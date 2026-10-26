# Exportierte API (Integrator; Spec 00 Abschnitt 14): Namen und exakte Signaturen. Eigentümer
# ersetzen nur Rümpfe; eine Signaturänderung ist eine MAJOR-Vertragsänderung (Abschnitt 1.4).

api_signatures <- list(
  vofi_read_scenario = 'function(path, format = c("auto", "yaml", "excel"), stochastic = NULL, library_paths = vofi_library_paths())',
  vofi_write_scenario = 'function(scenario, path, format = c("auto", "yaml", "excel"), resolved = FALSE, variant = "base", overwrite = FALSE)',
  vofi_scenario = 'function(x, source = NULL)',
  vofi_example = 'function(name = NULL)',
  vofi_excel_template = 'function(path, example = NULL, overwrite = FALSE)',
  vofi_library = 'function(block = NULL, library_paths = vofi_library_paths(), date = NULL)',
  vofi_library_paths = 'function(add = NULL)',
  vofi_variants = 'function(scenario)',
  vofi_resolve = 'function(scenario, variant = "base", overrides = NULL, scenario_set = NULL)',
  vofi_validate = 'function(x, variant = NULL, min_severity = c("info", "warning", "error"))',
  vofi_json_schema = 'function(path = NULL)',
  vofi_time_grid = 'function(valuation_date, horizon_years, construction_months = 0L, construction_step_months = 12L, operation_step_months = 12L, operation_alignment = c("calendar", "completion"), periods_months = NULL, start_year = NULL)',
  vofi_build = 'function(x, variant = "base", overrides = NULL, scenario_set = NULL)',
  vofi_run = 'function(model, n_sim = 1L, seed = NULL, store = c("auto", "full", "bands", "kpi"), chunk_size = getOption("vofi.chunk_size", 2000L))',
  vofi_mc = 'function(model, n_sim = NULL, seed = NULL, sampling = NULL, block_size = NULL, store = NULL, bands = NULL, keep_runs = NULL, parallel = FALSE, chunk_size = getOption("vofi.chunk_size", 2000L), preview = FALSE)',
  vofi_sim = 'function(x, i)',
  vofi_opportunity = 'function(x)',
  vofi_compare = 'function(x, variants = NULL, baseline = NULL, scenario_sets = NULL, n_sim = 1L, seed = NULL, store = c("auto", "bands", "kpi"), allow_unequal = FALSE)',
  vofi_sensitivity = 'function(x, params = NULL, method = c("tornado", "spider", "global"), probs = c(0.1, 0.9), delta = NULL, steps = 5L, kpi = NULL, variant = "base", reference = NULL)',
  vofi_solve = 'function(x, what = c("breakeven", "critical_value", "withdrawal_equivalent", "incremental_return"), param = NULL, kpi = NULL, target = 0, interval = NULL, tol = 1e-08, variant = "base", reference = NULL, rebuild = FALSE)',
  vofi_kpis = 'function(x, which = NULL, rv = c("both", "with", "without"), per = c("total", "unit", "m2"))',
  vofi_table = 'function(x, sim = 1L, layout = c("grob", "transposed"), detail = c("standard", "full"), periods = NULL, variant = NULL)',
  vofi_ledger = 'function(x, format = c("long", "wide"), sim = NULL, vat = FALSE)',
  vofi_plot = 'function(x, type = NULL, ...)',
  vofi_export_excel = 'function(x, path, overwrite = FALSE, sheets = NULL)',
  vofi_report = 'function(x, path, format = c("html", "docx"), mode = c("auto", "expert", "household"), template = NULL, title = NULL, open = interactive())',
  vofi_tenant_view = 'function(x, variant = NULL)',
  vofi_household_view = 'function(x, variant = NULL)',
  vofi_app = 'function(scenario = NULL, launch.browser = interactive(), ...)',
  vofi_type = 'function(name, kind, params = list(), ..., example = NULL, label = NULL, version = 1L)',
  vofi_register_type = 'function(def, overwrite = FALSE)',
  vofi_types = 'function(kind = NULL)',
  vofi_type_info = 'function(name, kind = NULL)',
  vofi_check_type = 'function(name, kind = NULL, n = c(1L, 2L, 7L))',
  vofi_param = 'function(kind, ..., default = NULL, required = FALSE, min = NULL, max = NULL, unit = NULL, stochastic = NULL, values = NULL, allow_auto = FALSE, shapes = NULL, deterministic_only = FALSE, fields = NULL)',
  vofi_row = 'function(key, values, section, category, tax_category = NULL, cash = NULL, kind = c("flow", "stock", "memo"), unit = "EUR", asset_id = NULL, measure_id = NULL, vat_rate = 0, vat_recoverable = FALSE, is_tax = NULL, program = NULL, label = NULL, label_key = NULL, ...)',
  vofi_flows = 'function(..., assets = list(), measures = list(), aux = list(), meta = list())',
  vofi_asset = 'function(asset_id, asset_type, in_service_date, land_share = 0, afa_method = NULL, useful_life_override = NULL, construction_start_date = NULL, building_application_date = NULL, original_completion_year = NULL, acquisition_date = NULL, living_area_m2 = NULL, efficiency_standard = NULL, label = NULL)',
  vofi_measure = 'function(measure_id, measure_type, classification = c("auto", "erhaltung", "herstellung"), classification_source = c("default", "user", "rule"), completion_date = NULL, paid_in_full_date = NULL, contractor_certified = NA, funding_choice = c("keine", "beg_zuschuss", "beg_kredit", "35c"), asset_id = NULL, label = NULL)',
  vofi_kpi_value = 'function(values, na_reason = NULL, years = NULL)',
  vofi_register_kpi = 'function(name, compute, label = NULL, unit = "EUR", shape = c("scalar", "series"), rv_variant = FALSE, higher_is_better = TRUE, mc_default = FALSE, perspectives = NULL, requires = character(), overwrite = FALSE)',
  vofi_register_tax_module = 'function(name, constructor, label = NULL, perspectives = NULL, blocked_regimes = NULL, params = list(), overwrite = FALSE)',
  vofi_tax_module_simple = 'function(name, fun, label = NULL)',
  tax_init = 'function(module, params, assets, measures, n_sim)',
  tax_step = 'function(module, t, inputs, interest, state, params)',
  tax_finalize = 'function(module, T, state, terminal_inputs, params)'
)

signature_of <- function(f) {
  txt <- deparse(args(f), width.cutoff = 500L)
  txt <- paste(trimws(txt[txt != "NULL"]), collapse = " ")
  gsub("\\s+", " ", txt)
}

test_that("alle 46 Funktionen aus Abschnitt 14 sind exportiert, keine weiteren", {
  exports <- getNamespaceExports("vofi")
  expect_identical(length(api_signatures), 46L)
  expect_setequal(setdiff(exports, character(0)), names(api_signatures))
})

test_that("Signaturen entsprechen exakt Abschnitt 14", {
  ns <- asNamespace("vofi")
  for (nm in names(api_signatures)) {
    expected <- eval(parse(text = paste(api_signatures[[nm]], "NULL")))
    expect_identical(signature_of(get(nm, envir = ns)), signature_of(expected), info = nm)
  }
})

test_that("S3-Methoden des Integrators und Steuer-Generics sind registriert", {
  expect_true(is.function(getS3method("print", "vofi_grid")))
  expect_true(is.function(getS3method("as.data.frame", "vofi_grid")))
  for (g in c("tax_init", "tax_step", "tax_finalize")) {
    expect_true(is.function(getS3method(g, "default")), info = g)
  }
  expect_error(tax_init(structure(list(), class = "tax_unbekannt"), list(), list(), list(), 1L),
               class = "vofi_error_registry")
  expect_error(tax_step(list(), 0L, list(), list(), list(), list()), class = "vofi_error_registry")
  expect_error(tax_finalize(list(), 1L, list(), list(), list()), class = "vofi_error_registry")
  m <- new_tax_module("none", params = list(a = 1))
  expect_s3_class(m, c("tax_none", "vofi_tax_module"), exact = TRUE)
})

test_that("Stubs melden vofi_error_not_implemented (Phase 0)", {
  ns <- asNamespace("vofi")
  stubs <- names(api_signatures)[vapply(names(api_signatures), is_stub, logical(1))]
  for (nm in stubs) {
    f <- get(nm, envir = ns)
    fm <- formals(f)
    args <- lapply(names(fm), function(a) NULL)
    names(args) <- names(fm)
    args <- args[names(args) != "..."]
    expect_error(do.call(f, args), class = "vofi_error_not_implemented", info = nm)
  }
})
