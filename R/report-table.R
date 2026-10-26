# VoFi-Tabelle und Zahlungsbuch (WS-H, Spec 00 Abschnitte 7.4-7.10, 13.5, 14 Nr. 22-23).
# Eigentuemer: WS-H. Inhalt: vofi_table() (Grob-Layout bzw. transponiert, detail "standard" mit
# Summen je Abschnitt und Kategorie bzw. "full" mit jeder Ledger-Zeile, Anzeige-Summen
# cf_project und grant_cash nach R-19, Ausblenden der Nullzeilen nach 7.7), vofi_ledger()
# (Long-/Wide-Format, Netto und USt nach 7.10) sowie interne Helfer, die die Ausgabefunktionen
# (Methoden, Excel-Export, Sichten, Grafiken) teilen. Die S3-Methoden der Klasse vofi_table
# stehen in R/methods-misc.R (2.4).

# ---------------------------------------------------------------------------------------------
# Quelle eines Ergebnisses (Ergebnis, Simulation, Vergleich)
# ---------------------------------------------------------------------------------------------

#' Abschnitte, deren zahlungswirksame Zeilen in den Finanzierungssaldo eingehen (7.5, 7.9)
#' @noRd
rep_balance_sections <- function() {
  c("project", "grants", "equity", "loans", "overdraft", "deposit", "tax")
}

#' Engine-Zeilen, die in `detail = "standard"` ausgeblendet werden, wenn sie in allen Läufen
#' null sind (7.7)
#' @noRd
rep_hideable_keys <- function() {
  c("odp_draw", "odp_repay", "odp_interest", "odp_balance", "dep_wht", "shortfall",
    "equity_call")
}

#' Klassenname für Meldungen
#' @noRd
rep_class_text <- function(x) utl_collapse(class(x))

#' Prüft die Klasse eines Ergebnisobjekts
#' @param x Objekt.
#' @param fun Name der aufrufenden Funktion.
#' @param classes zulässige Klassen.
#' @noRd
rep_check_class <- function(x, fun, classes) {
  if (!inherits(x, classes)) {
    vofi_abort("report.errors.not_result", fun = fun, cls = rep_class_text(x),
               allowed = utl_collapse(classes), .class = "vofi_error_input")
  }
  invisible(TRUE)
}

#' Ergebnis einer Variante aus einem Vergleich
#' @param x `vofi_comparison`.
#' @param variant Variante bzw. `NULL` (Referenz).
#' @return `vofi_result` bzw. `vofi_mc_result`.
#' @noRd
rep_comparison_result <- function(x, variant = NULL) {
  v <- variant %||% x$baseline %||% names(x$results)[1L]
  if (!utl_is_string(v) || !(v %in% names(x$results))) {
    vofi_abort("report.errors.variant_unknown", variant = utl_collapse(format(v)),
               suggestion = utl_suggest_text(as.character(v)[1L], names(x$results)),
               .class = "vofi_error_input")
  }
  x$results[[v]]
}

#' Varianten eines Vergleichs (Referenz zuerst)
#' @noRd
rep_comparison_variants <- function(x, variant = NULL) {
  all <- names(x$results)
  base <- x$baseline %||% all[1L]
  ord <- c(intersect(base, all), setdiff(all, base))
  if (is.null(variant)) return(ord)
  bad <- setdiff(variant, all)
  if (length(bad) > 0L) {
    vofi_abort("report.errors.variant_unknown", variant = utl_collapse(bad),
               suggestion = utl_suggest_text(bad[1L], all), .class = "vofi_error_input")
  }
  ord[ord %in% variant]
}

#' Deterministisches Ergebnis zu einem Ergebnisobjekt (Simulation: Basisfall)
#' @noRd
rep_det_result <- function(x) {
  if (inherits(x, "vofi_mc_result")) return(x$deterministic)
  x
}

#' Gespeicherter Lauf einer Simulation: Basisfall bzw. P5-, P50-, P95-Lauf (13.2)
#' @param x `vofi_mc_result`.
#' @param sim `"deterministic"`, `"p05"`, `"p50"` oder `"p95"`.
#' @param fun Name der aufrufenden Funktion.
#' @return `vofi_result`.
#' @noRd
rep_mc_run <- function(x, sim, fun) {
  choices <- c("deterministic", "p05", "p50", "p95")
  if (!utl_is_string(sim) || !(sim %in% choices)) {
    vofi_abort("report.errors.sim_mc", fun = fun, value = utl_collapse(format(sim)),
               choices = utl_collapse(choices), .class = "vofi_error_input")
  }
  res <- if (identical(sim, "deterministic")) x$deterministic else x$runs[[sim]]
  if (!inherits(res, "vofi_result")) {
    vofi_abort("report.errors.run_missing", run = sim, .class = "vofi_error_input")
  }
  res
}

#' Laufnummer eines gespeicherten Laufs in der Simulation (Basisfall: `NA`)
#' @noRd
rep_mc_run_index <- function(x, sim) {
  if (identical(sim, "deterministic")) return(NA_integer_)
  i <- (x$run_index %||% integer(0))[sim]
  if (length(i) == 1L && !is.na(i)) return(as.integer(i))
  as.integer(x$runs[[sim]]$meta$sim_index %||% NA_integer_)
}

#' Variante eines Einzelergebnisses prüfen (`NULL` oder die Variante des Ergebnisses)
#' @param variant angefragte Variante bzw. `NULL`.
#' @param v Variante des Ergebnisses.
#' @noRd
rep_check_variant <- function(variant, v) {
  if (!is.null(variant) && !identical(variant, v)) {
    vofi_abort("report.errors.variant_unknown", variant = utl_collapse(format(variant)),
               suggestion = utl_suggest_text(as.character(variant)[1L], v),
               .class = "vofi_error_input")
  }
  invisible(TRUE)
}

#' Lauf eines Ergebnisses für die Tabelle bestimmen
#'
#' `vofi_result`: Zeile `sim` des Ledgers. `vofi_mc_result`: `sim` als Laufnummer (aus dem
#' gespeicherten Ledger bei `store = "full"`, sonst über `vofi_sim()` nachgerechnet) oder als
#' `"deterministic"`, `"p05"`, `"p50"`, `"p95"` (Basisfall bzw. gespeicherte Läufe, 13.2).
#' `vofi_comparison`: Variante `variant` (Default Referenz).
#' @return Liste `ledger`, `grid`, `meta`, `spec`, `sim`, `variant`, `result`.
#' @noRd
rep_table_source <- function(x, sim = 1L, variant = NULL, fun = "vofi_table") {
  rep_check_class(x, fun, c("vofi_result", "vofi_mc_result", "vofi_comparison"))
  if (inherits(x, "vofi_comparison")) {
    v <- variant %||% x$baseline %||% names(x$results)[1L]
    out <- rep_table_source(rep_comparison_result(x, v), sim, NULL, fun)
    out$variant <- v
    return(out)
  }
  if (inherits(x, "vofi_mc_result")) {
    if (is.character(sim)) {
      res <- rep_mc_run(x, sim, fun)
      out <- rep_table_source(res, 1L, variant, fun)
      out$sim_label <- sim
      return(out)
    }
    n_sim <- as.integer(x$meta$n_sim %||% nrow(x$kpis))
    i <- utl_check_whole(sim, "sim", min = 1, max = n_sim)
    if (inherits(x$ledger, "vofi_ledger") && x$ledger$n >= i) {
      v <- x$meta$variant %||% "base"
      rep_check_variant(variant, v)
      return(list(ledger = x$ledger, grid = x$grid, meta = x$meta, spec = x$spec, sim = i,
                  variant = v, result = x, sim_label = i))
    }
    res <- vofi_sim(x, i)
    out <- rep_table_source(res, 1L, variant, fun)
    out$sim_label <- i
    return(out)
  }
  n <- x$ledger$n
  i <- utl_check_whole(sim, "sim", min = 1, max = n)
  v <- x$meta$variant %||% "base"
  rep_check_variant(variant, v)
  list(ledger = x$ledger, grid = x$grid, meta = x$meta, spec = x$spec, sim = i, variant = v,
       result = x, sim_label = x$meta$sim_index %||% i)
}

# ---------------------------------------------------------------------------------------------
# Zeilen der VoFi-Tabelle (7.8, 7.9)
# ---------------------------------------------------------------------------------------------

#' Sind alle Zeilen in allen Läufen null?
#' @noRd
rep_all_zero <- function(led, keys) {
  if (length(keys) == 0L) return(TRUE)
  tol <- vofi_tol$zero_abs
  all(vapply(led$values[keys], function(m) all(abs(m) <= tol), logical(1)))
}

#' Bezeichnung einer Einheit (EUR ohne Zusatz)
#' @noRd
rep_unit_label <- function(unit) {
  if (is.na(unit) || identical(unit, "EUR")) return(NA_character_)
  lbl(paste0("vocab.units.", unit), .default = unit)
}

#' Zeilenbezeichnung mit Einheit (nur bei Einheiten außer EUR)
#' @noRd
rep_label_unit <- function(label, unit) {
  u <- rep_unit_label(unit)
  if (is.na(u)) label else lbl("report.table.label_unit", label = label, unit = u)
}

#' Zeilendefinition der VoFi-Tabelle
#' @noRd
rep_row_def <- function(key, label, section, level, kind, members, category = NA_character_,
                        cash = TRUE, unit = "EUR", order = 0) {
  list(row_key = key, label = label, section = section, level = as.integer(level),
       kind = kind, members = as.character(members), category = category, cash = cash,
       unit = unit, order = order)
}

#' Zeilen der VoFi-Tabelle aus den Ledger-Metadaten
#'
#' `detail = "standard"`: Summen je (Abschnitt, Kategorie), Kredite je Baustein und Kategorie,
#' Bestände einzeln, Merkzeilen je Kategorie und Einheit (Restwertpfad zusätzlich je Basis,
#' steuerliche Nebenrechnung und Merkposten einzeln); Anzeige-Summen `cf_project` (immer) und
#' `grant_cash` (bei vorhandenen Zuschusszeilen) mit Unterzeilen der Ebene 1 (7.8, 7.9 Nr. 2,
#' Nr. 4). Ausgeblendet werden nur die in allen Läufen null gebliebenen Zeilen aus `odp_*`,
#' `dep_wht`, `shortfall`, `equity_call` (7.7); alle übrigen Zeilen, auch die
#' zahlungsunwirksamen Merkzeilen der Kredite (Tilgungszuschuss, Disagio, übernommene
#' Restschuld), bleiben stehen, damit die Tabelle stabil ist. `detail = "full"`: jede
#' Ledger-Zeile mit ihrer Bezeichnung.
#' @param led `vofi_ledger`.
#' @param detail `"standard"` oder `"full"`.
#' @param tax_module Name des Steuermoduls (Vermerk „nicht berücksichtigt“ bei `none`).
#' @return Liste von Zeilendefinitionen in Tabellenreihenfolge.
#' @noRd
rep_table_rows <- function(led, detail = "standard", tax_module = "none") {
  r <- led$rows
  r <- r[order(r$order, method = "radix"), , drop = FALSE]
  std <- identical(detail, "standard")
  acc <- new.env(parent = emptyenv())
  acc$out <- list()
  push <- function(def) acc$out[[length(acc$out) + 1L]] <- def
  keys_of <- function(sel) r$key[sel]
  sum_label <- function(sec, cat) {
    lbl(paste0("vocab.categories.", sec, ".", cat), .default = cat)
  }
  # Einzelzeilen (detail = "full" bzw. zahlungsunwirksame Merkzeilen)
  single <- function(i, level, kind = NULL) {
    k <- r$key[i]
    kd <- kind %||% if (isTRUE(r$cash[i])) "flow" else r$kind[i]
    rep_row_def(k, rep_label_unit(r$label[i], r$unit[i]), r$section[i], level, kd, k,
                r$category[i], isTRUE(r$cash[i]), r$unit[i], r$order[i])
  }
  hidden <- function(members) {
    std && length(members) > 0L && all(members %in% rep_hideable_keys()) &&
      rep_all_zero(led, members)
  }
  # Abschnitte project und grants mit Anzeige-Summe und Unterzeilen (R-19)
  for (sec in c("project", "grants")) {
    sel <- r$section == sec
    if (identical(sec, "grants") && !any(sel)) next
    cash_sel <- sel & r$cash
    agg_key <- if (identical(sec, "project")) "cf_project" else "grant_cash"
    push(rep_row_def(agg_key, lbl(paste0("core.rows.", agg_key)), sec, 0L, "sum",
                     keys_of(cash_sel), order = if (any(sel)) min(r$order[sel]) else 0))
    if (std) {
      cats <- unique(r$category[cash_sel])
      for (cat in cats) {
        m <- keys_of(cash_sel & r$category == cat)
        push(rep_row_def(paste0(sec, ".", cat), sum_label(sec, cat), sec, 1L, "flow", m, cat,
                         TRUE, "EUR", min(r$order[cash_sel & r$category == cat])))
      }
      for (i in which(sel & !r$cash)) push(single(i, 1L, "memo"))
    } else {
      for (i in which(sel)) push(single(i, 1L))
    }
  }
  # Eigenkapital, Kontokorrent, Geldanlage, Steuern: Summen je Kategorie bzw. Einzelzeilen
  for (sec in c("equity", "loans", "overdraft", "deposit", "tax")) {
    sel <- r$section == sec
    if (!any(sel)) next
    if (!std) {
      for (i in which(sel)) {
        def <- single(i, 0L)
        if (identical(sec, "tax") && identical(r$category[i], "income_tax")) {
          def$label <- rep_tax_label(def$label, tax_module)
        }
        push(def)
      }
      next
    }
    if (identical(sec, "loans")) {
      for (i in which(sel)) {
        push(single(i, 0L, if (isTRUE(r$cash[i])) NULL else "memo"))
      }
      next
    }
    cash_sel <- sel & r$cash
    for (cat in unique(r$category[cash_sel])) {
      csel <- cash_sel & r$category == cat
      m <- keys_of(csel)
      if (hidden(m)) next
      first <- which(csel)[1L]
      key <- if (identical(sec, "equity")) cat else r$key[first]
      label <- if (identical(sec, "equity")) sum_label(sec, cat) else r$label[first]
      if (identical(sec, "tax") && identical(cat, "income_tax")) {
        label <- rep_tax_label(label, tax_module)
      }
      push(rep_row_def(key, label, sec, 0L, "flow", m, cat, TRUE, "EUR", r$order[first]))
    }
    for (i in which(sel & !r$cash)) push(single(i, 0L, "memo"))
  }
  # Finanzierungssaldo und Bestände
  for (i in which(r$section == "check")) {
    push(rep_row_def(r$key[i], r$label[i], "check", 0L, "check", r$key[i], r$category[i],
                     FALSE, "EUR", r$order[i]))
  }
  for (i in which(r$section == "stocks")) {
    if (hidden(r$key[i])) next
    push(rep_row_def(r$key[i], r$label[i], "stocks", 0L, "stock", r$key[i], r$category[i],
                     FALSE, r$unit[i], r$order[i]))
  }
  # Merkzeilen (Marktwert, Mietersicht, Mengen, Steuer-Nebenrechnung)
  msel <- r$section == "memo"
  if (any(msel)) {
    if (!std) {
      for (i in which(msel)) push(single(i, 0L, "memo"))
    } else {
      rb <- vapply(r$extra, function(e) as.character(e$rv_basis %||% NA_character_), "")
      grp <- ifelse(r$category %in% c("tax_report", "aux_memo"), r$key,
                    paste(r$category, r$unit, ifelse(is.na(rb), "", rb), sep = "|"))
      for (g in unique(grp[msel])) {
        gsel <- msel & grp == g
        first <- which(gsel)[1L]
        cat <- r$category[first]
        if (cat %in% c("tax_report", "aux_memo")) {
          push(single(first, 0L, "memo"))
          next
        }
        label <- sum_label("memo", cat)
        key <- paste0("memo.", cat)
        if (!is.na(rb[first])) {
          label <- lbl("report.table.rv_basis", label = label,
                       basis = lbl(paste0("report.table.rv_basis_", rb[first])))
          key <- paste0(key, ".", rb[first])
        }
        if (!identical(r$unit[first], "EUR")) key <- paste0(key, ".", r$unit[first])
        push(rep_row_def(key, rep_label_unit(label, r$unit[first]), "memo", 0L, "memo",
                         keys_of(gsel), cat, FALSE, r$unit[first], r$order[first]))
      }
    }
  }
  acc$out
}

#' Bezeichnung der Ertragsteuerzeile mit Vermerk „nicht berücksichtigt“ (10.6, 7.7)
#' @noRd
rep_tax_label <- function(label, tax_module) {
  if (!identical(tax_module %||% "none", "none")) return(label)
  lbl("report.table.tax_none", label = label, note = lbl("core.rows.tax_note_none"))
}

#' Spalten (Zeitpunkte) einer Tabelle auswählen
#' @param grid `vofi_grid`.
#' @param periods `NULL`, Zeitpunkte t (0..T) oder Periodenbezeichnungen.
#' @return Spaltenindizes j = t + 1.
#' @noRd
rep_period_cols <- function(grid, periods = NULL) {
  n_t <- grid$T + 1L
  if (is.null(periods)) return(seq_len(n_t))
  if (is.character(periods)) {
    bad <- setdiff(periods, grid$label)
    if (length(bad) > 0L || anyNA(periods) || length(periods) == 0L) {
      vofi_abort("report.errors.periods", value = utl_collapse(bad),
                 suggestion = utl_suggest_text(bad[1L], grid$label),
                 .class = "vofi_error_input")
    }
    return(match(periods, grid$label))
  }
  if (!is.numeric(periods) || length(periods) == 0L || anyNA(periods) ||
        any(abs(periods - round(periods)) > 1e-9) || any(periods < 0) ||
        any(periods > grid$T)) {
    vofi_abort("report.errors.periods", value = utl_collapse(format(periods)),
               suggestion = "", .class = "vofi_error_input")
  }
  as.integer(round(periods)) + 1L
}

#' Werte der Tabellenzeilen eines Laufs
#' @return Matrix (Zeilen x Spalten).
#' @noRd
rep_row_values <- function(led, defs, sim, cols) {
  m <- matrix(0, length(defs), length(cols))
  for (i in seq_along(defs)) {
    keys <- defs[[i]]$members
    for (k in keys) m[i, ] <- m[i, ] + led$values[[k]][sim, cols]
  }
  m
}

# ---------------------------------------------------------------------------------------------
# Exportierte Funktionen
# ---------------------------------------------------------------------------------------------

#' VoFi-Tabelle
#'
#' Erzeugt die VoFi-Tabelle eines Laufs im Grob-Layout (Positionen in Zeilen, Perioden in
#' Spalten) bzw. transponiert (Spec 00, Abschnitte 7.8, 7.9, 13.5). Die Reihenfolge folgt dem
#' Grob-Layout: Zahlungsfolge der Investition (Anzeige-Summe `cf_project` mit den Kategorien als
#' Unterzeilen), Zuschüsse (`grant_cash`), Eigenkapital, je Kredit Aufnahme, Tilgung,
#' Schlusstilgung, Sondertilgung, Sollzinsen und Gebühren, Kontokorrent, Geldanlage, Steuern
#' (Ertragsteuern mit dem Vermerk „nicht berücksichtigt“, solange kein Steuermodul aktiv ist),
#' Finanzierungssaldo, Bestände (Kredite, Kontokorrent, Geldanlage, offene Steuer,
#' Bestandssaldo) und Merkzeilen. Mit und ohne Restwert: Der Restwert steht als eigene
#' Unterzeile der Zahlungsfolge; bei vorhandenen Restwertzeilen folgt dem Bestandssaldo die
#' Zeile „Bestandssaldo ohne Restwert“ mit dem Endwert ohne Restwert in T (Spec 00,
#' Abschnitte 9.4, 12.5).
#'
#' Mit `detail = "standard"` stehen Summen je Abschnitt und Kategorie (Kredite je Baustein);
#' Strafzins-Tranche, Abgeltungsteuer, Fehlbetrag und Nachschuss werden ausgeblendet, wenn sie
#' in allen Läufen null sind (Spec 00, Abschnitt 7.7); alle übrigen Zeilen, auch die Merkzeilen
#' der Kredite, bleiben stehen, damit die Tabelle stabil ist. Mit `detail = "full"` erscheint
#' jede Zeile des Zahlungsbuchs mit der Bezeichnung ihrer Komponente.
#'
#' Bei einer Simulation ist `sim` die Laufnummer (Werte aus dem gespeicherten Zahlungsbuch bei
#' `store = "full"`, sonst mit `vofi_sim()` nachgerechnet) oder einer der Werte
#' `"deterministic"` (Basisfall), `"p05"`, `"p50"`, `"p95"` (gespeicherte Läufe). Ohne Angabe
#' von `layout` wird ab mehr als 15 Perioden transponiert (Konzept 5.5).
#'
#' @param x Objekt der Klasse `vofi_result`, `vofi_mc_result` oder `vofi_comparison`.
#' @param sim Lauf (bei mehreren Läufen), siehe Details.
#' @param layout `"grob"` oder `"transposed"`.
#' @param detail `"standard"` (Summen je Kategorie) oder `"full"` (jede Ledger-Zeile).
#' @param periods `NULL` (alle) oder Auswahl der Perioden: Zeitpunkte t (0 bis T) oder
#'   Periodenbezeichnungen wie `"2027"`.
#' @param variant Variante (bei Vergleichen; Default: Referenzvariante).
#' @return Objekt der Klasse `vofi_table` mit `data` (Data Frame mit `row_key`, `label`,
#'   `section`, `level` und einer Spalte je Periode, benannt nach der Periodenbezeichnung),
#'   `layout`, `detail`, `periods` (Zeitpunkte t), `sim`, `variant`, `format`, `rows`
#'   (Zeilenmetadaten mit den zugehörigen Ledger-Schlüsseln), `columns` (Periodenangaben) und
#'   `meta`.
#' @family Berichten
#' @examples
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' tab <- vofi_table(res)
#' tab
#' vofi_table(res, layout = "transposed", detail = "full")
#' @export
vofi_table <- function(x, sim = 1L, layout = c("grob", "transposed"),
                       detail = c("standard", "full"), periods = NULL, variant = NULL) {
  auto_layout <- missing(layout)
  layout <- utl_match_arg(layout, c("grob", "transposed"), "layout")
  detail <- utl_match_arg(detail, c("standard", "full"), "detail")
  src <- rep_table_source(x, sim, variant, "vofi_table")
  cols <- rep_period_cols(src$grid, periods)
  if (auto_layout && length(cols) > 15L) layout <- "transposed"
  rep_build_table(src, layout, detail, cols)
}

#' Tabellenobjekt aus einer Quelle bauen
#' @noRd
rep_build_table <- function(src, layout, detail, cols) {
  led <- src$ledger
  grid <- src$grid
  defs <- rep_table_rows(led, detail, src$meta$tax_module %||% "none")
  vals <- rep_row_values(led, defs, src$sim, cols)
  ex <- rep_ex_rv_row(src, defs, vals, cols)
  defs <- ex$defs
  vals <- ex$vals
  labels <- grid$label[cols]
  data <- data.frame(
    row_key = vapply(defs, function(d) d$row_key, ""),
    label = vapply(defs, function(d) d$label, ""),
    section = vapply(defs, function(d) d$section, ""),
    level = vapply(defs, function(d) d$level, integer(1)),
    stringsAsFactors = FALSE
  )
  for (j in seq_along(cols)) data[[labels[j]]] <- vals[, j]
  rows <- data.frame(
    row_key = data$row_key,
    kind = vapply(defs, function(d) d$kind, ""),
    category = vapply(defs, function(d) as.character(d$category), ""),
    cash = vapply(defs, function(d) isTRUE(d$cash), logical(1)),
    unit = vapply(defs, function(d) as.character(d$unit), ""),
    stringsAsFactors = FALSE
  )
  rows$members <- I(lapply(defs, function(d) d$members))
  columns <- data.frame(t = grid$t[cols], label = labels, date_start = grid$date_start[cols],
                        date_end = grid$date_end[cols], year = grid$year[cols],
                        phase = grid$phase[cols], months = grid$months[cols],
                        stringsAsFactors = FALSE)
  meta <- src$meta %||% list()
  new_vofi_table(list(
    data = data, layout = layout, detail = detail, periods = grid$t[cols],
    sim = src$sim_label %||% src$sim, variant = src$variant,
    format = list(neg_red = TRUE, digits = 2), rows = rows, columns = columns,
    meta = list(title = src$spec$meta$title %||% meta$scenario_id %||% "",
                scenario_id = meta$scenario_id %||% NA_character_,
                mode = meta$mode %||% "deterministic",
                tax_module = meta$tax_module %||% "none",
                valuation_date = grid$valuation_date, end_date = grid$end_date,
                diff = FALSE)
  ))
}

#' Zeile „Bestandssaldo ohne Restwert“ (9.4, 12.5)
#'
#' Enthält das Zahlungsbuch Restwertzeilen (`residual_value`, `sale_cost`), folgt dem
#' Bestandssaldo eine Zeile mit denselben Werten bis T − 1 und in T dem Endwert ohne Restwert
#' (`terminal_value_ex_rv`, Terminalzustand nach 9.4). Ohne Restwertzeilen oder ohne diese
#' Kennzahl entfällt die Zeile.
#' @return Liste `defs`, `vals`.
#' @noRd
rep_ex_rv_row <- function(src, defs, vals, cols) {
  led <- src$ledger
  keep <- list(defs = defs, vals = vals)
  if (length(ledger_select(led, category = c("residual_value", "sale_cost"))) == 0L) {
    return(keep)
  }
  kp <- src$result$kpis
  ew <- if (is.data.frame(kp)) kp$terminal_value_ex_rv else NULL
  i <- match("net_position", vapply(defs, function(d) d$row_key, ""))
  if (is.null(ew) || is.na(i) || is.na(ew[src$sim])) return(keep)
  v <- vals[i, ]
  last <- which(cols == src$grid$T + 1L)
  v[last] <- ew[src$sim]
  def <- rep_row_def("net_position_ex_rv", lbl("report.table.net_position_ex_rv"), "stocks",
                     0L, "stock", "net_position", "net_position", FALSE, "EUR",
                     defs[[i]]$order + 0.5)
  list(defs = append(defs, list(def), after = i),
       vals = rbind(vals[seq_len(i), , drop = FALSE], v,
                    vals[-seq_len(i), , drop = FALSE]))
}

#' Differenz zweier VoFi-Tabellen (Differenz-VoFi zur Erklärung, Konzept 2.6)
#'
#' Für `vofi_compare()` (Feld `diff_table`, 13.3) und den Excel-Export: Zeilen beider Tabellen
#' über `row_key` vereint (Reihenfolge der Variante, fehlende Zeilen als 0), Werte Variante
#' minus Referenz. Nur bei identischen Perioden; sonst `NULL`.
#' @param a,b `vofi_table` der Variante bzw. der Referenz (gleiches Layout und Detail).
#' @param variant,baseline Namen für die Kopfzeile.
#' @return `vofi_table` bzw. `NULL`.
#' @noRd
rep_table_diff <- function(a, b, variant = a$variant, baseline = b$variant) {
  if (!identical(a$columns$label, b$columns$label) ||
        !identical(as.numeric(a$columns$date_end), as.numeric(b$columns$date_end))) {
    return(NULL)
  }
  pcols <- a$columns$label
  keys <- c(a$data$row_key, setdiff(b$data$row_key, a$data$row_key))
  pick <- function(tab, k) {
    i <- match(k, tab$data$row_key)
    if (is.na(i)) return(rep(0, length(pcols)))
    as.double(unlist(tab$data[i, pcols, drop = TRUE], use.names = FALSE))
  }
  meta_of <- function(k) {
    i <- match(k, a$data$row_key)
    if (!is.na(i)) return(list(tab = a, i = i))
    list(tab = b, i = match(k, b$data$row_key))
  }
  data <- do.call(rbind, lapply(keys, function(k) {
    m <- meta_of(k)
    d <- m$tab$data[m$i, c("row_key", "label", "section", "level"), drop = FALSE]
    v <- pick(a, k) - pick(b, k)
    for (j in seq_along(pcols)) d[[pcols[j]]] <- v[j]
    d
  }))
  rownames(data) <- NULL
  rows <- do.call(rbind, lapply(keys, function(k) {
    m <- meta_of(k)
    m$tab$rows[m$i, , drop = FALSE]
  }))
  rownames(rows) <- NULL
  out <- a
  out$data <- data
  out$rows <- rows
  out$variant <- lbl("report.table.diff_variant", variant = variant, baseline = baseline)
  out$meta$diff <- TRUE
  out
}

#' Zahlungsbuch
#'
#' Liefert das Zahlungsbuch (Ledger) im Long- oder Wide-Format mit allen Zeilenmerkmalen
#' (Spec 00, Abschnitte 7.4, 7.10). Long: eine Zeile je Ledger-Zeile, Lauf und Zeitpunkt mit
#' den Spalten `key`, `label`, `section`, `category`, `tax_category`, `cash`, `kind`, `unit`,
#' `source_id`, `source_type`, `asset_id`, `measure_id`, `vat_rate`, `sim`, `t`, `period`,
#' `date_end`, `year` und `value` (Bruttobetrag). Wide: eine Zeile je Ledger-Zeile und Lauf,
#' eine Spalte je Periode. Mit `vat = TRUE` werden Netto und Umsatzsteuer verlustfrei aus dem
#' Bruttobetrag und dem Umsatzsteuersatz der Zeile abgeleitet (`net = value / (1 + vat_rate)`,
#' `vat = value - net`): im Long-Format als Spalten `net` und `vat`, im Wide-Format als je
#' drei Zeilen mit `amount` = `"gross"`, `"net"`, `"vat"`. Bei Vergleichen werden die
#' Zahlungsbücher aller Varianten mit der Spalte `variant` untereinander gestellt (`sim` gilt für
#' jede Variante).
#'
#' Bei einer Simulation ist `sim` wie bei [vofi_table()] eine Auswahl von Laufnummern oder
#' einer der Werte `"deterministic"` (Basisfall), `"p05"`, `"p50"`, `"p95"` (gespeicherte
#' Läufe); die Spalte `sim` enthält die Laufnummer in der Simulation (beim Basisfall `NA`). Mit
#' gespeichertem Zahlungsbuch (`store = "full"`) stammen die Werte daraus, sonst werden die
#' gewählten Läufe mit `vofi_sim()` nachgerechnet; `sim = NULL` (alle Läufe) setzt das
#' gespeicherte Zahlungsbuch voraus.
#'
#' @param x Objekt der Klasse `vofi_result`, `vofi_mc_result` oder `vofi_comparison`.
#' @param format `"long"` oder `"wide"`.
#' @param sim `NULL` (alle Läufe), Laufnummern oder bei Simulationen `"deterministic"`,
#'   `"p05"`, `"p50"`, `"p95"`.
#' @param vat Netto und Umsatzsteuer getrennt ausgeben.
#' @return Data Frame.
#' @family Berichten
#' @examples
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' head(vofi_ledger(res))
#' vofi_ledger(res, format = "wide", vat = TRUE)[1:3, ]
#' @export
vofi_ledger <- function(x, format = c("long", "wide"), sim = NULL, vat = FALSE) {
  format <- utl_match_arg(format, c("long", "wide"), "format")
  if (!utl_is_flag(vat)) {
    vofi_abort("core.arg_flag", arg = "vat", .class = "vofi_error_input")
  }
  rep_check_class(x, "vofi_ledger", c("vofi_result", "vofi_mc_result", "vofi_comparison"))
  if (inherits(x, "vofi_comparison")) {
    parts <- lapply(rep_comparison_variants(x), function(v) {
      d <- vofi_ledger(x$results[[v]], format = format, sim = sim, vat = vat)
      cbind(data.frame(variant = rep(v, nrow(d)), stringsAsFactors = FALSE), d)
    })
    out <- do.call(rbind, parts)
    rownames(out) <- NULL
    return(out)
  }
  if (inherits(x, "vofi_mc_result")) return(rep_ledger_mc(x, format, sim, vat))
  sims <- rep_check_sims(sim, x$ledger$n)
  rep_ledger_frame(x$ledger, x$grid, sims, format, vat)
}

#' Zahlungsbuch einer Simulation (gespeichert, gespeicherter Lauf oder nachgerechnet)
#' @noRd
rep_ledger_mc <- function(x, format, sim, vat) {
  if (is.character(sim)) {
    res <- rep_mc_run(x, sim, "vofi_ledger")
    out <- rep_ledger_frame(res$ledger, res$grid, 1L, format, vat)
    out$sim <- rep(rep_mc_run_index(x, sim), nrow(out))
    return(out)
  }
  led <- x$ledger
  if (inherits(led, "vofi_ledger")) {
    return(rep_ledger_frame(led, x$grid, rep_check_sims(sim, led$n), format, vat))
  }
  if (is.null(sim)) {
    vofi_abort("report.errors.no_ledger", store = x$meta$store %||% "bands",
               .class = "vofi_error_input")
  }
  sims <- rep_check_sims(sim, as.integer(x$meta$n_sim %||% nrow(x$kpis)))
  # Läufe nachrechnen (identisch zum Batch, 14 Nr. 16) und ihre Zahlungsbücher (gleiche Zeilen
  # je Modell) zu einem Zahlungsbuch mit length(sims) Läufen zusammenführen
  runs <- lapply(sims, function(i) vofi_sim(x, i))
  first <- runs[[1L]]$ledger
  keys <- first$rows$key
  vals <- lapply(stats::setNames(keys, keys), function(k) {
    do.call(rbind, lapply(runs, function(r) r$ledger$values[[k]][1L, , drop = FALSE]))
  })
  led <- new_vofi_ledger(first$rows, vals, n = length(sims), T = first$T)
  out <- rep_ledger_frame(led, runs[[1L]]$grid, seq_along(sims), format, vat)
  out$sim <- sims[out$sim]
  out
}

#' Anzeige eines Laufs: Laufnummer bzw. Basisfall und gespeicherte Läufe der Simulation
#' @noRd
rep_sim_label <- function(sim) {
  if (is.character(sim)) {
    return(lbl(paste0("report.table.sim_", sim[1L]), .default = sim[1L]))
  }
  format(sim)
}

#' Laufnummern prüfen
#' @noRd
rep_check_sims <- function(sim, n) {
  if (is.null(sim)) return(seq_len(n))
  if (!is.numeric(sim) || length(sim) == 0L || anyNA(sim) ||
        any(abs(sim - round(sim)) > 1e-9) || any(sim < 1) || any(sim > n)) {
    vofi_abort("report.errors.sim_range", n = as.integer(n),
               value = utl_collapse(format(sim)), .class = "vofi_error_input")
  }
  as.integer(round(sim))
}

#' Zahlungsbuch als Data Frame
#' @noRd
rep_ledger_frame <- function(led, grid, sims, format, vat) {
  r <- led$rows
  meta_cols <- c("key", "label", "section", "category", "tax_category", "cash", "kind", "unit",
                 "source_id", "source_type", "asset_id", "measure_id", "vat_rate")
  meta <- r[, meta_cols, drop = FALSE]
  rownames(meta) <- NULL
  n_t <- grid$T + 1L
  nk <- nrow(r)
  ns <- length(sims)
  if (identical(format, "long")) {
    idx <- rep(seq_len(nk), each = ns * n_t)
    out <- meta[idx, , drop = FALSE]
    out$sim <- rep(rep(sims, times = n_t), times = nk)
    tt <- rep(rep(seq_len(n_t), each = ns), times = nk)
    out$t <- grid$t[tt]
    out$period <- grid$label[tt]
    out$date_end <- grid$date_end[tt]
    out$year <- grid$year[tt]
    out$value <- unlist(lapply(r$key, function(k) {
      as.vector(led$values[[k]][sims, , drop = FALSE])
    }), use.names = FALSE)
    if (vat) {
      out$net <- out$value / (1 + out$vat_rate)
      out$vat <- out$value - out$net
    }
    rownames(out) <- NULL
    return(out)
  }
  idx <- rep(seq_len(nk), each = ns)
  out <- meta[idx, , drop = FALSE]
  out$sim <- rep(sims, times = nk)
  vals <- do.call(rbind, lapply(r$key, function(k) led$values[[k]][sims, , drop = FALSE]))
  if (is.null(vals)) vals <- matrix(0, 0L, n_t)
  if (vat) {
    rate <- out$vat_rate
    net <- vals / (1 + rate)
    parts <- list(gross = vals, net = net, vat = vals - net)
    out3 <- out[rep(seq_len(nrow(out)), each = 3L), , drop = FALSE]
    out3$amount <- rep(c("gross", "net", "vat"), times = nrow(out))
    vals3 <- matrix(0, nrow(out3), n_t)
    for (a in seq_along(parts)) {
      vals3[seq(a, nrow(out3), by = 3L), ] <- parts[[a]]
    }
    out <- out3
    vals <- vals3
  }
  colnames(vals) <- grid$label
  out <- cbind(out, as.data.frame(vals, optional = TRUE))
  names(out)[(ncol(out) - n_t + 1L):ncol(out)] <- grid$label
  rownames(out) <- NULL
  out
}
