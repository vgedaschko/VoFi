# Excel-Eingabevorlage und gemeinsames Blattlayout (WS-A2, Spec 00 Abschnitt 4.14, Memo 05 4.10).
#
# Die Vorlage wird aus Registry (Typen und Parameter), Vokabularen, Feldkatalog (R/schema.R) und
# Label-Katalog erzeugt; dasselbe Layout schreibt io_write_excel() mit den Werten eines Szenarios
# (R/io-excel-write.R) und liest io_read_excel() (R/io-excel-read.R). Zeile 1 jedes Datenblatts
# enthaelt die Maschinenschluessel (ausgeblendet), Zeile 2 die deutschen Ueberschriften, ab Zeile
# 3 folgen Daten. Blaetter (Rolle -> Layout):
#   instructions  Text          Anleitung, Farblegende, Zahlen- und Wertformregeln
#   project       Schluessel-Wert  meta, project, grid, accounts, residual_value, tax, analysis
#   household     Schluessel-Wert  household
#   market        Schluessel-Wert  market, shared
#   building      Schluessel-Wert  building, energy
#   unit_groups, measures, funding, financing   breit (eine Zeile je Element)
#   components    lang (id, Typ, Parameter, Wert)
#   series        Zeitreihen (id, Form, Optionen, Spalten je Jahr bzw. Periode bzw. Termin)
#   settings      Schluessel-Wert  stochastic (ohne parameters, processes, correlations)
#   parameters    breit: stochastic.parameters (Ziel, Verteilung, P1-P4)
#   processes     lang: stochastic.processes
#   correlations  Art, Groesse A, Groesse B, rho
#   variants, scenario_sets   lang: Operationen je Variante bzw. Szenario-Set
#   lists         ausgeblendet: Auswahllisten (Code und deutsche Bezeichnung)
#   meta          ausgeblendet: schema_version, Vorlagen- und Paketversion, Reihenfolge der Bloecke

#' Excel-Eingabevorlage erzeugen
#'
#' Erzeugt die Excel-Eingabevorlage aus Registry, Vokabularen, Feldkatalog und Label-Katalog
#' (Spec 00, Abschnitt 4.14; Memo 05 Abschnitt 4.10). Die Vorlage enthält je Domänenblock ein
#' Blatt mit deutschen Bezeichnungen, Einheiten, Vorgaben (mit ihrer Herkunft: Typ-Default,
#' `global.yaml`, Profil, Ableitungsregel), Spalten für die Quelle und Kommentare, Auswahllisten
#' für Codes (deutsche Bezeichnungen, der Leser übersetzt sie in Codes), die Blätter
#' „Zeitreihen“, „Varianten“, „Szenario-Sets“ und die Blätter des Stochastik-Overlays
#' („Stochastik-Einstellungen“, „Unsicherheiten“, „Prozesse“, „Korrelationen“) sowie eine
#' Anleitung. Zeile 1 jedes Datenblatts enthält die Maschinenschlüssel (Pfade, ausgeblendet),
#' Zeile 2 die deutschen Überschriften, ab Zeile 3 folgen die Daten; gelbe Zellen sind Eingaben,
#' graue Zellen Angaben der Vorlage. Die Blätter sind ohne Kennwort geschützt: Maschinenschlüssel,
#' Pfade, Überschriften und Vorgaben sind gesperrt, Eingabezellen, freie Zeilen am Blattende und
#' freie Spalten im Blatt „Zeitreihen“ bleiben bearbeitbar.
#'
#' Mit `example` wird ein Szenario in die Vorlage eingetragen; die Datei entspricht dann
#' `vofi_write_scenario(szenario, path)` und lässt sich mit `vofi_read_scenario()` verlustfrei
#' wieder einlesen. Die mitgelieferte Vorlage `inst/templates/vofi_eingabe.xlsx` erzeugt
#' `data-raw/build_template.R`.
#'
#' @param path Zieldatei (`.xlsx`).
#' @param example optional: Name eines Beispielszenarios (`vofi_example()`) oder ein Objekt der
#'   Klasse `vofi_scenario`, das in die Vorlage eingetragen wird.
#' @param overwrite vorhandene Datei überschreiben.
#' @return `invisible(path)`.
#' @family Einlesen
#' @examples
#' f <- tempfile(fileext = ".xlsx")
#' vofi_excel_template(f, example = "skeleton")
#' openxlsx::getSheetNames(f)
#' sc <- vofi_read_scenario(f)
#' sc$meta$scenario_id
#' @export
vofi_excel_template <- function(path, example = NULL, overwrite = FALSE) {
  if (!utl_is_string(path) || !nzchar(path)) {
    vofi_abort("core.arg_scalar", arg = "path", .class = "vofi_error_input")
  }
  if (!utl_is_flag(overwrite)) {
    vofi_abort("core.arg_flag", arg = "overwrite", .class = "vofi_error_input")
  }
  if (!identical(tolower(tools::file_ext(path)), "xlsx")) {
    vofi_abort("excel_input.extension", path = path, .class = "vofi_error_input")
  }
  if (file.exists(path) && !overwrite) {
    vofi_abort("excel_input.file_exists", path = path, .class = "vofi_error_input")
  }
  x <- NULL
  if (!is.null(example)) {
    sc <- if (inherits(example, "vofi_scenario")) {
      example
    } else if (utl_is_string(example)) {
      vofi_read_scenario(vofi_example(example))
    } else {
      vofi_abort("excel_input.example_invalid", .class = "vofi_error_input")
    }
    x <- scn_input_tree(sc)
  }
  wb <- io_xl_workbook(x)
  io_xl_save(wb, path)
  invisible(path)
}

# ---------------------------------------------------------------------------------------------
# Blaetter, Rollen, Spalten
# ---------------------------------------------------------------------------------------------

#' Version des Vorlagenlayouts (Blatt _meta)
#' @noRd
io_xl_template_version <- function() 1L

#' Rollen der Blätter in Reihenfolge der Arbeitsmappe
#' @noRd
io_xl_roles <- function() {
  c("instructions", "project", "household", "market", "building", "unit_groups", "measures",
    "funding", "financing", "components", "series", "settings", "parameters", "processes",
    "correlations", "variants", "scenario_sets", "lists", "meta")
}

#' Layoutart einer Rolle
#' @noRd
io_xl_kind <- function(role) {
  switch(role,
    instructions = "text",
    project = , household = , market = , building = , settings = "kv",
    unit_groups = , measures = , funding = , financing = , parameters = "wide",
    components = , processes = , variants = , scenario_sets = "long",
    series = "series", correlations = "corr", lists = "lists", meta = "meta",
    NA_character_
  )
}

#' Oberste Blöcke der Schlüssel-Wert-Blätter
#' @noRd
io_xl_kv_blocks <- function(role) {
  switch(role,
    project = c("meta", "project", "grid", "accounts", "residual_value", "tax", "analysis"),
    household = "household", market = c("market", "shared"), building = c("building", "energy"),
    settings = "stochastic",
    character(0)
  )
}

#' Rolle eines obersten Blocks (Sammlungen und Overlay; NA = Blatt _meta)
#' @noRd
io_xl_block_role <- function(block) {
  for (r in c("project", "household", "market", "building")) {
    if (block %in% io_xl_kv_blocks(r)) return(r)
  }
  switch(block, unit_groups = "unit_groups", measures = "measures", funding = "funding",
         financing = "financing", components = "components", stochastic = "settings",
         variants = "variants", scenario_sets = "scenario_sets", NA_character_)
}

#' Blattname einer Rolle (Label-Katalog)
#' @noRd
io_xl_sheet_name <- function(role) lbl(paste0("excel_input.sheets.", role))

#' Feste Spalten (Maschinenschlüssel) der Blätter ohne katalogabhängige Spalten
#' @noRd
io_xl_fixed_columns <- function(role) {
  switch(io_xl_kind(role),
    kv = c("path", "label", "unit", "form", "value", "options", "default", "default_source",
           "source", "note", ".seq"),
    long = switch(role,
      components = c(".id", "type", ".param", ".label", ".unit", ".form", ".value", ".options",
                     ".source", ".note", ".order"),
      processes = c(".key", "target", "type", ".param", ".form", ".value", ".options",
                    ".note", ".order"),
      variants = c(".id", "label", "description", "extends", ".action", ".path", ".form",
                   ".value", ".options", ".note", ".order"),
      scenario_sets = c(".id", "label", "description", ".action", ".path", ".form", ".value",
                        ".options", ".note", ".order")
    ),
    series = c(".id", ".label", ".form", ".unit", ".options"),
    corr = c(".kind", ".a", ".b", ".rho", ".value", ".note"),
    meta = c(".key", ".value", ".extra"),
    character(0)
  )
}

#' Deutsche Überschrift eines Maschinenschlüssels (feste Spalten)
#' @noRd
io_xl_column_label <- function(key) {
  lbl(paste0("excel_input.columns.", sub("^[.]", "", key)))
}

#' Spalten der breiten Blätter (Element je Zeile)
#'
#' Felder des Katalogs bzw. der Typparameter; Maps mit fester Feldliste werden in Unterspalten
#' (`rent_law.levy`) zerlegt, freie Maps, Sequenzen und Zahlenlisten belegen eine Spalte (YAML).
#' @return Liste von Spalten `list(key, label, param, types)`; `types` = Typen, die den
#'   Parameter kennen (nur Finanzierung).
#' @noRd
io_xl_wide_columns <- function(role) {
  st <- io_xl_cache()
  if (!is.null(st$wide[[role]])) return(st$wide[[role]])
  col <- function(key, param = NULL, label = NULL, types = NULL) {
    list(key = key, param = param, label = label %||% io_xl_field_label(key), types = types)
  }
  special <- function(key) {
    list(key = key, param = NULL, label = io_xl_column_label(key), types = NULL)
  }
  cols <- switch(role,
    unit_groups = , measures = , funding = {
      fields <- val_schema_catalog()[[role]]
      front <- if (role == "funding") {
        list(col("from", io_xl_meta_param("string")), col("use", io_xl_meta_param("string")))
      } else {
        list()
      }
      c(list(special(".id")), front, io_xl_flatten_fields(fields, ""))
    },
    financing = io_xl_financing_columns(),
    parameters = {
      f <- val_schema_catalog()[["stochastic.parameters"]]
      c(list(special(".key"), col("target", f$target), col("label", f$label),
             col("dist", f$dist)),
        lapply(paste0(".p", 1:4), special),
        list(col("apply", f$apply), col("base", f$base), col("from", f$from),
             col("use", f$use), col("description", f$description)))
    }
  )
  tail_cols <- list(special(".note"), special(".order"))
  if (role != "parameters") tail_cols <- c(list(special(".source")), tail_cols)
  cols <- c(cols, list(special(".extra")), tail_cols)
  st$wide[[role]] <- cols
  cols
}

#' Felder in Spalten zerlegen (Maps mit fester Feldliste rekursiv)
#' @noRd
io_xl_flatten_fields <- function(fields, prefix) {
  out <- list()
  for (f in names(fields)) {
    if (f == ".key") next
    p <- fields[[f]]
    key <- path_join(prefix, f)
    if (io_xl_param_is_fixed_map(p)) {
      out <- c(out, io_xl_flatten_fields(p$fields, key))
    } else {
      out[[length(out) + 1L]] <- list(key = key, param = p, label = io_xl_field_label(key),
                                      types = NULL)
    }
  }
  out
}

#' Ist der Parameter eine Map mit fester Feldliste (keine freie Map, keine Sequenz)?
#' @noRd
io_xl_param_is_fixed_map <- function(p) {
  identical(p$kind, "map") && !isTRUE(p$extra[["free"]]) && !isTRUE(p$extra[["any"]]) &&
    !isTRUE(p$extra[["sequence"]]) && length(setdiff(names(p$fields), ".key")) > 0L
}

#' Spalten des Blatts Finanzierung: Metafelder, dann Parameter aller Finanzierungstypen
#' @noRd
io_xl_financing_columns <- function() {
  types <- io_xl_financing_types()
  meta <- c("type", "label", "description", "after", "asset_id", "measure_id", "funding_id",
            "program")
  out <- list(list(key = ".id", param = NULL, label = io_xl_column_label(".id"), types = NULL))
  for (m in meta) {
    p <- if (m == "after") io_xl_meta_param("ids") else io_xl_meta_param("string")
    out[[length(out) + 1L]] <- list(key = m, param = p, label = io_xl_field_label(m),
                                    types = NULL)
  }
  seen <- character(0)
  for (t in types) {
    def <- scn_type_def(t, "financing")
    if (is.null(def)) next
    for (pn in names(def$params)) {
      p <- def$params[[pn]]
      keys <- if (io_xl_param_is_fixed_map(p)) {
        vapply(io_xl_flatten_fields(p$fields, pn), function(e) e$key, "")
      } else {
        pn
      }
      for (k in keys) {
        if (k %in% seen) next
        seen <- c(seen, k)
        has <- types[vapply(types, function(tt) {
          d <- scn_type_def(tt, "financing")
          !is.null(d) && !is.null(val_walk_fields(d$params, path_split(k)))
        }, logical(1))]
        out[[length(out) + 1L]] <- list(
          key = k, param = val_walk_fields(def$params, path_split(k)),
          label = io_xl_type_param_label("financing", t, k), types = has
        )
      }
    }
  }
  out
}

#' Typen des Blatts Finanzierung (equity und alle Kredittypen der Registry)
#' @noRd
io_xl_financing_types <- function() {
  inst <- reg_list("instrument")$name
  c(if (reg_has("flow", "equity")) "equity", utl_sort(inst))
}

# ---------------------------------------------------------------------------------------------
# Feldbeschreibungen, Labels, Einheiten, Formate
# ---------------------------------------------------------------------------------------------

#' Zwischenspeicher des Layouts (Katalogabhängiges wird je Sitzung einmal berechnet)
#' @noRd
io_xl_cache <- function() {
  if (is.null(io_xl_state_env$cache)) io_xl_state_env$cache <- new.env(parent = emptyenv())
  io_xl_state_env$cache
}

io_xl_state_env <- new.env(parent = emptyenv())

#' Zwischenspeicher leeren (nach Registrierung neuer Typen)
#' @noRd
io_xl_cache_reset <- function() {
  io_xl_state_env$cache <- NULL
  invisible(NULL)
}

#' Parameterbeschreibung der Metafelder (string, ids)
#' @noRd
io_xl_meta_param <- function(kind) {
  st <- io_xl_cache()
  key <- paste0("meta_", kind)
  if (is.null(st[[key]])) st[[key]] <- vofi_param(kind)
  st[[key]]
}

#' Parameterbeschreibung eines Pfads (Katalog bzw. Typparameter)
#'
#' Wie `val_param_at()`; Komponenten und Finanzierungsbausteine über die Typen aus `types`
#' (benannter Vektor `"components.<id>"` -> Typ). Metafelder sind Zeichenketten, `after` eine
#' id-Liste.
#' @param path Pfad.
#' @param types benannter Zeichenvektor der Typen.
#' @return `vofi_param` oder `NULL`.
#' @noRd
io_xl_param_at <- function(path, types = character(0)) {
  segs <- path_split(path)
  if (length(segs) < 2L) return(NULL)
  if (segs[1L] %in% c("components", "financing")) {
    if (length(segs) < 3L) return(NULL)
    if (length(segs) == 3L && segs[3L] == "after") return(io_xl_meta_param("ids"))
    if (length(segs) == 3L && segs[3L] %in% reg_reserved_fields()) {
      return(io_xl_meta_param("string"))
    }
    key <- path_join(segs[1L], segs[2L])
    type <- if (key %in% names(types)) types[[key]] else NA_character_
    def <- scn_type_def(type, segs[1L])
    if (is.null(def)) return(NULL)
    return(val_walk_fields(def$params, segs[-(1:2)]))
  }
  if (segs[1L] == "stochastic" && length(segs) >= 4L &&
        segs[2L] %in% c("parameters", "processes") && length(segs) > 4L) {
    return(NULL)
  }
  tryCatch(val_param_at(list(), path), error = function(e) NULL)
}

#' Parameterbeschreibung des Ziels einer Operation in Varianten und Szenario-Sets
#'
#' Die Werte von `set`, `replace`, `add` und `overrides` zielen auf Szenariopfade (in Sets auch
#' mit Platzhalter `*`, z. B. `funding.*.approved`). Leser und Schreiber deuten sie nach dem
#' Schema dieses Ziels wie in den übrigen Blättern (Datumszellen, deutsche Bezeichnungen der
#' Auswahllisten, Text statt Zahl bei Zeichenketten). Andere Felder (`generate`) haben kein Schema.
#' @param field Feld der Variante bzw. des Sets.
#' @param target Zielpfad (relativ zur Szenariowurzel) oder `NULL`.
#' @param types benannter Zeichenvektor der Typen (`io_xl_param_at()`).
#' @return `vofi_param` oder `NULL`.
#' @noRd
io_xl_variant_param <- function(field, target, types = character(0)) {
  if (!(field %in% c("set", "replace", "add", "overrides")) || !utl_is_string(target) ||
        !nzchar(target)) {
    return(NULL)
  }
  io_xl_param_at(target, types)
}

#' Deutsche Bezeichnung eines Felds (letztes Pfadsegment; Platzhalter `*` übersprungen)
#' @noRd
io_xl_field_label <- function(path) {
  segs <- path_split(path)
  segs <- segs[segs != "*"]
  if (length(segs) == 0L) return(path)
  name <- segs[length(segs)]
  lbl(paste0("excel_input.fields.", name), .default = io_xl_code_label_any(name))
}

#' Bezeichnung eines Typparameters (Label der Typdatei, sonst Feldbezeichnung)
#' @param coll `"components"` bzw. `"financing"`.
#' @noRd
io_xl_type_param_label <- function(coll, type, relpath) {
  def <- scn_type_def(type, coll)
  segs <- path_split(relpath)
  if (!is.null(def) && length(segs) == 1L && identical(reg_source(def$kind, def$name), "vofi")) {
    key <- paste0(reg_label_prefix(def), ".params.", segs[1L], ".label")
    if (lbl_has(key)) return(lbl(key))
  }
  io_xl_field_label(relpath)
}

#' Einheitencode eines Felds (Schema, sonst Schlüsselsuffix nach 4.3)
#' @noRd
io_xl_unit_code <- function(param, path) {
  if (!is.null(param) && utl_is_string(param$unit)) return(param$unit)
  kind <- param$kind %||% "value"
  if (kind == "rate") return("rate_pa")
  if (kind == "share") return("share")
  if (kind == "amount") return("EUR")
  if (kind == "date") return("date")
  if (kind == "logical") return("flag")
  segs <- path_split(path)
  last <- if (length(segs) > 0L) segs[length(segs)] else ""
  suffixes <- c(eur_m2_month = "EUR_m2_month", eur_m2_pa = "EUR_m2_pa", eur_m2 = "EUR_m2",
                eur_kwh = "EUR_kwh", eur_kwp = "EUR_kwp", eur_t = "EUR_t", eur_pa = "EUR_pa",
                eur_month = "EUR_month", eur = "EUR", kwh_pa = "kWh_pa", kwh = "kWh",
                kwp = "kWp", kw = "kW", kg_kwh = "kg_kwh", m2 = "m2", share = "share",
                months = "months", years = "years", year = "year", date = "date")
  for (s in names(suffixes)) {
    if (last == s || endsWith(last, paste0("_", s))) return(suffixes[[s]])
  }
  if (grepl("_pa$", last) && node_is_rate_target(kind, path)) return("rate_pa")
  NA_character_
}

#' Anzeige der Einheit bzw. Eingabeart eines Felds
#' @noRd
io_xl_unit_label <- function(param, path) {
  u <- io_xl_unit_code(param, path)
  if (!is.na(u)) return(lbl(paste0("vocab.units.", u), .default = u))
  kind <- param$kind %||% ""
  if (kind %in% c("enum", "ids", "timing", "string", "schedule", "map", "integer")) {
    return(lbl(paste0("excel_input.kinds.", kind)))
  }
  ""
}

#' Zahlenformat eines Felds (englische Formatsyntax, Memo 05 4.10)
#' @noRd
io_xl_num_fmt <- function(param, path) {
  u <- io_xl_unit_code(param, path)
  if (is.na(u)) return(NULL)
  if (u %in% c("EUR", "EUR_pa")) return("#,##0 \u20ac")
  if (u %in% c("EUR_month", "EUR_m2", "EUR_m2_month", "EUR_m2_pa", "EUR_unit", "EUR_t")) {
    return("#,##0.00 \u20ac")
  }
  if (u %in% c("EUR_kwh", "EUR_kwp")) return("#,##0.0000 \u20ac")
  if (u %in% c("rate_pa", "share")) return("0.00%")
  if (u == "date") return("DATE")
  NULL
}

#' Bezeichnung eines Blocks bzw. einer Sammlung
#' @noRd
io_xl_block_label <- function(path) {
  key <- gsub(".", "_", sub("[.][*]$", "", path), fixed = TRUE)
  lbl(paste0("excel_input.blocks.", key), .default = path)
}

# ---------------------------------------------------------------------------------------------
# Auswahllisten (Blatt Listen)
# ---------------------------------------------------------------------------------------------

#' Name der Auswahlliste eines Parameters (`NULL` = keine Liste)
#' @noRd
io_xl_param_list <- function(param) {
  if (is.null(param)) return(NULL)
  if (identical(param$kind, "logical")) return("logical")
  if (!identical(param$kind, "enum")) return(NULL)
  vals <- param$values
  if (length(vals) == 1L && startsWith(vals, "vocab:")) {
    return(paste0("enum:", sub("^vocab:", "", vals)))
  }
  if (all(vals %in% vocab_codes("measure_types"))) return("vocab:measure_types")
  if (all(vals %in% vocab_codes("asset_types"))) return("vocab:asset_types")
  paste0("codes:", paste(vals, collapse = ","))
}

#' Inhalt einer Auswahlliste: Data Frame `code`, `label` (Bezeichnungen eindeutig)
#' @noRd
io_xl_list <- function(name) {
  st <- io_xl_cache()
  st$lists <- st$lists %||% list()
  if (!is.null(st$lists[[name]])) return(st$lists[[name]])
  kind <- sub(":.*$", "", name)
  arg <- sub("^[^:]*:", "", name)
  out <- switch(kind,
    logical = data.frame(code = c("ja", "nein"),
                         label = c(lbl("excel_input.logical.true"),
                                   lbl("excel_input.logical.false")),
                         stringsAsFactors = FALSE),
    enum = {
      codes <- vocab_codes(paste0("vocab:", arg))
      io_xl_list_df(codes, vapply(codes, function(cd) {
        lbl(paste0("vocab.enums.", arg, ".", cd), .default = io_xl_code_label_any(cd))
      }, ""))
    },
    vocab = {
      codes <- vocab_codes(arg)
      io_xl_list_df(codes, vapply(codes, function(cd) {
        lbl(paste0("vocab.", arg, ".", cd), .default = cd)
      }, ""))
    },
    codes = {
      codes <- strsplit(arg, ",", fixed = TRUE)[[1L]]
      io_xl_list_df(codes, vapply(codes, io_xl_code_label_any, ""))
    },
    types = {
      defs <- switch(arg,
        flow = lapply(reg_list("flow")$name, function(n) reg_get("flow", n)),
        financing = lapply(io_xl_financing_types(), function(n) scn_type_def(n, "financing")),
        distribution = lapply(reg_list("distribution")$name,
                              function(n) reg_get("distribution", n)),
        process = lapply(reg_list("process")$name, function(n) reg_get("process", n))
      )
      codes <- vapply(defs, function(d) d$name, "")
      io_xl_list_df(codes, vapply(defs, function(d) {
        reg_type_label(d, reg_source(d$kind, d$name))
      }, ""))
    },
    forms = {
      codes <- c("const", "series_t", "series_year", "points", "schedule", "ref", "growth",
                 "expr", "quantity", "auto", "from", "dist")
      io_xl_list_df(codes, vapply(codes, function(cd) {
        lbl(paste0("vocab.enums.value_form.", cd), .default = cd)
      }, ""))
    },
    actions = {
      codes <- if (arg == "sets") {
        c("set", "replace", "add", "remove", "overrides", "generate")
      } else {
        c("set", "replace", "add", "remove", "overrides")
      }
      io_xl_list_df(codes, vapply(codes, function(cd) lbl(paste0("excel_input.actions.", cd)),
                                  ""))
    },
    corr = {
      codes <- c("parameters", "shocks")
      io_xl_list_df(codes, vapply(codes, function(cd) {
        lbl(paste0("excel_input.correlation_kinds.", cd))
      }, ""))
    },
    library = {
      lib <- io_xl_library_table(arg)
      io_xl_list_df(lib$entry, ifelse(is.na(lib$label) | !nzchar(lib$label), lib$entry,
                                      paste0(lib$entry, " - ", lib$label)))
    },
    data.frame(code = character(0), label = character(0), stringsAsFactors = FALSE)
  )
  st$lists[[name]] <- out
  out
}

#' Bibliothekseinträge eines Blocks für die Auswahlliste (Paketbibliothek und Pfade der Option)
#' @noRd
io_xl_library_table <- function(block) {
  tab <- tryCatch(suppressWarnings(suppressMessages(vofi_library(block = block))),
                  error = function(e) NULL)
  if (is.null(tab) || nrow(tab) == 0L) {
    return(data.frame(entry = character(0), label = character(0), stringsAsFactors = FALSE))
  }
  tab[, c("entry", "label")]
}

#' Liste mit eindeutigen Bezeichnungen (Dubletten und Codes als Bezeichnung mit Code-Zusatz)
#' @noRd
io_xl_list_df <- function(codes, labels) {
  codes <- as.character(codes)
  labels <- enc2utf8(as.character(labels))
  labels[is.na(labels) | !nzchar(labels)] <- codes[is.na(labels) | !nzchar(labels)]
  clash <- (duplicated(labels) | duplicated(labels, fromLast = TRUE) |
              (labels %in% codes & labels != codes))
  labels[clash] <- paste0(labels[clash], " (", codes[clash], ")")
  data.frame(code = codes, label = labels, stringsAsFactors = FALSE)
}

#' Bezeichnung eines Codes ohne bekanntes Vokabular (erstes Enum mit diesem Code)
#' @noRd
io_xl_code_label_any <- function(code) {
  enums <- vocab_state$data[["enums"]] %||% list()
  for (e in names(enums)) {
    if (code %in% enums[[e]]$codes) {
      key <- paste0("vocab.enums.", e, ".", code)
      if (lbl_has(key)) return(lbl(key))
    }
  }
  for (v in c("measure_types", "asset_types")) {
    key <- paste0("vocab.", v, ".", code)
    if (lbl_has(key)) return(lbl(key))
  }
  code
}

# ---------------------------------------------------------------------------------------------
# Vorgaben (Spalte Vorgabe und ihre Herkunft)
# ---------------------------------------------------------------------------------------------

#' Defaults-Dateien für die Anzeige der Vorgaben (je Sitzung einmal gelesen)
#' @noRd
io_xl_defaults_files <- function() {
  st <- io_xl_cache()
  if (!is.null(st$defaults)) return(st$defaults)
  read <- function(f) {
    if (!nzchar(f) || !file.exists(f)) return(list())
    tryCatch(io_read_yaml_utf8(f), error = function(e) list())
  }
  glob <- read(system.file("extdata", "defaults", "global.yaml", package = "vofi"))
  pdir <- system.file("extdata", "profiles", package = "vofi")
  pfiles <- character(0)
  if (nzchar(pdir)) pfiles <- list.files(pdir, pattern = "\\.yaml$", full.names = TRUE)
  st$defaults <- list(global = glob, profiles = lapply(pfiles, read))
  st$defaults
}

#' Vorgabe eines Felds: Text und Herkunft (Typ-Default, global.yaml, Profil, Ableitungsregel)
#' @param path Pfad (Platzhalter `*` für Sammlungselemente).
#' @param param `vofi_param` oder `NULL`.
#' @return Liste `text`, `source` (Zeichenketten, ggf. leer).
#' @noRd
io_xl_default_info <- function(path, param) {
  d <- io_xl_defaults_files()
  segs <- path_split(path)
  none <- list(text = "", source = "")
  if (length(segs) < 2L) return(none)
  for (pr in d$profiles) {
    if (path_exists(pr, path)) {
      return(list(text = "", source = lbl("excel_input.default_sources.profile")))
    }
  }
  g <- d$global
  val <- NULL
  if (path_exists(g, path)) {
    val <- path_get(g, path)
  } else {
    items <- g$item_defaults %||% list()
    for (k in rev(seq_along(segs))) {
      head <- paste(segs[seq_len(k)], collapse = ".")
      key <- gsub(".*", "", head, fixed = TRUE)
      if (k < length(segs) && key %in% names(items)) {
        rest <- segs[-seq_len(k)]
        rest <- rest[rest != "*"]
        if (length(rest) > 0L && path_exists(items[[key]], paste(rest, collapse = "."))) {
          val <- path_get(items[[key]], paste(rest, collapse = "."))
          break
        }
      }
    }
  }
  if (!is.null(val)) {
    return(list(text = io_xl_display(val), source = lbl("excel_input.default_sources.global")))
  }
  rules <- scn_rule_fields()
  parent <- gsub(".*", "", paste(segs[-length(segs)], collapse = "."), fixed = TRUE)
  parent <- sub("^(measures|unit_groups|funding)[.][^.]+", "\\1", parent)
  parent <- sub("^(energy[.]carriers|building[.]elements)[.][^.]+", "\\1", parent)
  if (segs[length(segs)] %in% rules[[parent]]) {
    return(list(text = "", source = lbl("excel_input.default_sources.rule")))
  }
  if (!is.null(param$default)) {
    return(list(text = io_xl_display(param$default),
                source = lbl("excel_input.default_sources.type")))
  }
  if (identical(param$kind, "enum") && length(param$values) == 1L &&
        startsWith(param$values, "vocab:")) {
    def <- tryCatch(vocab(sub("^vocab:", "", param$values))$default, error = function(e) NULL)
    if (utl_is_string(def)) {
      return(list(text = def, source = lbl("excel_input.default_sources.vocab")))
    }
  }
  none
}

#' Anzeige eines Werts in YAML-Form (Zeichenketten ohne Anführungszeichen)
#' @noRd
io_xl_display <- function(x) {
  if (is.character(x) && length(x) == 1L && !is.na(x)) return(x)
  if (inherits(x, "Date") && length(x) == 1L) return(format(x, "%Y-%m-%d"))
  io_xl_flow(x)
}

# ---------------------------------------------------------------------------------------------
# Zeilen der Schlüssel-Wert-Blätter (Vorlage)
# ---------------------------------------------------------------------------------------------

#' Vorlagenzeilen eines Blocks (Kopfzeile, Felder in Katalogreihenfolge)
#' @return Liste von Zeilen `list(path, label, param, header)`.
#' @noRd
io_xl_kv_template <- function(block) {
  st <- io_xl_cache()
  st$kv <- st$kv %||% list()
  if (!is.null(st$kv[[block]])) return(st$kv[[block]])
  hdr <- function(path) {
    list(path = path, label = io_xl_block_label(path), param = NULL, header = TRUE)
  }
  cat <- val_schema_catalog()
  rows <- list(hdr(block))
  # Zeilen der Felder rekursiv als Rueckgabewert (keine Akkumulation per <<-, 2.7 Nr. 3)
  field_rows <- function(fields, prefix) {
    out <- list()
    for (f in names(fields)) {
      if (f == ".key") next
      p <- fields[[f]]
      path <- path_join(prefix, f)
      coll <- p$extra[["collection"]]
      out <- c(out, if (utl_is_string(coll)) {
        c(list(hdr(path)), field_rows(cat[[coll]], path_join(path, "*")))
      } else if (io_xl_param_is_fixed_map(p)) {
        c(list(hdr(path)), field_rows(p$fields, path))
      } else {
        list(list(path = path, label = io_xl_field_label(path), param = p, header = FALSE))
      })
    }
    out
  }
  if (block == "stochastic") {
    rows <- c(rows, list(hdr("stochastic.settings")),
              field_rows(cat[["stochastic.settings"]], "stochastic.settings"))
  } else if (block == "market") {
    for (path in io_xl_market_paths()) {
      rows[[length(rows) + 1L]] <- list(path = path, label = io_xl_market_label(path),
                                        param = NULL, header = FALSE)
    }
  } else if (!is.null(cat[[block]])) {
    rows <- c(rows, field_rows(cat[[block]], block))
  }
  st$kv[[block]] <- rows
  rows
}

#' Kanonische Marktnamen (Spec 00 4.3.11) als Zeilen des Blatts Markt
#' @noRd
io_xl_market_paths <- function() {
  carriers <- c("gas", "gas_mfh", "oil", "lpg", "power", "power_mfh", "heatpump_power",
                "heatpump_power_mfh", "district_heating", "pellets")
  feed_in <- c("partial_le10kwp", "partial_10_40kwp", "partial_40_100kwp", "full_le10kwp")
  c("market.from", "market.use", "market.inflation", "market.rent_growth",
    "market.rent_growth_new", "market.construction_price_index", "market.maintenance_index",
    "market.land_value_growth", "market.market_value_growth", "market.operating_cost_growth",
    "market.mortgage_rate", "market.bund_yield_10y", "market.mortgage_spread",
    "market.co2_price", paste0("market.energy_price.", carriers),
    paste0("market.energy_network_fee.", carriers), "market.bio_fuel_premium",
    paste0("market.feed_in_tariff.", feed_in), "market.vacancy_fluctuation")
}

#' Bezeichnung eines Marktpfads (Name und ggf. Träger bzw. Vergütungsklasse)
#' @noRd
io_xl_market_label <- function(path) {
  segs <- path_split(path)
  if (length(segs) < 2L) return(path)
  base <- lbl(paste0("excel_input.market.", segs[2L]), .default = segs[2L])
  if (length(segs) >= 3L) {
    sub_lbl <- lbl(paste0("excel_input.carriers.", segs[3L]), .default = segs[3L])
    return(paste0(base, ": ", sub_lbl))
  }
  base
}

#' Einheit und Format der Marktpfade (Raten, Energiepreise, CO2-Preis)
#' @noRd
io_xl_market_unit <- function(path) {
  segs <- path_split(path)
  nm <- if (length(segs) >= 2L) segs[2L] else ""
  if (nm %in% scn_market_rate_names()) return("rate_pa")
  if (nm %in% c("energy_price", "energy_network_fee", "bio_fuel_premium", "feed_in_tariff")) {
    return("EUR_kwh")
  }
  if (nm == "co2_price") return("EUR_t")
  if (nm == "vacancy_fluctuation") return("factor")
  NA_character_
}

# ---------------------------------------------------------------------------------------------
# YAML-Flussnotation (verlustfrei; Gegenstueck ist der YAML-Leser mit den Handlern aus 4.6)
# ---------------------------------------------------------------------------------------------

#' Wert in YAML-Flussnotation (einzeilig)
#'
#' Knoten werden in die Wertgrammatik zurückgeführt (`node_to_yaml()`), Zeichenketten stehen in
#' doppelten Anführungszeichen, Zahlen in der kürzesten verlustfreien Darstellung
#' (`io_fmt_num()`), Datumswerte als `"JJJJ-MM-TT"`, `NULL` als `~`, leere Maps als `{}`, leere
#' Sequenzen als `[]`.
#' @param x Wert.
#' @return Zeichenkette.
#' @noRd
io_xl_flow <- function(x) {
  if (is.null(x)) return("~")
  if (node_is(x)) return(io_xl_flow(node_to_yaml(x)))
  if (is.factor(x)) x <- as.character(x)
  if (inherits(x, "Date")) {
    s <- io_xl_quote(format(x, "%Y-%m-%d"))
    return(if (length(x) == 1L) s else paste0("[", paste(s, collapse = ", "), "]"))
  }
  if (is.list(x) && !is.data.frame(x)) {
    if (length(x) == 0L) return(if (is.null(names(x))) "[]" else "{}")
    parts <- vapply(x, io_xl_flow, "", USE.NAMES = FALSE)
    if (is.null(names(x))) return(paste0("[", paste(parts, collapse = ", "), "]"))
    return(paste0("{", paste0(io_xl_flow_str(names(x)), ": ", parts, collapse = ", "), "}"))
  }
  one <- if (is.logical(x)) {
    ifelse(is.na(x), "~", ifelse(x, "true", "false"))
  } else if (is.numeric(x)) {
    io_fmt_num(x)
  } else if (is.character(x)) {
    ifelse(is.na(x), "~", io_xl_flow_str(x))
  } else {
    io_xl_quote(paste(format(x), collapse = " "))
  }
  if (length(x) == 1L) return(unname(one))
  paste0("[", paste(one, collapse = ", "), "]")
}

#' Zeichenkette in Flussnotation: ohne Anführungszeichen, wenn YAML sie unverändert als Text
#' liest (Bezeichner, Pfade, Bibliotheks-ids), sonst in doppelten Anführungszeichen
#' @noRd
io_xl_flow_str <- function(s) {
  s <- enc2utf8(as.character(s))
  plain <- grepl("^[A-Za-z_][A-Za-z0-9_./*-]*$", s) & !grepl("[.]$", s) &
    !(tolower(s) %in% c("true", "false", "yes", "no", "on", "off", "null", "y", "n"))
  ifelse(plain, s, io_xl_quote(s))
}

#' Zeichenkette in doppelten Anführungszeichen (YAML-Escapes)
#' @noRd
io_xl_quote <- function(s) {
  s <- enc2utf8(as.character(s))
  s <- gsub("\\", "\\\\", s, fixed = TRUE)
  s <- gsub("\"", "\\\"", s, fixed = TRUE)
  s <- gsub("\n", "\\n", s, fixed = TRUE)
  s <- gsub("\r", "\\r", s, fixed = TRUE)
  s <- gsub("\t", "\\t", s, fixed = TRUE)
  paste0("\"", s, "\"")
}

#' Kürzeste Zahldarstellung, die als double exakt zurückgelesen wird (Excel-Zelle)
#' @noRd
io_xl_num_text <- function(v) {
  v <- as.double(v)
  s <- ""
  for (d in 15:17) {
    s <- trimws(formatC(v, digits = d, format = "g"))
    if (identical(as.double(s), v)) break
  }
  s
}

# ---------------------------------------------------------------------------------------------
# Anleitung
# ---------------------------------------------------------------------------------------------

#' Zeilen des Blatts Anleitung: Liste `list(text, style)`
#' @noRd
io_xl_instruction_rows <- function() {
  row <- function(text, style = "text") list(text = text, style = style)
  lines <- function(text) lapply(strsplit(text, "\n", fixed = TRUE)[[1L]], row)
  sheets <- setdiff(io_xl_roles(), c("instructions", "lists", "meta"))
  forms <- io_xl_list("forms")
  c(
    list(row(lbl("excel_input.instructions.title"), "title")),
    lines(lbl("excel_input.instructions.intro")), list(row("")),
    list(row(lbl("excel_input.instructions.legend_title"), "subtitle"),
         row(lbl("excel_input.instructions.legend_input"), "input"),
         row(lbl("excel_input.instructions.legend_info"), "info"), row("")),
    list(row(lbl("excel_input.instructions.sheets_title"), "subtitle")),
    lapply(sheets, function(r) {
      row(paste0(io_xl_sheet_name(r), ": ", lbl(paste0("excel_input.sheet_help.", r))))
    }),
    list(row(""), row(lbl("excel_input.instructions.numbers_title"), "subtitle")),
    lines(lbl("excel_input.instructions.numbers")),
    list(row(""), row(lbl("excel_input.instructions.forms_title"), "subtitle")),
    lapply(seq_len(nrow(forms)), function(i) {
      row(paste0(forms$label[i], " (", forms$code[i], "): ",
                 lbl(paste0("excel_input.form_help.", forms$code[i]))))
    }),
    list(row(lbl("excel_input.form_help.timeseries")), row(""),
         row(lbl("excel_input.instructions.rows_title"), "subtitle")),
    lines(lbl("excel_input.instructions.rows")),
    list(row(""), row(lbl("excel_input.instructions.protection_title"), "subtitle")),
    lines(lbl("excel_input.instructions.protection"))
  )
}
