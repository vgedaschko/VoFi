# Testfixtures (Integrator, Spec 00 Abschnitt 15.1). Synthetische, vertragsgemäße Objekte ohne
# Engine; Grundlage der Tests von WS-D2 (Kennzahlen), WS-H (Ausgabe) und WS-G (Analyse).

#' Kanonisches Szenario aus tests/testthat/fixtures/scenarios/<name>.yaml
example_scenario <- function(name = c("skeleton", "oracle_a")) {
  name <- match.arg(name)
  skip_if_stub("vofi_read_scenario")
  vofi_read_scenario(testthat::test_path("fixtures", "scenarios", paste0(name, ".yaml")))
}

#' Synthetisches core (12.1) für Kennzahltests (= reg_example_core())
example_core <- function(n = 7L, T = 6L) reg_example_core(n, T) # nolint

#' Ungerundete Werte von Orakel (a) aus der Python-Referenz (vofi_ref.py, Memo 01)
oracle_a_values <- function() {
  list(
    z = c(-100000, 6000, 10000, 30000, 8000, 30000),
    rv = c(0, 0, 0, 0, 0, 40000),
    ek = c(30000, 0, 0, 0, 0, 0),
    od_draw = c(0, 4995.856017247579, 1495.441618972337, 0, 0, 0),
    od_repay = c(0, 0, 0, -6491.297636219916, 0, 0),
    od_interest = c(0, 0, -499.5856017247579, -649.1297636219916, 0, 0),
    dep_invest = c(0, 0, 0, -11863.716582910514, 0, -29280.857144646892),
    dep_withdraw = c(0, 0, 0, 0, 2639.9445197602636, 0),
    dep_interest = c(0, 0, 0, 0, 355.9114974873154, 276.7131618945075),
    dep_balance = c(0, 0, 0, 11863.716582910514, 9223.77206315025, 38504.629207797145),
    od_balance = c(0, 4995.856017247579, 6491.297636219916, 0, 0, 0),
    net_position = c(-70000, -67900, -61873.83424068991, -35545.9162005801,
                     -29734.582670102216, 38504.629207797145),
    ann_draw = c(40000, 0, 0, 0, 0, 0),
    ann_interest = c(0, -2400, -1974.2486389651453, -1522.9521962681995, -1044.5779670094366,
                     -537.5012839951481),
    ann_repay = c(0, -7095.856017247579, -7521.607378282433, -7972.90382097938,
                  -8451.278050238143, -8958.354733252469),
    ann_balance = c(40000, 32904.14398275242, 25382.53660446999, 17409.63278349061,
                    8958.354733252469, 0),
    bul_draw = c(30000, 0, 0, 0, 0, 0),
    bul_interest = c(0, -1500, -1500, -1500, -1500, -1500),
    bul_repay_balloon = c(0, 0, 0, 0, 0, -30000),
    bul_balance = c(30000, 30000, 30000, 30000, 30000, 0),
    opp_dep_invest = c(-30000, -900, -927, -954.81, -983.4542999999999, -1012.9579289999998),
    opp_dep_interest = c(0, 900, 927, 954.81, 983.4542999999999, 1012.9579289999998),
    opp_balance = c(30000, 30900, 31827, 32781.81, 33765.264299999995, 34778.22222899999),
    kpi = list(terminal_value = 38504.629207797145, terminal_value_opp = 34778.22222899999,
               delta_terminal_value = 3726.406978797153, roe_classic = 0.05118302280002296,
               roe_mirr = 0.05118302280002296, roe_irr = 0.05118302279970746,
               payback_time = 5, payback_year = 2031, min_net_liquidity = -6491.297636219916,
               max_overdraft = 6491.297636219916, max_financing_need = 6491.297636219916,
               sum_equity_calls = 0, pv_equity_calls = 0, flag_shortfall = 0,
               flag_limit_breach = 0, flag_reserve_used = 0,
               withdrawal_equivalent = 672.4449798147999,
               npv_cf_project = 10195.962880595915, irr_cf_project = 0.05563648698505631)
  )
}

#' Ledger aus Zeilenmetadaten (new_ledger_rows()) und Werten je Schlüssel (n = 1)
#'
#' Die Metadaten entstehen mit denselben Konstruktoren wie in der Engine (eng_loan_rows(),
#' eng_engine_rows(), eng_stock_rows(), Typlabels nach 7.1); es wird nichts gerechnet. Fehlende
#' Werte sind Nullzeilen.
helper_ledger <- function(rows, values, n_t) {
  ord <- order(rows$order, method = "radix")
  rows <- rows[ord, , drop = FALSE]
  rownames(rows) <- NULL
  vals <- lapply(rows$key, function(k) matrix(as.double(values[[k]] %||% rep(0, n_t)), nrow = 1L))
  new_vofi_ledger(rows, stats::setNames(vals, rows$key))
}

#' Metadaten einer Komponentenzeile wie in eng_flow_row_meta() (7.1, 7.3, 7.8)
helper_flow_rows <- function(id, type, local, section, category, position, label = NULL) {
  def <- reg_get("flow", type)
  label_key <- paste0(reg_label_prefix(def), ".rows.", local)
  new_ledger_rows(paste0(id, "__", local), section, category, source_id = id,
                  source_type = type, origin = "scenario", local_row = local,
                  label_key = label_key,
                  label = eng_type_row_label(def, label_key, local, prefix = label),
                  order = eng_row_order(section, category, position))
}

#' Vertragsgemäßes vofi_result aus den Tabellenwerten von Orakel (a), ohne Engine (15.1)
#'
#' Lehrbuch-VoFi: Investition -100.000, Annuitätendarlehen 40.000 zu 6 % (5 Jahre), endfälliges
#' Darlehen 30.000 zu 5 %, EK 30.000, Habenzins 3 %, Sollzins 10 %, Restwert 40.000 in T = 5.
#' Struktur (Schlüssel, Tags, Labels, Ordnung, Abschnitte der Unterlassungsalternative, meta)
#' wie das Ergebnis der Engine für fixtures/scenarios/oracle_a.yaml (test-fixtures.R prüft das).
example_result <- function() {
  o <- oracle_a_values()
  grid <- vofi_time_grid(as.Date("2027-01-01"), 5L)
  n_t <- 6L
  comp <- function(id) list(id = id, origin = "scenario")
  rows <- rbind(
    helper_flow_rows("z", "custom_series", "value", "project", "custom", 1L, "Zahlungsfolge"),
    helper_flow_rows("rv", "custom_series", "value", "project", "residual_value", 2L,
                     "Restwert"),
    helper_flow_rows("ek", "equity", "in", "equity", "equity_in", 3L),
    helper_flow_rows("ek", "equity", "out", "equity", "equity_out", 3L),
    eng_loan_rows("ann", 1L, comp("ann"), reg_get("instrument", "annuity_loan")),
    eng_loan_rows("bul", 2L, comp("bul"), reg_get("instrument", "bullet_loan")),
    eng_engine_rows(),
    eng_stock_rows(c("ann", "bul"))
  )
  values <- list(
    z__value = o$z, rv__value = o$rv, ek__in = o$ek,
    loan_ann_draw = o$ann_draw, loan_ann_repay = o$ann_repay, loan_ann_interest = o$ann_interest,
    loan_bul_draw = o$bul_draw, loan_bul_repay_balloon = o$bul_repay_balloon,
    loan_bul_interest = o$bul_interest,
    od_draw = o$od_draw, od_repay = o$od_repay, od_interest = o$od_interest,
    dep_invest = o$dep_invest, dep_withdraw = o$dep_withdraw, dep_interest = o$dep_interest,
    loan_ann_balance = o$ann_balance, loan_bul_balance = o$bul_balance,
    od_balance = o$od_balance, dep_balance = o$dep_balance, net_position = o$net_position
  )
  ledger <- helper_ledger(rows, values, n_t)
  # Unterlassungsalternative wie eng_opportunity(): Einlagen/Entnahmen der Investition,
  # opp_equity_call_in, Konten, Steuer, Pruefung und Bestaende ohne Kredite (9.5)
  opp_rows <- rbind(
    rows[rows$key %in% c("ek__in", "ek__out"), , drop = FALSE],
    new_ledger_rows("opp_equity_call_in", "equity", "equity_in",
                    local_row = "opp_equity_call_in",
                    label_key = "core.rows.opp_equity_call_in",
                    label = lbl("core.rows.opp_equity_call_in")),
    eng_engine_rows(),
    eng_stock_rows(character(0))
  )
  opp_values <- list(ek__in = o$ek, dep_invest = o$opp_dep_invest,
                     dep_interest = o$opp_dep_interest, dep_balance = o$opp_balance,
                     net_position = o$opp_balance)
  k <- o$kpi
  ex_rv_tv <- k$terminal_value - 40000
  kpis <- data.frame(
    terminal_value = k$terminal_value, terminal_value_ex_rv = ex_rv_tv,
    terminal_value_opp = k$terminal_value_opp,
    delta_terminal_value = k$delta_terminal_value,
    delta_terminal_value_ex_rv = ex_rv_tv - k$terminal_value_opp,
    roe_classic = k$roe_classic, roe_classic_ex_rv = NA_real_,
    roe_mirr = k$roe_mirr, roe_mirr_ex_rv = NA_real_,
    roe_irr = k$roe_irr, roe_irr_ex_rv = NA_real_,
    payback_time = k$payback_time, payback_time_ex_rv = NA_real_,
    payback_year = k$payback_year, payback_year_ex_rv = NA_real_,
    min_net_liquidity = k$min_net_liquidity, min_net_liquidity_ex_rv = k$min_net_liquidity,
    max_overdraft = k$max_overdraft, max_overdraft_ex_rv = k$max_overdraft,
    max_financing_need = k$max_financing_need,
    max_financing_need_ex_rv = k$max_financing_need,
    sum_equity_calls = 0, pv_equity_calls = 0, flag_shortfall = 0, flag_limit_breach = 0,
    flag_reserve_used = 0, withdrawal_equivalent = k$withdrawal_equivalent,
    withdrawal_equivalent_ex_rv = NA_real_, npv_cf_project = k$npv_cf_project,
    irr_cf_project = k$irr_cf_project
  )
  kpi_na <- as.data.frame(lapply(kpis, function(v) NA_character_), stringsAsFactors = FALSE)
  for (nm in c("roe_classic_ex_rv", "roe_mirr_ex_rv", "roe_irr_ex_rv")) {
    kpi_na[[nm]] <- "equity_lost"
  }
  for (nm in c("payback_time_ex_rv", "payback_year_ex_rv")) kpi_na[[nm]] <- "no_payback"
  kpi_na$withdrawal_equivalent_ex_rv <- "not_computed"
  flags <- data.frame(reserve_used = FALSE, shortfall = FALSE, shortfall_sum = 0,
                      first_shortfall_t = NA_integer_, limit_breach = FALSE, limit_cut = FALSE,
                      opp_limit_breach = FALSE, ex_rv_gap = 0, overdraft_threshold = FALSE,
                      stopped = FALSE, negative_amortization = FALSE,
                      equity_call_over_savings = FALSE, arbitrage = FALSE)
  checks <- data.frame(invariant = c("I1", "I2", "I3a", "I3b", "I3c", "N1", "N2"),
                       max_dev = 0, tol = c(1e-8, 1e-8, 1e-6, 1e-6, 1e-6, 0, 1e-8), ok = TRUE,
                       stringsAsFactors = FALSE)
  spec <- reg_test_spec(grid, perspective = "wu_privat", legal_state = as.Date("2027-01-01"),
                        accounts = list(deposit_rate_pa = 0.03, overdraft_rate_pa = 0.10,
                                        penalty_spread_pa = 0))
  new_vofi_result(list(
    spec = spec, grid = grid, model_hash = "example_oracle_a", ledger = ledger,
    kpis = kpis, kpi_na = kpi_na, kpi_series = list(),
    opportunity = list(ledger = helper_ledger(opp_rows, opp_values, n_t),
                       BS = matrix(o$opp_balance, nrow = 1L),
                       EW = k$terminal_value_opp),
    checks = checks, flags = flags, registers = list(assets = list(), measures = list()),
    draws = NULL, decision = NULL, traffic_light = NULL,
    meta = list(package_version = as.character(utils::packageVersion("vofi")),
                contract_version = VOFI_CONTRACT_VERSION, schema_version = 1L,
                scenario_id = "oracle_a", project_id = "oracle_a", building_id = "b1",
                variant = "base", scenario_set = NULL, mode = "deterministic", n_sim = 1L,
                seed = NULL, sim_index = 1L, legal_state = as.Date("2027-01-01"),
                pending_reforms = character(0),
                library = data.frame(entry = character(0), as_of = as.Date(character(0)),
                                     valid_from = as.Date(character(0)),
                                     valid_to = as.Date(character(0)),
                                     quality = character(0), stringsAsFactors = FALSE),
                library_version = NA_character_, defaults = scn_defaults_meta("wu_privat"),
                tax_module = "none",
                perspective = "wu_privat", tax_regime = "wu_kapges", report_mode = "expert",
                comparison_mode = "absolute", primary_kpi = "delta_terminal_value",
                store = "full", runtime_sec = 0,
                created = as.POSIXct("2026-10-25 12:00:00", tz = "UTC"),
                r_version = R.version.string, notes = character(0))
  ))
}

#' Konvergenzausweis (12.7, R-97) mit den Default-Schwellen (rel. Halbbreite 0,005 des
#' Mittelwerts, abs. Halbbreite 0,01 der Verlustwahrscheinlichkeit); bei R < 10 FALSE
helper_converged <- function(mean, se, p_neg_se, r_blocks, rel = 0.005, abs_prob = 0.01) {
  if (r_blocks < 10L) return(FALSE)
  tq <- stats::qt(0.975, r_blocks - 1L)
  isTRUE(tq * se / abs(mean) < rel && tq * p_neg_se < abs_prob)
}

#' Synthetisches, vertragsgemäßes vofi_mc_result (Ziehungen synthetisch, ohne Lauf der Engine;
#' `model` = gebautes Modell von Orakel (a) für vofi_sim(), 13.2)
example_mc_result <- function(n_sim = 200L) {
  n_sim <- as.integer(n_sim)
  det <- example_result()
  bs <- 200L
  i <- seq_len(n_sim)
  sc <- stats::qnorm((i - 0.5) / n_sim)[reg_weyl_perm(n_sim, 1L)]
  base <- det$kpis
  kpis <- data.frame(sim = i, block = as.integer((i - 1L) %/% bs + 1L),
                     terminal_value = base$terminal_value + 6000 * sc,
                     terminal_value_ex_rv = base$terminal_value_ex_rv + 6000 * sc,
                     terminal_value_opp = rep(base$terminal_value_opp, n_sim),
                     delta_terminal_value = base$delta_terminal_value + 6000 * sc,
                     delta_terminal_value_ex_rv = base$delta_terminal_value_ex_rv + 6000 * sc,
                     roe_mirr = base$roe_mirr + 0.012 * sc,
                     flag_shortfall = as.double(sc < -1.5))
  kpi_na <- data.frame(sim = i, terminal_value = NA_character_,
                       terminal_value_ex_rv = NA_character_, terminal_value_opp = NA_character_,
                       delta_terminal_value = NA_character_,
                       delta_terminal_value_ex_rv = NA_character_, roe_mirr = NA_character_,
                       flag_shortfall = NA_character_, stringsAsFactors = FALSE)
  probs <- c(0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95)
  r_blocks <- max(1L, as.integer(ceiling(n_sim / bs)))
  stat_row <- function(nm) {
    x <- kpis[[nm]]
    q <- stats::quantile(x, probs, type = 7, names = FALSE)
    se <- if (r_blocks > 1L) stats::sd(tapply(x, kpis$block, mean)) / sqrt(r_blocks) else
      stats::sd(x) / sqrt(length(x))
    data.frame(kpi = nm, mean = mean(x), sd = stats::sd(x), se = se, se_df = r_blocks - 1L,
               q05 = q[1L], q10 = q[2L], q25 = q[3L], q50 = q[4L], q75 = q[5L], q90 = q[6L],
               q95 = q[7L], p_neg = mean(x < 0),
               p_neg_se = sqrt(mean(x < 0) * (1 - mean(x < 0)) / length(x)),
               es05 = mean(x[x <= q[1L]]), expected_loss = mean(pmax(-x, 0)), na_share = 0,
               n_valid = length(x), deterministic = det$kpis[[nm]],
               converged = helper_converged(mean(x), se, sqrt(mean(x < 0) * (1 - mean(x < 0)) /
                                                               length(x)), r_blocks),
               stringsAsFactors = FALSE)
  }
  stats <- do.call(rbind, lapply(setdiff(names(kpis), c("sim", "block")), stat_row))
  rownames(stats) <- NULL
  band_probs <- c(0.05, 0.25, 0.5, 0.75, 0.95)
  band <- function(key, spread) {
    v <- det$ledger$values[[key]][1L, ]
    m <- rbind(t(vapply(stats::qnorm(band_probs), function(z) v + spread * z * det$grid$t,
                        numeric(length(v)))), v)
    rownames(m) <- c(paste0("q", sprintf("%02d", round(100 * band_probs))), "mean")
    m
  }
  run_idx <- c(p05 = which.min(abs(kpis$delta_terminal_value - stats$q05[stats$kpi ==
                                                                       "delta_terminal_value"])),
               p50 = which.min(abs(kpis$delta_terminal_value - stats$q50[stats$kpi ==
                                                                       "delta_terminal_value"])),
               p95 = which.min(abs(kpis$delta_terminal_value - stats$q95[stats$kpi ==
                                                                       "delta_terminal_value"])))
  checks <- det$checks
  checks$n_runs <- n_sim
  model <- vofi_build(vofi_read_scenario(testthat::test_path("fixtures", "scenarios",
                                                            "oracle_a.yaml")))
  new_vofi_mc_result(list(
    spec = det$spec, grid = det$grid, model = model, kpis = kpis, kpi_na = kpi_na,
    kpi_series = list(),
    inputs = data.frame(sim = i, `components.z.values` = 1 + 0.05 * sc, check.names = FALSE),
    features = data.frame(sim = i, `inflation.mean` = 0.02 + 0.002 * sc, check.names = FALSE),
    flags = data.frame(sim = i, shortfall = sc < -1.5, limit_breach = FALSE,
                       stopped = FALSE),
    bands = list(net_position = band("net_position", 1500), dep_balance = band("dep_balance", 900),
                 od_balance = band("od_balance", 300)),
    runs = list(p05 = det, p50 = det, p95 = det), run_index = run_idx,
    deterministic = det, stats = stats, checks = checks, ledger = NULL, decision = NULL,
    traffic_light = NULL,
    meta = c(det$meta[setdiff(names(det$meta), c("seed", "n_sim", "mode", "store"))],
             list(seed = 20261025, n_sim = n_sim, mode = "mc", store = "bands",
                  sampling = "lhs", replicates = r_blocks, block_size = bs,
                  copula = "iman_conover", antithetic = FALSE, chunk_size = 2000L,
                  repaired = list(), rng_kind = c("Mersenne-Twister", "Inversion", "Rejection"),
                  plan_hash = "example", keep_runs_kpi = "delta_terminal_value"))
  ))
}

#' Synthetischer, vertragsgemäßer Vergleich zweier Varianten (deterministisch)
example_comparison <- function() {
  base <- example_result()
  a <- base
  a$meta$variant <- "a"
  a$kpis$terminal_value <- base$kpis$terminal_value + 2000
  a$kpis$delta_terminal_value <- base$kpis$delta_terminal_value + 2000
  kpi_table <- data.frame(
    variant = rep(c("base", "a"), each = 2L),
    kpi = rep(c("terminal_value", "delta_terminal_value"), 2L),
    value = c(base$kpis$terminal_value, base$kpis$delta_terminal_value,
              a$kpis$terminal_value, a$kpis$delta_terminal_value),
    stringsAsFactors = FALSE
  )
  dvr <- matrix(a$kpis$delta_terminal_value - base$kpis$delta_terminal_value, nrow = 1L,
                dimnames = list(NULL, "a"))
  new_vofi_comparison(list(
    results = list(base = base, a = a), baseline = "base", variants = "a",
    scenario_sets = NULL, kpi_table = kpi_table,
    differences = list(delta_vs_reference = dvr),
    diff_stats = data.frame(variant = "a", kpi = "delta_vs_reference", mean = dvr[1L, 1L],
                            se = NA_real_, q05 = dvr[1L, 1L], q25 = dvr[1L, 1L],
                            q50 = dvr[1L, 1L], q75 = dvr[1L, 1L], q95 = dvr[1L, 1L],
                            prob_better = 1, stringsAsFactors = FALSE),
    ranking = data.frame(variant = c("a", "base"), rank = 1:2,
                         criterion = "delta_vs_reference", stringsAsFactors = FALSE),
    diff_table = NULL, comparability = new_vofi_validation(),
    traffic_light = data.frame(variant = "a", level = "yellow", stage1 = "yellow",
                               basis = "base_only", kpi = "delta_vs_reference",
                               rv_dependent = TRUE, ko_codes = "", stringsAsFactors = FALSE),
    restrictions = data.frame(variant = character(0), code = character(0),
                              violated_base = logical(0), prob = numeric(0),
                              year = integer(0), value = numeric(0), threshold = numeric(0),
                              ko = logical(0), stringsAsFactors = FALSE),
    conditional = NULL, crn = TRUE,
    meta = list(seed = NULL, n_sim = 1L, mode = "deterministic", allow_unequal = FALSE,
                created = as.POSIXct("2026-10-25 12:00:00", tz = "UTC"))
  ))
}
