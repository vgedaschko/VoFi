# Tests für R/process-mr-trend.R (WS-C; Spec 01 Teil C 1.6.4, 2.4, 4.3 Nr. 1 c).

yrs <- 2027:2067

#' E[P_y] bei g ~ N(gbar, sd): p̄ E[(1 + g)^{y−1}] (p0/p̄)^{φ^{y−1}} (numerisch integriert)
mr_mean_uncertain <- function(p0, pbar, phi, gbar, gsd, y) {
  k <- y - 1
  eg <- vapply(k, function(kk) {
    stats::integrate(function(g) (1 + g)^kk * dnorm(g, gbar, gsd), -1, 1, rel.tol = 1e-12)$value
  }, numeric(1))
  out <- pbar * eg * (p0 / pbar)^(phi^k)
  out[k == 0] <- p0
  out
}

test_that("mr_trend: Prüffälle der Bibliothek energy_prices_mr_2026 (E[P_y] und E[P_31] | ḡ)", {
  p <- wsc_proc("mr_trend")
  cases <- list(
    c(0.06329700, 0.05949660, 0.75, 0.08, 0.02, 0.01, 0.06357122, 0.06672547, 0.07309457,
      0.11235976, 0.10777105),
    c(0.06042243, 0.05691600, 0.75, 0.08, 0.02, 0.01, 0.06071659, 0.06379900, 0.06991576,
      0.10748624, 0.10309656),
    c(0.09076136, 0.06857460, 0.70, 0.18, 0.02, 0.012, 0.08510985, 0.07947406, 0.08478237,
      0.13189142, 0.12421418),
    c(0.07061172, 0.06257143, 0.70, 0.15, 0.02, 0.012, 0.06945872, 0.07059949, 0.07701274,
      0.12034492, 0.11333979),
    c(0.31816764, 0.30857040, 0.75, 0.04, 0.02, 0.007, 0.32205552, 0.34333351, 0.37759403,
      0.57048917, 0.55893563),
    c(0.27260262, 0.26437981, 0.75, 0.04, 0.02, 0.007, 0.27593371, 0.29416447, 0.32351851,
      0.48878899, 0.47889004),
    c(0.22068358, 0.21428160, 0.75, 0.05, 0.02, 0.007, 0.22344668, 0.23835497, 0.26219635,
      0.39616666, 0.38814350),
    c(0.21210671, 0.20571360, 0.75, 0.05, 0.02, 0.007, 0.21469985, 0.22888771, 0.25172901,
      0.38032611, 0.37262375),
    c(0.13331778, 0.12920125, 0.80, 0.07, 0.025, 0.008, 0.13579622, 0.14777943, 0.16640173,
      0.27828370, 0.27101888),
    c(0.06774348, 0.06029412, 0.60, 0.09, 0.025, 0.008, 0.06627570, 0.06887995, 0.07744786,
      0.12986112, 0.12647099),
    c(0.0613, 0.0613, 0.75, 0.08, 0.02, 0.01, 0.06252600, 0.06774521, 0.07504800,
      0.11576421, 0.11103647)
  )
  for (cs in cases) {
    par <- list(p0 = cs[1], p_norm = cs[2], phi = cs[3], sigma = cs[4], growth = cs[5])
    e_unc <- mr_mean_uncertain(cs[1], cs[2], cs[3], cs[5], cs[6], c(2, 6, 11, 31))
    expect_equal(e_unc, cs[7:10], tolerance = 3e-7)
    expect_equal(p$expected(par, yrs)[31], cs[11], tolerance = 1e-7)
    # Verteilter Trend: expected() mit Punktparametern (point(…, "mean"), Spec 01 Teil C 1.5.3)
    pg <- utils::modifyList(par, list(growth = list(dist = "normal", mean = cs[5], sd = cs[6])))
    expect_equal(p$expected(pg, yrs), p$expected(par, yrs), tolerance = 1e-15)
  }
})

test_that("mr_trend: Konsistenz Basisfall (Gas, E[P_11] | ḡ = det(2037)) und Quantilpfad v2", {
  p <- wsc_proc("mr_trend")
  par <- list(p0 = 0.063297, p_norm = 0.0594966, phi = 0.75, sigma = 0.08, growth = 0.02)
  expect_spec(p$expected(par, yrs)[11], "0.07277935")
  q <- vapply(c(0.1, 0.5, 0.9), function(pr) p$quantile_path(par, yrs, pr)[11], 0)
  expect_spec(q, c("0.06189165", "0.07225064", "0.08434345"))
  expect_identical(p$quantile_path(par, yrs, 0.2)[1], 0.063297)
  # Variationskoeffizient des Rauschens stationär (φ = 0,75, σ = 0,08)
  expect_equal(sqrt(exp(0.08^2 / (1 - 0.75^2)) - 1), 0.12139231, tolerance = 1e-8)
  # p_norm = p0 (Default) ergibt die Formel aus Spec 00 11.7
  d <- list(p0 = 0.0613, phi = 0.75, sigma = 0.08, growth = 0.02)
  expect_equal(p$expected(d, yrs), 0.0613 * 1.02^(seq_along(yrs) - 1), tolerance = 1e-14)
})

test_that("mr_trend: Simulation (Spalte 1 = p0, Mittel = Erwartung, Prototyp E[P_41])", {
  p <- wsc_proc("mr_trend")
  n <- 20000L
  z <- smp_shocks(7, "shock:gas:1", n, 40L, "lhs")
  par <- list(p0 = 0.063297, p_norm = 0.0594966, phi = 0.75, sigma = 0.08, growth = 0.02)
  x <- p$simulate(par, z, NULL, yrs, structure(list(), n = n))
  expect_identical(x[, 1], rep(0.063297, n))
  e <- p$expected(par, yrs)
  se <- apply(x, 2, stats::sd) / sqrt(n)
  expect_true(all(abs(colMeans(x) - e) <= 4 * se + 1e-15))
  # Prototyp Memo 04 §10.3: p0 = 0,10, g ~ N(0,02; 0,01) -> E[P_41] = 0,238
  g <- 0.02 + 0.01 * qnorm((seq_len(n) - 0.5) / n)
  x2 <- p$simulate(list(p0 = 0.10, phi = 0.75, sigma = 0.08, growth = g), z, NULL, yrs,
                   structure(list(), n = n))
  expect_equal(mean(x2[, 41]), 0.238, tolerance = 0.01)
})

test_that("mr_trend: Validierung und Vertrag", {
  p <- wsc_proc("mr_trend")
  ok <- list(p0 = "base", p_norm = "base", phi = 0.75, sigma = 0.08, growth = 0.02)
  expect_identical(p$validate(ok), character(0))
  expect_length(p$validate(utils::modifyList(ok, list(p0 = -1))), 1L)
  expect_length(p$validate(utils::modifyList(ok, list(growth = -1))), 1L)
  expect_length(p$validate(utils::modifyList(ok, list(phi = -1))), 1L)
  mod <- function(...) utils::modifyList(ok, list(...))
  expect_length(p$validate(mod(p0 = list(dist = "normal", mean = 0.06, sd = 0.01))), 1L)
  expect_identical(p$validate(mod(p0 = list(dist = "lognormal", median = 0.06, p90 = 0.08))),
                   character(0))
  expect_identical(p$validate(mod(growth = list(dist = "normal", mean = 0.02, sd = 0.01))),
                   character(0))
  expect_type_contract("mr_trend", "process")
})
