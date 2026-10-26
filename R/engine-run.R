# Lauf-Stufen, Einzellauf (WS-D, Spec 00 Abschnitt 9.2).
# Phase 0: Stub von vofi_sim() (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-D. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).
# Phase-0-Minimalfassung, Eigentuemer: WS-D: vofi_run() fuer n_sim = 1 (store "full"),
# eng_run_chunk() (Stufen 1-9 fuer einen Chunk) und eng_run_draws() (Lauf mit vorgegebenen
# Ziehungen, z. B. fake_draws() in Tests; derselbe Codepfad fuer N = 1 und N > 1).
# Offen fuer WS-D/WS-C/WS-G: smp_draw() fuer MC-Chunks (WS-C), store "bands"/"kpi" (9.9,
# engine-store.R), extra_rows, return_paths, Design-Laeufe, vofi_sim().

#' VoFi berechnen
#'
#' Berechnet den VoFi deterministisch (`n_sim = 1`) oder als Monte-Carlo-Simulation (`n_sim > 1`,
#' Delegation an [vofi_mc()]) (Spec 00, Abschnitt 9.2).
#'
#' Phase-0-Minimalfassung (Eigentümer: WS-D): deterministischer Lauf vollständig; die
#' Monte-Carlo-Simulation folgt mit WS-C/WS-G.
#'
#' @param model Objekt der Klasse `vofi_model`.
#' @param n_sim Anzahl der Läufe.
#' @param seed Seed (ganze Zahl in `[1, 2^31 - 2]`); Default aus `stochastic$settings$seed`.
#' @param store Speicherstrategie: `"auto"`, `"full"`, `"bands"` oder `"kpi"`. Bei `n_sim = 1`
#'   enthält das Ergebnis stets den vollständigen Ledger (`"full"`, mit Hinweis bei `"bands"`
#'   bzw. `"kpi"`).
#' @param chunk_size Läufe je Chunk (wird auf ganze Blöcke abgerundet).
#' @return Objekt der Klasse `vofi_result` bzw. `vofi_mc_result`.
#' @family Rechnen
#' @examples
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' res$kpis$terminal_value
#' @export
vofi_run <- function(model, n_sim = 1L, seed = NULL, store = c("auto", "full", "bands", "kpi"),
                     chunk_size = getOption("vofi.chunk_size", 2000L)) {
  if (!inherits(model, "vofi_model")) {
    vofi_abort("engine.not_model", arg = "model", .class = "vofi_error_input")
  }
  n_sim <- utl_check_whole(n_sim, "n_sim", min = 1)
  store <- utl_match_arg(store, c("auto", "full", "bands", "kpi"), "store")
  if (n_sim > 1L) {
    if (store == "auto") store <- "bands"
    return(vofi_mc(model, n_sim = n_sim, seed = seed, store = store, chunk_size = chunk_size))
  }
  if (!is.null(seed)) utl_check_seed(seed)
  # Einzellauf (9.2, 13.1): das Ergebnis enthaelt immer den vollstaendigen Ledger
  if (store %in% c("bands", "kpi")) vofi_inform("engine.store_single_full", store = store)
  store <- "full"
  t0 <- proc.time()[["elapsed"]]
  if (eng_has_prepay(model)) {
    vofi_warn("engine.prepay_heuristic", .class = "vofi_warning_plausibility")
  }
  res <- eng_run_chunk(model, blocks = 1L, seed = seed, mode = "deterministic", store = store)
  eng_result(model, res, mode = "deterministic", store = store, seed = seed,
             runtime = proc.time()[["elapsed"]] - t0)
}

#' Einzellauf einer Simulation nachrechnen
#'
#' Rechnet Lauf `i` einer Simulation mit vollständiger VoFi-Tabelle nach; das Ergebnis ist
#' identisch zum Lauf im Batch (Spec 00, Abschnitt 11.4).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Objekt der Klasse `vofi_mc_result`.
#' @param i globale Laufnummer.
#' @return Objekt der Klasse `vofi_result`.
#' @family Rechnen
#' @export
vofi_sim <- function(x, i) {
  vofi_abort("core.not_implemented", fun = "vofi_sim",
             .class = "vofi_error_not_implemented")
}

#' Chunk-Lauf (9.2 Stufen 1-9)
#'
#' Phase-0-Minimalfassung, Eigentümer: WS-D. Im Modus `"deterministic"` sind die Ziehungen
#' leer (11.9); für `"mc"` und `"design"` fehlt in Phase 0 der Sampler (WS-C).
#' @return Liste nach 9.2 (`kpis`, `kpi_na`, `kpi_series`, `flags`, `inputs`, `features`,
#'   `ledger`, `decision`, `band_values`, `opp`, `paths`, `registers`, `draws`, `checks`,
#'   `draws_meta`).
#' @noRd
eng_run_chunk <- function(model, blocks, seed, mode = c("mc", "deterministic", "design"),
                          store = c("full", "bands", "kpi"), design = NULL, bands = NULL,
                          raw = NULL, extra_rows = NULL, return_paths = character(),
                          kpis = NULL) {
  mode <- utl_match_arg(mode, c("mc", "deterministic", "design"), "mode")
  store <- utl_match_arg(store, c("full", "bands", "kpi"), "store")
  if (!identical(mode, "deterministic") || !is.null(raw) || !is.null(design)) {
    eng_unsupported("smp_draw()/smp_design()")
  }
  if (!is.null(extra_rows)) eng_unsupported("eng_run_chunk(extra_rows)")
  eng_run_draws(model, draws = NULL, store = store, return_paths = return_paths, kpis = kpis)
}

#' Lauf mit vorgegebenen Ziehungen (Stufen 2-9; derselbe Codepfad für N = 1 und N > 1)
#'
#' Phase-0-Minimalfassung, Eigentümer: WS-D.
#' @param model `vofi_model`.
#' @param draws `NULL` (deterministisch) oder `vofi_draws` (z. B. aus `fake_draws()`).
#' @param store `"full"` (Ledger aller Läufe) oder `"kpi"`.
#' @param return_paths Namen der zurückzugebenden Pfade (9.2).
#' @param kpis `NULL` (alle Kennzahlen des Modells) oder Teilmenge.
#' @return Liste wie `eng_run_chunk()`.
#' @noRd
eng_run_draws <- function(model, draws = NULL, store = "full", return_paths = character(),
                          kpis = NULL) {
  env <- eng_engine_env(model)
  ctx <- eng_context(model, draws, env)
  env$stage <- "flows"
  exo <- eng_flows(model, ctx, env)
  eng_auto_amounts(model, ctx, exo$ledger, env)
  env$stage <- "balance"
  core <- eng_balance(model, ctx, exo$ledger, engine_env = env)
  opp <- eng_opportunity(model, ctx, core)
  core$opp <- list(BS = opp$BS, EW = opp$EW, ledger = opp$ledger)
  core$flags$opp_limit_breach <- opp$limit_breach
  checks <- eng_checks(core)
  eng_flag_conditions(core$flags)
  env$stage <- "kpi"
  env$rebalance <- function(extra_out = NULL) {
    eng_balance(model, ctx, exo$ledger, extra_out = extra_out, book = FALSE, engine_env = env)
  }
  sel <- if (is.null(kpis)) model$kpis else model$kpis[intersect(kpis, names(model$kpis))]
  kp <- kpi_compute(sel, core, ctx)
  n <- ctx$n
  paths <- list(net_position = core$stocks$BS, opp_net_position = opp$BS,
                dep_balance = core$stocks$G, od_balance = core$stocks$KK,
                equity_calls = core$ledger$values$equity_call + core$ledger$values$shortfall)
  inputs <- data.frame(sim = ctx$sims)
  if (!is.null(draws)) for (k in names(draws$static)) inputs[[k]] <- draws$static[[k]]
  list(kpis = kp$scalar, kpi_na = kp$na, kpi_series = kp$series, flags = core$flags,
       inputs = inputs, features = data.frame(sim = ctx$sims),
       ledger = if (identical(store, "full")) core$ledger else NULL, decision = NULL,
       band_values = list(), opp = core$opp, paths = paths[intersect(return_paths, names(paths))],
       registers = exo$registers, draws = draws, checks = checks, draws_meta = list(),
       core = core, n = n)
}

#' Ergebnisobjekt eines deterministischen Laufs (13.1)
#' @noRd
eng_result <- function(model, res, mode, store, seed, runtime) {
  spec <- model$spec
  p <- spec$project
  persp <- p$perspective
  report_mode <- p$report_mode %||% "auto"
  if (identical(report_mode, "auto")) {
    report_mode <- if (utl_is_string(persp) && startsWith(persp, "wu_")) "expert" else
      "household"
  }
  existing <- vocab("project_type")$existing_building
  primary <- spec$analysis$primary_kpi %||% "auto"
  if (identical(primary, "auto")) {
    primary <- if ((p$project_type %||% "") %in% existing &&
                     identical(p$comparison_mode %||% "absolute", "absolute")) {
      "delta_vs_reference"
    } else {
      "delta_terminal_value"
    }
  }
  meta <- list(
    package_version = as.character(utils::packageVersion("vofi")),
    contract_version = VOFI_CONTRACT_VERSION, schema_version = 1L,
    scenario_id = spec$meta$scenario_id %||% NA_character_,
    project_id = spec$meta$project_id %||% spec$meta$scenario_id %||% NA_character_,
    building_id = spec$building$building_id %||% NA_character_,
    variant = spec$variant %||% "base", scenario_set = spec$scenario_set, mode = mode,
    n_sim = res$n, seed = seed, sim_index = 1L, legal_state = p$legal_state,
    pending_reforms = p$pending_reforms %||% character(0), library = spec$library,
    library_version = NA_character_, defaults = attr(spec, "defaults_meta") %||% list(),
    tax_module = spec$tax$module %||% "none",
    perspective = persp, tax_regime = p$tax_regime, report_mode = report_mode,
    comparison_mode = p$comparison_mode %||% "absolute", primary_kpi = primary, store = store,
    runtime_sec = runtime, created = Sys.time(), r_version = R.version.string,
    notes = character(0)
  )
  new_vofi_result(list(
    spec = spec, grid = model$grid, model_hash = model$hash, ledger = res$ledger,
    kpis = res$kpis, kpi_na = res$kpi_na, kpi_series = res$kpi_series,
    opportunity = list(ledger = res$opp$ledger, BS = res$opp$BS, EW = res$opp$EW),
    checks = res$checks, flags = res$flags, registers = res$registers, draws = res$draws,
    decision = NULL, traffic_light = NULL, meta = meta
  ))
}
