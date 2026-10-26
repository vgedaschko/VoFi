# Tests für R/process-ar1.R (WS-C; Spec 01 Teil C 1.6.1, 4.3 Nr. 1 c).

infl <- list(mu = 0.02, phi = 0.5, sigma = 0.011, x0 = 0.028)
yrs <- 2027:2057

test_that("ar1: Erwartung und sd (Bibliotheksdefault inflation_ar1_2026)", {
  p <- wsc_proc("ar1")
  e <- p$expected(infl, yrs)
  expect_spec(e[c(1, 2, 3, 5, 11, 31)],
              c("0.028", "0.024", "0.022", "0.0205", "0.020007812", "0.020000000"))
  # sd mit μ-Unsicherheit N(0,020; 0,004): σ²(1 − φ^{2(y−1)})/(1 − φ²) + (1 − φ^{y−1})² s_μ²
  m <- proc_ar1_moments(infl, yrs)
  k <- seq_along(yrs) - 1
  sd_mu <- sqrt(m$sd^2 + (1 - 0.5^k)^2 * 0.004^2)
  expect_spec(sd_mu[c(1, 2, 3, 5, 11, 31)],
              c("0", "0.01118034", "0.012658989", "0.013219895", "0.013315478", "0.013316656"))
  expect_spec(0.011 / sqrt(1 - 0.25), "0.012701706")
})

test_that("ar1: Quantilpfad y = 11 (Prüffall v2)", {
  p <- wsc_proc("ar1")
  m <- proc_ar1_moments(infl, yrs)
  expect_spec(m$mean[11], "0.020007812")
  expect_spec(m$sd[11], "0.0127017")
  expect_spec(p$quantile_path(infl, yrs, 0.1)[11], "0.003729929")
  expect_spec(p$quantile_path(infl, yrs, 0.9)[11], "0.036285696")
  expect_identical(p$quantile_path(infl, yrs, 0.3)[1], 0.028)
})

test_that("ar1: Simulation (Rekursion, Spalte 1, n-Vektoren, x0-Default, Stationarität)", {
  p <- wsc_proc("ar1")
  z <- matrix(c(1, -1, 0.5, 0, 2, -2), 2, 3)
  x <- p$simulate(infl, z, NULL, 2027:2030, structure(list(), n = 2L))
  expect_identical(dim(x), c(2L, 4L))
  expect_identical(x[, 1], c(0.028, 0.028))
  expect_equal(x[1, 2], 0.02 + 0.5 * 0.008 + 0.011)
  expect_equal(x[2, 3], 0.02 + 0.5 * (x[2, 2] - 0.02) + 0.011 * 0)
  # unsichere Parameter als n-Vektor
  x2 <- p$simulate(list(mu = c(0.01, 0.03), phi = 0.5, sigma = 0), NULL, NULL, 2027:2029,
                   structure(list(), n = 2L))
  expect_identical(x2[, 1], c(0.01, 0.03))
  expect_equal(x2[, 3], c(0.01, 0.03))
  # ohne Schocks und Jahre > 1: Erwartungspfad
  x3 <- p$simulate(infl, NULL, NULL, yrs, structure(list(), n = 1L))
  expect_equal(as.vector(x3), p$expected(infl, yrs), tolerance = 1e-15)
  # nur ein Jahr
  expect_identical(dim(p$simulate(infl, NULL, NULL, 2027L, structure(list(), n = 3L))),
                   c(3L, 1L))
  # Stationarität: sd und Lag-1-Autokorrelation (Memo 04 §9, Prototyp sd 0,0125 bei φ = 0,6)
  n <- 20000L
  zz <- smp_shocks(4711, "shock:test:1", n, 40L, "pseudo")
  g <- p$simulate(list(mu = 0.02, phi = 0.6, sigma = 0.01), zz, NULL, 2027:2067,
                  structure(list(), n = n))
  expect_lt(abs(stats::sd(g[, 41]) / (0.01 / sqrt(1 - 0.36)) - 1), 0.03)
  expect_lt(abs(stats::cor(g[, 40], g[, 41]) - 0.6), 0.03)
})

test_that("ar1: Validierung (Parameter, Verteilungen, Token)", {
  p <- wsc_proc("ar1")
  mod <- function(...) utils::modifyList(infl, list(...))
  expect_identical(p$validate(infl), character(0))
  expect_identical(p$validate(mod(x0 = "base")), character(0))
  expect_identical(p$validate(mod(mu = list(dist = "normal", mean = 0.02, sd = 0.004))),
                   character(0))
  expect_length(p$validate(mod(phi = 1)), 1L)
  expect_length(p$validate(mod(sigma = -0.1)), 1L)
  expect_length(p$validate(list(phi = 0.5, sigma = 0.01)), 1L)
  expect_length(p$validate(mod(mu = "base")), 1L)
  expect_length(p$validate(mod(phi = list(dist = "normal", mean = 0.5, sd = 0.1))), 1L)
  expect_identical(p$validate(mod(phi = list(dist = "uniform", min = 0.3, max = 0.7))),
                   character(0))
  expect_length(p$validate(mod(sigma = list(dist = "normal", mean = 0.01, sd = 0.01))), 1L)
  expect_length(p$validate(mod(mu = list(dist = "gibtsnicht"))), 1L)
  expect_length(p$validate(mod(mu = list(dist = "uniform", min = 1, max = 0))), 1L)
  expect_error(p$simulate(utils::modifyList(infl, list(x0 = "base")), NULL, NULL, yrs,
                          structure(list(), n = 1L)), class = "vofi_error_contract")
  expect_true(is.na(p$expected(utils::modifyList(infl, list(x0 = "base")), yrs)[1]))
  expect_identical(p$n_shocks(infl), 1L)
  expect_identical(p$n_uniforms(infl), 0L)
  expect_type_contract("ar1", "process")
})
