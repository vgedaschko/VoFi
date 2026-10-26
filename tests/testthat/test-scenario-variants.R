# Tests für R/scenario-variants.R (WS-A; Spec 00 Abschnitte 4.7, 4.11; Spec 01 Teil A 2.1
# XM13, Teil C 4.1, 4.2 z1-z7).

variant_scenario <- function() {
  sc <- example_scenario("skeleton")
  sc$variants <- list(
    teuer = list(label = "Teurer", set = list("components.z.values" = c(-120000, 30000, 40000,
                                                                        50000))),
    mehr = list(label = "Mehr Miete", extends = "teuer", description = "mit Miete",
                add = list("components.miete" = list(type = "recurring", category = "rent",
                                                     amount_eur = 6000,
                                                     start_event = "2027-01-01")),
                overrides = list(accounts = list(deposit_rate_pa = 0.03))),
    ohne = list(label = "Ohne Kredit", remove = list("financing.bank"),
                replace = list("financing.ek" = list(type = "equity", amount_eur = 100000))),
    kreis_a = list(label = "a", extends = "kreis_b"),
    kreis_b = list(label = "b", extends = "kreis_a"),
    falsch = list(label = "f", set = list("components.gibt_es_nicht.values" = 1)),
    tippfehler = list(label = "t", sett = list("components.z.values" = 1))
  )
  sc$scenario_sets <- list(
    zins = list(label = "Zins", set = list("accounts.deposit_rate_pa" = 0.04)),
    verboten = list(label = "v", set = list("components.z.values" = 1))
  )
  vofi_scenario(sc)
}

quiet_resolve <- function(...) {
  withCallingHandlers(vofi_resolve(...),
                      vofi_warning_library_outdated = function(w) invokeRestart("muffleWarning"),
                      message = function(m) invokeRestart("muffleMessage"))
}

test_that("vofi_variants listet Basis und Varianten mit Elternvariante", {
  v <- vofi_variants(variant_scenario())
  expect_identical(v$variant[1:4], c("base", "teuer", "mehr", "ohne"))
  expect_identical(v$extends[3], "teuer")
  expect_identical(v$extends[2], "base")
  expect_identical(v$label[1], "Basis")
  expect_identical(v$description[3], "mit Miete")
  expect_identical(names(v), c("variant", "label", "extends", "description"))
  expect_error(vofi_variants(list()), class = "vofi_error_input")
  expect_identical(var_chain(variant_scenario()$variants, "mehr"), c("teuer", "mehr"))
  expect_identical(var_chain(list(), "base"), character(0))
})

test_that("Operationen set, add, overrides (extends-Kette), remove, replace (4.11)", {
  sc <- variant_scenario()
  t <- quiet_resolve(sc, "teuer")
  expect_identical(t$components$z$values$values, c(-120000, 30000, 40000, 50000))
  expect_identical(t$variant, "teuer")
  m <- quiet_resolve(sc, "mehr")
  expect_identical(m$components$z$values$values[1], -120000)
  expect_identical(m$components$miete$type, "recurring")
  expect_identical(m$components$miete$growth, node_const(0))
  expect_identical(m$accounts$deposit_rate_pa, node_const(0.03))
  prov <- attr(m, "provenance")
  expect_identical(prov$layer[prov$path == "accounts.deposit_rate_pa"], 7L)
  expect_identical(prov$variant[prov$path == "accounts.deposit_rate_pa"], "mehr")
  expect_identical(prov$variant[prov$path == "components.z.values"], "teuer")
  expect_identical(prov$source_type[prov$path == "components.miete.growth"], "type_default")
  o <- quiet_resolve(sc, "ohne")
  expect_null(o$financing$bank)
  expect_identical(o$financing$ek$amount_eur, node_const(100000))
  res <- vofi_run(vofi_build(quiet_resolve(sc, "mehr")))
  teuer <- vofi_run(vofi_build(quiet_resolve(sc, "teuer")))
  expect_true(res$kpis$terminal_value > teuer$kpis$terminal_value)
  e <- expect_error(quiet_resolve(sc, "kreis_a"), class = "vofi_error_validation")
  expect_identical(e$key, "io.variant_cycle")
  e <- expect_error(quiet_resolve(sc, "falsch"), class = "vofi_error_validation")
  expect_identical(e$key, "io.variant_path_missing")
  e <- expect_error(quiet_resolve(sc, "unbekannt"), class = "vofi_error_validation")
  expect_match(conditionMessage(e), "unbekannt", fixed = TRUE)
  e <- expect_error(quiet_resolve(sc, "tippfehler"), class = "vofi_error_validation")
  expect_identical(e$key, "io.variant_key_unknown")
  v <- suppressMessages(vofi_validate(sc, variant = c("base", "falsch")))
  expect_true("validation.resolve_failed" %in% v$code)
  e <- expect_error(var_apply_ops(list(a = list(b = 1)), list(add = list("a.b" = 2)), "v"),
                    class = "vofi_error_validation")
  expect_identical(e$key, "io.variant_path_exists")
})

test_that("Szenario-Sets: Pfadbeschränkung, Overrides (Schicht 8), Build auf Spezifikation", {
  sc <- variant_scenario()
  z <- quiet_resolve(sc, scenario_set = "zins")
  expect_identical(z$accounts$deposit_rate_pa, node_const(0.04))
  expect_identical(z$scenario_set, "zins")
  pz <- attr(z, "provenance")
  expect_identical(pz$source_type[pz$path == "accounts.deposit_rate_pa"], "scenario_set")
  expect_identical(pz$variant[pz$path == "accounts.deposit_rate_pa"], "zins")
  expect_identical(pz$variant[pz$path == "components.z.values"], "base+zins")
  e <- expect_error(quiet_resolve(sc, scenario_set = "verboten"), class = "vofi_error_validation")
  expect_identical(e$key, "io.scenario_set_path")
  expect_error(quiet_resolve(sc, scenario_set = "fehlt"), class = "vofi_error_validation")
  expect_error(quiet_resolve(sc, scenario_set = 1), class = "vofi_error_input")
  ov <- quiet_resolve(sc, overrides = list(financing = list(bank = list(rate_pa = 0.06))))
  expect_identical(ov$financing$bank$rate_pa, node_const(0.06))
  expect_identical(ov$financing$bank$term_years, node_const(3))
  ov_rate <- list(financing = list(bank = list(rate_pa = 0.06)))
  m1 <- suppressMessages(vofi_build(sc, overrides = ov_rate))
  m2 <- suppressMessages(vofi_build(quiet_resolve(sc), overrides = ov_rate))
  expect_identical(vofi_run(m1)$kpis, vofi_run(m2)$kpis)
  # 1 % mehr Sollzins: 600 EUR je Jahr weniger Anlage, aufgezinst mit 2 %
  expect_equal(vofi_run(m1)$kpis$terminal_value, 52830.80 - 600 * (1.02^2 + 1.02 + 1),
               tolerance = 1e-10)
  expect_error(vofi_resolve(list()), class = "vofi_error_input")
  expect_error(vofi_resolve(sc, overrides = 1), class = "vofi_error_input")
  expect_error(vofi_resolve(sc, variant = c("a", "b")), class = "vofi_error_input")
})

test_that("Standard-Sets aus global.yaml (Teil C 4.2): Platzhalter, Wachstumsform, Rechtsstand", {
  local_ws_a_library()
  base <- ws_a_scenario(horizon_years = 5L,
                        measures = list(m1 = list(measure_type = "fenster", year = 2028,
                                                  cost_eur = 1000)),
                        funding = list(f1 = list(instrument_type = "grant", measures = list("m1")),
                                       f2 = list(instrument_type = "grant")))
  # z1/foerderstopp: alle Zusagen 0 (Vorlagenfeld approved, R-112)
  fs <- ws_a_resolve(base, scenario_set = "foerderstopp")
  expect_identical(fs$funding$f1$approved, node_const(0))
  expect_identical(fs$funding$f2$approved, node_const(0))
  expect_identical(ws_a_prov(fs, "funding.f1.approved")$source_type, "scenario_set")
  # z2: kein Treffer -> Hinweis, Ergebnis wie Basis
  nofund <- ws_a_scenario(horizon_years = 5L)
  m <- testthat::capture_messages(withCallingHandlers(
    z2 <- vofi_resolve(vofi_scenario(nofund), scenario_set = "foerderstopp"),
    vofi_warning_library_outdated = function(w) invokeRestart("muffleWarning")))
  expect_true(any(grepl("keinen Treffer", m, fixed = TRUE)))
  b0 <- ws_a_resolve(nofund)
  expect_identical(z2$funding, b0$funding)
  expect_identical(z2$market, b0$market)
  # zinsschock: Bauzins dauerhaft 6,5 %
  zs <- ws_a_resolve(base, scenario_set = "zinsschock")
  expect_identical(zs$market$mortgage_rate, node_const(0.065))
  # z3: stress_2022 ersetzt die Ratenreihe der Wachstumsform, start und base_date bleiben
  st <- ws_a_resolve(base, scenario_set = "stress_2022")
  gas <- st$market$energy_price$gas
  expect_identical(gas$kind, "growth")
  expect_identical(gas$start, node_const(0.06335))
  expect_identical(gas$base_date, as.Date("2027-01-01"))
  expect_identical(gas$growth$kind, "series_year")
  g <- scn_grid(st)
  v <- as.vector(ws_a_value(st, "market.energy_price.gas", "path"))
  yearly <- vapply(2027:2031, function(y) v[max(which(g$year == y))], double(1))
  expect_equal(yearly, c(0.12923, 0.09886, 0.08067, 0.06857, 0.06994), tolerance = 1e-4)
  expect_equal(st$market$inflation$values, c(0.069, 0.059, 0.022))
  # z4: konstanter Energiepreis ist keine Wachstumsform
  const <- ws_a_scenario(horizon_years = 5L, market = list(energy_price = list(gas = 0.06335)))
  e <- expect_error(ws_a_resolve(const, scenario_set = "stress_2022"),
                    class = "vofi_error_validation")
  expect_identical(e$key, "io.scenario_set_growth_form")
  # gasnetz_rueckbau: Netzentgelte +8 % p. a. (nur growth gemischt)
  gn <- ws_a_resolve(base, scenario_set = "gasnetz_rueckbau")
  expect_identical(gn$market$energy_network_fee$gas$growth, node_const(0.08))
  expect_identical(gn$market$energy_network_fee$gas_mfh$start, node_const(0.0219))
  # z5: mit_2045_stufe wählt den Reformeintrag des Themas bio_treppe
  s45 <- ws_a_resolve(base, scenario_set = "mit_2045_stufe")
  expect_identical(s45$project$pending_reforms, "stufe_2045")
  expect_identical(s45$legal$bio_treppe$entry, "legal/gmodg_bio_treppe_2045")
  expect_identical(ws_a_resolve(base)$legal$bio_treppe$entry, "legal/gmodg_bio_treppe_2026")
  # vorsichtig wird generiert (WS-G), nicht von vofi_resolve() angewendet
  e <- expect_error(ws_a_resolve(base, scenario_set = "vorsichtig"), class = "vofi_error_input")
  expect_identical(e$key, "io.scenario_set_generated")
})

test_that("Set-Pfade: z6 außerhalb der Blöcke, z7 shared, Platzhalter höchstens einmal", {
  local_ws_a_library()
  sc <- ws_a_scenario(shared = list(co2_2030 = 100),
                      measures = list(m = list(measure_type = "fenster", year = 2028,
                                               cost_eur = 1)),
                      scenario_sets = list(
                        z6 = list(label = "z6", set = list("measures.*.cost_eur" = 1)),
                        z7 = list(label = "z7", set = list("shared.co2_2030" = 120)),
                        zwei = list(label = "2", set = list("funding.*.x.*" = 1)),
                        beides = list(label = "b", set = list("market.x" = 1),
                                      generate = list(method = "cautious")),
                        schluessel = list(label = "k", extends = "base"),
                        eigen = list(label = "e", set = list("market.pv_price" = 0.2))
                      ),
                      market = list(pv_price = 0.1))
  e6 <- expect_error(ws_a_resolve(sc, scenario_set = "z6"), class = "vofi_error_validation")
  expect_identical(e6$key, "io.scenario_set_path")
  e7 <- expect_error(ws_a_resolve(sc, scenario_set = "z7"), class = "vofi_error_validation")
  expect_identical(e7$key, "io.scenario_set_shared")
  expect_match(conditionMessage(e7), "market-Pfad", fixed = TRUE)
  ew <- expect_error(ws_a_resolve(sc, scenario_set = "zwei"), class = "vofi_error_validation")
  expect_identical(ew$key, "io.scenario_set_wildcard")
  eb <- expect_error(ws_a_resolve(sc, scenario_set = "beides"), class = "vofi_error_validation")
  expect_identical(eb$key, "io.scenario_set_both")
  ek <- expect_error(ws_a_resolve(sc, scenario_set = "schluessel"),
                     class = "vofi_error_validation")
  expect_identical(ek$key, "io.scenario_set_key_unknown")
  expect_identical(ws_a_resolve(sc, scenario_set = "eigen")$market$pv_price, node_const(0.2))
  expect_identical(var_expand_path(list(f = list(a = 1, b = 2)), "f.*.x", "s", TRUE),
                   c("f.a.x", "f.b.x"))
  expect_identical(var_expand_path(list(), "f.*.x", "s", TRUE), character(0))
  expect_error(var_expand_path(list(), "f.*.x", "v", FALSE), class = "vofi_error_validation")
})

test_that("Sets aus Profil und Szenario werden über global.yaml gemischt", {
  local_ws_a_library()
  defaults <- scn_defaults_stack("wu_privat")
  own <- list(zinsschock = list(set = list("market.mortgage_rate" = 0.07)),
              neu = list(label = "neu", set = list("tax.module" = "none")))
  sets <- var_scenario_sets(defaults, own)
  expect_true(all(c("foerderstopp", "vorsichtig", "zinsschock", "neu") %in% names(sets)))
  expect_identical(sets$zinsschock$set$market.mortgage_rate, 0.07)
  expect_match(sets$zinsschock$label, "Zinsschock", fixed = TRUE)
})

test_that("Overlay in Varianten (R-96) und Overlay-Bindung bei set/replace (4.7)", {
  local_ws_a_library()
  sc <- vofi_scenario(ws_a_scenario(
    market = list(x = 0.02, y = 0.03),
    stochastic = list(parameters = list(
      kx = list(target = "market.x", dist = "normal", mean = 0.02, sd = 0.01),
      ky = list(target = "market.y", dist = "normal", mean = 0.03, sd = 0.01))),
    variants = list(
      fix = list(label = "x fest", set = list("market.x" = 0.025)),
      neu = list(label = "x neu verteilt", set = list("market.x" = 0.025),
                 replace = list("stochastic.parameters.kx" = list(target = "market.x",
                                                                   dist = "normal",
                                                                   mean = 0.025, sd = 0.02))),
      add = list(label = "Overlay dazu", add = list("stochastic.parameters.kz" = list(
        target = "market.y", from = "processes/cost_risks_2026", use = "overrun_component"))),
      weg = list(label = "Overlay weg", remove = list("stochastic.parameters.ky")),
      kurz = list(label = "Kurzform", set = list("market.x" = list(dist = "pert", min = 0.01,
                                                                   base = 0.02,
                                                                   mode = 0.02, max = 0.04)))
    )))
  m <- testthat::capture_messages(withCallingHandlers(
    fx <- vofi_resolve(sc, "fix"),
    vofi_warning_library_outdated = function(w) invokeRestart("muffleWarning")))
  expect_true(any(grepl("kx", m, fixed = TRUE) & grepl("deterministisch", m, fixed = TRUE)))
  expect_null(fx$stochastic$parameters$kx)
  expect_false(is.null(fx$stochastic$parameters$ky))
  nu <- quiet_resolve(sc, "neu")
  expect_identical(nu$stochastic$parameters$kx$sd, 0.02)
  ad <- quiet_resolve(sc, "add")
  expect_identical(ad$stochastic$parameters$kz$dist, "pert")
  expect_identical(ad$stochastic$parameters$kz$target, "market.y")
  expect_identical(ws_a_prov(ad, "stochastic.parameters.kz.max")$entry, "processes/cost_risks_2026")
  expect_identical(ws_a_prov(ad, "stochastic.parameters.kz.max")$layer, 7L)
  expect_null(quiet_resolve(sc, "weg")$stochastic$parameters$ky)
  ku <- quiet_resolve(sc, "kurz")
  expect_identical(ku$market$x, node_const(0.02))
  expect_identical(ku$stochastic$parameters[["market.x"]]$dist, "pert")
  expect_null(ku$stochastic$parameters$kx)                    # Ziel höchstens einmal
})

test_that("Bibliotheksverweise in Operationen werden nach Schicht 3 aufgelöst (R-87)", {
  local_ws_a_library()
  sc <- vofi_scenario(ws_a_scenario(
    measures = list(m1 = list(measure_type = "fenster", year = 2028, cost_eur = 1000)),
    variants = list(
      kfw = list(label = "mit KfW", add = list("funding.kfw" = list(
        from = "funding/kfw_261_eh55", measures = "m1"))),
      co2 = list(label = "CO2 hoch", set = list("market.co2_price" = list(
        from = "prices/co2_price_paths_2026", use = "scenarios.hoch"))),
      bad = list(label = "falsche id", add = list("funding.k" = list(from = "funding/gibtsnicht")))
    )))
  k <- quiet_resolve(sc, "kfw")
  expect_identical(k$funding$kfw$instrument_type, "loan_with_repayment_grant")
  expect_identical(k$funding$kfw$measures, "m1")
  p <- ws_a_prov(k, "funding.kfw.repayment_grant.base_rates.ee")
  expect_identical(c(p$layer, p$entry, p$variant), c("7", "funding/kfw_261_eh55", "kfw"))
  expect_identical(ws_a_prov(k, "funding.kfw.measures")$source_type, "variant")
  expect_identical(k$funding$kfw$approval_timing, "before_start")
  c2 <- quiet_resolve(sc, "co2")
  expect_identical(ws_a_prov(c2, "market.co2_price")$entry, "prices/co2_price_paths_2026")
  expect_identical(c2$market$co2_price$kind, "points")
  e <- expect_error(quiet_resolve(sc, "bad"), class = "vofi_error_validation")
  expect_identical(e$key, "io.library.entry_unknown")
})

test_that("set/overrides auf Vorlagen- und Regelfelder (R-112, Teil A XM13)", {
  x <- unclass(example_scenario("skeleton"))
  x$building <- list(n_units = 4L)
  x$measures <- list(wp = list(measure_type = "heizung_waermepumpe_luft", year = 2028,
                               cost_eur = 30000))
  x$components$r <- list(type = "recurring", category = "rent", amount_eur = 1000,
                         start_event = as.Date("2027-01-01"))
  x$variants <- list(
    vorlage = list(label = "Vorlagenfeld", set = list("building.building_id" = "b2")),
    schema = list(label = "Schemafeld", overrides = list(building = list(denkmal = TRUE))),
    regel = list(label = "Regelfeld", set = list("project.tax_regime" = "wu_eg_stpfl")),
    typ = list(label = "Typparameter", set = list("components.r.growth" = 0.01,
                                                  "financing.bank.fees.processing_fee_share" =
                                                    0.01)),
    xm13a = list(label = "Pfadform", set = list("measures.wp.cost_factor" = 1.2)),
    xm13b = list(label = "Map-Merge", set = list("measures.wp" = list(cost_factor = 1.2))),
    katalog = list(label = "Katalogfeld", set = list("measures.wp.useful_life_years" = 20)),
    ersetzen = list(label = "replace", replace = list("building.building_id" = "b2")),
    xm13c = list(label = "replace Vorlagenfeld", replace = list("measures.wp.cost_factor" = 1.2)),
    tippfehler = list(label = "unbekannt", set = list("measures.wp.kostenfaktor" = 1.2)),
    neu = list(label = "neues Element", set = list("components.neu.amount_eur" = 1)),
    unbekannt = list(label = "Typfeld", set = list("components.r.gibt_es_nicht" = 1))
  )
  sc <- vofi_scenario(x)
  b2 <- quiet_resolve(sc, "vorlage")
  expect_identical(b2$building$building_id, "b2")
  prov <- attr(b2, "provenance")
  expect_identical(prov$layer[prov$path == "building.building_id"], 7L)
  expect_identical(prov$source_type[prov$path == "building.building_id"], "variant")
  expect_identical(quiet_resolve(sc)$building$building_id, "b1")
  expect_true(isTRUE(quiet_resolve(sc, "schema")$building$denkmal))
  rg <- quiet_resolve(sc, "regel")
  expect_identical(rg$project$tax_regime, "wu_eg_stpfl")
  prov_rg <- attr(rg, "provenance")
  expect_identical(prov_rg$source_type[prov_rg$path == "project.tax_regime"], "variant")
  ty <- quiet_resolve(sc, "typ")
  expect_identical(ty$components$r$growth, node_const(0.01))
  expect_identical(ty$financing$bank$fees$processing_fee_share, node_const(0.01))
  for (v in c("xm13a", "xm13b")) {
    s <- quiet_resolve(sc, v)
    expect_identical(s$measures$wp$cost_factor, node_const(1.2), info = v)
    expect_identical(ws_a_prov(s, "measures.wp.cost_factor")$source_type, "variant", info = v)
  }
  expect_identical(quiet_resolve(sc, "katalog")$measures$wp$useful_life_years, node_const(20))
  for (v in c("ersetzen", "xm13c", "tippfehler", "neu", "unbekannt")) {
    expect_error(quiet_resolve(sc, v), class = "vofi_error_validation", info = v)
  }
})

test_that("Existenzprüfung nach R-112 mit Vorlagen einer Sammlung (var_path_known)", {
  ctx <- list(items = list(
    building = list(building_id = "b1", maintenance = list(enabled = TRUE, rate = 1)),
    measures = list(cost_factor = list(ref = "project.construction_cost_factor"),
                    rent_law = list(levy = "auto"))))
  x <- list(measures = list(wp = list(cost_eur = 1000)), building = list(n_units = 1L))
  r <- var_apply_ops(x, list(set = list("measures.wp.cost_factor" = 1.2)), "v", ctx = ctx)
  expect_identical(r$x$measures$wp$cost_factor, 1.2)
  expect_identical(r$bound, "measures.wp.cost_factor")
  r2 <- var_apply_ops(x, list(set = list("measures.wp" = list(cost_factor = 1.2))), "v", ctx = ctx)
  expect_identical(r2$x$measures$wp, list(cost_eur = 1000, cost_factor = 1.2))
  ov <- list(measures = list(wp = list(rent_law = list(levy = "none"))))
  r3 <- var_apply_ops(x, list(overrides = ov), "v", ctx = ctx)
  expect_identical(r3$x$measures$wp$rent_law$levy, "none")
  r4 <- var_apply_ops(x, list(set = list("building.maintenance.rate" = 2)), "v", ctx = ctx)
  expect_identical(r4$x$building$maintenance$rate, 2)
  bad <- list(
    list(replace = list("measures.wp.cost_factor" = 1.2)),
    list(set = list("measures.wp.kostenfaktor" = 1.2)),
    list(set = list("measures.cost_factor" = 1)),
    list(set = list("measures.neu.cost_factor" = 1)),
    list(set = list("measures.wp.cost_factor.scale" = 1)),
    list(set = list("building.maintenance.gibt_es_nicht" = 1)),
    list(remove = list("measures.wp.cost_factor"))
  )
  for (ops in bad) {
    expect_error(var_apply_ops(x, ops, "v", ctx = ctx), class = "vofi_error_validation",
                 info = names(unlist(ops)))
  }
  expect_identical(var_template_fields(x, "measures", ctx), character(0))
  expect_true(all(c("cost_factor", "rent_law", "useful_life_years", "kg") %in%
                    var_template_fields(x, "measures.wp", ctx)))
  expect_identical(var_template_fields(x, "measures.wp.cost_factor", ctx), character(0))
  expect_true("enabled" %in% var_template_fields(x, "measures.wp.replacement", NULL))
})

test_that("overrides: ~ entfernt ein vorhandenes Blatt, sonst Fehler (4.11)", {
  x <- list(a = list(b = 1, c = 2))
  r <- var_apply_ops(x, list(overrides = list(a = list(b = NULL))), "v")
  expect_identical(r$x, list(a = list(c = 2)))
  expect_identical(r$bound, character(0))
  expect_error(var_apply_ops(x, list(overrides = list(a = list(d = NULL))), "v"),
               class = "vofi_error_validation")
  expect_identical(var_override_leaves(list(a = list(b = NULL, c = list(ref = "x.y")))),
                   c("a.b", "a.c"))
  expect_identical(var_overlay_key("stochastic.parameters.k.max"), "parameters:k")
  expect_true(is.na(var_overlay_key("market.x")))
  expect_identical(var_dist_keys(list(dist = "pert", min = 1), "market.x"), "parameters:market.x")
  expect_identical(var_dist_keys(1, "market.x"), character(0))
})

test_that("from nur mit Bibliotheks-id; Termine heißen start_event (4.9, R-110, P0-12)", {
  sc <- example_scenario("skeleton")
  with_comp <- function(comp) {
    x <- unclass(sc)
    x$components$r <- comp
    vofi_scenario(x)
  }
  bad <- with_comp(list(type = "recurring", category = "rent", amount_eur = 1000,
                        from = "completion"))
  err <- tryCatch(quiet_resolve(bad), error = function(e) e)
  expect_s3_class(err, "vofi_error_validation")
  expect_identical(err$key, "validation.library.ref_not_id")
  expect_identical(err$args$path, "components.r.from")
  expect_match(conditionMessage(err), "start_event", fixed = TRUE)
  expect_error(suppressMessages(vofi_build(bad)), class = "vofi_error_validation")
  v <- suppressMessages(vofi_validate(bad, variant = "base"))
  expect_true("validation.library.ref_not_id" %in% v$code)
  expect_identical(v$path[v$code == "validation.library.ref_not_id"], "components.r.from")
  x <- unclass(sc)
  x$building <- list(n_units = 4L, maintenance = list(from = as.Date("2028-01-01")))
  err2 <- tryCatch(quiet_resolve(vofi_scenario(x)), error = function(e) e)
  expect_identical(err2$key, "validation.library.ref_not_id")
  expect_identical(err2$args$path, "building.maintenance.from")
  expect_match(conditionMessage(err2), "2028-01-01", fixed = TRUE)
  x$building$maintenance <- list(from = 2030)
  expect_error(quiet_resolve(vofi_scenario(x)), class = "vofi_error_validation")
  ok <- with_comp(list(type = "recurring", category = "rent", amount_eur = 1000,
                       start_event = as.Date("2027-01-01")))
  sp <- quiet_resolve(ok, overrides = list(components = list(r = list(start_event = 2028))))
  expect_identical(sp$components$r$type, "recurring")
  expect_identical(sp$components$r$amount_eur, node_const(1000))
  expect_identical(sp$components$r$start_event, as.Date("2028-01-01"))
  expect_identical(quiet_resolve(ok)$components$r$start_event, as.Date("2027-01-01"))
  expect_error(quiet_resolve(ok, overrides = list(components = list(r = list(from = 2028)))),
               class = "vofi_error_validation")
})
