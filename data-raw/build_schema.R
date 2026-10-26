# Erzeugt das ausgelieferte JSON-Schema des Szenarios (WS-B; Memo 05 4.11).
#
# Aufruf aus dem Paketverzeichnis:
#   Rscript data-raw/build_schema.R
#
# Grundlage sind der Feldkatalog (R/schema.R) und die beim Laden registrierten Typen der
# Registry (Komponenten, Finanzierungsbausteine, Verteilungen, Prozesse). Nach Änderungen am
# Katalog oder an registrierten Typen neu ausführen; tests/testthat/test-schema.R vergleicht
# die Datei mit dem erzeugten Schema.

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("Paket 'pkgload' wird benoetigt.", call. = FALSE)
}
pkgload::load_all(".", quiet = TRUE)
out <- file.path("inst", "schema", "vofi-scenario.schema.json")
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
vofi_json_schema(out)
message("JSON-Schema geschrieben: ", out)
