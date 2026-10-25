args <- commandArgs(TRUE); dir <- args[1]; source(file.path(args[2], "mc_core.R"))
rd <- function(it) { d <- read.csv(file.path(dir, paste0("inx_", it, ".csv")))[, c("TIME_PERIOD", "OBS_VALUE")]
  yr <- as.integer(substr(d$TIME_PERIOD, 1, 4)); a <- tapply(d$OBS_VALUE, yr, mean); a[as.character(1996:2025)] }
lab <- c("000000" = "VPI_gesamt", "045100" = "Strom", "045200" = "Gas", "045300" = "Heizoel", "045500" = "Fernwaerme", "041000" = "Miete")
I <- sapply(names(lab), rd); colnames(I) <- lab[colnames(I)]
g <- diff(log(I))   # log-Wachstumsraten 1997-2025
st <- function(x) c(mean = mean(x), sd = sd(x), ar1 = cor(x[-1], x[-length(x)]))
cat("Log-Jahreswachstum 1997-2025 (Jahresdurchschnitte):\n"); print(round(t(apply(g, 2, st)), 3))
cat("bis 2019:\n"); print(round(t(apply(g[rownames(g) <= "2019", ], 2, st)), 3))
cat("Korrelationen der Jahreswachstumsraten 1997-2025:\n"); print(round(cor(g), 2))
# Log-Preis relativ zu VPI (real) : AR(1)-Mean-Reversion um Trend?
for (k in c("Strom", "Gas", "Heizoel")) { y <- log(I[, k] / I[, "VPI_gesamt"]); tt <- seq_along(y); res <- residuals(lm(y ~ tt))
  p <- calibrate_ar1(res); cat(sprintf("%-8s realer Trend %.3f p.a.; Abweichung AR1 phi %.2f sigma_e %.3f\n", k, coef(lm(y ~ tt))[2], p[["phi"]], p[["sigma_e"]])) }
