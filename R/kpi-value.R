# Endwert-Kennzahlen (WS-D2, Spec 00 Abschnitte 12.2, 12.3).
# Phase-0-Minimalfassung, Eigentuemer: WS-D2: terminal_value (EW = BS_T), terminal_value_opp
# (EW_U) und delta_terminal_value (Primaerkennzahl, D9). NA-Code run_stopped bei Policy stop.
# Offen fuer WS-D2: terminal_value_real, npv_cf_project und die uebrigen Kennzahlen aus 12.3.

#' NA mit Code run_stopped für Läufe mit Policy stop (12.1)
#' @noRd
kpi_with_stopped <- function(values, core) {
  stopped <- core$flags$stopped %||% rep(FALSE, length(values))
  values[stopped] <- NA_real_
  vofi_kpi_value(values, na_reason = ifelse(stopped, "run_stopped", NA_character_))
}

#' @noRd
typedef_kpi_terminal_value <- function() {
  vofi_type(
    name = "terminal_value", kind = "kpi",
    compute = function(core, ctx) {
      kpi_with_stopped(core$stocks$BS[, core$grid$T + 1L], core)
    },
    unit = "EUR", shape = "scalar", rv_variant = TRUE, higher_is_better = TRUE, mc_default = TRUE
  )
}

#' @noRd
typedef_kpi_terminal_value_opp <- function() {
  vofi_type(
    name = "terminal_value_opp", kind = "kpi",
    compute = function(core, ctx) vofi_kpi_value(as.double(core$opp$EW)),
    unit = "EUR", shape = "scalar", rv_variant = FALSE, higher_is_better = TRUE,
    mc_default = TRUE, requires = "opportunity"
  )
}

#' @noRd
typedef_kpi_delta_terminal_value <- function() {
  vofi_type(
    name = "delta_terminal_value", kind = "kpi",
    compute = function(core, ctx) {
      kpi_with_stopped(core$stocks$BS[, core$grid$T + 1L] - as.double(core$opp$EW), core)
    },
    unit = "EUR", shape = "scalar", rv_variant = TRUE, higher_is_better = TRUE, mc_default = TRUE,
    requires = "opportunity"
  )
}
