# Laufkontext ctx (WS-D, Spec 00 Abschnitt 6).
# Alle Felder und Funktionen aus 6.2 als Closures einer gesperrten Umgebung (Klasse vofi_ctx).
# Aufloesung nach 6.3 ueber R/values-resolve.R mit Zwischenspeicher je Kontext (Pfad + Shape +
# Basisfall, 6.1 Nr. 4). Ergebnisse gebauter Komponenten liegen in der privaten Engine-Umgebung
# (engine_env$components) und sind nur fuer deklarierte Abhaengigkeiten lesbar (6.1 Nr. 3;
# engine_env$deps der gerade gebauten Komponente). Basisfallwerte (R-70): param_base(),
# value_base() ohne Ziehungen und Designwerte, component_base() aus dem Basisfall-Vorlauf.
# ctx$auto() liefert den auto-Plan aus model$base (fest, auf n Laeufe gehoben) bzw. den
# topup-Betrag des Chunks aus der Engine-Umgebung (8.7); ctx$rebalance() ist nur in der Stufe
# "kpi" zulaessig und rechnet ueber den Instrument-Cache ohne Ledger-Buchung (9.3, 12.8).

#' Laufkontext eines Modells (6.1 Nr. 1)
#'
#' @param model `vofi_model`.
#' @param draws `NULL` (deterministisch) oder `vofi_draws`.
#' @param engine_env private Engine-Umgebung (`stage`, `components`, `rebalance`, `auto`,
#'   `quiet`) aus `eng_engine_env()`.
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
#' Erzeugt eine gesperrte Umgebung der Klasse `vofi_ctx` mit den Feldern und Funktionen aus
#' Spec 00, Abschnitt 6.2, ohne Modell.
#'
#' Vertrag (vom Prüfkit vorausgesetzt):
#' - `n` = `draws$n`, wenn `draws` gesetzt ist, sonst 1; `mode` wie übergeben.
#' - `components` sind vorab gebaute `vofi_flows` je id (für `ctx$component()`/`ctx$rows()`),
#'   `components_base` die des Basisfalls (für `ctx$component_base()`; im Modus
#'   `"deterministic"` ohne Eintrag gleich `ctx$component()`).
#' - `engine_env` ist `NULL` oder eine Umgebung mit `stage` (`"flows"`, `"balance"`, `"kpi"`),
#'   `rebalance(extra_out)` und `auto(id)`; `ctx$rebalance()` delegiert an
#'   `engine_env$rebalance` (nur bei `stage == "kpi"`, sonst `vofi_error_contract`),
#'   `ctx$auto(id)` an `engine_env$auto`. Enthält `engine_env` ein Element `components`, liest
#'   `ctx$component()` die dort laufend ergänzten Ergebnisse der Engine; `deps` begrenzt den
#'   Zugriff auf deklarierte Abhängigkeiten, `current` benennt die gerade gebaute Komponente,
#'   `quiet = TRUE` unterdrückt die Hinweise der Wertauflösung (Laufkontexte nach dem
#'   Basisfall-Vorlauf, der sie einmal meldet); `ctx$inform()` der Typen bleibt aktiv.
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
  quiet <- is.environment(engine_env) && isTRUE(get0("quiet", envir = engine_env,
                                                     inherits = FALSE))
  once <- new.env(parent = emptyenv())
  rc <- res_context(spec, grid, n, draws, mode, quiet = quiet, once = once)
  rc_base <- res_context(spec, grid, n, NULL, "deterministic", quiet = quiet, once = once)
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
  # Leistung (9.10): zeilengleiche Eingaben (alle Laeufe gleich) einmal mit einer Zeile rechnen
  # und das Ergebnis auf n Zeilen heben; die Rasterfunktionen rechnen zeilenweise, das Ergebnis
  # ist daher identisch zur Rechnung mit n Zeilen. keep_attr = TRUE: die Funktion uebernimmt
  # Attribute einer Matrix-Eingabe (Raten), dann nur fuer Matrizen ohne weitere Attribute.
  by_rows <- function(x, fun, keep_attr = FALSE) {
    if (keep_attr && is.matrix(x) && !identical(names(attributes(x)), "dim")) return(fun(x))
    one <- eng_uniform_rows(x, n)
    if (is.null(one)) return(fun(x))
    eng_expand_rows(fun(one), n) %||% fun(x)
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
  # Parameterschema eines (Unter-)Parameters der Komponente (map-Felder ueber fields)
  type_param <- function(s, name) {
    def <- scn_type_def(s[["type"]], eng_collection(spec, s))
    if (is.null(def)) return(NULL)
    segs <- path_split(name)
    pp <- def$params[[segs[1L]]]
    for (sg in segs[-1L]) pp <- if (inherits(pp, "vofi_param")) pp$fields[[sg]] else NULL
    if (inherits(pp, "vofi_param")) pp else NULL
  }
  # Knoten inkl. Default (6.2): Schicht 0 setzt nur Parameter der obersten Ebene; Felder einer
  # fehlenden Map erhalten hier ihren Feld-Default (z. B. fees.processing_fee_share = 0)
  param_node <- function(s, name) {
    v <- path_get(s, name)
    if (!is.null(v)) return(v)
    pp <- type_param(s, name)
    if (is.null(pp) || is.null(pp$default)) return(NULL)
    node_normalize(pp$default, pp, param_path(s, name))
  }
  # rasterabhaengige Termin-Defaults (7.12, 8.2): vofi_param("timing", grid_default = ...)
  grid_date <- function(token) {
    switch(token, valuation_date = grid$valuation_date, end_date = grid$end_date,
           completion = grid$completion_date, NULL)
  }
  raw_setting <- function(s, name) {
    v <- path_get(s, name)
    if (is.null(v)) v <- path_get(spec, param_path(s, name))
    if (!is.null(v)) return(v)
    pp <- type_param(s, name)
    if (is.null(pp)) return(NULL)
    if (!is.null(pp$default)) return(node_normalize(pp$default, pp, param_path(s, name)))
    tok <- pp$extra$grid_default
    if (utl_is_string(tok)) return(structure(tok, class = "vofi_grid_token"))
    NULL
  }
  where <- function() {
    if (is.environment(engine_env)) {
      get0("current", envir = engine_env, inherits = FALSE) %||% ""
    } else {
      ""
    }
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
    v <- raw_setting(spec, name)
    # timing -> Date (6.2): Token completion bzw. rasterabhaengiger Default als Datum
    if (inherits(v, "vofi_grid_token")) return(grid_date(unclass(v)))
    if (identical(v, "completion") &&
          identical(type_param(spec, name)$kind %||% "timing", "timing")) {
      return(grid$completion_date)
    }
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
    # im deterministischen Modus (auch im Basisfall-Vorlauf selbst) sind Basisfall und Lauf
    # dieselbe Komponente (6.3)
    if (is.null(fl) && identical(mode, "deterministic")) fl <- comps()[[id]]
    if (is.null(fl)) {
      vofi_abort("engine.component_unknown", id = id, where = where(),
                 .class = "vofi_error_contract")
    }
    eng_lift_flows(fl, n)
  }
  ctx$market <- function(name) ctx$value(paste0("market.", name), "path")
  # Indizes und Verschiebungen: mit einer Zeile (bzw. wenigen Werten) ueber Laeufe hinweg im
  # Zwischenspeicher (reine Rasterrechnungen, eng_memo())
  ctx$index <- function(g, base_date = NULL) {
    by_rows(lift(g), function(x) {
      eng_grid_memo("grid_index", list(grid, x, base_date), NROW(x) == 1L,
                    function() grid_index(grid, x, base_date))
    })
  }
  ctx$index_year <- function(g, base_date = NULL) {
    by_rows(lift(g), function(x) {
      eng_grid_memo("grid_index_year", list(grid, x, base_date), NROW(x) == 1L,
                    function() grid_index_year(grid, x, base_date))
    })
  }
  ctx$timing <- function(spec, name) {
    v <- raw_setting(spec, name)
    if (is.null(v)) return(NULL)
    if (inherits(v, "vofi_grid_token")) v <- unclass(v)
    if (identical(v, "completion")) {
      shift <- ctx$value("project.construction_delay_months", "scalar") %||% rep(0, n)
      return(list(date = grid$completion_date, shift = shift))
    }
    if (utl_is_string(v) && !is.null(grid_date(v))) v <- grid_date(v)
    list(date = utl_as_date(v, name), shift = rep(0, n))
  }
  # Verschiebungen: je verschiedenem Wert einmal gerechnet (zeilenweise Rasterfunktionen, 9.10)
  ctx$shift_period <- function(date, months) {
    eng_by_unique(rep_len(months, n), function(m) {
      eng_grid_memo("grid_shift_period", list(grid, date, m), length(m) <= 4L,
                    function() grid_shift_period(grid, date, m))
    })
  }
  ctx$shift_overlap <- function(from, months, to = NULL) {
    eng_by_unique(rep_len(months, n), function(m) {
      eng_grid_memo("grid_shift_overlap", list(grid, from, m, to), length(m) <= 4L,
                    function() grid_shift_overlap(grid, from, m, to))
    })
  }
  ctx$shift_months <- function(from, months, to = NULL) {
    eng_by_unique(rep_len(months, n), function(m) {
      eng_grid_memo("grid_shift_months", list(grid, from, m, to), length(m) <= 4L,
                    function() grid_shift_months(grid, from, m, to))
    })
  }
  ctx$rebalance <- function(extra_out = NULL) {
    if (!is.environment(engine_env) || !identical(engine_env$stage, "kpi")) {
      vofi_abort("engine.rebalance_stage", .class = "vofi_error_contract")
    }
    engine_env$rebalance(extra_out)
  }
  # Nullmatrix und Periodenlaengen je Kontext einmal (Kopie erst bei Aenderung durch den Aufrufer)
  ctx$zeros <- function() {
    z <- get0("zeros", envir = cache, inherits = FALSE)
    if (is.null(z)) {
      z <- grid_zeros(grid, n)
      assign("zeros", z, envir = cache)
    }
    z
  }
  ctx$by_sim <- function(x) grid_by_sim(grid, x, n)
  ctx$by_period <- function(x) {
    if (!identical(x, grid$delta)) return(grid_by_period(grid, x, n))
    d <- get0("by_period_delta", envir = cache, inherits = FALSE)
    if (is.null(d)) {
      d <- grid_by_period(grid, x, n)
      assign("by_period_delta", d, envir = cache)
    }
    d
  }
  ctx$rate_eff <- function(r_pa) {
    by_rows(lift(r_pa), function(x) grid_rate_eff(grid, x), keep_attr = TRUE)
  }
  ctx$rate_nom <- function(r_pa) {
    by_rows(lift(r_pa), function(x) grid_rate_nom(grid, x), keep_attr = TRUE)
  }
  ctx$per_period <- function(x_pa) {
    by_rows(lift(x_pa), function(x) grid_per_period(grid, x), keep_attr = TRUE)
  }
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
      # Tag der Zeile, sonst der Komponente (dieselbe Regel wie im Ledger, eng_flow_row_meta())
      comp_mid <- (spec$components[[cid]] %||% spec$financing[[cid]])[["measure_id"]]
      for (r in fl$rows) {
        if (hit(r$section, section) && hit(r$category, category) &&
              hit(r$tax_category, tax_category) &&
              hit(r$measure_id %||% comp_mid, measure_id) && hit(r$key, local_row)) {
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
    a <- engine_env$auto(id)
    # auto-Plan des Basisfalls (Laenge 1 bzw. T+1) auf n Laeufe heben (8.7); andere Laengen
    # und nicht endliche Werte sind Vertragsfehler (kein stilles Recycling, N1)
    src <- paste0("ctx$auto('", id, "')")
    if (is.null(a$commitment)) {
      vofi_abort("engine.return_length", what = "commitment", source = src, n = n, actual = 0L,
                 .class = "vofi_error_contract",
                 .data = list(invariant = "N1", source = src, row = "commitment"))
    }
    a$commitment <- eng_num(a$commitment, n, "commitment", src)
    if (!is.matrix(a$draws)) a$draws <- grid_by_period(grid, a$draws, n)
    if (ncol(a$draws) != grid$T + 1L || !(nrow(a$draws) %in% c(1L, n))) {
      vofi_abort("core.contract.length", what = paste0(src, "$draws"), expected = n,
                 actual = nrow(a$draws), .class = "vofi_error_contract")
    }
    if (nrow(a$draws) == 1L && n > 1L) a$draws <- a$draws[rep(1L, n), , drop = FALSE]
    eng_check_finite(list(commitment = a$commitment, draws = a$draws), src)
    a
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
  # Reformversion vor der Version ohne Reform (4.10), sonst die mit dem spaetesten valid_from
  vf <- vapply(ok, function(d) as.numeric(d$valid_from), double(1))
  rf <- vapply(ok, function(d) !is.null(d$reform), logical(1))
  ok[[order(rf, vf, method = "radix")[length(ok)]]]$fun
}

#' Erste Zeile einer zeilengleichen Eingabe (Leistung 9.10)
#'
#' Sind alle n Zeilen einer double-Matrix n x k (bzw. alle Elemente eines double-n-Vektors)
#' gleich, liefert die Funktion die erste Zeile als 1 x k-Matrix (bzw. das erste Element) mit den
#' Attributen `annual_before` (erste Zeile) und `path`, sonst `NULL`. Nicht endliche Werte,
#' Zeilen- oder Spaltennamen, ein nicht zeilengleiches oder anders geformtes `annual_before` und
#' n < 2 ergeben `NULL` (die Rasterfunktion rechnet dann wie bisher mit allen Zeilen).
#' @param x Matrix bzw. Vektor.
#' @param n Zahl der Läufe.
#' @noRd
eng_uniform_rows <- function(x, n) {
  if (n < 2L || !is.double(x)) return(NULL)
  if (is.matrix(x)) {
    if (nrow(x) != n || !is.null(dimnames(x)) || !eng_rows_equal(x)) return(NULL)
    one <- x[1L, , drop = FALSE]
  } else {
    if (length(x) != n || !isTRUE(x[[1L]] == x[[n]]) || !isTRUE(all(x == x[[1L]]))) {
      return(NULL)
    }
    one <- x[[1L]]
  }
  ab <- attr(x, "annual_before")
  if (!is.null(ab)) {
    if (!is.matrix(ab) || !is.double(ab)) return(NULL)
    if (nrow(ab) == n) {
      if (!eng_rows_equal(ab)) return(NULL)
      ab <- ab[1L, , drop = FALSE]
    } else if (nrow(ab) != 1L) {
      return(NULL)
    }
    attr(one, "annual_before") <- ab
  }
  if (!is.null(attr(x, "path"))) attr(one, "path") <- attr(x, "path")
  one
}

#' Sind alle Zeilen einer Matrix gleich (`==`, nicht endliche Werte: `FALSE`)?
#'
#' Prüft zuerst die erste gegen die letzte Zeile (schneller Ausschluss), dann alle Zeilen.
#' @param x numerische Matrix mit mindestens einer Zeile.
#' @noRd
eng_rows_equal <- function(x) {
  n <- nrow(x)
  if (n < 2L) return(TRUE)
  first <- x[1L, ]
  if (!isTRUE(all(first == x[n, ]))) return(FALSE)
  # konstante Matrix: ohne Hilfsmatrix (zwei Durchlaeufe)
  if (isTRUE(min(x) == max(x))) return(TRUE)
  isTRUE(all(x == rep(first, each = n)))
}

#' Ergebnis einer Zeile auf n Zeilen heben (Leistung 9.10, zu `eng_uniform_rows()`)
#'
#' Hat das Ergebnis nicht die Form 1 x k ohne weitere Attribute, ist der Weg über eine Zeile
#' nicht anwendbar (`NULL`; der Aufrufer rechnet dann mit allen Zeilen).
#' @param r Ergebnis für eine Zeile.
#' @noRd
eng_expand_rows <- function(r, n) {
  if (!is.matrix(r) || nrow(r) != 1L || !identical(names(attributes(r)), "dim")) return(NULL)
  r[rep.int(1L, n), , drop = FALSE]
}

#' Zeilenweise Funktion je verschiedenem Wert einmal auswerten (Leistung 9.10)
#'
#' `fun(m)` liefert je Element von `m` ein Element bzw. eine Matrixzeile (zeilenweise
#' Rasterfunktionen wie `grid_shift_period()`); das Ergebnis ist identisch zu `fun(m)`.
#' @param m n-Vektor.
#' @param fun Funktion.
#' @noRd
eng_by_unique <- function(m, fun) {
  if (length(m) < 2L) return(fun(m))
  u <- unique(m)
  if (length(u) == length(m)) return(fun(m))
  r <- fun(u)
  i <- match(m, u)
  if (is.matrix(r)) r[i, , drop = FALSE] else r[i]
}
