# Grafiken (WS-H, Spec 00 Abschnitte 13.6, 14 Nr. 24; Konzept 5.5; Memo 07 Paragraf 5.3).
# Eigentuemer: WS-H. vofi_plot() erzeugt ggplot-Objekte (ggplot2 aus Suggests, Pruefung ueber
# requireNamespace): Ergebnis (Vermoegens- und Bestandsverlauf, Differenzvermoegen mit
# Amortisationsmarke, Bestaende, Finanzierungsstruktur, Zahlungsbloecke, monatliche Belastung,
# Warmmiete), Simulation (Verteilung, Faecher, Verteilungsfunktion, Konvergenz, Streuung,
# Tornado aus Rangkorrelationen), Vergleich (Endwerte, Differenz mit Wahrscheinlichkeit
# "besser als Referenz", Verteilungsfunktionen, Bestandssaldo, Belastung) und Sensitivitaet
# (Tornado, Spider, Balken). Farben: Okabe-Ito-Palette; Beschriftungen aus dem Label-Katalog.

# ---------------------------------------------------------------------------------------------
# Grundlagen
# ---------------------------------------------------------------------------------------------

#' Okabe-Ito-Palette (farbenblindfreundlich)
#' @noRd
rep_palette <- function(n = 8L) {
  pal <- c("#0072B2", "#E69F00", "#009E73", "#D55E00", "#56B4E9", "#CC79A7", "#F0E442",
           "#000000")
  rep_len(pal, n)
}

#' Ästhetik aus Spaltennamen (ohne globale Variablen, R CMD check)
#' @noRd
rep_aes <- function(...) {
  args <- lapply(list(...), as.name)
  do.call(ggplot2::aes, args)
}

#' Grundthema der Grafiken
#' @noRd
rep_theme <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom", plot.title.position = "plot")
}

#' Achsenbeschriftung im deutschen Zahlenformat
#' @noRd
rep_axis_num <- function(digits = 0) function(v) fmt_num(v, digits)

#' Achsenbeschriftung in Prozent
#' @noRd
rep_axis_pct <- function(v) fmt_pct(v, 0)

#' Diskrete Farbskala (Okabe-Ito)
#' @noRd
rep_scale_colour <- function(n, aesthetics = "colour", name = NULL) {
  ggplot2::scale_colour_manual(values = rep_palette(n), aesthetics = aesthetics, name = name)
}

#' Grafiktyp prüfen (Default: erster Typ)
#' @noRd
rep_plot_type <- function(type, choices, cls) {
  if (is.null(type)) return(choices[1L])
  if (!utl_is_string(type) || !(type %in% choices)) {
    vofi_abort("report.errors.plot_type", type = utl_collapse(format(type)), cls = cls,
               choices = utl_collapse(choices),
               suggestion = utl_suggest_text(as.character(type)[1L], choices),
               .class = "vofi_error_input")
  }
  type
}

#' Achse der Periodenenden eines Rasters
#' @noRd
rep_dates <- function(grid) grid$date_end

#' Kennzahl einer Simulation bzw. eines Vergleichs prüfen
#' @noRd
rep_check_kpi <- function(kpi, available) {
  if (!utl_is_string(kpi) || !(kpi %in% available)) {
    vofi_abort("report.errors.plot_kpi", kpi = utl_collapse(format(kpi)),
               suggestion = utl_suggest_text(as.character(kpi)[1L], available),
               .class = "vofi_error_input")
  }
  kpi
}

#' Fehlende Daten einer Grafik
#' @noRd
rep_plot_no_data <- function(type, what) {
  vofi_abort("report.errors.plot_data", type = type, what = what, .class = "vofi_error_input")
}

#' Achsenbeschriftung einer Kennzahl (nach Einheit)
#' @noRd
rep_kpi_scale <- function(kpi, axis = "y") {
  u <- kpi_unit(kpi)
  lab <- if (!is.na(u) && u %in% c("rate_pa", "share")) rep_axis_pct else rep_axis_num(0)
  if (identical(axis, "y")) ggplot2::scale_y_continuous(labels = lab) else
    ggplot2::scale_x_continuous(labels = lab)
}

#' Wert einer Kennzahl als Text für Untertitel
#' @noRd
rep_kpi_text <- function(kpi, v) {
  u <- kpi_unit(kpi)
  rep_fmt_value(v, if (is.na(u)) "EUR" else u, 0)
}

# ---------------------------------------------------------------------------------------------
# Exportierte Funktion
# ---------------------------------------------------------------------------------------------

#' Grafiken
#'
#' Grafiken zu Ergebnis, Simulation, Vergleich und Sensitivität (ggplot2 aus Suggests; Spec 00,
#' Abschnitte 13.6, 14 Nr. 24; Konzept 5.5). Farben nach der Okabe-Ito-Palette, Beschriftungen
#' deutsch, Zahlen im deutschen Format.
#'
#' Typen je Klasse (erster Typ = Default):
#' * `vofi_result`: `"vermoegen"` (Bestandssaldo, Vermögen mit Restwertpfad und
#'   Unterlassungsalternative je Periode), `"differenz"` (Vermögensdifferenz zur
#'   Unterlassungsalternative mit und ohne Restwert, Amortisationsmarke), `"bestand"`
#'   (Restschulden, Kontokorrent, Geldanlage), `"finanzierung"` (Finanzierungsstruktur:
#'   Mittelherkunft über den Horizont), `"zahlungen"` (gestapelte Ein- und Auszahlungen nach
#'   Kategorien je Periode), `"belastung"` (monatliche Belastung je Jahr bzw. monatlicher
#'   Cashflow, [vofi_household_view()]), `"warmmiete"` (Warmmiete vorher/nachher,
#'   [vofi_tenant_view()]). Zusatzargument `sim` (Lauf).
#' * `vofi_mc_result`: `"verteilung"` (Histogramm einer Kennzahl mit Anteil > 0), `"fan"`
#'   (Fächer der Pfad-Quantile einer Zeile, Argument `row_key`, Default `net_position`),
#'   `"cdf"` (empirische Verteilungsfunktion), `"konvergenz"` (laufender Mittelwert mit
#'   95-%-Band), `"streu"` (Kennzahl gegen eine Eingangsgröße, Argument `input`),
#'   `"tornado"` (Rangkorrelationen der Eingangsgrößen mit der Kennzahl). Zusatzargument `kpi`
#'   (Default: Primärkennzahl).
#' * `vofi_comparison`: `"endwert"` (Endwertdifferenz je Variante mit und ohne Restwert),
#'   `"differenz"` (Vergleichskennzahl gegen die Referenz mit Wahrscheinlichkeit „besser als
#'   Referenz“), `"cdf"` (Verteilungsfunktionen der Kennzahl je Variante), `"bestand"`
#'   (Bestandssaldo je Variante), `"belastung"` (monatliche Belastung bzw. Cashflow je Variante
#'   und Jahr). Zusatzargument `kpi`.
#' * `vofi_sensitivity`: `"tornado"`, `"spider"`, `"balken"` (globale Maße, Argument
#'   `measure`, Default `"spearman"`); Default nach der Methode der Analyse.
#'
#' @param x Ergebnisobjekt (`vofi_result`, `vofi_mc_result`, `vofi_comparison`,
#'   `vofi_sensitivity`).
#' @param type Grafiktyp (abhängig von der Klasse von `x`), `NULL` = Default.
#' @param ... weitere Angaben an die Grafikfunktion (`sim`, `kpi`, `row_key`, `input`, `bins`,
#'   `measure`, `n`).
#' @return ggplot-Objekt.
#' @family Berichten
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' vofi_plot(res)
#' vofi_plot(res, type = "zahlungen")
#' @export
vofi_plot <- function(x, type = NULL, ...) {
  utl_require("ggplot2", "vofi_plot")
  if (inherits(x, "vofi_comparison")) return(rep_plot_comparison(x, type, ...))
  if (inherits(x, "vofi_mc_result")) return(rep_plot_mc(x, type, ...))
  if (inherits(x, "vofi_sensitivity")) return(rep_plot_sensitivity(x, type, ...))
  rep_check_class(x, "vofi_plot",
                  c("vofi_result", "vofi_mc_result", "vofi_comparison", "vofi_sensitivity"))
  rep_plot_result(x, type, ...)
}

# ---------------------------------------------------------------------------------------------
# Ergebnis
# ---------------------------------------------------------------------------------------------

#' Grafiken eines Ergebnisses
#' @noRd
rep_plot_result <- function(x, type = NULL, sim = 1L, ...) {
  type <- rep_plot_type(type, c("vermoegen", "differenz", "bestand", "finanzierung",
                                "zahlungen", "belastung", "warmmiete"), "vofi_result")
  sim <- utl_check_whole(sim, "sim", min = 1, max = x$ledger$n)
  switch(type,
    vermoegen = rep_plot_wealth(x, sim),
    differenz = rep_plot_wealth_diff(x, sim),
    bestand = rep_plot_stocks(x, sim),
    finanzierung = rep_plot_financing(x, sim),
    zahlungen = rep_plot_flows(x, sim),
    belastung = rep_plot_burden(x),
    warmmiete = rep_plot_warm_rent(x)
  )
}

#' Vermögenspfade eines Laufs: BS, W (mit Restwertpfad), BS^U
#' @noRd
rep_wealth_paths <- function(x, sim) {
  led <- x$ledger
  core <- rep_core_of(x)
  core$ledger <- ledger_subset_sims(led, sim)
  core$n <- 1L
  core$stocks$BS <- led$values$net_position[sim, , drop = FALSE]
  ctx <- rep_ctx_of(x)
  bs <- as.double(core$stocks$BS[1L, ])
  w <- as.double(kpi_wealth(core, ctx)[1L, ])
  opp <- x$opportunity$BS
  opp <- if (is.null(opp)) rep(0, length(bs)) else as.double(opp[min(sim, nrow(opp)), ])
  has_rwp <- length(ledger_select(led, category = "residual_path")) > 0L
  list(bs = bs, bs_ex = rep_bs_ex_rv(x, bs, sim), w = w, opp = opp, has_rwp = has_rwp)
}

#' @noRd
rep_plot_wealth <- function(x, sim) {
  p <- rep_wealth_paths(x, sim)
  d <- rep_dates(x$grid)
  df <- data.frame(date = d, value = p$bs, series = lbl("core.rows.net_position"),
                   stringsAsFactors = FALSE)
  if (p$has_rwp) {
    df <- rbind(df, data.frame(date = d, value = p$w, series = lbl("report.plot.wealth_rv"),
                               stringsAsFactors = FALSE))
  }
  df <- rbind(df, data.frame(date = d, value = p$opp, series = lbl("report.plot.opportunity"),
                             stringsAsFactors = FALSE))
  df$series <- factor(df$series, levels = unique(df$series))
  ggplot2::ggplot(df, rep_aes(x = "date", y = "value", colour = "series")) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey60") +
    ggplot2::geom_line(linewidth = 0.9) + ggplot2::geom_point(size = 1.4) +
    ggplot2::scale_y_continuous(labels = rep_axis_num(0)) +
    rep_scale_colour(nlevels(df$series)) +
    ggplot2::labs(title = lbl("report.plot.title_vermoegen"), x = lbl("report.plot.x_date"),
                  y = lbl("report.plot.y_eur"), colour = NULL) +
    rep_theme()
}

#' @noRd
rep_plot_wealth_diff <- function(x, sim) {
  p <- rep_wealth_paths(x, sim)
  d <- rep_dates(x$grid)
  df <- rbind(
    data.frame(date = d, value = p$w - p$opp, series = lbl("report.plot.diff_rv"),
               stringsAsFactors = FALSE),
    data.frame(date = d, value = p$bs_ex - p$opp, series = lbl("report.plot.diff_ex_rv"),
               stringsAsFactors = FALSE)
  )
  df$series <- factor(df$series, levels = unique(df$series))
  g <- ggplot2::ggplot(df, rep_aes(x = "date", y = "value", colour = "series")) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey60") +
    ggplot2::geom_line(linewidth = 0.9) + ggplot2::geom_point(size = 1.4)
  pb <- (x$kpis$payback_time %||% NA_real_)[sim]
  sub <- NULL
  if (!is.na(pb)) {
    j <- which.min(abs(x$grid$tau - pb))
    mark <- data.frame(date = d[j])
    g <- g + ggplot2::geom_vline(data = mark, mapping = rep_aes(xintercept = "date"),
                                 linetype = "dashed", colour = rep_palette(4L)[4L])
    sub <- lbl("report.plot.payback", year = as.integer(x$grid$year[j]))
  } else {
    sub <- lbl("report.plot.no_payback")
  }
  g + ggplot2::scale_y_continuous(labels = rep_axis_num(0)) + rep_scale_colour(2L) +
    ggplot2::labs(title = lbl("report.plot.title_differenz"), subtitle = sub,
                  x = lbl("report.plot.x_date"), y = lbl("report.plot.y_eur"), colour = NULL) +
    rep_theme()
}

#' @noRd
rep_plot_stocks <- function(x, sim) {
  led <- x$ledger
  r <- led$rows
  keys <- r$key[r$section == "stocks" & r$category == "balance"]
  keys <- keys[!vapply(keys, function(k) rep_all_zero(led, k), logical(1))]
  if (length(keys) == 0L) rep_plot_no_data("bestand", lbl("core.sections.stocks"))
  d <- rep_dates(x$grid)
  df <- do.call(rbind, lapply(keys, function(k) {
    data.frame(date = d, value = as.double(led$values[[k]][sim, ]),
               series = r$label[match(k, r$key)], stringsAsFactors = FALSE)
  }))
  df$series <- factor(df$series, levels = unique(df$series))
  ggplot2::ggplot(df, rep_aes(x = "date", y = "value", colour = "series")) +
    ggplot2::geom_line(linewidth = 0.9) + ggplot2::geom_point(size = 1.2) +
    ggplot2::scale_y_continuous(labels = rep_axis_num(0)) +
    rep_scale_colour(nlevels(df$series)) +
    ggplot2::labs(title = lbl("report.plot.title_bestand"), x = lbl("report.plot.x_date"),
                  y = lbl("report.plot.y_eur"), colour = NULL) +
    rep_theme()
}

#' Mittelherkunft über den Horizont (positive Zuflüsse der Finanzierungsabschnitte)
#' @noRd
rep_financing_sources <- function(x, sim) {
  led <- x$ledger
  r <- led$rows
  tot <- function(keys) {
    if (length(keys) == 0L) return(0)
    sum(vapply(led$values[keys], function(m) sum(pmax(m[sim, ], 0)), double(1)))
  }
  out <- list()
  eq <- r$key[r$section == "equity" & r$category %in% c("equity_in", "equity_in_kind")]
  out[[lbl("report.plot.src_equity")]] <- tot(eq)
  calls <- r$key[r$section == "equity" & r$category %in% c("equity_call", "shortfall")]
  out[[lbl("report.plot.src_calls")]] <- tot(calls)
  out[[lbl("core.rows.grant_cash")]] <- tot(r$key[r$section == "grants" & r$cash])
  for (k in r$key[r$section == "loans" & r$category %in% c("draw", "assumed")]) {
    lab <- r$label[match(k, r$key)]
    out[[lab]] <- (out[[lab]] %||% 0) + tot(k)
  }
  out[[lbl("core.sections.overdraft")]] <- tot(r$key[r$section == "overdraft" &
                                                       r$category == "draw"])
  v <- unlist(out)
  v <- v[v > vofi_tol$zero_abs]
  data.frame(source = names(v), value = as.double(v), share = as.double(v) / sum(v),
             stringsAsFactors = FALSE)
}

#' @noRd
rep_plot_financing <- function(x, sim) {
  df <- rep_financing_sources(x, sim)
  if (nrow(df) == 0L) rep_plot_no_data("finanzierung", lbl("core.sections.loans"))
  df$source <- factor(df$source, levels = rev(df$source))
  df$text <- paste0(fmt_num(df$value, 0), " (", fmt_pct(df$share, 0), ")")
  ggplot2::ggplot(df, rep_aes(x = "value", y = "source", fill = "source")) +
    ggplot2::geom_col(width = 0.7, show.legend = FALSE) +
    ggplot2::geom_text(rep_aes(label = "text"), hjust = -0.05, size = 3.2) +
    ggplot2::scale_x_continuous(labels = rep_axis_num(0),
                                expand = ggplot2::expansion(mult = c(0, 0.3))) +
    ggplot2::scale_fill_manual(values = rep_palette(nrow(df))) +
    ggplot2::labs(title = lbl("report.plot.title_finanzierung"), x = lbl("report.plot.y_eur"),
                  y = NULL) +
    rep_theme()
}

#' @noRd
rep_plot_flows <- function(x, sim) {
  tab <- vofi_table(x, sim = sim, layout = "grob", detail = "standard")
  d <- tab$data
  rows <- tab$rows
  pcols <- tab$columns$label
  sel <- (d$section %in% c("project", "grants") & d$level == 1L & rows$kind == "flow")
  parts <- list()
  for (i in which(sel)) {
    parts[[length(parts) + 1L]] <- data.frame(
      period = pcols, value = as.double(unlist(d[i, pcols])), category = d$label[i],
      stringsAsFactors = FALSE
    )
  }
  led <- x$ledger
  ds <- function(cats, label) {
    keys <- ledger_select(led, section = "loans", category = cats, cash = TRUE)
    v <- if (length(keys) == 0L) rep(0, length(pcols)) else
      as.double(Reduce(`+`, lapply(led$values[keys], function(m) m[sim, ])))
    data.frame(period = pcols, value = v[tab$columns$t + 1L], category = label,
               stringsAsFactors = FALSE)
  }
  parts[[length(parts) + 1L]] <- ds(c("interest", "fees"), lbl("report.plot.flow_interest"))
  parts[[length(parts) + 1L]] <- ds(c("repay", "repay_balloon", "prepay"),
                                    lbl("report.plot.flow_repay"))
  df <- do.call(rbind, parts)
  df <- df[abs(df$value) > vofi_tol$zero_abs, , drop = FALSE]
  if (nrow(df) == 0L) rep_plot_no_data("zahlungen", lbl("core.rows.cf_project"))
  df$period <- factor(df$period, levels = pcols)
  df$category <- factor(df$category, levels = unique(df$category))
  ggplot2::ggplot(df, rep_aes(x = "period", y = "value", fill = "category")) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey60") +
    ggplot2::geom_col(width = 0.75) +
    ggplot2::scale_y_continuous(labels = rep_axis_num(0)) +
    rep_scale_colour(nlevels(df$category), aesthetics = "fill") +
    ggplot2::labs(title = lbl("report.plot.title_zahlungen"), x = lbl("report.table.period"),
                  y = lbl("report.plot.y_eur"), fill = NULL) +
    rep_theme()
}

#' @noRd
rep_plot_burden <- function(x) {
  hv <- vofi_household_view(x)
  owner <- identical(attr(hv, "perspective"), "selbstnutzer")
  hv$period <- ifelse(hv$phase == "construction", lbl("report.plot.construction"),
                      as.character(hv$year))
  levels_p <- unique(hv$period)
  if (owner) {
    comps <- c("interest", "repay", "fees", "energy", "energy_income", "maintenance",
               "operating", "other")
    df <- do.call(rbind, lapply(comps, function(cc) {
      data.frame(period = hv$period, value = hv[[cc]],
                 component = lbl(paste0("report.plot.burden_", cc)), stringsAsFactors = FALSE)
    }))
    if (any(hv$current_rent > 0, na.rm = TRUE)) {
      df <- rbind(df, data.frame(period = hv$period, value = hv$current_rent,
                                 component = lbl("report.plot.burden_current_rent"),
                                 stringsAsFactors = FALSE))
    }
    df <- df[!is.na(df$value) & abs(df$value) > vofi_tol$zero_abs, , drop = FALSE]
    if (nrow(df) == 0L) rep_plot_no_data("belastung", lbl("report.plot.title_belastung"))
    df$period <- factor(df$period, levels = levels_p)
    df$component <- factor(df$component, levels = unique(df$component))
    tot <- data.frame(period = factor(hv$period, levels = levels_p), value = hv$burden)
    return(
      ggplot2::ggplot(df, rep_aes(x = "period", y = "value", fill = "component")) +
        ggplot2::geom_col(width = 0.75) +
        ggplot2::geom_point(data = tot, mapping = rep_aes(x = "period", y = "value"),
                            inherit.aes = FALSE, shape = 18, size = 2.5) +
        ggplot2::scale_y_continuous(labels = rep_axis_num(0)) +
        rep_scale_colour(nlevels(df$component), aesthetics = "fill") +
        ggplot2::labs(title = lbl("report.plot.title_belastung"),
                      subtitle = lbl("report.plot.subtitle_belastung"),
                      x = lbl("report.plot.x_year"), y = lbl("report.plot.y_eur_month"),
                      fill = NULL) +
        rep_theme()
    )
  }
  df <- data.frame(period = factor(hv$period, levels = levels_p), value = hv$cashflow,
                   kind = ifelse(hv$cashflow >= 0, lbl("report.plot.surplus"),
                                 lbl("report.plot.subsidy")), stringsAsFactors = FALSE)
  ggplot2::ggplot(df, rep_aes(x = "period", y = "value", fill = "kind")) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey60") +
    ggplot2::geom_col(width = 0.75) +
    ggplot2::scale_y_continuous(labels = rep_axis_num(0)) +
    ggplot2::scale_fill_manual(values = stats::setNames(
      rep_palette(4L)[c(3L, 4L)], c(lbl("report.plot.surplus"), lbl("report.plot.subsidy"))
    )) +
    ggplot2::labs(title = lbl("report.plot.title_cashflow"), x = lbl("report.plot.x_year"),
                  y = lbl("report.plot.y_eur_month"), fill = NULL) +
    rep_theme()
}

#' @noRd
rep_plot_warm_rent <- function(x) {
  tv <- vofi_tenant_view(x)
  df <- rbind(
    data.frame(variant = tv$variant, year = tv$year, value = tv$warm_rent,
               series = lbl("report.plot.warm_rent_after"), stringsAsFactors = FALSE),
    data.frame(variant = tv$variant, year = tv$year, value = tv$warm_rent_pre,
               series = lbl("report.plot.warm_rent_before"), stringsAsFactors = FALSE)
  )
  df <- df[!is.na(df$value), , drop = FALSE]
  if (nrow(df) == 0L) rep_plot_no_data("warmmiete", lbl("vocab.na_reasons.no_tenant_data"))
  multi <- length(unique(df$variant)) > 1L
  df$series <- if (multi) paste(df$variant, df$series, sep = ": ") else df$series
  df$series <- factor(df$series, levels = unique(df$series))
  ggplot2::ggplot(df, rep_aes(x = "year", y = "value", colour = "series")) +
    ggplot2::geom_line(linewidth = 0.9) + ggplot2::geom_point(size = 1.4) +
    ggplot2::scale_y_continuous(labels = rep_axis_num(2)) +
    rep_scale_colour(nlevels(df$series)) +
    ggplot2::labs(title = lbl("report.plot.title_warmmiete"), x = lbl("report.plot.x_year"),
                  y = lbl("report.plot.y_eur_m2_month"), colour = NULL) +
    rep_theme()
}

# ---------------------------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------------------------

#' Grafiken einer Simulation
#' @noRd
rep_plot_mc <- function(x, type = NULL, kpi = NULL, row_key = "net_position", input = NULL,
                        bins = 30L, ...) {
  type <- rep_plot_type(type, c("verteilung", "fan", "cdf", "konvergenz", "streu", "tornado"),
                        "vofi_mc_result")
  if (identical(type, "fan")) return(rep_plot_fan(x, row_key))
  cols <- setdiff(names(x$kpis), c("sim", "block", "branch"))
  kpi <- rep_check_kpi(kpi %||% x$meta$primary_kpi %||% "delta_terminal_value", cols)
  v <- as.double(x$kpis[[kpi]])
  switch(type,
    verteilung = rep_plot_hist(x, kpi, v, bins),
    cdf = rep_plot_cdf_mc(x, kpi, v),
    konvergenz = rep_plot_convergence(kpi, v),
    streu = rep_plot_scatter(x, kpi, v, input),
    tornado = rep_plot_rank_tornado(x, kpi, v)
  )
}

#' Untertitel mit Anteil > 0, Basisfall und NA-Anteil
#' @noRd
rep_mc_subtitle <- function(x, kpi, v) {
  ok <- v[!is.na(v)]
  det <- (x$deterministic$kpis[[kpi]] %||% NA_real_)[1L]
  lbl("report.plot.mc_subtitle", p = if (length(ok) > 0L) mean(ok > 0) else NA_real_,
      det = rep_kpi_text(kpi, det), na = mean(is.na(v)), n = as.integer(length(ok)))
}

#' @noRd
rep_plot_hist <- function(x, kpi, v, bins) {
  df <- data.frame(value = v[!is.na(v)])
  if (nrow(df) == 0L) rep_plot_no_data("verteilung", kpi_label(kpi))
  det <- (x$deterministic$kpis[[kpi]] %||% NA_real_)[1L]
  marks <- data.frame(value = c(0, det, stats::median(df$value)),
                      mark = c(lbl("report.plot.mark_zero"), lbl("report.plot.mark_det"),
                               lbl("report.plot.mark_median")), stringsAsFactors = FALSE)
  marks <- marks[!is.na(marks$value), , drop = FALSE]
  marks$mark <- factor(marks$mark, levels = unique(marks$mark))
  ggplot2::ggplot(df, rep_aes(x = "value")) +
    ggplot2::geom_histogram(bins = bins, fill = rep_palette(1L), colour = "white") +
    ggplot2::geom_vline(data = marks, mapping = rep_aes(xintercept = "value",
                                                        linetype = "mark")) +
    rep_kpi_scale(kpi, "x") +
    ggplot2::labs(title = lbl("report.plot.title_verteilung", kpi = kpi_label(kpi)),
                  subtitle = rep_mc_subtitle(x, kpi, v), x = kpi_label(kpi),
                  y = lbl("report.plot.y_count"), linetype = NULL) +
    rep_theme()
}

#' @noRd
rep_plot_cdf_mc <- function(x, kpi, v) {
  df <- data.frame(value = v[!is.na(v)])
  if (nrow(df) == 0L) rep_plot_no_data("cdf", kpi_label(kpi))
  ggplot2::ggplot(df, rep_aes(x = "value")) +
    ggplot2::stat_ecdf(geom = "step", colour = rep_palette(1L), linewidth = 0.9) +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed", colour = "grey40") +
    rep_kpi_scale(kpi, "x") +
    ggplot2::scale_y_continuous(labels = rep_axis_pct) +
    ggplot2::labs(title = lbl("report.plot.title_cdf", kpi = kpi_label(kpi)),
                  subtitle = rep_mc_subtitle(x, kpi, v), x = kpi_label(kpi),
                  y = lbl("report.plot.y_prob")) +
    rep_theme()
}

#' Laufender Mittelwert mit 95-%-Band (naiver Standardfehler)
#' @noRd
rep_plot_convergence <- function(kpi, v) {
  ok <- !is.na(v)
  vv <- v[ok]
  if (length(vv) < 2L) rep_plot_no_data("konvergenz", kpi_label(kpi))
  k <- seq_along(vv)
  m <- cumsum(vv) / k
  s2 <- pmax(cumsum(vv^2) / k - m^2, 0) * k / pmax(k - 1, 1)
  half <- 1.96 * sqrt(s2 / k)
  df <- data.frame(n = k, mean = m, lo = m - half, hi = m + half)
  ggplot2::ggplot(df, rep_aes(x = "n", y = "mean")) +
    ggplot2::geom_ribbon(rep_aes(ymin = "lo", ymax = "hi"), fill = rep_palette(5L)[5L],
                         alpha = 0.35) +
    ggplot2::geom_line(colour = rep_palette(1L), linewidth = 0.8) +
    rep_kpi_scale(kpi, "y") +
    ggplot2::scale_x_continuous(labels = rep_axis_num(0)) +
    ggplot2::labs(title = lbl("report.plot.title_konvergenz", kpi = kpi_label(kpi)),
                  subtitle = lbl("report.plot.subtitle_konvergenz"),
                  x = lbl("report.plot.x_runs"), y = kpi_label(kpi)) +
    rep_theme()
}

#' Eingangsgrößen einer Simulation (Spalten außer sim)
#' @noRd
rep_mc_inputs <- function(x) {
  inp <- x$inputs
  if (!is.data.frame(inp)) return(NULL)
  cols <- setdiff(names(inp), c("sim", "block", "branch"))
  cols <- cols[vapply(cols, function(cc) is.numeric(inp[[cc]]), logical(1))]
  if (length(cols) == 0L) return(NULL)
  inp[, c(intersect("sim", names(inp)), cols), drop = FALSE]
}

#' @noRd
rep_plot_scatter <- function(x, kpi, v, input) {
  inp <- rep_mc_inputs(x)
  if (is.null(inp)) rep_plot_no_data("streu", lbl("report.plot.inputs"))
  cols <- setdiff(names(inp), "sim")
  input <- input %||% cols[1L]
  if (!utl_is_string(input) || !(input %in% cols)) {
    vofi_abort("report.errors.plot_input", input = utl_collapse(format(input)),
               suggestion = utl_suggest_text(as.character(input)[1L], cols),
               .class = "vofi_error_input")
  }
  xv <- if ("sim" %in% names(inp)) inp[[input]][match(x$kpis$sim, inp$sim)] else inp[[input]]
  df <- data.frame(input = as.double(xv), value = v)
  df <- df[!is.na(df$input) & !is.na(df$value), , drop = FALSE]
  ggplot2::ggplot(df, rep_aes(x = "input", y = "value")) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey60") +
    ggplot2::geom_point(alpha = 0.4, colour = rep_palette(1L), size = 1.2) +
    rep_kpi_scale(kpi, "y") +
    ggplot2::labs(title = lbl("report.plot.title_streu", kpi = kpi_label(kpi)),
                  x = input, y = kpi_label(kpi)) +
    rep_theme()
}

#' Rangkorrelationen (Spearman) der Eingangsgrößen mit der Kennzahl
#' @noRd
rep_rank_correlations <- function(x, v) {
  inp <- rep_mc_inputs(x)
  if (is.null(inp)) return(NULL)
  cols <- setdiff(names(inp), "sim")
  rows <- if ("sim" %in% names(inp)) match(x$kpis$sim, inp$sim) else seq_len(nrow(inp))
  rho <- vapply(cols, function(cc) {
    a <- as.double(inp[[cc]][rows])
    ok <- !is.na(a) & !is.na(v)
    if (sum(ok) < 3L || stats::sd(a[ok]) == 0 || stats::sd(v[ok]) == 0) return(NA_real_)
    stats::cor(a[ok], v[ok], method = "spearman")
  }, double(1))
  data.frame(input = cols, rho = as.double(rho), stringsAsFactors = FALSE)
}

#' @noRd
rep_plot_rank_tornado <- function(x, kpi, v) {
  rc <- rep_rank_correlations(x, v)
  if (is.null(rc) || all(is.na(rc$rho))) rep_plot_no_data("tornado", lbl("report.plot.inputs"))
  rc <- rc[!is.na(rc$rho), , drop = FALSE]
  rc <- rc[order(abs(rc$rho), method = "radix"), , drop = FALSE]
  rc$input <- factor(rc$input, levels = rc$input)
  rc$sign <- ifelse(rc$rho >= 0, lbl("report.plot.positive"), lbl("report.plot.negative"))
  ggplot2::ggplot(rc, rep_aes(x = "rho", y = "input", fill = "sign")) +
    ggplot2::geom_col(width = 0.7) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey40") +
    ggplot2::scale_x_continuous(labels = rep_axis_num(2), limits = c(-1, 1)) +
    ggplot2::scale_fill_manual(values = stats::setNames(
      rep_palette(4L)[c(1L, 4L)], c(lbl("report.plot.positive"), lbl("report.plot.negative"))
    )) +
    ggplot2::labs(title = lbl("report.plot.title_rank_tornado", kpi = kpi_label(kpi)),
                  x = lbl("report.plot.x_spearman"), y = NULL, fill = NULL) +
    rep_theme()
}

#' Fächerdiagramm aus den Pfad-Quantilen einer Zeile (13.2 `bands`)
#' @noRd
rep_plot_fan <- function(x, row_key) {
  b <- x$bands[[row_key]]
  if (!is.matrix(b)) {
    vofi_abort("report.errors.plot_band", row = utl_collapse(format(row_key)),
               keys = utl_collapse(names(x$bands %||% list())), .class = "vofi_error_input")
  }
  rn <- rownames(b) %||% character(0)
  qs <- rn[grepl("^q[0-9]+$", rn)]
  qv <- as.integer(sub("^q", "", qs))
  qs <- qs[order(qv)]
  qv <- sort(qv)
  d <- rep_dates(x$grid)
  g <- ggplot2::ggplot()
  n_q <- length(qs)
  alphas <- c(0.2, 0.35, 0.5)
  for (i in seq_len(n_q %/% 2L)) {
    lo <- qs[i]
    hi <- qs[n_q + 1L - i]
    band <- data.frame(date = d, lo = b[lo, ], hi = b[hi, ],
                       band = lbl("report.plot.band", lo = qv[i], hi = qv[n_q + 1L - i]),
                       stringsAsFactors = FALSE)
    g <- g + ggplot2::geom_ribbon(data = band, mapping = rep_aes(x = "date", ymin = "lo",
                                                                 ymax = "hi"),
                                  fill = rep_palette(1L), alpha = alphas[min(i, 3L)])
  }
  lines <- list()
  if (n_q %% 2L == 1L) {
    lines[[length(lines) + 1L]] <- data.frame(date = d, value = b[qs[(n_q + 1L) %/% 2L], ],
                                              series = lbl("report.plot.mark_median"),
                                              stringsAsFactors = FALSE)
  }
  if ("mean" %in% rn) {
    lines[[length(lines) + 1L]] <- data.frame(date = d, value = b["mean", ],
                                              series = lbl("report.plot.mark_mean"),
                                              stringsAsFactors = FALSE)
  }
  det <- x$deterministic$ledger$values[[row_key]]
  if (is.matrix(det)) {
    lines[[length(lines) + 1L]] <- data.frame(date = d, value = as.double(det[1L, ]),
                                              series = lbl("report.plot.mark_det"),
                                              stringsAsFactors = FALSE)
  }
  if (length(lines) > 0L) {
    ld <- do.call(rbind, lines)
    ld$series <- factor(ld$series, levels = unique(ld$series))
    g <- g + ggplot2::geom_line(data = ld, mapping = rep_aes(x = "date", y = "value",
                                                             linetype = "series"),
                                colour = "black", linewidth = 0.7)
  }
  label <- x$deterministic$ledger$rows$label[match(row_key,
                                                   x$deterministic$ledger$rows$key)]
  if (length(label) == 0L || is.na(label)) label <- row_key
  g + ggplot2::scale_y_continuous(labels = rep_axis_num(0)) +
    ggplot2::labs(title = lbl("report.plot.title_fan", row = label),
                  subtitle = lbl("report.plot.subtitle_fan",
                                 bands = utl_collapse(paste0(qv, " %"))),
                  x = lbl("report.plot.x_date"), y = lbl("report.plot.y_eur"),
                  linetype = NULL) +
    rep_theme()
}

# ---------------------------------------------------------------------------------------------
# Vergleich
# ---------------------------------------------------------------------------------------------

#' Grafiken eines Vergleichs
#' @noRd
rep_plot_comparison <- function(x, type = NULL, kpi = NULL, bins = 30L, ...) {
  type <- rep_plot_type(type, c("endwert", "differenz", "cdf", "bestand", "belastung"),
                        "vofi_comparison")
  switch(type,
    endwert = rep_plot_cmp_terminal(x),
    differenz = rep_plot_cmp_diff(x, kpi, bins),
    cdf = rep_plot_cmp_cdf(x, kpi),
    bestand = rep_plot_cmp_stocks(x),
    belastung = rep_plot_cmp_burden(x)
  )
}

#' Wahrscheinlichkeit „besser als Referenz“ je Variante als Text
#' @noRd
rep_prob_better_text <- function(x, kpi = "delta_vs_reference") {
  ds <- x$diff_stats
  if (!is.data.frame(ds) || nrow(ds) == 0L) return(NULL)
  ds <- ds[ds$kpi == kpi, , drop = FALSE]
  if (nrow(ds) == 0L) return(NULL)
  utl_collapse(vapply(seq_len(nrow(ds)), function(i) {
    lbl("report.plot.prob_better", variant = ds$variant[i], baseline = x$baseline %||% "",
        p = ds$prob_better[i])
  }, ""), "; ")
}

#' @noRd
rep_plot_cmp_terminal <- function(x) {
  vars <- rep_comparison_variants(x)
  base_res <- rep_det_result(x$results[[x$baseline]] %||% x$results[[1L]])
  primary <- base_res$meta$primary_kpi %||% "delta_terminal_value"
  kpi <- if (primary %in% x$kpi_table$kpi) primary else "delta_terminal_value"
  rows <- list()
  for (v in vars) {
    for (sfx in c("", "_ex_rv")) {
      k <- paste0(kpi, sfx)
      val <- rep_cmp_value(x, v, k)
      st <- x$results[[v]]$stats
      lo <- hi <- NA_real_
      if (is.data.frame(st) && k %in% st$kpi) {
        lo <- st$q05[st$kpi == k]
        hi <- st$q95[st$kpi == k]
      }
      view <- if (nzchar(sfx)) lbl("report.plot.ex_rv") else lbl("report.plot.with_rv")
      rows[[length(rows) + 1L]] <- data.frame(variant = v, value = val, lo = lo, hi = hi,
                                              view = view, stringsAsFactors = FALSE)
    }
  }
  df <- do.call(rbind, rows)
  df <- df[!is.na(df$value), , drop = FALSE]
  if (nrow(df) == 0L) rep_plot_no_data("endwert", kpi_label(kpi))
  df$variant <- factor(df$variant, levels = vars)
  df$view <- factor(df$view, levels = unique(df$view))
  g <- ggplot2::ggplot(df, rep_aes(x = "variant", y = "value", fill = "view")) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey60") +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.8), width = 0.7)
  if (any(!is.na(df$lo))) {
    g <- g + ggplot2::geom_errorbar(rep_aes(ymin = "lo", ymax = "hi"),
                                    position = ggplot2::position_dodge(width = 0.8),
                                    width = 0.25, na.rm = TRUE)
  }
  g + ggplot2::scale_y_continuous(labels = rep_axis_num(0)) +
    rep_scale_colour(nlevels(df$view), aesthetics = "fill") +
    ggplot2::labs(title = lbl("report.plot.title_endwert", kpi = kpi_label(kpi)),
                  subtitle = rep_prob_better_text(x), x = lbl("report.compare.col_variant"),
                  y = lbl("report.plot.y_eur"), fill = NULL) +
    rep_theme()
}

#' @noRd
rep_plot_cmp_diff <- function(x, kpi, bins) {
  kpi <- kpi %||% "delta_vs_reference"
  m <- (x$differences %||% list())[[kpi]]
  if (!is.matrix(m)) {
    rep_check_kpi(kpi, names(x$differences %||% list()))
  }
  vars <- colnames(m) %||% x$variants
  df <- data.frame(variant = rep(vars, each = nrow(m)), value = as.vector(m),
                   stringsAsFactors = FALSE)
  df <- df[!is.na(df$value), , drop = FALSE]
  if (nrow(df) == 0L) rep_plot_no_data("differenz", kpi_label(kpi))
  df$variant <- factor(df$variant, levels = vars)
  sub <- rep_prob_better_text(x, kpi)
  if (nrow(m) <= 1L) {
    df$text <- vapply(df$value, function(v) rep_kpi_text(kpi, v), "")
    g <- ggplot2::ggplot(df, rep_aes(x = "variant", y = "value", fill = "variant")) +
      ggplot2::geom_hline(yintercept = 0, colour = "grey60") +
      ggplot2::geom_col(width = 0.6, show.legend = FALSE) +
      ggplot2::geom_text(rep_aes(label = "text"), vjust = -0.4, size = 3.2) +
      rep_kpi_scale(kpi, "y") +
      rep_scale_colour(length(vars), aesthetics = "fill") +
      ggplot2::labs(x = lbl("report.compare.col_variant"), y = kpi_label(kpi))
  } else {
    g <- ggplot2::ggplot(df, rep_aes(x = "value", fill = "variant")) +
      ggplot2::geom_histogram(bins = bins, colour = "white", alpha = 0.8,
                              position = "identity") +
      ggplot2::geom_vline(xintercept = 0, linetype = "dashed") +
      ggplot2::facet_wrap("variant", ncol = 1L) +
      rep_kpi_scale(kpi, "x") +
      rep_scale_colour(length(vars), aesthetics = "fill") +
      ggplot2::labs(x = kpi_label(kpi), y = lbl("report.plot.y_count"), fill = NULL)
  }
  g + ggplot2::labs(title = lbl("report.plot.title_cmp_diff", kpi = kpi_label(kpi),
                                baseline = x$baseline %||% ""), subtitle = sub) +
    rep_theme()
}

#' @noRd
rep_plot_cmp_cdf <- function(x, kpi) {
  vars <- rep_comparison_variants(x)
  base_res <- rep_det_result(x$results[[x$baseline]] %||% x$results[[1L]])
  kpi <- kpi %||% base_res$meta$primary_kpi %||% "delta_terminal_value"
  if (identical(kpi, "delta_vs_reference")) kpi <- "delta_terminal_value"
  parts <- lapply(vars, function(v) {
    r <- x$results[[v]]
    if (!(kpi %in% names(r$kpis))) return(NULL)
    vals <- as.double(r$kpis[[kpi]])
    data.frame(variant = v, value = vals[!is.na(vals)], stringsAsFactors = FALSE)
  })
  df <- do.call(rbind, parts)
  if (is.null(df) || nrow(df) == 0L) rep_plot_no_data("cdf", kpi_label(kpi))
  df$variant <- factor(df$variant, levels = vars)
  ggplot2::ggplot(df, rep_aes(x = "value", colour = "variant")) +
    ggplot2::stat_ecdf(geom = "step", linewidth = 0.9, pad = TRUE) +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed", colour = "grey40") +
    rep_kpi_scale(kpi, "x") +
    ggplot2::scale_y_continuous(labels = rep_axis_pct) +
    rep_scale_colour(length(vars)) +
    ggplot2::labs(title = lbl("report.plot.title_cdf", kpi = kpi_label(kpi)),
                  subtitle = rep_prob_better_text(x), x = kpi_label(kpi),
                  y = lbl("report.plot.y_prob"), colour = NULL) +
    rep_theme()
}

#' Bestandssaldo je Variante (Simulation: Median der Bänder, sonst Basisfall)
#' @noRd
rep_plot_cmp_stocks <- function(x) {
  vars <- rep_comparison_variants(x)
  parts <- lapply(vars, function(v) {
    r <- x$results[[v]]
    vals <- NULL
    if (inherits(r, "vofi_mc_result") && is.matrix(r$bands$net_position) &&
          "q50" %in% rownames(r$bands$net_position)) {
      vals <- r$bands$net_position["q50", ]
    } else {
      d <- rep_det_result(r)
      vals <- d$ledger$values$net_position[1L, ]
    }
    data.frame(variant = v, date = rep_dates(r$grid), value = as.double(vals),
               stringsAsFactors = FALSE)
  })
  df <- do.call(rbind, parts)
  df$variant <- factor(df$variant, levels = vars)
  ggplot2::ggplot(df, rep_aes(x = "date", y = "value", colour = "variant")) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey60") +
    ggplot2::geom_line(linewidth = 0.9) + ggplot2::geom_point(size = 1.2) +
    ggplot2::scale_y_continuous(labels = rep_axis_num(0)) +
    rep_scale_colour(length(vars)) +
    ggplot2::labs(title = lbl("report.plot.title_cmp_bestand"), x = lbl("report.plot.x_date"),
                  y = lbl("report.plot.y_eur"), colour = NULL) +
    rep_theme()
}

#' @noRd
rep_plot_cmp_burden <- function(x) {
  hv <- vofi_household_view(x)
  owner <- identical(attr(hv, "perspective"), "selbstnutzer")
  col <- if (owner) "burden" else "cashflow"
  df <- data.frame(variant = hv$variant, year = hv$year, value = hv[[col]],
                   phase = hv$phase, stringsAsFactors = FALSE)
  df <- df[df$phase == "operation" & !is.na(df$value), , drop = FALSE]
  if (nrow(df) == 0L) rep_plot_no_data("belastung", lbl("report.plot.title_belastung"))
  df$variant <- factor(df$variant, levels = unique(hv$variant))
  title <- if (owner) lbl("report.plot.title_belastung") else lbl("report.plot.title_cashflow")
  ggplot2::ggplot(df, rep_aes(x = "year", y = "value", colour = "variant")) +
    ggplot2::geom_line(linewidth = 0.9) + ggplot2::geom_point(size = 1.4) +
    ggplot2::scale_y_continuous(labels = rep_axis_num(0)) +
    rep_scale_colour(nlevels(df$variant)) +
    ggplot2::labs(title = title, x = lbl("report.plot.x_year"),
                  y = lbl("report.plot.y_eur_month"), colour = NULL) +
    rep_theme()
}

# ---------------------------------------------------------------------------------------------
# Sensitivität
# ---------------------------------------------------------------------------------------------

#' Grafiken einer Sensitivitätsanalyse
#' @noRd
rep_plot_sensitivity <- function(x, type = NULL, measure = "spearman", n = 15L, ...) {
  default <- switch(x$method, spider = "spider", global = "balken", "tornado")
  choices <- unique(c(default, "tornado", "spider", "balken"))
  type <- rep_plot_type(type, choices, "vofi_sensitivity")
  unit <- rep_sens_unit(x)
  kpi_txt <- if (utl_is_string(x$kpi)) kpi_label(x$kpi) else ""
  ylab <- function(v) rep_fmt_value(v, unit, 0)
  if (identical(type, "tornado")) {
    r <- x$results
    if (!is.data.frame(r) || nrow(r) == 0L) rep_plot_no_data("tornado", "results")
    r <- r[order(abs(r$swing), method = "radix"), , drop = FALSE]
    r <- utils::tail(r, n)
    lab <- rep_sens_param_labels(x, r$param)
    base <- x$base_value %||% NA_real_
    if (is.na(base)) base <- (r$kpi_low + r$kpi_high) / 2
    df <- rbind(
      data.frame(param = lab, from = base, to = r$kpi_low, end = lbl("report.plot.low"),
                 stringsAsFactors = FALSE),
      data.frame(param = lab, from = base, to = r$kpi_high, end = lbl("report.plot.high"),
                 stringsAsFactors = FALSE)
    )
    df$param <- factor(df$param, levels = unique(lab))
    df$end <- factor(df$end, levels = c(lbl("report.plot.low"), lbl("report.plot.high")))
    return(
      ggplot2::ggplot(df, rep_aes(x = "from", xend = "to", y = "param", yend = "param",
                                  colour = "end")) +
        ggplot2::geom_segment(linewidth = 6) +
        ggplot2::geom_vline(xintercept = base[1L], colour = "grey30") +
        ggplot2::scale_x_continuous(labels = ylab) +
        rep_scale_colour(2L) +
        ggplot2::labs(title = lbl("report.plot.title_tornado", kpi = kpi_txt),
                      x = kpi_txt, y = NULL, colour = NULL) +
        rep_theme()
    )
  }
  if (identical(type, "spider")) {
    s <- x$spider
    if (!is.data.frame(s) || nrow(s) == 0L) rep_plot_no_data("spider", "spider")
    s$param <- rep_sens_param_labels(x, s$param)
    s$param <- factor(s$param, levels = unique(s$param))
    return(
      ggplot2::ggplot(s, rep_aes(x = "step", y = "kpi", colour = "param")) +
        ggplot2::geom_line(linewidth = 0.9) + ggplot2::geom_point(size = 1.4) +
        ggplot2::scale_y_continuous(labels = ylab) +
        rep_scale_colour(nlevels(s$param)) +
        ggplot2::labs(title = lbl("report.plot.title_spider", kpi = kpi_txt),
                      x = lbl("report.sensitivity.step"), y = kpi_txt, colour = NULL) +
        rep_theme()
    )
  }
  g <- x$global
  if (!is.data.frame(g) || nrow(g) == 0L) rep_plot_no_data("balken", "global")
  if (!utl_is_string(measure) || !(measure %in% names(g))) {
    rep_plot_no_data("balken", utl_collapse(format(measure)))
  }
  g <- g[order(abs(g[[measure]]), method = "radix"), , drop = FALSE]
  g <- utils::tail(g, n)
  df <- data.frame(input = factor(g$input, levels = g$input), value = g[[measure]])
  ggplot2::ggplot(df, rep_aes(x = "value", y = "input")) +
    ggplot2::geom_col(fill = rep_palette(1L), width = 0.7) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey40") +
    ggplot2::scale_x_continuous(labels = rep_axis_num(2)) +
    ggplot2::labs(title = lbl("report.plot.title_balken", kpi = kpi_txt,
                              measure = lbl(paste0("report.sensitivity.", measure),
                                            .default = measure)),
                  x = lbl(paste0("report.sensitivity.", measure), .default = measure),
                  y = NULL) +
    rep_theme()
}
