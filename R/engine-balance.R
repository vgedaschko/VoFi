# Periodenalgorithmus und Terminalzustand ohne Restwert (WS-D, Spec 00 Abschnitte 9.3, 9.4).
# Phase-0-Minimalfassung, Eigentuemer: WS-D. Umgesetzt: Schritte (1)-(7) aus 9.3 je Periode
# t = 0..T (Instrumente in financing-Reihenfolge mit Instrument-Cache ohne loan_prepay, Kontozinsen
# auf Bestaende t-1, Abgeltungsteuer mit Pauschbetrag, Steuer-Hook in jeder Periode, sinkendes
# Limit (6a), Ueberschuss- und Defizitkette), Steuer am Horizont, Sacheinlage, Bestandssaldo,
# Finanzierungssaldo, Terminalzustand ohne Restwert (9.4, R-61), Markierungen (9.8),
# Wiederholungslauf ohne Buchung (book = FALSE) fuer ctx$rebalance().
# Offen fuer WS-D: Merkzeilen tax_report_<name> aktiver Steuermodule, Steuer-Eingaben fuer
# Module mit uses_inputs = TRUE nur minimal (eng_tax_inputs), Leistungsoptimierung.

#' Instrument-Cache: init/step über alle Perioden einmal je Kontext (9.3)
#' @return benannte Liste je Kredit: `flows`, `memo` (n x (T+1)), `balance`, `neg_amort`.
#' @noRd
eng_inst_cache <- function(model, ctx) {
  n <- ctx$n
  n_t <- ctx$T + 1L
  fl_names <- c("draw", "repay", "repay_balloon", "prepay", "interest", "fees")
  mm_names <- c("repayment_grant", "disagio", "assumed")
  out <- list()
  for (id in names(model$instruments)) {
    k <- model$instruments[[id]]
    st <- k$def$init(k$spec, ctx)
    flows <- stats::setNames(lapply(fl_names, function(x) matrix(0, n, n_t)), fl_names)
    memo <- stats::setNames(lapply(mm_names, function(x) matrix(0, n, n_t)), mm_names)
    bal <- matrix(0, n, n_t)
    for (j in seq_len(n_t)) {
      r <- k$def$step(st, j - 1L, ctx)
      st <- r$state
      for (f in fl_names) flows[[f]][, j] <- r$flows[[f]] %||% 0
      for (f in mm_names) memo[[f]][, j] <- r$memo[[f]] %||% 0
      bal[, j] <- r$stocks$balance
    }
    out[[id]] <- list(flows = flows, memo = memo, balance = bal,
                      neg_amort = st$neg_amort %||% rep(FALSE, n))
  }
  out
}

#' Steuer-Eingaben vor der Schleife (10.4); bei uses_inputs = FALSE leer
#' @noRd
eng_tax_inputs <- function(exo, ctx) {
  keys <- exo$rows$key[exo$rows$tax_category != "not_applicable"]
  rows <- exo$rows[match(keys, exo$rows$key), , drop = FALSE]
  sign <- ifelse(rows$category == "disagio", -1, 1)
  list(values = stats::setNames(lapply(seq_along(keys), function(i) {
    sign[i] * exo$values[[keys[i]]]
  }), keys), keys = data.frame(key = keys, source = rep("exo", length(keys)),
                               section = rows$section, category = rows$category,
                               tax_category = rows$tax_category, asset_id = rows$asset_id,
                               measure_id = rows$measure_id, cash = rows$cash,
                               stringsAsFactors = FALSE))
}

#' Steuer-Eingaben einer Periode (10.4)
#' @noRd
eng_tax_slice <- function(tin, j, grid, inst_rows) {
  keys <- if (is.null(tin)) {
    data.frame(key = character(0), source = character(0), section = character(0),
               category = character(0), tax_category = character(0),
               asset_id = character(0), measure_id = character(0), cash = logical(0),
               stringsAsFactors = FALSE)
  } else {
    tin$keys
  }
  list(t = grid$t[j], date_end = grid$date_end[j], delta = grid$delta[j], year = grid$year[j],
       phase = grid$phase[j],
       exo = if (is.null(tin)) list() else lapply(tin$values, function(m) m[, j]),
       inst = if (is.null(tin)) list() else inst_rows, keys = keys)
}

#' Ausgleichsketten einer Periode (9.3 Schritt 6)
#' @return `list(acc, ist, flows, flags, rest)`.
#' @noRd
eng_apply_chains <- function(surplus, deficit, acc, s, t, j, ctx, ist, skip_external = FALSE) {
  acc$j <- j
  rest <- list(surplus = pmax(s, 0), deficit = pmax(-s, 0))
  flows <- list()
  flags <- list()
  for (role in c("surplus", "deficit")) {
    chain <- if (role == "surplus") surplus else deficit
    for (a in chain) {
      if (skip_external && a$name %in% c("equity_call", "stop")) next
      r <- a$apply(acc, rest[[role]], t, ctx, ist)
      acc <- r$acc
      if (!is.null(r$inst)) ist <- r$inst
      rest[[role]] <- rest[[role]] - r$used
      for (k in names(r$flows)) flows[[k]] <- (flows[[k]] %||% 0) + r$flows[[k]]
      for (k in names(r$flags)) flags[[k]] <- (flags[[k]] %||% FALSE) | r$flags[[k]]
    }
  }
  list(acc = acc, ist = ist, flows = flows, flags = flags, rest_sur = rest$surplus,
       rest_def = rest$deficit)
}

#' Periodenalgorithmus (9.3)
#'
#' Phase-0-Minimalfassung, Eigentümer: WS-D.
#' @param model `vofi_model` (für die Unterlassungsalternative mit angepassten Ketten und ohne
#'   Instrumente).
#' @param ctx Laufkontext.
#' @param exo exogener Ledger (`vofi_ledger`).
#' @param extra_out optionale zusätzliche Entnahmen n x (T+1) (<= 0, 12.8).
#' @param book `FALSE`: keine Ledger-Buchung, Rückgabe `list(BS_T, NS, BS_T_ex_rv, RW_T)`.
#' @param engine_env private Engine-Umgebung (Instrument-Cache).
#' @return core (12.1) bzw. bei `book = FALSE` die Kurzform.
#' @noRd
eng_balance <- function(model, ctx, exo, extra_out = NULL, book = TRUE, engine_env = NULL) {
  g <- ctx$grid
  n <- ctx$n
  n_t <- g$T + 1L
  zero <- vofi_tol$zero_abs
  acc <- acc_init(model$accounts, ctx)
  insts <- model$instruments
  use_cache <- !eng_has_prepay(model)
  cache <- NULL
  ist <- NULL
  if (length(insts) > 0L) {
    if (use_cache) {
      cache <- if (is.environment(engine_env)) engine_env$inst_cache else NULL
      if (is.null(cache)) {
        cache <- eng_inst_cache(model, ctx)
        if (is.environment(engine_env)) engine_env$inst_cache <- cache
      }
    } else {
      ist <- lapply(insts, function(k) list(state = k$def$init(k$spec, ctx), def = k$def))
    }
  }
  e_cash <- ledger_sum(exo, section = c("project", "grants", "equity"), cash = TRUE)
  if (!is.null(extra_out)) e_cash <- e_cash + utl_sim_matrix(g, extra_out)
  tin <- if (isTRUE(model$tax$uses_inputs)) eng_tax_inputs(exo, ctx) else NULL
  tst <- tax_init(model$tax, model$tax_params, ctx$assets(), ctx$measures(), n)
  zm <- function() matrix(0, n, n_t)
  eng_keys <- c("equity_call", "shortfall", "od_draw", "od_repay", "od_interest", "odp_draw",
                "odp_repay", "odp_interest", "dep_invest", "dep_withdraw", "dep_interest",
                "dep_wht", "tax")
  rec <- stats::setNames(lapply(eng_keys, function(k) zm()), eng_keys)
  st_g <- st_kk <- st_kkp <- zm()
  fl_names <- c("draw", "repay", "repay_balloon", "prepay", "interest", "fees")
  mm_names <- c("repayment_grant", "disagio", "assumed")
  loan <- lapply(insts, function(k) {
    c(stats::setNames(lapply(c(fl_names, mm_names), function(x) zm()), c(fl_names, mm_names)),
      list(balance = zm()))
  })
  fl <- list(reserve_used = rep(FALSE, n), shortfall = rep(FALSE, n), limit_cut = rep(FALSE, n),
             overdraft_threshold = rep(FALSE, n), stopped = rep(FALSE, n),
             limit_breach = rep(FALSE, n))
  pre_t <- NULL
  for (j in seq_len(n_t)) {
    t <- j - 1L
    f <- e_cash[, j]
    exo_soll <- rep(0, n)
    exo_fees <- rep(0, n)
    bal_now <- list()
    inst_rows <- list()
    for (id in names(insts)) {
      r <- if (use_cache) {
        cc <- cache[[id]]
        list(flows = lapply(cc$flows, function(m) m[, j]),
             memo = lapply(cc$memo, function(m) m[, j]),
             stocks = list(balance = cc$balance[, j]))
      } else {
        rr <- ist[[id]]$def$step(ist[[id]]$state, t, ctx)
        ist[[id]]$state <- rr$state
        rr
      }
      fls <- lapply(fl_names, function(x) as.double(r$flows[[x]] %||% rep(0, n)))
      names(fls) <- fl_names
      f <- f + fls$draw + fls$repay + fls$repay_balloon + fls$prepay + fls$interest + fls$fees
      exo_soll <- exo_soll - fls$interest
      exo_fees <- exo_fees - fls$fees
      for (x in fl_names) loan[[id]][[x]][, j] <- fls[[x]]
      for (x in mm_names) loan[[id]][[x]][, j] <- as.double(r$memo[[x]] %||% rep(0, n))
      bal_now[[id]] <- as.double(r$stocks$balance)
      inst_rows[[paste0("loan_", id, "_interest")]] <- fls$interest
      inst_rows[[paste0("loan_", id, "_fees")]] <- fls$fees
      inst_rows[[paste0("loan_", id, "_disagio")]] <- -loan[[id]]$disagio[, j]
      inst_rows[[paste0("loan_", id, "_repayment_grant")]] <- loan[[id]]$repayment_grant[, j]
    }
    hz <- acc$G * acc$h[, j]
    wht <- acc$w * pmax(hz - acc$wa[, j], 0)
    kz <- acc$KK * acc$s[, j]
    kzp <- acc$KKP * acc$sp[, j]
    s <- f + hz - wht - kz - kzp
    rt <- tax_step(model$tax, t, inputs = eng_tax_slice(tin, j, g, inst_rows),
                   interest = list(exo_soll = exo_soll, exo_fees = exo_fees,
                                   endo_soll = kz + kzp, endo_haben = hz, endo_wht = wht),
                   state = tst, params = model$tax_params)
    tst <- rt$state
    pay <- rep_len(as.double(rt$payment), n)
    s <- s - pay
    rec$tax[, j] <- -pay
    if (j == n_t) pre_t <- list(acc = acc, ist = ist, s = s, bal = bal_now)
    excess <- pmax(acc$KK - acc$KL[, j], 0)
    acc$KK <- acc$KK - excess
    rec$od_repay[, j] <- rec$od_repay[, j] - excess
    s <- s - excess
    fl$limit_cut <- fl$limit_cut | (excess > zero)
    ch <- eng_apply_chains(model$surplus_chain, model$deficit_chain, acc, s, t, j, ctx, ist)
    acc <- ch$acc
    ist <- ch$ist
    if (max(ch$rest_sur, ch$rest_def) > zero) {
      vofi_abort("engine.chain_rest", t = t, value = max(ch$rest_sur, ch$rest_def),
                 .class = "vofi_error_engine",
                 .data = list(invariant = "chain", t = t,
                              sim = which.max(pmax(ch$rest_sur, ch$rest_def))))
    }
    for (k in names(ch$flows)) {
      if (k %in% names(rec)) {
        rec[[k]][, j] <- rec[[k]][, j] + ch$flows[[k]]
      } else {
        id <- if (grepl("^loan_.+_prepay$", k)) sub("^loan_(.*)_prepay$", "\\1", k) else ""
        if (is.null(loan[[id]])) {
          vofi_abort("engine.flow_key_unknown", row = k, .class = "vofi_error_contract")
        }
        loan[[id]]$prepay[, j] <- loan[[id]]$prepay[, j] + ch$flows[[k]]
      }
    }
    for (k in intersect(names(ch$flags), names(fl))) fl[[k]] <- fl[[k]] | ch$flags[[k]]
    rec$dep_interest[, j] <- hz
    rec$dep_wht[, j] <- -wht
    rec$od_interest[, j] <- -kz
    rec$odp_interest[, j] <- -kzp
    st_g[, j] <- acc$G
    st_kk[, j] <- acc$KK
    st_kkp[, j] <- acc$KKP
    for (id in names(insts)) {
      loan[[id]]$balance[, j] <- if (!use_cache && is.function(insts[[id]]$def$capacity)) {
        as.double(insts[[id]]$def$capacity(ist[[id]]$state, t, ctx)$balance)
      } else {
        bal_now[[id]]
      }
    }
  }
  terminal_inputs <- list(
    exo_T = lapply(exo$values, function(m) m[, n_t]),
    residual_value = ledger_sum(exo, category = c("residual_value", "sale_cost"))[, n_t],
    market_value_T = if (length(ledger_select(exo, category = "market_value")) > 0L) {
      ledger_sum(exo, category = "market_value")[, n_t]
    } else {
      NULL
    },
    horizon_date = g$end_date, assets = ctx$assets(), measures = ctx$measures()
  )
  fin <- tax_finalize(model$tax, g$T, tst, terminal_inputs, model$tax_params)
  tax_liab <- zm()
  tax_liab[, n_t] <- rep_len(as.double(fin$payment_T), n)
  b_total <- Reduce(`+`, lapply(loan, function(l) l$balance), zm())
  bs <- st_g - st_kk - st_kkp - b_total - tax_liab
  ns <- rec$equity_call + rec$shortfall
  rw_t <- terminal_inputs$residual_value
  term <- eng_terminal_ex_rv(model, ctx, pre_t, rw_t, ns[, n_t], g, tax_liab[, n_t], use_cache,
                             insts)
  if (!book) {
    return(list(BS_T = bs[, n_t], NS = ns, BS_T_ex_rv = term$BS, RW_T = rw_t))
  }
  eng_assemble_core(model, ctx, exo, rec, loan, st_g, st_kk, st_kkp, tax_liab, bs, term, fl,
                    acc, cache, ist, use_cache)
}

#' Terminalzustand ohne Restwert (9.4, R-61)
#'
#' Wiederholt (6a) und (6) der Periode T ab pre_T mit S' = S_T - RW_T + NS_T; D4-Aktionen mit
#' Zufluss von außen werden nicht ausgeführt, der Rest geht unbegrenzt in die Strafzinstranche.
#' @noRd
eng_terminal_ex_rv <- function(model, ctx, pre, rw_t, ns_t, g, tax_t, use_cache, insts) {
  n_t <- g$T + 1L
  acc <- pre$acc
  s <- pre$s - rw_t + ns_t
  excess <- pmax(acc$KK - acc$KL[, n_t], 0)
  acc$KK <- acc$KK - excess
  s <- s - excess
  ch <- eng_apply_chains(model$surplus_chain, model$deficit_chain, acc, s, g$T, n_t, ctx,
                         pre$ist, skip_external = TRUE)
  acc <- ch$acc
  gap <- ch$rest_def
  acc$KKP <- acc$KKP + gap
  b_total <- rep(0, length(s))
  for (id in names(insts)) {
    b_total <- b_total + if (!use_cache && is.function(insts[[id]]$def$capacity)) {
      as.double(insts[[id]]$def$capacity(ch$ist[[id]]$state, g$T, ctx)$balance)
    } else {
      pre$bal[[id]]
    }
  }
  list(G = acc$G, KK = acc$KK, KKP = acc$KKP, B_total = b_total,
       BS = acc$G - acc$KK - acc$KKP - b_total - tax_t, rv = rw_t, gap = gap)
}

#' Ledger, Bestände, Markierungen zu core zusammensetzen (9.3, 12.1)
#' @noRd
eng_assemble_core <- function(model, ctx, exo, rec, loan, st_g, st_kk, st_kkp, tax_liab, bs,
                              term, fl, acc, cache, ist, use_cache) {
  g <- ctx$grid
  n <- ctx$n
  n_t <- g$T + 1L
  zero <- vofi_tol$zero_abs
  insts <- model$instruments
  rows <- list(exo$rows)
  values <- exo$values
  for (id in names(insts)) {
    k <- insts[[id]]
    lr <- eng_loan_rows(id, k$k, k$spec, k$def)
    rows[[length(rows) + 1L]] <- lr
    cats <- c("draw", "repay", "repay_balloon", "prepay", "interest", "fees",
              "repayment_grant", "disagio", "assumed")
    for (cc in cats) values[[paste0("loan_", id, "_", cc)]] <- loan[[id]][[cc]]
  }
  er <- eng_engine_rows()
  rows[[length(rows) + 1L]] <- er[er$key != "balance_check", , drop = FALSE]
  for (k in names(rec)) values[[k]] <- rec[[k]]
  ev <- ctx$value_base("building.existing_value_eur", "scalar")
  if (!is.null(ev)) {
    assumed0 <- Reduce(`+`, lapply(loan, function(l) l$assumed[, 1L]), rep(0, n))
    eik <- matrix(0, n, n_t)
    eik[, 1L] <- ev - assumed0
    rows[[length(rows) + 1L]] <- new_ledger_rows(
      "equity_in_kind", "equity", "equity_in_kind", local_row = "equity_in_kind",
      label_key = "core.rows.equity_in_kind", label = lbl("core.rows.equity_in_kind"))
    values$equity_in_kind <- eik
  }
  meta <- do.call(rbind, rows)
  bal_secs <- c("project", "grants", "equity", "loans", "overdraft", "deposit", "tax")
  cash_keys <- meta$key[meta$cash & meta$section %in% bal_secs]
  bc <- Reduce(`+`, values[cash_keys], matrix(0, n, n_t))
  values$balance_check <- bc
  meta <- rbind(meta, er[er$key == "balance_check", , drop = FALSE])
  labels <- vapply(names(insts), function(id) insts[[id]]$spec$label %||% id, "")
  sr <- eng_stock_rows(names(insts), labels)
  if (length(insts) > 0L) {
    sr$existing_debt[seq_along(insts)] <- vapply(insts, function(k) isTRUE(k$spec$existing),
                                                 logical(1))
  }
  meta <- rbind(meta, sr)
  for (id in names(insts)) values[[paste0("loan_", id, "_balance")]] <- loan[[id]]$balance
  values$od_balance <- st_kk
  values$odp_balance <- st_kkp
  values$dep_balance <- st_g
  values$tax_liability <- tax_liab
  values$net_position <- bs
  ord <- order(meta$order, method = "radix")
  meta <- meta[ord, , drop = FALSE]
  rownames(meta) <- NULL
  ledger <- new_vofi_ledger(meta, values[meta$key], n = n, T = g$T)
  call_sum <- rec$equity_call + rec$shortfall + rec$odp_draw
  d4 <- call_sum > zero
  hit <- rowSums(d4) > 0
  first_t <- rep(NA_integer_, n)
  if (any(hit)) {
    first_t[hit] <- max.col(d4[hit, , drop = FALSE] * 1, ties.method = "first") - 1L
  }
  neg_amort <- rep(FALSE, n)
  for (id in names(insts)) {
    na <- if (use_cache) cache[[id]]$neg_amort else ist[[id]]$state$neg_amort
    neg_amort <- neg_amort | (na %||% FALSE)
  }
  flags <- data.frame(
    reserve_used = fl$reserve_used, shortfall = fl$shortfall | (rowSums(d4) > 0),
    shortfall_sum = rowSums(call_sum), first_shortfall_t = as.integer(first_t),
    limit_breach = fl$limit_breach | (rowSums(st_kkp > zero) > 0), limit_cut = fl$limit_cut,
    opp_limit_breach = rep(FALSE, n), ex_rv_gap = term$gap,
    overdraft_threshold = fl$overdraft_threshold |
      (rowSums((st_kk + st_kkp) > matrix(acc$flag_threshold, n, n_t)) > 0),
    stopped = fl$stopped, negative_amortization = neg_amort,
    equity_call_over_savings = eng_flag_savings(ctx, rec$equity_call),
    arbitrage = rowSums(acc$h_pa > acc$s_pa) > 0
  )
  list(
    ledger = ledger,
    stocks = list(G = st_g, KK = st_kk, KKP = st_kkp,
                  B = lapply(loan, function(l) l$balance), BS = bs, tax_liability = tax_liab),
    terminal_ex_rv = term, flags = flags,
    rates = list(h = acc$h, h_net = acc$h - acc$w * pmax(acc$h, 0), s = acc$s, sp = acc$sp),
    grid = g, n = n, opp = NULL, view = "with_rv",
    limits = list(KL = acc$KL, lmin_zero = all(acc$Lmin == 0))
  )
}

#' Markierung equity_call_over_savings (9.8): Nachschuss eines Betriebsjahres über 12 x
#' Sparfähigkeit
#' @noRd
eng_flag_savings <- function(ctx, calls) {
  n <- ctx$n
  sav <- ctx$value("household.savings_capacity_month_eur", "scalar")
  if (is.null(sav)) return(rep(FALSE, n))
  g <- ctx$grid
  out <- rep(FALSE, n)
  for (y in unique(g$op_year[g$op_year > 0L])) {
    cols <- which(g$op_year == y)
    out <- out | (rowSums(calls[, cols, drop = FALSE]) > 12 * sav + vofi_tol$zero_abs)
  }
  out
}
