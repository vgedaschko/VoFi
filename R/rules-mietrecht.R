# Rechtsregeln Mietrecht (WS-E, Spec 00 Abschnitte 4.10, 5.3; Spec 01 Teil B Abschnitte 1.8-1.12,
# 5).
# Alle Regeln sind vektorisiert (Argumente werden auf die gemeinsame Länge recycelt), ziehen keine
# Zufallszahlen und lesen weder ctx noch die Bibliothek, auch nicht in Default-Werten ihrer
# Formals (5.3, R-93). Das letzte Formal P ist die Ausgabe der Abbildungsregel mr_params()
# (Nutzlast der Themen `mietrecht` und `mietrecht_559f`, Teil B 0.9, 5.2). Ein inaktives Thema
# (Nutzlast NULL) ergibt Parameter NULL; die Regeln wenden die zugehörige Rechtsfolge dann nicht an
# (keine Umlage, keine § 558-Erhöhung, keine Halbierung nach § 559f, keine Mietpreisbremse).

# nolint start: object_name_linter. P wie im Regelkatalog (Teil B 5.1)

# ---------------------------------------------------------------------------------------------
# Hilfsfunktionen (intern)
# ---------------------------------------------------------------------------------------------

#' Feld einer Nutzlast über einen Punktpfad lesen (`NULL`, wenn nicht vorhanden)
#' @noRd
mr_get <- function(x, path) {
  if (is.null(x)) return(NULL)
  path_get(x, path)
}

#' Datum aus einer Nutzlast (Date, ISO-Zeichenkette oder Jahr) bzw. `NULL`
#' @noRd
mr_date <- function(x) {
  if (is.null(x) || length(x) == 0L) return(NULL)
  if (inherits(x, "Date")) return(x[1L])
  if (is.numeric(x) && utl_is_whole(x[1L]) && x[1L] >= 1000) {
    return(as.Date(sprintf("%04d-01-01", as.integer(x[1L]))))
  }
  if (is.character(x)) {
    d <- as.Date(x[1L], optional = TRUE)
    if (!is.na(d)) return(d)
  }
  NULL
}

#' Zahl aus einer Nutzlast bzw. `NULL`
#' @noRd
mr_num <- function(x) {
  if (is.null(x) || length(x) == 0L) return(NULL)
  if (is.list(x) && identical(x[["kind"]], "const")) x <- x[["value"]]
  if (!is.numeric(x)) {
    v <- suppressWarnings(as.double(x))
    if (all(is.na(v))) return(NULL)
    return(v)
  }
  as.double(x)
}

#' Zeichenvektor aus einer Nutzlast (Liste oder Vektor) bzw. `character(0)`
#' @noRd
mr_chr <- function(x) {
  if (is.null(x)) return(character(0))
  as.character(unlist(x, use.names = FALSE))
}

#' Wahrheitswert aus einer Nutzlast bzw. `default`
#' @noRd
mr_lgl <- function(x, default = NULL) {
  if (is.null(x) || length(x) == 0L) return(default)
  if (is.logical(x)) return(isTRUE(x[1L]))
  if (is.character(x)) return(tolower(x[1L]) %in% c("true", "yes", "ja", "ge"))
  isTRUE(as.logical(x[1L]))
}

#' Argumente auf eine gemeinsame Länge bringen
#' @noRd
mr_len <- function(...) {
  lens <- vapply(list(...), length, integer(1))
  if (any(lens == 0L)) return(0L)
  max(lens)
}

# ---------------------------------------------------------------------------------------------
# mr_params: Abbildung der Nutzlast (Teil B 5.2)
# ---------------------------------------------------------------------------------------------

#' Rechtsparameter des Mietrechts aus den Nutzlasten der Themen `mietrecht` und
#' `mietrecht_559f` (Teil B 5.2)
#'
#' @param lp `values` des gewählten Eintrags zum Thema `mietrecht` (bei `mietrecht_ii` die mit
#'   der Reform gemischte Nutzlast) oder `NULL` (Thema inaktiv).
#' @param lp_559f `values` des Eintrags zum Thema `mietrecht_559f` oder `NULL` (inaktiv: keine
#'   Halbierung nach § 559f).
#' @return benannte Liste P mit kurzen Namen; `active` bzw. `active_559f` zeigen an, ob die Themen
#'   aktiv sind. Fehlende Felder sind `NULL`.
#' @noRd
mr_params <- function(lp, lp_559f) {
  num <- function(p) mr_num(mr_get(lp, p))
  times12 <- function(p) {
    v <- num(p)
    if (is.null(v)) NULL else v * 12
  }
  staffel_excl <- mr_chr(mr_get(lp, "s557a.excludes"))
  relet <- mr_chr(mr_get(lp, "s556e.relet_levy_procedures"))
  if (length(relet) == 0L && !is.null(lp)) {
    # Regelkonstante (§ 556e Abs. 2): §§ 559, 559c; mit Mietrecht II zusätzlich § 559e. Die
    # Reformnutzlast schließt § 559e während der Staffelmiete aus; daran wird sie erkannt.
    relet <- c("bgb_559", "bgb_559c", if ("bgb_559e" %in% staffel_excl) "bgb_559e")
  }
  damping <- mr_get(lp, "s557b.damping")
  if (!is.null(damping) && !is.list(damping)) damping <- NULL
  cmp <- mr_get(lp_559f, "comparison")
  list(
    active = !is.null(lp),
    active_559f = !is.null(lp_559f) && !is.null(mr_num(mr_get(lp_559f, "jaz_threshold"))),
    kappung_rate_default = num("s558.cap_share"),
    kappung_rate_15 = num("s558.cap_share_tight_market"),
    wait_months = num("s558.waiting_months"),
    kappung_window_months = num("s558.cap_window_months"),
    kuerzung_rate_grant = num("s558.funding_deduction_grant_share_pa"),
    kuerzung_grant_years = num("s558.funding_deduction_duration_grant_years"),
    kuerzung_loan_duration = mr_chr(mr_get(lp, "s558.funding_deduction_duration_loan")),
    rate_559 = num("s559.rate_pa"),
    cap_high = num("s559.cap_eur_m2_month"),
    cap_low = num("s559.cap_low_rent_eur_m2_month"),
    cap_low_threshold = num("s559.low_rent_threshold_eur_m2_month"),
    cap_heating = num("s559.heating_cap_eur_m2_month"),
    cap_window_months = times12("s559.cap_window_years"),
    levy_effective_delay_months = num("s559.effective_month_offset"),
    levy_delay_defective_months = num("s559.delay_if_defective_notice_months"),
    hardship_excluded_kinds = mr_chr(mr_get(lp, "s559.hardship_exclusion_not_for")),
    repayment_grant_as_grant = mr_lgl(mr_get(lp, "s559a.repayment_grant_as_grant"),
                                      default = !is.null(lp)),
    limit_559c_per_unit = num("s559c.cost_limit_per_unit_eur"),
    flat_559c = num("s559c.flat_maintenance_share"),
    lookback_559c_months = times12("s559c.lookback_years"),
    block_559c_months = times12("s559c.lock_years"),
    rate_559e = num("s559e.rate_pa"),
    flat_559e = num("s559e.flat_maintenance_share"),
    cap_559e = num("s559e.cap_eur_m2_month"),
    staffel_excludes = staffel_excl,
    index_excludes = mr_chr(mr_get(lp, "s557b.excludes")),
    index_559_only_if_not_attributable = mr_lgl(mr_get(lp, "s557b.s559_only_if_not_attributable"),
                                                default = TRUE),
    index_heating_1a_allowed = mr_lgl(mr_get(lp, "s557b.heating_1a_allowed"), default = TRUE),
    index_min_months = num("s557b.min_months_unchanged"),
    index_damping = damping,
    brake_cap_share = num("s556d.cap_share_over_ovm"),
    brake_until_default = mr_date(mr_get(lp, "s556d.ordinance_until")),
    brake_newbuild_after = mr_date(mr_get(lp, "s556d.newbuild_first_use_after")),
    brake_comprehensive_exempt = mr_lgl(
      mr_get(lp, "s556d.first_letting_after_comprehensive_modernisation_exempt"), default = TRUE
    ),
    minderung_exclusion_months = num("s536_1a.exclusion_months"),
    minderung_exclusion_kinds = mr_chr(mr_get(lp, "s536_1a.scope")),
    attribution = mr_chr(mr_get(lp, "interpretation.third_party_allocation")),
    flat_559e_order = mr_chr(mr_get(lp, "interpretation.s559e_order")),
    hp_order = mr_chr(mr_get(lp, "interpretation.s559f_order")),
    section43_flat = mr_lgl(mr_get(lp, "interpretation.s559e_flat_for_section43"), default = NULL),
    mpb_modernization_months = if (is.null(lp)) NULL else 36,
    relet_levy_procedures = relet,
    hp_jaz_threshold = mr_num(mr_get(lp_559f, "jaz_threshold")),
    hp_inclusive = if (is.null(cmp)) NULL else identical(as.character(cmp)[1L], "ge"),
    hp_factor = mr_num(mr_get(lp_559f, "reduction_factor")),
    hp_exc_year = mr_num(mr_get(lp_559f, "exceptions.construction_year_after")),
    hp_exc_flow = mr_num(mr_get(lp_559f, "exceptions.flow_temperature_max_c"))
  )
}

# ---------------------------------------------------------------------------------------------
# Regeln (Teil B 5.1, 5.2)
# ---------------------------------------------------------------------------------------------

#' Zulässigkeit einer Modernisierungsumlage je Phase und Verfahren (Teil B 5.2, N-06, N-19)
#'
#' `bgb_559c` zählt für die Ausschlussprüfung als `bgb_559` (Berechnungsverfahren der Erhöhung
#' nach § 559).
#' @param kind Code `modernization_kind`.
#' @param rent_regime Code `rent_regime`.
#' @param phase Code `rent_phase` (`p558`, `staffel`, `index`, `bound`).
#' @param landlord_responsible vom Vermieter zu vertreten (lgl).
#' @param procedure `bgb_559`, `bgb_559c` oder `bgb_559e` (`auto` ist aufgelöst).
#' @param P Ausgabe von `mr_params()`.
#' @return logischer Vektor.
#' @noRd
mr_levy_allowed <- function(kind, rent_regime, phase, landlord_responsible, procedure, P) {
  n <- mr_len(kind, rent_regime, phase, landlord_responsible, procedure)
  if (n == 0L) return(logical(0))
  kind <- rep_len(as.character(kind), n)
  rent_regime <- rep_len(as.character(rent_regime), n)
  phase <- rep_len(as.character(phase), n)
  lr <- rep_len(as.logical(landlord_responsible), n)
  lr[is.na(lr)] <- TRUE
  procedure <- rep_len(as.character(procedure), n)
  if (!isTRUE(P$active)) return(rep(FALSE, n))
  p_star <- ifelse(procedure == "bgb_559c", "bgb_559", procedure)
  ok <- !(kind %in% c("none", "bgb_555b_2", "bgb_555b_7")) & rent_regime != "owner_occupied" &
    procedure %in% c("bgb_559", "bgb_559c", "bgb_559e") & !is.na(kind)
  ok <- ok & !(procedure == "bgb_559e" & kind != "bgb_555b_1a")
  ph_ok <- rep(FALSE, n)
  ph_ok[phase == "p558"] <- TRUE
  st <- phase == "staffel"
  ph_ok[st] <- !(p_star[st] %in% P$staffel_excludes)
  ix <- phase == "index"
  if (any(ix)) {
    only_na <- isTRUE(P$index_559_only_if_not_attributable)
    heat_1a <- isTRUE(P$index_heating_1a_allowed)
    ph_ok[ix] <- !(p_star[ix] %in% P$index_excludes) &
      ((kind[ix] == "bgb_555b_1a" & heat_1a) | !lr[ix] | !only_na)
  }
  ok & ph_ok
}

#' Zielmiete einer Erhöhung nach § 558 (Teil B 1.8.2 (f))
#'
#' Zielwert = min(OVM, Kappungsgrenze) − Kürzungsbetrag, höchstens die freiwillige Obergrenze;
#' die Kappungsgrenze ist Basismiete vor 36 Monaten × (1 + k) + Erhöhungen nach §§ 559 ff. im
#' Kappungsfenster; `cap_share = Inf` bedeutet keine Kappung (erste Erhöhung nach Bindungsende).
#' @param ovm ortsübliche Vergleichsmiete (EUR/m²·Monat).
#' @param base_36m Miete 36 Monate zuvor.
#' @param increases_36m Summe der Umlagen im Kappungsfenster.
#' @param kuerzung Kürzungsbetrag nach § 558 Abs. 5.
#' @param cap_share Kappungsgrenze k.
#' @param voluntary_cap freiwillige Obergrenze (Inf = keine).
#' @return numerischer Vektor (EUR/m²·Monat).
#' @noRd
mr_558_target <- function(ovm, base_36m, increases_36m, kuerzung, cap_share, voluntary_cap) {
  n <- mr_len(ovm, base_36m, increases_36m, kuerzung, cap_share, voluntary_cap)
  if (n == 0L) return(numeric(0))
  r <- function(x) rep_len(as.double(x), n)
  cs <- r(cap_share)
  cap <- r(base_36m) * (1 + ifelse(is.finite(cs), cs, 0)) + r(increases_36m)
  cap[!is.finite(cs)] <- Inf
  tgt <- pmin(r(ovm), cap) - r(kuerzung)
  pmin(tgt, r(voluntary_cap))
}

#' Jahresbetrag der Modernisierungsumlage vor Kappungen (Teil B 1.9.3)
#'
#' @param procedure `bgb_559`, `bgb_559c` oder `bgb_559e` (je Lauf).
#' @param cost aufgewendete Kosten K (EUR).
#' @param maintenance Erhaltungsanteil IH (EUR).
#' @param grants Zuschüsse G (EUR).
#' @param repayment_grants Tilgungszuschüsse TZ (EUR).
#' @param interest_reduction Jahresbetrag der Zinsermäßigung Zint (EUR/a).
#' @param attribution `full` oder `proportional` (Zurechnung der Drittmittel).
#' @param hp_halving 1 = Halbierung nach § 559f, 0 = keine.
#' @param hp_order `halve_then_funds` oder `funds_then_halve`.
#' @param flat_order `flat_before_funds` oder `funds_before_flat` (§ 559e).
#' @param section43 Heizung nach § 43 GModG ohne 15-%-Pauschale (lgl).
#' @param interest_in_559e Zinsermäßigung mindert auch die § 559e-Umlage (lgl).
#' @param P Ausgabe von `mr_params()`.
#' @return numerischer Vektor (EUR/a, für die gesamte Maßnahme vor Kostenverteilung).
#' @noRd
mr_levy_annual <- function(procedure, cost, maintenance, grants, repayment_grants,
                           interest_reduction, attribution, hp_halving, hp_order, flat_order,
                           section43, interest_in_559e, P) {
  n <- mr_len(procedure, cost, maintenance, grants, repayment_grants, interest_reduction,
              attribution, hp_halving, hp_order, flat_order, section43, interest_in_559e)
  if (n == 0L) return(numeric(0))
  if (!isTRUE(P$active)) return(rep(0, n))
  r <- function(x) rep_len(as.double(x), n)
  proc <- rep_len(as.character(procedure), n)
  k <- r(cost)
  ih <- r(maintenance)
  g <- r(grants)
  tz <- r(repayment_grants)
  zint <- r(interest_reduction)
  attr_prop <- rep_len(as.character(attribution), n) == "proportional"
  hv <- r(hp_halving) > 0.5
  halve_first <- rep_len(as.character(hp_order), n) != "funds_then_halve"
  flat_first <- rep_len(as.character(flat_order), n) != "funds_before_flat"
  s43 <- rep_len(as.logical(section43), n)
  s43[is.na(s43)] <- FALSE
  z559e <- rep_len(as.logical(interest_in_559e), n)
  z559e[is.na(z559e)] <- TRUE
  hf <- P$hp_factor %||% 0.5
  phi <- ifelse(attr_prop, ifelse(k > 0, (k - ih) / pmax(k, 1e-300), 0), 1)
  d <- phi * (g + tz)
  z <- phi * zint
  rate_559 <- P$rate_559 %||% 0
  rate_559e <- P$rate_559e %||% 0
  flat_559c <- P$flat_559c %||% 0
  flat_559e <- P$flat_559e %||% 0
  out <- rep(0, n)
  # § 559
  b559 <- ifelse(hv & halve_first, hf * (k - ih) - d,
                 ifelse(hv & !halve_first, hf * (k - ih - d), k - ih - d))
  u559 <- pmax(0, rate_559 * b559 - z)
  # § 559c (Zinsermäßigung nicht anwendbar)
  phic <- ifelse(attr_prop, 1 - flat_559c, 1)
  u559c <- pmax(0, rate_559 * ((1 - flat_559c) * k - phic * (g + tz)))
  # § 559e
  f <- ifelse(s43, 0, flat_559e)
  ih43 <- ifelse(s43, ih, 0)
  kk <- ifelse(hv & halve_first, hf * k, k)
  ih43 <- ifelse(hv & halve_first, hf * ih43, ih43)
  b559e <- ifelse(flat_first, (1 - f) * kk - ih43 - d, (1 - f) * (kk - d) - ih43)
  b559e <- ifelse(hv & !halve_first, hf * b559e, b559e)
  u559e <- pmax(0, rate_559e * b559e - ifelse(z559e, z, 0))
  out[proc == "bgb_559"] <- u559[proc == "bgb_559"]
  out[proc == "bgb_559c"] <- u559c[proc == "bgb_559c"]
  out[proc == "bgb_559e"] <- u559e[proc == "bgb_559e"]
  out
}

#' Restraum der Gesamtkappe nach § 559 Abs. 3a (Teil B 1.9.5)
#'
#' @param rent_before Miete vor der Erhöhung inkl. früherer Umlagen (EUR/m²·Monat).
#' @param prior_6y Summe der Umlagen der letzten sechs Jahre (EUR/m²·Monat).
#' @param P Ausgabe von `mr_params()`.
#' @return numerischer Vektor (EUR/m²·Monat, ≥ 0).
#' @noRd
mr_levy_cap_total <- function(rent_before, prior_6y, P) {
  n <- mr_len(rent_before, prior_6y)
  if (n == 0L) return(numeric(0))
  if (!isTRUE(P$active) || is.null(P$cap_high)) return(rep(Inf, n))
  rb <- rep_len(as.double(rent_before), n)
  low <- P$cap_low %||% P$cap_high
  thr <- P$cap_low_threshold %||% -Inf
  pmax(ifelse(rb < thr, low, P$cap_high) - rep_len(as.double(prior_6y), n), 0)
}

#' Restraum der Heizungskappe (§ 559 Abs. 3a S. 3, § 559e; Teil B 1.9.5)
#'
#' @param prior_heat_6y Summe der Heizungsumlagen der letzten sechs Jahre (EUR/m²·Monat).
#' @param P Ausgabe von `mr_params()`.
#' @return numerischer Vektor (EUR/m²·Monat, ≥ 0).
#' @noRd
mr_levy_cap_heating <- function(prior_heat_6y, P) {
  n <- length(prior_heat_6y)
  if (n == 0L) return(numeric(0))
  cap <- P$cap_heating %||% P$cap_559e
  if (!isTRUE(P$active) || is.null(cap)) return(rep(Inf, n))
  pmax(cap - as.double(prior_heat_6y), 0)
}

#' Halbierung der Umlagebasis bei Wärmepumpen nach § 559f (Teil B 5.2)
#'
#' @param heat_pump Maßnahme ist eine Wärmepumpe (lgl).
#' @param jaz_plan Plan-JAZ (Basisfallwert).
#' @param flow_temperature_c Vorlauftemperatur in °C (`NA` = unbekannt).
#' @param construction_year Baujahr des Gebäudes (`NA` = unbekannt).
#' @param exception `auto`, `none`, `building_after_1996` oder `flow_temperature`.
#' @param threshold_inclusive Schwelle erfüllt bei JAZ ≥ (TRUE) bzw. > (FALSE) der Schwelle;
#'   `NA` = Rechtsstand.
#' @param P Ausgabe von `mr_params()`.
#' @return numerischer Vektor (1 = Halbierung, 0 = keine).
#' @noRd
mr_hp_halving <- function(heat_pump, jaz_plan, flow_temperature_c, construction_year, exception,
                          threshold_inclusive, P) {
  n <- mr_len(heat_pump, jaz_plan, flow_temperature_c, construction_year, exception,
              threshold_inclusive)
  if (n == 0L) return(numeric(0))
  thr <- P$hp_jaz_threshold
  if (is.null(thr)) return(rep(0, n))
  hp <- rep_len(as.logical(heat_pump), n)
  hp[is.na(hp)] <- FALSE
  jaz <- rep_len(as.double(jaz_plan), n)
  flow <- rep_len(as.double(flow_temperature_c), n)
  year <- rep_len(as.double(construction_year), n)
  exc <- rep_len(as.character(exception), n)
  exc[is.na(exc)] <- "auto"
  incl <- rep_len(as.logical(threshold_inclusive), n)
  incl[is.na(incl)] <- isTRUE(P$hp_inclusive %||% TRUE)
  meets <- ifelse(incl, jaz >= thr, jaz > thr)
  meets[is.na(meets)] <- FALSE
  y_exc <- !is.na(year) & !is.null(P$hp_exc_year) & year > (P$hp_exc_year %||% Inf)
  f_exc <- !is.na(flow) & !is.null(P$hp_exc_flow) & flow <= (P$hp_exc_flow %||% -Inf)
  is_exc <- ifelse(exc == "auto", y_exc | f_exc,
                   ifelse(exc == "building_after_1996", y_exc,
                          ifelse(exc == "flow_temperature", f_exc, FALSE)))
  as.double(hp & !meets & !is_exc)
}

#' Anpassungssatz der Indexmiete (§ 557b; Dämpfung nur mit Mietrecht II, Teil B 1.12)
#'
#' @param inflation_prev_year VPI-Veränderung des Vorjahres.
#' @param index_cap_area Gebiet mit Indexmietendämpfung (lgl).
#' @param P Ausgabe von `mr_params()`.
#' @return numerischer Vektor (Anpassungssatz).
#' @noRd
mr_index_adjustment <- function(inflation_prev_year, index_cap_area, P) {
  n <- mr_len(inflation_prev_year, index_cap_area)
  if (n == 0L) return(numeric(0))
  infl <- rep_len(as.double(inflation_prev_year), n)
  d <- P$index_damping
  if (is.null(d)) return(infl)
  area <- rep_len(as.logical(index_cap_area), n)
  area[is.na(area)] <- FALSE
  if (!isTRUE(mr_lgl(d$only_in_ordinance_areas, default = TRUE))) area[] <- TRUE
  thr <- mr_num(d$threshold_pa) %||% Inf
  keep <- 1 - (mr_num(d$excess_share_ignored) %||% 0)
  sym <- isTRUE(mr_lgl(d$symmetric, default = TRUE))
  over <- infl > thr
  under <- sym & infl < -thr
  damped <- ifelse(over, thr + keep * (infl - thr),
                   ifelse(under, -thr + keep * (infl + thr), infl))
  ifelse(area, damped, infl)
}

#' Gilt die Mietpreisbremse bei einer Wiedervermietung? (§§ 556d, 556f; Teil B 1.8.2 (g))
#'
#' @param brake_area Gebiet mit Mietpreisbremse (lgl).
#' @param brake_until Ende der Verordnung (Date; `NA` = Rechtsstand).
#' @param date Datum der Wiedervermietung (Monatsbeginn, Date).
#' @param first_use_after_2014_10_01 Neubauausnahme (§ 556f S. 1).
#' @param comprehensive_done umfassende Modernisierung bereits fertiggestellt (§ 556f S. 2).
#' @param P Ausgabe von `mr_params()`.
#' @return logischer Vektor.
#' @noRd
mr_brake_applies <- function(brake_area, brake_until, date, first_use_after_2014_10_01,
                             comprehensive_done, P) {
  n <- mr_len(brake_area, date, first_use_after_2014_10_01, comprehensive_done)
  if (n == 0L) return(logical(0))
  if (!isTRUE(P$active) || is.null(P$brake_cap_share)) return(rep(FALSE, n))
  area <- rep_len(as.logical(brake_area), n)
  area[is.na(area)] <- FALSE
  until <- if (length(brake_until) == 0L) as.Date(NA) else as.Date(brake_until)
  until <- rep_len(until, n)
  def_until <- P$brake_until_default %||% as.Date("9999-12-31")
  until[is.na(until)] <- def_until
  d <- rep_len(as.Date(date), n)
  newb <- rep_len(as.logical(first_use_after_2014_10_01), n)
  newb[is.na(newb)] <- FALSE
  comp <- rep_len(as.logical(comprehensive_done), n)
  comp[is.na(comp)] <- FALSE
  exempt <- comp & isTRUE(P$brake_comprehensive_exempt)
  area & !is.na(d) & d <= until & !newb & !exempt
}

#' Neuvertragsmiete bei Wiedervermietung (§§ 556d, 556e; Teil B 1.8.2 (g))
#'
#' Ohne Mietpreisbremse gilt die Marktmiete; mit Bremse höchstens das Maximum aus 110 % der
#' Vergleichsmiete, der Vormiete (§ 556e Abs. 1) und 110 % der Vergleichsmiete ohne jüngere
#' Modernisierungszuschläge zuzüglich der Umlagen der letzten drei Jahre (§ 556e Abs. 2).
#' @param market_rent Marktmiete (EUR/m²·Monat).
#' @param ovm Vergleichsmiete des aktuellen Zustands.
#' @param ovm_unmodernized Vergleichsmiete ohne Zuschläge der letzten 36 Monate.
#' @param current_rent Vormiete.
#' @param levy_recent Umlagen der letzten 36 Monate.
#' @param brake_applies Ergebnis von `mr_brake_applies()`.
#' @param P Ausgabe von `mr_params()`.
#' @return numerischer Vektor (EUR/m²·Monat).
#' @noRd
mr_relet_rent <- function(market_rent, ovm, ovm_unmodernized, current_rent, levy_recent,
                          brake_applies, P) {
  n <- mr_len(market_rent, ovm, ovm_unmodernized, current_rent, levy_recent, brake_applies)
  if (n == 0L) return(numeric(0))
  r <- function(x) rep_len(as.double(x), n)
  mkt <- r(market_rent)
  ba <- rep_len(as.logical(brake_applies), n)
  ba[is.na(ba)] <- FALSE
  cs <- P$brake_cap_share %||% 0
  allowed <- pmax((1 + cs) * r(ovm), r(current_rent), (1 + cs) * r(ovm_unmodernized) +
                    r(levy_recent))
  ifelse(ba, pmin(mkt, allowed), mkt)
}

# ---------------------------------------------------------------------------------------------
# Typdefinitionen (Registry-Art rule, Version ab 29.07.2026; Teil B 5.1)
# ---------------------------------------------------------------------------------------------

#' Minimaler Parametersatz für die Beispiele der Vertragstests (Werte nach legal/mietrecht_2026)
#' @noRd
mr_example_p <- function() {
  mr_params(
    list(s558 = list(waiting_months = 15, cap_share = 0.20, cap_share_tight_market = 0.15),
         s559 = list(rate_pa = 0.08, cap_eur_m2_month = 3, cap_low_rent_eur_m2_month = 2,
                     low_rent_threshold_eur_m2_month = 7, heating_cap_eur_m2_month = 0.5),
         s559c = list(flat_maintenance_share = 0.30),
         s559e = list(rate_pa = 0.10, flat_maintenance_share = 0.15),
         s557a = list(excludes = c("bgb_558", "bgb_559", "bgb_559b")),
         s557b = list(excludes = "bgb_558"),
         s556d = list(cap_share_over_ovm = 0.10, ordinance_until = "2029-12-31")),
    list(jaz_threshold = 2.5, comparison = "ge", reduction_factor = 0.5,
         exceptions = list(construction_year_after = 1996, flow_temperature_max_c = 55))
  )
}

#' @noRd
typedef_rule_mr_params_20260729 <- function() {
  vofi_type(
    name = "mr_params", kind = "rule", valid_from = "2026-07-29", returns = "params",
    source = "BGB \u00a7\u00a7 536, 556d-556g, 557a, 557b, 558, 559-559f (Teil B 5.2)",
    fun = mr_params,
    example = list(lp = list(s558 = list(cap_share = 0.2), s559 = list(rate_pa = 0.08)),
                   lp_559f = NULL)
  )
}

#' @noRd
typedef_rule_mr_levy_allowed_20260729 <- function() {
  vofi_type(
    name = "mr_levy_allowed", kind = "rule", valid_from = "2026-07-29", returns = "value",
    source = "BGB \u00a7\u00a7 557a Abs. 2, 557b Abs. 2, 559, 559c, 559e (Teil B 5.2)",
    fun = mr_levy_allowed,
    example = list(kind = "bgb_555b_1a", rent_regime = "paragraph_558", phase = "staffel",
                   landlord_responsible = TRUE, procedure = "bgb_559e", P = mr_example_p())
  )
}

#' @noRd
typedef_rule_mr_558_target_20260729 <- function() {
  vofi_type(
    name = "mr_558_target", kind = "rule", valid_from = "2026-07-29", returns = "sim",
    source = "BGB \u00a7 558 Abs. 3, 5 (Teil B 1.8.2)",
    fun = mr_558_target,
    example = list(ovm = 9, base_36m = 7, increases_36m = 0.5, kuerzung = 0.2, cap_share = 0.2,
                   voluntary_cap = 12)
  )
}

#' @noRd
typedef_rule_mr_levy_annual_20260729 <- function() {
  vofi_type(
    name = "mr_levy_annual", kind = "rule", valid_from = "2026-07-29", returns = "sim",
    source = "BGB \u00a7\u00a7 559, 559a, 559c, 559e, 559f (Teil B 1.9.3)",
    fun = mr_levy_annual,
    example = list(procedure = "bgb_559", cost = 60000, maintenance = 18000, grants = 0,
                   repayment_grants = 3000, interest_reduction = 162, attribution = "full",
                   hp_halving = 0, hp_order = "halve_then_funds", flat_order = "flat_before_funds",
                   section43 = FALSE, interest_in_559e = TRUE, P = mr_example_p())
  )
}

#' @noRd
typedef_rule_mr_levy_cap_total_20260729 <- function() {
  vofi_type(
    name = "mr_levy_cap_total", kind = "rule", valid_from = "2026-07-29", returns = "sim",
    source = "BGB \u00a7 559 Abs. 3a (Teil B 1.9.5)",
    fun = mr_levy_cap_total,
    example = list(rent_before = 6.2, prior_6y = 0.3, P = mr_example_p())
  )
}

#' @noRd
typedef_rule_mr_levy_cap_heating_20260729 <- function() { # nolint: object_length_linter.
  vofi_type(
    name = "mr_levy_cap_heating", kind = "rule", valid_from = "2026-07-29", returns = "sim",
    source = "BGB \u00a7 559 Abs. 3a S. 3, \u00a7 559e (Teil B 1.9.5)",
    fun = mr_levy_cap_heating,
    example = list(prior_heat_6y = 0.1, P = mr_example_p())
  )
}

#' @noRd
typedef_rule_mr_hp_halving_20260729 <- function() {
  vofi_type(
    name = "mr_hp_halving", kind = "rule", valid_from = "2026-07-29", returns = "sim",
    source = "BGB \u00a7 559f (Teil B 5.2; Thema mietrecht_559f)",
    fun = mr_hp_halving,
    example = list(heat_pump = TRUE, jaz_plan = 2.4, flow_temperature_c = 70,
                   construction_year = 1985, exception = "auto", threshold_inclusive = TRUE,
                   P = mr_example_p())
  )
}

#' @noRd
typedef_rule_mr_index_adjustment_20260729 <- function() { # nolint: object_length_linter.
  vofi_type(
    name = "mr_index_adjustment", kind = "rule", valid_from = "2026-07-29", returns = "sim",
    source = "BGB \u00a7 557b (Teil B 1.8.2 (b), 1.12)",
    fun = mr_index_adjustment,
    example = list(inflation_prev_year = 0.028, index_cap_area = FALSE, P = mr_example_p())
  )
}

#' @noRd
typedef_rule_mr_brake_applies_20260729 <- function() {
  vofi_type(
    name = "mr_brake_applies", kind = "rule", valid_from = "2026-07-29", returns = "sim",
    source = "BGB \u00a7\u00a7 556d, 556f (Teil B 1.8.2 (g))",
    fun = mr_brake_applies,
    example = list(brake_area = TRUE, brake_until = as.Date("2029-12-31"),
                   date = as.Date("2028-01-01"), first_use_after_2014_10_01 = FALSE,
                   comprehensive_done = 0, P = mr_example_p())
  )
}

#' @noRd
typedef_rule_mr_relet_rent_20260729 <- function() {
  vofi_type(
    name = "mr_relet_rent", kind = "rule", valid_from = "2026-07-29", returns = "sim",
    source = "BGB \u00a7\u00a7 556d, 556e (Teil B 1.8.2 (g))",
    fun = mr_relet_rent,
    example = list(market_rent = 11, ovm = 9, ovm_unmodernized = 9, current_rent = 8,
                   levy_recent = 0, brake_applies = TRUE, P = mr_example_p())
  )
}

# nolint end
