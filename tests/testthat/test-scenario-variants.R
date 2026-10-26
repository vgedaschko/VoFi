# Tests für R/scenario-variants.R und R/scenario-layers.R (WS-A; Spec 00 Abschnitte 4.7, 4.11).
# Phase-0-Minimalfassung.

variant_scenario <- function() {
  sc <- example_scenario("skeleton")
  sc$variants <- list(
    teuer = list(label = "Teurer", set = list("components.z.values" = c(-120000, 30000, 40000,
                                                                        50000))),
    mehr = list(label = "Mehr Miete", extends = "teuer",
                add = list("components.miete" = list(type = "recurring", category = "rent",
                                                     amount_eur = 6000,
                                                     start_event = "2027-01-01")),
                overrides = list(accounts = list(deposit_rate_pa = 0.03))),
    ohne = list(label = "Ohne Kredit", remove = list("financing.bank"),
                replace = list("financing.ek" = list(type = "equity", amount_eur = 100000))),
    kreis_a = list(label = "a", extends = "kreis_b"),
    kreis_b = list(label = "b", extends = "kreis_a"),
    falsch = list(label = "f", set = list("components.gibt_es_nicht.values" = 1))
  )
  sc$scenario_sets <- list(
    zins = list(label = "Zins", set = list("accounts.deposit_rate_pa" = 0.04)),
    verboten = list(label = "v", set = list("components.z.values" = 1))
  )
  vofi_scenario(sc)
}

test_that("vofi_variants listet Basis und Varianten", {
  v <- vofi_variants(variant_scenario())
  expect_identical(v$variant[1:4], c("base", "teuer", "mehr", "ohne"))
  expect_identical(v$extends[3], "teuer")
  expect_identical(v$label[1], "Basis")
  expect_error(vofi_variants(list()), class = "vofi_error_input")
})

test_that("Operationen set, add, overrides (extends-Kette), remove, replace", {
  sc <- variant_scenario()
  t <- vofi_resolve(sc, "teuer")
  expect_identical(t$components$z$values$values, c(-120000, 30000, 40000, 50000))
  expect_identical(t$variant, "teuer")
  m <- vofi_resolve(sc, "mehr")
  expect_identical(m$components$z$values$values[1], -120000)
  expect_identical(m$components$miete$type, "recurring")
  expect_identical(m$components$miete$growth, node_const(0))
  expect_identical(m$accounts$deposit_rate_pa, node_const(0.03))
  prov <- attr(m, "provenance")
  expect_identical(prov$layer[prov$path == "accounts.deposit_rate_pa"], 7L)
  expect_identical(prov$source_type[prov$path == "components.miete.growth"], "type_default")
  o <- vofi_resolve(sc, "ohne")
  expect_null(o$financing$bank)
  expect_identical(o$financing$ek$amount_eur, node_const(100000))
  res <- vofi_run(vofi_build(sc, variant = "mehr"))
  expect_true(res$kpis$terminal_value > vofi_run(vofi_build(sc, "teuer"))$kpis$terminal_value)
  expect_error(vofi_resolve(sc, "kreis_a"), class = "vofi_error_validation")
  expect_error(vofi_resolve(sc, "falsch"), class = "vofi_error_validation")
  expect_error(vofi_resolve(sc, "unbekannt"), class = "vofi_error_validation")
  v <- vofi_validate(sc, variant = c("base", "falsch"))
  expect_true("validation.resolve_failed" %in% v$code)
})

test_that("Szenario-Sets und Overrides (Schicht 8)", {
  sc <- variant_scenario()
  z <- vofi_resolve(sc, scenario_set = "zins")
  expect_identical(z$accounts$deposit_rate_pa, node_const(0.04))
  expect_identical(z$scenario_set, "zins")
  expect_error(vofi_resolve(sc, scenario_set = "verboten"), class = "vofi_error_validation")
  expect_error(vofi_resolve(sc, scenario_set = "fehlt"), class = "vofi_error_validation")
  ov <- vofi_resolve(sc, overrides = list(financing = list(bank = list(rate_pa = 0.06))))
  expect_identical(ov$financing$bank$rate_pa, node_const(0.06))
  expect_identical(ov$financing$bank$term_years, node_const(3))
  m1 <- vofi_build(sc, overrides = list(financing = list(bank = list(rate_pa = 0.06))))
  ov_rate <- list(financing = list(bank = list(rate_pa = 0.06)))
  m2 <- vofi_build(vofi_resolve(sc), overrides = ov_rate)
  expect_identical(vofi_run(m1)$kpis, vofi_run(m2)$kpis)
  # 1 % mehr Sollzins: 600 EUR je Jahr weniger Anlage, aufgezinst mit 2 %
  expect_equal(vofi_run(m1)$kpis$terminal_value, 52830.80 - 600 * (1.02^2 + 1.02 + 1),
               tolerance = 1e-10)
  expect_error(vofi_resolve(list()), class = "vofi_error_input")
  expect_error(vofi_resolve(sc, overrides = 1), class = "vofi_error_input")
})

test_that("Knotenbewusstes Mischen: Knoten und Wertformen ersetzen, Teil-Maps mischen", {
  sy <- list(kind = "series_year", years = 2027L, values = 1, fill = "locf", before = "first")
  base <- list(market = list(a = node_const(1), b = sy, c = list(x = 1, y = 2)))
  m <- scn_merge(base, list(market = list(a = list(ref = "market.x"), b = list(fill = "zero"),
                                          c = list(y = NULL, z = 3))))$market
  expect_identical(m$a, list(ref = "market.x"))
  expect_identical(m$b$fill, "zero")
  expect_identical(m$b$kind, "series_year")
  expect_identical(m$c, list(x = 1, z = 3))
  expect_identical(scn_merge(base, list(market = list(a = node_const(2))))$market$a,
                   node_const(2))
  comp <- list(components = list(r = list(type = "recurring", start_event = "2027-01-01")))
  m2 <- scn_merge(comp, list(components = list(r = list(start_event = "2028-01-01"))))
  expect_identical(m2$components$r$type, "recurring")
  expect_identical(m2$components$r$start_event, "2028-01-01")
  expect_false(scn_is_library_ref(list(from = "2027-01-01", to = "2030-01-01")))
  expect_false(scn_is_library_ref(list(from = "completion")))
  expect_false(scn_is_library_ref(list(from = "prices")))
  expect_false(scn_is_library_ref(node_const(1)))
  expect_true(scn_is_library_ref(list(from = "prices/co2_2026", use = "mittel")))
  expect_error(scn_check_library(list(market = list(co2 = list(from = "prices/co2")))),
               class = "vofi_error_not_implemented")
})

test_that("from nur mit Bibliotheks-id; Termine heißen start_event (4.9, R-110, P0-12)", {
  sc <- example_scenario("skeleton")
  with_comp <- function(comp) {
    x <- unclass(sc)
    x$components$r <- comp
    vofi_scenario(x)
  }
  # recurring mit Termin "from": Validierungsfehler mit Hinweis auf start_event
  bad <- with_comp(list(type = "recurring", category = "rent", amount_eur = 1000,
                        from = "completion"))
  err <- tryCatch(vofi_resolve(bad), error = function(e) e)
  expect_s3_class(err, "vofi_error_validation")
  expect_identical(err$key, "validation.library.ref_not_id")
  expect_identical(err$args$path, "components.r.from")
  expect_match(conditionMessage(err), "start_event", fixed = TRUE)
  expect_error(vofi_build(bad), class = "vofi_error_validation")
  v <- vofi_validate(bad, variant = "base")
  expect_true("validation.library.ref_not_id" %in% v$code)
  expect_identical(v$path[v$code == "validation.library.ref_not_id"], "components.r.from")
  # Domänenblock mit Datum bzw. Jahr unter from
  x <- unclass(sc)
  x$building <- list(n_units = 4L, maintenance = list(from = as.Date("2028-01-01")))
  err2 <- tryCatch(vofi_resolve(vofi_scenario(x)), error = function(e) e)
  expect_identical(err2$key, "validation.library.ref_not_id")
  expect_identical(err2$args$path, "building.maintenance.from")
  expect_match(conditionMessage(err2), "2028-01-01", fixed = TRUE)
  x$building$maintenance <- list(from = 2030)
  expect_error(vofi_resolve(vofi_scenario(x)), class = "vofi_error_validation")
  expect_error(scn_check_library(list(a = list(from = "prices"))),
               class = "vofi_error_validation")
  # Override mischt den Termin start_event (Map ohne from)
  ok <- with_comp(list(type = "recurring", category = "rent", amount_eur = 1000,
                       start_event = as.Date("2027-01-01")))
  sp <- vofi_resolve(ok, overrides = list(components = list(r = list(start_event = 2028))))
  expect_identical(sp$components$r$type, "recurring")
  expect_identical(sp$components$r$amount_eur, node_const(1000))
  expect_identical(sp$components$r$start_event, as.Date("2028-01-01"))
  expect_identical(vofi_resolve(ok)$components$r$start_event, as.Date("2027-01-01"))
  expect_error(vofi_resolve(ok, overrides = list(components = list(r = list(from = 2028)))),
               class = "vofi_error_validation")
})

test_that("set/overrides auf Vorlagen- und Regelfelder (R-112, Teil A XM13, P0-13)", {
  x <- unclass(example_scenario("skeleton"))
  x$building <- list(n_units = 4L)
  x$components$r <- list(type = "recurring", category = "rent", amount_eur = 1000,
                         start_event = as.Date("2027-01-01"))
  x$variants <- list(
    vorlage = list(label = "Vorlagenfeld", set = list("building.building_id" = "b2")),
    schema = list(label = "Schemafeld", overrides = list(building = list(denkmal = TRUE))),
    regel = list(label = "Regelfeld", set = list("project.tax_regime" = "wu_eg_stpfl")),
    typ = list(label = "Typparameter", set = list("components.r.growth" = 0.01,
                                                  "financing.bank.fees.processing_fee_share" =
                                                    0.01)),
    ersetzen = list(label = "replace", replace = list("building.building_id" = "b2")),
    tippfehler = list(label = "unbekannt", set = list("building.kostenfaktor" = 1.2)),
    neu = list(label = "neues Element", set = list("components.neu.amount_eur" = 1)),
    unbekannt = list(label = "Typfeld", set = list("components.r.gibt_es_nicht" = 1))
  )
  sc <- vofi_scenario(x)
  b2 <- vofi_resolve(sc, "vorlage")
  expect_identical(b2$building$building_id, "b2")
  prov <- attr(b2, "provenance")
  expect_identical(prov$layer[prov$path == "building.building_id"], 7L)
  expect_identical(prov$source_type[prov$path == "building.building_id"], "variant")
  expect_identical(vofi_resolve(sc)$building$building_id, "b1")
  expect_true(isTRUE(vofi_resolve(sc, "schema")$building$denkmal))
  rg <- vofi_resolve(sc, "regel")
  expect_identical(rg$project$tax_regime, "wu_eg_stpfl")
  prov_rg <- attr(rg, "provenance")
  expect_identical(prov_rg$source_type[prov_rg$path == "project.tax_regime"], "variant")
  ty <- vofi_resolve(sc, "typ")
  expect_identical(ty$components$r$growth, node_const(0.01))
  expect_identical(ty$financing$bank$fees$processing_fee_share, node_const(0.01))
  for (v in c("ersetzen", "tippfehler", "neu", "unbekannt")) {
    expect_error(vofi_resolve(sc, v), class = "vofi_error_validation", info = v)
  }
})

test_that("Existenzprüfung nach R-112 mit item_defaults-Vorlage einer Sammlung (XM13)", {
  local_mocked_bindings(scn_item_defaults = function() {
    list(building = list(building_id = "b1", maintenance = list(enabled = TRUE, rate = 1)),
         measures = list(cost_factor = list(ref = "project.construction_cost_factor"),
                         rent_law = list(levy = "auto")))
  })
  x <- list(measures = list(wp = list(cost_eur = 1000)), building = list(n_units = 1L))
  r <- var_apply_ops(x, list(set = list("measures.wp.cost_factor" = 1.2)), "v")
  expect_identical(r$x$measures$wp$cost_factor, 1.2)
  expect_identical(r$paths, "measures.wp.cost_factor")
  r2 <- var_apply_ops(x, list(set = list("measures.wp" = list(cost_factor = 1.2))), "v")
  expect_identical(r2$x$measures$wp, list(cost_eur = 1000, cost_factor = 1.2))
  ov <- list(measures = list(wp = list(rent_law = list(levy = "none"))))
  r3 <- var_apply_ops(x, list(overrides = ov), "v")
  expect_identical(r3$x$measures$wp$rent_law$levy, "none")
  # Teilbaum der Vorlage eines optionalen Blocks (building.maintenance entsteht mit building)
  r4 <- var_apply_ops(x, list(set = list("building.maintenance.rate" = 2)), "v")
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
    expect_error(var_apply_ops(x, ops, "v"), class = "vofi_error_validation",
                 info = names(unlist(ops)))
  }
  expect_identical(var_template_fields(x, "measures"), character(0))
  expect_setequal(var_template_fields(x, "measures.wp"), c("cost_factor", "rent_law"))
  expect_identical(var_template_fields(x, "measures.wp.cost_factor"), character(0))
})

test_that("overrides: ~ entfernt ein vorhandenes Blatt, sonst Fehler (4.11)", {
  x <- list(a = list(b = 1, c = 2))
  r <- var_apply_ops(x, list(overrides = list(a = list(b = NULL))), "v")
  expect_identical(r$x, list(a = list(c = 2)))
  expect_identical(r$paths, "a.b")
  expect_error(var_apply_ops(x, list(overrides = list(a = list(d = NULL))), "v"),
               class = "vofi_error_validation")
  expect_identical(var_override_leaves(list(a = list(b = NULL, c = list(ref = "x.y")))),
                   c("a.b", "a.c"))
})

test_that("Ableitungsregeln und item_defaults: Herkunft, optionale Blöcke nur bei Bestand", {
  sc <- example_scenario("skeleton")
  sp <- vofi_resolve(sc)
  expect_identical(length(sp$building), 0L)
  prov <- attr(sp, "provenance")
  row <- prov[prov$path == "project.tax_regime", ]
  expect_identical(row$entry, "rule:tax_regime")
  expect_identical(row$source_type, "type_default")
  expect_identical(row$layer, 0L)
  expect_identical(prov$entry[prov$path == "project.price_base_year"], "rule:price_base_year")
  expect_identical(prov$entry[prov$path == "project.legal_state"], "rule:dates")
  expect_true(is.na(prov$entry[prov$path == "accounts.deposit_rate_pa"]))
  sc2 <- vofi_scenario(utils::modifyList(unclass(sc), list(building = list(n_units = 1L))))
  sp2 <- vofi_resolve(sc2)
  expect_identical(sp2$building$building_id, "b1")
  prov2 <- attr(sp2, "provenance")
  expect_identical(prov2$entry[prov2$path == "building.building_id"],
                   "global#item_defaults.building")
  expect_identical(prov2$layer[prov2$path == "building.building_id"], 1L)
  expect_identical(prov2$layer[prov2$path == "building.n_units"], 5L)
})
