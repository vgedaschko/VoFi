# Tests des Zahlungstyps equity (WS-E-INV; Spec 00 7.12, Spec 01 Teil A 4.12, Prüfwerte E1, X1).

eq_build <- function(..., grid = make_grid("annual", T = 6L), n = 1L, draws = NULL) {
  comps <- list(ek = utils::modifyList(list(type = "equity"), list(...)))
  wsei_build(comps, grid, n = n, draws = draws)$flows$ek
}

test_that("Vertrag und Registrierung", {
  expect_type_contract("equity", "flow")
  expect_identical(reg_get("flow", "equity")$rows, c("in", "out"))
})

test_that("Einmalige Einlage zum Termin (Default Bewertungsstichtag), Zeilenattribute", {
  f <- eq_build(amount_eur = 40000)
  expect_equal(wsei_row(f, "in"), c(40000, rep(0, 6)))
  expect_true(all(wsei_row(f, "out") == 0))
  r <- f$rows
  expect_identical(c(r[[1]]$section, r[[1]]$category), c("equity", "equity_in"))
  expect_identical(c(r[[2]]$section, r[[2]]$category), c("equity", "equity_out"))
  expect_identical(c(r[[1]]$tax_category, r[[2]]$tax_category), c("equity", "equity"))
  f2 <- eq_build(amount_eur = 40000, date = "2028-07-01")
  expect_equal(which(wsei_row(f2, "in") != 0) - 1L, 2L)
  f3 <- eq_build(amount_eur = 40000, date = "completion",
                 grid = make_grid("mixed", T = 6L))
  expect_equal(sum(wsei_row(f3, "in")), 40000)
})

test_that("E1: laufende Einlage 6.000 p. a. ohne Fortschreibung, start_event bis to", {
  f <- eq_build(contributions_pa = 6000, start_event = "2027-01-01", to = "2030-01-01")
  expect_equal(wsei_row(f, "in"), c(0, 6000, 6000, 6000, 0, 0, 0))
  g4 <- make_grid("mixed", T = 6L)
  f4 <- eq_build(contributions_pa = 6000, start_event = "2027-01-01", to = "2030-01-01",
                 grid = g4)
  v <- wsei_row(f4, "in")
  expect_equal(v[2:10], rep(500, 9))
  expect_equal(v[11], 1500)
  expect_equal(v[12:13], c(6000, 6000))
  expect_true(all(v[-(2:13)] == 0))
  expect_equal(sum(v[g4$year == 2027]), 6000)
  expect_equal(sum(wsei_row(f, "in")[make_grid("annual", T = 6L)$year == 2027]), 6000)
})

test_that("Entnahmen p. a. und Zahlungspläne (Beträge >= 0, Vorzeichen durch den Typ)", {
  f <- eq_build(withdrawals_pa = 600, contributions = list(schedule = list("2028-07-01" = 5000)),
                withdrawals = list(schedule = list("2030-01-01" = 2000)),
                start_event = "2027-01-01")
  # Termin 2030-01-01 = Periodenende von t = 3 (Konvention grid_period_of)
  expect_equal(wsei_row(f, "out"), c(0, -600, -600, -2600, -600, -600, -600))
  expect_equal(wsei_row(f, "in"), c(0, 0, 5000, 0, 0, 0, 0))
  # start_event completion (R-110): Beginn mit der Fertigstellung des Rasters
  g4 <- make_grid("mixed", T = 6L)
  fc <- eq_build(withdrawals_pa = 1200, start_event = "completion", grid = g4)
  v <- wsei_row(fc, "out")
  expect_true(all(v[g4$date_end <= g4$completion_date] == 0))
  expect_equal(sum(v[g4$year == 2027]), -300)
})

test_that("Negative Laufwerte werden begrenzt und gemeldet", {
  g <- make_grid("annual", T = 3L)
  dr <- fake_draws(3L, g, static = list("financing.ek.amount_eur" = c(1000, -5, 2000)))
  cap <- wsei_capture(eq_build(amount_eur = 1000, grid = g, n = 3L, draws = dr))
  expect_identical(cap$keys, "types.flow.equity.msg.negative_clamped")
  expect_equal(cap$value$rows[[1]]$values[, 1], c(1000, 0, 2000))
})

test_that("Einlage jenseits des Horizonts entfällt mit Hinweis", {
  cap <- wsei_capture(eq_build(amount_eur = 1000, date = "2040-01-01", grid = make_grid(T = 3L)))
  expect_identical(cap$keys, "types.flow.equity.msg.after_horizon")
  expect_true(all(wsei_row(cap$value, "in") == 0))
})

test_that("validate(): negative Beträge, Zeitraum, doppelte Sacheinlage", {
  f <- wsei_findings("equity", amount_eur = 1, contributions_pa = -1,
                     withdrawals = list(schedule = list("2028-01-01" = -5)),
                     start_event = "2030-01-01", to = "2029-01-01", id = "ek")
  expect_true(all(c("financing.negative", "financing.start_after_to") %in% names(f)))
  expect_true(all(f[names(f) == "financing.negative"] == "error"))
  d <- wsei_findings("equity", amount_eur = list(ref = "building.existing_value_eur"), id = "ek")
  expect_identical(unname(d["financing.in_kind_double"]), "warning")
  expect_length(wsei_findings("equity", amount_eur = 1000, id = "ek"), 0L)
  # amount_eur: auto ist nur bei Krediten zulässig (Spec 00 8.7)
  expect_error(make_component("equity", amount_eur = "auto", id = "ek"),
               class = "vofi_error_input")
})

test_that("X1: Sacheinlage des Bestandswerts mit Bestandsdarlehen (Engine, R-68)", {
  sc <- vofi_scenario(list(
    schema_version = 1L, meta = list(scenario_id = "x1", title = "X1"),
    project = list(perspective = "kleinvermieter", project_type = "sanierung_eh",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 2L),
    building = list(existing_value_eur = 2000000),
    residual_value = list(sale_cost_share = 0.03),
    components = list(z = list(type = "custom_series", label = "Zahlungsfolge",
                               values = c(-10000, 50000, 50000))),
    financing = list(
      ek = list(type = "equity", amount_eur = 10000),
      alt = list(type = "annuity_loan", amount_eur = 400000, rate_pa = 0.03,
                 term_years = 20, existing = TRUE, payments_per_year = 1L)
    ),
    accounts = list(deposit_rate_pa = 0, overdraft_rate_pa = 0, overdraft_limit_eur = Inf,
                    surplus_order = c("od_repay", "dep_invest"),
                    deficit_order = c("dep_withdraw", "od_draw", "equity_call")),
    analysis = list(kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value"))
  ))
  res <- vofi_run(vofi_build(sc))
  expect_equal(res$ledger$values$equity_in_kind[1, 1], 1600000)
  expect_true(all(res$ledger$values$equity_in_kind[1, -1] == 0))
  expect_equal(res$opportunity$ledger$values$opp_in_kind_sale[1, 1], 1540000)
  # die equity-Komponente selbst bucht nur die Bareinlage
  expect_equal(sum(res$ledger$values[["ek__in"]]), 10000)
})

test_that("Batch-Invarianz", {
  g4 <- make_grid("mixed", T = 6L)
  st <- list(
    "financing.ek.amount_eur" = c(1e5, 2e5, 0, 5e4),
    "financing.ek.withdrawals_pa" = c(0, 1200, 600, 2400),
    "financing.ek.date_shift_months" = c(0, 2, 5, 11)
  )
  dr <- fake_draws(4L, g4, static = st)
  comps <- list(ek = list(type = "equity", amount_eur = 1e5, withdrawals_pa = 1200,
                          contributions_pa = 300, start_event = "2027-04-01",
                          to = "2031-01-01", date = "2027-02-01"))
  fun <- function(n, draws) wsei_build(comps, g4, n = n, draws = draws)$flows$ek
  expect_batch_invariance(fun, n = 4L, grid = g4, draws = dr)
})
