# Rechtsregeln CO2KostAufG und Bio-Treppe (WS-E, Spec 00 Abschnitte 4.10, 5.3; Spec 01 Teil B
# Abschnitte 3.7.4, 5.3). Die Zahlen stammen aus den Nutzlasten der Themen `co2kostaufg` und
# `bio_treppe` (Teil C 3.5); die Abbildungsregel co2_params() bildet sie auf kurze Namen ab, deren
# Ergebnis PC als letztes Argument an die übrigen Regeln geht. Ein inaktives Thema (Nutzlast NULL)
# ergibt NULL-Felder: kein Vermieteranteil (Stufenmodell 0, kein § 5a) bzw. kein biogener Anteil.
# Alle Regeln sind vektorisiert, ziehen keine Zufallszahlen und lesen weder ctx noch die Bibliothek.

# nolint start: object_name_linter. P wie im Regelkatalog (Teil B 5.1)

#' Rechtsparameter des CO2KostAufG und der Bio-Treppe (Teil B 3.7.4, 5.3)
#'
#' @param lp_co2 `values` des Eintrags zum Thema `co2kostaufg` oder `NULL` (inaktiv).
#' @param lp_bio `values` des Eintrags zum Thema `bio_treppe` oder `NULL` (inaktiv).
#' @return benannte Liste PC; fehlt `lp_co2` bzw. dessen Teil `s5a`, sind `stage_*` bzw.
#'   `s5a_*` `NULL`; fehlt `lp_bio`, sind `bio_*` `NULL`.
#' @noRd
co2_params <- function(lp_co2, lp_bio) {
  sm <- mr_get(lp_co2, "stage_model")
  upper <- share <- NULL
  if (is.list(sm) && length(sm) > 0L) {
    upper <- vapply(sm, function(s) {
      u <- s[["upper_kg_m2a"]]
      if (is.null(u)) return(Inf)
      if (is.character(u) && tolower(u) %in% c(".inf", "inf")) return(Inf)
      as.double(u)
    }, double(1))
    share <- vapply(sm, function(s) as.double(s[["landlord_share"]] %||% 0), double(1))
    ord <- order(upper)
    upper <- upper[ord]
    share <- share[ord]
  } else if (is.data.frame(sm)) {
    upper <- as.double(sm$upper_kg_m2a)
    share <- as.double(sm$landlord_share)
  }
  s5a <- mr_get(lp_co2, "s5a")
  has_s5a <- is.list(s5a) && length(s5a) > 0L
  g5 <- function(p, fun = mr_num) if (has_s5a) fun(mr_get(s5a, p)) else NULL
  bio_years <- mr_num(mr_get(lp_bio, "min_bio_share.years"))
  bio_shares <- mr_num(mr_get(lp_bio, "min_bio_share.values"))
  if (!is.null(bio_years)) {
    ord <- order(bio_years)
    bio_years <- bio_years[ord]
    bio_shares <- bio_shares[ord]
  }
  list(
    active_co2 = !is.null(lp_co2),
    active_bio = !is.null(lp_bio),
    stage_upper = upper,
    stage_share = share,
    s5a_installed_after = g5("applies_to_installed_after", mr_date),
    s5a_co2_from = g5("co2_from", mr_date),
    s5a_co2_share = g5("co2_landlord_share"),
    s5a_network_from = g5("network_fee_from", mr_date),
    s5a_network_share = g5("network_fee_landlord_share"),
    s5a_bio_from = g5("bio_premium_from", mr_date),
    s5a_bio_share = g5("bio_premium_landlord_share"),
    s5a_bio_cap = g5("bio_premium_max_fuel_share"),
    s5a_breakdown_months = g5("transition.breakdown_install_months_before"),
    s5a_suspension_months = g5("transition.suspension_months"),
    s9_reduction_factor = mr_num(mr_get(lp_co2, "s9.reduction_factor")),
    bio_heating_classes = if (is.null(lp_bio)) NULL else
      mr_chr(mr_get(lp_bio, "applies_to.heating_types")),
    bio_installed_after = mr_date(mr_get(lp_bio, "applies_to.installed_after")),
    bio_building = if (is.null(lp_bio)) NULL else
      mr_chr(mr_get(lp_bio, "applies_to.building")),
    bio_years = bio_years,
    bio_shares = bio_shares
  )
}

#' Vermieteranteil nach dem Stufenmodell (Anlage CO2KostAufG; Teil B 3.7.4)
#'
#' Stufe mit `specific < stage_upper` (Untergrenze einschließlich, Obergrenze ausschließlich):
#' < 12 → 0; [12, 17) → 0,10; …; [47, 52) → 0,80; ≥ 52 → 0,95. Ohne Stufenmodell 0.
#' @param specific_kg_m2_pa spezifische Emission in kg CO2/(m²·a); Vektor oder Matrix.
#' @param PC Ausgabe von `co2_params()`.
#' @return Vermieteranteil in derselben Form wie `specific_kg_m2_pa`.
#' @noRd
co2_stage_share <- function(specific_kg_m2_pa, PC) {
  x <- specific_kg_m2_pa
  out <- x
  out[] <- 0
  up <- PC$stage_upper
  sh <- PC$stage_share
  if (is.null(up) || length(up) == 0L) return(out * 1)
  idx <- findInterval(as.double(x), up) + 1L
  idx <- pmin(idx, length(sh))
  out[] <- sh[idx]
  out[is.na(as.double(x))] <- 0
  out
}

#' Neue Heizung nach § 43 GModG (Bio-Treppe, § 5a, keine 15-%-Pauschale; Teil B 3.7.4)
#'
#' `TRUE`, wenn die Trägerklasse zu den Heizungsarten der Bio-Treppe gehört, der Einbau am oder nach
#' dem Stichtag der Regelung liegt und das Gebäude ein Bestandsgebäude ist. Ist das Thema
#' `bio_treppe` inaktiv, sind die `bio_*`-Parameter `NULL` und das Ergebnis `FALSE` (3.7.4).
#' @param carrier_class Code `carrier_class`.
#' @param installation_date Einbaudatum (Date).
#' @param existing_building Bestandsgebäude (lgl).
#' @param PC Ausgabe von `co2_params()`.
#' @return logischer Vektor.
#' @noRd
co2_section43 <- function(carrier_class, installation_date, existing_building, PC) {
  n <- mr_len(carrier_class, installation_date, existing_building)
  if (n == 0L) return(logical(0))
  classes <- PC$bio_heating_classes
  after <- PC$bio_installed_after
  if (is.null(after) || length(classes) == 0L) return(rep(FALSE, n))
  cls <- rep_len(as.character(carrier_class), n)
  d <- rep_len(as.Date(installation_date), n)
  ex <- rep_len(as.logical(existing_building), n)
  ex[is.na(ex)] <- FALSE
  building_ok <- if (length(PC$bio_building) == 0L || "existing" %in% PC$bio_building) ex else
    rep(TRUE, n)
  out <- cls %in% classes & !is.na(d) & d >= after & building_ok
  out[is.na(out)] <- FALSE
  out
}

#' Termine des § 5a CO2KostAufG (Vermieteranteil 50 % an CO2-Kosten, Gasnetzentgelt,
#' Bio-Mehrkosten; Teil B 3.7.4)
#'
#' `NA`, wenn weder § 43 noch § 5b gilt, bei Härtefall § 5d oder ohne `s5a`. Übergang bei Havarie
#' (3.7.4, 3.2.2): Liegt der Einbau wegen irreparablen Ausfalls im Fenster
#' [`s5a_co2_from` − `s5a_breakdown_months`, `s5a_co2_from`), verschiebt sich jeder Termin x mit
#' `installation_date >= x − s5a_breakdown_months` um `s5a_suspension_months` Monate („analog“ je
#' eigenem Termin); ein Einbau ab `s5a_co2_from` ist wirkungslos. Mit den Werten 2026 betrifft
#' das CO2-Kosten und Netzentgelt (2028 → 2029), nicht die Bio-Mehrkosten (ab 2029).
#' @param section43_or_5b § 43-Heizung oder Neubau nach § 5b (lgl).
#' @param installation_date Einbaudatum (Date).
#' @param emergency_replacement Einbau nach irreparablem Ausfall (lgl).
#' @param hardship_5d Härtefall § 5d (lgl).
#' @param PC Ausgabe von `co2_params()`.
#' @return Liste `co2_from`, `network_from`, `bio_from` (Date-Vektoren, `NA` = nicht anwendbar).
#' @noRd
co2_s5a_dates <- function(section43_or_5b, installation_date, emergency_replacement, hardship_5d,
                          PC) {
  n <- mr_len(section43_or_5b, installation_date, emergency_replacement, hardship_5d)
  na_dates <- rep(as.Date(NA), n)
  if (n == 0L || is.null(PC$s5a_co2_from)) {
    return(list(co2_from = na_dates, network_from = na_dates, bio_from = na_dates))
  }
  s43 <- rep_len(as.logical(section43_or_5b), n)
  s43[is.na(s43)] <- FALSE
  em <- rep_len(as.logical(emergency_replacement), n)
  em[is.na(em)] <- FALSE
  hs <- rep_len(as.logical(hardship_5d), n)
  hs[is.na(hs)] <- FALSE
  d <- rep_len(as.Date(installation_date), n)
  applies <- s43 & !hs
  bd <- PC$s5a_breakdown_months %||% 0
  sus <- PC$s5a_suspension_months %||% 0
  eligible <- em & !is.na(d) & d >= grid_add_months(PC$s5a_co2_from, -bd) &
    d < PC$s5a_co2_from
  mk <- function(base) {
    if (is.null(base)) return(na_dates)
    own <- eligible & d >= grid_add_months(base, -bd)
    out <- grid_add_months(rep(base, n), ifelse(own, sus, 0))
    out[!applies] <- NA
    out
  }
  list(co2_from = mk(PC$s5a_co2_from), network_from = mk(PC$s5a_network_from),
       bio_from = mk(PC$s5a_bio_from))
}

#' Mindestanteil biogener Brennstoffe nach § 43 GModG (Stufenfunktion; Teil B 3.7.4)
#'
#' Stufen gelten ab 1. Januar des genannten Jahres; vor der ersten Stufe 0; ohne Thema 0.
#' @param period_year Kalenderjahr je Periode; Vektor oder Matrix.
#' @param PC Ausgabe von `co2_params()`.
#' @return Anteil in derselben Form wie `period_year`.
#' @noRd
bio_share_section43 <- function(period_year, PC) {
  out <- period_year
  storage.mode(out) <- "double"
  out[] <- 0
  yrs <- PC$bio_years
  sh <- PC$bio_shares
  if (is.null(yrs) || length(yrs) == 0L) return(out)
  idx <- findInterval(as.double(period_year), yrs)
  vals <- c(0, sh)[idx + 1L]
  vals[is.na(vals)] <- 0
  out[] <- vals
  out
}

# ---------------------------------------------------------------------------------------------
# Typdefinitionen (Registry-Art rule; Teil B 5.1)
# ---------------------------------------------------------------------------------------------

#' Parametersatz für die Beispiele der Vertragstests (Werte nach legal/co2kostaufg_2026 und
#' legal/gmodg_bio_treppe_2026)
#' @noRd
co2_example_pc <- function() {
  co2_params(
    list(stage_model = lapply(seq_len(10L), function(i) {
      list(upper_kg_m2a = c(12, 17, 22, 27, 32, 37, 42, 47, 52, Inf)[i],
           landlord_share = c(0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.95)[i])
    }),
    s5a = list(applies_to_installed_after = "2026-07-29", co2_from = "2028-01-01",
               co2_landlord_share = 0.5, network_fee_from = "2028-01-01",
               network_fee_landlord_share = 0.5, bio_premium_from = "2029-01-01",
               bio_premium_landlord_share = 0.5, bio_premium_max_fuel_share = 0.3,
               transition = list(breakdown_install_months_before = 12, suspension_months = 12))),
    list(applies_to = list(heating_types = c("gas", "oil", "lpg"), installed_after = "2026-07-29",
                           building = "existing"),
         min_bio_share = list(years = c(2029, 2030, 2035, 2040),
                              values = c(0.10, 0.15, 0.30, 0.60)))
  )
}

#' @noRd
typedef_rule_co2_params_20230101 <- function() {
  vofi_type(
    name = "co2_params", kind = "rule", valid_from = "2023-01-01", returns = "params",
    source = "CO2KostAufG Anlage, \u00a7\u00a7 5a-5d, 9; GModG \u00a7 43 (Teil B 3.7.4)",
    fun = co2_params,
    example = list(lp_co2 = list(stage_model = list(list(upper_kg_m2a = 12, landlord_share = 0),
                                                    list(upper_kg_m2a = Inf,
                                                         landlord_share = 0.95))),
                   lp_bio = NULL)
  )
}

#' @noRd
typedef_rule_co2_stage_share_20230101 <- function() {
  vofi_type(
    name = "co2_stage_share", kind = "rule", valid_from = "2023-01-01", returns = "path",
    source = "CO2KostAufG Anlage zu \u00a7\u00a7 5-7 (Teil B 3.7.4)",
    fun = co2_stage_share,
    example = list(specific_kg_m2_pa = 27.3, PC = co2_example_pc())
  )
}

#' @noRd
typedef_rule_co2_section43_20260729 <- function() {
  vofi_type(
    name = "co2_section43", kind = "rule", valid_from = "2026-07-29", returns = "value",
    source = "GModG \u00a7 43 Abs. 1 (Teil B 3.7.4)",
    fun = co2_section43,
    example = list(carrier_class = "gas", installation_date = as.Date("2027-10-01"),
                   existing_building = TRUE, PC = co2_example_pc())
  )
}

#' @noRd
typedef_rule_co2_s5a_dates_20260729 <- function() {
  vofi_type(
    name = "co2_s5a_dates", kind = "rule", valid_from = "2026-07-29", returns = "params",
    source = "CO2KostAufG \u00a7 5a (Teil B 3.7.4)",
    fun = co2_s5a_dates,
    example = list(section43_or_5b = TRUE, installation_date = as.Date("2027-06-01"),
                   emergency_replacement = TRUE, hardship_5d = FALSE, PC = co2_example_pc())
  )
}

#' @noRd
typedef_rule_bio_share_section43_20260729 <- function() { # nolint: object_length_linter.
  vofi_type(
    name = "bio_share_section43", kind = "rule", valid_from = "2026-07-29", returns = "path",
    source = "GModG \u00a7 43 Abs. 1 (Teil B 3.7.4)",
    fun = bio_share_section43,
    example = list(period_year = 2035, PC = co2_example_pc())
  )
}

# nolint end
