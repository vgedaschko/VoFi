# Tests für R/dist-uniform.R (WS-C; Spec 01 Teil C 1.4.5).

test_that("uniform: Prüffall [0; 0,30] (S2 Green Premium)", {
  d <- wsc_dist("uniform")
  par <- list(min = 0, max = 0.3)
  expect_equal(d$point(par, "mean"), 0.15)
  expect_spec(sqrt(d$moments(par)$var), "0.08660254")
  expect_equal(d$quantile(c(0.1, 0.9), par), c(0.03, 0.27), tolerance = 1e-14)
  expect_identical(d$point(par, "mode"), d$point(par, "median"))
  expect_identical(d$quantile(c(0, 1), par), c(0, 0.3))
})

test_that("uniform: Entartung und Validierung", {
  d <- wsc_dist("uniform")
  expect_identical(d$quantile(c(0, 0.4, 1), list(min = 2, max = 2)), c(2, 2, 2))
  expect_identical(d$moments(list(min = 2, max = 2))$var, 0)
  expect_identical(d$validate(list(min = 2, max = 2)), character(0))
  expect_length(d$validate(list(min = 3, max = 2)), 1L)
  expect_length(d$validate(list(max = 2)), 1L)
  expect_length(d$validate(list(min = 1)), 1L)
  expect_type_contract("uniform", "distribution")
})
