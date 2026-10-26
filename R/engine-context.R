# Laufkontext ctx (WS-D, Spec 00 Abschnitt 6).
# Phase-0-Minimalfassung, Eigentuemer: WS-D. Umgesetzt: alle Felder und Funktionen aus 6.2 als
# Closures einer gesperrten Umgebung (Klasse vofi_ctx), Aufloesung nach 6.3 ueber
# R/values-resolve.R, Zwischenspeicher je Kontext (Pfad + Shape + Basisfall), Zugriff auf
# gebaute Komponenten ueber die private Engine-Umgebung (engine_env$components).
# Phase-0-Nacharbeit (17.5.4 P0-07) umgesetzt: ctx$rows() mit measure_id, local_row, id als Vektor.
# Nur deklarierte Abhaengigkeiten (6.1 Nr. 3) fuer component(), component_base() und rows()
# (ohne id: Schnitt mit engine_env$deps).
# Offen fuer WS-D: Designwerte (mode "design"), ctx$legal() mit Bibliothekseintraegen (WS-A/WS-L).

#' Laufkontext eines Modells (6.1 Nr. 1)
#'
#' Phase-0-Minimalfassung, Eigentümer: WS-D.
#' @param model `vofi_model`.
#' @param draws `NULL` (deterministisch) oder `vofi_draws`.
#' @param engine_env private Engine-Umgebung (`stage`, `components`, `rebalance`, `auto`).
#' @return `vofi_ctx`.
#' @noRd
eng_context <- function(model, draws = NULL, engine_env = NULL) {
  mode <- if (is.null(draws)) "deterministic" else draws$mode
  eng_context_from_parts(model$grid, model$spec, draws = draws, components = list(),
                         components_base = model$base$flows %||% list(), mode = mode,
                         engine_env = engine_env)
}

#' Laufkontext aus Einzelteilen (Prüfkit, Testhelfer; Spec 00 Abschnitt 6.1)
#'
#' Phase-0-Minimalfassung, Eigentümer: WS-D. Erzeugt eine gesperrte Umgebung der Klasse
#' `vofi_ctx` mit den Feldern und Funktionen aus Spec 00, Abschnitt 6.2, ohne Modell.
#'
#' Vertrag (vom Prüfkit vorausgesetzt):
#' - `n` = `draws$n`, wenn `draws` gesetzt ist, sonst 1; `mode` wie übergeben.
#' - `components` sind vorab gebaute `vofi_flows` je id (für `ctx$component()`/`ctx$rows()`),
#'   `components_base` die des Basisfalls (für `ctx$component_base()`).
#' - `engine_env` ist `NULL` oder eine Umgebung mit `stage` (`"flows"`, `"balance"`, `"kpi"`),
#'   `rebalance(extra_out)` und `auto(id)`; `ctx$rebalance()` delegiert an
#'   `engine_env$rebalance` (nur bei `stage == "kpi"`, sonst `vofi_error_contract`),
#'   `ctx$auto(id)` an `engine_env$auto`. Enthält `engine_env` ein Element `components`, liest
#'   `ctx$component()` die dort laufend ergänzten Ergebnisse der Engine.
#' - `ctx$assets()`/`ctx$measures()` enthalten mindestens `spec$registers`.
#' @param grid `vofi_grid`.
#' @param spec `vofi_spec`.
#' @param draws `NULL` oder `vofi_draws`.
#' @param components benannte Liste von `vofi_flows` (Abhängigkeiten).
#' @param components_base `vofi_flows` des Basisfalls.
#' @param mode `"deterministic"`, `"mc"` oder `"design"`.
#' @param engine_env private Engine-Umgebung bzw. Attrappe.
#' @return gesperrte Umgebung der Klasse `vofi_ctx`.
#' @noRd
eng_context_from_parts <- function(grid, spec, draws = NULL, components = list(),
                                   components_base = components,
                                   mode = c("deterministic", "mc", "design"),
                                   engine_env = NULL) {
  mode <- utl_match_arg(mode, c("deterministic", "mc", "design"), "mode")
  n <- if (is.null(draws)) 1L else as.integer(draws$n)
  rc <- res_context(spec, grid, n, draws, mode)
  rc_base <- res_context(spec, grid, n, NULL, "deterministic")
  cache <- new.env(parent = emptyenv())
  priv <- new.env(parent = emptyenv())
  priv$components <- components
  comps <- function() {
    if (is.environment(engine_env) && exists("components", envir = engine_env,
                                             inherits = FALSE)) {
      engine_env$components
    } else {
      priv$components
    }
  }
  lift <- function(x) {
    if (is.matrix(x)) return(x)
    at <- attributes(x)
    y <- rep_len(as.double(x), n)
    for (a in c("annual_before", "path")) if (!is.null(at[[a]])) attr(y, a) <- at[[a]]
    y
  }
  value_at <- function(path, shape, base, node = NULL) {
    key <- paste(if (base) "b" else "v", shape, path, sep = "|")
    hit <- get0(key, envir = cache, inherits = FALSE)
    if (!is.null(hit)) return(hit)
    v <- res_value(if (base) rc_base else rc, path, shape, base = base, node = node)
    if (!is.null(v)) assign(key, v, envir = cache)
    v
  }
  param_path <- function(s, name) path_join(eng_collection(spec, s), s[["id"]], name)
  param_node <- function(s, name) path_get(s, name)
  where <- function() {
    if (is.environment(engine_env)) get0("current", envir = engine_env, inherits = FALSE) %||%
      "" else ""
  }
  # deklarierte Abhaengigkeiten der gerade gebauten Komponente (6.1 Nr. 3); NULL = keine Pruefung
  # (Kennzahlen, Ausgleich, Testhelfer ohne Engine-Attrappe)
  deps_of <- function() {
    if (is.environment(engine_env)) get0("deps", envir = engine_env, inherits = FALSE) else NULL
  }
  check_dep <- function(id) {
    deps <- deps_of()
    if (!is.null(deps) && !(id %in% deps)) {
      vofi_abort("engine.component_undeclared", id = id, where = where(),
                 .class = "vofi_error_contract")
    }
    invisible(TRUE)
  }

  ctx <- new.env(parent = emptyenv())
  ctx$n <- n
  ctx$T <- grid$T
  ctx$grid <- grid
  ctx$mode <- mode
  ctx$sims <- if (is.null(draws)) 1L else as.integer(draws$sims)
  ctx$blocks <- if (is.null(draws) || length(draws$blocks) == 0L) 1L else
    as.integer(draws$blocks)
  ctx$spec <- spec
  ctx$project <- spec$project
  ctx$building <- spec$building
  ctx$household <- spec$household
  ctx$perspective <- spec$project$perspective
  ctx$tax_regime <- spec$project$tax_regime
  ctx$legal_state <- spec$project$legal_state
  ctx$pending_reforms <- spec$project$pending_reforms %||% character(0)
  ctx$tol <- vofi_tol

  ctx$param <- function(spec, name, shape = c("scalar", "path")) {
    shape <- utl_match_arg(shape, c("scalar", "path"), "shape")
    value_at(param_path(spec, name), shape, FALSE, param_node(spec, name))
  }
  ctx$param_base <- function(spec, name, shape = c("scalar", "path")) {
    shape <- utl_match_arg(shape, c("scalar", "path"), "shape")
    value_at(param_path(spec, name), shape, TRUE, param_node(spec, name))
  }
  ctx$setting <- function(spec, name) {
    v <- path_get(spec, name)
    if (is.null(v)) v <- path_get(ctx$spec, param_path(spec, name))
    v
  }
  ctx$value <- function(path, shape = c("scalar", "path")) {
    value_at(path, utl_match_arg(shape, c("scalar", "path"), "shape"), FALSE)
  }
  ctx$value_base <- function(path, shape = c("scalar", "path")) {
    value_at(path, utl_match_arg(shape, c("scalar", "path"), "shape"), TRUE)
  }
  ctx$component_base <- function(id) {
    check_dep(id)
    fl <- components_base[[id]]
    if (is.null(fl)) {
      vofi_abort("engine.component_unknown", id = id, where = where(),
                 .class = "vofi_error_contract")
    }
    eng_lift_flows(fl, n)
  }
  ctx$market <- function(name) ctx$value(paste0("market.", name), "path")
  ctx$index <- function(g, base_date = NULL) grid_index(grid, lift(g), base_date)
  ctx$index_year <- function(g, base_date = NULL) grid_index_year(grid, lift(g), base_date)
  ctx$timing <- function(spec, name) {
    v <- ctx$setting(spec, name)
    if (is.null(v)) return(NULL)
    if (identical(v, "completion")) {
      shift <- ctx$value("project.construction_delay_months", "scalar") %||% rep(0, n)
      return(list(date = grid$completion_date, shift = shift))
    }
    list(date = utl_as_date(v, name), shift = rep(0, n))
  }
  ctx$shift_period <- function(date, months) grid_shift_period(grid, date, rep_len(months, n))
  ctx$shift_overlap <- function(from, months, to = NULL) {
    grid_shift_overlap(grid, from, rep_len(months, n), to)
  }
  ctx$shift_months <- function(from, months, to = NULL) {
    grid_shift_months(grid, from, rep_len(months, n), to)
  }
  ctx$rebalance <- function(extra_out = NULL) {
    if (!is.environment(engine_env) || !identical(engine_env$stage, "kpi")) {
      vofi_abort("engine.rebalance_stage", .class = "vofi_error_contract")
    }
    engine_env$rebalance(extra_out)
  }
  ctx$zeros <- function() grid_zeros(grid, n)
  ctx$by_sim <- function(x) grid_by_sim(grid, x, n)
  ctx$by_period <- function(x) grid_by_period(grid, x, n)
  ctx$rate_eff <- function(r_pa) grid_rate_eff(grid, lift(r_pa))
  ctx$rate_nom <- function(r_pa) grid_rate_nom(grid, lift(r_pa))
  ctx$per_period <- function(x_pa) grid_per_period(grid, lift(x_pa))
  ctx$period_of <- function(date) grid_period_of(grid, date)
  ctx$period_of_year <- function(year) grid_period_of_year(grid, year)
  ctx$overlap <- function(from = NULL, to = NULL) grid_overlap(grid, from, to)
  ctx$to_periods <- function(x_month) grid_to_periods(grid, x_month)
  ctx$to_months <- function(x, how = c("repeat", "spread")) grid_to_months(grid, x, how)
  ctx$component <- function(id) {
    check_dep(id)
    fl <- comps()[[id]]
    if (is.null(fl)) {
      vofi_abort("engine.component_unknown", id = id, where = where(),
                 .class = "vofi_error_contract")
    }
    fl
  }
  ctx$rows <- function(id = NULL, section = NULL, category = NULL, tax_category = NULL,
                       measure_id = NULL, local_row = NULL) {
    cs <- comps()
    # ohne id: nur deklarierte Abhaengigkeiten (6.1 Nr. 3), mit id: Pruefung in ctx$component()
    ids <- if (is.null(id)) {
      deps <- deps_of()
      if (is.null(deps)) names(cs) else intersect(names(cs), deps)
    } else {
      id
    }
    hit <- function(v, allowed) is.null(allowed) || (length(v) == 1L && v %in% allowed)
    out <- list()
    for (cid in ids) {
      fl <- if (is.null(id)) cs[[cid]] else ctx$component(cid)
      for (r in fl$rows) {
        if (hit(r$section, section) && hit(r$category, category) &&
            hit(r$tax_category, tax_category) && hit(r$measure_id, measure_id) &&
            hit(r$key, local_row)) {
          out[[paste0(cid, "__", r$key)]] <- r$values
        }
      }
    }
    out
  }
  ctx$auto <- function(id) {
    if (!is.environment(engine_env) || !is.function(engine_env$auto)) {
      vofi_abort("engine.auto_unavailable", id = id, .class = "vofi_error_contract")
    }
    engine_env$auto(id)
  }
  ctx$rule <- function(name) eng_rule_for(name, spec)
  ctx$legal <- function(topic) spec$legal[[topic]]$values
  ctx$draw <- function(key) {
    if (is.null(draws) || identical(mode, "deterministic")) return(NULL)
    draws$static[[key]] %||% draws$paths[[key]] %||% draws$decision[[key]]
  }
  ctx$assets <- function() {
    reg <- spec$registers$assets %||% list()
    extra <- unlist(lapply(comps(), function(f) f$assets), recursive = FALSE)
    utl_register_list(c(reg, extra), "vofi_asset", "asset_id")
  }
  ctx$measures <- function() {
    reg <- spec$registers$measures %||% list()
    extra <- unlist(lapply(comps(), function(f) f$measures), recursive = FALSE)
    utl_register_list(c(reg, extra), "vofi_measure", "measure_id")
  }
  ctx$lbl <- function(key, ...) lbl(key, ...)
  ctx$abort <- function(key, ..., .class = "vofi_error_contract") {
    vofi_abort(key, ..., where = where(), .class = .class)
  }
  ctx$warn <- function(key, ..., .class = "vofi_warning_engine") {
    vofi_warn(key, ..., where = where(), .class = .class)
  }
  ctx$inform <- function(key, ...) vofi_inform(key, ..., where = where())
  class(ctx) <- "vofi_ctx"
  lockEnvironment(ctx, bindings = TRUE)
  ctx
}

#' Sammlung einer Komponente in der Spezifikation (components bzw. financing)
#' @noRd
eng_collection <- function(spec, comp) {
  id <- comp[["id"]]
  if (!is.null(id) && id %in% names(spec$financing)) "financing" else "components"
}

#' Zeilen einer Komponente auf n Läufe heben (Basisfall, n = 1)
#' @noRd
eng_lift_flows <- function(fl, n) {
  if (length(fl$rows) == 0L || nrow(fl$rows[[1L]]$values) == n) return(fl)
  fl$rows <- lapply(fl$rows, function(r) {
    r$values <- r$values[rep(1L, n), , drop = FALSE]
    r
  })
  fl$aux <- lapply(fl$aux, function(a) a[rep(1L, n), , drop = FALSE])
  fl
}

#' Regelversion zum Rechtsstand wählen (4.10)
#' @noRd
eng_rule_for <- function(name, spec) {
  versions <- reg_rules(name)
  ls <- spec$project$legal_state %||% spec$project$valuation_date
  reforms <- spec$project$pending_reforms %||% character(0)
  ok <- Filter(function(d) {
    (is.null(d$reform) || d$reform %in% reforms) && d$valid_from <= ls &&
      (is.null(d$valid_to) || ls < d$valid_to)
  }, versions)
  if (length(ok) == 0L) {
    vofi_abort("engine.rule_unknown", rule = name, date = ls, .class = "vofi_error_registry")
  }
  ok[[length(ok)]]$fun
}
