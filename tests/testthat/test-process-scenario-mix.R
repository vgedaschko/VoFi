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

test_that("scenario_mix: Prüffall v4 CO2-Korridor 2030 (Spec 01 Teil C 4.3, 2.5)", {
  p <- wsc_proc("scenario_mix")
  # processes/co2_price_corridor_2026: 20 gleichgewichtige Quantilpfade q01-q20
  yrs <- c(2026, 2027, 2028, 2030, 2032, 2035, 2040, 2045, 2050, 2060, 2070)
  co2 <- rbind(
    c(65.00, 57.50, 49.33, 60.92, 68.44, 88.11,
      117.50, 142.75, 168.00, 204.79, 249.63),
    c(65.00, 59.33, 52.50, 65.25, 74.62, 97.71,
      130.31, 159.40, 188.49, 229.77, 280.09),
    c(65.00, 60.59, 54.68, 68.23, 78.87, 104.32,
      139.13, 170.87, 202.60, 246.97, 301.05),
    c(65.00, 61.61, 56.46, 70.65, 82.33, 109.69,
      146.30, 180.19, 214.07, 260.95, 318.10),
    c(65.00, 62.50, 57.99, 72.75, 85.32, 114.33,
      152.50, 188.25, 223.99, 273.04, 332.83),
    c(65.00, 63.29, 59.36, 74.62, 88.00, 118.48,
      158.04, 195.45, 232.85, 283.84, 346.00),
    c(65.00, 64.01, 60.63, 76.39, 90.44, 122.27,
      163.10, 202.02, 240.94, 293.70, 358.02),
    c(65.00, 64.68, 61.93, 78.23, 92.88, 125.78,
      167.78, 208.11, 248.43, 302.83, 369.15),
    c(65.00, 65.32, 63.28, 80.14, 95.41, 129.05,
      172.21, 213.93, 255.65, 311.64, 379.89),
    c(65.00, 65.97, 64.69, 82.13, 98.06, 132.22,
      176.78, 219.98, 263.18, 320.82, 391.08),
    c(65.00, 66.65, 66.17, 84.23, 100.84, 135.53,
      181.58, 226.33, 271.08, 330.45, 402.81),
    c(65.00, 67.38, 67.73, 86.43, 103.77, 139.02,
      186.63, 233.02, 279.41, 340.60, 415.19),
    c(65.00, 68.14, 69.38, 88.77, 106.88, 142.72,
      191.99, 240.11, 288.24, 351.36, 428.31),
    c(65.00, 68.96, 71.15, 91.27, 110.20, 146.67,
      197.72, 247.70, 297.68, 362.88, 442.34),
    c(65.00, 69.84, 73.06, 93.98, 113.79, 150.95,
      203.91, 255.90, 307.89, 375.31, 457.50),
    c(65.00, 70.81, 75.16, 96.94, 117.73, 155.63,
      210.70, 264.88, 319.07, 388.94, 474.12),
    c(65.00, 71.90, 77.50, 100.25, 122.13, 160.87,
      218.29, 274.93, 331.58, 404.19, 492.70),
    c(65.00, 73.15, 80.21, 104.08, 127.22, 166.93,
      227.07, 286.56, 346.04, 421.82, 514.20),
    c(65.00, 74.70, 83.54, 108.80, 133.48, 174.38,
      237.88, 300.86, 363.84, 443.52, 540.65),
    c(65.00, 76.94, 88.39, 115.65, 142.58, 185.21,
      253.57, 321.63, 389.69, 475.03, 579.06)
  )
  sc <- list()
  for (k in 1:20) sc[[sprintf("q%02d", k)]] <- list(prob = 0.05, years = yrs, values = co2[k, ])
  par <- list(scenarios = sc)
  expect_spec(p$quantile_path(par, 2030, 0.1), "65.25")
  expect_spec(p$quantile_path(par, 2030, 0.9), "104.08")
  q <- vapply(c(0.1, 0.9), function(pr) p$quantile_path(par, 2027:2040, pr)[c(4, 14)],
              numeric(2))
  expect_spec(q[1, ], c("65.25", "104.08"))
  expect_spec(q[2, ], c("130.31", "227.07"))
  # Erwartungspfad (notes der Bibliothek): 84,99 in 2030, 181,65 in 2040
  expect_spec(p$expected(par, c(2030, 2040)), c("84.99", "181.65"))
})

test_that("scenario_mix: empirische Quantile der Mischung mit Rauschen = quantile_path (P4)", {
  p <- wsc_proc("scenario_mix")
  par <- list(scenarios = list(a = list(prob = 0.2, years = c(2027, 2031), values = c(50, 40)),
                               b = list(prob = 0.5, years = c(2027, 2031), values = c(60, 90)),
                               c = list(prob = 0.3, years = c(2027, 2031), values = c(70, 200))),
              noise = list(phi = 0.5, sigma = 0.15))
  n <- 20000L
  yrs <- 2027:2031
  z <- smp_shocks(5, "shock:co2:1", n, length(yrs) - 1L, "lhs")
  u <- matrix(smp_uniforms(5, "scen:co2:1", n, "lhs"), ncol = 1L)
  x <- p$simulate(par, z, u, yrs, structure(list(), n = n))
  for (pr in c(0.05, 0.25, 0.5, 0.75, 0.95)) {
    q <- p$quantile_path(par, yrs, pr)
    for (j in seq_along(yrs)) expect_quantile_near(x[, j], q[j], pr, info = yrs[j])
  }
})

test_that("scenario_mix: Quantilpfad mit Rauschen bei Szenariowerten 0 und < 0 (C-03)", {
  p <- wsc_proc("scenario_mix")
  # Prüffall des Reviews: a (0,5; Wert 0), b (0,5; Wert 10), Rauschen phi 0, sigma 0,1
  par <- list(scenarios = list(a = list(prob = 0.5, years = 2027, values = 0),
                               b = list(prob = 0.5, years = 2027, values = 10)),
              noise = list(phi = 0, sigma = 0.1))
  q <- p$quantile_path(par, 2026:2028, 0.7)
  expect_identical(q[1], 10)
  expect_equal(q[2:3], rep(10 * exp(-0.005 + stats::qnorm(0.4) * 0.1), 2), tolerance = 1e-9)
  # Punktmasse in 0: Quantile p <= 0,5 sind 0
  expect_identical(p$quantile_path(par, 2026:2028, 0.3), c(0, 0, 0))
  expect_identical(p$quantile_path(par, 2026:2028, 0.5)[2], 0)
  # Mischung mit negativem, null und positivem Wert gegen die Simulation
  pm <- list(scenarios = list(m = list(prob = 0.3, years = c(2027, 2030), values = c(-5, -20)),
                              n = list(prob = 0.2, years = c(2027, 2030), values = c(0, 0)),
                              p = list(prob = 0.5, years = c(2027, 2030), values = c(5, 30))),
             noise = list(phi = 0.6, sigma = 0.2))
  n <- 20000L
  yrs <- 2027:2030
  z <- smp_shocks(8, "shock:abg:1", n, length(yrs) - 1L, "lhs")
  u <- matrix(smp_uniforms(8, "scen:abg:1", n, "lhs"), ncol = 1L)
  x <- p$simulate(pm, z, u, yrs, structure(list(), n = n))
  for (pr in c(0.05, 0.2, 0.3, 0.4, 0.5, 0.6, 0.95)) {
    q <- p$quantile_path(pm, yrs, pr)
    expect_true(all(is.finite(q)))
    for (j in seq_along(yrs)) expect_quantile_near(x[, j], q[j], pr, info = yrs[j])
  }
  qs <- vapply(c(0.05, 0.25, 0.45, 0.75, 0.95), function(pr) p$quantile_path(pm, yrs, pr)[3], 0)
  expect_true(all(diff(qs) >= 0))
  expect_identical(qs[3], 0)
})
