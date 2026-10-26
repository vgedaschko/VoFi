# Verteilungstyp bernoulli (WS-C; Spec 00 Abschnitt 5.3, R-93; Spec 01 Teil C 1.4.9).
# Q(u) = 1{u > 1 - p} (monoton nicht fallend); Förderzusagen und Entscheidungsschlüssel.

#' Quantilfunktion der Bernoulli-Verteilung: 1{u > 1 − p}
#' @noRd
dist_bernoulli_q <- function(u, par) as.double(u > 1 - dist_num(par, "p"))

#' Verteilung `bernoulli`
#'
#' Q(u) = 1{u > 1 − p}; Mittelwert p, Varianz p(1 − p), Modus 1{p ≥ 0,5}, Median
#' Q(0,5) = 1{p > 0,5}. Mit LHS enthält jeder Block genau ⌊p m⌋ oder ⌈p m⌉ Einsen.
#' @return `vofi_typedef` der Art `distribution`.
#' @noRd
typedef_dist_bernoulli <- function() {
  vofi_type(
    name = "bernoulli", kind = "distribution",
    params = list(p = vofi_param("share", required = TRUE)),
    quantile = function(u, par) dist_bernoulli_q(u, par),
    point = function(par, which = c("mode", "median", "mean")) {
      which <- dist_which(which)
      p <- dist_num(par, "p")
      switch(which,
        mode = as.double(p >= 0.5),
        median = dist_bernoulli_q(0.5, par),
        mean = p
      )
    },
    moments = function(par) {
      p <- dist_num(par, "p")
      list(mean = p, var = p * (1 - p))
    },
    validate = function(par) {
      if (dist_is_finite(par, "p") && dist_num(par, "p") >= 0 && dist_num(par, "p") <= 1) {
        return(character(0))
      }
      dist_msg("bernoulli", "p_invalid", value = dist_fmt(par[["p"]]))
    },
    example = list(p = 0.85)
  )
}
