# Zahlungstyp recurring: laufender Jahresbetrag mit Kalenderjahresindex (WS-E, Spec 00 7.12).
# Phase-0-Minimalfassung, Eigentuemer: WS-E. Wert = +/- amount_eur * index_year(growth,
# base_date) * Delta_t * shift_overlap(from, shift, to) (R-62, 3.9); grid_invariant = TRUE.
# Offen fuer WS-E: validate() (Wachstumsform in amount_eur, direction gegen das Vorzeichen der
# Kategorie, Hinweis "Kategorie other_cost angenommen" fuer wu_*).

#' Abschnitt einer Kategorie der Abschnitte project bzw. grants
#' @noRd
typ_recurring_section <- function(category) {
  for (sec in c("project", "grants")) {
    if (!is.null(vocab_category(sec, category))) return(sec)
  }
  vofi_abort("core.contract.row_category", row = "value", section = "project/grants",
             category = category, suggestion = "", .class = "vofi_error_contract")
}

#' @noRd
typedef_recurring <- function() {
  vofi_type(
    name = "recurring", kind = "flow",
    params = list(
      amount_eur = vofi_param("amount", required = TRUE, min = 0, unit = "EUR"),
      # Jahresrate: Art rate (Pruefung > 1 nach 4.6) mit Shape scalar oder path (7.12)
      growth = vofi_param("rate", default = 0, shapes = c("scalar", "path")),
      base_date = vofi_param("timing"),
      from = vofi_param("timing", default = "completion"),
      to = vofi_param("timing", grid_default = "end_date"),
      category = vofi_param("string", default = "other_cost"),
      direction = vofi_param("enum", values = "vocab:direction"),
      tax_category = vofi_param("string")
    ),
    rows = "value",
    grid_invariant = TRUE,
    build = function(spec, ctx) {
      g <- ctx$grid
      cat <- ctx$setting(spec, "category") %||% "other_cost"
      sec <- typ_recurring_section(cat)
      sign <- switch(vocab_category(sec, cat)$sign,
        pos = 1,
        neg = -1,
        if (identical(ctx$setting(spec, "direction"), "inflow")) 1 else -1
      )
      pby <- ctx$project$price_base_year %||% (utl_year(g$valuation_date) - 1L)
      bd <- typ_timing_date(ctx, spec, "base_date",
                            as.Date(sprintf("%04d-01-01", as.integer(pby) + 1L)))
      idx <- ctx$index_year(ctx$param(spec, "growth", "path"), bd)
      fr <- ctx$timing(spec, "from") %||% list(date = g$valuation_date, shift = rep(0, ctx$n))
      to <- typ_timing_date(ctx, spec, "to", NULL)
      v <- sign * ctx$param(spec, "amount_eur") * idx * ctx$by_period(g$delta) *
        ctx$shift_overlap(fr$date, fr$shift, to)
      args <- list(key = "value", values = v, section = sec, category = cat)
      tc <- ctx$setting(spec, "tax_category")
      if (!is.null(tc)) args$tax_category <- tc
      vofi_flows(do.call(vofi_row, args))
    },
    example = list(type = "recurring", amount_eur = 14000, growth = 0.02,
                   base_date = "2027-01-01", from = "2027-01-01", category = "rent")
  )
}
