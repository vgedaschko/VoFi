# Erzeugt die ausgelieferte Excel-Eingabevorlage inst/templates/vofi_eingabe.xlsx (WS-A2,
# Spec 00 Abschnitt 4.14, Memo 05 Abschnitt 4.10).
#
# Die Vorlage wird aus Registry, Vokabularen, Feldkatalog, Defaults-Dateien, Paketbibliothek und
# Label-Katalog generiert (vofi_excel_template()). tests/testthat/test-io-excel-template.R
# vergleicht die ausgelieferte Datei Zelle für Zelle mit einer frisch generierten Vorlage; nach
# Änderungen an Typen, Parametern, Vokabularen, Labels, global.yaml, Profilen oder der
# Paketbibliothek dieses Skript erneut ausführen und die Datei einchecken.
#
# Aufruf aus der Paketwurzel:  Rscript data-raw/build_template.R

if (!file.exists("DESCRIPTION")) stop("Bitte aus der Paketwurzel aufrufen.")
if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all(".", quiet = TRUE)
} else {
  library(vofi)
}

# Nur die Paketbibliothek (keine Nutzerbibliotheken aus der Option), damit die Vorlage auf jedem
# Rechner gleich ist
old <- options(vofi.library_paths = character(0))
on.exit(options(old), add = TRUE)

dir.create(file.path("inst", "templates"), showWarnings = FALSE, recursive = TRUE)
out <- file.path("inst", "templates", "vofi_eingabe.xlsx")
vofi_excel_template(out, overwrite = TRUE)
message("Vorlage geschrieben: ", out)
