# Prototyp: Registry + Wert-Resolver + generische Engine mit Steuer-Hook
# Ziel: Schnittstellen pruefen und Overhead der generischen Maschinerie messen.

.reg <- new.env(parent = emptyenv())
register_type <- function(name, kind, build, params = list(), label = name) {
  assign(name, list(name = name, kind = kind, build = build, params = params, label = label), envir = .reg)
  invisible(name)
}
get_type <- function(name) {
  if (!exists(name, envir = .reg, inherits = FALSE))
    stop(sprintf("Unbekannter Typ '%s'. Registrierte Typen: %s", name,
                 paste(sort(ls(.reg)), collapse = ", ")), call. = FALSE)
  get(name, envir = .reg, inherits = FALSE)
}

# ---- stabile Seeds je Schluessel (CRN ueber Varianten) ----
key_seed <- function(seed, key) {
  h <- 0
  for (cp in utf8ToInt(key)) h <- (h * 31 + cp) %% 2147483629
  as.integer((h + seed * 7919) %% 2147483629)
}

# ---- Kontext ----
new_ctx <- function(n, T, seed, deterministic, object = list()) {
  ctx <- new.env(parent = emptyenv())
  ctx$n <- n; ctx$T <- T; ctx$seed <- seed; ctx$det <- deterministic
  ctx$object <- object; ctx$flows <- list(); ctx$draws <- list()
  ctx$zero <- function() matrix(0, n, T + 1)
  # Wertauflosung: Zahl | Verteilung | Treiber -> N x (T+1)-Matrix ("path") oder N-Vektor ("scalar")
  ctx$resolve <- function(x, key, shape = c("path", "scalar")) {
    shape <- match.arg(shape)
    v <- if (is.numeric(x)) {
      if (length(x) == 1) rep(x, n) else matrix(rep(c(0, x), each = n), n, T + 1)
    } else if (!is.null(x$dist)) {
      if (ctx$det) rep(x$mode %||% x$mean, n) else {
        set.seed(key_seed(ctx$seed, key))
        u <- runif(n); a <- x$min; b <- x$max; m <- x$mode; Fc <- (m - a) / (b - a)
        r <- ifelse(u < Fc, a + sqrt(u * (b - a) * (m - a)), b - sqrt((1 - u) * (b - a) * (b - m)))
        ctx$draws[[key]] <- r; r
      }
    } else if (!is.null(x$driver)) {
      ctx$driver(x$driver) * (x$scale %||% 1)
    } else stop("Unbekannte Wertangabe")
    if (shape == "path" && is.null(dim(v))) v <- matrix(v, n, T + 1)
    v
  }
  ctx$driver_cache <- list()
  ctx$driver <- function(name) {
    if (is.null(ctx$driver_cache[[name]])) {
      if (ctx$det) p <- matrix(1.02^(0:T), n, T + 1, byrow = TRUE) else {
        set.seed(key_seed(ctx$seed, paste0("drivers.", name)))
        z <- matrix(rnorm(n * T, 0.02, 0.015), n, T)
        p <- cbind(1, z + 1); for (t in 2:(T + 1)) p[, t] <- p[, t - 1] * p[, t]
      }
      ctx$driver_cache[[name]] <- p
    }
    ctx$driver_cache[[name]]
  }
  ctx
}
`%||%` <- function(a, b) if (is.null(a)) b else a

row <- function(id, values, label, section, category, tax_class) {
  list(id = id, values = values, label = label, section = section,
       category = category, tax_class = tax_class)
}

# ---- eingebaute Typen ----
register_type("investment", "flow", function(spec, ctx) {
  m <- ctx$zero()
  m[, spec$period + 1] <- -ctx$resolve(spec$amount_eur, paste0(spec$.path, ".amount_eur"), "scalar")
  list(rows = list(row(spec$id, m, spec$label, "originaer", "investition", spec$tax_class %||% "herstellungskosten")),
       meta = list(afa_basis = -m[, spec$period + 1] * (1 - (spec$land_share %||% 0))))
})
register_type("rent", "flow", function(spec, ctx) {
  base <- ctx$resolve(spec$rent_eur_m2_month, paste0(spec$.path, ".rent"), "path")
  idx <- ctx$resolve(spec$index, paste0(spec$.path, ".index"), "path")
  m <- base * idx * ctx$object$area_m2 * 12; m[, 1:(spec$start_period)] <- 0
  list(rows = list(row(spec$id, m, spec$label, "originaer", "miete", "einnahme_vv")))
})
register_type("share_of", "flow", function(spec, ctx) {
  ref <- ctx$flows[[spec$of]]$rows[[1]]$values
  list(rows = list(row(spec$id, -spec$share * ref, spec$label, "originaer", spec$category, "werbungskosten_sofort")))
})
register_type("annuity_loan", "financing", function(spec, ctx) {
  n <- ctx$n; T <- ctx$T
  amount <- if (identical(spec$amount_eur, "auto")) pmax(-ctx$t0_gap(), 0) else rep(spec$amount_eur, n)
  rate <- rep(spec$rate_pa, n); bal <- amount
  ann <- amount * spec$rate_pa / (1 - (1 + spec$rate_pa)^-spec$term_years)
  aus <- ctx$zero(); zin <- ctx$zero(); til <- ctx$zero(); rs <- ctx$zero()
  aus[, 1] <- amount; rs[, 1] <- amount
  for (t in seq_len(T)) {
    z <- bal * rate; tl <- pmin(pmax(ann - z, 0), bal); bal <- bal - tl
    zin[, t + 1] <- -z; til[, t + 1] <- -tl; rs[, t + 1] <- bal
  }
  list(rows = list(row(paste0(spec$id, ".auszahlung"), aus, "Kreditaufnahme", "kredit", "kredit_aufnahme", "steuerneutral"),
                   row(paste0(spec$id, ".zins"), zin, "Sollzinsen", "kredit", "zins", "zins_finanzierung"),
                   row(paste0(spec$id, ".tilgung"), til, "Tilgung", "kredit", "tilgung", "steuerneutral")),
       stocks = list(row(paste0(spec$id, ".restschuld"), rs, "Kreditstand", "bestand", "schuld", NA)))
})
register_type("equity", "financing", function(spec, ctx) {
  m <- ctx$zero(); m[, 1] <- spec$amount_eur
  list(rows = list(row(spec$id, m, "Eigenkapital", "eigenkapital", "ek_einlage", "steuerneutral")))
})

# ---- Steuer-Hook: Standard "keine Steuern" + Beispiel pauschal ----
tax_none <- list(name = "none", prepare = function(ctx, rows) NULL,
                 step = function(tctx, t, endo, state) list(tax = 0, state = state))
tax_flat <- function(rate) list(
  name = "flat",
  prepare = function(ctx, rows) {
    # steuerliche Bemessungsgrundlage aus getaggten Zeilen (exogener Teil), AfA 3 % linear
    basis <- ctx$zero()
    for (r in rows) if (r$tax_class %in% c("einnahme_vv", "werbungskosten_sofort", "zins_finanzierung")) basis <- basis + r$values
    afa_b <- Reduce(`+`, lapply(ctx$flows, function(f) f$meta$afa_basis %||% 0))
    afa <- matrix(afa_b * 0.03, ctx$n, ctx$T + 1); afa[, 1] <- 0
    list(basis = basis - afa)
  },
  step = function(tctx, t, endo, state) {
    zvE <- tctx$basis[, t] + endo$habenzins - endo$sollzins_kk
    list(tax = -rate * zvE, state = state)  # vereinfachte Verlustverrechnung (Erstattung)
  })

# ---- Engine ----
engine_run <- function(spec, n, seed = 1, deterministic = FALSE, tax = tax_none) {
  T <- spec$time$horizon_years
  ctx <- new_ctx(n, T, seed, deterministic, spec$object)
  rows_of <- function(kind) unlist(lapply(ctx$flows[vapply(ctx$flows, function(f) f$kind == kind, TRUE)], `[[`, "rows"), recursive = FALSE)
  # 1) originaere Zahlungen in Reihenfolge (Topologie hier: Listenreihenfolge)
  for (id in names(spec$components)) {
    s <- spec$components[[id]]; s$id <- id; s$.path <- paste0("components.", id)
    f <- get_type(s$type)$build(s, ctx); f$kind <- "flow"; ctx$flows[[id]] <- f
  }
  # 2) Finanzierung; "auto"-Instrumente zuletzt (decken Restbedarf in t0)
  fin <- spec$financing
  is_auto <- vapply(fin, function(s) identical(s$amount_eur, "auto"), TRUE)
  ctx$t0_gap <- function() Reduce(`+`, lapply(unlist(lapply(ctx$flows, `[[`, "rows"), recursive = FALSE), function(r) r$values[, 1]))
  for (id in c(names(fin)[!is_auto], names(fin)[is_auto])) {
    s <- fin[[id]]; s$id <- id; s$.path <- paste0("financing.", id)
    f <- get_type(s$type)$build(s, ctx); f$kind <- "financing"; ctx$flows[[id]] <- f
  }
  rows <- unlist(lapply(ctx$flows, `[[`, "rows"), recursive = FALSE)
  exo <- Reduce(`+`, lapply(rows, `[[`, "values"))
  # 3) Ausgleichsschleife ueber t, vektorisiert ueber N, mit Steuer-Hook
  h <- spec$settings$habenzins; s_ <- spec$settings$sollzins; lim <- spec$settings$kk_limit
  tctx <- tax$prepare(ctx, rows); tstate <- NULL
  G <- K <- ZH <- ZS <- TX <- NA_ <- AN <- KD <- ctx$zero()
  g <- k <- rep(0, n)
  for (t in seq_len(T + 1)) {
    zh <- h * g; zs <- s_ * k
    tx <- tax$step(tctx, t, list(habenzins = zh, sollzins_kk = zs), tstate)
    tstate <- tx$state
    cf <- exo[, t] + zh - zs + tx$tax
    net <- g - k + cf
    g2 <- pmax(net, 0); k2 <- pmin(pmax(-net, 0), lim); na <- pmax(-net - lim, 0)
    AN[, t] <- -(g2 - g); KD[, t] <- k2 - k; ZH[, t] <- zh; ZS[, t] <- -zs; TX[, t] <- tx$tax; NA_[, t] <- na
    g <- g2; k <- k2; G[, t] <- g; K[, t] <- k
  }
  saldo <- exo + ZH + ZS + TX + AN + KD + NA_
  stocks <- unlist(lapply(ctx$flows, `[[`, "stocks"), recursive = FALSE)
  debt_T <- Reduce(`+`, lapply(stocks, function(r) r$values[, T + 1]), 0)
  list(endwert = G[, T + 1] - K[, T + 1] - debt_T, max_saldo = max(abs(saldo)),
       rows = rows, n_rows = length(rows) + 7, draws = ctx$draws)
}

# ---- Beispielszenario mit vielen Komponenten ----
spec <- list(
  time = list(horizon_years = 40),
  object = list(area_m2 = 800),
  settings = list(habenzins = 0.02, sollzins = 0.09, kk_limit = 5e4),
  components = c(
    list(bau = list(type = "investment", period = 0, label = "Baukosten",
                    amount_eur = list(dist = "triangular", min = 1.1e6, mode = 1.2e6, max = 1.5e6), land_share = 0.2),
         miete = list(type = "rent", label = "Mieteinnahmen", start_period = 1,
                      rent_eur_m2_month = 10.5, index = list(driver = "miete_index"))),
    setNames(lapply(1:20, function(i) list(type = "share_of", of = "miete", share = 0.005,
                                           label = paste("Kostenposition", i), category = "bewirtschaftung")),
             paste0("kosten_", 1:20))),
  financing = list(ek = list(type = "equity", amount_eur = 3e5),
                   kfw = list(type = "annuity_loan", amount_eur = 1.5e5, rate_pa = 0.015, term_years = 20),
                   bank = list(type = "annuity_loan", amount_eur = "auto", rate_pa = 0.038, term_years = 30)))

d1 <- engine_run(spec, 1, deterministic = TRUE)
cat("Deterministisch: Endwert", round(d1$endwert), " max|Saldo|", d1$max_saldo, " Zeilen", d1$n_rows, "\n")
mc <- engine_run(spec, 1e4, seed = 42)
cat("MC N=10000: max|Saldo|", mc$max_saldo, " Median EW", round(median(mc$endwert)), "\n")
mc_tax <- engine_run(spec, 1e4, seed = 42, tax = tax_flat(0.3))
cat("MC mit Steuer-Hook (pauschal 30 %): Median EW", round(median(mc_tax$endwert)), "\n")
# CRN: Variante ohne KfW -> identische Ziehung der Baukosten
spec2 <- spec; spec2$financing$kfw <- NULL; spec2$components$kosten_20 <- NULL
mc2 <- engine_run(spec2, 1e4, seed = 42)
cat("CRN Baukosten-Ziehung identisch zwischen Varianten:",
    identical(mc$draws[["components.bau.amount_eur"]], mc2$draws[["components.bau.amount_eur"]]), "\n")
cat("P(Variante mit KfW besser):", mean(mc$endwert > mc2$endwert), "\n")
print(bench::mark(det = engine_run(spec, 1, deterministic = TRUE),
                  mc = engine_run(spec, 1e4, seed = 42),
                  mc_tax = engine_run(spec, 1e4, seed = 42, tax = tax_flat(0.3)),
                  iterations = 5, check = FALSE)[, c("expression", "median", "mem_alloc")])
