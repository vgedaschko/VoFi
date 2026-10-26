# Tests für R/kpi-returns.R (WS-D2; Spec 00 Abschnitte 12.3, 12.6, 12.8, 15.3, 15.4 R3).

expect_rate <- function(x, expected, tol = 5e-7) {
  expect_true(abs(x - expected) <= tol, info = paste(x, expected))
}

test_that("Orakel (a), (a_unlevered), (d), (e): R1 = R2 = R3, IZF der Zahlungsfolge", {
  o <- oracle_a_values()$kpi
  a <- d2_run(d2_oracle_a())
  expect_rate(a$kpis$roe_classic, o$roe_classic, 1e-9)
  expect_rate(a$kpis$roe_mirr, o$roe_mirr, 1e-9)
  expect_rate(a$kpis$roe_irr, o$roe_irr, 1e-9)
  expect_rate(a$kpis$irr_cf_project, o$irr_cf_project, 1e-9)
  expect_rate(a$kpis$roe_mirr, 0.051183)
  for (k in c("roe_classic_ex_rv", "roe_mirr_ex_rv", "roe_irr_ex_rv")) {
    expect_identical(a$kpi_na[[k]], "equity_lost", info = k)
  }
  un <- d2_oracle_a()
  un$financing <- list(ek = list(type = "equity", amount_eur = 100000))
  u <- d2_run(un)
  expect_equal(u$kpis$terminal_value, 127747.32, tolerance = 0.005 / 127747.32)
  expect_rate(u$kpis$roe_mirr, 0.050196)
  d <- d2_run(d2_oracle_a(rate = 0.05))
  expect_rate(d$kpis$roe_classic, 0.064492)
  e <- d2_run(d2_oracle_e())
  expect_rate(e$kpis$roe_mirr, 0.118553)
  expect_rate(e$kpis$roe_classic, 0.118553)
  expect_rate(e$kpis$roe_irr, 0.118553)
})

test_that("Orakel (b1), (b2), (c1), (c1_unlevered), (c2), (g): Renditen und NA-Codes", {
  b1 <- d2_run(d2_oracle_b("shorten_term"))
  for (k in c("roe_classic", "roe_mirr", "roe_irr")) expect_rate(b1$kpis[[k]], 0.034857)
  expect_rate(b1$kpis$irr_cf_project, 0.009458)
  b2 <- d2_run(d2_oracle_b("reduce_installment"))
  expect_rate(b2$kpis$roe_mirr, 0.036202)
  a3 <- d2_run(d2_oracle_a3())
  expect_rate(a3$kpis$roe_mirr, 0.0546293267, 1e-9)
  expect_rate(a3$kpis$roe_mirr, 0.054629)
  for (k in c("roe_classic", "roe_irr")) expect_rate(a3$kpis[[k]], 0.054629)
  c1 <- d2_run(d2_oracle_c())
  for (k in c("roe_classic", "roe_mirr", "roe_irr")) {
    expect_identical(c1$kpi_na[[k]], "no_equity", info = k)
  }
  expect_rate(c1$kpis$irr_cf_project, 0.051616)
  cu <- d2_oracle_c()
  cu$financing <- list(ek = list(type = "equity", amount_eur = 300000))
  cu <- d2_run(cu)
  expect_equal(cu$kpis$terminal_value, 477695.18, tolerance = 0.005 / 477695.18)
  expect_rate(cu$kpis$roe_mirr, 0.047618)
  c2 <- d2_run(d2_oracle_c(limit = 0))
  expect_identical(c2$kpi_na$roe_classic, "no_equity")
  expect_rate(c2$kpis$roe_mirr, 0.108879)
  expect_rate(c2$kpis$roe_irr, 0.169699)
  ga <- d2_run(d2_oracle_g("a"))
  expect_identical(ga$kpi_na$roe_classic, "multiple_equity_flows")
  expect_false(is.na(ga$kpis$roe_mirr))
})

test_that("Prüffall Sacheinlage (9.5): roe_mirr mit Bestandswert, sonst no_existing_value", {
  ik <- d2_run(d2_oracle_in_kind())
  expect_rate(ik$kpis$roe_mirr, 318700 / 300000 - 1, 1e-12)
  expect_rate(ik$kpis$roe_classic, 0.062333)
  no <- d2_run(d2_oracle_in_kind(existing_value = NULL))
  expect_equal(no$kpis$terminal_value, 318700, tolerance = 1e-10)
  for (k in c("roe_classic", "roe_mirr", "roe_irr", "roe_mirr_ex_rv")) {
    expect_identical(no$kpi_na[[k]], "no_existing_value", info = k)
  }
})

test_that("Synthetische Fälle: no_equity, multiple_equity_flows, no_existing_value", {
  core <- example_core(2L)
  ctx <- d2_ctx(core)
  expect_identical(d2_kpi("roe_classic", core, ctx)$na_reason, rep("multiple_equity_flows", 2))
  noeq <- core
  noeq$ledger$values$ek__in[] <- 0
  expect_identical(d2_kpi("roe_mirr", noeq, ctx)$na_reason, rep("no_equity", 2))
  expect_identical(d2_kpi("roe_irr", noeq, ctx)$na_reason, rep("no_equity", 2))
  expect_identical(d2_kpi("roe_classic", noeq, ctx)$na_reason, rep("no_equity", 2))
  ex <- d2_ctx(core, project = list(project_type = "sanierung_eh"))
  for (k in c("roe_classic", "roe_mirr", "roe_irr")) {
    expect_identical(d2_kpi(k, core, ex)$na_reason, rep("no_existing_value", 2), info = k)
  }
  exv <- d2_ctx(core, project = list(project_type = "sanierung_eh"),
                building = list(existing_value_eur = 250000))
  expect_false(anyNA(d2_kpi("roe_mirr", core, exv)$values))
  one <- core
  one$ledger$values$ek__out[] <- 0
  v1 <- d2_kpi("roe_classic", one, ctx)
  ew <- one$stocks$BS[, 7]
  expect_equal(v1$values, (ew / 100000)^(1 / 6) - 1)
  expect_equal(d2_kpi("roe_mirr", one, ctx)$values, v1$values)
})

test_that("Rangidentität R3 (15.4): sign(roe_mirr - r_U) = sign(Endwertdifferenz)", {
  for (n in c(1L, 7L)) {
    core <- example_core(n)
    ctx <- d2_ctx(core)
    for (cr in list(core, core_ex_rv(core))) {
      r3 <- d2_kpi("roe_mirr", cr, ctx)$values
      q <- kpi_q(cr)
      qt <- q[, 7]
      en <- kpi_en(cr)
      el <- kpi_el(cr)
      num_u <- kpi_ew_opp(cr) + rowSums(en * qt / q)
      r_u <- (num_u / rowSums(el / q))^(1 / 6) - 1
      dew <- kpi_ew(cr) - kpi_ew_opp(cr)
      ok <- !is.na(r3)
      expect_identical(sign(r3[ok] - r_u[ok]), sign(dew[ok]))
    }
  }
})

test_that("kpi_irr: Genauigkeit, Vorzeichenwechsel, außerhalb des Intervalls, Batch-Invarianz", {
  cf <- rbind(c(-100000, 6000, 10000, 30000, 8000, 70000),
              c(-100, 230, -132, 0, 0, 0),
              c(100, 10, 10, 10, 10, 10),
              c(-100, 0, 0, 0, 0, 0),
              c(0, 0, 0, 0, 0, 0))
  delta <- c(0, rep(1, 5))
  r <- kpi_irr(cf, delta)
  ref <- stats::uniroot(function(x) sum(cf[1, ] * (1 + x)^-(0:5)), c(0, 0.2), tol = 1e-14)$root
  expect_true(abs(r$value[1] - ref) < 1e-10)
  expect_identical(r$ambiguous, c(FALSE, TRUE, FALSE, FALSE, FALSE))
  expect_identical(r$out_of_range[c(1, 3, 4, 5)], c(FALSE, TRUE, TRUE, TRUE))
  expect_identical(kpi_sign_changes(cf), c(1L, 2L, 0L, 0L, 0L))
  expect_identical(kpi_sign_changes(rbind(c(-1, 1e-12, -1, 2))), 1L)
  single <- kpi_irr(cf[1, , drop = FALSE], delta)
  expect_identical(single$value, r$value[1])
  # nicht äquidistant: tau = 0, 0.25, ..., Horner mit (1 + r)^(-Delta)
  d2 <- c(0, 0.25, 0.25, 0.5, 1, 1)
  r2 <- kpi_irr(cf[1, , drop = FALSE], d2)
  tau <- cumsum(d2)
  expect_true(abs(sum(cf[1, ] * (1 + r2$value)^(-tau))) < 1e-6)
  expect_equal(kpi_npv_horner(cf[1, , drop = FALSE], delta, 0.03),
               sum(cf[1, ] / 1.03^(0:5)))
  core <- example_core(2L)
  ctx <- d2_ctx(core)
  amb <- core
  amb$ledger$values$rv__value[, 7] <- -2e6
  v <- d2_kpi("irr_cf_project", amb, ctx)
  expect_identical(v$na_reason, rep("irr_ambiguous", 2))
  pos <- core
  pos$ledger$values$inv__cost[] <- 0
  expect_identical(d2_kpi("irr_cf_project", pos, ctx)$na_reason, rep("irr_out_of_range", 2))
})

test_that("kpi_illinois: lineare und stückweise lineare Funktionen, Läufe unabhängig", {
  f <- function(x) c(5 - 2 * x[1], 3 - pmax(x[2], 1) - 0.5 * x[2], 10 - x[3]^3)
  sol <- kpi_illinois(f, lo = c(-10, -10, 0), hi = c(10, 10, 5), flo = f(c(-10, -10, 0)),
                      fhi = f(c(10, 10, 5)), tol = 1e-10, ftol = 1e-12, max_iter = 200L)
  expect_equal(sol$root[1], 2.5, tolerance = 1e-12)
  expect_equal(sol$root[2], 2, tolerance = 1e-10)
  expect_equal(sol$root[3], 10^(1 / 3), tolerance = 1e-9)
  expect_true(all(sol$converged))
  g1 <- function(x) 5 - 2 * x
  s1 <- kpi_illinois(g1, -10, 10, g1(-10), g1(10), tol = 1e-10, ftol = 1e-12)
  expect_identical(s1$root, sol$root[1])
  inact <- kpi_illinois(g1, c(-10, -10), c(10, 10), g1(c(-10, -10)), g1(c(10, 10)), tol = 1e-6,
                        ftol = 1e-12, active = c(TRUE, FALSE))
  expect_true(is.na(inact$root[2]))
  edge <- kpi_illinois(g1, 2.5, 10, 0, g1(10), tol = 1e-6, ftol = 1e-12)
  expect_identical(edge$root, 2.5)
  narrow <- kpi_illinois(g1, 2.4, 2.6, g1(2.4), g1(2.6), tol = 1, ftol = 1e-12)
  expect_equal(narrow$root, 2.5)
  expect_identical(narrow$iterations, 0L)
  nanf <- kpi_illinois(function(x) rep(NaN, length(x)), 0, 1, 1, -1, tol = 1e-9, ftol = 1e-12)
  expect_equal(nanf$root, 0.5)
  capped <- kpi_illinois(function(x) 10 - x^3, 0, 5, 10, -115, tol = 1e-15, ftol = 0,
                         max_iter = 2L)
  expect_true(capped$root > 0 && capped$root < 5)
  expect_identical(capped$iterations, 2L)
})

test_that("Rendite der Mehrinvestition (12.8): eine Nullstelle fallend, sonst no_solution", {
  g <- function(h) 1000 - 10000 * h
  r <- kpi_incremental_return(g)
  expect_equal(r$values, 0.1, tolerance = 1e-10)
  expect_identical(attr(r, "solver")$grid[c(1, 41)], c(-0.02, 0.15))
  expect_true(abs(r$values - 0.1) < 1e-8)
  # stückweise linear (Kontokorrent-Knick) mit Nullstelle zwischen Stützstellen
  gk <- function(h) 500 - 4000 * pmin(h, 0.05) - 12000 * pmax(h - 0.05, 0)
  rk <- kpi_incremental_return(gk)
  expect_true(abs(gk(rk$values)) < 1e-6)
  expect_equal(rk$values, 0.05 + 300 / 12000, tolerance = 1e-9)
  expect_identical(kpi_incremental_return(function(h) -1000 + 10000 * h)$na_reason,
                   "no_solution")
  expect_identical(kpi_incremental_return(function(h) 1 + h)$na_reason, "no_solution")
  expect_identical(kpi_incremental_return(function(h) (h - 0.01) * (h - 0.1))$na_reason,
                   "no_solution")
  expect_identical(kpi_incremental_return(function(h) rep(NA_real_, length(h)))$na_reason,
                   "no_solution")
  expect_identical(kpi_incremental_return(function(h) h[-1])$na_reason, "no_solution")
  expect_identical(kpi_incremental_return(function(h) rep(0, length(h)))$na_reason,
                   "no_solution")
  # Nullstelle genau auf einer Stützstelle
  hz <- seq(-0.02, 0.15, length.out = 41)[11]
  rz <- kpi_incremental_return(function(h) hz - h)
  expect_equal(rz$values, hz)
  step <- function(h) ifelse(h < 0.02, 1, ifelse(h > 0.03, -1, 0))
  two_zero <- kpi_incremental_return(step)
  expect_identical(two_zero$na_reason, "no_solution")
  rint <- kpi_incremental_return(g, interval = c(0, 0.2), n_grid = 5L)
  expect_equal(rint$values, 0.1, tolerance = 1e-10)
  expect_error(kpi_incremental_return(g, interval = c(0.2, 0)), class = "vofi_error_input")
  expect_error(kpi_incremental_return("g"), class = "vofi_error_input")
  mc <- kpi_incremental_return_mc(3L)
  expect_identical(mc$na_reason, rep("not_computed", 3))
})
