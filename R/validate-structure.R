# Validierung: Einstieg vofi_validate(), Befundtabelle und Ebene 1 Struktur (WS-B; Spec 00
# Abschnitte 2.9, 2.10, 4.2, 4.4, 4.7, 4.9, 4.11, 13.5; Spec 01 Teil A 2.1, Teil C 3.1, 4.1).
#
# Ebenen der Validierung (Befunde werden gesammelt, nicht geworfen):
#   1 Struktur (dieses Modul): oberste Ebene, reservierte Wurzelschluessel, Varianten und
#     Szenario-Sets, Defaults-Dateien (global.yaml, Profile), Bibliothekseintraege;
#   2 Typen, Einheiten, Bereiche nach Feldkatalog und Parameterschema (validate-types.R);
#   3 Querbezuege: Bezuege, Ausdruecke, Zyklen, ids, Overlay-Ziele, Entscheidungsknoten,
#     Vergleich der Varianten (validate-refs.R);
#   4 Plausibilitaet und blockbezogene Konsistenzregeln der Feldtabellen (validate-plausibility.R).
# Die Spalte `layer` der Befundtabelle ist die Schicht (0-8, Spec 00 4.7) des betroffenen Pfads
# nach der Herkunft; `location` die Fundstelle der Herkunft.

#' Szenario bzw. Spezifikation prüfen
#'
#' Prüft ein Szenario bzw. eine aufgelöste Spezifikation auf vier Ebenen und sammelt alle
#' Befunde (Spec 00, Abschnitte 2.9 und 13.5): (1) Struktur (unbekannte Schlüssel, reservierte
#' Wurzelschlüssel, Varianten und Szenario-Sets), (2) Typen, Einheiten und Wertebereiche nach den
#' Feldtabellen von Spec 01 und dem Parameterschema der Typen, (3) Querbezüge (Bezüge und
#' Ausdrücke einschließlich Zyklen, ids und erzeugte ids, Overlay-Ziele, Entscheidungsknoten,
#' Referenzvariante, Gleichheit von Bestandswert und Bestandsdarlehen über die Varianten),
#' (4) Plausibilität (Warnungen und Hinweise). Ein Szenario wird je Variante aufgelöst
#' ([vofi_resolve()]); Fehler beim Auflösen erscheinen als Befund.
#'
#' Die Meldungen stehen im Label-Katalog unter `validation.<block>.<code>` bzw.
#' blockübergreifend unter `validation.<code>` (Spec 00, Abschnitt 2.10).
#'
#' @param x Objekt der Klasse `vofi_scenario` oder `vofi_spec`.
#' @param variant `NULL` (Basis, alle Varianten und alle statischen Szenario-Sets) oder
#'   Zeichenvektor mit Namen von Varianten.
#' @param min_severity kleinste ausgegebene Schwere: `"info"`, `"warning"` oder `"error"`.
#' @return Objekt der Klasse `vofi_validation` (Data Frame mit den Spalten `severity`, `code`,
#'   `path`, `location`, `message`, `layer`, `variant`).
#' @family Validieren
#' @examples
#' v <- vofi_validate(vofi_read_scenario(vofi_example("skeleton")))
#' nrow(v)
#' @export
vofi_validate <- function(x, variant = NULL, min_severity = c("info", "warning", "error")) {
  min_severity <- utl_match_arg(min_severity, c("info", "warning", "error"), "min_severity")
  if (!is.null(variant) && (!is.character(variant) || length(variant) == 0L ||
                              anyNA(variant))) {
    vofi_abort("core.arg_character", arg = "variant", .class = "vofi_error_input")
  }
  if (inherits(x, "vofi_scenario")) {
    out <- val_scenario(x, variant)
  } else if (inherits(x, "vofi_spec")) {
    out <- val_spec(x, x$variant %||% "base")
  } else {
    vofi_abort("validation.not_validatable", .class = "vofi_error_input")
  }
  df <- val_bind(out)
  rank <- c(info = 1L, warning = 2L, error = 3L)
  df <- df[rank[df$severity] >= rank[[min_severity]], , drop = FALSE]
  df <- val_unique(df)
  rownames(df) <- NULL
  new_vofi_validation(df)
}

#' Szenario prüfen: Struktur, je Variante Auflösung und Spezifikation, Vergleiche
#' @param x `vofi_scenario`.
#' @param variant `NULL` oder Namen der Varianten.
#' @return Liste von Befunden.
#' @noRd
val_scenario <- function(x, variant = NULL) {
  out <- c(val_scenario_structure(x), val_variants_structure(x), val_sets_structure(x))
  struct <- val_bind(out)
  variants <- x$variants %||% list()
  vars <- if (is.null(variant)) c("base", names(variants)) else unique(variant)
  specs <- list()
  for (v in vars) {
    spec <- tryCatch(vofi_resolve(x, variant = v), error = function(e) e)
    if (inherits(spec, "error")) {
      chain <- val_variant_chain(variants, v)
      blocked <- any(struct$severity == "error" & struct$variant %in% chain)
      if (!blocked) out[[length(out) + 1L]] <- val_resolve_finding(spec, v)
      next
    }
    specs[[v]] <- spec
    out <- c(out, val_spec(spec, v, scenario = x))
  }
  c(out, val_cross(x, specs, full = is.null(variant)))
}

#' Variante und ihre Elternvarianten (ohne base; bricht bei Zyklen ab)
#' @noRd
val_variant_chain <- function(variants, v) {
  chain <- character(0)
  while (utl_is_string(v) && !identical(v, "base") && !(v %in% chain)) {
    chain <- c(chain, v)
    e <- variants[[v]]
    v <- if (is_map(e) && utl_is_string(e$extends)) e$extends else "base"
  }
  chain
}

#' Prüfungen einer aufgelösten Spezifikation (Ebenen 2-4)
#' @param spec `vofi_spec`.
#' @param variant Variante.
#' @param scenario optional: das Szenario (für Ausweich- und Referenzvarianten).
#' @return Liste von Befunden.
#' @noRd
val_spec <- function(spec, variant = "base", scenario = NULL) {
  vc <- val_context(spec, variant, scenario)
  val_types(vc)
  val_refs(vc)
  val_plausibility(vc)
  vc$out
}

#' Prüfkontext einer Spezifikation
#'
#' Enthält die Spezifikation, die Herkunft, den Feldkatalog, Stichtag, Horizontende und das
#' Raster (`NULL`, wenn es sich nicht bilden lässt) sowie den Sammler der Befunde.
#' @noRd
val_context <- function(spec, variant = "base", scenario = NULL) {
  vc <- new.env(parent = emptyenv())
  vc$spec <- spec
  vc$variant <- variant
  vc$scenario <- scenario
  vc$out <- list()
  vc$prov <- attr(spec, "provenance")
  vc$catalog <- val_schema_catalog()
  vc$domain <- val_has_domain(spec)
  vd <- spec$project$valuation_date
  vc$vd <- if (inherits(vd, "Date") && length(vd) == 1L && !is.na(vd)) vd else NULL
  hy <- spec$project$horizon_years
  vc$end_date <- if (!is.null(vc$vd) && utl_is_whole(hy) && hy >= 1) {
    grid_add_months(vc$vd, 12L * as.integer(hy))
  } else {
    NULL
  }
  vc$grid <- tryCatch(suppressMessages(suppressWarnings(eng_build_grid(spec))),
                      error = function(e) NULL)
  vc$base_cache <- new.env(parent = emptyenv())
  vc
}

#' Hat die Spezifikation Domänenblöcke? (Spec 00 4.2 Fußnote 1: Komponentenszenarien ohne)
#' @noRd
val_has_domain <- function(spec) {
  any(vapply(c("building", "household", "unit_groups", "measures", "energy", "funding"),
             function(b) is_map(spec[[b]]) && length(spec[[b]]) > 0L, logical(1)))
}

#' Befund in den Kontext aufnehmen (Schicht und Fundstelle aus der Herkunft)
#' @param vc Prüfkontext.
#' @param severity `"error"`, `"warning"` oder `"info"`.
#' @param code Label-Schlüssel.
#' @param path Pfad.
#' @param ... Platzhalterwerte.
#' @noRd
val_add <- function(vc, severity, code, path, ...) {
  pl <- val_prov_lookup(vc$prov, path)
  row <- val_finding(severity, code, path, ..., layer = pl$layer, variant = vc$variant,
                     location = pl$location)
  vc$out[[length(vc$out) + 1L]] <- row
  invisible(NULL)
}

#' Schicht und Fundstelle eines Pfads aus der Herkunft (4.8)
#'
#' Exakter Treffer; sonst die Blätter unter dem Pfad (jüngste Schicht); sonst der längste
#' Elternpfad.
#' @noRd
val_prov_lookup <- function(prov, path) {
  none <- list(layer = NA_integer_, location = NA_character_)
  if (!is.data.frame(prov) || nrow(prov) == 0L || !utl_is_string(path) || !nzchar(path)) {
    return(none)
  }
  pick <- function(i) {
    i <- i[order(-prov$layer[i], method = "radix")]
    loc <- prov$location[i]
    loc <- loc[!is.na(loc)]
    list(layer = as.integer(prov$layer[i[1L]]),
         location = if (length(loc) > 0L) as.character(loc[1L]) else NA_character_)
  }
  hit <- which(prov$path == path)
  if (length(hit) > 0L) return(pick(hit))
  hit <- which(startsWith(prov$path, paste0(path, ".")))
  if (length(hit) > 0L) return(pick(hit))
  segs <- path_split(path)
  for (k in rev(seq_len(max(0L, length(segs) - 1L)))) {
    hit <- which(prov$path == paste(segs[seq_len(k)], collapse = "."))
    if (length(hit) > 0L) return(pick(hit))
  }
  none
}

#' Befund als Zeile des Validierungsberichts
#' @param severity Schwere.
#' @param code Label-Schlüssel des Meldungstextes.
#' @param path Pfad (Platzhalter `{path}`).
#' @param ... weitere Platzhalterwerte.
#' @param layer Schicht.
#' @param variant Variante bzw. Szenario-Set.
#' @param location Fundstelle.
#' @return Data Frame mit einer Zeile.
#' @noRd
val_finding <- function(severity, code, path, ..., layer = NA_integer_,
                        variant = NA_character_, location = NA_character_) {
  path <- as.character(path %||% "")
  if (length(path) != 1L || is.na(path)) path <- ""
  data.frame(severity = severity, code = code, path = path,
             location = as.character(location %||% NA_character_),
             message = msg(code, path = path, ...),
             layer = as.integer(layer %||% NA_integer_),
             variant = as.character(variant %||% NA_character_),
             stringsAsFactors = FALSE)
}

#' Befund zu einem Fehler beim Auflösen einer Variante
#'
#' Bedingungen mit eigenem Schlüssel `validation.*` (z. B. `validation.library.ref_not_id`,
#' 4.9, R-110, oder Meldungen der Ausdrücke `validation.expr.*`) erscheinen unter diesem Code;
#' alle übrigen Fehler als `validation.resolve_failed` mit dem Meldungstext.
#' @param cond Fehlerobjekt.
#' @param variant Variante.
#' @noRd
val_resolve_finding <- function(cond, variant) {
  key <- cond$key
  if (utl_is_string(key) && startsWith(key, "validation.") && lbl_has(key)) {
    args <- cond$args %||% list()
    path <- args$path %||% ""
    args$path <- NULL
    return(do.call(val_finding, c(list("error", key, path), args,
                                  list(variant = variant))))
  }
  val_finding("error", "validation.resolve_failed", "", variant = variant,
              detail = conditionMessage(cond))
}

#' Befunde binden
#' @noRd
val_bind <- function(x) {
  x <- Filter(function(e) is.data.frame(e) && nrow(e) > 0L, x)
  if (length(x) == 0L) {
    return(as.data.frame(unclass(new_vofi_validation()), stringsAsFactors = FALSE))
  }
  out <- do.call(rbind, x)
  rownames(out) <- NULL
  out
}

#' Doppelte Befunde (gleiche Variante, Schwere, Code, Pfad und Meldung) entfernen
#' @noRd
val_unique <- function(df) {
  if (nrow(df) == 0L) return(df)
  key <- paste(df$variant, df$severity, df$code, df$path, df$message, sep = "\r")
  df[!duplicated(key), , drop = FALSE]
}

#' Liste von Zeichenketten bzw. Zeichenvektor (Operationen remove, ids)
#' @noRd
val_chr_list <- function(x) {
  if (is.null(x)) return(character(0))
  if (is.character(x)) return(x)
  if (is.list(x) && !is_map(x) &&
        all(vapply(x, function(e) is.character(e) && length(e) == 1L, logical(1)))) {
    return(unlist(x, use.names = FALSE))
  }
  NULL
}

# ---------------------------------------------------------------------------------------------
# Szenario: oberste Ebene (4.2), reservierte Wurzelschlüssel (4.7), Varianten und Sets (4.11)
# ---------------------------------------------------------------------------------------------

#' Ebene 1 für das Szenario: oberste Ebene (ohne Varianten und Sets)
#'
#' Auch Vorprüfung von `vofi_build()` (WS-D): Varianten und Szenario-Sets, die nicht gebaut
#' werden, prüfen `val_variants_structure()` und `val_sets_structure()` nur in
#' `vofi_validate()`.
#' @param x `vofi_scenario` bzw. Liste der Blöcke.
#' @return Liste von Befunden.
#' @noRd
val_scenario_structure <- function(x) {
  out <- list()
  add <- function(...) out[[length(out) + 1L]] <<- val_finding(...)
  allowed <- c("schema_version", utl_scenario_blocks())
  reserved <- c("defaults_meta", "by_project_type", "item_defaults")
  for (k in setdiff(names(x), allowed)) {
    if (k %in% reserved) {
      add("error", "validation.reserved_root_key", k, layer = 5L)
    } else {
      add("error", "validation.unknown_key", k, suggestion = utl_suggest_text(k, allowed),
          layer = 5L)
    }
  }
  sv <- x$schema_version
  if (!identical(as.integer(sv %||% NA_integer_), 1L)) {
    add("error", "validation.schema_version", "schema_version",
        value = utl_collapse(format(sv %||% "NULL")), layer = 5L)
  }
  st <- x$stochastic
  if (is_map(st)) {
    known <- c("settings", "parameters", "processes", "correlations")
    for (k in setdiff(names(st), known)) {
      add("error", "validation.stochastic.unknown_key", path_join("stochastic", k),
          suggestion = utl_suggest_text(k, known), layer = 6L)
    }
  }
  out
}

#' Unbekannte Wurzelschlüssel der Laufzeit-Overrides (Schicht 8, 4.2)
#' @param overrides Overrides in Baumform (nach `scn_overrides_tree()`).
#' @return Liste von Befunden.
#' @noRd
val_overrides_structure <- function(overrides) {
  allowed <- setdiff(utl_scenario_blocks(), c("variants", "scenario_sets"))
  out <- list()
  for (k in setdiff(names(overrides), allowed)) {
    out[[length(out) + 1L]] <- val_finding("error", "validation.unknown_key",
                                           path_join("overrides", k),
                                           suggestion = utl_suggest_text(k, allowed),
                                           layer = 8L)
  }
  out
}

#' Sammlungen, deren Elemente eine Variante bzw. ein Set mit `add` anlegen darf (4.11)
#' @noRd
val_add_collections <- function() {
  c(utl_merge_collections()[!utl_merge_collections() %in% c("variants", "scenario_sets")],
    "stochastic.parameters", "stochastic.processes")
}

#' Struktur der Varianten (4.11)
#' @noRd
val_variants_structure <- function(x) {
  variants <- x$variants
  out <- list()
  if (is.null(variants) || length(variants) == 0L) return(out)
  if (!is_map(variants)) {
    return(list(val_finding("error", "validation.not_map", "variants", layer = 7L)))
  }
  fields <- val_schema_catalog()$variants
  ids <- names(variants)
  for (v in ids) {
    path <- path_join("variants", v)
    add <- function(sev, code, p, ...) {
      out[[length(out) + 1L]] <<- val_finding(sev, code, p, ..., layer = 7L, variant = v)
    }
    if (!utl_is_id(v) || v %in% c("base", "engine")) add("error", "validation.id_invalid", path,
                                                        value = v)
    e <- variants[[v]]
    if (!is_map(e)) {
      add("error", "validation.not_map", path)
      next
    }
    for (f in setdiff(names(e), names(fields))) {
      add("error", "validation.unknown_field", path_join(path, f),
          suggestion = utl_suggest_text(f, names(fields)))
    }
    if (!utl_is_string(e$label) || !nzchar(e$label)) {
      add("error", "validation.required", path_join(path, "label"))
    }
    ext <- e$extends
    if (!is.null(ext)) {
      if (!utl_is_string(ext) || !(ext %in% c("base", ids))) {
        add("error", "validation.variants.extends_unknown", path_join(path, "extends"),
            value = utl_collapse(format(ext)),
            suggestion = utl_suggest_text(as.character(ext)[1L], c("base", ids)))
      } else {
        chain <- v
        cur <- ext
        while (!identical(cur, "base") && !(cur %in% chain) && is_map(variants[[cur]])) {
          chain <- c(chain, cur)
          nxt <- variants[[cur]]$extends
          cur <- if (utl_is_string(nxt) && nxt %in% c("base", ids)) nxt else "base"
        }
        if (identical(cur, v)) {
          add("error", "validation.variants.extends_cycle", path_join(path, "extends"),
              chain = utl_collapse(c(chain, v), " -> "))
        }
      }
    }
    out <- c(out, lapply(val_ops_structure(e, path, is_set = FALSE), function(f) {
      f$variant <- v
      f
    }))
  }
  out
}

#' Operationen einer Variante bzw. eines Sets: Formen und Pfade (4.11)
#' @param e Variante bzw. Set.
#' @param path Pfad (`variants.<id>` bzw. `scenario_sets.<id>`).
#' @param is_set Szenario-Set (Pfadbeschränkung, ein Platzhalter `*`).
#' @return Liste von Befunden (ohne Variante).
#' @noRd
val_ops_structure <- function(e, path, is_set) {
  out <- list()
  layer <- 7L
  add <- function(sev, code, p, ...) {
    out[[length(out) + 1L]] <<- val_finding(sev, code, p, ..., layer = layer)
  }
  blocks <- setdiff(utl_scenario_blocks(), c("variants", "scenario_sets"))
  check_path <- function(op, p, is_add = FALSE) {
    where <- path_join(path, op)
    segs <- strsplit(p, ".", fixed = TRUE)[[1L]]
    if (!utl_is_string(p) || !nzchar(p) || any(!nzchar(segs)) || !(segs[1L] %in% blocks)) {
      add("error", "validation.variants.path_invalid", where, value = p)
      return(invisible(FALSE))
    }
    n_star <- sum(segs == "*")
    if (n_star > 0L && !is_set) {
      add("error", "validation.variants.wildcard", where, value = p)
    }
    if (is_set) {
      if (identical(segs[1L], "shared")) {
        add("error", "validation.scenario_set.path_forbidden", where, value = p)
      } else if (!(segs[1L] %in% c("market", "funding", "accounts", "residual_value",
                                   "stochastic", "tax") ||
                     identical(p, "project.pending_reforms"))) {
        add("error", "validation.scenario_set.path_not_allowed", where, value = p)
      }
      if (n_star > 1L) add("error", "validation.scenario_set.wildcard_multiple", where, value = p)
    }
    if (is_add) {
      coll <- paste(segs[-length(segs)], collapse = ".")
      id <- segs[length(segs)]
      if (!(coll %in% val_add_collections())) {
        add("error", "validation.variants.add_not_collection", where, value = p)
      } else if (!utl_is_id(id)) {
        add("error", "validation.id_invalid", where, value = id)
      }
    }
    invisible(TRUE)
  }
  for (op in c("set", "replace", "add")) {
    ops <- e[[op]]
    if (is.null(ops)) next
    if (!is_map(ops)) {
      add("error", "validation.not_map", path_join(path, op))
      next
    }
    for (p in names(ops)) check_path(op, p, is_add = identical(op, "add"))
  }
  if (!is.null(e$remove)) {
    rm <- val_chr_list(e$remove)
    if (is.null(rm)) {
      add("error", "validation.not_ids", path_join(path, "remove"))
    } else {
      for (p in rm) check_path("remove", p)
    }
  }
  if (!is.null(e$overrides)) {
    if (!is_map(e$overrides)) {
      add("error", "validation.not_map", path_join(path, "overrides"))
    } else {
      for (k in setdiff(names(e$overrides), blocks)) {
        add("error", "validation.unknown_key", path_join(path, "overrides", k),
            suggestion = utl_suggest_text(k, blocks))
      }
      if (is_set) {
        for (p in var_override_leaves(e$overrides[intersect(names(e$overrides), blocks)])) {
          check_path("overrides", p)
        }
      }
    }
  }
  out
}

#' Struktur der Szenario-Sets (4.11; Spec 01 Teil C 4.1)
#' @noRd
val_sets_structure <- function(x) {
  sets <- x$scenario_sets
  out <- list()
  if (is.null(sets) || length(sets) == 0L) return(out)
  if (!is_map(sets)) {
    return(list(val_finding("error", "validation.not_map", "scenario_sets", layer = 7L)))
  }
  fields <- val_schema_catalog()$scenario_sets
  variant_ids <- names(x$variants %||% list())
  ops_names <- c("set", "replace", "add", "remove", "overrides")
  for (s in names(sets)) {
    path <- path_join("scenario_sets", s)
    add <- function(sev, code, p, ...) {
      out[[length(out) + 1L]] <<- val_finding(sev, code, p, ..., layer = 7L, variant = s)
    }
    if (!utl_is_id(s) || s %in% c("base", "engine")) {
      add("error", "validation.id_invalid", path, value = s)
    } else if (s %in% variant_ids) {
      add("error", "validation.scenario_set.id_is_variant", path, value = s)
    }
    e <- sets[[s]]
    if (!is_map(e)) {
      add("error", "validation.not_map", path)
      next
    }
    for (f in setdiff(names(e), names(fields))) {
      add("error", "validation.unknown_field", path_join(path, f),
          suggestion = utl_suggest_text(f, names(fields)))
    }
    if (!utl_is_string(e$label) || !nzchar(e$label)) {
      add("error", "validation.required", path_join(path, "label"))
    }
    has_ops <- any(vapply(ops_names, function(o) !is.null(e[[o]]), logical(1)))
    gen <- e$generate
    if (!is.null(gen) && has_ops) {
      add("error", "validation.scenario_set.generate_with_ops", path)
    } else if (is.null(gen) && !has_ops) {
      add("error", "validation.scenario_set.ops_missing", path)
    }
    if (!is.null(gen)) {
      if (!is_map(gen)) {
        add("error", "validation.not_map", path_join(path, "generate"))
      } else {
        probs <- suppressWarnings(as.double(unlist(gen$probs)))
        if (!is.null(gen$probs) && (length(probs) != 2L || anyNA(probs) ||
                                      !(probs[1L] > 0 && probs[1L] < 0.5 && probs[2L] > 0.5 &&
                                          probs[2L] < 1))) {
          add("error", "validation.scenario_set.probs", path_join(path, "generate", "probs"),
              value = utl_collapse(format(gen$probs)))
        }
      }
    }
    out <- c(out, lapply(val_ops_structure(e, path, is_set = TRUE), function(f) {
      f$variant <- s
      f
    }))
  }
  out
}

# ---------------------------------------------------------------------------------------------
# Defaults-Dateien (Schichten 1-2, 4.7, R-76, R-85) und Bibliothekseinträge (4.9; Teil C 3.1)
# ---------------------------------------------------------------------------------------------

#' Zulässige Pfade eines Perspektiven-Profils (4.7, R-76)
#' @noRd
val_profile_paths <- function() {
  c("accounts", "analysis", "residual_value.method", "residual_value.sale_cost_share",
    "project.horizon_years", "project.report_mode", "tax.module", "scenario_sets")
}

#' Defaults-Datei prüfen (global.yaml bzw. Perspektiven-Profil)
#'
#' Ebene 1 der Defaults-Dateien (Spec 00 4.7, R-76, R-85): `defaults_meta` ist Pflicht,
#' `item_defaults` nur in `global.yaml`, Profile setzen nur die Pfade nach
#' `val_profile_paths()` (auch in `by_project_type`), übrige Wurzelschlüssel wie im Szenario.
#' Für WS-A (`test-profiles.R`).
#' @param x Inhalt der Datei (Rohform).
#' @param kind `"global"` oder `"profile"`.
#' @param file Dateiname für die Meldungen.
#' @return Objekt der Klasse `vofi_validation`.
#' @noRd
val_defaults_file <- function(x, kind = c("global", "profile"), file = NA_character_) {
  kind <- utl_match_arg(kind, c("global", "profile"), "kind")
  out <- list()
  layer <- if (identical(kind, "global")) 1L else 2L
  add <- function(sev, code, p, ...) {
    out[[length(out) + 1L]] <<- val_finding(sev, code, p, ..., layer = layer,
                                            location = file)
  }
  if (!is_map(x)) {
    add("error", "validation.not_map", "")
    return(new_vofi_validation(val_bind(out)))
  }
  reserved <- c("defaults_meta", "by_project_type",
                if (identical(kind, "global")) "item_defaults")
  allowed <- c(setdiff(utl_scenario_blocks(), "variants"), reserved)
  for (k in setdiff(names(x), allowed)) {
    if (identical(k, "item_defaults")) {
      add("error", "validation.profile.item_defaults_forbidden", k, file = file)
    } else {
      add("error", "validation.unknown_key", k, suggestion = utl_suggest_text(k, allowed))
    }
  }
  dm <- x$defaults_meta
  if (!is_map(dm)) {
    add("error", "validation.profile.defaults_meta_missing", "defaults_meta", file = file)
  } else {
    for (f in c("kind", "id", "schema_version", "as_of", "quality", "source")) {
      if (is.null(dm[[f]])) add("error", "validation.required", path_join("defaults_meta", f))
    }
    if (!is.null(dm$kind) && !identical(dm$kind, kind)) {
      add("error", "validation.enum", "defaults_meta.kind", value = utl_collapse(format(dm$kind)),
          suggestion = utl_suggest_text(as.character(dm$kind)[1L], kind))
    }
  }
  if (identical(kind, "profile")) {
    trees <- list(x[setdiff(names(x), reserved)])
    names(trees) <- ""
    bpt <- x$by_project_type
    if (is_map(bpt)) {
      for (pt in names(bpt)) trees[[paste0("by_project_type.", pt)]] <- bpt[[pt]]
    }
    for (nm in names(trees)) {
      leaves <- path_leaves(trees[[nm]])
      ok <- vapply(leaves, function(p) {
        any(vapply(val_profile_paths(), function(a) {
          identical(p, a) || startsWith(p, paste0(a, "."))
        }, logical(1)))
      }, logical(1))
      for (p in leaves[!ok]) {
        add("error", "validation.profile_path_forbidden", path_join(nm, p), file = file)
      }
    }
  }
  new_vofi_validation(val_bind(out))
}

#' Wurzelschlüssel eines Bibliothekseintrags (Spec 00 4.9; Teil C 3.1)
#' @noRd
val_library_keys <- function() {
  c("id", "block", "topic", "schema_version", "label", "description", "source", "references",
    "as_of", "accessed", "valid_from", "valid_to", "quality", "quality_detail", "legal_state",
    "reform", "release", "uncertainty", "from", "fallback", "notes", "values")
}

#' Zielblock nach dem Ordner der Bibliothek (`prices/` -> `market`)
#' @noRd
val_library_block_of <- function(id) {
  folder <- strsplit(id, "/", fixed = TRUE)[[1L]][1L]
  switch(folder, prices = "market", folder)
}

#' Bibliothekseintrag prüfen (Ebene 1 der Bibliothek, Teil C 3.1, R-88)
#'
#' Für WS-L (`test-library.R`) und WS-A (Nutzerbibliotheken): Wurzelschlüssel, Pflichtfelder,
#' id = Dateipfad, Zielblock passend zum Ordner, Gültigkeit, Qualität, Rechtsstand, Reform und
#' Freigabe, Unterpfade von `quality_detail`.
#' @param entry Eintrag (Rohform).
#' @param id erwartete id (Pfad relativ zur Bibliothekswurzel ohne `.yaml`) oder `NULL`.
#' @param file Dateiname für die Meldungen.
#' @return Objekt der Klasse `vofi_validation`.
#' @noRd
val_library_entry <- function(entry, id = NULL, file = NA_character_) {
  out <- list()
  add <- function(sev, code, p, ...) {
    out[[length(out) + 1L]] <<- val_finding(sev, code, p, ..., layer = 3L, location = file)
  }
  if (!is_map(entry)) {
    add("error", "validation.not_map", "")
    return(new_vofi_validation(val_bind(out)))
  }
  keys <- val_library_keys()
  for (k in setdiff(names(entry), keys)) {
    add("error", "validation.library.unknown_key", k, suggestion = utl_suggest_text(k, keys))
  }
  for (f in c("id", "block", "schema_version", "label", "source", "as_of", "valid_from",
              "quality", "values")) {
    if (is.null(entry[[f]])) add("error", "validation.library.field_missing", f)
  }
  if (!utl_has_name(entry, "valid_to")) add("error", "validation.library.field_missing",
                                            "valid_to")
  eid <- entry$id
  if (!is.null(eid)) {
    if (!utl_is_string(eid) || !utl_is_library_id(eid)) {
      add("error", "validation.library.ref_not_id", "id", value = utl_collapse(format(eid)))
    } else if (!is.null(id) && !identical(eid, id)) {
      add("error", "validation.library.id_mismatch", "id", value = eid, expected = id)
    }
  }
  blocks <- c("funding", "financing", "market", "processes", "components", "legal", "costs",
              "valuation")
  blk <- entry$block
  if (!is.null(blk)) {
    if (!utl_is_string(blk) || !(blk %in% blocks)) {
      add("error", "validation.enum", "block", value = utl_collapse(format(blk)),
          suggestion = utl_suggest_text(as.character(blk)[1L], blocks))
    } else if (utl_is_string(eid) && utl_is_library_id(eid) &&
                 !identical(blk, val_library_block_of(eid))) {
      add("error", "validation.library.block_mismatch", "block", value = blk,
          expected = val_library_block_of(eid))
    }
  }
  if (!is.null(entry$schema_version) &&
        !identical(suppressWarnings(as.integer(entry$schema_version)), 1L)) {
    add("error", "validation.schema_version", "schema_version",
        value = utl_collapse(format(entry$schema_version)))
  }
  src <- entry$source
  if (!is.null(src) && (!is_map(src) || !utl_is_string(src$document) ||
                          !nzchar(src$document) || !utl_is_string(src$publisher) ||
                          !nzchar(src$publisher))) {
    add("error", "validation.library.source_incomplete", "source")
  }
  refs <- entry$references
  if (!is.null(refs) && length(refs) > 0L) {
    for (i in seq_along(refs)) {
      r <- refs[[i]]
      if (!is_map(r) || !utl_is_string(r$document) || !utl_is_string(r$publisher)) {
        add("error", "validation.library.source_incomplete", path_join("references", i))
      }
    }
  }
  dates <- list()
  for (f in c("as_of", "accessed", "valid_from", "valid_to")) {
    v <- entry[[f]]
    if (is.null(v)) next
    d <- val_as_date(v)
    if (is.null(d)) {
      add("error", "validation.not_date", f, value = utl_collapse(format(v)))
    } else {
      dates[[f]] <- d
    }
  }
  if (!is.null(dates$valid_from) && !is.null(dates$valid_to) &&
        dates$valid_to <= dates$valid_from) {
    add("error", "validation.library.validity_order", "valid_to", from = dates$valid_from,
        to = dates$valid_to)
  }
  q <- entry$quality
  if (!is.null(q) && !(utl_is_string(q) && q %in% c("A", "B", "C", "D"))) {
    add("error", "validation.enum", "quality", value = utl_collapse(format(q)),
        suggestion = "")
  }
  qd <- entry$quality_detail
  if (is_map(qd) && length(qd) > 0L) {
    for (sub in names(qd)) {
      if (!(utl_is_string(qd[[sub]]) && qd[[sub]] %in% c("A", "B", "C", "D"))) {
        add("error", "validation.enum", path_join("quality_detail", sub),
            value = utl_collapse(format(qd[[sub]])), suggestion = "")
      }
      if (!val_library_subpath_exists(entry$values, sub)) {
        add("error", "validation.library.quality_detail_path", path_join("quality_detail", sub),
            value = sub)
      }
    }
  }
  folder <- if (utl_is_string(eid) && utl_is_library_id(eid)) {
    strsplit(eid, "/", fixed = TRUE)[[1L]][1L]
  } else {
    NA_character_
  }
  ls <- entry$legal_state
  if (folder %in% c("legal", "funding") && !is_map(ls)) {
    add("error", "validation.library.legal_state_missing", "legal_state")
  }
  status <- if (is_map(ls)) ls$status else NULL
  statuses <- c("in_force", "enacted", "adopted_pending", "pending", "administrative",
                "derived", "market")
  if (!is.null(status) && !(utl_is_string(status) && status %in% statuses)) {
    add("error", "validation.enum", "legal_state.status", value = utl_collapse(format(status)),
        suggestion = utl_suggest_text(as.character(status)[1L], statuses))
  }
  reform <- entry$reform
  if (!is.null(reform) && !(utl_is_string(reform) && vocab_has("reform", reform))) {
    add("error", "validation.enum", "reform", value = utl_collapse(format(reform)),
        suggestion = utl_suggest_text(as.character(reform)[1L], vocab_codes("reform")))
  }
  if (identical(status, "pending") && is.null(reform)) {
    add("error", "validation.library.status_reform", "legal_state.status", value = status)
  }
  if (!is.null(reform) && utl_is_string(status) && !(status %in% c("pending", "derived"))) {
    add("error", "validation.library.status_reform", "reform", value = status)
  }
  if (identical(folder, "legal")) {
    if (identical(q, "D") && is.null(reform)) {
      add("error", "validation.library.reform_missing", "reform")
    }
    if (!utl_is_string(entry$topic)) add("error", "validation.library.topic_missing", "topic")
    rel <- entry$release
    if (identical(q, "C") && !is_map(rel)) {
      add("error", "validation.library.release_missing", "release")
    }
    if (is_map(rel)) {
      if (!(utl_is_string(rel$status) && rel$status %in% c("released", "pending"))) {
        add("error", "validation.enum", "release.status",
            value = utl_collapse(format(rel$status %||% "NULL")), suggestion = "")
      } else if (identical(rel$status, "released") &&
                   (is.null(rel$by) || is.null(rel$date))) {
        add("warning", "validation.library.release_incomplete", "release")
      }
    }
  }
  from <- entry$from
  if (!is.null(from) && !(utl_is_string(from) && utl_is_library_id(from))) {
    add("error", "validation.library.ref_not_id", "from", value = utl_collapse(format(from)))
  }
  new_vofi_validation(val_bind(out))
}

#' Existiert der Unterpfad in der Nutzlast? (Indizes `[i]` adressieren Sequenzelemente)
#' @noRd
val_library_subpath_exists <- function(values, sub) {
  x <- values
  for (seg in path_split(sub)) {
    idx <- regmatches(seg, regexec("^([^\\[]+)\\[([0-9]+)\\]$", seg))[[1L]]
    name <- if (length(idx) == 3L) idx[2L] else seg
    if (!utl_has_name(x, name)) return(FALSE)
    x <- x[[name]]
    if (length(idx) == 3L) {
      i <- as.integer(idx[3L])
      if (!is.list(x) || i < 1L || i > length(x)) return(FALSE)
      x <- x[[i]]
    }
  }
  TRUE
}
