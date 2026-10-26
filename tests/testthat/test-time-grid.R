# Tests für R/time-grid.R (Integrator; Spec 00 Abschnitt 3, Testfälle 3.8).

test_that("G1 Jahresraster: 2027-01-01, H = 30, C = 0", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 30)
  expect_s3_class(g, "vofi_grid")
  expect_identical(g$T, 30L)
  expect_identical(g$months, c(0L, rep(12L, 30)))
  expect_identical(g$label, c("t0", as.character(2027:2056)))
  expect_identical(grid_period_of_year(g, 2030)[1], 3L)
  expect_identical(g$t, 0:30)
  expect_equal(g$tau, 0:30)
  expect_identical(g$end_date, as.Date("2057-01-01"))
  expect_identical(g$completion_date, as.Date("2027-01-01"))
  expect_true(all(g$phase == "operation"))
  expect_identical(g$op_year, 0:30)
  expect_identical(g$op_year_full, c(FALSE, rep(TRUE, 30)))
  expect_identical(g$years, 2027:2056)
  expect_identical(g$year, c(2027L, 2027:2056))
})

test_that("G2 Neubau j\u00e4hrlich: H = 40, C = 24", {
  g <- vofi_time_grid("2027-01-01", 40, construction_months = 24)
  expect_identical(g$T, 40L)
  expect_identical(g$phase[1:4], c("construction", "construction", "construction", "operation"))
  expect_true(all(g$phase[-(1:3)] == "operation"))
  expect_identical(g$op_year[4], 1L)
  expect_identical(g$op_year[2:3], c(0L, 0L))
  expect_identical(g$completion_date, as.Date("2029-01-01"))
})

test_that("G3 Orakel (e): periods_months, C = 12", {
  g <- vofi_time_grid("2027-01-01", NULL, construction_months = 12,
                      periods_months = c(3, 3, 3, 3, 12, 12, 12))
  expect_identical(g$T, 7L)
  expect_equal(g$tau, c(0, .25, .5, .75, 1, 2, 3, 4))
  expect_identical(g$phase[2:5], rep("construction", 4))
  expect_identical(g$phase[6:8], rep("operation", 3))
  expect_identical(g$label, c("t0", "Q1/2027", "Q2/2027", "Q3/2027", "Q4/2027", "2028", "2029",
                              "2030"))
  expect_identical(g$settings$periods_months, c(3L, 3L, 3L, 3L, 12L, 12L, 12L))
})

test_that("G3: periods_months mit abweichendem horizon_years gibt einen Hinweis", {
  local_vofi_options(vofi.verbose = TRUE)
  expect_message(vofi_time_grid("2027-01-01", 5, periods_months = c(12, 12)),
                 class = "vofi_message")
})

test_that("G4 Bauphase monatlich, calendar", {
  g <- vofi_time_grid("2027-01-01", 30, construction_months = 9, construction_step_months = 1,
                      operation_alignment = "calendar")
  expect_identical(g$months, c(0L, rep(1L, 9), 3L, rep(12L, 29)))
  expect_identical(g$T, 39L)
  expect_identical(g$end_date, as.Date("2057-01-01"))
  expect_true(all(g$op_year[2:10] == 0L))
  expect_identical(g$op_year[11], 1L)
  expect_false(g$op_year_full[11])
  expect_identical(g$op_year[12], 2L)
  expect_true(g$op_year_full[12])
  expect_identical(g$label[11], "Q4/2027")
  expect_identical(g$label[2], "01/2027")
  expect_identical(g$phase[10], "construction")
  expect_identical(g$phase[11], "operation")
})

test_that("G5 Betrieb ab Fertigstellung", {
  g <- vofi_time_grid("2027-01-01", 30, construction_months = 9, construction_step_months = 3,
                      operation_alignment = "completion")
  expect_identical(g$months, c(0L, 3L, 3L, 3L, rep(12L, 29), 3L))
  expect_identical(g$T, 33L)
  expect_identical(g$op_year[5], 1L)
  expect_true(g$op_year_full[5])
  expect_false(g$op_year_full[g$T + 1L])
  expect_identical(g$months[g$T + 1L], 3L)
  expect_identical(g$label[5], "2027/28")
  expect_identical(g$end_date, as.Date("2057-01-01"))
})

test_that("Raster: Fehler bei ung\u00fcltigen Eingaben", {
  expect_error(vofi_time_grid("2027-01-15", 10), class = "vofi_error_input")
  expect_error(vofi_time_grid("2027-13-01", 10), class = "vofi_error_input")
  expect_error(vofi_time_grid("2027-01-01", 10, construction_step_months = 2),
               class = "vofi_error_input")
  expect_error(vofi_time_grid("2027-01-01", 10, operation_step_months = 6),
               class = "vofi_error_input")
  expect_error(vofi_time_grid("2027-01-01", 2, construction_months = 24),
               class = "vofi_error_input")
  expect_error(vofi_time_grid("2027-01-01", 0), class = "vofi_error_input")
  expect_error(vofi_time_grid("2027-01-01", 10, operation_alignment = "x"),
               class = "vofi_error_input")
  expect_error(vofi_time_grid("2027-01-01", NULL), class = "vofi_error_input")
  expect_error(vofi_time_grid("2027-01-01", NULL, periods_months = c(3, 0)),
               class = "vofi_error_input")
  expect_error(vofi_time_grid("2027-01-01", 10, start_year = 2030), class = "vofi_error_input")
})

test_that("Raster: start_year bestimmt years; festes Horizontende bei abweichender Bauzeit", {
  g <- vofi_time_grid("2027-01-01", 5, start_year = 2025)
  expect_identical(g$years, 2025:2031)
  a <- vofi_time_grid("2027-01-01", 30, construction_months = 9, construction_step_months = 1)
  b <- vofi_time_grid("2027-01-01", 30, construction_months = 18, construction_step_months = 3)
  expect_identical(a$end_date, b$end_date)
})

test_that("Stichtag au\u00dferhalb Januar: Kalenderausrichtung und Labels", {
  g <- vofi_time_grid("2027-04-01", 3, construction_months = 0, construction_step_months = 1)
  expect_identical(g$months, c(0L, 9L, 12L, 12L, 3L))
  expect_identical(g$label[2], "04-12/2027")
  g12 <- vofi_time_grid("2027-04-01", 2)
  expect_identical(g12$label, c("t0", "2027/28", "2028/29"))
})

test_that("grid_period_of: Zuordnung nach 3.4", {
  g <- vofi_time_grid("2027-01-01", 3)
  d <- as.Date(c("2027-01-01", "2027-06-30", "2028-01-01", "2028-01-02", "2030-01-01",
                 "2030-01-02", "2026-12-31", NA))
  p <- grid_period_of(g, d)
  expect_identical(as.vector(p), c(0L, 1L, 1L, 2L, 3L, NA, NA, NA))
  expect_identical(attr(p, "before"), c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE))
  expect_identical(as.vector(grid_period_of_year(g, c(2027, 2028, 2031))), c(0L, 1L, NA))
})

test_that("Formen: by_sim, by_period, zeros", {
  g <- vofi_time_grid("2027-01-01", 6)
  expect_identical(dim(grid_by_sim(g, c(1, 2, 3))), c(3L, 7L))
  expect_identical(grid_by_sim(g, 5, 2)[2, 7], 5)
  m <- grid_by_period(g, 0:6, 7)
  expect_identical(dim(m), c(7L, 7L))
  expect_identical(m[7, ], as.double(0:6))
  expect_error(grid_by_period(g, 1:3), class = "vofi_error_contract")
  expect_error(grid_by_sim(g, 1:3, n = 2), class = "vofi_error_contract")
  expect_identical(grid_zeros(g, 2), matrix(0, 2, 7))
})

test_that("Raten: effektiv, nominal, Periodenbetrag (3.6)", {
  g <- make_grid("oracle_e")
  r <- grid_rate_eff(g, 0.025)
  expect_identical(r[1, 1], 0)
  expect_equal(r[1, 2], 0.0061922463, tolerance = 1e-7)
  expect_equal(r[1, 6], 0.025)
  expect_equal(grid_rate_nom(g, 0.036)[1, ], 0.036 * g$delta)
  expect_equal(grid_per_period(g, c(1200, 2400))[2, ], 2400 * g$delta)
  rm <- matrix(c(0.02, 0.03), 2, 8)
  expect_equal(grid_rate_eff(g, rm)[2, 6], 0.03)
  expect_error(grid_rate_eff(g, matrix(0.02, 1, 3)), class = "vofi_error_contract")
})

test_that("grid_index: Periodenende, base_date nach und vor dem Stichtag", {
  g <- vofi_time_grid("2027-01-01", 10)
  expect_equal(grid_index(g, 0.02)[1, ], 1.02^(0:10))
  expect_equal(grid_index(g, 0.02, base_date = as.Date("2028-01-01"))[1, ], 1.02^((0:10) - 1))
  expect_equal(grid_index(g, 0.02, base_date = as.Date("2027-01-01"))[1, ], 1.02^(0:10))
  mid <- grid_index(g, 0.02, base_date = as.Date("2027-07-01"))
  expect_equal(mid[1, 2], 1.02^0.5)
  local_vofi_options(vofi.verbose = FALSE)
  pre <- grid_index(g, 0.02, base_date = as.Date("2025-01-01"))
  expect_equal(pre[1, 1:3], 1.02^(2:4))
  gg <- structure(0.02, annual_before = matrix(c(0.05, 0.04), 1, dimnames = list(NULL,
                                                                          c("2025", "2026"))))
  pre2 <- grid_index(g, gg, base_date = as.Date("2025-01-01"))
  expect_equal(pre2[1, 1], 1.05 * 1.04)
})

test_that("grid_index: Meldung, wenn Jahreswerte vor dem Stichtag fehlen", {
  g <- vofi_time_grid("2027-01-01", 3)
  local_vofi_options(vofi.verbose = TRUE)
  expect_message(grid_index(g, structure(0.02, path = "market.x"), base_date = "2026-01-01"),
                 "market.x")
})

test_that("grid_index_year: Orakel (b) und Pr\u00fcfwert F10 (3.6, 7.12)", {
  g <- vofi_time_grid("2027-01-01", 10)
  iy <- grid_index_year(g, 0.02, base_date = as.Date("2028-01-01"))
  expect_equal(iy[1, -1], 1.02^((2:11) - 2))
  expect_equal(iy[1, 1], iy[1, 2])
  ga <- reg_test_grid("annual")
  gm <- reg_test_grid("mixed")
  va <- 14000 * grid_index_year(ga, 0.02, as.Date("2027-01-01")) * grid_by_period(ga, ga$delta)
  vm <- 14000 * grid_index_year(gm, 0.02, as.Date("2027-01-01")) * grid_by_period(gm, gm$delta)
  sum_year <- function(v, g, y) sum(v[1, -1][g$year[-1] == y])
  expect_equal(sum_year(va, ga, 2027), 14280)
  expect_equal(sum_year(vm, gm, 2027), 14280)
  for (y in 2027:2032) expect_equal(sum_year(va, ga, y), sum_year(vm, gm, y))
  ve <- 14000 * grid_index(gm, 0.02) * grid_by_period(gm, gm$delta)
  expect_equal(sum_year(ve, gm, 2027), 14157.09, tolerance = 1e-6)
  # Pfad je Kalenderjahr: Rate des Jahres aus der ersten Periode des Jahres
  gp <- grid_index_year(ga, matrix(c(0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.06), 1),
                        as.Date("2027-01-01"))
  expect_equal(gp[1, 3], 1.01 * 1.02)
})

test_that("grid_overlap: Anteile der Monate je Periode", {
  gm <- reg_test_grid("mixed")
  o <- grid_overlap(gm, as.Date("2027-10-01"))
  expect_identical(length(o), gm$T + 1L)
  expect_equal(o, c(rep(0, 10), rep(1, 6)))
  ga <- reg_test_grid("annual")
  expect_equal(grid_overlap(ga, as.Date("2027-07-01"), as.Date("2029-04-01")),
               c(0, 0.5, 1, 0.25, 0, 0, 0))
  expect_equal(grid_overlap(ga), c(0, rep(1, 6)))
})

test_that("R-98: Daten ohne Monatsersten wirken ab dem folgenden Monatsersten", {
  ga <- reg_test_grid("annual")
  gm <- reg_test_grid("mixed")
  expect_equal(grid_overlap(ga, as.Date("2027-01-15"))[2], 11 / 12)
  expect_equal(grid_overlap(ga, as.Date("2027-01-01"), as.Date("2027-06-15"))[2], 6 / 12)
  expect_equal(grid_overlap(ga, as.Date("2027-01-02"), as.Date("2027-07-01"))[2], 5 / 12)
  so <- grid_shift_overlap(ga, as.Date("2027-01-15"), c(0, 2), to = as.Date("2028-03-10"))
  expect_equal(so[, 2], c(11, 9) / 12)
  expect_equal(so[, 3], c(3, 3) / 12)
  # eine Regel fuer alle Typen: Periodenanteile = summierte aktive Monate
  for (g in list(ga, gm)) {
    for (d in c("2027-01-15", "2027-03-31", "2027-10-01", "2028-02-29")) {
      sm <- grid_shift_months(g, as.Date(d), c(0, 1, 7), to = as.Date("2031-06-20"))
      so <- grid_shift_overlap(g, as.Date(d), c(0, 1, 7), to = as.Date("2031-06-20"))
      expect_equal(grid_to_periods(g, sm), so * matrix(g$months, 3, g$T + 1L, byrow = TRUE),
                   info = d)
      expect_equal(so[1, ], grid_overlap(g, as.Date(d), as.Date("2031-06-20")), info = d)
    }
  }
})

test_that("Monatsaufl\u00f6sung: grid_months, to_periods, to_months", {
  gm <- reg_test_grid("mixed")
  mt <- grid_months(gm)
  expect_identical(nrow(mt), 72L)
  expect_identical(mt$period[1:12], c(1:9, 10L, 10L, 10L))
  expect_identical(mt$date_start[10], as.Date("2027-10-01"))
  x <- matrix(1, 2, 72)
  p <- grid_to_periods(gm, x)
  expect_identical(dim(p), c(2L, 16L))
  expect_equal(p[1, ], c(0, rep(1, 9), 3, rep(12, 5)))
  per <- matrix(seq_len(16), 1)
  rep_m <- grid_to_months(gm, per, "repeat")
  expect_identical(rep_m[1, 10:12], c(11, 11, 11))
  spr <- grid_to_months(gm, per, "spread")
  expect_equal(grid_to_periods(gm, spr)[1, -1], as.double(2:16))
  expect_error(grid_to_periods(gm, matrix(1, 1, 10)), class = "vofi_error_contract")
})

test_that("grid_map_years: Prozess in Kalenderjahren auf das Raster", {
  gm <- reg_test_grid("mixed")
  xy <- matrix(seq_along(gm$years), 2, length(gm$years), byrow = TRUE)
  m <- grid_map_years(gm, xy)
  expect_identical(dim(m), c(2L, 16L))
  expect_equal(m[1, ], as.double(gm$year - 2026))
  expect_error(grid_map_years(gm, matrix(1, 1, 2)), class = "vofi_error_contract")
})

test_that("Verschiebungen: shift_period, shift_overlap, shift_months (3.9)", {
  g <- reg_test_grid("annual")
  expect_identical(grid_shift_period(g, as.Date("2027-06-01"), c(0, 7.4, 7.6, 100)),
                   c(1L, 1L, 2L, NA))
  so <- grid_shift_overlap(g, as.Date("2027-01-01"), c(0, 6, 12))
  expect_identical(dim(so), c(3L, 7L))
  expect_equal(so[2, 1:3], c(0, 0.5, 1))
  expect_equal(so[3, 2], 0)
  sm <- grid_shift_months(g, as.Date("2027-01-01"), c(0, 3), to = as.Date("2028-01-01"))
  expect_identical(dim(sm), c(2L, 72L))
  expect_identical(sum(sm[1, ]), 12)
  expect_identical(sum(sm[2, ]), 9)
})

test_that("print und as.data.frame", {
  g <- vofi_time_grid("2027-01-01", 3)
  df <- as.data.frame(g)
  expect_identical(names(df), c("t", "label", "date_start", "date_end", "months", "delta",
                                "tau", "year", "phase", "op_year", "op_year_full"))
  expect_identical(nrow(df), 4L)
  out <- capture.output(print(g))
  expect_match(out[1], "Zeitraster")
  expect_match(out[1], "01.01.2027")
  g40 <- vofi_time_grid("2027-01-01", 40)
  expect_true(any(grepl("weitere", capture.output(print(g40, n = 5)))))
})

test_that("grid_add_months begrenzt den Tag auf das Monatsende", {
  expect_identical(grid_add_months(as.Date("2027-01-31"), 1), as.Date("2027-02-28"))
  expect_identical(grid_add_months(as.Date("2027-12-01"), c(1, -12)),
                   as.Date(c("2028-01-01", "2026-12-01")))
  expect_identical(grid_months_between(as.Date("2027-10-01"), as.Date("2029-01-01")), 15L)
})
