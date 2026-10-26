# Kreditbetraege amount_eur: auto und topup (WS-D, Spec 00 Abschnitt 8.7, R-69).
# Phase-0-Minimalfassung, Eigentuemer: WS-D. In Phase 0 sind auto und topup noch nicht
# umgesetzt; ein Modell mit einem solchen Baustein meldet vofi_error_not_implemented beim Bau.
# Offen fuer WS-D: Bedarf im Fenster W, Basisfall-Plan (model$base$auto, need0), topup je Lauf,
# Rundung auf auto_round_eur, Puffer auto_buffer_share.

#' Funktion ist in Phase 0 noch nicht verfügbar (Engine)
#' @noRd
eng_unsupported <- function(what) {
  vofi_abort("core.not_implemented", fun = what, .class = "vofi_error_not_implemented")
}

#' auto-Betrag im Basisfall-Vorlauf bestimmen (9.1 Stufe 6a)
#' @return `list(auto = NULL | list(commitment, draws), need0 = NULL | num)`.
#' @noRd
eng_auto_base <- function(model, ctx, exo) {
  if (length(model$auto_id) > 0L || length(model$topup_id) > 0L) {
    eng_unsupported("amount_eur: auto/topup")
  }
  list(auto = NULL, need0 = NULL)
}

#' auto aus dem Basisfall (fest), topup je Lauf (9.2 Stufe 4)
#' @noRd
eng_auto_amounts <- function(model, ctx, exo, engine_env = NULL) {
  if (length(model$topup_id) > 0L) eng_unsupported("amount_eur: topup")
  invisible(NULL)
}
