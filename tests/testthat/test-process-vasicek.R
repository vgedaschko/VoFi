# Tests für R/process-vasicek.R (WS-C; Spec 01 Teil C 1.6.3, 2.8 Nr. 1, 4.3 Nr. 1 c).

vas <- list(r0 = 0.040, theta = 0.0375, kappa = 0.12, sigma = 0.007, floor = 0.005)
yrs <- 2027:2067

test_that("vasicek: Kenngrößen und Erwartungs-/sd-Tabelle (Default mortgage_rate_vasicek_2026)", {
  m <- proc_vasicek_moments(vas, yrs)
  expect_spec(m$phi, "0.88692044")
  expect_spec(m$sigma, "0.0066002635")
  expect_spec(0.007 / sqrt(2 * 0.12), "0.01428869")
  expect_spec(log(2) / 0.12, "5.7762265")
  sel <- c(1, 2, 6, 11, 21, 31, 41)
  expect_spec(m$mean[sel], c("0.04", "0.039717301", "0.038872029", "0.038252986", "0.037726795",
                             "0.037568309", "0.037520574"))
  expect_spec(m$sd[sel], c("0", "0.0066002635", "0.011944574", "0.013625164", "0.014229773",
                           "0.014283355", "0.014288206"))
  # E[max(r, floor)] und P(r < floor) analytisch aus den Momenten
  z <- (0.005 - m$mean) / m$sd
  ef <- m$mean + m$sd * dnorm(z) + (0.005 - m$mean) * pnorm(z)
  expect_spec(ef[sel[-1]], c("0.039717301", "0.038880087", "0.038285765", "0.037778916",
                             "0.037623729", "0.037576681"))
  expect_equal(pnorm(z)[sel[-1]], c(7.2e-8, 0.0022858, 0.0073323, 0.0107275, 0.0112992,
                                    0.0114217), tolerance = 1e-4)
})

test_that("vasicek: Quantile der Ausgabe (2.8 Nr. 1, Prüffall v2)", {
  p <- wsc_proc("vasicek")
  q <- function(y, pr) p$quantile_path(vas, yrs, pr)[y]
  q3 <- function(y) vapply(c(0.05, 0.5, 0.95), function(pr) q(y, pr), 0)
  expect_spec(q3(11), c("0.01584159", "0.03825299", "0.06066439"))
  expect_spec(q3(21), c("0.01432090", "0.03772679", "0.06113269"))
  expect_spec(q3(31), c("0.01407428", "0.03756831", "0.06106234"))
  expect_spec(c(q(11, 0.1), q(11, 0.9)), c("0.02079164", "0.05571434"))
  # bindende Untergrenze im Quantilpfad und in der Erwartung (R-95)
  low <- utils::modifyList(vas, list(r0 = 0.006, theta = 0.006, floor = 0.005))
  expect_identical(p$quantile_path(low, yrs, 0.01)[11], 0.005)
  hi <- utils::modifyList(vas, list(r0 = 0.002, theta = 0.002, floor = 0.005))
  expect_identical(p$expected(hi, yrs), rep(0.005, length(yrs)))
})

test_that("vasicek: Golden-Pfad Lauf 1 (m = 10) und Untergrenze nur der Ausgabe", {
  p <- wsc_proc("vasicek")
  z <- with_stream(20261025, "shock:mortgage_rate:1",
                   vapply(1:3, function(j) qnorm((sample.int(10) - runif(10)) / 10), numeric(10)))
  zz <- smp_shocks(20261025, "shock:mortgage_rate:1", 10L, 3L, "lhs")
  expect_identical(zz, z)
  x <- p$simulate(utils::modifyList(vas, list(floor = -Inf)), zz, NULL, 2027:2030,
                  structure(list(), n = 10L))
  expect_spec(x[1, ], c("0.0400000000", "0.0406599864", "0.0494826935", "0.0441105157"))
  # Zustand ungekappt: Ausgabe mit Untergrenze = pmax(ungekappte Ausgabe, floor)
  zl <- matrix(-3, 2, 5)
  a <- p$simulate(utils::modifyList(vas, list(floor = -Inf)), zl, NULL, 2027:2032,
                  structure(list(), n = 2L))
  b <- p$simulate(vas, zl, NULL, 2027:2032, structure(list(), n = 2L))
  expect_identical(b, pmax(a, 0.005))
  expect_true(any(a < 0.005))
  # Erwartung mit σ = 0 entspricht der Simulation (P2)
  s0 <- utils::modifyList(vas, list(sigma = 0))
  expect_equal(as.vector(p$simulate(s0, NULL, NULL, yrs, structure(list(), n = 1L))),
               p$expected(s0, yrs), tolerance = 1e-14)
})

test_that("vasicek: Simulation gegen Erwartung (Memo 04 §9) und Untergrenze eingehalten", {
  p <- wsc_proc("vasicek")
  n <- 20000L
  z <- smp_shocks(4711, "shock:r:1", n, 30L, "pseudo")
  r <- p$simulate(list(r0 = 0.05, theta = 0.03, kappa = 0.2, sigma = 0.005), z, NULL,
                  2027:2057, structure(list(), n = n))
  expect_lt(abs(mean(r[, 6]) - (0.03 + 0.02 * exp(-1))), 4 * stats::sd(r[, 6]) / sqrt(n))
  f <- p$simulate(list(r0 = 0.01, theta = 0.01, kappa = 0.1, sigma = 0.02, floor = 0), z,
                  NULL, 2027:2057, structure(list(), n = n))
  expect_true(all(f >= 0))
})

test_that("vasicek: Validierung und Vertrag", {
  p <- wsc_proc("vasicek")
  expect_identical(p$validate(vas), character(0))
  expect_identical(p$validate(utils::modifyList(vas, list(r0 = "base"))), character(0))
  expect_length(p$validate(utils::modifyList(vas, list(kappa = 0))), 1L)
  expect_length(p$validate(utils::modifyList(vas, list(floor = 0.05))), 1L)
  expect_length(p$validate(utils::modifyList(vas, list(theta = NULL))), 1L)
  expect_identical(p$validate(utils::modifyList(vas, list(floor = -Inf))), character(0))
  expect_type_contract("vasicek", "process")
})
