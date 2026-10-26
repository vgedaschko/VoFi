# Zahlungstyp operating_cost: Bewirtschaftungskosten einer Wohnungsgruppe (WS-E, Spec 01 Teil B
# Abschnitt 2.2). Verwaltung, nicht umlagefähige Betriebskosten, umlagefähige Betriebskosten im
# Leerstand (Vermieter) bzw. bei Selbstnutzung (Eigentümer) und die Mietersicht als Merkzeile.
# Laufende Jahresbeträge mit dem Kalenderjahresindex (0.7, R-62); grid_invariant = TRUE.

#' Liegt ein Parameter im Basisfall irgendwo ungleich 0? (deterministische Zeilenauswahl)
#' @noRd
oc_nonzero_base <- function(ctx, spec, name, shape = "scalar") {
  v <- ctx$param_base(spec, name, shape)
  !is.null(v) && any(abs(v) > 0)
}

#' Preisstand eines Typs: Parameter base_date bzw. 1. Januar nach project.price_base_year (R-35)
#' @noRd
oc_base_date <- function(ctx, spec, name = "base_date") {
  v <- ctx$setting(spec, name)
  if (!is.null(v)) return(v)
  pby <- mr_num(ctx$project[["price_base_year"]]) %||%
    (utl_year(ctx$grid$valuation_date) - 1L)
  as.Date(sprintf("%04d-01-01", as.integer(pby) + 1L))
}

#' @noRd
oc_build <- function(spec, ctx) {
  g <- ctx$grid
  n <- ctx$n
  par <- function(nm, shape = "scalar") ctx$param(spec, nm, shape)
  zero_path <- function(nm) par(nm, "path") %||% ctx$zeros()
  bd <- oc_base_date(ctx, spec)
  idx <- ctx$index_year(zero_path("growth"), bd)
  idx_o <- ctx$index_year(zero_path("opex_growth"), bd)
  st <- ctx$timing(spec, "start_event") %||% list(date = g$valuation_date, shift = rep(0, n))
  to <- ctx$timing(spec, "to")
  ov <- ctx$shift_overlap(st$date, st$shift, if (is.null(to)) NULL else to$date)
  dl <- ctx$by_period(g$delta)
  owner <- isTRUE(ctx$setting(spec, "owner_occupied"))
  rid <- ctx$setting(spec, "rent_component")
  vac <- ctx$zeros()
  soll <- ctx$zeros()
  if (!is.null(rid) && !owner) {
    rc <- ctx$component(rid)
    vac <- rc$aux$vacant_share %||% ctx$zeros()
    rows <- ctx$rows(id = rid, category = c("rent", "modernization_levy"))
    if (length(rows) > 0L) soll <- Reduce(`+`, rows)
  }
  # vacancy_opex_scope = warm wirkt in energy_cost (vacancy_landlord = FALSE, Teil B 3.5 Nr. 5)
  area <- rep_len(par("living_area_m2"), n)
  nu <- as.double(ctx$setting(spec, "n_units") %||% 1L)
  np <- as.double(ctx$setting(spec, "n_parking") %||% 0L)
  adm <- rep_len(par("admin_per_unit_eur_pa") %||% 0, n) * nu +
    rep_len(par("admin_per_parking_eur_pa") %||% 0, n) * np
  base_amt <- dl * ov
  nondeduct <- identical(ctx$setting(spec, "perspective_tax"), "nondeductible")
  tc <- if (nondeduct) "expense_nondeductible" else "expense_deductible"
  rows <- list(vofi_row("admin", -(adm * idx * base_amt), section = "project",
                        category = "operating_cost", tax_category = tc, vat_rate = 0))
  if (oc_nonzero_base(ctx, spec, "nonrecoverable_share_of_rent") ||
        oc_nonzero_base(ctx, spec, "nonrecoverable_eur_m2_pa")) {
    nr <- rep_len(par("nonrecoverable_share_of_rent") %||% 0, n) * soll +
      rep_len(par("nonrecoverable_eur_m2_pa") %||% 0, n) * area * idx_o * base_amt
    rows[[length(rows) + 1L]] <- vofi_row("nonrecoverable", -nr, section = "project",
                                          category = "operating_cost", tax_category = tc,
                                          vat_rate = 0.19)
  }
  opex <- rep_len(par("recoverable_opex_eur_m2_month") %||% 0, n) * 12 * area * idx_o * base_amt
  if (oc_nonzero_base(ctx, spec, "recoverable_opex_eur_m2_month")) {
    if (owner) {
      rows[[length(rows) + 1L]] <- vofi_row("owner_opex", -opex, section = "project",
                                            category = "operating_cost",
                                            tax_category = "expense_nondeductible",
                                            vat_rate = 0.19)
    } else {
      rows[[length(rows) + 1L]] <- vofi_row("vacancy_opex", -(opex * vac), section = "project",
                                            category = "operating_cost",
                                            tax_category = "expense_deductible",
                                            vat_rate = 0.19)
      rows[[length(rows) + 1L]] <- vofi_row("tenant_opex", opex, section = "memo",
                                            category = "tenant_operating_cost")
    }
  }
  vofi_flows(rows)
}

#' @noRd
typedef_operating_cost <- function() {
  p <- vofi_param
  vofi_type(
    name = "operating_cost", kind = "flow",
    params = list(
      n_units = p("integer", default = 1L, min = 0),
      living_area_m2 = p("number", required = TRUE, min = 0, unit = "m2"),
      admin_per_unit_eur_pa = p("amount", default = 0, min = 0, unit = "EUR"),
      admin_per_parking_eur_pa = p("amount", default = 0, min = 0, unit = "EUR"),
      n_parking = p("integer", default = 0L, min = 0),
      nonrecoverable_share_of_rent = p("share", default = 0),
      nonrecoverable_eur_m2_pa = p("amount", default = 0, min = 0, unit = "EUR"),
      recoverable_opex_eur_m2_month = p("amount", default = 0, min = 0, unit = "EUR"),
      vacancy_opex_scope = p("enum", values = "vocab:vacancy_opex_scope", default = "cold"),
      growth = p("value", default = 0, unit = "rate_pa"),
      opex_growth = p("value", default = 0, unit = "rate_pa"),
      base_date = p("timing"),
      start_event = p("timing", default = "completion"),
      to = p("timing", grid_default = "end_date"),
      owner_occupied = p("logical", default = FALSE),
      rent_component = p("ref"),
      perspective_tax = p("enum", values = "vocab:perspective_tax", default = "deductible")
    ),
    rows = c("admin", "nonrecoverable", "vacancy_opex", "owner_opex", "tenant_opex"),
    grid_invariant = TRUE,
    build = function(spec, ctx) oc_build(spec, ctx),
    example = list(type = "operating_cost", n_units = 24L, living_area_m2 = 1600,
                   admin_per_unit_eur_pa = 367, nonrecoverable_eur_m2_pa = 0.5,
                   recoverable_opex_eur_m2_month = 1.7, growth = 0.02, opex_growth = 0.025,
                   base_date = "2027-01-01", start_event = "2027-01-01", owner_occupied = TRUE)
  )
}
