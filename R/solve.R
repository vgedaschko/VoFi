# Zielwertsuche (WS-G, Spec 00 Abschnitte 12.8, 13.4, 13.6; Spec 01 Teil C 6.5).
# vofi_solve(): Break-even und kritische Werte jeder Kennzahl (Zielwert oder
# "threshold:<name>" aus analysis.thresholds), ausgewertet ueber Design-Laeufe (11.11) bzw.
# Schicht 8 (Pfad ohne numerisches Blatt oder rebuild = TRUE); Monotoniepruefung auf 11
# Stuetzstellen, stats::uniroot() im ersten Wechselintervall, Kennzeichnung von Sprungstellen,
# Ueberschreitungswahrscheinlichkeit bei Overlay-Verteilung; Vergleichskennzahlen gegen die
# Referenz mit derselben Designmatrix; Zielrenditemiete im Bestand ohne Bestandswert ueber
# delta_vs_reference = 0 bei Habenzins = Zielrendite (Teil C 6.5); Entnahme-Aequivalent mit der
# Toleranz des Aufrufs (kpi_withdrawal_equivalent(), WS-D2); Rendite der Mehrinvestition
# (cmp_incremental_return(), R/compare.R). print() fuer vofi_solution (13.6, WS-G).

#' Zielwertsuche
#'
#' Allgemeine Zielwertsuche (Kennzahl, Zielwert oder Schwelle `"threshold:<name>"`,
#' Monotonieprüfung), Entnahme-Äquivalent und Rendite der Mehrinvestition (Spec 00, Abschnitt
#' 12.8).
#'
#' `what = "breakeven"` bzw. `"critical_value"`: gesucht ist der Wert x am Pfad `param` mit
#' KPI(x) = `target` (Default 0; `kpi = NULL` ist die Primärkennzahl). Ausgewertet wird über
#' Design-Läufe (ein Lauf je Auswertung, Basisfallgrößen wie `auto`-Kreditbeträge fest) bzw.
#' über ein neu gebautes Modell (Schicht 8), wenn der Pfad kein numerisches Blatt ist oder
#' `rebuild = TRUE` gilt. Zuerst werden 11 äquidistante Stützstellen des Intervalls gerechnet
#' (Default: Minimum und Maximum der Overlay-Verteilung, sonst 0,5- bis 1,5-faches des
#' Basiswerts); ohne Vorzeichenwechsel ist das Ergebnis `NA` mit Hinweis, bei mehreren
#' Wechseln oder nicht monotonen Werten wird im ersten Wechselintervall gesucht (Warnung,
#' `monotone = FALSE`). Weicht die Kennzahl am Ergebnis um mehr als 1 EUR (bzw. 1e-4 bei
#' Raten, Anteilen und Verhältnissen) vom Ziel ab, ist es eine Sprungstelle (`jump = TRUE`).
#' Mit Overlay-Verteilung des Ziels steht P(X > x*) in `prob_exceed`. Vergleichskennzahlen
#' werden gegen `reference` (Default `project.reference_variant`) mit derselben Designmatrix
#' gerechnet. Ist bei der Zielrenditemiete `roe_mirr` mangels Bestandswert nicht definiert
#' (`no_existing_value`), wird gleichwertig `delta_vs_reference` = 0 bei Habenzins =
#' Zielrendite gesucht (Hinweis).
#'
#' `what = "withdrawal_equivalent"`: Entnahme-Äquivalent des deterministischen Laufs mit der
#' Toleranz `tol` (EUR/Jahr; Wert ohne Restwert im Attribut `"value_ex_rv"`).
#' `what = "incremental_return"`: Habenzins h*, bei dem `delta_vs_reference` null wird (41
#' Stützstellen auf `interval`, Default `[-0,02; 0,15]`, genau ein Vorzeichenwechsel mit
#' fallendem Verlauf, sonst `NA`).
#'
#' @param x Objekt der Klasse `vofi_scenario` oder `vofi_model`.
#' @param what `"breakeven"`, `"critical_value"`, `"withdrawal_equivalent"` oder
#'   `"incremental_return"`.
#' @param param Pfad des variierten Parameters.
#' @param kpi Kennzahl (`NULL` = Primärkennzahl).
#' @param target Zielwert oder `"threshold:<name>"`.
#' @param interval Suchintervall (Default aus der Overlay-Verteilung bzw. 0,5- bis 1,5-faches
#'   des Basiswerts).
#' @param tol Toleranz.
#' @param variant Variante (Default `"base"`).
#' @param reference Referenzvariante für Vergleichskennzahlen.
#' @param rebuild Modell je Auswertung neu bauen (Basisfallgrößen wie `auto`-Beträge neu
#'   bestimmen).
#' @return Objekt der Klasse `vofi_solution`.
#' @family Analysieren
#' @examples
#' sc <- vofi_read_scenario(vofi_example("grob_lehrbuch_a"))
#' sol <- vofi_solve(sc, param = "shared.rw", kpi = "delta_terminal_value")
#' sol$value
#' @export
vofi_solve <- function(x, what = c("breakeven", "critical_value", "withdrawal_equivalent",
                                   "incremental_return"),
                       param = NULL, kpi = NULL, target = 0, interval = NULL, tol = 1e-8,
                       variant = "base", reference = NULL, rebuild = FALSE) {
  what <- utl_match_arg(what, c("breakeven", "critical_value", "withdrawal_equivalent",
                                "incremental_return"), "what")
  if (!is.numeric(tol) || length(tol) != 1L || is.na(tol) || tol <= 0) {
    vofi_abort("mc.solve.tol", .class = "vofi_error_input")
  }
  if (!utl_is_flag(rebuild)) mc_abort_flag("rebuild")
  if (!utl_is_string(variant)) {
    vofi_abort("mc.arg_character", arg = "variant", .class = "vofi_error_input")
  }
  if (!is.null(interval) && (!is.numeric(interval) || length(interval) != 2L ||
                               anyNA(interval) || interval[1L] >= interval[2L])) {
    vofi_abort("mc.solve.interval", .class = "vofi_error_input")
  }
  run <- mc_capture(switch(what,
    withdrawal_equivalent = slv_withdrawal(x, variant, tol),
    incremental_return = slv_incremental(x, variant, reference, interval, tol),
    slv_target_search(x, what, param, kpi, target, interval, tol, variant, reference, rebuild)
  ))
  sol <- run$value
  mc_emit_conditions(run$conditions)
  if (isFALSE(sol$monotone) && !is.na(sol$value)) {
    vofi_warn("mc.solve.not_monotone", param = sol$param %||% "-",
              .class = "vofi_warning_plausibility")
  }
  if (is.na(sol$value)) vofi_inform("mc.solve.no_solution_note", message = sol$message)
  sol
}

# ---------------------------------------------------------------------------------------------
# Hilfen
# ---------------------------------------------------------------------------------------------

#' Modell aus der Eingabe (Szenario, Modell oder Simulation)
#' @noRd
slv_model <- function(x, variant) {
  if (inherits(x, "vofi_scenario")) return(vofi_build(x, variant = variant))
  if (inherits(x, "vofi_model")) return(x)
  if (inherits(x, "vofi_mc_result") && inherits(x$model, "vofi_model")) return(x$model)
  vofi_abort("mc.solve.x_invalid", .class = "vofi_error_input")
}

#' Modell des Basisfall-Zweigs (Entscheidungsknoten, 9.11 Nr. 3)
#' @noRd
slv_realized <- function(model) {
  dec <- model$decision
  if (is.null(dec) || identical(as.integer(dec$branch %||% 1L), 1L)) model else dec$fallback
}

#' Zielwert aus Zahl bzw. `"threshold:<name>"` (`analysis.thresholds`, 12.8)
#' @return Liste `value`, `source`.
#' @noRd
slv_target <- function(target, spec) {
  if (is.numeric(target) && length(target) == 1L && !is.na(target)) {
    return(list(value = as.double(target), source = "value"))
  }
  if (utl_is_string(target) && startsWith(target, "threshold:")) {
    nm <- sub("^threshold:", "", target)
    v <- cmp_spec_num(spec, paste0("analysis.thresholds.", nm))
    if (is.na(v)) {
      vofi_abort("mc.solve.threshold_missing", name = nm, .class = "vofi_error_input")
    }
    return(list(value = v, source = target))
  }
  vofi_abort("mc.solve.target", .class = "vofi_error_input")
}

#' Ist der Pfad ein numerisches Blatt (Zahl bzw. Konstantenknoten)?
#' @noRd
slv_numeric_leaf <- function(spec, path) {
  v <- path_get(spec, path)
  if (is.numeric(v) && !is.list(v)) return(length(v) == 1L)
  is.list(v) && identical(v$kind, "const") && is.numeric(v$value) && length(v$value) == 1L
}

#' Overlay-Eintrag (Rolle value) mit dem Ziel `path` im Plan
#' @return Liste `dist`, `par`, `apply` bzw. `NULL`.
#' @noRd
slv_overlay_entry <- function(plan, path) {
  if (!inherits(plan, "smp_plan")) return(NULL)
  st <- plan$static
  hit <- which(st$target == path & st$role == "value")
  if (length(hit) == 0L) return(NULL)
  i <- hit[1L]
  list(key = st$key[i], dist = st$dist[i], par = plan$static_par[[st$key[i]]],
       apply = st$apply[i] %||% "replace")
}

#' Wert eines Ziels aus der Ziehung x nach `apply` (R-94)
#' @noRd
slv_apply <- function(x, b, ap) {
  switch(ap %||% "replace", multiply = b * x, add = b + x, x)
}

#' Default-Suchintervall (12.8): [min, max] der Overlay-Verteilung, sonst Basis × [0,5; 1,5]
#' @noRd
slv_default_interval <- function(entry, base) {
  if (!is.null(entry)) {
    q <- reg_get("distribution", entry$dist)$quantile
    r <- as.double(c(q(0, entry$par), q(1, entry$par)))
    if (!all(is.finite(r))) r <- as.double(c(q(1e-3, entry$par), q(1 - 1e-3, entry$par)))
    r <- slv_apply(r, base, entry$apply)
    if (all(is.finite(r)) && r[1L] != r[2L]) return(sort(r))
  }
  if (is.na(base) || base == 0) {
    vofi_abort("mc.solve.interval_missing", .class = "vofi_error_input")
  }
  sort(base * c(0.5, 1.5))
}

#' Toleranz der Sprungstellen-Kennzeichnung (1 EUR bzw. 1e-4)
#' @noRd
slv_jump_tol <- function(kpi) {
  u <- kpi_unit(kpi)
  if (!is.na(u) && startsWith(u, "EUR")) 1 else 1e-4
}

#' Lösungsobjekt (13.4)
#' @noRd
slv_solution <- function(...) new_vofi_solution(list(...))

# ---------------------------------------------------------------------------------------------
# Entnahme-Äquivalent und Rendite der Mehrinvestition
# ---------------------------------------------------------------------------------------------

#' Entnahme-Äquivalent mit der Toleranz des Aufrufs (12.8)
#' @noRd
slv_withdrawal <- function(x, variant, tol) {
  model <- slv_realized(slv_model(x, variant))
  acc <- new.env(parent = emptyenv())
  def <- kpi_typedef("withdrawal_equivalent", function(core, ctx) {
    r <- kpi_withdrawal_equivalent(core, ctx, tol = tol)
    acc[[core$view %||% "with_rv"]] <- attr(r, "solver")
    attr(r, "solver") <- NULL
    r
  }, unit = "EUR_pa", rv_variant = TRUE, higher_is_better = TRUE, requires = "opportunity",
  stopped = TRUE)
  m2 <- model
  m2$kpis <- list(withdrawal_equivalent = def)
  ch <- eng_run_chunk(m2, blocks = 1L, seed = NULL, mode = "deterministic", store = "kpi",
                      kpis = "withdrawal_equivalent")
  v <- as.double(ch$kpis$withdrawal_equivalent[1L])
  v_ex <- as.double((ch$kpis$withdrawal_equivalent_ex_rv %||% NA_real_)[1L])
  code <- as.character(ch$kpi_na$withdrawal_equivalent[1L])
  msg_txt <- if (is.na(v)) {
    lbl("mc.solve.withdrawal_none", code = code %||% "no_solution")
  } else {
    lbl("mc.solve.withdrawal_ok", value = v, value_ex_rv = v_ex)
  }
  sol <- slv_solution(what = "withdrawal_equivalent", param = NULL,
                      kpi = "withdrawal_equivalent", target = 0, target_source = "value",
                      value = v, kpi_at_value = v,
                      iterations = as.integer(acc$with_rv$iterations %||% NA_integer_),
                      interval = NULL, jump = FALSE, monotone = TRUE, reference = NULL,
                      rebuild = FALSE, prob_exceed = NA_real_, message = msg_txt)
  attr(sol, "value_ex_rv") <- v_ex
  sol
}

#' Rendite der Mehrinvestition (12.6, 12.8, R-68)
#' @noRd
slv_incremental <- function(x, variant, reference, interval, tol) {
  if (!inherits(x, "vofi_scenario")) {
    vofi_abort("mc.solve.needs_scenario", what = "incremental_return",
               .class = "vofi_error_input")
  }
  mv <- vofi_build(x, variant = variant)
  ref <- reference %||% mv$spec$project$reference_variant
  if (!utl_is_string(ref) || identical(ref, variant)) {
    vofi_abort("mc.solve.reference_missing", variant = variant, .class = "vofi_error_input")
  }
  mr <- vofi_build(x, variant = ref)
  interval <- interval %||% c(-0.02, 0.15)
  ir <- cmp_incremental_return(mv, mr, interval = interval, n_grid = 41L, tol = tol)
  r <- ir$with
  info <- attr(r, "solver")
  v <- as.double(r$values)
  at <- if (is.na(v)) NA_real_ else as.double(ir$g(v)[1L, 1L])
  sol <- slv_solution(what = "incremental_return", param = "accounts.deposit_rate_pa",
                      kpi = "delta_vs_reference", target = 0, target_source = "value",
                      value = v, kpi_at_value = at,
                      iterations = as.integer(info$iterations %||% 0L),
                      interval = info$interval %||% interval,
                      jump = FALSE, monotone = !is.na(v), reference = ref, rebuild = FALSE,
                      prob_exceed = NA_real_,
                      message = if (is.na(v)) lbl("mc.solve.incremental_none") else
                        lbl("mc.solve.incremental_ok", value = v,
                            value_ex_rv = as.double(ir$ex_rv$values)))
  attr(sol, "value_ex_rv") <- as.double(ir$ex_rv$values)
  attr(sol, "solver") <- info
  sol
}

# ---------------------------------------------------------------------------------------------
# Break-even und kritische Werte (12.8, R-75)
# ---------------------------------------------------------------------------------------------

#' Auswertung der Kennzahl über Schicht 8 (neues Modell je Wert, `rebuild`)
#' @noRd
slv_eval_rebuild <- function(src, variant, ref, kpi, param, xs, extra) {
  ref_paths <- character(0)
  if (!is.null(ref)) {
    ref_spec <- vofi_build(src, variant = ref)$spec
    paths <- c(param, names(extra))
    ref_paths <- paths[vapply(paths, function(p) !is.null(path_get(ref_spec, p)), logical(1))]
  }
  vapply(xs, function(z) {
    ov <- c(stats::setNames(list(z), param), extra)
    mv <- vofi_build(src, variant = variant, overrides = ov)
    mr <- NULL
    if (!is.null(ref)) {
      ov_r <- ov[names(ov) %in% ref_paths]
      mr <- vofi_build(src, variant = ref, overrides = if (length(ov_r) > 0L) ov_r else NULL)
    }
    setup <- sens_setup_models(mv, mr, kpi)
    sens_eval(setup, data.frame(row.names = 1L))[1L]
  }, double(1))
}

#' Allgemeine Zielwertsuche (12.8)
#' @noRd
slv_target_search <- function(x, what, param, kpi, target, interval, tol, variant, reference,
                              rebuild) {
  if (!utl_is_string(param)) {
    vofi_abort("mc.solve.param_missing", what = what, .class = "vofi_error_input")
  }
  model <- slv_model(x, variant)
  kpi <- kpi %||% kpi_primary(model$spec)$kpi
  if (!utl_is_string(kpi)) {
    vofi_abort("mc.arg_character", arg = "kpi", .class = "vofi_error_input")
  }
  tg <- slv_target(target, model$spec)
  notes <- character(0)
  extra <- list()
  # Zielrenditemiete im Bestand ohne Bestandswert (Teil C 6.5)
  if (identical(kpi_base_name(kpi), "roe_mirr")) {
    det <- slv_realized(model)
    ch <- eng_run_chunk(det, blocks = 1L, seed = NULL, mode = "deterministic", store = "kpi",
                        kpis = "roe_mirr")
    if (identical(as.character(ch$kpi_na$roe_mirr[1L]), "no_existing_value")) {
      extra[["accounts.deposit_rate_pa"]] <- tg$value
      kpi <- "delta_vs_reference"
      notes <- c(notes, lbl("mc.solve.hurdle_switch", value = tg$value))
      vofi_inform("mc.solve.hurdle_switch", value = tg$value)
      tg <- list(value = 0, source = tg$source)
    }
  }
  compare <- kpi_base_name(kpi) %in% sens_compare_kpis()
  ref <- NULL
  ref_model <- NULL
  if (compare) {
    if (!inherits(x, "vofi_scenario")) {
      vofi_abort("mc.solve.needs_scenario", what = kpi, .class = "vofi_error_input")
    }
    ref <- reference %||% model$spec$project$reference_variant
    if (!utl_is_string(ref) || identical(ref, variant)) {
      vofi_abort("mc.solve.reference_missing", variant = variant, .class = "vofi_error_input")
    }
    ref_model <- vofi_build(x, variant = ref)
  }
  setup <- sens_setup_models(model, ref_model, kpi)
  use_design <- !rebuild && slv_numeric_leaf(model$spec, param)
  base <- sens_base_value(model$sampler, param)
  if (is.na(base)) base <- as.double(cmp_spec_num(model$spec, param))
  entry <- slv_overlay_entry(model$sampler, param)
  interval <- interval %||% slv_default_interval(entry, base)
  src <- if (inherits(x, "vofi_scenario")) x else model$spec
  f <- function(xs) {
    if (use_design) {
      d <- data.frame(xs, check.names = FALSE)
      names(d) <- param
      for (nm in names(extra)) d[[nm]] <- rep(extra[[nm]], length(xs))
      sens_eval(setup, d)
    } else {
      slv_eval_rebuild(src, variant, ref, kpi, param, xs, extra)
    }
  }
  grid <- seq(interval[1L], interval[2L], length.out = 11L)
  fv <- f(grid) - tg$value
  ok <- !is.na(fv)
  out <- list(what = what, param = param, kpi = kpi, target = tg$value,
              target_source = tg$source, value = NA_real_, kpi_at_value = NA_real_,
              iterations = 0L, interval = interval, jump = FALSE, monotone = TRUE,
              reference = ref, rebuild = !use_design, prob_exceed = NA_real_,
              message = NA_character_)
  if (sum(ok) < 2L) {
    out$message <- utl_collapse(c(lbl("mc.solve.no_root"), notes), sep = " ")
    return(do.call(slv_solution, out))
  }
  xo <- grid[ok]
  yo <- fv[ok]
  out$monotone <- all(diff(yo) >= 0) || all(diff(yo) <= 0)
  zero <- which(yo == 0)
  s <- sign(yo)
  ch_idx <- which(s[-length(s)] * s[-1L] < 0)
  if (length(ch_idx) > 1L) out$monotone <- FALSE
  if (length(zero) == 0L && length(ch_idx) == 0L) {
    out$message <- utl_collapse(c(lbl("mc.solve.no_root"), notes), sep = " ")
    return(do.call(slv_solution, out))
  }
  first_zero <- if (length(zero) > 0L) zero[1L] else Inf
  first_ch <- if (length(ch_idx) > 0L) ch_idx[1L] else Inf
  if (first_zero <= first_ch) {
    root <- xo[first_zero]
    iter <- 0L
  } else {
    lo <- xo[first_ch]
    hi <- xo[first_ch + 1L]
    ur <- tryCatch({
      stats::uniroot(function(z) f(z) - tg$value, lower = lo, upper = hi,
                     f.lower = yo[first_ch], f.upper = yo[first_ch + 1L],
                     tol = tol * max(1, abs(lo), abs(hi)), maxiter = 200L)
    }, error = function(e) NULL)
    if (is.null(ur)) {
      out$message <- utl_collapse(c(lbl("mc.solve.root_failed"), notes), sep = " ")
      return(do.call(slv_solution, out))
    }
    root <- ur$root
    iter <- as.integer(ur$iter)
  }
  y_star <- f(root)
  out$value <- root
  out$kpi_at_value <- y_star
  out$iterations <- iter
  out$jump <- isTRUE(abs(y_star - tg$value) > slv_jump_tol(kpi))
  if (!is.null(entry)) {
    xr <- switch(entry$apply %||% "replace", multiply = if (base != 0) root / base else NA,
                 add = root - base, root)
    if (identical(entry$apply, "multiply") && isTRUE(base < 0)) {
      out$prob_exceed <- mc_cdf(entry$dist, entry$par, xr)
    } else {
      out$prob_exceed <- 1 - mc_cdf(entry$dist, entry$par, xr)
    }
  }
  msgs <- c(lbl("mc.solve.found", value = root, kpi = kpi, target = tg$value),
            if (out$jump) lbl("mc.solve.jump"),
            if (!out$monotone) lbl("mc.solve.not_monotone", param = param),
            notes)
  out$message <- utl_collapse(msgs, sep = " ")
  do.call(slv_solution, out)
}

# ---------------------------------------------------------------------------------------------
# Ausgabe (13.6, WS-G)
# ---------------------------------------------------------------------------------------------

#' Ergebnis der Zielwertsuche ausgeben
#'
#' Gibt Art der Suche, Parameter, Kennzahl, Ziel, Ergebnis, Kennzahl am Ergebnis, Intervall,
#' Iterationen, Monotonie, Sprungstelle, Überschreitungswahrscheinlichkeit und Hinweis im
#' deutschen Zahlenformat aus (Spec 00, Abschnitt 13.6).
#'
#' @param x Objekt der Klasse `vofi_solution`.
#' @param ... nicht verwendet.
#' @return `invisible(x)`.
#' @family Analysieren
#' @examples
#' sol <- vofi:::new_vofi_solution(list(what = "breakeven", param = "shared.rw",
#'                                      kpi = "delta_terminal_value", value = 36273.59,
#'                                      kpi_at_value = 0, interval = c(30000, 50000)))
#' print(sol)
#' @export
print.vofi_solution <- function(x, ...) {
  what <- switch(x$what %||% "breakeven",
    breakeven = lbl("mc.solve.print.what_breakeven"),
    critical_value = lbl("mc.solve.print.what_critical_value"),
    withdrawal_equivalent = lbl("mc.solve.print.what_withdrawal_equivalent"),
    incremental_return = lbl("mc.solve.print.what_incremental_return"),
    as.character(x$what)
  )
  num <- function(v, d = 4) {
    if (is.null(v) || length(v) == 0L || is.na(v[1L])) "n. d." else fmt_num(v[1L], d)
  }
  cat(lbl("mc.solve.print.header", what = what), "\n", sep = "")
  if (!is.null(x$param)) cat(lbl("mc.solve.print.param", param = x$param), "\n", sep = "")
  if (!is.null(x$kpi)) {
    cat(lbl("mc.solve.print.kpi", kpi = kpi_label(x$kpi), target = num(x$target),
            source = x$target_source %||% "value"), "\n", sep = "")
  }
  if (!is.null(x$reference)) {
    cat(lbl("mc.solve.print.reference", reference = x$reference), "\n", sep = "")
  }
  cat(lbl("mc.solve.print.value", value = num(x$value), at = num(x$kpi_at_value)), "\n",
      sep = "")
  if (!is.null(x$interval) && length(x$interval) == 2L) {
    cat(lbl("mc.solve.print.interval", lo = num(x$interval[1L]), hi = num(x$interval[2L]),
            iter = as.character(x$iterations %||% NA_integer_)), "\n", sep = "")
  }
  flags <- c(if (isFALSE(x$monotone)) lbl("mc.solve.print.not_monotone"),
             if (isTRUE(x$jump)) lbl("mc.solve.print.jump"),
             if (isTRUE(x$rebuild)) lbl("mc.solve.print.rebuild"))
  if (length(flags) > 0L) cat(utl_collapse(flags, sep = "; "), "\n", sep = "")
  if (!is.null(x$prob_exceed) && !is.na(x$prob_exceed)) {
    cat(lbl("mc.solve.print.prob_exceed", prob = fmt_pct(x$prob_exceed, 2)), "\n", sep = "")
  }
  if (!is.null(x$message) && !is.na(x$message)) cat(x$message, "\n", sep = "")
  invisible(x)
}
