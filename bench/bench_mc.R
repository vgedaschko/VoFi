# Leistungsmessung der Analyse (WS-G, Spec 00 Abschnitt 9.10).
#
# Aufruf aus der Paketwurzel:
#   Rscript bench/bench_mc.R                         # installiertes Paket vofi (byte-kompiliert)
#   VOFI_BENCH_LOAD_ALL=1 Rscript bench/bench_mc.R   # Quellbaum ueber pkgload::load_all()
#   VOFI_BENCH_PROFILE=1 ...                         # zusaetzlich Rprof-Profil der MC 10.000 x 53
#   VOFI_BENCH_QUICK=1 ...                           # je Messung eine Wiederholung
#
# Gemessen werden (verstrichene Zeit und CPU-Zeit, ohne Einlesen und Modellbau) mit vofi_mc()
# einschliesslich Sampler (statische Groessen mit Iman-Conover-Korrelation, drei Prozesse mit
# korrelierten Schocks), Kennzahlen, Unterlassungsalternative und Baendern:
#   1. MC 10.000 x 53 Perioden:                                   Ziel < 1,5 s
#   2. MC 10.000 x 83 Perioden:                                   Ziel < 3 s
#   3. Vergleich 5 Varianten x 10.000 x 53 (CRN, vofi_compare()): Ziel < 8 s
#   4. Tornado 20 Parameter x 2 (ein Design-Lauf, eine Kennzahl): Ziel < 1 s
#   5. Spitzenspeicher MC 10.000 x 83, store = "bands":           Ziel < 1 GB
#   6. Variante mit Entscheidungsknoten (V und Ausweichvariante): <= 2 x Variante ohne Knoten
#   7. Set "vorsichtig" (Tornado + ein Design-Lauf):              Ziel < 1,5 s
#   8. Rendite der Mehrinvestition (zwei Design-Laeufe à 41 Zeilen + Verfeinerung): < 1,5 s
# Ausgabe: Tabelle mit gemessener Zeit, Ziel und Status; danach die Anteile Sampler/Engine eines
# MC-Chunks (2.000 Laeufe x 53 Perioden) und optional das Profil.
# Die Pflicht-Leistungstests (Spec 00 15.6, skip_on_cran(), Faktor VOFI_PERF_FACTOR) mit
# demselben Szenario (wsg_bench_scenario() in tests/testthat/helper-ws-g.R) stehen in
# test-mc.R, test-compare.R und test-sensitivity.R.

if (nzchar(Sys.getenv("VOFI_BENCH_LOAD_ALL"))) {
  suppressMessages(pkgload::load_all(".", quiet = TRUE))
} else {
  suppressMessages(library(vofi))
}
ns <- asNamespace("vofi")
get_int <- function(name) get(name, envir = ns)
quick <- nzchar(Sys.getenv("VOFI_BENCH_QUICK"))
reps <- function(n) if (quick) 1L else n

quiet <- function(expr) {
  withCallingHandlers(expr, warning = function(w) invokeRestart("muffleWarning"),
                      message = function(m) invokeRestart("muffleMessage"))
}

timing <- function(fun, n) {
  tt <- lapply(seq_len(n), function(i) {
    gc(FALSE)
    t0 <- proc.time()
    fun()
    d <- proc.time() - t0
    c(elapsed = d[["elapsed"]], cpu = d[["user.self"]] + d[["sys.self"]])
  })
  m <- do.call(rbind, tt)
  1000 * c(elapsed = stats::median(m[, "elapsed"]), cpu = min(m[, "cpu"]))
}

#' Benchmark-Szenario (wie bench_engine.R) mit Stochastik-Overlay
bench_mc_scenario <- function(horizon, construction_months, variants = list(),
                              decision = FALSE) {
  st_par <- list(
    rent = list(target = "components.rent.amount_eur", dist = "triangular", min = 170000,
                mode = 185000, max = 195000),
    opex = list(target = "components.opex.amount_eur", dist = "pert", min = 27000,
                mode = 30000, max = 36000),
    maint = list(target = "components.maint.amount_eur", dist = "pert", min = 0.9, mode = 1,
                 max = 1.4, apply = "multiply"),
    admin = list(target = "components.admin.amount_eur", dist = "uniform", min = 7000,
                 max = 9000),
    inv = list(target = "components.inv.values", dist = "pert", min = 0.95, mode = 1.05,
               max = 1.3, apply = "multiply"),
    kfw_rate = list(target = "financing.kfw.rate_pa", dist = "uniform", min = 0.015,
                    max = 0.025),
    haben = list(target = "accounts.deposit_rate_pa", dist = "triangular", min = 0.01,
                 mode = 0.02, max = 0.03)
  )
  procs <- list(
    zins = list(target = "market.mortgage_rate", type = "vasicek", r0 = 0.04, theta = 0.045,
                kappa = 0.2, sigma = 0.01),
    infl = list(target = "market.inflation", type = "ar1", mu = 0.02, phi = 0.6, sigma = 0.01,
                x0 = 0.025),
    miete = list(target = "market.rent_growth", type = "ar1", mu = 0.015, phi = 0.5,
                 sigma = 0.008)
  )
  raw <- list(
    schema_version = 1L,
    meta = list(scenario_id = "bench_mc", title = "Benchmark MC"),
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
    residual_value = list(method = "zero"), tax = list(module = "none"),
    analysis = list(kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value",
                             "roe_mirr", "payback_time", "min_net_liquidity",
                             "max_overdraft", "sum_equity_calls")),
    stochastic = list(
      settings = list(seed = 20261025L, block_size = 200L, sampling = "lhs"),
      parameters = st_par, processes = procs,
      correlations = list(parameters = list(list("rent", "opex", 0.3),
                                            list("opex", "admin", 0.5)),
                          shocks = list(list("zins", "infl", 0.4)))
    ),
    variants = variants
  )
  if (decision) {
    raw$building <- list(n_units = 20L, living_area_m2 = 1500, land_value_eur = 300000,
                         building_type = "MFH")
    raw$measures <- list(huelle = list(measure_type = "daemmung_fassade", date = "2027-01-01",
                                       cost_eur = 1, useful_life_years = 40))
    raw$funding <- list(f = list(instrument_type = "grant", measures = "huelle",
                                 approval_timing = "before_start", fallback_variant = "ohne",
                                 approval_probability = 0.7, approved = 1))
    raw$components$zus <- list(type = "custom_series", label = "Zuschuss",
                               values = c(list(list(ref = "shared.grant")),
                                          as.list(rep(0, horizon))))
    raw$shared <- list(grant = 150000)
    raw$variants$ohne <- list(label = "ohne Zusage", remove = list("funding.f"),
                              set = list(shared.grant = 0))
  }
  vofi_scenario(raw)
}

# Varianten setzen nur deterministische Blaetter (keine Overlay-Ziele), damit alle fuenf Faelle
# dieselben Overlay-Eintraege und Korrelationen haben
variants5 <- list(
  v1 = list(label = "Miete indexiert 2 %", set = list(components.rent.growth = 0.02)),
  v2 = list(label = "Endfaelliges Darlehen 4,5 %", set = list(financing.bul.rate_pa = 0.045)),
  v3 = list(label = "Instandhaltung +2 %", set = list(components.maint.growth = 0.02)),
  v4 = list(label = "Verwaltung +1,5 %", set = list(components.admin.growth = 0.015))
)

cat("Modelle bauen ...\n")
sc53 <- bench_mc_scenario(53L, 0L, variants = variants5)
sc83 <- bench_mc_scenario(83L, 0L)
scd <- bench_mc_scenario(53L, 0L, decision = TRUE)
m53 <- quiet(vofi_build(sc53))
m83 <- quiet(vofi_build(sc83))
md <- quiet(vofi_build(scd))
md0 <- md
md0$decision <- NULL
stopifnot(m53$grid$T == 53L, m83$grid$T == 83L, !is.null(md$decision))

mc_run <- function(m, store = "bands", n = 10000L) {
  quiet(vofi_mc(m, n_sim = n, seed = 20261025L, store = store, keep_runs = character(0)))
}

invisible(mc_run(m53, n = 2000L))
t_mc53 <- timing(function() mc_run(m53), reps(3L))
t_mc83 <- timing(function() mc_run(m83), reps(2L))
t_cmp <- timing(function() {
  quiet(vofi_compare(sc53, n_sim = 10000L, seed = 20261025L, store = "kpi"))
}, reps(1L))

# Tornado mit 20 Parametern (Overlay-Schluessel, Prozesse, Zielpfade mit delta)
tor_params <- c("rent", "opex", "maint", "admin", "inv", "kfw_rate", "haben", "zins", "infl",
                "miete", "financing.bul.rate_pa", "financing.bank.rate_pa",
                "accounts.overdraft_rate_pa", "accounts.penalty_spread_pa",
                "components.maint.growth", "components.admin.growth",
                "financing.ek.withdrawals_pa", "zins.theta", "infl.mu", "miete.mu")
t_tor <- timing(function() {
  quiet(vofi_sensitivity(m53, params = tor_params, kpi = "delta_terminal_value"))
}, reps(3L))
n_tor <- nrow(quiet(vofi_sensitivity(m53, params = tor_params,
                                     kpi = "delta_terminal_value"))$params)

# Spitzenspeicher MC 10.000 x 83 (bands)
invisible(gc(reset = TRUE))
mem0 <- sum(gc()[, 2L])
invisible(mc_run(m83))
mem_peak <- sum(gc()[, 6L])

# Entscheidungsknoten
t_dec <- timing(function() mc_run(md), reps(2L))
t_dec0 <- timing(function() mc_run(md0), reps(2L))

# Set "vorsichtig" und Rendite der Mehrinvestition
mv1 <- quiet(vofi_build(sc53, variant = "v1"))
t_caut <- timing(function() {
  quiet(get_int("cmp_cautious")(get_int("cmp_with_qt")(mv1), get_int("cmp_with_qt")(m53),
                                gen = list(n_drivers = 5L), kpi = "delta_vs_reference"))
}, reps(3L))
t_inc <- timing(function() quiet(get_int("cmp_incremental_return")(mv1, m53)), reps(3L))

res <- data.frame(
  vorgang = c("MC 10.000 x 53 (inkl. Sampler, KPIs, Unterlassung, Baender)",
              "MC 10.000 x 83",
              "Vergleich 5 Varianten x 10.000 x 53 (CRN)",
              sprintf("Tornado %d Parameter x 2 (ein Design-Lauf)", n_tor),
              "Spitzenspeicher MC 10.000 x 83, bands (MB)",
              "MC mit Entscheidungsknoten / ohne Knoten (Faktor)",
              "Set vorsichtig (Tornado + Design-Lauf)",
              "Rendite der Mehrinvestition"),
  ms = round(c(t_mc53[["elapsed"]], t_mc83[["elapsed"]], t_cmp[["elapsed"]],
               t_tor[["elapsed"]], mem_peak, t_dec[["elapsed"]] / t_dec0[["elapsed"]],
               t_caut[["elapsed"]], t_inc[["elapsed"]]), 2),
  cpu_ms = round(c(t_mc53[["cpu"]], t_mc83[["cpu"]], t_cmp[["cpu"]], t_tor[["cpu"]], NA,
                   t_dec[["cpu"]] / t_dec0[["cpu"]], t_caut[["cpu"]], t_inc[["cpu"]]), 2),
  ziel = c(1500, 3000, 8000, 1000, 1024, 2, 1500, 1500),
  stringsAsFactors = FALSE
)
val <- ifelse(is.na(res$cpu_ms), res$ms, res$cpu_ms)
res$status <- ifelse(val <= res$ziel, "ok", "ueber Ziel")
print(res, row.names = FALSE)

# Anteile eines Chunks: Sampler (smp_sample + smp_materialize) und Engine (eng_run_draws)
cfg <- quiet(get_int("mc_config")(m53, n_sim = 2000L, seed = 20261025L, store = "bands"))
plan <- cfg$model$sampler
t_smp <- timing(function() get_int("smp_sample")(plan, 1:10, 20261025), reps(3L))
raw <- get_int("smp_sample")(plan, 1:10, 20261025)
t_mat <- timing(function() get_int("smp_materialize")(raw, plan, m53$grid), reps(3L))
draws <- get_int("smp_materialize")(raw, plan, m53$grid)
t_eng <- timing(function() {
  quiet(get_int("eng_run_draws")(cfg$model, draws = draws, store = "bands", kpis = cfg$kpis,
                                 bands = cfg$bands))
}, reps(3L))
cat("\nAnteile eines Chunks 2.000 x 53 (CPU-ms):\n")
print(round(c(sampler_roh = t_smp[["cpu"]], sampler_materialisieren = t_mat[["cpu"]],
              engine_kpis = t_eng[["cpu"]]), 1))
cat(sprintf("Speicher vor dem Lauf %.1f MB, Spitze %.1f MB\n", mem0, mem_peak))

if (nzchar(Sys.getenv("VOFI_BENCH_PROFILE"))) {
  prof <- tempfile(fileext = ".out")
  utils::Rprof(prof, interval = 0.005)
  invisible(mc_run(m53))
  utils::Rprof(NULL)
  sp <- utils::summaryRprof(prof)
  cat("\nProfil MC 10.000 x 53 (self.pct, Top 30):\n")
  print(utils::head(sp$by.self, 30L))
  cat("\nProfil (total.pct, Top 30):\n")
  print(utils::head(sp$by.total, 30L))
}
