# Verteilungstyp fixed (WS-C; Spec 00 Abschnitt 5.3, Spec 01 Teil C 1.4.1).
# Q(u) = value; Zweck: Entartungstests und Abschalten einzelner Unsicherheiten.

#' Verteilung `fixed` (konstanter Wert)
#'
#' Quantilfunktion Q(u) = `value`; Modus, Median und Mittelwert sind `value`, die Varianz 0.
#' @return `vofi_typedef` der Art `distribution`.
#' @noRd
typedef_dist_fixed <- function() {
  vofi_type(
    name = "fixed", kind = "distribution",
    params = list(value = vofi_param("number", required = TRUE)),
    quantile = function(u, par) {
      rep(dist_num(par, "value"), length(u))
    },
    point = function(par, which = c("mode", "median", "mean")) {
      dist_which(which)
      dist_num(par, "value")
    },
    moments = function(par) list(mean = dist_num(par, "value"), var = 0),
    validate = function(par) {
      if (dist_is_finite(par, "value")) character(0) else dist_msg("fixed", "value_invalid")
    },
    example = list(value = 3)
  )
}
