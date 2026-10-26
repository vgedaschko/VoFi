# Tests für R/engine-accounts.R (WS-D; Spec 00 Abschnitt 8.8): Raten, Abgeltungsteuer mit
# Sparer-Pauschbetrag, Limit (auch fallend, Zwangstilgung 6a), Mindestliquidität, sp der
# Unterlassungsalternative, Zwischenspeicher der Raten, Kettenregeln.

test_that("Abgeltungsteuer: G = 100.000, h = 3 %, w = 26,375 % ergibt HZ 3.000, WHT 791,25", {
  sc <- wsd_scenario(c(0, 0), accounts = list(deposit_rate_pa = 0.03, overdraft_rate_pa = 0.08,
                                              deposit_withholding_tax_share = 0.26375))
  res <- vofi_run(vofi_build(sc))
  v <- res$ledger$values
  expect_equal(v$dep_interest[1L, ], c(0, 3000))
  expect_equal(v$dep_wht[1L, ], c(0, -791.25))
  expect_equal(res$kpis$terminal_value, 100000 + 3000 - 791.25)
  expect_true(all(res$checks$ok))
})

test_that("Sparer-Pauschbetrag: 1.000 EUR p. a. mindert die Bemessung auf 2.000 (R-76)", {
  sc <- wsd_scenario(c(0, 0), accounts = list(deposit_rate_pa = 0.03, overdraft_rate_pa = 0.08,
                                              deposit_withholding_tax_share = 0.26375,
                                              deposit_tax_allowance_eur_pa = 1000))
  res <- vofi_run(vofi_build(sc))
  expect_equal(res$ledger$values$dep_wht[1L, ], c(0, -527.50))
  # Pauschbetrag über den Habenzinsen: keine Abgeltungsteuer, keine negative Steuer
  sc$accounts$deposit_tax_allowance_eur_pa <- 5000
  res2 <- vofi_run(vofi_build(sc))
  expect_equal(res2$ledger$values$dep_wht[1L, ], c(0, 0))
})

test_that("Pauschbetrag je Periode = Jahresbetrag * delta, Spalte t0 = 0 (Halbjahresperiode)", {
  sc <- wsd_scenario(c(0, 0, 0, 0),
                     accounts = list(deposit_rate_pa = 0.03, overdraft_rate_pa = 0.08,
                                     deposit_tax_allowance_eur_pa = 1000),
                     horizon = 2L)
  sc$grid <- list(construction_months = 6L, construction_step_months = 6L)
  model <- vofi_build(sc)
  g <- model$grid
  expect_equal(g$delta[2L], 0.5)
  env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, NULL, env)
  acc <- acc_init(model$accounts, ctx)
  expect_equal(acc$wa[1L, 1L], 0)
  expect_equal(acc$wa[1L, 2L], 500)
  expect_equal(acc$wa[1L, ], 1000 * c(0, g$delta[-1L]))
  expect_equal(acc$h[1L, 2L], 1.03^0.5 - 1)
  expect_equal(acc$h[1L, 1L], 0)
  expect_equal(acc$h_pa[1L, 2L], 0.03)
  expect_identical(dim(acc$s), c(1L, g$T + 1L))
})

test_that("acc_init: fehlendes Limit ist unbegrenzt, Bestände starten bei 0", {
  model <- wsd_skeleton()
  env <- eng_engine_env(model, quiet = TRUE)
  real <- eng_context(model, NULL, env)
  fake <- list(n = 1L, grid = real$grid, zeros = real$zeros, rate_eff = real$rate_eff,
               by_period = real$by_period,
               value = function(path, shape = "scalar") {
                 if (path %in% c("accounts.overdraft_limit_eur",
                                 "accounts.overdraft_flag_threshold_eur")) NULL else
                   real$value(path, shape)
               })
  acc <- acc_init(model$accounts, fake)
  expect_true(all(is.infinite(acc$KL)))
  expect_true(is.infinite(acc$flag_threshold))
  expect_equal(c(acc$G, acc$KK, acc$KKP), c(0, 0, 0))
  expect_identical(acc$j, 1L)
  expect_equal(acc$s[1L, 2L], 0.08)
  expect_true(acc$sp[1L, 2L] >= acc$s[1L, 2L])
})

test_that("Unterlassungsalternative: sp := s, Raten einmal je Kontext berechnet (R-81)", {
  sc <- wsd_scenario(c(0, 0), accounts = list(overdraft_rate_pa = 0.08,
                                              penalty_spread_pa = 0.03))
  model <- vofi_build(sc)
  env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, NULL, env)
  a <- eng_acc_rates(model, ctx, env)
  expect_equal(a$sp[1L, 2L], 0.11)
  expect_false(is.null(env$acc_rates))
  m_opp <- eng_opportunity_model(model)
  expect_true(isTRUE(m_opp$accounts$opp_regular_penalty))
  b <- eng_acc_rates(m_opp, ctx, env)
  expect_equal(b$sp, b$s)
  expect_equal(b$s, a$s)
  # der Zwischenspeicher behält die Raten der Investition
  expect_equal(env$acc_rates$sp[1L, 2L], 0.11)
  # ohne Engine-Umgebung identisches Ergebnis
  expect_equal(eng_acc_rates(model, ctx, NULL), a)
})

test_that("acc_modify und acc_prepay_value", {
  expect_identical(acc_modify(NULL, a = 1), list(a = 1))
  expect_identical(acc_modify(list(a = 1), a = NULL), list(a = NULL))
  expect_identical(acc_prepay_value(NULL), 0)
  expect_identical(acc_prepay_value(list(kind = "const", value = 500)), 500)
  expect_identical(acc_prepay_value(0.01), 0.01)
})

test_that("Fallendes Limit: Zwangstilgung des Überhangs, gedeckt durch die Defizitkette (6a)", {
  sc <- wsd_scenario(c(-50000, 0, 0, 60000), ek = NULL,
                     accounts = list(overdraft_limit_eur = c(50000, 50000, 20000, 20000)))
  m <- testthat::capture_messages(res <- vofi_run(vofi_build(sc)))
  expect_length(m, 2L)
  v <- res$ledger$values
  expect_equal(v$od_draw[1L, ], c(50000, 0, 0, 0))
  expect_equal(v$od_repay[1L, ], c(0, 0, -30000, -20000))
  expect_equal(v$equity_call[1L, ], c(0, 0, 30000, 0))
  expect_equal(v$od_balance[1L, ], c(50000, 50000, 20000, 0))
  expect_true(res$flags$limit_cut)
  expect_identical(res$flags$first_shortfall_t, 2L)
  expect_equal(res$kpis$terminal_value, 40000)
  expect_true(all(res$checks$ok))
})

test_that("Mindestliquidität: D1 nur oberhalb L_min, Reserve über D3 mit Markierung", {
  sc <- wsd_scenario(c(-90000, -15000), ek = list(type = "equity", amount_eur = 100000),
                     accounts = list(min_liquidity_eur = 10000, overdraft_limit_eur = 3000,
                                     deficit_order = c("dep_withdraw", "od_draw",
                                                       "dep_use_reserve", "equity_call")))
  m <- testthat::capture_messages(res <- vofi_run(vofi_build(sc)))
  v <- res$ledger$values
  expect_equal(v$dep_invest[1L, ], c(-10000, 0))
  expect_equal(v$dep_withdraw[1L, ], c(0, 10000))
  expect_equal(v$od_draw[1L, ], c(0, 3000))
  expect_equal(v$equity_call[1L, ], c(0, 2000))
  expect_true(res$flags$reserve_used)
  expect_true(res$flags$shortfall)
  expect_length(grep("Liquidit", m), 1L)
})

test_that("Überschüsse füllen mit dep_fill_reserve zuerst die Reserve", {
  sc <- wsd_scenario(c(-95000, 2000, 8000), ek = list(type = "equity", amount_eur = 100000),
                     accounts = list(min_liquidity_eur = 10000,
                                     surplus_order = c("od_repay", "dep_fill_reserve",
                                                       "dep_invest")))
  res <- vofi_run(vofi_build(sc))
  v <- res$ledger$values
  expect_equal(v$dep_balance[1L, ], c(5000, 7000, 15000))
  expect_equal(res$kpis$terminal_value, 15000)
})

test_that("Schwelle des Kontokorrents: Hinweis overdraft_threshold einmal je Lauf", {
  sc <- wsd_scenario(c(-108000, 0, 9000), ek = list(type = "equity", amount_eur = 100000),
                     accounts = list(overdraft_limit_eur = Inf,
                                     overdraft_flag_threshold_eur = 5000))
  m <- testthat::capture_messages(res <- vofi_run(vofi_build(sc)))
  expect_true(res$flags$overdraft_threshold)
  expect_equal(res$ledger$values$od_balance[1L, ], c(8000, 8000, 0))
  expect_true(any(grepl("100,00 %", m, fixed = TRUE)))
})

test_that("Kettenregeln: falsche Reihenfolge ist ein Validierungsfehler (8.9)", {
  sc <- wsd_scenario(c(0, 0), accounts = list(surplus_order = c("dep_invest", "od_repay")))
  expect_error(vofi_build(sc), class = "vofi_error_validation")
  sc2 <- wsd_scenario(c(0, 0), accounts = list(deficit_order = c("dep_withdraw", "od_draw")))
  expect_error(vofi_build(sc2), class = "vofi_error_validation")
})
