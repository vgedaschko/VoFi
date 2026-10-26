# Tests für R/process-iid.R (WS-C; Spec 01 Teil C 1.6.7, 4.3 Prüffall v5).

ds <- list(dist_spec = list(dist = "pert", min = 0.5, mode = 1.0, max = 2.0))

test_that("iid: Prüffall PERT(0,5; 1; 2) (Spalte 1 = Mittel, Spaltenmittel ab y = 2)", {
  p <- wsc_proc("iid")
  n <- 20000L
  z <- smp_shocks(11, "shock:vac:1", n, 5L, "lhs")
  x <- p$simulate(ds, z, NULL, 2027:2032, structure(list(), n = n))
  expect_equal(x[, 1], rep(1.0833333, n), tolerance = 1e-7)
  sd_th <- sqrt(wsc_dist("pert")$moments(ds$dist_spec)$var)
  for (j in 2:6) expect_lt(abs(mean(x[, j]) - 1.0833333), 4 * sd_th / sqrt(n))
  e_pert <- wsc_dist("pert")$point(ds$dist_spec, "mean")
  expect_identical(p$expected(ds, 2027:2032), rep(e_pert, 6L))
  expect_true(all(x >= 0.5 & x <= 2))
})

test_that("iid: Quantilpfad (Prüffall v5) und Bernoulli-Jahresverteilung", {
  p <- wsc_proc("iid")
  expect_spec(p$quantile_path(ds, 2027:2029, 0.1), c("1.0833333", "0.72954154", "0.72954154"))
  expect_spec(p$quantile_path(ds, 2027:2029, 0.9), c("1.0833333", "1.46668505", "1.46668505"))
  expect_length(p$quantile_path(ds, 2027L, 0.9), 1L)
  b <- list(dist_spec = list(dist = "bernoulli", p = 0.3))
  x <- p$simulate(b, matrix(c(-3, 3), 2, 1), NULL, 2027:2028, structure(list(), n = 2L))
  expect_identical(x, matrix(c(0.3, 0.3, 0, 1), 2, 2))
  # extreme Schocks bleiben endlich (Uniform von 0 und 1 weg begrenzt)
  nrm <- list(dist_spec = list(dist = "normal", mean = 1, sd = 0.1))
  xe <- p$simulate(nrm, matrix(c(-40, 40), 2, 1), NULL, 2027:2028, structure(list(), n = 2L))
  expect_true(all(is.finite(xe)))
})

test_that("iid: Validierung und Vertrag", {
  p <- wsc_proc("iid")
  expect_identical(p$validate(ds), character(0))
  expect_length(p$validate(list()), 1L)
  expect_length(p$validate(list(dist_spec = list(dist = "gibtsnicht"))), 1L)
  expect_length(p$validate(list(dist_spec = list(dist = "pert", min = 2, mode = 1, max = 3))),
                1L)
  nested <- list(dist = "normal", mean = list(dist = "normal", mean = 0, sd = 1), sd = 1)
  expect_length(p$validate(list(dist_spec = nested)), 1L)
  expect_true(all(is.na(p$expected(list(), 2027:2028))))
  expect_true(all(is.na(p$quantile_path(list(), 2027:2028, 0.5))))
  expect_error(p$simulate(list(), NULL, NULL, 2027:2028, structure(list(), n = 1L)),
               class = "vofi_error_contract")
  expect_type_contract("iid", "process")
})

test_that("iid: empirische Jahresquantile der Simulation = quantile_path (PERT(0,5; 1; 2), P4)", {
  p <- wsc_proc("iid")
  n <- 20000L
  yrs <- 2027:2031
  z <- smp_shocks(13, "shock:vac:1", n, length(yrs) - 1L, "lhs")
  x <- p$simulate(ds, z, NULL, yrs, structure(list(), n = n))
  for (pr in c(0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95)) {
    q <- p$quantile_path(ds, yrs, pr)
    expect_identical(q[1], x[1, 1])
    for (j in 2:length(yrs)) expect_quantile_near(x[, j], q[j], pr, info = yrs[j])
  }
})
