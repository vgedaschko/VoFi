# Endwert-, Amortisations- und Barwertkennzahlen (WS-D2, Spec 00 Abschnitte 12.2, 12.3, 12.6).
# Eigentuemer: WS-D2. terminal_value (EW = BS_T), terminal_value_opp (EW_U),
# delta_terminal_value (Primaerkennzahl, D9), terminal_value_real (Deflation mit
# market.inflation), payback_time/payback_year (Vermoegensamortisation mit Restwertpfad W_t,
# ohne Restwert nur Guthaben und Schulden, R-72), npv_cf_project (Kapitalwert der Zahlungsfolge,
# "finanzierungsneutral, vereinfachte Annahmen"), pv_subsidies (Foerderbarwert, R-83) sowie die
# Vergleichskennzahl payback_vs_reference (12.6, 9.6 Nr. 9).

# ---------------------------------------------------------------------------------------------
# Endwert
# ---------------------------------------------------------------------------------------------

#' @noRd
typedef_kpi_terminal_value <- function() {
  kpi_typedef("terminal_value", function(core, ctx) vofi_kpi_value(kpi_ew(core)),
              unit = "EUR", rv_variant = TRUE, higher_is_better = TRUE, mc_default = TRUE,
              stopped = TRUE)
}

#' @noRd
typedef_kpi_terminal_value_opp <- function() {
  kpi_typedef("terminal_value_opp", function(core, ctx) vofi_kpi_value(kpi_ew_opp(core)),
              unit = "EUR", higher_is_better = TRUE, mc_default = TRUE, requires = "opportunity")
}

#' @noRd
typedef_kpi_delta_terminal_value <- function() {
  kpi_typedef("delta_terminal_value",
              function(core, ctx) vofi_kpi_value(kpi_ew(core) - kpi_ew_opp(core)),
              unit = "EUR", rv_variant = TRUE, higher_is_better = TRUE, mc_default = TRUE,
              requires = "opportunity", stopped = TRUE)
}

#' Realer Endwert EW / Prod_{u=1..T} (1 + pi_u)^Delta_u (12.3)
#' @noRd
kpi_calc_terminal_value_real <- function(core, ctx) {
  n <- core$n
  ew <- kpi_ew(core)
  infl <- ctx$value("market.inflation", "path")
  if (is.null(infl)) return(vofi_kpi_value(rep(NA_real_, n), na_reason = "no_inflation_path"))
  nt <- kpi_nt(core)
  if (nt < 2L) return(vofi_kpi_value(ew))
  g <- as.matrix(infl)[, seq.int(2L, nt), drop = FALSE]
  bad <- rowSums(!is.finite(g) | g <= -1) > 0
  g[bad, ] <- 0
  dmat <- matrix(core$grid$delta[seq.int(2L, nt)], n, nt - 1L, byrow = TRUE)
  defl <- exp(rowSums(log1p(g) * dmat))
  kpi_value_codes(ew / defl, list(bad, "no_inflation_path"))
}

#' @noRd
typedef_kpi_terminal_value_real <- function() {
  kpi_typedef("terminal_value_real", kpi_calc_terminal_value_real, unit = "EUR",
              rv_variant = TRUE, higher_is_better = TRUE, mc_default = FALSE, stopped = TRUE)
}

# ---------------------------------------------------------------------------------------------
# Amortisation (12.3, R-72)
# ---------------------------------------------------------------------------------------------

#' Spalte t* + 1 der dauerhaften Vermögensamortisation
#'
#' d_t = W_t - BS^U_t (Sicht mit Restwert, Restwertpfad 12.2) bzw. BS_t - BS^U_t (Sicht ohne
#' Restwert); t* = min{t : d_u >= -tol_u für alle u >= t}, tol_u = 1e-9 * max(1, |BS^U_u|).
#' @return integer n (Spaltenindex j = t* + 1) bzw. `NA`.
#' @noRd
kpi_payback_col <- function(core, ctx) {
  bsu <- core$opp$BS
  if (is.null(bsu)) bsu <- kpi_zeros(core)
  # ohne Restwertpfad ist W = BS + 0; der Vergleich unten ist davon unabhängig (Leistung 9.10:
  # keine Null- und Summenmatrix)
  no_rwp <- is.null(core$ledger) ||
    length(ledger_select(core$ledger, category = "residual_path",
                         rv_basis = kpi_rv_basis(ctx))) == 0L
  w <- if (identical(core$view, "ex_rv") || no_rwp) core$stocks$BS else kpi_wealth(core, ctx)
  d <- w - bsu
  kpi_first_permanent(d >= -1e-9 * pmax.int(1, abs(bsu)))
}

#' @noRd
typedef_kpi_payback_time <- function() {
  kpi_typedef("payback_time", function(core, ctx) {
    j <- kpi_payback_col(core, ctx)
    kpi_value_codes(core$grid$tau[j], list(is.na(j), "no_payback"))
  }, unit = "years", rv_variant = TRUE, higher_is_better = FALSE, mc_default = TRUE,
  requires = "opportunity", stopped = TRUE)
}

#' @noRd
typedef_kpi_payback_year <- function() {
  kpi_typedef("payback_year", function(core, ctx) {
    j <- kpi_payback_col(core, ctx)
    kpi_value_codes(as.double(core$grid$year[j]), list(is.na(j), "no_payback"))
  }, unit = "year", rv_variant = TRUE, higher_is_better = FALSE, mc_default = TRUE,
  requires = "opportunity", stopped = TRUE)
}

#' Amortisation gegenüber der Referenz (12.6, 9.6 Nr. 9)
#'
#' d_t = (W^A_t - BS^{U,A}_t) - (W^ref_t - BS^{U,ref}_t) auf den gemeinsamen Periodenenden
#' beider Raster; t* wie bei `payback_time`, Toleranz 1e-9 * max(1, |W^ref_t - BS^{U,ref}_t|,
#' |BS^{U,A}_t|). Für die Sicht ohne Restwert übergibt der Aufrufer BS statt W.
#' @param w_a,bsu_a,w_r,bsu_r n x (T+1) Pfade der Variante bzw. der Referenz.
#' @param grid_a,grid_r Raster der Variante bzw. der Referenz.
#' @return Liste `time` (Jahre seit Stichtag) und `year` (Kalenderjahr der Periode der Variante)
#'   als `vofi_kpi_value` (NA `no_payback`).
#' @noRd
kpi_payback_vs_reference <- function(w_a, bsu_a, w_r, bsu_r, grid_a, grid_r = grid_a) {
  common <- intersect(as.numeric(grid_a$date_end), as.numeric(grid_r$date_end))
  ia <- match(common, as.numeric(grid_a$date_end))
  ir <- match(common, as.numeric(grid_r$date_end))
  dr <- w_r[, ir, drop = FALSE] - bsu_r[, ir, drop = FALSE]
  d <- (w_a[, ia, drop = FALSE] - bsu_a[, ia, drop = FALSE]) - dr
  tol <- 1e-9 * pmax(1, abs(dr), abs(bsu_a[, ia, drop = FALSE]))
  k <- kpi_first_permanent(d >= -tol)
  j <- ia[k]
  list(time = kpi_value_codes(grid_a$tau[j], list(is.na(k), "no_payback")),
       year = kpi_value_codes(as.double(grid_a$year[j]), list(is.na(k), "no_payback")))
}

# ---------------------------------------------------------------------------------------------
# Barwerte (12.3)
# ---------------------------------------------------------------------------------------------

#' Zahlungsfolge cf_t des Projekts (zahlungswirksame Zeilen der Abschnitte project und grants)
#'
#' Enthält den Restwert und die Verkaufskosten in T; `npv_cf_project` und `irr_cf_project` haben
#' nach 12.3 keine Variante ohne Restwert und tragen in Ausgaben den Restwertbezug `"with"`.
#' @noRd
kpi_cf_project <- function(core) kpi_sum(core, section = c("project", "grants"), cash = TRUE)

#' @noRd
typedef_kpi_npv_cf_project <- function() {
  kpi_typedef("npv_cf_project", function(core, ctx) {
    vofi_kpi_value(rowSums(kpi_cf_project(core) / kpi_q(core)))
  }, unit = "EUR", higher_is_better = TRUE, mc_default = FALSE, rv_ref = "with")
}

#' Förderbarwert (Zuschüsse, laufende Zuschüsse, Steuerermäßigung, Tilgungszuschüsse; R-83)
#' @noRd
kpi_calc_pv_subsidies <- function(core, ctx) {
  s <- kpi_sum(core, section = "grants", category = c("grant", "operating_subsidy", "tax_credit")) +
    kpi_sum(core, section = "loans", category = "repayment_grant")
  vofi_kpi_value(rowSums(s / kpi_q(core)))
}

#' @noRd
typedef_kpi_pv_subsidies <- function() {
  kpi_typedef("pv_subsidies", kpi_calc_pv_subsidies, unit = "EUR", higher_is_better = TRUE,
              mc_default = FALSE)
}
