# Leistungsmessung der Engine (WS-D, Spec 00 Abschnitt 9.10).
#
# Aufruf aus der Paketwurzel:
#   Rscript bench/bench_engine.R            # installiertes Paket vofi (byte-kompiliert)
#   VOFI_BENCH_LOAD_ALL=1 Rscript bench/bench_engine.R   # Quellbaum ueber pkgload::load_all()
#
# Gemessen werden (Median aus mehreren Wiederholungen, ohne Einlesen):
#   1. deterministischer Lauf mit 83 Perioden (Bauphase 24 Monate monatlich, Betrieb jaehrlich):
#      Ziel < 50 ms
#   2. Entnahme-Aequivalent zusaetzlich (Wiederholungslaeufe ueber den Instrument-Cache wie
#      kpi_withdrawal_equivalent(), Bisektion mit 40 Auswertungen): Ziel < 100 ms
#   3. Engine-Anteil der MC 10.000 x 53 Perioden (5 Chunks zu 2.000 Laeufen mit vorgegebenen
#      Ziehungen inkl. Unterlassungsalternative, Invarianten, Kennzahlen und Baendern; ohne
#      Sampler, der in bench_mc.R von WS-G gemessen wird): Budget der MC < 1,5 s
#   4. dasselbe mit 83 Perioden: Budget < 3 s
#   5. Design-Lauf mit 41 Zeilen (Tornado 20 Parameter x 2 + Basis), nur eine Kennzahl:
#      Budget < 1 s
# Ausgabe: Tabelle mit gemessener Zeit, Ziel und Status.

if (nzchar(Sys.getenv("VOFI_BENCH_LOAD_ALL"))) {
  suppressMessages(pkgload::load_all(".", quiet = TRUE))
  ns <- asNamespace("vofi")
} else {
  suppressMessages(library(vofi))
  ns <- asNamespace("vofi")
}
get_int <- function(name) get(name, envir = ns)

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

median_ms <- function(expr_fun, reps) {
  tt <- vapply(seq_len(reps), function(i) {
    t0 <- proc.time()[["elapsed"]]
    expr_fun()
    proc.time()[["elapsed"]] - t0
  }, double(1))
  1000 * stats::median(tt)
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

run_engine_mc <- function(model, n_sim = 10000L, chunk = 2000L) {
  eng_run_draws <- get_int("eng_run_draws")
  draws <- fake_chunk_draws(model, chunk)
  for (k in seq_len(n_sim %/% chunk)) {
    suppressWarnings(suppressMessages(
      eng_run_draws(model, draws, store = "bands",
                    bands = c("net_position", "dep_balance", "od_balance"))
    ))
  }
  invisible(NULL)
}

rebalance_bisection <- function(model, evals = 40L) {
  env <- get_int("eng_engine_env")(model, quiet = TRUE)
  ctx <- get_int("eng_context")(model, NULL, env)
  exo <- get_int("eng_flows")(model, ctx, env)
  core <- get_int("eng_balance")(model, ctx, exo$ledger, engine_env = env)
  target <- core$stocks$BS[1L, ctx$T + 1L] / 2
  delta <- ctx$by_period(ctx$grid$delta)
  t0 <- proc.time()[["elapsed"]]
  lo <- -1e5
  hi <- 1e5
  for (k in seq_len(evals)) {
    mid <- (lo + hi) / 2
    r <- get_int("eng_balance")(model, ctx, exo$ledger, extra_out = -ctx$by_sim(mid) * delta,
                                book = FALSE, engine_env = env)
    if (r$BS_T[1L] > target) lo <- mid else hi <- mid
  }
  1000 * (proc.time()[["elapsed"]] - t0)
}

m83 <- suppressMessages(vofi_build(bench_scenario(61L, 24L)))
m53 <- suppressMessages(vofi_build(bench_scenario(53L, 0L)))
m83y <- suppressMessages(vofi_build(bench_scenario(83L, 0L)))
quiet_run <- function(m) suppressMessages(suppressWarnings(vofi_run(m)))
invisible(quiet_run(m83))

res <- data.frame(
  vorgang = c(sprintf("deterministischer Lauf, T = %d", m83$grid$T),
              "Entnahme-Aequivalent (40 Wiederholungslaeufe)",
              "Engine-Anteil MC 10.000 x 53 (5 Chunks)",
              "Engine-Anteil MC 10.000 x 83 (5 Chunks)",
              "Design-Lauf 41 Zeilen (Tornado 20 x 2)"),
  ms = c(median_ms(function() quiet_run(m83), 15L),
         stats::median(vapply(1:5, function(i) rebalance_bisection(m83), double(1))),
         median_ms(function() run_engine_mc(m53), 2L),
         median_ms(function() run_engine_mc(m83y), 1L),
         median_ms(function() {
           suppressMessages(suppressWarnings(
             get_int("eng_run_draws")(m53, fake_chunk_draws(m53, 41L), store = "kpi",
                                      kpis = "delta_terminal_value")
           ))
         }, 5L)),
  ziel_ms = c(50, 100, 1500, 3000, 1000),
  stringsAsFactors = FALSE
)
res$status <- ifelse(res$ms <= res$ziel_ms, "ok", "ueber Ziel")
print(res, row.names = FALSE)
