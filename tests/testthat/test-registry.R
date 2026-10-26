# Tests für R/registry.R und den Konstruktor vofi_param() (Integrator; Spec 00 Abschnitt 5).

#' Registry für die Dauer eines Tests sichern und wiederherstellen
local_registry <- function(env = parent.frame()) {
  old <- reg_state$types
  withr::defer(reg_state$types <- old, envir = env)
  invisible(old)
}

#' Minimaler gültiger Nutzer-Flowtyp
helper_flow_def <- function(name = "tk_einnahme", ...) {
  vofi_type(
    name = name, kind = "flow", label = "Testeinnahme",
    labels = list(description = "Testtyp", params = list(amount_eur = "Betrag"),
                  rows = list(value = "Einnahme")),
    params = list(amount_eur = vofi_param("amount", required = TRUE)), rows = "value",
    build = function(spec, ctx) {
      v <- ctx$by_sim(ctx$param(spec, "amount_eur")) * ctx$by_period(ctx$grid$delta)
      vofi_flows(vofi_row("value", v, section = "project", category = "other_income"))
    },
    example = list(type = name, amount_eur = 1000), ...
  )
}

test_that("vofi_param: artabh\u00e4ngige Defaults (5.4)", {
  p <- vofi_param("rate", required = TRUE)
  expect_s3_class(p, "vofi_param")
  expect_identical(c(p$min, p$max), c(-0.1, 1))
  expect_identical(p$shapes, "scalar")
  expect_true(p$stochastic)
  expect_false(p$deterministic_only)
  expect_identical(vofi_param("share")$max, 1)
  expect_identical(vofi_param("amount")$min, -Inf)
  expect_identical(vofi_param("value")$shapes, c("scalar", "path"))
  expect_identical(vofi_param("schedule")$shapes, "path")
  for (k in c("integer", "enum", "logical", "date", "string", "timing", "ref", "ids")) {
    p <- if (k == "enum") vofi_param(k, values = c("a", "b")) else vofi_param(k)
    expect_true(p$deterministic_only, info = k)
    expect_false(p$stochastic, info = k)
  }
  m <- vofi_param("map", fields = list(share = vofi_param("share")))
  expect_true(is.na(m$stochastic))
  e <- vofi_param("enum", values = "vocab:refi_rule", default = "keep_term", note = "x")
  expect_identical(utl_param_codes(e), c("keep_term", "keep_tilg_rate", "keep_payment"))
  expect_identical(e$extra, list(note = "x"))
  expect_true(vofi_param("amount", allow_auto = TRUE, deterministic_only = TRUE)$allow_auto)
})

test_that("vofi_param: Fehler bei unzul\u00e4ssigen Angaben", {
  er <- "vofi_error_registry"
  expect_error(vofi_param("zahl"), class = er)
  expect_error(vofi_param("rate", allow_auto = TRUE), class = er)
  expect_error(vofi_param("enum"), class = er)
  expect_error(vofi_param("number", values = "a"), class = er)
  expect_error(vofi_param("map"), class = er)
  expect_error(vofi_param("number", fields = list()), class = er)
  expect_error(vofi_param("number", min = 2, max = 1), class = er)
  expect_error(vofi_param("number", shapes = "matrix"), class = er)
  expect_error(vofi_param("number", unit = "furlong"), class = er)
  expect_error(vofi_param("number", required = NA), class = er)
})

test_that("vofi_type: Felder und artspezifische Defaults", {
  d <- helper_flow_def()
  expect_s3_class(d, "vofi_typedef")
  expect_identical(d$rows, "value")
  expect_false(d$grid_invariant)
  expect_null(d$perspectives)
  k <- vofi_type("tk_kpi", "kpi", compute = function(core, ctx) NULL, label = "K")
  expect_identical(k$unit, "EUR")
  expect_identical(k$shape, "scalar")
  expect_false(k$mc_default)
  r <- vofi_type("tk_regel", "rule", fun = function(x) x, valid_from = "2026-01-01",
                 returns = "sim", label = "R")
  expect_identical(r$name, "tk_regel@2026-01-01")
  expect_identical(r$rule_name, "tk_regel")
  expect_identical(r$valid_from, as.Date("2026-01-01"))
  r2 <- vofi_type("tk_regel@2027-01-01", "rule", fun = function(x) x, returns = "sim",
                  label = "R")
  expect_identical(r2$valid_from, as.Date("2027-01-01"))
  expect_error(vofi_type("x", "gibtsnicht"), class = "vofi_error_registry")
  expect_error(vofi_type(1, "flow"), class = "vofi_error_registry")
  expect_error(vofi_type("x", "flow", list(), function(spec, ctx) 1),
               class = "vofi_error_registry")
  expect_error(vofi_register_type(vofi_type("x", "flow", function(spec, ctx) 1, label = "x")),
               class = "vofi_error_registry")
})

test_that("Registrierung, Abruf, Liste, Info", {
  local_registry()
  d <- helper_flow_def()
  expect_identical(vofi_register_type(d), d)
  expect_true(reg_has("flow", "tk_einnahme"))
  expect_identical(reg_get("flow", "tk_einnahme")$name, "tk_einnahme")
  expect_identical(reg_source("flow", "tk_einnahme"), "user")
  tl <- vofi_types("flow")
  expect_true("tk_einnahme" %in% tl$name)
  expect_identical(tl$label[tl$name == "tk_einnahme"], "Testeinnahme")
  info <- vofi_type_info("tk_einnahme")
  expect_identical(info$kind, "flow")
  expect_identical(info$description, "Testtyp")
  expect_identical(info$params$param, "amount_eur")
  expect_identical(info$params$label, "Betrag")
  expect_identical(info$rows$label, "Einnahme")
  expect_true(info$params$required)
  expect_error(vofi_register_type(d), class = "vofi_error_registry")
  expect_silent(vofi_register_type(d, overwrite = TRUE))
  expect_error(reg_get("flow", "tk_einnahm"), "tk_einnahme", class = "vofi_error_registry")
  expect_error(vofi_type_info("gibtsnicht"), class = "vofi_error_registry")
  expect_error(vofi_types("blub"), class = "vofi_error_input")
  expect_error(vofi_register_type(d, overwrite = NA), class = "vofi_error_input")
  df <- reg_list()
  expect_identical(names(df), c("kind", "name", "version", "source"))
})

test_that("flow- und instrument-Namen sind gemeinsam eindeutig; eingebaute Typen", {
  local_registry()
  reg_add(helper_flow_def("tk_x"), source = "vofi")
  inst <- vofi_type("tk_x", "instrument", label = "I",
                    init = function(spec, ctx) list(), step = function(state, t, ctx) list(),
                    example = list(type = "tk_x"))
  expect_error(vofi_register_type(inst), class = "vofi_error_registry")
  expect_warning(vofi_register_type(inst, overwrite = TRUE))
  expect_false(reg_has("flow", "tk_x"))
  expect_true(reg_has("instrument", "tk_x"))
  expect_identical(vofi_type_info("tk_x")$kind, "instrument")
})

test_that("Nutzertypen brauchen ein label-Literal", {
  local_registry()
  d <- helper_flow_def()
  d$label <- NULL
  expect_error(vofi_register_type(d), class = "vofi_error_registry")
})

test_that("statische Vertragspr\u00fcfung C1-C3 bei der Registrierung", {
  local_registry()
  er <- "vofi_error_registry"
  bad_name <- helper_flow_def("Tk-Name")
  expect_error(vofi_register_type(bad_name), class = er)
  bad_formals <- helper_flow_def()
  bad_formals$build <- function(spec, context) NULL
  e <- tryCatch(vofi_register_type(bad_formals), error = identity)
  expect_s3_class(e, er)
  expect_true("C2" %in% e$data$findings$check)
  missing_fun <- helper_flow_def()
  missing_fun$build <- NULL
  expect_error(vofi_register_type(missing_fun), class = er)
  reserved <- helper_flow_def()
  reserved$params$label <- vofi_param("string")
  e <- tryCatch(vofi_register_type(reserved), error = identity)
  expect_true("C3" %in% e$data$findings$check)
  no_example <- helper_flow_def()
  no_example$example <- NULL
  expect_error(vofi_register_type(no_example), class = er)
  unknown_param <- helper_flow_def()
  unknown_param$example$foo <- 1
  expect_error(vofi_register_type(unknown_param), class = er)
  missing_req <- helper_flow_def()
  missing_req$example$amount_eur <- NULL
  expect_error(vofi_register_type(missing_req), class = er)
  bad_rows <- helper_flow_def()
  bad_rows$rows <- c("value", "x__y")
  expect_error(vofi_register_type(bad_rows), class = er)
  pat <- helper_flow_def()
  pat$rows <- c("value", "levy_*")
  pat$labels$rows[["levy_*"]] <- "Umlage {id}"
  expect_silent(vofi_register_type(pat))
  bad_version <- helper_flow_def("tk_v", version = 0L)
  expect_error(vofi_register_type(bad_version), class = er)
  bad_persp <- helper_flow_def("tk_p", perspectives = "investor")
  expect_error(vofi_register_type(bad_persp), class = er)
  inst <- vofi_type("tk_i", "instrument", label = "I",
                    init = function(spec, ctx) list(), step = function(state, t, ctx) list(),
                    prepay = function(state, amount, t, ctx) list(),
                    example = list(type = "tk_i"))
  expect_error(vofi_register_type(inst), class = er)
  act <- vofi_type("tk_a", "account_action", label = "A", role = "surplus", rank = "D1",
                   rows = "dep_invest", apply = function(acc, amount, t, ctx, inst) NULL)
  expect_error(vofi_register_type(act), class = er)
  kp <- vofi_type("tk_k", "kpi", label = "K", unit = "Euro",
                  compute = function(core, ctx) NULL)
  expect_error(vofi_register_type(kp), class = er)
  pr <- vofi_type("tk_pr", "process", label = "P", output = "level",
                  simulate = function(par, z, u, years) NULL,
                  expected = function(par, years) NULL, n_shocks = function(par) 1,
                  n_uniforms = function(par) 0, validate = function(par) character(),
                  example = list())
  expect_error(vofi_register_type(pr), class = er)
  # domain_reads (5.2, C3): nur flow/instrument, Codes aus der Blockliste
  dr_bad <- helper_flow_def("tk_dr", domain_reads = c("measures", "unsinn"))
  expect_error(vofi_register_type(dr_bad), class = er)
  dr_ok <- helper_flow_def("tk_dr2", domain_reads = c("measures", "unit_groups"))
  expect_silent(vofi_register_type(dr_ok))
  expect_null(helper_flow_def("tk_dr3")$domain_reads)
  kp_dr <- vofi_type("tk_kdr", "kpi", label = "K", domain_reads = "measures",
                     compute = function(core, ctx) NULL)
  expect_error(vofi_register_type(kp_dr), class = er)
  # Regeln: returns aus vocab rule_returns (inkl. value, R-93)
  rv <- vofi_type("tk_rv", "rule", fun = function(procedure, P) TRUE, valid_from = "2026-01-01",
                  returns = "value", label = "R")
  expect_silent(vofi_register_type(rv))
  rbad <- vofi_type("tk_rbad", "rule", fun = function(x) x, valid_from = "2026-01-01",
                    returns = "egal", label = "R")
  expect_error(vofi_register_type(rbad), class = er)
})

test_that("Rechtsregeln: Versionen mit identischen Formals", {
  local_registry()
  r1 <- vofi_type("tk_regel", "rule", fun = function(x, y) x, valid_from = "2026-01-01",
                  returns = "sim", label = "R")
  r2 <- vofi_type("tk_regel", "rule", fun = function(x, y) y, valid_from = "2024-01-01",
                  returns = "sim", label = "R")
  r3 <- vofi_type("tk_regel", "rule", fun = function(x) x, valid_from = "2028-01-01",
                  returns = "sim", label = "R")
  vofi_register_type(r1)
  vofi_register_type(r2)
  expect_identical(vapply(reg_rules("tk_regel"), function(d) d$name, ""),
                   c("tk_regel@2024-01-01", "tk_regel@2026-01-01"))
  expect_error(vofi_register_type(r3), class = "vofi_error_registry")
  expect_identical(reg_discovery_name(r1), "typedef_rule_tk_regel_20260101")
  expect_identical(reg_label_prefix(r1), "types.rule.tk_regel")
})

test_that("Discovery-Namen je Art (5.1)", {
  mk <- function(kind, name) structure(list(kind = kind, name = name), class = "vofi_typedef")
  expect_identical(reg_discovery_name(mk("flow", "equity")), "typedef_equity")
  expect_identical(reg_discovery_name(mk("instrument", "bullet_loan")), "typedef_bullet_loan")
  expect_identical(reg_discovery_name(mk("account_action", "od_draw")), "typedef_action_od_draw")
  expect_identical(reg_discovery_name(mk("expander", "measures")), "typedef_expander_measures")
  expect_identical(reg_discovery_name(mk("distribution", "pert")), "typedef_dist_pert")
  expect_identical(reg_discovery_name(mk("process", "ar1")), "typedef_process_ar1")
  expect_identical(reg_discovery_name(mk("kpi", "terminal_value")), "typedef_kpi_terminal_value")
  expect_identical(reg_discovery_name(mk("tax", "none")), "typedef_tax_none")
})

test_that("reg_discover registriert typedef_* und pr\u00fcft die Namen", {
  local_registry()
  env <- new.env()
  env$typedef_tk_d <- function() helper_flow_def("tk_d")
  expect_identical(reg_discover(env), 1L)
  expect_true(reg_has("flow", "tk_d"))
  env2 <- new.env()
  env2$typedef_tk_falsch <- function() helper_flow_def("tk_anders")
  expect_error(reg_discover(env2), class = "vofi_error_registry")
})

test_that("Labels eingebauter Typen kommen aus dem Katalog", {
  local_registry()
  d <- helper_flow_def("tk_katalog")
  d$label <- NULL
  reg_add(d, source = "vofi")
  local_vofi_options(vofi.strict_labels = TRUE)
  expect_identical(vofi_types("flow")$label[vofi_types("flow")$name == "tk_katalog"],
                   "tk_katalog")
  info <- vofi_type_info("tk_katalog")
  expect_true(is.na(info$description))
})
