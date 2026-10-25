source("mc_core.R"); source("mc_engine.R")
N <- 10000; T <- 40; seed <- 20261025; par <- par_default
tm <- function(expr) { g <- gc(); t0 <- proc.time()[["elapsed"]]; force(expr); proc.time()[["elapsed"]] - t0 }
t_gen <- system.time(sc <- gen_scenarios(N, T, seed, "lhs"))[["elapsed"]]
cat("Szenariogenerierung N=10000,T=40:", t_gen, "s; Größe", format(object.size(sc), units="MB"), "\n")
for (s in c("kpi","bands","full")) {
  tt <- numeric(5); for (r in 1:5) tt[r] <- system.time(res <- vofi_engine(sc, par, s))[["elapsed"]]
  cat(sprintf("Engine store=%-5s: median %.3f s (min %.3f)  Objekt %s\n", s, median(tt), min(tt), format(object.size(res), units="MB")))
}
res <- vofi_engine(sc, par, "full")
cat("max |Finanzierungssaldo|:", max(abs(res$full$finanzierungssaldo)), "\n")
cat("GA*KK > 0 gleichzeitig:", any(res$full$bestand_ga > 0 & res$full$bestand_kk > 0), "\n")
k <- res$kpi; print(summary(k$endwert)); print(summary(k$vofi_rendite))
cat("P(EW<EW_opp)", mean(k$endwert_diff < 0), " P(minDSCR<1)", mean(k$min_dscr < 1), " P(Liq)", mean(k$liquiditaetsengpass), " NA-Rendite", mean(is.na(k$vofi_rendite)), "\n")
# N mal deterministisch (N=1-Aufrufe)
sc1 <- function(i) lapply(sc, function(x) if (is.matrix(x)) x[i, , drop = FALSE] else x[i])
M <- 500
t_loop <- system.time(for (i in 1:M) vofi_engine(sc1(i), par, "kpi"))[["elapsed"]]
cat(sprintf("Schleife N=1-Aufrufe: %.2f ms/Lauf -> hochgerechnet 10000 Läufe: %.1f s\n", 1000*t_loop/M, t_loop/M*N))
# Prüfen: identische Ergebnisse
r1 <- do.call(rbind, lapply(1:20, function(i) vofi_engine(sc1(i), par, "kpi")$kpi))
cat("N=1 identisch zu vektorisiert:", isTRUE(all.equal(r1, res$kpi[1:20,], check.attributes=FALSE)), "\n")
# Skalierung
for (n in c(1000, 10000, 50000, 100000)) {
  scn <- gen_scenarios(n, T, seed, "pseudo")
  te <- system.time(vofi_engine(scn, par, "kpi"))[["elapsed"]]
  cat(sprintf("N=%6d: Engine kpi %.2f s\n", n, te))
}
for (TT in c(40, 80)) { p2 <- par; p2$T <- TT; scn <- gen_scenarios(10000, TT, seed, "pseudo"); te <- system.time(vofi_engine(scn, p2, "bands"))[["elapsed"]]; cat(sprintf("T=%d, N=10000 bands: %.2f s\n", TT, te)) }
# Parallel (future.apply, 4 Worker, Chunks)
library(future.apply); plan(multisession, workers = 4)
chunks <- split(seq_len(N), ceiling(seq_len(N) / 2500))
invisible(future_lapply(1:4, function(i) i))  # Worker warm
t_par <- system.time(rp <- future_lapply(chunks, function(ix) vofi_engine(lapply(sc, function(x) if (is.matrix(x)) x[ix, , drop = FALSE] else x[ix]), par, "kpi")$kpi,
                                        future.globals = list(sc = sc, par = par, vofi_engine = vofi_engine, annuity = annuity)))[["elapsed"]]
cat("Parallel 4 Worker (4 Chunks a 2500):", t_par, "s\n")
plan(sequential)
cat("parallel identisch:", isTRUE(all.equal(do.call(rbind, rp), res$kpi, check.attributes = FALSE)), "\n")
# Degeneriert = deterministisch
scd <- gen_scenarios(100, T, seed, degenerate = TRUE); rd <- vofi_engine(scd, par, "kpi")$kpi
r1d <- vofi_engine(lapply(scd, function(x) if (is.matrix(x)) x[1,,drop=FALSE] else x[1]), par, "kpi")$kpi
cat("Degeneriert: alle gleich", all(apply(rd, 2, function(x) length(unique(x)) == 1)), " = N=1:", isTRUE(all.equal(rd[1,], r1d, check.attributes=FALSE)), "\n")
print(r1d)
sessionInfo()$running
