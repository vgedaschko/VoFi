# Wertgrammatik -> Knoten (WS-A, Spec 00 Abschnitte 4.5, 4.6, 6.4).
# Umgesetzt: alle Wertformen aus 4.5 als Knoten (const, series_t, series_year, points, schedule,
# ref, growth, expr, quantity, auto/topup, Kurzform-Verteilung als Markierungsknoten "dist"),
# Knoten als Elemente (Regel 4: nur skalare Knoten const/ref/expr), die nicht-numerischen
# Parameterarten aus 5.4 und die Zahlenregeln aus 4.6 (Dezimalkomma, Tausenderpunkt,
# Prozentzeichen, Raten > 1). Bibliotheksverweise `from:` bleiben Rohform und werden in Schicht 3
# aufgeloest (R/scenario-library.R). Die Normalisierung ist idempotent und vervollstaendigt auch
# Knoten, in die eine Teil-Map ohne Wertform gemischt wurde (z. B. `{growth: ...}` in eine
# Wachstumsform, 4.7). Knotenkonstruktoren fuer bctx (6.4): node_const, node_ref, node_schedule,
# node_growth, node_expr. Umkehrung fuer das Schreiben: node_to_yaml().

#' Knotenarten der Wertgrammatik (4.5)
#' @noRd
node_kinds <- function() {
  c("const", "series_t", "series_year", "points", "schedule", "ref", "growth", "expr",
    "quantity", "auto", "dist")
}

#' Knotenarten, die als Elemente von `values`/`series` zulässig sind (4.5 Regel 4)
#' @noRd
node_scalar_kinds <- function() c("const", "ref", "expr")

#' Ist `x` ein normalisierter Knoten (`list(kind = ...)`)?
#' @noRd
node_is <- function(x) {
  is.list(x) && !is.data.frame(x) && !io_is_raw_num(x) && utl_has_name(x, "kind") &&
    utl_is_string(x[["kind"]]) && x[["kind"]] %in% node_kinds()
}

#' Rohwert der Wertgrammatik in einen Knoten überführen (Spec 00, Abschnitte 4.5, 4.6)
#'
#' Vertrag (vom Prüfkit vorausgesetzt): numerische Arten (`number`, `amount`, `rate`, `share`,
#' `value`, `schedule`; `param = NULL` = allgemeine Wertgrammatik) liefern einen Knoten
#' `list(kind = ...)` (Zahl -> `const`, Vektor -> `series_t`, Maps nach 4.5); nicht-numerische
#' Arten den normalisierten Wert (`Date`, chr, lgl, int); `map` eine Liste der normalisierten
#' Felder. Numerische Blätter werden als double gespeichert. Die Funktion ist idempotent:
#' bereits normalisierte Knoten und Werte bleiben unverändert.
#' @param x Rohwert (YAML-Form).
#' @param param `NULL` oder `vofi_param` des Ziels.
#' @param path Pfad für Meldungen.
#' @return Knoten bzw. normalisierter Wert.
#' @noRd
node_normalize <- function(x, param = NULL, path = NULL) {
  path <- path %||% ""
  if (is.null(x)) return(NULL)
  kind <- if (is.null(param)) "value" else param$kind
  if (kind %in% c("number", "amount", "rate", "share", "value", "schedule")) {
    unit <- param$unit
    eur <- identical(kind, "amount") || (utl_is_string(unit) && startsWith(unit, "EUR")) ||
      io_path_is_eur(path)
    node <- node_value(x, path, eur = eur, allow_auto = isTRUE(param$allow_auto))
    node_check_rate(node, kind, path, eur, unit = unit)
    return(node)
  }
  switch(kind,
    integer = node_integer(x, path),
    logical = node_logical(x, path),
    date = node_date(x, path),
    timing = node_timing(x, path),
    enum = node_enum(x, param, path),
    string = node_string(x, path),
    ref = node_string(x, path),
    ids = node_ids(x, path),
    map = node_map(x, param, path),
    x
  )
}

#' Knoten der allgemeinen Wertgrammatik (4.5)
#' @noRd
node_value <- function(x, path, eur = FALSE, allow_auto = FALSE) {
  if (node_is(x)) return(node_tidy(x, path, eur))
  if (io_is_raw_num(x) || (is.numeric(x) && length(x) == 1L)) {
    return(node_const(node_number(x, path, eur)))
  }
  if (utl_is_string(x)) {
    if (x %in% c("auto", "topup")) {
      if (!allow_auto) {
        vofi_abort("io.auto_not_allowed", path = path, value = x, .class = "vofi_error_input")
      }
      return(list(kind = "auto", mode = x))
    }
    return(node_const(node_number(x, path, eur)))
  }
  if (is.logical(x) && length(x) == 1L && !is.na(x)) {
    vofi_abort("io.not_number", path = path, raw = format(x), .class = "vofi_error_input")
  }
  if (is.numeric(x) && length(x) > 1L) {
    return(list(kind = "series_t", values = node_elements(as.list(x), path, eur)))
  }
  if (is.list(x) && !is_map(x)) {
    return(list(kind = "series_t", values = node_elements(x, path, eur)))
  }
  if (is_map(x)) {
    form <- utl_value_form_kind(x)
    if (is.na(form)) {
      vofi_abort("io.value_form_unknown", path = path,
                 keys = utl_collapse(names(x)), .class = "vofi_error_input")
    }
    return(switch(form,
      ref = node_ref_raw(x, path),
      expr = node_expr_raw(x, path),
      series_year = node_series_year_raw(x, path, eur),
      points = node_points_raw(x, path, eur),
      schedule = node_schedule_raw(x, path, eur),
      growth = node_growth_raw(x, path, eur),
      quantity = list(kind = "quantity", value = node_quantity_value(x[["value"]], path, eur),
                      per = node_quantity_per(x[["per"]], path_join(path, "per"))),
      dist = node_dist_raw(x, path),
      from = x
    ))
  }
  vofi_abort("io.not_number", path = path, raw = utl_collapse(format(x)),
             .class = "vofi_error_input")
}

#' Bereits normalisierten Knoten vervollständigen (Idempotenz)
#'
#' Numerische Felder werden double; Kindknoten, die nach dem Mischen einer Teil-Map (4.7) noch
#' Rohform haben, werden normalisiert.
#' @noRd
node_tidy <- function(x, path, eur) {
  switch(x$kind,
    const = node_const(node_number(x$value, path, eur)),
    series_t = {
      x$values <- node_elements(if (is.list(x$values)) x$values else as.list(x$values), path,
                                eur)
      x
    },
    series_year = {
      if (!is.integer(x$years)) x$years <- as.integer(x$years)
      x$values <- node_elements(if (is.list(x$values)) x$values else as.list(x$values),
                                path_join(path, "series"), eur)
      x$fill <- x$fill %||% "locf"
      x$before <- x$before %||% "first"
      x
    },
    points = {
      if (!is.integer(x$years)) x$years <- as.integer(x$years)
      x$values <- node_elements(if (is.list(x$values)) x$values else as.list(x$values),
                                path_join(path, "values"), eur)
      x$interpolate <- x$interpolate %||% "linear"
      x
    },
    schedule = {
      if (!inherits(x$dates, "Date")) {
        x$dates <- do.call(c, lapply(as.list(x$dates), function(d) node_timing(d, path)))
      }
      is_eur <- eur && !identical(x$unit, "share")
      x$amounts <- node_elements(if (is.list(x$amounts)) x$amounts else as.list(x$amounts),
                                 path_join(path, "schedule"), is_eur, node_schedule_kinds())
      x
    },
    ref = {
      num <- function(v, d) if (is.null(v)) d else node_number(v, path)
      x$path <- node_string(x$path, path_join(path, "ref"))
      x$scale <- num(x$scale, 1)
      x$offset <- num(x$offset, 0)
      x$floor <- num(x$floor, -Inf)
      x$cap <- num(x$cap, Inf)
      if (!is.null(x$anchor)) x$anchor <- node_number(x$anchor, path_join(path, "anchor"))
      x
    },
    growth = {
      x$start <- node_scalar_node(x$start, path_join(path, "start"), eur)
      x$growth <- node_growth_rate(x$growth, path_join(path, "growth"))
      if (!is.null(x$base_date) && !inherits(x$base_date, "Date")) {
        x$base_date <- node_timing(x$base_date, path_join(path, "base_date"))
      }
      x$real <- if (is.null(x$real)) FALSE else node_logical(x$real, path_join(path, "real"))
      x$index <- x$index %||% "calendar_year"
      x
    },
    expr = {
      if (!inherits(x$ast, "vofi_expr")) x <- node_expr(node_string(x$text, path))
      x
    },
    quantity = {
      x$value <- node_quantity_value(x$value, path, eur)
      x$per <- node_quantity_per(x$per, path_join(path, "per"))
      x
    },
    x
  )
}

#' Zahl aus Rohwert (Fehler, wenn keine Zahl)
#' @noRd
node_number <- function(x, path, eur = FALSE) {
  v <- io_as_number(x, path, eur)
  if (is.null(v) || length(v) != 1L || is.na(v)) {
    raw <- if (io_is_raw_num(x)) x[[1L]] else utl_collapse(format(x))
    vofi_abort("io.not_number", path = path, raw = raw, .class = "vofi_error_input")
  }
  as.double(v)
}

#' Skalares Element (Zahl oder skalarer Knoten, Regel 4)
#'
#' Elemente von `series_t`, `points` und `series_year` sind Zahlen oder die skalaren Knoten
#' `const`, `ref`, `expr` (4.5 Regel 4); Beträge eines Zahlungsplans dürfen zusätzlich ein
#' Mengenbezug sein (4.5 "Beträge dürfen selbst value sein", Spec 01 Teil A 4.6.1). Eine
#' Kurzform-Verteilung als Betrag eines Zahlungsplans ist `io.schedule_amount_form` (bei
#' Maßnahmen der Schlüssel `validation.measures.schedule_amount_form`, X-28).
#' @param allow zulässige Knotenarten.
#' @noRd
node_scalar <- function(x, path, eur = FALSE, allow = node_scalar_kinds()) {
  if (io_is_raw_num(x) || is.numeric(x) || utl_is_string(x)) {
    return(node_number(x, path, eur))
  }
  node <- node_value(x, path, eur)
  if (!(node$kind %in% allow)) {
    if ("quantity" %in% allow) {
      primary <- if (startsWith(path, "measures.")) {
        "validation.measures.schedule_amount_form"
      } else {
        "io.schedule_amount_form"
      }
      scn_signal("abort", primary, "io.schedule_amount_form", path = path, kind = node$kind,
                 form = node$kind, .class = "vofi_error_validation")
    }
    vofi_abort("io.element_not_scalar", path = path, kind = node$kind,
               .class = "vofi_error_input")
  }
  node
}

#' Skalares Element als Knoten (Zahl -> const)
#' @noRd
node_scalar_node <- function(x, path, eur = FALSE) {
  v <- node_scalar(x, path, eur)
  if (is.numeric(v)) node_const(v) else v
}

#' Elemente von series_t/points/series_year bzw. Beträge eines Zahlungsplans: double-Vektor
#' oder Liste skalarer Knoten
#' @param allow zulässige Knotenarten (`node_scalar()`).
#' @noRd
node_elements <- function(x, path, eur = FALSE, allow = node_scalar_kinds()) {
  out <- lapply(seq_along(x), function(i) node_scalar(x[[i]], path_join(path, i), eur, allow))
  if (all(vapply(out, function(e) is.numeric(e) && length(e) == 1L, logical(1)))) {
    return(as.double(unlist(out)))
  }
  lapply(out, function(e) if (is.numeric(e)) node_const(e) else e)
}

#' Zulässige Knotenarten der Beträge eines Zahlungsplans
#' @noRd
node_schedule_kinds <- function() c(node_scalar_kinds(), "quantity")

#' Wert eines Mengenbezugs `{value: x, per}`: jede skalare oder zeitabhängige Wertform außer
#' Mengenbezug, Verteilung und `auto` (Spec 01 Teil A 3.5, Prüffall Q6)
#' @noRd
node_quantity_value <- function(x, path, eur = FALSE) {
  if (io_is_raw_num(x) || is.numeric(x) && length(x) == 1L || utl_is_string(x)) {
    return(node_number(x, path, eur))
  }
  node <- node_value(x, path, eur)
  if (node$kind %in% c("quantity", "dist", "auto")) {
    vofi_abort("io.element_not_scalar", path = path, kind = node$kind,
               .class = "vofi_error_input")
  }
  node
}

#' Raten und Anteile > 1 sind ein Eingabefehler (4.6)
#'
#' Maßgeblich ist zuerst die Parameterart: `rate` und `share` sind Raten, `amount` und
#' EUR-Beträge (Einheit `EUR*`, Schlüsselsegment `_eur`) nie. Nennt das Schema eine Einheit,
#' entscheidet sie (`rate_pa`, `rate`, `share` sind Raten; `kWh_pa`, `EUR_pa`, `m2` usw. nicht).
#' Ohne Art und Einheit gilt das Schlüsselsuffix `_pa`/`_share` (4.6), außer wenn davor ein
#' Einheitensegment steht (`kwh_pa`, `quantity_kwh_pa`, `maintenance_eur_m2_pa`; Mengen und
#' Beträge je Jahr sind keine Raten).
#' @param unit `NULL` oder Einheit des Parameterschemas.
#' @noRd
node_check_rate <- function(node, kind, path, eur = FALSE, unit = NULL) {
  if (!node_is_rate_target(kind, path, eur, unit) || !is.list(node)) return(invisible(TRUE))
  vals <- if (identical(node$kind, "const")) {
    node$value
  } else if (node$kind %in% c("series_t", "series_year", "points") && is.numeric(node$values)) {
    node$values
  } else {
    numeric(0)
  }
  bad <- vals[is.finite(vals) & abs(vals) > 1]
  if (length(bad) > 0L) {
    vofi_abort("io.rate_above_one", path = path, value = bad[1L], suggestion = bad[1L] / 100,
               .class = "vofi_error_input")
  }
  invisible(TRUE)
}

#' Ist das Ziel eine Rate bzw. ein Anteil (Prüfung > 1 nach 4.6)?
#' @inheritParams node_check_rate
#' @return `TRUE`/`FALSE`.
#' @noRd
node_is_rate_target <- function(kind, path, eur = FALSE, unit = NULL) {
  if (kind %in% c("rate", "share")) return(TRUE)
  if (isTRUE(eur) || identical(kind, "amount")) return(FALSE)
  if (utl_is_string(unit) && nzchar(unit)) return(unit %in% node_rate_units())
  segs <- path_split(path)
  segs <- segs[!grepl("^[0-9]+$", segs)]
  last <- if (length(segs) > 0L) segs[length(segs)] else ""
  if (!grepl("(_pa|_share)$", last)) return(FALSE)
  stem <- strsplit(sub("(_pa|_share)$", "", last), "_", fixed = TRUE)[[1L]]
  !any(stem %in% node_unit_tokens())
}

#' Einheiten des Parameterschemas, die Raten bzw. Anteile bezeichnen (4.6)
#' @noRd
node_rate_units <- function() c("rate_pa", "rate", "share", "share_pa")

#' Einheitensegmente in Schlüsseln, vor denen `_pa` keine Rate bezeichnet (4.6)
#' @noRd
node_unit_tokens <- function() {
  c("eur", "ct", "kwh", "mwh", "kw", "kwp", "kg", "t", "m2", "m3", "l")
}

#' Mengenbezug `per` prüfen: Code aus `quantity_per`, Bauteilcode bei `m2_component:<b>`
#' (4.5, Spec 01 Teil A 3.1.1, 3.5)
#' @noRd
node_quantity_per <- function(x, path) {
  per <- node_string(x, path)
  ok <- vocab_has("quantity_per", per)
  if (ok && startsWith(per, "m2_component:")) {
    ok <- vocab_has("component_area", sub("^m2_component:", "", per))
  }
  if (!isTRUE(ok)) {
    vofi_abort("io.quantity_per_unknown", path = path, per = per,
               suggestion = utl_suggest_text(per, vocab_codes("quantity_per")),
               .class = "vofi_error_input")
  }
  per
}

#' Bezug {ref, scale, offset, floor, cap, anchor}
#' @noRd
node_ref_raw <- function(x, path) {
  num <- function(f, default) {
    if (is.null(x[[f]])) default else node_number(x[[f]], path_join(path, f))
  }
  node <- node_ref(node_string(x[["ref"]], path_join(path, "ref")), scale = num("scale", 1),
                   offset = num("offset", 0), floor = num("floor", -Inf), cap = num("cap", Inf))
  if (!is.null(x[["anchor"]])) node$anchor <- node_number(x[["anchor"]], path_join(path, "anchor"))
  node
}

#' Ausdruck {expr}
#' @noRd
node_expr_raw <- function(x, path) {
  node_expr(node_string(x[["expr"]], path_join(path, "expr")))
}

#' Reihe je Kalenderjahr {series: {Jahr: Wert}, fill, before}
#' @noRd
node_series_year_raw <- function(x, path, eur) {
  s <- x[["series"]]
  if (!is_map(s) || length(s) == 0L) {
    vofi_abort("io.series_year_invalid", path = path, .class = "vofi_error_input")
  }
  years <- suppressWarnings(as.integer(names(s)))
  if (anyNA(years)) {
    vofi_abort("io.series_year_invalid", path = path, .class = "vofi_error_input")
  }
  ord <- order(years)
  list(kind = "series_year", years = years[ord],
       values = node_elements(unname(s)[ord], path_join(path, "series"), eur),
       fill = node_enum(x[["fill"]] %||% "locf", vofi_param("enum", values = "vocab:series_fill"),
                        path_join(path, "fill")),
       before = node_enum(x[["before"]] %||% "first",
                          vofi_param("enum", values = "vocab:series_before"),
                          path_join(path, "before")))
}

#' Stützstellen {years, values, interpolate}
#' @noRd
node_points_raw <- function(x, path, eur) {
  years <- as.integer(vapply(as.list(x[["years"]]), function(y) {
    node_number(y, path_join(path, "years"))
  }, double(1)))
  vals <- as.list(x[["values"]])
  if (length(years) != length(vals) || length(years) == 0L) {
    vofi_abort("io.points_invalid", path = path, .class = "vofi_error_input")
  }
  ord <- order(years)
  list(kind = "points", years = years[ord],
       values = node_elements(vals[ord], path_join(path, "values"), eur),
       interpolate = node_enum(x[["interpolate"]] %||% "linear",
                               vofi_param("enum", values = "vocab:interpolate"),
                               path_join(path, "interpolate")))
}

#' Zahlungsplan {schedule: {Datum|Jahr: Betrag}, unit}
#' @noRd
node_schedule_raw <- function(x, path, eur) {
  s <- x[["schedule"]]
  if (!is_map(s) || length(s) == 0L) {
    vofi_abort("io.schedule_invalid", path = path, .class = "vofi_error_input")
  }
  dates <- do.call(c, lapply(names(s), function(k) node_timing(k, path_join(path, "schedule"))))
  unit <- if (is.null(x[["unit"]])) NULL else node_enum(x[["unit"]],
                                                        vofi_param("enum",
                                                                   values = "vocab:schedule_unit"),
                                                        path_join(path, "unit"))
  is_eur <- eur && !identical(unit, "share")
  node <- node_schedule(dates, node_elements(unname(s), path_join(path, "schedule"), is_eur,
                                             node_schedule_kinds()))
  node$unit <- unit
  node
}

#' Wachstum {start, growth, base_date, real, index}
#'
#' Die Rate `growth` ist eine Jahresrate; Werte über 1 sind zulässig (Krisenjahr mit
#' Verdopplung, Set `stress_2022`, Spec 01 Teil C §4.2), eine konstante Rate ≤ −1 nicht (der
#' Index würde null bzw. negativ).
#' @noRd
node_growth_raw <- function(x, path, eur) {
  bd <- if (is.null(x[["base_date"]])) NULL else node_timing(x[["base_date"]],
                                                             path_join(path, "base_date"))
  idx <- node_enum(x[["index"]] %||% vocab("growth_index")$default,
                   vofi_param("enum", values = "vocab:growth_index"), path_join(path, "index"))
  if (!vocab_has("growth_index", idx)) {
    vofi_abort("io.growth_index_invalid", path = path_join(path, "index"), value = idx,
               .class = "vofi_error_input")
  }
  node <- node_growth(node_scalar_node(x[["start"]], path_join(path, "start"), eur),
                      node_growth_rate(x[["growth"]], path_join(path, "growth")),
                      base_date = bd, index = idx)
  node$real <- if (is.null(x[["real"]])) FALSE else node_logical(x[["real"]],
                                                                 path_join(path, "real"))
  node
}

#' Rate einer Wachstumsform: skalarer Knoten oder Pfadform (series_year, points, series_t)
#' @noRd
node_growth_rate <- function(x, path) {
  g <- if (io_is_raw_num(x) || is.numeric(x) || utl_is_string(x)) {
    node_const(node_number(x, path))
  } else {
    node_value(x, path)
  }
  if (identical(g$kind, "const") && is.finite(g$value) && g$value <= -1) {
    vofi_abort("io.growth_rate_invalid", path = path, value = g$value,
               .class = "vofi_error_input")
  }
  g
}

#' Kurzform-Verteilung {dist, base, <Parameter>} als Markierungsknoten
#'
#' Die Szenario-Normalisierung verschiebt sie ins Overlay (Schlüssel = Zielpfad) und setzt am
#' Ort den Basiswert als `const` (4.5, Regel 1).
#' @noRd
node_dist_raw <- function(x, path) {
  par <- x[setdiff(names(x), c("dist", "base", "label"))]
  par <- lapply(stats::setNames(names(par), names(par)), function(nm) {
    v <- par[[nm]]
    if (io_is_raw_num(v) || (is.numeric(v) && length(v) == 1L)) node_number(v, path_join(path, nm))
    else io_unmark(v, path_join(path, nm))
  })
  list(kind = "dist", dist = node_string(x[["dist"]], path_join(path, "dist")), par = par,
       base = if (is.null(x[["base"]])) NULL else node_number(x[["base"]],
                                                              path_join(path, "base")),
       label = x[["label"]])
}

#' Ganze Zahl (Art integer)
#' @noRd
node_integer <- function(x, path) {
  if (is.integer(x) && length(x) == 1L) return(x)
  if (node_is(x) && identical(x$kind, "const")) return(node_integer(x$value, path))
  if (is.numeric(x) && length(x) > 1L) {
    return(as.integer(vapply(x, function(e) node_integer(e, path), integer(1))))
  }
  if (is.list(x) && !is_map(x) && !io_is_raw_num(x)) {
    return(as.integer(vapply(x, function(e) node_integer(e, path), integer(1))))
  }
  v <- node_number(x, path)
  if (!utl_is_whole(v) || abs(v) > .Machine$integer.max) {
    vofi_abort("io.not_integer", path = path, value = v, .class = "vofi_error_input")
  }
  as.integer(round(v))
}

#' Logischer Wert (ja/nein, yes/no, true/false, on/off nur bei Schema lgl)
#' @noRd
node_logical <- function(x, path) {
  if (is.logical(x) && length(x) == 1L && !is.na(x)) return(x)
  if (utl_is_string(x)) {
    s <- tolower(trimws(x))
    if (s %in% c("true", "yes", "ja", "on", "y", "wahr")) return(TRUE)
    if (s %in% c("false", "no", "nein", "off", "n", "falsch")) return(FALSE)
  }
  if (is.numeric(x) && length(x) == 1L && x %in% c(0, 1)) return(as.logical(x))
  vofi_abort("io.not_logical", path = path, raw = utl_collapse(format(x)),
             .class = "vofi_error_input")
}

#' Datum (Art date)
#' @noRd
node_date <- function(x, path) {
  if (inherits(x, "Date") && length(x) == 1L && !is.na(x)) return(x)
  if (utl_is_string(x)) {
    d <- as.Date(x, format = "%Y-%m-%d", optional = TRUE)
    if (!is.na(d) && grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", trimws(x))) return(d)
  }
  vofi_abort("core.date_invalid", arg = path, value = utl_collapse(format(x)),
             .class = "vofi_error_input")
}

#' Termin (Art timing): Datum, Jahr Y (= Y-01-01, 3.4) oder Token `completion` (3.9)
#' @noRd
node_timing <- function(x, path) {
  if (inherits(x, "Date") && length(x) == 1L && !is.na(x)) return(x)
  if (identical(x, "completion")) return("completion")
  if (node_is(x) && identical(x$kind, "const")) return(node_timing(x$value, path))
  if (is_map(x) && length(x) == 1L && names(x) %in% c("date", "year")) {
    return(node_timing(x[[1L]], path))
  }
  if (utl_is_string(x) && grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", trimws(x))) {
    return(node_date(trimws(x), path))
  }
  y <- if (io_is_raw_num(x) || is.numeric(x) || utl_is_string(x)) {
    suppressWarnings(tryCatch(io_as_number(x, path), error = function(e) NULL))
  } else {
    NULL
  }
  if (!is.null(y) && utl_is_whole(y) && y >= 1000 && y <= 9999) {
    return(as.Date(sprintf("%04d-01-01", as.integer(y))))
  }
  vofi_abort("io.timing_invalid", path = path, value = utl_collapse(format(x)),
             .class = "vofi_error_input")
}

#' Code (Art enum); Aliase werden kanonisiert, unbekannte Codes meldet die Validierung
#' @noRd
node_enum <- function(x, param, path) {
  if (is.null(x)) return(NULL)
  s <- if (is.logical(x) && length(x) == 1L && !is.na(x)) tolower(as.character(x)) else
    node_string(x, path)
  vals <- param$values
  if (length(vals) == 1L && startsWith(vals, "vocab:")) {
    spec <- tryCatch(utl_vocab_spec(vals), error = function(e) NULL)
    if (!is.null(spec) && s %in% names(spec$aliases)) {
      return(vocab_resolve(vals, s, path))
    }
  }
  s
}

#' Zeichenkette (Arten string, ref)
#' @noRd
node_string <- function(x, path) {
  if (utl_is_string(x)) return(enc2utf8(x))
  if (io_is_raw_num(x)) return(x[[1L]])
  if (is.numeric(x) && length(x) == 1L) return(format(x, scientific = FALSE, trim = TRUE))
  if (is.logical(x) && length(x) == 1L && !is.na(x)) return(tolower(as.character(x)))
  vofi_abort("io.not_string", path = path, raw = utl_collapse(format(x)),
             .class = "vofi_error_input")
}

#' Liste von ids bzw. Codes (Art ids)
#' @noRd
node_ids <- function(x, path) {
  if (is.null(x) || length(x) == 0L) return(character(0))
  as.character(vapply(as.list(x), function(e) node_string(e, path), ""))
}

#' Verschachtelter Parameter (Art map); unbekannte Felder bleiben für die Validierung erhalten
#' @noRd
node_map <- function(x, param, path) {
  if (!is_map(x)) {
    vofi_abort("io.not_map", path = path, .class = "vofi_error_input")
  }
  fields <- param$fields %||% list()
  for (f in names(x)) {
    if (!is.null(x[[f]]) && !is.null(fields[[f]])) {
      x[f] <- list(node_normalize(x[[f]], fields[[f]], path_join(path, f)))
    }
  }
  x
}

# ---------------------------------------------------------------------------------------------
# Knotenkonstruktoren (4.5, 6.4; auch in bctx)
# ---------------------------------------------------------------------------------------------

#' Konstantenknoten (4.5)
#' @param x Zahl.
#' @return `list(kind = "const", value = <double>)`.
#' @noRd
node_const <- function(x) list(kind = "const", value = as.double(x))

#' Bezugsknoten (4.5)
#' @return `list(kind = "ref", path, scale, offset, floor, cap, anchor)`.
#' @noRd
node_ref <- function(path, scale = 1, offset = 0, floor = -Inf, cap = Inf) {
  list(kind = "ref", path = path, scale = as.double(scale), offset = as.double(offset),
       floor = as.double(floor), cap = as.double(cap), anchor = NULL)
}

#' Zahlungsplanknoten (4.5)
#' @param dates `Date`-Vektor der Termine.
#' @param amounts Beträge (Zahlen oder skalare Knoten).
#' @return `list(kind = "schedule", dates, amounts)`.
#' @noRd
node_schedule <- function(dates, amounts) {
  list(kind = "schedule", dates = dates, amounts = amounts)
}

#' Wachstumsknoten (4.5, R-91)
#' @param start,growth Zahlen oder Knoten.
#' @param base_date `NULL` (Preisstand) oder `Date`.
#' @param index `"calendar_year"` (Default: Kalenderjahreswert, `grid_index_year()`) oder
#'   `"period_end"` (Stichtagswert zum Periodenende, `grid_index()`).
#' @return `list(kind = "growth", start, growth, base_date, real = FALSE, index)`.
#' @noRd
node_growth <- function(start, growth, base_date = NULL, index = "calendar_year") {
  if (is.numeric(start)) start <- node_const(start)
  if (is.numeric(growth)) growth <- node_const(growth)
  list(kind = "growth", start = start, growth = growth, base_date = base_date, real = FALSE,
       index = index)
}

#' Ausdrucksknoten (4.5 Regel 5, R-91)
#' @param text Ausdruckstext (Whitelist nach 4.5, geprueft durch `expr_parse()`).
#' @return `list(kind = "expr", text, ast)`.
#' @noRd
node_expr <- function(text) {
  list(kind = "expr", text = text, ast = expr_parse(text))
}

# ---------------------------------------------------------------------------------------------
# Hilfen fuer Vorlagen und das Schreiben
# ---------------------------------------------------------------------------------------------

#' Platzhalter `{id}` in Pfaden von Bezugs- und Ausdrucksknoten ersetzen (4.7 Nr. 3, R-118)
#'
#' Wirkt rekursiv auf Rohformen (`{ref: "market.energy_price.{id}"}`, `{expr: "..."}`) und auf
#' normalisierte Knoten; andere Zeichenketten bleiben unverändert.
#' @param x Teilbaum einer Vorlage.
#' @param id Element-id.
#' @return Teilbaum mit ersetztem Platzhalter.
#' @noRd
node_subst_id <- function(x, id) {
  if (!is.list(x) || is.data.frame(x) || io_is_raw_num(x)) return(x)
  if (node_is(x)) {
    if (identical(x$kind, "ref") && utl_is_string(x$path)) {
      x$path <- gsub("{id}", id, x$path, fixed = TRUE)
    } else if (identical(x$kind, "expr") && utl_is_string(x$text) &&
                 grepl("{id}", x$text, fixed = TRUE)) {
      return(node_expr(gsub("{id}", id, x$text, fixed = TRUE)))
    }
  } else if (is_map(x)) {
    for (f in c("ref", "expr")) {
      if (utl_is_string(x[[f]])) x[[f]] <- gsub("{id}", id, x[[f]], fixed = TRUE)
    }
  }
  for (i in seq_along(x)) {
    if (!is.null(x[[i]]) && is.list(x[[i]])) x[[i]] <- node_subst_id(x[[i]], id)
  }
  x
}

#' Knoten in die YAML-Form zurückführen (Umkehrung von `node_normalize()`)
#'
#' Defaults der Knotenfelder (scale 1, offset 0, floor -Inf, cap Inf, fill locf, before first,
#' interpolate linear, index calendar_year, real false) entfallen; das erneute Einlesen ergibt
#' denselben Knoten (Round-Trip 4.14).
#' @param x Knoten bzw. beliebiger Wert.
#' @return YAML-Form.
#' @noRd
node_to_yaml <- function(x) {
  if (!node_is(x)) return(x)
  elements <- function(v) if (is.list(v)) lapply(v, node_to_yaml) else as.list(as.double(v))
  switch(x$kind,
    const = as.double(x$value),
    series_t = if (is.numeric(x$values)) as.double(x$values) else elements(x$values),
    series_year = c(list(series = stats::setNames(elements(x$values), as.character(x$years))),
                    if (!identical(x$fill, "locf")) list(fill = x$fill),
                    if (!identical(x$before, "first")) list(before = x$before)),
    points = c(list(years = as.integer(x$years), values = elements(x$values)),
               if (!identical(x$interpolate, "linear")) list(interpolate = x$interpolate)),
    schedule = c(list(schedule = stats::setNames(elements(x$amounts),
                                                 format(x$dates, "%Y-%m-%d"))),
                 if (!is.null(x$unit)) list(unit = x$unit)),
    ref = c(list(ref = x$path),
            if (!identical(as.double(x$scale %||% 1), 1)) list(scale = x$scale),
            if (!identical(x$offset %||% 0, 0)) list(offset = x$offset),
            if (!identical(x$floor %||% -Inf, -Inf)) list(floor = x$floor),
            if (!identical(x$cap %||% Inf, Inf)) list(cap = x$cap),
            if (!is.null(x$anchor)) list(anchor = x$anchor)),
    growth = c(list(start = node_to_yaml(x$start), growth = node_to_yaml(x$growth)),
               if (!is.null(x$base_date)) list(base_date = x$base_date),
               if (isTRUE(x$real)) list(real = TRUE),
               if (!identical(x$index %||% "calendar_year", "calendar_year")) {
                 list(index = x$index)
               }),
    expr = list(expr = x$text),
    quantity = list(value = node_to_yaml(x$value), per = x$per),
    auto = x$mode,
    dist = c(list(dist = x$dist), x$par, if (!is.null(x$base)) list(base = x$base),
             if (!is.null(x$label)) list(label = x$label)),
    x
  )
}
