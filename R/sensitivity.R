# Tornado, Spider, globale Sensitivität (WS-G, Spec 00 Abschnitt 11.11).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-G. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Sensitivitätsanalyse
#'
#' Tornado und Spider (ein Design-Lauf) bzw. globale Sensitivität aus einer Simulation; `kpi =
#' NULL` ist die Primärkennzahl, Vergleichskennzahlen werden gegen `reference` gerechnet (Spec 00,
#' Abschnitte 11.11, 13.4).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Objekt der Klasse `vofi_scenario`, `vofi_model` oder `vofi_mc_result`.
#' @param params `NULL` (alle Overlay-Ziele) oder Zielpfade.
#' @param method `"tornado"`, `"spider"` oder `"global"`.
#' @param probs Quantile der Overlay-Verteilungen für `low`/`high`.
#' @param delta relative Abweichung, wenn keine Verteilung vorliegt.
#' @param steps Stützstellen je Seite (Spider).
#' @param kpi Kennzahl (`NULL` = Primärkennzahl).
#' @param variant Variante (Default `"base"`).
#' @param reference Referenzvariante für Vergleichskennzahlen.
#' @return Objekt der Klasse `vofi_sensitivity`.
#' @family Analysieren
#' @export
vofi_sensitivity <- function(x, params = NULL, method = c("tornado", "spider", "global"),
                             probs = c(0.1, 0.9), delta = NULL, steps = 5L, kpi = NULL,
                             variant = "base", reference = NULL) {
  vofi_abort("core.not_implemented", fun = "vofi_sensitivity",
             .class = "vofi_error_not_implemented")
}
