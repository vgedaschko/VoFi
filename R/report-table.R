# VoFi-Tabelle und Zahlungsbuch (WS-H, Spec 00 Abschnitte 7.8-7.10).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-H. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' VoFi-Tabelle
#'
#' Erzeugt die VoFi-Tabelle im Grob-Layout bzw. transponiert (Spec 00, Abschnitte 7.8, 7.9).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Objekt der Klasse `vofi_result`, `vofi_mc_result` oder `vofi_comparison`.
#' @param sim Lauf (bei mehreren Läufen).
#' @param layout `"grob"` oder `"transposed"`.
#' @param detail `"standard"` (Summen je Kategorie) oder `"full"` (jede Ledger-Zeile).
#' @param periods `NULL` (alle) oder Auswahl der Perioden.
#' @param variant Variante (bei Vergleichen).
#' @return Objekt der Klasse `vofi_table`.
#' @family Berichten
#' @export
vofi_table <- function(x, sim = 1L, layout = c("grob", "transposed"),
                       detail = c("standard", "full"), periods = NULL, variant = NULL) {
  vofi_abort("core.not_implemented", fun = "vofi_table",
             .class = "vofi_error_not_implemented")
}

#' Zahlungsbuch
#'
#' Liefert das Zahlungsbuch im Long- oder Wide-Format, optional mit Netto und Umsatzsteuer (Spec
#' 00, Abschnitte 7.4, 7.10).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Objekt der Klasse `vofi_result` oder `vofi_mc_result`.
#' @param format `"long"` oder `"wide"`.
#' @param sim `NULL` (alle Läufe) oder Laufnummern.
#' @param vat Netto und Umsatzsteuer getrennt ausgeben.
#' @return Data Frame.
#' @family Berichten
#' @export
vofi_ledger <- function(x, format = c("long", "wide"), sim = NULL, vat = FALSE) {
  vofi_abort("core.not_implemented", fun = "vofi_ledger",
             .class = "vofi_error_not_implemented")
}
