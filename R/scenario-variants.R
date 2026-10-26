# Varianten und Szenario-Sets (WS-A, Spec 00 Abschnitt 4.11).
# Phase-0-Minimalfassung, Eigentuemer: WS-A. Umgesetzt: extends-Kette (Zyklus = Fehler),
# Operationen remove -> replace -> set -> overrides -> add mit Existenzpruefungen (set/overrides
# auch auf Vorlagen- und Regelfelder, R-112), Szenario-Sets mit Pfadbeschraenkung,
# vofi_variants().
# Offen fuer WS-A: Platzhalter "*" in Set-Pfaden, generiertes Set "vorsichtig" (WS-G),
# Meldung bei Overlay-Zielen, die eine Variante deterministisch setzt (4.7).

#' Varianten eines Szenarios
#'
#' Listet die Basis und alle Varianten mit Bezeichnung und Elternvariante.
#'
#' Phase-0-Minimalfassung (Eigentümer: WS-A).
#'
#' @param scenario Objekt der Klasse `vofi_scenario`.
#' @return Data Frame mit den Spalten `variant`, `label`, `extends`.
#' @family Einlesen
#' @examples
#' vofi_variants(vofi_read_scenario(vofi_example("skeleton")))
#' @export
vofi_variants <- function(scenario) {
  if (!inherits(scenario, "vofi_scenario")) {
    vofi_abort("io.not_scenario", arg = "scenario", .class = "vofi_error_input")
  }
  v <- scenario$variants %||% list()
  data.frame(
    variant = c("base", names(v)),
    label = c(lbl("io.variant_base_label"),
              vapply(v, function(e) as.character(e$label %||% NA_character_), "",
                     USE.NAMES = FALSE)),
    extends = c(NA_character_, vapply(v, function(e) as.character(e$extends %||% "base"), "",
                                      USE.NAMES = FALSE)),
    stringsAsFactors = FALSE
  )
}

#' Variante mit ihrer extends-Kette anwenden
#' @return `list(x, paths)`.
#' @noRd
var_apply_chain <- function(x, variants, variant) {
  chain <- character(0)
  v <- variant
  while (!identical(v, "base")) {
    if (v %in% chain) {
      vofi_abort("io.variant_cycle", chain = utl_collapse(c(chain, v), " -> "),
                 .class = "vofi_error_validation")
    }
    if (is.null(variants[[v]])) {
      vofi_abort("io.variant_unknown", variant = v, suggestion = "",
                 .class = "vofi_error_validation")
    }
    chain <- c(chain, v)
    v <- variants[[v]]$extends %||% "base"
  }
  paths <- character(0)
  for (v in rev(chain)) {
    r <- var_apply_ops(x, variants[[v]], v)
    x <- r$x
    paths <- c(paths, r$paths)
  }
  list(x = x, paths = unique(paths))
}

#' Operationen einer Variante bzw. eines Szenario-Sets (4.11)
#'
#' Existenzprüfung: `replace`, `remove` und das Entfernen mit `~` in `overrides` verlangen einen
#' existierenden Pfad. Für `set` und `overrides` gilt ein Pfad auch dann als vorhanden, wenn sein
#' Elternelement existiert und das Blatt ein Feld der Feldtabellen bzw. der `item_defaults`-Vorlage
#' ist, das erst eine Ableitungsregel oder `item_defaults` füllt (`var_path_known()`, R-112).
#' @return `list(x, paths)` (geänderte Pfade für die Herkunft).
#' @noRd
var_apply_ops <- function(x, ops, name, is_set = FALSE) {
  paths <- character(0)
  must_exist <- function(p, op, relaxed = op %in% c("set", "overrides")) {
    if (is_set) var_check_set_path(p, name)
    known <- if (relaxed) var_path_known(x, p) else path_exists(x, p)
    if (!known) {
      vofi_abort("io.variant_path_missing", variant = name, op = op, path = p,
                 .class = "vofi_error_validation")
    }
  }
  for (p in as.character(unlist(ops$remove))) {
    must_exist(p, "remove")
    x <- path_remove(x, p)
    paths <- c(paths, p)
  }
  for (p in names(ops$replace)) {
    must_exist(p, "replace")
    x <- path_set(x, p, ops$replace[[p]])
    paths <- c(paths, p)
  }
  for (p in names(ops$set)) {
    must_exist(p, "set")
    x <- path_set(x, p, scn_merge(path_get(x, p), ops$set[[p]]))
    paths <- c(paths, p)
  }
  if (!is.null(ops$overrides)) {
    for (p in var_override_leaves(ops$overrides)) {
      v <- path_get(ops$overrides, p)
      must_exist(p, "overrides", relaxed = !is.null(v))
      x <- if (is.null(v)) path_remove(x, p) else path_set(x, p, scn_merge(path_get(x, p), v))
      paths <- c(paths, p)
    }
  }
  for (p in names(ops$add)) {
    if (is_set) var_check_set_path(p, name)
    if (path_exists(x, p)) {
      vofi_abort("io.variant_path_exists", variant = name, path = p,
                 .class = "vofi_error_validation")
    }
    x <- path_set(x, p, ops$add[[p]])
    paths <- c(paths, p)
  }
  list(x = x, paths = paths)
}

#' Blattpfade der Baumform `overrides` einschließlich der Löschanweisungen `~` (4.11)
#' @param x Teilbaum.
#' @param path Pfad von `x`.
#' @return Zeichenvektor.
#' @noRd
var_override_leaves <- function(x, path = "") {
  if (is.null(x)) return(if (nzchar(path)) path else character(0))
  if (node_is(x) || !is_map(x) || length(x) == 0L ||
        (nzchar(path) && is_value_form(x, path, kind_of = scn_kind_of))) {
    return(if (nzchar(path)) path else character(0))
  }
  out <- lapply(names(x), function(nm) var_override_leaves(x[[nm]], path_join(path, nm)))
  unlist(out, use.names = FALSE) %||% character(0)
}

#' Gilt ein Pfad für `set`/`overrides` als vorhanden? (4.11, R-112)
#'
#' Vorhanden ist ein existierender Pfad, außerdem ein Pfad, dessen Elternelement vorhanden ist
#' (rekursiv, z. B. ein Teilbaum der Vorlage `item_defaults.building`) und dessen Blatt ein Feld
#' des Elternelements nach `var_template_fields()` ist. Neue Elemente von Sammlungen entstehen
#' so nicht (dafür gibt es `add`).
#' @param x Spezifikation (Schicht 7).
#' @param p Pfad.
#' @return `TRUE`/`FALSE`.
#' @noRd
var_path_known <- function(x, p) {
  if (path_exists(x, p)) return(TRUE)
  segs <- path_split(p)
  k <- length(segs)
  if (k < 2L) return(FALSE)
  parent <- paste(segs[-k], collapse = ".")
  parent_ok <- path_exists(x, parent) || var_path_known(x, parent)
  parent_ok && is_map(path_get(x, parent) %||% list()) && !node_is(path_get(x, parent)) &&
    segs[k] %in% var_template_fields(x, parent)
}

#' Felder eines Elternelements nach Feldtabellen und Vorlagen (R-112)
#'
#' Vereinigung aus (1) den Typparametern und reservierten Metafeldern von
#' `components.<id>`/`financing.<id>` (auch Felder von map-Parametern), (2) dem Schema der
#' Domänenblöcke (`val_domain_schema()`, Feldtabellen von Spec 01) und (3) den Vorlagen
#' `item_defaults` (`scn_item_defaults()`). Schlüssel für (2) und (3) ist der Elternpfad ohne die
#' ids der Sammlungen (z. B. `measures.wp.rent_law` -> `measures.rent_law`); maßgeblich ist der
#' längste passende Schlüssel, darunter wird über map-Felder bzw. Teilbäume der Vorlage gegangen.
#' Ein Elternpfad, der selbst eine Sammlung ist (z. B. `measures`), hat keine Felder.
#' @param x Spezifikation.
#' @param parent Elternpfad.
#' @return Zeichenvektor der Feldnamen.
#' @noRd
var_template_fields <- function(x, parent) {
  segs <- path_split(parent)
  colls <- utl_merge_collections()
  tpl <- character(0)
  i <- 1L
  while (i <= length(segs)) {
    tpl <- c(tpl, segs[i])
    if (paste(tpl, collapse = ".") %in% colls) {
      if (i == length(segs)) return(character(0))
      i <- i + 1L                                   # id des Sammlungselements ueberspringen
    }
    i <- i + 1L
  }
  walk_params <- function(params, rest) {
    for (seg in rest) {
      pp <- params[[seg]]
      if (!inherits(pp, "vofi_param") || !is.list(pp$fields)) return(character(0))
      params <- pp$fields
    }
    names(params)
  }
  walk_template <- function(node, rest) {
    for (seg in rest) {
      node <- if (utl_has_name(node, seg)) node[[seg]] else NULL
      # Wertformen und Knoten der Vorlage sind Blaetter (strukturelle Pruefung, 4.7)
      if (!is_map(node) || node_is(node) || !is.na(utl_value_form_kind(node))) {
        return(character(0))
      }
    }
    names(node)
  }
  longest <- function(keys) {
    hit <- keys[vapply(keys, function(k) {
      ks <- path_split(k)
      length(ks) <= length(tpl) && identical(ks, tpl[seq_along(ks)])
    }, logical(1))]
    if (length(hit) == 0L) NULL else hit[which.max(nchar(hit))]
  }
  out <- character(0)
  if (length(segs) >= 2L && segs[1L] %in% c("components", "financing")) {
    def <- scn_type_def(path_get(x, path_join(segs[1:2]))[["type"]], segs[1L])
    if (!is.null(def)) {
      out <- c(out, walk_params(def$params, segs[-(1:2)]))
      if (length(segs) == 2L) out <- c(out, reg_reserved_fields())
    }
  }
  schema <- val_domain_schema()
  k <- longest(names(schema))
  if (!is.null(k)) out <- c(out, walk_params(schema[[k]], tpl[-seq_along(path_split(k))]))
  items <- scn_item_defaults()
  k <- longest(names(items))
  if (!is.null(k)) {
    out <- c(out, walk_template(items[[k]], tpl[-seq_along(path_split(k))]))
  }
  unique(out)
}

#' Zulässige Pfade eines Szenario-Sets (4.11)
#' @noRd
var_check_set_path <- function(p, name) {
  if (grepl("*", p, fixed = TRUE)) scn_unsupported(paste0("scenario_sets: ", p))
  first <- path_split(p)[1L]
  ok <- first %in% c("market", "funding", "accounts", "residual_value", "stochastic", "tax") ||
    identical(p, "project.pending_reforms")
  if (!ok) {
    vofi_abort("io.scenario_set_path", set = name, path = p, .class = "vofi_error_validation")
  }
  invisible(TRUE)
}
