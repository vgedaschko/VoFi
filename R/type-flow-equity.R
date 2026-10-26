# Zahlungstyp equity: geplante Einlagen und Entnahmen des Investors (WS-E, Spec 00 7.12, Spec 01
# Teil A 4.12). Einmalige Einlage zum Termin date, Zahlungsplaene (Betraege >= 0, Vorzeichen setzt
# der Typ) und laufende Jahresbetraege ohne Fortschreibung im Zeitraum [start_event, to) (R-110).
# Die Sacheinlage des Bestandswerts (equity_in_kind, R-68) ist keine Komponente: die Engine bucht
# sie aus building.existing_value_eur (Spec 00 9.3); validate() warnt, wenn ein equity-Baustein
# denselben Bestandswert zusaetzlich als Bareinlage fuehrt.
# Die Hilfsfunktionen typ_timing_date(), typ_one_off() und typ_per_annum() werden auch von anderen
# Typen verwendet (u. a. R/type-inst-loan-core.R); Signatur und Semantik bleiben stabil.

#' Termin eines timing-Parameters als Datum (Token `completion` = Fertigstellung)
#' @param ctx Laufkontext.
#' @param spec Komponente.
#' @param name Parametername.
#' @param default Rückgabe ohne Angabe.
#' @return `Date` bzw. `default`.
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

#' Jahresbetrag je Periode im Zeitraum `[start, to)` (Betrag p. a. x Delta x Monatsanteil)
#' @param start Termin aus `ctx$timing()` (`date`, `shift`).
#' @noRd
typ_per_annum <- function(ctx, spec, name, start, to) {
  x <- ctx$param(spec, name, "path")
  if (is.null(x)) return(ctx$zeros())
  x * ctx$by_period(ctx$grid$delta) * ctx$shift_overlap(start$date, start$shift, to)
}

#' Nicht-negative Beträge (Zahlungspläne und Jahresbeträge sind >= 0; Vorzeichen setzt der Typ)
#'
#' Negative Werte einzelner Läufe (z. B. aus einer Verteilung) werden auf 0 begrenzt und einmal je
#' Komponente gemeldet; die Validierung meldet negative Konstanten als Fehler.
#' @noRd
equity_nonneg <- function(ctx, spec, x, what) {
  neg <- x < -vofi_tol$zero_abs
  if (any(neg)) {
    ctx$inform("types.flow.equity.msg.negative_clamped", id = spec[["id"]] %||% "?",
               param = what, share = mean(rowSums(neg) > 0))
  }
  pmax(x, 0)
}

#' Zahlungskomponente equity bauen (Spec 00 7.12, Spec 01 Teil A 4.12)
#' @noRd
equity_build <- function(spec, ctx) {
  g <- ctx$grid
  n <- ctx$n
  tm <- ctx$timing(spec, "date") %||% list(date = g$valuation_date, shift = rep(0, n))
  amount <- ctx$param(spec, "amount_eur") %||% rep(0, n)
  v_in <- equity_nonneg(ctx, spec, typ_one_off(ctx, amount, tm$date, tm$shift), "amount_eur")
  if (any(is.na(ctx$shift_period(tm$date, tm$shift)) & abs(amount) > 0)) {
    ctx$inform("types.flow.equity.msg.after_horizon", id = spec[["id"]] %||% "?")
  }
  fr <- ctx$timing(spec, "start_event") %||% list(date = g$valuation_date, shift = rep(0, n))
  to <- typ_timing_date(ctx, spec, "to", NULL)
  contrib <- ctx$param(spec, "contributions", "path")
  if (!is.null(contrib)) v_in <- v_in + equity_nonneg(ctx, spec, contrib, "contributions")
  v_in <- v_in + equity_nonneg(ctx, spec, typ_per_annum(ctx, spec, "contributions_pa", fr, to),
                               "contributions_pa")
  v_out <- equity_nonneg(ctx, spec, typ_per_annum(ctx, spec, "withdrawals_pa", fr, to),
                         "withdrawals_pa")
  wd <- ctx$param(spec, "withdrawals", "path")
  if (!is.null(wd)) v_out <- v_out + equity_nonneg(ctx, spec, wd, "withdrawals")
  vofi_flows(
    vofi_row("in", v_in, section = "equity", category = "equity_in"),
    vofi_row("out", -v_out, section = "equity", category = "equity_out")
  )
}

#' Prüfungen der Komponente equity (Spec 00 7.12, Spec 01 Teil A 4.12, R-68)
#' @noRd
equity_validate <- function(spec, scenario) {
  v <- typ_validator(spec, scenario, "equity")
  for (f in c("amount_eur", "contributions_pa", "withdrawals_pa")) {
    x <- typ_const(spec[[f]])
    if (!is.null(x) && any(x < 0)) v$add("error", "negative", f, param = f)
  }
  for (f in c("contributions", "withdrawals")) {
    node <- spec[[f]]
    amounts <- if (is.list(node) && identical(node[["kind"]], "schedule")) node[["amounts"]] else
      NULL
    vals <- unlist(lapply(if (is.list(amounts)) amounts else as.list(amounts), typ_const))
    if (length(vals) > 0L && any(vals < 0)) v$add("error", "negative", f, param = f)
  }
  st <- typ_spec_date(spec[["start_event"]])
  to <- typ_spec_date(spec[["to"]])
  if (!is.null(st) && !is.null(to) && st >= to) v$add("error", "start_after_to", "to")
  targets <- typ_ref_targets(spec[setdiff(names(spec), c("id", "type", "after"))])
  if ("building.existing_value_eur" %in% targets) {
    v$add("warning", "in_kind_double", "amount_eur")
  }
  v$out
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
      start_event = vofi_param("timing", grid_default = "valuation_date"),
      to = vofi_param("timing", grid_default = "end_date")
    ),
    rows = c("in", "out"),
    validate = equity_validate,
    build = equity_build,
    example = list(type = "equity", amount_eur = 40000, contributions_pa = 1200,
                   withdrawals_pa = 600, start_event = "2027-01-01",
                   contributions = list(schedule = list("2028-07-01" = 5000)),
                   withdrawals = list(schedule = list("2030-01-01" = 2000)))
  )
}
