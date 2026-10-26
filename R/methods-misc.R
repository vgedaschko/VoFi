# S3-Methoden der Klassen vofi_table und vofi_sensitivity sowie gemeinsame Anzeigehelfer der
# Ausgabe (WS-H, Spec 00 Abschnitte 13.4, 13.5, 13.6).
# Eigentuemer: WS-H. Inhalt: deutsches Zahlenformat je Einheit (rep_fmt_value()), Ausgabe von
# Zeichenmatrizen mit Umbruch nach getOption("width") (rep_cat_matrix()), Methoden print(),
# format(), as.data.frame() fuer vofi_table und print(), plot(), as.data.frame() fuer
# vofi_sensitivity.

# ---------------------------------------------------------------------------------------------
# Gemeinsame Anzeigehelfer
# ---------------------------------------------------------------------------------------------

#' Text eines Vermerks: Label-Schlüssel werden übersetzt, sonst Text unverändert
#' @noRd
rep_note_text <- function(x) {
  vapply(as.character(x), function(n) {
    if (lbl_has(n)) lbl(n) else n
  }, "", USE.NAMES = FALSE)
}

#' Wert im deutschen Format je Einheit (2.10, Einheiten aus units.yaml)
#'
#' `EUR` mit Eurozeichen, Raten und Anteile in Prozent, Jahreszahlen ohne Tausenderpunkt,
#' 0/1-Kennzeichen als „ja“/„nein“, übrige Einheiten mit ihrer Bezeichnung.
#' @param x Zahlen.
#' @param unit Einheit (Länge 1 oder wie `x`).
#' @param digits Nachkommastellen für Geldbeträge.
#' @return Zeichenvektor (`NA` als „n. d.“).
#' @noRd
rep_fmt_value <- function(x, unit = "EUR", digits = 2) {
  x <- as.double(x)
  unit <- rep_len(as.character(unit), length(x))
  out <- character(length(x))
  for (i in seq_along(x)) {
    v <- x[i]
    u <- unit[i]
    if (is.na(v)) {
      out[i] <- fmt_num(NA)
      next
    }
    out[i] <- switch(
      if (is.na(u) || !nzchar(u)) "none" else u,
      EUR = fmt_eur(v, digits),
      rate_pa = , share = fmt_pct(v, 2),
      ratio = , factor = fmt_num(v, 2),
      year = sprintf("%d", as.integer(round(v))),
      years = paste(fmt_num(v, 1), rep_unit_label(u)),
      months = paste(fmt_num(v, 0), rep_unit_label(u)),
      flag = if (v > 0.5) lbl("report.common.yes") else lbl("report.common.no"),
      count = fmt_int(v),
      t_co2 = paste(fmt_num(v, 1), rep_unit_label(u)),
      kWh = , kWh_pa = paste(fmt_num(v, 0), rep_unit_label(u)),
      {
        lab <- if (nzchar(u)) rep_unit_label(u) else NA_character_
        if (is.na(lab)) fmt_num(v, digits) else paste(fmt_num(v, digits), lab)
      }
    )
  }
  enc2utf8(out)
}

#' Kennzahlwert mit NA-Begründung (12.4)
#' @noRd
rep_fmt_kpi <- function(value, unit, na_reason = NA_character_, digits = 2) {
  out <- rep_fmt_value(value, unit, digits)
  na_reason <- rep_len(as.character(na_reason), length(out))
  miss <- is.na(value) & !is.na(na_reason)
  if (any(miss)) {
    out[miss] <- vapply(which(miss), function(i) {
      lbl("report.common.na_reason", value = out[i],
          reason = lbl(paste0("vocab.na_reasons.", na_reason[i]), .default = na_reason[i]))
    }, "")
  }
  out
}

#' Zeichenkette auf Breite auffüllen (links- bzw. rechtsbündig, Anzeigebreite)
#' @noRd
rep_pad <- function(s, w, right = TRUE) {
  s <- as.character(s)
  s[is.na(s)] <- ""
  pad <- strrep(" ", pmax(0L, w - nchar(s, type = "width")))
  if (right) paste0(pad, s) else paste0(s, pad)
}

#' Zeichenmatrix mit Spaltenköpfen ausgeben, umgebrochen nach `width`
#'
#' Die ersten `left` Spalten sind linksbündig und werden in jedem Block wiederholt, die übrigen
#' rechtsbündig.
#' @param m Zeichenmatrix mit `colnames`.
#' @param left Anzahl der Kopfspalten.
#' @param width Zeilenbreite.
#' @param indent Einrückung.
#' @noRd
rep_cat_matrix <- function(m, left = 1L, width = getOption("width", 80L), indent = "  ") {
  if (!is.matrix(m) || ncol(m) == 0L) return(invisible())
  hdr <- colnames(m) %||% rep("", ncol(m))
  hdr[is.na(hdr)] <- ""
  w <- nchar(hdr, type = "width")
  if (nrow(m) > 0L) {
    cw <- vapply(seq_len(ncol(m)), function(j) {
      v <- m[, j]
      v[is.na(v)] <- ""
      max(nchar(v, type = "width"))
    }, integer(1))
    w <- pmax(w, cw)
  }
  left <- min(left, ncol(m))
  lcols <- seq_len(left)
  rest <- setdiff(seq_len(ncol(m)), lcols)
  base_w <- nchar(indent, type = "width") + sum(w[lcols]) + 2L * length(lcols)
  blocks <- list()
  cur <- integer(0)
  used <- base_w
  for (j in rest) {
    if (length(cur) > 0L && used + w[j] + 2L > width) {
      blocks[[length(blocks) + 1L]] <- cur
      cur <- integer(0)
      used <- base_w
    }
    cur <- c(cur, j)
    used <- used + w[j] + 2L
  }
  if (length(cur) > 0L || length(blocks) == 0L) blocks[[length(blocks) + 1L]] <- cur
  line <- function(vals, cols) {
    parts <- c(vapply(cols[cols %in% lcols], function(j) rep_pad(vals[j], w[j], FALSE), ""),
               vapply(cols[!(cols %in% lcols)], function(j) rep_pad(vals[j], w[j], TRUE), ""))
    sub("\\s+$", "", paste0(indent, paste(parts, collapse = "  ")))
  }
  for (b in seq_along(blocks)) {
    cols <- c(lcols, blocks[[b]])
    if (b > 1L) cat("\n")
    cat(line(hdr, cols), "\n", sep = "")
    for (i in seq_len(nrow(m))) cat(line(m[i, ], cols), "\n", sep = "")
  }
  invisible()
}

#' Data Frame als Zeichenmatrix (Spaltennamen als Köpfe)
#' @noRd
rep_df_matrix <- function(df) {
  m <- as.matrix(df)
  if (nrow(df) == 0L) m <- matrix(character(0), 0L, ncol(df))
  colnames(m) <- names(df)
  m
}

# ---------------------------------------------------------------------------------------------
# vofi_table (13.5)
# ---------------------------------------------------------------------------------------------

#' VoFi-Tabelle formatieren
#'
#' Liefert die VoFi-Tabelle als Zeichenmatrix im deutschen Zahlenformat (Spec 00, Abschnitte
#' 2.10, 13.6): im Grob-Layout eine Zeile je Position (Bezeichnung in der ersten Spalte,
#' Unterzeilen eingerückt) und eine Spalte je Periode, transponiert eine Zeile je Periode und
#' eine Spalte je Position. Nullwerte erscheinen als Gedankenstrich, der Finanzierungssaldo
#' immer als Zahl.
#'
#' @param x Objekt der Klasse `vofi_table`.
#' @param layout `"grob"` oder `"transposed"` (Default: Layout der Tabelle).
#' @param digits Nachkommastellen (Default aus `x$format$digits`).
#' @param zero Anzeige für Nullwerte.
#' @param ... nicht verwendet.
#' @return Zeichenmatrix mit Spaltenköpfen.
#' @family Berichten
#' @examples
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' format(vofi_table(res))
#' @export
format.vofi_table <- function(x, layout = x$layout, digits = x$format$digits %||% 2,
                              zero = "\u2013", ...) {
  layout <- utl_match_arg(layout, c("grob", "transposed"), "layout")
  d <- x$data
  pcols <- x$columns$label %||% setdiff(names(d), c("row_key", "label", "section", "level"))
  vals <- as.matrix(d[, pcols, drop = FALSE])
  if (nrow(d) == 0L) vals <- matrix(numeric(0), 0L, length(pcols))
  cells <- matrix(fmt_num(vals, digits), nrow(vals), ncol(vals))
  is_zero <- !is.na(vals) & abs(vals) < 0.5 * 10^(-digits)
  keep_zero <- matrix(d$section == "check", nrow(vals), ncol(vals))
  cells[is_zero & !keep_zero] <- zero
  labels <- paste0(strrep("  ", pmax(0L, d$level)), d$label)
  if (identical(layout, "grob")) {
    m <- cbind(labels, cells)
    colnames(m) <- c(lbl("report.table.position"), pcols)
  } else {
    m <- cbind(pcols, t(cells))
    colnames(m) <- c(lbl("report.table.period"), d$label)
  }
  rownames(m) <- NULL
  enc2utf8(m)
}

#' VoFi-Tabelle ausgeben
#'
#' @param x Objekt der Klasse `vofi_table`.
#' @param ... weitere Angaben an [format.vofi_table()] (z. B. `layout`, `digits`).
#' @return `invisible(x)`.
#' @family Berichten
#' @examples
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' print(vofi_table(res, detail = "full"))
#' @export
print.vofi_table <- function(x, ...) {
  m <- format(x, ...)
  layout <- list(...)$layout %||% x$layout
  cat(lbl("report.table.header", title = x$meta$title %||% "",
          layout = lbl(paste0("report.table.layout_", layout)),
          detail = lbl(paste0("report.table.detail_", x$detail)),
          variant = x$variant %||% "base", sim = rep_sim_label(x$sim)), "\n", sep = "")
  rep_cat_matrix(m, left = 1L)
  invisible(x)
}

#' VoFi-Tabelle als Data Frame
#'
#' @param x Objekt der Klasse `vofi_table`.
#' @param row.names,optional nicht verwendet (Kompatibilität mit [as.data.frame()]).
#' @param layout `"grob"` (Zeilen = Positionen, Spalten `row_key`, `label`, `section`, `level`
#'   und je Periode) oder `"transposed"` (Zeilen = Perioden mit `t`, `period`, `date_end`, eine
#'   Spalte je `row_key`); Default: Layout der Tabelle.
#' @param ... nicht verwendet.
#' @return Data Frame.
#' @family Berichten
#' @examples
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' as.data.frame(vofi_table(res), layout = "transposed")
#' @export
as.data.frame.vofi_table <- function(x, row.names = NULL, optional = FALSE, # nolint
                                     layout = x$layout, ...) {
  layout <- utl_match_arg(layout, c("grob", "transposed"), "layout")
  d <- x$data
  if (identical(layout, "grob")) {
    rownames(d) <- NULL
    return(d)
  }
  pcols <- x$columns$label
  vals <- as.matrix(d[, pcols, drop = FALSE])
  out <- data.frame(t = x$columns$t, period = pcols, date_end = x$columns$date_end,
                    stringsAsFactors = FALSE)
  for (i in seq_len(nrow(d))) out[[d$row_key[i]]] <- as.double(vals[i, ])
  rownames(out) <- NULL
  out
}

# ---------------------------------------------------------------------------------------------
# vofi_sensitivity (13.4)
# ---------------------------------------------------------------------------------------------

#' Einheit der Kennzahl einer Sensitivitätsanalyse
#' @noRd
rep_sens_unit <- function(x) {
  u <- kpi_unit(x$kpi %||% "")
  if (is.na(u)) "EUR" else u
}

#' Bezeichnungen der Parameter einer Sensitivitätsanalyse
#' @noRd
rep_sens_param_labels <- function(x, params) {
  p <- x$params
  lab <- if (is.data.frame(p) && "label" %in% names(p)) p$label[match(params, p$param)] else
    rep(NA_character_, length(params))
  ifelse(is.na(lab) | !nzchar(lab), params, lab)
}

#' Sensitivitätsanalyse ausgeben
#'
#' Gibt Methode, Kennzahl, Variante und Basiswert sowie die Ergebnistabelle aus: beim Tornado je
#' Parameter unteren und oberen Wert, die Kennzahl an beiden Werten, die Spannweite und den
#' Rang; beim Spider-Diagramm die Kennzahl je Stufe; bei der globalen Sensitivität die Maße
#' Spearman, SRC, SRRC, PRCC und den Haupteffekt-Index mit R² (Spec 00, Abschnitt 13.4).
#'
#' @param x Objekt der Klasse `vofi_sensitivity`.
#' @param n höchste Zahl angezeigter Parameter.
#' @param ... nicht verwendet.
#' @return `invisible(x)`.
#' @family Berichten
#' @export
print.vofi_sensitivity <- function(x, n = 15L, ...) {
  unit <- rep_sens_unit(x)
  kpi_txt <- if (utl_is_string(x$kpi)) kpi_label(x$kpi) else ""
  cat(lbl("report.sensitivity.header",
          method = lbl(paste0("report.sensitivity.method_", x$method), .default = x$method),
          kpi = kpi_txt, variant = x$variant %||% "base"), "\n", sep = "")
  if (!is.null(x$base_value) && !is.na(x$base_value)) {
    cat(lbl("report.sensitivity.base_value", value = rep_fmt_value(x$base_value, unit, 0)),
        "\n", sep = "")
  }
  m <- rep_sens_matrix(x, n, unit)
  if (is.null(m) || nrow(m) == 0L) {
    cat(lbl("report.sensitivity.empty"), "\n", sep = "")
    return(invisible(x))
  }
  cat("\n")
  rep_cat_matrix(m, left = 1L)
  if (identical(x$method, "global") && !is.null(x$r2_src) && !is.na(x$r2_src)) {
    cat("\n", lbl("report.sensitivity.r2", value = fmt_num(x$r2_src, 3)), "\n", sep = "")
  }
  invisible(x)
}

#' Ergebnistabelle einer Sensitivitätsanalyse als Zeichenmatrix
#' @noRd
rep_sens_matrix <- function(x, n, unit) {
  if (identical(x$method, "tornado")) {
    r <- x$results
    if (!is.data.frame(r) || nrow(r) == 0L) return(NULL)
    r <- r[order(r$rank %||% -abs(r$swing), method = "radix"), , drop = FALSE]
    r <- utils::head(r, n)
    m <- cbind(rep_sens_param_labels(x, r$param), fmt_num(r$value_low, 4),
               fmt_num(r$value_high, 4), rep_fmt_value(r$kpi_low, unit, 0),
               rep_fmt_value(r$kpi_high, unit, 0), rep_fmt_value(r$swing, unit, 0),
               as.character(r$rank))
    colnames(m) <- c(lbl("report.sensitivity.param"), lbl("report.sensitivity.value_low"),
                     lbl("report.sensitivity.value_high"), lbl("report.sensitivity.kpi_low"),
                     lbl("report.sensitivity.kpi_high"), lbl("report.sensitivity.swing"),
                     lbl("report.sensitivity.rank"))
    return(m)
  }
  if (identical(x$method, "spider")) {
    s <- x$spider
    if (!is.data.frame(s) || nrow(s) == 0L) return(NULL)
    m <- cbind(rep_sens_param_labels(x, s$param), as.character(s$step), fmt_num(s$value, 4),
               rep_fmt_value(s$kpi, unit, 0))
    colnames(m) <- c(lbl("report.sensitivity.param"), lbl("report.sensitivity.step"),
                     lbl("report.sensitivity.value"), lbl("report.sensitivity.kpi"))
    return(m)
  }
  g <- x$global
  if (!is.data.frame(g) || nrow(g) == 0L) return(NULL)
  g <- g[order(-abs(g$spearman), method = "radix"), , drop = FALSE]
  g <- utils::head(g, n)
  cols <- intersect(c("spearman", "src", "srrc", "prcc", "s1_binned"), names(g))
  m <- cbind(as.character(g$input), vapply(cols, function(cc) fmt_num(g[[cc]], 3),
                                           character(nrow(g))))
  if (nrow(g) == 1L) m <- matrix(m, nrow = 1L)
  colnames(m) <- c(lbl("report.sensitivity.input"),
                   vapply(cols, function(cc) lbl(paste0("report.sensitivity.", cc)), ""))
  m
}

#' Sensitivitätsanalyse als Data Frame
#'
#' @param x Objekt der Klasse `vofi_sensitivity`.
#' @param row.names,optional nicht verwendet (Kompatibilität mit [as.data.frame()]).
#' @param what `"results"` (Default: Ergebnis der Methode, also `results` beim Tornado,
#'   `spider` beim Spider-Diagramm, `global` bei der globalen Sensitivität) oder `"params"`.
#' @param ... nicht verwendet.
#' @return Data Frame.
#' @family Berichten
#' @export
as.data.frame.vofi_sensitivity <- function(x, row.names = NULL, optional = FALSE, # nolint
                                           what = c("results", "params"), ...) {
  what <- utl_match_arg(what, c("results", "params"), "what")
  if (identical(what, "params")) return(x$params)
  out <- switch(x$method, tornado = x$results, spider = x$spider, global = x$global, NULL)
  if (is.null(out)) out <- data.frame()
  out
}

#' Grafik einer Sensitivitätsanalyse
#'
#' Ruft [vofi_plot()] auf: Tornado (`type = "tornado"`), Spider-Diagramm (`"spider"`) bzw.
#' Balken der globalen Sensitivitätsmaße (`"balken"`); Default nach der Methode.
#'
#' @param x Objekt der Klasse `vofi_sensitivity`.
#' @param type Grafiktyp bzw. `NULL`.
#' @param ... weitere Angaben an [vofi_plot()].
#' @return ggplot-Objekt.
#' @family Berichten
#' @export
plot.vofi_sensitivity <- function(x, type = NULL, ...) {
  vofi_plot(x, type = type, ...)
}
