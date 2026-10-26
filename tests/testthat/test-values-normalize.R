# Tests für R/values-normalize.R (WS-A; Spec 00 Abschnitte 4.5, 4.6, 5.4). Phase-0-Minimalfassung.

test_that("Wertformen werden Knoten (idempotent, numerische Bl\u00e4tter double)", {
  expect_identical(node_normalize(5L), node_const(5))
  expect_identical(node_normalize(c(1, 2, 3))$kind, "series_t")
  expect_identical(node_normalize(list(ref = "market.inflation")), node_ref("market.inflation"))
  r <- node_normalize(list(ref = "market.mortgage_rate", anchor = 0.025, offset = -0.01))
  expect_identical(r$anchor, 0.025)
  expect_identical(r$offset, -0.01)
  sy <- node_normalize(list(series = list("2028" = 0.022, "2027" = 0.028), fill = "zero"))
  expect_identical(sy$kind, "series_year")
  expect_identical(sy$years, c(2027L, 2028L))
  expect_identical(sy$values, c(0.028, 0.022))
  expect_identical(sy$fill, "zero")
  expect_identical(sy$before, "first")
  pt <- node_normalize(list(years = c(2026, 2030), values = list(60, list(ref = "shared.c"))))
  expect_identical(pt$kind, "points")
  expect_identical(pt$values[[2]]$kind, "ref")
  sch <- node_normalize(list(schedule = list("2027-07-01" = 100, "2030" = 50)))
  expect_identical(sch$dates, as.Date(c("2027-07-01", "2030-01-01")))
  expect_identical(sch$amounts, c(100, 50))
  gr <- node_normalize(list(start = 7.2, growth = list(ref = "market.rent_growth")))
  expect_identical(gr$start, node_const(7.2))
  expect_identical(gr$growth$kind, "ref")
  expect_identical(gr$index, "calendar_year")
  gp <- node_normalize(list(start = 280000, growth = 0.02, index = "period_end"))
  expect_identical(gp$index, "period_end")
  expect_identical(gp, node_normalize(gp))
  expect_error(node_normalize(list(start = 1, growth = 0.02, index = "monthly"), path = "x.y"),
               class = "vofi_error_input")
  expect_identical(node_normalize(list(expr = "shared.a * 2")), node_expr("shared.a * 2"))
  ex <- node_normalize(list(expr = "building.living_area_m2 * 150"))
  expect_identical(ex$kind, "expr")
  expect_identical(expr_symbols(ex$ast), "building.living_area_m2")
  q <- node_normalize(list(value = 14, per = "m2_living_area"))
  expect_identical(q$kind, "quantity")
  d <- node_normalize(list(dist = "pert", min = 1, mode = 2, max = 4, base = 2))
  expect_identical(d$kind, "dist")
  expect_identical(node_normalize(d), d)
  expect_identical(node_normalize(gr), gr)
  expect_error(node_normalize(list(foo = 1)), class = "vofi_error_input")
  expect_error(node_normalize("auto"), class = "vofi_error_input")
  p <- vofi_param("amount", allow_auto = TRUE)
  expect_identical(node_normalize("topup", p), list(kind = "auto", mode = "topup"))
})

test_that("Raten > 1 sind Fehler, EUR-Jahresbetr\u00e4ge nicht", {
  expect_error(node_normalize(3.9, vofi_param("rate"), "financing.b.rate_pa"),
               class = "vofi_error_input")
  expect_error(node_normalize(3.9, NULL, "accounts.deposit_rate_pa"), class = "vofi_error_input")
  expect_identical(node_normalize(1200, vofi_param("value", unit = "EUR"),
                                  "financing.ek.contributions_pa"), node_const(1200))
  expect_identical(node_normalize(801, NULL, "accounts.deposit_tax_allowance_eur_pa"),
                   node_const(801))
})

test_that("Nicht-numerische Arten (5.4)", {
  expect_identical(node_normalize(12, vofi_param("integer")), 12L)
  expect_error(node_normalize(1.5, vofi_param("integer"), "x"), class = "vofi_error_input")
  expect_identical(node_normalize("ja", vofi_param("logical")), TRUE)
  expect_identical(node_normalize("no", vofi_param("logical")), FALSE)
  expect_error(node_normalize("vielleicht", vofi_param("logical"), "x"),
               class = "vofi_error_input")
  expect_identical(node_normalize("2027-01-01", vofi_param("date")), as.Date("2027-01-01"))
  expect_identical(node_normalize(2030, vofi_param("timing")), as.Date("2030-01-01"))
  expect_identical(node_normalize("completion", vofi_param("timing")), "completion")
  expect_identical(node_normalize(list(year = 2031), vofi_param("timing")),
                   as.Date("2031-01-01"))
  expect_error(node_normalize("bald", vofi_param("timing"), "x"), class = "vofi_error_input")
  expect_identical(node_normalize(list("a", "b"), vofi_param("ids")), c("a", "b"))
  expect_warning(e <- node_normalize("term_reduction",
                                     vofi_param("enum", values = "vocab:repayment_grant_effect")),
                 class = "vofi_warning_input")
  expect_identical(e, "shorten_term")
  m <- node_normalize(list(processing_fee_share = 0.01, extra = 1),
                      vofi_param("map", fields = list(processing_fee_share = vofi_param("share"))))
  expect_identical(m$processing_fee_share, node_const(0.01))
  expect_identical(m$extra, 1)
})

test_that("Wachstumsraten > 1 sind ein Eingabefehler (4.6): Wachstumsform und recurring.growth", {
  expect_error(node_normalize(list(start = 100, growth = 2), NULL, "market.x"),
               class = "vofi_error_input")
  ok <- node_normalize(list(start = 100, growth = 0.02, index = "period_end"), NULL, "market.x")
  expect_identical(ok$index, "period_end")
  expect_error(node_normalize(list(start = 1, growth = 0.02, index = "ende"), NULL, "m.x"),
               class = "vofi_error_input")
  def <- reg_get("flow", "recurring")
  expect_error(node_normalize(2, def$params$growth, "components.r.growth"),
               class = "vofi_error_input")
  expect_identical(node_normalize(list(ref = "market.rent_growth"), def$params$growth,
                                  "components.r.growth")$kind, "ref")
  expect_true("path" %in% def$params$growth$shapes)
})
