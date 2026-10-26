# Tests des Zahlungstyps maintenance (WS-E-INV; Spec 01 Teil A 4.11, Prüfwerte M1-M8).

maint_growth <- function() list(series = list("2027" = 0.04, "2028" = 0.03), fill = "locf")

by_year <- function(v, grid) {
  stats::setNames(v[-1L], grid$year[-1L])
}

test_that("Vertrag und Registrierung (grid_invariant, F10)", {
  expect_type_contract("maintenance", "flow")
  expect_true(reg_get("flow", "maintenance")$grid_invariant)
})

test_that("M1: Pauschale 14,40 EUR/m2 x 1.600 m2 mit Kalenderjahresindex", {
  g <- make_grid("annual", T = 30L)
  res <- wsei_build(list(mm = list(type = "maintenance", basis = "rate", rate_eur_m2_pa = 14.40,
                                   area_m2 = 1600, price_base_year = 2026L,
                                   growth = maint_growth(), start_event = "2027-01-01")), g)
  v <- wsei_row(res$flows$mm, "cost")
  expect_equal(round(v[2:4], 2), c(-23961.60, -24680.45, -25420.86))
  row <- res$flows$mm$rows[[1]]
  expect_identical(row$category, "maintenance")
  expect_identical(row$tax_category, "expense_deductible")
  expect_equal(row$vat_rate, 0.19)
})

test_that("M2: M1 auf G4 ab Fertigstellung 2027-10-01; Jahressumme rasterunabhängig", {
  g4 <- make_grid("mixed", T = 30L)
  res <- wsei_build(list(mm = list(type = "maintenance", basis = "rate", rate_eur_m2_pa = 14.40,
                                   area_m2 = 1600, price_base_year = 2026L,
                                   growth = maint_growth(), start_event = "2027-10-01")), g4)
  v <- wsei_row(res$flows$mm, "cost")
  expect_equal(round(v[10:12], 2), c(0, -5990.40, -24680.45))
  expect_equal(sum(v[g4$year == 2027]), -23961.60 * 3 / 12)
  # Token completion: Beginn mit der Rasterfertigstellung inklusive Bauzeitverzug
  dr <- fake_draws(2L, g4, static = list("project.construction_delay_months" = c(0, 3)))
  res2 <- wsei_build(list(mm = list(type = "maintenance", rate_eur_m2_pa = 14.40, area_m2 = 1600,
                                    price_base_year = 2026L, growth = maint_growth(),
                                    start_event = "completion")), g4, n = 2L, draws = dr)
  v2 <- res2$flows$mm$rows[[1]]$values
  expect_equal(round(v2[1, 11], 2), -5990.40)
  expect_equal(v2[2, 11], 0)
  # Lauf 2: Fertigstellung 2028-01-01 -> volles Jahr 2028
  expect_equal(round(v2[2, 12], 2), -24680.45)
})

test_that("M3: II. BV mit Bezugsfertigkeit 2004 und Alters-Reset durch eine Maßnahme", {
  g <- make_grid("annual", T = 30L)
  comps <- list(
    cx = list(type = "capex", date = "2030-01-01", cost_eur = 1, price_index = 0,
              asset_id = "b1", measure_id = "m1"),
    mm = list(type = "maintenance", basis = "iibv", area_m2 = 1000, reference_year = 2004L,
              iibv_rates = list(lt22y = 11.50, ge22y = 14.58, ge32y = 18.62), growth = 0,
              reset_capex_ids = "cx", start_event = "2027-01-01", after = "cx")
  )
  y <- by_year(wsei_row(wsei_build(comps, g)$flows$mm, "cost"), g)
  expect_equal(unname(y[c("2027", "2028", "2029")]), rep(-14580, 3))
  expect_equal(unname(y[as.character(2030:2050)]), rep(-11500, 21))
  expect_equal(unname(y["2051"]), -14580)
  comps$mm$reset_capex_ids <- list()
  y0 <- by_year(wsei_row(wsei_build(comps, g)$flows$mm, "cost"), g)
  expect_equal(unname(y0[c("2035", "2036")]), c(-14580, -18620))
  # Reset nur in Läufen mit a_c = 1
  dr <- fake_draws(2L, g, static = list("components.cx.active" = c(1, 0)))
  comps$mm$reset_capex_ids <- list("cx")
  v2 <- wsei_build(comps, g, n = 2L, draws = dr)$flows$mm$rows[[1]]$values
  expect_equal(v2[1, which(g$year == 2036)[1]], -11500)
  expect_equal(v2[2, which(g$year == 2036)[1]], -18620)
  # Zu-/Abschläge
  comps$mm$iibv_adjust_eur_m2_pa <- 1.63
  comps$mm$reset_capex_ids <- list()
  y1 <- by_year(wsei_row(wsei_build(comps, g)$flows$mm, "cost"), g)
  expect_equal(unname(y1["2027"]), -(14.58 + 1.63) * 1000)
})

test_that("M4: bauteilbezogene Instandsetzung (share_of_cost) ab Fertigstellung", {
  g <- make_grid("annual", T = 30L)
  comps <- list(
    wp = list(type = "capex", date = "2028-01-01", cost_eur = 32000, price_index = 0,
              asset_id = "b1", measure_id = "m1"),
    mt = list(type = "maintenance", basis = "share_of_cost", share_pa = 0.010, capex_id = "wp",
              growth = 0)
  )
  v <- wsei_row(wsei_build(comps, g)$flows$mt, "cost")
  expect_equal(v[1:4], c(0, 0, -320, -320))
  expect_true(all(v[3:31] == -320))
})

test_that("M5: Faktor einer wirkenden Maßnahme (Memo 07 S1 V2: 10/14,40) und Wirkungsdauer", {
  g <- make_grid("annual", T = 30L)
  comps <- list(
    cx = list(type = "capex", date = "2030-01-01", cost_eur = 1, price_index = 0,
              asset_id = "b1", measure_id = "m1"),
    mm = list(type = "maintenance", rate_eur_m2_pa = 14.40, area_m2 = 1000, growth = 0,
              factors = list(cx = 10 / 14.40), start_event = "2027-01-01", after = "cx")
  )
  y <- by_year(wsei_row(wsei_build(comps, g)$flows$mm, "cost"), g)
  expect_equal(unname(y[c("2027", "2028", "2029")]), rep(-14400, 3))
  expect_equal(unname(y[c("2030", "2056")]), c(-10000, -10000), tolerance = 1e-12)
  comps$mm$factor_years <- list(cx = 10)
  y2 <- by_year(wsei_row(wsei_build(comps, g)$flows$mm, "cost"), g)
  expect_equal(unname(y2["2039"]), -10000, tolerance = 1e-12)
  expect_equal(unname(y2["2040"]), -14400)
})

test_that("M6/M7: Doppelzählung Pauschale/Ersatz und Kennwert der expliziten Erneuerungen", {
  g <- make_grid("annual", T = 30L)
  sc <- make_spec(g)
  sc$components$el <- make_component("replacement", include_initial = FALSE,
                                     install_date = "2000-01-01", useful_life_years = 15,
                                     cost_eur = 60000, id = "el")
  f <- wsei_findings("maintenance", rate_eur_m2_pa = 14.4, area_m2 = 1000, scenario = sc)
  expect_identical(unname(f["double_count"]), "warning")
  sc$building$maintenance <- list(excludes_explicit_replacements = TRUE)
  comp <- make_component("maintenance", rate_eur_m2_pa = 14.4, area_m2 = 1000, id = "mm")
  out <- maintenance_validate(comp, path_set(sc, "components.mm", comp))
  codes <- vapply(out, function(x) x$code, "")
  expect_false(any(grepl("double_count", codes)))
  hit <- out[[which(grepl("replacements_excluded", codes))]]
  expect_identical(hit$severity, "info")
  # Ersatz 2030-01-01 und 2045-01-01 (je 60.000) im Horizont 2027-2057: 120.000 / (30 x 1.000)
  expect_equal(hit$args$value, 4)
  expect_type(do.call(msg, c(list(hit$code), hit$args)), "character")
  # Erhaltungsmaßnahme (Ohnehin-Anteil 1) zählt ebenfalls
  sc2 <- make_spec(g)
  sc2$components$dach <- make_component("capex", date = 2030, cost_eur = 1, ohnehin_share = 1,
                                        asset_id = "b1", measure_id = "m1", id = "dach")
  f2 <- wsei_findings("maintenance", rate_eur_m2_pa = 14.4, area_m2 = 1000, scenario = sc2)
  expect_identical(unname(f2["double_count"]), "warning")
  f3 <- wsei_findings("maintenance", rate_eur_m2_pa = 0, area_m2 = 1000, scenario = sc2)
  expect_false("double_count" %in% names(f3))
})

test_that("M8: Neubau mit II. BV ab Fertigstellung (Bezugsfertigkeit 2028)", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 40L, construction_months = 24L)
  res <- wsei_build(list(mm = list(type = "maintenance", basis = "iibv", area_m2 = 1000,
                                   reference_year = 2028L, growth = 0,
                                   iibv_rates = list(lt22y = 11.50, ge22y = 14.58, ge32y = 18.62),
                                   start_event = "completion")), g)
  y <- by_year(wsei_row(res$flows$mm, "cost"), g)
  expect_equal(unname(y[c("2027", "2028")]), c(0, 0))
  expect_equal(unname(y[as.character(2029:2049)]), rep(-11500, 21))
  expect_equal(unname(y[as.character(2050:2059)]), rep(-14580, 10))
  expect_equal(unname(y[as.character(2060:2066)]), rep(-18620, 7))
  # Bezugsfertigkeit aus building.first_occupancy_year
  res2 <- wsei_build(list(mm = list(type = "maintenance", basis = "iibv", area_m2 = 1000,
                                    growth = 0, start_event = "completion",
                                    iibv_rates = list(lt22y = 11.50, ge22y = 14.58,
                                                      ge32y = 18.62))), g,
                     spec_fun = function(s) {
                       s$building$first_occupancy_year <- 2028L
                       s
                     })
  expect_identical(wsei_row(res2$flows$mm, "cost"), wsei_row(res$flows$mm, "cost"))
})

test_that("Steuerkategorie nach Perspektive; ausdrückliche Angabe gewinnt", {
  g <- make_grid("annual", T = 6L)
  mm <- list(mm = list(type = "maintenance", rate_eur_m2_pa = 10, area_m2 = 100,
                       start_event = "2027-01-01", growth = 0))
  r1 <- wsei_build(mm, g, perspective = "selbstnutzer")
  expect_identical(r1$flows$mm$rows[[1]]$tax_category, "expense_nondeductible")
  mm$mm$tax_category <- "capex_expensable"
  r2 <- wsei_build(mm, g)
  expect_identical(r2$flows$mm$rows[[1]]$tax_category, "capex_expensable")
})

test_that("Fehlende Pflichtangaben sind Vertragsfehler bzw. Befunde", {
  g <- make_grid("annual", T = 6L)
  expect_error(wsei_build(list(mm = list(type = "maintenance", area_m2 = 100)), g),
               class = "vofi_error_contract")
  expect_error(wsei_build(list(mm = list(type = "maintenance", rate_eur_m2_pa = 1)), g),
               class = "vofi_error_contract")
  expect_error(wsei_build(list(mm = list(type = "maintenance", basis = "iibv", area_m2 = 100,
                                         reference_year = 2000L)), g),
               class = "vofi_error_contract")
  expect_error(wsei_build(list(mm = list(type = "maintenance", basis = "iibv", area_m2 = 100,
                                         iibv_rates = list(lt22y = 1, ge22y = 2, ge32y = 3))),
                          g),
               class = "vofi_error_contract")
  expect_error(wsei_build(list(mm = list(type = "maintenance", basis = "share_of_cost")), g),
               class = "vofi_error_contract")
  f <- wsei_findings("maintenance", basis = "rate")
  expect_true(all(c("rate_missing", "area_missing") %in% names(f)))
  f <- wsei_findings("maintenance", basis = "iibv", area_m2 = 1)
  expect_identical(unname(f["iibv_rates_missing"]), "error")
  f <- wsei_findings("maintenance", basis = "share_of_cost")
  expect_identical(unname(f["share_incomplete"]), "error")
  f <- wsei_findings("maintenance", rate_eur_m2_pa = 1, area_m2 = 1, start_event = "2030-01-01",
                     to = "2029-01-01")
  expect_identical(unname(f["start_after_to"]), "error")
})

test_that("Batch-Invarianz (Satz, Fläche und Faktor je Lauf)", {
  g <- make_grid("mixed", T = 6L)
  comps <- list(
    cx = list(type = "capex", date = "2028-04-01", cost_eur = 1, price_index = 0,
              asset_id = "b1", measure_id = "m1"),
    mm = list(type = "maintenance", rate_eur_m2_pa = 14.40, area_m2 = 900, growth = 0.02,
              factors = list(cx = 0.8), start_event = "2027-03-01", after = "cx")
  )
  st <- list(
    "components.mm.rate_eur_m2_pa" = c(10, 12, 14.4, 16, 9),
    "components.cx.delay_months" = c(0, 4, 12, 2, 30)
  )
  dr <- fake_draws(5L, g, static = st)
  fun <- function(n, draws) wsei_build(comps, g, n = n, draws = draws)$flows$mm
  expect_batch_invariance(fun, n = 5L, grid = g, draws = dr)
})
