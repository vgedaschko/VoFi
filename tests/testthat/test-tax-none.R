# Tests für R/tax-none.R (WS-D; Spec 00 Abschnitte 10.1, 10.6, 10.10 Nr. 1).

test_that("tax_none ist registriert: uses_inputs = FALSE, Klasse tax_none", {
  def <- reg_get("tax", "none")
  expect_false(isTRUE(def$uses_inputs))
  expect_identical(def$params, list())
  m <- def$constructor(list(), list())
  expect_s3_class(m, c("tax_none", "vofi_tax_module"), exact = TRUE)
  model <- wsd_skeleton()
  expect_s3_class(model$tax, "tax_none")
  expect_false(isTRUE(model$tax$uses_inputs))
})

test_that("Methoden von tax_none: Zahlung 0, leerer Zustand und Bericht (10.6)", {
  m <- new_tax_module("none")
  st <- tax_init(m, list(), list(), list(), 3L)
  expect_identical(st, list())
  r <- tax_step(m, 1L, list(), list(exo_soll = numeric(3), exo_fees = numeric(3),
                                    endo_soll = numeric(3), endo_haben = numeric(3),
                                    endo_wht = numeric(3)), st, list())
  expect_identical(r$payment, numeric(3))
  expect_identical(r$state, st)
  expect_identical(r$report, list())
  fin <- tax_finalize(m, 2L, st, list(residual_value = numeric(3), exo_T = list()), list())
  expect_identical(fin$payment_T, numeric(3))
  expect_identical(fin$report, list())
})

test_that("10.10 Nr. 1: tax_none ist bitgleich zum Lauf ohne Hook-Aufruf", {
  model <- wsd_skeleton()
  no_hook <- model
  no_hook$tax <- NULL
  a <- wsd_parts(model)$core
  b <- wsd_parts(no_hook)$core
  expect_identical(a$ledger$values, b$ledger$values)
  expect_identical(a$ledger$rows, b$ledger$rows)
  expect_identical(a$stocks, b$stocks)
  expect_identical(a$terminal_ex_rv, b$terminal_ex_rv)
  expect_identical(a$flags, b$flags)
  ra <- eng_run_draws(model)
  rb <- eng_run_draws(no_hook)
  expect_identical(ra$kpis, rb$kpis)
  expect_identical(ra$opp$EW, rb$opp$EW)
})

test_that("Der Hook läuft in jeder Periode inkl. t0 (10.1 Nr. 1, R-21)", {
  old <- reg_state$types
  withr::defer(reg_state$types <- old)
  seen <- new.env()
  seen$t <- integer(0)
  vofi_tax_module_simple("zaehler", function(inputs, params) {
    seen$t <- c(seen$t, inputs$t)
    0
  })
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  sc$tax <- list(module = "zaehler")
  model <- vofi_build(sc)
  seen$t <- integer(0)
  core <- wsd_parts(model)$core
  expect_identical(seen$t, 0:model$grid$T)
  expect_equal(core$stocks$BS, wsd_parts(wsd_skeleton())$core$stocks$BS)
})
