# Testumgebung (Integrator, Spec 00 Abschnitt 2.12): In Tests sind fehlende Labels Fehler.
local({
  old <- options(vofi.strict_labels = TRUE)
  if (requireNamespace("withr", quietly = TRUE)) {
    withr::defer(options(old), envir = testthat::teardown_env())
  }
})
