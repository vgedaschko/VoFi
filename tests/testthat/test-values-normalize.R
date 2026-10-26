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

test_that("Wachstumsform: Raten > 1 zulässig (stress_2022), <= -1 nicht; recurring.growth > 1", {
  g2 <- node_normalize(list(start = 100, growth = 1.04), NULL, "market.x")
  expect_identical(g2$growth, node_const(1.04))
  gs <- node_normalize(list(start = 0.06335, growth = list(series = list("2027" = 1.04,
                                                                         "2028" = -0.235))),
                       NULL, "market.energy_price.gas")
  expect_identical(gs$growth$kind, "series_year")
  e <- expect_error(node_normalize(list(start = 100, growth = -1), NULL, "market.x"),
                    class = "vofi_error_input")
  expect_identical(e$key, "io.growth_rate_invalid")
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

test_that("Kanonische Marktraten > 1 sind ein Eingabefehler (4.3.11, 4.6)", {
  sc <- unclass(vofi_read_scenario(vofi_example("skeleton")))
  x <- sc[intersect(names(sc), utl_scenario_blocks())]
  x$schema_version <- 1L
  x$market <- list(inflation = 2)
  expect_error(vofi_scenario(x), class = "vofi_error_input")
  x$market <- list(rent_growth = list(series = list("2027" = 0.02, "2030" = 3)))
  expect_error(vofi_scenario(x), class = "vofi_error_input")
  x$market <- list(inflation = 0.02, co2_price = 55)
  expect_s3_class(vofi_scenario(x), "vofi_scenario")
})

test_that("Mengenbezug: Wert jeder skalaren oder zeitabhängigen Form (Teil A 3.5, Q1, Q6)", {
  q1 <- node_normalize(list(value = 14.40, per = "m2_living_area"), NULL,
                       "building.maintenance.rate_eur_m2_pa")
  expect_identical(q1, list(kind = "quantity", value = 14.4, per = "m2_living_area"))
  q6 <- node_normalize(list(value = list(series = list("2027" = 10, "2043" = 14.4),
                                         fill = "locf"), per = "m2_living_area"))
  expect_identical(q6$value$kind, "series_year")
  expect_identical(q6$value$values, c(10, 14.4))
  expect_identical(node_normalize(q6), q6)
  qr <- node_normalize(list(value = list(ref = "shared.satz"), per = "unit"))
  expect_identical(qr$value$kind, "ref")
  e <- expect_error(node_normalize(list(value = list(value = 1, per = "unit"), per = "unit"),
                                   NULL, "x.q"), class = "vofi_error_input")
  expect_identical(e$key, "io.element_not_scalar")
  expect_error(node_normalize(list(value = list(dist = "pert", min = 1, mode = 2, max = 3),
                                   per = "unit"), NULL, "x.q"), class = "vofi_error_input")
})

test_that("Zahlungsplan: Beträge als Zahl, ref, expr oder Mengenbezug; Verteilung ist ein Fehler", {
  s <- node_normalize(list(schedule = list("2027-07-01" = 100000,
                                           "2028-07-01" = list(ref = "shared.rate2"),
                                           "2029" = list(value = 248, per = "m2_component:facade")),
                           unit = "eur"), NULL, "measures.m.payment_schedule")
  expect_identical(s$kind, "schedule")
  expect_identical(s$unit, "eur")
  expect_identical(vapply(s$amounts, function(a) a$kind, ""), c("const", "ref", "quantity"))
  expect_identical(node_normalize(s), s)
  e <- expect_error(node_normalize(list(schedule = list("2027" = list(dist = "pert", min = 1,
                                                                      mode = 2, max = 3))),
                                   NULL, "measures.m.payment_schedule"),
                    class = "vofi_error_validation")
  expect_identical(e$key, "io.schedule_amount_form")
  expect_error(node_normalize(list(schedule = list("2027" = list(value = 1, per = "unit"))),
                              NULL, "components.x.draw_schedule"), NA)
  e2 <- expect_error(node_normalize(list(years = c(2026, 2030),
                                         values = list(1, list(value = 1, per = "unit")))),
                     class = "vofi_error_input")
  expect_identical(e2$key, "io.element_not_scalar")
})

test_that("Knotenkonstruktoren für bctx (6.4, R-91)", {
  expect_identical(node_const(2L), list(kind = "const", value = 2))
  r <- node_ref("market.inflation", scale = 2)
  expect_identical(r$scale, 2)
  expect_null(r$anchor)
  sch <- node_schedule(as.Date(c("2027-01-01", "2028-01-01")), c(0.5, 0.5))
  expect_identical(sch$kind, "schedule")
  g <- node_growth(100, 0.02, base_date = as.Date("2027-01-01"), index = "period_end")
  expect_identical(g$start, node_const(100))
  expect_identical(g$growth, node_const(0.02))
  expect_identical(g$index, "period_end")
  ex <- node_expr("unit_groups.a.n_units + unit_groups.b.n_units")
  expect_s3_class(ex$ast, "vofi_expr")
  expect_identical(sort(expr_symbols(ex$ast)),
                   c("unit_groups.a.n_units", "unit_groups.b.n_units"))
})

test_that("Platzhalter {id} in Vorlagen (4.7 Nr. 3, R-118)", {
  tpl <- list(price_eur_kwh = list(ref = "market.energy_price.{id}"),
              x = list(expr = "measures.{id}.cost_eur * 2"), label = "{id} bleibt",
              n = list(sub = node_ref("measures.{id}.price_index")))
  out <- node_subst_id(tpl, "gas")
  expect_identical(out$price_eur_kwh$ref, "market.energy_price.gas")
  expect_identical(out$x$expr, "measures.gas.cost_eur * 2")
  expect_identical(out$label, "{id} bleibt")
  expect_identical(out$n$sub$path, "measures.gas.price_index")
  ne <- node_subst_id(list(kind = "expr", text = "measures.{id}.a + 1", ast = NULL), "wp")
  expect_identical(ne, node_expr("measures.wp.a + 1"))
  expect_identical(node_subst_id(5, "a"), 5)
})

test_that("node_to_yaml ist die Umkehrung von node_normalize (Round-Trip 4.14)", {
  forms <- list(
    0.039, c(1, 2, 3),
    list(series = list("2027" = 0.028, "2028" = 0.022), fill = "zero", before = "zero"),
    list(years = c(2026, 2030), values = list(60, list(ref = "shared.c")),
         interpolate = "step"),
    list(schedule = list("2027-07-01" = 100, "2030-01-01" = 50), unit = "eur"),
    list(ref = "market.mortgage_rate", anchor = 0.025, floor = 0, scale = 2, offset = 0.01,
         cap = 0.2),
    list(start = 7.2, growth = list(ref = "market.rent_growth"), base_date = "2027-01-01",
         real = TRUE, index = "period_end"),
    list(expr = "building.living_area_m2 * 150"),
    list(value = 14, per = "m2_living_area")
  )
  for (f in forms) {
    nd <- node_normalize(f)
    back <- node_to_yaml(nd)
    expect_identical(node_normalize(back), nd, info = utl_collapse(names(f)))
  }
  expect_identical(node_to_yaml(list(kind = "auto", mode = "topup")), "topup")
  d <- node_normalize(list(dist = "pert", min = 1, mode = 2, max = 4, base = 2, label = "L"))
  expect_identical(node_normalize(node_to_yaml(d)), d)
  expect_identical(node_to_yaml("text"), "text")
  expect_identical(node_to_yaml(node_const(1)), 1)
})
