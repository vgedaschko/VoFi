# Tests für R/report-views.R (WS-H): vofi_tenant_view(), vofi_household_view() (Spec 00
# Abschnitte 12.3, 12.6, 14 Nr. 27-28; Spec 01 Teil B 3.9.3, 3.10.4; Memo 07 Paragraf 5.4).

test_that("vofi_tenant_view: Warmmiete vorher/nachher (TC-1-Werte) gleich den Kennzahlen", {
  res <- wsh_run(wsh_tenant_scenario())
  tv <- vofi_tenant_view(res)
  expect_s3_class(tv, "data.frame")
  expect_identical(attr(tv, "unit"), "EUR_m2_month")
  expect_identical(tv$year, 2027:2032)
  expect_equal(tv$rent, rep(6, 6L))
  expect_equal(tv$levy, rep(0.25, 6L))
  expect_equal(tv$operating, rep(2, 6L))
  # Spec 01 Teil B TC-1: Mieter-Heizkosten nachher 4.998,00, vorher 17.157,42 (1.000 m²)
  expect_equal(tv$energy, rep(4998 / 12000, 6L))
  expect_equal(tv$energy_pre, rep(17157.42 / 12000, 6L))
  expect_equal(tv$energy_pre - tv$energy, rep(1.013285, 6L), tolerance = 1e-9)
  expect_equal(tv$warm_rent, as.double(res$kpi_series$warm_rent$values[1L, ]))
  expect_equal(tv$change_prepost,
               as.double(res$kpi_series$warm_rent_change_prepost$values[1L, ]))
  expect_equal(tv$warm_rent - tv$warm_rent_pre, tv$change_prepost)
  expect_equal(tv$change_prepost[2L], res$kpis$warm_rent_change_prepost_y1)
  expect_true(all(is.na(tv$na_reason)))
  expect_false("change_vs_reference" %in% names(tv))
  expect_false("coop_warning" %in% names(tv))
})

test_that("vofi_tenant_view: Vergleich gegen\u00fcber der Referenz und NA-Begr\u00fcndungen", {
  a <- wsh_run(wsh_tenant_scenario())
  b <- wsh_run(wsh_tenant_scenario(levy = 0, after = 17157.42, id = "ohne"))
  cmp <- wsh_comparison(list(ohne = b, mit = a))
  tv <- vofi_tenant_view(cmp)
  expect_identical(unique(tv$variant), c("ohne", "mit"))
  mit <- tv[tv$variant == "mit", ]
  expect_equal(mit$change_vs_reference, rep(0.25 + (4998 - 17157.42) / 12000, 6L))
  expect_equal(mit$change_vs_reference[1L], unname(cmp$differences$warm_rent_change_y1[1L, "mit"]))
  expect_equal(tv$change_vs_reference[tv$variant == "ohne"], rep(0, 6L))
  expect_identical(unique(vofi_tenant_view(cmp, variant = "mit")$variant), "mit")
  expect_error(vofi_tenant_view(cmp, variant = "x"), class = "vofi_error_input")
  # ohne Mieterdaten bzw. ohne Wohnfläche
  tv0 <- vofi_tenant_view(example_result())
  expect_true(all(is.na(tv0$warm_rent)))
  expect_true(all(tv0$na_reason == "no_tenant_data"))
  sc <- wsh_tenant_scenario()
  sc$building$living_area_m2 <- NULL
  tv1 <- vofi_tenant_view(wsh_run(sc))
  expect_true(all(tv1$na_reason == "no_living_area"))
  expect_true(all(is.na(tv1$warm_rent)))
  sc2 <- wsh_tenant_scenario()
  sc2$components$heiz_vor <- NULL
  tv2 <- vofi_tenant_view(wsh_run(sc2))
  expect_true(all(tv2$na_reason_prepost == "no_tenant_data"))
  expect_true(all(is.na(tv2$change_prepost)))
  expect_false(anyNA(tv2$warm_rent))
  # Simulation: Basisfall
  expect_identical(vofi_tenant_view(wsh_mc())$year, tv0$year)
  expect_error(vofi_tenant_view(1), class = "vofi_error_input")
})

test_that("Genossenschaft: Hinweis zu Nebenerl\u00f6sen (Teil B 3.9.3)", {
  res <- wsh_run(wsh_tenant_scenario("wu_genossenschaft", side_income = 6000))
  q <- rep_coop_income_check(res)
  expect_equal(q$share, rep(6000 / (72000 + 3000 + 6000), 6L))
  expect_identical(unique(q$threshold), 0.05)
  expect_true(all(q$warning))
  tv <- vofi_tenant_view(res)
  expect_true(all(tv$coop_warning))
  expect_true(any(grepl("KStG", rep_result_notes(res), fixed = TRUE)))
  # Mieterstrom (energy_income aus frei definierter Reihe): Schwelle 0,15
  res2 <- wsh_run(wsh_tenant_scenario("wu_genossenschaft", side_income = 6000,
                                      tenant_power = TRUE))
  q2 <- rep_coop_income_check(res2)
  expect_identical(unique(q2$threshold), 0.15)
  expect_false(any(q2$warning))
  expect_false(any(grepl("KStG", rep_result_notes(res2), fixed = TRUE)))
})

test_that("Rundung im Haushaltsmodus (Memo 07 Paragraf 5.4)", {
  expect_identical(rep_round_household(c(42, 47.6, 117, -233.4, 0), "month"),
                   c(40, 50, 120, -230, 0))
  expect_identical(rep_round_household(c(15680, -349), "sum"), c(15700, -300))
  expect_identical(rep_round_household(0.316, "pct"), 32)
  expect_identical(rep_amount_text(-1234.5, "sum"), "1.200")
  expect_error(rep_round_household(1, "jahr"), class = "vofi_error_input")
})

test_that("vofi_household_view (Selbstnutzer): Belastung je Jahr gleich den Kennzahlen", {
  res <- wsh_run(wsh_self_scenario())
  hv <- vofi_household_view(res)
  expect_identical(attr(hv, "perspective"), "selbstnutzer")
  op <- hv[hv$phase == "operation", ]
  expect_equal(op$burden, as.double(res$kpi_series$monthly_burden$values[1L, ]))
  expect_identical(op$year, res$kpi_series$monthly_burden$years)
  expect_equal(op$burden, op$interest + op$repay + op$fees + op$energy + op$energy_income +
                 op$maintenance + op$operating + op$other)
  expect_equal(op$burden_ex_repay, op$burden - op$repay)
  expect_equal(op$burden[op$full_year][1L], res$kpis$monthly_burden_y1)
  expect_equal(mean(op$burden[op$full_year]), res$kpis$monthly_burden_avg10)
  expect_equal(max(op$burden_ratio), res$kpis$burden_ratio_max)
  # Bauphase: Doppelbelastung mit bisheriger Miete (12.3)
  cr <- hv[hv$phase == "construction", ]
  expect_identical(nrow(cr), 1L)
  expect_identical(cr$op_year, 0L)
  expect_identical(cr$current_rent, 900)
  expect_equal(cr$burden, res$kpis$monthly_burden_construction)
  # Wartung 250 EUR/Jahr ab Fertigstellung
  expect_equal(op$maintenance, rep(250 / 12, nrow(op)))
  expect_identical(sum(hv$equity_calls), 0)
  s <- attr(hv, "summary")
  expect_true(all(c("burden_y1", "burden_construction", "burden_ratio", "own_contribution",
                    "equity_calls", "payback_year") %in% s$item))
  expect_equal(s$value[s$item == "own_contribution"], res$kpis$own_contribution)
  # Eigenanteil je Jahr der Zahlung, Kredite genannt (SN-05)
  oc_txt <- s$text[s$item == "own_contribution"]
  expect_match(oc_txt, "10.000", fixed = TRUE)
  expect_match(oc_txt, lbl("report.household.text.own_contribution_loans"), fixed = TRUE)
  expect_false(grepl("Einmalbetrag", oc_txt, fixed = TRUE))
  expect_identical(s$text[s$item == "burden_y1"],
                   lbl("report.household.text.burden_y1", value = "530", ex = "390"))
  expect_identical(s$text[s$item == "burden_construction"],
                   lbl("report.household.text.burden_construction", value = "1.100"))
  expect_identical(s$text[s$item == "equity_calls"],
                   lbl("report.household.text.no_equity_calls"))
  expect_identical(s$text[s$item == "burden_ratio"],
                   lbl("report.household.text.burden_ratio", value = "13"))
  expect_true(is.na(s$value[s$item == "payback_year"]))
  paid <- sum((hv$burden - hv$current_rent) * hv$months) + res$kpis$own_contribution
  expect_equal(s$value[s$item == "total_cost"], paid)
  expect_match(s$text[s$item == "total_cost"], rep_amount_text(paid, "sum"), fixed = TRUE)
})

test_that("vofi_household_view (Vergleich): Ersparnis, W\u00f6rter statt Vorzeichen", {
  wp <- wsh_run(wsh_self_scenario())
  gas <- wsh_run(wsh_self_scenario(energy = 4500, capex = -12000, loan = 0, id = "gas"))
  cmp <- wsh_comparison(list(wp = wp, gas = gas))
  hv <- vofi_household_view(cmp)
  g <- hv[hv$variant == "gas" & hv$phase == "operation", ]
  w <- hv[hv$variant == "wp" & hv$phase == "operation", ]
  expect_equal(g$saving, w$burden - g$burden)
  expect_equal(g$saving[g$full_year][1L],
               unname(cmp$differences$monthly_saving_y1[1L, "gas"]))
  expect_equal(mean(g$saving[g$full_year]),
               unname(cmp$differences$monthly_saving_avg10[1L, "gas"]))
  gg <- hv[hv$variant == "gas", ]
  expect_equal(gg$cumulative_saving, cumsum(gg$saving * gg$months))
  expect_equal(gg$wealth_diff_vs_reference,
               gg$wealth_diff - hv$wealth_diff[hv$variant == "wp"])
  s <- attr(hv, "summary")
  sg <- s[s$variant == "gas", ]
  y1 <- g$saving[g$full_year][1L]
  expect_gt(y1, 0)
  expect_identical(sg$text[sg$item == "saving_y1"],
                   lbl("report.household.text.saving", ref = "wp",
                       when = lbl("report.household.text.when_y1"),
                       value = rep_amount_text(y1)))
  # Gesamtersparnis = Gesamtkosten der Referenz - Gesamtkosten der Variante (SN-03)
  tot <- s$value[s$variant == "wp" & s$item == "total_cost"] -
    sg$value[sg$item == "total_cost"]
  expect_equal(sg$value[sg$item == "total_saving"], tot)
  expect_identical(sg$text[sg$item == "total_saving"],
                   lbl(if (tot >= 0) "report.household.text.total_saving" else
                     "report.household.text.total_more", n = nrow(g), ref = "wp",
                       value = rep_amount_text(tot, "sum")))
  # umgekehrte Richtung: "zahlen ... mehr"
  cmp2 <- wsh_comparison(list(gas = gas, wp = wp))
  s2 <- attr(vofi_household_view(cmp2), "summary")
  expect_match(s2$text[s2$variant == "wp" & s2$item == "saving_y1"],
               lbl("report.household.text.more", ref = "gas",
                   when = lbl("report.household.text.when_y1"), value = rep_amount_text(y1)),
               fixed = TRUE)
  expect_false("saving_y1" %in% s$item[s$variant == "wp"])
})

test_that("vofi_household_view (Kleinvermieter): monatlicher Cashflow gleich der Kennzahl", {
  res <- wsh_run(wsh_landlord_scenario())
  hv <- vofi_household_view(res)
  expect_identical(attr(hv, "perspective"), "kleinvermieter")
  expect_equal(hv$cashflow, as.double(res$kpi_series$monthly_net_cashflow$values[1L, ]))
  expect_equal(hv$rent, rep(2500, nrow(hv)))
  expect_equal(hv$costs, rep(-250, nrow(hv)))
  s <- attr(hv, "summary")
  expect_identical(s$text[s$item == "cashflow_y1"],
                   lbl("report.household.text.cashflow_surplus",
                       value = rep_amount_text(hv$cashflow[1L])))
  expect_identical(s$text[s$item == "own_contribution"],
                   lbl("report.household.text.own_contribution_none"))
  low <- wsh_run(wsh_landlord_scenario(rent = 12000, id = "niedrig"))
  s2 <- attr(vofi_household_view(low), "summary")
  expect_match(s2$text[s2$item == "cashflow_y1"], "zuschie", fixed = TRUE)
  expect_true("cashflow_min" %in% s2$item)
  cmp <- wsh_comparison(list(hoch = res, niedrig = low))
  hv3 <- vofi_household_view(cmp)
  expect_equal(hv3$cashflow_change[hv3$variant == "niedrig"],
               hv3$cashflow[hv3$variant == "niedrig"] - hv3$cashflow[hv3$variant == "hoch"])
  s3 <- attr(hv3, "summary")
  expect_true("cashflow_change_y1" %in% s3$item[s3$variant == "niedrig"])
})

test_that("Verm\u00f6gensamortisation (R-72) und Bandbreite in Worten aus der Simulation", {
  x <- example_result()
  hv <- vofi_household_view(x)
  s <- attr(hv, "summary")
  expect_identical(s$value[s$item == "payback_year"], x$kpis$payback_year)
  expect_identical(s$text[s$item == "payback_year"],
                   lbl("report.household.text.payback", year = 2031L,
                       basis = lbl("report.household.text.basis_method")))
  expect_equal(hv$wealth_diff[nrow(hv)], x$kpis$delta_terminal_value)
  expect_equal(hv$wealth_diff_ex_rv[nrow(hv)], x$kpis$delta_terminal_value_ex_rv)
  # Selbstnutzer-Simulation mit Statistik der Belastung: Memo-07-Muster
  mc <- wsh_mc()
  mc$deterministic <- wsh_run(wsh_self_scenario())
  row <- mc$stats[1L, ]
  row$kpi <- "monthly_burden_avg10"
  row$q10 <- 60
  row$q50 <- 112
  row$q90 <- 170
  mc$stats <- rbind(mc$stats, row)
  s2 <- attr(vofi_household_view(mc), "summary")
  expect_identical(s2$text[s2$item == "range"],
                   lbl("report.household.text.range_burden", median = "110", lo = "60",
                       hi = "170"))
  # entartete Spanne: keine Aussage „zwischen X und X“ (SN-07)
  mc$stats$q10[nrow(mc$stats)] <- 111
  mc$stats$q90[nrow(mc$stats)] <- 113
  s3 <- attr(vofi_household_view(mc), "summary")
  expect_identical(s3$text[s3$item == "range"],
                   lbl("report.household.text.range_flat_burden", median = "110"))
})

test_that("Bestandsprojekt: Amortisation nur gegen\u00fcber einer Referenzvariante (12.3a)", {
  wp <- wsh_run(wsh_self_scenario())
  expect_true(kpi_primary(wp$spec)$existing)
  s <- attr(vofi_household_view(wp), "summary")
  expect_identical(s$text[s$item == "payback_year"],
                   lbl("report.household.text.payback_needs_reference"))
  expect_true(is.na(s$value[s$item == "payback_year"]))
  expect_false(any(grepl(lbl("report.household.text.basis_measures"), s$text, fixed = TRUE)))
  # Vergleich: Variante gegenüber der Referenz, die Referenz selbst ohne Aussage
  gas <- wsh_run(wsh_self_scenario(energy = 4500, capex = -12000, loan = 0, id = "gas"))
  hv <- vofi_household_view(wsh_comparison(list(gas = gas, wp = wp)))
  sc <- attr(hv, "summary")
  w <- hv[hv$variant == "wp", ]
  pb <- sc[sc$variant == "wp" & sc$item == "payback_year", ]
  expect_identical(nrow(pb), 1L)
  if (any(w$paid_back)) {
    expect_identical(pb$value, as.double(w$year[which(w$paid_back)[1L]]))
  } else {
    expect_identical(pb$text, lbl("report.household.text.no_payback", end = wp$grid$end_date,
                                  basis = lbl("report.household.text.basis_ex_rv")))
  }
  expect_false("payback_year" %in% sc$item[sc$variant == "gas"])
  # summary() im Haushaltsmodus übernimmt den Klartext
  expect_true(lbl("report.household.text.payback_needs_reference") %in% summary(wp)$plain)
})

test_that("Bandbreite des Cashflows in Worten ohne Vorzeichen (Memo 07 Paragraf 5.4 Nr. 5)", {
  mc <- wsh_mc()
  mc$deterministic <- wsh_run(wsh_landlord_scenario())
  range_text <- function(q10, q50, q90) {
    m <- mc
    row <- m$stats[1L, ]
    row$kpi <- "monthly_net_cashflow_y1"
    row$q10 <- q10
    row$q50 <- q50
    row$q90 <- q90
    m$stats <- rbind(m$stats, row)
    s <- attr(vofi_household_view(m), "summary")
    s$text[s$item == "range"]
  }
  expect_identical(range_text(-300, -150, 20),
                   lbl("report.household.text.range_mixed_subsidy", median = "150",
                       lo = "300", hi = "20"))
  expect_identical(range_text(-40, 60, 210),
                   lbl("report.household.text.range_mixed_surplus", median = "60",
                       lo = "40", hi = "210"))
  expect_identical(range_text(-320, -180, -42),
                   lbl("report.household.text.range_subsidy", median = "180", lo = "40",
                       hi = "320"))
  expect_identical(range_text(12, 150, 330),
                   lbl("report.household.text.range_surplus", median = "150", lo = "10",
                       hi = "330"))
  expect_false(any(grepl("-", c(range_text(-300, -150, 20), range_text(-320, -180, -42)),
                         fixed = TRUE)))
})

test_that("Snapshots der Sichten (15.6)", {
  skip_if_not(l10n_info()[["UTF-8"]])
  local_reproducible_output(width = 100)
  res <- wsh_run(wsh_tenant_scenario())
  tv <- vofi_tenant_view(res)
  expect_snapshot(print(tv[, c("year", "rent", "levy", "operating", "energy", "warm_rent",
                               "warm_rent_pre", "change_prepost")], digits = 6))
  hv <- vofi_household_view(wsh_run(wsh_self_scenario()))
  expect_snapshot(writeLines(attr(hv, "summary")$text))
})

test_that("WS-H-Testszenarien: building und unit_groups erzeugen keine Zusatzzahlungen", {
  # Expander laufen mit building (01a 3.1, 01b 2.2); die Testszenarien setzen Baujahr,
  # Instandhaltung aus, Nebenkostenpauschale 0 und Restwert zero, damit alle Zahlungen aus den
  # Komponenten des Szenarios stammen (Sollwerte 530/390/1.100/13 % der Haushaltssicht)
  expander_rows <- function(res) {
    rows <- res$ledger$rows
    keys <- rows$key[rows$cash & rows$origin == "expander"]
    stats::setNames(vapply(keys, function(k) sum(abs(res$ledger$values[[k]])), 0), keys)
  }
  self <- wsh_run(wsh_self_scenario())
  rows <- self$ledger$rows
  expect_false("m_maintenance" %in% rows$source_id)
  expect_true("u_main_opex" %in% rows$source_id)
  expect_true(all(expander_rows(self) == 0))
  expect_identical(sum(self$ledger$values[["rv_value__value"]]), 0)
  # Grundsteuer fehlt bewusst: W der selbstgenutzten Gruppe (in wsh_run() verschluckt)
  expect_warning(withCallingHandlers(
    vofi_build(wsh_self_scenario()),
    vofi_warning_library_outdated = function(w) invokeRestart("muffleWarning")
  ), class = "vofi_warning_plausibility", regexp = "building.property_tax", fixed = TRUE)
  tenant <- wsh_run(wsh_tenant_scenario())
  rows <- tenant$ledger$rows
  expect_false("m_maintenance" %in% rows$source_id)
  expect_true(all(expander_rows(tenant) == 0))
  # Restwert nur aus der eigenen Reihe rw (300.000 am Horizont), nicht doppelt
  rv <- rows$key[rows$cash & rows$category == "residual_value"]
  expect_identical(sum(vapply(rv, function(k) sum(tenant$ledger$values[[k]]), 0)), 300000)
})

test_that("Haushaltsbericht S4: Wartung, Kreditrate, Zinsbezug, Bezeichnungen (SN-01, -06, -10, -11)", {
  skip_on_cran()
  local_utf8()
  sc <- vofi_read_scenario(vofi_example("s4_efh_1975_isfp"))
  res <- suppressWarnings(suppressMessages(vofi_run(vofi_build(sc, variant = "v1_isfp_stufen"))))
  # SN-11: Wartung und Messdienst in der Spalte Wartung, nicht unter Energie
  hv <- vofi_household_view(res)
  svc <- -rep_service_sum(rep_core_of(res))
  expect_gt(sum(svc), 0)
  expect_true(all(hv$maintenance[hv$phase == "operation"] > 0))
  # SN-01: Rate nach der tilgungsfreien Zeit je Kredit, Zinsen der Anlaufjahre
  ins <- rep_html_instruments(res)
  i <- which(startsWith(ins$label, "kfw358_2030"))
  expect_identical(ins$rate_year[i], 2033L)
  expect_equal(ins$rate[i], 349, tolerance = 0.01)
  expect_equal(ins$grace_interest[i], 70000 * 0.0253 / 12, tolerance = 1e-6)
  expect_identical(c(ins$grace_from[i], ins$grace_to[i]), c(2030L, 2032L))
  # SN-10: Programmname am Kredit
  expect_identical(ins$label[i], "kfw358_2030 (KfW 358)")
  # SN-06: Bezug auf die Bibliothek als aufgelöster Zinssatz
  path <- paste0("financing.", ins$id[i], ".rate_pa")
  expect_match(rep_html_spec_text(res$spec, path, "pct"), "ref", fixed = TRUE)
  expect_identical(rep_html_spec_text(res$spec, path, "pct", res), "2,53 %")
  # SN-10: Varianten-Labels statt Kennungen
  x <- list(meta = list(variant_labels = c(base = "Basis", v1 = "V1 Stufen")))
  expect_identical(rep_hh_vlabel(x, "v1"), "„V1 Stufen“")
  expect_identical(rep_hh_vlabel(list(), "v1"), "v1")
  rep_label_env$labels <- x$meta$variant_labels
  on.exit(rep_label_env$labels <- NULL, add = TRUE)
  expect_identical(rep_vlabel(c("v1", "zz"), short = TRUE), c("V1 Stufen", "zz"))
  expect_identical(rep_vlabel("v1"), "V1 Stufen (v1)")
  # SN-04: Nachschüsse ohne „zusätzlich“
  calls_txt <- lbl("report.household.text.equity_calls", value = "1")
  expect_false(startsWith(calls_txt, "Zus\u00e4tzlich"))
  expect_match(calls_txt, "Gesamtkosten", fixed = TRUE)
})
