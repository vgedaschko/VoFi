# Tests für R/kpi-withdrawal.R (WS-D2; Spec 00 Abschnitte 12.8, 15.3, 15.4 I5; Memo 01 §4.6).

#' Zielfunktion f(E) aus 12.8 über ctx$rebalance() (unabhängig von der Implementierung)
d2_withdrawal_f <- function(core, ctx, ex_rv = FALSE) {
  nt <- core$grid$T + 1L
  q <- kpi_q(core)
  qt <- q[, nt]
  dmat <- matrix(core$grid$delta, core$n, nt, byrow = TRUE)
  function(e) {
    r <- ctx$rebalance(extra_out = -e * dmat)
    bs <- if (ex_rv) r$BS_T_ex_rv else r$BS_T
    bs - rowSums((r$NS - kpi_ns(core)) * qt / q) - kpi_ew_opp(core)
  }
}

test_that("Orakel (a), (b1), (b2), (c1): Entnahme-Äquivalent (Prüfwerte 12.8)", {
  o <- oracle_a_values()$kpi
  a <- d2_run(d2_oracle_a())
  expect_true(abs(a$kpis$withdrawal_equivalent - o$withdrawal_equivalent) < 1e-6)
  expect_equal(a$kpis$withdrawal_equivalent, 672.44, tolerance = 0.005 / 672.44)
  b1 <- d2_run(d2_oracle_b("shorten_term"))
  expect_equal(b1$kpis$withdrawal_equivalent, 731.23, tolerance = 0.005 / 731.23)
  b2 <- d2_run(d2_oracle_b("reduce_installment"))
  expect_equal(b2$kpis$withdrawal_equivalent, 950.13, tolerance = 0.005 / 950.13)
  c1 <- d2_run(d2_oracle_c())
  expect_equal(c1$kpis$withdrawal_equivalent, 2300.89, tolerance = 0.005 / 2300.89)
  expect_true(a$kpis$withdrawal_equivalent_ex_rv < 0)
  expect_true(is.na(a$kpi_na$withdrawal_equivalent))
})

test_that("Lösung erfüllt f(E*) = 0 in beiden Sichten; Batch = Einzellauf; Toleranz", {
  core <- example_core(7L)
  ctx <- d2_ctx(core)
  w <- kpi_withdrawal_equivalent(core, ctx)
  expect_s3_class(w, "vofi_kpi_value")
  expect_false(anyNA(w$values))
  f <- d2_withdrawal_f(core, ctx)
  expect_true(all(abs(f(w$values)) < 1e-6))
  ex <- core_ex_rv(core)
  wx <- kpi_withdrawal_equivalent(ex, ctx)
  fx <- d2_withdrawal_f(ex, ctx, ex_rv = TRUE)
  expect_true(all(abs(fx(wx$values)) < 1e-6))
  expect_true(all(wx$values < w$values))
  for (i in c(1L, 4L, 7L)) {
    ci <- reg_example_core(1L, 6L, runs = i)
    wi <- kpi_withdrawal_equivalent(ci, d2_ctx(ci))
    expect_true(abs(wi$values - w$values[i]) <= 1e-9 * max(1, abs(w$values[i])), info = i)
  }
  det <- d2_ctx(core, mode = "deterministic")
  wd <- kpi_withdrawal_equivalent(core, det)
  expect_true(all(abs(wd$values - w$values) < 1e-6))
  loose <- kpi_withdrawal_equivalent(core, det, tol = 10)
  expect_true(all(abs(loose$values - wd$values) < 10))
  expect_true(attr(wd, "solver")$iterations >= 1L)
  expect_error(kpi_withdrawal_equivalent(core, det, tol = -1), class = "vofi_error_input")
})

test_that("Invariante I5: f streng fallend, Schranke -T_J (auch mit Nachschüssen)", {
  base <- example_core(2L)
  tk <- attr(base, "testkit")
  rates <- tk$rates
  rates$KL[] <- 0
  core <- reg_core_from_inputs(tk$inputs, base$grid, rates)
  attr(core, "testkit") <- list(inputs = tk$inputs, rates = rates)
  ctx <- d2_ctx(core)
  f <- d2_withdrawal_f(core, ctx)
  tj <- kpi_tj(core)
  for (e in c(-5000, 0, 5000, 20000, 60000)) {
    d <- f(rep(e + 1, 2)) - f(rep(e, 2))
    expect_true(all(d < 0), info = e)
    expect_true(all(d <= -tj + 1e-9), info = e)
  }
  r <- ctx$rebalance(extra_out = -60000 * matrix(core$grid$delta, 2, 7, byrow = TRUE))
  expect_true(sum(r$NS) > 0)
  w <- kpi_withdrawal_equivalent(core, ctx)
  expect_true(all(abs(f(w$values)) < 1e-6))
})

test_that("Klammer wird verdoppelt (negativer Habenzins), ohne Lösung NA no_solution", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 6L)
  rows <- list(z__value = d2_row("project", "custom", c(-50000, rep(0, 5), 80000)),
               ek__in = d2_row("equity", "equity_in", c(60000, rep(0, 6))))
  core <- d2_core(g, rows, h = -0.2, s = 0, sp = 0)
  ctx <- d2_ctx(core)
  dew <- kpi_ew(core) - kpi_ew_opp(core)
  w <- kpi_withdrawal_equivalent(core, ctx)
  expect_true(w$values > dew / kpi_tj(core) + 1)
  expect_true(abs(d2_withdrawal_f(core, ctx)(w$values)) < 1e-6)
  # Attrappe ohne Wirkung der Zusatzentnahme: f konstant > 0
  const_rebalance <- function(extra_out) {
    list(BS_T = kpi_ew(core) + 1, NS = matrix(0, 1, 7), BS_T_ex_rv = kpi_ew(core) + 1, RW_T = 0)
  }
  fake <- eng_context_from_parts(g, reg_test_spec(g), components = list(),
                                 mode = "deterministic",
                                 engine_env = reg_engine_env("kpi", rebalance = const_rebalance))
  nos <- kpi_withdrawal_equivalent(core, fake)
  expect_identical(nos$na_reason, "no_solution")
  v <- reg_get("kpi", "withdrawal_equivalent")$compute(core, fake)
  expect_identical(v$na_reason, "no_solution")
  expect_null(attr(v, "solver"))
})
