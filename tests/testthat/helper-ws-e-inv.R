# Testhelfer von WS-E-INV (Zahlungsbausteine Investition/Bestand/Restwert). Dünne Hülle um das
# Prüfkit: baut mehrere Komponenten in Reihenfolge, damit abhängige Typen (replacement,
# maintenance, share_of, residual_value) ihre Abhängigkeiten über ctx$component()/ctx$rows()
# lesen können. Der Basisfall (ctx$component_base()) ist der deterministische Bau mit n = 1.

#' Rohkomponenten normalisieren (Liste id -> list(type = ..., <Parameter>))
wsei_components <- function(comps) {
  out <- list()
  for (id in names(comps)) {
    raw <- comps[[id]]
    out[[id]] <- do.call(make_component, c(list(raw$type), raw[setdiff(names(raw), "type")],
                                           list(id = id)))
  }
  out
}

#' Komponenten in Reihenfolge bauen
#'
#' @param comps benannte Liste id -> Rohkomponente (Typ und Parameter wie in YAML).
#' @param grid Raster.
#' @param n Laufzahl; `draws` optional (sonst leere Ziehungen im Modus "mc" bei n > 1).
#' @param spec_fun optionale Funktion `function(spec) spec` (z. B. Rechtsstand, Domänenblöcke).
#' @param market rohe Marktannahmen (über den Prüfkit-Markt gemischt).
#' @return Liste `flows` (je id), `base` (Basisfall n = 1), `spec`, `ctx` (Kontext des letzten
#'   Baus).
wsei_build <- function(comps, grid = make_grid(), n = 1L, draws = NULL, spec_fun = NULL,
                       market = list(), perspective = "wu_kommunal") {
  norm <- wsei_components(comps)
  spec <- reg_test_spec(grid, perspective = perspective,
                        market = deep_merge(reg_test_market_raw(), market))
  for (id in names(norm)) {
    spec <- path_set(spec, path_join(helper_collection(norm[[id]]), id), norm[[id]])
  }
  if (is.function(spec_fun)) spec <- spec_fun(spec)
  run <- function(nn, dr, base_flows) {
    mode <- if (is.null(dr)) "deterministic" else dr$mode
    built <- list()
    ctx <- NULL
    for (id in names(norm)) {
      comp <- spec[[helper_collection(norm[[id]])]][[id]]
      def <- reg_get("flow", comp$type)
      deps <- eng_component_deps(comp, def, names(norm))
      ctx <- eng_context_from_parts(grid, spec, draws = dr, components = built,
                                    components_base = base_flows %||% built, mode = mode,
                                    engine_env = reg_engine_env("flows", deps = deps))
      built[[id]] <- def$build(comp, ctx)
    }
    list(flows = built, ctx = ctx)
  }
  base <- run(1L, NULL, NULL)
  n <- as.integer(n)
  if (n == 1L && is.null(draws)) {
    return(list(flows = base$flows, base = base$flows, spec = spec, ctx = base$ctx))
  }
  if (is.null(draws)) draws <- fake_draws(n, grid)
  res <- run(n, draws, base$flows)
  list(flows = res$flows, base = base$flows, spec = spec, ctx = res$ctx)
}

#' Werte einer Zeile (Lauf i) nach lokalem Schlüssel
wsei_row <- function(flows, key, i = 1L) {
  for (r in flows$rows) if (identical(r$key, key)) return(r$values[i, ])
  stop("Zeile nicht gefunden: ", key)
}

#' Zeilensummen je Schlüssel (Lauf i)
wsei_sums <- function(flows, i = 1L) {
  stats::setNames(vapply(flows$rows, function(r) sum(r$values[i, ]), 0),
                  vapply(flows$rows, function(r) r$key, ""))
}

#' Befunde der validate()-Funktion eines Typs für eine Rohkomponente
wsei_findings <- function(type, ..., id = "x", scenario = NULL) {
  comp <- make_component(type, ..., id = id)
  def <- reg_get("flow", type)
  sc <- scenario %||% make_spec(make_grid())
  sc <- path_set(sc, path_join(helper_collection(comp), id), comp)
  out <- def$validate(comp, sc)
  codes <- vapply(out, function(f) sub("^types\\.flow\\.[a-z_]+\\.errors\\.", "", f$code), "")
  for (f in out) testthat::expect_true(lbl_has(f$code), info = f$code)
  for (f in out) {
    testthat::expect_type(do.call(msg, c(list(f$code), f$args)), "character")
  }
  stats::setNames(vapply(out, function(f) f$severity, ""), codes)
}

#' Rechtsstand mit Grunderwerbsteuer (Nutzlast wie legal/grunderwerbsteuer_2026)
wsei_grest_payload <- function() {
  list(rates = list(BW = 0.050, BY = 0.035, BE = 0.060, BB = 0.065, HB = 0.055, HH = 0.055,
                    HE = 0.060, MV = 0.060, NI = 0.050, NW = 0.065, RP = 0.050, SL = 0.065,
                    SN = 0.055, ST = 0.050, SH = 0.065, TH = 0.050),
       exemption_threshold_eur = 2500, uniform_contract_includes_construction = FALSE)
}

#' Spezifikation mit aktivem Thema grunderwerbsteuer
wsei_with_grest <- function(spec) {
  spec$legal <- list(grunderwerbsteuer = list(entry = "legal/grunderwerbsteuer_2026",
                                              values = wsei_grest_payload()))
  spec
}

#' Ausdruck auswerten und die Label-Schlüssel aller Meldungen (vofi_inform) sammeln
wsei_capture <- function(expr) {
  keys <- character(0)
  value <- withCallingHandlers(expr, message = function(m) {
    keys <<- c(keys, if (is.null(m$key)) NA_character_ else m$key)
    invokeRestart("muffleMessage")
  })
  list(value = value, keys = keys)
}
