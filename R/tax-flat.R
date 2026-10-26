# Vereinfachtes Pauschalsteuer-Modul tax_flat (WS-X; Spec 00 Abschnitte 10.2-10.7, 10.10;
# Memo 06 Abschnitte 6.2 und 7). Optional, Standard aus (tax_none bleibt Default), gesperrt fuer
# Selbstnutzer und steuerbefreite Rechtstraeger (Perspektive selbstnutzer, Steuerregime
# selbstnutzer, wu_eg_befreit, wu_gemeinnuetzig). Vereinfachte Naeherung - keine Steuerberatung.
#
# Steuerliches Ergebnis je Periode t (n-Vektor; Vorzeichen der Eingaben nach 10.4):
#   E_t = Einnahmen (income_rental, income_other_taxable, subsidy_operating, Zuschuesse als
#         Einnahme) + abziehbare Aufwendungen (expense_deductible, interest_expense der Zeilen)
#       + Erhaltungsaufwand (capex_expensable sofort bzw. nach 82b EStDV verteilt)
#       - AfA (linear 7 Abs. 4 bzw. degressiv 7 Abs. 5a je Anlage) - Sonder-AfA 7b
#       - Sollzinsen (Summe exo_soll, exo_fees, endo_soll) und Disagio
#       [+ Habenzinsen (endo_haben) nur im Modus "ergebnis", Default fuer Unternehmen]
# Bemessungsgrundlage der AfA je asset_id = capex_depreciable + acquisition_ancillary - Zuschuesse
# (subsidy_investment, subsidy_repayment_grant; ueber measure_id der Anlage zugeordnet).
# Steuer je Veranlagungsjahr (Kalenderjahr des Periodenbeginns) mit Satz s_t (Zeitreihe):
# Verlustmodus sofort (Erstattung, optional gedeckelt durch other_income_eur_pa) bzw. vortrag
# (projektinterner Verlustvortrag ohne Mindestbesteuerung); lag 0 (Zahlung in der Periode) bzw.
# lag 1 (Veranlagung: Zahlung in der ersten Periode des Folgejahres); private Habenzinsen getrennt
# mit Abgeltungssatz (sofort, ohne Verrechnung mit V+V). Am Horizont (tax_finalize): offene
# Steuer, Steuer auf den Restwert (privat 23 EStG innerhalb der Frist, Unternehmen stets),
# optional Wert des verbleibenden Verlustvortrags. Keine Zirkularitaet: die Steuer in t nutzt
# nur Groessen bis t (Zinsen auf Bestaende t-1, Spec 00 10.1 Nr. 3); vektorisiert ueber n,
# Verzweigungen nur auf Termine und Konfiguration (2.8 Nr. 2).
# Parameter (Saetze, AfA-Regeln mit Gueltigkeit, Quellen): inst/params/steuern_DE.yaml.

# ---------------------------------------------------------------------------------------------
# Typdefinition und Parameter
# ---------------------------------------------------------------------------------------------

#' Steuermodul flat (Spec 00 Abschnitt 10.7)
#' @noRd
typedef_tax_flat <- function() {
  vofi_type(
    name = "flat", kind = "tax", params = tax_flat_param_schema(),
    perspectives = tax_flat_perspectives(), blocked_regimes = tax_flat_blocked_regimes(),
    uses_inputs = TRUE,
    constructor = tax_flat_constructor,
    example = list(rate = 0, capital_rate = 0, lag = 0L, loss_mode = "sofort")
  )
}

#' Perspektiven, für die tax_flat zulässig ist (Selbstnutzer gesperrt, Memo 06 6.2)
#' @noRd
tax_flat_perspectives <- function() {
  c("wu_kommunal", "wu_genossenschaft", "wu_privat", "kleinvermieter")
}

#' Gesperrte Steuerregime (Spec 00 10.2: Selbstnutzer, befreite eG, gemeinnützig)
#' @noRd
tax_flat_blocked_regimes <- function() c("selbstnutzer", "wu_eg_befreit", "wu_gemeinnuetzig")

#' Steuerregime der Unternehmen (Körperschaftsteuer-Pfad, Habenzinsen im Ergebnis)
#' @noRd
tax_flat_company_regimes <- function() c("wu_kapges", "wu_kommunal", "wu_eg_stpfl")

#' Parameterschema von tax_flat (Spec 00 10.7, Memo 06 6.2)
#'
#' `rate` ohne Angabe: Default nach Steuerregime aus `inst/params/steuern_DE.yaml` (privat
#' Grenzsteuersatz 44,31 %, Unternehmen KSt + Soli nach Jahr plus GewSt bei Hebesatz).
#' @noRd
tax_flat_param_schema <- function() {
  p <- vofi_param
  list(
    rate = p("value", min = 0, max = 0.99, unit = "share"),
    loss_mode = p("enum", values = c("sofort", "vortrag"), default = "sofort"),
    other_income_eur_pa = p("amount", min = 0, unit = "EUR_pa"),
    lag = p("integer", default = 1L, min = 0, max = 1),
    deposit_interest = p("enum", values = c("auto", "abgeltung", "ergebnis", "keine"),
                         default = "auto"),
    capital_rate = p("share", max = 0.99),
    church_tax_rate = p("share", default = 0, max = 0.09),
    saver_allowance_eur_pa = p("amount", default = 0, min = 0, unit = "EUR_pa"),
    trade_tax_multiplier = p("number", min = 0, max = 10, unit = "factor"),
    depreciation_method = p("enum", values = c("auto", "linear", "degressiv"), default = "auto"),
    degressive_switch_year = p("integer", min = 1),
    building_rate = p("share", min = 0, max = 1),
    special_7b = p("logical", default = FALSE),
    spread_years = p("integer", default = 1L, min = 1, max = 5),
    subsidy_treatment = p("enum", values = c("minderung", "einnahme"), default = "minderung"),
    acquisition_related = p("enum", values = c("pruefung", "umgliederung"),
                            default = "pruefung"),
    acquisition_vat_rate = p("share", default = 0.19),
    residual_value_tax = p("enum", values = c("auto", "ja", "nein"), default = "auto"),
    existing_book_value_eur = p("amount", default = 0, min = 0),
    holding_start = p("date"),
    remaining_loss = p("enum", values = c("verfall", "satz"), default = "verfall")
  )
}

#' Steuerparameter Deutschland (`inst/params/steuern_DE.yaml`)
#' @return Liste der Datei (Daten als Zeichenketten bzw. Date).
#' @noRd
tax_flat_legal <- function() {
  path <- system.file("params", "steuern_DE.yaml", package = "vofi")
  if (!nzchar(path)) {
    vofi_abort("core.file_missing", path = "inst/params/steuern_DE.yaml",
               .class = "vofi_error_input")
  }
  utl_read_yaml(path)
}

# ---------------------------------------------------------------------------------------------
# Konstruktor und Konfiguration (deterministisch, je Modell einmal)
# ---------------------------------------------------------------------------------------------

#' Konstruktor des Moduls (Spec 00 10.2): Konfiguration, Sperre, Bauprüfungen
#' @noRd
tax_flat_constructor <- function(params, spec) {
  info <- tax_flat_info(spec)
  tax_flat_check_blocked(info)
  legal <- tax_flat_legal()
  cfg <- tax_flat_config(params, info, legal)
  vofi_inform("types.tax.flat.msg.disclaimer")
  tax_flat_build_checks(cfg, info)
  new_tax_module("flat", params = params, cfg = cfg, info = info, uses_inputs = TRUE,
                 once = new.env(parent = emptyenv()))
}

#' Szenariogrößen, die das Modul liest (Regime, Projektart, Restwert, Register)
#' @noRd
tax_flat_info <- function(spec) {
  proj <- spec$project %||% list()
  persp <- proj$perspective %||% NA_character_
  regime <- proj$tax_regime
  if (!utl_is_string(regime)) {
    map <- vocab("tax_regime")$from_perspective %||% list()
    regime <- if (utl_is_string(persp)) map[[persp]] %||% NA_character_ else NA_character_
  }
  rv <- spec$residual_value$method
  list(perspective = persp, regime = regime,
       project_type = proj$project_type %||% NA_character_,
       rv_method = if (utl_is_string(rv)) rv else "zero",
       registers = spec$registers %||% list(assets = list(), measures = list()),
       variant = spec$variant %||% "base",
       year = tax_flat_year_of(proj$valuation_date))
}

#' Kalenderjahr eines Datums (Date oder ISO-Zeichenkette) bzw. NULL
#' @noRd
tax_flat_year_of <- function(d) {
  if (is.null(d)) return(NULL)
  d <- tryCatch(utl_as_date(d, "valuation_date"), vofi_error = function(e) NULL)
  if (is.null(d)) NULL else as.integer(format(d[1L], "%Y"))
}

#' Harte Sperre für Selbstnutzer und befreite Rechtsträger (Memo 06 6.2)
#'
#' `vofi_build()` sperrt bereits über `perspectives`/`blocked_regimes` (10.2); diese Prüfung
#' gilt auch für direkte Aufrufe des Konstruktors und nennt den Grund ausdrücklich.
#' @noRd
tax_flat_check_blocked <- function(info) {
  bad <- (utl_is_string(info$perspective) && !(info$perspective %in% tax_flat_perspectives())) ||
    (utl_is_string(info$regime) && info$regime %in% tax_flat_blocked_regimes())
  if (!bad) return(invisible(NULL))
  text <- msg("types.tax.flat.msg.blocked", perspective = info$perspective %||% "",
              regime = info$regime %||% "")
  report <- new_vofi_validation(data.frame(
    severity = "error", code = "types.tax.flat.msg.blocked", path = "tax.module",
    location = NA_character_, message = text, layer = NA_integer_,
    variant = info$variant %||% "base", stringsAsFactors = FALSE
  ))
  vofi_abort("types.tax.flat.msg.blocked", perspective = info$perspective %||% "",
             regime = info$regime %||% "", .class = "vofi_error_validation",
             .data = list(report = report))
}

#' Parameterfehler melden
#' @noRd
tax_flat_param_error <- function(param, value, expected) {
  vofi_abort("types.tax.flat.msg.param_invalid", param = param,
             value = utl_collapse(format(value)), expected = expected,
             .class = "vofi_error_input")
}

#' Wert eines Parameters ohne Knotenhülle (Konstante -> Zahl)
#' @noRd
tax_flat_unwrap <- function(x, param) {
  if (node_is(x)) {
    if (identical(x$kind, "const")) return(x$value)
    vofi_abort("types.tax.flat.msg.param_form", param = param, kind = x$kind,
               .class = "vofi_error_input")
  }
  x
}

#' Zahl eines Parameters prüfen (Skalar, endlich, Grenzen des Schemas)
#' @noRd
tax_flat_number <- function(x, param, def) {
  x <- tax_flat_unwrap(x, param)
  if (is.null(x)) return(NULL)
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) {
    tax_flat_param_error(param, x, "Zahl")
  }
  lo <- def$min %||% -Inf
  hi <- def$max %||% Inf
  if (x < lo || x > hi) tax_flat_param_error(param, x, paste0("[", lo, ", ", hi, "]"))
  as.double(x)
}

#' Konfiguration aus Parametern, Szenariogrößen und Steuerparametern
#' @param params Parameter des Moduls (`tax.params`, Defaults ggf. noch nicht eingesetzt).
#' @param info Ergebnis von `tax_flat_info()`.
#' @param legal Steuerparameter (`tax_flat_legal()`).
#' @return Liste (deterministisch).
#' @noRd
tax_flat_config <- function(params, info, legal) {
  params <- params %||% list()
  schema <- tax_flat_param_schema()
  if (!is.list(params) || (length(params) > 0L && is.null(names(params)))) {
    tax_flat_param_error("params", class(params)[1L], "benannte Liste")
  }
  unknown <- setdiff(names(params), names(schema))
  if (length(unknown) > 0L) {
    vofi_abort("types.tax.flat.msg.param_unknown", param = utl_collapse(unknown),
               suggestion = utl_suggest_text(unknown[1L], names(schema)),
               .class = "vofi_error_input")
  }
  get_p <- function(nm) {
    v <- params[[nm]]
    if (is.null(v)) v <- schema[[nm]]$default
    v
  }
  code <- function(nm) {
    v <- tax_flat_unwrap(get_p(nm), nm)
    vals <- schema[[nm]]$values
    if (!utl_is_string(v) || !(v %in% vals)) tax_flat_param_error(nm, v, utl_collapse(vals))
    v
  }
  num <- function(nm) tax_flat_number(get_p(nm), nm, schema[[nm]])
  int <- function(nm) {
    v <- tax_flat_unwrap(get_p(nm), nm)
    if (is.null(v)) return(NULL)
    if (!utl_is_whole(v)) tax_flat_param_error(nm, v, "ganze Zahl")
    v <- as.integer(round(v))
    lo <- schema[[nm]]$min %||% -Inf
    hi <- schema[[nm]]$max %||% Inf
    if (v < lo || v > hi) tax_flat_param_error(nm, v, paste0("[", lo, ", ", hi, "]"))
    v
  }
  flag <- function(nm) {
    v <- tax_flat_unwrap(get_p(nm), nm)
    if (!utl_is_flag(v)) tax_flat_param_error(nm, v, "TRUE/FALSE")
    v
  }
  regime <- info$regime
  private <- identical(regime, "privat_vermieter")
  company <- utl_is_string(regime) && regime %in% tax_flat_company_regimes()
  trade_mult <- num("trade_tax_multiplier")
  rate <- tax_flat_rate_config(get_p("rate"), private, trade_mult, legal)
  church <- num("church_tax_rate")
  cap <- legal$capital_income_tax
  capital_rate <- num("capital_rate") %||%
    (as.double(cap$rate) / (1 + as.double(cap$rate) * church) *
       (1 + as.double(cap$solidarity_surcharge) + church))
  deposit <- code("deposit_interest")
  if (identical(deposit, "auto")) deposit <- if (private) "abgeltung" else "ergebnis"
  loss_mode <- code("loss_mode")
  other <- num("other_income_eur_pa")
  loss_cap <- if (identical(loss_mode, "vortrag")) 0 else other %||% Inf
  hs <- tax_flat_unwrap(get_p("holding_start"), "holding_start")
  if (!is.null(hs)) {
    hs <- tryCatch(utl_as_date(hs, "holding_start"),
                   vofi_error = function(e) tax_flat_param_error("holding_start", hs, "Datum"))
  }
  dep <- legal$depreciation
  acq <- legal$acquisition_related
  it <- legal$income_tax
  # Spitzenbelastung privat: 45 % + Soli + Kirchensteuer (Plausibilitätsgrenze des Satzes)
  rate_max <- as.double(it$top_rates$zone5) *
    (1 + as.double(it$solidarity_surcharge) + as.double(it$church_tax_rates$other))
  list(
    regime = regime, private = private, company = company,
    rate = rate, rate_max = rate_max, capital_rate = capital_rate, deposit = deposit,
    allowance = num("saver_allowance_eur_pa"), loss_mode = loss_mode, loss_cap = loss_cap,
    lag = int("lag"), trade_mult = trade_mult,
    dep_method = code("depreciation_method"), switch_year = int("degressive_switch_year"),
    building_rate = num("building_rate"), special_7b = flag("special_7b"),
    spread_default = int("spread_years"), spread_allowed = private,
    subsidy = code("subsidy_treatment"), acq_mode = code("acquisition_related"),
    acq_vat = num("acquisition_vat_rate"), acq_share = as.double(acq$share),
    acq_months = 12L * as.integer(acq$years),
    acq_excluded = as.character(acq$excluded_measure_types),
    rv_mode = code("residual_value_tax"), rv_method = info$rv_method,
    ebv = num("existing_book_value_eur"), holding_start = hs,
    holding_years = as.integer(legal$private_sale$holding_years),
    remaining_loss = code("remaining_loss"),
    dep = list(
      linear = lapply(dep$buildings_linear$periods, tax_flat_period_dates),
      business_rate = as.double(dep$business_buildings$rate),
      deg_rate = as.double(dep$degressive_residential$rate),
      deg_from = utl_as_date(dep$degressive_residential$window_from, "window_from"),
      deg_to = utl_as_date(dep$degressive_residential$window_to, "window_to"),
      s7b_rate = as.double(dep$special_7b$rate), s7b_years = as.integer(dep$special_7b$years),
      s7b_from = utl_as_date(dep$special_7b$window_from, "window_from"),
      s7b_to = utl_as_date(dep$special_7b$window_to, "window_to"),
      s7b_cost_cap = as.double(dep$special_7b$cost_cap_eur_m2),
      s7b_basis_cap = as.double(dep$special_7b$basis_cap_eur_m2),
      s7b_standard = as.character(dep$special_7b$efficiency_standard),
      useful_life = dep$useful_life_years
    )
  )
}

#' Datumsgrenzen einer Tabellenzeile (completed_from/completed_to) als Date bzw. NA
#' @noRd
tax_flat_period_dates <- function(row) {
  d <- function(x) if (is.null(x)) as.Date(NA) else utl_as_date(x, "completed")
  list(from = d(row$completed_from), to = d(row$completed_to), rate = as.double(row$rate))
}

#' Steuersatz s_t (Spec 00 10.7: Zeitreihe)
#'
#' Nutzereingabe: Skalar (`const`) oder Basisfallpfad 1 x (T+1) (`path`); ohne Eingabe privat
#' der Grenzsteuersatz aus den Steuerparametern, Unternehmen KSt + Soli nach Jahr plus GewSt
#' (Messzahl x max(Hebesatz, Mindesthebesatz); ohne Hebesatz erweiterte Kürzung, GewSt 0).
#' @return `list(kind = "const" | "path" | "year", value, values, years, default = lgl)`.
#' @noRd
tax_flat_rate_config <- function(x, private, trade_mult, legal) {
  x <- tax_flat_unwrap(x, "rate")
  if (!is.null(x)) {
    v <- if (is.numeric(x)) as.double(x) else NA_real_
    if (length(v) == 0L || any(!is.finite(v)) || any(v < 0) || any(v >= 1)) {
      vofi_abort("types.tax.flat.msg.rate_invalid", value = utl_collapse(format(x)),
                 .class = "vofi_error_input")
    }
    if (length(v) == 1L) return(list(kind = "const", value = v, default = FALSE))
    return(list(kind = "path", values = v, default = FALSE))
  }
  if (private) {
    return(list(kind = "const", value = as.double(legal$income_tax$default_marginal_rate),
                default = TRUE))
  }
  ct <- legal$corporate_tax
  tt <- legal$trade_tax
  year_of <- function(d) as.integer(format(utl_as_date(d, "valid_from"), "%Y"))
  k_years <- vapply(ct$periods, function(r) year_of(r$valid_from), integer(1))
  k_rates <- vapply(ct$periods, function(r) as.double(r$rate), double(1))
  m_years <- vapply(tt$min_multiplier, function(r) year_of(r$valid_from), integer(1))
  m_vals <- vapply(tt$min_multiplier, function(r) as.double(r$value), double(1))
  years <- sort(unique(c(k_years, m_years)), method = "radix")
  at <- function(ys, vs, y) vs[max(1L, findInterval(y, ys))]
  values <- vapply(years, function(y) {
    kst <- at(k_years, k_rates, y) * (1 + as.double(ct$solidarity_surcharge))
    gew <- if (is.null(trade_mult)) 0 else
      as.double(tt$base_rate) * max(trade_mult, at(m_years, m_vals, y))
    kst + gew
  }, double(1))
  list(kind = "year", years = years, values = values, default = TRUE)
}

#' Steuersatz der Periode t (Kalenderjahr `year`)
#' @noRd
tax_flat_rate_at <- function(rate, t, year) {
  switch(rate$kind,
    const = rate$value,
    path = {
      j <- t + 1L
      if (j > length(rate$values)) {
        vofi_abort("types.tax.flat.msg.rate_path_length", t = t, n = length(rate$values),
                   .class = "vofi_error_contract")
      }
      rate$values[j]
    },
    year = rate$values[max(1L, findInterval(year, rate$years))]
  )
}

#' Prüfungen beim Bau (deterministisch: Register, Daten, Parameter; Memo 06 6.2 „Prüfregeln“)
#' @noRd
tax_flat_build_checks <- function(cfg, info) {
  if (isTRUE(cfg$rate$default)) {
    vofi_inform("types.tax.flat.msg.rate_default", regime = cfg$regime %||% "",
                value = tax_flat_rate_at(cfg$rate, 0L, info$year %||% 2026L))
  } else if (cfg$private && identical(cfg$rate$kind, "const") && cfg$rate$value > cfg$rate_max) {
    vofi_warn("types.tax.flat.msg.rate_high", value = cfg$rate$value,
              .class = "vofi_warning_plausibility")
  }
  if (cfg$company && !is.null(cfg$trade_mult) && cfg$trade_mult < 2.8) {
    vofi_inform("types.tax.flat.msg.trade_min", value = cfg$trade_mult)
  }
  if (!cfg$spread_allowed && cfg$spread_default > 1L) {
    vofi_inform("types.tax.flat.msg.spread_private_only", years = cfg$spread_default)
  }
  assets <- info$registers$assets %||% list()
  for (a in assets) {
    if (!inherits(a, "vofi_asset")) next
    ac <- tax_flat_asset_setup(a$asset_id, a, cfg, NULL)
    if (identical(cfg$dep_method, "degressiv") && identical(a$asset_type, "gebaeude_wohnen") &&
          !identical(ac$method, "degressiv")) {
      vofi_warn("types.tax.flat.msg.degressive_ineligible", asset = a$asset_id,
                .class = "vofi_warning_plausibility")
    }
    if (cfg$special_7b && identical(a$asset_type, "gebaeude_wohnen")) {
      tax_flat_check_7b(a, ac)
    }
  }
  tax_flat_check_acquisition(cfg, info)
  rv_taxed <- !identical(cfg$rv_method, "zero") && !identical(cfg$rv_mode, "nein") &&
    (cfg$company || identical(cfg$rv_mode, "ja"))
  existing <- info$project_type %in% (vocab("project_type")$existing_building %||% character(0))
  if (rv_taxed && existing && cfg$ebv == 0) {
    vofi_warn("types.tax.flat.msg.existing_book_value", .class = "vofi_warning_plausibility")
  }
  invisible(NULL)
}

#' Prüfungen der Sonder-AfA § 7b (Fenster, Effizienzhaus 40, Fläche; Memo 06 3.1.2, 6.2)
#' @noRd
tax_flat_check_7b <- function(a, ac) {
  if (!ac$s7b) {
    vofi_warn("types.tax.flat.msg.s7b_ineligible", asset = a$asset_id,
              .class = "vofi_warning_plausibility")
    return(invisible(NULL))
  }
  if (is.null(a$efficiency_standard)) {
    vofi_warn("types.tax.flat.msg.s7b_unchecked", asset = a$asset_id, what = "efficiency_standard",
              .class = "vofi_warning_plausibility")
  }
  if (is.null(a$building_application_date) && is.null(a$construction_start_date)) {
    vofi_warn("types.tax.flat.msg.s7b_unchecked", asset = a$asset_id,
              what = "building_application_date", .class = "vofi_warning_plausibility")
  }
  if (is.na(ac$area)) {
    vofi_warn("types.tax.flat.msg.s7b_unchecked", asset = a$asset_id, what = "living_area_m2",
              .class = "vofi_warning_plausibility")
  }
  vofi_inform("types.tax.flat.msg.s7b_conditions", asset = a$asset_id)
  invisible(NULL)
}

#' Hinweis anschaffungsnahe Herstellungskosten (§ 6 Abs. 1 Nr. 1a EStG; Memo 06 6.2)
#'
#' Erhaltungsmaßnahmen, die innerhalb von drei Jahren nach Anschaffung fertig werden, werden im
#' Modus `pruefung` nur geprüft (Merkzeilen, Warnung bei Überschreitung im Lauf); der Hinweis
#' nennt die betroffenen Maßnahmen schon beim Bau.
#' @noRd
tax_flat_check_acquisition <- function(cfg, info) {
  assets <- Filter(function(a) inherits(a, "vofi_asset") && !is.null(a$acquisition_date),
                   info$registers$assets %||% list())
  if (length(assets) == 0L || !identical(cfg$acq_mode, "pruefung")) return(invisible(NULL))
  ms <- info$registers$measures %||% list()
  hits <- character(0)
  for (a in assets) {
    to <- grid_add_months(a$acquisition_date, cfg$acq_months)
    for (m in ms) {
      if (!inherits(m, "vofi_measure") || !identical(m$classification, "erhaltung")) next
      if (!identical(m$asset_id %||% a$asset_id, a$asset_id)) next
      cd <- m$completion_date
      if (!is.null(cd) && cd >= a$acquisition_date && cd <= to) hits <- c(hits, m$measure_id)
    }
  }
  if (length(hits) > 0L) {
    vofi_warn("types.tax.flat.msg.acq_hint", measures = utl_collapse(unique(hits)),
              share = cfg$acq_share, .class = "vofi_warning_plausibility")
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Anlagen: AfA-Methode, Sätze, Inbetriebnahme (Memo 06 3.1.2, 7.4)
# ---------------------------------------------------------------------------------------------

#' AfA-Konfiguration einer Anlage
#' @param id asset_id.
#' @param a Registereintrag (`vofi_asset`) oder `NULL` (nicht registrierte Anlage: Wohngebäude,
#'   in Betrieb ab Stichtag, Satz nach `building_rate` bzw. Fertigstellung am Stichtag).
#' @param cfg Konfiguration.
#' @param t0 Stichtag (`Date`) oder `NULL`.
#' @return Liste `id`, `type`, `land`, `ism` (Monatserster der Inbetriebnahme oder NA), `method`
#'   (`linear`, `degressiv`, `none`), `rate_lin`, `rate_deg`, `s7b`, `s7b_years`, `area`,
#'   `acq_from`, `acq_to`, `y0` (Jahr der Inbetriebnahme bzw. NA).
#' @noRd
tax_flat_asset_setup <- function(id, a, cfg, t0) {
  dep <- cfg$dep
  type <- if (is.null(a)) "gebaeude_wohnen" else a$asset_type
  isd <- if (is.null(a)) as.Date(NA) else a$in_service_date
  ism <- if (is.na(isd)) as.Date(NA) else as.Date(format(isd, "%Y-%m-01"))
  y0 <- if (is.na(isd)) NA_integer_ else as.integer(format(isd, "%Y"))
  out <- list(id = id, type = type, land = identical(type, "grund_boden"), ism = ism,
              method = "linear", rate_lin = 0, rate_deg = 0, s7b = FALSE,
              s7b_years = integer(0), area = NA_real_, acq_from = as.Date(NA),
              acq_to = as.Date(NA), y0 = y0)
  if (!is.null(a) && !is.null(a$acquisition_date)) {
    out$acq_from <- a$acquisition_date
    out$acq_to <- grid_add_months(a$acquisition_date, cfg$acq_months)
  }
  if (out$land) {
    out$method <- "none"
    return(out)
  }
  override <- if (is.null(a)) NULL else a$useful_life_override
  building <- type %in% c("gebaeude_wohnen", "gebaeude_nichtwohnen")
  if (!building) {
    life <- override %||% as.double(dep$useful_life[[type]] %||% 10)
    out$rate_lin <- 1 / life
    return(out)
  }
  completion <- if (!is.null(a) && !is.null(a$original_completion_year)) {
    as.Date(sprintf("%04d-07-01", as.integer(a$original_completion_year)))
  } else if (!is.na(isd)) {
    isd
  } else {
    t0 %||% as.Date(NA)
  }
  out$rate_lin <- if (!is.null(override)) {
    1 / override
  } else if (!is.null(cfg$building_rate)) {
    cfg$building_rate
  } else if (identical(type, "gebaeude_nichtwohnen") && cfg$company) {
    dep$business_rate
  } else {
    tax_flat_linear_rate(dep$linear, completion)
  }
  if (identical(type, "gebaeude_wohnen")) {
    csd <- if (is.null(a)) NULL else a$construction_start_date
    deg_ok <- !is.null(csd) && csd >= dep$deg_from && csd <= dep$deg_to
    if (deg_ok && cfg$dep_method %in% c("auto", "degressiv")) {
      out$method <- "degressiv"
      out$rate_deg <- dep$deg_rate
    }
    if (cfg$special_7b && !is.null(a)) {
      new_building <- !is.na(y0) && y0 >= 2023L &&
        (is.null(a$original_completion_year) || a$original_completion_year >= 2023L)
      std_ok <- is.null(a$efficiency_standard) ||
        identical(a$efficiency_standard, dep$s7b_standard)
      app <- a$building_application_date %||% a$construction_start_date
      app_ok <- is.null(app) || (app >= dep$s7b_from && app <= dep$s7b_to)
      out$s7b <- new_building && std_ok && app_ok
      if (out$s7b) out$s7b_years <- y0 + seq_len(dep$s7b_years) - 1L
      out$area <- if (is.null(a$living_area_m2) || !(a$living_area_m2 > 0)) NA_real_ else
        as.double(a$living_area_m2)
    }
  }
  out
}

#' Linearer Gebäudesatz nach dem Fertigstellungsdatum (§ 7 Abs. 4 S. 1 Nr. 2)
#' @noRd
tax_flat_linear_rate <- function(table, completion) {
  if (length(completion) != 1L || is.na(completion)) return(table[[length(table)]]$rate)
  for (row in table) {
    lo_ok <- is.na(row$from) || completion >= row$from
    hi_ok <- is.na(row$to) || completion <= row$to
    if (lo_ok && hi_ok) return(row$rate)
  }
  table[[length(table)]]$rate
}

#' Monate der Periode, in denen die Anlage in Betrieb ist (Monat der Inbetriebnahme zählt)
#' @param ism Monatserster der Inbetriebnahme oder NA (in Betrieb ab Stichtag).
#' @param date_end Periodenende (Monatserster), `months` Periodenlänge in Monaten.
#' @noRd
tax_flat_months_in <- function(ism, date_end, months) {
  if (months <= 0L) return(0L)
  if (is.na(ism)) return(months)
  me <- as.integer(format(date_end, "%Y")) * 12L + as.integer(format(date_end, "%m"))
  mi <- as.integer(format(ism, "%Y")) * 12L + as.integer(format(ism, "%m"))
  max(0L, min(months, me - mi))
}

# ---------------------------------------------------------------------------------------------
# Zuordnung der Eingabezeilen (einmal je Lauf in der ersten Periode, deterministisch)
# ---------------------------------------------------------------------------------------------

#' Register als Listen je id
#' @noRd
tax_flat_registers <- function(assets, measures) {
  a <- list()
  for (x in assets %||% list()) if (inherits(x, "vofi_asset")) a[[x$asset_id]] <- x
  m <- list()
  for (x in measures %||% list()) if (inherits(x, "vofi_measure")) m[[x$measure_id]] <- x
  list(assets = a, measures = m)
}

#' Feld aus den Zusatzfeldern einer Eingabezeile
#' @noRd
tax_flat_extra <- function(keys, i, field) {
  ex <- keys$extra
  if (is.null(ex) || length(ex) < i) return(NULL)
  e <- ex[[i]]
  if (!is.list(e)) return(NULL)
  e[[field]]
}

#' Zuordnung der Eingabezeilen zu Rechengrößen (Terme) und Anlagenkonfiguration
#'
#' Terme: `inc`, `exp`, `int_exp`, `int_inc`, `disagio`, `sub_inc`, `land`, `mnt|k` (Erhaltung
#' mit Verteilung k), `dep|a` (Zugang zur Bemessung, positiv), `sub|a` (Minderung durch
#' Zuschuss, positiv), `subauto|a` (Zuschuss zu einer Maßnahme mit Einordnung auto), `ak|a`
#' (Anschaffungskosten des Gebäudes), `acqC|a` (Aufwand netto im 15-%-Test), `acqX|a` (davon
#' als Erhaltung eingeordnet), `acqE|a|k` (Erhaltung im Prüfzeitraum, Modus umgliederung),
#' `acqA|a` (Maßnahme mit Einordnung auto im Prüfzeitraum).
#' @return `state` mit `map`, `ast`, `acq`, `has_rv`, `t0_date`.
#' @noRd
tax_flat_prepare <- function(state, inputs, n) {
  cfg <- state$cfg
  keys <- inputs$keys
  z <- numeric(n)
  state$t0_date <- inputs$date_end
  cx <- tax_flat_key_context(keys, state$reg, cfg)
  acc <- new.env(parent = emptyenv())
  acc$terms <- list()
  acc$defer <- list()
  for (i in seq_len(cx$nk)) {
    if (tax_flat_map_row(acc, cx, i, cfg)) state$has_rv <- TRUE
  }
  terms <- acc$terms
  # Anlagen: alle Anlagen mit Termen (Zugang, Zuschuss, Prüfzeitraum) und des Registers
  ids <- unique(c(vapply(terms, function(tm) tm$asset, ""), names(state$reg$assets)))
  ids <- ids[!is.na(ids)]
  ast <- list()
  acq <- list()
  for (a in ids) {
    ac <- tax_flat_asset_setup(a, state$reg$assets[[a]], cfg, inputs$date_end)
    if (ac$land) next
    ast[[a]] <- list(cfg = ac, base = z, bv = z, cum = z, lin = z, used7b = rep(FALSE, n),
                     reset = FALSE, switched = FALSE, done7b = integer(0))
    if (!is.na(ac$acq_from)) {
      acq[[a]] <- list(ak = z, sum = z, exc = rep(FALSE, n), ded = z, queue = list(),
                       expl = z, flag = rep(FALSE, n))
    }
  }
  state$map <- list(terms = terms, defer = acc$defer)
  state$ast <- ast
  state$acq <- acq
  state
}

#' Deterministische Hilfsgrößen der Zuordnung (Register, Maßnahmenklassen, § 3c)
#' @noRd
tax_flat_key_context <- function(keys, reg, cfg) {
  nk <- if (is.null(keys)) 0L else nrow(keys)
  tc <- if (nk > 0L) keys$tax_category else character(0)
  mid <- if (nk > 0L) keys$measure_id else character(0)
  # Maßnahmen mit nur steuerfreien Erlösen (PV § 3 Nr. 72 EStG): Kosten nicht abziehbar (§ 3c)
  ex_m <- unique(mid[!is.na(mid) & tc == "income_tax_exempt"])
  tx_m <- unique(mid[!is.na(mid) & tc %in% c("income_rental", "income_other_taxable")])
  list(keys = keys, nk = nk, tc = tc, mid = mid, reg = reg, exempt = setdiff(ex_m, tx_m),
       expensable = unique(mid[!is.na(mid) & tc == "capex_expensable"]),
       excluded = cfg$acq_excluded)
}

#' Term anlegen bzw. um eine Zeile mit Gewicht erweitern (Akkumulator `acc`)
#' @noRd
tax_flat_add_term <- function(acc, kind, key, w, asset = NA_character_, k = NA_integer_) {
  nm <- paste(c(kind, if (!is.na(asset)) asset, if (!is.na(k)) k), collapse = "|")
  tm <- acc$terms[[nm]] %||% list(kind = kind, asset = asset, k = k, keys = character(0),
                                  w = numeric(0))
  tm$keys <- c(tm$keys, key)
  tm$w <- c(tm$w, w)
  acc$terms[[nm]] <- tm
  invisible(NULL)
}

#' Anlage einer Eingabezeile: asset_id der Zeile, sonst der Maßnahme (Register bzw. Zeilen)
#' @noRd
tax_flat_asset_of <- function(cx, i) {
  a <- cx$keys$asset_id[i]
  if (!is.na(a) && nzchar(a)) return(a)
  m <- cx$mid[i]
  if (is.na(m)) return(NA_character_)
  aid <- cx$reg$measures[[m]]$asset_id
  if (!is.null(aid)) return(aid)
  hit <- cx$keys$asset_id[!is.na(cx$mid) & cx$mid == m & cx$tc == "capex_depreciable" &
                            !is.na(cx$keys$asset_id)]
  if (length(hit) > 0L) hit[1L] else NA_character_
}

#' Feld einer Maßnahme des Registers (oder NA)
#' @noRd
tax_flat_measure_field <- function(cx, m, field) {
  if (is.na(m) || is.null(cx$reg$measures[[m]])) return(NA_character_)
  cx$reg$measures[[m]][[field]] %||% NA_character_
}

#' Hat die Anlage einen Prüfzeitraum anschaffungsnaher HK (Anschaffungsdatum im Register)?
#' @noRd
tax_flat_has_window <- function(cx, a) {
  !is.na(a) && !is.null(cx$reg$assets[[a]]) && !is.null(cx$reg$assets[[a]]$acquisition_date)
}

#' Zählt die Zeile im 15-%-Test (Investition bzw. Ersatz, keine Erweiterung, kein Erwerb)?
#' @noRd
tax_flat_counted <- function(cx, i, a) {
  tax_flat_has_window(cx, a) && cx$keys$category[i] %in% c("capex", "replacement") &&
    !(tax_flat_measure_field(cx, cx$mid[i], "measure_type") %in% cx$excluded)
}

#' Eine Eingabezeile den Termen zuordnen
#' @return `TRUE`, wenn die Zeile ein Restwert ist (Steuer am Horizont möglich).
#' @noRd
tax_flat_map_row <- function(acc, cx, i, cfg) {
  keys <- cx$keys
  key <- keys$key[i]
  tc <- cx$tc[i]
  m <- cx$mid[i]
  share <- tax_flat_extra(keys, i, "use_share_rented")
  share <- if (is.numeric(share) && length(share) == 1L && is.finite(share)) share else 1
  tp <- tax_flat_extra(keys, i, "tax_period")
  ad <- tax_flat_extra(keys, i, "approval_date")
  if ((is.numeric(tp) && length(tp) == 1L && !is.na(tp)) || inherits(ad, "Date")) {
    acc$defer[[key]] <- list(t = if (is.numeric(tp)) as.integer(tp) else NA_integer_,
                             date = if (inherits(ad, "Date")) ad[1L] else as.Date(NA))
  }
  if (identical(keys$source[i], "inst")) {
    cat_i <- keys$category[i]
    if (identical(cat_i, "disagio")) tax_flat_add_term(acc, "disagio", key, 1)
    if (identical(cat_i, "repayment_grant")) {
      tax_flat_map_subsidy(acc, cx, key, tax_flat_asset_of(cx, i), m, cfg)
    }
    return(FALSE)
  }
  if (!is.na(m) && m %in% cx$exempt &&
        tc %in% c("expense_deductible", "capex_expensable", "capex_depreciable",
                  "subsidy_investment", "subsidy_repayment_grant")) {
    return(FALSE)
  }
  switch(tc,
    income_rental = , income_other_taxable = , subsidy_operating = {
      tax_flat_add_term(acc, "inc", key, share)
    },
    expense_deductible = tax_flat_add_term(acc, "exp", key, share),
    interest_expense = tax_flat_add_term(acc, "int_exp", key, share),
    interest_income = tax_flat_add_term(acc, "int_inc", key, 1),
    capex_land = tax_flat_add_term(acc, "land", key, -1),
    capex_expensable = tax_flat_map_expensable(acc, cx, i, key, share, cfg),
    capex_depreciable = , acquisition_ancillary = {
      tax_flat_map_depreciable(acc, cx, i, key, share, cfg)
    },
    subsidy_investment = , subsidy_repayment_grant = {
      tax_flat_map_subsidy(acc, cx, key, tax_flat_asset_of(cx, i), m, cfg)
    },
    NULL
  )
  identical(tc, "disposal_proceeds") && identical(keys$category[i], "residual_value")
}

#' Erhaltungsaufwand zuordnen (Verteilung nach § 82b, Prüfzeitraum anschaffungsnaher HK)
#' @noRd
tax_flat_map_expensable <- function(acc, cx, i, key, share, cfg) {
  a <- tax_flat_asset_of(cx, i)
  k <- tax_flat_extra(cx$keys, i, "spread_years")
  k <- if (utl_is_whole(k)) as.integer(round(k)) else cfg$spread_default
  k <- if (cfg$spread_allowed) min(max(k, 1L), 5L) else 1L
  if (tax_flat_has_window(cx, a) && identical(cfg$acq_mode, "umgliederung")) {
    tax_flat_add_term(acc, "acqE", key, share, asset = a, k = k)
  } else {
    tax_flat_add_term(acc, "mnt", key, share, k = k)
  }
  if (tax_flat_counted(cx, i, a)) {
    tax_flat_add_term(acc, "acqC", key, -1 / (1 + cfg$acq_vat), asset = a)
    tax_flat_add_term(acc, "acqX", key, -1 / (1 + cfg$acq_vat), asset = a)
  }
  invisible(NULL)
}

#' Herstellungs- und Anschaffungskosten zuordnen (Bemessung, Boden, Prüfzeitraum)
#' @noRd
tax_flat_map_depreciable <- function(acc, cx, i, key, share, cfg) {
  tc <- cx$tc[i]
  m <- cx$mid[i]
  a <- tax_flat_asset_of(cx, i)
  if (!is.na(a) && identical(cx$reg$assets[[a]]$asset_type, "grund_boden")) {
    return(tax_flat_add_term(acc, "land", key, -1))
  }
  if (is.na(a)) a <- "ohne_anlage"
  mt <- tax_flat_measure_field(cx, m, "measure_type")
  is_acq <- mt %in% c("erwerb_objekt", "erwerb_grundstueck")
  win <- tax_flat_has_window(cx, a)
  auto <- identical(tc, "capex_depreciable") && win && !is_acq &&
    identical(tax_flat_measure_field(cx, m, "classification"), "auto")
  if (auto) {
    tax_flat_add_term(acc, "acqA", key, share, asset = a)
  } else {
    tax_flat_add_term(acc, "dep", key, -share, asset = a)
  }
  if (win && (is_acq || identical(tc, "acquisition_ancillary"))) {
    tax_flat_add_term(acc, "ak", key, -1, asset = a)
  }
  if (identical(tc, "capex_depreciable") && !is_acq && tax_flat_counted(cx, i, a)) {
    tax_flat_add_term(acc, "acqC", key, -1 / (1 + cfg$acq_vat), asset = a)
  }
  invisible(NULL)
}

#' Zuschuss einer Maßnahme bzw. Anlage zuordnen (R 21.5 EStR, Memo 06 3.1.7)
#'
#' `einnahme`: Einnahme im Zuflussjahr. `minderung`: Zuschuss zu Erhaltungsaufwand als Einnahme
#' im Zuflussjahr (wirkt wie die Minderung des Aufwands), zu Herstellungskosten als Minderung der
#' Bemessungsgrundlage der Anlage; Maßnahmen mit Einordnung `auto` im Prüfzeitraum nach dem
#' Stand der 15-%-Prüfung; ohne zuordenbare Anlage Einnahme. Zuschüsse zu steuerfreien
#' Tätigkeiten (§ 3c) bleiben außer Ansatz.
#' @noRd
tax_flat_map_subsidy <- function(acc, cx, key, a, m, cfg) {
  if (!is.na(m) && m %in% cx$exempt) return(invisible(NULL))
  if (identical(cfg$subsidy, "einnahme")) return(tax_flat_add_term(acc, "sub_inc", key, 1))
  cls <- tax_flat_measure_field(cx, m, "classification")
  erh <- (!is.na(m) && m %in% cx$expensable) || identical(cls, "erhaltung")
  if (erh || is.na(a)) return(tax_flat_add_term(acc, "sub_inc", key, 1))
  if (identical(cls, "auto") && tax_flat_has_window(cx, a)) {
    return(tax_flat_add_term(acc, "subauto", key, 1, asset = a))
  }
  tax_flat_add_term(acc, "sub", key, 1, asset = a)
}

# ---------------------------------------------------------------------------------------------
# Hook-Methoden (Spec 00 10.3)
# ---------------------------------------------------------------------------------------------

#' Konfiguration für die Hook-Methoden: die des Moduls, außer abweichende Parameter
#' @noRd
tax_flat_cfg_for <- function(module, params) {
  if (length(params) == 0L || identical(params, module$params)) return(module$cfg)
  tax_flat_config(params, module$info, tax_flat_legal())
}

#' tax_flat: Anfangszustand je Lauf (Spec 00 10.3, Memo 06 7.7)
#' @exportS3Method tax_init tax_flat
#' @noRd
tax_init.tax_flat <- function(module, params, assets, measures, n_sim) {
  n <- as.integer(n_sim)
  z <- numeric(n)
  list(cfg = tax_flat_cfg_for(module, params), reg = tax_flat_registers(assets, measures),
       map = NULL, n = n, vz = NA_integer_, ytd_e = z, ytd_tax = z, assessed = z, due = z,
       loss = z, land = z, spread = list(), ast = list(), acq = list(), deferred = list(),
       has_rv = FALSE, t0_date = NULL, closed = FALSE, t_last = NA_integer_)
}

#' tax_flat: Steuer der Periode t (Spec 00 10.3-10.5, 10.7)
#' @exportS3Method tax_step tax_flat
#' @noRd
tax_step.tax_flat <- function(module, t, inputs, interest, state, params) {
  n <- tax_n_of(interest)
  if (is.null(state$cfg)) state <- tax_init.tax_flat(module, params, list(), list(), n)
  if (is.null(state$map)) state <- tax_flat_prepare(state, inputs, n)
  cfg <- state$cfg
  z <- numeric(n)
  y <- as.integer(inputs$year)
  months <- as.integer(round(as.double(inputs$delta) * 12))
  last <- inputs$date_end >= as.Date(sprintf("%04d-01-01", y + 1L))
  if (!identical(state$vz, y)) {
    state$vz <- y
    state$ytd_e <- z
    state$ytd_tax <- z
  }
  pay <- z
  if (cfg$lag == 1L) {
    pay <- pay + state$due
    state$due <- z
  }
  sm <- tax_flat_sums(state, inputs, n)
  state <- sm$state
  g <- function(nm) sm$sums[[nm]] %||% z
  # Erhaltungsaufwand: fällige Raten (82b), neue Beträge, Prüfzeitraum anschaffungsnaher HK
  yk <- as.character(y)
  mnt <- z
  if (!is.null(state$spread[[yk]])) {
    mnt <- mnt + state$spread[[yk]]
    state$spread[[yk]] <- NULL
  }
  for (nm in names(sm$sums)) {
    tm <- state$map$terms[[nm]]
    if (!identical(tm$kind, "mnt")) next
    r <- tax_flat_spread(state$spread, sm$sums[[nm]], tm$k, y)
    mnt <- mnt + r$now
    state$spread <- r$queue
  }
  inc_sub <- g("sub_inc")
  reclass <- z
  acq_rep <- z
  acq_cost <- z
  acq_limit <- z
  afa_tot <- z
  sb_tot <- z
  bv_tot <- z
  for (a in names(state$ast)) {
    st <- state$ast[[a]]
    ac <- st$cfg
    add <- g(paste0("dep|", a))
    red <- g(paste0("sub|", a))
    auto_a <- g(paste0("acqA|", a))
    sauto <- g(paste0("subauto|", a))
    if (!is.null(state$acq[[a]])) {
      r <- tax_flat_acquisition(state$acq[[a]], ac, sm$sums, a, inputs, y, cfg)
      state$acq[[a]] <- r$acq
      mnt <- mnt + r$mnt
      add <- add + r$capitalize
      reclass <- reclass + r$reclass
      acq_rep <- acq_rep + r$capitalize
      acq_cost <- acq_cost + r$acq$sum
      acq_limit <- acq_limit + cfg$acq_share * r$acq$ak
      exc <- r$acq$exc
      inwin <- r$inwin
    } else {
      exc <- rep(TRUE, n)
      inwin <- FALSE
    }
    if (!inwin) add <- add - auto_a
    # Zuschuss zu einer Maßnahme mit Einordnung auto: Minderung, solange sie als HK gilt
    if (inwin) {
      red <- red + sauto * exc
      inc_sub <- inc_sub + sauto * !exc
    } else {
      red <- red + sauto
    }
    r <- tax_flat_depreciate(st, ac, add, red, inputs, months, y, last, cfg)
    state$ast[[a]] <- r$st
    inc_sub <- inc_sub + r$excess
    afa_tot <- afa_tot + r$afa
    sb_tot <- sb_tot + r$sb
    bv_tot <- bv_tot + r$st$bv
  }
  state$land <- state$land + g("land")
  # Zinsen (10.7: exo_soll + exo_fees + endo_soll; Disagio sofort, § 11 Abs. 2 S. 4 EStG)
  ip <- function(nm) interest[[nm]] %||% z
  int_exp <- -(ip("exo_soll") + ip("exo_fees") + ip("endo_soll")) + g("disagio") + g("int_exp")
  hz <- ip("endo_haben") + g("int_inc")
  int_inc <- if (identical(cfg$deposit, "ergebnis")) hz else z
  cap_tax <- if (identical(cfg$deposit, "abgeltung")) {
    base <- hz - cfg$allowance * as.double(inputs$delta)
    cfg$capital_rate * (base * (base > 0))
  } else {
    z
  }
  inc <- g("inc")
  expn <- g("exp")
  e <- inc + expn + mnt - afa_tot - sb_tot + int_exp + int_inc + inc_sub + reclass
  # Ertragsteuer je Veranlagungsjahr (Verlustmodus, Deckel des sofortigen Ausgleichs)
  s <- tax_flat_rate_at(cfg$rate, t, y)
  ytd <- state$ytd_e + e
  tax_ytd <- tax_flat_tax(ytd, state$loss, cfg$loss_cap, s)
  assessed <- tax_ytd - state$ytd_tax
  state$ytd_e <- ytd
  state$ytd_tax <- tax_ytd
  if (cfg$lag == 0L) {
    pay <- pay + assessed
  } else {
    state$assessed <- state$assessed + assessed
  }
  if (last) {
    state$loss <- tax_flat_loss_after(ytd, state$loss, cfg$loss_cap)
    if (cfg$lag == 1L) {
      state$due <- state$assessed
      state$assessed <- z
    }
  }
  state$closed <- last
  state$t_last <- as.integer(t)
  pay <- pay + cap_tax
  report <- list(income = inc + inc_sub, expenses = expn, maintenance = mnt,
                 depreciation = -afa_tot, special_depreciation = -sb_tot,
                 interest_expense = int_exp, interest_income = int_inc,
                 reclassification = reclass, taxable_income = e,
                 loss_carryforward = if (last) state$loss else
                   tax_flat_loss_after(ytd, state$loss, cfg$loss_cap),
                 tax_assessed = assessed, capital_income_tax = cap_tax, book_value = bv_tot,
                 acquisition_related = acq_rep, acq_test_costs = acq_cost,
                 acq_test_limit = acq_limit)
  list(payment = pay, state = state, report = report)
}

#' tax_flat: offene Steuer am Horizont (Spec 00 10.5, Memo 06 7.11)
#' @exportS3Method tax_finalize tax_flat
#' @noRd
tax_finalize.tax_flat <- function(module, T, state, terminal_inputs, params) { # nolint
  n <- max(c(1L, length(terminal_inputs$residual_value), state$n %||% 1L))
  z <- numeric(n)
  cfg <- state$cfg %||% tax_flat_cfg_for(module, params)
  if (is.null(state$map)) {
    return(list(payment_T = z, report = list()))
  }
  open <- if (cfg$lag == 1L) state$due + state$assessed else z
  loss <- if (isTRUE(state$closed)) state$loss else
    tax_flat_loss_after(state$ytd_e, state$loss, cfg$loss_cap)
  s <- tax_flat_rate_at(cfg$rate, as.integer(T), state$vz %||% 0L) # nolint
  gain <- z
  gain_tax <- z
  if (tax_flat_rv_taxed(cfg, state, terminal_inputs)) {
    rv <- as.double(terminal_inputs$residual_value %||% 0)
    bv <- z
    for (a in names(state$ast)) bv <- bv + state$ast[[a]]$bv
    pending <- z
    for (q in state$spread) pending <- pending + q
    for (a in names(state$acq)) for (q in state$acq[[a]]$queue) pending <- pending + q
    gain <- rv - bv - state$land - cfg$ebv + pending
    r <- tax_flat_gain_tax(gain, loss, cfg, s)
    gain_tax <- r$tax
    loss <- r$loss
  }
  loss_value <- if (identical(cfg$remaining_loss, "satz")) s * loss else z
  tax_flat_finalize_warnings(module, state, cfg)
  list(payment_T = open + gain_tax - loss_value,
       report = list(terminal_open_tax = open, terminal_gain = gain,
                     terminal_gain_tax = gain_tax, terminal_loss_value = loss_value))
}

# ---------------------------------------------------------------------------------------------
# Rechenbausteine (vektorisiert über n)
# ---------------------------------------------------------------------------------------------

#' Summen der Terme einer Periode (mit Verschiebung nach tax_period bzw. approval_date)
#' @return `list(sums = list(<term> = n-Vektor), state)`.
#' @noRd
tax_flat_sums <- function(state, inputs, n) {
  vals <- c(inputs$exo %||% list(), inputs$inst %||% list())
  defer <- state$map$defer
  for (k in names(defer)) {
    d <- defer[[k]]
    v <- vals[[k]] %||% numeric(n)
    held <- (!is.na(d$t) && inputs$t < d$t) || (!is.na(d$date) && inputs$date_end < d$date)
    if (held) {
      state$deferred[[k]] <- (state$deferred[[k]] %||% numeric(n)) + v
      vals[[k]] <- numeric(n)
    } else if (!is.null(state$deferred[[k]])) {
      vals[[k]] <- v + state$deferred[[k]]
      state$deferred[[k]] <- NULL
    }
  }
  terms <- state$map$terms
  sums <- vector("list", length(terms))
  names(sums) <- names(terms)
  for (nm in names(terms)) {
    tm <- terms[[nm]]
    acc <- numeric(n)
    for (i in seq_along(tm$keys)) {
      v <- vals[[tm$keys[i]]]
      if (!is.null(v)) acc <- acc + tm$w[i] * v
    }
    sums[[nm]] <- acc
  }
  list(sums = sums, state = state)
}

#' Erhaltungsaufwand verteilen (§ 82b EStDV): Anteil 1/k im Jahr y, Rest in y+1 ... y+k-1
#' @param queue Liste Jahr -> n-Vektor (fällige Abzüge, negativ).
#' @param x Aufwand der Periode (negativ).
#' @return `list(now, queue)`.
#' @noRd
tax_flat_spread <- function(queue, x, k, y) {
  part <- x / k
  if (k > 1L) {
    for (i in seq_len(k - 1L)) {
      yk <- as.character(y + i)
      queue[[yk]] <- (queue[[yk]] %||% 0) + part
    }
  }
  list(now = part, queue = queue)
}

#' Prüfzeitraum anschaffungsnaher Herstellungskosten (§ 6 Abs. 1 Nr. 1a EStG) je Anlage
#'
#' Im Zeitraum (Anschaffung bis drei Jahre danach) werden Instandsetzungs- und
#' Modernisierungsaufwand netto (`acqC`) und die Anschaffungskosten (`ak`) je Lauf summiert;
#' Überschreitung der 15-%-Grenze (Maske je Lauf) gliedert Aufwand der Maßnahmen mit Einordnung
#' `auto` (und im Modus `umgliederung` auch Erhaltung) in Herstellungskosten um: bisherige Abzüge
#' werden zurückgenommen (Einkünfteerhöhung in der Periode der Überschreitung), offene Raten
#' entfallen, die Beträge erhöhen die Bemessungsgrundlage. Außerhalb des Zeitraums gilt Erhaltung
#' als Erhaltung (mit Verteilung) und `auto` als Herstellungskosten.
#' @return `list(acq, mnt, capitalize, reclass, inwin)`.
#' @noRd
tax_flat_acquisition <- function(acq, ac, sums, a, inputs, y, cfg) {
  n <- length(acq$ak)
  z <- numeric(n)
  g <- function(nm) sums[[nm]] %||% z
  inwin <- inputs$date_end >= ac$acq_from && inputs$date_end <= ac$acq_to
  mnt <- z
  capitalize <- z
  reclass <- z
  # fällige Raten aus dem Prüfzeitraum (vorläufig abgezogen)
  yk <- as.character(y)
  if (!is.null(acq$queue[[yk]])) {
    mnt <- mnt + acq$queue[[yk]]
    acq$ded <- acq$ded - acq$queue[[yk]]
    acq$queue[[yk]] <- NULL
  }
  acq$ak <- acq$ak + g(paste0("ak|", a))
  subj <- list()
  for (nm in names(sums)) {
    if (startsWith(nm, paste0("acqE|", a, "|"))) {
      subj[[length(subj) + 1L]] <- list(x = sums[[nm]],
                                        k = as.integer(sub("^.*\\|", "", nm)))
    }
  }
  x_auto <- g(paste0("acqA|", a))
  if (inwin) {
    acq$sum <- acq$sum + g(paste0("acqC|", a))
    acq$expl <- acq$expl + g(paste0("acqX|", a))
    now <- (acq$sum > cfg$acq_share * acq$ak) & (acq$ak > 0)
    new <- now & !acq$exc
    acq$exc <- acq$exc | now
    acq$flag <- acq$flag | (acq$exc & acq$expl > 0)
    keep <- !acq$exc
    # Beträge der Periode: überschritten -> Herstellungskosten, sonst vorläufig Erhaltung
    capitalize <- capitalize - x_auto * acq$exc
    part <- x_auto * keep
    mnt <- mnt + part
    acq$ded <- acq$ded - part
    for (sj in subj) {
      capitalize <- capitalize - sj$x * acq$exc
      r <- tax_flat_spread(acq$queue, sj$x * keep, sj$k, y)
      mnt <- mnt + r$now
      acq$ded <- acq$ded - r$now
      acq$queue <- r$queue
    }
    # neu überschritten: frühere vorläufige Abzüge zurücknehmen, offene Raten aktivieren
    pending <- z
    for (q in acq$queue) pending <- pending - q
    reclass <- acq$ded * new
    capitalize <- capitalize + (acq$ded + pending) * new
    acq$ded <- acq$ded * !new
    for (qk in names(acq$queue)) acq$queue[[qk]] <- acq$queue[[qk]] * !new
  } else {
    for (sj in subj) {
      r <- tax_flat_spread(acq$queue, sj$x, sj$k, y)
      mnt <- mnt + r$now
      acq$queue <- r$queue
    }
  }
  list(acq = acq, mnt = mnt, capitalize = capitalize, reclass = reclass, inwin = inwin)
}

#' AfA einer Anlage in der Periode (§ 7 Abs. 4, Abs. 5a, § 7b, § 7a Abs. 9)
#'
#' Zugänge (`add`) und Zuschussminderungen (`red`) wirken ab der Periode ihrer Buchung auf
#' Bemessungsgrundlage und Restbuchwert (nachträgliche HK wie zu Jahresbeginn, R 7.4 Abs. 9
#' EStR); übersteigt eine Minderung den Restbuchwert, ist der Überhang Einnahme (`excess`).
#' Linear: Satz x Bemessungsgrundlage x Monate/12, höchstens der Restbuchwert; degressiv: Satz x
#' Restbuchwert x Monate/12; nach dem Wechsel (`degressive_switch_year`) bzw. nach Ablauf des
#' § 7b-Zeitraums Satz nach Abs. 4 x Restwert (fester Jahresbetrag). § 7b: 5 % der Basis
#' (höchstens 4.000 EUR/m²) im Jahr der Fertigstellung und den drei Folgejahren, ohne pro rata,
#' nur in Läufen mit Baukosten bis 5.200 EUR/m² (Maske).
#' @return `list(st, afa, sb, excess)`.
#' @noRd
tax_flat_depreciate <- function(st, ac, add, red, inputs, months, y, last, cfg) {
  dep <- cfg$dep
  delta <- add - red
  st$base <- st$base + delta
  st$bv <- st$bv + delta
  excess <- -st$bv
  excess <- excess * (excess > 0)
  st$bv <- st$bv + excess
  st$base <- st$base * (st$base > 0)
  if (st$reset) st$lin <- st$lin + ac$rate_lin * delta
  mi <- tax_flat_months_in(ac$ism, inputs$date_end, months)
  afa <- 0 * st$bv
  sb <- afa
  if (mi > 0L && !identical(ac$method, "none")) {
    f <- mi / 12
    amount <- if (st$reset) {
      st$lin * f
    } else if (identical(ac$method, "degressiv")) {
      ac$rate_deg * st$bv * f
    } else {
      ac$rate_lin * st$base * f
    }
    amount <- amount * (amount > 0)
    afa <- pmin(amount, st$bv)
    if (ac$s7b && y %in% ac$s7b_years && !(y %in% st$done7b)) {
      basis <- st$base
      elig <- rep(TRUE, length(basis))
      if (!is.na(ac$area)) {
        basis <- pmin(basis, dep$s7b_basis_cap * ac$area)
        elig <- st$base <= dep$s7b_cost_cap * ac$area
      }
      room <- st$bv - afa
      sb <- pmin(dep$s7b_rate * basis * elig, room * (room > 0))
      st$used7b <- st$used7b | (sb > 0)
      st$done7b <- c(st$done7b, y)
    }
    st$bv <- st$bv - afa - sb
    st$cum <- st$cum + afa + sb
  }
  # Ablauf des § 7b-Zeitraums (lineare AfA vom Restwert, § 7a Abs. 9) bzw. Wechsel von der
  # degressiven zur linearen AfA (§ 7 Abs. 5a S. 4): nur zum Jahresende, Termine deterministisch
  if (last && !st$reset) {
    end7b <- ac$s7b && length(ac$s7b_years) > 0L && y >= max(ac$s7b_years) &&
      identical(ac$method, "linear")
    switch_now <- identical(ac$method, "degressiv") && !is.null(cfg$switch_year) &&
      !is.na(ac$y0) && (y - ac$y0 + 1L) >= cfg$switch_year
    if (end7b) {
      st$lin <- ifelse(st$used7b, ac$rate_lin * st$bv, ac$rate_lin * st$base)
      st$reset <- TRUE
    } else if (switch_now) {
      st$lin <- ac$rate_lin * st$bv
      st$reset <- TRUE
      st$switched <- TRUE
    }
  }
  list(st = st, afa = afa, sb = sb, excess = excess)
}

#' Steuer des Veranlagungsjahres bis t (Verlustmodus, Deckel C des sofortigen Ausgleichs)
#'
#' C = Inf: sofortiger Verlustausgleich ohne Grenze (s x E). Endliches C (übriges Einkommen
#' bzw. 0 im Modus vortrag): Steuer = s x (max(max(C + E, 0) - L, 0) - C), d. h. Ausgleich mit
#' anderen Einkünften bis C, Vortrag L vorrangig, Erstattung höchstens s x C.
#' @noRd
tax_flat_tax <- function(e, loss, cap, s) {
  if (is.infinite(cap)) return(s * e)
  pos <- cap + e
  pos <- pos * (pos > 0)
  x <- pos - loss
  s * (x * (x > 0) - cap)
}

#' Verlustvortrag nach dem Veranlagungsjahr: L - min(L, max(C + E, 0)) + max(-(C + E), 0)
#' @noRd
tax_flat_loss_after <- function(e, loss, cap) {
  if (is.infinite(cap)) return(loss)
  v <- cap + e
  pos <- v * (v > 0)
  loss - pmin(loss, pos) + (pos - v)
}

#' Wird der Restwert am Horizont besteuert? (Memo 06 6.2, 7.11; deterministisch)
#'
#' Nur mit Restwertzeilen und Restwertmethode != zero; `ja`/`nein` ausdrücklich; `auto`:
#' Unternehmen stets, privat innerhalb der Frist des § 23 EStG (Beginn `holding_start`, sonst
#' frühestes Anschaffungsdatum im Register, sonst früheste Inbetriebnahme eines Gebäudes, sonst
#' Stichtag).
#' @noRd
tax_flat_rv_taxed <- function(cfg, state, terminal_inputs) {
  if (!isTRUE(state$has_rv) || identical(cfg$rv_method, "zero") ||
        identical(cfg$rv_mode, "nein")) {
    return(FALSE)
  }
  if (identical(cfg$rv_mode, "ja") || cfg$company) return(TRUE)
  start <- cfg$holding_start
  assets <- state$reg$assets
  if (is.null(start)) {
    acq <- Filter(Negate(is.null), lapply(assets, function(a) a$acquisition_date))
    if (length(acq) > 0L) start <- do.call(min, unname(acq))
  }
  if (is.null(start)) {
    bld <- Filter(function(a) a$asset_type %in% c("gebaeude_wohnen", "gebaeude_nichtwohnen"),
                  assets)
    isd <- lapply(bld, function(a) a$in_service_date)
    if (length(isd) > 0L) start <- do.call(min, unname(isd))
  }
  if (is.null(start)) start <- state$t0_date
  end <- terminal_inputs$horizon_date
  if (is.null(start) || is.null(end)) return(FALSE)
  end < grid_add_months(start, 12L * cfg$holding_years)
}

#' Steuer auf den Gewinn am Horizont (Verlustvortrag vorrangig)
#'
#' Privat (§ 23): nur Gewinne (Verluste nicht ausgleichsfähig). Unternehmen: Verlust bei
#' sofortigem Ausgleich ohne Deckel erstattet, sonst Vortrag.
#' @return `list(tax, loss)`.
#' @noRd
tax_flat_gain_tax <- function(gain, loss, cfg, s) {
  pos <- gain * (gain > 0)
  used <- pmin(loss, pos)
  tax <- s * (pos - used)
  loss <- loss - used
  if (cfg$company) {
    neg <- pos - gain
    if (is.infinite(cfg$loss_cap)) tax <- tax - s * neg else loss <- loss + neg
  }
  list(tax = tax, loss = loss)
}

#' Zusammengefasste Warnungen eines Modells (je Modell höchstens einmal)
#' @noRd
tax_flat_finalize_warnings <- function(module, state, cfg) {
  once <- module$once
  if (!is.environment(once) || isTRUE(once$acq)) return(invisible(NULL))
  flags <- lapply(state$acq, function(q) q$flag)
  if (length(flags) == 0L) return(invisible(NULL))
  hit <- Reduce(`|`, flags)
  if (identical(cfg$acq_mode, "pruefung") && any(hit)) {
    once$acq <- TRUE
    vofi_warn("types.tax.flat.msg.acq_exceeded", share = mean(hit), limit = cfg$acq_share,
              .class = "vofi_warning_plausibility")
  }
  invisible(NULL)
}
