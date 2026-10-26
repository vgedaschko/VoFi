# S3-Methoden der Klasse vofi_result (WS-H, Spec 00 Abschnitte 13.1, 13.6).
# Eigentuemer: WS-H. Inhalt: print() (Kopf, Kopf-Kennzahlen mit Primaerkennzahl zuerst, gekuerzte
# VoFi-Tabelle, Hinweise, Pruefungen), summary() mit eigener Klasse summary_vofi_result (alle
# Kennzahlen nach Restwertbezug, Ampel, Markierungen, Hinweise), format() (VoFi-Tabelle als
# Zeichenmatrix), as.data.frame() (Zahlungsbuch bzw. Kennzahlen, long/wide), plot(); dazu die
# Hinweise (Steuern, Steuerwarnhinweis je Regime, Bestandsprojekte) und die Ampel im Basisfall,
# solange cmp_traffic_light() (WS-G) nicht vorhanden ist.

# ---------------------------------------------------------------------------------------------
# Kopf, Kennzahlen, Hinweise
# ---------------------------------------------------------------------------------------------

#' Bezeichnung eines Vokabularcodes (Enum) mit Rückfall auf den Code
#' @noRd
rep_enum_label <- function(enum, code) {
  if (is.null(code) || length(code) == 0L || is.na(code[1L])) return(fmt_num(NA))
  lbl(paste0("vocab.enums.", enum, ".", code[1L]), .default = as.character(code[1L]))
}

#' Kopfzeilen eines Ergebnisses
#' @noRd
rep_result_header <- function(x) {
  m <- x$meta
  g <- x$grid
  title <- x$spec$meta$title %||% m$scenario_id %||% ""
  mode <- m$mode %||% "deterministic"
  lines <- c(
    lbl("report.print.header", title = title, id = m$scenario_id %||% "",
        variant = m$variant %||% "base"),
    lbl("report.print.subheader", mode = lbl(paste0("report.print.mode_", mode)),
        start = g$valuation_date, end = g$end_date, T = g$T)
  )
  if (identical(mode, "mc")) {
    lines <- c(lines, lbl("report.print.sim_index", i = as.integer(m$sim_index %||% 1L),
                          n = as.integer(m$n_sim %||% 1L)))
  }
  report <- lbl(paste0("report.print.report_mode_", m$report_mode %||% "expert"),
                .default = m$report_mode %||% "")
  c(lines, lbl("report.print.perspective",
               perspective = rep_enum_label("perspective", m$perspective),
               regime = rep_enum_label("tax_regime", m$tax_regime), report = report))
}

#' Angezeigte Primärkennzahl mit Rückfall (12.3a)
#'
#' Eingestellte Primärkennzahl aus `meta$primary_kpi` (sonst `kpi_primary()`). Ist sie unter
#' `available` nicht vorhanden – bei Bestandsprojekten `delta_vs_reference`, die nur ein
#' Vergleich liefert –, wird `delta_terminal_value` gezeigt, mit dem Vermerk aus
#' `kpi_primary()` („enthält Bestandszahlungen“ bzw. „gegenüber Verkauf zum Stichtag“), sonst
#' die erste verfügbare Kennzahl.
#' @param x `vofi_result` bzw. `vofi_mc_result`.
#' @param available verfügbare Kennzahlen (Default: Spalten von `x$kpis`).
#' @return Liste `kpi` (angezeigte Kennzahl bzw. `NA`), `primary` (eingestellte
#'   Primärkennzahl), `fallback` (Rückfall verwendet), `note` (Label-Schlüssel des Vermerks bzw.
#'   `NA`).
#' @noRd
rep_primary_kpi <- function(x, available = NULL) {
  available <- available %||% setdiff(names(x$kpis), c("sim", "block", "branch"))
  prim <- kpi_primary(x$spec)
  primary <- x$meta$primary_kpi %||% prim$kpi
  if (primary %in% available) {
    return(list(kpi = primary, primary = primary, fallback = FALSE, note = NA_character_))
  }
  kpi <- if ("delta_terminal_value" %in% available) "delta_terminal_value" else
    if (length(available) > 0L) available[1L] else NA_character_
  note <- if (identical(kpi, "delta_terminal_value")) prim$note else NA_character_
  list(kpi = kpi, primary = primary, fallback = TRUE, note = note)
}

#' Vermerk zur Endwertdifferenz bei Bestandsprojekten als Satz (12.3a)
#' @param note Label-Schlüssel (`kpi_primary()$note`) bzw. `NA`.
#' @return Zeichenkette bzw. `character(0)`.
#' @noRd
rep_existing_note <- function(note) {
  if (is.null(note) || is.na(note)) return(character(0))
  lbl("report.notes.primary_existing", kpi = kpi_label("delta_terminal_value"), note = lbl(note))
}

#' Kopf-Kennzahlen eines Ergebnisses (Primärkennzahl zuerst, 12.3a)
#'
#' Auswahl nach Perspektive und Berichtsmodus; nur vorhandene Kennzahlen, ohne solche, die für
#' die Perspektive nicht definiert sind (`not_applicable_perspective`).
#' @noRd
rep_head_kpis <- function(x, sim = 1L) {
  nm <- names(x$kpis)
  prim <- kpi_primary(x$spec)
  primary <- rep_primary_kpi(x)$kpi
  sel <- c(primary, paste0(primary, "_ex_rv"), "terminal_value", "terminal_value_ex_rv",
           "terminal_value_opp", prim$return_kpi, paste0(prim$return_kpi, "_ex_rv"),
           prim$payback, paste0(prim$payback, "_ex_rv"), "payback_year",
           "monthly_burden_y1", "monthly_burden_avg10", "monthly_burden_construction",
           "burden_ratio_max", "monthly_net_cashflow_y1", "own_contribution",
           "warm_rent_change_prepost_y1", "dscr_min", "min_net_liquidity", "max_overdraft",
           "sum_equity_calls", "withdrawal_equivalent")
  sel <- unique(sel[sel %in% nm])
  na <- vapply(sel, function(k) as.character((x$kpi_na[[k]] %||% NA_character_)[sim]), "")
  sel[is.na(na) | na != "not_applicable_perspective"]
}

#' Kennzahlen als Zeilen „Bezeichnung  Wert“
#' @param keys Kennzahlspalten.
#' @noRd
rep_kpi_lines <- function(x, keys, sim = 1L, primary = NULL) {
  if (length(keys) == 0L) return(character(0))
  labels <- vapply(keys, function(k) {
    txt <- kpi_label(k)
    if (!is.null(primary) && identical(k, primary)) {
      txt <- paste(txt, lbl("report.print.primary"))
    }
    txt
  }, "", USE.NAMES = FALSE)
  vals <- vapply(keys, function(k) {
    rep_fmt_kpi(x$kpis[[k]][sim], kpi_unit(k), (x$kpi_na[[k]] %||% NA_character_)[sim])
  }, "", USE.NAMES = FALSE)
  w <- max(nchar(labels, type = "width"))
  paste0("  ", rep_pad(labels, w, FALSE), "  ", rep_align_values(vals))
}

#' Werte rechtsbündig ausrichten; NA-Texte („n. d. (…)“) bleiben linksbündig
#' @noRd
rep_align_values <- function(vals) {
  na <- startsWith(vals, fmt_num(NA))
  if (any(!na)) {
    w <- max(nchar(vals[!na], type = "width"))
    vals[!na] <- rep_pad(vals[!na], w, TRUE)
  }
  vals
}

#' Hinweise zu einem Ergebnis (Steuern, Steuerwarnhinweis, Bestandsprojekte, Markierungen)
#'
#' Ertragsteuern „nicht berücksichtigt“ bei `tax_none` (10.6); Steuerwarnhinweis
#' `report.tax_warning_<regime>` für Kleinvermieter und Kapitalgesellschaften ohne erweiterte
#' Kürzung (Spec 01 Teil A 1.6, Konzept 3.12); Hinweis zu Nebenerlösen steuerbefreiter
#' Genossenschaften (Spec 01 Teil B 3.9.3); Vermerk der Endwertdifferenz bei Bestandsprojekten
#' (12.3a); gesetzte Markierungen (9.8) und Vermerke aus `meta$notes`.
#' @return Zeichenvektor.
#' @noRd
rep_result_notes <- function(x, sim = 1L) {
  m <- x$meta
  notes <- character(0)
  if (identical(m$tax_module %||% "none", "none")) notes <- c(notes, lbl("report.notes.tax_none"))
  regime <- m$tax_regime %||% NA_character_
  key <- paste0("report.tax_warning_", regime)
  if (!is.na(regime) && lbl_has(key)) notes <- c(notes, lbl(key))
  if (identical(m$perspective, "wu_genossenschaft")) {
    q <- rep_coop_income_check(x)
    if (!is.null(q) && any(q$warning)) {
      i <- which(q$warning)[1L]
      notes <- c(notes, lbl("report.notes.coop_income", year = as.integer(q$year[i]),
                            share = q$share[i], threshold = q$threshold[i]))
    }
  }
  notes <- c(notes, rep_existing_note(kpi_primary(x$spec)$note))
  fl <- x$flags
  if (is.data.frame(fl) && nrow(fl) >= sim) {
    for (f in c("shortfall", "stopped", "limit_breach", "limit_cut", "reserve_used",
                "negative_amortization", "equity_call_over_savings", "arbitrage",
                "overdraft_threshold")) {
      v <- fl[[f]]
      if (!is.null(v) && isTRUE(as.logical(v[sim]))) {
        notes <- c(notes, lbl(paste0("report.flags.", f)))
      }
    }
  }
  c(notes, rep_note_text(m$notes %||% character(0)))
}

#' Ampel eines deterministischen Ergebnisses (12.9, Basis `base_only`)
#'
#' Vorrang: `x$traffic_light`, dann `cmp_traffic_light(x)` (WS-G, intern), sonst diese
#' Rückfallfassung nach 12.9: Stufe 1 `yellow`, wenn die Primärkennzahl im Basisfall positiv ist,
#' sonst `red`, mit Hinweis „keine Robustheitsprüfung“; Restwertregel (Vorzeichenwechsel ohne
#' Restwert, `rv_dependent`); Stufe 2 mit den Restriktionskennzahlen `restriction_<c>` für
#' `c` in `analysis.restrictions` (verletzt im Basisfall = K.-o.; `NA` = nicht prüfbar). Für
#' Bestandsprojekte (Primärkennzahl `delta_vs_reference`) gibt es die Ampel nur im Vergleich
#' (`NULL`).
#' @noRd
rep_traffic_light <- function(x, sim = 1L) {
  if (!is.null(x$traffic_light)) return(x$traffic_light)
  f <- get0("cmp_traffic_light", envir = asNamespace("vofi"), mode = "function",
            inherits = FALSE)
  if (is.function(f)) return(f(x))
  primary <- x$meta$primary_kpi %||% kpi_primary(x$spec)$kpi
  if (!(primary %in% names(x$kpis))) return(NULL)
  p <- as.double(x$kpis[[primary]][sim])
  p_ex <- as.double((x$kpis[[paste0(primary, "_ex_rv")]] %||% NA_real_)[sim])
  stage1 <- if (!is.na(p) && p > 0) "yellow" else "red"
  notes <- "report.traffic.no_robustness"
  rv_dep <- !is.na(p) && !is.na(p_ex) && ((p > 0) != (p_ex > 0))
  if (rv_dep) notes <- c(notes, "report.traffic.rv_dependent")
  codes <- as.character(unlist(x$spec$analysis$restrictions %||% character(0)))
  restr <- data.frame(code = codes, violated_base = rep(FALSE, length(codes)),
                      prob = rep(NA_real_, length(codes)), year = rep(NA_integer_, length(codes)),
                      value = rep(NA_real_, length(codes)),
                      threshold = rep(NA_real_, length(codes)),
                      ko = rep(FALSE, length(codes)), stringsAsFactors = FALSE)
  for (i in seq_along(codes)) {
    v <- (x$kpis[[paste0("restriction_", codes[i])]] %||% NA_real_)[sim]
    if (is.na(v)) {
      notes <- c(notes, lbl("report.traffic.restriction_unchecked",
                            code = rep_restriction_label(codes[i])))
    } else {
      restr$violated_base[i] <- v > 0.5
      restr$ko[i] <- v > 0.5
    }
  }
  level <- stage1
  if (any(restr$ko) && identical(level, "green")) level <- "yellow"
  list(level = level, stage1 = stage1, basis = "base_only", kpi = primary,
       rv_dependent = rv_dep, restrictions = restr, notes = notes)
}

#' Bezeichnung einer Restriktion (12.3, Codes aus `analysis.restrictions`)
#' @noRd
rep_restriction_label <- function(code) {
  lbl(paste0("report.traffic.restriction_", code), .default = code)
}

#' Zeilen der Ampel
#' @noRd
rep_traffic_lines <- function(tl) {
  if (is.null(tl)) return(character(0))
  level <- lbl(paste0("report.traffic.level_", tl$level), .default = tl$level)
  stage1 <- lbl(paste0("report.traffic.level_", tl$stage1 %||% tl$level),
                .default = tl$stage1 %||% "")
  basis <- lbl(paste0("report.traffic.basis_", tl$basis %||% "base_only"),
               .default = tl$basis %||% "")
  out <- lbl("report.traffic.line", level = level, stage1 = stage1, basis = basis)
  r <- tl$restrictions
  if (is.data.frame(r) && nrow(r) > 0L && any(r$ko)) {
    labs <- vapply(r$code[r$ko], rep_restriction_label, "")
    out <- c(out, lbl("report.traffic.ko", codes = utl_collapse(labs)))
  }
  c(out, rep_note_text(tl$notes %||% character(0)))
}

#' Gekürzte VoFi-Tabelle (Summen je Abschnitt, Finanzierungssaldo, Bestandssaldo)
#' @noRd
rep_short_table <- function(x, sim, max_periods) {
  led <- x$ledger
  g <- x$grid
  n_t <- g$T + 1L
  rows <- list()
  for (s in rep_balance_sections()) {
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
  m <- cbind(names(rows), do.call(rbind, cells))
  colnames(m) <- c("", head_lab)
  rownames(m) <- NULL
  m
}

# ---------------------------------------------------------------------------------------------
# Methoden
# ---------------------------------------------------------------------------------------------

#' VoFi-Ergebnis ausgeben
#'
#' Gibt Kopfdaten (Szenario, Variante, Lauf, Stichtag, Horizont, Perspektive), die
#' Kopf-Kennzahlen (Primärkennzahl zuerst, jeweils mit und ohne Restwert), eine gekürzte
#' VoFi-Tabelle (Summen je Abschnitt, Finanzierungssaldo, Bestandssaldo), Hinweise und das
#' Ergebnis der Prüfungen im deutschen Zahlenformat aus (Spec 00, Abschnitt 13.6). Die
#' vollständige Tabelle liefert [vofi_table()], alle Kennzahlen [summary()].
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
  sim <- utl_check_whole(sim, "sim", min = 1, max = x$ledger$n)
  cat(paste0(rep_result_header(x), "\n"), sep = "")
  cat("\n", lbl("report.print.kpi_header"), "\n", sep = "")
  pk <- rep_primary_kpi(x)
  lines <- rep_kpi_lines(x, rep_head_kpis(x, sim), sim, if (pk$fallback) NULL else pk$kpi)
  if (length(lines) > 0L) cat(paste0(lines, "\n"), sep = "")
  cat("\n", lbl("report.print.table_header"), "\n", sep = "")
  rep_cat_matrix(rep_short_table(x, sim, max_periods), left = 1L)
  notes <- rep_result_notes(x, sim)
  if (length(notes) > 0L) {
    cat("\n", lbl("report.print.notes_header"), "\n", sep = "")
    cat(paste0("  - ", notes, "\n"), sep = "")
  }
  inv_ok <- all(x$checks$ok)
  cat("\n", lbl(if (inv_ok) "report.print.checks_ok" else "report.print.checks_failed"), "\n",
      sep = "")
  invisible(x)
}

#' Zusammenfassung eines VoFi-Ergebnisses
#'
#' Liefert ein Objekt der Klasse `summary_vofi_result` mit Kopfdaten, Primärkennzahl, allen
#' Kennzahlen nach Restwertbezug (mit Restwert, ohne Restwert, unabhängig vom Restwert;
#' [vofi_kpis()]), Reihenkennzahlen (erstes Jahr), Ampel im Basisfall (Spec 00, Abschnitt
#' 12.9), gesetzten Markierungen, Hinweisen und Prüfungen (Spec 00, Abschnitt 13.6).
#'
#' @param object Objekt der Klasse `vofi_result`.
#' @param sim Lauf (Default 1).
#' @param ... nicht verwendet.
#' @return Objekt der Klasse `summary_vofi_result`.
#' @family Berichten
#' @examples
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' summary(res)
#' @export
summary.vofi_result <- function(object, sim = 1L, ...) {
  x <- object
  sim <- utl_check_whole(sim, "sim", min = 1, max = x$ledger$n)
  kp <- vofi_kpis(x)
  if ("sim" %in% names(kp)) kp <- kp[kp$sim == sim, setdiff(names(kp), "sim"), drop = FALSE]
  series <- lapply(names(x$kpi_series %||% list()), function(nm) {
    s <- x$kpi_series[[nm]]
    vals <- as.matrix(s$values)
    data.frame(kpi = nm, label = kpi_label(nm), unit = kpi_unit(nm),
               year = as.integer(s$years), value = as.double(vals[sim, ]),
               stringsAsFactors = FALSE)
  })
  series <- if (length(series) > 0L) do.call(rbind, series) else NULL
  primary <- x$meta$primary_kpi %||% kpi_primary(x$spec)$kpi
  # Haushaltsmodus: Ergebnis auf einen Blick in Worten (Konzept 1.4, Memo 07 Paragraf 5.4)
  plain <- if (identical(x$meta$report_mode, "household")) {
    attr(vofi_household_view(x), "summary")$text
  } else {
    character(0)
  }
  structure(list(
    header = rep_result_header(x), primary = primary, kpis = kp, series = series,
    plain = plain,
    traffic_light = rep_traffic_light(x, sim), notes = rep_result_notes(x, sim),
    checks = x$checks, checks_ok = all(x$checks$ok), sim = sim,
    opportunity_ew = x$opportunity$EW %||% NA_real_
  ), class = "summary_vofi_result")
}

#' Zusammenfassung eines VoFi-Ergebnisses ausgeben
#'
#' @param x Objekt der Klasse `summary_vofi_result`.
#' @param ... nicht verwendet.
#' @return `invisible(x)`.
#' @family Berichten
#' @export
print.summary_vofi_result <- function(x, ...) {
  cat(paste0(x$header, "\n"), sep = "")
  tl <- rep_traffic_lines(x$traffic_light)
  if (length(tl) > 0L) {
    cat("\n", lbl("report.traffic.header"), "\n", sep = "")
    cat(paste0("  ", tl, "\n"), sep = "")
  }
  if (length(x$plain) > 0L) {
    cat("\n", lbl("report.summary.plain_header"), "\n", sep = "")
    cat(paste0("  - ", x$plain, "\n"), sep = "")
  }
  kp <- x$kpis
  for (grp in c("with", "without", "independent", "unknown")) {
    d <- kp[kp$rv == grp, , drop = FALSE]
    if (nrow(d) == 0L) next
    cat("\n", lbl(paste0("report.summary.rv_", grp)), "\n", sep = "")
    labels <- ifelse(d$primary & d$kpi == d$base,
                     paste(d$label, lbl("report.print.primary")), d$label)
    vals <- rep_fmt_kpi(d$value, d$unit, d$na_reason)
    w <- max(nchar(labels, type = "width"))
    cat(paste0("  ", rep_pad(labels, w, FALSE), "  ", rep_align_values(vals), "\n"), sep = "")
  }
  if (!is.null(x$series) && nrow(x$series) > 0L) {
    cat("\n", lbl("report.summary.series_header"), "\n", sep = "")
    for (nm in unique(x$series$kpi)) {
      s <- x$series[x$series$kpi == nm, , drop = FALSE]
      s <- s[!is.na(s$value), , drop = FALSE]
      if (nrow(s) == 0L) next
      cat("  ", lbl("report.summary.series_line", label = s$label[1L],
                    year = as.integer(s$year[1L]),
                    value = rep_fmt_value(s$value[1L], s$unit[1L], 2),
                    last_year = as.integer(s$year[nrow(s)]),
                    last = rep_fmt_value(s$value[nrow(s)], s$unit[1L], 2)), "\n", sep = "")
    }
  }
  if (length(x$notes) > 0L) {
    cat("\n", lbl("report.print.notes_header"), "\n", sep = "")
    cat(paste0("  - ", x$notes, "\n"), sep = "")
  }
  ok_key <- if (isTRUE(x$checks_ok)) "report.print.checks_ok" else "report.print.checks_failed"
  cat("\n", lbl(ok_key), "\n", sep = "")
  invisible(x)
}

#' VoFi-Ergebnis formatieren
#'
#' Liefert die VoFi-Tabelle des Laufs als Zeichenmatrix im deutschen Zahlenformat
#' ([vofi_table()] und [format.vofi_table()]).
#'
#' @param x Objekt der Klasse `vofi_result`.
#' @param sim Lauf.
#' @param layout `"grob"` oder `"transposed"`.
#' @param detail `"standard"` oder `"full"`.
#' @param ... weitere Angaben an [format.vofi_table()].
#' @return Zeichenmatrix.
#' @family Berichten
#' @examples
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' format(res)
#' @export
format.vofi_result <- function(x, sim = 1L, layout = c("grob", "transposed"),
                               detail = c("standard", "full"), ...) {
  layout <- utl_match_arg(layout, c("grob", "transposed"), "layout")
  detail <- utl_match_arg(detail, c("standard", "full"), "detail")
  format(vofi_table(x, sim = sim, layout = layout, detail = detail), ...)
}

#' VoFi-Ergebnis als Data Frame
#'
#' @param x Objekt der Klasse `vofi_result`.
#' @param row.names,optional nicht verwendet (Kompatibilität mit [as.data.frame()]).
#' @param what `"ledger"` (Zahlungsbuch, [vofi_ledger()]) oder `"kpis"` (Kennzahlen).
#' @param format `"long"` oder `"wide"`: beim Zahlungsbuch wie [vofi_ledger()]; bei den
#'   Kennzahlen eine Zeile je Kennzahl (long, [vofi_kpis()]) bzw. eine Zeile je Lauf mit einer
#'   Spalte je Kennzahl (wide).
#' @param ... weitere Angaben an [vofi_ledger()] (z. B. `vat = TRUE`).
#' @return Data Frame.
#' @family Berichten
#' @examples
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' head(as.data.frame(res))
#' as.data.frame(res, what = "kpis", format = "wide")
#' @export
as.data.frame.vofi_result <- function(x, row.names = NULL, optional = FALSE, # nolint
                                      what = c("ledger", "kpis"), format = c("long", "wide"),
                                      ...) {
  what <- utl_match_arg(what, c("ledger", "kpis"), "what")
  format <- utl_match_arg(format, c("long", "wide"), "format")
  if (identical(what, "ledger")) return(vofi_ledger(x, format = format, ...))
  if (identical(format, "long")) return(vofi_kpis(x))
  out <- cbind(data.frame(sim = seq_len(nrow(x$kpis))), x$kpis)
  rownames(out) <- NULL
  out
}

#' Grafik eines VoFi-Ergebnisses
#'
#' Ruft [vofi_plot()] auf (Typen `"vermoegen"`, `"differenz"`, `"bestand"`, `"finanzierung"`,
#' `"zahlungen"`, `"belastung"`, `"warmmiete"`).
#'
#' @param x Objekt der Klasse `vofi_result`.
#' @param type Grafiktyp bzw. `NULL` (Vermögensverlauf).
#' @param ... weitere Angaben an [vofi_plot()].
#' @return ggplot-Objekt.
#' @family Berichten
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' plot(res)
#' @export
plot.vofi_result <- function(x, type = NULL, ...) {
  vofi_plot(x, type = type, ...)
}
