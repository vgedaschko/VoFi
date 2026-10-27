# Leistungsmessung der Engine (WS-D, WS-PERF; Spec 00 Abschnitt 9.10).
#
# Aufruf aus der Paketwurzel:
#   Rscript bench/bench_engine.R                        # installiertes Paket (byte-kompiliert)
#   VOFI_BENCH_LOAD_ALL=1 Rscript bench/bench_engine.R  # Quellbaum ueber pkgload::load_all()
#   VOFI_BENCH_QUICK=1 ...                              # weniger Wiederholungen
#   VOFI_BENCH_CHUNKS=1 ...                             # zusaetzlich Wirkung der Chunk-Groesse
#
# Gemessen werden (Median der verstrichenen Zeit und kleinste CPU-Zeit aus mehreren
# Wiederholungen, ohne Einlesen und Modellbau):
#   1. deterministischer Lauf mit 83 Perioden (Bauphase 24 Monate monatlich, Betrieb jaehrlich):
#      Ziel < 50 ms
#   2. Entnahme-Aequivalent zusaetzlich (Wiederholungslaeufe ueber den Instrument-Cache wie
#      kpi_withdrawal_equivalent(), Bisektion mit 40 Auswertungen): Ziel < 100 ms; dazu je
#      Wiederholungslauf (12.8: < 1 ms)
#   3. Engine-Anteil der MC 10.000 x 53 Perioden (5 Chunks zu 2.000 Laeufen mit vorgegebenen
#      Ziehungen inkl. Unterlassungsalternative, Invarianten, Kennzahlen und Baendern; ohne
#      Sampler, den bench_mc.R mit vofi_mc() misst): Budget der MC < 1,5 s
#   4. dasselbe mit 83 Perioden: Budget < 3 s
#   5. Design-Lauf mit 41 Zeilen (Tornado 20 Parameter x 2 + Basis), nur eine Kennzahl: < 1 s
#   6. Spitzenspeicher eines Chunks 2.000 x 83 (bands): Budget der MC 10.000 x 83 < 1 GB
# Ausgabe: Rechner und Last (loadavg vor und nach der Messung), Tabelle mit verstrichener Zeit,
# CPU-Zeit, Anteil der Speicherbereinigung (gc) an der CPU-Zeit, Ziel und Status (nach der
# CPU-Zeit); danach die Anteile eines MC-Chunks und des deterministischen Laufs nach
# Eigentuemern (Zahlungskomponenten WS-E, Kredit-Schritte WS-F, uebrige Engine WS-D).
# Auf geteilten Rechnern schwanken die Zeiten mit der Last um 20-40 %; massgeblich ist die
# kleinste CPU-Zeit bei niedriger Last. Der Pflichttest tests/testthat/test-engine-performance.R
# prueft dieselben Budgets mit Toleranzfaktor (VOFI_PERF_FACTOR, Default 4).
#
# Chunk-Groesse (VOFI_BENCH_CHUNKS=1): Die Engine rechnet je Chunk Vorbereitung, Kennzahlen und
# Unterlassungsalternative einmal; groessere Chunks verteilen diese festen Kosten auf mehr Laeufe
# und senken die Zahl der Speicherbereinigungen je Lauf, brauchen aber proportional mehr
# Speicher (9.9). Gemessen wird der Engine-Anteil MC 10.000 x 53 mit 2.000, 5.000 und 10.000
# Laeufen je Chunk (Default vofi.chunk_size = 2000L, R/zzz.R).

if (nzchar(Sys.getenv("VOFI_BENCH_LOAD_ALL"))) {
  suppressMessages(pkgload::load_all(".", quiet = TRUE))
} else {
  suppressMessages(library(vofi))
}
ns <- asNamespace("vofi")
get_int <- function(name) get(name, envir = ns)
quick <- nzchar(Sys.getenv("VOFI_BENCH_QUICK"))
reps <- function(n) if (quick) max(1L, n %/% 3L) else n

bench_scenario <- function(horizon, construction_months) {
  vofi_scenario(list(
    schema_version = 1L,
    meta = list(scenario_id = "bench", title = "Benchmark Engine"),
    project = list(perspective = "wu_privat", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = horizon),
    grid = list(construction_months = construction_months,
                construction_step_months = if (construction_months > 0L) 1L else 12L),
    components = list(
      inv = list(type = "custom_series", label = "Investition",
                 values = list(schedule = list("2027-01-01" = -1500000,
                                               "2027-07-01" = -500000))),
      rent = list(type = "recurring", category = "rent", amount_eur = 185000,
                  growth = list(ref = "market.rent_growth"), start_event = "completion"),
      opex = list(type = "recurring", category = "operating_cost", direction = "outflow",
                  amount_eur = 30000, growth = list(ref = "market.inflation"),
                  start_event = "completion"),
      maint = list(type = "recurring", category = "maintenance", direction = "outflow",
                   amount_eur = 20000, growth = 0.025, start_event = "completion"),
      admin = list(type = "recurring", category = "other_cost", direction = "outflow",
                   amount_eur = 8000, growth = 0.02, start_event = "completion")
    ),
    financing = list(
      ek = list(type = "equity", amount_eur = 500000, withdrawals_pa = 10000),
      bank = list(type = "annuity_loan", amount_eur = 1000000, rate_pa = 0.04, term_years = 30,
                  payments_per_year = 12L, fixed_years = 10,
                  followup_rate_pa = list(ref = "market.mortgage_rate")),
      kfw = list(type = "installment_loan", amount_eur = 300000, rate_pa = 0.02,
                 term_years = 20, payments_per_year = 4L),
      bul = list(type = "bullet_loan", amount_eur = 200000, rate_pa = 0.05, term_years = 10,
                 payments_per_year = 1L)
    ),
    accounts = list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08,
                    overdraft_limit_eur = 300000, penalty_spread_pa = 0.03,
                    min_liquidity_eur = 0,
                    surplus_order = c("od_repay", "dep_invest"),
                    deficit_order = c("dep_withdraw", "od_draw", "penalty_rate")),
    market = list(rent_growth = 0.015, inflation = 0.02, mortgage_rate = 0.045),
    analysis = list(kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value"))
  ))
}

load_avg <- function() {
  la <- tryCatch(readLines("/proc/loadavg", n = 1L, warn = FALSE), error = function(e) "")
  if (length(la) == 0L || !nzchar(la)) return("unbekannt")
  paste(strsplit(la, " ")[[1L]][1:3], collapse = " / ")
}

#' Messung: Median der verstrichenen Zeit, kleinste CPU-Zeit und gc-Anteil (ms)
measure <- function(expr_fun, n) {
  tt <- lapply(seq_len(n), function(i) {
    g0 <- gc.time()[[1L]]
    t0 <- proc.time()
    expr_fun()
    d <- proc.time() - t0
    c(elapsed = d[["elapsed"]], cpu = d[["user.self"]] + d[["sys.self"]],
      gc = gc.time()[[1L]] - g0)
  })
  m <- do.call(rbind, tt)
  best <- which.min(m[, "cpu"])
  1000 * c(elapsed = stats::median(m[, "elapsed"]), cpu = m[[best, "cpu"]],
           gc = m[[best, "gc"]])
}

fake_chunk_draws <- function(model, n) {
  g <- model$grid
  i <- seq_len(n)
  u <- (i - 0.5) / n
  st <- list("components.rent.amount_eur" = 185000 * (0.85 + 0.3 * u),
             "components.opex.amount_eur" = 30000 * (0.9 + 0.2 * rev(u)),
             "financing.kfw.rate_pa" = 0.015 + 0.01 * u)
  pa <- list("market.mortgage_rate" = matrix(0.03 + 0.03 * u, n, g$T + 1L),
             "market.rent_growth" = matrix(0.005 + 0.02 * rev(u), n, g$T + 1L))
  keys <- c(names(st), names(pa))
  targets <- data.frame(key = keys, target = keys,
                        kind = c(rep("static", length(st)), rep("process", length(pa))),
                        apply = "replace", stringsAsFactors = FALSE)
  get_int("new_vofi_draws")("mc", n = n, sims = i, blocks = seq_len(n %/% 200L),
                            block_size = 200L, static = st, paths = pa, targets = targets,
                            years = g$years)
}

quiet <- function(expr) {
  withCallingHandlers(expr, warning = function(w) invokeRestart("muffleWarning"),
                      message = function(m) invokeRestart("muffleMessage"))
}

run_chunk <- function(model, draws) {
  quiet(get_int("eng_run_draws")(model, draws, store = "bands",
                                 bands = c("net_position", "dep_balance", "od_balance")))
}

run_engine_mc <- function(model, n_sim = 10000L, chunk = 2000L) {
  draws <- fake_chunk_draws(model, chunk)
  for (k in seq_len(n_sim %/% chunk)) run_chunk(model, draws)
  invisible(NULL)
}

rebalance_bisection <- function(model, evals = 40L) {
  env <- get_int("eng_engine_env")(model, quiet = TRUE)
  ctx <- get_int("eng_context")(model, NULL, env)
  exo <- get_int("eng_flows")(model, ctx, env)
  core <- get_int("eng_balance")(model, ctx, exo$ledger, engine_env = env)
  target <- core$stocks$BS[1L, ctx$T + 1L] / 2
  delta <- ctx$by_period(ctx$grid$delta)
  run <- function() {
    lo <- -1e5
    hi <- 1e5
    for (k in seq_len(evals)) {
      mid <- (lo + hi) / 2
      r <- get_int("eng_balance")(model, ctx, exo$ledger, extra_out = -ctx$by_sim(mid) * delta,
                                  book = FALSE, engine_env = env)
      if (r$BS_T[1L] > target) lo <- mid else hi <- mid
    }
  }
  run()
  measure(run, reps(9L))
}

#' Anteile eines Laufs nach Eigentuemern (WS-E Komponenten, WS-F Kredit-Schritte, Rest WS-D)
shares <- function(model, draws, n) {
  env <- get_int("eng_engine_env")(model, quiet = TRUE)
  ctx <- get_int("eng_context")(model, draws, env)
  steps <- function() {
    for (id in names(model$instruments)) {
      k <- model$instruments[[id]]
      st <- k$def$init(k$spec, ctx)
      for (j in seq_len(ctx$T + 1L)) st <- k$def$step(st, j - 1L, ctx)$state
    }
  }
  total <- measure(function() {
    quiet(get_int("eng_run_draws")(model, draws, store = if (is.null(draws)) "full" else "bands"))
  }, n)[["cpu"]]
  flows <- measure(function() get_int("eng_flows")(model, ctx, env), n)[["cpu"]]
  inst <- measure(steps, n)[["cpu"]]
  c(gesamt = total, komponenten_ws_e = flows, kredit_schritte_ws_f = inst,
    engine_ws_d = total - flows - inst)
}

load_before <- load_avg()
m83 <- quiet(vofi_build(bench_scenario(61L, 24L)))
m53 <- quiet(vofi_build(bench_scenario(53L, 0L)))
m83y <- quiet(vofi_build(bench_scenario(83L, 0L)))
quiet_run <- function(m) quiet(vofi_run(m))
invisible(quiet_run(m83))
invisible(run_engine_mc(m53, 2000L))

reb <- rebalance_bisection(m83)
d83 <- fake_chunk_draws(m83y, 2000L)
invisible(run_chunk(m83y, d83))
invisible(gc(reset = TRUE))
invisible(run_chunk(m83y, d83))
peak_mb <- sum(gc()[, 6L])
meas <- rbind(
  measure(function() quiet_run(m83), reps(15L)),
  reb,
  reb / 40,
  measure(function() run_engine_mc(m53), reps(3L)),
  measure(function() run_engine_mc(m83y), reps(2L)),
  measure(function() {
    quiet(get_int("eng_run_draws")(m53, fake_chunk_draws(m53, 41L), store = "kpi",
                                   kpis = "delta_terminal_value"))
  }, reps(5L))
)
res <- data.frame(
  vorgang = c(sprintf("deterministischer Lauf, T = %d", m83$grid$T),
              "Entnahme-Aequivalent (40 Wiederholungslaeufe)",
              "je Wiederholungslauf (12.8)",
              "Engine-Anteil MC 10.000 x 53 (5 Chunks)",
              "Engine-Anteil MC 10.000 x 83 (5 Chunks)",
              "Design-Lauf 41 Zeilen (Tornado 20 x 2)",
              "Spitzenspeicher Chunk 2.000 x 83 (MB)"),
  ms = round(c(meas[, "elapsed"], peak_mb), 2),
  cpu_ms = round(c(meas[, "cpu"], NA), 2),
  gc_anteil = c(sprintf("%.0f %%", 100 * meas[, "gc"] / pmax(meas[, "cpu"], 1e-9)), ""),
  ziel = c(50, 100, 1, 1500, 3000, 1000, 1024),
  stringsAsFactors = FALSE
)
val <- ifelse(is.na(res$cpu_ms), res$ms, res$cpu_ms)
res$status <- ifelse(val <= res$ziel, "ok", "ueber Ziel")
load_after <- load_avg()
cat(sprintf("vofi %s, %s, %d Kerne, Last (1/5/15 min) vorher %s, nachher %s\n",
            as.character(utils::packageVersion("vofi")), R.version.string,
            parallel::detectCores(), load_before, load_after))
cat("Zeiten in ms: ms = Median verstrichen, cpu_ms = kleinste CPU-Zeit (Status danach)\n\n")
print(res, row.names = FALSE)

cat("\nAnteile (CPU-ms): MC-Chunk 2.000 x 53\n")
print(round(shares(m53, fake_chunk_draws(m53, 2000L), reps(3L)), 1))
cat("\nAnteile (CPU-ms): deterministischer Lauf, T = 83 (Kette eng_run_draws)\n")
print(round(shares(m83, NULL, reps(10L)), 1))

if (nzchar(Sys.getenv("VOFI_BENCH_CHUNKS"))) {
  cat("\nChunk-Groesse: Engine-Anteil MC 10.000 x 53 (CPU-ms, gc-Anteil)\n")
  for (cs in c(2000L, 5000L, 10000L)) {
    invisible(run_engine_mc(m53, cs, cs))
    x <- measure(function() run_engine_mc(m53, 10000L, cs), reps(3L))
    cat(sprintf("  %5d Laeufe je Chunk: %7.0f ms (gc %.0f %%)\n", cs, x[["cpu"]],
                100 * x[["gc"]] / x[["cpu"]]))
  }
}
