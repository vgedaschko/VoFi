# Excel-Eingabevorlage (WS-A2, Spec 00 Abschnitt 4.14).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-A2. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Excel-Eingabevorlage erzeugen
#'
#' Erzeugt die Excel-Eingabevorlage aus Registry, Vokabularen und Label-Katalog (Spec 00,
#' Abschnitt 4.14).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param path Zieldatei (`.xlsx`).
#' @param example optional: Name eines Beispielszenarios, das in die Vorlage eingetragen wird.
#' @param overwrite vorhandene Datei überschreiben.
#' @return `invisible(path)`.
#' @family Einlesen
#' @export
vofi_excel_template <- function(path, example = NULL, overwrite = FALSE) {
  vofi_abort("core.not_implemented", fun = "vofi_excel_template",
             .class = "vofi_error_not_implemented")
}
