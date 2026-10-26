# Tests der Förderregeln (WS-E2, Spec 01 Teil B 4.3.3, 4.4, 4.8, 5.4).

test_that("fund_degression: Stufen nach Antragsdatum, Untergrenze (Teil B 4.3.3)", {
  f <- reg_get("rule", "fund_degression@2026-07-21")$fun
  # Klimageschwindigkeitsbonus KfW 458: 0,16, −0,04 je Halbjahr ab 2027-02-01, Untergrenze 0
  expect_equal(f(0.16, "2027-01-31", "2027-02-01", -0.04, 6, 0), 0.16)
  expect_equal(f(0.16, "2027-02-01", "2027-02-01", -0.04, 6, 0), 0.12)
  expect_equal(f(0.16, "2027-07-31", "2027-02-01", -0.04, 6, 0), 0.12)
  expect_equal(f(0.16, "2027-08-01", "2027-02-01", -0.04, 6, 0), 0.08)
  expect_equal(f(0.16, "2028-08-01", "2027-02-01", -0.04, 6, 0), 0)
  # Höchstkosten 1. WE: 28.000, −750 je Halbjahr, Untergrenze 22.000 (Prüfwerte 4.3.3)
  expect_equal(f(28000, "2027-02-01", "2027-02-01", -750, 6, 22000), 27250)
  expect_equal(f(28000, "2028-08-01", "2027-02-01", -750, 6, 22000), 25000)
  expect_equal(f(28000, "2030-08-01", "2027-02-01", -750, 6, 22000), 22000)
  # vektorisiert über Antragsdaten, Date-Eingaben, Anstieg mit Obergrenze, ohne Grenze
  ad <- as.Date(c("2026-12-01", "2027-02-01", "2030-08-01"))
  expect_equal(f(28000, ad, as.Date("2027-02-01"), -750, 6, 22000), c(28000, 27250, 22000))
  expect_equal(f(1, "2028-02-01", "2027-02-01", 0.5, 12, 2), 2)
  expect_equal(f(0, "2028-02-01", "2027-02-01", -1, 12, NULL), -2)
  expect_error(f(1, "kein Datum", "2027-02-01", -1, 6, 0), class = "vofi_error_input")
  expect_error(f(1, "2027-02-01", "2027-02-01", -1, 0, 0), class = "vofi_error_input")
})

test_that("fund_income_rate: Einkommensstaffel mit einschließlichen Schwellen (Teil B 4.3.3)", {
  f <- reg_get("rule", "fund_income_rate@2026-07-21")$fun
  t <- c(30000, 40000, 50000)
  r <- c(0.40, 0.30, 0.10, 0)
  expect_equal(f(c(28000, 30000, 30001, 38000, 45000, 48000, 50000, 70000), t, r),
               c(0.40, 0.40, 0.30, 0.30, 0.10, 0.10, 0.10, 0))
  expect_equal(f(NA_real_, t, r), NA_real_)
  expect_error(f(1, t, r[-1L]), class = "vofi_error_input")
  expect_error(f(1, c(2, 1), c(1, 2, 3)), class = "vofi_error_input")
})

test_that("fund_staffel_cap: Summe der Stufenwerte je WE, iSFP-Werte (Teil B 4.4)", {
  f <- reg_get("rule", "fund_staffel_cap@2026-07-21")$fun
  kfw <- list(list(units_from = 1, units_to = 1, cap_eur = 28000),
              list(units_from = 2, units_to = 6, cap_eur = 15000),
              list(units_from = 7, units_to = Inf, cap_eur = 8000))
  expect_equal(f(12L, kfw, FALSE), 151000)
  expect_equal(f(1L, kfw, FALSE), 28000)
  expect_equal(f(c(1L, 6L, 10L), kfw, FALSE), c(28000, 103000, 135000))
  bafa <- list(list(units_from = 1, units_to = 1, cap_eur = 30000, cap_isfp_eur = 60000),
               list(units_from = 2, units_to = 6, cap_eur = 15000, cap_isfp_eur = 30000))
  expect_equal(f(1L, bafa, FALSE), 30000)
  expect_equal(f(1L, bafa, TRUE), 60000)
  expect_equal(f(3L, bafa, TRUE), 120000)
  expect_equal(f(0L, bafa, TRUE), 0)
  # KfW 459 mit Degression der 1. WE ab 2027-02-01 (F-4a): 27.250 + 5 · 15.000 + 6 · 8.000
  kfw[[1L]]$cap_eur <- 27250
  expect_equal(f(12L, kfw, FALSE), 150250)
  expect_error(f(1L, list(), FALSE), class = "vofi_error_input")
})

test_that("fund_35c_params: Tranchen, Gesamtsatz, Deckel und Gesetzeswerte (Teil B 4.8)", {
  f <- reg_get("rule", "fund_35c_params@2020-01-01")$fun
  p <- f(list(total_share = 0.20, schedule_shares = c(0.07, 0.07, 0.06),
              cap_per_object_eur = 40000, energy_advice_share = 0.5))
  expect_equal(c(p$share_y1, p$share_y2, p$share_y3), c(0.07, 0.07, 0.06))
  expect_equal(c(p$cap_1, p$cap_2, p$cap_3), c(14000, 14000, 12000))
  expect_equal(p$cap_total, 40000)
  expect_equal(p$energy_advice_share, 0.5)
  expect_identical(f(NULL), p)
  q <- f(list(cap_per_object_eur = 20000))
  expect_equal(c(q$cap_1, q$cap_2, q$cap_3), c(7000, 7000, 6000))
  expect_error(f(list(schedule_shares = c(0.1, 0.1))), class = "vofi_error_input")
})

test_that("Förderregeln: Versionen, Registrierung und Vertragsprüfung (Spec 00 5.3)", {
  for (nm in c("fund_degression@2026-07-21", "fund_income_rate@2026-07-21",
               "fund_staffel_cap@2026-07-21", "fund_35c_params@2020-01-01")) {
    def <- reg_get("rule", nm)
    expect_identical(def$kind, "rule")
    expect_type_contract(nm, "rule")
  }
  spec <- list(project = list(legal_state = as.Date("2026-10-25")))
  expect_identical(scn_rule_for("fund_degression", spec), rule_fund_degression_fun)
  early <- list(project = list(legal_state = as.Date("2026-01-01")))
  expect_error(scn_rule_for("fund_degression", early), class = "vofi_error_registry")
  expect_identical(scn_rule_for("fund_35c_params", early), rule_fund_35c_params_fun)
})

test_that("Förderregeln ziehen keine Zufallszahlen und sind vektorisiert", {
  set.seed(1)
  s0 <- .Random.seed
  f <- reg_get("rule", "fund_income_rate@2026-07-21")$fun
  x <- seq(20000, 80000, by = 1000)
  out <- f(x, c(30000, 40000, 50000), c(0.4, 0.3, 0.1, 0))
  expect_identical(.Random.seed, s0)
  expect_equal(out, vapply(x, function(v) f(v, c(30000, 40000, 50000), c(0.4, 0.3, 0.1, 0)),
                           double(1)))
})
