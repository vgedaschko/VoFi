# Kernverträge: Zeilen, Komponentenrückgabe, Register, Kennzahlwerte, Konstruktoren und
# Validatoren aller Klassen (Integrator, Spec 00 Abschnitte 2.13, 4.13, 7, 11.8, 12.1, 13).

#' Vertragsversion der Kernverträge (Spec 00, Abschnitt 1.4)
#' @noRd
VOFI_CONTRACT_VERSION <- "1.0.0" # nolint: object_name_linter. Name durch Spec 00 festgelegt.

#' Numerische Toleranzen (Spec 00, Abschnitt 2.13); in ctx als `ctx$tol`
#' @noRd
vofi_tol <- list(
  balance_rel = 1e-8,    # I1: |balance_check| <= 1e-8 * max(1, Volumen des Laufs)
  stock_abs   = 1e-6,    # I3: Bestände >= -1e-6 EUR
  zero_abs    = 1e-9,    # "praktisch null" in Ketten und KPIs (EUR)
  oracle_abs  = 1e-6,    # Orakel gegen ungerundete Skriptwerte
  oracle_tab  = 0.005    # Orakel gegen gerundete Tabellenwerte (Memo 01)
)

# ---------------------------------------------------------------------------------------------
# Zeilenvertrag (7.1)
# ---------------------------------------------------------------------------------------------

#' Ledger-Zeile mit Pflicht-Tags erzeugen
#'
#' Erzeugt eine Zeile des Zahlungsbuchs (Spec 00, Abschnitt 7.1). Werte sind Bruttobeträge mit
#' dem Vorzeichen Zufluss +, Abfluss − aus Sicht des Investors als numerische Matrix
#' n × (T+1) (Spalte 1 = t0). Fehlende Angaben zu `tax_category`, `cash`, `kind` und `unit`
#' werden aus dem Vokabular der Kategorie ergänzt. Verstöße gegen den Vertrag sind Fehler der
#' Klasse `vofi_error_contract`.
#'
#' @param key lokaler Zeilenname des Typs (Muster `^[a-z][a-z0-9_]*$`, ohne `__`); den
#'   Ledger-Schlüssel setzt die Engine.
#' @param values numerische Matrix n × (T+1) ohne `NA`/`Inf`.
#' @param section Abschnitt aus `inst/vocab/sections.yaml`.
#' @param category Kategorie des Abschnitts aus `inst/vocab/categories.yaml`.
#' @param tax_category Steuerkategorie; `NULL` = Default der Kategorie.
#' @param cash zahlungswirksam; `NULL` = Default der Kategorie (im Abschnitt `memo` immer
#'   `FALSE`).
#' @param kind `"flow"`, `"stock"` oder `"memo"`; ohne Angabe der Default der Kategorie.
#' @param unit Einheit aus `inst/vocab/units.yaml`; ohne Angabe der Default der Kategorie.
#' @param asset_id,measure_id Bezug auf Anlagen- bzw. Maßnahmenregister.
#' @param vat_rate in `values` enthaltener Umsatzsteuersatz in `[0, 1]`.
#' @param vat_recoverable Vorsteuerabzug (v1 immer `FALSE`).
#' @param is_tax `NULL`, `"grundsteuer"`, `"grunderwerbsteuer"` oder `"umsatzsteuer"`.
#' @param program Programmcode (Förderung).
#' @param label,label_key Anzeige bzw. Label-Schlüssel.
#' @param ... Zusatzfelder aus `inst/vocab/row_extra_fields.yaml`.
#' @return Objekt der Klasse `vofi_row`.
#' @family Erweitern
#' @examples
#' m <- matrix(c(0, 1000, 1020), nrow = 1)
#' r <- vofi_row("value", m, section = "project", category = "rent")
#' r$tax_category
#' @export
vofi_row <- function(key, values, section, category, tax_category = NULL, cash = NULL,
                     kind = c("flow", "stock", "memo"), unit = "EUR", asset_id = NULL,
                     measure_id = NULL, vat_rate = 0, vat_recoverable = FALSE, is_tax = NULL,
                     program = NULL, label = NULL, label_key = NULL, ...) {
  if (!utl_is_string(key) || !utl_is_id(key, max_len = 80L)) {
    vofi_abort("core.contract.row_key", row = utl_collapse(format(key)),
               .class = "vofi_error_contract")
  }
  values <- utl_check_values(values, key)
  if (!utl_is_string(section) || !vocab_has("sections", section)) {
    vofi_abort("core.contract.row_section", row = key, section = utl_collapse(format(section)),
               suggestion = utl_suggest_text(as.character(section)[1L],
                                             vocab_codes("sections")),
               .class = "vofi_error_contract")
  }
  cat_row <- if (utl_is_string(category)) vocab_category(section, category) else NULL
  if (is.null(cat_row)) {
    vofi_abort("core.contract.row_category", row = key, section = section,
               category = utl_collapse(format(category)),
               suggestion = utl_suggest_text(as.character(category)[1L],
                                             vocab_codes("categories", section)),
               .class = "vofi_error_contract")
  }
  if (is.null(tax_category)) {
    tax_category <- cat_row$tax_category
  } else if (!utl_is_string(tax_category) ||
               !(tax_category %in% vocab_tax_allowed(section, category))) {
    vofi_abort("core.contract.row_tax_category", row = key,
               tax_category = utl_collapse(format(tax_category)), category = category,
               allowed = utl_collapse(vocab_tax_allowed(section, category)),
               .class = "vofi_error_contract")
  }
  if (is.null(cash)) {
    cash <- cat_row$cash
  } else if (!utl_is_flag(cash)) {
    vofi_abort("core.contract.row_flag", row = key, field = "cash",
               .class = "vofi_error_contract")
  }
  if (section == "memo" && isTRUE(cash)) {
    vofi_abort("core.contract.row_memo_cash", row = key, .class = "vofi_error_contract")
  }
  kind <- if (missing(kind)) {
    cat_row$kind
  } else {
    tryCatch(utl_match_arg(kind, c("flow", "stock", "memo"), "kind"),
             vofi_error_input = function(e) {
               vofi_abort("core.contract.row_kind", row = key,
                          kind = utl_collapse(format(kind)), .class = "vofi_error_contract")
             })
  }
  if (missing(unit)) unit <- cat_row$unit
  utl_check_row_unit(key, unit, section, cat_row)
  for (f in c("asset_id", "measure_id")) {
    v <- get(f)
    if (!is.null(v) && (!utl_is_string(v) || !utl_is_id(v, max_len = 80L))) {
      vofi_abort("core.contract.row_id", row = key, field = f, value = utl_collapse(format(v)),
                 .class = "vofi_error_contract")
    }
  }
  if (!is.numeric(vat_rate) || length(vat_rate) != 1L || is.na(vat_rate) ||
        vat_rate < 0 || vat_rate > 1) {
    vofi_abort("core.contract.row_vat", row = key, value = utl_collapse(format(vat_rate)),
               .class = "vofi_error_contract")
  }
  if (!utl_is_flag(vat_recoverable) || vat_recoverable) {
    vofi_abort("core.contract.row_vat_recoverable", row = key, .class = "vofi_error_contract")
  }
  if (!is.null(is_tax) && (!utl_is_string(is_tax) || !vocab_has("is_tax", is_tax))) {
    vofi_abort("core.contract.row_is_tax", row = key, value = utl_collapse(format(is_tax)),
               .class = "vofi_error_contract")
  }
  for (f in c("program", "label", "label_key")) {
    v <- get(f)
    if (!is.null(v) && !utl_is_string(v)) {
      vofi_abort("core.contract.row_string", row = key, field = f,
                 .class = "vofi_error_contract")
    }
  }
  extra <- utl_check_row_extra(list(...), key, category)
  structure(
    list(key = key, values = values, section = section, category = category,
         tax_category = tax_category, cash = cash, kind = kind, unit = unit,
         asset_id = asset_id, measure_id = measure_id, vat_rate = as.double(vat_rate),
         vat_recoverable = vat_recoverable, is_tax = is_tax, program = program,
         label = if (is.null(label)) NULL else enc2utf8(label), label_key = label_key,
         extra = extra),
    class = "vofi_row"
  )
}

#' Wertematrix einer Zeile prüfen (double, endlich)
#' @noRd
utl_check_values <- function(values, key) {
  if (!is.matrix(values) || !(is.numeric(values) || is.logical(values)) ||
        nrow(values) < 1L || ncol(values) < 1L) {
    vofi_abort("core.contract.row_values", row = key, .class = "vofi_error_contract")
  }
  if (!is.double(values)) storage.mode(values) <- "double"
  if (anyNA(values) || any(!is.finite(values))) {
    vofi_abort("core.contract.row_not_finite", row = key, .class = "vofi_error_contract")
  }
  values
}

#' Einheit einer Zeile prüfen (7.1)
#' @noRd
utl_check_row_unit <- function(key, unit, section, cat_row) {
  units <- vocab("units")
  ok <- utl_is_string(unit) && unit %in% units$code[units$row]
  if (ok && section != "memo") ok <- identical(unit, "EUR")
  if (ok && !identical(cat_row$unit, "EUR")) ok <- identical(unit, cat_row$unit)
  if (!ok) {
    vofi_abort("core.contract.row_unit", row = key, unit = utl_collapse(format(unit)),
               category = cat_row$category, .class = "vofi_error_contract")
  }
  invisible(TRUE)
}

#' Zusatzfelder einer Zeile prüfen (row_extra_fields.yaml)
#' @noRd
utl_check_row_extra <- function(extra, key, category) {
  if (length(extra) == 0L) return(list())
  spec <- vocab("row_extra_fields")
  nms <- names(extra)
  if (is.null(nms) || any(!nzchar(nms)) || anyDuplicated(nms)) {
    vofi_abort("core.contract.row_extra_names", row = key, .class = "vofi_error_contract")
  }
  for (nm in nms) {
    f <- spec[[nm]]
    v <- extra[[nm]]
    if (is.null(f)) {
      vofi_abort("core.contract.row_extra_unknown", row = key, field = nm,
                 suggestion = utl_suggest_text(nm, names(spec)),
                 .class = "vofi_error_contract")
    }
    ok <- length(v) == 1L && switch(f$type,
      integer = utl_is_whole(v),
      numeric = is.numeric(v) && !is.na(v),
      character = utl_is_string(v),
      logical = utl_is_flag(v),
      date = inherits(v, "Date") && !is.na(v),
      enum = utl_is_string(v) && v %in% f$values,
      FALSE
    )
    if (ok && length(f$categories) > 0L) ok <- category %in% f$categories
    if (!isTRUE(ok)) {
      vofi_abort("core.contract.row_extra_value", row = key, field = nm,
                 .class = "vofi_error_contract")
    }
    if (identical(f$type, "integer")) extra[[nm]] <- as.integer(round(v))
  }
  extra
}

#' Zusätzliche Regeln für Zeilen von Zahlungskomponenten (5.6 F4)
#'
#' Flows dürfen nur die Abschnitte `project`, `grants`, `equity` (nur `equity_in`/`equity_out`)
#' und `memo` verwenden, keine Engine-Kategorien und nie `tax_category = "principal"`.
#' @param row `vofi_row`.
#' @return `character()` oder Befundtexte.
#' @noRd
validate_flow_row <- function(row) {
  out <- character(0)
  sec <- vocab("sections")
  if (!isTRUE(sec$flow[match(row$section, sec$code)])) {
    out <- c(out, msg("core.contract.flow_section", row = row$key, section = row$section))
  }
  cat_row <- vocab_category(row$section, row$category)
  if (is.null(cat_row) || !isTRUE(cat_row$flow_ok)) {
    out <- c(out, msg("core.contract.flow_category", row = row$key, section = row$section,
                      category = row$category))
  }
  if (identical(row$tax_category, "principal")) {
    out <- c(out, msg("core.contract.flow_principal", row = row$key))
  }
  if (identical(row$section, "memo") && isTRUE(row$cash)) {
    out <- c(out, msg("core.contract.row_memo_cash", row = row$key))
  }
  out
}

# ---------------------------------------------------------------------------------------------
# Rückgabe einer Zahlungskomponente und Register (7.2)
# ---------------------------------------------------------------------------------------------

#' Rückgabe einer Zahlungskomponente bündeln
#'
#' Fasst die Zeilen einer Zahlungskomponente (`build(spec, ctx)`) mit Register-Einträgen,
#' Hilfsmatrizen und Hinweisen zusammen (Spec 00, Abschnitt 7.2).
#'
#' @param ... Objekte der Klasse `vofi_row` (auch als Listen von Zeilen).
#' @param assets Liste von [vofi_asset()]-Einträgen (oder ein einzelner Eintrag).
#' @param measures Liste von [vofi_measure()]-Einträgen (oder ein einzelner Eintrag).
#' @param aux benannte Liste von n × (T+1)-Matrizen, die keine Ledger-Zeilen sind (für
#'   abhängige Komponenten über `ctx$component(id)$aux`).
#' @param meta Liste mit Hinweisen und Diagnose (erscheint nicht im Ledger).
#' @return Objekt der Klasse `vofi_flows` mit den Elementen `rows`, `assets`, `measures`, `aux`,
#'   `meta`.
#' @family Erweitern
#' @examples
#' m <- matrix(c(0, 1000, 1020), nrow = 1)
#' f <- vofi_flows(vofi_row("value", m, section = "project", category = "rent"))
#' length(f$rows)
#' @export
vofi_flows <- function(..., assets = list(), measures = list(), aux = list(), meta = list()) {
  args <- list(...)
  rows <- list()
  for (a in args) {
    if (inherits(a, "vofi_row")) {
      rows[[length(rows) + 1L]] <- a
    } else if (is.list(a) && all(vapply(a, inherits, logical(1), "vofi_row"))) {
      rows <- c(rows, unname(a))
    } else {
      vofi_abort("core.contract.flows_rows", .class = "vofi_error_contract")
    }
  }
  keys <- vapply(rows, function(r) r$key, "")
  if (anyDuplicated(keys)) {
    vofi_abort("core.contract.flows_duplicate", row = keys[duplicated(keys)][1L],
               .class = "vofi_error_contract")
  }
  dims <- lapply(rows, function(r) dim(r$values))
  if (length(dims) > 1L && !all(vapply(dims, identical, logical(1), dims[[1L]]))) {
    vofi_abort("core.contract.flows_dims", .class = "vofi_error_contract")
  }
  assets <- utl_register_list(assets, "vofi_asset", "asset_id")
  measures <- utl_register_list(measures, "vofi_measure", "measure_id")
  if (!is.list(aux) || (length(aux) > 0L && (is.null(names(aux)) || any(!nzchar(names(aux)))))) {
    vofi_abort("core.contract.flows_aux", .class = "vofi_error_contract")
  }
  for (nm in names(aux)) {
    a <- aux[[nm]]
    if (!is.matrix(a) || !is.numeric(a) || anyNA(a) ||
          (length(dims) > 0L && !identical(dim(a), dims[[1L]]))) {
      vofi_abort("core.contract.flows_aux", .class = "vofi_error_contract")
    }
  }
  if (!is.list(meta)) vofi_abort("core.contract.flows_meta", .class = "vofi_error_contract")
  structure(list(rows = rows, assets = assets, measures = measures, aux = aux, meta = meta),
            class = "vofi_flows")
}

#' Registerliste prüfen
#' @noRd
utl_register_list <- function(x, cls, id_field) {
  if (inherits(x, cls)) x <- list(x)
  if (is.null(x)) x <- list()
  if (!is.list(x) || !all(vapply(x, inherits, logical(1), cls))) {
    vofi_abort("core.contract.register_class", class = cls, .class = "vofi_error_contract")
  }
  ids <- vapply(x, function(e) e[[id_field]], "")
  dup <- ids[duplicated(ids)]
  for (d in unique(dup)) {
    same <- x[ids == d]
    if (!all(vapply(same, identical, logical(1), same[[1L]]))) {
      vofi_abort("core.contract.register_duplicate", id = d, .class = "vofi_error_contract")
    }
  }
  unname(x[!duplicated(ids)])
}

#' Eintrag im Anlagenregister
#'
#' Beschreibt eine Anlage (Gebäude, Grund und Boden, PV-Anlage, ...) für spätere Steuermodule
#' (Spec 00, Abschnitt 7.2, R-41). Die AfA-Bemessungsgrundlage ist kein Feld; sie entsteht aus
#' den Zeilen mit derselben `asset_id`.
#'
#' @param asset_id id der Anlage (Muster wie ids, Abschnitt 4.4).
#' @param asset_type Anlagenart aus `inst/vocab/asset_types.yaml`.
#' @param in_service_date Datum der Fertigstellung bzw. Inbetriebnahme.
#' @param land_share Anteil Grund und Boden in `[0, 1]`.
#' @param afa_method AfA-Methode (Code, Steuermodul) oder `NULL`.
#' @param useful_life_override abweichende Nutzungsdauer in Jahren oder `NULL`.
#' @param construction_start_date,building_application_date,acquisition_date Daten oder `NULL`.
#' @param original_completion_year Baujahr des Bestands oder `NULL`.
#' @param living_area_m2 Wohnfläche in m² oder `NULL`.
#' @param efficiency_standard Effizienzstandard (Code) oder `NULL`.
#' @param label Anzeigename oder `NULL`.
#' @return Objekt der Klasse `vofi_asset`.
#' @family Erweitern
#' @examples
#' vofi_asset("b1", "gebaeude_wohnen", as.Date("2028-01-01"), land_share = 0.2)
#' @export
vofi_asset <- function(asset_id, asset_type, in_service_date, land_share = 0, afa_method = NULL,
                       useful_life_override = NULL, construction_start_date = NULL,
                       building_application_date = NULL, original_completion_year = NULL,
                       acquisition_date = NULL, living_area_m2 = NULL,
                       efficiency_standard = NULL, label = NULL) {
  utl_check_register_id(asset_id, "asset_id")
  if (!utl_is_string(asset_type) || !vocab_has("asset_types", asset_type)) {
    vofi_abort("core.contract.register_code", field = "asset_type",
               value = utl_collapse(format(asset_type)),
               suggestion = utl_suggest_text(as.character(asset_type)[1L],
                                             vocab_codes("asset_types")),
               .class = "vofi_error_contract")
  }
  in_service_date <- utl_as_date(in_service_date, "in_service_date")
  if (!is.numeric(land_share) || length(land_share) != 1L || is.na(land_share) ||
        land_share < 0 || land_share > 1) {
    vofi_abort("core.contract.register_value", field = "land_share",
               .class = "vofi_error_contract")
  }
  if (!is.null(useful_life_override) &&
        (!is.numeric(useful_life_override) || length(useful_life_override) != 1L ||
           !(useful_life_override > 0))) {
    vofi_abort("core.contract.register_value", field = "useful_life_override",
               .class = "vofi_error_contract")
  }
  if (!is.null(original_completion_year)) {
    original_completion_year <- utl_check_whole(original_completion_year,
                                                "original_completion_year")
  }
  if (!is.null(living_area_m2) &&
        (!is.numeric(living_area_m2) || length(living_area_m2) != 1L || !(living_area_m2 >= 0))) {
    vofi_abort("core.contract.register_value", field = "living_area_m2",
               .class = "vofi_error_contract")
  }
  for (f in c("afa_method", "efficiency_standard", "label")) {
    v <- get(f)
    if (!is.null(v) && !utl_is_string(v)) {
      vofi_abort("core.contract.register_value", field = f, .class = "vofi_error_contract")
    }
  }
  structure(list(
    asset_id = asset_id, asset_type = asset_type, in_service_date = in_service_date,
    land_share = as.double(land_share), afa_method = afa_method,
    useful_life_override = useful_life_override,
    construction_start_date = utl_as_date(construction_start_date, "construction_start_date",
                                          allow_null = TRUE),
    building_application_date = utl_as_date(building_application_date,
                                            "building_application_date", allow_null = TRUE),
    original_completion_year = original_completion_year,
    acquisition_date = utl_as_date(acquisition_date, "acquisition_date", allow_null = TRUE),
    living_area_m2 = living_area_m2, efficiency_standard = efficiency_standard, label = label
  ), class = "vofi_asset")
}

#' Eintrag im Maßnahmenregister
#'
#' Beschreibt eine Maßnahme für Förderung, Mietrecht und spätere Steuermodule (Spec 00,
#' Abschnitt 7.2).
#'
#' @param measure_id id der Maßnahme.
#' @param measure_type Maßnahmenart aus `inst/vocab/measure_types.yaml`.
#' @param classification `"auto"`, `"erhaltung"` oder `"herstellung"`.
#' @param classification_source `"default"`, `"user"` oder `"rule"`.
#' @param completion_date,paid_in_full_date Daten oder `NULL`.
#' @param contractor_certified Fachunternehmerbestätigung (`TRUE`/`FALSE`/`NA`).
#' @param funding_choice `"keine"`, `"beg_zuschuss"`, `"beg_kredit"` oder `"35c"`.
#' @param asset_id zugehörige Anlage oder `NULL`.
#' @param label Anzeigename oder `NULL`.
#' @return Objekt der Klasse `vofi_measure`.
#' @family Erweitern
#' @examples
#' vofi_measure("huelle", "daemmung_fassade", classification = "herstellung")
#' @export
vofi_measure <- function(measure_id, measure_type,
                         classification = c("auto", "erhaltung", "herstellung"),
                         classification_source = c("default", "user", "rule"),
                         completion_date = NULL, paid_in_full_date = NULL,
                         contractor_certified = NA,
                         funding_choice = c("keine", "beg_zuschuss", "beg_kredit", "35c"),
                         asset_id = NULL, label = NULL) {
  utl_check_register_id(measure_id, "measure_id")
  if (!utl_is_string(measure_type) || !vocab_has("measure_types", measure_type)) {
    vofi_abort("core.contract.register_code", field = "measure_type",
               value = utl_collapse(format(measure_type)),
               suggestion = utl_suggest_text(as.character(measure_type)[1L],
                                             vocab_codes("measure_types")),
               .class = "vofi_error_contract")
  }
  classification <- utl_match_arg(classification, c("auto", "erhaltung", "herstellung"),
                                  "classification")
  classification_source <- utl_match_arg(classification_source,
                                         c("default", "user", "rule"),
                                         "classification_source")
  funding_choice <- utl_match_arg(funding_choice,
                                  c("keine", "beg_zuschuss", "beg_kredit", "35c"),
                                  "funding_choice")
  if (!is.logical(contractor_certified) || length(contractor_certified) != 1L) {
    vofi_abort("core.contract.register_value", field = "contractor_certified",
               .class = "vofi_error_contract")
  }
  if (!is.null(asset_id)) utl_check_register_id(asset_id, "asset_id")
  if (!is.null(label) && !utl_is_string(label)) {
    vofi_abort("core.contract.register_value", field = "label", .class = "vofi_error_contract")
  }
  structure(list(
    measure_id = measure_id, measure_type = measure_type, classification = classification,
    classification_source = classification_source,
    completion_date = utl_as_date(completion_date, "completion_date", allow_null = TRUE),
    paid_in_full_date = utl_as_date(paid_in_full_date, "paid_in_full_date", allow_null = TRUE),
    contractor_certified = contractor_certified, funding_choice = funding_choice,
    asset_id = asset_id, label = label
  ), class = "vofi_measure")
}

#' @noRd
utl_check_register_id <- function(x, field) {
  if (!utl_is_string(x) || !utl_is_id(x, max_len = 80L)) {
    vofi_abort("core.contract.register_id", field = field, value = utl_collapse(format(x)),
               .class = "vofi_error_contract")
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------------------------------
# Kennzahlwert (12.1)
# ---------------------------------------------------------------------------------------------

#' Rückgabeobjekt einer Kennzahl
#'
#' Skalare Kennzahlen liefern einen numerischen Vektor der Länge n (ein Wert je Lauf),
#' Reihenkennzahlen eine Matrix n × P mit den Jahren `years`. Jeder `NA`-Wert MUSS einen
#' Begründungscode aus `inst/vocab/na_reasons.yaml` tragen; wo der Wert definiert ist, ist der
#' Code `NA` (Spec 00, Abschnitt 12.1). Werte sind endlich oder `NA`.
#'
#' @param values numerischer Vektor (Länge n) oder Matrix n × P.
#' @param na_reason `NULL`, ein Code (wird recycelt) oder Zeichenvektor der Länge n.
#' @param years bei Reihen: ganze Zahlen der Länge P (Kalender- bzw. Betriebsjahr).
#' @return Objekt der Klasse `vofi_kpi_value` mit `values`, `na_reason`, `years`, `shape`.
#' @family Erweitern
#' @examples
#' vofi_kpi_value(c(0.051, NA), na_reason = c(NA, "no_equity"))
#' @export
vofi_kpi_value <- function(values, na_reason = NULL, years = NULL) {
  shape <- if (is.matrix(values)) "series" else "scalar"
  if (!(is.numeric(values) || is.logical(values))) {
    vofi_abort("core.contract.kpi_values", .class = "vofi_error_contract")
  }
  if (shape == "scalar") {
    values <- as.double(values)
    n <- length(values)
    na_rows <- is.na(values)
  } else {
    storage.mode(values) <- "double"
    n <- nrow(values)
    na_rows <- rowSums(is.na(values)) > 0
    if (is.null(years) || length(years) != ncol(values) || !is.numeric(years) ||
          anyNA(years)) {
      vofi_abort("core.contract.kpi_years", .class = "vofi_error_contract")
    }
    years <- as.integer(years)
  }
  if (any(is.infinite(values))) {
    vofi_abort("core.contract.kpi_infinite", .class = "vofi_error_contract")
  }
  if (is.null(na_reason)) na_reason <- rep(NA_character_, n)
  if (length(na_reason) == 1L) na_reason <- rep(na_reason, n)
  if (length(na_reason) != n) {
    vofi_abort("core.contract.kpi_na_length", n = n, .class = "vofi_error_contract")
  }
  na_reason <- as.character(na_reason)
  na_reason[!na_rows] <- NA_character_
  if (any(na_rows & is.na(na_reason))) {
    vofi_abort("core.contract.kpi_na_reason", .class = "vofi_error_contract")
  }
  bad <- setdiff(unique(na_reason[!is.na(na_reason)]), vocab_codes("na_reasons"))
  if (length(bad) > 0L) {
    vofi_abort("core.contract.kpi_na_code", code = utl_collapse(bad),
               suggestion = utl_suggest_text(bad[1L], vocab_codes("na_reasons")),
               .class = "vofi_error_contract")
  }
  structure(list(values = values, na_reason = na_reason, years = years, shape = shape),
            class = "vofi_kpi_value")
}

# ---------------------------------------------------------------------------------------------
# Ledger (7.4)
# ---------------------------------------------------------------------------------------------

#' Metadaten-Zeilen des Ledgers bauen (vektorisiert)
#'
#' Fehlende `tax_category`, `cash`, `kind`, `unit` kommen aus dem Vokabular; `order` ohne Angabe
#' ist `1000 * section_order + 10 * category_rank` (7.8, ohne Komponentenposition).
#' @return Data Frame mit den Spalten aus Abschnitt 7.4.
#' @noRd
new_ledger_rows <- function(key, section, category, tax_category = NULL, cash = NULL,
                            kind = NULL, unit = NULL, asset_id = NA_character_,
                            measure_id = NA_character_, vat_rate = 0, vat_recoverable = FALSE,
                            is_tax = NA_character_, program = NA_character_,
                            source_id = "engine", existing_debt = FALSE, source_type = "engine",
                            origin = "engine", local_row = NA_character_,
                            label_key = NA_character_, label = NA_character_, order = NULL,
                            extra = NULL) {
  n <- length(key)
  rec <- function(x) rep_len(x, n)
  section <- rec(as.character(section))
  category <- rec(as.character(category))
  defs <- lapply(seq_len(n), function(i) vocab_category(section[i], category[i]))
  bad <- which(vapply(defs, is.null, logical(1)))
  if (length(bad) > 0L) {
    vofi_abort("core.contract.row_category", row = key[bad[1L]], section = section[bad[1L]],
               category = category[bad[1L]], suggestion = "", .class = "vofi_error_contract")
  }
  pick <- function(x, field, type) {
    if (is.null(x)) vapply(defs, function(d) d[[field]], type) else rec(x)
  }
  if (is.null(order)) {
    order <- 1000 * vocab_section_order(section) +
      10 * vapply(defs, function(d) as.double(d$rank), double(1))
  }
  df <- data.frame(
    key = as.character(key), section = section, category = category,
    tax_category = pick(tax_category, "tax_category", ""), cash = pick(cash, "cash", TRUE),
    kind = pick(kind, "kind", ""), unit = pick(unit, "unit", ""),
    asset_id = rec(as.character(asset_id)), measure_id = rec(as.character(measure_id)),
    vat_rate = rec(as.double(vat_rate)), vat_recoverable = rec(as.logical(vat_recoverable)),
    is_tax = rec(as.character(is_tax)), program = rec(as.character(program)),
    source_id = rec(as.character(source_id)), existing_debt = rec(as.logical(existing_debt)),
    source_type = rec(as.character(source_type)), origin = rec(as.character(origin)),
    local_row = rec(as.character(local_row)), label_key = rec(as.character(label_key)),
    label = rec(as.character(label)), order = rec(as.double(order)),
    stringsAsFactors = FALSE
  )
  df$extra <- I(if (is.null(extra)) rep(list(list()), n) else rec(extra))
  df
}

#' Ledger-Objekt bauen
#' @param rows Data Frame aus [new_ledger_rows()].
#' @param values benannte Liste n x (T+1)-Matrizen in der Reihenfolge `rows$key`.
#' @param n,T Läufe und letzter Periodenindex (Default: aus den Matrizen).
#' @return Objekt der Klasse `vofi_ledger`.
#' @noRd
new_vofi_ledger <- function(rows, values, n = NULL, T = NULL) { # nolint. T wie Spec 00 7.4
  big_t <- T # nolint. T wie Spec 00 7.4
  if (length(values) > 0L) {
    n <- n %||% nrow(values[[1L]])
    big_t <- big_t %||% (ncol(values[[1L]]) - 1L)
  }
  x <- structure(list(rows = rows, values = values, n = as.integer(n %||% 1L),
                      T = as.integer(big_t %||% 0L)), class = "vofi_ledger")
  validate_vofi_ledger(x)
}

#' Ledger prüfen (Struktur 7.4, Werte N1)
#' @noRd
validate_vofi_ledger <- function(x) {
  cols <- c("key", "section", "category", "tax_category", "cash", "kind", "unit", "asset_id",
            "measure_id", "vat_rate", "vat_recoverable", "is_tax", "program", "source_id",
            "existing_debt", "source_type", "origin", "local_row", "label_key", "label",
            "order", "extra")
  if (!inherits(x, "vofi_ledger") || !is.data.frame(x$rows) ||
        length(setdiff(cols, names(x$rows))) > 0L) {
    vofi_abort("core.contract.fields_missing", class = "vofi_ledger",
               fields = utl_collapse(setdiff(cols, names(x$rows))),
               .class = "vofi_error_contract")
  }
  if (!identical(names(x$values), x$rows$key) || anyDuplicated(x$rows$key)) {
    vofi_abort("core.contract.ledger_keys", .class = "vofi_error_contract")
  }
  for (k in names(x$values)) {
    v <- x$values[[k]]
    if (!is.matrix(v) || !is.double(v) || !identical(dim(v), c(x$n, x$T + 1L))) {
      vofi_abort("core.contract.ledger_dims", row = k, n = x$n, T = x$T,
                 .class = "vofi_error_contract")
    }
    # N1 in einem Durchlauf ohne Hilfsvektor: eine Summe ist genau dann nicht endlich, wenn ein
    # Element NA/NaN/Inf ist (Betraege in EUR liegen weit unter dem double-Ueberlauf)
    if (!is.finite(sum(v)) && !all(is.finite(v))) {
      vofi_abort("core.contract.row_not_finite", row = k, .class = "vofi_error_contract")
    }
  }
  invisible(x)
}

# ---------------------------------------------------------------------------------------------
# Ziehungen (11.8)
# ---------------------------------------------------------------------------------------------

#' Ziehungsobjekt bauen
#' @return Objekt der Klasse `vofi_draws`.
#' @noRd
new_vofi_draws <- function(mode = c("deterministic", "mc", "design"), n = 1L,
                           sims = seq_len(n), blocks = integer(0), block_size = NA_integer_,
                           static = list(), decision = list(), u = list(), targets = NULL,
                           annual = list(), paths = list(), years = integer(0),
                           scenario_index = list(), features = NULL, meta = list()) {
  mode <- utl_match_arg(mode, c("deterministic", "mc", "design"), "mode")
  if (is.null(targets)) {
    targets <- data.frame(key = character(0), target = character(0), kind = character(0),
                          stringsAsFactors = FALSE)
  }
  if (is.null(features)) features <- data.frame(row.names = seq_len(n))
  x <- structure(list(
    mode = mode, n = as.integer(n), sims = as.integer(sims), blocks = as.integer(blocks),
    block_size = as.integer(block_size), static = static, decision = decision, u = u,
    targets = targets, annual = annual, paths = paths, years = as.integer(years),
    scenario_index = scenario_index, features = features, meta = meta
  ), class = "vofi_draws")
  validate_vofi_draws(x)
}

#' Ziehungsobjekt prüfen (Zusicherungen 11.8)
#' @noRd
validate_vofi_draws <- function(x, T = NULL) { # nolint: object_name_linter. T wie Spec.
  n <- x$n
  bad <- function(what) {
    vofi_abort("core.contract.draws", what = what, .class = "vofi_error_contract")
  }
  if (length(x$sims) != n) bad("sims")
  for (k in names(x$static)) if (length(x$static[[k]]) != n) bad(paste0("static:", k))
  for (k in names(x$decision)) if (length(x$decision[[k]]) != n) bad(paste0("decision:", k))
  for (k in names(x$paths)) {
    p <- x$paths[[k]]
    if (!is.matrix(p) || nrow(p) != n || (!is.null(T) && ncol(p) != T + 1L)) { # nolint
      bad(paste0("paths:", k))
    }
  }
  if (anyDuplicated(x$targets$target)) bad("targets")
  invisible(x)
}

# ---------------------------------------------------------------------------------------------
# Validierungsbefunde (13.5)
# ---------------------------------------------------------------------------------------------

#' Befund einer validate()-Funktion eines Typs
#' @param severity `"error"`, `"warning"` oder `"info"`.
#' @param code Label-Schlüssel.
#' @param path Pfad.
#' @param args Platzhalterwerte.
#' @return Objekt der Klasse `vofi_finding`.
#' @noRd
new_vofi_finding <- function(severity = c("error", "warning", "info"), code, path = NA_character_,
                             args = list()) {
  severity <- utl_match_arg(severity, c("error", "warning", "info"), "severity")
  structure(list(severity = severity, code = code, path = path, args = args),
            class = "vofi_finding")
}

#' Validierungsbericht (leer oder aus Data Frame)
#' @noRd
new_vofi_validation <- function(x = NULL) {
  cols <- list(severity = character(0), code = character(0), path = character(0),
               location = character(0), message = character(0), layer = integer(0),
               variant = character(0))
  if (is.null(x)) x <- as.data.frame(cols, stringsAsFactors = FALSE)
  miss <- setdiff(names(cols), names(x))
  if (length(miss) > 0L) {
    vofi_abort("core.contract.fields_missing", class = "vofi_validation",
               fields = utl_collapse(miss), .class = "vofi_error_contract")
  }
  structure(x, class = c("vofi_validation", "data.frame"))
}

# ---------------------------------------------------------------------------------------------
# Szenario, Spezifikation, Modell (4.13)
# ---------------------------------------------------------------------------------------------

#' Felder prüfen bzw. ergänzen und Klasse setzen
#' @param x Liste.
#' @param cls Klasse.
#' @param required Felder, die vorhanden und nicht `NULL` sein müssen.
#' @param optional Felder, die mit Defaults ergänzt werden (benannte Liste).
#' @noRd
utl_new_object <- function(x, cls, required = character(0), optional = list()) {
  if (!is.list(x)) {
    vofi_abort("core.contract.fields_missing", class = cls, fields = "*",
               .class = "vofi_error_contract")
  }
  x <- utl_fill_defaults(unclass(x), optional)
  miss <- required[!(required %in% names(x)) |
                     vapply(required, function(f) is.null(x[[f]]), logical(1))]
  if (length(miss) > 0L) {
    vofi_abort("core.contract.fields_missing", class = cls, fields = utl_collapse(miss),
               .class = "vofi_error_contract")
  }
  structure(x, class = cls)
}

#' Blöcke der obersten Ebene (4.2)
#' @noRd
utl_scenario_blocks <- function() {
  c("meta", "project", "grid", "building", "household", "unit_groups", "measures", "energy",
    "funding", "components", "financing", "accounts", "market", "residual_value", "tax",
    "analysis", "stochastic", "shared", "variants", "scenario_sets")
}

#' Kanonisches Szenario-Objekt bauen (4.13)
#' @param x Liste der Blöcke.
#' @param source Liste `path`, `format`, `read_time`, `sha`, `stochastic_path`.
#' @param provenance Data Frame der Herkunft (Schicht 5) oder `NULL`.
#' @return Objekt der Klasse `vofi_scenario`.
#' @noRd
new_vofi_scenario <- function(x, source = list(), provenance = NULL) {
  opt <- c(list(schema_version = 1L),
           stats::setNames(rep(list(list()), length(utl_scenario_blocks())),
                           utl_scenario_blocks()))
  obj <- utl_new_object(x, "vofi_scenario", optional = opt)
  attr(obj, "source") <- utl_fill_defaults(source, list(path = NA_character_, format = "list",
                                                        read_time = NULL, sha = NA_character_,
                                                        stochastic_path = NULL))
  attr(obj, "provenance") <- provenance
  obj
}

#' Aufgelöste Variante bauen (4.13)
#' @noRd
new_vofi_spec <- function(x, provenance = NULL) {
  blocks <- setdiff(utl_scenario_blocks(), c("shared", "variants", "scenario_sets"))
  opt <- c(stats::setNames(rep(list(list()), length(blocks)), blocks),
           list(registers = list(assets = list(), measures = list()), legal = list(),
                variant = "base", scenario_set = NULL,
                library = data.frame(entry = character(0), as_of = as.Date(character(0)),
                                     valid_from = as.Date(character(0)),
                                     valid_to = as.Date(character(0)),
                                     quality = character(0), stringsAsFactors = FALSE)))
  obj <- utl_new_object(x, "vofi_spec", optional = opt)
  attr(obj, "provenance") <- provenance
  obj
}

#' Rechenfertiges Modell bauen (4.13)
#' @noRd
new_vofi_model <- function(x) {
  utl_new_object(x, "vofi_model", required = c("spec", "grid"),
                 optional = list(nodes = list(), instruments = list(), equity = character(0),
                                 accounts = list(), surplus_chain = list(),
                                 deficit_chain = list(), sampler = NULL, tax = NULL,
                                 tax_params = list(), kpis = list(), auto_id = NULL,
                                 topup_id = NULL, base = NULL, decision = NULL,
                                 hash = NA_character_,
                                 contract_version = VOFI_CONTRACT_VERSION))
}

#' Instrumentzustand (8.3) mit Klasse versehen
#' @noRd
new_vofi_inst_state <- function(x) {
  utl_new_object(x, "vofi_inst_state", required = c("B"))
}

# ---------------------------------------------------------------------------------------------
# Ergebnisklassen (13)
# ---------------------------------------------------------------------------------------------

#' Ergebnis eines deterministischen Laufs bzw. Einzellaufs (13.1)
#' @noRd
new_vofi_result <- function(x) {
  obj <- utl_new_object(
    x, "vofi_result",
    required = c("spec", "grid", "ledger", "kpis", "kpi_na", "checks", "flags", "meta"),
    optional = list(model_hash = NA_character_, kpi_series = list(), opportunity = NULL,
                    registers = list(assets = list(), measures = list()), draws = NULL,
                    decision = NULL, traffic_light = NULL)
  )
  validate_vofi_result(obj)
}

#' @noRd
validate_vofi_result <- function(x) {
  bad <- function(what) {
    vofi_abort("core.contract.result", class = "vofi_result", what = what,
               .class = "vofi_error_contract")
  }
  if (!inherits(x$grid, "vofi_grid")) bad("grid")
  if (!inherits(x$ledger, "vofi_ledger")) bad("ledger")
  validate_vofi_ledger(x$ledger)
  n <- x$ledger$n
  if (!is.data.frame(x$kpis) || nrow(x$kpis) != n) bad("kpis")
  if (!is.data.frame(x$kpi_na) || nrow(x$kpi_na) != n ||
        !identical(names(x$kpi_na), names(x$kpis))) {
    bad("kpi_na")
  }
  if (!is.data.frame(x$flags) || nrow(x$flags) != n) bad("flags")
  if (!is.data.frame(x$checks) ||
        length(setdiff(c("invariant", "max_dev", "tol", "ok"), names(x$checks))) > 0L) {
    bad("checks")
  }
  if (!is.list(x$meta)) bad("meta")
  invisible(x)
}

#' Ergebnis einer Monte-Carlo-Simulation (13.2)
#' @noRd
new_vofi_mc_result <- function(x) {
  utl_new_object(
    x, "vofi_mc_result",
    required = c("spec", "grid", "kpis", "kpi_na", "stats", "checks", "meta"),
    optional = list(model = NULL, kpi_series = list(), inputs = NULL, features = NULL,
                    flags = NULL, bands = list(), runs = list(), run_index = integer(0),
                    deterministic = NULL, ledger = NULL, decision = NULL,
                    traffic_light = NULL)
  )
}

#' Vergleich von Varianten (13.3)
#' @noRd
new_vofi_comparison <- function(x) {
  utl_new_object(
    x, "vofi_comparison",
    required = c("results", "baseline", "variants", "kpi_table", "meta"),
    optional = list(scenario_sets = NULL, differences = list(), diff_stats = NULL,
                    ranking = NULL, diff_table = NULL, comparability = new_vofi_validation(),
                    traffic_light = NULL, restrictions = NULL, conditional = NULL, crn = TRUE)
  )
}

#' Sensitivitätsanalyse (13.4)
#' @noRd
new_vofi_sensitivity <- function(x) {
  utl_new_object(
    x, "vofi_sensitivity",
    required = c("method", "kpi", "params", "meta"),
    optional = list(variant = "base", base_value = NA_real_, results = NULL, spider = NULL,
                    global = NULL, r2_src = NA_real_)
  )
}

#' Ergebnis der Zielwertsuche (13.4)
#' @noRd
new_vofi_solution <- function(x) {
  utl_new_object(
    x, "vofi_solution",
    required = c("what", "value"),
    optional = list(param = NULL, kpi = NULL, target = 0, target_source = "value",
                    kpi_at_value = NA_real_, iterations = NA_integer_, interval = NULL,
                    jump = FALSE, monotone = TRUE, reference = NULL, rebuild = FALSE,
                    prob_exceed = NA_real_, message = NA_character_)
  )
}

#' VoFi-Tabelle (13.5)
#' @noRd
new_vofi_table <- function(x) {
  utl_new_object(
    x, "vofi_table",
    required = c("data", "layout", "detail"),
    optional = list(periods = NULL, sim = 1L, variant = NULL,
                    format = list(neg_red = TRUE, digits = 2))
  )
}
