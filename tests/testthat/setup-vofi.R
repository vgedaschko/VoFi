# Testumgebung (Integrator, Spec 00 Abschnitt 2.12): In Tests sind fehlende Labels Fehler.
local({
  old <- options(vofi.strict_labels = TRUE)
  withr::defer(options(old), envir = testthat::teardown_env())
})
