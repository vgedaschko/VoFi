# Tests für R/mc.R (WS-G; Spec 00 Abschnitte 9.2, 9.9, 9.11, 11.4, 12.7, 13.2, 15.5, 15.6;
# Spec 01 Teil C 1.2, 6.1, 6.2).

grob_model <- function(kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value",
                                "roe_mirr", "payback_time")) {
  sc <- vofi_read_scenario(vofi_example("grob_lehrbuch_a"))
  wsg_quiet(vofi_build(sc, overrides = list(analysis = list(kpis = kpis))))
}

test_that("Argumentprüfung: Modell, Seed, Vielfaches der Blockgröße, store, keep_runs", {
  m <- grob_model()
  expect_error(vofi_mc(list()), class = "vofi_error_input")
  expect_error(vofi_mc(m, n_sim = 1100L, seed = 1L), class = "vofi_error_input")
  expect_error(vofi_mc(m, n_sim = 1L, seed = 1L), class = "vofi_error_input")
  expect_error(vofi_mc(m, n_sim = 200L, seed = 0), class = "vofi_error_input")
  expect_error(vofi_mc(m, n_sim = 200L, store = "alles"), class = "vofi_error_input")
  expect_error(vofi_mc(m, n_sim = 200L, keep_runs = "median"), class = "vofi_error_input")
  expect_error(vofi_mc(m, n_sim = 200L, parallel = NA), class = "vofi_error_input")
  expect_error(vofi_mc(m, n_sim = 200L, chunk_size = 0L), class = "vofi_error_input")
  m2 <- m
  m2$sampler$settings$seed <- NULL
  expect_error(vofi_mc(m2, n_sim = 200L), class = "vofi_error_input")
  m3 <- m
  m3$sampler <- NULL
  expect_error(vofi_mc(m3, n_sim = 200L), class = "vofi_error_not_implemented")
})

test_that("Ergebnis nach 13.2: Felder, Kennzahlen je Lauf, Bänder, keep_runs, Meta", {
  m <- grob_model()
  mc <- vofi_mc(m, n_sim = 1000L, seed = 20261025L)
  expect_s3_class(mc, "vofi_mc_result")
  for (f in c("spec", "grid", "model", "kpis", "kpi_na", "kpi_series", "inputs", "features",
              "flags", "bands", "runs", "run_index", "deterministic", "stats", "checks",
              "ledger", "decision", "traffic_light", "meta")) {
    expect_true(f %in% names(mc), info = f)
  }
  expect_identical(mc$kpis$sim, seq_len(1000L))
  expect_identical(mc$kpis$block, rep(1:5, each = 200L))
  expect_identical(nrow(mc$kpi_na), 1000L)
  expect_identical(names(mc$kpi_na)[1L], "sim")
  expect_true("rw" %in% names(mc$inputs))
  expect_identical(mc$flags$sim, seq_len(1000L))
  # Bänder: Zeilen q05 ... q95 und mean, Spalten T + 1 (9.9)
  expect_named(mc$bands, c("net_position", "dep_balance", "od_balance"))
  b <- mc$bands$net_position
  expect_identical(rownames(b), c("q05", "q25", "q50", "q75", "q95", "mean"))
  expect_identical(ncol(b), mc$grid$T + 1L)
  # keep_runs: Lauf mit kleinstem Abstand zum Quantil (Gleichstand: kleinster Index)
  x <- mc$kpis$delta_terminal_value
  for (p in c("p05", "p50", "p95")) {
    q <- stats::quantile(x, as.numeric(sub("p", "", p)) / 100, type = 7, names = FALSE)
    expect_identical(unname(mc$run_index[[p]]), which.min(abs(x - q)), info = p)
    expect_s3_class(mc$runs[[p]], "vofi_result")
    expect_equal(mc$runs[[p]]$kpis$delta_terminal_value, x[mc$run_index[[p]]],
                 tolerance = 1e-12)
  }
  expect_s3_class(mc$deterministic, "vofi_result")
  expect_equal(mc$deterministic$kpis$delta_terminal_value, 3726.406978797153, tolerance = 1e-6)
  st <- mc$stats
  expect_identical(names(st), mc_stat_columns())
  expect_identical(st$se_df[st$kpi == "terminal_value"], 4L)
  expect_false(any(st$converged))
  expect_equal(st$deterministic[st$kpi == "delta_terminal_value"], 3726.406978797153,
               tolerance = 1e-6)
  expect_true(all(mc$checks$ok))
  expect_identical(unique(mc$checks$n_runs), 1000L)
  meta <- mc$meta
  expect_identical(meta$mode, "mc")
  expect_identical(meta$n_sim, 1000L)
  expect_identical(meta$seed, 20261025)
  expect_identical(meta$block_size, 200L)
  expect_identical(meta$replicates, 5L)
  expect_identical(meta$sampling, "lhs")
  expect_identical(meta$copula, "iman_conover")
  expect_identical(meta$rng_kind, c("Mersenne-Twister", "Inversion", "Rejection"))
  expect_true(nzchar(meta$plan_hash))
  expect_identical(meta$keep_runs_kpi, "delta_terminal_value")
  expect_true(meta$se_rough)
  expect_true(any(grepl("grob", meta$notes)))
  expect_null(mc$ledger)
  # Ampel (12.9) für die Primärkennzahl delta_terminal_value, Basis mc
  expect_identical(mc$traffic_light$basis, "mc")
  expect_identical(mc$traffic_light$kpi, "delta_terminal_value")
  expect_true(mc$traffic_light$rv_dependent)
  expect_identical(mc$traffic_light$level, "yellow")
})

test_that("Präfix-Stabilität und Chunk-Invarianz (R-73, 9.9, 11.4)", {
  m <- grob_model()
  a <- vofi_mc(m, n_sim = 400L, seed = 5L, store = "kpi", chunk_size = 200L)
  b <- vofi_mc(m, n_sim = 400L, seed = 5L, store = "kpi", chunk_size = 2000L)
  expect_identical(a$kpis, b$kpis)
  expect_identical(a$inputs, b$inputs)
  expect_identical(a$meta$n_chunks, 2L)
  expect_identical(b$meta$n_chunks, 1L)
  c1 <- vofi_mc(m, n_sim = 200L, seed = 5L, store = "kpi")
  expect_identical(c1$kpis, a$kpis[1:200, ])
  # Vorschau = Preset preview: 1.000 Läufe, store kpi, keine keep_runs
  pv <- vofi_mc(m, seed = 5L, preview = TRUE)
  expect_identical(pv$meta$n_sim, 1000L)
  expect_identical(pv$meta$store, "kpi")
  expect_length(pv$runs, 0L)
  expect_true(pv$meta$preview)
  expect_identical(pv$kpis[1:400, ], a$kpis)
  pv2 <- vofi_mc(m, n_sim = 200L, seed = 5L, preview = TRUE, store = "bands")
  expect_identical(pv2$meta$n_sim, 200L)
  expect_identical(pv2$meta$store, "bands")
})

test_that("store kpi / bands / full (9.9, Teil C 6.2)", {
  m <- grob_model()
  k <- vofi_mc(m, n_sim = 200L, seed = 3L, store = "kpi")
  expect_identical(length(k$bands), 0L)
  expect_length(k$runs, 0L)
  expect_null(k$ledger)
  bd <- vofi_mc(m, n_sim = 400L, seed = 3L, store = "bands",
                bands = c("net_position", "opp_net_position", "equity_calls", "wealth"),
                keep_runs = "p50")
  f <- vofi_mc(m, n_sim = 400L, seed = 3L, store = "full", chunk_size = 200L,
               bands = c("net_position", "opp_net_position", "equity_calls", "wealth"),
               keep_runs = "p50")
  expect_identical(f$kpis, bd$kpis)
  expect_equal(f$bands, bd$bands, tolerance = 1e-12)
  expect_identical(f$ledger$n, 400L)
  expect_identical(dim(f$opportunity$BS), c(400L, m$grid$T + 1L))
  expect_identical(length(f$opportunity$EW), 400L)
  expect_s3_class(f$draws, "vofi_draws")
  expect_identical(f$draws$n, 400L)
  expect_identical(f$draws$sims, seq_len(400L))
  expect_identical(f$draws$static$rw, f$inputs$rw)
  expect_equal(f$opportunity$EW, f$kpis$terminal_value_opp, tolerance = 1e-12)
  # Lauf i im Batch = vofi_sim(i) (15.5 Nr. 1), auch im zweiten Chunk
  for (i in c(3L, 277L)) {
    one <- vofi_sim(f, i)
    for (key in f$ledger$rows$key) {
      expect_identical(one$ledger$values[[key]][1L, ], f$ledger$values[[key]][i, ], info = key)
    }
  }
  expect_named(f$runs, "p50")
})

test_that("vofi_run(n_sim > 1) delegiert an vofi_mc() (9.2)", {
  m <- grob_model()
  r <- vofi_run(m, n_sim = 200L, seed = 9L, store = "kpi")
  d <- vofi_mc(m, n_sim = 200L, seed = 9L, store = "kpi")
  expect_identical(r$kpis, d$kpis)
  r2 <- vofi_run(m, n_sim = 200L, seed = 9L)
  expect_identical(r2$meta$store, "bands")
})

test_that("MC-Kennzahlen: ausdrücklich angefordert alle, sonst MC-Default (12.3, R-51)", {
  sc <- vofi_read_scenario(vofi_example("grob_lehrbuch_a"))
  m <- wsg_quiet(vofi_build(sc))
  expect_true("withdrawal_equivalent" %in% names(m$kpis))
  expect_true(mc_kpis_explicit(m$spec))
  expect_true("withdrawal_equivalent" %in% mc_kpi_names(m))
  m2 <- m
  m2$spec$analysis$kpis <- "default"
  expect_false(mc_kpis_explicit(m2$spec))
  sel <- mc_kpi_names(m2, "delta_terminal_value")
  expect_false("withdrawal_equivalent" %in% sel)
  expect_false("roe_irr" %in% sel)
  expect_true(all(c("terminal_value", "delta_terminal_value", "roe_mirr") %in% sel))
  mm <- vofi_mc(m2, n_sim = 200L, seed = 2L, store = "kpi")
  expect_false("withdrawal_equivalent" %in% names(mm$kpis))
  expect_true("withdrawal_equivalent" %in% names(mm$deterministic$kpis))
  # Auswahlkennzahl für keep_runs fehlt: Hinweis und Primärkennzahl
  m3 <- grob_model(c("terminal_value", "terminal_value_opp", "delta_terminal_value"))
  m3$sampler$settings$keep_runs_kpi <- "roe_mirr"
  expect_message(r3 <- vofi_mc(m3, n_sim = 200L, seed = 2L, keep_runs = "p50"),
                 class = "vofi_message")
  expect_identical(r3$meta$keep_runs_kpi, "delta_terminal_value")
})

test_that("Meldungen über Chunks zusammengefasst; Markierungen einmal je Lauf (9.8, 2.9)", {
  out <- mc_run_chunks(list(1L, 2L, 3L), function(b) {
    vofi_inform("mc.parallel_dev")
    vofi_warn("mc.compare.unequal", n = 1L, .class = "vofi_warning_plausibility")
    b
  })
  expect_length(out$conditions, 6L)
  expect_identical(unlist(out$chunks), 1:3)
  n_msg <- 0L
  n_warn <- 0L
  withCallingHandlers(mc_emit_conditions(out$conditions),
                      vofi_message = function(m) {
                        n_msg <<- n_msg + 1L
                        invokeRestart("muffleMessage")
                      },
                      vofi_warning = function(w) {
                        n_warn <<- n_warn + 1L
                        invokeRestart("muffleWarning")
                      })
  expect_identical(c(n_msg, n_warn), c(1L, 1L))
  # Strafzinstranche in allen Läufen zweier Chunks: genau eine Warnung limit_breach
  sc <- wsg_scenario(flows = c(-100000, -20000, 9000, 9000, 9000), loan = FALSE,
                     accounts = list(overdraft_limit_eur = 0, penalty_spread_pa = 0.02,
                                     deficit_order = c("dep_withdraw", "od_draw",
                                                       "penalty_rate")),
                     shared = list(f = 30000), final = list(ref = "shared.f"),
                     stochastic = list(settings = list(seed = 3L, block_size = 200L),
                                       parameters = list(f = list(target = "shared.f",
                                                                  dist = "uniform",
                                                                  min = 20000,
                                                                  max = 40000))))
  m <- wsg_quiet(vofi_build(sc))
  keys <- character(0)
  withCallingHandlers(vofi_mc(m, n_sim = 400L, chunk_size = 200L, store = "kpi"),
                      vofi_warning = function(w) {
                        keys <<- c(keys, w$key)
                        invokeRestart("muffleWarning")
                      },
                      vofi_message = function(m) invokeRestart("muffleMessage"))
  expect_identical(sum(keys == "engine.flags.limit_breach"), 1L)
})

test_that("Ü3-Hinweis (loan_prepay) einmal je Lauf", {
  sc <- wsg_scenario(accounts = list(surplus_order = c("od_repay", "loan_prepay",
                                                       "dep_invest")),
                     shared = list(f = 30000), final = list(ref = "shared.f"),
                     stochastic = list(settings = list(seed = 3L, block_size = 200L),
                                       parameters = list(f = list(target = "shared.f",
                                                                  dist = "uniform",
                                                                  min = 20000,
                                                                  max = 40000))))
  sc$financing$bank$prepay_allowed <- TRUE
  m <- wsg_quiet(vofi_build(sc))
  keys <- character(0)
  withCallingHandlers(vofi_mc(m, n_sim = 400L, chunk_size = 200L, store = "kpi"),
                      vofi_warning = function(w) {
                        keys <<- c(keys, w$key)
                        invokeRestart("muffleWarning")
                      },
                      vofi_message = function(m) invokeRestart("muffleMessage"))
  expect_identical(sum(keys == "engine.prepay_heuristic"), 1L)
})

test_that("Speicherschätzung über vofi.max_memory_gb: vofi_warning_memory", {
  m <- grob_model()
  local_vofi_options(vofi.max_memory_gb = 1e-9)
  expect_warning(vofi_mc(m, n_sim = 200L, seed = 1L, store = "kpi"),
                 class = "vofi_warning_memory")
})

test_that("Kennzahlreihen: Quantile, Mittel und NA-Anteil je Jahr (13.2)", {
  v <- cbind(c(1, 2, 3, 4, NA), c(NA, NA, NA, NA, NA), c(5, 5, 5, 5, 5))
  s <- mc_series_summary(list(r = list(values = v, years = 2028:2030)), c(0.05, 0.5, 0.95))
  expect_identical(rownames(s$r$quantiles), c("q05", "q50", "q95"))
  q_ref <- stats::quantile(1:4, c(0.05, 0.5, 0.95), type = 7, names = FALSE)
  expect_equal(unname(s$r$quantiles[, 1L]), q_ref)
  expect_true(all(is.na(s$r$quantiles[, 2L])))
  expect_equal(s$r$mean, c(2.5, NA, 5))
  expect_equal(s$r$na_share, c(0.2, 1, 0))
  expect_identical(s$r$years, 2028:2030)
  expect_null(s$r$values)
  s2 <- mc_series_summary(list(r = list(values = v, years = 2028:2030)), 0.5, TRUE)
  expect_identical(s2$r$values, v)
})

test_that("Kompositum: zeilenweise Auswahl, Ledger mit Zeilen der Vereinigung (9.11 Nr. 4)", {
  sel <- c(TRUE, FALSE, TRUE)
  expect_identical(mc_pick_vec(1:3, 4:6, sel), c(1L, 5L, 3L))
  mv <- matrix(1, 3, 2)
  mf <- matrix(2, 3, 2)
  expect_identical(mc_pick_mat(mv, mf, sel)[, 1L], c(1, 2, 1))
  d <- mc_pick_df(data.frame(a = 1:3, b = c("x", "y", "z")),
                  data.frame(a = 4:6, c = 7:9), sel)
  expect_identical(d$a, c(1L, 5L, 3L))
  expect_identical(d$b, c("x", NA, "z"))
  expect_identical(d$c, c(NA, 8L, NA))
  r <- vofi_run(grob_model())
  lv <- r$ledger
  lf <- ledger_subset_sims(lv, c(1L, 1L, 1L))
  lv <- lf
  drop <- "loan_bul_draw"
  keep <- lv$rows$key != drop
  lf$rows <- lf$rows[keep, , drop = FALSE]
  lf$values <- lf$values[keep]
  lv$values <- lapply(lv$values, function(m) m * 2)
  out <- mc_pick_ledger(lv, lf, sel)
  expect_identical(out$rows$key, lv$rows$key)
  expect_identical(out$values[[drop]][2L, ], rep(0, lv$T + 1L))
  expect_identical(out$values[[drop]][1L, ], lv$values[[drop]][1L, ])
  k <- lv$rows$key[1L]
  expect_identical(out$values[[k]][2L, ], lf$values[[k]][2L, ])
})

test_that("Entscheidungsknoten: Kompositum = getrennte Rechnung, bedingte Statistik", {
  sc <- wsg_decision_scenario(n_sim = 400L, p = 0.6)
  m <- wsg_quiet(vofi_build(sc))
  expect_false(is.null(m$decision))
  mc <- wsg_quiet(vofi_mc(m, n_sim = 400L, seed = 11L, store = "kpi"))
  expect_identical(names(mc$kpis)[1:3], c("sim", "block", "branch"))
  b <- mc$kpis$branch
  expect_true(all(b %in% c(0L, 1L)))
  # LHS: Anteil der Zusagen je Block weicht höchstens 1/m von p ab
  share <- tapply(b, mc$kpis$block, mean)
  expect_true(all(abs(share - 0.6) <= 1 / 200 + 1e-12))
  expect_equal(mc$decision$share_approved, mean(b == 1L))
  expect_identical(mc$decision$key, "funding.f.approved")
  expect_identical(mc$decision$fallback_variant, "ohne")
  expect_equal(mc$decision$p_approval, 0.6)
  # getrennte Rechnung mit denselben Rohziehungen
  cfg <- mc_config(m, n_sim = 400L, seed = 11L, store = "kpi")
  raw <- smp_sample(cfg$union, 1:2, 11L)
  cv <- eng_run_chunk(cfg$model, 1:2, 11L, "mc", "kpi", raw = raw)
  cf <- eng_run_chunk(cfg$model$decision$fallback, 1:2, 11L, "mc", "kpi", raw = raw)
  want <- ifelse(b == 1L, cv$kpis$delta_terminal_value, cf$kpis$delta_terminal_value)
  expect_identical(mc$kpis$delta_terminal_value, want)
  expect_false(isTRUE(all.equal(cv$kpis$delta_terminal_value, cf$kpis$delta_terminal_value)))
  # bedingte Statistik: Variante "mit Zusage" bzw. Ausweichvariante über alle Läufe
  sa <- mc$decision$stats_approved
  expect_equal(sa$mean[sa$kpi == "delta_terminal_value"], mean(cv$kpis$delta_terminal_value))
  sf <- mc$decision$stats_fallback
  expect_equal(sf$mean[sf$kpi == "delta_terminal_value"], mean(cf$kpis$delta_terminal_value))
  # = Statistik der getrennten MC von V
  mv <- m
  mv$decision <- NULL
  mcv <- wsg_quiet(vofi_mc(mv, n_sim = 400L, seed = 11L, store = "kpi"))
  expect_equal(mcv$stats$mean, sa$mean)
  expect_equal(mcv$stats$q50, sa$q50)
  # vofi_sim liefert den realisierten Zweig
  for (i in c(which(b == 1L)[1L], which(b == 0L)[1L])) {
    one <- wsg_quiet(vofi_sim(mc, i))
    expect_equal(one$kpis$delta_terminal_value, mc$kpis$delta_terminal_value[i],
                 tolerance = 1e-12)
    expect_identical(one$decision$branch, b[i])
  }
  # deterministisch: realisierter Zweig = Zusage (Basiswert 1), Alternative in decision
  expect_identical(mc$deterministic$decision$branch, 1L)
  expect_s3_class(mc$deterministic$decision$alternative, "vofi_result")
})

test_that("Entscheidungsknoten mit store = full: Ledger des Kompositums", {
  sc <- wsg_decision_scenario(n_sim = 200L, p = 0.5)
  m <- wsg_quiet(vofi_build(sc))
  mc <- wsg_quiet(vofi_mc(m, n_sim = 200L, seed = 4L, store = "full", keep_runs = "p50"))
  b <- mc$kpis$branch
  expect_identical(mc$ledger$n, 200L)
  expect_true(all(mc$checks$ok))
  ew <- mc$ledger$values$net_position[, mc$grid$T + 1L]
  expect_equal(ew, mc$kpis$terminal_value, tolerance = 1e-9)
  zus <- mc$ledger$values$zus__value[, 1L]
  expect_true(all(zus[b == 0L] == 0))
  expect_true(all(zus[b == 1L] == 20000))
  expect_identical(names(mc$runs), "p50")
})

test_that("parallel = TRUE über future.apply: Ergebnis identisch (9.9, R-28)", {
  skip_if_not_installed("future")
  skip_if_not_installed("future.apply")
  m <- grob_model()
  a <- vofi_mc(m, n_sim = 400L, seed = 5L, store = "kpi", chunk_size = 200L)
  # Plan im selben Prozess: geht auch im Entwicklungsmodus über future_lapply()
  oplan <- future::plan(future::sequential)
  on.exit(future::plan(oplan), add = TRUE)
  expect_true(mc_future_inprocess())
  calls <- 0L
  orig <- future.apply::future_lapply
  testthat::local_mocked_bindings(
    future_lapply = function(...) {
      calls <<- calls + 1L
      orig(...)
    },
    .package = "future.apply"
  )
  p <- vofi_mc(m, n_sim = 400L, seed = 5L, store = "kpi", chunk_size = 200L, parallel = TRUE)
  expect_identical(calls, 1L)
  expect_identical(p$meta$n_chunks, 2L)
  expect_identical(p$kpis, a$kpis)
  expect_identical(p$inputs, a$inputs)
})

test_that("parallel = TRUE mit Workern in eigenen Prozessen (installiertes Paket)", {
  skip_on_cran()
  skip_if_not_installed("future")
  skip_if_not_installed("future.apply")
  skip_if(mc_dev_mode(), "Entwicklungsmodus: Worker sehen den Namespace nicht")
  m <- grob_model()
  a <- vofi_mc(m, n_sim = 400L, seed = 5L, store = "kpi", chunk_size = 200L)
  oplan <- future::plan(future::multisession, workers = 2L)
  on.exit(future::plan(oplan), add = TRUE)
  p <- vofi_mc(m, n_sim = 400L, seed = 5L, store = "kpi", chunk_size = 200L, parallel = TRUE)
  expect_identical(p$kpis, a$kpis)
  expect_identical(p$inputs, a$inputs)
})

# ---------------------------------------------------------------------------------------------
# Leistung (9.10, 15.6; skip_on_cran())
# ---------------------------------------------------------------------------------------------

# Markierungen (Strafzinstranche in einem Teil der Läufe) sind hier erwartet
wsg_bench_mc <- function(m, n = 10000L) {
  suppressWarnings(wsg_quiet(vofi_mc(m, n_sim = n, seed = 20261025L, store = "bands",
                                     keep_runs = character(0))))
}

test_that("9.10: MC 10.000 x 53 Perioden inkl. KPIs, Unterlassung, Bänder (< 1,5 s)", {
  wsg_perf_skip()
  m <- wsg_quiet(vofi_build(wsg_bench_scenario(53L)))
  expect_identical(m$grid$T, 53L)
  ms <- wsg_cpu_ms(function() wsg_bench_mc(m))
  expect_lt(ms, 1500 * wsg_perf_factor(), label = sprintf("MC 10.000 x 53 %.0f ms", ms))
})

test_that("9.10: MC 10.000 x 83 Perioden (< 3 s) und Spitzenspeicher mit bands (< 1 GB)", {
  wsg_perf_skip()
  m <- wsg_quiet(vofi_build(wsg_bench_scenario(83L)))
  expect_identical(m$grid$T, 83L)
  invisible(gc(reset = TRUE))
  ms <- wsg_cpu_ms(function() wsg_bench_mc(m))
  peak_mb <- sum(gc()[, 6L])
  expect_lt(ms, 3000 * wsg_perf_factor(), label = sprintf("MC 10.000 x 83 %.0f ms", ms))
  expect_lt(peak_mb, 1024, label = sprintf("Spitzenspeicher %.0f MB", peak_mb))
})

test_that("9.10: Entscheidungsknoten <= 2 x Budget der Variante ohne Knoten (2.000 x 53)", {
  wsg_perf_skip()
  md <- wsg_quiet(vofi_build(wsg_bench_scenario(53L, decision = TRUE)))
  expect_false(is.null(md$decision))
  ms <- wsg_cpu_ms(function() wsg_bench_mc(md, 2000L))
  expect_lt(ms, 2 * 1500 / 5 * wsg_perf_factor(),
            label = sprintf("MC mit Knoten 2.000 x 53 %.0f ms", ms))
})
