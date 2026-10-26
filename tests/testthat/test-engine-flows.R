# Tests für R/engine-flows.R (WS-D; Spec 00 Abschnitte 6.1, 7.1-7.3, 9.2 Stufe 3, 9.6 Nr. 6):
# Engine-Umgebung, exogener Ledger, Laufzeitprüfung des Zeilenvertrags, extra_rows.

test_that("eng_engine_env: Felder und Sperren (6.1 Nr. 3)", {
  model <- wsd_skeleton()
  env <- eng_engine_env(model, quiet = TRUE)
  expect_identical(env$stage, "flows")
  expect_identical(env$components, list())
  expect_true(env$quiet)
  expect_identical(env$setup, list())
  expect_error(env$rebalance(), class = "vofi_error_contract")
  expect_error(env$auto("bank"), class = "vofi_error_contract")
  expect_false(eng_engine_env(model)$quiet)
})

test_that("eng_flows: Schlüssel <id>__<zeile>, Grob-Ordnung, Labels, Register", {
  model <- wsd_skeleton()
  env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, NULL, env)
  exo <- eng_flows(model, ctx, env)
  led <- exo$ledger
  expect_s3_class(led, "vofi_ledger")
  expect_identical(led$rows$key, c("z__value", "ek__in", "ek__out"))
  expect_identical(led$rows$source_id, c("z", "ek", "ek"))
  expect_identical(order(led$rows$order), seq_len(nrow(led$rows)))
  expect_match(led$rows$label[1L], "^Zahlungsfolge")
  expect_equal(led$values$z__value[1L, ], c(-100000, 30000, 40000, 50000))
  expect_identical(names(env$components), names(model$nodes))
  expect_setequal(names(env$components), c("z", "ek"))
  expect_null(env$current)
  expect_null(env$deps)
  expect_true(all(c("assets", "measures") %in% names(exo$registers)))
})

test_that("eng_check_flows: Dimension, deklarierte Zeilen, Vorzeichen (F2, F3, F5)", {
  def <- reg_get("flow", "custom_series")
  nd <- list(spec = list(id = "x"), def = def)
  ok <- vofi_flows(vofi_row("value", matrix(0, 1L, 3L), "project", "custom"))
  expect_true(eng_check_flows(ok, nd, 1L, 2L))
  expect_error(eng_check_flows(ok, nd, 2L, 2L), class = "vofi_error_contract")
  undeclared <- vofi_flows(vofi_row("other", matrix(0, 1L, 3L), "project", "custom"))
  expect_error(eng_check_flows(undeclared, nd, 1L, 2L), class = "vofi_error_contract")
  wrong_sign <- vofi_flows(vofi_row("value", matrix(c(0, 5, 0), 1L), "project", "capex"))
  expect_error(eng_check_flows(wrong_sign, nd, 1L, 2L), class = "vofi_error_contract")
  expect_error(eng_check_flows(list(), nd, 1L, 2L), class = "vofi_error_contract")
})

test_that("eng_row_label_key: Eintrag und Muster <präfix>_*", {
  def <- list(kind = "flow", name = "custom_series", rows = c("value", "tenant_*"))
  k <- eng_row_label_key(def, "tenant_a")
  expect_identical(k$row, "tenant_*")
  expect_identical(k$id, "a")
  expect_match(k$key, "rows.tenant_\\*$")
  expect_null(eng_row_label_key(def, "value")$id)
})

test_that("extra_rows: Anhängen, Prüfung von Klasse, Dimension, Abschnitt, Kollision", {
  model <- wsd_skeleton()
  env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, NULL, env)
  mk <- function(key = "ref__neg", section = "project", category = "custom", n = 1L,
                 horizon = 3L) {
    new_vofi_ledger(new_ledger_rows(key, section, category),
                    stats::setNames(list(matrix(1, n, horizon + 1L)), key), n = n,
                    T = horizon)
  }
  exo <- eng_flows(model, ctx, env, extra_rows = mk())
  expect_true("ref__neg" %in% exo$ledger$rows$key)
  expect_error(eng_flows(model, ctx, env, extra_rows = list()), class = "vofi_error_input")
  expect_error(eng_flows(model, ctx, env, extra_rows = mk(n = 2L)), class = "vofi_error_input")
  expect_error(eng_flows(model, ctx, env, extra_rows = mk(section = "equity",
                                                          category = "equity_in")),
               class = "vofi_error_input")
  expect_error(eng_flows(model, ctx, env, extra_rows = mk(key = "z__value")),
               class = "vofi_error_engine")
})
