# Rechtsregel grest: Grunderwerbsteuer (WS-E, Spec 00 5.3, 7.11; Spec 01 Teil A 4.8, 7; N-19).
# Regelkonvention: benannte, vektorisierte Formals ohne Defaults, kein Zugriff auf ctx oder globale
# Zustaende; die Nutzlast des Themas grunderwerbsteuer uebergibt der Typ acquisition_cost als P.

#' Freigrenze der Grunderwerbsteuer (§ 3 Nr. 1 GrEStG), Rückfall bei inaktivem Thema
#'
#' Wird nur verwendet, wenn das Thema `grunderwerbsteuer` inaktiv ist (kein freigegebener
#' Eintrag, Spec 00 4.10) und ein ausdrücklicher Satz `grest_rate` angegeben ist.
#' @noRd
rule_grest_threshold_default <- function() 2500

#' Grunderwerbsteuer je Lauf (Version ab 2025-07-01)
#'
#' Satz des Landes aus `P$rates` bzw. ausdrücklicher Satz `rate` (gewinnt, wenn nicht `NA`);
#' Freigrenze `P$exemption_threshold_eur`: Bemessungsgrundlage bis zur Freigrenze ergibt 0.
#' @param basis_eur n-Vektor: Gegenleistung (Kaufpreis + Bauleistung bei einheitlichem Vertrag).
#' @param federal_state Code des Landes (enum `federal_state`) oder `NA`.
#' @param rate n-Vektor bzw. Skalar: ausdrücklicher Satz oder `NA`.
#' @param P Nutzlast des Themas `grunderwerbsteuer` (`rates`, `exemption_threshold_eur`).
#' @return double n-Vektor (Steuer in EUR, >= 0).
#' @noRd
rule_grest_fun <- function(basis_eur, federal_state, rate, P) { # nolint: object_name_linter.
  basis_eur <- as.double(basis_eur)
  n <- length(basis_eur)
  rate <- rep_len(as.double(rate), n)
  state_rate <- NA_real_
  if (utl_is_string(federal_state) && !is.null(P$rates[[federal_state]])) {
    state_rate <- as.double(P$rates[[federal_state]])
  }
  used <- ifelse(is.na(rate), state_rate, rate)
  threshold <- as.double(P$exemption_threshold_eur %||% rule_grest_threshold_default())
  due <- basis_eur > threshold
  if (any(is.na(used) & due)) {
    vofi_abort("types.rule.grest.msg.rate_missing",
               state = if (utl_is_string(federal_state)) federal_state else "-",
               .class = "vofi_error_contract")
  }
  used[is.na(used)] <- 0
  used * basis_eur * due
}

#' @noRd
typedef_rule_grest_20250701 <- function() {
  vofi_type(
    name = "grest@2025-07-01", kind = "rule", rule_name = "grest",
    valid_from = as.Date("2025-07-01"), valid_to = NULL, reform = NULL,
    source = "GrEStG Par. 3, 8, 9, 11 i. V. m. Landesrecht (legal/grunderwerbsteuer_2026)",
    returns = "sim",
    fun = rule_grest_fun,
    example = list(basis_eur = 840000, federal_state = "NW", rate = NA_real_,
                   P = list(rates = list(NW = 0.065, BY = 0.035), exemption_threshold_eur = 2500))
  )
}
