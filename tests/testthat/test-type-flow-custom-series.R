# Tests des Zahlungstyps custom_series (WS-E-INV; Spec 00 7.12, Spec 01 Teil A 4.13, Prüfwert CS1).

test_that("Vertrag und Registrierung", {
  expect_type_contract("custom_series", "flow")
})

test_that("CS1: Periodenbeträge ohne Delta-Skalierung, Kategorie other_cost", {
  g <- make_grid("annual", T = 3L)
  res <- wsei_build(list(cs = list(type = "custom_series", values = c(0, -1000, -1000, 0),
                                   category = "other_cost")), g)
  f <- res$flows$cs
  expect_equal(wsei_row(f, "value"), c(0, -1000, -1000, 0))
  r <- f$rows[[1]]
  expect_identical(c(r$section, r$category, r$tax_category), c("project", "other_cost",
                                                               "expense_deductible"))
  expect_vofi_flows_contract(f, res$ctx, reg_get("flow", "custom_series"))
  # auf dem gemischten Raster unverändert je Periode (keine Delta-Skalierung)
  g4 <- make_grid("mixed", T = 2L)
  vals <- seq_len(g4$T + 1L) * -10
  f4 <- wsei_build(list(cs = list(type = "custom_series", values = vals,
                                  category = "other_cost")), g4)$flows$cs
  expect_equal(wsei_row(f4, "value"), vals)
})

test_that("CS1: Kategorie rent mit negativem Wert ist ein Fehler", {
  f <- wsei_findings("custom_series", values = c(0, -1000, -1000, 0), category = "rent",
                     scenario = make_spec(make_grid("annual", T = 3L)))
  expect_identical(unname(f["components.sign"]), "error")
  g <- make_grid("annual", T = 3L)
  res <- wsei_build(list(cs = list(type = "custom_series", values = c(0, -1000, -1000, 0),
                                   category = "rent")), g)
  bad <- reg_flow_findings(res$flows$cs, res$ctx, reg_get("flow", "custom_series"), 1L, g, "")
  expect_false(bad$ok[bad$check == "F5"])
})

test_that("Kategorie custom: Default not_applicable, beide Vorzeichen; Tags gehen über", {
  g <- make_grid("annual", T = 3L)
  f <- wsei_build(list(cs = list(type = "custom_series", values = c(10, -10, 5, 0))), g)$flows$cs
  r <- f$rows[[1]]
  expect_identical(c(r$category, r$tax_category), c("custom", "not_applicable"))
  f2 <- wsei_build(list(cs = list(type = "custom_series", values = c(0, -5, 0, 0),
                                  category = "capex", asset_id = "b1", measure_id = "m1",
                                  tax_category = "capex_expensable")), g)$flows$cs
  r2 <- f2$rows[[1]]
  expect_identical(c(r2$asset_id, r2$measure_id, r2$tax_category),
                   c("b1", "m1", "capex_expensable"))
})

test_that("Abschnitt memo: nicht zahlungswirksam; memo mit cash = TRUE ist ein Fehler", {
  g <- make_grid("annual", T = 3L)
  f <- wsei_build(list(cs = list(type = "custom_series", values = c(1, 2, 3, 4),
                                 section = "memo", category = "aux_memo")), g)$flows$cs
  expect_false(f$rows[[1]]$cash)
  e <- wsei_findings("custom_series", values = c(1, 2, 3, 4), section = "memo",
                     category = "aux_memo", cash = TRUE)
  expect_identical(unname(e["components.memo_cash"]), "error")
})

test_that("validate(): Kategorie, Steuerkategorie, Einheit", {
  f <- wsei_findings("custom_series", values = c(0, 1, 0, 0), category = "rnet")
  expect_identical(unname(f["components.category_invalid"]), "error")
  f <- wsei_findings("custom_series", values = c(0, -1, 0, 0), category = "other_cost",
                     tax_category = "principal")
  expect_identical(unname(f["components.tax_category_invalid"]), "error")
  f <- wsei_findings("custom_series", values = c(0, -1, 0, 0), category = "other_cost",
                     tax_category = "income_rental")
  expect_identical(unname(f["components.tax_category_invalid"]), "error")
  f <- wsei_findings("custom_series", values = c(0, 1, 0, 0), section = "memo",
                     category = "aux_memo", unit = "furlongs")
  expect_identical(unname(f["components.unit_invalid"]), "error")
  f <- wsei_findings("custom_series", values = c(0, 1, 0, 0), category = "draw",
                     section = "project")
  expect_identical(unname(f["components.category_invalid"]), "error")
  expect_length(wsei_findings("custom_series", values = c(0, -1, 0, 0),
                              category = "other_cost"), 0L)
})

test_that("Fehlende Werte sind ein Vertragsfehler; Batch-Invarianz", {
  g <- make_grid("annual", T = 3L)
  expect_error(wsei_build(list(cs = list(type = "custom_series")), g),
               class = "vofi_error_contract")
  dr <- fake_draws(3L, g, paths = list("components.cs.values" = rbind(c(0, -1, -2, -3),
                                                                      c(0, -4, -5, -6),
                                                                      c(0, -7, -8, -9))))
  fun <- function(n, draws) {
    wsei_build(list(cs = list(type = "custom_series", values = c(0, -1, -1, -1),
                              category = "other_cost")), g, n = n, draws = draws)$flows$cs
  }
  expect_batch_invariance(fun, n = 3L, grid = g, draws = dr)
})
