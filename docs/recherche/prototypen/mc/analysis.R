source("mc_core.R"); source("mc_engine.R")
N <- 10000; T <- 40; seed <- 20261025
parA <- par_default                                         # Variante A: Sanierung/Neubau effizient
parB <- modifyList(par_default, list(invest_base = 2.85e6, saving = 0, hp_cost = 0.06e6, subsidy = 0, loan2 = 0.35e6))  # Variante B
sc  <- gen_scenarios(N, T, seed, "lhs")
sc2 <- gen_scenarios(N, T, seed + 1, "lhs")
A  <- vofi_engine(sc, parA)$kpi; B <- vofi_engine(sc, parB)$kpi; B2 <- vofi_engine(sc2, parB)$kpi
d_crn <- A$endwert - B$endwert; d_ind <- A$endwert - B2$endwert
cat(sprintf("Mittel Differenz CRN %.0f (SE %.0f) | unabh. %.0f (SE %.0f) | Var-Reduktionsfaktor %.1f\n",
  mean(d_crn), sd(d_crn)/sqrt(N), mean(d_ind), sd(d_ind)/sqrt(N), var(d_ind)/var(d_crn)))
cat(sprintf("P(A>B) CRN %.3f (SE %.3f); unabh. %.3f; cor(A,B) %.3f\n", mean(d_crn>0), sqrt(mean(d_crn>0)*(1-mean(d_crn>0))/N), mean(d_ind>0), cor(A$endwert,B$endwert)))
# Stochastische Dominanz 1. Ordnung (Gitter)
grid <- quantile(c(A$endwert, B$endwert), seq(0.001, 0.999, length.out = 500))
FA <- ecdf(A$endwert)(grid); FB <- ecdf(B$endwert)(grid)
cat("FSD A über B:", all(FA <= FB + 1e-12), " max(FA-FB)", max(FA-FB), "\n")
iA <- cumsum(FA * c(0, diff(grid))); iB <- cumsum(FB * c(0, diff(grid)))
cat("SSD A über B:", all(iA <= iB + 1e-6), "\n")
# Risiko-Kennzahlen
x <- A$endwert_diff; a <- 0.05; q <- quantile(x, a, names = FALSE)
cat(sprintf("VaR5%% (Verlust ggü. Opportunität) %.0f; CVaR5%% %.0f; P(Verlust) %.4f\n", -q, -mean(x[x <= q]), mean(x < 0)))
# Konfidenzintervalle
se_mean <- sd(A$endwert)/sqrt(N)
p <- 0.05; k <- qbinom(c(0.025, 0.975), N, p); s <- sort(A$endwert)
cat(sprintf("Mittel %.0f +- %.0f; Q5 %.0f KI [%.0f, %.0f]\n", mean(A$endwert), 1.96*se_mean, quantile(A$endwert, .05), s[k[1]], s[k[2]+1]))
# LHS vs Pseudo: Streuung des Mittelwertschätzers über Replikationen
rep_est <- function(method, R = 40, n = 1000) sapply(1:R, function(r) {
  s <- gen_scenarios(n, T, 1000 + r, method); k <- vofi_engine(s, parA)$kpi
  c(mean = mean(k$endwert), q05 = quantile(k$endwert, .05, names = FALSE), ploss = mean(k$endwert_diff < 0)) })
rl <- rep_est("lhs"); rp <- rep_est("pseudo")
cat("SD Schätzer (R=40, n=1000) LHS vs pseudo:\n"); print(round(rbind(lhs = apply(rl,1,sd), pseudo = apply(rp,1,sd)), 1))
# Antithetisch
ra <- sapply(1:40, function(r) { s <- gen_scenarios(1000, T, 2000 + r, "pseudo", antithetic = TRUE); mean(vofi_engine(s, parA)$kpi$endwert) })
cat("SD Mittel antithetisch:", round(sd(ra),1), "\n")
# Globale Sensitivität
summ <- data.frame(baukosten = sc$cost_factor, verzug = sc$delay_m, foerderung = sc$subsidy_ok,
                   perf_gap = sc$perf_factor, lebensdauer_wp = sc$lifetime_hp, exit_eps = sc$exit_eps,
                   zins_anschluss10 = sc$rate[, 10], zins_ende = sc$rate[, T], inflation_mittel = rowMeans(sc$infl),
                   miete_wachstum = rowMeans(sc$rent_g), co2_szenario = attr(sc$co2, "scenario"),
                   leerstand_mittel = rowMeans(sc$vac))
y <- A$endwert_diff
spear <- sapply(summ, function(v) cor(v, y, method = "spearman"))
src <- function(X, y) { Xs <- scale(X); ys <- as.vector(scale(y)); f <- lm(ys ~ Xs); list(coef = setNames(coef(f)[-1], colnames(X)), r2 = summary(f)$r.squared) }
prcc <- function(X, y) { R <- apply(X, 2, rank); ry <- rank(y); sapply(seq_len(ncol(R)), function(j) {
  Z <- cbind(1, R[, -j]); ex <- lm.fit(Z, R[, j])$residuals; ey <- lm.fit(Z, ry)$residuals; cor(ex, ey) }) }
s1 <- src(as.matrix(summ), y); p1 <- prcc(as.matrix(summ), y)
srcr <- src(apply(as.matrix(summ),2,rank), rank(y))
print(round(data.frame(spearman = spear, src = s1$coef, prcc = p1, srrc = srcr$coef), 3)); cat("R2 SRC", round(s1$r2,3), " R2 SRRC", round(srcr$r2,3), "\n")
t_s <- system.time(prcc(as.matrix(summ), y))[[3]]; cat("PRCC Zeit", t_s, "s\n")
# Tornado in einem Lauf: Basis + 2 Zeilen je Parameter
base <- gen_scenarios(1, T, seed, degenerate = TRUE)
lo_hi <- list(cost_factor = c(0.98, 1.22), delay_m = c(0.5, 7), perf_factor = c(0.55, 0.95), lifetime_hp = c(14, 22), exit_eps = c(-0.005, 0.005))
nr <- 1 + 2 * length(lo_hi)
scT <- lapply(base, function(x) if (is.matrix(x)) x[rep(1, nr), , drop = FALSE] else rep(x, nr))
i <- 2; for (nm in names(lo_hi)) { scT[[nm]][i] <- lo_hi[[nm]][1]; scT[[nm]][i+1] <- lo_hi[[nm]][2]; i <- i + 2 }
t_t <- system.time(kt <- vofi_engine(scT, parA)$kpi)[[3]]
tor <- data.frame(param = names(lo_hi), tief = kt$endwert_diff[seq(2, nr, 2)] - kt$endwert_diff[1], hoch = kt$endwert_diff[seq(3, nr, 2)] - kt$endwert_diff[1])
print(tor); cat("Tornado-Lauf (11 Zeilen):", t_t, "s\n")
# Kritischer Wert via uniroot: Baukostenfaktor, bei dem endwert_diff = 0
f <- function(cf) { s <- base; s$cost_factor <- cf; vofi_engine(s, parA)$kpi$endwert_diff }
t_u <- system.time(ur <- uniroot(f, c(0.8, 3), tol = 1e-6))[[3]]
cat(sprintf("Kritischer Baukostenfaktor: %.4f (%d Iterationen, %.3f s)\n", ur$root, ur$iter, t_u))
