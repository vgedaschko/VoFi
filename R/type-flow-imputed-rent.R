# Zahlungstyp imputed_rent: ersparte Miete der Selbstnutzer (WS-E, Spec 01 Teil B Abschnitt
# 3.10.3). value = area_m2 · rent_eur_m2_month · 12 · index_year(growth, base_date) · delta ·
# overlap; nur für den Vergleich „Kaufen oder Mieten“ (in Variantenvergleichen gleicher Gebäude
# hebt sich die Zeile auf). grid_invariant = TRUE (Jahresbetrag mit Kalenderjahresindex und
# Monatsanteilen).

#' @noRd
ir_build <- function(spec, ctx) {
  g <- ctx$grid
  n <- ctx$n
  par <- function(nm, shape = "scalar") ctx$param(spec, nm, shape)
  area <- rep_len(par("area_m2"), n)
  rent <- par("rent_eur_m2_month", "path")
  growth <- par("growth", "path") %||% ctx$zeros()
  bd <- ctx$setting(spec, "base_date") %||% grid_add_months(g$valuation_date, 12L)
  idx <- ctx$index_year(growth, bd)
  st <- ctx$timing(spec, "start_event") %||% list(date = g$valuation_date, shift = rep(0, n))
  to <- ctx$timing(spec, "to")
  ov <- ctx$shift_overlap(st$date, st$shift, if (is.null(to)) NULL else to$date)
  v <- area * rent * 12 * idx * ctx$by_period(g$delta) * ov
  vofi_flows(list(vofi_row("value", v, section = "project", category = "imputed_rent",
                           tax_category = "imputed_benefit")))
}

#' @noRd
typedef_imputed_rent <- function() {
  p <- vofi_param
  vofi_type(
    name = "imputed_rent", kind = "flow",
    params = list(
      area_m2 = p("number", required = TRUE, min = 0, unit = "m2"),
      rent_eur_m2_month = p("value", required = TRUE, unit = "EUR_m2_month"),
      growth = p("value", default = 0, unit = "rate_pa"),
      base_date = p("timing"),
      start_event = p("timing", grid_default = "valuation_date"),
      to = p("timing", grid_default = "end_date")
    ),
    rows = "value",
    grid_invariant = TRUE,
    build = function(spec, ctx) ir_build(spec, ctx),
    example = list(type = "imputed_rent", area_m2 = 140, rent_eur_m2_month = 9,
                   growth = 0.015, base_date = "2027-01-01")
  )
}
