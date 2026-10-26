# Tests für R/mc-stats.R (WS-G; Spec 00 Abschnitte 11.4, 12.7, 13.2; Spec 01 Teil C 6.1, 6.3).

test_that("Prüffall Teil C 6.3: x = (-3, -1, 0, 2, 4, 5, 7, 8, 10, 12), Blockgröße 5", {
  x <- c(-3, -1, 0, 2, 4, 5, 7, 8, 10, 12)
  kp <- data.frame(sim = 1:10, block = rep(1:2, each = 5L), x = x)
  st <- mc_stats(kp)
  expect_identical(names(st), mc_stat_columns())
  expect_identical(st$kpi, "x")
  expect_equal(st$mean, 4.4, tolerance = 1e-12)
  expect_equal(st$sd, 4.926121, tolerance = 1e-6)
  # Blockmittel 0,4 / 8,4 -> se = sd(c(0.4, 8.4)) / sqrt(2) = 4,0; naiv 1,557776
  expect_equal(st$se, 4.0, tolerance = 1e-12)
  expect_equal(stats::sd(x) / sqrt(10), 1.557776, tolerance = 1e-6)
  expect_identical(st$se_df, 1L)
  expect_equal(unlist(st[, c("q05", "q10", "q25", "q50", "q75", "q90", "q95")]),
               c(q05 = -2.1, q10 = -1.2, q25 = 0.5, q50 = 4.5, q75 = 7.75, q90 = 10.2,
                 q95 = 11.1), tolerance = 1e-12)
  expect_equal(st$p_neg, 0.2, tolerance = 1e-12)
  expect_equal(st$p_neg_se, 0.2, tolerance = 1e-12)
  expect_equal(st$es05, -3, tolerance = 1e-12)
  expect_equal(st$expected_loss, 0.4, tolerance = 1e-12)
  expect_identical(st$na_share, 0)
  expect_identical(st$n_valid, 10L)
  expect_false(st$converged)
  ci <- mc_mean_ci(st$mean, st$se, st$se_df)
  expect_equal(stats::qt(0.975, 1), 12.7062, tolerance = 1e-5)
  expect_equal(unname(ci[1, ]), c(-46.42, 55.22), tolerance = 1e-3)
})

test_that("R = 1: naive Formel sd/sqrt(n), se_df = 0; NA-Anteil und gültige Läufe", {
  x <- c(1, 2, NA, 4, 5)
  kp <- data.frame(sim = 1:5, block = 1L, x = x, y = NA_real_)
  st <- mc_stats(kp, deterministic = data.frame(x = 3, y = 7))
  r <- st[st$kpi == "x", ]
  expect_equal(r$se, stats::sd(c(1, 2, 4, 5)) / 2, tolerance = 1e-12)
  expect_identical(r$se_df, 0L)
  expect_equal(r$na_share, 0.2)
  expect_identical(r$n_valid, 4L)
  expect_equal(r$p_neg_se, 0)
  expect_identical(r$deterministic, 3)
  ry <- st[st$kpi == "y", ]
  expect_true(is.na(ry$mean))
  expect_identical(ry$na_share, 1)
  expect_identical(ry$n_valid, 0L)
  expect_identical(ry$deterministic, 7)
  expect_false(ry$converged)
})

test_that("Konvergenzausweis (R-97, R-101): R >= 10 und beide Halbbreiten unter der Schwelle", {
  set.seed(1)
  n <- 2000L
  x <- 1000 + stats::rnorm(n)
  blk <- rep(seq_len(20L), each = 100L)
  st <- mc_stats(data.frame(sim = seq_len(n), block = blk, x = x))
  expect_true(st$converged)
  tq <- stats::qt(0.975, 19)
  expect_lt(tq * st$se / abs(st$mean), 0.005)
  # weniger als 10 Blöcke: nie konvergiert ("grob")
  st9 <- mc_stats(data.frame(sim = seq_len(900L), block = rep(1:9, each = 100L),
                             x = x[seq_len(900L)]))
  expect_false(st9$converged)
  # strengere Schwelle für die Wahrscheinlichkeit: nicht konvergiert
  y <- stats::rnorm(n)
  sty <- mc_stats(data.frame(sim = seq_len(n), block = blk, y = y))
  expect_false(sty$converged)
  sty2 <- mc_stats(data.frame(sim = seq_len(n), block = blk, y = y),
                   convergence = list(rel_halfwidth_mean = 1e6, abs_halfwidth_prob = 1))
  expect_true(sty2$converged)
  expect_false(mc_converged(0, 0.1, 0.01, 20L))
})

test_that("0/1-Kennzahlen: Anteil mit Standardfehler aus den Blockanteilen", {
  v <- c(rep(c(1, 0, 0, 0), 25L), rep(c(1, 1, 0, 0), 25L))
  st <- mc_stats(data.frame(sim = 1:200, block = rep(1:2, each = 100L), r = v))
  expect_equal(st$mean, 0.375)
  expect_equal(st$se, stats::sd(c(0.25, 0.5)) / sqrt(2))
  expect_identical(st$p_neg, 0)
})

test_that("Spaltenauswahl, Spalten sim/block/branch werden übergangen, leere Eingabe", {
  kp <- data.frame(sim = 1:4, block = 1L, branch = c(1L, 0L, 1L, 0L), a = 1:4,
                   lab = letters[1:4], stringsAsFactors = FALSE)
  st <- mc_stats(kp)
  expect_identical(st$kpi, "a")
  st0 <- mc_stats(kp, cols = character(0))
  expect_identical(nrow(st0), 0L)
  expect_identical(names(st0), mc_stat_columns())
  expect_error(mc_stats(1:3), class = "vofi_error_input")
  expect_error(mc_stats(kp, block = 1:2), class = "vofi_error_input")
})

test_that("Quantil-Konfidenzintervall über Ordnungsstatistiken (Memo 04 4.4)", {
  x <- c(5, 1, 4, 2, 3, NA)
  ci <- mc_quantile_ci(x, 0.5)
  xs <- sort(x)
  expect_identical(unname(ci), c(xs[max(1L, stats::qbinom(0.025, 5, 0.5))],
                                 xs[min(5L, stats::qbinom(0.975, 5, 0.5) + 1L)]))
  expect_identical(unname(mc_quantile_ci(numeric(0), 0.5)), c(NA_real_, NA_real_))
  set.seed(2)
  y <- stats::runif(10000)
  ci95 <- mc_quantile_ci(y, 0.95, level = 0.999)
  expect_true(ci95[["lo"]] <= 0.95 && 0.95 <= ci95[["hi"]])
  expect_lt(ci95[["hi"]] - ci95[["lo"]], 0.02)
})

test_that("Verteilungsfunktion aus der Quantilfunktion (Überschreitungswahrscheinlichkeit)", {
  par <- list(min = 30000, mode = 40000, max = 50000)
  p <- mc_cdf("triangular", par, 36273.593021202847)
  expect_equal(p, 6273.593021202847^2 / (20000 * 10000), tolerance = 1e-10)
  expect_identical(mc_cdf("triangular", par, c(20000, 60000)), c(0, 1))
  expect_equal(mc_cdf("uniform", list(min = 0, max = 2), 0.5), 0.25, tolerance = 1e-12)
  expect_true(is.na(mc_cdf("uniform", list(min = 0, max = 2), NA)))
})
