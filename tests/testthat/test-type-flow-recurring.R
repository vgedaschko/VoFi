# Tests des Zahlungstyps recurring (WS-E-INV; Spec 00 7.12, Spec 01 Teil A 4.14, Prüfwert F10).

rec_build <- function(..., grid = make_grid("annual", T = 10L), n = 1L, draws = NULL) {
  comps <- list(r = utils::modifyList(list(type = "recurring"), list(...)))
  wsei_build(comps, grid, n = n, draws = draws)$flows$r
}

test_that("Vertrag und Registrierung (grid_invariant, F10)", {
  expect_type_contract("recurring", "flow")
  expect_true(reg_get("flow", "recurring")$grid_invariant)
})

test_that("F10: 14.000, 2 %, Basis = Stichtag -> Jahressumme 2027 = 14.280 auf annual und G4", {
  args <- list(amount_eur = 14000, growth = 0.02, base_date = "2027-01-01",
               start_event = "2027-01-01", category = "rent")
  ga <- make_grid("annual", T = 6L)
  va <- wsei_row(do.call(rec_build, c(args, list(grid = ga))), "value")
  expect_equal(sum(va[ga$year == 2027]), 14280)
  g4 <- make_grid("mixed", T = 6L)
  v4 <- wsei_row(do.call(rec_build, c(args, list(grid = g4))), "value")
  expect_equal(sum(v4[g4$year == 2027]), 14280)
  # Index innerhalb des Kalenderjahres konstant: alle Monatswerte 2027 gleich
  expect_equal(unique(round(v4[2:10], 8)), round(14280 / 12, 8))
  for (y in 2028:2032) {
    expect_equal(sum(v4[g4$year == y]), sum(va[ga$year == y]), tolerance = 1e-12)
  }
})

test_that("Orakel (b): Basis 2028-01-01 ergibt 14.000 * 1,02^(t-1)", {
  f <- rec_build(amount_eur = 14000, growth = 0.02, base_date = "2028-01-01",
                 start_event = "2027-01-01", category = "rent")
  v <- wsei_row(f, "value")
  expect_equal(v[1], 0)
  expect_equal(v[2:11], 14000 * 1.02^(0:9), tolerance = 1e-12)
  r <- f$rows[[1]]
  expect_identical(c(r$section, r$category, r$tax_category), c("project", "rent",
                                                               "income_rental"))
})

test_that("Vorzeichen nach Kategorie, Richtung bei +/- Kategorien; Abschnitt grants", {
  v <- wsei_row(rec_build(amount_eur = 1000, start_event = "2027-01-01",
                          category = "operating_cost"), "value")
  expect_true(all(v[-1] == -1000))
  vp <- wsei_row(rec_build(amount_eur = 1000, start_event = "2027-01-01",
                           category = "passthrough", direction = "inflow"), "value")
  expect_true(all(vp[-1] == 1000))
  vo <- wsei_row(rec_build(amount_eur = 1000, start_event = "2027-01-01",
                           category = "custom", direction = "outflow"), "value")
  expect_true(all(vo[-1] == -1000))
  expect_error(rec_build(amount_eur = 1000, category = "passthrough"),
               class = "vofi_error_contract")
  fg <- rec_build(amount_eur = 500, start_event = "2027-01-01", category = "operating_subsidy")
  expect_identical(fg$rows[[1]]$section, "grants")
  expect_error(rec_build(amount_eur = 1000, category = "renta"), class = "vofi_error_contract")
})

test_that("start_event (Default completion), to, Verschiebung und Wachstumspfad", {
  g4 <- make_grid("mixed", T = 4L)
  f <- rec_build(amount_eur = 1200, category = "other_cost", grid = g4)
  v <- wsei_row(f, "value")
  expect_true(all(v[g4$date_end <= g4$completion_date] == 0))
  expect_equal(sum(v[g4$year == 2027]), -300)
  f2 <- rec_build(amount_eur = 1200, category = "other_cost", start_event = "2027-01-01",
                  to = "2029-07-01")
  v2 <- wsei_row(f2, "value")
  expect_equal(v2[2:5], c(-1200, -1200, -600, 0))
  dr <- fake_draws(2L, g4, static = list("project.construction_delay_months" = c(0, 3)))
  fc <- rec_build(amount_eur = 1200, category = "other_cost", grid = g4, n = 2L, draws = dr)
  y27 <- g4$year == 2027
  expect_equal(rowSums(fc$rows[[1]]$values[, y27, drop = FALSE]), c(-300, 0))
  fp <- rec_build(amount_eur = 1000, category = "rent", start_event = "2027-01-01",
                  base_date = "2027-01-01",
                  growth = list(series = list("2027" = 0.10, "2028" = 0), fill = "locf"))
  vp <- wsei_row(fp, "value")
  expect_equal(vp[2:4], c(1100, 1100, 1100), tolerance = 1e-12)
})

test_that("base_date Default: (project.price_base_year + 1)-01-01", {
  g <- make_grid("annual", T = 3L)
  comps <- list(r = list(type = "recurring", amount_eur = 1000, growth = 0.1,
                         start_event = "2027-01-01", category = "rent"))
  sf <- function(s) {
    s$project$price_base_year <- 2027L
    s
  }
  # Jahresindex = Niveau zum Ende des Kalenderjahres relativ zu base_date (R-62)
  v <- wsei_row(wsei_build(comps, g, spec_fun = sf)$flows$r, "value")
  expect_equal(v[2:4], 1000 * 1.1^c(0, 1, 2), tolerance = 1e-12)
  v0 <- wsei_row(wsei_build(comps, g)$flows$r, "value")
  expect_equal(v0[2:4], 1000 * 1.1^c(1, 2, 3), tolerance = 1e-12)
})

test_that("validate(): Form, Vorzeichen, Richtung, Zeitraum, Kategoriehinweis", {
  f <- wsei_findings("recurring", amount_eur = list(start = 100, growth = 0.02),
                     category = "rent")
  expect_identical(unname(f["components.amount_form"]), "error")
  f <- wsei_findings("recurring", amount_eur = 100, category = "passthrough")
  expect_identical(unname(f["components.direction_missing"]), "error")
  f <- wsei_findings("recurring", amount_eur = 100, category = "rent", direction = "outflow")
  expect_identical(unname(f["components.direction_conflict"]), "error")
  f <- wsei_findings("recurring", amount_eur = 100, category = "rent",
                     start_event = "2030-01-01", to = "2029-01-01")
  expect_identical(unname(f["components.start_after_to"]), "error")
  f <- wsei_findings("recurring", amount_eur = 100, category = "rnet")
  expect_identical(unname(f["components.category_invalid"]), "error")
  f <- wsei_findings("recurring", amount_eur = 100, category = "rent",
                     tax_category = "capex_land")
  expect_identical(unname(f["components.tax_category_invalid"]), "error")
  sc <- make_spec(make_grid())
  attr(sc, "provenance") <- data.frame(path = "components.x.category",
                                       source_type = "type_default")
  f <- wsei_findings("recurring", amount_eur = 100, scenario = sc)
  expect_identical(unname(f["components.category_assumed"]), "info")
  expect_length(wsei_findings("recurring", amount_eur = 100, category = "rent"), 0L)
})

test_that("Batch-Invarianz", {
  g4 <- make_grid("mixed", T = 6L)
  st <- list(
    "components.r.amount_eur" = c(14000, 12000, 15000, 9000),
    "components.r.start_event_shift_months" = c(0, 2, 7, 13)
  )
  dr <- fake_draws(4L, g4, static = st)
  comps <- list(r = list(type = "recurring", amount_eur = 14000, growth = 0.02,
                         base_date = "2027-01-01", start_event = "2027-03-01",
                         category = "rent"))
  fun <- function(n, draws) wsei_build(comps, g4, n = n, draws = draws)$flows$r
  expect_batch_invariance(fun, n = 4L, grid = g4, draws = dr)
})
