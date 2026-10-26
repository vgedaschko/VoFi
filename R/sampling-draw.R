# Ziehungen je Chunk (WS-C; Spec 00 Abschnitte 11.4, 11.5, 11.6, 11.7, 11.8, 11.10).
# smp_sample() erzeugt die Rohziehungen (korrelierte Uniforms, korrelierte Schocks,
# Szenario-Uniforms) für ganze Blöcke; smp_materialize() wendet Quantilfunktionen und Prozesse
# an und bildet das Ziehungsobjekt vofi_draws; smp_draw() = smp_materialize(smp_sample(...)).
# Methoden print() und as.data.frame() für vofi_draws (Spec 00 13.6).

# ---------------------------------------------------------------------------------------------
# Blöcke, Replikate, Chunks (11.4)
# ---------------------------------------------------------------------------------------------

#' Blockgröße m eines Laufs mit n_sim Läufen
#'
#' Feste Blockgröße (Default 200, R-73) bzw. im F21-Modus m = n_sim / replicates. n_sim MUSS ein
#' Vielfaches von m (bzw. durch R teilbar) sein, sonst `vofi_error_input` mit Vorschlag der
#' nächsten Vielfachen.
#' @param settings Einstellungen des Plans.
#' @param n_sim Anzahl der Läufe.
#' @return integer(1).
#' @noRd
smp_block_size <- function(settings, n_sim) {
  n_sim <- utl_check_whole(n_sim, "n_sim", min = 1)
  r <- settings$replicates
  if (!is.null(r)) {
    r <- as.integer(r)
    if (n_sim %% r != 0L) smp_abort_multiple("sampling.n_sim_replicates", n_sim, r)
    return(as.integer(n_sim %/% r))
  }
  m <- as.integer(settings$block_size %||% 200L)
  if (n_sim %% m != 0L) smp_abort_multiple("sampling.n_sim_not_multiple", n_sim, m)
  m
}

#' Fehler „n_sim kein Vielfaches“ mit den nächsten Vielfachen als Vorschlag
#'
#' Unteres und oberes Vielfaches von `m` um `n_sim`; ist n_sim < m, gibt es nur einen Vorschlag
#' (Label `<key>_single`).
#' @noRd
smp_abort_multiple <- function(key, n_sim, m) {
  lower <- (n_sim %/% m) * m
  upper <- (n_sim %/% m + 1L) * m
  if (lower < m) {
    key <- paste0(key, "_single")
    lower <- upper
  }
  vofi_abort(key, n_sim = n_sim, block_size = m, replicates = m, lower = lower, upper = upper,
             .class = "vofi_error_input")
}

#' Einstellungen eines Laufs setzen und prüfen (Vorrang der Funktionsargumente, R-97)
#'
#' Nicht gesetzte (`NULL`) Argumente kommen aus dem Plan. `block_size` als Argument beendet den
#' F21-Modus, `replicates` schaltet ihn ein (m = n_sim / R, mit Hinweis). Geprüft werden
#' n_sim als Vielfaches der Blockgröße, die Mindestblockgröße der Korrelationsgruppe
#' (m ≥ max(2, d + 1)), `antithetic` nur mit `pseudo` und geradem m sowie der Seed.
#' @param plan `smp_plan`.
#' @param n_sim,seed,sampling,block_size,replicates Argumente des Laufs bzw. `NULL`.
#' @param preview `TRUE` entspricht `preset: preview` (n_sim 1.000, sofern nicht gesetzt).
#' @return `smp_plan` mit aktualisierten `settings` (u. a. `block_size` = m) und neuem Hash.
#' @noRd
smp_configure <- function(plan, n_sim = NULL, seed = NULL, sampling = NULL, block_size = NULL,
                          replicates = NULL, preview = FALSE) {
  smp_check_plan(plan)
  s <- plan$settings
  if (isTRUE(preview) && is.null(n_sim)) n_sim <- smp_presets()$preview$n_sim
  if (!is.null(n_sim)) s$n_sim <- utl_check_whole(n_sim, "n_sim", min = 1)
  if (!is.null(seed)) s$seed <- utl_check_seed(seed)
  if (!is.null(sampling)) s$sampling <- utl_match_arg(sampling, c("lhs", "pseudo"), "sampling")
  if (!is.null(block_size)) {
    s$block_size <- utl_check_whole(block_size, "block_size", min = 2)
    s["replicates"] <- list(NULL)
  } else if (!is.null(replicates)) {
    s$replicates <- utl_check_whole(replicates, "replicates", min = 1)
    s["block_size"] <- list(NULL)
  }
  m <- smp_block_size(s, s$n_sim)
  if (!is.null(s$replicates)) {
    vofi_inform("sampling.replicates_mode", replicates = s$replicates, block_size = m)
  }
  smp_check_sampling(s, m, plan)
  plan$settings <- s
  plan$hash <- smp_plan_hash(plan)
  plan
}

#' Ziehungseinstellungen gegen die Blockgröße prüfen
#' @noRd
smp_check_sampling <- function(s, m, plan) {
  if (m < 2L) {
    vofi_abort("sampling.setting_invalid", field = "block_size", value = m, choices = ">= 2",
               .class = "vofi_error_input")
  }
  if (isTRUE(s$antithetic)) {
    if (identical(s$sampling, "lhs")) {
      vofi_abort("sampling.antithetic_lhs", .class = "vofi_error_input")
    }
    if (m %% 2L != 0L) {
      vofi_abort("sampling.antithetic_odd", block_size = m, .class = "vofi_error_input")
    }
  }
  g <- plan$corr_pearson$parameters
  if (!is.null(g) && identical(s$copula, "iman_conover")) {
    smp_check_block_size(m, nrow(g), s$replicates)
  }
  invisible(TRUE)
}

#' Blöcke eines Laufs mit n_sim Läufen: 1…R
#' @noRd
smp_blocks <- function(plan, n_sim) {
  seq_len(as.integer(n_sim) %/% smp_block_size(plan$settings, n_sim))
}

#' Chunks aus ganzen Blöcken (Spec 00 9.9)
#'
#' `chunk_size` wird auf ein Vielfaches der Blockgröße abgerundet (mindestens ein Block).
#' @return Liste von Blockvektoren.
#' @noRd
smp_chunks <- function(plan, n_sim, chunk_size = getOption("vofi.chunk_size", 2000L)) {
  m <- smp_block_size(plan$settings, n_sim)
  blocks <- seq_len(as.integer(n_sim) %/% m)
  per <- max(1L, as.integer(chunk_size) %/% m)
  unname(split(blocks, (blocks - 1L) %/% per))
}

#' Plan prüfen
#' @noRd
smp_check_plan <- function(plan, arg = "plan") {
  if (!inherits(plan, "smp_plan")) {
    vofi_abort("sampling.not_plan", arg = arg, .class = "vofi_error_input")
  }
  invisible(plan)
}

#' Blockgröße der Ziehung (aus den Einstellungen; F21-Modus über n_sim)
#' @noRd
smp_plan_m <- function(plan) {
  s <- plan$settings
  if (!is.null(s$block_size)) return(as.integer(s$block_size))
  smp_block_size(s, s$n_sim)
}

# ---------------------------------------------------------------------------------------------
# Rohziehungen (11.5, 11.6)
# ---------------------------------------------------------------------------------------------

#' Rohziehungen für ganze Blöcke
#'
#' Je Block b und statischem Schlüssel die Uniforms aus `par:<key>:<b>` (LHS bzw. Pseudo), die
#' Korrelationsgruppe je Block mit Iman-Conover (Scores aus `ic:<key>:<b>`) bzw. Gauß-Copula; je
#' Prozess mit Schocks die Schockmatrix aus `shock:<proc>:<b>` (Spalte für Spalte), korreliert
#' mit `Z %*% chol(R)`; je Prozess mit Uniforms der Szenarioindex aus `scen:<proc>:<b>` (weitere
#' Spalten aus `uni:<proc>:<b>`).
#' @param plan `smp_plan` (auch die Vereinigung, `smp_plan_union()`).
#' @param blocks globale Blockindizes.
#' @param seed Seed (ganze Zahl in `[1, 2^31 − 2]`).
#' @return Objekt der Klasse `smp_raw`.
#' @noRd
smp_sample <- function(plan, blocks, seed) {
  smp_check_plan(plan)
  seed <- utl_check_seed(seed)
  blocks <- as.integer(blocks)
  if (length(blocks) == 0L || anyNA(blocks) || any(blocks < 1L) || anyDuplicated(blocks)) {
    vofi_abort("sampling.blocks_invalid", blocks = dist_fmt(blocks),
               .class = "vofi_error_input")
  }
  s <- plan$settings
  m <- smp_plan_m(plan)
  smp_check_sampling(s, m, plan)
  y <- length(plan$years)
  keys <- plan$static$key
  procs <- plan$processes
  u0 <- list()
  for (k in keys) {
    u0[[k]] <- unlist(lapply(blocks, function(b) {
      smp_uniforms(seed, smp_stream_name("par", k, b), m, s$sampling, s$antithetic)
    }), use.names = FALSE)
  }
  u <- smp_correlate_static(u0, plan$corr_pearson$parameters, s$copula, seed, blocks, m)
  sc <- list()
  z <- smp_sample_shocks(smp_shocked(plan), plan$corr_pearson$shocks, blocks, m, y, seed, s)
  for (p in names(procs)) {
    nu <- procs[[p]]$n_uniforms
    if (nu >= 1L) {
      sc[[p]] <- do.call(rbind, lapply(blocks, function(b) {
        first <- smp_uniforms(seed, smp_stream_name("scen", p, b), m, s$sampling, s$antithetic)
        more <- if (nu > 1L) {
          smp_uniform_matrix(seed, smp_stream_name("uni", p, b), m, nu - 1L, s$sampling,
                             s$antithetic)
        }
        cbind(first, more, deparse.level = 0)
      }))
    }
  }
  structure(list(
    seed = seed, blocks = blocks, block_size = m, n = length(blocks) * m,
    sims = smp_sims_of(blocks, m), years = plan$years, u = u, u_indep = u0, z = z,
    scen = sc, settings = s, plan_hash = plan$hash,
    corr = list(parameters = plan$corr_pearson$parameters, shocks = plan$corr_pearson$shocks,
                copula = s$copula)
  ), class = "smp_raw")
}

#' Korrelationsgruppe statischer Größen je Block korrelieren (Iman-Conover bzw. Gauß-Copula)
#' @param u0 benannte Liste unabhängiger Uniforms (n-Vektoren, Block für Block).
#' @param target Pearson-Zielmatrix der Gruppe oder `NULL`.
#' @param copula `"iman_conover"` oder `"gaussian"`.
#' @return Liste wie `u0`.
#' @noRd
smp_correlate_static <- function(u0, target, copula, seed, blocks, m) {
  if (is.null(target)) return(u0)
  grp <- rownames(target)
  if (!all(grp %in% names(u0))) {
    vofi_abort("sampling.raw_mismatch", what = utl_collapse(setdiff(grp, names(u0))),
               .class = "vofi_error_contract")
  }
  u <- u0
  if (identical(copula, "iman_conover")) smp_check_block_size(m, length(grp))
  for (i in seq_along(blocks)) {
    rows <- (i - 1L) * m + seq_len(m)
    ub <- vapply(grp, function(k) u0[[k]][rows], numeric(m))
    if (!is.matrix(ub)) ub <- matrix(ub, nrow = m)
    res <- if (identical(copula, "gaussian")) {
      smp_gauss_copula(ub, target)
    } else {
      smp_iman_conover(ub, target, smp_ic_block_scores(seed, grp, blocks[i], m), blocks[i])
    }
    for (j in seq_along(grp)) u[[grp[j]]][rows] <- res[, j]
  }
  u
}

#' Prozessschocks der Blöcke erzeugen und je Block korrelieren
#'
#' Je Block b und Prozess die Schocks aus `shock:<proc>:<b>` (Spalte für Spalte), danach die
#' Korrelationsgruppe des Blocks mit einer Multiplikation `Z %*% chol(R)` (11.6 Nr. 5).
#' @param procs Schlüssel der Prozesse mit Schocks.
#' @param target Pearson-Matrix der Schockgruppe oder `NULL`.
#' @param y Anzahl der Prozessjahre (Schockspalten y − 1).
#' @param s Einstellungen (`sampling`, `antithetic`).
#' @return benannte Liste n × (y − 1)-Matrizen (Block für Block).
#' @noRd
smp_sample_shocks <- function(procs, target, blocks, m, y, seed, s) {
  if (length(procs) == 0L) return(list())
  grp <- if (is.null(target)) character(0) else intersect(rownames(target), procs)
  if (length(grp) >= 2L) target <- target[grp, grp, drop = FALSE] else grp <- character(0)
  per_block <- lapply(blocks, function(b) {
    zb <- lapply(stats::setNames(procs, procs), function(p) {
      smp_shocks(seed, smp_stream_name("shock", p, b), m, y - 1L, s$sampling, s$antithetic)
    })
    if (length(grp) >= 2L) zb[grp] <- smp_correlate_shocks(zb[grp], target)
    zb
  })
  lapply(stats::setNames(procs, procs), function(p) {
    do.call(rbind, lapply(per_block, function(zb) zb[[p]]))
  })
}

# ---------------------------------------------------------------------------------------------
# Ziehungsobjekt (11.7, 11.8)
# ---------------------------------------------------------------------------------------------

#' Rohziehungen auf eine Variante anwenden
#'
#' Quantilfunktionen auf die korrelierten Uniforms (Korrelation auf Uniform-Ebene, R-59),
#' Prozesse in topologischer Reihenfolge, Abbildung auf das Raster mit `grid_map_years()` und
#' Pfadmerkmale. Die Variante übernimmt die korrelierten Uniforms und Schocks der Rohziehungen
#' (gleicher Schlüssel = gleiche Ziehung, 11.10 Nr. 1), wenn ihre Korrelationsangaben zu denen
#' der Rohziehungen passen (`smp_corr_compatible()`: gleiche Paare, die Vereinigung darf weitere
#' Schlüssel enthalten). Nur im Konfliktfall (abweichende Paare, Reparatur der vereinigten
#' Matrix, andere Copula; `smp_plan_union()` warnt dann mit `vofi_warning_correlation`) wird
#' die Gruppe der Variante aus denselben Strömen mit ihren eigenen Angaben neu korreliert
#' (CRN eingeschränkt, 11.10 Nr. 2). Die Schockspalten werden nach Kalenderjahr zugeordnet:
#' Beginnen die Prozessjahre der Variante später als die der Rohziehungen, beginnt sie bei der
#' Schockspalte ihres Startjahres.
#' @param raw `smp_raw` aus `smp_sample()`.
#' @param plan `smp_plan` der Variante.
#' @param grid `vofi_grid` der Variante.
#' @return Objekt der Klasse `vofi_draws` (Modus `"mc"`).
#' @noRd
smp_materialize <- function(raw, plan, grid) {
  smp_check_plan(plan)
  if (!inherits(raw, "smp_raw")) {
    vofi_abort("sampling.raw_mismatch", what = "smp_raw", .class = "vofi_error_contract")
  }
  n <- raw$n
  m <- raw$block_size
  shocked <- smp_shocked(plan)
  miss <- setdiff(c(plan$static$key, shocked), c(names(raw$u), names(raw$z)))
  if (length(miss) > 0L) {
    vofi_abort("sampling.raw_mismatch", what = utl_collapse(miss), .class = "vofi_error_contract")
  }
  years <- as.integer(grid$years)
  off <- smp_year_offset(years, raw$years)
  u <- raw$u
  if (!smp_corr_compatible(plan$corr_pearson$parameters, raw$corr$parameters,
                           smp_value_keys(plan), plan$settings$copula, raw$corr$copula)) {
    u <- smp_correlate_static(raw$u_indep[plan$static$key], plan$corr_pearson$parameters,
                              plan$settings$copula, raw$seed, raw$blocks, m)
  }
  z <- raw$z
  if (!smp_corr_compatible(plan$corr_pearson$shocks, raw$corr$shocks, shocked)) {
    # abweichende Schockkorrelation der Variante: dieselben Ströme neu erzeugen und mit den
    # eigenen Angaben korrelieren (CRN eingeschränkt, 11.10 Nr. 2)
    z <- smp_sample_shocks(shocked, plan$corr_pearson$shocks, raw$blocks, m,
                           length(raw$years), raw$seed, raw$settings)
  }
  # Schockspalten der Variante: Kalenderjahre years[2], years[3], ... (Versatz off)
  cols <- off + seq_len(max(length(years) - 1L, 0L))
  z <- lapply(z[intersect(shocked, names(z))], function(zz) zz[, cols, drop = FALSE])
  static <- list()
  decision <- list()
  uu <- list()
  for (i in seq_len(nrow(plan$static))) {
    k <- plan$static$key[i]
    def <- reg_get("distribution", plan$static$dist[i])
    x <- as.double(def$quantile(u[[k]], plan$static_par[[k]]))
    uu[[k]] <- u[[k]]
    if (identical(plan$static$role[i], "decision")) decision[[k]] <- x else static[[k]] <- x
  }
  sim <- smp_simulate_processes(plan, static, z, raw$scen, years, n)
  paths <- lapply(sim$annual, function(a) grid_map_years(grid, a))
  st <- plan$static
  targets <- data.frame(
    key = c(st$key, names(plan$processes)),
    target = c(st$target, vapply(plan$processes, function(p) p$target, "", USE.NAMES = FALSE)),
    kind = c(ifelse(st$role == "decision", "decision", "static"),
             rep("process", length(plan$processes))),
    apply = c(st$apply, rep("replace", length(plan$processes))),
    stringsAsFactors = FALSE
  )
  new_vofi_draws(
    "mc", n = n, sims = raw$sims, blocks = raw$blocks, block_size = m, static = static,
    decision = decision, u = uu, targets = targets, annual = sim$annual, paths = paths,
    years = years, scenario_index = sim$scenario,
    features = smp_features(plan, sim, paths, grid, n),
    meta = smp_draws_meta(plan, raw$seed, m)
  )
}

#' Metadaten des Ziehungsobjekts (11.8)
#' @noRd
smp_draws_meta <- function(plan, seed, m) {
  s <- plan$settings
  r <- if (utl_is_whole(s$n_sim) && m > 0L) as.integer(s$n_sim %/% m) else NA_integer_
  list(seed = seed, sampling = s$sampling, block_size = as.integer(m), replicates = r,
       copula = s$copula, antithetic = s$antithetic,
       rng_kind = c("Mersenne-Twister", "Inversion", "Rejection"),
       repaired = list(parameters = plan$repaired$parameters, shocks = plan$repaired$shocks),
       plan_hash = plan$hash)
}

#' Prozesse eines Chunks simulieren (topologische Reihenfolge)
#'
#' Unsichere Prozessparameter erhalten ihre Ziehung `<proc>.<param>` (n-Vektor); das Token
#' `u0 = base` wird je Lauf zu x_det − a − b · base_1 (g_1 = x_det, R-95).
#' @return Liste `annual` (n × Y je Prozess), `scenario` (Szenarioindex je `scenario_mix`).
#' @noRd
smp_simulate_processes <- function(plan, static, z, scen, years, n) {
  annual <- list()
  scenario <- list()
  y <- length(years)
  for (p in plan$proc_order) {
    pr <- plan$processes[[p]]
    def <- reg_get("process", pr$type)
    par <- smp_run_par(p, pr, static)
    linked <- lapply(pr$linked, function(l) annual[[l]])
    attr(linked, "n") <- n
    if (proc_is_token(par[["u0"]])) {
      base1 <- linked[["base"]][, 1L]
      par$u0 <- pr$x_det - proc_vec(par, "a", n, 0) - proc_vec(par, "b", n, 1) * base1
    }
    zp <- if (def$n_shocks(par) >= 1L && !is.null(z[[p]])) {
      z[[p]][, seq_len(y - 1L), drop = FALSE]
    }
    up <- if (def$n_uniforms(par) >= 1L) scen[[p]][, seq_len(def$n_uniforms(par)), drop = FALSE]
    x <- def$simulate(par, zp, up, years, linked)
    if (!is.null(attr(x, "scenario"))) scenario[[p]] <- as.integer(attr(x, "scenario"))
    attr(x, "scenario") <- NULL
    # u0 = base: g_1 = x_det exakt (ohne Rundungsrest aus a + b · base_1 + u0, R-95)
    if ("u0" %in% pr$start_base) x[, 1L] <- pr$x_det
    annual[[p]] <- x
  }
  list(annual = annual, scenario = scenario)
}

#' Parameter eines Prozesses für den Lauf: Verteilungen durch die Ziehungen ersetzt
#' @noRd
smp_run_par <- function(p, pr, static) {
  par <- pr$par
  for (nm in names(par)) {
    v <- par[[nm]]
    key <- paste0(p, ".", nm)
    if (proc_is_dist(v) && !is.null(static[[key]])) {
      par[[nm]] <- static[[key]]
    } else if (is.list(v) && !proc_is_dist(v) && !is.null(names(v))) {
      for (f in names(v)) {
        k2 <- paste0(key, ".", f)
        if (proc_is_dist(v[[f]]) && !is.null(static[[k2]])) par[[nm]][[f]] <- static[[k2]]
      }
    }
  }
  par
}

#' Pfadmerkmale je Prozess (Spec 00 11.7)
#'
#' `<key>.mean` (Mittel über die Kalenderjahre der Betriebsperioden), `<key>.end` (Wert im Jahr
#' der letzten Periode), `<key>.at<jahr>` (Werte an Zinsanpassungsterminen von Krediten, die den
#' Prozess über `followup_rate_pa` nutzen) und `<key>.scenario` (`scenario_mix`).
#' @return Data Frame mit n Zeilen.
#' @noRd
smp_features <- function(plan, sim, paths, grid, n) {
  out <- data.frame(row.names = seq_len(n))
  yrs <- as.integer(grid$years)
  jj <- seq_len(grid$T + 1L)[-1L]
  op_years <- unique(grid$year[jj][grid$phase[jj] == "operation"])
  if (length(op_years) == 0L) op_years <- unique(grid$year[jj])
  if (length(op_years) == 0L) op_years <- grid$year[1L]
  cols <- match(op_years, yrs)
  cols <- cols[!is.na(cols)]
  end_col <- match(grid$year[grid$T + 1L], yrs)
  for (p in plan$proc_order) {
    a <- sim$annual[[p]]
    out[[paste0(p, ".mean")]] <- rowMeans(a[, cols, drop = FALSE])
    out[[paste0(p, ".end")]] <- a[, end_col]
    at <- smp_reset_columns(plan, grid, plan$processes[[p]]$target)
    for (nm in names(at)) out[[paste0(p, ".at", nm)]] <- paths[[p]][, at[[nm]]]
    if (!is.null(sim$scenario[[p]])) out[[paste0(p, ".scenario")]] <- sim$scenario[[p]]
  }
  out
}

#' Rasterspalten der Zinsanpassungen von Krediten mit `followup_rate_pa` auf `target`
#'
#' Erste Anpassung nach m_start + 12 · `fixed_years` Monaten, weitere alle
#' 12 · `followup_fixed_years` Monate (Spec 00 8.6, R-45); Spalte = Periode, in der der
#' Anpassungsmonat endet. Kredite ohne feste Zinsbindung oder ohne Bezug entfallen.
#' @return benannte Liste Jahr → Spaltenindex.
#' @noRd
smp_reset_columns <- function(plan, grid, target) {
  spec <- plan$spec
  if (is.null(spec)) return(list())
  out <- list()
  for (id in names(spec$financing %||% list())) {
    comp <- spec$financing[[id]]
    cols <- tryCatch(smp_loan_reset_cols(comp, grid, target), error = function(e) integer(0))
    for (j in cols) out[[as.character(grid$year[j])]] <- j
  }
  out[utl_sort(names(out))]
}

#' Anpassungsspalten eines Kredits (siehe `smp_reset_columns()`)
#' @noRd
smp_loan_reset_cols <- function(comp, grid, target) {
  def <- if (utl_is_string(comp[["type"]]) && reg_has("instrument", comp[["type"]])) {
    reg_get("instrument", comp[["type"]])
  }
  if (is.null(def)) return(integer(0))
  fr <- comp[["followup_rate_pa"]]
  if (is.null(fr) && !is.null(def$params$followup_rate_pa)) {
    fr <- def$params$followup_rate_pa$default
  }
  path <- if (is.list(fr) && identical(fr[["kind"]], "ref")) {
    fr[["path"]]
  } else if (is.list(fr)) {
    fr[["ref"]]
  }
  if (!utl_is_string(path) || !identical(path, target)) return(integer(0))
  num <- function(x) {
    if (is.list(x) && identical(x[["kind"]], "const")) x <- x[["value"]]
    if (is.numeric(x) && length(x) == 1L && is.finite(x)) as.double(x) else NA_real_
  }
  fy <- num(comp[["fixed_years"]])
  if (is.na(fy)) return(integer(0))
  ffy <- num(comp[["followup_fixed_years"]])
  st <- comp[["start"]]
  d <- if (inherits(st, "Date")) {
    st
  } else if (is.numeric(st) && length(st) == 1L) {
    as.Date(sprintf("%04d-01-01", as.integer(st)))
  } else if (identical(st, "completion")) {
    grid$completion_date
  } else if (is.character(st) && length(st) == 1L) {
    as.Date(st, optional = TRUE)
  } else {
    grid$valuation_date
  }
  if (is.na(d)) d <- grid$valuation_date
  p0 <- as.integer(grid_period_of(grid, d))
  if (is.na(p0)) return(integer(0))
  m_start <- grid$month_end[p0 + 1L]
  months <- m_start + 12 * fy
  if (!is.na(ffy) && ffy > 0) {
    months <- seq(months, grid$month_end[grid$T + 1L], by = 12 * ffy)
  }
  months <- months[months >= 1 & months <= grid$month_end[grid$T + 1L]]
  vapply(months, function(mm) which(grid$month_end >= mm)[1L], integer(1))
}

#' Ziehungen eines Chunks
#'
#' `mode = "mc"`: `smp_materialize(smp_sample(plan, blocks, seed), plan, grid)`;
#' `mode = "deterministic"`: leeres Ziehungsobjekt mit n = 1 (11.9).
#' @param plan `smp_plan`.
#' @param grid `vofi_grid`.
#' @param blocks globale Blockindizes.
#' @param seed Seed.
#' @param mode `"mc"` oder `"deterministic"`.
#' @return `vofi_draws`.
#' @noRd
smp_draw <- function(plan, grid, blocks, seed, mode = c("mc", "deterministic")) {
  mode <- utl_match_arg(mode, c("mc", "deterministic"), "mode")
  smp_check_plan(plan)
  if (mode == "deterministic") {
    return(new_vofi_draws("deterministic", n = 1L, sims = 1L, blocks = 1L, block_size = 1L,
                          years = grid$years,
                          meta = list(seed = if (is.null(seed)) NA_real_ else seed,
                                      sampling = NA_character_, block_size = 1L,
                                      replicates = NULL, copula = NA_character_,
                                      antithetic = FALSE,
                                      rng_kind = c("Mersenne-Twister", "Inversion",
                                                   "Rejection"),
                                      repaired = list(parameters = NULL, shocks = NULL),
                                      plan_hash = plan$hash)))
  }
  if (is.null(seed)) {
    vofi_abort("sampling.seed_missing", .class = "vofi_error_input")
  }
  smp_materialize(smp_sample(plan, blocks, seed), plan, grid)
}

# ---------------------------------------------------------------------------------------------
# Methoden (13.6)
# ---------------------------------------------------------------------------------------------

#' Ziehungen ausgeben
#'
#' Gibt Modus, Läufe, Blöcke, Seed und eine Übersicht der statischen Ziehungen (Ziel, Mittelwert,
#' 5-%- und 95-%-Quantil) und der Prozesspfade aus.
#' @param x Objekt der Klasse `vofi_draws`.
#' @param n Anzahl der angezeigten Schlüssel je Abschnitt.
#' @param ... nicht verwendet.
#' @return `invisible(x)`.
#' @family Rechnen
#' @examples
#' d <- vofi:::new_vofi_draws("mc", n = 3L, static = list(kosten = c(0.98, 1.05, 1.2)),
#'                            targets = data.frame(key = "kosten",
#'                                                 target = "shared.cost_factor",
#'                                                 kind = "static", apply = "replace"))
#' print(d)
#' @export
print.vofi_draws <- function(x, n = 20L, ...) {
  meta <- x$meta %||% list()
  seed <- meta$seed
  cat(lbl("sampling.print.header", mode = lbl(paste0("vocab.enums.run_mode.", x$mode)),
          n = x$n, blocks = length(x$blocks), block_size = x$block_size %||% NA_integer_,
          seed = if (is.null(seed) || is.na(seed)) "-" else format(seed, scientific = FALSE)),
      "\n", sep = "")
  tg <- x$targets
  vals <- c(x$static, x$decision)
  if (length(vals) > 0L) {
    cat(lbl("sampling.print.static", count = length(vals)), "\n", sep = "")
    keys <- utl_sort(names(vals))
    shown <- utl_sort(names(vals))[seq_len(min(length(keys), n))]
    tab <- data.frame(
      key = shown,
      target = vapply(shown, function(k) {
        t <- tg$target[tg$key == k]
        if (length(t) > 0L) t[1L] else ""
      }, ""),
      mean = fmt_num(vapply(shown, function(k) mean(vals[[k]]), numeric(1)), 4),
      q05 = fmt_num(vapply(shown, function(k) smp_q(vals[[k]], 0.05), numeric(1)), 4),
      q95 = fmt_num(vapply(shown, function(k) smp_q(vals[[k]], 0.95), numeric(1)), 4),
      stringsAsFactors = FALSE, row.names = NULL
    )
    print(tab, row.names = FALSE, right = FALSE)
    if (length(keys) > n) cat(lbl("sampling.print.more", count = length(keys) - n), "\n", sep = "")
  }
  if (length(x$paths) > 0L) {
    cat(lbl("sampling.print.processes", count = length(x$paths)), "\n", sep = "")
    keys <- utl_sort(names(x$paths))
    shown <- keys[seq_len(min(length(keys), n))]
    tab <- data.frame(
      key = shown,
      target = vapply(shown, function(k) {
        t <- tg$target[tg$key == k]
        if (length(t) > 0L) t[1L] else ""
      }, ""),
      start = fmt_num(vapply(shown, function(k) mean(x$paths[[k]][, 1L]), numeric(1)), 4),
      end = fmt_num(vapply(shown, function(k) {
        mean(x$paths[[k]][, ncol(x$paths[[k]])])
      }, numeric(1)), 4),
      stringsAsFactors = FALSE, row.names = NULL
    )
    print(tab, row.names = FALSE, right = FALSE)
    if (length(keys) > n) cat(lbl("sampling.print.more", count = length(keys) - n), "\n", sep = "")
  }
  if (length(vals) == 0L && length(x$paths) == 0L) {
    cat(lbl("sampling.print.empty"), "\n", sep = "")
  }
  invisible(x)
}

#' Quantil für die Ausgabe (type 7)
#' @noRd
smp_q <- function(v, p) as.double(stats::quantile(v, p, type = 7, names = FALSE))

#' Statische Ziehungen als Data Frame
#'
#' Eine Zeile je Lauf mit den Spalten `sim` (globale Laufnummer), `block` und je statischem
#' Schlüssel bzw. Entscheidungsschlüssel der gezogene Wert (bei `apply: multiply`/`add` der
#' Faktor bzw. Zuschlag).
#' @param x Objekt der Klasse `vofi_draws`.
#' @param row.names nicht verwendet.
#' @param optional nicht verwendet.
#' @param ... nicht verwendet.
#' @return Data Frame.
#' @family Rechnen
#' @examples
#' d <- vofi:::new_vofi_draws("mc", n = 2L, static = list(kosten = c(0.98, 1.05)),
#'                            targets = data.frame(key = "kosten",
#'                                                 target = "shared.cost_factor",
#'                                                 kind = "static", apply = "replace"))
#' as.data.frame(d)
#' @export
as.data.frame.vofi_draws <- function(x, row.names = NULL, optional = FALSE, ...) { # nolint
  m <- x$block_size
  block <- if (length(m) == 1L && !is.na(m) && m > 0L) smp_block_of(x$sims, m) else
    rep(NA_integer_, x$n)
  out <- data.frame(sim = as.integer(x$sims), block = block)
  vals <- c(x$static, x$decision)
  for (k in utl_sort(names(vals))) out[[k]] <- as.double(vals[[k]])
  out
}
