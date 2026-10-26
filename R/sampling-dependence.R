# Abhängigkeiten (WS-C; Spec 00 Abschnitt 11.6, R-38, R-59; Spec 01 Teil C 1.7).
# Rangkorrelation statischer Größen je Block (Iman-Conover, Default; Gauß-Copula als Option),
# Korrelation der Prozessschocks (Cholesky), Reparatur nicht positiv definiter Matrizen durch
# Eigenwert-Clipping (kein Matrix::nearPD).

#' Spearman- in Pearson-Korrelation umrechnen: ρ = 2 sin(π ρ_S/6)
#' @param rs Zahl, Vektor oder Matrix (Diagonale bleibt 1).
#' @noRd
smp_spearman_to_pearson <- function(rs) {
  out <- 2 * sin(pi * rs / 6)
  if (is.matrix(rs)) diag(out) <- 1
  out
}

#' Korrelationsmatrix reparieren (Eigenwert-Clipping, Spec 01 Teil C 1.7.4)
#'
#' `R <- (R + t(R))/2`; Eigenzerlegung; falls min λ < ε = 1e-6: λ ← max(λ, ε), Rücktransformation,
#' Reskalierung auf Einheitsdiagonale. Bei einer größten Abweichung über 0,05 folgt
#' `vofi_warning_correlation` (mit Matrix vor und nach der Reparatur in `data`).
#' @param r Korrelationsmatrix (mit dimnames).
#' @param what `"parameters"` oder `"shocks"` (Meldung).
#' @param eps Untergrenze der Eigenwerte.
#' @param warn Warnung ausgeben.
#' @return Liste `matrix`, `repaired` (lgl), `max_dev`.
#' @noRd
smp_near_pd <- function(r, what = "parameters", eps = 1e-6, warn = TRUE) {
  r0 <- r
  r <- (r + t(r)) / 2
  diag(r) <- 1
  e <- eigen(r, symmetric = TRUE)
  if (min(e$values) >= eps) {
    return(list(matrix = r, repaired = FALSE, max_dev = 0))
  }
  lam <- pmax(e$values, eps)
  r2 <- e$vectors %*% (lam * t(e$vectors))
  d <- sqrt(diag(r2))
  r2 <- r2 / outer(d, d)
  r2 <- (r2 + t(r2)) / 2
  diag(r2) <- 1
  dimnames(r2) <- dimnames(r0)
  dev <- max(abs(r2 - r0))
  if (warn && dev > 0.05) {
    vofi_warn("sampling.corr_repaired", what = what, dev = dev,
              .class = "vofi_warning_correlation", .data = list(before = r0, after = r2))
  }
  list(matrix = r2, repaired = TRUE, max_dev = dev)
}

#' Mindestblockgröße für Iman-Conover: m ≥ max(2, d + 1) (Spec 00 11.4)
#' @param m Blockgröße.
#' @param d Anzahl der Schlüssel der Korrelationsgruppe.
#' @noRd
smp_check_block_size <- function(m, d) {
  need <- max(2L, as.integer(d) + 1L)
  if (m < need) {
    vofi_abort("sampling.block_too_small", block_size = m, d = d, min = need,
               .class = "vofi_error_input")
  }
  invisible(TRUE)
}

#' Iman-Conover in einem Block (Spec 00 11.6 Nr. 2, Spec 01 Teil C 1.7.2)
#'
#' T = S Q⁻¹ P mit cor(S) = QᵀQ und Ziel C = PᵀP (obere Cholesky-Faktoren); jede Uniform-Spalte
#' wird nach den Rängen der entsprechenden Spalte von T umsortiert (`ties.method = "first"`). Die
#' Wertemenge je Spalte bleibt exakt erhalten (LHS-Schichtung bleibt).
#' @param u Uniform-Matrix m × d des Blocks (Spalten in kanonischer Ordnung).
#' @param target Pearson-Zielmatrix d × d (repariert).
#' @param scores Score-Matrix m × d (je Spalte unabhängig permutiert).
#' @return Matrix m × d.
#' @noRd
smp_iman_conover <- function(u, target, scores) {
  d <- ncol(u)
  q <- chol(stats::cor(scores))
  p <- chol(target)
  tm <- scores %*% backsolve(q, diag(d)) %*% p
  out <- u
  for (j in seq_len(d)) {
    out[, j] <- sort(u[, j], method = "radix")[rank(tm[, j], ties.method = "first")]
  }
  out
}

#' Gauß-Copula in einem Block: U' = Φ(Φ⁻¹(U) chol(C)) (Spec 00 11.6 Nr. 2)
#' @noRd
smp_gauss_copula <- function(u, target) {
  stats::pnorm(stats::qnorm(u) %*% chol(target))
}

#' Prozessschocks eines Blocks korrelieren: Z %*% chol(R) über alle Jahresspalten
#' (zeithomogen, eine Multiplikation; Spec 00 11.6 Nr. 5)
#' @param z benannte Liste m × k-Schockmatrizen (Gruppe in kanonischer Ordnung).
#' @param target Pearson-Matrix der Gruppe (repariert), dimnames = Prozessschlüssel.
#' @return Liste wie `z`.
#' @noRd
smp_correlate_shocks <- function(z, target) {
  keys <- rownames(target)
  m <- nrow(z[[keys[1L]]])
  k <- ncol(z[[keys[1L]]])
  if (k == 0L) return(z)
  big <- vapply(keys, function(p) as.vector(z[[p]]), numeric(m * k))
  if (!is.matrix(big)) big <- matrix(big, ncol = length(keys))
  res <- big %*% chol(target)
  for (j in seq_along(keys)) z[[keys[j]]] <- matrix(res[, j], m, k)
  z
}
