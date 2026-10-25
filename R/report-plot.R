# Grafiken (WS-H).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-H. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Grafiken
#'
#' Grafiken zu Ergebnis, Simulation, Vergleich und Sensitivität (ggplot2 aus Suggests).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Ergebnisobjekt (`vofi_result`, `vofi_mc_result`, `vofi_comparison`,
#'   `vofi_sensitivity`).
#' @param type Grafiktyp (abhängig von der Klasse von `x`).
#' @param ... weitere Angaben an die Grafikfunktion.
#' @return ggplot-Objekt.
#' @family Berichten
#' @export
vofi_plot <- function(x, type = NULL, ...) {
  vofi_abort("core.not_implemented", fun = "vofi_plot",
             .class = "vofi_error_not_implemented")
}
