# Tests für R/type-inst-annuity-loan.R (WS-F): Typdefinition, Beispiel, Prüfwerte der
# Referenzszenarien S1-S5 auf Instrumentebene (Spec 01 Teil C §5, Memo 07; S1-S4 mit
# payments_per_year: 1, S5 mit Monatsraten, Spec 00 15.6). Gerundete Tabellenwerte: 0,005 EUR.

test_that("Typdefinition annuity_loan: Parameter, Zeilen, Beispiel, Vertrag", {
  def <- reg_get("instrument", "annuity_loan")
  expect_identical(def$repayment, "annuity")
  expect_true(all(c("initial_repayment_pa", "followup_repayment_pa", "installment_eur") %in%
                    names(def$params)))
  expect_true(def$params$amount_eur$deterministic_only && def$params$amount_eur$allow_auto)
  for (p in c("term_years", "grace_years", "fixed_years", "followup_fixed_years",
              "draw_schedule", "start", "payments_per_year")) {
    expect_true(isTRUE(def$params[[p]]$deterministic_only), info = p)
  }
  expect_identical(def$rows, c("draw", "repay", "repay_balloon", "prepay", "interest", "fees",
                               "repayment_grant", "disagio", "assumed", "balance"))
  expect_identical(def$domain_reads, "measures")
  expect_type_contract("annuity_loan", "instrument")
  ex <- do.call(loan_run, c(list("annuity_loan"),
                            def$example[setdiff(names(def$example), "type")],
                            list(grid = reg_test_grid("annual"))))
  expect_identical(ex$state$t_tz, 1L)
  expect_true(any(loan_row(ex, "repayment_grant") > 0))
  expect_true(any(loan_row(ex, "fees") < 0))
  expect_true(any(loan_row(ex, "prepay") < 0))
  expect_true(any(loan_row(ex, "disagio") > 0))
})

test_that("S1-T7/T7a: Annuit\u00e4t V1 427.185 zu 4 %, 20 J., Restschuld 2036, Anschluss", {
  r <- loan_run("annuity_loan", amount_eur = 427185, rate_pa = 0.04, term_years = 20,
                payments_per_year = 1L, fixed_years = 10, followup_rate_pa = 0.04,
                grid = make_grid("annual", T = 20L))
  expect_near(loan_payment(r, 1), 31433.02)
  expect_near(loan_row(r, "balance")[11], 254949.95)
  expect_near(loan_payment(r, 11), 31433.02)
  expect_near(loan_row(r, "balance")[21], 0, tol = 1e-6)
  a <- loan_run("annuity_loan", amount_eur = 427185, rate_pa = 0.04, term_years = 20,
                payments_per_year = 1L, fixed_years = 10, followup_rate_pa = 0.0425,
                grid = make_grid("annual", T = 12L))
  expect_near(loan_payment(a, 11), 31825.43)
})

test_that("S1-T3/T8: KfW 261 \u00fcber den Anteil der Zusage (Bezug Expander, 01b 4.6)", {
  r <- loan_run("annuity_loan", amount_eur = 1300000, rate_pa = 0.0365, term_years = 30,
                grace_years = 5, fixed_years = 10, payments_per_year = 1L,
                followup_rate_pa = 0.04, funding_id = "kfw261", measure_id = "heizung",
                repayment_grant = list(share = (0.10 * 1264000 + 0.50 * 36000) / 1300000,
                                       date = "2028-01-01"),
                grid = make_grid("annual", T = 30L))
  expect_near(loan_row(r, "repayment_grant")[2], 144400)
  expect_near(-loan_row(r, "interest")[2:3], c(47450, 42179.40))
  expect_near(loan_payment(r, 6), 80165.66)
  expect_near(loan_row(r, "balance")[11], 951288.32)
  expect_near(loan_payment(r, 11), 81639.56)
  expect_near(c(-loan_row(r, "interest")[27], -loan_row(r, "repay")[27]), c(3139.98, 78499.58))
})

test_that("S2-T4/T4a: KfW 298 mit Teilauszahlung 40 %/60 %, 5 tilgungsfreie Jahre (35/5/10)", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 40L, construction_months = 24L,
                      construction_step_months = 12L)
  run <- function(amount, rate) {
    loan_run("annuity_loan", amount_eur = amount, rate_pa = rate, term_years = 35,
             grace_years = 5, fixed_years = 10, payments_per_year = 1L,
             draw_schedule = list(schedule = list("2027-12-31" = 0.4, "2028-12-31" = 0.6),
                                  unit = "share"), grid = g)
  }
  v1 <- run(3600000, 0.0219)
  expect_near(-loan_row(v1, "interest")[3], 31536)
  expect_near(-loan_row(v1, "interest")[4:8], rep(78840, 5))
  expect_true(all(loan_row(v1, "repay")[1:8] == 0))
  expect_near(loan_payment(v1, 8), 164969.40)
  expect_identical(g$year[9], 2034L)
  v2 <- run(5400000, 0.0294)
  expect_near(-loan_row(v2, "interest")[3], 63504)
  expect_near(-loan_row(v2, "interest")[4:8], rep(158760, 5))
  expect_near(loan_payment(v2, 8), 273371.56)
})

test_that("S2-T5/T6: Bankdarlehen mit Tilgungssatz 2 % und keep_payment, Restschuld 2036", {
  run <- function(amount) {
    loan_run("annuity_loan", amount_eur = amount, rate_pa = 0.04, initial_repayment_pa = 0.02,
             fixed_years = 10, payments_per_year = 1L, refi_rule = "keep_payment",
             grid = make_grid("annual", T = 12L))
  }
  v1 <- run(5100000)
  expect_near(loan_payment(v1, 1), 306000)
  expect_near(loan_row(v1, "balance")[11], 3875377.07, tol = 1)
  expect_near(loan_payment(v1, 11), 306000)
  expect_near(loan_payment(run(8700000), 1), 522000)
  v2 <- run(3858400)
  expect_near(loan_payment(v2, 1), 231504)
  expect_near(loan_row(v2, "balance")[11], 2931912.73, tol = 1)
})

test_that("S3-T7: Bankdarlehen 142.060 zu 3,9 %, 15 J.", {
  r <- loan_run("annuity_loan", amount_eur = 142060, rate_pa = 0.039, term_years = 15,
                fixed_years = 15, payments_per_year = 1L, grid = make_grid("annual", T = 15L))
  expect_near(loan_payment(r, 1), 12687.85)
  expect_near(loan_payment(r, 15), 12687.85)
  expect_near(loan_row(r, "balance")[16], 0, tol = 1e-6)
})

test_that("S4-T7: KfW 358 (2030, 2033), 25/3/10 zu 2,53 %, Auszahlung zum Ma\u00dfnahmentermin", {
  g <- make_grid("annual", T = 30L)
  a <- loan_run("annuity_loan", amount_eur = 70000, rate_pa = 0.0253, term_years = 25,
                grace_years = 3, fixed_years = 10, payments_per_year = 1L, start = "2030-01-01",
                grid = g)
  expect_identical(loan_row(a, "draw")[4], 70000)
  expect_near(-loan_row(a, "interest")[5:7], rep(1771, 3))
  expect_identical(g$year[8], 2033L)
  expect_near(loan_payment(a, 7), 4188.12)
  b <- loan_run("annuity_loan", amount_eur = 45000, rate_pa = 0.0253, term_years = 25,
                grace_years = 3, fixed_years = 10, payments_per_year = 1L, start = "2033-01-01",
                grid = g)
  expect_near(-loan_row(b, "interest")[8:10], rep(1138.50, 3))
  expect_near(loan_payment(b, 10), 2692.36)
})

test_that("S5-T4...T9: Monatsraten Bank (Tilgungssatz + Laufzeit) und KfW (35/5/10)", {
  g <- make_grid("annual", T = 12L)
  bank <- function(amount) {
    loan_run("annuity_loan", amount_eur = amount, rate_pa = 0.041, initial_repayment_pa = 0.02,
             term_years = 35, fixed_years = 10, payments_per_year = 12L,
             refi_rule = "keep_term",
             fees = list(commitment_fee_rate_month = 0.0025, commitment_free_months = 6L),
             grid = g)
  }
  kfw <- function(amount, rate) {
    loan_run("annuity_loan", amount_eur = amount, rate_pa = rate, term_years = 35,
             grace_years = 5, fixed_years = 10, payments_per_year = 12L, grid = g)
  }
  b1 <- bank(426400)
  k1 <- kfw(100000, 0.0219)
  b2 <- bank(384600)
  k2 <- kfw(170000, 0.01)
  # S5-T4: Jahre 1-5 Bankrate + KfW-Zinsen
  expect_near(b1$states[[2]]$inst, 2167.53)
  expect_near(-loan_row(k1, "interest")[2] / 12, 182.50)
  expect_near(b1$states[[2]]$inst + -loan_row(k1, "interest")[2] / 12, 2350.03, tol = 0.01)
  expect_near(b2$states[[2]]$inst, 1955.05)
  expect_near(-loan_row(k2, "interest")[2] / 12, 141.67)
  expect_true(all(loan_row(k1, "repay")[2:6] == 0))
  # S5-T5/T7: KfW-Annuität ab Monat 61
  expect_near(k1$states[[7]]$inst, 379.19)
  expect_near(k2$states[[7]]$inst, 546.79)
  expect_near(b1$states[[7]]$inst + k1$states[[7]]$inst, 2546.73, tol = 0.01)
  expect_near(b2$states[[7]]$inst + k2$states[[7]]$inst, 2501.84, tol = 0.01)
  # S5-T6: Restschulden nach 120 Monaten
  expect_near(loan_row(b1, "balance")[11], 321200.85, tol = 1)
  expect_near(loan_row(b2, "balance")[11], 289713.52)
  expect_near(loan_row(k1, "balance")[11], 87540.04)
  expect_near(loan_row(k2, "balance")[11], 145085.47)
  # S5-T9: Bank V1 2027 (Monatsuhr), KfW-Zinsen 2027; Bereitstellungsprovision ohne Wirkung
  expect_near(c(-loan_row(b1, "interest")[2], -loan_row(b1, "repay")[2],
                loan_row(b1, "balance")[2]), c(17320.31, 8690.09, 417709.91))
  expect_near(-loan_row(k1, "interest")[2], 2190)
  expect_true(all(loan_row(b1, "fees") == 0))
  # Anschluss ab 2037 nach keep_term (Fälligkeit 2062): Rate aus Restlaufzeit 25 Jahre
  expect_near(b1$states[[12]]$inst,
              inst_loan_annuity(loan_row(b1, "balance")[11], 0.04 / 12, 300))
})
