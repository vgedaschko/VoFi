# Parameterbibliothek (WS-A, Spec 00 Abschnitt 4.9).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-A. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Einträge der Parameterbibliothek
#'
#' Listet die Einträge der Parameterbibliothek mit Metadaten und Gültigkeit zum Datum (Spec 00,
#' Abschnitt 4.9).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param block `NULL` oder Zielblock (z. B. `"funding"`).
#' @param library_paths Wurzeln der Nutzerbibliotheken.
#' @param date Stichtag der Gültigkeitsprüfung (Default: heute).
#' @return Data Frame mit einer Zeile je Eintrag.
#' @family Einlesen
#' @export
vofi_library <- function(block = NULL, library_paths = vofi_library_paths(), date = NULL) {
  vofi_abort("core.not_implemented", fun = "vofi_library",
             .class = "vofi_error_not_implemented")
}

#' Bibliothekspfade
#'
#' Gibt die Bibliothekspfade zurück (Paketbibliothek und Option `vofi.library_paths`) bzw. ergänzt
#' Nutzerpfade. Die Reihenfolge ist die Suchreihenfolge der Schichten 3 und 4 (Spec 00,
#' Abschnitte 2.12, 4.7, 4.9): zuerst die Paketbibliothek, dann die Option, dann `add`; bei
#' gleicher id gewinnt der spätere Pfad.
#'
#' Phase-0-Minimalfassung (Eigentümer: WS-A): Pfade werden nur zusammengestellt; die Bibliothek
#' wird erst mit WS-A ausgewertet.
#'
#' @param add optional: zusätzliche Bibliothekswurzeln.
#' @return Zeichenvektor der Pfade.
#' @family Einlesen
#' @examples
#' vofi_library_paths()
#' @export
vofi_library_paths <- function(add = NULL) {
  if (!is.null(add) && (!is.character(add) || anyNA(add))) {
    vofi_abort("core.arg_character", arg = "add", .class = "vofi_error_input")
  }
  pkg <- system.file("extdata", "library", package = "vofi")
  opt <- getOption("vofi.library_paths", character(0))
  out <- c(if (nzchar(pkg)) pkg, as.character(opt), add)
  unique(out[nzchar(out)])
}
