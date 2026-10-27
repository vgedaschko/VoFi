# Tests für R/kpi-core.R (WS-D2; Spec 00 Abschnitte 5.6, 12.1-12.6, 14 Nr. 21 und 41).

kpi_spec_table <- function() {
  data.frame(
    name = c("terminal_value", "terminal_value_opp", "delta_terminal_value", "roe_classic",
             "roe_mirr", "roe_irr", "payback_time", "payback_year", "min_net_liquidity",
             "max_overdraft", "max_financing_need", "sum_equity_calls", "pv_equity_calls",
             "flag_shortfall", "flag_limit_breach", "flag_reserve_used", "dscr_min", "dscr_mean",
             "dscr_years_below", "dscr_min_new", "icr_min", "ltv_max", "ltv_end",
             "lending_ratio_max", "withdrawal_equivalent", "npv_cf_project", "irr_cf_project",
             "terminal_value_real", "monthly_burden", "monthly_burden_y1",
             "monthly_burden_avg10", "monthly_burden_construction", "burden_ratio_max",
             "monthly_net_cashflow", "monthly_net_cashflow_y1", "monthly_net_cashflow_min",
             "warm_rent", "warm_rent_y1", "warm_rent_change_prepost",
             "warm_rent_change_prepost_y1", "own_contribution", "pv_subsidies", "co2_emissions",
             "restriction_dscr", "restriction_liquidity", "restriction_warm_rent",
             "restriction_burden", "restriction_savings"),
    unit = c("EUR", "EUR", "EUR", "rate_pa", "rate_pa", "rate_pa", "years", "year", "EUR", "EUR",
             "EUR", "EUR", "EUR", "flag", "flag", "flag", "ratio", "ratio", "years", "ratio",
             "ratio", "share", "share", "share", "EUR_pa", "EUR", "rate_pa", "EUR", "EUR_month",
             "EUR_month", "EUR_month", "EUR_month", "share", "EUR_month", "EUR_month",
             "EUR_month", "EUR_m2_month", "EUR_m2_month", "EUR_m2_month", "EUR_m2_month", "EUR",
             "EUR", "t_co2", "flag", "flag", "flag", "flag", "flag"),
    rv = c(TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE,
           FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE,
           FALSE, TRUE, rep(FALSE, 20L)),
    mc = c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE,
           TRUE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE,
           FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
           FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE),
    shape = "scalar", stringsAsFactors = FALSE
  )
}

test_that("Registry: alle Kennzahlen v1 nach 12.3 mit Einheit, Restwertbezug und MC-Default", {
  tab <- kpi_spec_table()
  tab$shape[tab$name %in% c("monthly_burden", "monthly_net_cashflow", "warm_rent",
                            "warm_rent_change_prepost")] <- "series"
  reg <- vofi_types("kpi")
  expect_true(all(tab$name %in% reg$name))
  for (i in seq_len(nrow(tab))) {
    def <- reg_get("kpi", tab$name[i])
    expect_identical(def$unit, tab$unit[i], info = tab$name[i])
    expect_identical(def$shape, tab$shape[i], info = tab$name[i])
    expect_identical(def$rv_variant, tab$rv[i], info = tab$name[i])
    expect_identical(def$mc_default, tab$mc[i], info = tab$name[i])
    expect_true(vocab_has("units", def$unit), info = tab$name[i])
  }
  expect_identical(reg_get("kpi", "monthly_burden")$perspectives, "selbstnutzer")
  expect_identical(reg_get("kpi", "monthly_net_cashflow_y1")$perspectives, "kleinvermieter")
  expect_identical(reg_get("kpi", "ltv_max")$requires, "market_value")
  expect_identical(reg_get("kpi", "delta_terminal_value")$requires, "opportunity")
  expect_false(reg_get("kpi", "payback_time")$higher_is_better)
})

test_that("Vertragstests (C1-C4, K1, F7, F8) für alle Kennzahltypen", {
  for (nm in kpi_spec_table()$name) expect_type_contract(nm, "kpi")
})

test_that("Labels: Typlabels, Zusatz ohne Restwert, Vergleichskennzahlen", {
  with_strict_labels({
    for (nm in kpi_spec_table()$name) {
      expect_true(lbl_has(paste0("types.kpi.", nm, ".label")), info = nm)
      expect_true(lbl_has(paste0("types.kpi.", nm, ".description")), info = nm)
    }
    expect_identical(kpi_label("terminal_value"), "Endwert")
    expect_identical(kpi_label("terminal_value_ex_rv"), "Endwert (ohne Restwert)")
    for (nm in names(kpi_compare_specs())) {
      expect_true(lbl_has(paste0("kpi.compare.", nm, ".label")), info = nm)
      expect_false(identical(kpi_label(nm), nm))
    }
    expect_identical(kpi_label("gibt_es_nicht"), "gibt_es_nicht")
  })
  expect_identical(kpi_unit("delta_vs_reference_ex_rv"), "EUR")
  expect_identical(kpi_unit("roe_mirr"), "rate_pa")
  expect_true(is.na(kpi_unit("unbekannt")))
  expect_identical(kpi_rv_class("terminal_value"), "with")
  expect_identical(kpi_rv_class("terminal_value_ex_rv"), "without")
  expect_identical(kpi_rv_class("dscr_min"), "independent")
  expect_identical(kpi_rv_class("x", c("x", "x_ex_rv")), "with")
  expect_identical(kpi_rv_class("payback_vs_reference"), "with")
  # Restwert im Wert ohne Gegenstück _ex_rv (12.3, 12.6): kein Vermerk „unabhängig“
  for (k in c("npv_cf_project", "irr_cf_project", "co2_abatement_cost",
              "prob_better_than_ref")) {
    expect_identical(kpi_rv_info(k), list(class = "with", note = NA_character_), info = k)
  }
  for (k in c("dscr_min", "sum_equity_calls", "own_contribution", "restriction_dscr",
              "terminal_value_opp", "co2_reduction", "monthly_saving_y1")) {
    expect_identical(kpi_rv_info(k)$note, "kpi.rv_independent", info = k)
  }
  for (k in c("ltv_max", "ltv_end", "lending_ratio_max")) {
    expect_identical(kpi_rv_info(k), list(class = "independent", note = "kpi.notes.value_path"),
                     info = k)
  }
  expect_identical(kpi_rv_info("gibt_es_nicht"), list(class = "unknown", note = NA_character_))
  expect_identical(kpi_rv_class("gibt_es_nicht", c("gibt_es_nicht", "gibt_es_nicht_ex_rv")),
                   "with")
  # alle eingebauten Kennzahlen mit Restwert führen die Klasse "with" (Spec 12.3, R-52)
  for (nm in kpi_spec_table()$name) {
    def <- reg_get("kpi", nm)
    expect_true(def$rv_ref %in% c("with", "independent", "value_path"), info = nm)
    if (isTRUE(def$rv_variant)) expect_identical(def$rv_ref, "with", info = nm)
  }
  with_strict_labels({
    for (k in c("kpi.rv_independent", "kpi.notes.value_path", "kpi.notes.project_simplified",
                "kpi.notes.censored")) {
      expect_true(lbl_has(k), info = k)
    }
  })
})

test_that("kpi_compute: beide Sichten, Reihen, Perspektive, Vertragsfehler", {
  core <- example_core(3L)
  ctx <- d2_ctx(core, perspective = "selbstnutzer")
  defs <- lapply(c("terminal_value", "dscr_min", "monthly_burden", "monthly_net_cashflow"),
                 function(k) reg_get("kpi", k))
  res <- kpi_compute(defs, core, ctx)
  expect_identical(names(res$scalar), c("terminal_value", "terminal_value_ex_rv", "dscr_min"))
  expect_identical(names(res$na), names(res$scalar))
  expect_identical(nrow(res$scalar), 3L)
  expect_equal(res$scalar$terminal_value, core$stocks$BS[, 7])
  expect_equal(res$scalar$terminal_value_ex_rv, core$terminal_ex_rv$BS)
  expect_identical(names(res$series), c("monthly_burden", "monthly_net_cashflow"))
  expect_identical(dim(res$series$monthly_burden$values), c(3L, 6L))
  expect_identical(res$series$monthly_burden$years, 2027:2032)
  expect_true(all(is.na(res$series$monthly_net_cashflow$values)))
  expect_identical(unique(res$series$monthly_net_cashflow$na_reason),
                   "not_applicable_perspective")
  bad <- vofi_type("tk_bad", "kpi", label = "x", compute = function(core, ctx) 1)
  expect_error(kpi_compute(list(bad), core, ctx), class = "vofi_error_contract")
  short <- vofi_type("tk_short", "kpi", label = "x",
                     compute = function(core, ctx) vofi_kpi_value(1))
  expect_error(kpi_compute(list(short), core, ctx), class = "vofi_error_contract")
  wrong <- vofi_type("tk_wrong", "kpi", label = "x", shape = "series",
                     compute = function(core, ctx) vofi_kpi_value(rep(1, core$n)))
  expect_error(kpi_compute(list(wrong), core, ctx), class = "vofi_error_contract")
  persp <- vofi_type("tk_p", "kpi", label = "x", perspectives = "kleinvermieter",
                     compute = function(core, ctx) stop("nicht aufrufen"))
  r <- kpi_compute(list(persp), core, ctx)
  expect_true(all(is.na(r$scalar$tk_p)))
  expect_identical(unique(r$na$tk_p), "not_applicable_perspective")
  empty <- kpi_compute(list(), core, ctx)
  expect_identical(nrow(empty$scalar), 3L)
})

test_that("core_ex_rv: Terminalzustand ohne Restwert, Restwertzeilen in T null (9.4)", {
  core <- example_core(2L)
  ex <- core_ex_rv(core)
  expect_identical(ex$view, "ex_rv")
  expect_equal(ex$stocks$BS[, 7], core$terminal_ex_rv$BS)
  expect_equal(ex$stocks$G[, 7], core$terminal_ex_rv$G)
  expect_equal(ex$stocks$BS[, 1:6], core$stocks$BS[, 1:6])
  expect_equal(unname(ex$ledger$values$rv__value[, 7]), c(0, 0))
  expect_equal(ex$ledger$values$net_position[, 7], core$terminal_ex_rv$BS)
  # N2: BS_T,exRV = BS_T - RW_T
  rw <- core$ledger$values$rv__value[, 7] + core$ledger$values$rv__sale_cost[, 7]
  expect_equal(core$terminal_ex_rv$BS, core$stocks$BS[, 7] - rw)
})

test_that("Notation 12.2: q, EL, EN, NS, NOI, KD, V, Restwertpfad, W", {
  core <- example_core(2L)
  ctx <- d2_ctx(core)
  q <- kpi_q(core)
  expect_equal(q[1, ], 1.02^(0:6))
  expect_equal(kpi_el(core)[1, ], c(100000, rep(0, 6)))
  expect_equal(kpi_en(core)[1, ], c(0, rep(3000, 6)))
  expect_true(all(kpi_ns(core) == 0))
  expect_equal(kpi_tj(core), 6)
  noi <- kpi_noi(core)
  led <- core$ledger$values
  expect_equal(noi, led$rent__value + led$rent__levy_m1 + led$opex__value + led$maint__value)
  expect_equal(kpi_kd(core), -(led$loan_bank_interest + led$loan_bank_repay +
                                 led$loan_kfw_interest + led$loan_kfw_repay))
  expect_equal(kpi_kd(core, TRUE), matrix(0, 2, 7))
  expect_equal(kpi_market_value(core), led$rv__market_value)
  expect_identical(kpi_rv_basis(ctx), "method")
  expect_equal(kpi_rwp(core, ctx), led$rv__path_method)
  su <- d2_ctx(core, perspective = "selbstnutzer")
  expect_identical(kpi_rv_basis(su), "measures")
  w <- kpi_wealth(core, ctx)
  expect_equal(w[, 1:6], core$stocks$BS[, 1:6] + led$rv__path_method[, 1:6])
  expect_equal(w[, 7], core$stocks$BS[, 7])
  expect_equal(kpi_wealth(core_ex_rv(core), ctx), core_ex_rv(core)$stocks$BS)
  spec <- reg_test_spec(core$grid, analysis = list(rv_path_basis = "measures"))
  expect_identical(kpi_rv_basis(d2_ctx(core, spec = spec)), "measures")
})

test_that("Betriebsjahre, Stabilisierungsjahr und dauerhafte Bedingung", {
  g4 <- vofi_time_grid(as.Date("2027-01-01"), 30L, construction_months = 9L,
                       construction_step_months = 1L)
  oy <- kpi_op_years(g4)
  expect_identical(oy$P[1:2], 1:2)
  expect_identical(oy$first[1:2], c(11L, 12L))
  expect_identical(oy$months[1:2], c(3, 12))
  expect_identical(oy$full[1:2], c(FALSE, TRUE))
  expect_identical(oy$year[1:2], c(2027L, 2028L))
  core <- example_core(1L)
  ctx <- d2_ctx(core)
  expect_identical(kpi_stab_year(oy, ctx), 2028L)
  spec <- reg_test_spec(core$grid, analysis = list(stabilization_year = 2030L))
  oy6 <- kpi_op_years(core$grid)
  expect_identical(kpi_stab_mask(oy6, d2_ctx(core, spec = spec)),
                   c(FALSE, FALSE, FALSE, TRUE, TRUE, TRUE))
  expect_identical(kpi_stab_mask(oy6, ctx), rep(TRUE, 6L))
  m <- matrix(c(1, 3, 2, 5, NA, 1), 2)
  expect_equal(kpi_row_min(m), c(1, 1))
  expect_equal(kpi_row_max(m), c(2, 5))
  expect_equal(kpi_row_min(m, m > 10), c(NA_real_, NA_real_))
  ok <- rbind(c(TRUE, FALSE, TRUE, TRUE), c(FALSE, FALSE, FALSE, FALSE),
              c(TRUE, TRUE, TRUE, TRUE), c(TRUE, TRUE, TRUE, FALSE))
  expect_identical(kpi_first_permanent(ok), c(3L, NA, 1L, NA))
  expect_identical(kpi_series_years(kpi_op_years(vofi_time_grid(as.Date("2027-01-01"), 1L,
                                                                periods_months = 12L,
                                                                construction_months = 12L)),
                                    core$grid), 2032L)
})

test_that("kpi_value_codes: Vorrang, Codes je Lauf, fehlender Code", {
  v <- kpi_value_codes(c(1, 2, 3, 4), list(c(TRUE, FALSE, FALSE, FALSE), "no_equity"),
                       list(c(TRUE, TRUE, FALSE, FALSE), "equity_lost"),
                       list(c(FALSE, FALSE, TRUE, FALSE), c("a", "b", NA, "d")))
  expect_identical(v$values, c(NA, NA, NA, 4))
  expect_identical(v$na_reason, c("no_equity", "equity_lost", "not_computed", NA))
  s <- kpi_value_codes(matrix(1:4, 2), list(c(FALSE, TRUE), "no_payback"), years = 2027:2028)
  expect_identical(s$shape, "series")
  expect_true(all(is.na(s$values[2, ])))
})

test_that("Anwendbarkeit: Restriktionen, Mietersicht, Policy stop", {
  core <- example_core(2L)
  ctx <- d2_ctx(core, analysis = list(restrictions = "dscr", tenant_view = FALSE))
  expect_identical(kpi_restrictions(ctx), "dscr")
  expect_false(kpi_tenant_view(ctx))
  expect_null(kpi_not_applicable(ctx, restriction = "dscr"))
  expect_identical(kpi_not_applicable(ctx, restriction = "liquidity"),
                   "not_applicable_perspective")
  expect_identical(kpi_not_applicable(ctx, tenant_view = TRUE), "not_applicable_perspective")
  expect_identical(kpi_not_applicable(ctx, perspectives = "selbstnutzer"),
                   "not_applicable_perspective")
  spec <- reg_test_spec(core$grid)
  spec$analysis$tenant_view <- NULL
  expect_true(kpi_tenant_view(d2_ctx(core, spec = spec)))
  stopped <- core
  stopped$flags$stopped <- c(TRUE, FALSE)
  for (k in c("terminal_value", "delta_terminal_value", "roe_mirr", "payback_time",
              "terminal_value_real", "withdrawal_equivalent")) {
    v <- d2_kpi(k, stopped, ctx)
    expect_true(is.na(v$values[1]), info = k)
    expect_identical(v$na_reason[1], "run_stopped", info = k)
    expect_false(is.na(v$values[2]), info = k)
  }
  expect_false(is.na(d2_kpi("terminal_value_opp", stopped, ctx)$values[1]))
  expect_false(is.na(d2_kpi("min_net_liquidity", stopped, ctx)$values[1]))
  expect_identical(kpi_flag(list(flags = data.frame(x = 1), n = 1L), "stopped"), FALSE)
})

test_that("Primärkennzahl (12.3a, R-65, R-68)", {
  spec <- list(project = list(project_type = "neubau", comparison_mode = "absolute"),
               analysis = list(primary_kpi = "auto"))
  p <- kpi_primary(spec)
  expect_identical(p$kpi, "delta_terminal_value")
  expect_identical(p$payback, "payback_time")
  expect_identical(p$return_kpi, "roe_mirr")
  expect_true(is.na(p$note))
  spec$project$project_type <- "sanierung_eh"
  p <- kpi_primary(spec)
  expect_identical(p$kpi, "delta_vs_reference")
  expect_identical(p$payback, "payback_vs_reference")
  expect_identical(p$return_kpi, "incremental_return")
  expect_identical(p$note, "kpi.notes.contains_existing")
  spec$building <- list(existing_value_eur = 500000)
  expect_identical(kpi_primary(spec)$note, "kpi.notes.vs_sale")
  spec$project$comparison_mode <- "differential"
  expect_identical(kpi_primary(spec)$kpi, "delta_terminal_value")
  spec$analysis$primary_kpi <- "delta_vs_reference"
  expect_identical(kpi_primary(spec)$kpi, "delta_vs_reference")
  for (pt in c("heizungstausch", "sanierung_stufenweise", "sanierung_einzelmassnahmen")) {
    expect_identical(kpi_primary(list(project = list(project_type = pt)))$kpi,
                     "delta_vs_reference")
  }
  for (pt in c("erwerb_sanierung", "erwerb_neubau")) {
    expect_identical(kpi_primary(list(project = list(project_type = pt)))$kpi,
                     "delta_terminal_value")
  }
  with_strict_labels({
    expect_true(lbl_has("kpi.notes.contains_existing"))
    expect_true(lbl_has("kpi.notes.vs_sale"))
  })
})

test_that("vofi_kpis: deterministisches Ergebnis, Filter rv/which, je WE und m²", {
  x <- example_result()
  tab <- vofi_kpis(x)
  expect_s3_class(tab, "data.frame")
  expect_identical(tab$kpi, names(x$kpis))
  expect_identical(names(tab), c("kpi", "base", "label", "unit", "rv", "per", "note", "primary",
                                 "value", "na_reason", "na_label"))
  expect_equal(tab$value[tab$kpi == "terminal_value"], x$kpis$terminal_value)
  expect_identical(tab$rv[tab$kpi == "terminal_value_ex_rv"], "without")
  expect_identical(tab$rv[tab$kpi == "sum_equity_calls"], "independent")
  expect_identical(tab$note[tab$kpi == "sum_equity_calls"], "unabhängig vom Restwert")
  expect_true(tab$primary[tab$kpi == "delta_terminal_value"])
  expect_true(tab$primary[tab$kpi == "delta_terminal_value_ex_rv"])
  expect_identical(tab$na_reason[tab$kpi == "roe_mirr_ex_rv"], "equity_lost")
  expect_identical(tab$na_label[tab$kpi == "roe_mirr_ex_rv"],
                   lbl("vocab.na_reasons.equity_lost"))
  with <- vofi_kpis(x, rv = "with")
  expect_false(any(endsWith(with$kpi, "_ex_rv")))
  expect_true("sum_equity_calls" %in% with$kpi)
  without <- vofi_kpis(x, rv = "without")
  expect_true(all(without$rv %in% c("without", "independent")))
  expect_false("terminal_value" %in% without$kpi)
  one <- vofi_kpis(x, which = "terminal_value")
  expect_identical(one$kpi, c("terminal_value", "terminal_value_ex_rv"))
  expect_identical(vofi_kpis(x, which = "terminal_value_ex_rv")$kpi, "terminal_value_ex_rv")
  expect_error(vofi_kpis(x, which = "terminal_valu"), class = "vofi_error_input")
  expect_error(vofi_kpis(x, which = 1), class = "vofi_error_input")
  expect_error(vofi_kpis(x, rv = "x"), class = "vofi_error_input")
  expect_error(vofi_kpis(list()), class = "vofi_error_input")
  unit <- vofi_kpis(x, per = "unit")
  expect_equal(unit$value[unit$kpi == "terminal_value"], x$kpis$terminal_value / 12)
  expect_equal(unit$value[unit$kpi == "roe_mirr"], x$kpis$roe_mirr)
  expect_identical(unique(unit$per), "unit")
  m2 <- vofi_kpis(x, which = c("terminal_value", "withdrawal_equivalent"), per = "m2")
  expect_equal(m2$value[m2$kpi == "terminal_value"], x$kpis$terminal_value / 900)
  expect_equal(m2$value[m2$kpi == "withdrawal_equivalent"], x$kpis$withdrawal_equivalent / 900)
  y <- x
  y$spec$building$n_units <- NULL
  expect_error(vofi_kpis(y, per = "unit"), class = "vofi_error_input")
  y$spec$building$living_area_m2 <- 0
  expect_error(vofi_kpis(y, per = "m2"), class = "vofi_error_input")
  expect_identical(nrow(vofi_kpis(x, which = character(0))), 0L)
})

test_that("vofi_kpis: Restwertbezug und Vermerke (12.3, 12.3a, 12.4, 12.5)", {
  a <- d2_run(d2_oracle_a())
  tab <- vofi_kpis(a, which = c("npv_cf_project", "irr_cf_project", "dscr_min",
                                "terminal_value"))
  np <- tab[tab$kpi == "npv_cf_project", ]
  expect_identical(np$rv, "with")
  expect_identical(np$note, lbl("kpi.notes.project_simplified"))
  # der Kapitalwert enthält den Restwert 40.000 / 1,03^5: ohne ihn wäre er negativ
  expect_equal(np$value - 40000 / 1.03^5, -24308.39, tolerance = 0.005 / 24308.39)
  ir <- tab[tab$kpi == "irr_cf_project", ]
  expect_identical(ir$rv, "with")
  expect_identical(ir$note, lbl("kpi.notes.project_simplified"))
  expect_identical(tab$note[tab$kpi == "dscr_min"], lbl("kpi.rv_independent"))
  expect_true(all(is.na(tab$note[startsWith(tab$kpi, "terminal_value")])))
  expect_false(any(grepl(lbl("kpi.rv_independent"), tab$note[tab$rv == "with"], fixed = TRUE)))
  wo <- vofi_kpis(a, rv = "without")
  expect_false(any(c("npv_cf_project", "irr_cf_project") %in% wo$kpi))
  expect_true("npv_cf_project" %in% vofi_kpis(a, rv = "with")$kpi)
  expect_true(all(is.na(vofi_kpis(a, which = "delta_terminal_value")$note)))
  # LTV und Beleihungsauslauf: Wertpfad V_t statt Restwert
  c1 <- d2_run(d2_oracle_c())
  lt <- vofi_kpis(c1, which = c("ltv_max", "ltv_end", "lending_ratio_max"))
  expect_identical(unique(lt$rv), "independent")
  expect_identical(unique(lt$note), lbl("kpi.notes.value_path"))
  # Bestandsprojekt (12.3a): Vermerk der Endwertdifferenz gegenüber der Unterlassung
  no <- d2_run(d2_oracle_in_kind(existing_value = NULL))
  d <- vofi_kpis(no, which = "delta_terminal_value")
  expect_identical(d$kpi, c("delta_terminal_value", "delta_terminal_value_ex_rv"))
  expect_identical(d$note, rep(lbl("kpi.notes.contains_existing"), 2L))
  expect_true(all(is.na(vofi_kpis(no, which = "terminal_value")$note)))
  ik <- d2_run(d2_oracle_in_kind())
  expect_identical(vofi_kpis(ik, which = "delta_terminal_value")$note,
                   rep(lbl("kpi.notes.vs_sale"), 2L))
  # mehrere Vermerke werden mit "; " verbunden
  keys <- kpi_note_keys("npv_cf_project", "kpi.rv_independent", censored = TRUE)
  expect_identical(keys[[1L]], c("kpi.rv_independent", "kpi.notes.project_simplified",
                                 "kpi.notes.censored"))
  # Simulation: Zensurvermerk nur bei Renditen mit undefinierten Läufen (12.4)
  mc <- example_mc_result(50L)
  st <- vofi_kpis(mc, which = "roe_mirr")
  expect_true(all(is.na(st$note)))
  mc$kpis$roe_mirr[1:5] <- NA
  mc$kpi_na$roe_mirr[1:5] <- "equity_lost"
  st <- vofi_kpis(mc, which = c("roe_mirr", "terminal_value"))
  expect_identical(st$note[st$kpi == "roe_mirr"], lbl("kpi.notes.censored"))
  expect_identical(st$n_valid[st$kpi == "roe_mirr"], 45L)
  expect_true(is.na(st$note[st$kpi == "terminal_value"]))
})

test_that("vofi_kpis: Ergebnis mit mehreren Läufen, Simulation und Vergleich", {
  x <- example_result()
  two <- x
  two$kpis <- rbind(x$kpis, x$kpis)
  two$kpis$terminal_value[2] <- 1
  two$kpi_na <- rbind(x$kpi_na, x$kpi_na)
  tab <- vofi_kpis(two, which = "terminal_value")
  expect_identical(tab$sim, c(1L, 1L, 2L, 2L))
  expect_equal(tab$value[3], 1)
  mc <- example_mc_result(200L)
  st <- vofi_kpis(mc)
  expect_true(all(c("deterministic", "mean", "sd", "q05", "q50", "q95", "p_neg", "na_share",
                    "n_valid") %in% names(st)))
  expect_false(any(st$kpi %in% c("sim", "block")))
  tv <- st[st$kpi == "terminal_value", ]
  expect_equal(tv$mean, mean(mc$kpis$terminal_value))
  expect_equal(tv$q50, stats::median(mc$kpis$terminal_value))
  expect_equal(tv$deterministic, mc$deterministic$kpis$terminal_value)
  expect_identical(tv$n_valid, 200L)
  st_u <- vofi_kpis(mc, which = "terminal_value", per = "unit")
  expect_equal(st_u$mean[1], tv$mean / 12)
  cmp <- example_comparison()
  ct <- vofi_kpis(cmp)
  expect_true(all(c("variant", "kpi", "value") %in% names(ct)))
  expect_identical(sort(unique(ct$variant)), c("a", "base"))
  d <- ct[ct$kpi == "delta_vs_reference", ]
  expect_equal(d$value, 2000)
  expect_identical(d$variant, "a")
  expect_identical(d$unit, "EUR")
  ct1 <- vofi_kpis(cmp, which = "terminal_value")
  expect_identical(unique(ct1$base), "terminal_value")
  expect_identical(nrow(vofi_kpis(cmp, which = "gibt_es_nicht")), 0L)
  cmp$results$a <- mc
  ctm <- vofi_kpis(cmp, which = "terminal_value", rv = "with")
  expect_equal(ctm$value[ctm$variant == "a"], mean(mc$kpis$terminal_value))
})

test_that("vofi_register_kpi: Nutzerkennzahl, Prüfungen, Einsatz in der Engine", {
  saved <- reg_state$types
  withr::defer(reg_state$types <- saved)
  f <- function(core, ctx) vofi_kpi_value(core$stocks$BS[, core$grid$T + 1L] * 2)
  def <- vofi_register_kpi("ew_doppelt", f, label = "Doppelter Endwert", rv_variant = TRUE)
  expect_s3_class(def, "vofi_typedef")
  expect_true(reg_has("kpi", "ew_doppelt"))
  expect_identical(reg_source("kpi", "ew_doppelt"), "user")
  expect_identical(kpi_label("ew_doppelt"), "Doppelter Endwert")
  expect_identical(kpi_label("ew_doppelt_ex_rv"), "Doppelter Endwert (ohne Restwert)")
  expect_type_contract("ew_doppelt", "kpi")
  expect_error(vofi_register_kpi("ew_doppelt", f), class = "vofi_error_registry")
  expect_silent(vofi_register_kpi("ew_doppelt", f, rv_variant = TRUE, overwrite = TRUE))
  vofi_register_kpi("nur_selbst", f, perspectives = "selbstnutzer")
  expect_error(vofi_register_kpi("Falsch", f), class = "vofi_error_registry")
  expect_error(vofi_register_kpi("x_ex_rv", f), class = "vofi_error_registry")
  expect_error(vofi_register_kpi("ok_name", function(x) 1), class = "vofi_error_registry")
  expect_error(vofi_register_kpi("ok_name", f, unit = "Euro"), class = "vofi_error_registry")
  expect_error(vofi_register_kpi("ok_name", f, shape = "matrix"), class = "vofi_error_input")
  expect_error(vofi_register_kpi("ok_name", f, rv_variant = NA), class = "vofi_error_registry")
  expect_error(vofi_register_kpi("ok_name", f, label = 1), class = "vofi_error_registry")
  expect_error(vofi_register_kpi("ok_name", f, requires = "geld"),
               class = "vofi_error_registry")
  sc <- d2_oracle_a()
  sc$analysis$kpis <- c("terminal_value", "ew_doppelt", "nur_selbst")
  res <- d2_run(sc)
  expect_equal(res$kpis$ew_doppelt, 2 * res$kpis$terminal_value)
  expect_equal(res$kpis$ew_doppelt_ex_rv, 2 * res$kpis$terminal_value_ex_rv)
  expect_false("nur_selbst" %in% names(res$kpis))
  expect_warning(vofi_register_kpi("terminal_value", f, overwrite = TRUE),
                 class = "vofi_warning")
  expect_identical(reg_source("kpi", "terminal_value"), "user")
})

test_that("kpi_compare_values: Vergleichsregel (Orakel (g)), CRN, CO2, Haushalt", {
  a <- d2_run(d2_oracle_g("a"))
  b <- d2_run(d2_oracle_g("base"))
  cmp <- kpi_compare_values(a, b, q_T = 1.02^2)
  expect_equal(cmp$kpis$delta_vs_reference, -80, tolerance = 1e-9)
  # Identität 9.6 Nr. 4: EW_A - EW_B - Sum_t (NS^A_t - NS^B_t) q_T / q_t
  expect_equal(cmp$kpis$delta_vs_reference, (16000 - 13020) - 3000 * 1.02, tolerance = 1e-9)
  expect_equal(a$kpis$sum_equity_calls, 3000)
  expect_equal(a$kpis$pv_equity_calls, 2941.18, tolerance = 0.005 / 2941.18)
  expect_true(is.na(cmp$kpis$payback_vs_reference))
  expect_identical(cmp$na$payback_vs_reference, "not_computed")
  expect_identical(cmp$na$monthly_saving_y1, "not_applicable_perspective")
  expect_identical(cmp$na$co2_abatement_cost, "no_co2_reduction")
  # fehlende Kennzahl (12.4): perspektivfremd vs. nicht angefordert bzw. über requires entfallen
  expect_false("warm_rent_y1" %in% names(a$kpis))
  expect_identical(cmp$na$warm_rent_change_y1, "not_computed")
  expect_identical(cmp$na$monthly_cashflow_change_y1, "not_applicable_perspective")
  a2 <- a
  a2$kpis$co2_emissions <- NULL
  a2$kpi_na$co2_emissions <- NULL
  out2 <- kpi_compare_values(a2, b, q_T = 1.02^2)
  expect_identical(out2$na$co2_reduction, "not_computed")
  expect_identical(out2$na$co2_abatement_cost, "not_computed")
  bare <- list(kpis = data.frame(delta_terminal_value = 1),
               kpi_na = data.frame(delta_terminal_value = NA_character_))
  unk <- kpi_compare_values(bare, bare)
  expect_identical(unk$na$monthly_saving_y1, "not_computed")
  su <- kpi_compare_values(bare, bare, perspective = "selbstnutzer")
  expect_identical(su$na$monthly_saving_y1, "not_computed")
  expect_identical(su$na$monthly_cashflow_change_y1, "not_applicable_perspective")
  kv <- bare
  kv$perspective <- "kleinvermieter"
  mix <- kpi_compare_values(kv, bare, perspective = "selbstnutzer")
  expect_identical(mix$na$monthly_saving_y1, "not_applicable_perspective")
  expect_identical(mix$na$monthly_cashflow_change_y1, "not_applicable_perspective")
  expect_identical(kpi_cmp_missing_code(NULL, "selbstnutzer"), "not_computed")
  expect_identical(kpi_cmp_missing_code("gibt_es_nicht", "selbstnutzer"), "not_computed")
  same <- kpi_compare_values(a, a)
  expect_identical(same$kpis$delta_vs_reference, 0)
  expect_identical(same$kpis$delta_vs_reference_ex_rv, 0)
  expect_identical(same$na$co2_abatement_cost, "not_computed")
  # synthetische Ergebnisse mit CO2, Belastung und Cashflow
  mk <- function(dtv, co2, burden, cf, wr) {
    list(kpis = data.frame(delta_terminal_value = dtv, co2_emissions = co2,
                           monthly_burden_y1 = burden, monthly_burden_avg10 = burden,
                           monthly_net_cashflow_y1 = cf, warm_rent_y1 = wr),
         kpi_na = data.frame(delta_terminal_value = NA_character_,
                             co2_emissions = NA_character_,
                             monthly_burden_y1 = ifelse(is.na(burden), "no_operation_period",
                                                        NA_character_),
                             monthly_burden_avg10 = NA_character_,
                             monthly_net_cashflow_y1 = NA_character_,
                             warm_rent_y1 = NA_character_, stringsAsFactors = FALSE))
  }
  v <- mk(c(-1000, 500), c(10, 12), c(800, NA), c(-100, 50), c(9.5, 9.8))
  r <- mk(c(0, 0), c(30, 12), c(900, 900), c(-150, 40), c(9.0, 9.0))
  out <- kpi_compare_values(v, r, q_T = c(1.1, 1.1))
  expect_equal(out$kpis$co2_reduction, c(20, 0))
  expect_equal(out$kpis$co2_abatement_cost[1], (1000 / 1.1) / 20)
  expect_identical(out$na$co2_abatement_cost, c(NA, "no_co2_reduction"))
  expect_equal(out$kpis$monthly_saving_y1, c(100, NA))
  expect_identical(out$na$monthly_saving_y1, c(NA, "no_operation_period"))
  expect_equal(out$kpis$monthly_cashflow_change_y1, c(50, 10))
  expect_equal(out$kpis$warm_rent_change_y1, c(0.5, 0.8))
  expect_identical(names(out$kpis), names(out$na))
})

test_that("Zeilenminimum und -maximum: schneller Weg = Spaltenschleife (9.10)", {
  set.seed(5)
  m <- matrix(round(stats::rnorm(60), 1), 6L, 10L)
  m[2L, ] <- 0.5
  m[3L, c(2L, 7L)] <- c(-Inf, Inf)
  m[4L, ] <- c(-0, 0, rep(1, 8))
  m[5L, ] <- Inf
  all_cols <- matrix(TRUE, nrow(m), ncol(m))
  expect_true(kpi_row_ext_ok(m))
  expect_identical(kpi_row_min(m), kpi_row_min(m, all_cols))
  expect_identical(kpi_row_max(m), kpi_row_max(m, all_cols))
  expect_identical(kpi_row_min(m), apply(m, 1L, function(x) {
    v <- min(x)
    if (is.finite(v)) v else NA_real_
  }))
  # mit NA bzw. ohne Spalten: Spaltenschleife
  m_na <- m
  m_na[1L, 3L] <- NA
  expect_false(kpi_row_ext_ok(m_na))
  expect_identical(kpi_row_max(m_na), kpi_row_max(m_na, !is.na(m_na)))
  expect_false(kpi_row_ext_ok(matrix(0, 3L, 0L)))
  expect_identical(kpi_row_min(matrix(0, 3L, 0L)), rep(NA_real_, 3L))
  expect_false(kpi_row_ext_ok(matrix(1L, 2L, 2L)))
})

test_that("Aufzinsfaktoren q: Zwischenspeicher der letzten Eingabe (9.10)", {
  core <- function(h) list(rates = list(h_net = h), grid = NULL)
  h1 <- matrix(c(0, 0.02, 0.03, 0, 0.01, 0.01), 2L, 3L, byrow = TRUE)
  h2 <- h1 * 2
  q1 <- kpi_q(core(h1))
  expect_identical(q1, cbind(1, 1 * (1 + h1[, 2L]), (1 * (1 + h1[, 2L])) * (1 + h1[, 3L])))
  expect_identical(kpi_q(core(h1 + 0)), q1)
  q2 <- kpi_q(core(h2))
  expect_identical(q2[, 3L], (1 + h2[, 2L]) * (1 + h2[, 3L]))
  expect_identical(kpi_q(core(h1)), q1)
})
