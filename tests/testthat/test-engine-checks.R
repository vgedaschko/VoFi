# Tests für R/engine-checks.R (WS-D; Spec 00 Abschnitte 9.7, 9.8): Invarianten I1, I2, I3a-c,
# N1, N2 mit Fehlerdaten; zusammengefasste Meldungen der Markierungen.

test_that("eng_checks: erfüllte Invarianten mit Toleranzen", {
  core <- wsd_parts(wsd_skeleton())$core
  chk <- eng_checks(core)
  expect_identical(chk$invariant, c("I1", "I2", "I3a", "I3b", "I3c", "N1", "N2"))
  expect_true(all(chk$ok))
  expect_identical(chk$tol[1L], vofi_tol$balance_rel)
  expect_identical(chk$tol[3L], vofi_tol$stock_abs)
})

test_that("eng_checks: verletzte Invariante ergibt vofi_error_engine mit Lauf, Periode, Zeilen", {
  model <- wsd_skeleton()
  core <- wsd_parts(model)$core
  bad <- core
  bad$ledger$values$balance_check[1, 3] <- 5
  e <- expect_error(eng_checks(bad), class = "vofi_error_engine")
  expect_identical(e$data$invariant, "I1")
  expect_identical(e$data$sim, 1L)
  expect_identical(e$data$t, 2L)
  expect_true(length(e$data$rows) >= 1L)
  expect_lte(length(e$data$rows), 5L)
  chk <- eng_checks(bad, stop_on_error = FALSE)
  expect_false(chk$ok[chk$invariant == "I1"])
  bad2 <- core
  bad2$ledger$values$dep_balance[1, 2] <- -1
  e2 <- expect_error(eng_checks(bad2), class = "vofi_error_engine")
  expect_identical(e2$data$invariant, "I3a")
  bad4 <- core
  bad4$ledger$values$net_position[1, 3] <- bad4$ledger$values$net_position[1, 3] + 7
  e4 <- expect_error(eng_checks(bad4), class = "vofi_error_engine")
  expect_identical(e4$data$invariant, "I2")
  bad3 <- core
  bad3$terminal_ex_rv$BS <- bad3$terminal_ex_rv$BS + 10
  e3 <- expect_error(eng_checks(bad3), class = "vofi_error_engine")
  expect_identical(e3$data$invariant, "N2")
  expect_identical(e3$data$t, model$grid$T)
})

test_that("I3b (G * KK = 0 bei L_min = 0), I3c (KK <= KL), N1 (endlich)", {
  core <- wsd_parts(wsd_skeleton())$core
  b <- core
  b$ledger$values$od_balance[1, 2] <- 100
  b$ledger$values$dep_balance[1, 2] <- 50
  chk <- eng_checks(b, stop_on_error = FALSE)
  expect_false(chk$ok[chk$invariant == "I3b"])
  c3 <- core
  c3$limits$KL <- matrix(-1, 1L, 4L)
  chk3 <- eng_checks(c3, stop_on_error = FALSE)
  expect_false(chk3$ok[chk3$invariant == "I3c"])
  n1 <- core
  n1$ledger$values$tax[1, 2] <- NaN
  chk1 <- eng_checks(n1, stop_on_error = FALSE)
  expect_false(chk1$ok[chk1$invariant == "N1"])
  expect_false(anyNA(chk1$ok))
  e1 <- expect_error(eng_checks(n1), class = "vofi_error_contract")
  expect_identical(e1$data$row, "tax")
})

test_that("eng_rowmax und eng_pmin_mat", {
  m <- rbind(c(1, 5, 2), c(-3, -1, -2))
  expect_equal(eng_rowmax(m), c(5, -1))
  a <- matrix(c(1, 4, 3, 2), 2L)
  b <- matrix(c(2, 3, 1, 5), 2L)
  out <- eng_pmin_mat(list(a, b))
  expect_identical(dim(out), c(2L, 2L))
  expect_equal(out, matrix(c(1, 3, 1, 2), 2L))
  expect_identical(eng_pmin_mat(list(a)), a)
})

test_that("eng_flag_conditions: Klassen der Meldungen, Anteil der Läufe, einmal je Art", {
  flags <- data.frame(stopped = c(TRUE, FALSE, FALSE, FALSE),
                      negative_amortization = c(TRUE, TRUE, FALSE, FALSE),
                      limit_breach = c(FALSE, FALSE, FALSE, TRUE),
                      opp_limit_breach = c(TRUE, TRUE, TRUE, TRUE),
                      reserve_used = c(FALSE, FALSE, FALSE, FALSE),
                      limit_cut = c(TRUE, FALSE, FALSE, FALSE),
                      first_shortfall_t = c(1L, NA, NA, NA))
  conds <- list()
  withCallingHandlers(
    hit <- eng_flag_conditions(flags),
    warning = function(w) {
      conds[[length(conds) + 1L]] <<- w
      invokeRestart("muffleWarning")
    },
    message = function(m) {
      conds[[length(conds) + 1L]] <<- m
      invokeRestart("muffleMessage")
    }
  )
  expect_identical(hit, c("stopped", "negative_amortization", "limit_breach",
                          "opp_limit_breach", "limit_cut"))
  cls <- vapply(conds, function(x) class(x)[1L], "")
  expect_identical(cls, c("vofi_warning_engine", "vofi_warning_engine",
                          "vofi_warning_engine", "vofi_warning_plausibility", "vofi_message"))
  expect_match(conditionMessage(conds[[1L]]), "25,00 %", fixed = TRUE)
  expect_match(conditionMessage(conds[[2L]]), "50,00 %", fixed = TRUE)
  expect_identical(eng_flag_conditions(data.frame(x = 1)), character(0))
})
