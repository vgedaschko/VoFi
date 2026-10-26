# Verteilungstyp beta (WS-C; Spec 00 Abschnitt 5.3, Spec 01 Teil C 1.4.8).
# Beta-Verteilung auf dem Intervall von min bis max (Default 0 bis 1) in der Form (a) mit
# shape1 und shape2 oder (b) mit mean und sd.

#' Kanonische Parameter der Beta-Verteilung
#'
#' Form b: μ' = (mean − min)/(max − min), v' = sd²/(max − min)², k = μ'(1 − μ')/v' − 1,
#' α = μ' k, β = (1 − μ') k.
#' @return Liste `shape1`, `shape2`, `min`, `max`, `form`, `error` (Code oder `NA`).
#' @noRd
dist_beta_canon <- function(par) {
  given <- function(f) !is.null(par[[f]])
  fa <- c("shape1", "shape2")
  fb <- c("mean", "sd")
  pa <- any(vapply(fa, given, logical(1)))
  pb <- any(vapply(fb, given, logical(1)))
  lo <- dist_num(par, "min", 0)
  hi <- dist_num(par, "max", 1)
  out <- list(shape1 = NA_real_, shape2 = NA_real_, min = lo, max = hi, form = NA_character_,
              error = NA_character_)
  if (pa && pb) {
    out$error <- "forms_multiple"
    return(out)
  }
  ca <- all(vapply(fa, given, logical(1)))
  cb <- all(vapply(fb, given, logical(1)))
  if (!ca && !cb) {
    out$error <- "form_missing"
    return(out)
  }
  if (!(length(lo) == 1L && length(hi) == 1L && is.finite(lo) && is.finite(hi))) {
    out$error <- "bounds_invalid"
    return(out)
  }
  if (!(lo < hi)) {
    out$error <- "bounds_order"
    return(out)
  }
  if (ca) {
    out$form <- "a"
    s1 <- dist_num(par, "shape1")
    s2 <- dist_num(par, "shape2")
    if (!dist_is_finite(par, "shape1") || !dist_is_finite(par, "shape2") || !(s1 > 0) ||
          !(s2 > 0)) {
      out$error <- "shape_invalid"
      return(out)
    }
    out$shape1 <- s1
    out$shape2 <- s2
    return(out)
  }
  out$form <- "b"
  m <- dist_num(par, "mean")
  s <- dist_num(par, "sd")
  if (!dist_is_finite(par, "mean") || !(m > lo && m < hi)) {
    out$error <- "mean_range"
    return(out)
  }
  if (!dist_is_finite(par, "sd") || !(s > 0) || !(s^2 < (m - lo) * (hi - m))) {
    out$error <- "sd_range"
    return(out)
  }
  mu <- (m - lo) / (hi - lo)
  v <- s^2 / (hi - lo)^2
  k <- mu * (1 - mu) / v - 1
  out$shape1 <- mu * k
  out$shape2 <- (1 - mu) * k
  out
}

#' Kanonische Parameter oder Fehler
#' @noRd
dist_beta_par <- function(par) {
  p <- dist_beta_canon(par)
  if (!is.na(p$error)) {
    vofi_abort("sampling.dist_invalid", entry = "beta", details = dist_msg("beta", p$error),
               .class = "vofi_error_input")
  }
  p
}

#' Quantilfunktion der Beta-Verteilung auf [min, max]
#' @noRd
dist_beta_q <- function(u, par) {
  p <- dist_beta_par(par)
  pmin(pmax(p$min + (p$max - p$min) * stats::qbeta(u, p$shape1, p$shape2), p$min), p$max)
}

#' Modus der Beta-Verteilung (Spec 01 Teil C 1.4.8)
#'
#' α, β > 1: min + (max − min)(α − 1)/(α + β − 2); α = β = 1: Mitte; sonst der Rand mit der
#' unbeschränkten Dichte (α ≤ 1 < β: min; β ≤ 1 < α: max; beide ≤ 1: kleinerer Formparameter).
#' @noRd
dist_beta_mode <- function(p) {
  a <- p$shape1
  b <- p$shape2
  w <- p$max - p$min
  if (a > 1 && b > 1) return(p$min + w * (a - 1) / (a + b - 2))
  if (a == 1 && b == 1) return(p$min + w / 2)
  if (a <= 1 && b > 1) return(p$min)
  if (b <= 1 && a > 1) return(p$max)
  if (a <= b) p$min else p$max
}

#' Verteilung `beta`
#'
#' Q(u) = min + (max − min) qbeta(u, α, β); Mittelwert min + (max − min) α/(α + β), Varianz
#' (max − min)² αβ/((α + β)²(α + β + 1)).
#' @return `vofi_typedef` der Art `distribution`.
#' @noRd
typedef_dist_beta <- function() {
  vofi_type(
    name = "beta", kind = "distribution",
    params = list(shape1 = vofi_param("number", min = 0), shape2 = vofi_param("number", min = 0),
                  mean = vofi_param("number"), sd = vofi_param("number", min = 0),
                  min = vofi_param("number", default = 0),
                  max = vofi_param("number", default = 1)),
    quantile = function(u, par) dist_beta_q(u, par),
    point = function(par, which = c("mode", "median", "mean")) {
      which <- dist_which(which)
      p <- dist_beta_par(par)
      switch(which,
        mode = dist_beta_mode(p),
        median = dist_beta_q(0.5, par),
        mean = p$min + (p$max - p$min) * p$shape1 / (p$shape1 + p$shape2)
      )
    },
    moments = function(par) {
      p <- dist_beta_par(par)
      a <- p$shape1
      b <- p$shape2
      w <- p$max - p$min
      list(mean = p$min + w * a / (a + b), var = w^2 * a * b / ((a + b)^2 * (a + b + 1)))
    },
    validate = function(par) {
      p <- dist_beta_canon(par)
      if (is.na(p$error)) character(0) else dist_msg("beta", p$error)
    },
    example = list(mean = 0.08, sd = 0.05)
  )
}
