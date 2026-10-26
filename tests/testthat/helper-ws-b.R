# Hilfen der Validierungstests (WS-B): Grundszenarien, Prüffälle als Tabelle, Ersatztypen für
# Verteilungen und Prozesse (WS-C liefert die echten Typen parallel) und Abdeckung der
# Meldungen (Spec 00 15.6: jede Meldung mindestens einmal ausgelöst).

#' Walking Skeleton als Liste (ohne Attribute)
wsb_skeleton <- function() {
  x <- unclass(example_scenario("skeleton"))
  attr(x, "source") <- NULL
  attr(x, "provenance") <- NULL
  x
}

#' Bestandsprojekt mit Domänenblöcken ohne Befund (wu_kommunal, sanierung_eh, 20 Jahre)
#'
#' Auch mit den Defaults aus global.yaml und dem Profil (WS-A) ohne Fehler: Bodenwert für den
#' Ertragswert des Profils, Wohnfläche für die Instandhaltung.
wsb_domain <- function() {
  x <- wsb_skeleton()
  x$project <- list(perspective = "wu_kommunal", project_type = "sanierung_eh",
                    valuation_date = "2027-01-01", horizon_years = 20L, federal_state = "NW")
  x$components$z$values <- c(-100000, rep(10000, 20))
  x$building <- list(building_type = "MFH", construction_year = 1963L, n_units = 12L,
                     living_area_m2 = 800, existing_value_eur = 1000000,
                     land_value_eur = 200000,
                     property_tax = list(amount_eur_pa = 2000),
                     maintenance = list(enabled = FALSE))
  x$unit_groups <- list(a = list(n_units = 12L, living_area_m2 = 800, rent_eur_m2_month = 7.5))
  x$measures <- list(huelle = list(measure_type = "daemmung_fassade", date = "2028-01-01",
                                   cost_eur = 500000, useful_life_years = 40))
  x$variants <- list(ohnehin = list(label = "Ohnehin",
                                    set = list("measures.huelle.cost_eur" = 300000)))
  x
}

#' Grundszenario ändern und als vofi_scenario liefern
#' @param base `"skeleton"` oder `"domain"`.
#' @param f Funktion Liste -> Liste.
wsb_with <- function(base = c("skeleton", "domain"), f = identity) {
  base <- match.arg(base)
  x <- if (identical(base, "skeleton")) wsb_skeleton() else wsb_domain()
  vofi_scenario(f(x))
}

#' Codes eines Validierungsberichts
wsb_codes <- function(x, ...) unique(vofi_validate(x, ...)$code)

#' Befunde, die nach der Integration aus den Defaults stammen (global.yaml, Profile,
#' Bibliothek, Ableitungsregeln; WS-A, WS-L) und nicht Gegenstand der Prüffälle sind
wsb_default_codes <- function() {
  c("validation.accounts.liquidity_unchecked", "validation.library.outdated",
    "validation.library.stale", "validation.stochastic.library_outdated",
    "validation.measures.ohnehin_catalog", "validation.measures.catalog_defaults",
    "validation.measures.kind_from_classification", "validation.maintenance.default_rate")
}

#' Validierungsbericht ohne die Befunde der Defaults (`wsb_default_codes()`)
#'
#' Für Tests, die einen Bericht vollständig vergleichen; sie bleiben so nach der Integration von
#' Defaults, Profilen und Bibliothek gültig. Tests der Defaults-Befunde selbst verwenden
#' `vofi_validate()`.
wsb_validate <- function(x, ...) {
  v <- vofi_validate(x, ...)
  keep <- !(v$code %in% wsb_default_codes())
  df <- as.data.frame(unclass(v), stringsAsFactors = FALSE)[keep, , drop = FALSE]
  rownames(df) <- NULL
  new_vofi_validation(df)
}

#' Prüffall: Objekt, erwartete Codes, optional eigene Ausführung
#'
#' Negativzusicherung: Bei Prüffällen mit `make` darf der Bericht keine Fehler (E) außer den
#' erwarteten Codes und `allow` enthalten (keine fremden Fehler, Review m5).
#' @param allow weitere zulässige Fehlercodes.
wsb_case <- function(id, codes, make = NULL, fun = NULL, args = list(), allow = character(0)) {
  list(id = id, codes = codes, make = make, fun = fun, args = args, allow = allow)
}

#' Codes eines Prüffalls (Attribut `errors`: Codes der Fehler, bei `make`)
#'
#' Prüft schon das Einlesen (WS-A) eine Regel mit eigenem Schlüssel `validation.*`, zählt der
#' Schlüssel der Bedingung als Befund (dieselbe Regel, früher gemeldet).
wsb_run_case <- function(case) {
  if (is.function(case$fun)) return(case$fun())
  x <- tryCatch(case$make(), error = function(e) e)
  if (inherits(x, "error")) {
    key <- x$key
    if (utl_is_string(key) && startsWith(key, "validation.")) {
      return(structure(key, errors = key))
    }
    stop(x)
  }
  v <- do.call(vofi_validate, c(list(x), case$args))
  structure(v$code, errors = unique(v$code[v$severity == "error"]))
}

#' Alle Prüffälle einer Tabelle ausführen
wsb_expect_cases <- function(cases) {
  for (cs in cases) {
    codes <- tryCatch(wsb_run_case(cs), error = function(e) {
      paste0("<Fehler: ", conditionMessage(e), ">")
    })
    miss <- setdiff(cs$codes, codes)
    testthat::expect(length(miss) == 0L,
                     sprintf("Prüffall %s: fehlt %s (erhalten: %s)", cs$id,
                             paste(miss, collapse = ", "), paste(unique(codes), collapse = ", ")))
    # Kennzahlen der Profile registriert erst WS-D2 (validation.kpi_unknown vor dessen Integration)
    extra <- setdiff(attr(codes, "errors"), c(cs$codes, cs$allow, "validation.kpi_unknown"))
    testthat::expect(length(extra) == 0L,
                     sprintf("Prüffall %s: fremde Fehler %s", cs$id,
                             paste(extra, collapse = ", ")))
  }
  invisible(TRUE)
}

#' Fehlerzeilen eines Validierungsberichts als Text (für Meldungen der Tests)
wsb_errors <- function(v) {
  e <- v[v$severity == "error", , drop = FALSE]
  paste(e$code, e$path, e$variant, sep = " @ ", collapse = "; ")
}

#' Ersatztyp der Registry eintragen (ohne Vertragsprüfung)
wsb_put_type <- function(kind, def) {
  def$kind <- kind
  def$version <- def$version %||% 1L
  class(def) <- "vofi_typedef"
  reg_state$types[[kind]][[def$name]] <- list(def = def, source = "vofi")
  invisible(def)
}

#' Ersatztypen für Verteilungen und Prozesse; Registry nach dem Test zurücksetzen
wsb_registry <- function(env = parent.frame()) {
  old <- reg_state$types
  withr::defer(reg_state$types <- old, envir = env)
  num <- function(x) as.double(unlist(x))
  wsb_put_type("distribution", list(
    name = "pert", params = list(min = vofi_param("number"), mode = vofi_param("number"),
                                 max = vofi_param("number")),
    quantile = function(u, par) num(par$min) + (num(par$max) - num(par$min)) * u,
    point = function(par, which) {
      switch(which, mode = num(par$mode),
             (num(par$min) + 4 * num(par$mode) + num(par$max)) / 6)
    },
    moments = function(par) list(mean = NA_real_, var = NA_real_),
    validate = function(par) {
      if (is.null(par$min) || is.null(par$mode) || is.null(par$max)) return("min, mode, max fehlen")
      if (num(par$min) > num(par$mode) || num(par$mode) > num(par$max)) {
        return("min <= mode <= max verletzt")
      }
      character(0)
    }))
  wsb_put_type("distribution", list(
    name = "normal", params = list(mean = vofi_param("number"), sd = vofi_param("number")),
    quantile = function(u, par) stats::qnorm(u, num(par$mean), num(par$sd)),
    point = function(par, which) num(par$mean),
    moments = function(par) list(mean = num(par$mean), var = num(par$sd)^2),
    validate = function(par) if (num(par$sd) < 0) "sd < 0" else character(0)))
  wsb_put_type("distribution", list(
    name = "bernoulli", params = list(p = vofi_param("number")),
    quantile = function(u, par) as.double(u > 1 - num(par$p)),
    point = function(par, which) num(par$p),
    moments = function(par) list(mean = num(par$p), var = num(par$p) * (1 - num(par$p))),
    validate = function(par) character(0)))
  wsb_put_type("distribution", list(
    name = "discrete", params = list(values = vofi_param("number"),
                                     probs = vofi_param("number")),
    quantile = function(u, par) {
      v <- num(par$values)
      v[pmin(length(v), findInterval(u, cumsum(num(par$probs))) + 1L)]
    },
    point = function(par, which) num(par$values)[1L],
    moments = function(par) list(mean = NA_real_, var = NA_real_),
    validate = function(par) character(0)))
  wsb_put_type("process", list(
    name = "ar1", params = list(mu = vofi_param("number"), phi = vofi_param("number"),
                                sigma = vofi_param("number"), x0 = vofi_param("number")),
    simulate = function(par, z, u, years, linked) NULL,
    expected = function(par, years) NULL,
    n_shocks = function(par) 1L, n_uniforms = function(par) 0L,
    quantile_path = function(par, years, p) NULL,
    validate = function(par) {
      if (!is.null(par$sigma) && is.numeric(par$sigma) && par$sigma < 0) "sigma < 0" else
        character(0)
    }))
  wsb_put_type("process", list(
    name = "linked_ar1", linked = "base",
    params = list(base = vofi_param("string"), a = vofi_param("number"),
                  b = vofi_param("number"), phi = vofi_param("number"),
                  sigma = vofi_param("number")),
    simulate = function(par, z, u, years, linked) NULL,
    expected = function(par, years) NULL,
    n_shocks = function(par) 1L, n_uniforms = function(par) 0L,
    quantile_path = function(par, years, p) NULL,
    validate = function(par) character(0)))
  wsb_put_type("process", list(
    name = "fixed_path", params = list(path = vofi_param("value")),
    simulate = function(par, z, u, years, linked) NULL,
    expected = function(par, years) NULL,
    n_shocks = function(par) 0L, n_uniforms = function(par) 0L,
    validate = function(par) character(0)))
  invisible(TRUE)
}

#' Spezifikation mit zusätzlichen Herkunftszeilen (Bibliothekseinträge)
wsb_spec_with_library <- function(spec, rows) {
  prov <- attr(spec, "provenance")
  add <- prov[rep(1L, nrow(rows)), , drop = FALSE]
  prov <- prov[!(prov$path %in% rows$path), , drop = FALSE]
  for (nm in names(rows)) add[[nm]] <- rows[[nm]]
  attr(spec, "provenance") <- rbind(prov, add)
  spec
}

#' Alle Meldungsschlüssel der Validierung (Blätter von inst/labels/de/validation.yaml)
wsb_label_keys <- function() lbl_keys("validation")

#' Schlüssel der Befunde aus den validate()-Funktionen der Typen (R-104)
#'
#' Sie stehen in validation.yaml, ausgelöst werden sie in den Typtests: Kredite (WS-F) in
#' test-type-inst-loan-core.R ("jeder Meldungscode ... über vofi_validate()"), die
#' Zahlungsbausteine (WS-E-INV, Liste in fixtures/ws-e-inv/validation_stubs.yaml) in
#' test-type-flow-*.R. Die Abdeckungsprüfung von WS-B (15.6) verlangt sie daher nicht von den
#' Prüffällen hier.
wsb_type_keys <- function() {
  stubs <- utl_flatten_labels(
    utl_read_yaml(testthat::test_path("fixtures", "ws-e-inv", "validation_stubs.yaml")),
    "validation"
  )
  unique(c(inst_loan_val_key(names(inst_loan_val_codes())), names(stubs)))
}

# ---------------------------------------------------------------------------------------------
# Prüffälle Ebene 1 (Struktur, Varianten, Sets, Auflösung, Defaults-Dateien, Bibliothek)
# ---------------------------------------------------------------------------------------------

wsb_cases_structure <- function() {
  sk <- function(f) function() wsb_with("skeleton", f)
  list(
    wsb_case("oberste Ebene", c("validation.unknown_key", "validation.reserved_root_key",
                                "validation.schema_version", "validation.stochastic.unknown_key"),
             sk(function(x) {
               x$horizon_from <- "completion"
               x$item_defaults <- list()
               x$schema_version <- 2L
               x$stochastic <- list(setings = list())
               x
             })),
    wsb_case("Varianten: ids, Felder, extends", c("validation.id_invalid", "validation.not_map",
                                                 "validation.unknown_field",
                                                 "validation.required",
                                                 "validation.variants.extends_unknown",
                                                 "validation.variants.extends_cycle"),
             sk(function(x) {
               x$variants <- list(
                 Bad = list(label = "B"), kaputt = 1,
                 v1 = list(label = "v1", sett = list()),
                 v2 = list(extends = "gibts"),
                 a = list(label = "a", extends = "b"), b = list(label = "b", extends = "a"))
               x
             })),
    wsb_case("Varianten: Operationen", c("validation.variants.path_invalid",
                                         "validation.variants.wildcard",
                                         "validation.variants.add_not_collection",
                                         "validation.id_invalid", "validation.not_ids",
                                         "validation.not_map", "validation.unknown_key"),
             sk(function(x) {
               x$variants <- list(
                 v1 = list(label = "v1", set = list("gibtsnicht.x" = 1,
                                                    "financing.*.rate_pa" = 0.04),
                           add = list("accounts.neu" = 1, "components.Neu" = list())),
                 v2 = list(label = "v2", remove = list(1), replace = 3,
                           overrides = list(acounts = list(deposit_rate_pa = 0.01))))
               x
             })),
    wsb_case("Szenario-Sets", c("validation.id_invalid", "validation.scenario_set.id_is_variant",
                                "validation.unknown_field", "validation.required",
                                "validation.scenario_set.generate_with_ops",
                                "validation.scenario_set.ops_missing",
                                "validation.scenario_set.probs",
                                "validation.scenario_set.path_forbidden",
                                "validation.scenario_set.path_not_allowed",
                                "validation.scenario_set.wildcard_multiple"),
             sk(function(x) {
               x$variants <- list(v1 = list(label = "v1",
                                            set = list("accounts.deposit_rate_pa" = 0.03)))
               x$scenario_sets <- list(
                 Bad = list(label = "B", set = list("accounts.deposit_rate_pa" = 0.01)),
                 v1 = list(label = "v1", set = list("accounts.deposit_rate_pa" = 0.01)),
                 s1 = list(extends = "base", set = list("accounts.deposit_rate_pa" = 0.01)),
                 s2 = list(label = "s2", generate = list(probs = c(0.2, 0.4)),
                           set = list("accounts.deposit_rate_pa" = 0.01)),
                 s3 = list(label = "s3"),
                 s4 = list(label = "s4", set = list("shared.co2_2030" = 120,
                                                    "components.z.values" = 1,
                                                    "funding.*.*.approved" = 0)))
               x
             })),
    wsb_case("Auflösung: from als Termin", "validation.library.ref_not_id",
             sk(function(x) {
               x$components$r <- list(type = "recurring", category = "rent", amount_eur = 1000,
                                      from = "completion")
               x
             })),
    # seit der Integration hat die Meldung von WS-A einen eigenen Schlüssel (val_resolve_finding())
    wsb_case("Auflösung: Variante mit fehlendem Pfad", "validation.variants.path_missing",
             sk(function(x) {
               x$variants <- list(falsch = list(label = "f",
                                                set = list("components.gibtsnicht.values" = 1)))
               x
             })),
    # Fehler des Resolvers ohne eigenen Schlüssel validation.* (hier io.variant_path_exists)
    wsb_case("Auflösung: Fehler ohne eigenen Schlüssel", "validation.resolve_failed",
             sk(function(x) {
               x$variants <- list(doppelt = list(label = "d", add = list(
                 "components.z" = list(type = "custom_series", values = c(0, 1, 2, 3))
               )))
               x
             })),
    wsb_case("Auflösung: Schlüssel des Resolvers", c("validation.library.entry_unknown",
                                                     "validation.stochastic.template_use_missing",
                                                     "validation.library.cycle",
                                                     "validation.library.entry_invalid",
                                                     "validation.library.use_missing",
                                                     "validation.library.local_keys",
                                                     "validation.variants.path_missing"),
             fun = function() {
               sc <- wsb_with("skeleton")
               out <- character(0)
               # Argumente wie in den Meldungen von WS-A (scn_signal(), Integration Stufe I)
               conds <- list(list("validation.library.entry_unknown",
                                  list(path = "funding.f.from", value = "funding/gibts")),
                             list("validation.stochastic.template_use_missing",
                                  list(path = "stochastic.parameters.k.use",
                                       entry = "processes/cost_risks_2026")),
                             list("validation.library.cycle",
                                  list(path = "funding.f.from", value = "funding/a",
                                       chain = "funding/a -> funding/b -> funding/a")),
                             list("validation.library.entry_invalid",
                                  list(path = "funding.f.from", id = "funding/a",
                                       value = "funding/a", detail = "values fehlt")),
                             list("validation.library.use_missing",
                                  list(path = "stochastic.parameters.k.use",
                                       id = "processes/cost_risks_2026",
                                       entry = "processes/cost_risks_2026", use = "gibts",
                                       value = "gibts")),
                             list("validation.library.local_keys",
                                  list(path = "market.inflation", id = "prices/macro_paths_2026",
                                       entry = "prices/macro_paths_2026", keys = "x, y",
                                       value = "x, y")),
                             list("validation.variants.path_missing",
                                  list(variant = "falsch", op = "set",
                                       path = "components.gibtsnicht.values",
                                       value = "components.gibtsnicht.values")))
               for (k in conds) {
                 f <- function(...) {
                   do.call(vofi_abort, c(list(k[[1L]]), k[[2L]],
                                         list(.class = "vofi_error_validation")))
                 }
                 out <- c(out, testthat::with_mocked_bindings(
                   vofi_validate(sc, variant = "base")$code, vofi_resolve = f, .package = "vofi"))
               }
               out
             }),
    wsb_case("Defaults-Dateien", c("validation.profile_path_forbidden",
                                   "validation.profile.item_defaults_forbidden",
                                   "validation.profile.defaults_meta_missing",
                                   "validation.unknown_key", "validation.required",
                                   "validation.enum", "validation.not_map"),
             fun = function() {
               p <- val_defaults_file(list(item_defaults = list(), acounts = list(),
                                           measures = list(m = list(cost_eur = 1)),
                                           accounts = list(deposit_rate_pa = 0.02),
                                           by_project_type = list(neubau = list(
                                             project = list(horizon_years = 40L,
                                                            valuation_date = "2027-01-01")))),
                                      "profile", file = "wu_kommunal.yaml")
               g <- val_defaults_file(list(defaults_meta = list(kind = "profile", id = "global")),
                                      "global", file = "global.yaml")
               c(p$code, g$code, val_defaults_file(1, "global")$code)
             }),
    wsb_case("Bibliothekseintrag", c("validation.library.unknown_key",
                                     "validation.library.field_missing",
                                     "validation.library.id_mismatch",
                                     "validation.library.block_mismatch",
                                     "validation.library.source_incomplete",
                                     "validation.library.validity_order",
                                     "validation.library.quality_detail_path",
                                     "validation.library.legal_state_missing",
                                     "validation.library.status_reform",
                                     "validation.library.reform_missing",
                                     "validation.library.release_missing",
                                     "validation.library.topic_missing",
                                     "validation.library.release_incomplete",
                                     "validation.library.ref_not_id", "validation.not_date",
                                     "validation.schema_version", "validation.enum",
                                     "validation.not_map", "validation.library.fallback_missing",
                                     "validation.library.uncertainty_invalid"),
             fun = function() {
               e1 <- list(id = "legal/test_eintrag", block = "funding", schema_version = 2L,
                          label = "T", source = list(document = "", publisher = "X"),
                          as_of = "bald", valid_from = "2027-01-01", valid_to = "2026-01-01",
                          quality = "D", quality_detail = list(gibts.nicht = "C", a = "E"),
                          references = list(list(document = "R")), title = "x",
                          values = list(a = 1), from = "2027", reform = "gibts")
               e2 <- list(id = "legal/zwei", block = "legal", schema_version = 1L, label = "Z",
                          source = list(document = "D", publisher = "P"), as_of = "2026-10-25",
                          valid_from = "2026-01-01", valid_to = NULL, quality = "C",
                          legal_state = list(as_of = "2026-01-01", status = "pending"),
                          topic = "mietrecht", values = list(a = 1))
               e3 <- e2
               e3$release <- list(status = "released")
               e3$legal_state$status <- "in_force"
               e3$reform <- "mietrecht_ii"
               e4 <- list(id = "Bad id", block = "irgendwas")
               e5 <- e2
               e5$quality <- "D"
               e5$legal_state$status <- "derived"
               e6 <- list(id = "processes/t", block = "processes", schema_version = 1L,
                          label = "P", source = list(document = "D", publisher = "P"),
                          as_of = "2026-10-25", valid_from = "2026-01-01", valid_to = NULL,
                          quality = "D", quality_detail = list(fehlt = "C"),
                          values = list(type = "ar1", x0 = "base"),
                          uncertainty = list(a = list(dist = "pert", apply = "mal"), b = 5))
               c(val_library_entry(e1, id = "legal/anders")$code, val_library_entry(e2)$code,
                 val_library_entry(e3)$code, val_library_entry(e4)$code,
                 val_library_entry(e5)$code, val_library_entry("x")$code,
                 val_library_entry(e6)$code)
             })
  )
}

# ---------------------------------------------------------------------------------------------
# Prüffälle Ebene 2 (Arten, Bereiche, ids, Komponenten, Konten, Steuer, Kennzahlen, Overlay)
# ---------------------------------------------------------------------------------------------

#' Registry-Zustand für einen Prüffall sichern und am Ende der Funktion zurücksetzen
wsb_local_types <- function(env = parent.frame()) {
  old <- reg_state$types
  withr::defer(reg_state$types <- old, envir = env)
  invisible(TRUE)
}

wsb_cases_types <- function() {
  sk <- function(f) function() wsb_with("skeleton", f)
  dm <- function(f) function() wsb_with("domain", f)
  list(
    wsb_case("Arten und Bereiche (Skelett)", c("validation.unknown_field", "validation.required",
                                               "validation.enum", "validation.not_allowed",
                                               "validation.range", "validation.unusual_value",
                                               "validation.pattern",
                                               "validation.id_invalid",
                                               "validation.valuation_first",
                                               "validation.horizon"),
             sk(function(x) {
               x$accounts$deposit_rate <- 0.02
               x$meta$title <- NULL
               x$meta$description <- strrep("x", 10)
               x$meta$tags <- c("Gut")
               x$meta$scenario_id <- "Bad"
               x$project$perspective <- "wu_kommunl"
               x$project$valuation_date <- "2027-01-15"
               x$project$horizon_years <- 0L
               x$grid <- list(construction_step_months = 5L)
               x$accounts$overdraft_rate_pa <- 0.5
               x$accounts$deposit_withholding_tax_share <- 0.3
               x
             })),
    wsb_case("Titel zu lang", "validation.text_long",
             sk(function(x) {
               x$meta$title <- strrep("x", 130)
               x
             })),
    wsb_case("Arten in Sammlungen (Rohform)", c("validation.not_number", "validation.not_integer",
                                                "validation.not_logical", "validation.not_date",
                                                "validation.not_timing", "validation.not_string",
                                                "validation.not_map",
                                                "validation.shape_path",
                                                "validation.auto_not_allowed",
                                                "validation.ref_id_unknown",
                                                "validation.not_schedule"),
             # Rohformen in der aufgelösten Spezifikation (das Einlesen von WS-A normalisiert
             # bzw. verwirft sie schon vorher)
             make = function() wsb_spec(g = function(s) {
               s$measures$huelle$cost_eur <- "teuer"
               s$measures$huelle$follows_construction <- "vielleicht"
               s$measures$huelle$completion_date <- "bald"
               s$measures$huelle$ohnehin_due_date <- "irgendwann"
               s$measures$huelle$label <- list(1, 2)
               s$measures$huelle$effects <- 5
               s$measures$huelle$useful_life_years <- c(30, 40, 50)
               s$measures$huelle$replaces_elements <- "gibts_nicht"
               s$measures$m2 <- list(measure_type = "fenster", date = "2028-01-01",
                                     cost_eur = "auto", payment_schedule = 5)
               s$unit_groups$a$n_units <- 2.5
               s
             }), allow = c("validation.measures.timing", "validation.measures.cost_source")),
    wsb_case("Listen, Folgen, Duplikate, Steigung", c("validation.not_list", "validation.not_ids",
                                                      "validation.duplicate_entries",
                                                      "validation.not_increasing"),
             make = function() wsb_spec(function(x) {
               x$analysis <- list(mandatory_sensitivities = list(a = 1))
               x$stochastic <- list(settings = list(keep_runs = c("p05", "p05"),
                                                    band_probs = c(0.5, 0.25)))
               x
             }, function(s) {
               s$funding <- list(f = list(instrument_type = "grant", measures = list(a = 1)))
               s
             }), allow = "validation.funding.measures_empty"),
    wsb_case("Plausibilitätsbereich", "validation.unusual",
             dm(function(x) {
               x$project$horizon_years <- 70L
               x$components$z$values <- c(-100000, rep(10000, 70))
               x
             })),
    wsb_case("ids", c("validation.id_too_long", "validation.id_collision",
                      "validation.energy.stage_reserved"),
             dm(function(x) {
               x$unit_groups <- list(eine_sehr_lange_gruppen_id_x = list(n_units = 12L,
                                                                         living_area_m2 = 800,
                                                                         rent_eur_m2_month = 7))
               x$building$elements <- list(huelle = list(measure_type = "daemmung_fassade",
                                                         installed_year = 1990L,
                                                         replacement_cost_eur = 1000))
               x$energy <- list(stages = list(before = list(label = "x")))
               x
             })),
    wsb_case("Komponenten", c("validation.id_duplicate", "validation.param_unknown",
                              "validation.param_required", "validation.type_unknown",
                              "validation.id_reserved_prefix",
                              "validation.generated_id_too_long"),
             sk(function(x) {
               x$components$bank <- list(type = "custom_series", values = c(1, 2, 3, 4))
               x$components$x <- list(type = "recurring", category = "rent", ammount_eur = 1)
               x$components$m_eigen <- list(type = "custom_series", values = c(1, 2, 3, 4))
               x$components$u_eine_sehr_lange_erzeugte_komponente_rent <- list(
                 type = "custom_series", values = c(0, 0, 0, 0), origin = "expander")
               x$financing$z2 <- list(type = "custom_series", values = c(1, 2, 3, 4))
               x
             })),
    wsb_case("Prüffunktion des Typs scheitert", "validation.type_validate_failed",
             fun = function() {
               wsb_local_types()
               def <- reg_get("flow", "custom_series")
               def$name <- "kaputt_series"
               def$validate <- function(spec, scenario) stop("kaputt")
               wsb_put_type("flow", def)
               wsb_codes(wsb_with("skeleton", function(x) {
                 x$components$z$type <- "kaputt_series"
                 x
               }))
             }),
    wsb_case("Ketten, Steuer, Kennzahlen", c("validation.chain_role", "validation.chain_order",
                                              "validation.tax_module_unknown",
                                              "validation.kpi_unknown",
                                              "validation.chain_action_unknown"),
             sk(function(x) {
               x$accounts$surplus_order <- c("od_repay", "od_draw", "dep_invest")
               x$accounts$deficit_order <- c("dep_withdraw", "equity_call", "od_draw")
               x$variants <- list(v = list(label = "v", set = list(
                 "accounts.deficit_order" = c("dep_withdraw", "od_drw", "equity_call"))))
               x$tax$module <- "flatt"
               x$analysis$kpis <- c("terminal_value", "endwert")
               x
             })),
    wsb_case("Steuer flat, gesperrt; Kennzahl der Perspektive",
             c("validation.tax_flat_withholding", "validation.tax_module_blocked",
               "validation.analysis.kpi_perspective"),
             fun = function() {
               wsb_local_types()
               tx <- reg_get("tax", "none")
               tx$name <- "flat"
               wsb_put_type("tax", tx)
               tx$name <- "nur_wu"
               tx$perspectives <- "wu_kommunal"
               wsb_put_type("tax", tx)
               reg_state$types$kpi$terminal_value$def$perspectives <- "selbstnutzer"
               a <- wsb_codes(wsb_with("skeleton", function(x) {
                 x$tax$module <- "flat"
                 x$accounts$deposit_withholding_tax_share <- 0.26375
                 x
               }))
               b <- wsb_codes(wsb_with("skeleton", function(x) {
                 x$tax$module <- "nur_wu"
                 x
               }))
               c(a, b)
             }),
    wsb_case("Kettenlänge null", "validation.required",
             fun = function() {
               sc <- wsb_with("skeleton", function(x) {
                 x$accounts$surplus_order <- character(0)
                 x
               })
               wsb_codes(vofi_resolve(sc))
             }),
    wsb_case("Termin vor dem Stichtag", "validation.before_valuation",
             sk(function(x) {
               x$financing$bank$start <- "2026-01-01"
               x
             })),
    wsb_case("Overlay: Schlüssel, Verteilungen, Prozesse",
             c("validation.stochastic.unknown_key", "validation.stochastic.key_invalid",
               "validation.stochastic.key_duplicate", "validation.stochastic.dist_unknown",
               "validation.stochastic.dist_invalid", "validation.stochastic.process_unknown",
               "validation.stochastic.process_invalid",
               "validation.stochastic.process_param_not_distributable",
               "validation.stochastic.process_param_support",
               "validation.stochastic.apply_not_allowed"),
             sk(function(x) {
               x$market <- list(inflation = 0.02, gas = 0.1)
               x$stochastic <- list(
                 settings = list(nsim = 10),
                 parameters = list(
                   Bad = list(target = "accounts.deposit_rate_pa", dist = "pert", min = 0.01,
                              mode = 0.02, max = 0.03),
                   k1 = list(target = "accounts.deposit_rate_pa", dist = "pertt"),
                   k2 = list(target = "accounts.overdraft_rate_pa", dist = "pert", min = 0.09,
                             mode = 0.08, max = 0.07, modus = 1),
                   k3 = list(target = "accounts.min_liquidity_eur", dist = "normal", mean = 0,
                             sd = 1, apply = "multiply"),
                   accounts.penalty_spread_pa = list(target = "accounts.penalty_spread_pa",
                                                     dist = "pert", min = 0, mode = 0.02,
                                                     max = 0.03, apply = "multiply"),
                   k4 = list(target = "accounts.deposit_tax_allowance_eur_pa",
                             dist = "pert", min = 0, mode = 0, max = 1)),
                 processes = list(
                   k4 = list(target = "market.inflation", type = "ar1", mu = 0.02, phi = 0.5,
                             sigma = 0.01),
                   p1 = list(target = "market.inflation", type = "ar2"),
                   p2 = list(target = "market.inflation", type = "ar1", mu = 0.02, phi = 0.5,
                             sigma = -1),
                   p3 = list(target = "market.gas", type = "fixed_path",
                             path = list(dist = "normal", mean = 0, sd = 1)),
                   p4 = list(target = "market.gas", type = "ar1", mu = 0.02,
                             phi = list(dist = "normal", mean = 0.5, sd = 0.2), sigma = 0.01)))
               x
             }), allow = "validation.stochastic.target_duplicate"),
    wsb_case("Overlay-Einstellungen", c("validation.stochastic.block_and_replicates",
                                        "validation.stochastic.n_sim_not_multiple",
                                        "validation.stochastic.antithetic_lhs",
                                        "validation.stochastic.start_year",
                                        "validation.stochastic.store_full"),
             sk(function(x) {
               x$stochastic <- list(
                 settings = list(block_size = 100L, replicates = 10L, n_sim = 2150L,
                                 antithetic = TRUE, start_year = 2030L, store = "full"),
                 parameters = list(k = list(target = "accounts.deposit_rate_pa", dist = "pert",
                                            min = 0.01, mode = 0.02, max = 0.03)))
               x
             })),
    wsb_case("Overlay-Einstellungen 2", c("validation.stochastic.antithetic_odd",
                                          "validation.stochastic.start_year_early",
                                          "validation.stochastic.se_coarse",
                                          "validation.stochastic.block_too_small",
                                          "validation.stochastic.replicates_mode",
                                          "validation.stochastic.n_sim_not_multiple"),
             fun = function() {
               a <- wsb_codes(wsb_with("skeleton", function(x) {
                 x$stochastic <- list(
                   settings = list(block_size = 3L, n_sim = 9L, sampling = "pseudo",
                                   antithetic = TRUE, start_year = 2020L),
                   parameters = list(
                     k = list(target = "accounts.deposit_rate_pa", dist = "pert", min = 0.01,
                              mode = 0.02, max = 0.03),
                     j = list(target = "accounts.overdraft_rate_pa", dist = "pert", min = 0.07,
                              mode = 0.08, max = 0.09),
                     i = list(target = "accounts.penalty_spread_pa", dist = "pert", min = 0.01,
                              mode = 0.02, max = 0.03)),
                   correlations = list(parameters = list(list("k", "j", 0.5),
                                                         list("j", "i", 0.5))))
                 x
               }))
               b <- wsb_codes(wsb_with("skeleton", function(x) {
                 x$stochastic <- list(
                   settings = list(replicates = 7L, n_sim = 1000L),
                   parameters = list(k = list(target = "accounts.deposit_rate_pa", dist = "pert",
                                              min = 0.01, mode = 0.02, max = 0.03)))
                 x
               }))
               c(a, b)
             })
  )
}

# ---------------------------------------------------------------------------------------------
# Prüffälle Ebene 3 (Bezüge, Zyklen, Komponenten, Overlay, Entscheidungsknoten, Varianten)
# ---------------------------------------------------------------------------------------------

#' Domänenszenario mit Förderinstrumenten
wsb_funding <- function(x, ...) {
  fs <- list(...)
  x$funding <- lapply(fs, function(f) {
    utils::modifyList(list(instrument_type = "grant", measures = "huelle"), f)
  })
  x
}

wsb_cases_refs <- function() {
  sk <- function(f) function() wsb_with("skeleton", f)
  dm <- function(f) function() wsb_with("domain", f)
  pert <- function(lo, mo, hi, ...) list(dist = "pert", min = lo, mode = mo, max = hi, ...)
  list(
    wsb_case("Bezüge und Ausdrücke", c("validation.ref_target_missing",
                                       "validation.ref_target_forbidden",
                                       "validation.ref_target_not_numeric",
                                       "validation.ref_cycle", "validation.element_not_scalar",
                                       "validation.expr.path_missing",
                                       "validation.expr.code_operand"),
             sk(function(x) {
               x$market <- list(a = list(ref = "market.b"), b = list(ref = "market.a"),
                                s = c(0, 0, 0, 0),
                                p = list(years = c(2027, 2030),
                                         values = list(list(ref = "market.s"), 0)),
                                e = list(expr = "project.perspective + 1"))
               x$accounts$deposit_rate_pa <- list(ref = "market.gibts")
               x$accounts$overdraft_rate_pa <- list(ref = "analysis.x")
               x$accounts$penalty_spread_pa <- list(ref = "project.perspective")
               x$accounts$min_liquidity_eur <- list(ref = "market.a")
               x$accounts$overdraft_limit_eur <- list(ref = "market.p")
               x$accounts$deposit_tax_allowance_eur_pa <- list(expr = "market.fehlt * 2")
               x$accounts$overdraft_flag_threshold_eur <- list(ref = "market.e")
               x
             })),
    wsb_case("Mengenbezug", "validation.quantity.reference_missing",
             dm(function(x) {
               x$measures$huelle$cost_eur <- list(value = 100, per = "kw")
               x
             })),
    wsb_case("Abhängigkeiten der Komponenten", c("validation.after_unknown",
                                                 "validation.component_cycle"),
             sk(function(x) {
               x$components$z$after <- "gibts"
               x$components$y <- list(type = "custom_series", values = c(0, 0, 0, 0),
                                      after = "w")
               x$components$w <- list(type = "custom_series", values = c(0, 0, 0, 0),
                                      after = "y")
               x
             })),
    wsb_case("auto und topup", c("validation.auto_multiple", "validation.auto_conflict"),
             sk(function(x) {
               x$financing$bank$amount_eur <- "auto"
               x$financing$b2 <- list(type = "bullet_loan", amount_eur = "auto", rate_pa = 0.05,
                                      term_years = 3, payments_per_year = 1L,
                                      start = "2028-01-01")
               x
             })),
    wsb_case("Entscheidungsknoten", c("validation.funding.decision_multiple",
                                      "validation.funding.on_reject_ignored",
                                      "validation.funding.fallback_missing",
                                      "validation.funding.fallback_contains",
                                      "validation.funding.fallback_nested"),
             dm(function(x) {
               wsb_funding(x,
                           f1 = list(approval_timing = "before_start",
                                     fallback_variant = "ohnehin", on_reject = "balance"),
                           f2 = list(approval_timing = "before_start",
                                     fallback_variant = "ohnehin"),
                           f3 = list(approval_timing = "before_start",
                                     approval_probability = 0.8))
             })),
    wsb_case("Ausweichvarianten", c("validation.funding.fallback_unknown",
                                    "validation.funding.fallback_kpis",
                                    "validation.funding.fallback_nested"),
             dm(function(x) {
               x <- wsb_funding(x, f = list(approval_timing = "before_start",
                                            fallback_variant = "ohne"))
               x$variants$ohne <- list(
                 label = "Ohne Förderung", remove = list("funding.f"),
                 set = list("analysis.kpis" = c("terminal_value")),
                 add = list("funding.g" = list(instrument_type = "grant", measures = "huelle",
                                               approval_timing = "before_start",
                                               fallback_variant = "base")))
               x$variants$falsch <- list(label = "Falsch", set = list(
                 "funding.f.fallback_variant" = "gibts"))
               x
             })),
    wsb_case("Overlay-Ziele (Skelett)", c("validation.stochastic.target_missing",
                                          "validation.stochastic.target_deterministic_only",
                                          "validation.stochastic.target_not_numeric",
                                          "validation.stochastic.target_not_path",
                                          "validation.stochastic.target_no_base",
                                          "validation.stochastic.target_duplicate",
                                          "validation.stochastic.credit_amount_target",
                                          "validation.stochastic.base_outside_support",
                                          "validation.stochastic.mode_differs_base",
                                          "validation.stochastic.base_differs",
                                          "validation.stochastic.share_unbounded"),
             sk(function(x) {
               x$market <- list(x = list(ref = "market.fehlt"), r = 0.03)
               x$stochastic <- list(
                 parameters = list(
                   t1 = c(list(target = "accounts.gibts"), pert(0, 1, 2)),
                   t2 = c(list(target = "project.horizon_years"), pert(2, 3, 4)),
                   t3 = c(list(target = "accounts.prepay"), pert(0, 1, 2)),
                   t4 = c(list(target = "market.x"), pert(0, 1, 2)),
                   t5 = c(list(target = "market.r"), pert(0, 0.03, 0.05)),
                   t6 = c(list(target = "market.r"), pert(0, 0.03, 0.05)),
                   t7 = c(list(target = "financing.bank.amount_eur"), pert(5e4, 6e4, 7e4)),
                   t8 = c(list(target = "accounts.deposit_rate_pa"), pert(0.03, 0.04, 0.05)),
                   t9 = c(list(target = "accounts.overdraft_rate_pa"), pert(0.07, 0.09, 0.1)),
                   t10 = c(list(target = "accounts.penalty_spread_pa"),
                           pert(0.01, 0.02, 0.03, base = 0.025)),
                   t11 = list(target = "accounts.deposit_withholding_tax_share", dist = "normal",
                              mean = 0, sd = 0.01)),
                 processes = list(
                   p1 = list(target = "accounts.deposit_tax_allowance_eur_pa", type = "ar1",
                             mu = 0, phi = 0.5, sigma = 0.1)))
               x
             })),
    wsb_case("Overlay-Ziel üblicherweise fest", "validation.stochastic.target_usually_fixed",
             fun = function() {
               wsb_local_types()
               def <- reg_get("flow", "custom_series")
               def$name <- "fix_series"
               def$params <- c(def$params, list(level = vofi_param("value", stochastic = FALSE)))
               def$validate <- NULL
               wsb_put_type("flow", def)
               wsb_codes(wsb_with("skeleton", function(x) {
                 x$components$fx <- list(type = "fix_series", values = c(0, 0, 0, 0),
                                         level = 1)
                 x$stochastic <- list(parameters = list(
                   k = c(list(target = "components.fx.level"), pert(0, 1, 2))))
                 x
               }))
             }),
    wsb_case("Overlay-Ziele (Domäne)", c("validation.stochastic.jaz_plan_target",
                                         "validation.measures.cost_derived",
                                         "validation.residual.rnd_target",
                                         "validation.stochastic.approval_key_and_availability",
                                         "validation.building.existing_value_overlay",
                                         "validation.stochastic.prebound_with_measured",
                                         "validation.energy.rebound_base_differs",
                                         "validation.measures.cost_risk_double",
                                         "validation.stochastic.cost_risk_double"),
             dm(function(x) {
               x <- wsb_funding(x, f = list(approved = 1))
               x$project$construction_cost_factor <- 1
               x$measures$huelle$contingency_share <- 0.1
               x$measures$huelle$cost_factor <- 1
               x$measures$m2 <- list(measure_type = "fenster", date = "2028-01-01",
                                     cost_kg = list(kg300 = 1000))
               x$measures$m3 <- list(measure_type = "fenster", date = "2028-01-01",
                                     cost_eur = 1000, contingency_share = 0.1)
               x$energy <- list(before = list(consumption_basis = "measured"),
                                performance_gap = list(prebound_factor = 1, rebound_factor = 1))
               x$stochastic <- list(parameters = list(
                 a = c(list(target = "energy.before.jaz_plan"), pert(2, 3, 4)),
                 b = c(list(target = "measures.m2.cost_eur"), pert(0, 1, 2)),
                 c = c(list(target = "residual_value.income_value.remaining_life_years"),
                       pert(1, 2, 3)),
                 d = list(target = "funding.f.approved", dist = "bernoulli", p = 0.8),
                 e = c(list(target = "building.existing_value_eur"), pert(9e5, 1e6, 1.1e6)),
                 f = c(list(target = "energy.performance_gap.prebound_factor"), pert(0.8, 1, 1.2)),
                 g = c(list(target = "energy.performance_gap.rebound_factor"), pert(0.9, 1.1, 1.3)),
                 h = c(list(target = "measures.huelle.contingency_share"), pert(0, 0.1, 0.2)),
                 i = c(list(target = "measures.huelle.cost_factor"), pert(0.9, 1, 1.5)),
                 j = c(list(target = "project.construction_cost_factor"), pert(0.9, 1, 1.5)),
                 k = c(list(target = "measures.m3.contingency_share"), pert(0, 0.1, 0.2))))
               x
             })),
    wsb_case("Verknüpfte Prozesse und Korrelationen",
             c("validation.stochastic.linked_cycle", "validation.stochastic.linked_base_unknown",
               "validation.stochastic.corr_pair_invalid", "validation.stochastic.corr_unknown_key",
               "validation.stochastic.corr_self", "validation.stochastic.corr_range",
               "validation.stochastic.corr_one", "validation.stochastic.corr_conflict",
               "validation.stochastic.corr_ties", "validation.stochastic.corr_no_shock",
               "validation.stochastic.corr_double_counting",
               "validation.stochastic.unknown_key"),
             sk(function(x) {
               x$market <- list(a = 0.01, b = 0.01, c = 0.01, d = 0.01, e = 0.01, f = 0.01)
               x$stochastic <- list(
                 parameters = list(
                   k1 = c(list(target = "accounts.deposit_rate_pa"), pert(0.01, 0.02, 0.03)),
                   k2 = c(list(target = "accounts.overdraft_rate_pa"), pert(0.07, 0.08, 0.09)),
                   k3 = list(target = "accounts.penalty_spread_pa", dist = "bernoulli",
                             p = 0.5)),
                 processes = list(
                   l1 = list(target = "market.a", type = "linked_ar1", base = "l2", a = 0, b = 1,
                             phi = 0.5, sigma = 0.01),
                   l2 = list(target = "market.b", type = "linked_ar1", base = "l1", a = 0, b = 1,
                             phi = 0.5, sigma = 0.01),
                   l3 = list(target = "market.c", type = "linked_ar1", base = "gibts", a = 0,
                             b = 1, phi = 0.5, sigma = 0.01),
                   p0 = list(target = "market.d", type = "ar1", mu = 0, phi = 0.5, sigma = 0.01),
                   l4 = list(target = "market.e", type = "linked_ar1", base = "p0", a = 0,
                             b = 1, phi = 0.5, sigma = 0.01),
                   fp = list(target = "market.f", type = "fixed_path", path = 0.01)),
                 correlations = list(
                   parameters = list(list("k1"), list("k1", "gibts", 0.5),
                                     list("k1", "k1", 0.5), list("k1", "k2", 1.5),
                                     list("k1", "k2", 1), list("k2", "k1", 0.3),
                                     list("k3", "k2", 0.2)),
                   shocks = list(list("fp", "p0", 0.3), list("l4", "p0", 0.4)),
                   gruppen = list()))
               x
             })),
    wsb_case("Korrelationen: keine Liste", "validation.not_list",
             sk(function(x) {
               x$stochastic <- list(correlations = list(parameters = list(a = 1)))
               x
             })),
    wsb_case("Entscheidungsschlüssel", "validation.stochastic.decision_correlated",
             dm(function(x) {
               x <- wsb_funding(x, f = list(approval_timing = "before_start",
                                            fallback_variant = "ohnehin"))
               x$variants$ohnehin$remove <- list("funding.f")
               x$stochastic <- list(
                 parameters = list(
                   k = c(list(target = "funding.f.approved"), pert(0, 0.5, 1)),
                   j = c(list(target = "measures.huelle.useful_life_years"), pert(30, 40, 50))),
                 correlations = list(parameters = list(list("funding.f.approved", "j", 0.5))))
               x
             }), allow = c("validation.stochastic.target_missing",
                           "validation.stochastic.corr_unknown_key")),
    wsb_case("Referenzvariante (unbekannt)", "validation.reference_variant_unknown",
             sk(function(x) {
               x$project$reference_variant <- "gibts"
               x
             })),
    wsb_case("Referenzvariante (Bestand)", c("validation.reference_variant_missing",
                                             "validation.reference_variant_opportunity"),
             fun = function() {
               a <- wsb_codes(wsb_with("domain", function(x) {
                 x$variants <- NULL
                 x
               }))
               b <- wsb_codes(wsb_with("domain", function(x) {
                 x$variants <- NULL
                 x$analysis <- list(allow_opportunity_reference = TRUE)
                 x
               }))
               c(a, b)
             }),
    wsb_case("Primärkennzahl bei Bestand", "validation.reference_variant_missing",
             dm(function(x) {
               x$analysis <- list(primary_kpi = "delta_terminal_value")
               x
             })),
    wsb_case("Bestandswert und Bestandsdarlehen in Varianten",
             c("validation.variants.existing_value_changed",
               "validation.variants.existing_debt_changed"),
             dm(function(x) {
               x$financing$bank$existing <- TRUE
               x$variants$ohnehin$set <- list("measures.huelle.cost_eur" = 300000,
                                              "building.existing_value_eur" = 900000,
                                              "financing.bank.rate_pa" = 0.06)
               x
             })),
    wsb_case("Szenario-Sets gegen die Basis", c("validation.scenario_set.wildcard_no_match",
                                                "validation.scenario_set.growth_form_required",
                                                "validation.kpi_unknown",
                                                "validation.scenario_set.generate_param_unknown",
                                                "validation.scenario_set.quantile_path_unavailable",
                                                "validation.variants.path_missing"),
             sk(function(x) {
               x$market <- list(p = 0.05, f = 0.01)
               x$stochastic <- list(processes = list(fp = list(target = "market.f",
                                                               type = "fixed_path",
                                                               path = 0.01)))
               x$scenario_sets <- list(
                 stopp = list(label = "Stopp", set = list("funding.*.approved" = 0)),
                 wachstum = list(label = "W", set = list("market.p" = list(growth = 0.03))),
                 vorsichtig = list(label = "V", generate = list(
                   method = "cautious", kpi = "endwert", params = c("gibts.x", "fp"),
                   exclude = c("funding.*.approved"))),
                 fehlt = list(label = "F", set = list("market.gibts.x" = 1)))
               x
             }))
  )
}

# ---------------------------------------------------------------------------------------------
# Prüffälle Ebene 4 (Plausibilität und blockbezogene Konsistenzregeln)
# ---------------------------------------------------------------------------------------------

#' Spezifikation des Domänenszenarios (Basis) mit Änderung f vor und g nach der Auflösung
wsb_spec <- function(f = identity, g = identity, base = "domain") {
  spec <- vofi_resolve(wsb_with(base, f))
  g(spec)
}

#' Herkunftszeilen für Pfade mit Eintrag und Schicht
wsb_rows <- function(path, entry = NA_character_, layer = 3L, valid_from = NA, valid_to = NA,
                     as_of = NA) {
  data.frame(path = path, entry = entry, layer = as.integer(layer),
             valid_from = as.Date(valid_from), valid_to = as.Date(valid_to),
             as_of = as.Date(as_of), stringsAsFactors = FALSE)
}

#' Maßnahme mit Termin und Kosten
wsb_m <- function(...) {
  utils::modifyList(list(measure_type = "fenster", date = "2028-01-01", cost_eur = 1000),
                    list(...))
}

wsb_cases_plaus <- function() {
  sk <- function(f) function() wsb_with("skeleton", f)
  dm <- function(f) function() wsb_with("domain", f)
  list(
    wsb_case("Projekt und meta", c("validation.project.tax_regime_unusual",
                                   "validation.project.comparison_differential",
                                   "validation.project.legal_state_far",
                                   "validation.project.price_base_year",
                                   "validation.project.mietpreisbremse_until",
                                   "validation.project.index_cap_inactive",
                                   "validation.library.unreleased_used",
                                   "validation.project.application_late",
                                   "validation.meta.created_late"),
             dm(function(x) {
               x$project$tax_regime <- "selbstnutzer"
               x$project$comparison_mode <- "differential"
               x$project$legal_state <- "2028-06-01"
               x$project$price_base_year <- 2040L
               x$project$municipality <- list(mietpreisbremse_area = FALSE,
                                              mietpreisbremse_until = "2030-01-01",
                                              index_cap_area = TRUE)
               x$project$pending_reforms <- "unreleased"
               x$project$application_date <- "2029-01-01"
               x$meta$created_date <- "2029-01-01"
               x
             })),
    wsb_case("Raster", c("validation.grid.construction_horizon",
                         "validation.grid.step_ineffective", "validation.grid.periods_sum"),
             fun = function() {
               a <- wsb_codes(wsb_with("domain", function(x) {
                 x$grid <- list(construction_months = 240L)
                 x
               }))
               b <- wsb_codes(wsb_with("domain", function(x) {
                 x$grid <- list(construction_step_months = 6L, periods_months = c(12L, 12L))
                 x
               }))
               c(a, b)
             }),
    wsb_case("Raster bei Neubau", c("validation.grid.no_construction",
                                    "validation.building.in_kind_land"),
             dm(function(x) {
               x$project$project_type <- "neubau"
               x
             })),
    wsb_case("Raster: Fertigstellung", c("validation.grid.completion_mismatch",
                                         "validation.measures.follows_mismatch",
                                         "validation.analysis.stabilization_early"),
             dm(function(x) {
               x$grid <- list(construction_months = 12L)
               x$measures$huelle$follows_construction <- TRUE
               x$measures$huelle$date <- "2029-06-01"
               x$analysis <- list(stabilization_year = 2027L)
               x
             })),
    wsb_case("Analyse", c("validation.analysis.traffic_light_order",
                          "validation.analysis.stabilization_year",
                          "validation.analysis.tenant_view_no_groups",
                          "validation.analysis.sensitivity_id",
                          "validation.analysis.sensitivity_path",
                          "validation.analysis.sensitivity_op", "validation.required"),
             dm(function(x) {
               x$unit_groups <- NULL
               x$analysis <- list(
                 traffic_light = list(green_prob = 0.3, red_prob = 0.5),
                 stabilization_year = 2060L, tenant_view = TRUE,
                 mandatory_sensitivities = list(
                   list(id = "a", path = "accounts.deposit_rate_pa", value = 0.02, label = "A"),
                   list(id = "a", path = "gibts.x", label = "B", delta = 0.01),
                   list(path = "accounts.deposit_rate_pa", value = 0.01, delta = 1)))
               x
             })),
    wsb_case("Konten", c("validation.accounts.liquidity_unchecked",
                         "validation.accounts.deposit_above_overdraft",
                         "validation.accounts.loan_prepay"),
             sk(function(x) {
               x$analysis$restrictions <- "liquidity"
               x$accounts$deposit_rate_pa <- 0.09
               x$accounts$surplus_order <- c("od_repay", "loan_prepay", "dep_invest")
               x
             })),
    wsb_case("Finanzierung", c("validation.financing.existing_forbidden",
                               "validation.financing.existing_start",
                               "validation.financing.negative_amortization",
                               "validation.financing.tau_with_installment",
                               "validation.financing.balloon_at_maturity",
                               "validation.before_valuation",
                               "validation.financing.after_horizon",
                               "validation.financing.draws_exceed",
                               "validation.financing.draw_before_start",
                               "validation.financing.draw_schedule_sum",
                               "validation.financing.repayment_grant_tag",
                               "validation.financing.repayment_grant_both",
                               "validation.financing.repayment_grant_high",
                               "validation.financing.prepay_program",
                               "validation.financing.fee_high",
                               "validation.financing.amount_overlay",
                               "validation.financing.delay_fixed_dates"),
             dm(function(x) {
               bl <- function(...) utils::modifyList(list(type = "bullet_loan", amount_eur = 60000,
                                                          rate_pa = 0.05, term_years = 3,
                                                          payments_per_year = 1L), list(...))
               an <- function(...) utils::modifyList(list(type = "annuity_loan",
                                                          amount_eur = 100000, rate_pa = 0.05,
                                                          term_years = 10), list(...))
               x$market <- list(k = 50000)
               x$measures$huelle$delay_months <- 0
               x$financing$bank <- bl(existing = TRUE, payout_rate = 0.98, grace_years = 1,
                                      start = "2027-06-01")
               x$financing$l2 <- an(installment_eur = 100, initial_repayment_pa = 0.02,
                                    term_years = NULL)
               x$financing$l3 <- an(rate_pa = 0.03, initial_repayment_pa = 0.02)
               x$financing$l4 <- bl(start = "2026-01-01")
               x$financing$l5 <- bl(start = "2050-01-01")
               x$financing$l6 <- bl(start = "2027-07-01",
                                    draw_schedule = list(schedule = list("2027-06-01" = 70000)))
               x$financing$l7 <- bl(draw_schedule = list(schedule = list("2027-01-01" = 0.5,
                                                                         "2027-06-01" = 0.4),
                                                         unit = "share"))
               x$financing$l8 <- an(repayment_grant = list(share = 0.1, amount_eur = 200000))
               x$financing$l9 <- bl(program = "kfw_261", prepay_allowed = TRUE,
                                    fees = list(processing_fee_share = 0.03))
               x$financing$l10 <- bl(amount_eur = list(ref = "market.k"), measure_id = "huelle")
               x$stochastic <- list(parameters = list(
                 k = list(target = "market.k", dist = "pert", min = 4e4, mode = 5e4, max = 6e4),
                 d = list(target = "measures.huelle.delay_months", dist = "discrete",
                          values = c(0, 6), probs = c(0.5, 0.5))))
               x
             }),
             # gleiche Regel im Instrumententyp (WS-F), Änderungswunsch an die Verträge
             allow = "types.instrument.annuity_loan.errors.tau_installment"),
    wsb_case("Bestandsdarlehen bei Neubau", "validation.financing.existing_new_build",
             dm(function(x) {
               x$project$project_type <- "neubau"
               x$financing$bank$existing <- TRUE
               x
             })),
    wsb_case("Bibliothek: Gültigkeit und Stand", c("validation.library.outdated",
                                                   "validation.library.stale",
                                                   "validation.stochastic.library_outdated",
                                                   "validation.stochastic.p_norm_start_year"),
             fun = function() {
               spec <- wsb_spec(function(x) {
                 x$market <- list(e = 0.1)
                 x <- wsb_funding(x, f = list())
                 x$stochastic <- list(settings = list(start_year = 2026L), processes = list(
                   p = list(target = "market.e", type = "ar1", mu = 0, phi = 0.5, sigma = 0.1,
                            p_norm = 0.1)))
                 x
               }, function(s) {
                 wsb_spec_with_library(s, wsb_rows(
                   c("accounts.deposit_rate_pa", "stochastic.processes.p.mu",
                     "funding.f.instrument_type"),
                   entry = c("prices/x_2020", "processes/energy_prices_mr_2026",
                             "funding/kfw_test"),
                   valid_from = c("2020-01-01", "2020-01-01", "2028-01-01"),
                   valid_to = c("2025-01-01", NA, NA),
                   as_of = c("2020-01-01", "2020-01-01", "2026-10-01")))
               })
               wsb_codes(spec)
             }),
    wsb_case("Gebäude", c("validation.building.type_missing",
                          "validation.building.construction_year_future",
                          "validation.building.occupancy_before_construction",
                          "validation.building.fictitious_before_construction",
                          "validation.unit_groups.sum_units", "validation.unit_groups.sum_area",
                          "validation.building.nfa_ratio", "validation.building.land_above_market",
                          "validation.building.points_max", "validation.building.commercial_share",
                          "validation.building.wpb_hint", "validation.building.consumption_low"),
             dm(function(x) {
               b <- x$building
               b$building_type <- NULL
               b$construction_year <- 2040L
               b$first_occupancy_year <- 1960L
               b$fictitious_construction_year <- 1950L
               b$n_units <- 20L
               b$living_area_m2 <- 1000
               b$net_floor_area_m2 <- 2000
               b$land_value_eur <- 2e6
               b$market_value_eur <- 1e6
               b$modernization_points_before <- list(heating = 5L)
               b$commercial_share <- 0.1
               b$energy_class_before <- "H"
               b$wpb_flag <- FALSE
               b$consumption_kwh <- list(gas = 10000)
               x$building <- b
               x$residual_value <- list(income_value = list(points_max = list(heating = 2L)))
               x
             })),
    wsb_case("Gebäude: fiktives Baujahr", "validation.building.fictitious_future",
             dm(function(x) {
               x$building$fictitious_construction_year <- 2030L
               x
             })),
    wsb_case("Gebäude: Pflichtangaben und Bestandswert",
             c("validation.building.construction_year_missing",
               "validation.building.n_units_missing", "validation.building.no_existing_value",
               "validation.building.negative_in_kind"),
             fun = function() {
               a <- wsb_codes(wsb_with("domain", function(x) {
                 x$building$construction_year <- NULL
                 x$building$existing_value_eur <- NULL
                 x$building$n_units <- NULL
                 x$unit_groups <- NULL
                 x
               }))
               b <- wsb_codes(wsb_with("domain", function(x) {
                 x$building$existing_value_eur <- 50000
                 x$financing$bank$existing <- TRUE
                 x
               }))
               c(a, b)
             }),
    wsb_case("Gebäude: Erwerb mit Bestandswert",
             "validation.building.existing_value_with_purchase",
             dm(function(x) {
               x$project$project_type <- "erwerb_sanierung"
               x$measures$kauf <- list(measure_type = "erwerb_objekt", date = "2027-01-01",
                                       purchase_price_eur = 500000, land_share = 0.3,
                                       grest_rate = 0.065)
               x
             })),
    wsb_case("Bestandsbauteile", c("validation.building.element_installed_missing",
                                   "validation.building.element_installed_future",
                                   "validation.building.element_next_before",
                                   "validation.building.element_next_after",
                                   "validation.building.element_overdue",
                                   "validation.building.element_cost_missing"),
             dm(function(x) {
               e <- function(...) utils::modifyList(list(measure_type = "fenster",
                                                         replacement_cost_eur = 1000), list(...))
               x$building$elements <- list(
                 e1 = e(), e2 = e(installed_year = 2030L),
                 e3 = e(next_replacement = "2026-01-01"), e4 = e(next_replacement = "2060-01-01"),
                 e5 = e(installed_year = 1990L, useful_life_years = 20),
                 e6 = list(measure_type = "fenster", installed_year = 2000L))
               x
             })),
    wsb_case("Grundsteuer", c("validation.building.property_tax_both",
                              "validation.building.property_tax_multiplier",
                              "validation.building.property_tax_land_only",
                              "validation.building.property_tax_missing"),
             fun = function() {
               pt <- function(v) wsb_codes(wsb_with("domain", function(x) {
                 x$building$property_tax <- v
                 x
               }))
               c(pt(list(amount_eur_pa = 1000, assessment_amount_eur = 100)),
                 pt(list(land_amount_eur_pa = 100)), pt(NULL))
             }),
    wsb_case("Maßnahmen", c("validation.measures.timing", "validation.measures.cost_source",
                            "validation.measures.schedule_sum",
                            "validation.measures.before_valuation",
                            "validation.measures.duration_timing",
                            "validation.measures.completion_order",
                            "validation.measures.completion_after_horizon",
                            "validation.measures.after_horizon", "validation.measures.kg800",
                            "validation.measures.kg100", "validation.measures.kg700_double",
                            "validation.measures.active_fraction",
                            "validation.measures.vat_recoverable",
                            "validation.measures.profile_ineffective",
                            "validation.measures.ohnehin_both",
                            "validation.measures.ohnehin_exceeds",
                            "validation.measures.ohnehin_due_both",
                            "validation.measures.ohnehin_due_after",
                            "validation.measures.tax_spread_class",
                            "validation.measures.kind_ohnehin_conflict",
                            "validation.measures.asset_type_conflict",
                            "validation.measures.pv_vat_unchecked",
                            "validation.measures.funding_choice_35c",
                            "validation.measures.contractor_35c", "validation.required",
                            "validation.measures.type_project_mismatch"),
             dm(function(x) {
               at <- vocab_codes("asset_types")
               x$measures <- c(x$measures, list(
                 m1 = wsb_m(year = 2028L, cost_kg = list(kg300 = 1000)),
                 m2 = wsb_m(date = NULL, payment_schedule = list(
                   schedule = list("2028-01-01" = 0.5, "2028-06-01" = 0.3), unit = "share")),
                 m4 = wsb_m(date = "2026-06-01"),
                 m5 = wsb_m(date = NULL, cost_eur = NULL, duration_months = 3L,
                            payment_schedule = list(schedule = list("2028-01-01" = 1000),
                                                    unit = "eur")),
                 m6 = wsb_m(date = "2028-06-01", completion_date = "2028-01-01"),
                 m7 = wsb_m(date = "2046-06-01", completion_date = "2050-01-01"),
                 m7b = wsb_m(date = "2048-01-01"),
                 m8 = wsb_m(kg = 800L), m9 = wsb_m(kg = 100L),
                 m10 = wsb_m(cost_eur = NULL, cost_kg = list(kg300 = 1000, kg700 = 100),
                             kg700_share = 0.2),
                 m11 = wsb_m(active = 0.5), m12 = wsb_m(vat_recoverable = TRUE),
                 m13 = wsb_m(payment_profile = "s_curve"),
                 m14 = wsb_m(ohnehin_share = 0.5, ohnehin_cost_eur = 100),
                 m15 = wsb_m(ohnehin_cost_eur = 2000),
                 m16 = wsb_m(ohnehin_due_date = "2030-01-01", ohnehin_due_year = 2031L),
                 m17 = wsb_m(ohnehin_due_year = 2050L),
                 m18 = wsb_m(tax_spread_years = 3L, classification = "herstellung"),
                 m19 = wsb_m(modernization_kind = "bgb_555b_1", ohnehin_share = 1),
                 m20 = wsb_m(asset_id = "a1", asset_type = at[1L]),
                 m21 = wsb_m(asset_id = "a1", asset_type = at[2L]),
                 m22 = wsb_m(measure_type = "pv"),
                 m23 = list(measure_type = "erwerb_objekt", date = "2027-01-01")))
               wsb_funding(x, s35c = list(instrument_type = "tax_credit"), beg = list())
             }),
             # Folgefehler des fehlenden Kaufpreises: die Ableitung von land_share (WS-A) verweist
             # auf measures.m23.purchase_price_eur
             allow = "validation.expr.path_missing"),
    wsb_case("Zahlungsplan: Betrag als Wachstumsform", "validation.measures.schedule_amount_form",
             dm(function(x) {
               x$measures$m3 <- wsb_m(date = NULL, cost_eur = NULL, payment_schedule = list(
                 schedule = list("2028-01-01" = list(start = 1000, growth = 0.02)),
                 unit = "eur"))
               x
             }), allow = "validation.measures.cost_source"),
    wsb_case("Maßnahmen: Herkunft aus Katalog und Regeln",
             c("validation.measures.ohnehin_catalog", "validation.measures.kind_from_classification",
               "validation.measures.catalog_defaults"),
             fun = function() {
               spec <- wsb_spec(function(x) {
                 x$measures$huelle$ohnehin_share <- 0.3
                 x$measures$m2 <- wsb_m(classification = "erhaltung", modernization_kind = "none")
                 x
               }, function(s) {
                 wsb_spec_with_library(s, wsb_rows(
                   c("measures.huelle.ohnehin_share", "measures.m2.modernization_kind"),
                   entry = c("costs/massnahmentypen_2026", "rule:measure_catalog"),
                   layer = c(3L, 0L)))
               })
               wsb_codes(spec)
             }),
    wsb_case("PV-Umsatzsteuer", "validation.measures.pv_vat_conflict",
             dm(function(x) {
               x$measures$pv1 <- wsb_m(measure_type = "pv", vat_rate = 0.19)
               x$energy <- list(pv = list(kwp = 20, measure = "pv1", self_consumption_share = 0.3,
                                          feed_in_tariff_eur_kwh = 0.08))
               x
             })),
    wsb_case("Maßnahmen: Mietrecht", c("validation.measures.levy_ineffective",
                                       "validation.measures.levy_procedure",
                                       "validation.measures.fictitious_maintenance_high",
                                       "validation.measures.heating_part_kind",
                                       "validation.measures.hp_state_unknown",
                                       "validation.measures.hp_state_missing",
                                       "validation.measures.allocation_sum",
                                       "validation.measures.declaration_early",
                                       "validation.measures.levy_effective_early",
                                       "validation.measures.works_after_completion"),
             dm(function(x) {
               x$measures$huelle$modernization_kind <- "none"
               x$measures$huelle$rent_law <- list(
                 levy = "auto", procedure = "bgb_559e", fictitious_maintenance_cost_eur = 600000,
                 heating_part_share = 0.2, hp_state = "gibts", allocation = list(a = 0.5),
                 declaration_date = "2027-06-01", levy_effective_date = "2027-01-15",
                 works_start_date = "2029-01-01")
               x$measures$m2 <- wsb_m(rent_law = list(heat_pump = TRUE))
               x
             })),
    wsb_case("Erwerb", c("validation.acquisition.federal_state_missing",
                         "validation.acquisition.grest_inactive",
                         "validation.acquisition.land_share_extreme",
                         "validation.acquisition.ancillary_sum",
                         "validation.acquisition.uniform_without_construction",
                         "validation.acquisition.grest_zero"),
             dm(function(x) {
               x$project$project_type <- "erwerb_sanierung"
               x$project$federal_state <- NULL
               x$building$existing_value_eur <- NULL
               x$measures$kauf <- list(measure_type = "erwerb_objekt", date = "2027-01-01",
                                       purchase_price_eur = 500000, land_share = 0,
                                       notary_share = 0.03, land_registry_share = 0.005,
                                       uniform_contract = TRUE)
               x$measures$kauf2 <- list(measure_type = "erwerb_grundstueck", date = "2027-01-01",
                                        purchase_price_eur = 100000, grest_rate = 0)
               x
             })),
    wsb_case("Erwerb: Landessatz", "validation.acquisition.grest_rate_deviation",
             fun = function() {
               spec <- wsb_spec(function(x) {
                 x$project$project_type <- "erwerb_sanierung"
                 x$building$existing_value_eur <- NULL
                 x$measures$kauf <- list(measure_type = "erwerb_grundstueck",
                                         date = "2027-01-01", purchase_price_eur = 100000,
                                         grest_rate = 0.05)
                 x
               }, function(s) {
                 s$legal$grunderwerbsteuer <- list(entry = "legal/grunderwerbsteuer_2026",
                                                   values = list(rates = list(NW = 0.065),
                                                                 exemption_threshold_eur = 2500))
                 s
               })
               wsb_codes(spec)
             }),
    wsb_case("Instandhaltung", c("validation.maintenance.double_count",
                                 "validation.maintenance.service_double",
                                 "validation.maintenance.service_double_energy",
                                 "validation.maintenance.window"),
             dm(function(x) {
               x$building$maintenance <- list(enabled = TRUE, basis = "rate", rate_eur_m2_pa = 14.4,
                                              excludes_explicit_replacements = FALSE,
                                              start_event = "2030-01-01", to = "2029-01-01")
               x$measures$huelle$replacement <- list(enabled = TRUE)
               x$measures$wp <- wsb_m(measure_type = "heizung_waermepumpe_luft",
                                      effects = list(maintenance = list(share_of_cost_pa = 0.01)))
               x$energy <- list(
                 after = list(measure = "wp", service_eur_pa = 100),
                 pv = list(kwp = 10, measure = "wp", self_consumption_share = 0.3,
                           feed_in_tariff_eur_kwh = 0.08, opex_share_of_cost = 0.01))
               x
             })),
    wsb_case("Instandhaltung: Defaults und Ausschluss",
             c("validation.maintenance.default_rate",
               "validation.maintenance.replacements_excluded"),
             fun = function() {
               spec <- wsb_spec(function(x) {
                 x$building$maintenance <- list(enabled = TRUE, basis = "rate",
                                                rate_eur_m2_pa = 14.4,
                                                excludes_explicit_replacements = TRUE)
                 x
               }, function(s) {
                 prov <- attr(s, "provenance")
                 prov$layer[prov$path == "building.maintenance.rate_eur_m2_pa"] <- 1L
                 attr(s, "provenance") <- prov
                 s
               })
               wsb_codes(spec)
             }),
    wsb_case("Wohnungsgruppen", c("validation.unit_groups.regime_conflict",
                                  "validation.unit_groups.rent_missing",
                                  "validation.unit_groups.rent_start_before",
                                  "validation.unit_groups.rent_end_order",
                                  "validation.unit_groups.ovm_missing",
                                  "validation.unit_groups.kappung_basis",
                                  "validation.unit_groups.ovm_low",
                                  "validation.unit_groups.rent_above_ovm",
                                  "validation.unit_groups.growth_early",
                                  "validation.unit_groups.levy_history_auto",
                                  "validation.unit_groups.history_after_valuation",
                                  "validation.unit_groups.market_rent_low",
                                  "validation.unit_groups.vacancy_double",
                                  "validation.unit_groups.default_rate_high",
                                  "validation.unit_groups.losses_high",
                                  "validation.unit_groups.staffel_missing",
                                  "validation.unit_groups.staffel_interval",
                                  "validation.unit_groups.binding_end_missing",
                                  "validation.unit_groups.rent_roll_mismatch",
                                  "validation.unit_groups.rent_roll_large",
                                  "validation.unit_groups.cap_mode_conflict",
                                  "validation.unit_groups.cap_mode_no_before",
                                  "validation.unit_groups.nonrecoverable_double"),
             dm(function(x) {
               g <- function(...) utils::modifyList(list(n_units = 2L, living_area_m2 = 100,
                                                         rent_eur_m2_month = 10), list(...))
               roll <- stats::setNames(rep(list(list(living_area_m2 = 2)), 51),
                                       paste0("w", 1:51))
               x$unit_groups <- list(
                 g1 = g(owner_occupied = TRUE, rent_regime = "paragraph_558"),
                 g2 = g(rent_eur_m2_month = NULL),
                 g3 = g(rent_start = "2026-01-01", rent_end = "2025-01-01"),
                 g4 = g(increase_policy = "max"),
                 g5 = g(ovm_eur_m2_month = 7), g6 = g(ovm_eur_m2_month = 8.2),
                 g7 = g(rent_start = "2027-01-01", growth_from = "2027-06-01"),
                 g8 = g(levy_history = list(h1 = list(effective_date = "2028-01-01",
                                                      procedure = "auto"))),
                 g9 = g(market_rent_eur_m2_month = 5),
                 g10 = g(relet_vacancy_months = 2, vacancy_rate = 0.05, rent_default_rate = 0.03),
                 g11 = g(vacancy_rate = 0.25, rent_default_rate = 0.1),
                 g12 = g(rent_regime = "staffel"),
                 g13 = g(rent_regime = "staffel", staffel_steps = list(
                   schedule = list("2028-01-01" = 1, "2028-06-01" = 2))),
                 g14 = g(rent_regime = "bound_social"),
                 g15 = g(rent_roll = list(w1 = list(living_area_m2 = 50))),
                 g16 = g(n_units = 51L, rent_roll = roll),
                 g17 = g(rent_law = list(voluntary_cap_mode = "warm_rent_neutral",
                                         voluntary_cap_per_m2 = 1)),
                 g18 = g(operating = list(nonrecoverable_eur_m2_pa = 1,
                                          nonrecoverable_share_of_rent = 0.01)))
               x
             })),
    wsb_case("Wohnungsgruppen: Pauschale beim Selbstnutzer",
             "validation.unit_groups.owner_opex_double",
             fun = function() {
               spec <- wsb_spec(function(x) {
                 x$unit_groups$a$owner_occupied <- TRUE
                 x$unit_groups$a$operating <- list(recoverable_opex_eur_m2_month = 1.7)
                 x$components$bk <- list(type = "recurring", category = "operating_cost",
                                         amount_eur = 100)
                 x
               }, function(s) {
                 prov <- attr(s, "provenance")
                 p <- "unit_groups.a.operating.recoverable_opex_eur_m2_month"
                 prov$entry[prov$path == p] <- "global#item_defaults.unit_groups"
                 attr(s, "provenance") <- prov
                 s
               })
               wsb_codes(spec)
             }),
    wsb_case("Energie", c("validation.energy.carrier_class_missing",
                          "validation.energy.gas_price_high",
                          "validation.energy.vat_biomass", "validation.energy.emission_hi",
                          "validation.energy.before_start", "validation.energy.demand_basis",
                          "validation.energy.shares_sum", "validation.energy.heating_carrier_both",
                          "validation.energy.consumption_carrier",
                          "validation.energy.efficiency_high",
                          "validation.energy.measured_outside_before",
                          "validation.energy.state_order", "validation.energy.measure_twice",
                          "validation.energy.flow_temperature_high",
                          "validation.energy.emergency_ineffective",
                          "validation.energy.double_reduction",
                          "validation.energy.co2_reduction_check",
                          "validation.energy.co2_hardship"),
             dm(function(x) {
               x$building$denkmal <- TRUE
               x$energy <- list(
                 carriers = list(x1 = list(price_eur_kwh = 0.1),
                                 gas = list(price_eur_kwh = 0.35, emission_factor_kg_kwh = 0.202),
                                 oil = list(price_eur_kwh = 0.1, co2_price_eur_t = 50,
                                            bio_premium_eur_kwh = 0.01),
                                 pellets = list(price_eur_kwh = 0.08, vat_rate = 0.07)),
                 before = list(start_event = "2027-06-01", consumption_basis = "demand",
                               carrier_shares = list(gas = 0.6, oil = 0.3),
                               heating_carrier = "gas", efficiency = 1.2,
                               consumption_kwh = list(pellets = 100)),
                 stages = list(s1 = list(measure = "huelle", consumption_basis = "measured",
                                         start_event = "2026-01-01")),
                 after = list(measure = "huelle", flow_temperature_c = 80, jaz = 3,
                              emergency_replacement = TRUE, installation_date = "2028-06-01"),
                 performance_gap = list(realisation_factor = 0.9, rebound_factor = 1.1),
                 co2_landlord_share_reduction = 0, co2_hardship_5d = TRUE)
               x
             }), allow = "validation.energy.co2_price_missing"),
    wsb_case("Energie: Trägerfelder fehlen nach den Defaults",
             c("validation.energy.network_fee_missing", "validation.energy.co2_price_missing",
               "validation.energy.bio_premium_missing"),
             fun = function() {
               # Netzentgelt, CO2-Preis und Bio-Aufschlag setzen nach der Integration Ableitungs-
               # regel und Vorlagen (WS-A); die Prüfung gilt dem aufgelösten Zustand
               spec <- wsb_spec(function(x) {
                 x$energy <- list(carriers = list(gas = list(price_eur_kwh = 0.06)))
                 x
               }, function(s) {
                 s$energy$carriers$gas[c("network_fee_eur_kwh", "co2_price_eur_t",
                                         "bio_premium_eur_kwh")] <- NULL
                 s
               })
               wsb_codes(spec)
             }),
    wsb_case("Energie: Prebound bei Verbrauchsdaten", "validation.energy.prebound_measured",
             dm(function(x) {
               x$energy <- list(before = list(consumption_basis = "measured"),
                                performance_gap = list(prebound_factor = 1.1))
               x
             })),
    wsb_case("PV", c("validation.energy.pv_full_self", "validation.energy.pv_tariff_missing",
                     "validation.energy.pv_vat_attested", "validation.energy.pv_vat_full",
                     "validation.energy.pv_internal_price"),
             fun = function() {
               a <- wsb_codes(wsb_with("domain", function(x) {
                 x$energy <- list(pv = list(kwp = 12, self_consumption_share = 0.3,
                                            feed_in_mode = "full",
                                            vat_zero_rate_attested = TRUE))
                 x
               }))
               b <- wsb_codes(wsb_with("domain", function(x) {
                 x$project$perspective <- "wu_genossenschaft"
                 x$energy <- list(pv = list(kwp = 40, self_consumption_share = 0.3,
                                            feed_in_tariff_eur_kwh = 0.08,
                                            vat_zero_rate_attested = FALSE,
                                            internal_price_eur_kwh = 0.1))
                 x
               }))
               c(a, b)
             }),
    wsb_case("Förderung", c("validation.funding.measures_empty",
                            "validation.funding.not_eligible", "validation.funding.class_missing",
                            "validation.household.taxable_income_missing",
                            "validation.funding.block_missing",
                            "validation.funding.eligibility_override",
                            "validation.funding.start_before_application",
                            "validation.funding.approval_low",
                            "validation.funding.eligible_share_measure",
                            "validation.funding.eligible_cost_set",
                            "validation.funding.basis_loan_share",
                            "validation.funding.loan_term_range",
                            "validation.funding.loan_variant_unknown",
                            "validation.funding.prior_credit",
                            "validation.funding.degression_target",
                            "validation.funding.condition_invalid",
                            "validation.funding.condition_symbol",
                            "validation.funding.cumulation_requires",
                            "validation.funding.annual_cap_shared"),
             dm(function(x) {
               el <- list(project_types = "neubau", measure_types = "fenster",
                          applicants = "weg",
                          conditions = list(owner_occupied = "required",
                                            efficiency_standard = "eh55",
                                            ee_or_nh_class = "required",
                                            taxable_income_max_eur = 90000))
               wsb_funding(x,
                 f1 = list(instrument_type = "loan", measures = list()),
                 f2 = list(eligibility = el, applicant = "unternehmen"),
                 f3 = list(instrument_type = "interest_subsidy"),
                 f4 = list(eligibility_override = TRUE),
                 f5 = list(application_before_start = TRUE, application_date = "2029-01-01"),
                 f6 = list(approval_probability = 0.3),
                 f7 = list(eligible_shares = list(gibts = 0.5), eligible_cost_eur = 1000),
                 f8 = list(instrument_type = "loan", basis = list(max_share_of_eligible_costs = 1),
                           loan = list(variants = list(v1 = list(term_years = 50,
                                                                 grace_years = 2)),
                                       default_variant = "v1",
                                       term_ranges = list(annuity = list(
                                         list(term = c(4, 10), grace = c(1, 2)))))),
                 f9 = list(instrument_type = "loan", loan_variant = "v9",
                           loan = list(variants = list(v1 = list(term_years = 10)))),
                 f10 = list(instrument_type = "tax_credit", credit = list(cap_per_object_eur = 40000),
                            prior_credit_used_eur = 50000),
                 f11 = list(degression = list(list(target = "rate_components.gibts.rate",
                                                   start = "2027-02-01", step = -0.04,
                                                   every_months = 6L, floor = 0)),
                            rate_components = list(
                              grund = list(rate = 0.3, condition = "1 +"),
                              bonus = list(rate = 0.1,
                                           condition = "building.living_area_m2 > 100"),
                              ok = list(rate = 0.1, condition = "unit.owner_occupied"))),
                 f12 = list(cumulation = list(requires = c("funding/kfw_458"))),
                 f13 = list(program_code = "x", basis = list(cap_period = "calendar_year")),
                 f14 = list(program_code = "x", basis = list(cap_period = "calendar_year")))
             }), allow = c("validation.ref_id_unknown", "validation.measures.funding_choice_35c")),
    wsb_case("Förderung: Kumulierung", "validation.funding.cumulation_exclusive",
             fun = function() {
               spec <- wsb_spec(function(x) {
                 wsb_funding(x, f1 = list(cumulation = list(exclusive_with = "funding/estg_35c")),
                             f2 = list(instrument_type = "tax_credit"))
               }, function(s) {
                 wsb_spec_with_library(s, wsb_rows("funding.f2.instrument_type",
                                                   entry = "funding/estg_35c"))
               })
               wsb_codes(spec)
             }),
    wsb_case("Haushalt (Selbstnutzer)", c("validation.household.income_missing",
                                          "validation.household.current_rent_missing",
                                          "validation.household.income_tax_missing",
                                          "validation.household.savings_double",
                                          "validation.unit_groups.imputed_rent_active",
                                          "validation.building.property_tax_missing"),
             dm(function(x) {
               x$project$perspective <- "selbstnutzer"
               x$project$project_type <- "neubau"
               x$building$property_tax <- NULL
               x$unit_groups$a$owner_occupied <- TRUE
               x$unit_groups$a$rent_eur_m2_month <- NULL
               x$unit_groups$a$imputed_rent_eur_m2_month <- 9
               x$household <- list(savings_eur = 10000)
               wsb_funding(x, s35c = list(instrument_type = "tax_credit"))
             })),
    wsb_case("Restwert", c("validation.residual.land_value_missing",
                           "validation.residual.double_count",
                           "validation.residual.fictitious_points",
                           "validation.residual.construction_year_missing",
                           "validation.residual.manual_years_missing",
                           "validation.residual.no_rent", "validation.residual.asset_value_rented",
                           "validation.residual.existing_excluded",
                           "validation.residual.no_useful_life"),
             fun = function() {
               rv <- function(f) wsb_codes(wsb_with("domain", f))
               c(rv(function(x) {
                 x$building$land_value_eur <- NULL
                 x$building$fictitious_construction_year <- 1990L
                 x$building$modernization_points_before <- list(heating = 1L)
                 x$residual_value <- list(method = "income_value", income_value = list(
                   bog_component_residual = TRUE))
                 x
               }), rv(function(x) {
                 x$building$construction_year <- NULL
                 x$residual_value <- list(method = "income_value", income_value = list(
                   land_value_eur = 1e5))
                 x
               }), rv(function(x) {
                 x$unit_groups$a$owner_occupied <- TRUE
                 x$residual_value <- list(method = "income_value", income_value = list(
                   land_value_eur = 1e5, remaining_life_method = "manual"))
                 x
               }), rv(function(x) {
                 x$residual_value <- list(method = "asset_value", asset_value = list(
                   land_value_eur = 1e5))
                 x
               }), rv(function(x) {
                 x$measures$huelle$measure_type <- "sonstige"       # Katalog ohne Nutzungsdauer
                 x$measures$huelle$useful_life_years <- NULL
                 x$residual_value <- list(method = "component", component = list(
                   include_existing = "false"))
                 x
               }))
             }),
    # Teil A 6.2 Nr. 5: ohne building nur user_value, zero, market_growth (mit Ausgangswert)
    # und exit_yield; Abbruch des Expanders residual mit eigenem Schlüssel (val_resolve_finding())
    wsb_case("Restwert ohne building: Methode", "validation.residual.method_needs_building",
             make = function() vofi_scenario(wsb_skeleton_defaults("asset_value"))),
    wsb_case("Restwert ohne building: Ausgangswert", "validation.residual.base_value_missing",
             make = function() vofi_scenario(wsb_skeleton_defaults("market_growth")))
  )
}

# ---------------------------------------------------------------------------------------------
# Prüffälle ohne Szenario: Ausdrücke, Bericht, JSON-Schema, Eingabe von vofi_validate()
# ---------------------------------------------------------------------------------------------

#' Schlüssel einer Bedingung (bzw. `NA`, wenn keine auftritt)
wsb_cond_key <- function(expr) {
  tryCatch({
    force(expr)
    NA_character_
  }, error = function(e) e$key %||% NA_character_)
}

wsb_cases_other <- function() {
  vals <- list(a.v = c(1, 2, 3), p.code = "x", p.date = as.Date("2027-01-01"),
               p.list = list(1))
  res <- function(p) vals[[p]]
  ev <- function(txt) expr_eval(expr_parse(txt), res, 3L, 3L)
  list(
    wsb_case("Ausdrücke", c("validation.expr.empty", "validation.expr.syntax",
                            "validation.expr.multiple", "validation.expr.literal",
                            "validation.expr.symbol", "validation.expr.function",
                            "validation.expr.named_arg", "validation.expr.arity",
                            "validation.expr.not_deterministic", "validation.expr.not_numeric",
                            "validation.expr.code_operand", "validation.expr.path_missing",
                            "validation.expr.not_numeric_symbol",
                            "validation.expr.ifelse_nonfinite", "validation.expr.position"),
             fun = function() {
               keys <- c(wsb_cond_key(expr_parse("")), wsb_cond_key(expr_parse("1 +")),
                         wsb_cond_key(expr_parse("a.v; a.v")), wsb_cond_key(expr_parse("NA")),
                         wsb_cond_key(expr_parse("x + 1")), wsb_cond_key(expr_parse("max(a.v)")),
                         wsb_cond_key(expr_parse("round(a.v, n = 1)")),
                         wsb_cond_key(expr_parse("abs(a.v, a.v)")),
                         wsb_cond_key(expr_parse("round(a.v, a.v)")),
                         wsb_cond_key(ev("p.code")), wsb_cond_key(ev("p.code + 1")),
                         wsb_cond_key(ev("a.fehlt")), wsb_cond_key(ev("p.list + 1")),
                         wsb_cond_key(ev("ifelse(a.v > 1, 1 / 0, 0)")))
               e <- tryCatch(expr_parse("1 +"), error = identity)
               if (grepl(lbl("validation.expr.position", line = 1L, col = 4L),
                         conditionMessage(e), fixed = TRUE)) {
                 keys <- c(keys, "validation.expr.position")
               }
               keys
             }),
    wsb_case("Bericht", c("validation.report.header", "validation.report.none",
                          "validation.report.line", "validation.report.location",
                          "validation.report.variants", "validation.report.more"),
             fun = function() {
               empty <- format(wsb_validate(wsb_with("skeleton")))
               v <- vofi_validate(wsb_with("skeleton", function(x) {
                 x$accounts$deposit_rate <- 0.02
                 x$accounts$overdraft_rat <- 0.02
                 x$variants <- list(v1 = list(label = "v1",
                                              set = list("accounts.deposit_rate_pa" = 0.03)))
                 x
               }))
               v$location[1L] <- "Zeile 7"
               txt <- format(v, max_rows = 1)
               sev <- lbl("vocab.enums.severity.error")
               c(if (identical(empty[2L], lbl("validation.report.none"))) "validation.report.none",
                 if (startsWith(txt[1L], "Validierung:")) "validation.report.header",
                 if (startsWith(txt[2L], paste0("[", sev, "]"))) "validation.report.line",
                 if (grepl("Zeile 7", txt[2L], fixed = TRUE)) "validation.report.location",
                 if (grepl("base, v1", txt[2L], fixed = TRUE)) "validation.report.variants",
                 if (grepl("weitere", txt[3L], fixed = TRUE)) "validation.report.more")
             }),
    wsb_case("JSON-Schema und Eingabe", c("validation.schema.title",
                                          "validation.schema.description",
                                          "validation.not_validatable"),
             fun = function() {
               s <- jsonlite::fromJSON(vofi_json_schema(), simplifyVector = FALSE)
               c(if (identical(s$title, lbl("validation.schema.title"))) "validation.schema.title",
                 if (identical(s$description, lbl("validation.schema.description"))) {
                   "validation.schema.description"
                 },
                 wsb_cond_key(vofi_validate(list())))
             })
  )
}

# ---------------------------------------------------------------------------------------------
# Positivfälle mit vollständigen Blöcken (Review m5): Defaults nach global.yaml und Profil
# (Spec 01 Teil A 2.2, 2.3; Teil C 1.2, 4.4) ohne Bibliotheksverweise
# ---------------------------------------------------------------------------------------------

#' Marktnamen der Defaults (Spec 00 4.3.11; Werte wie prices/macro_paths_2026)
wsb_market <- function() {
  list(inflation = 0.02, rent_growth = 0.0175, land_value_growth = 0.015,
       market_value_growth = 0.015, construction_price_index = 0.025, mortgage_rate = 0.041)
}

#' Stochastik-Einstellungen wie global.yaml (Teil C 1.2)
wsb_settings <- function() {
  list(preset = "standard", seed = 20261025L, sampling = "lhs", block_size = 200L,
       antithetic = FALSE, copula = "iman_conover", store = "bands",
       keep_runs = c("p05", "p50", "p95"), keep_runs_kpi = "delta_terminal_value",
       bands = c("net_position", "dep_balance", "od_balance"),
       band_probs = c(0.05, 0.25, 0.5, 0.75, 0.95), auto_funding_approval = TRUE,
       convergence = list(rel_halfwidth_mean = 0.005, abs_halfwidth_prob = 0.01))
}

#' Analyse wie global.yaml und Profil wu_kommunal (Teil A 2.2, 2.3; Teil C 4.4)
wsb_analysis <- function() {
  list(kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value"),
       primary_kpi = "auto", allow_opportunity_reference = FALSE,
       deterministic_point = "mode",
       thresholds = list(dscr = 1.2, burden_share = 0.40, warm_rent_increase_eur_m2 = 0.50,
                         roe_hurdle = 0.025),
       lending_value_haircut = 0.10, rv_path_basis = "auto", restrictions = "dscr",
       traffic_light = list(green_prob = 0.70, red_prob = 0.40, restriction_prob = 0.30),
       mandatory_sensitivities = list(
         list(id = "restwert_null", path = "residual_value.method", value = "zero",
              label = "Restwert = 0"),
         list(id = "habenzins_liquiditaet", path = "accounts.deposit_rate_pa", value = 0.02,
              label = "Habenzins 2,0 %"),
         list(id = "habenzins_kalkulationszins", path = "accounts.deposit_rate_pa",
              value = 0.035, label = "Habenzins 3,5 %"),
         list(id = "habenzins_fk", path = "accounts.deposit_rate_pa",
              value = list(ref = "market.mortgage_rate"), label = "Habenzins = FK-Zins"),
         list(id = "stufe_2045", path = "project.pending_reforms", add = "stufe_2045",
              label = "mit 2045-Stufe")))
}

#' Restwert wie global.yaml (Teil A 2.2) mit gewählter Methode
wsb_residual <- function(method = "zero") {
  ref <- function(p) list(ref = p)
  list(
    method = method, sale_cost_share = 0.03, path_pre_operation = "auto",
    income_value = list(
      variant = "general", cap_rate = 0.035, remaining_life_method = "anlage2",
      remaining_life_offset_years = 0, gnd_years = 80, income_basis = "forward",
      forward_growth = ref("market.rent_growth"), cost_forward_growth = ref("market.inflation"),
      include_other_income = FALSE, land_value_eur = ref("building.land_value_eur"),
      land_value_growth = ref("market.land_value_growth"),
      bwk = list(admin_eur_unit_pa = 367, maintenance_eur_m2_pa = 14.40, rent_loss_share = 0.02,
                 price_base_year = 2025L, index = ref("market.inflation"),
                 admin_source = "model", maintenance_source = "model",
                 variant_cost_categories = c("co2_cost", "energy_cost", "other_cost"),
                 vacancy_from_ledger = TRUE),
      bog_eur = 0, bog_component_residual = FALSE, stranded_discount_share = 0,
      liquidation_floor = TRUE, demolition_cost_eur = 0),
    multiplier = list(factor = 20, basis = "net_cold_rent_incl_levy", income_basis = "forward",
                      forward_growth = ref("market.rent_growth")),
    exit_yield = list(cap_rate = 0.04, income_basis = "forward",
                      forward_growth = ref("market.rent_growth"),
                      cost_forward_growth = ref("market.inflation")),
    market_growth = list(growth = ref("market.market_value_growth"), uplift_share = 0),
    asset_value = list(life_basis = "gnd", gnd_years = ref("residual_value.income_value.gnd_years"),
                       kg_include = c(200L, 300L, 400L, 500L, 700L), include_existing = TRUE,
                       market_adjustment_factor = 1.0, uplift_share = 0,
                       index = ref("market.construction_price_index"),
                       land_value_eur = ref("building.land_value_eur"),
                       land_value_growth = ref("market.land_value_growth")),
    component = list(indexed = TRUE, include_land = FALSE, include_existing = "auto",
                     existing_growth = ref("market.market_value_growth")),
    user_value = list(value_eur = 0))
}

#' Gerüst mit den Defaults ohne building (Spec 01 Teil A 6.1: gültig, R-115)
wsb_skeleton_defaults <- function(method = "income_value") {
  x <- wsb_skeleton()
  x$market <- wsb_market()
  x$residual_value <- wsb_residual(method)
  x$analysis <- utils::modifyList(wsb_analysis(), x$analysis)
  x$stochastic <- list(settings = wsb_settings())
  x
}

#' Bestandsprojekt mit vollständigen Domänenblöcken: Bestandsbauteile, Energieträger und
#' -zustände (after vor einer späteren Stufe, Teil B 3.2.2), Defaults wie global.yaml
wsb_full <- function() {
  x <- wsb_domain()
  x$market <- wsb_market()
  x$building$land_value_eur <- 200000
  x$building$elements <- list(
    kessel = list(measure_type = "heizung_gaskessel", installed_year = 2010L,
                  replacement_cost_eur = 95000, useful_life_years = 20, price_index = 0.02,
                  next_replacement_delay_months = 0, active = 1))
  x$measures$huelle$replaces_elements <- list()
  x$energy <- list(
    carriers = list(
      gas = list(price_eur_kwh = 0.06, network_fee_eur_kwh = 0.02, vat_rate = 0.19,
                 emission_factor_kg_kwh = 0.1814, co2_price_eur_t = 55,
                 bio_premium_eur_kwh = 0.01, base_fee_eur_pa = 150, fee_growth = 0.02),
      heatpump_power = list(price_eur_kwh = 0.22, vat_rate = 0.19)),
    before = list(consumption_basis = "demand", demand_kwh = 120000, heating_carrier = "gas",
                  efficiency = 0.9, installation_date = "2010-01-01"),
    stages = list(daemm = list(measure = "huelle", demand_kwh = 90000),
                  ersatz = list(start_event = 2045L, service_eur_pa = 300)),
    after = list(start_event = 2035L, heating_carrier = "heatpump_power", jaz = 3.2,
                 heat_pump_carrier = "heatpump_power", flow_temperature_c = 55),
    performance_gap = list(prebound_factor = 0.8, rebound_factor = 1.1,
                           realisation_factor = 1))
  x$accounts$deposit_rate_pa <- list(ref = "market.mortgage_rate", anchor = 0.025, floor = 0)
  x$accounts$overdraft_rate_pa <- list(ref = "market.mortgage_rate", anchor = 0.06)
  x$residual_value <- wsb_residual("income_value")
  x$analysis <- wsb_analysis()
  x$stochastic <- list(settings = wsb_settings())
  x$measures$huelle$cost_factor <- list(
    expr = "ifelse('stufe_2045' %in% project.pending_reforms, 1.1, 1)")
  x$project$pending_reforms <- list()
  x
}

# ---------------------------------------------------------------------------------------------
# Prüffälle der Review-Korrekturen (B1-B6, M1-M6, m1-m4)
# ---------------------------------------------------------------------------------------------

wsb_cases_review <- function() {
  sk <- function(f) function() wsb_with("skeleton", f)
  dm <- function(f) function() wsb_with("domain", f)
  fl <- function(f) function() vofi_scenario(f(wsb_full()))
  list(
    wsb_case("B1: Felder der Sammlungselemente nach Katalog", "validation.unknown_field",
             fl(function(x) {
               x$building$elements$kessel$baujahr <- 1998L
               x$energy$carriers$gas$preis <- 0.1
               x$energy$stages$daemm$wirkungsgrad <- 0.9
               x
             })),
    wsb_case("B2: band_probs als Zahlenliste", c("validation.not_increasing", "validation.range",
                                                 "validation.not_number"),
             fun = function() {
               v <- function(bp) {
                 vofi_validate(wsb_with("skeleton", function(x) {
                   x$stochastic <- list(settings = list(band_probs = bp))
                   x
                 }))$code
               }
               c(v(c(0.5, 0.25)), v(c(0, 0.5)), v("viele"))
             }),
    wsb_case("B3: Pflichtsensitivitäten nach der Art des Ziels",
             c("validation.enum", "validation.analysis.sensitivity_op_kind", "validation.range"),
             sk(function(x) {
               x$analysis$mandatory_sensitivities <- list(
                 list(id = "a", path = "residual_value.method", value = "nix", label = "A"),
                 list(id = "b", path = "residual_value.method", delta = 0.1, label = "B"),
                 list(id = "c", path = "accounts.deposit_rate_pa", add = "x", label = "C"),
                 list(id = "d", path = "project.pending_reforms", add = "gibts", label = "D"),
                 list(id = "e", path = "accounts.deposit_rate_pa", value = 0.5, label = "E"))
               x$residual_value <- list(method = "zero")
               x
             })),
    wsb_case("B4: Restwertbezug ohne building wird bei exit_yield gelesen",
             "validation.ref_target_missing",
             sk(function(x) {
               x$residual_value <- list(method = "exit_yield",
                                        exit_yield = list(cap_rate = list(ref = "market.fehlt")))
               x
             })),
    wsb_case("B5: Prozess mit unbekanntem Typ", "validation.stochastic.process_unknown",
             sk(function(x) {
               x$market$x <- 0.02
               x$stochastic <- list(processes = list(p = list(target = "market.x",
                                                               type = "ar_1")))
               x
             })),
    wsb_case("B6: Bauphase, nur die zweite Maßnahme folgt der Bauzeit",
             "validation.grid.completion_mismatch",
             dm(function(x) {
               x$grid <- list(construction_months = 12L)
               x$measures$b <- wsb_m(date = "2028-07-01", follows_construction = TRUE)
               x
             })),
    wsb_case("M1: Energiezustände mit gleichem Termin bzw. vor before",
             "validation.energy.state_order",
             fun = function() {
               v1 <- vofi_validate(vofi_scenario(within(wsb_full(), {
                 energy$stages$ersatz$start_event <- 2035L
               })))$code
               v2 <- vofi_validate(vofi_scenario(within(wsb_full(), {
                 energy$after$start_event <- "2026-01-01"
               })))$code
               c(v1, v2)
             }),
    wsb_case("M3: Ausdruck mit c() außerhalb von %in% und Fehler des Probelaufs",
             c("validation.expr.c_context", "validation.expr.eval_failed",
               "validation.expr.code_list"),
             fun = function() {
               cl <- wsb_cond_key(expr_eval(expr_parse("p.r == 'x'"),
                                            function(p) c("x", "y"), 2L, 1L))
               sp <- vofi_resolve(wsb_with("skeleton"))
               sp$financing$bank$rate_pa <- list(kind = "expr", text = "c(0.05, 0.04) * 1")
               a <- vofi_validate(sp)$code
               b <- vofi_validate(wsb_with("skeleton", function(x) {
                 x$market <- list(s = c(1, 2), e = list(expr = "market.s * 2"))
                 x$financing$bank$rate_pa <- list(ref = "market.e")
                 x
               }))$code
               c(a, b, cl)
             }),
    wsb_case("M4: statisches Szenario-Set auf den Ebenen 2-4", "validation.range",
             sk(function(x) {
               x$scenario_sets <- list(hoch = list(label = "Hoch",
                                                   set = list("accounts.deposit_rate_pa" = 0.5)))
               x
             })),
    wsb_case("M6: ersetzte Ohnehin-Maßnahme fehlt in der Referenzvariante",
             "validation.measures.replaces_ohnehin_unknown",
             dm(function(x) {
               x$measures$huelle$replaces_ohnehin <- "fenster_alt"
               x
             })),
    wsb_case("M6: Zuschüsse übersteigen Kosten bzw. max_total_share",
             "validation.funding.cumulation_total_share",
             fun = function() {
               a <- wsb_codes(wsb_with("domain", function(x) {
                 wsb_funding(x, f = list(amount_eur = 600000))
               }))
               b <- wsb_codes(wsb_with("domain", function(x) {
                 x$financing$k <- list(type = "annuity_loan", amount_eur = 300000, rate_pa = 0.02,
                                       term_years = 20, measure_id = "huelle",
                                       repayment_grant = list(amount_eur = 100000))
                 wsb_funding(x, f = list(amount_eur = 150000,
                                         cumulation = list(max_total_share = 0.4)))
               }))
               c(a, b)
             }),
    wsb_case("12.3a: Erwerb mit Sanierung ohne Referenzvariante",
             "validation.reference_variant_recommended",
             dm(function(x) {
               x$project$project_type <- "erwerb_sanierung"
               x$building$existing_value_eur <- NULL
               x$variants <- NULL
               x
             })),
    wsb_case("m1/m3: Kostengruppe 100, Neubau im Bestand, negativer Zahlungsplan",
             c("validation.measures.kg100", "validation.measures.type_project_mismatch",
               "validation.range"),
             dm(function(x) {
               x$measures$huelle$kg <- 100L
               x$measures$nb <- list(measure_type = "neubau", date = "2028-01-01",
                                     cost_eur = 1000)
               x$measures$ps <- list(measure_type = "fenster",
                                     payment_schedule = list(schedule = list("2028-01-01" = -5),
                                                             unit = "eur"))
               x
             })),
    wsb_case("m3: Bundesland bei ausdrücklicher Komponente acquisition_cost",
             "validation.acquisition.federal_state_missing",
             sk(function(x) {
               x$components$acq <- list(type = "acquisition_cost", basis_eur = 500000,
                                        date = "2027-01-01")
               x
             }),
             # mit dem Typ von WS-E-INV meldet dessen validate() zusätzlich das inaktive Thema
             # grunderwerbsteuer (legal/grunderwerbsteuer_2026: Qualität C, nicht freigegeben;
             # Teil A 4.13, spezifikationsgemäß)
             allow = c("validation.type_unknown", "validation.acquisition.grest_inactive"))
  )
}

#' Alle Prüffälle
wsb_all_cases <- function() {
  c(wsb_cases_structure(), wsb_cases_types(), wsb_cases_refs(), wsb_cases_plaus(),
    wsb_cases_other(), wsb_cases_review())
}
