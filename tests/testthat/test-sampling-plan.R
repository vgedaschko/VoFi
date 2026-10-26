# Tests für R/sampling-plan.R (WS-C; Spec 00 11.2, 11.4, 11.6, 11.7; Spec 01 Teil C 1.2-1.10).

infl_proc <- function(...) {
  utils::modifyList(list(target = "market.inflation", type = "ar1", mu = 0.02, phi = 0.5,
                         sigma = 0.011, x0 = 0.028), list(...))
}

test_that("Einstellungen: Defaults, Presets und Vorrang (R-97, Prüffall s8)", {
  s <- smp_resolve_settings(NULL)
  expect_identical(s$n_sim, 10000L)
  expect_identical(s$block_size, 200L)
  expect_identical(s$sampling, "lhs")
  expect_identical(s$store, "bands")
  expect_identical(s$keep_runs, c("p05", "p50", "p95"))
  expect_true(s$auto_funding_approval)
  expect_null(s$seed)
  p <- smp_resolve_settings(list(preset = "preview"))
  expect_identical(c(p$n_sim, length(p$keep_runs)), c(1000L, 0L))
  expect_identical(p$store, "kpi")
  p5 <- smp_resolve_settings(list(preset = "preview", n_sim = 5000))
  expect_identical(p5$n_sim, 5000L)
  expect_identical(smp_resolve_settings(list(preset = "report"))$n_sim, 50000L)
  # Felder aus Schichten 0-2 (global.yaml) unterliegen dem Preset
  prov <- data.frame(path = c("stochastic.settings.store", "stochastic.settings.preset"),
                     layer = c(1L, 5L), source_type = c("global", "scenario"),
                     stringsAsFactors = FALSE)
  pg <- smp_resolve_settings(list(preset = "preview", store = "bands"), prov)
  expect_identical(pg$store, "kpi")
  prov$layer[1] <- 5L
  expect_identical(smp_resolve_settings(list(preset = "preview", store = "bands"), prov)$store,
                   "bands")
  cu <- smp_resolve_settings(list(preset = "custom", n_sim = 400, store = "full"))
  expect_identical(c(cu$n_sim, cu$store), c("400", "full"))
  expect_error(smp_resolve_settings(list(preset = "vorschau")), class = "vofi_error_validation")
})

test_that("Einstellungen: Prüffälle s3, s5, s6 und ungültige Werte", {
  expect_error(smp_resolve_settings(list(antithetic = TRUE, sampling = "lhs")),
               class = "vofi_error_validation")
  expect_error(smp_resolve_settings(list(block_size = 200, replicates = 10)),
               class = "vofi_error_validation")
  # replicates mit block_size aus global.yaml (Schicht 1): F21-Modus
  prov <- data.frame(path = c("stochastic.settings.block_size",
                              "stochastic.settings.replicates"),
                     layer = c(1L, 5L), stringsAsFactors = FALSE)
  f21 <- smp_resolve_settings(list(block_size = 200, replicates = 10, n_sim = 1000), prov)
  expect_null(f21$block_size)
  expect_identical(f21$replicates, 10L)
  expect_identical(smp_block_size(f21, 1000L), 100L)
  expect_error(smp_resolve_settings(list(sampling = "sobol")), class = "vofi_error_validation")
  expect_error(smp_resolve_settings(list(copula = "t")), class = "vofi_error_validation")
  expect_error(smp_resolve_settings(list(block_size = 1)), class = "vofi_error_validation")
  expect_error(smp_resolve_settings(list(seed = 0)), class = "vofi_error_input")
  expect_identical(smp_resolve_settings(list(seed = 20261025L))$seed, 20261025)
})

test_that("Blockgröße: Prüffälle s1, s2, s4, s6 (smp_block_size, smp_configure)", {
  s <- smp_resolve_settings(NULL)
  expect_identical(smp_block_size(s, 1000L), 200L)
  expect_identical(10000L %/% smp_block_size(s, 10000L), 50L)
  e <- tryCatch(smp_block_size(s, 1100L), error = function(e) e)
  expect_s3_class(e, "vofi_error_input")
  expect_match(conditionMessage(e), "1.000")
  expect_match(conditionMessage(e), "1.200")
  ua <- wsc_par("shared.a", "uniform", min = 0, max = 1)
  plan <- smp_plan(wsc_spec(list(parameters = list(a = ua))))
  expect_identical(smp_blocks(plan, 1000L), 1:5)
  pc <- suppressMessages(smp_configure(plan, n_sim = 1000, replicates = 10))
  expect_identical(smp_plan_m(pc), 100L)
  expect_message(smp_configure(plan, n_sim = 1000, replicates = 10), class = "vofi_message")
  expect_error(smp_configure(plan, n_sim = 1000, replicates = 7), class = "vofi_error_input")
  expect_identical(smp_configure(pc, block_size = 50)$settings$block_size, 50L)
  expect_identical(smp_configure(plan, preview = TRUE)$settings$n_sim, 1000L)
  expect_error(smp_configure(plan, sampling = "pseudo", n_sim = 14, block_size = 7)$settings,
               NA)
  pa <- smp_plan(wsc_spec(list(settings = list(sampling = "pseudo", antithetic = TRUE),
                               parameters = list(a = wsc_par("shared.a", "uniform", min = 0,
                                                             max = 1)))))
  expect_error(smp_configure(pa, n_sim = 14, block_size = 7), class = "vofi_error_input")
  # s4: Gruppe mit d = 12 Schlüsseln und block_size 10
  pars <- list()
  pairs <- list()
  for (i in 1:12) {
    pars[[paste0("k", i)]] <- wsc_par(paste0("shared.k", i), "uniform", min = 0, max = 1)
  }
  for (i in 2:12) pairs[[i - 1L]] <- list("k1", paste0("k", i), 0.1)
  pg <- smp_plan(wsc_spec(list(parameters = pars, correlations = list(parameters = pairs))))
  expect_error(smp_configure(pg, n_sim = 100, block_size = 10), class = "vofi_error_input")
  expect_silent(smp_configure(pg, n_sim = 130, block_size = 13))
  expect_identical(length(smp_chunks(pc, 1000L, 250L)), 5L)
  expect_identical(smp_chunks(plan, 1000L, 450L), list(1:2, 3:4, 5L))
  expect_identical(smp_chunks(plan, 1000L, 10L), as.list(1:5))
})

test_that("Statische Schlüssel: Quellen, Rollen, apply, kanonische Ordnung und Parameter", {
  st <- list(
    parameters = list(
      zeta = wsc_par("shared.z", "lognormal", median = 0.02, p90 = 0.05),
      alpha = wsc_par("shared.a", "pert", min = 0.9, mode = 1, max = 1.4, apply = "multiply",
                      label = "Kostenfaktor"),
      "measures.huelle.cost_eur" = wsc_par("measures.huelle.cost_eur", "uniform", min = 1,
                                           max = 2, base = 1.5)
    ),
    processes = list(inflation = infl_proc(mu = list(dist = "normal", mean = 0.02, sd = 0.004)))
  )
  plan <- smp_plan(wsc_spec(st))
  expect_s3_class(plan, "smp_plan")
  expect_identical(plan$static$key, c("alpha", "inflation.mu", "measures.huelle.cost_eur", "zeta"))
  expect_identical(plan$static$source, c("overlay", "process_param", "inline", "overlay"))
  expect_identical(plan$static$apply, c("multiply", "replace", "replace", "replace"))
  expect_identical(plan$static$role, rep("value", 4L))
  expect_identical(plan$static$label[1], "Kostenfaktor")
  expect_identical(plan$static$target[2], "stochastic.processes.inflation.mu")
  expect_identical(names(plan$static_par$zeta), c("meanlog", "sdlog", "shift"))
  expect_null(plan$static_par[["measures.huelle.cost_eur"]]$base)
  expect_identical(plan$proc_order, "inflation")
  expect_identical(plan$processes$inflation$n_shocks, 1L)
  expect_identical(plan$processes$inflation$output, "rate")
  expect_identical(plan$years, make_grid()$years)
  expect_match(plan$hash, "^[0-9a-f]{32}$")
})

test_that("Plan-Hash hängt von der Struktur ab, nicht von Parameterwerten (R-93)", {
  mk <- function(max, sigma, extra = FALSE) {
    pars <- list(a = wsc_par("shared.a", "uniform", min = 0, max = max))
    if (extra) pars$b <- wsc_par("shared.b", "uniform", min = 0, max = 1)
    procs <- list(inflation = infl_proc(sigma = sigma))
    smp_plan(wsc_spec(list(parameters = pars, processes = procs)))$hash
  }
  expect_identical(mk(1, 0.01), mk(2, 0))
  expect_false(identical(mk(1, 0.01), mk(1, 0.01, extra = TRUE)))
})

test_that("Token base: Start am deterministischen Basisfall (R-95, Spec 01 Teil C 1.5.1)", {
  st <- list(processes = list(
    inflation = infl_proc(x0 = "base"),
    rent_growth = list(target = "market.rent_growth", type = "linked_ar1", base = "inflation",
                       a = 0.002, b = 0.8, phi = 0.5, sigma = 0.006, u0 = "base"),
    mortgage_rate = list(target = "market.mortgage_rate", type = "vasicek", r0 = "base",
                         theta = 0.0375, kappa = 0.12, sigma = 0.007),
    gas = list(target = "market.energy_price.gas", type = "mr_trend", p0 = "base",
               p_norm = "base", phi = 0.75, sigma = 0.08, growth = 0.02),
    power = list(target = "market.energy_price.power", type = "gbm", p0 = "base", sigma = 0.1)
  ))
  plan <- smp_plan(wsc_spec(st, market = list(inflation = 0.026, rent_growth = 0.0175)))
  pr <- plan$processes
  expect_identical(pr$inflation$par$x0, 0.026)
  expect_identical(pr$mortgage_rate$par$r0, 0.04)
  expect_identical(c(pr$gas$par$p0, pr$gas$par$p_norm), c(0.12, 0.12))
  expect_identical(pr$power$par$p0, 0.35)
  # Bibliotheksdefault Bestandsmiete: x_det = 0,0175, π_2027 = 0,026 -> u0 = -0,0053
  expect_equal(pr$rent_growth$par$u0, 0.0175 - 0.002 - 0.8 * 0.026, tolerance = 1e-15)
  expect_identical(pr$rent_growth$x_det, 0.0175)
  expect_identical(plan$proc_order, c("gas", "inflation", "mortgage_rate", "power",
                                      "rent_growth"))
  g <- wsc_proc("linked_ar1")$expected(smp_point_par(plan, "rent_growth"), plan$years)
  expect_spec(g[c(1, 2)], c("0.0175", "0.01775"))
  # Startwert der Basis laufspezifisch (x0 verteilt): Token bleibt, Auflösung je Lauf
  st2 <- st
  st2$processes$inflation$x0 <- list(dist = "uniform", min = 0.02, max = 0.03)
  p2 <- smp_plan(wsc_spec(st2))
  expect_identical(p2$processes$rent_growth$par$u0, "base")
  expect_identical(p2$processes$rent_growth$x_det, 0.015)
  # Spalte j >= 2 mit year[j] == start_year (gemischtes Raster: Bauphase monatlich)
  gm <- make_grid("mixed")
  pm <- smp_plan(wsc_spec(list(processes = list(inflation = infl_proc(x0 = "base"))), gm,
                          market = list(inflation = list(series = list("2027" = 0.03,
                                                                       "2028" = 0.01)))),
                 gm)
  expect_identical(pm$processes$inflation$par$x0, 0.03)
  # Ziel ohne Basiswert
  bad <- list(processes = list(x = infl_proc(target = "market.gibts_nicht", x0 = "base")))
  expect_error(smp_plan(wsc_spec(bad)), class = "vofi_error_validation")
})

test_that("Plan-Fehler: Typen, Ziele, Kopplungen, Schlüssel", {
  ev <- "vofi_error_validation"
  expect_error(smp_plan(wsc_spec(list(parameters = list(a = list(dist = "uniform", min = 0,
                                                                 max = 1))))), class = ev)
  expect_error(smp_plan(wsc_spec(list(parameters = list(a = wsc_par("shared.a", "unifrom",
                                                                    min = 0, max = 1))))),
               class = ev)
  expect_error(smp_plan(wsc_spec(list(parameters = list(a = wsc_par("shared.a", "uniform",
                                                                    min = 2, max = 1))))),
               class = ev)
  expect_error(smp_plan(wsc_spec(list(parameters = list(a = wsc_par("shared.a", "uniform",
                                                                    min = 0, max = 1,
                                                                    apply = "times"))))),
               class = ev)
  dup <- list(parameters = list(a = wsc_par("market.inflation", "uniform", min = 0, max = 1)),
              processes = list(inflation = infl_proc()))
  expect_error(smp_plan(wsc_spec(dup)), class = ev)
  expect_error(smp_plan(wsc_spec(list(processes = list(x = infl_proc(type = "arma"))))),
               class = ev)
  expect_error(smp_plan(wsc_spec(list(processes = list(x = infl_proc(phi = 2))))), class = ev)
  expect_error(smp_plan(wsc_spec(list(processes = list(x = infl_proc(target = NULL))))),
               class = ev)
  lk <- function(base) {
    list(target = paste0("market.", base, "_x"), type = "linked_ar1", base = base)
  }
  expect_error(smp_plan(wsc_spec(list(processes = list(r = lk("fehlt"))))), class = ev)
  cyc <- list(processes = list(a = utils::modifyList(lk("b"), list(target = "market.inflation")),
                               b = utils::modifyList(lk("a"), list(target = "market.rent_growth"))))
  expect_error(smp_plan(wsc_spec(cyc)), class = ev)
  same <- list(parameters = list(inflation.mu = wsc_par("shared.m", "uniform", min = 0, max = 1)),
               processes = list(inflation = infl_proc(mu = list(dist = "normal", mean = 0.02,
                                                                sd = 0.004))))
  expect_error(smp_plan(wsc_spec(same)), class = ev)
})

test_that("Automatische Förderzusage und Entscheidungsknoten (11.6 Nr. 4, R-55, R-71)", {
  fund <- list(
    kfw = list(approval_probability = 0.85, approval_timing = "after_start"),
    node = list(approval_probability = 0.6, approval_timing = "before_start",
                fallback_variant = "v1b"),
    sicher = list(approval_probability = 1),
    ohne = list()
  )
  plan <- smp_plan(wsc_spec(list(), funding = fund))
  expect_identical(plan$static$key, c("funding.kfw.approved", "funding.node.approved"))
  expect_identical(plan$static$source, rep("funding_auto", 2L))
  expect_identical(plan$static$role, c("value", "decision"))
  expect_identical(plan$static$dist, rep("bernoulli", 2L))
  expect_identical(plan$static_par$funding.kfw.approved$p, 0.85)
  off <- smp_plan(wsc_spec(list(settings = list(auto_funding_approval = FALSE)),
                           funding = fund))
  expect_identical(nrow(off$static), 0L)
  # ausdrücklicher Overlay-Eintrag ersetzt den automatischen Schlüssel; Knoten -> decision
  ov <- list(parameters = list(avail = wsc_par("funding.node.approved", "bernoulli", p = 0.4)))
  po <- smp_plan(wsc_spec(ov, funding = fund))
  expect_identical(po$static$key, c("avail", "funding.kfw.approved"))
  expect_identical(po$static$role, c("decision", "value"))
  expect_identical(po$static_par$avail$p, 0.4)
  # Entscheidungsschlüssel: 0/1-wertig und nicht korrelierbar
  bad <- list(parameters = list(avail = wsc_par("funding.node.approved", "uniform", min = 0,
                                                max = 1)))
  expect_error(smp_plan(wsc_spec(bad, funding = fund)), class = "vofi_error_validation")
  corr <- list(parameters = list(x = wsc_par("shared.x", "uniform", min = 0, max = 1)),
               correlations = list(parameters = list(list("x", "funding.node.approved", 0.5))))
  expect_error(smp_plan(wsc_spec(corr, funding = fund)), class = "vofi_error_validation")
  ok <- corr
  ok$correlations$parameters <- list(list("x", "funding.kfw.approved", 0.5))
  expect_identical(rownames(smp_plan(wsc_spec(ok, funding = fund))$correlations$parameters),
                   c("funding.kfw.approved", "x"))
})

test_that("Korrelationspaare: Matrix, Prüfungen, Bibliothekspaare (R-96)", {
  pars <- list(b = wsc_par("shared.b", "uniform", min = 0, max = 1),
               a = wsc_par("shared.a", "uniform", min = 0, max = 1),
               c = wsc_par("shared.c", "uniform", min = 0, max = 1))
  procs <- list(inflation = infl_proc(),
                mortgage_rate = list(target = "market.mortgage_rate", type = "vasicek", r0 = 0.04,
                                     theta = 0.0375, kappa = 0.12, sigma = 0.007),
                fix = list(target = "market.co2_price", type = "fixed_path", years = 2027,
                           values = 55))
  st <- list(parameters = pars, processes = procs,
             correlations = list(parameters = list(list("c", "a", 0.5), c("b", "a", "0.3")),
                                 shocks = list(list(a = "mortgage_rate", b = "inflation",
                                                    rho = 0.4))))
  plan <- smp_plan(wsc_spec(st))
  rs <- plan$correlations$parameters
  expect_identical(rownames(rs), c("a", "b", "c"))
  expect_identical(rs["a", "c"], 0.5)
  expect_identical(rs["b", "a"], 0.3)
  expect_identical(rs["b", "c"], 0)
  expect_equal(plan$corr_pearson$parameters["a", "c"], 2 * sin(pi * 0.5 / 6))
  expect_identical(rownames(plan$correlations$shocks), c("inflation", "mortgage_rate"))
  expect_identical(plan$corr_pearson$shocks["inflation", "mortgage_rate"], 0.4)
  expect_null(plan$repaired$parameters)
  ev <- "vofi_error_validation"
  bad <- function(pairs, what = "parameters") {
    s <- st
    s$correlations[[what]] <- pairs
    smp_plan(wsc_spec(s))
  }
  expect_error(bad(list(list("a", "zz", 0.5))), class = ev)
  expect_error(bad(list(list("a", "a", 0.5))), class = ev)
  expect_error(bad(list(list("a", "b", 1.5))), class = ev)
  expect_error(bad(list(list("a", "b", 0.5), list("b", "a", 0.4))), class = ev)
  expect_error(bad(list(list("a", "b"))), class = ev)
  expect_error(bad(list(list("inflation", "fix", 0.3)), "shocks"), class = ev)
  expect_silent(bad(list(list("a", "b", 0.5), list("b", "a", 0.5))))
  # Paare aus einem Bibliotheksverweis mit fehlendem Schlüssel werden verworfen (Hinweis)
  prov <- data.frame(path = "stochastic.correlations.shocks", layer = 3L,
                     source_type = "library", stringsAsFactors = FALSE)
  s <- st
  s$correlations$shocks <- list(list("inflation", "mortgage_rate", 0.4),
                                list("inflation", "energy_price_gas", 0.6))
  expect_message(pl <- smp_plan(wsc_spec(s, provenance = prov)), class = "vofi_message")
  expect_identical(rownames(pl$correlations$shocks), c("inflation", "mortgage_rate"))
  expect_error(smp_plan(wsc_spec(s)), class = ev)
  # nicht positiv definit: Reparatur mit Warnung, reparierte Matrix im Plan
  s2 <- st
  s2$correlations$parameters <- list(list("a", "b", 0.9), list("a", "c", -0.6),
                                     list("b", "c", 0.2))
  expect_warning(pr <- smp_plan(wsc_spec(s2)), class = "vofi_warning_correlation")
  expect_spec(pr$repaired$parameters["a", "b"], "0.766160")
})

test_that("Vereinigung der Pläne (CRN, smp_plan_union)", {
  st_a <- list(
    parameters = list(x = wsc_par("shared.x", "uniform", min = 0, max = 1),
                      y = wsc_par("shared.y", "pert", min = 0, mode = 1, max = 2)),
    processes = list(inflation = infl_proc()),
    correlations = list(parameters = list(list("x", "y", 0.5)))
  )
  a <- smp_plan(wsc_spec(st_a))
  st_b <- list(
    parameters = list(x = wsc_par("shared.x", "uniform", min = 1, max = 3),
                      z = wsc_par("shared.z", "normal", mean = 0, sd = 1)),
    processes = list(inflation = infl_proc(sigma = 0.02),
                     mortgage_rate = list(target = "market.mortgage_rate", type = "vasicek",
                                          r0 = 0.04, theta = 0.0375, kappa = 0.12,
                                          sigma = 0.007))
  )
  b <- smp_plan(wsc_spec(st_b))
  u <- smp_plan_union(list(a, b))
  expect_identical(u$static$key, c("x", "y", "z"))
  expect_identical(names(u$processes), c("inflation", "mortgage_rate"))
  expect_identical(u$static_par$x, a$static_par$x)
  expect_identical(rownames(u$correlations$parameters), c("x", "y"))
  expect_identical(smp_plan_union(list(a)), a)
  expect_identical(smp_plan_union(a), a)
  ev <- "vofi_error_validation"
  ux <- wsc_par("shared.x", "uniform", min = 0, max = 1)
  uo <- wsc_par("shared.other", "uniform", min = 0, max = 1)
  c1 <- smp_plan(wsc_spec(list(parameters = list(x = uo))))
  expect_error(smp_plan_union(list(a, c1)), class = ev)
  c2 <- smp_plan(wsc_spec(list(processes = list(x = infl_proc(target = "shared.x")))))
  expect_error(smp_plan_union(list(a, c2)), class = ev)
  c3 <- smp_plan(wsc_spec(list(settings = list(block_size = 100), parameters = list(x = ux))))
  expect_error(smp_plan_union(list(a, c3)), class = ev)
  st_c4 <- list(
    parameters = list(x = ux, y = wsc_par("shared.y", "uniform", min = 0, max = 1)),
    correlations = list(parameters = list(list("x", "y", 0.2)))
  )
  c4 <- smp_plan(wsc_spec(st_c4))
  expect_warning(smp_plan_union(list(a, c4)), class = "vofi_warning_correlation")
  expect_error(smp_plan_union(list(a, "x")), class = "vofi_error_input")
})
