# Tests für R/type-flow-energy-cost.R (WS-E; Spec 01 Teil B Abschnitte 3.4-3.6, Prüfwerte E-1 bis
# E-10).

expect_near <- function(actual, expected, tol = 0.006) {
  testthat::expect_true(all(abs(actual - expected) <= tol),
                        info = paste("ist:", paste(format(actual, nsmall = 6), collapse = " "),
                                     "soll:", paste(expected, collapse = " ")))
}

ec_cost <- function(res, id, years) {
  -(eop_cy(res, id, "work", years) + eop_cy(res, id, "base_fee", years) +
      eop_cy(res, id, "service", years))
}

test_that("Vertragstests energy_cost (Prüfkit 5.6)", {
  expect_type_contract("energy_cost", "flow")
})

test_that("E-1/E-2: Wärmepumpe gegenüber Gas mit Bruttopreisen (S4-T5/T6)", {
  res <- eop_chain(list(
    e_s_hp = list(type = "energy_cost", state = "before", carrier = "heatpump_power",
                  carrier_class = "power", quantity_kwh_pa = list(expr = "21560 / 2.9"),
                  price_eur_kwh = 0.24, price_basis = "gross", base_fee_eur_pa = 140,
                  service_eur_pa = 250, owner_share = 1),
    e_s_gas = list(type = "energy_cost", state = "before", carrier = "gas",
                   carrier_class = "gas", quantity_kwh_pa = list(expr = "24500"),
                   price_eur_kwh = 0.125, price_includes = "all", price_basis = "gross",
                   base_fee_eur_pa = 180, service_eur_pa = 300, owner_share = 1)
  ), .perspective = "selbstnutzer")
  expect_near(eop_cy(res, "e_s_hp", "quantity", 2027:2029), rep(7434.48, 3))
  hp <- ec_cost(res, "e_s_hp", 2027:2029)
  gas <- ec_cost(res, "e_s_gas", 2027:2029)
  expect_near(hp, rep(2174.28, 3))
  expect_near(hp / 12, rep(181.19, 3))
  expect_near(gas, rep(3542.50, 3))
  expect_near((gas - hp) / 12, rep(114.02, 3))
  wr <- res$flows$e_s_hp$rows[[1L]]
  expect_identical(wr$tax_category, "expense_nondeductible")
  expect_equal(wr$vat_rate, 0.19)
  expect_vofi_flows_contract(res$flows$e_s_hp, res$ctx, reg_get("flow", "energy_cost"))
})

test_that("E-3/E-4: Mengen der Stufen und Performance Gap als Ausdrucksknoten", {
  q <- function(expr) {
    res <- eop_chain(list(e = list(type = "energy_cost", state = "before", carrier = "hp",
                                   carrier_class = "power", quantity_kwh_pa = list(expr = expr),
                                   price_eur_kwh = 0.2)))
    eop_cy(res, "e", "quantity", 2028)
  }
  expect_near(q("21560 * 0.75 / 3.2"), 5053.125, 1e-6)
  expect_near(q("21560 * 0.75 * 0.72 / 3.5"), 3326.40, 1e-6)
  gap <- "(30000 * 0.7 - %s * (30000 * 0.7 - 12000 * 1.1)) / 3"
  expect_near(q(sprintf(gap, "1")), 4400, 1e-6)
  expect_near(q(sprintf(gap, "0.8")), 4920, 1e-6)
})

e5_case <- function(grid = make_grid(T = 10L), n = 1L, draws = NULL, measure = NULL) {
  after <- list(start_event = "2027-10-01")
  meas <- list()
  if (!is.null(measure)) {
    after <- list(measure = measure)
    ms <- list(completion_date = "2027-10-01", cost_eur = 1, active = 1)
    meas <- stats::setNames(list(ms), measure)
  }
  eop_chain(list(
    e_before_gas_cost = list(type = "energy_cost", state = "before", carrier = "gas",
                             carrier_class = "gas", quantity_kwh_pa = list(expr = "280000"),
                             price_eur_kwh = 0.08, emission_factor_kg_kwh = 0.181,
                             ghg_factor_kg_kwh = 0.21672),
    e_after_hp_cost = list(type = "energy_cost", state = "after", carrier = "hp",
                           carrier_class = "power", quantity_kwh_pa = list(expr = "120000 / 2.9"),
                           price_eur_kwh = 0.2, ghg_factor_kg_kwh = 0.56)
  ), .energy = list(before = list(), after = after), .measures = meas, .grid = grid, .n = n,
  .draws = draws)
}

test_that("E-5: Teiljahr beim Zustandswechsel 2027-10-01 (S1 V2)", {
  res <- e5_case()
  expect_near(eop_cy(res, "e_before_gas_cost", "quantity", 2027:2029), c(210000, 0, 0), 1e-6)
  expect_near(eop_cy(res, "e_after_hp_cost", "quantity", 2027:2029),
              c(10344.83, 41379.31, 41379.31))
  w <- en_state_weights(res$ctx, "after")
  expect_equal(w[1, 2:3], c(0.25, 1))
  expect_equal(en_state_weights(res$ctx, "before")[1, 2:3], c(0.75, 0))
})

test_that("E-6: Gesamtpreis mit Netzentgelt und CO2-Kosten (price_includes = all)", {
  res <- eop_chain(list(e = list(
    type = "energy_cost", state = "before", carrier = "gas", carrier_class = "gas",
    quantity_kwh_pa = list(expr = "10000"), price_eur_kwh = 0.125, price_includes = "all",
    price_basis = "gross", network_fee_eur_kwh = 0.0257, emission_factor_kg_kwh = 0.181,
    co2_price_eur_t = list(series = list("2027" = 60, "2028" = 70)), price_base_date = "2027-01-01"
  )))
  a <- res$flows$e$aux
  rest <- a$unit_price_gross[1, 2] / 1.19 - 0.0257
  expect_near(rest, 0.068482, 1e-6)
  per_kwh <- a$unit_price_gross[1, 2:3] + a$co2_gross[1, 2:3] / a$kwh[1, 2:3]
  expect_near(per_kwh, c(0.125000, 0.127154), 1e-6)
  expect_length(res$flows$e$meta$notes, 0L)
  neg <- eop_chain(list(e = list(
    type = "energy_cost", state = "before", carrier = "gas", carrier_class = "gas",
    quantity_kwh_pa = list(expr = "10000"), price_eur_kwh = 0.02, price_includes = "all",
    network_fee_eur_kwh = 0.0257
  )))
  expect_true("types.flow.energy_cost.msg.negative_rest_price" %in% neg$flows$e$meta$note_keys)
  expect_equal(neg$flows$e$aux$unit_price_gross[1, 2], 0.0257 * 1.19)
})

test_that("E-7 (F10): Jahressummen auf Raster mixed gleich annual", {
  run <- function(g) {
    res <- e5_case(grid = g)
    rbind(eop_cy(res, "e_before_gas_cost", "work", 2027:2032),
          eop_cy(res, "e_after_hp_cost", "work", 2027:2032),
          eop_cy(res, "e_after_hp_cost", "quantity", 2027:2032))
  }
  a <- run(make_grid(T = 10L))
  m <- run(make_grid("mixed", T = 10L))
  expect_equal(m, a, tolerance = 1e-9)
})

test_that("E-8: Treibhausgasbilanz vorher/nachher", {
  res <- eop_chain(list(
    e_before_gas_cost = list(type = "energy_cost", state = "before", carrier = "gas",
                             carrier_class = "gas", quantity_kwh_pa = list(expr = "150000"),
                             price_eur_kwh = 0.08, ghg_factor_kg_kwh = 0.21672),
    e_after_hp_cost = list(type = "energy_cost", state = "after", carrier = "hp",
                           carrier_class = "power", quantity_kwh_pa = list(expr = "20000"),
                           price_eur_kwh = 0.2, ghg_factor_kg_kwh = 0.56)
  ), .energy = list(before = list(), after = list(start_event = "2028-01-01")))
  em <- eop_cy(res, "e_before_gas_cost", "emission", 2027:2029) +
    eop_cy(res, "e_after_hp_cost", "emission", 2027:2029)
  expect_near(em, c(32.508, 11.200, 11.200), 1e-9)
  ref <- eop_chain(list(
    e_before_gas_cost = list(type = "energy_cost", state = "before", carrier = "gas",
                             carrier_class = "gas", quantity_kwh_pa = list(expr = "150000"),
                             price_eur_kwh = 0.08, ghg_factor_kg_kwh = 0.21672)
  ), .energy = list(before = list()))
  expect_near(eop_cy(ref, "e_before_gas_cost", "emission", 2028:2030) - em[c(2, 3, 3)],
              rep(21.308, 3), 1e-9)
  r <- res$flows$e_after_hp_cost$rows[[5L]]
  expect_identical(c(r$section, r$category, r$unit), c("memo", "co2_emission", "t_co2"))
})

test_that("E-10: Aktivierung der Maßnahme des Zustands (1, 0)", {
  g <- make_grid(T = 10L)
  dr <- fake_draws(2L, g, static = list("measures.k.active" = c(1, 0)))
  res <- e5_case(grid = g, n = 2L, draws = dr, measure = "k")
  expect_near(eop_cy(res, "e_before_gas_cost", "quantity", 2027:2029, sim = 1L),
              c(210000, 0, 0), 1e-6)
  expect_near(eop_cy(res, "e_before_gas_cost", "quantity", 2027:2029, sim = 2L),
              rep(280000, 3), 1e-6)
  expect_near(eop_cy(res, "e_after_hp_cost", "quantity", 2027:2029, sim = 2L), rep(0, 3), 1e-9)
  expect_near(eop_cy(res, "e_after_hp_cost", "quantity", 2028, sim = 1L), 41379.31)
})

test_that("Kostenträger: Eigentümeranteil, Leerstand und vacancy_landlord", {
  g <- make_grid(T = 6L)
  base <- list(type = "energy_cost", state = "before", carrier = "gas", carrier_class = "gas",
               quantity_kwh_pa = list(expr = "100000"), price_eur_kwh = 0.1, owner_share = 0.2,
               unit_groups = list("g"))
  res <- eop_chain(list(e1 = base, e2 = utils::modifyList(base, list(vacancy_landlord = FALSE))),
                   .grid = g, .unit_groups = list(g = list(living_area_m2 = 1000,
                                                           vacancy_rate = 0.05)))
  f1 <- res$flows$e1$aux$cost_share_owner_landlord[1, 2]
  expect_equal(res$flows$e1$aux$vacancy[1, 2], 0.05)
  expect_equal(f1, 0.2 + 0.8 * 0.05)
  expect_equal(res$flows$e2$aux$cost_share_owner_landlord[1, 2], 0.2)
  w <- -eop_cy(res, "e1", "work", 2027)
  expect_near(w, 100000 * 0.1 * 1.19 * f1, 1e-6)
})

test_that("Kontrafaktischer Vorzustand: Hilfsgrößen über den ganzen Horizont", {
  res <- eop_chain(list(
    e_before_gas_cost = list(type = "energy_cost", state = "before", carrier = "gas",
                             carrier_class = "gas", quantity_kwh_pa = list(expr = "150000"),
                             price_eur_kwh = 0.0634, counterfactual_pre = TRUE,
                             base_fee_eur_pa = 100)
  ), .energy = list(before = list(), after = list(start_event = "2028-01-01")))
  a <- res$flows$e_before_gas_cost$aux
  expect_equal(a$kwh[1, 2:3], c(150000, 0))
  expect_equal(a$cf_kwh[1, 2:4], rep(150000, 3))
  expect_near(a$cf_work_gross[1, 3], 150000 * 0.0634 * 1.19, 1e-6)
  expect_near(a$cf_fees_gross[1, 3], 119, 1e-9)
})

test_that("Alterung und Fortschreibung mit Kalenderjahresindex", {
  res <- eop_chain(list(e = list(
    type = "energy_cost", state = "before", carrier = "gas", carrier_class = "gas",
    quantity_kwh_pa = list(expr = "10000"), price_eur_kwh = 0.1, price_growth = 0.02,
    efficiency_degradation_pa = 0.01, installation_date = "2025-01-01",
    price_base_date = "2027-01-01", vat_rate = 0, owner_share = 1
  )))
  q <- eop_cy(res, "e", "quantity", 2027:2028)
  expect_near(q, 10000 * 1.01^c(2, 3), 1e-6)
  expect_near(-eop_cy(res, "e", "work", 2028), 10000 * 1.01^3 * 0.1 * 1.02^2, 1e-6)
  expect_equal(res$flows$e$rows[[1L]]$vat_rate, 0)
})

test_that("Batch-Invarianz mit Verschiebung und Aktivierung der Maßnahme", {
  g <- make_grid(T = 6L)
  dr <- fake_draws(5L, g, static = list("measures.k.delay_months" = c(0, 2, 5, 13, 0),
                                        "measures.k.active" = c(1, 1, 0, 1, 1)))
  fun <- function(n, draws) {
    res <- eop_chain(list(
      e_before_gas_cost = list(type = "energy_cost", state = "before", carrier = "gas",
                               carrier_class = "gas", quantity_kwh_pa = list(expr = "28000"),
                               price_eur_kwh = 0.08, counterfactual_pre = TRUE),
      e_after_hp_cost = list(type = "energy_cost", state = "after", carrier = "hp",
                             carrier_class = "power", quantity_kwh_pa = list(expr = "9000"),
                             price_eur_kwh = 0.25)
    ), .energy = list(before = list(), after = list(measure = "k")),
    .measures = list(k = list(completion_date = "2027-10-01", cost_eur = 1, active = 1,
                              delay_months = 0)),
    .grid = g, .n = n, .draws = draws)
    c(a = reg_row_values(res$flows$e_before_gas_cost),
      b = reg_row_values(res$flows$e_after_hp_cost))
  }
  expect_batch_invariance(fun, n = 5L, grid = g, draws = dr)
  v <- fun(5L, dr)
  q <- v[["b.quantity"]]
  expect_equal(sum(q[3, ]), 0)
  expect_true(q[4, 2] < q[1, 2])
  expect_true(q[2, 2] < q[1, 2])
})
