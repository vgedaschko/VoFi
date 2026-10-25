# Pfadfunktionen für verschachtelte Listen (Integrator, Spec 00 Abschnitt 4.4 Nr. 4).
# Pfade sind punktgetrennte Schlüssel, z. B. "financing.bank.rate_pa". Zugriffe verwenden `[[`
# mit exakter Namensübereinstimmung (kein Partial Matching, Abschnitt 2.7 Nr. 2).

#' Pfad in Segmente zerlegen
#' @param path Zeichenkette, z. B. `"components.z.values"`; `""` ergibt `character(0)`.
#' @return Zeichenvektor der Segmente.
#' @noRd
path_split <- function(path) {
  if (is.null(path) || length(path) == 0L || is.na(path[1L]) || !nzchar(path[1L])) {
    return(character(0))
  }
  strsplit(path[1L], ".", fixed = TRUE)[[1L]]
}

#' Pfadsegmente verbinden (leere Segmente entfallen)
#' @param ... Zeichenketten oder Zeichenvektoren.
#' @return Zeichenkette.
#' @noRd
path_join <- function(...) {
  parts <- unlist(list(...), use.names = FALSE)
  parts <- as.character(parts)
  parts <- parts[!is.na(parts) & nzchar(parts)]
  paste(parts, collapse = ".")
}

#' Hat `x` ein Element mit genau diesem Namen?
#' @noRd
utl_has_name <- function(x, nm) {
  is.list(x) && !is.null(names(x)) && nm %in% names(x)
}

#' Wert am Pfad lesen
#' @param x Liste.
#' @param path Pfad.
#' @return Knoten am Pfad oder `NULL`, wenn der Pfad nicht existiert.
#' @noRd
path_get <- function(x, path) {
  for (seg in path_split(path)) {
    if (!utl_has_name(x, seg)) return(NULL)
    x <- x[[seg]]
  }
  x
}

#' Existiert der Pfad?
#' @param x Liste.
#' @param path Pfad.
#' @return `TRUE`/`FALSE`.
#' @noRd
path_exists <- function(x, path) {
  for (seg in path_split(path)) {
    if (!utl_has_name(x, seg)) return(FALSE)
    x <- x[[seg]]
  }
  TRUE
}

#' Wert am Pfad setzen
#'
#' Fehlende Zwischenebenen werden als Listen angelegt. `value = NULL` entfernt das Element.
#' Klassen und Attribute der Zwischenebenen bleiben erhalten.
#' @param x Liste.
#' @param path Pfad (nicht leer).
#' @param value neuer Wert.
#' @return geänderte Liste.
#' @noRd
path_set <- function(x, path, value) {
  segs <- path_split(path)
  if (length(segs) == 0L) return(value)
  utl_path_set(x, segs, value, path)
}

#' @noRd
utl_path_set <- function(x, segs, value, path) {
  if (is.null(x)) x <- list()
  if (!is.list(x)) {
    vofi_abort("core.path_not_map", path = path, segment = segs[1L],
               .class = "vofi_error_input")
  }
  seg <- segs[1L]
  if (length(segs) == 1L) {
    if (is.null(value)) {
      if (utl_has_name(x, seg)) x[[seg]] <- NULL
    } else {
      x[seg] <- list(value)
    }
    return(x)
  }
  child <- if (utl_has_name(x, seg)) x[[seg]] else NULL
  new_child <- utl_path_set(child, segs[-1L], value, path)
  x[seg] <- list(new_child)
  x
}

#' Element am Pfad entfernen
#' @param x Liste.
#' @param path Pfad.
#' @return Liste ohne das Element (unverändert, wenn der Pfad nicht existiert).
#' @noRd
path_remove <- function(x, path) {
  if (!path_exists(x, path)) return(x)
  path_set(x, path, NULL)
}

#' Alle Blattpfade einer Liste
#'
#' Blätter sind alle Nicht-Maps (Skalare, Vektoren, Sequenzen, Datumswerte) sowie Wertformen
#' nach [is_value_form()]. Leere Maps haben keine Blätter.
#' @param x Liste.
#' @param path Präfix.
#' @param kind_of optional `function(path)` -> Parameterart (siehe [is_value_form()]).
#' @return Zeichenvektor der Blattpfade (Reihenfolge der Liste).
#' @noRd
path_leaves <- function(x, path = "", kind_of = NULL) {
  if (is.null(x)) return(character(0))
  if (!is_map(x) || is_value_form(x, path, kind_of)) {
    return(if (nzchar(path)) path else character(0))
  }
  out <- lapply(names(x), function(nm) path_leaves(x[[nm]], path_join(path, nm), kind_of))
  unlist(out, use.names = FALSE) %||% character(0)
}
