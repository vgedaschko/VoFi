# Wertgrammatik -> Knoten (WS-A, Spec 00 Abschnitt 4.5).
# Phase 0 (P0a): Knotenkonstruktoren nach den Knotenstrukturen aus 4.5 (für bctx, 6.4) und Stub
# von node_normalize() (vom Prüfkit verwendet). Minimalfassung von node_normalize(): Phase 0b;
# Eigentümer und Ausbau: WS-A.

#' Rohwert der Wertgrammatik in einen Knoten überführen (Spec 00, Abschnitte 4.5, 4.6)
#'
#' Vertrag für die Umsetzung (vom Prüfkit vorausgesetzt): numerische Arten (`number`, `amount`,
#' `rate`, `share`, `value`, `schedule`; `param = NULL` = allgemeine Wertgrammatik) liefern einen
#' Knoten `list(kind = ...)` (Zahl -> `const`, Vektor der Länge T+1 -> `series_t`, Maps nach 4.5);
#' nicht-numerische Arten den normalisierten Wert (`Date`, chr, lgl, int); `map` eine Liste der
#' normalisierten Felder. Numerische Blätter werden als double gespeichert.
#' @param x Rohwert (YAML-Form).
#' @param param `NULL` oder `vofi_param` des Ziels.
#' @param path Pfad für Meldungen.
#' @return Knoten bzw. normalisierter Wert.
#' @noRd
node_normalize <- function(x, param = NULL, path = NULL) {
  vofi_abort("core.not_implemented", fun = "node_normalize",
             .class = "vofi_error_not_implemented")
}

#' Konstantenknoten (4.5)
#' @param x Zahl.
#' @return `list(kind = "const", value = <double>)`.
#' @noRd
node_const <- function(x) list(kind = "const", value = as.double(x))

#' Bezugsknoten (4.5)
#' @return `list(kind = "ref", path, scale, offset, floor, cap, anchor)`.
#' @noRd
node_ref <- function(path, scale = 1, offset = 0, floor = -Inf, cap = Inf) {
  list(kind = "ref", path = path, scale = as.double(scale), offset = as.double(offset),
       floor = as.double(floor), cap = as.double(cap), anchor = NULL)
}

#' Zahlungsplanknoten (4.5)
#' @param dates `Date`-Vektor der Termine.
#' @param amounts Beträge (Zahlen oder skalare Knoten).
#' @return `list(kind = "schedule", dates, amounts)`.
#' @noRd
node_schedule <- function(dates, amounts) {
  list(kind = "schedule", dates = dates, amounts = amounts)
}

#' Wachstumsknoten (4.5)
#' @return `list(kind = "growth", start, growth, base_date, real = FALSE)`.
#' @noRd
node_growth <- function(start, growth, base_date = NULL) {
  list(kind = "growth", start = start, growth = growth, base_date = base_date, real = FALSE)
}
