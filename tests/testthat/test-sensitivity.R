# Tests für R/sensitivity.R (WS-G; Spec 00 Abschnitte 11.11, 13.4; Spec 01 Teil C 4.3, 6.4).

test_that("Tornado (Teil C 4.3 (v1)): Kandidaten, Grenzen P10/P90, Ausschläge, Ränge", {
  m <- wsg_quiet(vofi_build(wsg_linear_scenario()))
  tor <- wsg_quiet(vofi_sensitivity(m, kpi = "delta_terminal_value"))
  expect_s3_class(tor, "vofi_sensitivity")
  expect_identical(tor$method, "tornado")
  expect_identical(tor$kpi, "delta_terminal_value")
  expect_equal(tor$base_value, 100, tolerance = 1e-9)
  r <- tor$results
  expect_identical(names(r), c("param", "value_low", "value_high", "kpi_low", "kpi_high",
                               "swing", "rank"))
  expect_identical(r$param, c("x1", "x2", "x3"))
  expect_identical(r$rank, 1:3)
  expect_equal(r$value_low, rep(-0.8, 3L), tolerance = 1e-12)
  expect_equal(r$value_high, rep(0.8, 3L), tolerance = 1e-12)
  expect_equal(r$kpi_low, c(92, 104, 99.2), tolerance = 1e-9)
  expect_equal(r$kpi_high, c(108, 96, 100.8), tolerance = 1e-9)
  expect_equal(r$swing, c(16, 8, 1.6), tolerance = 1e-9)
  p <- tor$params
  expect_identical(names(p), c("param", "label", "base", "low", "high", "source"))
  expect_identical(unique(p$source), "overlay")
  expect_equal(p$base, c(0, 0, 0))
  expect_identical(tor$meta$n_rows, 7L)
  # Primärkennzahl ist der Default
  tor0 <- wsg_quiet(vofi_sensitivity(wsg_linear_scenario()))
  expect_identical(tor0$kpi, "delta_terminal_value")
  expect_equal(tor0$results$swing, r$swing)
})

test_that("Tornado mit Zielpfaden: Overlay-Ziel und Basis x (1 -/+ delta)", {
  sc <- vofi_read_scenario(vofi_example("grob_lehrbuch_a"))
  tor <- wsg_quiet(vofi_sensitivity(sc, params = c("shared.rw", "financing.ann.rate_pa"),
                                    kpi = "terminal_value"))
  p <- tor$params
  expect_identical(p$param, c("rw", "financing.ann.rate_pa"))
  expect_identical(p$label[1L], "Restwert")
  expect_identical(p$source, c("overlay", "delta"))
  q_tri <- function(u) ref_q_triangular(u, 30000, 40000, 50000)
  expect_equal(p$low[1L], q_tri(0.1), tolerance = 1e-9)
  expect_equal(p$high[1L], q_tri(0.9), tolerance = 1e-9)
  expect_equal(p$base[2L], 0.06)
  expect_equal(c(p$low[2L], p$high[2L]), c(0.048, 0.072), tolerance = 1e-12)
  r <- tor$results
  rw <- r[r$param == "rw", ]
  # EW linear im Restwert (Zufluss in T)
  expect_equal(rw$kpi_high - rw$kpi_low, q_tri(0.9) - q_tri(0.1), tolerance = 1e-6)
  # Zinssatz: Designzeile = deterministischer Lauf mit Override (Basisfallgrößen fest)
  zr <- r[r$param == "financing.ann.rate_pa", ]
  ov <- list(financing.ann.rate_pa = 0.072)
  det <- wsg_quiet(vofi_run(vofi_build(sc, overrides = ov)))
  expect_equal(zr$kpi_high, det$kpis$terminal_value, tolerance = 1e-6)
  expect_lt(zr$kpi_high, zr$kpi_low)
  tor2 <- wsg_quiet(vofi_sensitivity(sc, params = "financing.ann.rate_pa", delta = 0.5,
                                     kpi = "terminal_value"))
  expect_equal(c(tor2$params$low, tor2$params$high), c(0.03, 0.09), tolerance = 1e-12)
})

test_that("Spider: Stützstellen je Seite zwischen P05 und P95, Schritt 0 = Basisfall", {
  m <- wsg_quiet(vofi_build(wsg_linear_scenario()))
  sp <- wsg_quiet(vofi_sensitivity(m, method = "spider", steps = 2L,
                                   kpi = "delta_terminal_value"))
  expect_identical(sp$method, "spider")
  s1 <- sp$spider[sp$spider$param == "x1", ]
  expect_identical(s1$step, -2:2)
  expect_equal(s1$value, c(-0.9, -0.45, 0, 0.45, 0.9), tolerance = 1e-12)
  expect_equal(s1$kpi, 100 + 10 * s1$value, tolerance = 1e-9)
  s2 <- sp$spider[sp$spider$param == "x2", ]
  expect_equal(s2$kpi, 100 - 5 * s2$value, tolerance = 1e-9)
  expect_identical(nrow(sp$spider), 15L)
  expect_identical(sp$meta$n_rows, 13L)
  # Overlay-Verteilung: Schritt 0 = Basiswert mit der Kennzahl des Basisfalls
  expect_equal(s1$kpi[s1$step == 0L], sp$base_value)
  sc <- vofi_read_scenario(vofi_example("grob_lehrbuch_a"))
  sp2 <- wsg_quiet(vofi_sensitivity(sc, params = "financing.ann.rate_pa", method = "spider",
                                    steps = 2L, delta = 0.2, kpi = "terminal_value"))
  expect_equal(sp2$spider$value, 0.06 * c(0.8, 0.9, 1, 1.1, 1.2), tolerance = 1e-12)
})

test_that("Prozess mit Quantilpfad als Kandidat (S01C-10); unsicherer Prozessparameter", {
  sc <- wsg_scenario(loan = FALSE, kpis = c("terminal_value", "terminal_value_opp",
                                            "delta_terminal_value"),
                     extra = list(market = list(rent_growth = 0.015)))
  sc$components$rent <- list(type = "recurring", label = "Miete", category = "rent",
                             amount_eur = 9000, growth = list(ref = "market.rent_growth"),
                             base_date = as.Date("2027-01-01"),
                             start_event = as.Date("2027-01-01"))
  sc$stochastic <- list(settings = list(seed = 3L, block_size = 200L),
                        processes = list(rg = list(target = "market.rent_growth", type = "ar1",
                                                   mu = list(dist = "uniform", min = 0.005,
                                                             max = 0.025),
                                                   phi = 0.5, sigma = 0.01, x0 = 0.015)))
  m <- wsg_quiet(vofi_build(sc))
  tor <- wsg_quiet(vofi_sensitivity(m, kpi = "terminal_value"))
  expect_setequal(tor$params$param, c("rg", "rg.mu"))
  pr <- tor$params[tor$params$param == "rg", ]
  expect_identical(pr$source, "process")
  expect_equal(c(pr$low, pr$high), c(0.1, 0.9))
  expect_identical(tor$params$source[tor$params$param == "rg.mu"], "process_param")
  r <- tor$results[tor$results$param == "rg", ]
  expect_lt(r$kpi_low, tor$base_value)
  expect_gt(r$kpi_high, tor$base_value)
  # Designzeile mit Quantilpfad = smp_design(<proc> = p)
  ch <- eng_run_chunk(m, 1L, NULL, "design", "kpi", design = data.frame(rg = 0.9),
                      kpis = "terminal_value")
  expect_equal(r$kpi_high, ch$kpis$terminal_value, tolerance = 1e-12)
})

test_that("Spider: Schritt 0 eines Prozesses ist der eigene P50-Quantilpfad (gbm, schief)", {
  gb <- list(target = "market.rent_growth", type = "gbm", p0 = 0.015, sigma = 0.5)
  m <- wsg_quiet(vofi_build(wsg_process_scenario(gb)))
  sp <- wsg_quiet(vofi_sensitivity(m, kpi = "terminal_value", method = "spider", steps = 2L))
  s0 <- sp$spider[sp$spider$param == "rg" & sp$spider$step == 0L, ]
  expect_equal(s0$value, 0.5)
  p50 <- eng_run_chunk(m, 1L, NULL, "design", "kpi", design = data.frame(rg = 0.5),
                       kpis = "terminal_value")
  expect_equal(s0$kpi, p50$kpis$terminal_value, tolerance = 1e-9)
  # bei gbm liegt der Median unter dem Erwartungspfad des Basisfalls
  expect_lt(s0$kpi, sp$base_value)
  # Stützstellen monoton im Quantilniveau
  s <- sp$spider[sp$spider$param == "rg", ]
  expect_true(all(diff(s$kpi) > 0))
  expect_identical(sp$meta$n_rows, 1L + 4L + 1L)
})

test_that("delta_vs_reference: dieselbe Designmatrix für Variante und Referenz", {
  sc <- wsg_linear_scenario()
  z_a <- list(0, 0, list(expr = "120 + 20 * shared.x1 - 5 * shared.x2 + 1 * shared.x3"))
  sc$variants <- wsg_variant_a(components.z.values = z_a)
  tor <- wsg_quiet(vofi_sensitivity(sc, kpi = "delta_vs_reference", variant = "a"))
  expect_identical(tor$meta$reference, "base")
  expect_equal(tor$base_value, 20, tolerance = 1e-9)
  r <- tor$results
  expect_identical(r$param[1L], "x1")
  expect_equal(r$swing[1L], 16, tolerance = 1e-9)
  expect_equal(r$swing[r$param == "x2"], 0, tolerance = 1e-9)
  expect_error(wsg_quiet(vofi_sensitivity(wsg_quiet(vofi_build(sc, variant = "a")),
                                          kpi = "delta_vs_reference")),
               class = "vofi_error_input")
  expect_error(wsg_quiet(vofi_sensitivity(sc, kpi = "delta_vs_reference", variant = "a",
                                          reference = "a")), class = "vofi_error_input")
  expect_identical(tor$variant, "a")
})

test_that("delta_vs_reference im Modus differential: Referenzzeilen je Designzeile (9.6 Nr. 6)", {
  sc <- wsg_linear_scenario()
  z_a <- list(0, 0, list(expr = "120 + 20 * shared.x1 - 5 * shared.x2 + 1 * shared.x3"))
  sc$variants <- wsg_variant_a(components.z.values = z_a,
                               project.comparison_mode = "differential")
  tor <- wsg_quiet(vofi_sensitivity(sc, kpi = "delta_vs_reference", variant = "a"))
  # wie im Modus absolute: Basis 20, Ausschläge 16 / 0 / 0 (nicht 120 bzw. 32 / 8 / 1,6)
  expect_equal(tor$base_value, 20, tolerance = 1e-9)
  expect_equal(tor$results$swing, c(16, 0, 0), tolerance = 1e-9)
  sp <- wsg_quiet(vofi_sensitivity(sc, kpi = "delta_vs_reference", variant = "a",
                                   method = "spider", steps = 2L))
  s1 <- sp$spider[sp$spider$param == "x1", ]
  expect_equal(s1$kpi, 20 + 10 * s1$value, tolerance = 1e-9)
  s2 <- sp$spider[sp$spider$param == "x2", ]
  expect_equal(s2$kpi, rep(20, 5L), tolerance = 1e-9)
  # Paar der Design-Läufe: Variante mit den negierten Zeilen der Referenz
  setup <- wsg_quiet(sens_setup(sc, "a", NULL, "delta_vs_reference"))
  pr <- wsg_quiet(cmp_design_pair(setup$model, setup$ref_model, data.frame(x1 = c(-1, 1)),
                                  kpis = setup$kpis, store = "full"))
  expect_true(pr$differential)
  expect_true(pr$var$differential)
  expect_false(pr$ref$differential)
  key <- "ref_z__value"
  expect_true(key %in% pr$var_chunk$ledger$rows$key)
  expect_equal(pr$var_chunk$ledger$values[[key]], -pr$ref_chunk$ledger$values$z__value)
})

test_that("Variante des Ergebnisses aus dem Modell, nicht aus dem Argument", {
  sc <- wsg_linear_scenario()
  sc$variants <- wsg_variant_a(shared.x3 = 0.5)
  ma <- wsg_quiet(vofi_build(sc, variant = "a"))
  expect_identical(wsg_quiet(vofi_sensitivity(ma, kpi = "delta_terminal_value"))$variant, "a")
  expect_identical(wsg_quiet(vofi_sensitivity(sc, kpi = "delta_terminal_value"))$variant,
                   "base")
  sp <- wsg_quiet(vofi_sensitivity(ma, kpi = "delta_terminal_value", method = "spider",
                                   steps = 1L))
  expect_identical(sp$variant, "a")
})

test_that("Argumentprüfung", {
  m <- wsg_quiet(vofi_build(wsg_linear_scenario()))
  expect_error(vofi_sensitivity(m, probs = c(0.9, 0.1)), class = "vofi_error_input")
  expect_error(vofi_sensitivity(m, probs = 0.5), class = "vofi_error_input")
  expect_error(vofi_sensitivity(m, delta = -1), class = "vofi_error_input")
  expect_error(vofi_sensitivity(m, steps = 0L), class = "vofi_error_input")
  expect_error(vofi_sensitivity(m, method = "radar"), class = "vofi_error_input")
  expect_error(wsg_quiet(vofi_sensitivity(m, params = "gibts.nicht")),
               class = "vofi_error_input")
  expect_error(wsg_quiet(vofi_sensitivity(m, kpi = "roe_irr")), class = "vofi_error_input")
  expect_error(wsg_quiet(vofi_sensitivity(m, kpi = "incremental_return")),
               class = "vofi_error_input")
  expect_error(vofi_sensitivity(42), class = "vofi_error_input")
  expect_error(vofi_sensitivity(m, params = 1), class = "vofi_error_input")
})

test_that("Globale Sensitivität (Teil C 6.4): synthetische Stichprobe y = 2 x1 + x2", {
  n <- 10000L
  set.seed(42)
  lhs <- function() (sample.int(n) - stats::runif(n)) / n
  x <- data.frame(x1 = lhs(), x2 = lhs(), konst = 1)
  y <- 2 * x$x1 + x$x2
  g <- sens_global(x, y)
  gl <- g$global
  expect_identical(gl$input, c("x1", "x2"))
  expect_equal(gl$src, c(2, 1) / sqrt(5), tolerance = 0.005)
  expect_equal(gl$spearman, c(0.900, 0.426), tolerance = 0.01)
  expect_equal(gl$s1_binned, c(0.798, 0.200), tolerance = 0.01)
  expect_equal(g$r2_src, 1, tolerance = 1e-9)
  expect_true(g$r2_srrc >= 0.7)
  expect_identical(g$rank_by, "srrc")
  expect_true(all(gl$prcc > 0.9))
  # nicht lineare, nicht monotone Wirkung: Rang nach s1_binned
  y2 <- (x$x1 - 0.5)^2 + 0.01 * x$x2
  g2 <- sens_global(x, y2)
  expect_identical(g2$rank_by, "s1_binned")
  expect_identical(g2$global$input[1L], "x1")
  expect_identical(g$dropped, "konst")
  # Randfälle
  expect_identical(nrow(sens_global(data.frame(), y)$global), 0L)
  expect_identical(nrow(sens_global(x["konst"], y)$global), 0L)
})

test_that("Globale Sensitivität: Entscheidungsschlüssel und konstante Merkmale mit Hinweis", {
  m <- wsg_quiet(vofi_build(wsg_decision_scenario(n_sim = 400L, p = 0.6)))
  mc <- wsg_quiet(vofi_mc(m, n_sim = 400L, seed = 11L, store = "kpi"))
  key <- mc$decision$key
  expect_true(key %in% names(mc$inputs))
  expect_message(gs <- vofi_sensitivity(mc, method = "global", kpi = "delta_terminal_value"),
                 class = "vofi_message")
  expect_false(key %in% gs$global$input)
  expect_true(key %in% gs$meta$omitted)
  expect_true("rent" %in% gs$global$input)
})

test_that("Globale Sensitivität aus einer Simulation (inputs und Pfadmerkmale)", {
  pars <- list(x1 = list(target = "shared.x1", dist = "uniform", min = 0, max = 1),
               x2 = list(target = "shared.x2", dist = "uniform", min = 0, max = 1))
  sc <- wsg_expr_scenario("100 * (2 * shared.x1 + shared.x2)", parameters = pars,
                          shared = list(x2 = 0))
  m <- wsg_quiet(vofi_build(sc))
  mc <- wsg_quiet(vofi_mc(m, n_sim = 2000L, seed = 5L, store = "kpi"))
  gs <- wsg_quiet(vofi_sensitivity(mc, method = "global", kpi = "delta_terminal_value"))
  expect_identical(gs$method, "global")
  expect_identical(gs$global$input, c("x1", "x2"))
  expect_equal(gs$global$src, c(2, 1) / sqrt(5), tolerance = 0.01)
  expect_equal(gs$r2_src, 1, tolerance = 1e-8)
  expect_identical(gs$params$source, c("mc", "mc"))
  expect_equal(gs$base_value, 0, tolerance = 1e-9)
  gp <- wsg_quiet(vofi_sensitivity(mc, method = "global", params = "x2",
                                   kpi = "delta_terminal_value"))
  expect_identical(gp$global$input, "x2")
  expect_error(vofi_sensitivity(mc, method = "global", kpi = "gibts"),
               class = "vofi_error_input")
  # Tornado (P10/P90) derselben Kennzahl: Ausschläge 160 / 80
  tor <- wsg_quiet(vofi_sensitivity(mc, kpi = "delta_terminal_value"))
  expect_equal(tor$results$swing, c(160, 80), tolerance = 1e-9)
})

test_that("9.10: Tornado 20 Parameter x 2 (ein Design-Lauf, eine Kennzahl; < 1 s)", {
  wsg_perf_skip()
  m <- wsg_quiet(vofi_build(wsg_bench_scenario(53L)))
  params <- c("rent", "opex", "maint", "admin", "inv", "kfw_rate", "haben", "zins", "infl",
              "miete", "financing.bul.rate_pa", "financing.bank.rate_pa",
              "accounts.overdraft_rate_pa", "accounts.penalty_spread_pa",
              "components.maint.growth", "components.admin.growth",
              "financing.ek.withdrawals_pa", "zins.theta", "infl.mu", "miete.mu")
  run <- function() wsg_quiet(vofi_sensitivity(m, params = params, kpi = "delta_terminal_value"))
  tor <- run()
  expect_identical(nrow(tor$params), 20L)
  expect_identical(tor$meta$n_rows, 41L)
  ms <- wsg_cpu_ms(run, 2L)
  expect_lt(ms, 1000 * wsg_perf_factor(), label = sprintf("Tornado %.0f ms", ms))
})
