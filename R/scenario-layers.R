# Schichten, Deep-Merge, Defaults-Dateien, Ableitungsregeln, item_defaults, Build-Kontext und
# Expander-Aufruf (WS-A, Spec 00 Abschnitte 4.7-4.12, 6.4; Spec 01 Teil A 1.4, 2.1, 4.5.1,
# Teil B 5.5, 7.1).
# Reihenfolge nach 4.7: Schicht 0, global.yaml und sein Teilbaum by_project_type, Profil und
# sein Teilbaum by_project_type, Schichten 3 bis 8 (Bibliotheksverweise an der Fundstelle jeder
# Quelle; Szenario, Overlay, Varianten, Szenario-Set, Overrides), danach Ableitungsregeln,
# item_defaults, Rechtsstand, Typ-Defaults, Pruefung der Mengenbezuege und Expander. Herkunft
# je Blatt ueber den Herkunftsspeicher in R/scenario-provenance.R. Solange die Paketbibliothek
# fehlt (WS-L liefert sie in Welle 3), entfallen Bibliotheksverweise der Defaults-Dateien mit
# einem Hinweis je Sitzung.

scn_state <- new.env(parent = emptyenv())

#' Variante auflösen
#'
#' Löst eine Variante auf: Schichten 0–8 mischen, Bibliotheksverweise auflösen, Varianten und
#' Szenario-Sets anwenden, Ableitungsregeln und Element-Defaults (`item_defaults`) anwenden,
#' Rechtsstand wählen und Expander ausführen (Spec 00, Abschnitte 4.7–4.12).
#'
#' Reihenfolge: Typ-Defaults (Schicht 0), `global.yaml` (1) und sein Teilbaum
#' `by_project_type.<project_type>`, Perspektiven-Profil (2) und dessen Teilbaum, Bibliothek und
#' Nutzerbibliotheken (3, 4; Verweise `from:` an ihrer Fundstelle), Szenario (5), Overlay (6,
#' bleibt in `spec$stochastic` und wirkt nur in MC-Läufen), Variante mit ihrer `extends`-Kette
#' und Szenario-Set (7), Overrides (8). Danach laufen je Auflösung die Ableitungsregeln
#' `rule:<name>` (Spec 01 Teil A 1.4, Teil B 5.5), die Vorlagen `item_defaults` aus
#' `global.yaml`, die automatische Wahl der `legal/*`-Einträge (4.10) und die Expander (4.12).
#' Ein Pfad, den eine Variante, ein Set oder ein Override deterministisch setzt, verliert seinen
#' Overlay-Eintrag (Hinweis). Liegt das maßgebliche Datum eines verwendeten
#' Bibliothekseintrags außerhalb seiner Gültigkeit oder ist sein Stand zu alt, folgt
#' `vofi_warning_library_outdated`.
#'
#' `analysis.kpis: default` bedeutet den Wert der Schicht 2 (Kennzahlenliste des Profils, Spec 01
#' Teil A 2.1); die Liste steht danach in `spec$analysis$kpis` (Herkunft `profile`). Mengenbezüge
#' (`{value, per}`) brauchen ihre Bezugsgröße am Bezugsobjekt bzw. in `building`
#' (`validation.quantity.reference_missing`, Spec 01 Teil A 3.5).
#'
#' Die Spezifikation trägt die Herkunft je Blatt (`attr(spec, "provenance")`, 4.8), die Metadaten
#' der Defaults-Dateien (`attr(spec, "defaults_meta")`) und den Bibliotheksstand
#' (`attr(spec, "library_version")`, `spec$library`).
#'
#' @param scenario Objekt der Klasse `vofi_scenario`.
#' @param variant Variante (Default `"base"`).
#' @param overrides optional: Laufzeit-Overrides (Schicht 8) in Baum- oder Pfadform.
#' @param scenario_set optional: Name eines Szenario-Sets (aus `global.yaml`, Profil oder
#'   Szenario).
#' @return Objekt der Klasse `vofi_spec`.
#' @family Einlesen
#' @examples
#' spec <- vofi_resolve(vofi_read_scenario(vofi_example("skeleton")))
#' spec$project$tax_regime
#' head(attr(spec, "provenance")[, c("path", "layer", "source_type", "entry")])
#' @export
vofi_resolve <- function(scenario, variant = "base", overrides = NULL, scenario_set = NULL) {
  scn_resolve(scenario, variant = variant, overrides = overrides, scenario_set = scenario_set)
}

#' Variante auflösen (Arbeitsfunktion von vofi_resolve(); Expander wahlweise fehlertolerant)
#'
#' `expand = "strict"` ist die Auflösung nach 4.7-4.12 (vofi_resolve()). `"tolerant"` dient
#' allein der Validierung (Spec 00 4.1: vofi_validate() sammelt alle Befunde): Bricht ein
#' Expander ab (Validierung im Expander, Spec 01 Teil B 1.6 Nr. 8, Teil A 6.2 Nr. 5), fehlen nur
#' seine Komponenten, die übrigen Expander laufen weiter, und die Ebenen 2-4 prüfen die Domäne
#' trotzdem; die Namen der abgebrochenen Expander stehen in `attr(spec, "expand_failed")`.
#' `"none"` überspringt die Expander.
#' @inheritParams vofi_resolve
#' @param expand `"strict"`, `"tolerant"` oder `"none"`.
#' @return `vofi_spec`.
#' @noRd
scn_resolve <- function(scenario, variant = "base", overrides = NULL, scenario_set = NULL,
                        expand = c("strict", "tolerant", "none")) {
  expand <- match.arg(expand)
  if (!inherits(scenario, "vofi_scenario")) {
    vofi_abort("io.not_scenario", arg = "scenario", .class = "vofi_error_input")
  }
  if (!utl_is_string(variant)) {
    vofi_abort("core.arg_scalar", arg = "variant", .class = "vofi_error_input")
  }
  if (!is.null(scenario_set) && !utl_is_string(scenario_set)) {
    vofi_abort("core.arg_scalar", arg = "scenario_set", .class = "vofi_error_input")
  }
  if (!is.null(overrides)) overrides <- scn_overrides_tree(overrides)
  sc <- unclass(scenario)
  src <- attr(scenario, "source") %||% list()
  prov5 <- attr(scenario, "provenance")
  attr(sc, "source") <- NULL
  attr(sc, "provenance") <- NULL
  ctx <- scn_context(src, variant)
  variants <- scn_as_map(sc$variants, "variants")
  chain <- var_chain(variants, variant)
  base <- sc[setdiff(names(sc), c("variants", "scenario_sets"))]
  eff <- scn_effective_project(base, variants[chain], overrides)
  ctx$defaults <- scn_defaults_stack(eff$perspective)
  ctx$items <- ctx$defaults$global$items %||% list()

  # Schichten 1-2 (Defaults-Dateien mit by_project_type) und 5/6 (Szenario, Overlay)
  x <- list()
  for (s in scn_default_sources(ctx$defaults, eff$project_type, ctx)) {
    x <- scn_apply_source(x, s, ctx)
  }
  scn_inform_missing(ctx)
  scn_note_kpis_default(x, ctx)
  x <- scn_apply_scenario(x, base, prov5, ctx)

  # Schicht 7: Varianten (extends-Kette), danach Szenario-Set
  for (v in chain) {
    r <- var_apply_ops(x, variants[[v]], v, ctx = ctx)
    x <- var_unbind_overlay(scn_normalize(r$x), r$bound, r$keys, v)
  }
  if (!is.null(scenario_set)) {
    sets <- var_scenario_sets(ctx$defaults, sc$scenario_sets)
    set <- sets[[scenario_set]]
    if (is.null(set)) {
      vofi_abort("io.scenario_set_unknown", set = scenario_set,
                 suggestion = utl_suggest_text(scenario_set, names(sets)),
                 .class = "vofi_error_validation")
    }
    var_check_set(set, scenario_set)
    r <- var_apply_ops(x, set, scenario_set, is_set = TRUE, ctx = ctx)
    x <- var_unbind_overlay(scn_normalize(r$x), r$bound, r$keys, scenario_set)
  }
  # Schicht 8
  if (!is.null(overrides)) x <- scn_apply_override_layer(x, overrides, ctx)
  x <- scn_normalize(x)
  x <- scn_resolve_kpis_default(x, ctx)

  # Ableitungsregeln (vor item_defaults), item_defaults, Rechtsstand, Typ-Defaults,
  # Mengenbezuege, Expander
  x <- scn_run_rules(x, ctx)
  x <- scn_apply_item_defaults(x, ctx)
  x$legal <- scn_legal_all(x, ctx)
  x$registers <- list(assets = list(), measures = list())
  x <- scn_type_defaults(x, ctx)
  scn_check_quantities(x)
  failed <- character(0)
  if (!identical(expand, "none")) {
    x <- scn_run_expanders(x, ctx, tolerant = identical(expand, "tolerant"))
    failed <- attr(x, "expand_failed") %||% character(0)
    attr(x, "expand_failed") <- NULL
  }
  x <- scn_type_defaults(x, ctx)
  x$variant <- variant
  x$scenario_set <- scenario_set
  x$library <- scn_library_table(x, ctx)
  scn_check_outdated(x, ctx)

  label <- if (is.null(scenario_set)) variant else paste0(variant, "+", scenario_set)
  tree <- x[setdiff(names(x), c("registers", "legal", "variant", "scenario_set", "library"))]
  spec <- new_vofi_spec(x, provenance = prv_table(ctx$prv, tree, variant = label))
  attr(spec, "defaults_meta") <- scn_defaults_meta(ctx$defaults)
  attr(spec, "library_version") <- lib_version(ctx$lib_paths)
  attr(spec, "notes") <- unique(ctx$notes)
  if (!identical(expand, "strict")) attr(spec, "expand_failed") <- failed
  src$read_time <- NULL
  attr(spec, "scn_state") <- list(scenario = new_vofi_scenario(sc, source = src,
                                                               provenance = prov5),
                                  variant = variant, scenario_set = scenario_set,
                                  overrides = overrides, derived = unique(ctx$derived))
  spec
}

#' Auflösungskontext (Umgebung: Bibliothek, Herkunft, Vorlagen, Meldungen)
#' @noRd
scn_context <- function(src, variant) {
  ctx <- new.env(parent = emptyenv())
  ctx$lib_paths <- src$library_paths %||% vofi_library_paths()
  ctx$index <- lib_index(ctx$lib_paths)
  ctx$prv <- prv_new()
  ctx$lc <- lib_context(ctx$index, ctx$prv, mode = "error")
  ctx$file <- if (utl_is_string(src$path)) basename(src$path) else NA_character_
  ctx$variant <- variant
  ctx$notes <- character(0)
  ctx$lib_calls <- character(0)
  ctx$legal_cache <- list()
  ctx$kpis_default <- NULL
  ctx$kpis_default_info <- NULL
  ctx$derived <- character(0)
  ctx$lc$cache <- new.env(hash = TRUE, parent = emptyenv())
  ctx
}

#' Schlüssel eines Validierungsbefunds mit Rückfall (WS-B-Schlüssel, sobald im Katalog)
#'
#' Liefert `primary`, wenn der Schlüssel im Label-Katalog steht und alle seine Platzhalter unter
#' den übergebenen Argumenten sind, sonst `fallback` (Schlüssel von WS-A in `io.yaml`). Die
#' Aufrufer übergeben die Obermenge der Platzhalter beider Texte (Konvention von WS-B:
#' `path` = Fundstelle, `value` = betroffener Wert bzw. Zielpfad, dazu z. B. `file`, `form`,
#' `expected`, `entry`, `n`); `scn_signal()` meldet mit demselben Satz.
#' @param primary Schlüssel `validation.*` (Spec 01).
#' @param fallback eigener Schlüssel.
#' @param ... Platzhalterwerte, die der Aufrufer übergibt.
#' @return Zeichenkette.
#' @noRd
scn_key <- function(primary, fallback, ...) {
  if (!lbl_has(primary)) return(fallback)
  text <- get0(primary, envir = lbl_state$labels, inherits = FALSE)
  if (!utl_is_string(text)) return(fallback)
  ph <- regmatches(text, gregexpr("\\{([A-Za-z_][A-Za-z0-9_.]*)(:[a-z]+)?\\}", text))[[1L]]
  ph <- unique(sub("^\\{([A-Za-z_][A-Za-z0-9_.]*).*$", "\\1", ph))
  if (all(ph %in% names(list(...)))) primary else fallback
}

#' Befund mit Schlüsselwahl nach `scn_key()` melden
#'
#' Wählt den Schlüssel aus denselben Platzhaltern, mit denen gemeldet wird; so passen Text und
#' Argumente immer zusammen.
#' @param type `"abort"`, `"warn"` oder `"inform"`.
#' @param primary,fallback Schlüssel (`scn_key()`).
#' @param ... Platzhalterwerte (Obermenge beider Texte).
#' @param .class Bedingungsklasse (`abort`, `warn`).
#' @return wie `vofi_abort()`, `vofi_warn()` bzw. `vofi_inform()`.
#' @noRd
scn_signal <- function(type, primary, fallback, ..., .class = NULL) {
  key <- scn_key(primary, fallback, ...)
  switch(type,
    abort = vofi_abort(key, ..., .class = .class %||% "vofi_error_validation"),
    warn = vofi_warn(key, ..., .class = .class %||% "vofi_warning_plausibility"),
    inform = vofi_inform(key, ...)
  )
}

# ---------------------------------------------------------------------------------------------
# Defaults-Dateien (Schichten 1-2, 4.7 "Defaults-Dateien", R-76, R-85)
# ---------------------------------------------------------------------------------------------

#' Pfad einer Defaults-Datei
#' @param kind `"global"` oder `"profile"`.
#' @param id Perspektive (nur Profile).
#' @return Dateipfad oder `""`.
#' @noRd
scn_defaults_path <- function(kind, id = NULL) {
  if (identical(kind, "global")) {
    return(system.file("extdata", "defaults", "global.yaml", package = "vofi"))
  }
  if (!utl_is_string(id) || !grepl("^[a-z][a-z0-9_]*$", id)) return("")
  system.file("extdata", "profiles", paste0(id, ".yaml"), package = "vofi")
}

#' Defaults-Datei lesen, prüfen und zerlegen (zwischengespeichert nach Dateistand)
#'
#' Fehlerbefunde der Prüfung (`scn_check_defaults()`) sind ein Fehler der Klasse
#' `vofi_error_validation`.
#' @param kind `"global"` oder `"profile"`.
#' @param id Perspektive (nur Profile).
#' @param path optional: Datei (Tests).
#' @return Liste `kind`, `id`, `file`, `meta`, `tree`, `sets`, `bpt`, `items`, `locations`
#'   bzw. `NULL`, wenn die Datei fehlt.
#' @noRd
scn_defaults_load <- function(kind, id = NULL, path = NULL) {
  path <- path %||% scn_defaults_path(kind, id)
  if (!utl_is_string(path) || !nzchar(path) || !file.exists(path)) return(NULL)
  info <- file.info(path)
  key <- paste(normalizePath(path, winslash = "/", mustWork = FALSE),
               as.double(info$mtime), info$size, sep = "|")
  hit <- scn_state$defaults[[key]]
  if (!is.null(hit)) return(hit)
  txt <- io_read_lines_utf8(path)
  raw <- io_unmark(io_parse_yaml_text(txt, path), "")
  if (!is_map(raw)) {
    vofi_abort("io.defaults.not_map", file = path, .class = "vofi_error_validation")
  }
  rel <- if (identical(kind, "global")) "defaults/global.yaml" else
    paste0("profiles/", basename(path))
  found <- scn_check_defaults(raw, kind, rel)
  errs <- Filter(function(f) identical(f$severity, "error"), found)
  if (length(errs) > 0L) {
    f <- errs[[1L]]
    do.call(vofi_abort, c(list(f$code), f$args, list(.class = "vofi_error_validation")))
  }
  meta <- scn_defaults_meta_one(raw$defaults_meta, kind)
  out <- list(
    kind = kind, id = meta$id, file = rel, meta = meta,
    tree = raw[setdiff(names(raw), c(scn_defaults_reserved(), "scenario_sets"))],
    sets = raw$scenario_sets, bpt = raw$by_project_type %||% list(),
    items = raw$item_defaults %||% list(), locations = io_yaml_locations(txt)
  )
  if (is.null(scn_state$defaults)) scn_state$defaults <- list()
  scn_state$defaults[[key]] <- out
  out
}

#' Reservierte Wurzelschlüssel der Defaults-Dateien (4.2 Fußnote 3, R-85)
#' @noRd
scn_defaults_reserved <- function() c("defaults_meta", "by_project_type", "item_defaults")

#' Zulässige Pfade eines Perspektiven-Profils (R-76)
#' @noRd
scn_profile_paths <- function() {
  c("accounts.*", "analysis.*", "residual_value.method", "residual_value.sale_cost_share",
    "project.horizon_years", "project.report_mode", "tax.module", "scenario_sets.*")
}

#' Pfade der Vorlagen `item_defaults` (4.7 Nr. 3)
#' @return Liste `collections`, `blocks`.
#' @noRd
scn_item_paths <- function() {
  list(collections = c("unit_groups", "measures", "funding", "financing", "components",
                       "energy.carriers", "energy.stages", "building.elements"),
       blocks = c("building", "household", "energy", "energy.pv", "energy.performance_gap",
                  "energy.before", "energy.after", "building.property_tax"))
}

#' Defaults-Datei prüfen (Datentest R-76, R-85, R-97, N-05; `test-profiles.R`)
#'
#' Befunde: fehlendes bzw. unvollständiges `defaults_meta`; unbekannte Wurzelschlüssel
#' (`validation.unknown_key`); optionale Blöcke `building`, `household`, `energy` außerhalb von
#' `item_defaults` (N-05); `item_defaults` im Profil bzw. mit unzulässigem Pfad;
#' `by_project_type` mit unbekanntem Code; `n_sim` bzw. `replicates` in
#' `stochastic.settings` (R-97); im Profil jeder Pfad außerhalb der Liste nach R-76
#' (`validation.profile_path_forbidden`), auch in `by_project_type`.
#' @param raw Rohform der Datei.
#' @param kind `"global"` oder `"profile"`.
#' @param file Datei (für Meldungen).
#' @return Liste von Befunden `list(severity, code, path, args)`.
#' @noRd
scn_check_defaults <- function(raw, kind, file) {
  acc <- new.env(parent = emptyenv())
  acc$out <- list()
  add <- function(code, path, ...) {
    args <- c(list(path = path, file = file), list(...))
    acc$out[[length(acc$out) + 1L]] <- list(severity = "error", code = code, path = path,
                                            args = args)
  }
  meta <- raw$defaults_meta
  if (!is_map(meta)) {
    add("io.defaults.meta_missing", "defaults_meta")
  } else {
    miss <- setdiff(c("kind", "id", "schema_version", "as_of", "quality", "source"), names(meta))
    if (length(miss) > 0L) {
      add("io.defaults.meta_incomplete", "defaults_meta", fields = utl_collapse(miss))
    }
    if (!identical(meta$kind, kind)) {
      add("io.defaults.meta_kind", "defaults_meta.kind",
          value = utl_collapse(format(meta$kind %||% "NULL")), expected = kind)
    }
    if (!is.null(meta$schema_version) && !identical(as.double(meta$schema_version), 1)) {
      add("io.defaults.meta_schema", "defaults_meta.schema_version",
          value = utl_collapse(format(meta$schema_version)))
    }
    if (!is.null(meta$quality) && !(meta$quality %in% vocab_codes("quality"))) {
      add("io.defaults.meta_quality", "defaults_meta.quality",
          value = utl_collapse(format(meta$quality)))
    }
  }
  allowed <- c(setdiff(utl_scenario_blocks(), c("meta", "variants")), "defaults_meta",
               "by_project_type", if (identical(kind, "global")) "item_defaults")
  for (k in setdiff(names(raw), allowed)) {
    if (identical(k, "item_defaults")) {
      add("io.defaults.item_defaults_profile", k)
    } else {
      add(scn_key("validation.unknown_key", "io.defaults.unknown_key", path = k, file = file,
                  suggestion = ""),
          k, suggestion = utl_suggest_text(k, allowed))
    }
  }
  for (b in intersect(c("building", "household", "energy"), names(raw))) {
    add("io.defaults.optional_block", b, block = b)
  }
  items <- raw$item_defaults
  if (!is.null(items)) {
    ip <- scn_item_paths()
    for (p in names(items)) {
      if (!(p %in% c(ip$collections, ip$blocks))) {
        add("io.defaults.item_path", paste0("item_defaults.", p), item = p,
            suggestion = utl_suggest_text(p, c(ip$collections, ip$blocks)))
      } else if (!is_map(items[[p]])) {
        add("io.defaults.item_not_map", paste0("item_defaults.", p), item = p)
      }
    }
  }
  bpt <- raw$by_project_type
  if (!is.null(bpt)) {
    for (code in names(bpt)) {
      if (!vocab_has("project_type", code)) {
        add("io.defaults.project_type", paste0("by_project_type.", code), ptype = code,
            suggestion = utl_suggest_text(code, vocab_codes("project_type")))
      }
    }
  }
  trees <- c(list(raw), if (is_map(bpt)) unname(bpt))
  prefixes <- c("", if (is_map(bpt)) paste0("by_project_type.", names(bpt)))
  for (i in seq_along(trees)) {
    st <- trees[[i]]$stochastic$settings
    for (f in intersect(c("n_sim", "replicates"), names(st))) {
      add("io.defaults.settings_forbidden", path_join(prefixes[i], "stochastic.settings", f),
          field = f)
    }
    if (identical(kind, "profile")) {
      t <- trees[[i]]
      t <- t[setdiff(names(t), scn_defaults_reserved())]
      for (p in scn_defaults_leaves(t)) {
        if (!scn_profile_path_ok(p)) {
          add(scn_key("validation.profile_path_forbidden", "io.defaults.profile_path",
                      path = p, file = file, allowed = ""),
              path_join(prefixes[i], p),
              allowed = utl_collapse(scn_profile_paths()))
        }
      }
    }
  }
  acc$out
}

#' Blattpfade einer Defaults-Datei (Sammlungen und Sets als Ganzes, Wertformen als Blätter)
#' @noRd
scn_defaults_leaves <- function(x, path = "") {
  if (is.null(x)) return(if (nzchar(path)) path else character(0))
  if (!is_map(x) || length(x) == 0L || node_is(x) ||
        (nzchar(path) && is_value_form(x, path, kind_of = scn_kind_of))) {
    return(if (nzchar(path)) path else character(0))
  }
  unlist(lapply(names(x), function(nm) scn_defaults_leaves(x[[nm]], path_join(path, nm))),
         use.names = FALSE) %||% character(0)
}

#' Ist ein Profilpfad nach R-76 zulässig?
#' @noRd
scn_profile_path_ok <- function(p) {
  pats <- scn_profile_paths()
  exact <- pats[!endsWith(pats, ".*")]
  prefix <- sub("[.][*]$", "", pats[endsWith(pats, ".*")])
  p %in% exact || any(startsWith(p, paste0(prefix, ".")))
}

#' defaults_meta normalisieren (Datum, Ganzzahl)
#' @noRd
scn_defaults_meta_one <- function(meta, kind) {
  meta <- meta %||% list()
  d <- tryCatch(utl_as_date(as.character(meta$as_of %||% NA_character_)),
                error = function(e) as.Date(NA))
  list(kind = as.character(meta$kind %||% kind), id = as.character(meta$id %||% kind),
       schema_version = as.integer(meta$schema_version %||% NA_integer_),
       as_of = if (length(d) == 1L) d else as.Date(NA),
       quality = as.character(meta$quality %||% NA_character_),
       source = as.character(meta$source %||% NA_character_),
       note = as.character(meta$note %||% NA_character_))
}

#' `defaults_meta` der verwendeten Defaults-Dateien (13.1 `meta$defaults`, R-85)
#' @param defaults Defaults-Dateien der Auflösung (`scn_defaults_stack()`) oder eine
#'   Perspektive (Zeichenkette; Testhelfer, `example_result()`).
#' @return Liste `global` (und `profile`, wenn vorhanden).
#' @noRd
scn_defaults_meta <- function(defaults = NULL) {
  if (is.null(defaults) || is.character(defaults)) {
    defaults <- scn_defaults_stack(if (utl_is_string(defaults)) defaults else NULL)
  }
  out <- list()
  if (!is.null(defaults$global)) out$global <- defaults$global$meta
  if (!is.null(defaults$profile)) out$profile <- defaults$profile$meta
  out
}

#' Defaults-Dateien der Perspektive (global.yaml und Profil, falls vorhanden)
#' @noRd
scn_defaults_stack <- function(perspective) {
  g <- scn_defaults_load("global")
  p <- if (utl_is_string(perspective) && vocab_has("perspective", perspective)) {
    scn_defaults_load("profile", perspective)
  }
  Filter(Negate(is.null), list(global = g, profile = p))
}

#' Vorlagen `item_defaults` aus global.yaml (Rohform)
#' @noRd
scn_item_templates <- function() {
  scn_defaults_load("global")$items %||% list()
}

#' Quellen der Schichten 1-2 in Mischreihenfolge (4.7)
#' @noRd
scn_default_sources <- function(defaults, project_type, ctx) {
  out <- list()
  for (d in defaults) {
    layer <- if (identical(d$kind, "global")) 1L else 2L
    st <- if (identical(d$kind, "global")) "global" else "profile"
    trees <- list(d$tree)
    entries <- d$meta$id
    locs <- list(d$locations)
    if (utl_is_string(project_type) && !is.null(d$bpt[[project_type]])) {
      trees <- c(trees, list(d$bpt[[project_type]]))
      entries <- c(entries, paste0(d$meta$id, "#by_project_type.", project_type))
      pre <- paste0("by_project_type.", project_type, ".")
      l <- d$locations[startsWith(names(d$locations), pre)]
      names(l) <- substring(names(l), nchar(pre) + 1L)
      locs <- c(locs, list(l))
    }
    for (i in seq_along(trees)) {
      out[[length(out) + 1L]] <- list(
        tree = trees[[i]], locations = locs[[i]], defaults = TRUE,
        info = prv_info(layer, st, file = d$file, entry = entries[i])
      )
    }
  }
  out
}

#' Wert von `analysis.kpis` nach den Schichten 1-2 merken (Bedeutung von `default`)
#'
#' Ist der Wert nach global.yaml und Profil eine Liste (Profil, Spec 01 Teil A 2.3-2.7), ist sie
#' die Bedeutung von `analysis.kpis: default` in den Schichten 5-8; ihre Herkunft bleibt die des
#' Profils.
#' @noRd
scn_note_kpis_default <- function(x, ctx) {
  k <- x$analysis$kpis
  if (is.null(k) || identical(k, "default")) return(invisible(NULL))
  ctx$kpis_default <- k
  ctx$kpis_default_info <- prv_lookup(ctx$prv, "analysis.kpis")
  invisible(NULL)
}

#' `analysis.kpis: default` durch die Profilliste ersetzen (Wert der Schicht 2, Teil A 2.1, PR3)
#' @noRd
scn_resolve_kpis_default <- function(x, ctx) {
  if (!identical(x$analysis$kpis, "default") || is.null(ctx$kpis_default)) return(x)
  x$analysis$kpis <- ctx$kpis_default
  if (!is.null(ctx$kpis_default_info)) prv_set(ctx$prv, "analysis.kpis", ctx$kpis_default_info)
  x
}

#' Perspektive und Projektart der Auflösung (nach Varianten und Overrides)
#'
#' Bestimmt die Profilwahl (Schicht 2) und den Teilbaum `by_project_type`; maßgeblich ist der
#' Wert nach den Operationen der Varianten und den Overrides.
#' @noRd
scn_effective_project <- function(base, variants, overrides) {
  p <- base$project %||% list()
  apply_ops <- function(p, ops) {
    for (op in c("replace", "set", "add")) {
      for (k in names(ops[[op]])) {
        v <- ops[[op]][[k]]
        if (identical(k, "project") && is_map(v)) {
          for (f in intersect(names(v), c("perspective", "project_type"))) p[[f]] <- v[[f]]
        } else if (k %in% c("project.perspective", "project.project_type")) {
          p[[sub("^project[.]", "", k)]] <- v
        }
      }
    }
    ov <- if (is.null(ops$overrides)) NULL else scn_overrides_tree(ops$overrides)
    for (f in c("perspective", "project_type")) {
      if (utl_has_name(ov$project, f)) p[[f]] <- ov$project[[f]]
    }
    p
  }
  for (v in variants) p <- apply_ops(p, v)
  if (!is.null(overrides)) p <- apply_ops(p, list(overrides = overrides))
  chr <- function(v) if (utl_is_string(v)) v else NULL
  list(perspective = chr(p$perspective), project_type = chr(p$project_type))
}

#' Quelle einer Schicht anwenden: Bibliotheksverweise an der Fundstelle auflösen, Herkunft der
#' eigenen Blätter aufzeichnen, normalisieren und mischen (4.7, 4.9)
#' @noRd
scn_apply_source <- function(x, s, ctx) {
  lc <- ctx$lc
  lc$mode <- if (isTRUE(s$defaults) && !lib_package_available(ctx$index)) "drop" else "error"
  lc$layer <- NULL
  lc$variant <- NA_character_
  on.exit(lc$mode <- "error", add = TRUE)
  res <- lib_resolve(s$tree, "", lc)
  prv_record_tree(ctx$prv, lib_strip_refs(s$tree), "", s$info, s$locations)
  scn_merge(x, scn_normalize(res %||% list()))
}

#' Ist die Paketbibliothek vorhanden (mindestens ein Eintrag der Schicht 3)?
#' @noRd
lib_package_available <- function(index) {
  any(vapply(index$entries, function(r) identical(r$layer, 3L), logical(1)))
}

#' Hinweis auf entfallene Verweise der Defaults-Dateien (einmal je Sitzung)
#' @noRd
scn_inform_missing <- function(ctx) {
  miss <- utl_sort(unique(ctx$lc$missing))
  if (length(miss) == 0L) return(invisible(NULL))
  new <- setdiff(miss, scn_state$missing_informed)
  if (length(new) > 0L && length(scn_state$missing_informed) == 0L) {
    vofi_inform("io.library.defaults_missing", n = length(miss), ids = utl_collapse(miss))
  }
  scn_state$missing_informed <- unique(c(scn_state$missing_informed, miss))
  ctx$lc$missing <- character(0)
  invisible(NULL)
}

#' Szenario-Basis (Schicht 5) und Overlay (Schicht 6) mischen
#'
#' Bibliotheksverweise des Szenarios werden an ihrer Fundstelle aufgelöst (Nutzlast unter die
#' lokale Angabe, Herkunft Schicht 3 bzw. 4 mit `entry`); die eigenen Blätter erhalten die
#' Herkunft aus `attr(scenario, "provenance")` (Datei, Zeile, Schicht 5 bzw. 6).
#' @noRd
scn_apply_scenario <- function(x, base, prov5, ctx) {
  lc <- ctx$lc
  lc$mode <- "error"
  lc$layer <- NULL
  lc$variant <- NA_character_
  res <- lib_resolve(base, "", lc)
  leaves <- scn_leaves(lib_strip_refs(base))
  if (length(leaves) > 0L) {
    idx <- rep(NA_integer_, length(leaves))
    if (is.data.frame(prov5)) idx <- match(leaves, prov5$path)
    for (i in seq_along(leaves)) {
      j <- idx[i]
      info <- if (is.na(j)) {
        overlay <- startsWith(leaves[i], "stochastic.")
        prv_info(if (overlay) 6L else 5L, if (overlay) "overlay" else "scenario",
                 file = ctx$file)
      } else {
        prv_info(prov5$layer[j], prov5$source_type[j], file = prov5$file[j],
                 location = prov5$location[j])
      }
      prv_set(ctx$prv, leaves[i], info)
    }
  }
  scn_merge(x, scn_normalize(res))
}

#' Overrides (Schicht 8) anwenden: Bibliotheksverweise auflösen, Herkunft, Overlay-Bindung
#' @noRd
scn_apply_override_layer <- function(x, overrides, ctx) {
  lc <- ctx$lc
  lc$mode <- "error"
  lc$layer <- 8L
  lc$variant <- NA_character_
  on.exit(lc$layer <- NULL, add = TRUE)
  res <- lib_resolve(overrides, "", lc)
  own <- lib_strip_refs(overrides)
  leaves <- var_override_leaves(own)
  set_leaves <- leaves[!vapply(leaves, function(p) is.null(path_get(own, p)), logical(1))]
  info <- prv_info(8L, "override")
  for (p in set_leaves) prv_record_tree(ctx$prv, path_get(own, p), p, info)
  x <- scn_merge(x, res)
  keys <- unique(c(vapply(leaves, var_overlay_key, ""),
                   unlist(lapply(set_leaves, function(p) var_dist_keys(path_get(own, p), p)))))
  var_unbind_overlay(scn_normalize(x), set_leaves, keys[!is.na(keys)], "overrides")
}

# ---------------------------------------------------------------------------------------------
# Mischen (4.7)
# ---------------------------------------------------------------------------------------------

#' Knotenbewusstes Mischen zweier Schichten (4.7)
#'
#' Wie `deep_merge()`, zusätzlich gelten normalisierte Knoten (`list(kind = ...)`) und
#' Wertformen auf der Override-Seite als Blätter; eine Teil-Map ohne Wertform (z. B.
#' `{fill: zero}`, `{scale: 2}`, `{growth: 0.08}`) wird in einen Basisknoten gemischt.
#' @noRd
scn_merge <- function(base, override, path = "") {
  if (node_is(override) || io_is_raw_num(override)) return(override)
  if (!is_map(base) || !is_map(override)) return(override)
  if (is_value_form(override, path, kind_of = scn_kind_of)) return(override)
  if (utl_has_name(override, ".replace")) {
    replace <- override[[".replace"]]
    override[[".replace"]] <- NULL
    if (isTRUE(replace)) return(override)
  }
  for (nm in names(override)) {
    if (is.null(override[[nm]])) {
      if (utl_has_name(base, nm)) base[[nm]] <- NULL
    } else {
      child <- if (utl_has_name(base, nm)) base[[nm]] else NULL
      base[nm] <- list(scn_merge(child, override[[nm]], path_join(path, nm)))
    }
  }
  base
}

#' Zwei Override-Bäume mischen; Löschanweisungen `~` bleiben erhalten
#' @noRd
scn_merge_overrides <- function(a, b) {
  if (!is_map(a) || !is_map(b) || node_is(b)) return(b)
  for (nm in names(b)) {
    if (is.null(b[[nm]])) {
      a[nm] <- list(NULL)
    } else {
      a[nm] <- list(scn_merge_overrides(if (utl_has_name(a, nm)) a[[nm]] else NULL, b[[nm]]))
    }
  }
  a
}

#' Art eines Pfads für die Erkennung von Wertformen (4.7 Nr. 1)
#'
#' Oberste Blöcke und Einträge der Sammlungen (z. B. `components.<id>`) sind nie Wertformen,
#' auch wenn sie einen Bibliotheksverweis mit lokalen Schlüsseln tragen (4.9).
#' @return `"map"` bzw. `NA_character_` (strukturelle Prüfung).
#' @noRd
scn_kind_of <- function(path) {
  if (length(path_split(path)) == 1L) return("map")
  # Overlay-Eintraege sind Maps nach 4.3.15, keine Wertformen (R-119)
  if (grepl("^stochastic[.](parameters|processes)[.][^.]+$", path)) return("map")
  utl_default_kind_of(path)
}

#' Ist `x` ein Bibliotheksverweis `{from: <id>, ...}`?
#'
#' Nur mit einer Bibliotheks-id nach `utl_library_id_pattern()` (4.9, R-110).
#' @noRd
scn_is_library_ref <- function(x) {
  is_map(x) && !node_is(x) && utl_is_library_id(x[["from"]])
}

#' Schlüssel `from` prüfen (4.9, R-110)
#'
#' `from` ist ausschließlich der Bibliotheksverweis: Eine Map mit dem Schlüssel `from`, dessen
#' Wert keine Bibliotheks-id ist (z. B. `from: completion`, `from: 2027-10-01`), ist der
#' Validierungsfehler `validation.library.ref_not_id` (Termine heißen `start_event`). Gültige
#' Verweise löst `lib_resolve()` auf.
#' @param x Teilbaum (Rohform bzw. teilweise normalisiert).
#' @param path Pfad von `x`.
#' @return `invisible(TRUE)`.
#' @noRd
scn_check_library <- function(x, path = "") {
  if (is_map(x) && length(x) > 0L && !node_is(x)) {
    if (utl_has_name(x, "from") && !utl_is_library_id(x[["from"]])) {
      vofi_abort("validation.library.ref_not_id", path = path_join(path, "from"),
                 value = utl_collapse(format(x[["from"]])),
                 .class = "vofi_error_validation")
    }
    for (nm in names(x)) scn_check_library(x[[nm]], path_join(path, nm))
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------------------------------
# Overrides (Schicht 8)
# ---------------------------------------------------------------------------------------------

#' Overrides (Schicht 8) in Baumform bringen
#'
#' Zulässig sind die Baumform (`list(financing = list(bank = list(start = 2028)))`) und die
#' Pfadform (`list("financing.bank.start" = 2028)`, wie `set` einer Variante, 4.11); beide dürfen
#' gemischt werden, Pfadschlüssel werden nach der Baumform in Listenreihenfolge gemischt. `NULL`
#' (YAML `~`) entfernt das Blatt.
#' @param overrides benannte Liste.
#' @return Overrides in Baumform.
#' @noRd
scn_overrides_tree <- function(overrides) {
  if (!is_map(overrides)) {
    vofi_abort("io.not_map", path = "overrides", .class = "vofi_error_input")
  }
  dotted <- grepl(".", names(overrides), fixed = TRUE)
  if (!any(dotted)) return(overrides)
  insert <- function(tree, segs, value) {
    seg <- segs[1L]
    if (length(segs) == 1L) {
      tree[seg] <- list(value)                      # NULL bleibt als Loeschanweisung erhalten
      return(tree)
    }
    child <- if (utl_has_name(tree, seg) && is_map(tree[[seg]])) tree[[seg]] else list()
    tree[seg] <- list(insert(child, segs[-1L], value))
    tree
  }
  tree <- overrides[!dotted]
  for (i in which(dotted)) {
    tree <- insert(tree, path_split(names(overrides)[i]), overrides[[i]])
  }
  tree
}

#' Overrides (Schicht 8) auf eine Spezifikation anwenden
#'
#' Trägt die Spezifikation ihren Auflösungszustand (`attr(spec, "scn_state")`), wird die
#' Variante mit den zusammengeführten Overrides neu aufgelöst (Ableitungsregeln und Expander je
#' Override neu, 4.7); sonst werden die Overrides gemischt und normalisiert.
#' @param spec `vofi_spec`.
#' @param overrides Overrides (Baum- oder Pfadform).
#' @return `vofi_spec`.
#' @noRd
scn_apply_overrides <- function(spec, overrides) {
  tree <- scn_overrides_tree(overrides)
  st <- attr(spec, "scn_state")
  if (!is.null(st) && inherits(st$scenario, "vofi_scenario")) {
    ov <- if (is.null(st$overrides)) tree else scn_merge_overrides(st$overrides, tree)
    return(vofi_resolve(st$scenario, variant = st$variant, overrides = ov,
                        scenario_set = st$scenario_set))
  }
  prov <- attr(spec, "provenance")
  keep <- attributes(spec)[setdiff(names(attributes(spec)), c("names", "class", "provenance"))]
  x <- unclass(spec)
  attributes(x) <- list(names = names(x))
  x <- scn_normalize(scn_merge(x, tree))
  x <- scn_type_defaults(x, NULL)
  out <- new_vofi_spec(x, provenance = prov)
  for (a in names(keep)) attr(out, a) <- keep[[a]]
  out
}

# ---------------------------------------------------------------------------------------------
# Ableitungsregeln (4.7, R-86, R-113; Spec 01 Teil A 1.4, 4.5.1, 4.6.1, Teil B 5.5)
# ---------------------------------------------------------------------------------------------

#' Ableitungsregeln in Ausführungsreihenfolge
#'
#' Teil A in der Reihenfolge der Tabelle 1.4 (Schritt 6 von `rule:measure_catalog` nach
#' `rule:cost_from_kg`), danach Teil B 5.5.
#' @return benannte Liste von Funktionen `function(x, ctx)` -> `x`.
#' @noRd
scn_rules <- function() {
  list(
    tax_regime = scn_rule_tax_regime, report_mode = scn_rule_report_mode,
    dates = scn_rule_dates, price_base_year = scn_rule_price_base_year,
    project_id = scn_rule_project_id, tenant_view = scn_rule_tenant_view,
    building_aggregates = scn_rule_building_aggregates,
    first_occupancy = scn_rule_first_occupancy, measure_catalog = scn_rule_measure_catalog,
    cost_from_kg = scn_rule_cost_from_kg, measure_kind = scn_rule_measure_kind,
    maintenance_from = scn_rule_maintenance_from,
    unit_group_defaults = scn_rule_unit_group_defaults,
    carrier_defaults = scn_rule_carrier_defaults, approval_timing = scn_rule_approval_timing,
    approval_probability = scn_rule_approval_probability,
    tax_credit_defaults = scn_rule_tax_credit_defaults
  )
}

#' Zielfelder der Ableitungsregeln je Elternpfad ohne ids (R-112, `var_template_fields()`)
#' @noRd
scn_rule_fields <- function() {
  list(
    meta = "project_id",
    project = c("tax_regime", "report_mode", "application_date", "legal_state",
                "price_base_year"),
    analysis = "tenant_view",
    building = c("n_units", "living_area_m2", "land_value_eur", "market_value_eur",
                 "first_occupancy_year"),
    "building.maintenance" = c("start_event", "basis"),
    measures = c("kg", "asset_type", "ohnehin_share", "modernization_kind", "vat_rate",
                 "useful_life_years", "kg700_share", "contingency_share", "notary_share",
                 "land_registry_share", "broker_share", "other_share", "uniform_contract",
                 "classification", "price_base_year", "completion_date", "paid_in_full_date",
                 "follows_construction", "construction_delay_mode", "land_share",
                 "uniform_contract_measures", "ancillary_date", "kwp", "cost_eur",
                 "replacement", "effects"),
    "measures.replacement" = "enabled",
    "measures.effects" = "residual",
    "measures.effects.residual" = "modernization_points",
    "building.elements" = c("kg", "asset_type", "vat_rate", "useful_life_years",
                            "price_base_year"),
    unit_groups = c("owner_occupied", "rent_regime", "vacancy_rate", "rent_default_rate",
                    "lease_up_months", "operating"),
    "unit_groups.operating" = c("admin_per_unit_eur_pa", "admin_per_parking_eur_pa",
                                "nonrecoverable_share_of_rent"),
    "energy.carriers" = c("class", "network_fee_eur_kwh", "emission_factor_kg_kwh",
                          "ghg_factor_kg_kwh"),
    funding = c("approval_timing", "approval_probability", "payout_delay_months")
  )
}

#' Ableitungsregeln ausführen (nach Schicht 8, vor item_defaults)
#' @noRd
scn_run_rules <- function(x, ctx) {
  ctx$explicit_class <- scn_explicit_fields(x, "measures", "classification")
  ctx$explicit_rate <- !is.null(x$building$maintenance$rate_eur_m2_pa)
  ctx$catalog_set <- character(0)
  rules <- scn_rules()
  for (nm in names(rules)) {
    ctx$rule <- nm
    x <- rules[[nm]](x, ctx)
  }
  ctx$rule <- NULL
  if (length(ctx$catalog_set) > 0L) {
    fields <- utl_sort(unique(ctx$catalog_set))
    scn_signal("inform", "validation.measures.catalog_defaults", "io.rule.catalog_defaults",
               path = "measures", fields = utl_collapse(fields), variant = ctx$variant,
               n = length(fields), value = utl_collapse(utils::head(fields, 10L)))
  }
  x
}

#' Ids der Sammlungselemente, die ein Feld vor den Regeln ausdrücklich tragen
#' @noRd
scn_explicit_fields <- function(x, coll, field) {
  els <- x[[coll]] %||% list()
  names(els)[vapply(els, function(e) is_map(e) && !is.null(e[[field]]), logical(1))]
}

#' Wert einer Ableitungsregel in Knotenform (Zahlen double -> const; sonst unverändert)
#' @noRd
scn_rule_value <- function(v) {
  if (is.double(v) && length(v) == 1L && is.null(names(v)) && !inherits(v, "Date")) {
    return(node_const(v))
  }
  v
}

#' Fehlendes Blatt durch eine Regel setzen (Herkunft Schicht 0, `type_default`)
#' @param x Spezifikation.
#' @param path Zielpfad.
#' @param value Wert (Zahl, Code, Knoten, Map).
#' @param ctx Kontext.
#' @param entry `NULL` (= `"rule:<name>"`) oder Bibliotheks-id.
#' @param quality Qualitätsstufe (Bibliothekswerte).
#' @param auto Code `auto` gilt als fehlend (Enum-Felder).
#' @return `x`.
#' @noRd
scn_rule_set <- function(x, path, value, ctx, entry = NULL, quality = NA_character_,
                         auto = FALSE) {
  if (is.null(value)) return(x)
  cur <- path_get(x, path)
  if (!is.null(cur) && !(auto && identical(cur, "auto"))) return(x)
  value <- scn_rule_value(value)
  x <- path_set(x, path, value)
  ctx$derived <- c(ctx$derived, path)
  rec <- if (!is.null(entry) && utl_is_library_id(entry)) lib_get(ctx$index, entry) else NULL
  info <- prv_info(0L, "type_default", file = rec$file %||% NA_character_,
                   entry = entry %||% paste0("rule:", ctx$rule), valid_from = rec$valid_from,
                   valid_to = rec$valid_to, as_of = rec$as_of, accessed = rec$accessed,
                   quality = if (is.na(quality)) rec$quality %||% NA_character_ else quality)
  prv_record_tree(ctx$prv, value, path, info)
  if (identical(ctx$rule, "measure_catalog") || identical(ctx$rule, "measure_kind")) {
    ctx$catalog_set <- c(ctx$catalog_set, path_last_segs(path))
  }
  x
}

#' Pfad ohne Element-id für Meldungen (`measures.wp.kg` -> `kg`)
#' @noRd
path_last_segs <- function(path) {
  segs <- path_split(path)
  if (length(segs) >= 3L && segs[1L] %in% c("measures", "building")) {
    return(paste(segs[-seq_len(if (identical(segs[1L], "building")) 3L else 2L)],
                 collapse = "."))
  }
  path
}

#' Deterministischer Zahlenwert eines Blatts (Zahl oder const-Knoten), sonst `NULL`
#' @noRd
scn_num <- function(v) {
  if (node_is(v) && identical(v$kind, "const")) return(as.double(v$value))
  if (is.numeric(v) && length(v) == 1L && !is.na(v)) return(as.double(v))
  NULL
}

#' Datumswert eines Blatts (Date, ISO-Zeichenkette, Jahr), sonst `NULL`
#' @noRd
scn_date <- function(v) {
  if (is.null(v)) return(NULL)
  out <- tryCatch(node_timing(if (node_is(v)) scn_num(v) else v, ""), error = function(e) NULL)
  if (inherits(out, "Date")) out else NULL
}

#' Basisfallwert eines numerischen Pfads (n = 1, ohne Ziehungen; R-113) oder `NULL`
#' @noRd
scn_value_base <- function(spec, grid, path, shape = c("scalar", "path")) {
  shape <- utl_match_arg(shape, c("scalar", "path"), "shape")
  if (is.null(grid)) return(NULL)
  rc <- res_context(spec, grid, 1L)
  out <- res_value(rc, path, shape, base = TRUE)
  if (is.null(out)) return(NULL)
  if (identical(shape, "scalar")) as.double(out)[1L] else out
}

#' Zeitraster der teilaufgelösten Spezifikation (oder `NULL`, wenn nicht bildbar)
#' @noRd
scn_grid <- function(x) {
  p <- x$project %||% list()
  g <- x$grid %||% list()
  int <- function(v, d) {
    n <- scn_num(v)
    if (is.null(n)) {
      if (is.integer(v) && length(v) == 1L) return(v)
      return(d)
    }
    as.integer(n)
  }
  vd <- scn_date(p$valuation_date)
  hy <- int(p$horizon_years, NA_integer_)
  if (is.null(vd) || is.na(hy)) return(NULL)
  tryCatch(
    vofi_time_grid(vd, hy, construction_months = int(g$construction_months, 0L),
                   construction_step_months = int(g$construction_step_months, 12L),
                   operation_step_months = int(g$operation_step_months, 12L),
                   operation_alignment = g$operation_alignment %||% "calendar",
                   periods_months = g$periods_months,
                   start_year = scn_num(x$stochastic$settings$start_year)),
    error = function(e) NULL
  )
}

#' Ist die Projektart ein Neubauprojekt (`neubau`, `erwerb_neubau`)?
#' @noRd
scn_is_newbuild <- function(x) {
  isTRUE(x$project$project_type %in% c("neubau", "erwerb_neubau"))
}

#' Bibliothekseintrag für Regeln und `bctx$lib()` (Kette aufgelöst; `NULL`, wenn er fehlt)
#' @noRd
scn_lib <- function(ctx, id) {
  pl <- tryCatch(lib_payload(ctx$index, id, path = paste0("lib:", id), cache = ctx$lc$cache),
                 vofi_error = function(e) NULL)
  if (is.null(pl)) {
    if (!(id %in% ctx$lib_missing)) {
      ctx$lib_missing <- c(ctx$lib_missing, id)
      vofi_inform("io.rule.library_missing", rule = paste0("rule:", ctx$rule %||% ""), id = id)
    }
    return(NULL)
  }
  ctx$lib_calls <- unique(c(ctx$lib_calls, pl$chain))
  pl$values
}

#' legal/*-Thema zum Rechtsstand der teilaufgelösten Spezifikation (4.10; `NULL` = inaktiv)
#' @noRd
scn_legal <- function(ctx, x, topic) {
  sel <- scn_legal_all(x, ctx)
  sel[[topic]]
}

#' Alle legal/*-Themen zum Rechtsstand (zwischengespeichert je Rechtsstand und Reformliste)
#' @noRd
scn_legal_all <- function(x, ctx) {
  ls <- scn_date(x$project$legal_state) %||% scn_date(x$project$valuation_date)
  if (is.null(ls)) return(list())
  pending <- as.character(unlist(x$project$pending_reforms %||% character(0)))
  key <- paste(format(ls), paste(utl_sort(pending), collapse = ","), sep = "|")
  hit <- ctx$legal_cache[[key]]
  if (!is.null(hit)) return(hit)
  sel <- lib_select_legal(ctx$index, ls, pending)
  for (tp in names(sel)) {
    if (isTRUE(sel[[tp]]$unreleased)) {
      ctx$notes <- c(ctx$notes, lbl("io.library.unreleased_used", topic = tp,
                                    id = sel[[tp]]$entry))
    }
  }
  ctx$legal_cache[[key]] <- sel
  sel
}

# --- Teil A, Tabelle 1.4 ----------------------------------------------------------------------

#' `rule:tax_regime`: Steuerregime aus der Perspektive (4.3.2)
#' @noRd
scn_rule_tax_regime <- function(x, ctx) {
  persp <- x$project$perspective
  if (!utl_is_string(persp)) return(x)
  scn_rule_set(x, "project.tax_regime", vocab("tax_regime")$from_perspective[[persp]], ctx,
               auto = TRUE)
}

#' `rule:report_mode`: `auto` -> `expert` (wu_*) bzw. `household`
#' @noRd
scn_rule_report_mode <- function(x, ctx) {
  persp <- x$project$perspective
  if (!utl_is_string(persp)) return(x)
  mode <- if (startsWith(persp, "wu_")) "expert" else "household"
  scn_rule_set(x, "project.report_mode", mode, ctx, auto = TRUE)
}

#' `rule:dates`: Antragsdatum und Rechtsstand = Bewertungsstichtag
#' @noRd
scn_rule_dates <- function(x, ctx) {
  vd <- scn_date(x$project$valuation_date)
  if (is.null(vd)) return(x)
  x <- scn_rule_set(x, "project.application_date", vd, ctx)
  scn_rule_set(x, "project.legal_state", vd, ctx)
}

#' `rule:price_base_year`: Jahr(valuation_date) - 1 (R-35)
#' @noRd
scn_rule_price_base_year <- function(x, ctx) {
  vd <- scn_date(x$project$valuation_date)
  if (is.null(vd)) return(x)
  scn_rule_set(x, "project.price_base_year", utl_year(vd) - 1L, ctx)
}

#' `rule:project_id`: meta.project_id = meta.scenario_id
#' @noRd
scn_rule_project_id <- function(x, ctx) {
  id <- x$meta$scenario_id
  if (!utl_is_string(id)) return(x)
  scn_rule_set(x, "meta.project_id", id, ctx)
}

#' `rule:tenant_view`: TRUE für wu_*, sonst FALSE (Rückfall zum Profilwert)
#' @noRd
scn_rule_tenant_view <- function(x, ctx) {
  persp <- x$project$perspective
  if (!utl_is_string(persp)) return(x)
  scn_rule_set(x, "analysis.tenant_view", startsWith(persp, "wu_"), ctx)
}

#' Existiert der Block (nicht leer)?
#' @noRd
scn_has_block <- function(x, b) is_map(x[[b]]) && length(x[[b]]) > 0L

#' `rule:building_aggregates`: Summen über unit_groups als expr; Bodenwert und Marktwert (3.1)
#' @noRd
scn_rule_building_aggregates <- function(x, ctx) {
  if (!scn_has_block(x, "building")) return(x)
  ug <- x$unit_groups %||% list()
  for (f in c("n_units", "living_area_m2")) {
    have <- names(ug)[vapply(ug, function(g) is_map(g) && !is.null(g[[f]]), logical(1))]
    if (length(have) == 0L) next
    txt <- paste(paste0("unit_groups.", have, ".", f), collapse = " + ")
    x <- scn_rule_set(x, path_join("building", f), node_expr(txt), ctx)
  }
  b <- x$building
  if (!is.null(b$land_area_m2) && !is.null(b$land_value_eur_m2)) {
    x <- scn_rule_set(x, "building.land_value_eur",
                      node_expr("building.land_area_m2 * building.land_value_eur_m2"), ctx)
  }
  if (!is.null(b$existing_value_eur)) {
    x <- scn_rule_set(x, "building.market_value_eur", node_ref("building.existing_value_eur"),
                      ctx)
  }
  x
}

#' `rule:first_occupancy`: Baujahr bzw. Jahr der Fertigstellung (Neubau)
#' @noRd
scn_rule_first_occupancy <- function(x, ctx) {
  if (!scn_has_block(x, "building")) return(x)
  if (scn_is_newbuild(x)) {
    g <- scn_grid(x)
    if (is.null(g)) return(x)
    return(scn_rule_set(x, "building.first_occupancy_year",
                        utl_year(g$completion_date - 1L), ctx))
  }
  cy <- scn_num(x$building$construction_year) %||%
    (if (is.integer(x$building$construction_year)) as.double(x$building$construction_year))
  if (is.null(cy)) return(x)
  scn_rule_set(x, "building.first_occupancy_year", as.integer(cy), ctx)
}

#' Erster bzw. letzter Termin einer Maßnahme (`date`, `year` als 1. Januar, Zahlungsplan)
#' @return `list(first, last)` (Date oder `NULL`).
#' @noRd
scn_measure_dates <- function(m) {
  if (!is.null(m$date)) {
    d <- scn_date(m$date)
    return(list(first = d, last = d))
  }
  if (!is.null(m$year)) {
    y <- scn_num(m$year) %||% (if (is.integer(m$year)) as.double(m$year))
    if (!is.null(y)) {
      d <- as.Date(sprintf("%04d-01-01", as.integer(y)))
      return(list(first = d, last = d))
    }
  }
  ps <- m$payment_schedule
  if (node_is(ps) && identical(ps$kind, "schedule") && length(ps$dates) > 0L) {
    return(list(first = min(ps$dates), last = max(ps$dates)))
  }
  list(first = NULL, last = NULL)
}

#' Katalogzeile eines Maßnahmentyps (`costs/massnahmentypen_2026`)
#' @noRd
scn_catalog_row <- function(ctx, type) {
  if (!utl_is_string(type)) return(NULL)
  cat <- scn_lib(ctx, "costs/massnahmentypen_2026")
  cat$types[[type]]
}

#' `rule:measure_catalog` Schritte 1-5 (Spec 01 Teil A 4.5.1)
#' @noRd
scn_rule_measure_catalog <- function(x, ctx) {
  ms <- x$measures %||% list()
  ids <- names(ms)
  cat_id <- "costs/massnahmentypen_2026"
  nd_id <- "costs/nutzungsdauern_2026"
  kz_id <- "costs/kostenzuschlaege_2026"
  en_id <- "costs/erwerbsnebenkosten_2026"
  g <- scn_grid(x)
  newbuild <- scn_is_newbuild(x)
  ptype <- x$project$project_type %||% ""
  pby <- x$project$price_base_year
  # Schritte 1-3 je Maßnahme
  for (m in ids) {
    el <- ms[[m]]
    if (!is_map(el)) next
    p <- function(f) path_join("measures", m, f)
    type <- el$measure_type
    row <- scn_catalog_row(ctx, type)
    erwerb <- isTRUE(type %in% c("erwerb_grundstueck", "erwerb_objekt"))
    if (!is.null(row)) {
      if (!is.null(row$kg)) x <- scn_rule_set(x, p("kg"), as.integer(row$kg), ctx, cat_id)
      if (!is.null(row$asset_type)) {
        x <- scn_rule_set(x, p("asset_type"), as.character(unlist(row$asset_type)), ctx, cat_id)
      }
      if (is.null(el$ohnehin_share) && is.null(el$ohnehin_cost_eur) &&
            !is.null(row$ohnehin_share)) {
        x <- scn_rule_set(x, p("ohnehin_share"), as.double(row$ohnehin_share), ctx, cat_id)
      }
      if (!is.null(row$vat_rate)) {
        pv_type <- isTRUE(type %in% c("pv", "pv_wechselrichter", "batteriespeicher")) ||
          identical(m, x$energy$pv$measure)
        if (!(pv_type && scn_has_pv(x))) {
          x <- scn_rule_set(x, p("vat_rate"), as.double(row$vat_rate), ctx, cat_id)
        }
      }
      if (is_map(row$points) && length(row$points) > 0L) {
        pts <- lapply(row$points, as.integer)
        x <- scn_rule_set(x, p("effects.residual.modernization_points"), pts, ctx, cat_id)
      }
      # Nutzungsdauer: useful_life_key -> costs/nutzungsdauern_2026, sonst Katalogwert
      life <- NULL
      if (!erwerb && !identical(row$useful_life, "main")) {
        if (utl_is_string(row$useful_life_key)) {
          nd <- scn_lib(ctx, nd_id)
          v <- nd[[row$useful_life_key]]
          if (!is.null(v)) {
            rec <- lib_get(ctx$index, nd_id)
            x <- scn_rule_set(x, p("useful_life_years"), as.double(v), ctx, nd_id,
                              quality = lib_quality_of(rec, row$useful_life_key))
            life <- v
          }
        } else if (!is.null(row$useful_life_years)) {
          x <- scn_rule_set(x, p("useful_life_years"), as.double(row$useful_life_years), ctx,
                            cat_id)
          life <- row$useful_life_years
        }
      }
      has_life <- !is.null(life) || !is.null(el$useful_life_years)
      repl <- isTRUE(row$replacement) && has_life && !identical(row$useful_life, "main")
      x <- scn_rule_set(x, p("replacement.enabled"), repl, ctx, cat_id)
    }
    # Zuschläge (Teil A 4.1, 4.5.1 Nr. 1)
    has_kg <- is_map(el$cost_kg) && length(el$cost_kg) > 0L
    kz <- if (has_kg) scn_lib(ctx, kz_id) else NULL
    if (has_kg && is.null(el$cost_kg$kg700) && !is.null(kz$share_kg700_of_kg300_400)) {
      x <- scn_rule_set(x, p("kg700_share"), as.double(kz$share_kg700_of_kg300_400), ctx, kz_id)
    } else {
      x <- scn_rule_set(x, p("kg700_share"), 0, ctx)
    }
    if (has_kg && !is.null(kz$contingency_share)) {
      x <- scn_rule_set(x, p("contingency_share"), as.double(kz$contingency_share), ctx, kz_id)
    } else {
      x <- scn_rule_set(x, p("contingency_share"), 0, ctx)
    }
    if (erwerb) {
      en <- scn_lib(ctx, en_id)
      for (f in c("notary_share", "land_registry_share")) {
        if (!is.null(en[[f]])) {
          rec <- lib_get(ctx$index, en_id)
          x <- scn_rule_set(x, p(f), as.double(en[[f]]), ctx, en_id,
                            quality = lib_quality_of(rec, f))
        }
      }
      x <- scn_rule_set(x, p("broker_share"), 0, ctx)
      x <- scn_rule_set(x, p("other_share"), 0, ctx)
      x <- scn_rule_set(x, p("uniform_contract"), FALSE, ctx)
    }
    # Schritt 2: Projektart und Termine
    cls <- if (newbuild) {
      "herstellung"
    } else if (identical(ptype, "erwerb_sanierung")) {
      "auto"
    } else {
      ce <- row$classification_existing
      if (utl_is_string(ce) && !identical(ce, "main")) ce else NULL
    }
    if (!is.null(cls)) x <- scn_rule_set(x, p("classification"), cls, ctx)
    if (!is.null(pby)) x <- scn_rule_set(x, p("price_base_year"), pby, ctx)
    md <- scn_measure_dates(el)
    if (!is.null(md$last)) {
      x <- scn_rule_set(x, p("completion_date"), md$last, ctx)
      x <- scn_rule_set(x, p("paid_in_full_date"), md$last, ctx)
    }
    if (erwerb) {
      if (identical(type, "erwerb_grundstueck")) {
        x <- scn_rule_set(x, p("land_share"), 1, ctx)
      } else if (!is.null(x$building$land_value_eur)) {
        x <- scn_rule_set(x, p("land_share"),
                          node_expr(paste0("building.land_value_eur / measures.", m,
                                           ".purchase_price_eur")), ctx)
      }
      if (!is.null(md$first)) x <- scn_rule_set(x, p("ancillary_date"), md$first, ctx)
    }
    follows <- isTRUE(type %in% c("neubau", "erweiterung", "aufstockung"))
    if (!follows && !is.null(g) && isTRUE(g$settings$construction_months > 0L)) {
      cd <- scn_date(x$measures[[m]]$completion_date)
      follows <- !is.null(cd) && identical(cd, g$completion_date)
    }
    x <- scn_rule_set(x, p("follows_construction"), follows, ctx)
    fc <- isTRUE(x$measures[[m]]$follows_construction)
    x <- scn_rule_set(x, p("construction_delay_mode"), if (fc) "stretch" else "none", ctx)
  }
  # Erwerb: einheitlicher Vertragsgegenstand
  ms <- x$measures %||% list()
  follow_ids <- names(ms)[vapply(ms, function(e) isTRUE(e$follows_construction), logical(1))]
  for (m in names(ms)) {
    if (isTRUE(ms[[m]]$measure_type %in% c("erwerb_grundstueck", "erwerb_objekt"))) {
      x <- scn_rule_set(x, path_join("measures", m, "uniform_contract_measures"), follow_ids,
                        ctx)
    }
  }
  # Schritt 4: Nutzungsdauer der Hauptmaßnahme (X-26)
  ms <- x$measures %||% list()
  main <- names(ms)[vapply(ms, function(e) {
    isTRUE(e$follows_construction) && !is.null(e$useful_life_years)
  }, logical(1))]
  for (m in names(ms)) {
    row <- scn_catalog_row(ctx, ms[[m]]$measure_type)
    if (!identical(row$useful_life, "main")) next
    h <- setdiff(main, m)
    target <- if (length(h) > 0L) {
      paste0("measures.", h[1L], ".useful_life_years")
    } else {
      "residual_value.income_value.gnd_years"
    }
    x <- scn_rule_set(x, path_join("measures", m, "useful_life_years"), node_ref(target), ctx)
    x <- scn_rule_set(x, path_join("measures", m, "replacement.enabled"), FALSE, ctx)
    if (identical(row$classification_existing, "main") && !scn_is_newbuild(x) &&
          length(h) > 0L) {
      x <- scn_rule_set(x, path_join("measures", m, "classification"),
                        x$measures[[h[1L]]]$classification %||% "auto", ctx)
    }
  }
  # Schritt 3: Bestandsbauteile
  els <- x$building$elements %||% list()
  for (e in names(els)) {
    row <- scn_catalog_row(ctx, els[[e]]$measure_type)
    p <- function(f) path_join("building.elements", e, f)
    if (!is.null(row)) {
      if (!is.null(row$kg)) x <- scn_rule_set(x, p("kg"), as.integer(row$kg), ctx, cat_id)
      if (!is.null(row$asset_type)) {
        x <- scn_rule_set(x, p("asset_type"), as.character(unlist(row$asset_type)), ctx, cat_id)
      }
      if (!is.null(row$vat_rate)) {
        x <- scn_rule_set(x, p("vat_rate"), as.double(row$vat_rate), ctx, cat_id)
      }
      if (utl_is_string(row$useful_life_key)) {
        nd <- scn_lib(ctx, nd_id)
        v <- nd[[row$useful_life_key]]
        if (!is.null(v)) {
          rec <- lib_get(ctx$index, nd_id)
          x <- scn_rule_set(x, p("useful_life_years"), as.double(v), ctx, nd_id,
                            quality = lib_quality_of(rec, row$useful_life_key))
        }
      } else if (!is.null(row$useful_life_years)) {
        x <- scn_rule_set(x, p("useful_life_years"), as.double(row$useful_life_years), ctx,
                          cat_id)
      }
    }
    if (!is.null(pby)) x <- scn_rule_set(x, p("price_base_year"), pby, ctx)
  }
  scn_rule_pv(x, ctx)
}

#' Gibt es den Block `energy.pv`?
#' @noRd
scn_has_pv <- function(x) is_map(x$energy$pv) && length(x$energy$pv) > 0L

#' `rule:measure_catalog` Schritt 5: PV-Umsatzsteuer und PV-Leistung (X-25, Spec 00 7.10)
#' @noRd
scn_rule_pv <- function(x, ctx) {
  ms <- x$measures %||% list()
  pv_measure <- x$energy$pv$measure
  pv_ids <- names(ms)[vapply(names(ms), function(m) {
    isTRUE(ms[[m]]$measure_type %in% c("pv", "pv_wechselrichter", "batteriespeicher")) ||
      identical(m, pv_measure)
  }, logical(1))]
  if (length(pv_ids) == 0L) return(x)
  unchecked <- function() {
    scn_signal("inform", "validation.measures.pv_vat_unchecked", "io.rule.pv_vat_unchecked",
               measures = utl_collapse(pv_ids),
               path = utl_collapse(paste0("measures.", pv_ids, ".vat_rate")))
  }
  if (!scn_has_pv(x)) {
    unchecked()
    return(x)
  }
  ust <- scn_legal(ctx, x, "umsatzsteuer")
  s <- ust$values$pv_zero_rate$max_kwp_without_proof
  if (is.null(s)) {
    unchecked()
    for (m in pv_ids) {
      row <- scn_catalog_row(ctx, ms[[m]]$measure_type)
      if (!is.null(row$vat_rate)) {
        x <- scn_rule_set(x, path_join("measures", m, "vat_rate"), as.double(row$vat_rate),
                          ctx, "costs/massnahmentypen_2026")
      }
    }
  } else {
    txt <- paste0("ifelse(energy.pv.kwp <= ", io_fmt_num(s),
                  " | energy.pv.vat_zero_rate_attested, 0, 0.19)")
    g <- scn_grid(x)
    kwp <- tryCatch(scn_value_base(x, g, "energy.pv.kwp"), error = function(e) NULL)
    attested <- isTRUE(x$energy$pv$vat_zero_rate_attested)
    derived <- if (is.null(kwp)) NULL else if (kwp <= s || attested) 0 else 0.19
    for (m in pv_ids) {
      path <- path_join("measures", m, "vat_rate")
      cur <- path_get(x, path)
      if (is.null(cur)) {
        x <- scn_rule_set(x, path, node_expr(txt), ctx, ust$entry)
      } else if (!is.null(derived)) {
        given <- tryCatch(scn_value_base(x, g, path), error = function(e) NULL)
        if (!is.null(given) && abs(given - derived) > 1e-12) {
          scn_signal("warn", "validation.measures.pv_vat_conflict", "io.rule.pv_vat_conflict",
                     path = path, value = given, derived = derived, expected = derived,
                     .class = "vofi_warning_plausibility")
        }
      }
    }
  }
  if (utl_is_string(pv_measure) && pv_measure %in% names(ms)) {
    x <- scn_rule_set(x, path_join("measures", pv_measure, "kwp"), node_ref("energy.pv.kwp"),
                      ctx)
  }
  x
}

#' Zahl als Literal eines Ausdrucks
#' @noRd
scn_expr_num <- function(v) {
  s <- io_fmt_num(v)
  if (startsWith(s, "-")) paste0("(", s, ")") else s
}

#' Element eines Zahlungsplans bzw. Mengenbezugs als Ausdruckstext (Teil A 4.6.1, X-28)
#' @param el Zahl bzw. Knoten.
#' @param m Maßnahmen-id (Bezugsobjekt des Mengenbezugs).
#' @param x Spezifikation.
#' @param path Pfad für Meldungen.
#' @return Zeichenkette.
#' @noRd
scn_expr_term <- function(el, m, x, path) {
  if (is.numeric(el)) return(scn_expr_num(el))
  bad <- function(kind) {
    scn_signal("abort", "validation.measures.schedule_amount_form", "io.schedule_amount_form",
               path = path, kind = kind, form = kind, .class = "vofi_error_validation")
  }
  if (!node_is(el)) bad(utl_collapse(class(el)))
  switch(el$kind,
    const = scn_expr_num(el$value),
    expr = paste0("(", el$text, ")"),
    ref = {
      t <- el$path
      if (!identical(el$scale, 1) || !identical(el$offset, 0)) {
        t <- paste0("(", scn_expr_num(el$scale), " * ", t, " + ", scn_expr_num(el$offset), ")")
      }
      if (is.finite(el$floor)) t <- paste0("pmax(", t, ", ", scn_expr_num(el$floor), ")")
      if (is.finite(el$cap)) t <- paste0("pmin(", t, ", ", scn_expr_num(el$cap), ")")
      t
    },
    quantity = {
      v <- el$value
      if (!(is.numeric(v) || (node_is(v) && v$kind %in% c("const", "ref", "expr")))) {
        bad(if (node_is(v)) v$kind else "value")
      }
      ref <- scn_quantity_ref(el$per, m, x, path)
      if (is.null(ref)) return(scn_expr_term(v, m, x, path))
      paste0("(", scn_expr_term(v, m, x, path), " * ", ref, ")")
    },
    bad(el$kind)
  )
}

#' Bezugspfad eines Mengenbezugs an einer Maßnahme (Spec 01 Teil A 3.5)
#' @return Pfad bzw. `NULL` bei `per: total`; Fehler, wenn die Bezugsgröße fehlt.
#' @noRd
scn_quantity_ref <- function(per, m, x, path) {
  if (identical(per, "total")) return(NULL)
  field <- scn_quantity_field(per)
  own <- path_join("measures", m, field)
  if (path_exists(x, own)) return(own)
  if (!(per %in% c("kw", "kwp", "kwh"))) {
    b <- path_join("building", field)
    if (path_exists(x, b)) return(b)
  }
  scn_signal("abort", "validation.quantity.reference_missing", "io.quantity_reference_missing",
             path = path, per = per, .class = "vofi_error_validation")
}

#' Bezugsgrößen aller Mengenbezüge prüfen (Spec 01 Teil A 3.5, Prüffälle Q5, Q7)
#'
#' Nach den Ableitungsregeln und `item_defaults`, vor den Expandern: Für jeden Knoten
#' `{value, per}` der Domäne (auch Beträge eines Zahlungsplans) muss die Bezugsgröße am
#' Bezugsobjekt (nächster Vorfahre mit dem Feld, z. B. `measures.<m>`, `unit_groups.<g>`,
#' `building.elements.<e>`, die Komponente) oder in `building` stehen; `kw`, `kwp` und `kwh` haben
#' keinen Rückfall auf `building`. Sonst E `validation.quantity.reference_missing`.
#' @param x teilaufgelöste Spezifikation.
#' @return `invisible(TRUE)`.
#' @noRd
scn_check_quantities <- function(x) {
  blocks <- c("building", "household", "unit_groups", "measures", "energy", "funding",
              "components", "financing", "accounts", "market", "residual_value", "shared")
  hits <- unlist(lapply(intersect(blocks, names(x)), function(b) {
    scn_quantity_nodes(x[[b]], b)
  }), recursive = FALSE)
  for (h in hits) {
    if (identical(h$per, "total") || !utl_is_string(h$per)) next
    if (is.null(scn_quantity_target(x, h$path, h$per))) {
      scn_signal("abort", "validation.quantity.reference_missing",
                 "io.quantity_reference_missing", path = h$path, per = h$per,
                 .class = "vofi_error_validation")
    }
  }
  invisible(TRUE)
}

#' Feld der Bezugsgröße eines Mengenbezugs (Spec 00 4.5, R-91; `per` ist nach
#' `node_quantity_per()` geprüft)
#' @noRd
scn_quantity_field <- function(per) {
  if (startsWith(per, "m2_component:")) {
    return(paste0("component_areas_m2.", sub("^m2_component:", "", per)))
  }
  switch(per, unit = "n_units", m2_living_area = "living_area_m2",
         m2_net_floor_area = "net_floor_area_m2", parking = "n_parking", per)
}

#' Mengenbezüge eines Teilbaums (Pfad und `per`; Beträge eines Zahlungsplans eingeschlossen)
#' @noRd
scn_quantity_nodes <- function(x, path) {
  if (node_is(x)) {
    if (identical(x$kind, "quantity")) return(list(list(path = path, per = x$per)))
    if (identical(x$kind, "schedule") && is.list(x$amounts)) {
      return(unlist(lapply(seq_along(x$amounts), function(i) {
        scn_quantity_nodes(x$amounts[[i]], path_join(path, "schedule", i))
      }), recursive = FALSE))
    }
    return(list())
  }
  if (!is_map(x) || length(x) == 0L) return(list())
  unlist(lapply(names(x), function(nm) scn_quantity_nodes(x[[nm]], path_join(path, nm))),
         recursive = FALSE)
}

#' Pfad der Bezugsgröße eines Mengenbezugs oder `NULL` (Spec 01 Teil A 3.5, R-91)
#' @noRd
scn_quantity_target <- function(x, path, per) {
  field <- scn_quantity_field(per)
  segs <- path_split(path)
  for (k in rev(seq_len(length(segs) - 1L))) {
    cand <- path_join(paste(segs[seq_len(k)], collapse = "."), field)
    if (!is.null(path_get(x, cand))) return(cand)
  }
  if (per %in% c("kw", "kwp", "kwh")) return(NULL)
  fb <- paste0("building.", field)
  if (!is.null(path_get(x, fb))) fb else NULL
}

#' `rule:cost_from_kg`: abgeleitetes `cost_eur` (K0 nach 4.6.2 (1) bzw. Summe des
#' Zahlungsplans mit `unit: eur`; Teil A 4.6.1, X-28)
#' @noRd
scn_rule_cost_from_kg <- function(x, ctx) {
  ms <- x$measures %||% list()
  for (m in names(ms)) {
    el <- ms[[m]]
    if (!is_map(el) || !is.null(el$cost_eur)) next
    pre <- paste0("measures.", m, ".")
    if (is_map(el$cost_kg) && length(el$cost_kg) > 0L) {
      kgs <- intersect(paste0("kg", c(200, 300, 400, 500, 600, 700)), names(el$cost_kg))
      s <- function(k) if (k %in% kgs) paste0(pre, "cost_kg.", k) else NULL
      sum_of <- function(ks) {
        terms <- unlist(lapply(ks, s))
        if (length(terms) == 0L) "0" else paste0("(", paste(terms, collapse = " + "), ")")
      }
      b700 <- if (identical(el$kg700_basis %||% "kg300_400", "kg200_600")) {
        sum_of(paste0("kg", c(200, 300, 400, 500, 600)))
      } else {
        sum_of(c("kg300", "kg400"))
      }
      s6 <- sum_of(paste0("kg", c(200, 300, 400, 500, 600)))
      k700 <- paste0("(", if ("kg700" %in% kgs) paste0(pre, "cost_kg.kg700") else "0", " + ",
                     pre, "kg700_share * ", b700, ")")
      bc <- if (identical(el$contingency_basis %||% "kg200_700", "kg200_600")) s6 else
        paste0("(", s6, " + ", k700, ")")
      txt <- paste0(s6, " + ", k700, " + ", pre, "contingency_share * ", bc)
      x <- scn_rule_set(x, paste0(pre, "cost_eur"), node_expr(txt), ctx)
      next
    }
    ps <- el$payment_schedule
    if (node_is(ps) && identical(ps$kind, "schedule") && identical(ps$unit, "eur")) {
      am <- ps$amounts
      els <- if (is.numeric(am)) as.list(am) else am
      terms <- vapply(seq_along(els), function(i) {
        scn_expr_term(els[[i]], m, x, paste0(pre, "payment_schedule.schedule.", i))
      }, "")
      x <- scn_rule_set(x, paste0(pre, "cost_eur"), node_expr(paste(terms, collapse = " + ")),
                        ctx)
    }
  }
  x
}

#' `rule:measure_catalog` Schritt 6: `modernization_kind` (X-09, R-113)
#'
#' Fehlt der Code, gilt `none` bei ausdrücklicher `classification: erhaltung` oder einem
#' Ohnehin-Anteil von 1 im Basisfall (`bctx$value_base()`), sonst der Katalogwert bzw. `none`.
#' @noRd
scn_rule_measure_kind <- function(x, ctx) {
  ctx$rule <- "measure_catalog"
  ms <- x$measures %||% list()
  g <- scn_grid(x)
  from_class <- character(0)
  for (m in names(ms)) {
    el <- ms[[m]]
    if (!is_map(el)) next
    full <- scn_ohnehin_full(x, g, m)
    if (!is.null(el$modernization_kind)) {
      if (isTRUE(full) && !identical(el$modernization_kind, "none")) {
        scn_signal("warn", "validation.measures.kind_ohnehin_conflict",
                   "io.rule.kind_ohnehin_conflict", measure = m,
                   path = path_join("measures", m, "modernization_kind"),
                   value = el$modernization_kind, .class = "vofi_warning_plausibility")
      }
      next
    }
    explicit <- m %in% ctx$explicit_class && identical(el$classification, "erhaltung")
    if (explicit || isTRUE(full)) {
      x <- scn_rule_set(x, path_join("measures", m, "modernization_kind"), "none", ctx)
      from_class <- c(from_class, m)
      next
    }
    row <- scn_catalog_row(ctx, el$measure_type)
    if (utl_is_string(row$modernization_kind)) {
      x <- scn_rule_set(x, path_join("measures", m, "modernization_kind"),
                        row$modernization_kind, ctx, "costs/massnahmentypen_2026")
    } else {
      x <- scn_rule_set(x, path_join("measures", m, "modernization_kind"), "none", ctx)
    }
  }
  if (length(from_class) > 0L) {
    scn_signal("inform", "validation.measures.kind_from_classification",
               "io.rule.kind_from_classification", measures = utl_collapse(from_class),
               path = utl_collapse(paste0("measures.", from_class, ".modernization_kind")))
  }
  x
}

#' Ohnehin-Anteil 1 im Basisfall? (`ohnehin_share` = 1 bzw. `ohnehin_cost_eur` >= K0)
#' @noRd
scn_ohnehin_full <- function(x, g, m) {
  el <- x$measures[[m]]
  base <- function(f) {
    tryCatch(scn_value_base(x, g, path_join("measures", m, f)), error = function(e) NULL)
  }
  if (!is.null(el$ohnehin_share)) {
    v <- base("ohnehin_share")
    return(!is.null(v) && abs(v - 1) < 1e-12)
  }
  if (!is.null(el$ohnehin_cost_eur)) {
    oc <- base("ohnehin_cost_eur")
    k0 <- base("cost_eur")
    if (is.null(oc) || is.null(k0)) return(FALSE)
    if (is.null(el$cost_kg)) k0 <- k0 * (1 + (base("contingency_share") %||% 0))
    return(oc >= k0 - 1e-9)
  }
  FALSE
}

#' `rule:maintenance_from`: Beginn und Basis der Instandhaltung (Teil A 3.3, F-22)
#' @noRd
scn_rule_maintenance_from <- function(x, ctx) {
  if (!scn_has_block(x, "building")) return(x)
  newbuild <- scn_is_newbuild(x)
  ptype <- x$project$project_type %||% ""
  start <- if (newbuild) {
    "completion"
  } else if (startsWith(ptype, "erwerb_")) {
    ms <- x$measures %||% list()
    acq <- names(ms)[vapply(ms, function(e) {
      isTRUE(e$measure_type %in% c("erwerb_grundstueck", "erwerb_objekt"))
    }, logical(1))]
    d <- if (length(acq) > 0L) scn_measure_dates(ms[[acq[1L]]])$first else NULL
    d %||% scn_date(x$project$valuation_date)
  } else {
    scn_date(x$project$valuation_date)
  }
  x <- scn_rule_set(x, "building.maintenance.start_event", start, ctx, auto = TRUE)
  basis <- if (isTRUE(ctx$explicit_rate)) "rate" else if (newbuild) "iibv" else "rate"
  scn_rule_set(x, "building.maintenance.basis", basis, ctx, auto = TRUE)
}

# --- Teil B, 5.5 ------------------------------------------------------------------------------

#' `rule:unit_group_defaults` (Teil B 5.5, N-08, N-08a)
#' @noRd
scn_rule_unit_group_defaults <- function(x, ctx) {
  persp <- x$project$perspective %||% ""
  ug <- x$unit_groups %||% list()
  if (length(ug) == 0L && identical(persp, "selbstnutzer") && scn_has_block(x, "building")) {
    main <- list(n_units = node_ref("building.n_units"),
                 living_area_m2 = node_ref("building.living_area_m2"), owner_occupied = TRUE)
    x <- scn_rule_set(x, "unit_groups.main", main, ctx)
    ug <- x$unit_groups
  }
  if (length(ug) == 0L) return(x)
  bound <- character(0)
  for (f in x$funding %||% list()) {
    if (identical(f$instrument_type, "rent_binding")) {
      bound <- c(bound, as.character(unlist(f$unit_groups)))
    }
  }
  bv <- NULL
  for (g in names(ug)) {
    p <- function(f) path_join("unit_groups", g, f)
    x <- scn_rule_set(x, p("owner_occupied"), identical(persp, "selbstnutzer"), ctx)
    owner <- isTRUE(x$unit_groups[[g]]$owner_occupied)
    if (owner) {
      x <- scn_rule_set(x, p("rent_regime"), "owner_occupied", ctx)
      for (f in c("vacancy_rate", "rent_default_rate", "operating.admin_per_unit_eur_pa",
                  "operating.admin_per_parking_eur_pa",
                  "operating.nonrecoverable_share_of_rent")) {
        x <- scn_rule_set(x, p(f), 0, ctx)
      }
      next
    }
    if (identical(persp, "wu_genossenschaft")) {
      x <- scn_rule_set(x, p("rent_regime"), "cooperative_fee", ctx)
    }
    if (identical(x$unit_groups[[g]]$rent_regime, "bound_social") || g %in% bound) {
      id <- "costs/bewirtschaftung_ii_bv_2026"
      bv <- bv %||% scn_lib(ctx, id)
      if (!is.null(bv$admin_per_unit_eur_pa)) {
        x <- scn_rule_set(x, p("operating.admin_per_unit_eur_pa"),
                          as.double(bv$admin_per_unit_eur_pa), ctx, id)
      }
      if (!is.null(bv$admin_per_garage_eur_pa)) {
        x <- scn_rule_set(x, p("operating.admin_per_parking_eur_pa"),
                          as.double(bv$admin_per_garage_eur_pa), ctx, id)
      }
    }
    if (scn_is_newbuild(x)) x <- scn_rule_set(x, p("lease_up_months"), 3, ctx)
  }
  x
}

#' Trägerklasse der kanonischen Träger-ids (Teil B 3.2.1)
#' @noRd
scn_carrier_classes <- function() {
  c(gas = "gas", gas_mfh = "gas", oil = "oil", lpg = "lpg", power = "power",
    power_mfh = "power", heatpump_power = "power_hp", heatpump_power_mfh = "power_hp",
    district_heating = "district_heating", pellets = "biomass")
}

#' `rule:carrier_defaults` (Teil B 5.5, Tabelle 3.2.1)
#' @noRd
scn_rule_carrier_defaults <- function(x, ctx) {
  cs <- x$energy$carriers %||% list()
  if (length(cs) == 0L) return(x)
  co2 <- scn_legal(ctx, x, "emission_factors_co2cost")
  geg <- scn_legal(ctx, x, "emission_factors_geg")
  warned <- character(0)
  for (cid in names(cs)) {
    p <- function(f) path_join("energy.carriers", cid, f)
    cls_map <- scn_carrier_classes()
    if (cid %in% names(cls_map)) x <- scn_rule_set(x, p("class"), cls_map[[cid]], ctx)
    fee <- path_join("market.energy_network_fee", cid)
    x <- scn_rule_set(x, p("network_fee_eur_kwh"),
                      if (path_exists(x, fee)) node_ref(fee) else 0, ctx)
    cls <- x$energy$carriers[[cid]]$class
    if (!utl_is_string(cls)) cls <- "other"
    # CO2-Kosten nach BEHG und EBeV
    if (is.null(co2)) {
      x <- scn_rule_set(x, p("emission_factor_kg_kwh"), 0, ctx)
      warned <- c(warned, "emission_factors_co2cost")
    } else {
      key <- switch(cls, gas = "natural_gas_hs", oil = "heating_oil_hi", lpg = "lpg_hi",
                    biomass = "wood", NULL)
      if (identical(cls, "coal")) {
        vofi_warn("io.rule.coal_factor", carrier = cid, .class = "vofi_warning_plausibility")
      }
      v <- if (is.null(key)) 0 else co2$values[[key]]
      if (!is.null(v)) {
        x <- scn_rule_set(x, p("emission_factor_kg_kwh"), as.double(v), ctx,
                          if (is.null(key)) NULL else co2$entry)
      }
    }
    # Treibhausgas (GEG Anlage 9, g/kWh -> kg/kWh)
    if (is.null(geg)) {
      x <- scn_rule_set(x, p("ghg_factor_kg_kwh"), 0, ctx)
      warned <- c(warned, "emission_factors_geg")
    } else {
      gv <- geg$values
      v <- switch(cls,
        gas = {
          conv <- co2$values$conversion$gas_hs_to_hi
          if (is.null(gv$natural_gas) || is.null(conv)) NULL else gv$natural_gas * conv
        },
        oil = gv$heating_oil, lpg = gv$lpg, coal = gv$hard_coal,
        power = , power_hp = gv$electricity_grid,
        district_heating = gv$district_heating_chp$gas_oil, biomass = gv$wood, 0
      )
      if (!is.null(v)) {
        known <- cls %in% c("gas", "oil", "lpg", "coal", "power", "power_hp",
                            "district_heating", "biomass")
        x <- scn_rule_set(x, p("ghg_factor_kg_kwh"),
                          if (known) as.double(v) / 1000 else 0, ctx,
                          if (known) geg$entry else NULL)
      }
    }
  }
  for (tp in unique(warned)) {
    vofi_warn("io.rule.emission_factors_missing", topic = tp,
              .class = "vofi_warning_plausibility")
  }
  x
}

#' Frühester Termin der Maßnahmen (ohne Verschiebung) oder `NULL`
#' @noRd
scn_first_measure_date <- function(x, ids = NULL) {
  ms <- x$measures %||% list()
  if (!is.null(ids)) ms <- ms[intersect(ids, names(ms))]
  ds <- lapply(ms, function(m) scn_measure_dates(m)$first)
  ds <- Filter(Negate(is.null), ds)
  if (length(ds) == 0L) return(NULL)
  do.call(min, unname(ds))
}

#' Antragsdatum eines Förderinstruments (Instrument, sonst Projekt)
#' @noRd
scn_application_date <- function(x, f) {
  scn_date(x$funding[[f]]$application_date) %||% scn_date(x$project$application_date)
}

#' `rule:approval_timing` (Spec 00 4.3.7, R-111)
#' @noRd
scn_rule_approval_timing <- function(x, ctx) {
  fs <- x$funding %||% list()
  for (f in names(fs)) {
    ids <- as.character(unlist(fs[[f]]$measures))
    first <- if (length(ids) > 0L) scn_first_measure_date(x, ids) else scn_first_measure_date(x)
    ad <- scn_application_date(x, f)
    code <- if (is.null(first) || is.null(ad) || ad <= first) "before_start" else "after_start"
    x <- scn_rule_set(x, path_join("funding", f, "approval_timing"), code, ctx, auto = TRUE)
  }
  x
}

#' `rule:approval_probability` (Spec 00 4.3.7, S01B-13)
#' @noRd
scn_rule_approval_probability <- function(x, ctx) {
  fs <- x$funding %||% list()
  for (f in names(fs)) {
    br <- path_join("funding", f, "budget_risk.approval_probability")
    has_br <- path_exists(x, br)
    ad <- scn_application_date(x, f)
    late <- !is.null(ad) && ad >= as.Date("2031-01-01")
    val <- if (late) {
      node_expr(paste0(if (has_br) br else "1", " * funding.", f, ".availability_after_2030"))
    } else if (has_br) {
      node_ref(br)
    } else {
      1
    }
    x <- scn_rule_set(x, path_join("funding", f, "approval_probability"), val, ctx)
  }
  x
}

#' `rule:tax_credit_defaults`: Auszahlungsverzug 12 Monate bei `tax_credit` (Spec 00 10.9)
#' @noRd
scn_rule_tax_credit_defaults <- function(x, ctx) {
  fs <- x$funding %||% list()
  for (f in names(fs)) {
    if (identical(fs[[f]]$instrument_type, "tax_credit")) {
      x <- scn_rule_set(x, path_join("funding", f, "payout_delay_months"), 12, ctx)
    }
  }
  x
}

# ---------------------------------------------------------------------------------------------
# item_defaults (4.7 Nr. 3, R-85, R-118)
# ---------------------------------------------------------------------------------------------

#' Vorlagen `item_defaults` anwenden (nach den Ableitungsregeln, vor den Expandern)
#'
#' In aufsteigender Pfadtiefe; Sammlungen je vorhandenem Element (`element <- deep_merge(vorlage,
#' element)`, Platzhalter `{id}` ersetzt), optionale Blöcke nur, wenn der Block existiert
#' (oberste Blöcke: nicht leer). `from:` in einer Vorlage wird vorher aufgelöst (Herkunft
#' Schicht 1 mit `entry` = Bibliotheks-id), sonst `entry = "global#item_defaults.<pfad>"`.
#' @noRd
scn_apply_item_defaults <- function(x, ctx) {
  items <- ctx$items %||% list()
  if (length(items) == 0L) return(x)
  ip <- scn_item_paths()
  depth <- vapply(names(items), function(p) length(path_split(p)), integer(1))
  ord <- names(items)[order(depth, names(items), method = "radix")]
  gid <- ctx$defaults$global$meta$id %||% "global"
  for (p in ord) {
    is_coll <- p %in% ip$collections
    pseudo <- if (is_coll) paste0(p, ".{id}") else p
    tp <- prv_new()
    tpl <- scn_resolve_template(items[[p]], pseudo, tp, ctx)
    if (is.null(tpl)) next
    info <- prv_info(1L, "global", file = ctx$defaults$global$file %||% "defaults/global.yaml",
                     entry = paste0(gid, "#item_defaults.", p))
    if (is_coll) {
      coll <- path_get(x, p)
      if (!is_map(coll) || length(coll) == 0L || node_is(coll)) next
      # einmal je Vorlage normalisieren, danach je Element nur den Platzhalter {id} ersetzen
      norm <- path_get(scn_normalize(path_set(list(), pseudo, tpl)), pseudo)
      for (id in names(coll)) {
        x <- scn_item_merge(x, path_join(p, id), node_subst_id(norm, id), pseudo, tp, info, ctx,
                            normalized = TRUE)
      }
    } else {
      top <- length(path_split(p)) == 1L
      blk <- path_get(x, p)
      exists <- if (top) is_map(blk) && length(blk) > 0L else path_exists(x, p) && is_map(blk)
      if (!exists) next
      x <- scn_item_merge(x, p, tpl, pseudo, tp, info, ctx)
    }
  }
  x
}

#' Bibliotheksverweise einer Vorlage auflösen (Schicht 1, Herkunft in einem eigenen Speicher)
#' @noRd
scn_resolve_template <- function(tpl, pseudo, tp, ctx) {
  lc <- ctx$lc
  old <- list(prv = lc$prv, layer = lc$layer, mode = lc$mode)
  lc$prv <- tp
  lc$layer <- 1L
  lc$mode <- if (lib_package_available(ctx$index)) "error" else "drop"
  on.exit({
    lc$prv <- old$prv
    lc$layer <- old$layer
    lc$mode <- old$mode
  }, add = TRUE)
  out <- lib_resolve(tpl, pseudo, lc)
  scn_inform_missing(ctx)
  out
}

#' Vorlage unter ein Element mischen (Element gewinnt) und Herkunft der neuen Blätter setzen
#'
#' Die neuen Blätter gelten als abgeleitet (`ctx$derived`): `vofi_write_scenario(resolved =
#' TRUE)` lässt sie weg, weil sie beim Auflösen wieder entstehen.
#' @param normalized Vorlage bereits normalisiert (Sammlungen: einmal je Vorlage)?
#' @noRd
scn_item_merge <- function(x, path, tpl, pseudo, tp, info, ctx, normalized = FALSE) {
  el <- path_get(x, path)
  norm <- if (normalized) tpl else path_get(scn_normalize(path_set(list(), path, tpl)), path)
  merged <- scn_merge(norm, el %||% list(), path)
  before <- scn_leaves(el, path)
  after <- scn_leaves(merged, path)
  x <- path_set(x, path, merged)
  new <- setdiff(after, before)
  if (length(new) == 0L) return(x)
  ctx$derived <- c(ctx$derived, new)
  for (p in new) {
    rel <- substring(p, nchar(path) + 1L)
    hit <- prv_lookup(tp, paste0(pseudo, rel))
    rec <- if (is.null(hit)) {
      info
    } else {
      hit$layer <- 1L
      hit
    }
    prv_set(ctx$prv, p, rec)
  }
  x
}

# ---------------------------------------------------------------------------------------------
# Typ-Defaults (Schicht 0) und Expander (4.12)
# ---------------------------------------------------------------------------------------------

#' Typ-Defaults (Schicht 0) in Komponenten und Finanzierungsbausteine einsetzen
#' @param x Spezifikation.
#' @param ctx `NULL` oder Kontext (Herkunft).
#' @return `x`.
#' @noRd
scn_type_defaults <- function(x, ctx) {
  for (coll in c("components", "financing")) {
    for (id in names(x[[coll]])) {
      comp <- x[[coll]][[id]]
      def <- scn_type_def(comp[["type"]], coll)
      if (is.null(def)) next
      for (p in names(def$params)) {
        pp <- def$params[[p]]
        if (is.null(comp[[p]]) && !is.null(pp$default)) {
          comp[p] <- list(node_normalize(pp$default, pp, path_join(coll, id, p)))
          if (!is.null(ctx)) {
            prv_record_tree(ctx$prv, comp[[p]], path_join(coll, id, p),
                            prv_info(0L, "type_default"))
            ctx$derived <- c(ctx$derived, path_join(coll, id, p))
          }
        }
      }
      for (f in c("label", "description", "origin", "asset_id", "measure_id", "funding_id",
                  "program")) {
        if (!utl_has_name(comp, f)) comp[f] <- list(NULL)
      }
      comp$origin <- comp$origin %||% "scenario"
      comp$after <- comp$after %||% character(0)
      x[[coll]][[id]] <- comp
    }
  }
  x
}

#' Expander in order-Reihenfolge ausführen (4.12)
#'
#' Jeder registrierte Expander, der nach `scn_expander_runs()` anwendbar ist, erhält Block (leer:
#' `list()`), teilaufgelöste Spezifikation und Build-Kontext und liefert `list(components,
#' financing, assets, measures, notes)`. Erzeugte ids dürfen nicht kollidieren; die Herkunft der
#' erzeugten Blätter ist `source_type = "expander"`, `entry = "expander:<name>"`.
#'
#' Mit `tolerant = TRUE` (nur Validierung, `scn_resolve(expand = "tolerant")`) bleibt ein
#' abbrechender Expander ohne Ergebnis, die übrigen laufen weiter; sein Name steht im Attribut
#' `expand_failed` des Ergebnisses.
#' @noRd
scn_run_expanders <- function(x, ctx = NULL, tolerant = FALSE) {
  ex <- reg_list("expander")
  if (nrow(ex) == 0L) return(x)
  defs <- lapply(ex$name, function(nm) reg_get("expander", nm))
  defs <- defs[order(vapply(defs, function(d) as.double(d$order), double(1)),
                     vapply(defs, function(d) d$name, ""), method = "radix")]
  run <- function(d, x) {
    blk <- x[[d$block]] %||% list()
    grid <- scn_grid(x)
    bctx <- scn_bctx(x, grid, roots = ctx$lib_paths, index = ctx$index)
    res <- d$expand(blk, x, bctx)
    scn_merge_expansion(x, res, d$name, ctx)
  }
  failed <- character(0)
  for (d in defs) {
    if (!scn_expander_runs(d, x)) next
    if (!tolerant) {
      x <- run(d, x)
      next
    }
    r <- tryCatch(run(d, x), error = function(e) e)
    if (inherits(r, "error")) failed <- c(failed, d$name) else x <- r
  }
  if (tolerant) attr(x, "expand_failed") <- failed
  x
}

#' Läuft ein Expander? (4.12; Spec 01 Teil A 4.5.2)
#'
#' Ein Expander läuft, wenn sein Block nicht leer ist oder einer der Blöcke aus dem optionalen
#' Typfeld `run_if_blocks` existiert. Der Maßnahmen-Expander (`block = "measures"`) läuft
#' zusätzlich immer, wenn `building` existiert: Er erzeugt dann `m_maintenance` und die Assets
#' `<bid>_building`/`<bid>_land` auch ohne Maßnahmen (z. B. Referenzvariante mit `remove` aller
#' Maßnahmen).
#' @param d Typdefinition (Art `expander`).
#' @param x teilaufgelöste Spezifikation.
#' @return `TRUE`/`FALSE`.
#' @noRd
scn_expander_runs <- function(d, x) {
  extra <- d$run_if_blocks %||% if (identical(d$block, "measures")) "building"
  blocks <- unique(c(d$block, as.character(unlist(extra))))
  any(vapply(blocks, function(b) scn_has_block(x, b), logical(1)))
}

#' Ergebnis eines Expanders übernehmen (Kollisionen sind Validierungsfehler, 4.12 Nr. 3)
#' @noRd
scn_merge_expansion <- function(x, res, name, ctx) {
  if (is.null(res)) return(x)
  if (!is.list(res)) {
    vofi_abort("io.expander_result", expander = name, .class = "vofi_error_contract")
  }
  info <- prv_info(0L, "expander", entry = paste0("expander:", name))
  for (coll in c("components", "financing")) {
    new <- res[[coll]] %||% list()
    for (id in names(new)) {
      if (id %in% c(names(x$components), names(x$financing))) {
        scn_signal("abort", "validation.expander.id_collision", "io.expander_id_collision",
                   id = id, expander = name, path = path_join(coll, id), value = id,
                   .class = "vofi_error_validation")
      }
      comp <- scn_normalize_component(new[[id]], id, coll)
      comp$origin <- comp$origin %||% "expander"
      x[[coll]][[id]] <- comp
      if (!is.null(ctx)) prv_record_tree(ctx$prv, comp, path_join(coll, id), info)
    }
  }
  x$registers$assets <- c(x$registers$assets %||% list(), res$assets %||% list())
  x$registers$measures <- c(x$registers$measures %||% list(), res$measures %||% list())
  if (!is.null(ctx) && length(res$notes) > 0L) {
    ctx$notes <- c(ctx$notes, as.character(unlist(res$notes)))
  }
  x
}

#' Build-Kontext `bctx` der Expander (6.4)
#'
#' Gesperrte Umgebung mit `grid`, `spec` (teilaufgelöst), `project`, `building`,
#' `legal(topic)`, `rule(name)`, `lib(id)`, `period_of(date)`, `period_of_year(year)`,
#' `value_base(path, shape)`, `lbl`, `abort`, `warn`, `inform` und den Knotenkonstruktoren
#' `node_const`, `node_ref`, `node_schedule`, `node_growth`, `node_expr`. Ziehungen gibt es
#' nicht; `rule()`/`legal()` nur auf deterministische Eingaben (4.12 Nr. 5).
#' @param spec teilaufgelöste Spezifikation.
#' @param grid `vofi_grid` (oder `NULL`).
#' @param roots optional: Bibliothekswurzeln (Default `vofi_library_paths()`).
#' @param index optional: Bibliotheksindex.
#' @return Umgebung der Klasse `vofi_bctx`.
#' @noRd
scn_bctx <- function(spec, grid, roots = NULL, index = NULL) {
  idx <- index %||% lib_index(roots %||% vofi_library_paths())
  e <- new.env(parent = emptyenv())
  e$grid <- grid
  e$spec <- spec
  e$project <- spec$project
  e$building <- spec$building
  e$legal <- function(topic) spec$legal[[topic]]$values
  e$rule <- function(name) scn_rule_for(name, spec)
  e$lib <- function(id) {
    pl <- lib_payload(idx, id, path = paste0("bctx$lib(", id, ")"))
    if (is.null(pl)) {
      scn_signal("abort", "validation.library.entry_unknown", "io.library.entry_unknown",
                 path = "bctx", id = id, value = id,
                 suggestion = utl_suggest_text(id, names(idx$entries)),
                 .class = "vofi_error_validation")
    }
    pl$values
  }
  e$period_of <- function(date) grid_period_of(grid, date)
  e$period_of_year <- function(year) grid_period_of_year(grid, year)
  e$value_base <- function(path, shape = c("scalar", "path")) {
    scn_value_base(spec, grid, path, shape)
  }
  e$lbl <- function(key, ...) lbl(key, ...)
  e$abort <- function(key, ..., .class = "vofi_error_validation") {
    vofi_abort(key, ..., .class = .class)
  }
  e$warn <- function(key, ..., .class = "vofi_warning_plausibility") {
    vofi_warn(key, ..., .class = .class)
  }
  e$inform <- function(key, ...) vofi_inform(key, ...)
  e$node_const <- node_const
  e$node_ref <- node_ref
  e$node_schedule <- node_schedule
  e$node_growth <- node_growth
  e$node_expr <- node_expr
  class(e) <- "vofi_bctx"
  lockEnvironment(e, bindings = TRUE)
  e
}

#' Regelversion zum Rechtsstand wählen (4.10; Registry-Art `rule`)
#'
#' Nach demselben Muster wie die `legal/*`-Wahl (`lib_select_legal()`): wählbar sind Versionen
#' mit `valid_from <= legal_state < valid_to`, deren Reformcode (falls gesetzt) in
#' `pending_reforms` steht; Versionen mit Reform haben Vorrang vor Versionen ohne Reform, danach
#' gewinnt das größte `valid_from`.
#' @noRd
scn_rule_for <- function(name, spec) {
  versions <- reg_rules(name)
  ls <- scn_date(spec$project$legal_state) %||% scn_date(spec$project$valuation_date)
  reforms <- as.character(unlist(spec$project$pending_reforms %||% character(0)))
  has_reform <- function(d) utl_is_string(d$reform) && !is.na(d$reform) && nzchar(d$reform)
  ok <- Filter(function(d) {
    (!has_reform(d) || d$reform %in% reforms) && !is.null(ls) && d$valid_from <= ls &&
      (is.null(d$valid_to) || is.na(d$valid_to) || ls < d$valid_to)
  }, versions)
  if (length(ok) == 0L) {
    vofi_abort("io.rule_unknown", rule = name, date = format(ls %||% as.Date(NA)),
               .class = "vofi_error_registry")
  }
  ref <- vapply(ok, has_reform, logical(1))
  if (any(ref)) ok <- ok[ref]
  vf <- vapply(ok, function(d) as.double(d$valid_from), double(1))
  ok[[order(vf, method = "radix")[length(ok)]]]$fun
}

# ---------------------------------------------------------------------------------------------
# Bibliotheksstand, Gültigkeit (4.9, D10, R-80)
# ---------------------------------------------------------------------------------------------

#' Verwendete Bibliothekseinträge (Verweise, Ketten, legal/*-Wahl, `lib()`)
#' @noRd
scn_used_entries <- function(x, ctx) {
  ids <- unlist(lapply(ctx$lc$used, function(u) u$chain), use.names = FALSE)
  ids <- c(ids, unlist(lapply(x$legal %||% list(), function(l) l$chain), use.names = FALSE),
           ctx$lib_calls)
  ids <- unique(as.character(ids))
  ids[vapply(ids, function(id) !is.null(lib_get(ctx$index, id)), logical(1))]
}

#' Bibliotheksstand der Spezifikation (4.13 `library`)
#' @noRd
scn_library_table <- function(x, ctx) {
  ids <- utl_sort(scn_used_entries(x, ctx))
  recs <- lapply(ids, function(id) lib_get(ctx$index, id))
  dt <- function(f) {
    as.Date(vapply(recs, function(r) as.double(r[[f]] %||% NA_real_), double(1)),
            origin = "1970-01-01")
  }
  data.frame(entry = ids, as_of = dt("as_of"), valid_from = dt("valid_from"),
             valid_to = dt("valid_to"),
             quality = vapply(recs, function(r) as.character(r$quality %||% NA_character_), ""),
             stringsAsFactors = FALSE)
}

#' Gültigkeit und Stand der verwendeten Einträge prüfen (vofi_warning_library_outdated, D10)
#'
#' Maßgeblich ist für Verweise unter `funding.<f>` das Antragsdatum des Instruments, sonst
#' `project.legal_state`; ein Stand (`as_of`) älter als 6 Monate (Prozesse 12 Monate) vor dem
#' Rechtsstand ist ebenfalls veraltet. Je Eintrag eine Warnung.
#' @noRd
scn_check_outdated <- function(x, ctx) {
  ls <- scn_date(x$project$legal_state) %||% scn_date(x$project$valuation_date)
  if (is.null(ls)) return(invisible(NULL))
  dates <- list()
  for (u in ctx$lc$used) {
    segs <- path_split(u$path)
    d <- if (length(segs) >= 2L && identical(segs[1L], "funding")) {
      scn_application_date(x, segs[2L]) %||% ls
    } else {
      ls
    }
    for (id in u$chain) dates[[id]] <- dates[[id]] %||% d
  }
  for (id in scn_used_entries(x, ctx)) {
    rec <- lib_get(ctx$index, id)
    d <- dates[[id]] %||% ls
    if (!lib_valid_at(rec, d)) {
      vofi_warn("io.library.outdated", id = id, date = d,
                valid_from = format(rec$valid_from), valid_to = format(rec$valid_to),
                .class = "vofi_warning_library_outdated")
    } else if (lib_stale_at(rec, ls)) {
      vofi_warn("io.library.stale", id = id, as_of = rec$as_of, date = ls,
                months = if (identical(rec$block, "processes")) 12L else 6L,
                .class = "vofi_warning_library_outdated")
    }
  }
  invisible(NULL)
}
