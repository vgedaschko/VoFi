# Build-Stufen (WS-D, Spec 00 Abschnitt 9.1): Aufloesung (WS-A), Validierung (WS-B), Raster,
# topologisch sortierte Komponenten (ref-Parameter, Bezuege auf components/financing, after;
# Kahn mit Gleichstand nach id), Instrumente in financing-Reihenfolge (hoechstens ein auto und
# ein topup, 8.7), Ausgleichsketten, Basisfall-Vorlauf (6a: Fluesse mit n = 1, auto-Betrag und
# need0, R-69, R-70), Sampler-Plan (smp_plan() von WS-C, zur Laufzeit aufgeloest), Steuermodul
# mit Sperren und Parameter-Defaults (10.2), Kennzahlen (perspectives, requires),
# Entscheidungsknoten der Foerderzusage mit Ausweichvariante (9a, 9.11, R-71), Hash.

#' Rechenfertiges Modell bauen
#'
#' Baut aus einem Szenario oder einer Spezifikation ein rechenfertiges Modell (Spec 00,
#' Abschnitt 9.1): Auflösung und Validierung, Zeitraster, topologisch sortierte
#' Zahlungskomponenten, Kreditinstrumente, Ausgleichsketten, Basisfall-Vorlauf (Kreditbeträge
#' `amount_eur: auto` werden hier einmal bestimmt und gelten in allen Läufen, R-69),
#' Sampler-Plan, Steuermodul und Kennzahlen. Ist ein Förderinstrument ein Entscheidungsknoten
#' (`approval_timing: before_start` und `fallback_variant`, Abschnitt 9.11), wird das Modell der
#' Ausweichvariante mitgebaut (`model$decision`); im Modell der Variante gilt die Zusage dann
#' stets als erteilt.
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
  # 9a (vorgezogen): Entscheidungsknoten erkennen; im Modell der Variante gilt die Zusage
  # stets als erteilt (9.11 Nr. 2), der Zweig des Basisfalls ist der Wert vor dem Setzen
  node <- eng_decision_node(spec)
  if (!is.null(node)) {
    # die Ausweichvariante darf selbst keinen Knoten haben (9.11 Nr. 1; verhindert Rekursion)
    if (isTRUE(eng_build_state$fallback)) {
      vofi_abort("engine.decision_nested", variant = variant, .class = "vofi_error_validation")
    }
    node$branch <- eng_decision_branch(spec, node$key)
    node$p <- eng_decision_probability(spec, node$funding_id)
    spec <- path_set(spec, node$key, node_const(1))
  }
  grid <- eng_build_grid(spec)
  nodes <- eng_build_nodes(spec)
  instruments <- eng_build_instruments(spec)
  auto <- eng_auto_ids(instruments, grid)
  surplus <- eng_build_chain(spec$accounts$surplus_order)
  deficit <- eng_build_chain(spec$accounts$deficit_order)
  tax <- eng_build_tax(spec, grid)
  model <- new_vofi_model(list(
    spec = spec, grid = grid, nodes = nodes, instruments = instruments,
    equity = names(nodes)[vapply(nodes, function(nd) identical(nd$def$name, "equity"),
                                 logical(1))],
    accounts = eng_model_accounts(spec),
    surplus_chain = surplus, deficit_chain = deficit, sampler = NULL,
    tax = tax$module, tax_params = tax$params,
    kpis = eng_build_kpis(spec), auto_id = auto$auto, topup_id = auto$topup,
    hash = stable_hash(spec), contract_version = VOFI_CONTRACT_VERSION
  ))
  model$rows_meta <- list(inv = eng_model_rows(instruments),
                          opp = eng_model_rows(list(), opp = TRUE))
  model$base <- eng_base_run(model)
  model$sampler <- eng_build_sampler(spec, grid)
  model$kpis <- eng_filter_kpis_requires(model$kpis, spec, model$base$flows)
  if (!is.null(node)) {
    model$decision <- eng_build_decision(x, node, overrides, scenario_set)
  }
  model
}

#' Normalisierte Kontoparameter des Modells (4.13, 8.8)
#'
#' Der Block `accounts` der Spezifikation (Knoten der Kontoparameter, Ketten `surplus_order`,
#' `deficit_order`, `prepay`); Grundlage von `acc_init()` und der Vergleichbarkeitsprüfung
#' identischer Kontenparameter (9.6 Nr. 2). Die Werte löst die Engine je Lauf über
#' `ctx$value("accounts.<feld>")` auf (Ziehungen, Bezüge).
#' @return Liste (mindestens `prepay`).
#' @noRd
eng_model_accounts <- function(spec) {
  acc <- spec[["accounts"]] %||% list()
  if (is.null(acc[["prepay"]])) acc["prepay"] <- list(list())
  acc
}

#' Sampler-Plan (9.1 Stufe 7, WS-C: `smp_plan(spec, grid)`); ohne Sampler `NULL`
#' @noRd
eng_build_sampler <- function(spec, grid = NULL) {
  f <- get0("smp_plan", envir = topenv(environment(eng_smp_fun)), mode = "function",
            inherits = FALSE)
  if (is.null(f)) NULL else f(spec, grid)
}

#' Steuermodul mit Sperren und Parameter-Defaults (9.1 Stufe 8, 10.2)
#'
#' Sperren: `perspective` außerhalb von `perspectives` bzw. `tax_regime` in `blocked_regimes`
#' ergeben `vofi_error_validation` (`validation.tax_module_blocked`). Fehlende Parameter
#' erhalten den Default aus dem Parameterschema des Moduls; Wertknoten werden zu ihren
#' Basisfallwerten aufgelöst (das Modul erhält Zahlen bzw. Zeichenketten).
#' @param grid `vofi_grid` (Auflösung von Pfaden und Bezügen) oder `NULL`.
#' @return `list(module, params)`.
#' @noRd
eng_build_tax <- function(spec, grid = NULL) {
  name <- spec$tax$module %||% "none"
  def <- reg_get("tax", name)
  persp <- spec$project$perspective %||% NA_character_
  regime <- spec$project$tax_regime %||% NA_character_
  blocked <- (!is.null(def$perspectives) && !(persp %in% def$perspectives)) ||
    (!is.null(def$blocked_regimes) && regime %in% def$blocked_regimes)
  if (blocked) {
    text <- msg("validation.tax_module_blocked", value = name, path = "tax.module",
                perspective = persp, reason = val_tax_blocked_reason(name, persp, regime))
    rep_df <- data.frame(
      severity = "error", code = "validation.tax_module_blocked", path = "tax.module",
      location = NA_character_, message = text, layer = NA_integer_,
      variant = spec$variant %||% "base", stringsAsFactors = FALSE
    )
    report <- new_vofi_validation(rep_df)
    vofi_abort("engine.validation_failed", n = 1L, details = text,
               .class = "vofi_error_validation", .data = list(report = report))
  }
  params <- spec$tax$params %||% list()
  for (p in names(def$params)) {
    if (is.null(params[[p]]) && inherits(def$params[[p]], "vofi_param") &&
          !is.null(def$params[[p]]$default)) {
      params[p] <- list(def$params[[p]]$default)
    }
  }
  params <- eng_tax_param_values(params, spec, grid)
  mod <- def$constructor(params, spec)
  # 9.3: die Engine liest model$tax$uses_inputs (Default aus der Typdefinition, 5.3)
  if (is.null(mod$uses_inputs)) mod$uses_inputs <- isTRUE(def$uses_inputs)
  list(module = mod, params = params)
}

#' Parameter des Steuermoduls als Basisfallwerte (10.2)
#'
#' Konstanten werden zu ihrem Wert; andere Wertknoten (Bezug, Reihe) zum Basisfallwert als
#' Skalar je Lauf bzw. als Pfad n x (T+1) (n = 1); alles Übrige bleibt unverändert.
#' @noRd
eng_tax_param_values <- function(params, spec, grid = NULL) {
  rc <- NULL
  for (p in names(params)) {
    x <- params[[p]]
    if (!node_is(x)) next
    if (identical(x$kind, "const")) {
      params[p] <- list(x$value)
      next
    }
    if (is.null(grid)) next
    if (is.null(rc)) rc <- res_context(spec, grid, 1L)
    path <- paste0("tax.params.", p)
    v <- tryCatch(res_value(rc, path, "scalar", base = TRUE), vofi_error = function(e) NULL)
    if (is.null(v)) v <- res_value(rc, path, "path", base = TRUE)
    params[p] <- list(v)
  }
  params
}

#' Entscheidungsknoten der Förderzusage erkennen (9.11 Nr. 1, R-71)
#'
#' Knoten: `funding.<f>.approval_timing == "before_start"` (aufgelöster Code, R-86) und
#' `fallback_variant` gesetzt; höchstens einer je Variante.
#' @return `NULL` oder `list(funding_id, key, fallback_variant)`.
#' @noRd
eng_decision_node <- function(spec) {
  hits <- character(0)
  for (f in names(spec$funding %||% list())) {
    fu <- spec$funding[[f]]
    if (identical(fu$approval_timing, "before_start") && utl_is_string(fu$fallback_variant)) {
      hits <- c(hits, f)
    }
  }
  if (length(hits) == 0L) return(NULL)
  if (length(hits) > 1L) {
    vofi_abort("engine.decision_multiple", ids = utl_collapse(hits),
               .class = "vofi_error_validation")
  }
  list(funding_id = hits, key = paste0("funding.", hits, ".approved"),
       fallback_variant = spec$funding[[hits]]$fallback_variant)
}

#' Zweig des Basisfalls: Wert der Zusage nach den Schichten 0–5, 7, 8 (9.11 Nr. 3)
#' @noRd
eng_decision_branch <- function(spec, key) {
  g <- eng_build_grid(spec)
  v <- res_value(res_context(spec, g, 1L), key, "scalar", base = TRUE)
  b <- if (is.null(v)) 1 else v[1L]
  if (!(b %in% c(0, 1))) {
    vofi_abort("engine.decision_not_binary", path = key, value = b,
               .class = "vofi_error_validation")
  }
  as.integer(b)
}

#' Zusagewahrscheinlichkeit des Knotens (Basisfallwert, Default 1)
#' @noRd
eng_decision_probability <- function(spec, f) {
  key <- paste0("funding.", f, ".approval_probability")
  if (is.null(path_get(spec, key))) return(1)
  g <- eng_build_grid(spec)
  v <- res_value(res_context(spec, g, 1L), key, "scalar", base = TRUE)
  if (is.null(v)) 1 else as.double(v[1L])
}

#' Zustand des Modellbaus (Bau der Ausweichvariante läuft, 9.11 Nr. 1)
#' @noRd
eng_build_state <- new.env(parent = emptyenv())

#' Modell der Ausweichvariante (9.1 Stufe 9a, 9.11 Nr. 1, 2)
#' @return `list(funding_id, key, p, fallback_variant, fallback = <vofi_model>, branch)`.
#' @noRd
eng_build_decision <- function(x, node, overrides, scenario_set) {
  if (!inherits(x, "vofi_scenario")) {
    vofi_abort("engine.decision_needs_scenario", funding = node$funding_id,
               .class = "vofi_error_input")
  }
  old <- isTRUE(eng_build_state$fallback)
  eng_build_state$fallback <- TRUE
  on.exit(eng_build_state$fallback <- old, add = TRUE)
  fb <- vofi_build(x, variant = node$fallback_variant,
                   overrides = eng_decision_fallback_overrides(overrides, node$funding_id),
                   scenario_set = scenario_set)
  if (!is.null(fb$spec$funding[[node$funding_id]])) {
    vofi_abort("engine.decision_fallback_has_node", variant = node$fallback_variant,
               funding = node$funding_id, .class = "vofi_error_validation")
  }
  list(funding_id = node$funding_id, key = node$key, p = node$p,
       fallback_variant = node$fallback_variant, fallback = fb, branch = node$branch)
}

#' Overrides für das Modell der Ausweichvariante (9.1 Stufe 9a, 9.11 Nr. 1, 3)
#'
#' Die Ausweichvariante F enthält das Instrument f des Knotens nicht (9.11 Nr. 1). Overrides auf
#' `funding.<f>` (Zusageschlüssel `approved`, `approval_probability`, ...) gehören zum Knoten:
#' Sie wählen im Modell der Variante den Zweig (Schicht 8, 9.11 Nr. 3) und wirken in F nicht;
#' angewendet würden sie f in F als unvollständiges Instrument neu anlegen
#' (Validierungsfehler). Alle übrigen Overrides gelten unverändert auch für F.
#' @param overrides Overrides in Baumform (`scn_overrides_tree()`) oder `NULL`.
#' @param funding_id id des Förderinstruments des Knotens.
#' @return Overrides ohne `funding.<f>` oder `NULL`.
#' @noRd
eng_decision_fallback_overrides <- function(overrides, funding_id) {
  if (is.null(overrides) || !is_map(overrides[["funding"]])) return(overrides)
  fu <- overrides[["funding"]]
  fu <- fu[names(fu) != funding_id]
  if (length(fu) == 0L) {
    overrides <- overrides[names(overrides) != "funding"]
  } else {
    overrides["funding"] <- list(fu)
  }
  if (length(overrides) == 0L) NULL else overrides
}

#' Enthält die Überschusskette Ü3 (loan_prepay bzw. eine Aktion mit Sondertilgungszeilen)?
#' Ohne Ü3 hängen die Instrumentflüsse nicht vom Ausgleich ab; es gilt der Instrument-Cache (9.3)
#' @noRd
eng_has_prepay <- function(model) {
  any(vapply(model$surplus_chain, function(a) "loan_*_prepay" %in% a$rows, logical(1)))
}

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

#' Ausgleichskette aus Aktionsnamen (8.9)
#' @noRd
eng_build_chain <- function(names_chain) {
  out <- lapply(as.character(names_chain), function(a) reg_get("account_action", a))
  stats::setNames(out, as.character(names_chain))
}

#' Kennzahlen nach analysis.kpis, gefiltert nach perspectives (9.1 Stufe 9)
#'
#' `analysis.kpis: default` bedeutet den Kennzahlensatz des Perspektiven-Profils (Spec 01 Teil A
#' 1.5); solange die Profile nicht vorliegen (WS-A), gelten alle registrierten Kennzahlen.
#' Der Filter nach `requires` folgt nach dem Basisfall-Vorlauf
#' (`eng_filter_kpis_requires()`).
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
#' Regel (5.3): `opportunity` immer; `market_value`, wenn eine
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
  cats <- as.character(unlist(lapply(base_flows, function(fl) {
    vapply(fl$rows, function(r) r$category, "")
  }), use.names = FALSE))
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
#'
#' Zusagen mit ihrem Wert nach den Schichten 0–5, 7, 8 (Entscheidungsknoten: 1); Grundlage von
#' `ctx$component_base()` und `ctx$auto()`. Hinweise der Wertauflösung (z. B. Zahlungen nach dem
#' Horizont) werden hier einmal gemeldet.
#' @return `list(flows, n = 1, auto, need0)`.
#' @noRd
eng_base_run <- function(model) {
  env <- eng_engine_env(model, quiet = FALSE)
  ctx <- eng_context(model, draws = NULL, engine_env = env)
  exo <- eng_flows(model, ctx, env)
  auto <- eng_auto_base(model, ctx, exo$ledger)
  list(flows = env$components, n = 1L, auto = auto$auto, need0 = auto$need0)
}
