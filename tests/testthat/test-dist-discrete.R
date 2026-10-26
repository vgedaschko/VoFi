# Tests für R/dist-discrete.R (WS-C; Spec 01 Teil C 1.4.10).

test_that("discrete: Prüffall Kesselausfall 2028-2033 (gleich verteilt)", {
  d <- wsc_dist("discrete")
  par <- list(values = 2028:2033)
  m <- d$moments(par)
  expect_equal(m$mean, 2030.5)
  expect_spec(m$var, "2.9166667")
  expect_identical(d$quantile(c(0.1, 1 / 6, 1 / 6 + 1e-12, 0.5, 0.9), par),
                   c(2028, 2028, 2029, 2030, 2033))
  expect_identical(d$quantile(c(0, 1), par), c(2028, 2033))
})

test_that("discrete: S4-Verschiebung [0, 12, …, 60] (Mittel 30, Median 24, Modus 0)", {
  d <- wsc_dist("discrete")
  par <- list(values = c(0, 12, 24, 36, 48, 60))
  expect_equal(d$point(par, "mean"), 30)
  expect_identical(d$quantile(0.5, par), 24)
  expect_identical(d$point(par, "median"), 24)
  expect_identical(d$point(par, "mode"), 0)
})

test_that("discrete: Sortierung nach values, P_K = 1 exakt, Modus bei Gleichstand", {
  d <- wsc_dist("discrete")
  par <- list(values = c(3, 1, 2), probs = c(0.2, 0.5, 0.3))
  expect_identical(d$quantile(c(0.4, 0.6, 0.85, 1), par), c(1, 2, 3, 3))
  expect_identical(d$point(par, "mode"), 1)
  expect_identical(d$point(list(values = c(5, 2), probs = c(0.5, 0.5)), "mode"), 2)
  # Summe der Gewichte mit Rundungsfehler: der letzte Wert bleibt erreichbar
  p3 <- list(values = 1:3, probs = c(0.1, 0.2, 0.7 - 1e-12))
  expect_identical(d$quantile(1 - 1e-13, p3), 3)
})

test_that("discrete: Validierung und Vertrag", {
  d <- wsc_dist("discrete")
  expect_identical(d$validate(list(values = c(1, 2), probs = c(0.4, 0.6))), character(0))
  expect_length(d$validate(list(values = numeric(0))), 1L)
  expect_length(d$validate(list(values = c(1, 1))), 1L)
  expect_length(d$validate(list(values = c(1, 2), probs = 1)), 1L)
  expect_length(d$validate(list(values = c(1, 2), probs = c(-0.1, 1.1))), 1L)
  expect_length(d$validate(list(values = c(1, 2), probs = c(0.5, 0.6))), 1L)
  expect_length(d$validate(list(values = c(1, Inf))), 1L)
  expect_type_contract("discrete", "distribution")
})
