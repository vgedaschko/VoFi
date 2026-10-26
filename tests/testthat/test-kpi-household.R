# Tests für R/kpi-household.R (WS-D2; Spec 00 Abschnitte 12.2, 12.3; Spec 01 Teil B 3.10.4).

d2_household_core <- function(g = vofi_time_grid(as.Date("2027-01-01"), 12L), n = 1L) {
  nt <- g$T + 1L
  t <- g$t
  op <- as.double(t >= 1)
  y <- pmax(t - 1, 0)
  rows <- list(energy__cost = d2_row("project", "energy_cost", -2400 * (1 + 0.1 * y) * op),
               maint__value = d2_row("project", "maintenance", -600 * op),
               pv__feed_in = d2_row("project", "energy_income", 600 * op),
               rent__value = d2_row("project", "imputed_rent", 9000 * op),
               inv__cost = d2_row("project", "capex", c(-200000, rep(0, nt - 1L)), "b1", "m1"),
               ek__in = d2_row("equity", "equity_in", c(100000, rep(0, nt - 1L))))
  loans <- list(bank = d2_loan(draw = c(100000, rep(0, nt - 1L)), interest = -3000 * op,
                               repay = -2000 * op, balance = 100000 - 2000 * t))
  d2_core(g, rows, loans, n = n)
}

test_that("Monatliche Belastung (Selbstnutzer): Reihe, erstes volles Jahr, Mittel 10 Jahre", {
  core <- d2_household_core()
  ctx <- d2_ctx(core, perspective = "selbstnutzer")
  yearly <- 2400 * (1 + 0.1 * (0:11)) + 600 - 600 + 3000 + 2000
  mb <- d2_kpi("monthly_burden", core, ctx)
  expect_identical(mb$years, 2027:2038)
  expect_equal(mb$values[1, ], yearly / 12)
  expect_equal(d2_kpi("monthly_burden_y1", core, ctx)$values, yearly[1] / 12)
  expect_equal(d2_kpi("monthly_burden_avg10", core, ctx)$values, mean(yearly[1:10]) / 12)
  expect_identical(d2_kpi("monthly_burden_construction", core, ctx)$na_reason,
                   "no_construction_period")
  wu <- d2_ctx(core)
  for (k in c("monthly_burden", "monthly_burden_y1", "monthly_burden_avg10",
              "monthly_burden_construction", "burden_ratio_max")) {
    expect_identical(unique(d2_kpi(k, core, wu)$na_reason), "not_applicable_perspective",
                     info = k)
  }
  short <- d2_household_core(vofi_time_grid(as.Date("2027-01-01"), 3L))
  expect_equal(d2_kpi("monthly_burden_avg10", short, ctx)$values, mean(yearly[1:3]) / 12)
})

test_that("Belastung in der Bauphase inkl. bisheriger Miete und Bauzeitzinsen (Persona e)", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 4L, construction_months = 12L,
                      construction_step_months = 3L)
  nt <- g$T + 1L
  int <- -c(0, 900, 1800, 2700, 3600, rep(14400, nt - 5L))
  fees <- c(0, 0, -1500, -750, rep(0, nt - 4L))
  inv <- c(-200000, -100000, -100000, -100000, rep(0, nt - 4L))
  rows <- list(inv__cost = d2_row("project", "capex", inv, "b1", "m1"),
               ek__in = d2_row("equity", "equity_in", c(100000, rep(0, nt - 1L))))
  loans <- list(bau = d2_loan(draw = c(100000, 100000, 100000, 100000, rep(0, nt - 4L)),
                              interest = int, fees = fees,
                              balance = c(1e5, 2e5, 3e5, 4e5, rep(4e5, nt - 4L))))
  core <- d2_core(g, rows, loans)
  ctx <- d2_ctx(core, perspective = "selbstnutzer")
  expect_equal(d2_kpi("monthly_burden_construction", core, ctx)$values,
               (900 + 1800 + 2700 + 3600 + 1500 + 750 + 900 * 12) / 12)
  spec <- reg_test_spec(g, perspective = "selbstnutzer")
  spec$household$current_rent_month_eur <- NULL
  expect_equal(d2_kpi("monthly_burden_construction", core, d2_ctx(core, spec = spec))$values,
               (900 + 1800 + 2700 + 3600 + 1500 + 750) / 12)
})

test_that("Belastungsquote mit Einkommensindex, ohne Einkommen NA, Restriktion", {
  core <- d2_household_core()
  yearly <- 2400 * (1 + 0.1 * (0:11)) + 5000
  ctx <- d2_ctx(core, perspective = "selbstnutzer",
                household = list(net_income_month_eur = 3000, income_growth = 0),
                analysis = list(restrictions = "burden"))
  expect_equal(d2_kpi("burden_ratio_max", core, ctx)$values, max(yearly / 12) / 3000)
  grow <- d2_ctx(core, perspective = "selbstnutzer",
                 household = list(net_income_month_eur = 3000, income_growth = 0.05),
                 analysis = list(restrictions = "burden"))
  inc <- 3000 * 1.05^(0:11)
  expect_equal(d2_kpi("burden_ratio_max", core, grow)$values, max(yearly / 12 / inc))
  # Default-Schwelle 0,40 des Prüfkits: Belastungsquote ca. 0,27 bzw. 0,22
  expect_identical(d2_kpi("restriction_burden", core, ctx)$values, 0)
  tight <- d2_ctx(core, perspective = "selbstnutzer",
                  household = list(net_income_month_eur = 3000, income_growth = 0),
                  analysis = list(restrictions = "burden", thresholds = list(burden_share = 0.2)))
  expect_identical(d2_kpi("restriction_burden", core, tight)$values, 1)
  spec <- reg_test_spec(core$grid, perspective = "selbstnutzer",
                        analysis = list(restrictions = "burden"))
  spec$household$net_income_month_eur <- NULL
  noinc <- d2_ctx(core, spec = spec)
  expect_identical(d2_kpi("burden_ratio_max", core, noinc)$na_reason, "no_household_income")
  expect_identical(d2_kpi("restriction_burden", core, noinc)$na_reason, "no_household_income")
  zero <- d2_ctx(core, perspective = "selbstnutzer",
                 household = list(net_income_month_eur = 0))
  expect_identical(d2_kpi("burden_ratio_max", core, zero)$na_reason, "no_household_income")
  wu <- d2_ctx(core, analysis = list(restrictions = "burden"))
  expect_identical(d2_kpi("restriction_burden", core, wu)$na_reason, "not_applicable_perspective")
  expect_identical(kpi_calc_burden_ratio_max(core, wu)$na_reason, "not_applicable_perspective")
})

test_that("Orakel (e) als Selbstnutzer: Bauphase, Belastung, Quote, Eigenanteil (Engine)", {
  hh <- list(net_income_month_eur = 5000, income_growth = 0.02, current_rent_month_eur = 1000,
             savings_capacity_month_eur = 500)
  sc <- d2_oracle_e(perspective = "selbstnutzer", household = hh)
  sc$components$z$category <- "capex"
  sc$components$z$asset_id <- "b1"
  sc$components$z$measure_id <- "m1"
  sc$components$z$values <- c(-200000, -100000, -100000, -100000, 0, 0, 0, 0)
  sc$analysis$restrictions <- c("burden", "savings")
  r <- d2_run(sc)
  expect_equal(r$kpis$monthly_burden_construction,
               (900 + 1800 + 1500 + 2700 + 750 + 3600 + 12 * 1000) / 12, tolerance = 1e-10)
  expect_equal(r$kpis$monthly_burden_y1, 22400 / 12, tolerance = 1e-10)
  expect_equal(r$kpis$monthly_burden_avg10, 22400 / 12, tolerance = 1e-10)
  expect_identical(r$kpi_series$monthly_burden$years, 2028:2030)
  expect_equal(r$kpis$burden_ratio_max, (22400 / 12) / (5000 * 1.02), tolerance = 1e-10)
  expect_identical(r$kpis$restriction_burden, 0)
  expect_identical(r$kpis$restriction_savings, 0)
  expect_equal(r$kpis$own_contribution, 500000 - 400000, tolerance = 1e-10)
  expect_false("monthly_net_cashflow_y1" %in% names(r$kpis))
})

test_that("Monatlicher Cashflow (Kleinvermieter, Orakel (c1)): Zuschuss, Minimum, ohne Restwert", {
  sc <- d2_oracle_c()
  sc$project$perspective <- "kleinvermieter"
  r <- d2_run(sc)
  noi <- 12000 * 1.02^(0:9)
  expect_equal(r$kpis$monthly_net_cashflow_y1, (12000 - 17400) / 12, tolerance = 1e-10)
  expect_equal(r$kpis$monthly_net_cashflow_min, (12000 - 17400) / 12, tolerance = 1e-10)
  expect_equal(r$kpi_series$monthly_net_cashflow$values[1, ], (noi - 17400) / 12,
               tolerance = 1e-10)
  expect_identical(r$kpi_series$monthly_net_cashflow$years, 2027:2036)
  expect_false("monthly_burden_y1" %in% names(r$kpis))
  # synthetisch: Gebühren und Zuschüsse zählen, Restwert und Verkaufskosten nicht
  core <- d2_debt_core()
  core$ledger$values$rv__value[, 7] <- 50000
  core$ledger$values$rv__sale_cost[, 7] <- -1500
  ctx <- d2_ctx(core, perspective = "kleinvermieter")
  v <- d2_kpi("monthly_net_cashflow", core, ctx)
  expect_equal(v$values[1, ], rep((10000 - 1000 + 500 - 8000) / 12, 6))
  fee <- core
  fee$ledger$values$loan_neu_fees[, 2] <- -1200
  expect_equal(d2_kpi("monthly_net_cashflow_min", fee, ctx)$values, (1500 - 1200) / 12)
  wu <- d2_ctx(core)
  expect_identical(unique(d2_kpi("monthly_net_cashflow", core, wu)$na_reason),
                   "not_applicable_perspective")
})

test_that("Eigenanteil nach Förderung (R-83): Investition - Zuschüsse - neue Kredite", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 3L)
  rows <- list(inv__cost = d2_row("project", "capex", c(-300000, 0, 0, 0), "b1", "m1"),
               land__value = d2_row("project", "land", c(-50000, 0, 0, 0), "b1"),
               acq__value = d2_row("project", "acquisition_cost", c(-20000, 0, 0, 0), "b1"),
               rel__value = d2_row("project", "relocation_cost", c(0, -5000, 0, 0),
                                   measure = "m1"),
               repl__value = d2_row("project", "replacement", c(0, 0, -10000, 0), "b1", "m1"),
               grant__value = d2_row("grants", "grant", c(0, 30000, 0, 0), measure = "m1"),
               tc__value = d2_row("grants", "tax_credit", c(0, 0, 2000, 0), measure = "m1"),
               ek__in = d2_row("equity", "equity_in", c(200000, 0, 0, 0)))
  loans <- list(neu = d2_loan(draw = c(200000, 0, 0, 0), balance = rep(200000, 4)),
                alt = d2_loan(draw = c(80000, 0, 0, 0), balance = rep(80000, 4)))
  core <- d2_core(g, rows, loans)
  hit <- core$ledger$rows$source_id == "alt"
  core$ledger$rows$existing_debt[hit] <- TRUE
  v <- d2_kpi("own_contribution", core, d2_ctx(core))
  expect_equal(v$values, 300000 + 50000 + 20000 + 5000 - 30000 - 2000 - 200000)
  b1 <- d2_run(d2_oracle_b("shorten_term"))
  expect_equal(b1$kpis$own_contribution, -150000)
})
