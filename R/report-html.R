# HTML-Bericht (WS-H2).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-H2. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Bericht erzeugen
#'
#' Erzeugt einen HTML-Bericht im Fach- oder Haushaltsmodus (DOCX vorbereitet, Freigabe v1.1).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Ergebnisobjekt.
#' @param path Zieldatei.
#' @param format `"html"` oder `"docx"`.
#' @param mode `"auto"`, `"expert"` oder `"household"`.
#' @param template optional: eigene Berichtsvorlage.
#' @param title optional: Titel des Berichts.
#' @param open Bericht nach dem Erzeugen öffnen.
#' @return `invisible(path)`.
#' @family Berichten
#' @export
vofi_report <- function(x, path, format = c("html", "docx"), mode = c("auto", "expert", "household"),
                        template = NULL, title = NULL, open = interactive()) {
  vofi_abort("core.not_implemented", fun = "vofi_report",
             .class = "vofi_error_not_implemented")
}
