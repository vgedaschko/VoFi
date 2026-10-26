# Testhelfer von WS-D2 (Kennzahlen, Spec 00 Abschnitt 12).
# - d2_core()/d2_ctx(): synthetische, vertragsgemäße cores (12.1) aus frei wählbaren Ledger-Zeilen
#   und Krediten über den Mini-Ausgleich des Prüfkits (R/registry-testkit.R) mit
#   rebalance()-Attrappe; Spezifikation über reg_test_spec() (Perspektive, Analyse, Haushalt).
# - d2_oracle_*(): Orakelszenarien aus Memo 01 §10 bzw. Spec 00 §15.3 als R-Listen (Eingaben wie
#   die Orakel-Fixtures von WS-T), gerechnet mit der Engine (alle Kennzahlen: analysis.kpis
#   default). Die Engine stammt in Welle 1 aus dem Walking Skeleton bzw. von WS-D.

# vofi_kpis() und vofi_register_kpi() sind geliefert (WS-D2) und keine Stubs mehr. Bis der
# Integrator sie beim Wellen-Merge aus vofi_stubs() (helper-contracts.R) streicht, nimmt diese
# Hülle sie aus der Liste; sie ist idempotent und verkettbar (setdiff auf die vorige Fassung).
vofi_stubs <- local({
  previous <- vofi_stubs
  function() setdiff(previous(), c("vofi_kpis", "vofi_register_kpi"))
})

#' Ledger-Zeile für d2_core(): Abschnitt, Kategorie, Werte (Länge T+1 oder n x (T+1))
d2_row <- function(section, category, values, asset = NA, measure = NA, extra = NULL) {
  list(section, category, values, asset, measure, extra)
}

#' Kredit für d2_core(): Flüsse je Kategorie (Vektoren der Länge T+1 oder n x (T+1))
d2_loan <- function(...) list(...)

#' Synthetisches core (12.1) aus Zeilen und Krediten (Mini-Ausgleich des Prüfkits)
#'
#' Kontoraten effektiv p. a.; `kl` = Kontokorrentlimit (Inf: unbegrenzt, sonst Nachschuss).
#' Pflichtzeilen des Prüfkits (`rv__value`, `rv__sale_cost`, `ek__in`, `ek__out`) werden bei
#' Bedarf als Nullzeilen ergänzt.
d2_core <- function(grid, rows = list(), loans = list(), n = 1L, h = 0.02, s = 0.06,
                    sp = 0.08, kl = Inf, runs = seq_len(n)) {
  n_t <- grid$T + 1L
  as_m <- function(v) {
    if (is.matrix(v)) return(v)
    matrix(rep(as.double(v), each = n), n, n_t)
  }
  exo <- list()
  for (k in names(rows)) {
    r <- rows[[k]]
    r[[3L]] <- as_m(r[[3L]])
    exo[[k]] <- r
  }
  defaults <- list(rv__value = d2_row("project", "residual_value", 0),
                   rv__sale_cost = d2_row("project", "sale_cost", 0),
                   ek__in = d2_row("equity", "equity_in", 0),
                   ek__out = d2_row("equity", "equity_out", 0))
  for (k in setdiff(names(defaults), names(exo))) {
    r <- defaults[[k]]
    r[[3L]] <- as_m(r[[3L]])
    exo[[k]] <- r
  }
  cats <- c("draw", "repay", "repay_balloon", "prepay", "interest", "fees", "repayment_grant",
            "disagio", "assumed", "balance")
  lo <- list()
  if (length(loans) == 0L) loans <- list(bank = d2_loan())
  for (k in names(loans)) {
    l <- loans[[k]]
    full <- lapply(cats, function(cc) as_m(l[[cc]] %||% 0))
    lo[[k]] <- stats::setNames(full, cats)
  }
  inp <- list(exo = exo, loans = lo, rw = NULL, n = as.integer(n), runs = as.double(runs))
  rates <- list(h = grid_rate_eff(grid, rep(h, n)), s = grid_rate_eff(grid, rep(s, n)),
                sp = grid_rate_eff(grid, rep(sp, n)), KL = matrix(kl, n, n_t))
  core <- reg_core_from_inputs(inp, grid, rates)
  attr(core, "testkit") <- list(inputs = inp, rates = rates)
  core
}

#' Kontext zu einem synthetischen core (Stufe "kpi", rebalance()-Attrappe)
#' @param spec `NULL` (reg_test_spec() mit `...`) oder fertige Spezifikation.
#' @param mode `NULL` (n > 1: "mc", sonst "deterministic").
d2_ctx <- function(core, spec = NULL, mode = NULL, perspective = "wu_kommunal", ...) {
  tk <- attr(core, "testkit")
  grid <- core$grid
  n <- core$n
  n_t <- grid$T + 1L
  rebalance <- function(extra_out = NULL) {
    eo <- if (is.null(extra_out)) matrix(0, n, n_t) else utl_sim_matrix(grid, extra_out)
    p <- reg_core_from_inputs(tk$inputs, grid, tk$rates, extra_out = eo)
    list(BS_T = p$bs[, n_t], NS = p$bal$equity_call, BS_T_ex_rv = p$term$BS, RW_T = p$rw_t)
  }
  spec <- spec %||% reg_test_spec(grid, perspective = perspective, ...)
  mode <- mode %||% (if (n > 1L) "mc" else "deterministic")
  draws <- if (n > 1L) new_vofi_draws("mc", n = n, sims = as.integer(tk$inputs$runs)) else NULL
  eng_context_from_parts(grid, spec, draws = draws, components = list(), mode = mode,
                         engine_env = reg_engine_env("kpi", rebalance = rebalance))
}

#' Kennzahl `name` auf core und ctx rechnen (compute der Registry)
d2_kpi <- function(name, core, ctx) reg_get("kpi", name)$compute(core, ctx)

#' Alle registrierten Kennzahlen über kpi_compute()
d2_all <- function(core, ctx) {
  defs <- lapply(reg_list("kpi")$name, function(k) reg_get("kpi", k))
  names(defs) <- reg_list("kpi")$name
  kpi_compute(defs, core, ctx)
}

#' Synthetisches core mit Bestands- (alt) und neuem Kredit (neu), NOI 9.000 je Jahr
d2_debt_core <- function(existing = TRUE, n = 1L) {
  g <- vofi_time_grid(as.Date("2027-01-01"), 6L)
  t <- g$t
  on <- as.double(t >= 1)
  rows <- list(rent__value = d2_row("project", "rent", 10000 * on),
               opex__value = d2_row("project", "operating_cost", -1000 * on),
               levy__value = d2_row("project", "other_income", 500 * on),
               ek__in = d2_row("equity", "equity_in", c(20000, rep(0, 6))))
  loans <- list(alt = d2_loan(interest = -1000 * on, repay = -2000 * on,
                              balance = 30000 - 2000 * t),
                neu = d2_loan(draw = c(50000, rep(0, 6)), interest = -2000 * on,
                              repay = -3000 * on, repay_balloon = c(rep(0, 6), -32000),
                              balance = c(50000 - 3000 * t[-7], 0)))
  core <- d2_core(g, rows, loans, n = n)
  if (existing) {
    hit <- core$ledger$rows$source_id == "alt"
    core$ledger$rows$existing_debt[hit] <- TRUE
  }
  core
}

#' Pseudo-core aus einem Ergebnis der Engine (Ledger, Raster, Bestände) und Kontext
d2_result_core <- function(r) {
  led <- r$ledger
  v <- led$values
  bal <- ledger_select(led, section = "stocks", category = "balance")
  loans <- setdiff(bal, c("od_balance", "odp_balance", "dep_balance"))
  core <- list(ledger = led, grid = r$grid, n = 1L,
               stocks = list(G = v$dep_balance, KK = v$od_balance, KKP = v$odp_balance,
                             B = v[loans], BS = v$net_position))
  list(core = core, ctx = eng_context_from_parts(r$grid, r$spec))
}

# ---------------------------------------------------------------------------------------------
# Orakelszenarien (Memo 01 §10, Spec 00 §15.3)
# ---------------------------------------------------------------------------------------------

d2_accounts <- function(h, s, limit = Inf, spread = 0,
                        deficit = c("dep_withdraw", "od_draw", "equity_call")) {
  list(deposit_rate_pa = h, overdraft_rate_pa = s, overdraft_limit_eur = limit,
       min_liquidity_eur = 0, penalty_spread_pa = spread, deposit_withholding_tax_share = 0,
       surplus_order = c("od_repay", "dep_invest"), deficit_order = deficit)
}

d2_scenario <- function(id, horizon, components, financing, accounts, perspective = "wu_privat",
                        project_type = "neubau", analysis = list(kpis = "default"), ...) {
  c(list(schema_version = 1L, meta = list(scenario_id = id, title = id),
         project = list(perspective = perspective, project_type = project_type,
                        valuation_date = "2027-01-01", horizon_years = as.integer(horizon)),
         components = components, financing = financing, accounts = accounts,
         tax = list(module = "none"), analysis = analysis), list(...))
}

d2_run <- function(sc, ...) {
  suppressMessages(suppressWarnings(vofi_run(vofi_build(vofi_scenario(sc), ...))))
}

#' (a) Lehrbuch-VoFi; (d) dasselbe mit allen Zinsen 5 %
d2_oracle_a <- function(rate = NULL) {
  ann <- rate %||% 0.06
  bul <- rate %||% 0.05
  d2_scenario("oracle_a", 5L,
              list(z = list(type = "custom_series",
                            values = c(-100000, 6000, 10000, 30000, 8000, 30000)),
                   rv = list(type = "custom_series", category = "residual_value",
                             values = c(0, 0, 0, 0, 0, 40000))),
              list(ek = list(type = "equity", amount_eur = 30000),
                   ann = list(type = "annuity_loan", amount_eur = 40000, rate_pa = ann,
                              term_years = 5, payments_per_year = 1L),
                   bul = list(type = "bullet_loan", amount_eur = 30000, rate_pa = bul,
                              term_years = 5, payments_per_year = 1L)),
              d2_accounts(rate %||% 0.03, rate %||% 0.10))
}

#' (b1)/(b2) Ratentilgung mit Tilgungszuschuss
d2_oracle_b <- function(effect = "shorten_term") {
  d2_scenario("oracle_b", 10L,
              list(z = list(type = "custom_series", values = c(-200000, rep(0, 10))),
                   noi = list(type = "recurring", amount_eur = 14000, growth = 0.02,
                              base_date = "2028-01-01", category = "rent",
                              start_event = "2027-01-01"),
                   rv = list(type = "custom_series", category = "residual_value",
                             values = c(rep(0, 10), 60000))),
              list(ek = list(type = "equity", amount_eur = 50000),
                   foe = list(type = "installment_loan", amount_eur = 150000, rate_pa = 0.02,
                              term_years = 10, grace_years = 2, payments_per_year = 1L,
                              repayment_grant = list(amount_eur = 22500, date = "2028-01-01",
                                                     effect = effect))),
              d2_accounts(0.02, 0.08))
}

#' (c1)/(c2) 100 % Fremdfinanzierung (c2: KK-Limit 0, Nachschüsse)
d2_oracle_c <- function(limit = Inf) {
  d2_scenario("oracle_c", 10L,
              list(z = list(type = "custom_series", values = c(-300000, rep(0, 10))),
                   noi = list(type = "recurring", amount_eur = 12000, growth = 0.02,
                              base_date = "2028-01-01", category = "rent",
                              start_event = "2027-01-01"),
                   rv = list(type = "custom_series", category = "residual_value",
                             values = c(rep(0, 10), 280000 * 1.02^10 * 0.97)),
                   mv = list(type = "custom_series", section = "memo", category = "market_value",
                             values = list(start = 280000, growth = 0.02, index = "period_end"))),
              list(ann = list(type = "annuity_loan", amount_eur = 300000, rate_pa = 0.038,
                              initial_repayment_pa = 0.02, payments_per_year = 1L)),
              d2_accounts(0.025, 0.09, limit = limit))
}

#' Auszahlungsplan des Baudarlehens von (e): je 100.000 zu Quartalsbeginn 2027
d2_tranches <- function() {
  stats::setNames(as.list(rep(100000, 4)),
                  c("2027-01-01", "2027-04-01", "2027-07-01", "2027-10-01"))
}

#' (e) Bauphase quartalsweise, Baudarlehen in vier Tranchen mit Bereitstellungsprovision
d2_oracle_e <- function(perspective = "wu_privat", household = NULL) {
  sc <- d2_scenario("oracle_e", 4L,
                    list(z = list(type = "custom_series",
                                  values = c(-200000, -100000, -100000, -100000, 0, 30000, 30600,
                                             31212)),
                         rv = list(type = "custom_series", category = "residual_value",
                                   values = c(rep(0, 7), 520000))),
                    list(ek = list(type = "equity", amount_eur = 100000),
                         bau = list(type = "annuity_loan", amount_eur = 400000, rate_pa = 0.036,
                                    initial_repayment_pa = 0.02, payments_per_year = 1L,
                                    draw_schedule = list(schedule = d2_tranches()),
                                    grace_years = 0.25,
                                    fees = list(commitment_fee_rate_month = 0.0025,
                                                commitment_free_months = 3))),
                    d2_accounts(0.025, 0.09), perspective = perspective)
  sc$grid <- list(periods_months = c(3L, 3L, 3L, 3L, 12L, 12L, 12L), construction_months = 12L)
  if (!is.null(household)) sc$household <- household
  sc
}

#' (g) Vergleichsregel: Variante A bzw. Referenz B
d2_oracle_g <- function(variant = c("a", "base")) {
  variant <- match.arg(variant)
  z <- if (variant == "a") c(-10000, -3000, 16000) else c(-10000, 1000, 12000)
  d2_scenario(paste0("oracle_g_", variant), 2L,
              list(z = list(type = "custom_series", values = z)),
              list(ek = list(type = "equity", amount_eur = 10000)),
              d2_accounts(0.02, 0.08, limit = 0, spread = 0.02))
}

#' Prüffall Sacheinlage (Spec 00 §9.5): Bestandsprojekt mit Bestandsdarlehen
d2_oracle_in_kind <- function(existing_value = 500000) {
  sc <- d2_scenario("in_kind", 1L,
                    list(m = list(type = "custom_series", category = "rent", values = c(0, 30000)),
                         rv = list(type = "custom_series", category = "residual_value",
                                   values = c(0, 510000)),
                         sc = list(type = "custom_series", category = "sale_cost",
                                   values = c(0, -15300))),
                    list(alt = list(type = "bullet_loan", existing = TRUE, amount_eur = 200000,
                                    rate_pa = 0.03, term_years = 5, payments_per_year = 1L)),
                    d2_accounts(0.02, 0.08), project_type = "sanierung_einzelmassnahmen",
                    residual_value = list(sale_cost_share = 0.03))
  if (!is.null(existing_value)) sc$building <- list(existing_value_eur = existing_value)
  sc
}
