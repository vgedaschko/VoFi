# Tests für R/scenario-read.R (WS-A; Spec 00 Abschnitte 4.1, 4.4-4.6, 4.8, 4.13, 4.14).

write_lines <- function(lines, ext = ".yaml") {
  f <- tempfile(fileext = ext)
  writeLines(enc2utf8(lines), f, useBytes = TRUE)
  f
}

blocks_of <- function(sc) {
  x <- unclass(sc)
  attributes(x) <- list(names = names(x))
  x
}

#' Baum einer aufgelösten Spezifikation ohne Attribute und ohne Bibliotheksstand (dieser nennt
#' die Einträge, die in der aufgelösten Datei bereits eingesetzt sind). Die Schlüssel der Maps
#' werden sortiert (ihre Reihenfolge folgt den Schichten und ist ohne Bedeutung); die Reihenfolge
#' der ids in Sammlungen bleibt erhalten (4.4 Nr. 1).
spec_tree <- function(spec) {
  x <- blocks_of(spec)
  sort_map <- function(v, path = "") {
    if (!is.list(v) || is.data.frame(v)) return(v)
    if (!is.null(names(v))) {
      if (!(path %in% utl_merge_collections())) v <- v[order(names(v), method = "radix")]
      for (nm in names(v)) {
        if (!is.null(v[[nm]])) v[[nm]] <- sort_map(v[[nm]], path_join(path, nm))
      }
    }
    v
  }
  sort_map(x[setdiff(names(x), "library")])
}

test_that("vofi_read_scenario: Quelle, Herkunft mit Zeilennummern (Schicht 5)", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  expect_s3_class(sc, "vofi_scenario")
  src <- attr(sc, "source")
  expect_identical(src$format, "yaml")
  expect_identical(basename(src$path), "skeleton.yaml")
  expect_match(src$sha, "^[0-9a-f]{32}$")
  expect_identical(src$library_paths, vofi_library_paths())
  expect_null(src$stochastic_path)
  prov <- attr(sc, "provenance")
  expect_identical(names(prov), prv_columns())
  row <- prov[prov$path == "financing.bank.rate_pa", ]
  expect_identical(c(row$layer, row$source_type, row$file), c("5", "scenario", "skeleton.yaml"))
  expect_identical(row$location, "Zeile 10")
  expect_identical(prov$location[prov$path == "project.valuation_date"], "Zeile 5")
  expect_identical(sc$project$valuation_date, as.Date("2027-01-01"))
  expect_identical(sc$project$horizon_years, 3L)
  expect_identical(sc$components$z$values$kind, "series_t")
  expect_error(vofi_read_scenario(tempfile()), class = "vofi_error_input")
  expect_error(vofi_read_scenario(vofi_example("skeleton"), library_paths = 1),
               class = "vofi_error_input")
  ex <- expect_error(vofi_read_scenario(write_lines("a: 1", ".xlsx")),
                     class = "vofi_error_not_implemented")
  expect_match(conditionMessage(ex), "excel", fixed = TRUE)
})

test_that("Stochastik-Datei: gemischt, Herkunft Schicht 6, nur Wurzelschlüssel stochastic", {
  ov <- write_lines(c("stochastic:", "  settings:", "    seed: 42",
                      "  parameters:", "    zins:", "      target: financing.bank.rate_pa",
                      "      dist: normal", "      mean: 0.05", "      sd: 0.01"))
  sc <- vofi_read_scenario(vofi_example("skeleton"), stochastic = ov)
  expect_identical(sc$stochastic$parameters$zins$target, "financing.bank.rate_pa")
  expect_identical(sc$stochastic$settings$seed, node_const(42))
  expect_identical(attr(sc, "source")$stochastic_path,
                   normalizePath(ov, winslash = "/", mustWork = FALSE))
  prov <- attr(sc, "provenance")
  st <- prov[prov$path == "stochastic.parameters.zins.target", ]
  expect_identical(c(st$layer, st$source_type, st$file), c("6", "overlay", basename(ov)))
  expect_identical(st$location, "Zeile 6")
  e <- expect_error(vofi_read_scenario(vofi_example("skeleton"),
                                       stochastic = write_lines("x: 1")),
                    class = "vofi_error_input")
  expect_identical(e$key, "io.stochastic_root")
  extra <- write_lines(c("stochastic: {settings: {seed: 1}}", "item_defaults: {}"))
  e <- expect_error(vofi_read_scenario(vofi_example("skeleton"), stochastic = extra),
                    class = "vofi_error_validation")
  expect_identical(e$key, "io.stochastic_extra_keys")
  expect_error(vofi_read_scenario(vofi_example("skeleton"), stochastic = tempfile()),
               class = "vofi_error_input")
})

test_that("vofi_scenario: Sammlungen nach id, Kurzformen ins Overlay, idempotent (4.4-4.6)", {
  x <- list(
    schema_version = 1,
    meta = list(scenario_id = "s", title = "S"),
    project = list(perspective = "wu_privat", project_type = "sanierung_eh",
                   valuation_date = "2027-01-01", horizon_years = 3),
    measures = list(list(id = "wp", measure_type = "heizung_waermepumpe_luft", year = 2028,
                         cost_eur = list(dist = "triangular", min = 1, mode = 2, max = 4,
                                         base = 2))),
    funding = list(kfw = list(from = "funding/kfw_261_eh55", approved = 1)),
    components = list(z = list(type = "custom_series", values = c(-100, 50, 60, 70))),
    stochastic = list(settings = list(preset = "preview", n_sim = 1000, block_size = 200,
                                      band_probs = c(0.1, 0.9),
                                      convergence = list(rel_halfwidth_mean = 0.005)))
  )
  sc <- vofi_scenario(x)
  expect_identical(names(sc$measures), "wp")
  expect_identical(sc$measures$wp$year, node_const(2028))
  expect_identical(sc$measures$wp$cost_eur, node_const(2))
  ent <- sc$stochastic$parameters[["measures.wp.cost_eur"]]
  expect_identical(ent$target, "measures.wp.cost_eur")
  expect_identical(ent$dist, "triangular")
  expect_identical(ent$base, 2)
  expect_identical(sc$funding$kfw$from, "funding/kfw_261_eh55")       # Verweis bleibt Rohform
  expect_identical(sc$funding$kfw$approved, node_const(1))
  expect_identical(sc$stochastic$settings$n_sim, 1000L)
  expect_identical(sc$stochastic$settings$preset, "preview")
  expect_identical(sc$stochastic$settings$band_probs, c(0.1, 0.9))
  expect_identical(sc$stochastic$settings$convergence$rel_halfwidth_mean, 0.005)
  expect_identical(sc$schema_version, 1L)
  expect_identical(blocks_of(vofi_scenario(sc)), blocks_of(sc))
  expect_identical(attr(vofi_scenario(sc), "provenance"), attr(sc, "provenance"))
  expect_error(vofi_scenario(list(1, 2)), class = "vofi_error_input")
  expect_error(vofi_scenario(list(measures = list(1, 2))), class = "vofi_error_input")
  expect_error(vofi_scenario(list(project = 1)), class = "vofi_error_input")
  expect_error(vofi_scenario(list(stochastic = list(settings = 1))), class = "vofi_error_input")
  # Reservierte Schlüssel der Defaults-Dateien bleiben für die Validierung erhalten (4.2)
  bad <- vofi_scenario(c(x, list(item_defaults = list())))
  expect_true("item_defaults" %in% names(bad))
  v <- suppressMessages(vofi_validate(bad, variant = character(0)))
  expect_true("validation.unknown_key" %in% v$code)
})

test_that("vofi_write_scenario: Round-Trip der Eingabeform und der aufgelösten Variante (4.14)", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  f <- tempfile(fileext = ".yaml")
  expect_identical(vofi_write_scenario(sc, f), f)
  back <- vofi_read_scenario(f)
  expect_identical(blocks_of(back), blocks_of(sc))
  expect_match(readLines(f, n = 1L, encoding = "UTF-8"), "^# Szenario skeleton")
  expect_error(vofi_write_scenario(sc, f), class = "vofi_error_input")
  expect_identical(vofi_write_scenario(sc, f, overwrite = TRUE), f)
  rich <- vofi_scenario(list(
    schema_version = 1L, meta = list(scenario_id = "rich", title = "Rückweg"),
    project = list(perspective = "wu_privat", project_type = "sanierung_eh",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 3L,
                   pending_reforms = character(0)),
    market = list(a = list(series = list("2027" = 0.02, "2029" = 0.03), fill = "linear"),
                  b = list(years = c(2026, 2030), values = list(60, list(ref = "shared.c")),
                           interpolate = "step"),
                  c = list(start = 0.06, growth = list(ref = "market.a"), index = "period_end"),
                  d = list(expr = "market.a * 2"),
                  e = list(ref = "market.a", anchor = 0.01, floor = 0)),
    shared = list(c = 100),
    components = list(z = list(type = "custom_series", values = c(-1, 2, 3, 4))),
    financing = list(ek = list(type = "equity", amount_eur = 1)),
    variants = list(v = list(label = "V", set = list("market.d" = list(expr = "market.a * 3")))),
    stochastic = list(parameters = list(k = list(target = "market.e", dist = "normal",
                                                 mean = 0, sd = 1)))
  ))
  f2 <- tempfile(fileext = ".yaml")
  vofi_write_scenario(rich, f2)
  expect_identical(blocks_of(vofi_read_scenario(f2)), blocks_of(rich))
  # aufgelöste Variante: Defaults gemischt, ohne Varianten, erneut einlesbar
  f3 <- tempfile(fileext = ".yaml")
  suppressMessages(vofi_write_scenario(sc, f3, resolved = TRUE))
  rs <- vofi_read_scenario(f3)
  expect_identical(rs$accounts$penalty_spread_pa, node_const(0.02))
  expect_null(rs$project$tax_regime)                    # rule:tax_regime entsteht erneut
  expect_identical(spec_tree(ws_a_quiet(vofi_resolve(rs)))$project$tax_regime, "wu_kapges")
  expect_identical(spec_tree(ws_a_quiet(vofi_resolve(rs))), spec_tree(ws_a_quiet(vofi_resolve(sc))))
  expect_length(rs$variants, 0L)
  r1 <- suppressMessages(vofi_run(vofi_build(sc)))$kpis$terminal_value
  r2 <- suppressMessages(vofi_run(vofi_build(rs)))$kpis$terminal_value
  expect_identical(r2, r1)
  expect_error(vofi_write_scenario(sc, tempfile(fileext = ".xlsx")),
               class = "vofi_error_not_implemented")
  expect_error(vofi_write_scenario(list(), f), class = "vofi_error_input")
  expect_error(vofi_write_scenario(sc, 1), class = "vofi_error_input")
  expect_error(vofi_write_scenario(sc, f, resolved = NA), class = "vofi_error_input")
  expect_error(vofi_write_scenario(sc, f, overwrite = "ja"), class = "vofi_error_input")
})

test_that("A-05: aufgelöste Variante ist erneut einlesbar und ergibt dieselbe Spezifikation", {
  local_ws_a_library()
  plan_ps <- list(schedule = list("2028-07-01" = 1000,
                                  "2029-07-01" = list(value = 10, per = "m2_living_area")),
                  unit = "eur")
  sc <- vofi_scenario(ws_a_scenario(
    building = list(construction_year = 1972L, land_area_m2 = 500, land_value_eur_m2 = 300),
    unit_groups = list(a = list(n_units = 10, living_area_m2 = 1000),
                       b = list(n_units = 4, living_area_m2 = 300, rent_regime = "bound_social")),
    measures = list(
      wp = list(measure_type = "heizung_waermepumpe_luft", year = 2028, cost_eur = 126000),
      huelle = list(measure_type = "daemmung_fassade", year = 2029,
                    cost_kg = list(kg300 = 200000, kg400 = 50000)),
      plan = list(measure_type = "aussenanlagen", payment_schedule = plan_ps)
    ),
    energy = list(carriers = list(gas = list(), power = list())),
    funding = list(f35 = list(from = "funding/estg_35c", measures = "wp")),
    variants = list(v = list(set = list("measures.wp.cost_factor" = 1.1)))
  ))
  for (variant in c("base", "v")) {
    f <- tempfile(fileext = ".yaml")
    ws_a_quiet(vofi_write_scenario(sc, f, resolved = TRUE, variant = variant))
    rs <- ws_a_quiet(vofi_read_scenario(f))
    # abgeleitete Blätter fehlen in der Datei (Regeln, item_defaults, Typ-Defaults)
    expect_null(rs$building$n_units)
    expect_null(rs$building$maintenance$start_event)
    expect_null(rs$building$first_occupancy_year)
    expect_null(rs$measures$wp$kg)
    expect_null(rs$measures$plan$cost_eur)
    expect_null(rs$energy$carriers$gas$price_eur_kwh)
    expect_identical(rs$funding$f35$instrument_type, "tax_credit")      # Bibliothek eingesetzt
    a <- spec_tree(ws_a_resolve(sc, variant = variant))
    b <- spec_tree(ws_a_resolve(rs))
    b$variant <- a$variant
    expect_identical(b, a, info = variant)
  }
  expect_identical(attr(ws_a_resolve(sc), "scn_state")$derived[1L], "project.tax_regime")
  expect_identical(scn_drop_paths(list(a = list(b = list(c = 1)), d = 2), c("a.b.c", "x.y")),
                   list(a = list(b = structure(list(), names = character(0))), d = 2))
})

test_that("A-03: verschachtelte Sammlungen in Listenform werden Maps nach id (4.4 Nr. 1)", {
  local_ws_a_library()
  f <- write_lines(c(
    "schema_version: 1", "meta: {scenario_id: lf, title: Listenform}",
    "project: {perspective: wu_privat, project_type: sanierung_eh, valuation_date: 2027-01-01}",
    "building:", "  construction_year: 1972", "  living_area_m2: 800", "  elements:",
    "    - id: kessel", "      measure_type: heizung_gaskessel", "      installed_year: 2005",
    "energy:", "  carriers:", "    - id: gas", "    - {id: power, price_eur_kwh: 0.3}",
    "  stages:", "    - {id: zwischen, demand_kwh: 1000}",
    "components: {z: {type: custom_series, values: [-100, 50, 60]}}",
    "financing: {ek: {type: equity, amount_eur: 100}}",
    "analysis: {kpis: [terminal_value]}"
  ))
  sc <- vofi_read_scenario(f)
  expect_identical(names(sc$energy$carriers), c("gas", "power"))
  expect_identical(names(sc$building$elements), "kessel")
  expect_identical(names(sc$energy$stages), "zwischen")
  expect_identical(sc$energy$carriers$power$price_eur_kwh, node_const(0.3))
  spec <- ws_a_resolve(sc)
  gas <- spec$energy$carriers$gas
  expect_identical(gas$price_eur_kwh, node_ref("market.energy_price.gas"))
  expect_identical(gas$class, "gas")
  expect_identical(gas$network_fee_eur_kwh, node_ref("market.energy_network_fee.gas"))
  expect_identical(spec$energy$carriers$power$price_eur_kwh, node_const(0.3))
  expect_identical(spec$building$elements$kessel$active, node_const(1))
  expect_identical(ws_a_prov(spec, "building.elements.kessel.active")$entry,
                   "global#item_defaults.building.elements")
  expect_error(vofi_scenario(list(energy = list(carriers = list(list(price_eur_kwh = 1))))),
               class = "vofi_error_input")
})

test_that("Beispiele und Hilfen (vofi_example, scn_to_yaml)", {
  expect_true("skeleton" %in% vofi_example())
  expect_true(file.exists(vofi_example("skeleton")))
  e <- expect_error(vofi_example("skeletn"), class = "vofi_error_input")
  expect_match(conditionMessage(e), "skeleton", fixed = TRUE)
  y <- scn_to_yaml(list(a = node_const(1), b = NULL, c = list(), d = list(e = node_ref("x.y"))))
  expect_identical(y, list(a = 1, d = list(e = list(ref = "x.y"))))
  expect_null(scn_optional_fun("gibt_es_nicht"))
  expect_true(is.function(scn_optional_fun("vofi_resolve")))
})
