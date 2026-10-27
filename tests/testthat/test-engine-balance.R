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

test_that("eng_apply_chains: alle Kettenglieder ohne Sprünge, Flüsse unverdichtet, ext = NS", {
  model <- wsd_skeleton()
  acc <- wsd_acc(g = c(10, 0), kk = c(0, 0), kkp = c(0, 0), lmin = 0, kl = 5)
  r <- eng_apply_chains(model$surplus_chain, model$deficit_chain, acc, c(-15, -20), 1L, 2L,
                        NULL, NULL)
  expect_equal(r$acc$G, c(0, 0))
  expect_equal(r$acc$KK, c(5, 5))
  expect_equal(r$ext, c(0, 15))
  expect_equal(r$rest_def, c(0, 0))
  all_flows <- c("odp_repay", "od_repay", "dep_invest", "dep_withdraw", "od_draw", "equity_call")
  expect_identical(names(r$flows), all_flows)
  expect_equal(eng_flow_sum(r$flows, "equity_call", c(0, 0)), c(0, 15))
  # Betrag 0: dieselben Kettenglieder laufen (keine Verzweigung über Beträge, 2.8 Nr. 2, 3)
  z <- eng_apply_chains(model$surplus_chain, model$deficit_chain, acc, c(0, 0), 1L, 2L,
                        NULL, NULL)
  expect_identical(names(z$flows), all_flows)
  expect_true(all(vapply(z$flows, function(f) all(f == 0), logical(1))))
  expect_equal(z$acc, utils::modifyList(acc, list(j = 2L)))
  cc <- eng_chain_compile(model$surplus_chain, model$deficit_chain)
  expect_identical(cc$s$code, c("od_repay", "dep_invest"))
  expect_identical(cc$d$code, c("dep_withdraw", "od_draw", "equity_call"))
  expect_identical(cc$d$ext, c(FALSE, FALSE, TRUE))
  sk <- eng_apply_chains(model$surplus_chain, model$deficit_chain, acc, c(-15, -20), 1L, 2L,
                         NULL, NULL, skip_external = TRUE)
  expect_equal(sk$rest_def, c(0, 15))
  expect_equal(sk$ext, c(0, 0))
})

test_that("Direkt gerechnete Aktionen = apply() der Typen (8.9), Batch = Einzellauf", {
  n <- 7L
  amt <- c(-120, -35, 0, 15, 60, -5, 250)
  acc <- wsd_acc(g = c(0, 40, 10, 100, 0, 5, 30), kk = c(20, 0, 5, 0, 50, 0, 10),
                 kkp = c(0, 10, 0, 0, 5, 0, 20), lmin = c(0, 10, 20, 0, 5, 30, 0),
                 kl = c(100, 30, Inf, 0, 60, Inf, 10), thr = 25)
  sur <- list(c("od_repay", "dep_invest"), c("od_repay", "dep_fill_reserve", "dep_invest"))
  dfc <- list(c("dep_withdraw", "od_draw", "equity_call"),
              c("dep_withdraw", "od_draw", "dep_use_reserve", "penalty_rate"),
              c("dep_withdraw", "dep_use_reserve", "stop"))
  for (s_chain in sur) for (d_chain in dfc) {
    cs <- eng_build_chain(s_chain)
    cd <- eng_build_chain(d_chain)
    cc <- eng_chain_compile(cs, cd)
    expect_true(all(nzchar(c(cc$s$code, cc$d$code))))
    gen <- cc
    gen$s$code[] <- ""
    gen$d$code[] <- ""
    rt <- eng_chain_consts(acc)
    for (skip in c(FALSE, TRUE)) {
      a <- eng_chain_step(cc, acc$G, acc$KK, acc$KKP, amt, 1L, 2L, NULL, NULL, rt,
                          acc$Lmin[, 2L], acc$KL[, 2L], collect = TRUE, skip_external = skip)
      b <- eng_chain_step(gen, acc$G, acc$KK, acc$KKP, amt, 1L, 2L, NULL, NULL, rt,
                          acc$Lmin[, 2L], acc$KL[, 2L], collect = TRUE, skip_external = skip)
      info <- paste(c(s_chain, d_chain, skip), collapse = " ")
      for (f in c("G", "KK", "KKP", "rest_sur", "rest_def", "ext")) {
        expect_equal(a[[f]], b[[f]], info = paste(info, f))
      }
      expect_identical(names(a$flows), names(b$flows), info = info)
      expect_equal(unname(a$flows), unname(b$flows), info = info)
      expect_identical(names(a$flags), names(b$flags), info = info)
      expect_identical(unname(a$flags), unname(b$flags), info = info)
      # Batch gegen Einzellauf (elementweise über n)
      for (i in c(1L, 4L, 7L)) {
        ai <- eng_apply_chains(cs, cd, lapply(acc, function(x) {
          if (is.matrix(x)) x[i, , drop = FALSE] else if (length(x) == n) x[i] else x
        }), amt[i], 1L, 2L, NULL, NULL, skip_external = skip)
        expect_equal(ai$acc$G, a$G[i], info = paste(info, i))
        expect_equal(ai$acc$KKP, a$KKP[i], info = paste(info, i))
        expect_equal(ai$ext, a$ext[i], info = paste(info, i))
      }
    }
  }
})

test_that("N1: nicht endliche bzw. falsch lange Rückgaben mit Quelle (9.7, WSD-04)", {
  old <- reg_state$types
  withr::defer(reg_state$types <- old)
  ns <- asNamespace("vofi")
  vofi_register_tax_module("na_tax", function(params, spec) list(name = "na_tax"),
                           label = "NA-Steuer", overwrite = TRUE)
  registerS3method("tax_init", "tax_na_tax", function(module, params, assets, measures, n_sim) {
    list()
  }, envir = ns)
  registerS3method("tax_step", "tax_na_tax", function(module, t, inputs, interest, state,
                                                      params) {
    list(payment = if (t == 2L) NA_real_ else 0, state = state, report = list())
  }, envir = ns)
  fin <- function(module, T, state, terminal_inputs, params) { # nolint. T wie Spec 00 10.3
    list(payment_T = 0, report = list())
  }
  registerS3method("tax_finalize", "tax_na_tax", fin, envir = ns)
  sc <- wsd_scenario(c(-100000, 10000, 10000, 100000), accounts = list(overdraft_limit_eur = Inf))
  sc$tax <- list(module = "na_tax")
  e <- expect_error(vofi_run(vofi_build(sc)), class = "vofi_error_contract")
  expect_identical(e$data$invariant, "N1")
  expect_identical(e$data$source, "tax_na_tax")
  expect_identical(e$data$row, "payment")
  # Ziehung mit NA im Habenzins (Kontoparameter)
  model <- wsd_skeleton()
  d <- fake_draws(2L, model$grid, paths = list(
    "accounts.deposit_rate_pa" = rbind(rep(0.02, 4), c(0.02, NA, 0.02, 0.02))
  ))
  e2 <- expect_error(eng_run_draws(model, d), class = "vofi_error_contract")
  expect_identical(e2$data$source, "accounts")
  # Kredit mit NA-Zinsen bzw. falscher Länge
  m_na <- model
  step <- m_na$instruments$bank$def$step
  m_na$instruments$bank$def$step <- function(state, t, ctx) {
    r <- step(state, t, ctx)
    if (t == 1L) r$flows$interest <- NA_real_
    r
  }
  e3 <- expect_error(wsd_parts(m_na), class = "vofi_error_contract")
  expect_identical(e3$data$source, "bank")
  expect_identical(e3$data$row, "interest")
  m_len <- model
  m_len$instruments$bank$def$step <- function(state, t, ctx) {
    r <- step(state, t, ctx)
    r$flows$repay <- c(r$flows$repay, 0, 0)
    r
  }
  d3 <- fake_draws(3L, model$grid)
  e4 <- expect_error(eng_run_draws(m_len, d3), class = "vofi_error_contract")
  expect_identical(e4$data$source, "bank")
  # Zusatzentnahmen
  p <- wsd_parts(model)
  bad <- matrix(c(0, -1, NA, 0), 1L)
  e5 <- expect_error(eng_balance(model, p$ctx, p$exo$ledger, extra_out = bad, book = FALSE,
                                 engine_env = p$env), class = "vofi_error_contract")
  expect_identical(e5$data$source, "extra_out")
  # Rest nach den Ketten nicht endlich: N1 statt eines R-Fehlers
  ch <- list(rest_sur = c(0, NA), rest_def = c(0, 0))
  e6 <- expect_error(eng_chain_rest_abort(ch, 3L), class = "vofi_error_contract")
  expect_identical(e6$data$sim, 2L)
})

test_that("Hilfen: eng_num, eng_inst_tax_rows, eng_report_add", {
  expect_identical(eng_num(NULL, 2L), c(0, 0))
  expect_identical(eng_num(3, 2L), c(3, 3))
  expect_identical(eng_num(c(a = 1, b = 2), 2L), c(1, 2))
  expect_identical(eng_num(2L, 2L), c(2, 2))
  e <- expect_error(eng_num(c(1, 2), 3L, "payment", "tax_x"), class = "vofi_error_contract")
  expect_identical(e$data$source, "tax_x")
  expect_error(eng_num("a", 1L), class = "vofi_error_contract")
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
  # Pflichtangaben bei Block building (Spec 01 Teil A 3.3, 3.4, 6.2; WS-B): Baujahr bzw. WE-Zahl,
  # Instandhaltungspauschale abgeschaltet; ohne Expander (WS-E2) ohne Zahlungswirkung
  sc$building <- list(existing_value_eur = 50000, maintenance = list(enabled = FALSE))
  sc$residual_value <- list(method = "zero", sale_cost_share = 0.04)
  res <- vofi_run(vofi_build(sc))
  expect_equal(res$ledger$values$equity_in_kind[1, ], c(50000, 0, 0))
  opp <- res$opportunity$ledger$values
  expect_equal(opp$opp_in_kind_sale[1, ], c(50000 * 0.96, 0, 0))
  orows <- res$opportunity$ledger$rows
  expect_identical(orows$category[orows$key == "opp_in_kind_sale"], "equity_in")
  expect_true(all(res$checks$ok))
})

# ---------------------------------------------------------------------------------------------
# Schnelle Wege (WS-PERF, 9.10): gleiche Ergebnisse wie die allgemeine Rechnung
# ---------------------------------------------------------------------------------------------

test_that("Instrument-Cache: zeilengleiche Kredite mit einer Zeile = Rechnung mit n Zeilen", {
  model <- suppressMessages(vofi_build(wsd_bench_scenario(20L, 12L)))
  for (uniform in c(TRUE, FALSE)) {
    dr <- wsp_draws(model, 30L, uniform = uniform)
    ctx <- eng_context(model, dr, eng_engine_env(model, quiet = TRUE))
    fast <- eng_inst_cache(model, ctx)
    slow <- local({
      local_mocked_bindings(inst_loan_state_one = function(st, n) NULL)
      eng_inst_cache(model, ctx)
    })
    info <- paste("uniform", uniform)
    expect_identical(names(fast), names(slow), info = info)
    for (id in names(fast)) {
      wsp_expect_same(fast[[id]]$flows, slow[[id]]$flows, paste(info, id))
      wsp_expect_same(fast[[id]]$memo, slow[[id]]$memo, paste(info, id))
      expect_identical(fast[[id]]$balance, slow[[id]]$balance, info = paste(info, id))
      expect_identical(fast[[id]]$neg_amort, slow[[id]]$neg_amort, info = paste(info, id))
    }
    wsp_expect_same(attr(fast, "totals"), attr(slow, "totals"), info)
  }
  # zeilengleicher Zustand wird erkannt, verschiedene Läufe nicht
  ctx_u <- eng_context(model, wsp_draws(model, 4L, uniform = TRUE), NULL)
  ctx_v <- eng_context(model, wsp_draws(model, 4L), NULL)
  k <- model$instruments$kfw
  one <- inst_loan_state_one(k$def$init(k$spec, ctx_u), 4L)
  expect_identical(length(one$B), 1L)
  expect_identical(nrow(one$draws), 1L)
  expect_null(inst_loan_state_one(k$def$init(k$spec, ctx_v), 4L))
  expect_null(inst_loan_state_one(k$def$init(k$spec, ctx_u), 1L))
  expect_true(eng_inst_builtin(k$def))
  expect_false(eng_inst_builtin(utils::modifyList(k$def, list(step = function(state, t, ctx) {
    inst_loan_step(state, t, ctx)
  }))))
})

test_that("Wiederholungsläufe: schnelle Schleife = allgemeine Periodenschleife (12.8)", {
  model <- suppressMessages(vofi_build(wsd_bench_scenario(20L, 12L)))
  for (n in c(1L, 40L)) {
    dr <- if (n == 1L) NULL else wsp_draws(model, n)
    p <- suppressWarnings(suppressMessages(wsd_parts(model, dr)))
    delta <- p$ctx$by_period(p$ctx$grid$delta)
    for (amt in c(0, 2500, 40000)) {
      eo <- -p$ctx$by_sim(amt) * delta
      run <- function() {
        eng_balance(model, p$ctx, p$exo$ledger, extra_out = eo, book = FALSE,
                    engine_env = p$env)
      }
      expect_true(eng_fast_loop_ok(p$env$setup$inv$chains, FALSE, TRUE, TRUE))
      a <- run()
      b <- local({
        local_mocked_bindings(eng_fast_loop_ok = function(...) FALSE)
        run()
      })
      wsp_expect_same(a, b, paste(n, amt))
    }
  }
})

test_that("tax_none ohne Aufruf je Periode = Aufruf über das Generic (10.6)", {
  model <- suppressMessages(vofi_build(wsd_bench_scenario(20L, 12L)))
  expect_s3_class(model$tax, "tax_none")
  via_generic <- model
  class(via_generic$tax) <- c("vofi_test_none", class(model$tax))
  expect_false(identical(eng_tax_fun(via_generic$tax, "tax_step"), tax_step.tax_none))
  for (n in c(1L, 70L)) {
    dr <- if (n == 1L) NULL else wsp_draws(model, n)
    a <- suppressWarnings(suppressMessages(eng_run_draws(model, dr, store = "full")))
    b <- suppressWarnings(suppressMessages(eng_run_draws(via_generic, dr, store = "full")))
    wsp_expect_same(a$ledger$values, b$ledger$values, paste(n, "Ledger"))
    expect_identical(a$ledger$rows, b$ledger$rows)
    wsp_expect_same(wsp_chunk_parts(a), wsp_chunk_parts(b), paste(n, "Ergebnis"))
  }
})

test_that("eng_sum_last = letzte Spalte von ledger_sum()", {
  p <- suppressWarnings(suppressMessages(wsd_parts(
    suppressMessages(vofi_build(wsd_bench_scenario(20L, 12L))),
    NULL
  )))
  led <- p$exo$ledger
  keys <- ledger_select(led, section = "project")
  expect_gt(length(keys), 2L)
  expect_identical(eng_sum_last(led, keys), ledger_sum(led, section = "project")[, led$T + 1L])
  expect_identical(eng_sum_last(led, keys[1L]), led$values[[keys[1L]]][, led$T + 1L])
  expect_identical(eng_sum_last(led, character(0)), numeric(led$n))
})

test_that("Ketten ohne Betrag (8.9): übersprungene Glieder liefern dieselben Flüsse", {
  acc <- wsd_acc(g = c(0, 40, 10, 100), kk = c(20, 0, 5, 0), kkp = c(0, 10, 0, 0),
                 lmin = c(0, 10, 20, 0), kl = c(100, 30, Inf, 0), thr = 15)
  rt <- eng_chain_consts(acc)
  chains <- list(
    list(c("od_repay", "dep_invest"), c("dep_withdraw", "od_draw", "equity_call")),
    list(c("od_repay", "dep_fill_reserve", "dep_invest"),
         c("dep_withdraw", "od_draw", "dep_use_reserve", "penalty_rate")),
    list(c("od_repay", "dep_invest"), c("dep_withdraw", "dep_use_reserve", "stop"))
  )
  amounts <- list(rep(0, 4L), c(-10, -3, 0, -0.5), c(5, 0, 12, 1), c(-10, 4, 0, 2))
  for (ch in chains) {
    cc <- eng_chain_compile(eng_build_chain(ch[[1L]]), eng_build_chain(ch[[2L]]))
    gen <- cc
    gen$s$all_inline <- FALSE
    gen$d$all_inline <- FALSE
    for (amt in amounts) for (skip in c(FALSE, TRUE)) {
      a <- eng_chain_step(cc, acc$G, acc$KK, acc$KKP, amt, 1L, 2L, NULL, NULL, rt,
                          acc$Lmin[, 2L], acc$KL[, 2L], collect = TRUE, skip_external = skip)
      b <- eng_chain_step(gen, acc$G, acc$KK, acc$KKP, amt, 1L, 2L, NULL, NULL, rt,
                          acc$Lmin[, 2L], acc$KL[, 2L], collect = TRUE, skip_external = skip)
      info <- paste(c(unlist(ch), amt, skip), collapse = " ")
      for (f in c("G", "KK", "KKP", "rest_sur", "rest_def", "ext", "flows", "flags")) {
        expect_identical(a[[f]], b[[f]], info = paste(info, f))
      }
      # markierte Flüsse übersprungener Glieder sind in allen Läufen 0
      expect_true(all(vapply(a$flows[a$fz], function(x) all(x == 0), logical(1))), info = info)
      expect_false(any(b$fz), info = info)
      if (all(amt <= 0)) expect_true(any(a$fz), info = info)
    }
  }
})

test_that("Markierungen je Lauf: Kontokorrent-Schwelle, Strafzinstranche, Nachschuss (9.8)", {
  # Schwelle und Limit so, dass ein Teil der Läufe sie überschreitet (gemischte Markierungen)
  sc <- wsd_bench_scenario(20L, 12L)
  sc$accounts$overdraft_flag_threshold_eur <- 96000
  sc$accounts$overdraft_limit_eur <- 97000
  model <- suppressWarnings(suppressMessages(vofi_build(sc)))
  dr <- wsp_draws(model, 60L)
  p <- suppressWarnings(suppressMessages(wsd_parts(model, dr)))
  st <- p$core$stocks
  fl <- p$core$flags
  zero <- vofi_tol$zero_abs
  expect_true(any(fl$overdraft_threshold) && !all(fl$overdraft_threshold))
  expect_true(any(fl$limit_breach) && !all(fl$limit_breach))
  expect_identical(fl$overdraft_threshold, rowSums((st$KK + st$KKP) > 96000) > 0)
  expect_identical(fl$limit_breach, rowSums(st$KKP > zero) > 0)
  ns <- ledger_sum(p$core$ledger, section = "equity", category = c("equity_call", "shortfall"))
  expect_identical(fl$shortfall, rowSums(ns > zero) > 0 | fl$limit_breach)
  # ohne Schwelle (Inf) und ohne Strafzinstranche: alle FALSE
  p0 <- suppressWarnings(suppressMessages(wsd_parts(
    suppressMessages(vofi_build(wsd_bench_scenario(20L, 12L))), wsp_draws(model, 5L)
  )))
  expect_false(any(p0$core$flags$overdraft_threshold))
})
