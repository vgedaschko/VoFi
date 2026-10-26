# Leistungsbudget der Engine (WS-D; Spec 00 Abschnitte 9.10, 12.8, 15.6; Pflichttest mit
# skip_on_cran()). Gemessen wird die kleinste CPU-Zeit (Nutzer + System) aus mehreren
# Wiederholungen gegen das Budget aus 9.10 mal einem Toleranzfaktor für die Grundlast geteilter
# Rechner (Umgebungsvariable VOFI_PERF_FACTOR, Default 4; VOFI_SKIP_PERF = true überspringt).
# Szenario wie bench/bench_engine.R: 83 Perioden (Bauphase 24 Monate monatlich, Betrieb jährlich),
# vier Kredite (Annuität mit Anschlusszins, Raten- und Endfälligkeitsdarlehen), Ausgleich mit
# Strafzinstranche. Die MC wird als Engine-Anteil eines Chunks (2.000 Läufe x 53 Perioden mit
# vorgegebenen Ziehungen) gemessen; der Sampler (WS-C) und vofi_mc() (WS-G) messen bench_mc.R
# bzw. die Tests von WS-G.

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

perf_draws <- function(model, n) {
  g <- model$grid
  u <- (seq_len(n) - 0.5) / n
  st <- list("components.rent.amount_eur" = 185000 * (0.85 + 0.3 * u),
             "financing.kfw.rate_pa" = 0.015 + 0.01 * u)
  pa <- list("market.mortgage_rate" = matrix(0.03 + 0.03 * u, n, g$T + 1L),
             "market.rent_growth" = matrix(0.005 + 0.02 * rev(u), n, g$T + 1L))
  keys <- c(names(st), names(pa))
  targets <- data.frame(key = keys, target = keys,
                        kind = c(rep("static", length(st)), rep("process", length(pa))),
                        apply = "replace", stringsAsFactors = FALSE)
  new_vofi_draws("mc", n = n, sims = seq_len(n), blocks = seq_len(max(1L, n %/% 200L)),
                 block_size = min(n, 200L), static = st, paths = pa, targets = targets,
                 years = g$years)
}

test_that("9.10: deterministischer Lauf mit 83 Perioden", {
  perf_skip()
  model <- suppressMessages(vofi_build(wsd_bench_scenario(61L, 24L)))
  expect_identical(model$grid$T, 83L)
  run <- function() suppressMessages(suppressWarnings(vofi_run(model)))
  invisible(run())
  ms <- perf_cpu_ms(run)
  expect_lt(ms, 50 * perf_factor(), label = sprintf("deterministischer Lauf %.0f ms", ms))
})

test_that("9.10, 12.8: Entnahme-Äquivalent mit 40 Wiederholungsläufen (Instrument-Cache)", {
  perf_skip()
  model <- suppressMessages(vofi_build(wsd_bench_scenario(61L, 24L)))
  p <- suppressMessages(suppressWarnings(wsd_parts(model)))
  delta <- p$ctx$by_period(p$ctx$grid$delta)
  rebal <- function() {
    for (k in seq_len(40L)) {
      eng_balance(model, p$ctx, p$exo$ledger, extra_out = -p$ctx$by_sim(100 * k) * delta,
                  book = FALSE, engine_env = p$env)
    }
  }
  invisible(rebal())
  ms <- perf_cpu_ms(rebal)
  expect_lt(ms, 100 * perf_factor(), label = sprintf("40 Wiederholungsläufe %.0f ms", ms))
})

test_that("9.10: Design-Lauf mit 41 Zeilen und einer Kennzahl", {
  perf_skip()
  model <- suppressMessages(vofi_build(wsd_bench_scenario(53L, 0L)))
  d <- perf_draws(model, 41L)
  run <- function() {
    suppressMessages(suppressWarnings(
      eng_run_draws(model, d, store = "kpi", kpis = "delta_terminal_value")
    ))
  }
  invisible(run())
  ms <- perf_cpu_ms(run, 3L)
  expect_lt(ms, 1000 * perf_factor(), label = sprintf("Design-Lauf %.0f ms", ms))
})

test_that("9.10: Engine-Anteil eines MC-Chunks (2.000 x 53, Budget 1,5 s je 10.000 Läufe)", {
  perf_skip()
  model <- suppressMessages(vofi_build(wsd_bench_scenario(53L, 0L)))
  d <- perf_draws(model, 2000L)
  run <- function() {
    suppressMessages(suppressWarnings(
      eng_run_draws(model, d, store = "bands", bands = c("net_position", "dep_balance"))
    ))
  }
  ms <- perf_cpu_ms(run, 2L)
  expect_lt(ms, 1500 / 5 * perf_factor(), label = sprintf("MC-Chunk %.0f ms", ms))
})
