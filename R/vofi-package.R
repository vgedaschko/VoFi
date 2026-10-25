#' vofi: Vollständiger Finanzplan (VoFi) mit Monte-Carlo-Simulation für Wohngebäude
#'
#' Wirtschaftlichkeitsbewertung von Neubau und energetischer Sanierung von Wohngebäuden in
#' Deutschland nach der Methode des Vollständigen Finanzplans (Grob) aus Sicht von
#' Wohnungsunternehmen, privaten Vermietern und Selbstnutzern. Alle Zahlungen werden je Periode
#' erfasst, der Finanzierungssaldo ist in jeder Periode null; Zeitreihen sind Matrizen
#' n × (T+1) (Läufe × Zeitpunkte), sodass deterministische Rechnung (n = 1) und
#' Monte-Carlo-Simulation denselben Code durchlaufen.
#'
#' Verbindliche Grundlage ist die Spezifikation `docs/spec/00_kernvertraege.md`
#' (`contract_version` 1.0.0).
#'
#' @section Optionen:
#' \describe{
#'   \item{`vofi.library_paths`}{zusätzliche Bibliothekswurzeln (Default `character()`).}
#'   \item{`vofi.chunk_size`}{Läufe je Chunk (Default `2000L`).}
#'   \item{`vofi.max_memory_gb`}{Schwelle der Speicherwarnung (Default `2`).}
#'   \item{`vofi.verbose`}{Meldungen ausgeben (Default `TRUE`).}
#'   \item{`vofi.strict_labels`}{fehlende Labels als Fehler (Default `FALSE`, in Tests `TRUE`).}
#'   \item{`vofi.language`}{Sprache der Texte (reserviert, nur `"de"`).}
#' }
#'
#' @keywords internal
#' @importFrom stats qnorm quantile sd setNames
#' @importFrom utils adist head
"_PACKAGE"
