# Tests für R/contracts.R (Integrator; Spec 00 Abschnitte 2.13, 7, 11.8, 12.1, 13).

m3 <- function(x = c(0, 1, 2)) matrix(as.double(x), nrow = 1)

test_that("Vertragsversion und Toleranzen", {
  expect_identical(VOFI_CONTRACT_VERSION, "1.0.0")
  expect_identical(vofi_tol$balance_rel, 1e-8)
  expect_identical(vofi_tol$stock_abs, 1e-6)
  expect_identical(vofi_tol$zero_abs, 1e-9)
  expect_identical(vofi_tol$oracle_abs, 1e-6)
  expect_identical(vofi_tol$oracle_tab, 0.005)
})

test_that("vofi_row: Defaults der Kategorie", {
  r <- vofi_row("value", m3(), section = "project", category = "rent")
  expect_s3_class(r, "vofi_row")
  expect_identical(r$tax_category, "income_rental")
  expect_true(r$cash)
  expect_identical(r$kind, "flow")
  expect_identical(r$unit, "EUR")
  expect_identical(r$vat_rate, 0)
  expect_false(r$vat_recoverable)
  q <- vofi_row("kwh", m3(), section = "memo", category = "energy_quantity")
  expect_false(q$cash)
  expect_identical(q$unit, "kWh")
  expect_identical(q$kind, "memo")
  mv <- vofi_row("mv", m3(), section = "memo", category = "market_value", asset_id = "b1")
  expect_identical(mv$kind, "stock")
  ri <- vofi_row("v", matrix(1:3, 1), "project", "rent")
  expect_true(is.double(ri$values))
})

test_that("vofi_row: zul\u00e4ssige Angaben und Zusatzfelder", {
  r <- vofi_row("cost_vat19", -m3(), "project", "capex", tax_category = "capex_expensable",
                asset_id = "b1", measure_id = "m1", vat_rate = 0.19, is_tax = "umsatzsteuer",
                program = "beg", label = "Kosten", spread_years = 3)
  expect_identical(r$extra$spread_years, 3L)
  expect_identical(r$tax_category, "capex_expensable")
  rp <- vofi_row("p", m3(), "memo", "residual_path", rv_basis = "measures")
  expect_identical(rp$extra$rv_basis, "measures")
  cu <- vofi_row("c", m3(), "project", "custom", tax_category = "income_rental")
  expect_identical(cu$tax_category, "income_rental")
  st <- vofi_row("s", m3(), "memo", "aux_memo", kind = "stock", unit = "m2")
  expect_identical(st$unit, "m2")
})

test_that("vofi_row: Vertragsverletzungen", {
  ec <- "vofi_error_contract"
  expect_error(vofi_row("A", m3(), "project", "rent"), class = ec)
  expect_error(vofi_row("a__b", m3(), "project", "rent"), class = ec)
  expect_error(vofi_row("v", c(0, 1), "project", "rent"), class = ec)
  expect_error(vofi_row("v", m3(c(0, NA, 1)), "project", "rent"), class = ec)
  expect_error(vofi_row("v", m3(c(0, Inf, 1)), "project", "rent"), class = ec)
  expect_error(vofi_row("v", m3(), "projekt", "rent"), class = ec)
  expect_error(vofi_row("v", m3(), "grants", "rent"), class = ec)
  expect_error(vofi_row("v", m3(), "project", "rent", tax_category = "principal"), class = ec)
  expect_error(vofi_row("v", m3(), "project", "custom", tax_category = "tax_credit"), class = ec)
  expect_error(vofi_row("v", m3(), "memo", "aux_memo", cash = TRUE), class = ec)
  expect_error(vofi_row("v", m3(), "project", "rent", cash = NA), class = ec)
  expect_error(vofi_row("v", m3(), "project", "rent", kind = "check"), class = ec)
  expect_error(vofi_row("v", m3(), "project", "rent", unit = "kWh"), class = ec)
  expect_error(vofi_row("v", m3(), "memo", "energy_quantity", unit = "EUR"), class = ec)
  expect_error(vofi_row("v", m3(), "project", "rent", unit = "furlong"), class = ec)
  expect_error(vofi_row("v", m3(), "project", "rent", vat_rate = 1.5), class = ec)
  expect_error(vofi_row("v", m3(), "project", "rent", vat_recoverable = TRUE), class = ec)
  expect_error(vofi_row("v", m3(), "project", "rent", is_tax = "hundesteuer"), class = ec)
  expect_error(vofi_row("v", m3(), "project", "rent", asset_id = "B 1"), class = ec)
  expect_error(vofi_row("v", m3(), "project", "rent", program = 3), class = ec)
  expect_error(vofi_row("v", m3(), "project", "rent", foo = 1), class = ec)
  expect_error(vofi_row("v", m3(), "project", "rent", rv_basis = "method"), class = ec)
  expect_error(vofi_row("v", m3(), "project", "rent", spread_years = 1.5), class = ec)
  expect_error(vofi_row("v", m3(), "project", "rent", 1), class = ec)
})

test_that("validate_flow_row: Flows ohne Engine-Kategorien, ohne principal", {
  ok <- vofi_row("in", m3(), "equity", "equity_in")
  expect_identical(validate_flow_row(ok), character(0))
  eng <- vofi_row("x", m3(), "loans", "draw")
  expect_true(length(validate_flow_row(eng)) >= 1L)
  call <- vofi_row("x", m3(), "equity", "equity_call")
  expect_true(length(validate_flow_row(call)) >= 1L)
  dep <- vofi_row("x", m3(), "deposit", "interest")
  expect_true(length(validate_flow_row(dep)) >= 1L)
})

test_that("vofi_flows: Zeilen, Register, aux, meta", {
  r1 <- vofi_row("a", m3(), "project", "rent")
  r2 <- vofi_row("b", -m3(), "project", "operating_cost")
  f <- vofi_flows(r1, r2, assets = vofi_asset("b1", "gebaeude_wohnen", "2028-01-01"),
                  aux = list(heat = m3()), meta = list(note = "x"))
  expect_s3_class(f, "vofi_flows")
  expect_identical(length(f$rows), 2L)
  expect_identical(length(f$assets), 1L)
  f2 <- vofi_flows(list(r1, r2))
  expect_identical(vapply(f2$rows, function(r) r$key, ""), c("a", "b"))
  expect_identical(length(vofi_flows()$rows), 0L)
  ec <- "vofi_error_contract"
  expect_error(vofi_flows(r1, r1), class = ec)
  expect_error(vofi_flows(r1, vofi_row("c", matrix(0, 2, 3), "project", "rent")), class = ec)
  expect_error(vofi_flows("x"), class = ec)
  expect_error(vofi_flows(r1, aux = list(m3())), class = ec)
  expect_error(vofi_flows(r1, aux = list(h = matrix(0, 1, 2))), class = ec)
  expect_error(vofi_flows(r1, meta = "x"), class = ec)
  expect_error(vofi_flows(r1, assets = list("b1")), class = ec)
  a1 <- vofi_asset("b1", "gebaeude_wohnen", "2028-01-01")
  a2 <- vofi_asset("b1", "pv_anlage", "2028-01-01")
  expect_identical(length(vofi_flows(assets = list(a1, a1))$assets), 1L)
  expect_error(vofi_flows(assets = list(a1, a2)), class = ec)
})

test_that("vofi_asset und vofi_measure", {
  a <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2028-01-01"), land_share = 0.2,
                  original_completion_year = 1972, living_area_m2 = 900, label = "Haus")
  expect_s3_class(a, "vofi_asset")
  expect_identical(a$original_completion_year, 1972L)
  expect_identical(a$in_service_date, as.Date("2028-01-01"))
  ec <- "vofi_error_contract"
  expect_error(vofi_asset("b1", "schloss", "2028-01-01"), class = ec)
  expect_error(vofi_asset("b1", "gebaeude_wohnen", "2028-01-01", land_share = 2), class = ec)
  expect_error(vofi_asset("B1", "gebaeude_wohnen", "2028-01-01"), class = ec)
  expect_error(vofi_asset("b1", "gebaeude_wohnen", "kein Datum"), class = "vofi_error_input")
  m <- vofi_measure("huelle", "daemmung_fassade")
  expect_identical(m$classification, "auto")
  expect_identical(m$funding_choice, "keine")
  expect_true(is.na(m$contractor_certified))
  m2 <- vofi_measure("wp", "heizung_tausch", classification = "herstellung",
                     funding_choice = "35c", completion_date = "2028-03-01", asset_id = "b1")
  expect_identical(m2$completion_date, as.Date("2028-03-01"))
  expect_error(vofi_measure("x", "gibtsnicht"), class = ec)
  expect_error(vofi_measure("x", "pv", classification = "foo"), class = "vofi_error_input")
})

test_that("vofi_kpi_value: NA nur mit Code", {
  v <- vofi_kpi_value(c(1, NA, 3), na_reason = c(NA, "no_equity", NA))
  expect_s3_class(v, "vofi_kpi_value")
  expect_identical(v$shape, "scalar")
  expect_identical(v$na_reason, c(NA, "no_equity", NA))
  v1 <- vofi_kpi_value(c(1, NA), na_reason = "no_payback")
  expect_identical(v1$na_reason, c(NA, "no_payback"))
  vs <- vofi_kpi_value(matrix(c(1, 2, NA, 4), 2), na_reason = c("no_operation_period", NA),
                       years = c(1, 2))
  expect_identical(vs$shape, "series")
  expect_identical(vs$years, c(1L, 2L))
  ec <- "vofi_error_contract"
  expect_error(vofi_kpi_value(c(1, NA)), class = ec)
  expect_error(vofi_kpi_value(c(1, NA), na_reason = c(NA, "falscher_code")), class = ec)
  expect_error(vofi_kpi_value(c(1, Inf)), class = ec)
  expect_error(vofi_kpi_value("a"), class = ec)
  expect_error(vofi_kpi_value(c(1, 2), na_reason = c(NA, NA, NA)), class = ec)
  expect_error(vofi_kpi_value(matrix(1, 2, 2)), class = ec)
})

test_that("Ledger: Metadaten und Validierung", {
  rows <- new_ledger_rows(c("a__v", "loan_k_draw", "net_position"),
                          c("project", "loans", "stocks"), c("rent", "draw", "net_position"))
  expect_identical(rows$tax_category, c("income_rental", "principal", "not_applicable"))
  expect_identical(rows$cash, c(TRUE, TRUE, FALSE))
  expect_identical(rows$kind, c("flow", "flow", "stock"))
  expect_equal(rows$order[1], 1000 * 100 + 10 * 6)
  expect_true(all(c("extra", "existing_debt", "source_id", "label_key") %in% names(rows)))
  vals <- list(a__v = matrix(1, 2, 4), loan_k_draw = matrix(0, 2, 4),
               net_position = matrix(0, 2, 4))
  led <- new_vofi_ledger(rows, vals)
  expect_s3_class(led, "vofi_ledger")
  expect_identical(led$n, 2L)
  expect_identical(led$T, 3L)
  ec <- "vofi_error_contract"
  expect_error(new_vofi_ledger(rows, vals[3:1]), class = ec)
  bad <- vals
  bad$a__v <- matrix(1, 1, 4)
  expect_error(new_vofi_ledger(rows, bad), class = ec)
  bad$a__v <- matrix(NA_real_, 2, 4)
  expect_error(new_vofi_ledger(rows, bad), class = ec)
  expect_error(new_ledger_rows("x", "project", "gibtsnicht"), class = ec)
  r2 <- rbind(rows, rows[1, , drop = FALSE])
  expect_identical(nrow(r2), 4L)
})

test_that("Ziehungsobjekt: Konstruktor und Zusicherungen", {
  d <- new_vofi_draws("mc", n = 3, static = list(k = c(1, 2, 3)),
                      paths = list(p = matrix(0, 3, 7)),
                      targets = data.frame(key = c("k", "p"), target = c("a.b", "c.d"),
                                           kind = c("static", "process")))
  expect_s3_class(d, "vofi_draws")
  expect_identical(d$sims, 1:3)
  expect_identical(nrow(d$features), 3L)
  ec <- "vofi_error_contract"
  expect_error(new_vofi_draws("mc", n = 3, static = list(k = 1)), class = ec)
  expect_error(new_vofi_draws("mc", n = 3, paths = list(p = matrix(0, 2, 7))), class = ec)
  expect_error(validate_vofi_draws(d, T = 5), class = ec)
  expect_error(new_vofi_draws("mc", n = 1, targets = data.frame(key = c("a", "b"),
                                                                target = c("x", "x"),
                                                                kind = "static")),
               class = ec)
  expect_error(new_vofi_draws("zufall"), class = "vofi_error_input")
})

test_that("Szenario-, Spezifikations- und Modellobjekte", {
  sc <- new_vofi_scenario(list(meta = list(scenario_id = "x")), source = list(format = "list"))
  expect_s3_class(sc, "vofi_scenario")
  expect_identical(sc$schema_version, 1L)
  expect_true(all(utl_scenario_blocks() %in% names(sc)))
  expect_identical(attr(sc, "source")$format, "list")
  sp <- new_vofi_spec(list(project = list(perspective = "wu_privat")))
  expect_s3_class(sp, "vofi_spec")
  expect_identical(sp$variant, "base")
  expect_true("scenario_set" %in% names(sp))
  expect_true(is.data.frame(sp$library))
  g <- vofi_time_grid("2027-01-01", 2)
  mo <- new_vofi_model(list(spec = sp, grid = g))
  expect_identical(mo$contract_version, VOFI_CONTRACT_VERSION)
  expect_error(new_vofi_model(list(spec = sp)), class = "vofi_error_contract")
  st <- new_vofi_inst_state(list(B = 0))
  expect_s3_class(st, "vofi_inst_state")
})

test_that("Ergebnisklassen: Pflichtfelder", {
  ec <- "vofi_error_contract"
  expect_error(new_vofi_result(list()), class = ec)
  expect_error(new_vofi_mc_result(list(spec = 1)), class = ec)
  expect_error(new_vofi_comparison(list()), class = ec)
  s <- new_vofi_sensitivity(list(method = "tornado", kpi = "x", params = data.frame(),
                                 meta = list()))
  expect_s3_class(s, "vofi_sensitivity")
  expect_true("results" %in% names(s))
  so <- new_vofi_solution(list(what = "breakeven", value = 1))
  expect_s3_class(so, "vofi_solution")
  expect_identical(so$target_source, "value")
  tb <- new_vofi_table(list(data = data.frame(), layout = "grob", detail = "standard"))
  expect_identical(tb$sim, 1L)
  v <- new_vofi_validation()
  expect_s3_class(v, "vofi_validation")
  expect_identical(names(v), c("severity", "code", "path", "location", "message", "layer",
                               "variant"))
  expect_error(new_vofi_validation(data.frame(a = 1)), class = ec)
  f <- new_vofi_finding("warning", "validation.x", path = "a.b")
  expect_s3_class(f, "vofi_finding")
})
