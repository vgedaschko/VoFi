# Tests für R/schema.R (WS-B; Parameter-DSL Spec 00 Abschnitt 5.4, Feldkatalog Spec 01,
# JSON-Schema Memo 05 4.11).

test_that("vofi_param: artabhängige Defaults und Sperren", {
  r <- vofi_param("rate", required = TRUE, unit = "rate_pa")
  expect_s3_class(r, "vofi_param")
  expect_identical(c(r$min, r$max), c(-0.1, 1))
  expect_identical(r$shapes, "scalar")
  expect_true(r$stochastic)
  expect_false(r$deterministic_only)
  s <- vofi_param("share")
  expect_identical(c(s$min, s$max), c(0, 1))
  a <- vofi_param("amount", allow_auto = TRUE)
  expect_identical(a$min, -Inf)
  expect_identical(vofi_param("value")$shapes, c("scalar", "path"))
  expect_identical(vofi_param("schedule")$shapes, "path")
  e <- vofi_param("enum", values = "vocab:refi_rule", default = "keep_term")
  expect_true(e$deterministic_only)
  expect_false(e$stochastic)
  expect_true(is.na(vofi_param("map", fields = list(a = vofi_param("number")))$stochastic))
  x <- vofi_param("number", min = 0, excl_min = TRUE, warn = c(5, 80), unit = "years")
  expect_identical(x$extra, list(excl_min = TRUE, warn = c(5, 80)))
  expect_identical(vofi_param("number", stochastic = FALSE)$stochastic, FALSE)
})

test_that("vofi_param: Fehler der Parameterbeschreibung", {
  cls <- "vofi_error_registry"
  expect_error(vofi_param("zahl"), class = cls)
  expect_error(vofi_param(1), class = cls)
  expect_error(vofi_param("number", required = NA), class = cls)
  expect_error(vofi_param("number", allow_auto = "ja"), class = cls)
  expect_error(vofi_param("number", allow_auto = TRUE), class = cls)
  expect_error(vofi_param("number", deterministic_only = 1), class = cls)
  expect_error(vofi_param("number", min = "0"), class = cls)
  expect_error(vofi_param("number", min = 2, max = 1), class = cls)
  expect_error(vofi_param("number", shapes = "matrix"), class = cls)
  expect_error(vofi_param("number", stochastic = c(TRUE, FALSE)), class = cls)
  expect_error(vofi_param("enum"), class = cls)
  expect_error(vofi_param("number", values = "a"), class = cls)
  expect_error(vofi_param("map"), class = cls)
  expect_error(vofi_param("map", fields = list(a = 1)), class = cls)
  expect_error(vofi_param("number", fields = list(a = vofi_param("number"))), class = cls)
  expect_error(vofi_param("number", unit = "furlong"), class = cls)
})

test_that("Codes und Aliase eines enum-Parameters", {
  p <- vofi_param("enum", values = "vocab:refi_rule")
  expect_identical(utl_param_codes(p), vocab_codes("vocab:refi_rule"))
  expect_identical(utl_param_codes(vofi_param("enum", values = c("a", "b"))), c("a", "b"))
  expect_identical(val_param_aliases(vofi_param("enum", values = c("a", "b"))), character(0))
  pt <- vofi_param("enum", values = "vocab:project_types")
  expect_type(val_param_aliases(pt), "character")
})

test_that("Feldkatalog: Blöcke, Sammlungen und Sicht ohne Sammlungselemente", {
  cat <- val_schema_catalog()
  expect_true(all(c("meta", "project", "grid", "building", "household", "unit_groups",
                    "measures", "energy", "funding", "accounts", "residual_value", "tax",
                    "analysis", "stochastic.settings", "stochastic.parameters",
                    "stochastic.processes", "variants", "scenario_sets",
                    "building.elements", "energy.carriers", "energy.stages") %in% names(cat)))
  expect_true(all(vapply(unlist(cat, recursive = FALSE), inherits, logical(1), "vofi_param")))
  view <- val_domain_schema()
  expect_false(any(c(val_schema_collections(), "variants", "scenario_sets",
                     "stochastic.parameters") %in% names(view)))
  expect_true(all(c("project", "accounts", "stochastic.settings") %in% names(view)))
  expect_true("cost_eur" %in% names(val_domain_schema("measures")))
  expect_identical(val_domain_schema("gibt_es_nicht"), list())
  # freie Maps und Sequenzen sind aus der Sicht entfernt
  strip <- val_schema_strip(list(a = vofi_param("map", free = TRUE,
                                                fields = list(.key = vofi_param("number"))),
                                 b = vofi_param("number"),
                                 c = vofi_param("map", fields = list(
                                   d = vofi_param("map", sequence = TRUE,
                                                  fields = list(e = vofi_param("number")))))))
  expect_identical(names(strip), "b")
  # Grenzen aus Spec 01 (Auszug)
  hz <- cat$project$horizon_years
  expect_identical(hz$max, 100L)
  expect_identical(hz$extra[["warn"]], c(10, 60))
  expect_true(800 %in% cat$measures$kg$extra[["allowed"]])
})

test_that("val_param_at: Domänenfelder, Sammlungen, Typparameter, Stochastik", {
  spec <- vofi_resolve(wsb_with("domain"))
  expect_identical(val_param_at(spec, "project.horizon_years")$kind, "integer")
  expect_identical(val_param_at(spec, "measures.huelle.cost_eur")$kind,
                   val_schema_catalog()$measures$cost_eur$kind)
  expect_identical(val_param_at(spec, "unit_groups.a.vacancy_rate")$kind, "value")
  expect_s3_class(val_param_at(spec, "accounts.deposit_rate_pa"), "vofi_param")
  expect_s3_class(val_param_at(spec, "financing.bank.rate_pa"), "vofi_param")
  expect_null(val_param_at(spec, "financing.bank"))
  expect_null(val_param_at(spec, "financing.fehlt.rate_pa"))
  expect_null(val_param_at(spec, "market.x"))
  expect_null(val_param_at(spec, ""))
  expect_null(val_param_at(spec, "project.horizon_years.x"))
  expect_s3_class(val_param_at(spec, "stochastic.settings.n_sim"), "vofi_param")
  expect_s3_class(val_param_at(spec, "stochastic.parameters.k1.target"), "vofi_param")
  expect_s3_class(val_param_at(spec, "building.elements.dach.installed_year"), "vofi_param")
  expect_s3_class(val_param_at(spec, "energy.carriers.gas.class"), "vofi_param")
})

test_that("vofi_json_schema: Zeichenkette, Datei, Argumentprüfung", {
  skip_if_not_installed("jsonlite")
  txt <- vofi_json_schema()
  expect_type(txt, "character")
  expect_identical(length(txt), 1L)
  s <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
  expect_identical(s[["$schema"]], "https://json-schema.org/draft/2020-12/schema")
  expect_identical(unlist(s$required), c("schema_version", "meta", "project"))
  expect_false(s$additionalProperties)
  expect_true(all(c("project", "measures", "components", "financing", "stochastic",
                    "variants", "scenario_sets") %in% names(s$properties)))
  expect_true(all(c("value", "timing", "library_ref") %in% names(s[["$defs"]])))
  comp <- s$properties$components$additionalProperties$oneOf
  types <- vapply(comp, function(o) o$properties$type$const, "")
  expect_true(all(reg_list("flow")$name %in% types))
  expect_false(is.unsorted(types, strictly = TRUE))
  f <- withr::local_tempfile(fileext = ".json")
  expect_identical(vofi_json_schema(f), f)
  # Byte-Vergleich: die Datei ist UTF-8 unabhaengig von der Locale (readChar() liefert unter
  # LANG=C eine unmarkierte Zeichenkette, die sich von der UTF-8-markierten nicht identisch zeigt)
  expect_identical(readBin(f, "raw", file.size(f)), charToRaw(enc2utf8(txt)))
  expect_error(vofi_json_schema(1), class = "vofi_error_input")
  expect_error(vofi_json_schema(c("a", "b")), class = "vofi_error_input")
})

test_that("Ausgeliefertes JSON-Schema passt zum Katalog (data-raw/build_schema.R)", {
  skip_if_not_installed("jsonlite")
  shipped_file <- system.file("schema", "vofi-scenario.schema.json", package = "vofi")
  expect_true(nzchar(shipped_file))
  shipped <- jsonlite::fromJSON(shipped_file, simplifyVector = FALSE)
  gen <- jsonlite::fromJSON(vofi_json_schema(), simplifyVector = FALSE)
  # Blöcke und Domänenfelder sind registry-unabhängig; Typen der Registry können nach der
  # Integration weiterer Arbeitspakete hinzukommen (Schema dann neu erzeugen).
  expect_identical(names(shipped$properties), names(gen$properties))
  for (b in c("project", "accounts", "measures", "unit_groups", "funding", "analysis")) {
    expect_identical(shipped$properties[[b]], gen$properties[[b]], info = b)
  }
  expect_identical(shipped[["$defs"]], gen[["$defs"]])
})

test_that("M2: JSON-Schema nach Metaschema Draft 2020-12 (enum und required als Array)", {
  skip_if_not_installed("jsonlite")
  s <- jsonlite::fromJSON(vofi_json_schema(), simplifyVector = FALSE)
  bad <- character(0)
  walk <- function(x, path) {
    if (!is.list(x)) return(invisible(NULL))
    nms <- names(x) %||% rep("", length(x))
    for (i in seq_along(x)) {
      k <- nms[i]
      if (k %in% c("enum", "required") && !(is.list(x[[i]]) && is.null(names(x[[i]])))) {
        bad <<- c(bad, paste0(path, "/", k))
      }
      walk(x[[i]], paste0(path, "/", if (nzchar(k)) k else i))
    }
  }
  walk(s, "")
  expect_identical(bad, character(0))
  # Zahlenliste band_probs, beliebiger Wert bei mandatory_sensitivities.value
  st <- s$properties$stochastic$properties$settings$properties
  expect_identical(st$band_probs$anyOf[[1L]]$type, "array")
  # Prüfung gegen das Metaschema und Gültigkeit des Gerüsts, sofern python3 mit jsonschema
  # und yaml verfügbar ist
  py <- Sys.which("python3")
  skip_if(!nzchar(py), "python3 fehlt")
  ok <- suppressWarnings(system2(py, c("-I", "-c", shQuote("import jsonschema, yaml")),
                                 stdout = FALSE, stderr = FALSE))
  skip_if(!identical(ok, 0L), "python3 ohne jsonschema bzw. yaml")
  f <- withr::local_tempfile(fileext = ".json")
  vofi_json_schema(f)
  code <- paste(
    "import json, sys, yaml, datetime, jsonschema",
    "s = json.load(open(sys.argv[1], encoding='utf-8'))",
    "jsonschema.Draft202012Validator.check_schema(s)",
    "def conv(x):",
    "    if isinstance(x, dict): return {str(k): conv(v) for k, v in x.items()}",
    "    if isinstance(x, list): return [conv(v) for v in x]",
    "    if isinstance(x, (datetime.date, datetime.datetime)): return x.isoformat()",
    "    return x",
    "y = conv(yaml.safe_load(open(sys.argv[2], encoding='utf-8')))",
    "e = list(jsonschema.Draft202012Validator(s).iter_errors(y))",
    "print('ok' if not e else e[0].message)", sep = "\n")
  # Gerüst und Orakel (a) sind gültig nach dem Schema (YAML ~ entfernt ein Blatt: null zulässig)
  for (sc in c(vofi_example("skeleton"), test_path("fixtures", "scenarios", "oracle_a.yaml"))) {
    out <- system2(py, c("-I", "-c", shQuote(code), shQuote(f), shQuote(sc)),
                   stdout = TRUE, stderr = TRUE)
    expect_identical(out, "ok", info = sc)
  }
})
