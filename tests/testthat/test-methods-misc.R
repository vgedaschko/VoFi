# Tests für R/methods-misc.R (WS-H): Methoden der Klassen vofi_table und vofi_sensitivity,
# Zahlenformat je Einheit und Ausgabe von Zeichenmatrizen (Spec 00 Abschnitte 2.10, 13.4-13.6).

test_that("rep_fmt_value: deutsches Format je Einheit (2.10)", {
  expect_identical(rep_fmt_value(1234.567, "EUR"), "1.234,57 \u20ac")
  expect_identical(rep_fmt_value(1234.567, "EUR", 0), "1.235 \u20ac")
  expect_identical(rep_fmt_value(0.038, "rate_pa"), "3,80 %")
  expect_identical(rep_fmt_value(0.5, "share"), "50,00 %")
  expect_identical(rep_fmt_value(2031, "year"), "2031")
  expect_identical(rep_fmt_value(5, "years"), "5,0 Jahre")
  expect_identical(rep_fmt_value(c(1, 0), "flag"), c(lbl("report.common.yes"),
                                                     lbl("report.common.no")))
  expect_identical(rep_fmt_value(1.2345, "ratio"), "1,23")
  expect_identical(rep_fmt_value(250.5, "EUR_month"), "250,50 EUR/Monat")
  expect_identical(rep_fmt_value(12.34, "t_co2"), "12,3 t CO2")
  expect_identical(rep_fmt_value(7, "count"), "7")
  expect_identical(rep_fmt_value(1.5, NA), "1,50")
  expect_identical(rep_fmt_value(NA, "EUR"), "n. d.")
  expect_identical(rep_fmt_kpi(NA, "EUR", "no_payback"),
                   paste0("n. d. (", lbl("vocab.na_reasons.no_payback"), ")"))
  expect_identical(rep_fmt_kpi(-1, "EUR", NA), "-1,00 \u20ac")
})

test_that("rep_cat_matrix bricht nach der Zeilenbreite um und wiederholt die Kopfspalte", {
  m <- matrix(c("a", "b", rep("1.000,00", 10L)), nrow = 2L)
  colnames(m) <- c("Zeile", paste0("P", 1:5))
  out <- capture.output(rep_cat_matrix(m, left = 1L, width = 30L))
  expect_true(all(nchar(out) <= 30L))
  expect_identical(sum(grepl("^  Zeile", out)), 3L)
  out2 <- capture.output(rep_cat_matrix(m, left = 1L, width = 200L))
  expect_identical(length(out2), 3L)
  expect_silent(rep_cat_matrix(matrix(character(0), 0L, 0L)))
})

test_that("format(), print(), as.data.frame() f\u00fcr vofi_table", {
  tab <- vofi_table(example_result())
  m <- format(tab)
  expect_identical(dim(m), c(nrow(tab$data), 7L))
  expect_identical(unname(m[tab$data$row_key == "balance_check", "2027"]), "0,00")
  expect_identical(unname(m[tab$data$row_key == "equity_out", "2027"]), "\u2013")
  expect_identical(unname(m[tab$data$row_key == "project.custom", 1L]), "  Zahlung (frei)")
  expect_identical(unname(format(tab, zero = "0")[tab$data$row_key == "equity_out", "2027"]), "0")
  expect_identical(unname(format(tab, digits = 0)[1L, "t0"]), "-100.000")
  mt <- format(tab, layout = "transposed")
  expect_identical(dim(mt), c(6L, nrow(tab$data) + 1L))
  out <- capture.output(res <- print(tab))
  expect_identical(res, tab)
  expect_match(out[1L], lbl("report.table.layout_grob"), fixed = TRUE)
  out2 <- capture.output(print(tab, layout = "transposed"))
  expect_match(out2[1L], lbl("report.table.layout_transposed"), fixed = TRUE)
  expect_identical(as.data.frame(tab), tab$data)
  tr <- as.data.frame(tab, layout = "transposed")
  expect_identical(names(tr), c("t", "period", "date_end", tab$data$row_key))
  expect_error(format(tab, layout = "x"), class = "vofi_error_input")
})

test_that("vofi_sensitivity: print(), as.data.frame(), plot() f\u00fcr alle Methoden (13.4)", {
  for (m in c("tornado", "spider", "global")) {
    s <- wsh_sensitivity(m)
    out <- capture.output(res <- print(s))
    expect_identical(res, s)
    expect_match(out[1L], lbl(paste0("report.sensitivity.method_", m)), fixed = TRUE,
                 info = m)
    expect_true(any(grepl("3.726", out, fixed = TRUE)), info = m)
    expect_identical(as.data.frame(s), switch(m, tornado = s$results, spider = s$spider,
                                              global = s$global))
    expect_identical(as.data.frame(s, what = "params"), s$params)
  }
  out <- capture.output(print(wsh_sensitivity("tornado")))
  expect_true(any(grepl("Zahlungsfolge", out, fixed = TRUE)))
  expect_true(any(grepl("9.000", out, fixed = TRUE)))
  out <- capture.output(print(wsh_sensitivity("global")))
  expect_true(any(grepl("R\u00b2 = 0,830", out, fixed = TRUE)))
  empty <- wsh_sensitivity("tornado")
  empty$results <- NULL
  out <- capture.output(print(empty))
  expect_true(any(grepl(lbl("report.sensitivity.empty"), out, fixed = TRUE)))
  skip_if_not_installed("ggplot2")
  expect_s3_class(plot(wsh_sensitivity("spider")), "ggplot")
})

test_that("Snapshot einer Sensitivit\u00e4tsanalyse (15.6)", {
  skip_if_not(l10n_info()[["UTF-8"]])
  local_reproducible_output(width = 100)
  expect_snapshot(print(wsh_sensitivity("tornado")))
  expect_snapshot(print(wsh_sensitivity("global")))
})
