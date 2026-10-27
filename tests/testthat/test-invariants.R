# Invarianten (WS-T; Spec 00 Abschnitte 9.4, 9.5, 9.7, 15.4; Memo 01 §3.5, §4.3).
#
# I1-I3, N1, N2 unabhängig nachgerechnet (ref_invariants()) für Orakel, Beispielszenarien,
# Zufallsszenarien und alle Läufe einer MC; I4 vollkommener Kapitalmarkt; I5 Monotonie der
# Entnahme-Zielfunktion; I6 Unterlassungsalternative; V1 Vergleichsregel; R3 Rangidentität;
# Prüffälle 9.4 (Terminalzustand ohne Restwert), 9.5 (Unterlassung ohne eigene Nachschüsse,
# Sacheinlage); G Eigenschaften des Zufallsszenario-Generators.

# inv_run(), inv_q(), inv_sum(), inv_f_pkg(): helper-reference-engine.R (Abschnitt 11).

#' Prüfszenario in Rohform (Jahresraster ab 2027-01-01)
inv_scenario <- function(horizon, components, financing = list(), accounts = list(), ...) {
  acc <- utils::modifyList(list(deposit_rate_pa = 0, overdraft_rate_pa = 0,
                                overdraft_limit_eur = Inf, penalty_spread_pa = 0,
                                min_liquidity_eur = 0, deposit_withholding_tax_share = 0,
                                surplus_order = c("od_repay", "dep_invest"),
                                deficit_order = c("dep_withdraw", "od_draw", "equity_call")),
                           accounts)
  raw <- list(
    schema_version = 1L, meta = list(scenario_id = "inv", title = "Invariantenpruefung"),
    project = list(perspective = "wu_privat", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = as.integer(horizon)),
    components = components, financing = financing, accounts = acc,
    residual_value = list(method = "zero"), tax = list(module = "none"),
    analysis = list(kpis = "terminal_value")
  )
  utils::modifyList(raw, list(...))
}

#' Prüffall 9.4 (Terminalzustand ohne Restwert)
inv_9_4_scenario <- function(kl) {
  comps <- list(
    z = list(type = "custom_series", values = c(-100000, -5000)),
    rv = list(type = "custom_series", category = "residual_value", values = c(0, 90000))
  )
  inv_scenario(1L, components = comps,
               financing = list(ek = list(type = "equity", amount_eur = 100000)),
               accounts = list(overdraft_limit_eur = kl))
}

#' Prüffall 9.5 (Unterlassung ohne eigene Nachschüsse)
inv_9_5_scenario <- function() {
  inv_scenario(5L,
               components = list(z = list(type = "custom_series",
                                          values = c(-10000, rep(5000, 5)))),
               financing = list(ek = list(type = "equity", amount_eur = 10000,
                                          withdrawals_pa = 4000)),
               accounts = list(overdraft_limit_eur = 0, penalty_spread_pa = 0))
}

#' Prüffall Sacheinlage (R-68)
inv_sach_scenario <- function(with_value = TRUE) {
  comps <- list(
    rent = list(type = "custom_series", category = "rent", values = c(0, 30000)),
    rv = list(type = "custom_series", category = "residual_value", values = c(0, 510000)),
    sc = list(type = "custom_series", category = "sale_cost", values = c(0, -15300))
  )
  alt <- list(type = "bullet_loan", existing = TRUE, amount_eur = 200000, rate_pa = 0.03,
              term_years = 5, payments_per_year = 1L)
  raw <- inv_scenario(1L, components = comps, financing = list(alt = alt),
                      accounts = list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08),
                      residual_value = list(method = "zero", sale_cost_share = 0.03),
                      analysis = list(kpis = "terminal_value",
                                      allow_opportunity_reference = TRUE))
  raw$project$project_type <- "sanierung_einzelmassnahmen"
  # Pflichtangaben bei Block building (Spec 01 Teil A 3.3, 3.4, 6.2; WS-B): Baujahr bzw. WE-Zahl,
  # Instandhaltungspauschale abgeschaltet; ohne Expander (WS-E2) ohne Zahlungswirkung
  raw$building <- list(construction_year = 1972L, n_units = 6L,
                       maintenance = list(enabled = FALSE))
  if (with_value) raw$building$existing_value_eur <- 500000
  raw
}

# ---------------------------------------------------------------------------------------------
# I1-I3, N1, N2 (9.7), unabhängig nachgerechnet
# ---------------------------------------------------------------------------------------------

test_that("ref_invariants() erkennt verletzte Invarianten", {
  res <- oracle_result("a")
  inv <- ref_invariants(res)
  expect_identical(inv$invariant, c("I1", "I2", "I3a", "I3b", "I3c", "N1", "N2"))
  expect_true(all(inv$ok))
  bad <- res
  bad$ledger$values$od_interest[1L, 3L] <- bad$ledger$values$od_interest[1L, 3L] - 10
  inv <- ref_invariants(bad)
  expect_false(inv$ok[inv$invariant == "I1"])
  expect_false(inv$ok[inv$invariant == "I2"])
  bad <- res
  bad$ledger$values$dep_balance[1L, 3L] <- -1
  bad$ledger$values$od_balance[1L, 3L] <- 10
  inv <- ref_invariants(bad, kl = 5)
  expect_false(inv$ok[inv$invariant == "I3a"])
  expect_false(inv$ok[inv$invariant == "I3c"])
  expect_true(ref_invariants(bad, lmin = 100, kl = 5)$ok[4L])
  bad <- res
  bad$ledger$values$dep_interest[1L, 2L] <- NaN
  expect_false(ref_invariants(bad)$ok[6L])
  bad <- res
  bad$kpis$terminal_value_ex_rv <- 0
  expect_false(ref_invariants(bad)$ok[7L])
})

test_that("I1-I3, N1, N2 für alle Orakel und Beispielszenarien (deterministisch)", {
  for (id in setdiff(oracle_ids(), oracle_variant_ids())) {
    res <- oracle_result(id)
    expect_ref_invariants(res, attr(res, "model"), info = id)
    expect_true(all(res$checks$ok), info = id)
  }
  for (v in c("base", "a")) {
    res <- oracle_result("g", variant = v)
    expect_ref_invariants(res, attr(res, "model"), info = paste("g", v))
  }
  skip_if_stub("vofi_example", "vofi_read_scenario")
  n_i3b <- 0L
  n_branch <- 0L
  for (ex in vofi_example()) {
    sc <- vofi_read_scenario(vofi_example(ex))
    res <- oracle_result(ex, scenario = sc)
    # Entscheidungsknoten (S2, Spec 00 9.11): beide Zweige als getrennte Modelle (Variante mit
    # erteilter Zusage, Ausweichvariante), jeweils mit dem Ergebnis ihres Zweigs
    parts <- ref_decision_branches(res, attr(res, "model"))
    n_branch <- n_branch + (length(parts) == 2L)
    for (nm in names(parts)) {
      info <- if (nm == "main") ex else paste(ex, nm)
      # Mindestliquidität und Limit aus dem Modell (mit Defaults, Spec 01 Teil A 5.7): I3b gilt
      # auch ohne ausdrückliches accounts.min_liquidity_eur (Default 0)
      inv <- expect_ref_invariants(parts[[nm]]$res, parts[[nm]]$model, info = info)
      lmin <- spec_simple_from_model(parts[[nm]]$model)$accounts$min_liquidity_eur
      n_i3b <- n_i3b + all(lmin == 0)
      expect_identical(inv$invariant, c("I1", "I2", "I3a", "I3b", "I3c", "N1", "N2"))
      # Differenztest (Spec 00 15.6): Ledger und Kennzahlen gleich der Referenz-Engine
      expect_ref_equal(parts[[nm]]$res, parts[[nm]]$model, info = info)
    }
  }
  # Beispiele ohne ausdrückliche Mindestliquidität (z. B. das Skelett) prüfen I3b
  expect_gt(n_i3b, 0L)
  # S2 hat einen Entscheidungsknoten; beide Zweige laufen über die Referenz-Engine
  expect_gt(n_branch, 0L)
})

test_that("I1-I3, N1, N2 für 50 Zufallsszenarien (unabhängig der Engine-Prüfung)", {
  scs <- ref_scenario_generator(20261101L, 50L, "full")
  for (raw in scs) {
    res <- inv_run(raw)
    expect_ref_invariants(res, attr(res, "model"), info = raw$meta$scenario_id)
    expect_true(all(res$checks$ok), info = raw$meta$scenario_id)
  }
})

test_that("I1-I3 für alle Läufe einer MC mit n = 2.000 (store = full)", {
  sc <- vofi_read_scenario(system.file("extdata", "examples", "grob_lehrbuch_a.yaml",
                                       package = "vofi"))
  kp <- c("terminal_value", "terminal_value_opp", "delta_terminal_value")
  model <- withCallingHandlers(
    vofi_build(sc, overrides = list(analysis = list(kpis = kp))),
    vofi_message = function(m) invokeRestart("muffleMessage")
  )
  mc <- tryCatch(vofi_run(model, n_sim = 2000L, seed = 20261025L, store = "full"),
                 vofi_error_not_implemented = function(e) {
                   skip(paste("Monte-Carlo noch nicht implementiert:", conditionMessage(e)))
                 })
  expect_identical(as.integer(mc$ledger$n), 2000L)
  inv <- ref_invariants(mc)
  expect_true(all(inv$ok), info = utl_collapse(inv$invariant[!inv$ok]))
  expect_true(all(mc$checks$ok))
})

# ---------------------------------------------------------------------------------------------
# I4 vollkommener Kapitalmarkt
# ---------------------------------------------------------------------------------------------

#' I4: dEW - (1+i)^T * [KW_i(z) + KW_i(ZU) + KW_i(TZ)] (Spec 00 15.4)
inv_i4_gap <- function(res, i) {
  t1 <- res$ledger$T + 1L
  tau <- c(0, cumsum(res$grid$delta[-1L]))
  d <- (1 + i)^(-tau)
  z <- inv_sum(res, section = "project", cash = TRUE)
  zu <- inv_sum(res, section = "grants", cash = TRUE)
  tz <- inv_sum(res, category = "repayment_grant")
  rhs <- (1 + i)^tau[t1] * sum((z + zu + tz) * d)
  res$kpis$delta_terminal_value - rhs
}

test_that("I4: Orakel (d) und (b2) erfüllen die Kapitalwertidentität", {
  res <- oracle_result("d")
  expect_lt(abs(inv_i4_gap(res, 0.05)), 1e-8 * 1e5)
  res <- oracle_result("b2")
  expect_lt(abs(inv_i4_gap(res, 0.02)), 1e-8 * 2e5)
  expect_equal(res$kpis$delta_terminal_value,
               (-13524.20004670642 + 22500 / 1.02) * 1.02^10, tolerance = 1e-12)
})

test_that("I4: 50 Zufallsszenarien im vollkommenen Kapitalmarkt (Generatorregel G)", {
  scs <- ref_scenario_generator(20261102L, 50L, "perfect_market")
  n_tz <- 0L
  for (raw in scs) {
    i <- raw$accounts$deposit_rate_pa
    res <- inv_run(raw)
    vol <- max(1, unlist(lapply(res$ledger$values, abs)))
    expect_lt(abs(inv_i4_gap(res, i)), 1e-8 * vol)
    n_tz <- n_tz + any(inv_sum(res, category = "repayment_grant") > 0)
    ref <- ref_engine_run(spec_simple_from_model(attr(res, "model")))
    expect_lt(abs(ref$kpis$delta_terminal_value - res$kpis$delta_terminal_value), 1e-8 * vol)
  }
  expect_gt(n_tz, 0L)
})

# ---------------------------------------------------------------------------------------------
# I5 Monotonie der Entnahme-Zielfunktion (12.8)
# ---------------------------------------------------------------------------------------------

#' f(E) der Referenz-Engine (Zusatzentnahme E * delta in t >= 1)
inv_f_ref <- function(s, e_amt) {
  res <- ref_run_one(s, 1L)
  t1 <- length(s$months)
  ac <- res$run$ac
  q <- cumprod(c(1, 1 + (ac$h - ac$w * pmax(ac$h, 0))[-1L]))
  run <- ref_invest_run(s, 1L, extra = -e_amt * s$months / 12)
  rows <- ref_run_rows(s, 1L, run)
  ns <- rows$equity_call + rows$shortfall
  rows$net_position[t1] - sum((ns - res$ns) * q[t1] / q) - res$opp$EW
}

test_that("I5: f(E) streng fallend, Steigung <= -T_J bei nichtnegativen Zinsen ((c2), Paket)", {
  raw <- oracle_scenario("c2")
  base <- inv_run(raw)
  t_j <- 10
  for (e_amt in c(-5000, 0, 1000, 4831, 10000)) {
    d <- inv_f_pkg(raw, e_amt + 1, base) - inv_f_pkg(raw, e_amt, base)
    expect_lt(d, 0)
    expect_lte(d, -t_j + 1e-9)
  }
  # Nullstelle von f = Entnahme-Äquivalent aus der Fixture (Nachschusskorrektur, 12.8)
  we <- oracle_kpi_value(oracle_expected("c2"), "withdrawal_equivalent")
  expect_lt(abs(inv_f_pkg(raw, we, base)), 1e-6)
})

test_that("I5: Paket und Referenz-Engine auf 20 Zufallsszenarien mit h_net, s, sp >= 0", {
  scs <- ref_scenario_generator(20261103L, 20L, "nonneg")
  for (raw in scs) {
    id <- raw$meta$scenario_id
    base <- inv_run(raw)
    s <- spec_simple_from_model(attr(base, "model"))
    t_j <- sum(s$months) / 12
    vol <- max(1, unlist(lapply(base$ledger$values, abs)))
    for (e_amt in c(-2000, 0, 3000)) {
      f_ref <- c(inv_f_ref(s, e_amt), inv_f_ref(s, e_amt + 1))
      d <- f_ref[2L] - f_ref[1L]
      expect_lt(d, 0)
      expect_lte(d, -t_j + 1e-9)
      if (e_amt == -2000) next
      # Paket (Zusatzentnahme als Baustein equity, 7.12): gleiche Werte und gleiche Schranke
      f_pkg <- c(inv_f_pkg(raw, e_amt, base), inv_f_pkg(raw, e_amt + 1, base))
      d_pkg <- f_pkg[2L] - f_pkg[1L]
      expect_lt(d_pkg, 0, label = id)
      expect_lte(d_pkg, -t_j + 1e-9, label = id)
      expect_lt(max(abs(f_pkg - f_ref)), 1e-8 * vol, label = id)
    }
  }
})

# ---------------------------------------------------------------------------------------------
# I6 Unterlassungsalternative (9.5)
# ---------------------------------------------------------------------------------------------

#' I6-Abweichung EW_U - sum EL_t q_T/q_t (ohne Entnahmen, ohne KK, ohne Pauschbetrag)
inv_i6_gap <- function(res) {
  t1 <- res$ledger$T + 1L
  q <- inv_q(attr(res, "model"))
  el <- inv_sum(res, section = "equity",
                category = c("equity_in", "equity_in_kind", "equity_call", "shortfall"))
  opp <- res$opportunity$ledger$values
  if (!is.null(opp$opp_in_kind_sale)) {
    el[1L] <- el[1L] - inv_sum(res, category = "equity_in_kind")[1L] + opp$opp_in_kind_sale[1L, 1L]
  }
  res$kpis$terminal_value_opp - sum(el * q[t1] / q)
}

test_that("I6: Orakel ohne Entnahmen erfüllen EW_U = sum EL_t q_T / q_t", {
  for (id in c("a", "a3", "b1", "b2", "c1", "c2", "d", "e", "f", "h")) {
    res <- oracle_result(id)
    expect_lt(abs(inv_i6_gap(res)), 1e-6, label = id)
  }
  res <- oracle_result("g", variant = "a")
  expect_lt(abs(inv_i6_gap(res)), 1e-9)
  expect_equal(res$kpis$terminal_value_opp, 10000 * 1.02^2 + 3000 * 1.02, tolerance = 1e-12)
})

test_that("I6: Zufallsszenarien ohne Entnahmen und ohne KK der Alternative", {
  scs <- ref_scenario_generator(20261104L, 40L, "full")
  n_ok <- 0L
  for (raw in scs) {
    if (!is.null(raw$financing$ek$withdrawals_pa)) next
    raw$accounts$deposit_tax_allowance_eur_pa <- 0
    res <- inv_run(raw)
    ov <- res$opportunity$ledger$values
    if (any(ov$od_balance > 0) || any(ov$odp_balance > 0)) next
    n_ok <- n_ok + 1L
    vol <- max(1, abs(res$kpis$terminal_value_opp))
    expect_lt(abs(inv_i6_gap(res)), 1e-8 * vol, label = raw$meta$scenario_id)
  }
  expect_gt(n_ok, 10L)
})

# ---------------------------------------------------------------------------------------------
# V1 Vergleichsregel (9.6 Nr. 4) und R3 Rangidentität (12.3)
# ---------------------------------------------------------------------------------------------

#' V1-Identität aus zwei Variantenläufen: dEW_A - dEW_ref = EW_A - EW_ref - sum dNS q_T/q_t
inv_v1_gap <- function(ra, rb) {
  t1 <- ra$ledger$T + 1L
  q <- inv_q(attr(ra, "model"))
  dns <- inv_sum(ra, category = c("equity_call", "shortfall")) -
    inv_sum(rb, category = c("equity_call", "shortfall"))
  dvr <- ra$kpis$delta_terminal_value - rb$kpis$delta_terminal_value
  dvr - (ra$kpis$terminal_value - rb$kpis$terminal_value - sum(dns * q[t1] / q))
}

inv_opp_uses_kk <- function(res) {
  ov <- res$opportunity$ledger$values
  any(ov$od_balance > 0) || any(ov$odp_balance > 0)
}

test_that("V1: Vergleichsregel auf 50 Zufallsszenarien mit zwei Varianten und Orakel (g)", {
  scs <- ref_scenario_generator(20261105L, 50L, "full", variants = TRUE)
  n_ok <- 0L
  for (raw in scs) {
    raw$accounts$deposit_tax_allowance_eur_pa <- 0
    rb <- inv_run(raw)
    ra <- inv_run(raw, variant = "a")
    if (inv_opp_uses_kk(ra) || inv_opp_uses_kk(rb)) next
    if (isTRUE(ra$flags$stopped) || isTRUE(rb$flags$stopped)) next
    n_ok <- n_ok + 1L
    vol <- max(1, abs(ra$kpis$terminal_value), abs(rb$kpis$terminal_value))
    expect_lt(abs(inv_v1_gap(ra, rb)), 1e-8 * vol, label = raw$meta$scenario_id)
  }
  expect_gt(n_ok, 10L)
  ra <- oracle_result("g", variant = "a")
  rb <- oracle_result("g", variant = "base")
  expect_lt(abs(inv_v1_gap(ra, rb)), 1e-9)
  expect_equal(ra$kpis$delta_terminal_value - rb$kpis$delta_terminal_value, -80,
               tolerance = 1e-12)
})

test_that("V1: delta_vs_reference aus vofi_compare() auf Zufallsszenarien", {
  skip_if_stub("vofi_compare")
  scs <- ref_scenario_generator(20261106L, 10L, "simple", variants = TRUE)
  for (raw in scs) {
    raw$analysis$kpis <- c("terminal_value", "terminal_value_opp", "delta_terminal_value")
    cmp <- withCallingHandlers(vofi_compare(vofi_scenario(raw), variants = "a",
                                            baseline = "base"),
                               vofi_warning_plausibility = function(w) {
                                 invokeRestart("muffleWarning")
                               },
                               vofi_message = function(m) invokeRestart("muffleMessage"))
    ra <- inv_run(raw, variant = "a")
    rb <- inv_run(raw)
    want <- ra$kpis$delta_terminal_value - rb$kpis$delta_terminal_value
    expect_equal(as.numeric(cmp$differences$delta_vs_reference[1L, "a"]), want,
                 tolerance = 1e-10)
  }
})

test_that("R3: sign(roe_mirr - r_U) = sign(dEW) (Referenz-Engine, Paket, Prüffall 9.5)", {
  check_r3 <- function(res, s) {
    out <- ref_run_one(s, 1L)
    t1 <- length(s$months)
    ac <- out$run$ac
    q <- cumprod(c(1, 1 + (ac$h - ac$w * pmax(ac$h, 0))[-1L]))
    t_j <- sum(s$months) / 12
    rows <- out$rows
    e_n <- -ref_rows_sum(s, 1L, function(r) isTRUE(r$cash) && r$category == "equity_out")
    e_l <- ref_rows_sum(s, 1L, function(r) isTRUE(r$cash) && r$category == "equity_in") +
      rows$equity_in_kind + rows$equity_call + rows$shortfall
    den <- sum(e_l / q)
    num_u <- out$opp$EW + sum(e_n * q[t1] / q)
    rm <- out$kpis$roe_mirr$value
    if (den <= 1e-9 || num_u <= 0 || is.na(rm)) return(NA)
    r_u <- (num_u / den)^(1 / t_j) - 1
    d_ew <- out$kpis$delta_terminal_value$value
    if (abs(d_ew) < 1e-6) return(NA)
    ok <- sign(rm - r_u) == sign(d_ew)
    if (!is.null(res$kpis$roe_mirr) && !is.na(res$kpis$roe_mirr)) {
      ok <- ok && sign(res$kpis$roe_mirr - r_u) == sign(res$kpis$delta_terminal_value)
    }
    ok
  }
  scs <- ref_scenario_generator(20261107L, 40L, "full")
  n_ok <- 0L
  for (raw in scs) {
    res <- inv_run(raw, kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value",
                                 "roe_mirr"))
    s <- spec_simple_from_model(attr(res, "model"))
    s$kpis <- c("terminal_value", "delta_terminal_value", "roe_mirr")
    ok <- check_r3(res, s)
    if (is.na(ok)) next
    n_ok <- n_ok + 1L
    expect_true(ok, info = raw$meta$scenario_id)
  }
  expect_gt(n_ok, 10L)
  res <- inv_run(inv_9_5_scenario())
  s <- spec_simple_from_model(attr(res, "model"))
  s$kpis <- c("terminal_value", "delta_terminal_value", "roe_mirr")
  expect_true(check_r3(res, s))
})

# ---------------------------------------------------------------------------------------------
# Prüffälle 9.4, 9.5 und Sacheinlage (Pflicht WS-T)
# ---------------------------------------------------------------------------------------------

test_that("Prüffall 9.4: Terminalzustand ohne Restwert (N2, gap, keine Nachschüsse)", {
  kpis <- c("terminal_value", "terminal_value_opp", "delta_terminal_value")
  for (kl in c(0, Inf)) {
    raw <- inv_9_4_scenario(kl)
    res <- inv_run(raw, kpis = kpis)
    expect_equal(res$kpis$terminal_value, 85000, tolerance = 1e-12)
    expect_equal(res$kpis$terminal_value_ex_rv, -5000, tolerance = 1e-12)
    expect_equal(res$flags$ex_rv_gap, if (kl == 0) 5000 else 0, tolerance = 1e-12)
    expect_equal(inv_sum(res, category = "equity_call"), c(0, 0))
    expect_true(all(ref_invariants(res, kl = kl)$ok))
    ref <- ref_engine_run(spec_simple_from_model(attr(res, "model")))
    expect_equal(ref$terminal_ex_rv$BS, -5000, tolerance = 1e-12)
    expect_equal(ref$terminal_ex_rv$gap, if (kl == 0) 5000 else 0, tolerance = 1e-12)
    expect_equal(ref$terminal_ex_rv$KKP, if (kl == 0) 5000 else 0, tolerance = 1e-12)
    expect_equal(ref$terminal_ex_rv$KK, if (kl == 0) 0 else 5000, tolerance = 1e-12)
    expect_equal(sum(ref$rows$equity_call), 0)
    expect_identical(nrow(ref_compare_result(ref, res)), 0L)
  }
})

test_that("Prüffall 9.5: Unterlassung ohne eigene Nachschüsse (KKP zum Regelzins)", {
  res <- inv_run(inv_9_5_scenario())
  expect_equal(res$kpis$terminal_value, 5000, tolerance = 1e-12)
  expect_equal(sum(inv_sum(res, category = "equity_call")), 0)
  expect_equal(res$kpis$terminal_value_opp, -10000, tolerance = 1e-12)
  expect_equal(res$kpis$delta_terminal_value, 15000, tolerance = 1e-12)
  expect_true(res$flags$opp_limit_breach)
  ov <- res$opportunity$ledger$values
  expect_equal(ov$odp_balance[1L, ], c(0, 0, 0, 2000, 6000, 10000), tolerance = 1e-12)
  expect_equal(sum(ov$equity_call %||% 0), 0)
  ref <- ref_engine_run(spec_simple_from_model(attr(res, "model")))
  expect_equal(ref$opp$EW, -10000, tolerance = 1e-12)
  expect_true(ref$flags$opp_limit_breach)
  expect_identical(nrow(ref_compare_result(ref, res)), 0L)
  # Mit Strafzinsaufschlag bleibt die Alternative beim Regelzins s (R-81)
  raw <- inv_9_5_scenario()
  raw$accounts$overdraft_rate_pa <- 0.05
  raw$accounts$penalty_spread_pa <- 0.03
  res2 <- inv_run(raw)
  ov2 <- res2$opportunity$ledger$values
  expect_equal(ov2$odp_interest[1L, 5L], -2000 * 0.05, tolerance = 1e-12)
  ref2 <- ref_engine_run(spec_simple_from_model(attr(res2, "model")))
  expect_identical(nrow(ref_compare_result(ref2, res2)), 0L)
})

test_that("Prüffall Sacheinlage (R-68): Bestandswert, Bestandsdarlehen, Verkauf", {
  kpis <- c("terminal_value", "terminal_value_opp", "delta_terminal_value", "roe_mirr")
  res <- inv_run(inv_sach_scenario(), kpis = kpis)
  v <- res$ledger$values
  expect_equal(v$equity_in_kind[1L, 1L], 300000)
  expect_equal(v$loan_alt_assumed[1L, 1L], 200000)
  expect_equal(v$net_position[1L, 1L], -200000)
  expect_equal(v$loan_alt_interest[1L, 2L], -6000, tolerance = 1e-12)
  expect_equal(res$kpis$terminal_value, 318700, tolerance = 1e-12)
  expect_equal(res$opportunity$ledger$values$opp_in_kind_sale[1L, 1L], 285000, tolerance = 1e-12)
  expect_equal(res$kpis$terminal_value_opp, 290700, tolerance = 1e-12)
  expect_equal(res$kpis$delta_terminal_value, 28000, tolerance = 1e-12)
  expect_true(all(ref_invariants(res)$ok))
  s <- spec_simple_from_model(attr(res, "model"))
  s$kpis <- c(s$kpis, "roe_mirr", "roe_classic")
  ref <- ref_engine_run(s)
  expect_identical(nrow(ref_compare_result(ref, res)), 0L)
  expect_equal(ref$kpis$roe_mirr, 318700 / 300000 - 1, tolerance = 1e-12)
  expect_equal(round(100 * ref$kpis$roe_mirr, 4), 6.2333)
  if (reg_has("kpi", "roe_mirr")) {
    expect_equal(res$kpis$roe_mirr, 318700 / 300000 - 1, tolerance = 1e-9)
  }
  res0 <- inv_run(inv_sach_scenario(with_value = FALSE), kpis = kpis)
  expect_equal(res0$kpis$terminal_value, 318700, tolerance = 1e-12)
  expect_equal(res0$kpis$terminal_value_opp, 0)
  s0 <- spec_simple_from_model(attr(res0, "model"))
  s0$kpis <- c(s0$kpis, "roe_mirr", "roe_classic")
  ref0 <- ref_engine_run(s0)
  expect_identical(ref0$kpi_na$roe_mirr, "no_existing_value")
  expect_identical(ref0$kpi_na$roe_classic, "no_existing_value")
  expect_identical(nrow(ref_compare_result(ref0, res0)), 0L)
  if (reg_has("kpi", "roe_mirr")) {
    expect_identical(res0$kpi_na$roe_mirr, "no_existing_value")
  }
})

test_that("N2 für alle Orakel: terminal_value_ex_rv = EW - RW_T", {
  for (id in setdiff(oracle_ids(), oracle_variant_ids())) {
    res <- oracle_result(id)
    ex <- oracle_expected(id)
    want <- oracle_kpi_value(ex, "terminal_value_ex_rv")
    expect_lt(abs(res$kpis$terminal_value_ex_rv - want), 1e-6,
              label = id)
    rw <- inv_sum(res, category = c("residual_value", "sale_cost"), cash = TRUE)
    expect_lt(abs(res$kpis$terminal_value_ex_rv - (res$kpis$terminal_value - rw[length(rw)])),
              1e-8 * max(1, abs(res$kpis$terminal_value)), label = id)
  }
})

# ---------------------------------------------------------------------------------------------
# G Zufallsszenario-Generator (15.4)
# ---------------------------------------------------------------------------------------------

test_that("G: Generator ist reproduzierbar und lässt den globalen RNG-Zustand unverändert", {
  set.seed(1)
  before <- .Random.seed
  a <- ref_scenario_generator(42L, 20L, "full")
  expect_identical(.Random.seed, before)
  b <- ref_scenario_generator(42L, 20L, "full")
  expect_identical(a, b)
  expect_false(identical(a, ref_scenario_generator(43L, 20L, "full")))
  ids <- vapply(a, function(x) x$meta$scenario_id, character(1))
  expect_false(anyDuplicated(ids) > 0L)
  expect_length(ref_scenario_generator(42L, 200L, "full"), 200L)
})

test_that("G: Modus full mit Zinspfaden, fallenden Limits und gezielten Fällen; stochastic", {
  scs <- ref_scenario_generator(42L, 36L, "full")
  titles <- vapply(scs, function(x) x$meta$title, character(1))
  k <- seq_along(scs)
  expect_identical(grepl("(gezielt: ", titles, fixed = TRUE), k %% 3L == 0L)
  for (f in ref_gen_features) {
    expect_identical(sum(grepl(paste0("(gezielt: ", f, ")"), titles, fixed = TRUE)), 2L)
  }
  len <- function(p) vapply(scs, function(x) length(x$accounts[[p]]), integer(1))
  expect_gt(sum(len("deposit_rate_pa") > 1L), 0L)
  expect_gt(sum(len("overdraft_rate_pa") > 1L), 0L)
  kl <- Filter(function(x) length(x) > 1L, lapply(scs, function(x) x$accounts$overdraft_limit_eur))
  expect_gt(length(kl), 0L)
  expect_true(all(vapply(kl, function(x) all(diff(x) <= 0), logical(1))))
  fu <- unlist(lapply(scs, function(x) {
    lapply(x$financing, function(b) if (is.numeric(b$followup_rate_pa)) b$followup_rate_pa)
  }), recursive = FALSE)
  expect_true(any(lengths(fu) > 1L))
  # Die übrigen Modi bleiben von den Erweiterungen unberührt (keine Pfade, keine gezielten Fälle)
  for (mode in c("perfect_market", "nonneg", "simple")) {
    for (x in ref_scenario_generator(42L, 12L, mode)) {
      expect_length(x$accounts$deposit_rate_pa, 1L)
      expect_length(x$accounts$overdraft_limit_eur, 1L)
      expect_false(grepl("gezielt", x$meta$title))
    }
  }
  # stochastic = TRUE: gleiche Szenarien, zusätzlich Block stochastic und shared.rv
  b <- ref_scenario_generator(42L, 36L, "full", stochastic = TRUE)
  # einziger Unterschied in financing: das Overlay-Ziel repayment_grant.cut_share steht mit seinem
  # Typ-Default 0 ausdrücklich im Szenario (R-16, ref_gen_stochastic())
  drop_cut <- function(fin, orig) {
    for (k in names(fin)) {
      rg <- fin[[k]]$repayment_grant
      if (!is.null(rg) && identical(rg$cut_share, 0) && is.null(orig[[k]]$repayment_grant$cut_share)) {
        fin[[k]]$repayment_grant$cut_share <- NULL
      }
    }
    fin
  }
  for (q in seq_along(scs)) {
    expect_identical(drop_cut(b[[q]]$financing, scs[[q]]$financing), scs[[q]]$financing)
    expect_identical(b[[q]]$accounts, scs[[q]]$accounts)
    expect_identical(b[[q]]$components$z, scs[[q]]$components$z)
    st <- b[[q]]$stochastic
    expect_identical(st$settings$n_sim, 7L)
    tg <- vapply(st$parameters, function(p) p$target, character(1))
    expect_false(anyDuplicated(tg) > 0L)
    expect_true(all(grepl("^[a-z][a-z0-9_]*$", names(st$parameters))))
    if (!is.null(b[[q]]$shared$rv)) {
      expect_true("shared.rv" %in% tg)
      expect_identical(b[[q]]$components$rv$values[[length(scs[[q]]$components$z$values)]],
                       list(ref = "shared.rv"))
    }
  }
  # Ziehungen je Lauf: reproduzierbar, innerhalb der Träger, Pfade n x (T+1)
  raw <- b[[3L]]
  g <- vofi_time_grid(as.Date("2027-01-01"), raw$project$horizon_years,
                      construction_months = raw$grid$construction_months %||% 0L,
                      construction_step_months = raw$grid$construction_step_months %||% 12L)
  d1 <- ref_gen_draws(raw, g, 7L, 5L)
  expect_identical(d1, ref_gen_draws(raw, g, 7L, 5L))
  for (p in raw$stochastic$parameters) {
    x <- d1$static[[p$target]]
    expect_length(x, 7L)
    if (p$dist == "bernoulli") expect_true(all(x %in% c(0, 1)))
    if (p$dist %in% c("uniform", "triangular")) expect_true(all(x >= p$min & x <= p$max))
  }
  expect_identical(dim(d1$paths[["components.z.values"]]), c(7L, g$T + 1L))
  u <- c(0, 0.25, 0.5, 1)
  expect_equal(ref_q_triangular(u, 30000, 40000, 50000),
               c(30000, 30000 + sqrt(0.25 * 2e8), 40000, 50000))
})

test_that("G: Szenarien sind gültig und erfüllen die Moduseinschränkungen", {
  skip_if_stub("vofi_validate", "vofi_scenario")
  for (mode in c("full", "perfect_market", "nonneg", "simple")) {
    scs <- ref_scenario_generator(20261108L, 15L, mode, variants = mode == "simple")
    for (raw in scs) {
      val <- withCallingHandlers(vofi_validate(vofi_scenario(raw)),
                                 vofi_message = function(m) invokeRestart("muffleMessage"))
      expect_false(any(val$severity == "error"),
                   info = paste(mode, raw$meta$scenario_id,
                                utl_collapse(val$code[val$severity == "error"])))
      acc <- raw$accounts
      loans <- Filter(function(b) !identical(b$type, "equity"), raw$financing %||% list())
      if (mode == "perfect_market") {
        i <- acc$deposit_rate_pa
        expect_null(raw$grid)
        expect_identical(acc$overdraft_rate_pa, i)
        expect_true(is.infinite(acc$overdraft_limit_eur))
        expect_identical(acc$penalty_spread_pa, 0)
        expect_identical(acc$deposit_withholding_tax_share, 0)
        expect_identical(tail(acc$deficit_order, 1L), "penalty_rate")
        expect_false("loan_prepay" %in% acc$surplus_order)
        for (L in loans) {
          expect_identical(L$payments_per_year, 1L)
          expect_identical(L$rate_pa, i)
          expect_null(L$fees)
          expect_null(L$payout_rate)
          expect_null(L$fixed_years)
        }
      }
      if (mode == "nonneg") {
        expect_gte(acc$deposit_rate_pa, 0)
        expect_gte(acc$overdraft_rate_pa, 0)
        expect_gte(acc$penalty_spread_pa, 0)
      }
      if (mode == "simple") {
        expect_false("loan_prepay" %in% acc$surplus_order)
        for (L in loans) expect_identical(L$payments_per_year, 1L)
        expect_true(!is.null(raw$variants$a))
      }
    }
  }
})
