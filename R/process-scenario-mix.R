# Prozesstyp scenario_mix (WS-C; Spec 00 Abschnitte 5.3, 11.7, R-93; Spec 01 Teil C 1.6.6).
# CO2-Korridore, Regulierungsszenarien: Szenario je Lauf aus einer Uniform (Strom scen:), optional
# multiplikatives AR(1)-Log-Rauschen wie mr_trend.

#' Szenarien in kanonischer Ordnung
#'
#' Namen alphabetisch (`sort(method = "radix")`), Gewichte, kumulierte Gewichte mit letztem Wert
#' := 1 und die Stützwertpfade je Jahr (lineare Interpolation, außerhalb konstant).
#' @param par Parameter mit `scenarios`.
#' @param years Kalenderjahre.
#' @return Liste `names`, `prob`, `cum`, `paths` (Matrix K × length(years)).
#' @noRd
proc_scenarios <- function(par, years) {
  sc <- par[["scenarios"]]
  nms <- utl_sort(names(sc))
  prob <- vapply(nms, function(s) as.double(unlist(sc[[s]][["prob"]]))[1L], numeric(1),
                 USE.NAMES = FALSE)
  cum <- cumsum(prob)
  cum[length(cum)] <- 1
  paths <- matrix(0, length(nms), length(years))
  for (i in seq_along(nms)) {
    paths[i, ] <- proc_interp(sc[[nms[i]]][["years"]], sc[[nms[i]]][["values"]], years)
  }
  list(names = nms, prob = prob, cum = cum, paths = paths)
}

#' Prozess `scenario_mix` simulieren
#'
#' Szenario S = min{k : P_k ≥ u} aus der ersten Uniform-Spalte; X_y = x^{(S)}_y exp(Y_y − v_y/2)
#' mit Y_1 = v_1 = 0, Y_y = φ Y_{y−1} + σ z_y (nur mit `noise`). Attribut `"scenario"` = S
#' (1-basiert in kanonischer Ordnung).
#' @param par Parameter `scenarios`, `noise` (`phi`, `sigma`; optional).
#' @param z Schocks oder `NULL` (ohne `noise`).
#' @param u n × 1 Uniforms des Szenarioindex.
#' @param years Kalenderjahre.
#' @param linked nicht verwendet (Attribut `"n"`).
#' @return Matrix n × length(years) mit Attribut `"scenario"`.
#' @noRd
proc_scenario_mix_simulate <- function(par, z, u, years, linked) {
  n <- proc_n(par, z, u, linked)
  y <- length(years)
  s <- proc_scenarios(par, years)
  uu <- if (is.null(u)) rep(0.5, n) else as.double(as.matrix(u)[, 1L])
  idx <- findInterval(uu, s$cum, left.open = TRUE) + 1L
  idx <- pmin(pmax(idx, 1L), length(s$names))
  out <- s$paths[idx, , drop = FALSE]
  noise <- par[["noise"]]
  if (!is.null(noise)) {
    phi <- proc_vec(noise, "phi", n, default = 0)
    sigma <- proc_vec(noise, "sigma", n, default = 0)
    z <- proc_z(z, n, y)
    dev <- rep(0, n)
    v <- rep(0, n)
    ex <- matrix(0, n, y)
    for (k in seq_len(y - 1L)) {
      dev <- phi * dev + sigma * z[, k]
      v <- phi^2 * v + sigma^2
      ex[, k + 1L] <- dev - v / 2
    }
    out[, -1L] <- out[, -1L, drop = FALSE] * exp(ex[, -1L, drop = FALSE])
  }
  dimnames(out) <- NULL
  attr(out, "scenario") <- as.integer(idx)
  out
}

#' Quantilpfad von `scenario_mix` (Spec 01 Teil C 4.3 Nr. 1 c)
#'
#' Ohne Rauschen (bzw. mit v_y = 0) je Jahr der Wert x^{(k*)}_y mit den Szenarien je Jahr nach
#' ihrem Wert sortiert und k* = min{k : P_k ≥ p − 1e-12}; mit Rauschen die Nullstelle von
#' Σ_k p_k Φ((ln(x/x^{(k)}_y) + v_y/2)/√v_y) = p (`stats::uniroot`, Toleranz 1e-10).
#' @noRd
proc_scenario_mix_quantile <- function(par, years, p) {
  s <- proc_scenarios(par, years)
  y <- length(years)
  noise <- par[["noise"]]
  k <- seq_len(y) - 1L
  v <- if (is.null(noise)) rep(0, y) else
    proc_point(noise, "sigma", default = 0)^2 * proc_geo2(proc_point(noise, "phi", default = 0), k)
  out <- numeric(y)
  for (j in seq_len(y)) {
    x <- s$paths[, j]
    o <- order(x, method = "radix")
    if (v[j] <= 0) {
      cw <- cumsum(s$prob[o])
      kk <- which(cw >= p - 1e-12)
      out[j] <- x[o][if (length(kk) > 0L) kk[1L] else length(o)]
      next
    }
    keep <- s$prob > 0
    xs <- x[keep]
    ws <- s$prob[keep]
    sd <- sqrt(v[j])
    f <- function(q) sum(ws * stats::pnorm((log(q / xs) + v[j] / 2) / sd)) - p
    lo <- min(xs) * exp(-v[j] / 2 + stats::qnorm(min(p, 1 - 1e-15)) * sd) * 0.999
    hi <- max(xs) * exp(-v[j] / 2 + stats::qnorm(max(p, 1e-15)) * sd) * 1.001
    out[j] <- stats::uniroot(f, c(lo, hi), tol = 1e-10)$root
  }
  out
}

#' Felder der Map `noise` (AR(1)-Rauschen um den Szenariopfad)
#' @noRd
proc_scenario_mix_noise_fields <- function() {
  list(phi = vofi_param("number", default = 0, min = -1, max = 1),
       sigma = vofi_param("number", default = 0, min = 0))
}

#' Prozess `scenario_mix`
#'
#' Ausgabeart `level`; `n_uniforms` = 1 (Strom `scen:`), `n_shocks` = 1 genau dann, wenn `noise`
#' angegeben ist (nur strukturabhängig, R-93). `expected` = Σ_k p_k x^{(k)}_y.
#' @return `vofi_typedef` der Art `process`.
#' @noRd
typedef_process_scenario_mix <- function() {
  vofi_type(
    name = "scenario_mix", kind = "process", output = "level", linked = character(0),
    params = list(scenarios = vofi_param("value", required = TRUE, stochastic = FALSE,
                                         structure = "scenarios"),
                  noise = vofi_param("map", fields = proc_scenario_mix_noise_fields())),
    simulate = function(par, z, u, years, linked) {
      proc_scenario_mix_simulate(par, z, u, years, linked)
    },
    expected = function(par, years) {
      s <- proc_scenarios(par, years)
      as.double(crossprod(s$prob, s$paths))
    },
    n_shocks = function(par) as.integer(!is.null(par[["noise"]])),
    n_uniforms = function(par) 1L,
    quantile_path = function(par, years, p) proc_scenario_mix_quantile(par, years, p),
    validate = function(par) proc_scenario_mix_validate(par),
    example = list(
      scenarios = list(mittel = list(prob = 1, years = c(2027, 2030, 2040),
                                     values = c(55, 85, 140))),
      noise = list(phi = 0.5, sigma = 0.1)
    )
  )
}

#' Prüfung der Szenarien von `scenario_mix`
#' @return Zeichenvektor der Meldungen.
#' @noRd
proc_scenario_mix_validate <- function(par) {
  sc <- par[["scenarios"]]
  if (!is.list(sc) || length(sc) == 0L || is.null(names(sc))) {
    return(msg("sampling.process.scenarios_missing"))
  }
  out <- character(0)
  bad_names <- names(sc)[!grepl("^[a-z][a-z0-9_]*$", names(sc))]
  if (length(bad_names) > 0L) {
    out <- c(out, msg("sampling.process.scenario_name", name = utl_collapse(bad_names)))
  }
  probs <- numeric(0)
  for (s in names(sc)) {
    e <- sc[[s]]
    pr <- e[["prob"]]
    if (proc_is_dist(pr) || proc_is_dist(e[["values"]])) {
      out <- c(out, msg("sampling.process.dist_not_allowed", param = path_join("scenarios", s)))
      next
    }
    pr <- suppressWarnings(as.double(unlist(pr)))
    if (length(pr) != 1L || !is.finite(pr) || pr < 0) {
      out <- c(out, msg("sampling.process.prob_invalid", scenario = s))
    } else {
      probs <- c(probs, pr)
    }
    out <- c(out, proc_check_points(e[["years"]], e[["values"]], path_join("scenarios", s)))
  }
  if (length(probs) == length(sc) && abs(sum(probs) - 1) > 1e-9) {
    out <- c(out, msg("sampling.process.prob_sum", sum = sum(probs)))
  }
  noise <- par[["noise"]]
  if (!is.null(noise)) {
    if (!is.list(noise)) {
      out <- c(out, msg("sampling.process.param_finite", param = "noise",
                        value = utl_collapse(format(noise))))
    } else {
      out <- c(out, proc_check(noise, "phi", "abs_lt1", label = "noise.phi"),
               proc_check(noise, "sigma", "nonneg", label = "noise.sigma"))
    }
  }
  out
}
