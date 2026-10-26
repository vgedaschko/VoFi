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
  na_codes <- c("no_equity", "multiple_equity_flows", "equity_lost", "irr_ambiguous",
                "irr_out_of_range", "no_payback", "no_debt_service", "no_market_value",
                "no_household_income", "no_tenant_data", "no_living_area", "no_inflation_path",
                "no_operation_period", "no_construction_period", "no_solution", "run_stopped",
                "not_applicable_perspective", "not_computed", "no_existing_value",
                "no_co2_reduction", "no_liquidity_limit")
  expect_identical(vocab_codes("na_reasons"), na_codes)
  expect_identical(vocab_codes("asset_types"),
                   c("gebaeude_wohnen", "gebaeude_nichtwohnen", "grund_boden", "aussenanlage",
                     "bewegliches_wg", "pv_anlage", "ladeinfrastruktur"))
  mt <- vocab_codes("measure_types")
  expect_length(mt, 37L)
  expect_true(all(c("daemmung_fassade", "heizung_waermepumpe_luft", "daemmung_dach_steil",
                    "aussentueren", "erwerb_objekt", "baunebenkosten", "sonstige") %in% mt))
  # Sammelcodes gibt es nicht (2.11, N-01)
  expect_false(any(c("heizung_tausch", "daemmung_dach", "daemmung_ogd", "aussentuer",
                     "sonnenschutz") %in% mt))
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
  # Enums nach 2.11 (R-89, R-91, R-93, R-94, R-97)
  expect_identical(vocab_codes("growth_index"), c("calendar_year", "period_end"))
  expect_identical(vocab("growth_index")$default, "calendar_year")
  expect_identical(vocab_codes("overlay_apply"), c("replace", "multiply", "add"))
  expect_identical(vocab_codes("mc_preset"), c("preview", "standard", "report", "custom"))
  expect_identical(vocab("mc_preset")$default, "standard")
  expect_identical(vocab_codes("levy_procedure"), c("auto", "bgb_559", "bgb_559c", "bgb_559e"))
  expect_identical(vocab_codes("bgb_procedure"),
                   c("bgb_557a", "bgb_557b", "bgb_558", "bgb_559", "bgb_559b", "bgb_559c",
                     "bgb_559e"))
  expect_true(all(c("m2_net_floor_area", "parking") %in% vocab_codes("quantity_per")))
  expect_true("value" %in% vocab_codes("rule_returns"))
  expect_identical(vocab_codes("residual_method"),
                   c("zero", "market_growth", "income_value", "component", "asset_value",
                     "multiplier", "exit_yield", "user_value"))
})

test_that("Enums aus Spec 01 Teil A 8.1, Teil B 8 und den Feldtabellen (P0-02)", {
  soll <- list(
    # Teil A 8.1
    building_type = c("EFH", "ZFH", "DHH", "RH", "MFH", "ETW"),
    component_area = c("roof", "pitched_roof", "flat_roof", "top_ceiling", "facade", "windows",
                       "doors", "basement_ceiling", "floor_slab", "partition_unheated"),
    payment_profile = c("linear", "s_curve", "front", "back"),
    construction_delay_mode = c("none", "last", "stretch"),
    maintenance_basis = c("auto", "rate", "iibv", "share_of_cost", "none"),
    overdue_policy = c("first_period", "valuation", "skip"),
    remaining_life_method = c("anlage2", "linear", "manual"),
    income_basis = c("forward", "trailing"),
    modernization_element = c("roof_insulation", "windows_doors", "pipes", "heating",
                              "facade_insulation", "bathrooms", "interior", "floor_plan"),
    federal_state = c("BW", "BY", "BE", "BB", "HB", "HH", "HE", "MV", "NI", "NW", "RP", "SL",
                      "SN", "ST", "SH", "TH"),
    # Teil A, weitere Feldtabellen
    kg700_basis = c("kg300_400", "kg200_600"), contingency_basis = c("kg200_700", "kg200_600"),
    effect_start = c("completion", "next_year"),
    path_pre_operation = c("auto", "cost", "method", "zero"),
    income_value_variant = c("general", "simplified"), bwk_source = c("model", "ledger"),
    multiplier_basis = c("net_cold_rent_incl_levy", "net_cold_rent"),
    life_basis = c("gnd", "component"), include_existing = c("auto", "true", "false"),
    # Teil B 8
    rent_regime = c("paragraph_558", "staffel", "index", "bound_social", "cooperative_fee",
                    "owner_occupied"),
    increase_policy = c("auto", "fixed_growth", "max", "interval", "capped"),
    growth_applies_to = c("total", "base"), levy_mode = c("auto", "none"),
    maintenance_method = c("auto", "linear_wear", "fixed_share", "ohnehin", "none"),
    hp_exception = c("auto", "none", "building_after_1996", "flow_temperature"),
    third_party_allocation = c("full", "proportional"),
    s559e_order = c("flat_before_funds", "funds_before_flat"),
    s559f_order = c("halve_then_funds", "funds_then_halve"),
    voluntary_cap_mode = c("fixed", "warm_rent_neutral"), vacancy_opex_scope = c("cold", "warm"),
    perspective_tax = c("deductible", "nondeductible"),
    carrier_class = c("gas", "oil", "lpg", "coal", "power", "power_hp", "district_heating",
                      "biomass", "other"),
    heating_system_type = c("central", "floor", "single_room"),
    consumption_basis = c("measured", "demand"), price_includes = c("commodity", "all"),
    price_basis = c("net", "gross"), feed_in_mode = c("partial", "full"),
    pv_tax_exempt = c("auto", "yes", "no"),
    applicant = c("privatperson", "privatperson_vermieter", "weg", "unternehmen",
                  "kommunales_unternehmen", "genossenschaft", "gemeinnuetzig", "koerperschaft",
                  "contractor"),
    payout_event = c("completion_proof", "commitment"),
    grant_counts_as = c("zuschuss_559a_abs1", "none"),
    loan_counts_as = c("zinsverbilligung_559a_abs2", "none"),
    repayment_grant_class = c("ee", "nh"), bonus_mode = c("excess_over_threshold", "whole_amount"),
    cap_period = c("total", "calendar_year"), rent_phase = c("p558", "staffel", "index", "bound"),
    efficiency_standard = c("eh40", "eh55", "eh70", "eh85", "eh_denkmal", "none"),
    energy_class = c("A+", "A", "B", "C", "D", "E", "F", "G", "H"),
    # Teil C
    legal_status = c("in_force", "enacted", "adopted_pending", "pending", "administrative",
                     "derived", "market"),
    generate_method = "cautious"
  )
  for (nm in names(soll)) expect_identical(vocab_codes(nm), soll[[nm]], info = nm)
  defaults <- list(payment_profile = "linear", construction_delay_mode = "none",
                   overdue_policy = "first_period", heating_system_type = "central",
                   increase_policy = "auto", levy_mode = "auto", voluntary_cap_mode = "fixed",
                   efficiency_standard = "none", payout_event = "completion_proof")
  for (nm in names(defaults)) expect_identical(vocab(nm)$default, defaults[[nm]], info = nm)
  expect_null(vocab("carrier_class")$default)
  # Aliase modernization_kind (Teil B 1.4)
  expect_identical(vocab("modernization_kind")$aliases,
                   c(erhaltung = "none", instandsetzung = "none", energetisch = "bgb_555b_1",
                     heizung = "bgb_555b_1a"))
  expect_warning(mk <- vocab_resolve("modernization_kind", c("heizung", "bgb_555b_4")),
                 class = "vofi_warning_input")
  expect_identical(mk, c("bgb_555b_1a", "bgb_555b_4"))
  expect_identical(vocab_check("carrier_class", "coal"), character(0))
  expect_identical(lbl("vocab.enums.carrier_class.coal"), "Kohle")
  expect_identical(lbl("vocab.enums.energy_class.A+"), "Effizienzklasse A+")
  expect_identical(lbl("vocab.enums.pv_tax_exempt.yes"), "steuerbefreit")
  expect_identical(lbl("vocab.enums.include_existing.false"), "nicht einbeziehen")
})

test_that("vocab_check und vocab_resolve: Aliase und unbekannte Codes", {
  # levy_procedure: Alias auch für die als Zahl gelesene Eingabe 559 (2.11)
  expect_warning(r559 <- vocab_resolve("levy_procedure", 559), class = "vofi_warning_input")
  expect_identical(r559, "bgb_559")
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
