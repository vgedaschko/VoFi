# Zahlungstyp equity: geplante Einlagen und Entnahmen (WS-E, Spec 00 Abschnitt 7.12).
# Phase-0-Minimalfassung, Eigentuemer: WS-E. Parameter nach 7.12 vollstaendig; offen fuer WS-E:
# Validierung (Beträge der Zahlungsplaene >= 0) als validate()-Funktion, Hinweis auf
# Zahlungen nach dem Horizont je Komponente.

#' Termin eines timing-Parameters als Datum (Token `completion` = Fertigstellung)
#' @noRd
typ_timing_date <- function(ctx, spec, name, default) {
  v <- ctx$setting(spec, name)
  if (is.null(v)) return(default)
  if (identical(v, "completion")) return(ctx$grid$completion_date)
  v
}

#' Einmalbetrag in der (ggf. laufspezifisch verschobenen) Periode eines Termins
#' @param ctx Laufkontext.
#' @param amount n-Vektor.
#' @param date Datum.
#' @param shift n-Vektor der Verschiebung in Monaten.
#' @return n x (T+1).
#' @noRd
typ_one_off <- function(ctx, amount, date, shift) {
  out <- ctx$zeros()
  p <- ctx$shift_period(date, shift)
  ok <- !is.na(p)
  if (any(ok)) out[cbind(which(ok), p[ok] + 1L)] <- amount[ok]
  out
}

#' Jahresbetrag je Periode im Zeitraum [from, to) (Betrag p. a. x Delta x Monatsanteil)
#' @noRd
typ_per_annum <- function(ctx, spec, name, from, to) {
  x <- ctx$param(spec, name, "path")
  if (is.null(x)) return(ctx$zeros())
  x * ctx$by_period(ctx$grid$delta) * ctx$shift_overlap(from$date, from$shift, to)
}

#' @noRd
typedef_equity <- function() {
  vofi_type(
    name = "equity", kind = "flow",
    params = list(
      amount_eur = vofi_param("amount", default = 0, min = 0, unit = "EUR"),
      date = vofi_param("timing", grid_default = "valuation_date"),
      contributions = vofi_param("schedule", unit = "EUR"),
      contributions_pa = vofi_param("value", default = 0, unit = "EUR"),
      withdrawals = vofi_param("schedule", unit = "EUR"),
      withdrawals_pa = vofi_param("value", default = 0, unit = "EUR"),
      from = vofi_param("timing", grid_default = "valuation_date"),
      to = vofi_param("timing", grid_default = "end_date")
    ),
    rows = c("in", "out"),
    build = function(spec, ctx) {
      g <- ctx$grid
      tm <- ctx$timing(spec, "date") %||% list(date = g$valuation_date, shift = rep(0, ctx$n))
      v_in <- typ_one_off(ctx, ctx$param(spec, "amount_eur") %||% rep(0, ctx$n), tm$date,
                          tm$shift)
      fr <- ctx$timing(spec, "from") %||% list(date = g$valuation_date, shift = rep(0, ctx$n))
      to <- typ_timing_date(ctx, spec, "to", NULL)
      contrib <- ctx$param(spec, "contributions", "path")
      if (!is.null(contrib)) v_in <- v_in + contrib
      v_in <- v_in + typ_per_annum(ctx, spec, "contributions_pa", fr, to)
      v_out <- typ_per_annum(ctx, spec, "withdrawals_pa", fr, to)
      wd <- ctx$param(spec, "withdrawals", "path")
      if (!is.null(wd)) v_out <- v_out + wd
      vofi_flows(
        vofi_row("in", v_in, section = "equity", category = "equity_in"),
        vofi_row("out", -v_out, section = "equity", category = "equity_out")
      )
    },
    example = list(type = "equity", amount_eur = 40000, contributions_pa = 1200,
                   withdrawals_pa = 600, from = "2027-01-01")
  )
}
