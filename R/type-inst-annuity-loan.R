# Kredittyp annuity_loan: Annuitaetendarlehen (WS-F, Spec 00 Abschnitte 8.1-8.6).
# Phase-0-Minimalfassung, Eigentuemer: WS-F. Rechnet ueber den Kern inst_loan_* (Monatsuhr);
# Rate mit Laufzeit (8.6) oder anfaenglichem Tilgungssatz, Zinsanpassung nach fixed_years.

#' @noRd
typedef_annuity_loan <- function() {
  inst_loan_typedef("annuity_loan", "annuity",
                    example = list(type = "annuity_loan", amount_eur = 100000, rate_pa = 0.036,
                                   term_years = 20, payments_per_year = 12L, fixed_years = 3,
                                   prepay_allowed = TRUE,
                                   fees = list(processing_fee_share = 0.01)))
}
