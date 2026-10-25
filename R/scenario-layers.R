# Schichten, Deep-Merge, Expander-Aufruf (WS-A, Spec 00 Abschnitte 4.7-4.12, 6.4).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-A. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Variante auflösen
#'
#' Löst eine Variante auf: Schichten 0–8 mischen, Bibliotheksverweise auflösen, Varianten und
#' Szenario-Sets anwenden, Expander ausführen (Spec 00, Abschnitte 4.7–4.12).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param scenario Objekt der Klasse `vofi_scenario`.
#' @param variant Variante (Default `"base"`).
#' @param overrides optional: Laufzeit-Overrides (Schicht 8) als verschachtelte Liste.
#' @param scenario_set optional: Name eines Szenario-Sets.
#' @return Objekt der Klasse `vofi_spec`.
#' @family Einlesen
#' @export
vofi_resolve <- function(scenario, variant = "base", overrides = NULL, scenario_set = NULL) {
  vofi_abort("core.not_implemented", fun = "vofi_resolve",
             .class = "vofi_error_not_implemented")
}
