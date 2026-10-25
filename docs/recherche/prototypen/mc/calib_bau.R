args <- commandArgs(TRUE); source(file.path(args[2], "mc_core.R"))
d <- read.csv(args[1], stringsAsFactors = FALSE)
p <- d[d$indic_bt == "PRC_PRR" & d$unit == "PCH_SM", c("TIME_PERIOD", "OBS_VALUE")]; p <- p[order(p$TIME_PERIOD), ]
cat("Baupreise Wohngebäude DE (PRC_PRR, Veränderung ggü. Vorjahr %):", min(p$TIME_PERIOD), "-", max(p$TIME_PERIOD), "\n")
print(setNames(p$OBS_VALUE, p$TIME_PERIOD)[p$TIME_PERIOD >= 1996])
g <- p$OBS_VALUE[p$TIME_PERIOD >= 1997 & p$TIME_PERIOD <= 2025] / 100
cat("1997-2025 mean", round(100*mean(g),2), "sd", round(100*sd(g),2), "\n"); print(round(calibrate_ar1(g), 4))
h <- read.csv(file.path(args[3], "hicp_de.csv"))[, c("TIME_PERIOD","OBS_VALUE")]; yr <- substr(h$TIME_PERIOD,1,4)
inf <- tapply(h$OBS_VALUE, yr, mean)[as.character(1997:2025)] / 100
cat("Korrelation Baupreis- vs. HICP-Rate 1997-2025:", round(cor(g, inf), 2), "; mittlere Prämie über HICP (pp):", round(100*mean(g - inf), 2), "\n")
f <- lm(g ~ inf); print(round(coef(f), 3)); cat("Residuen: sd", round(sd(residuals(f)), 4), " AR1", round(cor(residuals(f)[-1], residuals(f)[-length(g)]), 2), "\n")
