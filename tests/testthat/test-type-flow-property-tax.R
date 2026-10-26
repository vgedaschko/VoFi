# Tests für R/type-flow-property-tax.R (WS-E; Spec 01 Teil B Abschnitt 2.3, Prüfwerte O-5 bis
# O-7).

expect_near <- function(actual, expected, tol = 0.006) {
  testthat::expect_true(all(abs(actual - expected) <= tol),
                        info = paste("ist:", paste(format(actual, nsmall = 4), collapse = " "),
                                     "soll:", paste(expected, collapse = " ")))
}

rp_vac <- list(type = "rent_path", unit_group = "g", living_area_m2 = 1600, n_units = 24L,
               rent_eur_m2_month = 6.2, vacancy_rate = 0.03)

pt_case <- function(..., grid = make_grid(T = 6L), with_rent = TRUE,
                    perspective = "wu_kommunal") {
  pt <- utils::modifyList(list(type = "property_tax", growth = 0.028, base_date = "2027-01-01"),
                          list(...))
  comps <- list()
  if (with_rent) {
    comps$u_g_rent <- rp_vac
    pt$rent_component <- "u_g_rent"
  }
  comps$u_g_property_tax <- pt
  eop_chain(comps, .grid = grid, .perspective = perspective)
}

test_that("Vertragstests property_tax (Prüfkit 5.6)", {
  expect_type_contract("property_tax", "flow")
})

test_that("O-5: vermietet, Leerstandsanteil und Mieteranteil", {
  res <- pt_case(amount_eur_pa = 6000)
  expect_near(eop_cy(res, "u_g_property_tax", "cost", 2027), -185.04)
  expect_near(eop_cy(res, "u_g_property_tax", "tenant_share", 2027), 6168.00)
  r <- res$flows$u_g_property_tax$rows[[1L]]
  expect_identical(c(r$category, r$tax_category, r$is_tax),
                   c("property_tax", "expense_deductible", "grundsteuer"))
  expect_vofi_flows_contract(res$flows$u_g_property_tax, res$ctx,
                             reg_get("flow", "property_tax"))
})

test_that("O-6: Selbstnutzer trägt die Grundsteuer voll", {
  res <- pt_case(amount_eur_pa = 1600, owner_occupied = TRUE, with_rent = FALSE,
                 perspective = "selbstnutzer")
  expect_near(eop_cy(res, "u_g_property_tax", "cost", 2027), -1644.80)
  keys <- vapply(res$flows$u_g_property_tax$rows, function(x) x$key, "")
  expect_identical(keys, "cost")
  expect_identical(res$flows$u_g_property_tax$rows[[1L]]$tax_category, "expense_nondeductible")
})

test_that("O-7: Neubau, Grundstück bis zur Fertigstellung voll kostenwirksam", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 8L, construction_months = 24L)
  res <- pt_case(amount_eur_pa = 6000, land_amount_eur_pa = 900, occupancy_from = "completion",
                 grid = g)
  expect_near(eop_cy(res, "u_g_property_tax", "cost", 2027), -925.20)
  expect_near(eop_cy(res, "u_g_property_tax", "cost", 2028), -900 * 1.028^2)
  expect_equal(eop_cy(res, "u_g_property_tax", "tenant_share", 2027:2028), c(0, 0))
  expect_near(eop_cy(res, "u_g_property_tax", "tenant_share", 2029), 6000 * 1.028^3, 1e-6)
})

test_that("Nachfeststellung zum 1. Januar nach dem Bezug", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 8L, construction_months = 9L)
  res <- pt_case(amount_eur_pa = 1000, amount_after_completion_eur_pa = 3000, growth = 0,
                 occupancy_from = "completion", owner_occupied = TRUE, with_rent = FALSE,
                 grid = g)
  expect_near(eop_cy(res, "u_g_property_tax", "cost", 2027:2029), -c(1000, 3000, 3000), 1e-9)
  ex <- pt_case(amount_eur_pa = 1000, amount_after_completion_eur_pa = 3000, growth = 0,
                after_completion_from = "2028-07-01", owner_occupied = TRUE, with_rent = FALSE)
  expect_near(eop_cy(ex, "u_g_property_tax", "cost", 2027:2029), -c(1000, 2000, 3000), 1e-9)
})

test_that("EOP-07: Bestand mit Bauphase, Nachfeststellung nach der Fertigstellung", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 6L, construction_months = 12L)
  run <- function(delay = 0) {
    pt <- list(type = "property_tax", amount_eur_pa = 1000, amount_after_completion_eur_pa = 2000,
               growth = 0, occupancy_from = "2027-01-01", owner_occupied = TRUE)
    eop_chain(list(u_g_property_tax = pt), .grid = g,
              .project = list(construction_delay_months = delay))
  }
  # Fertigstellung 2028-01-01 (Mieter bleiben): neuer Betrag ab dem 1. Januar danach (2029)
  expect_near(eop_cy(run(), "u_g_property_tax", "cost", 2027:2030),
              -c(1000, 1000, 2000, 2000), 1e-9)
  # Bauzeitverzug 13 Monate: Fertigstellung 2029-02-01, neuer Betrag ab 2030
  expect_near(eop_cy(run(13), "u_g_property_tax", "cost", 2027:2030),
              -c(1000, 1000, 1000, 2000), 1e-9)
})
