# Tests des Expanders energy (WS-E2, Spec 01 Teil B 3.2.3, 3.3, 3.5; E-3, E-4, S3, S4, S5).

e2_en_bld <- function(...) {
  utils::modifyList(list(building_type = "MFH", construction_year = 1985L, n_units = 12L,
                         living_area_m2 = 840, maintenance = list(basis = "none")), list(...))
}

e2_en_s3 <- function(after = NULL) {
  e2_scenario(perspective = "wu_genossenschaft", project_type = "heizungstausch",
              building = e2_en_bld(heating_existing = list(carrier = "gas_mfh",
                                                           installation_year = 2002L),
                                   consumption_kwh = list(gas_mfh = 109200)),
              unit_groups = list(m = list(n_units = 12L, living_area_m2 = 840,
                                          rent_eur_m2_month = 6.4)),
              measures = list(wp = list(measure_type = "heizung_waermepumpe_luft", year = 2027,
                                        completion_date = "2027-10-01", cost_eur = 153560,
                                        modernization_kind = "bgb_555b_1a")),
              energy = list(carriers = list(gas_mfh = list(emission_factor_kg_kwh = 0.181),
                                            heatpump_power_mfh = list()),
                            before = list(efficiency = 0.87, service_eur_pa = 714.28571429),
                            after = after %||% list(measure = "wp", demand_kwh = 95000,
                                                    heating_carrier = "heatpump_power_mfh",
                                                    jaz = 3.1, service_eur_pa = 756.30252101)))
}

test_that("S3: Segmente, Mengen, Vorzustand, CO2-Kosten und Mieterkosten", {
  spec <- e2_resolve(e2_en_s3())
  ids <- names(spec$components)
  expect_true(all(c("e_before_gas_mfh_cost", "e_after_heatpump_power_mfh_cost",
                    "e_before_gas_mfh_co2", "e_tenant") %in% ids))
  expect_false("e_after_heatpump_power_mfh_co2" %in% ids)
  b <- spec$components$e_before_gas_mfh_cost
  expect_identical(b$type, "energy_cost")
  expect_identical(b$state, "before")
  expect_identical(b$carrier_class, "gas")
  expect_identical(b$quantity_kwh_pa, node_ref("building.consumption_kwh.gas_mfh"))
  expect_true(b$counterfactual_pre)
  expect_identical(b$installation_date, as.Date("2002-01-01"))
  expect_identical(b$price_eur_kwh, node_ref("energy.carriers.gas_mfh.price_eur_kwh"))
  expect_identical(b$service_eur_pa, node_ref("energy.before.service_eur_pa"))
  expect_identical(b$owner_share, node_const(0))
  expect_identical(b$unit_groups, "m")
  expect_true(b$vacancy_landlord)
  expect_identical(b$construction_delay_months, node_ref("project.construction_delay_months"))
  a <- spec$components$e_after_heatpump_power_mfh_cost
  expect_identical(a$installation_date, as.Date("2027-10-01"))
  expect_false(a$counterfactual_pre)
  expect_identical(a$quantity_kwh_pa$kind, "expr")
  expect_equal(e2_value(spec, "components.e_after_heatpump_power_mfh_cost.quantity_kwh_pa"),
               95000 / 3.1)
  co2 <- spec$components$e_before_gas_mfh_co2
  expect_identical(co2$energy_component, "e_before_gas_mfh_cost")
  expect_identical(co2$all_energy_components, "e_before_gas_mfh_cost")
  expect_identical(co2$pre_energy_components, "e_before_gas_mfh_cost")
  expect_identical(co2$living_area_m2, node_ref("building.living_area_m2"))
  expect_false(co2$section43)
  t <- spec$components$e_tenant
  expect_setequal(t$energy_components, c("e_before_gas_mfh_cost",
                                         "e_after_heatpump_power_mfh_cost"))
  expect_identical(t$co2_components, "e_before_gas_mfh_co2")
  expect_identical(t$pre_energy_components, "e_before_gas_mfh_cost")
  expect_identical(t$rented_area_m2, node_ref("unit_groups.m.living_area_m2"))
  res <- e2_run(spec)
  expect_equal(e2_row(res, "e_before_gas_mfh_cost__quantity")[2L], 109200 * 0.75)
  expect_equal(e2_row(res, "e_after_heatpump_power_mfh_cost__quantity")[3L], 95000 / 3.1)
})

test_that("S4/E-3: Stufen mit Vererbung als Bezug auf den definierenden Zustand", {
  x <- e2_scenario(perspective = "selbstnutzer", project_type = "sanierung_stufenweise",
                   horizon_years = 8L,
                   building = e2_en_bld(n_units = 1L, living_area_m2 = 140,
                                        heating_existing = list(carrier = "gas",
                                                                installation_year = 2008L),
                                        consumption_kwh = list(gas = 24500)),
                   measures = list(
                     wp = list(measure_type = "heizung_waermepumpe_luft", year = 2027,
                               completion_date = "2027-10-01", cost_eur = 32960),
                     dach = list(measure_type = "daemmung_dach_steil", year = 2030,
                                 completion_date = "2030-10-01", cost_eur = 80000)
                   ),
                   energy = list(carriers = list(gas = list(), heatpump_power = list()),
                                 before = list(efficiency = 0.88),
                                 after = list(measure = "wp", demand_kwh = 21560,
                                              heating_carrier = "heatpump_power", jaz = 2.9),
                                 stages = list(stufe2 = list(measure = "dach",
                                                             demand_kwh = 16170, jaz = 3.2))))
  spec <- e2_resolve(x)
  s2 <- spec$components$e_stufe2_heatpump_power_cost
  expect_identical(s2$state, "stufe2")
  expect_identical(s2$installation_date, as.Date("2027-10-01"))
  q <- s2$quantity_kwh_pa$text
  expect_true(grepl("energy.stages.stufe2.demand_kwh", q, fixed = TRUE))
  expect_true(grepl("energy.stages.stufe2.jaz", q, fixed = TRUE))
  expect_true(grepl("building.consumption_kwh.gas * energy.before.efficiency", q, fixed = TRUE))
  expect_equal(e2_value(spec, "components.e_stufe2_heatpump_power_cost.quantity_kwh_pa"),
               16170 / 3.2)
  expect_equal(e2_value(spec, "components.e_after_heatpump_power_cost.quantity_kwh_pa"),
               21560 / 2.9)
  expect_identical(s2$owner_share, node_const(1))
  expect_false("e_tenant" %in% names(spec$components))
  # Vererbung der JAZ, wenn die Stufe keine eigene hat
  x$energy$stages$stufe2$jaz <- NULL
  s2 <- e2_resolve(x)$components$e_stufe2_heatpump_power_cost
  expect_true(grepl("energy.after.jaz", s2$quantity_kwh_pa$text, fixed = TRUE))
})

test_that("E-4: Performance Gap mit Bedarf vorher, Rebound und Realisierungsfaktor", {
  x <- e2_scenario(perspective = "selbstnutzer", project_type = "sanierung_einzelmassnahmen",
                   building = e2_en_bld(n_units = 1L, living_area_m2 = 140),
                   measures = list(wp = list(measure_type = "heizung_waermepumpe_luft",
                                             year = 2027, cost_eur = 30000)),
                   energy = list(carriers = list(gas = list(), heatpump_power = list()),
                                 performance_gap = list(rebound_factor = 1.1),
                                 before = list(heating_carrier = "gas", demand_kwh = 30000,
                                               efficiency = 0.9),
                                 after = list(measure = "wp", demand_kwh = 12000,
                                              heating_carrier = "heatpump_power", jaz = 3)))
  spec <- e2_resolve(x)
  qa <- "components.e_after_heatpump_power_cost.quantity_kwh_pa"
  expect_equal(e2_value(spec, qa), 4400)
  expect_equal(e2_value(spec, "components.e_before_gas_cost.quantity_kwh_pa"), 30000 * 0.7 / 0.9)
  x$energy$performance_gap$realisation_factor <- 0.8
  expect_equal(e2_value(e2_resolve(x), qa), 4920)
})

test_that("S5: Neubau mit Wärmepumpe am Haushaltszähler, Zusatzverbrauch, PV", {
  x <- e2_scenario(perspective = "selbstnutzer", project_type = "neubau", horizon_years = 5L,
                   grid = list(construction_months = 12L),
                   building = e2_en_bld(n_units = 1L, living_area_m2 = 140,
                                        construction_year = 2027L),
                   measures = list(pv = list(measure_type = "pv", date = "2027-12-01",
                                             completion_date = "2027-12-01", cost_eur = 11000)),
                   energy = list(carriers = list(power = list(base_fee_eur_pa = 100)),
                                 after = list(demand_kwh = 7000, heating_carrier = "power",
                                              heat_pump_carrier = "power", jaz = 3.5,
                                              extra_consumption = list(
                                                haushalt = list(carrier = "power",
                                                                kwh_pa = 3500)
                                              )),
                                 pv = list(kwp = 8, measure = "pv", specific_yield_kwh_kwp = 950,
                                           self_consumption_share = 0.35,
                                           feed_in_tariff_eur_kwh = 0.0755)))
  spec <- e2_resolve(x)
  seg <- spec$components$e_after_power_cost
  expect_equal(e2_value(spec, "components.e_after_power_cost.quantity_kwh_pa"), 2000)
  expect_identical(seg$extra_kwh_pa, node_ref("energy.after.extra_consumption.haushalt.kwh_pa"))
  expect_identical(seg$base_fee_eur_pa, node_ref("energy.carriers.power.base_fee_eur_pa"))
  expect_identical(seg$owner_share, node_const(1))
  pv <- spec$components$e_pv
  expect_identical(pv$type, "pv")
  expect_identical(pv$kwp, node_ref("energy.pv.kwp"))
  expect_identical(pv$measure, "pv")
  expect_identical(pv$commissioning_date, as.Date("2027-12-01"))
  expect_identical(pv$feed_in_tariff_eur_kwh, node_ref("energy.pv.feed_in_tariff_eur_kwh"))
  expect_identical(pv$self_consumption_components, "e_after_power_cost")
  expect_identical(pv$opex_eur_pa,
                   node_expr("energy.pv.opex_share_of_cost * measures.pv.cost_eur"))
  res <- e2_run(spec)
  expect_equal(e2_row(res, "e_after_power_cost__quantity")[3L], 5500)
  expect_true(e2_row(res, "e_pv__self_consumption")[3L] > 0)
})

test_that("Zustandsfolge, Eigentümeranteil, § 43, id-Längen und Fehlerfälle", {
  x <- e2_en_s3()
  x$unit_groups$own <- list(n_units = 1L, living_area_m2 = 60, owner_occupied = TRUE)
  spec <- e2_resolve(x)
  os <- spec$components$e_before_gas_mfh_cost$owner_share
  expect_identical(os, node_expr(paste0("(unit_groups.own.living_area_m2) / (",
                                        "unit_groups.m.living_area_m2 + ",
                                        "unit_groups.own.living_area_m2)")))
  # neue Gasheizung im Bestand nach dem 29.07.2026: § 43 abgeleitet
  g <- e2_en_s3(after = list(measure = "wp", demand_kwh = 95000, heating_carrier = "gas_mfh",
                             efficiency = 0.95))
  sg <- e2_resolve(g)
  expect_true(sg$components$e_after_gas_mfh_cost$section43)
  expect_true(sg$components$e_after_gas_mfh_co2$section43)
  expect_identical(sg$components$e_after_gas_mfh_co2$installation_date, as.Date("2027-10-01"))
  expect_setequal(sg$components$e_after_gas_mfh_co2$all_energy_components,
                  c("e_before_gas_mfh_cost", "e_after_gas_mfh_cost"))
  expect_length(sg$components$e_after_gas_mfh_co2$pre_energy_components, 0L)
  # gleichzeitiger Beginn zweier Folgezustände ist ein Fehler
  t <- e2_en_s3()
  t$energy$stages <- list(s2 = list(start_event = "2027-10-01", demand_kwh = 90000))
  t$energy$after$measure <- NULL
  t$energy$after$start_event <- "2027-10-01"
  e <- expect_error(e2_resolve(t), class = "vofi_error_validation")
  expect_identical(e$key, "expand.energy.state_order")
  # Zustands-id länger als 12 Zeichen
  l <- e2_en_s3()
  l$energy$stages <- list(abcdefghijklm = list(start_event = "2030-01-01", demand_kwh = 9e4))
  e <- expect_error(e2_resolve(l), class = "vofi_error_validation")
  expect_identical(e$key, "expand.energy.id_too_long")
  # fehlender Wirkungsgrad eines fossilen Trägers
  f <- e2_en_s3()
  f$energy$before$efficiency <- NULL
  e <- expect_error(e2_resolve(f), class = "vofi_error_validation")
  expect_identical(e$key, "expand.energy.efficiency_missing")
})
