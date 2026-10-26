# S3-Methoden der Klasse vofi_result (WS-H, Spec 00 Abschnitt 13.6).
# Phase-0-Minimalfassung, Eigentuemer: WS-H: print() mit Kopf, Kopf-Kennzahlen (Primaerkennzahl
# zuerst, mit und ohne Restwert) und gekuerzter VoFi-Tabelle (Summen je Abschnitt,
# Finanzierungssaldo, Bestandssaldo). Offen fuer WS-H: summary(), format(), plot(),
# as.data.frame(), Tabellenaufbau ueber vofi_table() (R/report-table.R), Snapshots.

#' VoFi-Ergebnis ausgeben
#'
#' Gibt Kopfdaten, die wichtigsten Kennzahlen (Primärkennzahl zuerst) und eine gekürzte
#' VoFi-Tabelle (Summen je Abschnitt, Finanzierungssaldo, Bestandssaldo) im deutschen
#' Zahlenformat aus.
#'
#' Phase-0-Minimalfassung (Eigentümer: WS-H).
#'
#' @param x Objekt der Klasse `vofi_result`.
#' @param sim Lauf, dessen Werte gezeigt werden (Default 1).
#' @param max_periods höchste Zahl angezeigter Perioden (gekürzt in der Mitte).
#' @param ... nicht verwendet.
#' @return `invisible(x)`.
#' @family Berichten
#' @examples
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' print(res)
#' @export
print.vofi_result <- function(x, sim = 1L, max_periods = 8L, ...) {
  m <- x$meta
  title <- x$spec$meta$title %||% m$scenario_id %||% ""
  cat(lbl("report.print.header", title = title, id = m$scenario_id %||% "",
          variant = m$variant %||% "base"), "\n", sep = "")
  cat(lbl("report.print.subheader", mode = lbl(paste0("report.print.mode_", m$mode)),
          start = x$grid$valuation_date, end = x$grid$end_date, T = x$grid$T), "\n\n",
      sep = "")
  rep_print_kpis(x, sim)
  cat("\n", lbl("report.print.table_header"), "\n", sep = "")
  rep_print_table(x, sim, max_periods)
  inv_ok <- all(x$checks$ok)
  cat("\n", lbl(if (inv_ok) "report.print.checks_ok" else "report.print.checks_failed"), "\n",
      sep = "")
  invisible(x)
}

#' Kennzahlen eines Laufs ausgeben (Primärkennzahl zuerst)
#' @noRd
rep_print_kpis <- function(x, sim) {
  cat(lbl("report.print.kpi_header"), "\n", sep = "")
  nm <- names(x$kpis)
  if (length(nm) == 0L) return(invisible())
  primary <- x$meta$primary_kpi %||% "delta_terminal_value"
  first <- intersect(c(primary, paste0(primary, "_ex_rv")), nm)
  nm <- c(first, setdiff(nm, first))
  labels <- vapply(nm, function(k) {
    base <- sub("_ex_rv$", "", k)
    txt <- lbl(paste0("types.kpi.", base, ".label"), .default = base)
    if (!identical(base, k)) txt <- paste(txt, lbl("report.print.ex_rv"))
    if (identical(base, primary) && identical(base, k)) txt <- paste(txt,
                                                                     lbl("report.print.primary"))
    txt
  }, "")
  vals <- vapply(nm, function(k) {
    v <- x$kpis[[k]][sim]
    if (is.na(v)) {
      code <- x$kpi_na[[k]][sim]
      return(paste0(fmt_num(NA), " (", lbl(paste0("vocab.na_reasons.", code), .default = code),
                    ")"))
    }
    unit <- rep_kpi_unit(sub("_ex_rv$", "", k))
    if (identical(unit, "EUR")) fmt_eur(v, 2) else fmt_num(v, 4)
  }, "")
  w <- max(nchar(labels, type = "width"))
  for (i in seq_along(nm)) {
    pad <- strrep(" ", w - nchar(labels[i], type = "width"))
    cat("  ", labels[i], pad, "  ", vals[i], "\n", sep = "")
  }
  invisible()
}

#' Einheit einer registrierten Kennzahl
#' @noRd
rep_kpi_unit <- function(name) {
  if (reg_has("kpi", name)) reg_get("kpi", name)$unit else NA_character_
}

#' Gekürzte VoFi-Tabelle (Summen je Abschnitt, Finanzierungssaldo, Bestandssaldo)
#' @noRd
rep_print_table <- function(x, sim, max_periods) {
  led <- x$ledger
  g <- x$grid
  n_t <- g$T + 1L
  secs <- c("project", "grants", "equity", "loans", "overdraft", "deposit", "tax")
  rows <- list()
  for (s in secs) {
    keys <- ledger_select(led, section = s, cash = TRUE)
    if (length(keys) == 0L) next
    v <- Reduce(`+`, lapply(led$values[keys], function(m) m[sim, ]))
    lab <- if (identical(s, "project")) lbl("core.rows.cf_project") else
      lbl(paste0("core.sections.", s))
    rows[[lab]] <- v
  }
  rows[[lbl("core.rows.balance_check")]] <- led$values$balance_check[sim, ]
  rows[[lbl("core.rows.net_position")]] <- led$values$net_position[sim, ]
  cols <- seq_len(n_t)
  gap <- FALSE
  if (n_t > max_periods) {
    keep_head <- max(1L, max_periods - 2L)
    cols <- c(seq_len(keep_head), n_t - 1L, n_t)
    gap <- TRUE
  }
  head_lab <- g$label[cols]
  cells <- lapply(rows, function(v) fmt_num(v[cols], 2))
  if (gap) {
    ins <- length(cols) - 2L
    head_lab <- append(head_lab, "...", after = ins)
    cells <- lapply(cells, function(cc) append(cc, "...", after = ins))
  }
  labels <- names(rows)
  wl <- max(nchar(labels, type = "width"))
  wc <- max(nchar(c(head_lab, unlist(cells)), type = "width"))
  pad_left <- function(s, w) paste0(strrep(" ", w - nchar(s, type = "width")), s)
  pad_right <- function(s, w) paste0(s, strrep(" ", w - nchar(s, type = "width")))
  cat("  ", pad_right("", wl), "  ",
      paste(vapply(head_lab, pad_left, "", w = wc), collapse = "  "), "\n", sep = "")
  for (i in seq_along(labels)) {
    cat("  ", pad_right(labels[i], wl), "  ",
        paste(vapply(cells[[i]], pad_left, "", w = wc), collapse = "  "), "\n", sep = "")
  }
  invisible()
}
