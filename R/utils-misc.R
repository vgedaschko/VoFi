# Allgemeine interne Hilfsfunktionen (Integrator, Spec 00 Abschnitt 2.4).
# Alle Funktionen sind intern; Präfix utl_ (Abschnitt 2.7 Nr. 4).

#' Ersatzwert für NULL
#'
#' Liefert `x`, falls `x` nicht `NULL` ist, sonst `y` (wie `%||%` ab R 4.4).
#' @param x,y beliebige Objekte.
#' @return `x` oder `y`.
#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x

#' YAML-Handler für paketinterne Kataloge
#'
#' Nur die Literale `true`/`false` werden logisch; `yes`, `no`, `on`, `off`, `y`, `n` bleiben
#' Zeichenketten (auch als Schlüssel, z. B. Codes). Szenarien liest ausschließlich
#' `io_read_yaml_utf8()` (WS-A, Abschnitt 4.6) mit eigenen Handlern.
#' @return Liste von Handlern für [yaml::yaml.load()].
#' @noRd
utl_yaml_handlers <- function() {
  list(
    "bool#yes" = function(x) if (identical(tolower(x), "true")) TRUE else x,
    "bool#no" = function(x) if (identical(tolower(x), "false")) FALSE else x
  )
}

#' Paketinterne YAML-Datei (Vokabular, Labels) UTF-8-sicher lesen
#'
#' Funktioniert auch unter der Locale `C`: Die Datei wird als UTF-8 gelesen, alle Zeichenketten
#' sind als UTF-8 markiert.
#' @param path Dateipfad.
#' @return Liste (leere Datei: `list()`).
#' @noRd
utl_read_yaml <- function(path) {
  if (!file.exists(path)) {
    vofi_abort("core.file_missing", path = path, .class = "vofi_error_input")
  }
  txt <- readLines(path, encoding = "UTF-8", warn = FALSE)
  res <- tryCatch(
    yaml::yaml.load(paste(txt, collapse = "\n"), handlers = utl_yaml_handlers(),
                    eval.expr = FALSE),
    error = function(e) {
      vofi_abort("core.yaml_invalid", path = path, detail = conditionMessage(e),
                 .class = "vofi_error_input")
    }
  )
  if (is.null(res)) list() else res
}

#' Gebietsschemaunabhängig sortieren (Abschnitt 2.7 Nr. 8)
#' @param x Vektor.
#' @return sortierter Vektor (C-Ordnung, `method = "radix"`).
#' @noRd
utl_sort <- function(x) {
  if (length(x) == 0L) return(x)
  sort(x, method = "radix")
}

#' Vorschlag für einen unbekannten Code (Levenshtein, `utils::adist`)
#' @param x Zeichenkette.
#' @param choices zulässige Werte.
#' @param max_dist größte zulässige Distanz.
#' @return bester Vorschlag oder `NULL`.
#' @noRd
utl_suggest <- function(x, choices, max_dist = 3) {
  choices <- unique(as.character(choices))
  if (length(choices) == 0L || length(x) != 1L || is.na(x)) return(NULL)
  d <- utils::adist(x, choices, ignore.case = TRUE)[1L, ]
  if (min(d) > max_dist) return(NULL)
  choices[which.min(d)]
}

#' Text "Meinten Sie ...?" für Fehlermeldungen
#' @noRd
utl_suggest_text <- function(x, choices) {
  s <- utl_suggest(x, choices)
  if (is.null(s)) "" else lbl("core.did_you_mean", suggestion = s)
}

#' Suggests-Paket prüfen (Abschnitt 2.5)
#' @param pkg Paketname.
#' @param fun aufrufende Funktion (für die Meldung).
#' @return `invisible(TRUE)` oder Fehler `core.suggests_missing`.
#' @noRd
utl_require <- function(pkg, fun) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    vofi_abort("core.suggests_missing", pkg = pkg, fun = fun, .class = "vofi_error_input")
  }
  invisible(TRUE)
}

#' Prüft id-Muster (Abschnitt 4.4 Nr. 2)
#' @param x Zeichenvektor.
#' @param max_len maximale Länge.
#' @return logischer Vektor.
#' @noRd
utl_is_id <- function(x, max_len = 40L) {
  is.character(x) & !is.na(x) & grepl("^[a-z][a-z0-9_]*$", x) &
    !grepl("__", x, fixed = TRUE) & nchar(x) <= max_len
}

#' Ist `x` eine einzelne, nicht fehlende Zeichenkette?
#' @noRd
utl_is_string <- function(x) is.character(x) && length(x) == 1L && !is.na(x)

#' Ist `x` ein einzelner logischer Wert (nicht NA)?
#' @noRd
utl_is_flag <- function(x) is.logical(x) && length(x) == 1L && !is.na(x)

#' Ist `x` eine einzelne ganze Zahl (integer oder ganzzahliges double)?
#' @noRd
utl_is_whole <- function(x) {
  is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x) &&
    abs(x - round(x)) < 1e-9
}

#' Datum aus Date oder ISO-Zeichenkette
#' @param x Eingabe.
#' @param arg Argumentname für die Meldung.
#' @param allow_null `NULL` zulassen.
#' @return `Date` (Länge wie Eingabe) oder `NULL`.
#' @noRd
utl_as_date <- function(x, arg = "date", allow_null = FALSE) {
  if (is.null(x)) {
    if (allow_null) return(NULL)
    vofi_abort("core.date_invalid", arg = arg, value = "NULL", .class = "vofi_error_input")
  }
  if (inherits(x, "Date")) {
    out <- x
  } else if (is.character(x)) {
    out <- as.Date(x, format = "%Y-%m-%d", optional = TRUE)
  } else {
    out <- as.Date(NA)
  }
  if (length(out) == 0L || anyNA(out)) {
    vofi_abort("core.date_invalid", arg = arg, value = paste(format(x), collapse = ", "),
               .class = "vofi_error_input")
  }
  out
}

#' Werte für Meldungen zusammenfassen
#' @noRd
utl_collapse <- function(x, sep = ", ") paste(as.character(x), collapse = sep)

#' Logische Felder einer Liste vervollständigen (Defaults einsetzen)
#' @param x Liste.
#' @param defaults benannte Liste der Defaults.
#' @return `x` mit eingesetzten Defaults (fehlende Namen; `NULL` bleibt erhalten, wenn vorhanden).
#' @noRd
utl_fill_defaults <- function(x, defaults) {
  for (nm in names(defaults)) {
    if (!(nm %in% names(x))) x[nm] <- list(defaults[[nm]])
  }
  x
}

#' Argument gegen zulässige Werte prüfen (wie `match.arg()`, mit Bedingungsklasse)
#' @param x Wert; ist `x` identisch zu `choices`, gilt der erste Wert.
#' @param choices zulässige Werte.
#' @param arg Argumentname.
#' @return gewählter Wert.
#' @noRd
utl_match_arg <- function(x, choices, arg = "x") {
  if (identical(x, choices)) return(choices[1L])
  if (!utl_is_string(x) || !(x %in% choices)) {
    vofi_abort("core.arg_invalid", arg = arg, value = utl_collapse(format(x)),
               choices = utl_collapse(choices), .class = "vofi_error_input")
  }
  x
}

#' Ganze Zahl prüfen
#' @param x Wert.
#' @param arg Argumentname.
#' @param min,max Grenzen (optional).
#' @return integer(1).
#' @noRd
utl_check_whole <- function(x, arg, min = -Inf, max = Inf) {
  if (!utl_is_whole(x) || x < min || x > max) {
    vofi_abort("core.arg_whole", arg = arg, value = utl_collapse(format(x)),
               min = format(min), max = format(max), .class = "vofi_error_input")
  }
  as.integer(round(x))
}
