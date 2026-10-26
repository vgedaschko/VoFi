# Tests des Expanders residual (WS-E2, Spec 01 Teil A 6.2).

e2_rv_bld <- function(...) {
  utils::modifyList(list(building_type = "MFH", construction_year = 1975L, n_units = 12L,
                         living_area_m2 = 900, land_value_eur = 300000,
                         modernization_points_before = list(heating = 1)), list(...))
}

test_that("rv_value: Methode als Bezüge, Tabellen als Werte, Gebäude- und Maßnahmenfelder", {
  x <- e2_scenario(building = e2_rv_bld(),
                   unit_groups = list(g = list(n_units = 12L, living_area_m2 = 900,
                                               rent_eur_m2_month = 7)),
                   measures = list(wp = list(measure_type = "heizung_waermepumpe_luft",
                                             year = 2027, cost_eur = 100000)),
                   residual_value = list(method = "income_value",
                                         income_value = list(cap_rate = 0.04)))
  spec <- e2_resolve(x)
  rv <- spec$components$rv_value
  expect_identical(rv$type, "residual_value")
  expect_identical(rv$method, "income_value")
  expect_identical(rv$income_value$cap_rate, node_ref("residual_value.income_value.cap_rate"))
  expect_identical(rv$income_value$land_value_eur,
                   node_ref("residual_value.income_value.land_value_eur"))
  expect_identical(rv$income_value$remaining_life_method, "anlage2")
  expect_identical(rv$income_value$rnd_table$p0$a, node_const(1.25))
  expect_identical(rv$income_value$points_max$heating, node_const(2))
  expect_identical(rv$income_value$bwk$admin_eur_unit_pa,
                   node_ref("residual_value.income_value.bwk.admin_eur_unit_pa"))
  expect_identical(rv$income_value$bwk$price_base_year, 2025L)
  expect_identical(rv$n_units, node_ref("building.n_units"))
  expect_identical(rv$living_area_m2, node_ref("building.living_area_m2"))
  expect_identical(rv$construction_year, 1975L)
  expect_identical(rv$points_before$heating,
                   node_ref("building.modernization_points_before.heating"))
  expect_identical(rv$points_measures$wp$heating,
                   node_ref("measures.wp.effects.residual.modernization_points.heating"))
  expect_identical(rv$sale_cost_share, node_ref("residual_value.sale_cost_share"))
  expect_setequal(rv$after, setdiff(names(spec$components), "rv_value"))
  expect_false("multiplier" %in% names(rv))
  res <- e2_run(spec)
  expect_true(e2_row(res, "rv_value__value")[11L] > 0)
})

test_that("rv_value: Methode zero ohne Zeitwertpfade ohne Abhängigkeiten, mit Pfaden mit after", {
  x <- e2_scenario(building = e2_rv_bld(), residual_value = list(method = "zero"))
  spec <- e2_resolve(x)
  expect_identical(spec$components$rv_value$method, "zero")
  expect_length(spec$components$rv_value$after, 0L)
  x$measures <- list(wp = list(measure_type = "heizung_waermepumpe_luft", year = 2027,
                               cost_eur = 100000))
  spec <- e2_resolve(x)
  expect_true("m_wp_repl" %in% spec$components$rv_value$after)
  res <- e2_run(spec)
  expect_equal(sum(e2_row(res, "rv_value__value")), 0)
  expect_true(e2_row(res, "rv_value__path_measures")[2L] > 0)
})

test_that("rv_value: Komponentenzeitwert (indexed), Bestandswert, Methode ohne building", {
  x <- e2_scenario(building = e2_rv_bld(existing_value_eur = 500000),
                   residual_value = list(method = "component", component = list(indexed = FALSE)))
  spec <- e2_resolve(x)
  rv <- spec$components$rv_value
  expect_false(rv$component$indexed)
  expect_identical(rv$existing_value_eur, node_ref("building.existing_value_eur"))
  # ohne building: Profilmethode (income_value) ohne Komponente; user_value zulässig
  nb <- e2_scenario(perspective = "wu_privat", project_type = "neubau")
  nb$residual_value <- NULL
  sn <- e2_resolve(nb)
  expect_false("rv_value" %in% names(sn$components))
  uv <- e2_scenario(perspective = "wu_privat", project_type = "neubau",
                    residual_value = list(method = "user_value",
                                          user_value = list(value_eur = 123456)))
  su <- e2_resolve(uv)
  expect_identical(su$components$rv_value$user_value$value_eur,
                   node_ref("residual_value.user_value.value_eur"))
  res <- e2_run(su)
  expect_equal(e2_row(res, "rv_value__value")[11L], 123456)
  mg <- e2_scenario(perspective = "wu_privat", project_type = "neubau",
                    residual_value = list(method = "market_growth"))
  e <- expect_error(e2_resolve(mg), class = "vofi_error_validation")
  expect_identical(e$key, "expand.residual.base_value_missing")
})

test_that("rv_value: Kollision mit einer Nutzerkomponente gleicher id ist ein Fehler", {
  x <- e2_scenario(building = e2_rv_bld(),
                   components = list(rv_value = list(type = "custom_series",
                                                     values = rep(0, 11L))))
  e <- expect_error(e2_resolve(x), class = "vofi_error_validation")
  expect_true(e$key %in% c("validation.expander.id_collision", "io.expander_id_collision"))
})
