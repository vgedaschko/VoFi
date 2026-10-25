source_lines <- readLines("bench_engine.R")
# nur Funktionsdefinitionen laden (bis zum Abschnitt "Lauf")
stop_at <- grep("^# -+ Lauf", source_lines)[1]
eval(parse(text = source_lines[1:(stop_at - 1)]))

# Optimierte Treiber: kumulierte Produkte spaltenweise statt apply() zeilenweise
col_cumprod <- function(x) { for (t in 2:ncol(x)) x[, t] <- x[, t - 1] * x[, t]; x }
col_cumsum  <- function(x) { for (t in 2:ncol(x)) x[, t] <- x[, t - 1] + x[, t]; x }
sample_drivers_fast <- function(n, T, seed = 1) {
  set.seed(seed)
  L <- chol(matrix(c(1, 0.3, 0.3, 1), 2))
  z1 <- matrix(rnorm(n * T), n, T); z2 <- matrix(rnorm(n * T), n, T)
  z_rent <- z1; z_en <- z1 * L[1, 2] + z2 * L[2, 2]
  g <- matrix(0, n, T); prev <- rep(0.02, n)
  for (t in seq_len(T)) { prev <- 0.02 + 0.6 * (prev - 0.02) + 0.01 * z_rent[, t]; g[, t] <- prev }
  rent_index <- col_cumprod(1 + g)
  en_index <- exp(col_cumsum(0.03 - 0.5 * 0.1^2 + 0.1 * z_en))
  r <- matrix(0, n, T); rr <- rep(0.035, n); zr <- matrix(rnorm(n * T), n, T)
  for (t in seq_len(T)) { rr <- rr + 0.15 * (0.04 - rr) + 0.008 * zr[, t]; r[, t] <- pmax(rr, 0) }
  u <- runif(n); a <- 0.95; m <- 1.05; b <- 1.30; Fc <- (m - a) / (b - a)
  cost_factor <- ifelse(u < Fc, a + sqrt(u * (b - a) * (m - a)), b - sqrt((1 - u) * (b - a) * (b - m)))
  list(rent_index = rent_index, energy_index = en_index, rate = r, cost_factor = cost_factor,
       vacancy = matrix(rbeta(n * T, 2, 60), n, T), resid_factor = rlnorm(n, 0, 0.15))
}
cat("== Treiber: apply() vs. spaltenweise Schleife (N=10000, T=40) ==\n")
print(bench::mark(apply_zeilen = sample_drivers(1e4, 40), spaltenweise = sample_drivers_fast(1e4, 40),
                  iterations = 5, check = FALSE)[, c("expression", "median", "mem_alloc")])

sample_drivers <- sample_drivers_fast
cat("\n== Gesamtlauf A mit optimierten Treibern ==\n")
for (T in c(40, 80)) {
  bm <- bench::mark(run_A(1e4, T), iterations = 5, check = FALSE)
  cat(sprintf("N=10000, T=%d: median %s, mem_alloc %s\n", T, format(bm$median), format(bm$mem_alloc)))
}
gc(reset = TRUE); invisible(run_A(1e4, 80)); g <- gc()
cat("Peak-Speicher (Vcells, MB) nach Lauf N=10000,T=80:", g[2, 6], "\n")

cat("\n== Anti-Pattern: deterministische Engine N-mal aufrufen (MC als aeussere Schleife) ==\n")
t1 <- system.time(for (i in 1:1000) run_A(1, 40, seed = i, keep_ledger = FALSE))[["elapsed"]]
cat(sprintf("1000 x run_A(n=1): %.2f s -> hochgerechnet 10000: %.1f s\n", t1, t1 * 10))

cat("\n== Skalierung N (T=40, nur KPI) ==\n")
for (n in c(1, 100, 1000, 1e4, 5e4)) {
  bm <- bench::mark(run_A(n, 40, keep_ledger = FALSE), iterations = 3, check = FALSE)
  cat(sprintf("N=%6d: %s\n", n, format(bm$median)))
}

cat("\n== Parallelisierung: N=100000, T=40, Chunks a 10000 (future.apply, multisession 4) ==\n")
suppressPackageStartupMessages({library(future); library(future.apply)})
t_seq <- system.time(res_seq <- lapply(1:10, function(k) run_A(1e4, 40, seed = k, keep_ledger = FALSE)$endwert))[["elapsed"]]
plan(multisession, workers = 4)
t_par <- system.time(res_par <- future_lapply(1:10, function(k) run_A(1e4, 40, seed = k, keep_ledger = FALSE)$endwert,
                                              future.seed = NULL, future.globals = TRUE))[["elapsed"]]
plan(sequential)
cat(sprintf("sequenziell: %.2f s, parallel(4): %.2f s, identisch: %s\n", t_seq, t_par,
            identical(unlist(res_seq), unlist(res_par))))

cat("\n== Profil Gesamtlauf (T=40) ==\n")
Rprof(tf <- tempfile(), interval = 0.005); for (i in 1:5) run_A(1e4, 40); Rprof(NULL)
s <- summaryRprof(tf)$by.self; print(head(s, 8))
