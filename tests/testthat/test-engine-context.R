# Tests für R/engine-context.R (WS-D; Spec 00 Abschnitt 6): Felder, Basisfallwerte (R-70),
# Abhängigkeiten, Zwischenspeicher, ctx$rebalance(), ctx$draw(), Regelwahl.

ctx_model <- function() {
  sc <- wsd_scenario(c(-100000, 0, 0, 0), ek = list(type = "equity", amount_eur = 100000),
                     components = list(rent = list(type = "recurring", category = "rent",
                                                   amount_eur = 9000)),
                     accounts = list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08))
  vofi_build(sc)
}

test_that("Felder des deterministischen Kontexts (6.2)", {
  model <- ctx_model()
  ctx <- eng_context(model, NULL, eng_engine_env(model, quiet = TRUE))
  expect_s3_class(ctx, "vofi_ctx")
  expect_identical(ctx$n, 1L)
  expect_identical(ctx$T, model$grid$T)
  expect_identical(ctx$mode, "deterministic")
  expect_identical(ctx$sims, 1L)
  expect_identical(ctx$blocks, 1L)
  expect_identical(ctx$perspective, "kleinvermieter")
  expect_identical(ctx$tol, vofi_tol)
  expect_true(environmentIsLocked(ctx))
  expect_error(assign("n", 2L, envir = ctx))
  expect_identical(dim(ctx$zeros()), c(1L, model$grid$T + 1L))
  expect_equal(ctx$by_sim(5)[, 1L], 5)
  expect_null(ctx$draw("components.rent.amount_eur"))
  expect_equal(ctx$value("accounts.deposit_rate_pa", "path")[1L, 2L], 0.02)
})

test_that("param und param_base: Ziehung gegen Basisfallwert (R-70)", {
  model <- ctx_model()
  dr <- fake_draws(3L, model$grid, static = list("components.rent.amount_eur" =
                                                   c(8000, 9000, 10000)))
  env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, dr, env)
  rent <- model$spec$components$rent
  expect_identical(ctx$n, 3L)
  expect_identical(ctx$mode, "mc")
  expect_equal(as.double(ctx$param(rent, "amount_eur")), c(8000, 9000, 10000))
  expect_equal(as.double(ctx$param_base(rent, "amount_eur")), rep(9000, 3))
  expect_equal(as.double(ctx$value_base("components.rent.amount_eur")), rep(9000, 3))
  expect_equal(ctx$draw("components.rent.amount_eur"), c(8000, 9000, 10000))
  # Zwischenspeicher: wiederholter Zugriff liefert dasselbe Objekt
  expect_identical(ctx$param(rent, "amount_eur"), ctx$param(rent, "amount_eur"))
})

test_that("component_base: Basisfall-Vorlauf, im deterministischen Modus = component()", {
  model <- ctx_model()
  dr <- fake_draws(2L, model$grid, static = list("components.rent.amount_eur" =
                                                   c(5000, 7000)))
  env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, dr, env)
  exo <- eng_flows(model, ctx, env)
  base <- ctx$component_base("rent")
  now <- ctx$component("rent")
  expect_identical(nrow(base$rows[[1L]]$values), 2L)
  expect_equal(base$rows[[1L]]$values[1L, ], base$rows[[1L]]$values[2L, ])
  expect_false(isTRUE(all.equal(now$rows[[1L]]$values[1L, ], now$rows[[1L]]$values[2L, ])))
  ctx0 <- eng_context_from_parts(model$grid, model$spec, components = model$base$flows)
  expect_identical(ctx0$component_base("rent"), ctx0$component("rent"))
  expect_error(ctx0$component("missing"), class = "vofi_error_contract")
})

test_that("Abhängigkeiten: nur deklarierte Komponenten lesbar (6.1 Nr. 3)", {
  model <- ctx_model()
  env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, NULL, env)
  exo <- eng_flows(model, ctx, env)
  env$deps <- "z"
  env$current <- "rent"
  expect_error(ctx$component("ek"), class = "vofi_error_contract")
  expect_s3_class(ctx$component("z"), "vofi_flows")
  expect_identical(names(ctx$rows()), "z__value")
  env$deps <- NULL
  expect_true(length(ctx$rows(section = "equity")) >= 1L)
  expect_length(ctx$rows(category = "rent"), 1L)
})

test_that("ctx$rebalance nur in der Stufe kpi (9.3, 12.8)", {
  model <- wsd_skeleton()
  env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, NULL, env)
  env$stage <- "balance"
  expect_error(ctx$rebalance(), class = "vofi_error_contract")
  env$stage <- "kpi"
  env$rebalance <- function(extra_out = NULL) "ok"
  expect_identical(ctx$rebalance(), "ok")
  ctx_no <- eng_context(model, NULL, NULL)
  expect_error(ctx_no$rebalance(), class = "vofi_error_contract")
})

test_that("ctx$setting und ctx$timing: Termin-Token und Defaults", {
  model <- wsd_skeleton()
  ctx <- eng_context(model, NULL, NULL)
  bank <- model$spec$financing$bank
  expect_identical(ctx$setting(bank, "start"), model$grid$valuation_date)
  expect_identical(ctx$setting(bank, "payments_per_year"), 1L)
  tm <- ctx$timing(list(id = "x", type = "custom_series", start = "completion"), "start")
  expect_identical(tm$date, model$grid$completion_date)
  expect_equal(tm$shift, 0)
})

test_that("eng_rule_for: Reformversion vor Basisversion, sonst spätestes valid_from", {
  rule <- function(from, reform = NULL, fun = from) {
    list(rule_name = "r", valid_from = as.Date(from), valid_to = NULL, reform = reform,
         fun = fun)
  }
  defs <- list(rule("2020-01-01"), rule("2025-01-01"),
               rule("2024-01-01", reform = "x", fun = "reform"))
  local_mocked_bindings(reg_rules = function(rule_name) defs)
  spec <- list(project = list(legal_state = as.Date("2027-01-01")))
  expect_identical(eng_rule_for("r", spec), "2025-01-01")
  spec$project$pending_reforms <- "x"
  expect_identical(eng_rule_for("r", spec), "reform")
  spec2 <- list(project = list(legal_state = as.Date("2019-01-01")))
  expect_error(eng_rule_for("r", spec2), class = "vofi_error_registry")
})

test_that("eng_lift_flows und eng_collection", {
  model <- wsd_skeleton()
  fl <- model$base$flows$z
  up <- eng_lift_flows(fl, 3L)
  expect_identical(nrow(up$rows[[1L]]$values), 3L)
  expect_identical(eng_lift_flows(fl, 1L), fl)
  expect_identical(eng_collection(model$spec, model$spec$financing$bank), "financing")
  expect_identical(eng_collection(model$spec, model$spec$components$z), "components")
})

test_that("ctx$auto: Plan auf n Läufe gehoben, falsche Längen und NA sind Vertragsfehler", {
  g <- make_grid()
  spec <- reg_test_spec(g)
  env <- new.env(parent = emptyenv())
  env$stage <- "flows"
  plan <- seq(0, 6) * 1000
  mk <- function(a) {
    env$auto <- function(id) a
    eng_context_from_parts(g, spec, draws = fake_draws(2L, g), mode = "mc", engine_env = env)
  }
  ok <- mk(list(commitment = 5, draws = plan))$auto("x")
  expect_identical(ok$commitment, c(5, 5))
  expect_identical(dim(ok$draws), c(2L, 7L))
  expect_identical(mk(list(commitment = c(5, 6), draws = matrix(plan, 1L)))$auto("x")$commitment,
                   c(5, 6))
  bad <- list(list(commitment = c(1, 2, 3), draws = plan), list(commitment = NULL, draws = plan),
              list(commitment = 1, draws = rbind(plan, plan, plan)),
              list(commitment = 1, draws = matrix(plan, 7L, 1L)),
              list(commitment = 1, draws = replace(plan, 2L, NA)),
              list(commitment = NA_real_, draws = plan))
  for (b in bad) expect_error(mk(b)$auto("x"), class = "vofi_error_contract")
})
