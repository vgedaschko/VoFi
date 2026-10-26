# Kredittyp bullet_loan: endfaelliges Darlehen (WS-F, Spec 00 Abschnitte 8.1-8.6).
# Phase-0-Minimalfassung, Eigentuemer: WS-F. Rechnet ueber den Kern inst_loan_* (Monatsuhr);
# Zinsen je Periode, Schlusstilgung des Restes bei Laufzeitende (8.5 (f)).

#' @noRd
typedef_bullet_loan <- function() {
  inst_loan_typedef("bullet_loan", "bullet",
                    example = list(type = "bullet_loan", amount_eur = 100000, rate_pa = 0.04,
                                   term_years = 5, payments_per_year = 1L,
                                   prepay_allowed = TRUE))
}
