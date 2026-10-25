source("mc_core.R"); source("mc_engine.R")
# replizierte LHS: r unabhängige LHS-Blöcke der Größe n/r
draw_u <- function(n, seed, name, method = c("pseudo", "lhs"), antithetic = FALSE, replicates = 10) {
  method <- match.arg(method)
  with_stream(seed, name, {
    if (method == "pseudo") return(runif(n))
    m <- n %/% replicates
    unlist(lapply(seq_len(replicates), function(b) (sample.int(m) - runif(m)) / m))
  })
}
draw_shocks <- function(n, T, seed, name, method = "pseudo", antithetic = FALSE, replicates = 10) {
  with_stream(seed, paste0("shock:", name), {
    if (method != "lhs") return(matrix(rnorm(n * T), n, T))
    m <- n %/% replicates
    vapply(seq_len(T), function(t) qnorm(unlist(lapply(seq_len(replicates), function(b) (sample.int(m) - runif(m)) / m))), numeric(n))
  })
}
T <- 40; N <- 10000; R <- 30
est <- t(sapply(1:R, function(r) {
  s <- gen_scenarios(N, T, 9000 + r, "lhs"); y <- vofi_engine(s, par_default)$kpi$endwert
  blk <- rep(1:10, each = N / 10); bm <- tapply(y, blk, mean)
  c(mean = mean(y), se_naiv = sd(y) / sqrt(N), se_rep = sd(bm) / sqrt(10)) }))
cat(sprintf("wahre SD des Mittelwerts (R=%d): %.0f | Ø naiver SE: %.0f | Ø SE aus Replikaten: %.0f\n", R, sd(est[, "mean"]), mean(est[, "se_naiv"]), mean(est[, "se_rep"])))
iman_conover_global <- iman_conover
iman_conover <- function(X, R_spearman, seed, name = "iman_conover", replicates = 10) {
  m <- nrow(X) %/% replicates
  for (b in seq_len(replicates)) { ix <- (b - 1) * m + seq_len(m); X[ix, ] <- iman_conover_global(X[ix, , drop = FALSE], R_spearman, seed, paste0(name, ":", b)) }
  X
}
est <- t(sapply(1:R, function(r) {
  s <- gen_scenarios(N, T, 9000 + r, "lhs"); y <- vofi_engine(s, par_default)$kpi$endwert
  blk <- rep(1:10, each = N / 10); bm <- tapply(y, blk, mean)
  c(mean = mean(y), se_naiv = sd(y) / sqrt(N), se_rep = sd(bm) / sqrt(10)) }))
cat(sprintf("IC je Block: wahre SD des Mittelwerts: %.0f | Ø naiver SE: %.0f | Ø SE aus Replikaten: %.0f\n", sd(est[, "mean"]), mean(est[, "se_naiv"]), mean(est[, "se_rep"])))
