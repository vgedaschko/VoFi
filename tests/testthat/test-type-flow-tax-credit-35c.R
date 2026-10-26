# Tests des Zahlungstyps tax_credit_35c (WS-E2, Spec 01 Teil B 4.8, F-8; Prüfraster annual ab
# 2027-01-01, Perioden 2027–2032).

e2_35c <- function(cost, ..., completion = "2028-06-01", household = list(), domain = list(),
                   tax_cap = FALSE) {
  comp <- utils::modifyList(list(type = "tax_credit_35c", funding_id = "f35", measures = list("m"),
                                 cost_components = list("c_m"), after = list("c_m")),
                            list(...))
  if (tax_cap) comp$income_tax_cap_eur_pa <- list(ref = "household.expected_income_tax_eur_pa")
  e2_type_build(list(c_m = list(type = "capex", measure_id = "m", asset_id = "b1",
                                cost_eur = cost, date = "2028-03-01",
                                completion_date = completion, price_index = 0),
                     t = comp),
                household = household, domain = domain)
}

e2_35c_row <- function(out) as.double(out$t$rows[[1L]]$values[1L, ])

test_that("F-8: Tranchen 7/7/6 % mit Zahlung nach dem Veranlagungsjahr (Perioden 2029–2031)", {
  out <- e2_35c(80000)
  expect_equal(e2_35c_row(out), c(0, 0, 0, 5600, 5600, 4800, 0))
  r <- out$t$rows[[1L]]
  expect_identical(r$key, "credit_m")
  expect_identical(c(r$section, r$category, r$tax_category),
                   c("grants", "tax_credit", "tax_credit"))
  expect_identical(r$measure_id, "m")
  expect_equal(e2_35c_row(e2_35c(250000)), c(0, 0, 0, 14000, 14000, 12000, 0))
  expect_equal(as.double(out$t$aux$tranche_1[1L, ]), c(0, 0, 0, 5600, 0, 0, 0))
  expect_type_contract("tax_credit_35c", "flow")
})

test_that("F-8: Deckel durch die erwartete Einkommensteuer (W), Energieberatung, Vornutzung", {
  expect_warning(out <- e2_35c(80000, tax_cap = TRUE,
                               household = list(expected_income_tax_eur_pa = 4000)),
                 class = "vofi_warning_plausibility")
  expect_equal(e2_35c_row(out), c(0, 0, 0, 4000, 4000, 4000, 0))
  expect_equal(sum(out$t$aux$capped_by_tax[1L, ]), 3)
  # ohne Bindung: Steuer 9.000 (Prüfkit) deckelt nicht
  expect_silent(out <- e2_35c(80000, tax_cap = TRUE))
  expect_equal(e2_35c_row(out), c(0, 0, 0, 5600, 5600, 4800, 0))
  out <- e2_35c(80000, energy_advice_cost_eur = 2000)
  expect_equal(e2_35c_row(out), c(0, 0, 0, 6600, 5600, 4800, 0))
  out <- e2_35c(250000, prior_used_eur = 30000)
  expect_equal(e2_35c_row(out), c(0, 0, 0, 10000, 0, 0, 0))
  out <- e2_35c(250000, prior_used_eur = 45000)
  expect_equal(sum(e2_35c_row(out)), 0)
})

test_that("F-8: Abschluss durch Verzug nach dem 01.01.2030 ergibt 0 (W); Zahlungsverzug", {
  dom <- list(measures = list(m = list(completion_date = "2028-06-01", delay_months = 20)))
  expect_warning(out <- e2_35c(80000, domain = dom), class = "vofi_warning_plausibility")
  expect_equal(sum(e2_35c_row(out)), 0)
  # Verzug 12 Monate ohne Fristüberschreitung: Veranlagungsjahre 2029–2031, Zahlung 2030–2032
  dom$measures$m$delay_months <- 12
  out <- e2_35c(80000, domain = dom)
  expect_equal(e2_35c_row(out), c(0, 0, 0, 0, 5600, 5600, 4800))
  # Zahlungsverzug 0: Zahlung zum 1. Januar des Folgejahres (Periode des Veranlagungsjahres)
  out <- e2_35c(80000, payout_delay_months = 0)
  expect_equal(e2_35c_row(out), c(0, 0, 5600, 5600, 4800, 0, 0))
})

test_that("tax_credit_35c: Aufteilung auf mehrere Maßnahmen, feste Aufwendungen, Zusage je Lauf", {
  comps <- list(
    c_a = list(type = "capex", measure_id = "a", asset_id = "b1", cost_eur = 60000,
               date = "2028-03-01", completion_date = "2028-06-01", price_index = 0),
    c_b = list(type = "capex", measure_id = "b", asset_id = "b1", cost_eur = 20000,
               date = "2028-03-01", completion_date = "2028-05-01", price_index = 0),
    t = list(type = "tax_credit_35c", measures = list("a", "b"),
             cost_components = list("c_a", "c_b"), after = list("c_a", "c_b"),
             approved = list(ref = "funding.f35.approved"))
  )
  dom <- list(funding = list(f35 = list(approved = 1)))
  out <- e2_type_build(comps, domain = dom)
  ra <- as.double(out$t$rows[[1L]]$values[1L, ])
  rb <- as.double(out$t$rows[[2L]]$values[1L, ])
  expect_equal(ra + rb, c(0, 0, 0, 5600, 5600, 4800, 0))
  expect_equal(sum(ra) / sum(ra + rb), 0.75)
  out <- e2_type_build(comps, n = 2L, static = list("funding.f35.approved" = c(1, 0)),
                       domain = dom)
  expect_equal(rowSums(out$t$rows[[1L]]$values + out$t$rows[[2L]]$values), c(16000, 0))
  comps$t$eligible_cost_eur <- 250000
  out <- e2_type_build(comps, domain = dom)
  tot <- out$t$rows[[1L]]$values + out$t$rows[[2L]]$values
  expect_equal(as.double(tot[1L, ]), c(0, 0, 0, 14000, 14000, 12000, 0))
})

test_that("tax_credit_35c: Prüfungen (Perspektive, Gebäudealter, Einkommensteuer)", {
  sc <- list(project = list(perspective = "kleinvermieter",
                            application_date = as.Date("2027-01-01")),
             building = list(construction_year = 2020L), household = list(),
             unit_groups = list(g = list(owner_occupied = FALSE)))
  f <- tax_credit_35c_validate(list(id = "t", measures = "m",
                                    income_tax_cap_eur_pa = node_ref(
                                      "household.expected_income_tax_eur_pa"
                                    )), sc)
  codes <- vapply(f, function(x) x$code, "")
  expect_setequal(codes, paste0("types.flow.tax_credit_35c.msg.",
                                c("not_owner_occupied", "building_too_young",
                                  "income_tax_missing")))
  ok <- list(project = list(perspective = "selbstnutzer", application_date = as.Date("2027-01-01")),
             building = list(construction_year = 1975L),
             household = list(expected_income_tax_eur_pa = 9000))
  expect_length(tax_credit_35c_validate(list(id = "t", measures = "m"), ok), 0L)
  for (k in codes) expect_true(lbl_has(k))
})

test_that("tax_credit_35c: a_m = 0 wie fehlende Maßnahme, auch ohne Energieberatung (R-71)", {
  dom <- list(measures = list(m = list(completion_date = "2028-06-01", active = 1)))
  comps <- list(
    c_m = list(type = "capex", measure_id = "m", asset_id = "b1", cost_eur = 80000,
               date = "2028-03-01", completion_date = "2028-06-01", price_index = 0,
               active = list(ref = "measures.m.active")),
    t = list(type = "tax_credit_35c", funding_id = "f35", measures = list("m"),
             cost_components = list("c_m"), after = list("c_m"),
             energy_advice_cost_eur = 2000)
  )
  out <- e2_type_build(comps, n = 2L, static = list("measures.m.active" = c(1, 0)),
                       domain = dom)
  v <- out$t$rows[[1L]]$values
  expect_equal(as.double(v[1L, ]), c(0, 0, 0, 6600, 5600, 4800, 0))
  expect_equal(sum(v[2L, ]), 0)
  expect_equal(sum(out$c_m$rows[[1L]]$values[2L, ]), 0)
  # Batch-Invarianz: jeder Lauf gleicht dem Einzellauf
  for (i in 1:2) {
    one <- e2_type_build(comps, n = 1L, static = list("measures.m.active" = c(1, 0)[i]),
                         domain = dom)
    expect_equal(one$t$rows[[1L]]$values[1L, ], v[i, ])
  }
  # zwei Maßnahmen: Termin nur aus aktiven Maßnahmen (inaktive späte Maßnahme ohne Wirkung)
  dom2 <- list(measures = list(a = list(completion_date = "2028-06-01", active = 1),
                               b = list(completion_date = "2031-06-01", active = 0)))
  comps2 <- list(
    c_a = list(type = "capex", measure_id = "a", asset_id = "b1", cost_eur = 80000,
               date = "2028-03-01", completion_date = "2028-06-01", price_index = 0,
               active = list(ref = "measures.a.active")),
    c_b = list(type = "capex", measure_id = "b", asset_id = "b1", cost_eur = 20000,
               date = "2031-03-01", completion_date = "2031-06-01", price_index = 0,
               active = list(ref = "measures.b.active")),
    t = list(type = "tax_credit_35c", measures = list("a", "b"),
             cost_components = list("c_a", "c_b"), after = list("c_a", "c_b"))
  )
  r <- e2_capture(e2_type_build(comps2, domain = dom2))
  expect_false("types.flow.tax_credit_35c.msg.completion_late" %in% r$warnings)
  tot <- r$value$t$rows[[1L]]$values + r$value$t$rows[[2L]]$values
  expect_equal(as.double(tot[1L, ]), c(0, 0, 0, 5600, 5600, 4800, 0))
})

test_that("tax_credit_35c: förderfähige Anteile und Erstattung vor dem Stichtag (Hinweis)", {
  out <- e2_35c(80000, eligible_shares = list(m = 0.5))
  expect_equal(e2_35c_row(out), c(0, 0, 0, 2800, 2800, 2400, 0))
  # Fertigstellung 2025: Tranche 1 (Veranlagungsjahr 2025) am 2026-01-01 vor dem Stichtag
  r <- e2_capture(e2_35c(80000, completion = "2025-06-01", payout_delay_months = 0))
  expect_true("types.flow.tax_credit_35c.msg.before_valuation" %in% r$messages)
  expect_equal(e2_35c_row(r$value), c(5600, 4800, 0, 0, 0, 0, 0))
  f <- tax_credit_35c_validate(list(id = "t", measures = "m", eligible_shares = list(x = 0)),
                               list(project = list(perspective = "selbstnutzer")))
  expect_identical(vapply(f, function(x) x$code, ""),
                   "types.flow.tax_credit_35c.msg.share_measure_unknown")
})
