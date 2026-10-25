source("mc_core.R"); source("mc_engine.R")
N <- 10000; T <- 40; sc <- gen_scenarios(N, T, 20261025, "lhs"); y <- vofi_engine(sc, par_default)$kpi$endwert_diff
first_order_binned <- function(x, y, bins = 30) {
  g <- if (length(unique(x)) <= bins) factor(x) else cut(rank(x, ties.method = "first"), bins, labels = FALSE)
  m <- tapply(y, g, mean); w <- tabulate(as.integer(factor(g))) / length(y)
  sum(w * (m - mean(y))^2) / var(y)
}
X <- data.frame(baukosten = sc$cost_factor, verzug = sc$delay_m, foerderung = sc$subsidy_ok, perf_gap = sc$perf_factor,
  lebensdauer_wp = round(sc$lifetime_hp), exit_eps = sc$exit_eps, zins_ende = sc$rate[, T], zins_anschluss10 = sc$rate[,10],
  inflation_mittel = rowMeans(sc$infl), miete_wachstum = rowMeans(sc$rent_g), co2_szenario = attr(sc$co2, "scenario"))
s <- sapply(X, first_order_binned, y = y); print(round(sort(s, decreasing = TRUE), 3)); cat("Summe", round(sum(s), 3), "\n")
