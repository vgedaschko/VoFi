# Knoten -> n-Vektor bzw. n x (T+1) im Laufkontext (WS-D, Spec 00 Abschnitte 4.5, 6.3).
# Aufloesungsreihenfolge 6.3: statische Ziehung (mit Verknuepfung apply, R-94) -> Prozesspfad ->
# Knoten. Alle Knotenarten aus 4.5 (const, series_t, series_year, points, schedule, ref mit
# scale/offset/floor/cap bzw. anchor, growth mit Kalenderjahres- bzw. Stichtagsindex, expr mit
# setting-Semantik fuer Codes, quantity mit Bezugsobjekt, auto), Elementknoten (Regel 4),
# Bezuege mit Zyklusschutz, Basisfallwerte ohne Ziehungen und Designwerte (R-70), Attribut
# "annual_before" fuer series_year/points (Vorlauf vor dem Stichtag, 3.6), Typ-Defaults
# (Schicht 0) fuer Bezuege auf nicht gesetzte Komponentenparameter (auch map-Felder).
# Design-Laeufe (11.11) laufen ueber dieselbe Schnittstelle: smp_design() liefert Ziehungen im
# Modus "design" (Zielpfade als replace, Overlay-Schluessel mit ihrer Verknuepfung).

#' Auflösungskontext (intern)
#'
#' @param spec `vofi_spec`.
#' @param grid `vofi_grid`.
#' @param n Anzahl der Läufe.
#' @param draws `NULL` oder `vofi_draws`.
#' @param mode `"deterministic"`, `"mc"` oder `"design"`.
#' @param quiet Meldungen der Auflösung unterdrücken (Laufkontexte; der Basisfall-Vorlauf in
#'   `vofi_build()` meldet sie einmal).
#' @param once Umgebung der bereits gemeldeten Hinweise (je Kontext höchstens einmal je Pfad).
#' @noRd
res_context <- function(spec, grid, n, draws = NULL, mode = "deterministic", quiet = FALSE,
                        once = new.env(parent = emptyenv())) {
  list(spec = spec, grid = grid, n = as.integer(n), draws = draws, mode = mode,
       quiet = isTRUE(quiet), once = once)
}

#' Hinweis höchstens einmal je Kontext und Schlüssel (6.1 Nr. 4, 9.8)
#' @param .once_id Kennung des Hinweises im Kontext.
#' @param .key Label-Schlüssel; `...` sind die Platzhalter (auch `id`, `key`).
#' @noRd
res_inform_once <- function(rc, .once_id, .key, ...) {
  if (isTRUE(rc$quiet) || !is.environment(rc$once)) return(invisible(FALSE))
  if (exists(.once_id, envir = rc$once, inherits = FALSE)) return(invisible(FALSE))
  assign(.once_id, TRUE, envir = rc$once)
  vofi_inform(.key, ...)
  invisible(TRUE)
}

#' Ziehung für einen Zielpfad (6.3 Schritte 1–2)
#' @return n-Vektor (Attribut `"apply"` bei multiply/add), n x (T+1) oder `NULL`.
#' @noRd
res_draw <- function(rc, path) {
  d <- rc$draws
  if (is.null(d) || identical(rc$mode, "deterministic") || is.null(d$targets) ||
        nrow(d$targets) == 0L) {
    return(NULL)
  }
  hit <- which(d$targets$target == path)
  if (length(hit) == 0L) return(NULL)
  key <- d$targets$key[hit[1L]]
  kind <- d$targets$kind[hit[1L]]
  if (identical(kind, "static")) {
    x <- d$static[[key]]
    if (is.null(x)) return(NULL)
    x <- as.double(x)
    ap <- if ("apply" %in% names(d$targets)) d$targets$apply[hit[1L]] else NA_character_
    if (!is.na(ap) && !identical(ap, "replace")) attr(x, "apply") <- ap
    return(x)
  }
  # Entscheidungsschluessel (Rolle decision, 9.11) wirken nicht auf ihr Ziel
  if (identical(kind, "process")) return(d$paths[[key]])
  NULL
}

#' Verknüpfung einer statischen Ziehung mit dem Knotenwert (6.3 Schritt 1, R-94)
#'
#' `apply = multiply`: b * x, `apply = add`: b + x mit b = Knotenwert nach Schritt 3 (Shape von
#' b; x zeilenweise gehoben wie `by_sim()`); Ziele der Art `share` auf `[0, 1]` begrenzt (Hinweis).
#' @noRd
res_apply_draw <- function(rc, x, path, stack, node) {
  ap <- attr(x, "apply")
  attr(x, "apply") <- NULL
  nd <- path_get(rc$spec, path) %||% node %||% res_default_node(rc$spec, path)
  b <- if (is.null(nd)) NULL else res_node(rc, nd, path, FALSE, c(stack, path))
  if (is.null(b) || is.character(b)) {
    vofi_abort("engine.ref_missing", path = path, target = path, .class = "vofi_error_contract")
  }
  if (is.matrix(b)) {
    x <- matrix(rep_len(x, nrow(b)), nrow = nrow(b), ncol = ncol(b))
  } else {
    b <- rep_len(as.double(b), rc$n)
  }
  out <- switch(ap,
    multiply = b * x,
    add = b + x,
    vofi_abort("engine.apply_unknown", path = path, apply = ap, .class = "vofi_error_contract")
  )
  if (identical(res_param_kind(rc, path), "share") && any(out < 0 | out > 1)) {
    res_inform_once(rc, paste0("clamp|", path), "engine.apply_share_clamped", path = path)
    out[] <- pmin(pmax(out, 0), 1)
  }
  out
}

#' Parameterart eines Spec-Pfads (Typschema bzw. Blockschema; Suffix _share als Rückfall)
#' @noRd
res_param_kind <- function(rc, path) {
  segs <- path_split(path)
  kind <- NULL
  if (length(segs) >= 3L && segs[1L] %in% c("components", "financing")) {
    pp <- res_type_param(rc$spec, segs)
    kind <- if (inherits(pp, "vofi_param")) pp$kind else NULL
  } else if (length(segs) == 2L) {
    kind <- tryCatch(val_domain_schema(segs[1L])[[segs[2L]]]$kind, error = function(e) NULL)
  }
  if (is.null(kind) && grepl("_share$", segs[length(segs)])) kind <- "share"
  kind %||% NA_character_
}

#' Parameterschema eines Komponentenpfads `<sammlung>.<id>.<param>[.<feld>...]`
#' @param spec `vofi_spec`.
#' @param segs Pfadsegmente.
#' @return `vofi_param` oder `NULL`.
#' @noRd
res_type_param <- function(spec, segs) {
  if (length(segs) < 3L || !(segs[1L] %in% c("components", "financing"))) return(NULL)
  comp <- spec[[segs[1L]]][[segs[2L]]]
  if (!is.list(comp)) return(NULL)
  def <- tryCatch(scn_type_def(comp[["type"]], segs[1L]), error = function(e) NULL)
  if (is.null(def)) return(NULL)
  pp <- def$params[[segs[3L]]]
  for (sg in segs[-(1:3)]) pp <- if (inherits(pp, "vofi_param")) pp$fields[[sg]] else NULL
  if (inherits(pp, "vofi_param")) pp else NULL
}

#' Typ-Default (Schicht 0) eines nicht gesetzten Komponentenparameters als Knoten
#'
#' Schicht 0 setzt nur Parameter der obersten Ebene; Felder einer fehlenden Map (z. B.
#' `financing.bank.fees.processing_fee_share`) und Parameter ohne gesetzten Wert erhalten hier
#' ihren Default aus dem Parameterschema des Typs.
#' @return Knoten bzw. normalisierter Wert oder `NULL`.
#' @noRd
res_default_node <- function(spec, path) {
  segs <- path_split(path)
  pp <- res_type_param(spec, segs)
  if (is.null(pp) || is.null(pp$default)) return(NULL)
  node_normalize(pp$default, pp, path)
}

#' Wert eines Spec-Pfads auflösen (6.3)
#' @param rc Auflösungskontext.
#' @param path Pfad.
#' @param shape `"scalar"` oder `"path"`.
#' @param base Basisfallwert (ohne Ziehungen und Designwerte, R-70).
#' @param node optional: Knoten, falls er nicht unter `path` in der Spezifikation liegt.
#' @return double n-Vektor bzw. n x (T+1); `NULL`, wenn der Pfad weder Knoten noch Ziehung hat.
#' @noRd
res_value <- function(rc, path, shape = c("scalar", "path"), base = FALSE, node = NULL) {
  shape <- utl_match_arg(shape, c("scalar", "path"), "shape")
  x <- res_path(rc, path, base, character(0), node)
  if (is.null(x)) return(NULL)
  res_shape(rc, x, shape, path)
}

#' Rohwert eines Pfads (Ziehung oder Knoten)
#' @noRd
res_path <- function(rc, path, base, stack, node = NULL) {
  if (path %in% stack) {
    vofi_abort("engine.ref_cycle", path = utl_collapse(c(stack, path), " -> "),
               .class = "vofi_error_contract")
  }
  if (!base) {
    d <- res_draw(rc, path)
    if (!is.null(attr(d, "apply"))) return(res_apply_draw(rc, d, path, stack, node))
    if (!is.null(d)) return(d)
  }
  nd <- path_get(rc$spec, path)
  if (is.null(nd)) nd <- node
  if (is.null(nd)) nd <- res_default_node(rc$spec, path)
  if (is.null(nd)) return(NULL)
  res_node(rc, nd, path, base, c(stack, path))
}

#' Shape-Regel (6.3 Schritt 4)
#' @noRd
res_shape <- function(rc, x, shape, path) {
  n <- rc$n
  n_t <- rc$grid$T + 1L
  if (is.character(x) || inherits(x, "Date")) {
    vofi_abort("engine.not_numeric", path = path, .class = "vofi_error_contract")
  }
  # Laeufe: Skalar bzw. eine Zeile wird recycelt, sonst genau n (keine stille Verkuerzung)
  len_ok <- if (is.matrix(x)) nrow(x) %in% c(1L, n) else length(x) %in% c(1L, n)
  if (!len_ok) {
    vofi_abort("core.contract.length", what = path, expected = n,
               actual = if (is.matrix(x)) nrow(x) else length(x), .class = "vofi_error_contract")
  }
  if (shape == "scalar") {
    if (is.matrix(x)) {
      vofi_abort("engine.scalar_path", path = path, .class = "vofi_error_contract")
    }
    return(as.double(rep_len(x, n)))
  }
  if (is.matrix(x)) {
    if (ncol(x) != n_t) {
      vofi_abort("core.contract.length", what = path, expected = n_t, actual = ncol(x),
                 .class = "vofi_error_contract")
    }
    if (nrow(x) == 1L && n > 1L) {
      at <- attributes(x)
      x2 <- x[rep(1L, n), , drop = FALSE]
      for (a in setdiff(names(at), c("dim", "dimnames"))) attr(x2, a) <- at[[a]]
      x <- x2
    }
    storage.mode(x) <- "double"
    return(x)
  }
  out <- matrix(rep_len(as.double(x), n), nrow = n, ncol = n_t)
  for (a in c("annual_before", "path")) if (!is.null(attr(x, a))) attr(out, a) <- attr(x, a)
  out
}

#' Knoten auswerten (6.3 Schritt 3)
#' @return Skalar, n-Vektor, n x (T+1) oder Codes (Zeichenketten, nur für Ausdrücke).
#' @noRd
res_node <- function(rc, node, path, base, stack) {
  if (io_is_raw_num(node)) node <- node_value(node, path)
  if (is.numeric(node) && !is.list(node)) {
    if (length(node) == 1L) return(as.double(node))
    node <- list(kind = "series_t", values = as.double(node))
  }
  if (is.logical(node) && length(node) == 1L) return(as.double(node))
  if (is.character(node)) return(node)
  if (is.list(node) && !node_is(node)) node <- node_value(node, path)
  switch(node$kind,
    const = as.double(node$value),
    series_t = res_series_t(rc, node, path, base, stack),
    series_year = res_series_year(rc, node, path, base, stack),
    points = res_points(rc, node, path, base, stack),
    schedule = res_schedule(rc, node, path, base, stack),
    ref = res_ref(rc, node, path, base, stack),
    growth = res_growth(rc, node, path, base, stack),
    expr = res_expr(rc, node, path, base, stack),
    quantity = res_quantity(rc, node, path, base, stack),
    auto = NULL,
    dist = vofi_abort("engine.dist_unresolved", path = path, .class = "vofi_error_contract"),
    vofi_abort("engine.node_unknown", path = path, kind = node$kind,
               .class = "vofi_error_contract")
  )
}

#' Skalares Element (Regel 4) als n-Vektor
#' @noRd
res_element <- function(rc, el, path, base, stack) {
  v <- if (is.numeric(el) && !is.list(el)) as.double(el) else res_node(rc, el, path, base, stack)
  if (is.matrix(v) || is.character(v) || is.null(v)) {
    vofi_abort("engine.element_not_scalar", path = path, .class = "vofi_error_contract")
  }
  rep_len(as.double(v), rc$n)
}

#' Elemente als Liste von n-Vektoren
#' @noRd
res_elements <- function(rc, vals, path, base, stack) {
  if (is.numeric(vals)) return(lapply(as.double(vals), function(v) rep_len(v, rc$n)))
  lapply(seq_along(vals), function(i) res_element(rc, vals[[i]], path, base, stack))
}

#' Reihe je Periode (Länge exakt T+1)
#' @noRd
res_series_t <- function(rc, node, path, base, stack) {
  n_t <- rc$grid$T + 1L
  vals <- node$values
  if (length(vals) != n_t) {
    vofi_abort("engine.series_length", path = path, expected = n_t, actual = length(vals),
               .class = "vofi_error_input")
  }
  if (is.numeric(vals)) return(matrix(as.double(vals), nrow = rc$n, ncol = n_t, byrow = TRUE))
  els <- res_elements(rc, vals, path, base, stack)
  do.call(cbind, els)
}

#' Jahreswerte auf beliebige Jahre abbilden (series_year: fill/before; points: interpolate)
#' @param years gegebene Jahre (sortiert).
#' @param els Liste von n-Vektoren.
#' @param target Zieljahre.
#' @param mode `"locf"`, `"zero"`, `"linear"` (series_year) bzw. `"step"`, `"linear"` (points).
#' @param before `"first"` oder `"zero"`.
#' @return n x length(target).
#' @noRd
res_year_values <- function(years, els, target, mode, before, n) {
  out <- matrix(0, n, length(target))
  k <- length(years)
  for (c in seq_along(target)) {
    y <- target[c]
    if (y < years[1L]) {
      out[, c] <- if (identical(before, "zero")) 0 else els[[1L]]
    } else if (y >= years[k]) {
      out[, c] <- if (y == years[k] || !identical(mode, "zero")) els[[k]] else 0
    } else {
      i <- max(which(years <= y))
      if (years[i] == y) {
        out[, c] <- els[[i]]
      } else if (identical(mode, "linear")) {
        w <- (y - years[i]) / (years[i + 1L] - years[i])
        out[, c] <- els[[i]] + w * (els[[i + 1L]] - els[[i]])
      } else if (identical(mode, "zero")) {
        out[, c] <- 0
      } else {
        out[, c] <- els[[i]]
      }
    }
  }
  out
}

#' Pfad aus Jahreswerten (Spalte j = Wert des Jahres `year[j]`) mit Attribut `annual_before`
#' @noRd
res_annual_path <- function(rc, years, els, mode, before) {
  g <- rc$grid
  path <- res_year_values(years, els, g$year, mode, before, rc$n)
  y0 <- utl_year(g$valuation_date)
  if (years[1L] < y0) {
    yb <- seq.int(years[1L], y0 - 1L)
    ab <- res_year_values(years, els, yb, mode, before, rc$n)
    colnames(ab) <- as.character(yb)
    attr(path, "annual_before") <- ab
  }
  path
}

#' Reihe je Kalenderjahr
#' @noRd
res_series_year <- function(rc, node, path, base, stack) {
  els <- res_elements(rc, node$values, path, base, stack)
  out <- res_annual_path(rc, node$years, els, node$fill %||% "locf", node$before %||% "first")
  attr(out, "path") <- path
  out
}

#' Stützstellen (linear bzw. step über Kalenderjahre, außerhalb konstant)
#' @noRd
res_points <- function(rc, node, path, base, stack) {
  els <- res_elements(rc, node$values, path, base, stack)
  mode <- if (identical(node$interpolate, "step")) "locf" else "linear"
  out <- res_annual_path(rc, node$years, els, mode, "first")
  attr(out, "path") <- path
  out
}

#' Zahlungsplan: Betrag in der Periode grid_period_of(date) (3.4, R-98)
#'
#' Termine vor dem Stichtag sind ein Eingabefehler; Termine nach dem Horizontende entfallen
#' (Hinweis höchstens einmal je Pfad und Kontext). Die Beträge dürfen selbst Knoten sein
#' (Regel 4); `unit: share` liefert die Anteile, den Gesamtbetrag bestimmt der Typ (R-119).
#' @noRd
res_schedule <- function(rc, node, path, base, stack) {
  g <- rc$grid
  out <- matrix(0, rc$n, g$T + 1L)
  if (length(node$dates) == 0L) return(out)
  els <- res_elements(rc, node$amounts, path, base, stack)
  p <- grid_period_of(g, node$dates)
  before <- attr(p, "before")
  if (any(before)) {
    vofi_abort("engine.schedule_before", path = path,
               date = node$dates[which(before)[1L]], .class = "vofi_error_input")
  }
  for (i in seq_along(els)) {
    if (is.na(p[i])) {
      res_inform_once(rc, paste0("after|", path, "|", format(node$dates[i])),
                      "engine.schedule_after", path = path, date = node$dates[i])
      next
    }
    out[, p[i] + 1L] <- out[, p[i] + 1L] + els[[i]]
  }
  out
}

#' Bezug mit scale/offset/floor/cap bzw. anchor
#' @noRd
res_ref <- function(rc, node, path, base, stack) {
  x <- res_path(rc, node$path, base, stack)
  if (is.null(x)) {
    vofi_abort("engine.ref_missing", path = path, target = node$path,
               .class = "vofi_error_contract")
  }
  if (is.character(x)) return(x)
  ab <- attr(x, "annual_before")
  scale <- node$scale %||% 1
  offset <- node$offset %||% 0
  floor <- node$floor %||% -Inf
  cap <- node$cap %||% Inf
  if (!is.null(node$anchor)) {
    x0 <- if (is.matrix(x)) x[, 1L] else x
    y <- node$anchor + scale * (x - x0) + offset
  } else {
    y <- x * scale + offset
  }
  if (is.finite(floor) || is.finite(cap)) {
    dims <- dim(y)
    y <- pmin(pmax(y, floor), cap)
    if (!is.null(dims)) dim(y) <- dims
  }
  if (!is.null(ab) && is.matrix(y)) {
    ab_y <- if (!is.null(node$anchor)) ab else ab * scale + offset
    attr(y, "annual_before") <- ab_y
  }
  attr(y, "path") <- node$path
  y
}

#' Preisbasis (Stichtag des Preisstands): 1. Januar nach project.price_base_year (R-35)
#' @noRd
res_price_base_date <- function(rc) {
  pby <- rc$spec$project$price_base_year
  if (node_is(pby)) pby <- pby$value
  if (is.null(pby) || !is.numeric(pby)) pby <- utl_year(rc$grid$valuation_date) - 1L
  as.Date(sprintf("%04d-01-01", as.integer(pby) + 1L))
}

#' Wachstum (4.5, R-91): `index: calendar_year` (Default) -> start * grid_index_year(growth,
#' base_date) (Kalenderjahreswert, je Kalenderjahr konstant); `index: period_end` ->
#' start * grid_index(growth, base_date) (Stichtagswert zum Periodenende, z. B. Marktwertpfad)
#' @noRd
res_growth <- function(rc, node, path, base, stack) {
  start <- res_element(rc, node$start, path_join(path, "start"), base, stack)
  g <- res_node(rc, node$growth, path_join(path, "growth"), base, stack)
  if (is.null(g) || is.character(g)) {
    vofi_abort("engine.not_numeric", path = path_join(path, "growth"),
               .class = "vofi_error_contract")
  }
  g <- res_shape(rc, g, "path", path_join(path, "growth"))
  if (isTRUE(node$real)) {
    pi_path <- res_path(rc, "market.inflation", base, stack)
    if (is.null(pi_path)) {
      vofi_abort("engine.ref_missing", path = path, target = "market.inflation",
                 .class = "vofi_error_contract")
    }
    ab <- attr(g, "annual_before")
    g <- (1 + g) * (1 + res_shape(rc, pi_path, "path", "market.inflation")) - 1
    if (!is.null(ab)) attr(g, "annual_before") <- ab
  }
  bd <- node$base_date %||% res_price_base_date(rc)
  if (identical(node$index, "period_end")) return(start * grid_index(rc$grid, g, bd))
  start * grid_index_year(rc$grid, g, bd)
}

#' Ausdruck (4.5 Regel 5)
#'
#' Pfadsymbole auf deterministische nicht-numerische Blätter (Codes, Code-Listen, Wahrheitswerte)
#' werden mit der Semantik von `ctx$setting()` als Zeichen- bzw. Wahrheitswerte übergeben (R-91);
#' die Zulässigkeit der Operationen prüft `expr_eval()`.
#' @noRd
res_expr <- function(rc, node, path, base, stack) {
  resolve <- function(p) {
    raw <- path_get(rc$spec, p)
    if (is.character(raw) || is.logical(raw)) return(raw)
    v <- res_path(rc, p, base, stack)
    if (is.null(v)) {
      vofi_abort("engine.ref_missing", path = path, target = p, .class = "vofi_error_contract")
    }
    v
  }
  ast <- node$ast %||% expr_parse(node$text)
  expr_eval(ast, resolve, rc$n, rc$grid$T)
}

#' Feld der Bezugsgröße eines Mengenbezugs (4.5, R-91)
#' @noRd
res_quantity_field <- function(per) {
  if (startsWith(per, "m2_component:")) {
    return(paste0("component_areas_m2.", sub("^m2_component:", "", per)))
  }
  switch(per,
    unit = "n_units",
    m2_living_area = "living_area_m2",
    m2_net_floor_area = "net_floor_area_m2",
    parking = "n_parking",
    per
  )
}

#' Pfad der Bezugsgröße eines Mengenbezugs (Spec 01 Teil A 3.5)
#'
#' Bezugsobjekt ist das nächste Objekt, in dem der Knoten steht (vom Knoten aufwärts: z. B.
#' `measures.<m>`, `unit_groups.<g>`, `building.elements.<e>` bzw. die Komponente); danach
#' `building`. `kw`, `kwp` und `kwh` haben keinen Rückfall auf `building`.
#' @return Pfad oder `NULL`.
#' @noRd
res_quantity_target <- function(spec, path, per) {
  field <- res_quantity_field(per)
  segs <- path_split(path)
  k <- length(segs) - 1L
  while (k >= 1L) {
    cand <- path_join(paste(segs[seq_len(k)], collapse = "."), field)
    if (!is.null(path_get(spec, cand))) return(cand)
    k <- k - 1L
  }
  if (per %in% c("kw", "kwp", "kwh")) return(NULL)
  fb <- paste0("building.", field)
  if (!is.null(path_get(spec, fb))) fb else NULL
}

#' Mengenbezug: value * Bezugsgröße (4.5, R-91)
#'
#' `value` darf jede skalare oder zeitabhängige Wertform sein; die Bezugsgröße ist ein
#' deterministisches Blatt (Bezugsobjekt nach `res_quantity_target()`).
#' @noRd
res_quantity <- function(rc, node, path, base, stack) {
  per <- node$per
  v <- res_node(rc, node$value, path, base, stack)
  if (is.null(v) || is.character(v)) {
    vofi_abort("engine.not_numeric", path = path, .class = "vofi_error_contract")
  }
  if (identical(per, "total")) return(v)
  target <- res_quantity_target(rc$spec, path, per)
  if (is.null(target)) {
    vofi_abort("engine.ref_missing", path = path,
               target = paste0("<", res_quantity_field(per), ">"),
               .class = "vofi_error_contract")
  }
  q <- res_path(rc, target, base, stack)
  if (is.null(q) || is.character(q)) {
    vofi_abort("engine.ref_missing", path = path, target = target,
               .class = "vofi_error_contract")
  }
  if (is.matrix(q) && !is.matrix(v)) {
    v <- matrix(rep_len(as.double(v), nrow(q)), nrow(q), ncol(q))
  } else if (is.matrix(v) && !is.matrix(q)) {
    q <- rep_len(as.double(q), nrow(v))
  }
  if (!is.matrix(v)) v <- rep_len(as.double(v), max(length(v), length(q)))
  v * q
}
