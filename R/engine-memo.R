# Zwischenspeicher reiner Hilfsrechnungen über Läufe hinweg (WS-PERF, Spec 00 Abschnitt 9.10).
# Deterministische Pläne und Rasterrechnungen (Ereignisplan der Kredite, Verschiebungen und
# Indizes auf dem Zeitraster, Zeilenmetadaten der Komponenten, Periodenteil der
# Steuer-Eingaben) hängen nur von ihren Argumenten ab und wiederholen sich in jedem Lauf und
# Chunk eines Modells. eng_memo() speichert je Art die letzten Ergebnisse mit ihren Argumenten;
# ein Treffer verlangt identische Argumente (identical(), Zeigergleichheit ist der schnelle
# Fall), das Ergebnis ist daher dasselbe wie die neue Rechnung. Rechnungen, die eine Bedingung
# melden (Hinweis, Warnung), werden nicht gespeichert, damit jede Meldung bei jedem Lauf erneut
# erscheint.

#' Speicher der Zwischenergebnisse (je Art eine Liste `list(key, value)`, neueste zuerst)
#' @noRd
eng_memo_env <- new.env(parent = emptyenv())

#' Ergebnis einer reinen Funktion aus dem Zwischenspeicher bzw. neu gerechnet
#'
#' @param tag Art der Rechnung (z. B. `"loan_plan"`).
#' @param key Liste der Argumente, von denen das Ergebnis abhängt (vollständig).
#' @param fun Funktion ohne Argumente, die das Ergebnis rechnet.
#' @param size Höchstzahl gespeicherter Ergebnisse je Art.
#' @return Ergebnis von `fun()`.
#' @noRd
eng_memo <- function(tag, key, fun, size = 64L) {
  slot <- eng_memo_env[[tag]]
  for (e in slot) if (identical(e$key, key)) return(e$value)
  flag <- new.env(parent = emptyenv())
  flag$cond <- FALSE
  v <- withCallingHandlers(fun(), condition = function(cnd) flag$cond <- TRUE)
  if (!flag$cond) {
    slot <- c(list(list(key = key, value = v)), slot)
    if (length(slot) > size) slot <- slot[seq_len(size)]
    assign(tag, slot, envir = eng_memo_env)
  }
  v
}

#' Rasterrechnung mit Zwischenspeicher nur für kleine Eingaben (eine Zeile, wenige Werte)
#' @param small Eingabe klein genug für den Zwischenspeicher?
#' @inheritParams eng_memo
#' @noRd
eng_grid_memo <- function(tag, key, small, fun) {
  if (isTRUE(small)) eng_memo(tag, key, fun) else fun()
}

#' Zwischenspeicher leeren (alle Arten bzw. eine Art)
#' @param tag Art oder `NULL` (alle).
#' @return `invisible(NULL)`.
#' @noRd
eng_memo_clear <- function(tag = NULL) {
  have <- ls(eng_memo_env, all.names = TRUE)
  tags <- if (is.null(tag)) have else intersect(tag, have)
  if (length(tags) > 0L) rm(list = tags, envir = eng_memo_env)
  invisible(NULL)
}
