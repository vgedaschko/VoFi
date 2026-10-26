# Standard-Steuermodul tax_none (WS-D, Spec 00 Abschnitte 10.2, 10.6).
# Nach 10.6: uses_inputs = FALSE, Zahlung 0 in jeder Periode, keine offene Steuer am Horizont;
# die Zeile `tax` traegt in der Anzeige den Vermerk core.rows.tax_note_none. Ein Lauf mit
# tax_none ist bitgleich zu einem Lauf ohne Hook-Aufruf (Vertragstest T1, 10.10 Nr. 1).

#' Steuermodul ohne Ertragsteuern (Vor-Steuer-VoFi, D5)
#' @noRd
typedef_tax_none <- function() {
  vofi_type(
    name = "none", kind = "tax", params = list(), perspectives = NULL, blocked_regimes = NULL,
    uses_inputs = FALSE,
    constructor = function(params, spec) new_tax_module("none", params = params),
    example = list()
  )
}

# tax_none: leerer Zustand (10.6).
#' @rdname tax_init
#' @export
tax_init.tax_none <- function(module, params, assets, measures, n_sim) {
  list()
}

# tax_none: Zahlung 0 in jeder Periode (10.6).
#' @rdname tax_step
#' @export
tax_step.tax_none <- function(module, t, inputs, interest, state, params) {
  # n aus den Zinsgroessen (10.4: n-Vektoren, immer uebergeben); tax_init liefert list() (10.6)
  n <- max(1L, length(interest[["endo_haben"]]), length(interest[["exo_soll"]]))
  list(payment = numeric(n), state = state, report = list())
}

# tax_none: keine offene Steuer am Horizont (10.6).
#' @rdname tax_finalize
#' @export
tax_finalize.tax_none <- function(module, T, state, terminal_inputs, params) { # nolint
  n <- max(c(1L, length(terminal_inputs$residual_value), lengths(terminal_inputs$exo_T)))
  list(payment_T = numeric(n), report = list())
}
