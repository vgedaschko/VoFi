# Testhelfer WS-E-OP (Zahlungsbausteine Betrieb, Energie, Mietrecht).
# Nutzlasten der Bibliothekseinträge legal/* (Spec 01 Teil C 3.5) als Listen, damit die Typen und
# Regeln ohne die Bibliothek (WS-L) und ohne Schicht 3 (WS-A) mit dem Rechtsstand 25.10.2026 geprüft
# werden können; Kontextaufbau mit Domänenblöcken über eng_context_from_parts() (6.1 Nr. 3).

#' Nutzlast legal/mietrecht_2026 (Teil C 3.5)
eop_lp_mietrecht <- function() {
  list(
    s558 = list(waiting_months = 15, request_min_months_after_last = 12, effective_month_offset = 3,
                cap_share = 0.20, cap_share_tight_market = 0.15, cap_window_months = 36,
                ovm_lookback_years = 6, excludes_increases = c("bgb_559", "bgb_559c", "bgb_559e"),
                funding_deduction_grant_share_pa = 0.08,
                funding_deduction_duration_grant_years = 12,
                funding_deduction_duration_loan = "fixed_period"),
    s559 = list(rate_pa = 0.08, cap_window_years = 6, cap_eur_m2_month = 3.00,
                cap_low_rent_eur_m2_month = 2.00, low_rent_threshold_eur_m2_month = 7.00,
                heating_cap_eur_m2_month = 0.50, effective_month_offset = 3,
                delay_if_defective_notice_months = 6, cost_deviation_threshold = 0.10,
                hardship_exclusion_not_for = c("bgb_555b_1", "bgb_555b_1a")),
    s559a = list(grants_reduce_costs = TRUE, repayment_grant_as_grant = TRUE,
                 market_rate_reference = "first_mortgage_at_completion"),
    s559c = list(cost_limit_per_unit_eur = 10000, flat_maintenance_share = 0.30,
                 interest_reduction_applicable = FALSE, lookback_years = 5, lock_years = 5),
    s559e = list(rate_pa = 0.10, flat_maintenance_share = 0.15,
                 flat_not_for_section43_heating = TRUE, cap_eur_m2_month = 0.50,
                 cap_window_years = 6, requires_third_party_funds = TRUE,
                 requires_measure = "bgb_555b_1a"),
    s557a = list(excludes = c("bgb_558", "bgb_559", "bgb_559b"), min_step_months = 12,
                 mietpreisbremse_per_step = TRUE),
    s557b = list(index = "vpi", min_months_unchanged = 12, excludes = "bgb_558",
                 s559_only_if_not_attributable = TRUE, heating_1a_allowed = TRUE,
                 effective_month_offset = 2),
    s556d = list(cap_share_over_ovm = 0.10, ordinance_until = as.Date("2029-12-31"),
                 newbuild_first_use_after = as.Date("2014-10-01"),
                 first_letting_after_comprehensive_modernisation_exempt = TRUE),
    s536_1a = list(exclusion_months = 3, scope = "bgb_555b_1"),
    s556e = list(relet_levy_procedures = c("bgb_559", "bgb_559c")),
    interpretation = list(third_party_allocation = "full", s559e_order = "flat_before_funds",
                          s559f_order = "halve_then_funds", heating_cap_order = "heating_first",
                          s559e_flat_for_section43 = FALSE)
  )
}

#' Nutzlast legal/mietrecht_559f_2026 (Teil C 3.5; Qualität C, nur mit Freigabe aktiv)
eop_lp_559f <- function() {
  list(jaz_threshold = 2.5, comparison = "ge", reduction_factor = 0.5, jaz_basis = "plan",
       exceptions = list(construction_year_after = 1996, flow_temperature_max_c = 55))
}

#' Nutzlast legal/mietrecht_ii_reform, mit der Kette auf legal/mietrecht_2026 gemischt
eop_lp_mietrecht_ii <- function() {
  deep_merge(eop_lp_mietrecht(), list(
    s559c = list(cost_limit_per_unit_eur = 20000),
    s557a = list(excludes = c("bgb_558", "bgb_559", "bgb_559b", "bgb_559e")),
    s557b = list(damping = list(threshold_pa = 0.03, excess_share_ignored = 0.5, symmetric = TRUE,
                                only_in_ordinance_areas = TRUE)),
    s536_1a = list(scope = c("bgb_555b_1", "bgb_555b_1a")),
    # Regelkonstante § 556e Abs. 2 je Rechtsstand (Änderungsantrag an Teil C 3.5, EOP-09)
    s556e = list(relet_levy_procedures = c("bgb_559", "bgb_559c", "bgb_559e"))
  ))
}

#' Nutzlast legal/co2kostaufg_2026 (Teil C 3.5)
eop_lp_co2 <- function() {
  up <- c(12, 17, 22, 27, 32, 37, 42, 47, 52, Inf)
  sh <- c(0, 0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.95)
  list(
    stage_model = lapply(seq_along(up), function(i) {
      list(upper_kg_m2a = up[i], landlord_share = sh[i])
    }),
    s5a = list(applies_to_installed_after = as.Date("2026-07-29"),
               co2_from = as.Date("2028-01-01"), co2_landlord_share = 0.5,
               network_fee_from = as.Date("2028-01-01"), network_fee_landlord_share = 0.5,
               bio_premium_from = as.Date("2029-01-01"), bio_premium_landlord_share = 0.5,
               bio_premium_max_fuel_share = 0.30,
               transition = list(breakdown_install_months_before = 12, suspension_months = 12)),
    s5b = list(newbuild_applies = TRUE, building_application_from = as.Date("2026-05-13"),
               completed_until = as.Date("2029-12-31")),
    s9 = list(reduction_factor = 0.5),
    district_heating = "co2_cost_in_heat_price",
    non_residential_split = 0.5
  )
}

#' Nutzlast legal/gmodg_bio_treppe_2026 bzw. (stufe_2045 = TRUE) legal/gmodg_bio_treppe_2045
eop_lp_bio <- function(stufe_2045 = FALSE) {
  x <- list(applies_to = list(heating_types = c("gas", "oil", "lpg"),
                              installed_after = as.Date("2026-07-29"), building = "existing"),
            min_bio_share = list(years = c(2029, 2030, 2035, 2040),
                                 values = c(0.10, 0.15, 0.30, 0.60), interpolate = "step"))
  if (stufe_2045) {
    x$min_bio_share <- list(years = c(2029, 2030, 2035, 2040, 2045),
                            values = c(0.10, 0.15, 0.30, 0.60, 1.00), interpolate = "step")
  }
  x
}

#' Rechtsstand des Prüfkontexts: benannte Liste Thema -> Nutzlast (`NULL` = inaktiv)
eop_legal <- function(mietrecht = eop_lp_mietrecht(), mietrecht_559f = NULL,
                      co2kostaufg = eop_lp_co2(), bio_treppe = eop_lp_bio()) {
  vals <- list(mietrecht = mietrecht, mietrecht_559f = mietrecht_559f,
               co2kostaufg = co2kostaufg, bio_treppe = bio_treppe)
  out <- list()
  for (topic in names(vals)) {
    if (!is.null(vals[[topic]])) {
      out[[topic]] <- list(entry = paste0("legal/", topic), values = vals[[topic]])
    }
  }
  out
}

#' Prüfspezifikation mit Domänenblöcken, Komponenten und Rechtsstand
#'
#' `components`: benannte Liste id -> normalisierte Komponente (aus `make_component()`);
#' Domänenblöcke werden roh übernommen (numerische Blätter als Knoten).
eop_spec <- function(grid = make_grid(T = 6L), components = list(), unit_groups = list(),
                     measures = list(), energy = list(), funding = list(), financing = list(),
                     building = list(), project = list(), market = list(),
                     legal = eop_legal(), perspective = "wu_kommunal",
                     legal_state = as.Date("2026-10-25")) {
  spec <- reg_test_spec(grid, perspective = perspective, legal_state = legal_state,
                        market = deep_merge(reg_test_market_raw(), market), project = project,
                        building = building)
  spec$unit_groups <- reg_normalize_block(unit_groups, "unit_groups")
  spec$measures <- reg_normalize_block(measures, "measures")
  spec$energy <- reg_normalize_block(energy, "energy")
  spec$funding <- reg_normalize_block(funding, "funding")
  for (id in names(financing)) spec$financing[[id]] <- reg_normalize_block(financing[[id]],
                                                                           "financing")
  for (id in names(components)) spec$components[[id]] <- components[[id]]
  spec$legal <- legal
  ms <- names(measures)
  if (length(ms) > 0L) {
    spec$registers$measures <- c(spec$registers$measures, lapply(ms, function(k) {
      vofi_measure(k, "sonstige", asset_id = "b1")
    }))
  }
  spec
}

#' Laufkontext zu `eop_spec()` (n Läufe, optionale Ziehungen und gebaute Abhängigkeiten)
eop_ctx <- function(spec, grid, n = 1L, draws = NULL, deps = list()) {
  n <- as.integer(n)
  if (is.null(draws) && n > 1L) draws <- fake_draws(n, grid)
  mode <- if (is.null(draws)) "deterministic" else draws$mode
  eng_context_from_parts(grid, spec, draws = draws, components = deps, components_base = deps,
                         mode = mode, engine_env = reg_engine_env("flows"))
}

#' Komponente bauen
eop_build <- function(type, comp, ctx) {
  reg_get("flow", type)$build(comp, ctx)
}

#' Zeile einer Rückgabe nach lokalem Namen
eop_row <- function(fl, key) {
  for (r in fl$rows) if (identical(r$key, key)) return(r$values)
  NULL
}

#' Jahressummen einer Zeile (n = Lauf) nach Kalenderjahr des Rasters
eop_year <- function(values, grid, year, sim = 1L) {
  sum(values[sim, -1L][grid$year[-1L] == year])
}

#' Kostenkomponente (Attrappe der capex-Komponente von WS-E-INV): Kosten als Einmalbetrag
eop_capex_flows <- function(n, grid, measure_id, amounts, t = 1L) {
  v <- matrix(0, n, grid$T + 1L)
  v[, t + 1L] <- -rep_len(amounts, n)
  vofi_flows(vofi_row("cost", v, section = "project", category = "capex", measure_id = measure_id,
                      asset_id = "b1"))
}

#' Zuschusskomponente (Attrappe des Typs grant von WS-E2)
eop_grant_flows <- function(n, grid, measure_id, amounts, t = 1L) {
  v <- matrix(0, n, grid$T + 1L)
  v[, t + 1L] <- rep_len(amounts, n)
  vofi_flows(vofi_row(paste0("grant_", measure_id), v, section = "grants", category = "grant",
                      measure_id = measure_id))
}

#' Mietpfad bauen: Komponente `id` mit Rohparametern `...`, Domänenblöcken und Abhängigkeiten
#' @return Liste `flows`, `ctx`, `comp`, `spec`, `grid`.
eop_rp <- function(..., .measures = list(), .unit_groups = list(), .funding = list(),
                   .financing = list(), .energy = list(), .deps = list(), .n = 1L,
                   .draws = NULL, .legal = eop_legal(), .grid = make_grid(T = 10L),
                   .project = list(), .building = list(), .market = list(), .id = "u_g_rent",
                   .base_deps = NULL) {
  comp <- make_component("rent_path", ..., id = .id)
  spec <- eop_spec(.grid, components = stats::setNames(list(comp), .id),
                   unit_groups = .unit_groups, measures = .measures, energy = .energy,
                   funding = .funding, financing = .financing, building = .building,
                   project = .project, market = .market, legal = .legal)
  ctx <- if (is.null(.base_deps)) {
    eop_ctx(spec, .grid, n = .n, draws = .draws, deps = .deps)
  } else {
    n <- as.integer(.n)
    draws <- .draws
    if (is.null(draws) && n > 1L) draws <- fake_draws(n, .grid)
    eng_context_from_parts(.grid, spec, draws = draws, components = .deps,
                           components_base = .base_deps,
                           mode = if (is.null(draws)) "deterministic" else draws$mode,
                           engine_env = reg_engine_env("flows"))
  }
  list(flows = eop_build("rent_path", comp, ctx), ctx = ctx, comp = comp, spec = spec,
       grid = .grid)
}

#' Jahreswerte einer Zeile als Vektor (Kalenderjahre `years`)
eop_years <- function(res, key, years, sim = 1L) {
  v <- eop_row(res$flows, key)
  vapply(years, function(y) eop_year(v, res$grid, y, sim), double(1))
}

#' Kette von Komponenten in Reihenfolge bauen (jede sieht die zuvor gebauten als Abhängigkeiten)
#'
#' `comps`: benannte Liste id -> Rohparameter mit Feld `type`. Vorab gebaute Rückgaben
#' (Attrappen) stehen in `.deps`.
#' @return Liste `flows` (benannt nach id), `ctx` (Kontext der letzten Komponente), `spec`, `grid`.
eop_chain <- function(comps, .measures = list(), .unit_groups = list(), .energy = list(),
                      .funding = list(), .building = list(), .project = list(), .market = list(),
                      .legal = eop_legal(), .perspective = "wu_kommunal",
                      .grid = make_grid(T = 10L), .n = 1L, .draws = NULL, .deps = list()) {
  norm <- lapply(names(comps), function(id) {
    x <- comps[[id]]
    do.call(make_component, c(list(x$type), x[setdiff(names(x), "type")], list(id = id)))
  })
  names(norm) <- names(comps)
  spec <- eop_spec(.grid, components = norm, unit_groups = .unit_groups, measures = .measures,
                   energy = .energy, funding = .funding, building = .building,
                   project = .project, market = .market, legal = .legal,
                   perspective = .perspective)
  n <- as.integer(.n)
  draws <- .draws
  if (is.null(draws) && n > 1L) draws <- fake_draws(n, .grid)
  built <- .deps
  ctx <- NULL
  for (id in names(norm)) {
    ctx <- eop_ctx(spec, .grid, n = n, draws = draws, deps = built)
    built[[id]] <- eop_build(comps[[id]]$type, norm[[id]], ctx)
  }
  list(flows = built, ctx = ctx, spec = spec, grid = .grid)
}

#' Jahreswerte einer Zeile einer Komponente der Kette
eop_cy <- function(res, id, key, years, sim = 1L) {
  v <- eop_row(res$flows[[id]], key)
  vapply(years, function(y) eop_year(v, res$grid, y, sim), double(1))
}

#' Jahreswerte einer Hilfsgröße (Summe über die Perioden des Jahres)
eop_aux_y <- function(res, id, field, years, sim = 1L) {
  v <- res$flows[[id]]$aux[[field]]
  vapply(years, function(y) eop_year(v, res$grid, y, sim), double(1))
}

#' Ausdruck auswerten und alle Meldungen (vofi_message) einsammeln
#' @return Liste `value`, `messages` (Texte).
eop_messages <- function(expr) {
  msgs <- character(0)
  value <- withCallingHandlers(expr, message = function(m) {
    msgs <<- c(msgs, conditionMessage(m))
    invokeRestart("muffleMessage")
  })
  list(value = value, messages = msgs)
}
