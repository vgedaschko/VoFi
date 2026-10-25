# Shiny-Viewer (Integrator-Stub; Umsetzung v1.1 durch WS-J).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: I (Stub), v1.1 WS-J. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Shiny-Viewer starten
#'
#' Startet den Shiny-Viewer. In v1 ist die Funktion ein Platzhalter mit Hinweis auf v1.1.
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param scenario optional: Szenario oder Pfad.
#' @param launch.browser Browser öffnen.
#' @param ... weitere Angaben an `shiny::runApp()`.
#' @return kein Rückgabewert (v1: Fehler `vofi_error_not_implemented`).
#' @family Berichten
#' @export
vofi_app <- function(scenario = NULL, launch.browser = interactive(), ...) { # nolint
  vofi_abort("core.not_implemented", fun = "vofi_app",
             .class = "vofi_error_not_implemented")
}
