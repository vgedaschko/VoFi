# Tests für R/scenario-variants.R und R/scenario-layers.R (WS-A; Spec 00 Abschnitte 4.7, 4.11).
# Phase-0-Minimalfassung.

variant_scenario <- function() {
  sc <- example_scenario("skeleton")
  sc$variants <- list(
    teuer = list(label = "Teurer", set = list("components.z.values" = c(-120000, 30000, 40000,
                                                                        50000))),
    mehr = list(label = "Mehr Miete", extends = "teuer",
                add = list("components.miete" = list(type = "recurring", category = "rent",
                                                     amount_eur = 6000, from = "2027-01-01")),
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
  comp <- list(components = list(r = list(type = "recurring", from = "2027-01-01")))
  m2 <- scn_merge(comp, list(components = list(r = list(from = "2028-01-01"))))
  expect_identical(m2$components$r$type, "recurring")
  expect_false(scn_is_library_ref(list(from = "2027-01-01", to = "2030-01-01")))
  expect_true(scn_is_library_ref(list(from = "prices/co2_2026", use = "mittel")))
  expect_error(scn_check_library(list(market = list(co2 = list(from = "prices/co2")))),
               class = "vofi_error_not_implemented")
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
