# Erzeugt Excel-Fassungen der mitgelieferten Beispielszenarien (WS-A2, Spec 00 Abschnitte 2.2,
# 4.14): je inst/extdata/examples/<name>.yaml eine Arbeitsmappe <name>.xlsx im Layout der
# Eingabevorlage. Jede Datei wird sofort wieder eingelesen und mit dem YAML-Szenario verglichen
# (verlustfreier Round-Trip YAML -> XLSX -> Liste, identical()).
#
# Aufruf aus der Paketwurzel:
#   Rscript data-raw/build_examples_xlsx.R                      # nach inst/extdata/examples
#   Rscript data-raw/build_examples_xlsx.R <zielverzeichnis>    # z. B. für Praktiker-Pakete
#
# Hinweis: Die Beispiele gehören ihren Eigentümern (skeleton: Integrator, grob_lehrbuch_a: WS-T,
# s1-s5: WS-S, Spec 00 2.4); welche xlsx-Fassungen eingecheckt werden, entscheidet der Integrator.

if (!file.exists("DESCRIPTION")) stop("Bitte aus der Paketwurzel aufrufen.")
if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all(".", quiet = TRUE)
} else {
  library(vofi)
}

args <- commandArgs(trailingOnly = TRUE)
src_dir <- file.path("inst", "extdata", "examples")
out_dir <- if (length(args) >= 1L) args[1L] else src_dir
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

blocks <- function(sc) {
  x <- unclass(sc)
  attributes(x) <- list(names = names(x))
  x
}

files <- sort(list.files(src_dir, pattern = "\\.ya?ml$", full.names = TRUE), method = "radix")
ok <- TRUE
for (f in files) {
  name <- sub("\\.ya?ml$", "", basename(f))
  sc <- vofi_read_scenario(f)
  out <- file.path(out_dir, paste0(name, ".xlsx"))
  vofi_write_scenario(sc, out, overwrite = TRUE)
  back <- vofi_read_scenario(out)
  same <- identical(blocks(back), blocks(sc))
  message(sprintf("%-28s -> %s  (Round-Trip %s)", basename(f), out,
                  if (same) "identisch" else "ABWEICHEND"))
  ok <- ok && same
}
if (!ok) stop("Mindestens ein Beispiel ist nach dem Round-Trip nicht identisch.")
