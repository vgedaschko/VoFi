# Hilfsfunktionen der Engine-Tests (WS-D, Spec 00 Abschnitte 6, 8.7-8.9, 9, 10).

#' Kleines Jahresszenario: Zahlungsfolge z, optional Restwert, Eigenkapital und Konten
#' @param z Zahlungsfolge je Periode (Länge T + 1).
#' @param rv optionale Restwertfolge (Kategorie residual_value).
#' @param ek Eigenkapitalkomponente.
#' @param accounts Konten (ergänzen bzw. ersetzen die neutralen Vorgaben).
#' @param financing zusätzliche Finanzierungskomponenten.
#' @param components zusätzliche Zahlungskomponenten.
#' @param project zusätzliche Projektfelder.
wsd_scenario <- function(z, rv = NULL, ek = list(type = "equity", amount_eur = 100000),
                         accounts = list(), horizon = length(z) - 1L, financing = list(),
                         components = list(), project = list(),
                         kpis = c("terminal_value", "terminal_value_opp",
                                  "delta_terminal_value")) {
  comps <- list(z = list(type = "custom_series", label = "Zahlungsfolge", values = z))
  if (!is.null(rv)) {
    comps$rv <- list(type = "custom_series", category = "residual_value", values = rv)
  }
  comps <- c(comps, components)
  acc <- utils::modifyList(list(deposit_rate_pa = 0, overdraft_rate_pa = 0,
                                overdraft_limit_eur = 0, penalty_spread_pa = 0,
                                min_liquidity_eur = 0,
                                surplus_order = c("od_repay", "dep_invest"),
                                deficit_order = c("dep_withdraw", "od_draw", "equity_call")),
                           accounts)
  fin <- c(if (is.null(ek)) list() else list(ek = ek), financing)
  proj <- utils::modifyList(list(perspective = "kleinvermieter", project_type = "neubau",
                                 valuation_date = as.Date("2027-01-01"),
                                 horizon_years = as.integer(horizon)), project)
  vofi_scenario(list(
    schema_version = 1L, meta = list(scenario_id = "engine_test", title = "Engine"),
    project = proj, components = comps, financing = fin, accounts = acc,
    analysis = list(kpis = kpis)
  ))
}

#' Modell des Gerüst-Beispiels (Anhang A)
wsd_skeleton <- function() {
  vofi_build(vofi_read_scenario(vofi_example("skeleton")))
}

#' Stufen eines Laufs einzeln (Kontext, Komponenten, Ausgleich)
#' @param model `vofi_model`.
#' @param draws `NULL` oder `vofi_draws`.
wsd_parts <- function(model, draws = NULL) {
  env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, draws, env)
  exo <- eng_flows(model, ctx, env)
  eng_auto_amounts(model, ctx, exo$ledger, env)
  core <- eng_balance(model, ctx, exo$ledger, engine_env = env)
  list(env = env, ctx = ctx, exo = exo, core = core)
}

#' Szenario des Prüffalls Sacheinlage (9.5, R-68)
#' @param existing_value Bestandswert W_0 oder `NULL`.
wsd_in_kind_scenario <- function(existing_value = 500000) {
  sc <- wsd_scenario(
    c(0, 30000), rv = c(0, 510000), ek = NULL,
    accounts = list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08),
    components = list(sc = list(type = "custom_series", category = "sale_cost",
                                values = c(0, -15300))),
    financing = list(alt = list(type = "bullet_loan", existing = TRUE, amount_eur = 200000,
                                rate_pa = 0.03, term_years = 5, payments_per_year = 1L)),
    project = list(project_type = "sanierung_einzelmassnahmen")
  )
  # Pflichtangaben bei Block building (Spec 01 Teil A 3.3, 3.4, 6.2; WS-B): Baujahr bzw. WE-Zahl,
  # Instandhaltungspauschale abgeschaltet
  if (!is.null(existing_value)) {
    sc$building <- list(existing_value_eur = existing_value, construction_year = 1972L,
                        n_units = 6L, maintenance = list(enabled = FALSE))
  }
  # Der Restwert 510.000 und die Verkaufskosten -15.300 stehen als eigene Reihen rv und sc im
  # Szenario; kein Restwert-Expander: Methode zero (Spec 01 Teil A 6.2 Nr. 1, nur Nullzeilen).
  # Sonst entstünde mit building zusätzlich rv_value nach der Profilmethode (component mit
  # include_existing = auto: W_0 fortgeschrieben), der Restwert zählte doppelt (Integration C5).
  # sale_cost_share bleibt für opp_in_kind_sale (Spec 00 9.5 Nr. 7) maßgeblich.
  sc$residual_value <- list(method = "zero", sale_cost_share = 0.03)
  sc
}

#' Kontenzustand für Einheitstests der Ausgleichsaktionen (8.9)
#' @param g,kk,kkp Bestände G, KK, KKP (n-Vektoren; n = Länge von `g`).
#' @param lmin,kl Mindestliquidität und Limit (Spalte j = 2).
wsd_acc <- function(g = c(100, 0), kk = c(0, 50), kkp = c(0, 20), lmin = 30, kl = 100,
                    thr = Inf, h_pa = 0.02, w = 0, buffer = 0, spread = 0) {
  n <- length(g)
  list(G = g, KK = kk, KKP = kkp, Lmin = matrix(lmin, n, 2L), KL = matrix(kl, n, 2L),
       flag_threshold = rep_len(thr, n), h_pa = matrix(h_pa, n, 2L), w = rep(w, n),
       prepay_buffer = buffer, prepay_min_spread = spread, j = 2L)
}

#' Szenario der Leistungsmessung (wie bench/bench_engine.R; Spec 00 Abschnitt 9.10)
#' @param horizon Horizont in Jahren.
#' @param construction_months Bauphase in Monaten (monatliches Raster, sonst jährlich).
wsd_bench_scenario <- function(horizon, construction_months) {
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
