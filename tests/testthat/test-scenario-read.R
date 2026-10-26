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
  e <- expect_error(vofi_read_scenario(vofi_example("skeleton"), stochastic = write_lines(
    c("stochastic: {settings: {seed: 1}}", "item_defaults: {}"))), class = "vofi_error_validation")
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
                  d = list(expr = "market.a * 2"), e = list(ref = "market.a", anchor = 0.01,
                                                           floor = 0)),
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
  expect_identical(rs$project$tax_regime, "wu_kapges")
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
