# Tests der gemeinsamen Expander-Helfer und Ende-zu-Ende-Läufe über vofi_build()/vofi_run()
# (WS-E2, Spec 00 4.12, R-92; Spec 01 Teil A 4.5, 6.2, Teil B 0.8, 1.6, 3.5, 4).

test_that("Lesehilfen: Zahlen, Daten, Flags, Codes, Pfade, Ausdrucksteile", {
  expect_equal(exp_num(node_const(3)), 3)
  expect_equal(exp_num(list(kind = "series_t", values = list(node_const(1), node_const(2)))),
               c(1, 2))
  expect_null(exp_num(node_ref("a.b")))
  expect_null(exp_num(TRUE))
  expect_equal(exp_num("2.5"), 2.5)
  expect_identical(exp_int(node_const(2027)), 2027L)
  expect_identical(exp_date("2027-10-01"), as.Date("2027-10-01"))
  expect_identical(exp_date(node_const(2028)), as.Date("2028-01-01"))
  expect_identical(exp_date(list(year = 2029)), as.Date("2029-01-01"))
  g <- vofi_time_grid(as.Date("2027-01-01"), 3L, construction_months = 12L)
  expect_identical(exp_date("completion", g), g$completion_date)
  expect_null(exp_date("completion"))
  expect_true(exp_lgl("true"))
  expect_false(exp_lgl(node_const(0)))
  expect_null(exp_lgl("required"))
  expect_identical(exp_chr(list("a", "b")), c("a", "b"))
  expect_identical(exp_fmt(c(0.1, -0.04, 1e300, 151000)), c("0.1", "(-0.04)", "1e+300", "151000"))
  expect_true(exp_is_path("funding.f.rate_components.grund.rate"))
  expect_false(exp_is_path("a + b"))
  expect_identical(exp_sum_node(character(0)), node_const(0))
  expect_identical(exp_sum_node("x.y"), node_ref("x.y"))
  expect_identical(exp_sum_node(c("x.y", "0.1")), node_expr("x.y + 0.1"))
  expect_identical(exp_text_node("3"), node_const(3))
  expect_identical(exp_sort(c("b", "a", "B")), sort(c("b", "a", "B"), method = "radix"))
})

test_that("Aktivierungsfaktor a_m und Maßnahmentermine (Teil B 0.8, Teil A 4.5.1)", {
  x <- list(measures = list(m = list(active = node_const(1)), k = list()),
            funding = list(f1 = list(on_reject = "drop_measures", measures = list("m")),
                           f2 = list(on_reject = "balance", measures = list("m")),
                           f3 = list(on_reject = "drop_measures", measures = list("m", "k"))))
  expect_identical(exp_activation_text(x, "m"),
                   "measures.m.active * funding.f1.approved * funding.f3.approved")
  expect_identical(exp_activation_text(x, "k"), "funding.f3.approved")
  expect_identical(exp_activation_node(list(measures = list(z = list())), "z"), node_const(1))
  expect_identical(exp_activation_node(list(measures = list(z = list(active = 1))), "z"),
                   node_ref("measures.z.active"))
  ms <- list(measures = list(
    a = list(date = "2027-06-01"),
    b = list(year = node_const(2028), completion_date = "2028-09-01"),
    c = list(date = "2027-12-01", duration_months = node_const(3)),
    d = list(payment_schedule = list(kind = "schedule",
                                     dates = as.Date(c("2027-07-01", "2028-07-01")),
                                     amounts = list(node_const(0.4), node_const(0.6)),
                                     unit = "share"))
  ))
  da <- exp_measure_dates(ms, "a")
  expect_identical(da$completion, as.Date("2027-06-01"))
  db <- exp_measure_dates(ms, "b")
  expect_identical(c(db$first, db$completion), as.Date(c("2028-01-01", "2028-09-01")))
  dc <- exp_measure_dates(ms, "c")
  expect_identical(dc$dates, as.Date(c("2027-10-01", "2027-11-01", "2027-12-01")))
  expect_equal(sum(dc$weights), 1)
  dd <- exp_measure_dates(ms, "d")
  expect_equal(dd$weights, c(0.4, 0.6))
  expect_identical(dd$completion, as.Date("2028-07-01"))
  expect_null(exp_measure_dates(list(measures = list(e = list())), "e"))
})

test_that("Förderung: Berechtigung, Symbole, Wohneinheiten und Plan (Teil B 4.3, 4.4)", {
  x <- list(project = list(perspective = "kleinvermieter", project_type = "heizungstausch",
                           application_date = as.Date("2026-12-01")),
            building = list(n_units = 6L, construction_year = 1990L,
                            heating_existing = list(carrier = "oil", installation_year = 2010L)),
            household = list(taxable_income_avg_eur = 58000, n_children_u18 = 2L),
            unit_groups = list(a = list(n_units = node_const(4), owner_occupied = FALSE),
                               b = list(n_units = node_const(2), owner_occupied = TRUE)),
            measures = list(wp = list(measure_type = "heizung_waermepumpe_luft",
                                      cost_eur = node_const(1000))))
  fs <- list(instrument_type = "grant", measures = list("wp"),
             eligibility = list(applicants = list("privatperson"),
                                project_types = list("heizungstausch"),
                                measure_types = list("heizung_waermepumpe_luft"),
                                conditions = list(building_age_min_years = 5,
                                                  owner_occupied = "required",
                                                  wpb_definition = "Text"),
                                exclusions = list("Hinweis")))
  bctx <- list(value_base = function(path, shape = "scalar") NULL)
  chk <- fund_check_eligibility(x, "f", fs, bctx)
  expect_false(chk$eligible)
  expect_identical(vapply(chk$reasons, function(r) r$code, ""), "owner_occupied")
  expect_setequal(vapply(chk$open, function(r) r$code, ""), c("wpb_definition", "exclusion"))
  fs$unit_groups <- list("b")
  expect_true(fund_check_eligibility(x, "f", fs, bctx)$eligible)
  expect_identical(fund_n_units(x, fs, bctx), 2L)
  expect_identical(fund_n_units(x, list(), bctx), 6L)
  fs$eligibility_override <- TRUE
  fs$unit_groups <- NULL
  expect_true(fund_check_eligibility(x, "f", fs, bctx)$eligible)
  expect_identical(fund_applicant(x, list()), "privatperson_vermieter")
  expect_equal(fund_taxable_income_adj(x, list(child_u18_threshold_shift_eur = 10000)), 48000)
  expect_equal(fund_taxable_income_adj(x, list(child_u18_threshold_shift_eur = 10000,
                                               child_u18_threshold_shift_per_child = TRUE)),
               38000)
  expect_true(fund_replaced_fossil(x, list(), 20))
  lk <- fund_lookup(x, "f", list(facts = list(isfp = TRUE)))
  expect_true(lk("funding.this.isfp"))
  expect_false(lk("funding.this.qng"))
  expect_equal(lk("application_year"), 2026)
  expect_equal(lk("building.construction_year"), 1990)
  expect_null(lk("foo.bar"))
  x$funding <- list(f = fs, r = list(instrument_type = "rent_binding"))
  pl <- fund_plan(x, bctx)
  expect_identical(pl$f$component, "f_f_grant")
  expect_null(pl$r$component)
})

test_that("Expandertest (R-92): numerische Domänenblätter über Schicht 8 ändern keine Knoten", {
  x <- e2_scenario(perspective = "wu_kommunal", project_type = "heizungstausch",
                   application_date = "2027-01-15",
                   building = list(building_type = "MFH", construction_year = 1985L,
                                   n_units = 12L, living_area_m2 = 840, land_value_eur = 300000,
                                   heating_existing = list(carrier = "gas_mfh",
                                                           installation_year = 2002L),
                                   consumption_kwh = list(gas_mfh = 109200),
                                   property_tax = list(amount_eur_pa = 3000)),
                   unit_groups = list(g = list(n_units = 12L, living_area_m2 = 840,
                                               rent_eur_m2_month = 6.4)),
                   measures = list(wp = list(measure_type = "heizung_waermepumpe_luft",
                                             year = 2027, completion_date = "2027-10-01",
                                             cost_eur = 153560,
                                             modernization_kind = "bgb_555b_1a")),
                   energy = list(carriers = list(gas_mfh = list(emission_factor_kg_kwh = 0.181),
                                                 heatpump_power_mfh = list()),
                                 before = list(efficiency = 0.87),
                                 after = list(measure = "wp", demand_kwh = 95000,
                                              heating_carrier = "heatpump_power_mfh", jaz = 3.1)),
                   funding = list(kfw459 = list(from = "funding/kfw_459_heizung_unternehmen",
                                                measures = list("wp"),
                                                application_date = "2027-01-15",
                                                approval_timing = "before_start")),
                   residual_value = list(method = "income_value"),
                   variants = list(v = list(set = list(
                     "measures.wp.cost_eur" = 170000,
                     "unit_groups.g.rent_eur_m2_month" = 7.1,
                     "energy.after.jaz" = 2.8,
                     "energy.after.demand_kwh" = 90000,
                     "energy.before.efficiency" = 0.9,
                     "building.property_tax.amount_eur_pa" = 3500,
                     "building.land_value_eur" = 350000,
                     "funding.kfw459.payout_delay_months" = 6
                   ))))
  set.seed(42)
  s0 <- .Random.seed
  base <- e2_resolve(x)
  var <- e2_resolve(x, "v")
  expect_identical(.Random.seed, s0)
  from_exp <- vapply(base$components, function(c) identical(c$origin, "expander"), logical(1))
  ids <- names(base$components)[from_exp]
  expect_true(all(c("m_wp_capex", "u_g_rent", "u_g_property_tax", "e_after_heatpump_power_mfh_cost",
                    "e_before_gas_mfh_co2", "e_tenant", "f_kfw459_grant", "rv_value") %in% ids))
  for (id in ids) {
    expect_identical(var$components[[id]], base$components[[id]], info = id)
  }
  expect_identical(var$financing, base$financing)
})

test_that("Ende zu Ende S3 V2: Zuschuss, Umlage, PV, Mieterkosten, Saldo (Teil C S3)", {
  x <- e2_scenario(perspective = "wu_genossenschaft", project_type = "heizungstausch",
                   horizon_years = 20L, application_date = "2027-01-15",
                   building = list(building_type = "MFH", construction_year = 1985L,
                                   n_units = 12L, living_area_m2 = 840,
                                   heating_existing = list(carrier = "gas_mfh",
                                                           installation_year = 2002L),
                                   consumption_kwh = list(gas_mfh = 109200),
                                   maintenance = list(basis = "none")),
                   unit_groups = list(mitglieder = list(
                     n_units = 12L, living_area_m2 = 840, rent_regime = "cooperative_fee",
                     rent_eur_m2_month = 6.40, increase_policy = "fixed_growth",
                     rent_growth = 0.015, growth_from = "2028-01-01", vacancy_rate = 0.01,
                     rent_default_rate = 0,
                     rent_law = list(modernization_levy = "auto", voluntary_cap_per_m2 = 0.35,
                                     hardship_share = 0)
                   )),
                   measures = list(
                     heizung_wp = list(measure_type = "heizung_waermepumpe_luft", year = 2027,
                                       completion_date = "2027-10-01", cost_eur = 153560,
                                       ohnehin_cost_eur = 45360,
                                       modernization_kind = "bgb_555b_1a",
                                       useful_life_years = 20),
                     pv = list(measure_type = "pv", year = 2027, completion_date = "2027-01-01",
                               cost_eur = 38500, vat_rate = 0, useful_life_years = 25)
                   ),
                   energy = list(carriers = list(gas_mfh = list(emission_factor_kg_kwh = 0.181),
                                                 heatpump_power_mfh = list()),
                                 before = list(efficiency = 0.87, flow_temperature_c = 70,
                                               service_eur_pa = 714.28571429),
                                 after = list(measure = "heizung_wp", demand_kwh = 95000,
                                              heating_carrier = "heatpump_power_mfh", jaz = 3.1,
                                              jaz_plan = 3.1, flow_temperature_c = 55,
                                              service_eur_pa = 756.30252101),
                                 pv = list(kwp = 30, measure = "pv",
                                           commissioning_date = "2027-01-01",
                                           specific_yield_kwh_kwp = 900,
                                           self_consumption_share = 0.30, tariff_years = 20L,
                                           opex_share_of_cost = 0.015)),
                   funding = list(kfw459 = list(from = "funding/kfw_459_heizung_unternehmen",
                                                measures = list("heizung_wp"),
                                                application_date = "2027-01-15",
                                                approval_timing = "before_start",
                                                payout = list(lag_months = 3L),
                                                approval_probability = 1)),
                   financing = list(ek = list(type = "equity", amount_eur = 50000),
                                    bank = list(type = "annuity_loan", amount_eur = 142060,
                                                start = "2027-01-01", rate_pa = 0.039,
                                                term_years = 15, fixed_years = 15,
                                                payments_per_year = 1L)),
                   residual_value = list(method = "component", sale_cost_share = 0,
                                         component = list(indexed = FALSE)))
  spec <- e2_resolve(x)
  res <- e2_run(spec)
  expect_s3_class(res, "vofi_result")
  expect_equal(e2_row(res, "f_kfw459_grant__grant_heizung_wp")[1:3], c(0, 45300, 0))
  levy <- e2_row(res, "u_mitglieder_rent__levy_heizung_wp")
  expect_equal(levy[3:4], c(3528, 3528))
  expect_equal(e2_row(res, "e_pv__feed_in")[3L], 1324.26, tolerance = 1e-6)
  expect_equal(e2_row(res, "e_after_heatpump_power_mfh_cost__quantity")[3L], 95000 / 3.1)
  expect_true(all(abs(e2_row(res, "balance_check")) < 1e-6))
  expect_true(e2_row(res, "e_tenant__energy_pre")[3L] > e2_row(res, "e_tenant__energy")[3L])
  expect_true(e2_row(res, "rv_value__value")[21L] > 0)
})
