# Tests für R/values-resolve.R über den Laufkontext (WS-D; Spec 00 Abschnitte 4.5, 6.3).

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
  expect_identical(ctx$timing(list(id = "x", start_event = "completion"), "start_event")$date,
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
  # Begrenzung auf [0, 1] ohne Laufzeithinweis (Information der Validierung, Spec 01c 1)
  expect_silent(sh <- ctx$value("shared.p_share"))
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

test_that("ctx$rows(measure_id): Tag der Komponente als Default wie im Ledger (R-93, WSD-06)", {
  z <- matrix(1, 1, 7)
  spec <- reg_test_spec(make_grid())
  c2 <- list(id = "c2", type = "custom_series", measure_id = "m1")
  spec <- path_set(spec, "components.c2", c2)
  spec <- path_set(spec, "components.c3", list(id = "c3", type = "custom_series"))
  comps <- list(c2 = vofi_flows(vofi_row("value", -z, "project", "operating_cost")),
                c3 = vofi_flows(vofi_row("value", -2 * z, "project", "operating_cost",
                                         measure_id = "m1"),
                                vofi_row("rest", -3 * z, "project", "operating_cost")))
  ctx <- make_ctx(spec = spec, components = comps)
  expect_setequal(names(ctx$rows(measure_id = "m1")), c("c2__value", "c3__value"))
  # die Zeile trägt ihren eigenen Tag vor dem der Komponente
  expect_identical(names(ctx$rows(id = "c3", measure_id = "m1")), "c3__value")
  expect_length(ctx$rows(measure_id = "m2"), 0L)
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

#' Ziehungen mit Schlüssel != Ziel (Overlay-Schlüssel, 4.13) und Verknüpfung apply
key_draws <- function(grid, key, target, x, apply = "multiply", mode = "mc") {
  n <- length(x)
  targets <- data.frame(key = key, target = target, kind = "static", apply = apply,
                        stringsAsFactors = FALSE)
  new_vofi_draws(mode, n = n, sims = seq_len(n), static = stats::setNames(list(x), key),
                 targets = targets, years = grid$years)
}

test_that("Prüffall apply (01c 1.3): 543.301,50 x 1,0087283674 = 548.043,64; Design", {
  g <- make_grid()
  pars <- list("measures.huelle.cost_eur" = 543301.50)
  d <- key_draws(g, "cost_huelle", "measures.huelle.cost_eur", 1.0087283674)
  ctx <- make_ctx(draws = d, params = pars)
  expect_equal(ctx$value("measures.huelle.cost_eur"), 548043.64, tolerance = 0.01 / 548043.64)
  expect_equal(ctx$value_base("measures.huelle.cost_eur"), 543301.50)
  # Designzeile mit Overlay-Schlüssel: Verknüpfung wie in der MC
  dd <- key_draws(g, "cost_huelle", "measures.huelle.cost_eur", 1.2, mode = "design")
  expect_equal(make_ctx(draws = dd, params = pars)$value("measures.huelle.cost_eur"),
               651961.80)
  # Designzeile mit Zielpfad: absoluter Wert (replace)
  dz <- key_draws(g, "measures.huelle.cost_eur", "measures.huelle.cost_eur", 600000,
                  apply = "replace", mode = "design")
  expect_equal(make_ctx(draws = dz, params = pars)$value("measures.huelle.cost_eur"), 600000)
  # unbekannte Verknüpfung ist ein Vertragsfehler
  bad <- key_draws(g, "k", "measures.huelle.cost_eur", 2, apply = "power")
  expect_error(make_ctx(draws = bad, params = pars)$value("measures.huelle.cost_eur"),
               class = "vofi_error_contract")
})

test_that("Entscheidungsschlüssel wirken nicht auf ihr Ziel (9.11 Nr. 3)", {
  g <- make_grid()
  targets <- data.frame(key = "funding.f.approved", target = "funding.f.approved",
                        kind = "decision", apply = "replace", stringsAsFactors = FALSE)
  d <- new_vofi_draws("mc", n = 2L, sims = 1:2, decision = list("funding.f.approved" = c(0, 1)),
                      targets = targets, years = g$years)
  ctx <- make_ctx(n = 2L, draws = d, params = list("funding.f.approved" = 1))
  expect_identical(ctx$value("funding.f.approved"), c(1, 1))
  expect_identical(ctx$draw("funding.f.approved"), c(0, 1))
})

test_that("Mengenbezug: nächstes Bezugsobjekt, Rückfall building, kein Rückfall für kWp", {
  ctx <- make_ctx(params = list(
    "measures.m1.living_area_m2" = 50,
    "measures.m1.cost" = list(value = 100, per = "m2_living_area"),
    "measures.m2.cost" = list(value = 100, per = "m2_living_area"),
    "measures.m3.cost" = list(value = 1000, per = "kwp"),
    "measures.m4.kwp" = 10,
    "measures.m4.cost" = list(value = 1000, per = "kwp"),
    "building.component_areas_m2.facade" = 400,
    "measures.m5.cost" = list(value = 120, per = "m2_component:facade"),
    "measures.m6.cost" = list(value = list(years = c(2027, 2033), values = c(10, 70)),
                              per = "unit"),
    "measures.m7.cost" = list(value = 9, per = "total")
  ))
  expect_identical(ctx$value("measures.m1.cost"), 5000)
  expect_identical(ctx$value("measures.m2.cost"), 100 * 900)
  expect_error(ctx$value("measures.m3.cost"), class = "vofi_error_contract")
  expect_identical(ctx$value("measures.m4.cost"), 10000)
  expect_identical(ctx$value("measures.m5.cost"), 48000)
  n_units <- ctx$value("building.n_units")
  expect_equal(ctx$value("measures.m6.cost", "path")[1L, ], c(10, 10, 20, 30, 40, 50, 60) *
                 n_units)
  expect_identical(ctx$value("measures.m7.cost"), 9)
  spec <- list(measures = list(a = list(n_units = 3)), building = list(n_units = 8))
  expect_identical(res_quantity_target(spec, "measures.a.cost", "unit"), "measures.a.n_units")
  expect_identical(res_quantity_target(spec, "measures.b.cost", "unit"), "building.n_units")
  expect_null(res_quantity_target(spec, "measures.b.cost", "kw"))
})

test_that("Typ-Defaults (Schicht 0) für nicht gesetzte Parameter und Map-Felder", {
  comp <- make_component("annuity_loan", id = "bank")
  ctx <- make_ctx(spec = comp)
  sp <- ctx$spec$financing$bank
  sp$payout_rate <- NULL
  sp$fees <- NULL
  expect_identical(ctx$param(sp, "payout_rate"), 1)
  expect_identical(ctx$param(sp, "fees.processing_fee_share"), 0)
  spec2 <- ctx$spec
  spec2$financing$bank$fees <- NULL
  expect_identical(res_default_node(spec2, "financing.bank.fees.processing_fee_share"),
                   node_const(0))
  expect_null(res_default_node(spec2, "financing.bank.gibt_es_nicht"))
  expect_null(res_default_node(spec2, "accounts.deposit_rate_pa"))
  expect_identical(res_param_kind(res_context(spec2, ctx$grid, 1L),
                                  "financing.bank.payout_rate"), "share")
  expect_identical(res_param_kind(res_context(spec2, ctx$grid, 1L), "shared.x_share"), "share")
})

test_that("Hinweise der Auflösung höchstens einmal je Kontext, quiet unterdrückt sie", {
  g <- make_grid()
  spec <- make_spec(g)
  spec <- path_set(spec, "shared.s", reg_node(list(schedule = list("2027-06-01" = 1,
                                                                   "2040" = 9)), "shared.s"))
  rc <- res_context(spec, g, 1L)
  expect_message(res_value(rc, "shared.s", "path"), class = "vofi_message")
  expect_silent(res_value(rc, "shared.s", "path"))
  rq <- res_context(spec, g, 1L, quiet = TRUE)
  expect_silent(res_value(rq, "shared.s", "path"))
  once <- new.env()
  r2 <- res_context(spec, g, 1L, once = once)
  expect_message(expect_true(res_inform_once(r2, "x", "engine.auto_zero", id = "a")))
  expect_false(res_inform_once(r2, "x", "engine.auto_zero", id = "a"))
  env <- reg_engine_env("flows")
  env$quiet <- TRUE
  ctx <- eng_context_from_parts(g, spec, engine_env = env)
  expect_silent(ctx$value("shared.s", "path"))
})

test_that("Wachstumsform auf gemischtem Raster: Kalenderjahreswert je Periode (R-91)", {
  ctx <- make_ctx(grid = make_grid("mixed"),
                  params = list("shared.g" = list(start = 100, growth = 0.02)))
  g <- ctx$grid
  v <- ctx$value("shared.g", "path")[1L, ]
  expect_equal(v, 100 * 1.02^(g$year - 2026L))
  expect_true(all(v[g$year == 2027L] == v[1L]))
})
