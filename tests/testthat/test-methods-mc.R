# Tests für R/methods-mc.R (WS-H): Methoden der Klasse vofi_mc_result (Spec 00 Abschnitte
# 12.7, 13.2, 13.6).

test_that("print.vofi_mc_result: Statistik mit SE, Quantilen und Basisfall", {
  mc <- wsh_mc()
  out <- capture.output(res <- print(mc))
  expect_identical(res, mc)
  expect_match(out[1L], "Monte-Carlo-Simulation", fixed = TRUE)
  expect_match(out[2L], "200", fixed = TRUE)
  expect_true(any(grepl(lbl("report.mc.col_det"), out, fixed = TRUE)))
  expect_true(any(grepl("P95", out, fixed = TRUE)))
  # Basisfall der Primärkennzahl, Anteil negativer Werte
  expect_true(any(grepl("3.726", out, fixed = TRUE)))
  expect_true(any(grepl(fmt_pct(mc$stats$p_neg[mc$stats$kpi == "delta_terminal_value"], 1),
                        out, fixed = TRUE)))
  expect_true(any(grepl(lbl("report.mc.se_single"), out, fixed = TRUE)))
})

test_that("Hinweise zum Standardfehler (12.7): ein Replikat, grob, Konvergenz", {
  mc <- wsh_mc()
  expect_true(lbl("report.mc.se_single") %in% rep_mc_se_notes(mc))
  mc$meta$replicates <- 5L
  expect_true(lbl("report.mc.se_rough", r = 5L) %in% rep_mc_se_notes(mc))
  mc$meta$replicates <- 50L
  n <- rep_mc_se_notes(mc)
  expect_false(any(grepl("grob", n, fixed = TRUE)))
  expect_true(any(grepl(lbl("report.mc.converged", count = 0L, n = nrow(mc$stats)), n,
                        fixed = TRUE)))
})

test_that("summary.vofi_mc_result: Risiko in Worten (Konzept 4.5) und Entscheidungsknoten", {
  mc <- wsh_mc()
  s <- summary(mc)
  expect_s3_class(s, "summary_vofi_mc_result")
  st <- mc$stats[mc$stats$kpi == "delta_terminal_value", ]
  k <- as.integer(round(10 * (1 - st$p_neg)))
  expect_identical(s$risk[1L], lbl("report.mc.risk_positive", count = k,
                                   label = kpi_label("delta_terminal_value")))
  expect_true(any(grepl(rep_fmt_value(st$q05, "EUR", 0), s$risk, fixed = TRUE)))
  expect_true(any(grepl(rep_fmt_value(st$es05, "EUR", 0), s$risk, fixed = TRUE)))
  out <- capture.output(print(s))
  expect_true(any(grepl(lbl("report.mc.risk_header"), out, fixed = TRUE)))
  expect_true(any(grepl(lbl("report.mc.checks_ok"), out, fixed = TRUE)))
  # bedingte Statistik bei Entscheidungsknoten (9.11)
  mc$decision <- list(funding_id = "kfw", fallback_variant = "ohne", key = "kfw",
                      p_approval = 0.8, share_approved = 0.8,
                      stats_approved = mc$stats, stats_fallback = mc$stats)
  mc$traffic_light <- list(level = "green", stage1 = "green", basis = "mc",
                           restrictions = data.frame(code = "dscr", violated_base = FALSE,
                                                     prob = 0.1, year = NA, value = NA,
                                                     threshold = 1.2, ko = FALSE),
                           notes = character(0))
  out2 <- capture.output(print(summary(mc)))
  expect_true(any(grepl("kfw", out2, fixed = TRUE)))
  expect_true(any(grepl(lbl("report.traffic.level_green"), out2, fixed = TRUE)))
})

test_that("format(), as.data.frame() und quantile() einer Simulation", {
  mc <- wsh_mc()
  m <- format(mc)
  expect_true(is.matrix(m))
  expect_identical(nrow(m), nrow(mc$stats))
  expect_identical(nrow(format(mc, kpis = "roe_mirr")), 1L)
  expect_identical(as.data.frame(mc), mc$kpis)
  expect_identical(as.data.frame(mc, what = "stats"), mc$stats)
  expect_identical(as.data.frame(mc, what = "inputs"), mc$inputs)
  expect_identical(as.data.frame(mc, what = "features"), mc$features)
  b <- as.data.frame(mc, what = "bands")
  expect_identical(nrow(b), 3L * 6L * 6L)
  expect_identical(unique(b$row_key), names(mc$bands))
  i <- b$row_key == "net_position" & b$stat == "q50"
  expect_equal(b$value[i], unname(mc$bands$net_position["q50", ]))
  mc2 <- mc
  mc2$bands <- list()
  expect_identical(nrow(as.data.frame(mc2, what = "bands")), 0L)
  q <- quantile(mc)
  expect_identical(colnames(q), c("5%", "25%", "50%", "75%", "95%"))
  expect_equal(q["terminal_value", "50%"],
               stats::quantile(mc$kpis$terminal_value, 0.5, type = 7, names = FALSE))
  q2 <- quantile(mc, probs = 0.1, kpi = "roe_mirr")
  expect_identical(dim(q2), c(1L, 1L))
  expect_error(quantile(mc, kpi = "gibt_es_nicht"), class = "vofi_error_input")
  expect_error(quantile(mc, probs = 2), class = "vofi_error_input")
  expect_error(as.data.frame(mc, what = "nix"), class = "vofi_error_input")
})

test_that("plot.vofi_mc_result liefert ein ggplot-Objekt", {
  skip_if_not_installed("ggplot2")
  p <- plot(wsh_mc())
  expect_s3_class(p, "ggplot")
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("Snapshots von print() und summary() (15.6)", {
  skip_if_not(l10n_info()[["UTF-8"]])
  local_reproducible_output(width = 100)
  mc <- wsh_mc()
  expect_snapshot(print(mc))
  expect_snapshot(print(summary(mc)))
})
