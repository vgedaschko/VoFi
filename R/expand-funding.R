# Expander funding (WS-E2, Spec 01 Teil B 4; Spec 00 4.12, 9.11, 10.9, R-71, R-99, R-111): je
# Foerderinstrument Berechtigung (deterministisch zum Antragsdatum), Degression, Bedingungen der
# Satzbausteine, Bemessung und Deckel, dann die Bausteine f_<f>_grant (grant), f_<f>_loan
# (Foerderkredit mit Tilgungszuschuss, Block financing), f_<f>_subsidy (recurring) bzw.
# f_<f>_35c (tax_credit_35c); Zusage (Entscheidungsknoten) und Kumulierung. Wertabhaengige
# Groessen (realisierte Kosten, Zusage je Lauf) rechnen die Typen; der Expander schreibt Bezuege
# auf die Nutzlast bzw. Ausdruecke darueber und setzt Tabellenwerte (Staffeln, Sequenzen) als
# Konstanten ein (Spec 00 4.12 Nr. 5 (b), R-92).

# ---------------------------------------------------------------------------------------------
# Degression (Teil B 4.3.3)
# ---------------------------------------------------------------------------------------------

#' Degressionseinträge eines Instruments auswerten
#'
#' Ziele auf Map-Blätter werden als Ausdrucks-Umhüllung zurückgegeben (`leaf`: Pfad relativ zum
#' Instrument -> Funktion Text -> Text), Ziele auf Sequenzelemente (`pfad[i].feld`) als
#' geänderte Kopie der Nutzlast (`fs`). Ein Ziel in einem durch `~` entfernten Satzbaustein entfällt
#' mit Hinweis; ein sonst fehlendes Ziel ist ein Fehler.
#' @return Liste `fs` (Nutzlast mit angewandten Tabellenwerten), `leaf`.
#' @noRd
fund_degression <- function(x, f, fs, bctx) {
  leaf <- list()
  entries <- fs[["degression"]] %||% list()
  if (length(entries) == 0L) return(list(fs = fs, leaf = leaf))
  ad <- fund_application_date(x, fs)
  rule <- exp_rule(bctx, "fund_degression")
  for (e in entries) {
    target <- exp_code(e[["target"]])
    if (is.null(target)) next
    start <- exp_date(e[["start"]]) %||% ad
    step <- exp_num(e[["step"]]) %||% 0
    every <- exp_num(e[["every_months"]]) %||% 12
    fl <- exp_num(e[["floor"]])
    m <- regmatches(target, regexec("^([A-Za-z0-9_.]+)\\[([0-9]+)\\]\\.?([A-Za-z0-9_.]*)$", target))
    m <- m[[1L]]
    if (length(m) == 4L) {
      seq_path <- m[2L]
      i <- as.integer(m[3L])
      field <- m[4L]
      tab <- path_get(fs, seq_path)
      el <- if (is.list(tab) && i >= 1L && i <= length(tab)) tab[[i]] else NULL
      v0 <- if (is.null(el)) NULL else if (nzchar(field)) exp_num(path_get(el, field)) else
        exp_num(el)
      if (is.null(v0)) {
        bctx$abort("expand.funding.degression_target", funding = f, target = target)
      }
      v <- rule(v0[1L], ad, start, step, every, fl)
      if (nzchar(field)) el <- path_set(el, field, v) else el <- v
      tab[[i]] <- el
      fs <- path_set(fs, seq_path, tab)
      next
    }
    if (is.null(path_get(fs, target))) {
      parts <- strsplit(target, ".", fixed = TRUE)[[1L]]
      if (length(parts) >= 2L && identical(parts[1L], "rate_components") &&
            is.null(fs[["rate_components"]][[parts[2L]]])) {
        bctx$inform("expand.funding.degression_target_removed", funding = f, target = target)
        next
      }
      bctx$abort("expand.funding.degression_target", funding = f, target = target)
    }
    delta <- rule(0, ad, start, step, every, NULL)[1L]
    leaf[[target]] <- local({
      d <- delta
      s <- step
      flo <- fl
      function(text) {
        if (d == 0) return(text)
        raw <- paste0(text, " + ", exp_fmt(d))
        if (is.null(flo)) return(raw)
        paste0(if (s < 0) "pmax(" else "pmin(", raw, ", ", exp_fmt(flo), ")")
      }
    })
  }
  list(fs = fs, leaf = leaf)
}

#' Pfadtext eines Nutzlastblatts mit Degression (`funding.<f>.<rel>`)
#' @noRd
fund_leaf <- function(f, rel, deg) {
  txt <- paste0("funding.", f, ".", rel)
  fn <- deg$leaf[[rel]]
  if (is.function(fn)) fn(txt) else txt
}

# ---------------------------------------------------------------------------------------------
# Bemessung und Deckel (Teil B 4.4)
# ---------------------------------------------------------------------------------------------

#' Höchstkosten eines Instruments (Knoten bzw. `NULL`) nach Teil B 4.4
#' @param use_isfp iSFP-Werte der Staffel verwenden.
#' @return Liste `node` (Knoten oder `NULL`), `value` (Basiswert, falls Konstante).
#' @noRd
fund_cost_cap <- function(x, f, fs, deg, n_units, use_isfp, bctx) {
  basis <- deg$fs[["basis"]] %||% list()
  for (tab in c("eligible_cost_caps_per_building",
                "eligible_cost_caps_per_unit_per_calendar_year")) {
    t <- basis[[tab]]
    if (is.list(t) && length(t) > 0L) {
      v <- exp_rule(bctx, "fund_staffel_cap")(n_units, t, use_isfp)[1L]
      return(list(node = node_const(v), value = v))
    }
  }
  pre <- "basis."
  if (n_units <= 1L && exp_has(x, paste0("funding.", f, ".basis.cap_efh_eur"))) {
    txt <- fund_leaf(f, paste0(pre, "cap_efh_eur"), deg)
    return(list(node = exp_text_node(txt), value = NULL))
  }
  unit <- exp_has(x, paste0("funding.", f, ".basis.cap_mfh_per_unit_eur"))
  total <- exp_has(x, paste0("funding.", f, ".basis.cap_mfh_total_eur"))
  if (unit || total) {
    parts <- c(if (unit) paste0(fund_leaf(f, paste0(pre, "cap_mfh_per_unit_eur"), deg), " * ",
                                n_units),
               if (total) fund_leaf(f, paste0(pre, "cap_mfh_total_eur"), deg))
    txt <- if (length(parts) == 2L) paste0("pmin(", parts[1L], ", ", parts[2L], ")") else parts
    return(list(node = exp_text_node(txt), value = NULL))
  }
  list(node = NULL, value = NULL)
}

#' Kreditdeckel eines Instruments als Ausdruckstext oder `NULL` (Teil B 4.4)
#' @noRd
fund_loan_cap <- function(x, f, fs, deg, n_units) {
  basis <- deg$fs[["basis"]] %||% list()
  qng <- fund_fact(x, fs, "qng")
  if (qng && exp_has(x, paste0("funding.", f, ".basis.loan_cap_per_unit_qng_eur"))) {
    return(paste0(fund_leaf(f, "basis.loan_cap_per_unit_qng_eur", deg), " * ", n_units))
  }
  if (exp_has(x, paste0("funding.", f, ".basis.loan_cap_per_unit_eur"))) {
    return(paste0(fund_leaf(f, "basis.loan_cap_per_unit_eur", deg), " * ", n_units))
  }
  tab <- basis[["loan_cap_by_children_eur"]]
  if (is.list(tab) && length(tab) > 0L) {
    kids <- exp_num(x$household$n_children_u18) %||% 0
    for (row in tab) {
      lo <- exp_num(row[["children_from"]]) %||% 0
      hi <- exp_num(row[["children_to"]]) %||% Inf
      if (kids[1L] >= lo && kids[1L] <= hi) {
        v <- if (qng) exp_num(row[["cap_qng"]]) %||% exp_num(row[["cap"]]) else
          exp_num(row[["cap"]])
        if (!is.null(v)) return(exp_fmt(v[1L]))
      }
    }
  }
  NULL
}

#' Gekappte Baubegleitung als Ausdruckstext (Teil B 4.4, 4.6) oder `NULL`
#' @noRd
fund_construction_support <- function(x, f, deg, n_units) {
  p <- paste0("funding.", f, ".construction_support_eur")
  if (!exp_has(x, p)) return(NULL)
  pre <- "construction_supervision."
  has <- function(k) exp_has(x, paste0("funding.", f, ".", pre, k))
  cap <- if (n_units <= 1L && has("cap_efh_eur")) {
    fund_leaf(f, paste0(pre, "cap_efh_eur"), deg)
  } else if (has("cap_mfh_per_unit_eur") && has("cap_mfh_total_eur")) {
    paste0("pmin(", fund_leaf(f, paste0(pre, "cap_mfh_per_unit_eur"), deg), " * ", n_units,
           ", ", fund_leaf(f, paste0(pre, "cap_mfh_total_eur"), deg), ")")
  } else if (has("cap_mfh_per_unit_eur")) {
    paste0(fund_leaf(f, paste0(pre, "cap_mfh_per_unit_eur"), deg), " * ", n_units)
  } else if (has("cap_mfh_total_eur")) {
    fund_leaf(f, paste0(pre, "cap_mfh_total_eur"), deg)
  } else {
    NULL
  }
  if (is.null(cap)) p else paste0("pmin(", p, ", ", cap, ")")
}

#' Geförderte Maßnahme mit den größten Basisfallkosten (Anzeige-Tag, R-99)
#' @noRd
fund_main_measure <- function(x, ms, bctx) {
  if (length(ms) == 0L) return(NULL)
  k <- vapply(ms, function(m) {
    exp_base(bctx, x, paste0("measures.", m, ".cost_eur")) %||% 0
  }, double(1))
  cand <- ms[k == max(k)]
  exp_sort(cand)[1L]
}

#' Kostenkomponenten der Maßnahmen (m_<m>_capex, sofern vorhanden)
#' @noRd
fund_cost_ids <- function(x, ms) {
  ids <- paste0("m_", ms, "_capex")
  ids[vapply(ids, function(id) identical(x$components[[id]][["type"]], "capex"), logical(1))]
}

#' Metafelder eines Bausteins
#' @noRd
fund_meta <- function(x, f, fs, ms, bctx, type) {
  out <- list(type = type, label = fs[["label"]] %||% f, funding_id = f)
  mm <- fund_main_measure(x, ms, bctx)
  if (!is.null(mm)) out$measure_id <- mm
  pc <- exp_code(fs[["program_code"]])
  if (!is.null(pc)) out$program <- pc
  out
}

# ---------------------------------------------------------------------------------------------
# Satzbausteine (Teil B 4.3.2, 4.5)
# ---------------------------------------------------------------------------------------------

#' Satz, Bonus und Höchstsatz eines Zuschussinstruments
#' @return Liste `rate` (Knoten), `bonus_rate`, `bonus_threshold`, `bonus_mode`, `rate_cap`.
#' @noRd
fund_grant_rates <- function(x, f, fs, deg, n_units, cap_without_bonus, bctx) {
  fail <- function(key, ...) bctx$abort(key, ..., funding = f)
  parts <- character(0)
  bonus <- character(0)
  threshold <- NULL
  mode <- NULL
  for (id in names(fs[["rate_components"]] %||% list())) {
    rc <- fs[["rate_components"]][[id]]
    if (is.null(rc)) next
    cond <- rc[["condition"]]
    if (!is.null(cond) &&
          !fund_eval_condition(cond, fund_lookup(x, f, fs, rc), on_error = fail)) {
      next
    }
    rel <- paste0("rate_components.", id)
    sched <- rc[["schedule_by_taxable_income"]]
    txt <- if (is.list(sched)) {
      adj <- fund_taxable_income_adj(x, sched)
      if (is.null(adj)) bctx$abort("expand.funding.taxable_income_missing", funding = f)
      exp_fmt(exp_rule(bctx, "fund_income_rate")(adj, exp_num(sched[["thresholds_eur"]]),
                                                 exp_num(sched[["rates"]]))[1L])
    } else if (!is.null(rc[["rate"]])) {
      fund_leaf(f, paste0(rel, ".rate"), deg)
    } else {
      NULL
    }
    if (is.null(txt)) next
    if (is.list(rc[["threshold"]])) {
      bonus <- c(bonus, txt)
      th <- rc[["threshold"]]
      if (n_units <= 1L && !is.null(th[["single_unit_eur"]])) {
        threshold <- node_ref(paste0("funding.", f, ".", rel, ".threshold.single_unit_eur"))
      } else if (identical(exp_code(th[["multi_unit"]]), "cap_without_bonus")) {
        threshold <- if (is.null(cap_without_bonus)) NULL else node_const(cap_without_bonus)
      } else if (!is.null(exp_num(th[["multi_unit"]]))) {
        threshold <- node_ref(paste0("funding.", f, ".", rel, ".threshold.multi_unit"))
      }
      mode <- exp_code(rc[["mode"]]) %||% mode
    } else {
      parts <- c(parts, txt)
    }
  }
  rate_cap <- NULL
  rcap <- fs[["rate_cap"]] %||% list()
  for (exc in rcap[["exceptions"]] %||% list()) {
    cond <- exc[["condition"]]
    ok <- is.null(cond) || fund_eval_condition(cond, fund_lookup(x, f, fs), on_error = fail)
    if (ok && !is.null(exp_num(exc[["cap"]]))) {
      rate_cap <- node_const(exp_num(exc[["cap"]])[1L])
      break
    }
  }
  if (is.null(rate_cap) && exp_has(x, paste0("funding.", f, ".rate_cap.default"))) {
    rate_cap <- exp_text_node(fund_leaf(f, "rate_cap.default", deg))
  }
  list(rate = exp_sum_node(parts),
       bonus_rate = if (length(bonus) > 0L) exp_sum_node(bonus) else NULL,
       bonus_threshold = threshold, bonus_mode = mode, rate_cap = rate_cap)
}

#' Komponente f_<f>_grant (Teil B 4.5)
#' @noRd
fund_build_grant <- function(x, f, fs, bctx) {
  ms <- exp_chr(fs[["measures"]])
  deg <- fund_degression(x, f, fs, bctx)
  n_units <- fund_n_units(x, fs, bctx)
  isfp <- fund_fact(x, fs, "isfp")
  cap <- fund_cost_cap(x, f, fs, deg, n_units, isfp, bctx)
  cap0 <- fund_cost_cap(x, f, fs, deg, n_units, FALSE, bctx)
  rates <- fund_grant_rates(x, f, fs, deg, n_units, cap0$value, bctx)
  cmp <- fund_meta(x, f, fs, ms, bctx, "grant")
  cost_ids <- fund_cost_ids(x, ms)
  cmp$measures <- ms
  if (length(cost_ids) > 0L) {
    cmp$cost_components <- cost_ids
    cmp$after <- cost_ids
  }
  p <- paste0("funding.", f, ".")
  if (exp_has(x, paste0(p, "eligible_cost_eur"))) {
    cmp$eligible_cost_eur <- node_ref(paste0(p, "eligible_cost_eur"))
  }
  cmp$rate <- rates$rate
  if (!is.null(rates$rate_cap)) cmp$rate_cap <- rates$rate_cap
  if (!is.null(rates$bonus_rate)) {
    cmp$bonus_rate <- rates$bonus_rate
    if (!is.null(rates$bonus_threshold)) cmp$bonus_threshold_eur <- rates$bonus_threshold
    if (!is.null(rates$bonus_mode)) cmp$bonus_mode <- rates$bonus_mode
  }
  if (!is.null(cap$node)) cmp$cost_cap_eur <- cap$node
  cp <- exp_code(fs[["basis"]][["cap_period"]])
  if (!is.null(cp)) cmp$cap_period <- cp
  if (exp_has(x, paste0(p, "amount_eur"))) cmp$amount_eur <- node_ref(paste0(p, "amount_eur"))
  if (exp_has(x, paste0(p, "approved"))) cmp$approved <- node_ref(paste0(p, "approved"))
  ev <- exp_code(fs[["payout"]][["event"]])
  if (!is.null(ev)) cmp$payout_event <- ev
  lag <- exp_int(fs[["payout"]][["lag_months"]])
  if (!is.null(lag)) cmp$payout_lag_months <- lag
  if (exp_has(x, paste0(p, "payout_delay_months"))) {
    cmp$payout_delay_months <- node_ref(paste0(p, "payout_delay_months"))
  }
  ad <- fund_application_date(x, fs)
  if (!is.null(ad)) cmp$application_date <- ad
  cmp
}

# ---------------------------------------------------------------------------------------------
# Förderkredite (Teil B 4.6)
# ---------------------------------------------------------------------------------------------

#' Auszahlungstermine und Gewichte der Maßnahmen eines Kredits (Basisfallkosten, R-92)
#' @return Liste `start` (Date oder `NULL`), `schedule` (Knoten oder `NULL`).
#' @noRd
fund_loan_draws <- function(x, ms, bctx) {
  plans <- lapply(ms, function(m) exp_measure_dates(x, m, bctx))
  ok <- !vapply(plans, is.null, logical(1))
  if (!any(ok)) return(list(start = NULL, schedule = NULL))
  plans <- plans[ok]
  k0 <- vapply(ms[ok], function(m) {
    max(exp_base(bctx, x, paste0("measures.", m, ".cost_eur")) %||% 0, 0)
  }, double(1))
  if (sum(k0) <= 0) k0 <- rep(1, length(k0))
  w <- k0 / sum(k0)
  dates <- do.call(c, lapply(plans, function(p) p$dates))
  amts <- unlist(lapply(seq_along(plans), function(i) w[i] * plans[[i]]$weights))
  key <- as.numeric(dates)
  ud <- sort(unique(key))
  agg <- vapply(ud, function(d) sum(amts[key == d]), double(1))
  start <- as.Date(ud[1L], origin = "1970-01-01")
  if (length(ud) <= 1L) return(list(start = start, schedule = NULL))
  list(start = start,
       schedule = list(kind = "schedule", dates = as.Date(ud, origin = "1970-01-01"),
                       amounts = lapply(agg / sum(agg), node_const), unit = "share"))
}

#' Ausdruckstext des Zusagefaktors eines Kredits bzw. einer Zinsverbilligung (R-99)
#' @noRd
fund_activation_max <- function(x, ms) {
  a <- unique(vapply(ms, function(m) exp_activation_text(x, m), character(1)))
  if (length(a) == 0L) return(NULL)
  if (length(a) == 1L) return(a)
  paste0("pmax(", paste(a, collapse = ", "), ")")
}

#' Tilgungszuschuss eines Kredits (Teil B 4.6) oder `NULL`
#' @param amount_text Ausdruck des Zusagebetrags.
#' @noRd
fund_repayment_grant <- function(x, f, fs, deg, n_units, amount_text, bctx) {
  rg <- fs[["repayment_grant"]]
  if (!is.list(rg) || length(rg) == 0L) return(NULL)
  p <- paste0("funding.", f, ".repayment_grant.")
  cls <- exp_code(rg[["class"]]) %||% (if (fund_fact(x, fs, "nh_class")) "nh" else "ee")
  parts <- character(0)
  if (exp_has(x, paste0(p, "base_rates.", cls))) {
    parts <- fund_leaf(f, paste0("repayment_grant.base_rates.", cls), deg)
  }
  for (id in names(rg[["bonuses"]] %||% list())) {
    b <- rg[["bonuses"]][[id]]
    if (is.null(b) || is.null(b[["rate"]])) next
    cond <- b[["condition"]]
    on_err <- function(key, ...) bctx$abort(key, ..., funding = f)
    ok <- is.null(cond) || fund_eval_condition(cond, fund_lookup(x, f, fs), on_error = on_err)
    if (ok) parts <- c(parts, fund_leaf(f, paste0("repayment_grant.bonuses.", id, ".rate"), deg))
  }
  if (length(parts) == 0L) parts <- "0"
  t <- paste(parts, collapse = " + ")
  if (exp_has(x, paste0(p, "max_total_share"))) {
    t <- paste0("pmin(", t, ", ", fund_leaf(f, "repayment_grant.max_total_share", deg), ")")
  }
  cs <- fund_construction_support(x, f, deg, n_units)
  basis <- if (is.null(cs)) amount_text else paste0("(", amount_text, " - ", cs, ")")
  if (exp_has(x, paste0(p, "cap_per_unit_basis_eur"))) {
    basis <- paste0("pmin(", basis, ", ", fund_leaf(f, "repayment_grant.cap_per_unit_basis_eur",
                                                    deg), " * ", n_units, ")")
  }
  num <- paste0("(", t, ") * ", basis)
  cs_share <- paste0("funding.", f, ".construction_supervision.repayment_grant_share")
  if (!is.null(cs) && exp_has(x, cs_share)) num <- paste0(num, " + ", cs_share, " * ", cs)
  out <- list(share = node_expr(paste0("(", num, ") / (", amount_text, ")")))
  ms <- exp_chr(fs[["measures"]])
  comps <- Filter(Negate(is.null), lapply(ms, function(m) exp_measure_completion(x, m, bctx)))
  lag <- exp_int(rg[["payout"]][["lag_months"]]) %||% 0L
  if (length(comps) > 0L) out$date <- grid_add_months(do.call(max, comps), lag)
  eff <- exp_code(rg[["effect"]], "repayment_grant_effect")
  if (!is.null(eff)) out$effect <- eff
  out$approved <- node_const(1)
  if (exp_has(x, paste0(p, "cut_share"))) out$cut_share <- node_ref(paste0(p, "cut_share"))
  out
}

#' Baustein financing.f_<f>_loan (Teil B 4.6)
#' @noRd
fund_build_loan <- function(x, f, fs, bctx) {
  ms <- exp_chr(fs[["measures"]])
  deg <- fund_degression(x, f, fs, bctx)
  n_units <- fund_n_units(x, fs, bctx)
  ln <- fs[["loan"]] %||% list()
  v <- exp_code(fs[["loan_variant"]]) %||% exp_code(ln[["default_variant"]])
  vv <- if (is.null(v)) NULL else ln[["variants"]][[v]]
  if (is.null(vv) && !is.null(exp_code(fs[["loan_variant"]]))) {
    bctx$abort("expand.funding.loan_variant_unknown", funding = f, variant = v)
  }
  if (is.null(vv)) {
    # ohne Konditionen (Nutzlast ohne Varianten) entsteht kein Kredit
    bctx$warn("expand.funding.loan_terms_missing", funding = f)
    return(NULL)
  }
  rep <- exp_code(vv[["repayment"]]) %||% exp_code(ln[["repayment"]]) %||% "annuity"
  type <- switch(rep, installment = "installment_loan", bullet = "bullet_loan", "annuity_loan")
  cmp <- fund_meta(x, f, fs, ms, bctx, type)
  p <- paste0("funding.", f, ".")
  amount_text <- if (exp_has(x, paste0(p, "amount_eur"))) {
    paste0(p, "amount_eur")
  } else {
    eligible <- vapply(ms, function(m) {
      cost <- paste0("measures.", m, ".cost_eur")
      sh <- paste0(p, "eligible_shares.", m)
      if (exp_has(x, sh)) paste0(sh, " * ", cost) else cost
    }, character(1))
    base <- paste0("(", paste(eligible, collapse = " + "), ")")
    msh <- paste0(p, "loan.max_share_of_eligible_costs")
    if (exp_has(x, msh)) base <- paste0(base, " * ", msh)
    cap <- fund_loan_cap(x, f, fs, deg, n_units)
    txt <- if (is.null(cap)) base else paste0("pmin(", base, ", ", cap, ")")
    cs <- fund_construction_support(x, f, deg, n_units)
    if (!is.null(cs)) txt <- paste0(txt, " + ", cs)
    bctx$warn("expand.funding.loan_amount_estimated", funding = f)
    paste0("(", txt, ")")
  }
  cmp$amount_eur <- exp_text_node(amount_text)
  act <- fund_activation_max(x, ms)
  appr <- c(if (exp_has(x, paste0(p, "approved"))) paste0(p, "approved"), act)
  if (length(appr) > 0L) cmp$approved <- exp_text_node(paste(appr, collapse = " * "))
  dr <- fund_loan_draws(x, ms, bctx)
  if (!is.null(dr$start)) cmp$start <- dr$start
  if (!is.null(dr$schedule)) cmp$draw_schedule <- dr$schedule
  vp <- paste0(p, "loan.variants.", v, ".")
  if (exp_has(x, paste0(vp, "rate_pa"))) cmp$rate_pa <- node_ref(paste0(vp, "rate_pa"))
  for (fld in c("term_years", "grace_years", "fixed_years")) {
    val <- exp_num(vv[[fld]])
    if (!is.null(val)) cmp[[fld]] <- val[1L]
  }
  ppy <- exp_int(ln[["payments_per_year"]])
  if (!is.null(ppy)) cmp$payments_per_year <- ppy
  fees <- list()
  for (fld in c("processing_fee_share", "commitment_fee_rate_month")) {
    if (exp_has(x, paste0(p, "loan.fees.", fld))) {
      fees[[fld]] <- node_ref(paste0(p, "loan.fees.", fld))
    }
  }
  cfm <- exp_int(ln[["fees"]][["commitment_free_months"]])
  if (!is.null(cfm)) fees$commitment_free_months <- cfm
  if (length(fees) > 0L) cmp$fees <- fees
  pa <- exp_lgl(ln[["prepay_allowed"]])
  if (!is.null(pa)) cmp$prepay_allowed <- pa
  if (identical(exp_code(ln[["followup"]]), "market") && exp_has(x, "market.mortgage_rate")) {
    cmp$followup_rate_pa <- node_ref("market.mortgage_rate")
  }
  if (identical(exp_code(fs[["instrument_type"]]), "loan_with_repayment_grant")) {
    rg <- fund_repayment_grant(x, f, fs, deg, n_units, amount_text, bctx)
    if (!is.null(rg)) cmp$repayment_grant <- rg
  }
  cmp
}

# ---------------------------------------------------------------------------------------------
# Zinsverbilligung und Steuerermäßigung (Teil B 4.7, 4.8)
# ---------------------------------------------------------------------------------------------

#' Komponente f_<f>_subsidy (Typ recurring, Teil B 4.7)
#' @noRd
fund_build_subsidy <- function(x, f, fs, bctx) {
  ms <- exp_chr(fs[["measures"]])
  is <- fs[["interest_subsidy"]] %||% list()
  p <- paste0("funding.", f, ".")
  base <- if (exp_has(x, paste0(p, "interest_subsidy.subsidized_amount_eur"))) {
    paste0(p, "interest_subsidy.subsidized_amount_eur")
  } else if (exp_has(x, paste0(p, "amount_eur"))) {
    paste0(p, "amount_eur")
  } else {
    bctx$abort("expand.funding.subsidy_amount_missing", funding = f)
  }
  if (!exp_has(x, paste0(p, "interest_subsidy.rate_reduction_pa"))) {
    bctx$abort("expand.funding.subsidy_amount_missing", funding = f)
  }
  parts <- c(base, paste0(p, "interest_subsidy.rate_reduction_pa"),
             if (exp_has(x, paste0(p, "approved"))) paste0(p, "approved"))
  act <- fund_activation_max(x, ms)
  if (!is.null(act)) parts <- c(parts, if (grepl("[*,]", act)) paste0("(", act, ")") else act)
  cmp <- fund_meta(x, f, fs, ms, bctx, "recurring")
  cmp$amount_eur <- node_expr(paste(parts, collapse = " * "))
  cmp$category <- "operating_subsidy"
  se <- is[["start_event"]]
  start <- if (identical(se, "completion")) "completion" else exp_date(se, bctx$grid)
  if (is.null(start)) {
    comps <- Filter(Negate(is.null), lapply(ms, function(m) exp_measure_completion(x, m, bctx)))
    start <- if (length(comps) > 0L) do.call(min, comps) else "completion"
  }
  cmp$start_event <- start
  yrs <- exp_num(is[["years"]])
  if (!is.null(yrs)) {
    d0 <- if (identical(start, "completion")) bctx$grid$completion_date else start
    if (!is.null(d0)) cmp$to <- grid_add_months(d0, round(12 * yrs[1L]))
  }
  cmp
}

#' Komponente f_<f>_35c (Typ tax_credit_35c, Teil B 4.8)
#' @noRd
fund_build_35c <- function(x, f, fs, bctx) {
  ms <- exp_chr(fs[["measures"]])
  cmp <- fund_meta(x, f, fs, ms, bctx, "tax_credit_35c")
  cost_ids <- fund_cost_ids(x, ms)
  cmp$measures <- ms
  if (length(cost_ids) > 0L) {
    cmp$cost_components <- cost_ids
    cmp$after <- cost_ids
  }
  p <- paste0("funding.", f, ".")
  cr <- fs[["credit"]] %||% list()
  pr <- exp_rule(bctx, "fund_35c_params")(cr)
  cmp$share_y1 <- pr$share_y1
  cmp$share_y2 <- pr$share_y2
  cmp$share_y3 <- pr$share_y3
  refs <- c(eligible_cost_eur = "eligible_cost_eur", total_share = "credit.total_share",
            cap_total_eur = "credit.cap_per_object_eur",
            energy_advice_cost_eur = "energy_advice_cost_eur",
            energy_advice_share = "credit.energy_advice_share",
            prior_used_eur = "prior_credit_used_eur", approved = "approved",
            payout_delay_months = "payout_delay_months")
  for (prm in names(refs)) {
    if (exp_has(x, paste0(p, refs[[prm]]))) cmp[[prm]] <- node_ref(paste0(p, refs[[prm]]))
  }
  if (isTRUE(exp_lgl(cr[["capped_by_expected_income_tax"]]))) {
    if (exp_has(x, "household.expected_income_tax_eur_pa")) {
      cmp$income_tax_cap_eur_pa <- node_ref("household.expected_income_tax_eur_pa")
    } else {
      bctx$warn("expand.funding.income_tax_missing", funding = f)
    }
  }
  cb <- exp_date(fs[["eligibility"]][["conditions"]][["completion_before"]])
  if (!is.null(cb)) cmp$completion_before <- cb
  cmp
}

# ---------------------------------------------------------------------------------------------
# Kumulierung und Zusage (Teil B 4.9, 4.11)
# ---------------------------------------------------------------------------------------------

#' Programmcode eines Bibliothekseintrags (über die Kette) oder `NA`
#' @noRd
fund_lib_code <- function(bctx, id) {
  v <- tryCatch(suppressMessages(bctx$lib(id)), error = function(e) NULL)
  exp_code(v[["program_code"]]) %||% NA_character_
}

#' Kumulierungsregeln prüfen (Teil B 4.11): E bei Ausschluss mit gemeinsamer Maßnahme, sonst W
#' @param active ids der Instrumente, die Bausteine erzeugen.
#' @noRd
fund_cumulation <- function(x, active, bctx) {
  fund <- x$funding %||% list()
  code_of <- vapply(active, function(f) exp_code(fund[[f]][["program_code"]]) %||% NA_character_,
                    character(1))
  names(code_of) <- active
  cache <- new.env(parent = emptyenv())
  lib_code <- function(id) {
    if (!exists(id, envir = cache, inherits = FALSE)) {
      assign(id, fund_lib_code(bctx, id), envir = cache)
    }
    get(id, envir = cache, inherits = FALSE)
  }
  hits <- function(ids, g) {
    if (length(ids) == 0L || is.na(code_of[[g]])) return(FALSE)
    any(vapply(ids, function(id) identical(lib_code(id), code_of[[g]]), logical(1)))
  }
  for (i in seq_along(active)) {
    f <- active[i]
    cu <- fund[[f]][["cumulation"]] %||% list()
    excl <- exp_chr(cu[["exclusive_with"]])
    for (g in setdiff(active, f)) {
      if (match(g, active) < i) next
      excl_g <- exp_chr(fund[[g]][["cumulation"]][["exclusive_with"]])
      if (!(hits(excl, g) || hits(excl_g, f))) next
      common <- intersect(exp_chr(fund[[f]][["measures"]]), exp_chr(fund[[g]][["measures"]]))
      if (length(common) > 0L) {
        bctx$abort("expand.funding.cumulation_exclusive", funding = f, other = g,
                   measure = common[1L])
      }
    }
    req <- exp_chr(cu[["requires"]])
    if (length(req) > 0L) {
      others <- setdiff(active, f)
      found <- others[vapply(others, function(g) hits(req, g), logical(1))]
      if (length(found) == 0L) {
        bctx$warn("expand.funding.cumulation_requires", funding = f,
                  required = utl_collapse(req))
      } else {
        cnd_f <- fund[[f]][["eligibility"]][["conditions"]]
        lim <- exp_num(cnd_f[["requires_beg_em_commitment_months"]])
        if (!is.null(lim)) {
          ad <- fund_application_date(x, fund[[f]])
          ok <- vapply(found, function(g) {
            adg <- fund_application_date(x, fund[[g]])
            !is.null(ad) && !is.null(adg) && adg <= ad &&
              grid_months_between(adg, ad) <= lim[1L]
          }, logical(1))
          if (!any(ok)) {
            bctx$warn("expand.funding.commitment_too_old", funding = f, months = lim[1L])
          }
        }
      }
    }
  }
  yearly <- active[vapply(active, function(f) {
    identical(exp_code(fund[[f]][["basis"]][["cap_period"]]), "calendar_year")
  }, logical(1))]
  for (code in unique(code_of[yearly][!is.na(code_of[yearly])])) {
    ids <- yearly[code_of[yearly] %in% code]
    if (length(ids) > 1L) {
      bctx$warn("expand.funding.annual_cap_shared", ids = utl_collapse(ids), program = code)
    }
  }
  invisible(NULL)
}

#' Zuschüsse und Tilgungszuschüsse je Maßnahme gegen die Kosten (Teil B 4.11, Basisfall)
#'
#' Schätzt je Instrument den Basisfallbetrag (fester Betrag bzw. Satz × min(Kosten, Deckel),
#' Tilgungszuschuss = Anteil × Zusagebetrag), verteilt ihn nach Basisfallkosten auf die
#' Maßnahmen und meldet W, wenn die Summe einer Maßnahme `max_total_share` (ohne Angabe 1) der
#' Kosten übersteigt.
#' @noRd
fund_total_share <- function(x, active, built, bctx) {
  fund <- x$funding %||% list()
  tot <- list()
  lim <- list()
  base_of <- function(node, path) {
    if (is.null(node)) return(NULL)
    v <- exp_num(node)
    if (!is.null(v)) return(v[1L])
    exp_eval_base(x, bctx$grid, path)
  }
  for (f in active) {
    b <- built[[f]]
    if (is.null(b)) next
    ms <- exp_chr(fund[[f]][["measures"]])
    k0 <- vapply(ms, function(m) {
      max(exp_base(bctx, x, paste0("measures.", m, ".cost_eur")) %||% 0, 0)
    }, double(1))
    if (sum(k0) <= 0) next
    amount <- NULL
    if (identical(b$comp$type, "grant")) {
      path <- paste0(b$collection, ".", b$id, ".")
      amount <- base_of(b$comp$amount_eur, paste0(path, "amount_eur"))
      if (is.null(amount)) {
        r <- base_of(b$comp$rate, paste0(path, "rate")) %||% 0
        cap <- base_of(b$comp$cost_cap_eur, paste0(path, "cost_cap_eur")) %||% Inf
        amount <- r * min(sum(k0), cap)
      }
    } else if (!is.null(b$comp$repayment_grant$share)) {
      path <- paste0(b$collection, ".", b$id, ".")
      sh <- base_of(b$comp$repayment_grant$share, paste0(path, "repayment_grant.share"))
      amt <- base_of(b$comp$amount_eur, paste0(path, "amount_eur"))
      if (!is.null(sh) && !is.null(amt)) amount <- sh * amt
    }
    if (is.null(amount) || !is.finite(amount)) next
    mts <- exp_num(fund[[f]][["cumulation"]][["max_total_share"]])
    for (j in seq_along(ms)) {
      m <- ms[j]
      tot[[m]] <- (tot[[m]] %||% 0) + amount * k0[j] / sum(k0)
      if (!is.null(mts)) lim[[m]] <- min(lim[[m]] %||% Inf, mts[1L])
    }
  }
  for (m in names(tot)) {
    k <- exp_base(bctx, x, paste0("measures.", m, ".cost_eur")) %||% 0
    share <- lim[[m]] %||% 1
    if (k > 0 && tot[[m]] > share * k + vofi_tol$zero_abs) {
      bctx$warn("expand.funding.cumulation_total_share", measure = m, share = share)
    }
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Expander
# ---------------------------------------------------------------------------------------------

#' Expander funding (Teil B 4.1–4.11)
#' @noRd
funding_expand <- function(block, scenario, bctx) {
  x <- scenario
  comps <- list()
  fin <- list()
  plan <- fund_plan(x, bctx)
  nodes <- names(block)[vapply(names(block), function(f) {
    fs <- block[[f]]
    identical(exp_code(fs[["approval_timing"]]), "before_start") &&
      utl_is_string(exp_code(fs[["fallback_variant"]]))
  }, logical(1))]
  if (length(nodes) > 1L) {
    bctx$abort("expand.funding.decision_nodes", ids = utl_collapse(nodes))
  }
  built <- list()
  active <- character(0)
  for (f in names(block)) {
    fs <- block[[f]] %||% list()
    exp_check_id(bctx, paste0("f_", f, "_subsidy"), f, 30L, "funding")
    pl <- plan[[f]]
    chk <- pl$check
    for (er in chk$errors) {
      bctx$abort("expand.funding.measure_type", funding = f, measure = er$measure,
                 measure_type = er$measure_type)
    }
    if (isTRUE(chk$override)) bctx$inform("expand.funding.override", funding = f)
    for (op in chk$open) {
      bctx$inform("expand.funding.condition_unchecked", funding = f,
                  condition = op$args$text %||% op$code)
    }
    if (!isTRUE(pl$eligible)) {
      for (r in chk$reasons) {
        cond <- bctx$lbl(paste0("expand.funding.conditions.", r$code), .default = r$code)
        bctx$warn("expand.funding.not_eligible", funding = f, condition = cond,
                  value = utl_collapse(format(r$args$value %||% "-")))
      }
      next
    }
    type <- pl$type
    # ohne Art bzw. ohne Maßnahmen entsteht kein Baustein; die Fehler meldet die Validierung
    # (WS-B: validation.funding.*), Entscheidungsknoten ohne Baustein bleiben zulässig (9.11)
    if (is.na(type) || !(type %in% vocab_codes("instrument_type"))) next
    if (!identical(type, "rent_binding") && length(exp_chr(fs[["measures"]])) == 0L) next
    cmp <- switch(type,
      grant = fund_build_grant(x, f, fs, bctx),
      loan = , loan_with_repayment_grant = fund_build_loan(x, f, fs, bctx),
      interest_subsidy = fund_build_subsidy(x, f, fs, bctx),
      tax_credit = fund_build_35c(x, f, fs, bctx),
      NULL
    )
    active <- c(active, f)
    if (is.null(cmp)) next
    if (identical(pl$collection, "financing")) fin[[pl$component]] <- cmp else
      comps[[pl$component]] <- cmp
    built[[f]] <- list(id = pl$component, collection = pl$collection, comp = cmp)
  }
  fund_cumulation(x, active, bctx)
  x2 <- x
  for (f in names(built)) {
    x2[[built[[f]]$collection]][[built[[f]]$id]] <- built[[f]]$comp
  }
  fund_total_share(x2, active, built, bctx)
  list(components = comps, financing = fin, assets = list(), measures = list())
}

#' @noRd
typedef_expander_funding <- function() {
  vofi_type(name = "funding", kind = "expander", block = "funding", order = 40L,
            expand = funding_expand)
}
