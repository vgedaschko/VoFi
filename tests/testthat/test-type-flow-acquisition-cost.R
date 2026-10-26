# Tests des Zahlungstyps acquisition_cost (WS-E-INV; Spec 01 Teil A 4.8, Prüfwerte A1-A6).

acq_build <- function(..., grid = make_grid("annual", T = 6L), n = 1L, draws = NULL,
                      legal = TRUE, project = list()) {
  base <- list(type = "acquisition_cost", date = "2027-01-01", measure_id = "m1")
  comps <- list(acq = utils::modifyList(base, list(...)))
  sf <- function(s) {
    if (isTRUE(legal)) s <- wsei_with_grest(s)
    for (k in names(project)) s$project[[k]] <- project[[k]]
    s
  }
  wsei_build(comps, grid, n = n, draws = draws, spec_fun = sf)$flows$acq
}

grest_of <- function(f, i = 1L) {
  sum(wsei_row(f, "grest_land", i)) + sum(wsei_row(f, "grest_building", i))
}

test_that("Vertrag und Registrierung", {
  expect_type_contract("acquisition_cost", "flow")
})

test_that("A1: Grundstück 840.000, NW 6,5 %, Default-Anteile", {
  f <- acq_build(basis_eur = 840000, land_share = 1, federal_state = "NW")
  s <- wsei_sums(f)
  expect_equal(unname(s["grest_land"] + s["grest_building"]), -54600)
  expect_equal(unname(s["notary_land"] + s["notary_building"]), -8400)
  expect_equal(unname(s["registry_land"] + s["registry_building"]), -4200)
  expect_equal(unname(s[c("grest_building", "notary_building", "registry_building")]),
               c(0, 0, 0))
  expect_equal(sum(s), -67200)
  expect_equal(f$aux$grest_total[1, 1], 54600)
  expect_equal(f$aux$grest_basis[1, 1], 840000)
  # Zahlung zum Termin (t = 0 bei Termin = Stichtag)
  expect_equal(which(wsei_row(f, "grest_land") != 0) - 1L, 0L)
})

test_that("A2: Erwerb 1.200.000, Bodenanteil 25 %, BY 3,5 %, Makler 3,57 %", {
  f <- acq_build(basis_eur = 1200000, land_share = 0.25, federal_state = "BY",
                 broker_share = 0.0357)
  s <- wsei_sums(f)
  expect_equal(unname(s[c("grest_land", "grest_building")]), c(-10500, -31500))
  expect_equal(unname(s[c("notary_land", "notary_building")]), c(-3000, -9000))
  expect_equal(unname(s[c("registry_land", "registry_building")]), c(-1500, -4500))
  expect_equal(unname(s[c("broker_land", "broker_building")]), c(-10710, -32130))
  expect_equal(unname(s[c("other_land", "other_building")]), c(0, 0))
  expect_equal(sum(s), -102840)
  rows <- stats::setNames(f$rows, vapply(f$rows, function(r) r$key, ""))
  expect_identical(rows$grest_land$is_tax, "grunderwerbsteuer")
  expect_identical(rows$grest_land$tax_category, "acquisition_ancillary")
  expect_identical(rows$grest_land$category, "acquisition_cost")
  expect_identical(c(rows$grest_land$asset_id, rows$grest_building$asset_id),
                   c("b1_land", "b1_building"))
  expect_equal(c(rows$notary_land$vat_rate, rows$registry_land$vat_rate,
                 rows$broker_land$vat_rate, rows$grest_land$vat_rate), c(0.19, 0, 0.19, 0))
})

test_that("A3: Freigrenze 2.500 EUR (Basis 2.400 bzw. 2.600)", {
  expect_equal(grest_of(acq_build(basis_eur = 2400, federal_state = "NW")), 0)
  expect_equal(grest_of(acq_build(basis_eur = 2600, federal_state = "NW")), -169)
  expect_equal(grest_of(acq_build(basis_eur = 2500, federal_state = "NW")), 0)
})

test_that("A4: einheitlicher Vertragsgegenstand 200.000 + Bauleistung 1.000.000, NW", {
  f <- acq_build(basis_eur = 200000, uniform_contract = TRUE, construction_basis_eur = 1000000,
                 federal_state = "NW")
  s <- wsei_sums(f)
  expect_equal(unname(s[c("grest_land", "grest_building")]), c(-13000, -65000))
  expect_equal(f$aux$grest_basis[1, 1], 1200000)
  # Notar/Grundbuch nur auf den Kaufpreis
  expect_equal(unname(s["notary_land"]), -2000)
  # ohne einheitlichen Vertrag bleibt die Bauleistung außer Ansatz
  f0 <- acq_build(basis_eur = 200000, construction_basis_eur = 1000000, federal_state = "NW")
  expect_equal(grest_of(f0), -13000)
})

test_that("A5: Kostenabweichung der Bauleistung ändert die GrESt nicht (Basisfallwert)", {
  g <- make_grid("annual", T = 6L)
  st <- list(
    "components.acq.construction_basis_eur" = c(1000000, 1200000, 800000)
  )
  dr <- fake_draws(3L, g, static = st)
  f <- acq_build(basis_eur = 200000, uniform_contract = TRUE, construction_basis_eur = 1000000,
                 federal_state = "NW", grid = g, n = 3L, draws = dr)
  expect_equal(vapply(1:3, function(i) grest_of(f, i), 0), rep(-78000, 3))
  # die Gegenleistung (Kaufpreis) selbst wirkt je Lauf
  dr2 <- fake_draws(2L, g, static = list("components.acq.basis_eur" = c(200000, 300000)))
  f2 <- acq_build(basis_eur = 200000, uniform_contract = TRUE, construction_basis_eur = 1000000,
                  federal_state = "NW", grid = g, n = 2L, draws = dr2)
  expect_equal(vapply(1:2, function(i) grest_of(f2, i), 0), c(-78000, -84500))
})

test_that("A6: federal_state fehlt bei Basis 300.000 (Befund und Abbruch)", {
  sc <- wsei_with_grest(make_spec(make_grid()))
  sc$project$federal_state <- NULL
  f <- wsei_findings("acquisition_cost", basis_eur = 300000, date = "2027-01-01",
                     measure_id = "m1", scenario = sc)
  expect_identical(unname(f["acquisition.federal_state_missing"]), "error")
  expect_error(acq_build(basis_eur = 300000, project = list(federal_state = NULL)),
               class = "vofi_error_contract")
  # project.federal_state als Default, ausdrücklicher Satz ohne Land zulässig
  f2 <- acq_build(basis_eur = 300000, project = list(federal_state = "BY"))
  expect_equal(grest_of(f2), -10500)
  sc2 <- sc
  f3 <- wsei_findings("acquisition_cost", basis_eur = 300000, grest_rate = 0.05,
                      date = "2027-01-01", scenario = sc2)
  expect_false("acquisition.federal_state_missing" %in% names(f3))
  # unter der Freigrenze kein Befund
  f4 <- wsei_findings("acquisition_cost", basis_eur = 2000, date = "2027-01-01", scenario = sc)
  expect_false("acquisition.federal_state_missing" %in% names(f4))
  # Bezug auf einen Domänenpfad: Basisfallwert entscheidet über die Fälligkeit
  sc5 <- sc
  sc5$measures <- list(m1 = list(purchase_price_eur = 2000))
  f5 <- wsei_findings("acquisition_cost", basis_eur = list(ref = "measures.m1.purchase_price_eur"),
                      date = "2027-01-01", scenario = sc5)
  expect_false("acquisition.federal_state_missing" %in% names(f5))
  sc5$measures$m1$purchase_price_eur <- 300000
  f6 <- wsei_findings("acquisition_cost", basis_eur = list(ref = "measures.m1.purchase_price_eur"),
                      date = "2027-01-01", scenario = sc5)
  expect_identical(unname(f6["acquisition.federal_state_missing"]), "error")
})

test_that("Ausdrücklicher Satz gewinnt; Abweichung vom Landessatz ist eine Warnung", {
  f <- acq_build(basis_eur = 1000000, federal_state = "NW", grest_rate = 0.05)
  expect_equal(grest_of(f), -50000)
  sc <- wsei_with_grest(make_spec(make_grid()))
  w <- wsei_findings("acquisition_cost", basis_eur = 1000000, federal_state = "NW",
                     grest_rate = 0.05, date = "2027-01-01", scenario = sc)
  expect_identical(unname(w["acquisition.rate_deviates"]), "warning")
  ok <- wsei_findings("acquisition_cost", basis_eur = 1000000, federal_state = "NW",
                      grest_rate = 0.065, date = "2027-01-01", scenario = sc)
  expect_false("acquisition.rate_deviates" %in% names(ok))
})

test_that("Thema grunderwerbsteuer inaktiv: mit Satz Rückfall-Freigrenze, ohne Satz Fehler", {
  f <- acq_build(basis_eur = 1000000, grest_rate = 0.05, legal = FALSE)
  expect_equal(grest_of(f), -50000)
  # Vermerk in meta$notes (Spec 00 4.10), kein Validierungsbefund
  expect_length(f$meta$notes, 1L)
  expect_match(f$meta$notes, "grunderwerbsteuer", fixed = TRUE)
  expect_length(acq_build(basis_eur = 1000000, federal_state = "NW")$meta$notes, 0L)
  expect_equal(grest_of(acq_build(basis_eur = 2400, grest_rate = 0.05, legal = FALSE)), 0)
  expect_error(acq_build(basis_eur = 1000000, federal_state = "NW", legal = FALSE),
               class = "vofi_error_contract")
  sc <- make_spec(make_grid())
  sc$legal <- list(einkommensteuer = list(entry = "legal/x", values = list()))
  e <- wsei_findings("acquisition_cost", basis_eur = 1e6, federal_state = "NW",
                     date = "2027-01-01", scenario = sc)
  expect_identical(unname(e["acquisition.grest_inactive"]), "error")
  i <- wsei_findings("acquisition_cost", basis_eur = 1e6, grest_rate = 0.05,
                     date = "2027-01-01", scenario = sc)
  expect_length(i, 0L)
  # auch ohne andere Themen (leerer Rechtsstand) ist das Thema inaktiv: Befund statt Abbruch
  sc0 <- make_spec(make_grid())
  sc0$legal <- list()
  e0 <- wsei_findings("acquisition_cost", basis_eur = 1e6, federal_state = "NW",
                      date = "2027-01-01", scenario = sc0)
  expect_identical(unname(e0["acquisition.grest_inactive"]), "error")
  # unter der Freigrenze fällig ist nichts
  expect_length(wsei_findings("acquisition_cost", basis_eur = 2000, federal_state = "NW",
                              date = "2027-01-01", scenario = sc0), 0L)
})

test_that("Termin, Verschiebung, Aktivierung und weitere Befunde", {
  g <- make_grid("annual", T = 6L)
  dr <- fake_draws(3L, g, static = list("components.acq.delay_months" = c(0, 12, 0),
                                        "components.acq.active" = c(1, 1, 0)))
  f <- acq_build(basis_eur = 1e5, federal_state = "BY", date = "2027-06-01", grid = g, n = 3L,
                 draws = dr)
  v <- f$rows[[1]]$values
  expect_equal(which(v[1, ] != 0) - 1L, 1L)
  expect_equal(which(v[2, ] != 0) - 1L, 2L)
  expect_true(all(v[3, ] == 0))
  expect_equal(f$aux$grest_total[3, 1], 3500)
  sc <- wsei_with_grest(make_spec(make_grid()))
  b <- wsei_findings("acquisition_cost", basis_eur = 1e5, federal_state = "BY",
                     uniform_contract = TRUE, date = "2026-01-01", delay_months = -2,
                     scenario = sc)
  expect_identical(b[c("acquisition.uniform_without_construction", "measures.before_valuation")],
                   c(acquisition.uniform_without_construction = "warning",
                     measures.before_valuation = "error"))
  # negative Verschiebung prüft die Wertegrenze des Schemas (validation.range, WS-B)
  expect_false(any(grepl("shift_negative", names(b))))
  expect_error(acq_build(basis_eur = NULL, federal_state = "BY"), class = "vofi_error_contract")
})

test_that("Batch-Invarianz", {
  g4 <- make_grid("mixed", T = 6L)
  st <- list(
    "components.acq.basis_eur" = c(1e6, 2400, 3e5, 1.5e6),
    "components.acq.broker_share" = c(0, 0.0357, 0.02, 0),
    "components.acq.delay_months" = c(0, 3, 9, 40)
  )
  dr <- fake_draws(4L, g4, static = st)
  comps <- list(acq = list(type = "acquisition_cost", basis_eur = 1e6, land_share = 0.3,
                           federal_state = "NW", date = "2027-02-01", measure_id = "m1"))
  fun <- function(n, draws) {
    wsei_build(comps, g4, n = n, draws = draws, spec_fun = wsei_with_grest)$flows$acq
  }
  expect_batch_invariance(fun, n = 4L, grid = g4, draws = dr)
})
