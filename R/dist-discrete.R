# Verteilungstyp discrete (WS-C; Spec 00 Abschnitt 5.3, Spec 01 Teil C 1.4.10).
# Endliche Verteilung über values mit probs (Default gleich verteilt).

#' Sortierte Ausprägungen und kumulierte Wahrscheinlichkeiten
#'
#' (values, probs) werden nach `values` aufsteigend sortiert (`order(method = "radix")`), die
#' kumulierte Summe P erhält P_K := 1 exakt.
#' @return Liste `values`, `probs`, `cum`.
#' @noRd
dist_discrete_par <- function(par) {
  v <- dist_num(par, "values")
  k <- length(v)
  p <- dist_num(par, "probs", rep(1 / max(k, 1L), k))
  o <- order(v, method = "radix")
  v <- v[o]
  p <- p[o]
  cp <- cumsum(p)
  if (k > 0L) cp[k] <- 1
  list(values = v, probs = p, cum = cp)
}

#' Quantilfunktion der diskreten Verteilung
#'
#' Q(u) = v_k mit k = min{k : P_k ≥ u} (`findInterval(u, P, left.open = TRUE) + 1`).
#' @noRd
dist_discrete_q <- function(u, par) {
  p <- dist_discrete_par(par)
  k <- length(p$values)
  idx <- findInterval(u, p$cum, left.open = TRUE) + 1L
  p$values[pmin(pmax(idx, 1L), k)]
}

#' Verteilung `discrete`
#'
#' Mittelwert Σ p_k v_k; Modus = Wert mit der größten Wahrscheinlichkeit (Gleichstand: kleinster
#' Wert); Median Q(0,5).
#' @return `vofi_typedef` der Art `distribution`.
#' @noRd
typedef_dist_discrete <- function() {
  vofi_type(
    name = "discrete", kind = "distribution",
    params = list(values = vofi_param("number", required = TRUE, vector = TRUE),
                  probs = vofi_param("number", vector = TRUE)),
    quantile = function(u, par) dist_discrete_q(u, par),
    point = function(par, which = c("mode", "median", "mean")) {
      which <- dist_which(which)
      p <- dist_discrete_par(par)
      switch(which,
        mode = p$values[which.max(p$probs)],
        median = dist_discrete_q(0.5, par),
        mean = sum(p$probs * p$values)
      )
    },
    moments = function(par) {
      p <- dist_discrete_par(par)
      m <- sum(p$probs * p$values)
      list(mean = m, var = max(sum(p$probs * (p$values - m)^2), 0))
    },
    validate = function(par) {
      v <- dist_num(par, "values")
      if (length(v) == 0L || anyNA(v) || !all(is.finite(v))) {
        return(dist_msg("discrete", "values_invalid"))
      }
      if (anyDuplicated(v)) return(dist_msg("discrete", "values_duplicate"))
      if (is.null(par[["probs"]])) return(character(0))
      p <- dist_num(par, "probs")
      if (length(p) != length(v)) {
        return(dist_msg("discrete", "probs_length", n_values = length(v), n_probs = length(p)))
      }
      if (anyNA(p) || any(p < 0)) return(dist_msg("discrete", "probs_negative"))
      if (abs(sum(p) - 1) > 1e-9) return(dist_msg("discrete", "probs_sum", sum = sum(p)))
      character(0)
    },
    example = list(values = c(0, 12, 24, 36, 48, 60))
  )
}
