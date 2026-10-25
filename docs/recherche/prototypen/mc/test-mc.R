library(testthat)
source("mc_core.R"); source("mc_engine.R")
seed <- 4711; N <- 20000

test_that("Momente der Verteilungen liegen im Toleranzband (4 SE)", {
  u <- draw_u(N, seed, "t1", "pseudo")
  x <- q_pert(u, 0.95, 1.05, 1.40)
  m_th <- (0.95 + 4 * 1.05 + 1.40) / 6
  a <- 1 + 4 * (1.05 - 0.95) / 0.45; b <- 1 + 4 * (1.40 - 1.05) / 0.45
  sd_th <- 0.45 * sqrt(a * b / ((a + b)^2 * (a + b + 1)))
  expect_lt(abs(mean(x) - m_th), 4 * sd_th / sqrt(N))
  expect_lt(abs(sd(x) / sd_th - 1), 0.03)
  x <- q_triangular(u, 0, 3, 12)
  expect_lt(abs(mean(x) - 5), 4 * sqrt((0 + 9 + 144 - 0 - 0 - 36) / 18) / sqrt(N))
  p <- lnorm_par(mean = 1.1, sd = 0.1); x <- qlnorm(u, p[1], p[2])
  expect_lt(abs(mean(x) - 1.1), 4 * 0.1 / sqrt(N))
  expect_gt(ks.test(q_truncnorm(u, 0, 1, -1, 2), function(q) (pnorm(q) - pnorm(-1)) / (pnorm(2) - pnorm(-1)))$p.value, 1e-3)
})

test_that("LHS ist je Spalte exakt stratifiziert", {
  u <- draw_u(1000, seed, "lhs", "lhs")
  expect_equal(sort(floor(u * 1000)), 0:999)
})

test_that("Rangkorrelation wird reproduziert, Randverteilungen bleiben erhalten (Iman-Conover)", {
  R <- matrix(c(1, .5, -.3, .5, 1, .2, -.3, .2, 1), 3)
  X <- cbind(q_pert(draw_u(N, seed, "a", "lhs"), 0, 1, 5), qexp(draw_u(N, seed, "b", "lhs")), draw_u(N, seed, "c", "lhs"))
  Y <- iman_conover(X, R, seed)
  expect_lt(max(abs(cor(Y, method = "spearman") - R)), 0.02)
  for (j in 1:3) expect_identical(sort(Y[, j]), sort(X[, j]))
})

test_that("Nearest-PD liefert gültige Korrelationsmatrix", {
  Rb <- matrix(c(1, .9, -.6, .9, 1, .2, -.6, .2, 1), 3)
  R2 <- near_pd_corr(Rb)
  expect_true(all(eigen(R2, symmetric = TRUE)$values > 0)); expect_equal(diag(R2), rep(1, 3))
  expect_silent(chol(R2))
})

test_that("Seeds: gleiche Ergebnisse bei gleichem Seed, Unabhängigkeit von Zusatzparametern", {
  expect_identical(draw_u(10, seed, "x"), draw_u(10, seed, "x"))
  expect_false(identical(draw_u(10, seed, "x"), draw_u(10, seed + 1, "x")))
  set.seed(1); a <- runif(1); set.seed(1); invisible(draw_u(5, seed, "y")); expect_identical(runif(1), a)
})

test_that("Prozesse: Vasicek-Erwartung, AR(1)-Stationarität, Floor", {
  Z <- draw_shocks(N, 30, seed, "r")
  r <- sim_vasicek(Z, 0.05, 0.03, 0.2, 0.005)
  expect_lt(abs(mean(r[, 5]) - (0.03 + 0.02 * exp(-1))), 4 * sd(r[, 5]) / sqrt(N))
  expect_true(all(sim_vasicek(Z, 0.01, 0.01, 0.1, 0.02, floor = 0) >= 0))
  g <- sim_ar1(Z, 0.02, 0.6, 0.01)
  expect_lt(abs(sd(g[, 30]) / (0.01 / sqrt(1 - 0.36)) - 1), 0.03)
  expect_lt(abs(cor(g[, 29], g[, 30]) - 0.6), 0.03)
  P <- sim_gbm(Z, 1, 0.02, 0.1); expect_lt(abs(mean(P[, 30]) / 1.02^30 - 1), 4 * sd(P[, 30]) / sqrt(N) / 1.02^30)
})

test_that("Degenerierte Verteilungen => Ergebnis = deterministische Rechnung (N = 1)", {
  scd <- gen_scenarios(50, 40, seed, degenerate = TRUE)
  k <- vofi_engine(scd, par_default)$kpi
  k1 <- vofi_engine(lapply(scd, function(x) if (is.matrix(x)) x[1, , drop = FALSE] else x[1]), par_default)$kpi
  expect_true(all(vapply(k, function(v) length(unique(v)) == 1, logical(1))))
  expect_equal(k[1, ], k1, ignore_attr = TRUE, tolerance = 1e-10)
})

test_that("VoFi-Invarianten: Finanzierungssaldo = 0, nie gleichzeitig Anlage und Kontokorrent", {
  sc <- gen_scenarios(500, 40, seed, "lhs")
  f <- vofi_engine(sc, par_default, "full")$full
  expect_lt(max(abs(f$finanzierungssaldo)), 1e-6)
  expect_false(any(f$bestand_ga > 0 & f$bestand_kk > 0))
})

test_that("CRN: identische Varianten haben Differenz exakt 0", {
  sc <- gen_scenarios(500, 40, seed, "lhs")
  expect_identical(vofi_engine(sc, par_default)$kpi$endwert - vofi_engine(sc, par_default)$kpi$endwert, rep(0, 500))
})
