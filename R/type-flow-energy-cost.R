# Zahlungstyp energy_cost: Energiekosten eines Segments (Zustand × Energieträger) (WS-E, Spec 00
# Abschnitte 4.3.6b, 7.10, R-90, R-101; Spec 01 Teil B Abschnitte 3.1-3.6). Arbeitspreis netto mit
# Netzentgelt und Bio-Mehrkosten (CO2-Kosten schreibt der Typ co2_cost), Grundpreis und Wartung,
# jeweils mit USt; Kostenträger Eigentümer (o), Vermieter im Leerstand (v), Mieter (Rest, Merkzeile
# in tenant_costs). Merkzeilen: Endenergie (kWh) und Treibhausgasbilanz (t CO2-Äq.).
# Gültigkeitsfenster und Aktivierung der Zustände über en_state_weights() (3.4); Mengen mit
# Monatsgewichten, Preise je Kalenderjahr: grid_invariant = TRUE. Zusätzlich zu 3.6.4 liefert aux
# den Betriebsanteil `operating` (Monate mit gültigem Zustand / 12, Bezug des Stufenmodells in
# co2_cost) und meta Zustand und Bauzeitverzug (Monatsverteilung des Bezugs in pv).

# ---------------------------------------------------------------------------------------------
# Zustände (Teil B 3.4)
# ---------------------------------------------------------------------------------------------

#' Zustände des Energieblocks in zeitlicher Ordnung mit Beginn und Maßnahme
#' @return Liste je Zustand: `id`, `path`, `measure`, `date` (Basistermin), `token` (completion).
#' @noRd
en_states <- function(ctx) {
  en <- ctx$spec$energy %||% list()
  g <- ctx$grid
  out <- list()
  add <- function(id, st, path) {
    if (!is.list(st)) return(NULL)
    meas <- rp_code(st[["measure"]])
    raw <- st[["start_event"]]
    token <- identical(raw, "completion")
    date <- if (identical(id, "before")) {
      g$valuation_date
    } else if (!is.null(raw) && !token) {
      rp_as_date(raw, g)
    } else if (!is.null(meas)) {
      rp_measure_completion(ctx, meas) %||% g$completion_date
    } else {
      token <- TRUE
      g$completion_date
    }
    list(id = id, path = path, measure = meas, date = date, token = token && is.null(meas))
  }
  if (!is.null(en[["before"]])) out[["before"]] <- add("before", en[["before"]], "energy.before")
  if (!is.null(en[["after"]])) out[["after"]] <- add("after", en[["after"]], "energy.after")
  for (s in names(en[["stages"]] %||% list())) {
    out[[s]] <- add(s, en[["stages"]][[s]], paste0("energy.stages.", s))
  }
  out <- Filter(Negate(is.null), out)
  if (length(out) == 0L) return(out)
  is_before <- names(out) == "before"
  dates <- vapply(out, function(x) as.numeric(x$date), double(1))
  ord <- order(!is_before, dates, method = "radix")
  out[ord]
}

#' Monatsgewichte w_s(i, m) ∈ {0, 1} eines Zustands (Teil B 3.4)
#'
#' Ein Zustand gilt ab seinem (laufspezifisch verschobenen) Beginn bis zum Beginn des nächsten
#' aktiven Zustands; bei Aktivierungsfaktor 0 gilt der vorangehende Zustand weiter. Ohne
#' Energieblock bzw. ohne den Zustand gilt w = 1 ab dem Stichtag.
#' @param ctx Laufkontext.
#' @param state Zustands-id (`before`, `after` oder id aus `stages`).
#' @param construction_delay_months n-Vektor (Verschiebung beim Token `completion`).
#' @return n x M Monatsgewichte.
#' @noRd
en_state_months <- function(ctx, state, construction_delay_months = rep(0, ctx$n)) {
  states <- en_states(ctx)
  if (!(state %in% names(states))) return(matrix(1, ctx$n, rp_months(ctx$grid)$M))
  big_a <- en_state_activations(ctx, states, construction_delay_months)
  j <- match(state, names(states))
  w <- big_a[[j]]
  later <- seq_along(states)[seq_along(states) > j]
  for (l in later) w <- w * (1 - big_a[[l]])
  w
}

#' Aktivierungsmasken A_j(i, m) der Zustände (Teil B 3.4)
#' @param states Ausgabe von `en_states()`.
#' @inheritParams en_state_months
#' @return Liste je Zustand: n x M (0/1).
#' @noRd
en_state_activations <- function(ctx, states, construction_delay_months = rep(0, ctx$n)) {
  n <- ctx$n
  mo <- rp_months(ctx$grid)
  big_m <- mo$M
  mm <- matrix(as.double(mo$m), n, big_m, byrow = TRUE)
  cdm <- rp_shift(rep_len(construction_delay_months, n))
  lapply(states, function(st) {
    if (identical(st$id, "before")) return(matrix(1, n, big_m))
    sh <- if (!is.null(st$measure)) rp_measure_shift(ctx, st$measure) else if (st$token) cdm else
      rep(0, n)
    start <- rp_mi(ctx$grid, st$date) + sh
    a <- if (is.null(st$measure)) rep(1, n) else act(ctx, st$measure)
    matrix(a, n, big_m) * (mm >= matrix(start, n, big_m))
  })
}

#' Betriebsmonate des Energieblocks: 1, solange irgendein Zustand gilt (Teil B 3.4)
#'
#' Σ_j w_j(i, m) = 1 − Π_j (1 − A_j(i, m)); ohne Energieblock gilt 1 ab dem Stichtag. Bezugsgröße
#' der spezifischen Emission des Stufenmodells in Teiljahren (co2_cost, 3.7.2).
#' @inheritParams en_state_months
#' @return n x M (0/1).
#' @noRd
en_operating_months <- function(ctx, construction_delay_months = rep(0, ctx$n)) {
  states <- en_states(ctx)
  big_m <- rp_months(ctx$grid)$M
  if (length(states) == 0L) return(matrix(1, ctx$n, big_m))
  big_a <- en_state_activations(ctx, states, construction_delay_months)
  off <- matrix(1, ctx$n, big_m)
  for (a in big_a) off <- off * (1 - a)
  1 - off
}

#' Jahresanteil ω je Periode eines Zustands (Teil B 3.4): Σ_{m∈t} w(m) / 12
#' @inheritParams en_state_months
#' @return n x (T+1), Spalte 1 = 0.
#' @noRd
en_state_weights <- function(ctx, state, construction_delay_months = rep(0, ctx$n)) {
  ctx$to_periods(en_state_months(ctx, state, construction_delay_months)) / 12
}

#' Kalenderjahreswert einer Pfadmatrix je Periode (Spalte der ersten Periode des Jahres; 3.6.2)
#' @noRd
en_year_value <- function(grid, x) {
  x[, rp_year_col(grid, grid$year), drop = FALSE]
}

# ---------------------------------------------------------------------------------------------
# Typ energy_cost (Teil B 3.6)
# ---------------------------------------------------------------------------------------------

#' Größen eines Segments bei Gewicht ω (Teil B 3.6.2)
#' @noRd
en_segment <- function(ctx, inp, omega) {
  q <- (inp$quantity * inp$deg + inp$extra) * omega
  w <- q * (inp$c + inp$nf + inp$bio) * (1 + inp$vat)
  list(kwh = q, work_gross = w,
       network_gross = q * inp$nf * (1 + inp$vat),
       bio_gross = q * inp$bio * (1 + inp$vat),
       co2_gross = q * inp$co2u * (1 + inp$vat),
       co2_kg = q * inp$ef * (1 - inp$beta),
       fees_gross = (inp$bf + inp$sv) * omega)
}

#' @noRd
en_build <- function(spec, ctx) {
  g <- ctx$grid
  n <- ctx$n
  par <- function(nm, shape = "scalar") ctx$param(spec, nm, shape)
  path0 <- function(nm) par(nm, "path") %||% ctx$zeros()
  messages <- list()
  state <- ctx$setting(spec, "state") %||% "before"
  cdm <- rep_len(par("construction_delay_months") %||% 0, n)
  omega <- en_state_weights(ctx, state, cdm)
  inst <- ctx$setting(spec, "installation_date") %||% g$valuation_date
  age <- pmax(g$year - utl_year(inst), 0)
  dpa <- rep_len(par("efficiency_degradation_pa") %||% 0, n)
  deg <- (1 + matrix(dpa, n, g$T + 1L))^ctx$by_period(age)
  vat <- rep_len(par("vat_rate") %||% 0.19, n)
  gross <- identical(ctx$setting(spec, "price_basis"), "gross")
  vf <- if (gross) 1 / (1 + vat) else rep(1, n)
  pbd <- oc_base_date(ctx, spec, "price_base_date")
  nf <- en_year_value(g, path0("network_fee_eur_kwh")) * vf *
    ctx$index_year(path0("network_fee_growth"), pbd)
  pc <- ctx$rule("co2_params")(ctx$legal("co2kostaufg"), ctx$legal("bio_treppe"))
  s43 <- isTRUE(ctx$setting(spec, "section43"))
  beta <- if (s43) ctx$rule("bio_share_section43")(ctx$by_period(g$year), pc) else ctx$zeros()
  ef <- rep_len(par("emission_factor_kg_kwh") %||% 0, n)
  co2u <- ef / 1000 * en_year_value(g, path0("co2_price_eur_t")) * (1 - beta)
  price <- en_year_value(g, path0("price_eur_kwh")) * vf
  pidx <- ctx$index_year(path0("price_growth"), pbd)
  c_net <- if (identical(ctx$setting(spec, "price_includes"), "all")) {
    j2 <- min(2L, g$T + 1L)
    rest <- price - nf[, j2] - co2u[, j2]
    neg <- rowSums(rest < 0) > 0
    # 3.6.5: E bei deterministischem Wert, sonst W mit dem Anteil der Läufe
    if (identical(ctx$mode, "deterministic") && any(neg)) {
      ctx$abort("types.flow.energy_cost.msg.negative_rest_price_error",
                carrier = ctx$setting(spec, "carrier") %||% "", .class = "vofi_error_input")
    }
    messages[[1L]] <- rp_signal(ctx, "types.flow.energy_cost.msg.negative_rest_price", neg,
                                "warn", carrier = ctx$setting(spec, "carrier") %||% "")
    pmax(rest, 0) * pidx
  } else {
    price * pidx
  }
  bio <- beta * en_year_value(g, path0("bio_premium_eur_kwh"))
  fidx <- ctx$index_year(path0("fee_growth"), pbd)
  inp <- list(
    quantity = path0("quantity_kwh_pa"), extra = path0("extra_kwh_pa"), deg = deg,
    c = c_net, nf = nf, bio = bio, vat = vat, co2u = co2u, ef = ef, beta = beta,
    bf = rep_len(par("base_fee_eur_pa") %||% 0, n) * vf * (1 + vat) * fidx,
    sv = rep_len(par("service_eur_pa") %||% 0, n) * vf * (1 + vat) * fidx
  )
  seg <- en_segment(ctx, inp, omega)
  groups <- rp_ids(ctx$setting(spec, "unit_groups"))
  v <- rp_vacancy_share(ctx, groups, cdm)
  o <- rep_len(par("owner_share") %||% 0, n)
  vl <- !identical(ctx$setting(spec, "vacancy_landlord"), FALSE)
  f <- o + (1 - o) * v * vl
  selbst <- identical(ctx$perspective, "selbstnutzer")
  tc <- if (selbst) "expense_nondeductible" else "expense_deductible"
  vr <- ctx$param_base(spec, "vat_rate")[1L] %||% 0.19
  ghg <- path0("ghg_factor_kg_kwh")
  rows <- list(
    vofi_row("work", -f * seg$work_gross, section = "project", category = "energy_cost",
             tax_category = tc, vat_rate = vr),
    vofi_row("base_fee", -f * inp$bf * omega, section = "project", category = "energy_cost",
             tax_category = tc, vat_rate = vr),
    vofi_row("service", -f * inp$sv * omega, section = "project", category = "energy_cost",
             tax_category = tc, vat_rate = vr),
    vofi_row("quantity", seg$kwh, section = "memo", category = "energy_quantity", unit = "kWh"),
    vofi_row("emission", seg$kwh * ghg / 1000, section = "memo", category = "co2_emission",
             unit = "t_co2")
  )
  aux <- list(kwh = seg$kwh, co2_kg = seg$co2_kg, work_gross = seg$work_gross,
              network_gross = seg$network_gross, bio_gross = seg$bio_gross,
              co2_gross = seg$co2_gross, fees_gross = seg$fees_gross,
              unit_price_gross = (c_net + nf + bio) * (1 + vat), beta = beta,
              owner_share = ctx$by_sim(o), vacancy = v, cost_share_owner_landlord = f,
              weight = omega,
              operating = ctx$to_periods(en_operating_months(ctx, cdm)) / 12)
  if (isTRUE(ctx$setting(spec, "counterfactual_pre"))) {
    cf <- en_segment(ctx, inp, ctx$by_period(g$delta))
    aux$cf_kwh <- cf$kwh
    aux$cf_co2_kg <- cf$co2_kg
    aux$cf_work_gross <- cf$work_gross
    aux$cf_fees_gross <- cf$fees_gross
    aux$cf_network_gross <- cf$network_gross
    aux$cf_bio_gross <- cf$bio_gross
    aux$cf_co2_gross <- cf$co2_gross
  }
  mn <- rp_meta_notes(character(0), messages, carrier = ctx$setting(spec, "carrier") %||% "")
  vofi_flows(rows, aux = aux,
             meta = list(notes = mn$notes, note_keys = mn$note_keys, messages = mn$messages,
                         state = state, construction_delay_months = cdm))
}

#' @noRd
typedef_energy_cost <- function() {
  p <- vofi_param
  vofi_type(
    name = "energy_cost", kind = "flow",
    params = list(
      state = p("string", required = TRUE),
      carrier = p("string", required = TRUE),
      carrier_class = p("enum", values = "vocab:carrier_class", required = TRUE),
      quantity_kwh_pa = p("value", default = 0, unit = "kWh_pa"),
      extra_kwh_pa = p("value", default = 0, unit = "kWh_pa"),
      efficiency_degradation_pa = p("rate", default = 0),
      installation_date = p("date", grid_default = "valuation_date"),
      price_eur_kwh = p("value", required = TRUE, unit = "EUR_kwh"),
      price_includes = p("enum", values = "vocab:price_includes", default = "commodity"),
      price_basis = p("enum", values = "vocab:price_basis", default = "net"),
      price_growth = p("value", default = 0, unit = "rate_pa"),
      network_fee_growth = p("value", default = 0, unit = "rate_pa"),
      fee_growth = p("value", default = 0, unit = "rate_pa"),
      price_base_date = p("timing"),
      network_fee_eur_kwh = p("value", default = 0, unit = "EUR_kwh"),
      bio_premium_eur_kwh = p("value", default = 0, unit = "EUR_kwh"),
      base_fee_eur_pa = p("amount", default = 0, min = 0, unit = "EUR"),
      service_eur_pa = p("amount", default = 0, min = 0, unit = "EUR"),
      vat_rate = p("share", default = 0.19),
      emission_factor_kg_kwh = p("number", default = 0, min = 0, unit = "kg_kwh"),
      ghg_factor_kg_kwh = p("value", default = 0, unit = "kg_kwh"),
      co2_price_eur_t = p("value", default = 0, unit = "EUR_t"),
      section43 = p("logical", default = FALSE),
      owner_share = p("share", default = 0),
      unit_groups = p("ids", default = list()),
      vacancy_landlord = p("logical", default = TRUE),
      counterfactual_pre = p("logical", default = FALSE),
      construction_delay_months = p("number", default = 0, min = 0, unit = "months")
    ),
    rows = c("work", "base_fee", "service", "quantity", "emission"),
    grid_invariant = TRUE,
    domain_reads = c("energy", "measures", "funding", "unit_groups"),
    build = function(spec, ctx) en_build(spec, ctx),
    example = list(type = "energy_cost", state = "before", carrier = "gas",
                   carrier_class = "gas", quantity_kwh_pa = list(expr = "24500"),
                   price_eur_kwh = 0.0634, network_fee_eur_kwh = 0.0257,
                   emission_factor_kg_kwh = 0.181, ghg_factor_kg_kwh = 0.21672,
                   co2_price_eur_t = 65, owner_share = 1, base_fee_eur_pa = 180,
                   service_eur_pa = 250, price_base_date = "2027-01-01")
  )
}
