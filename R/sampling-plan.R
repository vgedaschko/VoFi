# Sampler-Plan (WS-C; Spec 00 Abschnitte 11.2, 11.4, 11.6, 11.7, 11.10; Spec 01 Teil C 1.1-1.10).
# smp_plan(spec) liest das Stochastik-Overlay einer aufgelösten Variante (Einstellungen mit Preset,
# statische Schlüssel, Prozesse, unsichere Prozessparameter, automatische Förderzusagen,
# Korrelationen) und erzeugt den Plan, aus dem smp_sample()/smp_materialize() die Ziehungen je
# Block bilden. smp_plan_union() vereinigt die Pläne mehrerer Varianten (CRN).
# Zusätzlich gemeinsame Hilfen der Verteilungs- (dist_*) und Prozesstypen (proc_*).

# ---------------------------------------------------------------------------------------------
# Gemeinsame Hilfen der Verteilungstypen (R/dist-*.R)
# ---------------------------------------------------------------------------------------------

#' Metafelder eines Overlay-Eintrags, die keine Verteilungsparameter sind
#' @noRd
dist_meta_fields <- function() {
  c("dist", "target", "label", "description", "base", "apply", "from", "use", "source", "role")
}

#' Verteilungsparameter eines Overlay-Eintrags (ohne Metafelder)
#' @param entry Liste (Overlay-Eintrag oder Verteilungsangabe).
#' @return Liste der Parameter.
#' @noRd
dist_par <- function(entry) {
  if (!is.list(entry)) return(list())
  entry[setdiff(names(entry), dist_meta_fields())]
}

#' Numerischer Parameter einer Verteilung (Skalar oder Vektor, `double`)
#' @param par Verteilungsparameter.
#' @param name Parametername (exakter Name, kein Partial Matching).
#' @param default Rückfallwert, wenn der Parameter fehlt.
#' @return double (Tokens und Text ergeben `NA`) bzw. `default`.
#' @noRd
dist_num <- function(par, name, default = NULL) {
  v <- if (is.list(par) || !is.null(names(par))) par[[name]] else NULL
  if (is.null(v)) return(default)
  if (is.list(v)) v <- unlist(v, use.names = FALSE)
  if (is.logical(v)) v <- as.double(v)
  suppressWarnings(as.double(v))
}

#' Ist der Parameter eine endliche Zahl?
#' @noRd
dist_is_finite <- function(par, name) {
  v <- dist_num(par, name)
  length(v) == 1L && is.finite(v)
}

#' Argument `which` von `point()` prüfen
#' @noRd
dist_which <- function(which) utl_match_arg(which, c("mode", "median", "mean"), "which")

#' Validierungsmeldung eines Verteilungstyps (`types.distribution.<name>.validate.<code>`)
#' @noRd
dist_msg <- function(.type, .code, ...) {
  msg(paste0("types.distribution.", .type, ".validate.", .code), ...)
}

#' Meldungen zusammenfassen (`NULL` ergibt `character(0)`)
#' @noRd
dist_out <- function(...) {
  x <- c(...)
  if (is.null(x)) character(0) else as.character(x)
}

#' Wert für Meldungen formatieren
#' @noRd
dist_fmt <- function(x) {
  if (is.null(x)) return("NULL")
  utl_collapse(format(unlist(x, use.names = FALSE)))
}

#' Prüfung min ≤ mode ≤ max (Dreieck, PERT)
#' @noRd
dist_validate_three <- function(name, par) {
  bad <- c("min", "mode", "max")[!vapply(c("min", "mode", "max"), function(f) {
    dist_is_finite(par, f)
  }, logical(1))]
  if (length(bad) > 0L) return(dist_msg(name, "param_invalid", param = utl_collapse(bad)))
  a <- dist_num(par, "min")
  c0 <- dist_num(par, "mode")
  b <- dist_num(par, "max")
  if (!(a <= c0 && c0 <= b)) return(dist_msg(name, "order", min = a, mode = c0, max = b))
  character(0)
}

#' Kanonische Verteilungsparameter für den Plan (Spec 01 Teil C 1.4)
#'
#' `lognormal` → `meanlog`, `sdlog`, `shift`; `beta` → `shape1`, `shape2`, `min`, `max`;
#' `truncnorm` mit Aliasen `min`/`max` → `lower`/`upper` (Hinweis `vofi_warning_input`); alle
#' numerischen Parameter als `double`.
#' @param dist Verteilungstyp.
#' @param par Verteilungsparameter.
#' @param key Overlay-Schlüssel (für Meldungen).
#' @return Liste der Parameter.
#' @noRd
dist_canonical <- function(dist, par, key) {
  num <- function(v) {
    if (is.list(v)) v <- unlist(v, use.names = FALSE)
    if (is.numeric(v) || is.logical(v)) as.double(v) else v
  }
  par <- lapply(par, num)
  switch(dist,
    lognormal = {
      p <- dist_lognormal_canon(par)
      if (is.na(p$error)) list(meanlog = p$meanlog, sdlog = p$sdlog, shift = p$shift) else par
    },
    beta = {
      p <- dist_beta_canon(par)
      if (is.na(p$error)) list(shape1 = p$shape1, shape2 = p$shape2, min = p$min, max = p$max)
      else par
    },
    truncnorm = {
      for (al in list(c("min", "lower"), c("max", "upper"))) {
        if (!is.null(par[[al[1L]]]) && is.null(par[[al[2L]]])) {
          vofi_warn("sampling.alias", entry = key, alias = al[1L], canonical = al[2L],
                    .class = "vofi_warning_input")
          par[[al[2L]]] <- par[[al[1L]]]
        }
        par[[al[1L]]] <- NULL
      }
      par
    },
    par
  )
}

# ---------------------------------------------------------------------------------------------
# Gemeinsame Hilfen der Prozesstypen (R/process-*.R)
# ---------------------------------------------------------------------------------------------

#' Ist `x` eine Verteilungsangabe (`{dist: …}`)?
#' @noRd
proc_is_dist <- function(x) is.list(x) && utl_is_string(x[["dist"]])

#' Ist `x` das Token `base` (R-95)?
#' @noRd
proc_is_token <- function(x) identical(x, "base")

#' Startparameter, die das Token `base` tragen dürfen (Spec 00 11.7, R-95)
#' @noRd
proc_start_params <- function(type) {
  switch(type, ar1 = "x0", linked_ar1 = "u0", vasicek = "r0", mr_trend = c("p0", "p_norm"),
         gbm = "p0", character(0))
}

#' Laufzahl eines simulate()-Aufrufs
#'
#' Aus `z`, `u`, `attr(linked, "n")`, den Pfaden in `linked` bzw. der Länge der Parameter.
#' @noRd
proc_n <- function(par, z, u, linked) {
  if (!is.null(z) && is.matrix(z)) return(nrow(z))
  if (!is.null(u)) return(nrow(as.matrix(u)))
  n <- attr(linked, "n")
  if (!is.null(n)) return(as.integer(n))
  if (length(linked) > 0L && is.matrix(linked[[1L]])) return(nrow(linked[[1L]]))
  lens <- vapply(par, function(v) if (is.numeric(v)) length(v) else 1L, integer(1))
  max(c(1L, lens))
}

#' Parameterwert als n-Vektor (simulate)
#'
#' Zahl oder n-Vektor; eine Verteilungsangabe wird durch ihren Mittelwert ersetzt (nur bei
#' direktem Aufruf, der Sampler setzt Ziehungen ein); ein nicht aufgelöstes Token `base` ist ein
#' Vertragsfehler.
#' @noRd
proc_vec <- function(par, name, n, default = NULL) {
  v <- par[[name]]
  if (is.null(v)) v <- default
  if (proc_is_token(v)) {
    vofi_abort("sampling.process.token_unresolved", param = name,
               .class = "vofi_error_contract")
  }
  if (proc_is_dist(v)) v <- proc_dist_mean(v)
  v <- as.double(unlist(v, use.names = FALSE))
  if (length(v) == n) return(v)
  if (length(v) == 1L) return(rep(v, n))
  vofi_abort("sampling.process.param_length", param = name, n = n, length = length(v),
             .class = "vofi_error_contract")
}

#' Punktwert eines Parameters (expected, quantile_path)
#'
#' Verteilungsangabe → `point(…, "mean")`; Token `base` → `NA`; Vektor → Mittelwert.
#' @noRd
proc_point <- function(par, name, default = NULL) {
  v <- par[[name]]
  if (is.null(v)) v <- default
  if (is.null(v) || proc_is_token(v)) return(NA_real_)
  if (proc_is_dist(v)) return(proc_dist_mean(v))
  v <- suppressWarnings(as.double(unlist(v, use.names = FALSE)))
  if (length(v) == 0L) return(NA_real_)
  if (length(v) == 1L) v else mean(v)
}

#' Mittelwert einer Verteilungsangabe
#' @noRd
proc_dist_mean <- function(x) {
  reg_get("distribution", x[["dist"]])$point(dist_par(x), "mean")
}

#' Schockmatrix prüfen bzw. Nullschocks
#' @noRd
proc_z <- function(z, n, y) {
  if (is.null(z)) return(matrix(0, n, max(y - 1L, 0L)))
  if (!is.matrix(z) || nrow(z) != n || ncol(z) < y - 1L) {
    vofi_abort("sampling.process.shock_dims", n = n, y = y, .class = "vofi_error_contract")
  }
  z
}

#' Geometrische Summe Σ_{i=0}^{k−1} x^i = (1 − x^k)/(1 − x)
#' @noRd
proc_geo <- function(x, k) if (abs(1 - x) < 1e-15) as.double(k) else (1 - x^k) / (1 - x)

#' (1 − φ^{2k})/(1 − φ²): Varianzfaktor eines AR(1) nach k Schritten
#' @noRd
proc_geo2 <- function(phi, k) proc_geo(phi^2, k)

#' Lineare Interpolation von Stützstellen über Kalenderjahre (außerhalb konstant)
#' @noRd
proc_interp <- function(x_years, values, years) {
  x <- as.double(unlist(x_years, use.names = FALSE))
  v <- as.double(unlist(values, use.names = FALSE))
  if (length(v) == 1L) return(rep(v, length(years)))
  stats::approx(x, v, xout = as.double(years), rule = 2, ties = "ordered")$y
}

#' Momente eines Gaußprozesses (für Quantilpfade verknüpfter Prozesse, R-114)
#'
#' `ar1`, `vasicek` ohne Untergrenze und `linked_ar1` mit Gaußbasis; sonst `NULL`.
#' @param type Prozesstyp.
#' @param par Punktparameter (mit `.base` bei `linked_ar1`).
#' @param years Kalenderjahre.
#' @return Liste `mean`, `sd`, `phi`, `sigma` (AR-Parameter der eigenen Schocks) oder `NULL`.
#' @noRd
proc_gauss <- function(type, par, years) {
  switch(type,
    ar1 = proc_ar1_moments(par, years),
    vasicek = {
      fl <- proc_point(par, "floor", default = -Inf)
      if (!isTRUE(fl == -Inf)) return(NULL)
      proc_vasicek_moments(par, years)
    },
    linked_ar1 = {
      m <- proc_linked_ar1_moments(par, years)
      if (anyNA(m$sd)) NULL else m
    },
    NULL
  )
}

#' Prüfung eines Prozessparameters (validate der Prozesstypen)
#'
#' Regeln: `finite`, `not_nan` (auch ±Inf), `abs_lt1` (|x| < 1), `nonneg` (≥ 0), `positive`
#' (> 0), `gt_minus1` (> −1). Verteilungsangaben werden mit ihrem Typ geprüft; ihr Träger muss im
#' zulässigen Bereich liegen (Spec 01 Teil C 1.5.2).
#' @param par Parameter.
#' @param name Parametername.
#' @param rule Regel.
#' @param required Pflichtparameter.
#' @param allow_dist Verteilungsangabe zulässig.
#' @param allow_token Token `base` zulässig.
#' @param label Name in der Meldung.
#' @return Zeichenvektor der Meldungen.
#' @noRd
proc_check <- function(par, name, rule, required = FALSE, allow_dist = TRUE,
                       allow_token = FALSE, label = name) {
  v <- par[[name]]
  if (is.null(v)) {
    return(if (required) msg("sampling.process.param_missing", param = label) else character(0))
  }
  if (proc_is_token(v)) {
    if (allow_token) return(character(0))
    return(msg("sampling.process.token_not_allowed", param = label))
  }
  if (is.list(v) && !is.null(v[["dist"]])) {
    if (!allow_dist) return(msg("sampling.process.dist_not_allowed", param = label))
    if (!proc_is_dist(v) || !reg_has("distribution", v[["dist"]])) {
      return(msg("sampling.process.dist_invalid", param = label,
                 details = dist_fmt(v[["dist"]])))
    }
    def <- reg_get("distribution", v[["dist"]])
    dp <- dist_par(v)
    errs <- def$validate(dp)
    if (length(errs) > 0L) {
      return(msg("sampling.process.dist_invalid", param = label,
                 details = utl_collapse(errs, "; ")))
    }
    q <- def$quantile(c(0, 1e-12, 1), dp)
    ok <- switch(rule,
      abs_lt1 = q[1L] > -1 && q[3L] < 1,
      nonneg = q[1L] >= 0,
      positive = q[1L] >= 0 && q[2L] > 0,
      gt_minus1 = q[2L] > -1,
      TRUE
    )
    if (!isTRUE(ok)) {
      return(msg("sampling.process.dist_support", param = label, lower = q[1L], upper = q[3L]))
    }
    return(character(0))
  }
  x <- suppressWarnings(as.double(unlist(v, use.names = FALSE)))
  if (length(x) != 1L || is.na(x) || (rule != "not_nan" && !is.finite(x))) {
    return(msg("sampling.process.param_finite", param = label, value = dist_fmt(v)))
  }
  ok <- switch(rule, abs_lt1 = abs(x) < 1, nonneg = x >= 0, positive = x > 0,
               gt_minus1 = x > -1, TRUE)
  if (!ok) {
    return(msg(paste0("sampling.process.param_", rule), param = label, value = x))
  }
  character(0)
}

#' Stützstellen prüfen: Jahre streng steigend (≥ 1), Werte gleich lang und endlich
#' @noRd
proc_check_points <- function(years, values, label) {
  y <- suppressWarnings(as.double(unlist(years, use.names = FALSE)))
  v <- suppressWarnings(as.double(unlist(values, use.names = FALSE)))
  pre <- if (nzchar(label)) paste0(label, ".") else ""
  if (length(y) == 0L || anyNA(y) || !all(is.finite(y)) || any(diff(y) <= 0)) {
    return(msg("sampling.process.years_invalid", param = paste0(pre, "years")))
  }
  if (length(v) != length(y) || anyNA(v) || !all(is.finite(v))) {
    return(msg("sampling.process.values_invalid", param = paste0(pre, "values")))
  }
  character(0)
}

# ---------------------------------------------------------------------------------------------
# Einstellungen (Spec 00 4.3.15, 11.4; Spec 01 Teil C 1.2, 6.1)
# ---------------------------------------------------------------------------------------------

#' Defaults der Einstellungen (Spec 01 Teil C 1.2)
#' @noRd
smp_settings_defaults <- function() {
  list(preset = "standard", n_sim = NULL, seed = NULL, sampling = "lhs", block_size = 200L,
       replicates = NULL, antithetic = FALSE, copula = "iman_conover", start_year = NULL,
       store = "bands", keep_runs = c("p05", "p50", "p95"),
       keep_runs_kpi = "delta_terminal_value",
       bands = c("net_position", "dep_balance", "od_balance"),
       band_probs = c(0.05, 0.25, 0.5, 0.75, 0.95), auto_funding_approval = TRUE,
       convergence = list(rel_halfwidth_mean = 0.005, abs_halfwidth_prob = 0.01))
}

#' Presets (R-97, Spec 01 Teil C 6.1)
#' @noRd
smp_presets <- function() {
  list(preview = list(n_sim = 1000L, store = "kpi", keep_runs = character(0)),
       standard = list(n_sim = 10000L, store = "bands", keep_runs = c("p05", "p50", "p95")),
       report = list(n_sim = 50000L, store = "bands", keep_runs = c("p05", "p50", "p95")),
       custom = list())
}

#' Wert einer Einstellung in kanonischer Form
#' @noRd
smp_setting_value <- function(name, v) {
  if (is.list(v) && !(name %in% c("convergence"))) v <- unlist(v, use.names = FALSE)
  switch(name,
    n_sim = , block_size = , replicates = , start_year = {
      x <- suppressWarnings(as.double(v))
      if (length(x) != 1L || is.na(x)) return(v)
      if (utl_is_whole(x) && abs(x) <= .Machine$integer.max) as.integer(round(x)) else x
    },
    seed = suppressWarnings(as.double(v)),
    antithetic = , auto_funding_approval = as.logical(v),
    band_probs = as.double(v),
    preset = , sampling = , copula = , store = , keep_runs_kpi = as.character(v),
    keep_runs = , bands = as.character(v),
    v
  )
}

#' Einstellungen auflösen (Vorrang R-97)
#'
#' Funktionsargumente (später in `smp_configure()`) > ausdrücklich gesetzte Felder der Schichten
#' ≥ 3 > Werte des Presets > Felder der Schichten 0–2. Ein Feld gilt als ausdrücklich, wenn die
#' Herkunft der Spezifikation es einer Schicht ≥ 3 zuordnet bzw. (ohne Herkunftszeile) wenn es
#' gesetzt ist. `replicates` ohne ausdrückliche `block_size` schaltet den F21-Modus ein.
#' @param raw `spec$stochastic$settings`.
#' @param prov Herkunft (`attr(spec, "provenance")`) oder `NULL`.
#' @return Liste der Einstellungen (11.2) mit `preset` und `convergence`.
#' @noRd
smp_resolve_settings <- function(raw, prov = NULL) {
  raw <- raw %||% list()
  s <- smp_settings_defaults()
  for (f in names(raw)) {
    if (!is.null(raw[[f]])) s[[f]] <- smp_setting_value(f, raw[[f]])
  }
  explicit <- function(f) {
    if (is.null(raw[[f]])) return(FALSE)
    if (is.data.frame(prov) && all(c("path", "layer") %in% names(prov))) {
      hit <- prov$layer[prov$path == paste0("stochastic.settings.", f)]
      if (length(hit) > 0L && !is.na(hit[1L])) return(hit[1L] >= 3)
    }
    TRUE
  }
  preset <- s$preset %||% "standard"
  if (!utl_is_string(preset) || !(preset %in% names(smp_presets()))) {
    vofi_abort("sampling.preset_unknown", preset = dist_fmt(preset),
               suggestion = utl_suggest_text(as.character(preset)[1L], names(smp_presets())),
               .class = "vofi_error_validation")
  }
  pv <- smp_presets()[[preset]]
  for (f in names(pv)) if (!explicit(f)) s[f] <- list(pv[[f]])
  if (is.null(s$n_sim)) s$n_sim <- smp_presets()$standard$n_sim
  if (!is.null(s$replicates)) {
    if (explicit("block_size") && explicit("replicates")) {
      vofi_abort("sampling.block_and_replicates", .class = "vofi_error_validation")
    }
    s$block_size <- NULL
  }
  s <- utl_fill_defaults(s, list(block_size = NULL, replicates = NULL))
  smp_check_settings(s)
  s
}

#' Statische Prüfung der Einstellungen (Spec 01 Teil C 1.2)
#' @noRd
smp_check_settings <- function(s) {
  bad <- function(field, value, choices) {
    vofi_abort("sampling.setting_invalid", field = field, value = dist_fmt(value),
               choices = choices, .class = "vofi_error_validation")
  }
  if (!utl_is_string(s$sampling) || !(s$sampling %in% c("lhs", "pseudo"))) {
    bad("sampling", s$sampling, "lhs, pseudo")
  }
  if (!utl_is_string(s$copula) || !(s$copula %in% c("iman_conover", "gaussian"))) {
    bad("copula", s$copula, "iman_conover, gaussian")
  }
  if (!utl_is_flag(s$antithetic)) bad("antithetic", s$antithetic, "true, false")
  if (isTRUE(s$antithetic) && identical(s$sampling, "lhs")) {
    vofi_abort("sampling.antithetic_lhs", .class = "vofi_error_validation")
  }
  if (!is.null(s$block_size) && (!utl_is_whole(s$block_size) || s$block_size < 2)) {
    bad("block_size", s$block_size, ">= 2")
  }
  if (!is.null(s$replicates) && (!utl_is_whole(s$replicates) || s$replicates < 1)) {
    bad("replicates", s$replicates, ">= 1")
  }
  if (!utl_is_whole(s$n_sim) || s$n_sim < 1) bad("n_sim", s$n_sim, ">= 1")
  if (!is.null(s$seed)) utl_check_seed(s$seed)
  invisible(s)
}

# ---------------------------------------------------------------------------------------------
# Plan
# ---------------------------------------------------------------------------------------------

#' Raster einer Spezifikation (wie vofi_build() Stufe 3, mit start_year des Overlays)
#' @noRd
smp_grid_of <- function(spec) {
  p <- spec$project
  g <- spec$grid %||% list()
  vofi_time_grid(p$valuation_date, p$horizon_years,
                 construction_months = g$construction_months %||% 0L,
                 construction_step_months = g$construction_step_months %||% 12L,
                 operation_step_months = g$operation_step_months %||% 12L,
                 operation_alignment = g$operation_alignment %||% "calendar",
                 periods_months = g$periods_months,
                 start_year = smp_setting_value("start_year",
                                                spec$stochastic$settings$start_year))
}

#' Basisfall-Kontext (deterministisch, n = 1) für Basisfallwerte im Plan
#' @noRd
smp_base_ctx <- function(spec, grid) {
  eng_context_from_parts(grid, spec, draws = NULL, mode = "deterministic")
}

#' Basisfallwert eines Pfads als 1 × (T+1)-Pfad bzw. `NULL`
#' @noRd
smp_value_base <- function(ctx, path) {
  tryCatch(ctx$value_base(path, "path"), error = function(e) NULL)
}

#' Sampler-Plan einer Variante
#'
#' Liest `spec$stochastic` (Schicht 6) und erzeugt den Plan nach Spec 00 Abschnitt 11.2:
#' Einstellungen (Preset, F21-Modus), statische Schlüssel (`overlay`, `inline`, `funding_auto`,
#' `process_param`) mit Rolle (`value` bzw. `decision`, 9.11) und Verknüpfung `apply`, Prozesse in
#' topologischer Reihenfolge (Token `base` mit dem Basisfallwert des Ziels aufgelöst, R-95),
#' Korrelationen (Spearman bzw. Schockkorrelation; Reparatur mit Warnung) und Plan-Hash.
#' @param spec `vofi_spec`.
#' @param grid optional: `vofi_grid` (Default: aus `spec` wie in `vofi_build()`).
#' @return Objekt der Klasse `smp_plan`.
#' @noRd
smp_plan <- function(spec, grid = NULL) {
  stoch <- spec$stochastic %||% list()
  prov <- attr(spec, "provenance")
  settings <- smp_resolve_settings(stoch$settings, prov)
  grid <- grid %||% smp_grid_of(spec)
  cache <- new.env(parent = emptyenv())
  base_ctx <- function() {
    if (is.null(cache$ctx)) cache$ctx <- smp_base_ctx(spec, grid)
    cache$ctx
  }
  nodes <- smp_decision_nodes(spec)
  st <- smp_static_overlay(stoch$parameters %||% list(), nodes)
  pr <- smp_process_entries(stoch$processes %||% list(), grid, base_ctx)
  st <- smp_bind_static(st, pr$static)
  if (isTRUE(settings$auto_funding_approval)) {
    st <- smp_bind_static(st, smp_funding_auto(spec, st, nodes, base_ctx, prov))
  }
  if (length(st) > 0L) st <- st[order(names(st), method = "radix")]
  static <- smp_static_table(st)
  smp_check_targets(static, pr$processes)
  corr <- smp_plan_correlations(stoch$correlations %||% list(), static, pr$processes, prov)
  plan <- structure(list(
    settings = settings,
    static = static,
    static_par = lapply(st, function(e) e$par),
    processes = pr$processes,
    proc_order = pr$order,
    correlations = list(parameters = corr$parameters, shocks = corr$shocks),
    hash = NA_character_,
    corr_pearson = list(parameters = corr$pearson_parameters, shocks = corr$pearson_shocks),
    repaired = list(parameters = corr$repaired_parameters, shocks = corr$repaired_shocks),
    years = as.integer(grid$years),
    spec = spec,
    grid = grid
  ), class = "smp_plan")
  plan$hash <- smp_plan_hash(plan)
  plan
}

#' Entscheidungsknoten der Förderung (9.11 Nr. 1): `approval_timing` = `before_start` und
#' `fallback_variant` gesetzt
#' @return Zeichenvektor der Förder-ids mit Knoten.
#' @noRd
smp_decision_nodes <- function(spec) {
  fund <- spec$funding %||% list()
  code <- function(x) {
    if (is.list(x) && !is.null(x[["value"]])) x <- x[["value"]]
    if (is.character(x) && length(x) >= 1L) x[1L] else NA_character_
  }
  ids <- names(fund)
  ids[vapply(ids, function(f) {
    identical(code(fund[[f]][["approval_timing"]]), "before_start") &&
      !is.na(code(fund[[f]][["fallback_variant"]])) &&
      nzchar(code(fund[[f]][["fallback_variant"]]))
  }, logical(1))]
}

#' Statischer Eintrag (interne Darstellung)
#' @noRd
smp_static_entry <- function(key, target, dist, par, label, source, role, apply) {
  list(key = key, target = target, dist = dist, par = par,
       label = if (utl_is_string(label)) label else NA_character_, source = source,
       role = role, apply = apply)
}

#' Statische Overlay-Einträge (`stochastic.parameters`)
#' @param params Liste Schlüssel → Eintrag.
#' @param nodes Förder-ids mit Entscheidungsknoten.
#' @return benannte Liste interner Einträge.
#' @noRd
smp_static_overlay <- function(params, nodes) {
  out <- list()
  node_targets <- paste0("funding.", nodes, ".approved")
  for (key in names(params)) {
    e <- params[[key]]
    target <- e[["target"]]
    if (!utl_is_string(target) || !nzchar(target)) {
      vofi_abort("sampling.target_missing", entry = key, .class = "vofi_error_validation")
    }
    dist <- smp_check_dist(key, e[["dist"]])
    par <- dist_canonical(dist, dist_par(e), key)
    smp_check_dist_par(key, dist, par)
    ap <- e[["apply"]] %||% "replace"
    if (!utl_is_string(ap) || !(ap %in% c("replace", "multiply", "add"))) {
      vofi_abort("sampling.apply_invalid", entry = key, apply = dist_fmt(ap),
                 .class = "vofi_error_validation")
    }
    inline <- identical(key, target) && grepl(".", key, fixed = TRUE)
    role <- if (target %in% node_targets) "decision" else "value"
    if (role == "decision") {
      smp_check_binary(key, dist, par)
      ap <- "replace"
    }
    out[[key]] <- smp_static_entry(key, target, dist, par, e[["label"]],
                                   if (inline) "inline" else "overlay", role,
                                   if (inline) "replace" else ap)
  }
  out
}

#' Verteilungstyp prüfen
#' @noRd
smp_check_dist <- function(key, dist) {
  known <- reg_list("distribution")$name
  if (!utl_is_string(dist) || !reg_has("distribution", dist)) {
    vofi_abort("sampling.dist_unknown", entry = key, dist = dist_fmt(dist),
               suggestion = utl_suggest_text(as.character(dist)[1L], known),
               .class = "vofi_error_validation")
  }
  dist
}

#' Verteilungsparameter prüfen (validate() des Typs)
#' @noRd
smp_check_dist_par <- function(key, dist, par) {
  errs <- reg_get("distribution", dist)$validate(par)
  if (length(errs) > 0L) {
    vofi_abort("sampling.dist_invalid", entry = key, details = utl_collapse(errs, "; "),
               .class = "vofi_error_validation")
  }
  invisible(TRUE)
}

#' Entscheidungsschlüssel müssen 0/1-wertig sein (R-71)
#' @noRd
smp_check_binary <- function(key, dist, par) {
  vals <- switch(dist,
    bernoulli = c(0, 1),
    fixed = dist_num(par, "value"),
    discrete = dist_num(par, "values"),
    NA_real_
  )
  if (anyNA(vals) || !all(vals %in% c(0, 1))) {
    vofi_abort("sampling.decision_not_binary", entry = key, dist = dist,
               .class = "vofi_error_validation")
  }
  invisible(TRUE)
}

#' Prozesse (`stochastic.processes`): Parameter, Kopplungen, Tokens, unsichere Parameter
#' @param procs Liste Schlüssel → Eintrag.
#' @param grid Raster (Startjahr, Kalenderjahre).
#' @param base_ctx Funktion, die den Basisfall-Kontext liefert.
#' @return Liste `processes` (Spec 00 11.2), `order` (Topo-Reihenfolge), `static` (statische
#'   Einträge der unsicheren Prozessparameter `<proc>.<param>`).
#' @noRd
smp_process_entries <- function(procs, grid, base_ctx) {
  meta <- c("target", "type", "label", "description", "from", "use")
  out <- list()
  static <- list()
  keys <- utl_sort(names(procs))
  for (key in keys) {
    e <- procs[[key]]
    target <- e[["target"]]
    if (!utl_is_string(target) || !nzchar(target)) {
      vofi_abort("sampling.target_missing", entry = key, .class = "vofi_error_validation")
    }
    type <- e[["type"]]
    if (!utl_is_string(type) || !reg_has("process", type)) {
      vofi_abort("sampling.process_unknown", entry = key, type = dist_fmt(type),
                 suggestion = utl_suggest_text(as.character(type)[1L],
                                               reg_list("process")$name),
                 .class = "vofi_error_validation")
    }
    def <- reg_get("process", type)
    pn <- setdiff(names(e), meta)
    par <- lapply(stats::setNames(pn, pn), function(nm) {
      smp_proc_param_value(e[[nm]], paste0(key, ".", nm))
    })
    errs <- def$validate(par)
    if (length(errs) > 0L) {
      vofi_abort("sampling.process_invalid", entry = key, details = utl_collapse(errs, "; "),
                 .class = "vofi_error_validation")
    }
    linked <- list()
    for (l in def$linked) {
      lk <- par[[l]]
      if (!utl_is_string(lk) || !(lk %in% names(procs)) || identical(lk, key)) {
        vofi_abort("sampling.linked_missing", entry = key, base = dist_fmt(lk),
                   .class = "vofi_error_validation")
      }
      linked[[l]] <- lk
    }
    # unsichere Prozessparameter (S->P, Spec 01 Teil C 1.5.2): Parameter der Art number bzw.
    # number-Felder von map-Parametern (noise.phi, noise.sigma)
    for (p in names(def$params)) {
      pp <- def$params[[p]]
      if (identical(pp$kind, "number") && proc_is_dist(par[[p]])) {
        static[[paste0(key, ".", p)]] <- smp_proc_param_entry(key, p, par[[p]])
      } else if (identical(pp$kind, "map") && is.list(par[[p]])) {
        for (f in names(pp$fields)) {
          if (identical(pp$fields[[f]]$kind, "number") && proc_is_dist(par[[p]][[f]])) {
            static[[paste0(key, ".", p, ".", f)]] <-
              smp_proc_param_entry(key, paste0(p, ".", f), par[[p]][[f]])
          }
        }
      }
    }
    out[[key]] <- list(target = target, type = type, par = par, linked = linked,
                       label = if (utl_is_string(e[["label"]])) e[["label"]] else NA_character_,
                       source = "overlay", n_shocks = as.integer(def$n_shocks(par)),
                       n_uniforms = as.integer(def$n_uniforms(par)), output = def$output,
                       x_det = NULL)
  }
  order <- smp_proc_order(out)
  for (key in order) out[[key]] <- smp_resolve_tokens(key, out, grid, base_ctx)
  list(processes = out, order = order, static = static)
}

#' Prozessparameter in kanonische Form (Zahlen als double, Verteilungen kanonisch)
#' @param v Parameterwert.
#' @param label Schlüssel für Meldungen (`<proc>.<param>`, bei Map-Feldern
#'   `<proc>.<param>.<feld>`).
#' @noRd
smp_proc_param_value <- function(v, label) {
  if (proc_is_dist(v)) {
    return(c(list(dist = v[["dist"]]), dist_canonical(v[["dist"]], dist_par(v), label)))
  }
  if (is.list(v) && !is.null(names(v))) {
    out <- lapply(seq_along(v), function(i) {
      smp_proc_param_value(v[[i]], paste0(label, ".", names(v)[i]))
    })
    names(out) <- names(v)
    return(out)
  }
  if (is.list(v) && all(vapply(v, function(e) is.numeric(e) && length(e) == 1L, logical(1)))) {
    return(as.double(unlist(v)))
  }
  if (is.numeric(v)) return(as.double(v))
  v
}

#' Statischer Eintrag eines unsicheren Prozessparameters (Schlüssel `<proc>.<param>`)
#' @noRd
smp_proc_param_entry <- function(key, param, v) {
  k <- paste0(key, ".", param)
  dist <- smp_check_dist(k, v[["dist"]])
  par <- dist_par(v)
  smp_check_dist_par(k, dist, par)
  smp_static_entry(k, paste0("stochastic.processes.", k), dist, par, v[["label"]],
                   "process_param", "value", "replace")
}

#' Topologische Reihenfolge der Prozesse (Basisprozess vor dem gekoppelten; Kahn, Gleichstand
#' nach Schlüssel `method = "radix"`)
#' @noRd
smp_proc_order <- function(procs) {
  keys <- utl_sort(names(procs))
  deps <- lapply(procs, function(p) unique(unlist(p$linked, use.names = FALSE)))
  done <- character(0)
  rest <- keys
  while (length(rest) > 0L) {
    ready <- rest[vapply(rest, function(k) all(deps[[k]] %in% done), logical(1))]
    if (length(ready) == 0L) {
      vofi_abort("sampling.linked_cycle", path = utl_collapse(rest, " -> "),
                 .class = "vofi_error_validation")
    }
    done <- c(done, ready[1L])
    rest <- setdiff(rest, ready[1L])
  }
  done
}

#' Token `base` der Startparameter auflösen (Spec 00 11.7, R-95; Spec 01 Teil C 1.5.1)
#'
#' x_det = Basisfallwert des Ziels in der ersten Rasterspalte j ≥ 2 mit `year[j] == start_year`
#' (T = 0 bzw. ohne solche Spalte: Spalte 1). `x0`, `r0`, `p0`, `p_norm` erhalten x_det;
#' `u0 = base` wird zu x_det − a − b · base_1, wenn a, b und der Startwert des Basisprozesses
#' fest sind; sonst bleibt das Token und `smp_materialize()` löst es je Lauf auf (g_1 = x_det).
#' @noRd
smp_resolve_tokens <- function(key, procs, grid, base_ctx) {
  p <- procs[[key]]
  tok <- intersect(proc_start_params(p$type), names(p$par))
  tok <- tok[vapply(tok, function(t) proc_is_token(p$par[[t]]), logical(1))]
  if (length(tok) == 0L) return(p)
  path <- smp_value_base(base_ctx(), p$target)
  if (is.null(path) || !is.numeric(path)) {
    vofi_abort("sampling.base_token_missing", entry = key, param = tok[1L], target = p$target,
               .class = "vofi_error_validation")
  }
  path <- matrix(as.double(path), nrow = 1L)
  j <- which(seq_len(grid$T + 1L) >= 2L & grid$year == grid$years[1L])
  x_det <- if (length(j) > 0L) path[1L, j[1L]] else path[1L, 1L]
  p$x_det <- x_det
  p$start_base <- tok
  for (t in tok) {
    if (t != "u0") {
      p$par[[t]] <- x_det
      next
    }
    a <- p$par[["a"]] %||% 0
    b <- p$par[["b"]] %||% 1
    start <- smp_proc_start(p$linked[["base"]], procs, grid$years)
    if (is.numeric(a) && is.numeric(b) && !is.na(start)) {
      p$par$u0 <- x_det - a - b * start
    }
  }
  # erneut prüfen: Bedingungen, die validate() beim Token übersprungen hat (z. B. floor <= r0,
  # p0 > 0, p_norm > 0, endlich), gelten auch für den eingesetzten Basisfallwert
  errs <- reg_get("process", p$type)$validate(p$par)
  if (length(errs) > 0L) {
    vofi_abort("sampling.process_invalid_base", entry = key, target = p$target, value = x_det,
               details = utl_collapse(errs, "; "), .class = "vofi_error_validation")
  }
  p
}

#' Fester Startwert (Spalte 1) eines Prozesses oder `NA`, wenn er laufspezifisch ist
#' @param key Prozessschlüssel.
#' @param procs Prozesse des Plans.
#' @param years Kalenderjahre (Spalte 1 = Startjahr).
#' @noRd
smp_proc_start <- function(key, procs, years) {
  p <- procs[[key]]
  par <- p$par
  fixed <- function(v) is.numeric(v) && length(v) == 1L
  switch(p$type,
    ar1 = {
      v <- par[["x0"]] %||% par[["mu"]]
      if (fixed(v)) v else NA_real_
    },
    vasicek = if (fixed(par[["r0"]])) par[["r0"]] else NA_real_,
    mr_trend = , gbm = if (fixed(par[["p0"]])) par[["p0"]] else NA_real_,
    linked_ar1 = {
      a <- par[["a"]] %||% 0
      b <- par[["b"]] %||% 1
      u0 <- par[["u0"]] %||% 0
      s <- smp_proc_start(p$linked[["base"]], procs, years)
      if (fixed(a) && fixed(b) && fixed(u0) && !is.na(s)) a + b * s + u0 else NA_real_
    },
    scenario_mix = {
      # Spalte 1 ohne Rauschen (v_1 = 0): fest nur, wenn alle Szenarien dort übereinstimmen
      x1 <- proc_scenarios(par, years[1L])$paths[, 1L]
      if (length(unique(x1)) == 1L) x1[1L] else NA_real_
    },
    iid = reg_get("process", "iid")$expected(par, years[1L]),
    fixed_path = reg_get("process", "fixed_path")$expected(par, years[1L]),
    NA_real_
  )
}

#' Statische Einträge zusammenführen (Schlüssel eindeutig)
#' @noRd
smp_bind_static <- function(a, b) {
  dup <- intersect(names(a), names(b))
  if (length(dup) > 0L) {
    vofi_abort("sampling.key_duplicate", entry = dup[1L], .class = "vofi_error_validation")
  }
  c(a, b)
}

#' Automatische Förderzusage (Spec 00 11.6 Nr. 4, R-55, R-71)
#'
#' Für jedes Förderinstrument mit Basisfallwert `approval_probability` < 1 ohne Overlay-Eintrag
#' auf `funding.<id>.approved` entsteht der Schlüssel `funding.<id>.approved` (bernoulli,
#' p = approval_probability); bei einem Entscheidungsknoten mit Rolle `decision`. Setzt eine
#' Variante, ein Szenario-Set (Schicht 7, z. B. `foerderstopp`) oder ein Override (Schicht 8)
#' `funding.<id>.approved`, ist die Zusage für den Lauf deterministisch und es entsteht kein
#' Schlüssel (4.7 letzter Absatz: die Overlay-Bindung entfällt auch für den automatisch
#' erzeugten Eintrag).
#' @param prov Herkunft (`attr(spec, "provenance")`) oder `NULL`.
#' @noRd
smp_funding_auto <- function(spec, static, nodes, base_ctx, prov = NULL) {
  out <- list()
  targets <- vapply(static, function(e) e$target, "")
  for (f in names(spec$funding %||% list())) {
    key <- paste0("funding.", f, ".approved")
    if (key %in% targets || key %in% names(static)) next
    if (smp_fixed_by_layer(prov, key)) next
    pv <- smp_value_base(base_ctx(), paste0("funding.", f, ".approval_probability"))
    if (is.null(pv) || !is.numeric(pv)) next
    p <- as.double(pv)[1L]
    if (!is.finite(p) || p >= 1) next
    p <- min(max(p, 0), 1)
    out[[key]] <- smp_static_entry(key, key, "bernoulli", list(p = p), NA_character_,
                                   "funding_auto", if (f %in% nodes) "decision" else "value",
                                   "replace")
  }
  out
}

#' Ist ein Pfad durch eine Variante, ein Set (Schicht 7) oder Overrides (Schicht 8) gesetzt?
#' @param prov Herkunft (`attr(spec, "provenance")`, Spalten `path`, `layer`) oder `NULL`.
#' @param path Pfad.
#' @return logical(1).
#' @noRd
smp_fixed_by_layer <- function(prov, path) {
  if (!is.data.frame(prov) || !all(c("path", "layer") %in% names(prov))) return(FALSE)
  layer <- suppressWarnings(as.integer(prov$layer[prov$path == path]))
  any(!is.na(layer) & layer >= 7L)
}

#' Data Frame `static` des Plans (11.2), nach Schlüssel sortiert
#' @noRd
smp_static_table <- function(st) {
  col <- function(f) vapply(st, function(e) as.character(e[[f]]), "", USE.NAMES = FALSE)
  data.frame(key = col("key"), target = col("target"), dist = col("dist"),
             label = col("label"), source = col("source"), role = col("role"),
             apply = col("apply"), stringsAsFactors = FALSE)
}

#' Jedes Ziel höchstens einmal (statisch oder Prozess, Spec 00 11.8)
#' @noRd
smp_check_targets <- function(static, processes) {
  tg <- c(static$target, vapply(processes, function(p) p$target, "", USE.NAMES = FALSE))
  ky <- c(static$key, names(processes))
  dup <- unique(tg[duplicated(tg)])
  if (length(dup) > 0L) {
    vofi_abort("sampling.target_duplicate", target = dup[1L],
               keys = utl_collapse(ky[tg == dup[1L]]), .class = "vofi_error_validation")
  }
  both <- intersect(static$key, names(processes))
  if (length(both) > 0L) {
    vofi_abort("sampling.key_duplicate", entry = both[1L], .class = "vofi_error_validation")
  }
  invisible(TRUE)
}

#' Hash des Plans (strukturabhängig; unabhängig von Verteilungs- und Prozessparametern, R-93)
#' @noRd
smp_plan_hash <- function(plan) {
  procs <- lapply(plan$processes[utl_sort(names(plan$processes))], function(p) {
    list(target = p$target, type = p$type, linked = p$linked, n_shocks = p$n_shocks,
         n_uniforms = p$n_uniforms)
  })
  s <- plan$settings
  stable_hash(list(
    static = plan$static[, c("key", "target", "role", "apply", "source"), drop = FALSE],
    processes = procs, proc_order = plan$proc_order, correlations = plan$correlations,
    settings = list(sampling = s$sampling, block_size = s$block_size, replicates = s$replicates,
                    antithetic = s$antithetic, copula = s$copula, years = plan$years)
  ))
}

# ---------------------------------------------------------------------------------------------
# Korrelationen im Plan (Spec 00 11.6, Spec 01 Teil C 1.7)
# ---------------------------------------------------------------------------------------------

#' Korrelationspaare lesen (`[a, b, rho]` bzw. `{a, b, rho}`)
#' @return Data Frame `a`, `b`, `rho`.
#' @noRd
smp_parse_pairs <- function(x, what) {
  if (is.null(x) || length(x) == 0L) {
    return(data.frame(a = character(0), b = character(0), rho = numeric(0),
                      stringsAsFactors = FALSE))
  }
  if (!is.list(x)) x <- list(x)
  rows <- lapply(x, function(p) {
    if (is.list(p) && all(c("a", "b") %in% names(p))) {
      a <- p[["a"]]
      b <- p[["b"]]
      r <- p[["rho"]]
    } else {
      p <- unlist(p, use.names = FALSE)
      if (length(p) != 3L) {
        vofi_abort("sampling.corr_invalid", what = what, pair = dist_fmt(p),
                   .class = "vofi_error_validation")
      }
      a <- p[1L]
      b <- p[2L]
      r <- p[3L]
    }
    r <- suppressWarnings(as.double(unlist(r)))
    if (!utl_is_string(as.character(a)) || !utl_is_string(as.character(b)) ||
          length(r) != 1L || is.na(r)) {
      vofi_abort("sampling.corr_invalid", what = what, pair = dist_fmt(list(a, b, r)),
                 .class = "vofi_error_validation")
    }
    data.frame(a = as.character(a), b = as.character(b), rho = r, stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

#' Stammt die Paarliste aus einem Bibliotheksverweis (Herkunft `library`/`user_library`)?
#' @noRd
smp_pairs_from_library <- function(prov, what) {
  if (!is.data.frame(prov) || !all(c("path", "source_type") %in% names(prov))) return(FALSE)
  st <- prov$source_type[prov$path == paste0("stochastic.correlations.", what) |
                           startsWith(prov$path, paste0("stochastic.correlations.", what, "."))]
  length(st) > 0L && all(st %in% c("library", "user_library"))
}

#' Paare prüfen und bereinigen (Spec 01 Teil C 1.7.1, R-96)
#' @param pairs Data Frame aus `smp_parse_pairs()`.
#' @param allowed zulässige Schlüssel.
#' @param library Paare aus einem Bibliotheksverweis (fehlende Schlüssel werden verworfen).
#' @param decision Schlüssel der Rolle `decision` (nicht korrelierbar).
#' @return bereinigtes Data Frame (Paare mit a < b in C-Ordnung, ohne Duplikate).
#' @noRd
smp_clean_pairs <- function(pairs, allowed, library, decision, what) {
  keep <- rep(TRUE, nrow(pairs))
  for (i in seq_len(nrow(pairs))) {
    a <- pairs$a[i]
    b <- pairs$b[i]
    r <- pairs$rho[i]
    for (k in c(a, b)) {
      if (k %in% decision) {
        vofi_abort("sampling.decision_correlated", entry = k, .class = "vofi_error_validation")
      }
    }
    miss <- setdiff(c(a, b), allowed)
    if (length(miss) > 0L) {
      if (library) {
        vofi_inform("sampling.corr_pair_dropped", a = a, b = b, entry = miss[1L])
        keep[i] <- FALSE
        next
      }
      vofi_abort("sampling.corr_unknown_key", what = what, a = a, b = b, entry = miss[1L],
                 .class = "vofi_error_validation")
    }
    if (identical(a, b)) {
      vofi_abort("sampling.corr_self", what = what, entry = a, .class = "vofi_error_validation")
    }
    if (!is.finite(r) || abs(r) > 1) {
      vofi_abort("sampling.corr_range", what = what, a = a, b = b, rho = r,
                 .class = "vofi_error_validation")
    }
  }
  pairs <- pairs[keep, , drop = FALSE]
  if (nrow(pairs) == 0L) return(pairs)
  # Schlüssel je Paar in C-Ordnung (unabhängig vom Gebietsschema, 2.7 Nr. 8)
  sw <- vapply(seq_len(nrow(pairs)), function(i) {
    !identical(utl_sort(c(pairs$a[i], pairs$b[i]))[1L], pairs$a[i])
  }, logical(1))
  lo <- ifelse(sw, pairs$b, pairs$a)
  hi <- ifelse(sw, pairs$a, pairs$b)
  out <- data.frame(a = lo, b = hi, rho = pairs$rho, stringsAsFactors = FALSE)
  id <- paste(out$a, out$b, sep = "\r")
  for (u in unique(id[duplicated(id)])) {
    if (length(unique(out$rho[id == u])) > 1L) {
      vofi_abort("sampling.corr_conflict", what = what, a = out$a[id == u][1L],
                 b = out$b[id == u][1L], .class = "vofi_error_validation")
    }
  }
  out <- out[!duplicated(id), , drop = FALSE]
  out[order(out$a, out$b, method = "radix"), , drop = FALSE]
}

#' Korrelationsmatrix aus Paaren über die kanonisch sortierten Schlüssel der Gruppe
#' @return Matrix mit dimnames oder `NULL` (keine Paare).
#' @noRd
smp_corr_from_pairs <- function(pairs) {
  if (is.null(pairs) || nrow(pairs) == 0L) return(NULL)
  keys <- utl_sort(unique(c(pairs$a, pairs$b)))
  m <- diag(length(keys))
  dimnames(m) <- list(keys, keys)
  for (i in seq_len(nrow(pairs))) {
    m[pairs$a[i], pairs$b[i]] <- pairs$rho[i]
    m[pairs$b[i], pairs$a[i]] <- pairs$rho[i]
  }
  m
}

#' Korrelationen des Plans: Spearman-Matrix der statischen Größen, Schockkorrelation der
#' Prozesse; Pearson-Ziel ρ = 2 sin(π ρ_S/6) und Reparatur (Spec 01 Teil C 1.7.2–1.7.5)
#' @noRd
smp_plan_correlations <- function(corr, static, processes, prov) {
  value_keys <- static$key[static$role == "value"]
  decision <- static$key[static$role == "decision"]
  pp <- smp_clean_pairs(smp_parse_pairs(corr[["parameters"]], "parameters"), value_keys,
                        smp_pairs_from_library(prov, "parameters"), decision, "parameters")
  shocked <- names(processes)[vapply(processes, function(p) p$n_shocks >= 1L, logical(1))]
  sp <- smp_clean_pairs(smp_parse_pairs(corr[["shocks"]], "shocks"), shocked,
                        smp_pairs_from_library(prov, "shocks"), character(0), "shocks")
  rs <- smp_corr_from_pairs(pp)
  rz <- smp_corr_from_pairs(sp)
  out <- list(parameters = rs, shocks = rz, pearson_parameters = NULL, pearson_shocks = NULL,
              repaired_parameters = NULL, repaired_shocks = NULL)
  if (!is.null(rs)) {
    fix <- smp_near_pd(smp_spearman_to_pearson(rs), "parameters")
    out$pearson_parameters <- fix$matrix
    if (fix$repaired) out$repaired_parameters <- fix$matrix
  }
  if (!is.null(rz)) {
    fix <- smp_near_pd(rz, "shocks")
    out$pearson_shocks <- fix$matrix
    if (fix$repaired) out$repaired_shocks <- fix$matrix
  }
  out
}

# ---------------------------------------------------------------------------------------------
# Vereinigung der Pläne (CRN, Spec 00 11.8, 11.10)
# ---------------------------------------------------------------------------------------------

#' Prozesse eines Plans mit Schocks (`n_shocks >= 1`)
#' @noRd
smp_shocked <- function(plan) {
  procs <- plan$processes
  names(procs)[vapply(procs, function(p) p$n_shocks >= 1L, logical(1))]
}

#' Statische Schlüssel eines Plans mit Rolle `value` (korrelierbar)
#' @noRd
smp_value_keys <- function(plan) plan$static$key[plan$static$role == "value"]

#' Versatz der Prozessjahre einer Variante in den Jahren der Rohziehungen
#'
#' Die Jahre der Variante müssen ein zusammenhängender Ausschnitt der Jahre der Rohziehungen sein
#' (gleiche Kalenderjahre; die Vereinigung umfasst min(Startjahr) bis max(Endjahr)), sonst
#' Vertragsfehler.
#' @return integer(1): Anzahl der Jahre der Rohziehungen vor dem Startjahr der Variante.
#' @noRd
smp_year_offset <- function(years, raw_years) {
  years <- as.integer(years)
  raw_years <- as.integer(raw_years)
  off <- if (length(years) > 0L) match(years[1L], raw_years) - 1L else NA_integer_
  if (is.na(off) || off + length(years) > length(raw_years) ||
        !identical(years, raw_years[off + seq_along(years)])) {
    rng <- function(y) if (length(y) > 0L) utl_collapse(range(y)) else "-"
    vofi_abort("sampling.grid_years", years = rng(years), raw = rng(raw_years),
               .class = "vofi_error_contract")
  }
  as.integer(off)
}

#' Passt die Korrelationsgruppe einer Variante zu den Rohziehungen? (CRN, 11.10)
#'
#' Verträglich, wenn die Zielmatrix der Rohziehungen (Vereinigung), eingeschränkt auf die
#' Schlüssel der Variante, mit der Zielmatrix der Variante übereinstimmt (nicht genannte Paare
#' = 0; Toleranz 1e-10). Schlüssel der Vereinigung, die der Variante fehlen, sind ohne Wirkung:
#' Die Variante verwendet dann die korrelierten Ziehungen der Vereinigung, und derselbe Schlüssel
#' hat in allen Varianten dieselbe Ziehung. Hat die Variante eine eigene Gruppe, muss außerdem
#' die Copula übereinstimmen.
#' @param own Pearson-Zielmatrix der Variante oder `NULL`.
#' @param union Pearson-Zielmatrix der Rohziehungen oder `NULL`.
#' @param keys Schlüssel der Variante (statische Größen der Rolle `value` bzw. Prozesse mit
#'   Schocks).
#' @param copula,copula_union Copula der Variante bzw. der Rohziehungen (nur `parameters`).
#' @return `TRUE` oder `FALSE`.
#' @noRd
smp_corr_compatible <- function(own, union, keys, copula = NULL, copula_union = NULL) {
  k <- utl_sort(unique(c(intersect(keys, rownames(union)), rownames(own))))
  if (length(k) < 2L) return(TRUE)
  expand <- function(r) {
    out <- diag(length(k))
    dimnames(out) <- list(k, k)
    kk <- intersect(k, rownames(r))
    if (length(kk) > 0L) out[kk, kk] <- r[kk, kk, drop = FALSE]
    out
  }
  ok <- max(abs(expand(own) - expand(union))) <= 1e-10
  if (ok && !is.null(own) && !identical(copula, copula_union)) ok <- FALSE
  ok
}

#' Pläne mehrerer Varianten vereinigen (CRN)
#'
#' Ein Plan über die Vereinigung aller Schlüssel: gleicher Schlüssel mit anderem Ziel bzw.
#' statisch gegen Prozess ist `vofi_error_validation`; abweichende Ziehungseinstellungen
#' (`sampling`, `block_size`, `replicates`, `antithetic`) ebenso. Die Korrelationsgruppe der
#' Vereinigung enthält die Paare aller Pläne. Fehlt einer Variante nur ein Schlüssel eines
#' Paars, ist das kein Konflikt: Die Variante übernimmt die korrelierten Ziehungen der
#' Vereinigung (`smp_materialize()`, gleicher Schlüssel = gleiche Ziehung). Abweichende
#' Korrelationen (Paare zwischen Schlüsseln, die in beiden Plänen vorkommen, mit verschiedenen
#' Werten), eine durch die Vereinigung nötige Reparatur oder eine andere Copula ergeben
#' `vofi_warning_correlation` („CRN eingeschränkt“); die Vereinigung trägt dann die Angaben des
#' ersten Plans, `smp_materialize()` korreliert die betroffenen Varianten mit ihren eigenen
#' Angaben. Die Prozessjahre der Vereinigung reichen vom frühesten Startjahr bis zum spätesten
#' Endjahr; verschiedene Startjahre ergeben ebenfalls `vofi_warning_correlation` (Schocks nach
#' Kalenderjahr zugeordnet, Startwerte je Variante).
#' @param plans Liste von `smp_plan`.
#' @return `smp_plan`.
#' @noRd
smp_plan_union <- function(plans) {
  if (inherits(plans, "smp_plan")) plans <- list(plans)
  if (!is.list(plans) || length(plans) == 0L ||
        !all(vapply(plans, inherits, logical(1), "smp_plan"))) {
    vofi_abort("sampling.not_plan", arg = "plans", .class = "vofi_error_input")
  }
  if (length(plans) == 1L) return(plans[[1L]])
  first <- plans[[1L]]
  for (f in c("sampling", "block_size", "replicates", "antithetic")) {
    vals <- lapply(plans, function(p) p$settings[[f]])
    if (!all(vapply(vals, identical, logical(1), vals[[1L]]))) {
      vofi_abort("sampling.union_settings", field = f,
                 values = utl_collapse(vapply(vals, dist_fmt, "")),
                 .class = "vofi_error_validation")
    }
  }
  static <- first$static
  static_par <- first$static_par
  processes <- first$processes
  for (p in plans[-1L]) {
    for (i in seq_len(nrow(p$static))) {
      k <- p$static$key[i]
      if (k %in% names(processes)) {
        vofi_abort("sampling.union_kind", entry = k, .class = "vofi_error_validation")
      }
      j <- match(k, static$key)
      if (is.na(j)) {
        static <- rbind(static, p$static[i, , drop = FALSE])
        static_par[[k]] <- p$static_par[[k]]
      } else if (!identical(static$target[j], p$static$target[i])) {
        vofi_abort("sampling.union_target", entry = k,
                   targets = utl_collapse(c(static$target[j], p$static$target[i])),
                   .class = "vofi_error_validation")
      }
    }
    for (k in names(p$processes)) {
      if (k %in% static$key) {
        vofi_abort("sampling.union_kind", entry = k, .class = "vofi_error_validation")
      }
      q <- p$processes[[k]]
      if (is.null(processes[[k]])) {
        processes[[k]] <- q
      } else {
        if (!identical(processes[[k]]$target, q$target)) {
          vofi_abort("sampling.union_target", entry = k,
                     targets = utl_collapse(c(processes[[k]]$target, q$target)),
                     .class = "vofi_error_validation")
        }
        processes[[k]]$n_shocks <- max(processes[[k]]$n_shocks, q$n_shocks)
        processes[[k]]$n_uniforms <- max(processes[[k]]$n_uniforms, q$n_uniforms)
      }
    }
  }
  o <- order(static$key, method = "radix")
  static <- static[o, , drop = FALSE]
  rownames(static) <- NULL
  static_par <- static_par[static$key]
  processes <- processes[utl_sort(names(processes))]
  corr <- smp_union_correlations(plans, "parameters", static$key[static$role == "value"])
  zc <- smp_union_correlations(plans, "shocks", names(processes))
  # Varianten, die die korrelierten Ziehungen der Vereinigung nicht übernehmen können
  # (Reparatur der vereinigten Matrix, andere Copula): CRN eingeschränkt
  for (what in c("parameters", "shocks")) {
    if (isTRUE(if (what == "parameters") corr$warned else zc$warned)) next
    ok <- vapply(plans, function(p) {
      if (what == "parameters") {
        smp_corr_compatible(p$corr_pearson$parameters, corr$pearson, smp_value_keys(p),
                            p$settings$copula, first$settings$copula)
      } else {
        smp_corr_compatible(p$corr_pearson$shocks, zc$pearson, smp_shocked(p))
      }
    }, logical(1))
    if (!all(ok)) {
      vofi_warn("sampling.union_corr_restricted", what = what,
                .class = "vofi_warning_correlation")
    }
  }
  years_list <- lapply(plans, function(p) as.integer(p$years))
  starts <- vapply(years_list, function(y) y[1L], integer(1))
  ends <- vapply(years_list, function(y) y[length(y)], integer(1))
  years <- seq.int(min(starts), max(ends))
  if (length(unique(starts)) > 1L) {
    vofi_warn("sampling.union_start_year", years = utl_collapse(utl_sort(unique(starts))),
              .class = "vofi_warning_correlation")
  }
  plan <- structure(list(
    settings = first$settings, static = static, static_par = static_par,
    processes = processes, proc_order = smp_proc_order(processes),
    correlations = list(parameters = corr$spearman, shocks = zc$spearman),
    hash = NA_character_,
    corr_pearson = list(parameters = corr$pearson, shocks = zc$pearson),
    repaired = list(parameters = corr$repaired, shocks = zc$repaired),
    years = years, spec = NULL, grid = NULL, union_of = vapply(plans, function(p) p$hash, "")
  ), class = "smp_plan")
  plan$hash <- smp_plan_hash(plan)
  plan
}

#' Korrelationen der Vereinigung (Paare aller Pläne; Abweichungen mit Warnung)
#' @param what `"parameters"` oder `"shocks"`.
#' @param allowed Schlüssel der Vereinigung.
#' @return Liste `spearman` (bzw. Schockmatrix), `pearson`, `repaired`, `warned` (Warnung
#'   wegen abweichender Paare ausgegeben).
#' @noRd
smp_union_correlations <- function(plans, what, allowed) {
  pair_list <- lapply(plans, function(p) smp_pairs_of(p$correlations[[what]]))
  key_list <- lapply(plans, function(p) {
    if (what == "parameters") p$static$key else names(p$processes)
  })
  all_pairs <- unique(do.call(rbind, pair_list)[, c("a", "b"), drop = FALSE])
  rows <- list()
  warned <- FALSE
  for (i in seq_len(nrow(all_pairs))) {
    a <- all_pairs$a[i]
    b <- all_pairs$b[i]
    vals <- vapply(seq_along(plans), function(j) {
      pl <- pair_list[[j]]
      hit <- pl$rho[pl$a == a & pl$b == b]
      if (length(hit) > 0L) hit[1L] else if (all(c(a, b) %in% key_list[[j]])) 0 else NA_real_
    }, numeric(1))
    if (!warned && length(unique(vals[!is.na(vals)])) > 1L) {
      vofi_warn("sampling.union_corr_differs", a = a, b = b, what = what,
                .class = "vofi_warning_correlation")
      warned <- TRUE
    }
    rho <- vals[!is.na(vals) & vals != 0]
    if (length(rho) > 0L) {
      rows[[length(rows) + 1L]] <- data.frame(a = a, b = b, rho = rho[1L],
                                              stringsAsFactors = FALSE)
    }
  }
  pairs <- if (length(rows) > 0L) do.call(rbind, rows) else NULL
  if (!is.null(pairs)) pairs <- pairs[pairs$a %in% allowed & pairs$b %in% allowed, ,
                                      drop = FALSE]
  m <- smp_corr_from_pairs(pairs)
  if (is.null(m)) return(list(spearman = NULL, pearson = NULL, repaired = NULL, warned = warned))
  fix <- smp_near_pd(if (what == "parameters") smp_spearman_to_pearson(m) else m, what,
                     warn = FALSE)
  list(spearman = m, pearson = fix$matrix, repaired = if (fix$repaired) fix$matrix else NULL,
       warned = warned)
}

#' Paare einer Korrelationsmatrix (obere Hälfte, Werte ≠ 0)
#' @noRd
smp_pairs_of <- function(m) {
  empty <- data.frame(a = character(0), b = character(0), rho = numeric(0),
                      stringsAsFactors = FALSE)
  if (is.null(m) || nrow(m) < 2L) return(empty)
  keys <- rownames(m)
  idx <- which(upper.tri(m) & m != 0, arr.ind = TRUE)
  if (nrow(idx) == 0L) return(empty)
  data.frame(a = keys[idx[, 1L]], b = keys[idx[, 2L]], rho = m[idx], stringsAsFactors = FALSE)
}
