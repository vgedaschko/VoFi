# Methoden des Validierungsberichts vofi_validation (WS-B; Spec 00 Abschnitte 13.5, 13.6).
# Der Bericht bleibt ein Data Frame mit einer Zeile je Befund und Variante; format() und print()
# fassen gleiche Befunde mehrerer Varianten zu einer Zeile zusammen und ordnen nach Schwere
# (Fehler, Warnung, Hinweis) und Pfad. Alle Texte stammen aus dem Label-Katalog.

#' Validierungsbericht formatieren
#'
#' Formatiert einen Validierungsbericht ([vofi_validate()]) als Textzeilen: eine Kopfzeile mit
#' der Zahl der Fehler, Warnungen und Hinweise, danach je Befund Schwere, Pfad, Meldung,
#' Fundstelle und betroffene Varianten. Gleiche Befunde mehrerer Varianten erscheinen einmal.
#'
#' @param x Objekt der Klasse `vofi_validation`.
#' @param ... nicht verwendet.
#' @param max_rows größte Zahl ausgegebener Befunde (`Inf` = alle).
#' @return Zeichenvektor.
#' @family Validieren
#' @examples
#' v <- vofi_validate(vofi_read_scenario(vofi_example("skeleton")))
#' format(v)
#' @export
format.vofi_validation <- function(x, ..., max_rows = Inf) {
  if (!is.numeric(max_rows) || length(max_rows) != 1L || is.na(max_rows) || max_rows < 0) {
    vofi_abort("core.arg_scalar", arg = "max_rows", .class = "vofi_error_input")
  }
  df <- val_report_rows(x)
  counts <- vapply(c("error", "warning", "info"), function(s) sum(df$severity == s), integer(1))
  header <- lbl("validation.report.header", errors = counts[["error"]],
                warnings = counts[["warning"]], infos = counts[["info"]])
  if (nrow(df) == 0L) return(c(header, lbl("validation.report.none")))
  n_show <- min(nrow(df), max_rows)
  vars <- unique(x$variant[!is.na(x$variant)])
  show_variants <- length(vars) > 1L || any(vars != "base")
  lines <- vapply(seq_len(n_show), function(i) {
    sev <- lbl(paste0("vocab.enums.severity.", df$severity[i]))
    line <- lbl("validation.report.line", severity = sev,
                path = if (nzchar(df$path[i])) df$path[i] else "-", message = df$message[i])
    if (!is.na(df$location[i]) && nzchar(df$location[i])) {
      line <- paste0(line, lbl("validation.report.location", location = df$location[i]))
    }
    if (show_variants && !is.na(df$variant[i]) && nzchar(df$variant[i])) {
      line <- paste0(line, lbl("validation.report.variants", variants = df$variant[i]))
    }
    line
  }, "")
  out <- c(header, lines)
  if (n_show < nrow(df)) {
    out <- c(out, lbl("validation.report.more", n = as.integer(nrow(df) - n_show)))
  }
  out
}

#' Validierungsbericht ausgeben
#'
#' Gibt den Bericht wie [format.vofi_validation()] aus.
#' @param x Objekt der Klasse `vofi_validation`.
#' @param ... weitergereicht an [format.vofi_validation()] (z. B. `max_rows`).
#' @return `x` (unsichtbar).
#' @family Validieren
#' @examples
#' print(vofi_validate(vofi_read_scenario(vofi_example("skeleton"))))
#' @export
print.vofi_validation <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

#' Validierungsbericht als Data Frame
#'
#' Liefert den Bericht als gewöhnlichen Data Frame mit den Spalten `severity`, `code`, `path`,
#' `location`, `message`, `layer` und `variant` (eine Zeile je Befund und Variante).
#' @param x Objekt der Klasse `vofi_validation`.
#' @param row.names,optional wie [base::as.data.frame()].
#' @param ... nicht verwendet.
#' @return Data Frame.
#' @family Validieren
#' @examples
#' as.data.frame(vofi_validate(vofi_read_scenario(vofi_example("skeleton"))))
#' @export
as.data.frame.vofi_validation <- function(x, row.names = NULL, optional = FALSE, ...) {
  df <- x
  class(df) <- "data.frame"
  if (!is.null(row.names)) rownames(df) <- row.names else rownames(df) <- NULL
  df
}

#' Zeilen des Berichts: gleiche Befunde mehrerer Varianten zusammengefasst, sortiert
#'
#' Schlüssel der Zusammenfassung sind Schwere, Code, Pfad und Meldung; die Varianten erscheinen
#' kommagetrennt in der Reihenfolge ihres ersten Auftretens.
#' @param x `vofi_validation`.
#' @return Data Frame.
#' @noRd
val_report_rows <- function(x) {
  df <- as.data.frame.vofi_validation(x)
  if (nrow(df) == 0L) return(df)
  key <- paste(df$severity, df$code, df$path, df$message, sep = "\r")
  first <- !duplicated(key)
  vars <- tapply(df$variant, factor(key, levels = unique(key)), function(v) {
    v <- unique(v[!is.na(v) & nzchar(v)])
    if (length(v) == 0L) NA_character_ else paste(v, collapse = ", ")
  })
  out <- df[first, , drop = FALSE]
  out$variant <- as.character(vars[key[first]])
  rank <- c(error = 1L, warning = 2L, info = 3L)
  ord <- order(rank[out$severity], out$path, out$code, method = "radix")
  out <- out[ord, , drop = FALSE]
  rownames(out) <- NULL
  out
}
