# Tests für R/engine-auto.R (WS-D; Spec 00 Abschnitt 8.7, R-69): auto im Basisfall-Vorlauf
# (fest in allen Läufen), Puffer, Auszahlungskurs, Rundung, need0, topup je Lauf als Mehrbedarf,
# Zulässigkeit, ctx$auto().

auto_scenario <- function(bank = list(), extra = NULL, z = c(-100000, 20000, 20000, 90000),
                          ek = 40000) {
  fin <- list(bank = utils::modifyList(list(type = "bullet_loan", amount_eur = "auto",
                                            rate_pa = 0.05, term_years = 3,
                                            payments_per_year = 1L), bank))
  if (!is.null(extra)) fin$extra <- extra
  wsd_scenario(z, ek = list(type = "equity", amount_eur = ek),
               accounts = list(overdraft_limit_eur = Inf, overdraft_rate_pa = 0.08),
               financing = fin)
}

topup_loan <- list(type = "bullet_loan", amount_eur = "topup", rate_pa = 0.06, term_years = 3,
                   payments_per_year = 1L)

#' Ziehungen mit Faktor auf die Zahlungsfolge z (apply multiply, R-94)
factor_draws <- function(grid, f) {
  n <- length(f)
  targets <- data.frame(key = "components.z.values", target = "components.z.values",
                        kind = "static", apply = "multiply", stringsAsFactors = FALSE)
  new_vofi_draws("mc", n = n, sims = seq_len(n), blocks = 1L, block_size = n,
                 static = list("components.z.values" = f), paths = list(), targets = targets,
                 years = grid$years)
}

test_that("eng_auto_window: Bauphase inkl. t0, ohne Bauphase nur t0", {
  expect_identical(eng_auto_window(wsd_skeleton()$grid), 1L)
  sc <- wsd_scenario(list(schedule = list("2027-01-01" = -100000)), horizon = 3L,
                     ek = list(type = "equity", amount_eur = 100000))
  sc$grid <- list(construction_months = 12L, construction_step_months = 6L)
  g <- vofi_build(sc)$grid
  w <- eng_auto_window(g)
  expect_identical(w, seq_len(max(which(g$phase == "construction"))))
  expect_true(length(w) >= 2L)
})

test_that("eng_auto_need: laufendes Maximum von -cumsum(c), mindestens 0", {
  cw <- rbind(c(-100, 30, -50, 200), c(10, 10, 10, 10))
  expect_equal(eng_auto_need(cw), rbind(c(100, 100, 120, 120), c(0, 0, 0, 0)))
  plan <- eng_auto_plan(rbind(c(100, 100, 120)), buffer = 0.1, payout = 0.5)
  expect_equal(plan, rbind(c(220, 0, 44)))
})

test_that("auto: Bedarf im Basisfall, fester Plan, need0 = 0 (8.7)", {
  model <- vofi_build(auto_scenario())
  a <- model$base$auto
  expect_equal(a$commitment, 60000)
  expect_equal(a$draws, c(60000, 0, 0, 0))
  expect_identical(a$window, 0L)
  expect_equal(model$base$need0, 0)
  res <- vofi_run(model)
  expect_equal(res$ledger$values$loan_bank_draw[1L, ], c(60000, 0, 0, 0))
  expect_true(all(res$ledger$values$equity_call == 0))
})

test_that("auto: Puffer, Auszahlungskurs und Rundung auf auto_round_eur", {
  model <- vofi_build(auto_scenario(bank = list(auto_buffer_share = 0.1, payout_rate = 0.98,
                                                auto_round_eur = 5000)))
  a <- model$base$auto
  expect_equal(a$commitment, 70000)
  expect_equal(a$draws[1L], 70000)
  expect_equal(model$base$need0, 0)
  m2 <- vofi_build(auto_scenario(bank = list(auto_buffer_share = 0.1, payout_rate = 0.98)))
  expect_equal(m2$base$auto$commitment, 60000 * 1.1 / 0.98)
})

test_that("auto ohne Bedarf: Betrag 0 mit Hinweis", {
  expect_message(model <- vofi_build(auto_scenario(ek = 150000)), class = "vofi_message")
  expect_equal(model$base$auto$commitment, 0)
})

test_that("auto ist in allen Läufen fest, auch bei höheren Kosten des Laufs (R-69)", {
  model <- vofi_build(auto_scenario())
  dr <- factor_draws(model$grid, c(1, 1.2))
  out <- eng_run_draws(model, draws = dr, store = "full")
  v <- out$ledger$values
  expect_equal(v$loan_bank_draw[, 1L], c(60000, 60000))
  expect_equal(v$z__value[, 1L], c(-100000, -120000))
  expect_equal(v$od_draw[, 1L], c(0, 20000))
})

test_that("topup: Basisfall 0, je Lauf der Mehrbedarf gegenüber dem Basisfall", {
  model <- vofi_build(auto_scenario(bank = list(amount_eur = 50000), extra = topup_loan))
  expect_identical(model$topup_id, "extra")
  expect_null(model$base$auto)
  expect_equal(model$base$need0, 10000)
  det <- vofi_run(model)
  expect_true(all(det$ledger$values$loan_extra_draw == 0))
  dr <- factor_draws(model$grid, c(1, 1.1, 1.3, 0.9))
  out <- eng_run_draws(model, draws = dr, store = "full")
  expect_equal(out$ledger$values$loan_extra_draw[, 1L], c(0, 10000, 30000, 0))
  expect_true(all(out$checks$ok))
})

test_that("topup zusammen mit auto: Mehrbedarf nach dem festen auto-Plan", {
  model <- vofi_build(auto_scenario(extra = topup_loan))
  expect_identical(model$auto_id, "bank")
  expect_equal(model$base$need0, 0)
  dr <- factor_draws(model$grid, c(1, 1.25))
  out <- eng_run_draws(model, draws = dr, store = "full")
  v <- out$ledger$values
  expect_equal(v$loan_bank_draw[, 1L], c(60000, 60000))
  expect_equal(v$loan_extra_draw[, 1L], c(0, 25000))
  env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, dr, env)
  exo <- eng_flows(model, ctx, env)
  tp <- eng_auto_amounts(model, ctx, exo$ledger, env)
  expect_equal(tp$commitment, c(0, 25000))
  expect_identical(env$topup, tp)
  expect_identical(dim(tp$draws), c(2L, model$grid$T + 1L))
})

test_that("ctx$auto hebt den auto-Plan des Basisfalls auf n Läufe", {
  model <- vofi_build(auto_scenario(extra = topup_loan))
  dr <- factor_draws(model$grid, c(1, 1.25, 1.5))
  env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, dr, env)
  a <- ctx$auto("bank")
  expect_equal(a$commitment, rep(60000, 3))
  expect_identical(dim(a$draws), c(3L, model$grid$T + 1L))
  expect_equal(a$draws[, 1L], rep(60000, 3))
  ctx0 <- eng_context(model, NULL, NULL)
  expect_error(ctx0$auto("bank"), class = "vofi_error_contract")
})

test_that("Zulässigkeit: höchstens ein auto, kein existing, kein Auszahlungsplan, Start t0", {
  two <- auto_scenario(extra = list(type = "bullet_loan", amount_eur = "auto", rate_pa = 0.06,
                                    term_years = 3, payments_per_year = 1L))
  # Seit der Integration von WS-B meldet die Validierung (Ebene 3, Spec 00 8.7) die Verstöße mit
  # den Schlüsseln validation.auto_multiple bzw. validation.auto_conflict vor der Engine-Prüfung
  # (die eng_auto_ids() im nächsten Test direkt prüft); die Fundstelle steht in der Meldung.
  expect_error(vofi_build(two), "'financing.extra.amount_eur'", fixed = TRUE,
               class = "vofi_error_validation")
  ex <- auto_scenario(bank = list(existing = TRUE))
  expect_error(vofi_build(ex), "'financing.bank.existing'", fixed = TRUE,
               class = "vofi_error_validation")
  late <- auto_scenario(bank = list(start = "2028-01-01"))
  expect_error(vofi_build(late), "'financing.bank.start'", fixed = TRUE,
               class = "vofi_error_validation")
  sched <- auto_scenario(bank = list(draw_schedule = list(schedule = list("2027-01-01" = 1),
                                                          unit = "share")))
  expect_error(vofi_build(sched), "'financing.bank.draw_schedule'", fixed = TRUE,
               class = "vofi_error_validation")
})

test_that("eng_auto_ids: Ergebnis und Fehlerschlüssel", {
  model <- vofi_build(auto_scenario(extra = topup_loan))
  ids <- eng_auto_ids(model$instruments, model$grid)
  expect_identical(ids, list(auto = "bank", topup = "extra"))
  insts <- model$instruments
  insts$extra$spec$existing <- TRUE
  e <- expect_error(eng_auto_ids(insts, model$grid), class = "vofi_error_validation")
  expect_match(conditionMessage(e), "extra", fixed = TRUE)
  expect_identical(eng_auto_ids(wsd_skeleton()$instruments), list(auto = NULL, topup = NULL))
})
