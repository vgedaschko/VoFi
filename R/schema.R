# Parameter-DSL und JSON-Schema (WS-B; Konstruktor vofi_param() vom Integrator in Phase 0,
# Spec 00 Abschnitt 5.4).

#' Parameterbeschreibung eines Bausteintyps
#'
#' Beschreibt einen Parameter eines Typs der Registry (Parameter-DSL, Spec 00 Abschnitt 5.4).
#' Grenzen, zulässige Formen (`shapes`) und der Stochastik-Hinweis haben artabhängige Defaults.
#' `deterministic_only = TRUE` ist die harte Sperre gegen Overlay-, Kurzform- und Designziele; sie
#' gilt implizit für die Arten `integer`, `enum`, `logical`, `date`, `string`, `timing`, `ref` und
#' `ids`. `stochastic` ist nur ein Hinweis (Excel-Vorlage, Regler, Vorschläge).
#'
#' @param kind Art: `"number"`, `"amount"`, `"rate"`, `"share"`, `"value"`, `"integer"`,
#'   `"enum"`, `"logical"`, `"date"`, `"string"`, `"timing"`, `"schedule"`, `"ref"`, `"ids"`
#'   oder `"map"`.
#' @param ... weitere artspezifische Angaben (Feld `extra`).
#' @param default Default (Schicht 0) in Eingabeform wie in YAML.
#' @param required Pflichtparameter.
#' @param min,max Grenzen (Defaults: `amount` ab `-Inf`, `rate` in `[-0.1, 1]`, `share` in
#'   `[0, 1]`).
#' @param unit Einheit aus `inst/vocab/units.yaml`.
#' @param stochastic Hinweis „üblicherweise unsicher“ (Default artabhängig).
#' @param values bei `enum`: zulässige Codes (Vektor oder `"vocab:<enum>"`).
#' @param allow_auto erlaubt `auto` und `topup` (nur Art `amount`).
#' @param shapes zulässige Formen `"scalar"` und/oder `"path"` (Default artabhängig).
#' @param deterministic_only harte Sperre gegen stochastische Ziele.
#' @param fields bei `map`: benannte Liste von `vofi_param()`-Objekten.
#' @return Objekt der Klasse `vofi_param`.
#' @family Erweitern
#' @examples
#' vofi_param("rate", required = TRUE, unit = "rate_pa")
#' vofi_param("enum", values = "vocab:refi_rule", default = "keep_term")
#' @export
vofi_param <- function(kind, ..., default = NULL, required = FALSE, min = NULL, max = NULL,
                       unit = NULL, stochastic = NULL, values = NULL, allow_auto = FALSE,
                       shapes = NULL, deterministic_only = FALSE, fields = NULL) {
  kinds <- c("number", "amount", "rate", "share", "value", "integer", "enum", "logical",
             "date", "string", "timing", "schedule", "ref", "ids", "map")
  if (!utl_is_string(kind) || !(kind %in% kinds)) {
    vofi_abort("core.registry.param_kind", kind = utl_collapse(format(kind)),
               suggestion = utl_suggest_text(as.character(kind)[1L], kinds),
               .class = "vofi_error_registry")
  }
  numeric_kinds <- c("number", "amount", "rate", "share", "value", "schedule")
  hard_kinds <- c("integer", "enum", "logical", "date", "string", "timing", "ref", "ids")
  if (!utl_is_flag(required)) {
    vofi_abort("core.registry.param_flag", field = "required", .class = "vofi_error_registry")
  }
  if (!utl_is_flag(allow_auto)) {
    vofi_abort("core.registry.param_flag", field = "allow_auto", .class = "vofi_error_registry")
  }
  if (allow_auto && kind != "amount") {
    vofi_abort("core.registry.param_auto", kind = kind, .class = "vofi_error_registry")
  }
  if (!utl_is_flag(deterministic_only)) {
    vofi_abort("core.registry.param_flag", field = "deterministic_only",
               .class = "vofi_error_registry")
  }
  if (kind == "amount" && is.null(min)) min <- -Inf
  if (kind == "rate") {
    if (is.null(min)) min <- -0.1
    if (is.null(max)) max <- 1
  }
  if (kind == "share") {
    if (is.null(min)) min <- 0
    if (is.null(max)) max <- 1
  }
  for (b in list(min, max)) {
    if (!is.null(b) && (!is.numeric(b) || length(b) != 1L || is.na(b))) {
      vofi_abort("core.registry.param_bounds", .class = "vofi_error_registry")
    }
  }
  if (!is.null(min) && !is.null(max) && min > max) {
    vofi_abort("core.registry.param_bounds", .class = "vofi_error_registry")
  }
  if (is.null(shapes)) {
    shapes <- switch(kind,
      number = , amount = , rate = , share = , integer = "scalar",
      value = c("scalar", "path"),
      schedule = "path",
      NULL
    )
  } else if (!is.character(shapes) || !all(shapes %in% c("scalar", "path"))) {
    vofi_abort("core.registry.param_shapes", .class = "vofi_error_registry")
  }
  if (is.null(stochastic)) {
    stochastic <- if (kind %in% numeric_kinds) TRUE else if (kind == "map") NA else FALSE
  } else if (!is.logical(stochastic) || length(stochastic) != 1L) {
    vofi_abort("core.registry.param_flag", field = "stochastic", .class = "vofi_error_registry")
  }
  if (kind %in% hard_kinds) deterministic_only <- TRUE
  if (kind == "enum") {
    if (!is.character(values) || length(values) == 0L || anyNA(values)) {
      vofi_abort("core.registry.param_values", .class = "vofi_error_registry")
    }
  } else if (!is.null(values)) {
    vofi_abort("core.registry.param_values", .class = "vofi_error_registry")
  }
  if (kind == "map") {
    if (!is.list(fields) || length(fields) == 0L || is.null(names(fields)) ||
        !all(vapply(fields, inherits, logical(1), "vofi_param"))) {
      vofi_abort("core.registry.param_fields", .class = "vofi_error_registry")
    }
  } else if (!is.null(fields)) {
    vofi_abort("core.registry.param_fields", .class = "vofi_error_registry")
  }
  if (!is.null(unit) && (!utl_is_string(unit) || !vocab_has("units", unit))) {
    vofi_abort("core.registry.param_unit", unit = utl_collapse(format(unit)),
               .class = "vofi_error_registry")
  }
  structure(list(kind = kind, default = default, required = required, min = min, max = max,
                 unit = unit, stochastic = stochastic, values = values, allow_auto = allow_auto,
                 shapes = shapes, deterministic_only = deterministic_only, fields = fields,
                 extra = list(...)),
            class = "vofi_param")
}

#' Codes eines enum-Parameters
#' @param p `vofi_param` der Art `enum`.
#' @return Zeichenvektor.
#' @noRd
utl_param_codes <- function(p) {
  if (length(p$values) == 1L && startsWith(p$values, "vocab:")) {
    return(vocab_codes(p$values))
  }
  p$values
}

#' JSON-Schema des Szenarios exportieren
#'
#' Erzeugt das Eingabeschema als JSON-Schema für Editoren (Autovervollständigung und Prüfung von
#' YAML-Szenarien).
#'
#' @param path Zieldatei oder `NULL` (dann wird das Schema als Zeichenkette zurückgegeben).
#' @return Zeichenkette (JSON) bzw. `invisible(path)`.
#' @family Validieren
#' @export
vofi_json_schema <- function(path = NULL) {
  vofi_abort("core.not_implemented", fun = "vofi_json_schema",
             .class = "vofi_error_not_implemented")
}
