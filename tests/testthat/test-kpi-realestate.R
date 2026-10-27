# Tests für R/kpi-realestate.R (WS-D2; Spec 00 Abschnitte 12.2, 12.3, 12.6, 15.3; Memo 01 §10).

test_that("Orakel (b1), (b2), (c1): DSCR je Jahr, Minimum, Mittel, Jahre unter Schwelle", {
  b1 <- d2_run(d2_oracle_b("shorten_term"))
  p <- d2_result_core(b1)
  y <- kpi_dscr_years(p$core, p$ctx)
  r <- kpi_masked_ratio(y$noi, y$kd)
  expect_equal(round(r$ratio[1, 1:9], 2), c(4.67, 5.60, 0.68, 0.71, 0.74, 0.77, 0.80, 0.83, 1.07))
  expect_true(is.na(r$ratio[1, 10]))
  expect_equal(b1$kpis$dscr_min, 14000 * 1.02^2 / (18750 + 2550), tolerance = 1e-12)
  expect_equal(b1$kpis$dscr_mean, mean(r$ratio[1, 1:9]), tolerance = 1e-12)
  expect_identical(b1$kpis$dscr_years_below, 7)
  expect_equal(b1$kpis$dscr_min_new, b1$kpis$dscr_min)
  expect_equal(b1$kpis$icr_min, min(y$noi[1, 1:9] / y$int[1, 1:9]), tolerance = 1e-12)
  b2 <- d2_run(d2_oracle_b("reduce_installment"))
  p2 <- d2_result_core(b2)
  y2 <- kpi_dscr_years(p2$core, p2$ctx)
  expect_equal(round(y2$noi[1, ] / y2$kd[1, ], 2),
               c(4.67, 5.60, 0.79, 0.82, 0.85, 0.88, 0.92, 0.95, 0.99, 1.03))
  expect_equal(round(b2$kpis$dscr_min, 2), 0.79)
  c1 <- d2_run(d2_oracle_c())
  p3 <- d2_result_core(c1)
  y3 <- kpi_dscr_years(p3$core, p3$ctx)
  expect_equal(round(y3$noi[1, ] / y3$kd[1, ], 2),
               c(0.69, 0.70, 0.72, 0.73, 0.75, 0.76, 0.78, 0.79, 0.81, 0.82))
  expect_equal(c1$kpis$dscr_min, 12000 / 17400, tolerance = 1e-12)
  expect_equal(c1$kpis$icr_min, 12000 / 11400, tolerance = 1e-12)
  expect_identical(c1$kpis$dscr_years_below, 10)
})

test_that("Stabilisierungsjahr (R-77): explizit und Default erstes volles Betriebsjahr", {
  sc <- d2_oracle_b("shorten_term")
  sc$analysis$stabilization_year <- 2030L
  r <- d2_run(sc)
  expect_equal(r$kpis$dscr_min, 14000 * 1.02^3 / (18750 + 2175), tolerance = 1e-12)
  expect_identical(r$kpis$dscr_years_below, 6)
  # Raster mit Bauphase: Bau- und Stub-Perioden zählen nicht
  g <- vofi_time_grid(as.Date("2027-01-01"), 6L, construction_months = 9L,
                      construction_step_months = 1L)
  nt <- g$T + 1L
  op <- as.double(g$phase == "operation")
  rows <- list(rent__value = d2_row("project", "rent", 1000 * op * g$months),
               ek__in = d2_row("equity", "equity_in", c(50000, rep(0, nt - 1L))))
  int <- -200 * g$months
  int[1] <- 0
  loans <- list(bank = d2_loan(draw = c(100000, rep(0, nt - 1L)), interest = int,
                               balance = rep(100000, nt)))
  core <- d2_core(g, rows, loans)
  ctx <- d2_ctx(core)
  y <- kpi_dscr_years(core, ctx)
  expect_identical(ncol(y$noi), 5L)
  expect_equal(d2_kpi("dscr_min", core, ctx)$values, 5)
  expect_equal(d2_kpi("icr_min", core, ctx)$values, 5)
  late <- d2_ctx(core, analysis = list(stabilization_year = 2040L))
  expect_identical(d2_kpi("dscr_min", core, late)$na_reason, "no_debt_service")
})

test_that("DSCR, ICR: Kapitaldienst bis stock_abs zählt nicht (Rundungsrest, Befund B1 WS-S)", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 4L)
  nt <- g$T + 1L
  rows <- list(rent__value = d2_row("project", "rent", c(0, rep(12000, 4))),
               ek__in = d2_row("equity", "equity_in", c(50000, rep(0, nt - 1L))))
  dust <- function(kd) {
    loans <- list(bank = d2_loan(draw = c(100000, rep(0, nt - 1L)),
                                 interest = c(0, -2400, -2400, -kd, 0),
                                 balance = c(rep(100000, 3), 0, 0)))
    core <- d2_core(g, rows, loans)
    ctx <- d2_ctx(core, analysis = list(thresholds = list(dscr = 1.2)))
    vapply(c("dscr_min", "dscr_mean", "dscr_years_below", "dscr_min_new", "icr_min"),
           function(k) d2_kpi(k, core, ctx)$values, double(1))
  }
  # 1e-9 bzw. stock_abs: kein Kapitaldienstjahr (sonst DSCR = NOI / 1e-9)
  for (kd in c(1.09e-9, vofi_tol$stock_abs)) {
    expect_equal(unname(dust(kd)), c(5, 5, 0, 5, 5), info = format(kd))
  }
  # oberhalb von stock_abs zählt das Jahr
  expect_equal(unname(dust(1e-3)[c("dscr_min", "dscr_mean")]), c(5, (5 + 5 + 12000 / 1e-3) / 3))
})

test_that("DSCR Objekt- und Maßnahmenebene, ICR, Schwelle, Restriktion (R-46, R-77)", {
  core <- d2_debt_core()
  ctx <- d2_ctx(core, analysis = list(restrictions = "dscr", thresholds = list(dscr = 1.2)))
  # NOI = 10.000 - 1.000 (other_income ist nicht NOI-relevant);
  # KD = 3.000 + 5.000 (ohne Schlusstilgung)
  expect_equal(d2_kpi("dscr_min", core, ctx)$values, 9000 / 8000)
  expect_equal(d2_kpi("dscr_mean", core, ctx)$values, 9000 / 8000)
  expect_equal(d2_kpi("dscr_min_new", core, ctx)$values, (9000 - 3000) / 5000)
  expect_equal(d2_kpi("icr_min", core, ctx)$values, 9000 / 3000)
  expect_identical(d2_kpi("dscr_years_below", core, ctx)$values, 6)
  expect_identical(d2_kpi("restriction_dscr", core, ctx)$values, 1)
  low <- d2_ctx(core, analysis = list(restrictions = "dscr", thresholds = list(dscr = 1.1)))
  expect_identical(d2_kpi("dscr_years_below", core, low)$values, 0)
  expect_identical(d2_kpi("restriction_dscr", core, low)$values, 0)
  plain <- d2_debt_core(existing = FALSE)
  expect_equal(d2_kpi("dscr_min_new", plain, ctx)$values, d2_kpi("dscr_min", plain, ctx)$values)
  nodebt <- d2_core(vofi_time_grid(as.Date("2027-01-01"), 3L),
                    list(rent__value = d2_row("project", "rent", c(0, 1, 1, 1))))
  for (k in c("dscr_min", "dscr_mean", "dscr_years_below", "dscr_min_new", "icr_min")) {
    expect_identical(d2_kpi(k, nodebt, d2_ctx(nodebt))$na_reason, "no_debt_service", info = k)
  }
  expect_identical(d2_kpi("restriction_dscr", nodebt, ctx)$na_reason, "no_debt_service")
  liq <- d2_ctx(core, analysis = list(restrictions = "liquidity"))
  expect_identical(d2_kpi("restriction_dscr", core, liq)$na_reason, "not_applicable_perspective")
})

test_that("Orakel (c1): LTV je Periode, LTV am Horizont, Beleihungsauslauf", {
  c1 <- d2_run(d2_oracle_c())
  p <- d2_result_core(c1)
  r <- kpi_ltv_path(p$core)
  expect_equal(round(100 * r$ratio[1, ], 2),
               c(107.14, 104.83, 102.58, 100.38, 98.24, 96.16, 94.14, 92.19, 90.31, 88.50, 66.98))
  expect_equal(c1$kpis$ltv_max, 300000 / 280000, tolerance = 1e-12)
  expect_equal(c1$kpis$ltv_end, r$ratio[1, 11], tolerance = 1e-12)
  expect_equal(c1$kpis$lending_ratio_max, 300000 / (280000 * 0.9), tolerance = 1e-12)
  sc <- d2_oracle_c()
  sc$analysis$lending_value_haircut <- 0.2
  expect_equal(d2_run(sc)$kpis$lending_ratio_max, 300000 / (280000 * 0.8), tolerance = 1e-12)
  core <- example_core(2L)
  ctx <- d2_ctx(core)
  v <- d2_kpi("lending_ratio_max", core, ctx)
  b <- kpi_loan_balance(core)
  mv <- core$ledger$values$rv__market_value
  expect_equal(v$values, apply(b / (mv * 0.8), 1, max))
  nomv <- core
  nomv$ledger$values$rv__market_value[] <- 0
  for (k in c("ltv_max", "ltv_end", "lending_ratio_max")) {
    expect_identical(d2_kpi(k, nomv, ctx)$na_reason, rep("no_market_value", 2), info = k)
  }
  last0 <- core
  last0$ledger$values$rv__market_value[, 7] <- 0
  expect_identical(d2_kpi("ltv_end", last0, ctx)$na_reason, rep("no_market_value", 2))
  expect_false(anyNA(d2_kpi("ltv_max", last0, ctx)$values))
})

d2_tenant_core <- function(g = vofi_time_grid(as.Date("2027-01-01"), 3L), pre = 7000,
                           tenant = TRUE) {
  op <- as.double(g$t >= 1) * g$months / 12
  rows <- list(rent__value = d2_row("project", "rent", 12000 * op),
               rent__levy_m1 = d2_row("project", "modernization_levy", 1200 * op,
                                      measure = "m1"),
               ek__in = d2_row("equity", "equity_in", c(1000, rep(0, g$T))))
  if (tenant) {
    rows$tenant__energy <- d2_row("memo", "tenant_energy_cost", 6000 * op)
    rows$tenant__operating <- d2_row("memo", "tenant_operating_cost", 2400 * op)
  }
  if (!is.null(pre)) rows$tenant__energy_pre <- d2_row("memo", "tenant_energy_cost_pre", pre * op)
  d2_core(g, rows)
}

test_that("Warmmiete je vermietetem m² und vorher/nachher (12.3, R-83, R-101)", {
  core <- d2_tenant_core()
  spec <- reg_test_spec(core$grid, analysis = list(restrictions = "warm_rent"))
  spec$unit_groups <- list(a = list(living_area_m2 = 400, owner_occupied = FALSE),
                           b = list(living_area_m2 = 100, owner_occupied = TRUE),
                           c = list(living_area_m2 = 50, rent_regime = "owner_occupied"))
  ctx <- d2_ctx(core, spec = spec)
  expect_equal(kpi_rented_area(ctx, 1L), 400)
  wr <- d2_kpi("warm_rent", core, ctx)
  expect_identical(wr$years, 2027:2029)
  expect_equal(wr$values[1, ], rep((12000 + 1200 + 6000 + 2400) / (400 * 12), 3))
  expect_equal(d2_kpi("warm_rent_y1", core, ctx)$values, 21600 / 4800)
  pp <- d2_kpi("warm_rent_change_prepost", core, ctx)
  expect_equal(pp$values[1, ], rep((1200 + 6000 - 7000) / 4800, 3))
  expect_equal(d2_kpi("warm_rent_change_prepost_y1", core, ctx)$values, 200 / 4800)
  expect_identical(d2_kpi("restriction_warm_rent", core, ctx)$values, 0)
  hot <- d2_tenant_core(pre = 3000)
  expect_equal(d2_kpi("warm_rent_change_prepost_y1", hot, ctx)$values, 4200 / 4800)
  expect_identical(d2_kpi("restriction_warm_rent", hot, ctx)$values, 1)
  # ohne Wohnungsgruppen: building.living_area_m2
  bctx <- d2_ctx(core)
  expect_equal(d2_kpi("warm_rent_y1", core, bctx)$values, 21600 / (900 * 12))
  # ohne Vorzustand (Neubau, TC-2) bzw. ohne Mieterdaten
  nopre <- d2_tenant_core(pre = NULL)
  expect_identical(d2_kpi("warm_rent_change_prepost_y1", nopre, ctx)$na_reason, "no_tenant_data")
  expect_identical(d2_kpi("restriction_warm_rent", nopre, ctx)$na_reason, "no_tenant_data")
  expect_false(is.na(d2_kpi("warm_rent_y1", nopre, ctx)$values))
  empty <- d2_core(core$grid, list(z__value = d2_row("project", "custom", c(-1, 1, 1, 1))))
  expect_identical(d2_kpi("warm_rent", empty, ctx)$na_reason, "no_tenant_data")
  noarea <- spec
  noarea$unit_groups$a$owner_occupied <- TRUE
  v <- d2_kpi("warm_rent_y1", core, d2_ctx(core, spec = noarea))
  expect_identical(v$na_reason, "no_living_area")
  # Mietersicht aus: nicht anwendbar
  off <- d2_ctx(core, analysis = list(tenant_view = FALSE, restrictions = "warm_rent"))
  for (k in c("warm_rent", "warm_rent_y1", "warm_rent_change_prepost",
              "warm_rent_change_prepost_y1", "restriction_warm_rent")) {
    expect_identical(unique(d2_kpi(k, core, off)$na_reason), "not_applicable_perspective",
                     info = k)
  }
})

test_that("Warmmiete: Stub-Betriebsjahr zählt in der Reihe, _y1 ist das erste volle Jahr", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 6L, construction_months = 9L,
                      construction_step_months = 1L)
  core <- d2_tenant_core(g)
  ctx <- d2_ctx(core)
  wr <- d2_kpi("warm_rent", core, ctx)
  expect_identical(wr$years[1:2], c(2027L, 2028L))
  expect_equal(wr$values[1, 1:2], rep(21600 / (900 * 12), 2))
  expect_equal(d2_kpi("warm_rent_y1", core, ctx)$values, 21600 / (900 * 12))
  noop <- vofi_time_grid(as.Date("2027-01-01"), 1L, periods_months = 12L,
                         construction_months = 12L)
  c0 <- d2_core(noop, list(rent__value = d2_row("project", "rent", c(0, 100))))
  expect_identical(d2_kpi("warm_rent", c0, d2_ctx(c0))$na_reason, "no_operation_period")
  expect_identical(d2_kpi("warm_rent_y1", c0, d2_ctx(c0))$na_reason, "no_operation_period")
})

test_that("CO2-Emissionen (Treibhausgasbilanz, R-101)", {
  core <- example_core(2L)
  expect_equal(d2_kpi("co2_emissions", core, d2_ctx(core))$values, c(72, 72))
  red <- vofi_kpi_value(c(10, NA, -1), na_reason = c(NA, "no_operation_period", NA))
  dvr <- vofi_kpi_value(c(-500, -500, NA), na_reason = c(NA, NA, "run_stopped"))
  ac <- kpi_co2_abatement_cost(dvr, red, c(1.25, 1.25, 1.25))
  expect_equal(ac$values[1], (500 / 1.25) / 10)
  expect_identical(ac$na_reason, c(NA, "no_operation_period", "no_co2_reduction"))
  expect_identical(kpi_co2_abatement_cost(dvr, red, NULL)$na_reason, rep("not_computed", 3))
})
