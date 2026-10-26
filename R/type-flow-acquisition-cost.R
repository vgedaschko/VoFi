# Zahlungstyp acquisition_cost: Erwerbsnebenkosten (Grunderwerbsteuer ueber die Regel grest,
# Notar, Grundbuch, Makler, Sonstiges) mit Aufteilung Boden/Gebaeude (WS-E, Spec 01 Teil A 4.8,
# Spec 00 7.11). Die Bauleistung eines einheitlichen Vertragsgegenstands geht als Basisfallwert
# ein (Vertragspreis, Spec 00 6.3).

#' Nutzlast des Themas grunderwerbsteuer bzw. Rückfall bei ausdrücklichem Satz
#' @return Liste `P` oder `NULL` (Thema inaktiv ohne ausdrücklichen Satz).
#' @noRd
acq_grest_payload <- function(ctx, spec, has_rate) {
  p_legal <- ctx$legal("grunderwerbsteuer")
  if (!is.null(p_legal)) return(p_legal)
  if (!has_rate) return(NULL)
  # Thema inaktiv, ausdruecklicher Satz: gesetzliche Freigrenze (Vermerk in meta$notes)
  list(rates = list(), exemption_threshold_eur = rule_grest_threshold_default())
}

#' Zahlungskomponente acquisition_cost bauen (Spec 01 Teil A 4.8)
#' @noRd
acquisition_cost_build <- function(spec, ctx) {
  n <- ctx$n
  zero <- rep(0, n)
  id <- spec[["id"]] %||% "?"
  kp <- ctx$param(spec, "basis_eur")
  if (is.null(kp)) ctx$abort("types.flow.acquisition_cost.msg.no_basis", id = id)
  s <- ctx$param(spec, "land_share") %||% rep(1, n)
  a <- ctx$param(spec, "active") %||% rep(1, n)
  uniform <- isTRUE(ctx$setting(spec, "uniform_contract"))
  cb <- if (uniform) ctx$param_base(spec, "construction_basis_eur") %||% zero else zero
  rate <- ctx$param(spec, "grest_rate")
  fs <- ctx$setting(spec, "federal_state") %||% ctx$project$federal_state
  basis <- kp + cb
  threshold <- rule_grest_threshold_default()
  p_legal <- acq_grest_payload(ctx, spec, !is.null(rate))
  notes <- if (is.null(ctx$legal("grunderwerbsteuer")) && !is.null(rate)) {
    ctx$lbl("types.flow.acquisition_cost.msg.grest_topic_inactive", id = id,
            threshold = rule_grest_threshold_default())
  } else {
    character(0)
  }
  if (is.null(p_legal)) {
    if (any(basis > threshold)) {
      ctx$abort("types.flow.acquisition_cost.msg.grest_inactive", id = id)
    }
    grest <- zero
  } else {
    if (is.null(rate) && !utl_is_string(fs) &&
          any(basis > as.double(p_legal$exemption_threshold_eur %||% threshold))) {
      ctx$abort("types.flow.acquisition_cost.msg.federal_state_missing", id = id)
    }
    fs_code <- if (utl_is_string(fs)) fs else NA_character_
    grest <- ctx$rule("grest")(basis_eur = basis, federal_state = fs_code,
                               rate = rate %||% NA_real_, P = p_legal)
  }
  p <- typ_acq_period(ctx, spec, "acquisition_cost")
  ids <- typ_acq_asset_ids(ctx, spec)
  land_part <- typ_safe_div(kp * s, basis)
  rows <- list(
    vofi_row("grest_land", typ_book(ctx$zeros(), p, -grest * land_part * a),
             section = "project", category = "acquisition_cost",
             tax_category = "acquisition_ancillary", is_tax = "grunderwerbsteuer",
             asset_id = ids$land, measure_id = spec[["measure_id"]], vat_rate = 0),
    vofi_row("grest_building", typ_book(ctx$zeros(), p, -grest * (1 - land_part) * a),
             section = "project", category = "acquisition_cost",
             tax_category = "acquisition_ancillary", is_tax = "grunderwerbsteuer",
             asset_id = ids$building, measure_id = spec[["measure_id"]], vat_rate = 0)
  )
  items <- list(notary = c("notary_share", "notary_vat_rate"),
                registry = c("land_registry_share", NA_character_),
                broker = c("broker_share", "broker_vat_rate"),
                other = c("other_share", "other_vat_rate"))
  for (x in names(items)) {
    share <- ctx$param(spec, items[[x]][1L]) %||% zero
    vat <- if (is.na(items[[x]][2L])) 0 else typ_base_scalar(ctx, spec, items[[x]][2L], 0.19)
    for (part in c("land", "building")) {
      frac <- if (part == "land") s else 1 - s
      rows[[length(rows) + 1L]] <- vofi_row(
        paste0(x, "_", part), typ_book(ctx$zeros(), p, -share * kp * frac * a),
        section = "project", category = "acquisition_cost",
        tax_category = "acquisition_ancillary", asset_id = ids[[part]],
        measure_id = spec[["measure_id"]], vat_rate = vat
      )
    }
  }
  vofi_flows(rows, aux = list(grest_basis = ctx$by_sim(basis), grest_total = ctx$by_sim(grest)),
             meta = list(notes = notes))
}

#' Prüfungen der Komponente acquisition_cost (Spec 01 Teil A 4.8)
#'
#' Meldungen im Sondernamensraum `validation.acquisition.*`; der Termin vor dem Stichtag wie
#' bei `land` unter `validation.measures.before_valuation`.
#' @noRd
acquisition_cost_validate <- function(spec, scenario) {
  v <- typ_validator(spec, scenario, "acquisition")
  base <- typ_base_resolver(scenario)
  fs <- spec[["federal_state"]] %||% scenario[["project"]][["federal_state"]]
  has_rate <- !is.null(spec[["grest_rate"]])
  kp <- base(path_join(v$coll, v$id, "basis_eur"))
  cb <- if (isTRUE(spec[["uniform_contract"]])) {
    base(path_join(v$coll, v$id, "construction_basis_eur")) %||% 0
  } else {
    0
  }
  due <- is.null(kp) || any(kp + cb > rule_grest_threshold_default())
  if (due && !has_rate && !utl_is_string(fs)) {
    v$add("error", "federal_state_missing", "federal_state", measure = v$id)
  }
  legal <- scenario[["legal"]]
  if (due && !has_rate && is.null(legal[["grunderwerbsteuer"]])) {
    v$add("error", "grest_inactive", "grest_rate")
  }
  rate <- base(path_join(v$coll, v$id, "grest_rate"))
  rates <- legal[["grunderwerbsteuer"]][["values"]][["rates"]]
  if (!is.null(rate) && utl_is_string(fs) && !is.null(rates[[fs]]) &&
        abs(rate[1L] - as.double(rates[[fs]])) > 1e-12) {
    v$add("warning", "rate_deviates", "grest_rate", value = rate[1L],
          state_rate = as.double(rates[[fs]]))
  }
  if (isTRUE(spec[["uniform_contract"]]) && typ_is_zero_node(spec[["construction_basis_eur"]])) {
    v$add("warning", "uniform_without_construction", "uniform_contract")
  }
  vd <- typ_valuation_date(scenario)
  d <- typ_spec_date(spec[["date"]])
  if (!is.null(vd) && !is.null(d) && d < vd) {
    v$add("error", "measures.before_valuation", "date", date = d, value = d)
  }
  v$out
}

#' @noRd
typedef_acquisition_cost <- function() {
  p <- vofi_param
  vofi_type(
    name = "acquisition_cost", kind = "flow",
    params = list(
      basis_eur = p("amount", required = TRUE, min = 0, unit = "EUR"),
      land_share = p("share", default = 1),
      uniform_contract = p("logical", default = FALSE),
      construction_basis_eur = p("amount", default = 0, min = 0, unit = "EUR"),
      federal_state = p("enum", values = "vocab:federal_state"),
      grest_rate = p("rate", min = 0, max = 1),
      notary_share = p("share", default = 0.010),
      land_registry_share = p("share", default = 0.005),
      broker_share = p("share", default = 0),
      other_share = p("share", default = 0),
      notary_vat_rate = p("share", default = 0.19),
      broker_vat_rate = p("share", default = 0.19),
      other_vat_rate = p("share", default = 0.19),
      date = p("timing", required = TRUE),
      delay_months = p("number", default = 0, min = 0, unit = "months"),
      active = p("value", default = 1, min = 0, max = 1, shapes = "scalar"),
      land_asset_id = p("string"),
      building_asset_id = p("string")
    ),
    rows = c(paste0(c("grest", "notary", "registry", "broker", "other"), "_land"),
             paste0(c("grest", "notary", "registry", "broker", "other"), "_building")),
    validate = acquisition_cost_validate,
    build = acquisition_cost_build,
    example = list(type = "acquisition_cost", measure_id = "m1", basis_eur = 1200000,
                   land_share = 0.25, grest_rate = 0.035, broker_share = 0.0357,
                   uniform_contract = TRUE, construction_basis_eur = 300000,
                   date = "2027-04-01", land_asset_id = "b1", building_asset_id = "b1")
  )
}
