# MC-Statistik (WS-G, Spec 00 Abschnitte 11.4, 12.7, 13.2; Spec 01 Teil C 6.1, 6.3).
# mc_stats(): je skalarer Kennzahl Mittelwert, Standardabweichung, Replikat-Standardfehler aus
# den R Blockmitteln (se_df = R - 1, "grob" bei R < 10, naive Formel bei R = 1), Quantile
# (type = 7), Verlustwahrscheinlichkeit p_neg mit Standardfehler aus den Blockanteilen, Mittel
# der schlechtesten 5 % (es05, nicht negiert), erwarteter Nachteil, NA-Anteil, Zahl gueltiger
# Laeufe, deterministischer Wert und Konvergenzausweis (R-97, R-101). Dazu Konfidenzintervalle
# des Mittels (t-Verteilung mit se_df) und verteilungsfreie Intervalle der Quantile ueber
# Ordnungsstatistiken (Memo 04 4.4) sowie die Verteilungsfunktion aus der Quantilfunktion
# (Ueberschreitungswahrscheinlichkeit der Zielwertsuche, 12.8).

#' Quantilniveaus der MC-Statistik (12.7)
#' @noRd
mc_stat_probs <- function() c(0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95)

#' Spaltennamen der MC-Statistik (13.2)
#' @noRd
mc_stat_columns <- function() {
  c("kpi", "mean", "sd", "se", "se_df", "q05", "q10", "q25", "q50", "q75", "q90", "q95",
    "p_neg", "p_neg_se", "es05", "expected_loss", "na_share", "n_valid", "deterministic",
    "converged")
}

#' Standardfehler aus Blockmitteln (Replikat-SE, 11.4, 12.7)
#'
#' R = Zahl der Blöcke mit gültigen Werten; R >= 2: sd(Blockmittel) / sqrt(R), `se_df = R - 1`;
#' R = 1: naive Formel sd / sqrt(n) (überschätzt bei LHS), `se_df = 0`.
#' @param x gültige Werte.
#' @param block Blocknummern der Werte (gleiche Länge).
#' @return Liste `se`, `se_df`, `r` (Zahl der Blöcke).
#' @noRd
mc_block_se <- function(x, block) {
  n <- length(x)
  if (n == 0L) return(list(se = NA_real_, se_df = NA_integer_, r = 0L))
  ub <- unique(block)
  r <- length(ub)
  if (r <= 1L) {
    se <- if (n > 1L) stats::sd(x) / sqrt(n) else NA_real_
    return(list(se = se, se_df = 0L, r = 1L))
  }
  idx <- match(block, ub)
  bm <- as.double(rowsum(x, idx, reorder = FALSE)) / tabulate(idx, r)
  list(se = stats::sd(bm) / sqrt(r), se_df = as.integer(r - 1L), r = r)
}

#' Konvergenzausweis (12.7, R-97, R-101)
#'
#' `TRUE`, wenn R >= 10, t_{R-1; 0,975} * se / |mean| < `rel_halfwidth_mean` und
#' t_{R-1; 0,975} * p_neg_se < `abs_halfwidth_prob`; bei R < 10 stets `FALSE`.
#' @noRd
mc_converged <- function(mean, se, p_neg_se, r, convergence = NULL) {
  conv <- convergence %||% list()
  rel <- as.double(conv$rel_halfwidth_mean %||% 0.005)
  abs_p <- as.double(conv$abs_halfwidth_prob %||% 0.01)
  if (is.na(r) || r < 10L || !is.finite(mean) || !is.finite(se) || !is.finite(p_neg_se) ||
        mean == 0) {
    return(FALSE)
  }
  tq <- stats::qt(0.975, r - 1L)
  isTRUE(tq * se / abs(mean) < rel && tq * p_neg_se < abs_p)
}

#' Statistik einer Kennzahl über die gültigen Läufe (12.7)
#' @param x Werte je Lauf (NA = nicht definiert).
#' @param block Blocknummern je Lauf.
#' @param det deterministischer Wert.
#' @param convergence Konvergenzkriterien (`stochastic.settings.convergence`).
#' @return benannte Liste der numerischen Spalten von `mc_stat_columns()` (ohne `kpi`).
#' @noRd
mc_stat_one <- function(x, block, det = NA_real_, convergence = NULL) {
  x <- as.double(x)
  ok <- !is.na(x)
  v <- x[ok]
  nv <- length(v)
  out <- list(mean = NA_real_, sd = NA_real_, se = NA_real_, se_df = NA_integer_,
              q05 = NA_real_, q10 = NA_real_, q25 = NA_real_, q50 = NA_real_, q75 = NA_real_,
              q90 = NA_real_, q95 = NA_real_, p_neg = NA_real_, p_neg_se = NA_real_,
              es05 = NA_real_, expected_loss = NA_real_,
              na_share = if (length(x) > 0L) mean(!ok) else NA_real_, n_valid = nv,
              deterministic = as.double(det %||% NA_real_)[1L], converged = FALSE)
  if (nv == 0L) return(out)
  b <- block[ok]
  q <- stats::quantile(v, mc_stat_probs(), type = 7, names = FALSE)
  se <- mc_block_se(v, b)
  neg <- as.double(v < 0)
  pse <- mc_block_se(neg, b)
  if (se$r <= 1L) pse$se <- sqrt(mean(neg) * (1 - mean(neg)) / nv)
  out$mean <- mean(v)
  out$sd <- if (nv > 1L) stats::sd(v) else NA_real_
  out$se <- se$se
  out$se_df <- se$se_df
  out[c("q05", "q10", "q25", "q50", "q75", "q90", "q95")] <- as.list(q)
  out$p_neg <- mean(neg)
  out$p_neg_se <- pse$se
  out$es05 <- mean(v[v <= q[1L]])
  out$expected_loss <- mean(pmax(-v, 0))
  out$converged <- mc_converged(out$mean, out$se, out$p_neg_se, se$r, convergence)
  out
}

#' MC-Statistik je skalarer Kennzahl (12.7, 13.2)
#'
#' @param kpis Data Frame der Kennzahlen je Lauf (Spalten `sim`, `block`, `branch` werden
#'   übergangen).
#' @param block Blocknummern je Lauf (Default: Spalte `block` von `kpis`, sonst ein Block).
#' @param deterministic `NULL` oder Data Frame bzw. Liste der deterministischen Werte (eine
#'   Zeile).
#' @param convergence Konvergenzkriterien (`stochastic.settings.convergence`).
#' @param cols `NULL` (alle Kennzahlspalten) oder Auswahl.
#' @return Data Frame mit den Spalten nach 13.2 (`kpi`, `mean`, …, `converged`).
#' @noRd
mc_stats <- function(kpis, block = NULL, deterministic = NULL, convergence = NULL,
                     cols = NULL) {
  if (!is.data.frame(kpis)) {
    vofi_abort("mc.stats_input", .class = "vofi_error_input")
  }
  n <- nrow(kpis)
  block <- block %||% kpis$block %||% rep(1L, n)
  if (length(block) != n) vofi_abort("mc.stats_input", .class = "vofi_error_input")
  cols <- cols %||% setdiff(names(kpis), c("sim", "block", "branch"))
  cols <- cols[vapply(cols, function(k) is.numeric(kpis[[k]]) || is.logical(kpis[[k]]),
                      logical(1))]
  num_cols <- setdiff(mc_stat_columns(), c("kpi", "converged", "se_df", "n_valid"))
  if (length(cols) == 0L) {
    out <- data.frame(kpi = character(0), stringsAsFactors = FALSE)
    for (s in mc_stat_columns()[-1L]) {
      out[[s]] <- if (s == "converged") logical(0) else if (s %in% c("se_df", "n_valid"))
        integer(0) else double(0)
    }
    return(out)
  }
  rows <- lapply(cols, function(k) {
    d <- if (is.null(deterministic)) NULL else deterministic[[k]]
    det <- if (is.null(d) || length(d) == 0L) NA_real_ else as.double(d[1L])
    mc_stat_one(kpis[[k]], block, det, convergence)
  })
  out <- data.frame(kpi = cols, stringsAsFactors = FALSE)
  for (s in num_cols) out[[s]] <- vapply(rows, function(r) as.double(r[[s]]), double(1))
  out$se_df <- vapply(rows, function(r) as.integer(r$se_df), integer(1))
  out$n_valid <- vapply(rows, function(r) as.integer(r$n_valid), integer(1))
  out$converged <- vapply(rows, function(r) isTRUE(r$converged), logical(1))
  out <- out[, mc_stat_columns(), drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Konfidenzintervall des Mittelwerts (t-Verteilung mit `se_df`, 12.7)
#'
#' Bei `se_df` < 1 (ein Block) die Normalverteilung.
#' @param mean,se,se_df Spalten der MC-Statistik.
#' @param level Niveau.
#' @return Matrix mit Spalten `lo`, `hi`.
#' @noRd
mc_mean_ci <- function(mean, se, se_df, level = 0.95) {
  a <- 1 - (1 - level) / 2
  q <- ifelse(!is.na(se_df) & se_df >= 1, stats::qt(a, pmax(se_df, 1)), stats::qnorm(a))
  cbind(lo = mean - q * se, hi = mean + q * se)
}

#' Verteilungsfreies Konfidenzintervall eines Quantils über Ordnungsstatistiken (Memo 04 4.4)
#'
#' k_lo = qbinom((1 - level) / 2; n; p), k_hi = qbinom(1 - (1 - level) / 2; n; p) + 1, begrenzt
#' auf 1 … n.
#' @param x Werte (NA werden entfernt).
#' @param p Quantilniveau.
#' @param level Niveau.
#' @return benannter Vektor `lo`, `hi`.
#' @noRd
mc_quantile_ci <- function(x, p, level = 0.95) {
  xs <- sort(as.double(x[!is.na(x)]), method = "radix")
  n <- length(xs)
  if (n == 0L) return(c(lo = NA_real_, hi = NA_real_))
  a <- (1 - level) / 2
  k_lo <- max(1L, as.integer(stats::qbinom(a, n, p)))
  k_hi <- min(n, as.integer(stats::qbinom(1 - a, n, p)) + 1L)
  c(lo = xs[k_lo], hi = xs[k_hi])
}

#' Verteilungsfunktion einer Overlay-Verteilung aus ihrer Quantilfunktion
#'
#' F(x) = sup{u : Q(u) <= x} über Bisektion in u (Quantilfunktionen sind monoton nicht fallend,
#' 5.3); Grundlage der Überschreitungswahrscheinlichkeit P(X > x*) der Zielwertsuche (12.8).
#' @param dist Name des Verteilungstyps.
#' @param par Verteilungsparameter.
#' @param x Stelle(n).
#' @param iter Zahl der Bisektionsschritte.
#' @return F(x) je Stelle.
#' @noRd
mc_cdf <- function(dist, par, x, iter = 60L) {
  q <- reg_get("distribution", dist)$quantile
  vapply(as.double(x), function(xx) {
    if (is.na(xx)) return(NA_real_)
    lo <- 0
    hi <- 1
    if (q(1 - 1e-15, par) <= xx) return(1)
    if (q(1e-15, par) > xx) return(0)
    for (i in seq_len(iter)) {
      mid <- (lo + hi) / 2
      if (q(mid, par) <= xx) lo <- mid else hi <- mid
    }
    (lo + hi) / 2
  }, double(1))
}
