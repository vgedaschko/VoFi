# Lauf-Stufen, Chunk-Lauf, Einzellauf (WS-D, Spec 00 Abschnitte 9.2, 9.9, 9.11, 11.4).
# vofi_run(): n_sim = 1 deterministisch (Kompositum bei Entscheidungsknoten: realisierter Zweig,
# der andere in decision$alternative), n_sim > 1 Delegation an vofi_mc() (WS-G).
# eng_run_chunk(): Stufen 1-9 eines Chunks (Ziehungen ueber den Sampler von WS-C:
# smp_draw()/smp_materialize()/smp_design(), Kontext, Komponenten, auto/topup, Ausgleich,
# Unterlassungsalternative, Invarianten, Kennzahlen, Speicherung nach store mit return_paths,
# Baendern, Entscheidungswerten). eng_run_draws(): Stufen 2-9 mit vorgegebenen Ziehungen
# (derselbe Codepfad fuer N = 1 und N > 1; Tests mit fake_draws()). vofi_sim(): Lauf i einer
# Simulation (nur Block b neu, identisch zum Batch). Markierungen und die Warnung zu loan_prepay
# melden vofi_run()/vofi_sim() (bzw. vofi_mc()) einmal je Lauf, nicht je Chunk.

#' VoFi berechnen
#'
#' Berechnet den VoFi deterministisch (`n_sim = 1`) oder als Monte-Carlo-Simulation (`n_sim > 1`,
#' Delegation an [vofi_mc()]) (Spec 00, Abschnitt 9.2). Der deterministische Lauf verwendet die
#' Basisfallwerte aller Größen (Schichten 0–5, 7, 8; Abschnitt 11.9). Hat die Variante einen
#' Entscheidungsknoten der Förderzusage (Abschnitt 9.11), ist das Ergebnis das des realisierten
#' Zweigs; das Ergebnis des anderen Zweigs steht in `decision$alternative`.
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
  eng_warn_prepay(model)
  dec <- model$decision
  if (is.null(dec)) return(eng_run_single(model, seed))
  b <- as.integer(dec$branch %||% 1L)
  realized <- if (b == 1L) model else dec$fallback
  other <- if (b == 1L) dec$fallback else model
  res <- eng_run_single(realized, seed)
  alt <- eng_run_single(other, seed, signal = FALSE)
  res$decision <- list(funding_id = dec$funding_id, fallback_variant = dec$fallback_variant,
                       p_approval = dec$p, branch = b, alternative = alt)
  res
}

#' Deterministischer Einzellauf eines Modells als `vofi_result` (13.1)
#' @param signal Markierungen melden (9.8).
#' @noRd
eng_run_single <- function(model, seed = NULL, signal = TRUE) {
  t0 <- proc.time()[["elapsed"]]
  res <- eng_run_chunk(model, blocks = 1L, seed = seed, mode = "deterministic", store = "full")
  if (signal) eng_flag_conditions(res$flags)
  eng_result(model, res, mode = "deterministic", store = "full", seed = seed,
             runtime = proc.time()[["elapsed"]] - t0)
}

#' Warnung zum Heuristik-Charakter von Ü3 (loan_prepay), einmal je Lauf (8.9, R-29)
#' @noRd
eng_warn_prepay <- function(model) {
  if (eng_has_prepay(model)) {
    vofi_warn("engine.prepay_heuristic", .class = "vofi_warning_plausibility")
  }
  invisible(NULL)
}

#' Einzellauf einer Simulation nachrechnen
#'
#' Rechnet Lauf `i` einer Simulation mit vollständiger VoFi-Tabelle nach; nur Block
#' b = ⌈i / block_size⌉ wird neu gezogen, das Ergebnis ist identisch zum Lauf im Batch (Spec 00,
#' Abschnitt 11.4). Bei einem Entscheidungsknoten (Abschnitt 9.11) ist es das Ergebnis des im
#' Lauf realisierten Zweigs (gemeinsame Rohziehungen von Variante und Ausweichvariante).
#'
#' @param x Objekt der Klasse `vofi_mc_result` (mit `model`, `meta$seed` und
#'   `meta$block_size`).
#' @param i globale Laufnummer.
#' @return Objekt der Klasse `vofi_result`.
#' @family Rechnen
#' @examplesIf interactive()
#' model <- vofi_build(vofi_read_scenario(vofi_example("skeleton")))
#' mc <- vofi_mc(model, n_sim = 200, seed = 1)
#' vofi_sim(mc, 17)$kpis
#' @export
vofi_sim <- function(x, i) {
  if (!inherits(x, "vofi_mc_result") || !inherits(x$model, "vofi_model")) {
    vofi_abort("engine.not_mc_result", arg = "x", .class = "vofi_error_input")
  }
  n_sim <- as.integer(x$meta$n_sim %||% nrow(x$kpis))
  i <- utl_check_whole(i, "i", min = 1, max = n_sim)
  model <- eng_sim_model(x$model, x$meta)
  m <- as.integer(x$meta$block_size %||% model$sampler$settings$block_size %||% 200L)
  seed <- x$meta$seed %||% model$sampler$settings$seed
  if (is.null(seed)) {
    vofi_abort("engine.seed_missing", .class = "vofi_error_input")
  }
  b <- as.integer((i - 1L) %/% m + 1L)
  local <- as.integer(i - (b - 1L) * m)
  dec <- model$decision
  t0 <- proc.time()[["elapsed"]]
  eng_warn_prepay(model)
  if (is.null(dec)) {
    ch <- eng_run_chunk(model, blocks = b, seed = seed, mode = "mc", store = "full")
    res <- eng_sim_result(model, ch, local, i, x$meta, t0)
    eng_flag_conditions(res$flags)
    return(res)
  }
  fb <- eng_sim_model(dec$fallback, x$meta)
  union <- eng_smp_fun("smp_plan_union")(list(model$sampler, fb$sampler))
  raw <- eng_smp_fun("smp_sample")(union, b, seed)
  cv <- eng_run_chunk(model, blocks = b, seed = seed, mode = "mc", store = "full", raw = raw)
  cf <- eng_run_chunk(fb, blocks = b, seed = seed, mode = "mc", store = "full", raw = raw)
  branch <- as.integer(round((cv$decision %||% rep(1, cv$n))[local]))
  rv <- eng_sim_result(model, cv, local, i, x$meta, t0)
  rf <- eng_sim_result(fb, cf, local, i, x$meta, t0)
  res <- if (branch == 1L) rv else rf
  res$decision <- list(funding_id = dec$funding_id, fallback_variant = dec$fallback_variant,
                       p_approval = dec$p, branch = branch,
                       alternative = if (branch == 1L) rf else rv)
  eng_flag_conditions(res$flags)
  res
}

#' Modell eines Einzellaufs mit den Einstellungen der Simulation (Blockgröße, Verfahren)
#' @noRd
eng_sim_model <- function(model, meta) {
  if (is.list(model$sampler) && is.list(model$sampler$settings)) {
    for (f in c("block_size", "sampling", "antithetic", "copula", "replicates")) {
      if (!is.null(meta[[f]])) model$sampler$settings[[f]] <- meta[[f]]
    }
  }
  model
}

#' Lauf `local` eines Chunks als `vofi_result` (13.1)
#' @noRd
eng_sim_result <- function(model, ch, local, i, meta, t0) {
  one <- eng_chunk_subset(ch, local)
  res <- eng_result(model, one, mode = "mc", store = "full", seed = meta$seed,
                    runtime = proc.time()[["elapsed"]] - t0)
  res$meta$sim_index <- as.integer(i)
  res$meta$n_sim <- as.integer(meta$n_sim %||% res$meta$n_sim)
  res
}

#' Lauf `i` eines Chunk-Ergebnisses (alle Felder mit n Zeilen)
#' @noRd
eng_chunk_subset <- function(ch, i) {
  sub_df <- function(d) {
    if (!is.data.frame(d) || nrow(d) < max(i)) return(d)
    out <- d[i, , drop = FALSE]
    rownames(out) <- NULL
    out
  }
  sub_m <- function(m) if (is.matrix(m)) m[i, , drop = FALSE] else m
  out <- ch
  for (f in c("kpis", "kpi_na", "flags", "inputs", "features")) out[[f]] <- sub_df(ch[[f]])
  if (!is.null(ch$ledger)) out$ledger <- ledger_subset_sims(ch$ledger, i)
  out$kpi_series <- lapply(ch$kpi_series, function(s) {
    s$values <- sub_m(s$values)
    s
  })
  out$opp <- list(BS = sub_m(ch$opp$BS), EW = ch$opp$EW[i],
                  ledger = if (is.null(ch$opp$ledger)) NULL else
                    ledger_subset_sims(ch$opp$ledger, i),
                  checks = ch$opp$checks, flags = sub_df(ch$opp$flags))
  out$paths <- lapply(ch$paths, sub_m)
  out$band_values <- lapply(ch$band_values, sub_m)
  out$decision <- if (is.null(ch$decision)) NULL else ch$decision[i]
  if (!is.null(ch$draws)) out$draws <- reg_draws_subset(ch$draws, i)
  out$n <- length(i)
  out
}

#' Funktion des Samplers (WS-C) zur Laufzeit auflösen (11.2, 11.8)
#'
#' Der Sampler entsteht parallel (Welle 1b); fehlt eine Funktion, meldet die Engine
#' `vofi_error_not_implemented` statt eines undefinierten Aufrufs.
#' @param name `"smp_plan"`, `"smp_draw"`, `"smp_sample"`, `"smp_materialize"`,
#'   `"smp_design"` oder `"smp_plan_union"`.
#' @return Funktion.
#' @noRd
eng_smp_fun <- function(name) {
  f <- get0(name, envir = topenv(environment(eng_smp_fun)), mode = "function",
            inherits = FALSE)
  if (is.null(f)) {
    vofi_abort("core.not_implemented", fun = paste0(name, "()"),
               .class = "vofi_error_not_implemented")
  }
  f
}

#' Ziehungen eines Chunks (9.2 Stufe 1)
#' @return `NULL` (deterministisch) oder `vofi_draws`.
#' @noRd
eng_chunk_draws <- function(model, blocks, seed, mode, design = NULL, raw = NULL) {
  if (identical(mode, "deterministic")) {
    if (!is.null(raw) || !is.null(design)) {
      vofi_abort("engine.det_no_draws", .class = "vofi_error_input")
    }
    return(NULL)
  }
  plan <- model$sampler
  if (is.null(plan)) {
    vofi_abort("core.not_implemented", fun = "smp_plan()",
               .class = "vofi_error_not_implemented")
  }
  draws <- if (identical(mode, "design")) {
    if (is.null(design)) vofi_abort("engine.design_missing", .class = "vofi_error_input")
    eng_smp_fun("smp_design")(plan, model$grid, design)
  } else if (!is.null(raw)) {
    eng_smp_fun("smp_materialize")(raw, plan, model$grid)
  } else {
    if (is.null(seed)) vofi_abort("engine.seed_missing", .class = "vofi_error_input")
    eng_smp_fun("smp_draw")(plan, model$grid, blocks, seed, "mc")
  }
  if (!inherits(draws, "vofi_draws")) {
    vofi_abort("core.contract.draws", what = "class", .class = "vofi_error_contract")
  }
  validate_vofi_draws(draws, model$grid$T)
  draws
}

#' Chunk-Lauf (9.2 Stufen 1-9)
#'
#' @param model `vofi_model`.
#' @param blocks Blöcke des Chunks (globale Blocknummern, 11.4).
#' @param seed Seed der Simulation.
#' @param mode `"mc"`, `"deterministic"` oder `"design"`.
#' @param store `"full"` (Ledger, Ziehungen), `"bands"` (Bandzeilen) oder `"kpi"`.
#' @param design Data Frame der Designzeilen (Modus `"design"`, 11.11).
#' @param bands Ledger-Schlüssel bzw. Pfadnamen der Bänder (Default aus
#'   `stochastic.settings.bands`).
#' @param raw Rohziehungen aus `smp_sample()` (CRN, 11.10) oder `NULL`.
#' @param extra_rows `vofi_ledger` mit exogenen Zusatzzeilen (9.6 Nr. 6) oder `NULL`.
#' @param return_paths Namen zurückzugebender Pfade (`"net_position"`, `"opp_net_position"`,
#'   `"wealth"`, `"dep_balance"`, `"od_balance"`, `"equity_calls"`).
#' @param kpis `NULL` (alle Kennzahlen des Modells) oder Teilmenge.
#' @return Liste nach 9.2 (`kpis`, `kpi_na`, `kpi_series`, `flags`, `inputs`, `features`,
#'   `ledger`, `decision`, `band_values`, `opp`, `paths`, `registers`, `draws`, `checks`,
#'   `draws_meta`; zusätzlich `n`, `sims`, `blocks`).
#' @noRd
eng_run_chunk <- function(model, blocks, seed, mode = c("mc", "deterministic", "design"),
                          store = c("full", "bands", "kpi"), design = NULL, bands = NULL,
                          raw = NULL, extra_rows = NULL, return_paths = character(),
                          kpis = NULL) {
  mode <- utl_match_arg(mode, c("mc", "deterministic", "design"), "mode")
  store <- utl_match_arg(store, c("full", "bands", "kpi"), "store")
  draws <- eng_chunk_draws(model, blocks, seed, mode, design, raw)
  eng_run_draws(model, draws = draws, store = store, return_paths = return_paths, kpis = kpis,
                bands = bands, extra_rows = extra_rows)
}

#' Lauf mit vorgegebenen Ziehungen (Stufen 2-9; derselbe Codepfad für N = 1 und N > 1)
#'
#' @param model `vofi_model`.
#' @param draws `NULL` (deterministisch) oder `vofi_draws` (z. B. aus `fake_draws()`).
#' @param store `"full"`, `"bands"` oder `"kpi"`.
#' @param return_paths Namen der zurückzugebenden Pfade (9.2).
#' @param kpis `NULL` (alle Kennzahlen des Modells) oder Teilmenge.
#' @param bands Bandzeilen (nur `store = "bands"`).
#' @param extra_rows exogene Zusatzzeilen oder `NULL`.
#' @return Liste wie `eng_run_chunk()`.
#' @noRd
eng_run_draws <- function(model, draws = NULL, store = "full", return_paths = character(),
                          kpis = NULL, bands = NULL, extra_rows = NULL) {
  store <- utl_match_arg(store, c("full", "bands", "kpi"), "store")
  env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, draws, env)
  env$stage <- "flows"
  exo <- eng_flows(model, ctx, env, extra_rows)
  eng_auto_amounts(model, ctx, exo$ledger, env)
  env$stage <- "balance"
  core <- eng_balance(model, ctx, exo$ledger, engine_env = env)
  opp <- eng_opportunity(model, ctx, core, env)
  core$flags$opp_limit_breach <- opp$limit_breach
  checks <- eng_checks(core)
  opp_checks <- eng_checks(opp$core)
  full <- identical(store, "full")
  core$opp <- list(BS = opp$BS, EW = opp$EW, ledger = if (full) opp$ledger else NULL)
  env$stage <- "kpi"
  env$rebalance <- function(extra_out = NULL) {
    eng_balance(model, ctx, exo$ledger, extra_out = extra_out, book = FALSE, engine_env = env)
  }
  sel <- if (is.null(kpis)) model$kpis else model$kpis[intersect(kpis, names(model$kpis))]
  kp <- kpi_compute(sel, core, ctx)
  out <- eng_store_chunk(model, ctx, core, opp, kp, draws, store, return_paths, bands)
  out$registers <- exo$registers
  out$checks <- checks
  out$opp$checks <- opp_checks
  out$opp$flags <- opp$core$flags
  out
}

#' Ergebnisobjekt eines Laufs (13.1)
#' @param res Chunk-Ergebnis mit n = 1 (bzw. n Läufen bei internen Läufen).
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
    library_version = eng_library_version(), defaults = attr(spec, "defaults_meta") %||% list(),
    tax_module = spec$tax$module %||% "none",
    perspective = persp, tax_regime = p$tax_regime, report_mode = report_mode,
    comparison_mode = p$comparison_mode %||% "absolute", primary_kpi = primary, store = store,
    runtime_sec = runtime, created = Sys.time(), r_version = R.version.string,
    notes = character(0)
  )
  new_vofi_result(list(
    spec = spec, grid = model$grid, model_hash = model$hash, ledger = res$ledger,
    kpis = res$kpis, kpi_na = res$kpi_na, kpi_series = res$kpi_series,
    opportunity = list(ledger = res$opp$ledger, BS = res$opp$BS, EW = res$opp$EW,
                       checks = res$opp$checks, flags = res$opp$flags),
    checks = res$checks, flags = res$flags, registers = res$registers, draws = res$draws,
    decision = NULL, traffic_light = NULL, meta = meta
  ))
}

#' Stand der Paketbibliothek `JJJJ.MM.n` (inst/extdata/library/VERSION, 4.9, R-80)
#' @noRd
eng_library_version <- function() {
  f <- system.file("extdata", "library", "VERSION", package = "vofi")
  if (!nzchar(f) || !file.exists(f)) return(NA_character_)
  v <- trimws(readLines(f, warn = FALSE, encoding = "UTF-8"))
  v <- v[nzchar(v) & !startsWith(v, "#")]
  if (length(v) == 0L) NA_character_ else v[1L]
}
