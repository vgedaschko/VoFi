# Testhelfer von WS-G (Analyse: Monte Carlo, Vergleich, Sensitivität, Zielwertsuche; Spec 00
# Abschnitte 9.6, 9.9, 9.11, 11.11, 12.7-12.9, 13.2-13.4).
#
# vofi_mc(), vofi_compare(), vofi_sensitivity() und vofi_solve() sind geliefert (WS-G) und keine
# Stubs mehr. Bis der Integrator sie beim Wellen-Merge aus vofi_stubs() (helper-contracts.R)
# streicht, nimmt diese Hülle sie aus der Liste; sie ist idempotent und verkettbar (setdiff auf
# die vorige Fassung).
vofi_stubs <- local({
  previous <- vofi_stubs
  function() {
    setdiff(previous(), c("vofi_mc", "vofi_compare", "vofi_sensitivity", "vofi_solve"))
  }
})

#' Meldungen und Plausibilitätswarnungen eines Ausdrucks unterdrücken
wsg_quiet <- function(expr) {
  withCallingHandlers(expr,
                      vofi_message = function(m) invokeRestart("muffleMessage"),
                      vofi_warning_plausibility = function(w) invokeRestart("muffleWarning"),
                      vofi_warning_library_outdated = function(w) {
                        invokeRestart("muffleWarning")
                      })
}

#' Meldungen und Hinweise auf veraltete Bibliothekseinträge unterdrücken (übrige Warnungen
#' bleiben für expect_warning() sichtbar)
wsg_quiet_lib <- function(expr) {
  withCallingHandlers(expr,
                      vofi_message = function(m) invokeRestart("muffleMessage"),
                      vofi_warning_library_outdated = function(w) {
                        invokeRestart("muffleWarning")
                      })
}

#' Kleines Szenario: Investition in t = 0, Zahlungen je Jahr, Eigenkapital, optional Kredit
#'
#' Die Kennzahl ΔEW ist linear in `shared.*`-Blättern, wenn die Zahlungen in T liegen (keine
#' Verzinsung mehr). `final` ist der Zahlungsknoten in t = T (Zahl oder Wertform, z. B.
#' `list(expr = "...")`).
wsg_scenario <- function(horizon = 5L, final = 30000, flows = NULL, shared = list(),
                         stochastic = list(), variants = list(), kpis = NULL,
                         loan = TRUE, perspective = "wu_privat", project = list(),
                         accounts = list(), extra = list()) {
  flows <- flows %||% c(-100000, rep(9000, horizon - 1L))
  vals <- c(as.list(flows), list(final))
  comps <- list(z = list(type = "custom_series", label = "Zahlungsfolge", values = vals))
  fin <- list(ek = list(type = "equity", amount_eur = if (loan) 40000 else 100000))
  if (loan) {
    fin$bank <- list(type = "annuity_loan", amount_eur = 60000, rate_pa = 0.04,
                     term_years = 10, payments_per_year = 1L)
  }
  acc <- utils::modifyList(list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08,
                                overdraft_limit_eur = Inf, min_liquidity_eur = 0,
                                deposit_withholding_tax_share = 0,
                                surplus_order = c("od_repay", "dep_invest"),
                                deficit_order = c("dep_withdraw", "od_draw", "equity_call")),
                           accounts)
  raw <- c(list(
    schema_version = 1L, meta = list(scenario_id = "wsg", title = "WS-G-Testszenario"),
    project = utils::modifyList(list(perspective = perspective, project_type = "neubau",
                                     valuation_date = as.Date("2027-01-01"),
                                     horizon_years = as.integer(horizon)), project),
    components = comps, financing = fin, accounts = acc,
    residual_value = list(method = "zero"), tax = list(module = "none"),
    analysis = list(kpis = kpis %||% c("terminal_value", "terminal_value_opp",
                                       "delta_terminal_value"))
  ), extra)
  if (length(shared) > 0L) raw$shared <- shared
  if (length(stochastic) > 0L) raw$stochastic <- stochastic
  if (length(variants) > 0L) raw$variants <- variants
  vofi_scenario(raw)
}

#' Synthetisches Szenario mit ΔEW = 100 + 10 x1 - 5 x2 + 1 x3 (+ 0 x4) (Teil C 4.3 (v1))
wsg_linear_scenario <- function(with_x4 = FALSE) {
  params <- list(
    x1 = list(target = "shared.x1", dist = "uniform", min = -1, max = 1),
    x2 = list(target = "shared.x2", dist = "uniform", min = -1, max = 1),
    x3 = list(target = "shared.x3", dist = "uniform", min = -1, max = 1)
  )
  sh <- list(x1 = 0, x2 = 0, x3 = 0)
  if (with_x4) {
    params$x4 <- list(target = "shared.x4", dist = "uniform", min = -1, max = 1)
    sh$x4 <- 0
  }
  expr <- paste0("100 + 10 * shared.x1 - 5 * shared.x2 + 1 * shared.x3",
                 if (with_x4) " + 0 * shared.x4" else "")
  vofi_scenario(list(
    schema_version = 1L, meta = list(scenario_id = "wsg_lin", title = "linear"),
    project = list(perspective = "wu_privat", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 2L),
    components = list(z = list(type = "custom_series", label = "Zahlung",
                               values = list(0, 0, list(expr = expr)))),
    shared = sh,
    financing = list(ek = list(type = "equity", amount_eur = 0)),
    accounts = list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08,
                    overdraft_limit_eur = Inf, min_liquidity_eur = 0,
                    deposit_withholding_tax_share = 0,
                    surplus_order = c("od_repay", "dep_invest"),
                    deficit_order = c("dep_withdraw", "od_draw", "equity_call")),
    residual_value = list(method = "zero"), tax = list(module = "none"),
    analysis = list(kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value")),
    stochastic = list(settings = list(n_sim = 1000L, seed = 7L, block_size = 200L),
                      parameters = params)
  ))
}

#' Szenario mit ΔEW = Ausdruck in `shared.x1` (Zahlung in T = 2, ohne Eigenkapital)
wsg_expr_scenario <- function(expr, x1 = 0, parameters = list(), kpis = NULL, shared = list()) {
  raw <- list(
    schema_version = 1L, meta = list(scenario_id = "wsg_expr", title = "Ausdruck"),
    project = list(perspective = "wu_privat", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 2L),
    components = list(z = list(type = "custom_series", label = "Zahlung",
                               values = list(0, 0, list(expr = expr)))),
    shared = c(list(x1 = x1), shared),
    financing = list(ek = list(type = "equity", amount_eur = 0)),
    accounts = list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08,
                    overdraft_limit_eur = Inf, min_liquidity_eur = 0,
                    deposit_withholding_tax_share = 0,
                    surplus_order = c("od_repay", "dep_invest"),
                    deficit_order = c("dep_withdraw", "od_draw", "equity_call")),
    residual_value = list(method = "zero"), tax = list(module = "none"),
    analysis = list(kpis = kpis %||% c("terminal_value", "terminal_value_opp",
                                       "delta_terminal_value"))
  )
  if (length(parameters) > 0L) {
    raw$stochastic <- list(settings = list(seed = 5L, block_size = 200L),
                           parameters = parameters)
  }
  vofi_scenario(raw)
}

#' Szenario mit Entscheidungsknoten der Förderzusage (9.11) ohne Förder-Expander: der Zuschuss
#' ist eine Zahlung in t = 0 über `shared.grant`; die Ausweichvariante `ohne` entfernt das
#' Instrument und den Zuschuss.
wsg_decision_scenario <- function(n_sim = 400L, p = 0.6) {
  vofi_scenario(list(
    schema_version = 1L, meta = list(scenario_id = "wsg_dec", title = "Entscheidungsknoten"),
    project = list(perspective = "wu_privat", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 5L),
    building = list(n_units = 4L, living_area_m2 = 300, land_value_eur = 50000,
                    building_type = "MFH"),
    components = list(
      inv = list(type = "custom_series", label = "Investition",
                 values = c(-100000, 0, 0, 0, 0, 0)),
      rent = list(type = "custom_series", category = "rent",
                  values = list(0, list(ref = "shared.rent"), list(ref = "shared.rent"),
                                list(ref = "shared.rent"), list(ref = "shared.rent"),
                                list(ref = "shared.rent"))),
      zus = list(type = "custom_series", label = "Zuschuss",
                 values = list(list(ref = "shared.grant"), 0, 0, 0, 0, 0))
    ),
    shared = list(grant = 20000, rent = 9000),
    measures = list(huelle = list(measure_type = "daemmung_fassade", date = "2027-01-01",
                                  cost_eur = 1, useful_life_years = 40)),
    funding = list(f = list(instrument_type = "grant", measures = "huelle",
                            approval_timing = "before_start", fallback_variant = "ohne",
                            approval_probability = p, approved = 1)),
    financing = list(ek = list(type = "equity", amount_eur = 100000)),
    accounts = list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08,
                    overdraft_limit_eur = Inf, min_liquidity_eur = 0,
                    deposit_withholding_tax_share = 0,
                    surplus_order = c("od_repay", "dep_invest"),
                    deficit_order = c("dep_withdraw", "od_draw", "equity_call")),
    residual_value = list(method = "zero"), tax = list(module = "none"),
    analysis = list(kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value")),
    variants = list(ohne = list(label = "ohne Zusage", remove = list("funding.f"),
                                set = list(shared.grant = 0))),
    stochastic = list(settings = list(n_sim = as.integer(n_sim), seed = 1L, block_size = 200L),
                      parameters = list(rent = list(target = "shared.rent", dist = "uniform",
                                                    min = 7000, max = 11000)))
  ))
}

#' Attrappe von vofi_table() (WS-H) für die Differenz-VoFi: Summen je Abschnitt und Periode
wsg_mock_table <- function(x, sim = 1L, layout = "grob", detail = "standard", periods = NULL,
                           variant = NULL) {
  led <- x$ledger
  secs <- unique(led$rows$section)
  data <- data.frame(row_key = secs, label = secs, section = secs, level = 1L,
                     stringsAsFactors = FALSE)
  for (j in seq_len(led$T + 1L)) {
    data[[paste0("t", j - 1L)]] <- vapply(secs, function(s) {
      ks <- led$rows$key[led$rows$section == s & led$rows$cash]
      if (length(ks) == 0L) 0 else sum(vapply(ks, function(k) led$values[[k]][sim, j],
                                              double(1)))
    }, double(1))
  }
  new_vofi_table(list(data = data, layout = layout, detail = detail, periods = periods,
                      sim = sim, variant = variant))
}

# Variante "a" (Label "A") mit Overlay-Feldern `...`
wsg_variant_a <- function(...) list(a = list(label = "A", set = list(...)))

# Zahlungsreihe der Standardvariante "a" in den Vergleichstests
wsg_z_a <- c(-100000, 12000, 9000, 9000, 9000, 30000)
