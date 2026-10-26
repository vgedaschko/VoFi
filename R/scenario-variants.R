# Varianten und Szenario-Sets (WS-A, Spec 00 Abschnitt 4.11).
# Phase-0-Minimalfassung, Eigentuemer: WS-A. Umgesetzt: extends-Kette (Zyklus = Fehler),
# Operationen remove -> replace -> set -> overrides -> add mit Existenzpruefungen,
# Szenario-Sets mit Pfadbeschraenkung, vofi_variants().
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
#' @return `list(x, paths)` (geänderte Pfade für die Herkunft).
#' @noRd
var_apply_ops <- function(x, ops, name, is_set = FALSE) {
  paths <- character(0)
  must_exist <- function(p, op) {
    if (is_set) var_check_set_path(p, name)
    if (!path_exists(x, p)) {
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
    for (p in scn_leaves(ops$overrides)) {
      must_exist(p, "overrides")
      v <- path_get(ops$overrides, p)
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
