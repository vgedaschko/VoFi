# Excel-Export (WS-H, Spec 00 Abschnitte 7.10, 13.6, 14 Nr. 25; Konzept 5.5).
# Eigentuemer: WS-H. vofi_export_excel() schreibt mit openxlsx eine Arbeitsmappe: Uebersicht,
# VoFi (Grob-Layout) und VoFi transponiert mit dem Finanzierungssaldo und den Anzeige-Summen
# als Excel-Formeln, Kennzahlen (auch je WE und je m2), Zahlungsbuch (brutto, netto, USt),
# Annahmen mit Herkunft, Pruefungen; bei Simulationen MC-Statistik, Kennzahlen je Lauf und
# Pfad-Quantile; bei Vergleichen Varianten, Differenzen, Ampel und je Variante eine VoFi-Tabelle
# (dazu der Differenz-VoFi); bei Sensitivitaetsanalysen die Ergebnisse. Texte stehen in
# inst/labels/de/excel_export.yaml (excel_export.*); Zahlenformate mit Tausenderpunkt und
# negativen Werten in Rot.

# ---------------------------------------------------------------------------------------------
# Blätter und Stile
# ---------------------------------------------------------------------------------------------

#' Blattcodes je Klasse (Reihenfolge der Arbeitsmappe)
#' @noRd
rep_xl_codes <- function(x) {
  if (inherits(x, "vofi_comparison")) {
    return(c("overview", "variants", "differences", "traffic_light", "vofi", "diff_vofi",
             "kpis", "ledger", "assumptions", "checks"))
  }
  if (inherits(x, "vofi_mc_result")) {
    return(c("overview", "vofi", "vofi_transposed", "kpis", "mc_stats", "mc_runs", "mc_bands",
             "ledger", "assumptions", "checks"))
  }
  if (inherits(x, "vofi_sensitivity")) {
    return(c("overview", "sensitivity", "sensitivity_params"))
  }
  c("overview", "vofi", "vofi_transposed", "kpis", "ledger", "assumptions", "checks")
}

#' Alle Blattcodes
#' @noRd
rep_xl_all_codes <- function() {
  c("overview", "vofi", "vofi_transposed", "kpis", "ledger", "assumptions", "checks",
    "mc_stats", "mc_runs", "mc_bands", "variants", "differences", "traffic_light", "diff_vofi",
    "sensitivity", "sensitivity_params")
}

#' Zellformate (deutsche Anzeige über die Ländereinstellung von Excel)
#' @noRd
rep_xl_styles <- function() {
  list(
    title = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
    subtitle = openxlsx::createStyle(fontColour = "#555555", textDecoration = "italic"),
    header = openxlsx::createStyle(textDecoration = "bold", fgFill = "#E7EEF6",
                                   border = "bottom", wrapText = TRUE, valign = "top"),
    eur = openxlsx::createStyle(numFmt = "#,##0.00;[Red]-#,##0.00"),
    eur0 = openxlsx::createStyle(numFmt = "#,##0;[Red]-#,##0"),
    num = openxlsx::createStyle(numFmt = "#,##0.00"),
    num4 = openxlsx::createStyle(numFmt = "0.0000"),
    int = openxlsx::createStyle(numFmt = "0"),
    pct = openxlsx::createStyle(numFmt = "0.00%"),
    date = openxlsx::createStyle(numFmt = "dd.mm.yyyy", halign = "right"),
    bold = openxlsx::createStyle(textDecoration = "bold"),
    sum = openxlsx::createStyle(textDecoration = "bold", border = "top"),
    check = openxlsx::createStyle(textDecoration = "bold", fgFill = "#FFF4CE",
                                  border = c("top", "bottom")),
    text = openxlsx::createStyle(wrapText = TRUE, valign = "top")
  )
}

#' Zellformat einer Einheit
#' @noRd
rep_xl_unit_style <- function(unit, styles) {
  if (is.na(unit)) return(styles$num)
  switch(unit,
    EUR = styles$eur, EUR_pa = , EUR_month = , EUR_m2_month = , EUR_m2 = , EUR_m2_pa = ,
    EUR_t = , EUR_unit = styles$eur,
    rate_pa = , share = styles$pct,
    year = , flag = , count = styles$int,
    ratio = , factor = styles$num, years = styles$num,
    styles$num
  )
}

#' Eindeutiger Blattname (höchstens 31 Zeichen, ohne verbotene Zeichen)
#' @noRd
rep_xl_sheet_name <- function(wb, name) {
  name <- gsub("[]\\[:*?/\\\\]", "_", name, perl = TRUE)
  name <- substr(name, 1L, 31L)
  existing <- names(wb)
  base <- name
  i <- 1L
  while (tolower(name) %in% tolower(existing)) {
    i <- i + 1L
    suffix <- paste0(" (", i, ")")
    name <- paste0(substr(base, 1L, 31L - nchar(suffix)), suffix)
  }
  name
}

#' Blatt anlegen
#' @noRd
rep_xl_add_sheet <- function(wb, code, ...) {
  name <- rep_xl_sheet_name(wb, lbl(paste0("excel_export.sheets.", code), ...))
  openxlsx::addWorksheet(wb, name)
  name
}

#' Spaltenüberschriften (Label-Schlüssel excel_export.columns.<name>, sonst Name)
#' @noRd
rep_xl_col_names <- function(cols) {
  vapply(cols, function(cc) lbl(paste0("excel_export.columns.", cc), .default = cc), "",
         USE.NAMES = FALSE)
}

#' Data Frame mit Kopfzeile schreiben
#' @return Zeile nach dem Block.
#' @noRd
rep_xl_write_df <- function(wb, sheet, df, styles, start_row = 1L, header = NULL,
                            col_styles = list()) {
  if (is.null(header)) header <- rep_xl_col_names(names(df))
  out <- df
  names(out) <- make.unique(header)
  openxlsx::writeData(wb, sheet, out, startRow = start_row, colNames = TRUE,
                      headerStyle = styles$header, keepNA = FALSE)
  for (cc in names(col_styles)) {
    j <- match(cc, names(df))
    if (!is.na(j) && nrow(df) > 0L) {
      openxlsx::addStyle(wb, sheet, col_styles[[cc]], rows = start_row + seq_len(nrow(df)),
                         cols = j, gridExpand = TRUE, stack = TRUE)
    }
  }
  start_row + nrow(df) + 2L
}

#' Titelzeilen schreiben
#' @noRd
rep_xl_title <- function(wb, sheet, title, subtitle = NULL, styles) {
  openxlsx::writeData(wb, sheet, title, startRow = 1L, startCol = 1L)
  openxlsx::addStyle(wb, sheet, styles$title, rows = 1L, cols = 1L)
  if (!is.null(subtitle)) {
    openxlsx::writeData(wb, sheet, subtitle, startRow = 2L, startCol = 1L)
    openxlsx::addStyle(wb, sheet, styles$subtitle, rows = 2L, cols = 1L)
  }
  invisible()
}

# ---------------------------------------------------------------------------------------------
# Formeln
# ---------------------------------------------------------------------------------------------

#' Indizes zu Bereichen zusammenfassen (aufeinanderfolgende Zahlen)
#' @return Liste von `c(von, bis)`.
#' @noRd
rep_xl_runs <- function(idx) {
  idx <- sort(unique(as.integer(idx)))
  if (length(idx) == 0L) return(list())
  br <- c(0L, which(diff(idx) != 1L), length(idx))
  lapply(seq_len(length(br) - 1L), function(i) c(idx[br[i] + 1L], idx[br[i + 1L]]))
}

#' SUMME-Formel über Zellen einer Spalte (`rows`) bzw. Zeile (`cols`)
#'
#' Bereiche werden zusammengefasst; mehr als 200 Argumente werden in geschachtelte SUM()
#' aufgeteilt (Excel erlaubt höchstens 255 Argumente). Ohne Zellen: `0`.
#' @param col Spaltenbuchstabe (Formel über Zeilen) bzw. `NULL`.
#' @param rows Zeilennummern bzw. Zeile (bei `cols`).
#' @param cols Spaltennummern (Formel über Spalten) bzw. `NULL`.
#' @noRd
rep_xl_sum_formula <- function(col = NULL, rows = NULL, cols = NULL) {
  refs <- if (!is.null(cols)) {
    vapply(rep_xl_runs(cols), function(r) {
      a <- paste0(openxlsx::int2col(r[1L]), rows)
      b <- paste0(openxlsx::int2col(r[2L]), rows)
      if (r[1L] == r[2L]) a else paste0(a, ":", b)
    }, "")
  } else {
    vapply(rep_xl_runs(rows), function(r) {
      if (r[1L] == r[2L]) paste0(col, r[1L]) else paste0(col, r[1L], ":", col, r[2L])
    }, "")
  }
  if (length(refs) == 0L) return("0")
  chunks <- split(refs, ceiling(seq_along(refs) / 200L))
  parts <- vapply(chunks, function(ch) paste0("SUM(", paste(ch, collapse = ","), ")"), "")
  unname(if (length(parts) == 1L) parts else paste0("SUM(", paste(parts, collapse = ","), ")"))
}

#' Zeilen, deren Summe eine Formelzeile bildet
#'
#' Anzeige-Summe (`kind = "sum"`): die zahlungswirksamen Unterzeilen (Ebene 1) ihres Abschnitts;
#' Finanzierungssaldo: alle zahlungswirksamen Zeilen der Abschnitte 100 bis 700 außer den
#' Anzeige-Summen (7.9 Nr. 1).
#' @return benannte Liste row_key -> Indizes der Tabellenzeilen.
#' @noRd
rep_xl_formula_rows <- function(tab) {
  d <- tab$data
  r <- tab$rows
  out <- list()
  for (i in which(r$kind == "sum")) {
    out[[d$row_key[i]]] <- which(d$section == d$section[i] & d$level == 1L & r$cash &
                                   r$kind != "sum")
  }
  chk <- which(d$section == "check")
  if (length(chk) > 0L) {
    out[[d$row_key[chk[1L]]]] <- which(d$section %in% rep_balance_sections() & r$cash &
                                         r$kind != "sum")
  }
  out
}

# ---------------------------------------------------------------------------------------------
# VoFi-Tabellen
# ---------------------------------------------------------------------------------------------

#' VoFi-Tabelle im Grob-Layout mit Formeln schreiben
#' @noRd
rep_xl_vofi_grob <- function(wb, sheet, tab, styles, title) {
  d <- tab$data
  r <- tab$rows
  cols <- tab$columns
  np <- nrow(cols)
  rep_xl_title(wb, sheet, title, lbl("excel_export.notes.saldo_formula"), styles)
  hr <- 4L
  first <- hr + 2L
  hdr <- c(lbl("report.table.position"), lbl("excel_export.columns.key"), cols$label)
  openxlsx::writeData(wb, sheet, t(hdr), startRow = hr, colNames = FALSE)
  openxlsx::writeData(wb, sheet, lbl("report.table.date_end"), startRow = hr + 1L,
                      startCol = 1L)
  dates <- lapply(seq_len(np), function(j) cols$date_end[j])
  dates <- as.data.frame(stats::setNames(dates, paste0("d", seq_len(np))))
  openxlsx::writeData(wb, sheet, dates, startRow = hr + 1L, startCol = 3L, colNames = FALSE)
  openxlsx::addStyle(wb, sheet, styles$header, rows = hr, cols = seq_len(np + 2L))
  openxlsx::addStyle(wb, sheet, styles$date, rows = hr + 1L, cols = 2L + seq_len(np))
  if (nrow(d) == 0L) return(invisible())
  rows_x <- first + seq_len(nrow(d)) - 1L
  labels <- d$label
  openxlsx::writeData(wb, sheet, data.frame(a = labels, b = d$row_key), startRow = first,
                      colNames = FALSE)
  vals <- as.matrix(d[, cols$label, drop = FALSE])
  openxlsx::writeData(wb, sheet, as.data.frame(vals), startRow = first, startCol = 3L,
                      colNames = FALSE)
  for (lv in unique(d$level[d$level > 0L])) {
    openxlsx::addStyle(wb, sheet, openxlsx::createStyle(indent = 2L * lv),
                       rows = rows_x[d$level == lv], cols = 1L, stack = TRUE)
  }
  pcols <- 2L + seq_len(np)
  for (i in seq_len(nrow(d))) {
    st <- if (identical(r$unit[i], "EUR")) styles$eur else rep_xl_unit_style(r$unit[i], styles)
    openxlsx::addStyle(wb, sheet, st, rows = rows_x[i], cols = pcols, stack = TRUE)
  }
  fr <- rep_xl_formula_rows(tab)
  for (k in names(fr)) {
    i <- match(k, d$row_key)
    for (j in seq_len(np)) {
      col <- openxlsx::int2col(2L + j)
      openxlsx::writeFormula(wb, sheet, rep_xl_sum_formula(col, rows_x[fr[[k]]]),
                             startCol = 2L + j, startRow = rows_x[i])
    }
    st <- if (identical(d$section[i], "check")) styles$check else styles$sum
    openxlsx::addStyle(wb, sheet, st, rows = rows_x[i], cols = c(1L, 2L, pcols), stack = TRUE)
  }
  openxlsx::setColWidths(wb, sheet, cols = 1L, widths = 46)
  openxlsx::setColWidths(wb, sheet, cols = 2L, widths = 22)
  openxlsx::setColWidths(wb, sheet, cols = pcols, widths = 14)
  openxlsx::freezePane(wb, sheet, firstActiveRow = first, firstActiveCol = 3L)
  invisible()
}

#' VoFi-Tabelle transponiert mit Formeln schreiben
#' @noRd
rep_xl_vofi_transposed <- function(wb, sheet, tab, styles, title) {
  d <- tab$data
  r <- tab$rows
  cols <- tab$columns
  np <- nrow(cols)
  rep_xl_title(wb, sheet, title, lbl("excel_export.notes.saldo_formula"), styles)
  hr <- 4L
  first <- hr + 2L
  hdr <- c(lbl("report.table.period"), lbl("report.table.date_end"), d$label)
  keys <- c("", "", d$row_key)
  openxlsx::writeData(wb, sheet, t(hdr), startRow = hr, colNames = FALSE)
  openxlsx::writeData(wb, sheet, t(keys), startRow = hr + 1L, colNames = FALSE)
  openxlsx::addStyle(wb, sheet, styles$header, rows = hr, cols = seq_along(hdr))
  rows_x <- first + seq_len(np) - 1L
  openxlsx::writeData(wb, sheet, data.frame(p = cols$label, d = cols$date_end),
                      startRow = first, colNames = FALSE)
  openxlsx::addStyle(wb, sheet, styles$date, rows = rows_x, cols = 2L)
  if (nrow(d) == 0L) return(invisible())
  vals <- t(as.matrix(d[, cols$label, drop = FALSE]))
  openxlsx::writeData(wb, sheet, as.data.frame(vals), startRow = first, startCol = 3L,
                      colNames = FALSE)
  for (i in seq_len(nrow(d))) {
    st <- if (identical(r$unit[i], "EUR")) styles$eur else rep_xl_unit_style(r$unit[i], styles)
    openxlsx::addStyle(wb, sheet, st, rows = rows_x, cols = 2L + i, stack = TRUE)
  }
  fr <- rep_xl_formula_rows(tab)
  for (k in names(fr)) {
    i <- match(k, d$row_key)
    f <- vapply(rows_x, function(rr) rep_xl_sum_formula(rows = rr, cols = 2L + fr[[k]]), "")
    openxlsx::writeFormula(wb, sheet, f, startCol = 2L + i, startRow = first)
    st <- if (identical(d$section[i], "check")) styles$check else styles$sum
    openxlsx::addStyle(wb, sheet, st, rows = c(hr, rows_x), cols = 2L + i, stack = TRUE)
  }
  openxlsx::setColWidths(wb, sheet, cols = 1:2, widths = 13)
  openxlsx::setColWidths(wb, sheet, cols = 2L + seq_len(nrow(d)), widths = 16)
  openxlsx::freezePane(wb, sheet, firstActiveRow = first, firstActiveCol = 3L)
  invisible()
}

#' Titel einer VoFi-Tabelle
#' @noRd
rep_xl_vofi_title <- function(tab, transposed = FALSE) {
  lbl(if (transposed) "excel_export.titles.vofi_transposed" else "excel_export.titles.vofi",
      title = tab$meta$title %||% "", variant = tab$variant %||% "base",
      sim = rep_sim_label(tab$sim))
}

# ---------------------------------------------------------------------------------------------
# Inhalte der Blätter
# ---------------------------------------------------------------------------------------------

#' Zeilen „Merkmal | Wert“ der Übersicht
#' @noRd
rep_xl_overview_rows <- function(x) {
  it <- function(key, value) {
    value <- as.character(value)
    if (length(value) == 0L) value <- ""
    data.frame(item = c(lbl(paste0("excel_export.overview.", key)),
                        rep("", length(value) - 1L)),
               value = value, stringsAsFactors = FALSE)
  }
  if (inherits(x, "vofi_sensitivity")) {
    return(rbind(
      it("kind", lbl("excel_export.overview.kind_sensitivity")),
      it("method", lbl(paste0("report.sensitivity.method_", x$method), .default = x$method)),
      it("kpi", if (utl_is_string(x$kpi)) kpi_label(x$kpi) else ""),
      it("variant", x$variant %||% "base"),
      it("base_value", rep_fmt_value(x$base_value %||% NA_real_, rep_sens_unit(x), 2))
    ))
  }
  if (inherits(x, "vofi_comparison")) {
    base <- rep_det_result(rep_comparison_result(x, NULL))
    rows <- list(
      it("kind", lbl("excel_export.overview.kind_comparison")),
      it("title", base$spec$meta$title %||% base$meta$scenario_id %||% ""),
      it("scenario_id", base$meta$scenario_id %||% ""),
      it("baseline", x$baseline %||% ""),
      it("variants", utl_collapse(x$variants %||% character(0))),
      it("mode", if (identical(x$meta$mode, "mc")) {
        lbl("report.compare.mode_mc", n = as.integer(x$meta$n_sim %||% NA_integer_))
      } else {
        lbl("report.compare.mode_det")
      }),
      it("n_sim", x$meta$n_sim %||% 1L)
    )
    pb <- rep_prob_better_text(x)
    if (!is.null(pb)) rows[[length(rows) + 1L]] <- it("prob_better", pb)
    rk <- x$ranking
    if (is.data.frame(rk) && nrow(rk) > 0L) {
      rk <- rk[order(rk$rank, method = "radix"), , drop = FALSE]
      rows[[length(rows) + 1L]] <- it("ranking", paste0(rk$rank, ". ", rk$variant))
    }
    st <- rep_cmp_status_lines(x)
    if (length(st) > 0L) rows[[length(rows) + 1L]] <- it("traffic_light", st)
    rows[[length(rows) + 1L]] <- it("comparability", rep_cmp_comparability(x))
    return(do.call(rbind, rows))
  }
  res <- rep_det_result(x)
  m <- res$meta
  g <- res$grid
  primary <- m$primary_kpi %||% "delta_terminal_value"
  pv <- function(k) {
    if (!(k %in% names(res$kpis))) return(fmt_num(NA))
    rep_fmt_kpi(res$kpis[[k]][1L], kpi_unit(k), res$kpi_na[[k]][1L])
  }
  rows <- list(
    it("kind", lbl(paste0("excel_export.overview.kind_",
                          if (inherits(x, "vofi_mc_result")) "mc" else "result"))),
    it("title", res$spec$meta$title %||% m$scenario_id %||% ""),
    it("scenario_id", m$scenario_id %||% ""), it("variant", m$variant %||% "base"),
    it("perspective", rep_enum_label("perspective", m$perspective)),
    it("tax_regime", rep_enum_label("tax_regime", m$tax_regime)),
    it("report_mode", lbl(paste0("report.print.report_mode_", m$report_mode %||% "expert"),
                          .default = m$report_mode %||% "")),
    it("valuation_date", fmt_date(g$valuation_date)), it("end_date", fmt_date(g$end_date)),
    it("periods", g$T),
    it("primary", paste0(kpi_label(primary), ": ", pv(primary))),
    it("primary_ex_rv", paste0(kpi_label(paste0(primary, "_ex_rv")), ": ",
                               pv(paste0(primary, "_ex_rv"))))
  )
  if (inherits(x, "vofi_mc_result")) {
    mm <- x$meta
    rows[[length(rows) + 1L]] <- it("n_sim", mm$n_sim %||% nrow(x$kpis))
    rows[[length(rows) + 1L]] <- it("seed", format(mm$seed %||% NA))
    rows[[length(rows) + 1L]] <- it("sampling", paste0(mm$sampling %||% "", ", ",
                                                       mm$replicates %||% 1L, " x ",
                                                       mm$block_size %||% NA))
    risk <- rep_mc_risk_lines(x)
    if (length(risk) > 0L) rows[[length(rows) + 1L]] <- it("risk", risk)
    tl <- rep_traffic_lines(x$traffic_light)
  } else {
    tl <- rep_traffic_lines(rep_traffic_light(res))
  }
  if (length(tl) > 0L) rows[[length(rows) + 1L]] <- it("traffic_light", tl)
  notes <- rep_result_notes(res)
  if (length(notes) > 0L) rows[[length(rows) + 1L]] <- it("notes", notes)
  ok_key <- if (all(res$checks$ok %in% TRUE)) "report.print.checks_ok" else
    "report.print.checks_failed"
  rows[[length(rows) + 1L]] <- it("checks", lbl(ok_key))
  do.call(rbind, rows)
}

#' Blatt Übersicht
#' @noRd
rep_xl_sheet_overview <- function(wb, x, styles) {
  sheet <- rep_xl_add_sheet(wb, "overview")
  version <- as.character(utils::packageVersion("vofi"))
  rep_xl_title(wb, sheet, lbl("excel_export.titles.overview"),
               lbl("excel_export.notes.created", version = version,
                   contract = VOFI_CONTRACT_VERSION), styles)
  df <- rep_xl_overview_rows(x)
  rep_xl_write_df(wb, sheet, df, styles, start_row = 4L,
                  header = c(lbl("excel_export.columns.item"), lbl("excel_export.columns.value")))
  openxlsx::setColWidths(wb, sheet, cols = 1:2, widths = c(36, 110))
  sheet
}

#' Blätter VoFi bzw. VoFi transponiert
#' @noRd
rep_xl_sheet_vofi <- function(wb, x, styles, transposed = FALSE) {
  if (inherits(x, "vofi_comparison")) {
    for (v in rep_comparison_variants(x)) {
      tab <- vofi_table(x, sim = rep_xl_sim(x$results[[v]]), layout = "grob",
                        detail = "standard", variant = v)
      sheet <- rep_xl_add_sheet(wb, "vofi_variant", variant = v)
      rep_xl_vofi_grob(wb, sheet, tab, styles, rep_xl_vofi_title(tab))
    }
    return(invisible())
  }
  tab <- vofi_table(x, sim = rep_xl_sim(x), layout = "grob", detail = "standard")
  if (transposed) {
    sheet <- rep_xl_add_sheet(wb, "vofi_transposed")
    rep_xl_vofi_transposed(wb, sheet, tab, styles, rep_xl_vofi_title(tab, TRUE))
  } else {
    sheet <- rep_xl_add_sheet(wb, "vofi")
    rep_xl_vofi_grob(wb, sheet, tab, styles, rep_xl_vofi_title(tab))
  }
  invisible(sheet)
}

#' Lauf der VoFi-Tabelle: Simulation = Basisfall, sonst Lauf 1
#' @noRd
rep_xl_sim <- function(x) if (inherits(x, "vofi_mc_result")) "deterministic" else 1L

#' Blatt Differenz-VoFi (Variante minus Referenz, je Variante untereinander)
#' @noRd
rep_xl_sheet_diff_vofi <- function(wb, x, styles) {
  vars <- setdiff(rep_comparison_variants(x), x$baseline)
  ref_tab <- vofi_table(x, sim = rep_xl_sim(x$results[[x$baseline]]), layout = "grob",
                        variant = x$baseline)
  sheet <- rep_xl_add_sheet(wb, "diff_vofi")
  row <- 1L
  for (v in vars) {
    tab <- vofi_table(x, sim = rep_xl_sim(x$results[[v]]), layout = "grob", variant = v)
    dt <- rep_table_diff(tab, ref_tab, v, x$baseline)
    title <- lbl("excel_export.titles.diff_vofi", variant = v, baseline = x$baseline)
    if (is.null(dt)) {
      openxlsx::writeData(wb, sheet, c(title, lbl("excel_export.notes.diff_grid")),
                          startRow = row)
      row <- row + 3L
      next
    }
    openxlsx::writeData(wb, sheet, title, startRow = row)
    openxlsx::addStyle(wb, sheet, styles$bold, rows = row, cols = 1L)
    df <- dt$data[, c("label", "row_key", dt$columns$label), drop = FALSE]
    names(df) <- c(lbl("report.table.position"), lbl("excel_export.columns.key"),
                   dt$columns$label)
    openxlsx::writeData(wb, sheet, df, startRow = row + 1L, headerStyle = styles$header)
    openxlsx::addStyle(wb, sheet, styles$eur, rows = row + 1L + seq_len(nrow(df)),
                       cols = 2L + seq_along(dt$columns$label), gridExpand = TRUE)
    row <- row + nrow(df) + 4L
  }
  openxlsx::setColWidths(wb, sheet, cols = 1:2, widths = c(46, 22))
  invisible(sheet)
}

#' Rohdaten der Kennzahltabelle mit Werten je WE und je m² (falls bestimmbar)
#' @noRd
rep_xl_kpi_frame <- function(x) {
  tab <- vofi_kpis(x)
  rv_lab <- function(v) {
    vapply(v, function(e) lbl(paste0("excel_export.rv.", e), .default = e), "",
           USE.NAMES = FALSE)
  }
  tab$rv <- rv_lab(tab$rv)
  tab$unit_label <- vapply(tab$unit, function(u) {
    if (is.na(u)) "" else lbl(paste0("vocab.units.", u), .default = u)
  }, "", USE.NAMES = FALSE)
  if (!inherits(x, "vofi_comparison")) {
    for (per in c("unit", "m2")) {
      alt <- tryCatch(vofi_kpis(x, per = per), vofi_error = function(e) NULL)
      if (is.null(alt)) next
      col <- if ("value" %in% names(alt)) "value" else "mean"
      key <- if ("sim" %in% names(tab)) paste(tab$sim, tab$kpi) else tab$kpi
      akey <- if ("sim" %in% names(alt)) paste(alt$sim, alt$kpi) else alt$kpi
      v <- alt[[col]][match(key, akey)]
      v[!(tab$unit %in% c("EUR", "EUR_pa", "EUR_month"))] <- NA_real_
      tab[[paste0("per_", per)]] <- v
    }
  }
  tab
}

#' Blatt Kennzahlen
#' @noRd
rep_xl_sheet_kpis <- function(wb, x, styles) {
  sheet <- rep_xl_add_sheet(wb, "kpis")
  rep_xl_title(wb, sheet, lbl("excel_export.titles.kpis"), lbl("excel_export.notes.kpis"),
               styles)
  tab <- rep_xl_kpi_frame(x)
  num_cols <- intersect(c("value", "deterministic", "mean", "sd", "q05", "q50", "q95",
                          "per_unit", "per_m2"), names(tab))
  keep <- c(intersect(c("variant", "sim"), names(tab)), "label", "kpi", "unit_label", "rv",
            num_cols, intersect(c("p_neg", "na_share", "n_valid", "na_label", "note"),
                                names(tab)))
  df <- tab[, keep, drop = FALSE]
  start <- 4L
  rep_xl_write_df(wb, sheet, df, styles, start_row = start)
  rows_x <- start + seq_len(nrow(df))
  for (i in seq_len(nrow(df))) {
    st <- rep_xl_unit_style(tab$unit[i], styles)
    openxlsx::addStyle(wb, sheet, st, rows = rows_x[i], cols = match(num_cols, names(df)),
                       stack = TRUE)
  }
  for (cc in intersect(c("p_neg", "na_share"), names(df))) {
    openxlsx::addStyle(wb, sheet, styles$pct, rows = rows_x, cols = match(cc, names(df)),
                       stack = TRUE)
  }
  openxlsx::setColWidths(wb, sheet, cols = seq_len(ncol(df)), widths = "auto")
  openxlsx::freezePane(wb, sheet, firstActiveRow = start + 1L)
  invisible(sheet)
}

#' Blatt Zahlungsbuch (brutto, netto, USt; 7.10)
#' @noRd
rep_xl_sheet_ledger <- function(wb, x, styles) {
  # Simulation: Zahlungsbuch des Basisfalls (alle Läufe sprengen die Zeilenzahl von Excel)
  src <- if (inherits(x, "vofi_mc_result")) x$deterministic else x
  grid <- if (inherits(src, "vofi_comparison")) {
    rep_det_result(rep_comparison_result(src))$grid
  } else {
    src$grid
  }
  led <- vofi_ledger(src, format = "wide", vat = TRUE)
  sheet <- rep_xl_add_sheet(wb, "ledger")
  rep_xl_title(wb, sheet, lbl("excel_export.titles.ledger"), lbl("excel_export.notes.ledger"),
               styles)
  led$amount <- vapply(led$amount, function(a) lbl(paste0("excel_export.amount.", a)), "",
                       USE.NAMES = FALSE)
  led$cash <- ifelse(led$cash, lbl("report.common.yes"), lbl("report.common.no"))
  pcols <- intersect(grid$label, names(led))
  meta <- setdiff(names(led), pcols)
  hdr <- c(rep_xl_col_names(meta), pcols)
  start <- 4L
  rep_xl_write_df(wb, sheet, led, styles, start_row = start, header = hdr)
  if (nrow(led) > 0L) {
    openxlsx::addStyle(wb, sheet, styles$eur, rows = start + seq_len(nrow(led)),
                       cols = match(pcols, names(led)), gridExpand = TRUE, stack = TRUE)
    openxlsx::addStyle(wb, sheet, styles$pct, rows = start + seq_len(nrow(led)),
                       cols = match("vat_rate", names(led)), stack = TRUE)
  }
  openxlsx::freezePane(wb, sheet, firstActiveRow = start + 1L, firstActiveCol = 3L)
  openxlsx::setColWidths(wb, sheet, cols = 1:2, widths = c(28, 40))
  invisible(sheet)
}

#' Blatt Annahmen mit Herkunft (4.8)
#' @noRd
rep_xl_sheet_assumptions <- function(wb, x, styles) {
  res <- if (inherits(x, "vofi_comparison")) rep_det_result(rep_comparison_result(x)) else
    rep_det_result(x)
  sheet <- rep_xl_add_sheet(wb, "assumptions")
  rep_xl_title(wb, sheet, lbl("excel_export.titles.assumptions"),
               lbl("excel_export.notes.assumptions"), styles)
  m <- res$meta
  mm <- if (inherits(x, "vofi_mc_result")) x$meta else m
  defaults <- m$defaults %||% list()
  def_txt <- vapply(defaults, function(d) {
    if (is.list(d)) utl_collapse(paste0(names(d), "=", vapply(d, function(e) {
      utl_collapse(format(e))
    }, "")), "; ") else utl_collapse(format(d))
  }, "")
  meta <- data.frame(
    item = rep_xl_col_names(c("package_version", "contract_version", "schema_version",
                              "scenario_id", "variant", "scenario_set", "perspective",
                              "tax_regime", "tax_module", "legal_state", "pending_reforms",
                              "library_version", "seed", "n_sim", "created", "r_version",
                              "defaults")),
    value = c(m$package_version %||% "", m$contract_version %||% "",
              format(m$schema_version %||% ""), m$scenario_id %||% "", m$variant %||% "",
              m$scenario_set %||% "", m$perspective %||% "", m$tax_regime %||% "",
              m$tax_module %||% "", fmt_date(m$legal_state %||% NA),
              utl_collapse(m$pending_reforms %||% character(0)),
              m$library_version %||% "", format(mm$seed %||% ""),
              format(mm$n_sim %||% 1L), format(m$created %||% ""), m$r_version %||% "",
              utl_collapse(paste0(names(def_txt), ": ", def_txt), " | ")),
    stringsAsFactors = FALSE
  )
  row <- rep_xl_write_df(wb, sheet, meta, styles, start_row = 4L,
                         header = c(lbl("excel_export.columns.item"),
                                    lbl("excel_export.columns.value")))
  lib <- res$spec$library %||% m$library
  if (is.data.frame(lib) && nrow(lib) > 0L) {
    openxlsx::writeData(wb, sheet, lbl("excel_export.titles.library"), startRow = row)
    openxlsx::addStyle(wb, sheet, styles$bold, rows = row, cols = 1L)
    row <- rep_xl_write_df(wb, sheet, lib, styles, start_row = row + 1L,
                           col_styles = list(as_of = styles$date, valid_from = styles$date,
                                             valid_to = styles$date))
  }
  openxlsx::writeData(wb, sheet, lbl("excel_export.titles.parameters"), startRow = row)
  openxlsx::addStyle(wb, sheet, styles$bold, rows = row, cols = 1L)
  params <- as.data.frame(res$spec)
  rep_xl_write_df(wb, sheet, params, styles, start_row = row + 1L,
                  col_styles = list(valid_from = styles$date, valid_to = styles$date,
                                    as_of = styles$date, accessed = styles$date))
  openxlsx::setColWidths(wb, sheet, cols = 1:4, widths = c(44, 14, 10, 40))
  invisible(sheet)
}

#' Blatt Prüfungen (Invarianten, Markierungen)
#' @noRd
rep_xl_sheet_checks <- function(wb, x, styles) {
  sheet <- rep_xl_add_sheet(wb, "checks")
  rep_xl_title(wb, sheet, lbl("excel_export.titles.checks"), lbl("excel_export.notes.checks"),
               styles)
  results <- if (inherits(x, "vofi_comparison")) x$results else list(x)
  names(results) <- if (inherits(x, "vofi_comparison")) names(x$results) else
    (rep_det_result(x)$meta$variant %||% "base")
  row <- 4L
  for (v in names(results)) {
    r <- results[[v]]
    ch <- r$checks
    if (is.data.frame(ch) && nrow(ch) > 0L) {
      ch <- cbind(data.frame(variant = rep(v, nrow(ch)), stringsAsFactors = FALSE), ch)
      ch$ok <- ifelse(ch$ok %in% TRUE, lbl("report.common.yes"), lbl("report.common.no"))
      row <- rep_xl_write_df(wb, sheet, ch, styles, start_row = row)
    }
    fl <- r$flags
    if (is.data.frame(fl) && nrow(fl) > 0L) {
      cols <- setdiff(names(fl), c("sim", "block", "branch"))
      share <- vapply(cols, function(cc) {
        v2 <- fl[[cc]]
        if (is.logical(v2)) mean(v2 %in% TRUE) else suppressWarnings(mean(as.double(v2)))
      }, double(1))
      fdf <- data.frame(variant = v, flag = cols, value = as.double(share),
                        stringsAsFactors = FALSE)
      row <- rep_xl_write_df(wb, sheet, fdf, styles, start_row = row,
                             header = rep_xl_col_names(c("variant", "flag", "flag_share")))
    }
  }
  openxlsx::setColWidths(wb, sheet, cols = 1:6, widths = c(14, 26, 16, 16, 10, 10))
  invisible(sheet)
}

#' Blatt MC-Statistik
#' @noRd
rep_xl_sheet_mc_stats <- function(wb, x, styles) {
  sheet <- rep_xl_add_sheet(wb, "mc_stats")
  rep_xl_title(wb, sheet, lbl("excel_export.titles.mc_stats"),
               paste(rep_mc_se_notes(x), collapse = " "), styles)
  st <- x$stats
  if (!is.data.frame(st)) st <- data.frame()
  df <- cbind(data.frame(label = vapply(st$kpi, kpi_label, "", USE.NAMES = FALSE),
                         stringsAsFactors = FALSE), st)
  start <- 4L
  rep_xl_write_df(wb, sheet, df, styles, start_row = start)
  units <- vapply(st$kpi, function(k) {
    u <- kpi_unit(k)
    if (is.na(u)) "EUR" else u
  }, "", USE.NAMES = FALSE)
  vcols <- match(intersect(c("mean", "sd", "se", "q05", "q10", "q25", "q50", "q75", "q90",
                             "q95", "es05", "expected_loss", "deterministic"), names(df)),
                 names(df))
  for (i in seq_len(nrow(df))) {
    openxlsx::addStyle(wb, sheet, rep_xl_unit_style(units[i], styles), rows = start + i,
                       cols = vcols, stack = TRUE)
  }
  pcols <- match(intersect(c("p_neg", "p_neg_se", "na_share"), names(df)), names(df))
  if (nrow(df) > 0L) {
    openxlsx::addStyle(wb, sheet, styles$pct, rows = start + seq_len(nrow(df)), cols = pcols,
                       gridExpand = TRUE, stack = TRUE)
  }
  openxlsx::setColWidths(wb, sheet, cols = 1L, widths = 42)
  openxlsx::freezePane(wb, sheet, firstActiveRow = start + 1L, firstActiveCol = 3L)
  invisible(sheet)
}

#' Blatt Kennzahlen je Lauf
#' @noRd
rep_xl_sheet_mc_runs <- function(wb, x, styles) {
  sheet <- rep_xl_add_sheet(wb, "mc_runs")
  rep_xl_title(wb, sheet, lbl("excel_export.titles.mc_runs"), NULL, styles)
  df <- x$kpis
  na <- x$kpi_na
  if (is.data.frame(na)) {
    for (cc in setdiff(names(na), "sim")) {
      if (any(!is.na(na[[cc]]))) df[[paste0("na_", cc)]] <- na[[cc]]
    }
  }
  hdr <- vapply(names(df), function(cc) {
    if (cc %in% c("sim", "block", "branch")) return(rep_xl_col_names(cc))
    if (startsWith(cc, "na_")) return(lbl("excel_export.columns.na_of",
                                          kpi = kpi_label(sub("^na_", "", cc))))
    kpi_label(cc)
  }, "", USE.NAMES = FALSE)
  rep_xl_write_df(wb, sheet, df, styles, start_row = 3L, header = hdr)
  openxlsx::freezePane(wb, sheet, firstActiveRow = 4L, firstActiveCol = 2L)
  invisible(sheet)
}

#' Blatt Pfad-Quantile (Fächerbänder)
#' @noRd
rep_xl_sheet_mc_bands <- function(wb, x, styles) {
  sheet <- rep_xl_add_sheet(wb, "mc_bands")
  rep_xl_title(wb, sheet, lbl("excel_export.titles.mc_bands"), NULL, styles)
  g <- x$grid
  parts <- lapply(names(x$bands %||% list()), function(k) {
    b <- x$bands[[k]]
    lab <- x$deterministic$ledger$rows$label[match(k, x$deterministic$ledger$rows$key)]
    d <- data.frame(row_key = k, label = if (length(lab) == 0L || is.na(lab)) k else lab,
                    stat = rownames(b) %||% paste0("s", seq_len(nrow(b))),
                    stringsAsFactors = FALSE)
    vals <- as.data.frame(b, optional = TRUE)
    names(vals) <- g$label
    cbind(d, vals)
  })
  df <- if (length(parts) > 0L) do.call(rbind, parts) else data.frame()
  hdr <- c(rep_xl_col_names(c("key", "label", "stat")), g$label)
  rep_xl_write_df(wb, sheet, df, styles, start_row = 3L, header = hdr[seq_len(ncol(df))])
  if (nrow(df) > 0L) {
    openxlsx::addStyle(wb, sheet, styles$eur, rows = 3L + seq_len(nrow(df)),
                       cols = 3L + seq_along(g$label), gridExpand = TRUE, stack = TRUE)
  }
  invisible(sheet)
}

#' Blatt Varianten (Kennzahlen je Variante, Spalten = Varianten)
#' @noRd
rep_xl_sheet_variants <- function(wb, x, styles) {
  sheet <- rep_xl_add_sheet(wb, "variants")
  rep_xl_title(wb, sheet, lbl("excel_export.titles.variants"), lbl("excel_export.notes.variants"),
               styles)
  kpis <- rep_cmp_kpis(x, head = FALSE)
  vars <- rep_comparison_variants(x)
  df <- data.frame(label = vapply(kpis, kpi_label, "", USE.NAMES = FALSE), kpi = kpis,
                   stringsAsFactors = FALSE)
  for (v in vars) df[[v]] <- vapply(kpis, function(k) rep_cmp_value(x, v, k), double(1))
  start <- 4L
  rep_xl_write_df(wb, sheet, df, styles, start_row = start,
                  header = c(rep_xl_col_names(c("label", "kpi")), vars))
  for (i in seq_along(kpis)) {
    u <- kpi_unit(kpis[i])
    openxlsx::addStyle(wb, sheet, rep_xl_unit_style(if (is.na(u)) "EUR" else u, styles),
                       rows = start + i, cols = 2L + seq_along(vars), stack = TRUE)
  }
  openxlsx::setColWidths(wb, sheet, cols = 1:2, widths = c(44, 30))
  invisible(sheet)
}

#' Blatt Differenzen (Vergleich gegen die Referenz)
#' @noRd
rep_xl_sheet_differences <- function(wb, x, styles) {
  sheet <- rep_xl_add_sheet(wb, "differences")
  rep_xl_title(wb, sheet, lbl("excel_export.titles.differences", baseline = x$baseline %||% ""),
               lbl("excel_export.notes.differences"), styles)
  ds <- x$diff_stats
  if (!is.data.frame(ds)) ds <- data.frame()
  df <- cbind(data.frame(label = vapply(ds$kpi, kpi_label, "", USE.NAMES = FALSE),
                         stringsAsFactors = FALSE), ds)
  start <- 4L
  rep_xl_write_df(wb, sheet, df, styles, start_row = start)
  if (nrow(df) > 0L) {
    vcols <- match(intersect(c("mean", "se", "q05", "q25", "q50", "q75", "q95"), names(df)),
                   names(df))
    for (i in seq_len(nrow(df))) {
      u <- kpi_unit(ds$kpi[i])
      openxlsx::addStyle(wb, sheet, rep_xl_unit_style(if (is.na(u)) "EUR" else u, styles),
                         rows = start + i, cols = vcols, stack = TRUE)
    }
    openxlsx::addStyle(wb, sheet, styles$pct, rows = start + seq_len(nrow(df)),
                       cols = match("prob_better", names(df)), stack = TRUE)
  }
  openxlsx::setColWidths(wb, sheet, cols = 1L, widths = 44)
  invisible(sheet)
}

#' Blatt Ampel (je Variante, Restriktionen)
#' @noRd
rep_xl_sheet_traffic <- function(wb, x, styles) {
  sheet <- rep_xl_add_sheet(wb, "traffic_light")
  rep_xl_title(wb, sheet, lbl("excel_export.titles.traffic_light"), NULL, styles)
  row <- 3L
  tl <- x$traffic_light
  if (is.data.frame(tl) && nrow(tl) > 0L) {
    level_lbl <- function(l) {
      vapply(l, function(e) lbl(paste0("report.traffic.level_", e), .default = e), "",
             USE.NAMES = FALSE)
    }
    tl$level <- level_lbl(tl$level)
    tl$stage1 <- level_lbl(tl$stage1)
    row <- rep_xl_write_df(wb, sheet, tl, styles, start_row = row)
  }
  r <- x$restrictions
  if (is.data.frame(r) && nrow(r) > 0L) {
    r$code <- vapply(r$code, rep_restriction_label, "", USE.NAMES = FALSE)
    rep_xl_write_df(wb, sheet, r, styles, start_row = row,
                    col_styles = list(prob = styles$pct))
  }
  openxlsx::setColWidths(wb, sheet, cols = 1:8, widths = 18)
  invisible(sheet)
}

#' Blätter der Sensitivitätsanalyse
#' @noRd
rep_xl_sheet_sensitivity <- function(wb, x, styles, params = FALSE) {
  sheet <- rep_xl_add_sheet(wb, if (params) "sensitivity_params" else "sensitivity")
  title_key <- if (params) "excel_export.titles.sensitivity_params" else
    "excel_export.titles.sensitivity"
  rep_xl_title(wb, sheet, lbl(title_key), NULL, styles)
  df <- as.data.frame(x, what = if (params) "params" else "results")
  if (!is.data.frame(df)) df <- data.frame()
  rep_xl_write_df(wb, sheet, df, styles, start_row = 3L)
  openxlsx::setColWidths(wb, sheet, cols = seq_len(max(1L, ncol(df))), widths = 18)
  invisible(sheet)
}

# ---------------------------------------------------------------------------------------------
# Exportierte Funktion
# ---------------------------------------------------------------------------------------------

#' Excel-Export
#'
#' Exportiert ein Ergebnis nach Excel mit Annahmen, Prüfungen und Saldo-Formel (Spec 00,
#' Abschnitte 7.10, 14 Nr. 25; Konzept 5.5). Die Arbeitsmappe enthält je nach Klasse:
#'
#' * `vofi_result`: Übersicht (`"overview"`), VoFi im Grob-Layout (`"vofi"`) und transponiert
#'   (`"vofi_transposed"`), Kennzahlen mit Restwertbezug, auch je Wohneinheit und je m², wenn
#'   `building.n_units` bzw. `building.living_area_m2` gesetzt sind (`"kpis"`), Zahlungsbuch mit
#'   Brutto, Netto und Umsatzsteuer (`"ledger"`), Annahmen mit Herkunft (`"assumptions"`),
#'   Prüfungen und Markierungen (`"checks"`).
#' * `vofi_mc_result`: zusätzlich MC-Statistik (`"mc_stats"`), Kennzahlen je Lauf
#'   (`"mc_runs"`) und Pfad-Quantile (`"mc_bands"`); VoFi und Zahlungsbuch des Basisfalls.
#' * `vofi_comparison`: Übersicht, Kennzahlen je Variante (`"variants"`), Vergleich gegen die
#'   Referenz (`"differences"`), Ampel (`"traffic_light"`), je Variante eine VoFi-Tabelle
#'   (`"vofi"`), Differenz-VoFi (`"diff_vofi"`), Kennzahlen, Zahlungsbuch, Annahmen und
#'   Prüfungen.
#' * `vofi_sensitivity`: Übersicht, Ergebnisse (`"sensitivity"`), Parameter
#'   (`"sensitivity_params"`).
#'
#' In den VoFi-Blättern stehen der Finanzierungssaldo (Summe aller zahlungswirksamen Zeilen der
#' Periode) und die Anzeige-Summen „Zahlungsfolge der Investition“ und „Zuschüsse“ als
#' Excel-Formeln (`SUM`), sodass die Nullsumme in Excel nachgeprüft werden kann. Beträge haben
#' das Format `#,##0.00` mit negativen Werten in Rot, Datumswerte `TT.MM.JJJJ`.
#'
#' @param x Ergebnisobjekt (`vofi_result`, `vofi_mc_result`, `vofi_comparison`,
#'   `vofi_sensitivity`).
#' @param path Zieldatei (`.xlsx`).
#' @param overwrite vorhandene Datei überschreiben.
#' @param sheets `NULL` (alle) oder Auswahl der Blätter (Codes wie oben).
#' @return `invisible(path)`.
#' @family Berichten
#' @examples
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' f <- tempfile(fileext = ".xlsx")
#' vofi_export_excel(res, f)
#' openxlsx::getSheetNames(f)
#' @export
vofi_export_excel <- function(x, path, overwrite = FALSE, sheets = NULL) {
  rep_check_class(x, "vofi_export_excel", c("vofi_result", "vofi_mc_result", "vofi_comparison",
                                            "vofi_sensitivity"))
  if (!utl_is_string(path) || !grepl("\\.xlsx$", path, ignore.case = TRUE)) {
    vofi_abort("excel_export.errors.path", path = utl_collapse(format(path)),
               .class = "vofi_error_input")
  }
  if (!utl_is_flag(overwrite)) {
    vofi_abort("core.arg_flag", arg = "overwrite", .class = "vofi_error_input")
  }
  if (file.exists(path) && !overwrite) {
    vofi_abort("excel_export.errors.exists", path = path, .class = "vofi_error_input")
  }
  if (!dir.exists(dirname(path))) {
    vofi_abort("excel_export.errors.dir", path = dirname(path), .class = "vofi_error_input")
  }
  avail <- rep_xl_codes(x)
  if (!is.null(sheets)) {
    if (!is.character(sheets) || anyNA(sheets) || length(sheets) == 0L) {
      vofi_abort("core.arg_character", arg = "sheets", .class = "vofi_error_input")
    }
    bad <- setdiff(sheets, rep_xl_all_codes())
    if (length(bad) > 0L) {
      vofi_abort("excel_export.errors.sheet_unknown", sheet = utl_collapse(bad),
                 choices = utl_collapse(avail),
                 suggestion = utl_suggest_text(bad[1L], rep_xl_all_codes()),
                 .class = "vofi_error_input")
    }
    na <- setdiff(sheets, avail)
    if (length(na) > 0L) {
      vofi_abort("excel_export.errors.sheet_unavailable", sheet = utl_collapse(na),
                 cls = rep_class_text(x), choices = utl_collapse(avail),
                 .class = "vofi_error_input")
    }
    avail <- avail[avail %in% sheets]
  }
  styles <- rep_xl_styles()
  wb <- openxlsx::createWorkbook(creator = "vofi")
  for (code in avail) {
    switch(code,
      overview = rep_xl_sheet_overview(wb, x, styles),
      vofi = rep_xl_sheet_vofi(wb, x, styles),
      vofi_transposed = rep_xl_sheet_vofi(wb, x, styles, transposed = TRUE),
      kpis = rep_xl_sheet_kpis(wb, x, styles),
      ledger = rep_xl_sheet_ledger(wb, x, styles),
      assumptions = rep_xl_sheet_assumptions(wb, x, styles),
      checks = rep_xl_sheet_checks(wb, x, styles),
      mc_stats = rep_xl_sheet_mc_stats(wb, x, styles),
      mc_runs = rep_xl_sheet_mc_runs(wb, x, styles),
      mc_bands = rep_xl_sheet_mc_bands(wb, x, styles),
      variants = rep_xl_sheet_variants(wb, x, styles),
      differences = rep_xl_sheet_differences(wb, x, styles),
      traffic_light = rep_xl_sheet_traffic(wb, x, styles),
      diff_vofi = rep_xl_sheet_diff_vofi(wb, x, styles),
      sensitivity = rep_xl_sheet_sensitivity(wb, x, styles),
      sensitivity_params = rep_xl_sheet_sensitivity(wb, x, styles, params = TRUE)
    )
  }
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  invisible(path)
}
