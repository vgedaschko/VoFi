# Verteilungstyp triangular (WS-C; Spec 00 Abschnitt 5.3, Spec 01 Teil C 1.4.6).
# Dreiecksverteilung (min, mode, max); min = max ergibt den konstanten Wert.

#' Quantilfunktion der Dreiecksverteilung
#'
#' F_c = (c − a)/(b − a); Q(u) = a + √(u (b − a)(c − a)) für u < F_c, sonst
#' b − √((1 − u)(b − a)(b − c)); a = b ergibt Q ≡ a. Beide Zweige sind für u ∈ [0, 1] endlich und
#' werden über eine Maske zusammengesetzt (monoton nicht fallend).
#' @noRd
dist_triangular_q <- function(u, par) {
  a <- dist_num(par, "min")
  c0 <- dist_num(par, "mode")
  b <- dist_num(par, "max")
  if (a == b) return(rep(a, length(u)))
  u <- pmin(pmax(u, 0), 1)
  fc <- (c0 - a) / (b - a)
  lo <- a + sqrt(u * (b - a) * (c0 - a))
  out <- b - sqrt((1 - u) * (b - a) * (b - c0))
  m <- u < fc
  out[m] <- lo[m]
  pmin(pmax(out, a), b)
}

#' Verteilung `triangular`
#'
#' Mittelwert (a + b + c)/3, Varianz (a² + b² + c² − ab − ac − bc)/18, Modus c.
#' @return `vofi_typedef` der Art `distribution`.
#' @noRd
typedef_dist_triangular <- function() {
  vofi_type(
    name = "triangular", kind = "distribution",
    params = list(min = vofi_param("number", required = TRUE),
                  mode = vofi_param("number", required = TRUE),
                  max = vofi_param("number", required = TRUE)),
    quantile = function(u, par) dist_triangular_q(u, par),
    point = function(par, which = c("mode", "median", "mean")) {
      which <- dist_which(which)
      switch(which,
        mode = dist_num(par, "mode"),
        median = dist_triangular_q(0.5, par),
        mean = (dist_num(par, "min") + dist_num(par, "mode") + dist_num(par, "max")) / 3
      )
    },
    moments = function(par) {
      a <- dist_num(par, "min")
      c0 <- dist_num(par, "mode")
      b <- dist_num(par, "max")
      list(mean = (a + b + c0) / 3,
           var = max((a^2 + b^2 + c0^2 - a * b - a * c0 - b * c0) / 18, 0))
    },
    validate = function(par) dist_validate_three("triangular", par),
    example = list(min = 2.6, mode = 2.9, max = 3.3)
  )
}
