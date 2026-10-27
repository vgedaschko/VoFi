# Testhilfen der Referenzszenarien S1-S5 (WS-S, Spec 01 Teil C Abschnitt 5;
# test-scenarios-s1-s5.R). Die Hilfen lesen die Beispiele aus inst/extdata/examples, bauen und
# rechnen jede Kombination aus Szenario, Variante, Set und Override hoechstens einmal je Testlauf
# (Zwischenspeicher wss_cache) und stellen Zugriffe auf Ledger-Zeilen und Hilfsgroessen (aux) der
# Komponenten bereit. Die Hilfsgroessen liest wss_flows() ueber die internen Engine-Funktionen
# eng_engine_env(), eng_context() und eng_flows() (WS-D, Spec 00 Abschnitt 9.2), weil die
# Pruefwerte S1-T4/T4a, S3-T3/T4 und S3-T9 Zwischenergebnisse der Typen sind, die nicht im Ledger
# stehen (Spec 00 Abschnitt 7.2: aux sind keine Ledger-Zeilen).

wss_cache <- new.env(parent = emptyenv())

#' Dateinamen der Referenzszenarien (Spec 01 Teil C 5.0 Nr. 1)
wss_ids <- c(s1 = "s1_wu_mfh_1963_eh70", s2 = "s2_wu_neubau_mfh_36we",
             s3 = "s3_eg_waermepumpe_pv", s4 = "s4_efh_1975_isfp", s5 = "s5_neubau_efh_eh40")

#' Ausdruck ohne Meldungen und Warnungen auswerten (Hinweise der Expander und Validierung)
wss_quiet <- function(expr) suppressWarnings(suppressMessages(expr))

#' Ausdruck auswerten und Meldungen sowie Warnungen als Texte einsammeln
#' @return Liste `value`, `messages`, `warnings` und `conditions` (alle Bedingungsobjekte des
#'   Pakets mit `key` und `args`, Spec 00 Abschnitt 2.10).
wss_capture <- function(expr) {
  msgs <- character(0)
  warns <- character(0)
  conds <- list()
  keep <- function(cnd) {
    if (!is.null(cnd$key)) conds[[length(conds) + 1L]] <<- cnd
  }
  value <- withCallingHandlers(
    expr,
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      keep(m)
      invokeRestart("muffleMessage")
    },
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      keep(w)
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, messages = msgs, warnings = warns, conditions = conds)
}

#' Bedingungen mit Label-Schluessel `key` aus einem Ergebnis von `wss_capture()`
wss_conditions <- function(cap, key) {
  Filter(function(cnd) identical(cnd$key, key), cap$conditions)
}

#' Laufen die Simulationsteile? (wie testthat::skip_on_cran(): nur mit NOT_CRAN = "true")
wss_mc_enabled <- function() identical(Sys.getenv("NOT_CRAN"), "true")

#' Schluessel des Zwischenspeichers
wss_key <- function(...) {
  paste(vapply(list(...), function(x) if (is.null(x)) "-" else stable_hash(x), ""),
        collapse = "|")
}

#' Wert aus dem Zwischenspeicher bzw. neu berechnen
wss_memo <- function(key, expr) {
  if (!exists(key, envir = wss_cache, inherits = FALSE)) {
    assign(key, force(expr), envir = wss_cache)
  }
  get(key, envir = wss_cache, inherits = FALSE)
}

#' Szenario einlesen (`s1` ... `s5` oder Dateiname)
wss_scenario <- function(id) {
  nm <- if (id %in% names(wss_ids)) wss_ids[[id]] else id
  wss_memo(paste0("sc|", nm), wss_quiet(vofi_read_scenario(vofi_example(nm))))
}

#' Validierungsbericht eines Szenarios (alle Varianten und Sets) als Data Frame
wss_validation <- function(id) {
  wss_memo(paste0("val|", id), as.data.frame(wss_quiet(vofi_validate(wss_scenario(id)))))
}

#' Modell einer Variante (optional mit Szenario-Set und Overrides der Schicht 8)
#'
#' Ohne Set und Overrides stammt es, wenn die Simulationsteile laufen, aus dem simulierten
#' Vergleich (dort ohnehin gebaut).
wss_model <- function(id, variant = "base", overrides = NULL, set = NULL) {
  if (is.null(overrides) && is.null(set) && wss_mc_enabled()) {
    cmp <- wss_cmp_mc(id)
    if (variant %in% names(cmp$results)) return(cmp$results[[variant]]$model)
  }
  wss_memo(paste0("model|", wss_key(id, variant, overrides, set)),
           wss_quiet(vofi_build(wss_scenario(id), variant = variant, overrides = overrides,
                                scenario_set = set)))
}

#' Vergleich aller Varianten als Simulation (n_sim = 1.000, Seed der Referenzszenarien)
wss_cmp_mc <- function(id, n_sim = 1000L) {
  wss_memo(paste0("cmpmc|", id, "|", n_sim),
           wss_quiet(vofi_compare(wss_scenario(id), n_sim = n_sim, seed = 20261025L)))
}

#' Simulation des ersten Blocks einer Variante mit vollem Ledger (`store = "full"`)
#'
#' Die Laeufe 1 bis `n_sim` sind wegen der Praefix-Stabilitaet (Spec 00 11.4, R-73) identisch zu
#' den ersten Laeufen des Vergleichs `wss_cmp_mc()`; Meldungen und Warnungen werden mit
#' `wss_capture()` eingesammelt (Liste `value`, `messages`, `warnings`, `conditions`).
wss_mc_full <- function(id, variant = "base", n_sim = 200L) {
  wss_memo(paste0("mcfull|", id, "|", variant, "|", n_sim),
           wss_capture(vofi_mc(wss_model(id, variant), n_sim = n_sim, seed = 20261025L,
                               store = "full")))
}

#' Steuerbereitschaft (Spec 00 10.10 Nr. 7): Ledger-Schluessel der Zeilen `capex_*`,
#' `acquisition_ancillary` und `subsidy_*` ohne Verweis auf ein vorhandenes Asset bzw. eine
#' Massnahme (alle Zeilen, unabhaengig von ihren Werten)
wss_tax_ready_missing <- function(res) {
  rows <- res$ledger$rows
  a_ids <- vapply(res$registers$assets, function(a) a$asset_id, "")
  m_ids <- vapply(res$registers$measures, function(m) m$measure_id, "")
  sel <- grepl("^(capex_|acquisition_ancillary$|subsidy_)", rows$tax_category)
  ref <- (!is.na(rows$asset_id) & rows$asset_id %in% a_ids) |
    (!is.na(rows$measure_id) & rows$measure_id %in% m_ids)
  rows$key[sel & !ref]
}

#' Merkzeilen `loan_<k>_repayment_grant` von Krediten ohne Tilgungszuschuss (Parameter
#' `repayment_grant` fehlt): ohne `measure_id`, in allen Perioden 0 (Spec 00 7.6, R-99)
#' @param keys Ledger-Schluessel.
#' @return logischer Vektor (TRUE = Merkzeile eines Kredits ohne Tilgungszuschuss).
wss_unfunded_grant_memo <- function(res, keys) {
  memo <- grepl("^loan_.+_repayment_grant$", keys)
  inst <- sub("^loan_(.+)_repayment_grant$", "\\1", keys)
  fin <- res$spec$financing
  no_tz <- vapply(inst, function(k) !is.null(fin[[k]]) && is.null(fin[[k]]$repayment_grant),
                  logical(1))
  zero <- vapply(keys, function(k) all(res$ledger$values[[k]] == 0), logical(1))
  unname(memo & no_tz & zero)
}

#' Deterministisches Ergebnis einer Variante
#'
#' Ohne Set und Overrides stammt es, wenn die Simulationsteile laufen, aus dem simulierten
#' Vergleich (`results$<v>$deterministic`, identisch zu `vofi_run(vofi_build(...))`, dort mit den
#' Vergleichskennzahlen); sonst aus einem eigenen Lauf.
wss_det <- function(id, variant = "base", overrides = NULL, set = NULL) {
  if (is.null(overrides) && is.null(set) && wss_mc_enabled()) {
    cmp <- wss_cmp_mc(id)
    if (variant %in% names(cmp$results)) return(cmp$results[[variant]]$deterministic)
  }
  wss_memo(paste0("det|", wss_key(id, variant, overrides, set)),
           wss_quiet(vofi_run(wss_model(id, variant, overrides, set))))
}

#' Zeile eines Ledgers (Lauf `sim`) als Vektor, benannt nach den Periodenbezeichnungen
#' (`t0`, `2027`, ...)
wss_row <- function(res, key, sim = 1L) {
  led <- if (inherits(res, "vofi_ledger")) res else res$ledger
  v <- led$values[[key]]
  if (is.null(v)) stop("Ledger-Zeile fehlt: ", key)
  stats::setNames(v[sim, ], res$grid$label %||% c("t0", seq_len(led$T)))
}

#' Wert einer Ledger-Zeile in der Periode mit der Bezeichnung `period` (z. B. "2027", "t0")
wss_val <- function(res, key, period, sim = 1L) {
  r <- wss_row(res, key, sim)
  if (!(period %in% names(r))) stop("Periode fehlt: ", period)
  r[[period]]
}

#' Summe mehrerer Ledger-Zeilen in einer Periode
wss_sum <- function(res, keys, period) sum(vapply(keys, function(k) wss_val(res, k, period), 0))

#' Ledger-Schluessel nach Abschnitt und Kategorie (Auswahl ueber Tags, Spec 00 7.3)
wss_keys <- function(res, section = NULL, category = NULL, kind = NULL) {
  rows <- res$ledger$rows
  sel <- rep(TRUE, nrow(rows))
  if (!is.null(section)) sel <- sel & rows$section %in% section
  if (!is.null(category)) sel <- sel & rows$category %in% category
  if (!is.null(kind)) sel <- sel & rows$kind %in% kind
  rows$key[sel]
}

#' Fluesse aller Komponenten eines Modells (optional mit Ziehungen): Liste nach Komponenten-id
#' mit `rows`, `aux`, `meta` (interne Engine-Stufen 9.2 Nr. 2-4, WS-D)
wss_flows <- function(model, draws = NULL) {
  env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, draws, env)
  wss_quiet(eng_flows(model, ctx, env, NULL))
  ids <- names(model$nodes)
  stats::setNames(lapply(ids, function(id) ctx$component(id)), ids)
}

#' Hilfsgroessen (aux) einer Komponente im deterministischen Lauf (zwischengespeichert)
wss_aux <- function(id, variant = "base", component, overrides = NULL) {
  fl <- wss_memo(paste0("flows|", wss_key(id, variant, overrides)),
                 wss_flows(wss_model(id, variant, overrides)))
  cmp <- fl[[component]]
  if (is.null(cmp)) stop("Komponente fehlt: ", component)
  cmp$aux
}

#' Ziehungen der Bloecke `blocks` eines Modells (Simulation, Seed der Referenzszenarien)
wss_draws <- function(model, blocks = 1L) {
  eng_chunk_draws(model, blocks = as.integer(blocks), seed = 20261025L, mode = "mc")
}

#' Overrides fuer Pruefwerte "Preisbasis 2026" (Spec 01 Teil C 5.0 Nr. 8): Wachstum der
#' Marktpfade 0, VPI 0, CO2-Preis konstant 60 EUR/t (Stand 2027), Netzentgeltwachstum 0
wss_flat <- function(carriers, network = character(0)) {
  ep <- stats::setNames(lapply(carriers, function(c) list(growth = 0)), carriers)
  sh <- stats::setNames(lapply(network, function(c) 0), paste0("network_fee_growth_", network))
  out <- list(market = list(inflation = 0, co2_price = 60, energy_price = ep,
                            bio_fuel_premium_base = list(growth = 0)))
  if (length(sh) > 0L) out$shared <- sh
  out
}

#' Szenario aus einer veraenderten YAML-Fassung eines Beispiels (Zeilen ersetzen bzw. anhaengen)
#' @param id Szenario.
#' @param append Zeilen, die angehaengt werden (z. B. ein zusaetzlicher Block).
#' @param replace_block optional: Name eines obersten Blocks, dessen Zeilen durch `block_lines`
#'   ersetzt werden.
wss_scenario_text <- function(id, append = character(0), replace_block = NULL,
                              block_lines = character(0)) {
  nm <- if (id %in% names(wss_ids)) wss_ids[[id]] else id
  txt <- readLines(vofi_example(nm), encoding = "UTF-8", warn = FALSE)
  if (!is.null(replace_block)) {
    top <- grep("^[a-z_]+:", txt)
    start <- grep(paste0("^", replace_block, ":"), txt)
    stopifnot(length(start) == 1L)
    nxt <- top[top > start]
    end <- if (length(nxt) > 0L) nxt[1L] - 1L else length(txt)
    txt <- c(txt[seq_len(start - 1L)], block_lines, txt[-seq_len(end)])
  }
  f <- tempfile(fileext = ".yaml")
  writeLines(enc2utf8(c(txt, append)), f, useBytes = TRUE)
  on.exit(unlink(f), add = TRUE)
  wss_quiet(vofi_read_scenario(f))
}

#' Betrag mit absoluter Toleranz pruefen (Spec 01 Teil C 5.0 Nr. 8: +-0,01 EUR)
expect_wss_abs <- function(actual, expected, tol = 0.01, label = NULL) {
  ok <- length(actual) == 1L && is.finite(actual) && abs(actual - expected) <= tol
  testthat::expect(isTRUE(ok), sprintf("%s: %s statt %s (Toleranz %s)",
                                       label %||% "Pruefwert", format(actual, digits = 12),
                                       format(expected, digits = 12), format(tol)))
  invisible(actual)
}

#' Betrag mit relativer Toleranz pruefen (Annuitaeten +-0,1 %, Energiemengen 1e-6)
expect_wss_rel <- function(actual, expected, rel, label = NULL) {
  ok <- length(actual) == 1L && is.finite(actual) &&
    abs(actual - expected) <= rel * abs(expected)
  testthat::expect(isTRUE(ok), sprintf("%s: %s statt %s (relative Toleranz %s)",
                                       label %||% "Pruefwert", format(actual, digits = 12),
                                       format(expected, digits = 12), format(rel)))
  invisible(actual)
}

#' Mittelwert einer Eingangsgroesse innerhalb von 4 Standardfehlern (Spec 01 Teil C 5.0 Nr. 8)
expect_wss_mean <- function(x, expected, label = NULL, k = 4) {
  se <- stats::sd(x) / sqrt(length(x))
  dev <- abs(mean(x) - expected)
  ok <- is.finite(dev) && dev <= k * max(se, 1e-12 * max(1, abs(expected)))
  testthat::expect(isTRUE(ok), sprintf("%s: Mittel %s statt %s (|Abw.| %s > %s SE = %s)",
                                       label %||% "Mittel", format(mean(x), digits = 10),
                                       format(expected, digits = 10), format(dev, digits = 4),
                                       k, format(k * se, digits = 4)))
  invisible(mean(x))
}

#' Quantil innerhalb des Konfidenzintervalls der Ordnungsstatistiken (Spec 01 Teil C 6.3)
expect_wss_quantile <- function(x, p, expected, label = NULL) {
  n <- length(x)
  s <- sort(x)
  k_lo <- max(1L, stats::qbinom(0.025, n, p))
  k_hi <- min(n, stats::qbinom(0.975, n, p) + 1L)
  ok <- s[k_lo] <= expected && expected <= s[k_hi]
  testthat::expect(isTRUE(ok), sprintf("%s: q%02.0f-Soll %s ausserhalb [%s; %s]",
                                       label %||% "Quantil", 100 * p,
                                       format(expected, digits = 8), format(s[k_lo], digits = 8),
                                       format(s[k_hi], digits = 8)))
  invisible(NULL)
}
