# Validierung Ebene 2: Typen, Einheiten, Wertebereiche (WS-B; Spec 00 Abschnitte 4.3-4.6, 5.4,
# 8.2, 8.9, 10.2, 10.7, 11.4, 11.5; Feldtabellen Spec 01 Teile A-C, R-106).
#
# Der Feldkatalog (R/schema.R) beschreibt jeden Block und jedes Sammlungselement; die Typen der
# Registry beschreiben ihre Parameter mit vofi_param(). Geprueft werden Pflichtfelder,
# unbekannte Felder (mit Vorschlag), Arten (Zahl, ganze Zahl, Code, Wahrheitswert, Datum,
# Termin, Zeichenkette, Liste, Map), Formen der Wertgrammatik (zeitabhaengig nur mit Shape
# "path", auto/topup nur mit allow_auto), Wertebereiche (min/max, ausschliessliche Grenzen,
# zulaessige Werte) und ids. Querverweise auf ids anderer Sammlungen (Katalogangabe ref_ids)
# und Plausibilitaetsbereiche (warn) werden im selben Durchlauf gemeldet.
# Die Bausteine akzeptieren Rohform (YAML) und normalisierte Knoten, weil Sammlungen in
# Phase 0 nur allgemein normalisiert werden.

#' Ebene 2 einer Spezifikation
#' @param vc Prüfkontext (`val_context()`).
#' @noRd
val_types <- function(vc) {
  val_meta_project(vc)
  for (b in c("meta", "project", "grid", "household", "building", "energy", "accounts",
              "residual_value", "tax", "analysis")) {
    val_block(vc, b)
  }
  for (coll in c("building.elements", "energy.carriers", "energy.stages", "measures",
                 "unit_groups", "funding")) {
    val_collection(vc, coll)
  }
  val_id_collisions(vc)
  val_components(vc)
  val_accounts(vc)
  val_tax(vc)
  val_kpis(vc)
  val_stochastic_types(vc)
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Hilfsfunktionen für Werte in Roh- und Knotenform (auch für Ebenen 3 und 4)
# ---------------------------------------------------------------------------------------------

#' Numerische Arten der Parameter-DSL (5.4)
#' @noRd
val_numeric_kinds <- function() c("number", "amount", "rate", "share", "value", "schedule")

#' Zeitabhängige Knotenarten (Shape `path`, 4.5)
#' @noRd
val_path_kinds <- function() c("series_t", "series_year", "points", "schedule", "growth")

#' Datum aus `Date`, ISO-Zeichenkette oder Jahr (`NULL`, wenn keine Angabe dieser Art)
#' @param x Wert.
#' @param year Jahreszahlen als 1. Januar zulassen.
#' @noRd
val_as_date <- function(x, year = FALSE) {
  if (inherits(x, "Date") && length(x) == 1L && !is.na(x)) return(x)
  if (utl_is_string(x) && grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", trimws(x))) {
    d <- as.Date(trimws(x), format = "%Y-%m-%d", optional = TRUE)
    if (!is.na(d)) return(d)
  }
  if (year) {
    y <- if (utl_is_string(x) && grepl("^[0-9]{4}$", trimws(x))) as.double(trimws(x)) else
      val_num(x)
    if (!is.null(y) && length(y) == 1L && utl_is_whole(y) && y >= 1000 && y <= 9999) {
      return(as.Date(sprintf("%04d-01-01", as.integer(y))))
    }
  }
  NULL
}

#' Daten einer Liste verbinden (`NULL`-Elemente entfallen, die Klasse `Date` bleibt erhalten)
#'
#' `do.call(c, list(NULL, <Date>))` liefert `numeric`, weil `c()` nach dem ersten Argument
#' dispatcht; deshalb werden leere Elemente vorher entfernt.
#' @param x Liste von `Date`-Objekten bzw. `NULL`.
#' @return `Date`-Vektor oder `NULL`.
#' @noRd
val_dates_c <- function(x) {
  x <- Filter(function(d) inherits(d, "Date") && length(d) > 0L, unname(x))
  if (length(x) == 0L) return(NULL)
  do.call(c, x)
}

#' Zahl(en) aus Roh- oder Konstantenform (`NULL`, wenn keine feste Zahl)
#' @noRd
val_num <- function(x) {
  if (node_is(x)) {
    if (identical(x$kind, "const")) return(as.double(x$value))
    if (identical(x$kind, "series_t") && is.numeric(x$values)) return(as.double(x$values))
    return(NULL)
  }
  if (is.numeric(x) && !is.list(x) && length(x) >= 1L) return(as.double(x))
  NULL
}

#' Wahrheitswert aus Roh- oder Knotenform (`NA`, wenn keiner)
#' @noRd
val_flag <- function(x) {
  if (utl_is_flag(x)) return(x)
  if (utl_is_string(x)) {
    s <- tolower(trimws(x))
    if (s %in% c("true", "yes", "ja", "on", "wahr")) return(TRUE)
    if (s %in% c("false", "no", "nein", "off", "falsch")) return(FALSE)
  }
  v <- val_num(x)
  if (length(v) == 1L && v %in% c(0, 1)) return(as.logical(v))
  NA
}

#' Zeichenkette oder `NULL`
#' @noRd
val_str <- function(x) if (utl_is_string(x)) x else NULL

#' Ids einer Sammlung der Spezifikation
#' @noRd
val_ids <- function(vc, coll) {
  x <- path_get(vc$spec, coll)
  if (is_map(x)) names(x) %||% character(0) else character(0)
}

#' Kanonische Träger-ids (Spec 00 4.3.11, R-103)
#' @noRd
val_canonical_carriers <- function() {
  c("gas", "gas_mfh", "oil", "lpg", "power", "power_mfh", "heatpump_power",
    "heatpump_power_mfh", "district_heating", "pellets")
}

#' Codes eines Vokabularverweises (`"vocab:<enum>"` bzw. Name eines Vokabulars)
#' @return Zeichenvektor oder `NULL`, wenn das Vokabular fehlt.
#' @noRd
val_codes <- function(ref) {
  if (!utl_is_string(ref)) return(NULL)
  tryCatch({
    if (startsWith(ref, "vocab:")) utl_param_codes(list(values = ref)) else vocab_codes(ref)
  }, error = function(e) NULL)
}

#' Intervalltext einer Grenze, z. B. `"(0, Inf]"`
#' @noRd
val_interval <- function(lo, hi, excl_lo = FALSE, excl_hi = FALSE) {
  f <- function(x) format(x, scientific = FALSE, trim = TRUE, drop0trailing = TRUE)
  paste0(if (excl_lo) "(" else "[", f(lo), ", ", f(hi), if (excl_hi) ")" else "]")
}

#' Feste Zahlen eines Knotens für Bereichsprüfungen
#'
#' const, Zahlen von series_t/series_year/points (auch Konstanten als Elemente), Beträge eines
#' Zahlungsplans (ohne `unit: share`), Startwert einer Wachstumsform; bei `quantity` der Wert je
#' Bezugseinheit (nur Untergrenzen sinnvoll, Attribut `"lower_only"`).
#' @noRd
val_node_numbers <- function(node) {
  els <- function(v) {
    if (is.numeric(v)) return(as.double(v))
    if (is.list(v)) {
      out <- unlist(lapply(v, function(e) {
        if (is.numeric(e) && length(e) == 1L) return(as.double(e))
        if (node_is(e) && identical(e$kind, "const")) return(as.double(e$value))
        NULL
      }))
      return(as.double(out))
    }
    numeric(0)
  }
  if (!node_is(node)) return(numeric(0))
  switch(node$kind,
    const = as.double(node$value),
    series_t = els(node$values),
    series_year = els(node$values),
    points = els(node$values),
    schedule = if (identical(node$unit, "share")) numeric(0) else els(node$amounts),
    growth = if (node_is(node$start) && identical(node$start$kind, "const")) {
      as.double(node$start$value)
    } else {
      numeric(0)
    },
    quantity = structure(val_node_numbers(if (is.numeric(node$value)) node_const(node$value)
                                          else node$value), lower_only = TRUE),
    numeric(0)
  )
}

# ---------------------------------------------------------------------------------------------
# Felder nach Katalog bzw. Parameterschema
# ---------------------------------------------------------------------------------------------

#' Block nach Feldkatalog prüfen
#' @noRd
val_block <- function(vc, block) {
  x <- vc$spec[[block]]
  if (is.null(x) || (is.list(x) && length(x) == 0L)) return(invisible(NULL))
  val_walk(vc, x, vc$catalog[[block]], block, extra_known = val_known_extra_fields(block))
}

#' Zusätzlich bekannte Felder eines Blocks ohne Katalogeintrag (Kompatibilität mit Phase 0)
#'
#' Der Feldkatalog (`val_schema_catalog()`) ist vollständig; die Funktion liefert daher keine
#' Felder. Sie bleibt als Erweiterungspunkt der Phase-0-Schnittstelle erhalten, den Testhelfer
#' anderer Pakete (z. B. `helper-ws-a.R`) ergänzen dürfen; ergänzte Felder meldet die Prüfung
#' unbekannter Felder nicht.
#' @param block Name des Blocks.
#' @return Zeichenvektor.
#' @noRd
val_known_extra_fields <- function(block) character(0)

#' Feldliste einer Map prüfen (Pflicht, unbekannt, Art, Bereich)
#' @param vc Prüfkontext.
#' @param x Map.
#' @param fields benannte Liste von `vofi_param`.
#' @param path Pfad von `x`.
#' @param open weitere Felder zulässig.
#' @param unknown_code Schlüssel für unbekannte Felder.
#' @param extra_known weitere bekannte Felder ohne Katalogeintrag (ohne Prüfung).
#' @noRd
val_walk <- function(vc, x, fields, path, open = FALSE,
                     unknown_code = "validation.unknown_field", extra_known = character(0)) {
  if (!is_map(x)) {
    val_add(vc, "error", "validation.not_map", path)
    return(invisible(NULL))
  }
  if (!open) {
    for (f in setdiff(names(x), c(names(fields), extra_known))) {
      val_add(vc, "error", unknown_code, path_join(path, f),
              suggestion = utl_suggest_text(f, names(fields)))
    }
  }
  for (f in names(fields)) {
    p <- fields[[f]]
    v <- if (utl_has_name(x, f)) x[[f]] else NULL
    fp <- path_join(path, f)
    if (is.null(v)) {
      if (isTRUE(p$required)) {
        val_add(vc, "error", p$extra[["missing_code"]] %||% "validation.required", fp)
      }
      next
    }
    val_check_value(vc, v, p, fp)
  }
  invisible(NULL)
}

#' Einen Wert nach seiner Parameterbeschreibung prüfen
#' @noRd
val_check_value <- function(vc, v, p, path) {
  kind <- p$kind
  if (isTRUE(p$extra[["dynamic"]])) return(invisible(NULL))   # Blockregel (z. B. Sensitivitäten)
  if (isTRUE(p$extra[["vector"]]) || isTRUE(p$extra[["plain"]])) {
    return(val_check_vector(vc, v, p, path))
  }
  if (kind %in% val_numeric_kinds()) return(val_check_number(vc, v, p, path))
  switch(kind,
    integer = val_check_integer(vc, v, p, path),
    enum = val_check_enum(vc, v, p, path),
    logical = if (is.na(val_flag(v))) {
      val_add(vc, "error", "validation.not_logical", path, value = utl_collapse(format(v)))
    },
    date = if (is.null(val_as_date(v))) {
      val_add(vc, "error", "validation.not_date", path, value = utl_collapse(format(v)))
    },
    timing = val_check_timing(vc, v, p, path),
    string = , ref = val_check_string(vc, v, p, path),
    ids = val_check_ids(vc, v, p, path),
    map = val_check_map(vc, v, p, path),
    NULL
  )
  invisible(NULL)
}

#' Numerische Arten: Wertform, Shape, auto/topup, Bereich, Plausibilitätsbereich
#' @noRd
val_check_number <- function(vc, v, p, path) {
  node <- NULL
  if (node_is(v)) {
    node <- v
  } else if (is.numeric(v) && !is.list(v)) {
    node <- if (length(v) == 1L) node_const(v) else list(kind = "series_t", values = as.double(v))
  } else if (utl_is_string(v) && v %in% c("auto", "topup")) {
    node <- list(kind = "auto", mode = v)
  } else if (is_map(v) && utl_has_name(v, "from")) {
    return(invisible(NULL))                      # Bibliotheksverweis: Schicht 3 (WS-A)
  } else if (!is.null(node <- val_as_node(v, path))) {
    NULL                                         # Rohform der Wertgrammatik (Sammlungen)
  } else {
    val_add(vc, "error", "validation.not_number", path, value = utl_collapse(format(v)))
    return(invisible(NULL))
  }
  if (identical(node$kind, "auto")) {
    if (!isTRUE(p$allow_auto)) val_add(vc, "error", "validation.auto_not_allowed", path,
                                       value = node$mode %||% "auto")
    return(invisible(NULL))
  }
  if (identical(node$kind, "dist")) return(invisible(NULL))
  if (identical(p$kind, "schedule") && !identical(node$kind, "schedule")) {
    val_add(vc, "error", "validation.not_schedule", path)
    return(invisible(NULL))
  }
  if (node$kind %in% val_path_kinds() && !("path" %in% (p$shapes %||% "scalar"))) {
    val_add(vc, "error", "validation.shape_path", path, form = node$kind)
  }
  nums <- val_node_numbers(node)
  val_check_bounds(vc, nums, p, path, lower_only = isTRUE(attr(nums, "lower_only")))
  invisible(NULL)
}

#' Zahlen einer Zahlenliste (Rohform, Konstante, Liste von Zahlen bzw. Konstanten, series_t)
#' @return double-Vektor oder `NULL`, wenn der Wert keine Zahlenliste ist.
#' @noRd
val_num_vec <- function(x) {
  one <- function(e) {
    if (is.numeric(e) && !is.list(e) && length(e) == 1L) return(as.double(e))
    if (node_is(e) && identical(e$kind, "const") && is.numeric(e$value)) return(as.double(e$value))
    NA_real_
  }
  if (node_is(x)) {
    if (identical(x$kind, "const") && is.numeric(x$value)) return(as.double(x$value))
    if (identical(x$kind, "series_t")) return(val_num_vec(x$values))
    return(NULL)
  }
  if (is.numeric(x) && !is.list(x)) return(as.double(x))
  if (is.list(x) && !is_map(x) && length(x) > 0L) {
    out <- vapply(x, one, double(1))
    return(if (anyNA(out)) NULL else unname(out))
  }
  NULL
}

#' Zahlenliste (Extra `vector`, Konstanten beliebiger Länge) bzw. feste Zahl (Extra `plain`)
#'
#' Bereich je Element; kein Shape-Fehler, weil die Werte keine Wertformen sind.
#' @noRd
val_check_vector <- function(vc, v, p, path) {
  nums <- val_num_vec(v)
  if (is.null(nums) || length(nums) == 0L ||
        (!isTRUE(p$extra[["vector"]]) && length(nums) != 1L)) {
    val_add(vc, "error", "validation.not_number", path, value = utl_collapse(format(unlist(v))))
    return(invisible(NULL))
  }
  val_check_bounds(vc, nums, p, path)
}

#' Bereich (min/max, ausschließlich), zulässige Werte, Ganzzahligkeit, Warnbereich
#' @noRd
val_check_bounds <- function(vc, nums, p, path, lower_only = FALSE) {
  nums <- nums[!is.na(nums)]
  if (length(nums) == 0L) return(invisible(NULL))
  lo <- p$min %||% -Inf
  hi <- if (lower_only) Inf else p$max %||% Inf
  xl <- isTRUE(p$extra[["excl_min"]])
  xh <- isTRUE(p$extra[["excl_max"]]) && !lower_only
  bad <- nums[(nums < lo) | (xl & nums <= lo) | (nums > hi) | (xh & nums >= hi)]
  if (length(bad) > 0L) {
    val_add(vc, "error", "validation.range", path, value = bad[1L],
            interval = val_interval(lo, hi, xl, xh))
    return(invisible(NULL))
  }
  allowed <- p$extra[["allowed"]]
  if (!is.null(allowed)) {
    bad <- nums[!(nums %in% allowed)]
    if (length(bad) > 0L) {
      val_add(vc, "error", "validation.not_allowed", path, value = bad[1L],
              allowed = utl_collapse(format(allowed)))
      return(invisible(NULL))
    }
  }
  warn <- p$extra[["warn"]]
  if (!is.null(warn) && (!isTRUE(p$extra[["warn_domain"]]) || vc$domain)) {
    bad <- nums[nums < warn[1L] | nums > warn[2L]]
    if (length(bad) > 0L) {
      val_add(vc, "warning", "validation.unusual", path, value = bad[1L],
              interval = val_interval(warn[1L], warn[2L]))
    }
  }
  wa <- p$extra[["warn_allowed"]]
  if (!is.null(wa)) {
    bad <- nums[!vapply(nums, function(x) any(abs(x - wa) < 1e-9), logical(1))]
    if (length(bad) > 0L) {
      val_add(vc, "warning", "validation.unusual_value", path, value = bad[1L],
              allowed = utl_collapse(format(wa)))
    }
  }
  invisible(NULL)
}

#' Art integer (auch Konstantenknoten und Vektoren)
#'
#' Bezugs- und Ausdrucksknoten sind zulässig (Bezüge statt Kopien, R-86), z. B.
#' `unit_groups.main.n_units: {ref: building.n_units}` aus `rule:unit_group_defaults` (Spec 01
#' Teil B 5.5 (0), N-08a) oder `building.n_units` als Summenausdruck aus
#' `rule:building_aggregates`. Ziel, Zahlart und Zyklen prüft Ebene 3 (R-115); ist der
#' Basisfallwert auflösbar, gelten für ihn Ganzzahligkeit und Bereich wie für eine Zahl.
#' @noRd
val_check_integer <- function(vc, v, p, path) {
  node <- if (node_is(v)) v else if (is_map(v) && val_is_value(v)) val_as_node(v, path)
  if (!is.null(node) && node$kind %in% c("ref", "expr")) {
    nums <- val_bv(vc, path)
    if (length(nums) != 1L || is.na(nums)) return(invisible(NULL))
  } else {
    nums <- val_num(v)
  }
  if (is.null(nums)) {
    val_add(vc, "error", "validation.not_integer", path, value = utl_collapse(format(v)))
    return(invisible(NULL))
  }
  if (any(!is.finite(nums) | abs(nums - round(nums)) > 1e-9)) {
    val_add(vc, "error", "validation.not_integer", path, value = utl_collapse(format(nums)))
    return(invisible(NULL))
  }
  val_check_bounds(vc, nums, p, path)
}

#' Art enum: Code, Alias oder zulässiges Token
#' @noRd
val_check_enum <- function(vc, v, p, path) {
  s <- if (utl_is_flag(v)) tolower(as.character(v)) else v
  codes <- utl_param_codes(p)
  ok <- c(codes, val_param_aliases(p), p$extra[["token"]])
  if (!(utl_is_string(s) && s %in% ok)) {
    val_add(vc, "error", "validation.enum", path, value = utl_collapse(format(v)),
            suggestion = utl_suggest_text(as.character(unlist(v))[1L], codes))
  }
  invisible(NULL)
}

#' Art timing: Datum, Jahr, Token `completion` bzw. zulässiges Token (3.9)
#' @noRd
val_check_timing <- function(vc, v, p, path) {
  ok <- !is.null(val_as_date(v, year = TRUE)) ||
    (utl_is_string(v) && v %in% c("completion", p$extra[["token"]]))
  if (!ok) val_add(vc, "error", "validation.not_timing", path, value = utl_collapse(format(v)))
  invisible(NULL)
}

#' Arten string und ref: Zeichenkette, id-Muster, Länge, Muster, Querverweis
#' @noRd
val_check_string <- function(vc, v, p, path) {
  s <- if (utl_is_string(v)) v else if (is.numeric(v) && length(v) == 1L && !is.list(v)) {
    format(v, scientific = FALSE, trim = TRUE)
  } else {
    NULL
  }
  if (is.null(s)) {
    val_add(vc, "error", "validation.not_string", path)
    return(invisible(NULL))
  }
  if (isTRUE(p$extra[["id"]])) {
    max_len <- p$extra[["max_len"]] %||% 40L
    if (!utl_is_id(s, 1000L)) {
      val_add(vc, "error", "validation.id_invalid", path, value = s)
    } else if (nchar(s) > max_len) {
      val_add(vc, "error", "validation.id_too_long", path, value = s, max = max_len)
    }
  }
  if (!is.null(p$extra[["pattern"]]) && !grepl(p$extra[["pattern"]], s)) {
    val_add(vc, "error", "validation.pattern", path, value = s, pattern = p$extra[["pattern"]])
  }
  mc <- p$extra[["max_chars"]]
  if (!is.null(mc) && nchar(s) > mc) {
    val_add(vc, "warning", "validation.text_long", path, max = mc)
  }
  if (!is.null(p$extra[["ref_ids"]])) val_check_ref_id(vc, s, p$extra[["ref_ids"]], path)
  invisible(NULL)
}

#' Art ids: Liste von Zeichenketten, Codes eines Vokabulars, Muster, Querverweise
#' @noRd
val_check_ids <- function(vc, v, p, path) {
  vals <- val_chr_list(v)
  if (is.null(vals)) {
    val_add(vc, "error", "validation.not_ids", path)
    return(invisible(NULL))
  }
  if (length(vals) == 1L && vals %in% (p$extra[["token"]] %||% character(0))) {
    return(invisible(NULL))
  }
  if (!is.null(p$extra[["items"]])) {
    codes <- val_codes(p$extra[["items"]])
    if (!is.null(codes)) {
      for (el in setdiff(vals, codes)) {
        val_add(vc, "error", "validation.enum", path, value = el,
                suggestion = utl_suggest_text(el, codes))
      }
    }
  }
  if (!is.null(p$extra[["pattern"]])) {
    for (el in vals[!grepl(p$extra[["pattern"]], vals)]) {
      val_add(vc, "error", "validation.pattern", path, value = el, pattern = p$extra[["pattern"]])
    }
  }
  if (isTRUE(p$extra[["unique"]]) && anyDuplicated(vals)) {
    val_add(vc, "error", "validation.duplicate_entries", path,
            value = vals[duplicated(vals)][1L])
  }
  if (!is.null(p$extra[["ref_ids"]])) {
    for (el in vals) val_check_ref_id(vc, el, p$extra[["ref_ids"]], path)
  }
  invisible(NULL)
}

#' Art map: feste Feldliste, freie Map, Sequenz, beliebiger Inhalt
#' @noRd
val_check_map <- function(vc, v, p, path) {
  if (!is.null(p$extra[["collection"]])) return(invisible(NULL))  # eigene Prüfung (val_collection)
  if (isTRUE(p$extra[["sequence"]])) {
    if (!is.list(v) || (is_map(v) && length(v) > 0L)) {
      val_add(vc, "error", "validation.not_list", path)
      return(invisible(NULL))
    }
    for (i in seq_along(v)) val_walk(vc, v[[i]], p$fields, path_join(path, i),
                                     open = isTRUE(p$extra[["open"]]))
    return(invisible(NULL))
  }
  if (!is_map(v)) {
    val_add(vc, "error", "validation.not_map", path)
    return(invisible(NULL))
  }
  if (isTRUE(p$extra[["any"]])) return(invisible(NULL))
  if (isTRUE(p$extra[["free"]])) {
    leaf <- p$fields[[".key"]]
    keys <- if (!is.null(p$extra[["keys"]])) val_codes(p$extra[["keys"]]) else NULL
    for (k in names(v)) {
      kp <- path_join(path, k)
      if (!is.null(keys) && !(k %in% keys)) {
        val_add(vc, "error", "validation.enum", kp, value = k,
                suggestion = utl_suggest_text(k, keys))
      }
      if (!is.null(p$extra[["ref_ids"]])) val_check_ref_id(vc, k, p$extra[["ref_ids"]], kp)
      if (!is.null(v[[k]]) && inherits(leaf, "vofi_param")) val_check_value(vc, v[[k]], leaf, kp)
    }
    return(invisible(NULL))
  }
  val_walk(vc, v, p$fields, path, open = isTRUE(p$extra[["open"]]))
}

#' Querverweis auf die id eines Elements einer anderen Sammlung (Ebene 3)
#' @param vc Prüfkontext.
#' @param value id.
#' @param coll Sammlung (z. B. `"measures"`, `"energy.carriers"`).
#' @param path Pfad des Verweises.
#' @noRd
val_check_ref_id <- function(vc, value, coll, path) {
  ids <- val_ids(vc, coll)
  if (identical(coll, "energy.carriers") && startsWith(path, "building.")) {
    ids <- union(ids, val_canonical_carriers())
  }
  if (!(utl_is_string(value) && value %in% ids)) {
    val_add(vc, "error", "validation.ref_id_unknown", path, value = utl_collapse(format(value)),
            collection = coll, suggestion = utl_suggest_text(as.character(value)[1L], ids))
  }
  invisible(NULL)
}

#' Höchstlänge der Nutzer-ids einer Sammlung (4.4 Nr. 2, R-90)
#' @noRd
val_id_max_len <- function(coll) {
  switch(coll, measures = 29L, "building.elements" = 29L, unit_groups = 25L, funding = 30L,
         "energy.stages" = 12L, "energy.carriers" = 20L, 40L)
}

#' Sammlung prüfen: ids, Elemente nach Katalog
#' @noRd
val_collection <- function(vc, coll) {
  x <- path_get(vc$spec, coll)
  if (is.null(x) || (is.list(x) && length(x) == 0L)) return(invisible(NULL))
  if (!is_map(x)) {
    val_add(vc, "error", "validation.not_map", coll)
    return(invisible(NULL))
  }
  fields <- vc$catalog[[coll]]
  max_len <- val_id_max_len(coll)
  for (id in names(x)) {
    p <- path_join(coll, id)
    if (!utl_is_id(id, 1000L)) {
      val_add(vc, "error", "validation.id_invalid", p, value = id)
    } else if (nchar(id) > max_len) {
      val_add(vc, "error", "validation.id_too_long", p, value = id, max = max_len)
    }
    if (identical(coll, "energy.stages") && id %in% c("before", "after")) {
      val_add(vc, "error", "validation.energy.stage_reserved", p, value = id)
    }
    el <- x[[id]]
    if (is.null(el)) next
    val_walk(vc, el, fields, p)
  }
  invisible(NULL)
}

#' Maßnahmen und Bestandsbauteile sind gemeinsam eindeutig (Teil A 3.2, 4.5.2 Nr. 1)
#' @noRd
val_id_collisions <- function(vc) {
  both <- intersect(val_ids(vc, "measures"), val_ids(vc, "building.elements"))
  for (id in both) {
    val_add(vc, "error", "validation.id_collision", path_join("building.elements", id),
            value = id, other = path_join("measures", id))
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# meta, project, Komponenten, Konten, Steuer, Kennzahlen
# ---------------------------------------------------------------------------------------------

#' Sonderregeln für meta und project (4.3.1, 4.3.2; Teil A 1.1-1.3)
#' @noRd
val_meta_project <- function(vc) {
  p <- vc$spec$project %||% list()
  vd <- p$valuation_date
  if (inherits(vd, "Date") && length(vd) == 1L && !is.na(vd) && utl_mday(vd) != 1L) {
    val_add(vc, "error", "validation.valuation_first", "project.valuation_date", value = vd)
  }
  hy <- p$horizon_years
  if (is.null(vc$spec$grid$periods_months) &&
        (is.null(hy) || (utl_is_whole(hy) && hy < 1))) {
    val_add(vc, "error", "validation.horizon", "project.horizon_years")
  }
  invisible(NULL)
}

#' Komponenten und Finanzierungsbausteine: ids, Typen, Parameter (4.3.8, 4.3.9, 4.4, 5.4)
#' @noRd
val_components <- function(vc) {
  spec <- vc$spec
  seen <- character(0)
  prefixes <- c("m_", "u_", "f_", "e_", "h_", "rv_", "x_")
  for (coll in c("components", "financing")) {
    for (id in names(spec[[coll]])) {
      path <- path_join(coll, id)
      comp <- spec[[coll]][[id]]
      origin <- if (is.list(comp)) comp$origin %||% "scenario" else "scenario"
      user <- identical(origin, "scenario")
      if (!utl_is_id(id, 1000L) || id %in% c("base", "engine")) {
        val_add(vc, "error", "validation.id_invalid", path, value = id)
      } else if (nchar(id) > 40L) {
        if (user) {
          val_add(vc, "error", "validation.id_invalid", path, value = id)
        } else {
          val_add(vc, "error", "validation.generated_id_too_long", path, value = id,
                  max_user = val_generated_user_max(id))
        }
      }
      if (user && any(startsWith(id, prefixes))) {
        val_add(vc, "error", "validation.id_reserved_prefix", path, value = id,
                prefix = prefixes[startsWith(id, prefixes)][1L])
      }
      if (id %in% seen) val_add(vc, "error", "validation.id_duplicate", path, value = id)
      seen <- c(seen, id)
      if (!is_map(comp)) {
        val_add(vc, "error", "validation.not_map", path)
        next
      }
      type <- comp$type
      def <- scn_type_def(type, coll)
      if (is.null(def) || (identical(coll, "components") && !identical(def$kind, "flow")) ||
            (identical(coll, "financing") && identical(def$kind, "flow") &&
               !identical(def$name, "equity"))) {
        choices <- if (identical(coll, "financing")) c("equity", reg_list("instrument")$name) else
          reg_list("flow")$name
        val_add(vc, "error", "validation.type_unknown", path_join(path, "type"),
                value = utl_collapse(format(type %||% "NULL")),
                suggestion = utl_suggest_text(as.character(type %||% "")[1L], choices))
        next
      }
      for (p in names(def$params)) {
        pp <- def$params[[p]]
        v <- comp[[p]]
        if (is.null(v)) {
          if (isTRUE(pp$required)) val_add(vc, "error", "validation.param_required",
                                           path_join(path, p))
          next
        }
        val_check_value(vc, v, pp, path_join(path, p))
      }
      known <- c(names(def$params), reg_reserved_fields())
      for (f in setdiff(names(comp), known)) {
        val_add(vc, "error", "validation.param_unknown", path_join(path, f), type = def$name,
                suggestion = utl_suggest_text(f, names(def$params)))
      }
      if (is.function(def$validate)) {
        fds <- tryCatch(def$validate(comp, spec), error = function(e) e)
        if (inherits(fds, "error")) {
          val_add(vc, "error", "validation.type_validate_failed", path, type = def$name,
                  detail = conditionMessage(fds))
          next
        }
        for (fd in fds %||% list()) {
          do.call(val_add, c(list(vc, fd$severity, fd$code, fd$path %||% path), fd$args))
        }
      }
    }
  }
  invisible(NULL)
}

#' Zulässige Höchstlänge der Nutzer-id zu einer erzeugten id (R-90)
#' @noRd
val_generated_user_max <- function(id) {
  if (startsWith(id, "m_")) return("29")
  if (startsWith(id, "u_")) return("25")
  if (startsWith(id, "f_")) return("30")
  if (startsWith(id, "e_")) return("12 / 20")
  "40"
}

#' Ausgleichsketten (8.9)
#' @noRd
val_accounts <- function(vc) {
  a <- vc$spec$accounts %||% list()
  chains <- list(surplus_order = list(role = "surplus", first = "od_repay",
                                      last = "dep_invest"),
                 deficit_order = list(role = "deficit", first = "dep_withdraw",
                                      last = c("equity_call", "penalty_rate", "stop")))
  for (nm in names(chains)) {
    ch <- val_chr_list(a[[nm]])
    rule <- chains[[nm]]
    path <- path_join("accounts", nm)
    if (is.null(ch) || length(ch) == 0L) {
      val_add(vc, "error", "validation.required", path)
      next
    }
    ok_names <- TRUE
    for (act in ch) {
      if (!reg_has("account_action", act)) {
        val_add(vc, "error", "validation.chain_action_unknown", path, value = act,
                suggestion = utl_suggest_text(act, reg_list("account_action")$name))
        ok_names <- FALSE
      } else if (!identical(reg_get("account_action", act)$role, rule$role)) {
        val_add(vc, "error", "validation.chain_role", path, value = act)
        ok_names <- FALSE
      }
    }
    if (!ok_names) next
    ranks <- vapply(ch, function(act) as.character(reg_get("account_action", act)$rank), "")
    ok <- identical(ch[1L], rule$first) && ch[length(ch)] %in% rule$last &&
      !anyDuplicated(ch) && !anyDuplicated(ranks) &&
      identical(order(ranks, method = "radix"), seq_along(ranks))
    if (identical(rule$role, "deficit")) ok <- ok && sum(grepl("^D4$", ranks)) == 1L
    if (!ok) {
      val_add(vc, "error", "validation.chain_order", path, first = rule$first,
              last = utl_collapse(rule$last, " | "))
    }
  }
  invisible(NULL)
}

#' Steuermodul (10.2) und Doppelbesteuerung mit pauschaler Abgeltungsteuer (10.7)
#' @noRd
val_tax <- function(vc) {
  spec <- vc$spec
  mod <- spec$tax$module %||% "none"
  if (!utl_is_string(mod)) return(invisible(NULL))
  if (!reg_has("tax", mod)) {
    val_add(vc, "error", "validation.tax_module_unknown", "tax.module", value = mod,
            suggestion = utl_suggest_text(mod, reg_list("tax")$name))
    return(invisible(NULL))
  }
  def <- reg_get("tax", mod)
  persp <- spec$project$perspective
  if ((!is.null(def$perspectives) && !(utl_is_string(persp) && persp %in% def$perspectives)) ||
        (spec$project$tax_regime %||% "") %in% (def$blocked_regimes %||% character(0))) {
    val_add(vc, "error", "validation.tax_module_blocked", "tax.module", value = mod,
            perspective = persp %||% "",
            reason = val_tax_blocked_reason(mod, persp, spec$project$tax_regime))
  }
  w <- val_num(spec$accounts$deposit_withholding_tax_share)
  if (identical(mod, "flat") && length(w) >= 1L && any(w > 0)) {
    val_add(vc, "error", "validation.tax_flat_withholding",
            "accounts.deposit_withholding_tax_share")
  }
  invisible(NULL)
}

#' Grund der Sperre eines Steuermoduls (CR-5 WS-X)
#'
#' Text des Labels `types.tax.<modul>.msg.blocked` (Platzhalter `perspective`, `regime`) mit
#' führendem Leerzeichen, sonst leer; Platzhalter `reason` von `validation.tax_module_blocked`.
#' @noRd
val_tax_blocked_reason <- function(mod, perspective, regime) {
  key <- paste0("types.tax.", mod, ".msg.blocked")
  if (!utl_is_string(mod) || !lbl_has(key)) return("")
  paste0(" ", lbl(key, perspective = if (utl_is_string(perspective)) perspective else "",
                  regime = if (utl_is_string(regime)) regime else ""))
}

#' Kennzahlen (9.1 Stufe 9, 12.3)
#' @noRd
val_kpis <- function(vc) {
  kpis <- val_chr_list(vc$spec$analysis$kpis)
  if (is.null(kpis) || identical(kpis, "default")) return(invisible(NULL))
  persp <- vc$spec$project$perspective
  for (k in kpis) {
    if (!reg_has("kpi", k)) {
      val_add(vc, "error", "validation.kpi_unknown", "analysis.kpis", value = k,
              suggestion = utl_suggest_text(k, reg_list("kpi")$name))
      next
    }
    pp <- reg_get("kpi", k)$perspectives
    if (!is.null(pp) && utl_is_string(persp) && !(persp %in% pp)) {
      val_add(vc, "info", "validation.analysis.kpi_perspective", "analysis.kpis", value = k,
              perspective = persp)
    }
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Stochastik-Overlay: Einstellungen, Einträge, Verteilungen, Prozesse (4.3.15, 11.4; Teil C 1)
# ---------------------------------------------------------------------------------------------

#' Metafelder der Overlay-Einträge (keine Verteilungs- bzw. Prozessparameter)
#' @noRd
val_overlay_meta <- function(kind = c("parameters", "processes")) {
  kind <- utl_match_arg(kind, c("parameters", "processes"), "kind")
  if (identical(kind, "parameters")) {
    c("target", "label", "description", "dist", "apply", "base", "from", "use")
  } else {
    c("target", "type", "label", "description", "from", "use")
  }
}

#' Läufe je Preset (R-97; Teil C 6.1)
#' @noRd
val_preset_n_sim <- function(preset) {
  switch(preset %||% "standard", preview = 1000, standard = 10000, report = 50000, NULL)
}

#' Ist ein Blatt ausdrücklich gesetzt (Schicht >= 3)?
#' @noRd
val_explicit <- function(vc, path) {
  pl <- val_prov_lookup(vc$prov, path)
  is.na(pl$layer) || pl$layer >= 3L
}

#' Stochastik: Einstellungen und Einträge (Ebene 2)
#' @noRd
val_stochastic_types <- function(vc) {
  st <- vc$spec$stochastic
  if (!is_map(st) || length(st) == 0L) return(invisible(NULL))
  if (!is.null(st$settings)) {
    val_walk(vc, st$settings, vc$catalog[["stochastic.settings"]], "stochastic.settings",
             unknown_code = "validation.stochastic.unknown_key")
  }
  val_stochastic_settings(vc)
  keys <- character(0)
  for (kind in c("parameters", "processes")) {
    entries <- st[[kind]]
    if (is.null(entries) || length(entries) == 0L) next
    if (!is_map(entries)) {
      val_add(vc, "error", "validation.not_map", path_join("stochastic", kind))
      next
    }
    for (k in names(entries)) {
      path <- path_join("stochastic", kind, k)
      e <- entries[[k]]
      if (k %in% keys) val_add(vc, "error", "validation.stochastic.key_duplicate", path,
                               value = k)
      keys <- c(keys, k)
      short <- identical(kind, "parameters") && is_map(e) && identical(e$target, k)
      if (!short && (!utl_is_id(k) || grepl(".", k, fixed = TRUE))) {
        val_add(vc, "error", "validation.stochastic.key_invalid", path, value = k)
      }
      if (!is_map(e)) {
        val_add(vc, "error", "validation.not_map", path)
        next
      }
      if (identical(kind, "parameters")) val_overlay_parameter(vc, k, e, path, short) else
        val_overlay_process(vc, k, e, path)
    }
  }
  invisible(NULL)
}

#' Regeln der Einstellungen (11.4, 11.5; Teil C 1.2)
#' @noRd
val_stochastic_settings <- function(vc) {
  st <- vc$spec$stochastic
  s <- st$settings %||% list()
  n_entries <- length(st$parameters %||% list()) + length(st$processes %||% list())
  p <- "stochastic.settings"
  scalar <- function(x) {
    v <- val_num(x)
    if (length(v) == 1L && is.finite(v)) v else NULL
  }
  bs <- scalar(s$block_size)
  rep <- scalar(s$replicates)
  bs_set <- !is.null(bs) && val_explicit(vc, path_join(p, "block_size"))
  if (bs_set && !is.null(rep)) {
    val_add(vc, "error", "validation.stochastic.block_and_replicates", path_join(p, "replicates"))
  }
  n_sim <- scalar(s$n_sim)
  if (is.null(n_sim) || !val_explicit(vc, path_join(p, "n_sim"))) {
    n_sim <- val_preset_n_sim(val_str(s$preset)) %||% n_sim %||% 10000
  }
  f21 <- !is.null(rep) && !bs_set
  m <- NULL
  if (f21 && rep >= 1) {
    if (n_sim %% rep != 0) {
      val_add(vc, "error", "validation.stochastic.n_sim_not_multiple", path_join(p, "n_sim"),
              value = n_sim, lower = max(rep, floor(n_sim / rep) * rep),
              upper = ceiling(n_sim / rep) * rep)
    } else {
      m <- n_sim / rep
    }
    if (n_entries > 0L) val_add(vc, "info", "validation.stochastic.replicates_mode",
                                path_join(p, "replicates"))
  } else if (!f21) {
    m <- bs %||% 200
    if (m >= 1 && n_sim %% m != 0) {
      val_add(vc, "error", "validation.stochastic.n_sim_not_multiple", path_join(p, "n_sim"),
              value = n_sim, lower = max(m, floor(n_sim / m) * m),
              upper = ceiling(n_sim / m) * m)
      m <- NULL
    }
  }
  anti <- val_flag(s$antithetic)
  if (isTRUE(anti)) {
    if (!identical(val_str(s$sampling) %||% "lhs", "pseudo")) {
      val_add(vc, "error", "validation.stochastic.antithetic_lhs", path_join(p, "antithetic"))
    } else if (!is.null(m) && m %% 2 != 0) {
      val_add(vc, "error", "validation.stochastic.antithetic_odd", path_join(p, "antithetic"),
              value = m)
    }
  }
  sy <- scalar(s$start_year)
  if (!is.null(sy) && !is.null(vc$vd)) {
    y <- utl_year(vc$vd)
    if (sy > y) {
      val_add(vc, "error", "validation.stochastic.start_year", path_join(p, "start_year"),
              value = as.integer(sy), year = as.integer(y))
    } else if (sy < y - 1) {
      val_add(vc, "warning", "validation.stochastic.start_year_early",
              path_join(p, "start_year"), value = as.integer(sy), year = as.integer(y))
    }
  }
  if (n_entries > 0L) {
    if (identical(val_str(s$store), "full") && n_sim > 2000) {
      val_add(vc, "warning", "validation.stochastic.store_full", path_join(p, "store"),
              value = n_sim)
    }
    if (!is.null(m) && n_sim / m < 10) {
      val_add(vc, "info", "validation.stochastic.se_coarse", path_join(p, "n_sim"),
              value = n_sim / m)
    }
  }
  d <- length(val_corr_keys(st$correlations$parameters))
  if (!is.null(m) && d > 0L && m < max(2, d + 1)) {
    val_add(vc, "error", "validation.stochastic.block_too_small", path_join(p, "block_size"),
            value = m, min = d + 1L)
  }
  kr <- val_chr_list(s[["keep_runs"]])
  if (length(kr) > 0L && anyDuplicated(kr)) {
    val_add(vc, "error", "validation.duplicate_entries", path_join(p, "keep_runs"),
            value = kr[duplicated(kr)][1L])
  }
  bp <- val_num_vec(s$band_probs)
  if (length(bp) > 1L && any(diff(bp) <= 0)) {
    val_add(vc, "error", "validation.not_increasing", path_join(p, "band_probs"))
  }
  invisible(NULL)
}

#' Schlüssel der Korrelationspaare (Paare `[a, b, rho]`)
#' @noRd
val_corr_keys <- function(pairs) {
  if (!is.list(pairs) || is_map(pairs)) return(character(0))
  out <- unlist(lapply(pairs, function(pr) {
    pr <- as.list(pr)
    if (length(pr) == 3L) c(as.character(pr[[1L]]), as.character(pr[[2L]])) else NULL
  }))
  unique(as.character(out))
}

#' Parameter einer Verteilungsangabe (ohne Metafelder)
#' @noRd
val_dist_par <- function(e) {
  par <- e[setdiff(names(e), val_overlay_meta("parameters"))]
  lapply(par, function(v) if (node_is(v) && identical(v$kind, "const")) v$value else v)
}

#' Verteilungsangabe prüfen: Typ registriert, Parameter bekannt, validate(par) (Teil C 1.4)
#' @param vc Prüfkontext.
#' @param dist Name des Typs.
#' @param par Parameterliste.
#' @param path Pfad der Angabe.
#' @return Typdefinition oder `NULL`.
#' @noRd
val_check_dist <- function(vc, dist, par, path) {
  if (!utl_is_string(dist) || !reg_has("distribution", dist)) {
    val_add(vc, "error", "validation.stochastic.dist_unknown", path_join(path, "dist"),
            value = utl_collapse(format(dist %||% "NULL")),
            suggestion = utl_suggest_text(as.character(dist %||% "")[1L],
                                          reg_list("distribution")$name))
    return(NULL)
  }
  def <- reg_get("distribution", dist)
  if (length(def$params) > 0L) {
    for (f in setdiff(names(par), names(def$params))) {
      val_add(vc, "error", "validation.stochastic.unknown_key", path_join(path, f),
              suggestion = utl_suggest_text(f, names(def$params)))
    }
  }
  msgs <- tryCatch(def$validate(par), error = function(e) conditionMessage(e))
  for (m in as.character(unlist(msgs))) {
    val_add(vc, "error", "validation.stochastic.dist_invalid", path, detail = m)
  }
  if (length(msgs) > 0L) return(NULL)
  def
}

#' Statischer Overlay-Eintrag (Teil C 1.3)
#' @noRd
val_overlay_parameter <- function(vc, key, e, path, short) {
  for (f in c("target", "dist")) {
    if (is.null(e[[f]])) val_add(vc, "error", "validation.required", path_join(path, f))
  }
  if (!is.null(e$target) && !utl_is_string(e$target)) {
    val_add(vc, "error", "validation.not_string", path_join(path, "target"))
  }
  ap <- e$apply
  if (!is.null(ap) && !(utl_is_string(ap) && vocab_has("overlay_apply", ap))) {
    val_add(vc, "error", "validation.enum", path_join(path, "apply"),
            value = utl_collapse(format(ap)),
            suggestion = utl_suggest_text(as.character(ap)[1L], vocab_codes("overlay_apply")))
  }
  if (is.null(e$dist)) return(invisible(NULL))
  par <- val_dist_par(e)
  def <- val_check_dist(vc, e$dist, par, path)
  if (is.null(def) || !utl_is_string(ap) || identical(ap, "replace")) return(invisible(NULL))
  tgt <- val_str(e$target) %||% ""
  if (short || grepl("^funding\\.[^.]+\\.approved$", tgt)) {
    val_add(vc, "error", "validation.stochastic.apply_not_allowed", path_join(path, "apply"),
            value = ap)
  } else if (identical(ap, "multiply") && !identical(e$dist, "bernoulli")) {
    lo <- val_dist_support_min(def, e$dist, par)
    if (length(lo) != 1L || is.na(lo) || lo < 0) {
      val_add(vc, "error", "validation.stochastic.apply_not_allowed", path_join(path, "apply"),
              value = ap)
    }
  }
  invisible(NULL)
}

#' Untergrenze des Trägers einer Verteilung (R-94: multiply nur mit Träger in [0, Inf))
#'
#' Maßgeblich ist der Träger des Typs, nicht ein Quantil nahe 0: `normal` hat den Träger R
#' (auch bei kleiner Streuung); sonst das Quantil bei u = 0 (z. B. `-Inf` bei `truncnorm` ohne
#' Untergrenze, `min` bei `pert`, `triangular`, `uniform`, 0 bei `lognormal`). Eine Typangabe
#' `support` (Funktion `par -> c(lo, hi)`) hat Vorrang.
#' @return double(1) oder `NA`.
#' @noRd
val_dist_support_min <- function(def, dist, par) {
  if (identical(dist, "normal")) return(-Inf)
  if (is.function(def$support)) {
    sup <- tryCatch(as.double(def$support(par)), error = function(err) NA_real_)
    return(if (length(sup) >= 1L) sup[1L] else NA_real_)
  }
  lo <- tryCatch(suppressWarnings(as.double(def$quantile(0, par))),
                 error = function(err) NA_real_)
  if (length(lo) != 1L) NA_real_ else lo
}

#' Zulässiger Bereich der Prozessparameter für Verteilungsangaben (Teil C 1.5.2)
#' @return `list(lo, hi, excl_lo, excl_hi)` oder `NULL` (unbeschränkt).
#' @noRd
val_process_param_range <- function(def, name) {
  pp <- def$params[[name]]
  if (inherits(pp, "vofi_param") && (!is.null(pp$min) || !is.null(pp$max))) {
    return(list(lo = pp$min %||% -Inf, hi = pp$max %||% Inf,
                excl_lo = isTRUE(pp$extra[["excl_min"]]), excl_hi = isTRUE(pp$extra[["excl_max"]])))
  }
  switch(name,
    phi = , noise.phi = list(lo = -1, hi = 1, excl_lo = TRUE, excl_hi = TRUE),
    sigma = , kappa = , noise.sigma = list(lo = 0, hi = Inf, excl_lo = FALSE, excl_hi = FALSE),
    p0 = , p_norm = list(lo = 0, hi = Inf, excl_lo = TRUE, excl_hi = FALSE),
    NULL
  )
}

#' Prozessparameter, die keine Verteilung sein dürfen (Teil C 1.5.2)
#' @noRd
val_process_fixed_params <- function(type) {
  switch(type, scenario_mix = c("paths", "weights", "scenarios"), iid = "dist_spec",
         fixed_path = "*", character(0))
}

#' Prozess-Eintrag (Teil C 1.5)
#' @noRd
val_overlay_process <- function(vc, key, e, path) {
  for (f in c("target", "type")) {
    if (is.null(e[[f]])) val_add(vc, "error", "validation.required", path_join(path, f))
  }
  type <- e$type
  if (is.null(type)) return(invisible(NULL))
  if (!utl_is_string(type) || !reg_has("process", type)) {
    val_add(vc, "error", "validation.stochastic.process_unknown", path_join(path, "type"),
            value = utl_collapse(format(type)),
            suggestion = utl_suggest_text(as.character(type)[1L], reg_list("process")$name))
    return(invisible(NULL))
  }
  def <- reg_get("process", type)
  par <- e[setdiff(names(e), val_overlay_meta("processes"))]
  if (length(def$params) > 0L) {
    for (f in setdiff(names(par), names(def$params))) {
      val_add(vc, "error", "validation.stochastic.unknown_key", path_join(path, f),
              suggestion = utl_suggest_text(f, names(def$params)))
    }
  }
  fixed <- val_process_fixed_params(type)
  if (identical(type, "iid") && is_map(par$dist_spec)) {
    # dist_spec ist die Jahresverteilung selbst; ihre Parameter sind nicht verteilbar (1.5.2)
    dsp <- par$dist_spec
    dsp_path <- path_join(path, "dist_spec")
    nested <- names(dsp)[vapply(dsp, function(v) is_map(v) && utl_has_name(v, "dist"),
                                logical(1))]
    for (nm in nested) {
      val_add(vc, "error", "validation.stochastic.process_param_not_distributable",
              path_join(dsp_path, nm), param = path_join("dist_spec", nm))
    }
    if (length(nested) == 0L) val_check_dist(vc, dsp$dist, val_dist_par(dsp), dsp_path)
    par <- par[setdiff(names(par), "dist_spec")]
  }
  point <- par
  dist_params <- function(x, prefix) {
    out <- list()
    for (nm in names(x)) {
      v <- x[[nm]]
      full <- path_join(prefix, nm)
      if (is_map(v) && utl_has_name(v, "dist")) {
        out[[full]] <- v
      } else if (is_map(v) && !node_is(v)) {
        out <- c(out, dist_params(v, full))
      }
    }
    out
  }
  dp <- dist_params(par, "")
  for (nm in names(dp)) {
    v <- dp[[nm]]
    pp <- path_join(path, nm)
    if ("*" %in% fixed || path_split(nm)[1L] %in% fixed) {
      val_add(vc, "error", "validation.stochastic.process_param_not_distributable", pp,
              param = nm)
      next
    }
    dpar <- val_dist_par(v)
    ddef <- val_check_dist(vc, v$dist, dpar, pp)
    if (is.null(ddef)) next
    rng <- val_process_param_range(def, nm)
    if (!is.null(rng)) {
      q <- tryCatch(as.double(ddef$quantile(c(1e-9, 1 - 1e-9), dpar)),
                    error = function(err) c(NA_real_, NA_real_))
      bad <- anyNA(q) || q[1L] < rng$lo || q[2L] > rng$hi ||
        (rng$excl_lo && q[1L] <= rng$lo) || (rng$excl_hi && q[2L] >= rng$hi)
      if (bad) {
        val_add(vc, "error", "validation.stochastic.process_param_support", pp, param = nm,
                interval = val_interval(rng$lo, rng$hi, rng$excl_lo, rng$excl_hi))
      }
    }
    mean <- tryCatch(as.double(ddef$point(dpar, "mean")), error = function(err) NULL)
    point <- path_set(point, nm, mean)
  }
  for (nm in names(point)) {
    if (identical(point[[nm]], "base")) {
      b <- val_base_scalar(vc, val_str(e$target) %||% "")
      point[nm] <- list(b)
    }
  }
  point <- point[!vapply(point, is.null, logical(1))]
  point <- lapply(point, function(v) if (node_is(v) && identical(v$kind, "const")) v$value else v)
  if (identical(type, "iid") && !is.null(e$dist_spec)) point$dist_spec <- e$dist_spec
  msgs <- tryCatch(def$validate(point), error = function(err) conditionMessage(err))
  for (m in as.character(unlist(msgs))) {
    val_add(vc, "error", "validation.stochastic.process_invalid", path, detail = m)
  }
  invisible(NULL)
}
