# Entnahme-Aequivalent (WS-D2, Spec 00 Abschnitt 12.8, Memo 01 4.6, Invariante I5).
# Eigentuemer: WS-D2. kpi_withdrawal_equivalent() loest je Lauf die konstante Zusatzentnahme E*
# (E je Jahr, gebucht E * Delta_t in t >= 1) mit f(E*) = 0,
#   f(E) = BS(E) - Sum_t dNS_t(E) * q_T / q_t - EW_U,
# ueber Wiederholungslaeufe ctx$rebalance() ohne Ledger-Buchung mit dem Instrument-Cache der
# Engine (9.3). Klammer und Verdopplung nach 12.8, danach vektorisiertes Illinois-Verfahren
# (kpi_illinois(), R/kpi-returns.R). vofi_solve(what = "withdrawal_equivalent") (WS-G) ruft
# dieselbe Funktion mit eigener Toleranz.

#' Entnahme-Äquivalent je Lauf (12.8)
#'
#' @param core core (12.1) in der Sicht `"with_rv"` (BS(E) = `BS_T`) bzw. `"ex_rv"`
#'   (`BS_T_ex_rv`, 9.4).
#' @param ctx Laufkontext der Stufe `"kpi"` (mit `ctx$rebalance()`).
#' @param tol absolute Toleranz in EUR/Jahr; `NULL`: 1e-6 im deterministischen Lauf, sonst 1e-2.
#' @param max_iter Höchstzahl der Iterationen des Illinois-Verfahrens.
#' @return `vofi_kpi_value` (n Werte, NA `no_solution`) mit Attribut `"solver"`
#'   (`iterations`, `converged`).
#' @noRd
kpi_withdrawal_equivalent <- function(core, ctx, tol = NULL, max_iter = 80L) {
  n <- core$n
  nt <- kpi_nt(core)
  tj <- kpi_tj(core)
  tol <- tol %||% (if (identical(ctx$mode, "deterministic")) 1e-6 else 1e-2)
  if (!is.numeric(tol) || length(tol) != 1L || !is.finite(tol) || tol <= 0) {
    vofi_abort("kpi.errors.solver_args", .class = "vofi_error_input")
  }
  ex_rv <- identical(core$view, "ex_rv")
  ew_u <- kpi_ew_opp(core)
  q <- kpi_q(core)
  qt <- q[, nt]
  ns0 <- kpi_ns(core)
  dmat <- matrix(core$grid$delta, n, nt, byrow = TRUE)
  f <- function(e) {
    r <- ctx$rebalance(extra_out = -e * dmat)
    bs <- as.double(if (ex_rv) r$BS_T_ex_rv else r$BS_T)
    dns <- r$NS - ns0
    bs - rowSums(dns * qt / q) - ew_u
  }
  dew <- kpi_ew(core) - ew_u
  lo <- pmin(dew, 0) / tj - 1
  hi <- pmax(dew, 0) / tj + 1
  flo <- f(lo)
  fhi <- f(hi)
  for (k in seq_len(30L)) {
    need_lo <- is.finite(flo) & flo < 0
    need_hi <- is.finite(fhi) & fhi > 0
    if (!any(need_lo | need_hi)) break
    width <- hi - lo
    if (any(need_lo)) {
      lo[need_lo] <- lo[need_lo] - width[need_lo]
      flo[need_lo] <- f(lo)[need_lo]
    }
    if (any(need_hi)) {
      hi[need_hi] <- hi[need_hi] + width[need_hi]
      fhi[need_hi] <- f(hi)[need_hi]
    }
  }
  ok <- is.finite(flo) & is.finite(fhi) & flo >= 0 & fhi <= 0
  bsu <- core$opp$BS %||% kpi_zeros(core)
  scale <- pmax(1, abs(ew_u), kpi_row_max(abs(core$stocks$BS)), kpi_row_max(abs(bsu)))
  scale[is.na(scale)] <- 1
  sol <- kpi_illinois(f, lo, hi, flo, fhi, tol = tol, ftol = 1e-11 * scale,
                      max_iter = max_iter, active = ok)
  res <- kpi_value_codes(sol$root, list(!ok, "no_solution"))
  structure(res, solver = list(iterations = sol$iterations, converged = sol$converged))
}

#' @noRd
typedef_kpi_withdrawal_equivalent <- function() {
  kpi_typedef("withdrawal_equivalent", function(core, ctx) {
    res <- kpi_withdrawal_equivalent(core, ctx)
    attr(res, "solver") <- NULL
    res
  }, unit = "EUR_pa", rv_variant = TRUE, higher_is_better = TRUE, mc_default = FALSE,
  requires = "opportunity", stopped = TRUE)
}
