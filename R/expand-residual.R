# Expander residual (WS-E2, Spec 01 Teil A 6.2; Spec 00 4.12 Nr. 8, R-72, R-108): genau eine
# Komponente rv_value vom Typ residual_value. Numerische Blaetter der gewaehlten Methode als
# Bezuege, deterministische Tabellen (rnd_table, points_max) und Codes als Werte; Gebaeudewerte
# (n_units, living_area_m2, Baujahr, Modernisierungspunkte, Bestandswert) aus building bzw.
# measures. Methode zero ohne Zeitwertpfade der Massnahmen: Komponente ohne Abhaengigkeiten
# (Nullzeilen, Tabellenstabilitaet). Ohne Gebaeudedaten (Teil A 3.1, 6.2 Nr. 5): user_value,
# market_growth und exit_yield ohne Gebaeudebezug; zero ohne Komponente; uebrige Methoden E,
# ausser die Methode stammt aus den Defaults-Dateien (dann ohne Komponente, Teil A 3.1, 6.1).

#' Methoden, die ohne `building` zulässig sind (Teil A 6.2 Nr. 5)
#' @noRd
exp_rv_methods_without_building <- function() {
  c("user_value", "zero", "market_growth", "exit_yield")
}

#' Restwertmethode der Defaults-Dateien (global.yaml und Profil, je Projektart) oder `NULL`
#'
#' Dient der Unterscheidung „Methode aus Profil bzw. global.yaml“ gegenüber „Methode aus
#' Szenario, Variante, Set oder Override“, solange `bctx` keine Herkunft liefert: Gleicht die
#' Methode der Spezifikation der Methode der Schichten 1–2 zu Perspektive und Projektart, gilt sie
#' als Vorgabe (auch wenn der Nutzer dieselbe Methode ausdrücklich setzt).
#' @noRd
exp_rv_default_method <- function(x) {
  defaults <- tryCatch(scn_defaults_stack(x$project$perspective), error = function(e) list())
  pt <- x$project$project_type
  out <- NULL
  for (d in defaults) {
    out <- exp_code(d$tree$residual_value$method) %||% out
    if (utl_is_string(pt)) out <- exp_code(d$bpt[[pt]]$residual_value$method) %||% out
  }
  out
}

#' Teilbaum einer Methode als Parameter (Schema des Typs residual_value)
#'
#' Numerische Blätter (Parameterarten `number`, `amount`, `rate`, `share`, `value`) als Bezüge,
#' deterministische Parameter (`deterministic_only`, Ganzzahlen, Codes, Flags, ids) und die
#' Tabellen `rnd_table`, `points_max` als Werte.
#' @param x Spezifikation.
#' @param tree Teilbaum (Domänenwerte).
#' @param prefix Domänenpfad des Teilbaums.
#' @param params Parameterschema des Teilbaums (`fields` des map-Parameters) oder `NULL`.
#' @noRd
exp_rv_tree <- function(x, tree, prefix, params = NULL) {
  out <- list()
  for (nm in names(tree)) {
    v <- tree[[nm]]
    if (is.null(v)) next
    p <- paste0(prefix, ".", nm)
    pp <- params[[nm]] %||% params[["*"]]
    kind <- if (inherits(pp, "vofi_param")) pp$kind else NA_character_
    det <- inherits(pp, "vofi_param") && isTRUE(pp$deterministic_only)
    if (nm %in% c("rnd_table", "points_max")) {
      out[[nm]] <- exp_rv_values(v)
    } else if (identical(kind, "map") || (is.na(kind) && is_map(v) && !node_is(v))) {
      out[[nm]] <- exp_rv_tree(x, v, p, if (inherits(pp, "vofi_param")) pp$fields else NULL)
    } else if (kind %in% c("number", "amount", "rate", "share", "value", "schedule") && !det) {
      out[[nm]] <- node_ref(p)
    } else if (kind %in% c("number", "amount", "rate", "share", "value")) {
      out[[nm]] <- exp_num(v) %||% v
    } else if (identical(kind, "integer")) {
      iv <- exp_num(v)
      out[[nm]] <- if (is.null(iv)) v else as.integer(round(iv))
    } else if (identical(kind, "logical")) {
      out[[nm]] <- exp_lgl(v) %||% v
    } else if (identical(kind, "ids")) {
      out[[nm]] <- exp_chr(v)
    } else if (kind %in% c("enum", "string", "ref", "date", "timing")) {
      out[[nm]] <- if (is.list(v) && !node_is(v)) exp_chr(v) else v
    } else if (node_is(v)) {
      out[[nm]] <- node_ref(p)
    } else {
      out[[nm]] <- v
    }
  }
  out
}

#' Deterministische Tabelle als Zahlenwerte (Konstantenknoten -> Zahl)
#' @noRd
exp_rv_values <- function(v) {
  if (node_is(v)) return(exp_num(v) %||% v)
  if (is.list(v)) return(lapply(v, exp_rv_values))
  v
}

#' Komponenten mit Zeitwertpfad (Typ replacement)
#' @noRd
exp_rv_value_paths <- function(x) {
  comps <- x$components %||% list()
  names(comps)[vapply(comps, function(c) identical(c[["type"]], "replacement"), logical(1))]
}

#' Expander residual (Teil A 6.2)
#' @noRd
residual_expand <- function(block, scenario, bctx) {
  x <- scenario
  rv <- block %||% list()
  method <- exp_code(rv[["method"]]) %||% "zero"
  has_building <- exp_building_data(x)
  if (!has_building && identical(method, "zero")) {
    # Teil A 3.1: ohne Gebäudebezug läuft der Expander nicht; bei zero geht kein Wert verloren
    return(NULL)
  }
  if (!has_building && !(method %in% exp_rv_methods_without_building())) {
    # Teil A 6.2 Nr. 5: E, wenn die Methode aus Szenario, Variante, Set oder Override stammt.
    # Teil A 6.1 und 3.1: Szenarien ohne building (Gerüst, Orakel, Engine-Tests) bleiben mit der
    # Methode des Profils gültig; der Expander läuft dann nicht (ohne Meldung; Konflikt 6.1/6.2
    # an den Integrator).
    if (identical(method, exp_rv_default_method(x))) return(NULL)
    bctx$abort("expand.residual.method_needs_building", method = method)
  }
  if (!has_building && identical(method, "market_growth") &&
        !exp_has(x, "residual_value.market_growth.base_value_eur") &&
        !exp_has(x, "building.existing_value_eur") && !exp_has(x, "building.market_value_eur")) {
    bctx$abort("expand.residual.base_value_missing")
  }
  bid <- exp_code(x$building$building_id) %||% "b1"
  cmp <- list(type = "residual_value", label = bctx$lbl("expand.residual.label"),
              asset_id = paste0(bid, "_building"), method = method)
  if (exp_has(x, "residual_value.sale_cost_share")) {
    cmp$sale_cost_share <- node_ref("residual_value.sale_cost_share")
  }
  ppo <- exp_code(rv[["path_pre_operation"]])
  if (!is.null(ppo)) cmp$path_pre_operation <- ppo
  if (!identical(method, "zero") && is_map(rv[[method]])) {
    schema <- reg_get("flow", "residual_value")$params[[method]]
    cmp[[method]] <- exp_rv_tree(x, rv[[method]], paste0("residual_value.", method),
                                 if (inherits(schema, "vofi_param")) schema$fields else NULL)
  }
  if (!identical(method, "component") && is_map(rv[["component"]])) {
    det <- list()
    for (f in c("indexed", "include_land")) {
      v <- exp_lgl(rv[["component"]][[f]])
      if (!is.null(v)) det[[f]] <- v
    }
    ie <- rv[["component"]][["include_existing"]]
    if (!is.null(ie)) det$include_existing <- if (is.logical(ie)) tolower(ie) else exp_code(ie)
    if (length(det) > 0L) cmp$component <- det
  }
  if (exp_has(x, "building.existing_value_eur")) {
    cmp$existing_value_eur <- node_ref("building.existing_value_eur")
  }
  if (has_building) {
    for (f in c("n_units", "living_area_m2")) {
      if (exp_has(x, paste0("building.", f))) cmp[[f]] <- node_ref(paste0("building.", f))
    }
    for (f in c("construction_year", "fictitious_construction_year")) {
      v <- exp_int(x$building[[f]])
      if (!is.null(v)) cmp[[f]] <- v
    }
    pb <- x$building$modernization_points_before %||% list()
    if (length(pb) > 0L) {
      cmp$points_before <- stats::setNames(lapply(names(pb), function(el) {
        node_ref(paste0("building.modernization_points_before.", el))
      }), names(pb))
    }
  }
  pm <- list()
  for (m in names(x$measures %||% list())) {
    pts <- x$measures[[m]][["effects"]][["residual"]][["modernization_points"]] %||% list()
    if (length(pts) == 0L) next
    pm[[m]] <- stats::setNames(lapply(names(pts), function(el) {
      node_ref(paste0("measures.", m, ".effects.residual.modernization_points.", el))
    }), names(pts))
  }
  if (length(pm) > 0L) cmp$points_measures <- pm
  if (!identical(method, "zero") || length(exp_rv_value_paths(x)) > 0L) {
    deps <- setdiff(names(x$components %||% list()), "rv_value")
    readers <- vapply(deps, function(id) {
      c <- x$components[[id]]
      identical(c[["type"]], "share_of") && "rv_value" %in% exp_chr(c[["of"]])
    }, logical(1))
    cmp$after <- deps[!readers]
  }
  list(components = list(rv_value = cmp), financing = list(), assets = list(),
       measures = list())
}

#' @noRd
typedef_expander_residual <- function() {
  vofi_type(name = "residual", kind = "expander", block = "residual_value", order = 60L,
            expand = residual_expand)
}
