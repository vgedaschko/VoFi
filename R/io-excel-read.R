# Excel-Arbeitsmappe einlesen (WS-A2, Spec 00 Abschnitte 4.6, 4.8, 4.14; R-26).
#
# io_read_excel() ist der Lese-Hook von vofi_read_scenario(format = "excel") (R/scenario-read.R,
# WS-A). Gelesen wird ausschliesslich mit openxlsx::read.xlsx() (R-26). Weil read.xlsx() in
# Spalten mit gemischten Zellarten alle Werte als Text liefert, wird ein Blatt mit Zellen, die
# wie Zahlen oder Wahrheitswerte aussehen, ein zweites Mal mit na.strings = <diese Texte> gelesen:
# Textzellen werden dabei NA, Zahlen- und Wahrheitswertzellen nicht. So sind Zahlenzellen (exakt,
# gebietsschemaunabhaengig) und als Text eingegebene Zahlen (Regeln aus 4.6 ueber io_as_number(),
# z. B. Dezimalkomma mit Warnung, Tausenderpunkt bei EUR als Fehler) unterscheidbar.
#
# Regeln der Zellen (Gegenstueck: R/io-excel-write.R):
#   leer            nicht gesetzt
#   Zahl            double; bei Feldern der Art date/timing Seriennummer >= 10000 -> Datum
#   Wahrheitswert   logical
#   Text "~"        explizites NULL
#   Text { ... } bzw. [ ... ]   YAML-Flussnotation; {timeseries: <id>} = Zeile im Blatt Zeitreihen
#   Text "..."      Zeichenkette (YAML-Anfuehrungszeichen)
#   Text sonst      Codes: deutsche Bezeichnung der Auswahlliste -> Code; id-Listen: Komma;
#                   numerische Felder: Zahl nach 4.6 (io_as_number); sonst Zeichenkette
# Das Ergebnis wird normalisiert (Normalisierung von WS-A, idempotent); Meldungen der
# Normalisierung nennen Blatt und Zelle (Herkunft "Blatt!Zelle", 4.8).

#' Excel-Arbeitsmappe eines Szenarios lesen (Hook für `vofi_read_scenario()`)
#' @param path Datei (`.xlsx`).
#' @return Liste der Blöcke (normalisiert) mit Attribut `locations` (Pfad -> `"Blatt!Zelle"`).
#' @noRd
io_read_excel <- function(path) {
  io_xl_cache_reset()
  rs <- io_xl_new_reader(path)
  out <- io_xl_with_locations(rs, {
    io_xl_read_book(rs)
    raw <- io_xl_assemble(rs)
    scn_normalize(raw)
  })
  attr(out, "locations") <- rs$locations
  out
}

#' Lesezustand
#' @noRd
io_xl_new_reader <- function(path) {
  rs <- new.env(parent = emptyenv())
  rs$path <- path
  rs$locations <- character(0)
  rs$types <- character(0)
  rs$series <- list()
  rs$series_used <- character(0)
  rs$label_maps <- list()
  rs$parts <- list()
  rs$meta <- list(order = character(0), empty = list(), extra = list(), children = list())
  rs
}

#' NULL-Markierung (Zelle "~", explizites NULL)
#' @noRd
io_xl_null <- function() structure(list(), class = "io_xl_null")

#' Markierung in NULL umwandeln
#' @noRd
io_xl_unnull <- function(x) if (inherits(x, "io_xl_null")) NULL else x

# ---------------------------------------------------------------------------------------------
# Meldungen mit Blatt und Zelle
# ---------------------------------------------------------------------------------------------

#' Ausdruck auswerten; Fehler, Warnungen und Hinweise mit Pfad erhalten Blatt und Zelle
#' @noRd
io_xl_with_locations <- function(rs, expr) {
  tryCatch(
    withCallingHandlers(expr,
      vofi_warning = function(w) {
        w2 <- io_xl_locate(w, rs)
        if (!identical(w2, w)) {
          warning(w2)
          invokeRestart("muffleWarning")
        }
      },
      vofi_message = function(m) {
        m2 <- io_xl_locate(m, rs)
        if (!identical(m2, m)) {
          message(m2)
          invokeRestart("muffleMessage")
        }
      }
    ),
    vofi_error = function(e) stop(io_xl_locate(e, rs))
  )
}

#' Bedingung um die Fundstelle ergänzen (längster bekannter Pfadpräfix)
#' @noRd
io_xl_locate <- function(cond, rs) {
  if (isTRUE(cond$data$io_xl_located)) return(cond)
  args <- cond$args %||% list()
  path <- args$path %||% args$arg %||% args$target
  loc <- if (utl_is_string(path)) io_location_of(rs$locations, path) else NA_character_
  if (is.na(loc)) return(cond)
  txt <- lbl("excel_input.at_cell", location = loc)
  msg_text <- cond$message
  nl <- endsWith(msg_text, "\n")
  if (nl) msg_text <- substr(msg_text, 1L, nchar(msg_text) - 1L)
  cond$message <- paste0(msg_text, txt, if (nl) "\n")
  cond$data$location <- loc
  cond$data$io_xl_located <- TRUE
  cond
}

#' Fundstelle eintragen
#' @noRd
io_xl_set_loc <- function(rs, path, sheet, row, col) {
  if (!utl_is_string(path) || !nzchar(path)) return(invisible(NULL))
  rs$locations[path] <- paste0(sheet, "!", openxlsx::int2col(col), row)
  invisible(NULL)
}

#' Fundstelle als Text
#' @noRd
io_xl_loc_text <- function(sheet, row, col) paste0(sheet, "!", openxlsx::int2col(col), row)

# ---------------------------------------------------------------------------------------------
# Blätter lesen (zwei Durchgänge, Zellarten)
# ---------------------------------------------------------------------------------------------

#' Blattnamen der Datei (Fehler bei nicht lesbarer Datei)
#' @noRd
io_xl_sheet_names <- function(path) {
  res <- tryCatch(openxlsx::getSheetNames(path), error = function(e) e,
                  warning = function(w) w)
  if (inherits(res, "condition") || !is.character(res)) {
    vofi_abort("excel_input.read_failed", path = path,
               detail = if (inherits(res, "condition")) conditionMessage(res) else "",
               .class = "vofi_error_input")
  }
  res
}

#' Blatt lesen: Raster mit Zellart (`num`, `str`, `bool`) und Wert
#' @return Liste `n`, `m`, `type` (chr-Matrix, NA = leer), `num`, `str`, `lgl`, `sheet`.
#' @noRd
io_xl_read_grid <- function(path, sheet) {
  rd <- function(na) {
    read <- function() {
      openxlsx::read.xlsx(path, sheet = sheet, colNames = FALSE, skipEmptyRows = FALSE,
                          skipEmptyCols = FALSE, detectDates = FALSE, na.strings = na)
    }
    res <- tryCatch(suppressWarnings(read()), error = function(e) e)
    if (inherits(res, "error")) {
      vofi_abort("excel_input.read_failed", path = path, detail = conditionMessage(res),
                 .class = "vofi_error_input")
    }
    res
  }
  d1 <- rd(character(0))
  if (is.null(d1) || nrow(d1) == 0L || ncol(d1) == 0L) {
    return(list(n = 0L, m = 0L, sheet = sheet))
  }
  n <- nrow(d1)
  m <- ncol(d1)
  type <- matrix(NA_character_, n, m)
  num <- matrix(NA_real_, n, m)
  str <- matrix(NA_character_, n, m)
  lgl <- matrix(NA, n, m)
  cand_re <- "^[-+]?([0-9]+[.]?[0-9]*|[.][0-9]+)([eE][-+]?[0-9]+)?$"
  cands <- character(0)
  for (j in seq_len(m)) {
    col <- d1[[j]]
    if (is.character(col)) {
      cc <- col[!is.na(col) & (grepl(cand_re, col) | col %in% c("TRUE", "FALSE"))]
      cands <- c(cands, cc)
    }
  }
  cands <- unique(cands)
  d2 <- if (length(cands) > 0L) rd(cands) else NULL
  for (j in seq_len(m)) {
    col <- d1[[j]]
    ok <- !is.na(col)
    if (is.numeric(col)) {
      type[ok, j] <- "num"
      num[ok, j] <- as.double(col[ok])
    } else if (is.logical(col)) {
      type[ok, j] <- "bool"
      lgl[ok, j] <- col[ok]
    } else {
      col <- as.character(col)
      type[ok, j] <- "str"
      str[ok, j] <- enc2utf8(col[ok])
      if (!is.null(d2)) {
        hit <- which(ok & col %in% cands)
        for (i in hit) {
          v2 <- if (j <= ncol(d2) && i <= nrow(d2)) d2[[j]][i] else NA
          if (is.na(v2)) next
          if (col[i] %in% c("TRUE", "FALSE")) {
            type[i, j] <- "bool"
            lgl[i, j] <- identical(col[i], "TRUE")
          } else {
            type[i, j] <- "num"
            num[i, j] <- as.double(col[i])
          }
        }
      }
    }
  }
  list(n = n, m = m, type = type, num = num, str = str, lgl = lgl, sheet = sheet)
}

#' Zelle des Rasters (`NULL` = leer)
#' @noRd
io_xl_grid_cell <- function(g, i, j) {
  if (is.na(j) || i > g$n || j > g$m || i < 1L || j < 1L) return(NULL)
  t <- g$type[i, j]
  if (is.na(t)) return(NULL)
  switch(t,
    num = list(t = "num", v = g$num[i, j]),
    bool = list(t = "bool", v = g$lgl[i, j]),
    str = if (nzchar(g$str[i, j])) list(t = "str", v = g$str[i, j]) else NULL
  )
}

#' Maschinenschlüssel (Zeile 1) eines Rasters
#' @noRd
io_xl_grid_keys <- function(g) {
  vapply(seq_len(g$m), function(j) {
    cell <- io_xl_grid_cell(g, 1L, j)
    if (is.null(cell)) NA_character_ else io_xl_cell_text(cell)
  }, "")
}

#' Text einer Zelle (Zahlen in exakter Darstellung)
#' @noRd
io_xl_cell_text <- function(cell) {
  if (is.null(cell)) return(NA_character_)
  switch(cell$t,
    num = io_xl_num_text(cell$v),
    bool = if (isTRUE(cell$v)) "TRUE" else "FALSE",
    as.character(cell$v)
  )
}

#' Rolle eines Blattnamens (Label oder Rollenname, ohne Groß-/Kleinschreibung)
#' @noRd
io_xl_role_of_sheet <- function(name) {
  key <- tolower(trimws(name))
  for (r in io_xl_roles()) {
    if (key %in% tolower(c(io_xl_sheet_name(r), r))) return(r)
  }
  NA_character_
}

#' Alle Blätter lesen und zerlegen
#' @noRd
io_xl_read_book <- function(rs) {
  names <- io_xl_sheet_names(rs$path)
  roles <- vapply(names, io_xl_role_of_sheet, "")
  if (!any(!is.na(roles) & !(roles %in% c("instructions", "lists")))) {
    vofi_abort("excel_input.no_sheets", path = rs$path, .class = "vofi_error_input")
  }
  order <- c("lists", "meta", "series", "financing", "components", "unit_groups", "measures",
             "funding", "parameters", "processes", "correlations", "variants", "scenario_sets",
             "project", "household", "market", "building", "settings")
  for (r in order) {
    hit <- which(roles == r)
    if (length(hit) == 0L) next
    if (length(hit) > 1L) {
      vofi_abort("excel_input.sheet_duplicate", sheet = names[hit[2L]],
                 .class = "vofi_error_input")
    }
    sheet <- names[hit]
    g <- io_xl_read_grid(rs$path, sheet)
    if (g$n == 0L) next
    keys <- io_xl_grid_keys(g)
    switch(io_xl_kind(r),
      lists = io_xl_parse_lists(g, keys, rs),
      meta = io_xl_parse_meta(g, keys, rs),
      series = io_xl_parse_series(g, keys, rs),
      wide = io_xl_parse_wide(r, g, keys, rs),
      long = io_xl_parse_long(r, g, keys, rs),
      corr = io_xl_parse_corr(g, keys, rs),
      kv = io_xl_parse_kv(g, keys, rs)
    )
  }
  unused <- setdiff(names(rs$series), rs$series_used)
  if (length(unused) > 0L) {
    vofi_inform("excel_input.series_unused", ids = utl_collapse(unused))
  }
  invisible(rs)
}

#' Spalte eines Maschinenschlüssels (Pflichtspalte: Fehler mit Blatt)
#' @noRd
io_xl_col <- function(keys, key, g, required = TRUE) {
  j <- match(key, keys)
  if (is.na(j) && required) {
    vofi_abort("excel_input.column_missing", sheet = g$sheet, column = key,
               .class = "vofi_error_input")
  }
  j
}

# ---------------------------------------------------------------------------------------------
# Zellen deuten
# ---------------------------------------------------------------------------------------------

#' Ist der Parameter ein EUR-Betrag (Tausenderpunkt-Regel, 4.6)?
#' @noRd
io_xl_eur <- function(param, path) {
  identical(param$kind, "amount") || (utl_is_string(param$unit) && startsWith(param$unit, "EUR")) ||
    io_path_is_eur(path)
}

#' Zelle deuten (Regeln im Dateikopf)
#' @param cell Zelle oder `NULL`.
#' @param param `vofi_param` oder `NULL` (allgemeine Wertgrammatik).
#' @param path Pfad (Meldungen, Auswahlliste).
#' @param rs Lesezustand.
#' @param list_name Auswahlliste (Default nach Pfad und Parameter).
#' @return Wert, `io_xl_null()` oder `NULL` (leer).
#' @noRd
io_xl_decode_cell <- function(cell, param, path, rs, list_name = io_xl_list_for(path, param)) {
  if (is.null(cell)) return(NULL)
  kind <- param$kind %||% "value"
  if (cell$t == "bool") return(isTRUE(cell$v))
  if (cell$t == "num") {
    v <- cell$v
    if (kind %in% c("date", "timing") && is.finite(v) && v >= 10000) {
      return(format(as.Date(v - 25569, origin = "1970-01-01"), "%Y-%m-%d"))
    }
    return(v)
  }
  s <- cell$v
  tt <- trimws(s)
  if (!nzchar(tt)) return(NULL)
  if (tt == "~") return(io_xl_null())
  if (substr(tt, 1L, 1L) %in% c("{", "[", "\"", "'")) return(io_xl_parse_flow(tt, path, rs))
  if (kind %in% c("date", "timing") && grepl(io_xl_de_date_pattern(), tt)) {
    parts <- as.integer(strsplit(tt, ".", fixed = TRUE)[[1L]])
    return(sprintf("%04d-%02d-%02d", parts[3L], parts[2L], parts[1L]))
  }
  if (!is.null(list_name) && list_name != "logical") {
    code <- io_xl_label_to_code(list_name, s, rs)
    if (!is.null(code)) return(code)
  }
  if (identical(kind, "ids")) return(trimws(strsplit(s, ",", fixed = TRUE)[[1L]]))
  if (io_xl_numeric_ctx(param)) {
    v <- io_as_number(tt, path, eur = io_xl_eur(param, path))
    if (!is.null(v)) return(v)
  }
  s
}

#' Zelle als Zeichenkette (ids, Pfade, Bezeichnungen)
#' @noRd
io_xl_decode_string <- function(cell, path, rs) {
  if (is.null(cell)) return(NULL)
  if (cell$t != "str") return(io_xl_cell_text(cell))
  v <- io_xl_decode_cell(cell, io_xl_meta_param("string"), path, rs, list_name = NULL)
  if (inherits(v, "io_xl_null")) return(NULL)
  if (!utl_is_string(v)) {
    vofi_abort("excel_input.not_text", path = path, value = cell$v, .class = "vofi_error_input")
  }
  v
}

#' YAML-Flussnotation einer Zelle lesen (Handler aus 4.6; Zeitreihen-Verweis)
#' @noRd
io_xl_parse_flow <- function(text, path, rs) {
  res <- tryCatch(yaml::yaml.load(text, handlers = io_yaml_handlers(), eval.expr = FALSE),
                  error = function(e) e)
  if (inherits(res, "error")) {
    vofi_abort("excel_input.yaml_invalid", path = path, value = text,
               detail = conditionMessage(res), .class = "vofi_error_input")
  }
  if (is.null(res)) return(io_xl_null())
  if (is_map(res) && identical(names(res), "timeseries") && utl_is_string(res$timeseries)) {
    return(io_xl_series_value(res$timeseries, path, rs))
  }
  res
}

#' Code zu einer deutschen Bezeichnung einer Auswahlliste (`NULL`, wenn keine passt)
#' @noRd
io_xl_label_to_code <- function(list_name, text, rs) {
  lst <- tryCatch(io_xl_list(list_name), error = function(e) NULL)
  if (!is.null(lst)) {
    hit <- match(text, lst$label)
    if (!is.na(hit)) return(lst$code[hit])
    if (text %in% lst$code) return(text)
  }
  fm <- rs$label_maps[[list_name]]
  if (!is.null(fm)) {
    hit <- match(text, fm$label)
    if (!is.na(hit)) return(fm$code[hit])
  }
  NULL
}

#' Wertform aus der Zelle Wertform (Code oder Bezeichnung)
#' @noRd
io_xl_form_code <- function(cell, path, rs) {
  if (is.null(cell)) return("")
  s <- trimws(io_xl_cell_text(cell))
  if (!nzchar(s)) return("")
  code <- io_xl_label_to_code("forms", s, rs)
  if (is.null(code)) {
    vofi_abort("excel_input.form_unknown", path = path, value = s,
               choices = utl_collapse(io_xl_list("forms")$code), .class = "vofi_error_input")
  }
  code
}

#' Optionen einer Wertform (`scale: 2, anchor: 0.01` bzw. `{...}`) als Map
#' @noRd
io_xl_decode_options <- function(cell, path, rs) {
  if (is.null(cell)) return(list())
  s <- trimws(io_xl_cell_text(cell))
  if (!nzchar(s)) return(list())
  if (!startsWith(s, "{")) s <- paste0("{", s, "}")
  v <- io_xl_parse_flow(s, path, rs)
  if (!is_map(v)) {
    vofi_abort("excel_input.options_invalid", path = path, value = s,
               .class = "vofi_error_input")
  }
  if (length(v) == 0L) list() else v
}

#' Blatt mit Wertform deuten (Wertform, Wert, Optionen)
#' @return Wert in YAML-Form, `io_xl_null()` oder `NULL` (leer).
#' @noRd
io_xl_decode_leaf <- function(form_cell, value_cell, options_cell, param, path, rs) {
  form <- io_xl_form_code(form_cell, path, rs)
  opts <- io_xl_decode_options(options_cell, path, rs)
  if (form %in% c("", "const")) {
    if (length(opts) > 0L) {
      vofi_abort("excel_input.options_without_form", path = path, .class = "vofi_error_input")
    }
    return(io_xl_decode_cell(value_cell, param, path, rs))
  }
  if (is.null(value_cell) && form != "auto") {
    vofi_abort("excel_input.form_value_missing", path = path, form = form,
               .class = "vofi_error_input")
  }
  text <- if (is.null(value_cell)) "" else io_xl_cell_text(value_cell)
  tt <- trimws(text)
  switch(form,
    series_t = , series_year = , points = , schedule = {
      v <- if (substr(tt, 1L, 1L) %in% c("{", "[")) {
        io_xl_parse_flow(tt, path, rs)
      } else {
        io_xl_series_value(tt, path, rs, expect = form)
      }
      if (length(opts) > 0L && is_map(v)) {
        for (k in names(opts)) v[k] <- list(opts[[k]])
      }
      v
    },
    ref = c(list(ref = tt), opts),
    expr = {
      if (length(opts) > 0L) {
        vofi_abort("excel_input.options_invalid", path = path,
                   value = io_xl_cell_text(options_cell), .class = "vofi_error_input")
      }
      list(expr = text)
    },
    growth = c(list(start = io_xl_unnull(io_xl_decode_cell(value_cell, NULL,
                                                           path_join(path, "start"), rs))),
               opts),
    quantity = c(list(value = io_xl_unnull(io_xl_decode_cell(value_cell, NULL,
                                                             path_join(path, "value"), rs))),
                 opts),
    auto = if (tt %in% c("auto", "topup")) tt else "auto",
    from = c(list(from = tt), opts),
    dist = c(list(dist = tt), opts),
    vofi_abort("excel_input.form_unknown", path = path, value = form,
               choices = utl_collapse(io_xl_list("forms")$code), .class = "vofi_error_input")
  )
}

# ---------------------------------------------------------------------------------------------
# Zeitreihen
# ---------------------------------------------------------------------------------------------

#' Spaltenschlüssel einer Zeitreihenspalte aus Zeile 1 bzw. 2 (Jahr, t<k>, Termin)
#' @noRd
io_xl_series_key <- function(cell) {
  if (is.null(cell)) return(NA_character_)
  if (cell$t == "num") {
    v <- cell$v
    if (is.finite(v) && v >= 1000 && v <= 9999 && v == round(v)) {
      return(sprintf("%d", as.integer(v)))
    }
    if (is.finite(v) && v >= 10000) return(format(as.Date(v - 25569, origin = "1970-01-01")))
    return(NA_character_)
  }
  s <- trimws(io_xl_cell_text(cell))
  s <- gsub("[[:space:]=]", "", s)
  if (grepl("^[0-9]{4}$", s) || grepl("^t[0-9]+$", s)) return(s)
  if (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", s)) return(s)
  if (grepl(io_xl_de_date_pattern(), s)) {
    p <- as.integer(strsplit(s, ".", fixed = TRUE)[[1L]])
    return(sprintf("%04d-%02d-%02d", p[3L], p[2L], p[1L]))
  }
  NA_character_
}

#' Blatt Zeitreihen zerlegen
#' @noRd
io_xl_parse_series <- function(g, keys, rs) {
  jid <- io_xl_col(keys, ".id", g)
  jform <- io_xl_col(keys, ".form", g)
  jopt <- io_xl_col(keys, ".options", g)
  fixed <- io_xl_fixed_columns("series")
  tcols <- which(!(keys %in% fixed))
  tkeys <- vapply(tcols, function(j) {
    k <- io_xl_series_key(io_xl_grid_cell(g, 1L, j))
    if (is.na(k)) k <- io_xl_series_key(io_xl_grid_cell(g, 2L, j))
    k
  }, "")
  ok <- !is.na(tkeys)
  tcols <- tcols[ok]
  tkeys <- tkeys[ok]
  if (anyDuplicated(tkeys)) {
    vofi_abort("excel_input.series_key_duplicate", sheet = g$sheet,
               column = tkeys[anyDuplicated(tkeys)], .class = "vofi_error_input")
  }
  for (i in seq_len(g$n)[-(1:2)]) {
    idc <- io_xl_grid_cell(g, i, jid)
    if (is.null(idc)) next
    id <- io_xl_decode_string(idc, "", rs)
    if (is.null(id)) next
    if (id %in% names(rs$series)) {
      vofi_abort("excel_input.series_duplicate", id = id,
                 location = io_xl_loc_text(g$sheet, i, jid), .class = "vofi_error_input")
    }
    form <- io_xl_form_code(io_xl_grid_cell(g, i, jform), id, rs)
    if (!(form %in% c("series_t", "series_year", "points", "schedule"))) {
      vofi_abort("excel_input.series_form", id = id, value = form,
                 location = io_xl_loc_text(g$sheet, i, jform), .class = "vofi_error_input")
    }
    cells <- lapply(tcols, function(j) io_xl_grid_cell(g, i, j))
    filled <- !vapply(cells, is.null, logical(1))
    rs$series[[id]] <- list(
      id = id, form = form, options = io_xl_decode_options(io_xl_grid_cell(g, i, jopt), id, rs),
      keys = tkeys[filled], cells = cells[filled],
      locs = vapply(tcols[filled], function(j) io_xl_loc_text(g$sheet, i, j), ""),
      loc = io_xl_loc_text(g$sheet, i, jid)
    )
  }
  invisible(NULL)
}

#' Wert einer Zeitreihe (Rohform der Wertgrammatik) für den Pfad
#' @param expect erwartete Form (`NULL` = Form der Zeile).
#' @noRd
io_xl_series_value <- function(id, path, rs, expect = NULL) {
  row <- rs$series[[id]]
  if (is.null(row)) {
    vofi_abort("excel_input.series_missing", path = path, id = id, .class = "vofi_error_input")
  }
  if (!is.null(expect) && !identical(row$form, expect)) {
    vofi_abort("excel_input.series_form_mismatch", path = path, id = id, form = row$form,
               expected = expect, .class = "vofi_error_input")
  }
  rs$series_used <- union(rs$series_used, id)
  io_xl_series_raw(row, path, rs)
}

#' Rohform einer Zeitreihenzeile (`series_t`, `series_year`, `points`, `schedule`)
#' @noRd
io_xl_series_raw <- function(row, path, rs) {
  keys <- row$keys
  elem_path <- function(i) {
    switch(row$form, series_t = path_join(path, i), series_year = path_join(path, "series", i),
           points = path_join(path, "values", i), schedule = path_join(path, "schedule", i))
  }
  if (row$form == "series_t") {
    if (!all(grepl("^t[0-9]+$", keys))) {
      vofi_abort("excel_input.series_keys", path = path, id = row$id, form = row$form,
                 .class = "vofi_error_input")
    }
    idx <- as.integer(sub("^t", "", keys))
    ord <- order(idx)
    if (!identical(idx[ord], seq_along(idx) - 1L)) {
      vofi_abort("excel_input.series_gap", path = path, id = row$id,
                 .class = "vofi_error_input")
    }
  } else {
    pat <- if (row$form == "schedule") "^[0-9]{4}(-[0-9]{2}-[0-9]{2})?$" else "^[0-9]{4}$"
    if (!all(grepl(pat, keys))) {
      vofi_abort("excel_input.series_keys", path = path, id = row$id, form = row$form,
                 .class = "vofi_error_input")
    }
    when <- as.Date(ifelse(nchar(keys) == 4L, paste0(keys, "-01-01"), keys))
    ord <- order(when, method = "radix")
  }
  keys <- keys[ord]
  cells <- row$cells[ord]
  if (!is.null(row$locs)) {
    locs <- row$locs[ord]
    for (i in seq_along(keys)) rs$locations[elem_path(i)] <- locs[i]
  }
  vals <- lapply(seq_along(cells), function(i) {
    v <- io_xl_decode_cell(cells[[i]], NULL, elem_path(i), rs, list_name = NULL)
    if (is.null(v) || inherits(v, "io_xl_null")) {
      vofi_abort("excel_input.series_null", path = path, id = row$id,
                 .class = "vofi_error_input")
    }
    v
  })
  opts <- row$options %||% list()
  switch(row$form,
    series_t = {
      if (length(vals) > 0L && all(vapply(vals, function(v) is.numeric(v) && length(v) == 1L,
                                          logical(1)))) {
        as.double(unlist(vals))
      } else {
        vals
      }
    },
    series_year = c(list(series = stats::setNames(vals, keys)), opts),
    points = c(list(years = as.double(keys), values = vals), opts),
    schedule = c(list(schedule = stats::setNames(vals, keys)), opts)
  )
}

# ---------------------------------------------------------------------------------------------
# Bäume aufbauen
# ---------------------------------------------------------------------------------------------

#' Wert an einem Pfad einsetzen (explizites NULL bleibt erhalten; Konflikte sind Fehler)
#' @noRd
io_xl_put <- function(x, segs, value, path, loc) {
  if (length(segs) == 0L) return(value)
  if (is.null(x)) x <- list()
  if (!is.list(x) || (!is_map(x) && length(x) > 0L) || node_is(x)) {
    vofi_abort("excel_input.path_conflict", path = path, location = loc %||% "",
               .class = "vofi_error_input")
  }
  seg <- segs[1L]
  has <- utl_has_name(x, seg)
  if (length(segs) == 1L) {
    if (has) {
      vofi_abort("excel_input.path_duplicate", path = path, location = loc %||% "",
                 .class = "vofi_error_input")
    }
    x[seg] <- list(value)
    return(x)
  }
  child <- if (has) x[[seg]] else NULL
  if (has && (is.null(child) || !is_map(child))) {
    vofi_abort("excel_input.path_conflict", path = path, location = loc %||% "",
               .class = "vofi_error_input")
  }
  x[seg] <- list(io_xl_put(child, segs[-1L], value, path, loc))
  x
}

#' Element aus Paaren (relativer Pfad, Wert) in der Reihenfolge `.order` aufbauen
#' @param pairs Liste `list(rel, value, loc)`.
#' @param order Zeichenvektor der relativen Pfade (oder `NULL`).
#' @param id id des Elements (für ein implizites Feld `id`).
#' @param base Pfad des Elements (Meldungen).
#' @noRd
io_xl_build_element <- function(pairs, order, id, base) {
  rels <- vapply(pairs, function(p) p$rel, "")
  if (!is.null(order) && "id" %in% order && !("id" %in% rels)) {
    pairs[[length(pairs) + 1L]] <- list(rel = "id", value = id, loc = NULL)
    rels <- c(rels, "id")
  }
  if (!is.null(order) && length(pairs) > 1L) {
    pos <- match(rels, order)
    o <- order(ifelse(is.na(pos), length(order) + seq_along(rels), pos), method = "radix")
    pairs <- pairs[o]
  }
  el <- structure(list(), names = character(0))
  for (p in pairs) {
    el <- io_xl_put(el, path_split(p$rel), io_xl_unnull(p$value), path_join(base, p$rel),
                    p$loc)
  }
  el
}

#' `.order` einer Zelle (Liste relativer Pfade, `"*"` = Element als Ganzes, `NULL` = fehlt)
#' @noRd
io_xl_decode_order <- function(cell, path, rs) {
  if (is.null(cell)) return(NULL)
  s <- trimws(io_xl_cell_text(cell))
  if (s == "*") return("*")
  if (!startsWith(s, "[")) return(NULL)
  v <- tryCatch(yaml::yaml.load(s), error = function(e) NULL)
  if (is.null(v) || length(v) == 0L) return(character(0))
  as.character(unlist(v))
}

#' Beitrag eines Blatts zu einem obersten Block
#' @noRd
io_xl_add_part <- function(rs, block, kind, value) {
  rs$parts[[length(rs$parts) + 1L]] <- list(block = block, kind = kind, value = value)
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Blattarten zerlegen
# ---------------------------------------------------------------------------------------------

#' Schlüssel-Wert-Blatt: Datensätze (Pfad, Wert, Reihenfolge) je Block
#' @noRd
io_xl_parse_kv <- function(g, keys, rs) {
  jp <- io_xl_col(keys, "path", g)
  jf <- io_xl_col(keys, "form", g)
  jv <- io_xl_col(keys, "value", g)
  jo <- io_xl_col(keys, "options", g)
  js <- io_xl_col(keys, ".seq", g, required = FALSE)
  for (i in seq_len(g$n)[-(1:2)]) {
    vc <- io_xl_grid_cell(g, i, jv)
    fc <- io_xl_grid_cell(g, i, jf)
    oc <- io_xl_grid_cell(g, i, jo)
    if (is.null(vc) && is.null(fc) && is.null(oc)) next
    pc <- io_xl_grid_cell(g, i, jp)
    if (is.null(pc)) {
      vofi_abort("excel_input.path_missing", location = io_xl_loc_text(g$sheet, i, jp),
                 .class = "vofi_error_input")
    }
    path <- trimws(io_xl_cell_text(pc))
    if (grepl("*", path, fixed = TRUE) || grepl("..", path, fixed = TRUE) ||
          startsWith(path, ".") || endsWith(path, ".")) {
      vofi_abort("excel_input.placeholder_path", path = path,
                 location = io_xl_loc_text(g$sheet, i, jp), .class = "vofi_error_input")
    }
    io_xl_set_loc(rs, path, g$sheet, i, jv)
    param <- io_xl_param_at(path, rs$types)
    value <- io_xl_decode_leaf(fc, vc, oc, param, path, rs)
    if (is.null(value)) next
    sc <- io_xl_grid_cell(g, i, js)
    seq <- if (!is.null(sc) && sc$t == "num") sc$v else NA_real_
    io_xl_add_part(rs, path_split(path)[1L], "kv",
                   list(path = path, value = value, seq = seq,
                        loc = io_xl_loc_text(g$sheet, i, jv)))
  }
  invisible(NULL)
}

#' Breites Blatt (Element je Zeile)
#' @noRd
io_xl_parse_wide <- function(role, g, keys, rs) {
  idkey <- if (role == "parameters") ".key" else ".id"
  jid <- io_xl_col(keys, idkey, g)
  jex <- io_xl_col(keys, ".extra", g, required = FALSE)
  jord <- io_xl_col(keys, ".order", g, required = FALSE)
  prefix <- io_xl_collection_path(role)
  skip <- c(idkey, ".extra", ".order", ".note", ".source")
  fields <- which(!is.na(keys) & !(keys %in% skip))
  coll <- list()
  for (i in seq_len(g$n)[-(1:2)]) {
    idc <- io_xl_grid_cell(g, i, jid)
    filled <- vapply(c(fields, jex), function(j) !is.null(io_xl_grid_cell(g, i, j)),
                     logical(1))
    if (is.null(idc)) {
      if (any(filled)) {
        vofi_abort("excel_input.id_missing", location = io_xl_loc_text(g$sheet, i, jid),
                   .class = "vofi_error_input")
      }
      next
    }
    id <- io_xl_decode_string(idc, prefix, rs)
    if (is.null(id)) next
    if (id %in% names(coll)) {
      vofi_abort("excel_input.duplicate_id", id = id, location = io_xl_loc_text(g$sheet, i, jid),
                 .class = "vofi_error_input")
    }
    base <- path_join(prefix, id)
    io_xl_set_loc(rs, base, g$sheet, i, jid)
    order <- io_xl_decode_order(io_xl_grid_cell(g, i, jord), base, rs)
    if (identical(order, "*")) {
      v <- io_xl_decode_cell(io_xl_grid_cell(g, i, jex), NULL, base, rs, list_name = NULL)
      coll[id] <- list(io_xl_unnull(v))
      next
    }
    if (role == "financing") {
      jt <- match("type", keys)
      tc <- io_xl_grid_cell(g, i, jt)
      if (!is.null(tc)) {
        t <- io_xl_decode_cell(tc, io_xl_meta_param("string"), path_join(base, "type"), rs)
        if (utl_is_string(t)) rs$types[base] <- t
      }
    }
    dist_params <- character(0)
    if (role == "parameters") {
      jd <- match("dist", keys)
      d <- io_xl_decode_cell(io_xl_grid_cell(g, i, jd), NULL, path_join(base, "dist"), rs)
      dist_params <- io_xl_dist_param_names(d)
    }
    pairs <- list()
    for (j in fields) {
      cell <- io_xl_grid_cell(g, i, j)
      if (is.null(cell)) next
      k <- keys[j]
      rel <- k
      if (grepl("^[.]p[1-4]$", k)) {
        pi <- as.integer(substr(k, 3L, 3L))
        if (pi > length(dist_params)) {
          vofi_abort("excel_input.dist_param_unknown", path = base, column = k,
                     location = io_xl_loc_text(g$sheet, i, j), .class = "vofi_error_input")
        }
        rel <- dist_params[pi]
      } else if (startsWith(k, ".")) {
        next
      }
      path <- path_join(base, rel)
      io_xl_set_loc(rs, path, g$sheet, i, j)
      param <- io_xl_param_at(path, rs$types)
      v <- io_xl_decode_cell(cell, param, path, rs)
      if (is.null(v)) next
      pairs[[length(pairs) + 1L]] <- list(rel = rel, value = v,
                                          loc = io_xl_loc_text(g$sheet, i, j))
    }
    pairs <- c(pairs, io_xl_extra_pairs(g, i, jex, base, rs))
    coll[id] <- list(io_xl_build_element(pairs, order, id, base))
  }
  if (length(coll) == 0L) return(invisible(NULL))
  if (role == "parameters") {
    io_xl_add_part(rs, "stochastic", "parameters", coll)
  } else {
    io_xl_add_part(rs, role, "collection", coll)
  }
  invisible(NULL)
}

#' Paare der Spalte „weitere Angaben“ (YAML-Map relativer Pfade)
#' @noRd
io_xl_extra_pairs <- function(g, i, jex, base, rs) {
  cell <- io_xl_grid_cell(g, i, jex)
  if (is.null(cell)) return(list())
  loc <- io_xl_loc_text(g$sheet, i, jex)
  path <- path_join(base, ".extra")
  rs$locations[path] <- loc
  v <- io_xl_decode_cell(cell, NULL, path, rs, list_name = NULL)
  if (!is_map(v)) {
    vofi_abort("excel_input.extra_invalid", path = base, location = loc,
               .class = "vofi_error_input")
  }
  lapply(seq_along(v), function(k) {
    rel <- names(v)[k]
    rs$locations[path_join(base, rel)] <- loc
    list(rel = rel, value = if (is.null(v[[k]])) io_xl_null() else v[[k]], loc = loc)
  })
}

#' Gruppen eines langen Blatts: Zeilen je id (leere id = id der Zeile darüber)
#' @noRd
io_xl_long_groups <- function(g, jid, rs, prefix) {
  groups <- list()
  current <- NULL
  for (i in seq_len(g$n)[-(1:2)]) {
    cells <- lapply(seq_len(g$m), function(j) io_xl_grid_cell(g, i, j))
    if (all(vapply(cells, is.null, logical(1)))) next
    idc <- cells[[jid]]
    if (!is.null(idc)) {
      id <- io_xl_decode_string(idc, prefix, rs)
      if (!identical(id, current) && id %in% names(groups)) {
        vofi_abort("excel_input.duplicate_id", id = id,
                   location = io_xl_loc_text(g$sheet, i, jid), .class = "vofi_error_input")
      }
      current <- id
    } else if (is.null(current)) {
      vofi_abort("excel_input.id_missing", location = io_xl_loc_text(g$sheet, i, jid),
                 .class = "vofi_error_input")
    }
    groups[[current]] <- c(groups[[current]] %||% list(), list(list(row = i, cells = cells)))
  }
  groups
}

#' Langes Blatt (Komponenten, Prozesse, Varianten, Szenario-Sets)
#' @noRd
io_xl_parse_long <- function(role, g, keys, rs) {
  idkey <- if (role == "processes") ".key" else ".id"
  jid <- io_xl_col(keys, idkey, g)
  prefix <- io_xl_collection_path(role)
  groups <- io_xl_long_groups(g, jid, rs, prefix)
  named <- function(cells) stats::setNames(cells, keys)
  coll <- list()
  for (id in names(groups)) {
    rows <- groups[[id]]
    base <- path_join(prefix, id)
    io_xl_set_loc(rs, base, g$sheet, rows[[1L]]$row, jid)
    if (role %in% c("variants", "scenario_sets")) {
      coll[id] <- list(io_xl_decode_variant(role, base, lapply(rows, function(r) {
        c(named(r$cells), list(.row = r$row))
      }), g, rs))
      next
    }
    first <- named(rows[[1L]]$cells)
    order <- io_xl_decode_order(first[[".order"]], base, rs)
    if (identical(order, "*")) {
      coll[id] <- list(io_xl_unnull(io_xl_decode_cell(first[[".value"]], NULL, base, rs,
                                                      list_name = NULL)))
      next
    }
    pairs <- list()
    heads <- if (role == "components") "type" else c("target", "type")
    for (h in heads) {
      j <- match(h, keys)
      cell <- first[[h]]
      if (is.null(cell)) next
      path <- path_join(base, h)
      io_xl_set_loc(rs, path, g$sheet, rows[[1L]]$row, j)
      lst <- NULL
      if (h == "type") lst <- if (role == "components") "types:flow" else "types:process"
      v <- io_xl_decode_cell(cell, io_xl_meta_param("string"), path, rs, list_name = lst)
      if (h == "type" && role == "components" && utl_is_string(v)) rs$types[base] <- v
      pairs[[length(pairs) + 1L]] <- list(rel = h, value = v,
                                          loc = io_xl_loc_text(g$sheet, rows[[1L]]$row, j))
    }
    jparam <- match(".param", keys)
    jv <- match(".value", keys)
    for (r in rows) {
      cl <- named(r$cells)
      pc <- cl[[".param"]]
      if (is.null(pc)) {
        if (!is.null(cl[[".value"]]) || !is.null(cl[[".form"]])) {
          vofi_abort("excel_input.param_missing",
                     location = io_xl_loc_text(g$sheet, r$row, jparam),
                     .class = "vofi_error_input")
        }
        next
      }
      rel <- trimws(io_xl_cell_text(pc))
      path <- path_join(base, rel)
      io_xl_set_loc(rs, path, g$sheet, r$row, jv)
      param <- if (role == "components") io_xl_param_at(path, rs$types) else NULL
      v <- io_xl_decode_leaf(cl[[".form"]], cl[[".value"]], cl[[".options"]], param, path, rs)
      if (is.null(v)) next
      pairs[[length(pairs) + 1L]] <- list(rel = rel, value = v,
                                          loc = io_xl_loc_text(g$sheet, r$row, jv))
    }
    coll[id] <- list(io_xl_build_element(pairs, order, id, base))
  }
  if (length(coll) == 0L) return(invisible(NULL))
  if (role == "processes") {
    io_xl_add_part(rs, "stochastic", "processes", coll)
  } else {
    io_xl_add_part(rs, role, "collection", coll)
  }
  invisible(NULL)
}

#' Variante bzw. Szenario-Set aus seinen Zeilen
#' @param rows Liste benannter Zellenlisten (Maschinenschlüssel), mit `.row`.
#' @noRd
io_xl_decode_variant <- function(role, base, rows, g, rs) {
  first <- rows[[1L]]
  order <- io_xl_decode_order(first[[".order"]], base, rs)
  if (identical(order, "*")) {
    return(io_xl_unnull(io_xl_decode_cell(first[[".value"]], NULL, base, rs, list_name = NULL)))
  }
  fields <- list()
  heads <- c("label", "description", if (role == "variants") "extends")
  for (h in heads) {
    cell <- first[[h]]
    if (is.null(cell)) next
    fields[[h]] <- io_xl_decode_string(cell, path_join(base, h), rs)
  }
  lst <- if (role == "scenario_sets") "actions:sets" else "actions:variants"
  by_field <- list()
  for (r in rows) {
    ac <- r[[".action"]]
    if (is.null(ac)) {
      if (!is.null(r[[".path"]]) || !is.null(r[[".value"]])) {
        vofi_abort("excel_input.action_missing",
                   location = io_xl_loc_text(g$sheet, r$.row, match(".action", names(r))),
                   .class = "vofi_error_input")
      }
      next
    }
    a <- io_xl_decode_string(ac, base, rs)
    a <- io_xl_label_to_code(lst, a, rs) %||% a
    by_field[[a]] <- c(by_field[[a]] %||% list(), list(r))
  }
  for (f in names(by_field)) {
    fields[f] <- list(io_xl_decode_variant_field(role, f, by_field[[f]], rs, g$sheet, base))
  }
  if (!is.null(order) && length(fields) > 1L) {
    pos <- match(names(fields), order)
    fields <- fields[order(ifelse(is.na(pos), length(order) + seq_along(fields), pos),
                           method = "radix")]
  }
  if (length(fields) == 0L) return(structure(list(), names = character(0)))
  fields
}

#' Feld einer Variante aus seinen Zeilen (Gegenstück zu `io_xl_variant_field_rows()`)
#' @param rows Liste benannter Zellenlisten.
#' @noRd
io_xl_decode_variant_field <- function(role, f, rows, rs, sheet, base = role) {
  fpath <- path_join(base, f)
  get_path <- function(r) {
    pc <- r[[".path"]]
    if (is.null(pc)) return(NULL)
    io_xl_decode_string(pc, fpath, rs)
  }
  value_of <- function(r, path) {
    row <- r$.row %||% NA_integer_
    if (!is.na(row) && nzchar(sheet)) {
      rs$locations[path] <- io_xl_loc_text(sheet, row, match(".value", names(r)))
    }
    v <- io_xl_decode_leaf(r[[".form"]], r[[".value"]], r[[".options"]], NULL, path, rs)
    if (is.null(v)) io_xl_null() else v
  }
  if (length(rows) == 1L && is.null(rows[[1L]][[".path"]])) {
    return(io_xl_unnull(value_of(rows[[1L]], fpath)))
  }
  if (f == "remove") {
    return(vapply(rows, function(r) get_path(r) %||% "", ""))
  }
  if (f %in% c("set", "replace", "add")) {
    out <- list()
    for (r in rows) {
      p <- get_path(r)
      if (is.null(p)) {
        vofi_abort("excel_input.variant_path_missing", path = fpath,
                   .class = "vofi_error_input")
      }
      if (p %in% names(out)) {
        vofi_abort("excel_input.path_duplicate", path = path_join(fpath, p), location = "",
                   .class = "vofi_error_input")
      }
      out[p] <- list(io_xl_unnull(value_of(r, path_join(fpath, p))))
    }
    return(out)
  }
  out <- structure(list(), names = character(0))
  for (r in rows) {
    p <- get_path(r)
    if (is.null(p)) {
      vofi_abort("excel_input.variant_path_missing", path = fpath, .class = "vofi_error_input")
    }
    out <- io_xl_put(out, path_split(p), io_xl_unnull(value_of(r, path_join(fpath, p))),
                     path_join(fpath, p), NULL)
  }
  out
}

#' Blatt Korrelationen
#' @noRd
io_xl_parse_corr <- function(g, keys, rs) {
  jk <- io_xl_col(keys, ".kind", g)
  rows_by <- list()
  for (i in seq_len(g$n)[-(1:2)]) {
    cells <- stats::setNames(lapply(seq_len(g$m), function(j) io_xl_grid_cell(g, i, j)), keys)
    used <- cells[intersect(c(".kind", ".a", ".b", ".rho", ".value"), keys)]
    if (all(vapply(used, is.null, logical(1)))) next
    kc <- cells[[".kind"]]
    if (is.null(kc)) {
      if (!is.null(cells[[".value"]]) && length(rows_by) == 0L) {
        rows_by[[".all"]] <- list(cells)
        next
      }
      vofi_abort("excel_input.corr_kind_missing", location = io_xl_loc_text(g$sheet, i, jk),
                 .class = "vofi_error_input")
    }
    k <- io_xl_decode_string(kc, "stochastic.correlations", rs)
    k <- io_xl_label_to_code("corr", k, rs) %||% k
    rs$locations[path_join("stochastic.correlations", k)] <- io_xl_loc_text(g$sheet, i, jk)
    rows_by[[k]] <- c(rows_by[[k]] %||% list(), list(cells))
  }
  if (length(rows_by) == 0L) return(invisible(NULL))
  if (".all" %in% names(rows_by)) {
    v <- io_xl_decode_cell(rows_by[[".all"]][[1L]][[".value"]], NULL, "stochastic.correlations",
                           rs, list_name = NULL)
    io_xl_add_part(rs, "stochastic", "correlations", io_xl_unnull(v))
    return(invisible(NULL))
  }
  out <- list()
  for (k in names(rows_by)) out[k] <- list(io_xl_decode_corr_pairs(rows_by[[k]], rs))
  io_xl_add_part(rs, "stochastic", "correlations", out)
  invisible(NULL)
}

#' Paare einer Korrelationsart (bzw. die Angabe als Ganzes in der Spalte YAML)
#' @param rows Liste benannter Zellenlisten derselben Art.
#' @noRd
io_xl_decode_corr_pairs <- function(rows, rs) {
  path <- "stochastic.correlations"
  if (length(rows) == 1L && !is.null(rows[[1L]][[".value"]])) {
    return(io_xl_unnull(io_xl_decode_cell(rows[[1L]][[".value"]], NULL, path, rs,
                                          list_name = NULL)))
  }
  lapply(rows, function(r) {
    a <- io_xl_decode_string(r[[".a"]], path, rs)
    b <- io_xl_decode_string(r[[".b"]], path, rs)
    rho <- io_xl_decode_cell(r[[".rho"]], NULL, path, rs, list_name = NULL)
    if (is.null(a) || is.null(b) || is.null(rho) || inherits(rho, "io_xl_null")) {
      vofi_abort("excel_input.corr_incomplete", path = path, .class = "vofi_error_input")
    }
    list(a, b, rho)
  })
}

#' Blatt _meta
#' @noRd
io_xl_parse_meta <- function(g, keys, rs) {
  jk <- io_xl_col(keys, ".key", g)
  jv <- io_xl_col(keys, ".value", g)
  je <- io_xl_col(keys, ".extra", g, required = FALSE)
  for (i in seq_len(g$n)[-(1:2)]) {
    kc <- io_xl_grid_cell(g, i, jk)
    if (is.null(kc)) next
    key <- io_xl_cell_text(kc)
    vc <- io_xl_grid_cell(g, i, jv)
    ec <- io_xl_grid_cell(g, i, je)
    if (key == "schema_version") {
      rs$locations["schema_version"] <- io_xl_loc_text(g$sheet, i, jv)
      v <- io_xl_decode_cell(vc, NULL, "schema_version", rs, list_name = NULL)
      if (!is.null(v)) rs$meta$schema_version <- io_xl_unnull(v)
    } else if (key == "template_version") {
      v <- if (!is.null(vc) && vc$t == "num") vc$v else NA_real_
      if (is.finite(v) && v > io_xl_template_version()) {
        vofi_warn("excel_input.template_newer", version = v,
                  supported = io_xl_template_version(), .class = "vofi_warning_input")
      }
    } else if (key == "block" && !is.null(vc)) {
      b <- io_xl_cell_text(vc)
      rs$meta$order <- c(rs$meta$order, b)
      if (!is.null(ec)) {
        rs$locations[b] <- io_xl_loc_text(g$sheet, i, je)
        ev <- io_xl_decode_cell(ec, NULL, b, rs, list_name = NULL)
        if (b %in% c("schema_version", utl_scenario_blocks()) && is.list(ev) &&
              length(ev) == 0L) {
          rs$meta$empty[b] <- list(ev)
        } else {
          rs$meta$extra[b] <- list(io_xl_unnull(ev))
        }
      }
    } else if (key == "order" && !is.null(vc) && !is.null(ec)) {
      rs$meta$children[[io_xl_cell_text(vc)]] <- io_xl_decode_order(ec, "", rs)
    }
  }
  invisible(NULL)
}

#' Blatt Listen (Bezeichnungen der Datei als Rückfall für die Übersetzung in Codes)
#' @noRd
io_xl_parse_lists <- function(g, keys, rs) {
  for (j in seq_along(keys)) {
    k <- keys[j]
    if (is.na(k) || endsWith(k, "#label")) next
    jl <- match(paste0(k, "#label"), keys)
    if (is.na(jl)) next
    rows <- seq_len(g$n)[-(1:2)]
    codes <- vapply(rows, function(i) io_xl_cell_text(io_xl_grid_cell(g, i, j)), "")
    labels <- vapply(rows, function(i) io_xl_cell_text(io_xl_grid_cell(g, i, jl)), "")
    ok <- !is.na(codes) & !is.na(labels)
    rs$label_maps[[k]] <- data.frame(code = codes[ok], label = labels[ok],
                                     stringsAsFactors = FALSE)
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Szenario-Baum zusammensetzen
# ---------------------------------------------------------------------------------------------

#' Beiträge der Blätter zum Szenario-Baum (Reihenfolge der Blöcke aus _meta)
#' @noRd
io_xl_assemble <- function(rs) {
  blocks <- list()
  kv <- list()
  for (p in rs$parts) {
    if (p$kind == "kv") {
      kv[[p$block]] <- c(kv[[p$block]] %||% list(), list(p$value))
      next
    }
    cur <- blocks[[p$block]]
    if (p$kind == "collection") {
      blocks[[p$block]] <- p$value
    } else {
      cur <- cur %||% structure(list(), names = character(0))
      cur[p$kind] <- list(p$value)
      blocks[[p$block]] <- cur
    }
  }
  for (b in names(kv)) {
    recs <- kv[[b]]
    seqs <- vapply(recs, function(r) r$seq, double(1))
    o <- order(ifelse(is.na(seqs), Inf, seqs), seq_along(recs), method = "radix")
    tree <- if (b %in% names(blocks) && !(b %in% c("stochastic"))) blocks[[b]] else NULL
    stoch <- if (b == "stochastic") blocks[[b]] else NULL
    for (r in recs[o]) {
      segs <- path_split(r$path)
      if (length(segs) == 1L) {
        if (!is.null(tree)) {
          vofi_abort("excel_input.path_duplicate", path = r$path, location = r$loc,
                     .class = "vofi_error_input")
        }
        tree <- io_xl_unnull(r$value)
        if (is.null(tree)) tree <- io_xl_null()
        next
      }
      tree <- io_xl_put(tree, segs[-1L], io_xl_unnull(r$value), r$path, r$loc)
    }
    if (b == "stochastic" && !is.null(stoch)) {
      for (k in names(stoch)) {
        if (utl_has_name(tree, k)) {
          vofi_abort("excel_input.path_duplicate", path = path_join(b, k), location = "",
                     .class = "vofi_error_input")
        }
        tree[k] <- list(stoch[[k]])
      }
    }
    blocks[b] <- list(io_xl_unnull(tree))
  }
  ch <- rs$meta$children[["stochastic"]]
  if (!is.null(ch) && is_map(blocks$stochastic)) {
    s <- blocks$stochastic
    pos <- match(names(s), ch)
    blocks$stochastic <- s[order(ifelse(is.na(pos), length(ch) + seq_along(s), pos),
                                 method = "radix")]
  }
  if (!is.null(rs$meta$schema_version) && !("schema_version" %in% names(blocks))) {
    blocks$schema_version <- rs$meta$schema_version
  }
  for (b in names(rs$meta$empty)) {
    if (!(b %in% names(blocks))) blocks[b] <- list(rs$meta$empty[[b]])
  }
  for (b in names(rs$meta$extra)) {
    if (!(b %in% names(blocks))) blocks[b] <- list(rs$meta$extra[[b]])
  }
  canonical <- c("schema_version", utl_scenario_blocks())
  order <- c(rs$meta$order, canonical, names(blocks))
  order <- unique(order[order %in% names(blocks)])
  blocks[order]
}
