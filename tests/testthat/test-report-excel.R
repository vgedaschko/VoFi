# Tests für R/report-excel.R (WS-H): vofi_export_excel() (Spec 00 Abschnitte 7.10, 14 Nr. 25;
# Konzept 5.5): Blätter, Lesbarkeit mit openxlsx::read.xlsx, Saldo-Formel, Netto/USt.

#' Formeln eines VoFi-Blatts prüfen: Finanzierungssaldo und Anzeige-Summen
check_vofi_formulas <- function(path, sheet, tab, transposed = FALSE) {
  fm <- wsh_formulas(path, sheet)
  cells <- wsh_cells(path, sheet)
  d <- tab$data
  np <- nrow(tab$columns)
  first <- 6L
  idx_check <- which(d$section == "check")
  idx_cf <- which(d$row_key == "cf_project")
  expected_rows <- which(d$section %in% rep_balance_sections() & tab$rows$cash &
                           tab$rows$kind != "sum")
  for (j in seq_len(np)) {
    if (!transposed) {
      f <- fm$formula[fm$row == first + idx_check - 1L & fm$col == 2L + j]
    } else {
      f <- fm$formula[fm$row == first + j - 1L & fm$col == 2L + idx_check]
    }
    testthat::expect_length(f, 1L)
    v <- wsh_eval_sum(f, cells)
    testthat::expect_equal(v, 0, tolerance = 1e-6)
    testthat::expect_equal(v, tab$data[[tab$columns$label[j]]][idx_check], tolerance = 1e-6)
    fc <- if (!transposed) {
      fm$formula[fm$row == first + idx_cf - 1L & fm$col == 2L + j]
    } else {
      fm$formula[fm$row == first + j - 1L & fm$col == 2L + idx_cf]
    }
    testthat::expect_equal(wsh_eval_sum(fc, cells), d[[tab$columns$label[j]]][idx_cf],
                           tolerance = 1e-6)
  }
  # die Saldo-Formel der ersten Periode umfasst genau die zahlungswirksamen Zeilen
  if (!transposed) {
    f1 <- fm$formula[fm$row == first + idx_check - 1L & fm$col == 3L]
    hit <- integer(0)
    for (ref in regmatches(f1, gregexpr("C[0-9]+(:C[0-9]+)?", f1))[[1L]]) {
      p <- as.integer(strsplit(gsub("C", "", ref), ":", fixed = TRUE)[[1L]])
      hit <- c(hit, seq(p[1L], p[length(p)]))
    }
    testthat::expect_identical(sort(hit), first + expected_rows - 1L)
  }
  invisible(fm)
}

test_that("vofi_export_excel: Ergebnis mit allen Bl\u00e4ttern, lesbar mit read.xlsx", {
  x <- example_result()
  f <- wsh_xlsx()
  expect_identical(vofi_export_excel(x, f), f)
  expect_true(file.exists(f))
  expect_identical(openxlsx::getSheetNames(f),
                   vapply(c("overview", "vofi", "vofi_transposed", "kpis", "ledger",
                            "assumptions", "checks"),
                          function(k) lbl(paste0("excel_export.sheets.", k)), ""),
                   ignore_attr = TRUE)
  v <- wsh_read_xlsx(f, sheet = lbl("excel_export.sheets.vofi"), startRow = 4L)
  expect_identical(names(v)[1:3], c(lbl("report.table.position"),
                                    lbl("excel_export.columns.key"), "t0"))
  tab <- vofi_table(x)
  vv <- v[-1L, ]
  expect_identical(vv[[2L]], tab$data$row_key)
  i <- match("net_position", vv[[2L]])
  expect_equal(as.double(unlist(vv[i, 3:8])), as.double(unlist(tab$data[i, tab$columns$label])),
               tolerance = 1e-9)
  ov <- wsh_read_xlsx(f, sheet = lbl("excel_export.sheets.overview"), startRow = 4L)
  expect_true(any(grepl("3.726,41", ov[[2L]], fixed = TRUE)))
  expect_true(any(grepl(lbl("report.notes.tax_none"), ov[[2L]], fixed = TRUE)))
})

test_that("Saldo-Formel: Finanzierungssaldo als Excel-Formel ergibt 0 (Grob und transponiert)", {
  x <- example_result()
  f <- wsh_xlsx()
  vofi_export_excel(x, f)
  tab <- vofi_table(x)
  fm <- check_vofi_formulas(f, lbl("excel_export.sheets.vofi"), tab)
  expect_true(all(grepl("^SUM\\(", fm$formula)))
  expect_identical(nrow(fm), 2L * 6L)
  check_vofi_formulas(f, lbl("excel_export.sheets.vofi_transposed"), tab, transposed = TRUE)
  # Mietersicht: Merkzeilen (Mieterkosten) stehen in der Tabelle, aber nicht in der Formel
  res <- wsh_run(wsh_tenant_scenario())
  f2 <- wsh_xlsx()
  vofi_export_excel(res, f2, sheets = c("vofi", "vofi_transposed"))
  tab2 <- vofi_table(res)
  expect_true(any(tab2$data$section == "memo"))
  check_vofi_formulas(f2, lbl("excel_export.sheets.vofi"), tab2)
  check_vofi_formulas(f2, lbl("excel_export.sheets.vofi_transposed"), tab2, transposed = TRUE)
  # Bauphase mit unterjährigem Raster (Selbstnutzer)
  res3 <- wsh_run(wsh_self_scenario())
  f3 <- wsh_xlsx()
  vofi_export_excel(res3, f3, sheets = "vofi")
  check_vofi_formulas(f3, lbl("excel_export.sheets.vofi"), vofi_table(res3))
})

test_that("rep_xl_sum_formula: Bereiche, Einzelzellen, Zeilen und viele Argumente", {
  expect_identical(rep_xl_sum_formula("C", c(5:9, 11, 13:14)), "SUM(C5:C9,C11,C13:C14)")
  expect_identical(rep_xl_sum_formula("D", integer(0)), "0")
  expect_identical(rep_xl_sum_formula(rows = 7L, cols = c(3:5, 8L)), "SUM(C7:E7,H7)")
  many <- rep_xl_sum_formula("C", seq(1L, 1000L, by = 2L))
  expect_match(many, "^SUM\\(SUM\\(")
  expect_identical(lengths(regmatches(many, gregexpr("SUM\\(", many))), 4L)
})

test_that("Bl\u00e4tter Kennzahlen, Zahlungsbuch (brutto/netto/USt), Annahmen, Pr\u00fcfungen", {
  x <- example_result()
  x$ledger$rows$vat_rate[x$ledger$rows$key == "z__value"] <- 0.19
  f <- wsh_xlsx()
  vofi_export_excel(x, f)
  k <- wsh_read_xlsx(f, sheet = lbl("excel_export.sheets.kpis"), startRow = 4L)
  kp <- vofi_kpis(x)
  expect_identical(k[[lbl("excel_export.columns.kpi")]], kp$kpi)
  expect_equal(k[[lbl("excel_export.columns.value")]], kp$value)
  expect_true(all(k[[lbl("excel_export.columns.rv")]] %in%
                    vapply(c("with", "without", "independent"),
                           function(r) lbl(paste0("excel_export.rv.", r)), "")))
  l <- wsh_read_xlsx(f, sheet = lbl("excel_export.sheets.ledger"), startRow = 4L,
                     check.names = FALSE)
  z <- l[l[[lbl("excel_export.columns.key")]] == "z__value", ]
  expect_identical(z[[lbl("excel_export.columns.amount")]],
                   c(lbl("excel_export.amount.gross"), lbl("excel_export.amount.net"),
                     lbl("excel_export.amount.vat")))
  expect_equal(z[["t0"]], c(-100000, -100000 / 1.19, -100000 + 100000 / 1.19))
  a <- wsh_read_xlsx(f, sheet = lbl("excel_export.sheets.assumptions"), startRow = 4L,
                     colNames = FALSE)
  expect_true(any(a[[1L]] == lbl("excel_export.columns.contract_version")))
  expect_true(any(a[[1L]] == "accounts.deposit_rate_pa"))
  ch <- wsh_read_xlsx(f, sheet = lbl("excel_export.sheets.checks"), startRow = 4L)
  expect_identical(ch[[lbl("excel_export.columns.invariant")]][1:7], x$checks$invariant)
  # Kennzahlen je WE und je m²: Wohnfläche 900 m² im Prüfkit
  expect_true(lbl("excel_export.columns.per_m2") %in% names(k))
  i <- match("terminal_value", k[[lbl("excel_export.columns.kpi")]])
  expect_equal(k[[lbl("excel_export.columns.per_m2")]][i], x$kpis$terminal_value / 900)
})

test_that("Simulation, Vergleich und Sensitivit\u00e4t", {
  mc <- wsh_mc()
  f <- wsh_xlsx()
  vofi_export_excel(mc, f)
  sh <- openxlsx::getSheetNames(f)
  expect_true(all(c(lbl("excel_export.sheets.mc_stats"), lbl("excel_export.sheets.mc_runs"),
                    lbl("excel_export.sheets.mc_bands")) %in% sh))
  st <- wsh_read_xlsx(f, sheet = lbl("excel_export.sheets.mc_stats"), startRow = 4L)
  expect_equal(st[[lbl("excel_export.columns.q50")]], mc$stats$q50)
  runs <- wsh_read_xlsx(f, sheet = lbl("excel_export.sheets.mc_runs"), startRow = 3L)
  expect_identical(nrow(runs), 200L)
  bands <- wsh_read_xlsx(f, sheet = lbl("excel_export.sheets.mc_bands"), startRow = 3L)
  expect_identical(nrow(bands), 18L)
  check_vofi_formulas(f, lbl("excel_export.sheets.vofi"), vofi_table(mc, sim = "deterministic"))
  cmp <- example_comparison()
  f2 <- wsh_xlsx()
  vofi_export_excel(cmp, f2)
  sh2 <- openxlsx::getSheetNames(f2)
  expect_true(all(c("VoFi base", "VoFi a", lbl("excel_export.sheets.diff_vofi"),
                    lbl("excel_export.sheets.variants"), lbl("excel_export.sheets.differences"),
                    lbl("excel_export.sheets.traffic_light")) %in% sh2))
  check_vofi_formulas(f2, "VoFi a", vofi_table(cmp, variant = "a"))
  va <- wsh_read_xlsx(f2, sheet = lbl("excel_export.sheets.variants"), startRow = 4L)
  expect_equal(va$a[va[[lbl("excel_export.columns.kpi")]] == "delta_terminal_value"],
               cmp$results$a$kpis$delta_terminal_value)
  dv <- wsh_read_xlsx(f2, sheet = lbl("excel_export.sheets.diff_vofi"), startRow = 2L)
  expect_true(all(abs(as.matrix(dv[, -(1:2)])) < 1e-9))
  f3 <- wsh_xlsx()
  vofi_export_excel(wsh_sensitivity("tornado"), f3)
  expect_identical(length(openxlsx::getSheetNames(f3)), 3L)
  s <- wsh_read_xlsx(f3, sheet = lbl("excel_export.sheets.sensitivity"), startRow = 3L)
  expect_equal(s[[lbl("excel_export.columns.swing")]], c(9000, 1500))
})

test_that("vofi_export_excel: Auswahl der Bl\u00e4tter, \u00dcberschreiben und Fehler", {
  x <- example_result()
  f <- wsh_xlsx()
  vofi_export_excel(x, f, sheets = c("kpis", "vofi"))
  expect_identical(openxlsx::getSheetNames(f), c(lbl("excel_export.sheets.vofi"),
                                                 lbl("excel_export.sheets.kpis")))
  expect_error(vofi_export_excel(x, f), class = "vofi_error_input")
  expect_identical(vofi_export_excel(x, f, overwrite = TRUE, sheets = "checks"), f)
  expect_identical(openxlsx::getSheetNames(f), lbl("excel_export.sheets.checks"))
  expect_error(vofi_export_excel(x, sub("xlsx$", "csv", f)), class = "vofi_error_input")
  expect_error(vofi_export_excel(x, file.path(tempdir(), "fehlt", "a.xlsx")),
               class = "vofi_error_input")
  expect_error(vofi_export_excel(x, f, overwrite = TRUE, sheets = "mc_stats"),
               class = "vofi_error_input")
  expect_error(vofi_export_excel(x, f, overwrite = TRUE, sheets = "kpi"),
               class = "vofi_error_input")
  expect_error(vofi_export_excel(x, f, overwrite = NA), class = "vofi_error_input")
  expect_error(vofi_export_excel(list(), f), class = "vofi_error_input")
})
