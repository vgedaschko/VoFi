# Zahlungstyp pv: Photovoltaikanlage (WS-E, Spec 00 Abschnitt 7.10, R-84; Spec 01 Teil B
# Abschnitt 3.9). Ertrag mit Alterung ab Inbetriebnahme (Monatsgewichte, Aktivierung der Maßnahme),
# Eigenverbrauch bis zum Bezug des Eigenverbrauchsträgers (Begrenzung je Monat, Monatsrechnung
# 0.4), Einspeisung mit fester Vergütung über tariff_years und Anschlusspreis, Verrechnung an
# Mieter, Betriebskosten. Erlöszeilen ohne USt
# (Kleinunternehmer, § 19 UStG), Betriebskosten mit 19 %. Steuerbefreiung § 3 Nr. 72 EStG über
# tax_exempt (auto: kwp <= 30 je Einheit und <= 100). Das Begünstigungsattribut der Investition
# (Nullsteuersatz § 12 Abs. 3 Nr. 1 UStG) wertet pv_investment_vat_rate() aus.

#' USt-Satz der PV-Investition nach § 12 Abs. 3 Nr. 1 UStG (Spec 00 § 7.10, R-84)
#'
#' Nullsteuersatz bis `max_kwp` ohne Nachweis, darüber nur mit Begünstigungsattribut.
#' @param kwp Nennleistung (Vektor).
#' @param attested logisch: Nachweis der Begünstigung (`vat_zero_rate_attested`).
#' @param max_kwp Schwelle ohne Nachweis (Rechtswert, Standard 30).
#' @return Vektor der Sätze (0 bzw. 0.19).
#' @noRd
pv_investment_vat_rate <- function(kwp, attested = FALSE, max_kwp = 30) {
  ifelse(kwp <= max_kwp | as.logical(attested), 0, 0.19)
}

#' Mischsatz der Einspeisevergütung nach Leistungsstufen (Teil B 3.9.1, N-16)
#' @param kwp Nennleistung (Vektor oder Matrix).
#' @param le10,s10_40,s40_100 Sätze der Stufen bis 10, 10 bis 40 und 40 bis 100 kWp.
#' @return Satz je kWh (Form von `kwp`).
#' @noRd
pv_tariff_mix <- function(kwp, le10, s10_40, s40_100) {
  (pmin(kwp, 10) * le10 + pmin(pmax(kwp - 10, 0), 30) * s10_40 +
     pmin(pmax(kwp - 40, 0), 60) * s40_100) / pmax(kwp, 1e-300)
}

#' Steuerbefreiung § 3 Nr. 72 EStG (Code auto/yes/no; auto über Basisfallwerte)
#' @noRd
pv_tax_exempt <- function(code, kwp_base, n_units) {
  if (identical(code, "yes")) return(TRUE)
  if (identical(code, "no")) return(FALSE)
  all(kwp_base <= 30 * max(1, n_units)) && all(kwp_base <= 100)
}

#' Einspeisevergütung je kWh als Pfad: Parameter bzw. Mischsatz aus market.feed_in_tariff.*
#' @noRd
pv_feed_in_tariff <- function(ctx, spec, mode, kwp, kwp_base) {
  v <- ctx$param(spec, "feed_in_tariff_eur_kwh", "path")
  if (!is.null(v)) return(v)
  mk <- function(cls) {
    if (is.null(path_get(ctx$spec, paste0("market.feed_in_tariff.", cls)))) return(NULL)
    ctx$market(paste0("feed_in_tariff.", cls))
  }
  if (identical(mode, "full")) {
    ft <- mk("full_le10kwp")
    if (any(kwp_base > 10) || is.null(ft)) {
      vofi_abort("types.flow.pv.msg.tariff_missing", mode = mode,
                 kwp = format(max(kwp_base)), .class = "vofi_error_input")
    }
    return(ft)
  }
  le10 <- mk("partial_le10kwp")
  s10 <- mk("partial_10_40kwp")
  s40 <- mk("partial_40_100kwp")
  if (any(kwp_base > 100) || is.null(le10) || (any(kwp_base > 10) && is.null(s10)) ||
        (any(kwp_base > 40) && is.null(s40))) {
    vofi_abort("types.flow.pv.msg.tariff_missing", mode = mode,
               kwp = format(max(kwp_base)), .class = "vofi_error_input")
  }
  zero <- ctx$zeros()
  pv_tariff_mix(ctx$by_sim(kwp), le10, s10 %||% zero, s40 %||% zero)
}

#' Monatsverteilung des Periodenbezugs eines Eigenverbrauchssegments (n x M)
#'
#' Anteil des Monats m am Bezug der Periode p(m): w_s(m) / Σ_{m' ∈ p(m)} w_s(m') mit den
#' Monatsgewichten des Zustands des Segments (`meta$state`, `meta$construction_delay_months` von
#' energy_cost; 3.4); ohne Zustandsangabe gleichmäßig über die Monate der Periode. Innerhalb einer
#' Periode sind Menge und Preis des Segments konstant, die Verteilung ist deshalb exakt.
#' @param fl `vofi_flows` des Segments.
#' @noRd
pv_segment_months <- function(ctx, fl) {
  st <- fl$meta$state
  big_m <- rp_months(ctx$grid)$M
  w <- if (is.null(st)) {
    matrix(1, ctx$n, big_m)
  } else {
    en_state_months(ctx, st, fl$meta$construction_delay_months %||% rep(0, ctx$n))
  }
  den <- ctx$to_months(ctx$to_periods(w), "repeat")
  out <- w / pmax(den, 1e-300)
  out[den <= 0] <- 0
  out
}

#' @noRd
pv_build <- function(spec, ctx) {
  g <- ctx$grid
  n <- ctx$n
  mo <- rp_months(g)
  big_m <- mo$M
  par <- function(nm, shape = "scalar") ctx$param(spec, nm, shape)
  set <- function(nm) ctx$setting(spec, nm)
  meas <- rp_code(set("measure"))
  com_raw <- set("commissioning_date")
  com <- if (!is.null(com_raw)) {
    rp_as_date(com_raw, g)
  } else if (!is.null(meas)) {
    rp_measure_completion(ctx, meas) %||% g$completion_date
  } else {
    g$valuation_date
  }
  sc <- if (!is.null(meas)) rp_measure_shift(ctx, meas) else rep(0, n)
  a <- if (!is.null(meas)) act(ctx, meas) else rep(1, n)
  mm <- matrix(as.double(mo$m), n, big_m, byrow = TRUE)
  start <- matrix(rp_mi(g, com) + sc, n, big_m)
  ty <- as.double(set("tariff_years") %||% 20L)
  w_pv <- (mm >= start) * matrix(a, n, big_m)
  in_t <- (mm < start + 12 * ty) * 1
  om <- ctx$to_periods(w_pv) / 12
  kwp <- rep_len(par("kwp"), n)
  kwp_base <- ctx$param_base(spec, "kwp")
  yld <- par("specific_yield_kwh_kwp", "path") %||% (ctx$zeros() + 950)
  dpa <- rep_len(par("degradation_pa") %||% 0, n)
  age <- pmax(g$year - utl_year(com), 0)
  # Monatsrechnung (Teil B 0.4): Ertrag, Bezug und Eigenverbrauchsgrenze je Monat, damit ein
  # unterjähriger Beginn des Bezugs (Zustandswechsel) rasterunabhängig wirkt (F10)
  e_pa <- kwp * yld * (1 - matrix(dpa, n, g$T + 1L))^ctx$by_period(age)
  e_m <- ctx$to_months(e_pa, "repeat") * w_pv / 12
  e_kwh <- ctx$to_periods(e_m)
  sc_ids <- rp_ids(set("self_consumption_components"))
  d_m <- matrix(Inf, n, big_m)
  w_m <- matrix(0, n, big_m)
  kwh <- ctx$zeros()
  work <- ctx$zeros()
  if (length(sc_ids) > 0L) {
    d_m[] <- 0
    for (id in sc_ids) {
      fl <- ctx$component(id)
      ax <- fl$aux
      sm <- pv_segment_months(ctx, fl)
      kwh_s <- ax$kwh %||% ctx$zeros()
      work_s <- ax$work_gross %||% ctx$zeros()
      kwh <- kwh + kwh_s
      work <- work + work_s
      d_m <- d_m + ctx$to_months(kwh_s, "repeat") * sm
      w_m <- w_m + ctx$to_months(work_s, "repeat") * sm
    }
  }
  p_m <- ifelse(is.finite(d_m) & d_m > 0, w_m / pmax(d_m, 1e-300), 0)
  share <- par("self_consumption_share", "path") %||% ctx$zeros()
  mode <- rp_code(set("feed_in_mode")) %||% "partial"
  if (identical(mode, "full")) share <- ctx$zeros()
  s_m <- pmin(e_m * ctx$to_months(share, "repeat"), d_m)
  f_m <- e_m - s_m
  s_kwh <- ctx$to_periods(s_m)
  f_kwh <- e_kwh - s_kwh
  self_val <- ctx$to_periods(s_m * p_m)
  p_avg <- ifelse(kwh > 0, work / pmax(kwh, 1e-300), 0)
  p_s <- ifelse(s_kwh > 0, self_val / pmax(s_kwh, 1e-300), p_avg)
  tariff <- pv_feed_in_tariff(ctx, spec, mode, kwp, kwp_base)
  post <- par("post_tariff_price_eur_kwh", "path") %||% ctx$zeros()
  internal <- par("internal_price_eur_kwh", "path") %||% ctx$zeros()
  feed_val <- ctx$to_periods(f_m * (ctx$to_months(tariff, "repeat") * in_t +
                                      ctx$to_months(post, "repeat") * (1 - in_t)))
  o_raw <- par("owner_share")
  selbst <- identical(ctx$perspective, "selbstnutzer")
  o <- ctx$by_sim(rep_len(o_raw %||% (if (selbst) 1 else 0), n))
  opex_pa <- par("opex_eur_pa")
  if (is.null(opex_pa)) {
    cost <- if (!is.null(meas)) rp_num(ctx, paste0("measures.", meas, ".cost_eur")) else NULL
    if (is.null(cost)) {
      vofi_abort("types.flow.pv.msg.opex_missing", .class = "vofi_error_input")
    }
    opex_pa <- rep_len(par("opex_share_of_cost") %||% 0.012, n) * cost
  }
  growth <- par("opex_growth", "path")
  if (is.null(growth)) {
    growth <- if (is.null(path_get(ctx$spec, "market.inflation"))) ctx$zeros() else
      ctx$market("inflation")
  }
  idx <- ctx$index_year(growth, oc_base_date(ctx, spec))
  n_units <- mr_num(path_get(ctx$spec, "building.n_units")) %||% 1
  exempt <- pv_tax_exempt(rp_code(set("tax_exempt")) %||% "auto", kwp_base, n_units)
  tc_cost <- if (selbst || exempt) "expense_nondeductible" else "expense_deductible"
  mid <- meas
  rows <- list(
    vofi_row("feed_in", feed_val, section = "project",
             category = "energy_income",
             tax_category = if (exempt) "income_tax_exempt" else "income_other_taxable",
             vat_rate = 0, measure_id = mid),
    vofi_row("self_consumption", o * self_val, section = "project",
             category = "energy_saving", tax_category = "imputed_benefit", vat_rate = 0,
             measure_id = mid),
    vofi_row("internal_sale", (1 - o) * s_kwh * internal, section = "project",
             category = "energy_income", tax_category = "income_other_taxable", vat_rate = 0,
             measure_id = mid),
    vofi_row("opex", -ctx$by_sim(opex_pa) * idx * om, section = "project",
             category = "operating_cost", tax_category = tc_cost, vat_rate = 0.19,
             measure_id = mid),
    vofi_row("generation", e_kwh, section = "memo", category = "energy_quantity", unit = "kWh",
             measure_id = mid),
    vofi_row("feed_in_kwh", f_kwh, section = "memo", category = "energy_quantity",
             unit = "kWh", measure_id = mid)
  )
  aux <- list(self_kwh = s_kwh, self_kwh_rented = (1 - o) * s_kwh, unit_price_self = p_s,
              internal_charge = (1 - o) * s_kwh * internal, weight = om)
  vofi_flows(rows, aux = aux, meta = list(tax_exempt = exempt))
}

#' @noRd
typedef_pv <- function() {
  p <- vofi_param
  vofi_type(
    name = "pv", kind = "flow",
    params = list(
      kwp = p("number", required = TRUE, min = 0, unit = "kWp"),
      measure = p("string"),
      commissioning_date = p("timing"),
      specific_yield_kwh_kwp = p("value", default = 950, unit = "kWh_pa"),
      degradation_pa = p("rate", default = 0),
      self_consumption_share = p("value", default = 0, unit = "share"),
      self_consumption_components = p("ids", default = list()),
      feed_in_mode = p("enum", values = c("partial", "full"), default = "partial"),
      feed_in_tariff_eur_kwh = p("value", unit = "EUR_kwh"),
      tariff_years = p("integer", default = 20L, min = 0),
      post_tariff_price_eur_kwh = p("value", default = 0, unit = "EUR_kwh"),
      internal_price_eur_kwh = p("value", default = 0, unit = "EUR_kwh"),
      opex_share_of_cost = p("share", default = 0.012),
      opex_eur_pa = p("amount", min = 0, unit = "EUR"),
      opex_growth = p("value", unit = "rate_pa"),
      base_date = p("timing"),
      owner_share = p("share"),
      tax_exempt = p("enum", values = c("auto", "yes", "no"), default = "auto")
    ),
    rows = c("feed_in", "self_consumption", "internal_sale", "opex", "generation",
             "feed_in_kwh"),
    grid_invariant = TRUE,
    domain_reads = c("energy", "measures", "funding", "building", "market"),
    build = function(spec, ctx) pv_build(spec, ctx),
    example = list(type = "pv", kwp = 30, specific_yield_kwh_kwp = 900,
                   self_consumption_share = 0.3, feed_in_tariff_eur_kwh = 0.0700667,
                   degradation_pa = 0.003, opex_eur_pa = 450, opex_growth = 0.02,
                   commissioning_date = "2027-01-01", base_date = "2027-01-01")
  )
}
