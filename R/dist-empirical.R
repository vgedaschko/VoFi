# Verteilungstyp empirical (WS-C; Spec 00 Abschnitt 5.3, R-93; Spec 01 Teil C 1.4.11).
# Quantilfunktion der Stichprobe nach stats::quantile(type = 7); Modus := Median.

#' Quantilfunktion der empirischen Verteilung
#'
#' Q(u) = `stats::quantile(data, u, type = 7)` (lineare Interpolation der Ordnungsstatistiken).
#' @noRd
dist_empirical_q <- function(u, par) {
  d <- dist_num(par, "data")
  stats::quantile(d, probs = pmin(pmax(u, 0), 1), type = 7, names = FALSE)
}

#' Momente der interpolierten Quantilfunktion
#'
#' Mit s_(1) ≤ … ≤ s_(n): Mittelwert (1/(n − 1)) Σ (s_(i) + s_(i+1))/2,
#' E[X²] = (1/(n − 1)) Σ (s_(i)² + s_(i) s_(i+1) + s_(i+1)²)/3.
#' @noRd
dist_empirical_moments <- function(par) {
  s <- sort(dist_num(par, "data"), method = "radix")
  n <- length(s)
  lo <- s[-n]
  hi <- s[-1L]
  m <- sum((lo + hi) / 2) / (n - 1)
  m2 <- sum((lo^2 + lo * hi + hi^2) / 3) / (n - 1)
  list(mean = m, var = max(m2 - m^2, 0))
}

#' Verteilung `empirical`
#'
#' Momente der Verteilung, die die Quantilfunktion erzeugt (nicht die Stichprobenmomente).
#' @return `vofi_typedef` der Art `distribution`.
#' @noRd
typedef_dist_empirical <- function() {
  vofi_type(
    name = "empirical", kind = "distribution",
    params = list(data = vofi_param("number", required = TRUE, vector = TRUE)),
    quantile = function(u, par) dist_empirical_q(u, par),
    point = function(par, which = c("mode", "median", "mean")) {
      which <- dist_which(which)
      switch(which,
        mode = dist_empirical_q(0.5, par),
        median = dist_empirical_q(0.5, par),
        mean = dist_empirical_moments(par)$mean
      )
    },
    moments = function(par) dist_empirical_moments(par),
    validate = function(par) {
      d <- dist_num(par, "data")
      if (length(d) < 2L || anyNA(d) || !all(is.finite(d))) {
        return(dist_msg("empirical", "data_invalid", n = length(d)))
      }
      character(0)
    },
    example = list(data = c(0.98, 1.02, 1.05, 1.08, 1.12, 1.20, 1.35))
  )
}
