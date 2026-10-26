# Zahlungskomponenten bauen und zum exogenen Ledger buendeln (WS-D, Spec 00 Abschnitte 7.1-7.3,
# 9.2 Stufe 3). Phase-0-Minimalfassung, Eigentuemer: WS-D. Umgesetzt: build() in
# Topo-Reihenfolge, Laufzeitpruefung des Zeilenvertrags (Dimension, deklarierte Zeilen,
# Abschnitt/Kategorie, Vorzeichen; vofi_error_contract), Ledger-Schluessel <id>__<zeile>,
# Default-Tags der Komponente, Labels mit vorangestelltem Komponentenlabel, Grob-Ordnung,
# Register. Offen fuer WS-D: extra_rows (Differential-Modus, 9.6 Nr. 6).

#' Private Engine-Umgebung eines Kontexts (6.1 Nr. 3)
#' @noRd
eng_engine_env <- function(model) {
  env <- new.env(parent = emptyenv())
  env$stage <- "flows"
  env$components <- list()
  env$current <- NULL
  env$deps <- NULL
  env$inst_cache <- NULL
  env$rebalance <- function(extra_out = NULL) {
    vofi_abort("engine.rebalance_stage", .class = "vofi_error_contract")
  }
  env$auto <- function(id) {
    a <- model$base$auto
    if (is.null(a) || !identical(id, model$auto_id)) {
      vofi_abort("engine.auto_unavailable", id = id, .class = "vofi_error_contract")
    }
    a
  }
  env
}

#' Zahlungskomponenten in Topo-Reihenfolge bauen (9.2 Stufe 3)
#' @param model `vofi_model`.
#' @param ctx Laufkontext.
#' @param engine_env private Engine-Umgebung (erhält `components`).
#' @return `list(ledger = <vofi_ledger>, registers = list(assets, measures))`.
#' @noRd
eng_flows <- function(model, ctx, engine_env) {
  n <- ctx$n
  big_t <- ctx$T
  meta <- list()
  values <- list()
  engine_env$components <- list()
  assets <- model$spec$registers$assets %||% list()
  measures <- model$spec$registers$measures %||% list()
  for (id in names(model$nodes)) {
    nd <- model$nodes[[id]]
    engine_env$current <- nd$path
    engine_env$deps <- nd$deps
    fl <- nd$def$build(nd$spec, ctx)
    eng_check_flows(fl, nd, n, big_t)
    engine_env$components[[id]] <- fl
    assets <- c(assets, fl$assets)
    measures <- c(measures, fl$measures)
    for (r in fl$rows) {
      key <- paste0(id, "__", r$key)
      meta[[key]] <- eng_flow_row_meta(key, r, nd)
      values[[key]] <- r$values
    }
  }
  engine_env$current <- NULL
  engine_env$deps <- NULL
  rows <- eng_flow_rows_df(meta)
  ord <- order(rows$order, method = "radix")
  rows <- rows[ord, , drop = FALSE]
  rownames(rows) <- NULL
  list(ledger = new_vofi_ledger(rows, values[rows$key], n = n, T = big_t),
       registers = list(assets = utl_register_list(assets, "vofi_asset", "asset_id"),
                        measures = utl_register_list(measures, "vofi_measure",
                                                     "measure_id")))
}

#' Laufzeitprüfung des Zeilenvertrags einer Komponente (7.1, 5.6 F1-F5)
#' @noRd
eng_check_flows <- function(fl, nd, n, big_t) {
  bad <- function(details) {
    vofi_abort("engine.flow_contract", id = nd$spec$id, type = nd$def$name, details = details,
               .class = "vofi_error_contract")
  }
  if (!inherits(fl, "vofi_flows")) bad(msg("core.testkit.not_flows", name = nd$def$name))
  for (r in fl$rows) {
    if (!identical(dim(r$values), c(as.integer(n), as.integer(big_t) + 1L))) {
      bad(msg("core.testkit.rows_failed", what = "F2", rows = r$key))
    }
    if (!reg_row_declared(r$key, nd$def$rows)) {
      bad(msg("core.testkit.rows_failed", what = "F3", rows = r$key))
    }
    probs <- validate_flow_row(r)
    if (length(probs) > 0L) bad(utl_collapse(probs, "; "))
    cat_row <- vocab_category(r$section, r$category)
    tol <- vofi_tol$zero_abs
    if ((cat_row$sign == "pos" && min(r$values) < -tol) ||
        (cat_row$sign == "neg" && max(r$values) > tol)) {
      bad(msg("core.testkit.rows_failed", what = "F5", rows = r$key))
    }
  }
  invisible(TRUE)
}

#' Label-Schlüssel einer lokalen Zeile (Eintrag oder Muster <präfix>_*)
#' @return `list(key, id, row)` (`id` = Platzhalterwert bei Mustern, `row` = Eintrag in
#'   `def$rows`).
#' @noRd
eng_row_label_key <- function(def, local) {
  prefix <- paste0(reg_label_prefix(def), ".rows.")
  if (local %in% def$rows) return(list(key = paste0(prefix, local), id = NULL, row = local))
  for (p in def$rows[endsWith(def$rows, "_*")]) {
    pre <- substr(p, 1L, nchar(p) - 1L)
    if (startsWith(local, pre)) {
      return(list(key = paste0(prefix, p), id = substr(local, nchar(pre) + 1L, nchar(local)),
                  row = p))
    }
  }
  list(key = paste0(prefix, local), id = NULL, row = local)
}

#' Ledger-Metadaten einer Komponentenzeile (7.3, 7.4) als Liste der Spaltenwerte
#' @noRd
eng_flow_row_meta <- function(key, r, nd) {
  comp <- nd$spec
  lk <- eng_row_label_key(nd$def, r$key)
  label_key <- r$label_key %||% lk$key
  list(
    key = key, section = r$section, category = r$category, tax_category = r$tax_category,
    cash = r$cash, kind = r$kind, unit = r$unit,
    asset_id = r$asset_id %||% comp$asset_id %||% NA_character_,
    measure_id = r$measure_id %||% comp$measure_id %||% NA_character_,
    vat_rate = r$vat_rate, vat_recoverable = r$vat_recoverable,
    is_tax = r$is_tax %||% NA_character_,
    program = r$program %||% comp$program %||% NA_character_, source_id = comp$id,
    source_type = nd$def$name, origin = comp$origin %||% "scenario", local_row = r$key,
    label_key = label_key,
    label = r$label %||% eng_type_row_label(nd$def, label_key, lk$row, lk$id,
                                            prefix = comp$label),
    order = eng_row_order(r$section, r$category, nd$position), extra = r$extra %||% list()
  )
}

#' Metadaten aller Komponentenzeilen in einem Aufruf von new_ledger_rows() (vektorisiert)
#' @noRd
eng_flow_rows_df <- function(meta) {
  if (length(meta) == 0L) {
    return(new_ledger_rows(character(0), character(0), character(0)))
  }
  col <- function(f, type) vapply(meta, function(m) m[[f]], type, USE.NAMES = FALSE)
  rows <- new_ledger_rows(
    col("key", ""), col("section", ""), col("category", ""),
    tax_category = col("tax_category", ""), cash = col("cash", TRUE), kind = col("kind", ""),
    unit = col("unit", ""), asset_id = col("asset_id", ""), measure_id = col("measure_id", ""),
    vat_rate = col("vat_rate", 0), vat_recoverable = col("vat_recoverable", TRUE),
    is_tax = col("is_tax", ""), program = col("program", ""), source_id = col("source_id", ""),
    existing_debt = FALSE, source_type = col("source_type", ""), origin = col("origin", ""),
    local_row = col("local_row", ""), label_key = col("label_key", ""),
    label = col("label", ""), order = col("order", 0),
    extra = lapply(meta, function(m) m$extra)
  )
  rownames(rows) <- NULL
  rows
}
