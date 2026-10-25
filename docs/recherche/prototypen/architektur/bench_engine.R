# Prototyp-Benchmark: vektorisierte VoFi-Engine (N Simulationen x T Perioden)
# Varianten: (A) Matrix-Engine, Schleife ueber t vektorisiert ueber N
#            (A0) skalare Doppelschleife (pro Simulation)
#            (B) R6-Objekt pro Simulation
#            (C) tidy pipeline (dplyr/purrr) pro Simulation
suppressPackageStartupMessages({
  library(bench)
})

# ---------------------------------------------------------------- Treiber ----
sample_drivers <- function(n, T, seed = 1) {
  set.seed(seed)
  # Korrelierte Standardnormal-Schocks (Gauss-Copula) fuer Miete & Energie
  R <- matrix(c(1, 0.3, 0.3, 1), 2)
  L <- chol(R)
  z1 <- matrix(rnorm(n * T), n, T)
  z2 <- matrix(rnorm(n * T), n, T)
  z_rent <- z1 * L[1, 1]
  z_en   <- z1 * L[1, 2] + z2 * L[2, 2]
  # AR(1) Mietwachstum um 2 % p.a.
  g <- matrix(0, n, T)
  prev <- rep(0.02, n)
  for (t in seq_len(T)) {
    prev <- 0.02 + 0.6 * (prev - 0.02) + 0.01 * z_rent[, t]
    g[, t] <- prev
  }
  rent_index <- t(apply(1 + g, 1, cumprod))
  # GBM Energiepreisindex
  en_index <- exp(t(apply(0.03 - 0.5 * 0.1^2 + 0.1 * z_en, 1, cumsum)))
  # Vasicek-Anschlusszins
  r <- matrix(0, n, T)
  rr <- rep(0.035, n)
  zr <- matrix(rnorm(n * T), n, T)
  for (t in seq_len(T)) {
    rr <- rr + 0.15 * (0.04 - rr) + 0.008 * zr[, t]
    r[, t] <- pmax(rr, 0)
  }
  # skalare Zufallsvariablen je Simulation
  u <- runif(n)
  a <- 0.95; m <- 1.05; b <- 1.30  # Dreieck Baukostenfaktor
  Fc <- (m - a) / (b - a)
  cost_factor <- ifelse(u < Fc, a + sqrt(u * (b - a) * (m - a)),
                        b - sqrt((1 - u) * (b - a) * (b - m)))
  vacancy <- matrix(rbeta(n * T, 2, 60), n, T)
  list(rent_index = rent_index, energy_index = en_index, rate = r,
       cost_factor = cost_factor, vacancy = vacancy,
       resid_factor = rlnorm(n, 0, 0.15))
}

# ------------------------------------------------------- Komponenten (A) ----
# Konvention: Matrizen N x (T+1), Spalte 1 = Periode 0
comp_investment <- function(d, n, T) {
  m <- matrix(0, n, T + 1); m[, 1] <- -1.2e6 * d$cost_factor; m
}
comp_rent <- function(d, n, T) {
  cbind(0, 800 * 12 * 10.5 * d$rent_index * (1 - d$vacancy))
}
comp_opex <- function(rent) -0.03 * rent - cbind(0, matrix(800 * 2.5, nrow(rent), ncol(rent) - 1))
comp_maint <- function(d, n, T) {
  infl <- matrix(1.02^(seq_len(T)), n, T, byrow = TRUE)
  cbind(0, -800 * 14 * infl)
}
comp_energy <- function(d, n, T) cbind(0, -800 * 25 * 0.12 * d$energy_index)
comp_residual <- function(d, n, T) {
  m <- matrix(0, n, T + 1)
  m[, T + 1] <- 1.2e6 * 0.5 * d$resid_factor * d$rent_index[, T] / 1.6
  m
}
# Annuitaetendarlehen mit Zinsbindung und stochastischem Anschlusszins
inst_annuity <- function(d, n, T, amount, rate0, fix_years, term, grace = 0,
                         grant_share = 0) {
  bal <- rep(amount, n)
  rate <- rep(rate0, n)
  pay_out <- matrix(0, n, T + 1); pay_out[, 1] <- amount
  interest <- matrix(0, n, T + 1)
  principal <- matrix(0, n, T + 1)
  balance <- matrix(0, n, T + 1); balance[, 1] <- amount
  grant <- matrix(0, n, T + 1)
  ann <- if (rate0 > 0) amount * rate0 / (1 - (1 + rate0)^-(term - grace)) else amount / (term - grace)
  ann <- rep(ann, n)
  for (t in seq_len(T)) {
    if (t == fix_years + 1) {
      rate <- d$rate[, t]
      rem <- max(term - fix_years, 1)
      ann <- ifelse(rate > 0, bal * rate / (1 - (1 + rate)^-rem), bal / rem)
    }
    if (t == 1 && grant_share > 0) {
      g <- amount * grant_share
      grant[, t + 1] <- g
      bal <- bal - g
    }
    z <- bal * rate
    tilg <- if (t <= grace) 0 else pmin(pmax(ann - z, 0), bal)
    if (t == term) tilg <- bal
    bal <- bal - tilg
    interest[, t + 1] <- -z
    principal[, t + 1] <- -tilg
    balance[, t + 1] <- bal
  }
  list(auszahlung = pay_out, zinsen = interest, tilgung = principal,
       restschuld = balance, tilgungszuschuss_info = grant)
}

# ------------------------------------------------------ Ausgleichsschleife --
balance_loop <- function(exo, n, T, h = 0.02, s = 0.09, kk_limit = 5e4) {
  G <- matrix(0, n, T + 1)   # Guthabenstand
  K <- matrix(0, n, T + 1)   # Kontokorrentstand
  zh <- matrix(0, n, T + 1); zs <- matrix(0, n, T + 1)
  nach <- matrix(0, n, T + 1)  # Liquiditaetsluecke / Nachschuss
  anl <- matrix(0, n, T + 1); kkd <- matrix(0, n, T + 1)
  g <- pmax(exo[, 1], 0); k <- pmin(pmax(-exo[, 1], 0), kk_limit)
  nach[, 1] <- pmax(-exo[, 1] - kk_limit, 0)
  G[, 1] <- g; K[, 1] <- k
  anl[, 1] <- -g; kkd[, 1] <- k
  for (t in 2:(T + 1)) {
    zhi <- h * g; zsi <- s * k
    cf <- exo[, t] + zhi - zsi
    net <- g - k + cf
    g_new <- pmax(net, 0)
    k_new <- pmin(pmax(-net, 0), kk_limit)
    na <- pmax(-net - kk_limit, 0)
    anl[, t] <- -(g_new - g)
    kkd[, t] <- k_new - k
    zh[, t] <- zhi; zs[, t] <- -zsi; nach[, t] <- na
    g <- g_new; k <- k_new
    G[, t] <- g; K[, t] <- k
  }
  list(guthaben = G, kontokorrent = K, habenzins = zh, sollzins = zs,
       anlage_saldo = anl, kk_saldo = kkd, nachschuss = nach)
}

run_A <- function(n, T, seed = 1, keep_ledger = TRUE) {
  d <- sample_drivers(n, T, seed)
  rows <- list()
  rows$investition <- comp_investment(d, n, T)
  rows$miete <- comp_rent(d, n, T)
  rows$bewirtschaftung <- comp_opex(rows$miete)
  rows$instandhaltung <- comp_maint(d, n, T)
  rows$energie <- comp_energy(d, n, T)
  rows$restwert <- comp_residual(d, n, T)
  ek <- matrix(0, n, T + 1); ek[, 1] <- 4e5 + 0.2e6 * (d$cost_factor - 1) * 0
  rows$eigenkapital <- ek
  bank <- inst_annuity(d, n, T, 6e5, 0.038, 10, 30)
  kfw  <- inst_annuity(d, n, T, 1.5e5, 0.015, 10, 20, grace = 2, grant_share = 0.15)
  rows$bank_auszahlung <- bank$auszahlung; rows$bank_zins <- bank$zinsen; rows$bank_tilgung <- bank$tilgung
  rows$kfw_auszahlung <- kfw$auszahlung; rows$kfw_zins <- kfw$zinsen; rows$kfw_tilgung <- kfw$tilgung
  exo <- Reduce(`+`, rows)
  b <- balance_loop(exo, n, T)
  rows$habenzins <- b$habenzins; rows$sollzins <- b$sollzins
  rows$geldanlage <- b$anlage_saldo; rows$kontokorrent <- b$kk_saldo
  rows$nachschuss <- b$nachschuss
  saldo <- Reduce(`+`, rows)
  endwert <- b$guthaben[, T + 1] - b$kontokorrent[, T + 1] -
    bank$restschuld[, T + 1] - kfw$restschuld[, T + 1]
  ek0 <- 4e5 + rowSums(b$nachschuss)  # vereinfachte EK-Basis
  rendite <- ifelse(endwert > 0, (endwert / ek0)^(1 / T) - 1, NA_real_)
  res <- list(endwert = endwert, rendite = rendite,
              max_abs_saldo = max(abs(saldo)))
  if (keep_ledger) res$rows <- c(rows, list(guthaben = b$guthaben, kk = b$kontokorrent))
  res
}

# -------------------------------------------- (A0) skalare Doppelschleife ----
run_A0_balance <- function(exo, h = 0.02, s = 0.09, kk_limit = 5e4) {
  n <- nrow(exo); T1 <- ncol(exo)
  ew <- numeric(n)
  for (i in seq_len(n)) {
    g <- max(exo[i, 1], 0); k <- min(max(-exo[i, 1], 0), kk_limit)
    for (t in 2:T1) {
      net <- g - k + exo[i, t] + h * g - s * k
      if (net >= 0) { g <- net; k <- 0 } else { g <- 0; k <- min(-net, kk_limit) }
    }
    ew[i] <- g - k
  }
  ew
}

# ------------------------------------------------ (B) R6 pro Simulation ----
Konto <- R6::R6Class("Konto", public = list(
  g = 0, k = 0, h = 0.02, s = 0.09, lim = 5e4,
  initialize = function(cf0) {
    self$g <- max(cf0, 0); self$k <- min(max(-cf0, 0), self$lim)
  },
  step = function(cf) {
    net <- self$g - self$k + cf + self$h * self$g - self$s * self$k
    if (net >= 0) { self$g <- net; self$k <- 0 } else { self$g <- 0; self$k <- min(-net, self$lim) }
    invisible(self)
  },
  endwert = function() self$g - self$k
))
run_B_balance <- function(exo) {
  n <- nrow(exo); T1 <- ncol(exo); ew <- numeric(n)
  for (i in seq_len(n)) {
    kto <- Konto$new(exo[i, 1])
    for (t in 2:T1) kto$step(exo[i, t])
    ew[i] <- kto$endwert()
  }
  ew
}

# ------------------------------------ (C) tidy pipeline pro Simulation ------
run_C_balance <- function(exo) {
  suppressPackageStartupMessages({library(dplyr); library(tidyr); library(purrr)})
  n <- nrow(exo); T1 <- ncol(exo)
  df <- tibble(sim = rep(seq_len(n), each = T1), t = rep(0:(T1 - 1), n),
               cf = as.vector(t(exo)))
  step <- function(acc, cf) {
    g <- acc[1]; k <- acc[2]
    net <- g - k + cf + 0.02 * g - 0.09 * k
    if (net >= 0) c(net, 0) else c(0, min(-net, 5e4))
  }
  df %>% group_by(sim) %>% summarise(
    endwert = {
      st <- purrr::reduce(cf[-1], step, .init = c(max(cf[1], 0), min(max(-cf[1], 0), 5e4)))
      st[1] - st[2]
    }, .groups = "drop")
}

# ------------------------------------------------------------------- Lauf --
cat("== Plausibilitaet (deterministisch N=1, T=40) ==\n")
r1 <- run_A(1, 40)
cat("Endwert:", format(round(r1$endwert), big.mark = "."), " max|Finanzierungssaldo|:", r1$max_abs_saldo, "\n")

for (T in c(40, 80)) {
  cat(sprintf("\n== Variante A (Matrix-Engine) N=10000, T=%d ==\n", T))
  bm <- bench::mark(full = run_A(10000, T, keep_ledger = TRUE),
                    kpi_only = run_A(10000, T, keep_ledger = FALSE),
                    iterations = 5, check = FALSE, memory = TRUE)
  print(bm[, c("expression", "min", "median", "mem_alloc", "n_gc")])
  r <- run_A(10000, T)
  cat("max|Finanzierungssaldo| ueber alle Sims/Perioden:", r$max_abs_saldo, "\n")
  cat("Ledger-Groesse (MB):", round(as.numeric(object.size(r$rows)) / 2^20, 1),
      " Zeilen:", length(r$rows), "\n")
  cat("Endwert-Quantile:\n"); print(round(quantile(r$endwert, c(.05, .5, .95))))
}

# Einzelne Bausteine timen (T=40)
d <- sample_drivers(10000, 40)
cat("\n== Bausteine (N=10000, T=40) ==\n")
exo <- Reduce(`+`, list(comp_investment(d, 1e4, 40), comp_rent(d, 1e4, 40),
                        comp_maint(d, 1e4, 40), comp_energy(d, 1e4, 40)))
exo[, 1] <- exo[, 1] + 1.15e6
print(bench::mark(
  treiber = sample_drivers(10000, 40),
  annuitaet = inst_annuity(d, 1e4, 40, 6e5, 0.038, 10, 30),
  ausgleich = balance_loop(exo, 1e4, 40),
  iterations = 5, check = FALSE)[, c("expression", "min", "median", "mem_alloc")])

cat("\n== Ausgleichsschleife: Vergleich der Architekturen (T=40) ==\n")
ew_A <- { b <- balance_loop(exo, 1e4, 40); b$guthaben[, 41] - b$kontokorrent[, 41] }
t_A0 <- system.time(ew_A0 <- run_A0_balance(exo))[["elapsed"]]
exo_small <- exo[1:1000, ]
t_B <- system.time(ew_B <- run_B_balance(exo_small))[["elapsed"]]
exo_tiny <- exo[1:1000, ]
t_C <- system.time(ew_C <- run_C_balance(exo_tiny))[["elapsed"]]
t_Av <- median(replicate(5, system.time(balance_loop(exo, 1e4, 40))[["elapsed"]]))
cat(sprintf("A  vektorisiert   N=10000: %7.3f s\n", t_Av))
cat(sprintf("A0 skalar         N=10000: %7.3f s  (Abw. max %.2e)\n", t_A0, max(abs(ew_A - ew_A0))))
cat(sprintf("B  R6 pro Sim     N= 1000: %7.3f s  -> hochgerechnet N=10000: %6.2f s (Abw. %.2e)\n",
            t_B, t_B * 10, max(abs(ew_A[1:1000] - ew_B))))
cat(sprintf("C  dplyr/purrr    N= 1000: %7.3f s  -> hochgerechnet N=10000: %6.2f s (Abw. %.2e)\n",
            t_C, t_C * 10, max(abs(ew_A[1:1000] - ew_C$endwert))))
