# Parameter-DSL, Feldkatalog der Szenarioblöcke und JSON-Schema (WS-B, Spec 00 Abschnitte 4.2-4.3,
# 4.11, 5.4; Feldtabellen Spec 01 Teile A-C, R-106).
#
# Der Feldkatalog beschreibt jeden Block und jedes Sammlungselement als benannte Liste von
# vofi_param()-Objekten. Validierungsangaben, die die DSL nicht kennt, stehen im Feld `extra`
# (Argumente `...` von vofi_param()):
#   excl_min, excl_max  Grenze min bzw. max ausschliesslich (E bei Gleichheit)
#   warn                c(lo, hi): W ausserhalb [lo, hi] (Plausibilitaet, Ebene 4)
#   warn_domain         Warnbereich nur in Szenarien mit Domaenenbloecken (nicht in reinen
#                       Komponentenszenarien wie Orakeln und Lehrbuchbeispielen, Spec 00 4.2 Fn. 1)
#   allowed             zulaessige Werte (E), warn_allowed zulaessige Werte (W)
#   whole               ganzzahlige Werte verlangt
#   id, max_len         Zeichenkette nach dem id-Muster (4.4 Nr. 2) mit Hoechstlaenge
#   pattern             regulaerer Ausdruck fuer Zeichenketten bzw. Elemente von ids
#   items               Vokabular der Elemente einer Code-Liste (Art ids), z. B. "vocab:reform"
#   ref_ids             Sammlung, deren ids eine Zeichenkette bzw. Liste bezeichnet (Ebene 3)
#   token               zusaetzlich zulaessige Token (z. B. "auto", "default")
#   free                freie Map: Schluessel beliebig (bzw. nach keys), Werte nach fields$.key
#   keys                Vokabular der Schluessel einer freien Map
#   sequence            Sequenz von Maps mit den Feldern fields
#   missing_code        eigener Meldungsschluessel fuer ein fehlendes Pflichtfeld
#   max_chars           W bei laengeren Zeichenketten
# Die Sicht val_domain_schema() (ohne Sammlungselemente, freie Maps und Sequenzen) nutzen die
# Normalisierung (WS-A, scn_normalize_block()) und die Existenzpruefung der Varianten (R-112).

#' Parameterbeschreibung eines Bausteintyps
#'
#' Beschreibt einen Parameter eines Typs der Registry (Parameter-DSL, Spec 00 Abschnitt 5.4).
#' Grenzen, zulässige Formen (`shapes`) und der Stochastik-Hinweis haben artabhängige Defaults.
#' `deterministic_only = TRUE` ist die harte Sperre gegen Overlay-, Kurzform- und Designziele; sie
#' gilt implizit für die Arten `integer`, `enum`, `logical`, `date`, `string`, `timing`, `ref` und
#' `ids`. `stochastic` ist nur ein Hinweis (Excel-Vorlage, Regler, Vorschläge). Weitere benannte
#' Angaben (`...`) stehen im Feld `extra`; die Validierung wertet u. a. `excl_min`, `excl_max`
#' (ausschließliche Grenzen), `warn` (Plausibilitätsbereich `c(lo, hi)`) und `allowed`
#' (zulässige Werte) aus.
#'
#' @param kind Art: `"number"`, `"amount"`, `"rate"`, `"share"`, `"value"`, `"integer"`,
#'   `"enum"`, `"logical"`, `"date"`, `"string"`, `"timing"`, `"schedule"`, `"ref"`, `"ids"`
#'   oder `"map"`.
#' @param ... weitere artspezifische Angaben (Feld `extra`).
#' @param default Default (Schicht 0) in Eingabeform wie in YAML.
#' @param required Pflichtparameter.
#' @param min,max Grenzen (Defaults: `amount` ab `-Inf`, `rate` in `[-0.1, 1]`, `share` in
#'   `[0, 1]`).
#' @param unit Einheit aus `inst/vocab/units.yaml`.
#' @param stochastic Hinweis „üblicherweise unsicher“ (Default artabhängig).
#' @param values bei `enum`: zulässige Codes (Vektor oder `"vocab:<enum>"`).
#' @param allow_auto erlaubt `auto` und `topup` (nur Art `amount`).
#' @param shapes zulässige Formen `"scalar"` und/oder `"path"` (Default artabhängig).
#' @param deterministic_only harte Sperre gegen stochastische Ziele.
#' @param fields bei `map`: benannte Liste von `vofi_param()`-Objekten.
#' @return Objekt der Klasse `vofi_param`.
#' @family Erweitern
#' @examples
#' vofi_param("rate", required = TRUE, unit = "rate_pa")
#' vofi_param("enum", values = "vocab:refi_rule", default = "keep_term")
#' vofi_param("number", min = 0, excl_min = TRUE, warn = c(5, 80), unit = "years")
#' @export
vofi_param <- function(kind, ..., default = NULL, required = FALSE, min = NULL, max = NULL,
                       unit = NULL, stochastic = NULL, values = NULL, allow_auto = FALSE,
                       shapes = NULL, deterministic_only = FALSE, fields = NULL) {
  kinds <- c("number", "amount", "rate", "share", "value", "integer", "enum", "logical",
             "date", "string", "timing", "schedule", "ref", "ids", "map")
  if (!utl_is_string(kind) || !(kind %in% kinds)) {
    vofi_abort("core.registry.param_kind", kind = utl_collapse(format(kind)),
               suggestion = utl_suggest_text(as.character(kind)[1L], kinds),
               .class = "vofi_error_registry")
  }
  numeric_kinds <- c("number", "amount", "rate", "share", "value", "schedule")
  hard_kinds <- c("integer", "enum", "logical", "date", "string", "timing", "ref", "ids")
  if (!utl_is_flag(required)) {
    vofi_abort("core.registry.param_flag", field = "required", .class = "vofi_error_registry")
  }
  if (!utl_is_flag(allow_auto)) {
    vofi_abort("core.registry.param_flag", field = "allow_auto", .class = "vofi_error_registry")
  }
  if (allow_auto && kind != "amount") {
    vofi_abort("core.registry.param_auto", kind = kind, .class = "vofi_error_registry")
  }
  if (!utl_is_flag(deterministic_only)) {
    vofi_abort("core.registry.param_flag", field = "deterministic_only",
               .class = "vofi_error_registry")
  }
  if (kind == "amount" && is.null(min)) min <- -Inf
  if (kind == "rate") {
    if (is.null(min)) min <- -0.1
    if (is.null(max)) max <- 1
  }
  if (kind == "share") {
    if (is.null(min)) min <- 0
    if (is.null(max)) max <- 1
  }
  for (b in list(min, max)) {
    if (!is.null(b) && (!is.numeric(b) || length(b) != 1L || is.na(b))) {
      vofi_abort("core.registry.param_bounds", .class = "vofi_error_registry")
    }
  }
  if (!is.null(min) && !is.null(max) && min > max) {
    vofi_abort("core.registry.param_bounds", .class = "vofi_error_registry")
  }
  if (is.null(shapes)) {
    shapes <- switch(kind,
      number = , amount = , rate = , share = , integer = "scalar",
      value = c("scalar", "path"),
      schedule = "path",
      NULL
    )
  } else if (!is.character(shapes) || !all(shapes %in% c("scalar", "path"))) {
    vofi_abort("core.registry.param_shapes", .class = "vofi_error_registry")
  }
  if (is.null(stochastic)) {
    stochastic <- if (kind %in% numeric_kinds) TRUE else if (kind == "map") NA else FALSE
  } else if (!is.logical(stochastic) || length(stochastic) != 1L) {
    vofi_abort("core.registry.param_flag", field = "stochastic", .class = "vofi_error_registry")
  }
  if (kind %in% hard_kinds) deterministic_only <- TRUE
  if (kind == "enum") {
    if (!is.character(values) || length(values) == 0L || anyNA(values)) {
      vofi_abort("core.registry.param_values", .class = "vofi_error_registry")
    }
  } else if (!is.null(values)) {
    vofi_abort("core.registry.param_values", .class = "vofi_error_registry")
  }
  if (kind == "map") {
    if (!is.list(fields) || length(fields) == 0L || is.null(names(fields)) ||
          !all(vapply(fields, inherits, logical(1), "vofi_param"))) {
      vofi_abort("core.registry.param_fields", .class = "vofi_error_registry")
    }
  } else if (!is.null(fields)) {
    vofi_abort("core.registry.param_fields", .class = "vofi_error_registry")
  }
  if (!is.null(unit) && (!utl_is_string(unit) || !vocab_has("units", unit))) {
    vofi_abort("core.registry.param_unit", unit = utl_collapse(format(unit)),
               .class = "vofi_error_registry")
  }
  structure(list(kind = kind, default = default, required = required, min = min, max = max,
                 unit = unit, stochastic = stochastic, values = values, allow_auto = allow_auto,
                 shapes = shapes, deterministic_only = deterministic_only, fields = fields,
                 extra = list(...)),
            class = "vofi_param")
}

#' Codes eines enum-Parameters
#' @param p `vofi_param` der Art `enum`.
#' @return Zeichenvektor.
#' @noRd
utl_param_codes <- function(p) {
  if (length(p$values) == 1L && startsWith(p$values, "vocab:")) {
    return(vocab_codes(p$values))
  }
  p$values
}

#' Aliase eines enum-Parameters (Eingabe-Normalisierung, 2.11)
#' @noRd
val_param_aliases <- function(p) {
  if (length(p$values) == 1L && startsWith(p$values, "vocab:")) {
    spec <- tryCatch(utl_vocab_spec(p$values), error = function(e) NULL)
    return(names(spec$aliases) %||% character(0))
  }
  character(0)
}

# ---------------------------------------------------------------------------------------------
# Feldkatalog (Spec 00 4.3; Spec 01 Teil A 1, 3-6; Teil B 1-4; Teil C 1, 4.1)
# ---------------------------------------------------------------------------------------------

val_schema_state <- new.env(parent = emptyenv())

#' Vollständiger Feldkatalog
#'
#' Schlüssel sind Blocknamen (`project`, `building`, ...), Elementpfade der Sammlungen ohne ids
#' (`measures`, `building.elements`, `unit_groups`, `funding`, `energy.carriers`,
#' `energy.stages`) und Einträge der Sonderblöcke (`stochastic.settings`,
#' `stochastic.parameters`, `stochastic.processes`, `stochastic.correlations`, `variants`,
#' `scenario_sets`).
#' @return benannte Liste (Schlüssel -> benannte Liste von `vofi_param`).
#' @noRd
val_schema_catalog <- function() {
  if (is.null(val_schema_state$catalog)) val_schema_state$catalog <- val_build_catalog()
  val_schema_state$catalog
}

#' Sammlungselemente des Katalogs (Elementpfade ohne ids)
#' @noRd
val_schema_collections <- function() {
  c("measures", "building.elements", "unit_groups", "funding", "energy.carriers",
    "energy.stages")
}

#' Parameterschema der Felder eines Blocks (Sicht für Normalisierung und Varianten)
#'
#' Ohne Argument: alle Blöcke ohne Sammlungselemente; freie Maps und Sequenzen sind entfernt,
#' weil sie keine feste Feldliste haben (die Normalisierung behandelt sie allgemein). Mit
#' Argument: der Eintrag des Katalogs (auch Sammlungselemente, z. B. `"measures"`), ebenfalls ohne
#' freie Maps und Sequenzen.
#' @param block Name des Blocks bzw. `"stochastic.settings"`, `"measures"`, ...
#' @return benannte Liste von `vofi_param` (leer, wenn der Block kein Schema hat).
#' @noRd
val_domain_schema <- function(block = NULL) {
  if (is.null(val_schema_state$view)) {
    cat <- val_schema_catalog()
    view <- lapply(cat, val_schema_strip)
    val_schema_state$view <- view
  }
  view <- val_schema_state$view
  if (is.null(block)) {
    keep <- setdiff(names(view), c(val_schema_collections(), "stochastic.parameters",
                                   "stochastic.processes", "stochastic.correlations",
                                   "variants", "scenario_sets"))
    return(view[keep])
  }
  view[[block]] %||% list()
}

#' Freie Maps und Sequenzen aus einer Feldliste entfernen (rekursiv)
#' @noRd
val_schema_strip <- function(fields) {
  out <- list()
  for (f in names(fields)) {
    p <- fields[[f]]
    if (isTRUE(p$extra[["free"]]) || isTRUE(p$extra[["sequence"]])) next
    if (identical(p$kind, "map")) {
      sub <- val_schema_strip(p$fields)
      if (length(sub) == 0L) next
      p$fields <- sub
    }
    out[[f]] <- p
  }
  out
}

#' Katalog aufbauen
#' @noRd
val_build_catalog <- function() {
  p <- vofi_param
  enum <- function(v, ...) p("enum", values = paste0("vocab:", v), ...)
  codes <- function(values, ...) p("enum", values = values, ...)
  num <- function(...) p("number", ...)
  amt <- function(...) p("amount", ...)
  shr <- function(...) p("share", ...)
  rte <- function(...) p("rate", ...)
  val <- function(...) p("value", ...)
  int <- function(...) p("integer", ...)
  lgl <- function(...) p("logical", ...)
  dat <- function(...) p("date", ...)
  tim <- function(...) p("timing", ...)
  str <- function(...) p("string", ...)
  ids <- function(...) p("ids", ...)
  map <- function(fields, ...) p("map", fields = fields, ...)
  free <- function(leaf, ...) p("map", fields = list(.key = leaf), free = TRUE, ...)
  anymap <- function(...) p("map", fields = list(.key = p("string")), free = TRUE, any = TRUE,
                            ...)
  sqn <- function(fields, ...) p("map", fields = fields, sequence = TRUE, ...)
  vshare <- function(...) val(min = 0, max = 1, ...)
  vrate <- function(...) val(min = -0.1, max = 1, ...)
  vnonneg <- function(...) val(min = 0, ...)
  year <- function(...) int(unit = "year", ...)
  kg_codes <- c(100, 200, 300, 400, 500, 600, 700)
  meas_codes <- vocab_codes("measure_types")
  asset_codes <- vocab_codes("asset_types")
  vat_set <- c(0, 0.07, 0.19)

  state <- list(
    start_event = tim(), measure = str(ref_ids = "measures"),
    consumption_basis = enum("consumption_basis"),
    consumption_kwh = free(vnonneg(unit = "kWh_pa"), ref_ids = "energy.carriers"),
    demand_kwh = vnonneg(unit = "kWh_pa"),
    carrier_shares = free(vshare(), ref_ids = "energy.carriers"),
    heating_carrier = str(ref_ids = "energy.carriers"),
    efficiency = val(min = 0, excl_min = TRUE),
    efficiency_by_carrier = free(val(min = 0, excl_min = TRUE), ref_ids = "energy.carriers"),
    jaz = val(min = 0, excl_min = TRUE, warn = c(2, 5)),
    jaz_plan = num(deterministic_only = TRUE, min = 0, excl_min = TRUE, stochastic = FALSE),
    heat_pump_carrier = str(ref_ids = "energy.carriers"),
    flow_temperature_c = num(deterministic_only = TRUE, stochastic = FALSE),
    installation_date = dat(), section43 = lgl(), emergency_replacement = lgl(),
    service_eur_pa = vnonneg(unit = "EUR_pa"), efficiency_degradation_pa = vrate(),
    extra_consumption = free(map(list(carrier = str(ref_ids = "energy.carriers"),
                                      kwh_pa = vnonneg(unit = "kWh_pa"), label = str()))),
    label = str()
  )

  levy_entry <- map(list(effective_date = dat(), eur_m2_month = num(min = 0),
                         heating = lgl(), procedure = enum("levy_procedure")))

  list(
    meta = list(
      scenario_id = str(required = TRUE, id = TRUE, max_len = 40L), version = str(),
      project_id = str(id = TRUE, max_len = 40L),
      title = str(required = TRUE, max_chars = 120L), author = str(),
      description = str(), created_date = dat(), tags = ids(pattern = "^[a-z][a-z0-9_]*$")
    ),
    project = list(
      perspective = enum("perspective", required = TRUE), tax_regime = enum("tax_regime"),
      project_type = enum("project_type", required = TRUE),
      comparison_mode = enum("comparison_mode"),
      valuation_date = dat(required = TRUE),
      horizon_years = int(max = 100L, warn = c(10, 60), warn_domain = TRUE,
                          unit = "years"),
      application_date = dat(), legal_state = dat(),
      pending_reforms = ids(items = "vocab:reform"),
      federal_state = enum("federal_state"),
      municipality = map(list(mietpreisbremse_area = lgl(), mietpreisbremse_until = dat(),
                              kappung_15_area = lgl(), index_cap_area = lgl(),
                              milieuschutz = lgl())),
      price_base_year = int(min = 1990L, unit = "year"),
      construction_delay_months = num(min = 0, warn = c(0, 36), unit = "months"),
      construction_cost_factor = num(min = 0, excl_min = TRUE, warn = c(0.8, 2),
                                     unit = "factor"),
      reference_variant = str(), report_mode = enum("report_mode")
    ),
    grid = list(
      construction_months = int(min = 0L, unit = "months"),
      construction_step_months = int(allowed = c(1, 3, 6, 12), unit = "months"),
      operation_step_months = int(allowed = 12, unit = "months"),
      operation_alignment = enum("operation_alignment"),
      periods_months = int(min = 1L, unit = "months")
    ),
    building = list(
      building_id = str(id = TRUE, max_len = 20L), label = str(),
      building_type = enum("building_type"), construction_year = year(),
      first_occupancy_year = year(), fictitious_construction_year = year(),
      n_units = int(min = 1L, unit = "count"),
      living_area_m2 = num(min = 0, excl_min = TRUE, unit = "m2"),
      net_floor_area_m2 = num(min = 0, excl_min = TRUE, unit = "m2"),
      n_parking = int(min = 0L, unit = "count"),
      component_areas_m2 = free(num(min = 0, unit = "m2"), keys = "vocab:component_area"),
      land_area_m2 = num(min = 0, excl_min = TRUE, unit = "m2"),
      land_value_eur_m2 = val(min = 0, unit = "EUR_m2"),
      land_value_eur = val(unit = "EUR"), market_value_eur = val(min = 0, unit = "EUR"),
      existing_value_eur = val(min = 0, unit = "EUR"),
      modernization_points_before = free(int(min = 0L),
                                         keys = "vocab:modernization_element"),
      commercial_share = shr(),
      maintenance = map(list(
        enabled = lgl(), basis = enum("maintenance_basis"),
        rate_eur_m2_pa = val(min = 0, unit = "EUR_m2_pa"),
        area_m2 = val(min = 0, excl_min = TRUE, unit = "m2"),
        price_base_year = int(min = 1990L, unit = "year"), growth = vrate(),
        start_event = tim(token = "auto"), to = tim(), vat_rate = shr(),
        excludes_explicit_replacements = lgl(),
        iibv = map(list(
          rates_eur_m2_pa = map(list(lt22y = val(min = 0), ge22y = val(min = 0),
                                     ge32y = val(min = 0))),
          adjust_eur_m2_pa = val(), price_base_year = int(min = 1990L),
          reset_by_measures = ids(token = "auto", ref_ids = "measures")
        ))
      )),
      property_tax = map(list(
        amount_eur_pa = val(min = 0, unit = "EUR_pa"),
        assessment_amount_eur = val(min = 0, unit = "EUR"),
        municipal_multiplier = val(min = 0, excl_min = TRUE),
        land_amount_eur_pa = val(min = 0, unit = "EUR_pa"),
        amount_after_completion_eur_pa = val(min = 0, unit = "EUR_pa"),
        after_completion_from = tim(), growth = vrate()
      )),
      elements = free(map(list(label = str())), collection = "building.elements"),
      energy_class_before = enum("energy_class"), energy_class_after = enum("energy_class"),
      efficiency_standard_after = enum("efficiency_standard"), wpb_flag = lgl(),
      denkmal = lgl(), serial_renovation = lgl(), isfp_available = lgl(),
      heating_existing = map(list(carrier = str(ref_ids = "energy.carriers"),
                                  installation_year = year(),
                                  type = enum("heating_system_type"), label = str())),
      consumption_kwh = free(num(min = 0, unit = "kWh_pa"), ref_ids = "energy.carriers")
    ),
    household = list(
      net_income_month_eur = val(min = 0, unit = "EUR_month"), income_growth = vrate(),
      taxable_income_avg_eur = num(min = 0, unit = "EUR_pa"),
      n_children_u18 = int(min = 0L, unit = "count"),
      savings_capacity_month_eur = val(min = 0, unit = "EUR_month"),
      current_rent_month_eur = val(min = 0, unit = "EUR_month"),
      expected_income_tax_eur_pa = val(min = 0, unit = "EUR_pa"),
      savings_eur = val(min = 0, unit = "EUR"),
      contribution_month_eur = val(min = 0, unit = "EUR_month"),
      contribution_from = tim(), contribution_to = tim()
    ),
    measures = list(
      label = str(), measure_type = codes(meas_codes, required = TRUE), description = str(),
      date = dat(), year = year(), payment_schedule = p("schedule"),
      duration_months = int(min = 0L, unit = "months"),
      payment_profile = enum("payment_profile"), completion_date = dat(),
      follows_construction = lgl(), construction_delay_mode = enum("construction_delay_mode"),
      delay_months = num(min = 0, unit = "months"), active = val(min = 0, max = 1),
      cost_eur = amt(min = 0, unit = "EUR"),
      cost_kg = map(list(kg200 = amt(min = 0), kg300 = amt(min = 0), kg400 = amt(min = 0),
                         kg500 = amt(min = 0), kg600 = amt(min = 0), kg700 = amt(min = 0),
                         kg800 = amt(min = 0))),
      kg = int(allowed = c(kg_codes, 800)), kg700_share = shr(),
      kg700_basis = enum("kg700_basis"),
      contingency_share = shr(), contingency_basis = enum("contingency_basis"),
      cost_is_net = lgl(), vat_recoverable = lgl(), vat_rate = shr(warn_allowed = vat_set),
      cost_factor = num(min = 0, excl_min = TRUE, unit = "factor"),
      price_base_year = int(min = 1990L, unit = "year"), price_index = vrate(),
      component_areas_m2 = free(num(min = 0, unit = "m2"), keys = "vocab:component_area"),
      kw = val(min = 0, excl_min = TRUE, unit = "kW"),
      kwp = val(min = 0, excl_min = TRUE, unit = "kWp"),
      kwh = val(min = 0, excl_min = TRUE, unit = "kWh"),
      useful_life_years = num(min = 0, excl_min = TRUE, warn = c(5, 100), unit = "years"),
      replacement = map(list(enabled = lgl(), cost_eur = amt(min = 0), cost_factor = num(min = 0),
                             price_index = vrate(), classification = enum("classification"))),
      ohnehin_share = shr(), ohnehin_cost_eur = amt(min = 0, unit = "EUR"),
      ohnehin_due_date = tim(), ohnehin_due_year = tim(),
      classification = enum("classification"), tax_spread_years = int(min = 1L, max = 5L),
      modernization_kind = enum("modernization_kind"), asset_type = codes(asset_codes),
      asset_id = str(id = TRUE, max_len = 40L),
      replaces_ohnehin = ids(), replaces_elements = ids(ref_ids = "building.elements"),
      funding_choice = enum("funding_choice"), contractor_certified = lgl(),
      paid_in_full_date = dat(),
      effects = map(list(
        start = enum("effect_start"),
        maintenance = map(list(factor = val(min = 0),
                               duration_years = num(min = 0, excl_min = TRUE),
                               reset_age = lgl(), share_of_cost_pa = shr())),
        residual = map(list(modernization_points = free(int(min = 0L),
                                                        keys = "vocab:modernization_element")))
      )),
      rent_law = map(list(
        levy = enum("levy_mode"), procedure = enum("levy_procedure"),
        maintenance_share_method = enum("maintenance_method"),
        maintenance_share = vshare(), fictitious_maintenance_cost_eur = val(min = 0),
        component_age_years = val(min = 0), component_life_years = val(min = 0, excl_min = TRUE),
        heating_part_share = vshare(), section43_heating = lgl(),
        fundable_in_principle = lgl(), hp_state = str(), heat_pump = lgl(),
        hp_exception = enum("hp_exception"), landlord_responsible = lgl(),
        unit_groups = ids(ref_ids = "unit_groups"),
        allocation = free(vshare(), ref_ids = "unit_groups"),
        declaration_date = tim(), levy_effective_date = dat(), announcement_ok = lgl(),
        works_start_date = tim(), works_rent_reduction_share = vshare(),
        works_vacancy_share = vshare(),
        ovm_uplift_eur_m2_month = val(min = 0, warn = c(0, 2), unit = "EUR_m2_month"),
        comprehensive_modernization = lgl()
      )),
      purchase_price_eur = amt(min = 0, unit = "EUR"), land_share = shr(),
      uniform_contract = lgl(), uniform_contract_measures = ids(ref_ids = "measures"),
      grest_rate = rte(min = 0, max = 0.2), notary_share = shr(), land_registry_share = shr(),
      broker_share = shr(warn = c(0, 0.0714)), other_share = shr(), ancillary_date = tim()
    ),
    "building.elements" = list(
      label = str(), measure_type = codes(meas_codes, required = TRUE),
      installed_year = year(),
      useful_life_years = num(min = 0, excl_min = TRUE, warn = c(5, 80), unit = "years"),
      replacement_cost_eur = val(min = 0, required = TRUE, unit = "EUR",
                                 missing_code = "validation.building.element_cost_missing"),
      price_base_year = int(min = 1990L, unit = "year"), price_index = vrate(),
      vat_rate = shr(warn_allowed = vat_set), next_replacement = tim(),
      next_replacement_delay_months = num(min = 0, unit = "months"),
      overdue = enum("overdue_policy"), active = val(min = 0, max = 1),
      kg = int(allowed = kg_codes), asset_type = codes(asset_codes)
    ),
    unit_groups = list(
      label = str(), n_units = int(min = 1L, required = TRUE, unit = "count"),
      living_area_m2 = num(min = 0, excl_min = TRUE, required = TRUE, unit = "m2"),
      owner_occupied = lgl(), rent_regime = enum("rent_regime"),
      rent_eur_m2_month = val(min = 0, excl_min = TRUE, warn = c(0, 30),
                              unit = "EUR_m2_month"),
      rent_start = tim(), rent_end = tim(), rent_growth = vrate(),
      increase_policy = enum("increase_policy"), growth_from = tim(),
      growth_applies_to = enum("growth_applies_to"),
      ovm_eur_m2_month = val(min = 0, unit = "EUR_m2_month"), ovm_base_date = dat(),
      interval_months = int(min = 15L, unit = "months"),
      voluntary_558_cap_share = vshare(),
      voluntary_558_cap_months = int(min = 12L, unit = "months"),
      rent_36m_ago_eur_m2_month = val(min = 0, unit = "EUR_m2_month"),
      last_558_increase_date = dat(),
      levy_history = free(levy_entry),
      market_rent_eur_m2_month = val(min = 0, unit = "EUR_m2_month"),
      market_rent_growth = vrate(), market_rent_base_date = dat(),
      turnover_rate_pa = vshare(warn = c(0, 0.25)),
      relet_vacancy_months = val(min = 0, unit = "months"),
      first_use_after_2014_10_01 = lgl(),
      vacancy_rate = vshare(warn = c(0, 0.15)), rent_default_rate = vshare(),
      extra_loss_share = vshare(),
      lease_up_months = val(min = 0, warn = c(0, 12), unit = "months"),
      staffel_steps = p("schedule"),
      after_staffel_regime = codes(c("paragraph_558", "index")), index_rate = vrate(),
      index_adjust_month = int(min = 1L, max = 12L), bound_increase_pa = vrate(),
      binding_end = tim(), after_binding_regime = codes(c("paragraph_558", "index")),
      post_binding_kappung = lgl(),
      imputed_rent_eur_m2_month = val(min = 0, unit = "EUR_m2_month"),
      imputed_rent_growth = vrate(),
      rent_roll = free(map(list(living_area_m2 = num(min = 0, excl_min = TRUE),
                                rent_eur_m2_month = val(min = 0),
                                rent_36m_ago_eur_m2_month = val(min = 0),
                                last_558_increase_date = dat(),
                                levy_history = free(levy_entry)))),
      operating = map(list(
        admin_per_unit_eur_pa = val(min = 0, warn = c(0, 1000), unit = "EUR_pa"),
        n_parking = int(min = 0L), admin_per_parking_eur_pa = val(min = 0, unit = "EUR_pa"),
        nonrecoverable_share_of_rent = vshare(warn = c(0, 0.05)),
        nonrecoverable_eur_m2_pa = val(min = 0, unit = "EUR_m2_pa"),
        recoverable_opex_eur_m2_month = val(min = 0, warn = c(0, 4), unit = "EUR_m2_month"),
        vacancy_opex_scope = enum("vacancy_opex_scope"), growth = vrate(),
        opex_growth = vrate(), base_date = tim()
      )),
      rent_law = map(list(
        modernization_levy = enum("levy_mode"), voluntary_cap_per_m2 = val(min = 0),
        voluntary_cap_mode = enum("voluntary_cap_mode"), hardship_share = vshare(),
        drittmittel_attribution = enum("third_party_allocation"),
        flat_559e_order = enum("s559e_order"), hp_reduction_order = enum("s559f_order"),
        section43_flat = lgl(), interest_subsidy_in_559e = lgl(),
        hp_threshold_inclusive = lgl(), kappung_rate = val(min = 0, max = 0.2),
        kuerzung_558_5 = lgl(), kuerzung_grant_years = val(min = 0),
        kuerzung_loan_years = val(min = 0), levy_effective_delay_months = int(min = 0L)
      ))
    ),
    energy = list(
      carriers = free(map(list(label = str())), collection = "energy.carriers"),
      before = map(state), after = map(state),
      stages = free(map(list(label = str())), collection = "energy.stages"),
      performance_gap = map(list(prebound_factor = val(min = 0, excl_min = TRUE),
                                 rebound_factor = val(min = 0, excl_min = TRUE,
                                                      warn = c(0.8, 1.6)),
                                 realisation_factor = val(min = 0, warn = c(0.3, 1.2)))),
      co2_landlord_share_reduction = vshare(), co2_hardship_5d = lgl(),
      co2_newbuild_5b = lgl(),
      pv = map(list(
        kwp = val(min = 0, excl_min = TRUE, required = TRUE, warn = c(0, 100), unit = "kWp"),
        measure = str(ref_ids = "measures"), commissioning_date = tim(),
        specific_yield_kwh_kwp = val(min = 0, warn = c(700, 1200)),
        degradation_pa = vrate(), self_consumption_share = vshare(required = TRUE),
        self_consumption_carrier = str(ref_ids = "energy.carriers"),
        feed_in_mode = enum("feed_in_mode"), feed_in_tariff_eur_kwh = val(min = 0),
        tariff_years = int(min = 0L, unit = "years"),
        post_tariff_price_eur_kwh = val(min = 0), internal_price_eur_kwh = val(min = 0),
        opex_share_of_cost = vshare(), opex_eur_pa = val(min = 0, unit = "EUR_pa"),
        tax_exempt = enum("pv_tax_exempt"), vat_zero_rate_attested = lgl()
      ))
    ),
    "energy.carriers" = list(
      class = enum("carrier_class"), price_eur_kwh = val(min = 0, unit = "EUR_kwh"),
      price_includes = enum("price_includes"), price_basis = enum("price_basis"),
      price_growth = vrate(), price_base_date = tim(),
      network_fee_eur_kwh = val(min = 0, unit = "EUR_kwh"), network_fee_growth = vrate(),
      base_fee_eur_pa = val(min = 0, unit = "EUR_pa"), fee_growth = vrate(),
      vat_rate = shr(), emission_factor_kg_kwh = num(min = 0, unit = "kg_kwh"),
      ghg_factor_kg_kwh = val(min = 0, unit = "kg_kwh"),
      co2_price_eur_t = val(min = 0, unit = "EUR_t"),
      bio_premium_eur_kwh = val(min = 0, unit = "EUR_kwh"), label = str()
    ),
    "energy.stages" = state,
    funding = list(
      label = str(), instrument_type = enum("instrument_type", required = TRUE),
      provider = str(), program_code = str(), measures = ids(ref_ids = "measures"),
      unit_groups = ids(ref_ids = "unit_groups"), applicant = enum("applicant"),
      application_date = dat(), approved = val(min = 0, max = 1),
      approval_probability = vshare(), availability_after_2030 = vshare(),
      application_before_start = lgl(), approval_timing = enum("approval_timing"),
      fallback_variant = str(), on_reject = enum("on_reject"),
      payout_delay_months = val(min = 0, unit = "months"),
      payout = map(list(event = enum("payout_event"), lag_months = int(min = 0L))),
      eligibility = map(list(applicants = ids(items = "vocab:applicant"),
                             project_types = ids(items = "vocab:project_type"),
                             measure_types = ids(items = "measure_types"),
                             conditions = anymap(), exclusions = ids())),
      eligibility_override = lgl(), basis = anymap(),
      eligible_shares = free(vshare(), ref_ids = "measures"),
      eligible_cost_eur = val(min = 0, unit = "EUR"),
      rate_components = free(map(list(rate = val(), condition = str(),
                                      schedule_by_taxable_income = anymap(),
                                      threshold = anymap(), mode = enum("bonus_mode"),
                                      min_age_gas_biomass_years = int(min = 0L)),
                                 open = TRUE)),
      rate_cap = map(list(default = val(), exceptions = sqn(list(condition = str(),
                                                                cap = val())))),
      degression = sqn(list(target = str(), start = dat(), step = num(),
                            every_months = int(min = 1L), floor = num())),
      amount_eur = val(min = 0, unit = "EUR"),
      loan = map(list(repayment = enum("repayment"),
                      payments_per_year = int(allowed = c(1, 4, 12)),
                      variants = anymap(), default_variant = str(),
                      term_ranges = anymap(), fees = anymap(),
                      prepay_allowed = lgl(), followup = str(),
                      max_share_of_eligible_costs = shr())),
      loan_variant = str(),
      repayment_grant = map(list(base_rates = free(val()), bonuses = anymap(),
                                 cap_per_unit_basis_eur = val(min = 0),
                                 max_total_share = shr(), payout = anymap(),
                                 effect = enum("repayment_grant_effect"),
                                 class = enum("repayment_grant_class"),
                                 cut_share = vshare())),
      construction_supervision = anymap(),
      construction_support_eur = val(min = 0, unit = "EUR"),
      interest_subsidy = map(list(subsidized_amount_eur = val(min = 0),
                                  rate_reduction_pa = val(min = 0), years = int(min = 1L),
                                  start_event = tim())),
      rent_binding = map(list(rent_eur_m2_month = val(min = 0), increase_pa = val(),
                              years = int(min = 1L))),
      rent_law = map(list(grant_counts_as = enum("grant_counts_as"),
                          loan_counts_as = enum("loan_counts_as"),
                          enables = ids(items = "vocab:bgb_procedure"),
                          reference_rate_pa = val())),
      cumulation = map(list(exclusive_with = ids(), combinable_with = ids(), requires = ids(),
                            max_total_share = shr())),
      budget_risk = map(list(approval_probability = vshare())),
      facts = anymap(), credit = anymap(),
      energy_advice_cost_eur = val(min = 0, unit = "EUR"),
      prior_credit_used_eur = val(min = 0, unit = "EUR")
    ),
    accounts = list(
      deposit_rate_pa = val(min = -0.02, max = 0.15, unit = "rate_pa"),
      overdraft_rate_pa = val(min = 0, max = 0.25, unit = "rate_pa"),
      overdraft_limit_eur = val(min = 0, unit = "EUR"),
      penalty_spread_pa = val(min = 0, unit = "rate_pa"),
      min_liquidity_eur = val(min = 0, unit = "EUR"),
      deposit_withholding_tax_share = shr(warn_allowed = c(0, 0.26375, 0.278186, 0.279951)),
      deposit_tax_allowance_eur_pa = amt(min = 0, warn = c(0, 2000), unit = "EUR_pa"),
      overdraft_flag_threshold_eur = num(min = 0, unit = "EUR"),
      surplus_order = ids(), deficit_order = ids(),
      prepay = map(list(buffer_eur = num(min = 0), min_spread_pa = rte(min = 0)))
    ),
    residual_value = list(
      method = enum("residual_method"), sale_cost_share = shr(warn = c(0, 0.08)),
      path_pre_operation = enum("path_pre_operation"),
      income_value = map(list(
        variant = enum("income_value_variant"),
        cap_rate = val(min = -0.01, excl_min = TRUE, max = 0.12, warn = c(0.015, 0.06)),
        remaining_life_method = enum("remaining_life_method"),
        remaining_life_years = num(min = 0), remaining_life_offset_years = num(),
        gnd_years = num(min = 0, excl_min = TRUE),
        rnd_table = free(map(list(a = num(), b = num(), c = num(), rel_age_min = num()))),
        points_max = free(int(min = 0L), keys = "vocab:modernization_element"),
        points_decay_years = num(min = 0, excl_min = TRUE),
        income_basis = enum("income_basis"), forward_growth = vrate(),
        cost_forward_growth = vrate(), include_other_income = lgl(),
        land_value_eur = val(min = 0), land_value_growth = vrate(),
        bwk = map(list(admin_eur_unit_pa = val(min = 0), maintenance_eur_m2_pa = val(min = 0),
                       rent_loss_share = vshare(), price_base_year = int(min = 1990L),
                       index = vrate(), admin_source = enum("bwk_source"),
                       maintenance_source = enum("bwk_source"),
                       variant_cost_categories = ids(), vacancy_from_ledger = lgl())),
        bog_eur = val(), bog_component_residual = lgl(),
        stranded_discount_share = val(min = 0, max = 1, excl_max = TRUE),
        liquidation_floor = lgl(), demolition_cost_eur = val(min = 0)
      )),
      multiplier = map(list(factor = val(min = 0, excl_min = TRUE, warn = c(10, 35)),
                            basis = enum("multiplier_basis"),
                            income_basis = enum("income_basis"), forward_growth = vrate())),
      exit_yield = map(list(cap_rate = val(min = 0, excl_min = TRUE, warn = c(0.02, 0.08)),
                            income_basis = enum("income_basis"), forward_growth = vrate(),
                            cost_forward_growth = vrate())),
      market_growth = map(list(base_value_eur = val(min = 0), growth = vrate(),
                               uplift_share = val(min = 0))),
      asset_value = map(list(life_basis = enum("life_basis"),
                             gnd_years = num(min = 0, excl_min = TRUE),
                             kg_include = int(allowed = kg_codes[-1L]),
                             include_existing = lgl(),
                             market_adjustment_factor = val(min = 0, excl_min = TRUE),
                             uplift_share = val(min = 0), index = vrate(),
                             land_value_eur = val(min = 0), land_value_growth = vrate())),
      component = map(list(indexed = lgl(), include_land = lgl(),
                           include_existing = enum("include_existing"),
                           existing_growth = vrate())),
      user_value = map(list(value_eur = val(min = 0)))
    ),
    tax = list(module = str(), params = anymap()),
    analysis = list(
      kpis = ids(token = "default"), primary_kpi = enum("primary_kpi"),
      allow_opportunity_reference = lgl(), deterministic_point = enum("deterministic_point"),
      thresholds = map(list(dscr = num(min = 0, excl_min = TRUE), burden_share = shr(),
                            warm_rent_increase_eur_m2 = num(min = 0), roe_hurdle = rte())),
      stabilization_year = year(), lending_value_haircut = shr(),
      rv_path_basis = enum("rv_path_basis"), restrictions = ids(items = "vocab:restriction"),
      traffic_light = map(list(green_prob = shr(), red_prob = shr(), restriction_prob = shr())),
      mandatory_sensitivities = sqn(list(id = str(id = TRUE, max_len = 40L), path = str(),
                                         label = str(), value = val(), delta = num(),
                                         add = str())),
      tenant_view = lgl()
    ),
    "stochastic.settings" = list(
      preset = enum("mc_preset"), n_sim = int(min = 2L),
      seed = int(min = 1L, max = 2147483646L),
      sampling = enum("sampling"), block_size = int(min = 2L), replicates = int(min = 1L),
      antithetic = lgl(), copula = enum("copula"), start_year = int(min = 1990L),
      store = enum("store"), keep_runs = ids(pattern = "^p[0-9]{2}$", unique = TRUE),
      keep_runs_kpi = str(),
      bands = ids(), band_probs = num(min = 0, max = 1, excl_min = TRUE, excl_max = TRUE),
      auto_funding_approval = lgl(),
      convergence = map(list(rel_halfwidth_mean = num(min = 0, max = 1, excl_min = TRUE,
                                                      excl_max = TRUE),
                             abs_halfwidth_prob = num(min = 0, max = 1, excl_min = TRUE,
                                                      excl_max = TRUE)))
    ),
    "stochastic.parameters" = list(
      target = str(required = TRUE), label = str(), description = str(),
      dist = str(required = TRUE), apply = enum("overlay_apply"), base = num(),
      from = str(), use = str()
    ),
    "stochastic.processes" = list(
      target = str(required = TRUE), type = str(required = TRUE), label = str(),
      description = str(), from = str(), use = str()
    ),
    "stochastic.correlations" = list(parameters = sqn(list(key = str())),
                                     shocks = sqn(list(key = str()))),
    variants = list(
      label = str(required = TRUE), description = str(), extends = str(),
      set = anymap(), replace = anymap(), add = anymap(), remove = ids(),
      overrides = anymap()
    ),
    scenario_sets = list(
      label = str(required = TRUE), description = str(), set = anymap(),
      replace = anymap(), add = anymap(), remove = ids(), overrides = anymap(),
      generate = map(list(method = enum("generate_method"), n_drivers = int(min = 1L),
                          probs = num(min = 0, max = 1, excl_min = TRUE, excl_max = TRUE),
                          kpi = str(), params = ids(token = "auto"), exclude = ids()))
    )
  )
}

#' Feldbeschreibung eines Pfads der aufgelösten Spezifikation
#'
#' Sucht den Parameter eines beliebigen Blattpfads: Komponenten- und Finanzierungsparameter
#' über die Typdefinition, Domänenfelder über den Katalog (Sammlungs-ids werden übersprungen,
#' Felder von Maps rekursiv). `market` und `shared` haben kein Schema.
#' @param spec Spezifikation (für den Typ von Komponenten).
#' @param path Blattpfad.
#' @return `vofi_param` oder `NULL`.
#' @noRd
val_param_at <- function(spec, path) {
  segs <- path_split(path)
  if (length(segs) == 0L) return(NULL)
  if (segs[1L] %in% c("components", "financing")) {
    if (length(segs) < 3L) return(NULL)
    comp <- spec[[segs[1L]]][[segs[2L]]]
    def <- if (is.list(comp)) scn_type_def(comp[["type"]], segs[1L]) else NULL
    if (is.null(def)) return(NULL)
    return(val_walk_fields(def$params, segs[-(1:2)]))
  }
  cat <- val_schema_catalog()
  key <- segs[1L]
  i <- 2L
  if (identical(key, "building") && length(segs) >= 3L && identical(segs[2L], "elements")) {
    key <- "building.elements"
    i <- 4L
  } else if (identical(key, "energy") && length(segs) >= 3L &&
               segs[2L] %in% c("carriers", "stages")) {
    key <- paste0("energy.", segs[2L])
    i <- 4L
  } else if (key %in% c("measures", "unit_groups", "funding")) {
    i <- 3L
  } else if (identical(key, "stochastic") && length(segs) >= 2L) {
    key <- paste0("stochastic.", segs[2L])
    i <- if (segs[2L] %in% c("parameters", "processes")) 4L else 3L
  }
  fields <- cat[[key]]
  if (is.null(fields) || length(segs) < i) return(NULL)
  val_walk_fields(fields, segs[i:length(segs)])
}

#' Feldliste entlang von Pfadsegmenten durchlaufen (Maps, freie Maps)
#' @noRd
val_walk_fields <- function(fields, segs) {
  p <- NULL
  for (k in seq_along(segs)) {
    s <- segs[k]
    p <- fields[[s]]
    if (is.null(p) && !is.null(fields[[".key"]])) p <- fields[[".key"]]
    if (!inherits(p, "vofi_param")) return(NULL)
    if (k < length(segs)) {
      if (!identical(p$kind, "map")) return(NULL)
      fields <- p$fields
    }
  }
  p
}

# ---------------------------------------------------------------------------------------------
# JSON-Schema (Memo 05 4.11, Spec 00 2.5: jsonlite in Suggests)
# ---------------------------------------------------------------------------------------------

#' JSON-Schema des Szenarios exportieren
#'
#' Erzeugt das Eingabeschema des Szenarios (Schema v1, Spec 00 Abschnitt 4.2) als JSON-Schema
#' (Draft 2020-12) für Editoren mit YAML-Language-Server (Autovervollständigung und Prüfung von
#' YAML-Szenarien). Grundlage sind der Feldkatalog (Spec 01) und die zum Aufrufzeitpunkt
#' registrierten Typen der Registry: Komponenten (`components`) und Finanzierungsbausteine
#' (`financing`) werden je Typ mit ihren Parametern beschrieben. Die Wertgrammatik (Spec 00
#' Abschnitt 4.5) erscheint als gemeinsame Definition `value`. Das ausgelieferte Schema
#' `inst/schema/vofi-scenario.schema.json` erzeugt `data-raw/build_schema.R`.
#'
#' Die Validierung des Pakets (`vofi_validate()`) prüft mehr als das JSON-Schema (Querbezüge,
#' Plausibilität) und ist allein maßgeblich.
#'
#' @param path Zieldatei oder `NULL` (dann wird das Schema als Zeichenkette zurückgegeben).
#' @return Zeichenkette (JSON) bzw. `invisible(path)`.
#' @family Validieren
#' @examples
#' if (requireNamespace("jsonlite", quietly = TRUE)) {
#'   s <- vofi_json_schema()
#'   substr(s, 1, 60)
#' }
#' @export
vofi_json_schema <- function(path = NULL) {
  if (!is.null(path) && !utl_is_string(path)) {
    vofi_abort("core.arg_scalar", arg = "path", .class = "vofi_error_input")
  }
  utl_require("jsonlite", "vofi_json_schema")
  schema <- val_json_schema_list()
  txt <- as.character(jsonlite::toJSON(schema, auto_unbox = TRUE, pretty = TRUE, null = "null",
                                       digits = NA))
  txt <- enc2utf8(paste0(txt, "\n"))
  if (is.null(path)) return(txt)
  con <- file(path, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(txt), con)
  invisible(path)
}

#' JSON-Schema als R-Liste
#' @noRd
val_json_schema_list <- function() {
  cat <- val_schema_catalog()
  blocks <- list(
    schema_version = list(type = "integer", const = 1L),
    meta = val_json_object(cat$meta),
    project = val_json_object(cat$project),
    grid = val_json_object(cat$grid),
    building = val_json_building(cat),
    household = val_json_object(cat$household),
    unit_groups = val_json_collection(cat$unit_groups),
    measures = val_json_collection(cat$measures),
    energy = val_json_energy(cat),
    funding = val_json_collection(cat$funding, library_ref = TRUE),
    components = val_json_types("components"),
    financing = val_json_types("financing"),
    accounts = val_json_object(cat$accounts),
    market = list(type = "object", additionalProperties = list(`$ref` = "#/$defs/market")),
    residual_value = val_json_object(cat$residual_value),
    tax = val_json_object(cat$tax),
    analysis = val_json_object(cat$analysis),
    stochastic = val_json_stochastic(cat),
    shared = list(type = "object"),
    variants = val_json_collection(cat$variants),
    scenario_sets = val_json_collection(cat$scenario_sets)
  )
  list(
    `$schema` = "https://json-schema.org/draft/2020-12/schema",
    `$id` = "https://vofi.example.org/schema/vofi-scenario.schema.json",
    title = lbl("validation.schema.title"),
    description = lbl("validation.schema.description"),
    type = "object",
    required = c("schema_version", "meta", "project"),
    additionalProperties = FALSE,
    properties = blocks,
    `$defs` = val_json_defs()
  )
}

#' Gemeinsame Definitionen: Wertgrammatik, Bibliotheksverweis, Termine
#' @noRd
val_json_defs <- function() {
  num <- list(type = "number")
  str <- list(type = "string")
  numstr <- list(type = c("number", "string"))
  forms <- list(
    num, list(type = "string", pattern = "^-?[0-9.,_eE+%\\s]+$|^\\.?-?\\.inf$"),
    list(type = "array", items = list(`$ref` = "#/$defs/scalar")),
    list(type = "object", required = list("ref"), additionalProperties = FALSE,
         properties = list(ref = str, scale = num, offset = num, floor = numstr, cap = numstr,
                           anchor = num)),
    list(type = "object", required = list("expr"), additionalProperties = FALSE,
         properties = list(expr = str)),
    list(type = "object", required = list("series"), additionalProperties = FALSE,
         properties = list(series = list(type = "object"),
                           fill = list(enum = vocab_codes("enums:series_fill")),
                           before = list(enum = vocab_codes("enums:series_before")))),
    list(type = "object", required = list("years", "values"), additionalProperties = FALSE,
         properties = list(years = list(type = "array"), values = list(type = "array"),
                           interpolate = list(enum = vocab_codes("enums:interpolate")))),
    list(type = "object", required = list("schedule"), additionalProperties = FALSE,
         properties = list(schedule = list(type = "object"),
                           unit = list(enum = vocab_codes("enums:schedule_unit")))),
    list(type = "object", required = list("start", "growth"), additionalProperties = FALSE,
         properties = list(start = list(`$ref` = "#/$defs/scalar"),
                           growth = list(`$ref` = "#/$defs/value"),
                           base_date = list(`$ref` = "#/$defs/timing"),
                           real = list(type = "boolean"),
                           index = list(enum = vocab_codes("enums:growth_index")))),
    list(type = "object", required = list("value", "per"), additionalProperties = FALSE,
         properties = list(value = list(`$ref` = "#/$defs/value"), per = str)),
    list(type = "object", required = list("dist")),
    list(`$ref` = "#/$defs/library_ref")
  )
  list(
    scalar = list(anyOf = list(num, str, list(type = "object"))),
    value = list(anyOf = forms),
    amount_auto = list(anyOf = list(list(`$ref` = "#/$defs/value"),
                                    list(enum = vocab_codes("enums:auto_mode")))),
    timing = list(anyOf = list(list(type = "string", format = "date"),
                               list(type = "integer", minimum = 1000, maximum = 9999),
                               list(enum = c("completion", "auto")))),
    library_ref = list(type = "object", required = list("from"),
                       properties = list(from = list(type = "string",
                                                     pattern = utl_library_id_pattern()),
                                         use = str)),
    market = list(anyOf = list(list(`$ref` = "#/$defs/value"),
                               list(type = "object",
                                    additionalProperties = list(`$ref` = "#/$defs/market"))))
  )
}

#' JSON-Schema eines Parameters
#' @noRd
val_json_param <- function(p) {
  out <- switch(p$kind,
    number = , amount = , rate = , share = , value = , schedule = {
      if (isTRUE(p$allow_auto)) list(`$ref` = "#/$defs/amount_auto") else
        list(`$ref` = "#/$defs/value")
    },
    integer = list(anyOf = list(list(type = "integer"),
                                list(type = "array", items = list(type = "integer")))),
    enum = {
      cds <- utl_param_codes(p)
      list(enum = unique(c(cds, val_param_aliases(p))))
    },
    logical = list(anyOf = list(list(type = "boolean"),
                                list(enum = c("ja", "nein", "yes", "no")))),
    date = list(type = "string", format = "date"),
    timing = list(`$ref` = "#/$defs/timing"),
    string = , ref = {
      o <- list(type = "string")
      if (isTRUE(p$extra[["id"]])) o$pattern <- "^[a-z][a-z0-9_]*$"
      if (!is.null(p$extra[["max_len"]])) o$maxLength <- as.integer(p$extra[["max_len"]])
      o
    },
    ids = list(anyOf = list(list(type = "array", items = list(type = "string")),
                            list(type = "string"))),
    map = {
      if (isTRUE(p$extra[["sequence"]])) {
        list(type = "array", items = list(type = "object"))
      } else if (isTRUE(p$extra[["any"]])) {
        list(type = "object")
      } else if (isTRUE(p$extra[["free"]])) {
        list(type = "object", additionalProperties = val_json_param(p$fields[[1L]]))
      } else {
        o <- val_json_object(p$fields)
        if (isTRUE(p$extra[["open"]])) o$additionalProperties <- TRUE
        o
      }
    },
    list()
  )
  if (!is.null(p$min) && is.finite(p$min) && p$kind %in% c("integer")) out$minimum <- p$min
  out
}

#' JSON-Schema einer festen Feldliste
#' @noRd
val_json_object <- function(fields, extra_props = list()) {
  props <- lapply(fields, val_json_param)
  props <- c(props, extra_props)
  req <- names(fields)[vapply(fields, function(f) isTRUE(f$required), logical(1))]
  out <- list(type = "object", additionalProperties = FALSE, properties = props)
  if (length(req) > 0L) out$required <- as.list(req)
  out
}

#' JSON-Schema einer Sammlung (Map nach id)
#' @noRd
val_json_collection <- function(fields, library_ref = FALSE) {
  extra <- if (library_ref) {
    list(from = list(type = "string", pattern = utl_library_id_pattern()),
         use = list(type = "string"))
  } else {
    list()
  }
  el <- val_json_object(fields, extra)
  if (library_ref) el$required <- NULL
  list(type = "object", propertyNames = list(pattern = "^[a-z][a-z0-9_]*$"),
       additionalProperties = el)
}

#' JSON-Schema des Blocks building (mit Bestandsbauteilen)
#' @noRd
val_json_building <- function(cat) {
  b <- cat$building
  b$elements <- NULL
  val_json_object(b, list(elements = val_json_collection(cat[["building.elements"]])))
}

#' JSON-Schema des Blocks energy (Träger und Zustände als Sammlungen)
#' @noRd
val_json_energy <- function(cat) {
  e <- cat$energy
  e$carriers <- NULL
  e$stages <- NULL
  val_json_object(e, list(carriers = val_json_collection(cat[["energy.carriers"]]),
                          stages = val_json_collection(cat[["energy.stages"]])))
}

#' JSON-Schema des Stochastik-Overlays
#' @noRd
val_json_stochastic <- function(cat) {
  pe <- val_json_object(cat[["stochastic.parameters"]])
  pe$additionalProperties <- TRUE
  pr <- val_json_object(cat[["stochastic.processes"]])
  pr$additionalProperties <- TRUE
  dists <- reg_list("distribution")$name
  procs <- reg_list("process")$name
  if (length(dists) > 0L) pe$properties$dist <- list(enum = dists)
  if (length(procs) > 0L) pr$properties$type <- list(enum = procs)
  pair <- list(type = "array", items = list(type = "array", minItems = 3L, maxItems = 3L))
  list(type = "object", additionalProperties = FALSE,
       properties = list(
         settings = val_json_object(cat[["stochastic.settings"]]),
         parameters = list(type = "object", additionalProperties = pe),
         processes = list(type = "object", additionalProperties = pr),
         correlations = list(type = "object", additionalProperties = FALSE,
                             properties = list(parameters = list(anyOf = list(
                               pair, list(`$ref` = "#/$defs/library_ref"))),
                               shocks = list(anyOf = list(
                                 pair, list(`$ref` = "#/$defs/library_ref")))))
       ))
}

#' JSON-Schema der Komponenten bzw. Finanzierungsbausteine (je registriertem Typ)
#' @noRd
val_json_types <- function(coll) {
  kinds <- if (identical(coll, "financing")) c("flow", "instrument") else "flow"
  tab <- reg_list()
  tab <- tab[tab$kind %in% kinds, , drop = FALSE]
  if (identical(coll, "financing")) {
    tab <- tab[tab$kind == "instrument" | tab$name == "equity", , drop = FALSE]
  }
  names_ord <- sort(unique(tab$name), method = "radix")
  meta <- list(id = list(type = "string"), label = list(type = "string"),
               description = list(type = "string"),
               after = list(type = "array", items = list(type = "string")),
               origin = list(type = "string"), asset_id = list(type = "string"),
               measure_id = list(type = "string"), funding_id = list(type = "string"),
               program = list(type = "string"))
  variants <- lapply(names_ord, function(nm) {
    kind <- tab$kind[tab$name == nm][1L]
    def <- reg_get(kind, nm)
    o <- val_json_object(def$params, meta)
    o$properties$type <- list(const = nm)
    o$required <- as.list(unique(c("type", unlist(o$required))))
    o
  })
  el <- if (length(variants) == 0L) {
    list(type = "object", required = list("type"))
  } else {
    list(oneOf = variants)
  }
  list(type = "object", propertyNames = list(pattern = "^[a-z][a-z0-9_]*$"),
       additionalProperties = el)
}
