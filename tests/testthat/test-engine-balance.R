# Tests für R/engine-balance.R (WS-D; Spec 00 Abschnitte 9.3, 9.4, 9.8): Periodenalgorithmus,
# Prüffälle 9.4 und 9.5, Policy stop, Wiederholungslauf ohne Buchung, Zusatzentnahmen,
# Instrument-Cache, Ketten, Markierungen.

test_that("Prüffall 9.4: Terminalzustand ohne Restwert, gap und N2", {
  res <- vofi_run(vofi_build(wsd_scenario(c(-100000, -5000), rv = c(0, 90000))))
  expect_equal(res$kpis$terminal_value, 85000)
  expect_equal(res$kpis$terminal_value_ex_rv, -5000)
  expect_equal(res$flags$ex_rv_gap, 5000)
  expect_true(all(res$ledger$values$equity_call == 0))
  expect_true(all(res$opportunity$ledger$values$opp_equity_call_in == 0))
  expect_true(all(res$checks$ok))
  inf <- vofi_run(vofi_build(wsd_scenario(c(-100000, -5000), rv = c(0, 90000),
                                          accounts = list(overdraft_limit_eur = Inf))))
  expect_equal(inf$kpis$terminal_value_ex_rv, -5000)
  expect_equal(inf$flags$ex_rv_gap, 0)
})

test_that("Prüffall 9.5: Unterlassungsalternative ohne eigene Nachschüsse (KKP zu s)", {
  sc <- wsd_scenario(c(-10000, rep(5000, 5)),
                     ek = list(type = "equity", amount_eur = 10000, withdrawals_pa = 4000))
  expect_warning(res <- vofi_run(vofi_build(sc)), class = "vofi_warning_plausibility")
  expect_equal(res$kpis$terminal_value, 5000)
  expect_equal(res$kpis$terminal_value_opp, -10000)
  expect_equal(res$kpis$delta_terminal_value, 15000)
  expect_true(res$flags$opp_limit_breach)
  expect_true(all(res$ledger$values$equity_call == 0))
  opp <- res$opportunity$ledger$values
  expect_equal(opp$odp_balance[1, ], c(0, 0, 0, 2000, 6000, 10000))
  expect_true(all(opp$equity_call == 0))
  expect_equal(opp$ek__out[1, ], c(0, rep(-4000, 5)))
})

test_that("Nachschuss der Investition geht als Einlage in die Unterlassungsalternative", {
  sc <- wsd_scenario(c(-10000, -3000, 16000), ek = list(type = "equity", amount_eur = 10000),
                     accounts = list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08,
                                     penalty_spread_pa = 0.02))
  expect_message(res <- vofi_run(vofi_build(sc)), class = "vofi_message")
  expect_equal(res$ledger$values$equity_call[1, ], c(0, 3000, 0))
  expect_equal(res$kpis$terminal_value, 16000)
  expect_equal(res$opportunity$ledger$values$opp_equity_call_in[1, ], c(0, 3000, 0))
  expect_equal(res$kpis$terminal_value_opp, 13464)
  expect_equal(res$kpis$delta_terminal_value, 2536)
  expect_true(res$flags$shortfall)
  expect_identical(res$flags$first_shortfall_t, 1L)
  expect_equal(res$flags$shortfall_sum, 3000)
})

test_that("Policy stop: Fehlbetrag, Markierung, Kennzahlen NA run_stopped", {
  sc <- wsd_scenario(c(-100000, -5000), ek = list(type = "equity", amount_eur = 100000),
                     accounts = list(deficit_order = c("dep_withdraw", "od_draw", "stop")))
  # eine zusammengefasste Warnung je Markierungsart (9.8, 2.9: Fehlbetrag bei stop)
  w <- testthat::capture_warnings(
    m <- testthat::capture_messages(res <- vofi_run(vofi_build(sc)))
  )
  expect_length(grep("'stop'", w, fixed = TRUE), 1L)
  expect_length(grep("D4", m, fixed = TRUE), 1L)
  expect_equal(res$ledger$values$shortfall[1, ], c(0, 5000))
  expect_true(res$flags$stopped)
  expect_true(is.na(res$kpis$terminal_value))
  expect_identical(res$kpi_na$terminal_value, "run_stopped")
  expect_false(is.na(res$kpis$terminal_value_opp))
})

test_that("Policy penalty_rate: unbegrenzte Strafzinstranche zum Zins s + Aufschlag", {
  sc <- wsd_scenario(c(-100000, 0, 0), ek = list(type = "equity", amount_eur = 90000),
                     accounts = list(overdraft_rate_pa = 0.08, penalty_spread_pa = 0.04,
                                     overdraft_limit_eur = 4000,
                                     deficit_order = c("dep_withdraw", "od_draw",
                                                       "penalty_rate")))
  w <- testthat::capture_warnings(m <- testthat::capture_messages(
    res <- vofi_run(vofi_build(sc))
  ))
  v <- res$ledger$values
  expect_equal(v$od_draw[1L, 1L], 4000)
  expect_equal(v$odp_draw[1L, 1L], 6000)
  expect_equal(v$odp_interest[1L, 2L], -6000 * 0.12)
  expect_equal(v$od_interest[1L, 2L], -4000 * 0.08)
  expect_true(res$flags$limit_breach)
  expect_true(any(grepl("Strafzins", w)))
  expect_true(all(res$checks$ok))
})

test_that("Wiederholungslauf ohne Buchung (book = FALSE) mit Zusatzentnahme", {
  model <- wsd_skeleton()
  p <- wsd_parts(model)
  r0 <- eng_balance(model, p$ctx, p$exo$ledger, book = FALSE, engine_env = p$env)
  expect_identical(names(r0), c("BS_T", "NS", "BS_T_ex_rv", "RW_T"))
  expect_equal(r0$BS_T, p$core$stocks$BS[, 4])
  expect_equal(r0$BS_T_ex_rv, p$core$terminal_ex_rv$BS)
  e <- -p$ctx$by_sim(1000) * p$ctx$by_period(p$ctx$grid$delta)
  r1 <- eng_balance(model, p$ctx, p$exo$ledger, extra_out = e, book = FALSE,
                    engine_env = p$env)
  expect_equal(r0$BS_T - r1$BS_T, 1000 * (1.02^2 + 1.02 + 1))
  expect_true(all(r1$NS == 0))
  # Zwischenspeicher: gleiche Vorbereitung für alle Wiederholungsläufe
  expect_identical(p$env$setup$inv$exo, p$exo$ledger)
})

test_that("Zusatzentnahme mit Buchung: Zeile extra_equity_out, I1 erfüllt (12.8)", {
  model <- wsd_skeleton()
  p <- wsd_parts(model)
  e <- -p$ctx$by_sim(1000) * p$ctx$by_period(p$ctx$grid$delta)
  core <- eng_balance(model, p$ctx, p$exo$ledger, extra_out = e, engine_env = p$env)
  v <- core$ledger$values
  expect_equal(v$extra_equity_out[1L, ], c(0, -1000, -1000, -1000))
  rows <- core$ledger$rows
  expect_identical(rows$category[rows$key == "extra_equity_out"], "equity_out")
  expect_true(all(abs(v$balance_check) < 1e-8))
  expect_true(all(eng_checks(core)$ok))
  expect_equal(core$stocks$BS[, 4L], p$core$stocks$BS[, 4L] - 1000 * (1.02^2 + 1.02 + 1))
})

test_that("Instrument-Cache und Schrittlauf ergeben denselben Ledger (9.3)", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  m_cache <- vofi_build(sc)
  sc$accounts$surplus_order <- c("od_repay", "loan_prepay", "dep_invest")
  m_step <- suppressWarnings(vofi_build(sc))
  expect_false(eng_has_prepay(m_cache))
  expect_true(eng_has_prepay(m_step))
  a <- wsd_parts(m_cache)$core
  b <- wsd_parts(m_step)$core
  keys <- a$ledger$rows$key
  expect_setequal(keys, b$ledger$rows$key)
  for (k in keys) expect_equal(b$ledger$values[[k]], a$ledger$values[[k]], info = k)
  expect_equal(b$stocks$BS, a$stocks$BS)
  expect_equal(b$terminal_ex_rv$BS, a$terminal_ex_rv$BS)
})

test_that("Ketten: Rest nach der Defizitkette ist ein Engine-Fehler", {
  sc <- wsd_scenario(c(-100000, 0), ek = list(type = "equity", amount_eur = 50000))
  model <- vofi_build(sc)
  model$deficit_chain <- model$deficit_chain["dep_withdraw"]
  p_env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, NULL, p_env)
  exo <- eng_flows(model, ctx, p_env)
  e <- expect_error(eng_balance(model, ctx, exo$ledger, engine_env = p_env),
                    class = "vofi_error_engine")
  expect_identical(e$data$invariant, "chain")
  expect_identical(e$data$t, 0L)
})

test_that("eng_apply_chains: Flüsse unverdichtet, Betrag 0 überspringt, ext = NS", {
  model <- wsd_skeleton()
  acc <- wsd_acc(g = c(10, 0), kk = c(0, 0), kkp = c(0, 0), lmin = 0, kl = 5)
  r <- eng_apply_chains(model$surplus_chain, model$deficit_chain, acc, c(-15, -20), 1L, 2L,
                        NULL, NULL)
  expect_equal(r$acc$G, c(0, 0))
  expect_equal(r$acc$KK, c(5, 5))
  expect_equal(r$ext, c(0, 15))
  expect_equal(r$rest_def, c(0, 0))
  expect_identical(names(r$flows), c("dep_withdraw", "od_draw", "equity_call"))
  expect_equal(eng_flow_sum(r$flows, "equity_call", c(0, 0)), c(0, 15))
  z <- eng_apply_chains(model$surplus_chain, model$deficit_chain, acc, c(0, 0), 1L, 2L,
                        NULL, NULL)
  expect_identical(names(z$flows), "od_draw")
  expect_equal(z$acc, utils::modifyList(acc, list(j = 2L)))
  info <- eng_chain_info(model$surplus_chain, model$deficit_chain)
  expect_identical(info$noop_s, c(TRUE, TRUE))
  expect_identical(info$noop_d, c(TRUE, FALSE, TRUE))
  expect_identical(info$ext_d, c(FALSE, FALSE, TRUE))
  sk <- eng_apply_chains(model$surplus_chain, model$deficit_chain, acc, c(-15, -20), 1L, 2L,
                         NULL, NULL, skip_external = TRUE)
  expect_equal(sk$rest_def, c(0, 15))
  expect_equal(sk$ext, c(0, 0))
})

test_that("Hilfen: eng_num, eng_inst_tax_rows, eng_report_add", {
  expect_identical(eng_num(NULL, 2L), c(0, 0))
  expect_identical(eng_num(3, 2L), c(3, 3))
  rows <- eng_inst_tax_rows("bank", list(interest = -10, fees = -1),
                            list(disagio = 5, repayment_grant = 2))
  expect_identical(names(rows), c("loan_bank_interest", "loan_bank_fees", "loan_bank_disagio",
                                  "loan_bank_repayment_grant"))
  expect_equal(rows$loan_bank_disagio, -5)
  expect_equal(rows$loan_bank_repayment_grant, 2)
  rep <- eng_report_add(list(), list(a = 1), 2L, 1L, 3L)
  rep <- eng_report_add(rep, list(a = 2), 3L, 1L, 3L, add = TRUE)
  expect_equal(rep$a, matrix(c(0, 1, 2), 1L))
})

test_that("Markierungen: Arbitrage (h > s) als vofi_warning_engine (8.8), je Art einmal", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  sc$accounts$deposit_rate_pa <- 0.09
  expect_warning(res <- vofi_run(vofi_build(sc)), class = "vofi_warning_engine")
  expect_true(res$flags$arbitrage)
  flags <- data.frame(arbitrage = c(TRUE, FALSE), limit_breach = c(FALSE, FALSE),
                      shortfall = c(TRUE, TRUE), shortfall_sum = c(1, 2))
  w <- testthat::capture_warnings(m <- testthat::capture_messages(
    hit <- eng_flag_conditions(flags)
  ))
  expect_identical(hit, c("arbitrage", "shortfall"))
  expect_length(w, 1L)
  expect_match(w, "50,00 %", fixed = TRUE)
  expect_length(m, 1L)
})

test_that("Markierung equity_call_over_savings: Nachschuss über 12 x Sparfähigkeit", {
  sc <- wsd_scenario(c(-100000, -15000, 0), ek = list(type = "equity", amount_eur = 100000))
  sc$household <- list(savings_capacity_month_eur = 1000)
  m <- testthat::capture_messages(res <- vofi_run(vofi_build(sc)))
  expect_true(res$flags$equity_call_over_savings)
  sc$household$savings_capacity_month_eur <- 2000
  m2 <- testthat::capture_messages(res2 <- vofi_run(vofi_build(sc)))
  expect_false(res2$flags$equity_call_over_savings)
})

test_that("Unbekannter Flussschlüssel einer Ausgleichsaktion ist ein Vertragsfehler", {
  local_registry_state <- reg_state$types
  withr::defer(reg_state$types <- local_registry_state)
  bad <- reg_get("account_action", "dep_invest")
  bad$name <- "dep_invest_bad"
  bad$rows <- "loan_*_prepay"
  bad$apply <- function(acc, amount, t, ctx, inst) {
    acc$G <- acc$G + amount
    list(acc = acc, used = amount, flows = list(loan_x_prepay = -amount), flags = list())
  }
  reg_add(bad, source = "vofi", overwrite = TRUE)
  model <- vofi_build(vofi_read_scenario(vofi_example("skeleton")))
  model$surplus_chain[["dep_invest"]] <- bad
  # die Kette enthält nun eine Aktion mit Sondertilgungszeilen: Heuristik-Warnung (8.9)
  expect_warning(expect_error(vofi_run(model), class = "vofi_error_contract"),
                 class = "vofi_warning_plausibility")
})

test_that("Einzellauf mit store = kpi bzw. bands liefert ein vollständiges Ergebnis", {
  model <- wsd_skeleton()
  expect_message(r <- vofi_run(model, store = "kpi"), class = "vofi_message")
  expect_s3_class(r, "vofi_result")
  expect_identical(r$meta$store, "full")
  expect_equal(r$kpis$terminal_value, 52830.80, tolerance = 1e-9)
  expect_message(vofi_run(model, store = "bands"), "full", fixed = TRUE)
})

test_that("Sacheinlage (Bestandswert): equity_in_kind und Verkauf in der Alternative (9.5 Nr. 7)", {
  sc <- wsd_scenario(c(-100000, 20000, 120000),
                     ek = list(type = "equity", amount_eur = 100000),
                     accounts = list(overdraft_limit_eur = Inf))
  sc$building <- list(existing_value_eur = 50000)
  sc$residual_value <- list(sale_cost_share = 0.04)
  res <- vofi_run(vofi_build(sc))
  expect_equal(res$ledger$values$equity_in_kind[1, ], c(50000, 0, 0))
  opp <- res$opportunity$ledger$values
  expect_equal(opp$opp_in_kind_sale[1, ], c(50000 * 0.96, 0, 0))
  orows <- res$opportunity$ledger$rows
  expect_identical(orows$category[orows$key == "opp_in_kind_sale"], "equity_in")
  expect_true(all(res$checks$ok))
})
