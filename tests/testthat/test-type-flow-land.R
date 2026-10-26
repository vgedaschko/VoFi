# Tests des Zahlungstyps land (WS-E-INV; Spec 01 Teil A 4.7).

test_that("Vertrag und Registrierung", {
  expect_type_contract("land", "flow")
  expect_identical(reg_get("flow", "land")$rows, c("price_land", "price_building"))
})

test_that("Kaufpreis mit Aufteilung Boden/Gebäude, nominal und ohne Umsatzsteuer", {
  g <- make_grid("annual", T = 6L)
  res <- wsei_build(list(ld = list(type = "land", purchase_price_eur = 1200000,
                                   land_share = 0.25, date = "2027-04-01",
                                   measure_id = "m_kauf")), g)
  f <- res$flows$ld
  expect_equal(wsei_sums(f), c(price_land = -300000, price_building = -900000))
  expect_equal(which(wsei_row(f, "price_land") != 0) - 1L, 1L)
  r1 <- f$rows[[1]]
  r2 <- f$rows[[2]]
  expect_identical(c(r1$category, r1$tax_category), c("land", "capex_land"))
  expect_identical(c(r2$category, r2$tax_category), c("capex", "capex_depreciable"))
  expect_identical(c(r1$asset_id, r2$asset_id), c("b1_land", "b1_building"))
  expect_identical(c(r1$measure_id, r2$measure_id), c("m_kauf", "m_kauf"))
  expect_equal(c(r1$vat_rate, r2$vat_rate), c(0, 0))
  expect_identical(f$meta$measure_id, "m_kauf")
  # F1-F6 mit im Prüfkit registrierten Anlagen/Maßnahmen (b1, m1)
  res2 <- wsei_build(list(ld = list(type = "land", purchase_price_eur = 1200000,
                                    land_share = 0.25, date = "2027-04-01", measure_id = "m1",
                                    land_asset_id = "b1", building_asset_id = "b1")), g)
  expect_vofi_flows_contract(res2$flows$ld, res2$ctx, reg_get("flow", "land"))
})

test_that("A1: Grundstück 840.000 (land_share 1) mit Erwerbsnebenkosten -907.200", {
  g <- make_grid("annual", T = 6L)
  comps <- list(
    ld = list(type = "land", purchase_price_eur = 840000, land_share = 1, date = "2027-01-01",
              measure_id = "m1"),
    acq = list(type = "acquisition_cost", basis_eur = 840000, land_share = 1,
               date = "2027-01-01", federal_state = "NW", measure_id = "m1")
  )
  res <- wsei_build(comps, g, spec_fun = wsei_with_grest)
  s <- wsei_sums(res$flows$ld)
  expect_equal(unname(s), c(-840000, 0))
  expect_equal(sum(s) + sum(wsei_sums(res$flows$acq)), -907200)
})

test_that("Anlagen-ids und building_id; ausdrückliche Anlagen", {
  g <- make_grid("annual", T = 6L)
  comps <- list(ld = list(type = "land", purchase_price_eur = 1, date = "2027-01-01",
                          measure_id = "m1", land_asset_id = "gb", building_asset_id = "geb"))
  f <- wsei_build(comps, g)$flows$ld
  expect_identical(vapply(f$rows, function(r) r$asset_id, ""), c("gb", "geb"))
  comps$ld$land_asset_id <- NULL
  comps$ld$building_asset_id <- NULL
  f2 <- wsei_build(comps, g, spec_fun = function(s) {
    s$building$building_id <- "haus"
    s
  })$flows$ld
  expect_identical(vapply(f2$rows, function(r) r$asset_id, ""), c("haus_land", "haus_building"))
})

test_that("Termin completion, laufspezifische Verschiebung und Aktivierung", {
  g4 <- make_grid("mixed", T = 6L)
  st <- list(
    "components.ld.delay_months" = c(0, 2.4, 4.6),
    "components.ld.active" = c(1, 1, 0)
  )
  dr <- fake_draws(3L, g4, static = st)
  comps <- list(ld = list(type = "land", purchase_price_eur = 1000, date = "2027-03-01",
                          measure_id = "m1"))
  v <- wsei_build(comps, g4, n = 3L, draws = dr)$flows$ld$rows[[1]]$values
  pos <- function(i) which(v[i, ] != 0) - 1L
  per <- function(d) as.integer(grid_period_of(g4, as.Date(d)))
  expect_identical(pos(1L), per("2027-03-01"))
  expect_identical(pos(2L), per("2027-05-01"))
  expect_true(all(v[3, ] == 0))
  expect_equal(rowSums(v), c(-1000, -1000, 0))
  # completion: Fertigstellung des Rasters zuzüglich Bauzeitverzug
  dc <- fake_draws(2L, g4, static = list("project.construction_delay_months" = c(0, 3)))
  comps$ld$date <- "completion"
  vc <- wsei_build(comps, g4, n = 2L, draws = dc)$flows$ld$rows[[1]]$values
  expect_identical(which(vc[1, ] != 0) - 1L, per(g4$completion_date))
  expect_identical(which(vc[2, ] != 0) - 1L, per(grid_add_months(g4$completion_date, 3L)))
})

test_that("Termin jenseits des Horizonts entfällt mit Hinweis", {
  g <- make_grid("annual", T = 3L)
  comps <- list(ld = list(type = "land", purchase_price_eur = 1000, date = "2035-01-01",
                          measure_id = "m1"))
  cap <- wsei_capture(wsei_build(comps, g))
  expect_identical(cap$keys, "types.flow.land.msg.after_horizon")
  expect_true(all(wsei_row(cap$value$flows$ld, "price_land") == 0))
})

test_that("Fehlende Pflichtangaben sind Vertragsfehler", {
  g <- make_grid("annual", T = 3L)
  expect_error(wsei_build(list(ld = list(type = "land", date = "2027-01-01")), g),
               class = "vofi_error_contract")
  expect_error(wsei_build(list(ld = list(type = "land", purchase_price_eur = 1)), g),
               class = "vofi_error_contract")
})

test_that("validate(): Stichtag, Maßnahme, Kaufpreisaufteilung, Projektart (4.7)", {
  f <- wsei_findings("land", purchase_price_eur = 1, date = "2026-01-01", delay_months = -1)
  expect_identical(f[c("measures.before_valuation", "measures.measure_missing")],
                   c(measures.before_valuation = "error", measures.measure_missing = "error"))
  # negative Verschiebung: Wertegrenze des Schemas (validation.range), kein eigener Befund
  expect_false(any(grepl("shift_negative", names(f))))
  expect_length(wsei_findings("land", purchase_price_eur = 1, date = "2027-01-01",
                              measure_id = "m1"), 0L)
  # erwerb_objekt mit land_share 0 oder 1 (Basisfallwert des Bezugs): Kaufpreisaufteilung prüfen
  sc <- make_spec(make_grid())
  sc$project$project_type <- "erwerb_sanierung"
  sc$measures <- list(m1 = list(measure_type = "erwerb_objekt", land_share = node_const(1)))
  w <- wsei_findings("land", purchase_price_eur = 1, date = "2027-01-01", measure_id = "m1",
                     land_share = list(ref = "measures.m1.land_share"), scenario = sc)
  expect_identical(w, c(measures.land_share_extreme = "warning"))
  sc$measures$m1$land_share <- node_const(0.25)
  expect_length(wsei_findings("land", purchase_price_eur = 1, date = "2027-01-01",
                              measure_id = "m1", land_share = list(ref = "measures.m1.land_share"),
                              scenario = sc), 0L)
  # Grundstückskauf mit land_share 1 ist üblich (kein Befund)
  sc$measures$m1 <- list(measure_type = "erwerb_grundstueck", land_share = node_const(1))
  expect_length(wsei_findings("land", purchase_price_eur = 1, date = "2027-01-01",
                              measure_id = "m1", land_share = 1, scenario = sc), 0L)
  # Erwerb in einem Bestandsprojekt ohne Erwerb
  sc$project$project_type <- "sanierung_eh"
  m <- wsei_findings("land", purchase_price_eur = 1, date = "2027-01-01", measure_id = "m1",
                     scenario = sc)
  expect_identical(m, c(measures.type_project_mismatch = "warning"))
})

test_that("Batch-Invarianz", {
  g4 <- make_grid("mixed", T = 6L)
  st <- list(
    "components.ld.purchase_price_eur" = c(1e6, 9e5, 1.1e6, 1e6),
    "components.ld.land_share" = c(0.2, 0.3, 0.25, 0.4),
    "components.ld.delay_months" = c(0, 1, 7, 30)
  )
  dr <- fake_draws(4L, g4, static = st)
  comps <- list(ld = list(type = "land", purchase_price_eur = 1e6, date = "2027-02-01",
                          measure_id = "m1"))
  fun <- function(n, draws) wsei_build(comps, g4, n = n, draws = draws)$flows$ld
  expect_batch_invariance(fun, n = 4L, grid = g4, draws = dr)
})
