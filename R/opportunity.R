# Unterlassungsalternative (WS-D, Spec 00 Abschnitt 9.5).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-D. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Unterlassungsalternative
#'
#' Berechnet die Unterlassungsalternative zu einem Modell oder Ergebnis: gleiche Einlagen
#' inklusive Nachschüsse der Investition und gleiche Entnahmen, keine Investition, keine Kredite,
#' keine eigenen Nachschüsse (Spec 00, Abschnitt 9.5).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Objekt der Klasse `vofi_model` oder `vofi_result`.
#' @return Objekt der Klasse `vofi_result`.
#' @family Rechnen
#' @export
vofi_opportunity <- function(x) {
  vofi_abort("core.not_implemented", fun = "vofi_opportunity",
             .class = "vofi_error_not_implemented")
}
