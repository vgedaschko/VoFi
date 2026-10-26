# Tests für R/engine-store.R (WS-D; Spec 00 Abschnitte 9.2, 9.9, 12.2): Rückgabepfade, Vermögen
# mit Restwertpfad, Chunkplan, Sammler mit Quantilbändern, keep_runs, Speicherschätzung.

store_chunk <- function(model, f, store = "full", bands = NULL) {
  g <- model$grid
  targets <- data.frame(key = "components.z.values", target = "components.z.values",
                        kind = "static", apply = "multiply", stringsAsFactors = FALSE)
  dr <- new_vofi_draws("mc", n = length(f), sims = seq_along(f), blocks = 1L,
                       block_size = length(f), static = list("components.z.values" = f),
                       targets = targets, years = g$years)
  eng_run_draws(model, draws = dr, store = store, bands = bands,
                return_paths = c("net_position", "wealth"))
}

test_that("Pfadnamen, Berichtsmodus, Vermögen mit Restwertpfad (12.2, R-72)", {
  expect_identical(eng_path_names(), c("net_position", "opp_net_position", "wealth",
                                       "dep_balance", "od_balance", "equity_calls"))
  expect_identical(eng_report_mode(list(project = list(perspective = "wu_privat"))), "expert")
  expect_identical(eng_report_mode(list(project = list(perspective = "selbstnutzer"))),
                   "household")
  pr <- list(project = list(report_mode = "expert", perspective = "selbstnutzer"))
  expect_identical(eng_report_mode(pr), "expert")
  sc <- wsd_scenario(c(-100000, 0, 0), ek = list(type = "equity", amount_eur = 100000),
                     components = list(rwp = list(type = "custom_series", section = "memo",
                                                  category = "residual_path",
                                                  values = c(90000, 80000, 70000))))
  model <- vofi_build(sc)
  core <- wsd_parts(model)$core
  w <- eng_wealth(model, core)
  bs <- core$stocks$BS
  # ohne Kennzeichnung rv_basis wirkt der Pfad nicht; W_T = BS_T
  expect_equal(w[, 3L], bs[, 3L])
})

test_that("eng_store_chunk: full mit Ledger und Ziehungen, bands, kpi", {
  model <- vofi_build(wsd_scenario(c(-100000, 30000, 40000, 80000),
                                   ek = list(type = "equity", amount_eur = 100000)))
  full <- store_chunk(model, c(0.9, 1, 1.1))
  expect_s3_class(full$ledger, "vofi_ledger")
  expect_s3_class(full$draws, "vofi_draws")
  expect_identical(names(full$paths), c("net_position", "wealth"))
  expect_identical(full$sims, 1:3)
  expect_false(is.null(full$opp$ledger))
  b <- store_chunk(model, c(0.9, 1, 1.1), store = "bands")
  expect_null(b$ledger)
  expect_null(b$draws)
  expect_null(b$opp$ledger)
  expect_identical(names(b$band_values), c("net_position", "dep_balance", "od_balance"))
  k <- store_chunk(model, c(0.9, 1, 1.1), store = "kpi")
  expect_length(k$band_values, 0L)
  expect_null(k$ledger)
})

test_that("eng_chunk_plan: ganze Blöcke, mindestens ein Block, Fehler bei Rest", {
  expect_identical(eng_chunk_plan(1000L, 200L, 500L), list(1:2, 3:4, 5L))
  expect_identical(eng_chunk_plan(400L, 200L, 50L), list(1L, 2L))
  expect_identical(eng_chunk_plan(400L, 200L, 5000L), list(1:2))
  e <- expect_error(eng_chunk_plan(450L, 200L), class = "vofi_error_input")
  expect_match(conditionMessage(e), "600", fixed = TRUE)
})

test_that("Sammler: Kennzahlen mit sim und block, Quantilbänder je Spalte, Prüfungen", {
  model <- vofi_build(wsd_scenario(c(-100000, 30000, 40000, 80000),
                                   ek = list(type = "equity", amount_eur = 100000)))
  f1 <- c(0.9, 1, 1.1)
  f2 <- c(1.2, 0.8, 1.05)
  c1 <- store_chunk(model, f1, store = "bands")
  c2 <- store_chunk(model, f2, store = "bands")
  c2$sims <- 4:6
  c2$blocks <- 2L
  acc <- eng_store_init("bands")
  eng_store(acc, c1)
  eng_store(acc, c2)
  out <- eng_store_finalize(acc)
  expect_identical(out$kpis$sim, 1:6)
  expect_identical(out$kpis$block, rep(1:2, each = 3L))
  expect_identical(nrow(out$flags), 6L)
  bs <- rbind(c1$band_values$net_position, c2$band_values$net_position)
  q <- out$bands$net_position
  expect_identical(rownames(q), c("q05", "q25", "q50", "q75", "q95", "mean"))
  expect_equal(q["q50", ], apply(bs, 2L, stats::quantile, 0.5, type = 7, names = FALSE))
  expect_equal(q["mean", ], colMeans(bs))
  expect_identical(unique(out$checks$n_runs), 6L)
  expect_true(all(out$checks$ok))
  expect_null(out$ledger)
  expect_identical(dim(out$paths$net_position), c(6L, 4L))
})

test_that("Sammler mit store full: Ledger über Chunks zusammengeführt", {
  model <- vofi_build(wsd_scenario(c(-100000, 30000, 40000, 80000),
                                   ek = list(type = "equity", amount_eur = 100000)))
  c1 <- store_chunk(model, c(0.9, 1))
  c2 <- store_chunk(model, c(1.1, 1.2))
  c2$sims <- 3:4
  acc <- eng_store_init("full")
  eng_store(acc, c1)
  eng_store(acc, c2)
  out <- eng_store_finalize(acc)
  expect_identical(out$ledger$n, 4L)
  expect_equal(out$ledger$values$net_position,
               rbind(c1$ledger$values$net_position, c2$ledger$values$net_position))
  expect_equal(eng_rbind_df(list(data.frame(a = 1), NULL, data.frame(a = 2)))$a, c(1, 2))
  expect_identical(eng_rbind_df(list()), data.frame())
})

test_that("eng_keep_runs: Lauf mit kleinstem Abstand zum Quantil", {
  x <- c(5, 1, 3, 2, 4)
  expect_identical(eng_keep_runs(x, c("p50", "p0", "p99")), c(p50 = 3L, p0 = 2L, p99 = 1L))
  expect_identical(eng_keep_runs(x, character(0)), stats::setNames(integer(0), character(0)))
  expect_error(eng_keep_runs(x, "median"), class = "vofi_error_input")
  expect_identical(unname(eng_keep_runs(c(NA, NA), "p50")), NA_integer_)
})

test_that("Speicherschätzung und Warnung vofi_warning_memory (9.9)", {
  model <- wsd_skeleton()
  est <- eng_memory_estimate(model, 2000L)
  expect_gt(est, 0)
  expect_equal(eng_memory_estimate(model, 4000L), 2 * est)
  withr::local_options(vofi.max_memory_gb = 1e-6)
  expect_warning(eng_check_memory(model, 2000L), class = "vofi_warning_memory")
  withr::local_options(vofi.max_memory_gb = 100)
  expect_silent(gb <- eng_check_memory(model, 2000L))
  expect_equal(gb, est / 1024^3)
})

test_that("eng_decision_values ohne Knoten NULL, sonst Zweig des Basisfalls", {
  model <- wsd_skeleton()
  expect_null(eng_decision_values(model, NULL, 1L))
  model$decision <- list(key = "funding.x.approved", branch = 0L)
  expect_equal(eng_decision_values(model, NULL, 2L), c(0, 0))
})
