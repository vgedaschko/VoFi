# Tests des Zahlungstyps capex (WS-E-INV; Spec 01 Teil A 4.6, Prüfwerte C1-C9 nach vref.py).

capex_build_one <- function(..., grid = make_grid("annual", T = 25L), n = 1L, draws = NULL,
                            market = list(), id = "x") {
  comp <- make_component("capex", ..., id = id)
  ctx <- make_ctx(n, grid = grid, spec = comp, draws = draws, market = market)
  list(flows = reg_get("flow", "capex")$build(comp, ctx), ctx = ctx, comp = comp)
}

test_that("Vertrag und Registrierung (C1-C4, F1-F9)", {
  expect_type_contract("capex", "flow")
  def <- reg_get("flow", "capex")
  expect_false(def$grid_invariant)
  expect_true(all(c("cost", "cost_kg300", "contingency") %in% def$rows))
})

test_that("C1: Einmalzahlung zum 1. Januar 2030 mit Preisindex 3 %", {
  r <- capex_build_one(date = 2030, cost_eur = 32000, price_base_year = 2026L, price_index = 0.03,
                       asset_id = "b1", measure_id = "m1")
  v <- wsei_row(r$flows, "cost")
  expect_equal(which(v != 0) - 1L, 3L)
  expect_equal(v[4], -32000 * 1.03^3, tolerance = 1e-12)
  expect_equal(round(v[4], 2), -34967.26)
  expect_vofi_flows_contract(r$flows, r$ctx, reg_get("flow", "capex"))
  row <- r$flows$rows[[1]]
  expect_identical(row$asset_id, "b1")
  expect_identical(row$measure_id, "m1")
  expect_identical(row$tax_category, "capex_depreciable")
  expect_equal(row$vat_rate, 0.19)
})

test_that("C2: Kostengruppen mit Baunebenkosten und Risikozuschlag (Memo 07 S1 V2)", {
  r <- capex_build_one(cost_kg = list(kg300 = 799500, kg400 = 372000), kg700_share = 0.18,
                       contingency_share = 0.05, price_index = 0, date = "2027-07-01",
                       asset_id = "b1", measure_id = "m1")
  s <- wsei_sums(r$flows)
  expect_setequal(names(s), c("cost_kg300", "cost_kg400", "cost_kg700", "contingency"))
  expect_equal(unname(s["cost_kg700"]), -210870)
  expect_equal(unname(s["contingency"]), -69118.5)
  expect_equal(sum(s), -1451488.5)
  aux <- r$flows$aux
  expect_equal(sum(aux$cost_kg300), 839475)
  expect_equal(sum(aux$cost_kg400), 390600)
  expect_equal(sum(aux$cost_kg700), 221413.5)
  expect_equal(sum(aux$cost_total), 1451488.5)
  expect_equal(aux$cost_base[1, 1], 1451488.5)
  v1 <- capex_build_one(cost_kg = list(kg300 = 478000), kg700_share = 0.15,
                        contingency_share = 0.05, price_index = 0, date = "2027-07-01",
                        asset_id = "b1", measure_id = "m1")
  expect_equal(sum(v1$flows$aux$cost_total), 577185)
  expect_equal(sum(aux$cost_total) - sum(v1$flows$aux$cost_total), 874303.5)
  # Basen kg200_600 bzw. kg200_600 für den Zuschlag (KG 700 ohne Zuschlaganteil)
  r2 <- capex_build_one(cost_kg = list(kg200 = 10000, kg300 = 90000, kg700 = 5000),
                        kg700_basis = "kg200_600", kg700_share = 0.1,
                        contingency_basis = "kg200_600", contingency_share = 0.1,
                        price_index = 0, date = "2027-07-01", asset_id = "b1", measure_id = "m1")
  s2 <- wsei_sums(r2$flows)
  expect_equal(unname(s2["cost_kg700"]), -(5000 + 0.1 * 100000))
  expect_equal(unname(s2["contingency"]), -0.1 * 100000)
  expect_equal(sum(r2$flows$aux$cost_kg700), 15000)
  expect_equal(sum(r2$flows$aux$cost_kg200), 10000 + 10000 * 0.1)
  expect_identical(r2$flows$rows[[1]]$tax_category, "capex_depreciable")
  r3 <- capex_build_one(cost_kg = list(kg200 = 10000), tax_category_kg200 = "capex_land",
                        price_index = 0, date = "2027-07-01", asset_id = "b1", measure_id = "m1")
  expect_identical(r3$flows$rows[[1]]$tax_category, "capex_land")
  expect_identical(vapply(r3$flows$rows, function(x) x$key, ""), "cost_kg200")
})

test_that("C3: Ausführungsdauer mit S-Kurve auf dem Raster mit monatlicher Bauphase (G4)", {
  g4 <- make_grid("mixed", T = 30L)
  r <- capex_build_one(grid = g4, date = "2027-10-01", duration_months = 9L,
                       payment_profile = "s_curve", cost_eur = 900000, price_index = 0.04,
                       price_base_year = 2026L, asset_id = "b1", measure_id = "m1")
  v <- wsei_row(r$flows, "cost")
  expect_equal(round(v[2:10], 2), c(-30965.24, -83258.52, -120933.06, -143843.62, -151843.98,
                                    -144786.97, -122524.47, -84907.36, -31785.57))
  expect_equal(round(sum(v), 2), -914848.79)
  lin <- capex_build_one(grid = g4, date = "2027-10-01", duration_months = 9L,
                         payment_profile = "linear", cost_eur = 900000, price_index = 0.04,
                         price_base_year = 2026L, asset_id = "b1", measure_id = "m1")
  vl <- wsei_row(lin$flows, "cost")
  expect_equal(round(vl[c(2, 10)], 2), c(-100327.37, -102985.24))
  expect_equal(round(sum(vl), 2), -914861.18)
  for (prof in c("front", "back")) {
    p <- capex_build_one(grid = g4, date = "2027-10-01", duration_months = 9L,
                         payment_profile = prof, cost_eur = 900000, price_index = 0,
                         asset_id = "b1", measure_id = "m1")
    expect_equal(sum(wsei_row(p$flows, "cost")), -900000)
  }
  expect_equal(capex_profile("front", 0.5), 0.75)
  expect_equal(capex_profile("back", 0.5), 0.25)
})

test_that("C4: Verzug der Maßnahme je Lauf (0 bzw. 14 Monate)", {
  g <- make_grid("annual", T = 25L)
  dr <- fake_draws(2L, g, static = list("components.x.delay_months" = c(0, 14)))
  r <- capex_build_one(grid = g, n = 2L, draws = dr, date = 2030, cost_eur = 32000,
                       price_base_year = 2026L, price_index = 0.03, asset_id = "b1",
                       measure_id = "m1")
  v <- r$flows$rows[[1]]$values
  expect_equal(which(v[1, ] != 0) - 1L, 3L)
  expect_equal(which(v[2, ] != 0) - 1L, 5L)
  expect_equal(round(v[2, 6], 2), -37096.77)
  expect_equal(r$flows$aux$completion_shift[, 1], c(0, 14))
})

test_that("C4b: Bauzeitverzug gestreckt (stretch), letzte Zahlung (last), ohne (none)", {
  g <- make_grid("annual", T = 25L)
  sched <- list(schedule = list("2027-07-01" = 0.4, "2028-07-01" = 0.6), unit = "share")
  dr <- fake_draws(2L, g, static = list("components.x.construction_delay_months" = c(6, 7)))
  r <- capex_build_one(grid = g, n = 2L, draws = dr, payment_schedule = sched,
                       cost_eur = 1e6, price_index = 0, construction_delay_mode = "stretch",
                       asset_id = "b1", measure_id = "m1")
  v <- r$flows$rows[[1]]$values
  expect_equal(v[, 2], c(-4e5, -4e5))
  expect_equal(v[1, 3], -6e5)
  expect_equal(v[2, 4], -6e5)
  expect_equal(rowSums(v), c(-1e6, -1e6))
  none <- capex_build_one(grid = g, n = 2L, draws = dr, payment_schedule = sched,
                          cost_eur = 1e6, price_index = 0, construction_delay_mode = "none",
                          asset_id = "b1", measure_id = "m1")
  expect_equal(none$flows$rows[[1]]$values[, 3], c(-6e5, -6e5))
  expect_equal(none$flows$aux$completion_shift[, 1], c(0, 0))
  last <- capex_build_one(grid = g, n = 2L, draws = dr, payment_schedule = sched,
                          cost_eur = 1e6, price_index = 0, construction_delay_mode = "last",
                          asset_id = "b1", measure_id = "m1")
  lv <- last$flows$rows[[1]]$values
  expect_equal(lv[, 2], c(-4e5, -4e5))
  expect_equal(lv[2, 4], -6e5)
  expect_equal(last$flows$aux$completion_shift[, 1], c(6, 7))
  # Zahlungsplan mit Beträgen (unit eur): Kosten = Summe, keine Zuschlagszeile
  sched <- list(schedule = list("2027-07-01" = 100000, "2028-07-01" = 50000), unit = "eur")
  eur <- capex_build_one(grid = g, payment_schedule = sched, price_index = 0,
                         asset_id = "b1", measure_id = "m1")
  ev <- wsei_row(eur$flows, "cost")
  expect_equal(ev[2:3], c(-100000, -50000))
  expect_equal(eur$flows$aux$cost_base[1, 1], 150000)
  expect_identical(eur$flows$meta$cost_mode, "eur")
})

test_that("C5: Kosten netto angegeben, Umsatzsteuer ableitbar (Spec 00 7.10)", {
  r <- capex_build_one(date = "2027-06-01", cost_eur = 100000, cost_is_net = TRUE,
                       vat_rate = 0.19, price_index = 0, asset_id = "b1", measure_id = "m1")
  row <- r$flows$rows[[1]]
  expect_equal(sum(row$values), -119000)
  expect_equal(sum(row$values) / (1 + row$vat_rate), -100000)
  expect_equal(sum(row$values) - sum(row$values) / (1 + row$vat_rate), -19000)
})

test_that("C6: Aktivierungsfaktor 0 ergibt Nullzeilen und keinen Wirkungsbeginn", {
  r <- capex_build_one(date = 2030, cost_eur = 32000, price_index = 0.03, active = 0,
                       asset_id = "b1", measure_id = "m1", contingency_share = 0.1)
  expect_identical(vapply(r$flows$rows, function(x) x$key, ""), c("cost", "contingency"))
  for (row in r$flows$rows) expect_true(all(row$values == 0))
  expect_true(all(r$flows$aux$in_operation == 0))
  expect_true(all(r$flows$aux$cost_base == 0))
})

test_that("C7: Wirkungsbeginn auf G4 mit Bauzeitverzug (in_operation)", {
  g4 <- make_grid("mixed", T = 30L)
  dr <- fake_draws(2L, g4, static = list("components.x.construction_delay_months" = c(0, 2)))
  r <- capex_build_one(grid = g4, n = 2L, draws = dr, date = "2027-10-01",
                       completion_date = "2027-10-01", cost_eur = 1000, price_index = 0,
                       construction_delay_mode = "stretch", asset_id = "b1", measure_id = "m1")
  io <- r$flows$aux$in_operation
  expect_equal(io[1, 10:12], c(0, 1, 1))
  expect_equal(io[2, 10:12], c(0, 1 / 3, 1), tolerance = 1e-12)
  # effect_start next_year: ab 1. Januar nach dem Fertigstellungsmonat
  ny <- capex_build_one(grid = g4, date = "2027-10-01", cost_eur = 1000, price_index = 0,
                        effect_start = "next_year", asset_id = "b1", measure_id = "m1")
  expect_equal(ny$flows$aux$in_operation[1, 10:12], c(0, 0, 1))
})

test_that("C8: Preisstand vor dem Stichtag über den Vorlauf des Baupreisindex", {
  bpi <- list(series = list("2026" = 0.05, "2027" = 0.035), fill = "locf", before = "first")
  r <- capex_build_one(price_base_year = 2024L, date = "2027-07-01", cost_eur = 100000,
                       market = list(construction_price_index = bpi),
                       asset_id = "b1", measure_id = "m1")
  v <- wsei_row(r$flows, "cost")
  expect_equal(v[2], -100000 * 1.05 * 1.05 * 1.035, tolerance = 1e-12)
  expect_equal(round(v[2], 2), -114108.75)
})

test_that("C9: Kosten als Bezug auf die Domäne (Bezug statt Kopie)", {
  g <- make_grid("annual", T = 10L)
  comp <- make_component("capex", cost_eur = list(ref = "measures.wp.cost_eur"), date = 2028,
                         price_index = 0.03, asset_id = "b1", measure_id = "m1")
  spec <- make_spec(g)
  spec$measures <- list(wp = list(cost_eur = node_const(130000)))
  spec <- path_set(spec, "components.x", comp)
  ctx <- make_ctx(1L, grid = g, spec = spec)
  v <- wsei_row(reg_get("flow", "capex")$build(comp, ctx), "cost")
  expect_equal(v[2], -130000 * 1.03)
  expect_identical(comp$cost_eur$kind, "ref")
})

test_that("Hilfsgrößen: Ohnehin-Anteil, Modernisierungsanteil, Metadaten", {
  r <- capex_build_one(date = "2027-06-01", cost_eur = 100000, ohnehin_share = 0.3,
                       price_index = 0, cost_factor = 1.1, asset_id = "b1", measure_id = "m1")
  aux <- r$flows$aux
  expect_equal(aux$cost_base[1, 1], 110000)
  expect_equal(aux$ohnehin_base[1, 1], 33000)
  expect_equal(aux$modernization_base[1, 1], 77000)
  expect_identical(r$flows$meta$completion_date, as.Date("2027-06-01"))
  oc <- capex_build_one(date = "2027-06-01", cost_eur = 100000, ohnehin_cost_eur = 150000,
                        price_index = 0, asset_id = "b1", measure_id = "m1")
  expect_equal(oc$flows$aux$ohnehin_base[1, 1], 100000)
  ero <- capex_build_one(date = "2027-06-01", cost_eur = 1000, classification = "erhaltung",
                         spread_years = 3L, price_index = 0, asset_id = "b1", measure_id = "m1")
  row <- ero$flows$rows[[1]]
  expect_identical(row$tax_category, "capex_expensable")
  expect_identical(row$extra$spread_years, 3L)
})

test_that("Zahlungen jenseits des Horizonts entfallen (Hinweis mit Laufanteil)", {
  g <- make_grid("annual", T = 6L)
  expect_message(r <- capex_build_one(grid = g, date = 2040, cost_eur = 1000, price_index = 0,
                                      asset_id = "b1", measure_id = "m1"),
                 "jenseits des Horizonts")
  expect_true(all(wsei_row(r$flows, "cost") == 0))
})

test_that("Fehlende Termine bzw. Kosten sind Vertragsfehler", {
  expect_error(capex_build_one(cost_eur = 1000, asset_id = "b1", measure_id = "m1"),
               class = "vofi_error_contract")
  expect_error(capex_build_one(date = 2028, asset_id = "b1", measure_id = "m1"),
               class = "vofi_error_contract")
})

test_that("Batch-Invarianz mit laufspezifischen Kosten, Verzug und Index", {
  g <- make_grid("mixed", T = 6L)
  fun <- function(n, draws) {
    comp <- make_component("capex", cost_kg = list(kg300 = 1e5, kg400 = 5e4), kg700_share = 0.1,
                           contingency_share = 0.05, date = "2027-10-01",
                           duration_months = 6L, payment_profile = "s_curve",
                           price_index = 0.03, construction_delay_mode = "stretch",
                           asset_id = "b1", measure_id = "m1")
    reg_get("flow", "capex")$build(comp, make_ctx(n, grid = g, spec = comp, draws = draws))
  }
  st <- list(
    "components.x.delay_months" = c(0, 1, 2, 5, 9, 14, 30),
    "components.x.construction_delay_months" = c(0, 3, 0, 7, 2, 1, 4),
    "components.x.cost_factor" = c(1, 1.1, 0.9, 1.2, 1, 1.05, 1.3)
  )
  dr <- fake_draws(7L, g, static = st)
  expect_batch_invariance(fun, n = 7L, grid = g, draws = dr)
  expect_no_rng(fun(7L, dr))
})

test_that("validate(): Befunde nach Spec 01 Teil A 4.6.5 (validation.measures.*)", {
  f <- wsei_findings("capex", cost_eur = 1000, asset_id = "b1", measure_id = "m1")
  expect_identical(unname(f["measures.timing"]), "error")
  f <- wsei_findings("capex", date = 2028, asset_id = "b1", measure_id = "m1")
  expect_identical(unname(f["measures.cost_source"]), "error")
  f <- wsei_findings("capex", date = 2028, cost_eur = 1, cost_kg = list(kg300 = 1),
                     asset_id = "b1", measure_id = "m1")
  expect_true("measures.cost_source" %in% names(f))
  f <- wsei_findings("capex", date = 2028, cost_kg = list(kg300 = 1, kg800 = 2, kg700 = 3),
                     kg700_share = 0.1, asset_id = "b1", measure_id = "m1")
  expect_identical(unname(f[c("measures.kg800", "measures.kg700_double")]),
                   c("error", "warning"))
  # andere unbekannte Schlüssel der Map cost_kg: blockübergreifend unknown_field
  comp <- make_component("capex", date = 2028, cost_kg = list(kg300 = 1), asset_id = "b1",
                         measure_id = "m1")
  comp$cost_kg$kg100 <- node_const(5)
  out <- capex_validate(comp, make_spec())
  expect_identical(vapply(out, function(x) x$code, ""), "validation.unknown_field")
  expect_identical(out[[1]]$path, "components.x.cost_kg.kg100")
  f <- wsei_findings("capex", payment_schedule = list(schedule = list("2027-07-01" = 0.4,
                                                                      "2028-07-01" = 0.5),
                                                      unit = "share"),
                     cost_eur = 1, duration_months = 3L, asset_id = "b1", measure_id = "m1")
  expect_identical(unname(f[c("measures.schedule_sum", "measures.timing")]), c("error", "error"))
  f <- wsei_findings("capex", payment_schedule = list(schedule = list("2027-07-01" = 10)),
                     contingency_share = 0.1, asset_id = "b1", measure_id = "m1")
  expect_identical(unname(f["measures.contingency_ignored"]), "warning")
  f <- wsei_findings("capex", date = "2027-03-01", duration_months = 6L, cost_eur = 1,
                     completion_date = "2026-09-01", active = 0.5, vat_rate = 0.1,
                     delay_months = 0)
  expect_true(all(c("measures.before_valuation", "measures.completion_order",
                    "measures.active_fraction", "measures.ids_missing",
                    "measures.vat_unusual") %in% names(f)))
  f <- wsei_findings("capex", date = 2028, cost_eur = 1, asset_id = "b1", measure_id = "m1")
  expect_length(f, 0L)
  # Befunde sind vofi_finding-Objekte mit Pfad der Komponente
  out <- capex_validate(make_component("capex", cost_eur = 1, asset_id = "b1",
                                       measure_id = "m1"), make_spec())
  expect_s3_class(out[[1]], "vofi_finding")
  expect_identical(out[[1]]$code, "validation.measures.timing")
  expect_identical(out[[1]]$path, "components.x")
  # negative Verschiebung: Wertegrenze des Schemas (validation.range), kein eigener Befund
  comp <- make_component("capex", date = 2028, cost_eur = 1, asset_id = "b1", measure_id = "m1")
  comp$delay_months <- node_const(-1)
  expect_length(capex_validate(comp, make_spec()), 0L)
  # Aktivierungsfaktor als Ausdruck: Basisfallwert entscheidet (a_m, 4.5.2)
  sc <- make_spec(make_grid())
  sc$measures <- list(m1 = list(active = node_const(0.5)))
  f <- wsei_findings("capex", date = 2028, cost_eur = 1, asset_id = "b1", measure_id = "m1",
                     active = list(expr = "measures.m1.active * 1"), scenario = sc)
  expect_identical(unname(f["measures.active_fraction"]), "warning")
})

test_that("vofi_validate(): Befunde der Typen erscheinen im Bericht unter validation.*", {
  sc <- example_scenario("skeleton")
  x <- unclass(sc)
  x$components$wp <- list(type = "capex", cost_eur = 50000, asset_id = "b1", measure_id = "wp")
  rep <- vofi_validate(vofi_scenario(x))
  hit <- rep[rep$code == "validation.measures.timing", , drop = FALSE]
  expect_identical(nrow(hit), 1L)
  expect_identical(hit$severity, "error")
  expect_identical(hit$path, "components.wp")
  # Text aus validation.yaml (WS-B): die Fundstelle nennt die Komponente
  expect_match(hit$message, "'components.wp'", fixed = TRUE)
})

test_that("Bau über vofi_build()/vofi_run(): Investitionszeile im Ledger mit Tags", {
  sc <- example_scenario("skeleton")
  x <- unclass(sc)
  x$components$wp <- list(type = "capex", cost_eur = 50000, date = as.Date("2028-01-01"),
                          price_index = 0.02, asset_id = "b1", measure_id = "wp")
  res <- vofi_run(vofi_build(vofi_scenario(x)))
  rows <- res$ledger$rows
  expect_true("wp__cost" %in% rows$key)
  expect_identical(rows$category[rows$key == "wp__cost"], "capex")
  expect_equal(res$ledger$values[["wp__cost"]][1, 2], -50000 * 1.02)
  expect_vofi_invariants(res)
})

test_that("Basisfallwerte für validate(): typ_base_resolver() und typ_capex_base_cost()", {
  sc <- make_spec(make_grid("annual", T = 10L))
  sc$measures <- list(m1 = list(cost_eur = node_const(1000), kg300 = node_const(799500)))
  put <- function(sc, id, ...) {
    path_set(sc, path_join("components", id), make_component("capex", id = id, ...))
  }
  # C2: K = 1.451.488,50 (Bezug auf ein Domänenblatt)
  sc <- put(sc, "c2", date = 2028, asset_id = "b1", measure_id = "m1",
            cost_kg = list(kg300 = list(ref = "measures.m1.kg300"), kg400 = 372000),
            kg700_share = 0.18, contingency_share = 0.05)
  base <- typ_base_resolver(sc)
  expect_equal(typ_capex_base_cost(sc$components$c2, "c2", base), 1451488.50)
  # cost_eur netto mit Faktor und Aktivierung
  sc <- put(sc, "c1", date = 2028, asset_id = "b1", measure_id = "m1",
            cost_eur = list(ref = "measures.m1.cost_eur"), cost_is_net = TRUE, cost_factor = 1.1,
            contingency_share = 0.1, active = 0.5)
  base <- typ_base_resolver(sc)
  expect_equal(typ_capex_base_cost(sc$components$c1, "c1", base), 1000 * 1.1 * 1.19 * 1.1 * 0.5)
  # Zahlungsplan in EUR: Summe der Beträge ohne Zuschlag
  sc <- put(sc, "c3", asset_id = "b1", measure_id = "m1", contingency_share = 0.1,
            payment_schedule = list(schedule = list("2027-07-01" = 100, "2028-07-01" = 50),
                                    unit = "eur"))
  base <- typ_base_resolver(sc)
  expect_equal(typ_capex_base_cost(sc$components$c3, "c3", base), 150)
  sc <- put(sc, "c4", date = 2028, asset_id = "b1", measure_id = "m1")
  expect_null(typ_capex_base_cost(sc$components$c4, "c4", typ_base_resolver(sc)))
  # Auflöser: fehlender Pfad, Nicht-Knoten, zeitabhängiger Wert -> NULL
  expect_null(base("components.c1.gibt_es_nicht"))
  expect_null(base("components.c1.classification"))
  sc$market$series_x <- node_normalize(list(series = list("2027" = 1, "2030" = 2)),
                                       vofi_param("value"), "market.series_x")
  sc <- put(sc, "c5", date = 2028, asset_id = "b1", measure_id = "m1",
            cost_eur = list(ref = "market.series_x"))
  expect_null(typ_base_resolver(sc)("components.c5.cost_eur"))
  # ohne Stichtag kein Raster: Bezüge bleiben unaufgelöst, Konstanten gelten
  sc0 <- sc
  sc0$project$valuation_date <- NULL
  b0 <- typ_base_resolver(sc0)
  expect_null(b0("components.c1.cost_eur"))
  expect_equal(b0("components.c1.cost_factor"), 1.1)
  expect_null(typ_scenario_grid(sc0))
})
