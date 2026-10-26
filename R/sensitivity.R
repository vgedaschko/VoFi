# Tornado, Spider, globale Sensitivitaet (WS-G, Spec 00 Abschnitte 11.11, 13.4; Spec 01 Teil C
# 4.3, 6.4).
# vofi_sensitivity(): Tornado und Spider als ein Design-Lauf (smp_design(), WS-C) ueber
# eng_run_chunk(mode = "design") je Modell (bei Vergleichskennzahlen dieselbe Designmatrix fuer
# Variante und Referenz, 12.8); Kandidaten (params = NULL) wie das Set "vorsichtig" (Teil C 4.3
# Nr. 1): statische Overlay-Schluessel, unsichere Prozessparameter, Prozesse mit Quantilpfad
# (S01C-10, R-95, R-114), Entscheidungsschluessel; Grenzen P10/P90 der Overlay-Verteilung bzw.
# Basis x (1 -/+ delta) ohne Verteilung. Globale Sensitivitaet aus einer Simulation (inputs und
# Pfadmerkmale): Spearman, SRC/SRRC (standardisierte Regression auf Werten bzw. Raengen),
# PRCC (partielle Rangkorrelation), einfacher Haupteffektindex s1_binned (20 gleich besetzte
# Klassen). Die Hilfen sens_* nutzt auch cmp_cautious() (R/compare.R).

#' Sensitivitätsanalyse
#'
#' Tornado und Spider (ein Design-Lauf) bzw. globale Sensitivität aus einer Simulation (Spec 00,
#' Abschnitte 11.11, 13.4; Spec 01 Teil C 6.4). `kpi = NULL` ist die Primärkennzahl;
#' Vergleichskennzahlen (z. B. `delta_vs_reference`) werden gegen `reference` (Default
#' `project.reference_variant`) mit derselben Designmatrix für Variante und Referenz gerechnet.
#'
#' Kandidaten mit `params = NULL`: alle statischen Overlay-Schlüssel, alle unsicheren
#' Prozessparameter (`<prozess>.<parameter>`), alle Prozesse mit Quantilpfad (Designwert ist das
#' Quantilniveau) und die Entscheidungsschlüssel der Förderzusage. Ausdrücklich genannte
#' Parameter dürfen außerdem Zielpfade mit numerischem Basiswert sein; ohne Overlay-Verteilung
#' gelten die Grenzen Basis × (1 ∓ `delta`) (Default 0,2). Basisfallgrößen wie
#' `auto`-Kreditbeträge bleiben in allen Designzeilen fest (R-69).
#'
#' `method = "global"` wertet eine Simulation aus (`x` als `vofi_mc_result`; sonst wird eine
#' Simulation mit `store = "kpi"` gerechnet): Rangkorrelation nach Spearman, standardisierte
#' Regressionskoeffizienten auf Werten (SRC) und Rängen (SRRC), partielle
#' Rangkorrelationskoeffizienten (PRCC) und der Haupteffektindex `s1_binned` =
#' `Var(E(y | Klasse(x))) / Var(y)` mit 20 gleich besetzten Klassen. Die Treiber sind nach |SRRC|
#' geordnet, wenn das Bestimmtheitsmaß der Rangregression mindestens 0,7 beträgt, sonst nach
#' `s1_binned`.
#'
#' @param x Objekt der Klasse `vofi_scenario`, `vofi_model` oder `vofi_mc_result`.
#' @param params `NULL` (alle Overlay-Ziele) oder Zielpfade.
#' @param method `"tornado"`, `"spider"` oder `"global"`.
#' @param probs Quantile der Overlay-Verteilungen für `low`/`high`.
#' @param delta relative Abweichung, wenn keine Verteilung vorliegt.
#' @param steps Stützstellen je Seite (Spider).
#' @param kpi Kennzahl (`NULL` = Primärkennzahl).
#' @param variant Variante (Default `"base"`).
#' @param reference Referenzvariante für Vergleichskennzahlen.
#' @return Objekt der Klasse `vofi_sensitivity`.
#' @family Analysieren
#' @examples
#' sc <- vofi_read_scenario(vofi_example("grob_lehrbuch_a"))
#' tor <- vofi_sensitivity(sc, params = c("shared.rw", "financing.ann.rate_pa"),
#'                         kpi = "delta_terminal_value")
#' tor$results
#' @export
vofi_sensitivity <- function(x, params = NULL, method = c("tornado", "spider", "global"),
                             probs = c(0.1, 0.9), delta = NULL, steps = 5L, kpi = NULL,
                             variant = "base", reference = NULL) {
  method <- utl_match_arg(method, c("tornado", "spider", "global"), "method")
  if (!is.numeric(probs) || length(probs) != 2L || anyNA(probs) || probs[1L] <= 0 ||
        probs[2L] >= 1 || probs[1L] >= probs[2L]) {
    vofi_abort("mc.sensitivity.probs", .class = "vofi_error_input")
  }
  if (!is.null(delta) && (!is.numeric(delta) || length(delta) != 1L || is.na(delta) ||
                            delta <= 0)) {
    vofi_abort("mc.sensitivity.delta", .class = "vofi_error_input")
  }
  steps <- utl_check_whole(steps, "steps", min = 1)
  if (!is.null(params) && (!is.character(params) || anyNA(params) || length(params) == 0L)) {
    vofi_abort("mc.arg_character", arg = "params", .class = "vofi_error_input")
  }
  if (!is.null(kpi) && !utl_is_string(kpi)) {
    vofi_abort("mc.arg_character", arg = "kpi", .class = "vofi_error_input")
  }
  if (!utl_is_string(variant)) {
    vofi_abort("mc.arg_character", arg = "variant", .class = "vofi_error_input")
  }
  if (identical(method, "global")) return(sens_global_result(x, params, kpi, variant))
  run <- mc_capture({
    setup <- sens_setup(x, variant, reference, kpi)
    cands <- sens_candidates(setup, params, probs, delta)
    out <- if (identical(method, "tornado")) sens_tornado(setup, cands) else
      sens_spider(setup, cands, steps)
    list(setup = setup, out = out)
  })
  mc_emit_conditions(run$conditions)
  setup <- run$value$setup
  out <- run$value$out
  new_vofi_sensitivity(list(
    method = method, kpi = setup$kpi, variant = variant, base_value = out$base_value,
    params = out$params, results = out$results, spider = out$spider, global = NULL,
    r2_src = NA_real_,
    meta = list(probs = probs, delta = delta %||% 0.2, steps = steps,
                reference = setup$reference, higher_is_better = setup$hib,
                n_rows = out$n_rows, unit = kpi_unit(setup$kpi), created = Sys.time())
  ))
}

# ---------------------------------------------------------------------------------------------
# Modelle und Kennzahl
# ---------------------------------------------------------------------------------------------

#' Namen der Vergleichskennzahlen (12.6)
#' @noRd
sens_compare_kpis <- function() c(names(kpi_compare_specs()), "delta_vs_reference")

#' Kennzahlen, die eine Vergleichskennzahl im Design-Lauf braucht (12.6)
#' @noRd
sens_needed_kpis <- function(base) {
  switch(base,
    delta_vs_reference = , prob_better_than_ref = "delta_terminal_value",
    payback_vs_reference = , payback_year_vs_reference = c("terminal_value",
                                                           "delta_terminal_value"),
    co2_reduction = "co2_emissions",
    co2_abatement_cost = c("co2_emissions", "delta_terminal_value", cmp_qt_name()),
    monthly_saving_y1 = "monthly_burden_y1",
    monthly_saving_avg10 = "monthly_burden_avg10",
    monthly_cashflow_change_y1 = "monthly_net_cashflow_y1",
    warm_rent_change_y1 = "warm_rent_y1",
    base
  )
}

#' Einstellungen der Design-Läufe aus den Modellen und der Kennzahl
#' @param model Modell der Variante.
#' @param ref_model Modell der Referenz (nur bei Vergleichskennzahlen) bzw. `NULL`.
#' @param kpi Kennzahl (auch `<name>_ex_rv`).
#' @return Liste `model`, `ref_model`, `kpi`, `base_kpi`, `compare`, `hib`, `kpis`, `paths`.
#' @noRd
sens_setup_models <- function(model, ref_model, kpi) {
  base <- kpi_base_name(kpi)
  cmpk <- base %in% sens_compare_kpis()
  if (identical(base, "incremental_return")) {
    vofi_abort("mc.sensitivity.kpi_not_design", kpi = kpi, .class = "vofi_error_input")
  }
  if (cmpk && is.null(ref_model)) {
    vofi_abort("mc.sensitivity.reference_missing", kpi = kpi, .class = "vofi_error_input")
  }
  if (!cmpk && !(base %in% names(model$kpis))) {
    vofi_abort("mc.sensitivity.kpi_unknown", kpi = kpi,
               suggestion = utl_suggest_text(base, names(model$kpis)),
               .class = "vofi_error_input")
  }
  hib <- if (cmpk) kpi_compare_specs()[[base]]$hib %||% TRUE else
    model$kpis[[base]]$higher_is_better
  if (cmpk) {
    model <- cmp_with_qt(model)
    ref_model <- cmp_with_qt(ref_model)
  }
  list(model = model, ref_model = if (cmpk) ref_model else NULL, kpi = kpi, base_kpi = base,
       compare = cmpk, hib = !isFALSE(hib), kpis = sens_needed_kpis(base),
       paths = if (startsWith(base, "payback")) cmp_paths() else character(0))
}

#' Modelle aus der Eingabe (Szenario, Modell oder Simulation)
#' @noRd
sens_setup <- function(x, variant = "base", reference = NULL, kpi = NULL) {
  model <- if (inherits(x, "vofi_mc_result")) {
    x$model
  } else if (inherits(x, "vofi_model")) {
    x
  } else if (inherits(x, "vofi_scenario")) {
    vofi_build(x, variant = variant)
  } else {
    vofi_abort("mc.sensitivity.x_invalid", .class = "vofi_error_input")
  }
  if (!inherits(model, "vofi_model")) {
    vofi_abort("mc.sensitivity.x_invalid", .class = "vofi_error_input")
  }
  kpi <- kpi %||% kpi_primary(model$spec)$kpi
  ref_model <- NULL
  ref <- NULL
  if (kpi_base_name(kpi) %in% sens_compare_kpis()) {
    if (!inherits(x, "vofi_scenario")) {
      vofi_abort("mc.sensitivity.needs_scenario", kpi = kpi, .class = "vofi_error_input")
    }
    ref <- reference %||% model$spec$project$reference_variant
    if (!utl_is_string(ref)) {
      vofi_abort("mc.sensitivity.reference_missing", kpi = kpi, .class = "vofi_error_input")
    }
    if (identical(ref, variant)) {
      vofi_abort("mc.sensitivity.reference_same", variant = variant,
                 .class = "vofi_error_input")
    }
    ref_model <- vofi_build(x, variant = ref)
  }
  out <- sens_setup_models(model, ref_model, kpi)
  out$reference <- ref
  out
}

#' Kennzahl je Designzeile (11.11; Vergleichskennzahlen gegen die Referenz, 12.8)
#' @param setup Einstellungen aus `sens_setup_models()`.
#' @param design Data Frame der Designzeilen.
#' @return numerischer Vektor (eine Zahl je Zeile).
#' @noRd
sens_eval <- function(setup, design) {
  cv <- cmp_design_run(setup$model, design, kpis = setup$kpis, return_paths = setup$paths)
  vals <- if (setup$compare) {
    cr <- cmp_design_run(setup$ref_model, design, kpis = setup$kpis,
                         return_paths = setup$paths)
    cmp_compare_sides(cmp_side(cv, setup$model), cmp_side(cr, setup$ref_model))$kpis
  } else {
    cv$kpis
  }
  v <- vals[[setup$kpi]]
  if (is.null(v)) {
    vofi_abort("mc.sensitivity.kpi_unknown", kpi = setup$kpi,
               suggestion = utl_suggest_text(setup$kpi, names(vals)),
               .class = "vofi_error_input")
  }
  as.double(v)
}

# ---------------------------------------------------------------------------------------------
# Kandidaten (Spec 01 Teil C 4.3 Nr. 1, 6.4)
# ---------------------------------------------------------------------------------------------

#' Pläne der beteiligten Modelle (Variante, Referenz, Ausweichvarianten)
#' @noRd
sens_plans <- function(setup) {
  ms <- list(setup$model, setup$ref_model, setup$model$decision$fallback,
             setup$ref_model$decision$fallback)
  pl <- lapply(Filter(Negate(is.null), ms), function(m) m$sampler)
  Filter(function(p) inherits(p, "smp_plan"), pl)
}

#' Basisfallwert eines Ziels (Spalte 1 bzw. konstanter Pfad) im Plan
#' @return Zahl bzw. `NA` (nicht konstant oder ohne Wert).
#' @noRd
sens_base_value <- function(plan, path) {
  ctx <- tryCatch(smp_base_ctx(plan$spec, plan$grid), error = function(e) NULL)
  if (is.null(ctx)) return(NA_real_)
  v <- smp_value_base(ctx, path)
  if (is.null(v) || !is.numeric(v) || length(v) == 0L) return(NA_real_)
  v <- as.double(v)
  if (any(abs(v - v[1L]) > 1e-12 * max(1, abs(v[1L])))) return(NA_real_)
  v[1L]
}

#' Kandidat aus einem statischen Eintrag des Plans
#' @noRd
sens_static_candidate <- function(plan, i) {
  st <- plan$static
  key <- st$key[i]
  src <- if (identical(st$role[i], "decision")) "decision" else
    if (identical(st$source[i], "process_param")) "process_param" else "overlay"
  par <- plan$static_par[[key]]
  ap <- st$apply[i] %||% "replace"
  base <- switch(src,
    process_param = tryCatch(as.double(reg_get("distribution", st$dist[i])$point(par, "mean")),
                             error = function(e) NA_real_),
    decision = {
      b <- sens_base_value(plan, st$target[i])
      if (is.na(b)) 1 else b
    },
    if (identical(ap, "multiply")) 1 else if (identical(ap, "add")) 0 else
      sens_base_value(plan, st$target[i])
  )
  list(param = key, label = if (is.na(st$label[i])) key else st$label[i], source = src,
       dist = st$dist[i], par = par, apply = ap, target = st$target[i], base = base)
}

#' Hat der Prozess einen geschlossenen Quantilpfad (R-95, R-114)?
#' @noRd
sens_has_quantile_path <- function(plan, p) {
  pr <- plan$processes[[p]]
  def <- reg_get("process", pr$type)
  if (is.null(def$quantile_path)) return(FALSE)
  qp <- tryCatch(def$quantile_path(smp_point_par(plan, p), plan$years, 0.5),
                 error = function(e) NA_real_)
  !anyNA(qp)
}

#' Kandidat aus einem Prozess (Quantilpfad)
#' @noRd
sens_process_candidate <- function(plan, p) {
  pr <- plan$processes[[p]]
  lab <- pr$label
  list(param = p, label = if (utl_is_string(lab)) lab else p, source = "process",
       dist = NA_character_, par = NULL, apply = "replace", target = pr$target,
       base = NA_real_)
}

#' Kandidaten mit `params = auto` (Teil C 4.3 Nr. 1)
#' @noRd
sens_auto_candidates <- function(plans) {
  out <- list()
  for (pl in plans) {
    st <- pl$static
    for (i in seq_len(nrow(st))) {
      if (!(st$key[i] %in% names(out))) out[[st$key[i]]] <- sens_static_candidate(pl, i)
    }
    for (p in names(pl$processes)) {
      if (p %in% names(out)) next
      def <- reg_get("process", pl$processes[[p]]$type)
      if (is.null(def$quantile_path)) next
      if (!sens_has_quantile_path(pl, p)) {
        vofi_inform("validation.scenario_set.quantile_path_unavailable",
                    path = paste0("stochastic.processes.", p), value = p)
        next
      }
      out[[p]] <- sens_process_candidate(pl, p)
    }
  }
  if (length(out) == 0L) return(list())
  out[order(names(out), method = "radix")]
}

#' Kandidat zu einem ausdrücklich genannten Parameter
#' @noRd
sens_param_candidate <- function(p, plans) {
  for (pl in plans) {
    st <- pl$static
    if (p %in% st$key) return(sens_static_candidate(pl, match(p, st$key)))
    if (p %in% names(pl$processes)) {
      if (!sens_has_quantile_path(pl, p)) {
        vofi_abort("mc.sensitivity.no_quantile_path", param = p, .class = "vofi_error_input")
      }
      return(sens_process_candidate(pl, p))
    }
    hit <- which(st$target == p & st$role == "value")
    if (length(hit) > 0L) {
      cand <- sens_static_candidate(pl, hit[1L])
      if (identical(cand$label, cand$param)) cand$label <- p
      return(cand)
    }
  }
  for (pl in plans) {
    segs <- path_split(p)
    if (length(segs) == 2L && segs[1L] %in% names(pl$processes)) {
      def <- reg_get("process", pl$processes[[segs[1L]]]$type)
      if (segs[2L] %in% names(def$params)) {
        b <- tryCatch(as.double(smp_point_par(pl, segs[1L])[[segs[2L]]])[1L],
                      error = function(e) NA_real_)
        return(list(param = p, label = p, source = "delta", dist = NA_character_, par = NULL,
                    apply = "replace", target = p, base = b))
      }
    }
    if (!is.null(pl$spec) && !is.null(path_get(pl$spec, p))) {
      b <- sens_base_value(pl, p)
      if (is.na(b)) {
        vofi_abort("mc.sensitivity.path_target", param = p, .class = "vofi_error_input")
      }
      return(list(param = p, label = p, source = "delta", dist = NA_character_, par = NULL,
                  apply = "replace", target = p, base = b))
    }
  }
  vofi_abort("mc.sensitivity.param_unknown", param = p,
             suggestion = utl_suggest_text(p, unique(unlist(lapply(plans, function(pl) {
               c(pl$static$key, pl$static$target, names(pl$processes))
             })))), .class = "vofi_error_input")
}

#' Wert eines Kandidaten zum Quantilniveau p (Overlay-Verteilung) bzw. Prozess-Designwert p
#' @noRd
sens_value_at <- function(cand, p) {
  if (identical(cand$source, "process")) return(p)
  if (identical(cand$source, "delta")) return(NA_real_)
  as.double(reg_get("distribution", cand$dist)$quantile(p, cand$par))
}

#' Ausschlussmuster (`generate.exclude`, ein Segment `*` zulässig) auf Kandidatennamen
#' @noRd
sens_excluded <- function(names_c, exclude) {
  if (length(exclude) == 0L) return(rep(FALSE, length(names_c)))
  hit <- rep(FALSE, length(names_c))
  for (e in exclude) {
    rx <- paste0("^", gsub("\\*", "[^.]+", gsub(".", "\\.", e, fixed = TRUE)), "$")
    hit <- hit | grepl(rx, names_c)
  }
  hit
}

#' Kandidaten mit Grenzen `low`/`high` (11.11, Teil C 4.3, 6.4)
#'
#' Grenzen: Quantile `probs` der Overlay-Verteilung (bei `apply` multiply/add die Ziehung x),
#' bei Prozessen das Quantilniveau selbst, ohne Verteilung Basis × (1 ∓ `delta`).
#' @return Liste von Kandidaten (Felder `param`, `label`, `source`, `base`, `low`, `high`, …).
#' @noRd
sens_candidates <- function(setup, params = NULL, probs = c(0.1, 0.9), delta = NULL,
                            exclude = character(0)) {
  plans <- sens_plans(setup)
  delta <- delta %||% 0.2
  cands <- if (is.null(params)) sens_auto_candidates(plans) else
    lapply(unique(params), sens_param_candidate, plans = plans)
  if (length(cands) > 0L) {
    names(cands) <- vapply(cands, function(cc) cc$param, "")
    cands <- cands[!duplicated(names(cands))]
    cands <- cands[!sens_excluded(names(cands), exclude)]
  }
  lapply(cands, function(cc) {
    if (identical(cc$source, "delta")) {
      cc$low <- cc$base * (1 - delta)
      cc$high <- cc$base * (1 + delta)
    } else {
      cc$low <- sens_value_at(cc, probs[1L])
      cc$high <- sens_value_at(cc, probs[2L])
    }
    cc$delta <- delta
    cc
  })
}

#' Parametertabelle der Kandidaten (13.4 `params`)
#' @noRd
sens_params_frame <- function(cands) {
  if (length(cands) == 0L) {
    return(data.frame(param = character(0), label = character(0), base = numeric(0),
                      low = numeric(0), high = numeric(0), source = character(0),
                      stringsAsFactors = FALSE))
  }
  data.frame(param = vapply(cands, function(cc) cc$param, ""),
             label = vapply(cands, function(cc) as.character(cc$label), ""),
             base = vapply(cands, function(cc) as.double(cc$base), double(1)),
             low = vapply(cands, function(cc) as.double(cc$low), double(1)),
             high = vapply(cands, function(cc) as.double(cc$high), double(1)),
             source = vapply(cands, function(cc) cc$source, ""),
             stringsAsFactors = FALSE, row.names = NULL)
}

#' Leere Designmatrix (Basisfall) mit Spalten der Kandidaten
#' @noRd
sens_design_frame <- function(n, cols) {
  m <- matrix(NA_real_, n, length(cols), dimnames = list(NULL, cols))
  d <- as.data.frame(m, optional = TRUE)
  names(d) <- cols
  d
}

# ---------------------------------------------------------------------------------------------
# Tornado und Spider (11.11)
# ---------------------------------------------------------------------------------------------

#' Tornado als ein Design-Lauf mit 1 + 2k Zeilen (Zeile 1 = Basisfall)
#' @return Liste `results` (Data Frame nach 13.4, nach Rang), `params`, `base_value`, `n_rows`,
#'   `spider = NULL`.
#' @noRd
sens_tornado <- function(setup, cands) {
  k <- length(cands)
  cols <- unname(vapply(cands, function(cc) cc$param, ""))
  design <- sens_design_frame(1L + 2L * k, cols)
  for (j in seq_len(k)) {
    design[[j]][2L * j] <- cands[[j]]$low
    design[[j]][2L * j + 1L] <- cands[[j]]$high
  }
  if (k == 0L) design <- data.frame(row.names = 1L)
  y <- sens_eval(setup, design)
  lo <- if (k > 0L) y[2L * seq_len(k)] else numeric(0)
  hi <- if (k > 0L) y[2L * seq_len(k) + 1L] else numeric(0)
  swing <- abs(hi - lo)
  res <- data.frame(param = cols,
                    value_low = vapply(cands, function(cc) as.double(cc$low), double(1)),
                    value_high = vapply(cands, function(cc) as.double(cc$high), double(1)),
                    kpi_low = lo, kpi_high = hi, swing = swing, rank = integer(k),
                    stringsAsFactors = FALSE, row.names = NULL)
  if (k > 0L) {
    o <- order(-swing, cols, method = "radix", na.last = TRUE)
    res$rank[o] <- seq_len(k)
    res <- res[o, , drop = FALSE]
    rownames(res) <- NULL
  }
  list(results = res, params = sens_params_frame(cands), base_value = y[1L],
       n_rows = nrow(design), spider = NULL)
}

#' Spider als ein Design-Lauf: je Parameter `steps` Stützstellen je Seite zwischen P05 und P95
#' (bzw. Basis × (1 ± delta)), Schritt 0 = Basisfall (Teil C 6.4)
#' @noRd
sens_spider <- function(setup, cands, steps = 5L) {
  k <- length(cands)
  cols <- unname(vapply(cands, function(cc) cc$param, ""))
  s <- c(-rev(seq_len(steps)), seq_len(steps))
  design <- sens_design_frame(1L + length(s) * k, cols)
  vals <- list()
  for (j in seq_len(k)) {
    cc <- cands[[j]]
    v <- if (identical(cc$source, "delta")) cc$base * (1 + s * cc$delta / steps) else
      vapply(0.5 + s * 0.45 / steps, function(p) sens_value_at(cc, p), double(1))
    rows <- 1L + (j - 1L) * length(s) + seq_along(s)
    design[[j]][rows] <- v
    vals[[j]] <- v
  }
  if (k == 0L) design <- data.frame(row.names = 1L)
  y <- sens_eval(setup, design)
  parts <- lapply(seq_len(k), function(j) {
    rows <- 1L + (j - 1L) * length(s) + seq_along(s)
    base_v <- if (identical(cands[[j]]$source, "process")) 0.5 else cands[[j]]$base
    data.frame(param = cols[j], step = c(s[s < 0], 0L, s[s > 0]),
               value = c(vals[[j]][s < 0], base_v, vals[[j]][s > 0]),
               kpi = c(y[rows][s < 0], y[1L], y[rows][s > 0]), stringsAsFactors = FALSE)
  })
  spider <- if (k > 0L) do.call(rbind, parts) else
    data.frame(param = character(0), step = integer(0), value = numeric(0),
               kpi = numeric(0), stringsAsFactors = FALSE)
  spider$step <- as.integer(spider$step)
  rownames(spider) <- NULL
  list(results = NULL, params = sens_params_frame(cands), base_value = y[1L],
       n_rows = nrow(design), spider = spider)
}

# ---------------------------------------------------------------------------------------------
# Globale Sensitivität (Teil C 6.4)
# ---------------------------------------------------------------------------------------------

#' Standardisierte Regression (Koeffizienten und Bestimmtheitsmaß)
#' @noRd
sens_std_fit <- function(m, y) {
  ms <- scale(m)
  ys <- (y - mean(y)) / stats::sd(y)
  q <- qr(ms)
  b <- as.double(qr.coef(q, ys))
  r <- qr.resid(q, ys)
  list(b = b, r2 = 1 - sum(r^2) / sum(ys^2))
}

#' Globale Sensitivitätsmaße aus Stichproben (Teil C 6.4)
#'
#' @param x Data Frame der Eingangsgrößen (numerisch; konstante Spalten entfallen).
#' @param y Kennzahl je Lauf.
#' @param bins Klassen für `s1_binned` (gleich besetzt nach Rang).
#' @return Liste `global` (Data Frame `input`, `spearman`, `src`, `srrc`, `prcc`, `s1_binned`,
#'   geordnet), `r2_src`, `r2_srrc`, `rank_by`, `n_valid`.
#' @noRd
sens_global <- function(x, y, bins = 20L) {
  empty <- list(global = data.frame(input = character(0), spearman = numeric(0),
                                    src = numeric(0), srrc = numeric(0), prcc = numeric(0),
                                    s1_binned = numeric(0), stringsAsFactors = FALSE),
                r2_src = NA_real_, r2_srrc = NA_real_, rank_by = NA_character_, n_valid = 0L)
  y <- as.double(y)
  if (!is.data.frame(x) || ncol(x) == 0L) return(empty)
  ok <- !is.na(y) & stats::complete.cases(x)
  x <- x[ok, , drop = FALSE]
  y <- y[ok]
  n <- length(y)
  keep <- vapply(x, function(v) is.numeric(v) && length(unique(v)) > 1L, logical(1))
  x <- x[, keep, drop = FALSE]
  if (n < 3L || ncol(x) == 0L || stats::var(y) <= 0) {
    empty$n_valid <- n
    return(empty)
  }
  xm <- as.matrix(x)
  storage.mode(xm) <- "double"
  rk <- apply(xm, 2L, rank)
  if (!is.matrix(rk)) rk <- matrix(rk, ncol = ncol(xm))
  ry <- rank(y)
  spearman <- vapply(seq_len(ncol(xm)), function(j) stats::cor(rk[, j], ry), double(1))
  src <- sens_std_fit(xm, y)
  srrc <- sens_std_fit(rk, ry)
  prcc <- vapply(seq_len(ncol(xm)), function(j) {
    if (ncol(xm) == 1L) return(spearman[j])
    q <- qr(cbind(1, rk[, -j, drop = FALSE]))
    a <- qr.resid(q, rk[, j])
    b <- qr.resid(q, ry)
    if (stats::sd(a) <= 0 || stats::sd(b) <= 0) return(NA_real_)
    stats::cor(a, b)
  }, double(1))
  vy <- mean((y - mean(y))^2)
  s1 <- vapply(seq_len(ncol(xm)), function(j) {
    cls <- ceiling(rank(xm[, j], ties.method = "first") * bins / n)
    mk <- as.double(rowsum(y, cls, reorder = TRUE)) / tabulate(cls)[sort(unique(cls))]
    nk <- tabulate(cls)[sort(unique(cls))]
    sum(nk * (mk - mean(y))^2) / n / vy
  }, double(1))
  g <- data.frame(input = colnames(xm), spearman = spearman, src = src$b, srrc = srrc$b,
                  prcc = prcc, s1_binned = s1, stringsAsFactors = FALSE)
  rank_by <- if (isTRUE(srrc$r2 >= 0.7)) "srrc" else "s1_binned"
  o <- if (rank_by == "srrc") order(-abs(g$srrc), g$input, method = "radix") else
    order(-g$s1_binned, g$input, method = "radix")
  g <- g[o, , drop = FALSE]
  rownames(g) <- NULL
  list(global = g, r2_src = src$r2, r2_srrc = srrc$r2, rank_by = rank_by, n_valid = n)
}

#' Globale Sensitivität einer Simulation als `vofi_sensitivity` (13.4)
#' @noRd
sens_global_result <- function(x, params, kpi, variant) {
  mc <- if (inherits(x, "vofi_mc_result")) {
    x
  } else if (inherits(x, "vofi_model")) {
    vofi_mc(x, store = "kpi")
  } else if (inherits(x, "vofi_scenario")) {
    vofi_mc(vofi_build(x, variant = variant), store = "kpi")
  } else {
    vofi_abort("mc.sensitivity.x_invalid", .class = "vofi_error_input")
  }
  kpi <- kpi %||% kpi_primary(mc$spec)$kpi
  if (is.null(mc$kpis[[kpi]])) {
    vofi_abort("mc.sensitivity.kpi_unknown", kpi = kpi,
               suggestion = utl_suggest_text(kpi, setdiff(names(mc$kpis), c("sim", "block"))),
               .class = "vofi_error_input")
  }
  inp <- mc$inputs %||% data.frame()
  fea <- mc$features %||% data.frame()
  x_in <- inp[, setdiff(names(inp), "sim"), drop = FALSE]
  x_fe <- fea[, setdiff(names(fea), "sim"), drop = FALSE]
  st <- mc$model$sampler$static
  dec_keys <- if (is.data.frame(st)) st$key[st$role == "decision"] else character(0)
  if (!is.null(mc$model$decision)) dec_keys <- c(dec_keys, mc$model$decision$key)
  xx <- if (ncol(x_fe) > 0L && nrow(x_fe) == nrow(x_in)) cbind(x_in, x_fe) else x_in
  xx <- xx[, setdiff(names(xx), dec_keys), drop = FALSE]
  if (!is.null(params)) xx <- xx[, intersect(params, names(xx)), drop = FALSE]
  g <- sens_global(xx, mc$kpis[[kpi]])
  det <- mc$deterministic$kpis[[kpi]]
  params_df <- data.frame(param = g$global$input, label = g$global$input,
                          base = rep(NA_real_, nrow(g$global)),
                          low = rep(NA_real_, nrow(g$global)),
                          high = rep(NA_real_, nrow(g$global)),
                          source = rep("mc", nrow(g$global)), stringsAsFactors = FALSE)
  new_vofi_sensitivity(list(
    method = "global", kpi = kpi, variant = mc$meta$variant %||% variant,
    base_value = if (is.null(det)) NA_real_ else as.double(det[1L]), params = params_df,
    results = NULL, spider = NULL, global = g$global, r2_src = g$r2_src,
    meta = list(r2_srrc = g$r2_srrc, rank_by = g$rank_by, n_valid = g$n_valid, bins = 20L,
                n_sim = mc$meta$n_sim, seed = mc$meta$seed, created = Sys.time())
  ))
}
