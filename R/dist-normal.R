# Verteilungstyp normal (WS-C; Spec 00 Abschnitt 5.3, Spec 01 Teil C 1.4.2).
# Q(u) = mean + sd * qnorm(u); sd = 0 ist zulässig (konstanter Wert).

#' Verteilung `normal`
#'
#' Quantilfunktion Q(u) = μ + σ Φ⁻¹(u); Modus = Median = Mittelwert = μ, Varianz σ². Bei σ = 0
#' liefert die Quantilfunktion den konstanten Wert μ (auch für u = 0 bzw. 1).
#' @return `vofi_typedef` der Art `distribution`.
#' @noRd
typedef_dist_normal <- function() {
  vofi_type(
    name = "normal", kind = "distribution",
    params = list(mean = vofi_param("number", required = TRUE),
                  sd = vofi_param("number", required = TRUE, min = 0)),
    quantile = function(u, par) {
      mu <- dist_num(par, "mean")
      s <- dist_num(par, "sd")
      if (s == 0) return(rep(mu, length(u)))
      mu + s * stats::qnorm(u)
    },
    point = function(par, which = c("mode", "median", "mean")) {
      dist_which(which)
      dist_num(par, "mean")
    },
    moments = function(par) list(mean = dist_num(par, "mean"), var = dist_num(par, "sd")^2),
    validate = function(par) {
      dist_out(
        if (!dist_is_finite(par, "mean")) dist_msg("normal", "mean_invalid"),
        if (!dist_is_finite(par, "sd") || dist_num(par, "sd") < 0) {
          dist_msg("normal", "sd_invalid")
        }
      )
    },
    example = list(mean = 0, sd = 0.004)
  )
}
