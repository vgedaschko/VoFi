# Zahlungstyp co2_cost: Aufteilung der CO2-Kosten eines Energiesegments nach dem CO2KostAufG
# (WS-E, Spec 01 Teil B Abschnitt 3.7). Stufenmodell (10 Stufen) über die spezifische Emission
# aller Segmente je Abrechnungsjahr (Kalenderjahr, Teiljahre hochgerechnet), ab 2028 § 5a für
# Heizungen nach § 43 GModG (50 % CO2-Kosten und Gasnetzentgelt,
# ab 2029 50 % der Bio-Mehrkosten bis 30 % Bioanteil), Kürzung nach § 9, Übergang bei Havarie,
# Härtefall § 5d, Neubau § 5b. Die Logik steht in R/rules-co2kostaufg.R; die Größen des Segments
# liest der Typ aus der Komponente energy_cost (aux). Ein inaktives Thema co2kostaufg ergibt
# keinen Vermieteranteil (Vermerk in meta$notes).

#' Summen je Abrechnungsjahr (Kalenderjahr des Periodenbeginns), in jede Periode des Jahres
#' zurückgeschrieben (n x (T+1); Spalte 1 = 0)
#' @noRd
co2_year_sum <- function(grid, x) {
  yr <- grid$year
  j <- seq_along(yr)
  s <- outer(yr, yr, "==") * outer(j >= 2L, j >= 2L, "&")
  x %*% s
}

#' Spezifische Emission (kg CO2/(m²·a)) je Abrechnungsjahr (Teil B 3.7.2)
#'
#' Das Stufenmodell gilt je Abrechnungszeitraum (Kalenderjahr): spez = Σ der co2_kg aller Segmente
#' in den Perioden des Jahres / (Fläche · Betriebsmonate des Jahres / 12). Betriebsmonate sind die
#' Monate, in denen ein Energiezustand gilt (`aux$operating` von energy_cost, ohne Angabe
#' delta); Teiljahre (Fertigstellung, Stichtag) werden so auf ein Jahr hochgerechnet. Das
#' Ergebnis gilt für alle Perioden des Jahres und hängt damit nicht vom Raster ab (F10). Perioden,
#' die ein Kalenderjahr überschreiten, bilden das Abrechnungsjahr ihres Beginns.
#' @param auxes Liste der Segment-Hilfsgrößen.
#' @param field `co2_kg` bzw. `cf_co2_kg`.
#' @param area n-Vektor der Bezugsfläche.
#' @param operating n x (T+1) Betriebsjahresanteil je Periode.
#' @noRd
co2_specific <- function(ctx, auxes, field, area, operating) {
  kg <- ctx$zeros()
  for (a in auxes) if (!is.null(a[[field]])) kg <- kg + a[[field]]
  den <- matrix(rep_len(area, ctx$n), ctx$n, ctx$grid$T + 1L) *
    co2_year_sum(ctx$grid, operating)
  out <- co2_year_sum(ctx$grid, kg) / pmax(den, 1e-300)
  out[den <= 0] <- 0
  out
}

#' Monatsanteil je Periode ab einem Termin (0 bei NA)
#' @noRd
co2_from_share <- function(ctx, d) {
  if (length(d) == 0L || is.na(d[1L])) return(ctx$zeros())
  ctx$by_period(ctx$overlap(d[1L], NULL))
}

#' @noRd
co2_build <- function(spec, ctx) {
  g <- ctx$grid
  n <- ctx$n
  set <- function(nm) ctx$setting(spec, nm)
  eid <- set("energy_component")
  e <- ctx$component(eid)$aux
  pc <- ctx$rule("co2_params")(ctx$legal("co2kostaufg"), ctx$legal("bio_treppe"))
  notes <- character(0)
  if (!isTRUE(pc$active_co2)) notes <- c(notes, "types.flow.co2_cost.msg.topic_inactive")
  area <- rep_len(ctx$param(spec, "living_area_m2"), n)
  all_ids <- unique(c(eid, rp_ids(set("all_energy_components"))))
  auxes <- lapply(all_ids, function(id) ctx$component(id)$aux)
  op <- e$operating %||% ctx$by_period(g$delta)
  spez <- co2_specific(ctx, auxes, "co2_kg", area, op)
  stage <- ctx$rule("co2_stage_share")(spez, pc)
  s43 <- isTRUE(set("section43"))
  nb5 <- isTRUE(set("newbuild_5b"))
  inst <- set("installation_date") %||% g$valuation_date
  d5 <- ctx$rule("co2_s5a_dates")(s43 || nb5, inst, isTRUE(set("emergency_replacement")),
                                  isTRUE(set("hardship_5d")), pc)
  a5 <- co2_from_share(ctx, d5$co2_from)
  a5n <- co2_from_share(ctx, d5$network_from)
  a5b <- co2_from_share(ctx, d5$bio_from)
  red <- rep_len(ctx$param(spec, "landlord_share_reduction") %||% 0, n)
  s5_co2 <- pc$s5a_co2_share %||% 0
  s5_net <- pc$s5a_network_share %||% 0
  s5_bio <- pc$s5a_bio_share %||% 0
  cap_bio <- pc$s5a_bio_cap %||% 0
  s <- (a5 * s5_co2 + (1 - a5) * stage) * (1 - red)
  o <- e$owner_share %||% ctx$zeros()
  vl <- !identical(set("vacancy_landlord"), FALSE)
  v <- (e$vacancy %||% ctx$zeros()) * vl
  occ <- (1 - o) * (1 - v)
  co2g <- e$co2_gross %||% ctx$zeros()
  netg <- e$network_gross %||% ctx$zeros()
  biog <- e$bio_gross %||% ctx$zeros()
  beta <- e$beta %||% ctx$zeros()
  is_gas <- identical(set("carrier_class"), "gas")
  bio_part <- ifelse(beta > 0, pmin(beta, cap_bio) / pmax(beta, 1e-300), 0)
  net_l <- if (is_gas) occ * a5n * s5_net * netg else ctx$zeros()
  bio_l <- occ * a5b * s5_bio * bio_part * biog
  selbst <- identical(ctx$perspective, "selbstnutzer")
  vr <- 0.19
  for (r in ctx$component(eid)$rows) if (identical(r$key, "work")) vr <- r$vat_rate
  rows <- list(
    vofi_row("co2_owner", -o * co2g, section = "project", category = "co2_cost",
             tax_category = if (selbst) "expense_nondeductible" else "expense_deductible",
             vat_rate = vr),
    vofi_row("co2_vacancy", -(1 - o) * v * co2g, section = "project", category = "co2_cost",
             vat_rate = vr),
    vofi_row("co2_landlord", -occ * s * co2g, section = "project", category = "co2_cost",
             vat_rate = vr),
    vofi_row("network_fee_landlord", -net_l, section = "project", category = "energy_cost",
             vat_rate = vr),
    vofi_row("bio_landlord", -bio_l, section = "project", category = "energy_cost",
             vat_rate = vr)
  )
  aux <- list(
    landlord_share = s, specific_kg_m2 = spez, stage_share = stage, s5a_active = a5,
    tenant_co2_gross = (1 - o) * (1 - s) * co2g,
    tenant_network_reduction = if (is_gas) (1 - o) * a5n * s5_net * netg else ctx$zeros(),
    tenant_bio_reduction = (1 - o) * a5b * s5_bio * bio_part * biog
  )
  if (!is.null(e$cf_co2_gross)) {
    pre_ids <- rp_ids(set("pre_energy_components"))
    pre_ids <- if (length(pre_ids) == 0L) eid else unique(c(eid, pre_ids))
    pre_aux <- lapply(pre_ids, function(id) ctx$component(id)$aux)
    spez_cf <- co2_specific(ctx, pre_aux, "cf_co2_kg", area, ctx$by_period(g$delta))
    s_cf <- (a5 * s5_co2 + (1 - a5) * ctx$rule("co2_stage_share")(spez_cf, pc)) * (1 - red)
    aux$cf_specific_kg_m2 <- spez_cf
    aux$cf_landlord_share <- s_cf
    aux$cf_tenant_co2_gross <- (1 - o) * (1 - s_cf) * e$cf_co2_gross
    aux$cf_tenant_network_reduction <- if (is_gas) {
      (1 - o) * a5n * s5_net * (e$cf_network_gross %||% ctx$zeros())
    } else {
      ctx$zeros()
    }
    aux$cf_tenant_bio_reduction <- (1 - o) * a5b * s5_bio * bio_part *
      (e$cf_bio_gross %||% ctx$zeros())
  }
  vofi_flows(rows, aux = aux,
             meta = list(notes = vapply(notes, function(k) lbl(k), ""), note_keys = notes))
}

#' @noRd
typedef_co2_cost <- function() {
  p <- vofi_param
  vofi_type(
    name = "co2_cost", kind = "flow",
    params = list(
      energy_component = p("ref", required = TRUE),
      all_energy_components = p("ids", default = list()),
      pre_energy_components = p("ids", default = list()),
      living_area_m2 = p("number", required = TRUE, min = 0, unit = "m2"),
      carrier_class = p("enum", values = "vocab:carrier_class", required = TRUE),
      section43 = p("logical", default = FALSE),
      emergency_replacement = p("logical", default = FALSE),
      newbuild_5b = p("logical", default = FALSE),
      hardship_5d = p("logical", default = FALSE),
      installation_date = p("date"),
      landlord_share_reduction = p("share", default = 0),
      vacancy_landlord = p("logical", default = TRUE)
    ),
    rows = c("co2_owner", "co2_vacancy", "co2_landlord", "network_fee_landlord",
             "bio_landlord"),
    grid_invariant = TRUE,
    domain_reads = "energy",
    build = function(spec, ctx) co2_build(spec, ctx),
    example = list(
      type = "co2_cost", energy_component = "e_before_gas_cost", living_area_m2 = 1000,
      carrier_class = "gas", section43 = TRUE, installation_date = "2027-10-01",
      .deps = list(e_before_gas_cost = list(
        type = "energy_cost", state = "before", carrier = "gas", carrier_class = "gas",
        quantity_kwh_pa = list(expr = "150000"), price_eur_kwh = 0.0634,
        network_fee_eur_kwh = 0.0257, emission_factor_kg_kwh = 0.182, co2_price_eur_t = 65,
        section43 = TRUE, owner_share = 0.2, price_base_date = "2027-01-01"
      ))
    )
  )
}
