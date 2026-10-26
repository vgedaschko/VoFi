# Tests für R/type-flow-imputed-rent.R (WS-E; Spec 01 Teil B Abschnitt 3.10.3, Prüfwert H-2).

test_that("Vertragstests imputed_rent (Prüfkit 5.6)", {
  expect_type_contract("imputed_rent", "flow")
})

test_that("H-2: ersparte Miete mit Stichtagsniveau", {
  res <- eop_chain(list(h_rent = list(type = "imputed_rent", area_m2 = 140,
                                      rent_eur_m2_month = 9, growth = 0.015)),
                   .perspective = "selbstnutzer")
  v <- eop_cy(res, "h_rent", "value", 2027:2028)
  expect_equal(v, c(15120.00, 15346.80), tolerance = 1e-12)
  r <- res$flows$h_rent$rows[[1L]]
  expect_identical(c(r$section, r$category, r$tax_category),
                   c("project", "imputed_rent", "imputed_benefit"))
  expect_vofi_flows_contract(res$flows$h_rent, res$ctx, reg_get("flow", "imputed_rent"))
})

test_that("Beginn mit Token completion und Rasterinvarianz (F10)", {
  run <- function(g) {
    res <- eop_chain(list(h_rent = list(type = "imputed_rent", area_m2 = 100,
                                        rent_eur_m2_month = 10, growth = 0.02,
                                        start_event = "2027-10-01")), .grid = g)
    eop_cy(res, "h_rent", "value", 2027:2031)
  }
  a <- run(make_grid(T = 6L))
  expect_equal(a[1:2], c(3000, 12240), tolerance = 1e-12)
  expect_equal(run(make_grid("mixed", T = 6L)), a, tolerance = 1e-9)
})
