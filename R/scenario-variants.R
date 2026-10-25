# Varianten und Szenario-Sets (WS-A, Spec 00 Abschnitt 4.11).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-A. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Varianten eines Szenarios
#'
#' Listet die Basis und alle Varianten mit Bezeichnung und Elternvariante (Spec 00, Abschnitt
#' 4.11).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param scenario Objekt der Klasse `vofi_scenario`.
#' @return Data Frame mit einer Zeile je Variante.
#' @family Einlesen
#' @export
vofi_variants <- function(scenario) {
  vofi_abort("core.not_implemented", fun = "vofi_variants",
             .class = "vofi_error_not_implemented")
}
