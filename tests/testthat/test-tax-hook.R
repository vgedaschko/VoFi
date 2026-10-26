# Tests für R/tax-hook.R (WS-D; Spec 00 Abschnitt 10): Generics, Registrierung, vereinfachtes
# Modul, Eingaben mit Vorzeichenkonvention, Sperren, Berichtszeilen und die Pflichttests der
# Schnittstelle 10.10 Nr. 2-4 und 6 mit dem Test-Steuermodul test_flat.

#' Ziehungen mit Faktor auf die Zahlungsfolge z (apply multiply)
tax_factor_draws <- function(grid, f) {
  n <- length(f)
  targets <- data.frame(key = "components.z.values", target = "components.z.values",
                        kind = "static", apply = "multiply", stringsAsFactors = FALSE)
  new_vofi_draws("mc", n = n, sims = seq_len(n), blocks = 1L, block_size = n,
                 static = list("components.z.values" = f), paths = list(), targets = targets,
                 years = grid$years)
}

test_that("Default-Methoden der Generics melden vofi_error_registry (10.3)", {
  m <- structure(list(name = "x"), class = c("tax_unbekannt", "vofi_tax_module"))
  expect_error(tax_init(m, list(), list(), list(), 1L), class = "vofi_error_registry")
  expect_error(tax_step(m, 0L, list(), list(), list(), list()), class = "vofi_error_registry")
  expect_error(tax_finalize(m, 1L, list(), list(), list()), class = "vofi_error_registry")
})

test_that("vofi_register_tax_module: Prüfung der Argumente, Klasse, Defaults (10.2, 5.7)", {
  old <- reg_state$types
  withr::defer(reg_state$types <- old)
  expect_error(vofi_register_tax_module("Bad Name", function(params, spec) list()),
               class = "vofi_error_input")
  expect_error(vofi_register_tax_module("ok_name", "keine Funktion"), class = "vofi_error_input")
  expect_error(vofi_register_tax_module("ok_name", function(params, spec) list(),
                                        overwrite = NA), class = "vofi_error_input")
  expect_error(vofi_register_tax_module("ok_name", function(params, spec) list(),
                                        params = list(1)), class = "vofi_error_input")
  def <- vofi_register_tax_module("ok_name", function(params, spec) list(extra = 1),
                                  params = list(rate = vofi_param("share", default = 0)))
  expect_identical(def$kind, "tax")
  expect_true(isTRUE(def$uses_inputs))
  expect_identical(def$example, list(rate = 0))
  expect_true("ok_name" %in% vofi_types("tax")$name)
  m <- reg_get("tax", "ok_name")$constructor(list(rate = 0), list())
  expect_s3_class(m, c("tax_ok_name", "vofi_tax_module"), exact = TRUE)
  expect_identical(m$name, "ok_name")
  expect_identical(m$extra, 1)
  expect_error(vofi_register_tax_module("ok_name", function(params, spec) list()),
               class = "vofi_error_registry")
})

test_that("new_tax_module und tax_as_module", {
  m <- new_tax_module("abc", params = list(a = 1), x = 2)
  expect_s3_class(m, c("tax_abc", "vofi_tax_module"), exact = TRUE)
  expect_identical(m$x, 2)
  m2 <- tax_as_module("abc", list(b = 1), NULL)
  expect_identical(m2$params, list(b = 1))
  expect_identical(m2$name, "abc")
})

test_that("vofi_tax_module_simple: periodenweise Zahlung ohne Zustand", {
  old <- reg_state$types
  withr::defer(reg_state$types <- old)
  expect_error(vofi_tax_module_simple("einfach", function(x) 0), class = "vofi_error_input")
  vofi_tax_module_simple("einfach", function(inputs, params) {
    rep(100, length(inputs$exo[[1L]])) * (inputs$t > 0)
  }, label = "Einfach")
  sc <- wsd_scenario(c(-100000, 10000, 10000), accounts = list(overdraft_limit_eur = Inf))
  sc$tax <- list(module = "einfach")
  model <- vofi_build(sc)
  expect_s3_class(model$tax, "vofi_tax_simple")
  res <- vofi_run(model)
  expect_equal(res$ledger$values$tax[1L, ], c(0, -100, -100))
  expect_equal(res$ledger$values$tax_liability[1L, 3L], 0)
  st <- tax_init(model$tax, list(), list(), list(), 2L)
  expect_identical(st, list())
  fin <- tax_finalize(model$tax, 2L, st, list(residual_value = c(0, 0)), list())
  expect_equal(fin$payment_T, c(0, 0))
})

test_that("vofi_tax_module_simple: fun gilt auch bei vorhandenen Methoden (WSD-09)", {
  old <- reg_state$types
  withr::defer(reg_state$types <- old)
  expect_warning(vofi_tax_module_simple("none", function(inputs, params) 1000,
                                        label = "Ersatz"), class = "vofi_warning")
  sc <- wsd_scenario(c(-100000, 10000, 100000), accounts = list(overdraft_limit_eur = Inf))
  model <- vofi_build(sc)
  expect_identical(class(model$tax), c("vofi_tax_simple", "tax_none", "vofi_tax_module"))
  res <- vofi_run(model)
  expect_equal(res$ledger$values$tax[1L, ], c(-1000, -1000, -1000))
  expect_identical(eng_tax_fun(model$tax, "tax_step"), tax_step.vofi_tax_simple)
})

test_that("eng_tax_fun: Methode der eingebauten Klassen, sonst das Generic", {
  none <- new_tax_module("none")
  expect_identical(eng_tax_fun(none, "tax_step"), tax_step.tax_none)
  expect_identical(eng_tax_fun(none, "tax_finalize"), tax_finalize.tax_none)
  other <- new_tax_module("fremd")
  expect_identical(eng_tax_fun(other, "tax_step"), tax_step)
})

test_that("tax_inputs: zeilengenau, Vorzeichen disagio negativ, Metadaten (10.4, R-56)", {
  model <- wsd_skeleton()
  env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, NULL, env)
  exo <- eng_flows(model, ctx, env)
  rows <- exo$ledger$rows
  extra <- new_ledger_rows("x__dis", "loans", "disagio", tax_category = "interest_expense",
                           cash = FALSE, kind = "memo")
  led <- ledger_add(exo$ledger, extra, list(x__dis = matrix(c(0, 50, 0, 0), 1L)))
  tin <- tax_inputs(led, ctx, model$rows_meta$inv$loans)
  expect_true(all(led$rows$tax_category[match(names(tin$values), led$rows$key)] !=
                    "not_applicable"))
  expect_equal(tin$values$x__dis[1L, ], c(0, -50, 0, 0))
  expect_true(all(c("key", "source", "section", "category", "tax_category", "asset_id",
                    "measure_id", "cash", "extra") %in% names(tin$keys)))
  expect_true(all(tin$keys$source %in% c("exo", "inst")))
  expect_true("loan_bank_interest" %in% tin$keys$key[tin$keys$source == "inst"])
  sl <- tax_slice(tin, 2L, list(loan_bank_interest = -3000))
  expect_identical(sl$t, 1L)
  expect_equal(sl$delta, 1)
  expect_equal(sl$exo$x__dis, -50)
  expect_identical(names(sl$inst), "loan_bank_interest")
  empty <- tax_slice(NULL, 1L, grid = model$grid)
  expect_identical(empty$exo, list())
  expect_identical(empty$inst, list())
  expect_identical(nrow(empty$keys), 0L)
})

test_that("Sperre nach Perspektive: vofi_error_validation mit Bericht (10.2)", {
  restore <- register_tax_test_module("test_gesperrt")
  withr::defer(restore())
  def <- reg_get("tax", "test_gesperrt")
  def$perspectives <- "wu_privat"
  reg_add(def, source = "user", overwrite = TRUE)
  sc <- tax_test_scenario(module = "test_gesperrt")
  e <- expect_error(vofi_build(sc), class = "vofi_error_validation")
  expect_identical(e$data$report$code, "validation.tax_module_blocked")
  def$perspectives <- NULL
  def$blocked_regimes <- "privat_vermieter"
  reg_add(def, source = "user", overwrite = TRUE)
  sc$project$tax_regime <- "privat_vermieter"
  expect_error(vofi_build(sc), class = "vofi_error_validation")
})

test_that("Parameter-Defaults und Basisfallwerte der Modulparameter", {
  restore <- register_tax_test_module()
  withr::defer(restore())
  sc <- tax_test_scenario()
  sc$tax$params <- list(rate = 0.25)
  model <- vofi_build(sc)
  expect_identical(model$tax_params$rate, 0.25)
  expect_identical(model$tax_params$depreciation_years, 50)
  expect_identical(model$tax_params$lag, 0L)
  expect_s3_class(model$tax, "tax_test_flat")
  expect_true(isTRUE(model$tax$uses_inputs))
})

test_that("10.10 Nr. 2: Test-Modul mit s = 0 ist identisch mit dem Vor-Steuer-VoFi", {
  restore <- register_tax_test_module()
  withr::defer(restore())
  res0 <- vofi_run(vofi_build(tax_test_scenario(rate = 0)))
  sc_none <- tax_test_scenario()
  sc_none$tax <- NULL
  ref <- vofi_run(vofi_build(sc_none))
  expect_identical(res0$kpis, ref$kpis)
  keys <- ref$ledger$rows$key
  expect_identical(res0$ledger$values[keys], ref$ledger$values[keys])
  expect_identical(res0$opportunity$EW, ref$opportunity$EW)
  expect_true(all(res0$ledger$values$tax == 0))
  expect_true(all(c("tax_report_taxable_income", "tax_report_depreciation") %in%
                    res0$ledger$rows$key))
})

test_that("10.10 Nr. 3: Standardmodell, Endwert mit Kalkulationszins i(1 - s)", {
  restore <- register_tax_test_module()
  withr::defer(restore())
  s <- 0.3
  i <- 0.05
  res <- vofi_run(vofi_build(tax_test_scenario(rate = s, i = i)))
  q <- 1 + i * (1 - s)
  afa <- 100000 / 3
  rent <- c(0, 30000, 40000, 50000)
  tax_op <- s * (rent - c(0, rep(afa, 3)))
  net <- c(60000, 0, 0, 0) + c(-100000, 0, 0, 0) + rent - tax_op
  expect_equal(res$kpis$terminal_value, sum(net * q^(3:0)), tolerance = 1e-10)
  # Unterlassungsalternative mit demselben Modul: EK zu i(1 - s)
  expect_equal(res$opportunity$EW, 60000 * q^3, tolerance = 1e-10)
  expect_true(all(res$checks$ok))
  # Erstattung bei Verlust (sofortiger Verlustausgleich): Zeile tax positiv
  expect_gt(res$ledger$values$tax[1L, 2L], 0)
})

test_that("10.10 Nr. 4: AfA-Summe über die Nutzungsdauer = Bemessungsgrundlage", {
  restore <- register_tax_test_module()
  withr::defer(restore())
  res <- vofi_run(vofi_build(tax_test_scenario(rate = 0.3, years = 2,
                                               rent = c(0, 30000, 40000, 50000))))
  afa <- res$ledger$values$tax_report_depreciation[1L, ]
  expect_equal(sum(afa), 100000)
  expect_equal(afa, c(0, 50000, 50000, 0))
  lbl_row <- res$ledger$rows$label[res$ledger$rows$key == "tax_report_depreciation"]
  expect_identical(lbl_row, "depreciation")
  rows <- res$ledger$rows[startsWith(res$ledger$rows$key, "tax_report_"), , drop = FALSE]
  expect_true(all(rows$section == "memo" & rows$category == "tax_report" & !rows$cash))
})

test_that("Veranlagungs-Lag: Steuer in t + 1, am Horizont offen in tax_liability (10.5)", {
  restore <- register_tax_test_module()
  withr::defer(restore())
  r0 <- vofi_run(vofi_build(tax_test_scenario(rate = 0.3, lag = 0L)))
  r1 <- vofi_run(vofi_build(tax_test_scenario(rate = 0.3, lag = 1L)))
  e1 <- r1$ledger$values$tax_report_taxable_income[1L, ]
  expect_equal(r1$ledger$values$tax[1L, ], -0.3 * c(0, e1[1:3]))
  expect_equal(r1$ledger$values$tax_liability[1L, 4L], 0.3 * e1[4L])
  expect_true(all(r1$checks$ok))
  expect_false(isTRUE(all.equal(r0$kpis$terminal_value, r1$kpis$terminal_value)))
})

test_that("10.10 Nr. 6: Ergebnis invariant gegen die Chunk-Größe (Lauf i im Batch = einzeln)", {
  restore <- register_tax_test_module()
  withr::defer(restore())
  model <- vofi_build(tax_test_scenario(rate = 0.3))
  f <- c(0.8, 1, 1.3)
  batch <- eng_run_draws(model, draws = tax_factor_draws(model$grid, f), store = "full")
  for (i in seq_along(f)) {
    one <- eng_run_draws(model, draws = tax_factor_draws(model$grid, f[i]), store = "full")
    expect_identical(batch$kpis[i, , drop = FALSE], `rownames<-`(one$kpis, i))
    expect_identical(batch$ledger$values$tax[i, , drop = FALSE], one$ledger$values$tax)
    expect_identical(batch$opp$EW[i], one$opp$EW)
  }
})
