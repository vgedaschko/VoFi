# Referenzszenarien S1-S5 als Beispiele und Integrationstests (WS-S, Spec 01 Teil C
# Abschnitt 5, Spec 00 Abschnitte 10.10 Nr. 7 und 15.6). Geprueft werden:
#   - Laden ueber vofi_example(), Validierung (keine Fehler; nur dokumentierte Warnungen),
#   - alle deterministischen Pruefwerte S1-T* bis S5-T* mit den Toleranzen aus 5.0 Nr. 8
#     (Betraege +-0,01 EUR, Annuitaeten +-0,1 %, Energiemengen 1e-6 relativ, sonst wie angegeben),
#   - Plausibilitaet: Finanzierungssaldo 0, Invarianten, Steuerbereitschaft, Vergleichskennzahlen,
#   - die MC-Erwartungen (m1)-(m4) mit n_sim = 1.000 (Praefix des Standardlaufs, Seed 20261025);
#     qualitative Hypothesen sind keine Sollwerte (5.0 Nr. 8, Konzept F20): bestaetigte werden
#     als Regressionspruefung festgehalten, nicht bestaetigte sind im Kommentar vermerkt.
# Die Simulations-, Sensitivitaets- und Excel-Teile laufen nur ausserhalb von CRAN
# (skip_on_cran()); die Hilfen stehen in helper-ws-s.R.

# Ohne JIT-Compiler laufen die vielen dynamisch erzeugten Closures der Typen deutlich schneller
# (load_all() und installiertes Paket); Ruecksetzen am Dateiende.
.wss_jit <- compiler::enableJIT(0)
withr::defer({
  compiler::enableJIT(.wss_jit)
  rm(list = ls(wss_cache, all.names = TRUE), envir = wss_cache)
})

# ---------------------------------------------------------------------------------------------
# Laden und Validierung
# ---------------------------------------------------------------------------------------------

test_that("vofi_example() liefert S1-S5; scenario_id = Dateiname, Basis = Referenzvariante", {
  ex <- vofi_example()
  expect_true(all(wss_ids %in% ex))
  for (id in names(wss_ids)) {
    sc <- wss_scenario(id)
    expect_s3_class(sc, "vofi_scenario")
    expect_identical(as.character(unlist(sc$meta$scenario_id)), wss_ids[[id]], info = id)
    expect_identical(vofi_example(wss_ids[[id]]),
                     system.file("extdata", "examples", paste0(wss_ids[[id]], ".yaml"),
                                 package = "vofi"), info = id)
    v <- vofi_variants(sc)
    expect_true("base" %in% as.character(unlist(v$variant %||% v)), info = id)
  }
  # Varianten und Sets nach Teil C 5.1-5.5
  vars <- function(id) setdiff(names(wss_scenario(id)$variants), "base")
  expect_setequal(vars("s1"), "v2_eh70")
  expect_setequal(vars("s2"), c("v1b_ohne_kfw", "v2_eh40_qng"))
  expect_setequal(vars("s3"), c("v2_wp_pv", "v2_jaz_test"))
  expect_setequal(vars("s4"), c("v1_isfp_stufen", "v2_nur_wp"))
  expect_setequal(vars("s5"), c("v2_eh40_kfw300", "v2b_eh40_ohne_kfw300", "v1b_ohne_kfw"))
  expect_true("ohne_wpb" %in% names(wss_scenario("s1")$scenario_sets))
  expect_true("pv_verrechnung_20ct" %in% names(wss_scenario("s3")$scenario_sets))
})

test_that("Validierung S1-S5: keine Fehler, nur dokumentierte Warnungen", {
  # Erwartete Warnungen (Spec 01 Teil C 5.0 Nr. 9, 6.6, OP-06; 01a/01b wie vermerkt)
  allowed <- list(
    s1 = "validation.accounts.liquidity_unchecked",                     # 6.6 (WU ohne Limit)
    s2 = c("validation.accounts.liquidity_unchecked",
           "validation.acquisition.grest_zero",                         # OP-06
           "validation.acquisition.ancillary_sum"),                     # OP-06 (Notar/Grundbuch 0)
    s3 = c("validation.accounts.liquidity_unchecked",
           "validation.library.unreleased_used",                        # v2_jaz_test (Spec 00 4.10)
           "validation.project.application_late"),                      # 01a: Antrag 15.01.2027
    s4 = c("validation.accounts.liquidity_unchecked",                   # Limit .inf (Memo 07)
           "validation.building.property_tax_missing",                  # 5.0 Nr. 9
           "validation.funding.annual_cap_shared"),                     # 01b 4.11 (BAFA 2030/2033)
    s5 = c("validation.building.property_tax_missing",                  # 5.0 Nr. 9
           "validation.acquisition.grest_zero", "validation.acquisition.ancillary_sum")
  )
  required <- list(s1 = character(0), s2 = "validation.acquisition.grest_zero",
                   s3 = "validation.library.unreleased_used",
                   s4 = "validation.building.property_tax_missing",
                   s5 = c("validation.building.property_tax_missing",
                          "validation.acquisition.grest_zero"))
  for (id in names(wss_ids)) {
    v <- wss_validation(id)
    err <- v[v$severity == "error", , drop = FALSE]
    expect_identical(nrow(err), 0L, info = paste(id, paste(err$code, err$path, collapse = "; ")))
    w <- unique(v$code[v$severity == "warning"])
    expect_true(all(w %in% allowed[[id]]),
                info = paste(id, "unerwartete Warnungen:", paste(setdiff(w, allowed[[id]]),
                                                                 collapse = ", ")))
    expect_true(all(required[[id]] %in% w), info = id)
  }
  v3 <- wss_validation("s3")
  expect_identical(unique(v3$variant[v3$code == "validation.library.unreleased_used"]),
                   "v2_jaz_test")
  # 5.0 Nr. 9: ohne building.property_tax Hinweis (I) bei Vermietung (S1-S3), Warnung bei
  # Selbstnutzung (S4, S5, oben)
  for (id in c("s1", "s2", "s3")) {
    v <- wss_validation(id)
    expect_true("validation.building.property_tax_missing" %in% v$code[v$severity == "info"],
                info = id)
  }
  # S1: Set ohne_wpb ohne Treffer in base (Hinweis, 5.1)
  v1 <- wss_validation("s1")
  expect_true("validation.scenario_set.wildcard_no_match" %in% v1$code[v1$severity == "info"])
})

test_that("Varianten bauen und rechnen deterministisch: Finanzierungssaldo 0, Invarianten", {
  for (id in names(wss_ids)) {
    for (v in c("base", setdiff(names(wss_scenario(id)$variants), "base"))) {
      res <- wss_det(id, v)
      expect_s3_class(res, "vofi_result")
      expect_lte(max(abs(res$ledger$values$balance_check)), 1e-6)
      expect_true(all(res$checks$ok), info = paste(id, v))
      expect_vofi_invariants(res)
      expect_identical(res$meta$variant, v, info = paste(id, v))
    }
  }
})

test_that("Steuerbereitschaft (Spec 00 10.10 Nr. 7) in S1-S5", {
  for (id in names(wss_ids)) {
    for (v in c("base", setdiff(names(wss_scenario(id)$variants), "base"))) {
      res <- wss_det(id, v)
      rows <- res$ledger$rows
      cash <- rows$cash & rows$section != "check"
      expect_false(any(cash & rows$tax_category == "not_applicable"), info = paste(id, v))
      # jede capex_*-, acquisition_ancillary- und subsidy_*-Zeile (auch Nullzeilen) mit Asset bzw.
      # Massnahme, ohne Ausnahme
      expect_identical(wss_tax_ready_missing(res), character(0), info = paste(id, v))
    }
  }
  # Foerderkredit mit Tilgungszuschuss: Anzeige-Tag = Massnahme mit den groessten Basisfallkosten
  # (R-99; S1 V2: huelle 990.580,50 von 1.451.488,50 EUR)
  rows <- wss_det("s1", "v2_eh70")$ledger$rows
  expect_identical(rows$measure_id[rows$key == "loan_f_kfw261_loan_repayment_grant"], "huelle")
})

test_that("Merkzeilen loan_<k>_repayment_grant ohne Tilgungszuschuss: nicht steuerrelevant", {
  # Kredite ohne Parameter repayment_grant (z. B. loan_bank_repayment_grant in S1, S2, S3 V2, S5):
  # die Merkzeile ist in allen Perioden 0, unbar und traegt not_applicable statt
  # subsidy_repayment_grant ohne measure_id (Spec 00 7.6, R-99, 10.10 Nr. 7; Befund WS-S)
  n_rows <- 0L
  for (id in names(wss_ids)) {
    for (v in c("base", setdiff(names(wss_scenario(id)$variants), "base"))) {
      res <- wss_det(id, v)
      rows <- res$ledger$rows
      keys <- rows$key[rows$section == "loans" & rows$category == "repayment_grant"]
      memo <- wss_unfunded_grant_memo(res, keys)
      n_rows <- n_rows + sum(memo)
      sel <- rows$key %in% keys[memo]
      expect_true(all(rows$tax_category[sel] == "not_applicable"), info = paste(id, v))
      expect_false(any(rows$cash[sel]), info = paste(id, v))
      # Kredite mit Tilgungszuschuss behalten subsidy_repayment_grant mit Massnahme
      tz <- rows$key %in% keys[!memo]
      expect_true(all(rows$tax_category[tz] == "subsidy_repayment_grant"), info = paste(id, v))
      expect_false(anyNA(rows$measure_id[tz]), info = paste(id, v))
    }
  }
  expect_gt(n_rows, 0L)
})

# ---------------------------------------------------------------------------------------------
# S1 - Kommunales WU: MFH 1963 auf EH 70 EE gegenueber Ohnehin-Sanierung (Teil C 5.1)
# ---------------------------------------------------------------------------------------------

test_that("S1-T1, S1-T2, S1-T11: Investition, Modernisierungskosten, Mittelverwendung t = 0", {
  v1 <- wss_det("s1")
  v2 <- wss_det("s1", "v2_eh70")
  inv1 <- -wss_sum(v1, c("m_ohnehin_fassade_capex__cost", "m_ohnehin_fenster_capex__cost",
                         "m_ohnehin_heizung_capex__cost"), "t0")
  inv2 <- -wss_sum(v2, c("m_huelle_capex__cost", "m_heizung_capex__cost",
                         "m_lueftung_capex__cost"), "t0")
  expect_wss_abs(inv1, 577185.00, label = "S1-T1 V1")
  expect_wss_abs(inv2, 1451488.50, label = "S1-T1 V2")
  expect_wss_abs(-sum(vapply(wss_keys(v1, "project", "capex"), function(k) wss_val(v1, k, "t0"),
                             0)), 577185.00, label = "S1-T1 V1 (alle capex)")
  mod <- vapply(c("huelle", "heizung", "lueftung"), function(m) {
    wss_aux("s1", "v2_eh70", paste0("m_", m, "_capex"))$modernization_base[1, 1]
  }, 0)
  expect_wss_abs(mod[["huelle"]], 542598.00, label = "S1 huelle")
  expect_wss_abs(mod[["heizung"]], 242497.50, label = "S1 heizung")
  expect_wss_abs(mod[["lueftung"]], 89208.00, label = "S1 lueftung")
  expect_wss_abs(sum(mod), 874303.50, label = "S1-T2")
  # S1-T11: Mittelverwendung = Mittelherkunft in t = 0
  expect_wss_abs(wss_val(v1, "ek__in", "t0"), 151488.50, label = "EK")
  expect_wss_abs(wss_val(v1, "loan_bank_draw", "t0"), 427185, label = "S1-T11 Bank")
  expect_wss_abs(wss_val(v1, "dep_balance", "t0"), 1488.50, label = "S1-T11 Geldanlage V1")
  expect_wss_abs(wss_val(v1, "ek__in", "t0") - wss_val(v1, "dep_balance", "t0") +
                   wss_val(v1, "loan_bank_draw", "t0"), inv1, label = "S1-T11 V1")
  expect_wss_abs(wss_val(v2, "loan_f_kfw261_loan_draw", "t0"), 1300000, label = "S1-T11 KfW")
  expect_wss_abs(wss_val(v2, "ek__in", "t0") + wss_val(v2, "loan_f_kfw261_loan_draw", "t0"),
                 inv2, label = "S1-T11 V2")
  expect_wss_abs(wss_val(v2, "dep_balance", "t0"), 0, label = "S1-T11 V2 ohne Geldanlage")
})

test_that("S1-T3: Tilgungszuschuss KfW 261 144.400 EUR zum Termin 2028-01-01 (t = 1)", {
  v2 <- wss_det("s1", "v2_eh70")
  tz <- wss_row(v2, "loan_f_kfw261_loan_repayment_grant")
  expect_wss_abs(tz[["2027"]], 144400.00, label = "S1-T3")
  expect_wss_abs(sum(tz), 144400.00, label = "S1-T3 Summe")
  expect_wss_abs(wss_val(v2, "loan_f_kfw261_loan_balance", "2027"), 1155600, label = "B nach TZ")
})

test_that("S1-T4, T4a, T5, T6: Modernisierungsumlage vor und nach Kappungen (Konzept F14)", {
  a <- wss_aux("s1", "v2_eh70", "u_bestand_rent")
  ms <- c("huelle", "heizung", "lueftung")
  at <- function(f, m) a[[paste0("levy_", m, "_", f)]][1, 3]       # Periode 2028 (t = 2)
  comp <- vapply(ms, function(m) at("computed", m), 0)
  capd <- vapply(ms, function(m) at("capped", m), 0)
  area <- 1600
  expect_wss_abs(sum(comp), 53842.28, label = "S1-T4")
  expect_wss_abs(sum(comp) / area / 12, 2.804285, tol = 5e-7, label = "S1-T4 je m2")
  expect_wss_abs(comp[["huelle"]], 32418.90, label = "S1-T4a huelle")
  expect_wss_abs(comp[["lueftung"]], 6147.02, label = "S1-T4a lueftung")
  expect_wss_abs(comp[["heizung"]], 15276.37, label = "S1-T4a heizung (vor Teilkappung)")
  # Teilkappung Heizungsanteil 0,50 EUR/m2: Gesamtkappe wirkt proportional auf den Vektor nach
  # Teilkappung, daher Heizungsanteil nach Teilkappung = capped_heizung / Faktor
  fac <- capd[["huelle"]] / comp[["huelle"]]
  expect_equal(capd[["lueftung"]] / comp[["lueftung"]], fac, tolerance = 1e-12)
  heiz_partial <- capd[["heizung"]] / fac
  expect_wss_abs(heiz_partial, 9600.00, label = "S1-T4a Teilkappung Heizung")
  t4a <- comp[["huelle"]] + comp[["lueftung"]] + heiz_partial
  expect_wss_abs(t4a, 48165.91, label = "S1-T4a")
  expect_wss_abs(t4a / area / 12, 2.508641, tol = 5e-7, label = "S1-T4a je m2")
  # S1-T5: Gesamtkappe 2,00 EUR/m2 (Miete 6,20 < 7,00)
  expect_wss_abs(sum(capd), 38400.00, label = "S1-T5")
  expect_wss_abs(capd[["huelle"]], 25845.78, label = "S1-T5 huelle")
  expect_wss_abs(capd[["lueftung"]], 4900.67, label = "S1-T5 lueftung")
  expect_wss_abs(capd[["heizung"]], 7653.55, label = "S1-T5 heizung")
  expect_identical(unname(vapply(ms, function(m) at("procedure", m), 0)), c(1, 1, 1))  # bgb_559
  # S1-T6: angesetzte Umlage (Beschluss 1,10 EUR/m2) ab 2028-01-01
  v2 <- wss_det("s1", "v2_eh70")
  lev <- paste0("u_bestand_rent__levy_", ms)
  expect_wss_abs(wss_sum(v2, lev, "2027"), 0, label = "S1-T6 2027")
  for (y in c("2028", "2040", "2056")) {
    expect_wss_abs(wss_sum(v2, lev, y), 21120.00, label = paste("S1-T6", y))
  }
})

test_that("S1-T7, T7a: Annuitaet, Restschuld und Anschluss Bankdarlehen V1", {
  v1 <- wss_det("s1")
  ann <- function(res, y) -wss_sum(res, c("loan_bank_repay", "loan_bank_interest"), y)
  expect_wss_rel(ann(v1, "2027"), 31433.02, 1e-3, label = "S1-T7 Annuitaet")
  expect_wss_abs(wss_val(v1, "loan_bank_balance", "2036"), 254949.95, label = "S1-T7 Restschuld")
  expect_wss_rel(ann(v1, "2037"), 31433.02, 1e-3, label = "S1-T7 Anschluss 4,00 %")
  expect_wss_abs(wss_val(v1, "loan_bank_balance", "2046"), 0, tol = 1e-6, label = "getilgt 2046")
  r7a <- wss_det("s1", overrides = list(financing = list(bank = list(followup_rate_pa = 0.0425))))
  expect_wss_rel(ann(r7a, "2037"), 31825.43, 1e-3, label = "S1-T7a Anschluss 4,25 %")
  expect_wss_abs(wss_val(r7a, "loan_bank_balance", "2036"), 254949.95, label = "S1-T7a bis 2036")
})

test_that("S1-T8, T8a: KfW-261-Kredit (Zinsen, TZ, Annuitaet, Anschluss keep_term n_eff = 16)", {
  v2 <- wss_det("s1", "v2_eh70")
  int <- -wss_row(v2, "loan_f_kfw261_loan_interest")
  rep <- -wss_row(v2, "loan_f_kfw261_loan_repay")
  expect_wss_abs(int[["2027"]], 47450.00, label = "S1-T8 Zinsen 2027")
  for (y in as.character(2028:2031)) {
    expect_wss_abs(int[[y]], 42179.40, label = paste("S1-T8 Zinsen", y))
    expect_wss_abs(rep[[y]], 0, label = paste("S1-T8 tilgungsfrei", y))
  }
  expect_wss_rel(int[["2032"]] + rep[["2032"]], 80165.66, 1e-3, label = "S1-T8 Annuitaet 2032")
  expect_wss_abs(wss_val(v2, "loan_f_kfw261_loan_balance", "2036"), 951288.32,
                 label = "S1-T8 Restschuld 31.12.2036")
  expect_wss_rel(int[["2037"]] + rep[["2037"]], 81639.56, 1e-3, label = "S1-T8 Anschlussrate")
  expect_wss_abs(int[["2052"]], 3139.98, label = "S1-T8 letzte Rate Zins")
  expect_wss_abs(rep[["2052"]], 78499.58, label = "S1-T8 letzte Rate Tilgung")
  years <- names(rep)[rep > 1]
  expect_identical(years, as.character(2032:2052))                   # 21 Annuitaetenjahre
  ov8a <- list(funding = list(kfw261 = list(repayment_grant = list(
    effect = "reduce_installment"
  ))))
  r8a <- wss_det("s1", "v2_eh70", overrides = ov8a)
  expect_wss_rel(-wss_sum(r8a, c("loan_f_kfw261_loan_repay", "loan_f_kfw261_loan_interest"),
                          "2032"), 71261.11, 1e-3, label = "S1-T8a Annuitaet")
  expect_wss_abs(wss_val(r8a, "loan_f_kfw261_loan_balance", "2036"), 999182.07,
                 label = "S1-T8a Restschuld")
})

test_that("S1-T8 (Ende): nach der letzten Rate 2052 keine weitere Leistung (DSCR-Mittel)", {
  # Restschuld 1,09e-9 nach der letzten Annuitaet wird mit ihr getilgt (R/type-inst-loan-core.R);
  # Kapitaldienst bis stock_abs zaehlt in der DSCR nicht (R/kpi-realestate.R; Befund B1 von WS-S)
  v2 <- wss_det("s1", "v2_eh70")
  expect_lte(abs(wss_val(v2, "loan_f_kfw261_loan_balance", "2052")), vofi_tol$zero_abs)
  expect_identical(unname(wss_row(v2, "loan_f_kfw261_loan_repay")[c("2053", "2054")]), c(0, 0))
  expect_lt(v2$kpis$dscr_mean, 100)
})

test_that("S1-T9, T10: CO2-Intensitaet Bestand, Vermieteranteil 2027 und ab 2028 (Paragraf 5a)", {
  b <- wss_aux("s1", "base", "e_before_gas_mfh_co2")
  expect_wss_abs(b$cf_specific_kg_m2[1, 2], 31.675, tol = 1e-9, label = "S1-T9 Intensitaet")
  expect_wss_abs(b$cf_landlord_share[1, 2], 0.40, tol = 1e-12, label = "S1-T9 Stufe")
  expect_wss_abs(b$landlord_share[1, 2], 0.40, tol = 1e-12, label = "S1-T9 Vermieteranteil 2027")
  a <- wss_aux("s1", "base", "e_after_gas_mfh_co2")
  expect_identical(unname(a$s5a_active[1, 2:4]), c(0, 1, 1))
  for (j in 3:31) expect_wss_abs(a$landlord_share[1, j], 0.50, tol = 1e-12,
                                 label = paste("S1-T10 t =", j - 1))
})

test_that("S1-T12: hoeherer CO2-Preis (Set co2_hoch) erhoeht delta_vs_reference (V2)", {
  # Vergleichsregel (Spec 00 12.6, Modus absolute): delta_vs_reference = dEW(V2) - dEW(V1),
  # beide unter demselben Set
  dvr <- function(set = NULL) {
    wss_det("s1", "v2_eh70", set = set)$kpis$delta_terminal_value -
      wss_det("s1", set = set)$kpis$delta_terminal_value
  }
  base <- dvr()
  expect_gt(dvr("co2_hoch"), base)
  if (wss_mc_enabled()) {
    kt <- wss_cmp_mc("s1")$kpi_table
    sel <- kt$variant == "v2_eh70" & kt$kpi == "delta_vs_reference"
    expect_wss_abs(kt$deterministic[sel], base, tol = 1e-6, label = "delta_vs_reference")
  }
})

test_that("Restwerte S1, S2, S5 (Ertragswert bzw. Sachwert) mit Verkaufskosten 3 %", {
  last <- function(res) res$grid$label[length(res$grid$label)]
  rv <- function(id, v = "base") {
    res <- wss_det(id, v)
    y <- last(res)
    val <- wss_val(res, "rv_value__value", y)
    expect_gt(val, 0)
    expect_wss_abs(wss_val(res, "rv_value__sale_cost", y), -0.03 * val, tol = 1e-6,
                   label = paste(id, v, "Verkaufskosten"))
    expect_wss_abs(sum(wss_row(res, "rv_value__value")), val, tol = 1e-6,
                   label = paste(id, v, "nur in T"))
    val
  }
  expect_identical(wss_model("s1")$spec$residual_value$method, "income_value")
  expect_gt(rv("s1", "v2_eh70"), rv("s1"))                          # RND 25 statt 15 Jahre
  rv("s2")
  expect_identical(wss_model("s5")$spec$residual_value$method, "asset_value")
  expect_gt(rv("s5", "v2_eh40_kfw300"), rv("s5"))                   # Effizienzzuschlag 3 %
})

test_that("S1-T13, T14, T16: Verwaltung, Energiemengen, Instandhaltung", {
  v1 <- wss_det("s1")
  v2 <- wss_det("s1", "v2_eh70")
  expect_wss_abs(-wss_val(v1, "u_bestand_opex__admin", "2027"), 9054.62, label = "S1-T13 2027")
  expect_wss_abs(-wss_val(v1, "u_bestand_opex__admin", "2028"), 9253.83, label = "S1-T13 2028")
  for (y in c("2028", "2040")) {
    expect_wss_rel(wss_val(v2, "e_after_heatpump_power_mfh_cost__quantity", y), 120000 / 2.9,
                   1e-6, label = "S1-T14 WP-Strom")
    expect_wss_rel(wss_val(v1, "e_after_gas_mfh_cost__quantity", y), 255000, 1e-6,
                   label = "S1-T14 Gas V1")
  }
  expect_wss_rel(wss_val(v1, "e_before_gas_mfh_cost__quantity", "2027"), 210000, 1e-6,
                 label = "S1-T14 Gas 2027 (9 Monate)")
  expect_wss_abs(-wss_val(v1, "m_maintenance__cost", "2027"), 23961.60, label = "S1-T16 V1 2027")
  expect_wss_abs(-wss_val(v2, "m_maintenance__cost", "2028"), 17139.20, label = "S1-T16 V2 2028")
  expect_wss_abs(-wss_val(v2, "m_maintenance__cost", "2043"), 38451.33, label = "S1-T16 V2 2043")
})

test_that("S1-T15: Pflichtsensitivitaet stufe_2045 (Ersatz 2047 als Waermepumpe)", {
  base <- wss_det("s1")
  st <- wss_det("s1", set = "mit_2045_stufe")
  expect_identical(st$meta$pending_reforms, "stufe_2045")
  # Ersatztermin 2047-01-01 -> Periode 2046 (R-35); Index wie im Basisfall (95.000)
  idx <- -wss_val(base, "m_ersatz_heizung_2047_capex__cost", "2046") / 95000
  expect_gt(idx, 1)
  expect_wss_abs(-wss_val(st, "m_ersatz_heizung_2047_capex__cost", "2046") / idx, 300000,
                 label = "S1-T15 Ersatzkosten (Kostenstand 2027)")
  # Zustand ersatz2047 zu 100 % Waermepumpe (JAZ 2,7); ohne Stufe zu 100 % Gas
  expect_wss_rel(wss_val(st, "e_ersatz2047_heatpump_power_mfh_cost__quantity", "2047"),
                 242250 / 2.7, 1e-6, label = "S1-T15 WP-Strom 2047")
  expect_identical(sum(abs(wss_row(st, "e_ersatz2047_gas_mfh_cost__quantity"))), 0)
  expect_wss_rel(wss_val(base, "e_ersatz2047_gas_mfh_cost__quantity", "2047"), 255000, 1e-6,
                 label = "ohne Stufe Gas")
  expect_identical(sum(abs(wss_row(base, "e_ersatz2047_heatpump_power_mfh_cost__quantity"))), 0)
})

test_that("S1: Set ohne_wpb hat in base keinen Treffer (Hinweis) und kostet V2 den WPB-Bonus", {
  skip_on_cran()
  msgs <- wss_capture(vofi_build(wss_scenario("s1"), scenario_set = "ohne_wpb"))$messages
  expect_true(any(grepl("ohne_wpb", msgs) & grepl("keinen Treffer", msgs)))
  res <- wss_det("s1", "v2_eh70", set = "ohne_wpb")
  # Hypothese 5.1: V2 verliert 126.400 EUR (10 % x 1.264.000); Baubegleitung (50 %) bleibt
  expect_wss_abs(sum(wss_row(res, "loan_f_kfw261_loan_repayment_grant")), 144400 - 126400,
                 label = "TZ ohne WPB")
})

# ---------------------------------------------------------------------------------------------
# S2 - Kommunales WU: Neubau MFH 36 WE mit KfW 298 und Entscheidungsknoten (Teil C 5.2)
# ---------------------------------------------------------------------------------------------

test_that("S2-T1, T2, T3: Gesamtkosten, KfW-Betraege, Bankdarlehen", {
  cost <- function(res) {
    k <- grep("^m_(grundstueck|bauwerk|nebenkosten)_", wss_keys(res, "project"), value = TRUE)
    -sum(vapply(k, function(z) sum(wss_row(res, z)), 0))
  }
  v1 <- wss_det("s2")
  v1b <- wss_det("s2", "v1b_ohne_kfw")
  v2 <- wss_det("s2", "v2_eh40_qng")
  expect_wss_abs(cost(v1), 11700000, label = "S2-T1 V1")
  expect_wss_abs(cost(v2), 12258400, label = "S2-T1 V2 (ohne pv)")
  expect_wss_abs(-sum(wss_row(v2, "m_pv_capex__cost")), 44000, label = "PV getrennt")
  expect_wss_abs(sum(wss_row(v1, "loan_f_kfw298_loan_draw")), 3600000, label = "S2-T2 V1")
  expect_wss_abs(sum(wss_row(v2, "loan_f_kfw298_qng_loan_draw")), 5400000, label = "S2-T2 V2")
  # Teilauszahlungen nach Zahlungsplan 40 % Ende 2027, 60 % Ende 2028 (Teil B 4.6)
  expect_wss_abs(wss_val(v1, "loan_f_kfw298_loan_draw", "2027"), 1440000, label = "KfW 2027")
  expect_wss_abs(wss_val(v1, "loan_f_kfw298_loan_draw", "2028"), 2160000, label = "KfW 2028")
  expect_wss_abs(wss_val(v1, "loan_bank_draw", "t0"), 5100000, label = "S2-T3 V1")
  expect_wss_abs(wss_val(v1b, "loan_bank_draw", "t0"), 8700000, label = "S2-T3 V1b")
  expect_wss_abs(wss_val(v2, "loan_bank_draw", "t0"), 3858400, label = "S2-T3 V2")
  expect_false(any(grepl("^loan_f_", v1b$ledger$rows$key)))
})

test_that("S2-T4, T4a, T5, T6: Zinsen, Annuitaeten und Restschulden", {
  v1 <- wss_det("s2")
  v1b <- wss_det("s2", "v1b_ohne_kfw")
  v2 <- wss_det("s2", "v2_eh40_qng")
  kfw <- list(v1 = list(res = v1, k = "loan_f_kfw298_loan", int = 78840, int28 = 31536,
                        ann = 164969.40),
              v2 = list(res = v2, k = "loan_f_kfw298_qng_loan", int = 158760, int28 = 63504,
                        ann = 273371.56))
  for (nm in names(kfw)) {
    x <- kfw[[nm]]
    int <- -wss_row(x$res, paste0(x$k, "_interest"))
    rep <- -wss_row(x$res, paste0(x$k, "_repay"))
    expect_wss_abs(int[["2028"]], x$int28, label = paste("S2-T4 2028", nm))
    for (y in as.character(2029:2033)) {
      expect_wss_abs(int[[y]], x$int, label = paste("S2-T4", y, nm))
      expect_wss_abs(rep[[y]], 0, label = paste("tilgungsfrei", y, nm))
    }
    expect_wss_rel(int[["2034"]] + rep[["2034"]], x$ann, 1e-3, label = paste("S2-T4a", nm))
  }
  bank <- function(res, y = "2027") -wss_sum(res, c("loan_bank_repay", "loan_bank_interest"), y)
  expect_wss_rel(bank(v1), 306000, 1e-3, label = "S2-T5 V1")
  expect_wss_rel(bank(v1b), 522000, 1e-3, label = "S2-T5 V1b")
  expect_wss_rel(bank(v2), 231504, 1e-3, label = "S2-T5 V2")
  expect_wss_abs(wss_val(v1, "loan_bank_balance", "2036"), 3875377.07, tol = 1, label = "S2-T6 V1")
  expect_wss_abs(wss_val(v2, "loan_bank_balance", "2036"), 2931912.73, tol = 1, label = "S2-T6 V2")
  # keep_payment: Fortfuehrung mit gleicher Rate nach dem Anschluss
  expect_wss_rel(bank(v1, "2037"), bank(v1), 1e-9, label = "keep_payment")
})

test_that("S2-T7, T8, T9: Rohertrag 2029, keine Mieten in der Bauzeit, Verwaltung", {
  v1 <- wss_det("s2")
  expect_wss_abs(wss_val(v1, "u_wohnen_rent__rent", "2029") +
                   wss_val(v1, "stellplaetze__value", "2029"), 384480.00, label = "S2-T7")
  for (y in c("t0", "2027", "2028")) {
    expect_wss_abs(wss_val(v1, "u_wohnen_rent__rent", y), 0, label = paste("S2-T8", y))
    expect_wss_abs(wss_val(v1, "stellplaetze__value", y), 0, label = paste("S2-T8 Stellpl.", y))
  }
  expect_wss_abs(-wss_val(v1, "u_wohnen_opex__admin", "2029"), 14186.11, label = "S2-T9")
})

test_that("S2-T10: Entscheidungsknoten deterministisch (Zweig 1; unter foerderstopp V1b)", {
  v1 <- wss_det("s2")
  expect_identical(v1$decision$funding_id, "kfw298")
  expect_identical(v1$decision$fallback_variant, "v1b_ohne_kfw")
  expect_equal(v1$decision$p_approval, 0.8)
  expect_identical(as.integer(v1$decision$branch), 1L)
  expect_gt(sum(wss_row(v1, "loan_f_kfw298_loan_draw")), 0)
  fs <- wss_det("s2", set = "foerderstopp")
  expect_identical(as.integer(fs$decision$branch), 0L)
  expect_identical(fs$meta$variant, "v1b_ohne_kfw")
  expect_s3_class(fs$decision$alternative, "vofi_result")
  expect_wss_abs(sum(wss_row(fs$decision$alternative, "loan_f_kfw298_loan_draw")), 3600000,
                 label = "Alternative = V1")
  v1b <- wss_det("s2", "v1b_ohne_kfw")
  expect_identical(names(fs$ledger$values), names(v1b$ledger$values))
  expect_lte(max(abs(unlist(fs$ledger$values) - unlist(v1b$ledger$values))), 1e-6)
})

test_that("S2-T11: gleiches Horizontende 2067-01-01 und gleiches Raster in V1, V1b, V2", {
  g <- lapply(c("base", "v1b_ohne_kfw", "v2_eh40_qng"), function(v) wss_det("s2", v)$grid)
  for (x in g) {
    expect_identical(x$end_date, as.Date("2067-01-01"))
    expect_identical(x$T, 40L)
    expect_identical(x$date_end, g[[1L]]$date_end)
  }
})

# ---------------------------------------------------------------------------------------------
# S3 - Genossenschaft: Gas -> Waermepumpe + PV 30 kWp, 12 WE (Teil C 5.3)
# ---------------------------------------------------------------------------------------------

test_that("S3-T1, T2: foerderfaehige Hoechstkosten und Zuschuss KfW 459 (Termin -> t = 1)", {
  g <- wss_aux("s3", "v2_wp_pv", "f_kfw459_grant")
  expect_wss_abs(g$eligible_cost[1, 2], 153560, label = "foerderfaehig")
  expect_wss_abs(g$capped_cost[1, 2], 151000, label = "S3-T1")
  v2 <- wss_det("s3", "v2_wp_pv")
  gr <- wss_row(v2, "f_kfw459_grant__grant_heizung_wp")
  expect_wss_abs(gr[["2027"]], 45300.00, label = "S3-T2")
  expect_wss_abs(sum(gr), 45300.00, label = "S3-T2 Summe")
})

test_that("S3-T3, T4, T4a: Paragraf 559e, Paragraf 559f (Konzept F13, B1, P5)", {
  lv <- function(v, f, ov = NULL) {
    wss_aux("s3", v, "u_mitglieder_rent", ov)[[paste0("levy_heizung_wp_", f)]][1, 3]
  }
  expect_wss_abs(lv("v2_wp_pv", "computed"), 8522.60, label = "S3-T3 rechnerisch")
  expect_wss_abs(lv("v2_wp_pv", "capped"), 5040.00, label = "S3-T3 gekappt")
  expect_identical(lv("v2_wp_pv", "procedure"), 3)                  # bgb_559e
  v2 <- wss_det("s3", "v2_wp_pv")
  expect_wss_abs(wss_val(v2, "u_mitglieder_rent__levy_heizung_wp", "2028"), 3528.00,
                 label = "S3-T3 angesetzt")
  expect_wss_abs(wss_val(v2, "u_mitglieder_rent__levy_heizung_wp", "2027"), 0, label = "2027")
  expect_wss_abs(lv("v2_jaz_test", "computed"), 1996.30, label = "S3-T4 halve_then_funds")
  ov <- list(unit_groups = list(mitglieder = list(rent_law = list(
    hp_reduction_order = "funds_then_halve"
  ))))
  expect_wss_abs(lv("v2_jaz_test", "computed", ov), 4261.30, label = "S3-T4 funds_then_halve")
  ov4a <- list(project = list(pending_reforms = list("unreleased")))
  expect_wss_abs(lv("v2_wp_pv", "computed", ov4a), 8522.60, label = "S3-T4a")
})

test_that("S3-T5, T6, T7, T8: CO2-Stufe, Einspeiseerloes, Annuitaet, Restwerte", {
  b <- wss_aux("s3", "base", "e_before_gas_mfh_co2")
  expect_wss_abs(b$cf_specific_kg_m2[1, 2], 23.53, tol = 5e-3, label = "S3-T5 Intensitaet")
  expect_wss_abs(b$cf_landlord_share[1, 2], 0.30, tol = 1e-12, label = "S3-T5 Stufe")
  v1 <- wss_det("s3")
  v2 <- wss_det("s3", "v2_wp_pv")
  for (y in c("2028", "2040", "2046")) {
    expect_wss_abs(wss_val(v2, "e_pv__feed_in", y), 1324.26, label = paste("S3-T6", y))
  }
  expect_wss_rel(-wss_sum(v2, c("loan_bank_repay", "loan_bank_interest"), "2027"), 12687.85,
                 1e-3, label = "S3-T7")
  expect_wss_abs(wss_val(v2, "loan_bank_balance", "2041"), 0, tol = 1e-6, label = "getilgt")
  expect_wss_abs(wss_val(v2, "rv_value__value", "2046"), 7700.00 + 5758.50, label = "S3-T8 V2")
  expect_wss_abs(wss_val(v1, "rv_value__value", "2046"), 1701.00, label = "S3-T8 Kessel V1")
})

test_that("S3-T9: WP-Strom, PV-Eigenverbrauch und Netzbezug", {
  e <- wss_aux("s3", "v2_wp_pv", "e_after_heatpump_power_mfh_cost")
  p <- wss_aux("s3", "v2_wp_pv", "e_pv")
  expect_wss_rel(e$kwh[1, 3], 95000 / 3.1, 1e-6, label = "S3-T9 WP-Strom")
  expect_wss_rel(p$self_kwh[1, 3], 8100, 1e-6, label = "S3-T9 Eigenverbrauch")
  expect_wss_rel(e$kwh[1, 3] - p$self_kwh[1, 3], 22545.16129, 1e-6, label = "S3-T9 Netzbezug")
})

test_that("S3-T10, T11: Heizkosten der Mitglieder und PV-Betriebskosten (Preisbasis 2026)", {
  flat <- wss_flat(c("gas_mfh", "heatpump_power_mfh"), network = "gas_mfh")
  e1 <- wss_aux("s3", "base", "e_after_gas_mfh_cost", overrides = flat)
  # Heizkosten des Gebaeudes vor der Aufteilung (Arbeitspreis inkl. Netzentgelt, CO2 60 EUR/t,
  # Wartung brutto); die Mitglieder tragen davon nach CO2KostAufG und Paragraf 5a GModG weniger
  tot1 <- e1$work_gross[1, 3] + e1$co2_gross[1, 3] + e1$fees_gross[1, 3]
  expect_wss_abs(tot1, 12052.34, label = "S3-T10 V1")
  v2f <- wss_det("s3", "v2_wp_pv", overrides = flat)
  hk2 <- wss_val(v2f, "e_tenant__energy", "2028")
  expect_wss_abs(hk2, 6536.29, label = "S3-T10 V2")
  expect_wss_abs(hk2 / 840 / 12, 0.6484, tol = 5e-5, label = "S3-T10 V2 je m2")
  expect_wss_abs(-wss_val(v2f, "e_pv__opex", "2028"), 577.50, label = "S3-T11")
  # Mieteranteil V1 (Merkzeile, Vollvermietungsbasis) + Vermieteranteile (CO2-Stufe/Paragraf 5a,
  # belegte Flaeche 99 %) = Heizkosten des Gebaeudes
  v1f <- wss_det("s3", overrides = flat)
  landlord <- -wss_sum(v1f, c("e_after_gas_mfh_co2__co2_landlord",
                              "e_after_gas_mfh_co2__network_fee_landlord"), "2028") / 0.99
  expect_wss_abs(wss_val(v1f, "e_tenant__energy", "2028") + landlord, tot1, tol = 0.02,
                 label = "Mieter- + Vermieteranteil V1")
})

# ---------------------------------------------------------------------------------------------
# S4 - Selbstnutzer EFH 1975: stufenweise Sanierung nach iSFP (Teil C 5.4)
# ---------------------------------------------------------------------------------------------

test_that("S4-T1, T2, T8, T9: KfW 458 (zvE, Boni, Hoechstkosten, Antragsdatum)", {
  m <- wss_model("s4", "v1_isfp_stufen")
  sched <- m$spec$funding$kfw458_wp$rate_components$einkommen$schedule_by_taxable_income
  expect_wss_abs(fund_taxable_income_adj(m$spec, sched), 48000, label = "S4-T1 zvE")
  g <- wss_aux("s4", "v1_isfp_stufen", "f_kfw458_wp_grant")
  expect_wss_abs(g$rate_effective[1, 2], 0.30 + 0.16 + 0.10, tol = 1e-12, label = "S4-T1 Satz")
  expect_wss_abs(g$capped_cost[1, 2], 28000, label = "Hoechstkosten")
  v1 <- wss_det("s4", "v1_isfp_stufen")
  gr <- wss_row(v1, "f_kfw458_wp_grant__grant_wp_2027")
  expect_wss_abs(gr[["2027"]], 15680.00, label = "S4-T2")
  expect_wss_abs(sum(gr), 15680.00, label = "S4-T2 Summe")
  ov8 <- list(building = list(heating_existing = list(installation_year = 2008)))
  r8 <- wss_det("s4", "v1_isfp_stufen", overrides = ov8)
  expect_wss_abs(wss_val(r8, "f_kfw458_wp_grant__grant_wp_2027", "2027"), 11200.00,
                 label = "S4-T8")
  ov9 <- list(funding = list(kfw458_wp = list(application_date = "2027-02-15")))
  r9 <- wss_det("s4", "v1_isfp_stufen", overrides = ov9)
  expect_wss_abs(wss_val(r9, "f_kfw458_wp_grant__grant_wp_2027", "2027"), 14170.00,
                 label = "S4-T9")
})

test_that("S4-T3, T3a: Ausfuehrungskosten V1 und V0 (Kostenstand 2026, Index zum Termin)", {
  v1 <- wss_det("s4", "v1_isfp_stufen")
  v0 <- wss_det("s4")
  # Termin Y-01-01 faellt in die Periode Y - 1 (R-35); 2027-01-01 = t0
  t3 <- list(c("m_wp_2027_capex__cost", "t0", 32960.00),
             c("m_dach_fenster_2030_capex__cost", "2029", 85988.87),
             c("m_fassade_2033_capex__cost", "2032", 55405.82),
             c("m_wp_ersatz_2047_capex__cost", "2046", 46507.36))
  for (x in t3) expect_wss_abs(-wss_val(v1, x[1], x[2]), as.double(x[3]), label = x[1])
  t3a <- list(c("m_gaskessel_capex__cost", "2029", 14068.86),
              c("m_dach_2032_capex__cost", "2031", 47762.09),
              c("m_anstrich_2033_capex__cost", "2032", 14266.54),
              c("m_fenster_2042_capex__cost", "2041", 31452.25),
              c("m_wp_2050_capex__cost", "2049", 65049.41))
  for (x in t3a) {
    expect_wss_abs(-wss_val(v0, x[1], x[2]), as.double(x[3]), label = x[1])
    expect_wss_abs(-sum(wss_row(v0, x[1])), as.double(x[3]), label = paste(x[1], "Summe"))
  }
})

test_that("S4-T4: BAFA-Zuschuss 2030/2033 (excess_over_threshold, Alternative whole_amount)", {
  v1 <- wss_det("s4", "v1_isfp_stufen")
  expect_wss_abs(wss_val(v1, "f_bafa_2030_grant__grant_dach_fenster_2030", "2030"), 10500.00,
                 label = "S4-T4 2030 (t = 4)")
  expect_wss_abs(wss_val(v1, "f_bafa_2033_grant__grant_fassade_2033", "2033"), 9581.16,
                 label = "S4-T4 2033 (t = 7)")
  whole <- list(rate_components = list(isfp = list(mode = "whole_amount")))
  ov <- list(funding = list(bafa_2030 = whole, bafa_2033 = whole))
  r <- wss_det("s4", "v1_isfp_stufen", overrides = ov)
  expect_wss_abs(wss_val(r, "f_bafa_2030_grant__grant_dach_fenster_2030", "2030"), 12000.00,
                 label = "S4-T4 whole_amount 2030")
  expect_wss_abs(wss_val(r, "f_bafa_2033_grant__grant_fassade_2033", "2033"), 11081.16,
                 label = "S4-T4 whole_amount 2033")
})

test_that("S4-T5, T5a: Energiemengen je Zustand", {
  v1 <- wss_det("s4", "v1_isfp_stufen")
  v0 <- wss_det("s4")
  expect_wss_rel(wss_val(v1, "e_after_heatpump_power_cost__quantity", "2027"), 21560 / 2.9, 1e-6,
                 label = "S4-T5 Zustand 1")
  expect_wss_rel(wss_val(v1, "e_stufe2_heatpump_power_cost__quantity", "2030"), 16170 / 3.2, 1e-6,
                 label = "S4-T5 Zustand 2")
  expect_wss_rel(wss_val(v1, "e_stufe3_heatpump_power_cost__quantity", "2033"), 11642.4 / 3.5,
                 1e-6, label = "S4-T5 Zustand 3")
  expect_wss_rel(wss_val(v0, "e_after_gas_cost__quantity", "2030"), 21560 / 0.94, 1e-6,
                 label = "S4-T5a Zustand 1")
  expect_wss_rel(wss_val(v0, "e_dach_gas_cost__quantity", "2032"), 18972.8 / 0.94, 1e-6,
                 label = "S4-T5a Zustand 2")
  expect_wss_rel(wss_val(v0, "e_fenster_gas_cost__quantity", "2042"), 18024.16 / 0.94, 1e-6,
                 label = "S4-T5a Zustand 3")
})

test_that("S4-T6: Energie + Wartung Zustand 1 (Preisbasis 2026) und Ersparnis", {
  flat <- wss_flat(c("gas", "heatpump_power"), network = "gas")
  cost <- function(res) {
    -sum(vapply(wss_keys(res, "project", c("energy_cost", "co2_cost"), kind = "flow"),
                function(k) wss_val(res, k, "2027"), 0))
  }
  c0 <- cost(wss_det("s4", overrides = flat))
  c1 <- cost(wss_det("s4", "v1_isfp_stufen", overrides = flat))
  expect_wss_abs(c0, 3543.07, label = "S4-T6 V0")
  expect_wss_abs(c1, 2174.28, label = "S4-T6 V1")
  expect_wss_abs((c0 - c1) / 12, 114.07, label = "S4-T6 Ersparnis je Monat")
})

test_that("S4-T7: KfW 358 (2030 und 2033): Zinsen der tilgungsfreien Jahre, Annuitaet", {
  v1 <- wss_det("s4", "v1_isfp_stufen")
  k30 <- "loan_f_kfw358_2030_loan"
  k33 <- "loan_f_kfw358_2033_loan"
  expect_wss_abs(wss_val(v1, paste0(k30, "_draw"), "2029"), 70000, label = "Auszahlung 2030")
  expect_wss_abs(wss_val(v1, paste0(k33, "_draw"), "2032"), 45000, label = "Auszahlung 2033")
  for (y in as.character(2030:2032)) {
    expect_wss_abs(-wss_val(v1, paste0(k30, "_interest"), y), 1771.00, label = paste("358/30", y))
  }
  expect_wss_rel(-wss_sum(v1, paste0(k30, c("_interest", "_repay")), "2033"), 4188.12, 1e-3,
                 label = "S4-T7 Annuitaet ab 2033")
  for (y in as.character(2033:2035)) {
    expect_wss_abs(-wss_val(v1, paste0(k33, "_interest"), y), 1138.50, label = paste("358/33", y))
  }
  expect_wss_rel(-wss_sum(v1, paste0(k33, c("_interest", "_repay")), "2036"), 2692.36, 1e-3,
                 label = "S4-T7 Annuitaet ab 2036")
})

test_that("S4-T10: Pflichtsensitivitaet habenzins_abgeltung (Variante und Unterlassung)", {
  r <- wss_det("s4", "v1_isfp_stufen",
               overrides = list(accounts = list(deposit_withholding_tax_share = 0.26375)))
  net_rate <- function(led) {
    b <- led$values$dep_balance[1, ]
    i <- led$values$dep_interest[1, ] + led$values$dep_wht[1, ]
    j <- which(b[-length(b)] > 1)
    i[j + 1L] / b[j]
  }
  nr <- net_rate(r$ledger)
  expect_gt(length(nr), 0L)
  expect_equal(nr, rep(0.025 * 0.73625, length(nr)), tolerance = 1e-9)
  ol <- r$opportunity$ledger
  expect_s3_class(ol, "vofi_ledger")
  no <- net_rate(ol)
  expect_gt(length(no), 0L)
  expect_equal(no, rep(0.01840625, length(no)), tolerance = 1e-9)
  pf <- wss_model("s4")$spec$analysis$mandatory_sensitivities
  ids <- vapply(pf, function(e) as.character(unlist(e$id))[1L], "")
  expect_true("habenzins_abgeltung" %in% ids)
})

test_that("S4-T11: Referenzpflicht im Bestand (Spec 00 12.3a)", {
  sc <- wss_scenario_text("s4", append = "analysis: {primary_kpi: delta_terminal_value}")
  v <- as.data.frame(wss_quiet(vofi_validate(sc)))
  e <- v[v$severity == "error", , drop = FALSE]
  expect_true("validation.reference_variant_missing" %in% e$code)
  expect_identical(unique(e$path[e$code == "validation.reference_variant_missing"]),
                   "analysis.primary_kpi")
})

test_that("S4: Ausfalljahr als Verschiebung, wp_2050 folgt (48 Monate -> t = 25, 60 entfaellt)", {
  # Baupreisindex 3,0 % ab 2026 (Kostenstand 2026): Faktor 1,03^(Y - 2026) zum Termin Y-01-01
  ov <- function(d) list(measures = list(gaskessel = list(delay_months = d)))
  hint <- "types.flow.capex.msg.after_horizon"
  cap48 <- wss_capture(r48 <- vofi_run(wss_model("s4", overrides = ov(48))))
  expect_wss_abs(-wss_val(r48, "m_gaskessel_capex__cost", "2031"), 12500 * 1.03^6,
                 label = "Kessel 2032")
  wp <- wss_row(r48, "m_wp_2050_capex__cost")
  expect_wss_abs(-wp[["2051"]], 32000 * 1.03^26, label = "wp_2050 am Horizontende")
  expect_wss_abs(sum(wp) - wp[["2051"]], 0, label = "wp_2050 nur in t = 25")
  # Termin gleich Horizontende: gebucht, kein Hinweis
  expect_length(wss_conditions(cap48, hint), 0L)
  # 60 Monate: Termin 2053-01-01 nach dem Horizontende, wp_2050 entfaellt mit Hinweis (Teil C (m1))
  cap <- wss_capture(r60 <- vofi_run(wss_model("s4", overrides = ov(60))))
  expect_wss_abs(-wss_val(r60, "m_gaskessel_capex__cost", "2032"), 12500 * 1.03^7,
                 label = "Kessel 2033")
  expect_identical(sum(abs(wss_row(r60, "m_wp_2050_capex__cost"))), 0)
  hz <- wss_conditions(cap, hint)
  expect_length(hz, 1L)
  expect_s3_class(hz[[1L]], "vofi_message")
  expect_identical(hz[[1L]]$args$id, "m_wp_2050_capex")
  expect_equal(hz[[1L]]$args$share, 1)
})

test_that("S4: BAFA 2033 ohne Zusage -> KfW 358 (2033) entfaellt, Luecke ueber 6,0 %-Kredit", {
  r <- wss_det("s4", "v1_isfp_stufen",
               overrides = list(funding = list(bafa_2033 = list(approved = 0))))
  expect_identical(sum(abs(wss_row(r, "f_bafa_2033_grant__grant_fassade_2033"))), 0)
  expect_identical(sum(abs(wss_row(r, "loan_f_kfw358_2033_loan_draw"))), 0)
  expect_wss_abs(-wss_val(r, "m_fassade_2033_capex__cost", "2032"), 55405.82,
                 label = "Stufe 3 findet statt")
  od <- r$ledger$values$od_balance[1, ]
  oi <- -r$ledger$values$od_interest[1, ]
  j <- which(od[-length(od)] > 1)
  expect_gt(length(j), 0L)
  expect_equal(oi[j + 1L] / od[j], rep(0.06, length(j)), tolerance = 1e-9)
})

# ---------------------------------------------------------------------------------------------
# S5 - Familie, Neubau EFH: EH 40 mit KfW 300 gegenueber GModG-Standard (Teil C 5.5)
# ---------------------------------------------------------------------------------------------

test_that("S5-T1: Gesamtkosten V1 / V2", {
  cost <- function(res) {
    k <- grep("^m_(grundstueck|bauwerk|nebenkosten|kueche|pv)_", wss_keys(res, "project"),
              value = TRUE)
    -sum(vapply(k, function(z) sum(wss_row(res, z)), 0))
  }
  expect_wss_abs(cost(wss_det("s5")), 706400, label = "S5-T1 V1")
  expect_wss_abs(cost(wss_det("s5", "v2_eh40_kfw300")), 734600, label = "S5-T1 V2")
})

test_that("S5-T4, T5, T6, T7, T9: Monatsraten, Restschulden, Bank 2027", {
  rate <- function(res, k, y) -wss_sum(res, paste0(k, c("_repay", "_interest")), y) / 12
  v1 <- wss_det("s5")
  v2 <- wss_det("s5", "v2_eh40_kfw300")
  for (y in as.character(2027:2031)) {
    expect_wss_abs(rate(v1, "loan_bank", y) + rate(v1, "loan_f_kfw297_loan", y), 2350.03,
                   label = paste("S5-T4 V1", y))
    expect_wss_abs(rate(v2, "loan_bank", y) + rate(v2, "loan_f_kfw300_loan", y), 2096.72,
                   label = paste("S5-T4 V2", y))
  }
  for (y in as.character(2032:2036)) {
    expect_wss_abs(rate(v1, "loan_bank", y) + rate(v1, "loan_f_kfw297_loan", y), 2546.73,
                   label = paste("S5-T5 V1", y))
    expect_wss_abs(rate(v2, "loan_bank", y) + rate(v2, "loan_f_kfw300_loan", y), 2501.84,
                   label = paste("S5-T5 V2", y))
    expect_wss_abs(rate(v2, "loan_f_kfw300_loan", y), 546.79, label = paste("S5-T7", y))
  }
  expect_wss_abs(wss_val(v1, "loan_bank_balance", "2036"), 321200.85, tol = 1, label = "S5-T6")
  expect_wss_abs(wss_val(v2, "loan_bank_balance", "2036"), 289713.52, label = "S5-T6 V2")
  expect_wss_abs(wss_val(v1, "loan_f_kfw297_loan_balance", "2036"), 87540.04, label = "S5-T6 KfW")
  expect_wss_abs(wss_val(v2, "loan_f_kfw300_loan_balance", "2036"), 145085.47,
                 label = "S5-T6 KfW V2")
  expect_wss_abs(-wss_val(v1, "loan_bank_interest", "2027"), 17320.31, label = "S5-T9 Zinsen")
  expect_wss_abs(-wss_val(v1, "loan_bank_repay", "2027"), 8690.09, label = "S5-T9 Tilgung")
  expect_wss_abs(wss_val(v1, "loan_bank_balance", "2027"), 417709.91, label = "S5-T9 Restschuld")
  expect_wss_abs(-wss_val(v1, "loan_f_kfw297_loan_interest", "2027"), 2190.00,
                 label = "S5-T9 KfW-Zinsen")
  # V2b: KfW 297 Standard 100.000 EUR zu 2,94 %
  v2b <- wss_det("s5", "v2b_eh40_ohne_kfw300")
  expect_wss_abs(-wss_val(v2b, "loan_f_kfw297_standard_loan_interest", "2027"), 2940.00,
                 label = "V2b KfW 297 Standard")
  expect_wss_abs(wss_val(v2b, "loan_bank_draw", "t0"), 454600, label = "V2b Bank")
  expect_wss_abs(wss_val(wss_det("s5", "v1b_ohne_kfw"), "loan_bank_draw", "t0"), 526400,
                 label = "V1b Bank")
})

test_that("S5-T8: WP-Strom V1 / V2 (+ Lueftung), Haushaltsstrom getrennt", {
  q1 <- wss_val(wss_det("s5"), "e_after_power_cost__quantity", "2028")
  q2 <- wss_val(wss_det("s5", "v2_eh40_kfw300"), "e_after_power_cost__quantity", "2028")
  expect_wss_rel(q1 - 3500, 2000, 1e-6, label = "S5-T8 V1")
  expect_wss_rel(q2 - 3500 - 400, 4900 / 3.8, 1e-6, label = "S5-T8 V2")
  expect_wss_abs(wss_val(wss_det("s5"), "e_after_power_cost__quantity", "2027"), 0,
                 label = "Bezug 2028")
})

test_that("S5-T2: KfW-300-Berechtigung und Kreditdeckel (Teil B 4.3.1, F-13, N-10)", {
  v2 <- wss_det("s5", "v2_eh40_kfw300")
  expect_wss_abs(wss_val(v2, "loan_f_kfw300_loan_draw", "t0"), 170000, label = "Zusage")
  cap <- function(facts = NULL) {
    f <- list(amount_eur = NULL)
    if (!is.null(facts)) f$facts <- facts
    r <- wss_det("s5", "v2_eh40_kfw300", overrides = list(funding = list(kfw300 = f)))
    wss_val(r, "loan_f_kfw300_loan_draw", "t0")
  }
  expect_wss_abs(cap(), 170000, label = "S5-T2 Deckel Stufe 1 ohne QNG")
  expect_wss_abs(cap(list(qng = TRUE)), 220000, label = "S5-T2 Deckel mit QNG")
  ov <- list(funding = list(kfw300 = list(facts = list(lca_thg = FALSE))))
  cap_res <- wss_capture(vofi_run(vofi_build(wss_scenario("s5"), "v2_eh40_kfw300",
                                             overrides = ov)))
  r <- cap_res$value
  msgs <- cap_res$warnings
  expect_true(any(grepl("kfw300", msgs) & grepl("lca_thg", msgs)))
  expect_false(any(grepl("^loan_f_kfw300", r$ledger$rows$key)))
})

test_that("S5-T3: zvE 105.000 -> KfW 300 nicht berechtigt, Fehlbetrag ueber den Ausgleich", {
  ov <- list(household = list(taxable_income_avg_eur = 105000))
  cap_res <- wss_capture(vofi_run(vofi_build(wss_scenario("s5"), "v2_eh40_kfw300",
                                             overrides = ov)))
  r <- cap_res$value
  msgs <- cap_res$warnings
  expect_true(any(grepl("kfw300", msgs) & grepl("105000", msgs)))
  expect_false(any(grepl("^loan_f_kfw300", r$ledger$rows$key)))
  v2 <- wss_det("s5", "v2_eh40_kfw300")
  gap <- wss_val(r, "equity_call", "t0") - wss_val(v2, "equity_call", "t0") +
    wss_val(v2, "dep_balance", "t0") - wss_val(r, "dep_balance", "t0")
  expect_wss_abs(gap, 170000, label = "S5-T3 Fehlbetrag (Nachschuss)")
  expect_true("v2b_eh40_ohne_kfw300" %in% names(wss_scenario("s5")$variants))
})

# ---------------------------------------------------------------------------------------------
# Simulation (n_sim = 1.000, Praefix des Standardlaufs) und Vergleich ueber die Varianten
# ---------------------------------------------------------------------------------------------

test_that("Vergleich S1-S5 als Simulation: Vergleichskennzahlen, Rangfolge, Ampel, Invarianten", {
  skip_on_cran()
  for (id in names(wss_ids)) {
    cmp <- wss_cmp_mc(id)
    expect_s3_class(cmp, "vofi_comparison")
    vars <- setdiff(names(wss_scenario(id)$variants), "base")
    expect_identical(cmp$baseline, "base", info = id)
    expect_setequal(names(cmp$results), c("base", vars))
    expect_true(cmp$crn, info = id)
    expect_identical(as.integer(cmp$meta$n_sim), 1000L, info = id)
    for (v in names(cmp$results)) {
      r <- cmp$results[[v]]
      expect_s3_class(r, "vofi_mc_result")
      expect_identical(nrow(r$kpis), 1000L, info = paste(id, v))
      expect_identical(as.integer(r$meta$replicates), 5L, info = paste(id, v))
      expect_true(all(r$checks$ok), info = paste(id, v))
      st <- r$stats[r$stats$kpi == "delta_terminal_value", , drop = FALSE]
      expect_equal(st$deterministic, r$deterministic$kpis$delta_terminal_value[1L],
                   tolerance = 1e-9, info = paste(id, v))
    }
    ds <- cmp$diff_stats[cmp$diff_stats$kpi == "delta_vs_reference", , drop = FALSE]
    expect_setequal(ds$variant, vars)
    expect_true(all(ds$prob_better >= 0 & ds$prob_better <= 1), info = id)
    kt <- cmp$kpi_table
    expect_true(all(vars %in% kt$variant[kt$kpi == "delta_vs_reference"]), info = id)
    expect_setequal(cmp$ranking$variant, c("base", vars))
    tl <- cmp$traffic_light
    expect_setequal(tl$variant, vars)
    expect_true(all(tl$level %in% c("green", "yellow", "red")), info = id)
    expect_true(all(tl$basis == "mc"), info = id)
    expect_s3_class(cmp$comparability, "vofi_validation")
  }
})

test_that("S1 MC (m1), (m2): Eingangsmomente, Rangkorrelation, CRN, Lauf i = Batch", {
  skip_on_cran()
  cmp <- wss_cmp_mc("s1")
  r1 <- cmp$results$base
  r2 <- cmp$results$v2_eh70
  i1 <- r1$inputs
  i2 <- r2$inputs
  expect_wss_mean(i2$cost_factor_v2 * 1451488.50, 1657116.04, "S1 (m1) Kosten V2")
  expect_wss_mean(i2$cost_factor_v2, 1.1416667, "S1 (m1) PERT-Mittel V2")
  expect_wss_mean(i1$cost_factor_v1 * 577185, 615664.00, "S1 (m1) Kosten V1")
  expect_wss_mean(i2$jaz_v2, 2.9333333, "S1 (m1) JAZ")
  expect_wss_mean(i2$demand_after_v2, 122666.67, "S1 (m1) Nutzwaerme")
  expect_wss_mean(i1$cap_rate_rv, 0.0350222, "S1 (m1) Liegenschaftszins")
  expect_wss_mean(i1$rnd_rv, 15, "S1 (m1) RND V1")
  expect_wss_mean(i2$rnd_rv, 25, "S1 (m1) RND V2")
  expect_wss_mean(i1$co2_2030, 116.66667, "S1 (m1) CO2 2030")
  expect_wss_mean(i1$co2_2040, 176.66667, "S1 (m1) CO2 2040")
  expect_lte(abs(stats::cor(i2$cost_factor_v1, i2$cost_factor_v2, method = "spearman") - 0.70),
             0.02)
  expect_lte(abs(stats::cor(i1$co2_2030, i1$co2_2040, method = "spearman") - 0.80), 0.02)
  # (m2) gleiche Schluessel in V1 und V2: identische Uniforms je Lauf (CRN)
  expect_identical(rank(i1$vacancy), rank(i2$vacancy))
  expect_identical(rank(i1$rnd_rv), rank(i2$rnd_rv))
  expect_false(isTRUE(all.equal(i1$vacancy, i2$vacancy)))           # andere Parameter
  for (k in c("co2_2030", "co2_2040", "cost_factor_v1", "cost_factor_v2", "cap_rate_rv")) {
    expect_identical(i1[[k]], i2[[k]], info = k)
  }
  # Lauf i nachrechnen (vofi_sim) = Batch; Kosten = Basis x gezogener Kostenfaktor
  one <- wss_quiet(vofi_sim(r2, 7L))
  expect_equal(one$kpis$delta_terminal_value, r2$kpis$delta_terminal_value[7L],
               tolerance = 1e-9)
  inv <- -wss_sum(one, c("m_huelle_capex__cost", "m_heizung_capex__cost",
                         "m_lueftung_capex__cost"), "t0")
  expect_wss_abs(inv, 1451488.50 * i2$cost_factor_v2[7L], tol = 1e-6, label = "Lauf 7")
  expect_vofi_invariants(one)
})

test_that("S1 MC (m3): entartete Verteilungen -> jeder Lauf = deterministischer Basisfall", {
  skip_on_cran()
  # Spec 00 15.5 Nr. 2: statische Groessen mit min = mode = max = Basis bzw. sd = 0; die Prozesse
  # entfallen (ein Vasicek-Prozess mit sigma = 0 folgt dem Erwartungspfad, nicht dem
  # deterministischen Basiszins 4,0 %)
  deg <- c(
    "stochastic:",
    "  settings: {n_sim: 200, seed: 20261025, sampling: lhs, block_size: 200, store: kpi}",
    "  parameters:",
    "    co2_2030: {target: shared.co2_2030, dist: triangular, min: 80, mode: 80, max: 80}",
    "    co2_2040: {target: shared.co2_2040, dist: triangular,",
    "               min: 121.72377780, mode: 121.72377780, max: 121.72377780}",
    "    network_fee_growth_gas_mfh: {target: shared.network_fee_growth_gas_mfh,",
    "                                 dist: fixed, value: 0.03}",
    "    bio_premium_factor: {target: shared.bio_premium_factor, dist: fixed, value: 1}",
    "    construction_price_shift: {target: shared.construction_price_shift,",
    "                               dist: normal, mean: 0, sd: 0}",
    "    rent_growth: {target: unit_groups.bestand.rent_growth, dist: normal, mean: 0.015, sd: 0}",
    "    cost_factor_v1: {target: shared.cost_factor_v1, dist: triangular,",
    "                     min: 1, mode: 1, max: 1}",
    "    cost_factor_v2: {target: shared.cost_factor_v2, dist: triangular,",
    "                     min: 1, mode: 1, max: 1}",
    "    vacancy: {target: unit_groups.bestand.vacancy_rate, dist: fixed, value: 0.03}",
    "    hardship: {target: unit_groups.bestand.rent_law.hardship_share, dist: fixed, value: 0}",
    "    cap_rate_rv: {target: residual_value.income_value.cap_rate, dist: truncnorm,",
    "                  mean: 0.035, sd: 0, lower: 0.02, upper: 0.06}",
    "    rnd_rv: {target: residual_value.income_value.remaining_life_years,",
    "             dist: triangular, min: 15, mode: 15, max: 15}",
    "  correlations:",
    "    parameters: [[cost_factor_v1, cost_factor_v2, 0.7], [co2_2030, co2_2040, 0.8]]"
  )
  sc <- wss_scenario_text("s1", replace_block = "stochastic", block_lines = deg)
  mc <- wss_quiet(vofi_mc(wss_quiet(vofi_build(sc)), n_sim = 200L))
  det <- wss_det("s1")
  k <- setdiff(intersect(names(mc$kpis), names(det$kpis)), c("sim", "block", "branch"))
  expect_gt(length(k), 10L)
  for (z in k) {
    x <- mc$kpis[[z]]
    d <- det$kpis[[z]][1L]
    if (is.na(d)) {
      expect_true(all(is.na(x)), info = z)
    } else {
      # Toleranz wie Spec 00 15.5 Nr. 2 (1e-10, relativ zu max(1, |Wert|))
      expect_lte(max(abs(x - d)), 1e-10 * max(1, abs(d)), label = z)
    }
  }
})

test_that("S1 MC (m4): Hypothesen (Restwertabhaengigkeit, Ampel hoechstens Gelb)", {
  skip_on_cran()
  cmp <- wss_cmp_mc("s1")
  ds <- cmp$diff_stats
  pb <- function(k) ds$prob_better[ds$variant == "v2_eh70" & ds$kpi == k]
  expect_lt(pb("delta_vs_reference_ex_rv"), 0.2)                   # bestaetigt (0,095)
  expect_gt(pb("delta_vs_reference"), 0.5)                         # bestaetigt (0,904)
  tl <- cmp$traffic_light[cmp$traffic_light$variant == "v2_eh70", ]
  expect_true(tl$level %in% c("yellow", "red"))
  expect_true(isTRUE(tl$rv_dependent))
  # Nicht bestaetigt (keine Sollwerte, Konzept F20): Tornado-Treiber RND/LZ/Kostenfaktor V2
  # (berechnet: Kostenfaktor V2, Mietsteigerung, Netzentgeltwachstum) und Vorzeichenwechsel bei
  # RND V2 <= 18 J. bzw. LZ >= 4,5 % (kein Wechsel im Intervall der Overlay-Verteilung)
  tor <- wss_memo("tor_s1", wss_quiet(vofi_sensitivity(wss_scenario("s1"), variant = "v2_eh70")))
  expect_s3_class(tor, "vofi_sensitivity")
  expect_identical(tor$kpi, "delta_vs_reference")
  res <- tor$results
  expect_true(all(res$swing >= 0))
  expect_lte(res$rank[res$param == "cost_factor_v2"], 3L)          # bestaetigter Teil
  expect_true(all(c("rnd_rv", "cap_rate_rv") %in% res$param))
  sol <- wss_quiet(vofi_solve(wss_scenario("s1"),
                              param = "residual_value.income_value.remaining_life_years",
                              variant = "v2_eh70"))
  expect_s3_class(sol, "vofi_solution")
  expect_equal(sol$interval, c(18, 32))                             # Overlay triangular(18; 25; 32)
  expect_identical(sol$reference, "base")
})

test_that("S2 MC (m1): Entscheidungsknoten, Kompositum, bedingte Statistik", {
  skip_on_cran()
  cmp <- wss_cmp_mc("s2")
  b <- cmp$results$base
  f <- cmp$results$v1b_ohne_kfw
  d <- b$decision
  expect_identical(d$funding_id, "kfw298")
  expect_identical(d$key, "funding.kfw298.approved")
  expect_equal(d$p_approval, 0.8)
  expect_identical(d$share_approved, 0.8)
  a <- b$inputs[["funding.kfw298.approved"]]
  expect_equal(as.vector(tapply(a, b$kpis$block, sum)), rep(160, 5))    # je Block exakt 160/200
  expect_identical(as.integer(b$kpis$branch), as.integer(a))
  i0 <- which(a == 0)
  i1 <- which(a == 1)
  for (k in c("delta_terminal_value", "terminal_value", "dscr_min")) {
    expect_identical(b$kpis[[k]][i0], f$kpis[[k]][i0], info = k)  # Zweig 0 = Ausweichvariante
  }
  # stats_approved = Statistik einer getrennten MC von V1 (Zusage fest, ohne Knoten)
  m1 <- wss_model("s2", overrides = list(funding = list(kfw298 = list(approved = 1,
                                                                      fallback_variant = NULL))))
  expect_null(m1$decision)
  mc1 <- wss_memo("mc_s2_v1", wss_quiet(vofi_mc(m1, n_sim = 1000L, seed = 20261025L)))
  expect_identical(b$kpis$delta_terminal_value[i1], mc1$kpis$delta_terminal_value[i1])
  sa <- d$stats_approved
  s1 <- mc1$stats
  for (k in c("delta_terminal_value", "terminal_value")) {
    expect_equal(sa$mean[sa$kpi == k], s1$mean[s1$kpi == k], tolerance = 1e-9, info = k)
    expect_equal(sa$q50[sa$kpi == k], s1$q50[s1$kpi == k], tolerance = 1e-9, info = k)
  }
  sf <- d$stats_fallback
  expect_equal(sf$mean[sf$kpi == "delta_terminal_value"],
               f$stats$mean[f$stats$kpi == "delta_terminal_value"], tolerance = 1e-9)
})

test_that("S2 MC (m2), (m3): Eingangsmomente und Hypothesen", {
  skip_on_cran()
  cmp <- wss_cmp_mc("s2")
  i <- cmp$results$base$inputs
  expect_wss_mean(i$cost_construction, 1.0833333, "S2 (m2) Kostenfaktor")
  expect_wss_mean(i$cost_construction * 8640000, 9360000, "S2 (m2) Bauwerk V1")
  expect_wss_mean(i$delay_construction, 3.3333333, "S2 (m2) Verzug")
  expect_lte(abs(stats::cor(i$delay_construction, i$cost_construction, method = "spearman") -
                   0.50), 0.02)
  expect_wss_mean(i$rent_initial, 13.00, "S2 (m2) Erstvermietungsmiete")
  expect_lte(abs(stats::sd(i$rent_initial) - 0.80), 4 * 0.80 / sqrt(2 * 1000))
  expect_wss_mean(i$maintenance_factor, 1.0333333, "S2 (m2) Instandhaltung")
  expect_wss_mean(i$cap_rate_rv, 0.0302762, "S2 (m2) Liegenschaftszins")
  expect_lte(abs(stats::sd(i$cap_rate_rv) - 0.0047076), 4 * 0.0047076 / sqrt(2 * 1000))
  expect_wss_mean(cmp$results$v2_eh40_qng$inputs$green_premium_v2, 0.15, "S2 (m2) Green Premium")
  # (m3) bestaetigt: V1 > V2 (gegen das Kompositum) und V2 > V1b
  ds <- cmp$diff_stats[cmp$diff_stats$kpi == "delta_vs_reference", ]
  expect_lt(ds$prob_better[ds$variant == "v2_eh40_qng"], 0.5)
  expect_gt(ds$mean[ds$variant == "v2_eh40_qng"], ds$mean[ds$variant == "v1b_ohne_kfw"])
  # nicht bestaetigt (keine Sollwerte): groesster Beitrag mortgage_rate.at2037 (berechnet:
  # rent_growth) und Break-even-Miete 15-17 EUR/m2 (berechnet rund 13,5 EUR/m2)
  gl <- wss_quiet(vofi_sensitivity(cmp$results$base, method = "global"))
  expect_true("mortgage_rate.at2037" %in% gl$global$input)
  sol <- wss_quiet(vofi_solve(wss_scenario("s2"), param = "shared.rent_initial", kpi = "roe_mirr",
                              target = 0.04))
  expect_s3_class(sol, "vofi_solution")
  if (!is.na(sol$value)) expect_equal(sol$kpi_at_value, 0.04, tolerance = 1e-6)
  expect_true(isTRUE(sol$monotone))
})

test_that("S3 MC (m1)-(m3): Eingaenge, Umlage unabhaengig von der realisierten JAZ, Hypothesen", {
  skip_on_cran()
  cmp <- wss_cmp_mc("s3")
  i <- cmp$results$v2_wp_pv$inputs
  expect_wss_mean(i$jaz, 3.0333333, "S3 (m1) JAZ")
  expect_wss_mean(i$pv_self_share, 0.30, "S3 (m1) Eigenverbrauch")
  expect_wss_mean(i$pv_yield, 900, "S3 (m1) PV-Ertrag")
  expect_lte(abs(stats::sd(i$pv_yield) - 60), 4 * 60 / sqrt(2 * 1000))
  expect_wss_mean(i$cost_factor_v2, 1.025, "S3 (m1) Kostenfaktor")
  expect_wss_mean(cmp$results$base$inputs$hardship, 0.05, "S3 (m1) Haertefall")
  # (m2) je Lauf (Block 1): rechnerische Umlage nur vom Kostenfaktor abhaengig (Plan-JAZ fest)
  m <- wss_model("s3", "v2_wp_pv")
  dr <- wss_draws(m, 1L)
  fl <- wss_flows(m, dr)
  a <- fl$u_mitglieder_rent$aux
  f <- dr$static$cost_factor_v2
  k <- 153560 * f
  expect_equal(a$levy_heizung_wp_computed[, 3], 0.10 * (0.85 * k - 0.30 * pmin(k, 151000)),
               tolerance = 1e-9)
  expect_gt(stats::sd(dr$static$jaz), 0)
  expect_true(all(f >= 0.95))
  expect_equal(a$levy_heizung_wp_capped[, 3], rep(5040, length(f)), tolerance = 1e-9)
  expect_equal(a$levy_heizung_wp_charged[, 3], rep(3528, length(f)), tolerance = 1e-9)
  # (m3) bestaetigt: V2 besser mit P > 0,8; Warmmiete V2 im Bezugsjahr j* (erstes volles Jahr
  # nach Wirksamkeit der Massnahme, 2028; MRE-01) unter V1 (rund -0,03 EUR/m2; im Baujahr 2027
  # waren es deutlicher als -0,04); nicht bestaetigt: Groessenordnung +20 bis +60 TEUR
  # (berechnet rund +15 TEUR)
  ds <- cmp$diff_stats
  expect_gt(ds$prob_better[ds$variant == "v2_wp_pv" & ds$kpi == "delta_vs_reference"], 0.8)
  wr <- ds$mean[ds$variant == "v2_wp_pv" & ds$kpi == "warm_rent_change_y1"]
  expect_lt(wr, 0)
})

test_that("S4 MC (m1)-(m4): Ausfalljahr, BAFA-Zusage, Eingaenge, Hypothesen", {
  skip_on_cran()
  cmp <- wss_cmp_mc("s4")
  b <- cmp$results$base
  v1 <- cmp$results$v1_isfp_stufen
  bf <- b$inputs$boiler_failure
  expect_true(all(bf %in% c(0, 12, 24, 36, 48, 60)))
  expect_true(all(bf >= 0))
  expect_wss_mean(bf, 30, "S4 (m1) Verschiebung")
  cnt <- table(factor(bf, levels = c(0, 12, 24, 36, 48, 60)), b$kpis$block)
  expect_true(all(colSums(cnt) == 200))
  # Teil C (m1) nennt 33 oder 34 Laeufe je Wert; mit LHS-Punkten zufaellig innerhalb der Schichten
  # (Spec 00 11.5) koennen die mittleren Klassen 32 erhalten (Abweichung < 2 von 200/6)
  expect_true(all(abs(cnt - 200 / 6) < 2))
  ap <- v1$inputs[["funding.bafa_2033.approved"]]
  expect_equal(as.vector(tapply(ap, v1$kpis$block, sum)), rep(140, 5))    # je Block 140/200
  i <- v1$inputs
  expect_wss_mean(i$saving_stage2, 0.2433333, "S4 (m3) Einsparung Stufe 2")
  expect_wss_mean(i$saving_stage3, 0.27, "S4 (m3) Einsparung Stufe 3")
  expect_wss_mean(i$rate_kfw358_2030, 0.0276653, "S4 (m3) KfW-358-Zins 2030")
  expect_wss_mean(i$rate_kfw358_2033, 0.0276653, "S4 (m3) KfW-358-Zins 2033")
  expect_wss_mean(b$inputs$deposit_rate, 0.0250115, "S4 (m3) Habenzins")
  expect_lte(abs(stats::cor(i$jaz_s1, i$jaz_s2, method = "spearman") - 0.70), 0.02)
  expect_lte(abs(stats::cor(i$jaz_s2, i$jaz_s3, method = "spearman") - 0.70), 0.02)
  # (m4) bestaetigt: V2 besser mit P > 0,9; Mehrbelastung V1 im Zehnjahresmittel;
  # nicht bestaetigt: P(V1 besser) 0,4-0,6 (berechnet rund 1,0)
  ds <- cmp$diff_stats
  expect_gt(ds$prob_better[ds$variant == "v2_nur_wp" & ds$kpi == "delta_vs_reference"], 0.9)
  expect_lt(ds$mean[ds$variant == "v1_isfp_stufen" & ds$kpi == "monthly_saving_avg10"], 0)
})

test_that("S4 MC (m1), (m2) je Lauf: wp_2050 folgt der Verschiebung, BAFA 2033 koppelt KfW 358", {
  skip_on_cran()
  cmp <- wss_cmp_mc("s4")
  per_of <- function(m, lab) {
    apply(m, 1L, function(r) {
      j <- which(abs(r) > 0)
      if (length(j) == 1L) lab[j] else if (length(j) == 0L) "-" else "mehrfach"
    })
  }
  # (m1) Block 1 mit vollem Ledger: Laeufe 1-200 = Praefix des Vergleichs (R-73)
  b <- cmp$results$base
  cap <- wss_mc_full("s4")
  mc <- cap$value
  bf <- mc$inputs$boiler_failure
  expect_identical(bf, b$inputs$boiler_failure[1:200])
  expect_identical(mc$kpis$delta_terminal_value, b$kpis$delta_terminal_value[1:200])
  expect_setequal(unique(bf), c(0, 12, 24, 36, 48, 60))
  lab <- mc$grid$label
  # Termin Y-01-01 in der Periode Y - 1 (R-35): Kessel 2028 + d/12, wp_2050 2050 + (d - 24)/12;
  # 48 Monate -> 2052-01-01 = Horizontende (t = 25, Periode 2051), 60 Monate -> entfaellt
  kessel <- per_of(mc$ledger$values$m_gaskessel_capex__cost, lab)
  expect_identical(kessel, as.character(2027 + bf / 12))
  wp <- per_of(mc$ledger$values$m_wp_2050_capex__cost, lab)
  expect_identical(wp, ifelse(bf == 60, "-", as.character(2047 + bf / 12)))
  expect_identical(wp[bf == 48], rep(lab[26L], sum(bf == 48)))
  # Hinweis einmal je Komponente mit dem Anteil der Laeufe ohne Zahlung im Horizont
  hz <- wss_conditions(cap, "types.flow.capex.msg.after_horizon")
  expect_length(hz, 1L)
  expect_identical(hz[[1L]]$args$id, "m_wp_2050_capex")
  expect_equal(hz[[1L]]$args$share, mean(bf == 60))
  expect_vofi_invariants(mc)
  # Laeufe ausserhalb von Block 1 (vofi_sim, je Verschiebung ein Lauf) folgen derselben Regel
  bf_all <- b$inputs$boiler_failure
  for (d in c(0, 12, 24, 36, 48, 60)) {
    i <- which(bf_all == d & seq_along(bf_all) > 200L)[1L]
    one <- wss_quiet(vofi_sim(b, i))
    expect_equal(one$kpis$delta_terminal_value, b$kpis$delta_terminal_value[i], tolerance = 1e-9)
    w <- per_of(one$ledger$values$m_wp_2050_capex__cost, one$grid$label)
    expect_identical(w, if (d == 60) "-" else as.character(2047 + d / 12), info = paste(d, i))
  }
  # (m2) V1: in Laeufen ohne BAFA-2033-Zusage entfallen Zuschuss und KfW 358 (2033) (Kopplung
  # approved = ref funding.bafa_2033.approved); Stufe 3 findet statt, Fehlbetrag ueber das
  # Kontokorrent (Ergaenzungskredit, Zins am Pfad market.mortgage_rate)
  v1 <- cmp$results$v1_isfp_stufen
  cap1 <- wss_mc_full("s4", "v1_isfp_stufen")
  m1 <- cap1$value
  ap <- m1$inputs[["funding.bafa_2033.approved"]]
  expect_identical(ap, v1$inputs[["funding.bafa_2033.approved"]][1:200])
  expect_equal(sum(ap), 140)
  vals <- m1$ledger$values
  tot <- function(k) rowSums(abs(vals[[k]]))
  expect_identical(tot("loan_f_kfw358_2033_loan_draw")[ap == 0], rep(0, 60))
  expect_identical(tot("f_bafa_2033_grant__grant_fassade_2033")[ap == 0], rep(0, 60))
  expect_equal(tot("loan_f_kfw358_2033_loan_draw")[ap == 1], rep(45000, 140), tolerance = 1e-12)
  expect_true(all(tot("f_bafa_2033_grant__grant_fassade_2033")[ap == 1] > 0))
  expect_true(all(tot("loan_f_kfw358_2033_loan_interest")[ap == 0] == 0))
  expect_true(all(tot("m_fassade_2033_capex__cost") > 0))
  p32 <- match("2032", lab)
  expect_true(all(vals$od_balance[ap == 0, p32] > 1))
  expect_vofi_invariants(m1)
  i <- which(v1$inputs[["funding.bafa_2033.approved"]] == 0 & seq_len(nrow(v1$kpis)) > 200L)[1L]
  one <- wss_quiet(vofi_sim(v1, i))
  expect_identical(sum(abs(wss_row(one, "loan_f_kfw358_2033_loan_draw"))), 0)
  expect_identical(sum(abs(wss_row(one, "f_bafa_2033_grant__grant_fassade_2033"))), 0)
  expect_equal(one$kpis$delta_terminal_value, v1$kpis$delta_terminal_value[i], tolerance = 1e-9)
})

test_that("S5 MC (m1)-(m3): Anschlusszinsfaecher, Eingaenge, Belastung und Ampel", {
  skip_on_cran()
  m <- wss_model("s5")
  dr <- wss_draws(m, 1:5)
  lab <- m$grid$label
  r37 <- dr$paths$mortgage_rate[, match("2037", lab)]
  expect_length(r37, 1000L)
  # Teil C 1.6.3, y = 11: E 0,038252986, sd 0,013625164; Quantile q05/q50/q95
  expect_wss_mean(r37, 0.038252986, "S5 (m1) Zins 2037")
  expect_lte(abs(stats::sd(r37) - 0.013625164), 4 * 0.013625164 / sqrt(2 * 1000))
  expect_wss_quantile(r37, 0.05, 0.01584159, "S5 (m1)")
  expect_wss_quantile(r37, 0.50, 0.03825299, "S5 (m1)")
  expect_wss_quantile(r37, 0.95, 0.06066439, "S5 (m1)")
  cmp <- wss_cmp_mc("s5")
  b <- cmp$results$base
  v2 <- cmp$results$v2_eh40_kfw300
  # Anschluss 2037-01-01: beobachtet wird der Pfadwert der Periode 2036 (R-45)
  expect_equal(b$features[["mortgage_rate.at2036"]],
               dr$paths$mortgage_rate[, match("2036", lab)], tolerance = 1e-12)
  expect_wss_mean(v2$inputs$eh40_surcharge, 0.0633333, "S5 (m2) Mehrkosten EH 40")
  expect_wss_mean(b$inputs$demand_after, 7000, "S5 (m2) Nutzwaerme V1")
  expect_wss_mean(v2$inputs$demand_after, 5040, "S5 (m2) Nutzwaerme V2")
  expect_identical(rank(b$inputs$demand_after), rank(v2$inputs$demand_after))      # CRN
  expect_equal(as.vector(tapply(b$inputs$feed_in_flag, b$kpis$block, sum)), rep(100, 5))
  expect_wss_mean(v2$inputs$efficiency_premium_v2, 0.03, "S5 (m2) Effizienzzuschlag")
  # (m3) bestaetigt: V2 besser mit P > 0,8; Belastungsquote 0,38-0,42, Restriktion in einem Teil
  # der Laeufe verletzt, Ampel daher hoechstens Gelb
  ds <- cmp$diff_stats
  expect_gt(ds$prob_better[ds$variant == "v2_eh40_kfw300" & ds$kpi == "delta_vs_reference"], 0.8)
  st <- v2$stats
  br <- st$mean[st$kpi == "burden_ratio_max"]
  expect_true(br >= 0.38 && br <= 0.42)
  pr <- cmp$restrictions
  p_burden <- pr$prob[pr$variant == "v2_eh40_kfw300" & pr$code == "burden"]
  expect_true(p_burden > 0 && p_burden < 1)
  expect_gte(p_burden, 0.30)
  tl <- cmp$traffic_light[cmp$traffic_light$variant == "v2_eh40_kfw300", ]
  expect_true(tl$level %in% c("yellow", "red"))
  expect_true(grepl("burden", tl$ko_codes))
})

# ---------------------------------------------------------------------------------------------
# Excel-Fassungen der Beispiele (data-raw/build_examples_xlsx.R, Spec 00 4.14)
# ---------------------------------------------------------------------------------------------

test_that("Excel-Fassungen S1-S5 entsprechen den YAML-Beispielen (Round-Trip)", {
  skip_on_cran()
  blocks <- function(sc) {
    x <- unclass(sc)
    attributes(x) <- list(names = names(x))
    x
  }
  for (id in names(wss_ids)) {
    f <- system.file("extdata", "examples", paste0(wss_ids[[id]], ".xlsx"), package = "vofi")
    expect_true(nzchar(f), info = id)
    sx <- wss_quiet(vofi_read_scenario(f))
    expect_identical(blocks(sx), blocks(wss_scenario(id)), info = id)
  }
})
