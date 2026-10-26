# Tests für R/type-flow-rent-path.R (WS-E; Spec 01 Teil B Abschnitte 1.7-1.15, Prüfwerte RP-*,
# L-2, S1-T4/T4a/T5/T6, S3-T3/T4).

expect_eur <- function(actual, expected, tol = 0.006) {
  testthat::expect_true(all(abs(actual - expected) <= tol),
                        info = paste("ist:", paste(format(actual, nsmall = 4), collapse = " "),
                                     "soll:", paste(expected, collapse = " ")))
}

test_that("Vertragstests rent_path (Prüfkit 5.6)", {
  expect_type_contract("rent_path", "flow")
})

test_that("Monatsindex mi() und Kalenderjahresspalten (Teil B 0.4)", {
  g <- make_grid(T = 3L)
  expect_identical(rp_mi(g, as.Date(c("2027-01-01", "2027-03-01", "2027-09-15", "2026-06-01"))),
                   c(1, 3, 10, -6))
  expect_identical(rp_mi_floor(g, as.Date(c("2027-09-15", "2027-10-01"))), c(9, 10))
  gm <- make_grid("mixed")
  expect_identical(rp_year_col(gm, c(2026L, 2027L, 2028L, 2040L)),
                   c(2L, 2L, 12L, length(gm$year)))
  mo <- rp_months(g)
  expect_identical(mo$year[c(1, 12, 13)], c(2027L, 2027L, 2028L))
  expect_identical(mo$moy[c(1, 12, 13)], c(1L, 12L, 1L))
})

test_that("RP-4: feste Steigerung, Leerstand und Forderungsausfall (S1 V1)", {
  res <- eop_rp(unit_group = "g", living_area_m2 = 1600, n_units = 24L, rent_eur_m2_month = 6.2,
                increase_policy = "fixed_growth", rent_growth = 0.015,
                growth_from = "2028-01-01", vacancy_rate = 0.03, rent_default_rate = 0.01)
  expect_eur(eop_years(res, "rent", 2027:2031),
             c(119040.00, 120825.60, 122637.98, 124477.55, 126344.72))
  expect_eur(eop_years(res, "rent_loss", 2027:2028), c(-4725.89, -4796.78))
  expect_vofi_flows_contract(res$flows, res$ctx, reg_get("flow", "rent_path"))
  expect_equal(res$flows$aux$vacant_share[1, 2], 0.03)
})

test_that("RP-1: § 558-Erhöhungen mit Kappung 15 %, Umlage und Vergleichsmietenzuschlag", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 11L, construction_months = 120L,
                      construction_step_months = 1L)
  meas <- list(k = list(modernization_kind = "bgb_555b_1", cost_eur = 21000,
                        completion_date = "2027-03-01",
                        rent_law = list(ovm_uplift_eur_m2_month = 1.2,
                                        levy_effective_date = "2027-03-01")))
  res <- eop_rp(unit_group = "g", living_area_m2 = 70, n_units = 1L, rent_eur_m2_month = 7.5,
                ovm_eur_m2_month = 8, rent_growth = 0.025, kappung_15_area = TRUE,
                rent_36m_ago_eur_m2_month = 7.5, last_558_increase_date = "2026-06-01",
                increase_policy = "max", rent_law_measures = list("k"), levy_rows = list("k"),
                .measures = meas, .grid = g)
  lvl <- res$flows$aux$rent_level[1, -1L]
  expect_equal(lvl[3], 9.5)
  expect_equal(res$flows$aux$ovm_level[1, 4], 9.2 * 1.025^(3 / 12))
  ups <- which(diff(lvl) > 1e-9) + 1L
  expect_identical(ups[1L], 3L)
  ups <- ups[ups > 3L & ups <= 120L]
  expect_identical(ups, c(16L, 31L, 46L, 61L, 76L, 91L, 106L))
  expect_equal(round(lvl[ups], 4), c(9.5079, 9.8060, 10.1134, 10.4304, 10.7574, 11.0946,
                                     11.4424))
  expect_eur(eop_years(res, "rent", 2027:2030), c(6300.00, 6305.00, 6431.85, 6621.58))
  expect_eur(eop_years(res, "levy_k", 2027:2029), c(1400, 1680, 1680))
})

test_that("RP-2: Kappungsgrenze 20 % bzw. 15 % und Wartefrist", {
  run <- function(k15) {
    eop_rp(unit_group = "g", living_area_m2 = 1, n_units = 1L, rent_eur_m2_month = 6,
           ovm_eur_m2_month = 8, rent_growth = 0, rent_36m_ago_eur_m2_month = 6,
           last_558_increase_date = "2025-01-01", increase_policy = "max",
           kappung_15_area = k15)
  }
  r20 <- run(FALSE)$flows$aux$rent_level[1, -1L]
  expect_equal(r20[1:4], c(7.2, 7.2, 7.2, 8.0))
  r15 <- run(TRUE)$flows$aux$rent_level[1, -1L]
  expect_equal(r15[1:7], c(6.9, 6.9, 6.9, 7.935, 7.935, 7.935, 8.0))
})

test_that("RP-3: Kürzungsbetrag nach § 558 Abs. 5 aus einem Zuschuss", {
  g <- make_grid(T = 10L)
  meas <- list(k = list(modernization_kind = "bgb_555b_1", cost_eur = 50000,
                        completion_date = "2027-01-01"))
  res <- eop_rp(unit_group = "g", living_area_m2 = 70, n_units = 1L, rent_eur_m2_month = 7,
                ovm_eur_m2_month = 9, rent_growth = 0, rent_36m_ago_eur_m2_month = 7,
                last_558_increase_date = "2025-01-01", increase_policy = "max",
                rent_law_measures = list("k"), grant_components = list("f_x_grant"),
                after = list("f_x_grant"), .measures = meas,
                .deps = list(f_x_grant = eop_grant_flows(1L, g, "k", 10500)), .grid = g)
  expect_equal(res$flows$aux$kuerzung_level[1, 2], 1.00)
  expect_equal(res$flows$aux$rent_level[1, 2:3], c(7.4, 7.4))
  expect_true(res$flows$aux$rent_level[1, 5] > 7.4)
  expect_null(eop_row(res$flows, "levy_k"))
})

test_that("RP-5 und RP-15: Umlage mit Beschluss 1,10 EUR/m², Aktivierungsfaktor je Lauf", {
  meas <- list(k = list(modernization_kind = "bgb_555b_1", cost_eur = 673028.5,
                        completion_date = "2027-10-01", ohnehin_share = 0, active = 1))
  args <- list(unit_group = "g", living_area_m2 = 1600, n_units = 24L, rent_eur_m2_month = 6.2,
               increase_policy = "fixed_growth", rent_growth = 0.015,
               growth_from = "2029-01-01", growth_applies_to = "total",
               rent_law_measures = list("k"), levy_rows = list("k"))
  res <- do.call(eop_rp, c(args, list(voluntary_cap_per_m2 = 1.10, .measures = meas)))
  expect_eur(eop_years(res, "levy_k", 2028:2031), rep(21120, 4))
  expect_eur(eop_years(res, "rent", 2027:2031),
             c(119040.00, 119040.00, 121142.40, 123276.34, 125442.28))
  aux <- res$flows$aux
  expect_eur(aux$levy_k_computed[1, 3], 53842.28)
  expect_eur(aux$levy_k_capped[1, 3], 38400)
  expect_eur(aux$levy_k_charged[1, 3], 21120)
  expect_identical(aux$levy_k_procedure[1, 3], 1)
  open <- do.call(eop_rp, c(args, list(.measures = meas)))
  expect_eur(eop_years(open, "levy_k", 2028), 38400)
  # RP-15: active = (1, 0)
  g <- make_grid(T = 10L)
  dr <- fake_draws(2L, g, static = list("measures.k.active" = c(1, 0)))
  two <- do.call(eop_rp, c(args, list(voluntary_cap_per_m2 = 1.10, .measures = meas, .n = 2L,
                                      .draws = dr, .grid = g)))
  expect_eur(eop_years(two, "levy_k", 2028, sim = 1L), 21120)
  expect_eur(eop_years(two, "levy_k", 2028:2031, sim = 2L), rep(0, 4))
  expect_eur(eop_years(two, "rent", 2027:2029, sim = 2L), c(119040.00, 119040.00, 120825.60))
})

test_that("RP-13: Batch-Invarianz bei laufspezifischer Verschiebung der Maßnahme", {
  g <- make_grid(T = 6L)
  meas <- list(k = list(modernization_kind = "bgb_555b_1", cost_eur = 673028.5,
                        completion_date = "2027-10-01", ohnehin_share = 0, delay_months = 0))
  delays <- 3 * (0:6)
  dr <- fake_draws(7L, g, static = list("measures.k.delay_months" = delays))
  fun <- function(n, draws) {
    eop_rp(unit_group = "g", living_area_m2 = 1600, n_units = 24L, rent_eur_m2_month = 6.2,
           increase_policy = "fixed_growth", rent_growth = 0.015, growth_from = "2029-01-01",
           rent_law_measures = list("k"), levy_rows = list("k"), voluntary_cap_per_m2 = 1.10,
           .measures = meas, .n = n, .draws = draws, .grid = g)$flows
  }
  expect_batch_invariance(fun, n = 7L, grid = g, draws = dr)
  fl <- fun(7L, dr)
  lv <- eop_row(fl, "levy_k")
  # Wirksamkeit ab Monat 13 + 3 (i - 1): Monate mit Umlage im Jahr 2028
  months_2028 <- pmax(0, 12 - pmax(0, delays))
  expect_eur(lv[, 3], 1.1 * 1600 * months_2028)
})

test_that("RP-6: Fluktuation mit und ohne Mietpreisbremse", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 3L, construction_months = 12L,
                      construction_step_months = 1L)
  run <- function(brake) {
    eop_rp(unit_group = "g", living_area_m2 = 100, n_units = 1L, rent_eur_m2_month = 8,
           increase_policy = "fixed_growth", rent_growth = 0, ovm_eur_m2_month = 9,
           market_rent_eur_m2_month = 11, market_rent_growth = 0, turnover_rate_pa = 0.12,
           brake_area = brake, brake_until = "2029-12-31", first_use_after_2014_10_01 = FALSE,
           .grid = g)
  }
  b <- run(TRUE)
  expect_equal(b$flows$aux$rent_level[1, 13], 8.215869, tolerance = 1e-6)
  expect_eur(eop_years(b, "rent", 2027), 9742.90)
  nb <- run(FALSE)
  expect_equal(nb$flows$aux$rent_level[1, 13], 8.340845, tolerance = 1e-6)
  expect_eur(eop_years(nb, "rent", 2027), 9825.63)
})

test_that("RP-8: Staffelmiete, keine Umlage nach § 559 während der Staffel", {
  meas <- list(k = list(modernization_kind = "bgb_555b_1", cost_eur = 20000,
                        completion_date = "2027-10-01", ohnehin_share = 0))
  res <- eop_rp(unit_group = "g", living_area_m2 = 100, n_units = 1L, rent_eur_m2_month = 8,
                rent_regime = "staffel",
                staffel_steps = list(schedule = list("2028-01-01" = 8.30, "2029-07-01" = 8.60)),
                rent_law_measures = list("k"), levy_rows = list("k"), .measures = meas)
  expect_eur(eop_years(res, "rent", 2027:2029), c(9600, 9960, 10140))
  expect_eur(eop_years(res, "levy_k", 2027:2031), rep(0, 5))
})

test_that("RP-9: Indexmiete, Dämpfung mit Mietrecht II", {
  run <- function(rate, legal = eop_legal(), cap = FALSE) {
    eop_rp(unit_group = "g", living_area_m2 = 100, n_units = 1L, rent_eur_m2_month = 8,
           rent_regime = "index", index_rate = rate, index_cap_area = cap, .legal = legal)
  }
  res <- run(list(series = list("2027" = 0.028, "2028" = 0.022)))
  expect_eur(eop_years(res, "rent", 2027:2029), c(9600, 9868.80, 10085.91))
  ii <- run(0.05, eop_legal(mietrecht = eop_lp_mietrecht_ii()), cap = TRUE)
  expect_eur(eop_years(ii, "rent", 2028:2029), c(9984.00, 10383.36))
})

test_that("RP-10: Anlaufleerstand (Lease-up) und Leerstandshelfer", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 2L, construction_months = 12L,
                      construction_step_months = 1L)
  res <- eop_rp(unit_group = "g", living_area_m2 = 100, n_units = 1L, rent_eur_m2_month = 10,
                lease_up_months = 4, .grid = g)
  loss <- eop_row(res$flows, "rent_loss")[1, ]
  expect_eur(loss[2:6], c(-875, -625, -375, -125, 0))
  expect_eur(eop_years(res, "rent_loss", 2027), -2000)
})

test_that("RP-11: Mietminderung während der Arbeiten, Ausschluss nach § 536 Abs. 1a", {
  run <- function(kind) {
    meas <- list(k = list(modernization_kind = kind, cost_eur = 10000,
                          completion_date = "2027-10-01",
                          rent_law = list(works_start_date = "2027-01-01",
                                          works_rent_reduction_share = 0.2)))
    eop_rp(unit_group = "g", living_area_m2 = 100, n_units = 1L, rent_eur_m2_month = 10,
           rent_law_measures = list("k"), .measures = meas)
  }
  expect_eur(eop_years(run("bgb_555b_1"), "rent_loss", 2027), -1200)
  expect_eur(eop_years(run("bgb_555b_4"), "rent_loss", 2027), -1800)
})

test_that("RP-12: Förderung fällt aus, Rückfall auf § 559 und Heizungskappe", {
  g <- make_grid(T = 6L)
  meas <- list(h = list(modernization_kind = "bgb_555b_1a", cost_eur = 153560,
                        ohnehin_cost_eur = 45360, completion_date = "2027-10-01"))
  res <- eop_rp(unit_group = "g", living_area_m2 = 840, n_units = 12L, rent_eur_m2_month = 6.4,
                rent_law_measures = list("h"), levy_rows = list("h"),
                grant_components = list("f_g_grant"), after = list("f_g_grant"),
                .measures = meas, .deps = list(f_g_grant = eop_grant_flows(1L, g, "h", 0)),
                .grid = g)
  aux <- res$flows$aux
  expect_eur(aux$levy_h_computed[1, 3], 8656.00)
  expect_eur(aux$levy_h_computed[1, 3] / (12 * 840), 0.858730, tol = 1e-6)
  expect_eur(aux$levy_h_capped[1, 3], 5040.00)
  expect_identical(aux$levy_h_procedure[1, 3], 1)
  expect_true(any(grepl("559", res$flows$meta$notes)))
})

#' S1 V2: drei Maßnahmen mit KfW 261 (Tilgungszuschuss 144.400, Zinsermäßigung 4.550)
s1_case <- function(r0, cap = NULL, n = 1L, draws = NULL, grid = make_grid(T = 6L)) {
  meas <- list(
    huelle = list(modernization_kind = "bgb_555b_1", cost_eur = 990580.50,
                  ohnehin_cost_eur = 447982.50, completion_date = "2027-10-01"),
    heizung = list(modernization_kind = "bgb_555b_1a", cost_eur = 371700.00,
                   ohnehin_cost_eur = 129202.50, completion_date = "2027-10-01",
                   rent_law = list(procedure = "bgb_559")),
    lueftung = list(modernization_kind = "bgb_555b_1", cost_eur = 89208.00,
                    ohnehin_cost_eur = 0, completion_date = "2027-10-01")
  )
  ids <- list("huelle", "heizung", "lueftung")
  args <- list(unit_group = "bestand", living_area_m2 = 1600, n_units = 24L,
               rent_eur_m2_month = r0, increase_policy = "fixed_growth", rent_growth = 0.015,
               growth_from = "2029-01-01", rent_law_measures = ids, levy_rows = ids,
               funding_ids = list("kfw261"),
               .measures = meas,
               .funding = list(kfw261 = list(instrument_type = "loan_with_repayment_grant",
                                             measures = ids)),
               .financing = list(f_kfw261_loan = list(type = "annuity_loan", amount_eur = 1300000,
                                                      approved = 1, rate_pa = 0.0365,
                                                      start = "2027-01-01", fixed_years = 10,
                                                      repayment_grant = list(amount_eur = 144400))),
               .n = n, .draws = draws, .grid = grid)
  if (!is.null(cap)) args$voluntary_cap_per_m2 <- cap
  do.call(eop_rp, args)
}

test_that("S1-T4, S1-T4a, S1-T5, S1-T6: Umlage je Maßnahme mit Teilkappung (F14)", {
  res <- s1_case(6.20)
  aux <- res$flows$aux
  comp <- c(aux$levy_huelle_computed[1, 3], aux$levy_heizung_computed[1, 3],
            aux$levy_lueftung_computed[1, 3])
  expect_eur(sum(comp), 53842.28, tol = 0.02)
  expect_eur(comp, c(32418.90, 15276.37, 6147.02), tol = 0.01)
  # S1-T5: Gesamtkappe 2,00 EUR/m² (Miete 6,20 < 7,00), proportional
  capped <- c(aux$levy_huelle_capped[1, 3], aux$levy_heizung_capped[1, 3],
              aux$levy_lueftung_capped[1, 3])
  expect_eur(sum(capped), 38400, tol = 0.01)
  expect_eur(capped, c(25845.78, 7653.55, 4900.67), tol = 0.01)
  # S1-T4a: bei T = 7,20 bindet nur die Heizungskappe
  hi <- s1_case(7.20)$flows$aux
  capped_hi <- c(hi$levy_huelle_capped[1, 3], hi$levy_heizung_capped[1, 3],
                 hi$levy_lueftung_capped[1, 3])
  expect_eur(capped_hi[2], 9600.00)
  expect_eur(sum(capped_hi), 48165.91, tol = 0.02)
  expect_eur(sum(capped_hi) / (12 * 1600), 2.508641, tol = 1e-6)
  # S1-T6: Beschluss 1,10 EUR/m²
  cap <- s1_case(6.20, cap = 1.10)
  total <- eop_years(cap, "levy_huelle", 2028) + eop_years(cap, "levy_heizung", 2028) +
    eop_years(cap, "levy_lueftung", 2028)
  expect_eur(total, 21120)
})

test_that("L-1 Zurechnung proportional und L-2 Sammelmaßnahme", {
  meas <- list(k = list(modernization_kind = "bgb_555b_1", cost_eur = 1451488.50,
                        ohnehin_cost_eur = 577185.00, completion_date = "2027-10-01",
                        rent_law = list(heating_part_share = 300000 / 1171500)))
  base <- list(unit_group = "bestand", living_area_m2 = 1600, n_units = 24L,
               increase_policy = "fixed_growth", rent_growth = 0, rent_law_measures = list("k"),
               levy_rows = list("k"), funding_ids = list("kfw261"), .measures = meas,
               .funding = list(kfw261 = list(instrument_type = "loan_with_repayment_grant",
                                             measures = list("k"))),
               .financing = list(f_kfw261_loan = list(amount_eur = 1300000, approved = 1,
                                                      rate_pa = 0.0365, start = "2027-01-01",
                                                      repayment_grant = list(amount_eur = 144400))),
               .grid = make_grid(T = 4L))
  low <- do.call(eop_rp, c(base, list(rent_eur_m2_month = 6.2)))$flows$aux
  expect_eur(low$levy_k_computed[1, 3], 53842.28)
  expect_eur(low$levy_k_capped[1, 3], 38400.00)
  high <- do.call(eop_rp, c(base, list(rent_eur_m2_month = 7.2)))$flows$aux
  expect_eur(high$levy_k_capped[1, 3], 49654.24, tol = 0.02)
  prop <- do.call(eop_rp, c(base, list(rent_eur_m2_month = 6.2,
                                       drittmittel_attribution = "proportional")))$flows$aux
  expect_eur(prop$levy_k_computed[1, 3], 60245.25)
})

#' S3 V2: Wärmepumpe nach § 559e mit KfW 459 (Zuschuss 45.300)
s3_case <- function(cap = 0.35, legal = eop_legal(), jaz_plan = 3.1, flow = 55,
                    order = NULL) {
  g <- make_grid(T = 6L)
  meas <- list(heizung_wp = list(modernization_kind = "bgb_555b_1a", cost_eur = 153560,
                                 ohnehin_cost_eur = 45360, completion_date = "2027-10-01"))
  energy <- list(carriers = list(heatpump_power_mfh = list(class = "power_hp")),
                 after = list(measure = "heizung_wp", heating_carrier = "heatpump_power_mfh",
                              jaz = 3.1, jaz_plan = jaz_plan, flow_temperature_c = flow))
  args <- list(unit_group = "mitglieder", living_area_m2 = 840, n_units = 12L,
               rent_eur_m2_month = 6.4, rent_regime = "cooperative_fee",
               increase_policy = "fixed_growth", rent_growth = 0.015,
               growth_from = "2028-01-01", rent_law_measures = list("heizung_wp"),
               levy_rows = list("heizung_wp"), grant_components = list("f_kfw459_grant"),
               after = list("f_kfw459_grant"), .measures = meas, .energy = energy,
               .building = list(construction_year = 1985L), .legal = legal,
               .deps = list(f_kfw459_grant = eop_grant_flows(1L, g, "heizung_wp", 45300)),
               .grid = g)
  if (!is.null(cap)) args$voluntary_cap_per_m2 <- cap
  if (!is.null(order)) args$hp_reduction_order <- order
  do.call(eop_rp, args)
}

test_that("S3-T3: § 559e rechnerisch, gekappt, angesetzt (F13)", {
  res <- s3_case()
  aux <- res$flows$aux
  expect_eur(aux$levy_heizung_wp_computed[1, 3], 8522.60)
  expect_eur(aux$levy_heizung_wp_capped[1, 3], 5040.00)
  expect_eur(aux$levy_heizung_wp_charged[1, 3], 3528.00)
  expect_identical(aux$levy_heizung_wp_procedure[1, 3], 3)
  expect_eur(eop_years(res, "levy_heizung_wp", 2028), 3528.00)
  expect_identical(res$flows$rows[[1L]]$label_key, "types.flow.rent_path.rows.rent_cooperative")
})

test_that("S3-T4, S3-T4a, L-4: § 559f mit Plan-JAZ 2,4 und Vorlauf 70 °C", {
  legal <- eop_legal(mietrecht_559f = eop_lp_559f())
  ht <- s3_case(cap = NULL, legal = legal, jaz_plan = 2.4, flow = 70)
  expect_eur(ht$flows$aux$levy_heizung_wp_computed[1, 3], 1996.30)
  th <- s3_case(cap = NULL, legal = legal, jaz_plan = 2.4, flow = 70, order = "funds_then_halve")
  expect_eur(th$flows$aux$levy_heizung_wp_computed[1, 3], 4261.30)
  # S3-T4a: Plan-JAZ 3,1 und Vorlauf 55 °C -> keine Halbierung
  ok <- s3_case(cap = NULL, legal = legal, jaz_plan = 3.1, flow = 55)
  expect_eur(ok$flows$aux$levy_heizung_wp_computed[1, 3], 8522.60)
  # Plan-JAZ genau 2,5 (einschließlich) bzw. Vorlauf 55 °C: keine Halbierung
  expect_eur(s3_case(cap = NULL, legal = legal, jaz_plan = 2.5, flow = 70)$flows$aux$
               levy_heizung_wp_computed[1, 3], 8522.60)
  expect_eur(s3_case(cap = NULL, legal = legal, jaz_plan = 2.4, flow = 55)$flows$aux$
               levy_heizung_wp_computed[1, 3], 8522.60)
  # Thema inaktiv: keine Halbierung
  inactive <- s3_case(cap = NULL, jaz_plan = 2.4, flow = 70)
  expect_eur(inactive$flows$aux$levy_heizung_wp_computed[1, 3], 8522.60)
  expect_true("types.flow.rent_path.msg.topic_559f_inactive" %in%
                inactive$flows$meta$note_keys)
})

test_that("L-4: realisierte JAZ im MC ändert die Halbierung nicht (Plan-JAZ als Basisfall)", {
  legal <- eop_legal(mietrecht_559f = eop_lp_559f())
  g <- make_grid(T = 6L)
  meas <- list(heizung_wp = list(modernization_kind = "bgb_555b_1a", cost_eur = 153560,
                                 completion_date = "2027-10-01"))
  energy <- list(after = list(measure = "heizung_wp", heating_carrier = "heatpump_power_mfh",
                              jaz = 3.1, flow_temperature_c = 70))
  dr <- fake_draws(2L, g, static = list("energy.after.jaz" = c(2.0, 3.1)))
  res <- eop_rp(unit_group = "m", living_area_m2 = 840, n_units = 12L, rent_eur_m2_month = 6.4,
                rent_law_measures = list("heizung_wp"), levy_rows = list("heizung_wp"),
                grant_components = list("f_g"), after = list("f_g"), .measures = meas,
                .energy = energy, .building = list(construction_year = 1985L), .legal = legal,
                .deps = list(f_g = eop_grant_flows(2L, g, "heizung_wp", 45300)), .n = 2L,
                .draws = dr, .grid = g)
  cmp <- res$flows$aux$levy_heizung_wp_computed[, 3]
  expect_equal(cmp[1], cmp[2])
  expect_eur(cmp[1], 8522.60)
})

test_that("L-11: Wirksamkeit der Umlage nach Zugang der Erklärung", {
  run <- function(decl, ok = TRUE) {
    meas <- list(k = list(modernization_kind = "bgb_555b_1", cost_eur = 10000,
                          completion_date = "2027-09-01",
                          rent_law = list(declaration_date = decl, announcement_ok = ok)))
    g <- vofi_time_grid(as.Date("2027-01-01"), 3L, construction_months = 24L,
                        construction_step_months = 1L)
    res <- eop_rp(unit_group = "g", living_area_m2 = 100, n_units = 1L, rent_eur_m2_month = 8,
                  rent_law_measures = list("k"), levy_rows = list("k"), .measures = meas,
                  .grid = g)
    v <- eop_row(res$flows, "levy_k")[1, -1L]
    g$date_start[which(v > 0)[1L] + 1L]
  }
  expect_identical(run("2027-10-01"), as.Date("2028-01-01"))
  expect_identical(run("2027-09-15"), as.Date("2027-12-01"))
  expect_identical(run("2027-10-01", FALSE), as.Date("2028-07-01"))
})

test_that("RP-14: warmmietenneutrale Obergrenze aus dem Basisfall der Mieterkosten", {
  g <- make_grid(T = 6L)
  sav <- matrix(0, 1L, g$T + 1L)
  sav[1, 3] <- (17157.42 - 4998.00) / 12000
  tenant <- vofi_flows(vofi_row("energy", matrix(0, 1L, g$T + 1L), section = "memo",
                                category = "tenant_energy_cost"),
                       aux = list(saving_eur_m2_month = sav))
  meas <- list(k = list(modernization_kind = "bgb_555b_1", cost_eur = 180000,
                        ohnehin_share = 0, completion_date = "2027-10-01",
                        rent_law = list(heating_part_share = 0.25)))
  res <- eop_rp(unit_group = "g", living_area_m2 = 1000, n_units = 10L, rent_eur_m2_month = 6,
                increase_policy = "fixed_growth", rent_growth = 0,
                rent_law_measures = list("k"), levy_rows = list("k"),
                voluntary_cap_mode = "warm_rent_neutral", tenant_cost_component = "e_tenant",
                .measures = meas, .deps = list(e_tenant = tenant), .grid = g)
  expect_eur(res$flows$aux$levy_k_computed[1, 3], 14400)
  expect_eur(res$flows$aux$voluntary_cap_level[1, 3], 1.013285, tol = 1e-6)
  expect_eur(eop_years(res, "levy_k", 2028), 12159.42)
  warm <- (eop_years(res, "levy_k", 2028) + 4998.00 - 17157.42) / 12000
  expect_eur(warm, 0, tol = 1e-6)
  # Obergrenze aus dem Basisfall: abweichende Ersparnis im Lauf ändert sie nicht
  run_tenant <- tenant
  run_tenant$aux$saving_eur_m2_month[1, 3] <- 0.5
  mc <- eop_rp(unit_group = "g", living_area_m2 = 1000, n_units = 10L, rent_eur_m2_month = 6,
               increase_policy = "fixed_growth", rent_growth = 0,
               rent_law_measures = list("k"), levy_rows = list("k"),
               voluntary_cap_mode = "warm_rent_neutral", tenant_cost_component = "e_tenant",
               .measures = meas, .deps = list(e_tenant = run_tenant),
               .base_deps = list(e_tenant = tenant), .grid = g)
  expect_eur(eop_years(mc, "levy_k", 2028), 12159.42)
  # ohne Komponente: Obergrenze 0 mit Hinweis
  none <- eop_rp(unit_group = "g", living_area_m2 = 1000, n_units = 10L, rent_eur_m2_month = 6,
                 rent_law_measures = list("k"), levy_rows = list("k"),
                 voluntary_cap_mode = "warm_rent_neutral", .measures = meas, .grid = g)
  expect_eur(eop_years(none, "levy_k", 2028), 0)
  expect_true("types.flow.rent_path.msg.warm_neutral_no_saving" %in% none$flows$meta$note_keys)
})

test_that("Härtefallanteil mindert nur die Zahlung, nicht das Mietniveau", {
  meas <- list(k = list(modernization_kind = "bgb_555b_1", cost_eur = 21000, ohnehin_share = 0,
                        completion_date = "2027-03-01",
                        rent_law = list(levy_effective_date = "2027-03-01")))
  res <- eop_rp(unit_group = "g", living_area_m2 = 70, n_units = 1L, rent_eur_m2_month = 7.5,
                rent_law_measures = list("k"), levy_rows = list("k"), hardship_share = 0.25,
                .measures = meas)
  expect_eur(eop_years(res, "levy_k", 2028), 1680 * 0.75)
  expect_equal(res$flows$aux$levy_level[1, 3], 2)
})

test_that("Mietrecht inaktiv: keine Umlage, Hinweis in meta$notes", {
  meas <- list(k = list(modernization_kind = "bgb_555b_1", cost_eur = 21000,
                        completion_date = "2027-03-01"))
  res <- eop_rp(unit_group = "g", living_area_m2 = 70, n_units = 1L, rent_eur_m2_month = 7.5,
                rent_law_measures = list("k"), levy_rows = list("k"), .measures = meas,
                .legal = eop_legal(mietrecht = NULL))
  expect_eur(eop_years(res, "levy_k", 2027:2029), c(0, 0, 0))
  expect_true("types.flow.rent_path.msg.topic_inactive" %in% res$flows$meta$note_keys)
})

test_that("Mieterliste: Kappung je Wohnung (2 EUR vs. 3 EUR)", {
  meas <- list(k = list(modernization_kind = "bgb_555b_1", cost_eur = 64800, ohnehin_share = 0,
                        completion_date = "2027-03-01",
                        rent_law = list(levy_effective_date = "2027-03-01")))
  roll <- list(a = list(living_area_m2 = 100, rent_eur_m2_month = 6.5),
               b = list(living_area_m2 = 100, rent_eur_m2_month = 7.5))
  ug <- list(g = list(living_area_m2 = 200, rent_roll = roll))
  res <- eop_rp(unit_group = "g", living_area_m2 = 200, n_units = 2L, rent_eur_m2_month = 7,
                rent_law_measures = list("k"), levy_rows = list("k"),
                rent_roll_units = list("a", "b"), .measures = meas, .unit_groups = ug)
  # Umlage rechnerisch 0,08 * 64.800 / (12 * 200) = 2,16 EUR/m²; Wohnung a gekappt auf 2,00
  expect_eur(eop_years(res, "levy_k", 2028), (2.00 + 2.16) * 100 * 12)
  expect_eur(eop_years(res, "rent", 2027), (6.5 + 7.5) * 100 * 12)
})

test_that("Leerstandshelfer rp_vacancy_share entspricht aux$vacant_share (E-9)", {
  g <- make_grid(T = 6L)
  ug <- list(g = list(living_area_m2 = 1600, vacancy_rate = 0.03, lease_up_months = 0),
             h = list(living_area_m2 = 100, lease_up_months = 4))
  res_g <- eop_rp(unit_group = "g", living_area_m2 = list(ref = "unit_groups.g.living_area_m2"),
                  n_units = 24L, rent_eur_m2_month = 6.2,
                  vacancy_rate = list(ref = "unit_groups.g.vacancy_rate"), .unit_groups = ug,
                  .grid = g)
  expect_equal(rp_vacancy_share(res_g$ctx, "g"), res_g$flows$aux$vacant_share,
               tolerance = 1e-12)
  res_h <- eop_rp(unit_group = "h", living_area_m2 = list(ref = "unit_groups.h.living_area_m2"),
                  n_units = 1L, rent_eur_m2_month = 10,
                  lease_up_months = list(ref = "unit_groups.h.lease_up_months"),
                  .unit_groups = ug, .grid = g, .id = "u_h_rent")
  expect_equal(rp_vacancy_share(res_h$ctx, "h"), res_h$flows$aux$vacant_share,
               tolerance = 1e-12)
  both <- rp_vacancy_share(res_h$ctx, c("g", "h"))
  expect_equal(both[1, 2], (1600 * 0.03 + 100 * 2 / 12) / 1700, tolerance = 1e-12)
  expect_equal(rp_vacancy_share(res_h$ctx, character(0)), res_h$ctx$zeros())
})

test_that("act(): Aktivierungsfaktor mit Zusage bei on_reject drop_measures", {
  g <- make_grid(T = 2L)
  spec <- eop_spec(g, measures = list(k = list(active = 1), j = list(active = 0.5)),
                   funding = list(f = list(on_reject = "drop_measures", measures = list("k"),
                                           approved = 1),
                                  b = list(on_reject = "balance", measures = list("k"),
                                           approved = 0)))
  dr <- fake_draws(2L, g, static = list("funding.f.approved" = c(1, 0)))
  ctx <- eop_ctx(spec, g, n = 2L, draws = dr)
  expect_identical(act(ctx, "k"), c(1, 0))
  expect_identical(act(ctx, "j"), c(0.5, 0.5))
  expect_identical(act(ctx, "unbekannt"), c(1, 1))
})

test_that("Rasterinvarianz (F10) mit Umlage und Steigerung", {
  meas <- list(k = list(modernization_kind = "bgb_555b_1", cost_eur = 50000, ohnehin_share = 0,
                        completion_date = "2027-10-01"))
  run <- function(g) {
    eop_rp(unit_group = "g", living_area_m2 = 100, n_units = 2L, rent_eur_m2_month = 6,
           rent_start = "2027-01-01", growth_from = "2028-01-01", rent_growth = 0.02,
           vacancy_rate = 0.02, rent_law_measures = list("k"), levy_rows = list("k"),
           .measures = meas, .grid = g)
  }
  a <- run(make_grid("annual"))
  m <- run(make_grid("mixed"))
  for (key in c("rent", "rent_loss", "levy_k")) {
    for (y in 2027:2032) {
      expect_equal(eop_year(eop_row(a$flows, key), a$grid, y),
                   eop_year(eop_row(m$flows, key), m$grid, y), tolerance = 1e-9)
    }
  }
})
