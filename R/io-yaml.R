# YAML-Leser mit den Zahlen- und Einheitenregeln aus Spec 00, Abschnitt 4.6 (WS-A).
# Phase-0-Minimalfassung, Eigentuemer: WS-A. Ausbau: io_write_yaml(), Zeilennummern fuer die
# Herkunft (location), vollstaendige Meldungstexte.
#
# Lesen ausschliesslich ueber io_read_yaml_utf8(): readLines(encoding = "UTF-8") + yaml.load()
# mit den Handlern int, float#fix, float#exp, float#inf, float#neginf, float#nan, bool#yes,
# bool#no (Namen MUSS). Mehrdeutige Zahlen (Dezimalkomma "3,5", Tausenderpunkt "150.000")
# werden nicht still umgedeutet, sondern als markierte Rohzahl (Klasse "vofi_raw_num")
# weitergegeben; die Normalisierung (R/values-normalize.R) kennt Pfad und Parameterart und
# entscheidet ueber Warnung (vofi_warning_input) bzw. Fehler (EUR-Parameter, vofi_error_input).

#' YAML-Datei eines Szenarios UTF-8-sicher lesen (Spec 00, Abschnitt 4.6)
#'
#' Phase-0-Minimalfassung, Eigentümer: WS-A.
#' @param path Dateipfad.
#' @return Liste (leere Datei: `list()`); Zahlen sind `double`, mehrdeutige Zahlen markierte
#'   Rohzahlen (`io_raw_num()`), Datumsangaben Zeichenketten (Umwandlung bei der Normalisierung).
#' @noRd
io_read_yaml_utf8 <- function(path) {
  if (!utl_is_string(path) || !file.exists(path)) {
    vofi_abort("core.file_missing", path = as.character(path %||% "NULL")[1L],
               .class = "vofi_error_input")
  }
  txt <- readLines(path, encoding = "UTF-8", warn = FALSE)
  bad <- which(!validUTF8(txt))
  if (length(bad) > 0L) {
    vofi_abort("io.not_utf8", path = path, line = as.character(bad[1L]),
               .class = "vofi_error_input")
  }
  res <- tryCatch(
    withCallingHandlers(
      yaml::yaml.load(paste(txt, collapse = "\n"), handlers = io_yaml_handlers(),
                      eval.expr = FALSE),
      warning = function(w) {
        if (inherits(w, "vofi_warning")) return(invisible(NULL))
        vofi_warn("io.yaml_warning", path = path, detail = conditionMessage(w),
                  .class = "vofi_warning_input")
        invokeRestart("muffleWarning")
      }
    ),
    vofi_error = function(e) stop(e),
    error = function(e) {
      vofi_abort("core.yaml_invalid", path = path, detail = conditionMessage(e),
                 .class = "vofi_error_input")
    }
  )
  if (is.null(res)) list() else res
}

#' YAML-Handler fuer Szenarien (Spec 00, Abschnitt 4.6; exakte Namen)
#' @return benannte Liste von Handlern fuer [yaml::yaml.load()].
#' @noRd
io_yaml_handlers <- function() {
  list(
    "int" = function(x) io_parse_int(x),
    # Fuehrende Null: libyaml taggt "0,02", "-0,5", "010" als oktal; der Rohtext geht wie bei
    # int an io_parse_int() (Dezimalkomma bzw. dezimale Lesung, nie oktal).
    "int#oct" = function(x) io_parse_int(x),
    "int#hex" = function(x) io_raw_num(x, NA_real_, "not_number"),
    # Sexagesimalformen ("1:30") bleiben Text
    "int#base60" = function(x) as.character(x),
    "float#base60" = function(x) as.character(x),
    "float#fix" = function(x) io_parse_float_fix(x),
    "float#exp" = function(x) as.double(x),
    "float#inf" = function(x) Inf,
    "float#neginf" = function(x) -Inf,
    "float#nan" = function(x) io_raw_num(x, NaN, "nan"),
    "bool#yes" = function(x) if (identical(tolower(x), "true")) TRUE else x,
    "bool#no" = function(x) if (identical(tolower(x), "false")) FALSE else x
  )
}

#' Rohtext des Handlers int
#'
#' Ganze Zahlen werden als `double` geliefert (auch ausserhalb des Integer-Bereichs, nie `NA`);
#' `"3,5"` (Dezimalkomma) wird als markierte Rohzahl weitergegeben.
#' @noRd
io_parse_int <- function(x) {
  s <- gsub("_", "", x, fixed = TRUE)
  if (grepl("^[-+]?0[0-9]+$", s)) {
    # fuehrende Null: dezimal lesen, Rohtext bleibt fuer Zeichenkettenparameter erhalten
    return(io_raw_num(x, as.double(s), "leading_zero"))
  }
  if (grepl("^[-+]?[0-9]+$", s)) return(as.double(s))
  if (grepl("^[-+]?[0-9]+,[0-9]+$", s)) {
    return(io_raw_num(x, as.double(sub(",", ".", s, fixed = TRUE)), "decimal_comma"))
  }
  io_raw_num(x, NA_real_, "not_number")
}

#' Rohtext des Handlers float#fix (Dezimalzahl mit Punkt, auch "150.000")
#' @noRd
io_parse_float_fix <- function(x) {
  s <- gsub("_", "", x, fixed = TRUE)
  v <- suppressWarnings(as.double(s))
  if (grepl("^[-+]?[1-9][0-9]{0,2}[.][0-9]{3}$", s)) {
    return(io_raw_num(x, v, "thousands"))
  }
  if (is.na(v)) return(io_raw_num(x, NA_real_, "not_number"))
  v
}

#' Markierte Rohzahl (unbenannte Liste, damit YAML-Sequenzen sie nicht vereinfachen)
#' @param raw Rohtext.
#' @param value gelesener Zahlenwert (bzw. `NA`).
#' @param note `"decimal_comma"`, `"thousands"`, `"leading_zero"`, `"nan"` oder
#'   `"not_number"`.
#' @noRd
io_raw_num <- function(raw, value, note) {
  structure(list(as.character(raw), as.double(value), as.character(note)),
            class = "vofi_raw_num")
}

#' Ist `x` eine markierte Rohzahl?
#' @noRd
io_is_raw_num <- function(x) inherits(x, "vofi_raw_num")

#' Zahl aus einem Rohwert bestimmen (Spec 00, Abschnitt 4.6)
#'
#' Zahlen bleiben Zahlen (`double`). Markierte Rohzahlen: Dezimalkomma -> Wert mit
#' `vofi_warning_input`; Tausenderpunkt -> bei EUR-Parametern `vofi_error_input`, sonst Wert
#' mit Warnung; führende Null (`010`) -> dezimal. Zeichenketten folgen denselben Regeln
#' (`"150.000"` wie unquotiert, auch für den Excel-Leser): `"3,5 %"`/`"3.5%"` -> 0.035
#' (Warnung), `"1.234.567"`, `"150_000"`, `"1e-2"` -> Zahl mit Hinweis, `".inf"` -> `Inf`.
#' @param x Rohwert (Skalar).
#' @param path Pfad fuer Meldungen.
#' @param eur `TRUE`, wenn der Parameter ein EUR-Betrag ist.
#' @return double(1) oder `NULL`, wenn `x` keine Zahl darstellt.
#' @noRd
io_as_number <- function(x, path = "", eur = FALSE) {
  if (io_is_raw_num(x)) {
    raw <- x[[1L]]
    v <- x[[2L]]
    note <- x[[3L]]
    if (identical(note, "decimal_comma")) {
      vofi_warn("io.decimal_comma", path = path, raw = raw, value = v,
                .class = "vofi_warning_input")
      return(v)
    }
    if (identical(note, "leading_zero")) return(v)
    if (identical(note, "nan")) {
      vofi_abort("io.nan", path = path, value = raw, .class = "vofi_error_input")
    }
    if (identical(note, "thousands")) {
      if (isTRUE(eur)) {
        vofi_abort("io.thousands_eur", path = path, raw = raw,
                   value = gsub(".", "", raw, fixed = TRUE), .class = "vofi_error_input")
      }
      vofi_warn("io.thousands", path = path, raw = raw, value = v,
                .class = "vofi_warning_input")
      return(v)
    }
    return(NULL)
  }
  if (is.logical(x) && length(x) == 1L && !is.na(x)) return(NULL)
  if (is.numeric(x) && length(x) == 1L) return(as.double(x))
  if (!utl_is_string(x)) return(NULL)
  s <- trimws(x)
  if (s %in% c(".inf", "+.inf", "Inf", "inf")) return(Inf)
  if (s %in% c("-.inf", "-Inf", "-inf")) return(-Inf)
  if (grepl("^[-+]?[0-9]+([.,][0-9]+)?[[:space:]]*%$", s)) {
    num <- as.double(sub(",", ".", sub("[[:space:]]*%$", "", s), fixed = FALSE))
    vofi_warn("io.percent", path = path, raw = s, value = num / 100,
              .class = "vofi_warning_input")
    return(num / 100)
  }
  if (grepl("^[-+]?[1-9][0-9]{0,2}[.][0-9]{3}$", s)) {
    # wie unquotiert (Handler float#fix): Tausenderpunkt mehrdeutig (4.6)
    return(io_as_number(io_raw_num(s, as.double(s), "thousands"), path, eur))
  }
  if (grepl("^[-+]?[0-9]+,[0-9]+$", s)) {
    v <- as.double(sub(",", ".", s, fixed = TRUE))
    vofi_warn("io.decimal_comma", path = path, raw = s, value = v,
              .class = "vofi_warning_input")
    return(v)
  }
  if (grepl("^[-+]?[0-9]{1,3}([.][0-9]{3}){2,}$", s) || grepl("^[-+]?[0-9][0-9_]*$", s) ||
      grepl("^[-+]?[0-9]+([.][0-9]+)?[eE][-+]?[0-9]+$", s)) {
    v <- as.double(gsub("[._]", "", s))
    if (grepl("[eE]", s)) v <- as.double(s)
    if (!identical(s, format(v, scientific = FALSE, trim = TRUE))) {
      vofi_inform("io.number_read", path = path, raw = s, value = v)
    }
    return(v)
  }
  if (grepl("^[-+]?[0-9]*[.][0-9]+$", s)) return(as.double(s))
  NULL
}

#' Markierte Rohzahlen in einer beliebigen Struktur aufloesen (Restdurchlauf)
#'
#' Fuer Stellen ohne Parameterschema entscheidet das Schluesselsuffix `_eur` ueber die
#' Behandlung des Tausenderpunkts (4.3: Einheiten als Suffix im Schluessel).
#' @param x Struktur.
#' @param path Pfad.
#' @return Struktur ohne markierte Rohzahlen.
#' @noRd
io_unmark <- function(x, path = "") {
  if (io_is_raw_num(x)) {
    v <- io_as_number(x, path, eur = io_path_is_eur(path))
    if (is.null(v)) {
      vofi_abort("io.not_number", path = path, raw = x[[1L]], .class = "vofi_error_input")
    }
    return(v)
  }
  if (is.list(x) && !is.data.frame(x) && !io_is_raw_num(x)) {
    nms <- names(x)
    for (i in seq_along(x)) {
      seg <- if (!is.null(nms) && nzchar(nms[i])) nms[i] else as.character(i)
      if (!is.null(x[[i]])) x[[i]] <- io_unmark(x[[i]], path_join(path, seg))
    }
    if (is.null(nms) && length(x) > 0L &&
        all(vapply(x, function(e) is.numeric(e) && length(e) == 1L, logical(1)))) {
      x <- as.double(unlist(x))
    }
  }
  x
}

#' Ist der Pfad ein EUR-Betrag nach Schluesselsuffix?
#' @noRd
io_path_is_eur <- function(path) {
  segs <- path_split(path)
  segs <- segs[!grepl("^[0-9]+$", segs)]
  length(segs) > 0L && grepl("_eur$", segs[length(segs)])
}
