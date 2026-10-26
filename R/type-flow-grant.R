# Zahlungstyp grant: Investitionszuschuss eines Foerderinstruments (WS-E2, Spec 01 Teil B 4.5).
# Bemessung auf den realisierten Kosten der Massnahmen (capex-Zeilen der Abhaengigkeiten,
# inkl. Preisindex, Verschiebung und Aktivierungsfaktor) mal foerderfaehigem Anteil (Parameter
# eligible_shares des Expanders, KG-Filter, sonst funding.<f>.eligible_shares), Deckel je Gruppe
# (eine Gruppe bzw. je Kalenderjahr der Fertigstellung), Bonus ueber einer Schwelle, Hoechstsatz,
# Zusage je Lauf und Auszahlung zum Datumstermin nach R-98 (ctx$shift_period; Termine vor dem
# Stichtag bzw. nach dem Horizont werden nicht gebucht, je mit eigenem Hinweis). Vektorisiert
# ueber die Laeufe; die Schleifen laufen nur ueber Massnahmen und Deckelgruppen.

#' Zahlenwert eines Domänenblatts je Lauf (n-Vektor) oder `default`, falls der Pfad fehlt
#' @param ctx Laufkontext.
#' @param path Domänenpfad.
#' @param default Rückgabe bei fehlendem Pfad.
#' @param base Basisfallwert (`ctx$value_base()`).
#' @noRd
fund_dom_num <- function(ctx, path, default = NULL, base = FALSE) {
  if (is.null(path_get(ctx$spec, path))) return(default)
  v <- if (base) ctx$value_base(path) else ctx$value(path)
  if (is.null(v)) default else rep_len(as.double(v), ctx$n)
}

#' Maßnahmen eines Förderbausteins (Parameter `measures`, sonst Metafeld `measure_id`)
#' @noRd
fund_type_measures <- function(spec) {
  ms <- as.character(unlist(spec[["measures"]], use.names = FALSE))
  if (length(ms) == 0L && utl_is_string(spec[["measure_id"]])) ms <- spec[["measure_id"]]
  ms
}

#' Realisierte Kosten K_m einer Maßnahme je Lauf (Teil B 4.4)
#'
#' K_m = −Σ der capex-Zeilen der Komponenten `cost_components` mit `measure_id = m` (alle
#' Perioden); ohne Kostenkomponente der Maßnahme a_m · `measures.<m>.cost_eur` bzw. 0.
#' @return n-Vektor.
#' @noRd
fund_measure_cost <- function(ctx, cost_ids, m) {
  n <- ctx$n
  if (length(cost_ids) > 0L) {
    rows <- ctx$rows(id = cost_ids, category = "capex", measure_id = m)
    if (length(rows) > 0L) return(-rowSums(Reduce(`+`, rows)))
  }
  k0 <- fund_dom_num(ctx, paste0("measures.", m, ".cost_eur"), NULL)
  if (is.null(k0)) return(rep(0, n))
  act(ctx, m) * k0
}

#' Basisfallkosten K⁰_m einer Maßnahme (Gewichte eines festen Zuschussbetrags, Teil B 4.5)
#' @return Skalar (≥ 0).
#' @noRd
fund_measure_base_cost <- function(ctx, cost_ids, m) {
  k0 <- fund_dom_num(ctx, paste0("measures.", m, ".cost_eur"), NULL, base = TRUE)
  if (!is.null(k0)) return(max(as.double(k0[1L]), 0))
  tot <- 0
  for (cid in cost_ids) {
    fl <- ctx$component_base(cid)
    for (r in fl$rows) {
      if (identical(r$category, "capex") && identical(r$measure_id %||% fl$meta$measure_id, m)) {
        tot <- tot - sum(r$values[1L, ])
      }
    }
  }
  max(tot, 0)
}

#' Fertigstellung einer Maßnahme (Domäne, sonst Metafeld der Kostenkomponente; ohne Verschiebung)
#' @return `Date` oder `NULL`.
#' @noRd
fund_measure_completion <- function(ctx, cost_ids, m) {
  d <- if (!is.null(ctx$spec$measures[[m]])) rp_measure_completion(ctx, m) else NULL
  if (!is.null(d)) return(d)
  for (cid in cost_ids) {
    fl <- ctx$component(cid)
    if (identical(fl$meta$measure_id, m) && inherits(fl$meta$completion_date, "Date")) {
      return(fl$meta$completion_date)
    }
  }
  NULL
}

#' Periode eines verschobenen Termins je Lauf mit Kennung „vor dem Stichtag“ (R-98)
#'
#' Wie `ctx$shift_period()`; zusätzlich `before` = Termin vor dem Stichtag (bereits ausgezahlt,
#' gehört nicht in das Modell, Teil B 4.5 Randfälle), im Unterschied zu `NA` nach dem Horizont.
#' @param date Bezugstermin (Länge 1).
#' @param months n-Vektor der Verschiebung in Monaten.
#' @return Liste `p` (integer n-Vektor, `NA` außerhalb des Rasters), `before` (lgl n-Vektor).
#' @noRd
fund_shift_period <- function(ctx, date, months) {
  d <- utl_as_date(date, "date")
  m <- typ_round_months(rep_len(as.double(months), ctx$n))
  p <- ctx$shift_period(d, m)
  dd <- grid_add_months(rep(d, ctx$n), m)
  before <- is.na(p) & as.numeric(dd) < as.numeric(ctx$grid$date_end[1L])
  list(p = p, before = before)
}

#' Hinweis „Auszahlung vor dem Stichtag, nicht gebucht“ (Teil B 4.5, 4.8)
#' @param lost lgl n-Vektor der Läufe mit nicht gebuchtem Betrag vor dem Stichtag.
#' @noRd
fund_inform_before <- function(ctx, spec, type, lost) {
  if (any(lost)) {
    ctx$inform(paste0("types.flow.", type, ".msg.before_valuation"), id = spec[["id"]] %||% "?",
               share = mean(lost))
  }
  invisible(NULL)
}

#' Auszahlungsperiode je Lauf nach Ereignis und Verzug (Teil B 4.5, R-98)
#' @return Liste `p` (integer n-Vektor; NA = vor dem Stichtag bzw. nach dem Horizont), `before`.
#' @noRd
grant_payout_period <- function(ctx, spec, m, cost_ids, event, lag, delay) {
  if (identical(event, "commitment")) {
    ad <- ctx$setting(spec, "application_date") %||% ctx$grid$valuation_date
    return(fund_shift_period(ctx, utl_as_date(ad, "application_date"),
                             lag + typ_round_months(delay)))
  }
  cd <- fund_measure_completion(ctx, cost_ids, m)
  if (is.null(cd)) {
    ctx$abort("types.flow.grant.msg.no_completion", id = spec[["id"]] %||% "?", measure = m)
  }
  s_m <- if (!is.null(ctx$spec$measures[[m]])) rp_measure_shift(ctx, m) else rep(0, ctx$n)
  fund_shift_period(ctx, cd, lag + s_m + typ_round_months(delay))
}

#' Förderfähiger Anteil e_m je Lauf (Teil B 4.4, 4.5)
#'
#' Parameter `eligible_shares.<m>` (vom Expander gesetzt: Bezug auf
#' `funding.<f>.eligible_shares.<m>` bzw. 0 bei Ausschluss durch den KG-Filter), sonst der
#' Domänenpfad `funding.<funding_id>.eligible_shares.<m>` (Domänenlesezugriff), sonst 1.
#' @param domain Domänenpfad lesen (`grant`: ja; `tax_credit_35c`: nein).
#' @return n-Vektor.
#' @noRd
fund_type_share <- function(ctx, spec, m, domain = TRUE) {
  if (!is.null(spec[["eligible_shares"]][[m]])) {
    return(rep_len(as.double(ctx$param(spec, paste0("eligible_shares.", m))), ctx$n))
  }
  fid <- spec[["funding_id"]]
  ones <- rep(1, ctx$n)
  if (!domain || !utl_is_string(fid)) return(ones)
  fund_dom_num(ctx, paste0("funding.", fid, ".eligible_shares.", m), ones)
}

#' Zahlungskomponente grant bauen (Teil B 4.5)
#' @noRd
grant_build <- function(spec, ctx) {
  n <- ctx$n
  ms <- fund_type_measures(spec)
  if (length(ms) == 0L) ctx$abort("types.flow.grant.msg.no_measures", id = spec[["id"]] %||% "?")
  cost_ids <- as.character(unlist(spec[["cost_components"]], use.names = FALSE))
  fid <- spec[["funding_id"]]
  ones <- rep(1, n)
  a <- lapply(stats::setNames(ms, ms), function(m) act(ctx, m))
  share <- lapply(stats::setNames(ms, ms), function(m) fund_type_share(ctx, spec, m))
  k_raw <- lapply(stats::setNames(ms, ms), function(m) fund_measure_cost(ctx, cost_ids, m))
  fixed_cost <- ctx$param(spec, "eligible_cost_eur")
  ke <- if (is.null(fixed_cost)) {
    lapply(ms, function(m) share[[m]] * k_raw[[m]])
  } else {
    a_max <- Reduce(pmax, a)
    tot_raw <- Reduce(`+`, k_raw)
    lapply(ms, function(m) {
      w <- if (length(ms) == 1L) ones else
        ifelse(tot_raw > 0, k_raw[[m]] / (tot_raw + (tot_raw == 0)), 1 / length(ms))
      fixed_cost * a_max * w
    })
  }
  names(ke) <- ms
  rate <- ctx$param(spec, "rate")
  rate_cap <- ctx$param(spec, "rate_cap") %||% ones
  bonus_rate <- ctx$param(spec, "bonus_rate") %||% rep(0, n)
  threshold <- ctx$param(spec, "bonus_threshold_eur") %||% rep(0, n)
  cap <- ctx$param(spec, "cost_cap_eur") %||% rep(Inf, n)
  mode <- ctx$setting(spec, "bonus_mode") %||% "excess_over_threshold"
  amount <- ctx$param(spec, "amount_eur")
  approved <- ctx$param(spec, "approved") %||% ones
  period_mode <- ctx$setting(spec, "cap_period") %||% "total"
  completion <- lapply(stats::setNames(ms, ms), function(m) {
    fund_measure_completion(ctx, cost_ids, m)
  })
  groups <- if (identical(period_mode, "calendar_year")) {
    vapply(ms, function(m) {
      d <- completion[[m]]
      if (is.null(d)) "na" else as.character(utl_year(d))
    }, character(1))
  } else {
    rep("all", length(ms))
  }
  k0 <- if (is.null(amount)) NULL else
    vapply(ms, function(m) fund_measure_base_cost(ctx, cost_ids, m), double(1))
  if (!is.null(k0)) names(k0) <- ms
  g_m <- list()
  kcap_m <- list()
  for (gr in unique(groups)) {
    mg <- ms[groups == gr]
    k_g <- Reduce(`+`, ke[mg])
    kff <- pmin(k_g, cap)
    b <- if (identical(mode, "whole_amount")) kff else pmax(kff - threshold, 0)
    g_g <- pmin(rate * kff + bonus_rate * b, rate_cap * kff)
    if (!is.null(amount)) {
      tot0 <- sum(k0)
      g_g <- if (tot0 > 0) {
        amount * Reduce(`+`, lapply(mg, function(m) k0[[m]] * a[[m]])) / tot0
      } else {
        amount * Reduce(pmax, a[mg]) * length(mg) / length(ms)
      }
    }
    g_g <- pmax(g_g, 0) * (k_g > 0 | !is.null(amount))
    for (m in mg) {
      w <- if (length(mg) == 1L) ones else ke[[m]] / (k_g + (k_g == 0))
      if (!is.null(amount) && length(mg) > 1L) {
        w0 <- k0[[m]] * a[[m]]
        den <- Reduce(`+`, lapply(mg, function(j) k0[[j]] * a[[j]]))
        w <- ifelse(k_g > 0, w, w0 / (den + (den == 0)))
      }
      g_m[[m]] <- g_g * w
      kcap_m[[m]] <- kff * w
    }
  }
  event <- ctx$setting(spec, "payout_event") %||% "completion_proof"
  lag <- as.integer(ctx$setting(spec, "payout_lag_months") %||% 0L)
  delay <- typ_shift_param(ctx, spec, "payout_delay_months")
  aux <- list(eligible_cost = ctx$zeros(), capped_cost = ctx$zeros(), grant_gross = ctx$zeros())
  rows <- list()
  lost <- rep(FALSE, n)
  lost_before <- rep(FALSE, n)
  for (m in ms) {
    pp <- grant_payout_period(ctx, spec, m, cost_ids, event, lag, delay)
    p <- pp$p
    hit <- is.na(p) & abs(g_m[[m]] * approved) > 0
    lost <- lost | (hit & !pp$before)
    lost_before <- lost_before | (hit & pp$before)
    rows[[length(rows) + 1L]] <- vofi_row(
      paste0("grant_", m), typ_book(ctx$zeros(), p, g_m[[m]] * approved), section = "grants",
      category = "grant", tax_category = "subsidy_investment", measure_id = m, vat_rate = 0,
      program = spec[["program"]]
    )
    aux$eligible_cost <- typ_book(aux$eligible_cost, p, ke[[m]])
    aux$capped_cost <- typ_book(aux$capped_cost, p, kcap_m[[m]])
    aux$grant_gross <- typ_book(aux$grant_gross, p, g_m[[m]])
  }
  typ_inform_after_horizon(ctx, spec, "grant", lost)
  fund_inform_before(ctx, spec, "grant", lost_before)
  aux$rate_effective <- typ_safe_div(aux$grant_gross, aux$capped_cost)
  vofi_flows(rows, aux = aux,
             meta = list(measure_id = spec[["measure_id"]] %||% ms[1L], funding_id = fid,
                         measures = ms))
}

#' Befund eines Fördertyps mit Schlüssel `types.flow.<typ>.msg.<code>`
#' @noRd
fund_type_finding <- function(type, severity, code, spec, scenario, field = NULL, ...) {
  id <- spec[["id"]] %||% "?"
  coll <- if (id %in% names(scenario[["financing"]])) "financing" else "components"
  new_vofi_finding(severity, paste0("types.flow.", type, ".msg.", code),
                   path_join(coll, id, field), args = c(list(id = id), list(...)))
}

#' Prüfungen der Komponente grant (Teil B 4.5)
#' @noRd
grant_validate <- function(spec, scenario) {
  out <- list()
  ms <- fund_type_measures(spec)
  if (length(ms) == 0L) {
    out[[length(out) + 1L]] <- fund_type_finding("grant", "error", "no_measures", spec, scenario,
                                                 "measures")
  }
  cost_ids <- as.character(unlist(spec[["cost_components"]], use.names = FALSE))
  miss <- setdiff(cost_ids, as.character(unlist(spec[["after"]], use.names = FALSE)))
  if (length(miss) > 0L) {
    out[[length(out) + 1L]] <- fund_type_finding("grant", "error", "cost_not_after", spec,
                                                 scenario, "cost_components",
                                                 components = utl_collapse(miss))
  }
  c(out, fund_share_findings("grant", spec, scenario, ms))
}

#' Prüfung des Parameters `eligible_shares`: Schlüssel müssen geförderte Maßnahmen sein (E)
#' @noRd
fund_share_findings <- function(type, spec, scenario, ms) {
  extra <- setdiff(names(spec[["eligible_shares"]] %||% list()), ms)
  if (length(extra) == 0L) return(list())
  list(fund_type_finding(type, "error", "share_measure_unknown", spec, scenario,
                         "eligible_shares", measures = utl_collapse(extra)))
}

#' @noRd
typedef_grant <- function() {
  p <- vofi_param
  vofi_type(
    name = "grant", kind = "flow",
    params = list(
      measures = p("ids", default = list()),
      cost_components = p("ids", default = list()),
      eligible_cost_eur = p("value", min = 0, unit = "EUR", shapes = "scalar"),
      eligible_shares = p("map", fields = list("*" = p("value", min = 0, max = 1,
                                                       shapes = "scalar"))),
      rate = p("value", required = TRUE, min = 0, max = 1, shapes = "scalar"),
      rate_cap = p("value", default = 1, min = 0, max = 1, shapes = "scalar"),
      bonus_rate = p("value", default = 0, min = 0, max = 1, shapes = "scalar"),
      bonus_threshold_eur = p("amount", default = 0, min = 0, unit = "EUR"),
      bonus_mode = p("enum", values = "vocab:bonus_mode", default = "excess_over_threshold"),
      cost_cap_eur = p("amount", default = Inf, min = 0, unit = "EUR"),
      cap_period = p("enum", values = "vocab:cap_period", default = "total"),
      amount_eur = p("value", min = 0, unit = "EUR", shapes = "scalar"),
      approved = p("value", default = 1, min = 0, max = 1, shapes = "scalar"),
      payout_event = p("enum", values = "vocab:payout_event", default = "completion_proof"),
      payout_lag_months = p("integer", default = 0L, min = 0),
      payout_delay_months = p("number", default = 0, min = 0, unit = "months"),
      application_date = p("date", grid_default = "valuation_date")
    ),
    rows = "grant_*",
    grid_invariant = TRUE,
    domain_reads = c("measures", "funding"),
    validate = grant_validate,
    build = grant_build,
    example = list(type = "grant", measure_id = "m1", eligible_cost_eur = 100000, rate = 0.3,
                   cost_cap_eur = 80000, payout_event = "commitment",
                   application_date = "2027-01-01")
  )
}
