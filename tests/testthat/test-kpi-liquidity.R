# Tests für R/kpi-liquidity.R (WS-D2; Spec 00 Abschnitte 12.3, 15.3; Memo 01 §10).

test_that("Orakel (a), (b1), (c1): Nettoliquidität, Kontokorrent, Finanzierungsbedarf", {
  o <- oracle_a_values()$kpi
  a <- d2_run(d2_oracle_a())
  tol <- vofi_tol$oracle_abs
  expect_equal(a$kpis$min_net_liquidity, o$min_net_liquidity, tolerance = tol / 6491.3)
  expect_equal(a$kpis$max_overdraft, o$max_overdraft, tolerance = tol / 6491.3)
  expect_equal(a$kpis$max_financing_need, o$max_financing_need, tolerance = tol / 6491.3)
  expect_equal(a$kpis$min_net_liquidity_ex_rv, o$min_net_liquidity, tolerance = tol / 6491.3)
  for (k in c("sum_equity_calls", "pv_equity_calls", "flag_shortfall", "flag_limit_breach",
              "flag_reserve_used")) {
    expect_identical(a$kpis[[k]], 0, info = k)
  }
  b1 <- d2_run(d2_oracle_b("shorten_term"))
  expect_equal(b1$kpis$max_overdraft, 6421.70, tolerance = 0.005 / 6421.70)
  expect_equal(b1$kpis$min_net_liquidity, -6421.70, tolerance = 0.005 / 6421.70)
  b2 <- d2_run(d2_oracle_b("reduce_installment"))
  expect_identical(b2$kpis$max_overdraft, 0)
  c1 <- d2_run(d2_oracle_c())
  expect_equal(c1$kpis$max_overdraft, 59114.48, tolerance = 0.005 / 59114.48)
  expect_equal(c1$kpis$min_net_liquidity, -59114.48, tolerance = 0.005 / 59114.48)
  # ohne Restwert: KK in T nicht zurückgeführt (Terminalzustand 9.4)
  expect_true(c1$kpis$max_overdraft_ex_rv > c1$kpis$max_overdraft)
  e <- d2_run(d2_oracle_e())
  expect_equal(e$kpis$max_overdraft, 11530.53, tolerance = 0.005 / 11530.53)
})

test_that("Orakel (c2), (g): Summe und Barwert der Nachschüsse, Finanzierungsbedarf", {
  c2 <- d2_run(d2_oracle_c(limit = 0))
  expect_equal(c2$kpis$sum_equity_calls, 39544.46, tolerance = 0.005 / 39544.46)
  expect_equal(c2$kpis$pv_equity_calls, 35359.90, tolerance = 0.005 / 35359.90)
  expect_equal(c2$kpis$max_financing_need, c2$kpis$sum_equity_calls, tolerance = 1e-12)
  expect_identical(c2$kpis$max_overdraft, 0)
  expect_identical(c2$kpis$flag_shortfall, 1)
  ga <- d2_run(d2_oracle_g("a"))
  expect_equal(ga$kpis$sum_equity_calls, 3000, tolerance = 1e-12)
  expect_equal(ga$kpis$pv_equity_calls, 3000 / 1.02, tolerance = 1e-12)
  expect_equal(ga$kpis$pv_equity_calls, 2941.18, tolerance = 0.005 / 2941.18)
})

test_that("max_financing_need: KK plus kumulierte Nachschüsse", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 3L)
  rows <- list(z__value = d2_row("project", "custom", c(-10000, -5000, 0, 20000)),
               ek__in = d2_row("equity", "equity_in", c(10000, 0, 0, 0)))
  core <- d2_core(g, rows, h = 0, s = 0, kl = 0)
  ctx <- d2_ctx(core)
  expect_equal(kpi_ns(core)[1, ], c(0, 5000, 0, 0))
  expect_equal(d2_kpi("max_financing_need", core, ctx)$values, 5000)
  expect_equal(d2_kpi("sum_equity_calls", core, ctx)$values, 5000)
  expect_identical(d2_kpi("flag_shortfall", core, ctx)$values, 1)
  core2 <- d2_core(g, rows, h = 0, s = 0, kl = Inf)
  expect_equal(d2_kpi("max_financing_need", core2, d2_ctx(core2))$values, 5000)
  expect_equal(d2_kpi("max_overdraft", core2, d2_ctx(core2))$values, 5000)
  expect_equal(d2_kpi("min_net_liquidity", core2, d2_ctx(core2))$values, -5000)
  expect_equal(kpi_cumsum_cols(matrix(1:6, 2)), matrix(c(1, 2, 4, 6, 9, 12), 2))
})

test_that("restriction_liquidity: Limit, Markierungsschwelle, stop, nicht prüfbar (R-101)", {
  core <- example_core(2L)
  on <- function(...) {
    d2_ctx(core, analysis = list(restrictions = c("liquidity", "savings")), ...)
  }
  # Schwelle 25.000 endlich, kein KK im Beispiel -> 0
  expect_identical(d2_kpi("restriction_liquidity", core, on())$values, c(0, 0))
  # Schwelle unter dem KK-Stand
  over <- core
  over$stocks$KK[, 3] <- c(30000, 10000)
  expect_identical(d2_kpi("restriction_liquidity", over, on())$values, c(1, 0))
  # Strafzinstranche genutzt bzw. Policy stop
  pen <- core
  pen$stocks$KKP[1, 4] <- 1
  pen$flags$stopped <- c(FALSE, TRUE)
  expect_identical(d2_kpi("restriction_liquidity", pen, on())$values, c(1, 1))
  # unendliches Limit und unendliche Schwelle: nicht prüfbar
  inf <- on(accounts = list(overdraft_flag_threshold_eur = Inf))
  v <- d2_kpi("restriction_liquidity", core, inf)
  expect_identical(v$na_reason, rep("no_liquidity_limit", 2))
  # endliches Limit aus der Engine (core$limits$KL) macht die Restriktion prüfbar
  lim <- core
  lim$limits <- list(KL = matrix(c(Inf, 5000), 2, 7))
  v2 <- d2_kpi("restriction_liquidity", lim, inf)
  expect_identical(v2$values, c(NA, 0))
  expect_identical(v2$na_reason, c("no_liquidity_limit", NA))
  # endliches Limit aus der Spezifikation
  lim_spec <- on(accounts = list(overdraft_flag_threshold_eur = Inf,
                                 overdraft_limit_eur = 10000))
  expect_identical(d2_kpi("restriction_liquidity", core, lim_spec)$values, c(0, 0))
  # nicht in analysis.restrictions
  off <- d2_ctx(core, analysis = list(restrictions = "dscr"))
  expect_identical(d2_kpi("restriction_liquidity", core, off)$na_reason,
                   rep("not_applicable_perspective", 2))
})

test_that("restriction_savings: Markierung equity_call_over_savings, ohne Sparfähigkeit NA", {
  core <- example_core(2L)
  ctx <- d2_ctx(core, analysis = list(restrictions = "savings"))
  expect_identical(d2_kpi("restriction_savings", core, ctx)$values, c(0, 0))
  hit <- core
  hit$flags$equity_call_over_savings <- c(TRUE, FALSE)
  expect_identical(d2_kpi("restriction_savings", hit, ctx)$values, c(1, 0))
  spec <- reg_test_spec(core$grid, analysis = list(restrictions = "savings"))
  spec$household$savings_capacity_month_eur <- NULL
  v <- d2_kpi("restriction_savings", core, d2_ctx(core, spec = spec))
  expect_identical(v$na_reason, rep("no_household_income", 2))
  flags <- core
  flags$flags$reserve_used <- c(TRUE, FALSE)
  flags$flags$limit_breach <- c(FALSE, TRUE)
  expect_identical(d2_kpi("flag_reserve_used", flags, ctx)$values, c(1, 0))
  expect_identical(d2_kpi("flag_limit_breach", flags, ctx)$values, c(0, 1))
})
