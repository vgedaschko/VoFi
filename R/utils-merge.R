# Deep-Merge der Schichten und Erkennung von Wertformen (Integrator, Spec 00 Abschnitt 4.7).

#' Ist `x` eine Map (benannte Liste)?
#'
#' Eine leere Liste gilt als (leere) Map. Data Frames und Wertknoten mit Klasse sind keine Maps
#' im Sinne der Merge-Semantik, wenn sie keine Namen tragen.
#' @param x Objekt.
#' @return `TRUE`/`FALSE`.
#' @noRd
is_map <- function(x) {
  if (!is.list(x) || is.data.frame(x)) return(FALSE)
  if (length(x) == 0L) return(TRUE)
  nms <- names(x)
  !is.null(nms) && all(!is.na(nms) & nzchar(nms))
}

#' Schlüsselmengen der Wertformen (Abschnitt 4.7, `is_value_form()`)
#'
#' `req` = Pflichtschlüssel, `opt` = zulässige weitere Schlüssel; `opt = NA` bedeutet offen
#' (Verteilungsparameter bzw. lokale Angaben neben `from`).
#' @noRd
utl_value_form_keys <- function() {
  list(
    ref = list(req = "ref", opt = c("scale", "offset", "floor", "cap", "anchor")),
    expr = list(req = "expr", opt = character(0)),
    series_year = list(req = "series", opt = c("fill", "before")),
    points = list(req = c("years", "values"), opt = "interpolate"),
    schedule = list(req = "schedule", opt = "unit"),
    growth = list(req = c("start", "growth"), opt = c("base_date", "real")),
    quantity = list(req = c("value", "per"), opt = character(0)),
    dist = list(req = "dist", opt = NA_character_),
    from = list(req = "from", opt = NA_character_)
  )
}

#' Strukturell erkannte Wertform einer Map
#' @param x Map.
#' @return Name der Wertform (`"ref"`, `"expr"`, ...) oder `NA_character_`, wenn keine oder
#'   mehr als eine Wertform passt.
#' @noRd
utl_value_form_kind <- function(x) {
  if (!is_map(x) || length(x) == 0L) return(NA_character_)
  nms <- names(x)
  forms <- utl_value_form_keys()
  hit <- vapply(forms, function(f) {
    if (!all(f$req %in% nms)) return(FALSE)
    if (length(f$opt) == 1L && is.na(f$opt)) return(TRUE)
    all(nms %in% c(f$req, f$opt))
  }, logical(1))
  if (sum(hit) == 1L) names(forms)[hit] else NA_character_
}

#' Ist `x` eine Wertform (Blatt der Wertgrammatik)?
#'
#' 1. Liefert `kind_of(path)` eine Parameterart, entscheidet sie: Wertformen gibt es nur bei
#'    den Arten `value`, `amount`, `rate`, `share`, `number`, `schedule`; bei diesen Arten wird
#'    zusätzlich die Struktur geprüft (eine Teil-Map wie `{fill: zero}` ist keine Wertform und
#'    wird gemischt).
#' 2. Sonst strukturell: `x` ist eine Map, deren Namen vollständig in der Schlüsselmenge genau
#'    einer Wertform liegen und deren Pflichtschlüssel enthalten.
#' @param x Objekt.
#' @param path Pfad des Knotens (für `kind_of`).
#' @param kind_of `NULL` oder `function(path)` -> Parameterart bzw. `NULL`/`NA`, wenn der Pfad
#'   kein Parameterpfad ist.
#' @return `TRUE`/`FALSE`.
#' @noRd
is_value_form <- function(x, path = "", kind_of = NULL) {
  if (!is_map(x) || length(x) == 0L) return(FALSE)
  if (!is.null(kind_of)) {
    k <- kind_of(path)
    if (length(k) == 1L && !is.na(k)) {
      if (!(k %in% c("value", "amount", "rate", "share", "number", "schedule"))) return(FALSE)
    }
  }
  !is.na(utl_value_form_kind(x))
}

#' Deep-Merge zweier Schichten (Abschnitt 4.7, MUSS)
#'
#' Maps werden rekursiv gemischt, alles andere wird ersetzt. Ein explizites `NULL` (YAML `~`)
#' auf der Override-Seite löscht den Schlüssel; `.replace: true` ersetzt eine Map vollständig;
#' eine Wertform auf der Override-Seite ersetzt den Basisknoten als Ganzes.
#' @param base Basis.
#' @param override Override.
#' @param path aktueller Pfad.
#' @param kind_of optional, siehe [is_value_form()].
#' @return gemischtes Objekt.
#' @noRd
deep_merge <- function(base, override, path = "", kind_of = NULL) {
  if (!is_map(base) || !is_map(override)) return(override)
  if (is_value_form(override, path, kind_of)) return(override)
  if (utl_has_name(override, ".replace")) {
    replace <- override[[".replace"]]
    override[[".replace"]] <- NULL
    if (isTRUE(replace)) return(override)
  }
  for (nm in names(override)) {
    if (is.null(override[[nm]])) {
      if (utl_has_name(base, nm)) base[[nm]] <- NULL
    } else {
      child <- if (utl_has_name(base, nm)) base[[nm]] else NULL
      base[nm] <- list(deep_merge(child, override[[nm]], path_join(path, nm), kind_of))
    }
  }
  base
}
