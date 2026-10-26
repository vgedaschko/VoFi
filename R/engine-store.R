# Speicherstrategie und Chunks (WS-D, Spec 00 Abschnitte 9.2 Stufe 9, 9.9, 11.4).
# eng_store_chunk(): Auswahl der Chunk-Ergebnisse nach store (full: Ledger aller Laeufe und
# Ziehungen; bands: Bandzeilen n x (T+1); kpi: weder Ledger noch Baender), Rueckgabepfade
# (net_position, opp_net_position, wealth, dep_balance, od_balance, equity_calls), statische
# Ziehungen und Pfadmerkmale je Lauf, Werte der Entscheidungsschluessel (9.11).
# Hilfen fuer die Chunk-Schleife von vofi_mc() (WS-G): Chunkplan aus ganzen Bloecken
# (eng_chunk_plan()), Sammler ueber Chunks (eng_store_init(), eng_store(), eng_store_finalize()
# mit exakten Quantilen der Bandzeilen je Spalte, type = 7), keep_runs (eng_keep_runs()),
# Speicherschaetzung mit vofi_warning_memory (eng_check_memory()).

#' Namen der Rückgabepfade je Lauf (9.2)
#' @noRd
eng_path_names <- function() {
  c("net_position", "opp_net_position", "wealth", "dep_balance", "od_balance", "equity_calls")
}

#' Berichtsmodus des Projekts (`auto`: `wu_*` -> expert, sonst household; 4.3.2)
#' @noRd
eng_report_mode <- function(spec) {
  rm <- spec$project$report_mode %||% "auto"
  if (!identical(rm, "auto")) return(rm)
  persp <- spec$project$perspective
  if (utl_is_string(persp) && startsWith(persp, "wu_")) "expert" else "household"
}

#' Vermögen mit Restwertpfad W_t (12.2, R-72)
#'
#' W_t = BS_t + RWP_t für t < T, W_T = BS_T; RWP = Merkzeilen `residual_path` mit
#' `rv_basis` = `analysis.rv_path_basis` (`auto`: `measures` im Haushaltsmodus, sonst
#' `method`); ohne solche Zeilen 0.
#' @noRd
eng_wealth <- function(model, core) {
  basis <- model$spec$analysis$rv_path_basis %||% "auto"
  if (identical(basis, "auto")) {
    basis <- if (identical(eng_report_mode(model$spec), "household")) "measures" else "method"
  }
  rwp <- ledger_sum(core$ledger, category = "residual_path", rv_basis = basis)
  w <- core$stocks$BS + rwp
  n_t <- ncol(w)
  w[, n_t] <- core$stocks$BS[, n_t]
  w
}

#' Pfad je Lauf nach Namen (9.2 return_paths, Bandzeilen)
#' @return n x (T+1) oder `NULL`.
#' @noRd
eng_path_value <- function(name, model, core, opp) {
  v <- core$ledger$values
  switch(name,
    net_position = core$stocks$BS,
    opp_net_position = opp$BS,
    wealth = eng_wealth(model, core),
    dep_balance = core$stocks$G,
    od_balance = core$stocks$KK,
    equity_calls = v$equity_call + v$shortfall,
    v[[name]]
  )
}

#' Werte der Entscheidungsschlüssel je Lauf (9.11 Nr. 3)
#'
#' MC und Design: Ziehung bzw. Designwert des Schlüssels (`draws$decision`); deterministisch: der
#' Zweig des Basisfalls (`model$decision$branch`).
#' @return n-Vektor (0/1) oder `NULL` ohne Entscheidungsknoten.
#' @noRd
eng_decision_values <- function(model, draws, n) {
  dec <- model$decision
  if (is.null(dec)) return(NULL)
  key <- dec$key
  v <- NULL
  if (!is.null(draws)) {
    v <- draws$decision[[key]]
    if (is.null(v) && !is.null(draws$targets) && nrow(draws$targets) > 0L) {
      hit <- which(draws$targets$target == key | draws$targets$key == key)
      if (length(hit) > 0L) {
        k <- draws$targets$key[hit[1L]]
        v <- draws$decision[[k]] %||% draws$static[[k]]
      }
    }
  }
  if (is.null(v)) v <- rep(as.double(dec$branch %||% 1), n)
  as.double(rep_len(v, n))
}

#' Ergebnis eines Chunks nach der Speicherstrategie (9.2 Stufe 9, 9.9)
#'
#' @param model `vofi_model`.
#' @param ctx Laufkontext.
#' @param core core der Investition (inkl. `opp`).
#' @param opp Ergebnis von `eng_opportunity()`.
#' @param kp Ergebnis von `kpi_compute()`.
#' @param draws `vofi_draws` oder `NULL`.
#' @param store `"full"`, `"bands"` oder `"kpi"`.
#' @param return_paths Namen der Rückgabepfade.
#' @param bands Bandzeilen (Ledger-Schlüssel oder Pfadnamen) oder `NULL`.
#' @return Liste nach 9.2 (ohne `registers`, `checks`).
#' @noRd
eng_store_chunk <- function(model, ctx, core, opp, kp, draws, store, return_paths = character(),
                            bands = NULL) {
  n <- ctx$n
  bad <- setdiff(return_paths, eng_path_names())
  if (length(bad) > 0L) {
    vofi_abort("engine.path_unknown", path = utl_collapse(bad),
               allowed = utl_collapse(eng_path_names()), .class = "vofi_error_input")
  }
  paths <- stats::setNames(lapply(return_paths, eng_path_value, model = model, core = core,
                                  opp = opp), return_paths)
  band_values <- list()
  if (identical(store, "bands")) {
    keys <- bands %||% model$sampler$settings$bands %||%
      c("net_position", "dep_balance", "od_balance")
    for (k in as.character(keys)) {
      v <- eng_path_value(k, model, core, opp)
      if (is.null(v)) {
        vofi_abort("engine.band_unknown", row = k, .class = "vofi_error_input")
      }
      band_values[[k]] <- v
    }
  }
  inputs <- data.frame(sim = ctx$sims)
  features <- data.frame(sim = ctx$sims)
  if (!is.null(draws)) {
    for (k in names(draws$static)) inputs[[k]] <- draws$static[[k]]
    for (k in names(draws$decision)) inputs[[k]] <- draws$decision[[k]]
    if (is.data.frame(draws$features) && ncol(draws$features) > 0L &&
          nrow(draws$features) == n) {
      for (k in names(draws$features)) features[[k]] <- draws$features[[k]]
    }
  }
  full <- identical(store, "full")
  list(kpis = kp$scalar, kpi_na = kp$na, kpi_series = kp$series, flags = core$flags,
       inputs = inputs, features = features, ledger = if (full) core$ledger else NULL,
       decision = eng_decision_values(model, draws, n), band_values = band_values,
       opp = core$opp, paths = paths, registers = NULL, draws = if (full) draws else NULL,
       checks = NULL, draws_meta = if (is.null(draws)) list() else draws$meta,
       n = n, sims = ctx$sims, blocks = ctx$blocks)
}

#' Chunkplan aus ganzen Blöcken (9.9, 11.4)
#'
#' @param n_sim Anzahl der Läufe (Vielfaches der Blockgröße).
#' @param block_size Blockgröße m.
#' @param chunk_size gewünschte Läufe je Chunk (abgerundet auf ganze Blöcke, mindestens ein
#'   Block).
#' @return Liste der Blocknummern je Chunk.
#' @noRd
eng_chunk_plan <- function(n_sim, block_size, chunk_size = getOption("vofi.chunk_size", 2000L)) {
  n_sim <- utl_check_whole(n_sim, "n_sim", min = 1)
  m <- utl_check_whole(block_size, "block_size", min = 1)
  if (n_sim %% m != 0L) {
    vofi_abort("engine.n_sim_blocks", n_sim = n_sim, block_size = m,
               suggestion = as.integer(ceiling(n_sim / m) * m), .class = "vofi_error_input")
  }
  per <- max(1L, as.integer(floor(as.double(chunk_size) / m)))
  blocks <- seq_len(n_sim %/% m)
  unname(split(blocks, ceiling(blocks / per)))
}

#' Sammler über Chunks anlegen (9.9)
#' @param store `"full"`, `"bands"` oder `"kpi"`.
#' @param band_probs Quantilniveaus der Bänder.
#' @return Umgebung.
#' @noRd
eng_store_init <- function(store = c("bands", "kpi", "full"),
                           band_probs = c(0.05, 0.25, 0.5, 0.75, 0.95)) {
  acc <- new.env(parent = emptyenv())
  acc$store <- utl_match_arg(store, c("bands", "kpi", "full"), "store")
  acc$band_probs <- as.double(band_probs)
  acc$chunks <- list()
  acc
}

#' Chunk-Ergebnis in den Sammler übernehmen (9.2 Stufe 9)
#' @param acc_store Sammler aus `eng_store_init()`.
#' @param chunk Ergebnis von `eng_run_chunk()`.
#' @return `invisible(acc_store)`.
#' @noRd
eng_store <- function(acc_store, chunk) {
  keep <- c("kpis", "kpi_na", "kpi_series", "flags", "inputs", "features", "decision",
            "band_values", "checks", "paths", "n", "sims", "blocks", "draws_meta")
  if (identical(acc_store$store, "full")) keep <- c(keep, "ledger", "opp")
  if (identical(acc_store$store, "kpi")) keep <- setdiff(keep, "band_values")
  acc_store$chunks[[length(acc_store$chunks) + 1L]] <- chunk[intersect(keep, names(chunk))]
  invisible(acc_store)
}

#' Data Frames gleicher Spalten untereinander (schnell, ohne Zeilennamen)
#' @noRd
eng_rbind_df <- function(dfs) {
  dfs <- Filter(Negate(is.null), dfs)
  if (length(dfs) == 0L) return(data.frame())
  cols <- names(dfs[[1L]])
  out <- lapply(cols, function(cn) unlist(lapply(dfs, function(d) d[[cn]]), use.names = FALSE))
  names(out) <- cols
  as.data.frame(out, stringsAsFactors = FALSE, optional = TRUE)
}

#' Sammler auswerten: Kennzahlen, Markierungen, Bänder, Prüfungen (9.9, 13.2)
#'
#' Bänder: je Bandzeile und Spalte `stats::quantile(x, band_probs, type = 7)` und Mittelwert
#' über alle Läufe; Zeilen `q05`, …, `mean`.
#' @param acc_store Sammler.
#' @return Liste `kpis` (mit `sim`, `block`), `kpi_na`, `kpi_series`, `flags`, `inputs`,
#'   `features`, `decision`, `bands`, `checks` (mit `n_runs`), `paths`, `ledger` (nur `full`).
#' @noRd
eng_store_finalize <- function(acc_store) {
  ch <- acc_store$chunks
  sims <- unlist(lapply(ch, function(x) x$sims), use.names = FALSE)
  blocks <- unlist(lapply(ch, function(x) {
    nb <- length(x$blocks)
    if (nb > 0L && x$n %% nb == 0L) rep(as.integer(x$blocks), each = x$n %/% nb) else
      rep(NA_integer_, x$n)
  }), use.names = FALSE)
  first <- function(x) if (length(x) > 0L) x[[1L]] else NULL
  with_id <- function(df, extra) {
    if (is.null(df) || ncol(df) == 0L) return(extra)
    cbind(extra, df)
  }
  kpis <- with_id(eng_rbind_df(lapply(ch, function(x) x$kpis)),
                  data.frame(sim = sims, block = blocks))
  kna <- with_id(eng_rbind_df(lapply(ch, function(x) x$kpi_na)), data.frame(sim = sims))
  flags <- with_id(eng_rbind_df(lapply(ch, function(x) x$flags)), data.frame(sim = sims))
  inputs <- eng_rbind_df(lapply(ch, function(x) x$inputs))
  features <- eng_rbind_df(lapply(ch, function(x) x$features))
  decision <- unlist(lapply(ch, function(x) x$decision), use.names = FALSE)
  series <- list()
  for (nm in names(first(ch)$kpi_series)) {
    series[[nm]] <- list(values = do.call(rbind, lapply(ch, function(x) {
      x$kpi_series[[nm]]$values
    })), years = first(ch)$kpi_series[[nm]]$years)
  }
  paths <- list()
  for (nm in names(first(ch)$paths)) {
    paths[[nm]] <- do.call(rbind, lapply(ch, function(x) x$paths[[nm]]))
  }
  bands <- list()
  probs <- acc_store$band_probs
  for (nm in names(first(ch)$band_values)) {
    m <- do.call(rbind, lapply(ch, function(x) x$band_values[[nm]]))
    q <- vapply(seq_len(ncol(m)), function(j) {
      c(stats::quantile(m[, j], probs, type = 7, names = FALSE), mean(m[, j]))
    }, numeric(length(probs) + 1L))
    q <- matrix(q, nrow = length(probs) + 1L)
    rownames(q) <- c(paste0("q", sprintf("%02d", round(100 * probs))), "mean")
    bands[[nm]] <- q
  }
  chk <- lapply(ch, function(x) x$checks)
  checks <- NULL
  if (length(chk) > 0L && !is.null(chk[[1L]])) {
    checks <- chk[[1L]]
    for (c2 in chk[-1L]) checks$max_dev <- pmax(checks$max_dev, c2$max_dev)
    checks$ok <- checks$max_dev <= checks$tol
    checks$n_runs <- length(sims)
  }
  ledger <- NULL
  if (identical(acc_store$store, "full") && length(ch) > 0L) {
    led <- ch[[1L]]$ledger
    if (length(ch) > 1L) {
      led$values <- lapply(led$rows$key, function(k) {
        do.call(rbind, lapply(ch, function(x) x$ledger$values[[k]]))
      })
      names(led$values) <- led$rows$key
      led$n <- length(sims)
    }
    ledger <- led
  }
  list(kpis = kpis, kpi_na = kna, kpi_series = series, flags = flags, inputs = inputs,
       features = features, decision = if (length(decision) == 0L) NULL else decision,
       bands = bands, checks = checks, paths = paths, ledger = ledger)
}

#' Einzelläufe für keep_runs bestimmen (9.9)
#'
#' Für `p<zz>`: der Lauf mit kleinstem |x_i - q_p(x)| (`type = 7`, gültige Läufe; Gleichstand:
#' kleinster Index).
#' @param x Kennzahlwerte je Lauf (`keep_runs_kpi`).
#' @param keep z. B. `c("p05", "p50", "p95")`.
#' @return benannter Integervektor der Laufindizes.
#' @noRd
eng_keep_runs <- function(x, keep = c("p05", "p50", "p95")) {
  keep <- as.character(keep)
  if (length(keep) == 0L) return(stats::setNames(integer(0), character(0)))
  ok <- grepl("^p[0-9]{1,2}(\\.[0-9]+)?$", keep)
  if (!all(ok)) {
    vofi_abort("engine.keep_runs_invalid", value = utl_collapse(keep[!ok]),
               .class = "vofi_error_input")
  }
  p <- as.double(sub("^p", "", keep)) / 100
  x <- as.double(x)
  out <- vapply(p, function(pp) {
    if (all(is.na(x))) return(NA_integer_)
    q <- stats::quantile(x, pp, type = 7, names = FALSE, na.rm = TRUE)
    as.integer(which.min(abs(x - q)))
  }, integer(1))
  stats::setNames(out, keep)
}

#' Speicherschätzung eines Chunks in Byte (9.9)
#'
#' (Zeilen Investition + Zeilen Alternative + Steuer-Eingabezeilen) x chunk x (T+1) x 8 Byte x 3.
#' @param model `vofi_model`.
#' @param chunk_size Läufe je Chunk.
#' @return Zahl (Byte).
#' @noRd
eng_memory_estimate <- function(model, chunk_size) {
  exo_rows <- sum(vapply(model$base$flows %||% list(), function(f) length(f$rows), integer(1)))
  eq_rows <- sum(vapply(model$base$flows %||% list(), function(f) {
    sum(vapply(f$rows, function(r) identical(r$section, "equity"), logical(1)))
  }, integer(1)))
  n_eng <- length(eng_rec_keys()) + 6L
  n_inst <- length(model$instruments)
  tax_rows <- if (isTRUE(model[["tax"]]$uses_inputs)) exo_rows + 4L * n_inst else 0L
  rows <- (exo_rows + 10L * n_inst + n_eng) + (eq_rows + 1L + n_eng) + tax_rows
  as.double(rows) * as.double(chunk_size) * (model$grid$T + 1) * 8 * 3
}

#' Speicherschätzung prüfen (vofi_warning_memory über `vofi.max_memory_gb`, 9.9)
#' @return `invisible(Schätzung in GB)`.
#' @noRd
eng_check_memory <- function(model, chunk_size) {
  gb <- eng_memory_estimate(model, chunk_size) / 1024^3
  lim <- getOption("vofi.max_memory_gb", 2)
  if (is.numeric(lim) && gb > lim) {
    sugg <- max(1L, as.integer(floor(chunk_size * lim / gb)))
    vofi_warn("engine.memory", gb = gb, limit = lim, chunk = as.integer(chunk_size),
              suggestion = sugg, .class = "vofi_warning_memory")
  }
  invisible(gb)
}
