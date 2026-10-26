# Zahlungstyp tenant_costs: Heiz- und Warmwasserkosten der Mieter (Warmmiete) als Merkzeilen
# (WS-E, Spec 00 Abschnitt 7.6, R-83; Spec 01 Teil B Abschnitt 3.8). Mieteranteil auf
# Vollvermietungsbasis aus den Energiesegmenten (ohne Eigentümeranteil), den Mieteranteilen der
# CO2-Kosten nach CO2KostAufG und dem Vorteil aus PV-Eigenverbrauch; dazu die kontrafaktische
# Merkzeile energy_pre (Vorzustand mit denselben Preis- und Mengenpfaden). Basis der Kennzahlen
# warm_rent und warm_rent_change_prepost und der warmmietenneutralen Umlage (rent_path).

#' Summe einer Hilfsgröße über Komponenten (Nullmatrix, wo sie fehlt)
#' @noRd
tc_sum <- function(ctx, ids, fun) {
  out <- ctx$zeros()
  for (id in rp_ids(ids)) {
    v <- fun(ctx$component(id))
    if (!is.null(v)) out <- out + v
  }
  out
}

#' @noRd
tc_build <- function(spec, ctx) {
  g <- ctx$grid
  set <- function(nm) ctx$setting(spec, nm)
  z <- function(x) x %||% ctx$zeros()
  share_tenant <- function(a) 1 - z(a$owner_share)
  r_s <- tc_sum(ctx, set("energy_components"), function(fl) {
    a <- fl$aux
    share_tenant(a) * (z(a$work_gross) + z(a$fees_gross))
  })
  r_c <- tc_sum(ctx, set("co2_components"), function(fl) {
    a <- fl$aux
    z(a$tenant_co2_gross) - z(a$tenant_network_reduction) - z(a$tenant_bio_reduction)
  })
  pv_id <- set("pv_component")
  b_pv <- ctx$zeros()
  if (!is.null(pv_id)) {
    a <- ctx$component(pv_id)$aux
    b_pv <- z(a$self_kwh_rented) * z(a$unit_price_self) - z(a$internal_charge)
  }
  energy <- pmax(r_s + r_c - b_pv, 0)
  area <- rep_len(ctx$param(spec, "rented_area_m2"), ctx$n)
  den <- matrix(area, ctx$n, g$T + 1L) * ctx$by_period(g$months)
  per_m2 <- function(x) {
    out <- x / pmax(den, 1e-300)
    out[den <= 0] <- 0
    out
  }
  rows <- list(vofi_row("energy", energy, section = "memo", category = "tenant_energy_cost"))
  aux <- list(energy_eur_m2_month = per_m2(energy))
  pre_e <- rp_ids(set("pre_energy_components"))
  if (length(pre_e) > 0L) {
    rs_cf <- tc_sum(ctx, pre_e, function(fl) {
      a <- fl$aux
      share_tenant(a) * (z(a$cf_work_gross) + z(a$cf_fees_gross))
    })
    rc_cf <- tc_sum(ctx, set("pre_co2_components"), function(fl) {
      a <- fl$aux
      z(a$cf_tenant_co2_gross) - z(a$cf_tenant_network_reduction) - z(a$cf_tenant_bio_reduction)
    })
    existing_pv <- is.null(rp_code(rp_raw(ctx, "energy.pv.measure")))
    b_cf <- if (existing_pv) b_pv else ctx$zeros()
    energy_pre <- pmax(rs_cf + rc_cf - b_cf, 0)
    rows[[2L]] <- vofi_row("energy_pre", energy_pre, section = "memo",
                           category = "tenant_energy_cost_pre")
    aux$energy_pre_eur_m2_month <- per_m2(energy_pre)
    aux$saving_eur_m2_month <- per_m2(energy_pre - energy)
  } else {
    aux$energy_pre_eur_m2_month <- ctx$zeros()
    aux$saving_eur_m2_month <- ctx$zeros()
  }
  relief <- tc_sum(ctx, set("co2_components"), function(fl) {
    out <- ctx$zeros()
    for (r in fl$rows) {
      if (r$key %in% c("co2_landlord", "network_fee_landlord", "bio_landlord")) {
        out <- out - r$values
      }
    }
    out
  })
  aux$co2_landlord_relief_eur_m2_month <- per_m2(relief)
  vofi_flows(rows, aux = aux)
}

#' @noRd
typedef_tenant_costs <- function() {
  p <- vofi_param
  vofi_type(
    name = "tenant_costs", kind = "flow",
    params = list(
      energy_components = p("ids", default = list()),
      co2_components = p("ids", default = list()),
      pv_component = p("ref"),
      pre_energy_components = p("ids", default = list()),
      pre_co2_components = p("ids", default = list()),
      rented_area_m2 = p("number", required = TRUE, min = 0, unit = "m2")
    ),
    rows = c("energy", "energy_pre"),
    grid_invariant = TRUE,
    domain_reads = c("energy", "unit_groups"),
    build = function(spec, ctx) tc_build(spec, ctx),
    example = list(
      type = "tenant_costs", rented_area_m2 = 1000, energy_components = list("e_before_gas_cost"),
      pre_energy_components = list("e_before_gas_cost"), after = list("e_before_gas_cost"),
      .deps = list(e_before_gas_cost = list(
        type = "energy_cost", state = "before", carrier = "gas", carrier_class = "gas",
        quantity_kwh_pa = list(expr = "150000"), price_eur_kwh = 0.0634,
        network_fee_eur_kwh = 0.0257, counterfactual_pre = TRUE, price_base_date = "2027-01-01"
      ))
    )
  )
}
