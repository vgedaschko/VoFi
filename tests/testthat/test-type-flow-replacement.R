# Tests des Zahlungstyps replacement (WS-E-INV; Spec 01 Teil A 4.10, Prüfwerte R1-R6).

repl_comps <- function(life = 18, ...) {
  list(
    cx = list(type = "capex", date = "2027-10-01", cost_eur = 126000, price_index = 0.03,
              price_base_year = 2026L, asset_id = "b1", measure_id = "m1"),
    rp = c(list(type = "replacement", capex_id = "cx", install_date = "2027-10-01",
                useful_life_years = life, price_index = 0.03, price_base_year = 2026L,
                asset_id = "b1", measure_id = "m1"), list(...))
  )
}

element_comp <- function(...) {
  list(el = c(list(type = "replacement", include_initial = FALSE, install_date = "1998-01-01",
                   useful_life_years = 18, cost_eur = 95000, price_index = 0.03,
                   price_base_year = 2026L, asset_id = "b1", measure_id = "m1"), list(...)))
}

test_that("Vertrag und Registrierung", {
  expect_type_contract("replacement", "flow")
  expect_identical(reg_get("flow", "replacement")$rows, "cost")
})

test_that("R1: Wärmepumpe mit Erstinvestition, Ersatz nach 18 Jahren, Zeitwertpfad", {
  g <- make_grid("annual", T = 30L)
  res <- wsei_build(repl_comps(), g)
  expect_equal(round(sum(res$flows$cx$aux$cost_total), 2), 129780)
  f <- res$flows$rp
  v <- wsei_row(f, "cost")
  expect_equal(which(v != 0) - 1L, 19L)
  expect_equal(round(v[20], 2), -220941.76)
  expect_equal(v[20], -126000 * 1.03^19, tolerance = 1e-12)
  val <- f$aux$value[1, ]
  expect_equal(round(val[c(1, 2, 19, 20, 31)], 2), c(0, 127977.50, 8937.77, 217873.13, 114688.15))
  expect_equal(val[31], 126000 * 1.03^30 * 0.375, tolerance = 1e-12)
  expect_equal(round(f$aux$value_nominal[1, 31], 2), 82853.16)
  expect_equal(f$aux$age_years[1, 31], 11.25)
  expect_equal(f$aux$life_months[1, 1], 216)
  expect_identical(f$rows[[1]]$tax_category, "capex_expensable")
  expect_true(f$meta$include_initial)
  expect_identical(f$meta$capex_id, "cx")
  expect_vofi_flows_contract(f, res$ctx, reg_get("flow", "replacement"))
})

test_that("R2: stochastische Nutzungsdauer 15,5 Jahre (Lauf 2)", {
  g <- make_grid("annual", T = 30L)
  dr <- fake_draws(2L, g, static = list("components.rp.useful_life_years" = c(18, 15.5)))
  res <- wsei_build(repl_comps(), g, n = 2L, draws = dr)
  v <- res$flows$rp$rows[[1]]$values
  expect_equal(which(v[2, ] != 0) - 1L, 17L)
  expect_equal(round(v[2, 18], 2), -208258.80)
  expect_equal(round(res$flows$rp$aux$value[2, 31], 2), 34529.77)
  expect_equal(res$flows$rp$aux$age_years[2, 31], 13.75)
  expect_equal(round(v[1, 20], 2), -220941.76)
})

test_that("R3: überfälliges Bestandsbauteil (first_period), Folgeersatz 2046", {
  g <- make_grid("annual", T = 30L)
  f <- wsei_build(element_comp(), g)$flows$el
  v <- wsei_row(f, "cost")
  expect_equal(which(v != 0) - 1L, c(1L, 19L))
  expect_equal(round(v[c(2, 20)], 2), c(-97850.00, -166583.08))
  expect_false(f$meta$include_initial)
  # valuation: Ersatz zum Stichtag (t = 0), skip: erster Termin nach dem Stichtag
  fv <- wsei_build(element_comp(overdue = "valuation"), g)$flows$el
  vv <- wsei_row(fv, "cost")
  expect_equal(which(vv != 0) - 1L, c(0L, 18L))
  expect_equal(vv[1], -95000)
  fs <- wsei_build(element_comp(overdue = "skip"), g)$flows$el
  vs <- wsei_row(fs, "cost")
  # 1998 + 18 + 18 = 2034-01-01 -> t = 7, danach 2052-01-01 -> t = 25
  expect_equal(which(vs != 0) - 1L, c(7L, 25L))
  expect_equal(vs[8], -95000 * 1.03^7, tolerance = 1e-12)
  # Wertpfad des Bauteils: Wiederbeschaffungswert ab Einbau (abgeschrieben)
  expect_equal(f$aux$value[1, 1], 0)
  expect_equal(f$aux$value[1, 2], 97850 * (1 - 0 / 216))
})

test_that("R4/R5: Zyklusende durch eine ersetzende Maßnahme; Aktivierung 0 hebt das Ende auf", {
  g <- make_grid("annual", T = 30L)
  f4 <- wsei_build(element_comp(until_date = "2027-10-01"), g)$flows$el
  expect_true(all(wsei_row(f4, "cost") == 0))
  expect_true(all(f4$aux$value[1, -1] == 0))
  f5 <- wsei_build(element_comp(until_date = "2027-10-01", until_shift_months = 1200), g)$flows$el
  expect_equal(which(wsei_row(f5, "cost") != 0) - 1L, c(1L, 19L))
})

test_that("R6: Batch-Invarianz mit Läufen L = 15,5 und 18 Jahre", {
  g <- make_grid("annual", T = 30L)
  st <- list(
    "components.rp.useful_life_years" = c(15.5, 18, 18, 15.5),
    "components.rp.install_shift_months" = c(0, 0, 7, 3)
  )
  dr <- fake_draws(4L, g, static = st)
  fun <- function(n, draws) wsei_build(repl_comps(), g, n = n, draws = draws)$flows$rp
  expect_batch_invariance(fun, n = 4L, grid = g, draws = dr)
  res <- wsei_build(repl_comps(), g, n = 4L, draws = dr)
  expect_equal(which(res$flows$rp$rows[[1]]$values[3, ] != 0) - 1L, 20L)  # 2046-05-01
})

test_that("enabled = FALSE: nur Zeitwertpfad der Erstinvestition", {
  g <- make_grid("annual", T = 30L)
  f <- wsei_build(repl_comps(enabled = FALSE), g)$flows$rp
  expect_true(all(wsei_row(f, "cost") == 0))
  expect_equal(round(f$aux$value[1, 2], 2), 127977.50)
  expect_true(all(f$aux$value[1, 20:31] == 0))
  expect_false(f$meta$enabled)
})

test_that("Kosten: ausdrücklich bzw. aus der Erstinvestition mit Faktor; Aktivierung", {
  g <- make_grid("annual", T = 30L)
  f <- wsei_build(repl_comps(cost_factor = 1.2), g)$flows$rp
  expect_equal(wsei_row(f, "cost")[20], -126000 * 1.2 * 1.03^19, tolerance = 1e-12)
  f2 <- wsei_build(repl_comps(cost_eur = 50000, active = 0), g)$flows$rp
  expect_true(all(wsei_row(f2, "cost") == 0))
  cx0 <- repl_comps()
  cx0$cx$active <- 0
  f3 <- wsei_build(cx0, g)$flows$rp
  expect_true(all(wsei_row(f3, "cost") == 0))
  expect_true(all(f3$aux$value == 0))
  f4 <- wsei_build(repl_comps(first_date = "2030-01-01", first_shift_months = 6), g)$flows$rp
  expect_equal(which(wsei_row(f4, "cost") != 0) - 1L, c(4L, 22L))
})

test_that("Fehlende Erstinvestition bzw. Kosten sind Vertragsfehler", {
  g <- make_grid("annual", T = 10L)
  bad <- list(rp = list(type = "replacement", install_date = "2027-10-01",
                        useful_life_years = 18, asset_id = "b1", measure_id = "m1"))
  expect_error(wsei_build(bad, g), class = "vofi_error_contract")
  bad2 <- list(rp = list(type = "replacement", include_initial = FALSE,
                         install_date = "2000-01-01", useful_life_years = 18, asset_id = "b1",
                         measure_id = "m1"))
  expect_error(wsei_build(bad2, g), class = "vofi_error_contract")
})

test_that("validate(): Befunde nach Spec 01 Teil A 4.10.2", {
  f <- wsei_findings("replacement", install_date = "2027-10-01", useful_life_years = 3,
                     first_date = "2027-01-01", asset_id = "b1", measure_id = "m1")
  expect_true(all(c("life_short", "first_before_install", "no_capex") %in% names(f)))
  f <- wsei_findings("replacement", install_date = "2027-10-01", useful_life_years = 0,
                     include_initial = FALSE)
  expect_true(all(c("life_nonpositive", "element_cost_missing") %in% names(f)))
  f <- wsei_findings("replacement", install_date = "2027-01-01", useful_life_years = 0.5,
                     cost_eur = 1, include_initial = FALSE,
                     scenario = make_spec(make_grid("annual", T = 30L)))
  expect_identical(unname(f["many_events"]), "warning")
  comp <- make_component("replacement", install_date = "2027-10-01", useful_life_years = 10,
                         capex_id = "cx")
  comp$first_shift_months <- node_const(-1)
  out <- replacement_validate(comp, make_spec())
  expect_true(any(grepl("shift_negative", vapply(out, function(x) x$code, ""))))
})
