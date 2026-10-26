# Tests für R/dist-bernoulli.R (WS-C; Spec 00 5.3, R-93; Spec 01 Teil C 1.4.9).

test_that("bernoulli: Q(u) = 1{u > 1 - p} (Prüffall p = 0,85)", {
  d <- wsc_dist("bernoulli")
  par <- list(p = 0.85)
  expect_identical(d$quantile(c(1e-9, 0.5, 1 - 1e-9), par), c(0, 1, 1))
  expect_identical(d$quantile(0.15, par), 0)
  expect_identical(d$quantile(0.1500001, par), 1)
  expect_identical(d$moments(par), list(mean = 0.85, var = 0.85 * 0.15))
  expect_identical(d$point(par, "mode"), 1)
  expect_identical(d$point(par, "median"), 1)
  expect_identical(d$point(list(p = 0.5), "median"), 0)
  expect_identical(d$point(list(p = 0.5), "mode"), 1)
  u <- seq(0, 1, by = 0.01)
  expect_true(all(diff(d$quantile(u, par)) >= 0))
})

test_that("bernoulli: Randfälle p = 0 und p = 1, Validierung, Vertrag", {
  d <- wsc_dist("bernoulli")
  expect_identical(d$quantile(c(0.001, 0.999), list(p = 0)), c(0, 0))
  expect_identical(d$quantile(c(0.001, 0.999), list(p = 1)), c(1, 1))
  expect_identical(d$validate(list(p = 0)), character(0))
  expect_length(d$validate(list(p = 1.2)), 1L)
  expect_length(d$validate(list()), 1L)
  expect_type_contract("bernoulli", "distribution")
})
