# Statistische Tests des Samplers (WS-C; Spec 00 15.6 "MC-Statistik", 15.5 Nr. 4, 7, 9; Memo 04
# §9). Die Auswertung der MC-Ergebnisse (Standardfehler, Quantile, Konvergenz) testet WS-G in
# test-mc-stats.R und test-mc.R.

n_big <- 20000L

#' Ziehungen mit n_big Läufen in Blöcken zu 200
big_draws <- function(stochastic, seed = 4711, n = n_big, ...) {
  wsc_draw(stochastic, n, block_size = 200L, seed = seed, ...)
}

dist_cases <- function() {
  list(
    normal = list(dist = "normal", mean = 1, sd = 0.2),
    truncnorm = list(dist = "truncnorm", mean = 0, sd = 1, lower = -1, upper = 2),
    lognormal = list(dist = "lognormal", mean = 1.1, sd = 0.1),
    uniform = list(dist = "uniform", min = 0, max = 0.3),
    triangular = list(dist = "triangular", min = 0, mode = 3, max = 12),
    pert = list(dist = "pert", min = 0.95, mode = 1.05, max = 1.40),
    beta = list(dist = "beta", mean = 0.08, sd = 0.05),
    bernoulli = list(dist = "bernoulli", p = 0.85),
    discrete = list(dist = "discrete", values = 2028:2033),
    empirical = list(dist = "empirical", data = c(0.98, 1.02, 1.05, 1.08, 1.12, 1.20, 1.35)),
    fixed = list(dist = "fixed", value = 3)
  )
}

#' Verteilungsfunktion eines stetigen Typs (für den KS-Test)
cdf_of <- function(name, par) {
  switch(name,
    normal = function(q) pnorm(q, par$mean, par$sd),
    truncnorm = function(q) (pnorm(q) - pnorm(-1)) / (pnorm(2) - pnorm(-1)),
    lognormal = {
      p <- dist_lognormal_canon(par)
      function(q) plnorm(q, p$meanlog, p$sdlog)
    },
    uniform = function(q) punif(q, par$min, par$max),
    triangular = function(q) {
      a <- par$min
      c0 <- par$mode
      b <- par$max
      ifelse(q <= c0, (q - a)^2 / ((b - a) * (c0 - a)), 1 - (b - q)^2 / ((b - a) * (b - c0)))
    },
    pert = {
      p <- dist_pert_par(par)
      function(q) pbeta((q - p$a) / (p$b - p$a), p$alpha, p$beta)
    },
    beta = {
      p <- dist_beta_canon(par)
      function(q) pbeta(q, p$shape1, p$shape2)
    },
    NULL
  )
}

test_that("Momente aller Verteilungen: Mittel innerhalb 4 SE, sd ± 3 %, KS-Test (Memo 04 §9)", {
  cases <- dist_cases()
  pars <- lapply(names(cases), function(k) c(list(target = paste0("shared.", k)), cases[[k]]))
  names(pars) <- names(cases)
  for (sampling in c("lhs", "pseudo")) {
    dr <- big_draws(list(settings = list(sampling = sampling), parameters = pars))
    for (k in names(cases)) {
      x <- dr$static[[k]]
      par <- dist_par(cases[[k]])
      def <- wsc_dist(cases[[k]]$dist)
      m <- def$moments(par)
      sd_th <- sqrt(m$var)
      expect_lte(abs(mean(x) - m$mean), 4 * sd_th / sqrt(n_big) + 1e-12)
      if (sd_th > 0) expect_lt(abs(stats::sd(x) / sd_th - 1), 0.03)
      if (sd_th == 0) expect_identical(unique(x), m$mean)
      cdf <- cdf_of(k, par)
      if (!is.null(cdf)) {
        expect_gt(suppressWarnings(stats::ks.test(x, cdf)$p.value), 1e-3)
      }
    }
  }
})

test_that("Parametrisierungen: Lognormal-Median/P90 und PERT-/Dreiecksmittel getroffen", {
  pars <- list(
    ln = wsc_par("shared.a", "lognormal", median = 0.02, p90 = 0.05),
    pe = wsc_par("shared.b", "pert", min = 0, mode = 2, max = 12),
    tr = wsc_par("shared.c", "triangular", min = 60, mode = 90, max = 200)
  )
  dr <- big_draws(list(parameters = pars))
  expect_lt(abs(stats::quantile(dr$static$ln, 0.5) - 0.02), 0.0005)
  expect_lt(abs(stats::quantile(dr$static$ln, 0.9) - 0.05), 0.001)
  expect_lt(abs(mean(dr$static$pe) - 10 / 3), 1e-3)
  expect_lt(abs(mean(dr$static$tr) - 350 / 3), 0.05)
})

test_that("LHS exakt geschichtet je Schlüssel und Block, auch nach Iman-Conover", {
  pars <- list(a = wsc_par("shared.a", "uniform", min = 0, max = 1),
               b = wsc_par("shared.b", "pert", min = 0, mode = 1, max = 5),
               c = wsc_par("shared.c", "normal", mean = 0, sd = 1))
  st <- list(parameters = pars,
             correlations = list(parameters = list(list("a", "b", 0.5), list("a", "c", -0.3))))
  dr <- wsc_draw(st, 2000L, block_size = 200L, seed = 1)
  for (k in c("a", "b", "c")) {
    for (b in 1:10) {
      ub <- dr$u[[k]][(b - 1L) * 200L + 1:200]
      expect_identical(sort(floor(200 * ub)), as.double(0:199))
    }
  }
  # Bernoulli mit LHS: je Block genau floor(p m) oder ceiling(p m) Einsen, Abweichung <= 1/m
  db <- wsc_draw(list(parameters = list(z = wsc_par("shared.z", "bernoulli", p = 0.37))), 2000L,
                 block_size = 200L)
  share <- tapply(db$static$z, rep(1:10, each = 200L), mean)
  expect_true(all(abs(share - 0.37) <= 1 / 200 + 1e-12))
})

test_that("Iman-Conover: Rangkorrelation ±0,02 bei n = 20.000 (Blöcke zu 200), Ränder identisch", {
  pars <- list(a = wsc_par("shared.a", "pert", min = 0, mode = 1, max = 5),
               b = wsc_par("shared.b", "lognormal", meanlog = 0, sdlog = 1),
               c = wsc_par("shared.c", "uniform", min = 0, max = 1))
  target <- matrix(c(1, 0.5, -0.3, 0.5, 1, 0.2, -0.3, 0.2, 1), 3)
  pairs <- list(list("a", "b", 0.5), list("a", "c", -0.3), list("b", "c", 0.2))
  st <- list(parameters = pars, correlations = list(parameters = pairs))
  dr <- big_draws(st)
  x <- cbind(dr$static$a, dr$static$b, dr$static$c)
  expect_lt(max(abs(stats::cor(x, method = "spearman") - target)), 0.02)
  # gleiche Wertemenge je Block wie ohne Korrelation (Ränder exakt erhalten)
  ind <- big_draws(list(parameters = pars))
  for (k in c("a", "b", "c")) {
    for (b in c(1L, 37L, 100L)) {
      rows <- (b - 1L) * 200L + 1:200
      expect_identical(sort(dr$static[[k]][rows]), sort(ind$static[[k]][rows]))
    }
  }
})

test_that("CRN über Varianten: gleiche Ziehungen, je Variante die eigene Rangkorrelation (11.10)", {
  g <- make_grid()
  uni <- function(t) wsc_par(t, "pert", min = 0, mode = 1, max = 5)
  plan <- function(st) {
    smp_configure(smp_plan(wsc_spec(st, g), g), n_sim = n_big, block_size = 200L)
  }
  blocks <- seq_len(n_big %/% 200L)
  # A: {a, b} unkorreliert; B: {a, b, c} mit [a, c, 0,7]; C: {a, b} mit [a, b, -0,5]
  pa <- plan(list(parameters = list(a = uni("shared.a"), b = uni("shared.b"))))
  pb <- plan(list(parameters = list(a = uni("shared.a"), b = uni("shared.b"),
                                    c = uni("shared.c")),
                  correlations = list(parameters = list(list("a", "c", 0.7)))))
  un <- smp_plan_union(list(pa, pb, pa))
  raw <- smp_sample(un, blocks, 4711)
  da <- smp_materialize(raw, pa, g)
  db <- smp_materialize(raw, pb, g)
  # identische Varianten: Differenz in jedem Lauf exakt 0 (11.10 Nr. 4)
  expect_identical(da$static$a - smp_materialize(raw, pa, g)$static$a, rep(0, n_big))
  # gleicher Schlüssel = gleiche Ziehung, obwohl nur B die Gruppe {a, c} hat
  expect_identical(da$static$a, db$static$a)
  expect_identical(da$static$b, db$static$b)
  expect_lt(abs(stats::cor(db$static$a, db$static$c, method = "spearman") - 0.7), 0.02)
  expect_lt(abs(stats::cor(da$static$a, da$static$b, method = "spearman")), 0.02)
  # Konflikt: C weicht für [a, b] ab (Warnung); jede Variante erhält ihre eigene Korrelation
  pc <- plan(list(parameters = list(a = uni("shared.a"), b = uni("shared.b")),
                  correlations = list(parameters = list(list("a", "b", -0.5)))))
  expect_warning(u2 <- smp_plan_union(list(pb, pc)), class = "vofi_warning_correlation")
  r2 <- smp_sample(u2, blocks, 4711)
  d2b <- smp_materialize(r2, pb, g)
  d2c <- smp_materialize(r2, pc, g)
  expect_lt(abs(stats::cor(d2c$static$a, d2c$static$b, method = "spearman") + 0.5), 0.02)
  expect_lt(abs(stats::cor(d2b$static$a, d2b$static$b, method = "spearman")), 0.02)
  expect_lt(abs(stats::cor(d2b$static$a, d2b$static$c, method = "spearman") - 0.7), 0.02)
  # Ränder je Block in jeder Variante exakt erhalten (gleiche Wertemenge wie unabhängig)
  for (b in c(1L, 50L, 100L)) {
    rows <- (b - 1L) * 200L + 1:200
    expect_identical(sort(d2c$static$a[rows]), sort(da$static$a[rows]))
  }
})

test_that("Gauß-Copula: Zielkorrelation näherungsweise, Uniforms in (0, 1)", {
  pars <- list(a = wsc_par("shared.a", "uniform", min = 0, max = 1),
               b = wsc_par("shared.b", "uniform", min = 0, max = 1))
  st <- list(settings = list(copula = "gaussian"), parameters = pars,
             correlations = list(parameters = list(list("a", "b", 0.6))))
  dr <- big_draws(st)
  expect_lt(abs(stats::cor(dr$static$a, dr$static$b, method = "spearman") - 0.6), 0.02)
  expect_true(all(dr$u$a > 0 & dr$u$a < 1))
})

test_that("Prozessschocks: Kreuzkorrelation ±0,02 und Niveaukorrelation zweier AR(1)", {
  st <- list(processes = list(
    inflation = list(target = "market.inflation", type = "ar1", mu = 0.02, phi = 0.5,
                     sigma = 0.011),
    mortgage_rate = list(target = "market.mortgage_rate", type = "vasicek", r0 = 0.04,
                         theta = 0.0375, kappa = 0.12, sigma = 0.007)
  ), correlations = list(shocks = list(list("inflation", "mortgage_rate", 0.4))))
  g <- vofi_time_grid(as.Date("2027-01-01"), 30L)
  dr <- big_draws(st, grid = g)
  a <- dr$annual$inflation
  r <- dr$annual$mortgage_rate
  zi <- (a[, 3] - 0.02 - 0.5 * (a[, 2] - 0.02)) / 0.011
  zr <- (r[, 3] - 0.0375 - (r[, 2] - 0.0375) * exp(-0.12)) /
    (0.007 * sqrt(-expm1(-0.24) / 0.24))
  expect_lt(abs(stats::cor(zi, zr) - 0.4), 0.02)
  # stationär: Corr = ρ √((1 − φ1²)(1 − φ2²)) / (1 − φ1 φ2) = 0,2875 (Spec 01 Teil C 1.7.5)
  ph <- exp(-0.12)
  expect_spec(0.4 * sqrt((1 - 0.25) * (1 - ph^2)) / (1 - 0.5 * ph), "0.2875")
  expect_lt(abs(stats::cor(a[, ncol(a)], r[, ncol(r)]) - 0.2875), 0.03)
})

test_that("Prozesse: Vasicek-Erwartung, AR(1)-Stationarität, GBM, Untergrenze, mr_trend", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 30L)
  st <- list(processes = list(
    r = list(target = "market.mortgage_rate", type = "vasicek", r0 = 0.05, theta = 0.03,
             kappa = 0.2, sigma = 0.005),
    f = list(target = "accounts.deposit_rate_pa", type = "vasicek", r0 = 0.01, theta = 0.01,
             kappa = 0.1, sigma = 0.02, floor = 0),
    g = list(target = "market.inflation", type = "ar1", mu = 0.02, phi = 0.6, sigma = 0.01),
    p = list(target = "market.energy_price.gas", type = "gbm", p0 = 1, growth = 0.02,
             sigma = 0.1),
    m = list(target = "market.energy_price.power", type = "mr_trend", p0 = 0.35,
             p_norm = 0.3, growth = 0.02, phi = 0.75, sigma = 0.08)
  ))
  dr <- big_draws(st, grid = g)
  r <- dr$annual$r
  expect_lt(abs(mean(r[, 6]) - (0.03 + 0.02 * exp(-1))), 4 * stats::sd(r[, 6]) / sqrt(n_big))
  expect_true(all(dr$annual$f >= 0))
  expect_true(all(dr$paths$f >= 0))
  a <- dr$annual$g
  expect_lt(abs(stats::sd(a[, ncol(a)]) / (0.01 / sqrt(1 - 0.36)) - 1), 0.03)
  expect_lt(abs(stats::cor(a[, ncol(a) - 1L], a[, ncol(a)]) - 0.6), 0.03)
  p <- dr$annual$p
  ep <- wsc_proc("gbm")$expected(st$processes$p, g$years)
  expect_equal(ep, 1.02^(seq_along(g$years) - 1), tolerance = 1e-12)
  nc <- ncol(p)
  expect_lt(abs(mean(p[, nc]) - ep[nc]), 4 * stats::sd(p[, nc]) / sqrt(n_big))
  mm <- dr$annual$m
  e <- wsc_proc("mr_trend")$expected(st$processes$m, g$years)
  se <- apply(mm, 2, stats::sd) / sqrt(n_big)
  expect_true(all(abs(colMeans(mm) - e) <= 4 * se + 1e-15))
})

test_that("Unsichere Prozessparameter (S->P): Ziehung je Lauf, Korrelation mit statischen Größen", {
  st <- list(
    parameters = list(theta_x = wsc_par("shared.t", "uniform", min = 0, max = 1)),
    processes = list(inflation = list(target = "market.inflation", type = "ar1",
                                      mu = list(dist = "normal", mean = 0.02, sd = 0.004),
                                      phi = 0.5, sigma = 0, x0 = 0.02)),
    correlations = list(parameters = list(list("inflation.mu", "theta_x", 0.5)))
  )
  dr <- big_draws(st)
  mu <- dr$static$inflation.mu
  expect_lt(abs(mean(mu) - 0.02), 4 * 0.004 / sqrt(n_big))
  expect_lt(abs(stats::cor(mu, dr$static$theta_x, method = "spearman") - 0.5), 0.02)
  # σ = 0: Pfad je Lauf = Erwartung mit dem gezogenen μ
  k <- seq_along(dr$years) - 1
  expect_equal(dr$annual$inflation[5, ], mu[5] + 0.5^k * (0.02 - mu[5]), tolerance = 1e-14)
})

test_that("Reproduzierbarkeit: Seed, globaler RNG, Zusatzschlüssel, Reihenfolge, Gebietsschema", {
  pars <- list(a = wsc_par("shared.a", "uniform", min = 0, max = 1),
               b = wsc_par("shared.b", "pert", min = 0, mode = 1, max = 2),
               c = wsc_par("shared.c", "normal", mean = 0, sd = 1))
  procs <- list(inflation = list(target = "market.inflation", type = "ar1", mu = 0.02,
                                 phi = 0.5, sigma = 0.01),
                mortgage_rate = list(target = "market.mortgage_rate", type = "vasicek",
                                     r0 = 0.04, theta = 0.0375, kappa = 0.12, sigma = 0.007))
  corr <- list(parameters = list(list("a", "b", 0.5), list("c", "a", 0.2)),
               shocks = list(list("inflation", "mortgage_rate", 0.4)))
  st <- list(parameters = pars, processes = procs, correlations = corr)
  withr::local_seed(99)
  before <- .Random.seed
  d1 <- wsc_draw(st, 400L, seed = 11)
  d2 <- wsc_draw(st, 400L, seed = 11)
  d3 <- wsc_draw(st, 400L, seed = 12)
  expect_identical(d1, d2)
  expect_false(identical(d1$static$a, d3$static$a))
  expect_false(identical(d1$paths$inflation, d3$paths$inflation))
  expect_identical(.Random.seed, before)
  # zusätzlicher unkorrelierter Schlüssel bzw. Prozess verschiebt keine anderen Ziehungen
  st_x <- st
  st_x$parameters$zz <- wsc_par("shared.zz", "uniform", min = 0, max = 1)
  st_x$processes$extra <- list(target = "market.rent_growth", type = "ar1", mu = 0.01, phi = 0.3,
                               sigma = 0.01)
  dx <- wsc_draw(st_x, 400L, seed = 11)
  for (k in names(d1$static)) expect_identical(dx$static[[k]], d1$static[[k]])
  for (k in names(d1$paths)) expect_identical(dx$paths[[k]], d1$paths[[k]])
  # Reihenfolge der Einträge und Paare ohne Wirkung (kanonische Ordnung, 15.5 Nr. 7)
  st_r <- list(parameters = rev(pars), processes = rev(procs),
               correlations = list(parameters = list(list("a", "c", 0.2), list("b", "a", 0.5)),
                                   shocks = list(list("mortgage_rate", "inflation", 0.4))))
  dr <- wsc_draw(st_r, 400L, seed = 11)
  for (k in names(d1$static)) expect_identical(dr$static[[k]], d1$static[[k]])
  for (k in names(d1$paths)) expect_identical(dr$paths[[k]], d1$paths[[k]])
  withr::with_collate("C", dc <- wsc_draw(st_r, 400L, seed = 11))
  expect_identical(dc$static, d1$static)
  expect_identical(dc$paths, d1$paths)
})

test_that("Präfix-Stabilität: Vorschau = erste 1.000 Läufe des Standardlaufs (R-73, 15.5 Nr. 9)", {
  st <- list(
    parameters = list(a = wsc_par("shared.a", "pert", min = 0.9, mode = 1, max = 1.4),
                      b = wsc_par("shared.b", "uniform", min = 0, max = 1)),
    processes = list(inflation = list(target = "market.inflation", type = "ar1", mu = 0.02,
                                      phi = 0.5, sigma = 0.011)),
    correlations = list(parameters = list(list("a", "b", 0.6)))
  )
  g <- make_grid()
  std <- wsc_plan(st, g, n_sim = 10000L)
  prev <- smp_configure(wsc_plan(st, g), preview = TRUE)
  expect_identical(prev$settings$n_sim, 1000L)
  d_std <- smp_draw(std, g, smp_blocks(std, 10000L), 20261025)
  d_prev <- smp_draw(prev, g, smp_blocks(prev, 1000L), 20261025)
  rows <- seq_len(1000L)
  for (k in names(d_prev$static)) expect_identical(d_prev$static[[k]], d_std$static[[k]][rows])
  for (k in names(d_prev$paths)) {
    expect_identical(d_prev$paths[[k]], d_std$paths[[k]][rows, , drop = FALSE])
  }
  # Vielfaches der Blockgröße Pflicht
  expect_error(smp_configure(std, n_sim = 1100L), class = "vofi_error_input")
  # F21-Modus: Ziehungen hängen von n_sim ab (dokumentiert)
  f1 <- suppressMessages(smp_configure(wsc_plan(st, g), n_sim = 1000L, replicates = 10L))
  f2 <- suppressMessages(smp_configure(wsc_plan(st, g), n_sim = 2000L, replicates = 10L))
  expect_false(identical(smp_draw(f1, g, 1L, 1)$static$a[1:10],
                         smp_draw(f2, g, 1L, 1)$static$a[1:10]))
})

test_that("Entartung: alle Verteilungen entartet bzw. σ = 0 ergeben den deterministischen Wert", {
  g <- make_grid()
  st <- list(
    parameters = list(
      a = wsc_par("shared.a", "triangular", min = 9000, mode = 9000, max = 9000),
      b = wsc_par("shared.b", "uniform", min = 1500, max = 1500),
      c = wsc_par("shared.c", "pert", min = 1, mode = 1, max = 1, apply = "multiply"),
      d = wsc_par("shared.d", "normal", mean = 0.04, sd = 0),
      e = wsc_par("shared.e", "fixed", value = 2)
    ),
    processes = list(
      inflation = list(target = "market.inflation", type = "ar1", mu = 0.02, phi = 0.5,
                       sigma = 0, x0 = "base"),
      mortgage_rate = list(target = "market.mortgage_rate", type = "vasicek", r0 = "base",
                           theta = 0.04, kappa = 0.2, sigma = 0),
      gas = list(target = "market.energy_price.gas", type = "mr_trend", p0 = "base",
                 p_norm = "base", growth = 0, phi = 0.75, sigma = 0)
    )
  )
  shared <- list(a = 9000, b = 1500, c = 50, d = 0.04, e = 2)
  spec <- wsc_spec(st, g, shared = shared)
  plan <- smp_configure(smp_plan(spec, g), n_sim = 14L, block_size = 7L)
  dr <- smp_draw(plan, g, 1:2, 1)
  ctx <- eng_context_from_parts(g, spec, draws = dr, mode = "mc")
  det <- eng_context_from_parts(g, spec, mode = "deterministic")
  for (nm in names(shared)) {
    expect_equal(ctx$value(paste0("shared.", nm)), rep(det$value(paste0("shared.", nm)), 14L),
                 tolerance = 1e-10)
  }
  for (m in c("inflation", "mortgage_rate", "energy_price.gas")) {
    b <- det$market(m)
    expect_equal(unname(ctx$market(m)), matrix(b[1L, ], 14L, ncol(b), byrow = TRUE),
                 tolerance = 1e-10)
  }
})

test_that("Antithetische Variablen: lineare Funktion -> Paarmittel exakt (Memo 04 §9)", {
  st <- list(settings = list(sampling = "pseudo", antithetic = TRUE),
             parameters = list(a = wsc_par("shared.a", "uniform", min = 2, max = 6)))
  dr <- wsc_draw(st, 400L, block_size = 200L)
  for (b in 1:2) {
    rows <- (b - 1L) * 200L
    pair <- (dr$static$a[rows + 1:100] + dr$static$a[rows + 101:200]) / 2
    expect_equal(pair, rep(4, 100L), tolerance = 1e-14)
  }
})

test_that("Entscheidungsschlüssel: ohne Zielwirkung, nicht korrelierbar, Zusagequote je Block", {
  fund <- list(node = list(approval_probability = 0.85, approval_timing = "before_start",
                           fallback_variant = "alt"))
  g <- make_grid()
  spec <- wsc_spec(list(), g, funding = fund)
  plan <- smp_configure(smp_plan(spec, g), n_sim = 2000L)
  dr <- smp_draw(plan, g, smp_blocks(plan, 2000L), 3)
  share <- tapply(dr$decision$funding.node.approved, rep(1:10, each = 200L), mean)
  expect_true(all(abs(share - 0.85) <= 1 / 200))
  expect_length(dr$static, 0L)
  ctx <- eng_context_from_parts(g, spec, draws = dr, mode = "mc")
  expect_null(ctx$value("funding.node.approved"))
  bad <- list(parameters = list(x = wsc_par("shared.x", "uniform", min = 0, max = 1)),
              correlations = list(parameters = list(list("funding.node.approved", "x", 0.3))))
  expect_error(smp_plan(wsc_spec(bad, g, funding = fund), g), class = "vofi_error_validation")
})
