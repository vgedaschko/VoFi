source("mc_core.R")

read_stochastic_spec <- function(path) {            # locale-unabhängig (auch unter LC_ALL=C)
  txt <- readLines(path, encoding = "UTF-8", warn = FALSE)
  yaml::yaml.load(paste(txt, collapse = "\n"))$stochastic
}
corr_from_pairs <- function(pairs, names) {
  R <- diag(length(names)); dimnames(R) <- list(names, names)
  for (p in pairs) R[p[[1]], p[[2]]] <- R[p[[2]], p[[1]]] <- as.numeric(p[[3]])
  R
}
is_dist <- function(x) is.list(x) && !is.null(x$dist)

sample_stochastic <- function(spec, n = NULL) {
  st <- spec$settings; n <- n %||% st$n_sim; T <- st$horizon; seed <- st$seed
  meth <- st$sampling %||% "pseudo"; anti <- isTRUE(st$antithetic)
  rep <- if (meth == "lhs") as.integer(st$replicates %||% 1L) else 1L
  years <- st$start_year + seq_len(T)
  U_of <- function(name) draw_u(n, seed, name, meth, anti, rep)

  # 1) statische Parameter + unsichere Prozessparameter ("prozess.param")
  pars <- spec$parameters
  for (pn in names(spec$processes)) for (k in setdiff(names(spec$processes[[pn]]), "dist_spec"))
    if (is_dist(spec$processes[[pn]][[k]])) pars[[paste(pn, k, sep = ".")]] <- spec$processes[[pn]][[k]]
  U <- matrix(vapply(names(pars), function(nm) U_of(paste0("par:", nm)), numeric(n)),
              n, dimnames = list(NULL, names(pars)))
  cp <- spec$correlations$parameters
  grp <- unique(unlist(lapply(cp, function(p) unlist(p[1:2]))))
  cop <- st$copula %||% "iman_conover"
  if (length(grp) && cop == "gaussian")
    U[, grp] <- gauss_copula(U[, grp, drop = FALSE], corr_from_pairs(cp, grp))
  X <- U
  for (nm in names(pars)) X[, nm] <- quantile_fun(pars[[nm]])(U[, nm])
  if (length(grp) && cop == "iman_conover")
    X[, grp] <- iman_conover(X[, grp, drop = FALSE], corr_from_pairs(cp, grp), seed, "ic:parameters", rep)
  getp <- function(p, k) { v <- spec$processes[[p]][[k]]; if (is_dist(v)) X[, paste(p, k, sep = ".")] else v }

  # 2) Schocks je Prozess (benannte Ströme) + Kreuzkorrelation
  pn <- names(spec$processes)
  Z <- lapply(setNames(pn, pn), function(p) draw_shocks(n, T, seed, p, meth, anti, rep))
  if (length(spec$correlations$shocks)) Z <- correlate_shocks(Z, corr_from_pairs(spec$correlations$shocks, pn))

  # 3) Pfade (verknüpfte Prozesse nach ihren Basisprozessen)
  paths <- list()
  for (p in pn[order(vapply(spec$processes, function(s) !is.null(s$base), logical(1)))]) {
    s <- spec$processes[[p]]
    paths[[p]] <- switch(s$type,
      fixed_path   = matrix(approx(unlist(s$years), unlist(s$values), xout = years, rule = 2)$y, 1, T),
      iid          = sim_iid(pnorm(Z[[p]]), tabulate_qf(quantile_fun(s$dist_spec))),
      ar1          = sim_ar1(Z[[p]], getp(p, "mu"), getp(p, "phi"), getp(p, "sigma"), s$x0 %||% getp(p, "mu")),
      vasicek      = sim_vasicek(Z[[p]], s$r0, getp(p, "theta"), getp(p, "kappa"), getp(p, "sigma"), s$floor %||% -Inf),
      gbm          = sim_gbm(Z[[p]], s$p0, getp(p, "growth"), getp(p, "sigma")),
      mr_trend     = sim_mr_trend(Z[[p]], s$p0 * outer(rep_len(1 + getp(p, "growth"), n), seq_len(T), "^"),
                                  getp(p, "phi"), getp(p, "sigma")),
      linked_ar1   = getp(p, "a") + getp(p, "b") * paths[[s$base]] +
                     sim_ar1(Z[[p]], 0, getp(p, "phi"), getp(p, "sigma"), 0),
      scenario_mix = {
        sc <- s$scenarios
        P <- t(vapply(sc, function(x) approx(unlist(x$years), unlist(x$values), xout = years, rule = 2)$y, numeric(T)))
        sim_scenario_mix(U_of(paste0("scen:", p)), P, vapply(sc, `[[`, numeric(1), "prob"),
                         Z[[p]], s$noise$sigma %||% 0, s$noise$phi %||% 0)
      },
      stop("Unbekannter Prozesstyp: ", s$type))
  }
  structure(list(parameters = as.data.frame(X), paths = paths, years = years,
                 meta = list(seed = seed, n = n, sampling = meth, replicates = rep,
                             rng = "Mersenne-Twister/Inversion/Rejection, benannte Ströme",
                             r_version = R.version.string, created = Sys.time())),
            class = "vofi_scenarios")
}
