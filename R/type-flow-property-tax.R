# Zahlungstyp property_tax: Grundsteuer einer Wohnungsgruppe (WS-E, Spec 00 Abschnitt 7.11;
# Spec 01 Teil B Abschnitt 2.3). Kostenwirksam vor dem Bezug (Bauphase, Grundstück), bei
# Selbstnutzung und im Leerstandsanteil; der umgelegte Teil steht als Merkzeile der Mietersicht.
# Laufende Jahresbeträge mit dem Kalenderjahresindex (0.7, R-62); grid_invariant = TRUE.

#' @noRd
pt_build <- function(spec, ctx) {
  g <- ctx$grid
  n <- ctx$n
  mo <- rp_months(g)
  big_m <- mo$M
  par <- function(nm) ctx$param(spec, nm)
  amount <- rep_len(par("amount_eur_pa"), n)
  land <- rep_len(par("land_amount_eur_pa") %||% amount, n)
  after_amt <- par("amount_after_completion_eur_pa")
  growth <- ctx$param(spec, "growth", "path") %||% ctx$zeros()
  idx <- ctx$index_year(growth, oc_base_date(ctx, spec))
  occ <- ctx$timing(spec, "occupancy_from") %||% list(date = g$valuation_date, shift = rep(0, n))
  mi_occ <- rp_mi(g, occ$date) + rp_shift(rep_len(occ$shift, n))
  mm <- matrix(as.double(mo$m), n, big_m, byrow = TRUE)
  before <- (mm < matrix(mi_occ, n, big_m)) * 1
  a_m <- before * matrix(land, n, big_m) + (1 - before) * matrix(amount, n, big_m)
  if (!is.null(after_amt)) {
    ac <- ctx$timing(spec, "after_completion_from")
    mi_ac <- if (!is.null(ac)) {
      rp_mi(g, ac$date) + rp_shift(rep_len(ac$shift, n))
    } else {
      # Nachfeststellung zum 1. Januar nach der Fertigstellung (Fertigstellung des Rasters mit
      # laufspezifischem Bauzeitverzug project.construction_delay_months, Token completion),
      # unabhängig vom Bezug (Bestand mit Bauphase: Mieter bleiben, occupancy_from = Stichtag)
      delay <- rp_num(ctx, "project.construction_delay_months", rep(0, n))
      first <- rp_mi(g, g$completion_date) + rp_shift(rep_len(delay, n)) + 1
      moy <- (utl_month(g$valuation_date) - 1 + first - 1) %% 12 + 1
      first + (1 - moy) %% 12
    }
    after <- (mm >= matrix(mi_ac, n, big_m)) * 1
    a_m <- a_m * (1 - after) + after * matrix(rep_len(after_amt, n), n, big_m)
  }
  x_m <- a_m / 12 * rp_period_months(mo, idx)
  owner <- isTRUE(ctx$setting(spec, "owner_occupied"))
  rid <- ctx$setting(spec, "rent_component")
  x_before <- ctx$to_periods(x_m * before)
  x_after <- ctx$to_periods(x_m * (1 - before))
  if (owner) {
    cost <- x_before + x_after
  } else {
    vac <- if (is.null(rid)) ctx$zeros() else ctx$component(rid)$aux$vacant_share %||% ctx$zeros()
    cost <- x_before + vac * x_after
  }
  tc <- if (owner || identical(ctx$perspective, "selbstnutzer")) "expense_nondeductible" else
    "expense_deductible"
  rows <- list(vofi_row("cost", -cost, section = "project", category = "property_tax",
                        tax_category = tc, is_tax = "grundsteuer"))
  if (!owner) {
    rows[[2L]] <- vofi_row("tenant_share", x_after, section = "memo",
                           category = "tenant_operating_cost")
  }
  vofi_flows(rows)
}

#' @noRd
typedef_property_tax <- function() {
  p <- vofi_param
  vofi_type(
    name = "property_tax", kind = "flow",
    params = list(
      amount_eur_pa = p("amount", required = TRUE, min = 0, unit = "EUR"),
      land_amount_eur_pa = p("amount", min = 0, unit = "EUR"),
      amount_after_completion_eur_pa = p("amount", min = 0, unit = "EUR"),
      after_completion_from = p("timing"),
      growth = p("value", default = 0, unit = "rate_pa"),
      base_date = p("timing"),
      occupancy_from = p("timing", grid_default = "valuation_date"),
      owner_occupied = p("logical", default = FALSE),
      rent_component = p("ref")
    ),
    rows = c("cost", "tenant_share"),
    grid_invariant = TRUE,
    build = function(spec, ctx) pt_build(spec, ctx),
    example = list(type = "property_tax", amount_eur_pa = 6000, land_amount_eur_pa = 900,
                   growth = 0.02, base_date = "2027-01-01", occupancy_from = "2027-10-01",
                   owner_occupied = TRUE)
  )
}
