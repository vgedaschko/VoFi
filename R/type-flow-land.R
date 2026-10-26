# Zahlungstyp land: Kaufpreis eines Erwerbs mit Aufteilung Boden/Gebaeude (WS-E, Spec 01 Teil A
# 4.7). Termin ueber ctx$timing() (Token completion mit Bauzeitverzug) und laufspezifische
# Verschiebung delay_months (Spec 00 3.9); Kaufpreis nominal (Vertragspreis, nicht indexiert).

#' Anlagen-ids eines Erwerbs (Default `<building_id>_land` bzw. `<building_id>_building`, 4.5.4)
#' @noRd
typ_acq_asset_ids <- function(ctx, spec) {
  bid <- ctx$building$building_id %||% "b1"
  list(land = ctx$setting(spec, "land_asset_id") %||% paste0(bid, "_land"),
       building = ctx$setting(spec, "building_asset_id") %||% paste0(bid, "_building"))
}

#' Buchungsperiode eines Erwerbstermins je Lauf (Termin + delay_months)
#' @noRd
typ_acq_period <- function(ctx, spec, type) {
  tm <- ctx$timing(spec, "date")
  if (is.null(tm)) {
    ctx$abort(paste0("types.flow.", type, ".msg.no_date"), id = spec[["id"]] %||% "?")
  }
  p <- ctx$shift_period(tm$date, tm$shift + typ_shift_param(ctx, spec, "delay_months"))
  typ_inform_after_horizon(ctx, spec, type, is.na(p))
  p
}

#' Zahlungskomponente land bauen (Spec 01 Teil A 4.7)
#' @noRd
land_build <- function(spec, ctx) {
  n <- ctx$n
  price <- ctx$param(spec, "purchase_price_eur")
  if (is.null(price)) {
    ctx$abort("types.flow.land.msg.no_price", id = spec[["id"]] %||% "?")
  }
  s <- ctx$param(spec, "land_share") %||% rep(1, n)
  a <- ctx$param(spec, "active") %||% rep(1, n)
  p <- typ_acq_period(ctx, spec, "land")
  ids <- typ_acq_asset_ids(ctx, spec)
  vofi_flows(
    vofi_row("price_land", typ_book(ctx$zeros(), p, -price * s * a), section = "project",
             category = "land", tax_category = "capex_land", asset_id = ids$land,
             measure_id = spec[["measure_id"]], vat_rate = 0),
    vofi_row("price_building", typ_book(ctx$zeros(), p, -price * (1 - s) * a),
             section = "project", category = "capex", tax_category = "capex_depreciable",
             asset_id = ids$building, measure_id = spec[["measure_id"]], vat_rate = 0),
    meta = list(measure_id = spec[["measure_id"]])
  )
}

#' Prüfungen der Komponente land (Spec 01 Teil A 4.7)
#' @noRd
land_validate <- function(spec, scenario) {
  v <- typ_validator(spec, scenario, "measures")
  vd <- typ_valuation_date(scenario)
  d <- typ_spec_date(spec[["date"]])
  if (!is.null(vd) && !is.null(d) && d < vd) {
    v$add("error", "before_valuation", "date", date = d, value = d)
  }
  m <- spec[["measure_id"]]
  if (is.null(m)) v$add("error", "measure_missing")
  mt <- if (utl_is_string(m)) scenario[["measures"]][[m]][["measure_type"]] else NULL
  if (identical(mt, "erwerb_objekt")) {
    s <- typ_base_resolver(scenario)(path_join(v$coll, v$id, "land_share"))
    if (!is.null(s) && any(s %in% c(0, 1))) {
      v$add("warning", "land_share_extreme", "land_share", value = s[1L])
    }
  }
  pt <- scenario[["project"]][["project_type"]]
  if (utl_is_string(pt) && !(pt %in% c("erwerb_sanierung", "erwerb_neubau", "neubau"))) {
    v$add("warning", "type_project_mismatch", "measure_id", project_type = pt,
          measure_type = mt %||% "-", value = mt %||% "-")
  }
  v$out
}

#' @noRd
typedef_land <- function() {
  p <- vofi_param
  vofi_type(
    name = "land", kind = "flow",
    params = list(
      purchase_price_eur = p("amount", required = TRUE, min = 0, unit = "EUR"),
      land_share = p("share", default = 1),
      date = p("timing", required = TRUE),
      delay_months = p("number", default = 0, min = 0, unit = "months"),
      active = p("value", default = 1, min = 0, max = 1, shapes = "scalar"),
      land_asset_id = p("string"),
      building_asset_id = p("string")
    ),
    rows = c("price_land", "price_building"),
    validate = land_validate,
    build = land_build,
    example = list(type = "land", measure_id = "m1", purchase_price_eur = 1200000,
                   land_share = 0.25, date = "2027-04-01", delay_months = 1,
                   land_asset_id = "b1", building_asset_id = "b1")
  )
}
