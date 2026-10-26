# Tests für R/sampling-dependence.R (WS-C; Spec 00 11.6, R-38; Spec 01 Teil C 1.7).

test_that("Spearman -> Pearson: ρ = 2 sin(π ρ_S / 6) (Spec 01 Teil C 1.7.2)", {
  expect_spec(smp_spearman_to_pearson(c(0.3, 0.5, 0.7, 0.8, 0.9)),
              c("0.31286893", "0.51763809", "0.7167359", "0.81347329", "0.907981"))
  m <- smp_spearman_to_pearson(matrix(c(1, 0.5, 0.5, 1), 2))
  expect_identical(diag(m), c(1, 1))
})

test_that("Reparatur nicht positiv definiter Matrizen (Prüffall Memo 04 §3.3)", {
  keys <- c("a", "b", "c")
  rs <- matrix(c(1, 0.9, -0.6, 0.9, 1, 0.2, -0.6, 0.2, 1), 3, dimnames = list(keys, keys))
  p <- smp_spearman_to_pearson(rs)
  expect_spec(p[upper.tri(p)], c("0.907981", "-0.618034", "0.209057"))
  expect_spec(eigen(p, symmetric = TRUE)$values, c("2.0087", "1.1935", "-0.2022"))
  expect_warning(fix <- smp_near_pd(p), class = "vofi_warning_correlation")
  expect_true(fix$repaired)
  expect_spec(fix$matrix[upper.tri(fix$matrix)], c("0.766160", "-0.522453", "0.147684"))
  expect_spec(fix$max_dev, "0.14182")
  expect_identical(unname(diag(fix$matrix)), c(1, 1, 1))
  expect_identical(dimnames(fix$matrix), dimnames(p))
  expect_true(all(eigen(fix$matrix, symmetric = TRUE)$values > 0))
  expect_silent(chol(fix$matrix))
  # ohne Pearson-Umrechnung (Memo 04): (0,772317; -0,515891; 0,145746)
  raw <- suppressWarnings(smp_near_pd(rs))
  expect_spec(raw$matrix[upper.tri(raw$matrix)], c("0.772317", "-0.515891", "0.145746"))
  # positiv definit: unverändert, keine Warnung
  ok <- matrix(c(1, 0.5, 0.5, 1), 2)
  expect_silent(r <- smp_near_pd(ok))
  expect_false(r$repaired)
  expect_identical(r$matrix, ok)
  # kleine Reparatur ohne Warnung (|ρ| = 1 wird repariert)
  one <- matrix(c(1, 1, 1, 1), 2)
  expect_silent(r1 <- smp_near_pd(one))
  expect_true(r1$repaired && r1$max_dev < 0.05)
  expect_silent(chol(r1$matrix))
})

test_that("Iman-Conover je Block: Ränder exakt erhalten, Rangkorrelation getroffen", {
  m <- 2000L
  keys <- c("a", "b", "c")
  target <- smp_spearman_to_pearson(matrix(c(1, 0.5, -0.3, 0.5, 1, 0.2, -0.3, 0.2, 1), 3,
                                           dimnames = list(keys, keys)))
  u <- vapply(keys, function(k) smp_uniforms(4711, paste0("par:", k, ":1"), m, "lhs"),
              numeric(m))
  sc <- vapply(keys, function(k) smp_ic_scores(4711, k, 1L, m), numeric(m))
  res <- smp_iman_conover(u, target, sc)
  for (j in 1:3) expect_identical(sort(res[, j]), sort(u[, j]))
  rho <- stats::cor(res, method = "spearman")
  expect_lt(max(abs(rho - c(1, 0.5, -0.3, 0.5, 1, 0.2, -0.3, 0.2, 1))), 0.03)
  # T = S Q^-1 P hat exakt die Zielkorrelation
  q <- chol(stats::cor(sc))
  tm <- sc %*% backsolve(q, diag(3)) %*% chol(target)
  expect_equal(unname(stats::cor(tm)), unname(target), tolerance = 1e-10)
})

test_that("Gauß-Copula, Schockkorrelation und Mindestblockgröße", {
  m <- 5000L
  target <- matrix(c(1, 0.6, 0.6, 1), 2)
  u <- cbind(smp_uniforms(1, "par:a:1", m, "lhs"), smp_uniforms(1, "par:b:1", m, "lhs"))
  g <- smp_gauss_copula(u, target)
  expect_true(all(g > 0 & g < 1))
  expect_lt(abs(stats::cor(qnorm(g))[1, 2] - 0.6), 0.03)
  z <- list(x = smp_shocks(1, "shock:x:1", m, 3L, "pseudo"),
            y = smp_shocks(1, "shock:y:1", m, 3L, "pseudo"))
  zt <- matrix(c(1, 0.4, 0.4, 1), 2, dimnames = list(c("x", "y"), c("x", "y")))
  zc <- smp_correlate_shocks(z, zt)
  expect_identical(zc$x, z$x)
  for (j in 1:3) expect_lt(abs(stats::cor(zc$x[, j], zc$y[, j]) - 0.4), 0.05)
  expect_identical(smp_correlate_shocks(list(x = matrix(0, 4, 0), y = matrix(0, 4, 0)), zt)$x,
                   matrix(0, 4, 0))
  expect_error(smp_check_block_size(12L, 12L), class = "vofi_error_input")
  expect_silent(smp_check_block_size(13L, 12L))
  expect_error(smp_check_block_size(1L, 0L), class = "vofi_error_input")
})
