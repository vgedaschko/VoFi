# Lauf-Stufen, Einzellauf (WS-D, Spec 00 Abschnitt 9.2).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-D. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' VoFi berechnen
#'
#' Berechnet den VoFi deterministisch (`n_sim = 1`) oder als Monte-Carlo-Simulation (`n_sim > 1`,
#' Delegation an [vofi_mc()]) (Spec 00, Abschnitt 9.2).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param model Objekt der Klasse `vofi_model`.
#' @param n_sim Anzahl der Läufe.
#' @param seed Seed (ganze Zahl in `[1, 2^31 - 2]`); Default aus `stochastic$settings$seed`.
#' @param store Speicherstrategie: `"auto"`, `"full"`, `"bands"` oder `"kpi"`.
#' @param chunk_size Läufe je Chunk (wird auf ganze Blöcke abgerundet).
#' @return Objekt der Klasse `vofi_result` bzw. `vofi_mc_result`.
#' @family Rechnen
#' @export
vofi_run <- function(model, n_sim = 1L, seed = NULL, store = c("auto", "full", "bands", "kpi"),
                     chunk_size = getOption("vofi.chunk_size", 2000L)) {
  vofi_abort("core.not_implemented", fun = "vofi_run",
             .class = "vofi_error_not_implemented")
}

#' Einzellauf einer Simulation nachrechnen
#'
#' Rechnet Lauf `i` einer Simulation mit vollständiger VoFi-Tabelle nach; das Ergebnis ist
#' identisch zum Lauf im Batch (Spec 00, Abschnitt 11.4).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Objekt der Klasse `vofi_mc_result`.
#' @param i globale Laufnummer.
#' @return Objekt der Klasse `vofi_result`.
#' @family Rechnen
#' @export
vofi_sim <- function(x, i) {
  vofi_abort("core.not_implemented", fun = "vofi_sim",
             .class = "vofi_error_not_implemented")
}
