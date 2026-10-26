# Tests für R/engine-balance.R und R/opportunity.R (WS-D; Spec 00 Abschnitte 9.3-9.5, 9.8).
# Phase-0-Minimalfassung: Prüffälle aus 9.4 und 9.5, Policy stop, Wiederholungslauf.

engine_scenario <- function(z, rv = NULL, ek = list(type = "equity", amount_eur = 100000),
                            accounts = list(), horizon = length(z) - 1L) {
  comps <- list(z = list(type = "custom_series", label = "Zahlungsfolge", values = z))
  if (!is.null(rv)) {
    comps$rv <- list(type = "custom_series", category = "residual_value", values = rv)
  }
  acc <- utils::modifyList(list(deposit_rate_pa = 0, overdraft_rate_pa = 0,
                                overdraft_limit_eur = 0, penalty_spread_pa = 0,
                                min_liquidity_eur = 0,
                                surplus_order = c("od_repay", "dep_invest"),
                                deficit_order = c("dep_withdraw", "od_draw", "equity_call")),
                           accounts)
  vofi_scenario(list(
    schema_version = 1L, meta = list(scenario_id = "engine_test", title = "Engine"),
    project = list(perspective = "kleinvermieter", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = as.integer(horizon)),
    components = comps, financing = list(ek = ek), accounts = acc,
    analysis = list(kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value"))
  ))
}

test_that("Pr\u00fcffall 9.4: Terminalzustand ohne Restwert, gap und N2", {
  res <- vofi_run(vofi_build(engine_scenario(c(-100000, -5000), rv = c(0, 90000))))
  expect_equal(res$kpis$terminal_value, 85000)
  expect_equal(res$kpis$terminal_value_ex_rv, -5000)
  expect_equal(res$flags$ex_rv_gap, 5000)
  expect_true(all(res$ledger$values$equity_call == 0))
  expect_true(all(res$checks$ok))
  inf <- vofi_run(vofi_build(engine_scenario(c(-100000, -5000), rv = c(0, 90000),
                                             accounts = list(overdraft_limit_eur = Inf))))
  expect_equal(inf$kpis$terminal_value_ex_rv, -5000)
  expect_equal(inf$flags$ex_rv_gap, 0)
})

test_that("Pr\u00fcffall 9.5: Unterlassungsalternative ohne eigene Nachsch\u00fcsse (KKP zu s)", {
  sc <- engine_scenario(c(-10000, rep(5000, 5)),
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
  sc <- engine_scenario(c(-10000, -3000, 16000), ek = list(type = "equity", amount_eur = 10000),
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
})

test_that("Policy stop: Fehlbetrag, Markierung, Kennzahlen NA run_stopped", {
  sc <- engine_scenario(c(-100000, -5000), ek = list(type = "equity", amount_eur = 100000),
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

test_that("Wiederholungslauf ohne Buchung (book = FALSE) mit Zusatzentnahme", {
  model <- vofi_build(vofi_read_scenario(vofi_example("skeleton")))
  env <- eng_engine_env(model)
  ctx <- eng_context(model, NULL, env)
  exo <- eng_flows(model, ctx, env)
  core <- eng_balance(model, ctx, exo$ledger, engine_env = env)
  r0 <- eng_balance(model, ctx, exo$ledger, book = FALSE, engine_env = env)
  expect_equal(r0$BS_T, core$stocks$BS[, 4])
  expect_equal(r0$BS_T_ex_rv, core$terminal_ex_rv$BS)
  e <- -ctx$by_sim(1000) * ctx$by_period(ctx$grid$delta)
  r1 <- eng_balance(model, ctx, exo$ledger, extra_out = e, book = FALSE, engine_env = env)
  expect_equal(r0$BS_T - r1$BS_T, 1000 * (1.02^2 + 1.02 + 1))
  expect_true(all(r1$NS == 0))
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

test_that("Unbekannter Flussschl\u00fcssel einer Ausgleichsaktion ist ein Vertragsfehler", {
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
  expect_error(vofi_run(model), class = "vofi_error_contract")
})

test_that("Einzellauf mit store = kpi bzw. bands liefert ein vollst\u00e4ndiges Ergebnis", {
  model <- vofi_build(vofi_read_scenario(vofi_example("skeleton")))
  expect_message(r <- vofi_run(model, store = "kpi"), class = "vofi_message")
  expect_s3_class(r, "vofi_result")
  expect_identical(r$meta$store, "full")
  expect_equal(r$kpis$terminal_value, 52830.80, tolerance = 1e-9)
  expect_message(vofi_run(model, store = "bands"), "full", fixed = TRUE)
})
