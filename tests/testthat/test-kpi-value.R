# Tests für R/kpi-value.R (WS-D2; Spec 00 Abschnitte 12.2, 12.3, 12.6, 15.3; Memo 01 §10).

test_that("Orakel (a): Endwert, Unterlassung, Endwertdifferenz, Amortisation, Kapitalwert", {
  o <- oracle_a_values()$kpi
  r <- d2_run(d2_oracle_a())
  tol <- vofi_tol$oracle_abs
  expect_equal(r$kpis$terminal_value, o$terminal_value, tolerance = tol / o$terminal_value)
  expect_equal(r$kpis$terminal_value_opp, o$terminal_value_opp,
               tolerance = tol / o$terminal_value_opp)
  expect_equal(r$kpis$delta_terminal_value, o$delta_terminal_value,
               tolerance = tol / o$delta_terminal_value)
  expect_equal(r$kpis$terminal_value_ex_rv, o$terminal_value - 40000, tolerance = 1e-9)
  expect_equal(r$kpis$delta_terminal_value_ex_rv,
               o$terminal_value - 40000 - o$terminal_value_opp, tolerance = 1e-9)
  expect_identical(r$kpis$payback_time, 5)
  expect_identical(r$kpis$payback_year, 2031)
  expect_true(is.na(r$kpis$payback_time_ex_rv))
  expect_identical(r$kpi_na$payback_time_ex_rv, "no_payback")
  expect_identical(r$kpi_na$payback_year_ex_rv, "no_payback")
  expect_equal(r$kpis$npv_cf_project, o$npv_cf_project, tolerance = tol / o$npv_cf_project)
  expect_equal(r$kpis$npv_cf_project, 10195.96, tolerance = 0.005 / 10195.96)
  expect_true(is.na(r$kpis$terminal_value_real))
  expect_identical(r$kpi_na$terminal_value_real, "no_inflation_path")
  expect_equal(r$kpis$pv_subsidies, 0)
  # Struktur wie die Fixture example_result() (Tabellenwerte von Orakel (a))
  # (die Fixture führt withdrawal_equivalent_ex_rv als nicht berechnet)
  fx <- example_result()
  for (k in setdiff(intersect(names(fx$kpis), names(r$kpis)), "withdrawal_equivalent_ex_rv")) {
    expect_equal(r$kpis[[k]], fx$kpis[[k]], tolerance = 1e-8, info = k)
    expect_identical(r$kpi_na[[k]], fx$kpi_na[[k]], info = k)
  }
})

test_that("Orakel (d), I4: Endwertdifferenz = KW(5 %) * 1,05^5 bei vollkommenem Kapitalmarkt", {
  r <- d2_run(d2_oracle_a(rate = 0.05))
  expect_equal(r$kpis$terminal_value, 41004.58, tolerance = 0.005 / 41004.58)
  expect_equal(r$kpis$terminal_value_opp, 38288.45, tolerance = 0.005 / 38288.45)
  expect_equal(r$kpis$delta_terminal_value, 2716.13, tolerance = 0.005 / 2716.13)
  expect_equal(r$kpis$npv_cf_project, 2128.16, tolerance = 0.005 / 2128.16)
  expect_equal(r$kpis$delta_terminal_value, r$kpis$npv_cf_project * 1.05^5, tolerance = 1e-10)
})

test_that("Orakel (b1), (c1), (e) und Prüffall Sacheinlage: Endwerte und Amortisation", {
  b1 <- d2_run(d2_oracle_b("shorten_term"))
  expect_equal(b1$kpis$terminal_value, 70432.51, tolerance = 0.005 / 70432.51)
  expect_equal(b1$kpis$terminal_value_opp, 60949.72, tolerance = 0.005 / 60949.72)
  expect_equal(b1$kpis$delta_terminal_value, 9482.79, tolerance = 0.005 / 9482.79)
  expect_identical(b1$kpis$payback_time, 10)
  expect_identical(b1$kpi_na$payback_time_ex_rv, "no_payback")
  expect_equal(b1$kpis$npv_cf_project, -13524.20, tolerance = 0.005 / 13524.20)
  expect_equal(b1$kpis$pv_subsidies, 22500 / 1.02, tolerance = 1e-10)
  c1 <- d2_run(d2_oracle_c())
  expect_equal(c1$kpis$terminal_value, 34957.28, tolerance = 0.005 / 34957.28)
  expect_equal(c1$kpis$terminal_value_opp, 0)
  expect_identical(c1$kpis$payback_year, 2036)
  e <- d2_run(d2_oracle_e())
  expect_equal(e$kpis$terminal_value, 156540.56, tolerance = 0.005 / 156540.56)
  expect_equal(e$kpis$terminal_value_opp, 110381.29, tolerance = 0.005 / 110381.29)
  expect_equal(e$kpis$delta_terminal_value, 46159.27, tolerance = 0.005 / 46159.27)
  expect_identical(e$kpis$payback_time, 4)
  ik <- d2_run(d2_oracle_in_kind())
  expect_equal(ik$kpis$terminal_value, 318700, tolerance = 1e-10)
  expect_equal(ik$kpis$terminal_value_opp, 290700, tolerance = 1e-10)
  expect_equal(ik$kpis$delta_terminal_value, 28000, tolerance = 1e-9)
})

test_that("Orakel (a3): Sondertilgung aus Überschüssen (Ü3), Endwert, Amortisation", {
  r <- d2_run(d2_oracle_a3())
  # Sollwerte aus docs/recherche/prototypen/vofi_referenz/vofi_ref.py (Tabellenwerte 15.3)
  expect_equal(r$kpis$terminal_value, 39139.9686922067, tolerance = 1e-6 / 39139.97)
  expect_equal(r$kpis$terminal_value, 39139.97, tolerance = 0.005 / 39139.97)
  expect_equal(r$kpis$terminal_value_opp, 34778.22, tolerance = 0.005 / 34778.22)
  expect_equal(r$kpis$delta_terminal_value, 4361.7464632067, tolerance = 1e-6 / 4361.75)
  expect_equal(r$kpis$delta_terminal_value, 4361.75, tolerance = 0.005 / 4361.75)
  expect_equal(r$kpis$terminal_value_ex_rv, 39139.9686922067 - 40000, tolerance = 1e-9)
  expect_identical(r$kpis$payback_time, 5)
  expect_identical(r$kpi_na$payback_time_ex_rv, "no_payback")
  v <- r$ledger$values
  expect_equal(-v$loan_ann_prepay[1, 4], 11863.72, tolerance = 0.005 / 11863.72)
  expect_equal(v$dep_balance[1, 6], 39139.97, tolerance = 0.005 / 39139.97)
  # Zahlungsfolge unverändert gegenüber (a)
  expect_equal(r$kpis$npv_cf_project, 10195.96, tolerance = 0.005 / 10195.96)
})

test_that("Orakel (b2), (c2), (g): Endwerte, Unterlassung und Endwertdifferenz (15.3)", {
  tol <- 0.005
  b2 <- d2_run(d2_oracle_b("reduce_installment"))
  expect_equal(b2$kpis$terminal_value, 71353.38, tolerance = tol / 71353.38)
  expect_equal(b2$kpis$terminal_value_opp, 60949.72, tolerance = tol / 60949.72)
  expect_equal(b2$kpis$delta_terminal_value, 10403.66, tolerance = tol / 10403.66)
  c2 <- d2_run(d2_oracle_c(limit = 0))
  expect_equal(c2$kpis$terminal_value, 99392.07, tolerance = tol / 99392.07)
  expect_equal(c2$kpis$terminal_value_opp, 45263.66, tolerance = tol / 45263.66)
  expect_equal(c2$kpis$delta_terminal_value, 54128.41, tolerance = tol / 54128.41)
  ga <- d2_run(d2_oracle_g("a"))
  expect_equal(ga$kpis$terminal_value, 16000, tolerance = tol / 16000)
  expect_equal(ga$kpis$terminal_value_opp, 13464, tolerance = tol / 13464)
  expect_equal(ga$kpis$delta_terminal_value, 2536, tolerance = tol / 2536)
  gb <- d2_run(d2_oracle_g("base"))
  expect_equal(gb$kpis$terminal_value, 13020, tolerance = tol / 13020)
  expect_equal(gb$kpis$terminal_value_opp, 10404, tolerance = tol / 10404)
  expect_equal(gb$kpis$delta_terminal_value, 2616, tolerance = tol / 2616)
  expect_equal(gb$kpis$sum_equity_calls, 0)
  # Vergleichsregel: (2.536 - 2.616) = (EW_A - EW_B) - 3.000 * 1,02
  expect_equal(ga$kpis$delta_terminal_value - gb$kpis$delta_terminal_value,
               (16000 - 13020) - 3000 * 1.02, tolerance = 1e-9)
})

d2_payback_core <- function(path = c(90000, 80000, 70000, 60000), rv = 60000) {
  g <- vofi_time_grid(as.Date("2027-01-01"), 3L)
  rows <- list(inv__cost = d2_row("project", "capex", c(-100000, 0, 0, 0), "b1", "m1"),
               rent__value = d2_row("project", "rent", c(0, 20000, 20000, 20000)),
               rv__value = d2_row("project", "residual_value", c(0, 0, 0, rv), "b1"),
               ek__in = d2_row("equity", "equity_in", c(100000, 0, 0, 0)))
  if (!is.null(path)) {
    rows$rv__path_method <- d2_row("memo", "residual_path", path, "b1",
                                   extra = list(rv_basis = "method"))
  }
  d2_core(g, rows, h = 0, s = 0.06)
}

test_that("Vermögensamortisation mit Restwertpfad, ohne Restwert und dauerhaft (R-72)", {
  core <- d2_payback_core()
  ctx <- d2_ctx(core)
  expect_equal(core$opp$BS[1, ], rep(100000, 4))
  expect_identical(d2_kpi("payback_time", core, ctx)$values, 1)
  expect_identical(d2_kpi("payback_year", core, ctx)$values, 2027)
  ex <- core_ex_rv(core)
  expect_identical(d2_kpi("payback_time", ex, ctx)$na_reason, "no_payback")
  nopath <- d2_payback_core(path = NULL)
  expect_identical(d2_kpi("payback_time", nopath, ctx)$values, 3)
  expect_identical(d2_kpi("payback_year", nopath, ctx)$values, 2029)
  # Scheinamortisation in t = 1 zählt nicht, weil d_2 < 0 ist
  temp <- d2_payback_core(path = c(90000, 85000, 20000, 0))
  expect_identical(d2_kpi("payback_time", temp, ctx)$values, 3)
  # Basis measures im Haushaltsmodus: keine Zeilen dieser Basis -> wie ohne Pfad
  su <- d2_ctx(core, perspective = "selbstnutzer")
  expect_identical(d2_kpi("payback_time", core, su)$values, 3)
  # Toleranz: d_t = -1e-10 gilt als amortisiert
  core0 <- d2_payback_core(path = c(100000 - 1e-10, 80000, 70000, 60000))
  expect_identical(d2_kpi("payback_time", core0, ctx)$values, 0)
})

test_that("payback_vs_reference: gemeinsame Periodenenden bei abweichendem Raster (9.6 Nr. 9)", {
  ga <- vofi_time_grid(as.Date("2027-01-01"), 6L)
  gr <- vofi_time_grid(as.Date("2027-01-01"), 6L, construction_months = 9L,
                       construction_step_months = 1L)
  d <- c(-5, -3, -1, 2, 3, 4, 5)
  w_a <- matrix(d + 100, 1L)
  bsu_a <- matrix(100, 1L, 7L)
  w_r <- matrix(50, 1L, gr$T + 1L)
  pb <- kpi_payback_vs_reference(w_a, bsu_a, w_r, w_r, ga, gr)
  expect_identical(pb$time$values, 3)
  expect_identical(pb$year$values, 2029)
  never <- kpi_payback_vs_reference(w_a - 10, bsu_a, w_r, w_r, ga, gr)
  expect_identical(never$time$na_reason, "no_payback")
  # Rückgabepfade wie eng_run_chunk(return_paths = ...)
  var <- list(kpis = data.frame(terminal_value_ex_rv = 99), kpi_na = data.frame(x = NA),
              paths = list(wealth = w_a, net_position = w_a, opp_net_position = bsu_a), grid = ga)
  ref <- list(kpis = data.frame(terminal_value_ex_rv = 50), kpi_na = data.frame(x = NA),
              paths = list(wealth = w_r, net_position = w_r, opp_net_position = w_r), grid = gr)
  expect_identical(kpi_payback_vs_reference_from(var, ref)$time$values, 3)
  ex <- kpi_payback_vs_reference_from(var, ref, ex_rv = TRUE)
  expect_identical(ex$time$na_reason, "no_payback")
  cmp <- kpi_compare_values(var, ref)
  expect_identical(cmp$kpis$payback_vs_reference, 3)
  expect_identical(cmp$kpis$payback_year_vs_reference, 2029)
})

test_that("Realer Endwert: Deflation mit market.inflation (Pfad), ohne Inflationspfad NA", {
  core <- example_core(2L)
  ctx <- d2_ctx(core)
  v <- d2_kpi("terminal_value_real", core, ctx)
  expect_equal(v$values, core$stocks$BS[, 7] / 1.02^6)
  infl <- c(0, 0.01, 0.02, 0.03, 0.02, 0.01, 0)
  mk <- reg_test_market_raw()
  mk$inflation <- infl
  spec <- reg_test_spec(core$grid, market = mk)
  v2 <- d2_kpi("terminal_value_real", core, d2_ctx(core, spec = spec))
  expect_equal(v2$values, core$stocks$BS[, 7] / prod(1 + infl[-1]))
  spec0 <- reg_test_spec(core$grid, market = list(rent_growth = 0.01))
  v0 <- d2_kpi("terminal_value_real", core, d2_ctx(core, spec = spec0))
  expect_identical(v0$na_reason, rep("no_inflation_path", 2L))
  specb <- reg_test_spec(core$grid, market = list(inflation = -1.5))
  expect_error(d2_kpi("terminal_value_real", core, d2_ctx(core, spec = specb)), NA)
  vb <- d2_kpi("terminal_value_real", core, d2_ctx(core, spec = specb))
  expect_identical(vb$na_reason, rep("no_inflation_path", 2L))
  ex <- d2_kpi("terminal_value_real", core_ex_rv(core), ctx)
  expect_equal(ex$values, core$terminal_ex_rv$BS / 1.02^6)
})

test_that("Förderbarwert: Zuschüsse, laufende Zuschüsse, Steuerermäßigung, Tilgungszuschuss", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 3L)
  rows <- list(grant__value = d2_row("grants", "grant", c(0, 10000, 0, 0), measure = "m1"),
               sub__value = d2_row("grants", "operating_subsidy", c(0, 1000, 1000, 1000)),
               tc__value = d2_row("grants", "tax_credit", c(0, 0, 500, 0), measure = "m1"),
               ek__in = d2_row("equity", "equity_in", c(50000, 0, 0, 0)))
  loans <- list(kfw = d2_loan(draw = c(20000, 0, 0, 0), repayment_grant = c(0, 2000, 0, 0),
                              repay = c(0, -18000, 0, 0), balance = c(20000, 0, 0, 0)))
  core <- d2_core(g, rows, loans, h = 0.02)
  v <- d2_kpi("pv_subsidies", core, d2_ctx(core))
  expect_equal(v$values, (10000 + 1000 + 2000) / 1.02 + 1500 / 1.02^2 + 1000 / 1.02^3)
  npv <- d2_kpi("npv_cf_project", core, d2_ctx(core))
  expect_equal(npv$values, 11000 / 1.02 + 1500 / 1.02^2 + 1000 / 1.02^3)
})
