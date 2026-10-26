# Verteilungstyp pert (WS-C; Spec 00 Abschnitt 5.3, Spec 01 Teil C 1.4.7).
# Standard für Expertenschätzungen: Beta-Verteilung auf [min, max] mit Modus mode und
# Formparameter lambda (Default 4).

#' Formparameter der PERT-Verteilung
#'
#' α = 1 + λ (c − a)/(b − a), β = 1 + λ (b − c)/(b − a).
#' @return Liste `a`, `c`, `b`, `lambda`, `alpha`, `beta`.
#' @noRd
dist_pert_par <- function(par) {
  a <- dist_num(par, "min")
  c0 <- dist_num(par, "mode")
  b <- dist_num(par, "max")
  lam <- dist_num(par, "lambda", 4)
  w <- b - a
  list(a = a, c = c0, b = b, lambda = lam,
       alpha = if (w > 0) 1 + lam * (c0 - a) / w else NA_real_,
       beta = if (w > 0) 1 + lam * (b - c0) / w else NA_real_)
}

#' Quantilfunktion der PERT-Verteilung
#'
#' Q(u) = a + (b − a) qbeta(u, α, β) (exakt, ohne Tabellierung); a = b ergibt Q ≡ a.
#' @noRd
dist_pert_q <- function(u, par) {
  p <- dist_pert_par(par)
  if (p$a == p$b) return(rep(p$a, length(u)))
  pmin(pmax(p$a + (p$b - p$a) * stats::qbeta(u, p$alpha, p$beta), p$a), p$b)
}

#' Verteilung `pert`
#'
#' Mittelwert (a + λc + b)/(λ + 2), Varianz (mean − a)(b − mean)/(λ + 3), Modus c.
#' @return `vofi_typedef` der Art `distribution`.
#' @noRd
typedef_dist_pert <- function() {
  vofi_type(
    name = "pert", kind = "distribution",
    params = list(min = vofi_param("number", required = TRUE),
                  mode = vofi_param("number", required = TRUE),
                  max = vofi_param("number", required = TRUE),
                  lambda = vofi_param("number", default = 4)),
    quantile = function(u, par) dist_pert_q(u, par),
    point = function(par, which = c("mode", "median", "mean")) {
      which <- dist_which(which)
      p <- dist_pert_par(par)
      switch(which,
        mode = p$c,
        median = dist_pert_q(0.5, par),
        mean = (p$a + p$lambda * p$c + p$b) / (p$lambda + 2)
      )
    },
    moments = function(par) {
      p <- dist_pert_par(par)
      m <- (p$a + p$lambda * p$c + p$b) / (p$lambda + 2)
      list(mean = m, var = max((m - p$a) * (p$b - m) / (p$lambda + 3), 0))
    },
    validate = function(par) {
      out <- dist_validate_three("pert", par)
      if (length(out) > 0L) return(out)
      lam <- dist_num(par, "lambda", 4)
      if (!(length(lam) == 1L && is.finite(lam) && lam > 0)) {
        return(dist_msg("pert", "lambda_invalid", value = utl_collapse(format(lam))))
      }
      character(0)
    },
    example = list(min = 0.95, mode = 1.10, max = 1.50)
  )
}
