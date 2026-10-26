# Label-Katalog (Integrator, Spec 00 Abschnitt 2.10).
# Alle Nutzertexte stehen in inst/labels/de/**/*.yaml; R-Code enthält nur Schlüssel (2.7 Nr. 1).
# Schlüsselpräfix = relativer Dateipfad ohne Endung mit "/" -> "." (core.yaml -> core.*,
# types/instrument/annuity_loan.yaml -> types.instrument.annuity_loan.*).

lbl_state <- new.env(parent = emptyenv())
lbl_state$labels <- new.env(hash = TRUE, parent = emptyenv())
lbl_state$sources <- new.env(hash = TRUE, parent = emptyenv())
lbl_state$dir <- NULL

#' Label-Katalog laden
#'
#' Liest alle YAML-Dateien unter `dir` rekursiv (UTF-8-sicher) und ersetzt den geladenen Katalog.
#' Doppelte Schlüssel (auch über Dateigrenzen nach dem Abflachen) sind ein Fehler
#' (`vofi_error_label`).
#' @param dir Wurzel des Katalogs, z. B. `system.file("labels", "de", package = "vofi")`.
#' @return `invisible(Anzahl Schlüssel)`.
#' @noRd
lbl_load <- function(dir) {
  if (!utl_is_string(dir) || !nzchar(dir) || !dir.exists(dir)) {
    vofi_abort("core.label_dir_missing", dir = as.character(dir %||% "NULL")[1L],
               .class = "vofi_error_label")
  }
  files <- utl_sort(list.files(dir, pattern = "\\.ya?ml$", recursive = TRUE))
  env <- new.env(hash = TRUE, parent = emptyenv())
  src <- new.env(hash = TRUE, parent = emptyenv())
  dup <- NULL
  for (f in files) {
    prefix <- gsub("/", ".", sub("\\.ya?ml$", "", f), fixed = TRUE)
    flat <- utl_flatten_labels(utl_read_yaml(file.path(dir, f)), prefix)
    for (k in names(flat)) {
      if (exists(k, envir = env, inherits = FALSE)) {
        dup <- list(key = k, file = f, other = get(k, envir = src, inherits = FALSE))
        break
      }
      assign(k, flat[[k]], envir = env)
      assign(k, f, envir = src)
    }
    if (!is.null(dup)) break
  }
  lbl_state$labels <- env
  lbl_state$sources <- src
  lbl_state$dir <- dir
  if (!is.null(dup)) {
    vofi_abort("core.label_duplicate", label = dup$key, file = dup$file, other = dup$other,
               .class = "vofi_error_label")
  }
  invisible(length(ls(env, all.names = TRUE)))
}

#' Verschachtelte Label-Liste abflachen
#' @param x Liste aus YAML.
#' @param prefix Schlüsselpräfix.
#' @return benannte Liste Schlüssel -> Text (UTF-8); Sequenzen werden mit Zeilenumbruch verbunden.
#' @noRd
utl_flatten_labels <- function(x, prefix) {
  if (is.null(x)) return(list())
  if (is.list(x) && !is.null(names(x))) {
    parts <- lapply(names(x), function(nm) utl_flatten_labels(x[[nm]], path_join(prefix, nm)))
    out <- do.call(c, parts)
    return(if (is.null(out)) list() else out)
  }
  text <- paste(as.character(unlist(x, use.names = FALSE)), collapse = "\n")
  stats::setNames(list(enc2utf8(text)), prefix)
}

#' Text zu einem Label-Schlüssel
#'
#' `...` ersetzt Platzhalter `{name}` (Zeichen unverändert, Zahlen mit `fmt_num(x, 2)`, ganze
#' Zahlen vom Typ integer mit `fmt_int()`, Datumswerte mit `fmt_date()`), `{name:int}`,
#' `{name:num}`, `{name:pct}`, `{name:eur}`, `{name:date}`, `{name:raw}` (`format()` ohne
#' Lokalisierung). Vektoren werden mit `", "` verbunden.
#'
#' Fehlender Schlüssel: bei `getOption("vofi.strict_labels")` ein Fehler `vofi_error_label`,
#' sonst `.default` bzw. `"[[key]]"`. Fehlender Platzhalterwert: `{name}` bleibt sichtbar, bei
#' strikten Labels Fehler. Platzhalter dürfen nicht `key` heißen (Formal von `lbl()`,
#' `msg()` und `vofi_abort()`); für Zeilennamen ist `row` üblich.
#' @param key Label-Schlüssel.
#' @param ... benannte Platzhalterwerte.
#' @param .default Ersatztext, wenn der Schlüssel fehlt.
#' @return Zeichenkette (UTF-8).
#' @noRd
lbl <- function(key, ..., .default = NULL) {
  utl_lbl_text(key, list(...), .default)
}

#' Text zu einem Schlüssel mit Platzhalterliste (Arbeitsfunktion von lbl(), msg() und den
#' Bedingungen; Platzhalter dürfen hier auch `key` heißen)
#' @noRd
utl_lbl_text <- function(key, args = list(), .default = NULL) {
  text <- if (utl_is_string(key)) {
    get0(key, envir = lbl_state$labels, inherits = FALSE)
  } else {
    NULL
  }
  if (is.null(text)) {
    if (!is.null(.default)) {
      text <- .default
    } else if (isTRUE(getOption("vofi.strict_labels", FALSE))) {
      utl_label_error("core.label_missing", as.character(key)[1L])
    } else {
      return(paste0("[[", as.character(key)[1L], "]]"))
    }
  }
  if (!grepl("{", text, fixed = TRUE)) return(text)
  utl_fill_placeholders(text, args, key)
}

#' Meldungstext (identisch zu `lbl()`, Name für Meldungen)
#' @inheritParams lbl
#' @noRd
msg <- function(key, ...) lbl(key, ...)

#' Existiert der Label-Schlüssel?
#' @param key Schlüssel.
#' @return `TRUE`/`FALSE`.
#' @noRd
lbl_has <- function(key) {
  utl_is_string(key) && exists(key, envir = lbl_state$labels, inherits = FALSE)
}

#' Alle geladenen Schlüssel (optional mit Präfix)
#' @param prefix z. B. `"vocab.sections"`.
#' @return sortierter Zeichenvektor.
#' @noRd
lbl_keys <- function(prefix = NULL) {
  keys <- ls(lbl_state$labels, all.names = TRUE)
  if (!is.null(prefix)) {
    keys <- keys[startsWith(keys, paste0(prefix, "."))]
  }
  utl_sort(keys)
}

#' Platzhalter ersetzen
#' @noRd
utl_fill_placeholders <- function(text, args, key,
                                  strict = isTRUE(getOption("vofi.strict_labels", FALSE))) {
  pattern <- "\\{([A-Za-z_][A-Za-z0-9_.]*)(:(int|num|pct|eur|date|raw))?\\}"
  m <- gregexpr(pattern, text, perl = TRUE)
  tokens <- regmatches(text, m)[[1L]]
  if (length(tokens) == 0L) return(text)
  repl <- vapply(tokens, function(tok) {
    inner <- substr(tok, 2L, nchar(tok) - 1L)
    parts <- strsplit(inner, ":", fixed = TRUE)[[1L]]
    name <- parts[1L]
    fmt <- if (length(parts) > 1L) parts[2L] else ""
    if (!(name %in% names(args))) {
      if (strict) utl_label_error("core.label_placeholder_missing", key, name)
      return(tok)
    }
    utl_format_placeholder(args[[name]], fmt)
  }, character(1), USE.NAMES = FALSE)
  regmatches(text, m) <- list(enc2utf8(repl))
  enc2utf8(text)
}

#' Platzhalterwert formatieren
#' @noRd
utl_format_placeholder <- function(x, fmt = "") {
  if (is.null(x) || length(x) == 0L) return("")
  if (is.factor(x)) x <- as.character(x)
  out <- switch(fmt,
    int = fmt_int(x),
    num = fmt_num(x, 2),
    pct = fmt_pct(x),
    eur = fmt_eur(x),
    date = fmt_date(x),
    raw = if (is.list(x)) {
      vapply(x, function(e) paste(format(e), collapse = " "), "")
    } else {
      format(x)
    },
    {
      if (inherits(x, "Date")) {
        fmt_date(x)
      } else if (is.integer(x)) {
        fmt_int(x)
      } else if (is.numeric(x)) {
        fmt_num(x, 2)
      } else if (is.list(x)) {
        vapply(x, function(e) paste(as.character(e), collapse = " "), "")
      } else {
        as.character(x)
      }
    }
  )
  enc2utf8(paste(out, collapse = ", "))
}

#' Label-Fehler ohne Rekursion über vofi_abort()
#' @noRd
utl_label_error <- function(which, key, placeholder = NULL) {
  tmpl <- get0(which, envir = lbl_state$labels, inherits = FALSE)
  args <- list(key = key, placeholder = placeholder %||% "")
  text <- if (is.null(tmpl)) {
    paste0("[[", which, "]] ", key)
  } else {
    utl_fill_placeholders(tmpl, args, which, strict = FALSE)
  }
  stop(structure(list(message = text, call = NULL, key = which, data = args, args = args),
                 class = c("vofi_error_label", "vofi_error", "error", "condition")))
}
