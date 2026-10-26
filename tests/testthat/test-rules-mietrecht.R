# Tests für R/rules-mietrecht.R (WS-E; Spec 01 Teil B Abschnitte 1.9, 1.12, 5.1, 5.2, Prüfwerte
# L-1 bis L-13). L-2, L-4 (Typebene) und L-11 stehen in test-type-flow-rent-path.R.

expect_near <- function(actual, expected, tol = 0.006) {
  testthat::expect_true(all(abs(actual - expected) <= tol),
                        info = paste("ist:", paste(format(actual, nsmall = 6), collapse = " "),
                                     "soll:", paste(expected, collapse = " ")))
}

p_cur <- mr_params(eop_lp_mietrecht(), NULL)
p_ii <- mr_params(eop_lp_mietrecht_ii(), NULL)
p_f <- mr_params(eop_lp_mietrecht(), eop_lp_559f())

ann <- function(procedure, cost, ih = 0, g = 0, tz = 0, zint = 0, attribution = "full", hv = 0,
                hp_order = "halve_then_funds", flat_order = "flat_before_funds",
                section43 = FALSE, p = p_cur) {
  mr_levy_annual(procedure, cost, ih, g, tz, zint, attribution, hv, hp_order, flat_order,
                 section43, TRUE, p)
}

test_that("Vertragstests aller Mietrechtsregeln (Prüfkit 5.6)", {
  rl <- reg_list("rule")
  nm <- rl$name[startsWith(rl$name, "mr_")]
  expect_length(nm, 10L)
  for (x in nm) expect_type_contract(x, "rule")
})

test_that("mr_params: Rechtsparameter aus der Nutzlast", {
  expect_true(p_cur$active)
  expect_false(isTRUE(p_cur$active_559f))
  expect_true(p_f$active_559f)
  expect_equal(c(p_cur$kappung_rate_default, p_cur$kappung_rate_15, p_cur$rate_559,
                 p_cur$rate_559e), c(0.20, 0.15, 0.08, 0.10))
  expect_equal(c(p_cur$cap_high, p_cur$cap_low, p_cur$cap_low_threshold, p_cur$cap_heating),
               c(3, 2, 7, 0.5))
  expect_equal(p_cur$cap_window_months, 72)
  expect_equal(c(p_cur$limit_559c_per_unit, p_ii$limit_559c_per_unit), c(10000, 20000))
  expect_false("bgb_559e" %in% p_cur$relet_levy_procedures)
  expect_true("bgb_559e" %in% p_ii$relet_levy_procedures)
  # Regelkonstante je Rechtsstand nur über s556e.relet_levy_procedures (EOP-09); ohne den
  # Schlüssel gilt das geltende Recht, auch wenn s557a.excludes § 559e enthält
  lp_no_key <- eop_lp_mietrecht_ii()
  lp_no_key$s556e <- NULL
  expect_identical(mr_params(lp_no_key, NULL)$relet_levy_procedures, c("bgb_559", "bgb_559c"))
  lp_other <- eop_lp_mietrecht()
  lp_other$s556e <- NULL
  lp_other$s557a$excludes <- c(lp_other$s557a$excludes, "bgb_559e")
  expect_false("bgb_559e" %in% mr_params(lp_other, NULL)$relet_levy_procedures)
  inactive <- mr_params(NULL, NULL)
  expect_false(isTRUE(inactive$active))
  expect_equal(mr_levy_annual("bgb_559", 1e5, 0, 0, 0, 0, "full", 0, "halve_then_funds",
                              "flat_before_funds", FALSE, TRUE, inactive), 0)
  expect_equal(mr_levy_cap_total(7, 0, inactive), Inf)
  expect_equal(mr_levy_cap_heating(0, inactive), Inf)
})

test_that("L-1: Drittmittel voll bzw. anteilig zugerechnet (S1-T4, F14)", {
  k <- 1451488.50
  ih <- 577185.00
  zint <- 1300000 * (0.04 - 0.0365)
  expect_near(zint, 4550, 1e-9)
  full <- ann("bgb_559", k, ih, tz = 144400, zint = zint)
  expect_near(full, 53842.28)
  expect_near(full / (12 * 1600), 2.804285, 1e-6)
  expect_near(ann("bgb_559", k, ih, tz = 144400, zint = zint, attribution = "proportional"),
              60245.25)
  memo07 <- ann("bgb_559", k, ih, tz = 144400) - (k - ih) / k * zint
  expect_near((k - ih) / k, 0.602350, 1e-6)
  expect_near(memo07, 55651.59)
})

test_that("L-3: § 559e mit Zuschuss, Heizungskappe und Beschluss (S3-T3, F13)", {
  u <- ann("bgb_559e", 153560, g = 45300)
  expect_near(u, 8522.60)
  expect_near(u / (12 * 840), 0.845496, 1e-6)
  expect_near(ann("bgb_559e", 153560, g = 45300, flat_order = "funds_before_flat"), 9202.10)
  cap <- rp_levy_caps(matrix(u / (12 * 840)), matrix(1), 6.4, 0, 0, Inf, 0, p_cur)
  expect_near(cap$l[1, 1] * 12 * 840, 5040.00)
  expect_true(cap$binding)
  vol <- rp_levy_caps(matrix(u / (12 * 840)), matrix(1), 6.4, 0, 0, 0.35, 0, p_cur)
  expect_near(vol$l[1, 1] * 12 * 840, 3528.00)
  expect_near(vol$capped[1, 1], 0.5, 1e-12)
})

test_that("L-4: Halbierung nach § 559f (Reihenfolgen, Ausnahmen, Schwelle)", {
  hv <- mr_hp_halving(TRUE, c(2.4, 2.5, 2.4, 2.4, 2.4), c(70, 70, 55, 70, 70),
                      c(1985, 1985, 1985, 1997, 1985), "auto", NA, p_f)
  expect_equal(hv, c(1, 0, 0, 0, 1))
  expect_equal(mr_hp_halving(TRUE, 2.5, 70, 1985, "auto", FALSE, p_f), 1)
  expect_equal(mr_hp_halving(TRUE, 2.4, 55, 1985, "none", NA, p_f), 1)
  expect_equal(mr_hp_halving(TRUE, 2.4, 70, 1985, "auto", NA, p_cur), 0)
  expect_equal(mr_hp_halving(FALSE, 2.0, 70, 1985, "auto", NA, p_f), 0)
  expect_near(ann("bgb_559e", 153560, g = 45300, hv = 1, p = p_f), 1996.30)
  expect_near(ann("bgb_559e", 153560, g = 45300, hv = 1, hp_order = "funds_then_halve", p = p_f),
              4261.30)
  expect_near(ann("bgb_559e", 153560, g = 45300, hv = 1, flat_order = "funds_before_flat",
                  p = p_f), 2675.80)
  expect_near(ann("bgb_559e", 153560, g = 45300, hv = 1, hp_order = "funds_then_halve",
                  flat_order = "funds_before_flat", p = p_f), 4601.05)
  expect_near(ann("bgb_559e", 153560, g = 45300, hv = 0, p = p_cur), 8522.60)
})

test_that("L-5: § 559 mit Erhaltungsanteil, Tilgungszuschuss und Zinsermäßigung", {
  zint <- 60000 * (0.038 - 0.0353)
  u <- ann("bgb_559", 60000, 18000, tz = 3000, zint = zint)
  expect_near(u, 2958.00)
  expect_near(u / (12 * 70), 3.521429, 1e-6)
  expect_equal(mr_levy_cap_total(7.5, 0, p_cur), 3)
  cap <- rp_levy_caps(matrix(u / (12 * 70)), matrix(0), 7.5, 0, 0, Inf, 0, p_cur)
  expect_near(cap$l[1, 1] * 70, 210.00)
  expect_near(cap$l[1, 1] * 70 * 12, 2520.00)
  expect_equal(mr_levy_cap_total(c(6.99, 7), 0, p_cur), c(2, 3))
})

test_that("L-6: § 559c über der Wertgrenze fällt auf § 559 zurück; Mietrecht II", {
  expect_near(ann("bgb_559c", 18000), 1008.00)
  expect_near(ann("bgb_559", 18000), 1440.00)
  case <- function(legal) {
    eop_rp(unit_group = "g", living_area_m2 = 70, n_units = 1L, rent_eur_m2_month = 7.5,
           increase_policy = "fixed_growth", rent_growth = 0, rent_law_measures = list("k"),
           levy_rows = list("k"),
           .measures = list(k = list(modernization_kind = "bgb_555b_1", cost_eur = 18000,
                                     completion_date = "2027-01-01",
                                     rent_law = list(procedure = "bgb_559c",
                                                     levy_effective_date = "2027-01-01"))),
           .legal = legal)
  }
  # W „Wertgrenze überschritten“ mit dem Anteil der Läufe (1.9.2, 1.14)
  expect_warning(cur <- case(eop_legal()), "Wertgrenze", class = "vofi_warning_engine")
  expect_near(eop_years(cur, "levy_k", 2027:2028), c(1440, 1440))
  expect_equal(cur$flows$aux$levy_k_procedure[1, 2], 1)
  msg <- Filter(function(x) grepl("limit_559c", x$key), cur$flows$meta$messages)
  expect_length(msg, 1L)
  expect_identical(c(msg[[1L]]$level, msg[[1L]]$share), c("warn", "1"))
  ii <- case(eop_legal(mietrecht = eop_lp_mietrecht_ii()))
  expect_near(eop_years(ii, "levy_k", 2027:2028), c(1008, 1008))
  expect_near(eop_row(ii$flows, "levy_k")[1, 2] / 12, 84.00)
  expect_equal(ii$flows$aux$levy_k_procedure[1, 2], 2)
})

test_that("L-7: § 559e gegenüber § 559 mit Heizungskappe (Memo 02 Bsp. 3)", {
  u_e <- ann("bgb_559e", 15000, g = 4500)
  expect_near(u_e, 825.00)
  expect_near(u_e / (12 * 70), 0.982143, 1e-6)
  u_9 <- ann("bgb_559", 15000, ih = 0.4 * 15000)
  expect_near(u_9, 720.00)
  for (u in c(u_e, u_9)) {
    cap <- rp_levy_caps(matrix(u / (12 * 70)), matrix(1), 7.5, 0, 0, Inf, 0, p_cur)
    expect_near(cap$l[1, 1] * 70, 35.00)
    expect_near(cap$l[1, 1] * 70 * 12, 420.00)
  }
})

test_that("L-8 bis L-10: Restraum der Kappungen und proportionale Kürzung", {
  l8 <- rp_levy_caps(matrix(2.00), matrix(0), 7.5, 1.50, 0, Inf, 1.50, p_cur)
  expect_near(l8$l[1, 1], 1.50, 1e-12)
  l9 <- rp_levy_caps(matrix(c(0.40, 1.00), 1), matrix(c(1, 0), 1), 7.5, 0.30, 0.30, Inf, 0.30,
                     p_cur)
  expect_near(l9$l[1, ], c(0.20, 1.00), 1e-12)
  expect_near(l9$heat[1, 1], 0.20, 1e-12)
  l10 <- rp_levy_caps(matrix(c(0.80, 2.80), 1), matrix(c(1, 0), 1), 7.5, 0, 0, Inf, 0, p_cur)
  expect_near(l10$l[1, ], c(0.454545, 2.545455), 1e-6)
  expect_near(sum(l10$l), 3, 1e-12)
  batch <- rp_levy_caps(matrix(c(2.00, 2.00), 2, 1), matrix(0, 2, 1), c(7.5, 6.5), c(1.5, 0),
                        c(0, 0), c(Inf, 1), c(1.5, 0), p_cur)
  expect_near(batch$l[, 1], c(1.50, 1.00), 1e-12)
})

test_that("L-12: Zulässigkeit der Umlage je Phase (mr_levy_allowed, N-06)", {
  procs <- c("bgb_559", "bgb_559c", "bgb_559e")
  expect_identical(mr_levy_allowed("bgb_555b_1a", "staffel", "staffel", TRUE, procs, p_cur),
                   c(FALSE, FALSE, TRUE))
  expect_identical(mr_levy_allowed("bgb_555b_1a", "staffel", "staffel", TRUE, procs, p_ii),
                   c(FALSE, FALSE, FALSE))
  expect_identical(mr_levy_allowed(c("bgb_555b_1", "bgb_555b_1a", "bgb_555b_6"), "index",
                                   "index", c(TRUE, TRUE, FALSE), "bgb_559", p_cur),
                   c(FALSE, TRUE, TRUE))
  expect_identical(mr_levy_allowed(c("bgb_555b_1", "none", "bgb_555b_2"), "paragraph_558",
                                   "p558", TRUE, "bgb_559", p_cur), c(TRUE, FALSE, FALSE))
  expect_identical(mr_levy_allowed("bgb_555b_1", c("paragraph_558", "owner_occupied"), "p558",
                                   TRUE, "bgb_559e", p_cur), c(FALSE, FALSE))
  expect_identical(mr_levy_allowed("bgb_555b_1", "paragraph_558", "p558", TRUE, "bgb_559",
                                   mr_params(NULL, NULL)), FALSE)
})

test_that("L-13: Aliase des Verfahrens (Zahl 559, \"559e\")", {
  expect_identical(rp_code(559, "levy_procedure"), "bgb_559")
  expect_identical(rp_code("559e", "levy_procedure"), "bgb_559e")
  case <- function(proc) {
    eop_rp(unit_group = "g", living_area_m2 = 70, n_units = 1L, rent_eur_m2_month = 7.5,
           increase_policy = "fixed_growth", rent_growth = 0, rent_law_measures = list("k"),
           levy_rows = list("k"),
           .measures = list(k = list(modernization_kind = "bgb_555b_1", cost_eur = 12000,
                                     completion_date = "2027-01-01",
                                     rent_law = list(procedure = proc,
                                                     levy_effective_date = "2027-01-01"))))
  }
  expect_equal(eop_years(case(559), "levy_k", 2027:2029),
               eop_years(case("bgb_559"), "levy_k", 2027:2029))
})

test_that("§ 558: Zielmiete mit Kappung, Kürzung und freiwilliger Obergrenze", {
  expect_equal(mr_558_target(8, 6, 0, 0, 0.20, Inf), 7.2)
  expect_equal(mr_558_target(8, 6, 0, 0, 0.15, Inf), 6.9)
  expect_equal(mr_558_target(9, 7, 0, 1, 0.20, Inf), 7.4)
  expect_equal(mr_558_target(9, 7, 0.5, 0, 0.20, Inf), 8.9)
  expect_equal(mr_558_target(9, 7, 0, 0, Inf, Inf), 9)
  expect_equal(mr_558_target(c(9, 9), 7, 0, 0, 0.2, c(8, Inf)), c(8, 8.4))
})

test_that("Indexmiete: Dämpfung nur mit Mietrecht II im Gebiet", {
  expect_equal(mr_index_adjustment(0.05, TRUE, p_cur), 0.05)
  expect_equal(mr_index_adjustment(c(0.05, 0.05, 0.02, -0.05), c(TRUE, FALSE, TRUE, TRUE), p_ii),
               c(0.04, 0.05, 0.02, -0.04))
})

test_that("Mietpreisbremse und Neuvertragsmiete (§§ 556d bis 556f)", {
  d <- as.Date(c("2028-01-01", "2030-01-01"))
  expect_identical(mr_brake_applies(TRUE, NA, d, FALSE, FALSE, p_cur), c(TRUE, FALSE))
  expect_identical(mr_brake_applies(TRUE, as.Date("2031-12-31"), d, FALSE, FALSE, p_cur),
                   c(TRUE, TRUE))
  expect_identical(mr_brake_applies(TRUE, NA, d[1], TRUE, FALSE, p_cur), FALSE)
  expect_identical(mr_brake_applies(TRUE, NA, d[1], FALSE, TRUE, p_cur), FALSE)
  expect_identical(mr_brake_applies(FALSE, NA, d[1], FALSE, FALSE, p_cur), FALSE)
  expect_equal(mr_relet_rent(11, 9, 9, 8, 0, TRUE, p_cur), 9.9)
  expect_equal(mr_relet_rent(11, 9, 9, 10.5, 0, TRUE, p_cur), 10.5)
  expect_equal(mr_relet_rent(11, 9.5, 8, 8, 2, TRUE, p_cur), 10.8)
  expect_equal(mr_relet_rent(11, 9, 9, 8, 0, FALSE, p_cur), 11)
})
