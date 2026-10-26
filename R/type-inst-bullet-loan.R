# Kredittyp bullet_loan: endfaelliges Darlehen (WS-F; Spec 00 Abschnitte 8.1-8.7, 8.10;
# Spec 01 Teil A Abschnitt 5). Eigentuemer: WS-F. Rechnet ueber den gemeinsamen Kern inst_loan_*
# (R/type-inst-loan-core.R, Monatsuhr): Zinsen je Periode, keine Raten, Schlusstilgung des
# Restes bei Faelligkeit (Zeile repay_balloon, 8.5 (f)); eine Zinsanpassung aendert nur den
# Zins, refi_rule wird ignoriert.

#' Typdefinition bullet_loan (endfälliges Darlehen)
#'
#' Beispiel der Vertragstests: Zinsanpassung nach 2 Jahren mit Aufschlag, Disagio,
#' Bearbeitungsgebühr, regelbasierte Sondertilgung erlaubt.
#' @return `vofi_typedef`.
#' @noRd
typedef_bullet_loan <- function() {
  inst_loan_typedef(
    "bullet_loan", "bullet",
    example = list(
      type = "bullet_loan", amount_eur = 100000, rate_pa = 0.04, term_years = 5,
      payments_per_year = 1L, fixed_years = 2, followup_spread_pa = 0.005, payout_rate = 0.97,
      fees = list(processing_fee_share = 0.01), prepay_allowed = TRUE
    )
  )
}
