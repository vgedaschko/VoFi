# Batch- und Reproduzierbarkeitstests (Integrator; Spec 00 Abschnitt 15.5).
# Die Tests werden übersprungen, solange die benötigten Funktionen Stubs sind (Phase 0), und
# laufen automatisch, sobald die Eigentümer (WS-A, WS-C, WS-D, WS-F, WS-G) geliefert haben.

batch_scenario <- function(block_size = 7L, n_sim = 7L, degenerate = FALSE, extra_param = FALSE,
                           reorder = FALSE, correlate = FALSE) {
  rent <- if (degenerate) {
    list(target = "components.rent.amount_eur", dist = "triangular", min = 9000, mode = 9000,
         max = 9000)
  } else {
    list(target = "components.rent.amount_eur", dist = "triangular", min = 8000, mode = 9000,
         max = 10500)
  }
  cost <- list(target = "components.opex.amount_eur", dist = "uniform",
               min = if (degenerate) 1500 else 1000, max = if (degenerate) 1500 else 2000)
  params <- list(rent = rent, opex = cost)
  if (extra_param) {
    params$rate <- list(target = "financing.bank.rate_pa", dist = "uniform", min = 0.03,
                        max = 0.05)
  }
  if (reorder) params <- rev(params)
  stoch <- list(
    settings = list(n_sim = n_sim, seed = 20261025L, sampling = "lhs", block_size = block_size,
                    store = "full"),
    parameters = params,
    processes = list(rent_growth = list(target = "market.rent_growth", type = "ar1",
                                        mu = 0.015, phi = 0.5,
                                        sigma = if (degenerate) 0 else 0.01))
  )
  if (correlate) {
    pairs <- list(list("rent", "opex", 0.5))
    if (reorder) pairs <- list(list("opex", "rent", 0.5))
    stoch$correlations <- list(parameters = pairs)
  }
  vofi_scenario(list(
    schema_version = 1L,
    meta = list(scenario_id = "batch", title = "Batch-Test"),
    project = list(perspective = "wu_privat", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 5L),
    components = list(
      inv = list(type = "custom_series", label = "Investition",
                 values = c(-100000, 0, 0, 0, 0, 0)),
      rent = list(type = "recurring", label = "Miete", category = "rent", amount_eur = 9000,
                  growth = list(ref = "market.rent_growth"), base_date = as.Date("2027-01-01"),
                  from = as.Date("2027-01-01")),
      opex = list(type = "recurring", label = "Kosten", category = "operating_cost",
                  direction = "outflow", amount_eur = 1500, base_date = as.Date("2027-01-01"),
                  from = as.Date("2027-01-01"))
    ),
    financing = list(
      ek = list(type = "equity", amount_eur = 40000),
      bank = list(type = "bullet_loan", amount_eur = 60000, rate_pa = 0.04, term_years = 5,
                  payments_per_year = 1L)
    ),
    accounts = list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08, overdraft_limit_eur = Inf,
                    surplus_order = c("od_repay", "dep_invest"),
                    deficit_order = c("dep_withdraw", "od_draw", "equity_call")),
    market = list(rent_growth = 0.015, inflation = 0.02),
    analysis = list(kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value")),
    stochastic = stoch
  ))
}

batch_model <- function(...) vofi_build(batch_scenario(...))

expect_same_ledger_row <- function(batch, single, i, tol = 1e-12) {
  for (k in batch$rows$key) {
    a <- batch$values[[k]][i, ]
    b <- single$values[[k]][1L, ]
    testthat::expect_true(all(abs(a - b) <= tol * pmax(1, abs(a))), info = k)
  }
}

test_that("1. Lauf i im Batch = Einzellauf i (vofi_sim)", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_mc", "vofi_sim")
  mc <- vofi_mc(batch_model(), n_sim = 7L, block_size = 7L, seed = 20261025L, store = "full")
  for (i in seq_len(7L)) expect_same_ledger_row(mc$ledger, vofi_sim(mc, i)$ledger, i)
})

test_that("2. Entartung: jeder MC-Lauf = deterministischer Lauf", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_run", "vofi_mc")
  model <- batch_model(degenerate = TRUE)
  det <- vofi_run(model)
  mc <- vofi_mc(model, n_sim = 7L, block_size = 7L, seed = 1L, store = "kpi")
  for (k in c("terminal_value", "delta_terminal_value")) {
    expect_true(all(abs(mc$kpis[[k]] - det$kpis[[k]]) <= 1e-10 * max(1, abs(det$kpis[[k]]))),
                info = k)
  }
})

test_that("3. Chunk-Invarianz und Parallelisierung", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_mc")
  model <- batch_model(n_sim = 14L)
  a <- vofi_mc(model, n_sim = 14L, block_size = 7L, seed = 5L, store = "kpi", chunk_size = 7L)
  b <- vofi_mc(model, n_sim = 14L, block_size = 7L, seed = 5L, store = "kpi", chunk_size = 14L)
  expect_identical(a$kpis, b$kpis)
  skip_on_cran()
  skip_if_not(requireNamespace("future", quietly = TRUE) &&
                requireNamespace("future.apply", quietly = TRUE))
  oplan <- future::plan(future::multisession, workers = 2L)
  on.exit(future::plan(oplan), add = TRUE)
  p <- vofi_mc(model, n_sim = 14L, block_size = 7L, seed = 5L, store = "kpi", chunk_size = 7L,
               parallel = TRUE)
  expect_identical(p$kpis, a$kpis)
})

test_that("4. Reproduzierbarkeit, RNG-Hygiene, zus\u00e4tzlicher Overlay-Parameter", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_mc")
  withr::local_seed(99)
  before <- .Random.seed
  model <- batch_model()
  a <- vofi_mc(model, n_sim = 7L, block_size = 7L, seed = 11L, store = "kpi")
  b <- vofi_mc(model, n_sim = 7L, block_size = 7L, seed = 11L, store = "kpi")
  c2 <- vofi_mc(model, n_sim = 7L, block_size = 7L, seed = 12L, store = "kpi")
  expect_identical(a$kpis, b$kpis)
  expect_false(identical(a$kpis$terminal_value, c2$kpis$terminal_value))
  expect_identical(.Random.seed, before)
  e <- vofi_mc(batch_model(extra_param = TRUE), n_sim = 7L, block_size = 7L, seed = 11L,
               store = "kpi")
  shared <- setdiff(intersect(names(a$inputs), names(e$inputs)), "sim")
  expect_true(length(shared) >= 2L)
  for (k in shared) expect_identical(a$inputs[[k]], e$inputs[[k]], info = k)
})

test_that("5. CRN: zwei identische Varianten ergeben Differenz exakt 0", {
  skip_if_stub("vofi_scenario", "vofi_compare")
  sc <- batch_scenario()
  sc$variants <- list(gleich = list(label = "identisch", set = list()))
  cmp <- vofi_compare(sc, variants = "gleich", baseline = "base", n_sim = 7L, seed = 3L,
                      store = "kpi")
  expect_true(all(cmp$differences$delta_vs_reference == 0))
})

test_that("6. Rasterinvarianz der Kredite (Jahresannuit\u00e4t, Bauphase monatlich)", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_run")
  mk <- function(grid) {
    sc <- batch_scenario()
    sc$stochastic <- list()
    sc$grid <- grid
    sc$financing$bank <- list(type = "annuity_loan", amount_eur = 60000, rate_pa = 0.04,
                              term_years = 5, payments_per_year = 1L)
    vofi_run(vofi_build(sc))
  }
  a <- mk(list())
  m <- mk(list(construction_months = 9L, construction_step_months = 1L))
  ga <- a$grid
  gm <- m$grid
  for (k in c("loan_bank_repay", "loan_bank_interest", "loan_bank_draw")) {
    for (y in unique(ga$year[-1L])) {
      sa <- sum(a$ledger$values[[k]][1L, -1L][ga$year[-1L] == y])
      sm <- sum(m$ledger$values[[k]][1L, -1L][gm$year[-1L] == y])
      expect_equal(sm, sa, tolerance = 1e-9, info = paste(k, y))
    }
  }
  ends_a <- a$ledger$values$loan_bank_balance[1L, ga$date_end %in% gm$date_end]
  ends_m <- m$ledger$values$loan_bank_balance[1L, gm$date_end %in% ga$date_end]
  expect_equal(ends_m, ends_a, tolerance = 1e-9)
})

test_that("7. Kanonische Ordnung im Sampler; Mindestblockgr\u00f6\u00dfe", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_mc")
  a <- vofi_mc(batch_model(correlate = TRUE), n_sim = 7L, block_size = 7L, seed = 2L,
               store = "kpi")
  b <- vofi_mc(batch_model(correlate = TRUE, reorder = TRUE), n_sim = 7L, block_size = 7L,
               seed = 2L, store = "kpi")
  expect_identical(a$inputs[order(names(a$inputs))], b$inputs[order(names(b$inputs))])
  withr::with_collate("C", {
    c1 <- vofi_mc(batch_model(correlate = TRUE), n_sim = 7L, block_size = 7L, seed = 2L,
                  store = "kpi")
  })
  expect_identical(c1$inputs, a$inputs)
  expect_error(vofi_mc(batch_model(correlate = TRUE, block_size = 2L, n_sim = 2L), n_sim = 2L,
                       block_size = 2L, seed = 2L), class = "vofi_error_input")
})

test_that("8. Instrument-Cache: gleiches Ergebnis wie erzwungene Neuberechnung", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_run")
  sc <- batch_scenario()
  sc$stochastic <- list()
  a <- vofi_run(vofi_build(sc))
  sc$accounts$surplus_order <- c("od_repay", "loan_prepay", "dep_invest")
  b <- suppressWarnings(vofi_run(vofi_build(sc)))
  expect_identical(a$ledger$values$net_position, b$ledger$values$net_position)
  expect_identical(a$kpis$terminal_value, b$kpis$terminal_value)
})

test_that("9. Pr\u00e4fix-Stabilit\u00e4t der Bl\u00f6cke (R-73)", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_mc")
  model <- batch_model(block_size = 200L, n_sim = 1000L)
  expect_error(vofi_mc(model, n_sim = 1100L, block_size = 200L, seed = 4L),
               class = "vofi_error_input")
  skip_on_cran()
  small <- vofi_mc(model, n_sim = 1000L, block_size = 200L, seed = 4L, store = "kpi")
  big <- vofi_mc(model, n_sim = 10000L, block_size = 200L, seed = 4L, store = "kpi")
  cols <- setdiff(names(small$kpis), "sim")
  expect_identical(big$kpis[seq_len(1000L), cols], small$kpis[, cols])
})

test_that("10. Feste Kreditbetr\u00e4ge bei amount_eur: auto (R-69)", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_run", "vofi_mc")
  sc <- batch_scenario()
  sc$financing$bank$amount_eur <- "auto"
  sc$stochastic$parameters$inv <- list(target = "components.rent.amount_eur",
                                       dist = "uniform", min = 8500, max = 9500)
  model <- vofi_build(sc)
  det <- vofi_run(model)
  mc <- vofi_mc(model, n_sim = 7L, block_size = 7L, seed = 8L, store = "full")
  d0 <- det$ledger$values$loan_bank_draw[1L, ]
  for (i in seq_len(7L)) expect_identical(mc$ledger$values$loan_bank_draw[i, ], d0)
})

test_that("11. Entscheidungsknoten: Kompositum = getrennte Rechnung (R-71)", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_mc", "vofi_compare")
  skip(paste("ben\u00f6tigt F\u00f6rder-Expander mit fallback_variant (WS-E2);",
             "Integrator erg\u00e4nzt den Test nach Welle 3"))
})
