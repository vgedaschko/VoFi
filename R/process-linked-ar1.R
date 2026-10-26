# Prozesstyp linked_ar1 (WS-C; Spec 00 Abschnitte 5.3, 11.7, R-95, R-114; Spec 01 Teil C 1.6.2).
# Strukturelle Kopplung an einen Basisprozess: g_y = a + b base_y + u_y, u_1 = u0,
# u_y = phi u_{y-1} + sigma z_y.

#' Prozess `linked_ar1` simulieren
#'
#' @param par Parameter `base` (Schlüssel des Basisprozesses), `a` (0), `b` (1), `phi` (0),
#'   `sigma` (0), `u0` (0).
#' @param z n × (length(years) − 1) Schocks des Rests (`NULL` = 0).
#' @param u nicht verwendet.
#' @param years Kalenderjahre.
#' @param linked benannte Liste mit dem Pfad `base` (n × length(years)) des Basisprozesses.
#' @return Matrix n × length(years).
#' @noRd
proc_linked_ar1_simulate <- function(par, z, u, years, linked) {
  n <- proc_n(par, z, u, linked)
  y <- length(years)
  base <- linked[["base"]]
  if (!is.matrix(base) || nrow(base) != n || ncol(base) != y) {
    vofi_abort("sampling.process.linked_input", param = "base", n = n, y = y,
               .class = "vofi_error_contract")
  }
  a <- proc_vec(par, "a", n, default = 0)
  b <- proc_vec(par, "b", n, default = 1)
  phi <- proc_vec(par, "phi", n, default = 0)
  sigma <- proc_vec(par, "sigma", n, default = 0)
  u0 <- proc_vec(par, "u0", n, default = 0)
  z <- proc_z(z, n, y)
  res <- matrix(0, n, y)
  cur <- u0
  res[, 1L] <- cur
  for (k in seq_len(y - 1L)) {
    cur <- phi * cur + sigma * z[, k]
    res[, k + 1L] <- cur
  }
  a + b * base + res
}

#' Momente von `linked_ar1` bei Punktparametern (Gaußbasis, R-114)
#'
#' m_y = a + b m^B_y + φ^{y−1} u0; Var(g_y) = b² Var(base_y) + σ²(1 − φ^{2(y−1)})/(1 − φ²)
#' + 2 b ρ σ_B σ (1 − (φ_B φ)^{y−1})/(1 − φ_B φ) mit ρ = Schockkorrelation zum Basisprozess und
#' den AR-Parametern φ_B, σ_B der Basis (Spec 01 Teil C 4.3 Nr. 1 c). Ohne `par$.base` bzw. ohne
#' Gaußbasis ist `sd` `NA`; ohne `.base` ist auch `mean` `NA`.
#' @return Liste `mean`, `sd`, `phi`, `sigma`.
#' @noRd
proc_linked_ar1_moments <- function(par, years) {
  y <- length(years)
  k <- seq_len(y) - 1L
  a <- proc_point(par, "a", default = 0)
  b <- proc_point(par, "b", default = 1)
  phi <- proc_point(par, "phi", default = 0)
  sigma <- proc_point(par, "sigma", default = 0)
  u0 <- proc_point(par, "u0", default = 0)
  na <- rep(NA_real_, y)
  out <- list(mean = na, sd = na, phi = phi, sigma = sigma)
  bs <- par[[".base"]]
  if (!is.list(bs) || !utl_is_string(bs$type) || !reg_has("process", bs$type)) return(out)
  bpar <- bs$par %||% list()
  bmean <- reg_get("process", bs$type)$expected(bpar, years)
  out$mean <- a + b * bmean + phi^k * u0
  g <- proc_gauss(bs$type, bpar, years)
  if (is.null(g)) return(out)
  rho <- as.double(bs$rho %||% 0)
  cross <- if (rho == 0) 0 else
    2 * b * rho * g$sigma * sigma * proc_geo(g$phi * phi, k)
  v <- b^2 * g$sd^2 + sigma^2 * proc_geo2(phi, k) + cross
  out$sd <- sqrt(pmax(v, 0))
  out
}

#' Prozess `linked_ar1`
#'
#' Ausgabeart `rate`; `linked = "base"`. `expected` und `quantile_path` brauchen Typ,
#' Punktparameter und Schockkorrelation des Basisprozesses in `par$.base = list(type, par, rho)`
#' (rekursiv bei verketteten Prozessen; R-114). Ohne Gaußbasis liefert `quantile_path`
#' `rep(NA_real_, length(years))`.
#' @return `vofi_typedef` der Art `process`.
#' @noRd
typedef_process_linked_ar1 <- function() {
  vofi_type(
    name = "linked_ar1", kind = "process", output = "rate", linked = "base",
    params = list(base = vofi_param("string", required = TRUE),
                  a = vofi_param("number", default = 0),
                  b = vofi_param("number", default = 1),
                  phi = vofi_param("number", default = 0, min = -1, max = 1),
                  sigma = vofi_param("number", default = 0, min = 0),
                  u0 = vofi_param("number", default = 0)),
    simulate = function(par, z, u, years, linked) {
      proc_linked_ar1_simulate(par, z, u, years, linked)
    },
    expected = function(par, years) proc_linked_ar1_moments(par, years)$mean,
    n_shocks = function(par) 1L,
    n_uniforms = function(par) 0L,
    quantile_path = function(par, years, p) {
      m <- proc_linked_ar1_moments(par, years)
      if (anyNA(m$sd) || anyNA(m$mean)) return(rep(NA_real_, length(years)))
      m$mean + stats::qnorm(p) * m$sd
    },
    validate = function(par) {
      base <- par[["base"]]
      c(if (!utl_is_string(base) || !nzchar(base)) msg("sampling.process.base_missing"),
        proc_check(par, "a", "finite"),
        proc_check(par, "b", "finite"),
        proc_check(par, "phi", "abs_lt1"),
        proc_check(par, "sigma", "nonneg"),
        proc_check(par, "u0", "finite", allow_token = TRUE, allow_dist = FALSE))
    },
    example = list(base = "inflation", a = 0.002, b = 0.8, phi = 0.5, sigma = 0.006, u0 = 0,
                   .base = list(type = "ar1",
                                par = list(mu = 0.02, phi = 0.5, sigma = 0.011, x0 = 0.028),
                                rho = 0.3))
  )
}
