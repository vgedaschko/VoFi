# Gemeinsamer Kern der Kredittypen als Zustandsautomat (WS-F, Spec 00 Abschnitte 8.1-8.6).
# Phase-0-Minimalfassung, Eigentuemer: WS-F. Referenzsemantik Monatsuhr nach 8.5: Zinsen
# monatlich i_nom/12 auf den Monatsanfangsbestand, Tilgungen in Vertragsfrequenz, alle Betraege
# einer Periode am Periodenende. Umgesetzt: Auszahlung bei start bzw. nach draw_schedule,
# Annuitaet (mit Laufzeit oder Tilgungssatz), Ratentilgung, endfaellig, tilgungsfreie Zeit,
# Zinsanpassung mit keep_term/keep_tilg_rate/keep_payment, Auszahlungskurs (Disagio),
# Bearbeitungs- und Bereitstellungsgebuehr, Tilgungszuschuss (shorten_term/reduce_installment),
# geplante Sondertilgungen, prepay()/capacity() (Ue3), Bestandsdarlehen (existing).
# validate(): Vertragsfrequenz, Laufzeit, tilgungsfreie Zeit, Tilgungssatz neben fester Rate;
# Wertebereiche (min) im Parameterschema.
# Offen fuer WS-F: amount_eur auto/topup ueber ctx$auto() (Engine WS-D), uebrige
# Kombinationsregeln aus 8.2 (existing, draw_schedule-Summe, refi_rule je Tilgungsart),
# schnellere geschlossene Periodenrechnung (8.1 Nr. 3), Test (h).

#' Parameterschema der Kredittypen (8.2)
#' @param repayment `"annuity"`, `"installment"` oder `"bullet"`.
#' @return benannte Liste von `vofi_param`.
#' @noRd
inst_loan_params <- function(repayment) {
  p <- list(
    amount_eur = vofi_param("amount", required = TRUE, allow_auto = TRUE,
                            deterministic_only = TRUE, unit = "EUR", min = 0),
    approved = vofi_param("value", default = 1),
    existing = vofi_param("logical", default = FALSE),
    installment_eur = vofi_param("amount", unit = "EUR", min = 0),
    rank = vofi_param("integer"),
    start = vofi_param("timing", grid_default = "valuation_date"),
    draw_schedule = vofi_param("schedule", deterministic_only = TRUE),
    rate_pa = vofi_param("rate", required = TRUE),
    payments_per_year = vofi_param("integer", default = 12L),
    term_years = vofi_param("number", deterministic_only = TRUE, min = 0),
    grace_years = vofi_param("number", default = 0, deterministic_only = TRUE, min = 0),
    initial_repayment_pa = vofi_param("rate"),
    fixed_years = vofi_param("number", deterministic_only = TRUE, min = 0),
    followup_rate_pa = vofi_param("value", default = list(ref = "market.mortgage_rate")),
    followup_spread_pa = vofi_param("rate", default = 0),
    followup_fixed_years = vofi_param("number", deterministic_only = TRUE, min = 0),
    refi_rule = vofi_param("enum", values = "vocab:refi_rule"),
    followup_repayment_pa = vofi_param("rate"),
    payout_rate = vofi_param("share", default = 1),
    fees = vofi_param("map", fields = list(
      processing_fee_share = vofi_param("share", default = 0),
      commitment_fee_rate_month = vofi_param("rate", default = 0),
      commitment_free_months = vofi_param("number", default = 0, deterministic_only = TRUE),
      commitment_date = vofi_param("timing")
    )),
    repayment_grant = vofi_param("map", fields = list(
      share = vofi_param("share"),
      amount_eur = vofi_param("value", unit = "EUR"),
      date = vofi_param("timing"),
      year = vofi_param("integer"),
      effect = vofi_param("enum", values = "vocab:repayment_grant_effect",
                          default = "shorten_term"),
      approved = vofi_param("value", default = 1),
      cut_share = vofi_param("share", default = 0)
    )),
    planned_prepayments = vofi_param("schedule", unit = "EUR"),
    prepay_allowed = vofi_param("logical", default = FALSE),
    prepay_cap_share_pa = vofi_param("share", default = 1),
    auto_buffer_share = vofi_param("share", default = 0),
    auto_round_eur = vofi_param("amount", default = 0, deterministic_only = TRUE, min = 0),
    round_payments = vofi_param("logical", default = FALSE)
  )
  if (!identical(repayment, "annuity")) {
    p$initial_repayment_pa <- NULL
    p$followup_repayment_pa <- NULL
  }
  if (identical(repayment, "bullet")) p$installment_eur <- NULL
  p
}

#' Fehler eines Kredittyps (Label types.instrument.<typ>.errors.<code>)
#' @noRd
inst_loan_abort <- function(spec, code, ...) {
  vofi_abort(paste0("types.instrument.", spec$type, ".errors.", code), id = spec$id %||% "?",
             ..., .class = "vofi_error_input")
}

#' Deterministischer Skalar eines Parameters (Basisfall, erster Lauf)
#' @noRd
inst_loan_det <- function(ctx, spec, name) {
  v <- ctx$param_base(spec, name)
  if (is.null(v)) NULL else v[1L]
}

#' Zustand initialisieren (8.3)
#' @param spec Komponente aus `financing`.
#' @param ctx Laufkontext.
#' @param repayment Tilgungsart.
#' @return `vofi_inst_state`.
#' @noRd
inst_loan_init <- function(spec, ctx, repayment) {
  g <- ctx$grid
  n <- ctx$n
  n_t <- g$T + 1L
  me <- g$month_end
  num <- function(name, default) ctx$param(spec, name) %||% rep(default, n)
  existing <- isTRUE(ctx$setting(spec, "existing"))
  amount_node <- path_get(spec, "amount_eur")
  is_auto <- node_is(amount_node) && identical(amount_node$kind, "auto")
  start <- if (existing) g$valuation_date else typ_timing_date(ctx, spec, "start",
                                                               g$valuation_date)
  t_start <- grid_period_of(g, start)
  if (is.na(t_start)) inst_loan_abort(spec, "start_outside", date = start)
  sched <- path_get(spec, "draw_schedule")
  if (is_auto) {
    a <- ctx$auto(spec$id)
    commitment <- as.double(a$commitment)
    draws <- a$draws
    draw_t <- which(colSums(abs(draws)) > 0) - 1L
    if (length(draw_t) == 0L) draw_t <- t_start
  } else {
    commitment <- ctx$param_base(spec, "amount_eur")
    draws <- matrix(0, n, n_t)
    if (existing || is.null(sched) || length(sched$dates) == 0L) {
      if (!existing) draws[, t_start + 1L] <- commitment
      draw_t <- t_start
    } else {
      amt <- ctx$param_base(spec, "draw_schedule", "path")
      share <- identical(sched$unit, "share") ||
        (is.null(sched$unit) && sum(amt[1L, ]) <= 1 + 1e-9)
      draws <- if (share) amt * commitment else amt
      draw_t <- grid_period_of(g, sched$dates)
      draw_t <- draw_t[!is.na(draw_t)]
    }
  }
  t_first <- min(draw_t)
  t_last <- max(draw_t)
  ppy <- as.integer(ctx$setting(spec, "payments_per_year") %||% 12L)
  if (!(ppy %in% c(1L, 4L, 12L))) inst_loan_abort(spec, "ppy", value = ppy)
  term <- inst_loan_det(ctx, spec, "term_years")
  grace <- inst_loan_det(ctx, spec, "grace_years") %||% 0
  tau <- if (identical(repayment, "annuity")) ctx$param(spec, "initial_repayment_pa") else NULL
  if (is.null(term) && (repayment != "annuity" || is.null(tau))) {
    inst_loan_abort(spec, "term_missing")
  }
  m_start <- me[t_start + 1L]
  m_a <- me[t_last + 1L]
  m_rep <- m_a + round(12 * grace)
  m_mat <- if (is.null(term)) Inf else m_a + round(12 * term)
  fixed <- inst_loan_det(ctx, spec, "fixed_years")
  ffix <- inst_loan_det(ctx, spec, "followup_fixed_years")
  big_m <- me[n_t]
  resets <- integer(0)
  if (!is.null(fixed)) {
    r <- m_start + round(12 * fixed)
    step <- if (is.null(ffix)) Inf else round(12 * ffix)
    while (r < big_m && r < m_mat) {
      resets <- c(resets, as.integer(r))
      r <- r + step
    }
  }
  followup <- if (length(resets) > 0L) ctx$param(spec, "followup_rate_pa", "path") else
    matrix(0, n, n_t)
  fee_date <- typ_timing_date(ctx, spec, "fees.commitment_date", start)
  free <- inst_loan_det(ctx, spec, "fees.commitment_free_months") %||% 0
  rg <- path_get(spec, "repayment_grant")
  t_tz <- NA_integer_
  tz_amount <- rep(NA_real_, n)
  if (is_map(rg) && length(rg) > 0L && (!is.null(rg$share) || !is.null(rg$amount_eur))) {
    tz_date <- rg$date %||% if (!is.null(rg$year)) {
      as.Date(sprintf("%04d-01-01", as.integer(rg$year)))
    } else {
      max(g$completion_date, g$date_end[t_last + 1L])
    }
    t_tz <- grid_period_of(g, tz_date)
    attributes(t_tz) <- NULL
    cut <- ctx$param(spec, "repayment_grant.cut_share") %||% rep(0, n)
    appr <- ctx$param(spec, "repayment_grant.approved") %||% rep(1, n)
    if (!is.null(rg$amount_eur)) {
      tz_amount <- ctx$param(spec, "repayment_grant.amount_eur") * appr * (1 - cut)
    }
  }
  planned <- ctx$param(spec, "planned_prepayments", "path") %||% matrix(0, n, n_t)
  installment <- if (identical(repayment, "bullet")) NULL else
    ctx$param_base(spec, "installment_eur")
  refi_rule <- ctx$setting(spec, "refi_rule") %||%
    (if (!is.null(tau)) "keep_tilg_rate" else "keep_term")
  new_vofi_inst_state(list(
    B = rep(0, n), drawn = rep(0, n), commitment = as.double(commitment),
    i_pa = as.double(ctx$param(spec, "rate_pa")), inst = rep(NA_real_, n),
    accrued = rep(0, n), tz_amount = tz_amount, approved = num("approved", 1),
    prepaid_ytd = rep(0, n), tau = if (is.null(tau)) rep(NA_real_, n) else tau,
    neg_amort = rep(FALSE, n),
    repayment = repayment, ppy = ppy, pay_interval = as.integer(12L %/% ppy),
    t_first_draw = as.integer(t_first), m_start = as.integer(m_start), m_A = as.integer(m_a),
    m_rep = as.double(m_rep), m_mat = as.double(m_mat), reset_months = resets,
    fee_free_until = floor(grid_month_pos(g, fee_date) + 1e-9) + free, inst_set = FALSE,
    t_tz = as.integer(t_tz), draws = draws, planned = planned, followup = followup,
    par = list(
      kappa = num("payout_rate", 1), spread = num("followup_spread_pa", 0),
      refi_rule = refi_rule, existing = existing,
      tau2 = ctx$param(spec, "followup_repayment_pa") %||%
        (if (is.null(tau)) rep(NA_real_, n) else tau),
      effect = rg$effect %||% "shorten_term",
      tz_share = if (is_map(rg)) ctx$param(spec, "repayment_grant.share") else NULL,
      tz_cut = if (is_map(rg)) ctx$param(spec, "repayment_grant.cut_share") %||% rep(0, n),
      tz_approved = if (is_map(rg)) ctx$param(spec, "repayment_grant.approved") %||%
        rep(1, n),
      fee_share = ctx$param(spec, "fees.processing_fee_share") %||% rep(0, n),
      fee_rate = ctx$param(spec, "fees.commitment_fee_rate_month") %||% rep(0, n),
      prepay_allowed = isTRUE(ctx$setting(spec, "prepay_allowed")),
      cap_share = num("prepay_cap_share_pa", 1),
      installment = installment,
      round = isTRUE(ctx$setting(spec, "round_payments")),
      has_tz = !is.na(t_tz)
    )
  ))
}

#' Anzahl der Vertragszahlungen in (m, m_mat]
#' @noRd
inst_loan_n_rem <- function(st, m) {
  if (!is.finite(st$m_mat)) return(Inf)
  k_mat <- floor((st$m_mat - st$m_rep) / st$pay_interval)
  k_m <- if (m <= st$m_rep) 0 else floor((m - st$m_rep) / st$pay_interval)
  max(0, k_mat - k_m)
}

#' Annuität aus Bestand, Jahreszins und Restzahl (i = 0: B / n)
#' @noRd
inst_loan_annuity <- function(b, i_pa, ppy, n_rem) {
  i_s <- i_pa / ppy
  out <- b / n_rem
  nz <- abs(i_s) > 1e-15
  out[nz] <- (b * i_s / (1 - (1 + i_s)^(-n_rem)))[nz]
  out
}

#' Erste Rate der Tilgungsphase (8.6, set_installment)
#' @noRd
inst_loan_set_installment <- function(st) {
  p <- st$par
  if (!is.null(p$installment)) return(as.double(p$installment))
  basis <- if (identical(p$effect, "reduce_installment") && isTRUE(p$has_tz)) st$B else
    st$commitment * st$approved
  n_s <- (st$m_mat - st$m_rep) / st$pay_interval
  out <- switch(st$repayment,
    annuity = if (all(!is.na(st$tau))) basis * (st$i_pa + st$tau) / st$ppy else
      inst_loan_annuity(basis, st$i_pa, st$ppy, n_s),
    installment = basis / n_s,
    rep(0, length(basis))
  )
  if (isTRUE(p$round)) out <- round(out, 2)
  out
}

#' Rate nach Zinsanpassung (8.6, refi)
#' @noRd
inst_loan_refi <- function(st, m) {
  rule <- st$par$refi_rule
  i_new <- st$i_pa
  n_rem <- inst_loan_n_rem(st, m - 1)
  out <- st$inst
  if (identical(st$repayment, "annuity")) {
    if (identical(rule, "keep_term")) {
      out <- inst_loan_annuity(st$B, i_new, st$ppy, n_rem)
    } else if (identical(rule, "keep_tilg_rate")) {
      out <- st$B * (i_new + st$par$tau2) / st$ppy
    } else {
      st$neg_amort <- st$neg_amort | (st$inst <= st$B * i_new / st$ppy)
    }
  } else if (identical(st$repayment, "installment") && identical(rule, "keep_term")) {
    out <- if (n_rem > 0) st$B / n_rem else st$B
  }
  if (isTRUE(st$par$round)) out <- round(out, 2)
  st$inst <- out
  st
}

#' Rate nach Tilgungszuschuss mit reduce_installment (8.6, recalc)
#' @noRd
inst_loan_recalc <- function(st, m) {
  n_rem <- inst_loan_n_rem(st, m)
  out <- switch(st$repayment,
    annuity = if (all(!is.na(st$tau))) st$B * (st$i_pa + st$tau) / st$ppy else
      inst_loan_annuity(st$B, st$i_pa, st$ppy, n_rem),
    installment = if (n_rem > 0) st$B / n_rem else st$B,
    st$inst
  )
  if (isTRUE(st$par$round)) out <- round(out, 2)
  out
}

#' Ist Monat m ein Vertragszahlungsmonat?
#' @noRd
inst_loan_pay <- function(st, m) {
  m > st$m_rep && ((m - st$m_rep) %% st$pay_interval) == 0 && m <= st$m_mat
}

#' Ein Schritt des Automaten (8.5)
#' @param state `vofi_inst_state`.
#' @param t Periode.
#' @param ctx Laufkontext.
#' @return `list(state, flows, memo, stocks)` (n-Vektoren, Vorzeichen 8.4).
#' @noRd
inst_loan_step <- function(state, t, ctx) {
  st <- state
  g <- ctx$grid
  n <- length(st$B)
  j <- t + 1L
  z_sum <- r_sum <- rb_sum <- p_sum <- rep(0, n)
  # Nach Faelligkeit ohne Bestand und ohne Bereitstellungszinsen aendert die Monatsuhr nichts
  # (alle Monatsbetraege 0); die Schleife entfaellt dann (Leistung, 8.1 Nr. 3; bitgleich)
  idle <- t >= 1L && g$month_end[j - 1L] + 1L > st$m_mat && all(st$B == 0) &&
    all(st$par$fee_rate * pmax(st$commitment * st$approved - st$drawn, 0) == 0)
  if (t >= 1L && g$months[j] > 0L && !idle) {
    for (m in (g$month_end[j - 1L] + 1L):g$month_end[j]) {
      if ((m - 1L) %in% st$reset_months) {
        jstar <- if (m - 1L <= 0L) 1L else utl_month_period(g, m - 1L) + 1L
        st$i_pa <- st$followup[, jstar] + st$par$spread
        if (st$inst_set) st <- inst_loan_refi(st, m)
      }
      if (m == st$m_rep + 1) st$accrued <- rep(0, n)
      z <- st$B * st$i_pa / 12
      z_sum <- z_sum + z
      st$accrued <- st$accrued + z
      if (m > st$fee_free_until) {
        p_sum <- p_sum + st$par$fee_rate * pmax(st$commitment * st$approved - st$drawn, 0)
      }
      if (inst_loan_pay(st, m)) {
        if (!st$inst_set) {
          st$inst <- inst_loan_set_installment(st)
          st$inst_set <- TRUE
        }
        r <- switch(st$repayment,
          annuity = pmin(pmax(st$inst - st$accrued, 0), st$B),
          installment = pmin(st$inst, st$B),
          rep(0, n)
        )
        st$B <- st$B - r
        r_sum <- r_sum + r
        st$accrued <- rep(0, n)
      }
      if (m == st$m_mat) {
        rb_sum <- rb_sum + st$B
        st$B <- rep(0, n)
      }
      if (m > st$m_start && ((m - st$m_start) %% 12L) == 0L) st$prepaid_ytd <- rep(0, n)
    }
  }
  assumed <- rep(0, n)
  if (isTRUE(st$par$existing) && t == 0L) {
    st$B <- st$commitment
    assumed <- st$commitment
    d <- rep(0, n)
  } else {
    d <- st$draws[, j] * st$approved
    if (t == st$t_first_draw) {
      p_sum <- p_sum + st$par$fee_share * st$commitment * st$approved
    }
  }
  st$B <- st$B + d
  st$drawn <- st$drawn + d
  stp <- pmin(st$planned[, j], st$B,
              pmax(st$par$cap_share * st$commitment - st$prepaid_ytd, 0))
  st$B <- st$B - stp
  st$prepaid_ytd <- st$prepaid_ytd + stp
  tz <- rep(0, n)
  if (!is.na(st$t_tz) && t == st$t_tz) {
    tz_t <- if (all(!is.na(st$tz_amount))) st$tz_amount else
      (st$par$tz_share %||% 0) * pmin(st$commitment, st$drawn) * st$par$tz_approved *
        (1 - st$par$tz_cut)
    tz <- pmin(pmax(tz_t, 0), st$B)
    st$B <- st$B - tz
    if (identical(st$par$effect, "reduce_installment") && st$inst_set) {
      st$inst <- inst_loan_recalc(st, g$month_end[j])
    }
  }
  kappa <- st$par$kappa
  list(
    state = st,
    flows = list(draw = kappa * d, repay = -r_sum, repay_balloon = -rb_sum, prepay = -stp,
                 interest = -z_sum, fees = -p_sum),
    memo = list(repayment_grant = tz, disagio = (1 - kappa) * d, assumed = assumed),
    stocks = list(balance = st$B)
  )
}

#' Zulässige Sondertilgung (8.4, capacity)
#' @noRd
inst_loan_capacity <- function(state, t, ctx) {
  cap_rest <- pmax(state$par$cap_share * state$commitment - state$prepaid_ytd, 0)
  list(balance = state$B, rate_pa = state$i_pa,
       cap = pmin(cap_rest, state$B) * as.double(isTRUE(state$par$prepay_allowed)))
}

#' Sondertilgung buchen (8.4, prepay)
#' @noRd
inst_loan_prepay <- function(state, amount, t, ctx) {
  cap <- inst_loan_capacity(state, t, ctx)$cap
  used <- pmin(pmax(as.double(amount), 0), cap)
  state$B <- state$B - used
  state$prepaid_ytd <- state$prepaid_ytd + used
  list(state = state, used = used, flows = list(prepay = -used))
}

#' Deterministischer Zahlenwert eines normalisierten Parameters (Konstante) bzw. `NULL`
#' @noRd
inst_loan_const <- function(x) {
  if (is.list(x) && identical(x$kind, "const") && is.numeric(x$value)) return(x$value)
  if (is.numeric(x) && length(x) == 1L) return(as.double(x))
  NULL
}

#' Validierung der Kombinationsregeln eines Kredits (8.2, 8.6; Ebene 2/3)
#'
#' Phase-0-Minimalfassung (Eigentümer: WS-F): Vertragsfrequenz, Laufzeit > 0 bzw. Pflicht,
#' tilgungsfreie Zeit kleiner als die Laufzeit, Tilgungssatz neben fester Rate, Wertebereiche
#' der Konstanten prüft val_components() allgemein (min/max des Parameterschemas).
#' @param spec normalisierte Komponente.
#' @param scenario Spezifikation.
#' @param repayment `"annuity"`, `"installment"` oder `"bullet"`.
#' @return Liste von Befunden `list(severity, code, path, args)`.
#' @noRd
inst_loan_validate <- function(spec, scenario, repayment) {
  acc <- new.env(parent = emptyenv())
  acc$out <- list()
  path <- path_join("financing", spec$id)
  key <- function(code) paste0("types.instrument.", spec$type, ".errors.", code)
  add <- function(code, field, ...) {
    acc$out[[length(acc$out) + 1L]] <- list(severity = "error", code = key(code),
                                            path = path_join(path, field),
                                            args = list(id = spec$id, ...))
  }
  ppy <- spec$payments_per_year
  if (!is.null(ppy) && !(ppy %in% c(1L, 4L, 12L))) add("ppy", "payments_per_year", value = ppy)
  term <- inst_loan_const(spec$term_years)
  tau <- spec$initial_repayment_pa
  if (is.null(term) && !(identical(repayment, "annuity") && !is.null(tau)) &&
        !isTRUE(spec$existing)) {
    add("term_missing", "term_years")
  }
  if (!is.null(term) && term <= 0) add("term_nonpositive", "term_years", value = term)
  grace <- inst_loan_const(spec$grace_years) %||% 0
  if (!is.null(term) && term > 0 && grace >= term) {
    add("grace_too_long", "grace_years", value = grace, term = term)
  }
  if (identical(repayment, "annuity") && !is.null(tau) && !is.null(spec$installment_eur)) {
    add("tau_installment", "initial_repayment_pa")
  }
  acc$out
}

#' Typdefinition eines Kredittyps aus dem Kern
#' @noRd
inst_loan_typedef <- function(name, repayment, example) {
  vofi_type(
    name = name, kind = "instrument", params = inst_loan_params(repayment),
    validate = function(spec, scenario) inst_loan_validate(spec, scenario, repayment),
    rows = c("draw", "repay", "repay_balloon", "prepay", "interest", "fees", "repayment_grant",
             "disagio", "assumed", "balance"),
    init = function(spec, ctx) inst_loan_init(spec, ctx, repayment),
    step = function(state, t, ctx) inst_loan_step(state, t, ctx),
    prepay = function(state, amount, t, ctx) inst_loan_prepay(state, amount, t, ctx),
    capacity = function(state, t, ctx) inst_loan_capacity(state, t, ctx),
    repayment = repayment,
    example = example
  )
}
