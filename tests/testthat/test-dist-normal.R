# Tests für R/dist-normal.R (WS-C; Spec 01 Teil C 1.4.2).

test_that("normal: Prüffall mean 0, sd 0.004 (q10/q50/q90)", {
  d <- wsc_dist("normal")
  par <- list(mean = 0, sd = 0.004)
  expect_spec(d$quantile(c(0.1, 0.5, 0.9), par), c("-0.0051262063", "0", "0.0051262063"))
  expect_identical(d$moments(par), list(mean = 0, var = 0.004^2))
  for (w in c("mode", "median", "mean")) expect_identical(d$point(par, w), 0)
})

test_that("normal: Entartung sd = 0 auch an den Rändern", {
  d <- wsc_dist("normal")
  expect_identical(d$quantile(c(0, 0.3, 1), list(mean = 2, sd = 0)), c(2, 2, 2))
  expect_identical(d$moments(list(mean = 2, sd = 0))$var, 0)
})

test_that("normal: Validierung (D3) und Vertrag", {
  d <- wsc_dist("normal")
  expect_identical(d$validate(list(mean = 1, sd = 0)), character(0))
  expect_length(d$validate(list(mean = 1, sd = -1)), 1L)
  expect_length(d$validate(list(sd = 1)), 1L)
  expect_length(d$validate(list(mean = NA, sd = NA)), 2L)
  expect_type_contract("normal", "distribution")
})
