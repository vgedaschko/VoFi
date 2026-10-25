# Build-Stufen (WS-D, Spec 00 Abschnitt 9.1).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-D. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Rechenfertiges Modell bauen
#'
#' Baut aus einem Szenario oder einer Spezifikation ein rechenfertiges Modell: Validierung,
#' Zeitraster, sortierte Komponenten, Instrumente, Ausgleichsketten, Basisfall-Vorlauf,
#' Sampler-Plan, Steuermodul und Kennzahlen (Spec 00, Abschnitt 9.1).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Objekt der Klasse `vofi_scenario` oder `vofi_spec`.
#' @param variant Variante (Default `"base"`).
#' @param overrides optional: Laufzeit-Overrides (Schicht 8).
#' @param scenario_set optional: Name eines Szenario-Sets.
#' @return Objekt der Klasse `vofi_model`.
#' @family Rechnen
#' @export
vofi_build <- function(x, variant = "base", overrides = NULL, scenario_set = NULL) {
  vofi_abort("core.not_implemented", fun = "vofi_build",
             .class = "vofi_error_not_implemented")
}
