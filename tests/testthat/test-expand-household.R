# Tests des Expanders household (WS-E2, Spec 01 Teil B 3.10.2, H-1).

e2_hh <- function(household, financing = NULL) {
  x <- e2_scenario(perspective = "selbstnutzer", project_type = "sanierung_einzelmassnahmen",
                   building = list(building_type = "EFH", construction_year = 1975L,
                                   n_units = 1L, living_area_m2 = 140,
                                   maintenance = list(basis = "none"),
                                   property_tax = list(amount_eur_pa = 600)),
                   household = household)
  x$financing <- financing %||% list()
  x
}

test_that("H-1: Ersparnis als Einlage h_equity +60.000 in t = 0", {
  spec <- e2_resolve(e2_hh(list(savings_eur = 60000, net_income_month_eur = 5000)))
  h <- spec$financing$h_equity
  expect_identical(h$type, "equity")
  expect_identical(h$amount_eur, node_ref("household.savings_eur"))
  expect_identical(h$date, as.Date("2027-01-01"))
  expect_false("h_contrib" %in% names(spec$financing))
  res <- e2_run(spec)
  expect_equal(e2_row(res, "h_equity__in")[1L], 60000)
})

test_that("h_contrib: laufende Einlage mit Zeitraum; vorhandenes Eigenkapital hat Vorrang", {
  spec <- e2_resolve(e2_hh(list(savings_eur = 10000, contribution_month_eur = 200,
                                contribution_from = "2028-01-01",
                                contribution_to = "2030-01-01",
                                net_income_month_eur = 5000)))
  c <- spec$financing$h_contrib
  expect_identical(c$contributions_pa, node_expr("household.contribution_month_eur * 12"))
  expect_identical(c$start_event, as.Date("2028-01-01"))
  expect_identical(c$to, as.Date("2030-01-01"))
  res <- e2_run(spec)
  expect_equal(e2_row(res, "h_contrib__in")[1:4], c(0, 0, 2400, 2400))
  ek <- list(ek = list(type = "equity", amount_eur = 5000))
  r <- e2_resolve_full(e2_hh(list(savings_eur = 10000, net_income_month_eur = 5000), ek))
  expect_false("h_equity" %in% names(r$value$financing))
  expect_true("expand.household.equity_exists" %in% r$messages)
})
