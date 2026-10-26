# Kredittyp installment_loan: Ratentilgungsdarlehen (WS-F, Spec 00 Abschnitte 8.1-8.6).
# Phase-0-Minimalfassung, Eigentuemer: WS-F. Rechnet ueber den Kern inst_loan_* (Monatsuhr);
# konstante Tilgungsrate, Zinsanpassung mit keep_term (Test (h), 8.10).

#' @noRd
typedef_installment_loan <- function() {
  inst_loan_typedef("installment_loan", "installment",
                    example = list(type = "installment_loan", amount_eur = 120000,
                                   rate_pa = 0.02, term_years = 10, payments_per_year = 12L,
                                   fixed_years = 5, followup_rate_pa = 0.04, grace_years = 1,
                                   measure_id = "m1",
                                   repayment_grant = list(share = 0.1, year = 2028)))
}
