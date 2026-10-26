# Tests für R/scenario-library.R (WS-A; Spec 00 Abschnitte 4.7 Schichten 3-4, 4.9, 4.10;
# Bibliothek: tests/testthat/fixtures/library).

test_that("vofi_library_paths: Paketbibliothek zuerst, dann Option und add (2.12, 4.9)", {
  local_vofi_options(vofi.library_paths = c("/tmp/a", "/tmp/b"))
  p <- vofi_library_paths(add = c("/tmp/c", "/tmp/a"))
  expect_identical(utils::tail(p, 3L), c("/tmp/a", "/tmp/b", "/tmp/c"))
  expect_error(vofi_library_paths(add = 1), class = "vofi_error_input")
  local_ws_a_library()
  expect_identical(vofi_library_paths()[1], normalizePath(ws_a_lib(), winslash = "/"))
})

test_that("Index: ein Eintrag je Datei, Listenform nur in Nutzerbibliotheken, Befunde je Eintrag", {
  local_ws_a_library()
  lib <- vofi_library(date = "2027-01-01")
  expect_s3_class(lib, "data.frame")
  expect_true(all(c("entry", "block", "topic", "quality", "as_of", "valid_from", "valid_to",
                    "valid", "outdated", "source_type", "file", "shadows",
                    "problems") %in% names(lib)))
  expect_true("funding/kfw_261_eh55" %in% lib$entry)
  expect_identical(lib$source_type[lib$entry == "funding/kfw_261_eh55"], "library")
  expect_identical(lib$file[lib$entry == "funding/kfw_261_eh55"], "funding/kfw_261_eh55.yaml")
  expect_true(all(lib$problems == ""))
  expect_identical(unique(vofi_library("legal", date = "2027-01-01")$block), "legal")
  expect_error(vofi_library("gibtsnicht"), class = "vofi_error_input")
  expect_error(vofi_library(library_paths = 1), class = "vofi_error_input")
  expect_error(vofi_library(date = c("2027-01-01", "2028-01-01")), class = "vofi_error_input")
  # Nutzerbibliothek (Schicht 4): Listenform, Überschattung, fehlerhafte Einträge
  ulib <- vofi_library(library_paths = c(vofi_library_paths(), ws_a_lib("user_lib")),
                       date = "2027-01-01")
  expect_true(all(c("costs/user_a", "costs/user_b") %in% ulib$entry))
  expect_identical(ulib$source_type[ulib$entry == "costs/user_a"], "user_library")
  sh <- ulib[ulib$entry == "prices/interest_rates_2026_10", ]
  expect_identical(sh$source_type, "user_library")
  expect_match(sh$shadows, "fixtures/library", fixed = TRUE)
  expect_match(ulib$problems[ulib$entry == "funding/bad_key"], "title", fixed = TRUE)
  expect_match(ulib$problems[ulib$entry == "funding/anderer_name"], "id_mismatch|entspricht")
  # Gültigkeit und Stand (D10): user_b gilt bis 2026-06-01, funding_risks hat Stand 2025-01-15
  expect_false(ulib$valid[ulib$entry == "costs/user_b"])
  expect_true(ulib$outdated[ulib$entry == "costs/user_b"])
  expect_true(ulib$outdated[ulib$entry == "processes/funding_risks_2026"])
  expect_false(ulib$outdated[ulib$entry == "costs/user_a"])
})

test_that("Listenform in der Paketbibliothek ist ein Befund (R-13)", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "costs"))
  writeLines(c("- id: costs/x", "  block: costs"), file.path(root, "costs", "liste.yaml"))
  writeLines("a: [1", file.path(root, "costs", "kaputt.yaml"))
  testthat::local_mocked_bindings(lib_package_root = function() root)
  lib_state$index <- NULL
  withr::defer(lib_state$index <- NULL)
  lib <- vofi_library(library_paths = root, date = "2027-01-01")
  expect_identical(sort(lib$entry), c("costs/kaputt", "costs/liste"))
  expect_match(lib$problems[lib$entry == "costs/liste"], "Nutzerbibliotheken", fixed = TRUE)
  expect_true(nzchar(lib$problems[lib$entry == "costs/kaputt"]))
  idx <- lib_index(root)
  e <- expect_error(lib_payload(idx, "costs/liste", "x"), class = "vofi_error_validation")
  expect_identical(e$key, "io.library.entry_invalid")
})

test_that("Nutzlast mit Kette (entry$from), Unterpfad und Zyklus (4.9)", {
  local_ws_a_library()
  idx <- lib_index(c(vofi_library_paths(), ws_a_lib("user_lib")))
  pl <- lib_payload(idx, "funding/kfw_261_eh55", "funding.k")
  expect_identical(pl$chain, c("funding/kfw_261_eh55", "funding/kfw_261_wg_kredit_2026"))
  expect_identical(pl$values$repayment_grant$base_rates$ee, 0.15)
  expect_identical(pl$values$repayment_grant$effect, "shorten_term")
  expect_identical(pl$values$instrument_type, "loan_with_repayment_grant")
  expect_identical(unname(pl$origin["repayment_grant.base_rates.ee"]), "funding/kfw_261_eh55")
  expect_identical(unname(pl$origin["instrument_type"]), "funding/kfw_261_wg_kredit_2026")
  ub <- lib_payload(idx, "costs/user_b")
  expect_identical(ub$values$nested, list(x = 1, y = 3))
  expect_null(lib_payload(idx, "costs/gibtsnicht"))
  e <- expect_error(lib_payload(idx, "costs/cycle_a", "x"), class = "vofi_error_validation")
  expect_identical(e$key, "io.library.cycle")
  expect_match(conditionMessage(e), "costs/cycle_a -> costs/cycle_b -> costs/cycle_a",
               fixed = TRUE)
  rec <- lib_get(idx, "funding/kfw_261_wg_kredit_2026")
  expect_identical(lib_quality_of(rec, "repayment_grant.effect"), "C")
  expect_identical(lib_quality_of(rec, "loan.repayment"), "B")
})

test_that("Fundstelle from/use: Nutzlast unter lokal, Ersetzung bei Skalar/Wertform (R-87)", {
  local_ws_a_library()
  prv <- prv_new()
  lc <- lib_context(lib_index(vofi_library_paths()), prv)
  x <- list(market = list(from = "prices/macro_paths_2026", use = "market", inflation = 0.03,
                          mortgage_rate = list(from = "prices/interest_rates_2026_10",
                                               use = "market.mortgage_rate")))
  out <- lib_resolve(x, "", lc)
  expect_identical(out$market$inflation, 0.03)                 # lokal gewinnt
  expect_identical(out$market$mortgage_rate, 0.041)            # Skalar ersetzt den Knoten
  expect_true(!is.null(out$market$rent_growth))
  expect_identical(prv_lookup(prv, "market.mortgage_rate")$entry, "prices/interest_rates_2026_10")
  expect_identical(prv_lookup(prv, "market.mortgage_rate")$quality, "A")
  expect_identical(prv_lookup(prv, "market.rent_growth")$layer, 3L)
  # Skalar bzw. Wertform mit weiteren lokalen Schlüsseln: Fehler
  e <- expect_error(lib_resolve(list(market = list(mortgage_rate = list(
    from = "prices/interest_rates_2026_10", use = "market.mortgage_rate", scale = 2))), "", lc),
    class = "vofi_error_validation")
  expect_identical(e$key, "io.library.local_keys")
  e <- expect_error(lib_resolve(list(market = list(x = list(from = "prices/macro_paths_2026",
                                                            use = "gibtsnicht"))), "", lc),
                    class = "vofi_error_validation")
  expect_identical(e$key, "io.library.use_missing")
  e <- expect_error(lib_resolve(list(funding = list(k = list(from = "funding/gibtsnicht"))), "",
                                lc), class = "vofi_error_validation")
  expect_identical(e$key, "io.library.entry_unknown")
  e <- expect_error(lib_resolve(list(c = list(r = list(type = "recurring", from = "completion"))),
                                "", lc), class = "vofi_error_validation")
  expect_identical(e$key, "validation.library.ref_not_id")
  # Löschanweisungen bleiben erhalten, entfallene Verweise (Modus drop) nicht
  keep <- lib_resolve(list(a = list(b = NULL, c = 1)), "", lc)
  expect_true("b" %in% names(keep$a))
  lc$mode <- "drop"
  dropped <- lib_resolve(list(a = list(x = list(from = "prices/gibtsnicht"), y = 1)), "", lc)
  expect_identical(names(dropped$a), "y")
  expect_identical(lc$missing, "prices/gibtsnicht")
  # Verwendete Einträge werden für spec$library und die Gültigkeitsprüfung gemerkt
  expect_true(any(vapply(lc$used, function(u) u$id == "prices/macro_paths_2026", logical(1))))
})

test_that("Overlay-Einträge: Vorlage unter lokal, use Pflicht bei Vorlagen-Map (R-119)", {
  local_ws_a_library()
  lc <- lib_context(lib_index(vofi_library_paths()), prv_new())
  st <- list(stochastic = list(
    parameters = list(kost = list(target = "project.construction_cost_factor",
                                  from = "processes/cost_risks_2026", use = "overrun_retrofit",
                                  max = 1.6)),
    correlations = list(shocks = list(from = "processes/shock_correlations_2026"))
  ))
  out <- lib_resolve(st, "", lc)
  k <- out$stochastic$parameters$kost
  expect_identical(k$dist, "pert")
  expect_identical(k$max, 1.6)
  expect_identical(k$min, 0.95)
  expect_identical(k$target, "project.construction_cost_factor")
  expect_identical(k$apply, "multiply")
  expect_length(out$stochastic$correlations$shocks, 3L)
  e <- expect_error(lib_resolve(list(stochastic = list(parameters = list(
    kost = list(target = "x.y", from = "processes/cost_risks_2026")))), "", lc),
    class = "vofi_error_validation")
  expect_identical(e$key, "io.library.use_missing")
})

test_that("Überschattung durch eine Nutzerbibliothek: eine Warnung je Auflösung (4.7)", {
  local_ws_a_library()
  lc <- lib_context(lib_index(c(vofi_library_paths(), ws_a_lib("user_lib"))), prv_new())
  x <- list(market = list(mortgage_rate = list(from = "prices/interest_rates_2026_10",
                                               use = "market.mortgage_rate"),
                          bund = list(from = "prices/interest_rates_2026_10",
                                      use = "market.bund_yield_10y")))
  w <- testthat::capture_warnings(out <- lib_resolve(x, "", lc))
  expect_length(w, 1L)
  expect_match(w, "interest_rates_2026_10", fixed = TRUE)
  expect_identical(out$market$mortgage_rate, 0.05)
})

test_that("Rechtsstand: Wahl je Thema mit Freigaberegel und Reformvorrang (4.10, R-80)", {
  local_ws_a_library()
  idx <- lib_index(vofi_library_paths())
  d <- as.Date("2027-01-01")
  sel <- lib_select_legal(idx, d)
  expect_true(all(c("mietrecht", "umsatzsteuer", "emission_factors_co2cost",
                    "emission_factors_geg", "bio_treppe") %in% names(sel)))
  expect_identical(sel$mietrecht$entry, "legal/mietrecht_2026")
  expect_identical(sel$bio_treppe$entry, "legal/gmodg_bio_treppe_2026")
  expect_false("mietrecht_559f" %in% names(sel))               # C ohne Freigabe: inaktiv
  expect_false("grunderwerbsteuer" %in% names(sel))
  ref <- lib_select_legal(idx, d, c("mietrecht_ii", "stufe_2045"))
  expect_identical(ref$mietrecht$entry, "legal/mietrecht_ii_reform")
  expect_identical(ref$bio_treppe$entry, "legal/gmodg_bio_treppe_2045")
  expect_identical(ref$bio_treppe$chain,
                   c("legal/gmodg_bio_treppe_2045", "legal/gmodg_bio_treppe_2026"))
  unrel <- lib_select_legal(idx, d, "unreleased")
  expect_identical(unrel$mietrecht_559f$entry, "legal/mietrecht_559f_2026")
  expect_true(unrel$mietrecht_559f$unreleased)
  expect_false(unrel$mietrecht$unreleased)
  early <- lib_select_legal(idx, as.Date("2026-01-01"))
  expect_false("mietrecht" %in% names(early))                  # vor valid_from: inaktiv
  expect_identical(lib_select_legal(idx, NULL), list())
  rec <- lib_get(idx, "legal/mietrecht_559f_2026")
  rec$release_status <- "released"
  expect_true(lib_legal_selectable(rec, d, character(0)))
  rec$quality <- "D"
  expect_false(lib_legal_selectable(rec, d, character(0)))
})

test_that("Bibliotheksstand aus VERSION (R-80) und Gültigkeitsprüfung", {
  local_ws_a_library()
  expect_identical(lib_version(), "2026.10.1")
  expect_identical(lib_version(ws_a_lib("user_lib")), "2026.10.1")
  testthat::local_mocked_bindings(lib_package_root = function() "")
  expect_identical(lib_version(), NA_character_)
  rec <- list(valid_from = as.Date("2026-01-01"), valid_to = as.Date("2027-01-01"),
              as_of = as.Date("2026-05-01"), block = "costs")
  expect_true(lib_valid_at(rec, as.Date("2026-12-31")))
  expect_false(lib_valid_at(rec, as.Date("2027-01-01")))
  expect_true(lib_stale_at(rec, as.Date("2027-01-01")))
  rec$block <- "processes"
  expect_false(lib_stale_at(rec, as.Date("2027-01-01")))
  expect_true(lib_valid_at(rec, NA))
})
