# Tests für R/account-actions.R (WS-D; Spec 00 Abschnitt 8.9): Einheitstests der zehn
# Ausgleichsaktionen über einen vorgegebenen Kontenzustand und die Sondertilgung im Lauf.

act <- function(name) reg_get("account_action", name)

test_that("Alle zehn Aktionen aus 8.9 sind registriert, mit Rolle, Rang und Zeilen", {
  names10 <- c("od_repay", "dep_fill_reserve", "loan_prepay", "dep_invest", "dep_withdraw",
               "od_draw", "dep_use_reserve", "equity_call", "penalty_rate", "stop")
  for (nm in names10) {
    a <- act(nm)
    expect_true(is.function(a$apply), info = nm)
    expect_true(a$role %in% c("surplus", "deficit"), info = nm)
    expect_true(length(a$rows) >= 1L, info = nm)
  }
  ranks <- vapply(names10, function(nm) act(nm)$rank, "")
  expect_identical(unname(ranks), c("U1", "U2", "U3", "U4", "D1", "D2", "D3", "D4", "D4", "D4"))
})

test_that("U1 od_repay tilgt zuerst die Strafzinstranche, dann die Regeltranche", {
  acc <- wsd_acc()
  r <- act("od_repay")$apply(acc, c(10, 30), 1L, NULL, NULL)
  expect_equal(r$used, c(0, 30))
  expect_equal(r$acc$KKP, c(0, 0))
  expect_equal(r$acc$KK, c(0, 40))
  expect_equal(r$flows$odp_repay, c(0, -20))
  expect_equal(r$flows$od_repay, c(0, -10))
})

test_that("U2 dep_fill_reserve füllt bis L_min, U4 dep_invest unbegrenzt", {
  acc <- wsd_acc()
  r <- act("dep_fill_reserve")$apply(acc, c(50, 50), 1L, NULL, NULL)
  expect_equal(r$used, c(0, 30))
  expect_equal(r$acc$G, c(100, 30))
  expect_equal(r$flows$dep_invest, c(0, -30))
  r2 <- act("dep_invest")$apply(acc, c(5, 7), 1L, NULL, NULL)
  expect_equal(r2$used, c(5, 7))
  expect_equal(r2$acc$G, c(105, 7))
  expect_equal(r2$flows$dep_invest, c(-5, -7))
})

test_that("D1 dep_withdraw bis L_min, D3 dep_use_reserve bis 0 mit Markierung", {
  acc <- wsd_acc(g = c(100, 20))
  r <- act("dep_withdraw")$apply(acc, c(90, 10), 1L, NULL, NULL)
  expect_equal(r$used, c(70, 0))
  expect_equal(r$acc$G, c(30, 20))
  expect_equal(r$flows$dep_withdraw, c(70, 0))
  r2 <- act("dep_use_reserve")$apply(r$acc, c(20, 25), 1L, NULL, NULL)
  expect_equal(r2$used, c(20, 20))
  expect_equal(r2$acc$G, c(10, 0))
  expect_identical(r2$flags$reserve_used, c(TRUE, TRUE))
})

test_that("D2 od_draw bis zum Limit, Markierung überschrittener Schwelle", {
  acc <- wsd_acc(kk = c(0, 90), kkp = c(0, 0), thr = 40)
  r <- act("od_draw")$apply(acc, c(50, 50), 1L, NULL, NULL)
  expect_equal(r$used, c(50, 10))
  expect_equal(r$acc$KK, c(50, 100))
  expect_equal(r$flows$od_draw, c(50, 10))
  expect_identical(r$flags$overdraft_threshold, c(TRUE, TRUE))
  acc_inf <- wsd_acc(kl = Inf)
  expect_equal(act("od_draw")$apply(acc_inf, c(1e9, 0), 1L, NULL, NULL)$used, c(1e9, 0))
})

test_that("D4: equity_call, penalty_rate, stop sind unbegrenzt mit Markierungen", {
  acc <- wsd_acc()
  ec <- act("equity_call")$apply(acc, c(0, 12), 1L, NULL, NULL)
  expect_equal(ec$used, c(0, 12))
  expect_equal(ec$flows$equity_call, c(0, 12))
  expect_identical(ec$flags$shortfall, c(FALSE, TRUE))
  pr <- act("penalty_rate")$apply(acc, c(0, 12), 1L, NULL, NULL)
  expect_equal(pr$acc$KKP, c(0, 32))
  expect_equal(pr$flows$odp_draw, c(0, 12))
  expect_identical(pr$flags$limit_breach, c(FALSE, TRUE))
  st <- act("stop")$apply(acc, c(3, 0), 1L, NULL, NULL)
  expect_equal(st$flows$shortfall, c(3, 0))
  expect_identical(st$flags$stopped, c(TRUE, FALSE))
  expect_true(isTRUE(act("equity_call")$unlimited))
  expect_true(isTRUE(act("penalty_rate")$unlimited))
  expect_true(isTRUE(act("stop")$unlimited))
})

test_that("U3 loan_prepay: keine Wirkung in t0 oder ohne Kredite", {
  acc <- wsd_acc()
  r0 <- act("loan_prepay")$apply(acc, c(10, 10), 0L, NULL, list())
  expect_equal(r0$used, c(0, 0))
  expect_null(r0$inst)
  r1 <- act("loan_prepay")$apply(acc, c(10, 10), 1L, NULL, list())
  expect_equal(r1$used, c(0, 0))
})

test_that("U3 loan_prepay im Lauf: Sondertilgung aus Überschüssen, Warnung einmal je Lauf", {
  sc <- wsd_scenario(c(-100000, 30000, 30000, 30000),
                     ek = list(type = "equity", amount_eur = 50000),
                     accounts = list(surplus_order = c("od_repay", "loan_prepay", "dep_invest"),
                                     deposit_rate_pa = 0.01),
                     financing = list(bank = list(type = "bullet_loan", amount_eur = 50000,
                                                  rate_pa = 0.05, term_years = 3,
                                                  payments_per_year = 1L,
                                                  prepay_allowed = TRUE,
                                                  prepay_cap_share_pa = 0.2)))
  model <- vofi_build(sc)
  w <- testthat::capture_warnings(res <- suppressMessages(vofi_run(model)))
  expect_length(grep("loan_prepay", w, fixed = TRUE), 1L)
  pp <- res$ledger$values$loan_bank_prepay[1L, ]
  # Deckel 20 % der Zusage je Jahr: 10.000 in t = 1 und t = 2, Rest in T als Schlusstilgung
  expect_equal(pp[1:3], c(0, -10000, -10000))
  expect_equal(res$ledger$values$loan_bank_balance[1L, 2:3], c(40000, 30000))
  expect_true(all(res$checks$ok))
  # die Unterlassungsalternative läuft ohne Sondertilgung (9.5 Nr. 2)
  expect_false(any(grepl("prepay", res$opportunity$ledger$rows$key)))
})
