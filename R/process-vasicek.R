# Prozesstyp vasicek (WS-C; Spec 00 Abschnitte 5.3, 11.7, R-95; Spec 01 Teil C 1.6.3).
# Bauzins, Bundrendite: exakte Diskretisierung in Jahresschritten, Untergrenze nur der Ausgabe.

#' Prozess `vasicek` simulieren
#'
#' Zustand r_1 = r0, r_y = θ + (r_{y−1} − θ) e^{−κ} + σ √((1 − e^{−2κ})/(2κ)) z_y; Ausgabe
#' `pmax(r, floor)` (der Zustand bleibt ungekappt).
#' @param par Parameter `r0`, `theta`, `kappa`, `sigma`, `floor` (Default `-Inf`).
#' @param z n × (length(years) − 1) Schocks (`NULL` = 0).
#' @param u nicht verwendet.
#' @param years Kalenderjahre.
#' @param linked nicht verwendet (Attribut `"n"`).
#' @return Matrix n × length(years).
#' @noRd
proc_vasicek_simulate <- function(par, z, u, years, linked) {
  n <- proc_n(par, z, u, linked)
  y <- length(years)
  r0 <- proc_vec(par, "r0", n)
  theta <- proc_vec(par, "theta", n)
  kappa <- proc_vec(par, "kappa", n)
  sigma <- proc_vec(par, "sigma", n)
  fl <- proc_vec(par, "floor", n, default = -Inf)
  a <- exp(-kappa)
  s <- sigma * sqrt(-expm1(-2 * kappa) / (2 * kappa))
  z <- proc_z(z, n, y)
  out <- matrix(0, n, y)
  cur <- r0
  out[, 1L] <- cur
  for (k in seq_len(y - 1L)) {
    cur <- theta + (cur - theta) * a + s * z[, k]
    out[, k + 1L] <- cur
  }
  # Untergrenze nur, wenn ein Lauf eine endliche Untergrenze hat (Typparameter, 2.8 Nr. 2)
  if (all(fl == -Inf)) out else pmax(out, fl)
}

#' Ungekappte Momente von `vasicek` bei Punktparametern
#'
#' m*_y = θ + (r0 − θ) e^{−κ(y−1)}, sd_y = σ √((1 − e^{−2κ(y−1)})/(2κ)); AR-Äquivalent
#' φ = e^{−κ}, σ_ε = σ √((1 − e^{−2κ})/(2κ)).
#' @return Liste `mean`, `sd`, `phi`, `sigma`, `floor`.
#' @noRd
proc_vasicek_moments <- function(par, years) {
  k <- seq_along(years) - 1L
  r0 <- proc_point(par, "r0")
  theta <- proc_point(par, "theta")
  kappa <- proc_point(par, "kappa")
  sigma <- proc_point(par, "sigma")
  list(mean = theta + (r0 - theta) * exp(-kappa * k),
       sd = sigma * sqrt(-expm1(-2 * kappa * k) / (2 * kappa)),
       phi = exp(-kappa), sigma = sigma * sqrt(-expm1(-2 * kappa) / (2 * kappa)),
       floor = proc_point(par, "floor", default = -Inf))
}

#' Prozess `vasicek`
#'
#' Ausgabeart `level`. `expected` = pmax(m*_y, floor) (P2 gilt auch bei bindender Untergrenze,
#' R-95); `quantile_path` = pmax(m*_y + Φ⁻¹(p) sd_y, floor) (die Kappung ist monoton).
#' @return `vofi_typedef` der Art `process`.
#' @noRd
typedef_process_vasicek <- function() {
  vofi_type(
    name = "vasicek", kind = "process", output = "level", linked = character(0),
    params = list(r0 = vofi_param("number", required = TRUE),
                  theta = vofi_param("number", required = TRUE),
                  kappa = vofi_param("number", required = TRUE, min = 0),
                  sigma = vofi_param("number", required = TRUE, min = 0),
                  floor = vofi_param("number", default = -Inf)),
    simulate = function(par, z, u, years, linked) {
      proc_vasicek_simulate(par, z, u, years, linked)
    },
    expected = function(par, years) {
      m <- proc_vasicek_moments(par, years)
      pmax(m$mean, m$floor)
    },
    n_shocks = function(par) 1L,
    n_uniforms = function(par) 0L,
    quantile_path = function(par, years, p) {
      m <- proc_vasicek_moments(par, years)
      pmax(m$mean + stats::qnorm(p) * m$sd, m$floor)
    },
    validate = function(par) {
      out <- c(proc_check(par, "r0", "finite", required = TRUE, allow_token = TRUE),
               proc_check(par, "theta", "finite", required = TRUE),
               proc_check(par, "kappa", "positive", required = TRUE),
               proc_check(par, "sigma", "nonneg", required = TRUE),
               proc_check(par, "floor", "not_nan"))
      r0 <- par[["r0"]]
      fl <- par[["floor"]]
      if (length(out) == 0L && is.numeric(r0) && is.numeric(fl) && fl > r0) {
        out <- c(out, msg("sampling.process.floor_r0", floor = fl, r0 = r0))
      }
      out
    },
    example = list(r0 = 0.04, theta = 0.0375, kappa = 0.12, sigma = 0.007, floor = 0.005)
  )
}
