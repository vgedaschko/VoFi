args <- commandArgs(TRUE); source(file.path(args[2], "mc_core.R"))
d <- read.csv(args[1], stringsAsFactors = FALSE)[, c("TIME_PERIOD", "OBS_VALUE")]
yr <- as.integer(substr(d$TIME_PERIOD, 1, 4)); cnt <- table(yr)
ann <- tapply(d$OBS_VALUE, yr, mean) / 100; ann <- ann[names(cnt)[cnt == 12]]
print(round(100 * ann, 1))
cat("1997-2025: mean", round(100 * mean(ann), 2), "sd", round(100 * sd(ann), 2), "\n"); print(round(calibrate_ar1(ann), 4))
a2 <- ann[names(ann) <= "2019"]; cat("bis 2019:\n"); print(round(calibrate_ar1(a2), 4))
cat("letzte Monate:", paste(tail(d$TIME_PERIOD, 4), tail(d$OBS_VALUE, 4), collapse = " | "), "\n")
