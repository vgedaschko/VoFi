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

test_that("Iman-Conover bei kleinen Blöcken: singuläres cor(S) wird neu permutiert (C-02)", {
  # m = d + 1 = 3: cor(S) ist singulär, wenn beide Spalten gleich oder gespiegelt permutiert sind
  a <- qnorm(1:3 / 4)
  expect_null(smp_ic_chol(cbind(a, a)))
  expect_null(smp_ic_chol(cbind(a, rev(a))))
  expect_false(is.null(smp_ic_chol(cbind(a, a[c(2, 1, 3)]))))
  # Neupermutation im Unterstrom ic:<key>:<b>:<k>, Versuch 0 = Strom nach Spec 00 11.3
  expect_identical(smp_ic_scores(1, "x", 5L, 3L, 0L), smp_ic_scores(1, "x", 5L, 3L))
  expect_identical(smp_ic_scores(1, "x", 5L, 3L, 2L), with_stream(1, "ic:x:5:2", sample(a)))
  retry <- vapply(1:100, function(b) {
    attr(smp_ic_block_scores(1, c("x", "y"), b, 3L), "retry")
  }, integer(1))
  expect_true(any(retry > 0L))
  b1 <- which(retry > 0L)[1L]
  sc <- smp_ic_block_scores(1, c("x", "y"), b1, 3L)
  expect_false(is.null(smp_ic_chol(sc)))
  expect_identical(unname(sc[, "x"]), smp_ic_scores(1, "x", b1, 3L, retry[b1]))
  expect_identical(sc, smp_ic_block_scores(1, c("x", "y"), b1, 3L))
  # Ziehung mit m = 3 über 100 Blöcke: kein Abbruch, LHS-Schichtung je Block bleibt
  g <- make_grid()
  uni <- function(t) wsc_par(t, "uniform", min = 0, max = 1)
  st <- list(parameters = list(x = uni("shared.x"), y = uni("shared.y")),
             correlations = list(parameters = list(list("x", "y", 0.5))))
  plan <- wsc_plan(st, g, n_sim = 300L, block_size = 3L)
  expect_silent(dr <- smp_draw(plan, g, 1:100, 1))
  strata <- function(v) apply(matrix(ceiling(v * 3), nrow = 3), 2, function(s) all(sort(s) == 1:3))
  expect_true(all(strata(dr$u$x)) && all(strata(dr$u$y)))
  expect_gt(stats::cor(dr$u$x, dr$u$y, method = "spearman"), 0.3)
})

test_that("Iman-Conover: Beispiel F21 (d = 6, replicates 10, n_sim 70, Spec 01 Teil C 1.7.3)", {
  g <- make_grid()
  keys <- paste0("k", 1:6)
  pars <- stats::setNames(lapply(keys, function(k) {
    wsc_par(paste0("shared.", k), "uniform", min = 0, max = 1)
  }), keys)
  pairs <- lapply(1:5, function(i) list(keys[i], keys[i + 1L], 0.4))
  st <- list(parameters = pars, correlations = list(parameters = pairs))
  plan <- smp_plan(wsc_spec(st, g), g)
  plan <- suppressMessages(smp_configure(plan, n_sim = 70L, replicates = 10L))
  expect_identical(plan$settings$replicates, 10L)
  # Seed 21: in mindestens einem Block ist cor(S) zunächst singulär (vor der Korrektur ein
  # roher chol-Fehler)
  retry <- vapply(1:10, function(b) attr(smp_ic_block_scores(21, keys, b, 7L), "retry"),
                  integer(1))
  expect_true(any(retry > 0L))
  expect_silent(dr <- smp_draw(plan, g, 1:10, 21))
  for (k in keys) {
    expect_true(all(apply(matrix(ceiling(dr$u[[k]] * 7), nrow = 7), 2,
                          function(s) all(sort(s) == 1:7))))
  }
})

test_that("Iman-Conover: Rückfall ohne Q^-1 bei dauerhaft singulärem cor(S) mit Warnung", {
  a <- qnorm(1:4 / 5)
  u <- cbind(c(0.1, 0.3, 0.6, 0.9), c(0.2, 0.4, 0.7, 0.8))
  target <- matrix(c(1, 0.5, 0.5, 1), 2)
  expect_warning(res <- smp_iman_conover(u, target, cbind(a, a), block = 7L),
                 class = "vofi_warning_correlation")
  for (j in 1:2) expect_identical(sort(res[, j]), sort(u[, j]))
})

test_that("Mindestblockgröße: Vorschlag je Modus (Spec 01 Teil C 1.7.3, C-07)", {
  e <- tryCatch(smp_check_block_size(2L, 2L), error = identity)
  expect_s3_class(e, "vofi_error_input")
  expect_match(conditionMessage(e), "block_size >= 3", fixed = TRUE)
  e2 <- tryCatch(smp_check_block_size(6L, 6L, replicates = 10L), error = identity)
  expect_s3_class(e2, "vofi_error_input")
  expect_match(conditionMessage(e2), "n_sim >= 70", fixed = TRUE)
  expect_false(grepl("block_size >=", conditionMessage(e2), fixed = TRUE))
  # F21-Modus über smp_configure(): n_sim zu klein für die Gruppe
  g <- make_grid()
  uni <- function(t) wsc_par(t, "uniform", min = 0, max = 1)
  st <- list(parameters = list(x = uni("shared.x"), y = uni("shared.y")),
             correlations = list(parameters = list(list("x", "y", 0.5))))
  plan <- smp_plan(wsc_spec(st, g), g)
  e3 <- tryCatch(suppressMessages(smp_configure(plan, n_sim = 20L, replicates = 10L)),
                 error = identity)
  expect_s3_class(e3, "vofi_error_input")
  expect_match(conditionMessage(e3), "n_sim >= 30", fixed = TRUE)
})
