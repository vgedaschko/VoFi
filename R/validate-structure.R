# Validierung Ebene 1 (Struktur) und Einstieg vofi_validate() (WS-B, Spec 00 Abschnitt 13.5).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-B. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Szenario bzw. Spezifikation prüfen
#'
#' Prüft ein Szenario bzw. eine aufgelöste Spezifikation auf vier Ebenen (Struktur, Typen, Bezüge,
#' Plausibilität) und sammelt alle Befunde (Spec 00, Abschnitte 2.9, 13.5).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Objekt der Klasse `vofi_scenario` oder `vofi_spec`.
#' @param variant `NULL` (alle Varianten) oder Name einer Variante.
#' @param min_severity kleinste ausgegebene Schwere: `"info"`, `"warning"` oder `"error"`.
#' @return Objekt der Klasse `vofi_validation`.
#' @family Validieren
#' @export
vofi_validate <- function(x, variant = NULL, min_severity = c("info", "warning", "error")) {
  vofi_abort("core.not_implemented", fun = "vofi_validate",
             .class = "vofi_error_not_implemented")
}
