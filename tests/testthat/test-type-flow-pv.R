# Tests für R/type-flow-pv.R (WS-E; Spec 01 Teil B Abschnitt 3.9, Prüfwerte PV-1 bis PV-4).

expect_near <- function(actual, expected, tol = 0.006) {
  testthat::expect_true(all(abs(actual - expected) <= tol),
                        info = paste("ist:", paste(format(actual, nsmall = 6), collapse = " "),
                                     "soll:", paste(expected, collapse = " ")))
}

eeg <- list(feed_in_tariff = list(partial_le10kwp = 0.0770, partial_10_40kwp = 0.0666,
                                  partial_40_100kwp = 0.0545, full_le10kwp = 0.122))

pv_case <- function(..., market = eeg, perspective = "wu_kommunal", deps = list(),
                    measures = list(), energy = list(), building = list(),
                    grid = make_grid(T = 6L), n = 1L, draws = NULL) {
  comps <- c(deps, list(e_pv = c(list(type = "pv"), list(...))))
  eop_chain(comps, .market = market, .perspective = perspective, .measures = measures,
            .energy = energy, .building = building, .grid = grid, .n = n, .draws = draws)
}

test_that("Vertragstests pv (Prüfkit 5.6)", {
  expect_type_contract("pv", "flow")
})

test_that("PV-1: Mischsatz und Einspeisung 30 kWp (S3-T6)", {
  expect_near(pv_tariff_mix(30, 0.0770, 0.0666, 0.0545), 0.0700667, 1e-7)
  res <- pv_case(kwp = 30, specific_yield_kwh_kwp = 900, self_consumption_share = 0.3,
                 opex_eur_pa = 0, commissioning_date = "2027-01-01")
  expect_near(eop_cy(res, "e_pv", "feed_in_kwh", 2027), 18900, 1e-6)
  expect_near(eop_cy(res, "e_pv", "feed_in", 2027), 1324.26)
  deg <- pv_case(kwp = 30, specific_yield_kwh_kwp = 900, self_consumption_share = 0.3,
                 opex_eur_pa = 0, degradation_pa = 0.003, commissioning_date = "2027-01-01")
  expect_near(eop_cy(deg, "e_pv", "feed_in", 2028), 1320.29)
  r <- res$flows$e_pv$rows
  vr <- vapply(r, function(x) x$vat_rate, 0)
  names(vr) <- vapply(r, function(x) x$key, "")
  expect_equal(unname(vr[c("feed_in", "self_consumption", "internal_sale", "opex")]),
               c(0, 0, 0, 0.19))
  expect_identical(r[[1L]]$tax_category, "income_tax_exempt")
  expect_vofi_flows_contract(res$flows$e_pv, res$ctx, reg_get("flow", "pv"))
})

test_that("PV-1a: Stufe 40 bis 100 kWp und fehlender Satz über 100 kWp", {
  expect_near(pv_tariff_mix(60, 0.0770, 0.0666, 0.0545), 0.0643000, 1e-7)
  expect_near(pv_tariff_mix(100, 0.0770, 0.0666, 0.0545), 0.0603800, 1e-7)
  res <- pv_case(kwp = 60, specific_yield_kwh_kwp = 950, self_consumption_share = 0.2,
                 opex_eur_pa = 0, building = list(n_units = 1L))
  expect_near(eop_cy(res, "e_pv", "feed_in_kwh", 2027), 45600, 1e-6)
  expect_near(eop_cy(res, "e_pv", "feed_in", 2027), 2932.08)
  expect_identical(res$flows$e_pv$rows[[1L]]$tax_category, "income_other_taxable")
  expect_error(pv_case(kwp = 120, self_consumption_share = 0.2, opex_eur_pa = 0),
               class = "vofi_error_input")
  expect_error(pv_case(kwp = 12, feed_in_mode = "full", opex_eur_pa = 0),
               class = "vofi_error_input")
  full <- pv_case(kwp = 8, feed_in_mode = "full", opex_eur_pa = 0, specific_yield_kwh_kwp = 1000)
  expect_near(eop_cy(full, "e_pv", "feed_in", 2027), 8000 * 0.122, 1e-6)
})

pv2_dep <- function(q = "3500") {
  e <- list(type = "energy_cost", state = "before", carrier = "power", carrier_class = "power",
            quantity_kwh_pa = list(expr = q), price_eur_kwh = 0.37, price_basis = "gross",
            owner_share = 1)
  list(e_before_power_cost = e)
}

test_that("PV-2: Selbstnutzer mit Eigenverbrauch (S5)", {
  res <- pv_case(kwp = 8, specific_yield_kwh_kwp = 950, self_consumption_share = 0.35,
                 self_consumption_components = list("e_before_power_cost"), opex_eur_pa = 0,
                 feed_in_tariff_eur_kwh = 0.0778, after = list("e_before_power_cost"),
                 perspective = "selbstnutzer", deps = pv2_dep())
  expect_near(res$flows$e_pv$aux$self_kwh[1, 2], 2660, 1e-6)
  expect_near(eop_cy(res, "e_pv", "self_consumption", 2027), 984.20)
  expect_equal(eop_cy(res, "e_pv", "internal_sale", 2027), 0)
  expect_near(res$flows$e_pv$aux$unit_price_self[1, 2], 0.37, 1e-12)
  expect_identical(res$flows$e_pv$rows[[2L]]$tax_category, "imputed_benefit")
  expect_identical(res$flows$e_pv$rows[[4L]]$tax_category, "expense_nondeductible")
})

test_that("PV-3: Eigenverbrauch begrenzt auf den Bezug", {
  res <- pv_case(kwp = 8, specific_yield_kwh_kwp = 950, self_consumption_share = 0.35,
                 self_consumption_components = list("e_before_power_cost"), opex_eur_pa = 0,
                 feed_in_tariff_eur_kwh = 0.0778, after = list("e_before_power_cost"),
                 perspective = "selbstnutzer", deps = pv2_dep("1000"))
  expect_near(res$flows$e_pv$aux$self_kwh[1, 2], 1000, 1e-9)
  expect_near(eop_cy(res, "e_pv", "feed_in_kwh", 2027), 7600 - 1000, 1e-9)
})

test_that("PV-4: USt-Satz der Investition (Begünstigungsattribut)", {
  expect_equal(pv_investment_vat_rate(45, FALSE), 0.19)
  expect_equal(pv_investment_vat_rate(45, TRUE), 0)
  expect_equal(pv_investment_vat_rate(25, FALSE), 0)
  expect_equal(pv_investment_vat_rate(c(28, 35), FALSE), c(0, 0.19))
})

test_that("Inbetriebnahme mit Maßnahme, Vergütungsende, Betriebskosten und Verrechnung", {
  g <- make_grid(T = 25L)
  res <- pv_case(kwp = 20, specific_yield_kwh_kwp = 1000, self_consumption_share = 0.25,
                 measure = "pv", feed_in_tariff_eur_kwh = 0.07, post_tariff_price_eur_kwh = 0.03,
                 tariff_years = 20L, internal_price_eur_kwh = 0.2, opex_share_of_cost = 0.012,
                 opex_growth = 0.02,
                 measures = list(pv = list(completion_date = "2027-07-01", cost_eur = 30000)),
                 grid = g)
  gen <- eop_cy(res, "e_pv", "generation", 2027:2028)
  expect_near(gen, c(10000, 20000), 1e-9)
  expect_near(eop_cy(res, "e_pv", "opex", 2027:2028), -360 * c(1.02 * 0.5, 1.02^2), 1e-9)
  fi <- eop_cy(res, "e_pv", "feed_in", c(2046, 2047, 2048))
  expect_near(fi, c(15000 * 0.07, 7500 * 0.07 + 7500 * 0.03, 15000 * 0.03), 1e-9)
  expect_near(eop_cy(res, "e_pv", "internal_sale", 2028), 5000 * 0.2, 1e-9)
  expect_near(res$flows$e_pv$aux$self_kwh_rented[1, 3], 5000, 1e-9)
  expect_identical(res$flows$e_pv$rows[[1L]]$measure_id, "pv")
})

test_that("Steuerbefreiung § 3 Nr. 72 EStG: auto, yes, no", {
  expect_true(pv_tax_exempt("auto", 30, 1))
  expect_false(pv_tax_exempt("auto", 45, 1))
  expect_true(pv_tax_exempt("auto", 45, 2))
  expect_false(pv_tax_exempt("auto", 120, 10))
  expect_true(pv_tax_exempt("yes", 120, 1))
  expect_false(pv_tax_exempt("no", 5, 1))
  res <- pv_case(kwp = 45, opex_eur_pa = 0, building = list(n_units = 4L))
  expect_identical(res$flows$e_pv$rows[[1L]]$tax_category, "income_tax_exempt")
  expect_true(res$flows$e_pv$meta$tax_exempt)
})

test_that("Fehlende Betriebskosten ohne Maßnahme sind ein Eingabefehler", {
  expect_error(pv_case(kwp = 10), class = "vofi_error_input")
})

test_that("Batch-Invarianz mit Aktivierung und Verschiebung der Maßnahme", {
  g <- make_grid(T = 6L)
  dr <- fake_draws(4L, g, static = list("measures.pv.active" = c(1, 0, 1, 1),
                                        "measures.pv.delay_months" = c(0, 0, 4, 11)))
  fun <- function(n, draws) {
    pv_case(kwp = 20, specific_yield_kwh_kwp = 950, self_consumption_share = 0.2,
            measure = "pv", opex_eur_pa = 300,
            measures = list(pv = list(completion_date = "2027-07-01", cost_eur = 30000,
                                      active = 1, delay_months = 0)),
            grid = g, n = n, draws = draws)$flows$e_pv
  }
  expect_batch_invariance(fun, n = 4L, grid = g, draws = dr)
  fl <- fun(4L, dr)
  ge <- eop_row(fl, "generation")
  expect_equal(sum(ge[2, ]), 0)
  expect_true(ge[3, 2] < ge[1, 2])
})

test_that("EOP-02: Eigenverbrauch monatlich begrenzt, Zustandswechsel und F10 (annual = mixed)", {
  run <- function(grid) {
    e <- list(type = "energy_cost", state = "after", carrier = "heatpump_power",
              carrier_class = "power_hp", quantity_kwh_pa = list(expr = "8000"),
              price_eur_kwh = 0.25, owner_share = 1)
    pv_case(kwp = 10, specific_yield_kwh_kwp = 1000, self_consumption_share = 0.5,
            self_consumption_components = list("e_after_hp_cost"), opex_eur_pa = 0,
            feed_in_tariff_eur_kwh = 0.08, commissioning_date = "2027-01-01",
            after = list("e_after_hp_cost"), perspective = "selbstnutzer",
            deps = list(e_after_hp_cost = e),
            energy = list(after = list(start_event = "2027-10-01")), grid = grid)
  }
  ra <- run(make_grid("annual", T = 4L))
  rm <- run(make_grid("mixed", T = 4L))
  # Bezug erst ab Oktober: Eigenverbrauch Okt.–Dez. 3 · 416,67 kWh zu 0,25 · 1,19 EUR/kWh
  for (r in list(ra, rm)) {
    expect_near(eop_cy(r, "e_pv", "self_consumption", 2027:2028), c(1250, 5000) * 0.2975, 1e-9)
    expect_near(eop_cy(r, "e_pv", "feed_in", 2027:2028), c(8750, 5000) * 0.08, 1e-9)
    expect_near(eop_cy(r, "e_pv", "feed_in_kwh", 2027), 8750, 1e-9)
  }
  ya <- vapply(c("feed_in", "self_consumption", "internal_sale", "opex"), function(k) {
    eop_cy(ra, "e_pv", k, 2027:2030)
  }, double(4))
  ym <- vapply(c("feed_in", "self_consumption", "internal_sale", "opex"), function(k) {
    eop_cy(rm, "e_pv", k, 2027:2030)
  }, double(4))
  expect_equal(ya, ym, tolerance = 1e-9)
  # Bewertungspreis je Periode: Wert des Eigenverbrauchs / Menge
  expect_near(ra$flows$e_pv$aux$unit_price_self[1, 2], 0.2975, 1e-12)
  # Vergütungsende unterjährig: Einspeisung je Monat mit Satz bzw. Anschlusspreis
  g <- make_grid(T = 6L)
  end <- pv_case(kwp = 10, specific_yield_kwh_kwp = 1200, self_consumption_share = 0,
                 opex_eur_pa = 0, feed_in_tariff_eur_kwh = 0.08, post_tariff_price_eur_kwh = 0.02,
                 tariff_years = 1L, commissioning_date = "2027-07-01", grid = g)
  expect_near(eop_cy(end, "e_pv", "feed_in", 2027:2028),
              c(6000 * 0.08, 6000 * 0.08 + 6000 * 0.02), 1e-9)
})
