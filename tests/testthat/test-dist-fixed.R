# Tests für R/dist-fixed.R (WS-C; Spec 01 Teil C 1.4.1).

test_that("fixed: Prüffall value = 3 (Quantile, Momente, Punkte)", {
  d <- wsc_dist("fixed")
  par <- list(value = 3)
  expect_identical(d$quantile(c(0.1, 0.9), par), c(3, 3))
  expect_identical(d$moments(par), list(mean = 3, var = 0))
  for (w in c("mode", "median", "mean")) expect_identical(d$point(par, w), 3)
  expect_identical(d$point(par), 3)
  expect_length(d$quantile(numeric(0), par), 0L)
})

test_that("fixed: Validierung und Vertrag", {
  d <- wsc_dist("fixed")
  expect_identical(d$validate(list(value = 3)), character(0))
  expect_length(d$validate(list()), 1L)
  expect_length(d$validate(list(value = Inf)), 1L)
  expect_length(d$validate(list(value = "a")), 1L)
  expect_error(d$point(list(value = 1), "max"), class = "vofi_error_input")
  expect_type_contract("fixed", "distribution")
})
