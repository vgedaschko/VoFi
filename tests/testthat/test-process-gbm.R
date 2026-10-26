# Tests für R/process-gbm.R (WS-C; Spec 01 Teil C 1.6.5, 4.3 Prüffall v3).

test_that("gbm: Prüffall p0 = 1, g = 0,02, σ = 0,1, y = 31 (E, Median, P10/P90)", {
  p <- wsc_proc("gbm")
  par <- list(p0 = 1, growth = 0.02, sigma = 0.1)
  yrs <- 2027:2057
  expect_spec(p$expected(par, yrs)[31], "1.8113616")
  expect_spec(p$quantile_path(par, yrs, 0.5)[31], "1.5590534")
  expect_spec(p$quantile_path(par, yrs, 0.1)[31], "0.7727066")
  expect_spec(p$quantile_path(par, yrs, 0.9)[31], "3.1456279")
  expect_identical(p$quantile_path(par, yrs, 0.9)[1], 1)
})

test_that("gbm: Simulation (Memo 04 §9: E[P_T] = P0 (1 + g)^T)", {
  p <- wsc_proc("gbm")
  n <- 20000L
  z <- smp_shocks(4711, "shock:r:1", n, 30L, "pseudo")
  x <- p$simulate(list(p0 = 1, growth = 0.02, sigma = 0.1), z, NULL, 2027:2057,
                  structure(list(), n = n))
  expect_identical(x[, 1], rep(1, n))
  expect_lt(abs(mean(x[, 31]) / 1.02^30 - 1), 4 * stats::sd(x[, 31]) / sqrt(n) / 1.02^30)
  x0 <- p$simulate(list(p0 = 2, growth = 0.03, sigma = 0), NULL, NULL, 2027:2037,
                   structure(list(), n = 1L))
  expect_equal(as.vector(x0), 2 * 1.03^(0:10), tolerance = 1e-14)
})

test_that("gbm: Validierung und Vertrag", {
  p <- wsc_proc("gbm")
  expect_identical(p$validate(list(p0 = "base", sigma = 0.1)), character(0))
  expect_length(p$validate(list(p0 = 0, sigma = 0.1)), 1L)
  expect_length(p$validate(list(p0 = 1)), 1L)
  expect_length(p$validate(list(p0 = 1, sigma = 0.1, growth = -2)), 1L)
  expect_type_contract("gbm", "process")
})
