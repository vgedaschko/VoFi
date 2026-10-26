# S3-Methoden der Klasse vofi_mc_result (WS-H, Spec 00 Abschnitte 12.7, 13.2, 13.6).
# Eigentuemer: WS-H. Inhalt: print() (Statistik mit Standardfehler, Quantilen und
# deterministischem Wert), summary() mit Klasse summary_vofi_mc_result (alle Kennzahlen,
# Risikoaussagen in Worten, bedingte Statistik bei Entscheidungsknoten, Ampel), format(),
# as.data.frame() (what = kpis, inputs, features, bands, stats), quantile() und plot().

#' Kopfzeilen einer Simulation
#' @noRd
rep_mc_header <- function(x) {
  m <- x$meta
  title <- x$spec$meta$title %||% m$scenario_id %||% ""
  r <- as.integer(m$replicates %||% 1L)
  c(lbl("report.mc.header", title = title, id = m$scenario_id %||% "",
        variant = m$variant %||% "base"),
    lbl("report.mc.subheader", n = as.integer(m$n_sim %||% nrow(x$kpis)),
        seed = format(m$seed %||% NA), sampling = m$sampling %||% "", r = r,
        block = as.integer(m$block_size %||% NA_integer_)))
}

#' Primärkennzahl einer Simulation mit Rückfall (12.3a)
#'
#' Bei Bestandsprojekten ist die Primärkennzahl `delta_vs_reference`, die es nur im Vergleich
#' gibt; dann gilt `delta_terminal_value` mit Vermerk (`rep_primary_kpi()` über die Kennzahlen
#' der Statistik bzw. der Läufe).
#' @noRd
rep_mc_primary <- function(x) {
  st <- if (is.data.frame(x$stats)) x$stats$kpi else NULL
  rep_primary_kpi(x, st %||% setdiff(names(x$kpis), c("sim", "block", "branch")))
}

#' Hinweise zum Standardfehler (12.7: R < 10 „grob“, R = 1 „überschätzt bei LHS“)
#' @noRd
rep_mc_se_notes <- function(x) {
  r <- as.integer(x$meta$replicates %||% 1L)
  out <- character(0)
  if (r <= 1L) {
    out <- c(out, lbl("report.mc.se_single"))
  } else if (r < 10L) {
    out <- c(out, lbl("report.mc.se_rough", r = r))
  }
  st <- x$stats
  if (is.data.frame(st) && "converged" %in% names(st) && nrow(st) > 0L) {
    out <- c(out, lbl("report.mc.converged", count = sum(st$converged %in% TRUE),
                      n = nrow(st)))
  }
  out
}

#' Kennzahlen der Kurzausgabe (Primärkennzahl zuerst)
#' @noRd
rep_mc_head_kpis <- function(x) {
  st <- x$stats$kpi
  primary <- rep_mc_primary(x)$kpi
  sel <- c(primary, paste0(primary, "_ex_rv"), "terminal_value", "terminal_value_ex_rv",
           "terminal_value_opp", "roe_mirr", "roe_mirr_ex_rv", "payback_time",
           "monthly_burden_y1", "monthly_net_cashflow_y1", "warm_rent_change_prepost_y1",
           "min_net_liquidity", "max_overdraft", "sum_equity_calls", "flag_shortfall")
  sel <- unique(sel[sel %in% st])
  if (length(sel) == 0L) sel <- utils::head(st, 10L)
  sel
}

#' Statistiktabelle als Zeichenmatrix
#' @param x `vofi_mc_result`.
#' @param kpis Kennzahlen bzw. `NULL` (alle).
#' @noRd
rep_mc_stats_matrix <- function(x, kpis = NULL) {
  st <- x$stats
  if (!is.data.frame(st) || nrow(st) == 0L) return(NULL)
  if (!is.null(kpis)) st <- st[match(kpis, st$kpi), , drop = FALSE]
  st <- st[!is.na(st$kpi), , drop = FALSE]
  pk <- rep_mc_primary(x)
  primary <- if (pk$fallback) NA_character_ else pk$kpi
  units <- vapply(st$kpi, function(k) {
    u <- kpi_unit(k)
    if (is.na(u)) "EUR" else u
  }, "", USE.NAMES = FALSE)
  labels <- vapply(st$kpi, function(k) {
    txt <- kpi_label(k)
    if (identical(k, primary)) txt <- paste(txt, lbl("report.print.primary"))
    txt
  }, "", USE.NAMES = FALSE)
  fv <- function(v) {
    vapply(seq_along(v), function(i) rep_fmt_value(v[i], units[i], 0), "")
  }
  # 0/1-Kennzahlen: Mittel und SE als Anteil, Quantile als 0/1 (12.7)
  flag <- units == "flag"
  fq <- function(col) ifelse(flag, fmt_num(st[[col]], 0), fv(st[[col]]))
  fs <- function(col) ifelse(flag, fmt_pct(st[[col]], 1), fv(st[[col]]))
  m <- cbind(labels, fq("deterministic"), fs("mean"), fs("se"), fq("q05"), fq("q25"),
             fq("q50"), fq("q75"), fq("q95"), fmt_pct(st$p_neg, 1),
             fmt_pct(st$na_share, 1))
  if (nrow(st) == 1L) m <- matrix(m, nrow = 1L)
  colnames(m) <- c(lbl("report.mc.col_kpi"), lbl("report.mc.col_det"), lbl("report.mc.col_mean"),
                   lbl("report.mc.col_se"), lbl("report.mc.col_q05"), lbl("report.mc.col_q25"),
                   lbl("report.mc.col_median"), lbl("report.mc.col_q75"),
                   lbl("report.mc.col_q95"), lbl("report.mc.col_p_neg"), lbl("report.mc.col_na"))
  m
}

#' Simulationsergebnis ausgeben
#'
#' Gibt Kopfdaten (Szenario, Läufe, Seed, Verfahren, Replikate) und die Statistik der
#' wichtigsten Kennzahlen aus: deterministischer Wert (Basisfall), Mittelwert,
#' Replikat-Standardfehler, Quantile P5 bis P95, Anteil negativer Werte und NA-Anteil (Spec 00,
#' Abschnitte 12.7, 13.6), dazu Hinweise zum Standardfehler und zur Konvergenz. Bei
#' Bestandsprojekten ist die Primärkennzahl die Endwertdifferenz gegenüber der Referenz, die nur
#' ein Variantenvergleich liefert; gezeigt wird dann die Endwertdifferenz gegenüber der
#' Unterlassungsalternative mit dem Vermerk „enthält Bestandszahlungen“ (Spec 00, Abschnitt
#' 12.3a).
#'
#' @param x Objekt der Klasse `vofi_mc_result`.
#' @param ... nicht verwendet.
#' @return `invisible(x)`.
#' @family Berichten
#' @export
print.vofi_mc_result <- function(x, ...) {
  cat(paste0(rep_mc_header(x), "\n"), sep = "")
  m <- rep_mc_stats_matrix(x, rep_mc_head_kpis(x))
  cat("\n", lbl("report.mc.stats_header"), "\n", sep = "")
  if (is.null(m)) {
    cat(lbl("report.mc.no_stats"), "\n", sep = "")
  } else {
    rep_cat_matrix(m, left = 1L)
  }
  notes <- c(rep_existing_note(rep_mc_primary(x)$note), rep_mc_se_notes(x))
  if (length(notes) > 0L) cat("\n", paste0("  - ", notes, "\n"), sep = "")
  invisible(x)
}

#' Risikoaussagen in Worten zur Primärkennzahl (Konzept 4.5)
#'
#' Ohne `kpi` zur Primärkennzahl mit Rückfall nach `rep_mc_primary()`; beim Rückfall auf die
#' Endwertdifferenz eines Bestandsprojekts steht der Vermerk (12.3a) voran.
#' @noRd
rep_mc_risk_lines <- function(x, kpi = NULL) {
  st <- x$stats
  if (!is.data.frame(st) || nrow(st) == 0L) return(character(0))
  note <- character(0)
  if (is.null(kpi)) {
    pk <- rep_mc_primary(x)
    kpi <- pk$kpi
    note <- rep_existing_note(pk$note)
  }
  s <- st[st$kpi %in% kpi, , drop = FALSE]
  if (nrow(s) == 0L) return(character(0))
  s <- s[1L, , drop = FALSE]
  unit <- kpi_unit(kpi)
  if (is.na(unit)) unit <- "EUR"
  label <- kpi_label(kpi)
  k10 <- round(10 * (1 - s$p_neg))
  out <- lbl("report.mc.risk_positive", count = as.integer(k10), label = label)
  if (!is.null(s$p_neg_se) && !is.na(s$p_neg_se)) {
    out <- c(out, lbl("report.mc.risk_p_neg", p = s$p_neg, se = 100 * s$p_neg_se))
  }
  out <- c(out,
           lbl("report.mc.risk_range", lo = rep_fmt_value(s$q10, unit, 0),
               hi = rep_fmt_value(s$q90, unit, 0)),
           lbl("report.mc.risk_q05", value = rep_fmt_value(s$q05, unit, 0)),
           lbl("report.mc.risk_es05", value = rep_fmt_value(s$es05, unit, 0)),
           lbl("report.mc.risk_expected_loss", value = rep_fmt_value(s$expected_loss, unit, 0)))
  c(note, out)
}

#' Bedingte Statistik des Entscheidungsknotens für die Zusammenfassung (9.11)
#' @noRd
rep_mc_decision <- function(dec, pick) {
  if (is.null(dec)) return(NULL)
  list(funding_id = dec$funding_id, fallback_variant = dec$fallback_variant,
       p_approval = dec$p_approval, share_approved = dec$share_approved,
       approved = pick(dec$stats_approved), fallback = pick(dec$stats_fallback))
}

#' Zusammenfassung eines Simulationsergebnisses
#'
#' Liefert ein Objekt der Klasse `summary_vofi_mc_result` mit Kopfdaten, der Statistik aller
#' Kennzahlen, Risikoaussagen in Worten zur Primärkennzahl („In X von 10 simulierten Zukünften
#' …“, Verlustwahrscheinlichkeit mit MC-Fehler, 5-%-Quantil, Mittel der schlechtesten 5 %,
#' erwarteter Verlust; Konzept 4.5), der bedingten Statistik bei Entscheidungsknoten (9.11),
#' der Ampel und den Prüfungen (Spec 00, Abschnitte 12.7, 13.2).
#'
#' @param object Objekt der Klasse `vofi_mc_result`.
#' @param ... nicht verwendet.
#' @return Objekt der Klasse `summary_vofi_mc_result`.
#' @family Berichten
#' @export
summary.vofi_mc_result <- function(object, ...) {
  x <- object
  dec <- x$decision
  primary <- rep_mc_primary(x)$kpi
  pick <- function(s) if (is.data.frame(s)) s[s$kpi %in% primary, , drop = FALSE] else NULL
  structure(list(
    header = rep_mc_header(x), stats = rep_mc_stats_matrix(x), risk = rep_mc_risk_lines(x),
    se_notes = rep_mc_se_notes(x), traffic_light = x$traffic_light,
    decision = rep_mc_decision(dec, pick),
    checks = x$checks, checks_ok = !is.data.frame(x$checks) || all(x$checks$ok %in% TRUE),
    primary = primary
  ), class = "summary_vofi_mc_result")
}

#' Zusammenfassung eines Simulationsergebnisses ausgeben
#'
#' @param x Objekt der Klasse `summary_vofi_mc_result`.
#' @param ... nicht verwendet.
#' @return `invisible(x)`.
#' @family Berichten
#' @export
print.summary_vofi_mc_result <- function(x, ...) {
  cat(paste0(x$header, "\n"), sep = "")
  tl <- rep_traffic_lines(x$traffic_light)
  if (length(tl) > 0L) {
    cat("\n", lbl("report.traffic.header"), "\n", sep = "")
    cat(paste0("  ", tl, "\n"), sep = "")
  }
  if (length(x$risk) > 0L) {
    cat("\n", lbl("report.mc.risk_header"), "\n", sep = "")
    cat(paste0("  - ", x$risk, "\n"), sep = "")
  }
  if (!is.null(x$decision)) {
    d <- x$decision
    cat("\n", lbl("report.mc.decision_header", funding = d$funding_id %||% "",
                  fallback = d$fallback_variant %||% ""), "\n", sep = "")
    cat("  ", lbl("report.mc.decision_share", p = d$p_approval %||% NA_real_,
                  share = d$share_approved %||% NA_real_), "\n", sep = "")
    for (nm in c("approved", "fallback")) {
      s <- d[[nm]]
      if (is.data.frame(s) && nrow(s) > 0L) {
        cat("  ", lbl(paste0("report.mc.decision_", nm), mean = rep_fmt_value(s$mean[1L],
                                                                              "EUR", 0),
                      q05 = rep_fmt_value(s$q05[1L], "EUR", 0),
                      q95 = rep_fmt_value(s$q95[1L], "EUR", 0)), "\n", sep = "")
      }
    }
  }
  cat("\n", lbl("report.mc.stats_header_all"), "\n", sep = "")
  if (is.null(x$stats)) cat(lbl("report.mc.no_stats"), "\n", sep = "") else
    rep_cat_matrix(x$stats, left = 1L)
  if (length(x$se_notes) > 0L) cat("\n", paste0("  - ", x$se_notes, "\n"), sep = "")
  cat("\n", lbl(if (isTRUE(x$checks_ok)) "report.mc.checks_ok" else "report.mc.checks_failed"),
      "\n", sep = "")
  invisible(x)
}

#' Simulationsergebnis formatieren
#'
#' Liefert die Statistiktabelle aller Kennzahlen als Zeichenmatrix im deutschen Zahlenformat.
#'
#' @param x Objekt der Klasse `vofi_mc_result`.
#' @param kpis `NULL` (alle) oder Auswahl der Kennzahlen.
#' @param ... nicht verwendet.
#' @return Zeichenmatrix.
#' @family Berichten
#' @export
format.vofi_mc_result <- function(x, kpis = NULL, ...) {
  m <- rep_mc_stats_matrix(x, kpis)
  if (is.null(m)) m <- matrix(character(0), 0L, 0L)
  m
}

#' Simulationsergebnis als Data Frame
#'
#' @param x Objekt der Klasse `vofi_mc_result`.
#' @param row.names,optional nicht verwendet (Kompatibilität mit [as.data.frame()]).
#' @param what `"kpis"` (Kennzahlen je Lauf), `"inputs"` (statische Ziehungen je Lauf),
#'   `"features"` (Pfadmerkmale je Lauf), `"bands"` (Fächerbänder im Long-Format mit
#'   `row_key`, `stat`, `t`, `period`, `date_end`, `value`) oder `"stats"` (Statistik je
#'   Kennzahl).
#' @param ... nicht verwendet.
#' @return Data Frame.
#' @family Berichten
#' @export
as.data.frame.vofi_mc_result <- function(x, row.names = NULL, optional = FALSE, # nolint
                                         what = c("kpis", "inputs", "features", "bands",
                                                  "stats"), ...) {
  what <- utl_match_arg(what, c("kpis", "inputs", "features", "bands", "stats"), "what")
  if (!identical(what, "bands")) {
    out <- x[[what]]
    if (is.null(out)) out <- data.frame()
    return(out)
  }
  g <- x$grid
  parts <- lapply(names(x$bands %||% list()), function(k) {
    b <- x$bands[[k]]
    stats_names <- rownames(b) %||% paste0("s", seq_len(nrow(b)))
    data.frame(row_key = k, stat = rep(stats_names, times = ncol(b)),
               t = rep(g$t, each = nrow(b)), period = rep(g$label, each = nrow(b)),
               date_end = rep(g$date_end, each = nrow(b)), value = as.vector(b),
               stringsAsFactors = FALSE)
  })
  if (length(parts) == 0L) {
    return(data.frame(row_key = character(0), stat = character(0), t = integer(0),
                      period = character(0), date_end = as.Date(character(0)),
                      value = double(0), stringsAsFactors = FALSE))
  }
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

#' Quantile der Kennzahlen einer Simulation
#'
#' Empirische Quantile (`stats::quantile`, Typ 7) der Kennzahlen über die gültigen Läufe
#' (Spec 00, Abschnitt 12.7).
#'
#' @param x Objekt der Klasse `vofi_mc_result`.
#' @param probs Wahrscheinlichkeiten.
#' @param kpi `NULL` (alle Kennzahlen) oder Auswahl.
#' @param type Quantiltyp (Default 7).
#' @param ... nicht verwendet.
#' @return Matrix (Zeilen = Kennzahlen, Spalten = Quantile).
#' @family Berichten
#' @export
quantile.vofi_mc_result <- function(x, probs = c(0.05, 0.25, 0.5, 0.75, 0.95), kpi = NULL,
                                    type = 7L, ...) {
  if (!is.numeric(probs) || anyNA(probs) || any(probs < 0 | probs > 1)) {
    vofi_abort("report.errors.probs", .class = "vofi_error_input")
  }
  cols <- setdiff(names(x$kpis), c("sim", "block", "branch"))
  if (!is.null(kpi)) {
    bad <- setdiff(kpi, cols)
    if (length(bad) > 0L) {
      vofi_abort("kpi.errors.unknown", kpi = utl_collapse(bad),
                 suggestion = utl_suggest_text(bad[1L], cols), .class = "vofi_error_input")
    }
    cols <- kpi
  }
  m <- t(vapply(cols, function(k) {
    v <- as.double(x$kpis[[k]])
    v <- v[!is.na(v)]
    if (length(v) == 0L) return(rep(NA_real_, length(probs)))
    stats::quantile(v, probs, type = type, names = FALSE)
  }, numeric(length(probs))))
  if (length(probs) == 1L) m <- matrix(m, ncol = 1L)
  dimnames(m) <- list(cols, paste0(format(100 * probs, trim = TRUE), "%"))
  m
}

#' Grafik eines Simulationsergebnisses
#'
#' Ruft [vofi_plot()] auf (Typen `"verteilung"`, `"fan"`, `"cdf"`, `"konvergenz"`, `"streu"`,
#' `"tornado"`).
#'
#' @param x Objekt der Klasse `vofi_mc_result`.
#' @param type Grafiktyp bzw. `NULL` (Verteilung der Primärkennzahl).
#' @param ... weitere Angaben an [vofi_plot()].
#' @return ggplot-Objekt.
#' @family Berichten
#' @export
plot.vofi_mc_result <- function(x, type = NULL, ...) {
  vofi_plot(x, type = type, ...)
}
