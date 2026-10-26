# Tests für R/engine-build.R (WS-D; Spec 00 Abschnitte 9.1, 9.11): Modellfelder, Topo-Ordnung,
# Zeilenmetadaten, Basisfall-Vorlauf, Sampler-Plan, Kennzahlenfilter, Entscheidungsknoten.

decision_scenario <- function(approved = 0, p = 0.7, fallback_ops = NULL, funding = NULL) {
  sc <- wsd_scenario(c(-100000, 5000, 5000, 110000),
                     ek = list(type = "equity", amount_eur = 100000),
                     accounts = list(overdraft_limit_eur = Inf, overdraft_rate_pa = 0.08))
  raw <- unclass(sc)
  # Pflichtfelder nach Spec 01 Teil B 4.1 (instrument_type, measures) bzw. Spec 00 4.11 (label
  # der Variante); die Maßnahme erzeugt ohne Expander (WS-E2) keine Zahlungen
  raw$measures <- list(m1 = list(measure_type = "sonstige", year = 2027L, cost_eur = 1000))
  raw$funding <- funding %||% list(kfw = list(instrument_type = "grant", measures = list("m1"),
                                              approval_timing = "before_start",
                                              fallback_variant = "ohne", approved = approved,
                                              approval_probability = p))
  ops <- fallback_ops %||% list(remove = "funding.kfw",
                                replace = list("financing.ek.amount_eur" = 90000))
  raw$variants <- list(ohne = c(list(label = "Ohne Förderung"), ops))
  vofi_scenario(raw)
}

test_that("vofi_build: Modellfelder, Zeilenmetadaten, Basisfall-Vorlauf (9.1)", {
  model <- wsd_skeleton()
  expect_s3_class(model, "vofi_model")
  expect_identical(names(model$instruments), "bank")
  expect_identical(model$equity, "ek")
  expect_identical(names(model$surplus_chain), c("od_repay", "dep_invest"))
  expect_identical(names(model$deficit_chain), c("dep_withdraw", "od_draw", "equity_call"))
  expect_identical(model$rows_meta$inv$ids, "bank")
  expect_true(all(startsWith(model$rows_meta$inv$loans$key, "loan_bank_")))
  expect_identical(model$rows_meta$inv$check$key, "balance_check")
  expect_null(model$rows_meta$opp$ids)
  expect_identical(names(model$rows_meta$opp$opp_rows), c("call_in", "sale_in", "sale_out"))
  expect_identical(model$base$n, 1L)
  expect_true(all(c("z", "ek") %in% names(model$base$flows)))
  expect_null(model$base$auto)
  expect_null(model$auto_id)
  expect_identical(model$contract_version, VOFI_CONTRACT_VERSION)
  # normalisierte Kontoparameter im Modell (4.13, 8.8; Vergleichbarkeit 9.6 Nr. 2, WSD-07)
  expect_true(all(c("deposit_rate_pa", "overdraft_rate_pa", "overdraft_limit_eur",
                    "surplus_order", "deficit_order", "prepay") %in% names(model$accounts)))
  expect_identical(model$accounts[["deposit_rate_pa"]], model$spec$accounts[["deposit_rate_pa"]])
  sc2 <- vofi_read_scenario(vofi_example("skeleton"))
  sc2$accounts$deposit_rate_pa <- 0.03
  expect_false(identical(vofi_build(sc2)$accounts, model$accounts))
  expect_true(nzchar(model$hash))
  expect_identical(vofi_build(vofi_read_scenario(vofi_example("skeleton")))$hash, model$hash)
})

test_that("Sampler-Plan: smp_plan() von WS-C, sonst NULL", {
  model <- wsd_skeleton()
  if (is.null(get0("smp_plan", envir = asNamespace("vofi"), inherits = FALSE))) {
    expect_null(model$sampler)
  } else {
    expect_false(is.null(model$sampler))
  }
})

test_that("Eingabeprüfung und Validierungsfehler", {
  expect_error(vofi_build(list()), class = "vofi_error_input")
  sc <- wsd_scenario(c(-1, 1), accounts = list(surplus_order = c("dep_invest")))
  e <- expect_error(vofi_build(sc), class = "vofi_error_validation")
  expect_s3_class(e$data$report, "vofi_validation")
})

test_that("Topologische Ordnung nach Bezügen, Gleichstand nach id, Zyklus als Fehler", {
  sc <- wsd_scenario(c(-100000, 0, 0), components = list(
    b = list(type = "custom_series", values = list(ref = "components.a.values")),
    a = list(type = "custom_series", values = c(0, 1, 2))
  ))
  model <- vofi_build(sc)
  ord <- names(model$nodes)
  expect_lt(match("a", ord), match("b", ord))
  expect_identical(model$nodes$b$deps, "a")
  cyc <- wsd_scenario(c(-100000, 0, 0), components = list(
    b = list(type = "custom_series", values = list(ref = "components.a.values")),
    a = list(type = "custom_series", values = list(ref = "components.b.values"))
  ))
  expect_error(vofi_build(cyc), class = "vofi_error_validation")
})

test_that("Kennzahlenfilter nach requires mit Hinweis bei ausdrücklicher Anforderung", {
  kpis <- list(a = list(requires = character(0)), b = list(requires = "market_value"))
  spec <- list(analysis = list(kpis = c("a", "b")))
  expect_message(out <- eng_filter_kpis_requires(kpis, spec, list()), class = "vofi_message")
  expect_identical(names(out), "a")
  spec2 <- list(analysis = list(kpis = "default"))
  expect_silent(out2 <- eng_filter_kpis_requires(kpis, spec2, list()))
  expect_identical(names(out2), "a")
  avail <- eng_kpi_available(list(building = list(market_value_eur = 1)))
  expect_true(all(c("opportunity", "market_value") %in% avail))
})

test_that("eng_has_prepay erkennt Ü3 an den Zeilen der Aktion", {
  model <- wsd_skeleton()
  expect_false(eng_has_prepay(model))
  model$surplus_chain$loan_prepay <- reg_get("account_action", "loan_prepay")
  expect_true(eng_has_prepay(model))
})

test_that("Entscheidungsknoten: Ausweichvariante, Zusage im Modell V gleich 1 (9.11)", {
  sc <- decision_scenario(approved = 0, p = 0.7)
  model <- vofi_build(sc)
  dec <- model$decision
  expect_identical(dec$funding_id, "kfw")
  expect_identical(dec$key, "funding.kfw.approved")
  expect_identical(dec$fallback_variant, "ohne")
  expect_identical(dec$branch, 0L)
  expect_equal(dec$p, 0.7)
  expect_s3_class(dec$fallback, "vofi_model")
  expect_null(dec$fallback$decision)
  expect_identical(model$spec$funding$kfw$approved, node_const(1))
  res <- vofi_run(model)
  # deterministisch: realisierter Zweig (Ausweichvariante), der andere in decision$alternative
  expect_identical(res$decision$branch, 0L)
  expect_equal(res$ledger$values$ek__in[1L, 1L], 90000)
  expect_equal(res$decision$alternative$ledger$values$ek__in[1L, 1L], 100000)
  expect_equal(res$decision$p_approval, 0.7)
  r1 <- vofi_run(vofi_build(decision_scenario(approved = 1)))
  expect_identical(r1$decision$branch, 1L)
  expect_equal(r1$ledger$values$ek__in[1L, 1L], 100000)
})

test_that("Entscheidungsknoten: Fehlerfälle (9.11 Nr. 1)", {
  expect_error(vofi_build(decision_scenario(approved = 0.5)), class = "vofi_error_validation")
  two <- list(kfw = list(instrument_type = "grant", measures = list("m1"),
                         approval_timing = "before_start", fallback_variant = "ohne"),
              beg = list(instrument_type = "grant", measures = list("m1"),
                         approval_timing = "before_start", fallback_variant = "ohne"))
  expect_error(vofi_build(decision_scenario(funding = two)), class = "vofi_error_validation")
  # Ausweichvariante enthält den Knoten selbst: verschachtelt (keine Rekursion)
  keep <- list(replace = list("financing.ek.amount_eur" = 90000))
  expect_error(vofi_build(decision_scenario(fallback_ops = keep)),
               class = "vofi_error_validation")
  # Ausweichvariante enthält f ohne Knoten
  plain <- list(replace = list("funding.kfw.approval_timing" = "after_start"))
  expect_error(vofi_build(decision_scenario(fallback_ops = plain)),
               class = "vofi_error_validation")
  expect_false(isTRUE(eng_build_state$fallback))
  # nur aus einem Szenario (die Ausweichvariante braucht die Varianten)
  spec <- vofi_resolve(decision_scenario())
  expect_error(vofi_build(spec), class = "vofi_error_input")
})

test_that("eng_tax_param_values: Konstanten zu Werten, übrige Werte unverändert", {
  p <- eng_tax_param_values(list(a = node_const(0.2), b = "text", c = 3L), list(), NULL)
  expect_identical(p, list(a = 0.2, b = "text", c = 3L))
})
