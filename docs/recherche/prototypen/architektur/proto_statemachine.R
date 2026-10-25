# Prototyp 3: Kredite als Zustandsautomaten IN der Periodenschleife (Memo 01, E9),
# Ausgleich ueber Aktionsketten (Memo 01, 3.2: Ue1..Ue4, D1..D4), Steuer-Slot, nicht aequidistantes Raster.
suppressPackageStartupMessages(library(bench))

make_grid <- function(construction_months = 12, years = 70) {
  delta <- c(0, rep(1 / 12, construction_months), rep(1, years))  # Periode 0 hat Laenge 0
  list(T = length(delta) - 1, delta = delta, tau = cumsum(delta))
}

# ---- Kredit-Zustandsautomat (Annuitaet, Teilvalutierung, tilgungsfreie Zeit, Zinsbindung, Tilgungszuschuss) ----
loan_annuity <- function(id, commit, draws_at, rate_pa, fix_until_tau, followup, tilg_rate, grace_periods, tz_share, tz_at) {
  init <- function(n) list(B = rep(0, n), A = rep(0, n), i_pa = rep(rate_pa, n), drawn = rep(0, n))
  step <- function(st, t, g, ctx) {
    n <- length(st$B); d <- g$delta[t + 1]
    # Zinssatz: nach Zinsbindung stochastischer Anschlusszins (Pfad je Simulation)
    if (g$tau[t + 1] > fix_until_tau && g$tau[t] <= fix_until_tau) {
      st$i_pa <- followup[, t + 1]
      st$A <- st$B * (st$i_pa + tilg_rate)            # keep_tilg_rate
    }
    Z <- st$B * st$i_pa * d                            # nominal: i * Delta
    D <- if (t %in% draws_at) rep(commit / length(draws_at), n) else rep(0, n)
    last_draw <- max(draws_at)
    Tl <- if (t > last_draw + grace_periods) pmin(pmax(st$A * d - Z, 0), st$B) else rep(0, n)
    if (t == last_draw + grace_periods) st$A <- (st$B + D) * (rate_pa + tilg_rate)
    st$B <- st$B + D - Tl
    TZ <- if (t == tz_at) pmin(commit * tz_share, st$B) else rep(0, n)
    st$B <- st$B - TZ
    list(state = st, flows = list(draw = D, interest = -Z, repay = -Tl), memo = list(grant = TZ))
  }
  list(id = id, init = init, step = step)
}

# ---- Ausgleichsaktionen (vektorisiert; nehmen Betrag, geben verbrauchten Teil zurueck) ----
act_od_repay   <- function(acc, amt) { x <- pmin(amt, acc$KK); acc$KK <- acc$KK - x; list(acc = acc, used = x, flow = -x, row = "od_repay") }
act_dep_invest <- function(acc, amt) { acc$G <- acc$G + amt; list(acc = acc, used = amt, flow = -amt, row = "dep_invest") }
act_dep_withdraw <- function(acc, amt) { x <- pmin(amt, pmax(acc$G - acc$Lmin, 0)); acc$G <- acc$G - x; list(acc = acc, used = x, flow = x, row = "dep_withdraw") }
act_od_draw    <- function(acc, amt) { x <- pmin(amt, pmax(acc$KL - acc$KK, 0)); acc$KK <- acc$KK + x; list(acc = acc, used = x, flow = x, row = "od_draw") }
act_equity_call <- function(acc, amt) list(acc = acc, used = amt, flow = amt, row = "equity_call")

engine <- function(n, g, exo, loans, h_pa = 0.02, s_pa = 0.09, KL = 5e4, tax_step = NULL, seed = 1) {
  T1 <- g$T + 1
  rows <- c("od_repay", "dep_invest", "dep_withdraw", "od_draw", "equity_call", "od_interest", "dep_interest", "tax")
  rec <- lapply(setNames(rows, rows), function(r) matrix(0, n, T1))
  for (l in loans) for (r in c("draw", "interest", "repay")) rec[[paste0("loan_", l$id, "_", r)]] <- matrix(0, n, T1)
  stockG <- stockKK <- stockB <- matrix(0, n, T1)
  acc <- list(G = rep(0, n), KK = rep(0, n), Lmin = 0, KL = KL)
  ls <- lapply(loans, function(l) l$init(n))
  surplus_chain <- list(act_od_repay, act_dep_invest)
  deficit_chain <- list(act_dep_withdraw, act_od_draw, act_equity_call)
  for (t in 0:g$T) {
    j <- t + 1; d <- g$delta[j]
    F <- exo[, j]
    for (k in seq_along(loans)) {
      r <- loans[[k]]$step(ls[[k]], t, g, NULL); ls[[k]] <- r$state
      for (nm in names(r$flows)) { rec[[paste0("loan_", loans[[k]]$id, "_", nm)]][, j] <- r$flows[[nm]]; F <- F + r$flows[[nm]] }
    }
    HZ <- acc$G * ((1 + h_pa)^d - 1); KZ <- acc$KK * ((1 + s_pa)^d - 1)
    S <- F + HZ - KZ
    St <- if (is.null(tax_step)) 0 else tax_step(t, F, HZ, KZ)
    S <- S + St
    sur <- pmax(S, 0); def <- pmax(-S, 0)
    for (a in surplus_chain) { r <- a(acc, sur); acc <- r$acc; sur <- sur - r$used; rec[[r$row]][, j] <- rec[[r$row]][, j] + r$flow }
    for (a in deficit_chain) { r <- a(acc, def); acc <- r$acc; def <- def - r$used; rec[[r$row]][, j] <- rec[[r$row]][, j] + r$flow }
    rec$od_interest[, j] <- -KZ; rec$dep_interest[, j] <- HZ; rec$tax[, j] <- St
    stockG[, j] <- acc$G; stockKK[, j] <- acc$KK; stockB[, j] <- Reduce(`+`, lapply(ls, `[[`, "B"))
  }
  saldo <- exo + Reduce(`+`, rec)
  list(EW = acc$G - acc$KK - stockB[, T1], max_saldo = max(abs(saldo)), rec = rec,
       BS = stockG - stockKK - stockB)
}

run <- function(n, construction_months = 12, years = 70, tax = FALSE, seed = 1) {
  set.seed(seed)
  g <- make_grid(construction_months, years); T1 <- g$T + 1
  exo <- matrix(0, n, T1)
  cost_factor <- 1 + rlnorm(n, log(0.05), 0.5)
  exo[, 1] <- 4e5                                        # Eigenkapital-Einlage
  exo[, 2:(construction_months + 1)] <- -2.0e6 / construction_months * cost_factor
  growth <- matrix(rnorm(n * years, 0.02, 0.01), n, years)
  idx <- growth + 1; for (k in 2:years) idx[, k] <- idx[, k - 1] * idx[, k]
  exo[, (construction_months + 2):T1] <- 1.1e5 * idx    # NOI Betriebsjahre
  followup <- matrix(pmax(rnorm(n * T1, 0.045, 0.01), 0), n, T1)
  loans <- list(
    loan_annuity("kfw", 1.2e6, 1:6, 0.0353, 11, followup, 0.02, 3, 0.05, construction_months + 6),
    loan_annuity("bank", 0.6e6, 7:12, 0.039, 11, followup, 0.02, 0, 0, -1))
  tax_step <- if (tax) function(t, F, HZ, KZ) -0.3 * pmax(HZ - KZ, 0) else NULL
  engine(n, g, exo, loans, tax_step = tax_step)
}

r1 <- run(1)
cat(sprintf("N=1: Perioden=%d, max|Finanzierungssaldo|=%.2e, EW=%.0f\n", ncol(r1$BS), r1$max_saldo, r1$EW))
r <- run(1e4)
cat(sprintf("N=10000: max|Finanzierungssaldo|=%.2e, EW-Median=%.0f\n", r$max_saldo, median(r$EW)))
# Vektorisierungs-Invarianz: Simulation i im Batch == Einzellauf mit identischen Eingaben? (hier gleicher Seed -> Sim 1)
cat("Sim 1 im Batch == Einzellauf:", isTRUE(all.equal(r$EW[1], run(1)$EW)), "(nur bei gleicher Zufallsfolge aussagekraeftig)\n")
print(bench::mark(
  `N=1, T=82 (12 Monate Bau + 70 J.)` = run(1),
  `N=10000, T=52 (12 + 40)` = run(1e4, years = 40),
  `N=10000, T=82 (12 + 70)` = run(1e4),
  `N=10000, T=82, Steuer-Slot` = run(1e4, tax = TRUE),
  iterations = 3, check = FALSE)[, c("expression", "median", "mem_alloc")])
