# Tests für R/type-inst-loan-core.R (WS-F; Spec 00 Abschnitte 8.1-8.10; Spec 01 Teil A 5.6).
# Prüfwerte (f), (h), L1-L11 aus Spec 00 8.10 und Spec 01 Teil A 5.6 (gerundete Tabellenwerte,
# Toleranz 0,005 EUR); Monatsuhr-Äquivalenz gegen die skalare Referenz in helper-ws-f.R.

# ---------------------------------------------------------------------------------------------
# Pflichtprüfwerte (f) und (h), Spec 00 8.10
# ---------------------------------------------------------------------------------------------

test_that("Test (f): Monatsannuit\u00e4t 100.000 zu 3,6 %, 240 Monate, Jahresraster", {
  r <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.036, term_years = 20,
                payments_per_year = 12L, grid = make_grid("annual", T = 2L))
  expect_near(r$state$inst, 585.11)
  expect_near(-loan_row(r, "interest")[2], 3542.98)
  expect_near(-loan_row(r, "repay")[2], 3478.36)
  expect_near(loan_row(r, "balance")[2], 96521.64)
  expect_identical(loan_row(r, "draw")[1], 100000)
  expect_true(all(loan_row(r, "repay_balloon") == 0))
  # Vertragsfrequenz und Aggregation: auf dem Raster mit monatlicher Bauphase sind die Summen je
  # Kalenderjahr identisch (8.10, 15.5 Nr. 6)
  gm <- make_grid("mixed", T = 2L)
  m <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.036, term_years = 20,
                payments_per_year = 12L, grid = gm)
  y27 <- gm$year == 2027L & gm$t > 0L
  expect_equal(sum(-loan_row(m, "interest")[y27]), sum(-loan_row(r, "interest")[2]),
               tolerance = 1e-12)
  expect_equal(sum(-loan_row(m, "repay")[y27]), -loan_row(r, "repay")[2], tolerance = 1e-12)
  expect_equal(loan_row(m, "balance")[gm$date_end == as.Date("2028-01-01")],
               loan_row(r, "balance")[2], tolerance = 1e-12)
})

test_that("Test (h): Ratendarlehen mit Zinsanpassung keep_term; keep_tilg_rate ist ein Fehler", {
  r <- loan_run("installment_loan", amount_eur = 120000, rate_pa = 0.02, term_years = 10,
                payments_per_year = 12L, fixed_years = 5, followup_rate_pa = 0.04)
  expect_equal(-loan_row(r, "repay")[2:11], rep(12000, 10))
  expect_near(r$state$inst, 1000)
  expect_near(-loan_row(r, "interest")[2], 2290)
  expect_near(loan_row(r, "balance")[6], 60000)
  expect_near(-loan_row(r, "interest")[7], 2180)
  expect_near(-loan_row(r, "repay")[7], 12000)
  expect_near(loan_row(r, "balance")[9], 24000)
  expect_near(loan_row(r, "balance")[11], 0)
  expect_identical(r$state$reset_months, 60L)
  expect_true("errors.refi_rule_invalid" %in%
                loan_val_codes("installment_loan", amount_eur = 120000, rate_pa = 0.02,
                               term_years = 10, fixed_years = 5, followup_rate_pa = 0.04,
                               refi_rule = "keep_tilg_rate"))
  expect_error(loan_run("installment_loan", amount_eur = 120000, rate_pa = 0.02, term_years = 10,
                        fixed_years = 5, followup_rate_pa = 0.04, refi_rule = "keep_tilg_rate"),
               class = "vofi_error_input")
})

# ---------------------------------------------------------------------------------------------
# Spec 01 Teil A 5.6: L1-L11
# ---------------------------------------------------------------------------------------------

l1_args <- function(...) {
  utils::modifyList(list(amount_eur = 1300000, rate_pa = 0.0365, payments_per_year = 1L,
                         term_years = 30, grace_years = 5, fixed_years = 10,
                         followup_rate_pa = 0.04, funding_id = "kfw261",
                         repayment_grant = list(amount_eur = 144400, date = "2028-01-01")),
                    list(...))
}

run_l1 <- function(...) {
  do.call(loan_run, c(list("annuity_loan"), l1_args(...),
                      list(grid = make_grid("annual", T = 30L))))
}

test_that("L1 (= S1-T8): KfW 261, Tilgungszuschuss shorten_term, keep_term mit n_eff (R-100)", {
  r <- run_l1()
  z <- -loan_row(r, "interest")
  rr <- -loan_row(r, "repay")
  b <- loan_row(r, "balance")
  expect_near(z[2], 47450)
  expect_near(loan_row(r, "repayment_grant")[2], 144400)
  expect_near(b[2], 1155600)
  expect_near(z[3:6], rep(42179.40, 4))
  expect_true(all(rr[1:6] == 0))
  expect_near(loan_payment(r, 6), 80165.66)
  expect_near(z[7], 42179.40)
  expect_near(rr[7], 37986.26)
  expect_near(b[11], 951288.32)
  expect_near(inst_loan_n_star(1L, b[11], 80165.66, 0.0365, 1L), 15.833415, tol = 5e-6)
  expect_near(r$state$inst, 81639.56)
  expect_near(z[12], 38051.53)
  expect_near(rr[12], 43588.03)
  expect_near(b[12], 907700.29)
  expect_near(z[27], 3139.98)
  expect_near(rr[27], 78499.58)
  expect_near(b[27], 0, tol = 1e-6)
  paid <- which(rr > 1e-6) - 1L
  expect_identical(length(paid), 21L)
  expect_identical(range(r$ctx$grid$year[paid + 1L]), c(2032L, 2052L))
  expect_true(all(loan_row(r, "repay_balloon") == 0))
  # gleiche Gutschrift als Anteil der Zusage (Förderkredit, 01b 4.6): 144.400 / 1.300.000
  s <- run_l1(repayment_grant = list(share = 144400 / 1300000, date = "2028-01-01"))
  expect_equal(loan_row(s, "repayment_grant"), loan_row(r, "repayment_grant"), tolerance = 1e-12)
  expect_equal(loan_row(s, "balance"), b, tolerance = 1e-12)
})

test_that("L2 (= S1-T8a): L1 mit reduce_installment", {
  r <- run_l1(repayment_grant = list(amount_eur = 144400, date = "2028-01-01",
                                     effect = "reduce_installment"))
  expect_near(loan_payment(r, 6), 71261.11)
  expect_near(loan_row(r, "balance")[11], 999182.07)
  expect_near(loan_payment(r, 11), 73521.57)
  expect_near(r$state$inst, 73521.57)
})

test_that("L3: monatliche Bauphase, Teilauszahlungen, Bereitstellungsprovision, Tilgungsbeginn", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 3L, construction_months = 6L,
                      construction_step_months = 1L)
  expect_identical(g$months, c(0L, 1L, 1L, 1L, 1L, 1L, 1L, 6L, 12L, 12L))
  r <- loan_run("annuity_loan", amount_eur = 300000, rate_pa = 0.02, payments_per_year = 12L,
                term_years = 10, grace_years = 1, start = "2027-02-01",
                draw_schedule = list(schedule = list("2027-02-01" = 100000,
                                                     "2027-05-01" = 100000,
                                                     "2027-07-01" = 100000), unit = "eur"),
                fees = list(commitment_fee_rate_month = 0.0015, commitment_free_months = 2L,
                            commitment_date = "2027-01-01"),
                grid = g)
  z <- loan_row(r, "interest")
  f <- loan_row(r, "fees")
  expect_near(z[3:10], c(-166.67, -166.67, -166.67, -333.33, -333.33, -3000, -5936.42,
                         -5410.71))
  expect_near(f[4:7], c(-300, -300, -150, -150))
  expect_true(all(f[c(1:3, 8:10)] == 0))
  expect_near(loan_row(r, "repay")[9:10], c(-15289.07, -31040.27))
  expect_near(loan_row(r, "balance")[9:10], c(284710.93, 253670.66))
  expect_near(r$state$inst, 3037.58)
  expect_near(-sum(z), 15513.80)
  expect_near(-sum(f), 900)
  expect_identical(loan_row(r, "draw")[c(2, 5, 7)], rep(100000, 3))
})

test_that("L4: endf\u00e4llig, quartalsweise, Disagio und Bearbeitungsgeb\u00fchr", {
  r <- loan_run("bullet_loan", amount_eur = 100000, rate_pa = 0.05, payments_per_year = 4L,
                term_years = 5, payout_rate = 0.97, fees = list(processing_fee_share = 0.01),
                grid = make_grid("annual", T = 6L))
  expect_near(loan_row(r, "draw")[1], 97000)
  expect_near(loan_row(r, "fees")[1], -1000)
  expect_near(loan_row(r, "disagio")[1], 3000)
  expect_near(loan_row(r, "balance")[1], 100000)
  expect_near(loan_row(r, "interest")[2:6], rep(-5000, 5))
  expect_near(loan_row(r, "repay_balloon")[6], -100000)
  expect_true(all(loan_row(r, "repay") == 0))
  expect_identical(loan_row(r, "balance")[7], 0)
})

test_that("L5: Tilgungssatz, geplante Sondertilgung mit Obergrenze 5 % p. a.", {
  r <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.03, initial_repayment_pa = 0.02,
                payments_per_year = 12L, prepay_cap_share_pa = 0.05,
                planned_prepayments = list(schedule = list("2029-01-01" = 10000)),
                grid = make_grid("annual", T = 6L))
  expect_near(r$state$inst, 416.67)
  expect_near(c(loan_row(r, "interest")[2], loan_row(r, "repay")[2], loan_row(r, "balance")[2]),
              c(-2972.27, -2027.73, 97972.27))
  expect_near(c(loan_row(r, "interest")[3], loan_row(r, "repay")[3], loan_row(r, "prepay")[3],
                loan_row(r, "balance")[3]), c(-2910.59, -2089.41, -5000, 90882.86))
  expect_near(c(loan_row(r, "interest")[4], loan_row(r, "repay")[4], loan_row(r, "balance")[4]),
              c(-2694.96, -2305.04, 88577.83))
  expect_true(is.infinite(r$state$m_mat))
})

test_that("L6: Bestandsdarlehen mit vertraglicher Rate, Restbindung 3 J., keep_payment", {
  r <- loan_run("annuity_loan", amount_eur = 400000, rate_pa = 0.025, existing = TRUE,
                installment_eur = 2000, payments_per_year = 12L, fixed_years = 3,
                followup_rate_pa = 0.045, refi_rule = "keep_payment",
                grid = make_grid("annual", T = 10L))
  expect_identical(loan_row(r, "assumed")[1], 400000)
  expect_true(all(loan_row(r, "assumed")[-1] == 0))
  expect_true(all(loan_row(r, "draw") == 0))
  expect_true(all(loan_row(r, "fees") == 0))
  expect_identical(loan_row(r, "balance")[1], 400000)
  expect_near(c(loan_row(r, "interest")[2], loan_row(r, "repay")[2], loan_row(r, "balance")[2]),
              c(-9838.46, -14161.54, 385838.46))
  expect_near(loan_row(r, "balance")[4], 356431.97)
  expect_near(c(loan_row(r, "interest")[5], loan_row(r, "repay")[5]), c(-15873.18, -8126.82))
  expect_near(loan_row(r, "balance")[6], 339804.99)
  expect_identical(r$state$inst, 2000)
  expect_false(any(r$state$neg_amort))
  # Bestandsdarlehen: alle Ledger-Zeilen mit existing_debt = TRUE (Engine, 7.4, 8.4)
  rows <- eng_loan_rows("k", 1L, r$comp, reg_get("instrument", "annuity_loan"))
  expect_true(all(rows$existing_debt))
})

test_that("L7: Tilgungssatz j\u00e4hrlich, Anschluss 5 % mit keep_tilg_rate", {
  r <- loan_run("annuity_loan", amount_eur = 200000, rate_pa = 0.035, initial_repayment_pa = 0.02,
                payments_per_year = 1L, fixed_years = 5, followup_rate_pa = 0.05)
  expect_identical(r$state$par$refi_rule, "keep_tilg_rate")
  expect_near(c(loan_row(r, "interest")[2], loan_row(r, "repay")[2]), c(-7000, -4000))
  expect_near(loan_row(r, "balance")[6], 178550.14)
  expect_near(r$state$inst, 12498.51)
  expect_equal(r$state$inst, loan_row(r, "balance")[6] * 0.07, tolerance = 1e-12)
  expect_near(c(loan_row(r, "interest")[7], loan_row(r, "repay")[7]), c(-8927.51, -3571.00))
})

test_that("L8: Ratendarlehen mit Tilgungszuschuss 12.000 in t = 2, reduce_installment", {
  r <- loan_run("installment_loan", amount_eur = 120000, rate_pa = 0.02, payments_per_year = 1L,
                term_years = 10, measure_id = "m1",
                repayment_grant = list(amount_eur = 12000, year = 2029L,
                                       effect = "reduce_installment"))
  expect_near(c(loan_row(r, "interest")[2], loan_row(r, "repay")[2]), c(-2400, -12000))
  expect_near(c(loan_row(r, "repay")[3], loan_row(r, "repayment_grant")[3],
                loan_row(r, "balance")[3]), c(-12000, 12000, 84000))
  expect_near(c(loan_row(r, "interest")[4], loan_row(r, "repay")[4]), c(-1680, -10500))
  expect_near(loan_row(r, "balance")[11], 0, tol = 1e-6)
})

test_that("L9: L1 mit approved = 0 je Lauf: alle Zeilen 0, auch die Bereitstellungsprovision", {
  args <- l1_args(start = "2028-01-01",
                  fees = list(commitment_fee_rate_month = 0.0015, commitment_free_months = 6L,
                              commitment_date = "2027-01-01"))
  g <- make_grid("annual", T = 30L)
  dr <- fake_draws(2L, g, static = list("financing.k.approved" = c(0, 1)))
  r <- do.call(loan_run, c(list("annuity_loan"), args, list(grid = g, n = 2L, draws = dr)))
  for (x in loan_cols()) expect_true(all(r$m[[x]][1L, ] == 0), info = x)
  expect_near(r$m$fees[2L, 2L], -6 * 0.0015 * 1300000)
  expect_near(r$m$balance[2L, 2L], 1155600)
})

test_that("L10: L1 mit cut_share = 0,5 je Lauf", {
  g <- make_grid("annual", T = 30L)
  dr <- fake_draws(2L, g, static = list("financing.k.repayment_grant.cut_share" = c(0.5, 0)))
  r <- do.call(loan_run, c(list("annuity_loan"), l1_args(), list(grid = g, n = 2L, draws = dr)))
  expect_near(r$m$repayment_grant[, 2L], c(72200, 144400))
  expect_near(r$m$balance[, 2L], c(1227800, 1155600))
})

test_that("L11: Tilgungssatz und Laufzeit zugleich (R-100): Schlusstilgung bei F\u00e4lligkeit", {
  r <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.03, initial_repayment_pa = 0.02,
                payments_per_year = 12L, term_years = 10)
  expect_near(r$state$inst, 416.67)
  expect_near(c(loan_row(r, "interest")[2], loan_row(r, "repay")[2], loan_row(r, "balance")[2]),
              c(-2972.27, -2027.73, 97972.27))
  expect_near(c(loan_row(r, "interest")[11], loan_row(r, "repay")[11],
                loan_row(r, "repay_balloon")[11]), c(-2344.64, -2655.36, -76709.76))
  expect_identical(loan_row(r, "balance")[11], 0)
  expect_true("msg.balloon_at_maturity" %in%
                loan_val_codes("annuity_loan", amount_eur = 100000, rate_pa = 0.03,
                               initial_repayment_pa = 0.02, term_years = 10))
})

# ---------------------------------------------------------------------------------------------
# Referenzsemantik Monatsuhr (8.1 Nr. 3), Rasterinvarianz (15.5 Nr. 6)
# ---------------------------------------------------------------------------------------------

loan_cases <- function() {
  list(
    ann_monthly = list(type = "annuity_loan", amount_eur = 250000, rate_pa = 0.031,
                       term_years = 25, payments_per_year = 12L, grace_years = 0.5,
                       fixed_years = 2, followup_fixed_years = 1.5, followup_rate_pa = 0.045,
                       payout_rate = 0.99, fees = list(processing_fee_share = 0.005)),
    ann_quarter_tz = list(type = "annuity_loan", amount_eur = 400000, rate_pa = 0.0255,
                          term_years = 20, grace_years = 1, payments_per_year = 4L,
                          fixed_years = 3, followup_rate_pa = 0.05, funding_id = "f",
                          draw_schedule = list(schedule = list("2027-01-01" = 0.25,
                                                               "2027-10-01" = 0.75),
                                               unit = "share"),
                          fees = list(commitment_fee_rate_month = 0.0025,
                                      commitment_free_months = 1L),
                          repayment_grant = list(share = 0.15, date = "2029-01-01"),
                          planned_prepayments = list(schedule = list("2031-01-01" = 30000)),
                          prepay_cap_share_pa = 0.05),
    ann_tau_ktr = list(type = "annuity_loan", amount_eur = 180000, rate_pa = 0.042,
                       initial_repayment_pa = 0.025, payments_per_year = 12L, fixed_years = 4,
                       followup_rate_pa = 0.06, followup_repayment_pa = 0.03,
                       round_payments = TRUE),
    ann_reduce = list(type = "annuity_loan", amount_eur = 150000, rate_pa = 0.02,
                      term_years = 15, payments_per_year = 1L, fixed_years = 5,
                      followup_rate_pa = 0.035, measure_id = "m1",
                      repayment_grant = list(amount_eur = 20000, year = 2030L,
                                             effect = "reduce_installment")),
    inst_shorten = list(type = "installment_loan", amount_eur = 150000, rate_pa = 0.02,
                        term_years = 10, grace_years = 2, payments_per_year = 1L,
                        fixed_years = 5, followup_rate_pa = 0.03, measure_id = "m1",
                        repayment_grant = list(amount_eur = 22500, date = "2028-01-01")),
    inst_monthly = list(type = "installment_loan", amount_eur = 90000, rate_pa = 0.028,
                        term_years = 8, payments_per_year = 12L, fixed_years = 3,
                        followup_rate_pa = 0.041, refi_rule = "keep_payment",
                        planned_prepayments = list(schedule = list("2029-07-01" = 4000))),
    bullet_reset = list(type = "bullet_loan", amount_eur = 80000, rate_pa = 0.04,
                        term_years = 7, payments_per_year = 1L, fixed_years = 3,
                        followup_rate_pa = 0.055, followup_spread_pa = 0.005,
                        start = "2027-07-01"),
    existing = list(type = "annuity_loan", amount_eur = 220000, rate_pa = 0.019,
                    existing = TRUE, term_years = 12, payments_per_year = 12L,
                    fixed_years = 2, followup_rate_pa = 0.044),
    # Volltilgung innerhalb einer Folge einfacher Monatsraten (Laufzeitverkürzung durch TZ)
    ann_payoff = list(type = "annuity_loan", amount_eur = 100000, rate_pa = 0.03,
                      term_years = 10, payments_per_year = 12L, funding_id = "f",
                      repayment_grant = list(share = 0.45, date = "2028-01-01")),
    inst_payoff = list(type = "installment_loan", amount_eur = 100000, rate_pa = 0.03,
                       term_years = 10, payments_per_year = 4L, funding_id = "f",
                       repayment_grant = list(amount_eur = 41000, date = "2028-01-01")),
    # Rate <= Zins in einer Folge (keep_payment nach Zinsanstieg)
    ann_negative = list(type = "annuity_loan", amount_eur = 100000, rate_pa = 0.01,
                        existing = TRUE, installment_eur = 300, payments_per_year = 12L,
                        fixed_years = 2, followup_rate_pa = 0.06, refi_rule = "keep_payment")
  )
}

test_that("Ereignisrechnung = Monatsuhr (8.1 Nr. 3) auf Jahres-, Bauphasen- und Quartalsraster", {
  grids <- list(annual = make_grid("annual", T = 12L), mixed = make_grid("mixed", T = 12L),
                quarter = vofi_time_grid(as.Date("2027-01-01"), 12L, construction_months = 12L,
                                         construction_step_months = 3L))
  for (nm in names(loan_cases())) {
    a <- loan_cases()[[nm]]
    for (gn in names(grids)) {
      g <- grids[[gn]]
      # ann_negative warnt erwartungsgemäß (keep_payment mit Rate <= Zins)
      run <- suppressWarnings(do.call(loan_run, c(list(a$type), a[setdiff(names(a), "type")],
                                                  list(grid = g))))
      ref <- loan_ref_clock(g, a$type, a)
      expect_equal(loan_as_matrix(run), ref, tolerance = 1e-9, info = paste(nm, gn))
    }
  }
})

test_that("Geschlossene Folgen: gemischte L\u00e4ufe mit und ohne Volltilgung in der Folge", {
  g <- make_grid("annual", T = 12L)
  cut <- c(0, 0.3, 0.9, 1)
  rate <- c(0.03, 0.05, 0.02, 0)
  dr <- fake_draws(4L, g, static = list("financing.k.repayment_grant.cut_share" = cut,
                                        "financing.k.rate_pa" = rate))
  a <- loan_cases()$ann_payoff
  run <- do.call(loan_run, c(list(a$type), a[setdiff(names(a), "type")],
                             list(grid = g, n = 4L, draws = dr)))
  for (i in seq_along(cut)) {
    ai <- a
    ai$rate_pa <- rate[i]
    ai$repayment_grant$cut_share <- cut[i]
    expect_equal(loan_as_matrix(run, i), loan_ref_clock(g, a$type, ai), tolerance = 1e-9,
                 info = paste("Lauf", i))
  }
  expect_true(loan_row(run, "balance", 1L)[8] < 1e-6)
  expect_true(loan_row(run, "balance", 4L)[8] > 1000)
})

test_that("Rasterinvarianz der Kredite (15.5 Nr. 6): Kalenderjahre identisch", {
  ga <- make_grid("annual", T = 12L)
  gm <- make_grid("mixed", T = 12L)
  for (nm in c("ann_monthly", "ann_reduce", "inst_shorten", "existing")) {
    a <- loan_cases()[[nm]]
    ra <- do.call(loan_run, c(list(a$type), a[setdiff(names(a), "type")], list(grid = ga)))
    rm <- do.call(loan_run, c(list(a$type), a[setdiff(names(a), "type")], list(grid = gm)))
    for (x in setdiff(loan_cols(), "balance")) {
      for (y in unique(ga$year[-1L])) {
        sa <- sum(loan_row(ra, x)[-1L][ga$year[-1L] == y])
        sm <- sum(loan_row(rm, x)[-1L][gm$year[-1L] == y])
        expect_equal(sm, sa, tolerance = 1e-9, info = paste(nm, x, y))
      }
      expect_equal(loan_row(rm, x)[1L], loan_row(ra, x)[1L], info = paste(nm, x, "t0"))
    }
    common <- ga$date_end %in% gm$date_end
    expect_equal(loan_row(rm, "balance")[gm$date_end %in% ga$date_end],
                 loan_row(ra, "balance")[common], tolerance = 1e-9, info = nm)
  }
})

# ---------------------------------------------------------------------------------------------
# Laufspezifische Größen, Batch-Invarianz, kein RNG, Cache
# ---------------------------------------------------------------------------------------------

test_that("Batch-Invarianz: Zins, Bewilligung, K\u00fcrzung, Anschlusszinspfad je Lauf (F7)", {
  g <- make_grid("annual", T = 6L)
  n <- 7L
  i <- seq_len(n) - 1
  dr <- fake_draws(n, g,
                   static = list("financing.k.rate_pa" = 0.02 + 0.004 * i,
                                 "financing.k.approved" = c(1, 0, 1, 1, 0, 1, 1),
                                 "financing.k.repayment_grant.cut_share" = 0.1 * i,
                                 "financing.k.prepay_cap_share_pa" = 0.02 + 0.01 * i),
                   paths = list("market.mortgage_rate" = outer(0.03 + 0.005 * i,
                                                               rep(1, g$T + 1L))))
  fun <- function(nn, draws) {
    r <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.03, term_years = 10,
                  payments_per_year = 12L, fixed_years = 2, grace_years = 1, measure_id = "m1",
                  repayment_grant = list(share = 0.1, date = "2028-01-01"),
                  planned_prepayments = list(schedule = list("2029-01-01" = 6000)),
                  grid = g, n = nn, draws = draws)
    r$m
  }
  expect_batch_invariance(fun, n = n, grid = g, draws = dr)
  b <- fun(n, dr)
  expect_true(all(b$draw[c(2, 5), ] == 0) && all(b$balance[c(2, 5), ] == 0))
  expect_false(isTRUE(all.equal(b$interest[1, ], b$interest[3, ])))
})

test_that("Instrumente ziehen keine Zufallszahlen und ver\u00e4ndern keinen Zustand (F8, Cache)", {
  comp <- make_component("annuity_loan", amount_eur = 50000, rate_pa = 0.03, term_years = 5,
                         payments_per_year = 4L, fixed_years = 2, id = "k")
  g <- make_grid("mixed", T = 6L)
  ctx <- loan_ctx(comp, g, n = 3L)
  def <- reg_get("instrument", "annuity_loan")
  expect_no_rng(st0 <- def$init(comp, ctx))
  expect_identical(def$init(comp, ctx), st0)
  st <- st0
  for (t in 0:g$T) {
    expect_no_rng(r1 <- def$step(st, t, ctx))
    r2 <- def$step(st, t, ctx)
    expect_identical(r1, r2)
    st <- r1$state
  }
  expect_no_rng(def$capacity(st, g$T, ctx))
  expect_no_rng(def$prepay(st, rep(100, 3), g$T, ctx))
  expect_s3_class(st, "vofi_inst_state")
  expect_true(all(c("B", "drawn", "commitment", "i_pa", "inst", "accrued", "tz_amount",
                    "approved", "prepaid_ytd", "tau", "neg_amort", "repayment", "ppy",
                    "pay_interval", "t_first_draw", "m_start", "m_A", "m_rep", "m_mat",
                    "reset_months", "fee_free_until", "inst_set", "t_tz", "draws", "planned",
                    "followup", "par") %in% names(st)))
  expect_identical(dim(st$draws), c(3L, g$T + 1L))
})

test_that("Vertragstests (Pr\u00fcfkit) f\u00fcr alle drei Kredittypen", {
  for (nm in c("annuity_loan", "installment_loan", "bullet_loan")) {
    expect_type_contract(nm, "instrument")
  }
})

# ---------------------------------------------------------------------------------------------
# Zinsbindung, Anschlusszins, Ratenregeln (8.6)
# ---------------------------------------------------------------------------------------------

test_that("Anschlusszins aus dem Pfad: Wert der Periode, in der der Anpassungsmonat endet (R-45)", {
  g <- make_grid("annual", T = 10L)
  path <- 0.03 + 0.001 * seq_len(g$T + 1L)
  dr <- fake_draws(1L, g, paths = list("market.mortgage_rate" = path))
  r <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.02, term_years = 20,
                payments_per_year = 1L, fixed_years = 3, followup_fixed_years = 2,
                followup_spread_pa = 0.01, grid = g, draws = dr)
  expect_identical(r$state$reset_months, c(36L, 60L, 84L, 108L))
  rates <- vapply(r$states, function(s) s$i_pa, numeric(1))
  # Anpassung zu Beginn von Monat 37 (2030): Spalte der Periode, in der Monat 36 endet (t = 3)
  expect_equal(rates, c(rep(0.02, 4), rep(path[4] + 0.01, 2), rep(path[6] + 0.01, 2),
                        rep(path[8] + 0.01, 2), path[10] + 0.01), tolerance = 1e-12)
  cap <- reg_get("instrument", "annuity_loan")$capacity(r$state, 10L, r$ctx)
  expect_equal(cap$rate_pa, path[10] + 0.01, tolerance = 1e-12)
  ref <- loan_ref_clock(g, "annuity_loan",
                        list(amount_eur = 100000, rate_pa = 0.02, term_years = 20,
                             payments_per_year = 1L, fixed_years = 3, followup_fixed_years = 2,
                             followup_spread_pa = 0.01), followup = path)
  expect_equal(loan_as_matrix(r), ref, tolerance = 1e-9)
})

test_that("Zinsanpassung vor Tilgungsbeginn \u00e4ndert nur den Zins (8.6, R-45)", {
  r <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.02, term_years = 12,
                grace_years = 4, payments_per_year = 1L, fixed_years = 2, followup_rate_pa = 0.05)
  expect_near(-loan_row(r, "interest")[2:5], c(2000, 2000, 5000, 5000))
  expect_near(loan_payment(r, 5), 100000 * 0.05 / (1 - 1.05^-8))
})

test_that("keep_payment: negative Tilgung wird markiert und gewarnt (vofi_warning_engine)", {
  run_neg <- function() {
    loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.02, existing = TRUE,
             installment_eur = 300, payments_per_year = 12L, fixed_years = 1,
             followup_rate_pa = 0.05, refi_rule = "keep_payment",
             grid = make_grid("annual", T = 3L))
  }
  expect_warning(run_neg(), class = "vofi_warning_engine")
  r <- suppressWarnings(run_neg())
  expect_true(all(r$state$neg_amort))
  expect_true(all(loan_row(r, "repay")[3:4] == 0))
  expect_near(loan_row(r, "balance")[3], loan_row(r, "balance")[2])
  expect_true("msg.negative_amortization" %in%
                loan_val_codes("annuity_loan", amount_eur = 100000, rate_pa = 0.06,
                               installment_eur = 400, payments_per_year = 12L, term_years = 30))
})

test_that("keep_term nach shorten_term bei Ratentilgung: effektive Restzahl (R-100)", {
  r <- loan_run("installment_loan", amount_eur = 150000, rate_pa = 0.02, term_years = 10,
                grace_years = 2, payments_per_year = 1L, fixed_years = 5, followup_rate_pa = 0.03,
                measure_id = "m1", repayment_grant = list(amount_eur = 22500, date = "2028-01-01"))
  # Rate 18.750 auf Basis der Zusage; nach Gutschrift 127.500: 18.750 je Jahr bis zur Anpassung
  expect_near(-loan_row(r, "repay")[4:6], rep(18750, 3))
  b5 <- loan_row(r, "balance")[6]
  expect_near(b5, 127500 - 3 * 18750)
  # n* = 71.250 / 18.750 = 3,8 -> n_eff = 4 statt n_rem = 5; Rate 71.250 / 4
  expect_near(r$state$inst, b5 / 4)
  expect_near(loan_row(r, "balance")[10], 0, tol = 1e-6)
  expect_true(all(loan_row(r, "repay")[11] == 0))
})

test_that("keep_tilg_rate ohne Tilgungssatz und keep_term ohne Laufzeit sind Fehler", {
  expect_error(loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.02, term_years = 10,
                        fixed_years = 2, followup_rate_pa = 0.04, refi_rule = "keep_tilg_rate"),
               class = "vofi_error_input")
  expect_error(loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.02, existing = TRUE,
                        installment_eur = 800, fixed_years = 2, followup_rate_pa = 0.04),
               class = "vofi_error_input")
  r <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.02, existing = TRUE,
                installment_eur = 800, fixed_years = 2, followup_rate_pa = 0.04,
                refi_rule = "keep_payment")
  expect_identical(r$state$inst, 800)
})

test_that("Zins 0 und negativer Zins: Annuit\u00e4t B / n bzw. Formel", {
  r <- loan_run("annuity_loan", amount_eur = 120000, rate_pa = 0, term_years = 10,
                payments_per_year = 12L)
  expect_near(r$state$inst, 1000)
  expect_true(all(loan_row(r, "interest") == 0))
  expect_near(loan_row(r, "balance")[11], 0, tol = 1e-6)
  n <- loan_run("annuity_loan", amount_eur = 120000, rate_pa = -0.005, term_years = 10,
                payments_per_year = 1L)
  expect_near(n$state$inst, 120000 * -0.005 / (1 - 0.995^-10))
  expect_near(loan_row(n, "balance")[11], 0, tol = 1e-6)
  expect_true(all(loan_row(n, "interest")[2:11] > 0))
})

test_that("round_payments: Raten auf Cent bei Festlegung und Anpassung", {
  r <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.036, term_years = 20,
                payments_per_year = 12L, fixed_years = 1, followup_rate_pa = 0.041,
                round_payments = TRUE, grid = make_grid("annual", T = 3L))
  expect_identical(r$states[[2]]$inst, 585.11)
  expect_identical(round(r$state$inst, 2), r$state$inst)
  u <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.036, term_years = 20,
                payments_per_year = 12L, grid = make_grid("annual", T = 1L))
  expect_false(identical(round(u$state$inst, 2), u$state$inst))
})

# ---------------------------------------------------------------------------------------------
# Tilgungszuschuss (8.5 (j), 8.6)
# ---------------------------------------------------------------------------------------------

test_that("Tilgungszuschuss: Default-Termin, Bezug auf den abgerufenen Betrag, Kappung", {
  g <- make_grid("annual", T = 8L)
  # Default: spätere von Fertigstellung der Maßnahme und Ende der letzten Auszahlungsperiode
  r <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.03, term_years = 10,
                payments_per_year = 1L, measure_id = "m1", repayment_grant = list(share = 0.2),
                grid = g,
                spec_fun = function(s) {
                  path_set(s, "measures.m1", list(completion_date = as.Date("2029-10-01")))
                })
  expect_identical(r$state$t_tz, 3L)
  expect_near(loan_row(r, "repayment_grant")[4], 20000)
  r2 <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.03, term_years = 10,
                 payments_per_year = 1L, funding_id = "f", repayment_grant = list(share = 0.2),
                 draw_schedule = list(schedule = list("2027-01-01" = 0.5, "2029-01-01" = 0.5),
                                      unit = "share"), grid = g)
  expect_identical(r2$state$t_tz, 2L)
  # Bezug auf min(Zusage, abgerufen): nur 60.000 abgerufen (Plan in EUR unter der Zusage)
  r3 <- loan_run("bullet_loan", amount_eur = 100000, rate_pa = 0.03, term_years = 5,
                 payments_per_year = 1L, funding_id = "f",
                 draw_schedule = list(schedule = list("2027-01-01" = 60000), unit = "eur"),
                 repayment_grant = list(share = 0.25, date = "2028-01-01"), grid = g)
  expect_near(loan_row(r3, "repayment_grant")[2], 15000)
  # Kappung auf den Bestand mit Hinweis (Anteil der Läufe)
  run_cap <- function() {
    loan_run("bullet_loan", amount_eur = 10000, rate_pa = 0.03, term_years = 5,
             payments_per_year = 1L, funding_id = "f",
             repayment_grant = list(amount_eur = 9000, date = "2028-01-01"),
             planned_prepayments = list(schedule = list("2028-01-01" = 5000)), grid = g)
  }
  expect_message(run_cap(), class = "vofi_message")
  r4 <- suppressMessages(run_cap())
  expect_near(loan_row(r4, "repayment_grant")[2], 5000)
  expect_identical(loan_row(r4, "balance")[2], 0)
  # Gutschrift nach dem Horizont entfällt
  r5 <- loan_run("bullet_loan", amount_eur = 10000, rate_pa = 0.03, term_years = 5,
                 payments_per_year = 1L, funding_id = "f",
                 repayment_grant = list(amount_eur = 1000, year = 2040L), grid = g)
  expect_true(is.na(r5$state$t_tz))
  expect_true(all(loan_row(r5, "repayment_grant") == 0))
})

test_that("Tilgungszuschuss mit reduce_installment in der Tilgungsphase und mit tau", {
  r <- loan_run("annuity_loan", amount_eur = 200000, rate_pa = 0.04, initial_repayment_pa = 0.03,
                payments_per_year = 1L, measure_id = "m1",
                repayment_grant = list(amount_eur = 50000, date = "2030-01-01",
                                       effect = "reduce_installment"))
  b3 <- loan_row(r, "balance")[4]
  expect_near(r$states[[4]]$inst, b3 * 0.07)
  expect_near(loan_payment(r, 4), b3 * 0.07)
})

# ---------------------------------------------------------------------------------------------
# Auszahlung, Gebühren, Bewilligung, Bestandsdarlehen, auto/topup (8.2, 8.5 (h), 8.7)
# ---------------------------------------------------------------------------------------------

test_that("Auszahlungsplan in EUR, sp\u00e4ter Start, Geb\u00fchr mit der ersten Auszahlung", {
  r <- loan_run("installment_loan", amount_eur = 90000, rate_pa = 0.03, term_years = 9,
                payments_per_year = 1L, start = "2028-01-01",
                draw_schedule = list(schedule = list("2028-01-01" = 30000,
                                                     "2029-01-01" = 60000), unit = "eur"),
                fees = list(processing_fee_share = 0.01))
  expect_identical(loan_row(r, "draw")[1:4], c(0, 30000, 60000, 0))
  expect_identical(loan_row(r, "fees")[2], -900)
  expect_identical(r$state$m_start, 12L)
  expect_identical(r$state$m_A, 24L)
  expect_near(-loan_row(r, "interest")[3:4], c(900, 2700))
  expect_near(-loan_row(r, "repay")[4], 10000)
})

test_that("Bereitstellungsprovision: Zusagedatum mitten im Monat, approved je Lauf", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 2L, construction_months = 6L,
                      construction_step_months = 1L)
  dr <- fake_draws(2L, g, static = list("financing.k.approved" = c(1, 0)))
  r <- loan_run("bullet_loan", amount_eur = 100000, rate_pa = 0.03, term_years = 5,
                payments_per_year = 1L, start = "2027-05-01",
                fees = list(commitment_fee_rate_month = 0.002, commitment_free_months = 1L,
                            commitment_date = "2027-01-15"), grid = g, n = 2L, draws = dr)
  # Zusage 15.01. -> Frist ab 01.02., ein freier Monat: Provision in März und April
  expect_equal(r$m$fees[1L, 1:6], c(0, 0, 0, -200, -200, 0))
  expect_true(all(r$m$fees[2L, ] == 0))
  expect_true(all(r$m$balance[2L, ] == 0))
})

test_that("Bestandsdarlehen: approved ohne Wirkung, keine Geb\u00fchren, Rate aus Restlaufzeit", {
  g <- make_grid("annual", T = 6L)
  dr <- fake_draws(2L, g, static = list("financing.k.approved" = c(0, 1)))
  r <- loan_run("installment_loan", amount_eur = 60000, rate_pa = 0.02, existing = TRUE,
                term_years = 6, payments_per_year = 1L, grid = g, n = 2L, draws = dr)
  expect_identical(r$m$assumed[, 1L], c(60000, 60000))
  expect_identical(r$m$balance[1L, ], r$m$balance[2L, ])
  expect_near(-r$m$repay[1L, 2:7], rep(10000, 6))
  expect_identical(r$state$m_A, 0L)
})

test_that("amount_eur auto bzw. topup: Zusage und Plan aus ctx$auto(), Fenster der Bauphase", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 4L, construction_months = 12L,
                      construction_step_months = 6L)
  expect_identical(g$phase[1:3], rep("construction", 3))
  n <- 2L
  dmat <- matrix(0, n, g$T + 1L)
  dmat[, 2L] <- c(40000, 50000)
  dmat[, 3L] <- c(10000, 0)
  auto <- function(id) list(commitment = c(50000, 50000), draws = dmat)
  path <- matrix(c(0.03, 0.035, 0.04, 0.05, 0.05, 0.05), n, g$T + 1L, byrow = TRUE)
  dr <- fake_draws(n, g, paths = list("financing.k.rate_pa" = path))
  r <- loan_run("annuity_loan", amount_eur = "topup", rate_pa = 0.04, term_years = 10,
                payments_per_year = 1L, fees = list(processing_fee_share = 0.01),
                grid = g, n = n, draws = dr, auto = auto)
  expect_identical(r$m$draw[, 2L], c(40000, 50000))
  expect_identical(r$m$draw[, 3L], c(10000, 0))
  # Bearbeitungsgebühr in der ersten Fensterperiode (t0), m_A = Ende der letzten Fensterperiode
  expect_identical(r$m$fees[, 1L], c(-500, -500))
  expect_identical(r$state$m_A, 12L)
  expect_identical(r$state$t_first_draw, 0L)
  # topup: Zins der letzten Fensterperiode (t = 2) des Laufpfads
  expect_identical(r$state$i_pa, c(0.04, 0.04))
  expect_near(loan_payment(r, 3), 50000 * 0.04 / (1 - 1.04^-10))
  a <- loan_run("annuity_loan", amount_eur = "auto", rate_pa = 0.04, term_years = 10,
                payments_per_year = 1L, grid = g, n = n, auto = auto)
  expect_identical(a$m$draw[, 3L], c(10000, 0))
  expect_error(loan_run("annuity_loan", amount_eur = "auto", rate_pa = 0.04, term_years = 10,
                        grid = g),
               class = "vofi_error_contract")
})

test_that("Kredit ohne Auszahlung im Horizont entf\u00e4llt; Termin vor dem Stichtag: Fehler", {
  g <- make_grid("annual", T = 3L)
  expect_message(r <- loan_run("bullet_loan", amount_eur = 50000, rate_pa = 0.03, term_years = 5,
                               payments_per_year = 1L, start = "2031-01-01", grid = g),
                 class = "vofi_message")
  for (x in loan_cols()) expect_true(all(loan_row(r, x) == 0), info = x)
  expect_identical(reg_get("instrument", "bullet_loan")$capacity(r$state, 3L, r$ctx)$cap, 0)
  expect_error(loan_run("bullet_loan", amount_eur = 50000, rate_pa = 0.03, term_years = 5,
                        start = "2026-01-01", grid = g), class = "vofi_error_input")
})

test_that("Laufzeitfehler: Vertragsfrequenz, fehlende Laufzeit", {
  expect_error(loan_run("bullet_loan", amount_eur = 50000, rate_pa = 0.03, term_years = 5,
                        payments_per_year = 2L), class = "vofi_error_input")
  expect_error(loan_run("bullet_loan", amount_eur = 50000, rate_pa = 0.03),
               class = "vofi_error_input")
  expect_error(loan_run("installment_loan", amount_eur = 50000, rate_pa = 0.03, term_years = 0),
               class = "vofi_error_input")
})

# ---------------------------------------------------------------------------------------------
# Sondertilgungen: geplant (8.5 (i)) und regelbasiert (prepay/capacity, Ü3)
# ---------------------------------------------------------------------------------------------

test_that("prepay()/capacity(): Obergrenze je Vertragsjahr, Wirkung ab t + 1, Erlaubnis", {
  g <- make_grid("annual", T = 6L)
  r <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.05, term_years = 10,
                payments_per_year = 1L, prepay_allowed = TRUE, prepay_cap_share_pa = 0.1,
                grid = g, prepay_at = list("1" = 15000, "2" = 4000))
  def <- reg_get("instrument", "annuity_loan")
  expect_identical(loan_row(r, "prepay")[2:3], c(-10000, -4000))
  base <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.05, term_years = 10,
                   payments_per_year = 1L, grid = g)
  b1 <- loan_row(base, "balance")[2]
  expect_equal(loan_row(r, "balance")[2], b1 - 10000)
  # Zinsen der Periode t = 2 auf den verringerten Bestand, Rate unverändert
  expect_near(-loan_row(r, "interest")[3], (b1 - 10000) * 0.05)
  expect_near(loan_payment(r, 2), loan_payment(base, 2))
  cap <- def$capacity(r$states[[3]], 2L, r$ctx)
  expect_identical(cap$cap, 6000)
  expect_identical(cap$rate_pa, 0.05)
  p <- def$prepay(r$states[[3]], -5, 2L, r$ctx)
  expect_identical(p$used, 0)
  nop <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.05, term_years = 10,
                  payments_per_year = 1L, grid = g)
  expect_identical(def$capacity(nop$states[[2]], 1L, nop$ctx)$cap, 0)
  expect_identical(def$prepay(nop$states[[2]], 1000, 1L, nop$ctx)$used, 0)
})

test_that("Geplante Sondertilgungen als Anteil der Zusage; Kappung je Vertragsjahr", {
  r <- loan_run("bullet_loan", amount_eur = 100000, rate_pa = 0.04, term_years = 6,
                payments_per_year = 1L, prepay_cap_share_pa = 0.05,
                planned_prepayments = list(schedule = list("2028-01-01" = 0.03,
                                                           "2029-01-01" = 0.08),
                                           unit = "share"))
  expect_identical(loan_row(r, "prepay")[2:3], c(-3000, -5000))
  expect_identical(loan_row(r, "balance")[3], 92000)
  expect_true("msg.prepay_capped" %in%
                loan_val_codes("bullet_loan", amount_eur = 100000, rate_pa = 0.04,
                               term_years = 6, prepay_cap_share_pa = 0.05,
                               planned_prepayments = list(schedule = list("2029-01-01" = 9000))))
})

# ---------------------------------------------------------------------------------------------
# Validierung (Kombinationsregeln, Spec 01 Teil A 5.2, 5.3, 5.5) und Labels
# ---------------------------------------------------------------------------------------------

test_that("Validierung: Laufzeit, Raster der Monate, Zinsbindung, Raten", {
  v <- function(type, ...) loan_val_codes(type, ...)
  expect_identical(v("annuity_loan", amount_eur = 1e5, rate_pa = 0.03, term_years = 10),
                   character(0))
  expect_true("errors.ppy" %in% v("bullet_loan", amount_eur = 1e5, rate_pa = 0.03,
                                  term_years = 5, payments_per_year = 2L))
  expect_true("errors.term_missing" %in% v("installment_loan", amount_eur = 1e5,
                                           rate_pa = 0.03))
  expect_true("errors.term_missing" %in% v("annuity_loan", amount_eur = 1e5, rate_pa = 0.03))
  expect_false("errors.term_missing" %in% v("annuity_loan", amount_eur = 1e5, rate_pa = 0.03,
                                            installment_eur = 900))
  expect_true("errors.term_nonpositive" %in% v("bullet_loan", amount_eur = 1e5,
                                               rate_pa = 0.03, term_years = 0))
  expect_true("errors.months_fraction" %in% v("bullet_loan", amount_eur = 1e5,
                                              rate_pa = 0.03, term_years = 10.3))
  expect_true("errors.grace_too_long" %in% v("bullet_loan", amount_eur = 1e5,
                                             rate_pa = 0.03, term_years = 5, grace_years = 5))
  expect_true("errors.nonpositive" %in% v("bullet_loan", amount_eur = 1e5, rate_pa = 0.03,
                                          term_years = 5, fixed_years = 0))
  expect_true("errors.tau_with_installment" %in%
                v("annuity_loan", amount_eur = 1e5, rate_pa = 0.03, initial_repayment_pa = 0.02,
                  installment_eur = 500))
  expect_true("errors.tau_missing" %in%
                v("annuity_loan", amount_eur = 1e5, rate_pa = 0.03, term_years = 10,
                  fixed_years = 5, refi_rule = "keep_tilg_rate"))
  expect_true("errors.keep_term_needs_term" %in%
                v("annuity_loan", amount_eur = 1e5, rate_pa = 0.03, installment_eur = 800,
                  existing = TRUE, fixed_years = 2))
  expect_true("msg.followup_repayment_unused" %in%
                v("annuity_loan", amount_eur = 1e5, rate_pa = 0.03, term_years = 10,
                  followup_repayment_pa = 0.02))
  expect_true("errors.amount_nonpositive" %in% v("bullet_loan", amount_eur = 0, rate_pa = 0.03,
                                                 term_years = 5))
  expect_true("errors.installment_nonpositive" %in%
                v("installment_loan", amount_eur = 1e5, rate_pa = 0.03, term_years = 5,
                  installment_eur = 0))
  expect_true("errors.rank_invalid" %in% v("bullet_loan", amount_eur = 1e5, rate_pa = 0.03,
                                           term_years = 5, rank = 0L))
  expect_true("msg.rate_high" %in% v("bullet_loan", amount_eur = 1e5, rate_pa = 0.13,
                                     term_years = 5))
  expect_true("errors.payout_rate_range" %in% v("bullet_loan", amount_eur = 1e5, rate_pa = 0.03,
                                                term_years = 5, payout_rate = 0.85))
  expect_true("errors.rate_path" %in% v("bullet_loan", amount_eur = 1e5,
                                        rate_pa = c(0.03, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04,
                                                    0.04, 0.04, 0.04, 0.04),
                                        term_years = 5))
  expect_false("errors.rate_path" %in% v("bullet_loan", amount_eur = "topup",
                                         rate_pa = list(ref = "market.mortgage_rate",
                                                        offset = 0.01),
                                         term_years = 5))
})

test_that("Validierung: Bestandsdarlehen und auto/topup (5.3, 8.7)", {
  v <- function(type, ...) loan_val_codes(type, ...)
  ex <- v("annuity_loan", amount_eur = 1e5, rate_pa = 0.03, term_years = 10, existing = TRUE,
          draw_schedule = list(schedule = list("2027-01-01" = 1), unit = "share"),
          fees = list(processing_fee_share = 0.01), payout_rate = 0.98, grace_years = 1,
          repayment_grant = list(share = 0.1), measure_id = "m1", start = "2028-01-01")
  expect_identical(sum(ex == "errors.existing_forbidden"), 5L)
  expect_true(all(c("errors.existing_start", "msg.existing_installment_missing",
                    "msg.existing_new_build") %in% ex))
  expect_true("errors.existing_forbidden" %in%
                v("bullet_loan", amount_eur = "auto", rate_pa = 0.03, term_years = 5,
                  existing = TRUE))
  au <- v("bullet_loan", amount_eur = "auto", rate_pa = 0.03, term_years = 5,
          start = "2028-01-01",
          draw_schedule = list(schedule = list("2028-01-01" = 1), unit = "share"))
  expect_true(all(c("errors.auto_draw_schedule", "errors.auto_start") %in% au))
  expect_true("msg.auto_params_unused" %in% v("bullet_loan", amount_eur = 1e5, rate_pa = 0.03,
                                              term_years = 5, auto_buffer_share = 0.1))
})

test_that("Validierung: Termine, Auszahlungsplan, Geb\u00fchren, Sondertilgungen", {
  v <- function(type, ...) loan_val_codes(type, ...)
  base <- list(amount_eur = 1e5, rate_pa = 0.03, term_years = 5)
  vb <- function(...) do.call(v, c(list("bullet_loan"), utils::modifyList(base, list(...))))
  expect_true("errors.start_before" %in% vb(start = "2026-01-01"))
  expect_true("msg.start_after_horizon" %in% vb(start = "2040-01-01"))
  expect_true("errors.draw_share_sum" %in%
                vb(draw_schedule = list(schedule = list("2027-01-01" = 0.5), unit = "share")))
  expect_true("errors.draws_exceed" %in%
                vb(draw_schedule = list(schedule = list("2027-01-01" = 150000), unit = "eur")))
  expect_true("errors.draw_eur_sum" %in%
                vb(draw_schedule = list(schedule = list("2027-01-01" = 50000), unit = "eur")))
  expect_true("errors.draw_before_start" %in%
                vb(start = "2028-01-01",
                   draw_schedule = list(schedule = list("2027-06-01" = 1), unit = "share")))
  expect_true("msg.fee_high" %in% vb(fees = list(processing_fee_share = 0.03)))
  expect_true("msg.commitment_fee_high" %in% vb(fees = list(commitment_fee_rate_month = 0.01)))
  expect_true("errors.commitment_date_range" %in%
                vb(fees = list(commitment_date = "2029-01-01")))
  expect_true("msg.commitment_fee_window" %in%
                vb(start = "2028-01-01",
                   fees = list(commitment_fee_rate_month = 0.001,
                               commitment_date = "2027-01-01")))
  expect_true("msg.prepay_exceeds" %in%
                vb(planned_prepayments = list(schedule = list("2028-01-01" = 60000,
                                                              "2029-01-01" = 60000))))
  expect_true("msg.prepay_program" %in% vb(prepay_allowed = TRUE, program = "KfW 261"))
  expect_true("msg.fixed_after_horizon" %in% vb(term_years = 20, fixed_years = 15))
  expect_true("msg.followup_truncated" %in% vb(term_years = 10, fixed_years = 5,
                                               followup_fixed_years = 3))
  no_rate <- function(s) {
    s$market$mortgage_rate <- NULL
    s
  }
  expect_true("errors.followup_missing" %in% vb(fixed_years = 2, spec_fun = no_rate))
  expect_false("errors.followup_missing" %in% vb(fixed_years = 2))
})

test_that("Validierung: Tilgungszuschuss, Overlay-Bez\u00fcge, Verzug der Ma\u00dfnahme", {
  v <- function(type, ...) loan_val_codes(type, ...)
  base <- list(amount_eur = 1e5, rate_pa = 0.03, term_years = 10)
  vb <- function(...) do.call(v, c(list("annuity_loan"), utils::modifyList(base, list(...))))
  expect_true("errors.grant_share_xor_amount" %in%
                vb(measure_id = "m1", repayment_grant = list(share = 0.1, amount_eur = 5000)))
  expect_true("errors.grant_needs_id" %in% vb(repayment_grant = list(share = 0.1)))
  expect_true("errors.grant_exceeds" %in%
                vb(measure_id = "m1", repayment_grant = list(amount_eur = 2e5)))
  expect_true("errors.grant_date_year" %in%
                vb(measure_id = "m1", repayment_grant = list(share = 0.1, date = "2028-01-01",
                                                             year = 2028L)))
  expect_true("errors.grant_before_start" %in%
                vb(measure_id = "m1", start = "2029-01-01",
                   repayment_grant = list(share = 0.1, date = "2028-01-01")))
  expect_true("msg.grant_after_horizon" %in%
                vb(measure_id = "m1", repayment_grant = list(share = 0.1, year = 2045L)))
  ovl <- function(s) {
    pars <- list(
      a = list(target = "funding.f.amount_eur", dist = "uniform", min = 1, max = 2),
      d = list(target = "measures.m1.delay_months", dist = "uniform", min = 0, max = 6)
    )
    s$stochastic <- list(parameters = pars)
    s
  }
  w <- v("annuity_loan", amount_eur = list(ref = "funding.f.amount_eur"), rate_pa = 0.03,
         term_years = 10, measure_id = "m1", spec_fun = ovl)
  expect_true(all(c("msg.amount_fixed", "msg.measure_delay") %in% w))
})

test_that("Validierung \u00fcber vofi_validate(): Pfade und Meldungstexte", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  expect_identical(nrow(vofi_validate(sc)), 0L)
  bad <- sc
  bad$financing$bank$amount_eur <- -60000
  vv <- vofi_validate(bad)
  expect_true("validation.range" %in% vv$code)
  expect_identical(vv$path[vv$code == "validation.range"], "financing.bank.amount_eur")
  expect_error(vofi_build(bad), class = "vofi_error_validation")
  b2 <- sc
  b2$financing$bank$term_years <- 0
  b2$financing$bank$payments_per_year <- 2L
  v2 <- vofi_validate(b2)
  expect_true(all(c("types.instrument.bullet_loan.errors.term_nonpositive",
                    "types.instrument.bullet_loan.errors.ppy") %in% v2$code))
  expect_identical(v2$path[v2$code == "types.instrument.bullet_loan.errors.ppy"],
                   "financing.bank.payments_per_year")
  expect_match(v2$message[v2$code == "types.instrument.bullet_loan.errors.ppy"], "'bank'")
  b5 <- sc
  b5$financing$bank <- list(type = "annuity_loan", amount_eur = 60000, rate_pa = 0.05,
                            initial_repayment_pa = 0.02, installment_eur = 500,
                            payments_per_year = 12L)
  expect_true("types.instrument.annuity_loan.errors.tau_with_installment" %in%
                vofi_validate(b5)$code)
})

test_that("Labels: alle Meldungscodes in allen drei Kredittypen, gleiche Schl\u00fcsselmengen", {
  codes <- inst_loan_codes()
  for (type in c("annuity_loan", "installment_loan", "bullet_loan")) {
    for (sec in names(codes)) {
      keys <- inst_loan_key(type, sec, codes[[sec]])
      expect_identical(keys[!vapply(keys, lbl_has, logical(1))], character(0),
                       info = paste(type, sec))
      present <- sub(paste0("^types\\.instrument\\.", type, "\\.", sec, "\\."), "",
                     lbl_keys(paste0("types.instrument.", type, ".", sec)))
      expect_setequal(present, codes[[sec]])
    }
    def <- reg_get("instrument", type)
    expect_true(all(vapply(paste0("types.instrument.", type, ".params.", names(def$params),
                                  ".help"), lbl_has, logical(1))))
  }
})

test_that("Randf\u00e4lle: Termin completion, auto ohne Bauphase, Plan nach dem Horizont", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 5L, construction_months = 12L,
                      construction_step_months = 12L)
  r <- loan_run("bullet_loan", amount_eur = 10000, rate_pa = 0.05, term_years = 3,
                payments_per_year = 1L, start = "completion", grid = g)
  expect_identical(loan_row(r, "draw")[2], 10000)
  expect_identical(r$state$m_start, 12L)
  # auto ohne Bauphase: Fenster W = {t0}; Betrag 0 mit Hinweis im deterministischen Lauf
  ga <- make_grid("annual", T = 3L)
  auto0 <- function(id) list(commitment = 0, draws = matrix(0, 1L, ga$T + 1L))
  run_auto <- function() {
    loan_run("annuity_loan", amount_eur = "auto", rate_pa = 0.03, term_years = 5,
             payments_per_year = 1L, grid = ga, auto = auto0)
  }
  expect_message(run_auto(), class = "vofi_message")
  a <- suppressMessages(run_auto())
  expect_identical(a$state$m_A, 0L)
  expect_true(all(loan_row(a, "balance") == 0))
  # Auszahlungsplan vollständig nach dem Horizont: Kredit entfällt
  run_late <- function() {
    loan_run("installment_loan", amount_eur = 10000, rate_pa = 0.03, term_years = 5,
             draw_schedule = list(schedule = list("2035-01-01" = 1), unit = "share"),
             grid = ga)
  }
  late <- loan_capture_msgs(run_late())
  expect_true("types.instrument.installment_loan.msg.inactive" %in% late$keys)
  p <- late$value
  expect_true(all(loan_row(p, "draw") == 0))
  # Rundung auch bei Neuberechnung nach Tilgungszuschuss (reduce_installment)
  rd <- loan_run("annuity_loan", amount_eur = 100000, rate_pa = 0.031, term_years = 10,
                 payments_per_year = 12L, round_payments = TRUE, measure_id = "m1",
                 repayment_grant = list(amount_eur = 7777, date = "2029-01-01",
                                        effect = "reduce_installment"), grid = ga)
  expect_identical(round(rd$states[[3]]$inst, 2), rd$states[[3]]$inst)
  expect_false(identical(rd$states[[2]]$inst, rd$states[[3]]$inst))
})

test_that("Validierung: Termin completion und Ma\u00dfnahmen eines F\u00f6rderinstruments", {
  with_overlay <- function(s) {
    s$funding <- list(f = list(measures = c("m1", "m2")))
    pars <- list(d = list(target = "measures.m2.delay_months", dist = "uniform", min = 0,
                          max = 6))
    s$stochastic <- list(parameters = pars)
    s
  }
  w <- loan_val_codes("annuity_loan", amount_eur = 1e5, rate_pa = 0.03, term_years = 10,
                      funding_id = "f", start = "completion",
                      repayment_grant = list(share = 0.1), spec_fun = with_overlay)
  expect_true("msg.measure_delay" %in% w)
  expect_false("errors.start_before" %in% w)
  expect_null(inst_loan_val_dates(list(project = list())))
  pm <- inst_loan_val_dates(list(project = list(valuation_date = "2027-01-01"),
                                 grid = list(periods_months = c(3, 3, 6))))
  expect_identical(pm$end, as.Date("2028-01-01"))
})

# ---------------------------------------------------------------------------------------------
# Zusammenspiel mit der Engine (Instrument-Cache, Ü3 loan_prepay, Ledger-Zeilen)
# ---------------------------------------------------------------------------------------------

loan_engine_scenario <- function(prepay = FALSE) {
  surplus <- if (prepay) c("od_repay", "loan_prepay", "dep_invest") else
    c("od_repay", "dep_invest")
  vofi_scenario(list(
    schema_version = 1L,
    meta = list(scenario_id = "wsf", title = "Kredite"),
    project = list(perspective = "wu_privat", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 8L),
    components = list(
      z = list(type = "custom_series", label = "Zahlungsfolge",
               values = c(-400000, 60000, 60000, 60000, 60000, 60000, 60000, 60000, 300000))
    ),
    financing = list(
      ek = list(type = "equity", amount_eur = 100000),
      ann = list(type = "annuity_loan", amount_eur = 150000, rate_pa = 0.035, term_years = 20,
                 payments_per_year = 12L, fixed_years = 3, followup_rate_pa = 0.045,
                 funding_id = "kfw", fees = list(processing_fee_share = 0.01),
                 repayment_grant = list(share = 0.1, date = "2028-01-01")),
      rat = list(type = "installment_loan", amount_eur = 90000, rate_pa = 0.03, term_years = 6,
                 payments_per_year = 4L, payout_rate = 0.98),
      bul = list(type = "bullet_loan", amount_eur = 60000, rate_pa = 0.06, term_years = 8,
                 payments_per_year = 1L, prepay_allowed = prepay, prepay_cap_share_pa = 0.25)
    ),
    accounts = list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08, overdraft_limit_eur = Inf,
                    surplus_order = surplus,
                    deficit_order = c("dep_withdraw", "od_draw", "equity_call")),
    analysis = list(kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value"))
  ))
}

test_that("Engine: Ledger-Zeilen der Kredite = Instrument, Invarianten, \u00dc3 und Cache", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_run")
  res <- vofi_run(vofi_build(loan_engine_scenario()))
  expect_vofi_invariants(res)
  v <- res$ledger$values
  g <- res$grid
  ann <- loan_run("annuity_loan", amount_eur = 150000, rate_pa = 0.035, term_years = 20,
                  payments_per_year = 12L, fixed_years = 3, followup_rate_pa = 0.045,
                  funding_id = "kfw", fees = list(processing_fee_share = 0.01),
                  repayment_grant = list(share = 0.1, date = "2028-01-01"), grid = g)
  for (x in loan_cols()) {
    expect_equal(v[[paste0("loan_ann_", x)]][1L, ], loan_row(ann, x), tolerance = 1e-12,
                 info = x)
  }
  expect_equal(v$loan_rat_disagio[1L, 1L], 1800)
  expect_equal(v$loan_bul_repay_balloon[1L, 9L], -60000)
  # Ü3: Sondertilgung des endfälligen Darlehens aus Überschüssen, höchstens 25 % je Jahr
  pre <- suppressWarnings(vofi_run(vofi_build(loan_engine_scenario(prepay = TRUE))))
  expect_vofi_invariants(pre)
  pv <- pre$ledger$values
  expect_true(any(pv$loan_bul_prepay[1L, ] < 0))
  expect_true(all(-pv$loan_bul_prepay[1L, ] <= 0.25 * 60000 + 1e-9))
  expect_identical(pv$loan_bul_prepay[1L, 1L], 0)
  bal <- pv$loan_bul_balance[1L, ]
  expect_equal(bal[-1L], 60000 + cumsum(pv$loan_bul_prepay[1L, -1L]) +
                 cumsum(pv$loan_bul_repay_balloon[1L, -1L]), tolerance = 1e-9)
  # Zinsen der Folgeperiode auf den verringerten Bestand (Wirkung ab t + 1, 8.1 Nr. 4)
  expect_equal(-pv$loan_bul_interest[1L, 3:9], 0.06 * bal[2:8], tolerance = 1e-9)
})
