# Tests des Zahlungstyps grant (WS-E2, Spec 01 Teil B 4.5, 4.12; Prüfraster annual ab 2027-01-01).

e2_capex <- function(m, cost, date = "2027-03-01", completion = "2027-10-01", ...) {
  utils::modifyList(list(type = "capex", measure_id = m, asset_id = "b1", cost_eur = cost,
                         date = date, completion_date = completion, price_index = 0),
                    list(...))
}

e2_grant_comp <- function(ms, ...) {
  utils::modifyList(list(type = "grant", funding_id = "f1", measures = as.list(ms),
                         cost_components = as.list(paste0("c_", ms)),
                         after = as.list(paste0("c_", ms))),
                    list(...))
}

test_that("grant: Vertragsbeispiel +24.000 in t = 0 (Teil B 4.5)", {
  def <- reg_get("flow", "grant")
  out <- e2_type_build(list(g = def$example))
  v <- out$g$rows[[1L]]
  expect_identical(v$key, "grant_m1")
  expect_equal(as.double(v$values[1L, ]), c(24000, 0, 0, 0, 0, 0, 0))
  expect_identical(v$section, "grants")
  expect_identical(v$category, "grant")
  expect_identical(v$tax_category, "subsidy_investment")
  expect_identical(v$measure_id, "m1")
  expect_equal(v$vat_rate, 0)
  expect_equal(as.double(out$g$aux$capped_cost[1L, 1L]), 80000)
  expect_equal(as.double(out$g$aux$eligible_cost[1L, 1L]), 100000)
  expect_equal(as.double(out$g$aux$rate_effective[1L, 1L]), 0.3)
  expect_type_contract("grant", "flow")
})

test_that("F-1/F-16: KfW 459, Deckel 151.000, Auszahlung Fertigstellung + 3 Monate (+ Verzug)", {
  comps <- list(c_wp = e2_capex("wp", 153560),
                g = e2_grant_comp("wp", rate = 0.3, rate_cap = 0.3, cost_cap_eur = 151000,
                                  payout_lag_months = 3L))
  out <- e2_type_build(comps)
  expect_equal(as.double(out$g$rows[[1L]]$values[1L, ]), c(0, 45300, 0, 0, 0, 0, 0))
  for (d in c(9, 12)) {
    comps$g$payout_delay_months <- d
    out <- e2_type_build(comps)
    expect_equal(as.double(out$g$rows[[1L]]$values[1L, ]), c(0, 0, 45300, 0, 0, 0, 0))
  }
})

test_that("F-6: BAFA Hülle mit iSFP-Bonus über der Schwelle bzw. auf die ganzen Kosten", {
  base <- e2_grant_comp("h", rate = 0.15, bonus_rate = 0.05, bonus_threshold_eur = 30000,
                        cost_cap_eur = 60000, payout_event = "commitment",
                        application_date = "2027-01-01")
  run <- function(cost, ...) {
    out <- e2_type_build(list(c_h = e2_capex("h", cost), g = utils::modifyList(base, list(...))))
    sum(out$g$rows[[1L]]$values)
  }
  expect_equal(run(85988.87), 10500)
  expect_equal(run(85988.87, bonus_mode = "whole_amount"), 12000)
  expect_equal(run(55405.82), 9581.164, tolerance = 1e-9)
  expect_equal(run(55405.82, bonus_mode = "whole_amount"), 11081.164, tolerance = 1e-9)
  expect_equal(run(40000), 6500)
  # ohne iSFP: Deckel 30.000, kein Bonus
  expect_equal(run(85988.87, bonus_rate = 0, cost_cap_eur = 30000), 4500)
})

test_that("F-6a: Jahresdeckel je Kalenderjahr der Fertigstellung (cap_period calendar_year)", {
  g <- e2_grant_comp(c("fassade", "fenster"), rate = 0.15, bonus_rate = 0.05,
                     bonus_threshold_eur = 30000, cost_cap_eur = 60000,
                     cap_period = "calendar_year", payout_event = "commitment",
                     application_date = "2027-01-01")
  same <- e2_type_build(list(
    c_fassade = e2_capex("fassade", 40000, "2028-03-01", "2028-09-01"),
    c_fenster = e2_capex("fenster", 30000, "2028-03-01", "2028-09-01"), g = g
  ))
  vals <- vapply(same$g$rows, function(r) sum(r$values), double(1))
  expect_equal(unname(vals), c(6000, 4500))
  split <- e2_type_build(list(
    c_fassade = e2_capex("fassade", 40000, "2028-03-01", "2028-09-01"),
    c_fenster = e2_capex("fenster", 30000, "2029-03-01", "2029-09-01"), g = g
  ))
  vals <- vapply(split$g$rows, function(r) sum(r$values), double(1))
  expect_equal(unname(vals), c(6500, 4500))
  # gemeinsame Gruppe ohne Jahresdeckel: 70.000 -> 60.000 -> 10.500
  g$cap_period <- "total"
  tot <- e2_type_build(list(
    c_fassade = e2_capex("fassade", 40000, "2028-03-01", "2028-09-01"),
    c_fenster = e2_capex("fenster", 30000, "2029-03-01", "2029-09-01"), g = g
  ))
  expect_equal(sum(vapply(tot$g$rows, function(r) sum(r$values), double(1))), 10500)
})

test_that("grant: fester Betrag, förderfähige Anteile, Kosten 0, Termin nach dem Horizont", {
  dom <- list(funding = list(f1 = list(eligible_shares = list(a = 0.5))))
  out <- e2_type_build(list(c_a = e2_capex("a", 100000), c_b = e2_capex("b", 100000),
                            g = e2_grant_comp(c("a", "b"), rate = 0.2, payout_event = "commitment",
                                              application_date = "2027-01-01")),
                       domain = dom)
  vals <- vapply(out$g$rows, function(r) sum(r$values), double(1))
  expect_equal(unname(vals), c(10000, 20000))
  # fester Zuschussbetrag nach Basisfallkosten verteilt
  out <- e2_type_build(list(c_a = e2_capex("a", 30000), c_b = e2_capex("b", 10000),
                            g = e2_grant_comp(c("a", "b"), rate = 0.2, amount_eur = 8000,
                                              payout_event = "commitment",
                                              application_date = "2027-01-01")))
  vals <- vapply(out$g$rows, function(r) sum(r$values), double(1))
  expect_equal(unname(vals), c(6000, 2000))
  # Kosten 0: kein Zuschuss
  out <- e2_type_build(list(c_a = e2_capex("a", 0),
                            g = e2_grant_comp("a", rate = 0.3, payout_event = "commitment",
                                              application_date = "2027-01-01")))
  expect_equal(sum(out$g$rows[[1L]]$values), 0)
  # Termin nach dem Horizont: nicht gebucht, Hinweis
  expect_message(
    out <- e2_type_build(list(c_a = e2_capex("a", 10000, "2032-03-01", "2032-10-01"),
                              g = e2_grant_comp("a", rate = 0.3, payout_lag_months = 6L))),
    class = "vofi_message"
  )
  expect_equal(sum(out$g$rows[[1L]]$values), 0)
})

test_that("grant: Zusage je Lauf und Batch-Invarianz (Spec 00 15.5)", {
  comps <- list(c_wp = e2_capex("wp", 100000),
                g = e2_grant_comp("wp", rate = 0.3, approved = list(ref = "funding.f1.approved"),
                                  payout_event = "commitment", application_date = "2027-01-01"))
  dom <- list(funding = list(f1 = list(approved = 1)))
  out <- e2_type_build(comps, n = 2L, static = list("funding.f1.approved" = c(1, 0)),
                       domain = dom)
  v <- out$g$rows[[1L]]$values
  expect_equal(rowSums(v), c(30000, 0))
  # Kostenfaktor je Lauf: Zuschuss folgt den realisierten Kosten bis zum Deckel
  comps$g$cost_cap_eur <- 110000
  comps$c_wp$cost_factor <- list(ref = "measures.wp.cost_factor")
  dom$measures <- list(wp = list(cost_factor = 1))
  batch <- e2_type_build(comps, n = 3L,
                         static = list("measures.wp.cost_factor" = c(0.8, 1, 1.2)), domain = dom)
  expect_equal(rowSums(batch$g$rows[[1L]]$values), c(24000, 30000, 33000))
  for (i in 1:3) {
    one <- e2_type_build(comps, n = 1L,
                         static = list("measures.wp.cost_factor" = c(0.8, 1, 1.2)[i]),
                         domain = dom)
    expect_equal(one$g$rows[[1L]]$values[1L, ], batch$g$rows[[1L]]$values[i, ])
  }
})

test_that("grant: Prüfungen ohne Maßnahmen bzw. Kostenkomponente außerhalb von after", {
  sc <- list(components = list())
  f <- grant_validate(list(id = "g", type = "grant", measures = list(), cost_components = "c",
                           after = character(0)), sc)
  keys <- vapply(f, function(x) x$code, "")
  expect_setequal(keys, c("types.flow.grant.msg.no_measures",
                          "types.flow.grant.msg.cost_not_after"))
  expect_length(grant_validate(list(id = "g", measures = "a", cost_components = "c",
                                    after = "c"), sc), 0L)
})
