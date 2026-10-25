args <- commandArgs(TRUE)
source(file.path(args[2], "mc_core.R"))
x <- readLines(args[1], encoding = "UTF-8", warn = FALSE)
x <- x[grepl("^[0-9]{4}-[0-9]{2};", x)]
d <- do.call(rbind, strsplit(x, ";"))
r <- as.numeric(sub(",", ".", d[, 2])) / 100; ym <- d[, 1]
cat("Monate:", length(r), ym[1], "bis", ym[length(ym)], "\n")
yr <- as.integer(substr(ym, 1, 4))
ann <- tapply(r, yr, mean); print(round(100 * ann, 2))
full <- ann[names(ann) <= "2025"]
cat("Jahresmittel: mean", round(100*mean(full),2), " sd jährl. Änderungen (pp)", round(100*sd(diff(full)),2), "\n")
cat("Vasicek (Jahresdaten 2003-2025):\n"); print(round(calibrate_vasicek(full), 4))
# Monatsdaten -> kappa/sigma je Jahr
pm <- calibrate_ar1(r); km <- -log(pm[["phi"]]) * 12; sm <- pm[["sigma_e"]] * sqrt(2 * km / (1 - pm[["phi"]]^2) )
cat(sprintf("Vasicek (Monatsdaten): theta %.4f kappa %.3f p.a. sigma %.4f p.a. Halbwertszeit %.1f J\n", pm[["mu"]], km, sm * sqrt(1), log(2)/km))
cat("sd 12-Monats-Änderungen (pp):", round(100 * sd(diff(r, lag = 12)), 2), "\n")
cat("letzte Werte:", paste(tail(ym, 6), round(100 * tail(r, 6), 2), collapse = " | "), "\n")
