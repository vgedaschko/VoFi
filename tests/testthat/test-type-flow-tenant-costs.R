# Tests für R/type-flow-tenant-costs.R (WS-E; Spec 01 Teil B Abschnitt 3.8, Prüfwerte TC-1, TC-2).

expect_near <- function(actual, expected, tol = 0.006) {
  testthat::expect_true(all(abs(actual - expected) <= tol),
                        info = paste("ist:", paste(format(actual, nsmall = 6), collapse = " "),
                                     "soll:", paste(expected, collapse = " ")))
}

tc1_comps <- function(with_before = TRUE, pv = NULL) {
  ids_e <- c(if (with_before) "e_before_gas_cost", "e_after_hp_cost")
  out <- list()
  if (with_before) {
    out$e_before_gas_cost <- list(type = "energy_cost", state = "before", carrier = "gas",
                                  carrier_class = "gas", quantity_kwh_pa = list(expr = "150000"),
                                  price_eur_kwh = 0.0634, network_fee_eur_kwh = 0.0257,
                                  emission_factor_kg_kwh = 0.18, co2_price_eur_t = 65,
                                  counterfactual_pre = TRUE)
  }
  out$e_after_hp_cost <- list(type = "energy_cost", state = "after", carrier = "hp",
                              carrier_class = "power", quantity_kwh_pa = list(expr = "20000"),
                              price_eur_kwh = 0.21)
  if (with_before) {
    out$e_before_gas_co2 <- list(type = "co2_cost", energy_component = "e_before_gas_cost",
                                 living_area_m2 = 1000, carrier_class = "gas",
                                 all_energy_components = list("e_before_gas_cost"),
                                 pre_energy_components = list("e_before_gas_cost"),
                                 after = list("e_before_gas_cost"))
  }
  if (!is.null(pv)) out$e_pv <- pv
  co2 <- if (with_before) list("e_before_gas_co2") else list()
  pre <- if (with_before) list("e_before_gas_cost") else list()
  out$e_tenant <- list(type = "tenant_costs", energy_components = as.list(ids_e),
                       co2_components = co2, pre_energy_components = pre,
                       pre_co2_components = co2, rented_area_m2 = 1000,
                       pv_component = if (!is.null(pv)) "e_pv",
                       after = as.list(c(ids_e, unlist(co2), if (!is.null(pv)) "e_pv")))
  Filter(Negate(is.null), out)
}

test_that("Vertragstests tenant_costs (Prüfkit 5.6)", {
  expect_type_contract("tenant_costs", "flow")
})

test_that("TC-1: Heizkosten der Mieter vorher/nachher", {
  res <- eop_chain(tc1_comps(), .energy = list(before = list(),
                                               after = list(start_event = "2028-01-01")))
  en <- eop_cy(res, "e_tenant", "energy", 2027:2029)
  pre <- eop_cy(res, "e_tenant", "energy_pre", 2027:2029)
  expect_near(en, c(17157.42, 4998.00, 4998.00))
  expect_near(pre, rep(17157.42, 3))
  expect_near(15904.35 + 0.6 * 2088.45, 17157.42)
  a <- res$flows$e_tenant$aux
  expect_near(a$saving_eur_m2_month[1, 3], 1.013285, 1e-6)
  expect_near(a$saving_eur_m2_month[1, 2], 0, 1e-9)
  expect_near(a$energy_eur_m2_month[1, 3], 4998 / 12000, 1e-9)
  expect_near(a$co2_landlord_relief_eur_m2_month[1, 2], 0.4 * 2088.45 / 12000, 1e-6)
  r <- res$flows$e_tenant$rows
  expect_identical(vapply(r, function(x) x$category, ""),
                   c("tenant_energy_cost", "tenant_energy_cost_pre"))
  expect_false(any(vapply(r, function(x) isTRUE(x$cash), TRUE)))
  expect_vofi_flows_contract(res$flows$e_tenant, res$ctx, reg_get("flow", "tenant_costs"))
})

test_that("TC-2: ohne Vorzustand keine Zeile energy_pre", {
  res <- eop_chain(tc1_comps(with_before = FALSE), .energy = list(after = list()))
  keys <- vapply(res$flows$e_tenant$rows, function(x) x$key, "")
  expect_identical(keys, "energy")
  expect_near(eop_cy(res, "e_tenant", "energy", 2027), 4998.00)
  expect_equal(res$flows$e_tenant$aux$saving_eur_m2_month[1, 2], 0)
})

test_that("PV-Eigenverbrauch mindert die Heizkosten der Mieter (Neuanlage nicht im Vorzustand)", {
  pv <- list(type = "pv", kwp = 10, specific_yield_kwh_kwp = 1000, self_consumption_share = 0.5,
             self_consumption_components = list("e_after_hp_cost"),
             feed_in_tariff_eur_kwh = 0.08, opex_eur_pa = 100, internal_price_eur_kwh = 0.1,
             measure = "pv", after = list("e_after_hp_cost"))
  res <- eop_chain(tc1_comps(pv = pv),
                   .energy = list(before = list(), after = list(start_event = "2028-01-01"),
                                  pv = list(measure = "pv")),
                   .measures = list(pv = list(completion_date = "2027-01-01", cost_eur = 15000)))
  b_pv <- 5000 * 0.21 * 1.19 - 5000 * 0.1
  expect_near(eop_cy(res, "e_tenant", "energy", 2028), 4998 - b_pv, 1e-6)
  expect_near(eop_cy(res, "e_tenant", "energy_pre", 2028), 17157.42)
})
