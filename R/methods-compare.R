# S3-Methoden der Klasse vofi_comparison (WS-H, Spec 00 Abschnitte 9.6, 12.6, 12.9, 13.3,
# 13.6). Eigentuemer: WS-H. Inhalt: print() (Kennzahlen je Variante, Vergleich gegen die
# Referenz mit Wahrscheinlichkeit "besser als Referenz", Rangfolge, Ampel, Vergleichbarkeit),
# summary() mit Klasse summary_vofi_comparison, format(), as.data.frame(), plot().

#' Kennzahlwert einer Variante aus `kpi_table` (deterministisch `value`, MC `mean`)
#' @noRd
rep_cmp_value <- function(x, variant, kpi) {
  kt <- x$kpi_table
  i <- which(kt$variant == variant & kt$kpi == kpi)
  if (length(i) == 0L) return(NA_real_)
  v <- if ("value" %in% names(kt)) as.double(kt$value[i[1L]]) else NA_real_
  if (is.na(v) && "mean" %in% names(kt)) v <- as.double(kt$mean[i[1L]])
  v
}

#' Kennzahlen eines Vergleichs (Reihenfolge: Primärkennzahl, dann Tabellenreihenfolge)
#' @noRd
rep_cmp_kpis <- function(x, head = TRUE) {
  kt <- x$kpi_table
  all <- unique(kt$kpi)
  base_res <- rep_det_result(x$results[[x$baseline]] %||% x$results[[1L]])
  primary <- base_res$meta$primary_kpi %||% "delta_terminal_value"
  if (!head) return(unique(c(intersect(c(primary, paste0(primary, "_ex_rv")), all), all)))
  sel <- c(primary, paste0(primary, "_ex_rv"), "delta_terminal_value",
           "delta_terminal_value_ex_rv", "terminal_value", "terminal_value_ex_rv", "roe_mirr",
           "payback_time", "own_contribution", "monthly_burden_y1", "monthly_net_cashflow_y1",
           "warm_rent_change_prepost_y1", "warm_rent_y1", "co2_emissions", "dscr_min",
           "min_net_liquidity", "sum_equity_calls")
  sel <- unique(sel[sel %in% all])
  if (length(sel) == 0L) sel <- utils::head(all, 12L)
  sel
}

#' Vermerk zur Endwertdifferenz eines Vergleichs (Bestandsprojekte, 12.3a)
#'
#' Bei Bestandsprojekten trägt die Endwertdifferenz gegenüber der eigenen
#' Unterlassungsalternative den Vermerk aus `kpi_primary()` („enthält Bestandszahlungen“ bzw.
#' „gegenüber Verkauf zum Stichtag“).
#' @param x `vofi_comparison`.
#' @param kpis Kennzahlen.
#' @return Liste `marked` (logisch je Kennzahl) und `note` (Label-Schlüssel bzw. `NA`).
#' @noRd
rep_cmp_kpi_note <- function(x, kpis) {
  base_res <- rep_det_result(x$results[[x$baseline]] %||% x$results[[1L]])
  note <- kpi_primary(base_res$spec)$note
  marked <- !is.na(note) & kpis %in% c("delta_terminal_value", "delta_terminal_value_ex_rv")
  list(marked = marked, note = note)
}

#' Bezeichnungen der Kennzahlen eines Vergleichs mit Vermerk
#'
#' `short = TRUE` (Ausgabe in der Konsole): Kennzeichen „*“ an der Bezeichnung, der Vermerk
#' steht als Fußnote unter der Tabelle (`rep_cmp_kpi_footnote()`); sonst der Vermerk in
#' Klammern.
#' @noRd
rep_cmp_kpi_labels <- function(x, kpis, short = FALSE) {
  nt <- rep_cmp_kpi_note(x, kpis)
  labels <- vapply(kpis, kpi_label, "", USE.NAMES = FALSE)
  if (!any(nt$marked)) return(labels)
  note <- lbl(nt$note)
  labels[nt$marked] <- vapply(labels[nt$marked], function(l) {
    if (short) lbl("report.compare.note_mark", label = l) else
      lbl("report.common.with_note", label = l, note = note)
  }, "", USE.NAMES = FALSE)
  labels
}

#' Fußnote zu den gekennzeichneten Kennzahlen eines Vergleichs
#' @return Zeichenkette bzw. `character(0)`.
#' @noRd
rep_cmp_kpi_footnote <- function(x, kpis) {
  nt <- rep_cmp_kpi_note(x, kpis)
  if (!any(nt$marked)) return(character(0))
  lbl("report.compare.note_footnote", note = lbl(nt$note))
}

#' Kennzahlen je Variante als Zeichenmatrix (Zeilen = Kennzahlen, Spalten = Varianten)
#' @param short Vermerk als Kennzeichen „*“ (mit Fußnote) statt in Klammern.
#' @noRd
rep_cmp_kpi_matrix <- function(x, kpis, short = TRUE) {
  vars <- rep_comparison_variants(x)
  if (length(kpis) == 0L) return(NULL)
  cells <- vapply(vars, function(v) {
    vapply(kpis, function(k) {
      u <- kpi_unit(k)
      rep_fmt_value(rep_cmp_value(x, v, k), if (is.na(u)) "EUR" else u, 0)
    }, "")
  }, character(length(kpis)))
  if (length(kpis) == 1L) cells <- matrix(cells, nrow = 1L)
  m <- cbind(rep_cmp_kpi_labels(x, kpis, short = short), cells)
  colnames(m) <- c(lbl("report.mc.col_kpi"), vars)
  rownames(m) <- NULL
  m
}

#' Vergleich gegen die Referenz als Zeichenmatrix (diff_stats, 13.3)
#' @noRd
rep_cmp_diff_matrix <- function(x) {
  ds <- x$diff_stats
  if (!is.data.frame(ds) || nrow(ds) == 0L) return(NULL)
  units <- vapply(ds$kpi, function(k) {
    u <- kpi_unit(k)
    if (is.na(u)) "EUR" else u
  }, "", USE.NAMES = FALSE)
  fv <- function(col) {
    v <- ds[[col]] %||% rep(NA_real_, nrow(ds))
    vapply(seq_along(v), function(i) rep_fmt_value(v[i], units[i], 0), "")
  }
  m <- cbind(ds$variant, vapply(ds$kpi, kpi_label, "", USE.NAMES = FALSE), fv("mean"),
             fv("q05"), fv("q50"), fv("q95"), fmt_pct(ds$prob_better, 1))
  if (nrow(ds) == 1L) m <- matrix(m, nrow = 1L)
  colnames(m) <- c(lbl("report.compare.col_variant"), lbl("report.mc.col_kpi"),
                   lbl("report.mc.col_mean"), lbl("report.mc.col_q05"),
                   lbl("report.mc.col_median"), lbl("report.mc.col_q95"),
                   lbl("report.compare.col_prob_better"))
  m
}

#' Kopfzeilen eines Vergleichs
#' @noRd
rep_cmp_header <- function(x) {
  base_res <- rep_det_result(x$results[[x$baseline]] %||% x$results[[1L]])
  title <- base_res$spec$meta$title %||% base_res$meta$scenario_id %||% ""
  m <- x$meta %||% list()
  mode <- m$mode %||% "deterministic"
  mode_txt <- if (identical(mode, "mc")) {
    lbl("report.compare.mode_mc", n = as.integer(m$n_sim %||% NA_integer_))
  } else {
    lbl("report.compare.mode_det")
  }
  c(lbl("report.compare.header", title = title),
    lbl("report.compare.subheader", baseline = x$baseline %||% "",
        variants = utl_collapse(x$variants %||% character(0)), mode = mode_txt))
}

#' Ampel und Vergleichbarkeit eines Vergleichs als Zeilen
#' @noRd
rep_cmp_status_lines <- function(x) {
  out <- character(0)
  tl <- x$traffic_light
  if (is.data.frame(tl) && nrow(tl) > 0L) {
    for (i in seq_len(nrow(tl))) {
      line <- lbl("report.compare.traffic_line", variant = tl$variant[i],
                  level = lbl(paste0("report.traffic.level_", tl$level[i]),
                              .default = tl$level[i]),
                  basis = lbl(paste0("report.traffic.basis_", tl$basis[i]),
                              .default = tl$basis[i]))
      if (isTRUE(tl$rv_dependent[i])) line <- paste(line, lbl("report.traffic.rv_dependent"))
      ko <- tl$ko_codes[i] %||% ""
      if (!is.na(ko) && nzchar(ko)) {
        codes <- strsplit(ko, "[,; ]+")[[1L]]
        labs <- vapply(codes[nzchar(codes)], rep_restriction_label, "")
        line <- paste(line, lbl("report.traffic.ko", codes = utl_collapse(labs)))
      }
      out <- c(out, line)
    }
  }
  out
}

#' Zeilen zur Vergleichbarkeit (9.6; ungleiche Nachschüsse sind kein Befund)
#' @noRd
rep_cmp_comparability <- function(x) {
  v <- x$comparability
  out <- character(0)
  if (!is.data.frame(v) || nrow(v) == 0L) {
    out <- lbl("report.compare.comparable")
  } else {
    out <- lbl("report.compare.findings", errors = sum(v$severity == "error"),
               warnings = sum(v$severity == "warning"), infos = sum(v$severity == "info"))
    out <- c(out, paste0("  ", v$message[v$severity %in% c("error", "warning")]))
  }
  calls <- vapply(rep_comparison_variants(x), function(vn) {
    rep_cmp_value(x, vn, "sum_equity_calls")
  }, double(1))
  if (any(!is.na(calls)) && length(unique(round(calls[!is.na(calls)], 2))) > 1L) {
    out <- c(out, lbl("report.compare.unequal_calls",
                      values = utl_collapse(paste0(names(calls), ": ",
                                                   rep_fmt_value(calls, "EUR", 0)))))
  }
  out
}

#' Variantenvergleich ausgeben
#'
#' Gibt Kopfdaten (Referenz, Varianten, Modus), die wichtigsten Kennzahlen je Variante
#' (Mittelwert bei Simulationen), den Vergleich gegen die Referenz nach der Vergleichsregel mit
#' der Wahrscheinlichkeit „besser als Referenz“, die Rangfolge, die Ampel je Variante und den
#' Stand der Vergleichbarkeit aus (Spec 00, Abschnitte 9.6, 12.6, 12.9, 13.3). Bei
#' Bestandsprojekten ist die Endwertdifferenz je Variante mit „*“ gekennzeichnet und trägt als
#' Fußnote den Vermerk „enthält Bestandszahlungen“ (Spec 00, Abschnitt 12.3a).
#'
#' @param x Objekt der Klasse `vofi_comparison`.
#' @param ... nicht verwendet.
#' @return `invisible(x)`.
#' @family Berichten
#' @export
print.vofi_comparison <- function(x, ...) {
  cat(paste0(rep_cmp_header(x), "\n"), sep = "")
  kpis <- rep_cmp_kpis(x, head = TRUE)
  m <- rep_cmp_kpi_matrix(x, kpis)
  if (!is.null(m)) {
    cat("\n", lbl("report.compare.kpi_header"), "\n", sep = "")
    rep_cat_matrix(m, left = 1L)
    fn <- rep_cmp_kpi_footnote(x, kpis)
    if (length(fn) > 0L) cat(fn, "\n", sep = "")
  }
  d <- rep_cmp_diff_matrix(x)
  if (!is.null(d)) {
    cat("\n", lbl("report.compare.diff_header"), "\n", sep = "")
    rep_cat_matrix(d, left = 2L)
  }
  rk <- x$ranking
  if (is.data.frame(rk) && nrow(rk) > 0L) {
    rk <- rk[order(rk$rank, method = "radix"), , drop = FALSE]
    crit <- rk$criterion[1L] %||% ""
    cat("\n", lbl("report.compare.ranking",
                  ranking = utl_collapse(paste0(rk$rank, ". ", rk$variant)),
                  criterion = kpi_label(crit)), "\n", sep = "")
  }
  st <- rep_cmp_status_lines(x)
  if (length(st) > 0L) {
    cat("\n", lbl("report.traffic.header"), "\n", sep = "")
    cat(paste0("  ", st, "\n"), sep = "")
  }
  cat("\n", paste0(rep_cmp_comparability(x), "\n"), sep = "")
  invisible(x)
}

#' Zusammenfassung eines Variantenvergleichs
#'
#' Liefert ein Objekt der Klasse `summary_vofi_comparison` mit allen Kennzahlen je Variante,
#' dem Vergleich gegen die Referenz, der Rangfolge, der Ampel mit Restriktionen, der bedingten
#' Statistik bei Entscheidungsknoten und den Befunden zur Vergleichbarkeit.
#'
#' @param object Objekt der Klasse `vofi_comparison`.
#' @param ... nicht verwendet.
#' @return Objekt der Klasse `summary_vofi_comparison`.
#' @family Berichten
#' @export
summary.vofi_comparison <- function(object, ...) {
  x <- object
  kpis <- rep_cmp_kpis(x, head = FALSE)
  structure(list(
    header = rep_cmp_header(x), kpis = rep_cmp_kpi_matrix(x, kpis),
    kpi_footnote = rep_cmp_kpi_footnote(x, kpis),
    differences = rep_cmp_diff_matrix(x), ranking = x$ranking,
    traffic = rep_cmp_status_lines(x), restrictions = x$restrictions,
    conditional = x$conditional, comparability = rep_cmp_comparability(x)
  ), class = "summary_vofi_comparison")
}

#' Zusammenfassung eines Variantenvergleichs ausgeben
#'
#' @param x Objekt der Klasse `summary_vofi_comparison`.
#' @param ... nicht verwendet.
#' @return `invisible(x)`.
#' @family Berichten
#' @export
print.summary_vofi_comparison <- function(x, ...) {
  cat(paste0(x$header, "\n"), sep = "")
  if (!is.null(x$kpis)) {
    cat("\n", lbl("report.compare.kpi_header_all"), "\n", sep = "")
    rep_cat_matrix(x$kpis, left = 1L)
    if (length(x$kpi_footnote) > 0L) cat(x$kpi_footnote, "\n", sep = "")
  }
  if (!is.null(x$differences)) {
    cat("\n", lbl("report.compare.diff_header"), "\n", sep = "")
    rep_cat_matrix(x$differences, left = 2L)
  }
  if (length(x$traffic) > 0L) {
    cat("\n", lbl("report.traffic.header"), "\n", sep = "")
    cat(paste0("  ", x$traffic, "\n"), sep = "")
  }
  r <- x$restrictions
  if (is.data.frame(r) && nrow(r) > 0L) {
    cat("\n", lbl("report.compare.restrictions_header"), "\n", sep = "")
    m <- cbind(r$variant, vapply(r$code, rep_restriction_label, "", USE.NAMES = FALSE),
               ifelse(r$violated_base, lbl("report.common.yes"), lbl("report.common.no")),
               fmt_pct(r$prob, 1), ifelse(is.na(r$year), fmt_num(NA), sprintf("%d", r$year)),
               fmt_num(r$value, 2), fmt_num(r$threshold, 2),
               ifelse(r$ko, lbl("report.common.yes"), lbl("report.common.no")))
    if (nrow(r) == 1L) m <- matrix(m, nrow = 1L)
    colnames(m) <- c(lbl("report.compare.col_variant"), lbl("report.compare.col_restriction"),
                     lbl("report.compare.col_violated"), lbl("report.compare.col_prob"),
                     lbl("report.compare.col_year"), lbl("report.compare.col_value"),
                     lbl("report.compare.col_threshold"), lbl("report.compare.col_ko"))
    rep_cat_matrix(m, left = 2L)
  }
  cd <- x$conditional
  if (is.data.frame(cd) && nrow(cd) > 0L) {
    cat("\n", lbl("report.compare.conditional_header"), "\n", sep = "")
    klab <- vapply(cd$kpi, kpi_label, "", USE.NAMES = FALSE)
    m <- cbind(cd$variant, as.character(cd$branch), klab, fmt_num(cd$mean, 0),
               fmt_num(cd$q05, 0), fmt_num(cd$q50, 0), fmt_num(cd$q95, 0),
               fmt_pct(cd$prob_better, 1))
    if (nrow(cd) == 1L) m <- matrix(m, nrow = 1L)
    colnames(m) <- c(lbl("report.compare.col_variant"), lbl("report.compare.col_branch"),
                     lbl("report.mc.col_kpi"), lbl("report.mc.col_mean"),
                     lbl("report.mc.col_q05"), lbl("report.mc.col_median"),
                     lbl("report.mc.col_q95"), lbl("report.compare.col_prob_better"))
    rep_cat_matrix(m, left = 3L)
  }
  cat("\n", paste0(x$comparability, "\n"), sep = "")
  invisible(x)
}

#' Variantenvergleich formatieren
#'
#' Liefert die Kennzahlen je Variante als Zeichenmatrix im deutschen Zahlenformat; bei
#' Bestandsprojekten trägt die Endwertdifferenz den Vermerk „enthält Bestandszahlungen“ (Spec 00,
#' Abschnitt 12.3a).
#'
#' @param x Objekt der Klasse `vofi_comparison`.
#' @param kpis `NULL` (alle Kennzahlen der Vergleichstabelle) oder Auswahl.
#' @param ... nicht verwendet.
#' @return Zeichenmatrix.
#' @family Berichten
#' @export
format.vofi_comparison <- function(x, kpis = NULL, ...) {
  m <- rep_cmp_kpi_matrix(x, kpis %||% rep_cmp_kpis(x, head = FALSE), short = FALSE)
  if (is.null(m)) m <- matrix(character(0), 0L, 0L)
  m
}

#' Variantenvergleich als Data Frame
#'
#' @param x Objekt der Klasse `vofi_comparison`.
#' @param row.names,optional nicht verwendet (Kompatibilität mit [as.data.frame()]).
#' @param what `"kpis"` (Kennzahlen je Variante, `kpi_table`), `"differences"` (Vergleich
#'   gegen die Referenz, `diff_stats`), `"runs"` (Vergleichskennzahlen je Lauf aus
#'   `differences` im Long-Format), `"ranking"`, `"traffic_light"`, `"restrictions"` oder
#'   `"conditional"`.
#' @param ... nicht verwendet.
#' @return Data Frame.
#' @family Berichten
#' @export
as.data.frame.vofi_comparison <- function(x, row.names = NULL, optional = FALSE, # nolint
                                          what = c("kpis", "differences", "runs", "ranking",
                                                   "traffic_light", "restrictions",
                                                   "conditional"), ...) {
  what <- utl_match_arg(what, c("kpis", "differences", "runs", "ranking", "traffic_light",
                                "restrictions", "conditional"), "what")
  out <- switch(what,
    kpis = x$kpi_table,
    differences = x$diff_stats,
    runs = {
      parts <- lapply(names(x$differences %||% list()), function(k) {
        m <- x$differences[[k]]
        vars <- colnames(m) %||% x$variants
        data.frame(kpi = k, variant = rep(vars, each = nrow(m)),
                   sim = rep(seq_len(nrow(m)), times = ncol(m)), value = as.vector(m),
                   stringsAsFactors = FALSE)
      })
      if (length(parts) == 0L) NULL else do.call(rbind, parts)
    },
    ranking = x$ranking, traffic_light = x$traffic_light, restrictions = x$restrictions,
    conditional = x$conditional
  )
  if (is.null(out)) out <- data.frame()
  rownames(out) <- NULL
  out
}

#' Grafik eines Variantenvergleichs
#'
#' Ruft [vofi_plot()] auf (Typen `"endwert"`, `"differenz"`, `"cdf"`, `"bestand"`,
#' `"belastung"`).
#'
#' @param x Objekt der Klasse `vofi_comparison`.
#' @param type Grafiktyp bzw. `NULL` (Endwerte je Variante).
#' @param ... weitere Angaben an [vofi_plot()].
#' @return ggplot-Objekt.
#' @family Berichten
#' @export
plot.vofi_comparison <- function(x, type = NULL, ...) {
  vofi_plot(x, type = type, ...)
}
