source("mc_core.R")
seed <- 20261025; N <- 20000
# Verteilungen
u <- draw_u(N, seed, "baukosten", "lhs")
x <- q_pert(u, 0.95, 1.05, 1.40); cat("PERT mean", mean(x), "theor", (0.95+4*1.05+1.4)/6, "\n")
x <- q_triangular(u, 0, 3, 12); cat("Tri mean", mean(x), "theor", 5, "\n")
p <- lnorm_par(median=1.05, p90=1.25); x <- qlnorm(u, p[1], p[2]); cat("lnorm median", median(x), "p90", quantile(x,.9), "\n")
x <- q_truncnorm(u, 0.02, 0.01, 0, Inf); cat("truncnorm min", min(x), "mean", mean(x), "\n")
x <- q_discrete(u, c(0, 0.15, 0.20), c(0.2, 0.5, 0.3)); print(table(x)/N)
# LHS Stratifikation
print(all(table(floor(u*N)) == 1)); print(length(unique(floor(u*N))))
# Reproduzierbarkeit
print(identical(draw_u(10, seed, "a"), draw_u(10, seed, "a"))); print(identical(draw_u(10, seed, "a"), draw_u(10, seed, "b")))
# Globaler RNG unberührt?
set.seed(1); a1 <- runif(1); set.seed(1); invisible(draw_u(5, seed, "x")); a2 <- runif(1); print(a1 == a2)
# Copula vs IC
Rs <- matrix(c(1,.5,.3, .5,1,.6, .3,.6,1),3); 
U <- sapply(c("p1","p2","p3"), function(nm) draw_u(N, seed, nm, "lhs"))
Uc <- gauss_copula(U, Rs); cat("Copula Spearman\n"); print(round(cor(Uc, method="spearman"),3))
cat("LHS-Strat nach Copula, Spalte 2:", length(unique(floor(Uc[,2]*N))), "von", N, "\n")
X <- cbind(q_pert(U[,1], .95,1.05,1.4), q_triangular(U[,2],0,3,12), qnorm(U[,3]))
Xic <- iman_conover(X, Rs, seed); cat("IC Spearman\n"); print(round(cor(Xic, method="spearman"),3))
print(all.equal(sort(Xic[,2]), sort(X[,2])))
# nicht-PD Matrix
Rbad <- matrix(c(1,.9,-.6, .9,1,.2, -.6,.2,1),3); print(eigen(Rbad)$values); Rf <- near_pd_corr(Rbad); print(round(Rf,3)); print(eigen(Rf)$values)
print(round(as.matrix(Matrix::nearPD(Rbad, corr=TRUE)$mat),3))
# Prozesse
T <- 40
Z <- draw_shocks(N, T, seed, "infl")
g <- sim_ar1(Z, 0.02, 0.6, 0.01); cat("AR1 mean", mean(g[,40]), "sd", sd(g[,40]), "theor", 0.01/sqrt(1-.36), " acf", cor(g[,39], g[,40]), "\n")
r <- sim_vasicek(draw_shocks(N,T,seed,"zins"), 0.04, 0.035, 0.15, 0.008, floor=0.005)
cat("Vasicek E[r_10]", mean(r[,10]), "theor", 0.035+(0.04-0.035)*exp(-1.5), " min", min(r), " sd_stat", sd(r[,40]), "theor", 0.008/sqrt(0.3), "\n")
P <- sim_gbm(draw_shocks(N,T,seed,"gas"), 0.12, 0.02, 0.12); cat("GBM E[P_T]/P0", mean(P[,40])/0.12, "theor", 1.02^40, "\n")
tr <- 0.12*1.02^(1:T); M <- sim_mr_trend(draw_shocks(N,T,seed,"gas2"), tr, 0.7, 0.12); cat("MR-Trend ratio", mean(M[,40])/tr[40], "\n")
# Kreuzkorrelation
Zs <- correlate_shocks(list(a=draw_shocks(N,T,seed,"a"), b=draw_shocks(N,T,seed,"b")), matrix(c(1,.5,.5,1),2)); cat("shock corr", cor(as.vector(Zs$a), as.vector(Zs$b)), "\n")
ga <- sim_ar1(Zs$a, 0, .9, 1); gb <- sim_ar1(Zs$b, 0, .3, 1); cat("level corr", cor(ga[,40], gb[,40]), "theor", .5*sqrt((1-.81)*(1-.09))/(1-.27), "\n")
# Szenario-Mix
paths <- rbind(niedrig = approx(c(2026,2030,2045,2066), c(60,70,90,100), xout=2027:2066)$y,
               mittel  = approx(c(2026,2030,2045,2066), c(60,120,200,250), xout=2027:2066)$y,
               hoch    = approx(c(2026,2030,2045,2066), c(60,200,300,350), xout=2027:2066)$y)
co2 <- sim_scenario_mix(draw_u(N, seed, "co2_szen"), paths, c(.3,.5,.2), Z = draw_shocks(N,T,seed,"co2"), sigma=.15, phi=.8)
print(table(attr(co2,"scenario"))/N); cat("CO2 mean 2030", mean(co2[,4]), "\n")
# Bootstrap
hist <- cbind(infl = c(5.0,4.5,2.7,1.7,1.4,1.9,1.0,0.6,1.4,2.0,1.4,1.0,1.7,1.5,1.6,2.3,2.6,0.3,1.1,2.1,2.0,1.4,1.0,0.5,0.5,1.5,1.8,1.4,0.5,3.1,6.9,5.9,2.2,2.2)/100)
B <- sim_block_bootstrap(hist, N, T, block = 4, seed = seed, recenter = 0.02); cat("Bootstrap mean", mean(B$infl), "\n")
print(round(calibrate_ar1(hist[,1]),4))
