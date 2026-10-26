# Tests des Expanders unit_groups (WS-E2, Spec 01 Teil B 1.6, 2.2, 2.3, 3.10, O-7a).

e2_ug_bld <- function(...) {
  utils::modifyList(list(building_type = "MFH", construction_year = 1975L, n_units = 12L,
                         living_area_m2 = 840, maintenance = list(basis = "none")), list(...))
}

e2_ug <- function(...) {
  utils::modifyList(list(n_units = 12L, living_area_m2 = 840, rent_eur_m2_month = 6.4),
                    list(...))
}

test_that("vermietete Gruppe: u_<g>_rent und u_<g>_opex mit Bezügen, Hinweis ohne Grundsteuer", {
  x <- e2_scenario(building = e2_ug_bld(),
                   project = list(municipality = list(kappung_15_area = TRUE,
                                                      mietpreisbremse_area = TRUE,
                                                      mietpreisbremse_until = "2029-12-31")),
                   unit_groups = list(g = e2_ug(label = "Bestand", vacancy_rate = 0.03,
                                                growth_from = "2028-01-01")))
  r <- e2_resolve_full(x)
  spec <- r$value
  rp <- spec$components$u_g_rent
  expect_identical(rp$type, "rent_path")
  expect_identical(rp$label, "Bestand")
  expect_identical(rp$unit_group, "g")
  expect_identical(rp$living_area_m2, node_ref("unit_groups.g.living_area_m2"))
  expect_identical(rp$rent_eur_m2_month, node_ref("unit_groups.g.rent_eur_m2_month"))
  expect_identical(rp$vacancy_rate, node_ref("unit_groups.g.vacancy_rate"))
  expect_identical(rp$rent_growth, node_ref("unit_groups.g.rent_growth"))
  expect_identical(rp$n_units, 12L)
  expect_identical(rp$rent_regime, "paragraph_558")
  expect_identical(rp$growth_from, as.Date("2028-01-01"))
  expect_true(rp$kappung_15_area)
  expect_true(rp$brake_area)
  expect_identical(rp$brake_until, as.Date("2029-12-31"))
  expect_false(rp$first_use_after_2014_10_01)
  expect_identical(rp$modernization_levy, "auto")
  op <- spec$components$u_g_opex
  expect_identical(op$type, "operating_cost")
  expect_identical(op$rent_component, "u_g_rent")
  expect_identical(op$after, "u_g_rent")
  expect_false(op$owner_occupied)
  expect_identical(op$admin_per_unit_eur_pa,
                   node_ref("unit_groups.g.operating.admin_per_unit_eur_pa"))
  expect_identical(op$start_event, as.Date("2027-01-01"))
  expect_false("u_g_property_tax" %in% names(spec$components))
  expect_true("expand.unit_groups.property_tax_missing" %in% r$messages)
  res <- e2_run(spec)
  expect_equal(e2_row(res, "u_g_rent__rent")[2L], 6.4 * 840 * 12)
})

test_that("selbstgenutzte Gruppe: Kosten, Grundsteuer (W ohne Angabe), Mietwert", {
  base <- e2_scenario(perspective = "selbstnutzer", project_type = "sanierung_einzelmassnahmen",
                      building = e2_ug_bld(n_units = 1L, living_area_m2 = 140),
                      unit_groups = list(haus = list(n_units = 1L, living_area_m2 = 140,
                                                     imputed_rent_eur_m2_month = 9)))
  r <- e2_resolve_full(base)
  spec <- r$value
  expect_false("u_haus_rent" %in% names(spec$components))
  op <- spec$components$u_haus_opex
  expect_true(op$owner_occupied)
  expect_identical(op$perspective_tax, "nondeductible")
  expect_null(op$rent_component)
  expect_true("expand.unit_groups.property_tax_missing_owner" %in% r$warnings)
  imp <- spec$components$u_haus_imputed_rent
  expect_identical(imp$type, "imputed_rent")
  expect_identical(imp$area_m2, node_ref("unit_groups.haus.living_area_m2"))
  expect_identical(imp$rent_eur_m2_month, node_ref("unit_groups.haus.imputed_rent_eur_m2_month"))
  expect_identical(imp$growth, node_ref("unit_groups.haus.imputed_rent_growth"))
  expect_identical(imp$base_date, as.Date("2028-01-01"))
  base$building$property_tax <- list(amount_eur_pa = 1600)
  r <- e2_resolve_full(base)
  pt <- r$value$components$u_haus_property_tax
  expect_identical(pt$amount_eur_pa, node_ref("building.property_tax.amount_eur_pa"))
  expect_true(pt$owner_occupied)
  expect_false("expand.unit_groups.property_tax_missing_owner" %in% r$warnings)
  res <- e2_run(r$value)
  g <- e2_path(r$value, "market.inflation")
  expect_equal(e2_row(res, "u_haus_property_tax__cost")[2L], -1600 * (1 + g[2L]),
               tolerance = 1e-9)
})

test_that("O-7a/2.3: Grundsteuer mit Flächenanteil, Messbetrag × Hebesatz, Fehlerfälle", {
  x <- e2_scenario(building = e2_ug_bld(property_tax = list(assessment_amount_eur = 1000,
                                                            municipal_multiplier = 5)),
                   unit_groups = list(a = e2_ug(n_units = 8L, living_area_m2 = 600),
                                      b = e2_ug(n_units = 4L, living_area_m2 = 240)))
  spec <- e2_resolve(x)
  pa <- spec$components$u_a_property_tax$amount_eur_pa
  expect_identical(pa$kind, "expr")
  expect_identical(pa$text, paste0("(building.property_tax.assessment_amount_eur * ",
                                   "building.property_tax.municipal_multiplier) * ",
                                   "unit_groups.a.living_area_m2 / (unit_groups.a.living_area_m2",
                                   " + unit_groups.b.living_area_m2)"))
  expect_equal(e2_value(spec, "components.u_a_property_tax.amount_eur_pa") +
                 e2_value(spec, "components.u_b_property_tax.amount_eur_pa"), 5000)
  expect_identical(spec$components$u_b_property_tax$rent_component, "u_b_rent")
  x$building$property_tax <- list(assessment_amount_eur = 1000)
  e <- expect_error(e2_resolve(x), class = "vofi_error_validation")
  expect_identical(e$key, "expand.unit_groups.multiplier_missing")
  x$building$property_tax <- list(land_amount_eur_pa = 900)
  e <- expect_error(e2_resolve(x), class = "vofi_error_validation")
  expect_identical(e$key, "expand.unit_groups.property_tax_amount_missing")
})

test_that("1.6 Nr. 4/5: mietrechtliche Maßnahmen, Umlagezeilen, Kosten- und Förderbausteine", {
  x <- e2_scenario(perspective = "wu_genossenschaft", project_type = "heizungstausch",
                   building = e2_ug_bld(heating_existing = list(carrier = "gas_mfh",
                                                                installation_year = 2002L)),
                   unit_groups = list(m = e2_ug(rent_law = list(modernization_levy = "auto"))),
                   measures = list(
                     wp = list(measure_type = "heizung_waermepumpe_luft", year = 2027,
                               completion_date = "2027-10-01", cost_eur = 153560,
                               ohnehin_cost_eur = 45360, modernization_kind = "bgb_555b_1a"),
                     fenster = list(measure_type = "fenster", year = 2027, cost_eur = 50000,
                                    modernization_kind = "bgb_555b_1",
                                    rent_law = list(levy = "none")),
                     anstrich = list(measure_type = "putz_anstrich", year = 2027,
                                     cost_eur = 10000)
                   ),
                   funding = list(kfw459 = list(from = "funding/kfw_459_heizung_unternehmen",
                                                measures = list("wp"),
                                                application_date = "2027-01-15",
                                                approval_timing = "before_start")))
  r <- e2_resolve_full(x)
  rp <- r$value$components$u_m_rent
  expect_identical(rp$rent_regime, "cooperative_fee")
  expect_setequal(rp$rent_law_measures, c("wp", "fenster"))
  expect_identical(rp$levy_rows, "wp")
  expect_setequal(rp$cost_components, c("m_wp_capex", "m_fenster_capex"))
  expect_identical(rp$grant_components, "f_kfw459_grant")
  expect_setequal(rp$after, c("m_wp_capex", "m_fenster_capex", "f_kfw459_grant"))
  expect_true("expand.unit_groups.levy_excluded" %in% r$messages)
  expect_true("f_kfw459_grant" %in% names(r$value$components))
  res <- e2_run(r$value)
  expect_true(sum(e2_row(res, "u_m_rent__levy_wp")) > 0)
  # Gruppenbeschluss modernization_levy: none -> keine Umlagezeilen
  x$unit_groups$m$rent_law$modernization_levy <- "none"
  rp <- e2_resolve(x)$components$u_m_rent
  expect_length(rp$levy_rows, 0L)
  expect_setequal(rp$rent_law_measures, c("wp", "fenster"))
})

test_that("1.6 Nr. 6/7: Mietbindung und warmmietenneutrale Obergrenze", {
  x <- e2_scenario(building = e2_ug_bld(),
                   unit_groups = list(g = e2_ug(rent_law = list(
                     voluntary_cap_mode = "warm_rent_neutral"
                   ))),
                   energy = list(carriers = list(gas = list()),
                                 before = list(heating_carrier = "gas", demand_kwh = 100000,
                                               efficiency = 0.9)),
                   funding = list(bind = list(instrument_type = "rent_binding",
                                              rent_binding = list(rent_eur_m2_month = 5.9,
                                                                  increase_pa = 0.01,
                                                                  years = 15),
                                              approval_probability = 0.8)))
  r <- e2_resolve_full(x)
  rp <- r$value$components$u_g_rent
  expect_identical(rp$rent_regime, "bound_social")
  expect_identical(rp$rent_eur_m2_month, node_ref("funding.bind.rent_binding.rent_eur_m2_month"))
  expect_identical(rp$bound_increase_pa, node_ref("funding.bind.rent_binding.increase_pa"))
  expect_identical(rp$binding_end, as.Date("2042-01-01"))
  expect_identical(rp$tenant_cost_component, "e_tenant")
  expect_true("e_tenant" %in% rp$after)
  expect_true("e_tenant" %in% names(r$value$components))
  expect_true("expand.unit_groups.binding_unconditional" %in% r$warnings)
})

test_that("Neubau: Mietbeginn und Kostenbeginn zum Token completion; id-Länge der Gruppe", {
  x <- e2_scenario(perspective = "wu_privat", project_type = "neubau", horizon_years = 5L,
                   grid = list(construction_months = 12L),
                   building = e2_ug_bld(construction_year = 2028L),
                   unit_groups = list(g = e2_ug(rent_eur_m2_month = 13)))
  spec <- e2_resolve(x)
  expect_identical(spec$components$u_g_rent$rent_start, "completion")
  expect_identical(spec$components$u_g_opex$start_event, "completion")
  expect_true(spec$components$u_g_rent$first_use_after_2014_10_01)
  res <- e2_run(spec)
  rent <- e2_row(res, "u_g_rent__rent")
  expect_equal(rent[2L], 0)
  expect_true(rent[3L] > 0)
  long <- strrep("g", 26L)
  ug <- list(e2_ug())
  names(ug) <- long
  e <- expect_error(e2_resolve(e2_scenario(building = e2_ug_bld(), unit_groups = ug)),
                    class = "vofi_error_validation")
  expect_identical(e$key, "expand.unit_groups.id_too_long")
  expect_equal(e$args$max, 25L)
})
