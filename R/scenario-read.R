# Szenario einlesen und schreiben (WS-A, Spec 00 Abschnitte 4.1, 4.4, 4.6, 4.8, 4.13).
# vofi_read_scenario() fuer YAML (inkl. separater Stochastik-Datei, Zeilennummern in der
# Herkunft; Excel ueber io_read_excel() von WS-A2, sobald vorhanden), vofi_scenario() mit
# Normalisierung aller Bloecke (Listen mit id -> Maps, Domaenenfelder nach dem Schema aus
# R/schema.R, Typparameter nach der Registry, uebrige numerische Blaetter als Knoten,
# Kurzform-Verteilungen ins Overlay), Herkunft der Schichten 5 und 6, vofi_write_scenario()
# (YAML; aufgeloeste Variante auf Wunsch), vofi_example().

#' Szenario einlesen
#'
#' Liest ein Szenario aus YAML oder Excel, normalisiert es (Wertgrammatik, Einheiten, Aliase) und
#' liefert das kanonische Szenario-Objekt mit Herkunft der Blätter (Spec 00, Abschnitte 4.1,
#' 4.6, 4.8). YAML wird UTF-8-sicher gelesen (auch unter der Locale `C`); mehrdeutige Zahlen
#' (Dezimalkomma, Tausenderpunkt) werden nach 4.6 gemeldet bzw. abgewiesen. Optional wird ein
#' separates Stochastik-Overlay (Wurzelschlüssel `stochastic`) über den Block der Szenariodatei
#' gemischt (Datei gewinnt; Herkunft Schicht 6).
#'
#' Bibliotheksverweise `from:` bleiben im Szenario unaufgelöst; `vofi_resolve()` löst sie mit
#' den hier übergebenen Bibliothekspfaden auf.
#'
#' @param path Pfad der Szenariodatei (`.yaml`/`.yml` oder `.xlsx`).
#' @param format `"auto"` (nach Dateiendung), `"yaml"` oder `"excel"`.
#' @param stochastic optional: Pfad einer YAML-Datei mit Wurzelschlüssel `stochastic`.
#' @param library_paths Bibliothekswurzeln (Paketbibliothek und Nutzerbibliotheken; später
#'   gewinnt).
#' @return Objekt der Klasse `vofi_scenario`.
#' @family Einlesen
#' @examples
#' sc <- vofi_read_scenario(vofi_example("skeleton"))
#' sc$meta$scenario_id
#' head(attr(sc, "provenance")[, c("path", "layer", "location")])
#' @export
vofi_read_scenario <- function(path, format = c("auto", "yaml", "excel"), stochastic = NULL,
                               library_paths = vofi_library_paths()) {
  format <- utl_match_arg(format, c("auto", "yaml", "excel"), "format")
  if (!utl_is_string(path) || !file.exists(path)) {
    vofi_abort("core.file_missing", path = as.character(path %||% "NULL")[1L],
               .class = "vofi_error_input")
  }
  if (!is.character(library_paths)) {
    vofi_abort("core.arg_character", arg = "library_paths", .class = "vofi_error_input")
  }
  if (format == "auto") {
    ext <- tolower(tools::file_ext(path))
    format <- if (ext %in% c("xlsx", "xls")) "excel" else "yaml"
  }
  norm_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  locations <- character(0)
  if (format == "excel") {
    reader <- scn_optional_fun("io_read_excel")
    if (is.null(reader)) scn_unsupported("vofi_read_scenario(format = \"excel\")")
    raw <- reader(path)
    locations <- attr(raw, "locations") %||% character(0)
  } else {
    txt <- io_read_lines_utf8(path)
    raw <- io_parse_yaml_text(txt, path)
    locations <- io_yaml_locations(txt)
  }
  stoch_path <- NULL
  stoch_locations <- character(0)
  if (!is.null(stochastic)) {
    if (!utl_is_string(stochastic) || !file.exists(stochastic)) {
      vofi_abort("core.file_missing", path = as.character(stochastic %||% "NULL")[1L],
                 .class = "vofi_error_input")
    }
    stxt <- io_read_lines_utf8(stochastic)
    ov <- io_parse_yaml_text(stxt, stochastic)
    if (!is_map(ov) || is.null(ov[["stochastic"]])) {
      vofi_abort("io.stochastic_root", path = stochastic, .class = "vofi_error_input")
    }
    extra <- setdiff(names(ov), "stochastic")
    if (length(extra) > 0L) {
      vofi_abort("io.stochastic_extra_keys", path = stochastic, keys = utl_collapse(extra),
                 .class = "vofi_error_validation")
    }
    raw$stochastic <- deep_merge(raw$stochastic %||% list(), ov$stochastic)
    stoch_path <- normalizePath(stochastic, winslash = "/", mustWork = FALSE)
    stoch_locations <- io_yaml_locations(stxt)
  }
  vofi_scenario(raw, source = list(
    path = norm_path, format = format, read_time = Sys.time(),
    sha = stable_hash_file(path), stochastic_path = stoch_path,
    library_paths = library_paths, locations = locations,
    stochastic_locations = stoch_locations
  ))
}

#' Szenario schreiben
#'
#' Schreibt ein Szenario als YAML (bzw. Excel über WS-A2), auf Wunsch die aufgelöste Variante:
#' Schichten 1–8 gemischt (Defaults-Dateien, Profil, Bibliotheksverweise aufgelöst, Szenario,
#' Overlay, Variante, Szenario-Set, Overrides). Was beim Auflösen nach Schicht 8 entsteht, entfällt,
#' weil es beim erneuten Auflösen wieder entsteht: Werte der Ableitungsregeln (`rule:*`), der
#' Vorlagen `item_defaults`, der Typ-Defaults (Schicht 0) und die Expander-Komponenten. Knoten
#' werden in die Wertgrammatik zurückgeführt. Das erneute Einlesen ergibt dieselbe kanonische
#' Liste; bei `resolved = TRUE` ergibt das erneute Auflösen dieselbe Spezifikation (Round-Trip,
#' Spec 00, Abschnitte 4.6, 4.14).
#'
#' @param scenario Objekt der Klasse `vofi_scenario`.
#' @param path Zieldatei.
#' @param format `"auto"` (nach Dateiendung), `"yaml"` oder `"excel"`.
#' @param resolved aufgelöste Variante (Schichten gemischt) statt der Eingabeform schreiben.
#' @param variant Variante, die bei `resolved = TRUE` geschrieben wird.
#' @param overwrite vorhandene Datei überschreiben.
#' @return `invisible(path)`.
#' @family Einlesen
#' @examples
#' sc <- vofi_read_scenario(vofi_example("skeleton"))
#' f <- tempfile(fileext = ".yaml")
#' vofi_write_scenario(sc, f)
#' identical(vofi_read_scenario(f)$components, sc$components)
#' @export
vofi_write_scenario <- function(scenario, path, format = c("auto", "yaml", "excel"),
                                resolved = FALSE, variant = "base", overwrite = FALSE) {
  if (!inherits(scenario, "vofi_scenario")) {
    vofi_abort("io.not_scenario", arg = "scenario", .class = "vofi_error_input")
  }
  if (!utl_is_string(path)) {
    vofi_abort("core.arg_scalar", arg = "path", .class = "vofi_error_input")
  }
  if (!utl_is_flag(resolved)) {
    vofi_abort("core.arg_scalar", arg = "resolved", .class = "vofi_error_input")
  }
  if (!utl_is_flag(overwrite)) {
    vofi_abort("core.arg_scalar", arg = "overwrite", .class = "vofi_error_input")
  }
  format <- utl_match_arg(format, c("auto", "yaml", "excel"), "format")
  if (format == "auto") {
    format <- if (tolower(tools::file_ext(path)) %in% c("xlsx", "xls")) "excel" else "yaml"
  }
  if (file.exists(path) && !overwrite) {
    vofi_abort("io.file_exists", path = path, .class = "vofi_error_input")
  }
  x <- if (resolved) scn_resolved_tree(scenario, variant) else scn_input_tree(scenario)
  if (format == "excel") {
    writer <- scn_optional_fun("io_write_excel")
    if (is.null(writer)) scn_unsupported("vofi_write_scenario(format = \"excel\")")
    writer(x, path)
    return(invisible(path))
  }
  header <- lbl("io.write_header", id = as.character(x$meta$scenario_id %||% "")[1L],
                variant = if (resolved) variant else "-")
  io_write_yaml(scn_to_yaml(x), path, header = header)
  invisible(path)
}

#' Eingabeform eines Szenarios (Blöcke ohne Attribute)
#' @noRd
scn_input_tree <- function(scenario) {
  x <- unclass(scenario)
  attr(x, "source") <- NULL
  attr(x, "provenance") <- NULL
  x
}

#' Aufgelöste Variante als Szenario-Baum
#'
#' Ohne Register, Rechtsstand, Expander-Komponenten und ohne die abgeleiteten Blätter
#' (`attr(spec, "scn_state")$derived`: Ableitungsregeln, `item_defaults`, Typ-Defaults). Maps,
#' die dadurch leer werden, bleiben als leere Maps stehen: Ein leeres Element einer Sammlung
#' (z. B. `energy.carriers.gas: {}`) ist eine Angabe des Szenarios, und Vorlagen wie
#' Ableitungsregeln behandeln eine leere Map wie eine fehlende.
#' @noRd
scn_resolved_tree <- function(scenario, variant) {
  spec <- vofi_resolve(scenario, variant = variant)
  derived <- attr(spec, "scn_state")$derived %||% character(0)
  x <- unclass(spec)
  attributes(x) <- list(names = names(x))
  x <- x[intersect(c("schema_version", utl_scenario_blocks()), names(x))]
  x$schema_version <- 1L
  for (coll in c("components", "financing")) {
    keep <- vapply(x[[coll]] %||% list(), function(c0) !identical(c0$origin, "expander"),
                   logical(1))
    x[[coll]] <- x[[coll]][keep]
  }
  x <- scn_drop_paths(x, derived)
  x$variants <- list()
  x$scenario_sets <- list()
  x
}

#' Pfade entfernen (nicht vorhandene Pfade bleiben ohne Wirkung)
#' @param x Liste.
#' @param paths Pfade.
#' @return `x`.
#' @noRd
scn_drop_paths <- function(x, paths) {
  for (p in unique(paths)) x <- path_remove(x, p)
  x
}

#' Szenario-Baum in YAML-Form (Knoten zurückgeführt, NULL und leere Blöcke entfallen)
#' @noRd
scn_to_yaml <- function(x, top = TRUE) {
  if (node_is(x)) return(node_to_yaml(x))
  if (!is.list(x) || is.data.frame(x)) return(x)
  if (length(x) == 0L) return(x)
  out <- lapply(x, function(e) scn_to_yaml(e, top = FALSE))
  if (!is.null(names(x))) {
    keep <- !vapply(out, is.null, logical(1))
    if (top) keep <- keep & !vapply(out, function(e) is.list(e) && length(e) == 0L, logical(1))
    out <- out[keep]
  }
  out
}

#' Optionale Funktion eines anderen Pakets im Namensraum (z. B. Excel von WS-A2)
#' @noRd
scn_optional_fun <- function(name) {
  f <- get0(name, envir = asNamespace("vofi"), mode = "function", inherits = FALSE)
  if (is.function(f)) f else NULL
}

#' Kanonisches Szenario aus einer R-Liste
#'
#' Erzeugt ein kanonisches, normalisiertes Szenario aus einer R-Liste in YAML-Form (Datumswerte
#' als `Date` oder ISO-Zeichenkette, Zahlen, Wertformen der Wertgrammatik). Die Normalisierung
#' ist idempotent: ein bereits normalisiertes Szenario bleibt unverändert.
#'
#' Sammlungen (`unit_groups`, `measures`, `funding`, `components`, `financing`, `variants`,
#' `scenario_sets`, `building.elements`, `energy.carriers`, `energy.stages`) dürfen als Listen
#' mit Feld `id` angegeben werden und werden Maps nach id.
#' Felder mit Schema (Spec 00, Abschnitt 4.3; Typparameter der Registry) werden nach ihrer Art
#' normalisiert, übrige numerische Blätter und Wertformen werden Knoten. Kurzform-Verteilungen
#' wandern ins Overlay (Schlüssel = Zielpfad), am Ort bleibt der Basiswert.
#'
#' @param x Liste mit den Blöcken der obersten Ebene (Spec 00, Abschnitt 4.2).
#' @param source optional: Herkunftsangaben (`path`, `format`, `library_paths`, ...).
#' @return Objekt der Klasse `vofi_scenario`.
#' @family Einlesen
#' @examples
#' sc <- vofi_scenario(list(
#'   schema_version = 1L,
#'   meta = list(scenario_id = "mini", title = "Mini"),
#'   project = list(perspective = "wu_privat", project_type = "neubau",
#'                  valuation_date = as.Date("2027-01-01"), horizon_years = 2L),
#'   components = list(z = list(type = "custom_series", values = c(-100, 50, 60))),
#'   financing = list(ek = list(type = "equity", amount_eur = 100))
#' ))
#' sc$components$z$values
#' @export
vofi_scenario <- function(x, source = NULL) {
  old_source <- NULL
  old_prov <- NULL
  if (inherits(x, "vofi_scenario")) {
    old_source <- attr(x, "source")
    old_prov <- attr(x, "provenance")
    x <- unclass(x)
    attr(x, "source") <- NULL
    attr(x, "provenance") <- NULL
  }
  if (!is_map(x)) {
    vofi_abort("io.scenario_not_map", .class = "vofi_error_input")
  }
  x <- scn_normalize(x)
  src <- source %||% old_source %||% list(path = NA_character_, format = "list",
                                          read_time = Sys.time(), sha = stable_hash(x),
                                          stochastic_path = NULL)
  file <- if (utl_is_string(src$path)) basename(src$path) else NA_character_
  prov <- if (is.null(source) && !is.null(old_prov)) {
    old_prov
  } else {
    scn_scenario_provenance(x, src, file)
  }
  new_vofi_scenario(x, source = src, provenance = prov)
}

#' Herkunft eines eingelesenen Szenarios (Schicht 5; Overlay Schicht 6 mit eigener Datei)
#' @noRd
scn_scenario_provenance <- function(x, src, file) {
  top <- setdiff(names(x), c("variants", "scenario_sets"))
  tree <- x[top]
  st_file <- if (utl_is_string(src$stochastic_path)) basename(src$stochastic_path) else file
  prov <- scn_provenance(tree, layer = c(stochastic = 6L), source_type = c(stochastic = "overlay"),
                         file = file, files = c(stochastic = st_file),
                         locations = src$locations)
  if (length(src$stochastic_locations) > 0L && nrow(prov) > 0L) {
    st <- startsWith(prov$path, "stochastic.")
    prov$location[st] <- vapply(prov$path[st], function(p) {
      io_location_of(src$stochastic_locations, p)
    }, "", USE.NAMES = FALSE)
  }
  prov
}

#' Mitgelieferte Beispielszenarien
#'
#' Liefert den Pfad eines mitgelieferten Beispielszenarios bzw. die Namen aller Beispiele.
#'
#' @param name Name des Beispiels (z. B. `"skeleton"`) oder `NULL`.
#' @return Zeichenkette (Pfad) bzw. Zeichenvektor der Namen.
#' @family Einlesen
#' @examples
#' vofi_example()
#' vofi_example("skeleton")
#' @export
vofi_example <- function(name = NULL) {
  dir <- system.file("extdata", "examples", package = "vofi")
  files <- list.files(dir, pattern = "\\.(ya?ml|xlsx)$")
  names_all <- utl_sort(unique(sub("\\.(ya?ml|xlsx)$", "", files)))
  if (is.null(name)) return(names_all)
  if (!utl_is_string(name) || !(name %in% names_all)) {
    vofi_abort("io.example_unknown", name = utl_collapse(format(name)),
               suggestion = utl_suggest_text(as.character(name)[1L], names_all),
               .class = "vofi_error_input")
  }
  hit <- files[sub("\\.(ya?ml|xlsx)$", "", files) == name]
  file.path(dir, hit[order(!grepl("\\.ya?ml$", hit))][1L])
}

#' Funktion bzw. Eingabeform ist noch nicht verfügbar (Lieferung eines anderen Pakets)
#' @noRd
scn_unsupported <- function(what) {
  vofi_abort("core.not_implemented", fun = what, .class = "vofi_error_not_implemented")
}

# ---------------------------------------------------------------------------------------------
# Normalisierung (4.4, 4.5, 4.6)
# ---------------------------------------------------------------------------------------------

#' Oberste Sammlungen nach id (4.4 Nr. 1); verschachtelte: `scn_nested_collections()`
#' @noRd
scn_collections <- function() {
  c("unit_groups", "measures", "funding", "components", "financing", "variants",
    "scenario_sets")
}

#' Verschachtelte Sammlungen nach id (4.4 Nr. 1; `utl_merge_collections()`)
#' @noRd
scn_nested_collections <- function() {
  grep(".", utl_merge_collections(), fixed = TRUE, value = TRUE)
}

#' Liste mit Feld `id` in eine Map nach id umwandeln (Reihenfolge bleibt erhalten)
#' @noRd
scn_as_map <- function(x, block) {
  if (is.null(x) || length(x) == 0L) return(list())
  if (is_map(x)) return(x)
  if (is.list(x) && all(vapply(x, function(e) is_map(e) && utl_is_string(e[["id"]]),
                               logical(1)))) {
    ids <- vapply(x, function(e) e[["id"]], "")
    return(stats::setNames(x, ids))
  }
  vofi_abort("io.collection_invalid", block = block, .class = "vofi_error_input")
}

#' Alle Blöcke eines Szenarios normalisieren (idempotent)
#'
#' Domänenblöcke mit Schema (`val_domain_schema()`) nach ihren Feldarten; Sammlungen der Domäne
#' (`unit_groups`, `measures`, `funding`) je Element nach dem Schema des Sammlungsnamens, falls
#' WS-B es führt, sonst nach der allgemeinen Wertgrammatik; Komponenten nach den Typparametern.
#' @param x Liste der Blöcke (Rohform oder bereits normalisiert).
#' @return normalisierte Liste.
#' @noRd
scn_normalize <- function(x) {
  if (!is.null(x$schema_version)) {
    x$schema_version <- node_integer(x$schema_version, "schema_version")
  }
  for (b in intersect(scn_collections(), names(x))) x[[b]] <- scn_as_map(x[[b]], b)
  for (cp in scn_nested_collections()) {
    v <- path_get(x, cp)
    if (!is.null(v) && !is_map(v)) x <- path_set(x, cp, scn_as_map(v, cp))
  }
  for (b in c("meta", "project", "grid", "building", "household", "accounts",
              "residual_value", "tax", "analysis")) {
    if (!is.null(x[[b]])) x[[b]] <- scn_normalize_block(x[[b]], b, val_domain_schema(b))
  }
  for (b in c("unit_groups", "measures", "funding")) {
    sch <- val_domain_schema(b)
    for (id in names(x[[b]])) {
      el <- x[[b]][[id]]
      if (is.null(el)) next
      x[[b]][[id]] <- scn_normalize_block(el, path_join(b, id), sch)
    }
  }
  if (!is.null(x$energy)) {
    x$energy <- scn_normalize_block(x$energy, "energy", val_domain_schema("energy"))
  }
  for (coll in c("components", "financing")) {
    for (id in names(x[[coll]])) {
      x[[coll]][[id]] <- scn_normalize_component(x[[coll]][[id]], id, coll)
    }
  }
  for (b in c("market", "shared")) {
    if (!is.null(x[[b]])) x[[b]] <- scn_normalize_values(x[[b]], b)
  }
  # Raten der kanonischen Marktnamen (4.3.11: Inflation, Wachstum, Zinsen p. a.): > 1 ist ein
  # Eingabefehler (4.6)
  for (nm in intersect(scn_market_rate_names(), names(x$market))) {
    node_check_rate(x$market[[nm]], "rate", path_join("market", nm))
  }
  if (!is.null(x$stochastic)) x$stochastic <- scn_normalize_stochastic(x$stochastic)
  x <- scn_move_dists(x)
  io_unmark(x)
}

#' Kanonische Marktnamen, die Raten p. a. sind (4.3.11, R-103)
#' @noRd
scn_market_rate_names <- function() {
  c("inflation", "rent_growth", "rent_growth_new", "construction_price_index",
    "maintenance_index", "land_value_growth", "market_value_growth", "operating_cost_growth",
    "mortgage_rate", "bund_yield_10y", "mortgage_spread")
}

#' Felder eines Blocks nach Schema normalisieren; übrige numerische Blätter als Knoten
#'
#' Bibliotheksverweise (`{from: <id>, ...}`) bleiben Rohform; ihre lokalen Schlüssel werden
#' wie Felder des Blocks normalisiert.
#' @noRd
scn_normalize_block <- function(x, block, schema) {
  if (!is_map(x)) {
    vofi_abort("io.not_map", path = block, .class = "vofi_error_input")
  }
  for (f in names(x)) {
    if (is.null(x[[f]]) || f %in% c("from", "use")) next
    p <- path_join(block, f)
    if (!is.null(schema[[f]]) && !scn_is_library_ref(x[[f]])) {
      x[f] <- list(scn_normalize_field(x[[f]], schema[[f]], p))
    } else {
      x[f] <- list(scn_normalize_values(x[[f]], p))
    }
  }
  x
}

#' Feld eines Domänenblocks nach Schema normalisieren
#'
#' Wie `node_normalize()`; bei verschachtelten Feldern der Art `map` werden die Unterfelder,
#' die die Sicht `val_domain_schema()` nicht führt (freie Maps, Sequenzen, z. B.
#' `energy.before.consumption_kwh.<träger>` oder `extra_consumption.<x>.kwh_pa`), wie auf der
#' obersten Ebene nach der allgemeinen Wertgrammatik normalisiert (Vertrag der Sicht, WS-B).
#' @noRd
scn_normalize_field <- function(x, param, path) {
  if (!identical(param$kind, "map") || !is_map(x)) return(node_normalize(x, param, path))
  fields <- param$fields %||% list()
  for (f in names(x)) {
    if (is.null(x[[f]]) || f %in% c("from", "use")) next
    p <- path_join(path, f)
    x[f] <- list(if (!is.null(fields[[f]]) && !scn_is_library_ref(x[[f]])) {
      scn_normalize_field(x[[f]], fields[[f]], p)
    } else {
      scn_normalize_values(x[[f]], p)
    })
  }
  x
}

#' Allgemeine Normalisierung: numerische Blätter und Wertformen werden Knoten, Maps rekursiv
#' @noRd
scn_normalize_values <- function(x, path) {
  if (is.null(x)) return(NULL)
  if (node_is(x)) return(node_normalize(x, NULL, path))
  if (io_is_raw_num(x) || (is.numeric(x) && length(x) == 1L)) {
    return(node_normalize(x, NULL, path))
  }
  if (is_map(x) && length(x) > 0L) {
    kind <- utl_value_form_kind(x)
    if (identical(kind, "from")) {
      for (f in setdiff(names(x), c("from", "use"))) {
        if (!is.null(x[[f]])) x[f] <- list(scn_normalize_values(x[[f]], path_join(path, f)))
      }
      return(x)
    }
    if (!is.na(kind)) return(node_normalize(x, NULL, path))
    for (f in names(x)) {
      if (!is.null(x[[f]])) x[f] <- list(scn_normalize_values(x[[f]], path_join(path, f)))
    }
    return(x)
  }
  if (is.numeric(x) && length(x) > 1L) return(node_normalize(x, NULL, path))
  x
}

#' Komponente bzw. Finanzierungsbaustein normalisieren (Metafelder, Typparameter flach)
#' @noRd
scn_normalize_component <- function(comp, id, coll) {
  path <- path_join(coll, id)
  if (!is_map(comp)) {
    vofi_abort("io.not_map", path = path, .class = "vofi_error_input")
  }
  comp$id <- id
  type <- comp[["type"]]
  def <- scn_type_def(type, coll)
  for (f in setdiff(names(comp), "id")) {
    v <- comp[[f]]
    if (is.null(v) || f %in% c("from", "use")) next
    p <- path_join(path, f)
    comp[f] <- list(
      if (f == "after") {
        node_ids(v, p)
      } else if (f %in% reg_reserved_fields()) {
        node_string(v, p)
      } else if (!is.null(def) && !is.null(def$params[[f]]) && !scn_is_library_ref(v)) {
        node_normalize(v, def$params[[f]], p)
      } else {
        scn_normalize_values(v, p)
      }
    )
  }
  comp
}

#' Typdefinition einer Komponente (components: flow; financing: equity oder instrument)
#' @noRd
scn_type_def <- function(type, coll) {
  if (!utl_is_string(type)) return(NULL)
  kinds <- if (identical(coll, "financing")) c("instrument", "flow") else "flow"
  for (k in kinds) if (reg_has(k, type)) return(reg_get(k, type))
  NULL
}

#' Stochastik-Overlay normalisieren
#'
#' Einstellungen mit Schema nach ihrer Art, übrige Einstellungen (z. B. `preset`, `band_probs`,
#' `convergence`) als Werte ohne Knoten; Overlay-Einträge als Maps nach Schlüssel.
#' @noRd
scn_normalize_stochastic <- function(x) {
  if (!is_map(x)) {
    vofi_abort("io.not_map", path = "stochastic", .class = "vofi_error_input")
  }
  if (!is.null(x$settings)) {
    if (!is_map(x$settings)) {
      vofi_abort("io.not_map", path = "stochastic.settings", .class = "vofi_error_input")
    }
    schema <- val_domain_schema("stochastic.settings")
    for (f in names(x$settings)) {
      v <- x$settings[[f]]
      if (is.null(v)) next
      p <- path_join("stochastic.settings", f)
      x$settings[f] <- list(if (!is.null(schema[[f]])) {
        node_normalize(v, schema[[f]], p)
      } else {
        io_unmark(v, p)
      })
    }
  }
  for (b in c("parameters", "processes")) {
    if (is.null(x[[b]])) next
    x[[b]] <- scn_as_map(x[[b]], paste0("stochastic.", b))
    for (k in names(x[[b]])) x[[b]][[k]] <- io_unmark(x[[b]][[k]], path_join("stochastic", b, k))
  }
  x
}

#' Kurzform-Verteilungen ins Overlay verschieben (4.5, Regel 1): Schlüssel = Zielpfad, am Ort
#' bleibt der Basiswert als const
#' @noRd
scn_move_dists <- function(x) {
  hits <- scn_find_nodes(x, "dist")
  if (length(hits) == 0L) return(x)
  for (p in hits) {
    nd <- path_get(x, p)
    base <- nd$base %||% scn_dist_point(nd, x, p)
    entry <- c(list(target = p, dist = nd$dist), nd$par,
               if (!is.null(nd$label)) list(label = nd$label), list(base = base))
    x$stochastic <- x$stochastic %||% list()
    x$stochastic$parameters <- x$stochastic$parameters %||% list()
    x$stochastic$parameters[[p]] <- entry
    x <- path_set(x, p, node_const(base))
  }
  x
}

#' Basiswert einer Kurzform ohne `base`: point(par, analysis.deterministic_point)
#' @noRd
scn_dist_point <- function(nd, x, path) {
  if (!reg_has("distribution", nd$dist)) {
    vofi_abort("io.dist_base_missing", path = path, dist = nd$dist,
               .class = "vofi_error_input")
  }
  which <- x$analysis$deterministic_point %||% "mode"
  as.double(reg_get("distribution", nd$dist)$point(nd$par, which))
}

#' Pfade aller Knoten einer Art (Knoten gelten als Blätter)
#' @noRd
scn_find_nodes <- function(x, kind, path = "") {
  if (node_is(x)) return(if (identical(x$kind, kind)) path else character(0))
  if (!is_map(x) || length(x) == 0L) return(character(0))
  out <- lapply(names(x), function(nm) {
    if (nm %in% c("variants", "scenario_sets", "stochastic") && !nzchar(path)) {
      return(character(0))
    }
    scn_find_nodes(x[[nm]], kind, path_join(path, nm))
  })
  unlist(out, use.names = FALSE) %||% character(0)
}
