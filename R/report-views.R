# Nutzerkosten- und Haushaltssicht (WS-H, Spec 00 Abschnitte 12.2, 12.3, 12.6, 14 Nr. 27-28;
# Spec 01 Teil B 3.9.3, 3.10.4; Konzept 1.4, 2.5; Memo 07 Paragraf 5).
# Eigentuemer: WS-H. Inhalt: vofi_tenant_view() (Warmmiete je Jahr und Variante, vorher/nachher
# und gegenueber der Referenz, Hinweis zu Nebenerloesen steuerbefreiter Genossenschaften),
# vofi_household_view() (Selbstnutzer: monatliche Belastung je Jahr inkl. Bauphase und "ohne
# Tilgung", Ersparnis, Belastungsquote, Nachschuesse, Vermoegensamortisation mit Zeitwert der
# Massnahmen; Kleinvermieter: monatlicher Cashflow je Jahr) mit Klartext-Kopfwerten im
# Attribut "summary" (Rundung und Formulierung nach Memo 07 Paragraf 5.4). Die Groessen werden
# aus den Ledger-Tags gebildet wie die Kennzahlen von WS-D2 (Kategoriemerkmal burden, 7.6).

# ---------------------------------------------------------------------------------------------
# Grundlagen: core und Kontext eines Ergebnisses
# ---------------------------------------------------------------------------------------------

#' core-ähnliche Liste eines Ergebnisses für die Notation 12.2
#' @noRd
rep_core_of <- function(res) {
  led <- res$ledger
  list(ledger = led, grid = res$grid, n = led$n,
       stocks = list(BS = led$values$net_position),
       opp = list(BS = res$opportunity$BS, EW = res$opportunity$EW), view = "with_rv")
}

#' Bestandssaldo ohne Restwert (9.4): BS_t, in T der Endwert ohne Restwert
#' @param res `vofi_result`.
#' @param bs Bestandssaldo des Laufs (Vektor der Länge T + 1).
#' @param sim Lauf.
#' @noRd
rep_bs_ex_rv <- function(res, bs, sim = 1L) {
  ew <- (res$kpis$terminal_value_ex_rv %||% NA_real_)[sim]
  if (!is.na(ew)) bs[length(bs)] <- ew
  bs
}

#' Laufkontext eines Ergebnisses (deterministisch, Basisfallwerte der Spezifikation)
#' @noRd
rep_ctx_of <- function(res) eng_context_from_parts(res$grid, res$spec)

#' Ergebnisse je Variante für die Sichten (Simulation: Basisfall)
#' @return benannte Liste von `vofi_result` (Referenz zuerst) und Attribut `baseline`.
#' @noRd
rep_view_results <- function(x, variant, fun) {
  rep_check_class(x, fun, c("vofi_result", "vofi_mc_result", "vofi_comparison"))
  if (inherits(x, "vofi_comparison")) {
    vars <- rep_comparison_variants(x, variant)
    out <- lapply(vars, function(v) rep_det_result(x$results[[v]]))
    names(out) <- vars
    attr(out, "baseline") <- x$baseline %||% names(x$results)[1L]
    return(out)
  }
  res <- rep_det_result(x)
  v <- res$meta$variant %||% "base"
  if (!is.null(variant) && !identical(variant, v)) {
    vofi_abort("report.errors.variant_unknown", variant = utl_collapse(format(variant)),
               suggestion = utl_suggest_text(as.character(variant)[1L], v),
               .class = "vofi_error_input")
  }
  out <- stats::setNames(list(res), v)
  attr(out, "baseline") <- NULL
  out
}

#' Referenzergebnis eines Vergleichs (auch wenn es nicht ausgewählt ist)
#' @noRd
rep_view_reference <- function(x) {
  if (!inherits(x, "vofi_comparison")) return(NULL)
  rep_det_result(rep_comparison_result(x, NULL))
}

#' Werte je Betriebsjahr: Summe einer Periodenmatrix (Lauf 1) über die Perioden des Jahres
#' @noRd
rep_year_sum <- function(m, oy) as.double(kpi_by_year(m[1L, , drop = FALSE], oy))

#' Wert am Ende jedes Betriebsjahres (letzte Periode des Jahres, Lauf 1)
#' @noRd
rep_year_end <- function(m, oy) {
  last <- vapply(oy$cols, function(cc) cc[length(cc)], integer(1))
  as.double(m[1L, last])
}

#' Summe zahlungswirksamer Zeilen gewählter Kategorien je Periode (n x (T+1))
#' @noRd
rep_cat_sum <- function(core, section, category) {
  kpi_sum(core, section = section, category = category, cash = TRUE)
}

#' Zeilen eines Vergleichs nach Jahr zuordnen (Referenzwert je Jahr der Variante)
#' @noRd
rep_match_year <- function(years, ref_years, ref_values) {
  ref_values[match(years, ref_years)]
}

# ---------------------------------------------------------------------------------------------
# Rundung und Klartext (Memo 07 Paragraf 5.4)
# ---------------------------------------------------------------------------------------------

#' Rundung im Haushaltsmodus: Monatswerte auf 5 bzw. 10 EUR (ab 100 EUR), Summen auf 100 EUR,
#' Prozentangaben auf ganze Prozent
#' @param x Werte.
#' @param kind `"month"`, `"sum"` oder `"pct"` (Anteil, Ergebnis in Prozent).
#' @noRd
rep_round_household <- function(x, kind = c("month", "sum", "pct")) {
  kind <- utl_match_arg(kind, c("month", "sum", "pct"), "kind")
  x <- as.double(x)
  switch(kind,
    month = {
      step <- ifelse(abs(x) < 100, 5, 10)
      round(x / step) * step
    },
    sum = round(x / 100) * 100,
    pct = round(100 * x)
  )
}

#' Gerundeter Betrag als Text (ohne Vorzeichen, deutsches Format)
#' @noRd
rep_amount_text <- function(x, kind = "month") fmt_int(abs(rep_round_household(x, kind)))

# ---------------------------------------------------------------------------------------------
# Nutzerkostensicht (Warmmiete)
# ---------------------------------------------------------------------------------------------

#' Warmmiete je Betriebsjahr eines Ergebnisses (EUR/m² und Monat, 12.3)
#' @noRd
rep_tenant_frame <- function(res, variant) {
  core <- rep_core_of(res)
  ctx <- rep_ctx_of(res)
  p <- kpi_tenant_parts(core, ctx)
  oy <- p$oy
  ny <- length(oy$P)
  area <- as.double(p$area[1L])
  ok_area <- area > vofi_tol$zero_abs
  per <- function(m) {
    v <- as.double(m[1L, , drop = TRUE])
    if (!ok_area || ny == 0L) return(rep(NA_real_, ny))
    v / (area * oy$months)
  }
  rent <- per(p$rent)
  levy <- per(p$levy)
  energy <- per(p$energy)
  operating <- per(p$operating)
  pre <- per(p$pre)
  na_reason <- if (!p$has_tenant) "no_tenant_data" else if (!ok_area) "no_living_area" else
    NA_character_
  na_pre <- if (!p$has_pre) "no_tenant_data" else if (!ok_area) "no_living_area" else
    NA_character_
  warm <- rent + levy + energy + operating
  if (!is.na(na_reason)) warm[] <- NA_real_
  pre[!is.na(rep(na_pre, ny))] <- NA_real_
  warm_pre <- rent + operating + pre
  data.frame(
    variant = rep(variant, ny), year = oy$year, op_year = as.integer(oy$P),
    months = oy$months, full_year = oy$full, area_m2 = rep(area, ny),
    rent = rent, levy = levy, operating = operating, energy = energy, warm_rent = warm,
    energy_pre = pre, warm_rent_pre = ifelse(is.na(warm), NA_real_, warm_pre),
    change_prepost = ifelse(is.na(warm), NA_real_, levy + energy - pre),
    na_reason = rep(na_reason, ny), na_reason_prepost = rep(na_pre, ny),
    stringsAsFactors = FALSE
  )
}

#' Nebenerlöse steuerbefreiter Vermietungsgenossenschaften (Spec 01 Teil B 3.9.3)
#'
#' Quote je Betriebsjahr q = (energy_income + operating_income + other_income) /
#' (rent + modernization_levy + Zähler); Hinweis ab q > 0,05 bzw. > 0,15, wenn das Projekt
#' Mieterstrom enthält (Kategorie `energy_income` aus einer frei definierten Zahlungsreihe,
#' Teil B 1.16; halbe Grenzen 10 % bzw. 30 % nach § 5 Abs. 1 Nr. 10 KStG).
#' @param res `vofi_result`.
#' @return Data Frame `year`, `op_year`, `share`, `threshold`, `warning` bzw. `NULL` ohne
#'   Betriebsjahre.
#' @noRd
rep_coop_income_check <- function(res) {
  res <- rep_det_result(res)
  core <- rep_core_of(res)
  oy <- kpi_op_years(res$grid)
  if (length(oy$P) == 0L) return(NULL)
  num <- rep_year_sum(rep_cat_sum(core, "project",
                                  c("energy_income", "operating_income", "other_income")), oy)
  den <- rep_year_sum(rep_cat_sum(core, "project", c("rent", "modernization_levy")), oy) + num
  share <- ifelse(den > vofi_tol$zero_abs, num / den, NA_real_)
  r <- res$ledger$rows
  tenant_power <- any(r$category == "energy_income" & r$source_type == "custom_series")
  thr <- if (tenant_power) 0.15 else 0.05
  data.frame(year = oy$year, op_year = as.integer(oy$P), share = share,
             threshold = rep(thr, length(share)),
             warning = !is.na(share) & share > thr, stringsAsFactors = FALSE)
}

#' Nutzerkostensicht
#'
#' Nutzerkostensicht: Warmmiete je Jahr und Variante in EUR je m² vermieteter Wohnfläche und
#' Monat (Spec 00, Abschnitte 12.3, 12.6; Konzept 2.5). Je Betriebsjahr: Nettokaltmiete
#' (`rent`), Modernisierungsumlage (`levy`), sonstige Betriebskosten der Mieter (`operating`),
#' Heiz- und Warmwasserkosten der Mieter (`energy`, nur Mieteranteil), Warmmiete
#' (`warm_rent`); im Zustand vor der Maßnahme die Heizkosten `energy_pre` und die Warmmiete
#' `warm_rent_pre` (gleiche Miete und Betriebskosten, ohne Umlage), die Änderung
#' „vorher/nachher“ (`change_prepost` = Umlage + Heizkosten nachher − vorher) und bei
#' Vergleichen die Änderung gegenüber der Referenzvariante im selben Jahr
#' (`change_vs_reference`). Die vermietete Fläche ist die Summe der Wohnungsgruppen ohne
#' Selbstnutzung (ohne Gruppen: Wohnfläche des Gebäudes). Fehlende Daten tragen NA mit
#' Begründungscode (`na_reason`, `na_reason_prepost`: `no_tenant_data`, `no_living_area`). Für
#' steuerbefreite Vermietungsgenossenschaften (`wu_genossenschaft`) stehen zusätzlich die Quote
#' der Nebenerlöse (`coop_income_share`), die Hinweisschwelle (`coop_threshold`) und der
#' Hinweis (`coop_warning`) in der Tabelle (Spec 01 Teil B 3.9.3).
#'
#' Bei Simulationen gilt der Basisfall.
#'
#' @param x Objekt der Klasse `vofi_result` oder `vofi_comparison` (auch `vofi_mc_result`).
#' @param variant `NULL` (alle) oder Variante.
#' @return Data Frame mit einer Zeile je Variante und Betriebsjahr.
#' @family Berichten
#' @examples
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' vofi_tenant_view(res)
#' @export
vofi_tenant_view <- function(x, variant = NULL) {
  results <- rep_view_results(x, variant, "vofi_tenant_view")
  ref <- rep_view_reference(x)
  ref_tab <- if (is.null(ref)) NULL else rep_tenant_frame(ref, x$baseline %||% "base")
  parts <- lapply(names(results), function(v) {
    res <- results[[v]]
    d <- rep_tenant_frame(res, v)
    if (!is.null(ref_tab)) {
      d$change_vs_reference <- d$warm_rent - rep_match_year(d$year, ref_tab$year,
                                                            ref_tab$warm_rent)
    }
    if (identical(res$meta$perspective, "wu_genossenschaft")) {
      q <- rep_coop_income_check(res)
      d$coop_income_share <- q$share[match(d$op_year, q$op_year)]
      d$coop_threshold <- q$threshold[match(d$op_year, q$op_year)]
      d$coop_warning <- q$warning[match(d$op_year, q$op_year)]
    }
    d
  })
  out <- rep_rbind_fill(parts)
  attr(out, "unit") <- "EUR_m2_month"
  out
}

#' Data Frames zeilenweise verbinden, fehlende Spalten mit NA auffüllen
#' @noRd
rep_rbind_fill <- function(parts) {
  parts <- parts[!vapply(parts, is.null, logical(1))]
  if (length(parts) == 0L) return(data.frame())
  cols <- unique(unlist(lapply(parts, names)))
  parts <- lapply(parts, function(d) {
    for (cc in setdiff(cols, names(d))) d[[cc]] <- rep(NA, nrow(d))
    d[, cols, drop = FALSE]
  })
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

# ---------------------------------------------------------------------------------------------
# Haushaltssicht
# ---------------------------------------------------------------------------------------------

#' Gruppen der monatlichen Belastung (Kategorien mit `burden = TRUE`, 7.6; Spec 01 Teil B
#' 3.10.4)
#' @noRd
rep_burden_groups <- function() {
  list(interest = list("loans", "interest"), repay = list("loans", "repay"),
       fees = list("loans", "fees"),
       energy = list("project", c("energy_cost", "co2_cost")),
       energy_income = list("project", c("energy_income", "energy_saving")),
       maintenance = list("project", "maintenance"),
       operating = list("project", c("operating_cost", "property_tax")),
       other = list("project", "other_cost"))
}

#' Wartung und Messdienst der Energiekosten (Zeilen `service`, zahlungswirksam, Vorzeichen des
#' Ledgers)
#' @noRd
rep_service_sum <- function(core) {
  r <- core$ledger$rows
  if (is.null(r) || is.null(r$local_row)) return(kpi_zeros(core))
  keys <- r$key[r$section == "project" & r$category == "energy_cost" & r$cash &
                  !is.na(r$local_row) & r$local_row == "service"]
  kpi_sum_keys(core, keys)
}

#' Gruppen des monatlichen Cashflows nach Kapitaldienst (Kleinvermieter, 12.3)
#'
#' Zahlungswirksame Zeilen der Abschnitte project und grants ohne Restwert und Verkaufskosten,
#' abzüglich planmäßigem Kapitaldienst (Zinsen, Tilgung) und Gebühren.
#' @noRd
rep_cashflow_groups <- function(led) {
  r <- led$rows
  sel <- r$cash & r$section %in% c("project", "grants") &
    !(r$category %in% c("residual_value", "sale_cost"))
  grp <- rep("other", sum(sel))
  cats <- r$category[sel]
  secs <- r$section[sel]
  grp[cats %in% c("rent", "rent_loss", "modernization_levy")] <- "rent"
  grp[cats %in% c("operating_income", "energy_income", "energy_saving", "other_income",
                  "imputed_rent", "passthrough")] <- "other_income"
  grp[cats %in% c("operating_cost", "property_tax", "maintenance", "energy_cost", "co2_cost",
                  "other_cost")] <- "costs"
  grp[cats %in% c("land", "acquisition_cost", "capex", "replacement",
                  "relocation_cost")] <- "investment"
  grp[secs == "grants"] <- "grants"
  split(r$key[sel], factor(grp, levels = c("rent", "other_income", "grants", "costs",
                                           "investment", "other")))
}

#' Haushaltsgrößen je Jahr eines Ergebnisses
#' @param res `vofi_result`.
#' @param variant Variantenname.
#' @param owner Selbstnutzersicht (`TRUE`) bzw. Vermietersicht.
#' @return Data Frame (Bauphase als Zeile mit `op_year = 0`, falls vorhanden).
#' @noRd
rep_household_frame <- function(res, variant, owner) {
  core <- rep_core_of(res)
  ctx <- rep_ctx_of(res)
  g <- res$grid
  oy <- kpi_op_years(g)
  ny <- length(oy$P)
  cc <- which(g$phase == "construction" & g$t >= 1L)
  c_months <- sum(g$months[cc])
  has_c <- length(cc) > 0L && c_months > 0
  per_year <- function(m) {
    y <- rep_year_sum(m, oy)
    if (ny == 0L) return(numeric(0))
    y / oy$months
  }
  per_c <- function(m) sum(m[1L, cc]) / c_months
  base <- data.frame(variant = rep(variant, ny), year = oy$year, op_year = as.integer(oy$P),
                     phase = rep("operation", ny), months = oy$months, full_year = oy$full,
                     stringsAsFactors = FALSE)
  crow <- if (has_c) {
    data.frame(variant = variant, year = as.integer(g$year[cc[1L]]), op_year = 0L,
               phase = "construction", months = c_months, full_year = FALSE,
               stringsAsFactors = FALSE)
  } else {
    NULL
  }
  vals <- list()
  cvals <- list()
  if (owner) {
    # Wartung der Wärmeerzeugung und Schornsteinfeger (Zeilen `service` der Energiekosten)
    # stehen in der Spalte Wartung, nicht unter Energie (Memo 07 5.4; SN-11)
    svc <- -rep_service_sum(core)
    for (nm in names(rep_burden_groups())) {
      gdef <- rep_burden_groups()[[nm]]
      m <- -rep_cat_sum(core, gdef[[1L]], gdef[[2L]])
      if (identical(nm, "energy")) m <- m - svc
      if (identical(nm, "maintenance")) m <- m + svc
      vals[[nm]] <- per_year(m)
      if (has_c) cvals[[nm]] <- per_c(m)
    }
    burden <- Reduce(`+`, vals)
    vals$current_rent <- rep(0, ny)
    rent_now <- ctx$value("household.current_rent_month_eur", "scalar")
    rent_now <- if (is.null(rent_now)) 0 else as.double(rent_now[1L])
    vals$burden <- burden
    vals$burden_ex_repay <- burden - vals$repay
    inc <- ctx$value("household.net_income_month_eur", "scalar")
    if (!is.null(inc) && ny > 0L) {
      growth <- ctx$value("household.income_growth", "path")
      if (is.null(growth)) growth <- rep(0, core$n)
      idx <- ctx$index_year(growth, base_date = kpi_price_base_date(ctx, g))
      vals$income <- as.double(inc[1L]) * as.double(idx[1L, oy$first])
    } else {
      vals$income <- rep(NA_real_, ny)
    }
    vals$burden_ratio <- ifelse(!is.na(vals$income) & vals$income > vofi_tol$zero_abs,
                                vals$burden / vals$income, NA_real_)
    if (has_c) {
      cb <- Reduce(`+`, cvals)
      cvals$current_rent <- rent_now
      cvals$burden <- cb + rent_now
      cvals$burden_ex_repay <- cb + rent_now - cvals$repay
      cvals$income <- NA_real_
      cvals$burden_ratio <- NA_real_
    }
  } else {
    groups <- rep_cashflow_groups(res$ledger)
    for (nm in names(groups)) {
      m <- kpi_sum_keys(core, groups[[nm]])
      vals[[nm]] <- per_year(m)
      if (has_c) cvals[[nm]] <- per_c(m)
    }
    for (nm in c("interest", "repay", "fees")) {
      m <- rep_cat_sum(core, "loans", nm)
      vals[[nm]] <- per_year(m)
      if (has_c) cvals[[nm]] <- per_c(m)
    }
    vals$cashflow <- Reduce(`+`, vals)
    if (has_c) cvals$cashflow <- Reduce(`+`, cvals)
  }
  ns <- kpi_ns(core)
  vals$equity_calls <- rep_year_sum(ns, oy)
  if (has_c) cvals$equity_calls <- sum(ns[1L, cc])
  opp <- res$opportunity$BS
  if (is.null(opp)) opp <- matrix(0, 1L, g$T + 1L)
  dw <- matrix(kpi_wealth(core, ctx)[1L, ] - opp[1L, ], nrow = 1L)
  db <- matrix(rep_bs_ex_rv(res, core$stocks$BS[1L, ], 1L) - opp[1L, ], nrow = 1L)
  vals$wealth_diff <- rep_year_end(dw, oy)
  vals$wealth_diff_ex_rv <- rep_year_end(db, oy)
  if (has_c) {
    last <- cc[length(cc)]
    cvals$wealth_diff <- dw[1L, last]
    cvals$wealth_diff_ex_rv <- db[1L, last]
  }
  out <- base
  for (nm in names(vals)) out[[nm]] <- as.double(vals[[nm]])
  if (has_c) {
    for (nm in names(vals)) crow[[nm]] <- as.double(cvals[[nm]] %||% NA_real_)
    out <- rbind(crow, out)
  }
  rownames(out) <- NULL
  out
}

#' Haushaltssicht
#'
#' Haushaltssicht (Spec 00, Abschnitte 12.3, 12.6, 14 Nr. 28; Spec 01 Teil B 3.10.4; Konzept
#' 1.4, 2.5; Memo 07 Paragraf 5.4). Eine Zeile je Variante und Jahr (Bauphase als eigene Zeile
#' mit `op_year = 0` und `phase = "construction"`), Beträge in EUR pro Monat.
#'
#' **Selbstnutzer** (Perspektive `selbstnutzer`): Zinsen (`interest`), Tilgung (`repay`),
#' Gebühren (`fees`), Energie- und CO2-Kosten (`energy`), Einspeiseerlöse und Ersparnisse als
#' Gutschrift (`energy_income`, negativ), Instandhaltung und Wartung (`maintenance`, mit Wartung
#' und Messdienst der Wärmeerzeugung aus den Energiekosten),
#' Betriebskosten und Grundsteuer (`operating`), sonstige laufende Kosten (`other`), die
#' monatliche Belastung (`burden`, gleich der Kennzahl `monthly_burden`) und die Belastung
#' „ohne Tilgung“ (`burden_ex_repay`, Kostensicht). In der Bauphase kommt die bisherige Miete
#' hinzu (`current_rent`, „Doppelbelastung“, gleich `monthly_burden_construction`). Dazu das
#' Nettoeinkommen (`income`) und die Belastungsquote (`burden_ratio`), bei Vergleichen die
#' Ersparnis gegenüber der Referenzvariante (`saving`, positiv = Ersparnis) und ihre Summe in
#' EUR (`cumulative_saving`).
#'
#' **Kleinvermieter** (alle übrigen Perspektiven): monatlicher Cashflow nach Kapitaldienst
#' (`cashflow`, positiv = Überschuss, negativ = Zuschuss; gleich der Kennzahl
#' `monthly_net_cashflow`) mit Mieten (`rent`), sonstigen Erlösen (`other_income`),
#' Zuschüssen (`grants`), laufenden Kosten (`costs`), Investitionen (`investment`), Zinsen,
#' Tilgung und Gebühren, bei Vergleichen die Änderung gegenüber der Referenz
#' (`cashflow_change`).
#'
#' **Beide:** Nachschüsse des Jahres in EUR (`equity_calls`) und die Vermögensdifferenz zur
#' Unterlassungsalternative am Jahresende mit Restwertpfad (`wealth_diff`; im Haushaltsmodus mit
#' dem Zeitwert der Maßnahmen, R-72) bzw. nur aus Guthaben und Schulden (`wealth_diff_ex_rv`),
#' bei Vergleichen die Vermögensdifferenz gegenüber der Referenzvariante mit bzw. ohne Restwert
#' (`wealth_diff_vs_reference`, `wealth_diff_ex_rv_vs_reference`) und die Markierung der
#' dauerhaften Amortisation ohne Restwert (`paid_back`).
#'
#' Das Attribut `summary` enthält die Kopfwerte je Variante (`item`, `label`, `value`, `unit`)
#' mit einem Klartext (`text`) nach den Regeln für Nicht-Finanzleute: gerundete Monatswerte
#' (5 bzw. 10 EUR), Summen auf 100 EUR, Prozent ganzzahlig, Wörter statt Vorzeichen („Sie
#' sparen …“, „Sie zahlen … mehr“) und bei Simulationen die Bandbreite in Worten. Die
#' Vermögensamortisation steht bei Vergleichen gegenüber der Referenzvariante; bei
#' Bestandsprojekten ohne Referenzvariante wird sie nicht ausgewiesen, weil der
#' Vermögensvergleich mit der Unterlassung die ohnehin anfallenden Bestandszahlungen enthält
#' (Spec 00, Abschnitt 12.3a). Bei Simulationen gilt für die Tabelle der Basisfall.
#'
#' @param x Objekt der Klasse `vofi_result` oder `vofi_comparison` (auch `vofi_mc_result`).
#' @param variant `NULL` (alle) oder Variante.
#' @return Data Frame mit den Attributen `summary` und `perspective`.
#' @family Berichten
#' @examples
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' hv <- vofi_household_view(res)
#' hv
#' attr(hv, "summary")$text
#' @export
vofi_household_view <- function(x, variant = NULL) {
  results <- rep_view_results(x, variant, "vofi_household_view")
  ref <- rep_view_reference(x)
  first <- if (is.null(ref)) results[[1L]] else ref
  persp <- first$meta$perspective %||% first$spec$project$perspective %||% ""
  owner <- identical(persp, "selbstnutzer")
  ref_name <- x$baseline %||% NULL
  ref_tab <- if (is.null(ref)) NULL else rep_household_frame(ref, ref_name, owner)
  # Gesamtkosten der Referenz für die Gesamtersparnis (SN-03)
  ref_cost <- if (is.null(ref_tab) || !owner) NA_real_ else
    rep_household_total_cost(ref_tab, ref$kpis$own_contribution)
  parts <- lapply(names(results), function(v) {
    d <- rep_household_frame(results[[v]], v, owner)
    if (!is.null(ref_tab)) d <- rep_household_vs_ref(d, ref_tab, owner)
    d
  })
  out <- rep_rbind_fill(parts)
  summ <- lapply(names(results), function(v) {
    rep_household_summary(x, results[[v]], out[out$variant == v, , drop = FALSE], v, owner,
                          ref_name, ref_cost = ref_cost)
  })
  attr(out, "summary") <- rep_rbind_fill(summ)
  attr(out, "perspective") <- persp
  out
}

#' Vergleichsspalten der Haushaltssicht (Ersparnis, Cashflow-Änderung, Vermögensdifferenz)
#' @noRd
rep_household_vs_ref <- function(d, ref, owner) {
  key <- paste(d$phase, d$year)
  rkey <- paste(ref$phase, ref$year)
  pick <- function(col) ref[[col]][match(key, rkey)]
  if (owner) {
    d$saving <- pick("burden") - d$burden
    d$cumulative_saving <- cumsum(ifelse(is.na(d$saving), 0, d$saving * d$months))
  } else {
    d$cashflow_change <- d$cashflow - pick("cashflow")
  }
  d$wealth_diff_vs_reference <- d$wealth_diff - pick("wealth_diff")
  d$wealth_diff_ex_rv_vs_reference <- d$wealth_diff_ex_rv - pick("wealth_diff_ex_rv")
  # Amortisation gegenüber der Referenz ohne Restwert: der Zeitwert der Maßnahmen setzt die
  # Investition im Jahr der Zahlung voll als Vermögen an (SN-02)
  d$paid_back <- rep_paid_back(d$wealth_diff_ex_rv_vs_reference)
  d
}

#' Gesamtkosten einer Variante über den Horizont (Selbstnutzer, nominal; Memo 07 5.4)
#'
#' Laufende Belastung ohne bisherige Miete (einschließlich der aus dem Einkommen gezahlten
#' Nachschüsse) plus Eigenanteil nach Förderung (Investitionen abzüglich Zuschüssen und
#' Krediten, deren Raten in der Belastung stehen).
#' @noRd
rep_household_total_cost <- function(d, oc) {
  oc <- as.double(oc %||% NA_real_)[1L]
  sum((d$burden - d$current_rent) * d$months, na.rm = TRUE) + max(0, if (is.na(oc)) 0 else oc)
}

#' Bezeichnung einer Variante (Label des Szenarios; ohne Label die Kennung)
#'
#' Labels stehen in Anführungszeichen, Kennungen ohne.
#' @noRd
rep_hh_vlabel <- function(x, v) {
  if (is.null(v)) return("")
  labs <- if (is.list(x$meta)) x$meta$variant_labels else NULL
  if (!is.null(labs) && v %in% names(labs) && !identical(labs[[v]], v)) {
    return(paste0("\u201e", labs[[v]], "\u201c"))
  }
  v
}

#' Eigenanteil nach Zuschüssen und Krediten je Kalenderjahr (SN-05)
#'
#' Investitionsauszahlungen abzüglich Zuschüssen und Kreditauszahlungen je Kalenderjahr
#' (nominal, positiv = eigene Mittel); ein negativer Jahreswert (z. B. ein Zuschuss, der erst im
#' Folgejahr ausgezahlt wird) wird dem vorigen Jahr zugerechnet. `prefinance`: größter Betrag,
#' der vor der Auszahlung der Zuschüsse eines Jahres aus eigenen Mitteln vorzufinanzieren ist.
#' @return Liste `years`, `amounts`, `prefinance` (EUR bzw. `NA`).
#' @noRd
rep_household_own_by_year <- function(res) {
  core <- rep_core_of(res)
  inv <- kpi_sum(core, section = "project", category = rep_html_invest_categories(), cash = TRUE)
  gr <- kpi_sum(core, section = "grants", cash = TRUE)
  dr <- kpi_sum(core, section = "loans", category = "draw", cash = TRUE)
  own <- -as.double((inv + gr + dr)[1L, ])
  inv1 <- -as.double(inv[1L, ])
  yrs <- as.integer(res$grid$year)
  by <- tapply(own, yrs, sum)
  y <- as.integer(names(by))
  a <- as.double(by)
  keep <- abs(a) > 50
  y <- y[keep]
  a <- a[keep]
  i <- 2L
  while (i <= length(a)) {
    if (a[i] < 0) {
      a[i - 1L] <- a[i - 1L] + a[i]
      a <- a[-i]
      y <- y[-i]
    } else {
      i <- i + 1L
    }
  }
  keep <- a > 50
  pre <- NA_real_
  if (any(keep)) {
    # vorzufinanzieren: Investition und Kredit bis zur ersten Zuschusszahlung im ersten Jahr
    y0 <- y[keep][1L]
    cols <- which(yrs == y0)
    g0 <- cols[abs(gr[1L, cols]) > vofi_tol$zero_abs]
    if (length(g0) > 0L) {
      before <- cols[cols < g0[1L]]
      pre <- sum(inv1[before]) - sum(dr[1L, before])
    }
  }
  list(years = y[keep], amounts = a[keep], prefinance = pre)
}

#' Dauerhafte Amortisation: ab der Zeile, ab der alle folgenden Werte >= 0 sind
#' @noRd
rep_paid_back <- function(v) {
  ok <- !is.na(v) & v >= -1e-9
  out <- rev(cumprod(rev(ok))) == 1
  out & !is.na(v)
}

#' Klartext-Kopfwerte der Haushaltssicht (Memo 07 Paragraf 5.4)
#' @noRd
rep_household_summary <- function(x, res, d, variant, owner, ref_name, ref_cost = NA_real_) {
  acc <- new.env(parent = emptyenv())
  acc$items <- list()
  add <- function(item, value, unit, text, label = NULL) {
    label <- label %||% lbl(paste0("report.household.items.", item))
    acc$items[[length(acc$items) + 1L]] <- data.frame(
      variant = variant, item = item, label = label, value = as.double(value), unit = unit,
      text = text, stringsAsFactors = FALSE
    )
  }
  op <- d[d$phase == "operation", , drop = FALSE]
  full <- op[op$full_year, , drop = FALSE]
  y1 <- if (nrow(full) > 0L) full[1L, , drop = FALSE] else NULL
  avg_rows <- utils::head(full, 10L)
  kp <- res$kpis
  has_ref <- !is.null(ref_name) && !identical(variant, ref_name)
  ref_label <- rep_hh_vlabel(x, ref_name)
  oc <- kp$own_contribution %||% NA_real_
  paid <- if (owner) rep_household_total_cost(d, oc) else NA_real_
  if (owner) {
    if (!is.null(y1)) {
      add("burden_y1", y1$burden, "EUR_month",
          lbl("report.household.text.burden_y1", value = rep_amount_text(y1$burden),
              ex = rep_amount_text(y1$burden_ex_repay)))
    }
    cr <- d[d$phase == "construction", , drop = FALSE]
    if (nrow(cr) > 0L) {
      add("burden_construction", cr$burden[1L], "EUR_month",
          lbl("report.household.text.burden_construction",
              value = rep_amount_text(cr$burden[1L])))
    }
    if (has_ref && !is.null(y1) && !is.na(y1$saving)) {
      add("saving_y1", y1$saving, "EUR_month",
          rep_saving_text(y1$saving, ref_label, "report.household.text.when_y1"))
      sv <- mean(avg_rows$saving)
      add("saving_avg10", sv, "EUR_month",
          rep_saving_text(sv, ref_label, "report.household.text.when_avg",
                          n = nrow(avg_rows)))
      # Gesamtersparnis = Gesamtkosten der Referenz - Gesamtkosten der Variante (SN-03)
      tot <- if (is.na(ref_cost)) utils::tail(op$cumulative_saving, 1L) else ref_cost - paid
      key <- if (tot >= 0) "report.household.text.total_saving" else
        "report.household.text.total_more"
      add("total_saving", tot, "EUR",
          lbl(key, value = rep_amount_text(tot, "sum"), n = nrow(op), ref = ref_label))
    }
    ratio <- suppressWarnings(max(op$burden_ratio, na.rm = TRUE))
    if (is.finite(ratio)) {
      thr <- rep_spec_number(res$spec, "analysis.thresholds.burden_share") %||% 0.40
      pct <- fmt_int(rep_round_household(ratio, "pct"))
      txt <- lbl("report.household.text.burden_ratio", value = pct)
      if (ratio > thr) {
        txt <- paste(txt, lbl("report.household.text.burden_ratio_high",
                              threshold = fmt_int(rep_round_household(thr, "pct"))))
      }
      add("burden_ratio", ratio, "share", txt)
    }
  } else if (!is.null(y1)) {
    key <- if (y1$cashflow >= 0) "report.household.text.cashflow_surplus" else
      "report.household.text.cashflow_subsidy"
    add("cashflow_y1", y1$cashflow, "EUR_month", lbl(key, value = rep_amount_text(y1$cashflow)))
    i <- which.min(op$cashflow)
    if (length(i) == 1L && op$cashflow[i] < 0) {
      add("cashflow_min", op$cashflow[i], "EUR_month",
          lbl("report.household.text.cashflow_min", year = as.integer(op$year[i]),
              value = rep_amount_text(op$cashflow[i])))
    }
    if (has_ref && !is.na(y1$cashflow_change)) {
      key <- if (y1$cashflow_change >= 0) "report.household.text.cashflow_more" else
        "report.household.text.cashflow_less"
      add("cashflow_change_y1", y1$cashflow_change, "EUR_month",
          lbl(key, value = rep_amount_text(y1$cashflow_change), ref = ref_label))
    }
  }
  if (owner) {
    # Gesamtkosten über den Horizont (Memo 07 Paragraf 5.4): Eigenanteil und laufende
    # Belastung ohne bisherige Miete, nominal
    add("total_cost", paid, "EUR",
        lbl("report.household.text.total_cost", n = nrow(op),
            value = rep_amount_text(paid, "sum")))
  }
  if (!is.na(oc[1L])) {
    add("own_contribution", oc[1L], "EUR", rep_own_contribution_text(res, oc[1L]))
  }
  calls <- sum(d$equity_calls, na.rm = TRUE)
  add("equity_calls", calls, "EUR",
      if (calls > vofi_tol$zero_abs) {
        lbl(if (owner) "report.household.text.equity_calls" else
          "report.household.text.equity_calls_landlord", value = rep_amount_text(calls, "sum"))
      } else {
        lbl("report.household.text.no_equity_calls")
      })
  if (has_ref) {
    # gegenüber der Referenz ohne Restwert (SN-02)
    pb_col <- d$wealth_diff_ex_rv_vs_reference
    basis <- "ex_rv"
  } else {
    pb_col <- d$wealth_diff
    basis <- kpi_rv_basis(rep_ctx_of(res))
  }
  pb <- rep_paid_back(pb_col)
  pb_year <- if (any(pb)) d$year[which(pb)[1L]] else NA_integer_
  if (!has_ref && !is.na(pb_year) && pb_year <= min(d$year)) {
    # „bezahlt gemacht“ im Stichtagsjahr nur ohne Restwert, nie aus dem Zeitwert (SN-02)
    pb <- rep_paid_back(d$wealth_diff_ex_rv)
    pb_year <- if (any(pb)) d$year[which(pb)[1L]] else NA_integer_
    basis <- "ex_rv"
  }
  btxt <- lbl(paste0("report.household.text.basis_", basis))
  if (!has_ref && isTRUE(kpi_primary(res$spec)$existing)) {
    # Bestandsprojekt ohne Referenzvariante: Der Vermögensvergleich mit der Unterlassung
    # enthält die ohnehin anfallenden Bestandszahlungen und ist keine Amortisation (12.3a);
    # die Referenzvariante eines Vergleichs selbst bekommt keine Aussage
    if (is.null(ref_name)) {
      add("payback_year", NA_real_, "year",
          lbl("report.household.text.payback_needs_reference"))
    }
  } else if (is.na(pb_year)) {
    add("payback_year", NA_real_, "year",
        lbl("report.household.text.no_payback", end = res$grid$end_date, basis = btxt))
  } else {
    add("payback_year", pb_year, "year",
        lbl("report.household.text.payback", year = as.integer(pb_year), basis = btxt))
  }
  rng <- rep_household_range(x, variant, owner)
  if (!is.null(rng)) add(rng$item, rng$value, rng$unit, rng$text)
  rep_rbind_fill(acc$items)
}

#' Klartext des Eigenanteils: heute bzw. im Jahr der ersten Stufe, spätere Stufen je Jahr,
#' Vorfinanzierung des Zuschusses, Hinweis auf Kredite (SN-05)
#' @noRd
rep_own_contribution_text <- function(res, oc) {
  ob <- tryCatch(rep_household_own_by_year(res), error = function(e) NULL)
  if (is.null(ob) || length(ob$years) == 0L) {
    if (oc > vofi_tol$zero_abs) {
      return(lbl("report.household.text.own_contribution_total",
                 value = rep_amount_text(oc, "sum")))
    }
    return(lbl("report.household.text.own_contribution_none"))
  }
  txt <- lbl("report.household.text.own_contribution", year = ob$years[1L],
             value = rep_amount_text(ob$amounts[1L], "sum"))
  if (!is.na(ob$prefinance) && ob$prefinance > ob$amounts[1L] + 50) {
    txt <- paste(txt, lbl("report.household.text.own_contribution_prefinance",
                          value = rep_amount_text(ob$prefinance, "sum")))
  }
  if (length(ob$years) > 1L) {
    items <- vapply(seq_along(ob$years)[-1L], function(i) {
      lbl("report.household.text.own_contribution_item", year = ob$years[i],
          value = rep_amount_text(ob$amounts[i], "sum"))
    }, "")
    txt <- paste(txt, lbl("report.household.text.own_contribution_later",
                          items = paste(items, collapse = ", "),
                          total = rep_amount_text(sum(ob$amounts), "sum")))
  }
  paste(txt, lbl("report.household.text.own_contribution_loans"))
}

#' Text „Sie sparen … / Sie zahlen … mehr“ (Wörter statt Vorzeichen)
#' @noRd
rep_saving_text <- function(v, ref, when_key, n = NULL) {
  when <- if (is.null(n)) lbl(when_key) else lbl(when_key, n = as.integer(n))
  r <- rep_round_household(v)
  key <- if (r > 0) "report.household.text.saving" else if (r < 0)
    "report.household.text.more" else "report.household.text.equal"
  lbl(key, value = rep_amount_text(v), ref = ref, when = when)
}

#' Bandbreite in Worten aus der Simulation (q10 bis q90: „in 8 von 10 Zukünften“)
#'
#' Wörter statt Vorzeichen (Memo 07 Paragraf 5.4 Nr. 5): Beim Cashflow des Kleinvermieters
#' richtet sich der Text nach den gerundeten Werten – Überschuss, Zuschuss oder eine Spanne von
#' Zuschuss bis Überschuss; alle Beträge ohne Vorzeichen.
#' @noRd
rep_household_range <- function(x, variant, owner) {
  mc <- if (inherits(x, "vofi_comparison")) x$results[[variant]] else x
  if (!inherits(mc, "vofi_mc_result") || !is.data.frame(mc$stats)) return(NULL)
  # Selbstnutzer: Belastung im Mittel der ersten 10 Jahre; im ersten Jahr sind Preise und
  # Inflation meist noch fest (SN-07)
  kpi <- if (owner) c("monthly_burden_avg10", "monthly_burden_y1") else
    "monthly_net_cashflow_y1"
  kpi <- kpi[kpi %in% mc$stats$kpi][1L]
  if (is.na(kpi)) return(NULL)
  s <- mc$stats[mc$stats$kpi == kpi, , drop = FALSE]
  if (nrow(s) == 0L || is.na(s$q10) || is.na(s$q50) || is.na(s$q90)) return(NULL)
  s <- s[1L, , drop = FALSE]
  q10 <- rep_round_household(s$q10)
  q50 <- rep_round_household(s$q50)
  q90 <- rep_round_household(s$q90)
  med <- rep_amount_text(s$q50)
  if (q10 == q90) {
    # entartete Spanne: keine Aussage „zwischen X und X“
    key <- if (owner) "report.household.text.range_flat_burden" else
      "report.household.text.range_flat"
    text <- if (owner) lbl(key, median = med) else lbl(key)
  } else if (owner) {
    key <- if (identical(kpi, "monthly_burden_avg10")) "report.household.text.range_burden" else
      "report.household.text.range_burden_y1"
    text <- lbl(key, median = med, lo = rep_amount_text(s$q10), hi = rep_amount_text(s$q90))
  } else if (q10 >= 0) {
    text <- lbl("report.household.text.range_surplus", median = med,
                lo = rep_amount_text(s$q10), hi = rep_amount_text(s$q90))
  } else if (q90 <= 0) {
    # Zuschuss: kleinster Zuschuss (q90) bis größter Zuschuss (q10)
    text <- lbl("report.household.text.range_subsidy", median = med,
                lo = rep_amount_text(s$q90), hi = rep_amount_text(s$q10))
  } else {
    key <- if (q50 >= 0) "report.household.text.range_mixed_surplus" else
      "report.household.text.range_mixed_subsidy"
    text <- lbl(key, median = med, lo = rep_amount_text(s$q10), hi = rep_amount_text(s$q90))
  }
  list(item = "range", value = s$q50, unit = "EUR_month", text = text)
}

#' Wert eines Spezifikationspfads (Knoten: Basisfallwert der Konstanten)
#' @noRd
rep_spec_number <- function(spec, path) {
  v <- path_get(spec, path)
  if (node_is(v) && identical(v$kind, "const")) return(as.double(v$value))
  if (is.numeric(v)) return(as.double(v))
  NULL
}
