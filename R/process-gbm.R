# Prozesstyp gbm (WS-C; Spec 00 Abschnitte 5.3, 11.7; Spec 01 Teil C 1.6.5).
# Geometrische Brownsche Bewegung in Jahresschritten (Option, nicht Default für Energiepreise).

#' Prozess `gbm` simulieren
#'
#' ln P_y = ln P_{y−1} + ln(1 + g) − σ²/2 + σ z_y; Spalte 1 ist exakt p0.
#' @param par Parameter `p0`, `growth` (0), `sigma`.
#' @param z n × (length(years) − 1) Schocks (`NULL` = 0).
#' @param u nicht verwendet.
#' @param years Kalenderjahre.
#' @param linked nicht verwendet (Attribut `"n"`).
#' @return Matrix n × length(years).
#' @noRd
proc_gbm_simulate <- function(par, z, u, years, linked) {
  n <- proc_n(par, z, u, linked)
  y <- length(years)
  p0 <- proc_vec(par, "p0", n)
  g <- proc_vec(par, "growth", n, default = 0)
  sigma <- proc_vec(par, "sigma", n)
  z <- proc_z(z, n, y)
  lp <- matrix(log(p0), n, y)
  step <- log1p(g) - sigma^2 / 2
  for (k in seq_len(y - 1L)) lp[, k + 1L] <- lp[, k] + step + sigma * z[, k]
  out <- exp(lp)
  out[, 1L] <- p0
  out
}

#' Prozess `gbm`
#'
#' Ausgabeart `level`; E[P_y] = p0 (1 + g)^{y−1}; `quantile_path` = p0 (1 + g)^{y−1}
#' exp(−σ²(y − 1)/2 + Φ⁻¹(p) σ √(y − 1)).
#' @return `vofi_typedef` der Art `process`.
#' @noRd
typedef_process_gbm <- function() {
  vofi_type(
    name = "gbm", kind = "process", output = "level", linked = character(0),
    params = list(p0 = vofi_param("number", required = TRUE, min = 0),
                  growth = vofi_param("number", default = 0, min = -1),
                  sigma = vofi_param("number", required = TRUE, min = 0)),
    simulate = function(par, z, u, years, linked) proc_gbm_simulate(par, z, u, years, linked),
    expected = function(par, years) {
      k <- seq_along(years) - 1L
      p0 <- proc_point(par, "p0")
      out <- p0 * exp(k * log1p(proc_point(par, "growth", default = 0)))
      out[1L] <- p0
      out
    },
    n_shocks = function(par) 1L,
    n_uniforms = function(par) 0L,
    quantile_path = function(par, years, p) {
      k <- seq_along(years) - 1L
      p0 <- proc_point(par, "p0")
      g <- proc_point(par, "growth", default = 0)
      s <- proc_point(par, "sigma")
      out <- p0 * exp(k * log1p(g) - s^2 * k / 2 + stats::qnorm(p) * s * sqrt(k))
      out[1L] <- p0
      out
    },
    validate = function(par) {
      c(proc_check(par, "p0", "positive", required = TRUE, allow_token = TRUE),
        proc_check(par, "growth", "gt_minus1"),
        proc_check(par, "sigma", "nonneg", required = TRUE))
    },
    example = list(p0 = 1, growth = 0.02, sigma = 0.1)
  )
}
