# Verteilungstyp uniform (WS-C; Spec 00 Abschnitt 5.3, Spec 01 Teil C 1.4.5).
# Q(u) = min + (max - min) u; min = max ist zulässig (konstanter Wert).

#' Verteilung `uniform`
#'
#' Q(u) = a + (b − a) u; Modus := Median := Mittelwert = (a + b)/2, Varianz (b − a)²/12.
#' @return `vofi_typedef` der Art `distribution`.
#' @noRd
typedef_dist_uniform <- function() {
  vofi_type(
    name = "uniform", kind = "distribution",
    params = list(min = vofi_param("number", required = TRUE),
                  max = vofi_param("number", required = TRUE)),
    quantile = function(u, par) {
      a <- dist_num(par, "min")
      b <- dist_num(par, "max")
      if (a == b) return(rep(a, length(u)))
      pmin(pmax(a + (b - a) * u, a), b)
    },
    point = function(par, which = c("mode", "median", "mean")) {
      dist_which(which)
      (dist_num(par, "min") + dist_num(par, "max")) / 2
    },
    moments = function(par) {
      a <- dist_num(par, "min")
      b <- dist_num(par, "max")
      list(mean = (a + b) / 2, var = (b - a)^2 / 12)
    },
    validate = function(par) {
      out <- dist_out(
        if (!dist_is_finite(par, "min")) dist_msg("uniform", "min_invalid"),
        if (!dist_is_finite(par, "max")) dist_msg("uniform", "max_invalid")
      )
      if (length(out) > 0L) return(out)
      if (dist_num(par, "min") > dist_num(par, "max")) {
        return(dist_msg("uniform", "order", min = dist_num(par, "min"),
                        max = dist_num(par, "max")))
      }
      character(0)
    },
    example = list(min = 0, max = 0.3)
  )
}
