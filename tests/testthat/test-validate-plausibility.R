# Tests für R/validate-plausibility.R (WS-B; Feldtabellen und Validierungsregeln Spec 01
# Teil A 1-6, Teil B 1-4, Teil C 1.11; Spec 00 Abschnitte 4.9, 8.2, 8.6, 10.9, 12.3).

test_that("Prüffälle der Ebene 4 (Tabelle)", {
  wsb_registry()
  wsb_expect_cases(wsb_cases_plaus())
})

test_that("Komponentenszenarien ohne Domänenblöcke bleiben ohne Plausibilitätsbefund", {
  sk <- example_scenario("skeleton")
  expect_identical(sk$project$project_type, "neubau")
  expect_identical(nrow(vofi_validate(sk)), 0L)
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
  rented <- vofi_validate(wsb_with("domain", function(x) {
    x$building$property_tax <- NULL
    x
  }), variant = "base")
  expect_identical(rented$severity[rented$code == "validation.building.property_tax_missing"],
                   "info")
  own <- vofi_validate(wsb_with("domain", function(x) {
    x$project$perspective <- "selbstnutzer"
    x$building$property_tax <- NULL
    x$unit_groups$a$owner_occupied <- TRUE
    x
  }), variant = "base")
  expect_identical(own$severity[own$code == "validation.building.property_tax_missing"],
                   "warning")
  e <- vofi_validate(wsb_with("domain", function(x) {
    x$building$property_tax <- list(assessment_amount_eur = 100)
    x
  }), variant = "base")
  expect_identical(e$code, "validation.building.property_tax_multiplier")
})

test_that("Finanzierung: L11 (Tilgungssatz und Laufzeit) und Rate negativer Tilgung", {
  v <- vofi_validate(wsb_with("skeleton", function(x) {
    x$financing$l11 <- list(type = "annuity_loan", amount_eur = 100000, rate_pa = 0.03,
                            initial_repayment_pa = 0.02, term_years = 10,
                            payments_per_year = 12L)
    x
  }))
  b <- v[v$code == "validation.financing.balloon_at_maturity", , drop = FALSE]
  expect_identical(b$severity, "info")
  expect_identical(b$path, "financing.l11.initial_repayment_pa")
  ok <- vofi_validate(wsb_with("skeleton", function(x) {
    x$financing$a <- list(type = "annuity_loan", amount_eur = 100000, rate_pa = 0.03,
                          installment_eur = 500, payments_per_year = 12L)
    x
  }))
  expect_false("validation.financing.negative_amortization" %in% ok$code)
  neg <- vofi_validate(wsb_with("skeleton", function(x) {
    x$financing$a <- list(type = "annuity_loan", amount_eur = 100000, rate_pa = 0.03,
                          installment_eur = 250, payments_per_year = 12L)
    x
  }))
  expect_true("validation.financing.negative_amortization" %in% neg$code)
})

test_that("Erwerb: A6 und X2 (Teil A 4.8, 4.9)", {
  a6 <- vofi_validate(wsb_with("domain", function(x) {
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
  small <- vofi_validate(wsb_with("domain", function(x) {
    x$project$project_type <- "erwerb_sanierung"
    x$project$federal_state <- NULL
    x$building$existing_value_eur <- NULL
    x$measures$kauf <- list(measure_type = "erwerb_grundstueck", date = "2027-01-01",
                            purchase_price_eur = 2400)
    x
  }), variant = "base")
  expect_false("validation.acquisition.federal_state_missing" %in% small$code)
  x2 <- vofi_validate(wsb_with("domain", function(x) {
    x$project$project_type <- "erwerb_sanierung"
    x
  }), variant = "base")
  expect_identical(x2$code, "validation.building.existing_value_with_purchase")
})

test_that("Instandhaltung: Kennwert der expliziten Erneuerungen (4.11.4)", {
  v <- vofi_validate(wsb_with("domain", function(x) {
    x$building$maintenance <- list(enabled = TRUE, basis = "rate", rate_eur_m2_pa = 10,
                                   excludes_explicit_replacements = TRUE)
    x$building$elements <- list(dach = list(measure_type = "daemmung_dach_steil",
                                            installed_year = 2000L,
                                            replacement_cost_eur = 16000))
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
  expect_false("validation.library.outdated" %in% vofi_validate(spec)$code)
  late <- wsb_spec(function(x) wsb_funding(x, f = list(application_date = "2026-01-01")),
                   function(s) {
                     wsb_spec_with_library(s, wsb_rows("funding.f.instrument_type",
                                                       entry = "funding/kfw_test",
                                                       valid_from = "2026-07-21",
                                                       as_of = "2026-10-25"))
                   })
  v <- vofi_validate(late)
  expect_identical(v$path[v$code == "validation.library.outdated"],
                   "funding.f.instrument_type")
})

test_that("Förderung: Berechtigung mit Oberbegriff privatperson und Bestätigung", {
  v <- vofi_validate(wsb_with("domain", function(x) {
    wsb_funding(x,
                f1 = list(applicant = "privatperson_vermieter",
                          eligibility = list(applicants = "privatperson")),
                f2 = list(eligibility = list(project_types = "neubau"),
                          eligibility_override = TRUE))
  }), variant = "base")
  expect_false("validation.funding.not_eligible" %in% v$code)
  expect_identical(v$code, "validation.funding.eligibility_override")
})
