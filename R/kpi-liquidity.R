# Liquiditaetskennzahlen (WS-D2, Spec 00 Abschnitte 12.2, 12.3).
# Eigentuemer: WS-D2. min_net_liquidity, max_overdraft, max_financing_need (mit und ohne
# Restwert), sum_equity_calls, pv_equity_calls, Markierungen flag_shortfall,
# flag_limit_breach, flag_reserve_used sowie die Restriktionen restriction_liquidity (R-101:
# ohne endliches Limit und ohne endliche Markierungsschwelle NA no_liquidity_limit) und
# restriction_savings (Nachschuss eines Betriebsjahres ueber der Sparfaehigkeit, R-74).

#' Nettoliquidität G_t - KK_t - KKP_t
#' @noRd
kpi_net_liquidity <- function(core) core$stocks$G - core$stocks$KK - core$stocks$KKP

#' Kumulierte Summe über die Spalten (Schleife über Perioden)
#' @noRd
kpi_cumsum_cols <- function(m) {
  out <- m
  if (ncol(m) > 1L) for (j in seq.int(2L, ncol(m))) out[, j] <- out[, j - 1L] + m[, j]
  out
}

#' @noRd
typedef_kpi_min_net_liquidity <- function() {
  kpi_typedef("min_net_liquidity", function(core, ctx) {
    vofi_kpi_value(kpi_row_min(kpi_net_liquidity(core)))
  }, unit = "EUR", rv_variant = TRUE, higher_is_better = TRUE, mc_default = TRUE)
}

#' @noRd
typedef_kpi_max_overdraft <- function() {
  kpi_typedef("max_overdraft", function(core, ctx) {
    vofi_kpi_value(kpi_row_max(core$stocks$KK + core$stocks$KKP))
  }, unit = "EUR", rv_variant = TRUE, higher_is_better = FALSE, mc_default = TRUE)
}

#' Maximaler Finanzierungsbedarf max_t (KK_t + KKP_t + Sum_{u <= t} NS_u)
#' @noRd
kpi_calc_max_financing_need <- function(core, ctx) {
  need <- core$stocks$KK + core$stocks$KKP + kpi_cumsum_cols(kpi_ns(core))
  vofi_kpi_value(kpi_row_max(need))
}

#' @noRd
typedef_kpi_max_financing_need <- function() {
  kpi_typedef("max_financing_need", kpi_calc_max_financing_need, unit = "EUR",
              rv_variant = TRUE, higher_is_better = FALSE, mc_default = TRUE)
}

#' @noRd
typedef_kpi_sum_equity_calls <- function() {
  kpi_typedef("sum_equity_calls", function(core, ctx) vofi_kpi_value(rowSums(kpi_ns(core))),
              unit = "EUR", higher_is_better = FALSE, mc_default = TRUE)
}

#' @noRd
typedef_kpi_pv_equity_calls <- function() {
  kpi_typedef("pv_equity_calls", function(core, ctx) {
    vofi_kpi_value(rowSums(kpi_ns(core) / kpi_q(core)))
  }, unit = "EUR", higher_is_better = FALSE, mc_default = FALSE)
}

#' @noRd
typedef_kpi_flag_shortfall <- function() {
  kpi_typedef("flag_shortfall",
              function(core, ctx) vofi_kpi_value(as.double(kpi_flag(core, "shortfall"))),
              unit = "flag", higher_is_better = FALSE, mc_default = TRUE)
}

#' @noRd
typedef_kpi_flag_limit_breach <- function() {
  kpi_typedef("flag_limit_breach",
              function(core, ctx) vofi_kpi_value(as.double(kpi_flag(core, "limit_breach"))),
              unit = "flag", higher_is_better = FALSE, mc_default = TRUE)
}

#' @noRd
typedef_kpi_flag_reserve_used <- function() {
  kpi_typedef("flag_reserve_used",
              function(core, ctx) vofi_kpi_value(as.double(kpi_flag(core, "reserve_used"))),
              unit = "flag", higher_is_better = FALSE, mc_default = TRUE)
}

#' Restriktion Liquidität (12.3, R-101)
#'
#' 1, wenn in einer Periode KKP > zero_abs (Limit überschritten), Policy `stop` ausgelöst oder
#' KK + KKP > `accounts.overdraft_flag_threshold_eur`; `NA` (`no_liquidity_limit`), wenn das
#' Limit in allen Perioden unendlich und die Markierungsschwelle unendlich ist.
#' @noRd
kpi_calc_restriction_liquidity <- function(core, ctx) {
  n <- core$n
  z <- vofi_tol$zero_abs
  kl <- core$limits$KL
  if (is.null(kl)) kl <- ctx$value("accounts.overdraft_limit_eur", "path")
  kl_finite <- if (is.null(kl)) rep(FALSE, n) else
    rowSums(is.finite(matrix(as.double(kl), nrow = n))) > 0
  thr <- ctx$value("accounts.overdraft_flag_threshold_eur", "scalar")
  thr <- if (is.null(thr)) rep(Inf, n) else rep_len(as.double(thr), n)
  kk <- core$stocks$KK
  kkp <- core$stocks$KKP
  viol <- rowSums(kkp > z) > 0 | kpi_flag(core, "stopped") | rowSums((kk + kkp) > thr) > 0
  kpi_value_codes(as.double(viol), list(!(kl_finite | is.finite(thr)), "no_liquidity_limit"))
}

#' @noRd
typedef_kpi_restriction_liquidity <- function() {
  kpi_typedef("restriction_liquidity", kpi_calc_restriction_liquidity, unit = "flag",
              higher_is_better = FALSE, mc_default = TRUE, restriction = "liquidity")
}

#' Restriktion Sparfähigkeit: Markierung `equity_call_over_savings` (9.8, 12.3)
#' @noRd
kpi_calc_restriction_savings <- function(core, ctx) {
  sav <- ctx$value("household.savings_capacity_month_eur", "scalar")
  if (is.null(sav)) {
    return(vofi_kpi_value(rep(NA_real_, core$n), na_reason = "no_household_income"))
  }
  vofi_kpi_value(as.double(kpi_flag(core, "equity_call_over_savings")))
}

#' @noRd
typedef_kpi_restriction_savings <- function() {
  kpi_typedef("restriction_savings", kpi_calc_restriction_savings, unit = "flag",
              higher_is_better = FALSE, mc_default = TRUE, restriction = "savings")
}
