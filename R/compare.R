# Vergleich von Alternativen (WS-G, Spec 00 Abschnitt 9.6).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-G. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Varianten vergleichen
#'
#' Vergleicht Varianten als vollständige VoFis mit gemeinsamen Zufallszahlen (Vergleichsregel
#' ΔEW_A − ΔEW_ref, Ausweichvarianten, Set „vorsichtig“, Ampel; Spec 00, Abschnitte 9.6, 9.11,
#' 12.9).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Objekt der Klasse `vofi_scenario`.
#' @param variants `NULL` (alle) oder Namen der Varianten.
#' @param baseline Referenzvariante (Default `project.reference_variant`).
#' @param scenario_sets optional: Szenario-Sets, die mit den Varianten gekreuzt werden.
#' @param n_sim Anzahl der Läufe (1 = deterministisch).
#' @param seed Seed der Simulation.
#' @param store `"auto"`, `"bands"` oder `"kpi"`.
#' @param allow_unequal Vergleich trotz Vergleichbarkeitsbefunden (mit Warnung).
#' @return Objekt der Klasse `vofi_comparison`.
#' @family Analysieren
#' @export
vofi_compare <- function(x, variants = NULL, baseline = NULL, scenario_sets = NULL, n_sim = 1L,
                         seed = NULL, store = c("auto", "bands", "kpi"), allow_unequal = FALSE) {
  vofi_abort("core.not_implemented", fun = "vofi_compare",
             .class = "vofi_error_not_implemented")
}
