# Tests für R/opportunity.R (WS-D; Spec 00 Abschnitt 9.5, R-61, R-68, R-81): Modell und exogene
# Zeilen der Unterlassungsalternative, Prüffälle 9.5 und Sacheinlage, I6, vofi_opportunity().

test_that("eng_opportunity_model: keine Instrumente, ohne Ü3, D4 extern -> penalty_rate", {
  model <- wsd_skeleton()
  model$surplus_chain <- c(model$surplus_chain[1L],
                           list(loan_prepay = reg_get("account_action", "loan_prepay")),
                           model$surplus_chain[2L])
  m <- eng_opportunity_model(model)
  expect_length(m$instruments, 0L)
  expect_identical(names(m$surplus_chain), c("od_repay", "dep_invest"))
  expect_identical(names(m$deficit_chain), c("dep_withdraw", "od_draw", "penalty_rate"))
  expect_true(isTRUE(m$accounts$opp_regular_penalty))
  sc <- wsd_scenario(c(0, 0), accounts = list(deficit_order = c("dep_withdraw", "od_draw",
                                                                "penalty_rate")))
  m2 <- eng_opportunity_model(vofi_build(sc))
  expect_identical(names(m2$deficit_chain), c("dep_withdraw", "od_draw", "penalty_rate"))
  expect_null(m2$accounts$opp_regular_penalty)
})

test_that("eng_opportunity_exo: Eigenkapitalzeilen und Nachschuss als Einlage (9.5 Nr. 1)", {
  sc <- wsd_scenario(c(-10000, -3000, 16000), ek = list(type = "equity", amount_eur = 10000))
  model <- vofi_build(sc)
  p <- suppressMessages(wsd_parts(model))
  exo <- eng_opportunity_exo(p$ctx, p$core$ledger, model$rows_meta$opp$opp_rows)
  expect_true(all(exo$rows$section == "equity"))
  expect_true(all(c("ek__in", "ek__out", "opp_equity_call_in") %in% exo$rows$key))
  expect_false(any(c("z__value", "equity_call") %in% exo$rows$key))
  expect_equal(exo$values$opp_equity_call_in[1L, ], c(0, 3000, 0))
  expect_identical(exo$rows$label[exo$rows$key == "opp_equity_call_in"],
                   lbl("core.rows.opp_equity_call_in"))
  exo2 <- eng_opportunity_exo(p$ctx, p$core$ledger)
  expect_identical(exo2$rows, exo$rows)
})

test_that("Prüffall Sacheinlage (R-68): Sollwerte der Investition und der Alternative", {
  res <- vofi_run(vofi_build(wsd_in_kind_scenario()))
  v <- res$ledger$values
  expect_equal(v$equity_in_kind[1L, ], c(300000, 0))
  expect_equal(v$loan_alt_assumed[1L, ], c(200000, 0))
  expect_equal(v$net_position[1L, 1L], -200000)
  expect_equal(v$loan_alt_interest[1L, 2L], -6000)
  expect_equal(res$kpis$terminal_value, 318700)
  expect_equal(res$kpis$terminal_value_opp, 290700)
  expect_equal(res$kpis$delta_terminal_value, 28000)
  expect_equal(res$opportunity$ledger$values$opp_in_kind_sale[1L, ], c(285000, 0))
  expect_true(all(res$checks$ok))
  expect_true(all(res$opportunity$checks$ok))
  # ohne Bestandswert: keine Sacheinlage, kein Verkauf, EW_U = 0
  r0 <- vofi_run(vofi_build(wsd_in_kind_scenario(existing_value = NULL)))
  expect_equal(r0$kpis$terminal_value, 318700)
  expect_equal(r0$kpis$terminal_value_opp, 0)
  expect_false("opp_in_kind_sale" %in% r0$opportunity$ledger$rows$key)
})

test_that("Verkauf unter den Bestandsdarlehen: opp_in_kind_sale als Entnahme", {
  expect_warning(res <- vofi_run(vofi_build(wsd_in_kind_scenario(existing_value = 150000))),
                 class = "vofi_warning_plausibility")
  orows <- res$opportunity$ledger$rows
  expect_identical(orows$category[orows$key == "opp_in_kind_sale"], "equity_out")
  expect_equal(res$opportunity$ledger$values$opp_in_kind_sale[1L, 1L], 150000 * 0.97 - 200000)
  expect_true(all(res$opportunity$checks$ok))
})

test_that("I6: ohne Entnahmen und Kontokorrent EW_U = Summe EL * Produkt (1 + h_net)", {
  sc <- wsd_scenario(c(-100000, 20000, 20000, 90000),
                     ek = list(type = "equity", amount_eur = 100000),
                     accounts = list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08,
                                     deposit_withholding_tax_share = 0.25))
  res <- vofi_run(vofi_build(sc))
  expect_equal(res$kpis$terminal_value_opp, 100000 * (1 + 0.02 * 0.75)^3)
  expect_false(res$flags$opp_limit_breach)
})

test_that("Alternative nutzt die Strafzinstranche zum Regelzins s (R-81)", {
  sc <- wsd_scenario(c(-10000, rep(5000, 5)),
                     ek = list(type = "equity", amount_eur = 10000, withdrawals_pa = 4000),
                     accounts = list(overdraft_rate_pa = 0.1, penalty_spread_pa = 0.05))
  expect_warning(res <- vofi_run(vofi_build(sc)), class = "vofi_warning_plausibility")
  kkp <- res$opportunity$ledger$values$odp_balance[1L, ]
  # G: 10.000 -> 6.000 -> 2.000; ab t = 3 KKP zum Regelzins 10 % (nicht 15 %)
  expect_equal(kkp, c(0, 0, 0, 2000, 2000 * 1.1 + 4000, (2000 * 1.1 + 4000) * 1.1 + 4000))
  expect_true(res$flags$opp_limit_breach)
  expect_true(all(res$opportunity$ledger$values$equity_call == 0))
})

test_that("vofi_opportunity: Ergebnis der Alternative mit Endwert EW_U", {
  model <- wsd_skeleton()
  res <- vofi_run(model)
  opp <- vofi_opportunity(res)
  expect_s3_class(opp, "vofi_result")
  expect_equal(opp$kpis$terminal_value, 42448.32, tolerance = 1e-9)
  expect_equal(opp$kpis$terminal_value_ex_rv, opp$kpis$terminal_value)
  expect_identical(opp$meta$alternative, "opportunity")
  expect_true(lbl("engine.opportunity_note") %in% opp$meta$notes)
  expect_true(all(opp$checks$ok))
  expect_null(opp$opportunity)
  expect_false(any(opp$ledger$rows$section %in% c("project", "loans")))
  expect_equal(vofi_opportunity(model)$kpis, opp$kpis)
  expect_error(vofi_opportunity(list()), class = "vofi_error_input")
  bad <- res
  bad$opportunity$ledger <- NULL
  expect_error(vofi_opportunity(bad), class = "vofi_error_input")
})
