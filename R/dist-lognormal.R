# Verteilungstyp lognormal (WS-C; Spec 00 Abschnitt 5.3, Spec 01 Teil C 1.4.4).
# Genau eine der Formen (a) meanlog/sdlog, (b) mean/sd, (c) median/p90; optional shift.

#' Formen der Lognormalverteilung
#' @noRd
dist_lognormal_forms <- function() {
  list(a = c("meanlog", "sdlog"), b = c("mean", "sd"), c = c("median", "p90"))
}

#' Kanonische Parameter der Lognormalverteilung (meanlog, sdlog, shift)
#'
#' Umrechnung (Spec 01 Teil C 1.4.4): Form b: σ_l² = ln(1 + sd²/(mean − s)²),
#' m = ln(mean − s) − σ_l²/2; Form c: m = ln(median − s), σ_l = (ln(p90 − s) − ln(median − s)) /
#' Φ⁻¹(0,9).
#' @param par Verteilungsparameter in einer der drei Formen.
#' @return Liste `meanlog`, `sdlog`, `shift`, `form` (`"a"`, `"b"`, `"c"`) und `error`
#'   (Validierungscode oder `NA`).
#' @noRd
dist_lognormal_canon <- function(par) {
  forms <- dist_lognormal_forms()
  given <- function(f) !is.null(par[[f]])
  present <- vapply(forms, function(f) any(vapply(f, given, logical(1))), logical(1))
  complete <- vapply(forms, function(f) all(vapply(f, given, logical(1))), logical(1))
  s <- dist_num(par, "shift", 0)
  out <- list(meanlog = NA_real_, sdlog = NA_real_, shift = s, form = NA_character_,
              error = NA_character_)
  if (sum(present) > 1L) {
    out$error <- "forms_multiple"
    return(out)
  }
  if (!any(complete)) {
    out$error <- "form_missing"
    return(out)
  }
  form <- names(forms)[complete][1L]
  out$form <- form
  if (!(length(s) == 1L && is.finite(s))) {
    out$error <- "shift_invalid"
    return(out)
  }
  num_ok <- function(f) dist_is_finite(par, f)
  if (form == "a") {
    if (!num_ok("meanlog")) {
      out$error <- "meanlog_invalid"
    } else if (!num_ok("sdlog") || dist_num(par, "sdlog") < 0) {
      out$error <- "sdlog_invalid"
    } else {
      out$meanlog <- dist_num(par, "meanlog")
      out$sdlog <- dist_num(par, "sdlog")
    }
  } else if (form == "b") {
    m <- dist_num(par, "mean")
    sd <- dist_num(par, "sd")
    if (!num_ok("mean") || !(m > s)) {
      out$error <- "mean_shift"
    } else if (!num_ok("sd") || sd < 0) {
      out$error <- "sd_invalid"
    } else {
      v <- log1p(sd^2 / (m - s)^2)
      out$sdlog <- sqrt(v)
      out$meanlog <- log(m - s) - v / 2
    }
  } else {
    med <- dist_num(par, "median")
    p90 <- dist_num(par, "p90")
    if (!num_ok("median") || !(med > s)) {
      out$error <- "median_shift"
    } else if (!num_ok("p90") || !(p90 >= med)) {
      out$error <- "p90_median"
    } else {
      out$meanlog <- log(med - s)
      out$sdlog <- (log(p90 - s) - log(med - s)) / stats::qnorm(0.9)
    }
  }
  out
}

#' Kanonische Parameter oder Fehler (für Quantil- und Momentfunktionen)
#' @noRd
dist_lognormal_par <- function(par) {
  p <- dist_lognormal_canon(par)
  if (!is.na(p$error)) {
    vofi_abort("sampling.dist_invalid", entry = "lognormal",
               details = dist_msg("lognormal", p$error), .class = "vofi_error_input")
  }
  p
}

#' Quantilfunktion der Lognormalverteilung
#' @noRd
dist_lognormal_q <- function(u, par) {
  p <- dist_lognormal_par(par)
  if (p$sdlog == 0) return(rep(p$shift + exp(p$meanlog), length(u)))
  p$shift + exp(p$meanlog + p$sdlog * stats::qnorm(u))
}

#' Verteilung `lognormal`
#'
#' Y = X − s ist lognormal(m, σ_l). Q(u) = s + exp(m + σ_l Φ⁻¹(u)); Median s + e^m, Mittelwert
#' s + e^{m + σ_l²/2}, Modus s + e^{m − σ_l²}, Varianz (e^{σ_l²} − 1) e^{2m + σ_l²}.
#' @return `vofi_typedef` der Art `distribution`.
#' @noRd
typedef_dist_lognormal <- function() {
  vofi_type(
    name = "lognormal", kind = "distribution",
    params = list(meanlog = vofi_param("number"), sdlog = vofi_param("number", min = 0),
                  mean = vofi_param("number"), sd = vofi_param("number", min = 0),
                  median = vofi_param("number"), p90 = vofi_param("number"),
                  shift = vofi_param("number", default = 0)),
    quantile = function(u, par) dist_lognormal_q(u, par),
    point = function(par, which = c("mode", "median", "mean")) {
      which <- dist_which(which)
      p <- dist_lognormal_par(par)
      switch(which,
        mode = p$shift + exp(p$meanlog - p$sdlog^2),
        median = p$shift + exp(p$meanlog),
        mean = p$shift + exp(p$meanlog + p$sdlog^2 / 2)
      )
    },
    moments = function(par) {
      p <- dist_lognormal_par(par)
      list(mean = p$shift + exp(p$meanlog + p$sdlog^2 / 2),
           var = expm1(p$sdlog^2) * exp(2 * p$meanlog + p$sdlog^2))
    },
    validate = function(par) {
      p <- dist_lognormal_canon(par)
      if (is.na(p$error)) character(0) else dist_msg("lognormal", p$error)
    },
    example = list(mean = 1.1, sd = 0.1)
  )
}
