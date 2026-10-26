# Tests für R/report-table.R (WS-H): vofi_table(), vofi_ledger(), rep_table_diff()
# (Spec 00 Abschnitte 7.4-7.10, 13.5, 14 Nr. 22-23; Konzept 2.2).

#' Zeile einer Tabelle als Vektor
tab_row <- function(tab, key) {
  i <- match(key, tab$data$row_key)
  as.double(unlist(tab$data[i, tab$columns$label]))
}

#' Summe der Zeilen eines Abschnitts und einer Kategorie
tab_sum <- function(tab, section, category) {
  sel <- tab$data$section == section & tab$rows$category %in% category
  colSums(as.matrix(tab$data[sel, tab$columns$label, drop = FALSE]))
}

test_that("vofi_table: Grob-Layout von Orakel (a) gibt die Lehrbuchwerte wieder (Konzept 2.2)", {
  tab <- vofi_table(example_result())
  expect_s3_class(tab, "vofi_table")
  expect_identical(tab$layout, "grob")
  expect_identical(tab$detail, "standard")
  expect_identical(names(tab$data)[1:4], c("row_key", "label", "section", "level"))
  expect_identical(tab$columns$label, c("t0", "2027", "2028", "2029", "2030", "2031"))
  tol <- vofi_tol$oracle_tab
  expect_equal(tab_row(tab, "cf_project"), c(-100000, 6000, 10000, 30000, 8000, 70000),
               tolerance = tol)
  expect_equal(tab_row(tab, "equity_in"), c(30000, 0, 0, 0, 0, 0), tolerance = tol)
  expect_equal(unname(tab_sum(tab, "loans", "draw")), c(70000, 0, 0, 0, 0, 0), tolerance = tol)
  expect_equal(unname(tab_sum(tab, "loans", c("repay", "repay_balloon"))),
               c(0, -7095.86, -7521.61, -7972.90, -8451.28, -38958.35), tolerance = tol)
  expect_equal(unname(tab_sum(tab, "loans", "interest")),
               c(0, -3900, -3474.25, -3022.95, -2544.58, -2037.50), tolerance = tol)
  expect_equal(tab_row(tab, "od_draw") + tab_row(tab, "od_repay"),
               c(0, 4995.86, 1495.44, -6491.30, 0, 0), tolerance = tol)
  expect_equal(tab_row(tab, "od_interest"), c(0, 0, -499.59, -649.13, 0, 0), tolerance = tol)
  expect_equal(tab_row(tab, "dep_invest") + tab_row(tab, "dep_withdraw"),
               c(0, 0, 0, -11863.72, 2639.94, -29280.86), tolerance = tol)
  expect_equal(tab_row(tab, "dep_interest"), c(0, 0, 0, 0, 355.91, 276.71), tolerance = tol)
  expect_equal(tab_row(tab, "loan_ann_balance") + tab_row(tab, "loan_bul_balance"),
               c(70000, 62904.14, 55382.54, 47409.63, 38958.35, 0), tolerance = tol)
  expect_equal(tab_row(tab, "dep_balance"), c(0, 0, 0, 11863.72, 9223.77, 38504.63),
               tolerance = tol)
  expect_equal(tab_row(tab, "net_position"),
               c(-70000, -67900, -61873.83, -35545.92, -29734.58, 38504.63), tolerance = tol)
  expect_equal(tab_row(tab, "balance_check"), rep(0, 6L))
  # mit und ohne Restwert (9.4, 12.5): Endwert ohne Restwert -1.495,37 in T
  expect_equal(tab_row(tab, "net_position_ex_rv"),
               c(-70000, -67900, -61873.83, -35545.92, -29734.58, -1495.37), tolerance = tol)
  expect_equal(tab_row(tab, "project.residual_value"), c(0, 0, 0, 0, 0, 40000))
})

test_that("vofi_table: Reihenfolge nach Grob (7.8), Anzeige-Summen und Unterzeilen (R-19)", {
  tab <- vofi_table(example_result())
  d <- tab$data
  sec_order <- c(project = 1, grants = 2, equity = 3, loans = 4, overdraft = 5, deposit = 6,
                 tax = 7, check = 8, stocks = 9, memo = 10)
  expect_false(is.unsorted(sec_order[d$section]))
  expect_identical(d$row_key[1L], "cf_project")
  expect_identical(d$level[d$section == "project"], c(0L, 1L, 1L))
  expect_identical(d$row_key[d$section == "project"],
                   c("cf_project", "project.custom", "project.residual_value"))
  # cf_project = Summe der Unterzeilen
  sub <- colSums(as.matrix(d[d$section == "project" & d$level == 1L, tab$columns$label]))
  expect_equal(tab_row(tab, "cf_project"), unname(sub))
  # Kredite je Baustein in Vertragsreihenfolge, Bestände in der Reihenfolge 7.8
  expect_identical(d$row_key[d$section == "loans"],
                   paste0("loan_", rep(c("ann", "bul"), each = 6L), "_",
                          c("draw", "repay", "repay_balloon", "prepay", "interest", "fees")))
  expect_identical(d$row_key[d$section == "stocks"],
                   c("loan_ann_balance", "loan_bul_balance", "od_balance", "dep_balance",
                     "tax_liability", "net_position", "net_position_ex_rv"))
  # ohne Zuschusszeilen keine Anzeige-Summe grant_cash
  expect_false("grant_cash" %in% d$row_key)
  # Ertragsteuern mit Vermerk "nicht berücksichtigt"
  expect_match(d$label[d$row_key == "tax"], lbl("core.rows.tax_note_none"), fixed = TRUE)
  expect_identical(tab$rows$kind[tab$rows$row_key == "cf_project"], "sum")
  expect_true(all(c("z__value", "rv__value") %in% tab$rows$members[[1L]]))
})

test_that("vofi_table: standard blendet Nullzeilen nach 7.7 aus, full zeigt jede Ledger-Zeile", {
  x <- example_result()
  std <- vofi_table(x)
  full <- vofi_table(x, detail = "full")
  hide <- c("odp_balance", "dep_wht", "shortfall", "equity_call")
  expect_false(any(hide %in% std$data$row_key))
  expect_true(all(c(x$ledger$rows$key, "cf_project") %in% full$data$row_key))
  expect_identical(nrow(full$data), nrow(x$ledger$rows) + 2L)
  # Merkzeilen der Kredite ohne Betrag nur in full
  expect_false("loan_ann_disagio" %in% std$data$row_key)
  expect_true("loan_ann_disagio" %in% full$data$row_key)
  # Komponentenlabel nur in full
  expect_identical(full$data$label[full$data$row_key == "z__value"], "Zahlungsfolge: Zahlung")
  # nicht ausgeblendet, sobald ein Lauf einen Wert hat
  x2 <- x
  x2$ledger$values$equity_call[1L, 3L] <- 100
  x2$ledger$values$od_draw[1L, 3L] <- x2$ledger$values$od_draw[1L, 3L] - 100
  expect_true("equity_call" %in% vofi_table(x2)$data$row_key)
  # Kontokorrent: Summen je Kategorie enthalten die Strafzinstranche
  x3 <- x
  x3$ledger$values$odp_draw[1L, 2L] <- 10
  x3$ledger$values$od_draw[1L, 2L] <- x3$ledger$values$od_draw[1L, 2L] - 10
  t3 <- vofi_table(x3)
  expect_equal(tab_row(t3, "od_draw"), tab_row(std, "od_draw"))
  expect_identical(t3$rows$members[[match("od_draw", t3$data$row_key)]],
                   c("od_draw", "odp_draw"))
})

test_that("vofi_table: Zusch\u00fcsse (grant_cash), Merkzeilen und Einheiten", {
  x <- example_result()
  led <- x$ledger
  rows <- rbind(
    led$rows,
    new_ledger_rows("g__value", "grants", "operating_subsidy", source_id = "g",
                    source_type = "custom_series", local_row = "value",
                    label = "Zuschuss: Zahlung", order = 200030),
    new_ledger_rows("e__kwh", "memo", "energy_quantity", source_id = "e",
                    source_type = "custom_series", local_row = "kwh", label = "Gas: Menge",
                    order = 950100),
    new_ledger_rows("m__v", "memo", "market_value", source_id = "m",
                    source_type = "custom_series", local_row = "v", label = "Marktwert",
                    order = 950010)
  )
  vals <- c(led$values, list(g__value = matrix(c(0, 500, 0, 0, 0, 0), 1L),
                             e__kwh = matrix(c(0, rep(1000, 5L)), 1L),
                             m__v = matrix(rep(300000, 6L), 1L)))
  vals$dep_invest[1L, 2L] <- -500
  x$ledger <- new_vofi_ledger(rows, vals)
  tab <- vofi_table(x)
  expect_true("grant_cash" %in% tab$data$row_key)
  expect_identical(tab$data$level[tab$data$row_key == "grants.operating_subsidy"], 1L)
  expect_equal(tab_row(tab, "grant_cash"), c(0, 500, 0, 0, 0, 0))
  expect_identical(tab$data$section[nrow(tab$data)], "memo")
  expect_true(all(c("memo.market_value", "memo.energy_quantity.kWh") %in% tab$data$row_key))
  expect_match(tab$data$label[tab$data$row_key == "memo.energy_quantity.kWh"], "(kWh)",
               fixed = TRUE)
  expect_identical(tab$rows$unit[tab$rows$row_key == "memo.energy_quantity.kWh"], "kWh")
})

test_that("vofi_table: Perioden, transponiertes Layout, automatische Transposition", {
  x <- example_result()
  t1 <- vofi_table(x, periods = c(0, 5))
  expect_identical(t1$columns$label, c("t0", "2031"))
  expect_identical(t1$periods, c(0L, 5L))
  t2 <- vofi_table(x, periods = c("2028", "2029"))
  expect_identical(t2$columns$t, 2:3)
  expect_error(vofi_table(x, periods = 6), class = "vofi_error_input")
  expect_error(vofi_table(x, periods = "2040"), class = "vofi_error_input")
  expect_error(vofi_table(x, periods = 1.5), class = "vofi_error_input")
  tr <- vofi_table(x, layout = "transposed")
  expect_identical(tr$layout, "transposed")
  df <- as.data.frame(tr)
  expect_identical(nrow(df), 6L)
  expect_identical(names(df)[1:3], c("t", "period", "date_end"))
  expect_equal(df$net_position, tab_row(tr, "net_position"))
  # Raster mit mehr als 15 Perioden: ohne Angabe von layout transponiert (Konzept 5.5)
  sc <- vofi_scenario(list(
    schema_version = 1L, meta = list(scenario_id = "lang", title = "Lang"),
    project = list(perspective = "wu_kommunal", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 20L),
    components = list(z = list(type = "custom_series", values = c(-1000, rep(100, 20L)))),
    financing = list(ek = list(type = "equity", amount_eur = 1000)),
    accounts = wsh_accounts()
  ))
  long <- wsh_run(sc)
  expect_identical(vofi_table(long)$layout, "transposed")
  expect_identical(vofi_table(long, layout = "grob")$layout, "grob")
  expect_identical(vofi_table(long, periods = 0:10)$layout, "grob")
})

test_that("vofi_table: Engine-Ergebnis von Orakel (a) entspricht der Fixture", {
  res <- wsh_run(wsh_quiet(example_scenario("oracle_a")))
  a <- vofi_table(res)
  b <- vofi_table(example_result())
  expect_identical(a$data$row_key, b$data$row_key)
  for (k in a$data$row_key) {
    expect_equal(tab_row(a, k), tab_row(b, k), tolerance = 1e-6, info = k)
  }
})

test_that("vofi_table: Simulation (L\u00e4ufe, gespeicherte L\u00e4ufe) und Vergleich", {
  mc <- wsh_mc_full()
  t2 <- vofi_table(mc, sim = 2L)
  expect_equal(tab_row(t2, "cf_project"), 1.1 * c(-100000, 6000, 10000, 30000, 8000, 70000))
  expect_equal(tab_row(t2, "net_position_ex_rv")[6L], mc$kpis$terminal_value_ex_rv[2L])
  # ohne Restwertzeilen keine Zeile ohne Restwert
  sk <- wsh_run(vofi_read_scenario(vofi_example("skeleton")))
  expect_false("net_position_ex_rv" %in% vofi_table(sk)$data$row_key)
  expect_identical(t2$sim, 2L)
  # Batch-Invarianz: Lauf i der Tabelle = Tabelle des Einzellaufs i
  for (i in 1:3) {
    one <- example_result()
    one$ledger <- ledger_subset_sims(mc$ledger, i)
    one$kpis$terminal_value_ex_rv <- mc$kpis$terminal_value_ex_rv[i]
    expect_identical(vofi_table(mc, sim = i)$data, vofi_table(one)$data)
  }
  det <- vofi_table(wsh_mc(), sim = "deterministic")
  expect_identical(det$data, vofi_table(example_result())$data)
  expect_identical(det$sim, "deterministic")
  expect_s3_class(vofi_table(wsh_mc(), sim = "p50"), "vofi_table")
  expect_error(vofi_table(wsh_mc(), sim = "p99"), class = "vofi_error_input")
  expect_error(vofi_table(mc, sim = 201L), class = "vofi_error_input")
  cmp <- example_comparison()
  expect_identical(vofi_table(cmp)$variant, "base")
  expect_identical(vofi_table(cmp, variant = "a")$variant, "a")
  expect_error(vofi_table(cmp, variant = "b"), class = "vofi_error_input")
  expect_error(vofi_table(example_result(), variant = "a"), class = "vofi_error_input")
  expect_error(vofi_table(list()), class = "vofi_error_input")
  expect_error(vofi_table(example_result(), sim = 2L), class = "vofi_error_input")
  expect_error(vofi_table(example_result(), layout = "quer"), class = "vofi_error_input")
})

test_that("rep_table_diff: Differenz-VoFi Variante minus Referenz", {
  x <- example_result()
  y <- x
  y$ledger$values$z__value[1L, 6L] <- 31000
  y$ledger$values$dep_invest[1L, 6L] <- y$ledger$values$dep_invest[1L, 6L] - 1000
  y$meta$variant <- "a"
  d <- rep_table_diff(vofi_table(y), vofi_table(x))
  expect_s3_class(d, "vofi_table")
  expect_true(d$meta$diff)
  expect_equal(tab_row(d, "cf_project"), c(0, 0, 0, 0, 0, 1000))
  expect_equal(tab_row(d, "dep_invest"), c(0, 0, 0, 0, 0, -1000))
  expect_equal(tab_row(d, "balance_check"), rep(0, 6L))
  expect_match(d$variant, "a minus base", fixed = TRUE)
  expect_null(rep_table_diff(vofi_table(x, periods = 0:3), vofi_table(x)))
})

test_that("vofi_ledger: Long, Wide, Netto und USt (7.10), L\u00e4ufe, Vergleich", {
  x <- example_result()
  led <- x$ledger
  long <- vofi_ledger(x)
  expect_identical(nrow(long), nrow(led$rows) * 6L)
  expect_true(all(c("key", "section", "category", "tax_category", "cash", "sim", "t",
                    "period", "date_end", "year", "value") %in% names(long)))
  expect_equal(long$value[long$key == "z__value"], as.double(led$values$z__value))
  wide <- vofi_ledger(x, format = "wide")
  expect_identical(nrow(wide), nrow(led$rows))
  expect_equal(unlist(wide[wide$key == "net_position", x$grid$label]),
               led$values$net_position[1L, ], ignore_attr = TRUE)
  # USt verlustfrei: Zeile mit 19 % USt
  led2 <- led
  led2$rows$vat_rate[led2$rows$key == "z__value"] <- 0.19
  x$ledger <- led2
  lv <- vofi_ledger(x, vat = TRUE)
  z <- lv[lv$key == "z__value", ]
  expect_equal(z$net, z$value / 1.19)
  expect_equal(z$net + z$vat, z$value)
  wv <- vofi_ledger(x, format = "wide", vat = TRUE)
  expect_identical(nrow(wv), 3L * nrow(led$rows))
  zz <- wv[wv$key == "z__value", ]
  expect_identical(zz$amount, c("gross", "net", "vat"))
  g <- unlist(zz[1L, x$grid$label])
  expect_equal(unlist(zz[2L, x$grid$label]) + unlist(zz[3L, x$grid$label]), g)
  # Läufe einer Simulation mit Zahlungsbuch
  mc <- wsh_mc_full()
  expect_identical(sort(unique(vofi_ledger(mc, sim = 2:3)$sim)), 2:3)
  expect_identical(nrow(vofi_ledger(mc, format = "wide")), 3L * nrow(led$rows))
  expect_error(vofi_ledger(mc, sim = 5L), class = "vofi_error_input")
  expect_error(vofi_ledger(wsh_mc()), class = "vofi_error_input")
  expect_error(vofi_ledger(x, vat = NA), class = "vofi_error_input")
  cl <- vofi_ledger(example_comparison(), format = "wide")
  expect_identical(names(cl)[1L], "variant")
  expect_identical(unique(cl$variant), c("base", "a"))
})

test_that("Snapshots der VoFi-Tabelle (13.6, 15.6)", {
  skip_if_not(l10n_info()[["UTF-8"]])
  local_reproducible_output(width = 100)
  x <- example_result()
  expect_snapshot(print(vofi_table(x)))
  expect_snapshot(print(vofi_table(x, detail = "full", periods = 0:2)))
  expect_snapshot(print(vofi_table(x, layout = "transposed", periods = c(0, 5))))
})
