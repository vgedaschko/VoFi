# Testhelfer von WS-X (Steuermodul tax_flat; Spec 00 Abschnitte 10.7, 10.10).
#
# wsx_run() rechnet das Modul direkt über die Perioden eines Rasters (ohne Engine) mit
# synthetischen Eingabezeilen in der Form von tax_inputs()/tax_slice() (10.4) und Zinsgrößen
# je Periode; wsx_scenario() baut ein Engine-Szenario des Standardmodells (wie
# tax_test_scenario() von WS-D) mit tax_flat. Abhängigkeiten zu anderen Paketen: keine Attrappen;
# die Engine (WS-D) und das Prüfkit (Integrator) werden direkt genutzt.

#' Eingabezeile für Modultests
#' @param values Vektor der Länge T+1 (für alle Läufe gleich) oder Matrix n x (T+1).
wsx_row <- function(key, tax_category, values, category = "custom", asset_id = NA_character_,
                    measure_id = NA_character_, extra = list(), source = "exo",
                    section = "project") {
  list(key = key, tax_category = tax_category, values = values, category = category,
       asset_id = asset_id, measure_id = measure_id, extra = extra, source = source,
       section = section)
}

#' Metadaten der Eingabezeilen wie tax_keys_df() (10.4)
wsx_keys <- function(rows) {
  if (length(rows) == 0L) return(tax_keys_empty())
  out <- data.frame(
    key = vapply(rows, function(r) r$key, ""),
    source = vapply(rows, function(r) r$source, ""),
    section = vapply(rows, function(r) r$section, ""),
    category = vapply(rows, function(r) r$category, ""),
    tax_category = vapply(rows, function(r) r$tax_category, ""),
    asset_id = vapply(rows, function(r) as.character(r$asset_id), ""),
    measure_id = vapply(rows, function(r) as.character(r$measure_id), ""),
    cash = TRUE, stringsAsFactors = FALSE
  )
  out$extra <- I(lapply(rows, function(r) r$extra))
  out
}

#' Modul tax_flat direkt über alle Perioden rechnen
#' @param interest benannte Liste (`exo_soll`, `exo_fees`, `endo_soll`, `endo_haben`,
#'   `endo_wht`) je Vektor der Länge T+1 oder Matrix n x (T+1).
#' @return Liste `pay` (n x (T+1)), `report` (Liste n x (T+1)), `fin` (Ergebnis von
#'   tax_finalize()), `state`, `module`.
wsx_run <- function(params = list(), rows = list(), grid = make_grid("annual", T = 6L), n = 1L,
                    perspective = "kleinvermieter", regime = NULL, assets = list(),
                    measures = list(), interest = list(), rv = 0, rv_method = "income_value",
                    project = list()) {
  proj <- project
  if (!is.null(regime)) proj$tax_regime <- regime
  spec <- reg_test_spec(grid, perspective = perspective, project = proj)
  spec$registers <- list(assets = assets, measures = measures)
  spec$residual_value$method <- rv_method
  module <- suppressMessages(reg_get("tax", "flat")$constructor(params, spec))
  n <- as.integer(n)
  n_t <- grid$T + 1L
  mat <- function(v) {
    if (is.matrix(v)) return(v)
    matrix(rep(as.double(v), each = n), n, n_t)
  }
  keys <- wsx_keys(rows)
  vals <- stats::setNames(lapply(rows, function(r) mat(r$values)), keys$key)
  int_names <- c("exo_soll", "exo_fees", "endo_soll", "endo_haben", "endo_wht")
  ints <- stats::setNames(lapply(int_names, function(nm) mat(interest[[nm]] %||% 0)), int_names)
  state <- tax_init(module, module$params, assets, measures, n)
  pay <- matrix(0, n, n_t)
  rep <- list()
  for (j in seq_len(n_t)) {
    t <- j - 1L
    sel_exo <- keys$source == "exo"
    inputs <- list(t = t, date_end = grid$date_end[j], delta = grid$delta[j],
                   year = grid$year[j], phase = grid$phase[j],
                   exo = lapply(vals[sel_exo], function(m) m[, j]),
                   inst = lapply(vals[!sel_exo], function(m) m[, j]), keys = keys)
    r <- tax_step(module, t, inputs, lapply(ints, function(m) m[, j]), state, module$params)
    state <- r$state
    pay[, j] <- r$payment
    for (nm in names(r$report)) {
      if (is.null(rep[[nm]])) rep[[nm]] <- matrix(0, n, n_t)
      rep[[nm]][, j] <- r$report[[nm]]
    }
  }
  fin <- tax_finalize(module, grid$T, state,
                      list(exo_T = list(), residual_value = rep_len(as.double(rv), n),
                           market_value_T = NULL, horizon_date = grid$end_date,
                           assets = assets, measures = measures),
                      module$params)
  list(pay = pay, report = rep, fin = fin, state = state, module = module)
}

#' Szenario des Standardmodells (Investition mit Anlage, Mieten, EK, Konten zu i) mit tax_flat
#' @param params Parameter von tax_flat (`tax.params`).
wsx_scenario <- function(params = list(rate = 0.3, lag = 0L, deposit_interest = "ergebnis",
                                       building_rate = 1 / 3),
                         i = 0.05, rent = c(0, 30000, 40000, 50000), ek = 60000,
                         project = list()) {
  sc <- wsd_scenario(
    rent, ek = list(type = "equity", amount_eur = ek),
    accounts = list(deposit_rate_pa = i, overdraft_rate_pa = i, overdraft_limit_eur = Inf),
    components = list(inv = list(type = "custom_series", category = "capex",
                                 tax_category = "capex_depreciable", asset_id = "geb",
                                 values = c(-100000, rep(0, length(rent) - 1L)))),
    project = project
  )
  sc$components$z$category <- "rent"
  sc$tax <- list(module = "flat", params = params)
  sc
}

#' Ziehungen mit Faktor auf die Mietzeile z (apply multiply; Batch- und Chunk-Invarianz)
wsx_factor_draws <- function(grid, f) {
  n <- length(f)
  targets <- data.frame(key = "components.z.values", target = "components.z.values",
                        kind = "static", apply = "multiply", stringsAsFactors = FALSE)
  new_vofi_draws("mc", n = n, sims = seq_len(n), blocks = 1L, block_size = n,
                 static = list("components.z.values" = f), paths = list(), targets = targets,
                 years = grid$years)
}

#' Modell bauen, Meldungen und Plausibilitätswarnungen der Bibliothek unterdrücken
wsx_build <- function(sc) {
  suppressMessages(suppressWarnings(vofi_build(sc)))
}
