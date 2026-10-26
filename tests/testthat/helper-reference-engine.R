# Skalare Referenz-Engine, Übersetzung von Modellen und Zufallsszenarien (WS-T; Spec 00
# Abschnitte 8, 9.3-9.5, 12, 15.1, 15.4 G, 15.6 "Differenztests"; Memo 01 §3, §4).
#
# Zweite, unabhängige Implementierung des Rechenkerns für Differenztests: einfache Schleifen je
# Lauf, Periode und Monat, geschrieben ausschließlich nach Spec 00 §8 (Monatsuhr der Kredite,
# Konten, Ausgleichsaktionen), §9.3-9.5 (Periodenalgorithmus, Terminalzustand ohne Restwert,
# Unterlassungsalternative) und §12 (Kennzahlen). Sie ruft keine Funktion der Engine
# (R/engine-*.R, R/account-actions.R, R/type-inst-*.R) auf und verwendet nur Basis-R. Nur die
# Übersetzung spec_simple_from_model() liest Vertragsobjekte des Pakets (vofi_model, vofi_spec,
# vofi_grid, vofi_flows, vofi_result; Spec 00 §3.2, §4.13, §7, §13).
#
# Eingabe der Referenz-Engine (spec_simple), alle Beträge in EUR, Raten p. a.:
#   n             Anzahl der Läufe
#   months        Periodenlängen in Monaten (Länge T+1, months[1] = 0)
#   year, op_year, op_year_full, phase   Rasterangaben (Länge T+1, Spec 00 §3.2)
#   rows          exogene Zeilen: list(<key> = list(values = n x (T+1), section, category, cash,
#                 rv_basis)) (Zahlungskomponenten, geplantes Eigenkapital, Merkzeilen)
#   loans         list(<k> = Kreditparameter, siehe ref_loan_init())
#   accounts      list(deposit_rate_pa, overdraft_rate_pa, penalty_spread_pa, overdraft_limit_eur,
#                 min_liquidity_eur, allowance_pa (Pfade: Skalar, Zeitvektor T+1 oder n x (T+1)),
#                 withholding, flag_threshold, prepay_buffer, prepay_min_spread (Skalar oder n),
#                 surplus, deficit (Ketten))
#   existing_value, sale_cost_share, bestand   Sacheinlage (R-68) und Bestandsprojekt (12.3a)
#   analysis      list(dscr_threshold, stabilization_year, haircut, rv_path_basis)
#   inflation     NULL oder Pfad (Zeitvektor bzw. n x (T+1)) für terminal_value_real
#   kpis          NULL (alle) oder Namen der Kennzahlen (ohne Suffix _ex_rv)
#   wd_tol        Toleranz des Entnahme-Äquivalents (Default 1e-10)

# Bezeichner folgen bewusst der Notation der Spec (L, M, B, T, E, BS, EW, NS, ...), damit die
# Referenz-Engine Zeile für Zeile gegen Spec 00 §8/§9/§12 gelesen werden kann.
# nolint start: object_name_linter.

ref_zero <- 1e-9

#' Kategorien mit noi = TRUE (Spec 00 7.6) als "section/category"
ref_noi_keys <- c("project/rent", "project/rent_loss", "project/modernization_levy",
                  "project/operating_income", "project/operating_cost", "project/property_tax",
                  "project/maintenance", "project/energy_cost", "project/co2_cost",
                  "project/energy_income", "project/energy_saving", "project/other_cost",
                  "grants/operating_subsidy")

#' Projektarten der Bestandsprojekte (Spec 00 1.5, 12.3a)
ref_bestand_types <- c("sanierung_eh", "sanierung_einzelmassnahmen", "sanierung_stufenweise",
                       "heizungstausch")

#' Kennzahlen der Referenz-Engine (Spec 00 12.3): mit Restwertvariante bzw. ohne
ref_kpi_rv <- c("terminal_value", "delta_terminal_value", "roe_classic", "roe_mirr", "roe_irr",
                "payback_time", "payback_year", "min_net_liquidity", "max_overdraft",
                "max_financing_need", "withdrawal_equivalent", "terminal_value_real")
ref_kpi_plain <- c("terminal_value_opp", "sum_equity_calls", "pv_equity_calls",
                   "flag_shortfall", "flag_limit_breach", "flag_reserve_used", "dscr_min",
                   "dscr_mean", "dscr_years_below", "dscr_min_new", "icr_min", "ltv_max",
                   "ltv_end", "lending_ratio_max", "npv_cf_project", "irr_cf_project",
                   "own_contribution", "pv_subsidies", "co2_emissions")

#' Kennzahlen, die bei gestopptem Lauf NA "run_stopped" sind (wertbasiert, 12.1)
ref_kpi_stopped <- c("terminal_value", "delta_terminal_value", "roe_classic", "roe_mirr",
                     "roe_irr", "payback_time", "payback_year", "withdrawal_equivalent",
                     "terminal_value_real")

#' Engine-Zeilen der Referenz (Spec 00 7.7)
ref_engine_keys <- c("equity_call", "shortfall", "equity_in_kind", "od_draw", "od_repay",
                     "od_interest", "od_balance", "odp_draw", "odp_repay", "odp_interest",
                     "odp_balance", "dep_invest", "dep_withdraw", "dep_interest", "dep_wht",
                     "dep_balance", "tax", "tax_liability", "balance_check", "net_position")

#' Kreditzeilen (Spec 00 8.4)
ref_loan_keys <- c("draw", "repay", "repay_balloon", "prepay", "interest", "fees",
                   "repayment_grant", "disagio", "assumed", "balance")
ref_loan_cash <- c("draw", "repay", "repay_balloon", "prepay", "interest", "fees")

# ---------------------------------------------------------------------------------------------
# 1. Hilfen
# ---------------------------------------------------------------------------------------------

#' Element i eines Skalars oder n-Vektors
ref_el <- function(x, i) if (length(x) > 1L) x[[i]] else x

#' Zeile i eines Pfads: Skalar, Zeitvektor der Länge T+1 oder Matrix n x (T+1)
ref_path_row <- function(x, i, t1) {
  if (is.null(x)) return(NULL)
  if (is.matrix(x)) return(as.double(x[i, ]))
  if (length(x) == 1L) return(rep(as.double(x), t1))
  if (length(x) == t1) return(as.double(x))
  stop("ref_path_row: Pfad hat weder Laenge 1 noch T+1", call. = FALSE)
}

#' Kaufmännische Rundung auf Cent (round_payments, Spec 01 Teil A 5.2)
ref_round_cent <- function(x) floor(100 * x + 0.5) / 100

#' Vorzeichenwechsel einer Zahlungsreihe (Nullen und |c| <= zero_abs übergangen)
ref_sign_changes <- function(cf) {
  s <- sign(cf[abs(cf) > ref_zero])
  if (length(s) < 2L) return(0L)
  sum(s[-1L] != s[-length(s)])
}

#' Interner Zinsfuß mit Bisektion auf [-0.99, 1] (Spec 00 12.3) -> list(value, na)
ref_irr <- function(cf, tau) {
  if (ref_sign_changes(cf) > 1L) return(list(value = NA_real_, na = "irr_ambiguous"))
  f <- function(r) sum(cf * (1 + r)^(-tau))
  lo <- -0.99
  hi <- 1
  flo <- f(lo)
  fhi <- f(hi)
  if (!is.finite(flo) || !is.finite(fhi) || flo * fhi > 0) {
    return(list(value = NA_real_, na = "irr_out_of_range"))
  }
  for (k in seq_len(300L)) {
    mid <- (lo + hi) / 2
    fm <- f(mid)
    if ((fm > 0) == (flo > 0)) {
      lo <- mid
      flo <- fm
    } else {
      hi <- mid
    }
    if (hi - lo < 1e-14) break
  }
  list(value = (lo + hi) / 2, na = NA_character_)
}

# ---------------------------------------------------------------------------------------------
# 2. Kredite: Monatsuhr (Spec 00 8.3, 8.5, 8.6)
# ---------------------------------------------------------------------------------------------

#' Zustand eines Kredits für Lauf i
#'
#' Parameter `L` (deterministische Termine als Monate ab Stichtag bzw. Perioden):
#' `id`, `repayment` ("annuity"/"installment"/"bullet"), `commitment` (Nennbetrag D, fest),
#' `approved` (n), `existing` (lgl), `installment_eur` (NA oder Betrag), `draws` (Nennbeträge
#' je Periode, Länge T+1), `t_first_draw`, `m_A`, `m_start`, `rate_pa` (n), `ppy`,
#' `term_months` (Inf ohne Laufzeit), `grace_months`, `tau` (n oder NA), `fixed_months`,
#' `followup_fixed_months` (NA = eine Anschlussbindung), `followup` (Anschlusszinspfad ohne
#' Spread), `spread` (n), `refi_rule`, `tau_followup` (n), `payout` (n),
#' `processing_fee_share` (n), `fee_rate` (Bereitstellungsprovision je Monat, n),
#' `fee_free_until` (Monat), `tz` (NULL oder list(type = "amount"/"share", value, t, approved,
#' cut, effect)), `planned` (geplante Sondertilgungen je Periode), `prepay_allowed`,
#' `cap_share` (n), `round` (lgl).
ref_loan_init <- function(L, i, M) {
  t1 <- length(M)
  e <- function(x, default) {
    if (is.null(x)) default else ref_el(x, i)
  }
  tau <- e(L$tau, NA_real_)
  p <- list(
    id = L$id, repayment = L$repayment, commitment = as.double(L$commitment),
    approved = e(L$approved, 1), existing = isTRUE(L$existing),
    installment_eur = e(L$installment_eur, NA_real_),
    draws = if (is.null(L$draws)) c(as.double(L$commitment), rep(0, t1 - 1L)) else
      as.double(L$draws),
    t_first_draw = L$t_first_draw %||% 0L, m_A = L$m_A %||% 0L, m_start = L$m_start %||% 0L,
    ppy = as.integer(L$ppy %||% 12L), term = as.double(L$term_months %||% Inf),
    grace = as.double(L$grace_months %||% 0), tau = tau, spread = e(L$spread, 0),
    refi_rule = L$refi_rule %||% (if (is.na(tau)) "keep_term" else "keep_tilg_rate"),
    tau_followup = e(L$tau_followup, tau), payout = e(L$payout, 1),
    pfs = e(L$processing_fee_share, 0), fee_rate = e(L$fee_rate, 0),
    fee_free_until = as.double(L$fee_free_until %||% 0),
    planned = if (is.null(L$planned)) rep(0, t1) else ref_path_row(L$planned, i, t1),
    prepay_allowed = isTRUE(L$prepay_allowed), cap_share = e(L$cap_share, 1),
    round = isTRUE(L$round)
  )
  p$followup <- if (is.null(L$followup)) rep(0, t1) else ref_path_row(L$followup, i, t1)
  p$pi <- 12L %/% p$ppy
  p$m_rep <- p$m_A + p$grace
  p$m_mat <- p$m_A + p$term
  fm <- L$fixed_months %||% NA_real_
  ffm <- L$followup_fixed_months %||% NA_real_
  p$reset <- numeric(0)
  if (!is.na(fm)) {
    r0 <- p$m_start + fm
    r <- if (is.na(ffm) || r0 >= M[t1]) r0 else seq(r0, M[t1], by = ffm)
    p$reset <- r[r > 0 & r < p$m_mat & r < M[t1]]
  }
  if (!is.null(L$tz)) {
    p$tz <- list(type = L$tz$type, value = ref_el(L$tz$value, i),
                 t = if (is.null(L$tz$t)) NA_integer_ else as.integer(L$tz$t),
                 approved = e(L$tz$approved, 1), cut = e(L$tz$cut, 0),
                 effect = L$tz$effect %||% "shorten_term")
  }
  list(par = p, B = 0, drawn = 0, i_pa = ref_el(L$rate_pa, i), inst = NA_real_,
       inst_set = FALSE, accrued = 0, prepaid_ytd = 0, neg_amort = FALSE, ex_prepay = 0,
       last = NULL)
}

#' Vertragszahlungsmonat (8.3)
ref_loan_pay <- function(p, m) {
  m > p$m_rep && ((m - p$m_rep) %% p$pi == 0) && m <= p$m_mat
}

#' Anzahl der Vertragszahlungsmonate in (m, m_mat] (8.3)
ref_loan_n_rem <- function(p, m) {
  if (!is.finite(p$m_mat)) return(Inf)
  first <- p$m_rep + p$pi
  if (first > p$m_mat) return(0)
  k <- seq(first, p$m_mat, by = p$pi)
  sum(k > m)
}

#' Rate bei der ersten Vertragszahlung der Tilgungsphase (8.6, set_installment)
ref_loan_set_inst <- function(st) {
  p <- st$par
  has_ri <- !is.null(p$tz) && identical(p$tz$effect, "reduce_installment")
  basis <- if (has_ri) st$B else p$commitment * p$approved
  n_s <- (p$m_mat - p$m_rep) / p$pi
  inst <- if (!is.na(p$installment_eur)) {
    p$installment_eur
  } else if (p$repayment == "annuity") {
    if (!is.na(p$tau)) {
      basis * (st$i_pa + p$tau) / p$ppy
    } else {
      i_s <- st$i_pa / p$ppy
      if (i_s == 0) basis / n_s else basis * i_s / (1 - (1 + i_s)^(-n_s))
    }
  } else if (p$repayment == "installment") {
    basis / n_s
  } else {
    0
  }
  if (p$round) inst <- ref_round_cent(inst)
  inst
}

#' Rate nach einer Zinsanpassung (8.6, refi), m = Monat der Anpassung, t = Periode
ref_loan_refi <- function(st, i_old, m, t) {
  p <- st$par
  if (p$repayment == "bullet") return(st)
  B <- st$B
  i_new <- st$i_pa
  if (p$refi_rule == "keep_term") {
    n <- ref_loan_n_rem(p, m - 1)
    if (!is.null(p$tz) && identical(p$tz$effect, "shorten_term") && !is.na(p$tz$t) &&
          p$tz$t < t) {
      # R-100: effektive Restzahl nach Laufzeitverkürzung durch Tilgungszuschuss
      i0 <- i_old / p$ppy
      n_star <- if (p$repayment == "annuity") {
        if (i0 == 0) B / st$inst else if (st$inst <= B * i0) Inf else
          -log(1 - B * i0 / st$inst) / log(1 + i0)
      } else {
        B / st$inst
      }
      n <- min(n, ceiling(n_star - 1e-9))
    }
    if (n >= 1) {
      if (p$repayment == "annuity") {
        i_s <- i_new / p$ppy
        st$inst <- if (i_s == 0) B / n else B * i_s / (1 - (1 + i_s)^(-n))
      } else {
        st$inst <- B / n
      }
    }
  } else if (p$refi_rule == "keep_tilg_rate") {
    if (p$repayment == "annuity") st$inst <- B * (i_new + p$tau_followup) / p$ppy
  } else if (p$refi_rule == "keep_payment") {
    if (p$repayment == "annuity" && st$inst <= B * i_new / p$ppy) st$neg_amort <- TRUE
  } else {
    stop("ref_loan_refi: unbekannte refi_rule ", p$refi_rule, call. = FALSE)
  }
  if (p$round) st$inst <- ref_round_cent(st$inst)
  st
}

#' Neuberechnung der Rate nach Tilgungszuschuss mit reduce_installment (8.6, recalc)
ref_loan_recalc <- function(st, m_end) {
  p <- st$par
  B <- st$B
  if (p$repayment == "annuity") {
    if (!is.na(p$tau)) {
      st$inst <- B * (st$i_pa + p$tau) / p$ppy
    } else {
      n <- ref_loan_n_rem(p, m_end)
      i_s <- st$i_pa / p$ppy
      if (n >= 1) st$inst <- if (i_s == 0) B / n else B * i_s / (1 - (1 + i_s)^(-n))
    }
  } else if (p$repayment == "installment") {
    n <- ref_loan_n_rem(p, m_end)
    if (n >= 1) st$inst <- B / n
  }
  if (p$round) st$inst <- ref_round_cent(st$inst)
  st
}

#' Schritt der Periode t (Spec 00 8.5); M = month_end je Spalte (M[1] = 0)
ref_loan_step <- function(st, t, M) {
  p <- st$par
  Z <- 0
  R <- 0
  RB <- 0
  P <- 0
  if (t >= 1L) {
    for (m in seq.int(M[t] + 1, M[t + 1L])) {
      if (any(p$reset == m - 1)) {                               # (a) Zinsanpassung
        jstar <- which(M >= m - 1)[1L]
        i_old <- st$i_pa
        st$i_pa <- p$followup[jstar] + p$spread
        if (st$inst_set) st <- ref_loan_refi(st, i_old, m, t)
      }
      if (m == p$m_rep + 1) st$accrued <- 0                      # (b) Beginn Tilgungsphase
      z <- st$B * st$i_pa / 12                                    # (c) Monatszins
      Z <- Z + z
      st$accrued <- st$accrued + z
      if (m > p$fee_free_until) {                                 # (d) Bereitstellungsprovision
        P <- P + p$fee_rate * max(p$commitment * p$approved - st$drawn, 0)
      }
      if (ref_loan_pay(p, m)) {                                   # (e) Vertragszahlung
        if (!st$inst_set) {
          st$inst <- ref_loan_set_inst(st)
          st$inst_set <- TRUE
        }
        r <- switch(
          p$repayment,
          annuity = min(max(st$inst - st$accrued, 0), st$B),
          installment = min(st$inst, st$B),
          0
        )
        st$B <- st$B - r
        R <- R + r
        st$accrued <- 0
      }
      if (m == p$m_mat) {                                         # (f) Schlusstilgung
        RB <- RB + st$B
        st$B <- 0
      }
      if (m > p$m_start && (m - p$m_start) %% 12 == 0) st$prepaid_ytd <- 0   # (g)
    }
  }
  D <- 0
  assumed <- 0
  if (p$existing && t == 0L) {                                    # (h) Bestandsdarlehen
    st$B <- p$commitment
    assumed <- p$commitment
  } else {
    D <- p$draws[t + 1L] * p$approved
    if (t == p$t_first_draw) P <- P + p$pfs * p$commitment * p$approved
    st$B <- st$B + D
    st$drawn <- st$drawn + D
  }
  ST <- min(p$planned[t + 1L], st$B, max(p$cap_share * p$commitment - st$prepaid_ytd, 0))
  st$B <- st$B - ST                                               # (i) geplante Sondertilgung
  st$prepaid_ytd <- st$prepaid_ytd + ST
  TZ <- 0
  if (!is.null(p$tz) && !is.na(p$tz$t) && t == p$tz$t) {          # (j) Tilgungszuschuss
    tz_t <- if (p$tz$type == "amount") {
      p$tz$value * p$tz$approved * (1 - p$tz$cut)
    } else {
      p$tz$value * min(p$commitment, st$drawn) * p$tz$approved * (1 - p$tz$cut)
    }
    TZ <- min(tz_t, st$B)
    st$B <- st$B - TZ
    if (identical(p$tz$effect, "reduce_installment") && st$inst_set) {
      st <- ref_loan_recalc(st, M[t + 1L])
    }
  }
  st$last <- c(draw = p$payout * D, repay = -R, repay_balloon = -RB, prepay = -ST,
               interest = -Z, fees = -P, repayment_grant = TZ, disagio = (1 - p$payout) * D,
               assumed = assumed, balance = st$B)
  st
}

#' Zulässige Sondertilgung (8.4 capacity)
ref_loan_cap <- function(st) {
  p <- st$par
  if (!p$prepay_allowed) return(0)
  min(max(p$cap_share * p$commitment - st$prepaid_ytd, 0), st$B)
}

#' Kreditpläne ohne Ausgleichsabhängigkeit (Instrument-Cache, 9.3)
ref_loan_schedules <- function(loans, M) {
  lapply(loans, function(st) {
    out <- matrix(0, length(M), length(ref_loan_keys), dimnames = list(NULL, ref_loan_keys))
    for (j in seq_along(M)) {
      st <- ref_loan_step(st, j - 1L, M)
      out[j, ] <- st$last[ref_loan_keys]
    }
    list(rows = out, state = st)
  })
}

# ---------------------------------------------------------------------------------------------
# 3. Konten, Ausgleichsaktionen, Periodenschleife (Spec 00 8.8, 8.9, 9.3, 9.4)
# ---------------------------------------------------------------------------------------------

#' Kontoparameter für Lauf i (8.8); sp_is_s: Strafzinstranche zum Regelzins (9.5 Nr. 5)
ref_accounts <- function(A, i, months, sp_is_s = FALSE) {
  t1 <- length(months)
  delta <- months / 12
  row <- function(x, default) {
    if (is.null(x)) rep(default, t1) else ref_path_row(x, i, t1)
  }
  eff <- function(r) {
    v <- (1 + r)^delta - 1
    v[1L] <- 0
    v
  }
  h_pa <- row(A$deposit_rate_pa, 0)
  s_pa <- row(A$overdraft_rate_pa, 0)
  sp_pa <- if (sp_is_s) s_pa else s_pa + row(A$penalty_spread_pa, 0)
  wa <- row(A$allowance_pa, 0) * delta
  wa[1L] <- 0
  list(h_pa = h_pa, s_pa = s_pa, h = eff(h_pa), s = eff(s_pa), sp = eff(sp_pa),
       w = ref_el(A$withholding %||% 0, i), wa = wa, KL = row(A$overdraft_limit_eur, Inf),
       Lmin = row(A$min_liquidity_eur, 0), thr = ref_el(A$flag_threshold %||% Inf, i),
       buffer = ref_el(A$prepay_buffer %||% 0, i),
       min_spread = ref_el(A$prepay_min_spread %||% 0, i))
}

ref_flags0 <- function() {
  list(reserve_used = FALSE, shortfall = FALSE, shortfall_sum = 0,
       first_shortfall_t = NA_integer_, limit_breach = FALSE, limit_cut = FALSE,
       overdraft_threshold = FALSE, stopped = FALSE)
}

ref_period_flows0 <- function() {
  c(od_draw = 0, od_repay = 0, odp_draw = 0, odp_repay = 0, dep_invest = 0, dep_withdraw = 0,
    equity_call = 0, shortfall = 0)
}

#' D4-Betrag buchen (Markierungen 9.8)
ref_flag_d4 <- function(x, amt, t, stopped = FALSE, breach = FALSE) {
  if (amt > ref_zero) {
    x$flags$shortfall <- TRUE
    x$flags$shortfall_sum <- x$flags$shortfall_sum + amt
    if (is.na(x$flags$first_shortfall_t)) x$flags$first_shortfall_t <- as.integer(t)
    if (stopped) x$flags$stopped <- TRUE
    if (breach) x$flags$limit_breach <- TRUE
  }
  x
}

#' Ü3: Sondertilgung aus Überschüssen (8.9 loan_prepay)
ref_prepay_chain <- function(x, amt, j, t, ac) {
  if (t == 0L || length(x$loans) == 0L) return(list(x = x, used = 0))
  ids <- which(vapply(x$loans, function(s) s$par$prepay_allowed, logical(1)))
  if (length(ids) == 0L) return(list(x = x, used = 0))
  ipa <- vapply(x$loans[ids], function(s) s$i_pa, double(1))
  ord <- ids[order(-ipa, ids)]
  avail <- max(amt - max(ac$Lmin[j] + ac$buffer - x$G, 0), 0)
  used <- 0
  for (k in ord) {
    s <- x$loans[[k]]
    elig <- s$i_pa > ac$h_pa[j] * (1 - ac$w) + ac$min_spread
    v <- min(avail * elig, ref_loan_cap(s))
    s$B <- s$B - v
    s$prepaid_ytd <- s$prepaid_ytd + v
    s$ex_prepay <- s$ex_prepay + v
    x$loans[[k]] <- s
    avail <- avail - v
    used <- used + v
  }
  list(x = x, used = used)
}

#' Eine Ausgleichsaktion (8.9); ex_mode: Wiederholung der Periode T ohne Restwert (9.4)
ref_action <- function(a, x, amt, j, t, ac, ex_mode = FALSE) {
  used <- 0
  f <- x$f
  if (a == "od_repay") {
    x1 <- min(amt, x$KKP)
    x$KKP <- x$KKP - x1
    x2 <- min(amt - x1, x$KK)
    x$KK <- x$KK - x2
    f[["odp_repay"]] <- f[["odp_repay"]] - x1
    f[["od_repay"]] <- f[["od_repay"]] - x2
    used <- x1 + x2
  } else if (a == "dep_fill_reserve") {
    v <- min(amt, max(ac$Lmin[j] - x$G, 0))
    x$G <- x$G + v
    f[["dep_invest"]] <- f[["dep_invest"]] - v
    used <- v
  } else if (a == "loan_prepay") {
    x$f <- f
    r <- ref_prepay_chain(x, amt, j, t, ac)
    return(r)
  } else if (a == "dep_invest") {
    x$G <- x$G + amt
    f[["dep_invest"]] <- f[["dep_invest"]] - amt
    used <- amt
  } else if (a == "dep_withdraw") {
    v <- min(amt, max(x$G - ac$Lmin[j], 0))
    x$G <- x$G - v
    f[["dep_withdraw"]] <- f[["dep_withdraw"]] + v
    used <- v
  } else if (a == "od_draw") {
    v <- min(amt, max(ac$KL[j] - x$KK, 0))
    x$KK <- x$KK + v
    f[["od_draw"]] <- f[["od_draw"]] + v
    if (x$KK + x$KKP > ac$thr) x$flags$overdraft_threshold <- TRUE
    used <- v
  } else if (a == "dep_use_reserve") {
    v <- min(amt, x$G)
    x$G <- x$G - v
    f[["dep_withdraw"]] <- f[["dep_withdraw"]] + v
    if (v > ref_zero) x$flags$reserve_used <- TRUE
    used <- v
  } else if (a %in% c("equity_call", "stop")) {
    if (ex_mode) {                   # 9.4 Nr. 2: kein Zufluss von außen, Rest in die KKP
      x$KKP <- x$KKP + amt
      x$gap <- x$gap + amt
    } else if (a == "equity_call") {
      f[["equity_call"]] <- f[["equity_call"]] + amt
      x <- ref_flag_d4(x, amt, t)
    } else {
      f[["shortfall"]] <- f[["shortfall"]] + amt
      x <- ref_flag_d4(x, amt, t, stopped = TRUE)
    }
    used <- amt
  } else if (a == "penalty_rate") {
    x$KKP <- x$KKP + amt
    f[["odp_draw"]] <- f[["odp_draw"]] + amt
    x <- ref_flag_d4(x, amt, t, breach = TRUE)
    used <- amt
  } else {
    stop("ref_action: unbekannte Ausgleichsaktion ", a, call. = FALSE)
  }
  x$f <- f
  list(x = x, used = used)
}

#' Ausgleich einer Periode: Schritte (6a) und (6) aus 9.3
ref_settle <- function(x, S, j, t, ac, surplus, deficit, ex_mode = FALSE) {
  excess <- max(x$KK - ac$KL[j], 0)
  if (excess > 0) {
    x$KK <- x$KK - excess
    x$f[["od_repay"]] <- x$f[["od_repay"]] - excess
    S <- S - excess
    if (excess > ref_zero) x$flags$limit_cut <- TRUE
  }
  sur <- max(S, 0)
  def <- max(-S, 0)
  for (a in surplus) {
    r <- ref_action(a, x, sur, j, t, ac, ex_mode)
    x <- r$x
    sur <- sur - r$used
  }
  for (a in deficit) {
    r <- ref_action(a, x, def, j, t, ac, ex_mode)
    x <- r$x
    def <- def - r$used
  }
  if (max(sur, def) > 1e-6 * max(1, abs(S))) {
    stop("Referenz-Engine: Ausgleich unvollstaendig (Kettenregeln 8.9)", call. = FALSE)
  }
  x
}

#' Periodenschleife eines Laufs (9.3) mit Instrument-Cache ohne loan_prepay
#'
#' @param E exogene zahlungswirksame Zeilen (Abschnitte project, grants, equity), Länge T+1.
#' @param loans Liste von Kreditzuständen aus ref_loan_init().
#' @param cache Ergebnis von ref_loan_schedules() oder NULL.
ref_balance <- function(E, loans, ac, surplus, deficit, M, cache = NULL) {
  t1 <- length(M)
  nl <- length(loans)
  use_cache <- !("loan_prepay" %in% surplus)
  if (use_cache && is.null(cache)) cache <- ref_loan_schedules(loans, M)
  rec <- lapply(stats::setNames(ref_engine_keys, ref_engine_keys), function(k) rep(0, t1))
  lrec <- lapply(loans, function(s) {
    matrix(0, t1, length(ref_loan_keys), dimnames = list(NULL, ref_loan_keys))
  })
  x <- list(G = 0, KK = 0, KKP = 0, loans = loans, f = ref_period_flows0(),
            flags = ref_flags0(), gap = 0)
  pre <- NULL
  for (j in seq_len(t1)) {
    t <- j - 1L
    Fj <- E[j]                                                     # (1)
    for (k in seq_len(nl)) {                                       # (2)
      if (use_cache) {
        lr <- cache[[k]]$rows[j, ]
      } else {
        x$loans[[k]] <- ref_loan_step(x$loans[[k]], t, M)
        x$loans[[k]]$ex_prepay <- 0
        lr <- x$loans[[k]]$last[ref_loan_keys]
      }
      lrec[[k]][j, ] <- lr
      Fj <- Fj + sum(lr[ref_loan_cash])
    }
    HZ <- x$G * ac$h[j]                                            # (3)
    WHT <- ac$w * max(HZ - ac$wa[j], 0)
    KZ <- x$KK * ac$s[j]
    KZP <- x$KKP * ac$sp[j]
    S <- Fj + HZ - WHT - KZ - KZP                                   # (4), (5) tax_none
    if (j == t1) pre <- list(G = x$G, KK = x$KK, KKP = x$KKP, loans = x$loans, S = S)
    x$f <- ref_period_flows0()
    x <- ref_settle(x, S, j, t, ac, surplus, deficit)              # (6a), (6)
    for (nm in names(x$f)) rec[[nm]][j] <- x$f[[nm]]               # (7)
    rec$dep_interest[j] <- HZ
    rec$dep_wht[j] <- -WHT
    rec$od_interest[j] <- -KZ
    rec$odp_interest[j] <- -KZP
    rec$dep_balance[j] <- x$G
    rec$od_balance[j] <- x$KK
    rec$odp_balance[j] <- x$KKP
    if (!use_cache) {
      for (k in seq_len(nl)) {
        lrec[[k]][j, "prepay"] <- lrec[[k]][j, "prepay"] - x$loans[[k]]$ex_prepay
        lrec[[k]][j, "balance"] <- x$loans[[k]]$B
      }
    }
  }
  final <- if (use_cache) lapply(cache, function(cc) cc$state) else x$loans
  list(rec = rec, lrec = lrec, flags = x$flags, pre = pre, use_cache = use_cache,
       cache = cache, loans_final = final)
}

#' Terminalzustand ohne Restwert (9.4): Periode T ab pre_T, Saldo S_T minus RW_T plus NS_T
ref_terminal_ex_rv <- function(run, rw, ns_t, ac, surplus, deficit, M) {
  t1 <- length(M)
  pre <- run$pre
  loans <- lapply(pre$loans, function(s) {
    s$ex_prepay <- 0
    s
  })
  x <- list(G = pre$G, KK = pre$KK, KKP = pre$KKP, loans = loans, f = ref_period_flows0(),
            flags = ref_flags0(), gap = 0)
  x <- ref_settle(x, pre$S - rw + ns_t, t1, t1 - 1L, ac, surplus, deficit, ex_mode = TRUE)
  b <- if (run$use_cache) {
    sum(vapply(run$lrec, function(m) m[t1, "balance"], double(1)))
  } else {
    sum(vapply(x$loans, function(s) s$B, double(1)))
  }
  list(G = x$G, KK = x$KK, KKP = x$KKP, B_total = b, BS = x$G - x$KK - x$KKP - b, rv = rw,
       gap = x$gap)
}

# ---------------------------------------------------------------------------------------------
# 4. Ein Lauf: Investition, Sicht ohne Restwert, Unterlassungsalternative, Kennzahlen
# ---------------------------------------------------------------------------------------------

#' Summe exogener Zeilen von Lauf i nach Filter
ref_rows_sum <- function(s, i, filter) {
  t1 <- length(s$months)
  out <- rep(0, t1)
  for (r in s$rows) {
    if (isTRUE(filter(r))) out <- out + ref_path_row(r$values, i, t1)
  }
  out
}

ref_is_cash <- function(r, sections) isTRUE(r$cash) && r$section %in% sections

#' Lauf i rechnen (Investition) mit optionaler Zusatzentnahme extra (<= 0, Länge T+1)
ref_invest_run <- function(s, i, extra = NULL, cache = NULL) {
  M <- cumsum(s$months)
  E <- ref_rows_sum(s, i, function(r) ref_is_cash(r, c("project", "grants", "equity")))
  if (!is.null(extra)) E <- E + extra
  loans <- lapply(s$loans, ref_loan_init, i = i, M = M)
  ac <- ref_accounts(s$accounts, i, s$months)
  run <- ref_balance(E, loans, ac, s$accounts$surplus, s$accounts$deficit, M, cache = cache)
  run$E <- E
  run$ac <- ac
  run$M <- M
  run
}

#' Zeilen eines Laufs (Engine- und Kreditzeilen, 7.7) inkl. Finanzierungssaldo und Bestandssaldo
ref_run_rows <- function(s, i, run) {
  t1 <- length(s$months)
  rec <- run$rec
  btot <- rep(0, t1)
  cash_loans <- rep(0, t1)
  out <- list()
  for (k in seq_along(run$lrec)) {
    id <- s$loans[[k]]$id
    for (nm in ref_loan_keys) out[[paste0("loan_", id, "_", nm)]] <- run$lrec[[k]][, nm]
    btot <- btot + run$lrec[[k]][, "balance"]
    cash_loans <- cash_loans + rowSums(run$lrec[[k]][, ref_loan_cash, drop = FALSE])
  }
  rec$balance_check <- run$E + cash_loans + rec$od_draw + rec$od_repay + rec$od_interest +
    rec$odp_draw + rec$odp_repay + rec$odp_interest + rec$dep_invest + rec$dep_withdraw +
    rec$dep_interest + rec$dep_wht + rec$tax + rec$equity_call + rec$shortfall
  rec$net_position <- rec$dep_balance - rec$od_balance - rec$odp_balance - btot -
    rec$tax_liability
  if (!is.null(s$existing_value)) {
    assumed <- 0
    for (k in seq_along(run$lrec)) {
      if (isTRUE(s$loans[[k]]$existing)) assumed <- assumed + run$lrec[[k]][1L, "assumed"]
    }
    rec$equity_in_kind[1L] <- ref_el(s$existing_value, i) - assumed
  }
  c(rec, out)
}

#' Unterlassungsalternative von Lauf i (9.5)
ref_opportunity_run <- function(s, i, ns) {
  M <- cumsum(s$months)
  E <- ref_rows_sum(s, i, function(r) ref_is_cash(r, "equity")) + ns
  if (!is.null(s$existing_value)) {
    b0 <- 0
    for (L in s$loans) if (isTRUE(L$existing)) b0 <- b0 + L$commitment
    E[1L] <- E[1L] + ref_el(s$existing_value, i) * (1 - (s$sale_cost_share %||% 0)) - b0
  }
  deficit <- s$accounts$deficit
  d4 <- deficit[length(deficit)]
  sp_is_s <- d4 %in% c("equity_call", "stop")
  if (sp_is_s) deficit[length(deficit)] <- "penalty_rate"
  surplus <- setdiff(s$accounts$surplus, "loan_prepay")
  ac <- ref_accounts(s$accounts, i, s$months, sp_is_s = sp_is_s)
  run <- ref_balance(E, list(), ac, surplus, deficit, M)
  run$E <- E
  run$ac <- ac
  rows <- ref_run_rows(list(months = s$months, loans = list(), existing_value = NULL), i, run)
  list(BS = rows$net_position, EW = rows$net_position[length(M)], rows = rows,
       limit_breach = any(rows$odp_draw > ref_zero))
}

#' Ergebnis eines Laufs (Zeilen, Sicht ohne Restwert, Alternative, Markierungen, Kennzahlen)
ref_run_one <- function(s, i) {
  t1 <- length(s$months)
  run <- ref_invest_run(s, i)
  rows <- ref_run_rows(s, i, run)
  ns <- rows$equity_call + rows$shortfall
  rw <- ref_rows_sum(s, i, function(r) {
    ref_is_cash(r, "project") && r$category %in% c("residual_value", "sale_cost")
  })[t1]
  ex <- ref_terminal_ex_rv(run, rw, ns[t1], run$ac, s$accounts$surplus, s$accounts$deficit,
                           run$M)
  opp <- ref_opportunity_run(s, i, ns)
  fl <- run$flags
  fl$limit_breach <- fl$limit_breach || any(rows$odp_balance > ref_zero)
  fl$opp_limit_breach <- opp$limit_breach
  fl$ex_rv_gap <- ex$gap
  fl$negative_amortization <- any(vapply(run$loans_final, function(st) isTRUE(st$neg_amort),
                                         logical(1)))
  fl$arbitrage <- any(run$ac$h_pa[-1L] > run$ac$s_pa[-1L])
  out <- list(rows = rows, ex = ex, opp = opp, flags = fl, run = run, rw = rw, ns = ns)
  out$kpis <- ref_kpis_one(s, i, out)
  out
}

# ---------------------------------------------------------------------------------------------
# 5. Kennzahlen (Spec 00 12.2, 12.3, 12.5, 12.8)
# ---------------------------------------------------------------------------------------------

ref_kv <- function(value, na = NA_character_) list(value = value, na = na)
ref_kna <- function(code) list(value = NA_real_, na = code)

#' Renditen R1-R3 mit NA-Codes (12.3)
ref_roe <- function(ew, EL, EN, q, TJ, tau, no_existing = FALSE) {
  t1 <- length(EL)
  if (no_existing) {
    return(list(roe_classic = ref_kna("no_existing_value"),
                roe_mirr = ref_kna("no_existing_value"),
                roe_irr = ref_kna("no_existing_value")))
  }
  out <- list()
  out$roe_classic <- if (EL[1L] <= ref_zero) {
    ref_kna("no_equity")
  } else if (any(abs(EL[-1L]) > ref_zero) || any(abs(EN) > ref_zero)) {
    ref_kna("multiple_equity_flows")
  } else if (ew <= 0) {
    ref_kna("equity_lost")
  } else {
    ref_kv((ew / EL[1L])^(1 / TJ) - 1)
  }
  num <- ew + sum(EN * q[t1] / q)
  den <- sum(EL / q)
  if (den <= ref_zero) {
    out$roe_mirr <- ref_kna("no_equity")
    out$roe_irr <- ref_kna("no_equity")
  } else if (num <= 0) {
    out$roe_mirr <- ref_kna("equity_lost")
    out$roe_irr <- ref_kna("equity_lost")
  } else {
    out$roe_mirr <- ref_kv((num / den)^(1 / TJ) - 1)
    cf <- -EL + EN
    cf[t1] <- cf[t1] + ew
    r <- ref_irr(cf, tau)
    out$roe_irr <- ref_kv(r$value, r$na)
  }
  out
}

#' Vermögensamortisation (12.3, R-72) -> list(time, year)
ref_payback <- function(w, bs_u, tau, year) {
  t1 <- length(w)
  ok <- (w - bs_u) >= -1e-9 * pmax(1, abs(bs_u))
  if (!ok[t1]) return(list(time = ref_kna("no_payback"), year = ref_kna("no_payback")))
  j <- t1
  while (j > 1L && ok[j - 1L]) j <- j - 1L
  list(time = ref_kv(tau[j]), year = ref_kv(as.double(year[j])))
}

#' Entnahme-Äquivalent (12.8) für Lauf i; ex: Sicht ohne Restwert
ref_withdrawal <- function(s, i, res, q, TJ, ew_u, d_ew, ex = FALSE) {
  t1 <- length(s$months)
  delta <- s$months / 12
  ns0 <- res$ns
  cache <- if (res$run$use_cache) res$run$cache else NULL
  f <- function(E) {
    run <- ref_invest_run(s, i, extra = -E * delta, cache = cache)
    rows <- ref_run_rows(s, i, run)
    ns <- rows$equity_call + rows$shortfall
    bs <- if (ex) {
      ref_terminal_ex_rv(run, res$rw, ns[t1], run$ac, s$accounts$surplus,
                         s$accounts$deficit, run$M)$BS
    } else {
      rows$net_position[t1]
    }
    bs - sum((ns - ns0) * q[t1] / q) - ew_u
  }
  lo <- min(d_ew, 0) / TJ - 1
  hi <- max(d_ew, 0) / TJ + 1
  flo <- f(lo)
  fhi <- f(hi)
  k <- 0L
  while ((flo < 0 || fhi > 0) && k < 30L) {
    lo <- 2 * lo
    hi <- 2 * hi
    flo <- f(lo)
    fhi <- f(hi)
    k <- k + 1L
  }
  if (flo < 0 || fhi > 0) return(ref_kna("no_solution"))
  tol <- s$wd_tol %||% 1e-10
  for (it in seq_len(200L)) {
    mid <- (lo + hi) / 2
    fm <- f(mid)
    if ((fm > 0) == (flo > 0)) {
      lo <- mid
      flo <- fm
    } else {
      hi <- mid
    }
    if (hi - lo < tol) break
  }
  ref_kv((lo + hi) / 2)
}

#' Summen je Betriebsjahr über die Jahre in P_stab (12.2, R-77)
ref_stab_years <- function(s) {
  oy <- s$op_year
  P <- sort(unique(oy[oy > 0]))
  if (length(P) == 0L) return(list(P = integer(0), first_year = integer(0)))
  first_period <- vapply(P, function(y) which(oy == y)[1L], integer(1))
  full <- vapply(P, function(y) all(s$op_year_full[oy == y]), logical(1))
  ystab <- s$analysis$stabilization_year %||% NA_integer_
  if (is.na(ystab)) ystab <- if (any(full)) s$year[first_period[which(full)[1L]]] else -Inf
  keep <- s$year[first_period] >= ystab
  list(P = P[keep])
}

#' Kennzahlen von Lauf i (12.3) mit und ohne Restwert
ref_kpis_one <- function(s, i, res) {
  t1 <- length(s$months)
  delta <- s$months / 12
  tau <- cumsum(delta)
  TJ <- tau[t1]
  ac <- res$run$ac
  h_net <- ac$h - ac$w * pmax(ac$h, 0)
  q <- cumprod(c(1, 1 + h_net[-1L]))
  rows <- res$rows
  cat_sum <- function(sections, cats, cash = TRUE) {
    ref_rows_sum(s, i, function(r) {
      (!cash || isTRUE(r$cash)) && r$section %in% sections && r$category %in% cats
    })
  }
  EL <- cat_sum("equity", "equity_in") + rows$equity_in_kind + rows$equity_call + rows$shortfall
  EN <- -cat_sum("equity", "equity_out")
  ns <- res$ns
  bs <- rows$net_position
  ew <- bs[t1]
  ew_ex <- res$ex$BS
  ew_u <- res$opp$EW
  bs_u <- res$opp$BS
  no_ex <- isTRUE(s$bestand) && is.null(s$existing_value)
  want <- s$kpis %||% c(ref_kpi_rv, ref_kpi_plain)
  K <- list()
  views <- list(list(sfx = "", ew = ew,
                     G = rows$dep_balance, KK = rows$od_balance + rows$odp_balance),
                list(sfx = "_ex_rv", ew = ew_ex,
                     G = c(rows$dep_balance[-t1], res$ex$G),
                     KK = c((rows$od_balance + rows$odp_balance)[-t1], res$ex$KK + res$ex$KKP)))
  rvb <- s$analysis$rv_path_basis %||% "method"
  rwp <- ref_rows_sum(s, i, function(r) {
    r$category == "residual_path" && identical(r$rv_basis %||% "method", rvb)
  })
  cum_ns <- cumsum(ns)
  for (v in views) {
    sx <- v$sfx
    K[[paste0("terminal_value", sx)]] <- ref_kv(v$ew)
    K[[paste0("delta_terminal_value", sx)]] <- ref_kv(v$ew - ew_u)
    roe <- ref_roe(v$ew, EL, EN, q, TJ, tau, no_existing = no_ex)
    for (nm in names(roe)) K[[paste0(nm, sx)]] <- roe[[nm]]
    w <- if (sx == "") c(bs[-t1] + rwp[-t1], ew) else c(bs[-t1], ew_ex)
    pb <- ref_payback(w, bs_u, tau, s$year)
    K[[paste0("payback_time", sx)]] <- pb$time
    K[[paste0("payback_year", sx)]] <- pb$year
    K[[paste0("min_net_liquidity", sx)]] <- ref_kv(min(v$G - v$KK))
    K[[paste0("max_overdraft", sx)]] <- ref_kv(max(v$KK))
    K[[paste0("max_financing_need", sx)]] <- ref_kv(max(v$KK + cum_ns))
    if ("withdrawal_equivalent" %in% want) {
      K[[paste0("withdrawal_equivalent", sx)]] <-
        ref_withdrawal(s, i, res, q, TJ, ew_u, v$ew - ew_u, ex = sx != "")
    }
    if (is.null(s$inflation)) {
      K[[paste0("terminal_value_real", sx)]] <- ref_kna("no_inflation_path")
    } else {
      pi_t <- ref_path_row(s$inflation, i, t1)
      K[[paste0("terminal_value_real", sx)]] <- ref_kv(v$ew / prod((1 + pi_t[-1L])^delta[-1L]))
    }
  }
  K$terminal_value_opp <- ref_kv(ew_u)
  K$sum_equity_calls <- ref_kv(sum(ns))
  K$pv_equity_calls <- ref_kv(sum(ns / q))
  K$flag_shortfall <- ref_kv(as.double(res$flags$shortfall))
  K$flag_limit_breach <- ref_kv(as.double(res$flags$limit_breach))
  K$flag_reserve_used <- ref_kv(as.double(res$flags$reserve_used))
  # Kapitaldienst je Betriebsjahr (12.2: KD = interest + repay, ohne repay_balloon, prepay, fees)
  noi <- ref_rows_sum(s, i, function(r) {
    isTRUE(r$cash) && paste0(r$section, "/", r$category) %in% ref_noi_keys
  })
  kd <- kd_ex <- int <- draw_new <- tz <- rep(0, t1)
  btot <- rep(0, t1)
  for (L in s$loans) {
    pre <- paste0("loan_", L$id, "_")
    k <- -(rows[[paste0(pre, "interest")]] + rows[[paste0(pre, "repay")]])
    kd <- kd + k
    if (isTRUE(L$existing)) {
      kd_ex <- kd_ex + k
    } else {
      draw_new <- draw_new + rows[[paste0(pre, "draw")]]
    }
    int <- int - rows[[paste0(pre, "interest")]]
    tz <- tz + rows[[paste0(pre, "repayment_grant")]]
    btot <- btot + rows[[paste0(pre, "balance")]]
  }
  st <- ref_stab_years(s)
  ysum <- function(x) vapply(st$P, function(y) sum(x[s$op_year == y]), double(1))
  noi_y <- ysum(noi)
  kd_y <- ysum(kd)
  kd_ex_y <- ysum(kd_ex)
  int_y <- ysum(int)
  sel <- kd_y > ref_zero
  if (any(sel)) {
    dscr <- noi_y[sel] / kd_y[sel]
    K$dscr_min <- ref_kv(min(dscr))
    K$dscr_mean <- ref_kv(mean(dscr))
    thr <- s$analysis$dscr_threshold %||% NA_real_
    K$dscr_years_below <- if (is.na(thr)) ref_kna("not_computed") else
      ref_kv(as.double(sum(dscr < thr)))
  } else {
    K$dscr_min <- K$dscr_mean <- K$dscr_years_below <- ref_kna("no_debt_service")
  }
  kd_new_y <- kd_y - kd_ex_y
  sel <- kd_new_y > ref_zero
  K$dscr_min_new <- if (any(sel)) ref_kv(min((noi_y[sel] - kd_ex_y[sel]) / kd_new_y[sel])) else
    ref_kna("no_debt_service")
  sel <- int_y > ref_zero
  K$icr_min <- if (any(sel)) ref_kv(min(noi_y[sel] / int_y[sel])) else
    ref_kna("no_debt_service")
  # Marktwert und Beleihung (12.3)
  V <- ref_rows_sum(s, i, function(r) r$category == "market_value")
  debt <- btot + rows$od_balance + rows$odp_balance
  sel <- V > ref_zero
  if (any(sel)) {
    K$ltv_max <- ref_kv(max(debt[sel] / V[sel]))
    hc <- s$analysis$haircut %||% NA_real_
    K$lending_ratio_max <- if (is.na(hc)) ref_kna("not_computed") else
      ref_kv(max(btot[sel] / (V[sel] * (1 - hc))))
  } else {
    K$ltv_max <- K$lending_ratio_max <- ref_kna("no_market_value")
  }
  K$ltv_end <- if (V[t1] > ref_zero) ref_kv(debt[t1] / V[t1]) else ref_kna("no_market_value")
  cf <- ref_rows_sum(s, i, function(r) ref_is_cash(r, c("project", "grants")))
  K$npv_cf_project <- ref_kv(sum(cf / q))
  r <- ref_irr(cf, tau)
  K$irr_cf_project <- ref_kv(r$value, r$na)
  inv <- cat_sum("project", c("land", "acquisition_cost", "capex", "relocation_cost")) +
    cat_sum("grants", c("grant", "tax_credit"))
  K$own_contribution <- ref_kv(-sum(inv) - sum(draw_new))
  subs <- cat_sum("grants", c("grant", "operating_subsidy", "tax_credit"))
  K$pv_subsidies <- ref_kv(sum((subs + tz) / q))
  K$co2_emissions <- ref_kv(sum(ref_rows_sum(s, i, function(r) r$category == "co2_emission")))
  if (isTRUE(res$flags$stopped)) {
    for (nm in c(ref_kpi_stopped, paste0(ref_kpi_stopped, "_ex_rv"))) {
      if (!is.null(K[[nm]])) K[[nm]] <- ref_kna("run_stopped")
    }
  }
  keep <- c(want, paste0(intersect(want, ref_kpi_rv), "_ex_rv"))
  K[intersect(names(K), keep)]
}

# ---------------------------------------------------------------------------------------------
# 6. Hauptfunktion
# ---------------------------------------------------------------------------------------------

#' Skalare Referenz-Engine (Spec 00 15.1): alle Läufe der Reihe nach
#'
#' @return list(n, T, rows = list(<key> = n x (T+1)), opp = list(BS, EW, rows),
#'   terminal_ex_rv = data.frame, flags = data.frame, kpis = data.frame, kpi_na = data.frame)
ref_engine_run <- function(spec_simple) {
  s <- spec_simple
  n <- as.integer(s$n %||% 1L)
  t1 <- length(s$months)
  stopifnot(n >= 1L, t1 >= 1L, s$months[1L] == 0)
  runs <- lapply(seq_len(n), function(i) ref_run_one(s, i))
  stack <- function(get) {
    keys <- unique(unlist(lapply(runs, function(r) names(get(r)))))
    lapply(stats::setNames(keys, keys), function(k) {
      do.call(rbind, lapply(runs, function(r) get(r)[[k]] %||% rep(0, t1)))
    })
  }
  df <- function(get) {
    as.data.frame(do.call(rbind, lapply(runs, function(r) as.data.frame(get(r)))),
                  stringsAsFactors = FALSE)
  }
  kp <- lapply(runs, function(r) r$kpis)
  knames <- names(kp[[1L]])
  kpis <- as.data.frame(lapply(stats::setNames(knames, knames), function(k) {
    vapply(kp, function(x) x[[k]]$value, double(1))
  }))
  kpi_na <- as.data.frame(lapply(stats::setNames(knames, knames), function(k) {
    vapply(kp, function(x) x[[k]]$na, character(1))
  }), stringsAsFactors = FALSE)
  list(n = n, T = t1 - 1L, rows = stack(function(r) r$rows), exo = s$rows,
       loan_ids = vapply(s$loans, function(L) L$id, character(1)),
       opp = list(BS = do.call(rbind, lapply(runs, function(r) r$opp$BS)),
                  EW = vapply(runs, function(r) r$opp$EW, double(1)),
                  rows = stack(function(r) r$opp$rows)),
       terminal_ex_rv = df(function(r) r$ex), flags = df(function(r) r$flags),
       kpis = kpis, kpi_na = kpi_na)
}

#' Teilmenge der Läufe einer spec_simple (für Batch-gegen-Einzellauf)
ref_spec_subset <- function(s, i) {
  sub_path <- function(x) {
    if (is.matrix(x)) return(x[i, , drop = FALSE])
    if (length(x) == s$n && s$n > 1L) x[i] else x
  }
  sub_list <- function(L) {
    if (is.null(L)) return(NULL)
    for (nm in names(L)) {
      v <- L[[nm]]
      if (is.list(v) && !is.null(names(v))) L[[nm]] <- sub_list(v) else
        if (is.numeric(v) || is.logical(v)) L[[nm]] <- sub_path(v)
    }
    L
  }
  out <- s
  out$rows <- lapply(s$rows, function(r) {
    r$values <- r$values[i, , drop = FALSE]
    r
  })
  keep_det <- c("draws", "planned", "t_first_draw", "m_A", "m_start", "ppy", "term_months",
                "grace_months", "fixed_months", "followup_fixed_months", "fee_free_until",
                "commitment")
  out$loans <- lapply(s$loans, function(L) {
    det <- L[intersect(names(L), keep_det)]
    L <- sub_list(L)
    L[names(det)] <- det
    L
  })
  out$accounts <- sub_list(s$accounts)
  if (!is.null(s$existing_value)) out$existing_value <- sub_path(s$existing_value)
  if (!is.null(s$inflation)) out$inflation <- sub_path(s$inflation)
  out$n <- 1L
  out
}

# ---------------------------------------------------------------------------------------------
# 7. Übersetzung vofi_model -> spec_simple (Vertragsobjekte, Spec 00 4.13, 7.4, 13.1, 13.2)
# ---------------------------------------------------------------------------------------------

#' Knoten bzw. Wert an einem Punktpfad (eigene, schlichte Pfadauflösung)
ref_path_get <- function(x, path) {
  for (p in strsplit(path, ".", fixed = TRUE)[[1L]]) {
    if (!is.list(x) || is.null(x[[p]])) return(NULL)
    x <- x[[p]]
  }
  x
}

#' n-Vektor bzw. n x (T+1)-Matrix als Pfad
ref_as_path <- function(x, n, t1) {
  if (is.matrix(x)) return(x)
  matrix(rep_len(as.double(x), n), n, t1)
}

#' Skalare Form (n-Vektor); zeitabhängige Werte sind hier ein Fehler (6.3 Schritt 4)
ref_as_scalar <- function(x) {
  if (is.matrix(x)) {
    if (all(x == x[, 1L])) return(as.double(x[, 1L]))
    stop("ref_as_scalar: zeitabhaengiger Wert fuer einen skalaren Parameter", call. = FALSE)
  }
  as.double(x)
}

#' Knoten der Wertgrammatik auswerten (4.5, 6.3; Teilmenge const, series_t, series_year, ref)
#'
#' `env`: list(spec, grid, n, static = list(<ziel> = n-Vektor), paths = list(<ziel> = Matrix)).
#' Statische Ziehungen und Prozesspfade ersetzen den Knoten am Zielpfad (apply = replace).
ref_node_eval <- function(node, path, env, depth = 0L) {
  if (depth > 30L) stop("ref_node_eval: Zyklus", call. = FALSE)
  n <- env$n
  t1 <- env$grid$T + 1L
  if (!is.null(path) && !is.null(env$static[[path]])) return(as.double(env$static[[path]]))
  if (!is.null(path) && !is.null(env$paths[[path]])) return(env$paths[[path]])
  if (is.null(node)) stop("ref_node_eval: kein Wert am Pfad ", path, call. = FALSE)
  if (is.numeric(node)) return(rep_len(as.double(node), n))
  el <- function(e) {
    if (is.numeric(e)) rep_len(as.double(e), n) else
      ref_as_scalar(ref_node_eval(e, NULL, env, depth + 1L))
  }
  switch(node$kind,
    const = rep(as.double(node$value), n),
    series_t = {
      vals <- if (is.list(node$values)) node$values else as.list(node$values)
      if (length(vals) != t1) stop("ref_node_eval: series_t hat nicht T+1 Elemente", call. = FALSE)
      do.call(cbind, lapply(vals, el))
    },
    series_year = {
      vals <- lapply(if (is.list(node$values)) node$values else as.list(node$values), el)
      yrs <- node$years
      fill <- node$fill %||% "locf"
      if (!fill %in% c("locf", "linear")) stop("ref_node_eval: fill ", fill, call. = FALSE)
      out <- matrix(0, n, t1)
      for (j in seq_len(t1)) {
        y <- env$grid$year[j]
        if (y < yrs[1L]) {
          out[, j] <- if (identical(node$before %||% "first", "first")) vals[[1L]] else 0
        } else {
          k <- max(which(yrs <= y))
          if (fill == "linear" && k < length(yrs) && yrs[k] < y) {
            w <- (y - yrs[k]) / (yrs[k + 1L] - yrs[k])
            out[, j] <- (1 - w) * vals[[k]] + w * vals[[k + 1L]]
          } else {
            out[, j] <- vals[[k]]
          }
        }
      }
      out
    },
    ref = {
      x <- ref_node_eval(ref_path_get(env$spec, node$path), node$path, env, depth + 1L)
      if (!is.null(node$anchor)) {
        xm <- ref_as_path(x, n, t1)
        y <- node$anchor + node$scale * (xm - xm[, 1L]) + node$offset
      } else {
        y <- x * node$scale + node$offset
      }
      pmin(pmax(y, node$floor), node$cap)
    },
    stop("ref_node_eval: Knotenart nicht unterstuetzt: ", node$kind, call. = FALSE)
  )
}

#' Periode eines Datums (3.4, R-35); NA jenseits des Horizonts
ref_period_of <- function(g, d) {
  if (is.null(d) || is.na(d)) return(NA_integer_)
  if (d == g$valuation_date) return(0L)
  if (d > g$end_date || d < g$valuation_date) return(NA_integer_)
  as.integer(which(g$date_end >= d)[1L] - 1L)
}

#' Monate vom Stichtag bis zu einem Monatsersten
ref_months_from <- function(g, d) {
  (as.integer(format(d, "%Y")) - as.integer(format(g$valuation_date, "%Y"))) * 12L +
    (as.integer(format(d, "%m")) - as.integer(format(g$valuation_date, "%m")))
}

#' Termin (Date oder Token "completion", 3.9)
ref_timing <- function(x, g) {
  if (identical(x, "completion")) return(g$completion_date)
  if (is.null(x)) return(NULL)
  if (inherits(x, "Date")) return(x)
  stop("ref_timing: Termin nicht lesbar", call. = FALSE)
}

#' Zahl bzw. Basisfallwert eines nicht-stochastischen Felds
ref_num <- function(x, env0) {
  if (is.null(x)) return(NULL)
  if (is.numeric(x)) return(as.double(x)[1L])
  ref_as_scalar(ref_node_eval(x, NULL, env0))[1L]
}

#' Kreditbaustein k aus vofi_spec (8.2) in Referenzparameter übersetzen
ref_loan_from_spec <- function(L, k, env, model) {
  g <- env$grid
  t1 <- g$T + 1L
  M <- g$month_end
  env0 <- list(spec = env$spec, grid = g, n = 1L, static = list(), paths = list())
  pth <- function(p) paste("financing", k, p, sep = ".")
  val <- function(p, default = NULL) {
    node <- ref_path_get(L, p)
    if (is.null(node) && is.null(env$static[[pth(p)]])) return(default)
    ref_as_scalar(ref_node_eval(node, pth(p), env))
  }
  base <- function(p, default = NULL) {
    node <- ref_path_get(L, p)
    if (is.null(node)) default else ref_num(node, env0)
  }
  repayment <- c(annuity_loan = "annuity", installment_loan = "installment",
                 bullet_loan = "bullet")[[L$type]]
  existing <- isTRUE(L$existing)
  start <- if (existing) g$valuation_date else ref_timing(L$start %||% g$valuation_date, g)
  draws <- rep(0, t1)
  if (identical(model$auto_id, k)) {
    commitment <- as.double(model$base$auto$commitment)
    draws <- as.double(model$base$auto$draws)
    w <- which(g$phase == "construction")
    if (length(w) == 0L) w <- 1L
    t_first <- w[1L] - 1L
    t_last <- w[length(w)] - 1L
  } else if (existing) {
    commitment <- base("amount_eur")
    t_first <- 0L
    t_last <- 0L
  } else {
    commitment <- base("amount_eur")
    ds <- L$draw_schedule
    if (is.null(ds)) {
      t_first <- t_last <- ref_period_of(g, start)
      if (!is.na(t_first)) draws[t_first + 1L] <- commitment
    } else {
      amts <- if (is.list(ds$amounts)) vapply(ds$amounts, ref_num, double(1), env0 = env0) else
        as.double(ds$amounts)
      if (identical(ds$unit, "share")) amts <- amts * commitment
      tp <- vapply(seq_along(ds$dates), function(q) ref_period_of(g, ds$dates[q]), integer(1))
      for (q in which(!is.na(tp))) draws[tp[q] + 1L] <- draws[tp[q] + 1L] + amts[q]
      t_first <- min(tp, na.rm = TRUE)
      t_last <- max(tp, na.rm = TRUE)
    }
  }
  if (is.na(t_first)) t_first <- t_last <- g$T + 1L     # Auszahlung nach dem Horizont
  m_A <- if (t_last <= g$T) M[t_last + 1L] else ref_months_from(g, start)
  p_start <- ref_period_of(g, start)
  m_start <- if (existing) 0 else if (is.na(p_start)) ref_months_from(g, start) else
    M[p_start + 1L]
  term <- base("term_years")
  fixed <- base("fixed_years")
  ffix <- base("followup_fixed_years")
  tau <- val("initial_repayment_pa", NA_real_)
  term_m <- if (is.null(term)) Inf else round(12 * term)
  fixed_m <- if (is.null(fixed)) NA_real_ else round(12 * fixed)
  ffix_m <- if (is.null(ffix)) NA_real_ else round(12 * ffix)
  needs_followup <- !is.na(fixed_m) && (m_start + fixed_m) < min(M[t1], m_A + term_m)
  followup <- if (needs_followup) {
    ref_as_path(ref_node_eval(L$followup_rate_pa, pth("followup_rate_pa"), env), env$n, t1)
  } else {
    NULL
  }
  fees <- L$fees %||% list()
  cdate <- ref_timing(fees$commitment_date %||% start, g)
  free <- ref_num(fees$commitment_free_months, env0) %||% 0
  tz <- NULL
  rg <- L$repayment_grant
  if (!is.null(rg) && (!is.null(rg$share) || !is.null(rg$amount_eur))) {
    type <- if (!is.null(rg$share)) "share" else "amount"
    d <- rg$date %||% rg$year
    if (is.null(d)) {
      if (!is.null(L$measure_id)) {
        stop("ref_loan_from_spec: Termin des Tilgungszuschusses aus Massnahme nicht unterstuetzt",
             call. = FALSE)
      }
      t_tz <- if (t_last <= g$T) t_last else NA_integer_
    } else {
      t_tz <- ref_period_of(g, ref_timing(d, g))
    }
    tz <- list(type = type,
               value = if (type == "share") val("repayment_grant.share") else
                 val("repayment_grant.amount_eur"),
               t = t_tz, approved = val("repayment_grant.approved", 1),
               cut = val("repayment_grant.cut_share", 0),
               effect = rg$effect %||% "shorten_term")
  }
  planned <- rep(0, t1)
  pp <- L$planned_prepayments
  if (!is.null(pp)) {
    amts <- if (is.list(pp$amounts)) vapply(pp$amounts, ref_num, double(1), env0 = env0) else
      as.double(pp$amounts)
    tp <- vapply(seq_along(pp$dates), function(q) ref_period_of(g, pp$dates[q]), integer(1))
    for (q in which(!is.na(tp))) planned[tp[q] + 1L] <- planned[tp[q] + 1L] + amts[q]
  }
  rule <- L$refi_rule %||% (if (all(is.na(tau))) "keep_term" else "keep_tilg_rate")
  list(id = k, repayment = repayment, commitment = commitment, approved = val("approved", 1),
       existing = existing, installment_eur = base("installment_eur", NA_real_),
       draws = draws, t_first_draw = t_first, m_A = m_A, m_start = m_start,
       rate_pa = val("rate_pa"), ppy = as.integer(L$payments_per_year %||% 12L),
       term_months = term_m, grace_months = round(12 * (base("grace_years") %||% 0)),
       tau = tau, fixed_months = fixed_m, followup_fixed_months = ffix_m, followup = followup,
       spread = val("followup_spread_pa", 0), refi_rule = rule,
       tau_followup = val("followup_repayment_pa", tau), payout = val("payout_rate", 1),
       processing_fee_share = val("fees.processing_fee_share", 0),
       fee_rate = val("fees.commitment_fee_rate_month", 0),
       fee_free_until = ref_months_from(g, cdate) + free, tz = tz, planned = planned,
       prepay_allowed = isTRUE(L$prepay_allowed), cap_share = val("prepay_cap_share_pa", 1),
       round = isTRUE(L$round_payments))
}

#' Exogene Zeilen aus dem Basisfall-Vorlauf (model$base$flows, n = 1)
ref_rows_from_flows <- function(flows) {
  out <- list()
  for (id in names(flows)) {
    for (r in flows[[id]]$rows) {
      out[[paste0(id, "__", r$key)]] <- list(values = r$values, section = r$section,
                                             category = r$category, cash = isTRUE(r$cash),
                                             rv_basis = r$extra$rv_basis)
    }
  }
  out
}

#' Exogene Zeilen aus einem gespeicherten Ledger (Zahlungskomponenten und Eigenkapital)
ref_rows_from_ledger <- function(led) {
  rows <- led$rows
  sel <- which(rows$source_type != "engine" &
                 rows$section %in% c("project", "grants", "equity", "memo"))
  out <- list()
  for (q in sel) {
    k <- rows$key[q]
    ex <- rows$extra[[q]]
    out[[k]] <- list(values = led$values[[k]], section = rows$section[q],
                     category = rows$category[q], cash = isTRUE(rows$cash[q]),
                     rv_basis = if (is.list(ex)) ex$rv_basis else NULL)
  }
  out
}

#' Statische Ziehungen je Zielpfad aus einem Ergebnis (vofi_mc_result: inputs + Plan;
#' Objekt mit `draws`: vofi_draws)
ref_result_draws <- function(model, result) {
  static <- list()
  paths <- list()
  if (is.null(result)) return(list(static = static, paths = paths))
  dr <- result$draws
  if (inherits(dr, "vofi_draws")) {
    tg <- dr$targets
    for (q in seq_len(nrow(tg))) {
      if (!identical(tg$apply[q], "replace")) stop("apply != replace", call. = FALSE)
      if (tg$kind[q] == "static") static[[tg$target[q]]] <- dr$static[[tg$key[q]]]
      if (tg$kind[q] == "process") paths[[tg$target[q]]] <- dr$paths[[tg$key[q]]]
    }
    return(list(static = static, paths = paths))
  }
  plan <- model$sampler
  if (!is.null(plan) && length(plan$processes) > 0L) {
    stop("spec_simple_from_model: Prozesse ohne Ziehungsobjekt nicht unterstuetzt",
         call. = FALSE)
  }
  if (!is.null(plan) && !is.null(plan$static) && nrow(plan$static) > 0L) {
    st <- plan$static
    for (q in seq_len(nrow(st))) {
      if (!identical(st$role[q] %||% "value", "value")) next
      if (!identical(st$apply[q] %||% "replace", "replace")) stop("apply != replace",
                                                                  call. = FALSE)
      static[[st$target[q]]] <- result$inputs[[st$key[q]]]
    }
  }
  list(static = static, paths = paths)
}

#' Übersetzung eines unterstützten Modells in die Referenz-Eingabe (Spec 00 15.1)
#'
#' Ohne `result`: deterministischer Basisfall (exogene Zeilen aus `model$base$flows`).
#' Mit `result` (vofi_result oder vofi_mc_result mit `store = "full"`): exogene Zeilen aller
#' Läufe aus `result$ledger`, laufspezifische statische Ziehungen aus `result$inputs` (Ziele
#' aus `model$sampler$static`) bzw. `result$draws`.
#' Nicht unterstützt (Fehler): Steuermodule außer `none`, `topup`, Entscheidungsknoten,
#' Wertformen außer const/series_t/series_year/ref an Kredit- und Kontoparametern.
spec_simple_from_model <- function(model, result = NULL) {
  if (!inherits(model, "vofi_model")) stop("spec_simple_from_model: kein vofi_model",
                                           call. = FALSE)
  if (!inherits(model$tax, "tax_none")) stop("nur tax_none unterstuetzt", call. = FALSE)
  if (!is.null(model$topup_id)) stop("topup nicht unterstuetzt", call. = FALSE)
  if (!is.null(model$decision)) stop("Entscheidungsknoten nicht unterstuetzt", call. = FALSE)
  sp <- model$spec
  g <- model$grid
  t1 <- g$T + 1L
  led <- if (is.null(result)) NULL else result$ledger
  if (!is.null(result) && is.null(led)) stop("Ergebnis ohne Ledger (store = full noetig)",
                                             call. = FALSE)
  n <- if (is.null(led)) 1L else as.integer(led$n)
  dr <- ref_result_draws(model, result)
  env <- list(spec = sp, grid = g, n = n, static = dr$static, paths = dr$paths)
  env0 <- list(spec = sp, grid = g, n = 1L, static = list(), paths = list())
  A <- sp$accounts
  apath <- function(p, default) {
    node <- ref_path_get(A, p)
    tgt <- paste0("accounts.", p)
    if (is.null(node) && is.null(env$static[[tgt]]) && is.null(env$paths[[tgt]])) {
      return(matrix(default, n, t1))
    }
    ref_as_path(ref_node_eval(node, tgt, env), n, t1)
  }
  ascal <- function(p, default) {
    node <- ref_path_get(A, p)
    tgt <- paste0("accounts.", p)
    if (is.null(node) && is.null(env$static[[tgt]])) return(default)
    ref_as_scalar(ref_node_eval(node, tgt, env))
  }
  accounts <- list(
    deposit_rate_pa = apath("deposit_rate_pa", 0),
    overdraft_rate_pa = apath("overdraft_rate_pa", 0),
    penalty_spread_pa = apath("penalty_spread_pa", 0),
    overdraft_limit_eur = apath("overdraft_limit_eur", Inf),
    min_liquidity_eur = apath("min_liquidity_eur", 0),
    allowance_pa = apath("deposit_tax_allowance_eur_pa", 0),
    withholding = ascal("deposit_withholding_tax_share", 0),
    flag_threshold = ascal("overdraft_flag_threshold_eur", Inf),
    prepay_buffer = ascal("prepay.buffer_eur", 0),
    prepay_min_spread = ascal("prepay.min_spread_pa", 0),
    surplus = A$surplus_order %||% c("od_repay", "dep_fill_reserve", "dep_invest"),
    deficit = A$deficit_order
  )
  if (is.null(accounts$deficit)) stop("accounts.deficit_order fehlt", call. = FALSE)
  loans <- lapply(names(model$instruments), function(k) {
    ref_loan_from_spec(sp$financing[[k]] %||% model$instruments[[k]]$spec, k, env, model)
  })
  names(loans) <- names(model$instruments)
  rows <- if (is.null(led)) ref_rows_from_flows(model$base$flows) else ref_rows_from_ledger(led)
  pt <- sp$project$project_type %||% ""
  ev <- ref_path_get(sp, "building.existing_value_eur")
  rm <- sp$project$report_mode %||% "auto"
  if (identical(rm, "auto")) {
    rm <- if (startsWith(sp$project$perspective %||% "", "wu_")) "expert" else "household"
  }
  rvb <- sp$analysis$rv_path_basis %||% "auto"
  if (identical(rvb, "auto")) rvb <- if (rm == "household") "measures" else "method"
  kp <- names(model$kpis)
  infl <- NULL
  if ("terminal_value_real" %in% kp && !is.null(ref_path_get(sp, "market.inflation"))) {
    infl <- ref_as_path(ref_node_eval(ref_path_get(sp, "market.inflation"), "market.inflation",
                                      env), n, t1)
  }
  list(
    n = n, months = as.double(g$months), year = g$year, op_year = g$op_year,
    op_year_full = g$op_year_full, phase = g$phase, rows = rows, loans = loans,
    accounts = accounts,
    existing_value = if (is.null(ev)) NULL else ref_num(ev, env0),
    sale_cost_share = ref_num(ref_path_get(sp, "residual_value.sale_cost_share"), env0) %||% 0,
    bestand = pt %in% ref_bestand_types,
    analysis = list(
      dscr_threshold = ref_num(ref_path_get(sp, "analysis.thresholds.dscr"), env0) %||%
        NA_real_,
      stabilization_year = sp$analysis$stabilization_year %||% NA_integer_,
      haircut = ref_num(ref_path_get(sp, "analysis.lending_value_haircut"), env0) %||% NA_real_,
      rv_path_basis = rvb
    ),
    inflation = infl,
    kpis = setdiff(unique(sub("_ex_rv$", "", kp)), character(0)),
    wd_tol = 1e-10
  )
}

# ---------------------------------------------------------------------------------------------
# 8. Vergleich Referenz-Engine gegen Paket-Ergebnis
# ---------------------------------------------------------------------------------------------

#' Abweichungen zwischen Referenz-Engine und vofi_result bzw. vofi_mc_result (store = "full")
#'
#' Toleranz relativ zum Volumen des Laufs (Spec 00 15.6: 1e-8); Entnahme-Äquivalent mit
#' `wd_tol` (Lösertoleranz des Pakets, 12.8). Rückgabe: data.frame der Abweichungen (leer = ok).
ref_compare_result <- function(ref, res, tol = 1e-8, wd_tol = 2e-6, flags = TRUE) {
  led <- res$ledger
  n <- ref$n
  out <- list()
  add <- function(what, key, sim, t, a, b) {
    out[[length(out) + 1L]] <<- data.frame(what = what, key = key, sim = sim, t = t,
                                           ref = a, pkg = b, stringsAsFactors = FALSE)
  }
  vol <- vapply(seq_len(n), function(i) {
    max(1, unlist(lapply(led$values[led$rows$key[led$rows$cash]], function(m) abs(m[i, ]))))
  }, double(1))
  for (k in names(ref$rows)) {
    a <- ref$rows[[k]]
    b <- led$values[[k]]
    if (is.null(b)) {
      if (any(abs(a) > tol * vol)) add("row_missing", k, NA_integer_, NA_integer_, max(abs(a)),
                                       NA_real_)
      next
    }
    d <- abs(a - b) > tol * vol
    if (any(d)) {
      w <- which(d, arr.ind = TRUE)[1L, ]
      add("row", k, w[[1L]], w[[2L]] - 1L, a[w[[1L]], w[[2L]]], b[w[[1L]], w[[2L]]])
    }
  }
  bs <- res$opportunity$BS
  if (!is.null(bs)) {
    d <- abs(ref$opp$BS - bs) > tol * vol
    if (any(d)) {
      w <- which(d, arr.ind = TRUE)[1L, ]
      add("opp_BS", "opp_net_position", w[[1L]], w[[2L]] - 1L, ref$opp$BS[w[[1L]], w[[2L]]],
          bs[w[[1L]], w[[2L]]])
    }
  }
  kk <- intersect(names(res$kpis), names(ref$kpis))
  for (k in kk) {
    a <- ref$kpis[[k]]
    b <- res$kpis[[k]]
    na_a <- ref$kpi_na[[k]]
    na_b <- res$kpi_na[[k]] %||% rep(NA_character_, n)
    tk <- if (startsWith(k, "withdrawal_equivalent")) wd_tol else tol
    for (i in seq_len(n)) {
      if (is.na(a[i]) || is.na(b[i])) {
        if (!identical(is.na(a[i]), is.na(b[i])) || !identical(na_a[i], na_b[i])) {
          add("kpi_na", k, i, NA_integer_, a[i], b[i])
        }
      } else if (abs(a[i] - b[i]) > tk * max(1, abs(a[i]))) {
        add("kpi", k, i, NA_integer_, a[i], b[i])
      }
    }
  }
  if (flags && !is.null(res$flags)) {
    fcols <- intersect(c("reserve_used", "shortfall", "shortfall_sum", "first_shortfall_t",
                         "limit_breach", "limit_cut", "opp_limit_breach", "ex_rv_gap",
                         "stopped", "negative_amortization"), names(res$flags))
    for (f in fcols) {
      a <- as.double(ref$flags[[f]])
      b <- as.double(res$flags[[f]])
      bad <- (is.na(a) != is.na(b)) | (!is.na(a) & !is.na(b) &
                                         abs(a - b) > tol * pmax(1, abs(a)))
      if (any(bad)) {
        i <- which(bad)[1L]
        add("flag", f, i, NA_integer_, a[i], b[i])
      }
    }
  }
  if (length(out) == 0L) {
    return(data.frame(what = character(0), key = character(0), sim = integer(0),
                      t = integer(0), ref = numeric(0), pkg = numeric(0)))
  }
  do.call(rbind, out)
}

#' Paket-Ergebnis gegen die Referenz-Engine prüfen (testthat-Erwartung)
expect_ref_equal <- function(res, model, tol = 1e-8, wd_tol = 2e-6, info = NULL) {
  mc <- if (identical(res$meta$mode, "deterministic")) NULL else res
  ref <- ref_engine_run(spec_simple_from_model(model, mc))
  d <- ref_compare_result(ref, res, tol = tol, wd_tol = wd_tol)
  head_line <- paste0("Referenz-Engine weicht ab",
                      if (!is.null(info)) paste0(" (", info, ")"), ":")
  msg <- if (nrow(d) == 0L) "" else
    paste(c(head_line, utils::capture.output(print(utils::head(d, 10L)))), collapse = "\n")
  testthat::expect(nrow(d) == 0L, msg)
  invisible(d)
}

# ---------------------------------------------------------------------------------------------
# 9. Zufallsszenarien (Spec 00 15.1, 15.4 G, 15.6 "Differenztests")
# ---------------------------------------------------------------------------------------------

#' Zufallsszenarien in kanonischer YAML-Grammatik (Rohlisten für vofi_scenario())
#'
#' @param seed fester Seed (Generator lokal, globaler RNG-Zustand bleibt unverändert).
#' @param n Anzahl der Szenarien.
#' @param mode "full" (alle Merkmale der Referenz-Engine), "perfect_market" (I4: Jahresraster,
#'   payments_per_year = 1, alle Zinsen gleich i, keine Gebühren/Disagio, KK unbegrenzt, keine
#'   D4-Zuflüsse, 15.4 G), "nonneg" (I5: h_net, s, sp >= 0), "simple" (ohne Kredite mit
#'   Monatsfrequenz und ohne Ü3; für schnelle Läufe).
#' @param variants TRUE: zusätzlich Variante `a` mit eigener Zahlungsfolge (V1, 9.6 Nr. 4).
#' @return Liste von n Rohszenarien.
ref_scenario_generator <- function(seed, n = 200L,
                                   mode = c("full", "perfect_market", "nonneg", "simple"),
                                   variants = FALSE) {
  mode <- match.arg(mode)
  withr::with_seed(seed, lapply(seq_len(n), function(k) ref_gen_one(k, mode, variants)))
}

ref_gen_round <- function(x, d = 2) round(x, d)

#' Ein Zufallsszenario
ref_gen_one <- function(k, mode, variants) {
  ru <- function(a, b) stats::runif(1L, a, b)
  pick <- function(x) x[sample.int(length(x), 1L)]
  coin <- function(p) stats::runif(1L) < p
  pm <- mode == "perfect_market"
  annual <- pm || coin(0.6)
  grid <- list()
  if (annual) {
    H <- sample.int(12L, 1L)
  } else {
    cs <- pick(c(1L, 3L, 6L, 12L))
    C <- pick(c(3L, 6L, 9L, 12L, 18L))
    H <- as.integer(ceiling(C / 12) + sample.int(6L, 1L))
    grid <- list(construction_months = C, construction_step_months = cs,
                 operation_alignment = "calendar")
  }
  g <- vofi_time_grid(as.Date("2027-01-01"), H,
                      construction_months = grid$construction_months %||% 0L,
                      construction_step_months = grid$construction_step_months %||% 12L)
  t1 <- g$T + 1L
  inv <- ref_gen_round(ru(50000, 400000))
  z <- c(-inv, ref_gen_round(stats::runif(t1 - 1L, -0.15, 0.35) * inv * pmax(g$delta[-1L], 0.25)))
  comps <- list(z = list(type = "custom_series", label = "Zahlungsfolge", values = z))
  if (coin(0.5)) {
    comps$rent <- list(type = "recurring", category = "rent",
                       amount_eur = ref_gen_round(ru(5000, 30000)),
                       growth = ref_gen_round(ru(-0.01, 0.04), 4),
                       base_date = pick(as.Date(c("2027-01-01", "2028-01-01"))),
                       start_event = as.Date("2027-01-01"))
  }
  if (coin(0.6)) {
    comps$rv <- list(type = "custom_series", category = "residual_value",
                     values = c(rep(0, t1 - 1L), ref_gen_round(ru(0, 1.2) * inv)))
    if (coin(0.5)) {
      comps$sc <- list(type = "custom_series", category = "sale_cost",
                       values = c(rep(0, t1 - 1L), -ref_gen_round(ru(0, 0.03) * inv)))
    }
  }
  if (coin(0.3)) {
    comps$sub <- list(type = "custom_series", section = "grants", category = "operating_subsidy",
                      values = c(0, ref_gen_round(stats::runif(t1 - 1L, 0, 3000))))
  }
  if (coin(0.4)) {
    comps$mv <- list(type = "custom_series", section = "memo", category = "market_value",
                     values = ref_gen_round(inv * (1 + cumsum(c(0, stats::runif(t1 - 1L, -0.02,
                                                                                0.05))))))
  }
  i_pm <- ref_gen_round(ru(0, 0.06), 4)
  fin <- list()
  ek <- ref_gen_round(ru(0, 1) * inv)
  if (coin(0.85)) {
    fin$ek <- list(type = "equity", amount_eur = ek)
    if (coin(0.25)) fin$ek$withdrawals_pa <- ref_gen_round(ru(0, 0.03) * inv)
    if (coin(0.15)) fin$ek$contributions_pa <- ref_gen_round(ru(0, 0.02) * inv)
  }
  nl <- if (pm) sample(0:2, 1L) else sample(0:3, 1L, prob = c(0.15, 0.4, 0.3, 0.15))
  prepay_any <- FALSE
  for (q in seq_len(nl)) {
    L <- ref_gen_loan(g, inv, mode, ru, pick, coin)
    if (pm) L$rate_pa <- i_pm
    prepay_any <- prepay_any || isTRUE(L$prepay_allowed)
    fin[[paste0("k", q)]] <- L
  }
  h <- if (pm) i_pm else ref_gen_round(ru(if (mode == "nonneg") 0 else -0.005, 0.05), 4)
  s <- if (pm) i_pm else ref_gen_round(h + ru(if (coin(0.05)) -0.005 else 0, 0.08), 4)
  if (mode == "nonneg") s <- max(s, 0)
  s <- max(s, 0)
  kl_inf <- pm || coin(0.5)
  acc <- list(deposit_rate_pa = h, overdraft_rate_pa = s,
              overdraft_limit_eur = if (kl_inf) Inf else ref_gen_round(ru(0, 0.2) * inv),
              penalty_spread_pa = if (pm) 0 else ref_gen_round(ru(0, 0.05), 4),
              min_liquidity_eur = if (pm || coin(0.7)) 0 else ref_gen_round(ru(0, 0.05) * inv),
              deposit_withholding_tax_share = if (pm || coin(0.7)) 0 else 0.26375,
              deposit_tax_allowance_eur_pa = if (pm || coin(0.7)) 0 else 1000,
              overdraft_flag_threshold_eur = if (kl_inf && coin(0.3)) {
                ref_gen_round(ru(0, 0.1) * inv)
              } else {
                Inf
              })
  sur <- c("od_repay")
  if (!pm && coin(0.3)) sur <- c(sur, "dep_fill_reserve")
  if (!pm && mode != "simple" && (prepay_any || coin(0.1))) {
    sur <- c(sur, "loan_prepay")
    if (coin(0.5)) acc$prepay <- list(buffer_eur = ref_gen_round(ru(0, 5000)),
                                      min_spread_pa = ref_gen_round(ru(0, 0.01), 4))
  }
  acc$surplus_order <- c(sur, "dep_invest")
  def <- c("dep_withdraw")
  if (pm || coin(0.85)) def <- c(def, "od_draw")
  if (!pm && coin(0.3)) def <- c(def, "dep_use_reserve")
  d4 <- if (pm) "penalty_rate" else pick(c("equity_call", "equity_call", "penalty_rate",
                                           "penalty_rate", "stop"))
  acc$deficit_order <- c(def, d4)
  sc <- list(
    schema_version = 1L,
    meta = list(scenario_id = sprintf("ref_%03d", k), title = sprintf("Zufallsszenario %d", k)),
    project = list(perspective = "wu_privat", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = H),
    components = comps, financing = fin, accounts = acc, residual_value = list(method = "zero"),
    tax = list(module = "none"),
    analysis = list(kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value"),
                    thresholds = list(dscr = 1.2), lending_value_haircut = 0.2)
  )
  if (length(grid) > 0L) sc$grid <- grid
  if (length(fin) == 0L) sc$financing <- NULL
  if (variants) {
    za <- z + c(0, ref_gen_round(stats::runif(t1 - 1L, -0.1, 0.1) * inv))
    sc$project$reference_variant <- "base"
    sc$variants <- list(a = list(label = "Variante a", set = list("components.z.values" = za)))
  }
  sc
}

#' Ein Zufallskredit (Parameter nach Spec 00 8.2 innerhalb der Validierungsgrenzen)
ref_gen_loan <- function(g, inv, mode, ru, pick, coin) {
  pm <- mode == "perfect_market"
  type <- pick(c("annuity_loan", "annuity_loan", "installment_loan", "bullet_loan"))
  ppy <- if (pm || mode == "simple") 1L else pick(c(1L, 1L, 4L, 12L))
  amount <- ref_gen_round(ru(0.1, 0.8) * inv)
  L <- list(type = type, amount_eur = amount, rate_pa = ref_gen_round(ru(0, 0.06), 4),
            payments_per_year = ppy)
  grace <- if (ppy == 1L) pick(c(0, 0, 1, 2)) else pick(c(0, 0, 0.25, 0.5, 1))
  term <- as.double(sample(3:25, 1L))
  starts <- g$date_end[g$date_end < g$end_date]
  if (coin(0.2) && length(starts) > 1L) L$start <- pick(starts[-1L])
  start <- L$start %||% g$valuation_date
  if (coin(0.25)) {
    later <- g$date_end[g$date_end > start & g$date_end < g$end_date]
    if (length(later) >= 1L) {
      nd <- min(length(later), sample(1:3, 1L))
      dts <- sort(c(start, later[sample.int(length(later), nd)]))
      w <- stats::runif(length(dts))
      w <- round(w / sum(w), 4)
      w[length(w)] <- 1 - sum(w[-length(w)])
      sched <- stats::setNames(as.list(w), format(dts, "%Y-%m-%d"))
      L$draw_schedule <- list(schedule = sched, unit = "share")
      if (!pm && coin(0.6)) {
        L$fees <- list(commitment_fee_rate_month = ref_gen_round(ru(0, 0.003), 5),
                       commitment_free_months = sample(0:6, 1L))
      }
    }
  }
  if (type == "annuity_loan") {
    if (pm || coin(0.6)) {
      L$term_years <- term
    } else {
      L$initial_repayment_pa <- ref_gen_round(ru(0.01, 0.05), 4)
      if (coin(0.3)) L$term_years <- term
    }
  } else {
    L$term_years <- term
  }
  if (grace > 0 && grace < (L$term_years %||% 99)) L$grace_years <- grace
  if (!pm && coin(0.35) && type != "bullet_loan") {
    L$fixed_years <- as.double(sample.int(max(1L, floor(g$tau[g$T + 1L])), 1L))
    L$followup_rate_pa <- ref_gen_round(ru(0, 0.07), 4)
    if (coin(0.3)) L$followup_spread_pa <- ref_gen_round(ru(0, 0.01), 4)
    if (coin(0.3)) L$followup_fixed_years <- as.double(sample(1:3, 1L))
    rules <- if (type == "installment_loan") c("keep_term", "keep_payment") else
      c("keep_term", "keep_payment", if (!is.null(L$initial_repayment_pa)) "keep_tilg_rate")
    if (is.null(L$term_years)) rules <- setdiff(rules, "keep_term")
    L$refi_rule <- pick(rules)
  } else if (!pm && coin(0.2) && type == "bullet_loan") {
    L$fixed_years <- as.double(sample.int(max(1L, floor(g$tau[g$T + 1L])), 1L))
    L$followup_rate_pa <- ref_gen_round(ru(0, 0.07), 4)
  }
  if (!pm) {
    if (coin(0.2)) L$payout_rate <- ref_gen_round(ru(0.95, 1), 4)
    if (coin(0.2)) {
      L$fees <- c(L$fees %||% list(), list(processing_fee_share = ref_gen_round(ru(0, 0.02), 4)))
    }
    if (mode != "simple" && coin(0.3)) {
      L$prepay_allowed <- TRUE
      if (coin(0.5)) L$prepay_cap_share_pa <- ref_gen_round(ru(0.02, 0.2), 4)
    }
  }
  # Tilgungszuschuss und geplante Sondertilgung (auch im vollkommenen Markt, I4)
  if (coin(0.25) && type != "bullet_loan") {
    d <- pick(g$date_end[g$date_end >= start])
    L$funding_id <- "foe"
    L$repayment_grant <- if (coin(0.5)) {
      list(amount_eur = ref_gen_round(ru(0, 0.2) * amount))
    } else {
      list(share = ref_gen_round(ru(0, 0.2), 4))
    }
    L$repayment_grant$date <- d
    L$repayment_grant$effect <- pick(c("shorten_term", "reduce_installment"))
  }
  cand <- g$date_end[g$date_end > start]
  if (coin(0.15) && length(cand) > 0L) {
    d <- pick(cand)
    sched <- stats::setNames(list(ref_gen_round(ru(0, 0.2) * amount)), format(d, "%Y-%m-%d"))
    L$planned_prepayments <- list(schedule = sched, unit = "eur")
  }
  L
}

# ---------------------------------------------------------------------------------------------
# 10. Laufzeitinvarianten, unabhängig nachgerechnet (Spec 00 9.7, 15.4 "I1-I3")
# ---------------------------------------------------------------------------------------------

#' Invarianten I1, I2, I3a, I3b, I3c, N1, N2 eines Ergebnisses je Lauf nachrechnen
#'
#' @param res vofi_result bzw. vofi_mc_result mit Ledger (`store = "full"`).
#' @param lmin Mindestliquidität (Skalar oder n x (T+1)); I3b nur, wenn sie überall 0 ist.
#' @param kl Kontokorrentlimit (Skalar oder n x (T+1)) für I3c.
#' @return data.frame(invariant, max_dev, tol, ok); Abweichungen I1, I2, N2 relativ zum Volumen
#'   max_t sum(abs(zahlungswirksame Zeilen in t)) (2.13).
ref_invariants <- function(res, lmin = 0, kl = Inf) {
  led <- res$ledger
  rows <- led$rows
  v <- led$values
  n <- as.integer(led$n)
  t1 <- as.integer(led$T) + 1L
  zero <- matrix(0, n, t1)
  tot <- function(sel) {
    ks <- rows$key[sel]
    if (length(ks) == 0L) zero else Reduce(`+`, lapply(ks, function(k) v[[k]]))
  }
  secs <- c("project", "grants", "equity", "loans", "overdraft", "deposit", "tax")
  cash <- rows$cash & rows$section %in% secs
  abs_sum <- Reduce(`+`, lapply(rows$key[cash], function(k) abs(v[[k]])), zero)
  vol <- pmax(1, apply(abs_sum, 1L, max))
  i1 <- max(apply(abs(tot(cash)), 1L, max) / vol)
  bs <- v[["net_position"]] %||% zero
  tl <- v[["tax_liability"]] %||% zero
  lag <- function(m) cbind(0, m[, -t1, drop = FALSE])
  flow <- tot(cash & rows$tax_category != "principal") + tot(rows$category == "repayment_grant") -
    tot(rows$category == "disagio") - tot(rows$category == "assumed") - (tl - lag(tl))
  i2 <- max(apply(abs(bs - lag(bs) - flow), 1L, max) / vol)
  st <- rows$key[rows$section == "stocks" & rows$category == "balance"]
  i3a <- if (length(st) > 0L) max(0, -min(unlist(lapply(v[st], min)))) else 0
  g <- v[["dep_balance"]] %||% zero
  kk <- (v[["od_balance"]] %||% zero) + (v[["odp_balance"]] %||% zero)
  i3b <- if (all(lmin == 0)) max(0, pmin(g, kk)) else 0
  klm <- if (is.matrix(kl)) kl else matrix(kl, n, t1)
  od <- v[["od_balance"]] %||% zero
  fin <- is.finite(klm)
  i3c <- if (any(fin)) max(0, (od - klm)[fin]) else 0
  n1 <- all(vapply(v, function(m) all(is.finite(m)), logical(1)))
  n2 <- 0
  if (!is.null(res$kpis$terminal_value_ex_rv) && !is.null(res$kpis$terminal_value)) {
    rw <- tot(rows$category %in% c("residual_value", "sale_cost") & rows$cash)[, t1]
    d <- abs(res$kpis$terminal_value_ex_rv - (res$kpis$terminal_value - rw))
    n2 <- max(0, (d / vol)[is.finite(d)])
  }
  out <- data.frame(invariant = c("I1", "I2", "I3a", "I3b", "I3c", "N1", "N2"),
                    max_dev = c(i1, i2, i3a, i3b, i3c, if (n1) 0 else Inf, n2),
                    tol = c(1e-8, 1e-8, 1e-6, 1e-6, 1e-6, 0, 1e-8),
                    stringsAsFactors = FALSE)
  out$ok <- out$max_dev <= out$tol
  out
}

#' Invarianten eines Ergebnisses mit Kontoparametern aus dem Modell prüfen
expect_ref_invariants <- function(res, model, info = NULL) {
  mc <- if (identical(res$meta$mode, "deterministic")) NULL else res
  s <- spec_simple_from_model(model, mc)
  inv <- ref_invariants(res, lmin = s$accounts$min_liquidity_eur,
                        kl = s$accounts$overdraft_limit_eur)
  bad <- inv[!inv$ok, , drop = FALSE]
  msg <- paste0("Invarianten verletzt", if (!is.null(info)) paste0(" (", info, ")"), ": ",
                paste0(bad$invariant, " (", format(bad$max_dev), ")", collapse = ", "))
  testthat::expect(nrow(bad) == 0L, msg)
  invisible(inv)
}

# nolint end
