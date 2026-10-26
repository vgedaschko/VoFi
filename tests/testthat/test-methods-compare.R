# Tests für R/methods-compare.R (WS-H): Methoden der Klasse vofi_comparison (Spec 00
# Abschnitte 9.6, 12.6, 12.9, 13.3, 13.6).

test_that("print.vofi_comparison: Kennzahlen je Variante, Vergleichsregel, Rangfolge, Ampel", {
  cmp <- example_comparison()
  out <- capture.output(res <- print(cmp))
  expect_identical(res, cmp)
  expect_match(out[1L], "Variantenvergleich", fixed = TRUE)
  expect_true(any(grepl("Referenz base", out, fixed = TRUE)))
  expect_true(any(grepl("5.726", out, fixed = TRUE)))
  expect_true(any(grepl("2.000", out, fixed = TRUE)))
  expect_true(any(grepl("100,0 %", out, fixed = TRUE)))
  expect_true(any(grepl("1. a, 2. base", out, fixed = TRUE)))
  expect_true(any(grepl(lbl("report.traffic.rv_dependent"), out, fixed = TRUE)))
  expect_true(any(grepl(lbl("report.compare.comparable"), out, fixed = TRUE)))
})

test_that("Vergleichbarkeit: Befunde, ungleiche Nachsch\u00fcsse (9.6 Nr. 2)", {
  cmp <- example_comparison()
  findings <- data.frame(severity = c("error", "warning"),
                         code = c("validation.x", "validation.y"), path = NA_character_,
                         location = NA_character_, message = c("Horizont", "Konten"),
                         layer = 3L, variant = "a", stringsAsFactors = FALSE)
  cmp$comparability <- new_vofi_validation(findings)
  calls <- data.frame(variant = c("base", "a"), kpi = "sum_equity_calls", value = c(0, 3000))
  cmp$kpi_table <- rbind(cmp$kpi_table, calls)
  lines <- rep_cmp_comparability(cmp)
  expect_identical(lines[1L], lbl("report.compare.findings", errors = 1L, warnings = 1L,
                                  infos = 0L))
  expect_true(any(grepl("Horizont", lines, fixed = TRUE)))
  expect_true(any(grepl("3.000", lines, fixed = TRUE)))
})

test_that("summary(), format(), as.data.frame() eines Vergleichs", {
  self <- wsh_run(wsh_self_scenario())
  gas <- wsh_run(wsh_self_scenario(energy = 4500, capex = -12000, loan = 0, id = "gas"))
  cmp <- wsh_comparison(list(gas = gas, wp = self))
  s <- summary(cmp)
  expect_s3_class(s, "summary_vofi_comparison")
  expect_true(nrow(s$kpis) > 10L)
  out <- capture.output(print(s))
  expect_true(any(grepl(lbl("report.compare.restrictions_header"), out, fixed = TRUE)))
  expect_true(any(grepl(rep_restriction_label("burden"), out, fixed = TRUE)))
  m <- format(cmp)
  expect_identical(colnames(m), c(lbl("report.mc.col_kpi"), "gas", "wp"))
  expect_identical(nrow(format(cmp, kpis = "own_contribution")), 1L)
  expect_identical(as.data.frame(cmp), cmp$kpi_table)
  expect_identical(as.data.frame(cmp, what = "differences"), cmp$diff_stats)
  runs <- as.data.frame(cmp, what = "runs")
  expect_true(all(c("kpi", "variant", "sim", "value") %in% names(runs)))
  expect_equal(runs$value[runs$kpi == "monthly_saving_y1"],
               gas$kpis$monthly_burden_y1 - self$kpis$monthly_burden_y1)
  expect_identical(as.data.frame(cmp, what = "ranking"), cmp$ranking)
  expect_identical(nrow(as.data.frame(cmp, what = "conditional")), 0L)
  # bedingte Ergebnisse (9.11 Nr. 5)
  cmp$conditional <- data.frame(variant = "wp", branch = 1L, kpi = "delta_vs_reference",
                                mean = 1, q05 = 0, q50 = 1, q95 = 2, prob_better = 0.6)
  out2 <- capture.output(print(summary(cmp)))
  expect_true(any(grepl(lbl("report.compare.conditional_header"), out2, fixed = TRUE)))
})

test_that("plot.vofi_comparison liefert ein ggplot-Objekt", {
  skip_if_not_installed("ggplot2")
  p <- plot(example_comparison())
  expect_s3_class(p, "ggplot")
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("Snapshots von print() und summary() (15.6)", {
  skip_if_not(l10n_info()[["UTF-8"]])
  local_reproducible_output(width = 100)
  cmp <- example_comparison()
  expect_snapshot(print(cmp))
  expect_snapshot(print(summary(cmp)))
})
