source("mc_core.R"); source("mc_engine.R")
mc_convergence <- function(y, checkpoints = unique(round(10^seq(2, log10(length(y)), length.out = 25))), probs = c(0.05, 0.5)) {
  cs <- cumsum(y); cs2 <- cumsum(y^2)
  do.call(rbind, lapply(checkpoints, function(n) {
    m <- cs[n] / n; s <- sqrt((cs2[n] - n * m^2) / (n - 1))
    q <- quantile(y[seq_len(n)], probs, names = FALSE)
    data.frame(n = n, mean = m, lo = m - 1.96 * s / sqrt(n), hi = m + 1.96 * s / sqrt(n),
               t(setNames(q, paste0("q", probs * 100))))
  }))
}
quantile_ci <- function(y, p, level = 0.95) {
  n <- length(y); s <- sort(y); a <- (1 - level) / 2
  k <- qbinom(c(a, 1 - a), n, p)
  c(q = quantile(y, p, names = FALSE), lo = s[max(k[1], 1)], hi = s[min(k[2] + 1, n)])
}
mc_summary <- function(k, hurdle = 0.04, alpha = 0.05) {
  d <- k$endwert_diff; q <- quantile(d, alpha, names = FALSE); n <- nrow(k)
  p <- function(x) c(p = mean(x), se = sqrt(mean(x) * (1 - mean(x)) / n))
  list(endwert = c(mean = mean(k$endwert), sd = sd(k$endwert), quantile(k$endwert, c(.05, .25, .5, .75, .95))),
       p_verlust = p(d < 0), p_rendite_unter_huerde = p(!is.na(k$vofi_rendite) & k$vofi_rendite < hurdle | is.na(k$vofi_rendite)),
       var = -q, cvar = -mean(d[d <= q]), p_liquiditaet = p(k$liquiditaetsengpass), p_dscr_unter_1 = p(k$min_dscr < 1))
}
sc <- gen_scenarios(10000, 40, 1, "pseudo"); k <- vofi_engine(sc, par_default)$kpi
cv <- mc_convergence(k$endwert); print(tail(cv, 3)); print(quantile_ci(k$endwert, 0.05)); str(mc_summary(k))
library(ggplot2)
pl <- ggplot(cv, aes(n, mean)) + geom_ribbon(aes(ymin = lo, ymax = hi), alpha = .2) + geom_line() + scale_x_log10() +
  labs(x = "Anzahl Simulationen", y = "Mittlerer Endwert (EUR)", title = "Konvergenz des Mittelwerts mit 95-%-Konfidenzband")
ggsave("conv.png", pl, width = 6, height = 3.5)
r <- vofi_engine(sc, par_default, "bands")$bands$bestandssaldo
fan <- data.frame(t = 0:40, r); names(fan) <- c("t","p05","p25","p50","p75","p95")
pf <- ggplot(fan, aes(t)) + geom_ribbon(aes(ymin = p05, ymax = p95), alpha = .2) + geom_ribbon(aes(ymin = p25, ymax = p75), alpha = .35) + geom_line(aes(y = p50)) +
  labs(x = "Jahr", y = "Bestandssaldo (EUR)", title = "Fächerdiagramm Bestandssaldo (5/25/50/75/95 %)")
ggsave("fan.png", pf, width = 6, height = 3.5); cat("ok\n")
