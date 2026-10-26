# Prozesstyp ar1 (WS-C; Spec 00 Abschnitte 5.3, 11.7; Spec 01 Teil C 1.6.1).
# Inflation und Wachstumsraten: x_1 = x0, x_y = mu + phi (x_{y-1} - mu) + sigma z_y.

#' Prozess `ar1` simulieren
#'
#' Vektorisiert über Läufe; Parameter sind Skalare oder n-Vektoren (unsichere Parameter).
#' @param par Parameter `mu`, `phi`, `sigma`, `x0` (Default `mu`).
#' @param z n × (length(years) − 1) Standardnormal-Schocks (`NULL` = 0).
#' @param u nicht verwendet.
#' @param years Kalenderjahre.
#' @param linked nicht verwendet (Attribut `"n"` = Laufzahl).
#' @return Matrix n × length(years), Spalte 1 = x0.
#' @noRd
proc_ar1_simulate <- function(par, z, u, years, linked) {
  n <- proc_n(par, z, u, linked)
  y <- length(years)
  mu <- proc_vec(par, "mu", n)
  phi <- proc_vec(par, "phi", n)
  sigma <- proc_vec(par, "sigma", n)
  x0 <- proc_vec(par, "x0", n, default = par[["mu"]])
  z <- proc_z(z, n, y)
  out <- matrix(0, n, y)
  cur <- x0
  out[, 1L] <- cur
  for (k in seq_len(y - 1L)) {
    cur <- mu + phi * (cur - mu) + sigma * z[, k]
    out[, k + 1L] <- cur
  }
  out
}

#' Erwartungspfad und Standardabweichung von `ar1` bei Punktparametern
#'
#' E[x_y] = μ + φ^{y−1}(x0 − μ), sd_y = σ √((1 − φ^{2(y−1)})/(1 − φ²)).
#' @return Liste `mean`, `sd`, `phi`, `sigma` (AR-Parameter für gekoppelte Prozesse).
#' @noRd
proc_ar1_moments <- function(par, years) {
  k <- seq_along(years) - 1L
  mu <- proc_point(par, "mu")
  phi <- proc_point(par, "phi")
  sigma <- proc_point(par, "sigma")
  x0 <- proc_point(par, "x0", default = par[["mu"]])
  list(mean = mu + phi^k * (x0 - mu), sd = sigma * sqrt(proc_geo2(phi, k)), phi = phi,
       sigma = sigma)
}

#' Prozess `ar1`
#'
#' Ausgabeart `rate`; ein Schock je Jahr, keine weiteren Uniforms. `quantile_path` =
#' m_y + Φ⁻¹(p) sd_y (Spec 01 Teil C 4.3 Nr. 1 c).
#' @return `vofi_typedef` der Art `process`.
#' @noRd
typedef_process_ar1 <- function() {
  vofi_type(
    name = "ar1", kind = "process", output = "rate", linked = character(0),
    params = list(mu = vofi_param("number", required = TRUE),
                  phi = vofi_param("number", required = TRUE, min = -1, max = 1),
                  sigma = vofi_param("number", required = TRUE, min = 0),
                  x0 = vofi_param("number")),
    simulate = function(par, z, u, years, linked) proc_ar1_simulate(par, z, u, years, linked),
    expected = function(par, years) proc_ar1_moments(par, years)$mean,
    n_shocks = function(par) 1L,
    n_uniforms = function(par) 0L,
    quantile_path = function(par, years, p) {
      m <- proc_ar1_moments(par, years)
      m$mean + stats::qnorm(p) * m$sd
    },
    validate = function(par) {
      c(proc_check(par, "mu", "finite", required = TRUE),
        proc_check(par, "phi", "abs_lt1", required = TRUE),
        proc_check(par, "sigma", "nonneg", required = TRUE),
        proc_check(par, "x0", "finite", allow_token = TRUE))
    },
    example = list(mu = 0.02, phi = 0.5, sigma = 0.011, x0 = 0.028)
  )
}
