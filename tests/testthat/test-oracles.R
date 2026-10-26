# Testorakel und Referenz-Engine (WS-T; Spec 00 Abschnitte 8.10, 15.3, 15.6 "Differenztests";
# Spec 01 Teil A 5.6 und Teil C 5.6; Memo 01 §10).
#
# 1. Fixtures: vollständig und konsistent mit den Kernwerten von Spec 00 15.3.
# 2. Referenz-Engine: reproduziert alle Orakel (1e-6 EUR, 1e-9 Raten) und die Prüfwerte der
#    Kredittypen (Spec 01 Teil A 5.6, Toleranz 0,005 gegen gerundete Tabellenwerte); Spalte j*
#    des Anschlusszinses (8.5 (a), R-45).
# 3. Paket gegen Orakel: Zeilen und registrierte Kennzahlen je Orakel; (g) über
#    vofi_compare(); Break-even-NOI_1 von (c1); grob_lehrbuch_a.yaml (Spec 01 Teil C 5.6) mit
#    Zielwertsuche und geschlossenen MC-Erwartungen; Spalte j* im Paket.
# 4. Differenztests: Referenz-Engine gegen Paket auf Zufallsszenarien (1e-8 relativ) mit
#    Mindestabdeckung der Merkmale; Batches mit Ziehungen je Lauf (n = 1, 2, T+1) gegen
#    Referenz und Einzelläufe; MC über vofi_run(n_sim > 1); Entnahme-Äquivalent.

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
  # Zielwertsuche (12.8): Break-even-NOI_1 von (c1)
  expect_true("c1_solve.csv" %in% files)
  sv <- oracle_solve("c1")
  expect_identical(names(sv), c("what", "param", "kpi", "target", "value"))
  expect_identical(nrow(sv), 1L)
  expect_identical(nrow(oracle_solve("a")), 0L)
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
  expect_abs(oracle_solve("c1")$value, 9869.14, tab_tol)
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

#' Darlehen für die Prüfung der Spalte j* (streng monotoner Anschlusszinspfad `fu`)
jstar_loan <- function(fixed_m, fu, repayment = "annuity", ppy = 1L) {
  list(id = "j", repayment = repayment, commitment = 100000, rate_pa = 0.03, ppy = ppy,
       term_months = 240, fixed_months = fixed_m, followup = fu)
}

#' Erwartete Zinsen der Perioden t = 0..T für einen Kredit ohne Tilgung bis zum Horizont
#' (endfällig): Bestand 100.000, Zins vor der Anpassung 3 %, danach fu[j]
jstar_bullet_interest <- function(months, reset_m, j) {
  m_end <- cumsum(months)
  vapply(seq_along(months), function(k) {
    if (k == 1L) return(0)
    m <- seq.int(m_end[k - 1L] + 1, m_end[k])
    sum(ifelse(m <= reset_m, 0.03, j)) * 100000 / 12
  }, double(1))
}

test_that("Referenz-Engine: Spalte j* des Anschlusszinses (8.5 (a), R-45), Verschiebung +-1", {
  fu <- 0.01 + 0.002 * (0:8)
  months <- c(0, rep(12, 8))
  # Anpassung zum Jahreswechsel (Monat 60 endet in t = 5): Zins ab t = 6 ist fu[6], der Wert
  # des Jahres vor dem Termin; fu[5] bzw. fu[7] (Verschiebung -1/+1) liegen 0,002 daneben
  p <- ref_loan_plan(jstar_loan(60, fu), months)$rows
  i6 <- -p[7L, "interest"] / p[6L, "balance"]
  expect_abs(i6, fu[6L], 1e-12)
  expect_gt(min(abs(i6 - fu[c(5L, 7L)])), 1e-3)
  # Anpassung im Jahr (Monat 18 endet in t = 2): sechs Monate alter Zins, sechs Monate fu[3]
  p <- ref_loan_plan(jstar_loan(18, fu), months)$rows
  want <- p[2L, "balance"] * (6 * 0.03 + 6 * fu[3L]) / 12
  expect_abs(-p[3L, "interest"], want, 1e-9)
  expect_gt(abs(want - p[2L, "balance"] * (6 * 0.03 + 6 * fu[4L]) / 12), 50)
  expect_gt(abs(want - p[2L, "balance"] * (6 * 0.03 + 6 * fu[2L]) / 12), 50)
  # Quartalsraster der Bauphase (C = 12, Schritt 3): Anpassung nach 9 Monaten (Ende t = 3),
  # danach nach 7 Monaten (Monat 7 endet in t = 3, Spalte 4); endfällig, Zinsen geschlossen
  g3 <- vofi_time_grid(as.Date("2027-01-01"), 4L, construction_months = 12L,
                       construction_step_months = 3L)
  fu3 <- 0.01 + 0.002 * (seq_len(g3$T + 1L) - 1L)
  for (fm in c(9, 7)) {
    p <- ref_loan_plan(jstar_loan(fm, fu3, "bullet", 4L), g3$months)$rows
    want <- jstar_bullet_interest(g3$months, fm, fu3[4L])
    expect_abs(-p[, "interest"], want, 1e-9)
    expect_gt(max(abs(-p[, "interest"] - jstar_bullet_interest(g3$months, fm, fu3[3L]))), 10)
    expect_gt(max(abs(-p[, "interest"] - jstar_bullet_interest(g3$months, fm, fu3[5L]))), 10)
  }
  # Folgebindungen (followup_fixed_years = 1): jede Anpassung liest ihre eigene Spalte
  ln <- jstar_loan(24, fu, "bullet")
  ln$followup_fixed_months <- 12
  p <- ref_loan_plan(ln, months)$rows
  expect_abs(-p[4:9, "interest"], 100000 * fu[3:8], 1e-9)
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

#' Rohszenario mit einem Kredit `j` und Anschlusszinspfad `fu` (series_t) für die Spalte j*
jstar_scenario <- function(fixed_years, fu, type = "annuity_loan", ppy = 1L, horizon = 8L,
                           grid = NULL, followup_fixed_years = NULL) {
  t1 <- length(fu)
  raw <- list(
    schema_version = 1L, meta = list(scenario_id = "jstar", title = "Spalte j*"),
    project = list(perspective = "wu_privat", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = horizon),
    components = list(z = list(type = "custom_series", values = c(-150000, rep(9000, t1 - 1L)))),
    financing = list(ek = list(type = "equity", amount_eur = 50000),
                     j = list(type = type, amount_eur = 100000, rate_pa = 0.03, term_years = 20,
                              payments_per_year = ppy, fixed_years = fixed_years,
                              followup_rate_pa = fu)),
    accounts = list(deposit_rate_pa = 0.01, overdraft_rate_pa = 0.08, overdraft_limit_eur = Inf,
                    penalty_spread_pa = 0, min_liquidity_eur = 0,
                    surplus_order = c("od_repay", "dep_invest"),
                    deficit_order = c("dep_withdraw", "od_draw", "equity_call")),
    tax = list(module = "none"), residual_value = list(method = "zero"),
    analysis = list(kpis = "terminal_value")
  )
  if (!is.null(grid)) raw$grid <- grid
  if (!is.null(followup_fixed_years)) {
    raw$financing$j$followup_fixed_years <- followup_fixed_years
  }
  raw
}

test_that("Paket: Spalte j* des Anschlusszinses (8.5 (a), R-45) gegen Handwerte und Referenz", {
  fu <- 0.01 + 0.002 * (0:8)
  # Jahresraster, Anpassung nach 5 Jahren: Zins in t = 6 = fu[6] (nicht fu[5] bzw. fu[7])
  res <- inv_run(jstar_scenario(5, fu))
  v <- res$ledger$values
  expect_abs(-v$loan_j_interest[1L, 7L] / v$loan_j_balance[1L, 6L], fu[6L], 1e-12)
  expect_ref_equal(res, attr(res, "model"), info = "j* Jahreswechsel")
  # Anpassung im Jahr (1,5 Jahre): t = 2 je zur Hälfte alter Zins und fu[3]
  res <- inv_run(jstar_scenario(1.5, fu))
  v <- res$ledger$values
  expect_abs(-v$loan_j_interest[1L, 3L], v$loan_j_balance[1L, 2L] * (0.03 + fu[3L]) / 2, 1e-9)
  expect_ref_equal(res, attr(res, "model"), info = "j* im Jahr")
  # Quartalsraster der Bauphase, endfällig, Anpassung nach 9 Monaten -> Spalte 4
  grid <- list(construction_months = 12L, construction_step_months = 3L,
               operation_alignment = "calendar")
  g3 <- vofi_time_grid(as.Date("2027-01-01"), 4L, construction_months = 12L,
                       construction_step_months = 3L)
  fu3 <- 0.01 + 0.002 * (seq_len(g3$T + 1L) - 1L)
  res <- inv_run(jstar_scenario(0.75, fu3, "bullet_loan", 4L, 4L, grid))
  expect_abs(-res$ledger$values$loan_j_interest[1L, ],
             jstar_bullet_interest(g3$months, 9, fu3[4L]), 1e-9)
  expect_ref_equal(res, attr(res, "model"), info = "j* Quartalsraster")
  # Folgebindungen: jede Anpassung liest ihre eigene Spalte
  res <- inv_run(jstar_scenario(2, fu, "bullet_loan", followup_fixed_years = 1))
  expect_abs(-res$ledger$values$loan_j_interest[1L, 4:9], 100000 * fu[3:8], 1e-9)
  expect_ref_equal(res, attr(res, "model"), info = "j* Folgebindungen")
})

test_that("Orakel (c1): Break-even-NOI_1 9.869,14 (Referenz-Engine, Paket, vofi_solve)", {
  sv <- oracle_solve("c1")
  be_py <- sv$value[sv$what == "breakeven" & sv$param == "components.noi.amount_eur"]
  expect_length(be_py, 1L)
  expect_abs(be_py, 9869.14, tab_tol)
  # Referenz-Engine: dEW(NOI_1) mit skalierter NOI-Zeile (recurring ist linear im Betrag;
  # EW_U = 0 ohne Eigenkapital), Nullstelle per uniroot
  res <- oracle_result("c1")
  s <- spec_simple_from_model(attr(res, "model"))
  s$kpis <- c("terminal_value", "delta_terminal_value")
  expect_true("noi__value" %in% names(s$rows))
  noi <- s$rows$noi__value$values
  expect_abs(noi[1L, 2L], 12000, 1e-9)
  d_ew <- function(x) {
    s1 <- s
    s1$rows$noi__value$values <- noi * (x / 12000)
    ref_engine_run(s1)$kpis$delta_terminal_value
  }
  be <- stats::uniroot(d_ew, c(5000, 15000), tol = 1e-10)$root
  expect_abs(be, be_py, 1e-6)
  expect_lt(abs(d_ew(be)), 1e-6)
  # Paket am Break-even: dEW = 0
  sc <- oracle_scenario("c1")
  ks <- c("terminal_value", "terminal_value_opp", "delta_terminal_value")
  model <- ref_quiet(vofi_build(sc, overrides = list(components = list(noi = list(amount_eur = be)),
                                                     analysis = list(kpis = ks))))
  expect_lt(abs(ref_quiet(vofi_run(model))$kpis$delta_terminal_value), 1e-5)
  skip_if_stub("vofi_solve")
  sol <- ref_quiet(vofi_solve(sc, what = "breakeven", param = "components.noi.amount_eur",
                              target = 0))
  expect_s3_class(sol, "vofi_solution")
  expect_abs(sol$value, be_py, 1e-4)
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

#' Geschlossene MC-Sollwerte von grob_lehrbuch_a (Spec 01 Teil C 5.6): dEW = RW - 40.000 +
#' 3.726,41 mit RW ~ Dreieck(30.000; 40.000; 50.000)
grob_mc_expected <- function() {
  c0 <- 3726.406978797153                                     # dEW bei RW = 40.000
  q_tri <- function(p) ref_q_triangular(p, 30000, 40000, 50000)
  x_star <- 40000 - c0                                        # kritischer Restwert
  p0 <- (x_star - 30000)^2 / (20000 * 10000)
  list(c0 = c0, p0 = p0,
       q = c(q05 = q_tri(0.05), q50 = q_tri(0.5), q95 = q_tri(0.95)) - 40000 + c0,
       es05 = 30000 + 2 / 3 * (q_tri(0.05) - 30000) - 40000 + c0,
       expected_loss = (x_star - 30000)^3 / (3 * 20000 * 10000))
}

test_that("grob_lehrbuch_a: MC-Erwartungen geschlossen (Spec 01 Teil C 5.6)", {
  ex <- grob_mc_expected()
  # Die Tabelle leitet Quantile und es05 mit dem gerundeten dEW 3.726,41 her (Abweichung bis
  # 0,0054 EUR), daher Toleranz 0,01 EUR
  expect_abs(ex$q, c(-3111.31, 3726.41, 10564.13), 0.01)
  expect_abs(ex$es05, -4165.40, 0.01)
  expect_abs(ex$expected_loss, 411.53, tab_tol)
  expect_abs(ex$p0, 0.196790, 5e-7)
  sc <- vofi_read_scenario(system.file("extdata", "examples", "grob_lehrbuch_a.yaml",
                                       package = "vofi"))
  ks <- sc$analysis$kpis[vapply(sc$analysis$kpis, oracle_kpi_registered, logical(1))]
  ks <- setdiff(ks, "withdrawal_equivalent")
  model <- ref_quiet(vofi_build(sc, overrides = list(analysis = list(kpis = ks))))
  mc <- tryCatch(vofi_run(model, n_sim = 10000L, seed = 20261025L, store = "kpi"),
                 vofi_error_not_implemented = function(e) {
                   skip(paste("Monte-Carlo noch nicht implementiert:", conditionMessage(e)))
                 })
  x <- mc$kpis$terminal_value
  n <- length(x)
  expect_identical(n, 10000L)
  se <- stats::sd(x) / sqrt(n)
  expect_lt(abs(mean(x) - 38504.629207797145), 4 * se)
  expect_lt(abs(stats::sd(x) - 10000 / sqrt(6)), 0.05 * 10000 / sqrt(6))
  d <- mc$kpis$delta_terminal_value
  # Mittel innerhalb 4 SE (konservativ: LHS-Varianz ist kleiner als sd/sqrt(n))
  expect_lt(abs(mean(d) - ex$c0), 4 * stats::sd(d) / sqrt(n))
  expect_lt(abs(mean(d < 0) - ex$p0), 4 * sqrt(ex$p0 * (1 - ex$p0) / n))
  # Quantile innerhalb ihrer verteilungsfreien 99,9-%-Konfidenzintervalle (Ordnungsstatistiken)
  ds <- sort(d)
  for (k in names(ex$q)) {
    p <- c(q05 = 0.05, q50 = 0.5, q95 = 0.95)[[k]]
    lo <- max(1L, stats::qbinom(0.0005, n, p))
    hi <- min(n, stats::qbinom(0.9995, n, p) + 1L)
    expect_true(ds[lo] <= ex$q[[k]] && ex$q[[k]] <= ds[hi], info = k)
  }
  # es05 (Mittel der Werte <= q05) und expected_loss (Mittel von max(-dEW, 0)) innerhalb 4 SE
  q05 <- stats::quantile(d, 0.05, type = 7, names = FALSE)
  tail5 <- d[d <= q05]
  expect_lt(abs(mean(tail5) - ex$es05),
            4 * stats::sd(tail5) / sqrt(length(tail5)) + abs(q05 - ex$q[["q05"]]))
  el <- pmax(-d, 0)
  expect_lt(abs(mean(el) - ex$expected_loss), 4 * stats::sd(el) / sqrt(n))
  # na_share von payback_time: Amortisation in t = 5 genau bei dEW >= 0, sonst no_payback
  if ("payback_time" %in% names(mc$kpis)) {
    na <- is.na(mc$kpis$payback_time)
    expect_lt(abs(mean(na) - ex$p0), 4 * sqrt(ex$p0 * (1 - ex$p0) / n))
    expect_identical(na, d < 0)
    expect_true(all(mc$kpi_na$payback_time[na] == "no_payback"))
    expect_true(all(mc$kpis$payback_time[!na] == 5))
  }
  if (!is.null(mc$kpis$terminal_value_ex_rv)) {
    expect_abs(mc$kpis$terminal_value_ex_rv, rep(38504.629207797145 - 40000, length(x)), 1e-6)
  }
  # Statistik mc$stats (12.7): Definitionen aus den Läufen und geschlossene Sollwerte
  st <- mc$stats
  expect_false(is.null(st))
  sd_row <- st[st$kpi == "delta_terminal_value", , drop = FALSE]
  expect_identical(nrow(sd_row), 1L)
  expect_abs(sd_row$mean, mean(d), 1e-9 * max(1, abs(mean(d))))
  expect_abs(c(sd_row$q05, sd_row$q50, sd_row$q95),
             stats::quantile(d, c(0.05, 0.5, 0.95), type = 7, names = FALSE), 1e-6)
  expect_abs(sd_row$p_neg, mean(d < 0), 1e-12)
  expect_abs(sd_row$es05, mean(tail5), 1e-6)
  expect_abs(sd_row$expected_loss, mean(el), 1e-6)
  expect_abs(sd_row$na_share, 0, 0)
  expect_identical(as.integer(sd_row$n_valid), n)
  expect_lt(abs(sd_row$mean - ex$c0), 4 * stats::sd(d) / sqrt(n))
  expect_lt(abs(sd_row$es05 - ex$es05),
            4 * stats::sd(tail5) / sqrt(length(tail5)) + abs(q05 - ex$q[["q05"]]))
  expect_lt(abs(sd_row$expected_loss - ex$expected_loss), 4 * stats::sd(el) / sqrt(n))
  if ("payback_time" %in% st$kpi) {
    expect_lt(abs(st$na_share[st$kpi == "payback_time"] - ex$p0),
              4 * sqrt(ex$p0 * (1 - ex$p0) / n))
  }
})

# ---------------------------------------------------------------------------------------------
# 4. Differenztests Referenz-Engine gegen Paket
# ---------------------------------------------------------------------------------------------

#' Szenario bauen und deterministisch rechnen; registrierte Kennzahlen; Hinweise abgefangen
diff_run <- function(raw, kpis = NULL) {
  res <- inv_run(raw, kpis = kpis %||% c(ref_kpi_rv, ref_kpi_plain))
  list(model = attr(res, "model"), res = res)
}

#' Kennzahlen der Differenztests (ohne das teure Entnahme-Äquivalent, eigener Test)
diff_kpis <- setdiff(c(ref_kpi_rv, ref_kpi_plain), "withdrawal_equivalent")

#' Differenztest über eine Liste von Zufallsszenarien (Spec 00 15.6: 1e-8 relativ)
#'
#' @return list(not_impl = Anzahl, deferred = Szenario-ids mit Vergleich ohne R-100,
#'   counts = Anzahl der Szenarien je Merkmal (`ref_features()`, aus der Referenz-Engine)).
run_diff_tests <- function(scs, kpis = NULL) {
  not_impl <- 0L
  deferred <- character(0)
  feats <- NULL
  for (raw in scs) {
    id <- raw$meta$scenario_id
    r <- tryCatch(diff_run(raw, kpis), vofi_error_not_implemented = function(e) NULL)
    if (is.null(r)) {
      not_impl <- not_impl + 1L
      next
    }
    chk <- expect_ref_equal(r$res, r$model, info = id)
    expect_ref_invariants(r$res, r$model, info = id)
    if (chk$deferred) deferred <- c(deferred, id)
    feats <- rbind(feats, chk$features)
  }
  list(not_impl = not_impl, deferred = deferred,
       counts = if (is.null(feats)) integer(0) else colSums(feats))
}

#' Mindestabdeckung je Merkmal (F2): gezielte Merkmale jedes dritten Szenarios und zufällige
#' Merkmale des Modus "full"
expect_feature_counts <- function(counts, min_targeted, min_random) {
  for (f in ref_gen_features) {
    expect_gte(counts[[f]], min_targeted, label = paste("Szenarien mit", f))
  }
  for (f in c("rate_path", "kl_path", "prepay", "shortfall", "penalty")) {
    expect_gte(counts[[f]], min_random, label = paste("Szenarien mit", f))
  }
}

#' Abschluss eines Differenztests: Skip mit Begründung für nicht implementierte Funktionen
#' bzw. Läufe, die nur ohne R-100 verglichen werden konnten (Paketfassung ohne R-100, WS-F)
diff_finish <- function(out) {
  if (out$not_impl > 0L) {
    skip(paste(out$not_impl, "Szenarien nutzen noch nicht implementierte Funktionen"))
  }
  if (length(out$deferred) > 0L) {
    skip(paste0(length(out$deferred), " Szenarien hängen von R-100 ab (Spec 00 8.6) und sind ",
                "nur ohne effektive Restzahl verglichen: die Paketfassung verfehlt den Prüfwert ",
                "L1 (Spec 01 Teil A 5.6; Kreditkern WS-F): ", utl_collapse(out$deferred)))
  }
}

test_that("Differenztest: Referenz-Engine = Paket auf 40 Zufallsszenarien (alle Merkmale)", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_run")
  scs <- ref_scenario_generator(20261026L, 40L, "full")
  out <- run_diff_tests(scs, kpis = diff_kpis)
  expect_feature_counts(out$counts, 2L, 1L)
  diff_finish(out)
})

test_that("Differenztest: 200 Zufallsszenarien (Spec 00 15.6)", {
  skip_on_cran()
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_run")
  scs <- ref_scenario_generator(20261027L, 200L, "full")
  out <- run_diff_tests(scs, kpis = diff_kpis)
  expect_feature_counts(out$counts, 10L, 5L)
  diff_finish(out)
})

test_that("Differenztest: Entnahme-Äquivalent auf Zufallsszenarien (12.8)", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_run")
  scs <- ref_scenario_generator(20261028L, 15L, "simple")
  # Referenz-Engine gegen die Paket-Engine ohne die Kennzahl des Pakets: Zusatzentnahme E* als
  # Baustein equity (inv_f_pkg()) ergibt f(E*) = 0 (12.8, mit und ohne Restwert)
  n_ok <- 0L
  for (raw in scs) {
    id <- raw$meta$scenario_id
    base <- inv_run(raw)
    s <- spec_simple_from_model(attr(base, "model"))
    s$kpis <- c("terminal_value", "delta_terminal_value", "withdrawal_equivalent")
    ref <- ref_engine_run(s)
    vol <- max(1, unlist(lapply(base$ledger$values, abs)))
    for (ex in c(FALSE, TRUE)) {
      k <- if (ex) "withdrawal_equivalent_ex_rv" else "withdrawal_equivalent"
      we <- ref$kpis[[k]]
      if (is.na(we)) {
        expect_true(ref$kpi_na[[k]] %in% c("no_solution", "run_stopped"), info = paste(id, k))
        next
      }
      n_ok <- n_ok + 1L
      expect_lt(abs(inv_f_pkg(raw, we, base, ex_rv = ex)), 1e-8 * vol, label = paste(id, k))
    }
  }
  expect_gt(n_ok, 20L)
  # Paketkennzahl (WS-D2): Der Kennzahltyp ist kein exportierter Stub und meldet nicht
  # vofi_error_not_implemented; geprüft wird, sobald er registriert ist (Abstimmungspunkt)
  if (!reg_has("kpi", "withdrawal_equivalent")) {
    skip("Kennzahl withdrawal_equivalent noch nicht registriert (WS-D2); Referenzteil geprüft")
  }
  out <- run_diff_tests(scs, kpis = c("terminal_value", "terminal_value_opp",
                                      "delta_terminal_value", "withdrawal_equivalent"))
  diff_finish(out)
})

#' Lauf i eines Paket-Batches = Paket-Einzellauf mit den Ziehungen von Lauf i (2.8 Nr. 8)
expect_batch_row <- function(batch, single, i, info) {
  keys <- union(names(batch$ledger$values), names(single$ledger$values))
  bad <- character(0)
  same <- function(a, b) length(a) == length(b) && all(abs(a - b) <= 1e-12 * pmax(1, abs(a)))
  for (k in keys) {
    a <- batch$ledger$values[[k]]
    b <- single$ledger$values[[k]]
    if (is.null(a) || is.null(b) || !same(a[i, ], b[1L, ])) bad <- c(bad, k)
  }
  if (!same(batch$opportunity$BS[i, ], single$opportunity$BS[1L, ])) bad <- c(bad, "opp_BS")
  for (k in intersect(names(batch$kpis), names(single$kpis))) {
    a <- batch$kpis[[k]][i]
    b <- single$kpis[[k]][1L]
    if (!identical(is.na(a), is.na(b)) || (!is.na(a) && !same(a, b))) bad <- c(bad, k)
  }
  testthat::expect(length(bad) == 0L,
                   paste0("Batch-Lauf ", i, " != Einzellauf (", info, "): ", utl_collapse(bad)))
}

#' Batches mit Ziehungen je Lauf (n = 1, 2, T+1) gegen Referenz-Engine und Einzelläufe
run_batch_tests <- function(scs, seed) {
  deferred <- character(0)
  feats <- NULL
  n_batch <- 0L
  for (k in seq_along(scs)) {
    raw <- scs[[k]]
    id <- raw$meta$scenario_id
    raw$analysis$kpis <- diff_kpis[vapply(diff_kpis, function(x) reg_has("kpi", x), logical(1))]
    model <- ref_quiet(vofi_build(vofi_scenario(raw)))
    g <- model$grid
    for (n in unique(c(1L, 2L, g$T + 1L))) {
      dr <- ref_gen_draws(raw, g, n, ref_gen_subseed(seed, 100L * k + n))
      draws <- fake_draws(n, g, static = dr$static, paths = dr$paths)
      batch <- ref_pkg_run_draws(model, draws)
      info <- sprintf("%s, n = %d", id, n)
      expect_identical(as.integer(batch$ledger$n), n)
      chk <- expect_ref_equal(batch, model, info = info)
      expect_ref_invariants(batch, model, info = info)
      if (chk$deferred) deferred <- union(deferred, id)
      feats <- rbind(feats, chk$features)
      n_batch <- n_batch + 1L
      if (n == 1L) next
      for (i in unique(c(1L, 2L, n))) {
        single <- ref_pkg_run_draws(model, reg_draws_subset(draws, i))
        expect_batch_row(batch, single, i, info)
        ref_i <- ref_engine_run(ref_spec_subset(chk$s, i))
        for (key in names(ref_i$rows)) {
          expect_identical(chk$ref$rows[[key]][i, , drop = FALSE], ref_i$rows[[key]],
                           info = paste(info, key))
        }
      }
    }
  }
  list(deferred = deferred, n_batch = n_batch,
       counts = if (is.null(feats)) integer(0) else colSums(feats))
}

test_that("Differenztest Batch: n = 1, 2, T+1 mit Ziehungen je Lauf (2.8 Nr. 8, 15.6)", {
  skip_if_stub("vofi_scenario", "vofi_build")
  scs <- ref_scenario_generator(20261029L, 18L, "full", stochastic = TRUE)
  expect_true(all(vapply(scs, function(x) length(x$stochastic$parameters) > 0L, logical(1))))
  out <- run_batch_tests(scs, 20261029L)
  expect_gte(out$n_batch, 2L * length(scs))
  for (f in ref_gen_features) expect_gte(out$counts[[f]], 1L, label = f)
  if (length(out$deferred) > 0L) diff_finish(list(not_impl = 0L, deferred = out$deferred))
})

test_that("Differenztest Batch: 36 weitere Zufallsszenarien mit Ziehungen je Lauf", {
  skip_on_cran()
  skip_if_stub("vofi_scenario", "vofi_build")
  scs <- ref_scenario_generator(20261030L, 36L, "full", stochastic = TRUE)
  out <- run_batch_tests(scs, 20261030L)
  for (f in ref_gen_features) expect_gte(out$counts[[f]], 2L, label = f)
  if (length(out$deferred) > 0L) diff_finish(list(not_impl = 0L, deferred = out$deferred))
})

test_that("Differenztest MC über vofi_run(n_sim > 1): Zufallsszenarien mit stochastic-Block", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_run")
  scs <- ref_scenario_generator(20261031L, 6L, "full", stochastic = TRUE)
  deferred <- character(0)
  for (raw in scs) {
    id <- raw$meta$scenario_id
    raw$analysis$kpis <- c("terminal_value", "terminal_value_opp", "delta_terminal_value")
    model <- ref_quiet(vofi_build(vofi_scenario(raw)))
    mc <- tryCatch(ref_quiet(vofi_run(model, n_sim = 7L, seed = 11L, store = "full")),
                   vofi_error_not_implemented = function(e) {
                     skip(paste("Monte-Carlo noch nicht implementiert:", conditionMessage(e)))
                   })
    expect_s3_class(mc, "vofi_mc_result")
    expect_identical(as.integer(mc$ledger$n), 7L)
    chk <- expect_ref_equal(mc, model, info = id)
    expect_ref_invariants(mc, model, info = id)
    if (chk$deferred) deferred <- c(deferred, id)
  }
  if (length(deferred) > 0L) diff_finish(list(not_impl = 0L, deferred = deferred))
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
