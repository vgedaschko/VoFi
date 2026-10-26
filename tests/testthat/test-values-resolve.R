# Tests für R/values-resolve.R über den Laufkontext (WS-D; Spec 00 Abschnitte 4.5, 6.3).
# Phase-0-Minimalfassung.

test_that("series_year: fill, before, Jahre vor dem Stichtag (annual_before)", {
  ctx <- make_ctx(params = list(
    "shared.a" = list(series = list("2028" = 0.03, "2030" = 0.05)),
    "shared.b" = list(series = list("2028" = 0.03, "2030" = 0.05), fill = "linear",
                      before = "zero"),
    "shared.c" = list(series = list("2025" = 0.01, "2027" = 0.03))
  ))
  expect_identical(ctx$grid$year, c(2027L, 2027:2032))
  expect_equal(ctx$value("shared.a", "path")[1, ], c(0.03, 0.03, 0.03, 0.03, 0.05, 0.05, 0.05))
  expect_equal(ctx$value("shared.b", "path")[1, ], c(0, 0, 0.03, 0.04, 0.05, 0.05, 0.05))
  c3 <- ctx$value("shared.c", "path")
  expect_equal(unname(attr(c3, "annual_before")[1, ]), c(0.01, 0.01))
  expect_identical(colnames(attr(c3, "annual_before")), c("2025", "2026"))
  expect_error(ctx$value("shared.a", "scalar"), class = "vofi_error_contract")
})

test_that("points, ref mit anchor, growth, schedule, expr, quantity", {
  ctx <- make_ctx(n = 2L, params = list(
    "shared.p" = list(years = c(2027, 2031), values = c(10, 50)),
    "shared.r" = list(ref = "shared.p", anchor = 1, scale = 0.5),
    "shared.g" = list(start = 100, growth = 0.02),
    "shared.h" = list(start = 100, growth = 0.02, index = "period_end"),
    "shared.s" = list(schedule = list("2027-06-01" = 10, "2029" = 5, "2040" = 99)),
    "shared.e" = list(expr = "building.living_area_m2 * 2 + shared.p"),
    "shared.q" = list(value = 14, per = "m2_living_area")
  ))
  p <- ctx$value("shared.p", "path")
  expect_equal(p[1, ], c(10, 10, 20, 30, 40, 50, 50))
  expect_equal(ctx$value("shared.r", "path")[2, ], 1 + 0.5 * (p[1, ] - 10))
  # Wachstumsform (R-91): Default Kalenderjahreswert (Preisstand 2026, t0 und Periode 1 liegen im
  # Kalenderjahr 2027), index: period_end = Stichtagswert zum Periodenende.
  expect_equal(ctx$value("shared.g", "path")[1, ], 100 * 1.02^c(1, 1:6))
  expect_equal(ctx$value("shared.h", "path")[2, ], 100 * 1.02^(0:6))
  expect_message(s <- ctx$value("shared.s", "path"), class = "vofi_message")
  expect_equal(s[1, ], c(0, 10, 5, 0, 0, 0, 0))
  expect_equal(ctx$value("shared.e", "path")[1, ], 1800 + p[1, ])
  expect_identical(ctx$value("shared.q"), c(14 * 900, 14 * 900))
})

test_that("Ziehungen vor Knoten; Basisfall ohne Ziehungen; Zyklen", {
  g <- make_grid()
  d <- fake_draws(3L, g, static = list("shared.k" = c(1, 2, 3)),
                  paths = list("shared.m" = matrix(1:21, 3, 7)))
  ctx <- make_ctx(n = 3L, draws = d, params = list("shared.k" = 7, "shared.m" = 0.5,
                                                   "shared.x" = list(ref = "shared.k")))
  expect_identical(ctx$value("shared.k"), c(1, 2, 3))
  expect_identical(ctx$value_base("shared.k"), c(7, 7, 7))
  expect_identical(ctx$value("shared.x"), c(1, 2, 3))
  expect_identical(ctx$value_base("shared.x"), c(7, 7, 7))
  expect_identical(ctx$value("shared.m", "path")[, 2], c(4, 5, 6))
  expect_identical(ctx$draw("shared.k"), c(1, 2, 3))
  cyc <- make_ctx(params = list("shared.a" = list(ref = "shared.b"),
                                "shared.b" = list(ref = "shared.a")))
  expect_error(cyc$value("shared.a"), class = "vofi_error_contract")
  expect_error(cyc$value("shared.c.fehlt.nicht") %||% stop("NULL"), "NULL")
  expect_error(make_ctx(params = list("shared.z" = list(ref = "shared.y")))$value("shared.z"),
               class = "vofi_error_contract")
})

test_that("Kontext: Formen, Rasterfunktionen, Sperre, rebalance nur in Kennzahlen", {
  ctx <- make_ctx(n = 7L)
  expect_identical(dim(ctx$zeros()), c(7L, 7L))
  expect_identical(ctx$by_sim(1:7)[, 3], as.double(1:7))
  expect_identical(ctx$by_period(0:6)[2, ], as.double(0:6))
  expect_equal(ctx$rate_eff(0.02)[1, ], c(0, rep(0.02, 6)))
  expect_identical(as.integer(ctx$period_of_year(2030)), 3L)
  expect_error(ctx$rebalance(), class = "vofi_error_contract")
  expect_error(assign("n", 2L, envir = ctx))
  expect_true(environmentIsLocked(ctx))
  expect_identical(ctx$assets()[[1]]$asset_id, "b1")
  expect_identical(ctx$timing(list(id = "x", from = "completion"), "from")$date,
                   ctx$grid$completion_date)
  expect_error(ctx$component("fehlt"), class = "vofi_error_contract")
})

test_that("Overlay-Verknüpfung apply (6.3 Schritt 1, R-94) und Mengenbezug per -> Feld (R-91)", {
  g <- make_grid()
  d <- fake_draws(3L, g, static = list("shared.f" = c(1, 1.1, 1.2), "shared.a" = c(0, 1, 2),
                                       "shared.r" = c(5, 6, 7), "shared.p_share" = c(0.5, 2, 3)))
  d$targets$apply <- c("multiply", "add", "replace", "multiply")
  pars <- list("shared.f" = 100, "shared.a" = list(years = c(2027, 2033), values = c(10, 70)),
               "shared.r" = 1, "shared.p_share" = 0.4)
  ctx <- make_ctx(n = 3L, draws = d, params = pars)
  expect_equal(ctx$value("shared.f"), c(100, 110, 120))
  expect_identical(ctx$value_base("shared.f"), c(100, 100, 100))
  a <- ctx$value("shared.a", "path")
  expect_equal(a[, 1], c(10, 11, 12))
  expect_equal(a[2, ], c(10, 10, 20, 30, 40, 50, 60) + 1)
  expect_identical(ctx$value("shared.r"), c(5, 6, 7))
  expect_message(sh <- ctx$value("shared.p_share"), class = "vofi_message")
  expect_equal(sh, c(0.2, 0.8, 1))
  q <- make_ctx(params = list("shared.n" = list(value = 3, per = "m2_net_floor_area"),
                              "shared.k" = list(value = 2, per = "parking"),
                              "shared.u" = list(value = 5, per = "unit"),
                              "shared.n_units" = 4,
                              "building.net_floor_area_m2" = 1000, "building.n_parking" = 6))
  expect_identical(q$value("shared.n"), 3000)
  expect_identical(q$value("shared.k"), 12)
  expect_identical(q$value("shared.u"), 20)
})

test_that("Ausdrücke: setting-Semantik für Codes und Wahrheitswerte (R-91)", {
  ex <- list("shared.e" = list(expr = "ifelse(project.perspective == 'wu_kommunal', 2, 1)"),
             "shared.f" = list(expr = "project.perspective + 1"))
  ctx <- make_ctx(params = ex)
  expect_identical(ctx$value("shared.e"), 2)
  expect_error(ctx$value("shared.f"), class = "vofi_error_input")
})

test_that("ctx$rows(): Filter UND-verknüpft, id als Vektor, measure_id und local_row (R-93)", {
  z <- matrix(1, 1, 7)
  comps <- list(
    a = vofi_flows(vofi_row("miete", z, "project", "rent"),
                   vofi_row("kosten", -z, "project", "operating_cost", measure_id = "m1")),
    b = vofi_flows(vofi_row("kosten", -2 * z, "project", "operating_cost", measure_id = "m2"))
  )
  ctx <- make_ctx(components = comps)
  expect_setequal(names(ctx$rows()), c("a__miete", "a__kosten", "b__kosten"))
  expect_identical(names(ctx$rows(id = c("a", "b"), local_row = "kosten")),
                   c("a__kosten", "b__kosten"))
  expect_identical(names(ctx$rows(measure_id = "m2")), "b__kosten")
  expect_identical(names(ctx$rows(category = "operating_cost", measure_id = c("m1", "m2"))),
                   c("a__kosten", "b__kosten"))
  expect_length(ctx$rows(section = "project", category = "rent", measure_id = "m1"), 0L)
  expect_equal(ctx$rows(id = "b")$b__kosten, -2 * z)
})

test_that("res_shape: Laufzahl 1 oder n, sonst Vertragsfehler (keine stille Verkuerzung)", {
  g <- make_grid("annual")
  rc <- res_context(make_spec(g), g, 2L, NULL, "deterministic")
  expect_identical(res_shape(rc, c(1, 2), "scalar", "x"), c(1, 2))
  expect_identical(res_shape(rc, 3, "scalar", "x"), c(3, 3))
  expect_error(res_shape(rc, c(1, 2, 3), "scalar", "x"), class = "vofi_error_contract")
  expect_error(res_shape(rc, matrix(0, 3, 7), "path", "x"), class = "vofi_error_contract")
  expect_identical(dim(res_shape(rc, matrix(1, 1, 7), "path", "x")), c(2L, 7L))
})

test_that("Randfaelle der Aufloesung: reales Wachstum, floor/cap, Fehlerzweige", {
  ctx <- make_ctx(n = 2L, params = list(
    "shared.real" = list(start = 100, growth = 0.01, real = TRUE),
    "shared.fc" = list(ref = "shared.base", floor = 2, cap = 4),
    "shared.base" = list(years = c(2027, 2033), values = c(0, 6)),
    "shared.vec" = c(1, 2, 3, 4, 5, 6, 7),
    "shared.short" = c(1, 2, 3),
    "shared.early" = list(schedule = list("2026-06-01" = 10)),
    "shared.qmiss" = list(value = 3, per = "kw"),
    "shared.emiss" = list(expr = "shared.nichtda * 2"),
    "shared.nested" = list(years = c(2027, 2033),
                           values = list(1, list(ref = "shared.base")))
  ))
  # reales Wachstum: (1 + g) (1 + pi) - 1 mit market.inflation = 0.02 (Pruefkit-Markt)
  expect_equal(ctx$value("shared.real", "path")[1, 2], 100 * 1.01 * 1.02, tolerance = 1e-12)
  fc <- ctx$value("shared.fc", "path")
  expect_equal(fc[1, ], pmin(pmax(c(0, 0:5), 2), 4))
  expect_identical(dim(fc), c(2L, 7L))
  expect_equal(ctx$value("shared.vec", "path")[2, ], as.double(1:7))
  expect_error(ctx$value("shared.short", "path"), class = "vofi_error_input")
  expect_error(ctx$value("shared.early", "path"), class = "vofi_error_input")
  expect_error(ctx$value("shared.qmiss"), class = "vofi_error_contract")
  expect_error(ctx$value("shared.emiss"), class = "vofi_error_contract")
  expect_error(ctx$value("shared.nested", "path"), class = "vofi_error_contract")
  g <- make_grid()
  rc <- res_context(make_spec(g), g, 1L, NULL, "deterministic")
  expect_error(res_node(rc, list(kind = "dist", dist = "pert"), "x", FALSE, character(0)),
               class = "vofi_error_contract")
  expect_error(res_node(rc, list(kind = "kaputt"), "x", FALSE, character(0)),
               class = "vofi_error_input")
  expect_identical(res_node(rc, TRUE, "x", FALSE, character(0)), 1)
  expect_identical(res_node(rc, "code", "x", FALSE, character(0)), "code")
  expect_null(res_node(rc, list(kind = "auto", mode = "auto"), "x", FALSE, character(0)))
  expect_identical(res_quantity_field("m2_component:facade"), "component_areas_m2.facade")
  expect_identical(res_quantity_field("kwp"), "kwp")
})
