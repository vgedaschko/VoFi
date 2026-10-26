# Tests für R/engine-run.R (WS-D; Spec 00 Abschnitte 9.2, 9.9, 9.11, 11.4): vofi_run(),
# eng_run_chunk() mit Sampler-Attrappe (eng_smp_fun), eng_run_draws(), vofi_sim(), Ergebnis.

#' Ziehungen eines Blocks: Faktor auf die Zahlungsfolge z je globalem Lauf
run_block_draws <- function(grid, blocks, m, decision = NULL) {
  sims <- unlist(lapply(blocks, function(b) (b - 1L) * m + seq_len(m)))
  n <- length(sims)
  targets <- data.frame(key = "components.z.values", target = "components.z.values",
                        kind = "static", apply = "multiply", stringsAsFactors = FALSE)
  dec <- list()
  if (!is.null(decision)) {
    dec[["funding.kfw.approved"]] <- rep_len(decision, n)
    targets <- rbind(targets, data.frame(key = "funding.kfw.approved",
                                         target = "funding.kfw.approved", kind = "decision",
                                         apply = "replace", stringsAsFactors = FALSE))
  }
  new_vofi_draws("mc", n = n, sims = sims, blocks = blocks, block_size = m,
                 static = list("components.z.values" = 1 + 0.01 * sims), decision = dec,
                 targets = targets, years = grid$years)
}

#' Sampler-Attrappe für eng_smp_fun()
mock_sampler <- function(m = 3L, decision = NULL) {
  function(name) {
    switch(name,
      smp_draw = function(plan, grid, blocks, seed, mode) run_block_draws(grid, blocks, m),
      smp_design = function(plan, grid, design) {
        n <- nrow(design)
        targets <- data.frame(key = "components.z.values", target = "components.z.values",
                              kind = "static", apply = "multiply", stringsAsFactors = FALSE)
        new_vofi_draws("design", n = n, sims = seq_len(n),
                       static = list("components.z.values" = design$f), targets = targets,
                       years = grid$years)
      },
      smp_sample = function(plan, b, seed) list(b = b),
      smp_plan_union = function(plans) plans[[1L]],
      smp_materialize = function(raw, plan, grid) {
        run_block_draws(grid, raw$b, m, decision = decision)
      },
      stop("unbekannt: ", name)
    )
  }
}

run_model <- function() {
  model <- vofi_build(wsd_scenario(c(-100000, 30000, 40000, 50000),
                                   ek = list(type = "equity", amount_eur = 40000),
                                   accounts = list(overdraft_limit_eur = Inf,
                                                   overdraft_rate_pa = 0.08,
                                                   deposit_rate_pa = 0.02)))
  model$sampler <- list(settings = list(block_size = 3L, seed = 11L))
  model
}

test_that("vofi_run: Gerüst-Sollwerte (Anhang A) und Ergebnisobjekt (13.1)", {
  res <- vofi_run(wsd_skeleton())
  expect_s3_class(res, "vofi_result")
  expect_equal(res$kpis$terminal_value, 52830.80, tolerance = 1e-9)
  expect_equal(res$kpis$terminal_value_opp, 42448.32, tolerance = 1e-9)
  expect_equal(res$kpis$delta_terminal_value, 10382.48, tolerance = 1e-9)
  expect_true(all(abs(res$ledger$values$balance_check) < 1e-9))
  expect_identical(res$meta$mode, "deterministic")
  expect_identical(res$meta$n_sim, 1L)
  expect_identical(res$meta$tax_module, "none")
  expect_identical(res$meta$report_mode, "expert")
  expect_true(all(c("checks", "flags") %in% names(res$opportunity)))
  expect_true(all(res$opportunity$checks$ok))
  expect_error(vofi_run(list()), class = "vofi_error_input")
})

test_that("eng_run_chunk deterministisch: keine Ziehungen, Design verlangt Designzeilen", {
  model <- run_model()
  ch <- eng_run_chunk(model, blocks = 1L, seed = NULL, mode = "deterministic", store = "full")
  expect_identical(ch$n, 1L)
  expect_null(ch$draws)
  expect_error(eng_run_chunk(model, 1L, NULL, mode = "deterministic", raw = list(b = 1)),
               class = "vofi_error_input")
  local_mocked_bindings(eng_smp_fun = mock_sampler())
  expect_error(eng_run_chunk(model, 1L, 1L, mode = "design"), class = "vofi_error_input")
})

test_that("eng_run_chunk MC mit Sampler-Attrappe: Ziehungen, store, Pfade, Bänder", {
  model <- run_model()
  local_mocked_bindings(eng_smp_fun = mock_sampler())
  ch <- eng_run_chunk(model, blocks = 1:2, seed = 11L, mode = "mc", store = "full",
                      return_paths = c("net_position", "opp_net_position", "wealth",
                                       "dep_balance", "od_balance", "equity_calls"))
  expect_identical(ch$n, 6L)
  expect_identical(ch$sims, 1:6)
  expect_identical(ch$blocks, 1:2)
  expect_s3_class(ch$draws, "vofi_draws")
  expect_identical(ch$ledger$n, 6L)
  expect_equal(ch$ledger$values$z__value[, 1L], -100000 * (1 + 0.01 * (1:6)))
  expect_identical(dim(ch$paths$net_position), c(6L, 4L))
  expect_equal(ch$paths$net_position, ch$ledger$values$net_position)
  expect_equal(ch$paths$opp_net_position, ch$opp$BS)
  expect_equal(ch$paths$wealth, ch$paths$net_position)
  expect_equal(ch$paths$equity_calls, ch$ledger$values$equity_call)
  expect_identical(ch$inputs$sim, 1:6)
  expect_equal(ch$inputs[["components.z.values"]], 1 + 0.01 * (1:6))
  expect_true(all(ch$checks$ok))
  expect_true(all(ch$opp$checks$ok))
  bands <- eng_run_chunk(model, blocks = 1L, seed = 11L, mode = "mc", store = "bands",
                         bands = c("net_position", "dep_wht"))
  expect_null(bands$ledger)
  expect_identical(names(bands$band_values), c("net_position", "dep_wht"))
  kp <- eng_run_chunk(model, blocks = 1L, seed = 11L, mode = "mc", store = "kpi",
                      kpis = "terminal_value")
  expect_identical(names(kp$kpis), c("terminal_value", "terminal_value_ex_rv"))
  expect_length(kp$band_values, 0L)
  expect_error(eng_run_chunk(model, 1L, 11L, mode = "mc", return_paths = "unbekannt"),
               class = "vofi_error_input")
  expect_error(eng_run_chunk(model, 1L, 11L, mode = "mc", store = "bands", bands = "nix"),
               class = "vofi_error_input")
  expect_error(eng_run_chunk(model, 1L, NULL, mode = "mc"), class = "vofi_error_input")
})

test_that("Lauf i im Chunk = Lauf i einzeln (CRN, Batch-Invarianz)", {
  model <- run_model()
  local_mocked_bindings(eng_smp_fun = mock_sampler())
  ch <- eng_run_chunk(model, blocks = 1:2, seed = 11L, mode = "mc", store = "full")
  one <- eng_run_chunk(model, blocks = 2L, seed = 11L, mode = "mc", store = "full")
  for (i in 1:3) {
    expect_identical(unname(unlist(ch$kpis[3L + i, ])), unname(unlist(one$kpis[i, ])))
    expect_identical(ch$ledger$values$net_position[3L + i, ],
                     one$ledger$values$net_position[i, ])
  }
})

test_that("Design-Lauf: Designzeilen über smp_design()", {
  model <- run_model()
  local_mocked_bindings(eng_smp_fun = mock_sampler())
  ch <- eng_run_chunk(model, blocks = 1L, seed = NULL, mode = "design", store = "kpi",
                      design = data.frame(f = c(1, 1.1)), kpis = "terminal_value")
  expect_identical(ch$n, 2L)
  base <- vofi_run(model)$kpis$terminal_value
  expect_equal(ch$kpis$terminal_value[1L], base)
  expect_gt(ch$kpis$terminal_value[2L], base)
})

test_that("Fehlender Sampler: vofi_error_not_implemented", {
  model <- run_model()
  model$sampler <- NULL
  expect_error(eng_run_chunk(model, 1L, 1L, mode = "mc"), class = "vofi_error_not_implemented")
  expect_error(eng_smp_fun("gibt_es_nicht"), class = "vofi_error_not_implemented")
})

test_that("extra_rows: exogene Zusatzzeilen gehen in Ausgleich und Ledger ein (9.6 Nr. 6)", {
  model <- run_model()
  rows <- new_ledger_rows("ref__neg", "project", "custom")
  extra <- new_vofi_ledger(rows, list(ref__neg = matrix(c(0, -1000, 0, 0), 1L)), n = 1L,
                           T = model$grid$T)
  ch <- eng_run_chunk(model, 1L, NULL, mode = "deterministic", store = "full",
                      extra_rows = extra)
  base <- eng_run_chunk(model, 1L, NULL, mode = "deterministic", store = "full")
  expect_equal(ch$ledger$values$ref__neg[1L, 2L], -1000)
  expect_lt(ch$kpis$terminal_value, base$kpis$terminal_value)
  expect_true(all(ch$checks$ok))
})

test_that("vofi_sim: Lauf i = Lauf im Batch, nur Block b neu (11.4)", {
  model <- run_model()
  local_mocked_bindings(eng_smp_fun = mock_sampler())
  batch <- eng_run_chunk(model, blocks = 1:2, seed = 11L, mode = "mc", store = "full")
  mc <- structure(list(model = model, kpis = batch$kpis,
                       meta = list(n_sim = 6L, block_size = 3L, seed = 11L)),
                  class = "vofi_mc_result")
  r5 <- vofi_sim(mc, 5L)
  expect_s3_class(r5, "vofi_result")
  expect_identical(r5$meta$sim_index, 5L)
  expect_identical(r5$meta$n_sim, 6L)
  expect_identical(r5$meta$mode, "mc")
  expect_identical(unname(unlist(r5$kpis)), unname(unlist(batch$kpis[5L, ])))
  np <- batch$ledger$values$net_position
  expect_identical(r5$ledger$values$net_position, np[5L, , drop = FALSE])
  expect_error(vofi_sim(mc, 7L), class = "vofi_error_input")
  expect_error(vofi_sim(list(), 1L), class = "vofi_error_input")
  mc$meta$seed <- NULL
  mc$model$sampler$settings$seed <- NULL
  expect_error(vofi_sim(mc, 1L), class = "vofi_error_input")
})

test_that("Entscheidungsknoten: Werte je Lauf und Einzellauf des realisierten Zweigs", {
  sc <- wsd_scenario(c(-100000, 5000, 5000, 110000),
                     ek = list(type = "equity", amount_eur = 100000),
                     accounts = list(overdraft_limit_eur = Inf, overdraft_rate_pa = 0.08))
  raw <- unclass(sc)
  # Pflichtfelder nach Spec 01 Teil B 4.1 bzw. Spec 00 4.11 (siehe test-engine-build.R)
  raw$measures <- list(m1 = list(measure_type = "sonstige", year = 2027L, cost_eur = 1000))
  raw$funding <- list(kfw = list(instrument_type = "grant", measures = list("m1"),
                                 approval_timing = "before_start", fallback_variant = "ohne",
                                 approved = 1))
  raw$variants <- list(ohne = list(label = "Ohne Förderung", remove = "funding.kfw",
                                   replace = list("financing.ek.amount_eur" = 90000)))
  model <- vofi_build(vofi_scenario(raw))
  model$sampler <- list(settings = list(block_size = 3L))
  model$decision$fallback$sampler <- list(settings = list(block_size = 3L))
  local_mocked_bindings(eng_smp_fun = mock_sampler(decision = c(1, 0, 1)))
  raw_b <- list(b = 1L)
  ch <- eng_run_chunk(model, blocks = 1L, seed = 3L, mode = "mc", store = "kpi", raw = raw_b)
  expect_equal(ch$decision, c(1, 0, 1))
  det <- eng_run_chunk(model, blocks = 1L, seed = NULL, mode = "deterministic", store = "kpi")
  expect_equal(det$decision, 1)
  mc <- structure(list(model = model, kpis = ch$kpis,
                       meta = list(n_sim = 3L, block_size = 3L, seed = 3L)),
                  class = "vofi_mc_result")
  r2 <- vofi_sim(mc, 2L)
  expect_identical(r2$decision$branch, 0L)
  expect_equal(r2$ledger$values$ek__in[1L, 1L], 90000)
  expect_equal(r2$decision$alternative$ledger$values$ek__in[1L, 1L], 100000)
  r1 <- vofi_sim(mc, 1L)
  expect_identical(r1$decision$branch, 1L)
  expect_equal(r1$ledger$values$ek__in[1L, 1L], 100000)
})

test_that("eng_chunk_subset und eng_library_version", {
  model <- run_model()
  local_mocked_bindings(eng_smp_fun = mock_sampler())
  ch <- eng_run_chunk(model, blocks = 1L, seed = 11L, mode = "mc", store = "full",
                      return_paths = "net_position")
  one <- eng_chunk_subset(ch, 2L)
  expect_identical(one$n, 1L)
  expect_identical(nrow(one$kpis), 1L)
  expect_identical(one$ledger$n, 1L)
  expect_identical(dim(one$paths$net_position), c(1L, 4L))
  expect_identical(one$opp$EW, ch$opp$EW[2L])
  v <- eng_library_version()
  expect_true(is.character(v) && length(v) == 1L)
})

test_that("Speicher 'bands'/'kpi' im Einzellauf: Hinweis, Ergebnis vollständig", {
  model <- wsd_skeleton()
  m <- testthat::capture_messages(r <- vofi_run(model, store = "kpi"))
  expect_length(m, 1L)
  expect_identical(r$meta$store, "full")
  expect_false(is.null(r$ledger))
})
