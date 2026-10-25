# Kennzahlen-Registry und Ausgabe (WS-D2, Spec 00 Abschnitt 12).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-D2. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Kennzahlen eines Ergebnisses
#'
#' Liefert die Kennzahlen eines Ergebnisses mit Bezeichnung, Einheit und NA-Begründung;
#' EUR-Kennzahlen optional je Wohneinheit bzw. je m² Wohnfläche (Spec 00, Abschnitt 12).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Objekt der Klasse `vofi_result`, `vofi_mc_result` oder `vofi_comparison`.
#' @param which `NULL` (alle) oder Namen von Kennzahlen.
#' @param rv `"both"`, `"with"` (mit Restwert) oder `"without"` (ohne Restwert).
#' @param per `"total"`, `"unit"` (je Wohneinheit) oder `"m2"` (je m² Wohnfläche).
#' @return Data Frame der Kennzahlen.
#' @family Analysieren
#' @export
vofi_kpis <- function(x, which = NULL, rv = c("both", "with", "without"), per = c("total", "unit", "m2")) {
  vofi_abort("core.not_implemented", fun = "vofi_kpis",
             .class = "vofi_error_not_implemented")
}

#' Kennzahl registrieren
#'
#' Registriert eine Nutzerkennzahl `compute(core, ctx)` (Spec 00, Abschnitte 5.7, 12.1).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param name Name der Kennzahl.
#' @param compute Funktion `compute(core, ctx)`, die ein [vofi_kpi_value()] liefert.
#' @param label Anzeigename.
#' @param unit Einheit aus `inst/vocab/units.yaml`.
#' @param shape `"scalar"` oder `"series"`.
#' @param rv_variant zusätzlich ohne Restwert (`<name>_ex_rv`) berechnen.
#' @param higher_is_better Richtung der Kennzahl (`TRUE`, `FALSE` oder `NA`).
#' @param mc_default standardmäßig in der Simulation berechnen.
#' @param perspectives `NULL` (alle) oder zulässige Perspektiven.
#' @param requires benötigte Daten, Teilmenge von `opportunity`, `market_value`,
#'   `household_income`, `living_area`, `tenant_data`.
#' @param overwrite vorhandene Kennzahl ersetzen.
#' @return `invisible(def)`.
#' @family Erweitern
#' @export
vofi_register_kpi <- function(name, compute, label = NULL, unit = "EUR", shape = c("scalar", "series"),
                              rv_variant = FALSE, higher_is_better = TRUE, mc_default = FALSE,
                              perspectives = NULL, requires = character(), overwrite = FALSE) {
  vofi_abort("core.not_implemented", fun = "vofi_register_kpi",
             .class = "vofi_error_not_implemented")
}
