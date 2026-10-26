# Szenario einlesen und schreiben (WS-A, Spec 00 Abschnitte 4.1, 4.6, 4.13).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-A. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Szenario einlesen
#'
#' Liest ein Szenario aus YAML oder Excel, normalisiert es (Wertgrammatik, Einheiten, Aliase) und
#' liefert das kanonische Szenario-Objekt mit Herkunft der Blätter (Spec 00, Abschnitte 4.1, 4.6).
#' Optional wird ein separates Stochastik-Overlay gemischt (Datei gewinnt).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param path Pfad der Szenariodatei (`.yaml`/`.yml` oder `.xlsx`).
#' @param format `"auto"` (nach Dateiendung), `"yaml"` oder `"excel"`.
#' @param stochastic optional: Pfad einer YAML-Datei mit Wurzelschlüssel `stochastic`.
#' @param library_paths Wurzeln der Nutzerbibliotheken (später gewinnt).
#' @return Objekt der Klasse `vofi_scenario`.
#' @family Einlesen
#' @export
vofi_read_scenario <- function(path, format = c("auto", "yaml", "excel"), stochastic = NULL,
                               library_paths = vofi_library_paths()) {
  vofi_abort("core.not_implemented", fun = "vofi_read_scenario",
             .class = "vofi_error_not_implemented")
}

#' Szenario schreiben
#'
#' Schreibt ein Szenario (auf Wunsch eine aufgelöste Variante) als YAML oder Excel.
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param scenario Objekt der Klasse `vofi_scenario`.
#' @param path Zieldatei.
#' @param format `"auto"` (nach Dateiendung), `"yaml"` oder `"excel"`.
#' @param resolved aufgelöste Variante (Schichten gemischt) statt der Eingabeform schreiben.
#' @param variant Variante, die bei `resolved = TRUE` geschrieben wird.
#' @param overwrite vorhandene Datei überschreiben.
#' @return `invisible(path)`.
#' @family Einlesen
#' @export
vofi_write_scenario <- function(scenario, path, format = c("auto", "yaml", "excel"),
                                resolved = FALSE, variant = "base", overwrite = FALSE) {
  vofi_abort("core.not_implemented", fun = "vofi_write_scenario",
             .class = "vofi_error_not_implemented")
}

#' Kanonisches Szenario aus einer R-Liste
#'
#' Erzeugt ein kanonisches, normalisiertes Szenario aus einer R-Liste in YAML-Form.
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Liste mit den Blöcken der obersten Ebene (Spec 00, Abschnitt 4.2).
#' @param source optional: Herkunftsangaben (`path`, `format`, ...).
#' @return Objekt der Klasse `vofi_scenario`.
#' @family Einlesen
#' @export
vofi_scenario <- function(x, source = NULL) {
  vofi_abort("core.not_implemented", fun = "vofi_scenario",
             .class = "vofi_error_not_implemented")
}

#' Mitgelieferte Beispielszenarien
#'
#' Liefert den Pfad eines mitgelieferten Beispielszenarios bzw. die Namen aller Beispiele.
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param name Name des Beispiels (z. B. `"skeleton"`) oder `NULL`.
#' @return Zeichenkette (Pfad) bzw. Zeichenvektor der Namen.
#' @family Einlesen
#' @export
vofi_example <- function(name = NULL) {
  vofi_abort("core.not_implemented", fun = "vofi_example",
             .class = "vofi_error_not_implemented")
}
