# Tests für R/validate-plausibility.R (WS-B; Feldtabellen und Validierungsregeln Spec 01
# Teil A 1-6, Teil B 1-4, Teil C 1.11; Spec 00 Abschnitte 4.9, 8.2, 8.6, 10.9, 12.3).

test_that("Prüffälle der Ebene 4 (Tabelle)", {
  wsb_registry()
  wsb_expect_cases(wsb_cases_plaus())
})

test_that("Komponentenszenarien ohne Domänenblöcke bleiben ohne Plausibilitätsbefund", {
  sk <- example_scenario("skeleton")
  expect_identical(sk$project$project_type, "neubau")
  expect_identical(nrow(wsb_validate(sk)), 0L)
  vc <- val_context(vofi_resolve(sk))
  expect_false(vc$domain)
  expect_true(val_context(vofi_resolve(wsb_with("domain")))$domain)
})

test_that("AC5: Liquiditätsrestriktion nicht prüfbar bei unendlichem Limit (Teil A 5.7)", {
  sc <- function(threshold = NULL) {
    wsb_with("skeleton", function(x) {
      x$project$perspective <- "wu_kommunal"
      x$analysis$restrictions <- c("dscr", "liquidity")
      x$accounts$overdraft_flag_threshold_eur <- threshold
      x
    })
  }
  v <- vofi_validate(sc())
  hit <- v[v$code == "validation.accounts.liquidity_unchecked", , drop = FALSE]
  expect_identical(hit$severity, "warning")
  expect_identical(hit$path, "accounts.overdraft_limit_eur")
  expect_false("validation.accounts.liquidity_unchecked" %in% vofi_validate(sc(250000))$code)
})

test_that("Grundsteuer: Hinweis bei Vermietung, Warnung beim Selbstnutzer (Teil B 1.6, O-7a)", {
  rented <- wsb_validate(wsb_with("domain", function(x) {
    x$building$property_tax <- NULL
    x
  }), variant = "base")
  expect_identical(rented$severity[rented$code == "validation.building.property_tax_missing"],
                   "info")
  own <- wsb_validate(wsb_with("domain", function(x) {
    x$project$perspective <- "selbstnutzer"
    x$building$property_tax <- NULL
    x$unit_groups$a$owner_occupied <- TRUE
    x
  }), variant = "base")
  expect_identical(own$severity[own$code == "validation.building.property_tax_missing"],
                   "warning")
  e <- wsb_validate(wsb_with("domain", function(x) {
    x$building$property_tax <- list(assessment_amount_eur = 100)
    x
  }), variant = "base")
  expect_identical(e$code, "validation.building.property_tax_multiplier")
})

test_that("Finanzierung: L11 (Tilgungssatz und Laufzeit) und Rate negativer Tilgung", {
  v <- wsb_validate(wsb_with("skeleton", function(x) {
    x$financing$l11 <- list(type = "annuity_loan", amount_eur = 100000, rate_pa = 0.03,
                            initial_repayment_pa = 0.02, term_years = 10,
                            payments_per_year = 12L)
    x
  }))
  b <- v[v$code == "validation.financing.balloon_at_maturity", , drop = FALSE]
  expect_identical(b$severity, "info")
  expect_identical(b$path, "financing.l11.initial_repayment_pa")
  ok <- wsb_validate(wsb_with("skeleton", function(x) {
    x$financing$a <- list(type = "annuity_loan", amount_eur = 100000, rate_pa = 0.03,
                          installment_eur = 500, payments_per_year = 12L)
    x
  }))
  expect_false("validation.financing.negative_amortization" %in% ok$code)
  neg <- wsb_validate(wsb_with("skeleton", function(x) {
    x$financing$a <- list(type = "annuity_loan", amount_eur = 100000, rate_pa = 0.03,
                          installment_eur = 250, payments_per_year = 12L)
    x
  }))
  expect_true("validation.financing.negative_amortization" %in% neg$code)
})

test_that("Erwerb: A6 und X2 (Teil A 4.8, 4.9)", {
  a6 <- wsb_validate(wsb_with("domain", function(x) {
    x$project$project_type <- "erwerb_sanierung"
    x$project$federal_state <- NULL
    x$building$existing_value_eur <- NULL
    x$measures$kauf <- list(measure_type = "erwerb_grundstueck", date = "2027-01-01",
                            purchase_price_eur = 300000)
    x
  }), variant = "base")
  fs <- a6[a6$code == "validation.acquisition.federal_state_missing", , drop = FALSE]
  expect_identical(fs$path, "project.federal_state")
  expect_match(fs$message, "kauf", fixed = TRUE)
  small <- wsb_validate(wsb_with("domain", function(x) {
    x$project$project_type <- "erwerb_sanierung"
    x$project$federal_state <- NULL
    x$building$existing_value_eur <- NULL
    x$measures$kauf <- list(measure_type = "erwerb_grundstueck", date = "2027-01-01",
                            purchase_price_eur = 2400)
    x
  }), variant = "base")
  expect_false("validation.acquisition.federal_state_missing" %in% small$code)
  x2 <- wsb_validate(wsb_with("domain", function(x) {
    x$project$project_type <- "erwerb_sanierung"
    x
  }), variant = "base")
  expect_identical(x2$code, "validation.building.existing_value_with_purchase")
})

test_that("Instandhaltung: Kennwert der expliziten Erneuerungen (4.11.4)", {
  v <- wsb_validate(wsb_with("domain", function(x) {
    x$building$maintenance <- list(enabled = TRUE, basis = "rate", rate_eur_m2_pa = 10,
                                   excludes_explicit_replacements = TRUE)
    x$building$elements <- list(dach = list(measure_type = "daemmung_dach_steil",
                                            installed_year = 2000L,
                                            replacement_cost_eur = 16000))
    x$measures$huelle$classification <- "herstellung"     # nicht Erhaltung (Katalog: erhaltung)
    x$measures$huelle$ohnehin_share <- 0
    x
  }), variant = "base")
  hit <- v[v$code == "validation.maintenance.replacements_excluded", , drop = FALSE]
  expect_identical(hit$severity, "info")
  expect_match(hit$message, "entsprechen 1 EUR", fixed = TRUE)
  expect_false("validation.maintenance.double_count" %in% v$code)
})

test_that("Bibliothek: Gültigkeit je Instrument zum Antragsdatum", {
  spec <- wsb_spec(function(x) wsb_funding(x, f = list(application_date = "2026-08-01")),
                   function(s) {
                     wsb_spec_with_library(s, wsb_rows("funding.f.instrument_type",
                                                       entry = "funding/kfw_test",
                                                       valid_from = "2026-07-21",
                                                       as_of = "2026-10-25"))
                   })
  v0 <- vofi_validate(spec)
  expect_false("funding.f.instrument_type" %in% v0$path[v0$code == "validation.library.outdated"])
  late <- wsb_spec(function(x) wsb_funding(x, f = list(application_date = "2026-01-01")),
                   function(s) {
                     wsb_spec_with_library(s, wsb_rows("funding.f.instrument_type",
                                                       entry = "funding/kfw_test",
                                                       valid_from = "2026-07-21",
                                                       as_of = "2026-10-25"))
                   })
  v <- vofi_validate(late)
  hit <- v$path[v$code == "validation.library.outdated"]
  expect_identical(hit[startsWith(hit, "funding.")], "funding.f.instrument_type")
})

test_that("Förderung: Berechtigung mit Oberbegriff privatperson und Bestätigung", {
  v <- wsb_validate(wsb_with("domain", function(x) {
    wsb_funding(x,
                f1 = list(applicant = "privatperson_vermieter",
                          eligibility = list(applicants = "privatperson")),
                f2 = list(eligibility = list(project_types = "neubau"),
                          eligibility_override = TRUE))
  }), variant = "base")
  expect_false("validation.funding.not_eligible" %in% v$code)
  expect_identical(v$code, "validation.funding.eligibility_override")
})

test_that("Prüffälle der Review-Korrekturen (Tabelle, ohne fremde Fehler)", {
  wsb_registry()
  wsb_expect_cases(wsb_cases_review())
})

test_that("Positivfall: vollständige Domänenblöcke und Defaults ohne Fehler (Review m5)", {
  wsb_registry()
  v <- wsb_validate(vofi_scenario(wsb_full()))
  expect_identical(sum(v$severity == "error"), 0L, info = wsb_errors(v))
  # Elemente der Sammlungen werden nach ihrem Katalogeintrag geprüft (B1)
  expect_false(any(grepl("^(building\\.elements|energy\\.(carriers|stages))\\.", v$path) &
                     v$severity == "error"))
  # after vor der späteren Stufe ersatz: zeitlich geordnet (M1)
  expect_false("validation.energy.state_order" %in% v$code)
  # Pflichtsensitivitäten des Profils (B3), band_probs (B2)
  expect_false(any(startsWith(v$path, "analysis.mandatory_sensitivities")))
  expect_false(any(startsWith(v$path, "stochastic.settings")))
})

test_that("B4/R-115: Gerüst mit den Defaults ohne building bleibt ohne Befund (Teil A 6.1)", {
  # Methode des Profils (income_value) und zero: ohne Befund (Teil A 6.1, R-115; der Expander
  # residual läuft ohne building mit der Profilmethode nicht, Teil A 3.1)
  for (method in c("income_value", "zero")) {
    v <- wsb_validate(vofi_scenario(wsb_skeleton_defaults(method)))
    expect_identical(nrow(v), 0L, info = paste(method, paste(v$code, collapse = ",")))
  }
  # ausdrücklich gewählte Methode ohne building: asset_value unzulässig, market_growth nur mit
  # Ausgangswert (Teil A 6.2 Nr. 5, E); je genau ein Fehler mit eigenem Schlüssel
  for (m in list(c("asset_value", "validation.residual.method_needs_building"),
                 c("market_growth", "validation.residual.base_value_missing"))) {
    v <- wsb_validate(vofi_scenario(wsb_skeleton_defaults(m[1L])))
    expect_identical(v$code, m[2L], info = m[1L])
    expect_identical(v$severity, "error", info = m[1L])
  }
  ok <- wsb_skeleton_defaults("market_growth")
  ok$residual_value$market_growth$base_value_eur <- 250000
  expect_identical(nrow(wsb_validate(vofi_scenario(ok))), 0L)
  # exit_yield ohne building zulässig, ohne Mietkomponente aber W (Tabelle Teil A 6.1)
  v <- wsb_validate(vofi_scenario(wsb_skeleton_defaults("exit_yield")))
  expect_identical(v$code, "validation.residual.no_rent")
  expect_identical(v$severity, "warning")
  # mit building wird der Bezug der gewählten Methode gelesen
  v <- wsb_validate(vofi_scenario(within(wsb_skeleton_defaults("income_value"), {
    building <- list(n_units = 1L)
  })))
  expect_true("validation.ref_target_missing" %in% v$code)
  expect_true("residual_value.income_value.land_value_eur" %in% v$path)
})

test_that("B6: Termine aus Listen mit NULL behalten die Klasse Date", {
  d <- val_dates_c(list(NULL, as.Date("2028-01-01"), NULL, as.Date("2027-06-01")))
  expect_s3_class(d, "Date")
  expect_identical(min(d), as.Date("2027-06-01"))
  expect_null(val_dates_c(list(NULL, NULL)))
  expect_null(val_dates_c(list()))
  v <- wsb_validate(wsb_with("domain", function(x) {
    x$grid <- list(construction_months = 12L)
    x$measures$a <- wsb_m(date = "2028-01-01")
    x$measures$b <- wsb_m(date = "2028-02-01", follows_construction = TRUE)
    x$funding <- list(f = list(instrument_type = "grant", measures = c("a", "b"),
                               application_before_start = TRUE,
                               application_date = "2027-01-01"))
    x
  }))
  expect_false("validation.grid.completion_mismatch" %in% v$code)
  expect_identical(sum(v$severity == "error"), 0L, info = wsb_errors(v))
})

test_that("M1: Ordnung der Energiezustände nach Starttermin (Teil B 3.2.2, 3.4)", {
  st <- function(...) {
    vc <- val_context(vofi_resolve(wsb_with("domain")))
    val_energy_state_order(vc, lapply(list(...), as.Date))
    vapply(vc$out, function(r) r$code, "")
  }
  expect_length(st(before = "2027-01-01", after = "2028-01-01", wp = "2048-01-01",
                   dach = "2032-01-01"), 0L)
  # ein Zustand am Stichtag löst before sofort ab (Teil C S4: Wärmepumpe 2027)
  expect_length(st(before = "2027-01-01", after = "2027-01-01", s2 = "2030-01-01"), 0L)
  expect_identical(st(before = "2027-01-01", a = "2030-01-01", b = "2030-01-01"),
                   "validation.energy.state_order")
  expect_identical(st(before = "2027-01-01", after = "2026-01-01"),
                   "validation.energy.state_order")
})

test_that("M6: exclusive_with trifft auch über den Programmcode des Eintrags (Teil B 4.11)", {
  lib <- withr::local_tempdir()
  dir.create(file.path(lib, "funding"))
  writeLines(c("id: funding/x_test", "block: funding", "values:", "  program_code: '261'"),
             file.path(lib, "funding", "x_test.yaml"))
  writeLines(c("id: funding/x_kette", "block: funding", "from: funding/x_test", "values: {}"),
             file.path(lib, "funding", "x_kette.yaml"))
  withr::local_options(vofi.library_paths = lib)
  expect_identical(val_lib_program_code("funding/x_kette"), "261")
  expect_null(val_lib_program_code("funding/gibts_nicht"))
  run <- function(code, excl = "funding/x_test") {
    wsb_codes(wsb_with("domain", function(x) {
      wsb_funding(x, f1 = list(cumulation = list(exclusive_with = excl)),
                  f2 = list(program_code = code))
    }))
  }
  expect_true("validation.funding.cumulation_exclusive" %in% run("261"))
  expect_true("validation.funding.cumulation_exclusive" %in% run("261", "funding/x_kette"))
  expect_false("validation.funding.cumulation_exclusive" %in% run("458"))
})

test_that("M6: Zuschüsse im Rahmen der Kosten ohne Befund", {
  v <- wsb_validate(wsb_with("domain", function(x) {
    wsb_funding(x, f = list(amount_eur = 100000, cumulation = list(max_total_share = 0.4)))
  }))
  expect_false("validation.funding.cumulation_total_share" %in% v$code)
  v <- wsb_validate(wsb_with("domain", function(x) {
    x$measures$huelle$replaces_ohnehin <- "huelle"
    x
  }))
  expect_false("validation.measures.replaces_ohnehin_unknown" %in% v$code)
})

test_that("m1: Kostengruppe 100 nach Maßnahmentyp (Teil A 4.1)", {
  v <- wsb_validate(wsb_with("domain", function(x) {
    x$project$project_type <- "neubau"
    x$building$existing_value_eur <- NULL
    x$variants <- NULL
    x$measures <- list(gs = list(measure_type = "erwerb_grundstueck", date = "2027-01-01",
                                 purchase_price_eur = 200000, kg = 100L),
                       bau = list(measure_type = "neubau", date = "2028-01-01",
                                  cost_eur = 900000))
    x
  }))
  expect_false("validation.measures.kg100" %in% v$code)
  expect_false("validation.measures.type_project_mismatch" %in% v$code)
})

test_that("R-115: Bibliotheksstand nur für gelesene Teilbäume", {
  rows <- rbind(wsb_rows("building.maintenance.rate_eur_m2_pa", entry = "costs/alt",
                         valid_from = "2020-01-01", valid_to = "2021-01-01"),
                wsb_rows("residual_value.multiplier.factor", entry = "valuation/alt",
                         valid_from = "2020-01-01", valid_to = "2021-01-01"),
                wsb_rows("residual_value.income_value.cap_rate", entry = "valuation/alt2",
                         valid_from = "2020-01-01", valid_to = "2021-01-01"))
  spec <- wsb_spec(function(x) {
    x$building$maintenance <- list(enabled = FALSE, rate_eur_m2_pa = 14.4)
    lv <- list(ref = "building.land_value_eur")
    x$residual_value <- list(method = "income_value",
                             income_value = list(cap_rate = 0.035, land_value_eur = lv),
                             multiplier = list(factor = 20))
    x
  }, function(s) wsb_spec_with_library(s, rows))
  v <- vofi_validate(spec)
  hit <- v$path[v$code == "validation.library.outdated"]
  expect_true("residual_value.income_value.cap_rate" %in% hit)
  expect_false(any(c("building.maintenance.rate_eur_m2_pa", "residual_value.multiplier.factor")
                   %in% hit))
})
