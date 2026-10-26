# Hilfsfunktionen der Engine-Tests (WS-D, Spec 00 Abschnitte 6, 8.7-8.9, 9, 10).

# Von WS-D gelieferte Funktionen der Phase-0-Stubliste (helper-contracts.R, gepflegt vom
# Integrator): bis zum Wellen-Merge hier aus der Liste genommen, damit test-api.R die
# gelieferten Funktionen nicht als Stubs prüft. Die Liste des Integrators bleibt maßgeblich.
wsd_delivered <- function() {
  c("vofi_opportunity", "vofi_register_tax_module", "vofi_sim", "vofi_tax_module_simple")
}
if (exists("vofi_stubs", mode = "function", inherits = TRUE)) {
  wsd_stubs_orig <- vofi_stubs
  vofi_stubs <- function() setdiff(wsd_stubs_orig(), wsd_delivered())
}

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
  if (!is.null(existing_value)) sc$building <- list(existing_value_eur = existing_value)
  sc$residual_value <- list(sale_cost_share = 0.03)
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
