# Tests für R/type-inst-bullet-loan.R (WS-F): Typdefinition, Beispiel, Schlusstilgung und
# Zinsanpassung des endfälligen Darlehens (Spec 00 8.5 (f), 8.6 „endfällig“), Ü3-Attrappe des
# Prüfkits (reg_test_inst).

test_that("Typdefinition bullet_loan: Parameter, Beispiel, Vertrag", {
  def <- reg_get("instrument", "bullet_loan")
  expect_identical(def$repayment, "bullet")
  expect_false(any(c("installment_eur", "initial_repayment_pa") %in% names(def$params)))
  expect_true("refi_rule" %in% names(def$params))
  expect_type_contract("bullet_loan", "instrument")
  g <- reg_test_grid("annual")
  ex <- do.call(loan_run, c(list("bullet_loan"), def$example[setdiff(names(def$example), "type")],
                            list(grid = g)))
  expect_near(-loan_row(ex, "interest")[2:3], c(4000, 4000))
  expect_near(-loan_row(ex, "interest")[4:6], rep(4500, 3))
  expect_near(loan_row(ex, "repay_balloon")[6], -100000)
  expect_near(loan_row(ex, "disagio")[1], 3000)
})

test_that("Endf\u00e4llig: refi_rule ohne Wirkung, Schlusstilgung nach Sondertilgung", {
  a <- loan_run("bullet_loan", amount_eur = 50000, rate_pa = 0.03, term_years = 4,
                payments_per_year = 12L, fixed_years = 2, followup_rate_pa = 0.05,
                refi_rule = "keep_payment", grid = make_grid("annual", T = 5L))
  b <- loan_run("bullet_loan", amount_eur = 50000, rate_pa = 0.03, term_years = 4,
                payments_per_year = 12L, fixed_years = 2, followup_rate_pa = 0.05,
                grid = make_grid("annual", T = 5L))
  expect_identical(a$m, b$m)
  expect_near(-loan_row(a, "interest")[2:5], c(1500, 1500, 2500, 2500))
  p <- loan_run("bullet_loan", amount_eur = 50000, rate_pa = 0.03, term_years = 4,
                payments_per_year = 1L, prepay_allowed = TRUE,
                grid = make_grid("annual", T = 5L), prepay_at = list("2" = 20000))
  expect_near(loan_row(p, "repay_balloon")[5], -30000)
  expect_near(-loan_row(p, "interest")[4], 900)
})

test_that("Pr\u00fcfkit-Instrument f\u00fcr Ausgleichsaktionen (reg_test_inst) l\u00e4uft", {
  g <- reg_test_grid("annual")
  ti <- reg_test_inst(g, reg_test_spec(g), NULL, "deterministic")
  st <- ti$inst$k$state
  expect_identical(st$B, 50000)
  cap <- ti$inst$k$def$capacity(st, 1L, NULL)
  expect_identical(cap$cap, 50000)
  expect_identical(cap$rate_pa, 0.06)
})
