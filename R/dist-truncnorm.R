# Verteilungstyp truncnorm (WS-C; Spec 00 Abschnitt 5.3, Spec 01 Teil C 1.4.3).
# Normalverteilung N(mean, sd) auf [lower, upper]; Aliase min/max (Hinweis beim Planen).

#' Parameter der gestutzten Normalverteilung
#'
#' Liest `mean`, `sd`, `lower` (Alias `min`, Default `-Inf`) und `upper` (Alias `max`, Default
#' `Inf`) und berechnet α = (a − μ)/σ, β = (b − μ)/σ sowie die Masse Z = Φ(β) − Φ(α).
#' @param par Verteilungsparameter.
#' @return Liste `mu`, `sd`, `a`, `b`, `alpha`, `beta`, `z`.
#' @noRd
dist_truncnorm_par <- function(par) {
  mu <- dist_num(par, "mean")
  s <- dist_num(par, "sd")
  a <- dist_num(par, "lower", dist_num(par, "min", -Inf))
  b <- dist_num(par, "upper", dist_num(par, "max", Inf))
  out <- list(mu = mu, sd = s, a = a, b = b, alpha = NA_real_, beta = NA_real_, z = NA_real_)
  if (length(s) == 1L && is.finite(s) && s > 0) {
    out$alpha <- (a - mu) / s
    out$beta <- (b - mu) / s
    # Masse über die günstigere Flanke (Genauigkeit in den Rändern)
    out$z <- if (out$alpha > 0) {
      stats::pnorm(out$alpha, lower.tail = FALSE) - stats::pnorm(out$beta, lower.tail = FALSE)
    } else {
      stats::pnorm(out$beta) - stats::pnorm(out$alpha)
    }
  }
  out
}

#' x * φ(x) mit dem Grenzwert 0 für x = ±Inf
#' @noRd
dist_x_dnorm <- function(x) if (is.finite(x)) x * stats::dnorm(x) else 0

#' Quantilfunktion der gestutzten Normalverteilung
#' @noRd
dist_truncnorm_q <- function(u, par) {
  p <- dist_truncnorm_par(par)
  clamp <- min(max(p$mu, p$a), p$b)
  if (p$sd == 0) return(rep(clamp, length(u)))
  if (stats::pnorm(p$alpha) > 0.5) {
    qa <- stats::pnorm(p$alpha, lower.tail = FALSE)
    qb <- stats::pnorm(p$beta, lower.tail = FALSE)
    x <- p$mu - p$sd * stats::qnorm(qa - u * (qa - qb))
  } else {
    pa <- stats::pnorm(p$alpha)
    x <- p$mu + p$sd * stats::qnorm(pa + u * p$z)
  }
  pmin(pmax(x, p$a), p$b)
}

#' Verteilung `truncnorm`
#'
#' Q(u) = μ + σ Φ⁻¹(Φ(α) + u Z), für Φ(α) > 0,5 numerisch über die obere Flanke
#' Q(u) = μ − σ Φ⁻¹(Φ(−α) − u (Φ(−α) − Φ(−β))); das Ergebnis wird auf [a, b] begrenzt (monoton).
#' Mittelwert μ + σ (φ(α) − φ(β))/Z, Varianz σ² [1 + (α φ(α) − β φ(β))/Z − ((φ(α) − φ(β))/Z)²],
#' Modus min(max(μ, a), b). σ = 0 ergibt den konstanten Wert min(max(μ, a), b).
#' @return `vofi_typedef` der Art `distribution`.
#' @noRd
typedef_dist_truncnorm <- function() {
  vofi_type(
    name = "truncnorm", kind = "distribution",
    params = list(mean = vofi_param("number", required = TRUE),
                  sd = vofi_param("number", required = TRUE, min = 0),
                  lower = vofi_param("number", default = -Inf),
                  upper = vofi_param("number", default = Inf)),
    quantile = function(u, par) dist_truncnorm_q(u, par),
    point = function(par, which = c("mode", "median", "mean")) {
      which <- dist_which(which)
      p <- dist_truncnorm_par(par)
      switch(which,
        mode = min(max(p$mu, p$a), p$b),
        median = dist_truncnorm_q(0.5, par),
        mean = dist_truncnorm_moments(p)$mean
      )
    },
    moments = function(par) dist_truncnorm_moments(dist_truncnorm_par(par)),
    validate = function(par) {
      bounds_num <- all(vapply(c("lower", "upper", "min", "max"), function(f) {
        is.null(par[[f]]) || (is.numeric(dist_num(par, f)) && length(dist_num(par, f)) == 1L &&
                                !is.na(dist_num(par, f)))
      }, logical(1)))
      out <- dist_out(
        if (!dist_is_finite(par, "mean")) dist_msg("truncnorm", "mean_invalid"),
        if (!dist_is_finite(par, "sd") || dist_num(par, "sd") < 0) {
          dist_msg("truncnorm", "sd_invalid")
        },
        if (!bounds_num) dist_msg("truncnorm", "bounds_invalid")
      )
      if (length(out) > 0L) return(out)
      p <- dist_truncnorm_par(par)
      if (!(p$a < p$b)) return(dist_msg("truncnorm", "bounds_order", lower = p$a, upper = p$b))
      if (p$sd > 0 && !(p$z > 1e-12)) return(dist_msg("truncnorm", "mass_zero"))
      character(0)
    },
    example = list(mean = 0.0275, sd = 0.0075, lower = 0.01, upper = 0.05)
  )
}

#' Momente der gestutzten Normalverteilung
#' @param p Ergebnis von `dist_truncnorm_par()`.
#' @noRd
dist_truncnorm_moments <- function(p) {
  if (p$sd == 0) return(list(mean = min(max(p$mu, p$a), p$b), var = 0))
  da <- stats::dnorm(p$alpha)
  db <- stats::dnorm(p$beta)
  r <- (da - db) / p$z
  v <- p$sd^2 * (1 + (dist_x_dnorm(p$alpha) - dist_x_dnorm(p$beta)) / p$z - r^2)
  list(mean = p$mu + p$sd * r, var = max(v, 0))
}
