# Renditekennzahlen und Loeser (WS-D2, Spec 00 Abschnitte 12.3, 12.6, 12.8).
# Eigentuemer: WS-D2. roe_classic (R1), roe_mirr (R3, Standard, MIRR- bzw. Baldwin-Logik mit
# h_net), roe_irr (R2, vektorisierte Bisektion auf [-0,99; 1] mit Horner-Auswertung),
# irr_cf_project (IZF der Zahlungsfolge); NA-Codes no_existing_value (Bestandsprojekt ohne
# Bestandswert, R-68), no_equity, multiple_equity_flows, equity_lost, irr_ambiguous,
# irr_out_of_range. Dazu der vektorisierte Illinois-Loeser (Entnahme-Aequivalent, 12.8) und die
# Rendite der Mehrinvestition incremental_return (12.6, 12.8; deterministisch, in der MC v1
# "not_computed").

# ---------------------------------------------------------------------------------------------
# Hilfsfunktionen: Kapitalwert, Vorzeichenwechsel, Bisektion, Illinois
# ---------------------------------------------------------------------------------------------

#' Kapitalwert Sum_t c_t (1 + r)^(-tau_t), rückwärts mit (1 + r)^(-Delta_t) (Horner, 12.3)
#' @param cf n x K Zahlungen (Spalte 1 = t0).
#' @param delta Periodenlängen in Jahren (Länge K, `delta[1]` = 0).
#' @param r n-Vektor.
#' @return n-Vektor.
#' @noRd
kpi_npv_horner <- function(cf, delta, r) {
  k <- ncol(cf)
  v <- cf[, k]
  if (k > 1L) {
    for (j in rev(seq_len(k - 1L))) v <- cf[, j] + v * (1 + r)^(-delta[j + 1L])
  }
  v
}

#' Anzahl der Vorzeichenwechsel je Lauf (Beträge <= 1e-9 * max(1, max |c|) zählen als 0)
#' @noRd
kpi_sign_changes <- function(cf) {
  n <- nrow(cf)
  scale <- kpi_row_max(abs(cf))
  scale[is.na(scale)] <- 0
  tol <- 1e-9 * pmax(1, scale)
  last <- rep(0, n)
  cnt <- integer(n)
  for (j in seq_len(ncol(cf))) {
    s <- sign(cf[, j]) * (abs(cf[, j]) > tol)
    cnt <- cnt + as.integer(s != 0 & last != 0 & s != last)
    last <- ifelse(s != 0, s, last)
  }
  cnt
}

#' Interner Zinsfuß je Lauf (vektorisierte Bisektion, feste Iterationszahl, 12.3)
#'
#' Die feste Zahl der Halbierungen (64) macht das Ergebnis eines Laufs unabhängig von den
#' übrigen Läufen des Batches (F7).
#' @param cf n x K Zahlungen; @param delta Periodenlängen (Jahre).
#' @return Liste `value` (n), `ambiguous` (> 1 Vorzeichenwechsel), `out_of_range` (keine
#'   Nullstelle auf `[lo, hi]`).
#' @noRd
kpi_irr <- function(cf, delta, lo = -0.99, hi = 1, iter = 64L) {
  n <- nrow(cf)
  a <- rep(lo, n)
  b <- rep(hi, n)
  fa <- kpi_npv_horner(cf, delta, a)
  fb <- kpi_npv_horner(cf, delta, b)
  ambiguous <- kpi_sign_changes(cf) > 1L
  out <- !is.finite(fa) | !is.finite(fb) | (fa * fb > 0) | (fa == 0 & fb == 0)
  for (k in seq_len(iter)) {
    m <- (a + b) / 2
    fm <- kpi_npv_horner(cf, delta, m)
    right <- is.finite(fm) & fm != 0 & sign(fm) == sign(fa)
    a <- ifelse(right, m, a)
    fa <- ifelse(right, fm, fa)
    b <- ifelse(right, b, m)
  }
  list(value = (a + b) / 2, ambiguous = ambiguous, out_of_range = out)
}

#' Regula-falsi-Schätzung auf einer Klammer (Mitte, wenn entartet)
#' @noRd
kpi_secant <- function(a, b, fa, fb) {
  x <- (a * fb - b * fa) / (fb - fa)
  bad <- !is.finite(x) | x < a | x > b
  x[bad] <- (a[bad] + b[bad]) / 2
  x
}

#' Vektorisiertes Illinois-Verfahren für fallende Funktionen (12.8)
#'
#' Je Lauf gilt f(lo) >= 0 >= f(hi). Ein Lauf endet, wenn |f(x)| <= ftol (Nullstelle im linearen
#' Stück getroffen) oder hi - lo < tol (Schätzung: Regula falsi auf der Klammer); höchstens
#' `max_iter` Iterationen. Beendete Läufe bleiben unverändert, sodass das Ergebnis eines Laufs
#' nicht von den übrigen Läufen abhängt (F7).
#' @param f Funktion: n-Vektor -> n-Vektor.
#' @param lo,hi,flo,fhi Klammer und Funktionswerte (n-Vektoren).
#' @param tol,ftol Toleranzen (Skalar bzw. n-Vektor).
#' @param max_iter Höchstzahl der Iterationen.
#' @param active Läufe, die gelöst werden (übrige: `NA`).
#' @return Liste `root`, `converged`, `iterations`.
#' @noRd
kpi_illinois <- function(f, lo, hi, flo, fhi, tol, ftol, max_iter = 80L,
                         active = rep(TRUE, length(lo))) {
  n <- length(lo)
  a <- lo
  b <- hi
  fa <- flo
  fb <- fhi
  ga <- fa
  gb <- fb
  ftol <- rep_len(ftol, n)
  tol <- rep_len(tol, n)
  side <- integer(n)
  root <- rep(NA_real_, n)
  done <- !active
  hit_a <- active & abs(fa) <= ftol
  hit_b <- active & !hit_a & abs(fb) <= ftol
  root[hit_a] <- a[hit_a]
  root[hit_b] <- b[hit_b]
  done <- done | hit_a | hit_b
  narrow <- !done & (b - a) < tol
  root[narrow] <- kpi_secant(a, b, fa, fb)[narrow]
  done <- done | narrow
  iter <- 0L
  while (any(!done) && iter < max_iter) {
    iter <- iter + 1L
    x <- kpi_secant(a, b, ga, gb)
    x[done] <- a[done]
    x[!is.finite(x)] <- 0
    fx <- as.double(f(x))
    act <- !done
    badf <- act & !is.finite(fx)
    root[badf] <- kpi_secant(a, b, fa, fb)[badf]
    done <- done | badf
    act <- act & !badf
    hit <- act & abs(fx) <= ftol
    right <- act & !hit & fx > 0
    left <- act & !hit & fx < 0
    gb[right & side == -1L] <- gb[right & side == -1L] / 2
    a[right] <- x[right]
    fa[right] <- fx[right]
    ga[right] <- fx[right]
    side[right] <- -1L
    ga[left & side == 1L] <- ga[left & side == 1L] / 2
    b[left] <- x[left]
    fb[left] <- fx[left]
    gb[left] <- fx[left]
    side[left] <- 1L
    root[hit] <- x[hit]
    done <- done | hit
    conv <- act & !hit & (b - a) < tol
    root[conv] <- kpi_secant(a, b, fa, fb)[conv]
    done <- done | conv
  }
  rest <- active & is.na(root)
  root[rest] <- kpi_secant(a, b, fa, fb)[rest]
  list(root = root, converged = done & active, iterations = iter)
}

# ---------------------------------------------------------------------------------------------
# EK-Rentabilität R1, R3, R2 (12.3)
# ---------------------------------------------------------------------------------------------

#' Gemeinsame Größen der EK-Renditen
#' @return Liste `el`, `en`, `ew`, `q`, `tj`, `num` (Zähler R3), `den` (Nenner R3), `no_value`.
#' @noRd
kpi_roe_parts <- function(core, ctx) {
  el <- kpi_el(core)
  en <- kpi_en(core)
  ew <- kpi_ew(core)
  q <- kpi_q(core)
  qt <- q[, ncol(q)]
  ex <- kpi_existing(ctx)
  list(el = el, en = en, ew = ew, q = q, tj = kpi_tj(core),
       num = ew + rowSums(en * qt / q), den = rowSums(el / q),
       no_value = rep(ex$existing && !ex$has_value, core$n))
}

#' R1 klassisch: (EW / EL_0)^(1/T_J) - 1 (nur eine Einlage in t = 0, keine Entnahmen)
#' @noRd
kpi_calc_roe_classic <- function(core, ctx) {
  p <- kpi_roe_parts(core, ctx)
  z <- vofi_tol$zero_abs
  el0 <- p$el[, 1L]
  later <- rowSums(abs(p$el[, -1L, drop = FALSE]) > z) > 0 | rowSums(abs(p$en) > z) > 0
  bad <- p$no_value | el0 <= z | later | p$ew <= 0
  base <- ifelse(bad, 1, p$ew / ifelse(el0 > z, el0, 1))
  kpi_value_codes(base^(1 / p$tj) - 1, list(p$no_value, "no_existing_value"),
                  list(el0 <= z, "no_equity"), list(later, "multiple_equity_flows"),
                  list(p$ew <= 0, "equity_lost"))
}

#' R3 modifiziert (MIRR): (Zähler / Nenner)^(1/T_J) - 1
#' @noRd
kpi_calc_roe_mirr <- function(core, ctx) {
  p <- kpi_roe_parts(core, ctx)
  z <- vofi_tol$zero_abs
  bad <- p$no_value | p$den <= z | p$num <= 0
  base <- ifelse(bad, 1, p$num / ifelse(p$den > z, p$den, 1))
  kpi_value_codes(base^(1 / p$tj) - 1, list(p$no_value, "no_existing_value"),
                  list(p$den <= z, "no_equity"), list(p$num <= 0, "equity_lost"))
}

#' R2 Equity-IRR: c_t = -EL_t + EN_t, c_T += EW
#' @noRd
kpi_calc_roe_irr <- function(core, ctx) {
  p <- kpi_roe_parts(core, ctx)
  z <- vofi_tol$zero_abs
  cf <- -p$el + p$en
  nt <- ncol(cf)
  cf[, nt] <- cf[, nt] + p$ew
  r <- kpi_irr(cf, core$grid$delta)
  kpi_value_codes(r$value, list(p$no_value, "no_existing_value"),
                  list(p$den <= z, "no_equity"), list(p$num <= 0, "equity_lost"),
                  list(r$ambiguous, "irr_ambiguous"), list(r$out_of_range, "irr_out_of_range"))
}

#' IZF der Zahlungsfolge (project + grants, finanzierungsneutral)
#' @noRd
kpi_calc_irr_cf_project <- function(core, ctx) {
  r <- kpi_irr(kpi_cf_project(core), core$grid$delta)
  kpi_value_codes(r$value, list(r$ambiguous, "irr_ambiguous"),
                  list(r$out_of_range, "irr_out_of_range"))
}

#' @noRd
typedef_kpi_roe_classic <- function() {
  kpi_typedef("roe_classic", kpi_calc_roe_classic, unit = "rate_pa", rv_variant = TRUE,
              higher_is_better = TRUE, mc_default = TRUE, stopped = TRUE)
}

#' @noRd
typedef_kpi_roe_mirr <- function() {
  kpi_typedef("roe_mirr", kpi_calc_roe_mirr, unit = "rate_pa", rv_variant = TRUE,
              higher_is_better = TRUE, mc_default = TRUE, stopped = TRUE)
}

#' @noRd
typedef_kpi_roe_irr <- function() {
  kpi_typedef("roe_irr", kpi_calc_roe_irr, unit = "rate_pa", rv_variant = TRUE,
              higher_is_better = TRUE, mc_default = FALSE, stopped = TRUE)
}

#' @noRd
typedef_kpi_irr_cf_project <- function() {
  kpi_typedef("irr_cf_project", kpi_calc_irr_cf_project, unit = "rate_pa",
              higher_is_better = TRUE, mc_default = FALSE, rv_ref = "with")
}

# ---------------------------------------------------------------------------------------------
# Rendite der Mehrinvestition (12.6, 12.8, R-68)
# ---------------------------------------------------------------------------------------------

#' Rendite der Mehrinvestition h* mit g(h*) = 0 (deterministisch, 12.8)
#'
#' `g(h)` ist `delta_vs_reference` bei `accounts.deposit_rate_pa = h` in Variante, Referenz und
#' beiden Unterlassungsalternativen; der Aufrufer (`vofi_solve()`/`vofi_compare()`, WS-G) rechnet
#' sie über Design-Läufe und übergibt eine vektorisierte Funktion (Vektor von Habenzinsen ->
#' Vektor der Werte). Ablauf: Auswertung auf `n_grid` äquidistanten Stützstellen von
#' `interval`; definiert nur bei genau einem Vorzeichenwechsel von + nach - (g fallend,
#' Mehrinvestition), sonst `NA` (`no_solution`); danach Illinois-Verfahren im Wechselintervall bis
#' `tol`.
#' @param g Funktion: numerischer Vektor h -> numerischer Vektor g(h) gleicher Länge.
#' @param interval Suchintervall (Default `[-0,02; 0,15]`).
#' @param n_grid Anzahl der Stützstellen (Default 41).
#' @param tol Toleranz in h (Default 1e-8).
#' @param max_iter Höchstzahl der Iterationen.
#' @return `vofi_kpi_value` mit einem Wert und Attribut `"solver"` (`grid`, `values`,
#'   `interval`, `iterations`).
#' @noRd
kpi_incremental_return <- function(g, interval = c(-0.02, 0.15), n_grid = 41L, tol = 1e-8,
                                   max_iter = 100L) {
  if (!is.function(g) || !is.numeric(interval) || length(interval) != 2L ||
        !all(is.finite(interval)) || interval[1L] >= interval[2L]) {
    vofi_abort("kpi.errors.solver_args", .class = "vofi_error_input")
  }
  n_grid <- utl_check_whole(n_grid, "n_grid", min = 2)
  h <- seq(interval[1L], interval[2L], length.out = n_grid)
  gv <- as.double(g(h))
  info <- list(grid = h, values = gv, interval = NULL, iterations = 0L)
  none <- function() {
    structure(vofi_kpi_value(NA_real_, na_reason = "no_solution"), solver = info)
  }
  if (length(gv) != n_grid || anyNA(gv) || any(!is.finite(gv))) return(none())
  sg <- sign(gv)
  nz <- which(sg != 0)
  if (length(nz) < 2L) return(none())
  ch <- which(diff(sg[nz]) != 0)
  if (length(ch) != 1L || sg[nz][ch] != 1) return(none())
  i1 <- nz[ch]
  i2 <- nz[ch + 1L]
  info$interval <- h[c(i1, i2)]
  if (i2 - i1 > 1L) {
    if (i2 - i1 > 2L) return(none())
    return(structure(vofi_kpi_value(h[i1 + 1L]), solver = info))
  }
  scale <- max(1, abs(gv))
  sol <- kpi_illinois(function(x) as.double(g(x)), h[i1], h[i2], gv[i1], gv[i2], tol = tol,
                      ftol = 1e-12 * scale, max_iter = max_iter)
  info$iterations <- sol$iterations
  structure(vofi_kpi_value(sol$root), solver = info)
}

#' Rendite der Mehrinvestition in der Simulation (v1 nicht je Lauf: `not_computed`)
#' @noRd
kpi_incremental_return_mc <- function(n) {
  vofi_kpi_value(rep(NA_real_, n), na_reason = "not_computed")
}
