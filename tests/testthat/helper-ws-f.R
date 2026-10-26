# Testhelfer der Kredittypen (WS-F; Spec 00 Abschnitte 8.3-8.6, 8.10; Spec 01 Teil A 5.6).
# - loan_run(): Kredit über t = 0...T schrittweise rechnen (init/step wie die Engine).
# - loan_ref_clock(): unabhängige skalare Referenz der Monatsuhr (Spec 00 8.5/8.6 wörtlich, eine
#   Schleife über alle Monate, entspricht vref.py bzw. l1.py der Spezifikation) für den Nachweis
#   nach 8.1 Nr. 3 (schnellere Periodenrechnung = Monatsuhr bis 1e-9 relativ).
# Keine Abhängigkeit von anderen Arbeitspaketen außer dem Prüfkit (Integrator) und dem
# Laufkontext eng_context_from_parts() (WS-D, Phase-0-Vertrag 6.1).

#' Texte der Validierungsbefunde validation.financing.<code> der Kredittypen (Spec 00 2.10, R-104)
#'
#' ZULIEFERUNG an WS-B bzw. den Integrator für inst/labels/de/validation.yaml (Block financing):
#' validation.yaml gehört WS-B, deshalb stehen die Texte bis zur Integration hier. Die Tests
#' ergänzen nur Schlüssel, die im Katalog noch fehlen (loan_ensure_validation_labels()); nach der
#' Integration gelten die Texte aus validation.yaml. Den Platzhalter {path} setzt vofi_validate().
loan_validation_labels <- function() {
  c(
    payments_per_year = "'{path}': payments_per_year muss 1, 4 oder 12 sein (erhalten: {value}).",
    amount_nonpositive = "'{path}': der Kreditbetrag muss gr\u00f6\u00dfer als 0 sein.",
    months_fraction = "'{path}' muss ein Vielfaches von 1/12 Jahr sein (erhalten: {value:raw}).",
    term_missing = paste0("'{path}' fehlt (Pflicht bei Raten- und endf\u00e4lligen Darlehen ",
                          "sowie bei Annuit\u00e4tendarlehen ohne initial_repayment_pa und ohne ",
                          "installment_eur)."),
    term_nonpositive = paste0("'{path}': die Laufzeit muss gr\u00f6\u00dfer als 0 sein ",
                              "(erhalten: {value:raw})."),
    grace_too_long = paste0("'{path}': die tilgungsfreie Zeit ({value:raw} Jahre) muss ",
                            "k\u00fcrzer als die Laufzeit ({term:raw} Jahre) sein."),
    fixed_nonpositive = paste0("'{path}': die Zinsbindung muss gr\u00f6\u00dfer als 0 sein ",
                               "(erhalten: {value:raw})."),
    installment_nonpositive = "'{path}': die vertragliche Rate muss gr\u00f6\u00dfer als 0 sein.",
    refi_rule_invalid = paste0("'{path}': {rule} ist bei Ratendarlehen nicht zul\u00e4ssig ",
                               "(keep_term oder keep_payment)."),
    tau_missing = paste0("'{path}': keep_tilg_rate braucht initial_repayment_pa oder ",
                         "followup_repayment_pa."),
    keep_term_needs_term = paste0("'{path}': keep_term braucht eine endliche Laufzeit ",
                                  "term_years (mit vertraglicher Rate ohne Laufzeit nur ",
                                  "keep_payment oder keep_tilg_rate)."),
    rate_path = paste0("'{path}': ein zeitabh\u00e4ngiger Sollzins ist nur bei amount_eur topup ",
                       "zul\u00e4ssig (Spec 00 8.7)."),
    payout_rate_range = paste0("'{path}': der Auszahlungskurs muss gr\u00f6\u00dfer als 0,9 und ",
                               "h\u00f6chstens 1 sein (erhalten: {value:raw})."),
    commitment_date_range = paste0("'{path}': das Zusagedatum {value:date} muss zwischen ",
                                   "Bewertungsstichtag und start liegen."),
    repayment_grant_empty = paste0("'{path}': der Tilgungszuschuss braucht genau eines von ",
                                   "share und amount_eur."),
    repayment_grant_date_year = paste0("'{path}': repayment_grant.date und repayment_grant.year ",
                                       "schlie\u00dfen sich aus."),
    repayment_grant_before_start = "'{path}': der Gutschrifttermin {value:date} liegt vor start.",
    followup_repayment_unused = "'{path}' wirkt nur mit refi_rule keep_tilg_rate.",
    auto_params_unused = "'{path}' wirkt nur mit amount_eur auto oder topup.",
    rate_high = "'{path}': der Sollzins {value:pct} ist ungew\u00f6hnlich hoch.",
    prepay_exceeds = paste0("'{path}': die geplanten Sondertilgungen ({value:eur}) ",
                            "\u00fcbersteigen die Zusage ({amount:eur})."),
    existing_installment_missing = paste0("'{path}' fehlt beim Bestandsdarlehen: die Rate wird ",
                                          "aus der Restlaufzeit berechnet."),
    draw_after_horizon = paste0("'{path}': Auszahlungen ab {value:date} liegen nach dem ",
                                "Horizontende und entfallen; die Tilgung beginnt nach dem ",
                                "Horizont."),
    commitment_fee_window = paste0("'{path}': ohne Auszahlungsplan f\u00e4llt die ",
                                   "Bereitstellungsprovision nur zwischen Zusagedatum und ",
                                   "Vollauszahlung bei start an."),
    fixed_after_horizon = "'{path}': die Zinsbindung ({value:raw} Jahre) endet nach dem Horizont.",
    followup_truncated = paste0("'{path}': die letzte Anschlussbindung ({value:raw} Jahre) ",
                                "reicht \u00fcber die F\u00e4lligkeit hinaus und wird ",
                                "gek\u00fcrzt."),
    prepay_capped = paste0("'{path}': geplante Sondertilgungen \u00fcber prepay_cap_share_pa je ",
                           "Vertragsjahr werden gekappt."),
    repayment_grant_after_horizon = paste0("'{path}': der Gutschrifttermin {value:date} liegt ",
                                           "nach dem Horizontende; der Tilgungszuschuss ",
                                           "entf\u00e4llt.")
  )
}

#' Fehlende Schlüssel validation.financing.* im Label-Katalog ergänzen (nur Tests)
#' @return `invisible(Namen der ergänzten Schlüssel)`.
loan_ensure_validation_labels <- function() {
  labs <- loan_validation_labels()
  added <- character(0)
  for (k in names(labs)) {
    key <- paste0("validation.financing.", k)
    if (!lbl_has(key)) {
      assign(key, enc2utf8(labs[[k]]), envir = lbl_state$labels)
      assign(key, "tests/testthat/helper-ws-f.R", envir = lbl_state$sources)
      added <- c(added, key)
    }
  }
  invisible(added)
}

loan_ensure_validation_labels()

loan_cols <- function() {
  c("draw", "repay", "repay_balloon", "prepay", "interest", "fees", "repayment_grant", "disagio",
    "assumed", "balance")
}

#' Laufkontext für einen Kredit; `auto` = Funktion(id) für ctx$auto() (Attrappe der Engine)
loan_ctx <- function(comp, grid, n = 1L, draws = NULL, params = list(), market = list(),
                     auto = NULL, spec_fun = NULL) {
  spec <- reg_test_spec(grid, market = deep_merge(reg_test_market_raw(), market))
  spec <- path_set(spec, path_join("financing", comp$id), comp)
  for (p in names(params)) spec <- path_set(spec, p, reg_node(params[[p]], p))
  if (is.function(spec_fun)) spec <- spec_fun(spec)
  n <- as.integer(n)
  if (is.null(draws) && n > 1L) draws <- fake_draws(n, grid)
  mode <- if (is.null(draws)) "deterministic" else draws$mode
  eng_context_from_parts(grid, spec, draws = draws, mode = mode,
                         engine_env = reg_engine_env("balance", auto = auto))
}

#' Kredit rechnen: Rückgabe `list(m = list(<zeile> = n x (T+1)), state, states, ctx, comp)`
loan_run <- function(type, ..., grid = make_grid("annual", T = 10L), n = 1L, draws = NULL,
                     params = list(), market = list(), auto = NULL, id = "k", spec_fun = NULL,
                     prepay_at = NULL) {
  comp <- make_component(type, ..., id = id)
  ctx <- loan_ctx(comp, grid, n = n, draws = draws, params = params, market = market,
                  auto = auto, spec_fun = spec_fun)
  def <- reg_get("instrument", type)
  st <- def$init(comp, ctx)
  n <- ctx$n
  m <- stats::setNames(lapply(loan_cols(), function(x) matrix(0, n, grid$T + 1L)), loan_cols())
  states <- list()
  for (t in 0:grid$T) {
    r <- def$step(st, t, ctx)
    st <- r$state
    for (x in names(r$flows)) m[[x]][, t + 1L] <- r$flows[[x]]
    for (x in names(r$memo)) m[[x]][, t + 1L] <- r$memo[[x]]
    m$balance[, t + 1L] <- r$stocks$balance
    if (!is.null(prepay_at) && !is.null(prepay_at[[as.character(t)]])) {
      p <- def$prepay(st, prepay_at[[as.character(t)]], t, ctx)
      st <- p$state
      m$prepay[, t + 1L] <- m$prepay[, t + 1L] + p$flows$prepay
      m$balance[, t + 1L] <- def$capacity(st, t, ctx)$balance
    }
    states[[t + 1L]] <- st
  }
  list(m = m, state = st, states = states, ctx = ctx, comp = comp)
}

#' Zeile einer Größe (Lauf i) als Vektor über t = 0...T
loan_row <- function(run, what, i = 1L) run$m[[what]][i, ]

#' Annuität (Zins + Tilgung) der Periode t, Lauf i
loan_payment <- function(run, t, i = 1L) {
  -(run$m$interest[i, t + 1L] + run$m$repay[i, t + 1L])
}

#' Unabhängige skalare Monatsuhr (Spec 00 8.5, 8.6; Spec 01 Teil A 5.2)
#'
#' `a` sind die Rohparameter wie in YAML (Daten als Zeichenketten), Zinsen als Zahlen;
#' `followup` = Anschlusszinspfad als Vektor der Länge T+1 (Spalte = Periode) bzw. Zahl;
#' `prepay_at` = regelbasierte Sondertilgungen (Ü3) am Periodenende wie in loan_run()
#' (`list("<t>" = Betrag)`, begrenzt auf die Obergrenze je Vertragsjahr und den Bestand).
#' @return Matrix (T+1) x 10 mit den Spalten loan_cols().
loan_ref_clock <- function(grid, type, a, followup = a$followup_rate_pa %||% 0.04,
                           prepay_at = NULL) {
  g <- grid
  big_t <- g$T
  n_t <- big_t + 1L
  me <- g$month_end
  m_end <- me[n_t]
  per <- function(d) as.integer(grid_period_of(g, as.Date(d)))
  repay <- sub("_loan$", "", type)
  existing <- isTRUE(a$existing)
  amount <- a$amount_eur
  approved <- if (existing) 1 else a$approved %||% 1
  ppy <- a$payments_per_year %||% 12L
  pint <- 12L %/% ppy
  start <- as.Date(a$start %||% g$valuation_date)
  t_start <- per(start)
  dd <- numeric(n_t)
  draw_t <- integer(0)
  if (!existing) {
    if (is.null(a$draw_schedule)) {
      dd[t_start + 1L] <- amount
      draw_t <- t_start
    } else {
      s <- a$draw_schedule
      for (nm in names(s$schedule)) {
        tt <- per(nm)
        if (is.na(tt)) next                          # nach dem Horizont: entfällt
        v <- s$schedule[[nm]]
        if (identical(s$unit, "share")) v <- v * amount
        dd[tt + 1L] <- dd[tt + 1L] + v
        draw_t <- c(draw_t, tt)
      }
    }
  }
  t_first <- if (existing) 0L else min(draw_t)
  t_last <- if (existing) 0L else max(draw_t)
  m_start <- if (existing) 0 else me[t_start + 1L]
  m_a <- if (existing) 0 else me[t_last + 1L]
  d_last <- g$date_end[t_last + 1L]
  if (!existing && !is.null(a$draw_schedule)) {
    d_max <- max(as.Date(names(a$draw_schedule$schedule)))
    if (d_max > g$date_end[n_t]) {
      # letzter Termin nach dem Horizont: m_A = Monatsindex des Termins (Tilgung danach)
      m_a <- grid_months_between(g$valuation_date, d_max)
      d_last <- d_max
    }
  }
  grace <- if (existing) 0 else a$grace_years %||% 0
  m_rep <- m_a + round(12 * grace)
  m_mat <- if (is.null(a$term_years)) Inf else m_a + round(12 * a$term_years)
  resets <- numeric(0)
  if (!is.null(a$fixed_years)) {
    r <- m_start + round(12 * a$fixed_years)
    repeat {
      if (r >= m_mat || r >= m_end) break
      resets <- c(resets, r)
      if (is.null(a$followup_fixed_years)) break
      r <- r + round(12 * a$followup_fixed_years)
    }
  }
  fu <- if (length(followup) == 1L) rep(followup, n_t) else followup
  spread <- a$followup_spread_pa %||% 0
  tau <- a$initial_repayment_pa
  has_tau <- !is.null(tau)
  rule <- a$refi_rule %||% (if (has_tau) "keep_tilg_rate" else "keep_term")
  tau2 <- a$followup_repayment_pa %||% tau
  kappa <- a$payout_rate %||% 1
  fees <- a$fees %||% list()
  fee_share <- fees$processing_fee_share %||% 0
  fee_rate <- fees$commitment_fee_rate_month %||% 0
  cdate <- as.Date(fees$commitment_date %||% start)
  fee_free_until <- grid_months_between(g$valuation_date, cdate) +
    (fees$commitment_free_months %||% 0)
  rg <- a$repayment_grant
  has_tz <- !is.null(rg) && !existing
  effect <- rg$effect %||% "shorten_term"
  t_tz <- NA_integer_
  if (has_tz) {
    tz_date <- if (!is.null(rg$date)) as.Date(rg$date) else if (!is.null(rg$year)) {
      as.Date(sprintf("%04d-01-01", as.integer(rg$year)))
    } else {
      max(g$completion_date, d_last)
    }
    t_tz <- per(tz_date)
  }
  planned <- numeric(n_t)
  if (!is.null(a$planned_prepayments)) {
    for (nm in names(a$planned_prepayments$schedule)) {
      tt <- per(nm)
      planned[tt + 1L] <- planned[tt + 1L] + a$planned_prepayments$schedule[[nm]]
    }
  }
  cap <- a$prepay_cap_share_pa %||% 1
  # Zuschlag 1e-7 Cent wie inst_loan_round(): Halbcent-Grenzen unabhängig vom letzten Bit
  rnd <- function(x) if (isTRUE(a$round_payments)) floor(100 * x + 0.5 + 1e-7) / 100 else x
  n_rem <- function(m) {
    if (!is.finite(m_mat)) return(Inf)
    k <- seq_len(m_mat)
    sum(k > m & k > m_rep & ((k - m_rep) %% pint) == 0)
  }
  ann <- function(b, i_s, nn) if (abs(i_s) < 1e-15) b / nn else b * i_s / (1 - (1 + i_s)^(-nn))
  n_star <- function(b, inst, i_old) {
    if (is.na(inst) || inst <= 0) return(Inf)
    if (repay == "installment") return(b / inst)
    i_s <- i_old / ppy
    if (abs(i_s) < 1e-15) return(b / inst)
    x <- 1 - b * i_s / inst
    if (x <= 0) Inf else -log(x) / log(1 + i_s)
  }
  b <- 0
  drawn <- 0
  i <- a$rate_pa
  inst <- NA_real_
  inst_set <- FALSE
  accrued <- 0
  ytd <- 0
  cur_tau <- tau
  out <- matrix(0, n_t, 10L, dimnames = list(NULL, loan_cols()))
  for (t in 0:big_t) {
    z_sum <- r_sum <- rb_sum <- p_sum <- 0
    if (t >= 1L && g$months[t + 1L] > 0L) {
      for (m in (me[t] + 1L):me[t + 1L]) {
        if ((m - 1) %in% resets) {
          jstar <- which(me >= m - 1)[1L]
          i_new <- fu[jstar] + spread
          if (inst_set && repay != "bullet") {
            shorten <- has_tz && effect == "shorten_term" && !is.na(t_tz) && t_tz < t
            if (rule == "keep_term") {
              nr <- n_rem(m - 1)
              if (shorten) nr <- min(nr, ceiling(n_star(b, inst, i) - 1e-9))
              nr <- max(nr, 1)
              inst <- rnd(if (repay == "annuity") ann(b, i_new / ppy, nr) else b / nr)
            } else if (rule == "keep_tilg_rate" && repay == "annuity") {
              inst <- rnd(b * (i_new + tau2) / ppy)
              cur_tau <- tau2
            }
          }
          i <- i_new
        }
        if (m == m_rep + 1) accrued <- 0
        z <- b * i / 12
        z_sum <- z_sum + z
        accrued <- accrued + z
        if (m > fee_free_until) p_sum <- p_sum + fee_rate * max(amount * approved - drawn, 0)
        if (m > m_rep && ((m - m_rep) %% pint) == 0 && m <= m_mat) {
          if (!inst_set) {
            basis <- if (has_tz && effect == "reduce_installment") b else amount * approved
            # n_s = (m_mat - m_rep) / pay_interval (Spec 00 8.6), auch wenn die Division nicht
            # aufgeht (Rest als Schlusstilgung bei Fälligkeit)
            n_s <- max((m_mat - m_rep) / pint, 1)
            inst <- if (!is.null(a$installment_eur)) a$installment_eur else
              rnd(switch(repay,
                         annuity = if (has_tau) basis * (i + tau) / ppy else
                           ann(basis, i / ppy, n_s),
                         installment = basis / n_s, 0))
            inst_set <- TRUE
          }
          r <- switch(repay, annuity = min(max(inst - accrued, 0), b),
                      installment = min(inst, b), 0)
          b <- b - r
          r_sum <- r_sum + r
          accrued <- 0
        }
        if (m == m_mat) {
          rb_sum <- rb_sum + b
          b <- 0
        }
        if ((m - m_start) > 0 && ((m - m_start) %% 12) == 0) ytd <- 0
      }
    }
    assumed <- 0
    d <- 0
    if (existing) {
      if (t == 0L) {
        b <- amount
        assumed <- amount
      }
    } else {
      d <- dd[t + 1L] * approved
      if (t == t_first) p_sum <- p_sum + fee_share * amount * approved
    }
    b <- b + d
    drawn <- drawn + d
    stp <- min(planned[t + 1L], b, max(cap * amount - ytd, 0))
    b <- b - stp
    ytd <- ytd + stp
    tz <- 0
    if (has_tz && !is.na(t_tz) && t == t_tz) {
      fac <- (rg$approved %||% 1) * (1 - (rg$cut_share %||% 0))
      tz_t <- if (!is.null(rg$amount_eur)) rg$amount_eur * fac else
        rg$share * min(amount, drawn) * fac
      tz <- min(max(tz_t, 0), b)
      b <- b - tz
      if (effect == "reduce_installment" && inst_set) {
        nr <- n_rem(me[t + 1L])
        inst <- rnd(switch(repay,
                           annuity = if (has_tau) b * (i + cur_tau) / ppy else
                             ann(b, i / ppy, max(nr, 1)),
                           installment = b / max(nr, 1), inst))
      }
    }
    u3 <- 0
    if (!is.null(prepay_at[[as.character(t)]]) && isTRUE(a$prepay_allowed)) {
      u3 <- min(max(prepay_at[[as.character(t)]], 0), max(cap * amount - ytd, 0), b)
      b <- b - u3
      ytd <- ytd + u3
    }
    out[t + 1L, ] <- c(kappa * d, -r_sum, -rb_sum, -stp - u3, -z_sum, -p_sum, tz,
                       (1 - kappa) * d, assumed, b)
  }
  out
}

#' Prüfwert gegen einen gerundeten Tabellenwert (Spec 01 Teil A: 0,005 EUR absolut)
expect_near <- function(object, expected, tol = 0.005) {
  lab <- deparse(substitute(object))
  ok <- length(object) == length(expected) && all(abs(object - expected) <= tol)
  testthat::expect(ok, sprintf("%s = %s, erwartet %s (Toleranz %s)", lab,
                               paste(format(object, nsmall = 4), collapse = ", "),
                               paste(format(expected, nsmall = 4), collapse = ", "), tol))
  invisible(object)
}

#' Alle Meldungen eines Ausdrucks abfangen; Rückgabe `list(value, keys)` (Label-Schlüssel)
loan_capture_msgs <- function(expr) {
  keys <- character(0)
  value <- withCallingHandlers(expr, message = function(m) {
    keys <<- c(keys, m$key %||% conditionMessage(m))
    invokeRestart("muffleMessage")
  })
  list(value = value, keys = keys)
}

#' Codes der Befunde einer Validierung (validate() des Typs, ohne Präfix validation.financing.)
loan_val_codes <- function(type, ..., spec_fun = NULL, grid = make_grid("annual", T = 10L)) {
  comp <- make_component(type, ..., id = "k")
  spec <- reg_test_spec(grid)
  spec <- path_set(spec, "financing.k", comp)
  if (is.function(spec_fun)) spec <- spec_fun(spec)
  fd <- reg_get("instrument", type)$validate(comp, spec)
  vapply(fd, function(f) sub("^validation\\.financing\\.", "", f$code), "")
}

#' Ergebnis von loan_run() (Lauf i) als Matrix (T+1) x 10 wie loan_ref_clock()
loan_as_matrix <- function(run, i = 1L) {
  out <- vapply(loan_cols(), function(x) run$m[[x]][i, ], numeric(ncol(run$m$balance)))
  if (is.null(dim(out))) out <- matrix(out, nrow = 1L, dimnames = list(NULL, loan_cols()))
  out
}
