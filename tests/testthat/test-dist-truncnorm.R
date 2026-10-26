# Tests für R/dist-truncnorm.R (WS-C; Spec 01 Teil C 1.4.3).

test_that("truncnorm: Prüffall t1 (S4 KfW-358-Zins)", {
  d <- wsc_dist("truncnorm")
  par <- list(mean = 0.0275, sd = 0.0075, lower = 0.01, upper = 0.05)
  m <- d$moments(par)
  expect_spec(m$mean, "0.027665271")
  expect_spec(sqrt(m$var), "0.0072101237")
  expect_spec(d$quantile(c(0.1, 0.5, 0.9), par), c("0.018248918", "0.027579575", "0.037101672"))
  expect_spec(d$point(par, "median"), "0.027579575")
  expect_identical(d$point(par, "mode"), 0.0275)
  expect_equal(d$point(par, "mean"), m$mean)
})

test_that("truncnorm: Prüffall t2 (Memo 04 KS-Test) und Momente gegen Integration", {
  d <- wsc_dist("truncnorm")
  par <- list(mean = 0, sd = 1, lower = -1, upper = 2)
  m <- d$moments(par)
  expect_spec(m$mean, "0.22963718")
  expect_spec(m$var, "0.51976254")
  # Verteilungsfunktion der Quantile: F(Q(u)) = u
  u <- c(0.01, 0.2, 0.5, 0.77, 0.999)
  f <- (pnorm(d$quantile(u, par)) - pnorm(-1)) / (pnorm(2) - pnorm(-1))
  expect_equal(f, u, tolerance = 1e-12)
})

test_that("truncnorm: obere Flanke (Φ(α) > 0,5) numerisch stabil und monoton", {
  d <- wsc_dist("truncnorm")
  par <- list(mean = 0, sd = 1, lower = 6, upper = 9)
  q <- d$quantile(c(1e-9, 0.25, 0.5, 0.75, 1 - 1e-9), par)
  expect_true(all(is.finite(q)) && all(diff(q) > 0))
  expect_true(all(q >= 6 & q <= 9))
  m <- d$moments(par)
  expect_true(m$mean > 6 && m$mean < 6.3)
  # einseitig unbeschränkt
  q2 <- d$quantile(c(0.1, 0.9), list(mean = 0, sd = 1, lower = 0))
  expect_equal(q2, qnorm(0.5 + c(0.1, 0.9) / 2), tolerance = 1e-12)
  expect_equal(d$moments(list(mean = 0, sd = 1))$var, 1, tolerance = 1e-12)
})

test_that("truncnorm: Entartung sd = 0 und Aliase min/max", {
  d <- wsc_dist("truncnorm")
  expect_identical(d$quantile(c(0, 0.5, 1), list(mean = 5, sd = 0, lower = 0, upper = 3)),
                   c(3, 3, 3))
  expect_identical(d$moments(list(mean = 1, sd = 0))$mean, 1)
  a <- d$quantile(c(0.1, 0.9), list(mean = 0, sd = 1, min = -1, max = 2))
  b <- d$quantile(c(0.1, 0.9), list(mean = 0, sd = 1, lower = -1, upper = 2))
  expect_identical(a, b)
  expect_warning(p <- dist_canonical("truncnorm", list(mean = 0, sd = 1, min = -1), "k"),
                 class = "vofi_warning_input")
  expect_identical(p$lower, -1)
  expect_null(p$min)
})

test_that("truncnorm: Validierung (Prüffall t3 und weitere Fehler)", {
  d <- wsc_dist("truncnorm")
  expect_identical(d$validate(list(mean = 0.0275, sd = 0.0075, lower = 0.01, upper = 0.05)),
                   character(0))
  expect_length(d$validate(list(mean = 0, sd = 1, lower = 0.05, upper = 0.01)), 1L)
  expect_length(d$validate(list(mean = 0, sd = 1, lower = 30, upper = 40)), 1L)
  expect_length(d$validate(list(mean = 0, sd = -1)), 1L)
  expect_length(d$validate(list(sd = 1)), 1L)
  expect_length(d$validate(list(mean = 0, sd = 1, lower = "a")), 1L)
  expect_type_contract("truncnorm", "distribution")
})
