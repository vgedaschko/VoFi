# Tests für R/rules-co2kostaufg.R (WS-E; Spec 01 Teil B Abschnitt 3.7.4, Prüfwerte C-6, C-8 und
# Bio-Treppe).

pc <- co2_params(eop_lp_co2(), eop_lp_bio())

test_that("Vertragstests der Regeln des CO2KostAufG (Prüfkit 5.6)", {
  rl <- reg_list("rule")
  nm <- rl$name[grepl("^(co2_|bio_)", rl$name)]
  expect_length(nm, 5L)
  for (x in nm) expect_type_contract(x, "rule")
})

test_that("C-6: Stufengrenzen des Stufenmodells", {
  x <- c(11.999, 12.0, 16.999, 17.0, 31.9, 32.0, 51.99, 52.0)
  expect_equal(co2_stage_share(x, pc), c(0, 0.10, 0.10, 0.20, 0.40, 0.50, 0.80, 0.95))
  m <- matrix(c(5, 27.3, 60, 23.53), 2)
  out <- co2_stage_share(m, pc)
  expect_identical(dim(out), dim(m))
  expect_equal(out, matrix(c(0, 0.40, 0.95, 0.30), 2))
  expect_equal(co2_stage_share(c(30, NA), co2_params(NULL, NULL)), c(0, 0))
})

test_that("co2_params: Parameter und inaktive Themen", {
  expect_true(pc$active_co2)
  expect_true(pc$active_bio)
  expect_equal(pc$s5a_co2_from, as.Date("2028-01-01"))
  expect_equal(pc$s5a_bio_from, as.Date("2029-01-01"))
  expect_equal(c(pc$s5a_co2_share, pc$s5a_network_share, pc$s5a_bio_share, pc$s5a_bio_cap),
               c(0.5, 0.5, 0.5, 0.3))
  expect_equal(pc$s9_reduction_factor, 0.5)
  none <- co2_params(NULL, NULL)
  expect_false(isTRUE(none$active_co2))
  expect_false(isTRUE(none$active_bio))
})

test_that("C-8: Übergang bei Havarie und Härtefall § 5d", {
  d <- co2_s5a_dates(TRUE, as.Date(c("2027-06-01", "2027-06-01", "2026-12-01", "2027-06-01")),
                     c(TRUE, FALSE, TRUE, TRUE), c(FALSE, FALSE, FALSE, TRUE), pc)
  expect_equal(d$co2_from, as.Date(c("2029-01-01", "2028-01-01", "2028-01-01", NA)))
  expect_equal(d$network_from, as.Date(c("2029-01-01", "2028-01-01", "2028-01-01", NA)))
  # bio_from „analog“ je eigenem Termin: Einbau 2027-06-01 liegt vor 2029-01-01 − 12 Monate
  expect_equal(d$bio_from, as.Date(c("2029-01-01", "2029-01-01", "2029-01-01", NA)))
  # Einbau ab dem Beginn des § 5a: Havarie wirkungslos (3.2.2), keine Verschiebung (EOP-05)
  late <- co2_s5a_dates(TRUE, as.Date(c("2028-06-01", "2027-12-01", "2027-01-01")), TRUE, FALSE,
                        pc)
  expect_equal(late$co2_from, as.Date(c("2028-01-01", "2029-01-01", "2029-01-01")))
  expect_equal(late$network_from, as.Date(c("2028-01-01", "2029-01-01", "2029-01-01")))
  expect_equal(late$bio_from, as.Date(rep("2029-01-01", 3L)))
  off <- co2_s5a_dates(FALSE, as.Date("2027-06-01"), FALSE, FALSE, pc)
  expect_true(is.na(off$co2_from))
  expect_true(all(is.na(co2_s5a_dates(TRUE, as.Date("2027-06-01"), FALSE, FALSE,
                                      co2_params(NULL, NULL))$co2_from)))
})

test_that("§ 43 GModG: neue Heizung nach dem Stichtag im Bestand", {
  d <- as.Date(c("2027-10-01", "2026-05-01", "2027-10-01", "2027-10-01"))
  expect_identical(co2_section43(c("gas", "gas", "power", "oil"), d, TRUE, pc),
                   c(TRUE, FALSE, FALSE, TRUE))
  expect_identical(co2_section43("gas", as.Date("2027-10-01"), FALSE, pc), FALSE)
  # Thema bio_treppe inaktiv: bio_*-Parameter NULL, daher FALSE (3.7.4, EOP-05)
  no_bio <- co2_params(eop_lp_co2(), NULL)
  expect_identical(co2_section43("gas", as.Date("2027-10-01"), TRUE, no_bio), FALSE)
})

test_that("Bio-Treppe: Stufen 2029 bis 2040 und Reformcode stufe_2045", {
  y <- c(2028, 2029, 2030, 2034, 2035, 2040, 2045)
  expect_equal(bio_share_section43(y, pc), c(0, 0.10, 0.15, 0.15, 0.30, 0.60, 0.60))
  p45 <- co2_params(eop_lp_co2(), eop_lp_bio(stufe_2045 = TRUE))
  expect_equal(bio_share_section43(y, p45), c(0, 0.10, 0.15, 0.15, 0.30, 0.60, 1.00))
  m <- matrix(c(2029, 2035, 2040, 2045), 2)
  expect_equal(bio_share_section43(m, pc), matrix(c(0.10, 0.30, 0.60, 0.60), 2))
  expect_equal(bio_share_section43(y, co2_params(eop_lp_co2(), NULL)), rep(0, 7))
})
