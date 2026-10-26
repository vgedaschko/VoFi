# Tests für R/validate-structure.R (WS-B; Spec 00 Abschnitte 4.2-4.4, 8.9, 10.2, 13.5).
# Phase-0-Minimalfassung: jede Meldung der Phase 0 wird mindestens einmal ausgelöst.

codes_of <- function(x) vofi_validate(x)$code

test_that("Struktur: oberste Ebene, schema_version, Pflichtfelder, Codes, Stichtag", {
  sc <- example_scenario("skeleton")
  expect_identical(nrow(vofi_validate(sc)), 0L)
  bad <- sc
  bad$horizon_from <- "completion"
  bad$schema_version <- 2L
  bad$meta$scenario_id <- "Ger\u00fcst"
  bad$meta$title <- NULL
  bad$project$perspective <- "wu_kommunl"
  bad$project$valuation_date <- as.Date("2027-01-15")
  bad$project$horizon_years <- 0L
  v <- vofi_validate(bad)
  expect_s3_class(v, "vofi_validation")
  expect_true(all(c("validation.unknown_key", "validation.schema_version",
                    "validation.id_invalid", "validation.required", "validation.enum",
                    "validation.valuation_first", "validation.horizon") %in% v$code))
  expect_match(v$message[v$code == "validation.unknown_key"], "horizon_from", fixed = TRUE)
  expect_match(v$message[v$code == "validation.enum"][1], "wu_kommunal", fixed = TRUE)
  expect_identical(nrow(vofi_validate(bad, min_severity = "error")), nrow(v))
  expect_error(vofi_validate(list()), class = "vofi_error_input")
})

test_that("Komponenten: ids, Typen, Parameter", {
  sc <- example_scenario("skeleton")
  sc$components$bank <- list(type = "custom_series", values = c(1, 2, 3, 4))
  sc$components$x <- list(type = "recurring", category = "rent", ammount_eur = 1)
  sc$components$y <- list(type = "custom_series", values = c(1, 2, 3, 4), section = "stock")
  sc$financing$z2 <- list(type = "custom_series", values = c(1, 2, 3, 4))
  v <- vofi_validate(vofi_scenario(sc))
  expect_true(all(c("validation.id_duplicate", "validation.param_unknown",
                    "validation.param_required", "validation.type_unknown",
                    "validation.enum") %in% v$code))
  expect_match(v$message[v$code == "validation.param_unknown"][1], "amount_eur", fixed = TRUE)
})

test_that("Ketten (8.9), Steuermodul (10.2), Kennzahlen", {
  sc <- example_scenario("skeleton")
  sc$accounts$surplus_order <- c("od_repay", "od_draw", "dep_invest")
  sc$accounts$deficit_order <- c("dep_withdraw", "equity_call", "od_draw")
  sc$tax$module <- "flatt"
  sc$analysis$kpis <- c("terminal_value", "endwert")
  v <- vofi_validate(sc)
  expect_true(all(c("validation.chain_role", "validation.chain_order",
                    "validation.tax_module_unknown", "validation.kpi_unknown") %in% v$code))
  sc2 <- example_scenario("skeleton")
  sc2$accounts$deficit_order <- c("dep_withdraw", "od_drw", "equity_call")
  expect_true("validation.chain_action_unknown" %in% codes_of(sc2))
  sc3 <- example_scenario("skeleton")
  sc3$accounts$surplus_order <- character(0)
  expect_true("validation.required" %in% codes_of(vofi_resolve(sc3)))
  local_registry_state <- reg_state$types
  withr::defer(reg_state$types <- local_registry_state)
  tx <- reg_get("tax", "none")
  tx$name <- "nur_wu"
  tx$perspectives <- "wu_kommunal"
  reg_add(tx, source = "vofi")
  sc4 <- example_scenario("skeleton")
  sc4$tax$module <- "nur_wu"
  expect_true("validation.tax_module_blocked" %in% codes_of(sc4))
})

test_that("Unbekannte Felder der Domänenblöcke: Fehler bzw. Warnung mit Vorschlag", {
  sc <- example_scenario("skeleton")
  sc$accounts$deposit_rate <- 0.02
  v <- vofi_validate(sc)
  hit <- v[v$code == "validation.unknown_field", , drop = FALSE]
  expect_identical(unique(hit$severity), "error")
  expect_identical(unique(hit$path), "accounts.deposit_rate")
  expect_match(hit$message[1], "deposit_rate_pa", fixed = TRUE)
  expect_error(vofi_build(sc), class = "vofi_error_validation")
  sc2 <- example_scenario("skeleton")
  sc2$project$horizon_from <- "completion"
  expect_true("validation.unknown_field" %in% codes_of(sc2))
  sc3 <- example_scenario("skeleton")
  sc3$building <- list(n_units = 4L, unbekannt = 1)
  v3 <- vofi_validate(sc3)
  expect_identical(v3$severity[v3$code == "validation.unknown_field"], "warning")
  sc4 <- example_scenario("skeleton")
  sc4$project$municipality <- list(mietpreisbremse_area = TRUE)
  sc4$meta$version <- "2026-10-25a"
  sc4$analysis$thresholds <- list(dscr = 1.2)
  expect_false("validation.unknown_field" %in% codes_of(sc4))
})

test_that("vofi_build(): unbekannte Wurzelschlüssel von Szenario und Overrides (4.2)", {
  sc <- example_scenario("skeleton")
  x <- unclass(sc)
  x$acounts <- x$accounts
  x$accounts <- NULL
  bad <- vofi_scenario(x[setdiff(names(x), character(0))])
  e <- expect_error(vofi_build(bad), class = "vofi_error_validation")
  expect_true("validation.unknown_key" %in% e$data$report$code)
  e2 <- expect_error(vofi_build(sc, overrides = list(acounts = list(deposit_rate_pa = 0.01))),
                     class = "vofi_error_validation")
  expect_identical(e2$data$report$path[e2$data$report$code == "validation.unknown_key"],
                   "overrides.acounts")
  expect_identical(nrow(as.data.frame(val_overrides_structure(list(accounts = list())))), 0L)
})
