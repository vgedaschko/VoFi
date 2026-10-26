# Registry der Bausteintypen (Integrator, Spec 00 Abschnitt 5).
# Eingebaute Typen werden ausschließlich über typedef_*-Funktionen in .onLoad registriert (5.5);
# Registrierung auf oberster Dateiebene ist verboten.

reg_state <- new.env(parent = emptyenv())
reg_state$types <- list()

#' Arten der Registry (5.1)
#' @noRd
reg_kinds <- function() {
  c("flow", "instrument", "account_action", "expander", "distribution", "process", "kpi",
    "tax", "rule")
}

#' Reservierte Metafelder jeder Komponente (4.3.8)
#' @noRd
reg_reserved_fields <- function() {
  c("id", "type", "label", "description", "after", "origin", "asset_id", "measure_id",
    "funding_id", "program")
}

#' Pflicht- und optionale Funktionen je Art mit exakten Formals (5.1, 5.3)
#'
#' `NULL` als Formals bedeutet „beliebig“ (Regeln: identisch über alle Versionen).
#' @noRd
reg_fun_spec <- function(kind) {
  switch(kind,
    flow = list(required = list(build = c("spec", "ctx")),
                optional = list(validate = c("spec", "scenario"))),
    instrument = list(required = list(init = c("spec", "ctx"), step = c("state", "t", "ctx")),
                      optional = list(prepay = c("state", "amount", "t", "ctx"),
                                      capacity = c("state", "t", "ctx"),
                                      validate = c("spec", "scenario"))),
    account_action = list(required = list(apply = c("acc", "amount", "t", "ctx", "inst")),
                          optional = list()),
    expander = list(required = list(expand = c("block", "scenario", "bctx")),
                    optional = list()),
    distribution = list(required = list(quantile = c("u", "par"), point = c("par", "which"),
                                        moments = "par", validate = "par"),
                        optional = list()),
    process = list(required = list(simulate = c("par", "z", "u", "years", "linked"),
                                   expected = c("par", "years"), n_shocks = "par",
                                   n_uniforms = "par", validate = "par"),
                   optional = list(quantile_path = c("par", "years", "p"))),
    kpi = list(required = list(compute = c("core", "ctx")), optional = list()),
    tax = list(required = list(constructor = c("params", "spec")), optional = list()),
    rule = list(required = list(fun = NULL), optional = list()),
    list(required = list(), optional = list())
  )
}

#' Zulässige Domänenblöcke für `domain_reads` (5.2, 6.1 Nr. 3, R-93)
#' @noRd
reg_domain_blocks <- function() {
  c("measures", "funding", "financing", "energy", "unit_groups", "building", "household",
    "market")
}

#' Artspezifische Defaults der Typdefinition (5.2, 5.3)
#' @noRd
reg_kind_defaults <- function(kind) {
  switch(kind,
    flow = list(grid_invariant = FALSE),
    account_action = list(role = NULL, rank = NULL, unlimited = FALSE),
    expander = list(block = NULL, order = NULL),
    process = list(output = NULL, linked = character(0)),
    kpi = list(unit = "EUR", shape = "scalar", rv_variant = FALSE, higher_is_better = TRUE,
               mc_default = FALSE, requires = character(0)),
    tax = list(uses_inputs = TRUE, blocked_regimes = NULL),
    rule = list(rule_name = NULL, fun = NULL, valid_from = NULL, valid_to = NULL,
                reform = NULL, source = NULL, returns = NULL),
    list()
  )
}

#' Registry leeren (.onLoad)
#' @noRd
reg_reset <- function() {
  reg_state$types <- stats::setNames(rep(list(list()), length(reg_kinds())), reg_kinds())
  invisible(NULL)
}

#' Bausteintyp definieren
#'
#' Erzeugt die Definition eines Bausteintyps der Registry (Spec 00, Abschnitt 5.2). Neben den
#' allgemeinen Feldern (`labels`, `perspectives`, `rows`, `validate`, `grid_invariant`) nimmt
#' `...` die artspezifischen Felder und Funktionen auf (Abschnitt 5.3), z. B. `build` für
#' Zahlungskomponenten, `init`/`step` für Kreditinstrumente oder `compute` für Kennzahlen. Die
#' Vertragsprüfung erfolgt bei der Registrierung ([vofi_register_type()]) und in
#' [vofi_check_type()].
#'
#' @param name Name des Typs (`^[a-z][a-z0-9_]*$`; bei Rechtsregeln `"<regel>@<JJJJ-MM-TT>"`).
#' @param kind Art: `"flow"`, `"instrument"`, `"account_action"`, `"expander"`,
#'   `"distribution"`, `"process"`, `"kpi"`, `"tax"` oder `"rule"`.
#' @param params benannte Liste von [vofi_param()]-Objekten.
#' @param ... artspezifische Felder und Funktionen (benannt).
#' @param example Beispiel in Eingabeform wie in YAML (Pflicht für `flow`, `instrument`,
#'   `distribution`, `process`, `tax`).
#' @param label Anzeigename (nur Nutzertypen; eingebaute Typen verwenden den Label-Katalog).
#' @param version Version des Typs (ganze Zahl).
#' @return Objekt der Klasse `vofi_typedef`.
#' @family Erweitern
#' @examples
#' def <- vofi_type(
#'   name = "fixed_income", kind = "flow", label = "Feste Einnahme",
#'   labels = list(description = "Konstante Einnahme je Periode",
#'                 params = list(amount_eur = "Betrag"), rows = list(value = "Einnahme")),
#'   params = list(amount_eur = vofi_param("amount", required = TRUE)),
#'   rows = "value",
#'   build = function(spec, ctx) {
#'     v <- ctx$by_sim(ctx$param(spec, "amount_eur"))
#'     v[, 1] <- 0
#'     vofi_flows(vofi_row("value", v, section = "project", category = "other_income"))
#'   },
#'   example = list(type = "fixed_income", amount_eur = 1000)
#' )
#' class(def)
#' @export
vofi_type <- function(name, kind, params = list(), ..., example = NULL, label = NULL,
                      version = 1L) {
  if (!utl_is_string(kind) || !(kind %in% reg_kinds())) {
    vofi_abort("core.registry.kind_invalid", kind = utl_collapse(format(kind)),
               suggestion = utl_suggest_text(as.character(kind)[1L], reg_kinds()),
               .class = "vofi_error_registry")
  }
  if (!utl_is_string(name)) {
    vofi_abort("core.registry.name_invalid", name = utl_collapse(format(name)), kind = kind,
               .class = "vofi_error_registry")
  }
  dots <- list(...)
  if (length(dots) > 0L && (is.null(names(dots)) || any(!nzchar(names(dots))))) {
    vofi_abort("core.registry.fields_unnamed", name = name, .class = "vofi_error_registry")
  }
  base <- list(name = name, kind = kind, version = version, label = label, params = params,
               example = example)
  def <- c(base, dots)
  def <- utl_fill_defaults(def, c(list(labels = NULL, perspectives = NULL, rows = character(0),
                                       validate = NULL),
                                  if (kind %in% c("flow", "instrument")) {
                                    list(grid_invariant = FALSE, domain_reads = NULL)
                                  },
                                  reg_kind_defaults(kind)))
  if (kind == "rule") {
    rn <- def$rule_name %||% sub("@.*$", "", name)
    def$rule_name <- rn
    if (!is.null(def$valid_from)) {
      def$valid_from <- utl_as_date(def$valid_from, "valid_from")
      if (!grepl("@", name, fixed = TRUE)) def$name <- paste0(rn, "@", format(def$valid_from))
    } else if (grepl("@", name, fixed = TRUE)) {
      def$valid_from <- as.Date(sub("^.*@", "", name), optional = TRUE)
    }
    if (!is.null(def$valid_to)) def$valid_to <- utl_as_date(def$valid_to, "valid_to")
  }
  structure(def, class = "vofi_typedef")
}

#' Statische Vertragsprüfung einer Typdefinition (C1–C3, Abschnitt 5.6)
#' @param def `vofi_typedef`.
#' @return Data Frame `check`, `ok`, `message` (eine Zeile je Befund; leer = keine Befunde).
#' @noRd
reg_static_findings <- function(def) {
  acc <- new.env(parent = emptyenv())
  acc$out <- list()
  add <- function(check, key, ...) {
    acc$out[[length(acc$out) + 1L]] <- data.frame(check = check, ok = FALSE,
                                                  message = msg(key, ...),
                                                  stringsAsFactors = FALSE)
  }
  kind <- def$kind
  name <- def$name
  # C1 Namensmuster, Art, Version
  if (!(kind %in% reg_kinds())) {
    add("C1", "core.registry.kind_invalid", kind = kind, suggestion = "")
  }
  name_ok <- if (identical(kind, "rule")) {
    utl_is_string(name) && grepl("^[a-z][a-z0-9_]*@[0-9]{4}-[0-9]{2}-[0-9]{2}$", name) &&
      !grepl("__", name, fixed = TRUE)
  } else {
    utl_is_string(name) && utl_is_id(name)
  }
  if (!name_ok) add("C1", "core.registry.name_invalid", name = format(name), kind = kind)
  if (!utl_is_whole(def$version) || def$version < 1) {
    add("C1", "core.registry.version_invalid", name = format(name))
  }
  # C2 Pflichtfunktionen, exakte Formals
  fs <- reg_fun_spec(kind)
  for (fn in names(fs$required)) {
    f <- def[[fn]]
    if (!is.function(f)) {
      add("C2", "core.registry.fun_missing", name = format(name), fun = fn)
    } else if (!is.null(fs$required[[fn]]) &&
                 !identical(names(formals(f)), fs$required[[fn]])) {
      add("C2", "core.registry.fun_formals", name = format(name), fun = fn,
          expected = utl_collapse(fs$required[[fn]]),
          actual = utl_collapse(names(formals(f))))
    }
  }
  for (fn in names(fs$optional)) {
    f <- def[[fn]]
    if (!is.null(f)) {
      if (!is.function(f)) {
        add("C2", "core.registry.fun_missing", name = format(name), fun = fn)
      } else if (!identical(names(formals(f)), fs$optional[[fn]])) {
        add("C2", "core.registry.fun_formals", name = format(name), fun = fn,
            expected = utl_collapse(fs$optional[[fn]]),
            actual = utl_collapse(names(formals(f))))
      }
    }
  }
  if (identical(kind, "instrument") && xor(is.null(def$prepay), is.null(def$capacity))) {
    add("C2", "core.registry.fun_pair", name = format(name))
  }
  # C3 Parameterschema, reservierte Namen, Zeilen, Beispiel, artspezifische Felder
  params <- def$params
  if (!is.list(params) || (length(params) > 0L && is.null(names(params)))) {
    add("C3", "core.registry.params_invalid", name = format(name))
    params <- list()
  }
  for (p in names(params)) {
    if (!inherits(params[[p]], "vofi_param")) {
      add("C3", "core.registry.param_class", name = format(name), param = p)
    }
    if (!utl_is_id(p)) add("C3", "core.registry.param_name", name = format(name), param = p)
    if (p %in% reg_reserved_fields()) {
      add("C3", "core.registry.param_reserved", name = format(name), param = p)
    }
  }
  # from/use bezeichnen ausschliesslich den Bibliotheksverweis (4.9, R-110), auch in map-Feldern
  for (p in reg_library_key_params(params)) {
    add("C3", "core.registry.param_library_key", name = format(name), param = p)
  }
  if (anyDuplicated(names(params))) {
    add("C3", "core.registry.params_invalid", name = format(name))
  }
  rows <- def$rows
  if (!is.character(rows) || anyDuplicated(rows)) {
    add("C3", "core.registry.rows_invalid", name = format(name), row = utl_collapse(rows))
  } else {
    for (r in rows) {
      ok <- if (endsWith(r, "_*")) {
        identical(kind, "flow") && utl_is_id(substr(r, 1L, nchar(r) - 2L))
      } else if (identical(kind, "account_action")) {
        utl_is_id(r) || identical(r, "loan_*_prepay")
      } else {
        utl_is_id(r)
      }
      if (!ok) add("C3", "core.registry.rows_invalid", name = format(name), row = r)
    }
  }
  if (!is.null(def$perspectives) &&
        (!is.character(def$perspectives) ||
           !all(def$perspectives %in% vocab_codes("perspective")))) {
    add("C3", "core.registry.field_invalid", name = format(name), field = "perspectives")
  }
  if (!is.null(def$validate) && !(kind %in% c("flow", "instrument", "distribution", "process"))) {
    add("C3", "core.registry.field_invalid", name = format(name), field = "validate")
  }
  if (kind %in% c("flow", "instrument") && !utl_is_flag(def$grid_invariant)) {
    add("C3", "core.registry.field_invalid", name = format(name), field = "grid_invariant")
  }
  dr <- def[["domain_reads"]]
  if (!is.null(dr) &&
        (!(kind %in% c("flow", "instrument")) || !is.character(dr) || anyNA(dr) ||
           anyDuplicated(dr) || !all(dr %in% reg_domain_blocks()))) {
    add("C3", "core.registry.field_invalid", name = format(name), field = "domain_reads")
  }
  ex <- def$example
  if (kind %in% c("flow", "instrument", "distribution", "process", "tax")) {
    if (!is.list(ex)) add("C3", "core.registry.example_missing", name = format(name))
  }
  if (identical(kind, "rule") && is.list(ex) && length(ex) > 0L && is.function(def$fun)) {
    extra <- setdiff(names(ex), names(formals(def$fun)))
    if (length(extra) > 0L || is.null(names(ex))) {
      add("C3", "core.registry.example_unknown", name = format(name),
          param = utl_collapse(extra))
    }
  } else if (is.list(ex) && length(ex) > 0L && !(kind %in% c("kpi", "expander", "rule"))) {
    allowed <- c(names(params), reg_reserved_fields(), ".deps", ".collection")
    ex_names <- names(ex)
    # Prozesse: Elementnamen mit fuehrendem Punkt sind reserviert (z. B. .base, 5.3, R-114)
    if (identical(kind, "process")) ex_names <- ex_names[!startsWith(ex_names, ".")]
    extra <- setdiff(ex_names, allowed)
    if (length(extra) > 0L || is.null(names(ex))) {
      add("C3", "core.registry.example_unknown", name = format(name),
          param = utl_collapse(extra))
    }
  }
  if (kind %in% c("flow", "instrument", "distribution", "process", "tax") && is.list(ex)) {
    for (p in names(params)) {
      pp <- params[[p]]
      if (!inherits(pp, "vofi_param")) next
      if (isTRUE(pp$required) && is.null(ex[[p]]) && is.null(pp$default)) {
        add("C3", "core.registry.example_required", name = format(name), param = p)
      }
      v <- ex[[p]]
      if (identical(pp$kind, "enum") && utl_is_string(v) &&
            !(v %in% utl_param_codes(pp))) {
        add("C3", "core.registry.example_enum", name = format(name), param = p, value = v)
      }
    }
  }
  for (f in reg_kind_field_findings(def)) add("C3", f$key, name = format(name), field = f$field)
  if (length(acc$out) == 0L) {
    return(data.frame(check = character(0), ok = logical(0), message = character(0),
                      stringsAsFactors = FALSE))
  }
  do.call(rbind, acc$out)
}

#' Parameter mit den Namen `from` bzw. `use` (auch Felder von map-Parametern; 4.9, R-110)
#' @param params benannte Liste von `vofi_param`.
#' @param prefix Pfad des umgebenden map-Parameters.
#' @return Zeichenvektor der Parameterpfade.
#' @noRd
reg_library_key_params <- function(params, prefix = "") {
  out <- character(0)
  for (p in names(params)) {
    full <- path_join(prefix, p)
    if (p %in% c("from", "use")) out <- c(out, full)
    pp <- params[[p]]
    if (inherits(pp, "vofi_param") && is.list(pp$fields) && !is.null(names(pp$fields))) {
      out <- c(out, reg_library_key_params(pp$fields, full))
    }
  }
  out
}

#' Artspezifische Felder prüfen (5.3)
#' @return Liste von `list(key, field)`.
#' @noRd
reg_kind_field_findings <- function(def) {
  acc <- new.env(parent = emptyenv())
  acc$bad <- list()
  flag <- function(field) {
    acc$bad[[length(acc$bad) + 1L]] <- list(key = "core.registry.field_invalid", field = field)
  }
  switch(def$kind,
    account_action = {
      if (!utl_is_string(def$role) || !(def$role %in% c("surplus", "deficit"))) flag("role")
      ranks <- if (identical(def$role, "deficit")) paste0("D", 1:4) else paste0("U", 1:4)
      if (!utl_is_string(def$rank) || !(def$rank %in% ranks)) flag("rank")
      if (!utl_is_flag(def$unlimited)) flag("unlimited")
    },
    expander = {
      if (!utl_is_string(def$block)) flag("block")
      if (!utl_is_whole(def$order)) flag("order")
    },
    process = {
      if (!utl_is_string(def$output) || !(def$output %in% c("level", "rate"))) flag("output")
      if (!is.character(def$linked)) flag("linked")
    },
    kpi = {
      if (!utl_is_string(def$unit) || !vocab_has("units", def$unit)) flag("unit")
      if (!utl_is_string(def$shape) || !(def$shape %in% c("scalar", "series"))) flag("shape")
      if (!utl_is_flag(def$rv_variant)) flag("rv_variant")
      if (!(is.logical(def$higher_is_better) && length(def$higher_is_better) == 1L)) {
        flag("higher_is_better")
      }
      if (!utl_is_flag(def$mc_default)) flag("mc_default")
      req <- c("opportunity", "market_value", "household_income", "living_area", "tenant_data")
      if (!is.character(def$requires) || !all(def$requires %in% req)) flag("requires")
    },
    tax = {
      if (!utl_is_flag(def$uses_inputs)) flag("uses_inputs")
      if (!is.null(def$blocked_regimes) &&
            (!is.character(def$blocked_regimes) ||
               !all(def$blocked_regimes %in% vocab_codes("tax_regime")))) {
        flag("blocked_regimes")
      }
    },
    rule = {
      if (!utl_is_string(def$rule_name) || !utl_is_id(def$rule_name)) flag("rule_name")
      if (!inherits(def$valid_from, "Date") || length(def$valid_from) != 1L ||
            is.na(def$valid_from)) {
        flag("valid_from")
      }
      if (!is.null(def$valid_to) && !inherits(def$valid_to, "Date")) flag("valid_to")
      if (!is.null(def$reform) && !utl_is_string(def$reform)) flag("reform")
      if (!utl_is_string(def$returns) || !(def$returns %in% vocab_codes("rule_returns"))) {
        flag("returns")
      }
    },
    NULL
  )
  acc$bad
}

#' Typ in die Registry aufnehmen
#' @param def `vofi_typedef`.
#' @param source `"vofi"` (eingebaut) oder `"user"`.
#' @param overwrite vorhandenen Typ gleichen Namens ersetzen.
#' @return `invisible(def)`.
#' @noRd
reg_add <- function(def, source = c("vofi", "user"), overwrite = FALSE) {
  source <- utl_match_arg(source, c("vofi", "user"), "source")
  if (!inherits(def, "vofi_typedef")) {
    vofi_abort("core.registry.not_typedef", .class = "vofi_error_registry")
  }
  if (length(reg_state$types) == 0L) reg_reset()
  f <- reg_static_findings(def)
  if (nrow(f) > 0L) {
    vofi_abort("core.registry.invalid_type", name = format(def$name), kind = def$kind,
               details = utl_collapse(paste0(f$check, ": ", f$message), sep = "; "),
               .class = "vofi_error_registry", .data = list(findings = f))
  }
  if (source == "user" && !utl_is_string(def[["label"]])) {
    vofi_abort("core.registry.user_label", name = def$name, .class = "vofi_error_registry")
  }
  kinds <- if (def$kind %in% c("flow", "instrument")) c("flow", "instrument") else def$kind
  for (k in kinds) {
    old <- reg_state$types[[k]][[def$name]]
    if (is.null(old)) next
    if (!isTRUE(overwrite)) {
      vofi_abort("core.registry.duplicate", name = def$name, kind = k,
                 .class = "vofi_error_registry")
    }
    if (identical(old$source, "vofi") && source == "user") {
      vofi_warn("core.registry.overwrite", name = def$name, kind = k)
    }
    reg_state$types[[k]][[def$name]] <- NULL
  }
  if (def$kind == "rule") {
    for (other in reg_rules(def$rule_name)) {
      if (!identical(names(formals(other$fun)), names(formals(def$fun)))) {
        vofi_abort("core.registry.rule_formals", rule = def$rule_name,
                   .class = "vofi_error_registry")
      }
    }
  }
  reg_state$types[[def$kind]][[def$name]] <- list(def = def, source = source)
  invisible(def)
}

#' Typdefinition abrufen
#' @param kind Art.
#' @param name Name.
#' @return `vofi_typedef`; unbekannt: Fehler `vofi_error_registry` mit Vorschlag.
#' @noRd
reg_get <- function(kind, name) {
  e <- if (utl_is_string(kind) && utl_is_string(name)) reg_state$types[[kind]][[name]] else NULL
  if (is.null(e)) {
    choices <- names(reg_state$types[[kind %||% ""]] %||% list())
    vofi_abort("core.registry.unknown_type", name = utl_collapse(format(name)),
               kind = utl_collapse(format(kind)),
               suggestion = utl_suggest_text(as.character(name)[1L], choices),
               .class = "vofi_error_registry")
  }
  e$def
}

#' Ist der Typ registriert?
#' @noRd
reg_has <- function(kind, name) {
  utl_is_string(kind) && utl_is_string(name) && !is.null(reg_state$types[[kind]][[name]])
}

#' Herkunft eines registrierten Typs (`"vofi"` oder `"user"`)
#' @noRd
reg_source <- function(kind, name) {
  reg_state$types[[kind]][[name]]$source %||% NA_character_
}

#' Registrierte Typen als Data Frame
#' @param kind `NULL` oder Art.
#' @return Data Frame `kind`, `name`, `version`, `source` (sortiert nach Art und Name).
#' @noRd
reg_list <- function(kind = NULL) {
  kinds <- if (is.null(kind)) reg_kinds() else kind
  rows <- list()
  for (k in kinds) {
    for (nm in names(reg_state$types[[k]])) {
      e <- reg_state$types[[k]][[nm]]
      rows[[length(rows) + 1L]] <- data.frame(kind = k, name = nm,
                                              version = as.integer(e$def$version),
                                              source = e$source, stringsAsFactors = FALSE)
    }
  }
  if (length(rows) == 0L) {
    return(data.frame(kind = character(0), name = character(0), version = integer(0),
                      source = character(0), stringsAsFactors = FALSE))
  }
  df <- do.call(rbind, rows)
  df <- df[order(match(df$kind, reg_kinds()), df$name, method = "radix"), , drop = FALSE]
  rownames(df) <- NULL
  df
}

#' Alle Versionen einer Rechtsregel (sortiert nach valid_from)
#' @param rule_name Regelname ohne `@Datum`.
#' @return Liste von `vofi_typedef`.
#' @noRd
reg_rules <- function(rule_name) {
  defs <- lapply(reg_state$types[["rule"]] %||% list(), function(e) e$def)
  defs <- Filter(function(d) identical(d$rule_name, rule_name), defs)
  if (length(defs) == 0L) return(list())
  ord <- order(vapply(defs, function(d) as.numeric(d$valid_from), double(1)))
  unname(defs[ord])
}

#' Discovery-Name einer Typdefinition (5.1, 5.5)
#' @noRd
reg_discovery_name <- function(def) {
  switch(def$kind,
    flow = , instrument = paste0("typedef_", def$name),
    account_action = paste0("typedef_action_", def$name),
    expander = paste0("typedef_expander_", def$name),
    distribution = paste0("typedef_dist_", def$name),
    process = paste0("typedef_process_", def$name),
    kpi = paste0("typedef_kpi_", def$name),
    tax = paste0("typedef_tax_", def$name),
    rule = paste0("typedef_rule_", def$rule_name, "_",
                  gsub("-", "", format(def$valid_from), fixed = TRUE)),
    NA_character_
  )
}

#' Eingebaute Typen aus dem Namensraum registrieren (.onLoad, 5.5)
#' @param ns Namensraum.
#' @return `invisible(Anzahl)`.
#' @noRd
reg_discover <- function(ns) {
  fns <- utl_sort(ls(ns, pattern = "^typedef_", all.names = FALSE))
  for (f in fns) {
    def <- get(f, envir = ns)()
    if (!inherits(def, "vofi_typedef") || !identical(reg_discovery_name(def), f)) {
      vofi_abort("core.registry.discovery_name", fun = f,
                 expected = if (inherits(def, "vofi_typedef")) reg_discovery_name(def) else "?",
                 .class = "vofi_error_registry")
    }
    reg_add(def, source = "vofi")
  }
  invisible(length(fns))
}

#' Label-Präfix eines Typs (`types.<kind>.<name>`; Regeln ohne `@Datum`, 2.10)
#' @noRd
reg_label_prefix <- function(def) {
  base <- if (identical(def$kind, "rule")) def$rule_name else def$name
  paste("types", def$kind, base, sep = ".")
}

#' Anzeigename eines Typs
#' @noRd
reg_type_label <- function(def, source = "vofi") {
  if (identical(source, "user") || !is.null(def[["label"]])) return(def[["label"]] %||% def$name)
  lbl(paste0(reg_label_prefix(def), ".label"), .default = def$name)
}

#' Typ registrieren
#'
#' Registriert einen mit [vofi_type()] definierten Nutzertyp. Er ist danach sofort in Szenarien
#' (`type: <name>`) nutzbar. Nutzertypen tragen ihre Texte als Literale (`label`, `labels`).
#' Eingebaute Typen werden nur mit `overwrite = TRUE` (mit Warnung) ersetzt.
#'
#' @param def Typdefinition aus [vofi_type()].
#' @param overwrite vorhandenen Typ gleichen Namens ersetzen.
#' @return `invisible(def)`.
#' @family Erweitern
#' @examples
#' def <- vofi_type(
#'   name = "beispiel_einnahme", kind = "flow", label = "Beispiel-Einnahme",
#'   labels = list(description = "Konstante Einnahme", params = list(amount_eur = "Betrag"),
#'                 rows = list(value = "Einnahme")),
#'   params = list(amount_eur = vofi_param("amount", required = TRUE)), rows = "value",
#'   build = function(spec, ctx) {
#'     v <- ctx$by_sim(ctx$param(spec, "amount_eur"))
#'     v[, 1] <- 0
#'     vofi_flows(vofi_row("value", v, section = "project", category = "other_income"))
#'   },
#'   example = list(type = "beispiel_einnahme", amount_eur = 1000)
#' )
#' vofi_register_type(def, overwrite = TRUE)
#' "beispiel_einnahme" %in% vofi_types("flow")$name
#' @export
vofi_register_type <- function(def, overwrite = FALSE) {
  if (!utl_is_flag(overwrite)) {
    vofi_abort("core.arg_flag", arg = "overwrite", .class = "vofi_error_input")
  }
  reg_add(def, source = "user", overwrite = overwrite)
}

#' Registrierte Typen auflisten
#'
#' @param kind `NULL` (alle Arten) oder eine Art wie `"flow"`.
#' @return Data Frame mit den Spalten `kind`, `name`, `version`, `source`, `label`.
#' @family Erweitern
#' @examples
#' vofi_types()
#' @export
vofi_types <- function(kind = NULL) {
  if (!is.null(kind) && (!is.character(kind) || !all(kind %in% reg_kinds()))) {
    vofi_abort("core.registry.kind_invalid", kind = utl_collapse(format(kind)),
               suggestion = utl_suggest_text(as.character(kind)[1L], reg_kinds()),
               .class = "vofi_error_input")
  }
  df <- reg_list(kind)
  df$label <- vapply(seq_len(nrow(df)), function(i) {
    reg_type_label(reg_get(df$kind[i], df$name[i]), df$source[i])
  }, "")
  df
}

#' Beschreibung eines Typs
#'
#' @param name Name des Typs.
#' @param kind `NULL` oder Art (nötig, wenn der Name in mehreren Arten vorkommt).
#' @return Liste mit `name`, `kind`, `version`, `source`, `label`, `description`, `params`
#'   (Data Frame), `rows` (Data Frame), `perspectives`, `example`.
#' @family Erweitern
#' @examples
#' types <- vofi_types()
#' if (nrow(types) > 0) vofi_type_info(types$name[1], types$kind[1])
#' @export
vofi_type_info <- function(name, kind = NULL) {
  r <- reg_resolve_name(name, kind)
  def <- reg_get(r$kind, r$name)
  src <- reg_source(r$kind, r$name)
  prefix <- reg_label_prefix(def)
  user <- identical(src, "user")
  text <- function(key, literal) {
    if (user) literal %||% NA_character_ else lbl(key, .default = NA_character_)
  }
  pnames <- names(def$params) %||% character(0)
  params <- data.frame(
    param = pnames,
    kind = vapply(def$params, function(p) p$kind, "", USE.NAMES = FALSE),
    required = vapply(def$params, function(p) isTRUE(p$required), logical(1), USE.NAMES = FALSE),
    default = vapply(def$params, function(p) {
      if (is.null(p$default)) NA_character_ else paste(deparse(p$default), collapse = " ")
    }, "", USE.NAMES = FALSE),
    unit = vapply(def$params, function(p) p$unit %||% NA_character_, "", USE.NAMES = FALSE),
    stochastic = vapply(def$params, function(p) as.logical(p$stochastic), logical(1),
                        USE.NAMES = FALSE),
    deterministic_only = vapply(def$params, function(p) isTRUE(p$deterministic_only),
                                logical(1), USE.NAMES = FALSE),
    label = vapply(pnames, function(p) {
      text(paste0(prefix, ".params.", p, ".label"), def$labels$params[[p]])
    }, "", USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )
  rows <- data.frame(
    row = def$rows,
    label = vapply(def$rows, function(r) {
      text(paste0(prefix, ".rows.", r), def$labels$rows[[r]])
    }, "", USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )
  list(name = def$name, kind = def$kind, version = as.integer(def$version), source = src,
       label = reg_type_label(def, src),
       description = text(paste0(prefix, ".description"), def$labels$description),
       params = params, rows = rows, perspectives = def$perspectives, example = def$example)
}

#' Art eines Typnamens bestimmen
#' @noRd
reg_resolve_name <- function(name, kind = NULL) {
  if (!utl_is_string(name)) {
    vofi_abort("core.registry.unknown_type", name = utl_collapse(format(name)), kind = "?",
               suggestion = "", .class = "vofi_error_registry")
  }
  if (!is.null(kind)) {
    reg_get(kind, name)
    return(list(kind = kind, name = name))
  }
  hits <- reg_kinds()[vapply(reg_kinds(), function(k) reg_has(k, name), logical(1))]
  if (length(hits) == 0L) {
    all_names <- unlist(lapply(reg_state$types, names), use.names = FALSE)
    vofi_abort("core.registry.unknown_type", name = name, kind = "?",
               suggestion = utl_suggest_text(name, all_names), .class = "vofi_error_registry")
  }
  if (length(hits) > 1L) {
    vofi_abort("core.registry.ambiguous", name = name, kinds = utl_collapse(hits),
               .class = "vofi_error_registry")
  }
  list(kind = hits, name = name)
}

#' Vertragstests für einen Typ ausführen
#'
#' Führt die Vertragstests aus Spec 00, Abschnitt 5.6 (C1–C4 und die artspezifischen Prüfungen
#' F1–F10, I1–I4, A1–A2, D1–D3, P1–P4, K1, T1) mit dem Prüfkit des Pakets aus. Ein Verstoß ist
#' ein Fehler der Klasse `vofi_error_contract`; das Feld `data$findings` enthält alle Befunde.
#'
#' @param name Name des Typs.
#' @param kind `NULL` oder Art.
#' @param n Anzahl der Läufe, mit denen geprüft wird (Batch-Invarianz mit dem größten Wert).
#' @return `invisible(TRUE)`.
#' @family Erweitern
#' @examples
#' types <- vofi_types()
#' if ("equity" %in% types$name) vofi_check_type("equity")
#' @export
vofi_check_type <- function(name, kind = NULL, n = c(1L, 2L, 7L)) {
  r <- reg_resolve_name(name, kind)
  if (!is.numeric(n) || length(n) == 0L || anyNA(n) || any(n < 1)) {
    vofi_abort("core.arg_whole", arg = "n", value = utl_collapse(format(n)), min = "1",
               max = "Inf", .class = "vofi_error_input")
  }
  def <- reg_get(r$kind, r$name)
  findings <- reg_check_type(def, reg_source(r$kind, r$name), as.integer(n))
  failed <- findings[!findings$ok, , drop = FALSE]
  if (nrow(failed) > 0L) {
    vofi_abort("core.contract.check_failed", name = def$name, kind = def$kind,
               n_failed = nrow(failed),
               details = utl_collapse(paste0(failed$check, ": ", failed$message), sep = "; "),
               .class = "vofi_error_contract", .data = list(findings = findings))
  }
  invisible(TRUE)
}
