# Tests für R/report-plot.R (WS-H): vofi_plot() für Ergebnis, Simulation, Vergleich und
# Sensitivität (Spec 00 Abschnitte 13.6, 14 Nr. 24; Konzept 5.5).

#' Grafik bauen (ggplot_build) und Objekt zurückgeben
build_ok <- function(p) {
  testthat::expect_s3_class(p, "ggplot")
  b <- ggplot2::ggplot_build(p)
  testthat::expect_true(length(b$data) >= 1L)
  invisible(b)
}

test_that("vofi_plot: alle Grafiktypen eines Ergebnisses", {
  skip_if_not_installed("ggplot2")
  x <- example_result()
  for (t in c("vermoegen", "differenz", "bestand", "finanzierung", "zahlungen",
              "belastung")) {
    build_ok(vofi_plot(x, type = t))
  }
  p <- vofi_plot(x)
  expect_identical(p$labels$title, lbl("report.plot.title_vermoegen"))
  # Differenzvermögen: Amortisationsmarke im Jahr der Kennzahl
  pd <- vofi_plot(x, type = "differenz")
  expect_identical(pd$labels$subtitle, lbl("report.plot.payback", year = 2031L))
  d <- ggplot2::ggplot_build(pd)$data[[2L]]
  expect_equal(max(d$y), x$kpis$delta_terminal_value)
  ex <- d$y[d$colour == unique(d$colour)[2L]]
  expect_equal(ex[length(ex)], x$kpis$delta_terminal_value_ex_rv)
  # Finanzierungsstruktur: Eigenkapital 30.000 und Kredite 40.000 + 30.000
  fs <- rep_financing_sources(x, 1L)
  expect_equal(sum(fs$value), 100000 + sum(pmax(x$ledger$values$od_draw, 0)))
  expect_equal(fs$value[fs$source == lbl("report.plot.src_equity")], 30000)
  # Selbstnutzer: gestapelte Belastung; Mietersicht: Warmmiete
  build_ok(vofi_plot(wsh_run(wsh_self_scenario()), type = "belastung"))
  build_ok(vofi_plot(wsh_run(wsh_tenant_scenario()), type = "warmmiete"))
  expect_error(vofi_plot(x, type = "warmmiete"), class = "vofi_error_input")
  expect_error(vofi_plot(x, type = "torte"), class = "vofi_error_input")
  expect_error(vofi_plot(x, sim = 2L), class = "vofi_error_input")
  expect_error(vofi_plot(1), class = "vofi_error_input")
})

test_that("vofi_plot: Simulation (Verteilung, F\u00e4cher, CDF, Konvergenz, Streuung, Tornado)", {
  skip_if_not_installed("ggplot2")
  mc <- wsh_mc()
  for (t in c("verteilung", "fan", "cdf", "konvergenz", "streu", "tornado")) {
    build_ok(vofi_plot(mc, type = t))
  }
  st <- mc$stats[mc$stats$kpi == "delta_terminal_value", ]
  p <- vofi_plot(mc)
  expect_match(p$labels$subtitle, fmt_pct(1 - st$p_neg), fixed = TRUE)
  build_ok(vofi_plot(mc, type = "verteilung", kpi = "roe_mirr", bins = 10L))
  build_ok(vofi_plot(mc, type = "fan", row_key = "dep_balance"))
  b <- ggplot2::ggplot_build(vofi_plot(mc, type = "fan"))
  expect_equal(b$data[[1L]]$ymin, unname(mc$bands$net_position["q05", ]))
  expect_error(vofi_plot(mc, type = "fan", row_key = "gibt_es_nicht"),
               class = "vofi_error_input")
  expect_error(vofi_plot(mc, kpi = "gibt_es_nicht"), class = "vofi_error_input")
  expect_error(vofi_plot(mc, type = "streu", input = "x"), class = "vofi_error_input")
  rc <- rep_rank_correlations(mc, mc$kpis$delta_terminal_value)
  expect_equal(rc$rho, 1)
  mc2 <- mc
  mc2$inputs <- NULL
  expect_error(vofi_plot(mc2, type = "tornado"), class = "vofi_error_input")
})

test_that("vofi_plot: Vergleich mit Wahrscheinlichkeit besser als Referenz", {
  skip_if_not_installed("ggplot2")
  cmp <- example_comparison()
  for (t in c("endwert", "differenz", "cdf", "bestand", "belastung")) {
    build_ok(vofi_plot(cmp, type = t))
  }
  expect_identical(vofi_plot(cmp, type = "differenz")$labels$subtitle,
                   lbl("report.plot.prob_better", variant = "a", baseline = "base", p = 1))
  # Vergleich zweier Simulationen: Histogramme je Variante
  mc <- wsh_mc()
  cmp2 <- cmp
  cmp2$results <- list(base = mc, a = mc)
  cmp2$differences <- list(delta_vs_reference = matrix(mc$kpis$delta_terminal_value / 10,
                                                       ncol = 1L, dimnames = list(NULL, "a")))
  for (t in c("endwert", "differenz", "cdf", "bestand")) build_ok(vofi_plot(cmp2, type = t))
  wp <- wsh_run(wsh_self_scenario())
  gas <- wsh_run(wsh_self_scenario(energy = 4500, capex = -12000, loan = 0, id = "gas"))
  build_ok(vofi_plot(wsh_comparison(list(gas = gas, wp = wp)), type = "belastung"))
  expect_error(vofi_plot(cmp, type = "differenz", kpi = "nix"), class = "vofi_error_input")
})

test_that("vofi_plot: Sensitivit\u00e4t (Tornado, Spider, Balken)", {
  skip_if_not_installed("ggplot2")
  for (m in c("tornado", "spider", "global")) {
    s <- wsh_sensitivity(m)
    for (t in c("tornado", "spider", "balken")) build_ok(vofi_plot(s, type = t))
  }
  expect_identical(vofi_plot(wsh_sensitivity("global"))$labels$title,
                   lbl("report.plot.title_balken", kpi = kpi_label("delta_terminal_value"),
                       measure = lbl("report.sensitivity.spearman")))
  build_ok(vofi_plot(wsh_sensitivity("global"), measure = "prcc"))
  expect_error(vofi_plot(wsh_sensitivity("global"), measure = "xyz"), class = "vofi_error_input")
  s <- wsh_sensitivity("tornado")
  s$spider <- NULL
  expect_error(vofi_plot(s, type = "spider"), class = "vofi_error_input")
})
