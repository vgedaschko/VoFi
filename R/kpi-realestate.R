# Immobilienwirtschaftliche Kennzahlen (WS-D2, Spec 00 Abschnitte 12.2, 12.3, 12.6).
# Eigentuemer: WS-D2. DSCR ab dem Stabilisierungsjahr auf Objektebene (dscr_min, dscr_mean,
# dscr_years_below, inkl. Bestandsdarlehen) und Massnahmenebene (dscr_min_new, R-77), icr_min,
# ltv_max, ltv_end (Schulden / Marktwert V_t), lending_ratio_max (Beleihungsauslauf mit
# analysis.lending_value_haircut, R-72), Warmmiete je vermietetem m2 (warm_rent, warm_rent_y1)
# und Warmmietenaenderung "vorher/nachher" (warm_rent_change_prepost, _y1; R-83, R-101),
# co2_emissions (Treibhausgasbilanz aller Traeger), die Restriktionen restriction_dscr und
# restriction_warm_rent (R-74) sowie die Vergleichskennzahl co2_abatement_cost (12.6).

# ---------------------------------------------------------------------------------------------
# DSCR und ICR (12.3, R-46, R-77)
# ---------------------------------------------------------------------------------------------

#' Jahresgrößen der Betriebsjahre in P_stab
#' @return Liste `noi`, `kd`, `kd_ex`, `kd_new`, `int` (n x |P_stab|).
#' @noRd
kpi_dscr_years <- function(core, ctx) {
  oy <- kpi_op_years(core$grid)
  st <- kpi_stab_mask(oy, ctx)
  yr <- function(m) kpi_by_year(m, oy)[, st, drop = FALSE]
  list(noi = yr(kpi_noi(core)), kd = yr(kpi_kd(core)), kd_ex = yr(kpi_kd(core, TRUE)),
       kd_new = yr(kpi_kd(core, FALSE)), int = yr(kpi_int(core)))
}

#' Quotient je Jahr mit Maske (Nenner > zero_abs)
#' @return Liste `ratio` (n x k, außerhalb der Maske `NA`), `mask`, `none` (kein Jahr).
#' @noRd
kpi_masked_ratio <- function(num, den) {
  mask <- den > vofi_tol$zero_abs
  ratio <- num / ifelse(mask, den, 1)
  ratio[!mask] <- NA_real_
  list(ratio = ratio, mask = mask, none = rowSums(mask) == 0)
}

#' DSCR je Jahr auf Objektebene (NOI / KD)
#' @noRd
kpi_dscr_object <- function(core, ctx) {
  y <- kpi_dscr_years(core, ctx)
  kpi_masked_ratio(y$noi, y$kd)
}

#' @noRd
typedef_kpi_dscr_min <- function() {
  kpi_typedef("dscr_min", function(core, ctx) {
    r <- kpi_dscr_object(core, ctx)
    kpi_value_codes(kpi_row_min(r$ratio, r$mask), list(r$none, "no_debt_service"))
  }, unit = "ratio", higher_is_better = TRUE, mc_default = TRUE)
}

#' @noRd
typedef_kpi_dscr_mean <- function() {
  kpi_typedef("dscr_mean", function(core, ctx) {
    r <- kpi_dscr_object(core, ctx)
    s <- r$ratio
    s[!r$mask] <- 0
    kpi_value_codes(rowSums(s) / pmax(rowSums(r$mask), 1), list(r$none, "no_debt_service"))
  }, unit = "ratio", higher_is_better = TRUE, mc_default = FALSE)
}

#' Jahre mit DSCR unter der Schwelle `analysis.thresholds.dscr`
#' @noRd
kpi_dscr_below <- function(core, ctx) {
  r <- kpi_dscr_object(core, ctx)
  thr <- kpi_num_setting(ctx, "analysis.thresholds.dscr", 1.2)
  below <- r$mask & !is.na(r$ratio) & r$ratio < thr
  list(count = rowSums(below), none = r$none)
}

#' @noRd
typedef_kpi_dscr_years_below <- function() {
  kpi_typedef("dscr_years_below", function(core, ctx) {
    b <- kpi_dscr_below(core, ctx)
    kpi_value_codes(as.double(b$count), list(b$none, "no_debt_service"))
  }, unit = "years", higher_is_better = FALSE, mc_default = TRUE)
}

#' @noRd
typedef_kpi_dscr_min_new <- function() {
  kpi_typedef("dscr_min_new", function(core, ctx) {
    y <- kpi_dscr_years(core, ctx)
    r <- kpi_masked_ratio(y$noi - y$kd_ex, y$kd_new)
    kpi_value_codes(kpi_row_min(r$ratio, r$mask), list(r$none, "no_debt_service"))
  }, unit = "ratio", higher_is_better = TRUE, mc_default = FALSE)
}

#' @noRd
typedef_kpi_icr_min <- function() {
  kpi_typedef("icr_min", function(core, ctx) {
    y <- kpi_dscr_years(core, ctx)
    r <- kpi_masked_ratio(y$noi, y$int)
    kpi_value_codes(kpi_row_min(r$ratio, r$mask), list(r$none, "no_debt_service"))
  }, unit = "ratio", higher_is_better = TRUE, mc_default = FALSE)
}

#' @noRd
typedef_kpi_restriction_dscr <- function() {
  kpi_typedef("restriction_dscr", function(core, ctx) {
    b <- kpi_dscr_below(core, ctx)
    kpi_value_codes(as.double(b$count > 0), list(b$none, "no_debt_service"))
  }, unit = "flag", higher_is_better = FALSE, mc_default = TRUE, restriction = "dscr")
}

# ---------------------------------------------------------------------------------------------
# LTV und Beleihungsauslauf (12.3, R-72)
# ---------------------------------------------------------------------------------------------

#' LTV je Periode: (Sum_k B_k,t + KK_t + KKP_t) / V_t
#'
#' Bezug ist der Wertpfad V_t, nicht der Restwert (12.5; Vermerk `kpi.notes.value_path`). Der
#' Kontokorrentstand in T ist der der gewählten Sicht, d. h. in der Sicht mit Restwert nach dessen
#' Zufluss (wie Memo 01 §10, Orakel (c): LTV_T = 66,98 %).
#' @noRd
kpi_ltv_path <- function(core) {
  debt <- kpi_loan_balance(core) + core$stocks$KK + core$stocks$KKP
  kpi_masked_ratio(debt, kpi_market_value(core))
}

#' @noRd
typedef_kpi_ltv_max <- function() {
  kpi_typedef("ltv_max", function(core, ctx) {
    r <- kpi_ltv_path(core)
    kpi_value_codes(kpi_row_max(r$ratio, r$mask), list(r$none, "no_market_value"))
  }, unit = "share", higher_is_better = FALSE, mc_default = TRUE, requires = "market_value",
  rv_ref = "value_path")
}

#' @noRd
typedef_kpi_ltv_end <- function() {
  kpi_typedef("ltv_end", function(core, ctx) {
    r <- kpi_ltv_path(core)
    nt <- kpi_nt(core)
    kpi_value_codes(r$ratio[, nt], list(!r$mask[, nt], "no_market_value"))
  }, unit = "share", higher_is_better = FALSE, mc_default = FALSE, requires = "market_value",
  rv_ref = "value_path")
}

#' Beleihungsauslauf max_t Sum_k B_k,t / (V_t * (1 - Sicherheitsabschlag))
#' @noRd
kpi_calc_lending_ratio_max <- function(core, ctx) {
  hc <- kpi_num_setting(ctx, "analysis.lending_value_haircut", 0.10)
  r <- kpi_masked_ratio(kpi_loan_balance(core), kpi_market_value(core) * (1 - hc))
  kpi_value_codes(kpi_row_max(r$ratio, r$mask), list(r$none, "no_market_value"))
}

#' @noRd
typedef_kpi_lending_ratio_max <- function() {
  kpi_typedef("lending_ratio_max", kpi_calc_lending_ratio_max, unit = "share",
              higher_is_better = FALSE, mc_default = FALSE, requires = "market_value",
              rv_ref = "value_path")
}

# ---------------------------------------------------------------------------------------------
# Warmmiete (12.3, R-83, R-101)
# ---------------------------------------------------------------------------------------------

#' Vermietete Wohnfläche A_vm je Lauf (Gruppen ohne Selbstnutzung; ohne Gruppen: Gebäude)
#' @return n-Vektor (fehlende Angaben: 0).
#' @noRd
kpi_rented_area <- function(ctx, n) {
  val <- function(path) {
    v <- ctx$value(path, "scalar")
    if (is.null(v)) rep(0, n) else rep_len(as.double(v), n)
  }
  groups <- kpi_spec_get(ctx, "unit_groups") %||% list()
  if (length(groups) == 0L) return(val("building.living_area_m2"))
  area <- rep(0, n)
  for (id in names(groups)) {
    g <- groups[[id]]
    own <- isTRUE(as.logical(g[["owner_occupied"]])) ||
      identical(as.character(g[["rent_regime"]]), "owner_occupied")
    if (!own) area <- area + val(paste0("unit_groups.", id, ".living_area_m2"))
  }
  area
}

#' Größen der Mietersicht je Betriebsjahr
#' @return Liste `oy`, `rent`, `levy`, `energy`, `operating`, `pre` (n x |P|), `area`,
#'   `has_tenant`, `has_pre`.
#' @noRd
kpi_tenant_parts <- function(core, ctx) {
  oy <- kpi_op_years(core$grid)
  led <- core$ledger
  has <- function(...) !is.null(led) && length(ledger_select(led, ...)) > 0L
  yr <- function(...) kpi_by_year(kpi_sum(core, ...), oy)
  list(oy = oy,
       rent = yr(section = "project", category = "rent", cash = TRUE),
       levy = yr(section = "project", category = "modernization_levy", cash = TRUE),
       energy = yr(section = "memo", category = "tenant_energy_cost"),
       operating = yr(section = "memo", category = "tenant_operating_cost"),
       pre = yr(section = "memo", category = "tenant_energy_cost_pre"),
       area = kpi_rented_area(ctx, core$n),
       has_tenant = has(category = c("rent", "tenant_energy_cost", "tenant_operating_cost")),
       has_pre = has(section = "memo", category = "tenant_energy_cost_pre"))
}

#' Reihe je m² vermieteter Fläche und Monat mit NA-Codes der Mietersicht
#' @noRd
kpi_tenant_series <- function(core, p, num, has_data) {
  if (length(p$oy$P) == 0L) return(kpi_na_value(core, "series", "no_operation_period"))
  n <- core$n
  den <- outer(p$area, p$oy$months)
  ok_area <- p$area > vofi_tol$zero_abs
  vals <- num / ifelse(den > 0, den, 1)
  kpi_value_codes(vals, list(rep(!has_data, n), "no_tenant_data"),
                  list(!ok_area, "no_living_area"), years = p$oy$year)
}

#' Wert des ersten vollen Betriebsjahres einer Reihe (12.2)
#' @noRd
kpi_series_y1 <- function(res, oy, n) {
  i <- which(oy$full)
  if (length(i) == 0L || length(oy$P) == 0L) {
    return(vofi_kpi_value(rep(NA_real_, n), na_reason = "no_operation_period"))
  }
  vofi_kpi_value(res$values[, i[1L]], na_reason = res$na_reason)
}

#' Warmmiete je Betriebsjahr (rent + Umlage + Heiz- und Betriebskosten der Mieter) / (A_vm x Monate)
#' @noRd
kpi_calc_warm_rent <- function(core, ctx) {
  p <- kpi_tenant_parts(core, ctx)
  kpi_tenant_series(core, p, p$rent + p$levy + p$energy + p$operating, p$has_tenant)
}

#' Warmmietenänderung „vorher/nachher“ (Umlage + Heizkosten nachher - vorher, Mieteranteil)
#' @noRd
kpi_calc_warm_rent_change_prepost <- function(core, ctx) {
  p <- kpi_tenant_parts(core, ctx)
  kpi_tenant_series(core, p, p$levy + p$energy - p$pre, p$has_pre)
}

#' @noRd
typedef_kpi_warm_rent <- function() {
  kpi_typedef("warm_rent", kpi_calc_warm_rent, unit = "EUR_m2_month", shape = "series",
              higher_is_better = FALSE, mc_default = TRUE,
              requires = c("tenant_data", "living_area"), tenant_view = TRUE)
}

#' @noRd
typedef_kpi_warm_rent_y1 <- function() {
  kpi_typedef("warm_rent_y1", function(core, ctx) {
    kpi_series_y1(kpi_calc_warm_rent(core, ctx), kpi_op_years(core$grid), core$n)
  }, unit = "EUR_m2_month", higher_is_better = FALSE, mc_default = TRUE,
  requires = c("tenant_data", "living_area"), tenant_view = TRUE)
}

#' @noRd
typedef_kpi_warm_rent_change_prepost <- function() {
  kpi_typedef("warm_rent_change_prepost", kpi_calc_warm_rent_change_prepost,
              unit = "EUR_m2_month", shape = "series", higher_is_better = FALSE,
              mc_default = TRUE, requires = c("tenant_data", "living_area"), tenant_view = TRUE)
}

#' Warmmietenänderung „vorher/nachher“ im ersten vollen Betriebsjahr
#' @noRd
kpi_calc_warm_rent_change_prepost_y1 <- function(core, ctx) {
  kpi_series_y1(kpi_calc_warm_rent_change_prepost(core, ctx), kpi_op_years(core$grid), core$n)
}

#' @noRd
typedef_kpi_warm_rent_change_prepost_y1 <- function() {
  kpi_typedef("warm_rent_change_prepost_y1", kpi_calc_warm_rent_change_prepost_y1,
              unit = "EUR_m2_month", higher_is_better = FALSE, mc_default = TRUE,
              requires = c("tenant_data", "living_area"), tenant_view = TRUE)
}

#' Restriktion Warmmiete: Anstieg „vorher/nachher“ im ersten vollen Jahr über der Schwelle
#' @noRd
kpi_calc_restriction_warm_rent <- function(core, ctx) {
  if (!kpi_tenant_view(ctx)) {
    return(vofi_kpi_value(rep(NA_real_, core$n), na_reason = "not_applicable_perspective"))
  }
  y1 <- kpi_calc_warm_rent_change_prepost_y1(core, ctx)
  thr <- kpi_num_setting(ctx, "analysis.thresholds.warm_rent_increase_eur_m2", 0.50)
  vofi_kpi_value(as.double(y1$values > thr), na_reason = y1$na_reason)
}

#' @noRd
typedef_kpi_restriction_warm_rent <- function() {
  kpi_typedef("restriction_warm_rent", kpi_calc_restriction_warm_rent, unit = "flag",
              higher_is_better = FALSE, mc_default = TRUE, restriction = "warm_rent")
}

# ---------------------------------------------------------------------------------------------
# CO2 (12.3, 12.6, R-83, R-101)
# ---------------------------------------------------------------------------------------------

#' @noRd
typedef_kpi_co2_emissions <- function() {
  kpi_typedef("co2_emissions", function(core, ctx) {
    vofi_kpi_value(rowSums(kpi_sum(core, section = "memo", category = "co2_emission")))
  }, unit = "t_co2", higher_is_better = FALSE, mc_default = FALSE)
}

#' CO2-Vermeidungskosten -(delta_vs_reference / q_T) / co2_reduction (EUR/t, 12.6)
#' @param dvr,red `vofi_kpi_value` von `delta_vs_reference` bzw. `co2_reduction`.
#' @param q_T Aufzinsfaktor q_T je Lauf bzw. `NULL` (dann `not_computed`).
#' @noRd
kpi_co2_abatement_cost <- function(dvr, red, q_T) { # nolint: object_name_linter.
  n <- length(dvr$values)
  if (is.null(q_T)) return(vofi_kpi_value(rep(NA_real_, n), na_reason = "not_computed"))
  q_T <- rep_len(as.double(q_T), n) # nolint: object_name_linter.
  r <- red$values
  pos <- !is.na(r) & r > 0
  v <- -(dvr$values / q_T) / ifelse(pos, r, 1)
  kpi_value_codes(v, list(is.na(r), red$na_reason %||% "not_computed"),
                  list(!pos, "no_co2_reduction"),
                  list(is.na(dvr$values), dvr$na_reason %||% "not_computed"))
}
