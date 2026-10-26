# Tests für R/solve.R (WS-G; Spec 00 Abschnitte 12.8, 13.4, 13.6; Spec 01 Teil C 5.6, 6.5).

grob_scenario <- function() vofi_read_scenario(vofi_example("grob_lehrbuch_a"))

test_that("grob_lehrbuch_a: kritischer Restwert 36.273,59 und P(RW > x*) = 0,803210", {
  sol <- wsg_quiet(vofi_solve(grob_scenario(), param = "shared.rw", target = 0))
  expect_s3_class(sol, "vofi_solution")
  expect_identical(sol$what, "breakeven")
  expect_identical(sol$kpi, "delta_terminal_value")
  expect_identical(sol$target_source, "value")
  expect_equal(sol$value, 40000 - 3726.406978797153, tolerance = 1e-4)
  expect_lt(abs(sol$kpi_at_value), 1e-4)
  expect_equal(sol$prob_exceed, 1 - 6273.593021202847^2 / (20000 * 10000), tolerance = 1e-6)
  expect_equal(sol$interval, c(30000, 50000))
  expect_true(sol$monotone)
  expect_false(sol$jump)
  expect_false(sol$rebuild)
  expect_true(sol$iterations >= 0L)
  expect_null(sol$reference)
  expect_match(sol$message, "Kritischer Wert")
})

test_that("grob_lehrbuch_a: Zielrenditemiete roe_mirr = 6 % bei RW 41.642,14; Schwelle", {
  sol <- wsg_quiet(vofi_solve(grob_scenario(), what = "critical_value", param = "shared.rw",
                              kpi = "roe_mirr", target = 0.06))
  expect_equal(sol$value, 40000 + (30000 * 1.06^5 - 38504.629207797145), tolerance = 1e-4)
  expect_lt(abs(sol$kpi_at_value - 0.06), 1e-7)
  # Schwelle aus analysis.thresholds (Profil wu_privat: roe_hurdle 0,035)
  sol2 <- wsg_quiet(vofi_solve(grob_scenario(), param = "shared.rw", kpi = "roe_mirr",
                               target = "threshold:roe_hurdle"))
  expect_identical(sol2$target_source, "threshold:roe_hurdle")
  expect_equal(sol2$target, 0.035)
  expect_equal(sol2$value, 40000 + (30000 * 1.035^5 - 38504.629207797145), tolerance = 1e-4)
  expect_error(vofi_solve(grob_scenario(), param = "shared.rw", target = "threshold:gibts"),
               class = "vofi_error_input")
})

test_that("Liquiditäts-Break-even ohne Wechsel im Intervall: NA mit Hinweis (Teil C 6.5)", {
  sc <- grob_scenario()
  expect_message(suppressWarnings(vofi_solve(sc, param = "shared.rw",
                                             kpi = "min_net_liquidity", target = 0)),
                 "Kein kritischer Wert")
  sol <- wsg_quiet(vofi_solve(sc, param = "shared.rw", kpi = "min_net_liquidity", target = 0))
  expect_true(is.na(sol$value))
  expect_match(sol$message, "Kein kritischer Wert")
})

test_that("Monotonieprüfung: zwei Vorzeichenwechsel -> erster Wechsel, Warnung", {
  sc <- wsg_expr_scenario("100 * (shared.x1 * shared.x1 - 0.0625)", x1 = 0.5)
  expect_warning(sol <- wsg_quiet_lib(vofi_solve(sc, param = "shared.x1",
                                                 interval = c(-1, 1))),
                 class = "vofi_warning_plausibility")
  expect_false(sol$monotone)
  expect_equal(sol$value, -0.25, tolerance = 1e-6)
  # Nullstelle genau auf einer Stützstelle
  sc0 <- wsg_expr_scenario("100 * (shared.x1 - 0.2)", x1 = 0.5)
  sol0 <- wsg_quiet(vofi_solve(sc0, param = "shared.x1", interval = c(-1, 1)))
  expect_equal(sol0$value, 0.2, tolerance = 1e-8)
  expect_true(sol0$monotone)
})

test_that("Sprungstelle: Kennzahl springt über das Ziel (|f(x*)| > 1 EUR)", {
  sc <- wsg_expr_scenario("100 * (shared.x1 > 0.33) - 50", x1 = 0.5)
  sol <- wsg_quiet(vofi_solve(sc, param = "shared.x1", interval = c(-1, 1)))
  expect_true(sol$jump)
  expect_equal(sol$value, 0.33, tolerance = 1e-6)
  expect_match(sol$message, "Sprungstelle")
})

test_that("Default-Intervall: Basis x [0,5; 1,5]; Basis 0 ohne Verteilung ist ein Fehler", {
  sc <- wsg_expr_scenario("100 * (shared.x1 - 0.7)", x1 = 0.6)
  sol <- wsg_quiet(vofi_solve(sc, param = "shared.x1"))
  expect_equal(sol$interval, c(0.3, 0.9))
  expect_equal(sol$value, 0.7, tolerance = 1e-8)
  sc2 <- wsg_expr_scenario("100 * (shared.x1 - 0.7)", x1 = 0)
  expect_error(wsg_quiet(vofi_solve(sc2, param = "shared.x1")), class = "vofi_error_input")
  # Overlay mit apply multiply: Intervall = Basis x [min, max] der Ziehung
  sc3 <- wsg_expr_scenario("100 * (shared.x1 - 0.7)", x1 = 0.5,
                           parameters = list(f = list(target = "shared.x1", dist = "uniform",
                                                      min = 1, max = 2, apply = "multiply")))
  sol3 <- wsg_quiet(vofi_solve(sc3, param = "shared.x1"))
  expect_equal(sol3$interval, c(0.5, 1))
  expect_equal(sol3$prob_exceed, 1 - (0.7 / 0.5 - 1) / 1, tolerance = 1e-8)
})

test_that("rebuild = TRUE (Schicht 8) liefert denselben kritischen Restwert", {
  sol <- wsg_quiet(vofi_solve(grob_scenario(), param = "shared.rw", rebuild = TRUE,
                              kpi = "delta_terminal_value", interval = c(34000, 38000)))
  expect_true(sol$rebuild)
  expect_equal(sol$value, 40000 - 3726.406978797153, tolerance = 1e-3)
})

test_that("Vergleichskennzahl gegen die Referenz mit derselben Designmatrix", {
  sc <- wsg_expr_scenario("100 * shared.x1", x1 = 1)
  z_a <- list(0, 0, list(expr = "150 * shared.x1 - 25"))
  sc$variants <- wsg_variant_a(components.z.values = z_a)
  # delta_vs_reference(x) = 50 x - 25 = 0 bei x = 0,5
  sol <- wsg_quiet(vofi_solve(sc, param = "shared.x1", kpi = "delta_vs_reference",
                              variant = "a", reference = "base", interval = c(0, 2)))
  expect_equal(sol$value, 0.5, tolerance = 1e-8)
  expect_identical(sol$reference, "base")
  expect_error(vofi_solve(wsg_quiet(vofi_build(sc, variant = "a")), param = "shared.x1",
                          kpi = "delta_vs_reference"), class = "vofi_error_input")
  expect_error(wsg_quiet(vofi_solve(sc, param = "shared.x1", kpi = "delta_vs_reference",
                                    variant = "a", reference = "a")),
               class = "vofi_error_input")
})

test_that("Entnahme-Äquivalent mit der Toleranz des Aufrufs (12.8): 672,44", {
  ex <- oracle_expected("a")$kpis
  want <- ex$value[ex$kpi == "withdrawal_equivalent"]
  sol <- wsg_quiet(vofi_solve(grob_scenario(), what = "withdrawal_equivalent", tol = 1e-8))
  expect_identical(sol$what, "withdrawal_equivalent")
  expect_equal(sol$value, want, tolerance = 1e-7)
  expect_equal(sol$value, 672.44, tolerance = 0.005)
  expect_true(is.numeric(attr(sol, "value_ex_rv")))
  expect_true(sol$iterations > 0L)
})

test_that("Argumentprüfung und Ausgabe", {
  sc <- grob_scenario()
  expect_error(vofi_solve(sc), class = "vofi_error_input")
  expect_error(vofi_solve(sc, param = "shared.rw", tol = -1), class = "vofi_error_input")
  expect_error(vofi_solve(sc, param = "shared.rw", interval = c(2, 1)),
               class = "vofi_error_input")
  expect_error(vofi_solve(sc, param = "shared.rw", rebuild = NA), class = "vofi_error_input")
  expect_error(vofi_solve(sc, param = "shared.rw", target = list()), class = "vofi_error_input")
  expect_error(vofi_solve(1, param = "shared.rw"), class = "vofi_error_input")
  expect_error(wsg_quiet(vofi_solve(sc, what = "incremental_return")),
               class = "vofi_error_input")
  expect_error(wsg_quiet(vofi_solve(sc, param = "shared.rw", kpi = "gibts")),
               class = "vofi_error_input")
  sol <- wsg_quiet(vofi_solve(sc, param = "shared.rw"))
  out <- utils::capture.output(print(sol))
  expect_true(any(grepl("Break-even", out)))
  expect_true(any(grepl("shared.rw", out, fixed = TRUE)))
  expect_true(any(grepl("36.273", out, fixed = TRUE)))
  sol_na <- new_vofi_solution(list(what = "incremental_return", value = NA_real_,
                                   monotone = FALSE, jump = TRUE, rebuild = TRUE))
  out2 <- utils::capture.output(print(sol_na))
  expect_true(any(grepl("n. d.", out2, fixed = TRUE)))
  expect_true(any(grepl("Sprungstelle", out2)))
})
