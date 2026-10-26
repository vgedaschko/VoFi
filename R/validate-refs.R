# Validierung Ebene 3: Querbezuege (WS-B; Spec 00 Abschnitte 4.4, 4.5 Regeln 2-5, 4.11, 8.7,
# 9.6, 9.11, 11.2, 11.6, 11.7, 12.3a; Spec 01 Teil A 3.5, 4.9, 5.3; Teil B 4.9; Teil C 1.3-1.11).
#
# Bezuege und Ausdruecke werden nur in gelesenen Knoten geprueft (R-115): in den Parametern der
# Komponenten und Instrumente (Anschlusszinsen nur bei einer Zinsanpassung im Horizont), in den
# Domaenenbloecken ausser Teilbaeumen mit `enabled: false` und den Untermaps nicht gewaehlter
# Restwertmethoden, und transitiv in allen Blaettern, auf die diese verweisen. Dazu kommen
# Zyklen (Bezuege, Komponenten, linked_ar1), die Elementregel 4, Mengenbezuege, auto/topup,
# Overlay-Ziele und Korrelationen, Entscheidungsknoten sowie die Vergleiche ueber Varianten
# (Referenzvariante R-68, Bestandswert und Bestandsdarlehen, Ausweichvarianten, Szenario-Sets).

#' Ebene 3 einer Spezifikation
#' @param vc Prüfkontext.
#' @noRd
val_refs <- function(vc) {
  val_value_refs(vc)
  val_component_deps(vc)
  val_auto(vc)
  val_decision_nodes(vc)
  val_overlay_refs(vc)
  val_correlations(vc)
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Basisfallwerte (n = 1, ohne Ziehungen; Spec 00 6.3)
# ---------------------------------------------------------------------------------------------

#' Basisfallwert eines Pfads
#' @param vc Prüfkontext.
#' @param path Pfad.
#' @param shape `"scalar"` oder `"path"` (Vektor der Länge T+1).
#' @return double oder `NULL`, wenn sich der Wert nicht bestimmen lässt.
#' @noRd
val_base <- function(vc, path, shape = c("path", "scalar")) {
  shape <- utl_match_arg(shape, c("path", "scalar"), "shape")
  key <- paste(shape, path)
  if (exists(key, envir = vc$base_cache, inherits = FALSE)) {
    return(get(key, envir = vc$base_cache, inherits = FALSE))
  }
  out <- NULL
  if (!is.null(vc$grid) && utl_is_string(path)) {
    rc <- res_context(vc$spec, vc$grid, 1L)
    out <- tryCatch(suppressMessages(suppressWarnings(res_value(rc, path, shape, base = TRUE))),
                    error = function(e) NULL)
    if (is.matrix(out)) out <- as.double(out[1L, ])
    if (!is.null(out)) out <- as.double(out)
  }
  assign(key, out, envir = vc$base_cache)
  out
}

#' Basisfallwert als Skalar (zeitabhängig: Wert der ersten Periode nach t = 0)
#' @noRd
val_base_scalar <- function(vc, path) {
  v <- val_base(vc, path, "scalar")
  if (!is.null(v)) return(v[1L])
  v <- val_base(vc, path, "path")
  if (is.null(v) || length(v) == 0L) return(NULL)
  v[min(2L, length(v))]
}

# ---------------------------------------------------------------------------------------------
# Bezüge und Ausdrücke (4.5 Regeln 2-5, R-115)
# ---------------------------------------------------------------------------------------------

#' Zulässige Zielblöcke von Bezügen und Pfadsymbolen (4.5 Regel 2)
#' @noRd
val_ref_blocks <- function() {
  c("project", "building", "household", "unit_groups", "measures", "energy", "funding",
    "components", "financing", "market", "residual_value", "shared")
}

#' Ist ein Wert ein Knoten bzw. eine Wertform (Roh- oder Knotenform)?
#' @noRd
val_is_value <- function(x) {
  if (node_is(x)) return(TRUE)
  form <- utl_value_form_kind(x)
  !is.na(form) && !identical(form, "from")
}

#' Wert als Knoten (Rohformen der Sammlungen werden normalisiert; `NULL`, wenn keiner)
#' @noRd
val_as_node <- function(x, path) {
  if (node_is(x)) return(x)
  if (is.numeric(x) && !is.list(x)) {
    return(if (length(x) == 1L) node_const(x) else list(kind = "series_t", values = as.double(x)))
  }
  if (!val_is_value(x)) return(NULL)
  tryCatch(suppressWarnings(node_value(x, path)), error = function(e) NULL)
}

#' Restwertmethoden, die ohne `building` gelesen werden (Spec 01 Teil A 6.1, 6.2 Nr. 5)
#' @noRd
val_rv_methods_without_building <- function() c("user_value", "market_growth", "exit_yield")

#' Gelesene Wurzelknoten (R-115)
#'
#' Ohne `building` liest der Restwert nur die Methoden nach
#' `val_rv_methods_without_building()`; die Untermaps der übrigen Methoden (z. B.
#' `residual_value.income_value.land_value_eur: {ref: building.land_value_eur}` aus
#' `global.yaml`) bleiben ungeprüft (Spec 00 4.5 Regel 2; Gerüst, Orakel, `grob_lehrbuch_a`).
#' @return Zeichenvektor der Blattpfade mit Wertknoten.
#' @noRd
val_ref_roots <- function(vc) {
  spec <- vc$spec
  out <- character(0)
  collect <- function(x, path) {
    if (is.null(x)) return(invisible(NULL))
    if (val_is_value(x)) {
      out <<- c(out, path)
      return(invisible(NULL))
    }
    if (!is_map(x) || length(x) == 0L) return(invisible(NULL))
    if (utl_has_name(x, "enabled") && identical(val_flag(x$enabled), FALSE)) {
      return(invisible(NULL))
    }
    for (nm in names(x)) collect(x[[nm]], path_join(path, nm))
    invisible(NULL)
  }
  for (b in c("project", "building", "household", "unit_groups", "measures", "energy",
              "funding", "accounts")) {
    collect(spec[[b]], b)
  }
  rv <- spec$residual_value
  if (is_map(rv)) {
    method <- val_str(rv$method) %||% "zero"
    methods <- val_codes("vocab:residual_method") %||% character(0)
    has_building <- is_map(spec$building) && length(spec$building) > 0L
    for (nm in names(rv)) {
      if (nm %in% methods && !identical(nm, method)) next
      if (nm %in% methods && !has_building && !(nm %in% val_rv_methods_without_building())) next
      collect(rv[[nm]], path_join("residual_value", nm))
    }
  }
  for (coll in c("components", "financing")) {
    for (id in names(spec[[coll]])) {
      comp <- spec[[coll]][[id]]
      if (!is_map(comp)) next
      def <- scn_type_def(comp$type, coll)
      skip <- character(0)
      if (identical(def$kind, "instrument") && !val_loan_resets(vc, comp)) {
        skip <- c("followup_rate_pa", "followup_spread_pa", "followup_repayment_pa")
      }
      for (p in setdiff(names(comp), skip)) collect(comp[[p]], path_join(coll, id, p))
    }
  }
  unique(out)
}

#' Hat ein Kredit eine Zinsanpassung im Horizont? (Anschlusszins wird gelesen, R-115)
#' @noRd
val_loan_resets <- function(vc, comp) {
  fy <- val_num(comp$fixed_years)
  if (length(fy) != 1L || !is.finite(fy)) return(FALSE)
  start <- val_as_date(comp[["start"]], year = TRUE) %||% vc$vd
  if (is.null(start) || is.null(vc$end_date)) return(TRUE)
  reset <- grid_add_months(start, as.integer(round(12 * fy)))
  ty <- val_num(comp$term_years)
  if (length(ty) == 1L && is.finite(ty) &&
        reset >= grid_add_months(start, as.integer(round(12 * ty)))) {
    return(FALSE)
  }
  reset < vc$end_date
}

#' Ziele eines Knotens bzw. einer Rohwertform
#' @return Liste von `list(target, kind ("ref"/"expr"), element, text)`; Ausdrucksfehler als
#'   `list(error = <Bedingung>)`.
#' @noRd
val_node_targets <- function(x, element = FALSE) {
  out <- list()
  addt <- function(target, kind, text = NULL, el = element) {
    out[[length(out) + 1L]] <<- list(target = target, kind = kind, element = el, text = text)
  }
  if (is.null(x)) return(out)
  if (!node_is(x)) {
    if (is_map(x) && utl_has_name(x, "ref") && utl_is_string(x$ref)) {
      addt(x$ref, "ref")
    } else if (is_map(x) && utl_has_name(x, "expr")) {
      ast <- tryCatch(expr_parse(x$expr), error = function(e) e)
      if (inherits(ast, "error")) return(list(list(error = ast)))
      for (s in expr_symbols(ast)) addt(s, "expr", x$expr)
    }
    return(out)
  }
  elements <- function(vals) {
    if (!is.list(vals)) return(list())
    unlist(lapply(vals, function(e) val_node_targets(e, element = TRUE)), recursive = FALSE)
  }
  switch(x$kind,
    ref = addt(x$path, "ref"),
    expr = {
      ast <- tryCatch(x$ast %||% expr_parse(x$text), error = function(e) e)
      if (inherits(ast, "error")) return(list(list(error = ast)))
      for (s in expr_symbols(ast)) addt(s, "expr", x$text)
    },
    series_t = , series_year = , points = out <- c(out, elements(x$values)),
    schedule = out <- c(out, unlist(lapply(if (is.list(x$amounts)) x$amounts else list(),
                                           val_node_targets), recursive = FALSE)),
    growth = out <- c(out, val_node_targets(x$start), val_node_targets(x$growth)),
    quantity = out <- c(out, val_node_targets(x$value, element = element)),
    NULL
  )
  out
}

#' Shape eines Pfads (`"scalar"`, `"path"` oder `NA`)
#' @noRd
val_path_shape <- function(vc, path, stack = character(0)) {
  if (path %in% stack) return(NA_character_)
  procs <- vc$spec$stochastic$processes
  if (is_map(procs) && any(vapply(procs, function(p) identical(p$target, path), logical(1)))) {
    return("path")
  }
  x <- path_get(vc$spec, path)
  if (is.null(x)) return(NA_character_)
  if (!node_is(x)) {
    if (is.numeric(x) && !is.list(x)) return(if (length(x) == 1L) "scalar" else "path")
    if (is_map(x) && utl_is_string(x$ref)) return(val_path_shape(vc, x$ref, c(stack, path)))
    return(NA_character_)
  }
  if (x$kind %in% val_path_kinds()) return("path")
  if (identical(x$kind, "ref")) return(val_path_shape(vc, x$path, c(stack, path)))
  if (identical(x$kind, "expr")) {
    syms <- tryCatch(expr_symbols(x$ast %||% expr_parse(x$text)), error = function(e) NULL)
    sh <- vapply(syms, function(s) val_path_shape(vc, s, c(stack, path)), "")
    return(if (any(sh %in% "path")) "path" else "scalar")
  }
  if (identical(x$kind, "quantity")) {
    return(if (node_is(x$value) && x$value$kind %in% val_path_kinds()) "path" else "scalar")
  }
  "scalar"
}

#' Bezüge, Ausdrücke, Zyklen, Elementregel, Mengenbezüge der gelesenen Knoten
#' @noRd
val_value_refs <- function(vc) {
  spec <- vc$spec
  queue <- val_ref_roots(vc)
  visited <- character(0)
  edges <- list()
  reported <- character(0)
  broken <- character(0)
  while (length(queue) > 0L) {
    p <- queue[1L]
    queue <- queue[-1L]
    if (p %in% visited) next
    visited <- c(visited, p)
    node <- val_as_node(path_get(spec, p), p)
    tg <- val_node_targets(node)
    deps <- character(0)
    for (t in tg) {
      if (!is.null(t$error)) {
        val_add_condition(vc, t$error, p)
        broken <- c(broken, p)
        next
      }
      target <- t$target
      tag <- paste(p, target)
      if (tag %in% reported) next
      reported <- c(reported, tag)
      first <- path_split(target)[1L]
      if (!(first %in% val_ref_blocks())) {
        val_add(vc, "error", "validation.ref_target_forbidden", p, target = target)
        broken <- c(broken, p)
        next
      }
      tn <- path_get(spec, target)
      if (is.null(tn)) {
        if (identical(t$kind, "expr")) {
          val_add(vc, "error", "validation.expr.path_missing", p, text = t$text,
                  position = expr_token_position(t$text, target), symbol = target)
        } else {
          val_add(vc, "error", "validation.ref_target_missing", p, target = target,
                  suggestion = val_target_suggestion(spec, target))
        }
        broken <- c(broken, p)
        next
      }
      numeric_ok <- val_is_value(tn) || (is.numeric(tn) && !is.list(tn))
      if (identical(t$kind, "ref") && !numeric_ok) {
        val_add(vc, "error", "validation.ref_target_not_numeric", p, target = target)
        broken <- c(broken, p)
        next
      }
      if (isTRUE(t$element) && identical(val_path_shape(vc, target), "path")) {
        val_add(vc, "error", "validation.element_not_scalar", p, target = target)
      }
      if (numeric_ok && !(is.numeric(tn) && !is.list(tn))) {
        deps <- c(deps, target)
        if (!(target %in% visited)) queue <- c(queue, target)
      }
    }
    edges[[p]] <- unique(deps)
    if (node_is(node) && identical(node$kind, "quantity")) val_quantity_ref(vc, p, node)
  }
  for (cyc in val_find_cycles(edges)) {
    val_add(vc, "error", "validation.ref_cycle", cyc[1L],
            chain = utl_collapse(c(cyc, cyc[1L]), " -> "))
  }
  val_expr_dry_run(vc, visited, edges, broken)
  invisible(NULL)
}

#' Befund aus einer Bedingung mit Schlüssel `validation.*` (z. B. Ausdrucksfehler)
#'
#' Bedingungen ohne eigenen Schlüssel `validation.*` (z. B. Vertragsfehler der Formregel)
#' erscheinen als `fallback` mit dem Meldungstext (Platzhalter `detail`) und `args`; ohne
#' `fallback` werden sie verworfen.
#' @noRd
val_add_condition <- function(vc, cond, path, fallback = NULL, args = list()) {
  key <- cond$key
  if (!(utl_is_string(key) && startsWith(key, "validation.") && lbl_has(key))) {
    if (!is.null(fallback)) {
      do.call(val_add, c(list(vc, "error", fallback, path),
                         c(args, list(detail = conditionMessage(cond)))))
    }
    return(invisible(NULL))
  }
  args <- cond$args %||% list()
  args$path <- NULL
  do.call(val_add, c(list(vc, "error", key, path), args))
}

#' Vorschlag für ein fehlendes Ziel (Geschwister im Elternknoten)
#' @noRd
val_target_suggestion <- function(spec, target) {
  segs <- path_split(target)
  if (length(segs) < 2L) return("")
  parent <- path_get(spec, paste(segs[-length(segs)], collapse = "."))
  if (!is_map(parent)) return("")
  utl_suggest_text(segs[length(segs)], names(parent))
}

#' Zyklen eines gerichteten Graphen (Liste Knoten -> Nachfolger)
#' @return Liste von Zyklen (Knotenfolgen, je Zyklus einmal, beginnend beim kleinsten Knoten).
#' @noRd
val_find_cycles <- function(edges) {
  color <- new.env(parent = emptyenv())
  found <- list()
  keys <- character(0)
  visit <- function(v, stack) {
    assign(v, 1L, envir = color)
    for (w in edges[[v]] %||% character(0)) {
      cw <- get0(w, envir = color, inherits = FALSE, ifnotfound = 0L)
      if (cw == 1L) {
        cyc <- c(stack[match(w, stack):length(stack)])
        start <- which.min(rank(cyc, ties.method = "first"))
        cyc <- c(cyc[start:length(cyc)], cyc[seq_len(start - 1L)])
        k <- paste(cyc, collapse = "\r")
        if (!(k %in% keys)) {
          keys <<- c(keys, k)
          found[[length(found) + 1L]] <<- cyc
        }
      } else if (cw == 0L) {
        visit(w, c(stack, w))
      }
    }
    assign(v, 2L, envir = color)
  }
  for (v in sort(names(edges) %||% character(0), method = "radix")) {
    if (get0(v, envir = color, inherits = FALSE, ifnotfound = 0L) == 0L) visit(v, v)
  }
  found
}

#' Ausdrücke im Basisfall probeweise auswerten (Fehler der Ausdruckssprache, R-91)
#'
#' Ausgelassen werden Ausdrücke in Zyklen und Ausdrücke, die (transitiv) von einem bereits
#' gemeldeten fehlerhaften Bezug abhängen (`broken`). Fehler ohne eigenen Schlüssel
#' `validation.*` (z. B. Formfehler der Auswertung) erscheinen als
#' `validation.expr.eval_failed`.
#' @param vc Prüfkontext.
#' @param paths gelesene Pfade.
#' @param edges Abhängigkeiten (Pfad -> Zielpfade).
#' @param broken Pfade mit gemeldeten Fehlern der Bezüge bzw. Ausdrücke.
#' @noRd
val_expr_dry_run <- function(vc, paths, edges, broken = character(0)) {
  if (is.null(vc$grid)) return(invisible(NULL))
  cyclic <- unique(unlist(val_find_cycles(edges)))
  reaches_broken <- function(p) {
    seen <- character(0)
    todo <- p
    while (length(todo) > 0L) {
      q <- todo[1L]
      todo <- todo[-1L]
      if (q %in% broken) return(TRUE)
      if (q %in% seen) next
      seen <- c(seen, q)
      todo <- c(todo, edges[[q]] %||% character(0))
    }
    FALSE
  }
  rc <- res_context(vc$spec, vc$grid, 1L)
  for (p in setdiff(paths, cyclic)) {
    node <- val_as_node(path_get(vc$spec, p), p)
    if (!(node_is(node) && identical(node$kind, "expr")) || reaches_broken(p)) next
    res <- tryCatch(suppressMessages(suppressWarnings(res_node(rc, node, p, TRUE, p))),
                    error = function(e) e)
    if (inherits(res, "error")) {
      val_add_condition(vc, res, p, fallback = "validation.expr.eval_failed",
                        args = list(text = node$text %||% ""))
    }
  }
  invisible(NULL)
}

#' Bezugsobjekt eines Mengenbezugs (Teil A 3.5)
#' @noRd
val_quantity_object <- function(path) {
  segs <- path_split(path)
  n <- length(segs)
  if (n >= 3L && segs[1L] %in% c("measures", "unit_groups", "funding", "components",
                                 "financing")) {
    return(paste(segs[1:2], collapse = "."))
  }
  if (n >= 4L && ((segs[1L] == "building" && segs[2L] == "elements") ||
                    (segs[1L] == "energy" && segs[2L] %in% c("carriers", "stages")))) {
    return(paste(segs[1:3], collapse = "."))
  }
  paste(segs[-n], collapse = ".")
}

#' Bezugsgröße eines Mengenbezugs vorhanden? (Teil A 3.5, R-91)
#' @noRd
val_quantity_ref <- function(vc, path, node) {
  per <- node$per
  if (!utl_is_string(per) || identical(per, "total")) return(invisible(NULL))
  field <- res_quantity_field(per)
  own <- path_join(val_quantity_object(path), field)
  cands <- own
  if (!(per %in% c("kw", "kwp", "kwh"))) cands <- c(cands, paste0("building.", field))
  if (!any(vapply(cands, function(cp) !is.null(path_get(vc$spec, cp)), logical(1)))) {
    val_add(vc, "error", "validation.quantity.reference_missing", path, per = per)
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Komponenten: Abhängigkeiten und Zyklen (4.3.8, 6.4), auto/topup (8.7)
# ---------------------------------------------------------------------------------------------

#' Abhängigkeiten der Komponenten: after, ref-Parameter, Bezüge; Zyklen
#' @noRd
val_component_deps <- function(vc) {
  spec <- vc$spec
  ids <- c(names(spec$components), names(spec$financing))
  edges <- list()
  for (coll in c("components", "financing")) {
    for (id in names(spec[[coll]])) {
      comp <- spec[[coll]][[id]]
      if (!is_map(comp)) next
      path <- path_join(coll, id)
      deps <- character(0)
      after <- val_chr_list(comp$after) %||% character(0)
      for (a in after) {
        if (!(a %in% ids)) {
          val_add(vc, "error", "validation.after_unknown", path_join(path, "after"), value = a,
                  suggestion = utl_suggest_text(a, ids))
        } else {
          deps <- c(deps, a)
        }
      }
      def <- scn_type_def(comp$type, coll)
      for (p in names(def$params)) {
        if (identical(def$params[[p]]$kind, "ref") && utl_is_string(comp[[p]])) {
          if (!(comp[[p]] %in% ids)) {
            val_add(vc, "error", "validation.ref_id_unknown", path_join(path, p),
                    value = comp[[p]], collection = "components",
                    suggestion = utl_suggest_text(comp[[p]], ids))
          } else {
            deps <- c(deps, comp[[p]])
          }
        }
      }
      for (p in names(comp)) {
        for (t in val_node_targets(comp[[p]])) {
          segs <- path_split(t$target %||% "")
          if (length(segs) >= 2L && segs[1L] %in% c("components", "financing") &&
                segs[2L] %in% ids) {
            deps <- c(deps, segs[2L])
          }
        }
      }
      edges[[id]] <- setdiff(unique(deps), id)
    }
  }
  for (cyc in val_find_cycles(edges)) {
    coll <- if (cyc[1L] %in% names(spec$components)) "components" else "financing"
    val_add(vc, "error", "validation.component_cycle", path_join(coll, cyc[1L]),
            chain = utl_collapse(c(cyc, cyc[1L]), " -> "))
  }
  invisible(NULL)
}

#' auto/topup höchstens je einmal, ohne Auszahlungsplan, Bestand und anderen Termin (8.7)
#' @noRd
val_auto <- function(vc) {
  fin <- vc$spec$financing
  seen <- c(auto = 0L, topup = 0L)
  for (id in names(fin)) {
    comp <- fin[[id]]
    a <- comp$amount_eur
    mode <- if (node_is(a) && identical(a$kind, "auto")) a$mode else
      if (utl_is_string(a) && a %in% c("auto", "topup")) a else NULL
    if (is.null(mode)) next
    path <- path_join("financing", id, "amount_eur")
    seen[[mode]] <- seen[[mode]] + 1L
    if (seen[[mode]] > 1L) val_add(vc, "error", "validation.auto_multiple", path, mode = mode)
    start <- val_as_date(comp[["start"]], year = TRUE)
    conflict <- c(draw_schedule = !is.null(comp$draw_schedule),
                  existing = isTRUE(val_flag(comp$existing)),
                  start = !is.null(start) && !is.null(vc$vd) && start != vc$vd)
    for (f in names(conflict)[conflict]) {
      val_add(vc, "error", "validation.auto_conflict", path_join("financing", id, f),
              mode = mode)
    }
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Entscheidungsknoten (9.11, R-71; Teil B 4.9)
# ---------------------------------------------------------------------------------------------

#' Frühester Termin einer Maßnahme ohne Verschiebung (date, year, erster Zahlungstermin)
#' @noRd
val_measure_first_date <- function(m) {
  if (!is_map(m)) return(NULL)
  d <- val_as_date(m$date)
  if (!is.null(d)) return(d)
  d <- val_as_date(m$year, year = TRUE)
  if (!is.null(d)) return(d)
  val_schedule_dates(m$payment_schedule)[1L]
}

#' Termine eines Zahlungsplans (Knoten oder Rohform), aufsteigend
#' @noRd
val_schedule_dates <- function(x) {
  if (is.null(x)) return(NULL)
  dates <- if (node_is(x) && identical(x$kind, "schedule")) {
    x$dates
  } else if (is_map(x) && is_map(x$schedule)) {
    val_dates_c(lapply(names(x$schedule), function(k) val_as_date(k, year = TRUE)))
  } else {
    NULL
  }
  if (length(dates) == 0L || !inherits(dates, "Date")) return(NULL)
  sort(dates)
}

#' Aufgelöster Zeitpunkt der Zusage eines Instruments (4.3.7, R-111)
#'
#' Liest den Code von `approval_timing`; fehlt er oder ist er `auto` (vor der Ableitungsregel
#' `rule:approval_timing`), wird er nach derselben Regel bestimmt.
#' @noRd
val_approval_timing <- function(vc, fid) {
  f <- vc$spec$funding[[fid]]
  code <- val_str(f$approval_timing)
  if (!is.null(code) && code %in% c("before_start", "after_start")) return(code)
  app <- val_as_date(f$application_date) %||% val_as_date(vc$spec$project$application_date) %||%
    vc$vd
  ms <- val_chr_list(f$measures) %||% character(0)
  if (length(ms) == 0L) ms <- val_ids(vc, "measures")
  dates <- val_dates_c(lapply(ms, function(m) val_measure_first_date(vc$spec$measures[[m]])))
  if (length(dates) == 0L || is.null(app)) return("before_start")
  if (app <= min(dates)) "before_start" else "after_start"
}

#' Entscheidungsknoten einer Spezifikation (Instrumente mit before_start und fallback_variant)
#' @noRd
val_decision_ids <- function(vc) {
  fund <- vc$spec$funding
  ids <- names(fund)[vapply(names(fund), function(f) {
    utl_is_string(fund[[f]]$fallback_variant) &&
      identical(val_approval_timing(vc, f), "before_start")
  }, logical(1))]
  ids %||% character(0)
}

#' Entscheidungsknoten: höchstens einer je Variante; fehlende Ausweichvariante; on_reject
#' @noRd
val_decision_nodes <- function(vc) {
  fund <- vc$spec$funding
  if (!is_map(fund) || length(fund) == 0L) return(invisible(NULL))
  nodes <- val_decision_ids(vc)
  if (length(nodes) > 1L) {
    for (f in nodes[-1L]) {
      val_add(vc, "error", "validation.funding.decision_multiple",
              path_join("funding", f, "fallback_variant"), value = utl_collapse(nodes))
    }
  }
  for (f in names(fund)) {
    path <- path_join("funding", f)
    if (f %in% nodes) {
      if (!is.null(fund[[f]]$on_reject) && val_explicit(vc, path_join(path, "on_reject"))) {
        val_add(vc, "info", "validation.funding.on_reject_ignored", path_join(path, "on_reject"))
      }
      next
    }
    if (!identical(val_approval_timing(vc, f), "before_start")) next
    p <- val_base_scalar(vc, path_join(path, "approval_probability"))
    if (!is.null(p) && p < 1 && !utl_is_string(fund[[f]]$fallback_variant)) {
      val_add(vc, "warning", "validation.funding.fallback_missing", path, value = p)
    }
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Overlay-Ziele (11.2, 11.7, R-16; Teil C 1.3, 1.5, 1.9, 1.11)
# ---------------------------------------------------------------------------------------------

#' Ist `cost_eur` einer Maßnahme abgeleitet? (rule:cost_from_kg, Teil A 4.6.1)
#' @noRd
val_cost_derived <- function(vc, mid) {
  m <- vc$spec$measures[[mid]]
  if (!is_map(m)) return(FALSE)
  if (!is.null(m$cost_kg)) return(TRUE)
  ps <- m$payment_schedule
  unit <- if (node_is(ps)) ps$unit else if (is_map(ps)) ps$unit else NULL
  if (!is.null(ps) && !identical(unit, "share") && !is.null(unit)) return(TRUE)
  ent <- val_prov_entry(vc, path_join("measures", mid, "cost_eur"))
  identical(ent, "rule:cost_from_kg")
}

#' Eintrag der Herkunft eines Pfads (`NA`, wenn unbekannt)
#' @noRd
val_prov_entry <- function(vc, path) {
  prov <- vc$prov
  if (!is.data.frame(prov) || !("entry" %in% names(prov))) return(NA_character_)
  hit <- which(prov$path == path)
  if (length(hit) == 0L) hit <- which(startsWith(prov$path, paste0(path, ".")))
  if (length(hit) == 0L) return(NA_character_)
  as.character(prov$entry[hit[1L]])
}

#' Overlay-Ziele prüfen
#' @noRd
val_overlay_refs <- function(vc) {
  st <- vc$spec$stochastic
  if (!is_map(st)) return(invisible(NULL))
  seen <- character(0)
  static_targets <- character(0)
  for (kind in c("parameters", "processes")) {
    entries <- st[[kind]]
    if (!is_map(entries)) next
    for (k in names(entries)) {
      e <- entries[[k]]
      if (!is_map(e) || !utl_is_string(e$target)) next
      path <- path_join("stochastic", kind, k)
      tgt <- e$target
      if (tgt %in% names(seen)) {
        val_add(vc, "error", "validation.stochastic.target_duplicate", path_join(path, "target"),
                target = tgt, other = seen[[tgt]])
        next
      }
      seen[[tgt]] <- path
      if (identical(kind, "parameters")) static_targets <- c(static_targets, tgt)
      val_overlay_target(vc, k, e, path, kind)
    }
  }
  val_cost_risk_double(vc, static_targets)
  val_linked_cycles(vc)
  invisible(NULL)
}

#' Ein Overlay-Ziel prüfen
#' @noRd
val_overlay_target <- function(vc, key, e, path, kind) {
  spec <- vc$spec
  tgt <- e$target
  tp <- path_join(path, "target")
  segs <- path_split(tgt)
  if (grepl("^financing\\.[^.]+\\.amount_eur$", tgt)) {
    val_add(vc, "error", "validation.stochastic.credit_amount_target", tp, target = tgt)
    return(invisible(NULL))
  }
  if (length(segs) >= 2L && identical(segs[1L], "energy") &&
        identical(segs[length(segs)], "jaz_plan")) {
    val_add(vc, "error", "validation.stochastic.jaz_plan_target", tp, target = tgt)
    return(invisible(NULL))
  }
  if (length(segs) == 3L && identical(segs[1L], "measures") && identical(segs[3L], "cost_eur") &&
        val_cost_derived(vc, segs[2L])) {
    val_add(vc, "error", "validation.measures.cost_derived", tp, target = tgt,
            suggestion = path_join("measures", segs[2L], "cost_factor"))
    return(invisible(NULL))
  }
  if (identical(tgt, "residual_value.income_value.remaining_life_years") &&
        !identical(val_str(spec$residual_value$income_value$remaining_life_method), "manual")) {
    val_add(vc, "error", "validation.residual.rnd_target", tp, target = tgt)
    return(invisible(NULL))
  }
  node <- path_get(spec, tgt)
  if (is.null(node)) {
    val_add(vc, "error", "validation.stochastic.target_missing", tp, target = tgt,
            suggestion = val_target_suggestion(spec, tgt))
    return(invisible(NULL))
  }
  p <- val_param_at(spec, tgt)
  if (!is.null(p)) {
    if (isTRUE(p$deterministic_only)) {
      val_add(vc, "error", "validation.stochastic.target_deterministic_only", tp, target = tgt)
      return(invisible(NULL))
    }
    if (!(p$kind %in% val_numeric_kinds())) {
      val_add(vc, "error", "validation.stochastic.target_not_numeric", tp, target = tgt)
      return(invisible(NULL))
    }
    if (identical(p$stochastic, FALSE)) {
      val_add(vc, "warning", "validation.stochastic.target_usually_fixed", tp, target = tgt)
    }
    if (identical(kind, "processes") && !("path" %in% (p$shapes %||% "scalar"))) {
      val_add(vc, "error", "validation.stochastic.target_not_path", tp, target = tgt)
      return(invisible(NULL))
    }
  } else if (!(val_is_value(node) || (is.numeric(node) && !is.list(node)))) {
    val_add(vc, "error", "validation.stochastic.target_not_numeric", tp, target = tgt)
    return(invisible(NULL))
  }
  if (is.null(vc$grid)) return(invisible(NULL))
  base <- val_base(vc, tgt, "path")
  if (is.null(base) || length(base) == 0L || anyNA(base)) {
    val_add(vc, "error", "validation.stochastic.target_no_base", tp, target = tgt)
    return(invisible(NULL))
  }
  if (grepl("^funding\\.[^.]+\\.approved$", tgt)) {
    val_add(vc, "info", "validation.stochastic.approval_key_and_availability", tp, target = tgt)
  }
  if (identical(tgt, "building.existing_value_eur")) {
    val_add(vc, "warning", "validation.building.existing_value_overlay", tp)
  }
  if (identical(tgt, "energy.performance_gap.prebound_factor") &&
        identical(val_str(spec$energy$before$consumption_basis), "measured")) {
    val_add(vc, "warning", "validation.stochastic.prebound_with_measured", tp)
  }
  if (!identical(kind, "parameters")) return(invisible(NULL))
  dist <- e$dist
  if (!utl_is_string(dist) || !reg_has("distribution", dist)) return(invisible(NULL))
  def <- reg_get("distribution", dist)
  par <- val_dist_par(e)
  if (length(tryCatch(def$validate(par), error = function(err) "error")) > 0L) {
    return(invisible(NULL))
  }
  ap <- val_str(e$apply) %||% "replace"
  b <- base[min(2L, length(base))]
  if (identical(ap, "replace")) {
    # Träger [Q(0), Q(1)] einschließlich der Ränder (z. B. Basis 0 bei beta, pert mit min 0)
    q <- tryCatch(suppressWarnings(as.double(def$quantile(c(0, 1), par))),
                  error = function(err) c(NA_real_, NA_real_))
    if (length(q) != 2L) q <- c(NA_real_, NA_real_)
    tol <- 1e-9 * max(1, abs(b))
    if (!anyNA(q) && (b < q[1L] - tol || b > q[2L] + tol)) {
      val_add(vc, "error", "validation.stochastic.base_outside_support", tp, value = b,
              interval = val_interval(q[1L], q[2L]))
    }
    mode <- val_num(par$mode)
    if (length(mode) == 1L && abs(mode - b) > tol) {
      val_add(vc, "info", "validation.stochastic.mode_differs_base", tp, value = b, mode = mode)
      if (identical(tgt, "energy.performance_gap.rebound_factor")) {
        val_add(vc, "warning", "validation.energy.rebound_base_differs", tp, value = b,
                mode = mode)
      }
    }
    eb <- val_num(e$base)
    if (length(eb) == 1L && abs(eb - b) > tol) {
      val_add(vc, "warning", "validation.stochastic.base_differs", path_join(path, "base"),
              value = eb, base = b)
    }
  }
  if (!is.null(p) && identical(p$kind, "share") && dist %in% c("normal", "lognormal")) {
    val_add(vc, "warning", "validation.stochastic.share_unbounded", path_join(path, "dist"),
            value = dist)
  }
  invisible(NULL)
}

#' Kostenrisiko doppelt (Teil A 4.6.5; Teil C 1.11 cost_risk_double)
#' @noRd
val_cost_risk_double <- function(vc, targets) {
  ms <- val_ids(vc, "measures")
  proj <- "project.construction_cost_factor" %in% targets
  for (m in ms) {
    cs <- path_join("measures", m, "contingency_share")
    if (!(cs %in% targets)) next
    cf <- path_join("measures", m, "cost_factor")
    if (cf %in% targets || path_join("measures", m, "cost_eur") %in% targets) {
      val_add(vc, "warning", "validation.measures.cost_risk_double", path_join("measures", m))
    } else if (proj) {
      node <- vc$spec$measures[[m]]$cost_factor
      tgt <- if (node_is(node) && identical(node$kind, "ref")) node$path else
        if (is_map(node)) node$ref else NULL
      if (is.null(node) || identical(tgt, "project.construction_cost_factor")) {
        val_add(vc, "warning", "validation.stochastic.cost_risk_double", cs)
      }
    }
  }
  invisible(NULL)
}

#' Verknüpfte Prozesse: Basis vorhanden, keine Zyklen (Teil C 1.6.2, 1.11 linked_cycle)
#' @noRd
val_linked_cycles <- function(vc) {
  procs <- vc$spec$stochastic$processes
  if (!is_map(procs) || length(procs) == 0L) return(invisible(NULL))
  edges <- list()
  for (k in names(procs)) {
    e <- procs[[k]]
    if (!is_map(e) || !utl_is_string(e$type) || !reg_has("process", e$type)) next
    def <- reg_get("process", e$type)
    links <- def$linked %||% character(0)
    if (length(links) == 0L && identical(e$type, "linked_ar1")) links <- "base"
    deps <- character(0)
    for (l in links) {
      b <- e[[l]]
      if (is.null(b)) next
      if (!(utl_is_string(b) && b %in% names(procs))) {
        val_add(vc, "error", "validation.stochastic.linked_base_unknown",
                path_join("stochastic.processes", k, l), value = utl_collapse(format(b)),
                suggestion = utl_suggest_text(as.character(b)[1L], names(procs)))
      } else {
        deps <- c(deps, b)
      }
    }
    edges[[k]] <- deps
  }
  for (cyc in val_find_cycles(edges)) {
    val_add(vc, "error", "validation.stochastic.linked_cycle",
            path_join("stochastic.processes", cyc[1L]),
            chain = utl_collapse(c(cyc, cyc[1L]), " -> "))
  }
  invisible(NULL)
}

#' Schlüssel der Rolle decision (11.6 Nr. 4, R-71)
#' @noRd
val_decision_keys <- function(vc) {
  nodes <- val_decision_ids(vc)
  if (length(nodes) == 0L) return(character(0))
  tg <- paste0("funding.", nodes, ".approved")
  pars <- vc$spec$stochastic$parameters
  hit <- names(pars)[vapply(pars, function(e) {
    is_map(e) && utl_is_string(e$target) && e$target %in% tg
  }, logical(1))]
  unique(c(tg, hit))
}

#' Korrelationspaare (Teil C 1.7.1, 1.11; Spec 00 11.6 Nr. 4, 7)
#' @noRd
val_correlations <- function(vc) {
  st <- vc$spec$stochastic
  cr <- st$correlations
  pars <- st$parameters %||% list()
  procs <- st$processes %||% list()
  dec <- val_decision_keys(vc)
  for (k in intersect(names(pars), dec)) {
    e <- pars[[k]]
    if (!is_map(e)) next
    ok <- identical(e$dist, "bernoulli") ||
      (identical(e$dist, "discrete") && all(val_num(e$values) %in% c(0, 1)))
    if (!ok) val_add(vc, "error", "validation.stochastic.decision_correlated",
                     path_join("stochastic.parameters", k), value = k)
  }
  if (!is_map(cr) || length(cr) == 0L) return(invisible(NULL))
  for (f in setdiff(names(cr), c("parameters", "shocks"))) {
    val_add(vc, "error", "validation.stochastic.unknown_key", path_join("stochastic.correlations",
                                                                        f),
            suggestion = utl_suggest_text(f, c("parameters", "shocks")))
  }
  proc_params <- unlist(lapply(names(procs), function(k) {
    e <- procs[[k]]
    if (!is_map(e)) return(NULL)
    nm <- names(e)[vapply(e, function(v) is_map(v) && utl_has_name(v, "dist"), logical(1))]
    if (identical(e$type, "iid")) nm <- setdiff(nm, "dist_spec")   # Jahresverteilung
    if (length(nm) == 0L) NULL else paste(k, nm, sep = ".")
  }))
  fund_keys <- paste0("funding.", val_ids(vc, "funding"), ".approved")
  static <- unique(c(names(pars), proc_params, fund_keys))
  for (kind in c("parameters", "shocks")) {
    pairs <- cr[[kind]]
    if (is.null(pairs) || length(pairs) == 0L) next
    base <- path_join("stochastic.correlations", kind)
    if (!is.list(pairs) || is_map(pairs)) {
      val_add(vc, "error", "validation.not_list", base)
      next
    }
    from_library <- utl_is_library_id(val_prov_entry(vc, base))
    rhos <- list()
    for (i in seq_along(pairs)) {
      pr <- as.list(pairs[[i]])
      pp <- path_join(base, i)
      rho <- if (length(pr) == 3L) val_num(pr[[3L]]) else NULL
      if (length(pr) != 3L || !utl_is_string(pr[[1L]]) || !utl_is_string(pr[[2L]]) ||
            length(rho) != 1L || is.na(rho)) {
        val_add(vc, "error", "validation.stochastic.corr_pair_invalid", pp,
                value = utl_collapse(format(unlist(pr))))
        next
      }
      a <- pr[[1L]]
      b <- pr[[2L]]
      valid <- if (identical(kind, "parameters")) static else names(procs)
      unknown <- setdiff(c(a, b), valid)
      if (length(unknown) > 0L) {
        if (!from_library) {
          val_add(vc, "error", "validation.stochastic.corr_unknown_key", pp, value = unknown[1L],
                  suggestion = utl_suggest_text(unknown[1L], valid))
        }
        next
      }
      if (identical(a, b)) {
        val_add(vc, "error", "validation.stochastic.corr_self", pp, value = a)
        next
      }
      if (abs(rho) > 1) {
        val_add(vc, "error", "validation.stochastic.corr_range", pp, value = rho)
        next
      }
      if (abs(rho) == 1) val_add(vc, "warning", "validation.stochastic.corr_one", pp)
      key <- paste(sort(c(a, b), method = "radix"), collapse = "\r")
      if (!is.null(rhos[[key]]) && abs(rhos[[key]] - rho) > 1e-12) {
        val_add(vc, "error", "validation.stochastic.corr_conflict", pp, value = a, other = b)
      }
      rhos[[key]] <- rho
      if (identical(kind, "parameters")) {
        for (x in intersect(c(a, b), dec)) {
          val_add(vc, "error", "validation.stochastic.decision_correlated", pp, value = x)
        }
        for (x in c(a, b)) {
          d <- pars[[x]]$dist
          if (utl_is_string(d) && d %in% c("bernoulli", "discrete")) {
            val_add(vc, "info", "validation.stochastic.corr_ties", pp, value = x)
          }
        }
      } else {
        for (x in c(a, b)) {
          e <- procs[[x]]
          if (!utl_is_string(e$type) || !reg_has("process", e$type)) next
          def <- reg_get("process", e$type)
          ns <- tryCatch(def$n_shocks(e), error = function(err) NA)
          if (!identical(as.integer(ns), 1L)) {
            val_add(vc, "error", "validation.stochastic.corr_no_shock", pp, value = x)
          }
        }
        if (identical(procs[[a]]$base, b) || identical(procs[[b]]$base, a)) {
          val_add(vc, "info", "validation.stochastic.corr_double_counting", pp, value = a,
                  other = b)
        }
      }
    }
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Vergleiche über Varianten und Szenario-Sets (4.9 Nr. 1, 4.11, 9.11, 12.3a; Teil A 5.3)
# ---------------------------------------------------------------------------------------------

#' Bestandsprojekte (Spec 00 1.5)
#' @noRd
val_existing_project_types <- function() {
  c("sanierung_eh", "sanierung_einzelmassnahmen", "sanierung_stufenweise", "heizungstausch")
}

#' Prüfungen über Varianten und Szenario-Sets
#' @param x `vofi_scenario`.
#' @param specs Liste der aufgelösten Varianten.
#' @param full alle Varianten geprüft (dann auch Szenario-Sets).
#' @return Liste von Befunden.
#' @noRd
val_cross <- function(x, specs, full = TRUE) {
  cache <- new.env(parent = emptyenv())
  for (v in names(specs)) assign(v, specs[[v]], envir = cache)
  get_spec <- function(v) {
    if (!exists(v, envir = cache, inherits = FALSE)) {
      s <- tryCatch(vofi_resolve(x, variant = v), error = function(e) NULL)
      assign(v, s, envir = cache)
    }
    get(v, envir = cache, inherits = FALSE)
  }
  base <- get_spec("base")
  if (is.null(base)) return(list())
  out <- list()
  vc0 <- val_context(base, "base", x)
  val_reference_variant(vc0, x)
  out <- c(out, vc0$out)
  for (v in setdiff(names(specs), "base")) {
    vc <- val_context(specs[[v]], v, x)
    val_existing_vs_base(vc, base)
    out <- c(out, vc$out)
  }
  vars <- c("base", names(x$variants %||% list()))
  for (v in names(specs)) {
    vc <- val_context(specs[[v]], v, x)
    val_fallbacks(vc, vars, get_spec)
    val_replaces_ohnehin(vc, vars, get_spec)
    out <- c(out, vc$out)
  }
  if (full) out <- c(out, val_sets_cross(x, base))
  out
}

#' Referenzvariante (12.3a, R-68)
#' @noRd
val_reference_variant <- function(vc, x) {
  p <- vc$spec$project %||% list()
  rv <- val_str(p$reference_variant) %||% "base"
  vars <- c("base", names(x$variants %||% list()))
  bestand <- utl_is_string(p$project_type) && p$project_type %in% val_existing_project_types()
  absolute <- identical(val_str(p$comparison_mode) %||% "absolute", "absolute")
  allow <- isTRUE(val_flag(vc$spec$analysis$allow_opportunity_reference))
  pk <- val_str(vc$spec$analysis$primary_kpi) %||% "auto"
  report <- function(path) {
    if (allow) {
      val_add(vc, "warning", "validation.reference_variant_opportunity", path, value = rv)
    } else {
      val_add(vc, "error", "validation.reference_variant_missing", path, value = rv)
    }
  }
  if (!(rv %in% vars)) {
    if (bestand && absolute) {
      report("project.reference_variant")
    } else {
      val_add(vc, "error", "validation.reference_variant_unknown", "project.reference_variant",
              value = rv, suggestion = utl_suggest_text(rv, vars))
    }
    return(invisible(NULL))
  }
  if (bestand && absolute) {
    if (length(vars) < 2L) {
      report("project.reference_variant")
    } else if (identical(pk, "delta_terminal_value")) {
      report("analysis.primary_kpi")
    }
  }
  # Erwerb mit Sanierung: Referenzvariante für die Sanierungsentscheidung empfohlen (12.3a)
  if (identical(p$project_type, "erwerb_sanierung") && length(vars) < 2L) {
    val_add(vc, "info", "validation.reference_variant_recommended", "project.reference_variant",
            value = p$project_type)
  }
  invisible(NULL)
}

#' Parameter eines Bausteins ohne Metafelder (Vergleich über Varianten)
#' @noRd
val_comp_params <- function(comp) {
  if (!is.list(comp)) return(comp)
  comp <- comp[setdiff(names(comp), c("label", "description", "after", "origin"))]
  comp[!vapply(comp, is.null, logical(1))]
}

#' Bestandswert und Bestandsdarlehen sind in allen Varianten gleich (4.9 Nr. 1, 5.3)
#' @noRd
val_existing_vs_base <- function(vc, base) {
  spec <- vc$spec
  if (!identical(base$building$existing_value_eur, spec$building$existing_value_eur)) {
    val_add(vc, "error", "validation.variants.existing_value_changed",
            "building.existing_value_eur", value = vc$variant)
  }
  ex <- function(s) {
    fin <- s$financing
    names(fin)[vapply(fin, function(c) isTRUE(val_flag(c$existing)), logical(1))] %||%
      character(0)
  }
  eb <- ex(base)
  ev <- ex(spec)
  for (id in union(eb, ev)) {
    same <- id %in% eb && id %in% ev &&
      identical(val_comp_params(base$financing[[id]]), val_comp_params(spec$financing[[id]]))
    if (!same) {
      val_add(vc, "error", "validation.variants.existing_debt_changed",
              path_join("financing", id), value = vc$variant)
    }
  }
  invisible(NULL)
}

#' Ersetzte Ohnehin-Maßnahmen existieren in der Referenzvariante (Teil A 4.1)
#' @noRd
val_replaces_ohnehin <- function(vc, vars, get_spec) {
  ms <- vc$spec$measures
  if (!is_map(ms) || length(ms) == 0L) return(invisible(NULL))
  rv <- val_str(vc$spec$project$reference_variant) %||% "base"
  if (!(rv %in% vars)) return(invisible(NULL))          # meldet val_reference_variant()
  ref <- get_spec(rv)
  if (is.null(ref)) return(invisible(NULL))
  ids <- names(ref$measures %||% list()) %||% character(0)
  for (m in names(ms)) {
    ro <- if (is_map(ms[[m]])) val_chr_list(ms[[m]]$replaces_ohnehin) else NULL
    for (id in setdiff(ro %||% character(0), ids)) {
      val_add(vc, "warning", "validation.measures.replaces_ohnehin_unknown",
              path_join("measures", m, "replaces_ohnehin"), value = id, reference = rv,
              suggestion = utl_suggest_text(id, ids))
    }
  }
  invisible(NULL)
}

#' Ausweichvarianten der Entscheidungsknoten (9.11 Nr. 1, 4)
#' @noRd
val_fallbacks <- function(vc, vars, get_spec) {
  for (f in val_decision_ids(vc)) {
    fb <- vc$spec$funding[[f]]$fallback_variant
    path <- path_join("funding", f, "fallback_variant")
    if (!(fb %in% vars)) {
      val_add(vc, "error", "validation.funding.fallback_unknown", path, value = fb,
              suggestion = utl_suggest_text(fb, vars))
      next
    }
    fs <- get_spec(fb)
    if (is.null(fs)) next
    if (f %in% names(fs$funding %||% list())) {
      val_add(vc, "error", "validation.funding.fallback_contains", path, value = fb,
              funding = f)
    }
    vf <- val_context(fs, fb, vc$scenario)
    if (length(val_decision_ids(vf)) > 0L) {
      val_add(vc, "error", "validation.funding.fallback_nested", path, value = fb)
    }
    if (!identical(val_chr_list(vc$spec$analysis$kpis), val_chr_list(fs$analysis$kpis))) {
      val_add(vc, "error", "validation.funding.fallback_kpis", path, value = fb)
    }
  }
  invisible(NULL)
}

#' Szenario-Sets gegen die Basis: Platzhalter, Wachstumsform, generierte Sets
#'
#' Auflösung und Prüfung der statischen Sets auf den Ebenen 2 bis 4: `val_sets_specs()`.
#' @noRd
val_sets_cross <- function(x, base) {
  sets <- x$scenario_sets
  out <- list()
  if (!is_map(sets) || length(sets) == 0L) return(out)
  vc <- val_context(base, "base", x)
  for (s in names(sets)) {
    e <- sets[[s]]
    if (!is_map(e)) next
    vc$variant <- s
    path <- path_join("scenario_sets", s)
    if (!is.null(e$generate)) {
      val_generate_cross(vc, e$generate, path_join(path, "generate"))
      next
    }
    ops <- list()
    for (op in c("set", "replace", "add", "overrides")) {
      o <- e[[op]]
      if (!is_map(o)) next
      ps <- if (identical(op, "overrides")) var_override_leaves(o) else names(o)
      for (p in ps) {
        value <- if (identical(op, "overrides")) path_get(o, p) else o[[p]]
        ops[[length(ops) + 1L]] <- list(op = op, path = p, value = value)
      }
    }
    for (p in val_chr_list(e$remove) %||% character(0)) {
      ops[[length(ops) + 1L]] <- list(op = "remove", path = p, value = NULL)
    }
    for (o in ops) {
      where <- path_join(path, o$op)
      targets <- o$path
      segs <- path_split(o$path)
      if (sum(segs == "*") == 1L) {
        i <- which(segs == "*")
        parent <- path_get(base, paste(segs[seq_len(i - 1L)], collapse = "."))
        ids <- if (is_map(parent)) names(parent) else character(0)
        targets <- vapply(ids, function(id) {
          s2 <- segs
          s2[i] <- id
          paste(s2, collapse = ".")
        }, "")
        if (length(targets) == 0L) {
          val_add(vc, "info", "validation.scenario_set.wildcard_no_match", where, value = o$path)
        }
      }
      for (t in targets) {
        v <- o$value
        if (identical(path_split(t)[1L], "market") && o$op %in% c("set", "overrides") &&
              is_map(v) && !node_is(v) && utl_has_name(v, "growth") &&
              !utl_has_name(v, "start")) {
          bn <- path_get(base, t)
          if (!(node_is(bn) && identical(bn$kind, "growth"))) {
            val_add(vc, "error", "validation.scenario_set.growth_form_required", where, value = t)
          }
        }
      }
    }
  }
  c(out, vc$out)
}

#' Generiertes Set: Kennzahl, Kandidaten, Quantilpfade (Teil C 4.1, 4.3)
#' @noRd
val_generate_cross <- function(vc, gen, path) {
  if (!is_map(gen)) return(invisible(NULL))
  st <- vc$spec$stochastic
  pars <- st$parameters %||% list()
  procs <- st$processes %||% list()
  kpi <- val_str(gen$kpi) %||% "auto"
  if (!identical(kpi, "auto") && !reg_has("kpi", kpi)) {
    val_add(vc, "error", "validation.kpi_unknown", path_join(path, "kpi"), value = kpi,
            suggestion = utl_suggest_text(kpi, reg_list("kpi")$name))
  }
  proc_params <- unlist(lapply(names(procs), function(k) {
    if (!is_map(procs[[k]])) return(NULL)
    paste(k, setdiff(names(procs[[k]]), val_overlay_meta("processes")), sep = ".")
  }))
  known <- c(names(pars), names(procs), proc_params)
  is_target <- function(cand) {
    if (cand %in% known) return(TRUE)
    segs <- path_split(cand)
    if (sum(segs == "*") == 1L) {
      i <- which(segs == "*")
      parent <- path_get(vc$spec, paste(segs[seq_len(i - 1L)], collapse = "."))
      return(is_map(parent) && length(parent) > 0L)
    }
    n <- path_get(vc$spec, cand)
    val_is_value(n) || (is.numeric(n) && !is.list(n))
  }
  for (f in c("params", "exclude")) {
    cands <- val_chr_list(gen[[f]])
    if (is.null(cands) || identical(cands, "auto")) next
    for (cand in cands) {
      if (!is_target(cand)) {
        val_add(vc, "error", "validation.scenario_set.generate_param_unknown",
                path_join(path, f), value = cand)
      }
    }
  }
  for (k in names(procs)) {
    e <- procs[[k]]
    if (!is_map(e) || !utl_is_string(e$type) || !reg_has("process", e$type)) next
    if (!is.function(reg_get("process", e$type)$quantile_path)) {
      val_add(vc, "info", "validation.scenario_set.quantile_path_unavailable", path, value = k)
    }
  }
  invisible(NULL)
}
