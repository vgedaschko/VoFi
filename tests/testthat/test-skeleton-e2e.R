# Walking Skeleton Ende-zu-Ende (Integrator; Spec 00 Anhang A, Abschnitte 2.3 Welle 0, 9, 15.3).
# Kette: Einlesen, Aufloesen und Pruefen, Bauen, Rechnen, Ausgeben (vofi_read_scenario bis print)
# mit den Handrechnungswerten aus Anhang A; zusätzlich Orakel (a) über die Engine (Memo 01 §10)
# und dieselbe Rechnung aus einer R-Liste (vofi_scenario()).

#' Absolute Abweichung höchstens tol (Orakeltoleranz 1e-6 EUR, Spec 00 2.13)
expect_close <- function(object, expected, tol = vofi_tol$oracle_abs, info = NULL) {
  dev <- if (length(object) == length(expected)) max(abs(object - expected)) else Inf
  testthat::expect(isTRUE(dev <= tol),
                   paste0("Abweichung ", format(dev), " > ", format(tol),
                          if (!is.null(info)) paste0(" (", info, ")")))
  invisible(object)
}

skeleton_result <- function() {
  vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
}

test_that("Anhang A: Abnahme Phase 0 (Kette l\u00e4uft und liefert die Handrechnung)", {
  expect_true("skeleton" %in% vofi_example())
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  expect_s3_class(sc, "vofi_scenario")
  expect_identical(sc$schema_version, 1L)
  expect_identical(sc$project$valuation_date, as.Date("2027-01-01"))
  expect_identical(sc$components$z$values$kind, "series_t")
  expect_identical(sc$financing$bank$payments_per_year, 1L)
  expect_identical(sc$accounts$overdraft_limit_eur, node_const(Inf))
  spec <- vofi_resolve(sc)
  expect_s3_class(spec, "vofi_spec")
  expect_identical(spec$project$tax_regime, "wu_kapges")
  expect_identical(spec$financing$bank$followup_rate_pa, node_ref("market.mortgage_rate"))
  val <- vofi_validate(sc)
  expect_s3_class(val, "vofi_validation")
  expect_identical(nrow(val[val$severity == "error", ]), 0L)
  model <- vofi_build(sc)
  expect_s3_class(model, "vofi_model")
  expect_identical(names(model$nodes), c("ek", "z"))
  expect_identical(names(model$instruments), "bank")
  res <- vofi_run(model)
  expect_s3_class(res, "vofi_result")
  out <- capture.output(print(res))
  expect_true(any(grepl("52.830,80", out, fixed = TRUE)))
  expect_true(any(grepl("42.448,32", out, fixed = TRUE)))
  expect_true(any(grepl("10.382,48", out, fixed = TRUE)))
})

test_that("Anhang A: Kennzahlen EW, EW_U, Endwertdifferenz", {
  res <- skeleton_result()
  expect_close(res$kpis$terminal_value, 52830.80)
  expect_close(res$kpis$terminal_value_opp, 40000 * 1.02^3)
  expect_close(res$kpis$terminal_value_opp, 42448.32)
  expect_close(res$kpis$delta_terminal_value, 10382.48)
  expect_close(res$kpis$terminal_value_ex_rv, 52830.80)
  expect_true(all(is.na(unlist(res$kpi_na))))
  expect_identical(res$meta$primary_kpi, "delta_terminal_value")
  expect_identical(res$meta$mode, "deterministic")
  expect_identical(res$meta$scenario_id, "skeleton")
  expect_close(res$opportunity$EW, res$kpis$terminal_value_opp)
})

test_that("Anhang A: Periodenwerte der Handrechnung und Finanzierungssaldo 0", {
  res <- skeleton_result()
  v <- res$ledger$values
  expect_equal(v$z__value[1, ], c(-100000, 30000, 40000, 50000))
  expect_equal(v$ek__in[1, ], c(40000, 0, 0, 0))
  expect_equal(v$loan_bank_draw[1, ], c(60000, 0, 0, 0))
  expect_close(v$loan_bank_interest[1, ], c(0, -3000, -3000, -3000))
  expect_close(v$loan_bank_repay_balloon[1, ], c(0, 0, 0, -60000))
  expect_equal(v$loan_bank_balance[1, ], c(60000, 60000, 60000, 0))
  expect_close(v$dep_interest[1, ], c(0, 0, 540, 1290.80))
  expect_close(v$dep_invest[1, ], c(0, -27000, -37540, 0))
  expect_close(v$dep_withdraw[1, ], c(0, 0, 0, 11709.20))
  expect_close(v$dep_balance[1, ], c(0, 27000, 64540, 52830.80))
  expect_close(v$net_position[1, ], c(-60000, -33000, 4540, 52830.80))
  expect_true(all(abs(v$balance_check) <= vofi_tol$balance_rel * 100000))
  expect_true(all(v$od_balance == 0) && all(v$equity_call == 0) && all(v$tax == 0))
  expect_vofi_invariants(res)
  expect_true(all(res$checks$ok))
  expect_identical(res$checks$invariant, c("I1", "I2", "I3a", "I3b", "I3c", "N1", "N2"))
  opp <- res$opportunity$ledger$values
  expect_close(opp$dep_balance[1, ], 40000 * 1.02^(0:3))
  expect_true(all(helper_invariants(res$opportunity$ledger)$ok))
})

test_that("Anhang A: Ledger-Vertrag (Schl\u00fcssel, Tags, Grob-Reihenfolge)", {
  res <- skeleton_result()
  rows <- res$ledger$rows
  expect_identical(rows$key[rows$section == "stocks"],
                   c("loan_bank_balance", "od_balance", "odp_balance", "dep_balance",
                     "tax_liability", "net_position"))
  expect_identical(rows$key[1:3], c("z__value", "ek__in", "ek__out"))
  expect_identical(rows$source_id[rows$key == "z__value"], "z")
  expect_identical(rows$local_row[rows$key == "z__value"], "value")
  expect_identical(rows$source_type[rows$key == "ek__in"], "equity")
  expect_identical(rows$tax_category[rows$key == "z__value"], "not_applicable")
  expect_identical(rows$label[rows$key == "z__value"], "Zahlungsfolge: Zahlung")
  expect_false(is.unsorted(rows$order))
  for (k in c("equity_call", "shortfall", "od_draw", "odp_draw", "dep_wht", "tax",
              "balance_check", "net_position")) {
    expect_true(k %in% rows$key, info = k)
  }
  expect_identical(nrow(res$flags), 1L)
  expect_false(any(unlist(res$flags[, c("shortfall", "limit_breach", "stopped")])))
})

test_that("Fixture skeleton.yaml und R-Liste ergeben dasselbe Ergebnis", {
  a <- vofi_run(vofi_build(example_scenario("skeleton")))
  b <- vofi_run(vofi_build(vofi_scenario(list(
    schema_version = 1L,
    meta = list(scenario_id = "skeleton", title = "Ger\u00fcst"),
    project = list(perspective = "wu_privat", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 3L),
    components = list(z = list(type = "custom_series", label = "Zahlungsfolge",
                               values = c(-100000, 30000, 40000, 50000))),
    financing = list(
      ek = list(type = "equity", amount_eur = 40000),
      bank = list(type = "bullet_loan", amount_eur = 60000, rate_pa = 0.05, term_years = 3,
                  payments_per_year = 1L)
    ),
    accounts = list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08, overdraft_limit_eur = Inf,
                    surplus_order = c("od_repay", "dep_invest"),
                    deficit_order = c("dep_withdraw", "od_draw", "equity_call")),
    analysis = list(kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value"))
  ))))
  expect_identical(a$ledger$values, b$ledger$values)
  expect_identical(a$kpis, b$kpis)
  sc <- example_scenario("skeleton")
  expect_identical(unclass(vofi_scenario(sc))[names(sc)], unclass(sc)[names(sc)])
})

test_that("Orakel (a) \u00fcber die Engine (Annuit\u00e4t, endf\u00e4llig, Kontokorrent)", {
  res <- vofi_run(vofi_build(example_scenario("oracle_a")))
  o <- oracle_a_values()
  v <- res$ledger$values
  expect_close(res$kpis$terminal_value, o$kpi$terminal_value)
  expect_close(res$kpis$terminal_value_opp, o$kpi$terminal_value_opp)
  expect_close(res$kpis$delta_terminal_value, o$kpi$delta_terminal_value)
  expect_close(res$kpis$terminal_value_ex_rv, o$kpi$terminal_value - 40000)
  chk <- list(od_draw = "od_draw", od_repay = "od_repay", od_interest = "od_interest",
              dep_invest = "dep_invest", dep_withdraw = "dep_withdraw",
              dep_interest = "dep_interest", dep_balance = "dep_balance",
              od_balance = "od_balance", net_position = "net_position",
              loan_ann_interest = "ann_interest", loan_ann_repay = "ann_repay",
              loan_ann_balance = "ann_balance", loan_bul_interest = "bul_interest",
              loan_bul_repay_balloon = "bul_repay_balloon", loan_bul_balance = "bul_balance")
  for (k in names(chk)) {
    expect_close(v[[k]][1, ], o[[chk[[k]]]], info = k)
  }
  expect_close(res$opportunity$BS[1, ], o$opp_balance)
  expect_vofi_invariants(res)
  ref <- example_result()
  expect_identical(res$ledger$rows$key[res$ledger$rows$section == "stocks"],
                   ref$ledger$rows$key[ref$ledger$rows$section == "stocks"])
})

test_that("Validierung bricht den Bau mit vofi_error_validation ab", {
  sc <- example_scenario("skeleton")
  bad <- sc
  bad$accounts$surplus_order <- c("dep_invest", "od_repay")
  err <- tryCatch(vofi_build(bad), error = identity)
  expect_s3_class(err, "vofi_error_validation")
  expect_s3_class(err$data$report, "vofi_validation")
  expect_true("validation.chain_order" %in% err$data$report$code)
  bad2 <- sc
  bad2$components$z$type <- "custom_serie"
  v <- vofi_validate(bad2)
  expect_true("validation.type_unknown" %in% v$code)
  expect_match(v$message[v$code == "validation.type_unknown"][1], "custom_series",
               fixed = TRUE)
  expect_error(vofi_build(bad2), class = "vofi_error_validation")
})

test_that("Overrides (Schicht 8) in Baum- und Pfadform wirken gleich", {
  sc <- example_scenario("skeleton")
  base <- vofi_run(vofi_build(sc))$kpis$terminal_value
  tree <- vofi_run(vofi_build(sc, overrides = list(accounts = list(deposit_rate_pa = 0.03))))
  path <- vofi_run(vofi_build(sc, overrides = list("accounts.deposit_rate_pa" = 0.03)))
  expect_false(isTRUE(all.equal(tree$kpis$terminal_value, base)))
  expect_identical(path$kpis$terminal_value, tree$kpis$terminal_value)
  spec_path <- vofi_run(vofi_build(vofi_resolve(sc),
                                   overrides = list("accounts.deposit_rate_pa" = 0.03)))
  expect_identical(spec_path$kpis$terminal_value, tree$kpis$terminal_value)
  expect_identical(scn_overrides_tree(list("a.b" = NULL, c = 1)),
                   list(c = 1, a = list(b = NULL)))
  expect_error(scn_overrides_tree(1), class = "vofi_error_input")
})

test_that("Kennzahlen: Filter nach requires (9.1 Stufe 9), uses_inputs am Steuermodul", {
  local_registry_state <- reg_state$types
  withr::defer(reg_state$types <- local_registry_state)
  mv <- vofi_type("tk_mv", "kpi", label = "Marktwert T", requires = "market_value",
                  labels = list(description = "d", params = list(), rows = list()),
                  compute = function(core, ctx) vofi_kpi_value(rep(1, core$n)))
  vofi_register_type(mv)
  sc <- example_scenario("skeleton")
  sc$analysis$kpis <- "default"
  m <- vofi_build(sc)
  expect_false("tk_mv" %in% names(m$kpis))
  expect_true(all(c("terminal_value", "delta_terminal_value") %in% names(m$kpis)))
  sc$components$mv <- list(type = "custom_series", section = "memo", category = "market_value",
                           values = c(100000, 101000, 102000, 103000))
  expect_true("tk_mv" %in% names(vofi_build(sc)$kpis))
  sc2 <- example_scenario("skeleton")
  sc2$analysis$kpis <- c("terminal_value", "tk_mv")
  expect_message(m2 <- vofi_build(sc2), "tk_mv", fixed = TRUE)
  expect_identical(names(m2$kpis), "terminal_value")
  expect_false(isTRUE(m2$tax$uses_inputs))
  expect_null(m2$tax_uses_inputs)
  expect_null(m2$has_prepay)
  expect_identical(eng_kpi_available(m2$spec, m2$base$flows), "opportunity")
})

test_that("ctx$setting()/ctx$timing() liefern Defaults inkl. rasterabhaengiger Termine (6.2)", {
  g <- make_grid("annual")
  eq <- make_component("equity", amount_eur = 1000, id = "ek")
  ctx <- make_ctx(1L, grid = g, spec = eq)
  expect_identical(ctx$setting(eq, "date"), g$valuation_date)
  expect_identical(ctx$setting(eq, "to"), g$end_date)
  expect_identical(ctx$timing(eq, "to")$date, g$end_date)
  rec <- make_component("recurring", amount_eur = 100, category = "rent", id = "r")
  ctx2 <- make_ctx(2L, grid = g, spec = rec)
  expect_identical(ctx2$setting(rec, "start_event"), g$completion_date)
  expect_identical(ctx2$timing(rec, "start_event")$shift, c(0, 0))
  bank <- make_component("bullet_loan", amount_eur = 1000, rate_pa = 0.05, term_years = 3,
                         id = "bank")
  ctx3 <- make_ctx(1L, grid = g, spec = bank)
  expect_identical(ctx3$setting(bank, "start"), g$valuation_date)
  expect_identical(ctx3$param(bank, "fees.processing_fee_share"), 0)
  expect_identical(ctx3$setting(bank, "repayment_grant.effect"), "shorten_term")
  expect_null(ctx3$param(bank, "repayment_grant.share"))
})
