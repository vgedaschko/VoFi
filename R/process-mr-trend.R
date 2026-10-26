# Prozesstyp mr_trend (WS-C; Spec 00 Abschnitte 5.3, 11.7, R-95; Spec 01 Teil C 1.6.4).
# Energiepreise: Mean-Reversion der Log-Abweichung um einen Trend, optional vom Startniveau p0
# (z. B. 12-Monats-Mittel) zum Normalpreis p_norm.

#' Prozess `mr_trend` simulieren
#'
#' P_y = p̄ (1 + g)^{y−1} exp(Y_y − v_y/2), Y_1 = ln(p0/p̄), v_1 = 0, Y_y = φ Y_{y−1} + σ z_y,
#' v_y = φ² v_{y−1} + σ²; Spalte 1 ist exakt p0.
#' @param par Parameter `p0`, `p_norm` (Default `p0`), `growth` (0), `phi`, `sigma`.
#' @param z n × (length(years) − 1) Schocks (`NULL` = 0).
#' @param u nicht verwendet.
#' @param years Kalenderjahre.
#' @param linked nicht verwendet (Attribut `"n"`).
#' @return Matrix n × length(years).
#' @noRd
proc_mr_trend_simulate <- function(par, z, u, years, linked) {
  n <- proc_n(par, z, u, linked)
  y <- length(years)
  p0 <- proc_vec(par, "p0", n)
  pbar <- proc_vec(par, "p_norm", n, default = par[["p0"]])
  g <- proc_vec(par, "growth", n, default = 0)
  phi <- proc_vec(par, "phi", n)
  sigma <- proc_vec(par, "sigma", n)
  z <- proc_z(z, n, y)
  ex <- matrix(0, n, y)
  dev <- log(p0 / pbar)
  v <- rep(0, n)
  lg <- log1p(g)
  for (k in seq_len(y - 1L)) {
    dev <- phi * dev + sigma * z[, k]
    v <- phi^2 * v + sigma^2
    ex[, k + 1L] <- k * lg + dev - v / 2
  }
  out <- pbar * exp(ex)
  out[, 1L] <- p0
  out
}

#' Erwartungspfad von `mr_trend` bei Punktparametern
#'
#' E[P_y] = p̄ (1 + g)^{y−1} (p0/p̄)^{φ^{y−1}}; Spalte 1 = p0. Zusätzlich die Varianz des
#' Log-Rauschens v_y = σ²(1 − φ^{2(y−1)})/(1 − φ²).
#' @return Liste `mean`, `v`, `trend`, `dev`.
#' @noRd
proc_mr_trend_moments <- function(par, years) {
  k <- seq_along(years) - 1L
  p0 <- proc_point(par, "p0")
  pbar <- proc_point(par, "p_norm", default = par[["p0"]])
  g <- proc_point(par, "growth", default = 0)
  phi <- proc_point(par, "phi")
  sigma <- proc_point(par, "sigma")
  trend <- pbar * exp(k * log1p(g))
  dev <- phi^k * log(p0 / pbar)
  m <- trend * exp(dev)
  m[1L] <- p0
  list(mean = m, v = sigma^2 * proc_geo2(phi, k), trend = trend, dev = dev)
}

#' Prozess `mr_trend`
#'
#' Ausgabeart `level`; `quantile_path` = p̄ (1 + g)^{y−1} exp(φ^{y−1} ln(p0/p̄) − v_y/2 +
#' Φ⁻¹(p) √v_y).
#' @return `vofi_typedef` der Art `process`.
#' @noRd
typedef_process_mr_trend <- function() {
  vofi_type(
    name = "mr_trend", kind = "process", output = "level", linked = character(0),
    params = list(p0 = vofi_param("number", required = TRUE, min = 0),
                  p_norm = vofi_param("number", min = 0),
                  growth = vofi_param("number", default = 0, min = -1),
                  phi = vofi_param("number", required = TRUE, min = -1, max = 1),
                  sigma = vofi_param("number", required = TRUE, min = 0)),
    simulate = function(par, z, u, years, linked) {
      proc_mr_trend_simulate(par, z, u, years, linked)
    },
    expected = function(par, years) proc_mr_trend_moments(par, years)$mean,
    n_shocks = function(par) 1L,
    n_uniforms = function(par) 0L,
    quantile_path = function(par, years, p) {
      m <- proc_mr_trend_moments(par, years)
      q <- m$trend * exp(m$dev - m$v / 2 + stats::qnorm(p) * sqrt(m$v))
      q[1L] <- m$mean[1L]
      q
    },
    validate = function(par) {
      c(proc_check(par, "p0", "positive", required = TRUE, allow_token = TRUE),
        proc_check(par, "p_norm", "positive", allow_token = TRUE),
        proc_check(par, "growth", "gt_minus1"),
        proc_check(par, "phi", "abs_lt1", required = TRUE),
        proc_check(par, "sigma", "nonneg", required = TRUE))
    },
    example = list(p0 = 0.063297, p_norm = 0.0594966, growth = 0.02, phi = 0.75, sigma = 0.08)
  )
}
