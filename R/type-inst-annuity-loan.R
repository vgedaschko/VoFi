# Kredittyp annuity_loan: Annuitaetendarlehen (WS-F; Spec 00 Abschnitte 8.1-8.7, 8.10;
# Spec 01 Teil A Abschnitt 5). Eigentuemer: WS-F. Rechnet ueber den gemeinsamen Kern inst_loan_*
# (R/type-inst-loan-core.R, Monatsuhr): Rate aus Laufzeit (Annuitaetenformel) oder aus dem
# anfaenglichen Tilgungssatz (tau, zusammen mit term_years: Schlusstilgung bei Faelligkeit,
# R-100) bzw. vertragliche Rate installment_eur; Zinsanpassung nach keep_term, keep_tilg_rate
# (Default mit tau) oder keep_payment.

#' Typdefinition annuity_loan (Annuitätendarlehen)
#'
#' Beispiel der Vertragstests: Teilauszahlung (60 % / 40 %), ein tilgungsfreies Jahr,
#' Zinsbindung 3 Jahre mit Anschlusszins aus dem Marktpfad, Gebühren, Disagio,
#' Tilgungszuschuss mit `reduce_installment`, geplante und regelbasierte Sondertilgungen.
#' @return `vofi_typedef`.
#' @noRd
typedef_annuity_loan <- function() {
  inst_loan_typedef(
    "annuity_loan", "annuity",
    example = list(
      type = "annuity_loan", amount_eur = 100000, rate_pa = 0.036, term_years = 20,
      payments_per_year = 12L, grace_years = 1, fixed_years = 3, measure_id = "m1",
      draw_schedule = list(schedule = list("2027-01-01" = 0.6, "2027-07-01" = 0.4),
                           unit = "share"),
      payout_rate = 0.98,
      fees = list(processing_fee_share = 0.01, commitment_fee_rate_month = 0.0015,
                  commitment_free_months = 2L),
      repayment_grant = list(share = 0.1, date = "2028-01-01", effect = "reduce_installment"),
      planned_prepayments = list(schedule = list("2030-01-01" = 5000)),
      prepay_allowed = TRUE, prepay_cap_share_pa = 0.05
    )
  )
}
