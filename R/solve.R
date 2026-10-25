# Zielwertsuche (WS-G, Spec 00 Abschnitt 12.8).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-G. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Zielwertsuche
#'
#' Allgemeine Zielwertsuche (Kennzahl, Zielwert oder Schwelle `"threshold:<name>"`,
#' Monotonieprüfung), Entnahme-Äquivalent und Rendite der Mehrinvestition (Spec 00, Abschnitt
#' 12.8).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Objekt der Klasse `vofi_scenario` oder `vofi_model`.
#' @param what `"breakeven"`, `"critical_value"`, `"withdrawal_equivalent"` oder
#'   `"incremental_return"`.
#' @param param Pfad des variierten Parameters.
#' @param kpi Kennzahl (`NULL` = Primärkennzahl).
#' @param target Zielwert oder `"threshold:<name>"`.
#' @param interval Suchintervall (Default aus der Overlay-Verteilung bzw. Basis × [0,5; 1,5]).
#' @param tol Toleranz.
#' @param variant Variante (Default `"base"`).
#' @param reference Referenzvariante für Vergleichskennzahlen.
#' @param rebuild Modell je Auswertung neu bauen (Basisfallgrößen wie `auto`-Beträge neu
#'   bestimmen).
#' @return Objekt der Klasse `vofi_solution`.
#' @family Analysieren
#' @export
vofi_solve <- function(x, what = c("breakeven", "critical_value", "withdrawal_equivalent",
                                        "incremental_return"),
                       param = NULL, kpi = NULL, target = 0, interval = NULL, tol = 1e-8,
                       variant = "base", reference = NULL, rebuild = FALSE) {
  vofi_abort("core.not_implemented", fun = "vofi_solve",
             .class = "vofi_error_not_implemented")
}
