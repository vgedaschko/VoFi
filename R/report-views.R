# Nutzerkosten- und Haushaltssicht (WS-H).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-H. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Nutzerkostensicht
#'
#' Nutzerkostensicht: Warmmiete je Jahr und Variante.
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Objekt der Klasse `vofi_result` oder `vofi_comparison`.
#' @param variant `NULL` (alle) oder Variante.
#' @return Data Frame.
#' @family Berichten
#' @export
vofi_tenant_view <- function(x, variant = NULL) {
  vofi_abort("core.not_implemented", fun = "vofi_tenant_view",
             .class = "vofi_error_not_implemented")
}

#' Haushaltssicht
#'
#' Haushaltssicht: monatliche Belastung des Selbstnutzers (inklusive Bauphase, zusätzlich „ohne
#' Tilgung“), Ersparnis, Belastungsquote, Eigenanteil, Nachschüsse, Vermögensamortisation mit
#' Zeitwert der Maßnahmen je Jahr; für Kleinvermieter der monatliche Cashflow je Jahr.
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Objekt der Klasse `vofi_result` oder `vofi_comparison`.
#' @param variant `NULL` (alle) oder Variante.
#' @return Data Frame.
#' @family Berichten
#' @export
vofi_household_view <- function(x, variant = NULL) {
  vofi_abort("core.not_implemented", fun = "vofi_household_view",
             .class = "vofi_error_not_implemented")
}
