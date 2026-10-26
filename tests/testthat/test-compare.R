# Tests für R/compare.R (WS-G; Spec 00 Abschnitte 4.11, 9.6, 9.11, 11.10, 12.6, 12.9, 13.3,
# 15.3 (g), 15.4 V1, 15.6; Spec 01 Teil C 4.3, 4.4, 6.6).

test_that("Vergleichskennzahlen als Registry-Typen (12.6): Vertrag, Einheit, Restwertbezug", {
  for (nm in c("delta_vs_reference", "prob_better_than_ref")) {
    expect_true(reg_has("kpi", nm), info = nm)
    expect_type_contract(nm, "kpi")
  }
  expect_identical(kpi_unit("delta_vs_reference"), "EUR")
  expect_identical(kpi_unit("prob_better_than_ref"), "share")
  expect_true(reg_get("kpi", "delta_vs_reference")$rv_variant)
  expect_identical(kpi_rv_info("prob_better_than_ref"), list(class = "with",
                                                             note = NA_character_))
  core <- example_core(n = 3L)
  v <- reg_get("kpi", "delta_vs_reference")$compute(core, NULL)
  expect_true(all(is.na(v$values)))
  expect_identical(unique(v$na_reason), "not_computed")
})

test_that("Orakel (g): Vergleichsregel, Vergleichbarkeit trotz ungleicher Nachschüsse", {
  sc <- oracle_scenario("g")
  cmp <- wsg_quiet(vofi_compare(sc, variants = "a", baseline = "base"))
  expect_s3_class(cmp, "vofi_comparison")
  expect_identical(cmp$baseline, "base")
  expect_identical(cmp$variants, "a")
  expect_true(cmp$crn)
  dvr <- cmp$differences$delta_vs_reference
  expect_identical(dim(dvr), c(1L, 1L))
  expect_identical(colnames(dvr), "a")
  expect_equal(unname(dvr[1L, "a"]), -80, tolerance = 1e-9)
  expect_equal(unname(dvr[1L, "a"]), (16000 - 13020) - 3000 * 1.02, tolerance = 1e-9)
  expect_equal(unname(cmp$differences$delta_vs_reference_ex_rv[1L, "a"]), -80,
               tolerance = 1e-9)
  ra <- cmp$results$a
  expect_equal(ra$kpis$delta_vs_reference, -80, tolerance = 1e-9)
  expect_identical(ra$kpis$prob_better_than_ref, 0)
  expect_identical(ra$kpis$sum_equity_calls, 3000)
  expect_false(any(cmp$comparability$severity == "error"))
  expect_s3_class(cmp$comparability, "vofi_validation")
  # Ranking: Referenz (0) vor a (-80)
  expect_identical(cmp$ranking$variant, c("base", "a"))
  expect_identical(cmp$ranking$criterion[1L], "delta_vs_reference")
  # Ampel ohne Robustheitsprüfung (Basis base_only): P <= 0 -> red
  expect_identical(cmp$traffic_light$variant, "a")
  expect_identical(cmp$traffic_light$basis, "base_only")
  expect_identical(cmp$traffic_light$level, "red")
  expect_true(all(c("variant", "scenario_set", "kpi", "value") %in% names(cmp$kpi_table)))
  expect_equal(cmp$kpi_table$value[cmp$kpi_table$variant == "a" &
                                     cmp$kpi_table$kpi == "delta_vs_reference"], -80,
               tolerance = 1e-9)
  ds <- cmp$diff_stats
  expect_identical(ds$prob_better[ds$kpi == "delta_vs_reference"], 0)
  expect_true(is.na(ds$se[ds$kpi == "delta_vs_reference"]))
  # Identität (Orakel (g)): dvr = EW_A - EW_ref - Sum (NS^A - NS^ref) q_T / q_t
  expect_equal(unname(dvr[1L, "a"]),
               ra$kpis$terminal_value - cmp$results$base$kpis$terminal_value -
                 3000 * 1.02, tolerance = 1e-9)
  # Payback gegenüber der Referenz und Rendite der Mehrinvestition stehen im Ergebnis
  expect_true(all(c("payback_vs_reference", "payback_vs_reference_ex_rv",
                    "incremental_return", "incremental_return_ex_rv", "co2_abatement_cost") %in%
                    names(ra$kpis)))
  expect_identical(names(ra$kpi_na), names(ra$kpis))
})

test_that("Argumente: unbekannte Varianten und Sets, keine Variante, kein Szenario", {
  sc <- oracle_scenario("g")
  expect_error(vofi_compare(list()), class = "vofi_error_input")
  expect_error(vofi_compare(sc, variants = "zz"), class = "vofi_error_input")
  expect_error(vofi_compare(sc, baseline = "zz"), class = "vofi_error_input")
  expect_error(vofi_compare(sc, variants = "base"), class = "vofi_error_input")
  expect_error(vofi_compare(sc, scenario_sets = "gibts_nicht"), class = "vofi_error_input")
  expect_error(vofi_compare(sc, n_sim = 0L), class = "vofi_error_input")
  expect_error(vofi_compare(sc, allow_unequal = "ja"), class = "vofi_error_input")
})

test_that("Vergleichbarkeit (9.6 Nr. 2): Konten, EK-Zeilen, Horizont; allow_unequal", {
  base_sc <- function(variant_set) {
    wsg_scenario(variants = list(a = list(label = "A", set = variant_set)))
  }
  sc <- base_sc(list(accounts.deposit_rate_pa = 0.03))
  e <- tryCatch(wsg_quiet(vofi_compare(sc)), vofi_error_validation = identity)
  expect_s3_class(e, "vofi_error_validation")
  expect_true("mc.comparability.accounts" %in% e$data$report$code)
  expect_warning(cmp <- wsg_quiet_lib(vofi_compare(sc, allow_unequal = TRUE)),
                 class = "vofi_warning_plausibility")
  expect_true(any(cmp$comparability$severity == "warning" &
                    cmp$comparability$code == "mc.comparability.accounts"))
  expect_identical(cmp$meta$allow_unequal, TRUE)
  sc2 <- base_sc(list(financing.ek.amount_eur = 50000))
  e2 <- tryCatch(wsg_quiet(vofi_compare(sc2)), vofi_error_validation = identity)
  expect_true("mc.comparability.equity" %in% e2$data$report$code)
  sc3 <- base_sc(list(project.horizon_years = 6L,
                      components.z.values = c(-100000, rep(9000, 5), 30000)))
  e3 <- tryCatch(wsg_quiet(vofi_compare(sc3)), vofi_error_validation = identity)
  expect_true("mc.comparability.end_date" %in% e3$data$report$code)
  sc4 <- base_sc(list(residual_value.method = "income_value"))
  e4 <- tryCatch(wsg_quiet(vofi_compare(sc4)), error = identity)
  expect_s3_class(e4, "vofi_error_validation")
})

test_that("Rendite der Mehrinvestition (12.8): g(h*) = 0 für Zuwachs -10.000 / +11.000", {
  za <- c(-110000, 20000, 9000, 9000, 9000, 9000)
  sc <- wsg_scenario(loan = FALSE, flows = c(-100000, 9000, 9000, 9000, 9000), final = 9000,
                     variants = wsg_variant_a(components.z.values = za))
  sc$financing$ek$amount_eur <- 120000
  cmp <- wsg_quiet(vofi_compare(sc))
  ra <- cmp$results$a
  expect_equal(ra$kpis$incremental_return, 0.10, tolerance = 1e-7)
  expect_equal(ra$kpis$incremental_return_ex_rv, 0.10, tolerance = 1e-7)
  # delta_vs_reference bei 2 %: -10.000 * 1,02^5 + 11.000 * 1,02^4
  expect_equal(ra$kpis$delta_vs_reference, -10000 * 1.02^5 + 11000 * 1.02^4,
               tolerance = 1e-6)
  sol <- wsg_quiet(vofi_solve(sc, what = "incremental_return", variant = "a"))
  expect_s3_class(sol, "vofi_solution")
  expect_equal(sol$value, 0.10, tolerance = 1e-7)
  expect_lt(abs(sol$kpi_at_value), 1e-4)
  expect_identical(sol$reference, "base")
  expect_identical(sol$param, "accounts.deposit_rate_pa")
  expect_equal(attr(sol, "value_ex_rv"), 0.10, tolerance = 1e-7)
})

test_that("CRN in der MC: Differenzen je Lauf = getrennte Simulationen mit gleichem Seed", {
  st <- list(settings = list(seed = 13L, block_size = 200L),
             parameters = list(f = list(target = "shared.f", dist = "triangular", min = 20000,
                                        mode = 30000, max = 45000),
                               zins = list(target = "financing.bank.rate_pa",
                                           dist = "uniform", min = 0.03, max = 0.05)))
  za <- list(-100000, 12000, 9000, 9000, 9000, list(ref = "shared.f"))
  sc <- wsg_scenario(shared = list(f = 30000), final = list(ref = "shared.f"), stochastic = st,
                     variants = wsg_variant_a(components.z.values = za))
  cmp <- wsg_quiet(vofi_compare(sc, n_sim = 400L, seed = 13L, store = "kpi"))
  expect_identical(cmp$meta$mode, "mc")
  expect_s3_class(cmp$results$a, "vofi_mc_result")
  dvr <- cmp$differences$delta_vs_reference
  expect_identical(dim(dvr), c(400L, 1L))
  ma <- wsg_quiet(vofi_build(sc, variant = "a"))
  mb <- wsg_quiet(vofi_build(sc))
  a <- wsg_quiet(vofi_mc(ma, n_sim = 400L, seed = 13L, store = "kpi"))
  b <- wsg_quiet(vofi_mc(mb, n_sim = 400L, seed = 13L, store = "kpi"))
  expect_equal(dvr[, "a"], a$kpis$delta_terminal_value - b$kpis$delta_terminal_value,
               tolerance = 1e-9)
  expect_identical(cmp$results$a$inputs$f, a$inputs$f)
  ds <- cmp$diff_stats[cmp$diff_stats$kpi == "delta_vs_reference", ]
  expect_equal(ds$mean, mean(dvr[, "a"]))
  expect_equal(ds$prob_better, mean(dvr[, "a"] > 0))
  expect_equal(ds$q50, stats::quantile(dvr[, "a"], 0.5, type = 7, names = FALSE))
  expect_false(is.na(ds$se))
  st_a <- cmp$results$a$stats
  expect_equal(st_a$mean[st_a$kpi == "prob_better_than_ref"], mean(dvr[, "a"] > 0))
  expect_equal(st_a$deterministic[st_a$kpi == "delta_vs_reference"],
               cmp$results$a$deterministic$kpis$delta_vs_reference)
  expect_identical(cmp$traffic_light$basis, "mc")
  expect_true(all(cmp$results$a$kpi_na$incremental_return == "not_computed"))
  expect_false(is.na(cmp$results$a$deterministic$kpis$incremental_return) &&
                 FALSE)
  # Rangfolge nach mittlerem delta_vs_reference
  expect_identical(cmp$ranking$value[cmp$ranking$variant == "a"], mean(dvr[, "a"]))
})

test_that("Statische Szenario-Sets: Kreuzung mit jeder Variante, Referenz unter dem Set", {
  sc <- wsg_scenario(variants = wsg_variant_a(components.z.values = wsg_z_a))
  sc$scenario_sets <- list(zins = list(label = "Zins hoch",
                                       set = list(accounts.deposit_rate_pa = 0.04)))
  cmp <- wsg_quiet(vofi_compare(sc, scenario_sets = "zins"))
  expect_setequal(names(cmp$results), c("base", "a", "base@zins", "a@zins"))
  expect_identical(colnames(cmp$differences$delta_vs_reference), c("a", "a@zins"))
  ref_z <- cmp$results[["base@zins"]]
  a_z <- cmp$results[["a@zins"]]
  expect_equal(unname(cmp$differences$delta_vs_reference[1L, "a@zins"]),
               a_z$kpis$delta_terminal_value - ref_z$kpis$delta_terminal_value,
               tolerance = 1e-9)
  expect_identical(a_z$meta$scenario_set, "zins")
  expect_identical(cmp$scenario_sets, "zins")
  expect_true(all(cmp$meta$cases$reference[cmp$meta$cases$scenario_set %in% "zins"] ==
                    "base@zins"))
})

test_that("Set „vorsichtig“ (Teil C 4.3 (v1)): Swings 16 / 8 / 1,6; KPI 88 bzw. 87,2", {
  sc <- wsg_linear_scenario()
  m <- wsg_quiet(vofi_build(sc))
  cz <- wsg_quiet(cmp_cautious(m, NULL, gen = list(n_drivers = 2L, probs = c(0.1, 0.9)),
                               kpi = "delta_terminal_value"))
  tor <- cz$tornado$results
  expect_identical(tor$param, c("x1", "x2", "x3"))
  expect_equal(tor$swing, c(16, 8, 1.6), tolerance = 1e-9)
  expect_equal(cz$tornado$base_value, 100, tolerance = 1e-9)
  expect_identical(cz$drivers$param, c("x1", "x2"))
  expect_equal(cz$drivers$value, c(-0.8, 0.8), tolerance = 1e-12)
  expect_identical(cz$drivers$side, c("low", "high"))
  expect_equal(cz$value, 88, tolerance = 1e-9)
  expect_s3_class(cz$result, "vofi_result")
  expect_identical(cz$result$meta$scenario_set, "vorsichtig")
  expect_identical(cz$result$meta$mode, "design")
  expect_true(any(grepl("x1", cz$result$meta$notes)))
  cz5 <- wsg_quiet(cmp_cautious(m, NULL, gen = list(n_drivers = 5L), kpi = NULL))
  expect_equal(cz5$value, 87.2, tolerance = 1e-9)
  # vierter Schlüssel ohne Wirkung: unverändert (Ausschlag 0 ausgeschlossen)
  m4 <- wsg_quiet(vofi_build(wsg_linear_scenario(with_x4 = TRUE)))
  cz4 <- wsg_quiet(cmp_cautious(m4, NULL, gen = list(n_drivers = 5L)))
  expect_equal(cz4$value, 87.2, tolerance = 1e-9)
  expect_false("x4" %in% cz4$drivers$param)
  # exclude: Kandidat ausgeschlossen, der nächste rückt nach
  cze <- wsg_quiet(cmp_cautious(m, NULL, gen = list(n_drivers = 2L, exclude = "x1")))
  expect_identical(cze$drivers$param, c("x2", "x3"))
  expect_equal(cze$value, 100 - 4 - 0.8, tolerance = 1e-9)
  # Tornado identisch zu vofi_sensitivity(method = "tornado", probs = c(0.1, 0.9))
  tor2 <- wsg_quiet(vofi_sensitivity(m, kpi = "delta_terminal_value"))
  expect_equal(tor2$results$swing, tor$swing, tolerance = 1e-12)
})

test_that("Set „vorsichtig“ ohne Overlay: keine Treiber, Hinweis, Ampel ohne cautious", {
  sc <- wsg_scenario(variants = wsg_variant_a(components.z.values = wsg_z_a))
  expect_message(cz <- cmp_cautious(wsg_quiet(vofi_build(sc, variant = "a")),
                                    wsg_quiet(vofi_build(sc)), gen = list(),
                                    kpi = "delta_vs_reference"),
                 class = "vofi_message")
  expect_null(cz$result)
  cmp <- wsg_quiet(vofi_compare(sc, scenario_sets = "vorsichtig"))
  expect_identical(cmp$traffic_light$basis, "base_only")
  expect_false("a@vorsichtig" %in% names(cmp$results))
})

test_that("vofi_compare mit Set „vorsichtig“: Designzeile auf Variante und Referenz, Ampel", {
  sc <- wsg_linear_scenario()
  sc$variants <- list(a = list(label = "A", set = list(shared.x3 = 0.5)))
  cmp <- wsg_quiet(vofi_compare(sc, scenario_sets = "vorsichtig"))
  expect_true("a@vorsichtig" %in% names(cmp$results))
  rv <- cmp$results[["a@vorsichtig"]]
  expect_identical(rv$meta$scenario_set, "vorsichtig")
  # delta_vs_reference = 0,5 im Basisfall; die Designzeile auf beiden Modellen lässt ihn
  # unverändert (x3 ist in a fest gesetzt, die Treiber wirken auf beide gleich)
  expect_equal(unname(cmp$differences$delta_vs_reference[1L, "a"]), 0.5, tolerance = 1e-9)
  expect_identical(cmp$traffic_light$basis[cmp$traffic_light$variant == "a"], "cautious")
  inf <- cmp$meta$cautious[["a@vorsichtig"]]
  expect_true(is.data.frame(inf$drivers))
})

test_that("Ampel (12.9, Teil C 6.6): Prüffälle A1 bis A12", {
  thr <- list(green_prob = 0.70, red_prob = 0.40, restriction_prob = 0.30)
  mcv <- function(p, med = 1200, n = 100L) {
    k <- round(p * n)
    c(rep(-100, n - k), rep(med, k))
  }
  r <- function(code, vb, prob) {
    data.frame(code = code, violated_base = vb, prob = prob, stringsAsFactors = FALSE)
  }
  a1 <- cmp_traffic_light_core(500, 400, mc = mcv(0.75), thresholds = thr)
  expect_identical(c(a1$level, a1$stage1, a1$basis), c("green", "green", "mc"))
  expect_false(a1$rv_dependent)
  a2 <- cmp_traffic_light_core(500, -400, mc = mcv(0.75), thresholds = thr)
  expect_identical(a2$level, "yellow")
  expect_true(a2$rv_dependent)
  expect_true(any(grepl("Restwert", a2$notes)))
  expect_identical(cmp_traffic_light_core(500, 500, mc = mcv(0.55), thresholds = thr)$level,
                   "yellow")
  expect_identical(cmp_traffic_light_core(500, 500, mc = mcv(0.35), thresholds = thr)$level,
                   "red")
  a5 <- cmp_traffic_light_core(500, 500, mc = mcv(0.80), restrictions = r("dscr", FALSE, 0.31),
                               thresholds = thr)
  expect_identical(c(a5$stage1, a5$level), c("green", "yellow"))
  expect_true(a5$restrictions$ko)
  a6 <- cmp_traffic_light_core(500, 500, mc = mcv(0.80), restrictions = r("burden", TRUE, 0),
                               thresholds = thr)
  expect_identical(a6$level, "yellow")
  expect_true(a6$restrictions$ko)
  a7 <- cmp_traffic_light_core(500, 500, p_cautious = 10, thresholds = thr)
  expect_identical(c(a7$level, a7$basis), c("green", "cautious"))
  a8 <- cmp_traffic_light_core(500, 500, p_cautious = -10, thresholds = thr)
  expect_identical(a8$level, "yellow")
  expect_identical(cmp_traffic_light_core(-5, -5, p_cautious = -10, thresholds = thr)$level,
                   "red")
  a9 <- cmp_traffic_light_core(500, 500, thresholds = thr)
  expect_identical(c(a9$level, a9$basis), c("yellow", "base_only"))
  expect_true(any(grepl("keine Robustheitspr", a9$notes)))
  expect_identical(cmp_traffic_light_core(-1, -1, thresholds = thr)$level, "red")
  expect_identical(cmp_traffic_light_core(500, 500, mc = mcv(0.70), thresholds = thr)$level,
                   "green")
  expect_identical(cmp_traffic_light_core(500, 500, mc = mcv(0.40), thresholds = thr)$level,
                   "yellow")
  a12 <- cmp_traffic_light_core(500, 500, mc = mcv(0.80),
                                restrictions = r("liquidity", NA, NA_real_), thresholds = thr)
  expect_identical(a12$level, "green")
  expect_false(a12$restrictions$ko)
  expect_true(any(grepl("nicht pr", a12$notes)))
  # Median <= 0 trotz p >= green_prob: nicht green
  expect_identical(cmp_traffic_light_core(5, 5, mc = c(rep(-1, 51), rep(1, 49)),
                                          thresholds = list(green_prob = 0.4, red_prob = 0.1,
                                                            restriction_prob = 0.3))$level,
                   "yellow")
})

test_that("Ampel eines Ergebnisses: Schwellen und Restriktionen aus der Spezifikation", {
  res <- wsg_quiet(vofi_run(vofi_build(wsg_scenario())))
  tl <- cmp_traffic_light(res)
  expect_identical(tl$basis, "base_only")
  expect_identical(tl$kpi, "delta_terminal_value")
  expect_named(tl, c("level", "stage1", "basis", "kpi", "rv_dependent", "restrictions",
                     "notes"))
  thr <- cmp_tl_thresholds(res$spec)
  expect_identical(unlist(thr), c(green_prob = 0.7, red_prob = 0.4, restriction_prob = 0.3))
  tl2 <- cmp_traffic_light(res, cautious = -1)
  expect_identical(tl2$basis, "cautious")
  expect_null(cmp_traffic_light(res, kpi = "gibt_es_nicht"))
})

test_that("Restriktionen: Jahr und Betrag der ersten Verletzung (DSCR, Liquidität)", {
  sc <- wsg_scenario(flows = c(-100000, 1000, 1000, 1000, 1000), final = 1000,
                     kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value",
                              "dscr_min", "restriction_dscr", "restriction_liquidity"),
                     accounts = list(overdraft_flag_threshold_eur = 5000))
  res <- wsg_quiet(vofi_run(wsg_quiet(vofi_build(sc))))
  expect_identical(res$kpis$restriction_dscr, 1)
  d <- cmp_restriction_detail(res, "dscr")
  expect_identical(d$year, 2027L)
  expect_equal(d$threshold, 1.2)
  expect_lt(d$value, 1.2)
  l <- cmp_restriction_detail(res, "liquidity")
  expect_equal(l$threshold, 5000)
  expect_true(is.na(l$year) || l$year >= 2027L)
  rs <- cmp_restrictions(res)
  expect_true(all(c("dscr", "liquidity", "warm_rent") %in% rs$code))
  expect_true(rs$violated_base[rs$code == "dscr"])
  tl <- cmp_traffic_light(res)
  expect_true(tl$restrictions$ko[tl$restrictions$code == "dscr"])
  expect_true(any(grepl("DSCR", tl$notes)))
  expect_identical(cmp_restriction_detail(res, "gibts"),
                   list(year = NA_integer_, value = NA_real_, threshold = NA_real_))
})

test_that("Differenz-VoFi (9.6 Nr. 5): zeilenweise Differenz, nur bei gleichem Raster", {
  testthat::local_mocked_bindings(vofi_table = wsg_mock_table)
  sc <- wsg_scenario(variants = wsg_variant_a(components.z.values = wsg_z_a))
  cmp <- wsg_quiet(vofi_compare(sc))
  dt <- cmp$diff_table
  expect_s3_class(dt, "vofi_table")
  expect_identical(dt$variant, "a")
  pr <- dt$data[dt$data$row_key == "project", ]
  expect_equal(unname(unlist(pr[, paste0("t", 0:5)])), c(0, 3000, 0, 0, 0, 0))
  # anderes Raster: keine Differenz-VoFi, Hinweis
  ra <- cmp$results$a
  rb <- cmp$results$base
  rb$grid$months <- rb$grid$months + 1
  expect_identical(attr(cmp_diff_table(ra, rb), "note"), "grid")
})

test_that("Differenz-VoFi ohne Tabellenfunktion: NULL mit Hinweis", {
  testthat::local_mocked_bindings(vofi_table = function(...) {
    vofi_abort("core.not_implemented", fun = "vofi_table")
  })
  sc <- wsg_scenario(variants = wsg_variant_a(components.z.values = wsg_z_a))
  cmp <- wsg_quiet(vofi_compare(sc))
  expect_null(cmp$diff_table)
  expect_true(any(grepl("Differenz-VoFi", cmp$meta$notes)))
})

test_that("Modus differential (9.6 Nr. 6): negierte Referenzzahlungen, Vermerk", {
  sc <- wsg_scenario(variants = wsg_variant_a(components.z.values = wsg_z_a,
                                              project.comparison_mode = "differential"))
  cmp <- wsg_quiet(vofi_compare(sc))
  ra <- cmp$results$a
  expect_true(any(startsWith(ra$ledger$rows$key, "ref_")))
  refrow <- ra$ledger$values[["ref_z__value"]]
  expect_equal(refrow[1L, ], -cmp$results$base$ledger$values$z__value[1L, ])
  expect_equal(unname(cmp$differences$delta_vs_reference[1L, "a"]),
               ra$kpis$delta_terminal_value)
  expect_true(cmp$meta$differential)
  expect_true(any(grepl("Differenzzahlungen", cmp$meta$notes)))
  expect_true("mc.comparability.differential" %in% cmp$comparability$code)
})

test_that("Entscheidungsknoten im Vergleich: Kompositum und bedingte Ergebnisse (9.6 Nr. 8)", {
  sc <- wsg_decision_scenario(n_sim = 200L, p = 0.6)
  cmp <- wsg_quiet(vofi_compare(sc, variants = "base", baseline = "ohne"))
  expect_identical(cmp$variants, "base")
  cond <- cmp$conditional
  expect_identical(cond$branch, c(1L, 0L))
  expect_equal(cond$mean[cond$branch == 0L], 0, tolerance = 1e-9)
  expect_equal(cond$mean[cond$branch == 1L],
               unname(cmp$differences$delta_vs_reference[1L, "base"]),
               tolerance = 1e-9)
  mc <- wsg_quiet(vofi_compare(sc, variants = "base", baseline = "ohne", n_sim = 200L,
                               seed = 3L, store = "kpi"))
  b <- mc$results$base$kpis$branch
  dvr <- mc$differences$delta_vs_reference[, "base"]
  expect_true(all(abs(dvr[b == 0L]) < 1e-9))
  expect_true(all(dvr[b == 1L] > 0))
  cnd <- mc$conditional
  expect_identical(cnd$branch, c(1L, 0L))
  expect_equal(cnd$prob_better[cnd$branch == 0L], 0)
  expect_equal(cnd$prob_better[cnd$branch == 1L], 1)
})

test_that("Zwei identische Varianten: Differenz exakt 0 in jedem Lauf (11.10 Nr. 4)", {
  st <- list(settings = list(seed = 2L, block_size = 200L),
             parameters = list(f = list(target = "shared.f", dist = "uniform", min = 20000,
                                        max = 40000)))
  sc <- wsg_scenario(shared = list(f = 30000), final = list(ref = "shared.f"), stochastic = st,
                     variants = list(gleich = list(label = "gleich", set = list())))
  cmp <- wsg_quiet(vofi_compare(sc, variants = "gleich", n_sim = 200L, seed = 2L))
  expect_true(all(cmp$differences$delta_vs_reference == 0))
  expect_true(all(cmp$differences$delta_vs_reference_ex_rv == 0))
  expect_s3_class(cmp$results$gleich, "vofi_mc_result")
  expect_true(length(cmp$results$gleich$bands) > 0L)
})

test_that("Pflichtsensitivitäten (Teil C 4.4) auf dem Walking Skeleton", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  ms <- wsg_quiet(cmp_mandatory_sensitivities(sc))
  expect_true(all(c("restwert_null", "habenzins_kalkulationszins", "habenzins_fk",
                    "stufe_2045") %in% ms$id))
  expect_equal(unique(ms$base), 10382.48, tolerance = 0.005)
  g <- function(id) ms[ms$id == id, ]
  expect_equal(g("habenzins_kalkulationszins")$value, 9869.36, tolerance = 0.005)
  expect_identical(g("habenzins_kalkulationszins")$status, "computed")
  # kein Restwert im Skelett: Ergebnis wie im Basisfall (Teil C 4.4)
  expect_true(g("restwert_null")$status %in% c("same_as_base", "no_effect"))
  expect_equal(g("restwert_null")$value, g("restwert_null")$base, tolerance = 1e-9)
  expect_identical(g("habenzins_liquiditaet")$status, "same_as_base")
  expect_identical(g("stufe_2045")$status, "no_effect")
  fk <- g("habenzins_fk")
  expect_identical(fk$status, "computed")
  expect_equal(fk$value, 9688.64, tolerance = 0.005)
  # Abgeltungsteuer (Profil Selbstnutzer/Kleinvermieter) als eigener Eintrag
  sc2 <- sc
  ms_abg <- list(id = "habenzins_abgeltung", path = "accounts.deposit_withholding_tax_share",
                 value = 0.26375, label = "Abgeltung")
  sc2$analysis$mandatory_sensitivities <- list(ms_abg)
  ms2 <- wsg_quiet(cmp_mandatory_sensitivities(sc2))
  expect_equal(ms2$value, 10552.68, tolerance = 0.005)
  # delta auf eine Bezugsform mit Anker (R-107): Anker + delta, Kopplung bleibt
  spec <- list(accounts = list(deposit_rate_pa = list(kind = "ref",
                                                      ref = "market.mortgage_rate",
                                                      anchor = 0.02, floor = 0)))
  ov <- cmp_mandatory_override(spec, list(path = "accounts.deposit_rate_pa", delta = 0.01))
  expect_identical(ov[[1L]]$ref, "market.mortgage_rate")
  expect_equal(ov[[1L]]$anchor, 0.03)
  ov2 <- cmp_mandatory_override(spec, list(path = "accounts.deposit_rate_pa", value = 0.035))
  expect_identical(ov2[[1L]], 0.035)
  ov3 <- cmp_mandatory_override(list(project = list(pending_reforms = "a")),
                                list(path = "project.pending_reforms", add = "stufe_2045"))
  expect_identical(ov3[[1L]], c("a", "stufe_2045"))
})
