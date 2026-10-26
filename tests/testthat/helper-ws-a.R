# Testhelfer von WS-A (Eingabe, Schichten, Bibliothek; Spec 00 Abschnitt 15.1).
#
# Abhängigkeiten zu anderen Paketen (im Bericht an den Integrator genannt):
# 1. helper-contracts.R (Integrator) führt vofi_library() und vofi_write_scenario() noch als
#    Stubs; WS-A liefert beide. vofi_stubs() wird hier um diese Namen verkleinert (verkettbar
#    mit gleichartigen Helfern anderer Pakete), bis der Integrator die Liste anpasst.
# 2. Das Phase-0-Schema von WS-B (val_domain_schema(), val_known_extra_fields()) kennt die
#    Felder von residual_value aus global.yaml (Spec 01 Teil A 2.2, 6.1) noch nicht; ohne Patch
#    meldet vofi_validate() dafür validation.unknown_field. Der Patch ergänzt nur Felder, die
#    global.yaml und die Profile tatsächlich setzen und die das Schema noch nicht kennt; er ist
#    wirkungslos, sobald WS-B das Schema nach Spec 01 liefert.

if (exists("vofi_stubs", mode = "function")) {
  vofi_stubs <- local({
    orig_stubs <- vofi_stubs
    function() setdiff(orig_stubs(), c("vofi_library", "vofi_write_scenario"))
  })
}

local({
  ns <- asNamespace("vofi")
  orig <- get("val_known_extra_fields", envir = ns)
  files <- c(system.file("extdata", "defaults", "global.yaml", package = "vofi"),
             list.files(system.file("extdata", "profiles", package = "vofi"),
                        pattern = "\\.yaml$", full.names = TRUE))
  files <- files[nzchar(files) & file.exists(files)]
  blocks <- c("meta", "project", "grid", "building", "household", "accounts",
              "residual_value", "tax", "analysis")
  extra <- list()
  for (f in files) {
    raw <- get("io_read_yaml_utf8", envir = ns)(f)
    items <- raw$item_defaults %||% list()
    trees <- c(list(raw), unname(raw$by_project_type %||% list()),
               list(items[intersect(names(items), blocks)]))
    for (t in trees) {
      for (b in intersect(blocks, names(t))) {
        known <- c(names(get("val_domain_schema", envir = ns)(b)), orig(b))
        extra[[b]] <- unique(c(extra[[b]], setdiff(names(t[[b]]), known)))
      }
    }
  }
  rules <- get("scn_rule_fields", envir = ns)()
  for (b in intersect(blocks, names(rules))) {
    known <- c(names(get("val_domain_schema", envir = ns)(b)), orig(b))
    extra[[b]] <- unique(c(extra[[b]], setdiff(rules[[b]], known)))
  }
  extra <- Filter(length, extra)
  if (length(extra) > 0L) {
    patched <- function(block) unique(c(orig(block), extra[[block]]))
    environment(patched) <- list2env(list(orig = orig, extra = extra), parent = ns)
    utils::assignInNamespace("val_known_extra_fields", patched, ns = "vofi")
  }
})

#' Wurzel der Testbibliothek (tests/testthat/fixtures/library)
ws_a_lib <- function(...) testthat::test_path("fixtures", "library", ...)

#' Testbibliothek als Paketbibliothek (Schicht 3) für einen Test
#'
#' Ersetzt `lib_package_root()` für die Dauer des Tests (die Paketbibliothek von WS-L folgt in
#' Welle 3) und leert den Zwischenspeicher des Index.
local_ws_a_library <- function(env = parent.frame()) {
  root <- normalizePath(ws_a_lib(), winslash = "/", mustWork = TRUE)
  testthat::local_mocked_bindings(lib_package_root = function() root, .env = env)
  ns <- asNamespace("vofi")
  st <- get("lib_state", envir = ns)
  st$index <- NULL
  withr::defer(st$index <- NULL, envir = env)
  invisible(root)
}

#' Minimales Szenario (Liste) mit Perspektive, Projektart und expliziten Kennzahlen
ws_a_scenario <- function(..., perspective = "wu_privat", project_type = "sanierung_eh",
                          valuation_date = "2027-01-01", horizon_years = NULL) {
  project <- list(perspective = perspective, project_type = project_type,
                  valuation_date = valuation_date)
  if (!is.null(horizon_years)) project$horizon_years <- horizon_years
  base <- list(
    schema_version = 1L,
    meta = list(scenario_id = "ws_a", title = "WS-A Test"),
    project = project,
    components = list(z = list(type = "custom_series", values = c(-100, 50, 60))),
    financing = list(ek = list(type = "equity", amount_eur = 100)),
    analysis = list(kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value"))
  )
  extra <- list(...)
  for (nm in names(extra)) {
    base[[nm]] <- if (is.list(base[[nm]]) && is.list(extra[[nm]]) && !is.null(names(extra[[nm]])))
      utils::modifyList(base[[nm]], extra[[nm]]) else extra[[nm]]
  }
  base
}

#' Variante auflösen ohne Hinweise und ohne Veraltungswarnungen der Testbibliothek
#'
#' Die Testbibliothek bildet Spec 01 Teil C nach; `costs/bewirtschaftung_immowertv_2026` gilt
#' bis 2027-01-01 und ist daher zu jedem Stichtag 2027-01-01 veraltet (D10). Die Warnung prüft
#' `test-scenario-layers.R` gesondert.
ws_a_resolve <- function(x, ...) {
  sc <- if (inherits(x, "vofi_scenario")) x else vofi_scenario(x)
  withCallingHandlers(
    vofi_resolve(sc, ...),
    vofi_warning_library_outdated = function(w) invokeRestart("muffleWarning"),
    message = function(m) invokeRestart("muffleMessage")
  )
}

#' Ausdruck ohne Hinweise und ohne Veraltungswarnungen auswerten
ws_a_quiet <- function(expr) {
  withCallingHandlers(
    expr,
    vofi_warning_library_outdated = function(w) invokeRestart("muffleWarning"),
    message = function(m) invokeRestart("muffleMessage")
  )
}

#' Herkunftszeile eines Pfads
ws_a_prov <- function(spec, path) {
  p <- attr(spec, "provenance")
  p[p$path == path, , drop = FALSE]
}

#' Basisfallwert eines Pfads der aufgelösten Spezifikation (n = 1)
ws_a_value <- function(spec, path, shape = "scalar") {
  ns <- asNamespace("vofi")
  grid <- get("scn_grid", envir = ns)(spec)
  get("scn_value_base", envir = ns)(spec, grid, path, shape)
}
