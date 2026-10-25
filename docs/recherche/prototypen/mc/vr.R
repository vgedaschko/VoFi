source("mc_core.R"); source("mc_engine.R"); T <- 40; parA <- par_default
rep_est <- function(method, anti = FALSE, R = 100, n = 1000, rep = 1L) sapply(1:R, function(r) {
  s <- gen_scenarios(n, T, 5000 + r, method, antithetic = anti, replicates = rep); k <- vofi_engine(s, parA)$kpi
  c(mean = mean(k$endwert), q05 = quantile(k$endwert, .05, names = FALSE), q50 = median(k$endwert), ploss = mean(k$endwert_diff < 0), pdscr = mean(k$min_dscr < 1)) })
res <- rbind(pseudo = apply(rep_est("pseudo"), 1, sd), lhs_1 = apply(rep_est("lhs", rep = 1L), 1, sd),
             lhs_10 = apply(rep_est("lhs", rep = 10L), 1, sd), antithetisch = apply(rep_est("pseudo", TRUE), 1, sd))
print(signif(res, 3)); cat("Varianzreduktionsfaktor ggü. pseudo:\n"); print(round(sweep(res, 2, res[1, ], function(a, b) (b / a)^2), 2))
