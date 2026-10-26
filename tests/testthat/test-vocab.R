# Tests für R/vocab.R und inst/vocab/*.yaml (Integrator; Spec 00 Abschnitte 2.11, 7.5, 7.6,
# 10.8, 12.4).

test_that("alle Vokabulare sind geladen", {
  expect_setequal(names(vocab_state$data),
                  c("sections", "categories", "tax_categories", "asset_types", "measure_types",
                    "units", "na_reasons", "conditions", "row_extra_fields", "enums"))
  expect_error(vocab("gibtsnicht"), class = "vofi_error_contract")
})

test_that("Abschnitte nach 7.5", {
  s <- vocab("sections")
  expect_identical(s$code, c("project", "grants", "equity", "loans", "overdraft", "deposit",
                             "tax", "check", "stocks", "memo"))
  expect_identical(s$order, c(100, 200, 300, 400, 500, 600, 700, 800, 900, 950))
  expect_identical(s$balance, c(rep(TRUE, 7), FALSE, FALSE, FALSE))
  expect_identical(s$code[s$flow], c("project", "grants", "equity", "memo"))
  expect_identical(vocab_section_order(c("tax", "memo")), c(700, 950))
})

test_that("Kategorien nach 7.6: Regeln konsistent", {
  cats <- vocab("categories")
  expect_true(all(cats$section %in% vocab_codes("sections")))
  expect_true(all(cats$sign %in% c("pos", "neg", "any")))
  tc <- vocab_codes("tax_categories")
  expect_true(all(cats$tax_category %in% tc))
  allowed <- unlist(cats$tax_allowed)
  expect_true(all(allowed[allowed != "*"] %in% tc))
  expect_true(all(unlist(cats$tax_excluded) %in% tc))
  expect_true(all(unlist(c(cats$ids, cats$ids_optional)) %in% c("asset", "measure")))
  expect_true(all(cats$unit %in% vocab("units")$code[vocab("units")$row]))
  expect_true(all(cats$kind %in% c("flow", "stock", "memo", "check")))
  expect_false(any(cats$cash[cats$section == "memo"]))
  expect_false(any(cats$flow_ok[cats$engine]))
  expect_true(all(cats$engine[cats$section %in% c("loans", "overdraft", "deposit", "tax",
                                                  "check", "stocks")]))
  expect_identical(nrow(cats[duplicated(cats[, c("section", "category")]), ]), 0L)
  expect_identical(vocab_codes("categories", "loans"),
                   c("draw", "repay", "repay_balloon", "prepay", "interest", "fees",
                     "repayment_grant", "disagio", "assumed"))
  expect_identical(vocab_codes("categories:overdraft"), c("draw", "repay", "interest"))
  expect_error(vocab_codes("categories", "keiner"), class = "vofi_error_contract")
  capex <- vocab_category("project", "capex")
  expect_identical(capex$ids, c("asset", "measure"))
  expect_true(capex$cash)
  expect_null(vocab_category("project", "draw"))
  expect_identical(vocab_tax_allowed("project", "capex"),
                   c("capex_depreciable", "capex_expensable", "capex_land"))
  custom <- vocab_tax_allowed("project", "custom")
  expect_identical(custom[1], "not_applicable")
  expect_false(any(c("principal", "tax_credit", "tax_payment") %in% custom))
  expect_true("income_rental" %in% custom)
  expect_identical(vocab_tax_allowed("project", "nix"), character(0))
  noi <- cats$category[cats$noi]
  expect_true(all(c("rent", "rent_loss", "modernization_levy", "operating_cost",
                    "other_cost", "operating_subsidy") %in% noi))
  burden <- cats$category[cats$burden & cats$section == "loans"]
  expect_identical(burden, c("repay", "interest", "fees"))
})

test_that("Steuerkategorien, NA-Codes, Register-Codes", {
  expect_identical(length(vocab_codes("tax_categories")), 22L)
  expect_true(all(c("not_applicable", "principal", "tax_credit") %in%
                    vocab_codes("tax_categories")))
  expect_identical(vocab_codes("na_reasons"), c(
    "no_equity", "multiple_equity_flows", "equity_lost", "irr_ambiguous", "irr_out_of_range",
    "no_payback", "no_debt_service", "no_market_value", "no_household_income", "no_tenant_data",
    "no_living_area", "no_inflation_path", "no_operation_period", "no_construction_period",
    "no_solution", "run_stopped", "not_applicable_perspective", "not_computed",
    "no_existing_value", "no_co2_reduction"))
  expect_identical(vocab_codes("asset_types"),
                   c("gebaeude_wohnen", "gebaeude_nichtwohnen", "grund_boden", "aussenanlage",
                     "bewegliches_wg", "pv_anlage", "ladeinfrastruktur"))
  expect_true(all(c("daemmung_fassade", "heizung_tausch") %in% vocab_codes("measure_types")))
  ef <- vocab("row_extra_fields")
  expect_setequal(names(ef), c("tax_period", "spread_years", "use_share_rented", "activity_type",
                               "stochastic_source", "allocable_to_tenant", "realization",
                               "approval_date", "rv_basis"))
  expect_identical(ef$rv_basis$categories, "residual_path")
})

test_that("Enums: Form {codes, aliases, default}", {
  en <- vocab("enums")
  for (nm in names(en)) {
    e <- en[[nm]]
    expect_true(length(e$codes) > 0L, info = nm)
    expect_false(anyDuplicated(e$codes) > 0L, info = nm)
    if (!is.null(e$default)) expect_true(e$default %in% e$codes, info = nm)
    expect_true(all(unname(e$aliases) %in% e$codes), info = nm)
    expect_false(any(names(e$aliases) %in% e$codes), info = nm)
  }
  expect_identical(vocab_codes("perspective"),
                   c("wu_kommunal", "wu_genossenschaft", "wu_privat", "kleinvermieter",
                     "selbstnutzer"))
  expect_identical(vocab_codes("enums", "reform"), c("mietrecht_ii", "stufe_2045", "unreleased"))
  expect_identical(vocab_codes("vocab:refi_rule"), c("keep_term", "keep_tilg_rate", "keep_payment"))
  expect_identical(vocab("tax_regime")$from_perspective$wu_genossenschaft, "wu_eg_befreit")
  expect_true(all(unlist(vocab("tax_regime")$from_perspective) %in% vocab_codes("tax_regime")))
  expect_identical(vocab("project_type")$existing_building,
                   c("sanierung_eh", "sanierung_einzelmassnahmen", "sanierung_stufenweise",
                     "heizungstausch"))
  expect_identical(vocab_codes("residual_method"),
                   c("zero", "market_growth", "income_value", "component", "asset_value",
                     "multiplier", "exit_yield", "user_value"))
})

test_that("vocab_check und vocab_resolve: Aliase und unbekannte Codes", {
  expect_identical(vocab_check("perspective", c("wu_privat", "selbstnutzer")), character(0))
  expect_warning(res <- vocab_check("repayment_grant_effect", "reduce_annuity", "x"),
                 class = "vofi_warning_input")
  expect_identical(res, character(0))
  bad <- vocab_check("perspective", "wu_privatt", "project.perspective")
  expect_length(bad, 1L)
  expect_match(bad, "wu_privat'", fixed = TRUE)
  w <- testthat::capture_warnings(
    r <- vocab_resolve("residual_method", c("none", "zero", "sachwert_linear"))
  )
  expect_length(w, 2L)
  expect_identical(r, c("zero", "zero", "asset_value"))
  expect_error(vocab_resolve("residual_method", "gibtsnicht"), class = "vofi_error_input")
  expect_identical(vocab_check("quantity_per", c("m2_component:roof", "total")), character(0))
  expect_length(vocab_check("quantity_per", "m2_component:"), 1L)
  expect_true(vocab_has("units", "EUR"))
  expect_false(vocab_has("units", "furlong"))
  expect_length(vocab_check("perspective", NA), 1L)
})

test_that("jeder Vokabularcode hat ein deutsches Label, keine verwaisten Labels", {
  expected <- c(
    paste0("vocab.sections.", vocab_codes("sections")),
    paste0("vocab.categories.", vocab("categories")$section, ".", vocab("categories")$category),
    paste0("vocab.tax_categories.", vocab_codes("tax_categories")),
    paste0("vocab.asset_types.", vocab_codes("asset_types")),
    paste0("vocab.measure_types.", vocab_codes("measure_types")),
    paste0("vocab.units.", vocab_codes("units")),
    paste0("vocab.na_reasons.", vocab_codes("na_reasons")),
    paste0("vocab.conditions.", vocab_codes("conditions")),
    paste0("vocab.row_extra_fields.", names(vocab("row_extra_fields"))),
    unlist(lapply(names(vocab("enums")), function(nm) {
      paste0("vocab.enums.", nm, ".", vocab("enums")[[nm]]$codes)
    }))
  )
  missing_keys <- expected[!vapply(expected, lbl_has, logical(1))]
  expect_identical(missing_keys, character(0))
  orphans <- setdiff(lbl_keys("vocab"), expected)
  expect_identical(orphans, character(0))
})

test_that("Vokabulardateien sind ASCII (nur Codes und Regeln)", {
  dir <- system.file("vocab", package = "vofi")
  for (f in list.files(dir, full.names = TRUE)) {
    txt <- readLines(f, encoding = "UTF-8", warn = FALSE)
    expect_false(any(grepl("[^\\x01-\\x7F]", txt, perl = TRUE)), info = basename(f))
  }
})
