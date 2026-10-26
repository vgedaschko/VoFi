# Tests für R/methods-result.R (WS-H): print(), summary(), format(), as.data.frame(), plot()
# für vofi_result, Hinweise und Ampel im Basisfall (Spec 00 Abschnitte 12.3a, 12.9, 13.1, 13.6).

test_that("print.vofi_result: Kopf, Kopf-Kennzahlen, Tabelle, Hinweise", {
  x <- example_result()
  out <- capture.output(res <- print(x))
  expect_identical(res, x)
  expect_match(out[1L], "VoFi-Ergebnis: testkit (oracle_a), Variante base", fixed = TRUE)
  kpi_line <- which(out_has(lbl("report.print.primary"), out))
  expect_length(kpi_line, 1L)
  expect_match(out[kpi_line], "3.726,41", fixed = TRUE)
  expect_true(any(grepl("38.504,63", out, fixed = TRUE)))
  expect_true(any(grepl("34.778,22", out, fixed = TRUE)))
  expect_true(any(grepl("5,12 %", out, fixed = TRUE)))
  # Primärkennzahl steht vor allen anderen Kennzahlen
  expect_lt(kpi_line, grep(paste0("^  ", kpi_label("terminal_value"), " "), out)[1L])
  expect_true(any(out_has(lbl("report.notes.tax_none"), out)))
  expect_true(any(out_has(lbl("report.tax_warning_wu_kapges"), out)))
  expect_true(any(out_has(lbl("report.print.checks_ok"), out)))
  expect_error(print(x, sim = 2L), class = "vofi_error_input")
})

test_that("print.vofi_result: Walking Skeleton (Anhang A) und lange Raster gek\u00fcrzt", {
  res <- wsh_run(vofi_read_scenario(vofi_example("skeleton")))
  out <- capture.output(print(res))
  for (v in c("52.830,80", "42.448,32", "10.382,48")) {
    expect_true(any(grepl(v, out, fixed = TRUE)), info = v)
  }
  out2 <- capture.output(print(example_result(), max_periods = 4L))
  expect_true(any(grepl("...", out2, fixed = TRUE)))
})

test_that("Hinweise: Steuerwarnhinweise je Regime, Markierungen, Bestandsprojekte", {
  x <- example_result()
  x$meta$tax_regime <- "privat_vermieter"
  expect_true(lbl("report.tax_warning_privat_vermieter") %in% rep_result_notes(x))
  x$meta$tax_regime <- "wu_kommunal"
  expect_false(any(grepl("Steuerwarnhinweis", rep_result_notes(x), fixed = TRUE)))
  x$meta$tax_module <- "flat"
  expect_false(lbl("report.notes.tax_none") %in% rep_result_notes(x))
  x$flags$shortfall <- TRUE
  x$meta$notes <- c("report.flags.arbitrage", "freier Vermerk")
  n <- rep_result_notes(x)
  expect_true(lbl("report.flags.shortfall") %in% n)
  expect_true(lbl("report.flags.arbitrage") %in% n)
  expect_true("freier Vermerk" %in% n)
  x$spec$project$project_type <- "sanierung_eh"
  expect_true(any(grepl(lbl("kpi.notes.contains_existing"), rep_result_notes(x), fixed = TRUE)))
})

test_that("Ampel im Basisfall (12.9 base_only): gelb/rot, Restwertregel, K.-o., Bestand", {
  x <- example_result()
  tl <- rep_traffic_light(x)
  expect_identical(tl$level, "yellow")
  expect_identical(tl$basis, "base_only")
  expect_true(tl$rv_dependent)
  expect_true("report.traffic.no_robustness" %in% tl$notes)
  x$kpis$delta_terminal_value <- -1
  expect_identical(rep_traffic_light(x)$level, "red")
  expect_false(rep_traffic_light(x)$rv_dependent)
  # Restriktion verletzt: K.-o.-Kennzeichen; nicht prüfbar: Hinweis
  x <- example_result()
  x$spec$analysis$restrictions <- c("dscr", "liquidity")
  x$kpis$restriction_dscr <- 1
  x$kpi_na$restriction_dscr <- NA_character_
  tl <- rep_traffic_light(x)
  expect_identical(tl$restrictions$ko, c(TRUE, FALSE))
  expect_true(any(grepl(rep_restriction_label("liquidity"), tl$notes, fixed = TRUE)))
  expect_true(any(grepl(rep_restriction_label("dscr"), rep_traffic_lines(tl), fixed = TRUE)))
  # vorhandenes Feld traffic_light hat Vorrang
  x$traffic_light <- list(level = "green", stage1 = "green", basis = "mc", notes = character(0))
  expect_identical(rep_traffic_light(x)$level, "green")
  # Bestandsprojekt (Primärkennzahl delta_vs_reference): Ampel nur im Vergleich
  y <- example_result()
  y$meta$primary_kpi <- "delta_vs_reference"
  expect_null(rep_traffic_light(y))
})

test_that("summary.vofi_result: Kennzahlen nach Restwertbezug, Ampel, Reihen", {
  s <- summary(example_result())
  expect_s3_class(s, "summary_vofi_result")
  expect_true(all(c("with", "without", "independent") %in% s$kpis$rv))
  expect_identical(s$primary, "delta_terminal_value")
  out <- capture.output(print(s))
  expect_true(any(grepl(lbl("report.summary.rv_without"), out, fixed = TRUE)))
  expect_true(any(grepl(lbl("vocab.na_reasons.equity_lost"), out, fixed = TRUE)))
  self <- wsh_run(wsh_self_scenario())
  s2 <- summary(self)
  expect_true("monthly_burden" %in% s2$series$kpi)
  out2 <- capture.output(print(s2))
  expect_true(any(grepl(lbl("report.summary.series_header"), out2, fixed = TRUE)))
  # Haushaltsmodus: Klartext der Haushaltssicht
  expect_identical(s2$plain, attr(vofi_household_view(self), "summary")$text)
  expect_true(any(grepl(lbl("report.summary.plain_header"), out2, fixed = TRUE)))
  expect_length(s$plain, 0L)
  expect_error(summary(example_result(), sim = 3L), class = "vofi_error_input")
})

test_that("format.vofi_result und as.data.frame.vofi_result", {
  x <- example_result()
  m <- format(x)
  expect_true(is.matrix(m) && is.character(m))
  expect_identical(colnames(m)[1L], lbl("report.table.position"))
  expect_true("-100.000,00" %in% m[, "t0"])
  mt <- format(x, layout = "transposed", detail = "full")
  expect_identical(mt[, 1L], x$grid$label)
  expect_identical(as.data.frame(x), vofi_ledger(x))
  expect_identical(as.data.frame(x, format = "wide"), vofi_ledger(x, format = "wide"))
  expect_identical(nrow(as.data.frame(x, vat = TRUE)), nrow(vofi_ledger(x)))
  k <- as.data.frame(x, what = "kpis")
  expect_identical(k, vofi_kpis(x))
  kw <- as.data.frame(x, what = "kpis", format = "wide")
  expect_identical(names(kw)[1L], "sim")
  expect_equal(kw$terminal_value, x$kpis$terminal_value)
  expect_error(as.data.frame(x, what = "alles"), class = "vofi_error_input")
})

test_that("plot.vofi_result liefert ein ggplot-Objekt", {
  skip_if_not_installed("ggplot2")
  p <- plot(example_result())
  expect_s3_class(p, "ggplot")
  expect_silent(ggplot2::ggplot_build(p))
  expect_s3_class(plot(example_result(), type = "bestand"), "ggplot")
})

test_that("Snapshots von print() und summary() (13.6, 15.6)", {
  skip_if_not(l10n_info()[["UTF-8"]])
  local_reproducible_output(width = 100)
  x <- example_result()
  expect_snapshot(print(x))
  expect_snapshot(print(summary(x)))
})
