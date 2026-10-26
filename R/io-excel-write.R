# Szenario als Excel-Arbeitsmappe schreiben (WS-A2, Spec 00 Abschnitte 4.6, 4.14).
#
# io_write_excel() ist der Schreib-Hook von vofi_write_scenario(format = "excel") (R/scenario-
# read.R, WS-A): Es erhaelt den kanonischen Baum (Knoten, Blaetter nach dem Normalisieren) und
# schreibt ihn in das Layout der Vorlage (R/io-excel-template.R). Die Darstellung ist verlustfrei:
# io_read_excel() ergibt dieselbe kanonische Liste (identical(), 4.14 Nr. 1). Dafuer gilt:
#   - Zahlen stehen als Zahlenzellen in der kuerzesten exakten Darstellung (Wert identisch),
#     Inf als Text ".inf"; Datumswerte (Felder der Arten date/timing) als Datumszellen.
#   - Zeichenketten, die der Leser anders deuten wuerde (Zahl, Markierung ~ { [ "), stehen in
#     YAML-Anfuehrungszeichen; explizites NULL als "~".
#   - Codes (Enums, Typen) stehen als deutsche Bezeichnung der Auswahlliste.
#   - Wertformen ausser Konstanten in den Spalten Wertform/Wert/Optionen (Schluessel-Wert- und
#     lange Blaetter) bzw. als YAML-Flussnotation in der Zelle (breite Blaetter); Zeitreihen im
#     Blatt Zeitreihen. Jede Kodierung wird beim Schreiben geprueft (Ruecklesen und Normalisieren
#     ergibt denselben Knoten), sonst steht der Wert als YAML-Flussnotation.
#   - Die Reihenfolge der Felder steht in den ausgeblendeten Spalten .seq/.order, die der
#     Bloecke im Blatt _meta.

#' Kanonischen Szenario-Baum als Excel-Datei schreiben (Hook für `vofi_write_scenario()`)
#' @param x Liste der Blöcke (kanonische Form, wie `scn_input_tree()`).
#' @param path Zieldatei.
#' @return `invisible(path)`.
#' @noRd
io_write_excel <- function(x, path) {
  if (!is.list(x)) {
    vofi_abort("io.scenario_not_map", .class = "vofi_error_input")
  }
  wb <- io_xl_workbook(x)
  io_xl_save(wb, path)
  invisible(path)
}

#' Arbeitsmappe speichern (Fehler als vofi_error_input)
#' @noRd
io_xl_save <- function(wb, path) {
  detail <- character(0)
  if (file.exists(path)) unlink(path)
  res <- tryCatch(withCallingHandlers({
    openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
    TRUE
  }, warning = function(w) {
    detail <<- c(detail, conditionMessage(w))
    invokeRestart("muffleWarning")
  }), error = function(e) e)
  if (inherits(res, "error")) detail <- c(detail, conditionMessage(res))
  if (!isTRUE(res) || !file.exists(path)) {
    vofi_abort("excel_input.write_failed", path = path, detail = utl_collapse(detail, "; "),
               .class = "vofi_error_input")
  }
  invisible(path)
}

#' Arbeitsmappe im Layout der Vorlage (ohne Szenario: leere Vorlage)
#' @param x `NULL` oder kanonischer Szenario-Baum.
#' @return `openxlsx`-Arbeitsmappe.
#' @noRd
io_xl_workbook <- function(x = NULL) {
  io_xl_cache_reset()
  st <- io_xl_new_state(x)
  models <- list()
  for (role in io_xl_roles()) {
    kind <- io_xl_kind(role)
    models[[role]] <- switch(kind,
      kv = io_xl_model_kv(role, st),
      wide = io_xl_model_wide(role, st),
      long = io_xl_model_long(role, st),
      corr = io_xl_model_corr(st),
      NULL
    )
  }
  models$series <- io_xl_model_series(st)
  models$meta <- io_xl_model_meta(st)
  models$instructions <- io_xl_model_instructions()
  models$lists <- io_xl_model_lists(st)
  wb <- openxlsx::createWorkbook(creator = "vofi")
  openxlsx::modifyBaseFont(wb, fontSize = 10)
  for (role in io_xl_roles()) io_xl_render(wb, models[[role]], st)
  hidden <- vapply(io_xl_roles(), function(r) r %in% c("lists", "meta"), logical(1))
  openxlsx::sheetVisibility(wb)[hidden] <- "hidden"
  openxlsx::activeSheet(wb) <- 1L
  wb
}

#' Schreibzustand: Baum, Typen der Komponenten, Zeitreihen, verwendete Listen
#' @noRd
io_xl_new_state <- function(x) {
  st <- new.env(parent = emptyenv())
  st$x <- x
  st$types <- io_xl_types_of(x)
  st$series <- list()
  st$lists_used <- c("forms", "logical", "types:flow", "types:financing", "types:distribution",
                     "types:process", "actions:variants", "actions:sets", "corr",
                     "library:funding")
  st$label_maps <- NULL
  st
}

#' Typen der Komponenten und Finanzierungsbausteine (`"components.<id>"` -> Typ)
#' @noRd
io_xl_types_of <- function(x) {
  out <- character(0)
  for (coll in c("components", "financing")) {
    items <- x[[coll]]
    if (!is_map(items)) next
    for (id in names(items)) {
      t <- if (is.list(items[[id]])) items[[id]][["type"]] else NULL
      if (utl_is_string(t)) out[path_join(coll, id)] <- t
    }
  }
  out
}

# ---------------------------------------------------------------------------------------------
# Zellen
# ---------------------------------------------------------------------------------------------

#' Zahlenzelle (Inf/NaN als Text)
#' @noRd
io_xl_cell_num <- function(v) {
  v <- as.double(v)
  if (length(v) != 1L || is.na(v) && !is.nan(v)) return(NULL)
  if (is.nan(v)) return(io_xl_cell_str(".nan"))
  if (is.infinite(v)) return(io_xl_cell_str(if (v > 0) ".inf" else "-.inf"))
  list(t = "num", v = v)
}

#' Textzelle
#' @noRd
io_xl_cell_str <- function(s) list(t = "str", v = enc2utf8(as.character(s)))

#' Wahrheitswertzelle
#' @noRd
io_xl_cell_bool <- function(b) list(t = "bool", v = isTRUE(b))

#' Datumszelle (Seriennummer des 1900-Systems mit Datumsformat)
#' @noRd
io_xl_cell_date <- function(d) {
  list(t = "num", v = as.double(as.numeric(d) + 25569), date = TRUE)
}

#' Ist eine Parameterart numerisch (Leser deutet Text als Zahl, 4.6)?
#' @noRd
io_xl_numeric_ctx <- function(param) {
  kinds <- c("number", "amount", "rate", "share", "value", "schedule", "integer")
  is.null(param) || param$kind %in% kinds
}

#' Muss eine Zeichenkette in Anführungszeichen stehen (sonst andere Deutung beim Lesen)?
#' @noRd
io_xl_needs_quote <- function(s, param, list_name = NULL) {
  if (!nzchar(s)) return(TRUE)
  tt <- trimws(s)
  if (!nzchar(tt) || tt == "~") return(TRUE)
  if (substr(tt, 1L, 1L) %in% c("{", "[", "\"", "'")) return(TRUE)
  kind <- param$kind %||% "value"
  if (kind %in% c("date", "timing") && grepl(io_xl_de_date_pattern(), tt)) return(TRUE)
  if (!is.null(list_name)) {
    lst <- io_xl_list(list_name)
    if (s %in% lst$label) return(TRUE)
  }
  if (io_xl_numeric_ctx(param)) {
    v <- tryCatch(suppressWarnings(suppressMessages(io_as_number(tt, "", eur = FALSE))),
                  error = function(e) 1)
    if (!is.null(v)) return(TRUE)
  }
  FALSE
}

#' Muster eines deutschen Datums TT.MM.JJJJ
#' @noRd
io_xl_de_date_pattern <- function() "^[0-9]{1,2}[.][0-9]{1,2}[.][0-9]{4}$"

#' Auswahlliste eines Pfads (Enums, Typen, Verteilungen, Prozesse)
#' @noRd
io_xl_list_for <- function(path, param) {
  segs <- path_split(path)
  n <- length(segs)
  if (n == 3L && segs[1L] %in% c("components", "financing") && segs[3L] == "type") {
    return(if (segs[1L] == "components") "types:flow" else "types:financing")
  }
  if (n == 4L && segs[1L] == "stochastic" && segs[2L] == "processes" && segs[4L] == "type") {
    return("types:process")
  }
  if (n == 4L && segs[1L] == "stochastic" && segs[2L] == "parameters" && segs[4L] == "dist") {
    return("types:distribution")
  }
  if (n == 3L && segs[1L] == "funding" && segs[3L] == "from") return("library:funding")
  io_xl_param_list(param)
}

#' Skalare Zelle eines Werts (`NULL`, wenn `v` kein Skalar ist)
#' @param v Wert (kein Knoten).
#' @param param `vofi_param` oder `NULL`.
#' @param path Pfad.
#' @param st Schreibzustand.
#' @noRd
io_xl_scalar_cell <- function(v, param, path, st) {
  if (is.null(v)) return(io_xl_cell_str("~"))
  kind <- param$kind %||% "value"
  if (inherits(v, "Date")) {
    if (length(v) != 1L || is.na(v)) return(NULL)
    if (kind %in% c("date", "timing")) return(io_xl_cell_date(v))
    s <- format(v, "%Y-%m-%d")
    return(io_xl_cell_str(if (io_xl_needs_quote(s, param)) io_xl_quote(s) else s))
  }
  if (is.list(v) || length(v) != 1L || is.na(v)) return(NULL)
  if (is.logical(v)) return(io_xl_cell_bool(v))
  if (is.numeric(v)) return(io_xl_cell_num(v))
  if (is.character(v)) {
    ln <- io_xl_list_for(path, param)
    if (!is.null(ln) && ln != "logical") {
      lst <- io_xl_list(ln)
      hit <- match(v, lst$code)
      if (!is.na(hit)) {
        st$lists_used <- union(st$lists_used, ln)
        return(io_xl_cell_str(lst$label[hit]))
      }
    }
    if (io_xl_needs_quote(v, param, if (identical(ln, "logical")) NULL else ln)) {
      return(io_xl_cell_str(io_xl_quote(v)))
    }
    return(io_xl_cell_str(v))
  }
  NULL
}

#' Zelle eines Nicht-Knoten-Werts: Skalar, id-Liste (Komma) oder YAML-Flussnotation
#' @noRd
io_xl_value_cell <- function(v, param, path, st) {
  cell <- io_xl_scalar_cell(v, param, path, st)
  if (!is.null(cell)) return(cell)
  if (identical(param$kind, "ids") && is.character(v) && length(v) >= 1L && !anyNA(v)) {
    safe <- vapply(v, function(s) {
      nzchar(s) && identical(trimws(s), s) && !grepl(",", s, fixed = TRUE) &&
        !io_xl_needs_quote(s, io_xl_meta_param("string"))
    }, logical(1))
    if (all(safe)) return(io_xl_cell_str(paste(v, collapse = ", ")))
  }
  io_xl_cell_str(io_xl_flow(v))
}

# ---------------------------------------------------------------------------------------------
# Kodierung von Blättern (Wertform, Wert, Optionen)
# ---------------------------------------------------------------------------------------------

#' Kontext eines Pfads: `"raw"` (nicht normalisiert: Varianten, Sets, Overlay-Einträge) oder
#' `"norm"` (normalisierte Blöcke)
#' @noRd
io_xl_context <- function(path) {
  segs <- path_split(path)
  if (length(segs) == 0L) return("raw")
  b <- segs[1L]
  if (b %in% c("variants", "scenario_sets")) return("raw")
  if (b == "stochastic") {
    if (length(segs) >= 3L && segs[2L] == "settings" &&
          segs[3L] %in% names(val_domain_schema("stochastic.settings"))) {
      return("norm")
    }
    return("raw")
  }
  if (b %in% c("schema_version", utl_scenario_blocks())) "norm" else "raw"
}

#' Blatt kodieren
#'
#' @param v Wert am Pfad.
#' @param path Pfad (für Schema, Meldungen und Zeitreihen-id).
#' @param param `vofi_param` oder `NULL`.
#' @param st Schreibzustand.
#' @param mode `"kv"` (Spalten Wertform/Wert/Optionen) oder `"inline"` (eine Zelle).
#' @param ctx `"norm"` oder `"raw"`.
#' @return Liste `form` (Zelle oder `NULL`), `value` (Zelle), `options` (Zelle oder `NULL`).
#' @noRd
io_xl_encode <- function(v, path, param, st, mode = "kv", ctx = io_xl_context(path)) {
  plain <- function(cell) list(form = NULL, value = cell, options = NULL)
  if (node_is(v)) {
    enc <- io_xl_encode_node(v, path, param, st, mode)
    if (!is.null(enc) && io_xl_check_node(enc, v, path, param, st)) return(enc)
    io_xl_drop_series(st, path)
    return(plain(io_xl_cell_str(io_xl_flow(v))))
  }
  if (identical(ctx, "raw")) {
    if (mode == "kv" && is_map(v) && length(v) > 0L) {
      enc <- io_xl_encode_raw_form(v, path, param, st)
      if (!is.null(enc) && io_xl_check_raw(enc, v, path, param, st)) return(enc)
    }
    enc <- plain(io_xl_value_cell(v, param, path, st))
    if (io_xl_check_raw(enc, v, path, param, st)) return(enc)
    return(plain(io_xl_cell_str(io_xl_flow(v))))
  }
  if (mode == "kv" && is_map(v) && identical(utl_value_form_kind(v), "from") &&
        identical(names(v)[1L], "from")) {
    return(io_xl_form_cells("from", io_xl_cell_str(v[["from"]]), v[-1L], st))
  }
  plain(io_xl_value_cell(v, param, path, st))
}

#' Zellen einer Wertform (Bezeichnung der Form aus der Auswahlliste)
#' @noRd
io_xl_form_cells <- function(form, value, opts, st) {
  forms <- io_xl_list("forms")
  label <- forms$label[match(form, forms$code)]
  list(form = io_xl_cell_str(if (is.na(label)) form else label), value = value,
       options = if (length(opts) > 0L) io_xl_cell_str(io_xl_options_text(opts)) else NULL)
}

#' Optionen einer Wertform als Rumpf einer YAML-Map (`scale: 2, anchor: 0.01`)
#' @noRd
io_xl_options_text <- function(opts) {
  paste0(io_xl_flow_str(names(opts)), ": ", vapply(opts, io_xl_flow, "", USE.NAMES = FALSE),
         collapse = ", ")
}

#' Knoten kodieren (ohne Prüfung; `NULL` = nicht darstellbar)
#' @noRd
io_xl_encode_node <- function(v, path, param, st, mode) {
  k <- v$kind
  if (k == "const") {
    cell <- io_xl_cell_num(v$value)
    if (is.null(cell)) return(NULL)
    return(list(form = NULL, value = cell, options = NULL))
  }
  if (k %in% c("series_t", "series_year", "points", "schedule")) {
    row <- io_xl_series_row(v, path, param)
    if (is.null(row)) return(NULL)
    io_xl_add_series(st, row)
    if (mode == "inline") {
      return(list(form = NULL, value = io_xl_cell_str(io_xl_flow(list(timeseries = row$id))),
                  options = NULL))
    }
    return(io_xl_form_cells(k, io_xl_cell_str(row$id), list(), st))
  }
  if (mode == "inline") {
    cell <- if (k == "auto") io_xl_cell_str(v$mode) else io_xl_cell_str(io_xl_flow(v))
    return(list(form = NULL, value = cell, options = NULL))
  }
  y <- node_to_yaml(v)
  switch(k,
    ref = io_xl_form_cells("ref", io_xl_cell_str(y$ref), y[-1L], st),
    expr = io_xl_form_cells("expr", io_xl_cell_str(y$expr), list(), st),
    growth = io_xl_form_cells("growth", io_xl_primary_cell(y$start), y[-1L], st),
    quantity = io_xl_form_cells("quantity", io_xl_primary_cell(y$value), y[-1L], st),
    auto = io_xl_form_cells("auto", io_xl_cell_str(v$mode), list(), st),
    NULL
  )
}

#' Zelle des Hauptwerts einer Wertform (Zahl oder YAML-Flussnotation)
#' @noRd
io_xl_primary_cell <- function(x) {
  if (is.numeric(x) && length(x) == 1L) {
    cell <- io_xl_cell_num(x)
    if (!is.null(cell)) return(cell)
  }
  io_xl_cell_str(io_xl_flow(x))
}

#' Rohe Wertform (Varianten, Overlay) kodieren, wenn der Hauptschlüssel vorn steht
#' @noRd
io_xl_encode_raw_form <- function(v, path, param, st) {
  form <- utl_value_form_kind(v)
  if (is.na(form)) return(NULL)
  primary <- switch(form, ref = "ref", expr = "expr", growth = "start", quantity = "value",
                    from = "from", dist = "dist", NULL)
  if (is.null(primary) || !identical(names(v)[1L], primary)) return(NULL)
  p <- v[[1L]]
  value <- if (form %in% c("ref", "expr", "from", "dist")) {
    if (!utl_is_string(p)) return(NULL)
    io_xl_cell_str(p)
  } else {
    io_xl_primary_cell(p)
  }
  if (form == "expr" && length(v) > 1L) return(NULL)
  io_xl_form_cells(form, value, v[-1L], st)
}

#' Prüfung einer Knotenkodierung: Ruecklesen und Normalisieren ergibt denselben Knoten
#' @noRd
io_xl_check_node <- function(enc, v, path, param, st) {
  dec <- tryCatch(suppressWarnings(suppressMessages(
    io_xl_decode_leaf(enc$form, enc$value, enc$options, param, path, io_xl_reader_state(st))
  )), error = function(e) io_xl_null())
  if (inherits(dec, "io_xl_null")) return(FALSE)
  norm <- tryCatch(suppressWarnings(suppressMessages(node_normalize(dec, param, path))),
                   error = function(e) NULL)
  identical(norm, v)
}

#' Prüfung einer Rohkodierung: Ruecklesen ergibt denselben Wert
#' @noRd
io_xl_check_raw <- function(enc, v, path, param, st) {
  dec <- tryCatch(suppressWarnings(suppressMessages(
    io_xl_decode_leaf(enc$form, enc$value, enc$options, param, path, io_xl_reader_state(st))
  )), error = function(e) structure(list(), class = "io_xl_failed"))
  if (inherits(dec, "io_xl_failed")) return(FALSE)
  if (inherits(dec, "io_xl_null")) return(is.null(v))
  identical(io_unmark(dec), v)
}

#' Lesezustand für die Prüfung beim Schreiben (Zeitreihen des Schreibzustands)
#' @noRd
io_xl_reader_state <- function(st) {
  rs <- new.env(parent = emptyenv())
  rs$series <- lapply(st$series, function(r) r)
  rs$types <- st$types
  rs$label_maps <- NULL
  rs$locations <- character(0)
  rs
}

# ---------------------------------------------------------------------------------------------
# Zeitreihen
# ---------------------------------------------------------------------------------------------

#' Zeile des Blatts Zeitreihen aus einem Reihenknoten (`NULL` = nicht darstellbar)
#' @noRd
io_xl_series_row <- function(v, path, param) {
  vals <- v$values %||% v$amounts
  if (is.numeric(vals)) {
    cells <- lapply(as.double(vals), io_xl_cell_num)
  } else if (is.list(vals)) {
    cells <- lapply(vals, function(e) {
      if (node_is(e) && identical(e$kind, "const")) {
        io_xl_cell_num(e$value)
      } else {
        io_xl_cell_str(io_xl_flow(e))
      }
    })
  } else {
    return(NULL)
  }
  if (any(vapply(cells, is.null, logical(1)))) return(NULL)
  opts <- list()
  keys <- switch(v$kind,
    series_t = paste0("t", seq_along(cells) - 1L),
    series_year = {
      if (!identical(v$fill %||% "locf", "locf")) opts$fill <- v$fill
      if (!identical(v$before %||% "first", "first")) opts$before <- v$before
      as.character(v$years)
    },
    points = {
      if (!identical(v$interpolate %||% "linear", "linear")) opts$interpolate <- v$interpolate
      as.character(v$years)
    },
    schedule = {
      d <- v$dates
      if (!inherits(d, "Date") || anyNA(d) || (length(d) > 1L && any(diff(as.numeric(d)) <= 0))) {
        return(NULL)
      }
      if (!is.null(v$unit)) opts$unit <- v$unit
      ifelse(format(d, "%m-%d") == "01-01", format(d, "%Y"), format(d, "%Y-%m-%d"))
    }
  )
  if (length(keys) != length(cells) || anyDuplicated(keys) || length(keys) == 0L) return(NULL)
  market <- startsWith(path, "market.")
  unit_code <- if (market) io_xl_market_unit(path) else NA_character_
  list(id = path, label = if (market) io_xl_market_label(path) else io_xl_field_label(path),
       form = v$kind,
       unit = if (!is.na(unit_code)) lbl(paste0("vocab.units.", unit_code), .default = unit_code)
       else io_xl_unit_label(param, path),
       options = opts, keys = keys, cells = cells)
}

#' Zeitreihe registrieren (gleiche id ersetzt)
#' @noRd
io_xl_add_series <- function(st, row) {
  st$series[[row$id]] <- row
  invisible(NULL)
}

#' Zeitreihe entfernen (Kodierung verworfen)
#' @noRd
io_xl_drop_series <- function(st, id) {
  if (id %in% names(st$series)) st$series[[id]] <- NULL
  invisible(NULL)
}

#' Spaltenschlüssel der Zeitreihen (Jahre, Perioden t, Termine)
#' @noRd
io_xl_series_keys <- function(st) {
  keys <- unique(unlist(lapply(st$series, function(r) r$keys), use.names = FALSE))
  if (length(keys) == 0L) keys <- as.character(2025:2075)
  ts <- keys[grepl("^t[0-9]+$", keys)]
  dated <- keys[grepl("^[0-9]{4}(-[0-9]{2}-[0-9]{2})?$", keys)]
  when <- as.Date(ifelse(nchar(dated) == 4L, paste0(dated, "-01-01"), dated))
  c(dated[order(when, nchar(dated), method = "radix")], ts[order(as.integer(sub("^t", "", ts)))])
}

# ---------------------------------------------------------------------------------------------
# Blätter als Modelle (Zeilen mit Zellen); Ausgabe in io_xl_render()
# ---------------------------------------------------------------------------------------------

#' Leeres Blattmodell
#' @noRd
io_xl_model <- function(role, keys, headers = vapply(keys, io_xl_column_label, ""),
                        col_style = NULL) {
  list(role = role, name = io_xl_sheet_name(role), kind = io_xl_kind(role), keys = keys,
       headers = unname(headers), rows = list(),
       col_style = col_style %||% stats::setNames(rep("input", length(keys)), keys),
       col_fmt = list(), col_list = list(), widths = NULL, freeze = c(3L, 2L),
       extra_rows = 0L, comments = list(), cond = list())
}

#' Zeile eines Modells
#' @noRd
io_xl_row <- function(cells, style = "data", fmt = NULL, list_name = NULL) {
  list(cells = cells, style = style, fmt = fmt, list = list_name)
}

#' Blätter der obersten Ebene eines Schlüssel-Wert-Blocks (Pfad, Wert)
#'
#' Maps werden rekursiv zerlegt; Blätter sind Knoten, Nicht-Maps, leere Maps, Wertformen (außer
#' Sammlungselementen), Maps mit Punkt in Schlüsseln und explizites `NULL`.
#' @noRd
io_xl_leaves <- function(x, path) {
  out <- list()
  walk <- function(v, p) {
    if (io_xl_is_leaf(v, p)) {
      out[[length(out) + 1L]] <<- list(path = p, value = v)
      return(invisible(NULL))
    }
    for (i in seq_along(v)) walk(v[[i]], path_join(p, names(v)[i]))
  }
  if (!is_map(x) || length(x) == 0L) return(list(list(path = path, value = x)))
  for (i in seq_along(x)) walk(x[[i]], path_join(path, names(x)[i]))
  out
}

#' Ist der Wert ein Blatt der Zerlegung?
#' @noRd
io_xl_is_leaf <- function(v, p) {
  if (is.null(v) || node_is(v) || !is_map(v) || length(v) == 0L) return(TRUE)
  nms <- names(v)
  if (any(grepl(".", nms, fixed = TRUE)) || any(nms == "*")) return(TRUE)
  segs <- path_split(p)
  if (length(segs) >= 2L && !is.na(utl_value_form_kind(v)) &&
        !identical(utl_default_kind_of(p), "map") &&
        !grepl("^stochastic[.](parameters|processes)[.][^.]+$", p)) {
    return(TRUE)
  }
  FALSE
}

#' Modell eines Schlüssel-Wert-Blatts (Vorlagenzeilen und Blätter des Szenarios)
#' @noRd
io_xl_model_kv <- function(role, st) {
  keys <- io_xl_fixed_columns(role)
  cs <- stats::setNames(rep("info", length(keys)), keys)
  cs[c("form", "value", "options", "source", "note")] <- "input"
  cs[".seq"] <- "key"
  m <- io_xl_model(role, keys, col_style = cs)
  m$widths <- c(34, 42, 14, 16, 22, 26, 22, 18, 22, 22, 6)
  m$freeze <- c(3L, 3L)
  for (b in io_xl_kv_blocks(role)) {
    leaves <- list()
    if (!is.null(st$x) && b %in% names(st$x)) leaves <- io_xl_kv_block_leaves(st$x[[b]], b)
    rows <- io_xl_place_leaves(io_xl_kv_template(b), leaves)
    for (r in rows) m$rows[[length(m$rows) + 1L]] <- io_xl_kv_row(r, st)
  }
  m
}

#' Blätter eines Blocks für das Schlüssel-Wert-Blatt (Stochastik ohne Overlay-Einträge)
#' @noRd
io_xl_kv_block_leaves <- function(x, block) {
  if (block == "stochastic" && is_map(x)) {
    x <- x[setdiff(names(x), c("parameters", "processes", "correlations"))]
    if (length(x) == 0L) return(list())
  }
  if (is_map(x) && length(x) == 0L) return(list())
  io_xl_leaves(x, block)
}

#' Blätter den Vorlagenzeilen zuordnen; fehlende Zeilen nach der Gruppe des längsten Präfixes
#' @return Liste von Zeilen `list(path, label, param, header, leaf, seq)`.
#' @noRd
io_xl_place_leaves <- function(tmpl, leaves) {
  rows <- lapply(tmpl, function(r) c(r, list(leaf = NULL, seq = NA_integer_)))
  paths <- vapply(rows, function(r) r$path, "")
  is_hdr <- vapply(rows, function(r) isTRUE(r$header), logical(1))
  extra <- list()
  for (i in seq_along(leaves)) {
    lf <- leaves[[i]]
    hit <- which(paths == lf$path & !is_hdr)
    if (length(hit) == 1L && is.null(rows[[hit]]$leaf)) {
      rows[[hit]]$leaf <- lf
      rows[[hit]]$seq <- i
      next
    }
    extra[[length(extra) + 1L]] <- list(path = lf$path, label = NULL, param = NULL,
                                        header = FALSE, leaf = lf, seq = i)
  }
  for (e in extra) {
    norm <- vapply(rows, function(r) gsub(".*", "", r$path, fixed = TRUE), "")
    segs <- path_split(e$path)
    anchor <- 1L
    for (k in rev(seq_along(segs))) {
      hit <- which(norm == paste(segs[seq_len(k)], collapse = "."))
      if (length(hit) > 0L) {
        anchor <- hit[1L]
        break
      }
    }
    pre <- norm[anchor]
    end <- anchor
    while (end < length(rows) &&
             (norm[end + 1L] == pre || startsWith(norm[end + 1L], paste0(pre, ".")))) {
      end <- end + 1L
    }
    rows <- append(rows, list(e), after = end)
  }
  rows
}

#' Pfad mit Platzhalter `*` für die id eines Sammlungselements (Vorlagen, Vorgaben)
#' @noRd
io_xl_star_path <- function(path) {
  sub(paste0("^(measures|unit_groups|funding|components|financing|energy[.]carriers|",
             "energy[.]stages|building[.]elements)[.][^.]+"), "\\1.*", path)
}

#' Zeile des Schlüssel-Wert-Blatts
#' @noRd
io_xl_kv_row <- function(r, st) {
  path <- r$path
  if (isTRUE(r$header)) {
    cells <- list(path = io_xl_cell_str(path), label = io_xl_cell_str(r$label))
    return(io_xl_row(cells, style = "block"))
  }
  param <- r$param %||% io_xl_param_at(path, st$types)
  market <- startsWith(path, "market.")
  label <- r$label %||% (if (market) io_xl_market_label(path) else io_xl_field_label(path))
  unit_code <- if (market) io_xl_market_unit(path) else NA_character_
  unit <- if (!is.na(unit_code)) {
    lbl(paste0("vocab.units.", unit_code), .default = unit_code)
  } else {
    io_xl_unit_label(param, path)
  }
  fmt <- if (!is.na(unit_code)) {
    io_xl_num_fmt(list(unit = unit_code), path)
  } else {
    io_xl_num_fmt(param, path)
  }
  def <- io_xl_default_info(io_xl_star_path(path), param)
  cells <- list(path = io_xl_cell_str(path), label = io_xl_cell_str(label),
                unit = io_xl_cell_str(unit))
  if (nzchar(def$text)) cells$default <- io_xl_cell_str(def$text)
  if (nzchar(def$source)) cells$default_source <- io_xl_cell_str(def$source)
  ln <- io_xl_list_for(path, param)
  if (!is.null(r$leaf)) {
    enc <- io_xl_encode(r$leaf$value, path, param, st, mode = "kv")
    if (!is.null(enc$form)) cells$form <- enc$form
    cells$value <- enc$value
    if (!is.null(enc$options)) cells$options <- enc$options
    cells$.seq <- io_xl_cell_num(r$seq)
  }
  if (!is.null(ln)) st$lists_used <- union(st$lists_used, ln)
  io_xl_row(cells, style = "data", fmt = fmt, list_name = ln)
}

#' Elemente einer Sammlung (breites bzw. langes Blatt)
#' @noRd
io_xl_collection <- function(role, x) {
  if (is.null(x)) return(list())
  v <- switch(role,
    parameters = x$stochastic$parameters, processes = x$stochastic$processes,
    x[[role]]
  )
  if (is.null(v) || !is_map(v)) return(list())
  v
}

#' Pfadpräfix der Elemente einer Rolle
#' @noRd
io_xl_collection_path <- function(role) {
  switch(role, parameters = "stochastic.parameters", processes = "stochastic.processes", role)
}

#' Zerlegung eines Elements für breite Blätter (Spalten der Rolle als Blätter)
#' @noRd
io_xl_wide_leaves <- function(el, colkeys, prefix) {
  out <- list()
  walk <- function(v, rel) {
    p <- path_join(prefix, rel)
    if (rel %in% colkeys || io_xl_is_leaf(v, p)) {
      out[[length(out) + 1L]] <<- list(rel = rel, value = v)
      return(invisible(NULL))
    }
    for (i in seq_along(v)) walk(v[[i]], path_join(rel, names(v)[i]))
  }
  for (i in seq_along(el)) walk(el[[i]], names(el)[i])
  out
}

#' Modell eines breiten Blatts (ein Element je Zeile)
#' @noRd
io_xl_model_wide <- function(role, st) {
  cols <- io_xl_wide_columns(role)
  keys <- vapply(cols, function(cl) cl$key, "")
  cs <- stats::setNames(rep("input", length(keys)), keys)
  cs[".order"] <- "key"
  m <- io_xl_model(role, keys, headers = vapply(cols, function(cl) cl$label, ""),
                   col_style = cs)
  m$freeze <- c(3L, 2L)
  m$extra_rows <- 50L
  prefix <- io_xl_collection_path(role)
  for (cl in cols) {
    if (startsWith(cl$key, ".")) next
    path <- path_join(prefix, "*", cl$key)
    fmt <- io_xl_num_fmt(cl$param, path)
    if (!is.null(fmt)) m$col_fmt[[cl$key]] <- fmt
    ln <- io_xl_list_for(path_join(prefix, "x", cl$key), cl$param)
    if (!is.null(ln)) {
      m$col_list[[cl$key]] <- ln
      st$lists_used <- union(st$lists_used, ln)
    }
    m$comments[[cl$key]] <- io_xl_column_comment(cl, path)
  }
  if (role == "financing") m$cond <- io_xl_financing_cond(cols)
  if (role == "parameters") m$comments[paste0(".p", 1:4)] <- io_xl_dist_comments()
  coll <- io_xl_collection(role, st$x)
  for (id in names(coll)) {
    m$rows[[length(m$rows) + 1L]] <- io_xl_wide_row(role, id, coll[[id]], cols, keys, prefix, st)
  }
  m
}

#' Kommentar einer Spaltenüberschrift (Pfad, Einheit, Vorgabe)
#' @noRd
io_xl_column_comment <- function(cl, path) {
  def <- io_xl_default_info(path, cl$param)
  unit <- io_xl_unit_label(cl$param, path)
  parts <- c(path, if (nzchar(unit)) paste0(lbl("excel_input.columns.unit"), ": ", unit),
             if (nzchar(def$text) || nzchar(def$source)) {
               paste0(lbl("excel_input.columns.default"), ": ",
                      trimws(paste(def$text, if (nzchar(def$source)) paste0("(", def$source, ")"))))
             },
             if (length(cl$types) > 0L) {
               paste0(lbl("excel_input.columns.type"), ": ", paste(cl$types, collapse = ", "))
             })
  paste(parts, collapse = "\n")
}

#' Bedeutung von P1-P4 je Verteilung (Kommentar der Spalten)
#' @noRd
io_xl_dist_comments <- function() {
  dists <- reg_list("distribution")$name
  lapply(1:4, function(i) {
    lines <- vapply(dists, function(d) {
      pn <- names(reg_get("distribution", d)$params)
      paste0(d, ": ", if (length(pn) >= i) pn[i] else "-")
    }, "")
    paste(lines, collapse = "\n")
  })
}

#' Bedingte Formatierung des Blatts Finanzierung: Parameter, die der Typ nicht kennt, grau
#' @noRd
io_xl_financing_cond <- function(cols) {
  lst <- io_xl_list("types:financing")
  out <- list()
  for (cl in cols) {
    if (length(cl$types) == 0L) next
    labels <- c(lst$label[lst$code %in% cl$types], cl$types)
    terms <- paste0("$B3=\"", gsub("\"", "\"\"", labels, fixed = TRUE), "\"")
    out[[cl$key]] <- paste0("AND($B3<>\"\",NOT(OR(", paste(terms, collapse = ","), ")))")
  }
  out
}

#' Zeile eines breiten Blatts
#' @noRd
io_xl_wide_row <- function(role, id, el, cols, keys, prefix, st) {
  base <- path_join(prefix, id)
  cells <- list()
  cells[[keys[1L]]] <- io_xl_id_cell(id)
  if (!is_map(el) || length(el) == 0L) {
    cells$.extra <- io_xl_cell_str(io_xl_flow(el))
    cells$.order <- io_xl_cell_str("*")
    return(io_xl_row(cells))
  }
  param_cols <- if (role == "parameters") io_xl_dist_param_names(el[["dist"]]) else character(0)
  colkeys <- setdiff(keys, keys[startsWith(keys, ".")])
  leaves <- io_xl_wide_leaves(el, c(colkeys, param_cols), base)
  extra <- list()
  order <- character(0)
  for (lf in leaves) {
    order <- c(order, lf$rel)
    path <- path_join(base, lf$rel)
    if (lf$rel == "id" && identical(lf$value, id)) next
    pi <- match(lf$rel, param_cols)
    key <- if (!is.na(pi)) paste0(".p", pi) else if (lf$rel %in% colkeys) lf$rel else NA
    if (is.na(key)) {
      extra[[lf$rel]] <- lf$value
      next
    }
    param <- io_xl_param_at(path, st$types)
    enc <- io_xl_encode(lf$value, path, param, st, mode = "inline")
    cells[[key]] <- enc$value
  }
  if (length(extra) > 0L) cells$.extra <- io_xl_cell_str(io_xl_flow(extra))
  cells$.order <- io_xl_cell_str(io_xl_flow(order))
  io_xl_row(cells)
}

#' Zelle einer id bzw. eines Schlüssels (Zeichenkette, ggf. in Anführungszeichen)
#' @noRd
io_xl_id_cell <- function(id) {
  if (io_xl_needs_quote(id, io_xl_meta_param("string")) || grepl("^[0-9.eE+-]+$", id)) {
    return(io_xl_cell_str(io_xl_quote(id)))
  }
  io_xl_cell_str(id)
}

#' Parameternamen P1-P4 einer Verteilung (Reihenfolge der Registry)
#' @noRd
io_xl_dist_param_names <- function(dist) {
  if (!utl_is_string(dist) || !reg_has("distribution", dist)) return(character(0))
  pn <- names(reg_get("distribution", dist)$params)
  pn[seq_len(min(4L, length(pn)))]
}

#' Modell eines langen Blatts (Komponenten, Prozesse, Varianten, Szenario-Sets)
#' @noRd
io_xl_model_long <- function(role, st) {
  keys <- io_xl_fixed_columns(role)
  cs <- stats::setNames(rep("input", length(keys)), keys)
  cs[c(".label", ".unit")[c(".label", ".unit") %in% keys]] <- "info"
  cs[".order"] <- "key"
  m <- io_xl_model(role, keys, col_style = cs)
  m$extra_rows <- 50L
  m$freeze <- c(3L, 2L)
  m$col_list[[".form"]] <- "forms"
  if ("type" %in% keys) {
    m$col_list[["type"]] <- if (role == "components") "types:flow" else "types:process"
  }
  if (".action" %in% keys) {
    m$col_list[[".action"]] <- if (role == "scenario_sets") "actions:sets" else "actions:variants"
  }
  m$widths <- switch(
    role,
    components = c(16, 22, 26, 30, 12, 16, 22, 24, 18, 18, 6),
    processes = c(18, 28, 18, 18, 16, 22, 24, 18, 6),
    c(16, 26, 26, 12, 14, 30, 16, 22, 24, 18, 6)
  )
  coll <- if (role %in% c("variants", "scenario_sets")) {
    st$x[[role]]
  } else {
    io_xl_collection(role, st$x)
  }
  if (!is_map(coll)) coll <- list()
  for (id in names(coll)) {
    rows <- switch(role,
      components = io_xl_component_rows(id, coll[[id]], st),
      processes = io_xl_process_rows(id, coll[[id]], st),
      io_xl_variant_rows(role, id, coll[[id]], st)
    )
    m$rows <- c(m$rows, rows)
  }
  m
}

#' Zeilen einer Komponente (Typ in der ersten Zeile, Parameter je Zeile)
#' @noRd
io_xl_component_rows <- function(id, el, st) {
  base <- path_join("components", id)
  first <- list(.id = io_xl_id_cell(id))
  if (!is_map(el) || length(el) == 0L) {
    first$.value <- io_xl_cell_str(io_xl_flow(el))
    first$.order <- io_xl_cell_str("*")
    return(list(io_xl_row(first)))
  }
  leaves <- io_xl_wide_leaves(el, character(0), base)
  order <- vapply(leaves, function(lf) lf$rel, "")
  rows <- list()
  type <- el[["type"]]
  if (utl_is_string(type)) {
    first$type <- io_xl_scalar_cell(type, io_xl_meta_param("string"), path_join(base, "type"), st)
  }
  for (lf in leaves) {
    if (lf$rel == "type" && utl_is_string(type)) next
    if (lf$rel == "id" && identical(lf$value, id)) next
    path <- path_join(base, lf$rel)
    param <- io_xl_param_at(path, st$types)
    enc <- io_xl_encode(lf$value, path, param, st, mode = "kv")
    cells <- list(.id = io_xl_id_cell(id), .param = io_xl_cell_str(lf$rel),
                  .label = io_xl_cell_str(io_xl_type_param_label("components", type %||% "",
                                                                 lf$rel)),
                  .unit = io_xl_cell_str(io_xl_unit_label(param, path)))
    if (!is.null(enc$form)) cells$.form <- enc$form
    cells$.value <- enc$value
    if (!is.null(enc$options)) cells$.options <- enc$options
    rows[[length(rows) + 1L]] <- io_xl_row(cells, fmt = io_xl_num_fmt(param, path))
  }
  if (length(rows) == 0L) rows <- list(io_xl_row(list(.id = io_xl_id_cell(id))))
  for (k in names(first)) rows[[1L]]$cells[[k]] <- first[[k]]
  rows[[1L]]$cells$.order <- io_xl_cell_str(io_xl_flow(order))
  rows
}

#' Zeilen eines Prozesses (Ziel und Typ in der ersten Zeile, Parameter je Zeile)
#' @noRd
io_xl_process_rows <- function(key, el, st) {
  base <- path_join("stochastic.processes", key)
  first <- list(.key = io_xl_id_cell(key))
  if (!is_map(el) || length(el) == 0L) {
    first$.value <- io_xl_cell_str(io_xl_flow(el))
    first$.order <- io_xl_cell_str("*")
    return(list(io_xl_row(first)))
  }
  rows <- list()
  for (f in c("target", "type")) {
    if (utl_is_string(el[[f]])) {
      first[[f]] <- io_xl_scalar_cell(el[[f]], io_xl_meta_param("string"), path_join(base, f),
                                      st)
    }
  }
  for (i in seq_along(el)) {
    f <- names(el)[i]
    if (f %in% c("target", "type") && utl_is_string(el[[f]])) next
    path <- path_join(base, f)
    enc <- io_xl_encode(el[[i]], path, NULL, st, mode = "kv", ctx = "raw")
    cells <- list(.key = io_xl_id_cell(key), .param = io_xl_cell_str(f))
    if (!is.null(enc$form)) cells$.form <- enc$form
    cells$.value <- enc$value
    if (!is.null(enc$options)) cells$.options <- enc$options
    rows[[length(rows) + 1L]] <- io_xl_row(cells)
  }
  if (length(rows) == 0L) rows <- list(io_xl_row(list(.key = io_xl_id_cell(key))))
  for (k in names(first)) rows[[1L]]$cells[[k]] <- first[[k]]
  rows[[1L]]$cells$.order <- io_xl_cell_str(io_xl_flow(names(el)))
  rows
}

#' Zeilen einer Variante bzw. eines Szenario-Sets (eine Operation je Zeile)
#'
#' `set`, `replace`, `add`: Eintrag je Zeile (Pfad = Schlüssel); `remove`: Pfad je Zeile;
#' `overrides`, `generate`: Blätter des Baums je Zeile; Bezeichnung, Beschreibung und `extends`
#' in der ersten Zeile. Nicht darstellbare Felder stehen als Ganzes (Pfad leer, YAML).
#' @noRd
io_xl_variant_rows <- function(role, id, el, st) {
  base <- path_join(role, id)
  idcell <- io_xl_id_cell(id)
  first <- list(.id = idcell)
  if (!is_map(el) || length(el) == 0L) {
    first$.value <- io_xl_cell_str(io_xl_flow(el))
    first$.order <- io_xl_cell_str("*")
    return(list(io_xl_row(first)))
  }
  head_fields <- c("label", "description", if (role == "variants") "extends")
  str_param <- io_xl_meta_param("string")
  rows <- list()
  op_row <- function(action, path, v, mode_path) {
    cells <- list(.id = idcell, .action = io_xl_cell_str(io_xl_action_label(role, action)))
    if (!is.null(path)) {
      qp <- if (io_xl_needs_quote(path, str_param)) io_xl_quote(path) else path
      cells$.path <- io_xl_cell_str(qp)
    }
    if (!missing(v)) {
      enc <- io_xl_encode(v, mode_path, NULL, st, mode = "kv", ctx = "raw")
      if (!is.null(enc$form)) cells$.form <- enc$form
      cells$.value <- enc$value
      if (!is.null(enc$options)) cells$.options <- enc$options
    }
    io_xl_row(cells)
  }
  for (f in names(el)) {
    v <- el[[f]]
    if (f %in% head_fields && utl_is_string(v)) {
      first[[f]] <- io_xl_cell_str(if (io_xl_needs_quote(v, str_param)) io_xl_quote(v) else v)
      next
    }
    fr <- io_xl_variant_field_rows(role, f, v, base, op_row)
    if (is.null(fr) || !io_xl_check_variant_field(role, f, v, fr, st)) {
      fr <- list(op_row(f, NULL, v, path_join(base, f)))
    }
    rows <- c(rows, fr)
  }
  if (length(rows) == 0L) rows <- list(io_xl_row(list(.id = idcell)))
  for (k in names(first)) rows[[1L]]$cells[[k]] <- first[[k]]
  rows[[1L]]$cells$.order <- io_xl_cell_str(io_xl_flow(names(el)))
  rows
}

#' Bezeichnung einer Aktion (Auswahlliste), sonst der Feldname
#' @noRd
io_xl_action_label <- function(role, action) {
  lst <- io_xl_list(if (role == "scenario_sets") "actions:sets" else "actions:variants")
  hit <- match(action, lst$code)
  if (is.na(hit)) action else lst$label[hit]
}

#' Zeilen eines Felds einer Variante (`NULL` = als Ganzes)
#' @noRd
io_xl_variant_field_rows <- function(role, f, v, base, op_row) {
  if (f %in% c("set", "replace", "add")) {
    if (!is_map(v) || length(v) == 0L || any(!nzchar(names(v)))) return(NULL)
    return(lapply(seq_along(v), function(i) {
      op_row(f, names(v)[i], v[[i]], path_join(base, f, names(v)[i]))
    }))
  }
  if (f == "remove") {
    if (!is.character(v) || length(v) == 0L || anyNA(v)) return(NULL)
    return(lapply(v, function(p) op_row(f, p)))
  }
  if (f %in% c("overrides", "generate")) {
    if (!is_map(v) || length(v) == 0L) return(NULL)
    leaves <- io_xl_tree_leaves(v)
    if (is.null(leaves)) return(NULL)
    return(lapply(leaves, function(lf) {
      op_row(f, lf$path, lf$value, path_join(base, f, lf$path))
    }))
  }
  NULL
}

#' Blätter eines Baums (Overrides): Maps rekursiv; `NULL` bei unzulässigen Schlüsseln
#' @noRd
io_xl_tree_leaves <- function(v) {
  out <- list()
  ok <- TRUE
  walk <- function(x, p) {
    if (!ok) return(invisible(NULL))
    if (is.null(x) || node_is(x) || !is_map(x) || length(x) == 0L ||
          (nzchar(p) && !is.na(utl_value_form_kind(x)))) {
      out[[length(out) + 1L]] <<- list(path = p, value = x)
      return(invisible(NULL))
    }
    nms <- names(x)
    if (any(grepl(".", nms, fixed = TRUE)) || any(!nzchar(nms))) {
      ok <<- FALSE
      return(invisible(NULL))
    }
    for (i in seq_along(x)) walk(x[[i]], path_join(p, nms[i]))
  }
  walk(v, "")
  if (!ok) return(NULL)
  out
}

#' Prüfung der Zeilen eines Variantenfelds (Rücklesen ergibt dasselbe Feld)
#' @noRd
io_xl_check_variant_field <- function(role, f, v, rows, st) {
  rs <- io_xl_reader_state(st)
  dec <- tryCatch(suppressWarnings(suppressMessages(
    io_xl_decode_variant_field(role, f, lapply(rows, function(r) r$cells), rs, "", role)
  )), error = function(e) structure(list(), class = "io_xl_failed"))
  if (inherits(dec, "io_xl_failed")) return(FALSE)
  identical(io_unmark(dec), v)
}

#' Modell des Blatts Korrelationen (ein Paar je Zeile; andere Formen als Ganzes)
#' @noRd
io_xl_model_corr <- function(st) {
  keys <- io_xl_fixed_columns("correlations")
  m <- io_xl_model("correlations", keys)
  m$extra_rows <- 50L
  m$col_list[[".kind"]] <- "corr"
  m$widths <- c(16, 30, 30, 18, 40, 24)
  corr <- st$x$stochastic$correlations
  if (is.null(corr)) return(m)
  if (!is_map(corr) || length(corr) == 0L) {
    m$rows <- list(io_xl_row(list(.value = io_xl_cell_str(io_xl_flow(corr)))))
    return(m)
  }
  for (f in names(corr)) {
    v <- corr[[f]]
    kind <- io_xl_corr_label(f)
    rows <- io_xl_corr_rows(kind, v)
    dec <- NULL
    if (!is.null(rows)) {
      dec <- tryCatch(
        io_xl_decode_corr_pairs(lapply(rows, function(r) r$cells), io_xl_reader_state(st)),
        error = function(e) NULL
      )
    }
    if (is.null(rows) || !identical(dec, v)) {
      rows <- list(io_xl_row(list(.kind = io_xl_cell_str(kind),
                                  .value = io_xl_cell_str(io_xl_flow(v)))))
    }
    m$rows <- c(m$rows, rows)
  }
  m
}

#' Bezeichnung einer Korrelationsart
#' @noRd
io_xl_corr_label <- function(f) {
  lst <- io_xl_list("corr")
  hit <- match(f, lst$code)
  if (is.na(hit)) io_xl_quote(f) else lst$label[hit]
}

#' Zeilen der Paare `[a, b, rho]` (`NULL`, wenn die Liste keine solche Form hat)
#' @noRd
io_xl_corr_rows <- function(kind, v) {
  if (!is.list(v) || !is.null(names(v)) || length(v) == 0L) return(NULL)
  str_param <- io_xl_meta_param("string")
  rows <- list()
  for (e in v) {
    ok <- is.list(e) && is.null(names(e)) && length(e) == 3L && utl_is_string(e[[1L]]) &&
      utl_is_string(e[[2L]]) && is.numeric(e[[3L]]) && length(e[[3L]]) == 1L &&
      is.finite(e[[3L]])
    if (!ok) return(NULL)
    q <- function(s) io_xl_cell_str(if (io_xl_needs_quote(s, str_param)) io_xl_quote(s) else s)
    rows[[length(rows) + 1L]] <- io_xl_row(list(.kind = io_xl_cell_str(kind), .a = q(e[[1L]]),
                                                .b = q(e[[2L]]),
                                                .rho = io_xl_cell_num(e[[3L]])))
  }
  rows
}

#' Modell des Blatts Zeitreihen
#' @noRd
io_xl_model_series <- function(st) {
  fixed <- io_xl_fixed_columns("series")
  tkeys <- io_xl_series_keys(st)
  keys <- c(fixed, tkeys)
  headers <- c(vapply(fixed, io_xl_column_label, ""),
               ifelse(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", tkeys),
                      format(as.Date(tkeys, optional = TRUE), "%d.%m.%Y"), tkeys))
  cs <- stats::setNames(rep("input", length(keys)), keys)
  cs[c(".label", ".unit")] <- "info"
  m <- io_xl_model("series", keys, headers = headers, col_style = cs)
  m$extra_rows <- 30L
  m$col_list[[".form"]] <- "forms"
  m$widths <- c(30, 30, 18, 12, 22, rep(10, length(tkeys)))
  for (row in st$series) {
    cells <- list(.id = io_xl_cell_str(row$id), .label = io_xl_cell_str(row$label),
                  .form = io_xl_form_cells(row$form, NULL, list(), st)$form,
                  .unit = io_xl_cell_str(row$unit))
    if (length(row$options) > 0L) cells$.options <- io_xl_cell_str(io_xl_options_text(row$options))
    for (i in seq_along(row$keys)) cells[[row$keys[i]]] <- row$cells[[i]]
    m$rows[[length(m$rows) + 1L]] <- io_xl_row(cells)
  }
  m
}

#' Modell des Blatts _meta (Versionen, Reihenfolge und leere Blöcke, unbekannte Blöcke)
#' @noRd
io_xl_model_meta <- function(st) {
  keys <- io_xl_fixed_columns("meta")
  m <- io_xl_model("meta", keys)
  m$widths <- c(22, 40, 60)
  add <- function(key, value, extra = NULL) {
    cells <- list(.key = io_xl_cell_str(key))
    if (!is.null(value)) cells$.value <- value
    if (!is.null(extra)) cells$.extra <- io_xl_cell_str(extra)
    m$rows[[length(m$rows) + 1L]] <<- io_xl_row(cells)
  }
  x <- st$x
  sv <- if (!is.null(x) && "schema_version" %in% names(x)) x$schema_version else 1L
  add("schema_version", io_xl_value_cell(sv, io_xl_meta_param("string"), "schema_version", st))
  add("template_version", io_xl_cell_num(io_xl_template_version()))
  add("package_version", io_xl_cell_str(as.character(utils::packageVersion("vofi"))))
  if (is.null(x)) return(m)
  known <- c("schema_version", utl_scenario_blocks())
  for (b in names(x)) {
    v <- x[[b]]
    if (!(b %in% known)) {
      add("block", io_xl_cell_str(b), io_xl_flow(v))
    } else if (is.list(v) && length(v) == 0L) {
      add("block", io_xl_cell_str(b), if (is.null(names(v))) "[]" else "{}")
    } else {
      add("block", io_xl_cell_str(b))
    }
  }
  if (is_map(x$stochastic) && length(x$stochastic) > 0L) {
    add("order", io_xl_cell_str("stochastic"), io_xl_flow(names(x$stochastic)))
  }
  m
}

#' Modell des Blatts Anleitung
#' @noRd
io_xl_model_instructions <- function() {
  m <- io_xl_model("instructions", "text", headers = "")
  m$widths <- 140
  m$freeze <- NULL
  m$rows <- lapply(io_xl_instruction_rows(), function(r) {
    io_xl_row(list(text = io_xl_cell_str(r$text)), style = r$style)
  })
  m
}

#' Modell des Blatts Listen (je Liste zwei Spalten: Code und Bezeichnung)
#' @noRd
io_xl_model_lists <- function(st) {
  names_used <- utl_sort(unique(st$lists_used))
  keys <- character(0)
  headers <- character(0)
  for (nm in names_used) {
    keys <- c(keys, nm, paste0(nm, "#label"))
    headers <- c(headers, lbl("excel_input.columns.code"), nm)
  }
  m <- io_xl_model("lists", keys, headers = headers,
                   col_style = stats::setNames(rep("info", length(keys)), keys))
  m$freeze <- NULL
  lists <- lapply(names_used, io_xl_list)
  n <- max(c(0L, vapply(lists, nrow, integer(1))))
  st$list_ranges <- list()
  sheet <- gsub("'", "''", io_xl_sheet_name("lists"), fixed = TRUE)
  for (k in seq_along(names_used)) {
    col <- openxlsx::int2col(2L * k)
    nr <- nrow(lists[[k]])
    st$list_ranges[[names_used[k]]] <- if (nr > 0L) {
      paste0("'", sheet, "'!$", col, "$3:$", col, "$", nr + 2L)
    } else {
      NULL
    }
  }
  for (i in seq_len(n)) {
    cells <- list()
    for (k in seq_along(names_used)) {
      l <- lists[[k]]
      if (i > nrow(l)) next
      cells[[names_used[k]]] <- io_xl_cell_str(l$code[i])
      cells[[paste0(names_used[k], "#label")]] <- io_xl_cell_str(l$label[i])
    }
    m$rows[[i]] <- io_xl_row(cells)
  }
  m$widths <- rep(c(18, 34), length(names_used))
  m
}

# ---------------------------------------------------------------------------------------------
# Ausgabe eines Modells in die Arbeitsmappe
# ---------------------------------------------------------------------------------------------

#' Stil (Zwischenspeicher je Arbeitsmappe)
#' @noRd
io_xl_style <- function(st, base, fmt = NULL) {
  key <- paste(base, fmt %||% "")
  st$styles <- st$styles %||% list()
  if (!is.null(st$styles[[key]])) return(st$styles[[key]])
  args <- switch(base,
    key = list(fontColour = "#7F7F7F", fontSize = 8, fgFill = "#F2F2F2"),
    header = list(textDecoration = "bold", fgFill = "#D9D9D9", wrapText = TRUE,
                  valign = "top", border = "Bottom", locked = TRUE),
    input = list(fgFill = "#FFF2CC", locked = FALSE),
    info = list(fgFill = "#EDEDED", fontColour = "#404040", locked = TRUE),
    block = list(textDecoration = "bold", fgFill = "#DDEBF7", locked = TRUE),
    title = list(textDecoration = "bold", fontSize = 14),
    subtitle = list(textDecoration = "bold", fontSize = 11),
    text = list(wrapText = FALSE),
    disabled = list(bgFill = "#BFBFBF", fontColour = "#7F7F7F"),
    comment = list(fontSize = 9),
    list()
  )
  if (!is.null(fmt)) args$numFmt <- fmt
  s <- do.call(openxlsx::createStyle, args)
  st$styles[[key]] <- s
  s
}

#' Spalte als Folgen gleichartiger Zellen schreiben (leere Zellen überschreiben nichts)
#' @noRd
io_xl_write_column <- function(wb, sheet, col, cells, start_row) {
  n <- length(cells)
  if (n == 0L) return(invisible(NULL))
  types <- vapply(cells, function(cl) if (is.null(cl)) NA_character_ else cl$t, "")
  i <- 1L
  while (i <= n) {
    if (is.na(types[i])) {
      i <- i + 1L
      next
    }
    t <- types[i]
    j <- i
    while (j < n && (is.na(types[j + 1L]) || types[j + 1L] == t)) j <- j + 1L
    while (is.na(types[j])) j <- j - 1L
    idx <- i:j
    vals <- lapply(cells[idx], function(cl) cl$v)
    empty <- vapply(vals, is.null, logical(1))
    vec <- switch(t,
      num = {
        txt <- rep(NA_character_, length(vals))
        txt[!empty] <- vapply(vals[!empty], io_xl_num_text, "")
        structure(txt, class = "numeric")
      },
      str = {
        txt <- rep(NA_character_, length(vals))
        txt[!empty] <- as.character(unlist(vals[!empty]))
        txt
      },
      bool = {
        lg <- rep(NA, length(vals))
        lg[!empty] <- as.logical(unlist(vals[!empty]))
        lg
      }
    )
    openxlsx::writeData(wb, sheet, vec, startCol = col, startRow = start_row + i - 1L,
                        colNames = FALSE, keepNA = FALSE)
    i <- j + 1L
  }
  invisible(NULL)
}

#' Modell ausgeben
#' @noRd
io_xl_render <- function(wb, m, st) {
  sheet <- m$name
  openxlsx::addWorksheet(wb, sheet)
  keys <- m$keys
  nk <- length(keys)
  if (m$kind == "text") {
    io_xl_write_column(wb, sheet, 1L, lapply(m$rows, function(r) r$cells$text), 1L)
    for (s in c("title", "subtitle", "input", "info")) {
      rr <- which(vapply(m$rows, function(r) r$style == s, logical(1)))
      if (length(rr) > 0L) {
        base <- if (s %in% c("input", "info")) s else s
        openxlsx::addStyle(wb, sheet, io_xl_style(st, base), rows = rr, cols = 1L,
                           gridExpand = TRUE, stack = TRUE)
      }
    }
    openxlsx::setColWidths(wb, sheet, 1L, m$widths)
    return(invisible(NULL))
  }
  head <- as.data.frame(t(c(keys)), stringsAsFactors = FALSE)
  openxlsx::writeData(wb, sheet, head, startRow = 1L, colNames = FALSE)
  hdr <- as.data.frame(t(c(m$headers)), stringsAsFactors = FALSE)
  openxlsx::writeData(wb, sheet, hdr, startRow = 2L, colNames = FALSE)
  nr <- length(m$rows)
  for (j in seq_len(nk)) {
    cells <- lapply(m$rows, function(r) r$cells[[keys[j]]])
    io_xl_write_column(wb, sheet, j, cells, 3L)
  }
  openxlsx::addStyle(wb, sheet, io_xl_style(st, "key"), rows = 1L, cols = seq_len(nk),
                     gridExpand = TRUE)
  openxlsx::addStyle(wb, sheet, io_xl_style(st, "header"), rows = 2L, cols = seq_len(nk),
                     gridExpand = TRUE)
  io_xl_render_styles(wb, sheet, m, st)
  io_xl_render_validation(wb, sheet, m, st)
  for (k in names(m$cond)) {
    j <- match(k, keys)
    if (is.na(j)) next
    openxlsx::conditionalFormatting(wb, sheet, cols = j, rows = 3L:(nr + m$extra_rows + 2L),
                                    rule = m$cond[[k]], type = "expression",
                                    style = io_xl_style(st, "disabled"))
  }
  for (k in names(m$comments)) {
    j <- match(k, keys)
    if (is.na(j) || !nzchar(m$comments[[k]])) next
    openxlsx::writeComment(wb, sheet, col = j, row = 2L,
                           comment = openxlsx::createComment(m$comments[[k]], author = "vofi",
                                                             style = io_xl_style(st, "comment"),
                                                             visible = FALSE, width = 3,
                                                             height = 4))
  }
  widths <- m$widths
  if (is.null(widths)) {
    widths <- vapply(seq_len(nk), function(j) {
      if (startsWith(keys[j], ".") && keys[j] %in% c(".order", ".seq")) 6 else 18
    }, double(1))
  }
  openxlsx::setColWidths(wb, sheet, seq_len(nk), widths[seq_len(nk)])
  if (!is.null(m$freeze)) {
    openxlsx::freezePane(wb, sheet, firstActiveRow = m$freeze[1L], firstActiveCol = m$freeze[2L])
  }
  openxlsx::groupRows(wb, sheet, rows = 1L, hidden = TRUE)
  invisible(NULL)
}

#' Stile der Datenzellen (gruppiert nach Stil und Format)
#' @noRd
io_xl_render_styles <- function(wb, sheet, m, st) {
  keys <- m$keys
  groups <- list()
  addg <- function(base, fmt, r, c) {
    k <- paste(base, fmt %||% "", sep = "\r")
    g <- groups[[k]] %||% list(base = base, fmt = fmt, rows = integer(0), cols = integer(0))
    g$rows <- c(g$rows, r)
    g$cols <- c(g$cols, c)
    groups[[k]] <<- g
  }
  nr <- length(m$rows)
  for (i in seq_len(nr)) {
    r <- m$rows[[i]]
    for (j in seq_along(keys)) {
      k <- keys[j]
      base <- if (r$style == "block") "block" else m$col_style[[k]] %||% "input"
      cell <- r$cells[[k]]
      fmt <- NULL
      if (base == "input") {
        fmt <- if (m$kind == "kv" && k == "value") r$fmt else m$col_fmt[[k]]
        if (isTRUE(cell$date)) fmt <- "DATE"
      }
      if (!is.null(cell) && isTRUE(cell$date) && base != "input") fmt <- "DATE"
      addg(base, fmt, 2L + i, j)
    }
  }
  if (m$extra_rows > 0L) {
    rows <- (nr + 3L):(nr + 2L + m$extra_rows)
    for (j in seq_along(keys)) {
      base <- m$col_style[[keys[j]]] %||% "input"
      fmt <- if (base == "input") m$col_fmt[[keys[j]]] else NULL
      addg(base, fmt, rep(rows, 1L), rep(j, length(rows)))
    }
  }
  for (g in groups) {
    openxlsx::addStyle(wb, sheet, io_xl_style(st, g$base, g$fmt), rows = g$rows, cols = g$cols,
                       gridExpand = FALSE, stack = FALSE)
  }
  invisible(NULL)
}

#' Auswahllisten (Datenüberprüfung) der Zellen
#' @noRd
io_xl_render_validation <- function(wb, sheet, m, st) {
  keys <- m$keys
  nr <- length(m$rows)
  dv <- function(col, rows, ln) {
    rng <- st$list_ranges[[ln]]
    if (is.null(rng)) return(invisible(NULL))
    strict <- !(ln %in% c("logical", "library:funding") || startsWith(ln, "types:") ||
                  ln == "forms")
    withCallingHandlers(
      openxlsx::dataValidation(wb, sheet, cols = col, rows = rows, type = "list", value = rng,
                               allowBlank = TRUE, showInputMsg = FALSE, showErrorMsg = strict),
      warning = function(w) invokeRestart("muffleWarning")
    )
  }
  if (m$kind == "kv") {
    jv <- match("value", keys)
    if (nr > 0L) dv(match("form", keys), 3L:(nr + 2L), "forms")
    for (i in seq_len(nr)) {
      r <- m$rows[[i]]
      if (r$style != "block" && !is.null(r$list)) dv(jv, 2L + i, r$list)
    }
    return(invisible(NULL))
  }
  last <- nr + m$extra_rows + 2L
  if (last < 3L) return(invisible(NULL))
  for (k in names(m$col_list)) {
    j <- match(k, keys)
    if (!is.na(j)) dv(j, 3L:last, m$col_list[[k]])
  }
  invisible(NULL)
}
