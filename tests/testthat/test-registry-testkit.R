# Tests für R/registry-testkit.R (Integrator; Spec 00 Abschnitt 5.6).
# Die Prüfungen laufen gegen Attrappen von node_normalize() (WS-A) und
# eng_context_from_parts() (WS-D), damit das Prüfkit unabhängig von deren Umsetzung getestet ist.

local_registry <- function(env = parent.frame()) {
  old <- reg_state$types
  withr::defer(reg_state$types <- old, envir = env)
  invisible(old)
}

#' Attrappe von node_normalize(): Zahl -> const, Vektor -> series_t, {ref} -> ref
mock_normalize <- function(x, param = NULL, path = NULL) {
  kind <- if (is.null(param)) "value" else param$kind
  if (kind %in% c("number", "amount", "rate", "share", "value", "schedule")) {
    if (is.numeric(x) && length(x) == 1L) return(node_const(x))
    if (is.numeric(x)) return(list(kind = "series_t", values = as.double(x)))
    if (is.list(x) && !is.null(x$ref)) return(node_ref(x$ref))
    return(x)
  }
  switch(kind,
    integer = as.integer(x), logical = as.logical(x), date = as.Date(x),
    timing = if (identical(x, "completion")) x else as.Date(x),
    map = x, as.character(x))
}

#' Attrappe von eng_context_from_parts() mit den im Prüfkit benötigten Funktionen
mock_context <- function(grid, spec, draws = NULL, components = list(),
                         components_base = components,
                         mode = c("deterministic", "mc", "design"), engine_env = NULL) {
  mode <- match.arg(mode)
  n <- if (is.null(draws)) 1L else draws$n
  ctx <- new.env(parent = emptyenv())
  resolve <- function(path, shape, base = FALSE) {
    v <- NULL
    if (!base && !is.null(draws) && mode != "deterministic") {
      v <- draws$static[[path]] %||% draws$paths[[path]]
    }
    if (is.null(v)) {
      node <- path_get(spec, path)
      v <- if (is.list(node) && identical(node$kind, "const")) {
        node$value
      } else if (is.list(node) && identical(node$kind, "series_t")) {
        grid_by_period(grid, node$values, n)
      } else if (is.list(node) && identical(node$kind, "ref")) {
        resolve(node$path, shape, base) * node$scale + node$offset
      } else if (is.numeric(node)) {
        node
      } else {
        stop("Attrappe: Knoten nicht aufl\u00f6sbar: ", path)
      }
    }
    if (shape == "scalar") {
      if (is.matrix(v)) stop("zeitabh\u00e4ngig")
      as.double(rep_len(v, n))
    } else if (is.matrix(v)) v else grid_by_sim(grid, v, n)
  }
  coll <- function(s) {
    if (!is.null(path_get(spec, paste0("financing.", s$id)))) "financing" else "components"
  }
  ctx$n <- n
  ctx$T <- grid$T
  ctx$grid <- grid
  ctx$mode <- mode
  ctx$spec <- spec
  ctx$tol <- vofi_tol
  ctx$param <- function(spec, name, shape = c("scalar", "path")) {
    resolve(path_join(coll(spec), spec$id, name), match.arg(shape))
  }
  ctx$param_base <- function(spec, name, shape = c("scalar", "path")) {
    resolve(path_join(coll(spec), spec$id, name), match.arg(shape), base = TRUE)
  }
  ctx$value <- function(path, shape = c("scalar", "path")) resolve(path, match.arg(shape))
  ctx$setting <- function(spec, name) path_get(spec, name)
  ctx$by_sim <- function(x) grid_by_sim(grid, x, n)
  ctx$by_period <- function(x) grid_by_period(grid, x, n)
  ctx$zeros <- function() grid_zeros(grid, n)
  ctx$assets <- function() spec$registers$assets
  ctx$measures <- function() spec$registers$measures
  ctx$component <- function(id) components[[id]]
  ctx$rebalance <- function(extra_out = NULL) {
    if (!identical(engine_env$stage, "kpi")) stop("rebalance nur in Kennzahlen")
    engine_env$rebalance(extra_out)
  }
  ctx$auto <- function(id) engine_env$auto(id)
  class(ctx) <- "vofi_ctx"
  lockEnvironment(ctx, bindings = TRUE)
  ctx
}

local_testkit_mocks <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(node_normalize = mock_normalize,
                                  eng_context_from_parts = mock_context, .env = env)
}

flow_def <- function(name = "tk_income", build = NULL, category = "other_income",
                     grid_invariant = TRUE, ...) {
  build <- build %||% function(spec, ctx) {
    a <- ctx$param(spec, "amount_eur")
    v <- ctx$by_sim(a) * ctx$by_period(ctx$grid$delta)
    vofi_flows(vofi_row("value", v, section = "project", category = category))
  }
  vofi_type(name = name, kind = "flow", label = "Testeinnahme",
            labels = list(description = "Testtyp", params = list(amount_eur = "Betrag"),
                          rows = list(value = "Einnahme")),
            params = list(amount_eur = vofi_param("amount", required = TRUE)),
            rows = "value", build = build, grid_invariant = grid_invariant,
            example = list(type = name, amount_eur = 1000), ...)
}

findings_of <- function(name, kind = NULL) {
  r <- reg_resolve_name(name, kind)
  reg_check_type(reg_get(r$kind, r$name), reg_source(r$kind, r$name))
}

test_that("Pr\u00fcfraster und Pr\u00fcfspezifikation", {
  ga <- reg_test_grid("annual")
  gm <- reg_test_grid("mixed")
  expect_identical(ga$T, 6L)
  expect_identical(gm$end_date, ga$end_date)
  expect_identical(gm$months, c(0L, rep(1L, 9), 3L, rep(12L, 5)))
  sp <- reg_test_spec(ga)
  expect_s3_class(sp, "vofi_spec")
  expect_identical(sp$project$tax_regime, "wu_kommunal")
  expect_identical(sp$market$inflation, node_const(0.02))
  expect_identical(sp$market$energy_price$gas, node_const(0.12))
  expect_identical(sp$household$income_growth, node_ref("market.inflation"))
  expect_identical(sp$accounts$surplus_order, c("od_repay", "dep_invest"))
  expect_identical(sp$registers$assets[[1]]$asset_id, "b1")
  expect_identical(sp$registers$measures[[1]]$measure_id, "m1")
  sp2 <- reg_test_spec(ga, perspective = "selbstnutzer", project = list(project_type = "heizungstausch"))
  expect_identical(sp2$project$tax_regime, "selbstnutzer")
  expect_identical(sp2$project$project_type, "heizungstausch")
})

test_that("Beispielkomponente und Fake-Ziehungen", {
  local_testkit_mocks()
  d <- flow_def()
  comp <- reg_example_component(d)
  expect_identical(comp$id, "x")
  expect_identical(comp$type, "tk_income")
  expect_identical(comp$amount_eur, node_const(1000))
  expect_true(all(reg_reserved_fields() %in% names(comp)))
  dr <- reg_fake_draws(d, 7L, reg_test_grid("annual"))
  expect_s3_class(dr, "vofi_draws")
  expect_equal(dr$static[["components.x.amount_eur"]], 1000 * (1 + 0.1 * (0:6)))
  expect_identical(dr$targets$target, "components.x.amount_eur")
  s1 <- reg_draws_subset(dr, 3L)
  expect_identical(s1$n, 1L)
  expect_equal(s1$static[["components.x.amount_eur"]], 1200)
  eq <- vofi_type(name = "equity", kind = "flow", label = "E",
                  params = list(amount_eur = vofi_param("amount")), rows = "in",
                  build = function(spec, ctx) NULL, example = list(type = "equity"))
  expect_identical(reg_collection(eq), "financing")
})

test_that("vofi_check_type: g\u00fcltiger Zahlungstyp besteht C1-C4 und F1-F10", {
  local_registry()
  local_testkit_mocks()
  vofi_register_type(flow_def())
  f <- findings_of("tk_income")
  expect_true(all(f$ok), info = paste(f$check[!f$ok], f$message[!f$ok]))
  expect_true(all(c("C1", "C2", "C3", "C4", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9",
                    "F10") %in% f$check))
  expect_invisible(vofi_check_type("tk_income"))
  expect_type_contract("tk_income")
})

test_that("vofi_check_type: Verst\u00f6\u00dfe werden erkannt", {
  local_registry()
  local_testkit_mocks()
  vofi_register_type(flow_def("tk_sign", category = "other_cost"))
  f <- findings_of("tk_sign")
  expect_false(all(f$ok[f$check == "F5"]))
  expect_error(vofi_check_type("tk_sign"), class = "vofi_error_contract")
  vofi_register_type(flow_def("tk_batch", build = function(spec, ctx) {
    v <- ctx$by_sim(ctx$param(spec, "amount_eur")) * ctx$n
    v[, 1] <- 0
    vofi_flows(vofi_row("value", v, section = "project", category = "other_income"))
  }, grid_invariant = FALSE))
  f <- findings_of("tk_batch")
  expect_false(all(f$ok[f$check == "F7"]))
  vofi_register_type(flow_def("tk_rng", build = function(spec, ctx) {
    v <- ctx$zeros() + stats::runif(1)
    vofi_flows(vofi_row("value", v, section = "project", category = "other_income"))
  }, grid_invariant = FALSE))
  withr::local_preserve_seed()
  set.seed(1)
  f <- findings_of("tk_rng")
  expect_false(all(f$ok[f$check == "F8"]))
  vofi_register_type(flow_def("tk_rows", build = function(spec, ctx) {
    vofi_flows(vofi_row("undeclared", ctx$zeros(), section = "project", category = "other_income"))
  }, grid_invariant = FALSE))
  f <- findings_of("tk_rows")
  expect_false(all(f$ok[f$check == "F3"]))
  vofi_register_type(flow_def("tk_engine", build = function(spec, ctx) {
    vofi_flows(vofi_row("value", ctx$zeros(), section = "loans", category = "draw"))
  }, grid_invariant = FALSE))
  f <- findings_of("tk_engine")
  expect_false(all(f$ok[f$check == "F4"]))
  vofi_register_type(flow_def("tk_ids", build = function(spec, ctx) {
    vofi_flows(vofi_row("value", -ctx$zeros(), section = "project", category = "capex",
                        asset_id = "b9", measure_id = "m1"))
  }, grid_invariant = FALSE))
  f <- findings_of("tk_ids")
  expect_false(all(f$ok[f$check == "F6"]))
  vofi_register_type(flow_def("tk_rv", build = function(spec, ctx) {
    vofi_flows(vofi_row("value", ctx$zeros() + 1, section = "project",
                        category = "residual_value"))
  }, grid_invariant = FALSE))
  f <- findings_of("tk_rv")
  expect_false(all(f$ok[f$check == "F9"]))
  vofi_register_type(flow_def("tk_grid", build = function(spec, ctx) {
    v <- ctx$by_sim(ctx$param(spec, "amount_eur")) + ctx$zeros()
    v[, 1] <- 0
    vofi_flows(vofi_row("value", v, section = "project", category = "other_income"))
  }))
  f <- findings_of("tk_grid")
  expect_false(all(f$ok[f$check == "F10"]))
  vofi_register_type(flow_def("tk_err", build = function(spec, ctx) stop("kaputt"),
                              grid_invariant = FALSE))
  f <- findings_of("tk_err")
  expect_false(all(f$ok[f$check == "F1"]))
})

test_that("C4: fehlende Labels eingebauter Typen", {
  local_registry()
  local_testkit_mocks()
  d <- flow_def("tk_builtin")
  d$label <- NULL
  reg_add(d, source = "vofi")
  f <- findings_of("tk_builtin")
  expect_false(f$ok[f$check == "C4"])
  expect_match(f$message[f$check == "C4"], "types.flow.tk_builtin.label", fixed = TRUE)
})

test_that("Abh\u00e4ngigkeiten \u00fcber example$.deps", {
  local_registry()
  local_testkit_mocks()
  vofi_register_type(flow_def("tk_base", grid_invariant = FALSE))
  dep <- vofi_type(
    name = "tk_share", kind = "flow", label = "Anteil",
    labels = list(description = "d", params = list(of = "Bezug", share = "Anteil"),
                  rows = list(value = "Kosten")),
    params = list(of = vofi_param("ref", required = TRUE), share = vofi_param("share")),
    rows = "value",
    build = function(spec, ctx) {
      base <- ctx$component(ctx$setting(spec, "of"))$rows[[1]]$values
      vofi_flows(vofi_row("value", -ctx$by_sim(ctx$param(spec, "share")) * base,
                          section = "project", category = "other_cost"))
    },
    example = list(type = "tk_share", of = "b", share = 0.1, after = "b",
                   .deps = list(b = list(type = "tk_base", amount_eur = 500)))
  )
  vofi_register_type(dep)
  f <- findings_of("tk_share")
  expect_true(all(f$ok), info = paste(f$check[!f$ok], f$message[!f$ok]))
})

test_that("Kreditinstrument: I1-I4, F7, F8", {
  local_registry()
  local_testkit_mocks()
  inst <- vofi_type(
    name = "tk_bullet", kind = "instrument", label = "Endf\u00e4llig",
    labels = list(description = "d", params = list(amount_eur = "Betrag", rate_pa = "Zins"),
                  rows = list()),
    params = list(amount_eur = vofi_param("amount", required = TRUE, deterministic_only = TRUE),
                  rate_pa = vofi_param("rate", required = TRUE)),
    init = function(spec, ctx) {
      new_vofi_inst_state(list(B = rep(0, ctx$n), D = ctx$param_base(spec, "amount_eur"),
                               i = ctx$param(spec, "rate_pa"), prepaid = rep(0, ctx$n)))
    },
    step = function(state, t, ctx) {
      z <- rep(0, ctx$n)
      draw <- if (t == 0) state$D else z
      int <- -state$B * state$i * ctx$grid$delta[t + 1L]
      balloon <- if (t == ctx$T) -state$B else z
      state$B <- state$B + draw + balloon
      list(state = state,
           flows = list(draw = draw, repay = z, repay_balloon = balloon, prepay = z,
                        interest = int, fees = z),
           memo = list(repayment_grant = z, disagio = z, assumed = z),
           stocks = list(balance = state$B))
    },
    capacity = function(state, t, ctx) list(balance = state$B, rate_pa = state$i, cap = state$B),
    prepay = function(state, amount, t, ctx) {
      used <- pmin(amount, state$B)
      state$B <- state$B - used
      list(state = state, used = used, flows = list(prepay = -used))
    },
    example = list(type = "tk_bullet", amount_eur = 60000, rate_pa = 0.05)
  )
  vofi_register_type(inst)
  f <- findings_of("tk_bullet")
  expect_true(all(f$ok), info = paste(f$check[!f$ok], f$message[!f$ok]))
  expect_true(all(c("I1", "I2", "I3", "I4", "F7", "F8") %in% f$check))
  bad <- inst
  bad$name <- "tk_bad_inst"
  bad$example$type <- "tk_bad_inst"
  bad$step <- function(state, t, ctx) {
    r <- inst$step(state, t, ctx)
    r$stocks$balance <- r$stocks$balance + 1
    r
  }
  vofi_register_type(bad)
  f <- findings_of("tk_bad_inst")
  expect_false(all(f$ok[f$check == "I3"]))
})

test_that("Ausgleichsaktion: A1, A2", {
  local_registry()
  local_testkit_mocks()
  act <- vofi_type(
    name = "tk_invest", kind = "account_action", label = "Anlage",
    labels = list(description = "d", params = list(), rows = list(dep_invest = "Anlage")),
    role = "surplus", rank = "U4", unlimited = TRUE, rows = "dep_invest",
    apply = function(acc, amount, t, ctx, inst) {
      acc$G <- acc$G + amount
      list(acc = acc, used = amount, flows = list(dep_invest = -amount), flags = list(),
           inst = NULL)
    }
  )
  vofi_register_type(act)
  f <- findings_of("tk_invest")
  expect_true(all(f$ok), info = paste(f$check[!f$ok], f$message[!f$ok]))
  call <- vofi_type(
    name = "tk_call", kind = "account_action", label = "Nachschuss",
    labels = list(description = "d", params = list(), rows = list(equity_call = "N")),
    role = "deficit", rank = "D4", unlimited = TRUE, rows = "equity_call",
    apply = function(acc, amount, t, ctx, inst) {
      list(acc = acc, used = amount, flows = list(equity_call = amount),
           flags = list(shortfall = amount > 0), inst = NULL)
    }
  )
  vofi_register_type(call)
  expect_true(all(findings_of("tk_call")$ok))
  wrong <- act
  wrong$name <- "tk_wrong"
  wrong$apply <- function(acc, amount, t, ctx, inst) {
    acc$G <- acc$G + 2 * amount
    list(acc = acc, used = amount, flows = list(dep_invest = -amount), flags = list(),
         inst = NULL)
  }
  vofi_register_type(wrong)
  f <- findings_of("tk_wrong")
  expect_false(all(f$ok[f$check == "A2"]))
})

test_that("Verteilung: D1-D3", {
  local_registry()
  unif <- vofi_type(
    name = "tk_unif", kind = "distribution", label = "Gleichverteilung",
    labels = list(description = "d", params = list(min = "Min", max = "Max"), rows = list()),
    params = list(min = vofi_param("number"), max = vofi_param("number")),
    quantile = function(u, par) par$min + u * (par$max - par$min),
    point = function(par, which = c("mode", "median", "mean")) (par$min + par$max) / 2,
    moments = function(par) list(mean = (par$min + par$max) / 2,
                                 var = (par$max - par$min)^2 / 12),
    validate = function(par) if (par$max < par$min) "max < min" else character(0),
    example = list(min = 1, max = 3)
  )
  vofi_register_type(unif)
  f <- findings_of("tk_unif")
  expect_true(all(f$ok), info = paste(f$check[!f$ok], f$message[!f$ok]))
  bad <- unif
  bad$name <- "tk_unif_bad"
  bad$moments <- function(par) list(mean = 5, var = 1)
  vofi_register_type(bad)
  expect_false(all(findings_of("tk_unif_bad")$ok[findings_of("tk_unif_bad")$check == "D2"]))
})

test_that("Prozess: P1-P3", {
  local_registry()
  ar1 <- vofi_type(
    name = "tk_ar1", kind = "process", label = "AR(1)", output = "rate",
    labels = list(description = "d", params = list(mu = "mu", phi = "phi", sigma = "sigma"),
                  rows = list()),
    params = list(mu = vofi_param("number"), phi = vofi_param("number"),
                  sigma = vofi_param("number")),
    simulate = function(par, z, u, years, linked) {
      n <- if (is.null(z)) 1L else nrow(z)
      x <- matrix(par$mu, n, length(years))
      for (y in seq_along(years)[-1L]) {
        x[, y] <- par$mu + par$phi * (x[, y - 1L] - par$mu) + par$sigma * z[, y - 1L]
      }
      x
    },
    expected = function(par, years) rep(par$mu, length(years)),
    n_shocks = function(par) 1L, n_uniforms = function(par) 0L,
    validate = function(par) character(0),
    example = list(mu = 0.02, phi = 0.8, sigma = 0.01)
  )
  vofi_register_type(ar1)
  f <- findings_of("tk_ar1")
  expect_true(all(f$ok), info = paste(f$check[!f$ok], f$message[!f$ok]))
  expect_true(all(c("P1", "P2", "P3") %in% f$check))
})

test_that("synthetisches core: vertragsgem\u00e4\u00df und konsistent", {
  core <- reg_example_core(7L, 6L)
  expect_s3_class(core$ledger, "vofi_ledger")
  expect_identical(core$n, 7L)
  expect_identical(dim(core$stocks$BS), c(7L, 7L))
  inv <- helper_invariants(core$ledger)
  expect_true(all(inv$ok), info = paste(inv$invariant, inv$max_dev))
  n_t <- 7L
  expect_equal(core$ledger$values$net_position, core$stocks$BS)
  expect_equal(core$terminal_ex_rv$BS, core$stocks$BS[, n_t] - core$terminal_ex_rv$rv,
               tolerance = 1e-9)
  expect_true(any(core$flags$shortfall))
  expect_true(all(c("reserve_used", "shortfall", "shortfall_sum", "first_shortfall_t",
                    "limit_breach", "limit_cut", "opp_limit_breach", "ex_rv_gap",
                    "overdraft_threshold", "stopped", "negative_amortization",
                    "equity_call_over_savings", "arbitrage") %in% names(core$flags)))
  expect_identical(length(core$opp$EW), 7L)
  expect_true(all(c("h", "h_net", "s", "sp") %in% names(core$rates)))
  expect_identical(core$view, "with_rv")
  rows <- core$ledger$rows
  expect_true(all(c("market_value", "residual_path", "tenant_energy_cost_pre", "co2_emission",
                    "modernization_levy", "repayment_grant") %in% rows$category))
  expect_identical(rows$extra[[which(rows$key == "rv__path_method")]]$rv_basis, "method")
  one <- reg_example_core(1L, 6L, runs = 4L)
  expect_equal(one$stocks$BS[1, ], core$stocks$BS[4, ])
  expect_null(attr(core, "ctx"))
})

test_that("rebalance()-Attrappe und Kennzahltests K1, F7", {
  local_registry()
  local_testkit_mocks()
  core <- reg_example_core(7L, 6L)
  ctx <- reg_example_ctx(core)
  expect_identical(ctx$n, 7L)
  r0 <- ctx$rebalance(NULL)
  expect_equal(r0$BS_T, core$stocks$BS[, 7])
  expect_equal(r0$BS_T_ex_rv, core$terminal_ex_rv$BS)
  r1 <- ctx$rebalance(-ctx$by_sim(1000) * ctx$by_period(ctx$grid$delta))
  expect_true(all(r1$BS_T < r0$BS_T))
  kpi <- vofi_type("tk_ew", "kpi", label = "Endwert",
                   labels = list(description = "d", params = list(), rows = list()),
                   compute = function(core, ctx) {
                     vofi_kpi_value(core$stocks$BS[, ncol(core$stocks$BS)])
                   })
  vofi_register_type(kpi)
  f <- findings_of("tk_ew")
  expect_true(all(f$ok), info = paste(f$check[!f$ok], f$message[!f$ok]))
  kpi_rb <- vofi_type("tk_rb", "kpi", label = "Rebalance",
                      labels = list(description = "d", params = list(), rows = list()),
                      compute = function(core, ctx) vofi_kpi_value(ctx$rebalance(NULL)$BS_T))
  vofi_register_type(kpi_rb)
  expect_true(all(findings_of("tk_rb")$ok))
  kpi_bad <- vofi_type("tk_kbad", "kpi", label = "Falsch",
                       labels = list(description = "d", params = list(), rows = list()),
                       compute = function(core, ctx) vofi_kpi_value(1))
  vofi_register_type(kpi_bad)
  expect_false(all(findings_of("tk_kbad")$ok))
})

test_that("Steuermodul T1 und Rechtsregel F7", {
  local_registry()
  local_testkit_mocks()
  registerS3method("tax_init", "tax_tk_tax", function(module, params, assets, measures, n_sim) {
    list(n = n_sim)
  }, envir = asNamespace("vofi"))
  registerS3method("tax_step", "tax_tk_tax", function(module, t, inputs, interest, state,
                                                       params) {
    list(payment = rep(params$rate %||% 0, state$n), state = state, report = list())
  }, envir = asNamespace("vofi"))
  registerS3method("tax_finalize", "tax_tk_tax", function(module, T, state, terminal_inputs, # nolint
                                                           params) {
    list(payment_T = rep(0, state$n), report = list())
  }, envir = asNamespace("vofi"))
  tx <- vofi_type("tk_tax", "tax", label = "Test",
                  labels = list(description = "d", params = list(rate = "Satz"), rows = list()),
                  params = list(rate = vofi_param("share")),
                  constructor = function(params, spec) new_tax_module("tk_tax", params = params),
                  example = list(rate = 0))
  vofi_register_type(tx)
  expect_true(all(findings_of("tk_tax")$ok))
  tx2 <- tx
  tx2$example <- list(rate = 0.3)
  tx2$name <- "tk_tax2"
  tx2$constructor <- function(params, spec) new_tax_module("tk_tax", params = params)
  vofi_register_type(tx2)
  expect_false(all(findings_of("tk_tax2")$ok))
  rule <- vofi_type("tk_cap", "rule", label = "Kappung",
                    labels = list(description = "d", params = list(), rows = list()),
                    fun = function(x, cap) pmin(x, cap), valid_from = "2026-01-01",
                    returns = "sim", example = list(x = 10, cap = 12))
  vofi_register_type(rule)
  expect_true(all(findings_of("tk_cap@2026-01-01", "rule")$ok))
})
