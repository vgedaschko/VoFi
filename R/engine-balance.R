# Periodenalgorithmus und Terminalzustand ohne Restwert (WS-D, Spec 00 Abschnitte 9.3, 9.4).
# Schritte (1)-(7) aus 9.3 je Periode t = 0..T: exogene Zahlungen, Instrumente in
# financing-Reihenfolge (Instrument-Cache ohne loan_prepay, sonst init/step je Lauf mit
# capacity()/prepay() fuer Ue3), Kontozinsen auf Bestaende t-1 (D3), Abgeltungsteuer mit
# Sparer-Pauschbetrag (R-76), Steuer-Hook in jeder Periode vor dem Ausgleich (R-21), Ueberhang
# bei sinkendem Limit (6a), Ueberschuss- und Defizitkette in der konfigurierten Reihenfolge;
# danach offene Steuer am Horizont, Sacheinlage (R-68), Bestandssaldo, Finanzierungssaldo,
# Terminalzustand ohne Restwert (9.4, R-61) und Markierungen (9.8). Mit book = FALSE
# (Wiederholungslaeufe ueber ctx$rebalance(), 12.8) entfallen alle Buchungen; Rueckgabe
# list(BS_T, NS, BS_T_ex_rv, RW_T). Die Vorbereitung (Kontoraten, Instrument-Cache, exogene
# Summen, Steuer-Eingaben) entsteht je Kontext einmal (Zwischenspeicher in der
# Engine-Umgebung, Leistung 9.10).

#' Instrument-Cache: init/step über alle Perioden einmal je Kontext (9.3)
#' @return benannte Liste je Kredit (`flows`, `memo` als n x (T+1), `balance`, `neg_amort`) mit
#'   Attribut `"totals"` (`cash` = Summe der zahlungswirksamen Flüsse, `soll` = Sollzinsen
#'   positiv, `fees` = Gebühren positiv, `bal` = Summe der Bestände).
#' @noRd
eng_inst_cache <- function(model, ctx) {
  n <- ctx$n
  n_t <- ctx$T + 1L
  fl_names <- eng_loan_flow_names()
  mm_names <- eng_loan_memo_names()
  out <- list()
  tot <- list(cash = matrix(0, n, n_t), soll = matrix(0, n, n_t), fees = matrix(0, n, n_t),
              bal = matrix(0, n, n_t))
  for (id in names(model$instruments)) {
    k <- model$instruments[[id]]
    st <- k$def$init(k$spec, ctx)
    flows <- stats::setNames(lapply(fl_names, function(x) matrix(0, n, n_t)), fl_names)
    memo <- stats::setNames(lapply(mm_names, function(x) matrix(0, n, n_t)), mm_names)
    bal <- matrix(0, n, n_t)
    for (j in seq_len(n_t)) {
      r <- k$def$step(st, j - 1L, ctx)
      st <- r$state
      for (f in fl_names) flows[[f]][, j] <- eng_num(r$flows[[f]], n)
      for (f in mm_names) memo[[f]][, j] <- eng_num(r$memo[[f]], n)
      bal[, j] <- eng_num(r$stocks$balance, n)
    }
    tot$cash <- tot$cash + flows$draw + flows$repay + flows$repay_balloon + flows$prepay +
      flows$interest + flows$fees
    tot$soll <- tot$soll - flows$interest
    tot$fees <- tot$fees - flows$fees
    tot$bal <- tot$bal + bal
    out[[id]] <- list(flows = flows, memo = memo, balance = bal,
                      neg_amort = st$neg_amort %||% rep(FALSE, n))
  }
  attr(out, "totals") <- tot
  out
}

#' Zahlungswirksame Flüsse eines Kredits (8.4)
#' @noRd
eng_loan_flow_names <- function() {
  c("draw", "repay", "repay_balloon", "prepay", "interest", "fees")
}

#' Merkzeilen eines Kredits (8.4)
#' @noRd
eng_loan_memo_names <- function() c("repayment_grant", "disagio", "assumed")

#' Rückgabe eines Typs als double n-Vektor (fehlend: 0)
#' @noRd
eng_num <- function(x, n) {
  if (is.null(x)) return(rep(0, n))
  if (length(x) == n) return(as.double(x))
  rep_len(as.double(x), n)
}

#' Instrumentzeilen einer Periode für die Steuer-Eingaben (10.4: disagio negativ)
#' @noRd
eng_inst_tax_rows <- function(id, flows, memo) {
  stats::setNames(list(flows$interest, flows$fees, -memo$disagio, memo$repayment_grant),
                  paste0("loan_", id, c("_interest", "_fees", "_disagio", "_repayment_grant")))
}

#' Vorbereitung der Periodenschleife je Kontext (9.3; Zwischenspeicher)
#'
#' @param model `vofi_model` (Investition oder Unterlassungsalternative).
#' @param ctx Laufkontext.
#' @param exo exogener Ledger.
#' @param engine_env private Engine-Umgebung oder `NULL`.
#' @param setup_key Schlüssel des Zwischenspeichers (`"inv"`, `"opp"`).
#' @return Liste `exo`, `E`, `use_cache`, `cache`, `totals`, `tin`, `rw_t`, `terminal_inputs`,
#'   `acc0`, `inst_rows`.
#' @noRd
eng_balance_setup <- function(model, ctx, exo, engine_env = NULL, setup_key = "inv") {
  if (is.environment(engine_env)) {
    hit <- engine_env$setup[[setup_key]]
    if (!is.null(hit) && identical(hit$exo, exo)) return(hit)
  }
  n_t <- ctx$T + 1L
  insts <- model$instruments
  use_cache <- !eng_has_prepay(model)
  cache <- NULL
  if (length(insts) > 0L && use_cache) {
    cache <- if (is.environment(engine_env) && identical(setup_key, "inv")) {
      engine_env$inst_cache
    } else {
      NULL
    }
    if (is.null(cache)) cache <- eng_inst_cache(model, ctx)
    if (is.environment(engine_env) && identical(setup_key, "inv")) {
      engine_env$inst_cache <- cache
    }
  }
  rows_meta <- model$rows_meta[[setup_key]]
  if (is.null(rows_meta) || !identical(rows_meta$ids, names(insts))) {
    rows_meta <- eng_model_rows(insts)
  }
  e_cash <- ledger_sum(exo, section = c("project", "grants", "equity"), cash = TRUE)
  tin <- if (!is.null(model[["tax"]]) && isTRUE(model[["tax"]]$uses_inputs)) {
    tax_inputs(exo, ctx, rows_meta$loans)
  } else {
    NULL
  }
  rw <- ledger_sum(exo, category = c("residual_value", "sale_cost"))[, n_t]
  mv <- if (length(ledger_select(exo, category = "market_value")) > 0L) {
    ledger_sum(exo, category = "market_value")[, n_t]
  } else {
    NULL
  }
  su <- list(
    exo = exo, E = e_cash, use_cache = use_cache, cache = cache,
    totals = if (is.null(cache)) NULL else attr(cache, "totals"), tin = tin, rw_t = rw,
    terminal_inputs = list(exo_T = lapply(exo$values, function(m) m[, n_t]),
                           residual_value = rw, market_value_T = mv,
                           horizon_date = ctx$grid$end_date, assets = ctx$assets(),
                           measures = ctx$measures()),
    acc0 = eng_acc_rates(model, ctx, engine_env), rows_meta = rows_meta,
    tax_keys = if (is.null(tin)) tax_keys_empty() else tin$keys,
    chain_info = eng_chain_info(model$surplus_chain, model$deficit_chain)
  )
  # Module ohne Eingaben (uses_inputs = FALSE, 10.4): Periodenteil der Eingaben je Spalte vorab
  su$tax_slices <- if (is.null(tin)) {
    lapply(seq_len(n_t), function(j) tax_slice(NULL, j, list(), ctx$grid, su$tax_keys))
  } else {
    NULL
  }
  if (is.environment(engine_env)) engine_env$setup[[setup_key]] <- su
  su
}

#' Ausgleichsketten einer Periode (9.3 Schritt 6)
#'
#' Die Flüsse und Markierungen der Aktionen werden unverdichtet aneinandergehängt (`flows`,
#' `flags` können denselben Namen mehrfach enthalten, z. B. `dep_withdraw` aus D1 und D3); die
#' Aufrufer summieren bzw. verknüpfen sie über den Index. Eingebaute Aktionen, deren Wirkung
#' bei Betrag 0 in allen Läufen leer ist (`eng_zero_noop_actions()`), werden dann übersprungen.
#' @param skip_external D4-Aktionen mit Zufluss von außen (Zeilen `equity_call`, `shortfall`)
#'   nicht ausführen (Sicht ohne Restwert, 9.4 Nr. 2).
#' @param info `eng_chain_info()` der beiden Ketten oder `NULL` (dann neu bestimmt).
#' @return `list(acc, ist, flows, flags, rest_sur, rest_def, ext)`; `ext` ist die Summe der
#'   Flüsse `equity_call` und `shortfall` (Zufluss von außen NS, n-Vektor).
#' @noRd
eng_apply_chains <- function(surplus, deficit, acc, s, t, j, ctx, ist, skip_external = FALSE,
                             info = NULL) {
  if (is.null(info)) info <- eng_chain_info(surplus, deficit)
  acc$j <- j
  sur <- pmax.int(s, 0)
  def <- pmax.int(-s, 0)
  ext <- s * 0
  flows <- list()
  flags <- list()
  for (i in seq_along(surplus)) {
    if (info$noop_s[i] && max(sur) <= 0) next
    r <- surplus[[i]]$apply(acc, sur, t, ctx, ist)
    acc <- r$acc
    if (!is.null(r$inst)) ist <- r$inst
    sur <- sur - r$used
    if (length(r$flows) > 0L) flows <- c(flows, r$flows)
    if (length(r$flags) > 0L) flags <- c(flags, r$flags)
  }
  for (i in seq_along(deficit)) {
    if (info$noop_d[i] && max(def) <= 0) next
    if (skip_external && info$ext_d[i]) next
    r <- deficit[[i]]$apply(acc, def, t, ctx, ist)
    acc <- r$acc
    if (!is.null(r$inst)) ist <- r$inst
    def <- def - r$used
    if (length(r$flows) > 0L) {
      flows <- c(flows, r$flows)
      if (info$ext_d[i]) ext <- eng_flow_sum(r$flows, c("equity_call", "shortfall"), ext)
    }
    if (length(r$flags) > 0L) flags <- c(flags, r$flags)
  }
  list(acc = acc, ist = ist, flows = flows, flags = flags, rest_sur = sur, rest_def = def,
       ext = ext)
}

#' Eigenschaften der Kettenglieder für `eng_apply_chains()`
#' @return `list(noop_s, noop_d, ext_d)` (logische Vektoren je Kettenglied).
#' @noRd
eng_chain_info <- function(surplus, deficit) {
  noop <- eng_zero_noop_actions()
  nm <- function(ch) vapply(ch, function(a) as.character(a$name %||% "")[1L], character(1))
  list(noop_s = nm(surplus) %in% noop, noop_d = nm(deficit) %in% noop,
       ext_d = vapply(unname(deficit), eng_action_external, logical(1)))
}

#' Eingebaute Ausgleichsaktionen ohne Wirkung bei Betrag 0 (8.9)
#'
#' Bei Betrag 0 in allen Läufen sind Bestände, Flüsse und Markierungen dieser Aktionen leer
#' (`od_draw` bleibt ausgenommen: seine Markierung `overdraft_threshold` hängt vom Bestand ab).
#' @noRd
eng_zero_noop_actions <- function() {
  c("od_repay", "dep_fill_reserve", "loan_prepay", "dep_invest", "dep_withdraw",
    "dep_use_reserve", "equity_call", "penalty_rate", "stop")
}

#' Summe gleichnamiger Flüsse aus `eng_apply_chains()`
#' @param flows unverdichtete Flussliste.
#' @param keys Zeilenschlüssel.
#' @param zero Nullvektor (n).
#' @noRd
eng_flow_sum <- function(flows, keys, zero) {
  out <- zero
  nm <- names(flows)
  for (i in which(nm %in% keys)) out <- out + flows[[i]]
  out
}

#' Aktion mit Zufluss von außen (D4 `equity_call`, `stop`; 9.4 Nr. 2, 9.5 Nr. 5)
#' @noRd
eng_action_external <- function(a) any(a$rows %in% c("equity_call", "shortfall"))

#' Bestand eines Kredits nach dem Ausgleich (9.3 Schritt 7)
#' @noRd
eng_inst_balance <- function(e, t, ctx, fallback) {
  if (is.function(e$def$capacity)) as.double(e$def$capacity(e$state, t, ctx)$balance) else
    fallback
}

#' Periodenalgorithmus (9.3)
#'
#' @param model `vofi_model` (für die Unterlassungsalternative mit angepassten Ketten und ohne
#'   Instrumente). `model$tax = NULL` rechnet ohne Steuer-Hook (nur Tests, 10.10 Nr. 1); sonst
#'   läuft der Hook in jeder Periode inkl. t0, auch mit `tax_none` (10.1 Nr. 1).
#' @param ctx Laufkontext.
#' @param exo exogener Ledger (`vofi_ledger`).
#' @param extra_out optionale zusätzliche Entnahmen n x (T+1) (<= 0, 12.8); mit `book = TRUE`
#'   als Zeile `extra_equity_out` gebucht.
#' @param book `FALSE`: keine Ledger-Buchung, Rückgabe `list(BS_T, NS, BS_T_ex_rv, RW_T)`.
#' @param engine_env private Engine-Umgebung (Zwischenspeicher, Instrument-Cache).
#' @param setup_key Schlüssel des Zwischenspeichers (`"inv"` Investition, `"opp"` Alternative).
#' @return core (12.1) bzw. bei `book = FALSE` die Kurzform.
#' @noRd
eng_balance <- function(model, ctx, exo, extra_out = NULL, book = TRUE, engine_env = NULL,
                        setup_key = "inv") {
  g <- ctx$grid
  n <- ctx$n
  n_t <- g$T + 1L
  zero <- vofi_tol$zero_abs
  su <- eng_balance_setup(model, ctx, exo, engine_env, setup_key)
  acc <- su$acc0
  insts <- model$instruments
  ids <- names(insts)
  has_inst <- length(ids) > 0L
  use_cache <- su$use_cache
  cache <- su$cache
  tot <- su$totals
  tin <- su$tin
  ist <- NULL
  if (has_inst && !use_cache) {
    ist <- lapply(insts, function(k) list(state = k$def$init(k$spec, ctx), def = k$def))
  }
  eo <- if (is.null(extra_out)) NULL else utl_sim_matrix(g, extra_out, "extra_out")
  has_tax <- !is.null(model[["tax"]])
  tst <- if (has_tax) {
    tax_init(model$tax, model$tax_params, ctx$assets(), ctx$measures(), n)
  } else {
    NULL
  }
  zm <- function() matrix(0, n, n_t)
  zv <- rep(0, n)
  ns <- zm()
  fl_names <- eng_loan_flow_names()
  mm_names <- eng_loan_memo_names()
  if (book) {
    rec <- stats::setNames(lapply(eng_rec_keys(), function(k) zm()), eng_rec_keys())
    st_g <- zm()
    st_kk <- zm()
    st_kkp <- zm()
    loan <- if (has_inst && !use_cache) {
      lapply(ids, function(id) {
        stats::setNames(lapply(c(fl_names, mm_names, "balance"), function(x) zm()),
                        c(fl_names, mm_names, "balance"))
      })
    } else {
      list()
    }
    if (length(loan) > 0L) names(loan) <- ids
    reports <- list()
    fl <- list(reserve_used = rep(FALSE, n), shortfall = rep(FALSE, n),
               limit_cut = rep(FALSE, n), overdraft_threshold = rep(FALSE, n),
               stopped = rep(FALSE, n), limit_breach = rep(FALSE, n))
  }
  pre_t <- NULL
  for (j in seq_len(n_t)) {
    t <- j - 1L
    # (1) exogene Zahlungen
    f <- su$E[, j]
    if (!is.null(eo)) f <- f + eo[, j]
    # (2) Instrumente in financing-Reihenfolge
    soll <- zv
    fees <- zv
    inst_rows <- list()
    bal_now <- NULL
    if (has_inst) {
      if (use_cache) {
        f <- f + tot$cash[, j]
        soll <- tot$soll[, j]
        fees <- tot$fees[, j]
        if (!is.null(tin)) {
          for (id in ids) {
            cc <- cache[[id]]
            inst_rows <- c(inst_rows, eng_inst_tax_rows(
              id, list(interest = cc$flows$interest[, j], fees = cc$flows$fees[, j]),
              list(disagio = cc$memo$disagio[, j], repayment_grant = cc$memo$repayment_grant[, j])
            ))
          }
        }
      } else {
        bal_now <- list()
        for (id in ids) {
          r <- ist[[id]]$def$step(ist[[id]]$state, t, ctx)
          ist[[id]]$state <- r$state
          fls <- lapply(r$flows[fl_names], eng_num, n = n)
          names(fls) <- fl_names
          mms <- lapply(r$memo[mm_names], eng_num, n = n)
          names(mms) <- mm_names
          f <- f + fls$draw + fls$repay + fls$repay_balloon + fls$prepay + fls$interest +
            fls$fees
          soll <- soll - fls$interest
          fees <- fees - fls$fees
          bal_now[[id]] <- eng_num(r$stocks$balance, n)
          if (book) {
            for (x in fl_names) loan[[id]][[x]][, j] <- fls[[x]]
            for (x in mm_names) loan[[id]][[x]][, j] <- mms[[x]]
          }
          if (!is.null(tin)) inst_rows <- c(inst_rows, eng_inst_tax_rows(id, fls, mms))
        }
      }
    }
    # (3) Kontozinsen auf die Bestaende Ende t-1 (D3), Abgeltungsteuer mit Pauschbetrag
    hz <- acc$G * acc$h[, j]
    wht <- acc$w * pmax.int(hz - acc$wa[, j], 0)
    kz <- acc$KK * acc$s[, j]
    kzp <- acc$KKP * acc$sp[, j]
    # (4) vorlaeufiger Saldo
    s <- f + hz - wht - kz - kzp
    # (5) Steuer-Hook (jede Periode, R-21)
    if (has_tax) {
      inputs <- if (is.null(tin)) su$tax_slices[[j]] else
        tax_slice(tin, j, inst_rows, g, su$tax_keys)
      rt <- tax_step(model$tax, t, inputs = inputs,
                     interest = list(exo_soll = soll, exo_fees = fees, endo_soll = kz + kzp,
                                     endo_haben = hz, endo_wht = wht),
                     state = tst, params = model$tax_params)
      tst <- rt$state
      pay <- eng_num(rt$payment, n)
      s <- s - pay
      if (book) {
        rec$tax[, j] <- -pay
        reports <- eng_report_add(reports, rt$report, j, n, n_t)
      }
    }
    if (j == n_t) pre_t <- list(acc = acc, ist = ist, s = s)
    # (6a) Ueberhang bei sinkendem Limit: Zwangstilgung, zusaetzliches Defizit (8.8)
    excess <- pmax.int(acc$KK - acc$KL[, j], 0)
    acc$KK <- acc$KK - excess
    s <- s - excess
    # (6) Ausgleichsketten
    ch <- eng_apply_chains(model$surplus_chain, model$deficit_chain, acc, s, t, j, ctx, ist,
                           info = su$chain_info)
    acc <- ch$acc
    ist <- ch$ist
    rest <- pmax.int(ch$rest_sur, ch$rest_def)
    if (max(rest) > zero) {
      vofi_abort("engine.chain_rest", t = t, value = max(rest), .class = "vofi_error_engine",
                 .data = list(invariant = "chain", t = t, sim = which.max(rest)))
    }
    ns[, j] <- ch$ext
    if (!book) next
    rec$od_repay[, j] <- rec$od_repay[, j] - excess
    fl$limit_cut <- fl$limit_cut | (excess > zero)
    fk <- names(ch$flows)
    for (i in seq_along(fk)) {
      k <- fk[i]
      if (!is.null(rec[[k]])) {
        rec[[k]][, j] <- rec[[k]][, j] + ch$flows[[i]]
        next
      }
      id <- if (grepl("^loan_.+_prepay$", k)) sub("^loan_(.*)_prepay$", "\\1", k) else ""
      if (!(id %in% ids) || use_cache) {
        vofi_abort("engine.flow_key_unknown", row = k, .class = "vofi_error_contract")
      }
      loan[[id]]$prepay[, j] <- loan[[id]]$prepay[, j] + ch$flows[[i]]
    }
    gk <- names(ch$flags)
    for (i in which(gk %in% names(fl))) fl[[gk[i]]] <- fl[[gk[i]]] | ch$flags[[i]]
    # (7) Zinsen und Bestaende
    rec$dep_interest[, j] <- hz
    rec$dep_wht[, j] <- -wht
    rec$od_interest[, j] <- -kz
    rec$odp_interest[, j] <- -kzp
    st_g[, j] <- acc$G
    st_kk[, j] <- acc$KK
    st_kkp[, j] <- acc$KKP
    if (has_inst && !use_cache) {
      for (id in ids) loan[[id]]$balance[, j] <- eng_inst_balance(ist[[id]], t, ctx, bal_now[[id]])
    }
  }
  b_t <- if (!has_inst) {
    zv
  } else if (use_cache) {
    tot$bal[, n_t]
  } else {
    Reduce(`+`, lapply(ids, function(id) {
      eng_inst_balance(ist[[id]], g$T, ctx, rep(0, n))
    }), zv)
  }
  fin <- if (has_tax) {
    tax_finalize(model$tax, g$T, tst, su$terminal_inputs, model$tax_params)
  } else {
    NULL
  }
  tax_t <- if (has_tax) eng_num(fin$payment_T, n) else zv
  bs_t <- acc$G - acc$KK - acc$KKP - b_t - tax_t
  term <- eng_terminal_ex_rv(model, ctx, pre_t, su$rw_t, ns[, n_t], tax_t, use_cache, ids,
                             b_t)
  if (!book) {
    return(list(BS_T = bs_t, NS = ns, BS_T_ex_rv = term$BS, RW_T = su$rw_t))
  }
  if (has_tax) reports <- eng_report_add(reports, fin$report, n_t, n, n_t, add = TRUE)
  loan_values <- if (use_cache) {
    lapply(cache, function(cc) c(cc$flows, cc$memo, list(balance = cc$balance)))
  } else {
    loan
  }
  neg_amort <- rep(FALSE, n)
  for (id in ids) {
    na <- if (use_cache) cache[[id]]$neg_amort else ist[[id]]$state$neg_amort
    neg_amort <- neg_amort | (na %||% FALSE)
  }
  eng_assemble_core(model, ctx, su, rec, loan_values, st_g, st_kk, st_kkp, tax_t, term, fl,
                    acc, reports, eo, neg_amort)
}

#' Engine-Zeilen der Periodenschleife (7.7, ohne Prüf- und Bestandszeilen)
#' @noRd
eng_rec_keys <- function() {
  c("equity_call", "shortfall", "od_draw", "od_repay", "od_interest", "odp_draw", "odp_repay",
    "odp_interest", "dep_invest", "dep_withdraw", "dep_interest", "dep_wht", "tax")
}

#' Berichtsgrößen des Steuermoduls je Periode sammeln (10.5)
#' @param add `TRUE`: Werte zur Spalte addieren (Bericht aus `tax_finalize()` in T+1).
#' @noRd
eng_report_add <- function(reports, report, j, n, n_t, add = FALSE) {
  for (nm in names(report %||% list())) {
    if (is.null(reports[[nm]])) reports[[nm]] <- matrix(0, n, n_t)
    v <- eng_num(report[[nm]], n)
    reports[[nm]][, j] <- if (add) reports[[nm]][, j] + v else v
  }
  reports
}

#' Terminalzustand ohne Restwert (9.4, R-61)
#'
#' Wiederholt (6a) und (6) der Periode T ab pre_T mit S' = S_T - RW_T + NS_T; D4-Aktionen mit
#' Zufluss von außen werden nicht ausgeführt, der Rest geht unbegrenzt in die Strafzinstranche
#' (ohne Zinswirkung, T ist der Horizont). Die Steuerzahlung von T bleibt unverändert.
#' @return `list(G, KK, KKP, B_total, BS, rv, gap)` (n-Vektoren).
#' @noRd
eng_terminal_ex_rv <- function(model, ctx, pre, rw_t, ns_t, tax_t, use_cache, ids, b_t) {
  g <- ctx$grid
  n_t <- g$T + 1L
  acc <- pre$acc
  s <- pre$s - rw_t + ns_t
  excess <- pmax.int(acc$KK - acc$KL[, n_t], 0)
  acc$KK <- acc$KK - excess
  s <- s - excess
  ch <- eng_apply_chains(model$surplus_chain, model$deficit_chain, acc, s, g$T, n_t, ctx,
                         pre$ist, skip_external = TRUE)
  acc <- ch$acc
  gap <- ch$rest_def
  acc$KKP <- acc$KKP + gap
  b_total <- if (use_cache || length(ids) == 0L) {
    b_t
  } else {
    Reduce(`+`, lapply(ids, function(id) {
      eng_inst_balance(ch$ist[[id]], g$T, ctx, rep(0, length(s)))
    }), rep(0, length(s)))
  }
  list(G = acc$G, KK = acc$KK, KKP = acc$KKP, B_total = b_total,
       BS = acc$G - acc$KK - acc$KKP - b_total - tax_t, rv = rw_t, gap = gap)
}

#' Ledger, Bestände, Markierungen zu core zusammensetzen (9.3, 12.1)
#' @noRd
eng_assemble_core <- function(model, ctx, su, rec, loan_values, st_g, st_kk, st_kkp, tax_t,
                              term, fl, acc, reports, eo, neg_amort) {
  g <- ctx$grid
  n <- ctx$n
  n_t <- g$T + 1L
  zero <- vofi_tol$zero_abs
  exo <- su$exo
  rm <- su$rows_meta
  ids <- names(model$instruments)
  values <- exo$values
  cats <- c(eng_loan_flow_names(), eng_loan_memo_names())
  loan_cash <- matrix(0, n, n_t)
  for (id in ids) {
    lv <- loan_values[[id]]
    for (cc in cats) values[[paste0("loan_", id, "_", cc)]] <- lv[[cc]]
    loan_cash <- loan_cash + lv$draw + lv$repay + lv$repay_balloon + lv$prepay + lv$interest +
      lv$fees
  }
  for (k in names(rec)) values[[k]] <- rec[[k]]
  parts <- list(exo$rows, rm$loans, rm$engine)
  bc <- su$E + loan_cash
  for (k in names(rec)) bc <- bc + rec[[k]]
  if (!is.null(eo)) {
    values$extra_equity_out <- eo
    bc <- bc + eo
    parts[[length(parts) + 1L]] <- new_ledger_rows(
      "extra_equity_out", "equity", "equity_out", local_row = "extra_equity_out",
      label_key = "core.rows.extra_equity_out", label = lbl("core.rows.extra_equity_out")
    )
  }
  ev <- ctx$value_base("building.existing_value_eur", "scalar")
  if (!is.null(ev)) {
    assumed0 <- rep(0, n)
    for (id in ids) assumed0 <- assumed0 + loan_values[[id]]$assumed[, 1L]
    eik <- matrix(0, n, n_t)
    eik[, 1L] <- ev - assumed0
    values$equity_in_kind <- eik
    parts[[length(parts) + 1L]] <- new_ledger_rows(
      "equity_in_kind", "equity", "equity_in_kind", local_row = "equity_in_kind",
      label_key = "core.rows.equity_in_kind", label = lbl("core.rows.equity_in_kind")
    )
  }
  if (length(reports) > 0L) {
    parts[[length(parts) + 1L]] <- eng_tax_report_rows(model$tax, names(reports))
    for (nm in names(reports)) values[[paste0("tax_report_", nm)]] <- reports[[nm]]
  }
  values$balance_check <- bc
  parts <- c(parts, list(rm$check, rm$stocks))
  b_total <- matrix(0, n, n_t)
  for (id in ids) {
    values[[paste0("loan_", id, "_balance")]] <- loan_values[[id]]$balance
    b_total <- b_total + loan_values[[id]]$balance
  }
  tax_liab <- matrix(0, n, n_t)
  tax_liab[, n_t] <- tax_t
  bs <- st_g - st_kk - st_kkp - b_total - tax_liab
  values$od_balance <- st_kk
  values$odp_balance <- st_kkp
  values$dep_balance <- st_g
  values$tax_liability <- tax_liab
  values$net_position <- bs
  meta <- eng_bind_rows(parts)
  if (anyDuplicated(meta$key)) {
    vofi_abort("engine.key_collision", row = meta$key[duplicated(meta$key)][1L],
               .class = "vofi_error_engine")
  }
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
  per <- g$months > 0L
  flags <- data.frame(
    reserve_used = fl$reserve_used, shortfall = fl$shortfall | hit,
    shortfall_sum = rowSums(call_sum), first_shortfall_t = as.integer(first_t),
    limit_breach = fl$limit_breach | (rowSums(st_kkp > zero) > 0), limit_cut = fl$limit_cut,
    opp_limit_breach = rep(FALSE, n), ex_rv_gap = term$gap,
    overdraft_threshold = fl$overdraft_threshold |
      (rowSums((st_kk + st_kkp) > matrix(acc$flag_threshold, n, n_t)) > 0),
    stopped = fl$stopped, negative_amortization = neg_amort,
    equity_call_over_savings = eng_flag_savings(ctx, rec$equity_call),
    arbitrage = rowSums(acc$h_pa[, per, drop = FALSE] > acc$s_pa[, per, drop = FALSE]) > 0
  )
  list(
    ledger = ledger,
    stocks = list(G = st_g, KK = st_kk, KKP = st_kkp,
                  B = lapply(loan_values, function(l) l$balance), BS = bs,
                  tax_liability = tax_liab),
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
