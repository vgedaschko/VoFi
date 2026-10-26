# Prüfkit der Vertragstests (Integrator, Spec 00 Abschnitt 5.6).
# Liegt im Paket (nicht in tests/), damit vofi_check_type() für Nutzer und unter R CMD check
# lauffähig ist. Die Testhelfer in tests/testthat/helper-*.R sind dünne Hüllen um diese Funktionen.
#
# Konventionen des Prüfkits (verbindlich für die `example`-Angaben der Typen):
# - Raster: reg_test_grid("annual") = Jahresraster ab 2027-01-01, H = 6 (T = 6, T+1 = 7 = n);
#   reg_test_grid("mixed") = Bauphase 9 Monate monatlich, dann Kalenderjahre (gleiches end_date).
# - Spezifikation: reg_test_spec() mit Perspektive wu_kommunal, Markt (inflation, rent_growth,
#   construction_price_index, mortgage_rate, co2_price, energy_price.<träger>, ...), Gebäude,
#   Haushalt, Konten, Analyse und den Registereinträgen asset "b1" (gebaeude_wohnen) und
#   measure "m1" (daemmung_fassade), auf die Beispiele verweisen dürfen.
# - Beispielkomponente: id "x" (bzw. `example$id`), Sammlung components; Typ equity und alle
#   Instrumente in financing. Abhängigkeiten stehen als Rohkomponenten in `example$.deps`
#   (benannte Liste id -> list(type = ..., ...)), Sammlung abweichend über `example$.collection`.
# - Ziehungen: reg_fake_draws() variiert alle numerischen Parameter des Beispiels, die nicht
#   deterministic_only sind: Konstanten mit Basis * (1 + 0.1 * (i - 1)) (Art share:
#   Basis * (1 - 0.1 * (i - 1) / n)), Periodenreihen (series_t) als Pfad.
# - Kontext: eng_context_from_parts() (WS-D) mit einer Attrappe der Engine-Umgebung
#   (`stage`, `rebalance(extra_out)`, `auto(id)`), siehe reg_engine_env().
# - Steuermodule: das `example` eines Steuermoduls MUSS Nullparameter tragen (T1: Zahlung 0).
# - Kennzahlen: reg_example_core() liefert ein synthetisches, vertragsgemäßes core (12.1) mit
#   Attribut "ctx" (zugehöriger Kontext mit funktionsfähiger rebalance()-Attrappe), sofern
#   eng_context_from_parts() verfügbar ist; sonst über reg_example_ctx(core).

# ---------------------------------------------------------------------------------------------
# Raster, Spezifikation, Komponenten
# ---------------------------------------------------------------------------------------------

#' Prüfraster (5.6)
#' @param which `"annual"` (G1-artig, 2027-01-01, H = 6, C = 0) oder `"mixed"` (G4-artig,
#'   C = 9, cs = 1, `calendar`; gleiches `end_date` 2033-01-01).
#' @return `vofi_grid`.
#' @noRd
reg_test_grid <- function(which = c("annual", "mixed")) {
  which <- utl_match_arg(which, c("annual", "mixed"), "which")
  if (which == "annual") {
    vofi_time_grid(as.Date("2027-01-01"), 6L)
  } else {
    vofi_time_grid(as.Date("2027-01-01"), 6L, construction_months = 9L,
                   construction_step_months = 1L, operation_alignment = "calendar")
  }
}

#' Rohe Marktannahmen des Prüfkits
#' @noRd
reg_test_market_raw <- function() {
  list(inflation = 0.02, rent_growth = 0.015, rent_growth_new = 0.02,
       construction_price_index = 0.03, maintenance_index = 0.025, land_value_growth = 0.02,
       market_value_growth = 0.015, mortgage_rate = 0.04, co2_price = 55,
       energy_price = list(gas = 0.12, power = 0.35, district_heating = 0.15, oil = 0.11),
       energy_network_fee = list(gas = 0.01, power = 0.08), bio_fuel_premium = 0.02)
}

#' Wert als Knoten (4.5): Zahl -> const, `{ref: ...}` -> ref, Knoten bleiben, übrige Wertformen
#' über node_normalize() (WS-A)
#' @noRd
reg_node <- function(x, path = NULL) {
  if (is.numeric(x) && length(x) == 1L) return(node_const(x))
  if (is.list(x) && utl_is_string(x[["kind"]])) return(x)
  if (is_map(x) && identical(utl_value_form_kind(x), "ref") && length(x) == 1L) {
    return(node_ref(x[["ref"]]))
  }
  node_normalize(x, NULL, path)
}

#' Numerische Blätter eines Blocks in Knoten überführen
#' @noRd
reg_normalize_block <- function(x, prefix) {
  if (is.null(x)) return(list())
  for (p in path_leaves(x)) {
    v <- path_get(x, p)
    if (is.numeric(v) || is_value_form(v)) x <- path_set(x, p, reg_node(v, path_join(prefix, p)))
  }
  x
}

#' Spezifikation des Prüfkits (vofi_spec)
#'
#' @param grid `vofi_grid`.
#' @param perspective Perspektive.
#' @param legal_state Rechtsstand.
#' @param components,financing bereits normalisierte Komponenten (benannte Listen).
#' @param market rohe Marktannahmen (Default: Prüfkit-Markt); werden normalisiert.
#' @param project,building,household,accounts,analysis rohe Ergänzungen (werden gemischt).
#' @return `vofi_spec`.
#' @noRd
reg_test_spec <- function(grid, perspective = "wu_kommunal",
                          legal_state = as.Date("2026-10-25"), components = list(),
                          financing = list(), market = NULL, project = list(),
                          building = list(), household = list(), accounts = list(),
                          analysis = list()) {
  vd <- grid$valuation_date
  regimes <- vocab("tax_regime")$from_perspective
  st <- grid$settings
  proj <- list(
    perspective = perspective, tax_regime = regimes[[perspective]] %||% NA_character_,
    project_type = "neubau", comparison_mode = "absolute", valuation_date = vd,
    horizon_years = st$horizon_years %||% as.integer(round(grid$tau[grid$T + 1L])),
    application_date = vd, legal_state = utl_as_date(legal_state, "legal_state"),
    pending_reforms = character(0), federal_state = NULL,
    price_base_year = utl_year(vd) - 1L, construction_delay_months = 0,
    reference_variant = "base", report_mode = "auto"
  )
  proj <- deep_merge(proj, project)
  proj$construction_delay_months <- reg_node(proj$construction_delay_months,
                                             "project.construction_delay_months")
  bld <- deep_merge(list(building_id = "b1", n_units = 12L, living_area_m2 = 900,
                         net_floor_area_m2 = 1100), building)
  hh <- deep_merge(list(net_income_month_eur = 4500, income_growth = list(ref = "market.inflation"),
                        savings_capacity_month_eur = 800, n_children_u18 = 0L,
                        current_rent_month_eur = 900, expected_income_tax_eur_pa = 9000),
                   household)
  acc <- deep_merge(list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08,
                         overdraft_limit_eur = Inf, penalty_spread_pa = 0.02,
                         min_liquidity_eur = 0, deposit_withholding_tax_share = 0,
                         deposit_tax_allowance_eur_pa = 0, overdraft_flag_threshold_eur = 25000,
                         surplus_order = c("od_repay", "dep_invest"),
                         deficit_order = c("dep_withdraw", "od_draw", "equity_call"),
                         prepay = list(buffer_eur = 0, min_spread_pa = 0)),
                    accounts)
  ana <- deep_merge(list(kpis = "default", primary_kpi = "auto",
                         allow_opportunity_reference = FALSE, deterministic_point = "mode",
                         thresholds = list(dscr = 1.2, burden_share = 0.4,
                                           warm_rent_increase_eur_m2 = 0.5, roe_hurdle = 0.04),
                         stabilization_year = NULL, lending_value_haircut = 0.2,
                         rv_path_basis = "auto", restrictions = c("dscr", "liquidity"),
                         traffic_light = list(green_prob = 0.7, red_prob = 0.4,
                                              restriction_prob = 0.3),
                         mandatory_sensitivities = list(), tenant_view = TRUE),
                    analysis)
  num_fields <- function(x, fields, prefix) {
    for (f in intersect(fields, names(x))) {
      if (!is.null(x[[f]]) && (is.numeric(x[[f]]) || is_value_form(x[[f]]))) {
        x[[f]] <- reg_node(x[[f]], path_join(prefix, f))
      }
    }
    x
  }
  bld <- num_fields(bld, c("living_area_m2", "net_floor_area_m2", "market_value_eur",
                           "land_value_eur", "existing_value_eur"), "building")
  hh <- num_fields(hh, c("net_income_month_eur", "income_growth", "savings_capacity_month_eur",
                         "current_rent_month_eur", "expected_income_tax_eur_pa"), "household")
  acc <- num_fields(acc, c("deposit_rate_pa", "overdraft_rate_pa", "overdraft_limit_eur",
                           "penalty_spread_pa", "min_liquidity_eur"), "accounts")
  new_vofi_spec(list(
    meta = list(scenario_id = "testkit", project_id = "testkit", title = "testkit"),
    project = proj,
    grid = list(construction_months = st$construction_months %||% 0L,
                construction_step_months = st$construction_step_months %||% 12L,
                operation_step_months = st$operation_step_months %||% 12L,
                operation_alignment = st$operation_alignment %||% "calendar",
                periods_months = st$periods_months),
    building = bld, household = hh, unit_groups = list(), measures = list(), energy = list(),
    funding = list(), components = components, financing = financing, accounts = acc,
    market = reg_normalize_block(market %||% reg_test_market_raw(), "market"),
    residual_value = list(method = "zero", sale_cost_share = 0.03),
    tax = list(module = "none", params = list()), analysis = ana, stochastic = list(),
    registers = list(
      assets = list(vofi_asset("b1", "gebaeude_wohnen", vd, land_share = 0.2)),
      measures = list(vofi_measure("m1", "daemmung_fassade", asset_id = "b1"))
    ),
    legal = list(), variant = "base", scenario_set = NULL
  ))
}

#' Sammlung einer Komponente (components bzw. financing)
#' @noRd
reg_collection <- function(def, example = NULL) {
  if (!is.null(example[[".collection"]])) return(example[[".collection"]])
  if (identical(def$kind, "instrument") || identical(def$name, "equity")) "financing" else
    "components"
}

#' Normalisierte Komponente aus einem Rohbeispiel (Schicht 0 eingesetzt)
#' @param def `vofi_typedef` (flow oder instrument).
#' @param example Rohform wie in YAML (Default `def$example`).
#' @param id id der Komponente (Default `example$id` bzw. `"x"`).
#' @return Liste mit Metafeldern und flachen Parameterknoten (4.13).
#' @noRd
reg_example_component <- function(def, example = NULL, id = NULL) {
  ex <- example %||% def$example %||% list()
  id <- id %||% ex[["id"]] %||% "x"
  coll <- reg_collection(def, ex)
  comp <- list(id = id, type = def$name)
  for (f in setdiff(reg_reserved_fields(), c("id", "type"))) comp[f] <- list(ex[[f]])
  comp$origin <- comp$origin %||% "scenario"
  comp$after <- as.character(unlist(comp$after))
  for (p in names(def$params)) {
    pp <- def$params[[p]]
    raw <- if (!is.null(ex[[p]])) ex[[p]] else pp$default
    comp[p] <- list(if (is.null(raw)) NULL else node_normalize(raw, pp, path_join(coll, id, p)))
  }
  comp
}

#' Attrappe der privaten Engine-Umgebung (6.1 Nr. 3)
#'
#' `ctx$rebalance(extra_out)` und `ctx$auto(id)` MÜSSEN an `engine_env$rebalance` bzw.
#' `engine_env$auto` delegieren; `engine_env$stage` (`"flows"`, `"balance"`, `"kpi"`) steuert,
#' ob `rebalance()` zulässig ist (nur `"kpi"`). `deps` = deklarierte Abhängigkeiten der
#' geprüften Komponente (`NULL` = keine Prüfung); ein Zugriff auf andere Komponenten über
#' `ctx$component()`, `ctx$component_base()` oder `ctx$rows()` ist ein Vertragsfehler (F1).
#' @noRd
reg_engine_env <- function(stage = "flows", rebalance = NULL, auto = NULL, deps = NULL) {
  env <- new.env(parent = emptyenv())
  env$stage <- stage
  env$deps <- deps
  env$rebalance <- rebalance %||% function(extra_out = NULL) {
    vofi_abort("core.testkit.no_rebalance", .class = "vofi_error_contract")
  }
  env$auto <- auto %||% function(id) {
    vofi_abort("core.testkit.no_auto", id = id, .class = "vofi_error_contract")
  }
  env
}

#' Prüfaufbau für einen Typ: Spezifikation, Komponente, Abhängigkeiten, Kontext
#' @return Liste `ctx`, `comp`, `spec`, `deps` (gebaute `vofi_flows` je id).
#' @noRd
reg_test_setup <- function(def, n, grid, draws = NULL, example = NULL) {
  ex <- example %||% def$example %||% list()
  n <- as.integer(n)
  if (is.null(draws) && n > 1L) draws <- new_vofi_draws("mc", n = n)
  mode <- if (is.null(draws)) "deterministic" else draws$mode
  spec <- reg_test_spec(grid)
  dep_raw <- ex[[".deps"]] %||% list()
  dep_defs <- list()
  for (id in names(dep_raw)) {
    raw <- dep_raw[[id]]
    ddef <- reg_get(if (reg_has("flow", raw$type)) "flow" else "instrument", raw$type)
    dcomp <- reg_example_component(ddef, raw, id)
    spec <- path_set(spec, path_join(reg_collection(ddef, raw), id), dcomp)
    dep_defs[[id]] <- list(def = ddef, comp = dcomp)
  }
  comp <- NULL
  if (def$kind %in% c("flow", "instrument")) {
    comp <- reg_example_component(def, ex)
    spec <- path_set(spec, path_join(reg_collection(def, ex), comp$id), comp)
  }
  deps <- list()
  for (id in names(dep_defs)) {
    dctx <- eng_context_from_parts(grid, spec, draws = draws, components = deps,
                                   components_base = deps, mode = mode,
                                   engine_env = reg_engine_env("flows"))
    deps[[id]] <- dep_defs[[id]]$def$build(dep_defs[[id]]$comp, dctx)
  }
  declared <- if (is.null(comp)) NULL else {
    eng_component_deps(comp, def, c(names(dep_raw), comp$id))
  }
  ctx <- eng_context_from_parts(grid, spec, draws = draws, components = deps,
                                components_base = deps, mode = mode,
                                engine_env = reg_engine_env("flows", deps = declared))
  list(ctx = ctx, comp = comp, spec = spec, deps = deps)
}

#' Prüfkontext für einen Typ (5.6)
#' @param def `vofi_typedef`.
#' @param n Anzahl der Läufe.
#' @param grid `vofi_grid`.
#' @param draws `NULL` oder `vofi_draws` (z. B. aus [reg_fake_draws()]).
#' @param example Rohbeispiel (Default `def$example`).
#' @return `vofi_ctx` aus `eng_context_from_parts()`.
#' @noRd
reg_test_ctx <- function(def, n, grid, draws = NULL, example = NULL) {
  reg_test_setup(def, n, grid, draws, example)$ctx
}

#' Laufspezifische Ziehungen für die numerischen Parameter eines Beispiels (5.6)
#' @inheritParams reg_test_ctx
#' @return `vofi_draws` im Modus `"mc"`.
#' @noRd
reg_fake_draws <- function(def, n, grid, example = NULL) {
  n <- as.integer(n)
  ex <- example %||% def$example %||% list()
  static <- list()
  paths <- list()
  keys <- character(0)
  kinds <- character(0)
  if (def$kind %in% c("flow", "instrument")) {
    comp <- reg_example_component(def, ex)
    coll <- reg_collection(def, ex)
    i <- seq_len(n) - 1
    for (p in names(def$params)) {
      pp <- def$params[[p]]
      if (isTRUE(pp$deterministic_only) ||
          !(pp$kind %in% c("number", "amount", "rate", "share", "value"))) {
        next
      }
      node <- comp[[p]]
      key <- path_join(coll, comp$id, p)
      fac <- if (identical(pp$kind, "share")) 1 - 0.1 * i / n else 1 + 0.1 * i
      if (is.list(node) && identical(node$kind, "const") && is.numeric(node$value) &&
          length(node$value) == 1L) {
        static[[key]] <- as.double(node$value) * fac
        keys <- c(keys, key)
        kinds <- c(kinds, "static")
      } else if (is.list(node) && identical(node$kind, "series_t") && "path" %in% pp$shapes) {
        vals <- suppressWarnings(as.double(unlist(node$values)))
        if (length(vals) == grid$T + 1L && !anyNA(vals)) {
          paths[[key]] <- outer(fac, vals)
          keys <- c(keys, key)
          kinds <- c(kinds, "process")
        }
      }
    }
  }
  targets <- data.frame(key = keys, target = keys, kind = kinds,
                        apply = rep("replace", length(keys)), stringsAsFactors = FALSE)
  new_vofi_draws("mc", n = n, sims = seq_len(n), blocks = 1L, block_size = n,
                 static = static, targets = targets, paths = paths, years = grid$years,
                 meta = list(seed = NA_real_, sampling = "testkit", block_size = n,
                             replicates = 1L, copula = NA_character_, antithetic = FALSE,
                             rng_kind = c("Mersenne-Twister", "Inversion", "Rejection"),
                             repaired = list(parameters = NULL, shocks = NULL),
                             plan_hash = NA_character_))
}

#' Ziehungen eines einzelnen Laufs
#' @noRd
reg_draws_subset <- function(draws, i) {
  sub_m <- function(m) m[i, , drop = FALSE]
  new_vofi_draws(
    draws$mode, n = 1L, sims = draws$sims[i], blocks = draws$blocks,
    block_size = draws$block_size, static = lapply(draws$static, function(v) v[i]),
    decision = lapply(draws$decision, function(v) v[i]), u = lapply(draws$u, function(v) v[i]),
    targets = draws$targets, annual = lapply(draws$annual, sub_m),
    paths = lapply(draws$paths, sub_m), years = draws$years,
    scenario_index = lapply(draws$scenario_index, function(v) v[i]),
    features = if (nrow(draws$features) >= i) draws$features[i, , drop = FALSE] else NULL,
    meta = draws$meta
  )
}

# ---------------------------------------------------------------------------------------------
# Befunde
# ---------------------------------------------------------------------------------------------

#' @noRd
reg_finding <- function(check, ok, message = "") {
  data.frame(check = check, ok = isTRUE(ok), message = as.character(message)[1L],
             stringsAsFactors = FALSE)
}

#' Ausdruck auswerten; Fehler werden zum Befund
#' @noRd
reg_try <- function(check, expr) {
  tryCatch(expr, error = function(e) reg_finding(check, FALSE, conditionMessage(e)))
}

#' Zustand des globalen RNG
#' @noRd
reg_rng_state <- function() {
  genv <- globalenv()
  if (exists(".Random.seed", envir = genv, inherits = FALSE)) {
    get(".Random.seed", envir = genv, inherits = FALSE)
  } else {
    NULL
  }
}

#' Ausdruck auswerten und RNG-Unberührtheit festhalten (F8)
#' @return Liste `value`, `rng_ok`.
#' @noRd
reg_no_rng <- function(expr) {
  before <- reg_rng_state()
  value <- force(expr)
  list(value = value, rng_ok = identical(before, reg_rng_state()))
}

#' Befunde binden
#' @noRd
reg_bind <- function(x) {
  x <- Filter(Negate(is.null), x)
  if (length(x) == 0L) {
    return(data.frame(check = character(0), ok = logical(0), message = character(0),
                      stringsAsFactors = FALSE))
  }
  out <- do.call(rbind, x)
  rownames(out) <- NULL
  out
}

#' Alle Vertragstests eines Typs (C1–C4 und artspezifisch)
#' @param def `vofi_typedef`.
#' @param source `"vofi"` oder `"user"`.
#' @param n Laufzahlen.
#' @return Data Frame `check`, `ok`, `message`.
#' @noRd
reg_check_type <- function(def, source = "vofi", n = c(1L, 2L, 7L)) {
  static <- reg_static_findings(def)
  parts <- list(static)
  for (chk in c("C1", "C2", "C3")) {
    if (!(chk %in% static$check)) parts[[length(parts) + 1L]] <- reg_finding(chk, TRUE)
  }
  parts[[length(parts) + 1L]] <- reg_check_labels(def, source)
  if (!any(static$check == "C2")) {
    runtime <- switch(def$kind,
      flow = reg_check_flow(def, n),
      instrument = reg_check_instrument(def, n),
      account_action = reg_check_action(def, n),
      distribution = reg_check_distribution(def),
      process = reg_check_process(def),
      kpi = reg_check_kpi(def),
      tax = reg_check_tax(def),
      rule = reg_check_rule(def, n),
      NULL
    )
    parts[[length(parts) + 1L]] <- runtime
  }
  reg_bind(parts)
}

#' C4: Labels vorhanden
#' @noRd
reg_check_labels <- function(def, source = "vofi") {
  prefix <- reg_label_prefix(def)
  if (identical(source, "user")) {
    miss <- character(0)
    if (!utl_is_string(def[["label"]])) miss <- c(miss, "label")
    if (!utl_is_string(def$labels$description)) miss <- c(miss, "description")
    for (p in names(def$params)) {
      if (!utl_is_string(def$labels$params[[p]])) miss <- c(miss, paste0("params.", p))
    }
    for (r in def$rows) {
      if (!utl_is_string(def$labels$rows[[r]])) miss <- c(miss, paste0("rows.", r))
    }
  } else {
    keys <- c(paste0(prefix, ".label"), paste0(prefix, ".description"),
              if (length(def$params) > 0L) paste0(prefix, ".params.", names(def$params), ".label"),
              if (length(def$rows) > 0L) paste0(prefix, ".rows.", def$rows))
    miss <- keys[!vapply(keys, lbl_has, logical(1))]
  }
  if (length(miss) == 0L) return(reg_finding("C4", TRUE))
  reg_finding("C4", FALSE, msg("core.contract.labels_missing", name = def$name,
                               keys = utl_collapse(miss)))
}

# ---------------------------------------------------------------------------------------------
# Zahlungskomponenten (F1–F10)
# ---------------------------------------------------------------------------------------------

#' Zeilenname gegen deklarierte Zeilen und Muster prüfen (F3)
#' @noRd
reg_row_declared <- function(key, rows) {
  if (key %in% rows) return(TRUE)
  pats <- rows[endsWith(rows, "_*")]
  for (p in pats) {
    pre <- substr(p, 1L, nchar(p) - 1L)
    if (startsWith(key, pre) && nchar(key) > nchar(pre)) return(TRUE)
  }
  FALSE
}

#' Befunde F1–F6, F9 für ein Ergebnis von build()
#' @noRd
reg_flow_findings <- function(fl, ctx, def, n, grid, tag) {
  acc <- new.env(parent = emptyenv())
  acc$out <- list()
  add <- function(check, ok, key = NULL, ...) {
    acc$out[[length(acc$out) + 1L]] <- reg_finding(
      check, ok, if (ok) "" else paste(tag, msg(key, ...))
    )
  }
  if (!inherits(fl, "vofi_flows")) {
    add("F1", FALSE, "core.testkit.not_flows", name = def$name)
    return(reg_bind(acc$out))
  }
  add("F1", TRUE)
  tol <- vofi_tol$zero_abs
  n_t <- grid$T + 1L
  keys <- vapply(fl$rows, function(r) r$key %||% NA_character_, "")
  reg_ids <- function(what) {
    from_ctx <- tryCatch(if (what == "asset") ctx$assets() else ctx$measures(),
                         error = function(e) list())
    lst <- c(from_ctx, if (what == "asset") fl$assets else fl$measures)
    vapply(lst, function(e) e[[paste0(what, "_id")]] %||% NA_character_, "")
  }
  asset_ids <- reg_ids("asset")
  measure_ids <- reg_ids("measure")
  f2 <- f3 <- f4 <- f5 <- f6 <- f9 <- character(0)
  if (anyDuplicated(keys)) f3 <- c(f3, utl_collapse(keys[duplicated(keys)]))
  for (r in fl$rows) {
    k <- r$key %||% "?"
    if (!inherits(r, "vofi_row")) {
      f4 <- c(f4, k)
      next
    }
    v <- r$values
    if (!is.matrix(v) || !identical(dim(v), c(as.integer(n), n_t)) || !is.double(v) ||
        anyNA(v) || any(!is.finite(v))) {
      f2 <- c(f2, k)
      next
    }
    if (!reg_row_declared(k, def$rows) || grepl("__", k, fixed = TRUE)) f3 <- c(f3, k)
    probs <- validate_flow_row(r)
    if (length(probs) > 0L) f4 <- c(f4, k)
    cat_row <- vocab_category(r$section, r$category)
    if (is.null(cat_row)) {
      f4 <- c(f4, k)
      next
    }
    if ((cat_row$sign == "pos" && min(v) < -tol) || (cat_row$sign == "neg" && max(v) > tol)) {
      f5 <- c(f5, k)
    }
    if ("asset" %in% cat_row$ids && (is.null(r$asset_id) || !(r$asset_id %in% asset_ids))) {
      f6 <- c(f6, k)
    }
    if ("measure" %in% cat_row$ids &&
        (is.null(r$measure_id) || !(r$measure_id %in% measure_ids))) {
      f6 <- c(f6, k)
    }
    if (r$category %in% c("residual_value", "sale_cost") && n_t > 1L &&
        any(abs(v[, -n_t, drop = FALSE]) > tol)) {
      f9 <- c(f9, k)
    }
  }
  add("F2", length(f2) == 0L, "core.testkit.rows_failed", what = "F2", rows = utl_collapse(f2))
  add("F3", length(f3) == 0L, "core.testkit.rows_failed", what = "F3", rows = utl_collapse(f3))
  add("F4", length(f4) == 0L, "core.testkit.rows_failed", what = "F4", rows = utl_collapse(f4))
  add("F5", length(f5) == 0L, "core.testkit.rows_failed", what = "F5", rows = utl_collapse(f5))
  add("F6", length(f6) == 0L, "core.testkit.rows_failed", what = "F6", rows = utl_collapse(f6))
  add("F9", length(f9) == 0L, "core.testkit.rows_failed", what = "F9", rows = utl_collapse(f9))
  reg_bind(acc$out)
}

#' Komponente bauen (mit RNG-Kontrolle)
#' @noRd
reg_build_flow <- function(def, n, grid, draws) {
  setup <- reg_test_setup(def, n, grid, draws)
  res <- reg_no_rng(def$build(setup$comp, setup$ctx))
  list(flows = res$value, rng_ok = res$rng_ok, ctx = setup$ctx)
}

#' Zeilenwerte nach Schlüssel
#' @noRd
reg_row_values <- function(fl) {
  stats::setNames(lapply(fl$rows, function(r) r$values),
                  vapply(fl$rows, function(r) r$key, ""))
}

#' Batch-Invarianz zweier Wertelisten prüfen (Lauf i des Batches gegen Einzellauf)
#' @noRd
reg_same_run <- function(batch, single, i, tol = 1e-12) {
  if (!identical(sort(names(batch), method = "radix"), sort(names(single), method = "radix"))) {
    return(FALSE)
  }
  for (k in names(batch)) {
    a <- if (is.matrix(batch[[k]])) batch[[k]][i, ] else batch[[k]][i]
    b <- if (is.matrix(single[[k]])) single[[k]][1L, ] else single[[k]][1L]
    if (length(a) != length(b)) return(FALSE)
    na_a <- is.na(a)
    if (!identical(na_a, is.na(b))) return(FALSE)
    if (any(abs(a[!na_a] - b[!na_a]) > tol * pmax(1, abs(a[!na_a])))) return(FALSE)
  }
  TRUE
}

#' Vertragstests für Zahlungskomponenten
#' @noRd
reg_check_flow <- function(def, n) {
  out <- list()
  grids <- list(annual = reg_test_grid("annual"), mixed = reg_test_grid("mixed"))
  rng_ok <- TRUE
  built <- list()
  for (gname in names(grids)) {
    g <- grids[[gname]]
    for (nn in unique(n)) {
      tag <- sprintf("[%s, n = %d]", gname, nn)
      draws <- if (nn == 1L) NULL else reg_fake_draws(def, nn, g)
      res <- tryCatch(reg_build_flow(def, nn, g, draws), error = function(e) e)
      if (inherits(res, "error")) {
        out[[length(out) + 1L]] <- reg_finding("F1", FALSE, paste(tag, conditionMessage(res)))
        next
      }
      rng_ok <- rng_ok && res$rng_ok
      out[[length(out) + 1L]] <- reg_flow_findings(res$flows, res$ctx, def, nn, g, tag)
      built[[paste(gname, nn)]] <- list(flows = res$flows, draws = draws)
    }
  }
  out[[length(out) + 1L]] <- reg_finding("F8", rng_ok, if (rng_ok) "" else
    msg("core.testkit.rng", name = def$name))
  nmax <- max(n)
  if (nmax > 1L) {
    for (gname in names(grids)) {
      b <- built[[paste(gname, nmax)]]
      if (is.null(b) || !inherits(b$flows, "vofi_flows")) next
      ok <- reg_try("F7", {
        batch <- reg_row_values(b$flows)
        all(vapply(seq_len(nmax), function(i) {
          single <- reg_build_flow(def, 1L, grids[[gname]], reg_draws_subset(b$draws, i))
          reg_same_run(batch, reg_row_values(single$flows), i)
        }, logical(1)))
      })
      out[[length(out) + 1L]] <- if (is.data.frame(ok)) {
        ok
      } else {
        reg_finding("F7", ok, if (ok) "" else msg("core.testkit.batch", name = def$name,
                                                     grid = gname))
      }
    }
  }
  if (isTRUE(def$grid_invariant)) {
    out[[length(out) + 1L]] <- reg_try("F10", reg_check_grid_invariance(def, grids))
  }
  reg_bind(out)
}

#' F10: Jahressummen auf dem Raster mixed = Jahreswerte auf dem Raster annual
#' @noRd
reg_check_grid_invariance <- function(def, grids) {
  ya <- reg_year_sums(reg_build_flow(def, 1L, grids$annual, NULL)$flows, grids$annual)
  ym <- reg_year_sums(reg_build_flow(def, 1L, grids$mixed, NULL)$flows, grids$mixed)
  years <- intersect(colnames(ya), colnames(ym))
  ok <- identical(rownames(ya), rownames(ym)) && length(years) > 0L &&
    all(abs(ya[, years, drop = FALSE] - ym[, years, drop = FALSE]) <=
          1e-9 * pmax(1, abs(ya[, years, drop = FALSE])))
  reg_finding("F10", ok, if (ok) "" else msg("core.testkit.grid_invariance", name = def$name))
}

#' Summen der Flusszeilen je Kalenderjahr (n = 1)
#' @noRd
reg_year_sums <- function(fl, grid) {
  rows <- Filter(function(r) identical(r$kind, "flow"), fl$rows)
  keys <- utl_sort(vapply(rows, function(r) r$key, ""))
  yrs <- unique(grid$year[-1L])
  out <- matrix(0, length(keys), length(yrs), dimnames = list(keys, as.character(yrs)))
  for (r in rows) {
    v <- r$values[1L, ]
    for (y in yrs) out[r$key, as.character(y)] <- sum(v[-1L][grid$year[-1L] == y])
  }
  out
}

# ---------------------------------------------------------------------------------------------
# Kreditinstrumente (I1–I4, F7, F8)
# ---------------------------------------------------------------------------------------------

#' Instrument über alle Perioden schrittweise rechnen
#' @return Liste `steps` (je t: flows, memo, stocks), `findings`, `rng_ok`, `states`.
#' @noRd
reg_run_instrument <- function(def, n, grid, draws, tag) {
  setup <- reg_test_setup(def, n, grid, draws)
  ctx <- setup$ctx
  rng <- TRUE
  r0 <- reg_no_rng(def$init(setup$comp, ctx))
  rng <- rng && r0$rng_ok
  state <- r0$value
  steps <- list()
  states <- list()
  i1 <- i2 <- i3 <- character(0)
  b_prev <- rep(0, n)
  tol <- vofi_tol$stock_abs
  zero <- vofi_tol$zero_abs
  vec_ok <- function(x) is.numeric(x) && length(x) == n && !anyNA(x) && all(is.finite(x))
  get0v <- function(l, nm) if (is.null(l[[nm]])) rep(0, n) else as.double(l[[nm]])
  for (t in seq.int(0L, grid$T)) {
    rs <- reg_no_rng(def$step(state, t, ctx))
    rng <- rng && rs$rng_ok
    r <- rs$value
    fl_names <- c("draw", "repay", "repay_balloon", "prepay", "interest", "fees")
    mm_names <- c("repayment_grant", "disagio")
    if (!is.list(r) || !all(c("state", "flows", "memo", "stocks") %in% names(r)) ||
        !all(fl_names %in% names(r$flows)) || !all(mm_names %in% names(r$memo)) ||
        is.null(r$stocks$balance) ||
        !all(vapply(c(r$flows[fl_names], r$memo[mm_names], list(r$stocks$balance)), vec_ok,
                    logical(1)))) {
      i1 <- c(i1, paste0("t=", t))
      break
    }
    f <- lapply(r$flows[fl_names], as.double)
    m <- list(repayment_grant = get0v(r$memo, "repayment_grant"),
              disagio = get0v(r$memo, "disagio"), assumed = get0v(r$memo, "assumed"))
    b <- as.double(r$stocks$balance)
    if (any(f$draw < -zero) || any(unlist(f[setdiff(fl_names, "draw")]) > zero) ||
        any(unlist(m) < -zero) || any(b < -tol)) {
      i2 <- c(i2, paste0("t=", t))
    }
    expect <- b_prev + f$draw + m$disagio + m$assumed + f$repay + f$repay_balloon + f$prepay -
      m$repayment_grant
    if (any(abs(b - expect) > 1e-6 * pmax(1, abs(b)))) i3 <- c(i3, paste0("t=", t))
    b_prev <- b
    state <- r$state
    states[[t + 1L]] <- state
    steps[[t + 1L]] <- c(f, m, list(balance = b))
  }
  find <- reg_bind(list(
    reg_finding("I1", length(i1) == 0L, paste(tag, msg("core.testkit.steps_failed", what = "I1",
                                                       steps = utl_collapse(i1)))),
    reg_finding("I2", length(i2) == 0L, paste(tag, msg("core.testkit.steps_failed", what = "I2",
                                                       steps = utl_collapse(i2)))),
    reg_finding("I3", length(i3) == 0L, paste(tag, msg("core.testkit.steps_failed", what = "I3",
                                                       steps = utl_collapse(i3))))
  ))
  find$message[find$ok] <- ""
  list(steps = steps, states = states, findings = find, rng_ok = rng, ctx = ctx)
}

#' I4: prepay() und capacity()
#' @noRd
reg_check_prepay <- function(def, run, n, tag) {
  if (is.null(def$prepay) || length(run$states) < 2L) return(NULL)
  state <- run$states[[2L]]
  ctx <- run$ctx
  cap <- def$capacity(state, 1L, ctx)
  amount <- pmax(as.double(cap$balance) * 0.5, 1)
  p <- def$prepay(state, amount, 1L, ctx)
  used <- as.double(p$used)
  cap2 <- def$capacity(p$state, 1L, ctx)
  tol <- 1e-9 * pmax(1, abs(as.double(cap$balance)))
  ok <- length(used) == n && all(used >= -tol) &&
    all(used <= pmin(amount, as.double(cap$cap)) + tol) &&
    all(abs(as.double(cap2$balance) - (as.double(cap$balance) - used)) <= 1e-6 + tol) &&
    isTRUE(all.equal(as.double(p$flows$prepay), -used))
  reg_finding("I4", ok, if (ok) "" else paste(tag, msg("core.testkit.prepay", name = def$name)))
}

#' Vertragstests für Kreditinstrumente
#' @noRd
reg_check_instrument <- function(def, n) {
  out <- list()
  grids <- list(annual = reg_test_grid("annual"), mixed = reg_test_grid("mixed"))
  rng_ok <- TRUE
  runs <- list()
  for (gname in names(grids)) {
    g <- grids[[gname]]
    for (nn in unique(n)) {
      tag <- sprintf("[%s, n = %d]", gname, nn)
      draws <- if (nn == 1L) NULL else reg_fake_draws(def, nn, g)
      run <- tryCatch(reg_run_instrument(def, nn, g, draws, tag), error = function(e) e)
      if (inherits(run, "error")) {
        out[[length(out) + 1L]] <- reg_finding("I1", FALSE, paste(tag, conditionMessage(run)))
        next
      }
      rng_ok <- rng_ok && run$rng_ok
      out[[length(out) + 1L]] <- run$findings
      out[[length(out) + 1L]] <- reg_try("I4", reg_check_prepay(def, run, nn, tag))
      runs[[paste(gname, nn)]] <- list(run = run, draws = draws)
    }
  }
  out[[length(out) + 1L]] <- reg_finding("F8", rng_ok, if (rng_ok) "" else
    msg("core.testkit.rng", name = def$name))
  nmax <- max(n)
  if (nmax > 1L) {
    for (gname in names(grids)) {
      b <- runs[[paste(gname, nmax)]]
      if (is.null(b)) next
      ok <- reg_try("F7", {
        all(vapply(seq_len(nmax), function(i) {
          single <- reg_run_instrument(def, 1L, grids[[gname]], reg_draws_subset(b$draws, i), "")
          length(single$steps) == length(b$run$steps) &&
            all(vapply(seq_along(single$steps), function(t) {
              reg_same_run(b$run$steps[[t]], single$steps[[t]], i)
            }, logical(1)))
        }, logical(1)))
      })
      out[[length(out) + 1L]] <- if (is.data.frame(ok)) {
        ok
      } else {
        reg_finding("F7", ok, if (ok) "" else msg("core.testkit.batch", name = def$name,
                                                     grid = gname))
      }
    }
  }
  reg_bind(out)
}

# ---------------------------------------------------------------------------------------------
# Ausgleichsaktionen (A1, A2, F8)
# ---------------------------------------------------------------------------------------------

#' Synthetischer Kontenzustand (8.8) mit n Läufen
#' @noRd
reg_test_acc <- function(n, grid) {
  i <- seq_len(n)
  odd <- i %% 2L == 1L
  n_t <- grid$T + 1L
  list(
    G = ifelse(odd, 1000 * i, 0), KK = ifelse(odd, 0, 400 * i),
    KKP = ifelse(i == 4L, 300, 0),
    h = grid_rate_eff(grid, rep(0.02, n)), h_pa = matrix(0.02, n, n_t),
    w = 0, wa = matrix(0, n, n_t),
    s = grid_rate_eff(grid, rep(0.08, n)), s_pa = matrix(0.08, n, n_t),
    sp = grid_rate_eff(grid, rep(0.10, n)),
    KL = matrix(5000, n, n_t), Lmin = matrix(100, n, n_t),
    flag_threshold = 2000, prepay_buffer = 0, prepay_min_spread = 0, j = 2L
  )
}

#' Testinstrument für Aktionen mit Kreditbezug (Ü3 `loan_prepay`): endfälliges Darlehen "k"
#' (50.000 zu 6 %, Sondertilgung erlaubt), Zustand nach der Periode t = 1
#' @return `list(spec, inst)`; `inst` leer, wenn `bullet_loan` nicht registriert ist.
#' @noRd
reg_test_inst <- function(grid, spec, draws, mode) {
  if (!reg_has("instrument", "bullet_loan")) return(list(spec = spec, inst = list()))
  idef <- reg_get("instrument", "bullet_loan")
  comp <- reg_example_component(idef, list(type = "bullet_loan", amount_eur = 50000,
                                           rate_pa = 0.06, term_years = 5,
                                           payments_per_year = 1L, prepay_allowed = TRUE),
                                id = "k")
  spec <- path_set(spec, "financing.k", comp)
  ictx <- eng_context_from_parts(grid, spec, draws = draws, mode = mode,
                                 engine_env = reg_engine_env("balance"))
  st <- idef$init(comp, ictx)
  for (t in 0:1) st <- idef$step(st, t, ictx)$state
  list(spec = spec, inst = list(k = list(state = st, def = idef)))
}

#' Summe der Kreditbestände einer Instrumentliste (für A2)
#' @noRd
reg_inst_balance <- function(inst, t, ctx, n) {
  b <- rep(0, n)
  for (e in inst) {
    if (is.function(e$def$capacity)) b <- b + as.double(e$def$capacity(e$state, t, ctx)$balance)
  }
  b
}

#' Vertragstests für Ausgleichsaktionen
#' @noRd
reg_check_action <- function(def, n) {
  g <- reg_test_grid("annual")
  out <- list()
  rng_ok <- TRUE
  needs_inst <- "loan_*_prepay" %in% def$rows
  for (nn in unique(n)) {
    tag <- sprintf("[n = %d]", nn)
    res <- tryCatch({
      spec <- reg_test_spec(g)
      draws <- if (nn == 1L) NULL else new_vofi_draws("mc", n = nn)
      mode <- if (nn == 1L) "deterministic" else "mc"
      ti <- if (needs_inst) reg_test_inst(g, spec, draws, mode) else list(spec = spec,
                                                                          inst = list())
      ctx <- eng_context_from_parts(g, ti$spec, draws = draws, mode = mode,
                                    engine_env = reg_engine_env("balance"))
      acc <- reg_test_acc(nn, g)
      amount <- 750 * (seq_len(nn) - 1) + 50
      r <- reg_no_rng(def$apply(acc, amount, 1L, ctx, ti$inst))
      inst1 <- r$value$inst %||% ti$inst
      list(r = r$value, rng_ok = r$rng_ok, acc = acc, amount = amount,
           b0 = reg_inst_balance(ti$inst, 1L, ctx, nn), b1 = reg_inst_balance(inst1, 1L, ctx, nn))
    }, error = function(e) e)
    if (inherits(res, "error")) {
      out[[length(out) + 1L]] <- reg_finding("A1", FALSE, paste(tag, conditionMessage(res)))
      next
    }
    rng_ok <- rng_ok && res$rng_ok
    r <- res$r
    acc0 <- res$acc
    tol <- vofi_tol$stock_abs
    used <- as.double(r$used)
    keys <- names(r$flows) %||% character(0)
    keys_ok <- all(vapply(keys, function(k) {
      k %in% def$rows ||
        ("loan_*_prepay" %in% def$rows && grepl("^loan_[a-z0-9_]+_prepay$", k))
    }, logical(1)))
    flows_ok <- all(vapply(r$flows, function(v) {
      is.numeric(v) && length(v) == nn && all(is.finite(v))
    }, logical(1)))
    acc1 <- r$acc
    a1 <- length(used) == nn && all(used >= -tol) && all(used <= res$amount + tol) &&
      keys_ok && flows_ok && all(acc1$G >= -tol) && all(acc1$KK >= -tol) &&
      all(acc1$KKP >= -tol)
    out[[length(out) + 1L]] <- reg_finding("A1", a1, if (a1) "" else
      paste(tag, msg("core.testkit.action", what = "A1", name = def$name)))
    wealth <- function(a, b) a$G - a$KK - a$KKP - b
    total <- if (length(keys) > 0L) Reduce(`+`, lapply(r$flows, as.double)) else rep(0, nn)
    ext <- Reduce(`+`, lapply(intersect(keys, c("equity_call", "shortfall")),
                              function(k) as.double(r$flows[[k]])), rep(0, nn))
    d_w <- wealth(acc1, res$b1) - wealth(acc0, res$b0)
    a2 <- length(d_w) == nn && all(abs(d_w + (total - ext)) <= 1e-9 * pmax(1, res$amount))
    out[[length(out) + 1L]] <- reg_finding("A2", a2, if (a2) "" else
      paste(tag, msg("core.testkit.action", what = "A2", name = def$name)))
  }
  out[[length(out) + 1L]] <- reg_finding("F8", rng_ok, if (rng_ok) "" else
    msg("core.testkit.rng", name = def$name))
  reg_bind(out)
}

# ---------------------------------------------------------------------------------------------
# Verteilungen (D1–D3, F8) und Prozesse (P1–P3, F8)
# ---------------------------------------------------------------------------------------------

#' Deterministische Permutation (Weyl-Folge, ohne Zufallszahlen)
#' @noRd
reg_weyl_perm <- function(n, k) {
  alpha <- sqrt(c(2, 3, 5, 7, 11, 13, 17, 19, 23, 29)[(k - 1L) %% 10L + 1L]) + (k - 1L) %/% 10L
  order((seq_len(n) * alpha) %% 1)
}

#' Vertragstests für Verteilungen
#' @noRd
reg_check_distribution <- function(def) {
  par <- def$example
  out <- list()
  rng <- TRUE
  d1 <- reg_try("D1", {
    r <- reg_no_rng(def$quantile(c(1e-9, 0.5, 1 - 1e-9), par))
    rng <- rng && r$rng_ok
    q <- r$value
    u <- seq(1e-6, 1 - 1e-6, length.out = 101L)
    qq <- def$quantile(u, par)
    ok <- length(q) == 3L && all(is.finite(q)) && all(diff(q) >= -1e-12) &&
      length(qq) == length(u) && all(diff(qq) >= -1e-9 * pmax(1, abs(qq[-1L])))
    if (ok && !is.null(par$min) && is.numeric(par$min)) ok <- min(q) >= par$min - 1e-9
    if (ok && !is.null(par$max) && is.numeric(par$max)) ok <- max(q) <= par$max + 1e-9
    reg_finding("D1", ok, if (ok) "" else msg("core.testkit.dist", what = "D1", name = def$name))
  })
  out[[1L]] <- d1
  d2 <- reg_try("D2", {
    r <- reg_no_rng(list(med = def$point(par, "median"), mean = def$point(par, "mean"),
                         mode = def$point(par, "mode"), mom = def$moments(par)))
    rng <- rng && r$rng_ok
    v <- r$value
    ok <- length(v$med) == 1L && length(v$mean) == 1L && length(v$mode) == 1L &&
      is.list(v$mom) && all(c("mean", "var") %in% names(v$mom))
    if (ok) {
      ok <- abs(v$med - def$quantile(0.5, par)) <= 1e-8 * max(1, abs(v$med))
    }
    if (ok && is.finite(v$mom$mean)) {
      ok <- abs(v$mean - v$mom$mean) <= 1e-8 * max(1, abs(v$mean))
      m <- 20000L
      x <- def$quantile((seq_len(m) - 0.5) / m, par)
      se <- if (is.finite(v$mom$var)) sqrt(v$mom$var / m) else stats::sd(x) / sqrt(m)
      ok <- ok && abs(mean(x) - v$mom$mean) <= 4 * se + 1e-9 * max(1, abs(v$mom$mean))
    }
    reg_finding("D2", ok, if (ok) "" else msg("core.testkit.dist", what = "D2", name = def$name))
  })
  out[[2L]] <- d2
  out[[3L]] <- reg_try("D3", {
    v <- def$validate(par)
    ok <- is.character(v) && length(v) == 0L
    reg_finding("D3", ok, if (ok) "" else msg("core.testkit.dist", what = "D3", name = def$name))
  })
  out[[4L]] <- reg_finding("F8", rng, if (rng) "" else msg("core.testkit.rng", name = def$name))
  reg_bind(out)
}

#' Parameter einer Prozessdefinition entarten (alle `sigma` = 0)
#' @noRd
reg_degenerate <- function(par) {
  if (!is.list(par)) return(par)
  for (nm in names(par)) {
    if (identical(nm, "sigma")) par[[nm]] <- 0 else par[[nm]] <- reg_degenerate(par[[nm]])
  }
  par
}

#' Vertragstests für Prozesse (P1–P4, F8)
#'
#' Die Laufzahl n steht dem Prozess immer als `attr(linked, "n")` zur Verfügung (auch bei
#' `n_shocks = n_uniforms = 0` und skalaren Parametern, wenn `z` und `u` `NULL` sind); der Sampler
#' (WS-C) übergibt sie ebenso.
#' @noRd
reg_check_process <- function(def) {
  par <- def$example
  years <- 2027:2036
  n <- 4000L
  y <- length(years)
  rng <- TRUE
  scores <- stats::qnorm((seq_len(n) - 0.5) / n)
  make_z <- function(k) {
    if (k == 0L) return(NULL)
    z <- matrix(0, n, y - 1L)
    for (c in seq_len(y - 1L)) z[, c] <- scores[reg_weyl_perm(n, c)]
    z
  }
  make_u <- function(k) {
    if (k == 0L) return(NULL)
    u <- matrix(0, n, k)
    for (c in seq_len(k)) u[, c] <- ((seq_len(n) - 0.5) / n)[reg_weyl_perm(n, c + 20L)]
    u
  }
  linked <- stats::setNames(lapply(def$linked, function(l) matrix(0.02, n, y)), def$linked)
  attr(linked, "n") <- n
  out <- list()
  sim <- reg_try("P1", {
    ns <- def$n_shocks(par)
    nu <- def$n_uniforms(par)
    r <- reg_no_rng(def$simulate(par, make_z(as.integer(ns)), make_u(as.integer(nu)), years,
                                 linked))
    rng <- rng && r$rng_ok
    x <- r$value
    ex <- def$expected(par, years)
    ok <- isTRUE(is.matrix(x) && identical(dim(x), c(n, y)) && is.numeric(x) &&
                   length(ex) == y &&
                   all(abs(x[, 1L] - ex[1L]) <= 1e-12 * max(1, abs(ex[1L]))))
    list(f = reg_finding("P1", ok, if (ok) "" else msg("core.testkit.process", what = "P1",
                                                       name = def$name)),
         x = x, ex = ex, nu = nu, ok = ok)
  })
  if (is.data.frame(sim)) {
    out[[1L]] <- sim
  } else {
    out[[1L]] <- sim$f
    if (sim$ok && isTRUE(sim$nu == 0L)) {
      out[[2L]] <- reg_try("P2", {
        p0 <- reg_degenerate(par)
        x0 <- def$simulate(p0, make_z(as.integer(def$n_shocks(p0))), NULL, years, linked)
        e0 <- def$expected(p0, years)
        ok <- isTRUE(all(abs(x0 - matrix(e0, n, y, byrow = TRUE)) <=
                           1e-12 * pmax(1, abs(matrix(e0, n, y, byrow = TRUE)))))
        reg_finding("P2", ok, if (ok) "" else msg("core.testkit.process", what = "P2",
                                                  name = def$name))
      })
    }
    if (sim$ok && all(is.finite(sim$ex))) {
      se <- apply(sim$x, 2L, stats::sd) / sqrt(n)
      ok <- isTRUE(all(abs(colMeans(sim$x) - sim$ex) <= 4 * se + 1e-9 * pmax(1, abs(sim$ex))))
      out[[length(out) + 1L]] <- reg_finding("P3", ok, if (ok) "" else
        msg("core.testkit.process", what = "P3", name = def$name))
    }
    if (sim$ok && is.function(def$quantile_path)) {
      out[[length(out) + 1L]] <- reg_try("P4", reg_check_quantile_path(def, par, years, sim$x,
                                                                       linked))
    }
  }
  out[[length(out) + 1L]] <- reg_try("P1", {
    v <- def$validate(par)
    ok <- is.character(v) && length(v) == 0L
    reg_finding("P1", ok, if (ok) "" else msg("core.testkit.process", what = "validate",
                                              name = def$name))
  })
  out[[length(out) + 1L]] <- reg_finding("F8", rng, if (rng) "" else
    msg("core.testkit.rng", name = def$name))
  reg_bind(out)
}

#' P4: Quantilpfad monoton in p, entartet = expected(), empirisch innerhalb 4 SE (5.6, R-95)
#'
#' Die empirische Prüfung erfolgt auf der Wahrscheinlichkeitsskala: Für q = quantile_path(p) muss
#' p im Intervall [F_n(q-) - 4 SE, F_n(q) + 4 SE] liegen (SE = sqrt(p (1 - p) / n)); Jahre mit
#' (nahezu) konstanter Simulation verlangen q = Simulationswert.
#' @param x Simulation n × length(years) aus P1.
#' @noRd
reg_check_quantile_path <- function(def, par, years, x, linked) {
  y <- length(years)
  n <- nrow(x)
  ps <- c(0.05, 0.25, 0.5, 0.75, 0.95)
  r <- reg_no_rng(lapply(ps, function(p) def$quantile_path(par, years, p)))
  q <- r$value
  shape_ok <- r$rng_ok && all(vapply(q, function(v) {
    is.numeric(v) && length(v) == y && all(is.finite(v))
  }, logical(1)))
  if (!shape_ok) {
    return(reg_finding("P4", FALSE, msg("core.testkit.process", what = "P4", name = def$name)))
  }
  qm <- do.call(cbind, q)
  mono <- all(qm[, -1L, drop = FALSE] - qm[, -ncol(qm), drop = FALSE] >=
                -1e-12 * pmax(1, abs(qm[, -1L, drop = FALSE])))
  p0 <- reg_degenerate(par)
  e0 <- def$expected(p0, years)
  degen <- all(vapply(ps, function(p) {
    q0 <- def$quantile_path(p0, years, p)
    isTRUE(all(abs(q0 - e0) <= 1e-12 * pmax(1, abs(e0))))
  }, logical(1)))
  emp <- TRUE
  tol_x <- 1e-9 * pmax(abs(qm), 1)
  for (j in seq_len(y)) {
    xj <- x[, j]
    if (diff(range(xj)) <= 1e-12 * max(1, abs(xj))) {
      emp <- emp && all(abs(qm[j, ] - xj[1L]) <= tol_x[j, ])
      next
    }
    for (k in seq_along(ps)) {
      p <- ps[k]
      se <- sqrt(p * (1 - p) / n)
      lo <- mean(xj < qm[j, k] - tol_x[j, k])
      hi <- mean(xj <= qm[j, k] + tol_x[j, k])
      emp <- emp && p >= lo - 4 * se && p <= hi + 4 * se
    }
  }
  ok <- isTRUE(mono && degen && emp)
  reg_finding("P4", ok, if (ok) "" else msg("core.testkit.process", what = "P4", name = def$name))
}

# ---------------------------------------------------------------------------------------------
# Kennzahlen (K1, F7, F8), Steuermodule (T1), Regeln (F7, F8)
# ---------------------------------------------------------------------------------------------

#' Kennzahlwert prüfen (K1)
#' @noRd
reg_kpi_ok <- function(v, n, def) {
  if (!inherits(v, "vofi_kpi_value")) return(FALSE)
  if (!identical(v$shape, def$shape %||% "scalar")) return(FALSE)
  len <- if (v$shape == "series") nrow(v$values) else length(v$values)
  if (len != n || length(v$na_reason) != n) return(FALSE)
  na_rows <- if (v$shape == "series") rowSums(is.na(v$values)) > 0 else is.na(v$values)
  all(!is.na(v$na_reason[na_rows])) && all(v$na_reason[na_rows] %in% vocab_codes("na_reasons"))
}

#' Vertragstests für Kennzahlen
#' @noRd
reg_check_kpi <- function(def) {
  out <- list()
  n <- 7L
  res <- tryCatch({
    core <- reg_example_core(n, 6L)
    ctx <- attr(core, "ctx") %||% reg_example_ctx(core)
    r <- reg_no_rng(def$compute(core, ctx))
    list(v = r$value, rng = r$rng_ok)
  }, error = function(e) e)
  if (inherits(res, "error")) {
    return(reg_finding("K1", FALSE, conditionMessage(res)))
  }
  ok <- reg_kpi_ok(res$v, n, def)
  out[[1L]] <- reg_finding("K1", ok, if (ok) "" else msg("core.testkit.kpi", name = def$name))
  out[[2L]] <- reg_finding("F8", res$rng, if (res$rng) "" else
    msg("core.testkit.rng", name = def$name))
  if (ok) {
    out[[3L]] <- reg_try("F7", {
      vals <- list(v = res$v$values)
      same <- all(vapply(seq_len(n), function(i) {
        core_i <- reg_example_core(1L, 6L, runs = i)
        ctx_i <- attr(core_i, "ctx") %||% reg_example_ctx(core_i)
        vi <- def$compute(core_i, ctx_i)
        reg_same_run(vals, list(v = vi$values), i)
      }, logical(1)))
      reg_finding("F7", same, if (same) "" else msg("core.testkit.batch", name = def$name,
                                                     grid = "annual"))
    })
  }
  reg_bind(out)
}

#' Vertragstests für Steuermodule (T1)
#' @noRd
reg_check_tax <- function(def) {
  res <- tryCatch({
    g <- reg_test_grid("annual")
    n <- 2L
    spec <- reg_test_spec(g)
    params <- def$example %||% list()
    rr <- reg_no_rng({
      mod <- def$constructor(params, spec)
      st <- tax_init(mod, params, list(), list(), n)
      pay <- numeric(0)
      for (t in seq.int(0L, g$T)) {
        j <- t + 1L
        inputs <- list(t = t, date_end = g$date_end[j], delta = g$delta[j], year = g$year[j],
                       phase = g$phase[j], exo = list(), inst = list(),
                       keys = data.frame(key = character(0), source = character(0),
                                         section = character(0), category = character(0),
                                         tax_category = character(0),
                                         asset_id = character(0), measure_id = character(0),
                                         cash = logical(0), stringsAsFactors = FALSE))
        interest <- list(exo_soll = rep(0, n), exo_fees = rep(0, n), endo_soll = rep(0, n),
                         endo_haben = rep(0, n), endo_wht = rep(0, n))
        r <- tax_step(mod, t, inputs, interest, st, params)
        st <- r$state
        pay <- c(pay, as.double(r$payment))
      }
      fin <- tax_finalize(mod, g$T, st,
                          list(exo_T = list(), residual_value = rep(0, n), market_value_T = NULL,
                               horizon_date = g$end_date, assets = list(), measures = list()),
                          params)
      list(pay = pay, fin = as.double(fin$payment_T))
    })
    v <- rr$value
    ok <- inherits(def$constructor(params, spec), "vofi_tax_module") &&
      length(v$pay) == (g$T + 1L) * n && all(v$pay == 0) && length(v$fin) == n &&
      all(v$fin == 0)
    reg_bind(list(
      reg_finding("T1", ok, if (ok) "" else msg("core.testkit.tax", name = def$name)),
      reg_finding("F8", rr$rng_ok, if (rr$rng_ok) "" else msg("core.testkit.rng",
                                                                name = def$name))
    ))
  }, error = function(e) reg_finding("T1", FALSE, conditionMessage(e)))
  res
}

#' Vertragstests für Rechtsregeln (F7, F8; nur mit `example` = Argumentliste)
#' @noRd
reg_check_rule <- function(def, n) {
  ex <- def$example
  if (!is.list(ex) || length(ex) == 0L) return(NULL)
  nmax <- max(n)
  vary <- function(args, nn) {
    lapply(args, function(a) {
      if (is.numeric(a) && length(a) == 1L) a * (1 + 0.1 * (seq_len(nn) - 1)) else a
    })
  }
  res <- tryCatch({
    rb <- reg_no_rng(do.call(def$fun, vary(ex, nmax)))
    batch <- rb$value
    same <- TRUE
    # params und value: deterministische Rückgaben ohne Laufdimension (5.3, R-93)
    if (!(def$returns %in% c("params", "value"))) {
      for (i in seq_len(nmax)) {
        args_i <- lapply(vary(ex, nmax), function(a) {
          if (is.numeric(a) && length(a) == nmax) a[i] else a
        })
        single <- do.call(def$fun, args_i)
        same <- same && reg_same_run(list(v = batch), list(v = single), i)
      }
    }
    reg_bind(list(
      reg_finding("F7", same, if (same) "" else msg("core.testkit.batch", name = def$name,
                                                     grid = "-")),
      reg_finding("F8", rb$rng_ok, if (rb$rng_ok) "" else msg("core.testkit.rng",
                                                                name = def$name))
    ))
  }, error = function(e) reg_finding("F7", FALSE, conditionMessage(e)))
  res
}

# ---------------------------------------------------------------------------------------------
# Synthetisches core (12.1) mit Mini-Ausgleich (nur Prüfkit; keine Engine)
# ---------------------------------------------------------------------------------------------

#' Ausgleich Schritt (6) einer Periode: Ü1 od_repay (KKP vor KK), Ü4 dep_invest; D1
#' dep_withdraw, D2 od_draw (bis KL), D4 equity_call (ext = TRUE) bzw. KKP (ext = FALSE)
#' @noRd
reg_mini_step <- function(g, kk, kkp, s, kl, ext) {
  sur <- pmax(s, 0)
  def <- pmax(-s, 0)
  x1 <- pmin(sur, kkp)
  kkp <- kkp - x1
  x2 <- pmin(sur - x1, kk)
  kk <- kk - x2
  inv <- sur - x1 - x2
  g <- g + inv
  w <- pmin(def, g)
  g <- g - w
  def <- def - w
  d <- pmin(def, pmax(kl - kk, 0))
  kk <- kk + d
  def <- def - d
  call <- if (ext) def else 0 * def
  pen <- if (ext) 0 * def else def
  kkp <- kkp + pen
  list(G = g, KK = kk, KKP = kkp, odp_repay = -x1, od_repay = -x2, dep_invest = -inv,
       dep_withdraw = w, od_draw = d, equity_call = call, odp_draw = pen)
}

#' Mini-Ausgleich über alle Perioden (keine Steuern, keine Sondertilgung)
#' @param e_cash n x (T+1) exogene Zahlungen (project, grants, equity).
#' @param l_cash n x (T+1) Summe der Kreditflüsse.
#' @param rates Liste `h`, `s`, `sp`, `KL` (n x (T+1)).
#' @param ext D4 mit Zufluss von außen (`equity_call`) oder KKP.
#' @noRd
reg_mini_balance <- function(e_cash, l_cash, rates, ext = TRUE) {
  n <- nrow(e_cash)
  n_t <- ncol(e_cash)
  z <- matrix(0, n, n_t)
  rec <- list(od_draw = z, od_repay = z, od_interest = z, odp_draw = z, odp_repay = z,
              odp_interest = z, dep_invest = z, dep_withdraw = z, dep_interest = z,
              equity_call = z, G = z, KK = z, KKP = z)
  g <- kk <- kkp <- rep(0, n)
  pre_t <- NULL
  for (j in seq_len(n_t)) {
    hz <- g * rates$h[, j]
    kz <- kk * rates$s[, j]
    kzp <- kkp * rates$sp[, j]
    s <- e_cash[, j] + l_cash[, j] + hz - kz - kzp
    if (j == n_t) pre_t <- list(G = g, KK = kk, KKP = kkp, S = s)
    st <- reg_mini_step(g, kk, kkp, s, rates$KL[, j], ext)
    g <- st$G
    kk <- st$KK
    kkp <- st$KKP
    for (k in c("od_draw", "od_repay", "odp_draw", "odp_repay", "dep_invest", "dep_withdraw",
                "equity_call")) {
      rec[[k]][, j] <- st[[k]]
    }
    rec$dep_interest[, j] <- hz
    rec$od_interest[, j] <- -kz
    rec$odp_interest[, j] <- -kzp
    rec$G[, j] <- g
    rec$KK[, j] <- kk
    rec$KKP[, j] <- kkp
  }
  rec$pre_t <- pre_t
  rec
}

#' Terminalzustand ohne Restwert (9.4) aus pre_T
#' @noRd
reg_mini_terminal <- function(bal, rw_t, b_t, kl_t) {
  p <- bal$pre_t
  ns_t <- bal$equity_call[, ncol(bal$equity_call)]
  st <- reg_mini_step(p$G, p$KK, p$KKP, p$S - rw_t + ns_t, kl_t, ext = FALSE)
  list(G = st$G, KK = st$KK, KKP = st$KKP, B_total = b_t,
       BS = st$G - st$KK - st$KKP - b_t, rv = rw_t, gap = st$odp_draw)
}

#' Eingangsgrößen des synthetischen core je Lauf
#' @noRd
reg_core_inputs <- function(runs, grid) {
  n <- length(runs)
  n_t <- grid$T + 1L
  t <- grid$t
  f <- 1 + 0.05 * (runs - 1)
  q <- 1 - 0.03 * (runs - 1)
  idx <- grid_by_period(grid, 1.02^pmax(t - 1, 0), n)
  op <- grid_by_period(grid, as.double(t >= 1), n)
  last <- grid_by_period(grid, as.double(t == grid$T), n)
  first <- grid_by_period(grid, as.double(t == 0), n)
  one <- grid_by_period(grid, as.double(t == 1), n)
  rw <- 250000 + 10000 * (runs - 1)
  mv <- grid_by_period(grid, 320000 * 1.02^t, n)
  exo <- list(
    inv__cost = list("project", "capex", -300000 * f * first, "b1", "m1", NULL),
    rent__value = list("project", "rent", 24000 * q * idx * op, NA, NA, NULL),
    rent__levy_m1 = list("project", "modernization_levy", 3000 * idx * op, NA, "m1", NULL),
    opex__value = list("project", "operating_cost", -4000 * idx * op, NA, NA, NULL),
    maint__value = list("project", "maintenance", -2000 * op, NA, NA, NULL),
    rv__value = list("project", "residual_value", rw * last, "b1", NA, NULL),
    rv__sale_cost = list("project", "sale_cost", -0.03 * rw * last, NA, NA, NULL),
    grant__value = list("grants", "grant", 30000 * one, NA, "m1", NULL),
    ek__in = list("equity", "equity_in", 100000 * first, NA, NA, NULL),
    ek__out = list("equity", "equity_out", -3000 * op, NA, NA, NULL),
    rv__market_value = list("memo", "market_value", mv, "b1", NA, NULL),
    rv__path_method = list("memo", "residual_path", 0.97 * mv, "b1", NA,
                           list(rv_basis = "method")),
    rv__path_measures = list("memo", "residual_path",
                             grid_by_period(grid, 0.97 * 300000 * pmax(1 - t / 40, 0), n), "b1",
                             NA, list(rv_basis = "measures")),
    tenant__energy = list("memo", "tenant_energy_cost", 8000 * idx * op, NA, NA, NULL),
    tenant__energy_pre = list("memo", "tenant_energy_cost_pre", 11000 * idx * op, NA, NA, NULL),
    tenant__operating = list("memo", "tenant_operating_cost", 6000 * idx * op, NA, NA, NULL),
    energy__quantity = list("memo", "energy_quantity", 60000 * op, NA, NA, NULL),
    energy__co2 = list("memo", "co2_emission", 12 * op, NA, NA, NULL)
  )
  # Kredit "bank": Jahresannuität 200.000 zu 4 %, 20 Jahre; Kredit "kfw": Ratentilgung
  # 60.000 zu 1 %, 6.000 je Jahr, Tilgungszuschuss 6.000 in t = 1 (measure m1)
  loans <- list()
  a <- 200000 * 0.04 / (1 - 1.04^-20)
  for (k in c("bank", "kfw")) {
    z <- matrix(0, n, n_t)
    l <- list(draw = z, repay = z, repay_balloon = z, prepay = z, interest = z, fees = z,
              repayment_grant = z, disagio = z, assumed = z, balance = z)
    b <- rep(0, n)
    for (j in seq_len(n_t)) {
      if (j == 1L) {
        d <- if (k == "bank") 200000 else 60000
        l$draw[, j] <- d
        b <- b + d
      } else {
        rate <- if (k == "bank") 0.04 else 0.01
        int <- b * rate * grid$delta[j]
        rep_amt <- if (k == "bank") pmin(a - int, b) else pmin(rep(6000, n), b)
        l$interest[, j] <- -int
        l$repay[, j] <- -rep_amt
        b <- b - rep_amt
        if (k == "kfw" && grid$t[j] == 1L) {
          tz <- pmin(6000, b)
          l$repayment_grant[, j] <- tz
          b <- b - tz
        }
      }
      l$balance[, j] <- b
    }
    loans[[k]] <- l
  }
  list(exo = exo, loans = loans, rw = rw, n = n, runs = runs)
}

#' Synthetisches, vertragsgemäßes core für Kennzahltests (12.1)
#'
#' Jahresraster ab 2027-01-01 mit T Perioden; Lauf i variiert Investition, Miete und Restwert.
#' Enthält Projekt-, Förder-, EK-, Kredit- (zwei Kredite), Konto-, Steuer-, Prüf- und
#' Bestandszeilen sowie Merkzeilen (Marktwert, Restwertpfad mit `rv_basis`, Mietersicht,
#' Mengen). `opp`, `terminal_ex_rv`, `flags` und `rates` sind konsistent zum Ledger. Attribut
#' `"ctx"`: zugehöriger Kontext mit `rebalance()`-Attrappe (falls eng_context_from_parts()
#' verfügbar ist, sonst `NULL`).
#' @param n Läufe.
#' @param T letzter Periodenindex (Horizont in Jahren).
#' @param runs globale Laufnummern (für Einzelläufe der Batch-Invarianz).
#' @return Liste (core).
#' @noRd
reg_example_core <- function(n = 7L, T = 6L, runs = seq_len(n)) { # nolint: object_name_linter.
  grid <- vofi_time_grid(as.Date("2027-01-01"), as.integer(T)) # nolint. T wie Spec 00 5.6
  inp <- reg_core_inputs(as.double(runs), grid)
  n <- inp$n
  n_t <- grid$T + 1L
  rates <- list(h = grid_rate_eff(grid, rep(0.02, n)), s = grid_rate_eff(grid, rep(0.06, n)),
                sp = grid_rate_eff(grid, rep(0.08, n)), KL = matrix(20000, n, n_t))
  core <- reg_core_from_inputs(inp, grid, rates)
  attr(core, "testkit") <- list(inputs = inp, rates = rates)
  ctx <- tryCatch(reg_example_ctx(core), vofi_error_not_implemented = function(e) NULL)
  attr(core, "ctx") <- ctx
  core
}

#' core aus Eingangsgrößen (Mini-Ausgleich, Unterlassung, Terminalzustand)
#' @noRd
reg_core_from_inputs <- function(inp, grid, rates, extra_out = NULL) {
  n <- inp$n
  n_t <- grid$T + 1L
  z <- matrix(0, n, n_t)
  exo <- inp$exo
  cash_sec <- c("project", "grants", "equity")
  e_cash <- Reduce(`+`, lapply(exo, function(e) if (e[[1L]] %in% cash_sec) e[[3L]] else z))
  if (!is.null(extra_out)) e_cash <- e_cash + extra_out
  loan_flow_names <- c("draw", "repay", "repay_balloon", "prepay", "interest", "fees")
  l_cash <- Reduce(`+`, lapply(inp$loans, function(l) Reduce(`+`, l[loan_flow_names])))
  bal <- reg_mini_balance(e_cash, l_cash, rates, ext = TRUE)
  b_tot <- Reduce(`+`, lapply(inp$loans, function(l) l$balance))
  bs <- bal$G - bal$KK - bal$KKP - b_tot
  rw_t <- exo$rv__value[[3L]][, n_t] + exo$rv__sale_cost[[3L]][, n_t]
  term <- reg_mini_terminal(bal, rw_t, b_tot[, n_t], rates$KL[, n_t])
  # Unterlassungsalternative: Einlagen/Entnahmen + Nachschüsse der Investition, KKP zu s (R-81)
  opp_e <- exo$ek__in[[3L]] + exo$ek__out[[3L]] + bal$equity_call
  opp_rates <- rates
  opp_rates$sp <- rates$s
  opp <- reg_mini_balance(opp_e, z, opp_rates, ext = FALSE)
  opp_bs <- opp$G - opp$KK - opp$KKP
  parts <- list(bal = bal, b_tot = b_tot, bs = bs, rw_t = rw_t, term = term, opp = opp,
                opp_bs = opp_bs, e_cash = e_cash, l_cash = l_cash)
  if (!is.null(extra_out)) return(parts)
  reg_assemble_core(inp, grid, rates, parts)
}

#' Ledger, Bestände und Markierungen zusammensetzen
#' @noRd
reg_assemble_core <- function(inp, grid, rates, p) {
  n <- inp$n
  n_t <- grid$T + 1L
  z <- matrix(0, n, n_t)
  exo <- inp$exo
  values <- list()
  meta <- list()
  for (k in names(exo)) {
    e <- exo[[k]]
    parts <- strsplit(k, "__", fixed = TRUE)[[1L]]
    values[[k]] <- e[[3L]]
    meta[[k]] <- new_ledger_rows(k, e[[1L]], e[[2L]], asset_id = e[[4L]], measure_id = e[[5L]],
                                 source_id = parts[1L], source_type = "custom_series",
                                 origin = "scenario", local_row = parts[2L],
                                 program = if (k == "grant__value") "beg" else NA_character_,
                                 extra = if (is.null(e[[6L]])) NULL else list(e[[6L]]))
  }
  pos <- 0L
  for (lk in names(inp$loans)) {
    pos <- pos + 1L
    l <- inp$loans[[lk]]
    cats <- c("draw", "repay", "repay_balloon", "prepay", "interest", "fees", "repayment_grant",
              "disagio", "assumed")
    for (ci in seq_along(cats)) {
      key <- paste0("loan_", lk, "_", cats[ci])
      values[[key]] <- l[[cats[ci]]]
      meta[[key]] <- new_ledger_rows(key, "loans", cats[ci], source_id = lk,
                                     source_type = if (lk == "bank") "annuity_loan" else
                                       "installment_loan",
                                     origin = "scenario", local_row = cats[ci],
                                     measure_id = if (cats[ci] == "repayment_grant" &&
                                                      lk == "kfw") "m1" else NA_character_,
                                     order = 1000 * (400 + pos) + 10 * ci)
    }
  }
  b <- p$bal
  eng <- list(
    equity_call = list("equity", "equity_call", b$equity_call),
    shortfall = list("equity", "shortfall", z),
    od_draw = list("overdraft", "draw", b$od_draw),
    od_repay = list("overdraft", "repay", b$od_repay),
    od_interest = list("overdraft", "interest", b$od_interest),
    odp_draw = list("overdraft", "draw", b$odp_draw),
    odp_repay = list("overdraft", "repay", b$odp_repay),
    odp_interest = list("overdraft", "interest", b$odp_interest),
    dep_invest = list("deposit", "invest", b$dep_invest),
    dep_withdraw = list("deposit", "withdraw", b$dep_withdraw),
    dep_interest = list("deposit", "interest", b$dep_interest),
    dep_wht = list("tax", "withholding_tax", z), tax = list("tax", "income_tax", z)
  )
  for (k in names(eng)) {
    values[[k]] <- eng[[k]][[3L]]
    meta[[k]] <- new_ledger_rows(k, eng[[k]][[1L]], eng[[k]][[2L]], local_row = k)
  }
  cash_keys <- names(values)[vapply(meta, function(m) isTRUE(m$cash), logical(1))]
  bc <- Reduce(`+`, values[cash_keys])
  bc[abs(bc) < 1e-7] <- 0
  pos <- 0L
  for (lk in names(inp$loans)) {
    pos <- pos + 1L
    key <- paste0("loan_", lk, "_balance")
    values[[key]] <- inp$loans[[lk]]$balance
    meta[[key]] <- new_ledger_rows(key, "stocks", "balance", source_id = lk,
                                   source_type = "loan", order = 900000 + pos)
  }
  stock_keys <- list(od_balance = b$KK, odp_balance = b$KKP, dep_balance = b$G)
  for (k in names(stock_keys)) {
    values[[k]] <- stock_keys[[k]]
    meta[[k]] <- new_ledger_rows(k, "stocks", "balance", order = 900099 +
                                   match(k, names(stock_keys)))
  }
  values$tax_liability <- z
  meta$tax_liability <- new_ledger_rows("tax_liability", "stocks", "tax_liability",
                                        order = 900200)
  values$balance_check <- bc
  meta$balance_check <- new_ledger_rows("balance_check", "check", "balance_check")
  values$net_position <- p$bs
  meta$net_position <- new_ledger_rows("net_position", "stocks", "net_position", order = 900300)
  rows <- do.call(rbind, unname(meta))
  rownames(rows) <- NULL
  ord <- order(rows$order, method = "radix")
  rows <- rows[ord, , drop = FALSE]
  rownames(rows) <- NULL
  values <- values[rows$key]
  ledger <- new_vofi_ledger(rows, values, n = n, T = grid$T)
  first_t <- apply(b$equity_call > vofi_tol$zero_abs, 1L, function(r) {
    if (any(r)) as.integer(which(r)[1L] - 1L) else NA_integer_
  })
  flags <- data.frame(
    reserve_used = rep(FALSE, n),
    shortfall = rowSums(b$equity_call > vofi_tol$zero_abs) > 0,
    shortfall_sum = rowSums(b$equity_call),
    first_shortfall_t = as.integer(first_t),
    limit_breach = rowSums(b$KKP > vofi_tol$zero_abs) > 0,
    limit_cut = rep(FALSE, n),
    opp_limit_breach = rowSums(p$opp$KKP > vofi_tol$zero_abs) > 0,
    ex_rv_gap = p$term$gap,
    overdraft_threshold = rowSums((b$KK + b$KKP) > 15000) > 0,
    stopped = rep(FALSE, n), negative_amortization = rep(FALSE, n),
    equity_call_over_savings = rep(FALSE, n), arbitrage = rep(FALSE, n)
  )
  list(
    ledger = ledger,
    stocks = list(G = b$G, KK = b$KK, KKP = b$KKP,
                  B = lapply(inp$loans, function(l) l$balance), BS = p$bs,
                  tax_liability = matrix(0, n, n_t)),
    terminal_ex_rv = p$term,
    flags = flags,
    rates = list(h = rates$h, h_net = rates$h, s = rates$s, sp = rates$sp),
    opp = list(BS = p$opp_bs, EW = p$opp_bs[, n_t], ledger = NULL),
    grid = grid, n = n, view = "with_rv"
  )
}

#' Kontext zum synthetischen core (Stufe "kpi", rebalance()-Attrappe, 12.8)
#' @param core Ergebnis von [reg_example_core()].
#' @return `vofi_ctx`.
#' @noRd
reg_example_ctx <- function(core) {
  tk <- attr(core, "testkit")
  grid <- core$grid
  n <- core$n
  n_t <- grid$T + 1L
  rebalance <- function(extra_out = NULL) {
    eo <- if (is.null(extra_out)) matrix(0, n, n_t) else utl_sim_matrix(grid, extra_out)
    p <- reg_core_from_inputs(tk$inputs, grid, tk$rates, extra_out = eo)
    list(BS_T = p$bs[, n_t], NS = p$bal$equity_call, BS_T_ex_rv = p$term$BS, RW_T = p$rw_t)
  }
  draws <- if (n > 1L) new_vofi_draws("mc", n = n, sims = as.integer(tk$inputs$runs)) else NULL
  eng_context_from_parts(grid, reg_test_spec(grid), draws = draws, components = list(),
                         mode = if (n > 1L) "mc" else "deterministic",
                         engine_env = reg_engine_env("kpi", rebalance = rebalance))
}
