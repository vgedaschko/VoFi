# Bedingungen: Fehler, Warnungen, Meldungen (Integrator, Spec 00 Abschnitt 2.9).
# Der Text jeder Bedingung entsteht über msg(key, ...) aus dem Label-Katalog (Abschnitt 2.10).
# Zulässige Bedingungsklassen stehen in inst/vocab/conditions.yaml (nur diese).

#' Fehler signalisieren
#'
#' Signalisiert einen Fehler der Klasse `c(.class, "vofi_error", "error", "condition")`; die
#' Funktion kehrt nie zurück. Ohne `.class` erhält der Schlüssel `core.not_implemented` die
#' Klasse `vofi_error_not_implemented`.
#' @param key Label-Schlüssel des Meldungstextes.
#' @param ... benannte Platzhalterwerte für `{name}` im Text.
#' @param .class zusätzliche Bedingungsklasse(n) aus `conditions.yaml`.
#' @param .data Liste mit Zusatzdaten (Feld `data` der Bedingung).
#' @param .call Aufruf, der in der Bedingung erscheint (Default: Aufrufer).
#' @return kehrt nicht zurück.
#' @noRd
vofi_abort <- function(key, ..., .class = NULL, .data = list(), .call = NULL) {
  if (is.null(.call) && sys.nframe() > 1L) .call <- sys.call(-1L)
  cond <- utl_condition(key, list(...), .class, "error", .data, .call)
  stop(cond)
}

#' Warnung signalisieren
#'
#' Klasse `c(.class, "vofi_warning", "warning", "condition")`.
#' @inheritParams vofi_abort
#' @return `invisible(NULL)`.
#' @noRd
vofi_warn <- function(key, ..., .class = NULL, .data = list()) {
  call <- if (sys.nframe() > 1L) sys.call(-1L) else NULL
  cond <- utl_condition(key, list(...), .class, "warning", .data, call)
  warning(cond)
  invisible(NULL)
}

#' Meldung ausgeben (nur bei `getOption("vofi.verbose", TRUE)`)
#'
#' Klasse `c(.class, "vofi_message", "message", "condition")`.
#' @inheritParams vofi_abort
#' @return `invisible(NULL)`.
#' @noRd
vofi_inform <- function(key, ..., .class = NULL) {
  if (!isTRUE(getOption("vofi.verbose", TRUE))) return(invisible(NULL))
  call <- if (sys.nframe() > 1L) sys.call(-1L) else NULL
  cond <- utl_condition(key, list(...), .class, "message", list(), call)
  message(cond)
  invisible(NULL)
}

#' Bedingungsobjekt bauen
#' @param key Label-Schlüssel.
#' @param args benannte Liste der Platzhalterwerte.
#' @param cls zusätzliche Klassen.
#' @param type `"error"`, `"warning"` oder `"message"`.
#' @param data Zusatzdaten.
#' @param call Aufruf.
#' @return Bedingungsobjekt (Liste mit `message`, `call`, `key`, `data`, `args`).
#' @noRd
utl_condition <- function(key, args, cls, type = c("error", "warning", "message"),
                          data = list(), call = NULL) {
  type <- match.arg(type)
  base <- switch(type, error = "vofi_error", warning = "vofi_warning", message = "vofi_message")
  if (type == "error" && is.null(cls) && identical(key, "core.not_implemented")) {
    cls <- "vofi_error_not_implemented"
  }
  cls <- setdiff(unique(as.character(cls)), base)
  utl_check_condition_class(cls, type)
  text <- utl_lbl_text(key, args)
  if (type == "message") text <- paste0(text, "\n")
  structure(
    list(message = text, call = call, key = key, data = data %||% list(), args = args),
    class = c(cls, base, type, "condition")
  )
}

#' Zulässigkeit der Bedingungsklassen prüfen (inst/vocab/conditions.yaml)
#' @noRd
utl_check_condition_class <- function(cls, type) {
  if (length(cls) == 0L) return(invisible(TRUE))
  tab <- vocab_state$data[["conditions"]]
  if (is.null(tab)) return(invisible(TRUE))           # Vokabular noch nicht geladen (.onLoad)
  allowed <- tab$code[tab$base == type]
  bad <- setdiff(cls, allowed)
  if (length(bad) > 0L) {
    text <- if (lbl_has("core.condition_class_invalid")) {
      lbl("core.condition_class_invalid", class = utl_collapse(bad), type = type)
    } else {
      paste0("[[core.condition_class_invalid]] ", utl_collapse(bad))
    }
    stop(structure(list(message = text, call = NULL, key = "core.condition_class_invalid",
                        data = list(class = bad), args = list()),
                   class = c("vofi_error_contract", "vofi_error", "error", "condition")))
  }
  invisible(TRUE)
}
