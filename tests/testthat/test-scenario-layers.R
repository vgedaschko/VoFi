# Tests für R/scenario-layers.R (WS-A; Spec 00 Abschnitte 4.7-4.12, 6.4; Spec 01 Teil A 1.3,
# 1.4, 2.9, 3.4, 4.5.1, Teil B 5.5, 7.1; Bibliothek: tests/testthat/fixtures/library).

test_that("Schichtreihenfolge und Herkunft: global, Profil, Szenario, Regeln (4.7, 4.8)", {
  local_ws_a_library()
  spec <- ws_a_resolve(vofi_read_scenario(vofi_example("skeleton")))
  expect_s3_class(spec, "vofi_spec")
  expect_identical(spec$accounts$deposit_rate_pa, node_const(0.02))         # Szenario (5)
  expect_identical(spec$accounts$penalty_spread_pa, node_const(0.02))       # Profil (2)
  p <- ws_a_prov(spec, "accounts.penalty_spread_pa")
  expect_identical(p$source_type, "profile")
  expect_identical(p$entry, "wu_privat")
  expect_identical(p$file, "profiles/wu_privat.yaml")
  expect_match(p$location, "^Zeile [0-9]+$")
  s <- ws_a_prov(spec, "accounts.deposit_rate_pa")
  expect_identical(c(s$layer, s$source_type, s$file), c("5", "scenario", "skeleton.yaml"))
  expect_match(s$location, "^Zeile")
  expect_identical(spec$project$tax_regime, "wu_kapges")
  expect_identical(ws_a_prov(spec, "project.tax_regime")$entry, "rule:tax_regime")
  expect_identical(ws_a_prov(spec, "project.legal_state")$entry, "rule:dates")
  expect_identical(spec$project$price_base_year, 2026L)
  expect_identical(spec$project$report_mode, "expert")
  expect_identical(spec$meta$project_id, "skeleton")
  g <- ws_a_prov(spec, "project.comparison_mode")
  expect_identical(c(g$layer, g$source_type, g$entry), c("1", "global", "global"))
  expect_identical(ws_a_prov(spec, "market.mortgage_rate")$entry, "prices/interest_rates_2026_10")
  expect_identical(ws_a_prov(spec, "market.mortgage_rate")$layer, 3L)
  expect_identical(ws_a_prov(spec, "market.mortgage_rate")$quality, "A")
  dm <- attr(spec, "defaults_meta")
  expect_identical(dm$global$id, "global")
  expect_identical(dm$profile$id, "wu_privat")
  expect_identical(dm$profile$kind, "profile")
  expect_s3_class(dm$global$as_of, "Date")
  expect_identical(attr(spec, "library_version"), "2026.10.1")
  expect_identical(attr(spec, "kpis_default")[1:3],
                   c("terminal_value", "terminal_value_opp", "delta_terminal_value"))
  expect_identical(spec$analysis$kpis,
                   c("terminal_value", "terminal_value_opp", "delta_terminal_value"))
  expect_true(all(c("entry", "as_of", "valid_from", "valid_to", "quality") %in%
                    names(spec$library)))
  expect_true("prices/interest_rates_2026_10" %in% spec$library$entry)
  expect_true("mietrecht" %in% names(spec$legal))
  expect_identical(spec$legal$mietrecht$entry, "legal/mietrecht_2026")
  prov <- attr(spec, "provenance")
  expect_false(anyDuplicated(prov$path) > 0L)
  expect_true(all(prov$variant == "base"))
})

test_that("PR8: Gerüst ohne building: kein Block building, Herkunft der Projekt-Defaults", {
  local_ws_a_library()
  spec <- ws_a_resolve(vofi_read_scenario(vofi_example("skeleton")))
  expect_length(spec$building, 0L)
  expect_false("m_maintenance" %in% names(spec$components))
  prov <- attr(spec, "provenance")
  pj <- prov[startsWith(prov$path, "project.") & prov$source_type != "scenario", ]
  expect_true(all(pj$source_type %in% c("global", "type_default", "profile")))
  expect_true(all(pj$entry[pj$source_type == "type_default"] %in%
                    c("rule:tax_regime", "rule:report_mode", "rule:dates",
                      "rule:price_base_year")))
  mute <- function(w) invokeRestart("muffleWarning")
  v <- withCallingHandlers(vofi_validate(vofi_read_scenario(vofi_example("skeleton"))),
                           vofi_warning_library_outdated = mute)
  expect_identical(nrow(v), 0L)
})

test_that("GA1-GA3: Horizont aus by_project_type, Rasterende fest über Varianten (Teil A 1.3)", {
  local_ws_a_library()
  ga1 <- ws_a_resolve(ws_a_scenario(project_type = "neubau",
                                    grid = list(construction_months = 24L)))
  expect_identical(ga1$project$horizon_years, 40L)
  p <- ws_a_prov(ga1, "project.horizon_years")
  expect_identical(c(p$source_type, p$entry), c("global", "global#by_project_type.neubau"))
  g1 <- scn_grid(ga1)
  expect_identical(g1$T, 40L)
  expect_identical(g1$end_date, as.Date("2067-01-01"))
  ga2 <- ws_a_resolve(ws_a_scenario(project_type = "sanierung_eh"))
  expect_identical(ga2$project$horizon_years, 30L)
  expect_identical(scn_grid(ga2)$end_date, as.Date("2057-01-01"))
  sc <- ws_a_scenario(project_type = "neubau", horizon_years = 40L,
                      grid = list(construction_months = 24L),
                      variants = list(v2 = list(label = "kurze Bauzeit",
                                                set = list("grid.construction_months" = 12L))))
  b <- ws_a_resolve(sc)
  v2 <- ws_a_resolve(sc, variant = "v2")
  expect_identical(v2$grid$construction_months, 12L)
  expect_identical(scn_grid(b)$end_date, as.Date("2067-01-01"))
  expect_identical(scn_grid(v2)$end_date, as.Date("2067-01-01"))
  expect_identical(scn_grid(b)$T, 40L)
  expect_identical(scn_grid(v2)$T, 40L)
  expect_identical(ws_a_prov(v2, "grid.construction_months")$source_type, "variant")
  expect_identical(ws_a_prov(v2, "grid.construction_months")$variant, "v2")
})

test_that("PR1, PR2: Profilwerte je Perspektive und Projektart (Teil A 2.9)", {
  local_ws_a_library()
  pr1 <- ws_a_resolve(ws_a_scenario(perspective = "selbstnutzer", project_type = "neubau"))
  expect_identical(pr1$residual_value$method, "asset_value")
  p <- ws_a_prov(pr1, "residual_value.method")
  expect_identical(c(p$source_type, p$entry), c("profile", "selbstnutzer#by_project_type.neubau"))
  expect_identical(pr1$project$horizon_years, 40L)
  expect_identical(ws_a_prov(pr1, "project.horizon_years")$entry, "global#by_project_type.neubau")
  pr2 <- ws_a_resolve(ws_a_scenario(perspective = "wu_kommunal", project_type = "heizungstausch"))
  expect_identical(pr2$residual_value$method, "component")
  expect_identical(pr2$accounts$deficit_order[4], "penalty_rate")
  expect_identical(pr2$accounts$overdraft_limit_eur, node_const(Inf))
  expect_identical(pr2$analysis$tenant_view, TRUE)
})

test_that("PR5: Habenzins mit anchor folgt dem Zinspfad mit Untergrenze 0 (Teil A 2.8)", {
  local_ws_a_library()
  base <- ws_a_scenario(perspective = "wu_genossenschaft", horizon_years = 6L)
  s1 <- ws_a_resolve(base, overrides = list("market.mortgage_rate" = 0.041))
  expect_equal(as.vector(ws_a_value(s1, "accounts.deposit_rate_pa", "path")), rep(0.02, 7L))
  s2 <- ws_a_resolve(base, overrides = list("market.mortgage_rate" = list(
    series = list("2027" = 0.041, "2030" = 0.051), fill = "locf")))
  g <- scn_grid(s2)
  v2 <- as.vector(ws_a_value(s2, "accounts.deposit_rate_pa", "path"))
  expect_equal(v2[g$year <= 2029], rep(0.02, sum(g$year <= 2029)))
  expect_equal(v2[g$year >= 2030], rep(0.03, sum(g$year >= 2030)))
  s3 <- ws_a_resolve(base, overrides = list("market.mortgage_rate" = list(
    series = list("2027" = 0.041, "2030" = 0.010), fill = "locf")))
  v3 <- as.vector(ws_a_value(s3, "accounts.deposit_rate_pa", "path"))
  expect_equal(v3[g$year >= 2030], rep(0, sum(g$year >= 2030)))
  expect_identical(ws_a_prov(s3, "market.mortgage_rate")$source_type, "override")
  expect_identical(ws_a_prov(s3, "market.mortgage_rate")$layer, 8L)
})

test_that("PR9: Gebäude ohne Instandhaltung: Vorlage, Regel, Bibliothekssatz (Teil A 2.9, 3.3)", {
  local_ws_a_library()
  sc <- ws_a_scenario(building = list(living_area_m2 = 1000, construction_year = 1972L))
  spec <- ws_a_resolve(sc)
  expect_identical(spec$building$building_id, "b1")
  expect_identical(ws_a_prov(spec, "building.building_id")$entry, "global#item_defaults.building")
  expect_identical(spec$building$maintenance$basis, "rate")
  expect_identical(ws_a_prov(spec, "building.maintenance.basis")$entry, "rule:maintenance_from")
  expect_identical(spec$building$maintenance$rate_eur_m2_pa, node_const(14.4))
  r <- ws_a_prov(spec, "building.maintenance.rate_eur_m2_pa")
  expect_identical(c(r$entry, r$layer), c("costs/bewirtschaftung_immowertv_2026", "1"))
  expect_identical(spec$building$maintenance$start_event, as.Date("2027-01-01"))
  expect_identical(spec$building$maintenance$enabled, TRUE)
  expect_identical(spec$building$first_occupancy_year, 1972L)
  # Neubau: Basis iibv und Beginn mit Fertigstellung (F-22); ausdrücklicher Satz -> rate
  nb <- ws_a_resolve(ws_a_scenario(project_type = "neubau", building = list(living_area_m2 = 800),
                                   grid = list(construction_months = 18L)))
  expect_identical(nb$building$maintenance$basis, "iibv")
  expect_identical(nb$building$maintenance$start_event, "completion")
  expect_identical(nb$building$first_occupancy_year, 2028L)
  expect_identical(nb$building$maintenance$iibv$rates_eur_m2_pa$lt22y, node_const(11.5))
  ex <- ws_a_resolve(ws_a_scenario(project_type = "neubau",
                                   building = list(maintenance = list(rate_eur_m2_pa = 10))))
  expect_identical(ex$building$maintenance$basis, "rate")
  expect_identical(ex$building$maintenance$rate_eur_m2_pa, node_const(10))
})

test_that("PR10: Maßnahme ohne weitere Felder: Vorlage measures mit {id}, Overlay-Ziel existiert", {
  local_ws_a_library()
  sc <- ws_a_scenario(
    building = list(living_area_m2 = 1000, construction_year = 1972L),
    measures = list(wp = list(measure_type = "heizung_waermepumpe_luft", year = 2028,
                              cost_eur = 30000)),
    stochastic = list(parameters = list(d = list(target = "measures.wp.delay_months",
                                                 label = "Verzug WP", dist = "discrete",
                                                 values = c(0, 12), probs = c(0.5, 0.5))))
  )
  spec <- ws_a_resolve(sc)
  wp <- spec$measures$wp
  expect_identical(wp$cost_factor, node_ref("project.construction_cost_factor"))
  expect_identical(wp$delay_months, node_const(0))
  expect_identical(wp$replacement$price_index, node_ref("measures.wp.price_index"))
  expect_identical(ws_a_prov(spec, "measures.wp.replacement.price_index")$entry,
                   "global#item_defaults.measures")
  expect_true(path_exists(spec, spec$stochastic$parameters$d$target))
  expect_identical(spec$stochastic$parameters$d$target, "measures.wp.delay_months")
  # XM1: Nutzungsdauer über useful_life_key aus costs/nutzungsdauern_2026 (N-30)
  expect_identical(wp$useful_life_years, node_const(18))
  u <- ws_a_prov(spec, "measures.wp.useful_life_years")
  expect_identical(c(u$source_type, u$entry, u$quality),
                   c("type_default", "costs/nutzungsdauern_2026", "C"))
  expect_identical(wp$kg, 400L)
  expect_identical(wp$classification, "erhaltung")
  expect_identical(wp$modernization_kind, "bgb_555b_1a")
  expect_identical(ws_a_prov(spec, "measures.wp.modernization_kind")$entry,
                   "costs/massnahmentypen_2026")
  expect_identical(wp$completion_date, as.Date("2028-01-01"))
  expect_identical(wp$follows_construction, FALSE)
  expect_identical(wp$construction_delay_mode, "none")
  expect_identical(wp$replacement$enabled, TRUE)
  expect_identical(wp$effects$residual$modernization_points, list(heating = 2L))
  expect_identical(wp$price_base_year, 2026L)
  expect_identical(wp$kg700_share, node_const(0))
  expect_identical(ws_a_prov(spec, "measures.wp.kg700_share")$entry, "rule:measure_catalog")
})

test_that("XM7, XM10, XM11: Zuschläge, Nutzungsdauer der Hauptmaßnahme, abgeleitetes cost_eur", {
  local_ws_a_library()
  sc <- ws_a_scenario(
    project_type = "neubau", building = list(living_area_m2 = 900),
    shared = list(rate2 = 50000),
    measures = list(
      neubau = list(measure_type = "neubau", cost_kg = list(kg300 = 1000000), year = 2027,
                    follows_construction = TRUE),
      nk = list(measure_type = "baunebenkosten", cost_eur = 200000, year = 2027),
      plan = list(measure_type = "aussenanlagen", payment_schedule = list(
        schedule = list("2027-07-01" = 100000, "2028-07-01" = list(ref = "shared.rate2")),
        unit = "eur"))
    )
  )
  expect_message(spec <- withCallingHandlers(
    vofi_resolve(vofi_scenario(sc)),
    vofi_warning_library_outdated = function(w) invokeRestart("muffleWarning")),
    "kg700_share", fixed = TRUE)
  nb <- spec$measures$neubau
  expect_identical(nb$kg700_share, node_const(0.2))
  expect_identical(ws_a_prov(spec, "measures.neubau.kg700_share")$entry,
                   "costs/kostenzuschlaege_2026")
  expect_identical(nb$contingency_share, node_const(0.1))
  expect_identical(nb$cost_eur$kind, "expr")
  expect_identical(ws_a_prov(spec, "measures.neubau.cost_eur")$entry, "rule:cost_from_kg")
  expect_equal(ws_a_value(spec, "measures.neubau.cost_eur"), 1320000)
  expect_identical(nb$useful_life_years, node_const(80))
  expect_identical(nb$classification, "herstellung")
  expect_identical(spec$measures$nk$useful_life_years,
                   node_ref("measures.neubau.useful_life_years"))
  expect_identical(spec$measures$nk$replacement$enabled, FALSE)
  expect_equal(ws_a_value(spec, "measures.nk.useful_life_years"), 80)
  pl <- spec$measures$plan
  expect_identical(pl$cost_eur, node_expr("100000 + shared.rate2"))
  expect_equal(ws_a_value(spec, "measures.plan.cost_eur"), 150000)
  expect_identical(pl$completion_date, as.Date("2028-07-01"))
  expect_identical(pl$paid_in_full_date, as.Date("2028-07-01"))
  # ohne Hauptmaßnahme: Bezug auf die GND
  solo <- ws_a_resolve(ws_a_scenario(measures = list(nk = list(measure_type = "rueckbau",
                                                               cost_eur = 1, year = 2027))))
  expect_identical(solo$measures$nk$useful_life_years,
                   node_ref("residual_value.income_value.gnd_years"))
  # Mengenbezug im Zahlungsplan ohne Bezugsgröße: Fehler
  bad <- ws_a_scenario(measures = list(p = list(measure_type = "sonstige", payment_schedule = list(
    schedule = list("2027" = list(value = 10, per = "kw")), unit = "eur"))))
  e <- expect_error(ws_a_resolve(bad), class = "vofi_error_validation")
  expect_identical(e$key, "io.quantity_reference_missing")
  qok <- ws_a_scenario(building = list(living_area_m2 = 500),
                       measures = list(p = list(measure_type = "sonstige", payment_schedule = list(
                         schedule = list("2027" = list(value = 10, per = "m2_living_area")),
                         unit = "eur"))))
  q <- ws_a_resolve(qok)
  expect_identical(q$measures$p$cost_eur, node_expr("(10 * building.living_area_m2)"))
  expect_equal(ws_a_value(q, "measures.p.cost_eur"), 5000)
})

test_that("XM9: keine Modernisierung bei Erhaltung bzw. Ohnehin-Anteil 1 (X-09, R-113)", {
  local_ws_a_library()
  sc <- vofi_scenario(ws_a_scenario(measures = list(
    ersatz_wp_2049 = list(measure_type = "heizung_waermepumpe_luft", year = 2049,
                          cost_eur = 160000, classification = "erhaltung"),
    fenster_alt = list(measure_type = "fenster", year = 2028, cost_eur = 50000,
                       ohnehin_share = 1),
    fenster_neu = list(measure_type = "fenster", year = 2028, cost_eur = 50000,
                       ohnehin_share = 1, modernization_kind = "bgb_555b_1"),
    fenster_teil = list(measure_type = "fenster", year = 2028, cost_eur = 50000)
  )))
  acc <- new.env()
  acc$msgs <- character(0)
  w <- testthat::capture_warnings(withCallingHandlers(
    spec <- vofi_resolve(sc),
    message = function(m) {
      acc$msgs <- c(acc$msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }))
  msgs <- acc$msgs
  ms <- spec$measures
  expect_identical(ms$ersatz_wp_2049$modernization_kind, "none")
  expect_identical(ms$fenster_alt$modernization_kind, "none")
  expect_identical(ws_a_prov(spec, "measures.fenster_alt.modernization_kind")$entry,
                   "rule:measure_catalog")
  expect_identical(ms$fenster_neu$modernization_kind, "bgb_555b_1")
  expect_identical(ms$fenster_teil$modernization_kind, "bgb_555b_1")
  expect_identical(ms$fenster_teil$ohnehin_share, node_const(0.85))
  expect_true(any(grepl("ersatz_wp_2049, fenster_alt", msgs, fixed = TRUE)))
  expect_true(any(grepl("fenster_neu", w, fixed = TRUE)))
  # Ohnehin-Kosten >= Grundkosten im Basisfall
  oc <- ws_a_resolve(ws_a_scenario(measures = list(f = list(
    measure_type = "fenster", year = 2028, cost_eur = 50000, ohnehin_cost_eur = 50000))))
  expect_identical(oc$measures$f$modernization_kind, "none")
})

test_that("XM3: PV-Umsatzsteuer als Ausdruck aus dem Thema umsatzsteuer (X-25, 7.10)", {
  local_ws_a_library()
  mk <- function(pv, vat = NULL) {
    m <- list(measure_type = "pv", year = 2028, cost_eur = 45000)
    if (!is.null(vat)) m$vat_rate <- vat
    ws_a_scenario(measures = list(pv = m), energy = if (!is.null(pv)) list(pv = pv))
  }
  s10 <- ws_a_resolve(mk(list(kwp = 10, measure = "pv")))
  txt <- "ifelse(energy.pv.kwp <= 30 | energy.pv.vat_zero_rate_attested, 0, 0.19)"
  expect_identical(s10$measures$pv$vat_rate, node_expr(txt))
  expect_identical(ws_a_prov(s10, "measures.pv.vat_rate")$entry, "legal/umsatzsteuer_2026")
  expect_equal(ws_a_value(s10, "measures.pv.vat_rate"), 0)
  expect_identical(s10$measures$pv$kwp, node_ref("energy.pv.kwp"))
  expect_identical(s10$energy$pv$vat_zero_rate_attested, FALSE)
  s40 <- ws_a_resolve(mk(list(kwp = 40, measure = "pv")))
  expect_equal(ws_a_value(s40, "measures.pv.vat_rate"), 0.19)
  s40a <- ws_a_resolve(mk(list(kwp = 40, measure = "pv", vat_zero_rate_attested = TRUE)))
  expect_equal(ws_a_value(s40a, "measures.pv.vat_rate"), 0)
  expect_warning(withCallingHandlers(
    vofi_resolve(vofi_scenario(mk(list(kwp = 40, measure = "pv"), vat = 0))),
    message = function(m) invokeRestart("muffleMessage"),
    vofi_warning_library_outdated = function(w) invokeRestart("muffleWarning")),
    "widerspricht", class = "vofi_warning_plausibility")
  m <- testthat::capture_messages(withCallingHandlers(
    s0 <- vofi_resolve(vofi_scenario(mk(NULL))),
    vofi_warning_library_outdated = function(w) invokeRestart("muffleWarning")))
  expect_true(any(grepl("PV-Umsatzsteuer", m, fixed = TRUE)))
  expect_identical(s0$measures$pv$vat_rate, node_const(0))
})

test_that("UG1: Gebäudesummen über Wohnungsgruppen als Ausdruck (Teil A 3.4)", {
  local_ws_a_library()
  sc <- ws_a_scenario(building = list(construction_year = 1980L), unit_groups = list(
    a = list(n_units = 12, living_area_m2 = 600), b = list(n_units = 18, living_area_m2 = 1170),
    c = list(n_units = 6, living_area_m2 = 630)))
  spec <- ws_a_resolve(sc)
  expect_identical(spec$building$n_units$kind, "expr")
  expect_identical(ws_a_prov(spec, "building.n_units")$entry, "rule:building_aggregates")
  expect_equal(ws_a_value(spec, "building.n_units"), 36)
  expect_equal(ws_a_value(spec, "building.living_area_m2"), 2400)
  s8 <- ws_a_resolve(sc, overrides = list("unit_groups.a.living_area_m2" = 660))
  expect_equal(ws_a_value(s8, "building.living_area_m2"), 2460)
  bv <- ws_a_resolve(ws_a_scenario(building = list(land_area_m2 = 500, land_value_eur_m2 = 300,
                                                   existing_value_eur = 900000)))
  expect_equal(ws_a_value(bv, "building.land_value_eur"), 150000)
  expect_identical(bv$building$market_value_eur, node_ref("building.existing_value_eur"))
})

test_that("d1-d4: Ableitungsregeln von Teil B und Vorlagen (Teil B 5.5, 7.1)", {
  local_ws_a_library()
  d1 <- ws_a_resolve(ws_a_scenario(perspective = "selbstnutzer",
                                   building = list(n_units = 1L, living_area_m2 = 140)))
  g <- d1$unit_groups$main
  expect_identical(g$owner_occupied, TRUE)
  expect_identical(g$rent_regime, "owner_occupied")
  expect_identical(g$vacancy_rate, node_const(0))
  expect_identical(g$operating$admin_per_unit_eur_pa, node_const(0))
  expect_identical(g$n_units, node_ref("building.n_units"))
  expect_identical(ws_a_prov(d1, "unit_groups.main.vacancy_rate")$entry,
                   "rule:unit_group_defaults")
  expect_identical(g$operating$recoverable_opex_eur_m2_month, node_const(1.7))
  expect_identical(ws_a_prov(d1, "unit_groups.main.operating.recoverable_opex_eur_m2_month")$entry,
                   "global#item_defaults.unit_groups")
  d2 <- ws_a_resolve(ws_a_scenario(perspective = "wu_genossenschaft",
                                   unit_groups = list(g = list(n_units = 10))))
  expect_identical(d2$unit_groups$g$rent_regime, "cooperative_fee")
  expect_identical(d2$unit_groups$g$owner_occupied, FALSE)
  expect_identical(d2$unit_groups$g$vacancy_rate, node_const(0.025))
  d2k <- ws_a_resolve(ws_a_scenario(perspective = "wu_kommunal",
                                    unit_groups = list(g = list(n_units = 10))))
  expect_identical(d2k$unit_groups$g$rent_regime, "paragraph_558")
  expect_identical(ws_a_prov(d2k, "unit_groups.g.rent_regime")$entry,
                   "global#item_defaults.unit_groups")
  expect_identical(d2k$unit_groups$g$operating$admin_per_unit_eur_pa, node_const(367))
  bs <- ws_a_resolve(ws_a_scenario(project_type = "neubau", unit_groups = list(
    s = list(n_units = 10, rent_regime = "bound_social"))))
  expect_identical(bs$unit_groups$s$operating$admin_per_unit_eur_pa, node_const(372.46))
  expect_identical(ws_a_prov(bs, "unit_groups.s.operating.admin_per_unit_eur_pa")$entry,
                   "costs/bewirtschaftung_ii_bv_2026")
  expect_identical(bs$unit_groups$s$lease_up_months, node_const(3))
  d3 <- ws_a_resolve(ws_a_scenario(energy = list(carriers = list(gas = list()))))
  expect_identical(d3$energy$performance_gap$prebound_factor, node_const(0.7))
  expect_length(ws_a_resolve(ws_a_scenario())$energy, 0L)
  d4 <- ws_a_resolve(ws_a_scenario(
    measures = list(m1 = list(measure_type = "fenster", year = 2028, cost_eur = 1000)),
    funding = list(f35 = list(from = "funding/estg_35c", measures = list("m1")))))
  f <- d4$funding$f35
  expect_identical(f$instrument_type, "tax_credit")
  expect_identical(f$payout_delay_months, node_const(12))
  expect_identical(ws_a_prov(d4, "funding.f35.payout_delay_months")$entry,
                   "rule:tax_credit_defaults")
  expect_identical(f$availability_after_2030, node_const(0.7))
  expect_identical(f$approval_timing, "before_start")
  expect_identical(ws_a_prov(d4, "funding.f35.instrument_type")$entry, "funding/estg_35c")
  expect_identical(f$approved, node_const(1))
})

test_that("rule:carrier_defaults: Klasse, Netzentgelt, Emissionsfaktoren (Teil B 3.2.1)", {
  local_ws_a_library()
  spec <- ws_a_resolve(ws_a_scenario(energy = list(carriers = list(
    gas = list(), pellets = list(), heatpump_power = list(), eigen = list(class = "other",
                                                                         price_eur_kwh = 0.1)))))
  cs <- spec$energy$carriers
  expect_identical(cs$gas$class, "gas")
  expect_identical(cs$pellets$class, "biomass")
  expect_identical(cs$heatpump_power$class, "power_hp")
  expect_identical(cs$gas$network_fee_eur_kwh, node_ref("market.energy_network_fee.gas"))
  expect_identical(cs$pellets$network_fee_eur_kwh, node_const(0))
  expect_identical(cs$gas$emission_factor_kg_kwh, node_const(0.1814))
  e <- ws_a_prov(spec, "energy.carriers.gas.emission_factor_kg_kwh")
  expect_identical(c(e$entry, e$quality), c("legal/emission_factors_co2cost_2026", "A"))
  expect_equal(cs$gas$ghg_factor_kg_kwh$value, 0.21672)
  expect_equal(cs$heatpump_power$ghg_factor_kg_kwh$value, 0.56)
  expect_equal(cs$pellets$ghg_factor_kg_kwh$value, 0.02)
  expect_identical(cs$eigen$ghg_factor_kg_kwh, node_const(0))
  expect_identical(cs$gas$price_eur_kwh, node_ref("market.energy_price.gas"))
  expect_identical(cs$eigen$price_eur_kwh, node_const(0.1))
  expect_identical(ws_a_prov(spec, "energy.carriers.gas.price_eur_kwh")$entry,
                   "global#item_defaults.energy.carriers")
  expect_identical(cs$gas$vat_rate, node_const(0.19))
  # Thema inaktiv (vor valid_from): Faktor 0 und Warnung
  w <- testthat::capture_warnings(withCallingHandlers(
    old <- vofi_resolve(vofi_scenario(ws_a_scenario(valuation_date = "2020-01-01",
                                                    energy = list(carriers = list(gas = list()))))),
    message = function(m) invokeRestart("muffleMessage"),
    vofi_warning_library_outdated = function(w) invokeRestart("muffleWarning")))
  expect_identical(sum(grepl("Emissionsfaktoren nicht verfügbar", w, fixed = TRUE)), 2L)
  expect_identical(old$energy$carriers$gas$emission_factor_kg_kwh, node_const(0))
  expect_identical(old$energy$carriers$gas$ghg_factor_kg_kwh, node_const(0))
})

test_that("F-9, F-15: Zusagezeitpunkt und Zusagewahrscheinlichkeit (Teil B 4.2, 5.5, R-111)", {
  local_ws_a_library()
  ms <- list(m1 = list(measure_type = "fenster", date = "2027-03-01", cost_eur = 1),
             m0 = list(measure_type = "fenster", date = "2027-02-01", cost_eur = 1))
  mk <- function(funding, measures = ms) {
    ws_a_scenario(valuation_date = "2026-11-01", measures = measures, funding = funding)
  }
  s <- ws_a_resolve(mk(list(
    a = list(instrument_type = "grant", measures = list("m1"), application_date = "2026-11-01"),
    b = list(instrument_type = "grant", measures = list("m1"), application_date = "2027-06-01"),
    c = list(instrument_type = "rent_binding", application_date = "2027-06-01"),
    d = list(instrument_type = "grant", measures = list("m1"), approval_timing = "after_start"),
    e = list(instrument_type = "grant", measures = list("m1"), approval_timing = "auto",
             application_date = "2027-02-15")
  )))
  expect_identical(s$funding$a$approval_timing, "before_start")
  expect_identical(ws_a_prov(s, "funding.a.approval_timing")$entry, "rule:approval_timing")
  expect_identical(s$funding$b$approval_timing, "after_start")
  expect_identical(s$funding$c$approval_timing, "after_start")
  expect_identical(s$funding$d$approval_timing, "after_start")
  expect_identical(s$funding$e$approval_timing, "before_start")   # Maßnahme m1 ab 2027-03-01
  none <- ws_a_resolve(mk(list(c = list(instrument_type = "rent_binding",
                                        application_date = "2027-06-01")), measures = list()))
  expect_identical(none$funding$c$approval_timing, "before_start")
  f15 <- ws_a_resolve(mk(list(
    late = list(instrument_type = "grant", application_date = "2031-03-01",
                budget_risk = list(approval_probability = 0.9)),
    early = list(instrument_type = "grant", application_date = "2030-12-01",
                 budget_risk = list(approval_probability = 0.9)),
    plain = list(instrument_type = "grant", application_date = "2031-03-01"),
    lib = list(from = "funding/kfw_261_eh55", application_date = "2027-01-01")
  )))
  expect_identical(f15$funding$late$approval_probability, node_expr(
    "funding.late.budget_risk.approval_probability * funding.late.availability_after_2030"))
  expect_equal(ws_a_value(f15, "funding.late.approval_probability"), 0.63)
  expect_identical(f15$funding$early$approval_probability,
                   node_ref("funding.early.budget_risk.approval_probability"))
  expect_equal(ws_a_value(f15, "funding.early.approval_probability"), 0.9)
  expect_equal(ws_a_value(f15, "funding.plain.approval_probability"), 0.7)
  expect_equal(ws_a_value(f15, "funding.lib.approval_probability"), 0.9)
  expect_identical(ws_a_prov(f15, "funding.lib.budget_risk.approval_probability")$entry,
                   "funding/kfw_261_wg_kredit_2026")
  expect_identical(ws_a_prov(f15, "funding.lib.repayment_grant.base_rates.ee")$entry,
                   "funding/kfw_261_eh55")
})

test_that("Overrides (Schicht 8): Pfadform, Löschen, Bibliotheksverweis, Overlay-Bindung (4.7)", {
  local_ws_a_library()
  sc <- vofi_scenario(ws_a_scenario(
    market = list(x = 0.02),
    stochastic = list(parameters = list(k = list(target = "market.x", dist = "normal",
                                                 mean = 0.02, sd = 0.01)))))
  expect_message(spec <- withCallingHandlers(
    vofi_resolve(sc, overrides = list("market.x" = 0.03, project = list(horizon_years = 12L),
                                      market = list(co2 = list(from = "prices/co2_price_paths_2026",
                                                               use = "scenarios.hoch")))),
    vofi_warning_library_outdated = function(w) invokeRestart("muffleWarning")),
    "deterministisch", fixed = TRUE)
  expect_identical(spec$market$x, node_const(0.03))
  expect_null(spec$stochastic$parameters$k)
  expect_identical(spec$project$horizon_years, 12L)
  expect_identical(ws_a_prov(spec, "market.co2")$entry, "prices/co2_price_paths_2026")
  expect_identical(ws_a_prov(spec, "market.co2")$layer, 8L)
  del <- ws_a_resolve(sc, overrides = list(accounts = list(prepay = NULL)))
  expect_null(del$accounts$prepay)
  keep <- ws_a_resolve(sc, overrides = list(stochastic = list(parameters = list(
    k = list(target = "market.x", dist = "normal", mean = 0.03, sd = 0.01))),
    market = list(x = 0.03)))
  expect_identical(keep$stochastic$parameters$k$mean, 0.03)
  # vofi_build() auf einer Spezifikation löst mit den gemischten Overrides neu auf
  sp2 <- ws_a_resolve(vofi_read_scenario(vofi_example("skeleton")),
                      overrides = list("accounts.deposit_rate_pa" = 0.03))
  sp3 <- ws_a_quiet(scn_apply_overrides(sp2, list("accounts.overdraft_rate_pa" = 0.09)))
  expect_identical(sp3$accounts$deposit_rate_pa, node_const(0.03))
  expect_identical(sp3$accounts$overdraft_rate_pa, node_const(0.09))
  expect_identical(attr(sp3, "scn_state")$overrides$accounts$overdraft_rate_pa, 0.09)
  plain <- sp2
  attr(plain, "scn_state") <- NULL
  sp4 <- scn_apply_overrides(plain, list("accounts.overdraft_rate_pa" = 0.09))
  expect_identical(sp4$accounts$overdraft_rate_pa, node_const(0.09))
  expect_identical(attr(sp4, "defaults_meta"), attr(sp2, "defaults_meta"))
  expect_identical(scn_merge_overrides(list(a = 1, b = list(c = 2)), list(b = list(c = NULL))),
                   list(a = 1, b = list(c = NULL)))
})

test_that("Gültigkeit der Bibliothekseinträge: Antragsdatum bei Förderung, Stand (D10, 4.9)", {
  local_ws_a_library()
  sc <- ws_a_scenario(valuation_date = "2026-11-01", funding = list(
    f = list(from = "funding/estg_35c", application_date = "2030-06-01")))
  w <- testthat::capture_warnings(suppressMessages(vofi_resolve(vofi_scenario(sc))))
  expect_true(any(grepl("funding/estg_35c", w, fixed = TRUE)))
  st <- ws_a_scenario(valuation_date = "2026-11-01", stochastic = list(parameters = list(
    a = list(target = "funding.f.availability_after_2030", from = "processes/funding_risks_2026",
             use = "availability_after_2030"))),
    funding = list(f = list(instrument_type = "grant")))
  w2 <- testthat::capture_warnings(suppressMessages(vofi_resolve(vofi_scenario(st))))
  expect_true(any(grepl("processes/funding_risks_2026", w2, fixed = TRUE)))
  expect_true(any(grepl("12 Monate", w2, fixed = TRUE)))
  cls <- tryCatch(suppressMessages(vofi_resolve(vofi_scenario(st))),
                  warning = function(w) class(w))
  expect_true("vofi_warning_library_outdated" %in% cls)
})

test_that("Ohne Paketbibliothek entfallen die Verweise der Defaults-Dateien (Hinweis)", {
  testthat::local_mocked_bindings(lib_package_root = function() "")
  lib_state$index <- NULL
  withr::defer(lib_state$index <- NULL)
  st <- scn_state$missing_informed
  scn_state$missing_informed <- character(0)
  withr::defer(scn_state$missing_informed <- st)
  expect_message(spec <- vofi_resolve(vofi_read_scenario(vofi_example("skeleton"))),
                 "Paketbibliothek")
  expect_length(spec$market, 0L)
  expect_null(spec$residual_value$income_value$cap_rate)
  expect_identical(spec$residual_value$method, "income_value")
  expect_identical(nrow(spec$library), 0L)
  expect_true(is.na(attr(spec, "library_version")))
  e <- expect_error(vofi_resolve(vofi_scenario(ws_a_scenario(
    funding = list(f = list(from = "funding/kfw_261_eh55"))))), class = "vofi_error_validation")
  expect_identical(e$key, "io.library.entry_unknown")
})

test_that("Defaults-Dateien: Prüfung der reservierten Schlüssel (R-76, R-85, R-97, N-05; d5)", {
  bad <- io_read_yaml_utf8(ws_a_lib("defaults", "global_bad.yaml"))
  f <- scn_check_defaults(bad, "global", "defaults/global_bad.yaml")
  codes <- vapply(f, function(x) x$code, "")
  paths <- vapply(f, function(x) x$path, "")
  expect_true("validation.unknown_key" %in% codes)
  expect_true("energy_defaults" %in% paths[codes == "validation.unknown_key"])
  expect_true("io.defaults.optional_block" %in% codes)
  expect_true("io.defaults.settings_forbidden" %in% codes)
  expect_true("io.defaults.item_path" %in% codes)
  expect_true("io.defaults.project_type" %in% codes)
  for (x in f) expect_true(nzchar(do.call(lbl, c(list(x$code), x$args))))
  prof <- io_read_yaml_utf8(ws_a_lib("profiles", "forbidden_profile.yaml"))
  fp <- scn_check_defaults(prof, "profile", "profiles/forbidden_profile.yaml")
  pc <- vapply(fp, function(x) x$code, "")
  expect_true(scn_key("validation.profile_path_forbidden", "io.defaults.profile_path",
                      path = "", allowed = "") %in% pc)
  expect_true("market.inflation" %in% vapply(fp, function(x) x$path, ""))
  meta <- scn_check_defaults(list(project = list()), "profile", "p.yaml")
  expect_identical(meta[[1]]$code, "io.defaults.meta_missing")
  m2 <- scn_check_defaults(list(defaults_meta = list(kind = "global", id = "x",
                                                     schema_version = 2, quality = "E")),
                           "profile", "p.yaml")
  expect_true(all(c("io.defaults.meta_incomplete", "io.defaults.meta_kind",
                    "io.defaults.meta_schema", "io.defaults.meta_quality",
                    "io.defaults.item_defaults_profile") %in%
                    c(vapply(m2, function(x) x$code, ""),
                      vapply(scn_check_defaults(list(defaults_meta = list(kind = "profile"),
                                                     item_defaults = list()), "profile", "p"),
                             function(x) x$code, ""))))
  e <- expect_error(scn_defaults_load("global", path = ws_a_lib("defaults", "global_bad.yaml")),
                    class = "vofi_error_validation")
  expect_true(startsWith(e$key, "validation.") || startsWith(e$key, "io."))
  expect_null(scn_defaults_load("profile", "gibtsnicht"))
  expect_identical(scn_defaults_path("profile", "../x"), "")
})

test_that("Build-Kontext bctx: gesperrt, Knoten, Basisfallwerte, Recht, Bibliothek (6.4)", {
  local_ws_a_library()
  spec <- ws_a_resolve(ws_a_scenario(building = list(living_area_m2 = 1000)))
  g <- scn_grid(spec)
  b <- scn_bctx(spec, g)
  expect_s3_class(b, "vofi_bctx")
  expect_true(environmentIsLocked(b))
  expect_error(assign("grid", NULL, envir = b))
  expect_identical(b$node_const(2), node_const(2))
  expect_identical(b$node_ref("market.inflation"), node_ref("market.inflation"))
  expect_identical(b$node_expr("building.living_area_m2 * 2")$kind, "expr")
  expect_identical(b$value_base("building.living_area_m2"), 1000)
  expect_identical(b$period_of(as.Date("2027-06-01")), grid_period_of(g, as.Date("2027-06-01")))
  expect_identical(b$period_of_year(2030L), grid_period_of_year(g, 2030L))
  expect_identical(b$legal("umsatzsteuer")$standard, 0.19)
  expect_null(b$legal("mietrecht_559f"))
  expect_identical(b$lib("costs/kostenzuschlaege_2026")$contingency_share, 0.1)
  expect_error(b$lib("costs/gibtsnicht"), class = "vofi_error_validation")
  expect_identical(b$project$perspective, "wu_privat")
  expect_identical(b$building$living_area_m2, node_const(1000))
  expect_identical(b$lbl("io.variant_base_label"), "Basis")
  expect_error(b$abort("io.not_map", path = "x"), class = "vofi_error_validation")
  expect_warning(b$warn("io.not_map", path = "x"), class = "vofi_warning_plausibility")
  expect_message(b$inform("io.not_map", path = "x"))
  expect_error(b$rule("gibtsnicht"), class = "vofi_error_registry")
  expect_null(scn_value_base(spec, NULL, "building.living_area_m2"))
})

test_that("Expander: order-Reihenfolge, Herkunft expander, Kollision ist ein Fehler (4.12)", {
  local_ws_a_library()
  old <- reg_state$types
  withr::defer(reg_state$types <- old)
  ex <- vofi_type(name = "ws_a_test", kind = "expander", block = "measures", order = 99L,
                  expand = function(block, scenario, bctx) {
                    comps <- lapply(names(block), function(m) {
                      list(type = "custom_series", values = c(0, 0, 0),
                           measure_id = m, label = bctx$lbl("io.variant_base_label"))
                    })
                    names(comps) <- paste0("x_", names(block))
                    list(components = comps, assets = list(), measures = list(),
                         notes = "Testexpander")
                  })
  reg_add(ex, source = "vofi")
  sc <- ws_a_scenario(horizon_years = 2L, measures = list(
    m = list(measure_type = "fenster", year = 2028, cost_eur = 1)))
  spec <- ws_a_resolve(sc)
  expect_true("x_m" %in% names(spec$components))
  expect_identical(spec$components$x_m$origin, "expander")
  expect_identical(spec$components$x_m$measure_id, "m")
  expect_identical(ws_a_prov(spec, "components.x_m.values")$source_type, "expander")
  expect_identical(ws_a_prov(spec, "components.x_m.values")$entry, "expander:ws_a_test")
  expect_true("Testexpander" %in% attr(spec, "notes"))
  sc$components$x_m <- list(type = "custom_series", values = c(1, 2, 3))
  e <- expect_error(ws_a_resolve(sc), class = "vofi_error_validation")
  expect_identical(e$key, "io.expander_id_collision")
  expect_error(scn_merge_expansion(list(), "kaputt", "t", NULL), class = "vofi_error_contract")
})

test_that("Knotenbewusstes Mischen und Prüfung des Schlüssels from (4.7, R-110)", {
  r <- list(m = list(a = list(ref = "market.x")))
  expect_identical(scn_merge(list(m = list(a = node_const(1))), r), r)
  g <- node_growth(0.06, 0.02)
  m <- scn_merge(list(p = g), list(p = list(growth = 0.08)), "")
  expect_identical(m$p$growth, 0.08)
  expect_identical(m$p$start, node_const(0.06))
  expect_identical(scn_merge(list(a = list(b = 1, c = 2)), list(a = list(.replace = TRUE, d = 3))),
                   list(a = list(d = 3)))
  expect_identical(scn_merge(list(a = 1, b = 2), list(a = NULL)), list(b = 2))
  expect_identical(scn_kind_of("market"), "map")
  expect_identical(scn_kind_of("stochastic.parameters.k"), "map")
  expect_identical(scn_kind_of("funding.k"), "map")
  expect_true(is.na(scn_kind_of("market.x")))
  expect_true(scn_is_library_ref(list(from = "funding/kfw_261_eh55")))
  expect_false(scn_is_library_ref(list(from = "completion")))
  expect_error(scn_check_library(list(components = list(r = list(from = "2027-10-01")))),
               class = "vofi_error_validation")
  expect_true(scn_check_library(list(market = list(co2 = list(from = "prices/co2")))))
  expect_identical(scn_overrides_tree(list("a.b" = 1, c = 2, "a.d" = NULL)),
                   list(c = 2, a = list(b = 1, d = NULL)))
  expect_error(scn_overrides_tree(list(1)), class = "vofi_error_input")
})
