# Validierung Ebene 1 (Struktur) und Einstieg vofi_validate() (WS-B, Spec 00 Abschnitt 13.5).
# Phase-0-Minimalfassung, Eigentuemer: WS-B. Umgesetzt (Befunde werden gesammelt, nicht
# geworfen): unbekannte Schluessel der obersten Ebene mit Vorschlag, schema_version,
# Pflichtfelder und Codes von meta/project, Stichtag Monatserster, ids (Muster, gemeinsame
# Eindeutigkeit components/financing), registrierte Typen, Pflicht- und unbekannte Parameter,
# Codes der enum-Parameter, validate()-Funktionen der Typen, Kettenregeln 8.9, Steuermodul und
# Sperren (10.2), Kennzahlen. Offen fuer WS-B: Ebenen 2-4 vollstaendig (validate-types.R,
# validate-refs.R mit Zyklen und Bezugszielen, validate-plausibility.R), Methoden fuer
# vofi_validation (validate-report.R), Fundstellen (location).

#' Szenario bzw. Spezifikation prüfen
#'
#' Prüft ein Szenario bzw. eine aufgelöste Spezifikation auf vier Ebenen (Struktur, Typen, Bezüge,
#' Plausibilität) und sammelt alle Befunde (Spec 00, Abschnitte 2.9, 13.5).
#'
#' Phase-0-Minimalfassung (Eigentümer: WS-B): Struktur, Typen und Kettenregeln.
#'
#' @param x Objekt der Klasse `vofi_scenario` oder `vofi_spec`.
#' @param variant `NULL` (alle Varianten) oder Name einer Variante.
#' @param min_severity kleinste ausgegebene Schwere: `"info"`, `"warning"` oder `"error"`.
#' @return Objekt der Klasse `vofi_validation`.
#' @family Validieren
#' @examples
#' v <- vofi_validate(vofi_read_scenario(vofi_example("skeleton")))
#' nrow(v)
#' @export
vofi_validate <- function(x, variant = NULL, min_severity = c("info", "warning", "error")) {
  min_severity <- utl_match_arg(min_severity, c("info", "warning", "error"), "min_severity")
  if (inherits(x, "vofi_scenario")) {
    out <- val_scenario_structure(x)
    vars <- variant %||% c("base", names(x$variants %||% list()))
    for (v in vars) {
      spec <- tryCatch(vofi_resolve(x, variant = v), error = function(e) e)
      if (inherits(spec, "error")) {
        out[[length(out) + 1L]] <- val_resolve_finding(spec, v)
      } else {
        out <- c(out, val_spec(spec, v))
      }
    }
  } else if (inherits(x, "vofi_spec")) {
    out <- val_spec(x, x$variant %||% "base")
  } else {
    vofi_abort("validation.not_validatable", .class = "vofi_error_input")
  }
  df <- val_bind(out)
  rank <- c(info = 1L, warning = 2L, error = 3L)
  df <- df[rank[df$severity] >= rank[[min_severity]], , drop = FALSE]
  rownames(df) <- NULL
  new_vofi_validation(df)
}

#' Befund als Zeile des Validierungsberichts
#' @noRd
val_finding <- function(severity, code, path, ..., layer = NA_integer_,
                        variant = NA_character_) {
  data.frame(severity = severity, code = code, path = as.character(path %||% ""),
             location = NA_character_, message = msg(code, path = path, ...),
             layer = as.integer(layer), variant = as.character(variant),
             stringsAsFactors = FALSE)
}

#' Befund zu einem Fehler beim Auflösen einer Variante
#'
#' Validierungsfehler mit eigenem Schlüssel `validation.*` (z. B.
#' `validation.library.ref_not_id`, 4.9, R-110) erscheinen unter diesem Code; alle übrigen
#' Fehler als `validation.resolve_failed` mit dem Meldungstext.
#' @param cond Fehlerobjekt.
#' @param variant Variante.
#' @noRd
val_resolve_finding <- function(cond, variant) {
  key <- cond$key
  if (inherits(cond, "vofi_error_validation") && utl_is_string(key) &&
        startsWith(key, "validation.")) {
    args <- cond$args %||% list()
    return(do.call(val_finding, c(list("error", key, args$path %||% ""),
                                  args[setdiff(names(args), "path")],
                                  list(variant = variant))))
  }
  val_finding("error", "validation.resolve_failed", "", variant = variant,
              detail = conditionMessage(cond))
}

#' Befunde binden
#' @noRd
val_bind <- function(x) {
  x <- Filter(Negate(is.null), x)
  if (length(x) == 0L) return(as.data.frame(new_vofi_validation(), stringsAsFactors = FALSE))
  out <- do.call(rbind, x)
  rownames(out) <- NULL
  out
}

#' Ebene 1 für das Szenario: oberste Ebene und schema_version
#' @noRd
val_scenario_structure <- function(x) {
  out <- list()
  allowed <- c("schema_version", utl_scenario_blocks())
  for (k in setdiff(names(x), allowed)) {
    out[[length(out) + 1L]] <- val_finding("error", "validation.unknown_key", k,
                                           suggestion = utl_suggest_text(k, allowed),
                                           layer = 5L)
  }
  sv <- x$schema_version
  if (!identical(as.integer(sv %||% NA_integer_), 1L)) {
    out[[length(out) + 1L]] <- val_finding("error", "validation.schema_version",
                                           "schema_version", value = format(sv %||% "NULL"),
                                           layer = 5L)
  }
  out
}

#' Prüfungen einer aufgelösten Spezifikation
#' @noRd
val_spec <- function(spec, variant = "base") {
  acc <- new.env(parent = emptyenv())
  acc$out <- list()
  add <- function(severity, code, path, ...) {
    acc$out[[length(acc$out) + 1L]] <- val_finding(severity, code, path, ..., variant = variant)
  }
  val_meta_project(spec, add)
  val_domain_fields(spec, add)
  val_components(spec, add)
  val_accounts(spec, add)
  mod <- spec$tax$module %||% "none"
  if (!reg_has("tax", mod)) {
    add("error", "validation.tax_module_unknown", "tax.module", value = mod,
        suggestion = utl_suggest_text(mod, reg_list("tax")$name))
  } else {
    def <- reg_get("tax", mod)
    persp <- spec$project$perspective
    if ((!is.null(def$perspectives) && !(persp %in% def$perspectives)) ||
          (spec$project$tax_regime %||% "") %in% (def$blocked_regimes %||% character(0))) {
      add("error", "validation.tax_module_blocked", "tax.module", value = mod,
          perspective = persp %||% "")
    }
  }
  kpis <- spec$analysis$kpis
  if (!is.null(kpis) && !identical(kpis, "default")) {
    for (k in kpis) {
      if (!reg_has("kpi", k)) {
        add("error", "validation.kpi_unknown", "analysis.kpis", value = k,
            suggestion = utl_suggest_text(k, reg_list("kpi")$name))
      }
    }
  }
  acc$out
}

#' Felder der Domänenblöcke ohne Schema-Eintrag bekannt nach Spec 00 4.3 bzw. Spec 01 (Phase 0)
#' @noRd
val_known_extra_fields <- function(block) {
  switch(block,
    meta = "version",
    project = c("municipality", "construction_cost_factor"),
    analysis = c("thresholds", "traffic_light", "mandatory_sensitivities"),
    tax = "params",
    character(0)
  )
}

#' Unbekannte Felder der Domänenblöcke (Ebene 1, 4.3; Spec 01 Teil A 1.3 GA4)
#'
#' Fehler in Blöcken, deren Feldliste nach Spec 00 4.3 und Spec 01 Teil A 1.1-1.6, 5.7 bereits
#' vollständig ist (`meta`, `project`, `grid`, `accounts`, `tax`, `analysis`); Warnung in
#' Blöcken, deren Feldkatalog Spec 01 noch ergänzt (`building`, `household`, `residual_value`).
#' WS-B stellt auf Fehler um, sobald das Schema aus Spec 01 vollständig ist.
#' @noRd
val_domain_fields <- function(spec, add) {
  strict <- c("meta", "project", "grid", "accounts", "tax", "analysis")
  for (b in c("meta", "project", "grid", "building", "household", "accounts",
              "residual_value", "tax", "analysis")) {
    x <- spec[[b]]
    if (!is_map(x) || length(x) == 0L) next
    known <- c(names(val_domain_schema(b)), val_known_extra_fields(b))
    for (f in setdiff(names(x), known)) {
      add(if (b %in% strict) "error" else "warning", "validation.unknown_field",
          path_join(b, f), suggestion = utl_suggest_text(f, known))
    }
  }
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

#' meta und project (4.3.1, 4.3.2)
#' @noRd
val_meta_project <- function(spec, add) {
  sid <- spec$meta$scenario_id
  if (is.null(sid)) {
    add("error", "validation.required", "meta.scenario_id")
  } else if (!utl_is_string(sid) || !grepl("^[a-z][a-z0-9_]*$", sid)) {
    add("error", "validation.id_invalid", "meta.scenario_id", value = format(sid))
  }
  if (is.null(spec$meta$title)) add("error", "validation.required", "meta.title")
  p <- spec$project
  for (f in c("perspective", "project_type", "valuation_date")) {
    if (is.null(p[[f]])) add("error", "validation.required", path_join("project", f))
  }
  enums <- list(perspective = "perspective", project_type = "project_type",
                tax_regime = "tax_regime", comparison_mode = "comparison_mode",
                report_mode = "report_mode")
  for (f in names(enums)) {
    v <- p[[f]]
    if (!is.null(v) && !(utl_is_string(v) && vocab_has(enums[[f]], v))) {
      add("error", "validation.enum", path_join("project", f), value = utl_collapse(format(v)),
          suggestion = utl_suggest_text(as.character(v)[1L], vocab_codes(enums[[f]])))
    }
  }
  vd <- p$valuation_date
  if (inherits(vd, "Date") && utl_mday(vd) != 1L) {
    add("error", "validation.valuation_first", "project.valuation_date", value = vd)
  }
  hy <- p$horizon_years
  if (is.null(spec$grid$periods_months) && (!utl_is_whole(hy) || hy < 1)) {
    add("error", "validation.horizon", "project.horizon_years")
  }
}

#' components und financing: ids, Typen, Parameter (4.3.8, 4.3.9, 4.4)
#' @noRd
val_components <- function(spec, add) {
  seen <- character(0)
  for (coll in c("components", "financing")) {
    for (id in names(spec[[coll]])) {
      path <- path_join(coll, id)
      comp <- spec[[coll]][[id]]
      if (!utl_is_id(id) || id %in% c("base", "engine")) {
        add("error", "validation.id_invalid", path, value = id)
      }
      if (id %in% seen) add("error", "validation.id_duplicate", path, value = id)
      seen <- c(seen, id)
      type <- comp$type
      def <- scn_type_def(type, coll)
      if (is.null(def) || (identical(coll, "components") && !identical(def$kind, "flow")) ||
            (identical(coll, "financing") && identical(def$kind, "flow") &&
               !identical(def$name, "equity"))) {
        choices <- if (identical(coll, "financing")) c("equity", reg_list("instrument")$name) else
          reg_list("flow")$name
        add("error", "validation.type_unknown", path_join(path, "type"),
            value = utl_collapse(format(type %||% "NULL")),
            suggestion = utl_suggest_text(as.character(type %||% "")[1L], choices))
        next
      }
      for (p in names(def$params)) {
        pp <- def$params[[p]]
        if (isTRUE(pp$required) && is.null(comp[[p]])) {
          add("error", "validation.param_required", path_join(path, p))
        }
        v <- comp[[p]]
        if (identical(pp$kind, "enum") && !is.null(v) &&
              !(utl_is_string(v) && v %in% utl_param_codes(pp))) {
          add("error", "validation.enum", path_join(path, p), value = utl_collapse(format(v)),
              suggestion = utl_suggest_text(as.character(v)[1L], utl_param_codes(pp)))
        }
      }
      val_param_ranges(def$params, comp, path, add)
      known <- c(names(def$params), reg_reserved_fields())
      for (f in setdiff(names(comp), known)) {
        add("error", "validation.param_unknown", path_join(path, f), type = def$name,
            suggestion = utl_suggest_text(f, names(def$params)))
      }
      if (is.function(def$validate)) {
        for (fd in def$validate(comp, spec) %||% list()) {
          do.call(add, c(list(fd$severity, fd$code, fd$path %||% path), fd$args))
        }
      }
    }
  }
}

#' Wertebereiche (min/max des Parameterschemas, 5.4) für Konstanten und Periodenreihen
#'
#' Phase-0-Minimalfassung (Ebene 2): geprüft werden Konstanten (`const`), Zahlen und numerische
#' Elemente von `series_t`; Bezüge, Ausdrücke und Pfade prüft WS-B in Ebene 2/4.
#' @noRd
val_param_ranges <- function(params, comp, path, add) {
  for (p in names(params)) {
    pp <- params[[p]]
    if (is.null(pp$min) && is.null(pp$max)) next
    v <- comp[[p]]
    vals <- if (is.list(v) && identical(v$kind, "const")) v$value else
      if (is.list(v) && identical(v$kind, "series_t") && is.numeric(v$values)) v$values else
        if (is.numeric(v)) v else numeric(0)
    vals <- vals[is.finite(vals)]
    lo <- pp$min %||% -Inf
    hi <- pp$max %||% Inf
    bad <- vals[vals < lo | vals > hi]
    if (length(bad) > 0L) {
      add("error", "validation.range", path_join(path, p), value = bad[1L],
          min = format(lo), max = format(hi))
    }
  }
}

#' Ausgleichsketten (8.9)
#' @noRd
val_accounts <- function(spec, add) {
  a <- spec$accounts %||% list()
  chains <- list(surplus_order = list(role = "surplus", first = "od_repay",
                                      last = "dep_invest"),
                 deficit_order = list(role = "deficit", first = "dep_withdraw",
                                      last = c("equity_call", "penalty_rate", "stop")))
  for (nm in names(chains)) {
    ch <- a[[nm]]
    rule <- chains[[nm]]
    path <- path_join("accounts", nm)
    if (is.null(ch) || length(ch) == 0L) {
      add("error", "validation.required", path)
      next
    }
    ok_names <- TRUE
    for (act in ch) {
      if (!reg_has("account_action", act)) {
        add("error", "validation.chain_action_unknown", path, value = act,
            suggestion = utl_suggest_text(act, reg_list("account_action")$name))
        ok_names <- FALSE
      } else if (!identical(reg_get("account_action", act)$role, rule$role)) {
        add("error", "validation.chain_role", path, value = act)
        ok_names <- FALSE
      }
    }
    if (!ok_names) next
    ranks <- vapply(ch, function(act) reg_get("account_action", act)$rank, "")
    ok <- identical(ch[1L], rule$first) && ch[length(ch)] %in% rule$last &&
      !anyDuplicated(ch) && !anyDuplicated(ranks) &&
      identical(order(ranks, method = "radix"), seq_along(ranks))
    if (identical(rule$role, "deficit")) ok <- ok && sum(grepl("^D4$", ranks)) == 1L
    if (!ok) {
      add("error", "validation.chain_order", path, first = rule$first,
          last = utl_collapse(rule$last, " | "))
    }
  }
}
