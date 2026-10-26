# Monte-Carlo-Schleife, Baender, keep_runs, Kompositum (WS-G, Spec 00 Abschnitte 9.2, 9.9,
# 9.11, 11.4, 12.7, 13.2; Spec 01 Teil C 1.2, 6.1, 6.2).
# vofi_mc(): Einstellungen nach R-97 (Argumente > Szenario/Overlay > Preset > Defaults; preview =
# Preset preview), Sampler-Plan je Lauf (smp_configure()), Chunks aus ganzen Bloecken
# (eng_chunk_plan()), Chunk-Lauf eng_run_chunk() (sequenziell oder ueber future.apply ohne
# eigene Zufallszahlen in den Workern), Sammler eng_store_init()/eng_store()/
# eng_store_finalize(), Meldungen der Typen ueber alle Chunks zusammengefasst (je Meldung
# einmal), Markierungen und Ue3-Hinweis einmal je Lauf (eng_flag_conditions(),
# eng_warn_prepay()), Statistik (mc_stats(), R/mc-stats.R), Quantilbaender der Kennzahlreihen,
# keep_runs ueber vofi_sim(), Entscheidungsknoten als Kompositum mit bedingter Statistik (9.11)
# und Ampel fuer Modelle mit Primaerkennzahl delta_terminal_value (12.9, cmp_traffic_light()).
# Lauf i haengt nur von Seed, Schluessel, Blockgroesse und Block ab (11.4), nicht von n_sim,
# Chunk-Groesse oder Worker-Zahl.

#' Monte-Carlo-Simulation
#'
#' Führt die Monte-Carlo-Simulation in Chunks aus ganzen Blöcken aus (Spec 00, Abschnitte 9.2,
#' 9.9, 11.4). Nicht gesetzte (`NULL`) Argumente kommen aus `stochastic$settings` (dort
#' alternativ `replicates`, Abschnitt 11.4); Vorrang nach R-97: Argumente vor ausdrücklich
#' gesetzten Feldern des Szenarios vor dem Preset vor den Defaults. `preview = TRUE` entspricht
#' dem Preset `preview` und rechnet 1.000 Läufe (= die ersten 1.000 Läufe des Standardlaufs)
#' mit `store = "kpi"` und ohne `keep_runs`, soweit die Argumente nichts anderes angeben.
#'
#' Lauf i hängt nur von Seed, Schlüssel, Blockgröße und Block ab, nicht von `n_sim`, der
#' Chunk-Größe oder der Zahl der Worker. Kennzahlen: ausdrücklich angeforderte Kennzahlen
#' (`analysis.kpis` im Szenario bzw. als Override) werden alle gerechnet, sonst die Kennzahlen
#' mit MC-Default (Spec 00, Abschnitt 12.3; das Entnahme-Äquivalent nur auf Anforderung, R-51).
#' Hat die Variante einen Entscheidungsknoten der Förderzusage (Abschnitt 9.11), laufen
#' Variante und Ausweichvariante mit denselben Rohziehungen; das Ergebnis ist das Kompositum
#' (Spalte `branch` in `kpis`) mit bedingter Statistik in `decision`.
#'
#' Das Ergebnis enthält Kennzahlen, NA-Gründe, statische Ziehungen und Pfadmerkmale aller Läufe,
#' die Statistik je Kennzahl (Mittelwert, Standardabweichung, Replikat-Standardfehler aus den
#' Blockmitteln mit `se_df`, Quantile, Verlustwahrscheinlichkeit, Mittel der schlechtesten 5 %,
#' erwarteter Nachteil, NA-Anteil, deterministischer Wert, Konvergenzausweis; Abschnitt 12.7),
#' bei `store = "bands"` bzw. `"full"` die Fächerbänder und die nachgerechneten Läufe
#' `keep_runs`, bei `"full"` zusätzlich den Ledger aller Läufe, die Unterlassungsalternative und
#' die Ziehungen (Abschnitt 13.2).
#'
#' @param model Objekt der Klasse `vofi_model`.
#' @param n_sim Anzahl der Läufe (Vielfaches der Blockgröße).
#' @param seed Seed (ganze Zahl in `[1, 2^31 - 2]`).
#' @param sampling `"lhs"` oder `"pseudo"`.
#' @param block_size Läufe je Block (Default 200).
#' @param store `"bands"`, `"kpi"` oder `"full"` (Default `"bands"`).
#' @param bands Ledger-Zeilen, für die Fächerbänder gebildet werden.
#' @param keep_runs zu speichernde Einzelläufe, z. B. `c("p05", "p50", "p95")`.
#' @param parallel Chunks über `future.apply` verteilen (Ergebnisse identisch).
#' @param chunk_size Läufe je Chunk.
#' @param preview Vorschau mit 1.000 Läufen.
#' @return Objekt der Klasse `vofi_mc_result`.
#' @family Analysieren
#' @examples
#' sc <- vofi_read_scenario(vofi_example("grob_lehrbuch_a"))
#' model <- vofi_build(sc, overrides = list(analysis = list(
#'   kpis = c("terminal_value", "terminal_value_opp", "delta_terminal_value"))))
#' mc <- vofi_mc(model, n_sim = 200, seed = 1, store = "kpi")
#' mc$stats[, c("kpi", "mean", "se", "q05", "q95", "p_neg")]
#' @export
vofi_mc <- function(model, n_sim = NULL, seed = NULL, sampling = NULL, block_size = NULL,
                    store = NULL, bands = NULL, keep_runs = NULL, parallel = FALSE,
                    chunk_size = getOption("vofi.chunk_size", 2000L), preview = FALSE) {
  t0 <- proc.time()[["elapsed"]]
  model <- mc_force_model(model)
  cfg <- mc_config(model, n_sim = n_sim, seed = seed, sampling = sampling,
                   block_size = block_size, store = store, bands = bands,
                   keep_runs = keep_runs, parallel = parallel, chunk_size = chunk_size,
                   preview = preview)
  model <- cfg$model
  eng_warn_prepay(model)
  eng_check_memory(model, cfg$chunk_runs)
  det <- mc_capture(mc_deterministic(model))
  run <- mc_run_chunks(cfg$chunks, function(blocks) mc_chunk(model, blocks, cfg), cfg$parallel)
  mc_emit_conditions(c(det$conditions, run$conditions))
  res <- mc_assemble(model, cfg, run$chunks, det$value, t0)
  eng_flag_conditions(res$flags)
  res
}

# ---------------------------------------------------------------------------------------------
# Einstellungen (R-97, 11.4, 9.9)
# ---------------------------------------------------------------------------------------------

#' Einstellungen eines MC-Laufs auflösen und den Sampler-Plan konfigurieren
#'
#' Vorrang (R-97): Funktionsargumente > Felder aus `stochastic$settings` (bereits nach Preset
#' und Schichten aufgelöst, `smp_resolve_settings()`). `preview = TRUE` setzt die Werte des
#' Presets `preview` (n_sim 1.000, `store = "kpi"`, keine `keep_runs`) für nicht gesetzte
#' Argumente. Mit `store = "kpi"` werden keine Einzelläufe gespeichert (9.9).
#' @param model `vofi_model`.
#' @param return_paths Rückgabepfade je Lauf (9.2; Vergleich).
#' @param kpis `NULL` (Auswahl nach `mc_kpi_names()`) oder Kennzahlnamen.
#' @return Liste der Einstellungen inkl. konfiguriertem Modell (`model`), Chunkplan
#'   (`chunks`), Vereinigungsplan bei Entscheidungsknoten (`union`).
#' @noRd
mc_config <- function(model, n_sim = NULL, seed = NULL, sampling = NULL, block_size = NULL,
                      store = NULL, bands = NULL, keep_runs = NULL, parallel = FALSE,
                      chunk_size = getOption("vofi.chunk_size", 2000L), preview = FALSE,
                      return_paths = character(), kpis = NULL) {
  if (!inherits(model, "vofi_model")) {
    vofi_abort("mc.not_model", arg = "model", .class = "vofi_error_input")
  }
  if (!inherits(model$sampler, "smp_plan")) {
    vofi_abort("core.not_implemented", fun = "smp_plan()", .class = "vofi_error_not_implemented")
  }
  if (!utl_is_flag(parallel)) mc_abort_flag("parallel")
  if (!utl_is_flag(preview)) mc_abort_flag("preview")
  s <- model$sampler$settings
  if (preview) {
    pv <- smp_presets()$preview
    n_sim <- n_sim %||% pv$n_sim
    store <- store %||% pv$store
    keep_runs <- keep_runs %||% pv$keep_runs
  }
  n_sim <- utl_check_whole(n_sim %||% s$n_sim %||% smp_presets()$standard$n_sim, "n_sim",
                           min = 2)
  seed <- seed %||% s$seed
  if (is.null(seed)) vofi_abort("mc.seed_missing", .class = "vofi_error_input")
  seed <- utl_check_seed(seed)
  store <- utl_match_arg(store %||% s$store %||% "bands", c("bands", "kpi", "full"), "store")
  bands <- bands %||% s$bands %||% c("net_position", "dep_balance", "od_balance")
  if (!is.character(bands) || anyNA(bands)) {
    vofi_abort("mc.arg_character", arg = "bands", .class = "vofi_error_input")
  }
  keep_runs <- keep_runs %||% s$keep_runs %||% character(0)
  if (!is.character(keep_runs) || anyNA(keep_runs) ||
        !all(grepl("^p[0-9]{1,2}(\\.[0-9]+)?$", keep_runs))) {
    vofi_abort("mc.keep_runs_invalid", value = utl_collapse(format(keep_runs)),
               .class = "vofi_error_input")
  }
  if (identical(store, "kpi")) keep_runs <- character(0)
  chunk_size <- utl_check_whole(chunk_size, "chunk_size", min = 1)
  plan <- smp_configure(model$sampler, n_sim = n_sim, seed = seed, sampling = sampling,
                        block_size = block_size)
  m <- smp_plan_m(plan)
  chunks <- eng_chunk_plan(n_sim, m, chunk_size)
  model$sampler <- plan
  union <- NULL
  if (!is.null(model$decision)) {
    fb <- model$decision$fallback
    fb$sampler <- mc_align_plan(fb$sampler, plan)
    model$decision$fallback <- fb
    union <- smp_plan_union(list(plan, fb$sampler))
    miss <- union(setdiff(names(model$kpis), names(fb$kpis)),
                  setdiff(names(fb$kpis), names(model$kpis)))
    if (length(miss) > 0L) {
      vofi_abort("mc.decision_kpis", variant = model$decision$fallback_variant,
                 kpis = utl_collapse(miss), .class = "vofi_error_validation")
    }
  }
  st <- plan$settings
  if ("wealth" %in% bands) return_paths <- union(return_paths, "wealth")
  list(model = model, n_sim = n_sim, seed = seed, block_size = m,
       replicates = as.integer(n_sim %/% m), store = store, bands = as.character(bands),
       band_probs = as.double(st$band_probs %||% c(0.05, 0.25, 0.5, 0.75, 0.95)),
       keep_runs = as.character(keep_runs),
       keep_runs_kpi = st$keep_runs_kpi %||% "delta_terminal_value",
       convergence = st$convergence, chunks = chunks,
       chunk_runs = as.integer(length(chunks[[1L]]) * m), parallel = parallel, union = union,
       kpis = kpis %||% mc_kpi_names(model, st$keep_runs_kpi), return_paths = return_paths,
       preview = preview, settings = st)
}

#' Argument `model` auswerten; Mindestblockgröße der Korrelationsgruppe als Eingabefehler
#'
#' Eine zu kleine Blockgröße für eine Korrelationsgruppe ist nach Spec 00 11.4 (und 15.5 Nr. 7)
#' `vofi_error_input`; die Validierung beim Bau des Modells meldet sie als
#' `validation.stochastic.block_too_small` mit `vofi_error_validation` (Spec 01 Teil C 1.2).
#' Wird das Modell erst beim Aufruf von `vofi_mc()` gebaut (Argument), trägt der Fehler beide
#' Klassen (Änderungsantrag WS-G-03).
#' @noRd
mc_force_model <- function(model) {
  withCallingHandlers(model, vofi_error_validation = function(e) {
    rep <- e$data$report
    if (is.data.frame(rep) && "validation.stochastic.block_too_small" %in% rep$code &&
          !inherits(e, "vofi_error_input")) {
      class(e) <- c("vofi_error_input", class(e))
      stop(e)
    }
  })
}

#' Fehler für ein logisches Argument
#' @noRd
mc_abort_flag <- function(arg) {
  vofi_abort("mc.arg_flag", arg = arg, .class = "vofi_error_input")
}

#' Plan der Ausweichvariante an den Plan der Variante angleichen (CRN, 9.11 Nr. 4, 11.10)
#'
#' Gleiche Läufe, gleicher Seed, gleiches Verfahren und gleiche Blockgröße, damit
#' `smp_plan_union()` beide vereinigen kann und beide Modelle dieselben Rohziehungen nutzen.
#' @noRd
mc_align_plan <- function(plan, to) {
  if (!inherits(plan, "smp_plan")) return(plan)
  for (f in c("n_sim", "seed", "sampling", "block_size", "replicates", "antithetic")) {
    plan$settings[f] <- list(to$settings[[f]])
  }
  smp_check_sampling(plan$settings, smp_plan_m(plan), plan)
  plan$hash <- smp_plan_hash(plan)
  plan
}

#' Wurde `analysis.kpis` ausdrücklich gesetzt (Schicht >= 3, R-97-Logik)?
#'
#' Ohne Herkunftsangabe gilt ein gesetzter Wert als ausdrücklich (Spezifikation aus einer Liste).
#' @noRd
mc_kpis_explicit <- function(spec) {
  sel <- spec$analysis$kpis
  if (is.null(sel) || identical(sel, "default")) return(FALSE)
  prov <- attr(spec, "provenance")
  if (is.data.frame(prov) && all(c("path", "layer") %in% names(prov))) {
    hit <- prov$layer[prov$path == "analysis.kpis"]
    if (length(hit) > 0L && !is.na(hit[length(hit)])) return(max(hit, na.rm = TRUE) >= 3)
  }
  TRUE
}

#' Kennzahlen der Simulation (12.3, R-51)
#'
#' Ausdrücklich angeforderte Kennzahlen (`analysis.kpis` aus Schicht >= 3) alle, sonst die
#' Kennzahlen mit `mc_default = TRUE`; die Auswahlkennzahl von `keep_runs` und die
#' Primärkennzahl kommen stets hinzu, sofern das Modell sie rechnet.
#' @return Zeichenvektor.
#' @noRd
mc_kpi_names <- function(model, extra = NULL) {
  defs <- model$kpis
  if (length(defs) == 0L) return(character(0))
  if (mc_kpis_explicit(model$spec)) return(names(defs))
  keep <- names(defs)[vapply(defs, function(d) isTRUE(d$mc_default), logical(1))]
  add <- intersect(c(extra, kpi_primary(model$spec)$kpi, "delta_terminal_value",
                     "terminal_value", "terminal_value_opp"), names(defs))
  names(defs)[names(defs) %in% union(keep, add)]
}

# ---------------------------------------------------------------------------------------------
# Chunks, Meldungen, Parallelisierung (9.9, 11.12, 2.9)
# ---------------------------------------------------------------------------------------------

#' Ein Chunk der Simulation (9.2 Stufen 1-9), bei Entscheidungsknoten als Kompositum (9.11)
#' @return Liste `chunk` (Ergebnis wie `eng_run_chunk()`), `v`, `f` (Kennzahlen der Variante
#'   bzw. der Ausweichvariante bei Entscheidungsknoten, sonst `NULL`).
#' @noRd
mc_chunk <- function(model, blocks, cfg) {
  run <- function(m, raw = NULL) {
    ch <- eng_run_chunk(m, blocks = blocks, seed = cfg$seed, mode = "mc", store = cfg$store,
                        bands = cfg$bands, raw = raw, return_paths = cfg$return_paths,
                        kpis = cfg$kpis)
    mc_fill_bands(ch, m, cfg, cfg$store)
  }
  if (is.null(model$decision)) return(list(chunk = run(model), v = NULL, f = NULL))
  raw <- smp_sample(cfg$union, blocks, cfg$seed)
  cv <- run(model, raw)
  cf <- run(model$decision$fallback, raw)
  list(chunk = mc_composite(cv, cf), v = cv[c("kpis", "kpi_na", "sims", "blocks", "n")],
       f = cf[c("kpis", "kpi_na", "sims", "blocks", "n")])
}

#' Bandzeilen eines Chunks mit vollständigem Ledger (store = "full", 9.9, Teil C 6.2)
#'
#' Die Engine bildet Bandzeilen nur bei `store = "bands"`; mit `"full"` werden sie hier aus
#' dem Ledger (Bestands- und Flusszeilen), der Unterlassungsalternative
#' (`opp_net_position`), den Nachschüssen (`equity_calls`) bzw. dem Rückgabepfad `wealth`
#' gebildet (gleiche Werte wie bei `"bands"`).
#' @noRd
mc_fill_bands <- function(ch, model, cfg, store) {
  if (!identical(store, "full") || identical(cfg$store, "kpi") || length(cfg$bands) == 0L ||
        is.null(ch$ledger)) {
    return(ch)
  }
  v <- ch$ledger$values
  bv <- list()
  for (k in cfg$bands) {
    x <- switch(k,
      opp_net_position = ch$opp$BS,
      equity_calls = v$equity_call + v$shortfall,
      wealth = ch$paths$wealth,
      v[[k]]
    )
    if (is.null(x)) vofi_abort("engine.band_unknown", row = k, .class = "vofi_error_input")
    bv[[k]] <- x
  }
  ch$band_values <- bv
  ch
}

#' Ausdruck auswerten und Meldungen bzw. Warnungen des Pakets sammeln (statt sie auszugeben)
#' @return Liste `value`, `conditions`.
#' @noRd
mc_capture <- function(expr) {
  acc <- new.env(parent = emptyenv())
  acc$conds <- list()
  value <- withCallingHandlers(expr,
    vofi_warning = function(w) {
      acc$conds[[length(acc$conds) + 1L]] <- w
      invokeRestart("muffleWarning")
    },
    vofi_message = function(m) {
      acc$conds[[length(acc$conds) + 1L]] <- m
      invokeRestart("muffleMessage")
    }
  )
  list(value = value, conditions = acc$conds)
}

#' Gesammelte Meldungen einmal ausgeben (zusammengefasst über alle Chunks)
#'
#' Gleiche Meldungen (Klasse und Text) aus mehreren Chunks erscheinen genau einmal.
#' @return `invisible(Anzahl ausgegebener Meldungen)`.
#' @noRd
mc_emit_conditions <- function(conds) {
  if (length(conds) == 0L) return(invisible(0L))
  ids <- vapply(conds, function(cnd) {
    paste(class(cnd)[1L], cnd$key %||% "", conditionMessage(cnd), sep = "\r")
  }, "")
  keep <- conds[!duplicated(ids)]
  for (cnd in keep) {
    if (inherits(cnd, "warning")) warning(cnd) else message(cnd)
  }
  invisible(length(keep))
}

#' Läuft das Paket im Entwicklungsmodus (pkgload)? Worker können es dann nicht laden.
#' @noRd
mc_dev_mode <- function() {
  ns <- topenv(environment(mc_dev_mode))
  !is.null(get0(".__DEVTOOLS__", envir = ns, inherits = FALSE))
}

#' Rechnet der aktuelle future-Plan im selben Prozess (`sequential`)?
#' @noRd
mc_future_inprocess <- function() {
  if (!requireNamespace("future", quietly = TRUE)) return(FALSE)
  inherits(future::plan(), c("sequential", "uniprocess"))
}

#' Chunks sequenziell oder über `future.apply` rechnen (9.9, R-28, 11.12)
#'
#' Die Worker ziehen nur benannte Ströme ihrer Blöcke (`with_stream()`), die Ergebnisse sind
#' daher unabhängig von der Zahl der Worker. Meldungen werden je Chunk gesammelt und vom
#' Aufrufer einmal ausgegeben. Im Entwicklungsmodus (Paket nicht installiert) wird mit einem
#' Plan in eigenen Prozessen sequenziell gerechnet (Hinweis), weil die Worker den
#' Entwicklungs-Namespace nicht sehen; der Plan `future::sequential` läuft im selben Prozess und
#' geht auch dort über `future.apply`.
#' @param chunks Liste der Blockvektoren.
#' @param fun Funktion `blocks -> Ergebnis`.
#' @param parallel logisch.
#' @return Liste `chunks` (Ergebnisse), `conditions`.
#' @noRd
mc_run_chunks <- function(chunks, fun, parallel = FALSE) {
  wrap <- function(blocks) mc_capture(fun(blocks))
  if (isTRUE(parallel) && length(chunks) > 1L) {
    utl_require("future.apply", "vofi_mc")
    if (mc_dev_mode() && !mc_future_inprocess()) {
      vofi_inform("mc.parallel_dev")
      parallel <- FALSE
    }
  }
  out <- if (isTRUE(parallel) && length(chunks) > 1L) {
    future.apply::future_lapply(chunks, wrap, future.seed = FALSE)
  } else {
    lapply(chunks, wrap)
  }
  list(chunks = lapply(out, function(o) o$value),
       conditions = do.call(c, lapply(out, function(o) o$conditions)))
}

# ---------------------------------------------------------------------------------------------
# Kompositum (9.11 Nr. 4)
# ---------------------------------------------------------------------------------------------

#' Zeilenweise Auswahl zweier Vektoren (V bei `sel`, sonst F)
#' @noRd
mc_pick_vec <- function(xv, xf, sel) {
  out <- xf
  out[sel] <- xv[sel]
  out
}

#' Zeilenweise Auswahl zweier Matrizen
#' @noRd
mc_pick_mat <- function(mv, mf, sel) {
  if (is.null(mv) || is.null(mf) || !identical(dim(mv), dim(mf))) return(mv %||% mf)
  out <- mf
  out[sel, ] <- mv[sel, , drop = FALSE]
  out
}

#' Zeilenweise Auswahl zweier Data Frames (Spalten der Vereinigung; fehlende Spalte: NA)
#' @noRd
mc_pick_df <- function(dv, df, sel) {
  if (is.null(dv) || is.null(df)) return(dv %||% df)
  cols <- c(names(dv), setdiff(names(df), names(dv)))
  out <- lapply(cols, function(cn) {
    a <- dv[[cn]]
    b <- df[[cn]]
    if (is.null(a)) {
      b[sel] <- NA
      return(b)
    }
    if (is.null(b)) {
      a[!sel] <- NA
      return(a)
    }
    mc_pick_vec(a, b, sel)
  })
  names(out) <- cols
  as.data.frame(out, stringsAsFactors = FALSE, optional = TRUE)
}

#' Spalten zweier Data Frames gleicher Zeilen vereinigen (erste gewinnt)
#' @noRd
mc_merge_cols <- function(a, b) {
  if (is.null(a) || is.null(b)) return(a %||% b)
  for (cn in setdiff(names(b), names(a))) a[[cn]] <- b[[cn]]
  a
}

#' Zeilenweise Auswahl zweier Ledger (Zeilen der Vereinigung, fehlende Zeile im Zweig: 0)
#' @noRd
mc_pick_ledger <- function(lv, lf, sel) {
  if (is.null(lv) || is.null(lf)) return(lv %||% lf)
  extra <- setdiff(lf$rows$key, lv$rows$key)
  rows <- lv$rows
  if (length(extra) > 0L) {
    add <- lf$rows[match(extra, lf$rows$key), , drop = FALSE]
    idx <- c(seq_len(nrow(rows)), nrow(rows) + seq_len(nrow(add)))
    rows <- mc_rbind_rows(rows, add)
    ord <- order(rows$order, idx, method = "radix")
    rows <- rows[ord, , drop = FALSE]
    rownames(rows) <- NULL
  }
  values <- lapply(rows$key, function(k) {
    a <- lv$values[[k]]
    b <- lf$values[[k]]
    if (is.null(a)) {
      b[sel, ] <- 0
      return(b)
    }
    if (is.null(b)) {
      a[!sel, ] <- 0
      return(a)
    }
    mc_pick_mat(a, b, sel)
  })
  names(values) <- rows$key
  new_vofi_ledger(rows, values, n = lv$n, T = lv$T)
}

#' Zeilenmetadaten zweier Ledger untereinander (inkl. Listenspalte `extra`)
#' @noRd
mc_rbind_rows <- function(a, b) {
  out <- lapply(names(a), function(cn) {
    x <- a[[cn]]
    y <- b[[cn]]
    if (is.list(x)) return(I(c(unclass(x), unclass(y))))
    c(x, y)
  })
  names(out) <- names(a)
  as.data.frame(out, stringsAsFactors = FALSE, optional = TRUE)
}

#' Ziehungsobjekte zweier Modelle derselben Rohziehungen vereinigen (Schlüssel der Vereinigung)
#' @noRd
mc_merge_draws <- function(dv, df) {
  if (is.null(dv) || is.null(df)) return(dv %||% df)
  for (f in c("static", "decision", "u", "annual", "paths", "scenario_index")) {
    for (k in setdiff(names(df[[f]]), names(dv[[f]]))) dv[[f]][[k]] <- df[[f]][[k]]
  }
  tg <- df$targets
  if (is.data.frame(tg) && nrow(tg) > 0L) {
    new <- tg[!(tg$target %in% dv$targets$target), , drop = FALSE]
    if (nrow(new) > 0L) dv$targets <- rbind(dv$targets, new)
  }
  dv$features <- mc_merge_cols(dv$features, df$features)
  dv
}

#' Kompositum zweier Chunk-Ergebnisse (Variante V, Ausweichvariante F; 9.11 Nr. 4)
#'
#' x_i = b_i x^V_i + (1 - b_i) x^F_i als zeilenweise Auswahl für Kennzahlen, NA-Gründe,
#' Markierungen, Reihen, Bänder, Rückgabepfade, Unterlassungsalternative und Ledger; `decision`
#' = Zweig je Lauf (1 = Zusage, 0 = Ausweichvariante).
#' @noRd
mc_composite <- function(cv, cf) {
  b <- as.double(cv$decision %||% rep(1, cv$n))
  sel <- !is.na(b) & b == 1
  out <- cv
  out$kpis <- mc_pick_df(cv$kpis, cf$kpis, sel)
  out$kpi_na <- mc_pick_df(cv$kpi_na, cf$kpi_na, sel)
  out$flags <- mc_pick_df(cv$flags, cf$flags, sel)
  out$inputs <- mc_merge_cols(cv$inputs, cf$inputs)
  out$features <- mc_merge_cols(cv$features, cf$features)
  for (nm in names(cv$kpi_series)) {
    sf <- cf$kpi_series[[nm]]
    if (!is.null(sf) && identical(sf$years, cv$kpi_series[[nm]]$years)) {
      out$kpi_series[[nm]]$values <- mc_pick_mat(cv$kpi_series[[nm]]$values, sf$values, sel)
      na_v <- cv$kpi_series[[nm]]$na_reason
      if (!is.null(na_v) && !is.null(sf$na_reason)) {
        out$kpi_series[[nm]]$na_reason <- mc_pick_vec(na_v, sf$na_reason, sel)
      }
    }
  }
  for (nm in names(cv$band_values)) {
    out$band_values[[nm]] <- mc_pick_mat(cv$band_values[[nm]], cf$band_values[[nm]], sel)
  }
  for (nm in names(cv$paths)) out$paths[[nm]] <- mc_pick_mat(cv$paths[[nm]], cf$paths[[nm]], sel)
  out$opp$BS <- mc_pick_mat(cv$opp$BS, cf$opp$BS, sel)
  out$opp$EW <- mc_pick_vec(cv$opp$EW, cf$opp$EW, sel)
  out$opp$ledger <- mc_pick_ledger(cv$opp$ledger, cf$opp$ledger, sel)
  out$ledger <- mc_pick_ledger(cv$ledger, cf$ledger, sel)
  out$draws <- mc_merge_draws(cv$draws, cf$draws)
  if (is.data.frame(cv$checks) && is.data.frame(cf$checks)) {
    out$checks$max_dev <- pmax(cv$checks$max_dev, cf$checks$max_dev)
    out$checks$ok <- out$checks$max_dev <= out$checks$tol
  }
  out$decision <- b
  out
}

# ---------------------------------------------------------------------------------------------
# Deterministischer Lauf, Zusammenführung, keep_runs (9.9, 13.2)
# ---------------------------------------------------------------------------------------------

#' Deterministischer Lauf des Modells (Basisfall; bei Entscheidungsknoten der realisierte Zweig)
#' @noRd
mc_deterministic <- function(model) {
  dec <- model$decision
  if (is.null(dec)) return(eng_run_single(model, NULL, signal = FALSE))
  b <- as.integer(dec$branch %||% 1L)
  realized <- if (b == 1L) model else dec$fallback
  other <- if (b == 1L) dec$fallback else model
  res <- eng_run_single(realized, NULL, signal = FALSE)
  alt <- eng_run_single(other, NULL, signal = FALSE)
  res$decision <- list(funding_id = dec$funding_id, fallback_variant = dec$fallback_variant,
                       p_approval = dec$p, branch = b, alternative = alt)
  res
}

#' Ledger der Chunks untereinander (gleiche Zeilen)
#' @noRd
mc_bind_ledgers <- function(leds) {
  leds <- Filter(Negate(is.null), leds)
  if (length(leds) == 0L) return(NULL)
  if (length(leds) == 1L) return(leds[[1L]])
  first <- leds[[1L]]
  values <- lapply(first$rows$key, function(k) {
    do.call(rbind, lapply(leds, function(l) l$values[[k]]))
  })
  names(values) <- first$rows$key
  new_vofi_ledger(first$rows, values, n = sum(vapply(leds, function(l) l$n, integer(1))),
                  T = first$T)
}

#' Ziehungsobjekte der Chunks untereinander (store = "full")
#' @noRd
mc_bind_draws <- function(ds) {
  ds <- Filter(Negate(is.null), ds)
  if (length(ds) == 0L) return(NULL)
  if (length(ds) == 1L) return(ds[[1L]])
  d1 <- ds[[1L]]
  cat_vec <- function(f) {
    out <- lapply(names(d1[[f]]), function(k) {
      unlist(lapply(ds, function(d) d[[f]][[k]]), use.names = FALSE)
    })
    stats::setNames(out, names(d1[[f]]))
  }
  cat_mat <- function(f) {
    out <- lapply(names(d1[[f]]), function(k) do.call(rbind, lapply(ds, function(d) d[[f]][[k]])))
    stats::setNames(out, names(d1[[f]]))
  }
  new_vofi_draws(
    "mc", n = sum(vapply(ds, function(d) d$n, integer(1))),
    sims = unlist(lapply(ds, function(d) d$sims), use.names = FALSE),
    blocks = unlist(lapply(ds, function(d) d$blocks), use.names = FALSE),
    block_size = d1$block_size, static = cat_vec("static"), decision = cat_vec("decision"),
    u = cat_vec("u"), targets = d1$targets, annual = cat_mat("annual"), paths = cat_mat("paths"),
    years = d1$years, scenario_index = cat_vec("scenario_index"),
    features = eng_rbind_df(lapply(ds, function(d) d$features)), meta = d1$meta
  )
}

#' Quantile und Mittel der Kennzahlreihen je Jahr (13.2)
#' @param series Reihen aus `eng_store_finalize()` (`values` n x P, `years`).
#' @param probs Quantilniveaus (`band_probs`).
#' @param keep_values Werte je Lauf behalten (`store = "full"`).
#' @noRd
mc_series_summary <- function(series, probs, keep_values = FALSE) {
  lapply(series, function(s) {
    v <- s$values
    q <- vapply(seq_len(ncol(v)), function(j) {
      x <- v[, j]
      if (all(is.na(x))) return(rep(NA_real_, length(probs)))
      stats::quantile(x, probs, type = 7, names = FALSE, na.rm = TRUE)
    }, numeric(length(probs)))
    q <- matrix(q, nrow = length(probs))
    rownames(q) <- paste0("q", sprintf("%02d", round(100 * probs)))
    mean_y <- vapply(seq_len(ncol(v)), function(j) {
      x <- v[, j]
      if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
    }, double(1))
    out <- list(quantiles = q, mean = mean_y, years = s$years,
                na_share = colMeans(is.na(v)))
    if (keep_values) out$values <- v
    out
  })
}

#' Kennzahlen der Läufe mit `sim`, `block` (und `branch` bei Entscheidungsknoten)
#' @noRd
mc_kpi_frame <- function(fin, decision = FALSE) {
  k <- fin$kpis
  if (decision && !is.null(fin$decision)) {
    k <- cbind(k[, c("sim", "block"), drop = FALSE],
               data.frame(branch = as.integer(round(fin$decision))),
               k[, setdiff(names(k), c("sim", "block")), drop = FALSE])
  }
  k
}

#' Kennzahlen eines Zweigs über alle Chunks (bedingte Statistik, 9.11 Nr. 5)
#' @noRd
mc_branch_kpis <- function(chunks, which, m) {
  parts <- lapply(chunks, function(ch) ch[[which]])
  parts <- Filter(Negate(is.null), parts)
  if (length(parts) == 0L) return(NULL)
  k <- eng_rbind_df(lapply(parts, function(p) p$kpis))
  sims <- unlist(lapply(parts, function(p) p$sims), use.names = FALSE)
  cbind(data.frame(sim = sims, block = as.integer((sims - 1L) %/% m + 1L)), k)
}

#' Ergebnisobjekt der Simulation zusammensetzen (9.9, 13.2)
#' @param model konfiguriertes Modell.
#' @param cfg Einstellungen aus `mc_config()`.
#' @param chunks Ergebnisse von `mc_chunk()`.
#' @param det deterministisches Ergebnis (`vofi_result`).
#' @param t0 Startzeit (für `runtime_sec`).
#' @return Objekt der Klasse `vofi_mc_result`.
#' @noRd
mc_assemble <- function(model, cfg, chunks, det, t0) {
  acc <- eng_store_init(cfg$store, cfg$band_probs)
  for (ch in chunks) eng_store(acc, ch$chunk)
  fin <- eng_store_finalize(acc)
  has_dec <- !is.null(model$decision)
  kpis <- mc_kpi_frame(fin, has_dec)
  kna <- fin$kpi_na
  stats <- mc_stats(kpis, deterministic = det$kpis, convergence = cfg$convergence)
  full <- identical(cfg$store, "full")
  opportunity <- NULL
  draws <- NULL
  if (full) {
    opps <- lapply(chunks, function(ch) ch$chunk$opp)
    opportunity <- list(ledger = mc_bind_ledgers(lapply(opps, function(o) o$ledger)),
                        BS = do.call(rbind, lapply(opps, function(o) o$BS)),
                        EW = unlist(lapply(opps, function(o) o$EW), use.names = FALSE))
    draws <- mc_bind_draws(lapply(chunks, function(ch) ch$chunk$draws))
  }
  decision <- NULL
  if (has_dec) {
    dec <- model$decision
    kv <- mc_branch_kpis(chunks, "v", cfg$block_size)
    kf <- mc_branch_kpis(chunks, "f", cfg$block_size)
    det_v <- if (identical(as.integer(dec$branch %||% 1L), 1L)) det else det$decision$alternative
    det_f <- if (identical(as.integer(dec$branch %||% 1L), 1L)) det$decision$alternative else det
    decision <- list(funding_id = dec$funding_id, fallback_variant = dec$fallback_variant,
                     key = dec$key, p_approval = dec$p,
                     share_approved = mean(fin$decision == 1, na.rm = TRUE),
                     stats_approved = mc_stats(kv, deterministic = det_v$kpis,
                                               convergence = cfg$convergence),
                     stats_fallback = mc_stats(kf, deterministic = det_f$kpis,
                                               convergence = cfg$convergence))
  }
  st <- model$sampler$settings
  r <- cfg$replicates
  notes <- character(0)
  if (r < 10L) notes <- c(notes, lbl("mc.notes.se_rough", r = r))
  if (r == 1L) notes <- c(notes, lbl("mc.notes.se_naive"))
  meta <- det$meta
  meta$mode <- "mc"
  meta$n_sim <- cfg$n_sim
  meta$seed <- cfg$seed
  meta$sim_index <- NULL
  meta$store <- cfg$store
  meta$sampling <- st$sampling
  meta$replicates <- r
  meta$block_size <- cfg$block_size
  meta$copula <- st$copula
  meta$antithetic <- isTRUE(st$antithetic)
  meta$chunk_size <- cfg$chunk_runs
  meta$n_chunks <- length(cfg$chunks)
  meta$repaired <- model$sampler$repaired %||% list(parameters = NULL, shocks = NULL)
  meta$rng_kind <- c("Mersenne-Twister", "Inversion", "Rejection")
  meta$plan_hash <- model$sampler$hash
  meta$keep_runs_kpi <- cfg$keep_runs_kpi
  meta$preview <- cfg$preview
  meta$se_rough <- r < 10L
  meta$kpis_mc <- cfg$kpis
  meta$created <- Sys.time()
  meta$notes <- c(meta$notes %||% character(0), notes)
  res <- new_vofi_mc_result(list(
    spec = model$spec, grid = model$grid, model = model, kpis = kpis, kpi_na = kna,
    kpi_series = mc_series_summary(fin$kpi_series, cfg$band_probs, full),
    inputs = fin$inputs, features = fin$features, flags = fin$flags, bands = fin$bands,
    runs = list(), run_index = stats::setNames(integer(0), character(0)),
    deterministic = det, stats = stats, checks = fin$checks,
    ledger = if (full) fin$ledger else NULL, decision = decision, traffic_light = NULL,
    meta = meta
  ))
  if (full) {
    res$opportunity <- opportunity
    res$draws <- draws
  }
  res <- mc_keep_runs(res, cfg$keep_runs, cfg$keep_runs_kpi)
  if (identical(kpi_primary(model$spec)$kpi, "delta_terminal_value")) {
    res$traffic_light <- cmp_traffic_light(res)
  }
  res$meta$runtime_sec <- proc.time()[["elapsed"]] - t0
  res
}

#' Einzelläufe `keep_runs` bestimmen und nachrechnen (9.9)
#'
#' Auswahlkennzahl `keep_runs_kpi` (Default `delta_terminal_value`; fehlt sie, die
#' Primärkennzahl bzw. die erste Kennzahl); je `p<zz>` der Lauf mit kleinstem Abstand zum
#' Quantil (Gleichstand: kleinster Index), nachgerechnet mit `vofi_sim()` (identisch zum Batch;
#' bei Entscheidungsknoten auf dem Kompositum).
#' @noRd
mc_keep_runs <- function(res, keep, kpi) {
  if (length(keep) == 0L) return(res)
  cols <- setdiff(names(res$kpis), c("sim", "block", "branch"))
  if (length(cols) == 0L) return(res)
  k <- kpi
  if (!(k %in% cols)) {
    k <- intersect(c(kpi_primary(res$spec)$kpi, "delta_terminal_value"), cols)
    k <- if (length(k) > 0L) k[1L] else cols[1L]
    vofi_inform("mc.keep_runs_kpi_missing", kpi = kpi, used = k)
  }
  idx <- eng_keep_runs(res$kpis[[k]], keep)
  runs <- lapply(idx, function(i) {
    if (is.na(i)) return(NULL)
    mc_quiet(vofi_sim(res, i))
  })
  res$runs <- runs
  res$run_index <- idx
  res$meta$keep_runs_kpi <- k
  res
}

#' Ausdruck ohne Meldungen und Warnungen des Pakets auswerten
#' @noRd
mc_quiet <- function(expr) mc_capture(expr)$value
