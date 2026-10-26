# Tests für R/type-flow-co2-cost.R (WS-E; Spec 01 Teil B Abschnitt 3.7, Prüfwerte C-1 bis C-5a,
# C-7, C-9, C-10).

expect_near <- function(actual, expected, tol = 0.006) {
  testthat::expect_true(all(abs(actual - expected) <= tol),
                        info = paste("ist:", paste(format(actual, nsmall = 6), collapse = " "),
                                     "soll:", paste(expected, collapse = " ")))
}

#' Segment und CO2-Komponente bauen
co2_case <- function(q = "150000", ef = 0.182, price = 65, area = 1000, section43 = FALSE,
                     installation_date = NULL, emergency = FALSE, owner_share = 0,
                     network_fee = 0, bio_premium = 0, legal = eop_legal(),
                     grid = make_grid(T = 6L), unit_groups = list(), groups = list(),
                     perspective = "wu_kommunal", project = list()) {
  e <- list(type = "energy_cost", state = "before", carrier = "gas", carrier_class = "gas",
            quantity_kwh_pa = list(expr = q), price_eur_kwh = 0.06, emission_factor_kg_kwh = ef,
            co2_price_eur_t = price, network_fee_eur_kwh = network_fee,
            bio_premium_eur_kwh = bio_premium, section43 = section43, owner_share = owner_share,
            unit_groups = groups, counterfactual_pre = TRUE)
  c2 <- list(type = "co2_cost", energy_component = "e_before_gas_cost", living_area_m2 = area,
             carrier_class = "gas", section43 = section43, emergency_replacement = emergency,
             after = list("e_before_gas_cost"))
  if (!is.null(installation_date)) {
    e$installation_date <- installation_date
    c2$installation_date <- installation_date
  }
  eop_chain(list(e_before_gas_cost = e, e_before_gas_co2 = c2), .legal = legal, .grid = grid,
            .unit_groups = unit_groups, .perspective = perspective, .project = project)
}

co2_y <- function(res, key, years) eop_cy(res, "e_before_gas_co2", key, years)

test_that("Vertragstests co2_cost (Prüfkit 5.6)", {
  expect_type_contract("co2_cost", "flow")
})

test_that("C-1: Stufenmodell 40 % und § 5a-Anteil bei vier CO2-Preisen (Memo 02 Bsp. 4)", {
  exp <- list(`55` = c(1786.79, 714.71, 893.39), `65` = c(2111.66, 844.66, 1055.83),
              `100` = c(3248.70, 1299.48, 1624.35), `150` = c(4873.05, 1949.22, 2436.53))
  for (p in names(exp)) {
    res <- co2_case(price = as.numeric(p))
    a <- res$flows$e_before_gas_co2$aux
    expect_near(a$specific_kg_m2[1, 2], 27.3, 1e-9)
    expect_equal(a$stage_share[1, 2], 0.40)
    gross <- eop_aux_y(res, "e_before_gas_cost", "co2_gross", 2027)
    expect_near(gross, exp[[p]][1])
    expect_near(-co2_y(res, "co2_landlord", 2027), exp[[p]][2])
    expect_near(gross * 0.5, exp[[p]][3])
    expect_near(eop_aux_y(res, "e_before_gas_co2", "tenant_co2_gross", 2027),
                exp[[p]][1] - exp[[p]][2], 0.02)
  }
  expect_vofi_flows_contract(res$flows$e_before_gas_co2, res$ctx, reg_get("flow", "co2_cost"))
})

test_that("C-2/C-3: spezifische Emission und Stufe (S1-T9, S3-T5)", {
  r2 <- co2_case(q = "280000", ef = 0.181, area = 1600)
  expect_near(r2$flows$e_before_gas_co2$aux$specific_kg_m2[1, 2], 31.675, 1e-9)
  expect_equal(r2$flows$e_before_gas_co2$aux$landlord_share[1, 2], 0.40)
  r3 <- co2_case(q = "109200", ef = 0.181, area = 840)
  expect_near(r3$flows$e_before_gas_co2$aux$specific_kg_m2[1, 2], 23.53, 1e-9)
  expect_equal(r3$flows$e_before_gas_co2$aux$landlord_share[1, 2], 0.30)
})

c4_case <- function(legal = eop_legal(), grid = make_grid(T = 19L)) {
  co2_case(q = "255000", ef = 0.181, area = 1600, section43 = TRUE,
           installation_date = "2027-10-01", network_fee = 0.0219, bio_premium = 0.06,
           price = list(series = list("2027" = 65, "2028" = 70, "2035" = 105)), legal = legal,
           grid = grid)
}

test_that("C-4: § 5a ab 2028 mit Gasnetzentgelt (S1-T10)", {
  res <- c4_case()
  gross <- eop_aux_y(res, "e_before_gas_cost", "co2_gross", 2027:2028)
  expect_near(gross[2], 3844.71)
  expect_near(co2_y(res, "co2_landlord", 2028), -1922.36)
  expect_near(eop_aux_y(res, "e_before_gas_cost", "network_gross", 2028), 6645.55)
  expect_near(co2_y(res, "network_fee_landlord", 2028), -3322.78)
  a <- res$flows$e_before_gas_co2$aux
  expect_equal(a$s5a_active[1, 2:3], c(0, 1))
  expect_equal(a$landlord_share[1, 2], 0.40)
  expect_near(co2_y(res, "co2_landlord", 2027), -0.40 * gross[1])
  expect_equal(co2_y(res, "network_fee_landlord", 2027), 0)
  expect_near(eop_aux_y(res, "e_before_gas_co2", "tenant_network_reduction", 2028), 3322.78)
})

test_that("C-5: Bio-Treppe mit Deckel 30 % (2035, 2040)", {
  res <- c4_case()
  expect_near(eop_aux_y(res, "e_before_gas_cost", "co2_gross", 2035), 4036.95)
  expect_near(co2_y(res, "co2_landlord", 2035), -2018.47)
  expect_near(eop_aux_y(res, "e_before_gas_cost", "bio_gross", 2035), 5462.10)
  expect_near(co2_y(res, "bio_landlord", 2035), -2731.05)
  expect_near(eop_aux_y(res, "e_before_gas_cost", "bio_gross", 2040), 10924.20)
  expect_near(co2_y(res, "bio_landlord", 2040), -2731.05)
  expect_equal(co2_y(res, "bio_landlord", 2028), 0)
  expect_equal(res$flows$e_before_gas_cost$aux$beta[1, res$grid$year == 2035], 0.30)
})

test_that("C-5a: Reformcode stufe_2045 (Bio-Anteil 1,00 im Jahr 2045)", {
  base <- c4_case()
  j <- base$grid$year == 2045
  expect_equal(base$flows$e_before_gas_cost$aux$beta[1, j], 0.60)
  ref <- c4_case(legal = eop_legal(bio_treppe = eop_lp_bio(stufe_2045 = TRUE)))
  expect_equal(ref$flows$e_before_gas_cost$aux$beta[1, j], 1.00)
  expect_equal(eop_aux_y(ref, "e_before_gas_cost", "co2_gross", 2045), 0)
  expect_equal(co2_y(ref, "co2_landlord", 2045), 0)
})

test_that("C-7: Leerstand trägt der Vermieter", {
  res <- co2_case(q = "1000 / (0.2 * 50 / 1000 * 1.19)", ef = 0.2, price = 50, area = 700,
                  unit_groups = list(g = list(living_area_m2 = 700, vacancy_rate = 0.05)),
                  groups = list("g"))
  expect_near(eop_aux_y(res, "e_before_gas_cost", "co2_gross", 2027), 1000, 1e-9)
  expect_equal(res$flows$e_before_gas_co2$aux$landlord_share[1, 2], 0.30)
  expect_near(co2_y(res, "co2_vacancy", 2027), -50.00, 1e-9)
  expect_near(co2_y(res, "co2_landlord", 2027), -285.00, 1e-9)
  expect_near(eop_aux_y(res, "e_before_gas_co2", "tenant_co2_gross", 2027), 700.00, 1e-9)
})

test_that("C-8: Übergang bei Havarie verschiebt § 5a um ein Jahr", {
  res <- co2_case(section43 = TRUE, installation_date = "2027-06-01", emergency = TRUE,
                  grid = make_grid(T = 4L))
  a <- res$flows$e_before_gas_co2$aux$s5a_active
  expect_equal(a[1, 2:4], c(0, 0, 1))
})

test_that("C-9: Selbstnutzer trägt die CO2-Kosten vollständig", {
  res <- co2_case(q = "24500", ef = 0.181, price = 60, area = 140, owner_share = 1,
                  perspective = "selbstnutzer")
  expect_near(co2_y(res, "co2_owner", 2027), -316.62)
  for (k in c("co2_vacancy", "co2_landlord", "network_fee_landlord", "bio_landlord")) {
    expect_equal(co2_y(res, k, 2027:2030), rep(0, 4))
  }
  r <- res$flows$e_before_gas_co2$rows[[1L]]
  expect_identical(r$tax_category, "expense_nondeductible")
  expect_equal(r$vat_rate, 0.19)
})

test_that("C-10: Thema co2kostaufg inaktiv", {
  res <- co2_case(legal = eop_legal(co2kostaufg = NULL))
  expect_equal(co2_y(res, "co2_landlord", 2027:2030), rep(0, 4))
  expect_near(eop_aux_y(res, "e_before_gas_co2", "tenant_co2_gross", 2027), 2111.66)
  expect_true("types.flow.co2_cost.msg.topic_inactive" %in%
                res$flows$e_before_gas_co2$meta$note_keys)
  expect_match(res$flows$e_before_gas_co2$meta$notes[[1L]], "CO2KostAufG nicht angewendet")
})

test_that("Kürzung nach § 9 und kontrafaktische Mieteranteile", {
  res <- co2_case()
  e <- list(type = "energy_cost", state = "before", carrier = "gas", carrier_class = "gas",
            quantity_kwh_pa = list(expr = "150000"), price_eur_kwh = 0.06,
            emission_factor_kg_kwh = 0.182, co2_price_eur_t = 65)
  c2 <- list(type = "co2_cost", energy_component = "e_before_gas_cost", living_area_m2 = 1000,
             carrier_class = "gas", landlord_share_reduction = 0.5,
             after = list("e_before_gas_cost"))
  red <- eop_chain(list(e_before_gas_cost = e, e_before_gas_co2 = c2), .grid = make_grid(T = 3L))
  expect_equal(red$flows$e_before_gas_co2$aux$landlord_share[1, 2], 0.20)
  a <- res$flows$e_before_gas_co2$aux
  expect_equal(a$cf_landlord_share[1, 2], a$landlord_share[1, 2])
  expect_near(eop_year(a$cf_tenant_co2_gross, res$grid, 2027),
              eop_aux_y(res, "e_before_gas_co2", "tenant_co2_gross", 2027), 1e-9)
})

test_that("Batch-Invarianz mit laufspezifischem CO2-Preis", {
  g <- make_grid(T = 6L)
  dr <- fake_draws(4L, g, static = list("market.co2_price" = c(40, 65, 120, 200)))
  fun <- function(n, draws) {
    e <- list(type = "energy_cost", state = "before", carrier = "gas", carrier_class = "gas",
              quantity_kwh_pa = list(expr = "150000"), price_eur_kwh = 0.06,
              emission_factor_kg_kwh = 0.182, co2_price_eur_t = list(ref = "market.co2_price"),
              section43 = TRUE, installation_date = "2027-10-01")
    c2 <- list(type = "co2_cost", energy_component = "e_before_gas_cost", living_area_m2 = 1000,
               carrier_class = "gas", section43 = TRUE, installation_date = "2027-10-01",
               after = list("e_before_gas_cost"))
    eop_chain(list(e_before_gas_cost = e, e_before_gas_co2 = c2), .grid = g, .n = n,
              .draws = draws)$flows$e_before_gas_co2
  }
  expect_batch_invariance(fun, n = 4L, grid = g, draws = dr)
})
