# Tests für R/dist-empirical.R (WS-C; Spec 00 5.3, R-93; Spec 01 Teil C 1.4.11).

test_that("empirical: Prüffall (Quantile type 7, Momente der Quantilfunktion)", {
  d <- wsc_dist("empirical")
  par <- list(data = c(0.98, 1.02, 1.05, 1.08, 1.12, 1.20, 1.35))
  expect_equal(d$quantile(c(0.1, 0.5, 0.9), par), c(1.004, 1.08, 1.26), tolerance = 1e-12)
  m <- d$moments(par)
  expect_spec(m$mean, "1.1058333")
  expect_false(isTRUE(all.equal(m$mean, mean(par$data))))
  expect_spec(m$var, "0.0087159722")
  expect_identical(d$point(par, "mode"), d$point(par, "median"))
  expect_identical(d$point(par, "median"), 1.08)
  expect_equal(d$quantile(c(0.1, 0.5, 0.9), par),
               unname(stats::quantile(par$data, c(0.1, 0.5, 0.9), type = 7)))
  # unsortierte Eingabe
  expect_identical(d$quantile(0.3, list(data = rev(par$data))), d$quantile(0.3, par))
  # Momente gegen numerische Integration der Quantilfunktion
  u <- (seq_len(200000) - 0.5) / 200000
  x <- d$quantile(u, par)
  expect_equal(mean(x), m$mean, tolerance = 1e-8)
  expect_equal(mean(x^2) - mean(x)^2, m$var, tolerance = 1e-6)
})

test_that("empirical: Validierung und Vertrag", {
  d <- wsc_dist("empirical")
  expect_length(d$validate(list(data = 1)), 1L)
  expect_length(d$validate(list(data = c(1, NA))), 1L)
  expect_identical(d$validate(list(data = c(1, 2))), character(0))
  expect_type_contract("empirical", "distribution")
})
