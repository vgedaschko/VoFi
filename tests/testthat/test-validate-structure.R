# Tests für R/validate-structure.R (WS-B; Spec 00 Abschnitte 4.2, 4.4, 4.7, 4.9, 4.11, 13.5;
# Spec 01 Teil A 1.3 GA4, Teil C 3.1, 4.1).

codes_of <- function(x) wsb_validate(x)$code

test_that("Walking Skeleton und Orakel (a) sind ohne Befund", {
  for (nm in c("skeleton", "oracle_a")) {
    v <- wsb_validate(example_scenario(nm))
    expect_s3_class(v, "vofi_validation")
    expect_identical(nrow(v), 0L, info = nm)
    expect_identical(names(v), c("severity", "code", "path", "location", "message", "layer",
                                 "variant"))
  }
  expect_identical(nrow(wsb_validate(vofi_resolve(example_scenario("skeleton")))), 0L)
})

test_that("Prüffälle der Ebene 1 (Tabelle)", {
  wsb_registry()
  wsb_expect_cases(wsb_cases_structure())
})

test_that("Struktur: oberste Ebene, schema_version, Pflichtfelder, Codes, Stichtag (GA4)", {
  sc <- example_scenario("skeleton")
  bad <- sc
  bad$horizon_from <- "completion"
  bad$schema_version <- 2L
  bad$meta$scenario_id <- "Gerüst"
  bad$meta$title <- NULL
  bad$project$perspective <- "wu_kommunl"
  bad$project$valuation_date <- as.Date("2027-01-15")
  bad$project$horizon_years <- 0L
  v <- wsb_validate(bad)
  expect_true(all(c("validation.unknown_key", "validation.schema_version",
                    "validation.id_invalid", "validation.required", "validation.enum",
                    "validation.valuation_first", "validation.horizon") %in% v$code))
  expect_match(v$message[v$code == "validation.unknown_key"], "horizon_from", fixed = TRUE)
  expect_match(v$message[v$code == "validation.enum"][1], "wu_kommunal", fixed = TRUE)
  expect_identical(v$layer[v$code == "validation.unknown_key"], 5L)
  expect_identical(nrow(wsb_validate(bad, min_severity = "error")),
                   sum(v$severity == "error"))
  expect_error(wsb_validate(list()), class = "vofi_error_input")
  expect_error(wsb_validate(sc, variant = 1), class = "vofi_error_input")
  expect_error(wsb_validate(sc, min_severity = "fatal"), class = "vofi_error_input")
})

test_that("Reservierte Wurzelschlüssel nur in Defaults-Dateien (4.2 Fn. 3, R-85)", {
  for (k in c("defaults_meta", "by_project_type", "item_defaults")) {
    x <- wsb_skeleton()
    x[[k]] <- list()
    v <- wsb_validate(vofi_scenario(x))
    expect_identical(v$code, "validation.reserved_root_key", info = k)
    expect_identical(v$path, k)
  }
})

test_that("Varianten: Struktur je Variante, Auflösung nur ohne Strukturfehler", {
  sc <- wsb_with("skeleton", function(x) {
    x$variants <- list(a = list(label = "a", extends = "b"), b = list(label = "b",
                                                                      extends = "a"),
                       ok = list(label = "ok", set = list("accounts.deposit_rate_pa" = 0.03)),
                       falsch = list(label = "f", set = list("components.gibts.values" = 1)))
    x
  })
  v <- wsb_validate(sc)
  cyc <- v[v$code == "validation.variants.extends_cycle", , drop = FALSE]
  expect_setequal(cyc$variant, c("a", "b"))
  expect_match(cyc$message[1], "a -> b -> a", fixed = TRUE)
  expect_false(any(v$code == "validation.resolve_failed" & v$variant %in% c("a", "b")))
  # fehlender Pfad: eigener Schlüssel der Meldung von WS-A (val_resolve_finding())
  rf <- v[v$code == "validation.variants.path_missing", , drop = FALSE]
  expect_identical(rf$variant, "falsch")
  expect_match(rf$message, "gibts", fixed = TRUE)
  expect_false(any(v$variant == "ok", na.rm = TRUE))
  # Auswahl der Varianten: nur base und ok
  v2 <- wsb_validate(sc, variant = c("base", "ok"))
  expect_false(any(c("validation.resolve_failed", "validation.variants.path_missing") %in%
                     v2$code))
  # vofi_build einer gültigen Variante scheitert nicht an fehlerhaften anderen Varianten
  expect_s3_class(vofi_build(sc, variant = "ok"), "vofi_model")
})

test_that("Szenario-Sets: Pfade, Platzhalter, shared (z7), generate (Teil C 4.1)", {
  sc <- wsb_with("skeleton", function(x) {
    x$scenario_sets <- list(
      s1 = list(label = "s1", set = list("shared.co2_2030" = 120)),
      s2 = list(label = "s2", set = list("measures.m.cost_eur" = 1)),
      gen = list(label = "Vorsichtig", generate = list(method = "cautious", n_drivers = 5L,
                                                       probs = c(0.1, 0.9), kpi = "auto",
                                                       params = "auto")))
    x
  })
  v <- wsb_validate(sc)
  pf <- v[v$code == "validation.scenario_set.path_forbidden", , drop = FALSE]
  expect_identical(pf$path, "scenario_sets.s1.set")
  expect_match(pf$message, "market-Pfad", fixed = TRUE)
  expect_identical(v$path[v$code == "validation.scenario_set.path_not_allowed"],
                   "scenario_sets.s2.set")
  expect_false(any(v$variant == "gen", na.rm = TRUE))
})

test_that("Fehler beim Auflösen mit eigenem Schlüssel bzw. als resolve_failed", {
  f <- val_resolve_finding(structure(list(message = "x", key = "core.irgendwas",
                                          args = list()),
                                     class = c("vofi_error", "error", "condition")), "v")
  expect_identical(f$code, "validation.resolve_failed")
  expect_identical(f$variant, "v")
  e <- tryCatch(vofi_abort("validation.library.ref_not_id", path = "a.from", value = "2027",
                           .class = "vofi_error_validation"), error = identity)
  f2 <- val_resolve_finding(e, "base")
  expect_identical(f2$code, "validation.library.ref_not_id")
  expect_identical(f2$path, "a.from")
})

test_that("Abbruch eines Expanders verdeckt keine Domänenbefunde (Spec 00 4.1, 9.1)", {
  expect_null(attr(suppressWarnings(vofi_resolve(wsb_with("domain"))), "expand_failed"))
  old <- reg_state$types
  withr::defer(reg_state$types <- old)
  fail <- new.env()
  fail$how <- "validation"
  reg_add(vofi_type(name = "wsb_fail", kind = "expander", block = "measures", order = 95L,
                    expand = function(block, scenario, bctx) {
                      if (identical(fail$how, "validation")) {
                        bctx$abort("expand.measures.id_shared", id = "huelle")
                      }
                      stop("kaputt")
                    }), source = "vofi")
  reg_add(vofi_type(name = "wsb_ok", kind = "expander", block = "measures", order = 96L,
                    expand = function(block, scenario, bctx) {
                      list(components = list(x_ok = list(type = "custom_series",
                                                         values = rep(0, 21L))))
                    }), source = "vofi")
  domain <- function(err = FALSE) {
    wsb_with("domain", function(x) {
      x$components$z$after <- "x_ok"                  # Bezug auf eine erzeugte Komponente
      if (err) x$measures$huelle$useful_life_years <- 0
      x
    })
  }
  # tolerante Auflösung: nur der abgebrochene Expander fehlt
  sp <- suppressWarnings(scn_resolve(domain(), expand = "tolerant"))
  expect_identical(attr(sp, "expand_failed"), "wsb_fail")
  expect_true(all(c("x_ok", "m_huelle_capex") %in% names(sp$components)))
  none <- suppressWarnings(scn_resolve(domain(), expand = "none"))
  expect_false(any(startsWith(names(none$components), "m_")))
  expect_error(vofi_resolve(domain()), class = "vofi_error_validation")
  # Domänenfehler: Befund der Domäne statt resolve_failed (Abbruch ist dessen Folge)
  v <- wsb_validate(domain(TRUE), variant = "base")
  expect_true("validation.range" %in% v$code)
  expect_false("validation.resolve_failed" %in% v$code)
  expect_false("validation.after_unknown" %in% v$code)
  # ohne Domänenfehler bleibt der Abbruch der einzige Fehler
  v <- wsb_validate(domain(), variant = "base")
  e <- v[v$severity == "error", , drop = FALSE]
  expect_identical(e$code, "validation.resolve_failed")
  expect_match(e$message, "zugleich Maßnahme und Bestandsbauteil", fixed = TRUE)
  # Programmfehler eines Expanders wird nie als Folgefehler unterdrückt
  fail$how <- "bug"
  v <- wsb_validate(domain(TRUE), variant = "base")
  expect_true(all(c("validation.range", "validation.resolve_failed") %in% v$code))
  expect_match(v$message[v$code == "validation.resolve_failed"], "kaputt", fixed = TRUE)
})

test_that("Abbruch des Expanders residual mit eigenem Schlüssel, auch im Set (6.2 Nr. 5)", {
  x <- wsb_skeleton_defaults("income_value")
  x$scenario_sets <- list(sv = list(label = "Sachwert",
                                    set = list("residual_value.method" = "asset_value")))
  v <- wsb_validate(vofi_scenario(x))
  expect_identical(v$code, "validation.residual.method_needs_building")
  expect_identical(v$variant, "sv")
  expect_match(v$message, "'asset_value' braucht Gebäudedaten", fixed = TRUE)
  # Schlüssel der Expander ohne passenden Validierungstext bleiben resolve_failed
  e <- tryCatch(vofi_abort("expand.funding.degression_target", funding = "f", target = "t",
                           .class = "vofi_error_validation"), error = identity)
  expect_identical(val_resolve_finding(e, "base")$code, "validation.resolve_failed")
})

test_that("Doppel- und Folgebefunde an erzeugten Komponenten entfallen (4.12)", {
  spec <- list(components = list(m_a_acq = list(origin = "expander"),
                                 z = list(origin = "scenario")),
               financing = list(f_k_loan = list(origin = "expander")))
  f <- function(sev, code, path) val_finding(sev, code, path, variant = "base")
  codes <- function(out) paste(val_bind(out)$code, val_bind(out)$path)
  # gleicher Code an der Domäne: Doppelbefund; anderer Code ohne Domänenfehler bleibt
  out <- list(f("info", "validation.required", "components.m_a_acq.federal_state"),
              f("info", "validation.required", "project.federal_state"),
              f("warning", "validation.not_map", "financing.f_k_loan.fees"),
              f("warning", "validation.not_list", "components.m_a_acq.after"),
              f("error", "validation.param_required", "components.z.values"))
  expect_identical(codes(val_drop_generated(out[1:2], spec)),
                   "validation.required project.federal_state")
  expect_identical(nrow(val_bind(val_drop_generated(out[3:4], spec))), 2L)
  # Fehler an einem nicht erzeugten Pfad: alle Befunde an erzeugten Komponenten entfallen
  expect_identical(codes(val_drop_generated(out[c(3, 5)], spec)),
                   "validation.param_required components.z.values")
  # Schwere: ein Fehler an einer erzeugten Komponente bleibt neben einem Hinweis der Domäne
  e2 <- list(f("error", "validation.not_map", "components.m_a_acq.fees"),
             f("info", "validation.not_map", "measures.a.fees"))
  expect_identical(nrow(val_bind(val_drop_generated(e2, spec))), 2L)
  # Strukturbefunde der erzeugten ids bleiben; all = TRUE (unvollständige Expansion)
  s1 <- list(val_finding("error", "validation.generated_id_too_long", "components.m_a_acq",
                         value = "m_a_acq", max_user = "29", variant = "base"),
             f("error", "validation.required", "measures.a.cost_eur"),
             f("warning", "validation.not_map", "financing.f_k_loan.fees"))
  expect_identical(sort(val_bind(val_drop_generated(s1, spec))$code),
                   c("validation.generated_id_too_long", "validation.required"))
  expect_identical(val_bind(val_drop_generated(s1[c(1, 3)], spec, all = TRUE))$code,
                   "validation.generated_id_too_long")
  expect_identical(val_drop_generated(out[3:4], list()), out[3:4])
})

test_that("Degressionsziel: Index [i] auf Zahlenreihen und Tabellen (Teil B 4.3.3)", {
  staffel <- list(thresholds_eur = list(kind = "series_t", values = c(40000, 60000, 90000)),
                  rates = list(kind = "series_t", values = c(0.4, 0.3, 0.1, 0)))
  pl <- list(rate_components = list(einkommen = list(schedule_by_taxable_income = staffel)),
             rate_cap = list(value = list(kind = "const", value = 0.8),
                             exceptions = list(list(cap = 0.8, condition = "x"))))
  p <- "rate_components.einkommen.schedule_by_taxable_income.rates"
  expect_true(val_library_subpath_exists(pl, paste0(p, "[3]")))
  expect_true(val_library_subpath_exists(pl, paste0(p, "[4]")))
  expect_false(val_library_subpath_exists(pl, paste0(p, "[5]")))
  expect_false(val_library_subpath_exists(pl, paste0(p, "[0]")))
  expect_true(val_library_subpath_exists(pl, "rate_cap.exceptions[1].cap"))
  expect_false(val_library_subpath_exists(pl, "rate_cap.exceptions[2].cap"))
  expect_false(val_library_subpath_exists(pl, "rate_cap.value[1]"))   # Konstante: keine Sequenz
  expect_true(val_library_subpath_exists(list(a = c(1, 2)), "a[2]"))
})

test_that("vofi_build(): unbekannte Wurzelschlüssel von Szenario und Overrides (4.2)", {
  sc <- example_scenario("skeleton")
  x <- unclass(sc)
  x$acounts <- x$accounts
  x$accounts <- NULL
  bad <- vofi_scenario(x)
  e <- expect_error(vofi_build(bad), class = "vofi_error_validation")
  expect_true("validation.unknown_key" %in% e$data$report$code)
  e2 <- expect_error(vofi_build(sc, overrides = list(acounts = list(deposit_rate_pa = 0.01))),
                     class = "vofi_error_validation")
  expect_identical(e2$data$report$path[e2$data$report$code == "validation.unknown_key"],
                   "overrides.acounts")
  expect_identical(nrow(as.data.frame(val_overrides_structure(list(accounts = list())))), 0L)
})

test_that("Schicht und Fundstelle aus der Herkunft", {
  prov <- data.frame(path = c("a.b", "a.c", "d"), layer = c(5L, 7L, 1L),
                     location = c("Zeile 3", NA, NA), stringsAsFactors = FALSE)
  expect_identical(val_prov_lookup(prov, "a.b"), list(layer = 5L, location = "Zeile 3"))
  expect_identical(val_prov_lookup(prov, "a")$layer, 7L)
  expect_identical(val_prov_lookup(prov, "a")$location, "Zeile 3")
  expect_identical(val_prov_lookup(prov, "d.e.f")$layer, 1L)
  expect_true(is.na(val_prov_lookup(prov, "x")$layer))
  expect_true(is.na(val_prov_lookup(NULL, "x")$layer))
  sc <- wsb_with("skeleton", function(x) {
    x$accounts$deposit_rate <- 0.02
    x$variants <- list(v = list(label = "v", set = list("accounts.overdraft_rate_pa" = 0.5)))
    x
  })
  v <- wsb_validate(sc)
  expect_identical(v$layer[v$code == "validation.range"], 7L)
  expect_identical(v$variant[v$code == "validation.range"], "v")
  expect_identical(v$layer[v$code == "validation.unknown_field"][1], 5L)
  expect_setequal(v$variant[v$code == "validation.unknown_field"], c("base", "v"))
})

test_that("Defaults-Dateien und Bibliothekseinträge: gültige Dateien ohne Befund", {
  g <- list(defaults_meta = list(kind = "global", id = "global", schema_version = 1L,
                                 as_of = "2026-10-25", quality = "B", source = "Spec 01"),
            item_defaults = list(building = list(building_id = "b1")),
            accounts = list(deposit_rate_pa = 0.025))
  expect_identical(nrow(val_defaults_file(g, "global")), 0L)
  p <- g
  p$item_defaults <- NULL
  p$defaults_meta$kind <- "profile"
  p$residual_value <- list(method = "income_value", sale_cost_share = 0.03)
  p$by_project_type <- list(neubau = list(project = list(horizon_years = 40L)))
  expect_identical(nrow(val_defaults_file(p, "profile")), 0L)
  e <- list(id = "funding/kfw_test", block = "funding", schema_version = 1L, label = "T",
            source = list(document = "Merkblatt", publisher = "KfW"), as_of = "2026-10-25",
            valid_from = "2026-07-21", valid_to = NULL, quality = "B",
            quality_detail = list("loan.payments_per_year" = "D"),
            legal_state = list(as_of = "2026-09-02", status = "administrative"),
            values = list(loan = list(payments_per_year = 12L), rates = list(list(a = 1))))
  expect_identical(nrow(val_library_entry(e, id = "funding/kfw_test")), 0L)
  expect_true(val_library_subpath_exists(e$values, "rates[1].a"))
  expect_false(val_library_subpath_exists(e$values, "rates[2].a"))
  expect_identical(val_library_block_of("prices/x"), "market")
})

test_that("M5: quality_detail und fallback gegen die aufgelöste Nutzlast der Kette (4.9)", {
  e <- list(id = "funding/kind", block = "funding", schema_version = 1L, label = "K",
            source = list(document = "D", publisher = "P"), as_of = "2026-10-25",
            valid_from = "2026-01-01", valid_to = NULL, quality = "B",
            legal_state = list(as_of = "2026-01-01", status = "in_force"),
            from = "funding/eltern",
            quality_detail = list(budget_risk = "C", "basis.caps" = "D"),
            values = list(amount_eur = 1))
  # ohne aufgelöste Nutzlast keine falschen Fehler bei from-Ketten
  expect_identical(nrow(val_library_entry(e)), 0L)
  payload <- list(amount_eur = 1, budget_risk = list(p = 0.9), basis = list(caps = 1))
  expect_identical(nrow(val_library_entry(e, payload = payload)), 0L)
  v <- val_library_entry(e, payload = list(amount_eur = 1, basis = list(caps = 1)))
  expect_identical(v$code, "validation.library.quality_detail_path")
  expect_identical(v$path, "quality_detail.budget_risk")
  # Token base in der Nutzlast: fallback deckt jedes Token ab (Teil C 3.1, R-95)
  p <- list(id = "processes/p", block = "processes", schema_version = 1L, label = "P",
            source = list(document = "D", publisher = "P"), as_of = "2026-10-25",
            valid_from = "2026-01-01", valid_to = NULL, quality = "D",
            fallback = list(gas = list(p0 = 0.06)),
            values = list(gas = list(type = "mr_trend", p0 = "base"),
                          oil = list(type = "mr_trend", p0 = "base")))
  v <- val_library_entry(p)
  expect_identical(v$code, "validation.library.fallback_missing")
  expect_identical(v$message, msg("validation.library.fallback_missing", path = "fallback",
                                  value = "oil.p0"))
  p$fallback$oil <- list(p0 = 0.09)
  expect_identical(nrow(val_library_entry(p)), 0L)
})

test_that("m3: uncertainty mit gültigen Verteilungsangaben (Teil C 3.1)", {
  wsb_registry()
  base <- list(id = "costs/u", block = "costs", schema_version = 1L, label = "U",
               source = list(document = "D", publisher = "P"), as_of = "2026-10-25",
               valid_from = "2026-01-01", valid_to = NULL, quality = "C", values = list(a = 1))
  ok <- base
  ok$uncertainty <- list(a = list(dist = "pert", min = 1, mode = 2, max = 3),
                         "market.x" = list(dist = "pert", min = 0.8, mode = 1, max = 1.4,
                                           apply = "multiply"))
  expect_identical(nrow(val_library_entry(ok)), 0L)
  bad <- base
  bad$uncertainty <- list(a = list(dist = "pert", min = 3, mode = 2, max = 1),
                          b = list(dist = "gibts"), c = list(min = 1))
  v <- val_library_entry(bad)
  expect_identical(v$code, rep("validation.library.uncertainty_invalid", 3L))
  expect_identical(v$path, c("uncertainty.a", "uncertainty.b", "uncertainty.c"))
})

test_that("m4: Phase-0-Schnittstellen: variant = character(0) und val_known_extra_fields()", {
  expect_identical(val_known_extra_fields("residual_value"), character(0))
  sc <- wsb_with("skeleton", function(x) {
    x$horizon_from <- "x"
    x$accounts$deposit_rate_pa <- 0.5
    x
  })
  v <- wsb_validate(sc, variant = character(0))
  expect_identical(unique(v$code), "validation.unknown_key")
  expect_true("validation.range" %in% wsb_validate(sc)$code)
  # ein Testhelfer darf bekannte Zusatzfelder ergänzen (helper-ws-a.R)
  ns <- asNamespace("vofi")
  orig <- get("val_known_extra_fields", envir = ns)
  withr::defer(utils::assignInNamespace("val_known_extra_fields", orig, ns = "vofi"))
  utils::assignInNamespace("val_known_extra_fields",
                           function(block) if (identical(block, "tax")) "zusatz" else character(0),
                           ns = "vofi")
  v <- wsb_validate(wsb_with("skeleton", function(x) {
    x$tax <- list(module = "none", zusatz = 1)
    x
  }))
  expect_false("validation.unknown_field" %in% v$code)
})
