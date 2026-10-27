# Leistungsbudget der Engine (WS-D, WS-PERF; Spec 00 Abschnitte 9.10, 12.8, 15.6; Pflichttest
# mit skip_on_cran()).
#
# Gemessen wird die kleinste CPU-Zeit (Nutzer + System) aus mehreren Wiederholungen gegen das
# Budget aus 9.10 mal einem Toleranzfaktor für die Grundlast geteilter Rechner:
#   VOFI_PERF_FACTOR  Faktor auf alle Zeitbudgets (Default 4: geteilte VMs und CI mit
#                     schwankender Last; Abnahme auf einem ruhigen Rechner mit 1). Der
#                     Speicherbudget hat keinen Faktor.
#   VOFI_SKIP_PERF    "true" überspringt alle Leistungstests.
# Szenario wie bench/bench_engine.R (wsd_bench_scenario()): 83 Perioden (Bauphase 24 Monate
# monatlich, Betrieb jährlich) bzw. 53 und 83 Jahresperioden, vier Kredite (Annuität mit
# Anschlusszins, Raten- und Endfälligkeitsdarlehen), Ausgleich mit Strafzinstranche. Die MC wird
# als Engine-Anteil je Chunk (2.000 Läufe mit vorgegebenen Ziehungen, wsp_draws()) gegen ein
# Fünftel des MC-Budgets gemessen (10.000 Läufe = 5 Chunks); den Sampler (WS-C) und vofi_mc()
# bzw. vofi_compare() (WS-G) prüfen test-mc.R und test-compare.R, die Tabelle gegen alle Budgets
# geben bench/bench_engine.R und bench/bench_mc.R aus.

perf_factor <- function() {
  f <- suppressWarnings(as.double(Sys.getenv("VOFI_PERF_FACTOR", "4")))
  if (is.na(f) || f <= 0) 4 else f
}

perf_skip <- function() {
  skip_on_cran()
  skip_on_covr()
  skip_if(identical(tolower(Sys.getenv("VOFI_SKIP_PERF")), "true"), "VOFI_SKIP_PERF")
}

#' Kleinste CPU-Zeit in ms aus `reps` Wiederholungen
perf_cpu_ms <- function(f, reps = 5L) {
  tt <- vapply(seq_len(reps), function(i) {
    t0 <- proc.time()
    f()
    d <- proc.time() - t0
    d[["user.self"]] + d[["sys.self"]]
  }, double(1))
  1000 * min(tt)
}

perf_quiet <- function(expr) suppressMessages(suppressWarnings(expr))

perf_chunk <- function(model, draws) {
  perf_quiet(eng_run_draws(model, draws, store = "bands",
                           bands = c("net_position", "dep_balance", "od_balance")))
}

test_that("9.10: deterministischer Lauf mit 83 Perioden (< 50 ms)", {
  perf_skip()
  model <- perf_quiet(vofi_build(wsd_bench_scenario(61L, 24L)))
  expect_identical(model$grid$T, 83L)
  run <- function() perf_quiet(vofi_run(model))
  invisible(run())
  ms <- perf_cpu_ms(function() for (i in 1:5) run()) / 5
  expect_lt(ms, 50 * perf_factor(), label = sprintf("deterministischer Lauf %.1f ms", ms))
})

test_that("9.10, 12.8: Entnahme-Äquivalent, 40 Wiederholungsläufe (< 100 ms, je Lauf < 1 ms)", {
  perf_skip()
  model <- perf_quiet(vofi_build(wsd_bench_scenario(61L, 24L)))
  p <- perf_quiet(wsd_parts(model))
  delta <- p$ctx$by_period(p$ctx$grid$delta)
  rebal <- function() {
    for (k in seq_len(40L)) {
      eng_balance(model, p$ctx, p$exo$ledger, extra_out = -p$ctx$by_sim(100 * k) * delta,
                  book = FALSE, engine_env = p$env)
    }
  }
  invisible(rebal())
  ms <- perf_cpu_ms(rebal)
  expect_lt(ms, 100 * perf_factor(), label = sprintf("40 Wiederholungsläufe %.1f ms", ms))
  expect_lt(ms / 40, 1 * perf_factor(), label = sprintf("je Wiederholungslauf %.2f ms", ms / 40))
})

test_that("9.10: Design-Lauf mit 41 Zeilen und einer Kennzahl (< 1 s)", {
  perf_skip()
  model <- perf_quiet(vofi_build(wsd_bench_scenario(53L, 0L)))
  d <- wsp_draws(model, 41L)
  run <- function() {
    perf_quiet(eng_run_draws(model, d, store = "kpi", kpis = "delta_terminal_value"))
  }
  invisible(run())
  ms <- perf_cpu_ms(run, 3L)
  expect_lt(ms, 1000 * perf_factor(), label = sprintf("Design-Lauf %.0f ms", ms))
})

test_that("9.10: Engine-Anteil MC 10.000 x 53 (Chunk 2.000 x 53 < 1,5 s / 5)", {
  perf_skip()
  model <- perf_quiet(vofi_build(wsd_bench_scenario(53L, 0L)))
  d <- wsp_draws(model, 2000L)
  invisible(perf_chunk(model, d))
  ms <- perf_cpu_ms(function() perf_chunk(model, d), 3L)
  expect_lt(ms, 1500 / 5 * perf_factor(), label = sprintf("MC-Chunk 2.000 x 53 %.0f ms", ms))
})

test_that("9.10: Engine-Anteil MC 10.000 x 83 (Chunk 2.000 x 83 < 3 s / 5), Speicher < 1 GB", {
  perf_skip()
  model <- perf_quiet(vofi_build(wsd_bench_scenario(83L, 0L)))
  expect_identical(model$grid$T, 83L)
  d <- wsp_draws(model, 2000L)
  invisible(perf_chunk(model, d))
  invisible(gc(reset = TRUE))
  ms <- perf_cpu_ms(function() perf_chunk(model, d), 2L)
  peak_mb <- sum(gc()[, 6L])
  expect_lt(ms, 3000 / 5 * perf_factor(), label = sprintf("MC-Chunk 2.000 x 83 %.0f ms", ms))
  expect_lt(peak_mb, 1024, label = sprintf("Spitzenspeicher %.0f MB", peak_mb))
})
