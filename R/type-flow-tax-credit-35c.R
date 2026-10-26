# Zahlungstyp tax_credit_35c: Steuerermaessigung fuer energetische Massnahmen an selbstgenutztem
# Wohneigentum nach Par. 35c EStG (WS-E2, Spec 01 Teil B 4.8; Spec 00 10.9, R-11, R-79, R-98).
# Drei Tranchen (Veranlagungsjahr der Fertigstellung und die zwei Folgejahre) mit Jahresdeckeln,
# Energieberatung im ersten Jahr, Gesamtdeckel je Objekt abzueglich bereits genutzter Betraege,
# optional gedeckelt durch die erwartete Einkommensteuer des Jahres; Zahlung nach Ende des
# Veranlagungsjahres plus Verzug. Vektorisiert ueber die Laeufe.

#' Datum (Y + k)-01-01 je Lauf
#' @noRd
tc35c_jan1 <- function(years) as.Date(sprintf("%04d-01-01", as.integer(years)))

#' Zahlungskomponente tax_credit_35c bauen (Teil B 4.8)
#' @noRd
tax_credit_35c_build <- function(spec, ctx) {
  n <- ctx$n
  ones <- rep(1, n)
  ms <- fund_type_measures(spec)
  if (length(ms) == 0L) {
    ctx$abort("types.flow.tax_credit_35c.msg.no_measures", id = spec[["id"]] %||% "?")
  }
  cost_ids <- as.character(unlist(spec[["cost_components"]], use.names = FALSE))
  a <- lapply(stats::setNames(ms, ms), function(m) act(ctx, m))
  a_max <- Reduce(pmax, a)
  # Aufwendungen K_m = e_m · realisierte Kosten (e_m: Parameter eligible_shares, sonst 1)
  k_m <- lapply(stats::setNames(ms, ms), function(m) {
    fund_type_share(ctx, spec, m, domain = FALSE) * fund_measure_cost(ctx, cost_ids, m)
  })
  k_raw <- Reduce(`+`, k_m)
  fixed_cost <- ctx$param(spec, "eligible_cost_eur")
  k_tot <- if (is.null(fixed_cost)) k_raw else fixed_cost * a_max
  w <- lapply(ms, function(m) {
    if (length(ms) == 1L) ones else
      ifelse(k_raw > 0, k_m[[m]] / (k_raw + (k_raw == 0)), 1 / length(ms))
  })
  names(w) <- ms
  # Abschluss je Lauf: spätester Termin der aktiven Maßnahmen (a_m > 0) mit Verschiebung; sind
  # alle inaktiv, der späteste Termin aller Maßnahmen (Beträge dann 0). Ohne Verschiebung: dc0.
  comp0 <- lapply(ms, function(m) fund_measure_completion(ctx, cost_ids, m))
  if (any(vapply(comp0, is.null, logical(1)))) {
    ctx$abort("types.flow.tax_credit_35c.msg.no_completion", id = spec[["id"]] %||% "?")
  }
  dc0 <- max(do.call(c, comp0))
  shifted <- lapply(seq_along(ms), function(j) {
    s <- if (!is.null(ctx$spec$measures[[ms[j]]])) rp_measure_shift(ctx, ms[j]) else rep(0, n)
    as.numeric(grid_add_months(rep(comp0[[j]], n), s))
  })
  masked <- lapply(seq_along(ms), function(j) ifelse(a[[j]] > 0, shifted[[j]], -Inf))
  dc_num <- Reduce(pmax, masked)
  dc_num <- ifelse(is.finite(dc_num), dc_num, Reduce(pmax, shifted))
  dc <- as.Date(dc_num, origin = "1970-01-01")
  y0 <- utl_year(dc)
  y00 <- utl_year(dc0)
  before <- ctx$setting(spec, "completion_before")
  before <- if (is.null(before)) as.Date("2030-01-01") else utl_as_date(before, "completion_before")
  ok <- as.double(dc < before)
  shares <- list(ctx$param(spec, "share_y1") %||% rep(0.07, n),
                 ctx$param(spec, "share_y2") %||% rep(0.07, n),
                 ctx$param(spec, "share_y3") %||% rep(0.06, n))
  total_share <- ctx$param(spec, "total_share") %||% rep(0.20, n)
  cap_total <- ctx$param(spec, "cap_total_eur") %||% rep(40000, n)
  ea_cost <- ctx$param(spec, "energy_advice_cost_eur") %||% rep(0, n)
  ea_share <- ctx$param(spec, "energy_advice_share") %||% rep(0.5, n)
  prior <- ctx$param(spec, "prior_used_eur") %||% rep(0, n)
  approved <- ctx$param(spec, "approved") %||% ones
  delay <- typ_shift_param(ctx, spec, "payout_delay_months")
  has_tax_cap <- !is.null(spec[["income_tax_cap_eur_pa"]])
  est <- if (has_tax_cap) ctx$param(spec, "income_tax_cap_eur_pa", "path") else NULL
  rem <- pmax(cap_total - prior, 0)
  out <- lapply(ms, function(m) ctx$zeros())
  names(out) <- ms
  aux <- list(tranche_1 = ctx$zeros(), tranche_2 = ctx$zeros(), tranche_3 = ctx$zeros(),
              capped_by_tax = ctx$zeros())
  capped_any <- rep(FALSE, n)
  lost <- rep(FALSE, n)
  lost_before <- rep(FALSE, n)
  for (i in 1:3) {
    cap_i <- typ_safe_div(shares[[i]] * cap_total, total_share)
    # Energieberatung nur, wenn mindestens eine Maßnahme aktiv ist (a_m = 0: als fehlte m)
    x <- pmin(shares[[i]] * k_tot, cap_i) + if (i == 1L) ea_share * ea_cost * a_max else 0
    x <- pmax(x, 0)
    tranche <- x
    capped <- rep(FALSE, n)
    if (!is.null(est)) {
      cols <- rp_year_col(ctx$grid, y0 + i - 1L)
      tax_y <- est[cbind(seq_len(n), cols)]
      capped <- x > tax_y + ctx$tol$zero_abs
      x <- pmin(x, pmax(tax_y, 0))
    }
    x <- pmin(x, rem)
    rem <- rem - x
    x <- x * ok * approved
    pp <- fund_shift_period(ctx, tc35c_jan1(y00 + i), 12 * (y0 - y00) + typ_round_months(delay))
    p <- pp$p
    lost <- lost | (is.na(p) & x > 0 & !pp$before)
    lost_before <- lost_before | (is.na(p) & x > 0 & pp$before)
    for (m in ms) out[[m]] <- typ_book(out[[m]], p, x * w[[m]])
    aux[[paste0("tranche_", i)]] <- typ_book(aux[[paste0("tranche_", i)]], p,
                                             tranche * ok * approved)
    capped_now <- capped & ok * approved > 0
    aux$capped_by_tax <- typ_book(aux$capped_by_tax, p, as.double(capped_now))
    capped_any <- capped_any | capped_now
  }
  typ_inform_after_horizon(ctx, spec, "tax_credit_35c", lost)
  fund_inform_before(ctx, spec, "tax_credit_35c", lost_before)
  late <- ok == 0 & approved > 0 & a_max > 0
  if (any(late)) {
    ctx$warn("types.flow.tax_credit_35c.msg.completion_late", id = spec[["id"]] %||% "?",
             date = before, share = mean(late), .class = "vofi_warning_plausibility")
  }
  if (any(capped_any)) {
    ctx$warn("types.flow.tax_credit_35c.msg.capped_by_tax", id = spec[["id"]] %||% "?",
             share = mean(capped_any), .class = "vofi_warning_plausibility")
  }
  rows <- lapply(ms, function(m) {
    vofi_row(paste0("credit_", m), out[[m]], section = "grants", category = "tax_credit",
             tax_category = "tax_credit", measure_id = m, vat_rate = 0,
             program = spec[["program"]])
  })
  vofi_flows(rows, aux = aux,
             meta = list(measure_id = spec[["measure_id"]] %||% ms[1L],
                         funding_id = spec[["funding_id"]], measures = ms,
                         completion_date = dc0))
}

#' Prüfungen der Komponente tax_credit_35c (Teil B 4.8)
#'
#' Perspektive bzw. Gruppen nicht selbstgenutzt (E), Gebäudealter < 10 Jahre zum Antrag (E,
#' sofern Baujahr bekannt), fehlende Einkommensteuer bei Deckelung (W).
#' @noRd
tax_credit_35c_validate <- function(spec, scenario) {
  # Befunde in einer lokalen Umgebung sammeln (keine Zuweisung nach aussen, Spec 00 2.7 Nr. 3)
  acc <- new.env(parent = emptyenv())
  acc$out <- list()
  add <- function(severity, code, field = NULL, ...) {
    acc$out[[length(acc$out) + 1L]] <- fund_type_finding("tax_credit_35c", severity, code, spec,
                                                         scenario, field, ...)
  }
  ms <- fund_type_measures(spec)
  if (length(ms) == 0L) add("error", "no_measures", "measures")
  persp <- scenario[["project"]][["perspective"]]
  groups <- scenario[["unit_groups"]] %||% list()
  rented <- vapply(groups, function(g) !isTRUE(exp_lgl(g[["owner_occupied"]])), logical(1))
  if ((utl_is_string(persp) && !identical(persp, "selbstnutzer")) || any(rented)) {
    add("error", "not_owner_occupied", NULL, perspective = persp %||% "-")
  }
  cy <- exp_num(scenario[["building"]][["construction_year"]])
  ad <- exp_date(scenario[["project"]][["application_date"]]) %||%
    exp_date(scenario[["project"]][["valuation_date"]])
  if (!is.null(cy) && !is.null(ad) && utl_year(ad) - cy[1L] < 10) {
    add("error", "building_too_young", NULL, age = utl_year(ad) - cy[1L])
  }
  if (!is.null(spec[["income_tax_cap_eur_pa"]]) &&
        is.null(scenario[["household"]][["expected_income_tax_eur_pa"]]) &&
        identical(spec[["income_tax_cap_eur_pa"]][["kind"]], "ref")) {
    add("warning", "income_tax_missing", "income_tax_cap_eur_pa")
  }
  c(acc$out, fund_share_findings("tax_credit_35c", spec, scenario, ms))
}

#' @noRd
typedef_tax_credit_35c <- function() {
  p <- vofi_param
  vofi_type(
    name = "tax_credit_35c", kind = "flow",
    params = list(
      measures = p("ids", default = list()),
      cost_components = p("ids", default = list()),
      eligible_cost_eur = p("value", min = 0, unit = "EUR", shapes = "scalar"),
      eligible_shares = p("map", fields = list("*" = p("value", min = 0, max = 1,
                                                       shapes = "scalar"))),
      share_y1 = p("share", default = 0.07),
      share_y2 = p("share", default = 0.07),
      share_y3 = p("share", default = 0.06),
      total_share = p("share", default = 0.20),
      cap_total_eur = p("amount", default = 40000, min = 0, unit = "EUR"),
      energy_advice_cost_eur = p("value", default = 0, min = 0, unit = "EUR", shapes = "scalar"),
      energy_advice_share = p("share", default = 0.5),
      prior_used_eur = p("value", default = 0, min = 0, unit = "EUR", shapes = "scalar"),
      income_tax_cap_eur_pa = p("value", min = 0, unit = "EUR"),
      completion_before = p("date", default = "2030-01-01"),
      approved = p("value", default = 1, min = 0, max = 1, shapes = "scalar"),
      payout_delay_months = p("number", default = 12, min = 0, unit = "months")
    ),
    rows = "credit_*",
    grid_invariant = TRUE,
    domain_reads = c("measures", "funding", "household"),
    validate = tax_credit_35c_validate,
    build = tax_credit_35c_build,
    example = list(type = "tax_credit_35c", measure_id = "m1", measures = "m1",
                   cost_components = "c1", after = "c1", completion_before = "2030-01-01",
                   income_tax_cap_eur_pa = list(ref = "household.expected_income_tax_eur_pa"),
                   .deps = list(c1 = list(type = "capex", measure_id = "m1", asset_id = "b1",
                                          cost_eur = 80000, date = "2027-03-01",
                                          completion_date = "2027-06-01", price_index = 0)))
  )
}
