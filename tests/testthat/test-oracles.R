# Testorakel und Referenz-Engine (WS-T; Spec 00 Abschnitte 8.10, 15.3, 15.6 "Differenztests";
# Spec 01 Teil A 5.6 und Teil C 5.6; Memo 01 §10).
#
# 1. Fixtures: vollständig und konsistent mit den Kernwerten von Spec 00 15.3.
# 2. Referenz-Engine: reproduziert alle Orakel (1e-6 EUR, 1e-9 Raten) und die Prüfwerte der
#    Kredittypen (Spec 01 Teil A 5.6, Toleranz 0,005 gegen gerundete Tabellenwerte).
# 3. Paket gegen Orakel: Zeilen und registrierte Kennzahlen je Orakel; (g) über
#    vofi_compare(); grob_lehrbuch_a.yaml (Spec 01 Teil C 5.6).
# 4. Differenztests: Referenz-Engine gegen Paket auf Zufallsszenarien (1e-8 relativ), MC-Batch.

tab_tol <- vofi_tol$oracle_tab

#' Kernwerte (Tabellenwerte) aus Spec 00 15.3 bzw. 8.10: list(<id> = list(<kpi> = Wert))
spec_core_values <- function() {
  list(
    a = list(terminal_value = 38504.63, terminal_value_opp = 34778.22,
             delta_terminal_value = 3726.41, roe_classic = 0.051183, roe_mirr = 0.051183,
             roe_irr = 0.051183, payback_time = 5, min_net_liquidity = -6491.30,
             max_overdraft = 6491.30, withdrawal_equivalent = 672.44, npv_cf_project = 10195.96,
             irr_cf_project = 0.055636),
    a_unlevered = list(terminal_value = 127747.32, roe_mirr = 0.050196),
    a3 = list(terminal_value = 39139.97, delta_terminal_value = 4361.75, roe_mirr = 0.054629),
    b1 = list(terminal_value = 70432.51, terminal_value_opp = 60949.72,
              delta_terminal_value = 9482.79, roe_mirr = 0.034857, max_overdraft = 6421.70,
              withdrawal_equivalent = 731.23, npv_cf_project = -13524.20,
              irr_cf_project = 0.009458, dscr_min = 0.68),
    b2 = list(terminal_value = 71353.38, delta_terminal_value = 10403.66, roe_mirr = 0.036202,
              max_overdraft = 0, withdrawal_equivalent = 950.13, dscr_min = 0.79),
    c1 = list(terminal_value = 34957.28, terminal_value_opp = 0,
              delta_terminal_value = 34957.28, max_overdraft = 59114.48,
              withdrawal_equivalent = 2300.89, ltv_max = 1.0714, irr_cf_project = 0.051616,
              dscr_min = 0.69),
    c1_unlevered = list(terminal_value = 477695.18, roe_mirr = 0.047618),
    c2 = list(terminal_value = 99392.07, terminal_value_opp = 45263.66,
              delta_terminal_value = 54128.41, roe_mirr = 0.108879, roe_irr = 0.169699,
              sum_equity_calls = 39544.46, pv_equity_calls = 35359.90),
    d = list(terminal_value = 41004.58, terminal_value_opp = 38288.45,
             delta_terminal_value = 2716.13, roe_classic = 0.064492),
    e = list(terminal_value = 156540.56, terminal_value_opp = 110381.29,
             delta_terminal_value = 46159.27, roe_mirr = 0.118553, payback_time = 4,
             max_overdraft = 11530.53)
  )
}

#' Rundungstoleranz der Tabellenwerte: 0,005 EUR, Raten auf 4 Stellen in Prozent (5e-7) bzw.
#' Verhältnisse auf 2 Stellen
spec_core_tol <- function(kpi, value) {
  if (grepl("^(dscr_|ltv_)", kpi)) return(0.005 + 1e-4)
  if (grepl("^(roe_|irr_)", kpi)) return(5e-7 + 1e-9)
  tab_tol
}

# ---------------------------------------------------------------------------------------------
# 1. Fixtures
# ---------------------------------------------------------------------------------------------

test_that("Orakel-Fixtures sind vollständig (Szenario, Zeilen, Kennzahlen je Orakel)", {
  files <- list.files(oracle_dir())
  for (id in oracle_ids()) {
    for (f in paste0(id, c(".yaml", "_rows.csv", "_kpis.csv"))) {
      expect_true(f %in% files, info = f)
    }
    ex <- oracle_expected(id)
    expect_true(all(c("row_key", "t", "value", "variant") %in% names(ex$rows)))
    expect_true(all(c("kpi", "value", "na_reason", "variant") %in% names(ex$kpis)))
    expect_true(all(is.finite(ex$rows$value)), info = id)
    expect_false(anyNA(ex$kpis$value[is.na(ex$kpis$na_reason)]), info = id)
    expect_true(all(is.na(ex$kpis$value[!is.na(ex$kpis$na_reason)])), info = id)
    expect_true(all(ex$kpis$na_reason[!is.na(ex$kpis$na_reason)] %in% vocab_codes("na_reasons")),
                info = id)
    key_t <- paste(ex$rows$row_key, ex$rows$t, ex$rows$variant)
    expect_false(anyDuplicated(key_t) > 0L, info = id)
    for (v in unique(ex$rows$variant)) {
      r <- ex$rows[ex$rows$variant %in% v, , drop = FALSE]
      bc <- r$value[r$row_key == "balance_check"]
      expect_true(max(abs(bc)) <= 1e-6, info = paste(id, "balance_check"))
    }
  }
  expect_identical(oracle_variant_ids(), "g")
  expect_setequal(unique(oracle_expected("g")$kpis$variant), c("base", "a"))
})

test_that("Fixtures stimmen mit den Kernwerten von Spec 00 15.3 überein (Tabellentoleranz)", {
  core <- spec_core_values()
  for (id in names(core)) {
    ex <- oracle_expected(id)
    for (k in names(core[[id]])) {
      want <- core[[id]][[k]]
      got <- oracle_kpi_value(ex, k)
      expect_true(!is.na(got) && abs(got - want) <= spec_core_tol(k, want),
                  info = sprintf("%s %s: %.8f statt %.8f", id, k, got, want))
    }
  }
  a <- oracle_expected("a")
  expect_abs(a$rows$value[a$rows$row_key == "opp_net_position"],
             c(30000, 30900, 31827, 32781.81, 33765.26, 34778.22), tab_tol)
  expect_identical(a$kpis$na_reason[a$kpis$kpi == "payback_time_ex_rv"], "no_payback")
  a3 <- oracle_expected("a3")
  expect_abs(oracle_row_value(a3, "loan_ann_prepay", 3), -11863.72, tab_tol)
  expect_abs(oracle_row_value(a3, "dep_balance", 5), 39139.97, tab_tol)
  b1 <- oracle_expected("b1")
  dscr <- c(4.67, 5.60, 0.68, 0.71, 0.74, 0.77, 0.80, 0.83, 1.07)
  kd <- -(b1$rows$value[b1$rows$row_key == "loan_foe_interest"] +
            b1$rows$value[b1$rows$row_key == "loan_foe_repay_total"])
  noi <- 14000 * 1.02^(0:9)
  expect_equal(round(noi[1:9] / kd[2:10], 2), dscr)
  b2 <- oracle_expected("b2")
  expect_abs(b2$rows$value[b2$rows$row_key == "loan_foe_repay_total"][4:11], rep(-15937.50, 8),
             tab_tol)
  c1 <- oracle_expected("c1")
  for (k in c("roe_classic", "roe_mirr", "roe_irr")) {
    expect_identical(c1$kpis$na_reason[c1$kpis$kpi == k], "no_equity")
  }
  c2 <- oracle_expected("c2")
  expect_identical(c2$kpis$na_reason[c2$kpis$kpi == "roe_classic"], "no_equity")
  d <- oracle_expected("d")
  z <- c(-100000, 6000, 10000, 30000, 8000, 70000)
  expect_abs(oracle_kpi_value(d, "delta_terminal_value"), sum(z / 1.05^(0:5)) * 1.05^5, 1e-9)
  e <- oracle_expected("e")
  expect_abs(oracle_row_value(e, "loan_bau_fees", 2), -1500, tab_tol)
  expect_abs(oracle_row_value(e, "loan_bau_fees", 3), -750, tab_tol)
  expect_abs(oracle_row_value(e, "dep_interest", 7) / oracle_row_value(e, "dep_balance", 6),
             0.025, 1e-9)
  f <- oracle_expected("f")
  expect_abs(oracle_row_value(f, "loan_ann_interest", 1), -3542.98, tab_tol)
  expect_abs(oracle_row_value(f, "loan_ann_repay_total", 1), -3478.36, tab_tol)
  expect_abs(oracle_row_value(f, "loan_ann_balance", 1), 96521.64, tab_tol)
  rate_f <- -(oracle_row_value(f, "loan_ann_interest", 1) +
                oracle_row_value(f, "loan_ann_repay_total", 1)) / 12
  expect_abs(rate_f, 585.11, tab_tol)
  h <- oracle_expected("h")
  expect_abs(oracle_row_value(h, "loan_rat_interest", 1), -2290, tab_tol)
  expect_abs(oracle_row_value(h, "loan_rat_balance", 5), 60000, tab_tol)
  expect_abs(oracle_row_value(h, "loan_rat_interest", 6), -2180, tab_tol)
  expect_abs(oracle_row_value(h, "loan_rat_repay_total", 6), -12000, tab_tol)
  expect_abs(oracle_row_value(h, "loan_rat_balance", 8), 24000, tab_tol)
  expect_abs(oracle_row_value(h, "loan_rat_balance", 10), 0, tab_tol)
  expect_abs(h$rows$value[h$rows$row_key == "loan_rat_repay_total"][-1L], rep(-12000, 10), 1e-9)
  g <- oracle_expected("g")
  expect_abs(oracle_row_value(g, "equity_call", 1, "a"), 3000, 1e-9)
  expect_abs(oracle_kpi_value(g, "terminal_value", "a"), 16000, 1e-9)
  expect_abs(oracle_kpi_value(g, "terminal_value_opp", "a"), 13464, 1e-9)
  expect_abs(oracle_kpi_value(g, "delta_terminal_value", "a"), 2536, 1e-9)
  expect_abs(oracle_kpi_value(g, "terminal_value", "base"), 13020, 1e-9)
  expect_abs(oracle_kpi_value(g, "terminal_value_opp", "base"), 10404, 1e-9)
  expect_abs(oracle_kpi_value(g, "delta_terminal_value", "base"), 2616, 1e-9)
  expect_abs(oracle_kpi_value(g, "delta_vs_reference", "a"), -80, 1e-9)
  expect_abs(oracle_kpi_value(g, "delta_vs_reference", "a"), (16000 - 13020) - 3000 * 1.02, 1e-9)
  expect_abs(oracle_kpi_value(g, "sum_equity_calls", "a"), 3000, 1e-9)
  expect_abs(oracle_kpi_value(g, "pv_equity_calls", "a"), 2941.18, tab_tol)
  expect_equal(oracle_kpi_value(g, "sum_equity_calls", "base"), 0)
})

test_that("Orakelszenarien sind kanonisches YAML und lesbar (Spec 00 15.3)", {
  for (id in oracle_ids()) {
    sc <- oracle_scenario(id)
    expect_s3_class(sc, "vofi_scenario")
    expect_identical(sc$meta$scenario_id, paste0("oracle_", id))
    expect_identical(sc$project$valuation_date, as.Date("2027-01-01"))
    expect_identical(sc$tax$module, "none")
    expect_identical(sc$accounts$deficit_order, c("dep_withdraw", "od_draw", "equity_call"))
    loans <- Filter(function(b) !identical(b$type, "equity"), sc$financing)
    ppy <- vapply(loans, function(b) as.integer(b$payments_per_year), integer(1))
    expect_true(all(ppy == if (id %in% c("f", "h")) 12L else 1L), info = id)
  }
  expect_identical(oracle_scenario("a3")$accounts$surplus_order,
                   c("od_repay", "loan_prepay", "dep_invest"))
  expect_identical(oracle_scenario("c2")$accounts$overdraft_limit_eur, node_const(0))
  expect_identical(oracle_scenario("e")$grid$periods_months, c(3L, 3L, 3L, 3L, 12L, 12L, 12L))
})

# ---------------------------------------------------------------------------------------------
# 2. Referenz-Engine gegen die Orakel und die Prüfwerte der Kredittypen
# ---------------------------------------------------------------------------------------------

test_that("Referenz-Engine reproduziert alle Orakel (Zeilen 1e-6, Kennzahlen 1e-6/1e-9)", {
  for (id in setdiff(oracle_ids(), oracle_variant_ids())) {
    ref <- oracle_ref_run(id)
    unchecked <- expect_oracle(ref_as_result(ref), id)
    expect_length(unchecked, 0L)
  }
  for (v in c("base", "a")) {
    ref <- oracle_ref_run("g", variant = v)
    unchecked <- expect_oracle(ref_as_result(ref), "g", variant = v)
    expect_setequal(unchecked, if (v == "a") c("delta_vs_reference", "delta_vs_reference_ex_rv",
                                               "prob_better_than_ref") else character(0))
  }
})

#' Lehrbuchfall (a) unmittelbar als Referenzeingabe (ohne Paket)
ref_spec_oracle_a <- function(n = 1L) {
  m <- function(x) matrix(x, n, 6L, byrow = TRUE)
  list(
    n = n, months = c(0, rep(12, 5)), year = c(2027L, 2027:2031), op_year = 0:5,
    op_year_full = c(FALSE, rep(TRUE, 5)), phase = rep("operation", 6),
    rows = list(z__value = list(values = m(c(-100000, 6000, 10000, 30000, 8000, 30000)),
                                section = "project", category = "custom", cash = TRUE),
                rv__value = list(values = m(c(0, 0, 0, 0, 0, 40000)), section = "project",
                                 category = "residual_value", cash = TRUE),
                ek__in = list(values = m(c(30000, 0, 0, 0, 0, 0)), section = "equity",
                              category = "equity_in", cash = TRUE)),
    loans = list(
      ann = list(id = "ann", repayment = "annuity", commitment = 40000, rate_pa = 0.06,
                 ppy = 1L, term_months = 60),
      bul = list(id = "bul", repayment = "bullet", commitment = 30000, rate_pa = 0.05,
                 ppy = 1L, term_months = 60)
    ),
    accounts = list(deposit_rate_pa = 0.03, overdraft_rate_pa = 0.10, overdraft_limit_eur = Inf,
                    surplus = c("od_repay", "dep_invest"),
                    deficit = c("dep_withdraw", "od_draw", "equity_call")),
    analysis = list(), kpis = NULL
  )
}

test_that("Referenz-Engine ohne Paket: Orakel (a) aus einer handgeschriebenen Eingabe", {
  ref <- ref_engine_run(ref_spec_oracle_a())
  ex <- oracle_expected("a")
  view <- oracle_view(ref_as_result(ref))
  mm <- merge(ex$rows, view, by = c("row_key", "t"), suffixes = c("", "_ref"))
  expect_identical(nrow(mm), nrow(ex$rows))
  expect_lt(max(abs(mm$value - mm$value_ref)), 1e-6)
  for (q in seq_len(nrow(ex$kpis))) {
    k <- ex$kpis$kpi[q]
    if (is.na(ex$kpis$value[q])) {
      expect_identical(ref$kpi_na[[k]], ex$kpis$na_reason[q], info = k)
    } else {
      expect_abs(ref$kpis[[k]], ex$kpis$value[q], 1e-9, info = k)
    }
  }
  expect_true(is.na(ref$kpis$dscr_min) && ref$kpi_na$dscr_min == "no_debt_service" ||
                is.finite(ref$kpis$dscr_min))
  expect_identical(ref$kpi_na$ltv_max, "no_market_value")
  expect_identical(ref$kpi_na$terminal_value_real, "no_inflation_path")
  expect_abs(ref$terminal_ex_rv$BS, 38504.629207797145 - 40000, 1e-9)
  expect_equal(ref$terminal_ex_rv$gap, 0)
})

test_that("Referenz-Engine: Batch n > 1 ist zeilenweise gleich den Einzelläufen", {
  s <- ref_spec_oracle_a(n = 3L)
  s$rows$z__value$values[2L, ] <- s$rows$z__value$values[2L, ] * 1.1
  s$rows$rv__value$values[3L, 6L] <- 25000
  s$loans$ann$rate_pa <- c(0.06, 0.04, 0.08)
  s$accounts$deposit_rate_pa <- matrix(c(0.03, 0.01, 0.05), 3L, 6L)
  s$accounts$overdraft_limit_eur <- matrix(c(Inf, 2000, 0), 3L, 6L)
  batch <- ref_engine_run(s)
  for (i in 1:3) {
    single <- ref_engine_run(ref_spec_subset(s, i))
    for (k in names(single$rows)) {
      expect_identical(batch$rows[[k]][i, , drop = FALSE], single$rows[[k]], info = k)
    }
    expect_identical(batch$opp$BS[i, , drop = FALSE], single$opp$BS)
    for (k in names(single$kpis)) {
      expect_identical(batch$kpis[[k]][i], single$kpis[[k]], info = k)
      expect_identical(batch$kpi_na[[k]][i], single$kpi_na[[k]], info = k)
    }
  }
  expect_false(isTRUE(all.equal(batch$kpis$terminal_value[1L], batch$kpis$terminal_value[2L])))
  expect_true(batch$kpis$terminal_value[3L] < batch$kpis$terminal_value[1L])
})

#' Kreditplan der Referenz-Engine für einen Einzelkredit (Monatsuhr 8.5)
ref_loan_plan <- function(loan, months) {
  m_end <- cumsum(months)
  pl <- ref_loan_schedules(list(ref_loan_init(loan, 1L, m_end)), m_end)[[1L]]
  pl$rows <- as.data.frame(pl$rows)
  pl
}

test_that("Referenz-Engine: Prüfwerte (f) und (h) der Kredittypen (Spec 00 8.10)", {
  f <- ref_loan_plan(list(id = "f", repayment = "annuity", commitment = 100000, rate_pa = 0.036,
                          ppy = 12L, term_months = 240), c(0, rep(12, 20)))
  expect_abs(-f$rows[2L, "interest"], 3542.98, tab_tol)
  expect_abs(-f$rows[2L, "repay"], 3478.36, tab_tol)
  expect_abs(f$rows[2L, "balance"], 96521.64, tab_tol)
  expect_abs(-(f$rows[2L, "interest"] + f$rows[2L, "repay"]) / 12, 585.11, tab_tol)
  expect_equal(f$state$inst, 100000 * 0.003 / (1 - 1.003^-240), tolerance = 1e-12)
  expect_lt(abs(f$rows[21L, "balance"]), 1e-6)
  h <- ref_loan_plan(list(id = "h", repayment = "installment", commitment = 120000,
                          rate_pa = 0.02, ppy = 12L, term_months = 120, fixed_months = 60,
                          followup = 0.04), c(0, rep(12, 10)))
  expect_abs(-h$rows[2L, "interest"], 2290, 1e-9)
  expect_abs(h$rows[6L, "balance"], 60000, 1e-9)
  expect_abs(-h$rows[7L, "interest"], 2180, 1e-9)
  expect_abs(-h$rows[7L, "repay"], 12000, 1e-9)
  expect_abs(h$rows[9L, "balance"], 24000, 1e-9)
  expect_abs(h$rows[11L, "balance"], 0, 1e-9)
  expect_abs(h$rows[-1L, "repay"], rep(-12000, 10), 1e-9)
  expect_identical(h$state$i_pa, 0.04)
})

#' Raster L1/L2 (KfW 261, S1 V2): Jahresraster 30 Jahre
l1_loan <- function(effect = "shorten_term", approved = 1, cut = 0) {
  list(id = "kfw", repayment = "annuity", commitment = 1300000, rate_pa = 0.0365, ppy = 1L,
       term_months = 360, grace_months = 60, fixed_months = 120, followup = 0.04,
       approved = approved,
       tz = list(type = "amount", value = 144400, t = 1L, effect = effect, cut = cut))
}

test_that("Referenz-Engine: Prüfwerte L1, L2, L9, L10 (Spec 01 Teil A 5.6, R-100)", {
  months <- c(0, rep(12, 30))
  p <- ref_loan_plan(l1_loan(), months)$rows
  expect_abs(-p[2L, "interest"], 47450.00, tab_tol)
  expect_abs(p[2L, "balance"], 1155600.00, tab_tol)
  expect_equal(p[2L, "repayment_grant"], 144400)
  expect_abs(-p[3:6, "interest"], rep(42179.40, 4), tab_tol)
  expect_abs(-p[7L, "interest"], 42179.40, tab_tol)
  expect_abs(-p[7L, "repay"], 37986.26, tab_tol)
  expect_abs(-(p[7L, "interest"] + p[7L, "repay"]), 80165.66, tab_tol)
  expect_abs(p[11L, "balance"], 951288.32, tab_tol)
  expect_abs(-p[12L, "interest"], 38051.53, tab_tol)
  expect_abs(-p[12L, "repay"], 43588.03, tab_tol)
  expect_abs(-(p[12L, "interest"] + p[12L, "repay"]), 81639.56, tab_tol)
  expect_abs(p[12L, "balance"], 907700.29, tab_tol)
  expect_abs(-p[27L, "interest"], 3139.98, tab_tol)
  expect_abs(-p[27L, "repay"], 78499.58, tab_tol)
  expect_abs(p[27L, "balance"], 0, 1e-6)
  expect_identical(sum(p[, "repay"] < -1e-6), 21L)
  expect_identical(which(p[, "repay"] < -1e-6) - 1L, 6:26)
  # n* = 15,833415 aus Rate und Zins vor der Anpassung (R-100)
  b10 <- p[11L, "balance"]
  ann <- -(p[7L, "interest"] + p[7L, "repay"])
  n_star <- -log(1 - b10 * 0.0365 / ann) / log(1.0365)
  expect_abs(n_star, 15.833415, 1e-6)
  p2 <- ref_loan_plan(l1_loan("reduce_installment"), months)$rows
  expect_abs(-(p2[7L, "interest"] + p2[7L, "repay"]), 71261.11, tab_tol)
  expect_abs(p2[11L, "balance"], 999182.07, tab_tol)
  expect_abs(-(p2[12L, "interest"] + p2[12L, "repay"]), 73521.57, tab_tol)
  p9 <- ref_loan_plan(l1_loan(approved = 0), months)$rows
  expect_true(all(p9 == 0))
  p10 <- ref_loan_plan(l1_loan(cut = 0.5), months)$rows
  expect_equal(p10[2L, "repayment_grant"], 72200)
  expect_abs(p10[2L, "balance"], 1227800.00, tab_tol)
})

test_that("Referenz-Engine: Prüfwerte L3 bis L8, L11 (Spec 01 Teil A 5.6)", {
  # L3: monatliche Bauphase C = 6, H = 3; Teilauszahlungen, Bereitstellungsprovision
  g3 <- vofi_time_grid(as.Date("2027-01-01"), 3L, construction_months = 6L,
                       construction_step_months = 1L)
  expect_identical(g3$months, as.integer(c(0, 1, 1, 1, 1, 1, 1, 6, 12, 12)))
  draws <- rep(0, 10)
  draws[c(2L, 5L, 7L)] <- 100000
  p <- ref_loan_plan(list(id = "l3", repayment = "annuity", commitment = 300000, rate_pa = 0.02,
                          ppy = 12L, term_months = 120, grace_months = 12, draws = draws,
                          t_first_draw = 1L, m_A = 6, fee_rate = 0.0015, fee_free_until = 2),
                     g3$months)$rows
  z <- c(NA, NA, -166.67, -166.67, -166.67, -333.33, -333.33, -3000.00, -5936.42, -5410.71)
  fe <- c(NA, NA, 0, -300, -300, -150, -150, 0, 0, 0)
  expect_abs(p[3:10, "interest"], z[3:10], tab_tol)
  expect_abs(p[3:10, "fees"], fe[3:10], 1e-9)
  expect_abs(p[9:10, "repay"], c(-15289.07, -31040.27), tab_tol)
  expect_abs(p[9:10, "balance"], c(284710.93, 253670.66), tab_tol)
  expect_abs(-sum(p[, "interest"]), 15513.80, tab_tol)
  expect_abs(-sum(p[, "fees"]), 900, 1e-9)
  st <- ref_loan_schedules(list(ref_loan_init(list(id = "l3", repayment = "annuity",
                                                   commitment = 300000, rate_pa = 0.02,
                                                   ppy = 12L, term_months = 120,
                                                   grace_months = 12, draws = draws,
                                                   t_first_draw = 1L, m_A = 6), 1L,
                                              cumsum(g3$months))), cumsum(g3$months))[[1L]]
  expect_abs(st$state$inst, 3037.58, tab_tol)
  # L4: endfällig, quartalsweise, Disagio 3 %, Bearbeitungsgebühr 1 %
  p <- ref_loan_plan(list(id = "l4", repayment = "bullet", commitment = 100000, rate_pa = 0.05,
                          ppy = 4L, term_months = 60, payout = 0.97,
                          processing_fee_share = 0.01), c(0, rep(12, 6)))$rows
  expect_abs(p[1L, c("draw", "fees", "disagio", "balance")], c(97000, -1000, 3000, 100000),
             1e-9)
  expect_abs(p[2:6, "interest"], rep(-5000, 5), 1e-9)
  expect_abs(p[6L, "repay_balloon"], -100000, 1e-9)
  expect_equal(p[6L, "balance"], 0)
  # L5: geplante Sondertilgung mit Obergrenze 5 % p. a.
  planned <- c(0, 0, 10000, 0, 0, 0, 0)
  p <- ref_loan_plan(list(id = "l5", repayment = "annuity", commitment = 100000, rate_pa = 0.03,
                          tau = 0.02, ppy = 12L, planned = planned, cap_share = 0.05),
                     c(0, rep(12, 6)))$rows
  expect_abs(p[2L, c("interest", "repay", "balance")], c(-2972.27, -2027.73, 97972.27), tab_tol)
  expect_abs(p[3L, c("interest", "repay", "prepay", "balance")],
             c(-2910.59, -2089.41, -5000, 90882.86), tab_tol)
  expect_abs(p[4L, c("interest", "repay", "balance")], c(-2694.96, -2305.04, 88577.83), tab_tol)
  # L6: Bestandsdarlehen mit vertraglicher Rate, Anschluss 4,5 %, keep_payment
  p <- ref_loan_plan(list(id = "l6", repayment = "annuity", commitment = 400000, rate_pa = 0.025,
                          ppy = 12L, existing = TRUE, installment_eur = 2000, fixed_months = 36,
                          followup = 0.045, refi_rule = "keep_payment"), c(0, rep(12, 6)))$rows
  expect_abs(p[1L, c("draw", "assumed", "balance")], c(0, 400000, 400000), 0)
  expect_abs(p[2L, c("interest", "repay", "balance")], c(-9838.46, -14161.54, 385838.46), tab_tol)
  expect_abs(p[4L, "balance"], 356431.97, tab_tol)
  expect_abs(p[5L, c("interest", "repay")], c(-15873.18, -8126.82), tab_tol)
  expect_abs(p[6L, "balance"], 339804.99, tab_tol)
  # L7: keep_tilg_rate nach Zinsbindung
  pl <- ref_loan_plan(list(id = "l7", repayment = "annuity", commitment = 200000,
                           rate_pa = 0.035, tau = 0.02, ppy = 1L, fixed_months = 60,
                           followup = 0.05, refi_rule = "keep_tilg_rate"), c(0, rep(12, 8)))
  p <- pl$rows
  expect_abs(p[2L, c("interest", "repay")], c(-7000, -4000), 1e-9)
  expect_abs(p[6L, "balance"], 178550.14, tab_tol)
  expect_abs(-(p[7L, "interest"] + p[7L, "repay"]), 12498.51, tab_tol)
  expect_abs(p[7L, c("interest", "repay")], c(-8927.51, -3571.00), tab_tol)
  # L8: Ratentilgung mit Tilgungszuschuss reduce_installment
  p <- ref_loan_plan(list(id = "l8", repayment = "installment", commitment = 120000,
                          rate_pa = 0.02, ppy = 1L, term_months = 120,
                          tz = list(type = "amount", value = 12000, t = 2L,
                                    effect = "reduce_installment")), c(0, rep(12, 10)))$rows
  expect_abs(p[2L, c("interest", "repay")], c(-2400, -12000), 1e-9)
  expect_abs(p[3L, c("repay", "repayment_grant", "balance")], c(-12000, 12000, 84000), 1e-9)
  expect_abs(p[4L, c("interest", "repay")], c(-1680, -10500), 1e-9)
  # L11: Annuität mit anfänglicher Tilgung und Laufzeit (Schlusstilgung, R-100)
  p <- ref_loan_plan(list(id = "l11", repayment = "annuity", commitment = 100000, rate_pa = 0.03,
                          tau = 0.02, ppy = 12L, term_months = 120), c(0, rep(12, 10)))$rows
  expect_abs(p[2L, c("interest", "repay", "balance")], c(-2972.27, -2027.73, 97972.27), tab_tol)
  expect_abs(p[11L, c("interest", "repay", "repay_balloon", "balance")],
             c(-2344.64, -2655.36, -76709.76, 0), tab_tol)
})

test_that("Referenz-Engine: Rundung, Restzahlen, Zinsanpassung ohne Rate", {
  p <- ref_loan_plan(list(id = "r", repayment = "annuity", commitment = 100000, rate_pa = 0.036,
                          ppy = 12L, term_months = 240, round = TRUE), c(0, rep(12, 3)))
  expect_identical(p$state$inst, 585.11)
  pa <- list(m_rep = 12, pi = 3L, m_mat = 48)
  expect_identical(ref_loan_n_rem(pa, 12), 12L)
  expect_identical(ref_loan_n_rem(pa, 47), 1L)
  expect_identical(ref_loan_n_rem(pa, 48), 0L)
  expect_identical(ref_loan_n_rem(list(m_rep = 0, pi = 1L, m_mat = Inf), 5), Inf)
  # Anpassung in der tilgungsfreien Zeit ändert nur den Zins (8.6 R-45)
  p <- ref_loan_plan(list(id = "g", repayment = "annuity", commitment = 50000, rate_pa = 0.02,
                          ppy = 1L, term_months = 120, grace_months = 36, fixed_months = 12,
                          followup = c(0, 0.03, 0.03, 0.03, 0.03, 0.03)), c(0, rep(12, 5)))
  expect_abs(-p$rows[2L, "interest"], 1000, 1e-9)
  expect_abs(-p$rows[3L, "interest"], 1500, 1e-9)
  expect_equal(p$state$inst, 50000 * 0.03 / (1 - 1.03^-7), tolerance = 1e-12)
  expect_error(ref_loan_refi(list(par = list(repayment = "annuity", refi_rule = "x", tz = NULL,
                                             ppy = 1L, round = FALSE),
                                  B = 1, i_pa = 0.01, inst = 1), 0.01, 2, 1),
               "refi_rule")
})

# ---------------------------------------------------------------------------------------------
# 3. Paket gegen die Orakel
# ---------------------------------------------------------------------------------------------

test_that("Paket reproduziert die Zeilen aller Orakel (Spec 00 15.3, Toleranz 1e-6)", {
  for (id in setdiff(oracle_ids(), oracle_variant_ids())) {
    res <- oracle_result(id)
    expect_oracle(res, id, kpis = FALSE)
    expect_vofi_invariants(res)
    expect_ref_invariants(res, attr(res, "model"))
  }
  for (v in c("base", "a")) {
    res <- oracle_result("g", variant = v)
    expect_oracle(res, "g", variant = v, kpis = FALSE)
    expect_vofi_invariants(res)
  }
})

test_that("Paket reproduziert die Kennzahlen aller Orakel (registrierte Kennzahlen)", {
  missing <- character(0)
  for (id in setdiff(oracle_ids(), oracle_variant_ids())) {
    res <- oracle_result(id)
    unchecked <- expect_oracle(res, id)
    regd <- vapply(unchecked, oracle_kpi_registered, logical(1))
    expect_false(any(regd), info = paste(id, utl_collapse(unchecked[regd])))
    missing <- union(missing, unchecked[!regd])
  }
  for (v in c("base", "a")) {
    unchecked <- expect_oracle(oracle_result("g", variant = v), "g", variant = v)
    regd <- vapply(unchecked, oracle_kpi_registered, logical(1))
    expect_false(any(regd & !grepl("vs_reference|better_than_ref", unchecked)))
    missing <- union(missing, unchecked[!regd])
  }
  # Kennzahlen, deren Typ noch nicht registriert ist (Lieferung WS-D2), sind nicht geprüft
  if (length(missing) > 0L) {
    skip(paste("Kennzahlen noch nicht registriert:", utl_collapse(sort(missing))))
  }
})

test_that("Orakel (g): Vergleichsregel über vofi_compare() (Spec 00 9.6 Nr. 4, R-66)", {
  skip_if_stub("vofi_compare")
  sc <- oracle_scenario("g")
  ks <- sc$analysis$kpis[vapply(sc$analysis$kpis, oracle_kpi_registered, logical(1))]
  sc$analysis$kpis <- ks
  cmp <- withCallingHandlers(vofi_compare(sc, variants = "a", baseline = "base"),
                             vofi_message = function(m) invokeRestart("muffleMessage"))
  expect_s3_class(cmp, "vofi_comparison")
  ex <- oracle_expected("g")
  dvr <- cmp$differences$delta_vs_reference
  expect_abs(as.numeric(dvr[1L, "a"]), oracle_kpi_value(ex, "delta_vs_reference", "a"),
             vofi_tol$oracle_abs)
  if (!is.null(cmp$differences$delta_vs_reference_ex_rv)) {
    expect_abs(as.numeric(cmp$differences$delta_vs_reference_ex_rv[1L, "a"]),
               oracle_kpi_value(ex, "delta_vs_reference_ex_rv", "a"), 1e-6)
  }
  # Vergleichbarkeitsbericht ohne Fehler trotz ungleicher Nachschüsse (9.6 Nr. 2)
  comp <- cmp$comparability
  expect_false(any(comp$severity == "error"))
  for (v in c("base", "a")) expect_oracle(cmp$results[[v]], "g", variant = v)
})

test_that("grob_lehrbuch_a.yaml entspricht Spec 01 Teil C 5.6 und Orakel (a)", {
  path <- system.file("extdata", "examples", "grob_lehrbuch_a.yaml", package = "vofi")
  expect_true(nzchar(path))
  raw <- yaml::read_yaml(path)
  expect_identical(raw$meta$scenario_id, "grob_lehrbuch_a")
  expect_identical(raw$meta$author, "WS-T (Orakel (a))")
  expect_identical(raw$shared$rw, 40000L)
  expect_identical(raw$components$rw$values[[6L]], list(ref = "shared.rw"))
  expect_identical(raw$residual_value$method, "zero")
  expect_identical(raw$stochastic$parameters$rw,
                   list(target = "shared.rw", label = "Restwert", dist = "triangular",
                        min = 30000L, mode = 40000L, max = 50000L))
  expect_identical(raw$stochastic$settings,
                   list(n_sim = 10000L, seed = 20261025L, sampling = "lhs", block_size = 200L))
  expect_identical(raw$analysis$kpis,
                   c("terminal_value", "terminal_value_opp", "delta_terminal_value",
                     "roe_classic", "roe_mirr", "roe_irr", "payback_time", "min_net_liquidity",
                     "max_overdraft", "withdrawal_equivalent", "npv_cf_project",
                     "irr_cf_project"))
  skip_if_stub("vofi_example")
  expect_true("grob_lehrbuch_a" %in% vofi_example())
})

test_that("grob_lehrbuch_a: deterministischer Lauf = Orakel (a)", {
  sc <- vofi_read_scenario(system.file("extdata", "examples", "grob_lehrbuch_a.yaml",
                                       package = "vofi"))
  res <- oracle_result("a", scenario = sc)
  # Zeilen wie Orakel (a); die Restwertkomponente heißt hier rw statt rv
  expect_oracle(res, "a", kpis = FALSE)
  unchecked <- expect_oracle(res, "a")
  wanted <- sub("_ex_rv$", "", unchecked) %in% sc$analysis$kpis
  expect_false(any(vapply(unchecked, oracle_kpi_registered, logical(1)) & wanted))
  expect_abs(res$kpis$terminal_value_ex_rv, 38504.629207797145 - 40000, 1e-6)
  expect_ref_equal(res, attr(res, "model"))
})

test_that("grob_lehrbuch_a: Zielwertsuche (Spec 01 Teil C 5.6)", {
  skip_if_stub("vofi_solve")
  sc <- vofi_read_scenario(system.file("extdata", "examples", "grob_lehrbuch_a.yaml",
                                       package = "vofi"))
  sol <- withCallingHandlers(vofi_solve(sc, what = "breakeven", param = "shared.rw", target = 0),
                             vofi_message = function(m) invokeRestart("muffleMessage"))
  expect_s3_class(sol, "vofi_solution")
  expect_abs(sol$value, 40000 - 3726.406978797153, 1e-4)
  expect_abs(sol$prob_exceed, 1 - 6273.593021202847^2 / (20000 * 10000), 1e-6)
  sol2 <- withCallingHandlers(vofi_solve(sc, what = "critical_value", param = "shared.rw",
                                         kpi = "roe_mirr", target = 0.06),
                              vofi_message = function(m) invokeRestart("muffleMessage"))
  expect_abs(sol2$value, 40000 + (30000 * 1.06^5 - 38504.629207797145), 1e-4)
})

test_that("grob_lehrbuch_a: MC-Erwartungen geschlossen (Spec 01 Teil C 5.6)", {
  sc <- vofi_read_scenario(system.file("extdata", "examples", "grob_lehrbuch_a.yaml",
                                       package = "vofi"))
  ks <- sc$analysis$kpis[vapply(sc$analysis$kpis, oracle_kpi_registered, logical(1))]
  ks <- setdiff(ks, "withdrawal_equivalent")
  model <- withCallingHandlers(vofi_build(sc, overrides = list(analysis = list(kpis = ks))),
                               vofi_message = function(m) invokeRestart("muffleMessage"))
  mc <- tryCatch(vofi_run(model, n_sim = 10000L, seed = 20261025L, store = "kpi"),
                 vofi_error_not_implemented = function(e) {
                   skip(paste("Monte-Carlo noch nicht implementiert:", conditionMessage(e)))
                 })
  x <- mc$kpis$terminal_value
  se <- stats::sd(x) / sqrt(length(x))
  expect_lt(abs(mean(x) - 38504.629207797145), 4 * se)
  expect_lt(abs(stats::sd(x) - 10000 / sqrt(6)), 0.05 * 10000 / sqrt(6))
  d <- mc$kpis$delta_terminal_value
  p0 <- 6273.593021202847^2 / (20000 * 10000)
  expect_lt(abs(mean(d < 0) - p0), 4 * sqrt(p0 * (1 - p0) / length(d)))
  if (!is.null(mc$kpis$terminal_value_ex_rv)) {
    expect_abs(mc$kpis$terminal_value_ex_rv, rep(38504.629207797145 - 40000, length(x)), 1e-6)
  }
})

# ---------------------------------------------------------------------------------------------
# 4. Differenztests Referenz-Engine gegen Paket
# ---------------------------------------------------------------------------------------------

#' Szenario bauen und deterministisch rechnen; registrierte Kennzahlen; Hinweise abgefangen
diff_run <- function(raw, kpis = NULL) {
  ks <- kpis %||% c(ref_kpi_rv, ref_kpi_plain)
  ks <- ks[vapply(ks, function(k) reg_has("kpi", k), logical(1))]
  raw$analysis$kpis <- ks
  withCallingHandlers({
    model <- vofi_build(vofi_scenario(raw))
    res <- vofi_run(model)
  }, vofi_warning_plausibility = function(w) invokeRestart("muffleWarning"),
  vofi_warning_engine = function(w) invokeRestart("muffleWarning"),
  vofi_message = function(m) invokeRestart("muffleMessage"))
  list(model = model, res = res)
}

#' Differenztest über eine Liste von Zufallsszenarien (Spec 00 15.6: 1e-8 relativ)
run_diff_tests <- function(scs, kpis = NULL) {
  not_impl <- 0L
  for (k in seq_along(scs)) {
    r <- tryCatch(diff_run(scs[[k]], kpis), vofi_error_not_implemented = function(e) NULL)
    if (is.null(r)) {
      not_impl <- not_impl + 1L
      next
    }
    expect_ref_equal(r$res, r$model, info = scs[[k]]$meta$scenario_id)
    expect_ref_invariants(r$res, r$model)
  }
  not_impl
}

test_that("Differenztest: Referenz-Engine = Paket auf 40 Zufallsszenarien (alle Merkmale)", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_run")
  scs <- ref_scenario_generator(20261026L, 40L, "full")
  ni <- run_diff_tests(scs, kpis = setdiff(c(ref_kpi_rv, ref_kpi_plain), "withdrawal_equivalent"))
  if (ni > 0L) skip(paste(ni, "Szenarien nutzen noch nicht implementierte Funktionen"))
})

test_that("Differenztest: 200 Zufallsszenarien (Spec 00 15.6)", {
  skip_on_cran()
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_run")
  scs <- ref_scenario_generator(20261027L, 200L, "full")
  ni <- run_diff_tests(scs, kpis = setdiff(c(ref_kpi_rv, ref_kpi_plain), "withdrawal_equivalent"))
  if (ni > 0L) skip(paste(ni, "Szenarien nutzen noch nicht implementierte Funktionen"))
})

test_that("Differenztest: Entnahme-Äquivalent auf Zufallsszenarien (12.8)", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_run")
  if (!reg_has("kpi", "withdrawal_equivalent")) {
    skip("Kennzahl withdrawal_equivalent noch nicht registriert (WS-D2)")
  }
  scs <- ref_scenario_generator(20261028L, 15L, "simple")
  ni <- run_diff_tests(scs, kpis = c("terminal_value", "terminal_value_opp",
                                     "delta_terminal_value", "withdrawal_equivalent"))
  if (ni > 0L) skip(paste(ni, "Szenarien nutzen noch nicht implementierte Funktionen"))
})

test_that("Differenztest MC: jeder Lauf eines Batches = Referenz-Engine (statische Ziehungen)", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_run")
  raw <- list(
    schema_version = 1L, meta = list(scenario_id = "mc_diff", title = "MC-Differenztest"),
    project = list(perspective = "wu_privat", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 6L),
    components = list(
      z = list(type = "custom_series", values = c(-150000, 9000, 12000, -4000, 15000, 15000,
                                                  15000)),
      rw = list(type = "custom_series", category = "residual_value",
                values = c(as.list(rep(0, 6)), list(list(ref = "shared.rw"))))
    ),
    shared = list(rw = 50000),
    financing = list(
      ek = list(type = "equity", amount_eur = 50000),
      bank = list(type = "annuity_loan", amount_eur = 80000, rate_pa = 0.035, term_years = 8,
                  payments_per_year = 1L)
    ),
    accounts = list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08,
                    overdraft_limit_eur = 10000, penalty_spread_pa = 0.02,
                    min_liquidity_eur = 0, surplus_order = c("od_repay", "dep_invest"),
                    deficit_order = c("dep_withdraw", "od_draw", "penalty_rate")),
    tax = list(module = "none"), residual_value = list(method = "zero"),
    stochastic = list(
      settings = list(n_sim = 7L, seed = 11L, sampling = "lhs", block_size = 7L),
      parameters = list(
        rw = list(target = "shared.rw", label = "Restwert", dist = "triangular", min = 20000,
                  mode = 50000, max = 90000),
        zins = list(target = "financing.bank.rate_pa", label = "Kreditzins",
                    dist = "uniform", min = 0.02, max = 0.05),
        haben = list(target = "accounts.deposit_rate_pa", label = "Habenzins",
                     dist = "uniform", min = 0, max = 0.03)
      )
    )
  )
  r <- tryCatch(diff_run(raw, kpis = c("terminal_value", "terminal_value_opp",
                                       "delta_terminal_value")),
                vofi_error_not_implemented = function(e) skip(conditionMessage(e)))
  mc <- tryCatch(vofi_run(r$model, n_sim = 7L, seed = 11L, store = "full"),
                 vofi_error_not_implemented = function(e) {
                   skip(paste("Monte-Carlo noch nicht implementiert:", conditionMessage(e)))
                 })
  expect_s3_class(mc, "vofi_mc_result")
  expect_identical(as.integer(mc$ledger$n), 7L)
  s <- spec_simple_from_model(r$model, mc)
  ref <- ref_engine_run(s)
  d <- ref_compare_result(ref, mc, flags = FALSE)
  expect_identical(nrow(d), 0L)
  expect_gt(stats::sd(ref$kpis$terminal_value), 0)
  # Batch gegen Einzelläufe der Referenz-Engine mit den Ziehungen von Lauf i
  for (i in c(1L, 4L, 7L)) {
    single <- ref_engine_run(ref_spec_subset(s, i))
    expect_equal(single$kpis$terminal_value, ref$kpis$terminal_value[i], tolerance = 1e-12)
  }
  skip_if_stub("vofi_sim")
  for (i in c(1L, 7L)) {
    one <- vofi_sim(mc, i)
    for (k in names(one$ledger$values)) {
      expect_equal(one$ledger$values[[k]][1L, ], mc$ledger$values[[k]][i, ], tolerance = 1e-12,
                   info = k)
    }
  }
})

test_that("Vergleichsfunktion meldet Abweichungen und fehlende Zeilen", {
  r <- oracle_result("a")
  ref <- ref_engine_run(spec_simple_from_model(attr(r, "model")))
  expect_identical(nrow(ref_compare_result(ref, r)), 0L)
  bad <- r
  bad$ledger$values$loan_ann_interest[1L, 3L] <- bad$ledger$values$loan_ann_interest[1L, 3L] + 1
  d <- ref_compare_result(ref, bad)
  expect_identical(d$what, "row")
  expect_identical(d$key, "loan_ann_interest")
  expect_identical(d$t, 2L)
  bad2 <- r
  bad2$ledger$values$dep_balance <- NULL
  expect_identical(ref_compare_result(ref, bad2)$what, "row_missing")
  bad3 <- r
  bad3$opportunity$BS[1L, 6L] <- 0
  expect_identical(ref_compare_result(ref, bad3)$what, "opp_BS")
  bad4 <- r
  bad4$kpis$terminal_value <- 1
  expect_identical(ref_compare_result(ref, bad4)$key, "terminal_value")
  bad5 <- r
  bad5$flags$limit_cut <- TRUE
  expect_identical(ref_compare_result(ref, bad5)$what, "flag")
  expect_failure(expect_ref_equal(bad, attr(r, "model")))
})

test_that("spec_simple_from_model: unterstützte und nicht unterstützte Modelle", {
  r <- oracle_result("e")
  s <- spec_simple_from_model(attr(r, "model"))
  expect_identical(s$n, 1L)
  expect_identical(s$months, c(0, 3, 3, 3, 3, 12, 12, 12))
  bau <- s$loans$bau
  expect_identical(bau$draws, c(1e5, 1e5, 1e5, 1e5, 0, 0, 0, 0))
  expect_identical(c(bau$t_first_draw, bau$m_A, bau$grace_months), c(0, 9, 3))
  expect_identical(bau$fee_free_until, 3)
  expect_identical(bau$refi_rule, "keep_tilg_rate")
  expect_true(is.infinite(bau$term_months))
  expect_error(spec_simple_from_model(list()), "vofi_model")
  m <- attr(r, "model")
  m2 <- m
  m2$topup_id <- "bau"
  expect_error(spec_simple_from_model(m2), "topup")
  b1 <- spec_simple_from_model(attr(oracle_result("b1"), "model"))
  expect_identical(b1$loans$foe$tz$t, 1L)
  expect_identical(b1$loans$foe$tz$type, "amount")
  expect_identical(b1$analysis$dscr_threshold, 1.2)
  grid2 <- vofi_time_grid(as.Date("2027-01-01"), 2L)
  env <- list(spec = list(market = list(x = node_const(0.02))), grid = grid2, n = 2L,
              static = list(), paths = list())
  expect_equal(ref_node_eval(node_ref("market.x", scale = 2, offset = 0.01), "p", env),
               c(0.05, 0.05))
  sy <- list(kind = "series_year", years = c(2027L, 2029L), values = c(1, 3), fill = "linear",
             before = "first")
  expect_identical(ref_node_eval(sy, NULL, env), matrix(c(1, 1, 2), 2L, 3L, byrow = TRUE))
  expect_error(ref_node_eval(list(kind = "expr", text = "1"), NULL, env), "nicht unterstuetzt")
  anc <- node_ref("market.p")
  anc$anchor <- 0.01
  env$spec$market$p <- list(kind = "series_t", values = c(0.03, 0.04, 0.05))
  expect_equal(ref_node_eval(anc, NULL, env), matrix(c(0.01, 0.02, 0.03), 2L, 3L, byrow = TRUE))
})
