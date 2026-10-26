# Tests für R/tax-flat.R (WS-X; Spec 00 Abschnitte 10.2-10.10, Memo 06 Abschnitte 3, 6.2, 7):
# Typdefinition und Vertragstests, Steuerparameter, Konfiguration, Sperren, AfA (linear,
# degressiv, § 7b), Erhaltungsaufwand (§ 82b), Zuschüsse, anschaffungsnahe HK, Verlustmodi,
# Zahlungszeitpunkt, Zinsen, § 3c, Restwert am Horizont, Verschiebung, Batch-Invarianz und die
# Pflichttests der Schnittstelle 10.10 Nr. 2-6 mit der Engine.

z7 <- function(...) {
  v <- rep(0, 7L)
  x <- c(...)
  v[seq_along(x)] <- x
  v
}

# ---------------------------------------------------------------------------------------------
# Typdefinition, Vertragstests, Steuerparameter
# ---------------------------------------------------------------------------------------------

test_that("Typdefinition: Art tax, Sperren, Eingaben, Vertragstests C1-C4 und T1 (10.2, 5.6)", {
  def <- reg_get("tax", "flat")
  expect_s3_class(def, "vofi_typedef")
  expect_identical(def$kind, "tax")
  expect_true(isTRUE(def$uses_inputs))
  expect_false("selbstnutzer" %in% def$perspectives)
  expect_setequal(def$perspectives, c("wu_kommunal", "wu_genossenschaft", "wu_privat",
                                      "kleinvermieter"))
  expect_setequal(def$blocked_regimes, c("selbstnutzer", "wu_eg_befreit", "wu_gemeinnuetzig"))
  expect_identical(def$example$rate, 0)
  expect_type_contract("flat", "tax")
  expect_identical(reg_source("tax", "flat"), "vofi")
  # Standard bleibt tax_none (D5)
  expect_identical(eng_build_tax(list(project = list(perspective = "kleinvermieter")))$module$name,
                   "none")
  # Labels: Modul, Parameter, Berichtszeilen, Hinweis "keine Steuerberatung"
  expect_match(lbl("types.tax.flat.description"), "keine Steuerberatung", fixed = TRUE)
  expect_match(lbl("types.tax.flat.note"), "keine Steuerberatung", fixed = TRUE)
  for (p in names(def$params)) expect_true(lbl_has(paste0("types.tax.flat.params.", p, ".label")))
  r <- wsx_run(list(rate = 0.3, lag = 0L), list(), make_grid("annual", T = 2L))
  rep_names <- c(names(r$report), names(r$fin$report))
  for (nm in rep_names) expect_true(lbl_has(paste0("types.tax.flat.report.", nm)), info = nm)
})

test_that("Steuerparameter steuern_DE.yaml: Werte, Gültigkeit, Quellen, Kennzeichnung (7.6)", {
  p <- tax_flat_legal()
  expect_true(isTRUE(p$meta$simplified))
  expect_match(p$meta$disclaimer, "keine Steuerberatung", fixed = TRUE)
  expect_false(is.na(as.Date(p$meta$as_of)))
  for (sec in c("income_tax", "capital_income_tax", "corporate_tax", "trade_tax",
                "maintenance_spread", "acquisition_related", "private_sale")) {
    expect_true(utl_is_string(p[[sec]]$source), info = sec)
  }
  expect_equal(p$income_tax$default_marginal_rate, 0.4431)
  expect_equal(p$capital_income_tax$rate * (1 + p$capital_income_tax$solidarity_surcharge),
               0.26375)
  rates <- vapply(p$corporate_tax$periods, function(r) r$rate, double(1))
  expect_equal(rates, c(0.15, 0.14, 0.13, 0.12, 0.11, 0.10))
  expect_identical(p$corporate_tax$periods[[6L]]$valid_from, "2032-01-01")
  expect_null(p$corporate_tax$periods[[6L]]$valid_to)
  lin <- p$depreciation$buildings_linear$periods
  expect_equal(vapply(lin, function(r) r$rate, double(1)), c(0.025, 0.02, 0.03))
  expect_identical(lin[[3L]]$completed_from, "2023-01-01")
  dg <- p$depreciation$degressive_residential
  expect_equal(dg$rate, 0.05)
  expect_identical(c(dg$window_from, dg$window_to), c("2023-10-01", "2029-09-30"))
  s7 <- p$depreciation$special_7b
  expect_equal(c(s7$rate, s7$years, s7$cost_cap_eur_m2, s7$basis_cap_eur_m2),
               c(0.05, 4, 5200, 4000))
  expect_identical(c(s7$window_from, s7$window_to), c("2023-01-01", "2029-09-30"))
  expect_equal(c(p$maintenance_spread$years_min, p$maintenance_spread$years_max), c(2, 5))
  expect_equal(c(p$acquisition_related$share, p$acquisition_related$years), c(0.15, 3))
  expect_equal(p$private_sale$holding_years, 10)
  mm <- vapply(p$trade_tax$min_multiplier, function(r) r$value, double(1))
  expect_equal(mm, c(2.0, 2.8))
})

# ---------------------------------------------------------------------------------------------
# Konfiguration und Sperren
# ---------------------------------------------------------------------------------------------

test_that("Steuersatz: Nutzereingabe, Default privat 44,31 %, Unternehmen KSt-Pfad und GewSt", {
  g <- make_grid("annual", T = 8L)
  r <- wsx_run(list(rate = 0.42, lag = 0L), list(), g)
  expect_identical(r$module$cfg$rate, list(kind = "const", value = 0.42, default = FALSE))
  cap <- e2_capture(reg_get("tax", "flat")$constructor(list(),
                                                      reg_test_spec(g, "kleinvermieter")))
  expect_true(all(c("types.tax.flat.msg.disclaimer", "types.tax.flat.msg.rate_default") %in%
                    cap$messages))
  m <- cap$value
  expect_equal(tax_flat_rate_at(m$cfg$rate, 1L, 2027L), 0.4431)
  # Plausibilität: Grenzsteuersatz über der Spitzenbelastung
  expect_warning(wsx_run(list(rate = 0.6), list(), g), class = "vofi_warning_plausibility")
  co <- wsx_run(list(lag = 0L), list(), g, perspective = "wu_privat")$module$cfg$rate
  at <- function(y) tax_flat_rate_at(co, 1L, y)
  expect_equal(vapply(2026:2033, at, double(1)),
               c(0.15825, 0.15825, 0.1477, 0.13715, 0.1266, 0.11605, 0.1055, 0.1055))
  gw <- wsx_run(list(lag = 0L, trade_tax_multiplier = 4.5), list(), g,
                perspective = "wu_privat")$module$cfg$rate
  expect_equal(tax_flat_rate_at(gw, 1L, 2027L), 0.15825 + 0.035 * 4.5)
  # unter dem Mindesthebesatz: je Jahr Mindesthebesatz (200 % bis 2026, 280 % ab 2027)
  lo <- wsx_run(list(lag = 0L, trade_tax_multiplier = 2), list(), g,
                perspective = "wu_privat")$module$cfg$rate
  expect_equal(tax_flat_rate_at(lo, 1L, 2026L), 0.15825 + 0.07)
  expect_equal(tax_flat_rate_at(lo, 1L, 2027L), 0.15825 + 0.098)
  # Pfad (Basisfall 1 x (T+1)) je Periode
  pth <- wsx_run(list(rate = matrix(seq(0.1, 0.9, by = 0.1), 1L), lag = 0L), list(), g)
  expect_identical(pth$module$cfg$rate$kind, "path")
  expect_equal(tax_flat_rate_at(pth$module$cfg$rate, 3L, 2029L), 0.4)
  expect_error(tax_flat_rate_at(pth$module$cfg$rate, 9L, 2035L), class = "vofi_error_contract")
})

test_that("Abgeltungssatz: 26,375 %, mit Kirchensteuer nach § 32d, ausdrücklicher Satz", {
  g <- make_grid("annual", T = 2L)
  cfg <- function(p) wsx_run(p, list(), g)$module$cfg
  expect_equal(cfg(list(rate = 0.4))$capital_rate, 0.26375)
  expect_equal(cfg(list(rate = 0.4, church_tax_rate = 0.09))$capital_rate,
               0.25 / 1.0225 * 1.145, tolerance = 1e-12)
  expect_equal(cfg(list(rate = 0.4, church_tax_rate = 0.08))$capital_rate,
               0.25 / 1.02 * 1.135, tolerance = 1e-12)
  expect_equal(cfg(list(rate = 0.4, capital_rate = 0.2))$capital_rate, 0.2)
  expect_identical(cfg(list(rate = 0.4))$deposit, "abgeltung")
  expect_identical(wsx_run(list(rate = 0.4), list(), g, perspective = "wu_privat")$module$cfg$deposit,
                   "ergebnis")
  expect_identical(cfg(list(rate = 0.4, deposit_interest = "keine"))$deposit, "keine")
})

test_that("Parameterfehler: unbekannt, Code, Satz, Grenzen, Wertform (vofi_error_input)", {
  g <- make_grid("annual", T = 2L)
  spec <- reg_test_spec(g, "kleinvermieter")
  ctor <- reg_get("tax", "flat")$constructor
  bad <- list(list(rat = 0.3), list(rate = 0.3, loss_mode = "irgendwie"), list(rate = 1.2),
              list(rate = -0.1), list(rate = "hoch"), list(rate = 0.3, lag = 2L),
              list(rate = 0.3, spread_years = 7L), list(rate = 0.3, special_7b = "ja"),
              list(rate = 0.3, holding_start = "kein Datum"),
              list(rate = 0.3, church_tax_rate = 0.5),
              list(rate = list(kind = "ref", path = "market.inflation")))
  for (p in bad) {
    expect_error(suppressMessages(ctor(p, spec)), class = "vofi_error_input",
                 info = utl_collapse(names(p)))
  }
  e <- expect_error(suppressMessages(ctor(list(rat = 0.3), spec)), class = "vofi_error_input")
  expect_match(conditionMessage(e), "rate", fixed = TRUE)
  # Konstantenknoten werden ausgepackt
  ok <- suppressMessages(ctor(list(rate = node_const(0.25), lag = 0L), spec))
  expect_equal(ok$cfg$rate$value, 0.25)
})

test_that("10.10 Nr. 5: Sperre für Selbstnutzer und befreite Rechtsträger (Konstruktor)", {
  g <- make_grid("annual", T = 2L)
  ctor <- reg_get("tax", "flat")$constructor
  sn <- reg_test_spec(g, "selbstnutzer")
  e <- expect_error(ctor(list(rate = 0.3), sn), class = "vofi_error_validation")
  expect_match(conditionMessage(e), "Selbstnutzer", fixed = TRUE)
  expect_s3_class(e$data$report, "vofi_validation")
  for (rg in c("wu_eg_befreit", "wu_gemeinnuetzig", "selbstnutzer")) {
    sp <- reg_test_spec(g, "wu_kommunal", project = list(tax_regime = rg))
    expect_error(ctor(list(rate = 0.3), sp), class = "vofi_error_validation", info = rg)
  }
  # zulässig: steuerpflichtige eG, kommunale Kapitalgesellschaft, privat, Kleinvermieter
  for (x in list(c("wu_genossenschaft", "wu_eg_stpfl"), c("wu_kommunal", "wu_kommunal"),
                 c("wu_privat", "wu_kapges"), c("kleinvermieter", "privat_vermieter"))) {
    sp <- reg_test_spec(g, x[1L], project = list(tax_regime = x[2L]))
    expect_s3_class(suppressMessages(ctor(list(rate = 0.3), sp)), "tax_flat")
  }
})

test_that("10.10 Nr. 5: tax_flat lässt sich für Selbstnutzer nicht aktivieren (vofi_build)", {
  sc <- wsx_scenario(project = list(perspective = "selbstnutzer"))
  e <- expect_error(wsx_build(sc), class = "vofi_error_validation")
  rep <- e$data$report
  expect_true("validation.tax_module_blocked" %in% rep$code[rep$severity == "error"])
  # Genossenschaft: Default-Regime befreit -> gesperrt; steuerpflichtige eG zulässig
  eg <- wsx_scenario(project = list(perspective = "wu_genossenschaft"))
  expect_error(wsx_build(eg), class = "vofi_error_validation")
  eg$project$tax_regime <- "wu_eg_stpfl"
  expect_s3_class(wsx_build(eg)$tax, "tax_flat")
  # kommunal: gemeinnützig gesperrt, sonst zulässig
  ko <- wsx_scenario(project = list(perspective = "wu_kommunal", tax_regime = "wu_gemeinnuetzig"))
  expect_error(wsx_build(ko), class = "vofi_error_validation")
  ko$project$tax_regime <- "wu_kommunal"
  expect_s3_class(wsx_build(ko)$tax, "tax_flat")
})

test_that("Validierung: flat mit Abgeltungsteuer auf dem Konto ist Doppelbesteuerung (10.7)", {
  sc <- wsx_scenario()
  sc$accounts$deposit_withholding_tax_share <- 0.26375
  e <- expect_error(wsx_build(sc), class = "vofi_error_validation")
  expect_true("validation.tax_flat_withholding" %in% e$data$report$code)
})

# ---------------------------------------------------------------------------------------------
# AfA (Memo 06 3.1.2)
# ---------------------------------------------------------------------------------------------

test_that("Lineare AfA: Satz nach Fertigstellung, pro rata ab Monat der Inbetriebnahme", {
  g <- make_grid("annual", T = 6L)
  inv <- function(a) list(wsx_row("inv__cost", "capex_depreciable", z7(-300000),
                                  category = "capex", asset_id = a))
  a <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-04-15"))
  r <- wsx_run(list(rate = 0.4, lag = 0L), inv("b1"), g, assets = list(a))
  expect_equal(r$report$depreciation[1L, ], -c(0, 6750, rep(9000, 5)))
  expect_equal(r$pay[1L, ], -0.4 * c(0, 6750, rep(9000, 5)))
  expect_equal(r$report$book_value[1L, ], 300000 - cumsum(c(0, 6750, rep(9000, 5))))
  # Baujahr des Bestands: 2,5 % vor 1925, 2 % 1925-2022 (nachträgliche HK)
  for (x in list(c(1920, 0.025), c(1975, 0.02), c(2024, 0.03))) {
    ab <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2000-01-01"),
                     original_completion_year = as.integer(x[1L]))
    rb <- wsx_run(list(rate = 0.4, lag = 0L), inv("b1"), g, assets = list(ab))
    expect_equal(rb$report$depreciation[1L, 2L], -300000 * x[2L], info = x[1L])
  }
  # Gutachten-Nutzungsdauer und Satz-Override; Nicht-Wohngebäude im Betriebsvermögen 3 %
  ao <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-01-01"), useful_life_override = 25)
  expect_equal(wsx_run(list(rate = 0.4, lag = 0L), inv("b1"), g,
                       assets = list(ao))$report$depreciation[1L, 2L], -12000)
  expect_equal(wsx_run(list(rate = 0.4, lag = 0L, building_rate = 0.05), inv("b1"), g,
                       assets = list(a))$report$depreciation[1L, 3L], -15000)
  an <- vofi_asset("b1", "gebaeude_nichtwohnen", as.Date("2000-01-01"),
                   original_completion_year = 1990L)
  expect_equal(wsx_run(list(rate = 0.3, lag = 0L), inv("b1"), g, assets = list(an),
                       perspective = "wu_privat")$report$depreciation[1L, 2L], -9000)
  # andere Anlagen linear über die Nutzungsdauer (PV 20 Jahre), Boden ohne AfA
  ap <- vofi_asset("b1_pv", "pv_anlage", as.Date("2027-01-01"))
  expect_equal(wsx_run(list(rate = 0.4, lag = 0L), inv("b1_pv"), g,
                       assets = list(ap))$report$depreciation[1L, 2L], -15000)
  al <- vofi_asset("b1_land", "grund_boden", as.Date("2027-01-01"), land_share = 1)
  rl <- wsx_run(list(rate = 0.4, lag = 0L), inv("b1_land"), g, assets = list(al))
  expect_true(all(rl$report$depreciation == 0))
  expect_equal(rl$state$land, 300000)
})

test_that("Nachträgliche HK erhöhen die Bemessungsgrundlage ab dem Jahr ihrer Entstehung", {
  g <- make_grid("annual", T = 6L)
  a <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-01-01"))
  rows <- list(wsx_row("inv__cost", "capex_depreciable", z7(-200000, 0, 0, -100000),
                       category = "capex", asset_id = "b1"))
  r <- wsx_run(list(rate = 0.4, lag = 0L), rows, g, assets = list(a))
  expect_equal(r$report$depreciation[1L, ], -c(0, 6000, 6000, 9000, 9000, 9000, 9000))
})

test_that("Memo 06 3.1.2: degressiv 5 % + § 7b (20.000/18.000/16.100/14.295; 148.395 EUR)", {
  g <- make_grid("annual", T = 6L)
  a <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-01-01"),
                  construction_start_date = as.Date("2024-05-01"),
                  building_application_date = as.Date("2023-06-01"),
                  efficiency_standard = "eh40", living_area_m2 = 100)
  rows <- list(wsx_row("inv__cost", "capex_depreciable", z7(-400000), category = "capex",
                       asset_id = "b1"))
  r <- wsx_run(list(rate = 0.4431, lag = 0L, special_7b = TRUE), rows, g, assets = list(a))
  afa <- -r$report$depreciation[1L, ]
  sb <- -r$report$special_depreciation[1L, ]
  expect_equal(afa[2:5], c(20000, 18000, 16100, 14295))
  expect_equal(sb, c(0, 20000, 20000, 20000, 20000, 0, 0))
  expect_equal(sum(afa[2:5] + sb[2:5]), 148395)
  # linear 3 % zum Vergleich: 12.000 je Jahr; Steuerstundung in vier Jahren rund 44.500 EUR
  rl <- wsx_run(list(rate = 0.4431, lag = 0L, depreciation_method = "linear"), rows, g,
                assets = list(a))
  expect_equal(-rl$report$depreciation[1L, 2:5], rep(12000, 4))
  stundung <- sum(rl$pay[1L, 2:5]) - sum(r$pay[1L, 2:5])
  expect_equal(stundung, (148395 - 48000) * 0.4431)
  expect_true(abs(stundung - 44500) < 100)
  # degressiv ohne § 7b: 5 % vom Restwert
  rd <- wsx_run(list(rate = 0.4, lag = 0L), rows, g, assets = list(a))
  expect_equal(-rd$report$depreciation[1L, 2:5], 400000 * 0.05 * 0.95^(0:3))
  # linear + § 7b; nach Ablauf AfA vom Restwert (§ 7a Abs. 9): 3 % x 272.000 = 8.160
  rs <- wsx_run(list(rate = 0.4, lag = 0L, special_7b = TRUE, depreciation_method = "linear"),
                rows, g, assets = list(a))
  expect_equal(-rs$report$depreciation[1L, ], c(0, rep(12000, 4), 8160, 8160))
  expect_equal(-rs$report$special_depreciation[1L, ], c(0, rep(20000, 4), 0, 0))
})

test_that("Degressive AfA nur im Fenster des Baubeginns, Warnung bei ausdrücklicher Wahl", {
  g <- make_grid("annual", T = 3L)
  rows <- list(wsx_row("inv__cost", "capex_depreciable", c(-400000, 0, 0, 0),
                       category = "capex", asset_id = "b1"))
  for (d in c("2023-09-30", "2029-10-01")) {
    a <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-01-01"),
                    construction_start_date = as.Date(d))
    r <- wsx_run(list(rate = 0.4, lag = 0L), rows, g, assets = list(a))
    expect_equal(r$report$depreciation[1L, 2L], -12000, info = d)
    expect_warning(wsx_run(list(rate = 0.4, lag = 0L, depreciation_method = "degressiv"), rows,
                           g, assets = list(a)), class = "vofi_warning_plausibility")
  }
  a <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-01-01"),
                  construction_start_date = as.Date("2023-10-01"))
  expect_equal(wsx_run(list(rate = 0.4, lag = 0L), rows, g,
                       assets = list(a))$report$depreciation[1L, 2L], -20000)
})

test_that("§ 7b: Baukostenobergrenze 5.200 und Basis 4.000 EUR/m² je Lauf, Prüfhinweise", {
  g <- make_grid("annual", T = 5L)
  a <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-01-01"),
                  building_application_date = as.Date("2024-01-01"),
                  efficiency_standard = "eh40", living_area_m2 = 100)
  cost <- rbind(c(-500000, rep(0, 5)), c(-600000, rep(0, 5)), c(-300000, rep(0, 5)))
  rows <- list(wsx_row("inv__cost", "capex_depreciable", cost, category = "capex",
                       asset_id = "b1"))
  r <- wsx_run(list(rate = 0.4, lag = 0L, special_7b = TRUE), rows, g, n = 3L, assets = list(a))
  expect_equal(-r$report$special_depreciation[, 2L], c(20000, 0, 15000))
  expect_equal(-r$report$special_depreciation[1L, ], c(0, rep(20000, 4), 0))
  # Voraussetzungen verletzt: kein EH 40, Bauantrag außerhalb, Bestand -> Warnung, keine 7b
  bad <- list(vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-01-01"),
                         efficiency_standard = "eh55", living_area_m2 = 100),
              vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-01-01"),
                         building_application_date = as.Date("2022-12-31")),
              vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-01-01"),
                         original_completion_year = 1990L))
  for (b in bad) {
    expect_warning(rb <- wsx_run(list(rate = 0.4, lag = 0L, special_7b = TRUE), rows, g, n = 3L,
                                 assets = list(b)), class = "vofi_warning_plausibility")
    expect_true(all(rb$report$special_depreciation == 0))
  }
  # nicht prüfbar (Standard, Bauantrag, Fläche fehlen): Warnungen, als erfüllt angenommen
  u <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-01-01"))
  w <- character(0)
  ru <- withCallingHandlers(
    wsx_run(list(rate = 0.4, lag = 0L, special_7b = TRUE), rows, g, n = 3L, assets = list(u)),
    warning = function(cnd) {
      w <<- c(w, cnd$key)
      invokeRestart("muffleWarning")
    })
  expect_identical(unique(w), "types.tax.flat.msg.s7b_unchecked")
  expect_length(w, 3L)
  expect_equal(-ru$report$special_depreciation[, 2L], c(25000, 30000, 15000))
})

test_that("10.10 Nr. 4: AfA-Summe über die Nutzungsdauer = Bemessungsgrundlage (Modul)", {
  g <- make_grid("annual", T = 6L)
  a <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-07-01"))
  base <- rbind(c(-100000, rep(0, 6)), c(-250000, rep(0, 6)))
  rows <- list(wsx_row("inv__cost", "capex_depreciable", base, category = "capex",
                       asset_id = "b1"))
  r <- wsx_run(list(rate = 0.4, lag = 0L, building_rate = 0.2), rows, g, n = 2L,
               assets = list(a))
  expect_equal(-rowSums(r$report$depreciation), c(100000, 250000))
  expect_equal(-r$report$depreciation[1L, ], c(0, 10000, rep(20000, 4), 10000))
  expect_equal(r$report$book_value[, 7L], c(0, 0))
  # degressiv mit Wechsel nach 10 Jahren: Restwert x 3 % bis zur vollen Absetzung
  g50 <- make_grid("annual", T = 50L)
  ad <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-01-01"),
                   construction_start_date = as.Date("2025-01-01"))
  rd <- wsx_run(list(rate = 0.4, lag = 0L, degressive_switch_year = 10L),
                list(wsx_row("inv__cost", "capex_depreciable", c(-100000, rep(0, 50)),
                             category = "capex", asset_id = "b1")), g50, assets = list(ad))
  afa <- -rd$report$depreciation[1L, ]
  expect_equal(afa[2:11], 5000 * 0.95^(0:9))
  expect_equal(afa[12], 0.03 * 100000 * 0.95^10)
  expect_equal(sum(afa), 100000)
  expect_equal(rd$report$book_value[1L, 51L], 0)
})

# ---------------------------------------------------------------------------------------------
# Erhaltungsaufwand, Zuschüsse, anschaffungsnahe HK
# ---------------------------------------------------------------------------------------------

test_that("Erhaltungsaufwand: sofort, Verteilung § 82b (privat), Unternehmen sofort", {
  g <- make_grid("annual", T = 6L)
  rows <- list(wsx_row("m__cost", "capex_expensable", z7(0, -50000), category = "capex",
                       measure_id = "m1", extra = list(spread_years = 5L)),
               wsx_row("n__cost", "capex_expensable", z7(0, 0, -30000), category = "capex",
                       measure_id = "m2"))
  r <- wsx_run(list(rate = 0.4, lag = 0L), rows, g)
  expect_equal(r$report$maintenance[1L, ], -c(0, 10000, 40000, 10000, 10000, 10000, 0))
  expect_equal(r$pay[1L, ], 0.4 * r$report$maintenance[1L, ])
  # Default der Verteilung für Zeilen ohne eigene Angabe
  r3 <- wsx_run(list(rate = 0.4, lag = 0L, spread_years = 3L), rows, g)
  expect_equal(r3$report$maintenance[1L, ], -c(0, 10000, 20000, 20000, 20000, 10000, 0))
  # Unternehmen: § 82b nur im Privatvermögen
  cap <- e2_capture(reg_get("tax", "flat")$constructor(list(rate = 0.3, spread_years = 3L),
                                                      reg_test_spec(g, "wu_privat")))
  expect_true("types.tax.flat.msg.spread_private_only" %in% cap$messages)
  rc <- wsx_run(list(rate = 0.3, lag = 0L, spread_years = 3L), rows, g, perspective = "wu_privat")
  expect_equal(rc$report$maintenance[1L, ], -c(0, 50000, 30000, 0, 0, 0, 0))
  # offene Raten am Horizont: Abzug nur bei Veräußerung (Restwertbesteuerung)
  late <- list(wsx_row("m__cost", "capex_expensable", z7(0, 0, 0, 0, 0, 0, -50000),
                       category = "capex", extra = list(spread_years = 5L)))
  rl <- wsx_run(list(rate = 0.4, lag = 0L), late, g)
  expect_equal(sum(rl$report$maintenance), -10000)
  expect_equal(rl$fin$payment_T, 0)
})

test_that("Zuschüsse: Minderung der Bemessungsgrundlage bzw. Einnahme (R 21.5 EStR)", {
  g <- make_grid("annual", T = 4L)
  a <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-01-01"))
  ms <- list(vofi_measure("m1", "aufzug", classification = "herstellung", asset_id = "b1"),
             vofi_measure("m2", "fenster", classification = "erhaltung", asset_id = "b1"))
  rows <- list(
    wsx_row("m1__cost", "capex_depreciable", c(-100000, 0, 0, 0, 0), category = "capex",
            asset_id = "b1", measure_id = "m1"),
    wsx_row("g1__grant", "subsidy_investment", c(0, 20000, 0, 0, 0), category = "grant",
            measure_id = "m1", section = "grants"),
    wsx_row("m2__cost", "capex_expensable", c(0, -30000, 0, 0, 0), category = "capex",
            asset_id = "b1", measure_id = "m2"),
    wsx_row("g2__grant", "subsidy_investment", c(0, 0, 10000, 0, 0), category = "grant",
            measure_id = "m2", section = "grants"),
    wsx_row("loan_k_repayment_grant", "subsidy_repayment_grant", c(0, 0, 0, 5000, 0),
            category = "repayment_grant", measure_id = "m1", source = "inst", section = "loans")
  )
  r <- wsx_run(list(rate = 0.4, lag = 0L), rows, g, assets = list(a), measures = ms)
  expect_equal(-r$report$depreciation[1L, ], c(0, 2400, 2400, 2250, 2250))
  expect_equal(r$report$book_value[1L, ], c(100000, 77600, 75200, 67950, 65700))
  expect_equal(r$report$income[1L, ], c(0, 0, 10000, 0, 0))
  expect_equal(r$report$maintenance[1L, ], c(0, -30000, 0, 0, 0))
  # Wahl einnahme: alle Investitionszuschüsse sind Einnahmen im Zuflussjahr
  re <- wsx_run(list(rate = 0.4, lag = 0L, subsidy_treatment = "einnahme"), rows, g,
                assets = list(a), measures = ms)
  expect_equal(-re$report$depreciation[1L, ], c(0, 3000, 3000, 3000, 3000))
  expect_equal(re$report$income[1L, ], c(0, 20000, 10000, 5000, 0))
  # Zuschuss über dem Restbuchwert: Überhang ist Einnahme
  big <- rows[1:2]
  big[[2L]]$values <- c(0, 0, 0, 0, 150000)
  rb <- wsx_run(list(rate = 0.4, lag = 0L), big, g, assets = list(a), measures = ms)
  expect_equal(rb$report$book_value[1L, 5L], 0)
  expect_equal(rb$report$income[1L, 5L], 150000 - (100000 - 3 * 3000))
})

test_that("Anschaffungsnahe HK: 15-%-Grenze netto je Lauf, Umgliederung der Maßnahme auto", {
  g <- make_grid("annual", T = 6L)
  b1 <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-01-01"),
                   acquisition_date = as.Date("2027-01-01"), original_completion_year = 1960L)
  land <- vofi_asset("b1_land", "grund_boden", as.Date("2027-01-01"), land_share = 1)
  ms <- list(vofi_measure("kauf", "erwerb_objekt", classification = "herstellung",
                          asset_id = "b1"),
             vofi_measure("san", "daemmung_fassade", classification = "auto", asset_id = "b1"))
  san <- rbind(z7(0, -35700, -29750), 0.5 * z7(0, -35700, -29750))
  rows <- list(
    wsx_row("kauf__price_building", "capex_depreciable", z7(-300000), category = "capex",
            asset_id = "b1", measure_id = "kauf"),
    wsx_row("kauf__price_land", "capex_land", z7(-100000), category = "land",
            asset_id = "b1_land", measure_id = "kauf"),
    wsx_row("acq__building", "acquisition_ancillary", z7(-20000), category = "acquisition_cost",
            asset_id = "b1", measure_id = "kauf"),
    wsx_row("san__cost", "capex_depreciable", san, category = "capex", asset_id = "b1",
            measure_id = "san")
  )
  r <- wsx_run(list(rate = 0.4, lag = 0L), rows, g, n = 2L, assets = list(b1, land),
               measures = ms)
  # Lauf 1: netto 30.000 + 25.000 = 55.000 > 15 % x 320.000 = 48.000 -> Umgliederung in t = 2
  expect_equal(r$report$acq_test_limit[1L, ], rep(48000, 7))
  expect_equal(r$report$acq_test_costs[, 3L], c(55000, 27500))
  expect_equal(r$report$maintenance[1L, ], z7(0, -35700))
  expect_equal(r$report$reclassification[1L, ], z7(0, 0, 35700))
  expect_equal(r$report$acquisition_related[1L, ], z7(0, 0, 65450))
  expect_equal(-r$report$depreciation[1L, ], c(0, 6400, rep(0.02 * 385450, 5)))
  expect_equal(r$report$taxable_income[1L, 2:3], c(-42100, 35700 - 7709))
  # Lauf 2: unter der Grenze -> Erhaltung bleibt sofort abziehbar
  expect_equal(r$report$maintenance[2L, ], z7(0, -17850, -14875))
  expect_true(all(r$report$reclassification[2L, ] == 0))
  expect_equal(-r$report$depreciation[2L, ], c(0, rep(6400, 6)))
  expect_equal(r$state$land, c(100000, 100000))
  # nach dem Prüfzeitraum (> 3 Jahre): Maßnahme auto wie Zeile (Herstellungskosten)
  late <- rows
  late[[4L]]$values <- z7(0, 0, 0, 0, -59500)
  rl <- wsx_run(list(rate = 0.4, lag = 0L), late, g, assets = list(b1, land), measures = ms)
  expect_true(all(rl$report$maintenance == 0))
  expect_equal(-rl$report$depreciation[1L, 6L], 0.02 * (320000 + 59500))
})

test_that("Anschaffungsnahe HK: Erhaltung mit Prüfung (Warnung) bzw. Umgliederung mit Raten", {
  g <- make_grid("annual", T = 6L)
  b1 <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-01-01"),
                   acquisition_date = as.Date("2027-01-01"), original_completion_year = 1960L)
  ms <- list(vofi_measure("kauf", "erwerb_objekt", classification = "herstellung",
                          asset_id = "b1"),
             vofi_measure("dach", "daemmung_dach_steil", classification = "erhaltung",
                          asset_id = "b1", completion_date = as.Date("2028-06-01")))
  rows <- list(
    wsx_row("kauf__price_building", "capex_depreciable", z7(-300000), category = "capex",
            asset_id = "b1", measure_id = "kauf"),
    wsx_row("dach__cost", "capex_expensable", z7(0, -23800, -47600), category = "capex",
            asset_id = "b1", measure_id = "dach", extra = list(spread_years = 2L))
  )
  # Prüfung: Hinweis beim Bau, Warnung im Lauf (einmal je Modell), keine Umgliederung
  w <- character(0)
  r <- withCallingHandlers(
    wsx_run(list(rate = 0.4, lag = 0L), rows, g, assets = list(b1), measures = ms),
    warning = function(cnd) {
      w <<- c(w, cnd$key)
      invokeRestart("muffleWarning")
    })
  expect_true(all(c("types.tax.flat.msg.acq_hint", "types.tax.flat.msg.acq_exceeded") %in% w))
  expect_equal(r$report$maintenance[1L, ], -c(0, 11900, 35700, 23800, 0, 0, 0))
  expect_true(all(r$report$reclassification == 0))
  expect_warning(tax_flat_finalize_warnings(r$module, r$state, r$module$cfg), NA)
  # Umgliederung: vorläufige Abzüge (11.900 + 11.900) zurück, offene Raten aktiviert
  ru <- wsx_run(list(rate = 0.4, lag = 0L, acquisition_related = "umgliederung"), rows, g,
                assets = list(b1), measures = ms)
  expect_equal(ru$report$maintenance[1L, ], -c(0, 11900, 11900, 0, 0, 0, 0))
  expect_equal(ru$report$reclassification[1L, ], z7(0, 0, 23800))
  expect_equal(ru$report$acquisition_related[1L, ], z7(0, 0, 71400))
  expect_equal(ru$report$book_value[1L, 3L], 300000 + 71400 - 6000 - 0.02 * 371400)
})

# ---------------------------------------------------------------------------------------------
# Verlust, Zahlungszeitpunkt, Zinsen, § 3c, Restwert, Verschiebung
# ---------------------------------------------------------------------------------------------

test_that("Verlustmodus: sofort (Erstattung), vortrag, Deckel durch übriges Einkommen", {
  g <- make_grid("annual", T = 6L)
  rows <- list(wsx_row("z__rent", "income_rental", c(0, rep(10000, 6)), category = "rent"),
               wsx_row("z__cost", "expense_deductible", z7(0, -30000), category = "other_cost"))
  r <- wsx_run(list(rate = 0.3, lag = 0L), rows, g)
  expect_equal(r$pay[1L, ], c(0, -6000, rep(3000, 5)))
  expect_true(all(r$report$loss_carryforward == 0))
  rv <- wsx_run(list(rate = 0.3, lag = 0L, loss_mode = "vortrag"), rows, g)
  expect_equal(rv$pay[1L, ], c(0, 0, 0, 0, 3000, 3000, 3000))
  expect_equal(rv$report$loss_carryforward[1L, ], c(0, 20000, 10000, 0, 0, 0, 0))
  rc <- wsx_run(list(rate = 0.3, lag = 0L, other_income_eur_pa = 5000), rows, g)
  expect_equal(rc$pay[1L, ], c(0, -1500, -1500, rep(3000, 4)))
  expect_equal(rc$report$loss_carryforward[1L, ], c(0, 15000, 0, 0, 0, 0, 0))
  # Summe über den Horizont gleich, nur der Zeitpunkt unterscheidet sich
  expect_equal(sum(r$pay), sum(rv$pay))
  expect_equal(sum(r$pay), sum(rc$pay))
  # verbleibender Vortrag am Horizont: verfall (0) bzw. satz (Forderung s x Vortrag)
  loss <- list(wsx_row("z__cost", "expense_deductible", z7(0, -30000), category = "other_cost"))
  expect_equal(wsx_run(list(rate = 0.3, lag = 0L, loss_mode = "vortrag"), loss,
                       g)$fin$payment_T, 0)
  fs <- wsx_run(list(rate = 0.3, lag = 0L, loss_mode = "vortrag", remaining_loss = "satz"), loss,
                g)$fin
  expect_equal(fs$payment_T, -9000)
  expect_equal(fs$report$terminal_loss_value, 9000)
})

test_that("Zahlungszeitpunkt: lag 1 zahlt im Folgejahr, am Horizont offene Steuer (7.11)", {
  g <- make_grid("annual", T = 6L)
  rows <- list(wsx_row("z__rent", "income_rental", c(1000, rep(10000, 6)), category = "rent"))
  r0 <- wsx_run(list(rate = 0.3, lag = 0L), rows, g)
  r1 <- wsx_run(list(rate = 0.3, lag = 1L), rows, g)
  expect_equal(r0$pay[1L, ], c(300, rep(3000, 6)))
  # t = 0 und t = 1 bilden das Veranlagungsjahr 2027 (Zahlung 2028)
  expect_equal(r1$pay[1L, ], c(0, 0, 3300, 3000, 3000, 3000, 3000))
  expect_equal(r1$fin$payment_T, 3000)
  expect_equal(r1$fin$report$terminal_open_tax, 3000)
  expect_equal(sum(r1$pay) + r1$fin$payment_T, sum(r0$pay))
  expect_equal(r1$report$tax_assessed[1L, ], r0$pay[1L, ])
  # Default lag 1 (Memo 06 6.2)
  expect_identical(wsx_run(list(rate = 0.3), rows, g)$module$cfg$lag, 1L)
})

test_that("Veranlagungsjahr bei unterjährigen Perioden: Vortrag und lag 1 je Kalenderjahr", {
  g <- make_grid("mixed", T = 6L)
  n_t <- g$T + 1L
  v <- numeric(n_t)
  v[3L] <- -6000
  v[8L] <- 9000
  v[n_t] <- 10000
  rows <- list(wsx_row("z__x", "income_other_taxable", v, category = "other_income"))
  rv <- wsx_run(list(rate = 0.5, lag = 0L, loss_mode = "vortrag"), rows, g)
  # 2027 (monatliche Bauphase + Stub): -6.000 + 9.000 = 3.000 je Veranlagungsjahr
  expect_equal(sum(rv$pay[1L, g$year == 2027L]), 1500)
  expect_equal(rv$pay[1L, n_t], 5000)
  r1 <- wsx_run(list(rate = 0.5, lag = 1L), rows, g)
  first2028 <- which(g$year == 2028L)[1L]
  expect_equal(r1$pay[1L, first2028], 1500)
  expect_equal(sum(r1$pay[1L, -first2028]), 0)
  expect_equal(r1$fin$payment_T, 5000)
})

test_that("Zinsen: Soll, Gebühren, Kontokorrent, Disagio abziehbar; Habenzinsen nach Modus", {
  g <- make_grid("annual", T = 2L)
  int <- list(exo_soll = c(0, 5000, 4000), exo_fees = c(0, 200, 0), endo_soll = c(0, 300, 100),
              endo_haben = c(0, 1000, 1000))
  rows <- list(wsx_row("loan_k_disagio", "interest_expense", c(0, -1000, 0), category = "disagio",
                       source = "inst", section = "loans"),
               wsx_row("loan_k_interest", "interest_expense", c(0, -5000, -4000),
                       category = "interest", source = "inst", section = "loans"))
  r <- wsx_run(list(rate = 0.4, lag = 0L), rows, g, interest = int)
  expect_equal(r$report$interest_expense[1L, ], -c(0, 6500, 4100))
  # privat: Habenzinsen getrennt mit Abgeltungssatz, ohne Verrechnung mit dem Verlust
  expect_equal(r$report$capital_income_tax[1L, ], c(0, 263.75, 263.75))
  expect_equal(r$pay[1L, ], c(0, -0.4 * 6500 + 263.75, -0.4 * 4100 + 263.75))
  ra <- wsx_run(list(rate = 0.4, lag = 0L, saver_allowance_eur_pa = 600), rows, g, interest = int)
  expect_equal(ra$report$capital_income_tax[1L, ], c(0, 105.5, 105.5))
  # Unternehmen: Habenzinsen im Ergebnis
  rc <- wsx_run(list(rate = 0.3, lag = 0L), rows, g, interest = int, perspective = "wu_privat")
  expect_equal(rc$report$interest_income[1L, ], c(0, 1000, 1000))
  expect_true(all(rc$report$capital_income_tax == 0))
  expect_equal(rc$pay[1L, ], 0.3 * c(0, 1000 - 6500, 1000 - 4100))
  rk <- wsx_run(list(rate = 0.3, lag = 0L, deposit_interest = "keine"), rows, g, interest = int)
  expect_true(all(rk$report$capital_income_tax == 0) && all(rk$report$interest_income == 0))
})

test_that("§ 3c: Kosten einer Maßnahme mit nur steuerfreien Erlösen (PV) nicht abziehbar", {
  g <- make_grid("annual", T = 2L)
  pv <- vofi_asset("b1_pv", "pv_anlage", as.Date("2027-01-01"))
  rows <- list(
    wsx_row("pv__feed_in", "income_tax_exempt", c(0, 5000, 5000), category = "energy_income",
            measure_id = "pv"),
    wsx_row("pv__opex", "expense_deductible", c(0, -500, -500), category = "operating_cost",
            measure_id = "pv"),
    wsx_row("pvc__cost", "capex_depreciable", c(-20000, 0, 0), category = "capex",
            measure_id = "pv", asset_id = "b1_pv"))
  r <- wsx_run(list(rate = 0.4, lag = 0L), rows, g, assets = list(pv))
  expect_true(all(r$pay == 0) && all(r$report$taxable_income == 0))
  # steuerpflichtige PV (internal_sale): Kosten abziehbar, AfA 20 Jahre
  rows[[1L]]$tax_category <- "income_other_taxable"
  rt <- wsx_run(list(rate = 0.4, lag = 0L), rows, g, assets = list(pv))
  expect_equal(rt$report$taxable_income[1L, ], c(0, 3500, 3500))
})

test_that("Restwert am Horizont: Unternehmen stets, privat innerhalb der Frist des § 23", {
  g <- make_grid("annual", T = 6L)
  rows <- list(
    wsx_row("inv__cost", "capex_depreciable", z7(-100000), category = "capex", asset_id = "geb"),
    wsx_row("land__cost", "capex_land", z7(-50000), category = "land"),
    wsx_row("rv__value", "disposal_proceeds", z7(0, 0, 0, 0, 0, 0, 200000),
            category = "residual_value"))
  p <- list(rate = 0.3, lag = 0L, building_rate = 0.1)
  rc <- wsx_run(p, rows, g, rv = 200000, perspective = "wu_privat")
  expect_equal(rc$fin$report$terminal_gain, 200000 - 40000 - 50000)
  expect_equal(rc$fin$payment_T, 0.3 * 110000)
  # Restwert unter Buchwert: Erstattung bei Unternehmen (sofort), privat kein Verlust
  rl <- wsx_run(p, rows, g, rv = 60000, perspective = "wu_privat")
  expect_equal(rl$fin$payment_T, -0.3 * 30000)
  expect_equal(wsx_run(p, rows, g, rv = 60000)$fin$payment_T, 0)
  # privat: Frist ab Stichtag (6 Jahre) -> steuerpflichtig; ab 2015 -> steuerfrei
  expect_equal(wsx_run(p, rows, g, rv = 200000)$fin$payment_T, 33000)
  expect_equal(wsx_run(c(p, holding_start = "2015-01-01"), rows, g, rv = 200000)$fin$payment_T,
               0)
  old <- vofi_asset("geb", "gebaeude_wohnen", as.Date("1990-01-01"))
  expect_equal(wsx_run(p, rows, g, rv = 200000, assets = list(old))$fin$payment_T, 0)
  # ausdrücklich: nein bzw. ja; Restwertmethode zero
  expect_equal(wsx_run(c(p, residual_value_tax = "nein"), rows, g, rv = 200000,
                       perspective = "wu_privat")$fin$payment_T, 0)
  expect_equal(wsx_run(c(p, residual_value_tax = "ja", holding_start = "2015-01-01"), rows, g,
                       rv = 200000)$fin$payment_T, 33000)
  expect_equal(wsx_run(p, rows, g, rv = 200000, rv_method = "zero",
                       perspective = "wu_privat")$fin$payment_T, 0)
  # Restbuchwert des Bestands und Verlustvortrag mindern den Gewinn
  expect_equal(wsx_run(c(p, existing_book_value_eur = 10000), rows, g, rv = 200000,
                       perspective = "wu_privat")$fin$payment_T, 0.3 * 100000)
  lv <- c(rows, list(wsx_row("z__cost", "expense_deductible", z7(0, -30000),
                             category = "other_cost")))
  rv <- wsx_run(c(p, loss_mode = "vortrag"), lv, g, rv = 200000, perspective = "wu_privat")
  # Vortrag am Horizont: 30.000 + 6 x 10.000 AfA = 90.000 mindert den Gewinn von 110.000
  expect_equal(rv$fin$report$terminal_gain_tax, 0.3 * (110000 - 90000))
  # Bestandsprojekt eines Unternehmens ohne Restbuchwert des Bestands: Warnung
  expect_warning(wsx_run(p, rows, g, rv = 200000, perspective = "wu_privat",
                         project = list(project_type = "sanierung_eh")),
                 class = "vofi_warning_plausibility")
  # ohne Restwertzeile (z. B. Unterlassungsalternative) keine Besteuerung
  expect_equal(wsx_run(c(p, existing_book_value_eur = 10000), rows[1:2], g, rv = 0,
                       perspective = "wu_privat")$fin$payment_T, 0)
})

test_that("Vokabular tax_category: jede Kategorie zugeordnet, tax_credit ignoriert (10.8, 10.9)", {
  g <- make_grid("annual", T = 2L)
  codes <- vocab_codes("tax_categories")
  taxable <- c("income_rental", "income_other_taxable", "subsidy_operating",
               "expense_deductible", "interest_expense", "capex_expensable", "subsidy_investment",
               "subsidy_repayment_grant")
  depreciable <- c("capex_depreciable", "acquisition_ancillary")
  neutral <- c("income_tax_exempt", "imputed_benefit", "passthrough", "expense_nondeductible",
               "principal", "equity", "disposal_proceeds", "tax_credit", "tax_payment",
               "not_applicable", "capex_land", "interest_income")
  expect_setequal(codes, c(taxable, depreciable, neutral))
  for (tc in codes) {
    r <- wsx_run(list(rate = 0.5, lag = 0L, deposit_interest = "keine"),
                 list(wsx_row("x__v", tc, c(0, -1000, 0))), g)
    e <- r$report$taxable_income[1L, 2L]
    if (tc %in% taxable) {
      expect_equal(abs(e), 1000, info = tc)
    } else if (tc %in% depreciable) {
      # Bemessungsgrundlage einer nicht registrierten Anlage, lineare AfA 3 % im Zugangsjahr
      expect_equal(e, -30, info = tc)
    } else {
      expect_equal(e, 0, info = tc)
    }
  }
  # Habenzinsen aus Zeilen (interest_income) nach Modus: Ergebnis bzw. Abgeltung
  ii <- list(wsx_row("x__v", "interest_income", c(0, 1000, 0)))
  expect_equal(wsx_run(list(rate = 0.5, lag = 0L, deposit_interest = "ergebnis"), ii,
                       g)$report$taxable_income[1L, 2L], 1000)
  expect_equal(wsx_run(list(rate = 0.5, lag = 0L), ii, g)$report$capital_income_tax[1L, 2L],
               263.75)
  # Mischnutzung: use_share_rented gewichtet Einnahmen und Aufwand
  ms <- list(wsx_row("x__v", "income_rental", c(0, 1000, 0), extra = list(use_share_rented = 0.6)))
  expect_equal(wsx_run(list(rate = 0.5, lag = 0L), ms, g)$report$taxable_income[1L, 2L], 600)
})

test_that("Verschiebung der steuerlichen Erfassung (tax_period, approval_date)", {
  g <- make_grid("annual", T = 4L)
  rows <- list(
    wsx_row("a__x", "income_other_taxable", c(0, 1000, 0, 0, 0), category = "other_income",
            extra = list(tax_period = 3L)),
    wsx_row("b__x", "income_other_taxable", c(0, 2000, 0, 0, 0), category = "other_income",
            extra = list(approval_date = as.Date("2029-06-01"))),
    wsx_row("c__x", "income_other_taxable", c(0, 0, 0, 0, 4000), category = "other_income",
            extra = list(tax_period = 2L)))
  r <- wsx_run(list(rate = 0.5, lag = 0L), rows, g)
  # a: erfasst in t = 3; b: in der Periode des Bewilligungsdatums (2029, t = 3); c: tax_period
  # vor der Zahlung -> erfasst bei Zahlung (keine Rückwirkung)
  expect_equal(r$report$income[1L, ], c(0, 0, 0, 3000, 4000))
  expect_equal(r$pay[1L, ], 0.5 * c(0, 0, 0, 3000, 4000))
})

test_that("Batch-Invarianz: Lauf i im Batch identisch zum Einzellauf (2.8, 15.5)", {
  g <- make_grid("mixed", T = 6L)
  n_t <- g$T + 1L
  set <- function(k) {
    f <- c(0.8, 1, 1.3, 2)[k]
    inv <- numeric(n_t)
    inv[2:5] <- -100000 * f
    rent <- c(rep(0, 10), rep(20000 * f, n_t - 10))
    list(wsx_row("inv__cost", "capex_depreciable", inv, category = "capex", asset_id = "b1"),
         wsx_row("san__cost", "capex_depreciable", c(0, 0, -40000 * f, rep(0, n_t - 3)),
                 category = "capex", asset_id = "b1", measure_id = "san"),
         wsx_row("z__rent", "income_rental", rent, category = "rent"),
         wsx_row("e__cost", "capex_expensable", c(0, 0, 0, -30000 * f, rep(0, n_t - 4)),
                 category = "capex", extra = list(spread_years = 3L)))
  }
  a <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-10-01"),
                  construction_start_date = as.Date("2027-01-01"),
                  acquisition_date = as.Date("2027-01-01"),
                  efficiency_standard = "eh40", living_area_m2 = 50)
  ms <- list(vofi_measure("san", "fenster", classification = "auto", asset_id = "b1"))
  p <- list(rate = 0.42, lag = 1L, loss_mode = "vortrag", special_7b = TRUE)
  int <- list(endo_soll = c(0, rep(500, n_t - 1)), endo_haben = c(0, rep(100, n_t - 1)))
  rows4 <- lapply(seq_along(set(1)), function(i) {
    r <- set(1)[[i]]
    r$values <- do.call(rbind, lapply(1:4, function(k) set(k)[[i]]$values))
    r
  })
  batch <- suppressWarnings(wsx_run(p, rows4, g, n = 4L, assets = list(a), measures = ms,
                                    interest = int))
  for (k in 1:4) {
    one <- suppressWarnings(wsx_run(p, set(k), g, assets = list(a), measures = ms,
                                    interest = int))
    expect_identical(batch$pay[k, , drop = FALSE], one$pay)
    expect_identical(batch$fin$payment_T[k], one$fin$payment_T)
    for (nm in names(one$report)) {
      expect_identical(batch$report[[nm]][k, , drop = FALSE], one$report[[nm]], info = nm)
    }
  }
  expect_false(isTRUE(all.equal(batch$report$taxable_income[1L, ],
                                batch$report$taxable_income[4L, ])))
})

test_that("Ohne Eingaben und mit Nullsatz: keine Steuer (T1), Zustand ohne Zufall (F8)", {
  g <- make_grid("annual", T = 3L)
  seed <- if (exists(".Random.seed", globalenv())) get(".Random.seed", globalenv()) else NULL
  r <- wsx_run(list(rate = 0, capital_rate = 0, lag = 0L),
               list(wsx_row("z__rent", "income_rental", c(0, 1, 2, 3), category = "rent")), g,
               interest = list(endo_haben = c(0, 10, 10, 10)), n = 2L)
  expect_true(all(r$pay == 0))
  expect_identical(r$fin$payment_T, c(0, 0))
  seed2 <- if (exists(".Random.seed", globalenv())) get(".Random.seed", globalenv()) else NULL
  expect_identical(seed, seed2)
  # finalize ohne Perioden (leerer Zustand)
  m <- r$module
  st <- tax_init(m, m$params, list(), list(), 2L)
  expect_identical(tax_finalize(m, 3L, st, list(residual_value = c(0, 0)), m$params)$payment_T,
                   c(0, 0))
  # abweichende Parameter beim Aufruf der Methoden
  st2 <- tax_init(m, list(rate = 0.5, lag = 0L), list(), list(), 1L)
  expect_equal(st2$cfg$rate$value, 0.5)
})

# ---------------------------------------------------------------------------------------------
# Pflichttests der Schnittstelle mit der Engine (10.10 Nr. 2-4, 6)
# ---------------------------------------------------------------------------------------------

test_that("10.10 Nr. 2: tax_flat mit s = 0 ist identisch mit dem Vor-Steuer-VoFi", {
  sc0 <- wsx_scenario(params = list(rate = 0, capital_rate = 0, lag = 0L, building_rate = 0.25))
  res0 <- vofi_run(wsx_build(sc0))
  sc_none <- sc0
  sc_none$tax <- NULL
  ref <- vofi_run(wsx_build(sc_none))
  expect_identical(res0$kpis, ref$kpis)
  keys <- ref$ledger$rows$key
  expect_identical(res0$ledger$values[keys], ref$ledger$values[keys])
  expect_identical(res0$opportunity$EW, ref$opportunity$EW)
  expect_true(all(res0$ledger$values$tax == 0))
  expect_true("tax_report_taxable_income" %in% res0$ledger$rows$key)
  rows <- res0$ledger$rows[startsWith(res0$ledger$rows$key, "tax_report_"), , drop = FALSE]
  expect_true(all(rows$section == "memo" & rows$category == "tax_report" & !rows$cash))
  expect_identical(rows$label[rows$key == "tax_report_taxable_income"],
                   lbl("types.tax.flat.report.taxable_income"))
})

test_that("10.10 Nr. 3: Standardmodell, Endwert mit Kalkulationszins i(1 - s)", {
  s <- 0.3
  i <- 0.05
  res <- vofi_run(wsx_build(wsx_scenario(i = i)))
  q <- 1 + i * (1 - s)
  afa <- 100000 / 3
  rent <- c(0, 30000, 40000, 50000)
  net <- c(60000, 0, 0, 0) + c(-100000, 0, 0, 0) + rent - s * (rent - c(0, rep(afa, 3)))
  expect_equal(res$kpis$terminal_value, sum(net * q^(3:0)), tolerance = 1e-10)
  expect_equal(res$opportunity$EW, 60000 * q^3, tolerance = 1e-10)
  expect_true(all(res$checks$ok))
  expect_gt(res$ledger$values$tax[1L, 2L], 0)
  # mit Verlustvortrag und lag 1 weicht der Endwert ab (Steuerstundung)
  res_v <- vofi_run(wsx_build(wsx_scenario(params = list(rate = s, lag = 1L, building_rate = 1 / 3,
                                                        deposit_interest = "ergebnis",
                                                        loss_mode = "vortrag"), i = i)))
  expect_false(isTRUE(all.equal(res_v$kpis$terminal_value, res$kpis$terminal_value)))
  expect_true(all(res_v$checks$ok))
})

test_that("Unterlassungsalternative privat: Habenzins nach Abgeltungsteuer i(1 - 0,26375)", {
  i <- 0.04
  sc <- wsx_scenario(params = list(rate = 0.42, lag = 0L, building_rate = 1 / 3), i = i)
  res <- vofi_run(wsx_build(sc))
  expect_equal(res$opportunity$EW, 60000 * (1 + i * (1 - 0.26375))^3, tolerance = 1e-10)
})

test_that("10.10 Nr. 4: AfA-Summe = Bemessungsgrundlage (Engine)", {
  sc <- wsx_scenario(params = list(rate = 0.3, lag = 0L, building_rate = 0.5,
                                   deposit_interest = "ergebnis"))
  res <- vofi_run(wsx_build(sc))
  afa <- res$ledger$values$tax_report_depreciation[1L, ]
  expect_equal(-afa, c(0, 50000, 50000, 0))
  expect_equal(-sum(afa), 100000)
})

test_that("lag 1: offene Steuer am Horizont in tax_liability, Invarianten (10.5)", {
  p <- list(rate = 0.3, lag = 1L, building_rate = 1 / 3, deposit_interest = "ergebnis")
  r1 <- vofi_run(wsx_build(wsx_scenario(params = p)))
  e <- r1$ledger$values$tax_report_taxable_income[1L, ]
  expect_equal(r1$ledger$values$tax[1L, ], -0.3 * c(0, 0, e[1L] + e[2L], e[3L]))
  expect_equal(r1$ledger$values$tax_liability[1L, 4L], 0.3 * e[4L])
  expect_equal(r1$ledger$values$tax_report_terminal_open_tax[1L, 4L], 0.3 * e[4L])
  expect_true(all(r1$checks$ok))
})

test_that("10.10 Nr. 6: Ergebnis invariant gegen die Chunk-Größe (Lauf i im Batch = einzeln)", {
  model <- wsx_build(wsx_scenario(params = list(rate = 0.3, lag = 1L, building_rate = 0.25,
                                                loss_mode = "vortrag")))
  f <- c(0.5, 1, 1.3)
  batch <- eng_run_draws(model, draws = wsx_factor_draws(model$grid, f), store = "full")
  for (i in seq_along(f)) {
    one <- eng_run_draws(model, draws = wsx_factor_draws(model$grid, f[i]), store = "full")
    expect_identical(batch$kpis[i, , drop = FALSE], `rownames<-`(one$kpis, i))
    expect_identical(batch$ledger$values$tax[i, , drop = FALSE], one$ledger$values$tax)
    expect_identical(batch$ledger$values$tax_liability[i, , drop = FALSE],
                     one$ledger$values$tax_liability)
    expect_identical(batch$opp$EW[i], one$opp$EW)
  }
})

test_that("Ende-zu-Ende: Neubau Kleinvermieter, degressive AfA ab Fertigstellung (Register)", {
  x <- e2_scenario(
    project_type = "neubau", perspective = "kleinvermieter", horizon_years = 5L,
    building = list(building_type = "MFH", construction_year = 2028L,
                    first_occupancy_year = 2028L, n_units = 12L, living_area_m2 = 900,
                    maintenance = list(basis = "none")),
    grid = list(construction_months = 12L),
    measures = list(neubau = list(measure_type = "neubau", date = "2027-06-01",
                                  completion_date = "2028-01-01", cost_eur = 1000000,
                                  price_index = 0)),
    components = list(miete = list(type = "custom_series", category = "rent",
                                   values = c(0, 0, rep(60000, 4)))),
    tax = list(module = "flat", params = list(rate = 0.42, lag = 0L))
  )
  spec <- e2_resolve(x)
  res <- suppressMessages(e2_run(spec))
  afa <- -res$ledger$values$tax_report_depreciation[1L, ]
  expect_equal(afa, c(0, 0, 50000 * 0.95^(0:3)))
  e <- res$ledger$values$tax_report_taxable_income[1L, ]
  expect_equal(e[3:6], 60000 - afa[3:6])
  expect_true(all(res$checks$ok))
  x$tax$params$depreciation_method <- "linear"
  rl <- suppressMessages(e2_run(e2_resolve(x)))
  expect_equal(-rl$ledger$values$tax_report_depreciation[1L, 3:6], rep(30000, 4))
})

test_that("Ende-zu-Ende: Kauf + Sanierung, anschaffungsnahe HK über das Register (auto)", {
  mk <- function(cost) {
    e2_scenario(
      project_type = "erwerb_sanierung", perspective = "kleinvermieter", horizon_years = 4L,
      building = list(building_type = "MFH", construction_year = 1975L, n_units = 12L,
                      living_area_m2 = 900, maintenance = list(basis = "none")),
      measures = list(
        kauf = list(measure_type = "erwerb_objekt", date = "2027-01-01",
                    purchase_price_eur = 400000, land_share = 0.25, grest_rate = 0.05),
        keller = list(measure_type = "daemmung_kellerdecke", date = "2028-01-01",
                      cost_eur = cost, price_index = 0)),
      tax = list(module = "flat", params = list(rate = 0.42, lag = 0L))
    )
  }
  lo <- suppressMessages(e2_run(e2_resolve(mk(30000))))
  hi <- suppressMessages(e2_run(e2_resolve(mk(80000))))
  lim <- lo$ledger$values$tax_report_acq_test_limit[1L, 2L]
  expect_gt(lim, 0.15 * 300000)
  expect_equal(lo$ledger$values$tax_report_maintenance[1L, 2L], -30000)
  expect_equal(lo$ledger$values$tax_report_acq_test_costs[1L, 2L], 30000 / 1.19)
  expect_equal(hi$ledger$values$tax_report_maintenance[1L, 2L], 0)
  expect_equal(hi$ledger$values$tax_report_acquisition_related[1L, 2L], 80000)
  bv_lo <- lo$ledger$values$tax_report_book_value[1L, 2L]
  bv_hi <- hi$ledger$values$tax_report_book_value[1L, 2L]
  expect_equal(bv_hi - bv_lo, 80000 - 0.02 * 80000)
})

test_that("Leistung: Modul je Periode vektorisiert (MC 2.000 x 30 Perioden)", {
  skip_on_cran()
  g <- make_grid("annual", T = 30L)
  n <- 2000L
  n_t <- g$T + 1L
  rows <- list(
    wsx_row("inv__cost", "capex_depreciable", cbind(-seq(8e5, 1.2e6, length.out = n),
                                                    matrix(0, n, n_t - 1L)),
            category = "capex", asset_id = "b1"),
    wsx_row("z__rent", "income_rental", c(0, rep(60000, n_t - 1L)), category = "rent"),
    wsx_row("m__cost", "capex_expensable", c(0, 0, -20000, rep(0, n_t - 3L)), category = "capex",
            extra = list(spread_years = 4L)))
  a <- vofi_asset("b1", "gebaeude_wohnen", as.Date("2027-01-01"),
                  construction_start_date = as.Date("2026-01-01"))
  tm <- system.time(r <- wsx_run(list(rate = 0.42, loss_mode = "vortrag"), rows, g, n = n,
                                 assets = list(a)))
  expect_lt(tm[["elapsed"]], 5)
  expect_identical(dim(r$pay), c(n, n_t))
})
