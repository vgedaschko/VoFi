# Foerderregeln (WS-E2, Spec 01 Teil B 4.3.3, 4.4, 4.8, 5.4; Spec 00 5.3).
# fund_degression, fund_income_rate und fund_staffel_cap liefern deterministische Einzel- bzw.
# Tabellenwerte (returns: value) fuer den Expander funding; fund_35c_params bildet die Nutzlast
# credit des Eintrags funding/estg_35c auf die Parameter des Typs tax_credit_35c ab. Alle Regeln
# sind vektorisiert, ziehen keine Zufallszahlen und lesen weder ctx noch die Bibliothek.

#' Datum aus einer Regel-Eingabe (Date oder ISO-Zeichenkette)
#' @param x Date bzw. Zeichenvektor.
#' @param arg Name für Meldungen.
#' @return `Date`-Vektor.
#' @noRd
fund_as_date <- function(x, arg) {
  if (inherits(x, "Date")) return(x)
  if (is.list(x) && identical(x[["kind"]], "const")) x <- x[["value"]]
  if (is.numeric(x)) return(as.Date(sprintf("%04d-01-01", as.integer(round(x)))))
  out <- as.Date(as.character(x), format = "%Y-%m-%d", optional = TRUE)
  if (length(out) == 0L || anyNA(out)) {
    vofi_abort("types.rule.fund_degression.msg.date_invalid", arg = arg,
               value = utl_collapse(format(x)), .class = "vofi_error_input")
  }
  out
}

#' Zahl aus einer Regel-Eingabe (Zahl, Konstante oder `NULL` = Default)
#' @noRd
fund_num <- function(x, default = NA_real_) {
  if (is.null(x) || length(x) == 0L) return(default)
  if (is.list(x) && identical(x[["kind"]], "const")) x <- x[["value"]]
  if (is.list(x) && identical(x[["kind"]], "series_t")) x <- x[["values"]]
  if (is.list(x)) {
    x <- vapply(x, function(e) {
      if (is.list(e) && identical(e[["kind"]], "const")) e <- e[["value"]]
      v <- suppressWarnings(as.double(unlist(e, use.names = FALSE)))
      if (length(v) == 1L) v else NA_real_
    }, double(1))
  }
  v <- suppressWarnings(as.double(x))
  if (length(v) == 0L) default else v
}

#' Degression nach Antragsdatum (Teil B 4.3.3)
#'
#' k = 0, falls `application_date` < `start`, sonst k = 1 + floor(Monate(`application_date` −
#' `start`) / `every_months`); Wert = pmax(`value` + k · `step`, `floor`) bei `step` < 0 bzw.
#' pmin(`value` + k · `step`, `floor`) bei `step` > 0. Volle Monate: Differenz der Kalendermonate,
#' vermindert um 1, wenn der Tag des Antrags vor dem Tag des Starts liegt.
#' @param value Ausgangswert(e) der Nutzlast.
#' @param application_date Antragsdatum (Date bzw. ISO-Zeichenkette).
#' @param start Beginn der Absenkung.
#' @param step Schritt je Stufe (negativ = Absenkung).
#' @param every_months Stufenlänge in Monaten (> 0).
#' @param floor Untergrenze (`step` < 0) bzw. Obergrenze (`step` > 0); `NULL` = keine.
#' @return double (Länge von `value` bzw. `application_date`).
#' @noRd
rule_fund_degression_fun <- function(value, application_date, start, step, every_months,
                                     floor) {
  v0 <- fund_num(value)
  ad <- fund_as_date(application_date, "application_date")
  st <- fund_as_date(start, "start")
  stp <- fund_num(step, 0)
  em <- fund_num(every_months, 12)
  if (any(!is.finite(em) | em <= 0)) {
    vofi_abort("types.rule.fund_degression.msg.every_invalid",
               value = utl_collapse(format(em)), .class = "vofi_error_input")
  }
  n <- max(length(v0), length(ad))
  v0 <- rep_len(v0, n)
  ad <- rep_len(ad, n)
  st <- rep_len(st, n)
  stp <- rep_len(stp, n)
  months <- grid_months_between(st, ad) - (utl_mday(ad) < utl_mday(st))
  k <- ifelse(ad < st, 0, 1 + base::floor(months / em))
  raw <- v0 + k * stp
  fl <- fund_num(floor, NA_real_)
  if (is.null(floor) || all(is.na(fl))) return(raw)
  fl <- rep_len(fl, n)
  ifelse(stp < 0, pmax(raw, fl), ifelse(stp > 0, pmin(raw, fl), raw))
}

#' @noRd
typedef_rule_fund_degression_20260721 <- function() {
  vofi_type(
    name = "fund_degression@2026-07-21", kind = "rule", rule_name = "fund_degression",
    valid_from = as.Date("2026-07-21"), valid_to = NULL, reform = NULL,
    source = "BEG EM (BAnz AT 27.08.2026), Degression nach Antragsdatum; Spec 01 Teil B 4.3.3",
    returns = "value", fun = rule_fund_degression_fun,
    example = list(value = 28000, application_date = "2028-08-01", start = "2027-02-01",
                   step = -750, every_months = 6, floor = 22000)
  )
}

#' Satz einer Einkommensstaffel (Teil B 4.3.3)
#'
#' i = 1 + Σ_j 1{`taxable_income_adj` > t_j}; Ergebnis r_i (Schwellen einschließlich: x ≤ t₁ →
#' r₁). `taxable_income_adj` enthält bereits die Verschiebung für Kinder (4.3.2).
#' @param taxable_income_adj zu versteuerndes Einkommen nach Verschiebung (Vektor).
#' @param thresholds aufsteigende Schwellen t₁ < … < t_J.
#' @param rates Sätze r₁ … r_{J+1}.
#' @return double (Länge von `taxable_income_adj`).
#' @noRd
rule_fund_income_rate_fun <- function(taxable_income_adj, thresholds, rates) {
  x <- fund_num(taxable_income_adj)
  t <- fund_num(thresholds, numeric(0))
  r <- fund_num(rates, numeric(0))
  t <- t[!is.na(t)]
  if (length(r) != length(t) + 1L || is.unsorted(t, strictly = TRUE)) {
    vofi_abort("types.rule.fund_income_rate.msg.table_invalid", n_thresholds = length(t),
               n_rates = length(r), .class = "vofi_error_input")
  }
  i <- 1L + vapply(x, function(v) sum(v > t), integer(1))
  out <- r[i]
  out[is.na(x)] <- NA_real_
  out
}

#' @noRd
typedef_rule_fund_income_rate_20260721 <- function() {
  vofi_type(
    name = "fund_income_rate@2026-07-21", kind = "rule", rule_name = "fund_income_rate",
    valid_from = as.Date("2026-07-21"), valid_to = NULL, reform = NULL,
    source = "BEG EM Einkommensbonus (KfW 458); Spec 01 Teil B 4.3.3",
    returns = "value", fun = rule_fund_income_rate_fun,
    example = list(taxable_income_adj = 45000, thresholds = c(30000, 40000, 50000),
                   rates = c(0.40, 0.30, 0.10, 0))
  )
}

#' Höchstbetrag einer Staffel nach Wohneinheiten (Teil B 4.4)
#'
#' cap = Σ_{u=1..N} cap_eur(u) mit der Stufe der u-ten WE (`units_from` ≤ u ≤ `units_to`); mit
#' `use_isfp` gilt `cap_isfp_eur` (fehlt: `cap_eur`). Eine WE ohne Stufe trägt 0 bei.
#' @param n_units Zahl der WE N (ganzzahlig ≥ 0; Vektor zulässig).
#' @param table Sequenz von Stufen `{units_from, units_to, cap_eur[, cap_isfp_eur]}`.
#' @param use_isfp logisch: iSFP-Höchstbeträge verwenden.
#' @return double (Länge von `n_units`).
#' @noRd
rule_fund_staffel_cap_fun <- function(n_units, table, use_isfp) {
  nu <- fund_num(n_units)
  isfp <- isTRUE(as.logical(unlist(use_isfp))[1L])
  rows <- if (is.data.frame(table)) {
    lapply(seq_len(nrow(table)), function(i) as.list(table[i, , drop = FALSE]))
  } else {
    table
  }
  if (!is.list(rows) || length(rows) == 0L) {
    vofi_abort("types.rule.fund_staffel_cap.msg.table_invalid", .class = "vofi_error_input")
  }
  lo <- vapply(rows, function(r) fund_num(r[["units_from"]], 1), double(1))
  hi <- vapply(rows, function(r) fund_num(r[["units_to"]], Inf), double(1))
  cap <- vapply(rows, function(r) {
    v <- if (isfp) fund_num(r[["cap_isfp_eur"]], NA_real_) else NA_real_
    if (is.na(v)) fund_num(r[["cap_eur"]], 0) else v
  }, double(1))
  vapply(nu, function(n) {
    if (is.na(n) || n < 1) return(0)
    u <- seq_len(as.integer(round(n)))
    total <- 0
    for (j in seq_along(cap)) total <- total + cap[j] * sum(u >= lo[j] & u <= hi[j])
    total
  }, double(1))
}

#' @noRd
typedef_rule_fund_staffel_cap_20260721 <- function() {
  vofi_type(
    name = "fund_staffel_cap@2026-07-21", kind = "rule", rule_name = "fund_staffel_cap",
    valid_from = as.Date("2026-07-21"), valid_to = NULL, reform = NULL,
    source = "BEG EM Hoechstgrenzen foerderfaehiger Kosten je Wohneinheit; Spec 01 Teil B 4.4",
    returns = "value", fun = rule_fund_staffel_cap_fun,
    example = list(n_units = 12L,
                   table = list(list(units_from = 1, units_to = 1, cap_eur = 28000),
                                list(units_from = 2, units_to = 6, cap_eur = 15000),
                                list(units_from = 7, units_to = Inf, cap_eur = 8000)),
                   use_isfp = FALSE)
  )
}

#' Parameter der Steuerermäßigung nach § 35c EStG (Teil B 4.8, 5.4)
#'
#' Bildet die Nutzlast `credit` (`schedule_shares`, `total_share`, `cap_per_object_eur`,
#' `energy_advice_share`) auf `share_y1..3`, `total_share`, `cap_total`, `energy_advice_share` und
#' die Jahresdeckel `cap_1..3` = share_i · cap_total / total_share ab; fehlende Felder: Werte des
#' Gesetzes (0,07/0,07/0,06; 0,20; 40.000; 0,50).
#' @param credit Nutzlast `funding.<f>.credit` (Liste) oder `NULL`.
#' @return benannte Liste.
#' @noRd
rule_fund_35c_params_fun <- function(credit) {
  cr <- if (is.list(credit)) credit else list()
  sh <- fund_num(cr[["schedule_shares"]], c(0.07, 0.07, 0.06))
  if (length(sh) != 3L || anyNA(sh)) {
    vofi_abort("types.rule.fund_35c_params.msg.schedule_invalid",
               value = utl_collapse(format(sh)), .class = "vofi_error_input")
  }
  total <- fund_num(cr[["total_share"]], 0.20)[1L]
  cap_total <- fund_num(cr[["cap_per_object_eur"]], 40000)[1L]
  ea <- fund_num(cr[["energy_advice_share"]], 0.50)[1L]
  caps <- if (isTRUE(total > 0)) sh * cap_total / total else rep(0, 3L)
  list(share_y1 = sh[1L], share_y2 = sh[2L], share_y3 = sh[3L], total_share = total,
       cap_total = cap_total, energy_advice_share = ea,
       cap_1 = caps[1L], cap_2 = caps[2L], cap_3 = caps[3L])
}

#' @noRd
typedef_rule_fund_35c_params_20200101 <- function() {
  vofi_type(
    name = "fund_35c_params@2020-01-01", kind = "rule", rule_name = "fund_35c_params",
    valid_from = as.Date("2020-01-01"), valid_to = NULL, reform = NULL,
    source = "\u00a7 35c EStG (energetische Massnahmen, selbstgenutztes Wohneigentum); Teil B 4.8",
    returns = "params", fun = rule_fund_35c_params_fun,
    example = list(credit = list(total_share = 0.20, schedule_shares = c(0.07, 0.07, 0.06),
                                 cap_per_object_eur = 40000, energy_advice_share = 0.50))
  )
}
