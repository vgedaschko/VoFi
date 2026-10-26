# Tests für R/process-linked-ar1.R (WS-C; Spec 01 Teil C 1.6.2, 4.3 Nr. 1 c; R-114).

infl <- list(mu = 0.02, phi = 0.5, sigma = 0.011, x0 = 0.028)
yrs <- 2027:2057
lk <- function(a, b, phi, sigma, u0, rho = 0, base = infl) {
  list(base = "inflation", a = a, b = b, phi = phi, sigma = sigma, u0 = u0,
       .base = list(type = "ar1", par = base, rho = rho))
}

test_that("linked_ar1: Prüffälle der Erwartungspfade (Basis Inflation, x0 = 0,028)", {
  p <- wsc_proc("linked_ar1")
  sel <- c(1, 2, 3, 11, 31)
  ex <- function(...) p$expected(lk(...), yrs)
  expect_spec(ex(0.002, 0.8, 0.5, 0.006, 0)[sel],
              c("0.0244", "0.0212", "0.0196", "0.01800625", "0.018"))
  expect_spec(ex(0.002, 0.8, 0.5, 0.006, -0.0094)[sel],
              c("0.015", "0.0165", "0.01725", "0.01799707", "0.018"))
  expect_spec(ex(0.005, 1, 0.5, 0.02, -0.013)[sel],
              c("0.020", "0.0225", "0.02375", "0.02499512", "0.025"))
  expect_spec(ex(0.007, 1, 0.65, 0.015, 0)[c(1, 2, 11, 31)],
              c("0.035", "0.031", "0.027007812", "0.027"))
  expect_spec(ex(0.007, 1, 0.65, 0.015, 0.005)[sel],
              c("0.040", "0.03425", "0.0311125", "0.02707513", "0.027"))
  expect_spec(ex(0.010, 1, 0.65, 0.015, 0.002)[sel],
              c("0.040", "0.0353", "0.032845", "0.03003474", "0.030"))
})

test_that("linked_ar1: sd(g_11) mit μ-Unsicherheit der Basis (0,012707211 / 0,023808438)", {
  k <- seq_along(yrs) - 1
  for (cs in list(list(lk(0.002, 0.8, 0.5, 0.006, 0), "0.012707211"),
                  list(lk(0.007, 1, 0.65, 0.015, 0), "0.023808438"))) {
    m <- proc_linked_ar1_moments(cs[[1]], yrs)
    b <- cs[[1]]$b
    expect_spec(sqrt(m$sd^2 + b^2 * (1 - 0.5^k)^2 * 0.004^2)[11], cs[[2]])
  }
})

test_that("linked_ar1: Quantilpfad y = 11 (Prüffall v2, ohne Schockkorrelation)", {
  p <- wsc_proc("linked_ar1")
  par <- lk(0.002, 0.8, 0.5, 0.006, -0.0094)
  m <- proc_linked_ar1_moments(par, yrs)
  expect_spec(m$mean[11], "0.01799707")
  expect_spec(m$sd[11], "0.012298504")
  expect_spec(p$quantile_path(par, yrs, 0.1)[11], "0.002235904")
  expect_spec(p$quantile_path(par, yrs, 0.9)[11], "0.033758237")
})

test_that("linked_ar1: Quantilpfad mit Schockkorrelation, Vasicek- und verketteter Basis", {
  p <- wsc_proc("linked_ar1")
  # Kovarianzterm gegen Simulation: Var(g_y) = b² Var(B) + Var(u) + 2 b Cov(B, u)
  par <- lk(0.002, 0.8, 0.5, 0.006, 0, rho = 0.6)
  n <- 40000L
  zb <- smp_shocks(1, "shock:b:1", n, 10L, "pseudo")
  ze <- smp_shocks(1, "shock:e:1", n, 10L, "pseudo")
  z <- 0.6 * zb + sqrt(1 - 0.36) * ze
  xb <- wsc_proc("ar1")$simulate(infl, zb, NULL, 2027:2037, structure(list(), n = n))
  g <- p$simulate(par, z, NULL, 2027:2037, structure(list(base = xb), n = n))
  m <- proc_linked_ar1_moments(par, 2027:2037)
  expect_lt(abs(stats::sd(g[, 11]) / m$sd[11] - 1), 0.02)
  # Vasicek-Basis ohne Untergrenze: Gaußbasis
  vb <- list(type = "vasicek", par = list(r0 = 0.04, theta = 0.0375, kappa = 0.12, sigma = 0.007),
             rho = 0.3)
  pv <- list(base = "r", a = 0.01, b = 1, phi = 0.5, sigma = 0.004, u0 = 0, .base = vb)
  q <- p$quantile_path(pv, yrs, 0.9)
  expect_true(all(is.finite(q)))
  expect_equal(q[1], 0.05)
  # Vasicek mit Untergrenze bzw. mr_trend: keine Gaußbasis -> NA
  vb$par$floor <- 0.005
  expect_true(all(is.na(p$quantile_path(utils::modifyList(pv, list(.base = vb)), yrs, 0.9))))
  mb <- list(type = "mr_trend", par = list(p0 = 0.1, phi = 0.75, sigma = 0.08), rho = 0)
  pm <- utils::modifyList(pv, list(.base = mb))
  expect_true(all(is.na(p$quantile_path(pm, yrs, 0.9))))
  expect_equal(p$expected(pm, 2027:2028)[1], 0.01 + 0.1)
  # verkettet: linked_ar1 auf linked_ar1 auf ar1
  inner <- lk(0.002, 0.8, 0.5, 0.006, 0)
  outer <- list(base = "rent", a = 0, b = 1, phi = 0, sigma = 0.002, u0 = 0,
                .base = list(type = "linked_ar1", par = inner, rho = 0))
  q2 <- p$quantile_path(outer, yrs, 0.5)
  expect_equal(q2, p$expected(outer, yrs), tolerance = 1e-14)
  expect_equal(p$expected(outer, yrs), p$expected(inner, yrs), tolerance = 1e-15)
  # ohne .base: Erwartung und Quantilpfad NA
  expect_true(all(is.na(p$expected(lk(0, 1, 0, 0, 0)[1:6], yrs))))
  expect_true(all(is.na(p$quantile_path(lk(0, 1, 0, 0, 0)[1:6], yrs, 0.5))))
})

test_that("linked_ar1: Simulation, Eingabeprüfung, Validierung, Vertrag", {
  p <- wsc_proc("linked_ar1")
  base <- matrix(c(0.02, 0.03, 0.025, 0.035), 2, 2)
  x <- p$simulate(list(base = "i", a = 0.001, b = 0.5, phi = 0.5, sigma = 0.01, u0 = 0.002),
                  matrix(c(1, -1), 2, 1), NULL, 2027:2028, list(base = base))
  expect_equal(x[, 1], 0.001 + 0.5 * base[, 1] + 0.002)
  expect_equal(x[, 2], 0.001 + 0.5 * base[, 2] + 0.5 * 0.002 + 0.01 * c(1, -1))
  expect_error(p$simulate(list(base = "i"), NULL, NULL, 2027:2028,
                          structure(list(base = matrix(0, 3, 2)), n = 2L)),
               class = "vofi_error_contract")
  expect_identical(p$validate(lk(0.002, 0.8, 0.5, 0.006, "base")[1:6]), character(0))
  expect_length(p$validate(list(a = 1)), 1L)
  expect_length(p$validate(list(base = "i", phi = 2)), 1L)
  expect_length(p$validate(list(base = "i", u0 = list(dist = "normal", mean = 0, sd = 1))), 1L)
  expect_type_contract("linked_ar1", "process")
})
