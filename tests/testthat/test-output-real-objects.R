# Integrator (Stufe II): Ausgabeschicht von WS-H mit den echten Ergebnisobjekten von WS-G
# (Spec 00 Abschnitte 13.2-13.4, 13.6). WS-H wurde gegen die Fixtures example_mc_result() und
# example_comparison() (helper-fixtures.R) gebaut; diese Tests prüfen, dass Fixtures und echte
# Objekte dieselbe Struktur haben und alle Pflichtmethoden mit den echten Objekten laufen.

int_grob_model <- function() {
  sc <- vofi_read_scenario(vofi_example("grob_lehrbuch_a"))
  wsg_quiet(vofi_build(sc))
}

int_build_ok <- function(p) {
  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
}

test_that("vofi_mc_result: Struktur wie die Fixture, Methoden laufen (13.2, 13.6)", {
  mc <- wsg_quiet(vofi_mc(int_grob_model(), n_sim = 400L, seed = 1L))
  fx <- wsg_quiet(example_mc_result(400L))
  expect_setequal(names(mc), names(fx))
  expect_identical(names(mc$stats), names(fx$stats))
  expect_true(all(names(fx$meta) %in% names(mc$meta)),
              info = utl_collapse(setdiff(names(fx$meta), names(mc$meta))))
  expect_identical(names(mc$traffic_light), names(fx$traffic_light))
  expect_identical(rownames(mc$bands$net_position), rownames(fx$bands$net_position))
  expect_identical(names(mc$run_index), names(fx$run_index))
  out <- capture.output(res <- print(mc))
  expect_identical(res, mc)
  expect_true(any(out_has(kpi_label("delta_terminal_value"), out)))
  s <- summary(mc)
  expect_s3_class(s, "summary_vofi_mc_result")
  out <- capture.output(print(s))
  expect_true(any(out_has(lbl("report.traffic.header"), out)))
  expect_true(any(out_has(lbl("report.mc.risk_header"), out)))
  expect_identical(nrow(format(mc)), nrow(mc$stats))
  for (w in c("kpis", "inputs", "features", "stats")) {
    expect_identical(as.data.frame(mc, what = w), mc[[w]], info = w)
  }
  b <- as.data.frame(mc, what = "bands")
  expect_identical(nrow(b), length(mc$bands) * 6L * (mc$grid$T + 1L))
  q <- quantile(mc, kpi = "delta_terminal_value")
  expect_equal(unname(q[1L, "50%"]), mc$stats$q50[mc$stats$kpi == "delta_terminal_value"])
  expect_s3_class(vofi_table(mc, sim = "p50"), "vofi_table")
  expect_s3_class(vofi_table(mc, sim = 7L), "vofi_table")
  f <- withr::local_tempfile(fileext = ".xlsx")
  expect_identical(vofi_export_excel(mc, f), f)
  skip_if_not_installed("ggplot2")
  for (ty in c("verteilung", "fan", "cdf", "konvergenz", "streu", "tornado")) {
    int_build_ok(plot(mc, type = ty))
  }
})

test_that("vofi_mc_result mit Entscheidungsknoten: bedingte Statistik in summary() (9.11)", {
  mc <- wsg_quiet(vofi_mc(wsg_quiet(vofi_build(wsg_decision_scenario(n_sim = 400L))),
                          n_sim = 400L, seed = 1L))
  out <- capture.output(print(summary(mc)))
  expect_true(any(out_has(lbl("report.mc.decision_header", funding = "f", fallback = "ohne"),
                          out)))
  f <- withr::local_tempfile(fileext = ".xlsx")
  expect_identical(vofi_export_excel(mc, f), f)
})

test_that("vofi_comparison: Struktur wie die Fixture, Methoden laufen (13.3, 13.6)", {
  sc <- wsg_scenario(variants = wsg_variant_a(components.z.values = wsg_z_a))
  cmp <- wsg_quiet(vofi_compare(sc))
  fx <- example_comparison()
  expect_setequal(names(cmp), names(fx))
  for (f in c("kpi_table", "diff_stats", "ranking", "traffic_light", "restrictions")) {
    expect_identical(names(cmp[[f]]), names(fx[[f]]), info = f)
  }
  expect_true(all(names(fx$meta) %in% names(cmp$meta)))
  expect_s3_class(cmp$diff_table, "vofi_table")
  # MC-Vergleich mit gemeinsamen Zufallszahlen
  scm <- wsg_scenario(final = list(ref = "shared.x"), shared = list(x = 30000),
                      variants = wsg_variant_a(components.z.values = list(
                        -100000, 12000, 9000, 9000, 9000, list(ref = "shared.x"))),
                      stochastic = list(settings = list(seed = 1L, block_size = 200L),
                                        parameters = list(x = list(
                                          target = "shared.x", dist = "uniform",
                                          min = 20000, max = 40000))))
  cmm <- wsg_quiet(vofi_compare(scm, n_sim = 200L))
  expect_s3_class(cmm$results$a, "vofi_mc_result")
  for (x in list(cmp, cmm)) {
    out <- capture.output(res <- print(x))
    expect_identical(res, x)
    expect_true(any(grepl("1. a, 2. base", out, fixed = TRUE)))
    out <- capture.output(print(summary(x)))
    expect_true(any(out_has(lbl("report.compare.traffic_line", variant = "a",
                                level = lbl(paste0("report.traffic.level_",
                                                   x$traffic_light$level[1L])),
                                basis = lbl(paste0("report.traffic.basis_",
                                                   x$traffic_light$basis[1L]))), out)))
    expect_identical(colnames(format(x)), c(lbl("report.mc.col_kpi"), "base", "a"))
    for (w in c("kpis", "differences", "runs", "ranking", "traffic_light", "restrictions")) {
      expect_s3_class(as.data.frame(x, what = w), "data.frame")
    }
    f <- withr::local_tempfile(fileext = ".xlsx")
    expect_identical(vofi_export_excel(x, f), f)
  }
  runs <- as.data.frame(cmm, what = "runs")
  expect_identical(nrow(runs[runs$kpi == "delta_vs_reference", ]), 200L)
  skip_if_not_installed("ggplot2")
  for (x in list(cmp, cmm)) {
    for (ty in c("endwert", "differenz", "cdf", "bestand", "belastung")) {
      int_build_ok(plot(x, type = ty))
    }
  }
})

test_that("vofi_sensitivity und vofi_solution: Methoden mit echten Objekten (13.4)", {
  m <- int_grob_model()
  fx <- wsh_sensitivity("tornado")
  for (meth in c("tornado", "spider")) {
    s <- wsg_quiet(vofi_sensitivity(m, method = meth))
    expect_setequal(names(s), names(fx))
    expect_identical(names(s$params), names(fx$params))
    out <- capture.output(res <- print(s))
    expect_identical(res, s)
    expect_true(any(out_has(lbl(paste0("report.sensitivity.method_", meth)), out)))
    expect_s3_class(as.data.frame(s), "data.frame")
  }
  # global aus einer Simulation mit nur einer Eingangsgröße (rw): einzeilige Tabelle
  mc <- wsg_quiet(vofi_mc(m, n_sim = 400L, seed = 1L))
  g <- wsg_quiet(vofi_sensitivity(mc, method = "global"))
  expect_identical(nrow(g$global), 1L)
  expect_identical(names(g$global), names(wsh_sensitivity("global")$global))
  out <- capture.output(print(g))
  expect_true(any(grepl("rw", out, fixed = TRUE)))
  sol <- wsg_quiet(vofi_solve(m, what = "breakeven", param = "accounts.deposit_rate_pa",
                              kpi = "delta_terminal_value"))
  expect_s3_class(sol, "vofi_solution")
  out <- capture.output(res <- print(sol))
  expect_identical(res, sol)
  expect_gt(length(out), 0L)
  skip_if_not_installed("ggplot2")
  int_build_ok(plot(wsg_quiet(vofi_sensitivity(m))))
  int_build_ok(plot(g))
})
