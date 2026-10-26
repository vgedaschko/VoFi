# Tests des Expanders measures (WS-E2, Spec 01 Teil A 4.5.5 XM1–XM13).

e2_bld <- function(...) {
  utils::modifyList(list(building_type = "MFH", construction_year = 1975L, n_units = 12L,
                         living_area_m2 = 900), list(...))
}

test_that("XM1/XM2: capex und replacement mit Bezügen, Register, Bezug statt Kopie", {
  x <- e2_scenario(building = e2_bld(),
                   measures = list(wp = list(measure_type = "heizung_waermepumpe_luft",
                                             year = 2027, cost_eur = 126000)),
                   variants = list(v = list(set = list("measures.wp.cost_eur" = 130000))))
  r <- e2_resolve_full(x)
  spec <- r$value
  expect_true(all(c("m_wp_capex", "m_wp_repl", "m_maintenance") %in% names(spec$components)))
  cx <- spec$components$m_wp_capex
  expect_identical(cx$type, "capex")
  expect_identical(cx$cost_eur, node_ref("measures.wp.cost_eur"))
  expect_identical(cx$active, node_ref("measures.wp.active"))
  expect_identical(cx$date, as.Date("2027-01-01"))
  expect_identical(cx$measure_id, "wp")
  expect_identical(cx$asset_id, "b1_building")
  expect_identical(cx$origin, "expander")
  expect_equal(e2_value(spec, "measures.wp.useful_life_years"), 18)
  rp <- spec$components$m_wp_repl
  expect_identical(rp$capex_id, "m_wp_capex")
  expect_true(rp$include_initial)
  expect_identical(rp$useful_life_years, node_ref("measures.wp.useful_life_years"))
  expect_identical(rp$after, "m_wp_capex")
  reg <- Filter(function(m) identical(m$measure_id, "wp"), spec$registers$measures)[[1L]]
  expect_identical(reg$classification, "erhaltung")
  expect_identical(reg$classification_source, "default")
  expect_identical(reg$asset_id, "b1_building")
  expect_identical(reg$funding_choice, "keine")
  expect_identical(reg$completion_date, as.Date("2027-01-01"))
  # XM2: Schicht 8 ändert das Domänenblatt, nicht die Komponente
  sv <- e2_resolve(x, "v")
  expect_identical(sv$components$m_wp_capex, cx)
  expect_equal(e2_value(sv, "measures.wp.cost_eur"), 130000)
  ids <- vapply(spec$registers$assets, function(a) a$asset_id, "")
  expect_setequal(ids, c("b1_building", "b1_land"))
})

test_that("XM3/XM4: eigene Anlage der PV, Erwerb mit land und acquisition_cost", {
  x <- e2_scenario(building = e2_bld(),
                   measures = list(pv = list(measure_type = "pv", year = 2028, cost_eur = 45000)),
                   energy = list(pv = list(kwp = 10, measure = "pv",
                                           self_consumption_share = 0.3)))
  spec <- e2_resolve(x)
  expect_identical(spec$components$m_pv_capex$asset_id, "b1_pv")
  a <- Filter(function(a) identical(a$asset_id, "b1_pv"), spec$registers$assets)
  expect_length(a, 1L)
  expect_identical(a[[1L]]$asset_type, "pv_anlage")
  expect_identical(a[[1L]]$in_service_date, as.Date("2028-01-01"))
  x4 <- e2_scenario(project_type = "erwerb_sanierung", building = e2_bld(),
                    measures = list(kauf = list(measure_type = "erwerb_objekt",
                                                date = "2027-03-01",
                                                purchase_price_eur = 1200000,
                                                land_share = 0.25, grest_rate = 0.065)))
  s4 <- e2_resolve(x4)
  expect_identical(s4$components$m_kauf_purchase$type, "land")
  expect_identical(s4$components$m_kauf_purchase$purchase_price_eur,
                   node_ref("measures.kauf.purchase_price_eur"))
  expect_identical(s4$components$m_kauf_purchase$land_share, node_ref("measures.kauf.land_share"))
  expect_identical(s4$components$m_kauf_purchase$date, as.Date("2027-03-01"))
  expect_identical(s4$components$m_kauf_acq$type, "acquisition_cost")
  expect_identical(s4$components$m_kauf_acq$basis_eur, node_ref("measures.kauf.purchase_price_eur"))
  expect_false("m_kauf_capex" %in% names(s4$components))
  reg <- Filter(function(m) identical(m$measure_id, "kauf"), s4$registers$measures)[[1L]]
  expect_identical(reg$classification, "herstellung")
  bld <- Filter(function(a) identical(a$asset_id, "b1_building"), s4$registers$assets)[[1L]]
  expect_identical(bld$acquisition_date, as.Date("2027-03-01"))
  expect_equal(bld$land_share, 0.25)
  res <- e2_run(s4)
  expect_equal(e2_row(res, "m_kauf_purchase__price_land")[2L], -300000)
  expect_equal(e2_row(res, "m_kauf_purchase__price_building")[2L], -900000)
})

test_that("XM5: Aktivierungsfaktor bei drop_measures, Förderwahl im Register", {
  x <- e2_scenario(building = e2_bld(),
                   measures = list(wp = list(measure_type = "heizung_waermepumpe_luft",
                                             year = 2027, cost_eur = 126000)),
                   funding = list(f1 = list(instrument_type = "grant", measures = list("wp"),
                                            on_reject = "drop_measures",
                                            rate_components = list(grund = list(rate = 0.3)))))
  spec <- e2_resolve(x)
  expect_identical(spec$components$m_wp_capex$active,
                   node_expr("measures.wp.active * funding.f1.approved"))
  expect_identical(spec$components$m_wp_repl$active,
                   node_expr("measures.wp.active * funding.f1.approved"))
  reg <- Filter(function(m) identical(m$measure_id, "wp"), spec$registers$measures)[[1L]]
  expect_identical(reg$funding_choice, "beg_zuschuss")
})

test_that("XM6: Bestandsbauteil endet mit der ersetzenden Maßnahme (until_date, a_m)", {
  kessel <- list(measure_type = "heizung_gaskessel", installed_year = 1998L,
                 replacement_cost_eur = 95000)
  x <- e2_scenario(building = e2_bld(elements = list(kessel = kessel)),
                   measures = list(wp = list(measure_type = "heizung_waermepumpe_luft",
                                             year = 2027, completion_date = "2027-10-01",
                                             cost_eur = 126000,
                                             replaces_elements = list("kessel"))))
  spec <- e2_resolve(x)
  k <- spec$components$m_kessel_repl
  expect_identical(k$type, "replacement")
  expect_false(k$include_initial)
  expect_identical(k$install_date, as.Date("1998-01-01"))
  expect_identical(k$until_date, as.Date("2027-10-01"))
  expect_identical(k$until_shift_months,
                   node_expr("(measures.wp.delay_months) + (1 - measures.wp.active) * 1200"))
  expect_identical(k$cost_eur, node_ref("building.elements.kessel.replacement_cost_eur"))
  expect_identical(k$active, node_ref("building.elements.kessel.active"))
  reg <- Filter(function(m) identical(m$measure_id, "kessel"), spec$registers$measures)
  expect_length(reg, 1L)
  expect_identical(reg[[1L]]$classification, "erhaltung")
  # Lauf: Kessel überfällig -> Ersatz in Periode 1 entfällt, weil die WP ihn 2027-10 ersetzt
  res <- e2_run(spec)
  expect_equal(sum(e2_row(res, "m_kessel_repl__cost")), 0)
})

test_that("XM10: Baunebenkosten mit Nutzungsdauer der Hauptmaßnahme, Ersatz ausgeschaltet", {
  x <- e2_scenario(project_type = "neubau", perspective = "wu_privat", horizon_years = 5L,
                   building = e2_bld(construction_year = 2028L),
                   grid = list(construction_months = 12L),
                   measures = list(
                     neubau = list(measure_type = "neubau", date = "2027-06-01",
                                   completion_date = "2028-01-01", cost_eur = 1000000),
                     nk = list(measure_type = "baunebenkosten", date = "2027-06-01",
                               completion_date = "2028-01-01", cost_eur = 200000)
                   ))
  spec <- e2_resolve(x)
  expect_identical(spec$measures$nk$useful_life_years,
                   node_ref("measures.neubau.useful_life_years"))
  expect_false(spec$components$m_nk_repl$enabled)
  reg <- Filter(function(m) identical(m$measure_id, "neubau"), spec$registers$measures)[[1L]]
  expect_identical(reg$classification, "herstellung")
  expect_identical(reg$classification_source, "rule")
  bld <- Filter(function(a) identical(a$asset_id, "b1_building"), spec$registers$assets)[[1L]]
  expect_identical(bld$in_service_date, as.Date("2028-01-01"))
  expect_identical(bld$construction_start_date, as.Date("2027-06-01"))
})

test_that("XM12: Maßnahmen- und Bauteil-ids höchstens 29 Zeichen; gemeinsame Eindeutigkeit", {
  long <- strrep("a", 30L)
  m <- list(list(measure_type = "fenster", year = 2028, cost_eur = 1))
  names(m) <- long
  e <- expect_error(e2_resolve(e2_scenario(building = e2_bld(), measures = m)),
                    class = "vofi_error_validation")
  expect_identical(e$key, "expand.measures.id_too_long")
  expect_equal(e$args$max, 29L)
  ok <- m
  names(ok) <- strrep("a", 29L)
  spec <- e2_resolve(e2_scenario(building = e2_bld(), measures = ok))
  expect_true(paste0("m_", strrep("a", 29L), "_capex") %in% names(spec$components))
  el_x <- list(measure_type = "fenster", installed_year = 1990L, replacement_cost_eur = 1)
  dup <- e2_scenario(building = e2_bld(elements = list(x = el_x)),
                     measures = list(x = list(measure_type = "fenster", year = 2028,
                                              cost_eur = 1)))
  e <- expect_error(e2_resolve(dup), class = "vofi_error_validation")
  expect_identical(e$key, "expand.measures.id_shared")
})

test_that("Instandhaltung: m_maintenance mit Faktoren, m_<m>_maint, Selbstnutzer, ohne building", {
  x <- e2_scenario(perspective = "selbstnutzer",
                   building = e2_bld(n_units = 1L, living_area_m2 = 140),
                   measures = list(
                     fassade = list(measure_type = "daemmung_fassade", year = 2027,
                                    cost_eur = 50000,
                                    effects = list(maintenance = list(factor = 0.8,
                                                                      duration_years = 10))),
                     wp = list(measure_type = "heizung_waermepumpe_luft", year = 2027,
                               cost_eur = 30000,
                               effects = list(maintenance = list(share_of_cost_pa = 0.015)))
                   ))
  spec <- e2_resolve(x)
  mt <- spec$components$m_maintenance
  expect_identical(mt$type, "maintenance")
  expect_identical(mt$tax_category, "expense_nondeductible")
  expect_identical(mt$factors, list(m_fassade_capex = node_ref(
    "measures.fassade.effects.maintenance.factor"
  )))
  expect_identical(mt$factor_years$m_fassade_capex,
                   node_ref("measures.fassade.effects.maintenance.duration_years"))
  expect_true("m_fassade_capex" %in% mt$after)
  mm <- spec$components$m_wp_maint
  expect_identical(mm$basis, "share_of_cost")
  expect_identical(mm$capex_id, "m_wp_capex")
  expect_identical(mm$share_pa, node_ref("measures.wp.effects.maintenance.share_of_cost_pa"))
  res <- e2_run(spec)
  g <- e2_path(spec, "market.maintenance_index")
  expect_equal(e2_row(res, "m_wp_maint__cost")[2L], -450 * (1 + g[2L]))
  # ohne building: Maßnahmen zulässig, keine Instandhaltung, keine Gebäude-Assets
  nb <- e2_scenario(perspective = "wu_privat", project_type = "neubau",
                    measures = list(m = list(measure_type = "fenster", year = 2028,
                                             cost_eur = 1)))
  sn <- e2_resolve(nb)
  expect_true("m_m_capex" %in% names(sn$components))
  expect_false("m_maintenance" %in% names(sn$components))
  expect_identical(sn$components$m_m_capex$asset_id, "b1_building")
  expect_length(Filter(function(a) identical(a$asset_id, "b1_building"),
                       sn$registers$assets), 0L)
})

test_that("Anlagenregister: ausdrückliche asset_id gemeinsam nutzbar, andere Art ist Fehler", {
  base <- list(
    pv = list(measure_type = "pv", year = 2028, cost_eur = 20000, asset_id = "b1_pv"),
    wr = list(measure_type = "pv_wechselrichter", year = 2028, cost_eur = 3000,
              asset_id = "b1_pv")
  )
  spec <- e2_resolve(e2_scenario(building = e2_bld(), measures = base))
  a <- Filter(function(a) identical(a$asset_id, "b1_pv"), spec$registers$assets)
  expect_length(a, 1L)
  bad <- base
  bad$lade <- list(measure_type = "ladeinfrastruktur", year = 2028, cost_eur = 5000,
                   asset_id = "b1_pv")
  e <- expect_error(e2_resolve(e2_scenario(building = e2_bld(), measures = bad)),
                    class = "vofi_error_validation")
  expect_identical(e$key, "expand.measures.asset_type_conflict")
})

test_that("m_maintenance ohne auflösbare Bezugsfläche: Komponente mit I, Bezugsfehler im Bau", {
  x <- e2_scenario(building = list(building_type = "MFH", n_units = 4L,
                                   construction_year = 1970L))
  r <- e2_resolve_full(x)
  expect_true("expand.measures.maintenance_area_missing" %in% r$messages)
  expect_true(any(grepl("building.living_area_m2", r$texts, fixed = TRUE)))
  mt <- r$value$components$m_maintenance
  expect_identical(mt$type, "maintenance")
  expect_identical(mt$area_m2, node_ref("building.maintenance.area_m2"))
  # Bezugsfehler im Bau: vofi_build() validiert vor dem Aufbau der Knoten (Spec 00 9.1 Stufe 2);
  # der nicht auflösbare Bezug ist ein E der Validierung (validation.ref_target_missing), daher
  # bricht der Bau mit engine.validation_failed ab und nicht erst im Lauf (engine.ref_missing)
  e <- expect_error(e2_capture(vofi_build(r$value)), class = "vofi_error_validation")
  expect_identical(e$key, "engine.validation_failed")
  rep <- e$data$report
  expect_s3_class(rep, "vofi_validation")
  expect_true(any(rep$severity == "error" & rep$code == "validation.ref_target_missing" &
                    rep$path == "building.maintenance.area_m2"))
  # mit Fläche bzw. basis none: keine Meldung
  ok <- e2_resolve_full(e2_scenario(building = list(building_type = "MFH", n_units = 4L,
                                                    construction_year = 1970L,
                                                    living_area_m2 = 300)))
  expect_false("expand.measures.maintenance_area_missing" %in% ok$messages)
  none <- e2_resolve_full(e2_scenario(building = list(building_type = "MFH", n_units = 4L,
                                                      construction_year = 1970L,
                                                      maintenance = list(basis = "none"))))
  expect_false("m_maintenance" %in% names(none$value$components))
  expect_false("expand.measures.maintenance_area_missing" %in% none$messages)
})

test_that("Herkunft der Klassifikation aus dem Bibliotheksindex der Auflösung (Teil A 4.5.3)", {
  spec <- e2_resolve(e2_scenario(building = e2_bld(),
                                 measures = list(wp = list(
                                   measure_type = "heizung_waermepumpe_luft", year = 2027,
                                   cost_eur = 100000, classification = "herstellung"
                                 ))))
  reg <- Filter(function(m) identical(m$measure_id, "wp"), spec$registers$measures)[[1L]]
  expect_identical(reg$classification_source, "user")
  # bctx-Index statt der Standardwurzeln: ein überschattender Katalog wirkt
  fake <- list(entries = list("costs/massnahmentypen_2026" = list(
    values = list(types = list(fenster = list(classification_existing = "herstellung")))
  )))
  bctx <- scn_bctx(list(), NULL, index = fake)
  expect_identical(exp_lib_index(bctx), fake)
  expect_identical(exp_m_catalog_types(bctx)$fenster$classification_existing, "herstellung")
  mm <- list(measure_type = "fenster", classification = "herstellung")
  expect_identical(exp_m_class_source(list(project = list(project_type = "sanierung_eh")), mm,
                                      bctx), "default")
  mm$classification <- "erhaltung"
  expect_identical(exp_m_class_source(list(project = list(project_type = "sanierung_eh")), mm,
                                      bctx), "user")
})
