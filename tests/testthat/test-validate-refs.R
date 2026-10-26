# Tests für R/validate-refs.R (WS-B; Spec 00 Abschnitte 4.5 Regeln 2-5, 4.11, 8.7, 9.11, 11.6,
# 12.3a, R-115; Spec 01 Teil A 3.5, 4.9, 5.3; Teil B 4.9; Teil C 1.3-1.11, 4.2).

test_that("Prüffälle der Ebene 3 (Tabelle)", {
  wsb_registry()
  wsb_expect_cases(wsb_cases_refs())
})

test_that("R-115: Bezüge nur in gelesenen Knoten (Methode, enabled, Anschlusszins)", {
  # Restwert-Untermap einer nicht gewählten Methode und Szenario ohne building: ungeprüft
  v0 <- vofi_validate(wsb_with("skeleton", function(x) {
    x$residual_value <- list(method = "zero", income_value = list(
      land_value_eur = list(ref = "building.land_value_eur")))
    x
  }))
  expect_identical(nrow(v0), 0L)
  v1 <- vofi_validate(wsb_with("domain", function(x) {
    x$residual_value <- list(method = "income_value", income_value = list(
      land_value_eur = list(ref = "building.land_value_eur")))
    x
  }), variant = "base")
  hit <- v1[v1$code == "validation.ref_target_missing", , drop = FALSE]
  expect_identical(hit$path, "residual_value.income_value.land_value_eur")
  expect_match(hit$message, "building.land_value_eur", fixed = TRUE)
  expect_true("validation.residual.land_value_missing" %in% v1$code)
  # Teilbaum mit enabled: false
  off <- vofi_validate(wsb_with("domain", function(x) {
    x$building$maintenance <- list(enabled = FALSE, area_m2 = list(ref = "building.gibts"))
    x
  }), variant = "base")
  expect_false("validation.ref_target_missing" %in% off$code)
  on <- vofi_validate(wsb_with("domain", function(x) {
    x$building$maintenance <- list(enabled = TRUE, basis = "none",
                                   area_m2 = list(ref = "building.gibts"))
    x
  }), variant = "base")
  expect_identical(on$path[on$code == "validation.ref_target_missing"],
                   "building.maintenance.area_m2")
  # Anschlusszins nur bei Zinsanpassung im Horizont (Default {ref: market.mortgage_rate})
  expect_identical(nrow(vofi_validate(example_scenario("skeleton"))), 0L)
  reset <- vofi_validate(wsb_with("skeleton", function(x) {
    x$financing$bank$fixed_years <- 2
    x
  }))
  expect_identical(reset$path[reset$code == "validation.ref_target_missing"],
                   "financing.bank.followup_rate_pa")
  ok <- vofi_validate(wsb_with("skeleton", function(x) {
    x$financing$bank$fixed_years <- 2
    x$market <- list(mortgage_rate = 0.04)
    x
  }))
  expect_identical(nrow(ok), 0L)
  late <- vofi_validate(wsb_with("skeleton", function(x) {
    x$financing$bank$fixed_years <- 5
    x
  }))
  expect_identical(nrow(late), 0L)
})

test_that("Bezüge: transitiv, Zyklen mit Kette, Codes in Ausdrücken (R-91)", {
  v <- vofi_validate(wsb_with("skeleton", function(x) {
    x$market <- list(a = list(ref = "market.gibts"), b = list(ref = "market.c"),
                     c = list(expr = "market.b * 2"))
    x$accounts$deposit_rate_pa <- list(ref = "market.a")
    x$accounts$overdraft_rate_pa <- list(ref = "market.b")
    x$accounts$penalty_spread_pa <- list(
      expr = "ifelse(project.perspective == 'wu_privat', 0.02, 0.01)")
    x
  }))
  expect_identical(v$path[v$code == "validation.ref_target_missing"], "market.a")
  cyc <- v[v$code == "validation.ref_cycle", , drop = FALSE]
  expect_identical(nrow(cyc), 1L)
  expect_match(cyc$message, "market.b -> market.c -> market.b", fixed = TRUE)
  expect_false(any(grepl("^validation\\.expr", v$code)))
  expect_identical(val_find_cycles(list(a = "b", b = c("c", "a"), c = character(0))),
                   list(c("a", "b")))
  expect_identical(val_find_cycles(list(a = "b", b = character(0))), list())
})

test_that("Elementregel 4: Prozessziele gelten als zeitabhängig", {
  wsb_registry()
  v <- vofi_validate(wsb_with("skeleton", function(x) {
    x$shared <- list(co2_2030 = 100)
    x$market <- list(co2 = list(years = c(2026, 2030), values = list(60, list(
      ref = "shared.co2_2030"))))
    x$accounts$overdraft_limit_eur <- list(ref = "market.co2")
    x$stochastic <- list(processes = list(p = list(target = "shared.co2_2030", type = "ar1",
                                                   mu = 100, phi = 0.5, sigma = 1)))
    x
  }))
  expect_identical(v$path[v$code == "validation.element_not_scalar"], "market.co2")
  expect_identical(val_path_shape(vc = val_context(vofi_resolve(wsb_with("skeleton"))),
                                  "accounts.deposit_rate_pa"), "scalar")
})

test_that("Mengenbezug: Bezugsobjekt, Rückfall building, Q5 (Teil A 3.5)", {
  v <- vofi_validate(wsb_with("domain", function(x) {
    x$measures$huelle$cost_eur <- list(value = 600, per = "m2_living_area")
    x$measures$m2 <- wsb_m(cost_eur = list(value = 248, per = "m2_component:facade"),
                           component_areas_m2 = list(facade = 600))
    x$measures$m3 <- wsb_m(cost_eur = list(value = 248, per = "m2_component:facade"))
    x$measures$m4 <- wsb_m(cost_eur = list(value = 1800, per = "kw"))
    x$measures$m5 <- wsb_m(cost_eur = list(value = 1800, per = "kw"), kw = 10)
    x
  }), variant = "base")
  hit <- v[v$code == "validation.quantity.reference_missing", , drop = FALSE]
  expect_setequal(hit$path, c("measures.m3.cost_eur", "measures.m4.cost_eur"))
  expect_match(hit$message[hit$path == "measures.m4.cost_eur"], "per: kw", fixed = TRUE)
  expect_identical(val_quantity_object("building.elements.e.replacement_cost_eur"),
                   "building.elements.e")
  expect_identical(val_quantity_object("building.maintenance.rate_eur_m2_pa"),
                   "building.maintenance")
})

test_that("auto: ein Baustein ohne Befund; Entscheidungsknoten gültig ohne Befund", {
  v <- vofi_validate(wsb_with("skeleton", function(x) {
    x$financing$bank$amount_eur <- "auto"
    x
  }))
  expect_false(any(grepl("auto", v$code)))
  ok <- vofi_validate(wsb_with("domain", function(x) {
    x <- wsb_funding(x, f = list(approval_timing = "before_start", fallback_variant = "ohnehin",
                                 approval_probability = 0.8))
    x$variants$ohnehin$remove <- list("funding.f")
    x
  }))
  expect_identical(nrow(ok), 0L)
})

test_that("Zeitpunkt der Zusage ohne aufgelösten Code (rule:approval_timing, R-111)", {
  spec <- vofi_resolve(wsb_with("domain", function(x) {
    wsb_funding(x, a = list(), b = list(application_date = "2029-01-01"),
                c = list(instrument_type = "rent_binding", measures = list()))
  }))
  vc <- val_context(spec)
  expect_identical(val_approval_timing(vc, "a"), "before_start")
  expect_identical(val_approval_timing(vc, "b"), "after_start")
  expect_identical(val_approval_timing(vc, "c"), "before_start")
  expect_identical(val_measure_first_date(list(year = 2030L)), as.Date("2030-01-01"))
  expect_identical(val_schedule_dates(list(schedule = list("2029-01-01" = 1, "2028" = 2))),
                   as.Date(c("2028-01-01", "2029-01-01")))
  expect_null(val_measure_first_date(NULL))
})

test_that("Overlay: Rebound-Konvention E-12 (Teil B 3.11)", {
  wsb_registry()
  reb <- function(base, lo, mo, hi) {
    v <- vofi_validate(wsb_with("domain", function(x) {
      x$energy <- list(performance_gap = list(rebound_factor = base))
      x$stochastic <- list(parameters = list(rebound = list(
        target = "energy.performance_gap.rebound_factor", dist = "pert", min = lo, mode = mo,
        max = hi)))
      x
    }), variant = "base")
    v$code
  }
  expect_true("validation.energy.rebound_base_differs" %in% reb(1, 0.9, 1.1, 1.4))
  expect_false("validation.energy.rebound_base_differs" %in% reb(1.1, 0.9, 1.1, 1.4))
  expect_false("validation.energy.rebound_base_differs" %in% reb(1, 0.82, 1, 1.27))
})

test_that("Overlay: zulässige Einträge ohne Befund; Paare aus der Bibliothek", {
  wsb_registry()
  v <- vofi_validate(wsb_with("domain", function(x) {
    x$measures$huelle$cost_factor <- 1
    x$stochastic <- list(
      parameters = list(
        kosten = list(target = "measures.huelle.cost_factor", dist = "pert", min = 0.95,
                      mode = 1, max = 1.5, apply = "multiply"),
        nd = list(target = "measures.huelle.useful_life_years", dist = "pert", min = 30,
                  mode = 40, max = 50)),
      correlations = list(parameters = list(list("kosten", "nd", 0.3))))
    x
  }), variant = "base")
  expect_identical(nrow(v), 0L)
  spec <- vofi_resolve(wsb_with("skeleton", function(x) {
    x$stochastic <- list(
      parameters = list(k = list(target = "accounts.deposit_rate_pa", dist = "pert",
                                 min = 0.01, mode = 0.02, max = 0.03)),
      correlations = list(parameters = list(list("k", "fehlt", 0.5))))
    x
  }))
  expect_true("validation.stochastic.corr_unknown_key" %in% vofi_validate(spec)$code)
  lib <- wsb_spec_with_library(spec, wsb_rows("stochastic.correlations.parameters",
                                              entry = "processes/param_correlations_2026"))
  expect_false("validation.stochastic.corr_unknown_key" %in% vofi_validate(lib)$code)
})

test_that("Referenzvariante: Neubau und Differenzmodus ohne Befund (12.3a, R-68)", {
  expect_identical(nrow(vofi_validate(wsb_with("domain", function(x) {
    x$project$project_type <- "erwerb_neubau"
    x$grid <- list(construction_months = 12L)
    x$building$existing_value_eur <- NULL
    x$variants <- NULL
    x
  }))), 0L)
  v <- vofi_validate(wsb_with("domain", function(x) {
    x$project$comparison_mode <- "differential"
    x$variants <- NULL
    x
  }))
  expect_false(any(grepl("reference_variant", v$code)))
  miss <- vofi_validate(wsb_with("domain", function(x) {
    x$variants <- NULL
    x
  }))
  expect_identical(miss$severity[miss$code == "validation.reference_variant_missing"], "error")
  expect_error(vofi_build(wsb_with("domain", function(x) {
    x$project$reference_variant <- "gibts"
    x
  }), variant = "base"), NA)
})

test_that("Bestandsdarlehen unverändert in Varianten ohne Befund; Sets z2, z4, z7", {
  v <- vofi_validate(wsb_with("domain", function(x) {
    x$financing$bank$existing <- TRUE
    x$financing$bank$start <- NULL
    x
  }))
  expect_false("validation.variants.existing_debt_changed" %in% v$code)
  # z4: Set mit Wachstumsrate auf konstantem Energiepreis
  z <- vofi_validate(wsb_with("skeleton", function(x) {
    x$market <- list(energy_price = list(gas = 0.06335))
    x$scenario_sets <- list(stress_2022 = list(label = "Stress", set = list(
      "market.energy_price.gas" = list(growth = list(series = list("2027" = 1, "2028" = -0.2))))))
    x
  }))
  g <- z[z$code == "validation.scenario_set.growth_form_required", , drop = FALSE]
  expect_identical(g$variant, "stress_2022")
  expect_match(g$message, "market.energy_price.gas", fixed = TRUE)
  ok <- vofi_validate(wsb_with("skeleton", function(x) {
    x$market <- list(energy_price = list(gas = list(start = 0.06335, growth = 0.02)))
    x$scenario_sets <- list(stress_2022 = list(label = "Stress", set = list(
      "market.energy_price.gas" = list(growth = 0.03))))
    x
  }))
  expect_false("validation.scenario_set.growth_form_required" %in% ok$code)
  # z2: Förderstopp ohne Förderung: Hinweis
  stopp <- vofi_validate(wsb_with("skeleton", function(x) {
    x$scenario_sets <- list(foerderstopp = list(label = "Förderstopp",
                                                set = list("funding.*.approved" = 0)))
    x
  }))
  expect_identical(stopp$severity[stopp$code == "validation.scenario_set.wildcard_no_match"],
                   "info")
})
