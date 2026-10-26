# Tests für R/type-inst-installment-loan.R (WS-F): Typdefinition, Beispiel, Besonderheiten der
# Ratentilgung (Spec 00 8.6: inst = reine Tilgungsrate; keep_tilg_rate unzulässig).

test_that("Typdefinition installment_loan: Parameter, Beispiel, Vertrag", {
  def <- reg_get("instrument", "installment_loan")
  expect_identical(def$repayment, "installment")
  expect_false(any(c("initial_repayment_pa", "followup_repayment_pa") %in% names(def$params)))
  expect_true("installment_eur" %in% names(def$params))
  expect_type_contract("installment_loan", "instrument")
  g <- reg_test_grid("mixed")
  ex <- do.call(loan_run, c(list("installment_loan"),
                            def$example[setdiff(names(def$example), "type")], list(grid = g)))
  ref <- loan_ref_clock(g, "installment_loan", def$example)
  expect_equal(loan_as_matrix(ex), ref, tolerance = 1e-9)
  expect_identical(ex$state$t_tz, as.integer(grid_period_of(g, as.Date("2029-01-01"))))
})

test_that("Ratentilgung: Tilgungsrate ohne Zinsen, Quartalsraten, vertragliche Rate", {
  r <- loan_run("installment_loan", amount_eur = 80000, rate_pa = 0.04, term_years = 4,
                payments_per_year = 4L, grid = make_grid("annual", T = 5L))
  expect_identical(r$state$inst, 5000)
  expect_equal(-loan_row(r, "repay")[2:5], rep(20000, 4))
  # Zinsen monatlich auf den Monatsanfangsbestand: Jahr 1 = 3 x (80.000 + 75.000 + 70.000 +
  # 65.000) x 0,04 / 12
  expect_near(-loan_row(r, "interest")[2], 3 * (80000 + 75000 + 70000 + 65000) * 0.04 / 12)
  v <- loan_run("installment_loan", amount_eur = 80000, rate_pa = 0.04, term_years = 4,
                payments_per_year = 1L, installment_eur = 15000,
                grid = make_grid("annual", T = 5L))
  expect_equal(-loan_row(v, "repay")[2:5], rep(15000, 4))
  expect_near(loan_row(v, "repay_balloon")[5], -20000)
})

test_that("Ratentilgung mit keep_payment und reduce_installment ohne Laufzeitende", {
  r <- loan_run("installment_loan", amount_eur = 60000, rate_pa = 0.03, term_years = 6,
                payments_per_year = 1L, fixed_years = 2, followup_rate_pa = 0.06,
                refi_rule = "keep_payment", measure_id = "m1",
                repayment_grant = list(amount_eur = 6000, year = 2028L,
                                       effect = "reduce_installment"))
  # Gutschrift Ende t = 1 nach der ersten Rate: Bestand 44.000 auf 5 Raten -> 8.800
  expect_near(r$states[[2]]$inst, 8800)
  expect_near(-loan_row(r, "repay")[3:7], rep(8800, 5))
  expect_near(-loan_row(r, "interest")[4], (44000 - 8800) * 0.06)
})
