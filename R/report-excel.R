# Excel-Export (WS-H).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-H. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Excel-Export
#'
#' Exportiert ein Ergebnis nach Excel mit Annahmen, Prüfungen und Saldo-Formel.
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Ergebnisobjekt.
#' @param path Zieldatei (`.xlsx`).
#' @param overwrite vorhandene Datei überschreiben.
#' @param sheets `NULL` (alle) oder Auswahl der Blätter.
#' @return `invisible(path)`.
#' @family Berichten
#' @export
vofi_export_excel <- function(x, path, overwrite = FALSE, sheets = NULL) {
  vofi_abort("core.not_implemented", fun = "vofi_export_excel",
             .class = "vofi_error_not_implemented")
}
