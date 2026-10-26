# Testhelfer von WS-E2 (Expander und Förderung; Spec 00 4.12, Spec 01 Teil A 4.5, 6.2, Teil B
# 1.6, 3.5, 3.10.2, 4).
#
# Die Szenarien werden als Listen aufgebaut (keine Fixture-Dateien) und mit der Paketbibliothek
# (inst/extdata/library) aufgelöst. Abhängigkeiten zu anderen Paketen: keine zusätzlichen
# Attrappen; die Komponenten der Expander werden mit den Typen von WS-E/WS-F und der Engine von
# WS-D gebaut.

#' Minimales Szenario mit Projekt, Eigenkapital und schlanker Kennzahlliste
e2_scenario <- function(..., perspective = "wu_kommunal", project_type = "sanierung_eh",
                        valuation_date = "2027-01-01", horizon_years = 10L,
                        application_date = NULL, legal_state = "2026-10-25") {
  project <- list(perspective = perspective, project_type = project_type,
                  valuation_date = valuation_date, horizon_years = horizon_years,
                  legal_state = legal_state)
  if (!is.null(application_date)) project$application_date <- application_date
  base <- list(
    schema_version = 1L,
    meta = list(scenario_id = "ws_e2", title = "WS-E2 Test"),
    project = project,
    financing = list(ek = list(type = "equity", amount_eur = 2000000)),
    residual_value = list(method = "zero"),
    analysis = list(kpis = c("terminal_value"))
  )
  extra <- list(...)
  for (nm in names(extra)) {
    base[[nm]] <- if (is.list(base[[nm]]) && is.list(extra[[nm]]) &&
                        !is.null(names(extra[[nm]]))) {
      utils::modifyList(base[[nm]], extra[[nm]])
    } else {
      extra[[nm]]
    }
  }
  base
}

#' Bedingungen eines Ausdrucks sammeln (Warnungen und Hinweise werden unterdrückt)
#' @return Liste `value`, `warnings` (Schlüssel), `messages` (Schlüssel), `texts`.
e2_capture <- function(expr) {
  acc <- new.env(parent = emptyenv())
  acc$w <- character(0)
  acc$m <- character(0)
  acc$t <- character(0)
  value <- withCallingHandlers(
    expr,
    warning = function(w) {
      acc$w <- c(acc$w, w$key %||% conditionMessage(w))
      acc$t <- c(acc$t, conditionMessage(w))
      invokeRestart("muffleWarning")
    },
    message = function(m) {
      acc$m <- c(acc$m, m$key %||% conditionMessage(m))
      acc$t <- c(acc$t, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  list(value = value, warnings = acc$w, messages = acc$m, texts = acc$t)
}

#' Variante auflösen (Meldungen gesammelt)
e2_resolve_full <- function(x, variant = "base") {
  sc <- if (inherits(x, "vofi_scenario")) x else vofi_scenario(x)
  e2_capture(vofi_resolve(sc, variant = variant))
}

#' Variante auflösen (nur das Ergebnis)
e2_resolve <- function(x, variant = "base") e2_resolve_full(x, variant)$value

#' Basisfallwert eines Pfads einer aufgelösten Variante (Skalar)
e2_value <- function(spec, path) {
  rc <- res_context(spec, eng_build_grid(spec), 1L)
  as.double(res_value(rc, path, "scalar", base = TRUE))[1L]
}

#' Basisfallpfad eines Pfads (Länge T+1)
e2_path <- function(spec, path) {
  rc <- res_context(spec, eng_build_grid(spec), 1L)
  as.double(res_value(rc, path, "path", base = TRUE)[1L, ])
}

#' Deterministischer Lauf einer aufgelösten Variante
e2_run <- function(spec) {
  e2_capture(vofi_run(e2_capture(vofi_build(spec))$value))$value
}

#' Zeile `<id>__<row>` des Ledgers eines Laufs (erster Lauf, Länge T+1)
e2_row <- function(res, key) {
  led <- res$ledger
  v <- led$values[[key]]
  if (is.null(v)) return(NULL)
  as.double(v[1L, ])
}

#' Komponente einer Variante als Flussobjekt bauen (Basisfall, ein Lauf)
e2_flows <- function(spec, id) {
  model <- e2_capture(vofi_build(spec))$value
  res <- e2_capture(vofi_run(model))$value
  keys <- res$ledger$rows$key
  hit <- keys[startsWith(keys, paste0(id, "__"))]
  stats::setNames(lapply(hit, function(k) e2_row(res, k)), sub(paste0("^", id, "__"), "", hit))
}

#' Ziehungen mit festen Werten je Lauf (static) für Typtests
e2_draws <- function(n, static = list()) {
  keys <- names(static)
  targets <- data.frame(key = keys, target = keys, kind = rep("static", length(keys)),
                        apply = rep("replace", length(keys)), stringsAsFactors = FALSE)
  new_vofi_draws("mc", n = as.integer(n), sims = seq_len(n), blocks = 1L,
                 block_size = as.integer(n),
                 static = lapply(static, as.double), targets = targets)
}

#' Komponenten eines Typtests bauen (Prüfkit-Spezifikation mit Domänenergänzungen)
#'
#' @param comps benannte Liste roher Komponenten (`type` und Parameter), in Bauordnung.
#' @param n Zahl der Läufe; `static` laufspezifische Werte je Pfad (z. B. `funding.f1.approved`).
#' @param domain benannte Liste roher Domänenblöcke (`measures`, `funding`, ...).
#' @return benannte Liste der `vofi_flows` (Läufe nach `static`).
e2_type_build <- function(comps, n = 1L, static = list(), domain = list(),
                          grid = reg_test_grid("annual"), perspective = "selbstnutzer",
                          household = list(), building = list(), project = list(),
                          domain_spec = list()) {
  spec <- reg_test_spec(grid, perspective = perspective, household = household,
                        building = building, project = project)
  for (blk in names(domain)) spec[[blk]] <- reg_normalize_block(domain[[blk]], blk)
  for (blk in names(domain_spec)) spec[[blk]] <- domain_spec[[blk]]
  defs <- list()
  for (id in names(comps)) {
    raw <- comps[[id]]
    def <- reg_get(if (reg_has("flow", raw$type)) "flow" else "instrument", raw$type)
    comp <- reg_example_component(def, raw, id)
    spec <- path_set(spec, path_join(reg_collection(def, raw), id), comp)
    defs[[id]] <- list(def = def, comp = comp)
  }
  build_all <- function(draws, base) {
    mode <- if (is.null(draws)) "deterministic" else "mc"
    out <- list()
    for (id in names(defs)) {
      d <- defs[[id]]
      deps <- eng_component_deps(d$comp, d$def, names(defs))
      ctx <- eng_context_from_parts(grid, spec, draws = draws, components = out,
                                    components_base = base %||% out, mode = mode,
                                    engine_env = reg_engine_env("flows", deps = deps))
      out[[id]] <- d$def$build(d$comp, ctx)
    }
    out
  }
  base <- build_all(NULL, NULL)
  if (n == 1L && length(static) == 0L) return(base)
  build_all(e2_draws(n, static), base)
}

#' Wärmepumpenmaßnahme (EFH, KfW 458) im Selbstnutzerszenario (Teil B F-2)
e2_kfw458 <- function(taxable_income = 45000, kids = 0L, application_date = "2026-12-01",
                      heating = list(carrier = "oil", installation_year = 2000L),
                      funding_extra = list(), perspective = "selbstnutzer",
                      unit_groups = NULL, cost = 32000) {
  fund <- utils::modifyList(list(from = "funding/kfw_458_heizung_privat", measures = list("wp"),
                                 application_date = application_date,
                                 approval_probability = 1), funding_extra)
  args <- list(
    perspective = perspective, project_type = "heizungstausch",
    application_date = application_date,
    building = list(building_type = "EFH", construction_year = 1975L, n_units = 1L,
                    living_area_m2 = 140, heating_existing = heating,
                    maintenance = list(basis = "none")),
    household = list(taxable_income_avg_eur = taxable_income, n_children_u18 = kids,
                     net_income_month_eur = 5000),
    measures = list(wp = list(measure_type = "heizung_waermepumpe_luft", date = "2027-03-01",
                              completion_date = "2027-10-01", cost_eur = cost,
                              price_index = 0)),
    funding = list(kfw458 = fund),
    residual_value = list(method = "zero")
  )
  if (!is.null(unit_groups)) args$unit_groups <- unit_groups
  do.call(e2_scenario, args)
}

#' Grant-Komponente eines Szenarios nach dem Lauf: Zeile grant_<m>
e2_grant <- function(x, f = "kfw458", m = "wp", variant = "base") {
  spec <- e2_resolve(x, variant)
  res <- e2_run(spec)
  e2_row(res, paste0("f_", f, "_grant__grant_", m))
}
