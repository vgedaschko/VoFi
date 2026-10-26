# Testumgebung (Integrator, Spec 00 Abschnitt 2.12): In Tests sind fehlende Labels Fehler.
local({
  old <- options(vofi.strict_labels = TRUE)
  if (requireNamespace("withr", quietly = TRUE)) {
    withr::defer(options(old), envir = testthat::teardown_env())
  }
})

# Unter covr (R_COVR = "true") entstehen die Closures der Typdefinitionen in .onLoad vor der
# Instrumentierung; die Registry wird deshalb mit den instrumentierten typedef_*() neu
# aufgebaut, damit build/apply/compute der Typen in der Abdeckung erscheinen (DoD 15.7).
if (identical(Sys.getenv("R_COVR"), "true")) {
  local({
    ns <- asNamespace("vofi")
    get("reg_reset", envir = ns)()
    get("reg_discover", envir = ns)(ns)
  })
}
