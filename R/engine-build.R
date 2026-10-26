# Build-Stufen (WS-D, Spec 00 Abschnitt 9.1).
# Phase-0-Minimalfassung, Eigentuemer: WS-D. Umgesetzt: Stufen 1-6a, 8-10 (Aufloesung,
# Validierung, Raster, topologisch sortierte Komponenten nach ref-Parametern, Bezuegen und
# after, Instrumente in financing-Reihenfolge, Ketten, Basisfall-Vorlauf, Steuermodul mit
# Sperren, Kennzahlen mit Filter nach perspectives und requires, Hash). Offen fuer WS-D:
# Stufe 7 Sampler-Plan (smp_plan(), WS-C; bis dahin model$sampler = NULL), amount_eur auto
# (8.7, engine-auto.R), Entscheidungsknoten (9a).

#' Rechenfertiges Modell bauen
#'
#' Baut aus einem Szenario oder einer Spezifikation ein rechenfertiges Modell: Validierung,
#' Zeitraster, sortierte Komponenten, Instrumente, Ausgleichsketten, Basisfall-Vorlauf,
#' Sampler-Plan, Steuermodul und Kennzahlen (Spec 00, Abschnitt 9.1).
#'
#' Phase-0-Minimalfassung (Eigentümer: WS-D): ohne Sampler-Plan (WS-C), ohne `amount_eur: auto`
#' und ohne Entscheidungsknoten.
#'
#' @param x Objekt der Klasse `vofi_scenario` oder `vofi_spec`.
#' @param variant Variante (Default `"base"`).
#' @param overrides optional: Laufzeit-Overrides (Schicht 8).
#' @param scenario_set optional: Name eines Szenario-Sets.
#' @return Objekt der Klasse `vofi_model`.
#' @family Rechnen
#' @examples
#' model <- vofi_build(vofi_read_scenario(vofi_example("skeleton")))
#' names(model$nodes)
#' @export
vofi_build <- function(x, variant = "base", overrides = NULL, scenario_set = NULL) {
  if (!inherits(x, c("vofi_scenario", "vofi_spec"))) {
    vofi_abort("engine.not_buildable", .class = "vofi_error_input")
  }
  # Ebene 1 vor der Aufloesung: unbekannte Wurzelschluessel des Szenarios und der Overrides
  # (4.2); vofi_resolve() uebernimmt nur bekannte Bloecke.
  pre <- if (inherits(x, "vofi_scenario")) val_scenario_structure(x) else list()
  if (!is.null(overrides)) {
    overrides <- scn_overrides_tree(overrides)
    pre <- c(pre, val_overrides_structure(overrides))
  }
  spec <- if (inherits(x, "vofi_scenario")) {
    vofi_resolve(x, variant = variant, overrides = overrides, scenario_set = scenario_set)
  } else {
    if (is.null(overrides)) x else scn_apply_overrides(x, overrides)
  }
  report <- vofi_validate(spec)
  if (length(pre) > 0L) {
    report <- new_vofi_validation(val_bind(c(pre, list(as.data.frame(unclass(report),
                                                                     stringsAsFactors = FALSE)))))
  }
  errs <- report[report$severity == "error", , drop = FALSE]
  if (nrow(errs) > 0L) {
    vofi_abort("engine.validation_failed", n = nrow(errs),
               details = utl_collapse(errs$message, sep = " | "),
               .class = "vofi_error_validation", .data = list(report = report))
  }
  grid <- eng_build_grid(spec)
  nodes <- eng_build_nodes(spec)
  instruments <- eng_build_instruments(spec)
  auto <- eng_auto_ids(instruments)
  surplus <- eng_build_chain(spec$accounts$surplus_order)
  deficit <- eng_build_chain(spec$accounts$deficit_order)
  tax_def <- reg_get("tax", spec$tax$module %||% "none")
  tax_params <- spec$tax$params %||% list()
  tax_mod <- tax_def$constructor(tax_params, spec)
  # 9.3: die Engine liest model$tax$uses_inputs (Default aus der Typdefinition, 5.3)
  if (is.null(tax_mod$uses_inputs)) tax_mod$uses_inputs <- isTRUE(tax_def$uses_inputs)
  model <- new_vofi_model(list(
    spec = spec, grid = grid, nodes = nodes, instruments = instruments,
    equity = names(nodes)[vapply(nodes, function(nd) identical(nd$def$name, "equity"),
                                 logical(1))],
    accounts = list(prepay = spec$accounts$prepay %||% list()),
    surplus_chain = surplus, deficit_chain = deficit, sampler = NULL,
    tax = tax_mod, tax_params = tax_params,
    kpis = eng_build_kpis(spec), auto_id = auto$auto, topup_id = auto$topup,
    hash = stable_hash(spec), contract_version = VOFI_CONTRACT_VERSION
  ))
  model$base <- eng_base_run(model)
  model$kpis <- eng_filter_kpis_requires(model$kpis, spec, model$base$flows)
  model
}

#' Enthält die Überschusskette Ü3 (loan_prepay)? Ohne Ü3 gilt der Instrument-Cache (9.3)
#' @noRd
eng_has_prepay <- function(model) "loan_prepay" %in% names(model$surplus_chain)

#' Zeitraster aus project und grid (3.3, 9.1 Stufe 3)
#' @noRd
eng_build_grid <- function(spec) {
  p <- spec$project
  g <- spec$grid %||% list()
  vofi_time_grid(p$valuation_date, p$horizon_years,
                 construction_months = g$construction_months %||% 0L,
                 construction_step_months = g$construction_step_months %||% 12L,
                 operation_step_months = g$operation_step_months %||% 12L,
                 operation_alignment = g$operation_alignment %||% "calendar",
                 periods_months = g$periods_months,
                 start_year = spec$stochastic$settings$start_year)
}

#' Abhängigkeiten einer Komponente: ref-Parameter, Bezüge auf components/financing, after
#' @noRd
eng_component_deps <- function(comp, def, ids) {
  deps <- as.character(unlist(comp$after))
  for (p in names(def$params)) {
    if (identical(def$params[[p]]$kind, "ref") && utl_is_string(comp[[p]])) {
      deps <- c(deps, comp[[p]])
    }
  }
  targets <- eng_ref_targets(comp)
  for (tg in targets) {
    segs <- path_split(tg)
    if (length(segs) >= 2L && segs[1L] %in% c("components", "financing")) deps <- c(deps, segs[2L])
  }
  intersect(unique(deps), setdiff(ids, comp$id))
}

#' Bezugsziele aller Knoten einer Struktur (ref-Pfade und Ausdruckssymbole)
#' @noRd
eng_ref_targets <- function(x) {
  if (node_is(x)) {
    out <- switch(x$kind,
      ref = x$path,
      expr = expr_symbols(x$ast %||% expr_parse(x$text)),
      character(0)
    )
    sub_nodes <- x[intersect(names(x), c("values", "amounts", "start", "growth", "value"))]
    return(c(out, unlist(lapply(sub_nodes, eng_ref_targets), use.names = FALSE)))
  }
  if (is.list(x)) return(unlist(lapply(x, eng_ref_targets), use.names = FALSE))
  character(0)
}

#' Zahlungskomponenten (components + equity-Bausteine) topologisch sortieren (9.1 Stufe 4)
#'
#' Kahn-Verfahren, Gleichstand alphabetisch nach id (`method = "radix"`); Zyklus ist ein
#' Validierungsfehler mit Pfad.
#' @return benannte Liste `list(spec, def, deps, position, path)` in Topo-Reihenfolge.
#' @noRd
eng_build_nodes <- function(spec) {
  items <- list()
  for (coll in c("components", "financing")) {
    for (id in names(spec[[coll]])) {
      comp <- spec[[coll]][[id]]
      def <- scn_type_def(comp$type, coll)
      if (!identical(def$kind, "flow")) next
      items[[id]] <- list(spec = comp, def = def, path = path_join(coll, id),
                          position = length(items) + 1L)
    }
  }
  ids <- names(items)
  for (id in ids) items[[id]]$deps <- eng_component_deps(items[[id]]$spec, items[[id]]$def, ids)
  order_ids <- character(0)
  remaining <- ids
  while (length(remaining) > 0L) {
    ready <- remaining[vapply(remaining, function(id) {
      all(items[[id]]$deps %in% order_ids)
    }, logical(1))]
    if (length(ready) == 0L) {
      vofi_abort("engine.cycle", path = utl_collapse(utl_sort(remaining), " -> "),
                 .class = "vofi_error_validation")
    }
    nxt <- utl_sort(ready)[1L]
    order_ids <- c(order_ids, nxt)
    remaining <- setdiff(remaining, nxt)
  }
  items[order_ids]
}

#' Kreditinstrumente in financing-Reihenfolge (9.1 Stufe 5)
#' @noRd
eng_build_instruments <- function(spec) {
  out <- list()
  for (id in names(spec$financing)) {
    comp <- spec$financing[[id]]
    def <- scn_type_def(comp$type, "financing")
    if (!identical(def$kind, "instrument")) next
    out[[id]] <- list(spec = comp, def = def, k = length(out) + 1L,
                      path = path_join("financing", id))
  }
  out
}

#' Instrumente mit amount_eur auto bzw. topup (8.7)
#' @noRd
eng_auto_ids <- function(instruments) {
  auto <- topup <- NULL
  for (id in names(instruments)) {
    a <- instruments[[id]]$spec$amount_eur
    if (node_is(a) && identical(a$kind, "auto")) {
      if (identical(a$mode, "topup")) topup <- c(topup, id) else auto <- c(auto, id)
    }
  }
  if (length(auto) > 1L || length(topup) > 1L) {
    vofi_abort("engine.auto_multiple", .class = "vofi_error_validation")
  }
  list(auto = auto, topup = topup)
}

#' Ausgleichskette aus Aktionsnamen (8.9)
#' @noRd
eng_build_chain <- function(names_chain) {
  out <- lapply(as.character(names_chain), function(a) reg_get("account_action", a))
  stats::setNames(out, as.character(names_chain))
}

#' Kennzahlen nach analysis.kpis, gefiltert nach perspectives (9.1 Stufe 9)
#'
#' `analysis.kpis: default` bedeutet den Kennzahlensatz des Perspektiven-Profils (Spec 01 Teil A
#' 1.5); solange die Profile fehlen (WS-A, Welle 2), gelten in Phase 0 alle registrierten
#' Kennzahlen. Der Filter nach `requires` folgt nach dem Basisfall-Vorlauf
#' ([eng_filter_kpis_requires()]).
#' @noRd
eng_build_kpis <- function(spec) {
  sel <- spec$analysis$kpis
  all_names <- reg_list("kpi")$name
  names_kpi <- if (is.null(sel) || identical(sel, "default")) all_names else sel
  defs <- lapply(names_kpi, function(k) reg_get("kpi", k))
  persp <- spec$project$perspective
  keep <- vapply(defs, function(d) is.null(d$perspectives) || persp %in% d$perspectives,
                 logical(1))
  stats::setNames(defs[keep], names_kpi[keep])
}

#' Verfügbare Datengrundlagen für `requires` (5.3, 9.1 Stufe 9)
#'
#' Phase-0-Regel (WS-D/WS-D2 präzisieren): `opportunity` immer; `market_value`, wenn eine
#' Komponente des Basisfalls eine Zeile der Kategorie `market_value` schreibt oder
#' `building.market_value_eur` gesetzt ist; `household_income` bei
#' `household.net_income_month_eur`; `living_area` bei `building.living_area_m2` bzw.
#' Wohnflächen der Wohnungsgruppen; `tenant_data` bei Wohnungsgruppen oder Mieter-Merkzeilen
#' (`tenant_*`) im Basisfall.
#' @param spec `vofi_spec`.
#' @param base_flows `vofi_flows` des Basisfall-Vorlaufs je Komponente.
#' @return Zeichenvektor der verfügbaren Grundlagen.
#' @noRd
eng_kpi_available <- function(spec, base_flows = list()) {
  cats <- unlist(lapply(base_flows, function(fl) {
    vapply(fl$rows, function(r) r$category, "")
  }), use.names = FALSE)
  ug <- spec$unit_groups %||% list()
  has <- c(
    opportunity = TRUE,
    market_value = "market_value" %in% cats || !is.null(spec$building$market_value_eur),
    household_income = !is.null(spec$household$net_income_month_eur),
    living_area = !is.null(spec$building$living_area_m2) ||
      any(vapply(ug, function(g) !is.null(g$living_area_m2), logical(1))),
    tenant_data = length(ug) > 0L || any(startsWith(cats, "tenant_"))
  )
  names(has)[has]
}

#' Kennzahlen ohne verfügbare Datengrundlage entfernen (9.1 Stufe 9)
#'
#' Ausdrücklich angeforderte Kennzahlen, die entfallen, werden mit `vofi_inform()` gemeldet.
#' @noRd
eng_filter_kpis_requires <- function(kpis, spec, base_flows) {
  if (length(kpis) == 0L) return(kpis)
  avail <- eng_kpi_available(spec, base_flows)
  keep <- vapply(kpis, function(d) all((d$requires %||% character(0)) %in% avail), logical(1))
  explicit <- !identical(spec$analysis$kpis %||% "default", "default")
  if (explicit && any(!keep)) {
    for (nm in names(kpis)[!keep]) {
      vofi_inform("engine.kpi_requires", kpi = nm,
                  missing = utl_collapse(setdiff(kpis[[nm]]$requires, avail)))
    }
  }
  kpis[keep]
}

#' Basisfall-Vorlauf (9.1 Stufe 6a, R-69, R-70): Flüsse mit n = 1 im deterministischen Modus
#' @return `list(flows, n = 1, auto, need0)`.
#' @noRd
eng_base_run <- function(model) {
  env <- eng_engine_env(model)
  ctx <- eng_context(model, draws = NULL, engine_env = env)
  exo <- eng_flows(model, ctx, env)
  auto <- eng_auto_base(model, ctx, exo)
  list(flows = env$components, n = 1L, auto = auto$auto, need0 = auto$need0)
}
