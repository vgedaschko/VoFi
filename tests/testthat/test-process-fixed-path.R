# Tests für R/process-fixed-path.R (WS-C; Spec 01 Teil C 1.6.8).

test_that("fixed_path: lineare Interpolation, außerhalb konstant, deterministisch", {
  p <- wsc_proc("fixed_path")
  par <- list(years = c(2028, 2030), values = c(0.04, 0.06))
  e <- p$expected(par, 2026:2032)
  expect_equal(e, c(0.04, 0.04, 0.04, 0.05, 0.06, 0.06, 0.06))
  x <- p$simulate(par, NULL, NULL, 2026:2032, structure(list(), n = 3L))
  expect_identical(dim(x), c(3L, 7L))
  expect_identical(x[2, ], e)
  expect_identical(p$n_shocks(par), 0L)
  expect_identical(p$n_uniforms(par), 0L)
  expect_null(wsc_proc("fixed_path")$quantile_path)
  one <- list(years = 2030, values = 7)
  expect_identical(p$expected(one, 2027:2029), c(7, 7, 7))
})

test_that("fixed_path: Validierung und Vertrag", {
  p <- wsc_proc("fixed_path")
  expect_identical(p$validate(list(years = c(2028, 2030), values = c(1, 2))), character(0))
  expect_length(p$validate(list(years = c(2030, 2028), values = c(1, 2))), 1L)
  expect_length(p$validate(list(years = c(2028, 2030), values = 1)), 1L)
  expect_length(p$validate(list(years = numeric(0), values = numeric(0))), 1L)
  expect_length(p$validate(list(years = 2030, values = list(dist = "normal", mean = 0, sd = 1))),
                1L)
  expect_type_contract("fixed_path", "process")
})
