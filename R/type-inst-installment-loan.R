# Kredittyp installment_loan: Ratentilgungsdarlehen (WS-F; Spec 00 Abschnitte 8.1-8.7, 8.10;
# Spec 01 Teil A Abschnitt 5). Eigentuemer: WS-F. Rechnet ueber den gemeinsamen Kern inst_loan_*
# (R/type-inst-loan-core.R, Monatsuhr): konstante Tilgungsrate (Zusage / Zahl der Raten bzw.
# installment_eur), Zinsen getrennt auf den Monatsanfangsbestand; Zinsanpassung mit keep_term
# (Default; Test (h)) oder keep_payment, keep_tilg_rate ist unzulaessig.

#' Typdefinition installment_loan (Ratentilgungsdarlehen)
#'
#' Beispiel der Vertragstests: quartalsweise Tilgung, Zinsbindung 3 Jahre mit festem
#' Anschlusszins, Tilgungszuschuss als Betrag (`shorten_term`), geplante Sondertilgung.
#' @return `vofi_typedef`.
#' @noRd
typedef_installment_loan <- function() {
  inst_loan_typedef(
    "installment_loan", "installment",
    example = list(
      type = "installment_loan", amount_eur = 120000, rate_pa = 0.02, term_years = 10,
      payments_per_year = 4L, fixed_years = 3, followup_rate_pa = 0.04, measure_id = "m1",
      repayment_grant = list(amount_eur = 6000, year = 2029L),
      planned_prepayments = list(schedule = list("2029-01-01" = 2000)),
      prepay_allowed = TRUE
    )
  )
}
