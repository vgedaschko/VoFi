# Tests für R/type-flow-operating-cost.R (WS-E; Spec 01 Teil B Abschnitt 2.2, Prüfwerte O-1 bis
# O-4).

expect_near <- function(actual, expected, tol = 0.006) {
  testthat::expect_true(all(abs(actual - expected) <= tol),
                        info = paste("ist:", paste(format(actual, nsmall = 4), collapse = " "),
                                     "soll:", paste(expected, collapse = " ")))
}

vpi <- list(series = list("2027" = 0.028, "2028" = 0.022))

rp4 <- list(type = "rent_path", unit_group = "g", living_area_m2 = 1600, n_units = 24L,
            rent_eur_m2_month = 6.2, increase_policy = "fixed_growth", rent_growth = 0.015,
            growth_from = "2028-01-01", vacancy_rate = 0.03, rent_default_rate = 0.01)

oc_case <- function(..., grid = make_grid(T = 6L), with_rent = TRUE, perspective = "wu_kommunal") {
  oc <- utils::modifyList(list(type = "operating_cost", living_area_m2 = 1600, n_units = 24L,
                               base_date = "2027-01-01", start_event = "2027-01-01"),
                          list(...))
  comps <- list()
  if (with_rent) {
    comps$u_g_rent <- rp4
    oc$rent_component <- "u_g_rent"
  }
  comps$u_g_opex <- oc
  eop_chain(comps, .grid = grid, .perspective = perspective)
}

test_that("Vertragstests operating_cost (Prüfkit 5.6)", {
  expect_type_contract("operating_cost", "flow")
})

test_that("O-1: Verwaltungskosten mit Kalenderjahresindex (Preisstand 2026)", {
  res <- oc_case(admin_per_unit_eur_pa = 367, growth = vpi)
  expect_near(eop_cy(res, "u_g_opex", "admin", 2027:2029), -c(9054.62, 9253.83, 9457.41))
  r <- res$flows$u_g_opex$rows[[1L]]
  expect_identical(c(r$tax_category, r$category), c("expense_deductible", "operating_cost"))
  expect_equal(r$vat_rate, 0)
  expect_vofi_flows_contract(res$flows$u_g_opex, res$ctx, reg_get("flow", "operating_cost"))
})

test_that("O-2: nicht umlagefähige Betriebskosten in % der Sollmiete", {
  res <- oc_case(nonrecoverable_share_of_rent = 0.01)
  expect_near(eop_cy(res, "u_g_rent", "rent", 2027), 119040.00)
  expect_near(eop_cy(res, "u_g_opex", "nonrecoverable", 2027), -1190.40)
  keys <- vapply(res$flows$u_g_opex$rows, function(x) x$key, "")
  expect_identical(keys, c("admin", "nonrecoverable"))
})

test_that("O-3: Betriebskosten im Leerstand und Mietersicht", {
  res <- oc_case(recoverable_opex_eur_m2_month = 1.70, opex_growth = vpi)
  expect_near(eop_cy(res, "u_g_opex", "vacancy_opex", 2027), -1006.62)
  expect_near(eop_cy(res, "u_g_opex", "tenant_opex", 2027), 33553.92)
  expect_near(1.70 * 12 * 1600 * 1.028, 33553.92)
  keys <- vapply(res$flows$u_g_opex$rows, function(x) x$key, "")
  expect_identical(keys, c("admin", "vacancy_opex", "tenant_opex"))
  sel <- oc_case(recoverable_opex_eur_m2_month = 1.70, opex_growth = vpi, owner_occupied = TRUE,
                 with_rent = FALSE, perspective = "selbstnutzer",
                 perspective_tax = "nondeductible")
  expect_near(eop_cy(sel, "u_g_opex", "owner_opex", 2027), -33553.92)
  expect_identical(sel$flows$u_g_opex$rows[[1L]]$tax_category, "expense_nondeductible")
})

test_that("O-4 (F10): Jahressummen auf Raster mixed gleich annual", {
  run <- function(g) {
    res <- oc_case(admin_per_unit_eur_pa = 367, growth = vpi, nonrecoverable_eur_m2_pa = 0.5,
                   recoverable_opex_eur_m2_month = 1.7, opex_growth = 0.025, grid = g,
                   with_rent = FALSE, owner_occupied = TRUE)
    rbind(eop_cy(res, "u_g_opex", "admin", 2027:2031),
          eop_cy(res, "u_g_opex", "nonrecoverable", 2027:2031),
          eop_cy(res, "u_g_opex", "owner_opex", 2027:2031))
  }
  expect_equal(run(make_grid("mixed", T = 6L)), run(make_grid(T = 6L)), tolerance = 1e-9)
})

test_that("Beginn und Ende des Zeitraums (Monatsanteile)", {
  res <- oc_case(admin_per_unit_eur_pa = 100, n_units = 1L, start_event = "2027-07-01",
                 to = "2029-04-01", with_rent = FALSE)
  expect_near(eop_cy(res, "u_g_opex", "admin", 2027:2030), -c(50, 100, 25, 0), 1e-9)
})
