# Tests für R/process-scenario-mix.R (WS-C; Spec 01 Teil C 1.6.6, 4.3 Nr. 1 c).

sm <- list(scenarios = list(
  niedrig = list(prob = 0.3, years = 2030, values = 70),
  mittel = list(prob = 0.5, years = 2030, values = 120),
  hoch = list(prob = 0.2, years = 2030, values = 200)
))

test_that("scenario_mix: kanonische Ordnung alphabetisch (Prüffall Memo 04 §10.2)", {
  p <- wsc_proc("scenario_mix")
  s <- proc_scenarios(sm, 2030)
  expect_identical(s$names, c("hoch", "mittel", "niedrig"))
  expect_equal(s$cum, c(0.2, 0.7, 1))
  x <- p$simulate(sm, NULL, matrix(c(0.15, 0.25, 0.75), 3), 2030,
                  structure(list(), n = 3L))
  expect_identical(attr(x, "scenario"), 1:3)
  expect_identical(as.vector(x), c(200, 120, 70))
  expect_equal(p$expected(sm, 2030), 121)
  # Reihenfolge der Szenarien im YAML ohne Wirkung
  rev_sm <- list(scenarios = rev(sm$scenarios))
  expect_identical(p$simulate(rev_sm, NULL, matrix(c(0.15, 0.25, 0.75), 3), 2030,
                              structure(list(), n = 3L)), x)
})

test_that("scenario_mix: Interpolation, Rauschen, Uniform-Grenzen", {
  p <- wsc_proc("scenario_mix")
  par <- list(scenarios = list(a = list(prob = 0.5, years = c(2027, 2030), values = c(50, 80)),
                               b = list(prob = 0.5, years = c(2027, 2030), values = c(50, 110))))
  x <- p$simulate(par, NULL, matrix(c(0.5, 0.5000001), 2), 2026:2031,
                  structure(list(), n = 2L))
  expect_equal(x[1, ], c(50, 50, 60, 70, 80, 80))
  expect_equal(x[2, ], c(50, 50, 70, 90, 110, 110))
  expect_identical(p$n_shocks(par), 0L)
  expect_identical(p$n_uniforms(par), 1L)
  pn <- c(par, list(noise = list(phi = 0.5, sigma = 0.1)))
  expect_identical(p$n_shocks(pn), 1L)
  z <- matrix(c(1, -1, 0.5, 0.5), 2, 2)
  xn <- p$simulate(pn, z, matrix(c(0.2, 0.8), 2), 2027:2029, structure(list(), n = 2L))
  base <- p$simulate(par, NULL, matrix(c(0.2, 0.8), 2), 2027:2029, structure(list(), n = 2L))
  expect_identical(xn[, 1], base[, 1])
  dev2 <- 0.1 * z[, 1]
  expect_equal(xn[, 2], base[, 2] * exp(dev2 - 0.01 / 2))
  dev3 <- 0.5 * dev2 + 0.1 * z[, 2]
  expect_equal(xn[, 3], base[, 3] * exp(dev3 - (0.25 * 0.01 + 0.01) / 2))
  # Erwartung = Mischung (Rauschen mit Erwartung 1)
  expect_equal(p$expected(pn, 2027:2029), c(50, 65, 80))
})

test_that("scenario_mix: Quantilpfad ohne und mit Rauschen", {
  p <- wsc_proc("scenario_mix")
  # Szenarien je Jahr nach Wert sortiert (Kreuzung 2030 → 2040)
  par <- list(scenarios = list(a = list(prob = 0.3, years = c(2030, 2040), values = c(10, 100)),
                               b = list(prob = 0.7, years = c(2030, 2040), values = c(50, 60))))
  expect_identical(p$quantile_path(par, c(2030, 2040), 0.2), c(10, 60))
  expect_identical(p$quantile_path(par, c(2030, 2040), 0.3), c(10, 60))
  expect_identical(p$quantile_path(par, c(2030, 2040), 0.5), c(50, 60))
  expect_identical(p$quantile_path(par, c(2030, 2040), 0.8), c(50, 100))
  # mit Rauschen: Nullstelle der Mischverteilungsfunktion
  pn <- c(par, list(noise = list(phi = 0.5, sigma = 0.2)))
  yrs <- 2029:2035
  q <- p$quantile_path(pn, yrs, 0.4)
  v <- 0.2^2 * proc_geo2(0.5, seq_along(yrs) - 1)
  s <- proc_scenarios(pn, yrs)
  for (j in 2:length(yrs)) {
    f <- sum(s$prob * pnorm((log(q[j] / s$paths[, j]) + v[j] / 2) / sqrt(v[j])))
    expect_equal(f, 0.4, tolerance = 1e-8)
  }
  expect_identical(q[1], p$quantile_path(par, yrs, 0.4)[1])
  # monoton in p
  qs <- vapply(c(0.05, 0.3, 0.5, 0.7, 0.95), function(pr) p$quantile_path(pn, yrs, pr)[5], 0)
  expect_true(all(diff(qs) > 0))
})

test_that("scenario_mix: komonotoner Dreieckskorridor mit 20 Quantilpfaden (Konzept B6)", {
  p <- wsc_proc("scenario_mix")
  tri <- wsc_dist("triangular")
  sc <- list()
  for (k in 1:20) {
    sc[[sprintf("q%02d", k)]] <- list(prob = 0.05, years = 2030,
                                      values = tri$quantile((k - 0.5) / 20,
                                                            list(min = 60, mode = 85, max = 110)))
  }
  par <- list(scenarios = sc)
  expect_equal(p$expected(par, 2030), 85, tolerance = 2e-3)
  u <- (seq_len(2000) - 0.5) / 2000
  x <- p$simulate(par, NULL, matrix(u, ncol = 1), 2030, structure(list(), n = 2000L))
  expect_identical(attr(x, "scenario"), rep(1:20, each = 100))
  expect_true(all(diff(as.vector(x)) >= 0))
})

test_that("scenario_mix: Validierung und Vertrag", {
  p <- wsc_proc("scenario_mix")
  expect_identical(p$validate(sm), character(0))
  expect_length(p$validate(list()), 1L)
  bad <- sm
  bad$scenarios$hoch$prob <- 0.5
  expect_length(p$validate(bad), 1L)
  bad2 <- sm
  bad2$scenarios$Hoch <- bad2$scenarios$hoch
  expect_true(length(p$validate(bad2)) >= 1L)
  bad3 <- sm
  bad3$scenarios$mittel$values <- c(1, 2)
  expect_length(p$validate(bad3), 1L)
  bad4 <- sm
  bad4$scenarios$mittel$prob <- list(dist = "uniform", min = 0, max = 1)
  expect_length(p$validate(bad4), 1L)
  expect_length(p$validate(c(sm, list(noise = list(phi = 1, sigma = 0.1)))), 1L)
  noise_dist <- list(phi = 0.5, sigma = list(dist = "uniform", min = 0, max = 0.2))
  expect_identical(p$validate(c(sm, list(noise = noise_dist))), character(0))
  expect_type_contract("scenario_mix", "process")
})
