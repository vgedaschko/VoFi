# Laden des Pakets (Integrator, Spec 00 Abschnitt 5.5).
# Reihenfolge: Registry leeren, Label-Katalog und Vokabulare laden, eingebaute Typen über die
# typedef_*-Funktionen registrieren (sortiert mit method = "radix"), dann noch nicht gesetzte
# vofi.*-Optionen setzen (einzige erlaubte globale Wirkung, Abschnitt 2.7 Nr. 3).

.onLoad <- function(libname, pkgname) {
  ns <- asNamespace(pkgname)
  reg_reset()
  lbl_load(system.file("labels", "de", package = pkgname))
  vocab_load(system.file("vocab", package = pkgname))
  reg_discover(ns)
  op <- list(vofi.library_paths = character(), vofi.chunk_size = 2000L, vofi.max_memory_gb = 2,
             vofi.verbose = TRUE, vofi.strict_labels = FALSE, vofi.language = "de")
  toset <- !(names(op) %in% names(options()))
  if (any(toset)) options(op[toset])
  invisible()
}
