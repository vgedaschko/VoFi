# Tests für R/dist-lognormal.R (WS-C; Spec 01 Teil C 1.4.4).

test_that("lognormal: Prüffall l1 (mean 1,1, sd 0,1)", {
  d <- wsc_dist("lognormal")
  par <- list(mean = 1.1, sd = 0.1)
  p <- dist_lognormal_canon(par)
  expect_spec(p$meanlog, "0.09119493")
  expect_spec(p$sdlog, "0.090722098")
  expect_spec(d$quantile(c(0.1, 0.5, 0.9), par), c("0.97524153", "1.0954825", "1.2305485"))
  expect_equal(d$moments(par)$mean, 1.1, tolerance = 1e-12)
  expect_equal(d$moments(par)$var, 0.01, tolerance = 1e-12)
})

test_that("lognormal: Prüffall l2 (median 0,02, p90 0,05; Quote mit Warnhinweis)", {
  d <- wsc_dist("lognormal")
  par <- list(median = 0.02, p90 = 0.05)
  p <- dist_lognormal_canon(par)
  expect_spec(p$meanlog, "-3.912023")
  expect_spec(p$sdlog, "0.71498546")
  expect_spec(d$point(par, "mean"), "0.025824777")
  expect_spec(d$quantile(c(0.99, 0.9999), par), c("0.10553442", "0.2856522"))
  expect_equal(d$quantile(0.9, par), 0.05, tolerance = 1e-12)
  expect_equal(d$point(par, "median"), 0.02, tolerance = 1e-12)
})

test_that("lognormal: Prüffall l3 (meanlog 0, sdlog 0,25), Modus und Verschiebung", {
  d <- wsc_dist("lognormal")
  par <- list(meanlog = 0, sdlog = 0.25)
  m <- d$moments(par)
  expect_spec(m$mean, "1.0317434")
  expect_spec(m$var, "0.068653994")
  expect_equal(d$point(par, "mode"), exp(-0.0625), tolerance = 1e-12)
  sh <- list(meanlog = 0, sdlog = 0.25, shift = 2)
  expect_equal(d$quantile(c(0.2, 0.7), sh), 2 + d$quantile(c(0.2, 0.7), par),
               tolerance = 1e-14)
  expect_equal(d$moments(sh)$var, m$var, tolerance = 1e-14)
  # Form b mit Verschiebung: Mittelwert und sd getroffen
  b <- list(mean = 5, sd = 1, shift = 2)
  expect_equal(d$moments(b)$mean, 5, tolerance = 1e-12)
  expect_equal(d$moments(b)$var, 1, tolerance = 1e-12)
  # Entartung sdlog = 0 bzw. sd = 0
  expect_identical(d$quantile(c(0, 0.5, 1), list(meanlog = 0, sdlog = 0)), c(1, 1, 1))
  expect_equal(d$quantile(0.3, list(mean = 2, sd = 0)), 2, tolerance = 1e-14)
})

test_that("lognormal: Validierung (Prüffall l4 und weitere Formfehler)", {
  d <- wsc_dist("lognormal")
  expect_identical(d$validate(list(mean = 1.1, sd = 0.1)), character(0))
  expect_identical(d$validate(list(median = 0.02, p90 = 0.05)), character(0))
  expect_identical(d$validate(list(meanlog = 0, sdlog = 0.25)), character(0))
  expect_length(d$validate(list(meanlog = 0, sdlog = 1, mean = 1, sd = 1)), 1L)
  expect_length(d$validate(list(mean = 1)), 1L)
  expect_length(d$validate(list()), 1L)
  expect_length(d$validate(list(mean = 1, sd = 1, shift = 1)), 1L)
  expect_length(d$validate(list(mean = 1, sd = -1)), 1L)
  expect_length(d$validate(list(median = 1, p90 = 0.5)), 1L)
  expect_length(d$validate(list(median = -1, p90 = 0.5)), 1L)
  expect_length(d$validate(list(meanlog = NA, sdlog = 1)), 1L)
  expect_length(d$validate(list(meanlog = 0, sdlog = -1)), 1L)
  expect_length(d$validate(list(meanlog = 0, sdlog = 1, shift = Inf)), 1L)
  expect_error(d$quantile(0.5, list(mean = 1)), class = "vofi_error_input")
  expect_type_contract("lognormal", "distribution")
})

test_that("lognormal: kanonische Ablage im Plan (meanlog, sdlog, shift)", {
  expect_identical(names(dist_canonical("lognormal", list(median = 0.02, p90 = 0.05), "k")),
                   c("meanlog", "sdlog", "shift"))
  bad <- dist_canonical("lognormal", list(mean = 1), "k")
  expect_identical(bad, list(mean = 1))
})
