# Tests des Expanders funding (WS-E2, Spec 01 Teil B 4.1–4.12, F-1 bis F-17).

e2_s3_funding <- function(funding_extra = list(), measures_extra = list()) {
  e2_scenario(perspective = "wu_genossenschaft", project_type = "heizungstausch",
              application_date = "2027-01-15",
              building = list(building_type = "MFH", construction_year = 1985L, n_units = 12L,
                              living_area_m2 = 840, maintenance = list(basis = "none")),
              measures = utils::modifyList(list(
                wp = list(measure_type = "heizung_waermepumpe_luft", year = 2027,
                          completion_date = "2027-10-01", cost_eur = 153560, price_index = 0)
              ), measures_extra),
              funding = list(kfw459 = utils::modifyList(list(
                from = "funding/kfw_459_heizung_unternehmen", measures = list("wp"),
                application_date = "2027-01-15", approval_timing = "before_start",
                payout = list(lag_months = 3L), approval_probability = 1
              ), funding_extra)))
}

test_that("F-1/F-16: KfW 459 mit Staffeldeckel 151.000 und Auszahlung nach R-98", {
  spec <- e2_resolve(e2_s3_funding())
  g <- spec$components$f_kfw459_grant
  expect_identical(g$type, "grant")
  expect_identical(g$funding_id, "kfw459")
  expect_identical(g$program, "459")
  expect_identical(g$measure_id, "wp")
  expect_identical(g$measures, "wp")
  expect_identical(g$cost_components, "m_wp_capex")
  expect_identical(g$after, "m_wp_capex")
  expect_identical(g$rate, node_ref("funding.kfw459.rate_components.grund.rate"))
  expect_identical(g$rate_cap, node_ref("funding.kfw459.rate_cap.default"))
  expect_identical(g$cost_cap_eur, node_const(151000))
  expect_identical(g$approved, node_ref("funding.kfw459.approved"))
  expect_identical(g$payout_lag_months, 3L)
  expect_identical(g$payout_delay_months, node_ref("funding.kfw459.payout_delay_months"))
  expect_identical(g$application_date, as.Date("2027-01-15"))
  res <- e2_run(spec)
  expect_equal(e2_row(res, "f_kfw459_grant__grant_wp")[1:4], c(0, 45300, 0, 0))
  for (d in c(9, 12)) {
    res <- e2_run(e2_resolve(e2_s3_funding(list(payout_delay_months = d))))
    expect_equal(e2_row(res, "f_kfw459_grant__grant_wp")[1:4], c(0, 0, 45300, 0))
  }
})

test_that("F-4a: Degression auf einen entfernten Baustein entfällt mit Hinweis", {
  deg <- list(list(target = "rate_components.klimageschwindigkeit.rate", start = "2027-02-01",
                   step = -0.04, every_months = 6, floor = 0),
              list(target = "basis.eligible_cost_caps_per_building[1].cap_eur",
                   start = "2027-02-01", step = -750, every_months = 6, floor = 22000))
  r <- e2_resolve_full(e2_s3_funding(list(application_date = "2027-02-01", degression = deg)))
  expect_true("expand.funding.degression_target_removed" %in% r$messages)
  expect_identical(r$value$components$f_kfw459_grant$cost_cap_eur, node_const(150250))
  bad <- list(list(target = "basis.gibt_es_nicht", start = "2027-02-01", step = -1,
                   every_months = 6, floor = 0))
  e <- expect_error(e2_resolve(e2_s3_funding(list(degression = bad))),
                    class = "vofi_error_validation")
  expect_identical(e$key, "expand.funding.degression_target")
})

test_that("F-2/F-2a/F-3/F-4/F-5: KfW 458 Satzbausteine, Einkommensstaffel, Degression", {
  expect_equal(sum(e2_grant(e2_kfw458())), 15680)
  spec <- e2_resolve(e2_kfw458())
  g <- spec$components$f_kfw458_grant
  expect_identical(g$rate$text, paste0("funding.kfw458.rate_components.grund.rate + ",
                                       "funding.kfw458.rate_components.klimageschwindigkeit.rate",
                                       " + 0.1"))
  expect_identical(g$cost_cap_eur, node_const(28000))
  # F-2a: zvE 58.000, 2 Kinder -> 48.000 -> 0,10; je Kind -> 38.000 -> 0,30, Höchstsatz 0,70
  expect_equal(sum(e2_grant(e2_kfw458(taxable_income = 58000, kids = 2L))), 15680)
  pc <- list(rate_components = list(einkommen = list(schedule_by_taxable_income = list(
    child_u18_threshold_shift_per_child = TRUE
  ))))
  expect_equal(sum(e2_grant(e2_kfw458(taxable_income = 58000, kids = 2L, funding_extra = pc))),
               19600)
  # F-3: zvE 58.000, 1 Kind, Gaskessel 2008 (Alter 18) -> 0,40
  expect_equal(sum(e2_grant(e2_kfw458(taxable_income = 58000, kids = 1L,
                                      heating = list(carrier = "gas",
                                                     installation_year = 2008L)))), 11200)
  # F-4: Degression nach Antragsdatum
  expect_equal(sum(e2_grant(e2_kfw458(application_date = "2027-02-01"))), 14170)
  expect_equal(sum(e2_grant(e2_kfw458(application_date = "2028-08-01"))), 10000)
  expect_equal(sum(e2_grant(e2_kfw458(application_date = "2030-08-01"))), 8800)
  s4 <- e2_resolve(e2_kfw458(application_date = "2027-02-01"))
  expect_identical(s4$components$f_kfw458_grant$rate$text,
                   paste0("funding.kfw458.rate_components.grund.rate + ",
                          "pmax(funding.kfw458.rate_components.klimageschwindigkeit.rate + ",
                          "(-0.04), 0) + 0.1"))
  expect_identical(s4$components$f_kfw458_grant$cost_cap_eur, node_const(27250))
  # F-5: Höchstsatz-Ausnahme 0,80
  sp5 <- e2_resolve(e2_kfw458(taxable_income = 28000))
  expect_identical(sp5$components$f_kfw458_grant$rate_cap, node_const(0.8))
  expect_equal(sum(e2_grant(e2_kfw458(taxable_income = 28000))), 22400)
})

test_that("F-17: Klimageschwindigkeitsbonus für Gasetage und Kohle, nicht für Zentralgas", {
  floor_gas <- list(carrier = "gas", installation_year = 2016L, type = "floor")
  expect_equal(sum(e2_grant(e2_kfw458(taxable_income = 70000, heating = floor_gas))), 12880)
  coal <- e2_kfw458(taxable_income = 70000, heating = list(carrier = "kohle",
                                                           installation_year = 2016L))
  coal$energy <- list(carriers = list(kohle = list(class = "coal", price_eur_kwh = 0.09)))
  expect_equal(sum(e2_grant(coal)), 12880)
  central <- list(carrier = "gas", installation_year = 2016L, type = "central")
  expect_equal(sum(e2_grant(e2_kfw458(taxable_income = 70000, heating = central))), 8400)
  fact <- e2_kfw458(taxable_income = 70000, heating = central,
                    funding_extra = list(facts = list(heating_replaced_fossil_functional = TRUE)))
  expect_equal(sum(e2_grant(fact)), 12880)
})

test_that("F-6b: Antragsteller-Oberbegriff, Boni nur selbstgenutzt; KfW 297 nicht berechtigt", {
  ug <- list(g = list(n_units = 1L, living_area_m2 = 140, rent_eur_m2_month = 9))
  x <- e2_kfw458(perspective = "kleinvermieter", unit_groups = ug)
  expect_equal(sum(e2_grant(x)), 8400)
  x$funding$kfw297 <- list(from = "funding/kfw_297_khn_selbstnutzung", measures = list("wp"),
                           amount_eur = 50000, application_date = "2026-12-01")
  r <- e2_resolve_full(x)
  expect_true("expand.funding.not_eligible" %in% r$warnings)
  expect_false("f_kfw297_loan" %in% names(r$value$financing))
})

e2_bafa <- function(cost, isfp = TRUE, mode = NULL, measures = NULL) {
  fund <- list(from = "funding/bafa_beg_em_huelle", application_date = "2027-01-01",
               measures = as.list(names(measures %||% list(fassade = 1))),
               facts = list(isfp = isfp, energy_efficiency_expert = TRUE))
  if (!is.null(mode)) fund$rate_components <- list(isfp = list(mode = mode))
  ms <- measures %||% list(fassade = list(measure_type = "daemmung_fassade", year = 2028,
                                          completion_date = "2028-09-01", cost_eur = cost,
                                          price_index = 0))
  e2_scenario(perspective = "selbstnutzer", project_type = "sanierung_einzelmassnahmen",
              building = list(building_type = "EFH", construction_year = 1975L, n_units = 1L,
                              living_area_m2 = 140, maintenance = list(basis = "none"),
                              property_tax = list(amount_eur_pa = 600)),
              household = list(net_income_month_eur = 5000),
              measures = ms, funding = list(bafa = fund))
}

test_that("F-6/F-6a: BAFA Hülle mit iSFP-Bonus, Bonusbasis und Jahresdeckel", {
  spec <- e2_resolve(e2_bafa(85988.87))
  g <- spec$components$f_bafa_grant
  expect_identical(g$cost_cap_eur, node_const(60000))
  expect_identical(g$bonus_rate, node_ref("funding.bafa.rate_components.isfp.rate"))
  expect_identical(g$bonus_threshold_eur,
                   node_ref("funding.bafa.rate_components.isfp.threshold.single_unit_eur"))
  expect_identical(g$bonus_mode, "excess_over_threshold")
  expect_identical(g$cap_period, "calendar_year")
  expect_identical(g$payout_lag_months, 6L)
  expect_equal(sum(e2_grant(e2_bafa(85988.87), f = "bafa", m = "fassade")), 10500)
  expect_equal(sum(e2_grant(e2_bafa(85988.87, mode = "whole_amount"), f = "bafa",
                            m = "fassade")), 12000)
  expect_equal(sum(e2_grant(e2_bafa(85988.87, isfp = FALSE), f = "bafa", m = "fassade")), 4500)
  expect_equal(sum(e2_grant(e2_bafa(40000), f = "bafa", m = "fassade")), 6500)
  two <- function(y2) {
    ms <- list(fassade = list(measure_type = "daemmung_fassade", year = 2028,
                              completion_date = "2028-09-01", cost_eur = 40000, price_index = 0),
               fenster = list(measure_type = "fenster", year = y2,
                              completion_date = paste0(y2, "-09-01"), cost_eur = 30000,
                              price_index = 0))
    res <- e2_run(e2_resolve(e2_bafa(0, measures = ms)))
    c(sum(e2_row(res, "f_bafa_grant__grant_fassade")),
      sum(e2_row(res, "f_bafa_grant__grant_fenster")))
  }
  expect_equal(two(2028), c(6000, 4500))
  expect_equal(two(2029), c(6500, 4500))
})

e2_s1 <- function(funding_extra = list(), horizon = 4L) {
  e2_scenario(perspective = "wu_kommunal", project_type = "sanierung_eh",
              horizon_years = horizon, application_date = "2026-12-15",
              building = list(building_type = "MFH", construction_year = 1963L, n_units = 24L,
                              living_area_m2 = 1600, wpb_flag = TRUE,
                              efficiency_standard_after = "eh70",
                              maintenance = list(basis = "none")),
              measures = list(
                huelle = list(measure_type = "daemmung_fassade", year = 2027,
                              completion_date = "2027-10-01", cost_eur = 900000,
                              price_index = 0),
                heizung = list(measure_type = "heizung_waermepumpe_luft", year = 2027,
                               completion_date = "2027-10-01", cost_eur = 364000,
                               price_index = 0)
              ),
              funding = list(kfw261 = utils::modifyList(list(
                from = "funding/kfw_261_eh70", measures = list("huelle", "heizung"),
                application_date = "2026-12-15", amount_eur = 1300000,
                construction_support_eur = 36000, loan_variant = "v30_5_10",
                loan = list(payments_per_year = 1L),
                repayment_grant = list(payout = list(lag_months = 3L)),
                facts = list(ee_class = TRUE), approval_probability = 1
              ), funding_extra)))
}

test_that("F-7: KfW 261 EH 70 EE mit WPB-Bonus, Tilgungszuschuss 144.400 zum 2028-01-01", {
  spec <- e2_resolve(e2_s1())
  ln <- spec$financing$f_kfw261_loan
  expect_identical(ln$type, "annuity_loan")
  expect_identical(ln$funding_id, "kfw261")
  expect_identical(ln$program, "261")
  expect_identical(ln$measure_id, "huelle")
  expect_identical(ln$amount_eur, node_ref("funding.kfw261.amount_eur"))
  expect_identical(ln$rate_pa, node_ref("funding.kfw261.loan.variants.v30_5_10.rate_pa"))
  expect_equal(vapply(ln[c("term_years", "grace_years", "fixed_years")], exp_num, double(1)),
               c(term_years = 30, grace_years = 5, fixed_years = 10))
  expect_identical(ln$payments_per_year, 1L)
  expect_identical(ln$start, as.Date("2027-01-01"))
  expect_identical(ln$followup_rate_pa, node_ref("market.mortgage_rate"))
  expect_false(ln$prepay_allowed)
  expect_identical(ln$approved$text, paste0("funding.kfw261.approved * pmax(measures.huelle.",
                                            "active, measures.heizung.active)"))
  rg <- ln$repayment_grant
  expect_identical(rg$date, as.Date("2028-01-01"))
  expect_identical(rg$effect, "shorten_term")
  expect_equal(e2_value(spec, "financing.f_kfw261_loan.repayment_grant.share"),
               144400 / 1300000, tolerance = 1e-12)
  expect_equal(round(e2_value(spec, "financing.f_kfw261_loan.repayment_grant.share"), 7),
               0.1110769)
  res <- e2_run(spec)
  tz <- e2_row(res, "loan_f_kfw261_loan_repayment_grant")
  expect_equal(sum(tz), 144400)
  expect_equal(which(abs(tz) > 0) - 1L, 1L)
  # Bibliothekswert lag_months 6: Termin 2028-04-01 -> Periode 2028
  s6 <- e2_resolve(e2_s1(list(repayment_grant = list(payout = list(lag_months = 6L)))))
  expect_identical(s6$financing$f_kfw261_loan$repayment_grant$date, as.Date("2028-04-01"))
  # cut_share 0,5 -> 72.200
  sc <- e2_resolve(e2_s1(list(repayment_grant = list(cut_share = 0.5))))
  expect_identical(sc$financing$f_kfw261_loan$repayment_grant$cut_share,
                   node_ref("funding.kfw261.repayment_grant.cut_share"))
  expect_equal(sum(e2_row(e2_run(sc), "loan_f_kfw261_loan_repayment_grant")), 72200)
  # approved 0: keine Auszahlung, keine Gutschrift
  s0 <- e2_resolve(e2_s1(list(approved = 0)))
  r0 <- e2_run(s0)
  expect_equal(sum(e2_row(r0, "loan_f_kfw261_loan_repayment_grant")), 0)
  expect_equal(sum(e2_row(r0, "loan_f_kfw261_loan_draw")), 0)
})

test_that("Förderkredit ohne Zusagebetrag: Betrag aus Kostenschätzung mit Deckel (W)", {
  r <- e2_resolve_full(e2_s1(list(amount_eur = NULL)))
  expect_true("expand.funding.loan_amount_estimated" %in% r$warnings)
  # Deckel 150.000 · 24 WE > Kosten; Baubegleitung min(36.000, min(4.000 · 24, 40.000))
  expect_equal(e2_value(r$value, "financing.f_kfw261_loan.amount_eur"), 1264000 + 36000)
  s <- e2_resolve(e2_s1(list(amount_eur = NULL, construction_support_eur = 60000)))
  expect_equal(e2_value(s, "financing.f_kfw261_loan.amount_eur"), 1264000 + 40000)
})

test_that("KG-Filter (Teil B 4.2, 4.4): Außenanlagen KG 500 nicht förderfähig, Hinweis", {
  x <- e2_s1(list(amount_eur = NULL))
  x$funding$kfw261$measures <- list("huelle", "heizung", "aussen")
  x$measures$aussen <- list(measure_type = "aussenanlagen", year = 2027,
                            completion_date = "2027-10-01", cost_eur = 100000, price_index = 0)
  r <- e2_resolve_full(x)
  expect_true("expand.funding.kg_not_eligible" %in% r$messages)
  expect_true(any(grepl("aussen", r$texts, fixed = TRUE) & grepl("500", r$texts, fixed = TRUE)))
  s <- r$value
  expect_identical(s$measures$aussen$kg, 500L)
  expect_false(grepl("measures.aussen.cost_eur", s$financing$f_kfw261_loan$amount_eur$text,
                     fixed = TRUE))
  # Betrag 1.264.000 + 36.000; Tilgungszuschuss 0,10 · 1.264.000 + 0,5 · 36.000 = 144.400
  expect_equal(e2_value(s, "financing.f_kfw261_loan.amount_eur"), 1300000)
  expect_equal(sum(e2_row(e2_run(s), "loan_f_kfw261_loan_repayment_grant")), 144400)
  # ausdrücklicher Anteil gewinnt gegen den KG-Filter (kein Hinweis)
  x$funding$kfw261$eligible_shares <- list(aussen = 0.5)
  r2 <- e2_resolve_full(x)
  expect_false("expand.funding.kg_not_eligible" %in% r2$messages)
  expect_equal(e2_value(r2$value, "financing.f_kfw261_loan.amount_eur"), 1350000)
  # Zuschuss: Anteil 0 als Parameter des Typs grant, Zeile grant_<m> = 0
  g <- e2_s3_funding(measures_extra = list(aussen = list(measure_type = "aussenanlagen",
                                                         year = 2027,
                                                         completion_date = "2027-10-01",
                                                         cost_eur = 50000, price_index = 0)))
  g$funding <- list(zs = list(instrument_type = "grant", measures = list("wp", "aussen"),
                              application_date = "2027-01-15", approval_timing = "before_start",
                              basis = list(eligible_cost_kg = list(300, 400)),
                              rate_components = list(grund = list(rate = 0.3)),
                              payout = list(lag_months = 3L)))
  rg <- e2_resolve_full(g)
  expect_true("expand.funding.kg_not_eligible" %in% rg$messages)
  gc <- rg$value$components$f_zs_grant
  expect_identical(gc$eligible_shares, list(aussen = node_const(0)))
  res <- e2_run(rg$value)
  expect_equal(sum(e2_row(res, "f_zs_grant__grant_wp")), 0.3 * 153560)
  expect_equal(sum(e2_row(res, "f_zs_grant__grant_aussen")), 0)
})

test_that("Degression auf Sequenzelemente außerhalb von basis (Teil B 4.3.3)", {
  # rate_cap.exceptions[1].cap: 0,8 - 0,2 = 0,6 -> 0,6 · 28.000 = 16.800 (statt 22.400)
  deg_cap <- list(list(target = "rate_cap.exceptions[1].cap", start = "2026-01-01",
                       step = -0.2, every_months = 120, floor = 0.5))
  x <- e2_kfw458(taxable_income = 28000, funding_extra = list(degression = deg_cap))
  s <- e2_resolve(x)
  expect_equal(exp_num(s$components$f_kfw458_grant$rate_cap), 0.6, tolerance = 1e-12)
  expect_equal(sum(e2_grant(x)), 16800)
  # Zahlenreihe der Einkommensstaffel: rates[3] 0,10 -> 0,05 -> 0,51 · 28.000 = 14.280
  deg_rate <- list(list(target = "rate_components.einkommen.schedule_by_taxable_income.rates[3]",
                        start = "2026-01-01", step = -0.05, every_months = 120, floor = 0))
  y <- e2_kfw458(funding_extra = list(degression = deg_rate))
  expect_match(e2_resolve(y)$components$f_kfw458_grant$rate$text, "+ 0.05$")
  expect_equal(sum(e2_grant(y)), 14280)
  # Index außerhalb der Sequenz bleibt ein Fehler
  bad <- list(list(target = "rate_components.einkommen.schedule_by_taxable_income.rates[9]",
                   start = "2026-01-01", step = -0.05, every_months = 120, floor = 0))
  e <- expect_error(e2_resolve(e2_kfw458(funding_extra = list(degression = bad))),
                    class = "vofi_error_validation")
  expect_identical(e$key, "expand.funding.degression_target")
  # Degression ohne Untergrenze: Ausdruck geklammert (Vorrang bei Multiplikation mit N_f)
  fl <- list(list(target = "basis.cap_mfh_per_unit_eur", start = "2026-01-01", step = -100,
                  every_months = 120))
  expect_identical(fund_degression(list(project = list()), "f",
                                   list(degression = fl, application_date = "2027-01-01",
                                        basis = list(cap_mfh_per_unit_eur = 1)),
                                   list(rule = function(n) rule_fund_degression_fun,
                                        inform = function(...) NULL,
                                        abort = function(...) stop("abort")))$leaf[[
                                          "basis.cap_mfh_per_unit_eur"]]("p"),
                   "(p + (-100))")
})

test_that("Meldungen: fehlendes Einkommen in einer Bedingung (taxable_income_missing)", {
  ug <- list(g = list(n_units = 1L, living_area_m2 = 140, rent_eur_m2_month = 9))
  x <- e2_kfw458(perspective = "kleinvermieter", unit_groups = ug)
  x$household$taxable_income_avg_eur <- NULL
  e <- expect_error(e2_resolve(x), class = "vofi_error_validation")
  expect_identical(e$key, "expand.funding.taxable_income_missing")
})

test_that("F-13: KfW 300 Berechtigung (Einkommen, Kinder, lca_thg) und Kreditdeckel", {
  k300 <- function(income, facts = list()) {
    e2_scenario(perspective = "selbstnutzer", project_type = "neubau", horizon_years = 4L,
                grid = list(construction_months = 12L), application_date = "2026-12-15",
                building = list(building_type = "EFH", construction_year = 2027L, n_units = 1L,
                                living_area_m2 = 140, efficiency_standard_after = "eh40",
                                maintenance = list(basis = "none"),
                                property_tax = list(amount_eur_pa = 600)),
                household = list(taxable_income_avg_eur = income, n_children_u18 = 2L,
                                 net_income_month_eur = 6300),
                measures = list(bau = list(measure_type = "neubau", date = "2027-01-01",
                                           completion_date = "2028-01-01", cost_eur = 420000,
                                           price_index = 0)),
                funding = list(kfw300 = list(from = "funding/kfw_300_wohneigentum_familien",
                                             measures = list("bau"),
                                             application_date = "2026-12-15", facts = facts)))
  }
  r <- e2_resolve_full(k300(105000, list(lca_thg = TRUE)))
  expect_true("expand.funding.not_eligible" %in% r$warnings)
  expect_false("f_kfw300_loan" %in% names(r$value$financing))
  s <- e2_resolve(k300(85000, list(lca_thg = TRUE)))
  expect_equal(e2_value(s, "financing.f_kfw300_loan.amount_eur"), 170000)
  expect_identical(s$financing$f_kfw300_loan$rate_pa,
                   node_ref("funding.kfw300.loan.variants.v35_5_10.rate_pa"))
  q <- e2_resolve(k300(85000, list(lca_thg = TRUE, qng = TRUE)))
  expect_equal(e2_value(q, "financing.f_kfw300_loan.amount_eur"), 220000)
  r <- e2_resolve_full(k300(85000))
  expect_true("expand.funding.not_eligible" %in% r$warnings)
  expect_true(any(grepl("lca_thg", r$texts, fixed = TRUE)))
})

test_that("F-8: § 35c als Komponente f_<f>_35c mit Deckel durch die Einkommensteuer", {
  x <- e2_scenario(perspective = "selbstnutzer", project_type = "sanierung_einzelmassnahmen",
                   horizon_years = 6L,
                   building = list(building_type = "EFH", construction_year = 1975L,
                                   n_units = 1L, living_area_m2 = 140,
                                   maintenance = list(basis = "none"),
                                   property_tax = list(amount_eur_pa = 600)),
                   household = list(net_income_month_eur = 5000, expected_income_tax_eur_pa = 4000),
                   measures = list(dach = list(measure_type = "daemmung_dach_steil",
                                               year = 2028, completion_date = "2028-06-01",
                                               cost_eur = 80000, price_index = 0,
                                               contractor_certified = TRUE)),
                   funding = list(st = list(from = "funding/estg_35c", measures = list("dach"),
                                            application_date = "2028-01-01",
                                            facts = list(contractor_certified = TRUE))))
  spec <- e2_resolve(x)
  t <- spec$components$f_st_35c
  expect_identical(t$type, "tax_credit_35c")
  expect_equal(vapply(t[c("share_y1", "share_y2", "share_y3")], exp_num, double(1)),
               c(share_y1 = 0.07, share_y2 = 0.07, share_y3 = 0.06))
  expect_identical(t$total_share, node_ref("funding.st.credit.total_share"))
  expect_identical(t$cap_total_eur, node_ref("funding.st.credit.cap_per_object_eur"))
  expect_identical(t$income_tax_cap_eur_pa, node_ref("household.expected_income_tax_eur_pa"))
  expect_identical(t$completion_before, as.Date("2030-01-01"))
  expect_identical(t$payout_delay_months, node_ref("funding.st.payout_delay_months"))
  res <- e2_capture(e2_run(spec))$value
  expect_equal(e2_row(res, "f_st_35c__credit_dach")[1:7], c(0, 0, 0, 4000, 4000, 4000, 0))
  reg <- Filter(function(m) identical(m$measure_id, "dach"), spec$registers$measures)[[1L]]
  expect_identical(reg$funding_choice, "35c")
})

test_that("F-12: Kumulierung (Ausschluss über program_code, Voraussetzung)", {
  x <- e2_kfw458()
  x$funding$st <- list(from = "funding/estg_35c", measures = list("wp"),
                       facts = list(contractor_certified = TRUE))
  e <- expect_error(e2_resolve(x), class = "vofi_error_validation")
  expect_identical(e$key, "expand.funding.cumulation_exclusive")
  y <- e2_kfw458()
  y$funding <- list(st = list(from = "funding/estg_35c", measures = list("wp"),
                              facts = list(contractor_certified = TRUE)),
                    eigen = list(instrument_type = "grant", program_code = "458",
                                 measures = list("wp"),
                                 rate_components = list(grund = list(rate = 0.2))))
  e <- expect_error(e2_resolve(y), class = "vofi_error_validation")
  expect_identical(e$key, "expand.funding.cumulation_exclusive")
  z <- e2_kfw458()
  z$funding <- list(k358 = list(from = "funding/kfw_358_ergaenzungskredit_plus",
                                measures = list("wp"), amount_eur = 20000,
                                application_date = "2026-12-01"))
  r <- e2_resolve_full(z)
  expect_true("expand.funding.cumulation_requires" %in% r$warnings)
  expect_true("f_k358_loan" %in% names(r$value$financing))
  ok <- e2_kfw458()
  ok$funding$k358 <- list(from = "funding/kfw_358_ergaenzungskredit_plus",
                          measures = list("wp"), amount_eur = 20000,
                          application_date = "2026-12-01")
  r <- e2_resolve_full(ok)
  expect_false("expand.funding.cumulation_requires" %in% r$warnings)
})

test_that("F-14: Zinsverbilligung als laufender Zuschuss +1.000 je Jahr 2028–2037", {
  x <- e2_scenario(horizon_years = 12L,
                   building = list(building_type = "MFH", construction_year = 1975L,
                                   n_units = 12L, living_area_m2 = 900,
                                   maintenance = list(basis = "none")),
                   measures = list(m = list(measure_type = "fenster", year = 2027,
                                            cost_eur = 100000, price_index = 0)),
                   funding = list(zv = list(instrument_type = "interest_subsidy",
                                            measures = list("m"),
                                            interest_subsidy = list(
                                              subsidized_amount_eur = 100000,
                                              rate_reduction_pa = 0.01, years = 10L,
                                              start_event = "2028-01-01"
                                            ))))
  spec <- e2_resolve(x)
  s <- spec$components$f_zv_subsidy
  expect_identical(s$type, "recurring")
  expect_identical(s$category, "operating_subsidy")
  expect_identical(s$start_event, as.Date("2028-01-01"))
  expect_identical(s$to, as.Date("2038-01-01"))
  res <- e2_run(spec)
  v <- e2_row(res, "f_zv_subsidy__value")
  expect_equal(v, c(0, 0, rep(1000, 10), 0))
})

test_that("F-10/F-11: drop_measures setzt a_m = 0, balance nur den Zuschuss (je Lauf)", {
  run <- function(on_reject) {
    x <- e2_kfw458(funding_extra = list(on_reject = on_reject))
    spec <- e2_resolve(x)
    comps <- spec$components[c("m_wp_capex", "f_kfw458_grant")]
    names(comps) <- c("c_wp", "g")
    comps$g$cost_components <- "c_wp"
    comps$g$after <- "c_wp"
    dom <- list(measures = spec$measures, funding = spec$funding, project = spec$project)
    e2_type_build(comps, n = 2L, static = list("funding.kfw458.approved" = c(1, 0)),
                  domain_spec = dom)
  }
  d <- run("drop_measures")
  expect_equal(rowSums(d$g$rows[[1L]]$values), c(15680, 0))
  expect_equal(rowSums(d$c_wp$rows[[1L]]$values), c(-32000, 0))
  b <- run("balance")
  expect_equal(rowSums(b$g$rows[[1L]]$values), c(15680, 0))
  expect_equal(rowSums(b$c_wp$rows[[1L]]$values), c(-32000, -32000))
})

test_that("Zusage: höchstens ein Entscheidungsknoten; Fehlerfälle der Instrumente", {
  x <- e2_kfw458(funding_extra = list(approval_timing = "before_start",
                                      fallback_variant = "ohne"))
  x$funding$zweit <- list(instrument_type = "grant", measures = list("wp"),
                          approval_timing = "before_start", fallback_variant = "ohne",
                          rate_components = list(grund = list(rate = 0.1)))
  x$variants <- list(ohne = list(remove = list("funding.kfw458", "funding.zweit")))
  e <- expect_error(e2_resolve(x), class = "vofi_error_validation")
  expect_identical(e$key, "expand.funding.decision_nodes")
  # nicht förderfähiger Maßnahmentyp
  y <- e2_kfw458()
  y$measures$wp$measure_type <- "heizung_gaskessel"
  e <- expect_error(e2_resolve(y), class = "vofi_error_validation")
  expect_identical(e$key, "expand.funding.measure_type")
  # unbekannte Kreditvariante
  z <- e2_s1(list(loan_variant = "v99"))
  e <- expect_error(e2_resolve(z), class = "vofi_error_validation")
  expect_identical(e$key, "expand.funding.loan_variant_unknown")
  # Instrument-id höchstens 30 Zeichen
  w <- e2_kfw458()
  names(w$funding) <- strrep("f", 31L)
  e <- expect_error(e2_resolve(w), class = "vofi_error_validation")
  expect_identical(e$key, "expand.funding.id_too_long")
  # Instrument ohne Art: kein Baustein (Validierung meldet den Fehler)
  v <- e2_kfw458()
  v$funding$leer <- list(measures = list("wp"))
  sv <- e2_resolve(v)
  expect_false(any(startsWith(c(names(sv$components), names(sv$financing)), "f_leer_")))
})

test_that("Bedingungsausdrücke: Grammatik, Symbole, Fehler (fund_eval_condition)", {
  lk <- function(s) switch(s, a.b = 1, c.d = "eh40", e.f = TRUE, NULL)
  expect_true(fund_eval_condition("a.b == 1 & c.d == 'eh40'", lk))
  expect_true(fund_eval_condition("!(a.b > 2) | e.f", lk))
  expect_true(fund_eval_condition("c.d %in% c('eh40', 'eh55')", lk))
  expect_false(fund_eval_condition("a.b + 1 >= 3", lk))
  expect_error(fund_eval_condition("x.y == 1", lk), class = "vofi_error_validation")
  expect_error(fund_eval_condition("a.b ==", lk), class = "vofi_error_validation")
  expect_error(fund_eval_condition("system('x')", lk), class = "vofi_error_validation")
})

# ---------------------------------------------------------------------------------------------
# Ende zu Ende über vofi_resolve()/vofi_build()/vofi_run() (Teil C S1, S4, S5; Prüfwerte)
# ---------------------------------------------------------------------------------------------

test_that("Ende zu Ende S4 V1: KfW 458, BAFA 2030/2033 und KfW 358 (S4-T2, T4, T7)", {
  bafa <- function(m, ad, ...) {
    c(list(from = "funding/bafa_beg_em_huelle", measures = list(m), application_date = ad,
           payout = list(lag_months = 12L), facts = list(energy_efficiency_expert = TRUE)),
      list(...))
  }
  x <- e2_scenario(
    perspective = "selbstnutzer", project_type = "sanierung_stufenweise", horizon_years = 8L,
    application_date = "2026-12-15",
    building = list(building_type = "EFH", construction_year = 1975L, n_units = 1L,
                    living_area_m2 = 140, isfp_available = TRUE,
                    heating_existing = list(carrier = "gas", installation_year = 2005L),
                    maintenance = list(basis = "none"), property_tax = list(amount_eur_pa = 600)),
    household = list(taxable_income_avg_eur = 58000, n_children_u18 = 1L,
                     net_income_month_eur = 4800),
    unit_groups = list(haus = list(n_units = 1L, living_area_m2 = 140, owner_occupied = TRUE)),
    # Ausführungskosten S4-T3 (Kostenstand mit Index bereits eingerechnet, price_index 0)
    measures = list(
      wp_2027 = list(measure_type = "heizung_waermepumpe_luft", year = 2027, cost_eur = 32960,
                     price_index = 0, useful_life_years = 20,
                     replacement = list(enabled = FALSE)),
      dach_fenster_2030 = list(measure_type = "daemmung_dach_steil", year = 2030,
                               cost_eur = 85988.87, price_index = 0, useful_life_years = 45),
      fassade_2033 = list(measure_type = "daemmung_fassade", year = 2033, cost_eur = 55405.82,
                          price_index = 0, useful_life_years = 40)),
    funding = list(
      kfw458_wp = list(from = "funding/kfw_458_heizung_privat", measures = list("wp_2027"),
                       application_date = "2026-12-15", payout = list(lag_months = 12L),
                       approval_probability = 1),
      bafa_2030 = bafa("dach_fenster_2030", "2029-12-01", approval_probability = 1),
      bafa_2033 = bafa("fassade_2033", "2032-12-01", approval_timing = "after_start",
                       approval_probability = 0.7, on_reject = "balance"),
      kfw358_2030 = list(from = "funding/kfw_358_ergaenzungskredit_plus",
                         measures = list("dach_fenster_2030"), application_date = "2029-12-01",
                         amount_eur = 70000, loan_variant = "v25_3_10",
                         loan = list(payments_per_year = 1L), approval_probability = 1)),
    financing = list(ek = list(type = "equity", amount_eur = 200000)))
  r <- e2_resolve_full(x)
  expect_true("expand.funding.annual_cap_shared" %in% r$warnings)
  res <- e2_run(r$value)
  expect_s3_class(res, "vofi_result")
  # S4-T2: 0,56 · 28.000 zum Termin 2028-01-01 -> t = 1
  expect_equal(e2_row(res, "f_kfw458_wp_grant__grant_wp_2027")[1:3], c(0, 15680, 0))
  # S4-T4: BAFA 2030 (Termin 2031-01-01 -> t = 4) und 2033 (Termin 2034-01-01 -> t = 7)
  b30 <- e2_row(res, "f_bafa_2030_grant__grant_dach_fenster_2030")
  expect_equal(b30[5L], 10500)
  expect_equal(sum(b30), 10500)
  b33 <- e2_row(res, "f_bafa_2033_grant__grant_fassade_2033")
  expect_equal(b33[8L], 9581.16, tolerance = 1e-6)
  expect_equal(sum(b33), b33[8L])
  # S4-T7: KfW 358 (2030), 70.000 zu 2,53 %: Zinsen 2030-2032 1.771, Annuität ab 2033 4.188,12
  zins <- e2_row(res, "loan_f_kfw358_2030_loan_interest")
  expect_equal(zins[5:7], rep(-1771, 3L), tolerance = 1e-9)
  ann <- zins[8L] + e2_row(res, "loan_f_kfw358_2030_loan_repay")[8L]
  expect_equal(ann, -4188.12, tolerance = 1e-6)
  expect_equal(e2_row(res, "loan_f_kfw358_2030_loan_draw")[4L], 70000)
  expect_true(all(abs(e2_row(res, "balance_check")) < 1e-6))
})

test_that("Ende zu Ende S1 V2: Beschlussumlage 21.120 mit KfW 261 (S1-T3, S1-T6)", {
  x <- e2_scenario(
    perspective = "wu_kommunal", project_type = "sanierung_eh", horizon_years = 4L,
    application_date = "2026-12-15",
    building = list(building_type = "MFH", construction_year = 1963L, n_units = 24L,
                    living_area_m2 = 1600, wpb_flag = TRUE, efficiency_standard_after = "eh70",
                    maintenance = list(basis = "none")),
    unit_groups = list(bestand = list(
      n_units = 24L, living_area_m2 = 1600, rent_regime = "paragraph_558",
      rent_eur_m2_month = 6.2, increase_policy = "fixed_growth", rent_growth = 0.015,
      growth_from = "2029-01-01", vacancy_rate = 0.01, rent_default_rate = 0.01,
      rent_law = list(modernization_levy = "auto", voluntary_cap_per_m2 = 1.10,
                      hardship_share = 0))),
    measures = list(
      huelle = list(measure_type = "daemmung_fassade", year = 2027,
                    completion_date = "2027-10-01", cost_eur = 990580.50,
                    ohnehin_cost_eur = 447982.50, price_index = 0,
                    modernization_kind = "bgb_555b_1", useful_life_years = 40),
      heizung = list(measure_type = "heizung_waermepumpe_luft", year = 2027,
                     completion_date = "2027-10-01", cost_eur = 371700,
                     ohnehin_cost_eur = 129202.50, price_index = 0,
                     modernization_kind = "bgb_555b_1a", rent_law = list(procedure = "bgb_559"),
                     useful_life_years = 20),
      lueftung = list(measure_type = "lueftung_dezentral", year = 2027,
                      completion_date = "2027-10-01", cost_eur = 89208, ohnehin_cost_eur = 0,
                      price_index = 0, modernization_kind = "bgb_555b_1",
                      useful_life_years = 20)),
    funding = list(kfw261 = list(
      from = "funding/kfw_261_eh70", measures = list("huelle", "heizung", "lueftung"),
      application_date = "2026-12-15", amount_eur = 1300000, construction_support_eur = 36000,
      loan_variant = "v30_5_10", loan = list(payments_per_year = 1L),
      repayment_grant = list(payout = list(lag_months = 3L)), facts = list(ee_class = TRUE),
      approval_probability = 1)),
    financing = list(ek = list(type = "equity", amount_eur = 151488.50)))
  spec <- e2_resolve(x)
  rp <- spec$components$u_bestand_rent
  expect_setequal(rp$levy_rows, c("huelle", "heizung", "lueftung"))
  expect_identical(rp$funding_ids, "kfw261")
  res <- e2_run(spec)
  expect_equal(sum(e2_row(res, "loan_f_kfw261_loan_repayment_grant")), 144400)
  keys <- res$ledger$rows$key
  levy <- Reduce(`+`, lapply(keys[startsWith(keys, "u_bestand_rent__levy_")],
                             function(k) e2_row(res, k)))
  # Beschluss 1,10 €/m² · 1.600 m² · 12 ab 2028-01-01 (t = 2)
  expect_equal(levy[1:5], c(0, 0, 21120, 21120, 21120), tolerance = 1e-9)
})

test_that("Ende zu Ende S5 V1/V2: KfW 297 bzw. KfW 300 und Strommenge (S5-T8, S5-T9)", {
  x <- e2_scenario(
    perspective = "selbstnutzer", project_type = "neubau", horizon_years = 6L,
    application_date = "2026-12-15", grid = list(construction_months = 12L),
    building = list(building_type = "EFH", construction_year = 2027L, n_units = 1L,
                    living_area_m2 = 140, efficiency_standard_after = "eh55",
                    maintenance = list(basis = "none"), property_tax = list(amount_eur_pa = 600)),
    household = list(taxable_income_avg_eur = 85000, n_children_u18 = 2L,
                     net_income_month_eur = 6300),
    unit_groups = list(haus = list(n_units = 1L, living_area_m2 = 140, owner_occupied = TRUE)),
    measures = list(
      bauwerk = list(measure_type = "neubau", date = "2027-01-01",
                     completion_date = "2028-01-01", cost_eur = 420000, price_index = 0),
      nebenkosten = list(measure_type = "baunebenkosten", date = "2027-01-01",
                         completion_date = "2028-01-01", cost_eur = 95400, price_index = 0)),
    energy = list(carriers = list(power = list(base_fee_eur_pa = 100.84033613)),
                  after = list(demand_kwh = 7000, heating_carrier = "power",
                               heat_pump_carrier = "power", jaz = 3.5, flow_temperature_c = 35,
                               extra_consumption = list(haushalt = list(carrier = "power",
                                                                        kwh_pa = 3500)))),
    funding = list(kfw297 = list(from = "funding/kfw_297_khn_eh55_stufe",
                                 measures = list("bauwerk", "nebenkosten"),
                                 application_date = "2026-12-15", amount_eur = 100000,
                                 loan_variant = "v35_5_10", loan = list(payments_per_year = 12L),
                                 approval_probability = 1)),
    financing = list(ek = list(type = "equity", amount_eur = 600000)),
    variants = list(v2 = list(
      remove = list("funding.kfw297"),
      set = list("building.efficiency_standard_after" = "eh40",
                 "energy.after.demand_kwh" = 4900, "energy.after.jaz" = 3.8),
      add = list("energy.after.extra_consumption.lueftung" = list(carrier = "power",
                                                                  kwh_pa = 400),
                 "funding.kfw300" = list(from = "funding/kfw_300_wohneigentum_familien",
                                         measures = list("bauwerk", "nebenkosten"),
                                         application_date = "2026-12-15", amount_eur = 170000,
                                         loan_variant = "v35_5_10",
                                         loan = list(payments_per_year = 12L),
                                         facts = list(lca_thg = TRUE),
                                         approval_probability = 1)))))
  r1 <- e2_run(e2_resolve(x))
  # V1: WP-Strom 7.000 / 3,5 + Haushalt 3.500 ab Bezug 2028 (t = 2); KfW 297 2,19 % auf 100.000
  expect_equal(e2_row(r1, "e_after_power_cost__quantity")[1:4], c(0, 0, 5500, 5500))
  expect_equal(e2_row(r1, "loan_f_kfw297_loan_interest")[2:6], rep(-2190, 5L),
               tolerance = 1e-9)
  r2 <- e2_run(e2_resolve(x, "v2"))
  # V2: 4.900 / 3,8 + 400 Lüftung + 3.500 Haushalt = 5.189,47 kWh; KfW 300 1,00 % auf 170.000
  expect_equal(e2_row(r2, "e_after_power_cost__quantity")[3L], 4900 / 3.8 + 3900)
  expect_equal(round(e2_row(r2, "e_after_power_cost__quantity")[3L], 2), 5189.47)
  expect_equal(e2_row(r2, "loan_f_kfw300_loan_interest")[2:6], rep(-1700, 5L),
               tolerance = 1e-9)
  expect_null(e2_row(r2, "loan_f_kfw297_loan_interest"))
})
