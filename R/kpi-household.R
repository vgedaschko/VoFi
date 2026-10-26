# Haushaltskennzahlen (WS-D2, Spec 00 Abschnitte 12.2, 12.3, 12.6; Spec 01 Teil B 3.10.4).
# Eigentuemer: WS-D2. Selbstnutzer: monthly_burden (Reihe), monthly_burden_y1,
# monthly_burden_avg10, monthly_burden_construction ("Doppelbelastung" mit bisheriger Miete),
# burden_ratio_max (Belastungsquote). Kleinvermieter: monthly_net_cashflow (Reihe),
# monthly_net_cashflow_y1, monthly_net_cashflow_min. Alle Perspektiven: own_contribution
# (Eigenanteil nach Foerderung, R-83). Restriktion restriction_burden (R-74).

# ---------------------------------------------------------------------------------------------
# Monatliche Belastung (Selbstnutzer)
# ---------------------------------------------------------------------------------------------

#' Belastung je Periode: -Sum zahlungswirksame Zeilen mit `burden = TRUE` (7.6)
#' @noRd
kpi_burden <- function(core) -kpi_sum_keys(core, kpi_flag_keys(core, "burden"))

#' Monatswerte je Betriebsjahr einer Periodenmatrix (Summe / Monate)
#' @noRd
kpi_monthly_by_year <- function(m, oy) {
  y <- kpi_by_year(m, oy)
  if (length(oy$P) == 0L) return(y)
  y / matrix(oy$months, nrow(y), length(oy$P), byrow = TRUE)
}

#' Reihe aus Monatswerten je Betriebsjahr (ohne Betriebsjahr: `no_operation_period`)
#' @noRd
kpi_year_series <- function(core, vals, oy) {
  if (length(oy$P) == 0L) return(kpi_na_value(core, "series", "no_operation_period"))
  vofi_kpi_value(vals, years = oy$year)
}

#' Monatliche Belastung je Betriebsjahr (Reihe, EUR/Monat)
#' @noRd
kpi_calc_monthly_burden <- function(core, ctx) {
  oy <- kpi_op_years(core$grid)
  kpi_year_series(core, kpi_monthly_by_year(kpi_burden(core), oy), oy)
}

#' Mittel der ersten min(k, |P_voll|) vollen Betriebsjahre einer Reihe
#' @noRd
kpi_series_avg_full <- function(res, oy, n, k = 10L) {
  i <- which(oy$full)
  if (length(i) == 0L || length(oy$P) == 0L) {
    return(vofi_kpi_value(rep(NA_real_, n), na_reason = "no_operation_period"))
  }
  i <- i[seq_len(min(k, length(i)))]
  vofi_kpi_value(rowMeans(res$values[, i, drop = FALSE]), na_reason = res$na_reason)
}

#' @noRd
typedef_kpi_monthly_burden <- function() {
  kpi_typedef("monthly_burden", kpi_calc_monthly_burden, unit = "EUR_month", shape = "series",
              higher_is_better = FALSE, mc_default = TRUE, perspectives = "selbstnutzer")
}

#' @noRd
typedef_kpi_monthly_burden_y1 <- function() {
  kpi_typedef("monthly_burden_y1", function(core, ctx) {
    kpi_series_y1(kpi_calc_monthly_burden(core, ctx), kpi_op_years(core$grid), core$n)
  }, unit = "EUR_month", higher_is_better = FALSE, mc_default = TRUE,
  perspectives = "selbstnutzer")
}

#' @noRd
typedef_kpi_monthly_burden_avg10 <- function() {
  kpi_typedef("monthly_burden_avg10", function(core, ctx) {
    kpi_series_avg_full(kpi_calc_monthly_burden(core, ctx), kpi_op_years(core$grid), core$n)
  }, unit = "EUR_month", higher_is_better = FALSE, mc_default = TRUE,
  perspectives = "selbstnutzer")
}

#' Belastung in der Bauphase inkl. bisheriger Miete (12.3, Memo 07 Persona e)
#'
#' (-Summe der Belastungszeilen inkl. Bauzeitzinsen und Bereitstellungsprovision +
#' `household.current_rent_month_eur` x Monate) / Monate über die Perioden t >= 1 mit
#' `phase == "construction"`; ohne bisherige Miete zählt sie mit 0.
#' @noRd
kpi_calc_monthly_burden_construction <- function(core, ctx) {
  g <- core$grid
  cols <- which(g$phase == "construction" & g$t >= 1L)
  months <- sum(g$months[cols])
  n <- core$n
  if (length(cols) == 0L || months <= 0) {
    return(vofi_kpi_value(rep(NA_real_, n), na_reason = "no_construction_period"))
  }
  rent <- ctx$value("household.current_rent_month_eur", "scalar")
  rent <- if (is.null(rent)) rep(0, n) else rep_len(as.double(rent), n)
  b <- rowSums(kpi_burden(core)[, cols, drop = FALSE])
  vofi_kpi_value((b + rent * months) / months)
}

#' @noRd
typedef_kpi_monthly_burden_construction <- function() {
  kpi_typedef("monthly_burden_construction", kpi_calc_monthly_burden_construction,
              unit = "EUR_month", higher_is_better = FALSE, mc_default = TRUE,
              perspectives = "selbstnutzer")
}

#' Belastungsquote max_y monthly_burden_y / Einkommen_y (12.3)
#'
#' Einkommen_y = `household.net_income_month_eur` x Kalenderjahresindex von
#' `household.income_growth` in der ersten Periode des Betriebsjahres; Preisstand des
#' Einkommens ist das erste Kalenderjahr (Index 1 im Jahr des Stichtags).
#' @noRd
kpi_calc_burden_ratio_max <- function(core, ctx) {
  n <- core$n
  if (!identical(ctx$perspective, "selbstnutzer")) {
    return(vofi_kpi_value(rep(NA_real_, n), na_reason = "not_applicable_perspective"))
  }
  inc <- ctx$value("household.net_income_month_eur", "scalar")
  if (is.null(inc)) {
    return(vofi_kpi_value(rep(NA_real_, n), na_reason = "no_household_income"))
  }
  oy <- kpi_op_years(core$grid)
  if (length(oy$P) == 0L) {
    return(vofi_kpi_value(rep(NA_real_, n), na_reason = "no_operation_period"))
  }
  growth <- ctx$value("household.income_growth", "path")
  if (is.null(growth)) growth <- rep(0, n)
  base <- as.Date(paste0(utl_year(core$grid$valuation_date) + 1L, "-01-01"))
  idx <- ctx$index_year(growth, base_date = base)
  income <- rep_len(as.double(inc), n) * idx[, oy$first, drop = FALSE]
  burden <- kpi_monthly_by_year(kpi_burden(core), oy)
  r <- kpi_masked_ratio(burden, income)
  kpi_value_codes(kpi_row_max(r$ratio, r$mask), list(r$none, "no_household_income"))
}

#' @noRd
typedef_kpi_burden_ratio_max <- function() {
  kpi_typedef("burden_ratio_max", kpi_calc_burden_ratio_max, unit = "share",
              higher_is_better = FALSE, mc_default = TRUE, perspectives = "selbstnutzer",
              requires = "household_income")
}

#' @noRd
typedef_kpi_restriction_burden <- function() {
  kpi_typedef("restriction_burden", function(core, ctx) {
    r <- kpi_calc_burden_ratio_max(core, ctx)
    thr <- kpi_num_setting(ctx, "analysis.thresholds.burden_share", 0.40)
    vofi_kpi_value(as.double(r$values > thr), na_reason = r$na_reason)
  }, unit = "flag", higher_is_better = FALSE, mc_default = TRUE, restriction = "burden")
}

# ---------------------------------------------------------------------------------------------
# Monatlicher Cashflow (Kleinvermieter)
# ---------------------------------------------------------------------------------------------

#' Cashflow nach Kapitaldienst je Periode (12.3)
#'
#' Zahlungswirksame Zeilen der Abschnitte project und grants ohne `residual_value`/`sale_cost`
#' abzüglich planmäßigem Kapitaldienst KD und Gebühren FEES.
#' @noRd
kpi_net_cashflow <- function(core) {
  cf <- kpi_sum(core, section = c("project", "grants"), cash = TRUE) -
    kpi_sum(core, section = "project", category = c("residual_value", "sale_cost"))
  cf - kpi_kd(core) - kpi_fees(core)
}

#' @noRd
kpi_calc_monthly_net_cashflow <- function(core, ctx) {
  oy <- kpi_op_years(core$grid)
  kpi_year_series(core, kpi_monthly_by_year(kpi_net_cashflow(core), oy), oy)
}

#' @noRd
typedef_kpi_monthly_net_cashflow <- function() {
  kpi_typedef("monthly_net_cashflow", kpi_calc_monthly_net_cashflow, unit = "EUR_month",
              shape = "series", higher_is_better = TRUE, mc_default = TRUE,
              perspectives = "kleinvermieter")
}

#' @noRd
typedef_kpi_monthly_net_cashflow_y1 <- function() {
  kpi_typedef("monthly_net_cashflow_y1", function(core, ctx) {
    kpi_series_y1(kpi_calc_monthly_net_cashflow(core, ctx), kpi_op_years(core$grid), core$n)
  }, unit = "EUR_month", higher_is_better = TRUE, mc_default = TRUE,
  perspectives = "kleinvermieter")
}

#' @noRd
typedef_kpi_monthly_net_cashflow_min <- function() {
  kpi_typedef("monthly_net_cashflow_min", function(core, ctx) {
    res <- kpi_calc_monthly_net_cashflow(core, ctx)
    vofi_kpi_value(kpi_row_min(res$values), na_reason = res$na_reason)
  }, unit = "EUR_month", higher_is_better = TRUE, mc_default = TRUE,
  perspectives = "kleinvermieter")
}

# ---------------------------------------------------------------------------------------------
# Eigenanteil nach Förderung (R-83)
# ---------------------------------------------------------------------------------------------

#' Eigenanteil: -Sum (land, acquisition_cost, capex, relocation_cost, grant, tax_credit) -
#' Sum Auszahlungen neuer Kredite (nominal, ohne Ersatzinvestitionen)
#' @noRd
kpi_calc_own_contribution <- function(core, ctx) {
  inv <- kpi_sum(core, section = "project",
                 category = c("land", "acquisition_cost", "capex", "relocation_cost"),
                 cash = TRUE) +
    kpi_sum(core, section = "grants", category = c("grant", "tax_credit"), cash = TRUE)
  draws <- kpi_sum(core, section = "loans", category = "draw", existing_debt = FALSE)
  vofi_kpi_value(-rowSums(inv) - rowSums(draws))
}

#' @noRd
typedef_kpi_own_contribution <- function() {
  kpi_typedef("own_contribution", kpi_calc_own_contribution, unit = "EUR",
              higher_is_better = FALSE, mc_default = TRUE)
}
