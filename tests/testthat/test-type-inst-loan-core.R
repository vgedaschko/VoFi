# Tests für R/type-inst-loan-core.R (WS-F; Spec 00 Abschnitte 8.5, 8.6, 8.10).
# Phase-0-Minimalfassung: Prüfwerte Test (f) und Test (h).

run_loan <- function(type, ..., T = 10L) { # nolint: object_name_linter. T wie Spec 00.
  big_t <- T # nolint: T_and_F_symbol_linter. T ist der Periodenindex.
  comp <- make_component(type, ..., id = "k")
  ctx <- make_ctx(grid = make_grid("annual", T = big_t), spec = comp)
  def <- reg_get("instrument", type)
  st <- def$init(comp, ctx)
  out <- list()
  for (t in 0:big_t) {
    r <- def$step(st, t, ctx)
    st <- r$state
    out[[t + 1L]] <- c(unlist(r$flows), unlist(r$memo), balance = r$stocks$balance)
  }
  list(steps = as.data.frame(do.call(rbind, out)), state = st)
}

test_that("Test (f): Monatsannuit\u00e4t 100.000 zu 3,6 %, 240 Monate, Jahresraster", {
  r <- run_loan("annuity_loan", amount_eur = 100000, rate_pa = 0.036, term_years = 20,
                payments_per_year = 12L, T = 2L)
  expect_equal(round(r$state$inst, 2), 585.11)
  expect_equal(round(-r$steps$interest[2], 2), 3542.98)
  expect_equal(round(-r$steps$repay[2], 2), 3478.36)
  expect_equal(round(r$steps$balance[2], 2), 96521.64)
  expect_equal(r$steps$draw[1], 100000)
})

test_that("Test (h): Ratendarlehen mit Zinsanpassung keep_term", {
  r <- run_loan("installment_loan", amount_eur = 120000, rate_pa = 0.02, term_years = 10,
                payments_per_year = 12L, fixed_years = 5, followup_rate_pa = 0.04, T = 10L)
  s <- r$steps
  expect_equal(-s$repay[2:11], rep(12000, 10))
  expect_equal(-s$interest[2], 2290)
  expect_equal(s$balance[6], 60000)
  expect_equal(-s$interest[7], 2180)
  expect_equal(s$balance[9], 24000)
  expect_equal(s$balance[11], 0)
})

test_that("Endf\u00e4llig, Disagio, Bearbeitungsgeb\u00fchr, Tilgungszuschuss, Bewilligung", {
  r <- run_loan("bullet_loan", amount_eur = 50000, rate_pa = 0.04, term_years = 3,
                payments_per_year = 1L, payout_rate = 0.98,
                fees = list(processing_fee_share = 0.01), T = 4L)
  s <- r$steps
  expect_equal(s$draw[1], 49000)
  expect_equal(s$disagio[1], 1000)
  expect_equal(s$fees[1], -500)
  expect_equal(-s$interest[2:4], rep(2000, 3))
  expect_equal(s$repay_balloon[4], -50000)
  expect_equal(s$balance[5], 0)
  a <- run_loan("annuity_loan", amount_eur = 100000, rate_pa = 0.03, term_years = 10,
                payments_per_year = 1L, measure_id = "m1",
                repayment_grant = list(share = 0.1, year = 2028), T = 3L)
  expect_equal(a$steps$repayment_grant[2], 10000)
  expect_equal(a$steps$balance[2], 100000 - 10000 + a$steps$repay[2])
  n <- run_loan("bullet_loan", amount_eur = 50000, rate_pa = 0.04, term_years = 3,
                payments_per_year = 1L, approved = 0, T = 2L)
  expect_true(all(n$steps$draw == 0) && all(n$steps$balance == 0))
  expect_error(run_loan("bullet_loan", amount_eur = 1, rate_pa = 0.01, T = 1L),
               class = "vofi_error_input")
})

codes_of_val <- function(x) vofi_validate(x)$code

test_that("Validierung der Kredite: Wertebereiche und Kombinationsregeln (8.2, 8.6)", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  bad <- sc
  bad$financing$bank$amount_eur <- -60000
  v <- vofi_validate(bad)
  expect_true("validation.range" %in% v$code)
  expect_identical(v$path[v$code == "validation.range"], "financing.bank.amount_eur")
  expect_error(vofi_build(bad), class = "vofi_error_validation")
  b2 <- sc
  b2$financing$bank$term_years <- 0
  b2$financing$bank$payments_per_year <- 2L
  v2 <- vofi_validate(b2)
  expect_true(all(c("types.instrument.bullet_loan.errors.term_nonpositive",
                    "types.instrument.bullet_loan.errors.ppy") %in% v2$code))
  b3 <- sc
  b3$financing$bank$term_years <- NULL
  expect_true("types.instrument.bullet_loan.errors.term_missing" %in% codes_of_val(b3))
  b4 <- sc
  b4$financing$bank$grace_years <- 3
  expect_true("types.instrument.bullet_loan.errors.grace_too_long" %in% codes_of_val(b4))
  b5 <- sc
  b5$financing$bank <- list(type = "annuity_loan", amount_eur = 60000, rate_pa = 0.05,
                            initial_repayment_pa = 0.02, installment_eur = 500,
                            payments_per_year = 12L)
  expect_true("types.instrument.annuity_loan.errors.tau_installment" %in% codes_of_val(b5))
  expect_identical(nrow(vofi_validate(sc)), 0L)
})
