# Prototyp MC-Kern (Skizze) ---------------------------------------------------
`%||%` <- function(a, b) if (is.null(a)) b else a

# ---- 1. Benannte Zufallsströme ---------------------------------------------
stream_hash <- function(name) {                 # Polynom-Hash mod (2^31 - 1), exakt in double
  h <- 0
  for (code in utf8ToInt(name)) h <- (h * 131 + code) %% 2147483647
  h
}
with_stream <- function(seed, name, expr) {     # eigener RNG-Zustand, globaler Zustand bleibt unberührt
  had <- exists(".Random.seed", envir = globalenv())
  if (had) old <- get(".Random.seed", envir = globalenv())
  old_kind <- RNGkind()
  on.exit({
    RNGkind(old_kind[1], old_kind[2], old_kind[3])
    if (had) assign(".Random.seed", old, envir = globalenv())
    else if (exists(".Random.seed", envir = globalenv())) rm(".Random.seed", envir = globalenv())
  })
  set.seed((seed * 1000003 + stream_hash(name)) %% 2147483647,
           kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
  force(expr)
}

# ---- 2. Gleichverteilte Basiszahlen ----------------------------------------
lhs_vector <- function(n, replicates = 1L) {    # replizierte LHS: r unabhängige Blöcke à n/r
  m <- n %/% replicates
  stopifnot(m * replicates == n)
  unlist(lapply(seq_len(replicates), function(b) (sample.int(m) - runif(m)) / m))
}
draw_u <- function(n, seed, name, method = c("pseudo", "lhs"), antithetic = FALSE, replicates = 1L) {
  method <- match.arg(method)
  with_stream(seed, name, {
    m <- if (antithetic) n %/% 2 else n
    u <- if (method == "lhs") lhs_vector(m, replicates) else runif(m)
    if (antithetic) c(u, 1 - u) else u
  })
}
draw_shocks <- function(n, T, seed, name, method = "pseudo", antithetic = FALSE, replicates = 1L) {
  with_stream(seed, paste0("shock:", name), {
    m <- if (antithetic) n %/% 2 else n
    Z <- if (method == "lhs") vapply(seq_len(T), function(t) qnorm(lhs_vector(m, replicates)), numeric(m))
         else matrix(rnorm(m * T), m, T)
    if (antithetic) rbind(Z, -Z) else Z
  })
}

# ---- 3. Quantilfunktionen (Inversionsmethode) -------------------------------
q_triangular <- function(u, min, mode, max) {
  fc <- (mode - min) / (max - min)
  ifelse(u < fc, min + sqrt(u * (max - min) * (mode - min)),
                 max - sqrt((1 - u) * (max - min) * (max - mode)))
}
q_pert <- function(u, min, mode, max, lambda = 4) {
  a <- 1 + lambda * (mode - min) / (max - min)
  b <- 1 + lambda * (max - mode) / (max - min)
  min + (max - min) * qbeta(u, a, b)
}
q_truncnorm <- function(u, mean, sd, lower = -Inf, upper = Inf) {
  pa <- pnorm(lower, mean, sd); pb <- pnorm(upper, mean, sd)
  qnorm(pa + u * (pb - pa), mean, sd)
}
lnorm_par <- function(mean = NULL, sd = NULL, median = NULL, p90 = NULL) {
  if (!is.null(mean)) {
    s2 <- log(1 + (sd / mean)^2)
    return(c(meanlog = log(mean) - s2 / 2, sdlog = sqrt(s2)))
  }
  c(meanlog = log(median), sdlog = (log(p90) - log(median)) / qnorm(0.9))
}
q_discrete <- function(u, values, probs) {
  cp <- cumsum(probs) / sum(probs)
  values[findInterval(u, cp, left.open = TRUE) + 1L]
}
q_empirical <- function(u, data) unname(quantile(data, probs = u, type = 7))

quantile_fun <- function(spec) {
  switch(spec$dist,
    fixed      = function(u) rep(spec$value, length(u)),
    normal     = function(u) qnorm(u, spec$mean, spec$sd),
    truncnorm  = function(u) q_truncnorm(u, spec$mean, spec$sd, spec$lower %||% -Inf, spec$upper %||% Inf),
    lognormal  = function(u) {
      p <- if (!is.null(spec$mean)) lnorm_par(mean = spec$mean, sd = spec$sd)
           else lnorm_par(median = spec$median, p90 = spec$p90)
      (spec$shift %||% 0) + qlnorm(u, p[["meanlog"]], p[["sdlog"]])
    },
    uniform    = function(u) spec$min + (spec$max - spec$min) * u,
    triangular = function(u) q_triangular(u, spec$min, spec$mode, spec$max),
    pert       = function(u) q_pert(u, spec$min, spec$mode, spec$max, spec$lambda %||% 4),
    bernoulli  = function(u) as.numeric(u < spec$p),
    discrete   = function(u) q_discrete(u, unlist(spec$values), unlist(spec$probs)),
    empirical  = function(u) q_empirical(u, unlist(spec$data)),
    stop("Unbekannte Verteilung: ", spec$dist))
}
# Schnelle tabellierte Quantilfunktion (für große N x T, z. B. qbeta)
tabulate_qf <- function(qf, m = 4096) {
  g <- c(0, pnorm(seq(-7, 7, length.out = m)), 1)   # Stützstellen in den Rändern verdichtet
  approxfun(g, qf(g), rule = 2)
}

# ---- 4. Abhängigkeiten -------------------------------------------------------
spearman_to_pearson <- function(rs) 2 * sin(pi * rs / 6)
near_pd_corr <- function(R, eps = 1e-6) {          # Eigenwert-Clipping + Reskalierung
  R <- (R + t(R)) / 2
  e <- eigen(R, symmetric = TRUE)
  if (min(e$values) >= eps) return(R)
  R2 <- e$vectors %*% diag(pmax(e$values, eps)) %*% t(e$vectors)
  d <- sqrt(diag(R2)); R2 <- R2 / outer(d, d)
  dimnames(R2) <- dimnames(R)
  R2
}
gauss_copula <- function(U, R_spearman) {          # U unabhängig -> U korreliert
  R <- near_pd_corr(spearman_to_pearson(R_spearman)); diag(R) <- 1
  pnorm(qnorm(U) %*% chol(R))
}
iman_conover <- function(X, R_spearman, seed, name = "iman_conover", replicates = 1L) {
  C <- near_pd_corr(spearman_to_pearson(R_spearman)); diag(C) <- 1
  P <- chol(C); k <- ncol(X); m <- nrow(X) %/% replicates
  for (b in seq_len(replicates)) {                 # je LHS-Replikat getrennt
    ix <- (b - 1) * m + seq_len(m)
    a <- qnorm(seq_len(m) / (m + 1))               # van-der-Waerden-Scores
    S <- with_stream(seed, paste0(name, ":", b), vapply(seq_len(k), function(j) sample(a), numeric(m)))
    Tm <- S %*% backsolve(chol(cor(S)), diag(k)) %*% P   # S Q^{-1} P
    for (j in seq_len(k)) X[ix, j] <- sort(X[ix, j])[rank(Tm[, j], ties.method = "first")]
  }
  X
}

# ---- 5. Schocks und Prozesse -------------------------------------------------
correlate_shocks <- function(Zlist, R) {           # Liste N x T -> korrelierte Liste
  U <- chol(near_pd_corr(R)); N <- nrow(Zlist[[1]]); T <- ncol(Zlist[[1]])
  M <- vapply(Zlist, as.vector, numeric(N * T)) %*% U
  setNames(lapply(seq_along(Zlist), function(j) matrix(M[, j], N, T)), names(Zlist))
}
sim_ar1 <- function(Z, mu, phi, sigma, x0 = mu) {   # g_t = mu + phi (g_{t-1} - mu) + sigma z_t
  X <- matrix(0, nrow(Z), ncol(Z)); x <- rep_len(x0, nrow(Z))
  for (t in seq_len(ncol(Z))) { x <- mu + phi * (x - mu) + sigma * Z[, t]; X[, t] <- x }
  X
}
sim_vasicek <- function(Z, r0, theta, kappa, sigma, floor = -Inf, dt = 1) {   # exakt, Floor auf Ausgabe
  a <- exp(-kappa * dt); s <- sigma * sqrt((1 - a^2) / (2 * kappa))
  X <- matrix(0, nrow(Z), ncol(Z)); r <- rep_len(r0, nrow(Z))
  for (t in seq_len(ncol(Z))) { r <- theta + (r - theta) * a + s * Z[, t]; X[, t] <- r }
  pmax(X, floor)
}
sim_gbm <- function(Z, p0, g, sigma) {              # E[P_t] = p0 (1+g)^t
  incr <- log1p(g) - sigma^2 / 2 + sigma * Z
  p0 * exp(t(apply(incr, 1, cumsum)))
}
ar1_lognoise <- function(Z, phi, sigma) {           # exp(y_t - v_t/2), E = 1, y AR(1) mit y_0 = 0
  N <- nrow(Z); y <- numeric(N); v <- 0; X <- matrix(0, N, ncol(Z))
  for (t in seq_len(ncol(Z))) { y <- phi * y + sigma * Z[, t]; v <- phi^2 * v + sigma^2; X[, t] <- exp(y - v / 2) }
  X
}
sim_mr_trend <- function(Z, trend, phi, sigma) {    # ln P_t = ln Trend_t + y_t - v_t/2
  if (is.matrix(trend)) trend * ar1_lognoise(Z, phi, sigma)
  else sweep(ar1_lognoise(Z, phi, sigma), 2, trend, `*`)
}
sim_scenario_mix <- function(u, paths, probs, Z = NULL, sigma = 0, phi = 0) {
  s <- q_discrete(u, seq_len(nrow(paths)), probs)
  X <- paths[s, , drop = FALSE]
  if (!is.null(Z) && sigma > 0) X <- X * ar1_lognoise(Z, phi, sigma)
  attr(X, "scenario") <- s
  X
}
sim_iid <- function(U, qf) matrix(qf(as.vector(U)), nrow(U), ncol(U))   # jährlich unabhängig
sim_block_bootstrap <- function(hist, n, T, block = 3, seed, name = "bootstrap", recenter = NULL) {
  hist <- as.matrix(hist); H <- nrow(hist); nb <- ceiling(T / block)
  starts <- with_stream(seed, name, matrix(sample.int(H, n * nb, replace = TRUE), n, nb))
  idx <- (outer(starts, 0:(block - 1), "+") - 1) %% H + 1          # zirkulär
  idx <- aperm(idx, c(1, 3, 2)); dim(idx) <- c(n, nb * block)
  idx <- idx[, seq_len(T), drop = FALSE]
  out <- lapply(seq_len(ncol(hist)), function(j) {                   # gleiche Jahre für alle Reihen
    x <- hist[, j]; if (!is.null(recenter)) x <- x - mean(x) + recenter[j]
    matrix(x[idx], n, T)
  })
  setNames(out, colnames(hist))
}

# ---- 6. Kalibrierung -------------------------------------------------------
calibrate_ar1 <- function(x) {
  fit <- lm(x[-1] ~ x[-length(x)])
  a <- coef(fit)[[1]]; phi <- coef(fit)[[2]]; s <- sd(residuals(fit))
  c(mu = a / (1 - phi), phi = phi, sigma_e = s, sd_stationary = s / sqrt(1 - phi^2))
}
calibrate_vasicek <- function(r, dt = 1) {
  p <- calibrate_ar1(r); b <- p[["phi"]]; kappa <- -log(b) / dt
  c(theta = p[["mu"]], kappa = kappa, sigma = p[["sigma_e"]] * sqrt(2 * kappa / (1 - b^2)),
    half_life = log(2) / kappa)
}
