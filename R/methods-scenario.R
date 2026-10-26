# S3-Methoden der Klassen vofi_scenario, vofi_spec und vofi_model (WS-H, Spec 00 Abschnitte
# 4.8, 4.13, 13.6). Eigentuemer: WS-H. Inhalt: print() und summary() (Klasse
# summary_vofi_scenario) fuer Szenarien, print() und as.data.frame() (Parameterliste mit
# Herkunft) fuer aufgeloeste Varianten, print() fuer Modelle.

# ---------------------------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------------------------

#' Kompakte Zahl im deutschen Format (bis 6 Nachkommastellen, ohne Nullen am Ende)
#' @noRd
rep_num_text <- function(x) {
  x <- as.double(x)
  out <- formatC(x, format = "f", digits = 6, big.mark = ".", decimal.mark = ",")
  out <- sub("0+$", "", out)
  out <- sub(",$", "", out)
  out[is.na(x)] <- fmt_num(NA)
  out[x == 0 & !is.na(x)] <- "0"
  out
}

#' Wert eines Spezifikationsblatts als kurzer Text (Knoten der Wertgrammatik 4.5)
#' @noRd
rep_value_text <- function(v, max_items = 6L) {
  if (is.null(v)) return("")
  if (node_is(v)) {
    return(switch(v$kind,
      const = rep_num_text(v$value),
      series_t = rep_seq_text(v$values, max_items),
      series_year = paste0(lbl("report.scenario.kind_series_year"), " ",
                           rep_seq_text(v$values, max_items, names = v$years)),
      points = paste0(lbl("report.scenario.kind_points"), " ",
                      rep_seq_text(v$values, max_items, names = v$years)),
      schedule = paste0(lbl("report.scenario.kind_schedule"), " ",
                        rep_seq_text(v$amounts, max_items,
                                     names = format(v$dates, "%Y-%m-%d"))),
      ref = rep_ref_text(v),
      growth = lbl("report.scenario.kind_growth", start = rep_value_text(v$start),
                   growth = rep_value_text(v$growth)),
      expr = paste0("expr: ", v$text %||% ""),
      quantity = lbl("report.scenario.kind_quantity", value = rep_value_text(v$value),
                     per = v$per %||% ""),
      auto = v$mode %||% v$value %||% "auto",
      dist = lbl("report.scenario.kind_dist", type = v$type %||% v$dist %||% ""),
      v$kind
    ))
  }
  if (inherits(v, "Date")) return(utl_collapse(fmt_date(v)))
  if (is.logical(v) && length(v) == 1L && !is.na(v)) {
    return(if (v) lbl("report.common.yes") else lbl("report.common.no"))
  }
  if (is.numeric(v)) return(rep_seq_text(v, max_items))
  if (is.character(v) || is.factor(v)) {
    v <- as.character(v)
    if (length(v) > max_items) v <- c(v[seq_len(max_items)], "...")
    return(utl_collapse(v))
  }
  if (is.list(v) && length(v) == 0L) return("")
  if (is.list(v)) {
    return(utl_collapse(vapply(v, function(e) rep_value_text(e, max_items), ""), "; "))
  }
  utl_collapse(format(v))
}

#' Folge als Text `[a; b; ...]` (Elemente dürfen Knoten sein)
#' @noRd
rep_seq_text <- function(values, max_items = 6L, names = NULL) {
  items <- if (is.list(values)) vapply(values, rep_value_text, "") else rep_num_text(values)
  if (!is.null(names)) items <- paste0(names, ": ", items)
  if (length(items) == 1L && is.null(names)) return(items)
  if (length(items) > max_items) items <- c(items[seq_len(max_items)], "...")
  paste0("[", paste(items, collapse = "; "), "]")
}

#' Bezugsknoten als Text
#' @noRd
rep_ref_text <- function(v) {
  out <- paste0("ref: ", v$path %||% "")
  sc <- as.double(v$scale %||% 1)
  off <- as.double(v$offset %||% 0)
  if (!identical(sc, 1)) out <- paste0(out, " x ", rep_num_text(sc))
  if (!identical(off, 0)) out <- paste0(out, " + ", rep_num_text(off))
  out
}

#' Blattpfade einer Spezifikation (Knoten der Wertgrammatik sind Blätter)
#' @noRd
rep_spec_leaves <- function(x, path = "") {
  if (is.null(x)) return(list())
  if (node_is(x) || !is_map(x) || length(x) == 0L) {
    if (!nzchar(path) || (is_map(x) && length(x) == 0L)) return(list())
    return(stats::setNames(list(x), path))
  }
  out <- list()
  for (nm in names(x)) out <- c(out, rep_spec_leaves(x[[nm]], path_join(path, nm)))
  out
}

#' Anzahl der Elemente einer Sammlung
#' @noRd
rep_n <- function(x) if (is.list(x)) length(x) else 0L

#' Komponenten bzw. Bausteine einer Sammlung als Zeichenmatrix (id, Typ, Bezeichnung, Herkunft)
#' @noRd
rep_collection_matrix <- function(coll) {
  if (!is.list(coll) || length(coll) == 0L) return(NULL)
  ids <- names(coll)
  m <- cbind(ids,
             vapply(coll, function(e) as.character(e[["type"]] %||% ""), "", USE.NAMES = FALSE),
             vapply(coll, function(e) {
               l <- e[["label"]]
               if (utl_is_string(l)) l else ""
             }, "", USE.NAMES = FALSE),
             vapply(coll, function(e) as.character(e[["origin"]] %||% "scenario"), "",
                    USE.NAMES = FALSE))
  if (length(ids) == 1L) m <- matrix(m, nrow = 1L)
  colnames(m) <- c(lbl("report.scenario.col_id"), lbl("report.scenario.col_type"),
                   lbl("report.scenario.col_label"), lbl("report.scenario.col_origin"))
  m
}

#' Kopfzeilen eines Szenarios bzw. einer Spezifikation
#' @noRd
rep_scenario_lines <- function(x) {
  p <- x$project %||% list()
  title <- x$meta$title %||% ""
  id <- x$meta$scenario_id %||% ""
  horizon <- p$horizon_years
  if (node_is(horizon)) horizon <- horizon$value
  c(lbl("report.scenario.title", title = title, id = id),
    lbl("report.scenario.project",
        perspective = rep_enum_label("perspective", rep_plain(p$perspective)),
        type = rep_enum_label("project_type", rep_plain(p$project_type)),
        date = rep_value_text(p$valuation_date),
        horizon = if (is.null(horizon)) fmt_num(NA) else rep_num_text(horizon)))
}

#' Normalisierter Wert ohne Knotenhülle
#' @noRd
rep_plain <- function(v) {
  if (node_is(v) && identical(v$kind, "const")) return(v$value)
  v
}

#' Zählung der Domänenblöcke als Zeile
#' @noRd
rep_block_counts <- function(x) {
  lbl("report.scenario.counts", components = rep_n(x$components),
      financing = rep_n(x$financing), measures = rep_n(x$measures),
      unit_groups = rep_n(x$unit_groups), funding = rep_n(x$funding))
}

# ---------------------------------------------------------------------------------------------
# vofi_scenario
# ---------------------------------------------------------------------------------------------

#' Szenario ausgeben
#'
#' Gibt Titel, id, Perspektive, Projektart, Stichtag, Horizont, Quelle, die Zahl der
#' Komponenten, Bausteine, Maßnahmen, Wohnungsgruppen und Förderinstrumente sowie Varianten,
#' Szenario-Sets und den Umfang des Stochastik-Overlays aus (Spec 00, Abschnitte 4.13, 13.6).
#'
#' @param x Objekt der Klasse `vofi_scenario`.
#' @param ... nicht verwendet.
#' @return `invisible(x)`.
#' @family Einlesen
#' @examples
#' sc <- vofi_read_scenario(vofi_example("skeleton"))
#' print(sc)
#' @export
print.vofi_scenario <- function(x, ...) {
  cat(lbl("report.scenario.header"), "\n", sep = "")
  cat(paste0("  ", rep_scenario_lines(x), "\n"), sep = "")
  src <- attr(x, "source") %||% list()
  if (utl_is_string(src$path) && !is.na(src$path)) {
    cat("  ", lbl("report.scenario.source", path = basename(src$path),
                  format = src$format %||% ""), "\n", sep = "")
  }
  cat("  ", rep_block_counts(x), "\n", sep = "")
  vars <- names(x$variants %||% list())
  cat("  ", lbl("report.scenario.variants", variants = utl_collapse(c("base", vars))), "\n",
      sep = "")
  sets <- names(x$scenario_sets %||% list())
  if (length(sets) > 0L) {
    cat("  ", lbl("report.scenario.sets", sets = utl_collapse(sets)), "\n", sep = "")
  }
  st <- x$stochastic %||% list()
  n_st <- rep_n(st$overlay %||% st$distributions %||% list()) + rep_n(st$processes)
  if (n_st > 0L) cat("  ", lbl("report.scenario.stochastic", n = n_st), "\n", sep = "")
  invisible(x)
}

#' Zusammenfassung eines Szenarios
#'
#' Liefert ein Objekt der Klasse `summary_vofi_scenario` mit Kopfdaten, der Zahl der Blätter je
#' Block, den Komponenten und Finanzierungsbausteinen (id, Typ, Bezeichnung), den Varianten
#' ([vofi_variants()]) und der Herkunft der eingelesenen Blätter (Spec 00, Abschnitt 4.8).
#'
#' @param object Objekt der Klasse `vofi_scenario`.
#' @param ... nicht verwendet.
#' @return Objekt der Klasse `summary_vofi_scenario`.
#' @family Einlesen
#' @examples
#' summary(vofi_read_scenario(vofi_example("skeleton")))
#' @export
summary.vofi_scenario <- function(object, ...) {
  x <- object
  blocks <- setdiff(names(unclass(x)), "schema_version")
  leaves <- vapply(blocks, function(b) length(rep_spec_leaves(x[[b]], b)), integer(1))
  counts <- data.frame(block = blocks, leaves = as.integer(leaves), stringsAsFactors = FALSE)
  counts <- counts[counts$leaves > 0L, , drop = FALSE]
  rownames(counts) <- NULL
  vars <- tryCatch(vofi_variants(x), vofi_error = function(e) NULL)
  pv <- attr(x, "provenance")
  structure(list(
    lines = rep_scenario_lines(x), counts = counts, block_counts = rep_block_counts(x),
    components = rep_collection_matrix(x$components),
    financing = rep_collection_matrix(x$financing), variants = vars,
    provenance = if (is.data.frame(pv)) table(pv$source_type) else NULL,
    source = attr(x, "source")
  ), class = "summary_vofi_scenario")
}

#' Zusammenfassung eines Szenarios ausgeben
#'
#' @param x Objekt der Klasse `summary_vofi_scenario`.
#' @param ... nicht verwendet.
#' @return `invisible(x)`.
#' @family Einlesen
#' @export
print.summary_vofi_scenario <- function(x, ...) {
  cat(lbl("report.scenario.header"), "\n", sep = "")
  cat(paste0("  ", x$lines, "\n"), sep = "")
  cat("  ", x$block_counts, "\n", sep = "")
  if (nrow(x$counts) > 0L) {
    cat("\n", lbl("report.scenario.leaves_header"), "\n", sep = "")
    m <- cbind(x$counts$block, as.character(x$counts$leaves))
    colnames(m) <- c(lbl("report.scenario.col_block"), lbl("report.scenario.col_leaves"))
    rep_cat_matrix(m, left = 1L)
  }
  for (nm in c("components", "financing")) {
    if (!is.null(x[[nm]])) {
      cat("\n", lbl(paste0("report.scenario.", nm, "_header")), "\n", sep = "")
      rep_cat_matrix(x[[nm]], left = 1L)
    }
  }
  v <- x$variants
  if (is.data.frame(v) && nrow(v) > 0L) {
    cat("\n", lbl("report.scenario.variants_header"), "\n", sep = "")
    m <- cbind(v$variant, ifelse(is.na(v$label), "", v$label),
               ifelse(is.na(v$extends), "", v$extends))
    if (nrow(v) == 1L) m <- matrix(m, nrow = 1L)
    colnames(m) <- c(lbl("report.scenario.col_variant"), lbl("report.scenario.col_label"),
                     lbl("report.scenario.col_extends"))
    rep_cat_matrix(m, left = 1L)
  }
  if (!is.null(x$provenance) && length(x$provenance) > 0L) {
    counts <- paste0(names(x$provenance), ": ", as.integer(x$provenance))
    cat("\n", lbl("report.scenario.provenance", counts = utl_collapse(counts)), "\n", sep = "")
  }
  invisible(x)
}

# ---------------------------------------------------------------------------------------------
# vofi_spec
# ---------------------------------------------------------------------------------------------

#' Aufgelöste Variante ausgeben
#'
#' Gibt Kopfdaten, Variante und Szenario-Set, Komponenten und Finanzierungsbausteine (mit
#' Herkunft `scenario` bzw. `expander:<name>`), Register, Bibliothekseinträge und die Herkunft
#' der Parameter je Quelle aus (Spec 00, Abschnitte 4.8, 4.13).
#'
#' @param x Objekt der Klasse `vofi_spec`.
#' @param ... nicht verwendet.
#' @return `invisible(x)`.
#' @family Einlesen
#' @examples
#' sp <- vofi_resolve(vofi_read_scenario(vofi_example("skeleton")))
#' print(sp)
#' @export
print.vofi_spec <- function(x, ...) {
  cat(lbl("report.spec.header", variant = x$variant %||% "base",
          set = x$scenario_set %||% "-"), "\n", sep = "")
  cat(paste0("  ", rep_scenario_lines(x), "\n"), sep = "")
  cat("  ", rep_block_counts(x), "\n", sep = "")
  reg <- x$registers %||% list()
  cat("  ", lbl("report.spec.registers", assets = rep_n(reg$assets),
                measures = rep_n(reg$measures),
                library = if (is.data.frame(x$library)) nrow(x$library) else 0L), "\n",
      sep = "")
  for (nm in c("components", "financing")) {
    m <- rep_collection_matrix(x[[nm]])
    if (!is.null(m)) {
      cat("\n", lbl(paste0("report.scenario.", nm, "_header")), "\n", sep = "")
      rep_cat_matrix(m, left = 1L)
    }
  }
  pv <- attr(x, "provenance")
  if (is.data.frame(pv) && nrow(pv) > 0L) {
    tb <- table(pv$source_type)
    counts <- paste0(names(tb), ": ", as.integer(tb))
    cat("\n", lbl("report.scenario.provenance", counts = utl_collapse(counts)), "\n", sep = "")
  }
  invisible(x)
}

#' Aufgelöste Variante als Parameterliste mit Herkunft
#'
#' Eine Zeile je Blatt der Spezifikation (Knoten der Wertgrammatik als ein Blatt) mit Pfad,
#' Block, Knotenart (`kind`: Knotenart nach 4.5 bzw. `value` für normalisierte Werte), Wert als
#' Text (`value`), Zahlenwert bei Konstanten (`value_num`) und den Spalten der Herkunft nach
#' Spec 00, Abschnitt 4.8 (`layer`, `source_type`, `file`, `entry`, `location`, `variant`,
#' `valid_from`, `valid_to`, `as_of`, `accessed`, `quality`).
#'
#' @param x Objekt der Klasse `vofi_spec`.
#' @param row.names,optional nicht verwendet (Kompatibilität mit [as.data.frame()]).
#' @param blocks `NULL` (alle Blöcke) oder Auswahl der obersten Blöcke.
#' @param ... nicht verwendet.
#' @return Data Frame.
#' @family Einlesen
#' @examples
#' sp <- vofi_resolve(vofi_read_scenario(vofi_example("skeleton")))
#' head(as.data.frame(sp))
#' @export
as.data.frame.vofi_spec <- function(x, row.names = NULL, optional = FALSE, # nolint
                                    blocks = NULL, ...) {
  skip <- c("registers", "legal", "library", "variant", "scenario_set", "schema_version",
            "shared")
  all_blocks <- setdiff(names(unclass(x)), skip)
  if (!is.null(blocks)) all_blocks <- intersect(all_blocks, blocks)
  leaves <- list()
  for (b in all_blocks) leaves <- c(leaves, rep_spec_leaves(x[[b]], b))
  paths <- names(leaves) %||% character(0)
  out <- data.frame(
    path = paths,
    block = vapply(strsplit(paths, ".", fixed = TRUE), function(s) s[1L], ""),
    kind = vapply(leaves, function(v) if (node_is(v)) v$kind else "value", "",
                  USE.NAMES = FALSE),
    value = vapply(leaves, rep_value_text, "", USE.NAMES = FALSE),
    value_num = vapply(leaves, function(v) {
      if (node_is(v) && identical(v$kind, "const")) return(as.double(v$value))
      if (is.numeric(v) && length(v) == 1L) return(as.double(v))
      NA_real_
    }, double(1), USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )
  pv <- attr(x, "provenance")
  pcols <- c("layer", "source_type", "file", "entry", "location", "variant", "valid_from",
             "valid_to", "as_of", "accessed", "quality")
  if (is.data.frame(pv) && nrow(pv) > 0L) {
    i <- match(out$path, pv$path)
    for (cc in pcols) {
      out[[cc]] <- if (cc %in% names(pv)) pv[[cc]][i] else rep(NA, nrow(out))
    }
  } else {
    for (cc in pcols) out[[cc]] <- rep(NA, nrow(out))
  }
  rownames(out) <- NULL
  out
}

# ---------------------------------------------------------------------------------------------
# vofi_model
# ---------------------------------------------------------------------------------------------

#' Rechenfertiges Modell ausgeben
#'
#' Gibt Szenario, Variante, Zeitraster, Zahlungskomponenten (nach Typ), Kreditinstrumente,
#' Ausgleichsketten, Steuermodul, Zahl der Kennzahlen, Stochastik und Entscheidungsknoten aus
#' (Spec 00, Abschnitt 4.13).
#'
#' @param x Objekt der Klasse `vofi_model`.
#' @param ... nicht verwendet.
#' @return `invisible(x)`.
#' @family Rechnen
#' @examples
#' print(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' @export
print.vofi_model <- function(x, ...) {
  sp <- x$spec
  g <- x$grid
  cat(lbl("report.model.header", title = sp$meta$title %||% "",
          id = sp$meta$scenario_id %||% "", variant = sp$variant %||% "base"), "\n", sep = "")
  cat("  ", lbl("report.model.grid", T = g$T, start = g$valuation_date, end = g$end_date,
                completion = g$completion_date), "\n", sep = "")
  types <- vapply(x$nodes %||% list(), function(nd) {
    as.character(nd$spec$type %||% nd$def$name %||% "")
  }, "")
  if (length(types) > 0L) {
    tb <- table(types)
    cat("  ", lbl("report.model.nodes", n = length(types),
                  types = utl_collapse(paste0(names(tb), " (", as.integer(tb), ")"))), "\n",
        sep = "")
  }
  inst <- x$instruments %||% list()
  if (length(inst) > 0L) {
    types <- vapply(inst, function(k) {
      as.character(k$def$name %||% k$spec$type %||% "")
    }, "")
    ids <- utl_collapse(paste0(names(inst), " (", types, ")"))
    cat("  ", lbl("report.model.instruments", ids = ids), "\n", sep = "")
  }
  chain <- function(ch) {
    nm <- vapply(ch %||% list(), function(a) as.character(a$name %||% a$def$name %||% ""), "")
    if (length(nm) == 0L) "-" else utl_collapse(nm, " > ")
  }
  cat("  ", lbl("report.model.chains", surplus = chain(x$surplus_chain),
                deficit = chain(x$deficit_chain)), "\n", sep = "")
  tax <- if (is.list(x$tax)) x$tax$name %||% "none" else "none"
  cat("  ", lbl("report.model.tax", tax = tax, kpis = length(x$kpis %||% list())), "\n",
      sep = "")
  smp <- x$sampler
  if (is.list(smp)) {
    n_t <- if (is.data.frame(smp$targets)) nrow(smp$targets) else rep_n(smp$targets)
    cat("  ", lbl("report.model.sampler", n = as.integer(n_t)), "\n", sep = "")
  } else {
    cat("  ", lbl("report.model.no_sampler"), "\n", sep = "")
  }
  if (!is.null(x$decision)) {
    cat("  ", lbl("report.model.decision", funding = x$decision$funding_id %||% "",
                  p = as.double(x$decision$p %||% NA_real_),
                  fallback = x$decision$fallback_variant %||% ""), "\n", sep = "")
  }
  cat("  ", lbl("report.model.hash", hash = x$hash %||% ""), "\n", sep = "")
  invisible(x)
}
