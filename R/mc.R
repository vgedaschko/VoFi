# Monte-Carlo-Schleife, Bänder, keep_runs (WS-G, Spec 00 Abschnitte 9.2, 9.9).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-G. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Monte-Carlo-Simulation
#'
#' Führt die Monte-Carlo-Simulation in Chunks aus ganzen Blöcken aus. Nicht gesetzte (`NULL`)
#' Argumente kommen aus `stochastic$settings` (dort alternativ `replicates`); `preview = TRUE`
#' rechnet 1.000 Läufe (= die ersten 1.000 Läufe des Standardlaufs); Entscheidungsknoten werden
#' als Kompositum gerechnet (Spec 00, Abschnitte 9.2, 9.9, 9.11, 11.4).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param model Objekt der Klasse `vofi_model`.
#' @param n_sim Anzahl der Läufe (Vielfaches der Blockgröße).
#' @param seed Seed (ganze Zahl in `[1, 2^31 - 2]`).
#' @param sampling `"lhs"` oder `"pseudo"`.
#' @param block_size Läufe je Block (Default 200).
#' @param store `"bands"`, `"kpi"` oder `"full"` (Default `"bands"`).
#' @param bands Ledger-Zeilen, für die Fächerbänder gebildet werden.
#' @param keep_runs zu speichernde Einzelläufe, z. B. `c("p05", "p50", "p95")`.
#' @param parallel Chunks über `future.apply` verteilen (Ergebnisse identisch).
#' @param chunk_size Läufe je Chunk.
#' @param preview Vorschau mit 1.000 Läufen.
#' @return Objekt der Klasse `vofi_mc_result`.
#' @family Analysieren
#' @export
vofi_mc <- function(model, n_sim = NULL, seed = NULL, sampling = NULL, block_size = NULL,
                    store = NULL, bands = NULL, keep_runs = NULL, parallel = FALSE,
                    chunk_size = getOption("vofi.chunk_size", 2000L), preview = FALSE) {
  vofi_abort("core.not_implemented", fun = "vofi_mc",
             .class = "vofi_error_not_implemented")
}
