# Tests des Zahlungstyps residual_value (WS-E-INV; Spec 01 Teil A 6, Prüfwerte RV1-RV11).

# Hinweise (vofi_inform) nur dort, wo wsei_capture() sie mitschneidet
withr::local_options(vofi.verbose = FALSE)

rv3_comps <- function(rv = list()) {
  base <- list(type = "residual_value", method = "income_value", sale_cost_share = 0.03,
               n_units = 10, living_area_m2 = 700, after = c("rent", "loss", "co2"),
               income_value = list(cap_rate = 0.03, remaining_life_method = "manual",
                                   remaining_life_years = 40, land_value_eur = 200000,
                                   land_value_growth = 0.015, forward_growth = 0.02,
                                   cost_forward_growth = 0.02, bwk = list(index = 0.02)))
  list(
    rent = list(type = "custom_series", category = "rent", values = c(0, 0, 0, 100000)),
    loss = list(type = "custom_series", category = "rent_loss", values = c(0, 0, 0, -3000)),
    co2 = list(type = "custom_series", category = "co2_cost", values = c(0, 0, 0, -1000)),
    rv = utils::modifyList(base, rv)
  )
}

rv3_build <- function(rv = list(), ...) {
  suppressMessages(wsei_build(rv3_comps(rv), make_grid("annual", T = 3L), ...))
}

r1_comps <- function(rv = list(), active = 1) {
  list(
    cx = list(type = "capex", date = "2027-10-01", cost_eur = 126000, price_index = 0.03,
              price_base_year = 2026L, asset_id = "b1", measure_id = "m1", active = active),
    rx = list(type = "replacement", capex_id = "cx", install_date = "2027-10-01",
              useful_life_years = 18, price_index = 0.03, price_base_year = 2026L,
              asset_id = "b1", measure_id = "m1"),
    rv = utils::modifyList(list(type = "residual_value", method = "component",
                                after = c("cx", "rx")), rv)
  )
}

test_that("Vertrag und Registrierung", {
  expect_type_contract("residual_value", "flow")
  expect_identical(reg_get("flow", "residual_value")$rows,
                   c("value", "sale_cost", "market_value", "path_method", "path_measures"))
})

test_that("RV1: Kapitalisierungsfaktor und Ertragswert (general = simplified)", {
  kf <- rv_kf(0.03, 50)
  expect_equal(round(kf, 6), 25.729764)
  general <- (60338 - 200000 * 0.03) * kf + 200000
  simplified <- 60338 * kf + 200000 / 1.03^50
  expect_equal(round(general, 2), 1598103.92)
  expect_equal(general, simplified, tolerance = 1e-12)
  expect_equal(rv_kf(c(0, 1e-13), c(40, 40)), c(40, 40))
  expect_equal(rv_kf(matrix(0.03, 2, 2), matrix(40, 2, 2)), matrix(rv_kf(0.03, 40), 2, 2))
})

test_that("RV2: Restnutzungsdauer nach Anlage 2 (GND 80)", {
  tab <- rv_anlage2_table()
  rnd <- rv_rnd_anlage2(c(56, 56, 56, 56, 94, 94, 30, 16), c(0, 8, 12, 18, 4, 12, 0, 8), 80, tab)
  expect_equal(round(rnd, 4), c(24.0, 38.0, 45.9968, 58.56, 21.304, 41.456, 50, 64.0))
  # Punkte werden abgerundet und auf 0 ... 20 begrenzt; Matrixform bleibt erhalten
  expect_equal(rv_rnd_anlage2(56, 8.7, 80, tab), 38)
  expect_equal(rv_rnd_anlage2(56, 25, 80, tab), rv_rnd_anlage2(56, 20, 80, tab))
  m <- rv_rnd_anlage2(matrix(c(56, 30), 1, 2), matrix(0, 1, 2), 80, tab)
  expect_identical(dim(m), c(1L, 2L))
  expect_equal(c(m), c(24, 50))
})

test_that("RV3: Ertragswert mit BWK-Modellwerten, Verkaufskosten und Pfad V_2", {
  res <- rv3_build()
  f <- res$flows$rv
  mv <- wsei_row(f, "market_value")
  expect_equal(round(mv[4], 2), 1983483.07)
  expect_equal(round(mv[3], 2), 1967290.55)
  expect_equal(round(wsei_row(f, "value"), 2), c(0, 0, 0, 1983483.07))
  expect_equal(round(wsei_row(f, "sale_cost"), 2), c(0, 0, 0, -59504.49))
  expect_equal(round(sum(wsei_sums(f)[c("value", "sale_cost")]), 2), 1923978.58)
  expect_equal(wsei_row(f, "path_method"), mv * 0.97, tolerance = 1e-12)
  expect_true(all(wsei_row(f, "path_measures") == 0))
  # Teilgrößen: KF_T, BW_T, I^bwk_T
  expect_equal(round(rv_kf(0.03, 40), 6), 23.114772)
  expect_equal(round(rv_kf(0.03, 41), 6), 23.4124)
  expect_equal(200000 * 1.015^3, 209135.68, tolerance = 1e-7)
  expect_equal(1.02^4, 1.08243216)
  # Zeilenattribute (R-72)
  rows <- stats::setNames(f$rows, vapply(f$rows, function(r) r$key, ""))
  expect_identical(c(rows$value$category, rows$sale_cost$category),
                   c("residual_value", "sale_cost"))
  expect_identical(c(rows$market_value$section, rows$market_value$category),
                   c("memo", "market_value"))
  expect_identical(c(rows$path_method$extra$rv_basis, rows$path_measures$extra$rv_basis),
                   c("method", "measures"))
  expect_identical(rows$path_method$category, "residual_path")
  expect_false(rows$market_value$cash)
  expect_identical(f$meta$method, "income_value")
  expect_vofi_flows_contract(f, res$ctx, reg_get("flow", "residual_value"))
  # Variante simplified liefert denselben Wert (Bodenwertverzinsung über KF)
  fs <- rv3_build(list(income_value = list(variant = "simplified")))$flows$rv
  expect_equal(wsei_row(fs, "market_value")[4], mv[4], tolerance = 1e-9)
})

test_that("RV4/RV5: Rohertragsvervielfältiger und Exit-Rendite auf RV3", {
  f4 <- rv3_build(list(method = "multiplier",
                       multiplier = list(factor = 20, forward_growth = 0.02)))$flows$rv
  expect_equal(round(wsei_row(f4, "market_value")[4], 2), 2040000)
  f5 <- rv3_build(list(method = "exit_yield",
                       exit_yield = list(cap_rate = 0.05, forward_growth = 0.02,
                                         cost_forward_growth = 0.02)))$flows$rv
  expect_equal(round(wsei_row(f5, "market_value")[4], 2), 1958400)
  # nachlaufendes Fenster: Periode 3 selbst
  f4t <- rv3_build(list(method = "multiplier",
                        multiplier = list(factor = 20, income_basis = "trailing")))$flows$rv
  expect_equal(wsei_row(f4t, "market_value")[4], 2e6)
})

test_that("RV6: Sachwert linear mit Zuschlag und Bodenwert", {
  g30 <- make_grid("annual", T = 30L)
  comps <- list(
    cx = list(type = "capex", date = "2027-12-01", cost_eur = 500000, price_index = 0.03,
              price_base_year = 2026L, asset_id = "b1", measure_id = "m1"),
    rv = list(type = "residual_value", method = "asset_value", after = "cx",
              sale_cost_share = 0.03,
              asset_value = list(gnd_years = 80, uplift_share = 0.03, index = 0.03,
                                 land_value_eur = 150000, land_value_growth = 0.015))
  )
  res <- suppressMessages(wsei_build(comps, g30))
  expect_equal(round(sum(res$flows$cx$aux$cost_total[1, ]), 2), 515000)
  expect_equal(round(wsei_row(res$flows$rv, "market_value")[31], 2), 1030060.52)
  # Teilgrößen nach 6.3.6
  share <- 1 - (349 / 12) / 80
  expect_equal(round(share, 6), 0.636458)
  expect_equal(round(515000 * 1.03^29 * share, 2), 772425.71)
  expect_equal(round(150000 * 1.015^30, 2), 234462.03)
})

test_that("RV7: Marktwertfortschreibung", {
  g25 <- make_grid("annual", T = 25L)
  f <- wsei_build(list(rv = list(type = "residual_value", method = "market_growth",
                                 market_growth = list(base_value_eur = 400000,
                                                      growth = 0.0175))), g25)$flows$rv
  mv <- wsei_row(f, "market_value")
  expect_equal(round(mv[26], 2), 617192.21)
  expect_equal(mv[1], 400000)
  expect_equal(wsei_row(f, "value")[26], mv[26])
})

test_that("RV8/RV9: Komponenten-Zeitwert (indexiert/nominal) und Methode zero", {
  g30 <- make_grid("annual", T = 30L)
  f8 <- wsei_build(r1_comps(), g30)$flows$rv
  expect_equal(round(wsei_row(f8, "market_value")[31], 2), 114688.15)
  f8n <- wsei_build(r1_comps(list(component = list(indexed = FALSE))), g30)$flows$rv
  expect_equal(round(wsei_row(f8n, "market_value")[31], 2), 82853.16)
  expect_equal(wsei_row(f8n, "market_value")[31], 126000 * 1.03^19 * 0.375, tolerance = 1e-12)
  f9 <- wsei_build(r1_comps(list(method = "zero")), g30)$flows$rv
  s <- wsei_sums(f9)
  expect_equal(unname(s[c("value", "sale_cost", "market_value", "path_method")]), rep(0, 4))
  expect_equal(round(wsei_row(f9, "path_measures")[31], 2), 111247.51)
})

test_that("RV10: RV3 mit a_m = 0 für alle Maßnahmen -> path_measures = 0", {
  after <- list(after = c("rent", "loss", "co2", "cx", "rx"))
  comps <- c(r1_comps(active = 0)[c("cx", "rx")], rv3_comps(after))
  g <- make_grid("annual", T = 3L)
  f <- suppressMessages(wsei_build(comps, g))$flows$rv
  expect_true(all(wsei_row(f, "path_measures") == 0))
  expect_equal(round(wsei_row(f, "market_value")[4], 2), 1983483.07)
  # mit a_m = 1 trägt die Maßnahme zum Maßnahmenpfad bei
  comps1 <- c(r1_comps(active = 1)[c("cx", "rx")], rv3_comps(after))
  f1 <- suppressMessages(wsei_build(comps1, g))$flows$rv
  expect_true(wsei_row(f1, "path_measures")[4] > 0)
})

test_that("RV11: Komponenten-Zeitwert nominal mit Baunebenkosten und Grundstückskauf", {
  g30 <- make_grid("annual", T = 30L)
  repl <- function(cx) {
    list(type = "replacement", capex_id = cx, install_date = "2027-12-01",
         useful_life_years = 80, price_index = 0, asset_id = "b1", measure_id = "m1")
  }
  comps <- list(
    neubau = list(type = "capex", date = "2027-12-01", cost_eur = 1000000, price_index = 0,
                  asset_id = "b1", measure_id = "m1"),
    bnk = list(type = "capex", date = "2027-12-01", cost_eur = 200000, price_index = 0,
               asset_id = "b1", measure_id = "m1"),
    neubau_repl = repl("neubau"),
    bnk_repl = repl("bnk"),
    grund = list(type = "land", purchase_price_eur = 300000, land_share = 1,
                 date = "2027-01-01", measure_id = "m1"),
    rv = list(type = "residual_value", method = "component", sale_cost_share = 0.03,
              component = list(indexed = FALSE),
              after = c("neubau", "bnk", "neubau_repl", "bnk_repl", "grund"))
  )
  f <- wsei_build(comps, g30)$flows$rv
  expect_equal(round(wsei_row(f, "market_value")[31], 2), 763750)
  expect_equal(763750, 1200000 * (1 - 349 / 960))
  expect_equal(round(wsei_row(f, "path_measures")[31], 2), 740837.50)
})

test_that("Pfad vor Betriebsbeginn: Kostenpfad (Neubau), zero und method", {
  g4 <- make_grid("mixed", T = 3L)
  comps <- list(
    cx = list(type = "capex", date = "2027-05-01", cost_eur = 500000, price_index = 0,
              asset_id = "b1", measure_id = "m1"),
    rv = list(type = "residual_value", method = "market_growth", after = "cx",
              market_growth = list(base_value_eur = 900000, growth = 0))
  )
  pre <- which(g4$phase == "construction")
  mv <- wsei_row(wsei_build(comps, g4)$flows$rv, "market_value")
  pay <- which(g4$date_end >= as.Date("2027-05-01"))[1]
  expect_equal(mv[pre], ifelse(seq_along(pre) >= pay, 500000, 0))
  expect_equal(mv[g4$T + 1L], 900000)
  comps$rv$path_pre_operation <- "zero"
  mz <- wsei_row(wsei_build(comps, g4)$flows$rv, "market_value")
  expect_true(all(mz[pre] == 0))
  comps$rv$path_pre_operation <- "method"
  mm <- wsei_row(wsei_build(comps, g4)$flows$rv, "market_value")
  expect_true(all(mm == 900000))
})

test_that("Fehlende Angaben und Hinweise im Bau", {
  # Anlage 2 ohne Baujahr im Bestandsprojekt
  no_year <- function(s) {
    s$project$project_type <- "sanierung_eh"
    s$building$construction_year <- NULL
    s
  }
  expect_error(rv3_build(list(income_value = list(remaining_life_method = "anlage2")),
                         spec_fun = no_year),
               class = "vofi_error_contract")
  # Neubauprojekt: Baujahr* = Jahr der (verschobenen) Fertigstellung, kein Fehler
  a2 <- rv3_build(list(income_value = list(remaining_life_method = "anlage2")))
  expect_s3_class(a2$flows$rv, "vofi_flows")
  comps <- rv3_comps()
  comps$rv$income_value$remaining_life_years <- NULL
  expect_error(suppressMessages(wsei_build(comps, make_grid("annual", T = 3L))),
               class = "vofi_error_contract")
  comps <- rv3_comps()
  comps$rv$income_value$land_value_eur <- NULL
  no_land <- function(s) {
    s$building$land_value_eur <- NULL
    s
  }
  expect_error(suppressMessages(wsei_build(comps, make_grid("annual", T = 3L),
                                           spec_fun = no_land)),
               class = "vofi_error_contract")
  comps <- rv3_comps(list(income_value = list(cap_rate = 0.03)))
  comps$rent$values <- c(0, 0, 0, 1000)
  cap <- wsei_capture(wsei_build(comps, make_grid("annual", T = 3L)))
  expect_true("types.flow.residual_value.msg.liquidation_floor" %in% cap$keys)
  # Gebäudeertragswert begrenzt auf -Freilegung (0): Wert = Bodenwert
  expect_equal(wsei_row(cap$value$flows$rv, "market_value")[4], 200000 * 1.015^3,
               tolerance = 1e-12)
  # Maßnahme ohne Nutzungsdauer: Herstellungswert ohne Abschreibung mit Hinweis
  g <- make_grid("annual", T = 3L)
  c2 <- list(cx = list(type = "capex", date = "2027-06-01", cost_eur = 1000, price_index = 0,
                       asset_id = "b1", measure_id = "m1"),
             rv = list(type = "residual_value", method = "component", after = "cx"))
  cap <- wsei_capture(wsei_build(c2, g))
  expect_identical(cap$keys, "types.flow.residual_value.msg.no_useful_life")
  expect_equal(wsei_row(cap$value$flows$rv, "market_value"), c(0, 1000, 1000, 1000))
})

test_that("Anlage 2 mit Modernisierungspunkten einer wirkenden Maßnahme", {
  g <- make_grid("annual", T = 3L)
  comps <- rv3_comps(list(construction_year = 1971L, after = c("rent", "loss", "co2", "cx"),
                          points_before = list(heating = 2),
                          points_measures = list(m1 = list(facade_insulation = 4,
                                                           windows_doors = 2)),
                          income_value = list(remaining_life_method = "anlage2",
                                              remaining_life_years = NULL)))
  comps <- c(list(cx = list(type = "capex", date = "2028-06-01", cost_eur = 1, price_index = 0,
                            asset_id = "b1", measure_id = "m1")), comps)
  sf <- function(s) {
    s$project$project_type <- "sanierung_eh"
    s
  }
  f <- suppressMessages(wsei_build(comps, g, spec_fun = sf))$flows$rv
  mv <- wsei_row(f, "market_value")
  # ohne Maßnahme: 2 Punkte; mit Maßnahme (ab 2028-06): 8 Punkte -> höhere RND
  comps$cx$active <- 0
  f0 <- suppressMessages(wsei_build(comps, g, spec_fun = sf))$flows$rv
  mv0 <- wsei_row(f0, "market_value")
  expect_true(mv[4] > mv0[4])
  tab <- rv_anlage2_table()
  expect_true(rv_rnd_anlage2(59, 8, 80, tab) > rv_rnd_anlage2(59, 2, 80, tab))
})

test_that("validate(): Befunde nach Spec 01 Teil A 6.6 (validation.residual.*, R-117)", {
  sc <- make_spec(make_grid())
  sc$project$project_type <- "sanierung_eh"
  sc$building$construction_year <- NULL
  f <- wsei_findings("residual_value", method = "income_value",
                     income_value = list(remaining_life_method = "manual", cap_rate = 0.08,
                                         bog_component_residual = TRUE,
                                         land_value_eur = 100000),
                     sale_cost_share = 0.1, points_before = list(heating = 5),
                     scenario = sc)
  keys <- paste0("residual.", c("rnd_manual_missing", "double_count", "cap_rate_unusual",
                                "sale_cost_high", "points_capped", "no_rent"))
  expect_identical(unname(f[keys]),
                   c("error", "warning", "warning", "warning", "warning", "warning"))
  expect_true(all(startsWith(names(f), "residual.")))
  f <- wsei_findings("residual_value", method = "income_value", scenario = sc)
  expect_identical(unname(f["residual.construction_year_missing"]), "error")
  f <- wsei_findings("residual_value", method = "income_value",
                     fictitious_construction_year = 1990L,
                     points_measures = list(m1 = list(heating = 2)), scenario = sc)
  expect_identical(unname(f["residual.fictitious_and_points"]), "warning")
  f <- wsei_findings("residual_value", method = "multiplier", multiplier = list(factor = 40))
  expect_identical(unname(f["residual.factor_unusual"]), "warning")
  sc2 <- make_spec(make_grid())
  sc2$building$existing_value_eur <- 500000
  f <- wsei_findings("residual_value", method = "component",
                     component = list(include_existing = "false"), scenario = sc2)
  expect_identical(unname(f["residual.existing_without_value"]), "warning")
  expect_length(wsei_findings("residual_value", method = "zero"), 0L)
})

test_that("validate(): land_value_missing, no_rent und no_useful_life als Befunde (6.6)", {
  sc <- make_spec(make_grid())
  # Bodenwert als Bezug auf building.land_value_eur, das fehlt: Befund statt Laufzeitabbruch
  f <- wsei_findings("residual_value", method = "income_value",
                     income_value = list(remaining_life_method = "manual",
                                         remaining_life_years = 40), scenario = sc)
  expect_identical(unname(f["residual.land_value_missing"]), "error")
  f <- wsei_findings("residual_value", method = "asset_value", scenario = sc)
  expect_identical(unname(f["residual.land_value_missing"]), "error")
  sc$building$land_value_eur <- node_const(150000)
  f <- wsei_findings("residual_value", method = "asset_value", scenario = sc)
  expect_false("residual.land_value_missing" %in% names(f))
  # Untermaps anderer Methoden werden nicht geprüft (6.1, R-115)
  sc0 <- make_spec(make_grid())
  expect_length(wsei_findings("residual_value", method = "market_growth", scenario = sc0), 0L)
  # ohne Mietkomponente bzw. beim Selbstnutzer: no_rent (income_value, multiplier, exit_yield)
  for (m in c("multiplier", "exit_yield")) {
    f <- wsei_findings("residual_value", method = m, scenario = sc)
    expect_identical(unname(f["residual.no_rent"]), "warning")
  }
  sc$components$miete <- make_component("recurring", amount_eur = 1, category = "rent",
                                        id = "miete")
  expect_false("residual.no_rent" %in% names(wsei_findings("residual_value",
                                                           method = "multiplier",
                                                           scenario = sc)))
  sc$project$perspective <- "selbstnutzer"
  f <- wsei_findings("residual_value", method = "multiplier", scenario = sc)
  expect_identical(unname(f["residual.no_rent"]), "warning")
  # Maßnahme ohne Wertpfad einer Ersatzkomponente
  sc3 <- make_spec(make_grid())
  sc3$components$cx <- make_component("capex", date = 2028, cost_eur = 1, asset_id = "b1",
                                      measure_id = "m1", id = "cx")
  sc3$components$cy <- make_component("capex", date = 2028, cost_eur = 1, asset_id = "b1",
                                      measure_id = "m2", id = "cy")
  sc3$components$ry <- make_component("replacement", capex_id = "cy", install_date = 2028,
                                      useful_life_years = 20, id = "ry")
  comp <- make_component("residual_value", method = "zero", after = c("cx", "cy", "ry"),
                         id = "rv")
  out <- residual_value_validate(comp, path_set(sc3, "components.rv", comp))
  expect_identical(vapply(out, function(x) x$code, ""), "validation.residual.no_useful_life")
  expect_identical(out[[1]]$severity, "info")
  expect_identical(out[[1]]$args$components, "cx")
})

test_that("Ende-zu-Ende: RW_T = value + sale_cost im Ledger (vofi_run)", {
  sc <- vofi_scenario(list(
    schema_version = 1L, meta = list(scenario_id = "rv_e2e", title = "Restwert"),
    project = list(perspective = "kleinvermieter", project_type = "sanierung_eh",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 3L),
    components = list(
      miete = list(type = "recurring", category = "rent", amount_eur = 100000,
                   base_date = "2027-01-01", start_event = "2027-01-01"),
      rv = list(type = "residual_value", method = "multiplier", sale_cost_share = 0.03,
                multiplier = list(factor = 20, forward_growth = 0), after = "miete")
    ),
    financing = list(ek = list(type = "equity", amount_eur = 10000)),
    accounts = list(deposit_rate_pa = 0, overdraft_rate_pa = 0, overdraft_limit_eur = Inf,
                    surplus_order = c("od_repay", "dep_invest"),
                    deficit_order = c("dep_withdraw", "od_draw", "equity_call")),
    analysis = list(kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value"))
  ))
  res <- vofi_run(vofi_build(sc))
  lv <- res$ledger$values
  rw <- lv[["rv__value"]][1, 4] + lv[["rv__sale_cost"]][1, 4]
  expect_equal(rw, 2e6 * 0.97)
  expect_equal(lv[["rv__path_method"]][1, 4], rw)
  expect_true(all(lv[["rv__value"]][1, 1:3] == 0))
  expect_true(all(res$checks$ok))
})

test_that("Batch-Invarianz (Liegenschaftszins und Miete je Lauf)", {
  g <- make_grid("annual", T = 3L)
  st <- list(
    "components.rv.income_value.cap_rate" = c(0.03, 0.025, 0.04, 0.035),
    "components.rv.sale_cost_share" = c(0.03, 0.02, 0.05, 0.01)
  )
  dr <- fake_draws(4L, g, static = st)
  fun <- function(n, draws) {
    suppressMessages(wsei_build(rv3_comps(), g, n = n, draws = draws))$flows$rv
  }
  expect_batch_invariance(fun, n = 4L, grid = g, draws = dr)
})

# ---------------------------------------------------------------------------------------------
# Review-Fixes (F2, F3, F6, F7, F8, F10, F11)
# ---------------------------------------------------------------------------------------------

mg_comps <- function(active2 = 1, date1 = "2028-01-01") {
  list(
    m1 = list(type = "capex", date = date1, cost_eur = 1, price_index = 0, asset_id = "b1",
              measure_id = "m1"),
    m2 = list(type = "capex", date = "2028-01-01", cost_eur = 1, price_index = 0,
              asset_id = "b1", measure_id = "m2", active = active2),
    rv = list(type = "residual_value", method = "market_growth", after = c("m1", "m2"),
              market_growth = list(base_value_eur = 1e6, growth = 0, uplift_share = 0.1))
  )
}

test_that("market_growth: inaktive Maßnahmen zählen wie fehlende (R-71, 4.12 Nr. 7)", {
  g <- make_grid("annual", T = 6L)
  mv <- function(comps) wsei_row(wsei_build(comps, g)$flows$rv, "market_value")
  expect_equal(mv(mg_comps()), c(1e6, 1e6, rep(1.1e6, 5)))
  expect_equal(mv(mg_comps(active2 = 0)), c(1e6, 1e6, rep(1.1e6, 5)))
  only1 <- mg_comps()
  only1$m2 <- NULL
  only1$rv$after <- "m1"
  expect_equal(mv(only1), mv(mg_comps(active2 = 0)))
  # alle Maßnahmen inaktiv: kein Wertzuschlag
  none <- mg_comps(active2 = 0)
  none$m1$active <- 0
  expect_equal(mv(none), rep(1e6, 7))
  # unterjährige Fertigstellung der aktiven Maßnahme: ω = Monatsanteil
  expect_equal(mv(mg_comps(active2 = 0, date1 = "2028-07-01"))[3], 1.05e6)
  # je Lauf (a_2 aus der Ziehung) und batch-invariant
  dr <- fake_draws(3L, g, static = list("components.m2.active" = c(1, 0, 1),
                                        "components.m1.delay_months" = c(0, 0, 12)))
  f <- wsei_build(mg_comps(), g, n = 3L, draws = dr)$flows$rv
  v <- f$rows[[3]]$values
  expect_equal(v[1, 3], 1.1e6)
  expect_equal(v[2, 3], 1.1e6)
  expect_equal(v[3, 3:4], c(1e6, 1.1e6))
  fun <- function(n, draws) wsei_build(mg_comps(), g, n = n, draws = draws)$flows$rv
  expect_batch_invariance(fun, n = 3L, grid = g, draws = dr)
})

el_comps <- function(rv = list()) {
  list(
    el = list(type = "replacement", include_initial = FALSE, install_date = "2015-01-01",
              useful_life_years = 18, cost_eur = 95000, price_index = 0, asset_id = "b1",
              measure_id = "kessel"),
    rv = utils::modifyList(list(type = "residual_value", method = "component", after = "el",
                                existing_value_eur = list(ref = "building.existing_value_eur"),
                                component = list(include_existing = "true",
                                                 existing_growth = 0)), rv)
  )
}

with_w0 <- function(s) {
  s$building$existing_value_eur <- node_const(500000)
  s
}

test_that("component: Bestandsbauteile nur mit Ersatzinvestitionen, nicht neben W_0 (3.2)", {
  g <- make_grid("annual", T = 10L)
  res <- wsei_build(el_comps(), g, spec_fun = with_w0)
  mv <- wsei_row(res$flows$rv, "market_value")
  # bis zum ersten Ersatz (2033-01-01, Ende von t = 6) nur der Bestandswert
  expect_equal(mv[1:6], rep(500000, 6))
  # danach zusätzlich der Zeitwert der Ersatzinvestition
  expect_equal(mv[7], 500000 + 95000)
  expect_equal(mv[11], 500000 + 95000 * (1 - 4 / 18), tolerance = 1e-12)
  # Wertpfad des Bauteils selbst bleibt nach 4.10.2 (C_0 = C · I_0 ab Einbau)
  ax <- res$flows$el$aux
  expect_equal(ax$value[1, 1], 95000 * (1 - 12 / 18), tolerance = 1e-12)
  expect_identical(ax$replaced[1, ], c(rep(0, 6), rep(1, 5)))
  # ohne Bestandswert und include_existing auto: Bauteile zählen nicht
  res0 <- wsei_build(el_comps(list(component = list(include_existing = "auto"))), g)
  expect_true(all(wsei_row(res0$flows$rv, "market_value") == 0))
  # nominaler Zeitwert gleich (Preisindex 0)
  res_n <- wsei_build(el_comps(list(component = list(indexed = FALSE))), g, spec_fun = with_w0)
  expect_equal(wsei_row(res_n$flows$rv, "market_value"), mv)
})

test_that("fehlender Bestandswert: Bezug auf building.existing_value_eur ergibt keinen Bestand", {
  g <- make_grid("annual", T = 10L)
  # component ohne Bestandswert: kein Abbruch, Bestand 0
  f <- wsei_build(el_comps(list(component = list(include_existing = "auto"))), g)$flows$rv
  expect_true(all(wsei_row(f, "market_value") == 0))
  # market_growth: Rückfall auf die Investitionsbasis 300.000 · 1,03 · 1,02^10
  comps <- list(
    cx = list(type = "capex", date = "2027-07-01", cost_eur = 300000, price_index = 0.03,
              price_base_year = 2026L, asset_id = "b1", measure_id = "m1"),
    rv = list(type = "residual_value", method = "market_growth", after = "cx",
              existing_value_eur = list(ref = "building.existing_value_eur"),
              market_growth = list(growth = 0.02))
  )
  mv <- wsei_row(wsei_build(comps, g)$flows$rv, "market_value")
  expect_equal(round(mv[11], 1), 376669.3)
  expect_equal(mv[11], 300000 * 1.03 * 1.02^10, tolerance = 1e-12)
  # mit Bestandswert W_0 bzw. Marktwert (ohne W_0) als Ausgangswert
  mw <- wsei_row(wsei_build(comps, g, spec_fun = with_w0)$flows$rv, "market_value")
  expect_equal(mw[c(1, 11)], 500000 * c(1, 1.02^10), tolerance = 1e-12)
  with_mv <- function(s) {
    s$building$market_value_eur <- node_const(450000)
    s
  }
  mm <- wsei_row(wsei_build(comps, g, spec_fun = with_mv)$flows$rv, "market_value")
  expect_equal(mm[c(1, 11)], 450000 * c(1, 1.02^10), tolerance = 1e-12)
  # Pfad vor Betriebsbeginn ohne Bestandswert (Kostenpfad, Neubau auf G4)
  g4 <- make_grid("mixed", T = 3L)
  comps$rv$market_growth <- list(base_value_eur = 900000, growth = 0)
  expect_s3_class(wsei_build(comps, g4)$flows$rv, "vofi_flows")
})

av_comps <- function(av = list(), with_repl = FALSE) {
  out <- list(
    cx = list(type = "capex", date = "2027-07-01", price_index = 0, asset_id = "b1",
              measure_id = "m1", cost_kg = list(kg300 = 100000, kg600 = 20000)),
    rv = list(type = "residual_value", method = "asset_value", after = "cx",
              construction_year = 1970L,
              existing_value_eur = list(ref = "building.existing_value_eur"),
              asset_value = utils::modifyList(list(index = 0, land_value_eur = 100000,
                                                   land_value_growth = 0), av))
  )
  if (with_repl) {
    out <- c(out[1], list(rx = list(type = "replacement", capex_id = "cx",
                                    install_date = "2027-07-01", useful_life_years = 20,
                                    price_index = 0, asset_id = "b1", measure_id = "m1")),
             out[2])
    out$rv$after <- c("cx", "rx")
  }
  out
}

bestand <- function(s) {
  s$project$project_type <- "sanierung_eh"
  s$building$existing_value_eur <- node_const(500000)
  s
}

test_that("asset_value: KG-Filter, Bestand W_0, Nutzungsdauer gnd bzw. component (6.3.6)", {
  g <- make_grid("annual", T = 10L)
  mv <- function(...) {
    wsei_row(wsei_build(av_comps(...), g, spec_fun = bestand)$flows$rv, "market_value")
  }
  # Z = 100.000 · (1 − 9,5/80); E = 400.000 · (1 − 10/23); BW = 100.000
  v <- mv()
  expect_equal(round(v[11], 2), 414211.96)
  expect_equal(v[11], 100000 * (1 - 9.5 / 80) + 400000 * (1 - 10 / 23) + 100000,
               tolerance = 1e-12)
  # life_basis component: Nutzungsdauer der Maßnahme (L = 20)
  vc <- mv(list(life_basis = "component"), with_repl = TRUE)
  expect_equal(round(vc[11], 2), 378586.96)
  # KG 600 nur mit kg_include
  v6 <- mv(list(kg_include = list(300L, 600L)))
  expect_equal(v6[11] - v[11], 20000 * (1 - 9.5 / 80), tolerance = 1e-9)
  # ohne Bestand (include_existing false)
  v0 <- mv(list(include_existing = FALSE))
  expect_equal(v0[11], 100000 * (1 - 9.5 / 80) + 100000, tolerance = 1e-12)
})

test_that("asset_value mit Erwerb: Gebäudeanteil des Kaufpreises als Bestand (6.3.6)", {
  g <- make_grid("annual", T = 10L)
  comps <- list(
    kauf = list(type = "land", purchase_price_eur = 1e6, land_share = 0.25,
                date = "2027-01-01", measure_id = "m1"),
    rv = list(type = "residual_value", method = "asset_value", after = "kauf",
              construction_year = 1970L,
              asset_value = list(index = 0, land_value_eur = 250000, land_value_growth = 0))
  )
  sf <- function(s) {
    s$project$project_type <- "erwerb_sanierung"
    s
  }
  mv <- wsei_row(wsei_build(comps, g, spec_fun = sf)$flows$rv, "market_value")
  expect_equal(mv[11], 750000 * (1 - 10 / 23) + 250000, tolerance = 1e-12)
  # component mit Erwerb: Gebäudeanteil ab Erwerb, Boden nur mit include_land
  comps$rv$method <- "component"
  comps$rv$component <- list(existing_growth = 0.01)
  mc <- wsei_row(wsei_build(comps, g, spec_fun = sf)$flows$rv, "market_value")
  expect_equal(mc[11], 750000 * 1.01^10, tolerance = 1e-12)
  comps$rv$component$include_land <- TRUE
  comps$rv$income_value <- list(land_value_eur = 250000, land_value_growth = 0)
  ml <- wsei_row(wsei_build(comps, g, spec_fun = sf)$flows$rv, "market_value")
  expect_equal(ml[11], 750000 * 1.01^10 + 250000, tolerance = 1e-12)
})

test_that("component.include_land addiert den Bodenwert", {
  g30 <- make_grid("annual", T = 30L)
  f <- wsei_build(r1_comps(list(component = list(include_land = TRUE),
                                income_value = list(land_value_eur = 100000,
                                                    land_value_growth = 0.01))),
                  g30)$flows$rv
  expect_equal(wsei_row(f, "market_value")[31], 126000 * 1.03^30 * 0.375 + 100000 * 1.01^30,
               tolerance = 1e-12)
})

test_that("Ertragswert: bog_eur, Abschlag stranded_discount_share, Freilegungskosten", {
  base <- rv3_build()$flows$rv
  v3 <- wsei_row(base, "market_value")
  bw_t <- 200000 * 1.015^3
  fb <- rv3_build(list(income_value = list(bog_eur = 25000)))$flows$rv
  expect_equal(wsei_row(fb, "market_value")[4], v3[4] + 25000, tolerance = 1e-12)
  fs <- rv3_build(list(income_value = list(stranded_discount_share = 0.1)))$flows$rv
  expect_equal(wsei_row(fs, "market_value")[4], bw_t + (v3[4] - bw_t) * 0.9, tolerance = 1e-9)
  # Liquidationswert: Gebäudeertragswert unter −Freilegungskosten (Preisstand Stichtag, bwk.index)
  comps <- rv3_comps(list(income_value = list(demolition_cost_eur = 50000)))
  comps$rent$values <- c(0, 0, 0, 1000)
  cap <- wsei_capture(wsei_build(comps, make_grid("annual", T = 3L)))
  expect_true("types.flow.residual_value.msg.liquidation_floor" %in% cap$keys)
  expect_equal(wsei_row(cap$value$flows$rv, "market_value")[4], bw_t - 50000 * 1.02^3,
               tolerance = 1e-9)
})

test_that("Ertragswert: Verwaltung aus dem Ledger ohne Umlagen (admin_source ledger)", {
  g <- make_grid("annual", T = 3L)
  comps <- list(
    rent = list(type = "custom_series", category = "rent", values = c(0, 1e5, 1e5, 1e5)),
    opex = list(type = "custom_series", category = "operating_cost",
                values = c(0, -5000, -5000, -5000)),
    pt = list(type = "custom_series", category = "operating_cost", tax_category = "passthrough",
              values = c(0, -3000, -3000, -3000)),
    rv = list(type = "residual_value", method = "income_value", sale_cost_share = 0,
              after = c("rent", "opex", "pt"),
              income_value = list(cap_rate = 0.03, remaining_life_method = "manual",
                                  remaining_life_years = 40, land_value_eur = 200000,
                                  land_value_growth = 0, forward_growth = 0,
                                  cost_forward_growth = 0,
                                  bwk = list(admin_source = "ledger",
                                             maintenance_source = "ledger",
                                             rent_loss_share = 0, vacancy_from_ledger = FALSE,
                                             variant_cost_categories = list())))
  )
  mv <- wsei_row(suppressMessages(wsei_build(comps, g))$flows$rv, "market_value")
  expect_equal(round(mv[4]), 2257215)
  expect_equal(mv[4], (95000 - 200000 * 0.03) * rv_kf(0.03, 40) + 200000, tolerance = 1e-12)
})

test_that("BWK-Modellwerte als Pfad (Art value mit Shape path)", {
  base <- wsei_row(rv3_build()$flows$rv, "market_value")
  maint <- list(series = list("2027" = 10, "2029" = 14.4))
  f <- rv3_build(list(income_value = list(bwk = list(index = 0.02,
                                                     maintenance_eur_m2_pa = maint))))
  mv <- wsei_row(f$flows$rv, "market_value")
  # in T gilt 14,40 (wie RV3), in t = 2 (2028) 10,00: höherer Reinertrag
  expect_equal(mv[4], base[4], tolerance = 1e-9)
  expect_equal(mv[3], base[3] + 4.4 * 700 * 1.02^3 * rv_kf(0.03, 41), tolerance = 1e-6)
  # Stichtagswerte sind skalar deklariert (Validierung statt Laufzeitfehler)
  pr <- reg_get("flow", "residual_value")$params
  expect_identical(pr$income_value$fields$land_value_eur$shapes, "scalar")
  expect_identical(pr$asset_value$fields$land_value_eur$shapes, "scalar")
  expect_identical(pr$market_growth$fields$base_value_eur$shapes, "scalar")
  for (t in c("capex", "replacement", "land", "acquisition_cost")) {
    expect_identical(reg_get("flow", t)$params$active$shapes, "scalar")
  }
})

test_that("Anlage 2: exakte Werte mit Punkten einer Maßnahme und points_decay_years", {
  g <- make_grid("annual", T = 3L)
  sf <- function(s) {
    s$project$project_type <- "sanierung_eh"
    s
  }
  ref <- rv3_build()$flows$rv
  v_ref <- wsei_row(ref, "market_value")[4]
  bw_t <- 200000 * 1.015^3
  tab <- rv_anlage2_table()
  value_for <- function(points) {
    bw_t + (v_ref - bw_t) / rv_kf(0.03, 40) * rv_kf(0.03, rv_rnd_anlage2(59, points, 80, tab))
  }
  comps <- rv3_comps(list(construction_year = 1971L, after = c("rent", "loss", "co2", "cx"),
                          points_before = list(heating = 2),
                          points_measures = list(m1 = list(facade_insulation = 4,
                                                           windows_doors = 2)),
                          income_value = list(remaining_life_method = "anlage2",
                                              remaining_life_years = NULL)))
  comps <- c(list(cx = list(type = "capex", date = "2027-06-01", cost_eur = 1, price_index = 0,
                            asset_id = "b1", measure_id = "m1")), comps)
  mv <- function(x) {
    wsei_row(suppressMessages(wsei_build(x, g, spec_fun = sf))$flows$rv, "market_value")[4]
  }
  # Alter 59 in T; 2 + 6 = 8 Punkte (Wirkung ab Juni 2027)
  expect_equal(mv(comps), value_for(8), tolerance = 1e-9)
  # Punkte zählen nur 2 Jahre: in T (31 Monate nach Wirkungsbeginn) nur noch der Bestand
  comps$rv$income_value$points_decay_years <- 2
  expect_equal(mv(comps), value_for(2), tolerance = 1e-9)
  comps$rv$income_value$points_decay_years <- 3
  expect_equal(mv(comps), value_for(8), tolerance = 1e-9)
})

test_that("exit_yield: NOI <= 0 ergibt 0 mit Hinweis", {
  comps <- rv3_comps(list(method = "exit_yield",
                          exit_yield = list(cap_rate = 0.05, forward_growth = 0,
                                            cost_forward_growth = 0)))
  comps$rent$values <- c(0, 0, 0, 1000)
  cap <- wsei_capture(wsei_build(comps, make_grid("annual", T = 3L)))
  expect_true("types.flow.residual_value.msg.noi_nonpositive" %in% cap$keys)
  expect_equal(wsei_row(cap$value$flows$rv, "market_value")[4], 0)
})

test_that("Hinweis no_useful_life auch bei rv_basis = measures (Methode zero)", {
  g <- make_grid("annual", T = 3L)
  c2 <- list(cx = list(type = "capex", date = "2027-06-01", cost_eur = 1000, price_index = 0,
                       asset_id = "b1", measure_id = "m1"),
             rv = list(type = "residual_value", method = "zero", after = "cx"))
  cap <- wsei_capture(wsei_build(c2, g))
  expect_identical(cap$keys, "types.flow.residual_value.msg.no_useful_life")
  expect_equal(wsei_row(cap$value$flows$rv, "path_measures"), c(0, 970, 970, 970))
  # mit Ersatzkomponente kein Hinweis
  c2$rx <- list(type = "replacement", capex_id = "cx", install_date = "2027-06-01",
                useful_life_years = 20, price_index = 0, asset_id = "b1", measure_id = "m1")
  c2 <- c2[c("cx", "rx", "rv")]
  c2$rv$after <- c("cx", "rx")
  cap2 <- wsei_capture(wsei_build(c2, g))
  expect_length(cap2$keys, 0L)
})

test_that("Baujahr* im Neubau: verschobene Fertigstellung der Hauptmaßnahme bzw. completion", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 10L, construction_months = 24L)
  comps <- list(
    bau = list(type = "capex", date = "2029-01-01", cost_eur = 1, price_index = 0,
               asset_id = "b1", measure_id = "m1", delay_months = 14),
    rv = list(type = "residual_value", method = "zero", after = "bau")
  )
  by <- function(res, i = 1L) {
    sp <- res$spec$components$rv
    rv_build_year(res$ctx, sp, rv_deps(res$ctx, sp))[i]
  }
  res <- suppressMessages(wsei_build(comps, g))
  expect_identical(g$completion_date, as.Date("2029-01-01"))
  expect_equal(by(res), 2030)
  # ohne Hauptmaßnahme: Token completion mit Bauzeitverzug je Lauf (ctx$timing)
  dr <- fake_draws(2L, g, static = list("project.construction_delay_months" = c(0, 12)))
  res2 <- wsei_build(list(rv = list(type = "residual_value", method = "zero")), g, n = 2L,
                     draws = dr)
  expect_equal(c(by(res2, 1L), by(res2, 2L)), c(2029, 2030))
  # fiktives Baujahr gewinnt
  comps$rv$fictitious_construction_year <- 1995L
  expect_equal(by(suppressMessages(wsei_build(comps, g))), 1995)
})

test_that("Batch-Invarianz weiterer Methoden (component, asset_value, market_growth)", {
  g <- make_grid("annual", T = 10L)
  st <- list("components.cx.delay_months" = c(0, 5, 12, 2),
             "components.cx.active" = c(1, 1, 0, 1),
             "components.rx.useful_life_years" = c(20, 15.5, 20, 30))
  dr <- fake_draws(4L, g, static = st)
  for (m in c("component", "asset_value", "market_growth")) {
    comps <- av_comps(list(life_basis = "component"), with_repl = TRUE)
    comps$rv$method <- m
    comps$rv$market_growth <- list(growth = 0.02, uplift_share = 0.05)
    fun <- function(n, draws) {
      suppressMessages(wsei_build(comps, g, n = n, draws = draws, spec_fun = bestand))$flows$rv
    }
    expect_batch_invariance(fun, n = 4L, grid = g, draws = dr)
  }
})

test_that("Bodenwert ohne Angabe in der Untermap: Default-Bezug auf building.land_value_eur", {
  comps <- rv3_comps()
  comps$rv$income_value$land_value_eur <- NULL
  with_land <- function(s) {
    s$building$land_value_eur <- node_const(200000)
    s
  }
  f <- rv3_build(spec_fun = with_land)
  g <- suppressMessages(wsei_build(comps, make_grid("annual", T = 3L), spec_fun = with_land))
  expect_equal(wsei_row(g$flows$rv, "market_value"), wsei_row(f$flows$rv, "market_value"))
  expect_null(rv_param_default("income_value.gibt_es_nicht"))
  expect_null(rv_param_default("existing_value_eur"))
})
