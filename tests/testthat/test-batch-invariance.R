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
      # Zahlungsplan statt Periodenreihe: identisch auf dem Jahresraster (-100.000 in t0) und
      # gueltig auf jedem Raster (Test 6 rechnet auch mit monatlicher Bauphase, Spec 00 4.5).
      inv = list(type = "custom_series", label = "Investition",
                 values = list(schedule = list("2027-01-01" = -100000))),
      rent = list(type = "recurring", label = "Miete", category = "rent", amount_eur = 9000,
                  growth = list(ref = "market.rent_growth"), base_date = as.Date("2027-01-01"),
                  start_event = as.Date("2027-01-01")),
      opex = list(type = "recurring", label = "Kosten", category = "operating_cost",
                  direction = "outflow", amount_eur = 1500, base_date = as.Date("2027-01-01"),
                  start_event = as.Date("2027-01-01"))
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

#' Zeile i des Batch-Ledgers = Einzellauf; tol = 0 (Default) verlangt Identität (15.5 Nr. 1)
expect_same_ledger_row <- function(batch, single, i, tol = 0) {
  testthat::expect_identical(batch$rows$key, single$rows$key)
  for (k in batch$rows$key) {
    a <- batch$values[[k]][i, ]
    b <- single$values[[k]][1L, ]
    if (tol == 0) {
      testthat::expect_identical(a, b, info = k)
    } else {
      testthat::expect_true(all(abs(a - b) <= tol * pmax(1, abs(a))), info = k)
    }
  }
}

#' Ledger, Kennzahlen und Pfade eines Laufs mit vorgegebenen Ziehungen (Stufen 2-9 der Engine)
run_with_draws <- function(model, draws) eng_run_draws(model, draws = draws, store = "full")

#' Lauf i des Batches = Einzellauf mit den Ziehungen von Lauf i (Ledger, Kennzahlen, Opp),
#' identisch (15.5 Nr. 1; gemessene Abweichung exakt 0)
expect_batch_equals_single <- function(model, draws) {
  n <- draws$n
  batch <- run_with_draws(model, draws)
  expect_identical(batch$ledger$n, n)
  expect_identical(nrow(batch$kpis), n)
  for (i in seq_len(n)) {
    single <- run_with_draws(model, reg_draws_subset(draws, i))
    expect_same_ledger_row(batch$ledger, single$ledger, i)
    for (k in names(batch$kpis)) {
      expect_identical(batch$kpis[[k]][i], single$kpis[[k]][1L], info = paste(k, i))
    }
    expect_identical(batch$opp$BS[i, ], single$opp$BS[1L, ], info = paste("opp", i))
    expect_identical(batch$flags[i, , drop = FALSE], `rownames<-`(single$flags, i))
  }
  invisible(batch)
}

test_that("0. Walking Skeleton: Lauf i im Batch = Einzellauf i (fake_draws, N = 7 = T+1+3)", {
  model <- vofi_build(vofi_read_scenario(vofi_example("skeleton")))
  g <- model$grid
  i <- seq_len(7L) - 1
  z <- outer(1 + 0.15 * (i - 3), c(-100000, 30000, 40000, 50000))
  z[, 4] <- z[, 4] - 20000 * i
  draws <- fake_draws(7L, g, paths = list("components.z.values" = z),
                      static = list("accounts.deposit_rate_pa" = 0.02 + 0.005 * i,
                                    "financing.ek.amount_eur" = 40000 + 2500 * i))
  batch <- expect_batch_equals_single(model, draws)
  # Die Läufe unterscheiden sich (Geldanlage und Kontokorrent, Endwerte)
  expect_true(length(unique(round(batch$kpis$terminal_value, 6))) == 7L)
  expect_true(any(batch$ledger$values$od_draw > 0))
  expect_true(all(abs(batch$ledger$values$balance_check) <= 1e-6))
  # Lauf 4 (i = 3: Faktor 1, Zinssatz 3,5 %) = deterministischer Lauf mit denselben Werten
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  sc$components$z$values <- z[4, ]
  sc$accounts$deposit_rate_pa <- 0.035
  sc$financing$ek$amount_eur <- 47500
  det <- vofi_run(vofi_build(sc))
  expect_same_ledger_row(batch$ledger, det$ledger, 4L, 1e-12)
  expect_equal(batch$kpis$delta_terminal_value[4], det$kpis$delta_terminal_value,
               tolerance = 1e-12)
})

test_that("0c. N = T+1: Wachstumspfad, Miete, Zins und Monatsannuit\u00e4t im Batch (2.8 Nr. 8)", {
  sc <- batch_scenario()
  sc$stochastic <- list()
  sc$financing$bank <- list(type = "annuity_loan", amount_eur = 60000, rate_pa = 0.04,
                            term_years = 10, payments_per_year = 12L, fixed_years = 3,
                            followup_rate_pa = list(ref = "market.mortgage_rate"))
  sc$market$mortgage_rate <- 0.05
  model <- vofi_build(sc)
  g <- model$grid
  n <- g$T + 1L
  expect_identical(n, 6L)
  i <- seq_len(n) - 1
  growth <- outer(0.01 + 0.004 * i, rep(1, g$T + 1L))
  growth[, 1L] <- 0
  draws <- fake_draws(n, g,
                      paths = list("market.rent_growth" = growth,
                                   "market.mortgage_rate" = outer(0.03 + 0.01 * i,
                                                                  rep(1, g$T + 1L))),
                      static = list("components.rent.amount_eur" = 8000 + 500 * i,
                                    "financing.bank.rate_pa" = 0.03 + 0.003 * i))
  batch <- expect_batch_equals_single(model, draws)
  expect_identical(nrow(batch$kpis), n)
  expect_identical(length(unique(batch$ledger$values$loan_bank_interest[, 2L])), n)
  expect_true(length(unique(batch$ledger$values$rent__value[, g$T + 1L])) == n)
})

test_that("0b. Orakel (a) mit stochastischen Zinsen: Lauf i im Batch = Einzellauf i", {
  model <- vofi_build(example_scenario("oracle_a"))
  i <- seq_len(7L) - 1
  draws <- fake_draws(7L, model$grid,
                      static = list("financing.ann.rate_pa" = 0.06 - 0.01 * i,
                                    "financing.bul.approved" = c(1, 1, 0, 1, 1, 0, 1),
                                    "accounts.overdraft_rate_pa" = 0.10 + 0.01 * i))
  batch <- expect_batch_equals_single(model, draws)
  expect_equal(batch$kpis$terminal_value[1], oracle_a_values()$kpi$terminal_value,
               tolerance = 1e-9)
  expect_true(all(batch$ledger$values$loan_bul_draw[c(3L, 6L), 1] == 0))
})

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
    # Teilauszahlung zum Ende der Bauphase: die Auszahlung liegt nicht nur in t0; der Termin
    # 2028-01-01 ist Periodenende auf beiden Rastern ("gleiche Vertragstermine", 15.5 Nr. 6;
    # Auszahlungen wirken zum Periodenende, 8.5 (h))
    sc$financing$bank <- list(type = "annuity_loan", amount_eur = 60000, rate_pa = 0.04,
                              term_years = 5, payments_per_year = 1L,
                              draw_schedule = list(schedule = list("2027-01-01" = 0.5,
                                                                   "2028-01-01" = 0.5),
                                                   unit = "share"))
    vofi_run(vofi_build(sc))
  }
  a <- mk(list())
  m <- mk(list(construction_months = 9L, construction_step_months = 1L))
  ga <- a$grid
  gm <- m$grid
  expect_true(any(m$ledger$values$loan_bank_draw[1L, -1L] > 0))
  for (k in c("loan_bank_repay", "loan_bank_interest", "loan_bank_draw")) {
    expect_equal(m$ledger$values[[k]][1L, 1L], a$ledger$values[[k]][1L, 1L], tolerance = 1e-9,
                 info = paste(k, "t0"))
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

test_that("10. Feste Kreditbetr\u00e4ge bei amount_eur: auto, topup = Mehrbedarf (R-69)", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_run", "vofi_mc")
  sc <- batch_scenario()
  sc$financing$bank$amount_eur <- "auto"
  sc$financing$extra <- list(type = "bullet_loan", amount_eur = "topup", rate_pa = 0.06,
                             term_years = 5, payments_per_year = 1L)
  # stochastische Baukosten: Faktor auf den Zahlungsplan der Investition (apply multiply, R-94);
  # jedes Overlay-Ziel hoechstens einmal (11.8)
  sc$stochastic$parameters$inv <- list(target = "components.inv.values", dist = "uniform",
                                       min = 0.9, max = 1.3, apply = "multiply")
  model <- vofi_build(sc)
  det <- vofi_run(model)
  mc <- vofi_mc(model, n_sim = 7L, block_size = 7L, seed = 8L, store = "full")
  d0 <- det$ledger$values$loan_bank_draw[1L, ]
  expect_equal(d0[1L], 60000)
  for (i in seq_len(7L)) expect_identical(mc$ledger$values$loan_bank_draw[i, ], d0)
  # topup: Basisfall 0, je Lauf der Mehrbedarf gegenueber dem Basisfall (8.7)
  expect_true(all(det$ledger$values$loan_extra_draw == 0))
  need <- pmax(-mc$ledger$values$inv__value[, 1L] - 40000 - 60000, 0)
  expect_true(any(need > 0) && any(need == 0))
  expect_equal(mc$ledger$values$loan_extra_draw[, 1L], need, tolerance = 1e-9)
})

test_that("11. Entscheidungsknoten: Kompositum = getrennte Rechnung (R-71)", {
  skip_if_stub("vofi_scenario", "vofi_build", "vofi_mc", "vofi_sim")
  # Szenario mit Förder-Expander (WS-E2), Knoten f (before_start, Ausweichvariante "ohne");
  # Variante "sicher": Zusagewahrscheinlichkeit 1, also kein Zusageschlüssel und Zweig 1
  sc <- wsg_decision_scenario(n_sim = 400L, p = 0.6)
  sc$variants$sicher <- list(label = "Zusage sicher",
                             set = list(funding.f.approval_probability = 1))
  mc <- wsg_quiet(vofi_mc(wsg_quiet(vofi_build(sc)), n_sim = 400L, seed = 7L))
  mv <- wsg_quiet(vofi_mc(wsg_quiet(vofi_build(sc, variant = "sicher")), n_sim = 400L,
                          seed = 7L))
  mf <- wsg_quiet(vofi_mc(wsg_quiet(vofi_build(sc, variant = "ohne")), n_sim = 400L,
                          seed = 7L))
  b <- mc$kpis$branch
  expect_true(all(b %in% c(0L, 1L)))
  expect_true(any(b == 1L) && any(b == 0L))
  expect_true(all(mv$kpis$branch == 1L))
  expect_null(mf$decision)
  # getrennte Läufe mit denselben Ziehungen (Ströme je Schlüssel, 11.3): x_i = b_i x^V_i +
  # (1 - b_i) x^F_i (9.11 Nr. 4)
  expect_identical(mv$inputs$rent, mc$inputs$rent)
  expect_identical(mf$inputs$rent, mc$inputs$rent)
  for (k in c("terminal_value", "terminal_value_opp", "delta_terminal_value")) {
    expect_equal(mc$kpis[[k]], ifelse(b == 1L, mv$kpis[[k]], mf$kpis[[k]]), tolerance = 1e-9,
                 info = k)
  }
  expect_equal(mc$decision$share_approved, mean(b == 1L))
  expect_lt(abs(mean(b == 1L) - 0.6), 0.05)
  # Einzellauf = Lauf im Batch, auch für den Zweig
  for (i in unique(c(1L, which(b == 0L)[1L], which(b == 1L)[1L]))) {
    r <- wsg_quiet(vofi_sim(mc, i))
    expect_equal(r$kpis$delta_terminal_value, mc$kpis$delta_terminal_value[i],
                 tolerance = 1e-9, info = i)
    expect_identical(r$decision$branch, b[i])
  }
})
