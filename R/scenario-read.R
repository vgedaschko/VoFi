# Szenario einlesen und schreiben (WS-A, Spec 00 Abschnitte 4.1, 4.4, 4.6, 4.8, 4.13).
# Phase-0-Minimalfassung, Eigentuemer: WS-A. Umgesetzt: vofi_read_scenario() fuer YAML (inkl.
# separater Stochastik-Datei), vofi_scenario() mit Normalisierung aller Bloecke (Listen mit id
# -> Maps, Domaenenfelder nach dem Schema aus R/schema.R, Typparameter nach der Registry,
# Kurzform-Verteilungen ins Overlay), Herkunft der Schicht 5, vofi_example().
# Offen fuer WS-A: Excel-Eingabe (WS-A2), vofi_write_scenario(), Zeilennummern in der Herkunft,
# Bibliotheksverweise `from:` (Schicht 3).

#' Szenario einlesen
#'
#' Liest ein Szenario aus YAML oder Excel, normalisiert es (Wertgrammatik, Einheiten, Aliase) und
#' liefert das kanonische Szenario-Objekt mit Herkunft der Blätter (Spec 00, Abschnitte 4.1, 4.6).
#' Optional wird ein separates Stochastik-Overlay gemischt (Datei gewinnt).
#'
#' Phase-0-Minimalfassung (Eigentümer: WS-A): YAML vollständig nach 4.6; Excel folgt mit WS-A2.
#'
#' @param path Pfad der Szenariodatei (`.yaml`/`.yml` oder `.xlsx`).
#' @param format `"auto"` (nach Dateiendung), `"yaml"` oder `"excel"`.
#' @param stochastic optional: Pfad einer YAML-Datei mit Wurzelschlüssel `stochastic`.
#' @param library_paths Wurzeln der Nutzerbibliotheken (später gewinnt).
#' @return Objekt der Klasse `vofi_scenario`.
#' @family Einlesen
#' @examples
#' sc <- vofi_read_scenario(vofi_example("skeleton"))
#' sc$meta$scenario_id
#' @export
vofi_read_scenario <- function(path, format = c("auto", "yaml", "excel"), stochastic = NULL,
                               library_paths = vofi_library_paths()) {
  format <- utl_match_arg(format, c("auto", "yaml", "excel"), "format")
  if (!utl_is_string(path) || !file.exists(path)) {
    vofi_abort("core.file_missing", path = as.character(path %||% "NULL")[1L],
               .class = "vofi_error_input")
  }
  if (format == "auto") {
    ext <- tolower(tools::file_ext(path))
    format <- if (ext %in% c("xlsx", "xls")) "excel" else "yaml"
  }
  if (format == "excel") scn_unsupported("vofi_read_scenario(format = \"excel\")")
  raw <- io_read_yaml_utf8(path)
  stoch_path <- NULL
  if (!is.null(stochastic)) {
    ov <- io_read_yaml_utf8(stochastic)
    if (!is_map(ov) || is.null(ov[["stochastic"]])) {
      vofi_abort("io.stochastic_root", path = stochastic, .class = "vofi_error_input")
    }
    raw$stochastic <- deep_merge(raw$stochastic %||% list(), ov$stochastic)
    stoch_path <- normalizePath(stochastic, winslash = "/", mustWork = FALSE)
  }
  vofi_scenario(raw, source = list(
    path = normalizePath(path, winslash = "/", mustWork = FALSE), format = "yaml",
    read_time = Sys.time(), sha = stable_hash_file(path), stochastic_path = stoch_path
  ))
}

#' Szenario schreiben
#'
#' Schreibt ein Szenario (auf Wunsch eine aufgelöste Variante) als YAML oder Excel.
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param scenario Objekt der Klasse `vofi_scenario`.
#' @param path Zieldatei.
#' @param format `"auto"` (nach Dateiendung), `"yaml"` oder `"excel"`.
#' @param resolved aufgelöste Variante (Schichten gemischt) statt der Eingabeform schreiben.
#' @param variant Variante, die bei `resolved = TRUE` geschrieben wird.
#' @param overwrite vorhandene Datei überschreiben.
#' @return `invisible(path)`.
#' @family Einlesen
#' @export
vofi_write_scenario <- function(scenario, path, format = c("auto", "yaml", "excel"),
                                resolved = FALSE, variant = "base", overwrite = FALSE) {
  vofi_abort("core.not_implemented", fun = "vofi_write_scenario",
             .class = "vofi_error_not_implemented")
}

#' Kanonisches Szenario aus einer R-Liste
#'
#' Erzeugt ein kanonisches, normalisiertes Szenario aus einer R-Liste in YAML-Form (Datumswerte
#' als `Date` oder ISO-Zeichenkette, Zahlen, Wertformen der Wertgrammatik). Die Normalisierung
#' ist idempotent: ein bereits normalisiertes Szenario bleibt unverändert.
#'
#' Phase-0-Minimalfassung (Eigentümer: WS-A).
#'
#' @param x Liste mit den Blöcken der obersten Ebene (Spec 00, Abschnitt 4.2).
#' @param source optional: Herkunftsangaben (`path`, `format`, ...).
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
  if (inherits(x, "vofi_scenario")) {
    old_source <- attr(x, "source")
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
  new_vofi_scenario(x, source = src,
                    provenance = scn_provenance(x, layer = 5L, source_type = "scenario",
                                                file = file))
}

#' Mitgelieferte Beispielszenarien
#'
#' Liefert den Pfad eines mitgelieferten Beispielszenarios bzw. die Namen aller Beispiele.
#'
#' Phase-0-Minimalfassung (Eigentümer: WS-A).
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

#' Funktion bzw. Eingabeform ist in Phase 0 noch nicht verfügbar
#' @noRd
scn_unsupported <- function(what) {
  vofi_abort("core.not_implemented", fun = what, .class = "vofi_error_not_implemented")
}

# ---------------------------------------------------------------------------------------------
# Normalisierung (4.4, 4.5, 4.6)
# ---------------------------------------------------------------------------------------------

#' Sammlungen nach id (4.4 Nr. 1)
#' @noRd
scn_collections <- function() {
  c("unit_groups", "measures", "funding", "components", "financing", "variants",
    "scenario_sets")
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
#' @param x Liste der Blöcke (Rohform oder bereits normalisiert).
#' @return normalisierte Liste.
#' @noRd
scn_normalize <- function(x) {
  if (!is.null(x$schema_version)) {
    x$schema_version <- node_integer(x$schema_version, "schema_version")
  }
  for (b in intersect(scn_collections(), names(x))) x[[b]] <- scn_as_map(x[[b]], b)
  for (b in c("meta", "project", "grid", "building", "household", "accounts",
              "residual_value", "tax", "analysis")) {
    if (!is.null(x[[b]])) x[[b]] <- scn_normalize_block(x[[b]], b, val_domain_schema(b))
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
#' @noRd
scn_normalize_block <- function(x, block, schema) {
  if (!is_map(x)) {
    vofi_abort("io.not_map", path = block, .class = "vofi_error_input")
  }
  for (f in names(x)) {
    if (is.null(x[[f]])) next
    p <- path_join(block, f)
    if (!is.null(schema[[f]])) {
      x[f] <- list(node_normalize(x[[f]], schema[[f]], p))
    } else {
      x[f] <- list(scn_normalize_values(x[[f]], p))
    }
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
    if (!is.na(utl_value_form_kind(x))) return(node_normalize(x, NULL, path))
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
    if (is.null(v)) next
    p <- path_join(path, f)
    comp[f] <- list(
      if (f == "after") {
        node_ids(v, p)
      } else if (f %in% reg_reserved_fields()) {
        node_string(v, p)
      } else if (!is.null(def) && !is.null(def$params[[f]])) {
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

#' Stochastik-Overlay normalisieren (Einstellungen nach Schema, Parameter als Zahlen)
#' @noRd
scn_normalize_stochastic <- function(x) {
  if (!is_map(x)) {
    vofi_abort("io.not_map", path = "stochastic", .class = "vofi_error_input")
  }
  if (!is.null(x$settings)) {
    x$settings <- scn_normalize_block(x$settings, "stochastic.settings",
                                      val_domain_schema("stochastic.settings"))
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

#' Blattpfade (Knoten, Werte und Wertformen gelten als Blätter)
#' @noRd
scn_leaves <- function(x, path = "") {
  if (is.null(x)) return(character(0))
  if (node_is(x) || !is_map(x) || length(x) == 0L ||
        (nzchar(path) && is_value_form(x, path, kind_of = scn_kind_of))) {
    return(if (nzchar(path)) path else character(0))
  }
  unlist(lapply(names(x), function(nm) scn_leaves(x[[nm]], path_join(path, nm))),
         use.names = FALSE) %||% character(0)
}

#' Herkunftstabelle (4.8)
#' @param x Liste.
#' @param layer Schicht je Blatt (Skalar oder benannter Vektor nach Pfad).
#' @param source_type Quellart je Blatt (Skalar oder benannter Vektor).
#' @param file Datei.
#' @param variant Variante.
#' @param entry `NULL` oder benannter Vektor Blattpfad -> Eintrag (z. B. `"rule:dates"`).
#' @return Data Frame nach 4.8.
#' @noRd
scn_provenance <- function(x, layer = 5L, source_type = "scenario", file = NA_character_,
                           variant = NA_character_, entry = NULL, files = NULL) {
  paths <- scn_leaves(x)
  pick <- function(v, default) {
    if (length(v) == 1L && is.null(names(v))) return(rep(v, length(paths)))
    out <- rep(default, length(paths))
    for (i in seq_along(paths)) {
      segs <- path_split(paths[i])
      for (k in rev(seq_along(segs))) {
        key <- paste(segs[seq_len(k)], collapse = ".")
        if (key %in% names(v)) {
          out[i] <- v[[key]]
          break
        }
      }
    }
    out
  }
  na_date <- as.Date(rep(NA_character_, length(paths)))
  data.frame(
    path = paths, layer = as.integer(pick(layer, 5L)),
    source_type = as.character(pick(source_type, "scenario")),
    file = if (length(files) == 0L) rep(as.character(file), length(paths)) else
      as.character(pick(files, as.character(file))),
    entry = if (length(entry) == 0L) rep(NA_character_, length(paths)) else
      as.character(unname(entry[paths])),
    location = rep(NA_character_, length(paths)),
    variant = rep(as.character(variant), length(paths)), valid_from = na_date,
    valid_to = na_date, as_of = na_date, accessed = na_date,
    quality = rep(NA_character_, length(paths)), stringsAsFactors = FALSE
  )
}
