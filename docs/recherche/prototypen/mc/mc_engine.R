# Prototyp: über Simulationen vektorisierte VoFi-Engine ----------------------
# Jede Größe ist ein Vektor der Länge N (Simulationen); Schleife nur über t.

annuity <- function(B, i, n) ifelse(abs(i) < 1e-12, B / n, B * i / (1 - (1 + i)^(-n)))

vofi_engine <- function(sc, par, store = c("kpi", "bands", "full"),
                        probs = c(0.05, 0.25, 0.5, 0.75, 0.95)) {
  store <- match.arg(store)
  T <- par$T; N <- length(sc$cost_factor)
  rows <- c("investition", "miete", "leerstand", "instandhaltung", "verwaltung",
            "co2_vermieter", "ersatzinvestition", "restwert", "zahlungsreihe",
            "eigenkapital", "d1_aufnahme", "d1_zins", "d1_tilgung",
            "d2_aufnahme", "d2_zins", "d2_tilgung", "d2_tilgungszuschuss",
            "kk_aufnahme", "kk_rueckfuehrung", "kk_zins",
            "ga_anlage", "ga_aufloesung", "ga_zins", "finanzierungssaldo",
            "bestand_d1", "bestand_d2", "bestand_kk", "bestand_ga", "bestandssaldo")
  full <- if (store == "full") lapply(setNames(rows, rows), function(r) matrix(0, N, T + 1)) else NULL
  bands <- if (store != "kpi") list(bestandssaldo = matrix(NA, T + 1, length(probs)),
                                    bestand_kk   = matrix(NA, T + 1, length(probs)),
                                    dscr         = matrix(NA, T + 1, length(probs))) else NULL
  rec <- function(name, t, x) if (!is.null(full)) full[[name]][, t + 1] <<- x

  # Zustände (Vektoren der Länge N)
  B1 <- B2 <- KK <- GA <- numeric(N)
  i1 <- rep(par$i1, N); A1 <- rep(par$loan1 * (par$i1 + par$tilg1), N)
  n1 <- -log(1 - par$i1 * par$loan1 / A1[1]) / log(1 + par$i1)     # rechnerische Laufzeit
  tilg2 <- numeric(N)
  rent_idx <- cost_idx <- infl_idx <- rep(1, N)
  L <- pmax(round(sc$lifetime_hp), 1)
  min_dscr <- rep(Inf, N); kk_max <- numeric(N); noi <- numeric(N)

  for (t in 0:T) {
    z <- ek <- d1in <- d2in <- z1 <- t1 <- z2 <- t2 <- tz2 <- kkz <- gaz <- numeric(N)
    if (t == 0) {
      inv <- -par$invest_base * sc$cost_factor
      z <- inv; ek <- rep(par$ek0, N)
      d1in <- rep(par$loan1, N); d2in <- rep(par$loan2, N)
      rec("investition", t, inv)
    } else {
      rent_idx <- rent_idx * (1 + sc$rent_g[, t])
      cost_idx <- cost_idx * (1 + sc$constr_g[, t])
      infl_idx <- infl_idx * (1 + sc$infl[, t])
      occ   <- pmin(pmax(t - sc$delay_m / 12, 0), 1)                 # Bauzeitverzug
      miete <- par$rent0 * rent_idx * occ
      leer  <- -miete * sc$vac[, t]
      inst  <- -par$maint0 * cost_idx
      verw  <- -par$mgmt0 * infl_idx
      co2   <- -sc$co2[, t] * par$co2_t_base * (1 - par$saving * sc$perf_factor) * par$landlord_share
      ers   <- -par$hp_cost * cost_idx * ((t %% L) == 0)            # Ersatz nach Lebensdauer
      noi   <- miete + leer + inst + verw + co2
      rw <- numeric(N)
      if (t == T) {
        y_exit <- pmax(par$exit_yield0 + par$exit_beta * (sc$rate[, T] - par$i1) + sc$exit_eps, 0.02)
        rw <- noi * (1 + sc$rent_g[, T]) / y_exit
      }
      z <- noi + ers + rw
      rec("miete", t, miete); rec("leerstand", t, leer); rec("instandhaltung", t, inst)
      rec("verwaltung", t, verw); rec("co2_vermieter", t, co2); rec("ersatzinvestition", t, ers)
      rec("restwert", t, rw)

      # Darlehen 1: Annuität, Anschlusszins aus Zinspfad nach Zinsbindung
      if (t > 1 && (t - 1) %% par$binding1 == 0) {
        i1 <- sc$rate[, t - 1] + par$spread1             # Konditionen am Ende der Bindung
        A1 <- annuity(B1, i1, pmax(n1 - (t - 1), 1))
      }
      z1 <- -B1 * i1
      t1 <- -pmin(pmax(A1 + z1, 0), B1)
      # Darlehen 2: KfW, tilgungsfreie Anlaufjahre, Tilgungszuschuss bei Förderzusage
      if (t == 1) {
        tz2 <- pmin(par$subsidy * sc$subsidy_ok, B2)
        B2 <- B2 - tz2
      }
      if (t == par$free2 + 1) tilg2 <- B2 / (par$term2 - par$free2)
      z2 <- -B2 * par$i2
      t2 <- -pmin(if (t > par$free2) tilg2 else 0, B2)
      # Kontokorrent / Geldanlage: Zinsen auf Vorperiodenbestand
      kkz <- -KK * (sc$rate[, t] + par$kk_spread)
      gaz <- GA * sc$dep_rate[, t]
      ds  <- -(z1 + t1 + z2 + t2)
      dscr <- ifelse(ds > 0, noi / ds, Inf)
      min_dscr <- pmin(min_dscr, dscr)
    }
    # Ausgleichsregel (vektorisiert)
    pre <- z + ek + d1in + d2in + z1 + t1 + z2 + t2 + kkz + gaz
    net <- pre + GA - KK
    GA_new <- pmax(net, 0); KK_new <- pmax(-net, 0)
    kk_auf <- pmax(KK_new - KK, 0); kk_rf <- -pmax(KK - KK_new, 0)
    ga_an <- -pmax(GA_new - GA, 0); ga_auf <- pmax(GA - GA_new, 0)
    B1 <- B1 + d1in + t1; B2 <- B2 + d2in + t2
    KK <- KK_new; GA <- GA_new
    kk_max <- pmax(kk_max, KK)
    saldo <- GA - KK - B1 - B2
    if (!is.null(full)) {
      rec("zahlungsreihe", t, z); rec("eigenkapital", t, ek)
      rec("d1_aufnahme", t, d1in); rec("d1_zins", t, z1); rec("d1_tilgung", t, t1)
      rec("d2_aufnahme", t, d2in); rec("d2_zins", t, z2); rec("d2_tilgung", t, t2)
      rec("d2_tilgungszuschuss", t, tz2)
      rec("kk_aufnahme", t, kk_auf); rec("kk_rueckfuehrung", t, kk_rf); rec("kk_zins", t, kkz)
      rec("ga_anlage", t, ga_an); rec("ga_aufloesung", t, ga_auf); rec("ga_zins", t, gaz)
      rec("finanzierungssaldo", t, pre + kk_auf + kk_rf + ga_an + ga_auf)
      rec("bestand_d1", t, B1); rec("bestand_d2", t, B2); rec("bestand_kk", t, KK)
      rec("bestand_ga", t, GA); rec("bestandssaldo", t, saldo)
    }
    if (!is.null(bands)) {
      bands$bestandssaldo[t + 1, ] <- quantile(saldo, probs, names = FALSE)
      bands$bestand_kk[t + 1, ]    <- quantile(KK, probs, names = FALSE)
      if (t > 0) bands$dscr[t + 1, ] <- quantile(dscr, probs, names = FALSE)
    }
  }
  ew <- saldo
  ew_opp <- par$ek0 * apply(1 + sc$dep_rate[, 1:T, drop = FALSE], 1, prod)
  kpi <- data.frame(
    endwert = ew, endwert_opp = ew_opp, endwert_diff = ew - ew_opp,
    vofi_rendite = ifelse(ew > 0, (ew / par$ek0)^(1 / T) - 1, NA_real_),
    min_dscr = min_dscr, kk_max = kk_max,
    liquiditaetsengpass = kk_max > par$kk_limit)
  list(kpi = kpi, bands = bands, full = full)
}

# Szenario-Generator für den Prototyp ----------------------------------------
gen_scenarios <- function(N, T, seed, method = "lhs", antithetic = FALSE, degenerate = FALSE,
                          replicates = if (method == "lhs") 10L else 1L) {
  if (degenerate) {
    return(list(cost_factor = rep(1, N), delay_m = rep(0, N), subsidy_ok = rep(1, N),
                perf_factor = rep(0.8, N), lifetime_hp = rep(18, N), exit_eps = rep(0, N),
                infl = matrix(0.02, N, T), rent_g = matrix(0.02, N, T), constr_g = matrix(0.025, N, T),
                rate = matrix(0.035, N, T), dep_rate = matrix(0.02, N, T),
                co2 = matrix(rep(seq(65, 250, length.out = T), each = N), N, T), vac = matrix(0.02, N, T)))
  }
  du <- function(nm) draw_u(N, seed, nm, method, antithetic, replicates)
  U <- cbind(cost = du("cost_factor"), delay = du("delay_m"))
  X <- cbind(q_pert(U[, 1], 0.95, 1.05, 1.40), q_pert(U[, 2], 0, 2, 12))
  X <- iman_conover(X, matrix(c(1, 0.5, 0.5, 1), 2), seed, "ic:bau", replicates)
  sh <- function(nm) draw_shocks(N, T, seed, nm, method, antithetic, replicates)
  Zs <- correlate_shocks(list(infl = sh("infl"), rate = sh("rate"), rent = sh("rent"), constr = sh("constr")),
                         matrix(c(1, .4, .5, .6,
                                  .4, 1, .2, .3,
                                  .5, .2, 1, .3,
                                  .6, .3, .3, 1), 4))
  infl <- sim_ar1(Zs$infl, 0.02, 0.6, 0.010, x0 = 0.022)
  rate <- sim_vasicek(Zs$rate, 0.039, 0.040, 0.15, 0.008, floor = 0.005)
  paths <- rbind(approx(c(0, 4, 19, 40), c(60, 70, 90, 100), xout = 1:T, rule = 2)$y,
                 approx(c(0, 4, 19, 40), c(60, 120, 200, 250), xout = 1:T, rule = 2)$y,
                 approx(c(0, 4, 19, 40), c(60, 200, 300, 350), xout = 1:T, rule = 2)$y)
  list(cost_factor = X[, 1], delay_m = X[, 2],
       subsidy_ok = as.numeric(du("subsidy_ok") < 0.85),
       perf_factor = q_pert(du("perf_factor"), 0.4, 0.8, 1.05),
       lifetime_hp = q_pert(du("lifetime_hp"), 12, 18, 25),
       exit_eps = qnorm(du("exit_eps"), 0, 0.004),
       infl = infl,
       rent_g = 0.002 + 0.8 * infl + sim_ar1(Zs$rent, 0, 0.5, 0.006),   # Mietwachstum an Inflation gekoppelt
       constr_g = 0.005 + infl + sim_ar1(Zs$constr, 0, 0.5, 0.015),
       rate = rate, dep_rate = pmax(rate - 0.015, 0),
       co2 = sim_scenario_mix(du("co2_scenario"), paths, c(.3, .5, .2), Z = sh("co2"), sigma = .15, phi = .8),
       vac = sim_iid(matrix(draw_u(N * T, seed, "vac", "pseudo"), N, T), tabulate_qf(function(u) q_pert(u, 0, 0.02, 0.10))))
}

par_default <- list(T = 40, invest_base = 3.0e6, ek0 = 1.15e6, loan1 = 1.5e6, i1 = 0.039, tilg1 = 0.015,
                    binding1 = 10, spread1 = 0.0, loan2 = 0.5e6, i2 = 0.025, term2 = 20, free2 = 2,
                    subsidy = 0.075e6, rent0 = 0.18e6, maint0 = 0.025e6, mgmt0 = 0.012e6,
                    co2_t_base = 60, saving = 0.7, landlord_share = 0.5, hp_cost = 0.12e6,
                    kk_spread = 0.04, kk_limit = 0.15e6, exit_yield0 = 0.04, exit_beta = 0.5)
