# Zahlungstyp replacement: Ersatzinvestitionen im Nutzungsdauerzyklus einer Massnahme bzw. eines
# Bestandsbauteils und Zeitwertpfad fuer den Restwert (WS-E, Spec 01 Teil A 4.10, Spec 00 3.9,
# 4.12 Nr. 8, R-60, R-105, R-108).
# Termine werden je Lauf ueber ctx$shift_period() gebucht (laufspezifische Nutzungsdauer und
# Verschiebungen); die Schleife laeuft ueber die Ersatzereignisse k (vektorisiert ueber die Laeufe),
# K_max haengt nur von der kleinsten Nutzungsdauer des Chunks ab und aendert kein Ergebnis eines
# Laufs (Batch-Invarianz).

#' Termin- und Kostendaten des Ersatzzyklus je Lauf (Spec 01 Teil A 4.10.2)
#'
#' Positionen sind Monate seit dem Bewertungsstichtag (stetig, `grid_month_pos()`); die Buchung
#' erfolgt über `ctx$shift_period()` mit dem jeweiligen Bezugstermin.
#' @return Liste mit `life` (L in Monaten), `base_pos` (Position des ersten Ersatzes), `ref`
#'   (Bezugstermin je Lauf: 1 = d1 mit Verschiebung `s1`, 2 = Ende Periode 1, 3 = Stichtag),
#'   `s1`, `d1`, `until_pos`, `init` (Erstinvestition: `cost`, `pos`, `period`).
#' @noRd
repl_cycle <- function(ctx, spec, cap, include_initial) {
  g <- ctx$grid
  n <- ctx$n
  life <- ctx$param(spec, "useful_life_years")
  if (is.null(life)) {
    ctx$abort("types.flow.replacement.msg.no_life", id = spec[["id"]] %||% "?")
  }
  big_l <- pmax(typ_round_months(12 * life), 1)
  s0 <- typ_round_months(typ_shift_param(ctx, spec, "install_shift_months"))
  d0 <- utl_as_date(ctx$setting(spec, "install_date"), "install_date")
  fd <- ctx$setting(spec, "first_date")
  if (!is.null(fd)) {
    d1 <- utl_as_date(fd, "first_date")
    s1 <- typ_round_months(typ_shift_param(ctx, spec, "first_shift_months"))
  } else {
    d1 <- d0
    s1 <- s0 + big_l
  }
  pos_d1 <- grid_month_pos(g, d1)
  ref <- rep(1L, n)
  base_pos <- pos_d1 + s1
  if (!include_initial) {
    od <- base_pos <= 0
    policy <- ctx$setting(spec, "overdue") %||% "first_period"
    if (identical(policy, "first_period")) {
      ref[od] <- 2L
      base_pos[od] <- g$month_end[2L]
    } else if (identical(policy, "valuation")) {
      ref[od] <- 3L
      base_pos[od] <- 0
    } else {
      k_skip <- floor(-base_pos / big_l) + 1
      s1 <- s1 + od * k_skip * big_l
      base_pos <- pos_d1 + s1
    }
  }
  ud <- ctx$setting(spec, "until_date")
  until_pos <- rep(Inf, n)
  if (!is.null(ud)) {
    until_pos <- grid_month_pos(g, utl_as_date(ud, "until_date")) +
      typ_round_months(typ_shift_param(ctx, spec, "until_shift_months"))
  }
  list(life = big_l, base_pos = base_pos, ref = ref, s1 = s1, d1 = d1, d0 = d0, s0 = s0,
       until_pos = until_pos)
}

#' Periode des k-ten Ersatzes je Lauf (Bezugstermin nach `repl_cycle()`)
#' @noRd
repl_period <- function(ctx, cyc, k) {
  g <- ctx$grid
  step <- (k - 1) * cyc$life
  p <- ctx$shift_period(cyc$d1, cyc$s1 + step)
  if (any(cyc$ref == 2L)) {
    p2 <- ctx$shift_period(g$date_end[2L], step)
    p[cyc$ref == 2L] <- p2[cyc$ref == 2L]
  }
  if (any(cyc$ref == 3L)) {
    p3 <- ctx$shift_period(g$valuation_date, step)
    p[cyc$ref == 3L] <- p3[cyc$ref == 3L]
  }
  p
}

#' Letzte Investition vor bzw. in t eintragen (Zeitwertpfad, Spec 01 Teil A 4.10.2)
#' @param st Zustand `list(c_last, e_last, t_last)` (je n x (T+1)).
#' @param amount n-Vektor nominaler Betrag.
#' @param pos n-Vektor Position des Investitionstermins (Monate seit Stichtag).
#' @param period n-Vektor Periode der Investition (NA = ungültig).
#' @noRd
repl_track <- function(st, ctx, amount, pos, period) {
  n_t <- ctx$T + 1L
  ok <- !is.na(period)
  if (!any(ok)) return(st)
  me <- matrix(ctx$grid$month_end, ctx$n, n_t, byrow = TRUE)
  m <- (ok & matrix(pos, ctx$n, n_t) <= me + 1e-9)
  m[is.na(m)] <- FALSE
  st$c_last[m] <- matrix(amount, ctx$n, n_t)[m]
  st$e_last[m] <- matrix(pos, ctx$n, n_t)[m]
  st$t_last[m] <- matrix(as.double(period), ctx$n, n_t)[m]
  st
}

#' Zahlungskomponente replacement bauen (Spec 01 Teil A 4.10.2)
#' @noRd
replacement_build <- function(spec, ctx) {
  g <- ctx$grid
  n <- ctx$n
  n_t <- ctx$T + 1L
  zero <- rep(0, n)
  id <- spec[["id"]] %||% "?"
  include_initial <- !identical(ctx$setting(spec, "include_initial"), FALSE)
  enabled <- !identical(ctx$setting(spec, "enabled"), FALSE)
  capex_id <- ctx$setting(spec, "capex_id")
  cap <- if (utl_is_string(capex_id)) ctx$component(capex_id) else NULL
  if (include_initial && is.null(cap)) {
    ctx$abort("types.flow.replacement.msg.no_capex", id = id)
  }
  cost_eur <- ctx$param(spec, "cost_eur")
  active <- ctx$param(spec, "active") %||% rep(1, n)
  cost <- if (!is.null(cost_eur)) {
    cost_eur * active
  } else if (!is.null(cap) && !is.null(cap$aux$cost_base)) {
    cap$aux$cost_base[, 1L] * (ctx$param(spec, "cost_factor") %||% rep(1, n))
  } else {
    ctx$abort("types.flow.replacement.msg.no_cost", id = id)
  }
  bstar <- typ_price_base_date(ctx, spec)
  idx <- ctx$index(ctx$param(spec, "price_index", "path") %||% zero, base_date = bstar)
  cyc <- repl_cycle(ctx, spec, cap, include_initial)
  st <- list(c_last = ctx$zeros(), e_last = ctx$zeros(), t_last = ctx$zeros())
  if (include_initial) {
    c0 <- rowSums(cap$aux$cost_total)
    pos0 <- grid_month_pos(g, cyc$d0) + cyc$s0
    p0 <- ctx$shift_period(cyc$d0, cyc$s0)
    p0[pos0 > g$month_end[n_t] + 1e-9] <- NA_integer_
    st <- repl_track(st, ctx, c0, pos0, p0)
  } else {
    pos0 <- rep(grid_month_pos(g, cyc$d0), n)
    st <- repl_track(st, ctx, cost * idx[, 1L], pos0, rep(0L, n))
  }
  x <- ctx$zeros()
  if (enabled) {
    m_t <- g$month_end[n_t]
    # K_max je Chunk (kleinste Nutzungsdauer); weitere Ereignisse liegen in keinem Lauf im Horizont
    k_max <- max(1, ceiling((m_t - min(cyc$base_pos)) / min(cyc$life)) + 1)
    for (k in seq_len(k_max)) {
      pos_k <- cyc$base_pos + (k - 1) * cyc$life
      p_k <- repl_period(ctx, cyc, k)
      p_k[!(pos_k < cyc$until_pos)] <- NA_integer_
      amount <- cost * capex_index_at(idx, p_k)
      x <- typ_book(x, p_k, -amount)
      st <- repl_track(st, ctx, amount, pos_k, p_k)
    }
  }
  # Wertpfad: Alter der letzten Investition am Periodenende, null nach dem Ende des Zyklus
  me <- matrix(g$month_end, n, n_t, byrow = TRUE)
  has <- st$c_last != 0
  age_m <- (me - st$e_last) * has
  share <- pmax(0, 1 - age_m / matrix(cyc$life, n, n_t))
  share[!has] <- 0
  ended <- me >= matrix(cyc$until_pos, n, n_t) - 1e-9
  share[ended] <- 0
  i_last <- matrix(idx[cbind(rep(seq_len(n), n_t), as.integer(st$t_last) + 1L)], n, n_t)
  value_nominal <- st$c_last * share
  value <- st$c_last * idx / i_last * share
  value[!has | ended] <- 0
  vat <- typ_base_scalar(ctx, spec, "vat_rate", 0.19)
  cls <- ctx$setting(spec, "classification") %||% "erhaltung"
  row <- vofi_row("cost", x, section = "project", category = "replacement",
                  tax_category = typ_capex_tax(cls), asset_id = spec[["asset_id"]],
                  measure_id = spec[["measure_id"]], vat_rate = vat)
  vofi_flows(row,
             aux = list(value = value, value_nominal = value_nominal,
                        age_years = age_m / 12 * has, life_months = ctx$by_sim(cyc$life)),
             meta = list(include_initial = include_initial, enabled = enabled,
                         capex_id = capex_id, measure_id = spec[["measure_id"]]))
}

#' Prüfungen der Komponente replacement (Spec 01 Teil A 4.10.2)
#' @noRd
replacement_validate <- function(spec, scenario) {
  v <- typ_validator(spec, scenario, "replacement")
  life <- typ_const(spec[["useful_life_years"]])
  if (!is.null(life) && any(life <= 0)) {
    v$add("error", "life_nonpositive", "useful_life_years")
  } else if (!is.null(life) && any(life < 5)) {
    v$add("warning", "life_short", "useful_life_years", value = min(life))
  }
  inst <- typ_spec_date(spec[["install_date"]])
  first <- typ_spec_date(spec[["first_date"]])
  if (!is.null(inst) && !is.null(first) && first < inst) {
    v$add("error", "first_before_install", "first_date", date = first)
  }
  for (f in c("install_shift_months", "first_shift_months", "until_shift_months")) {
    x <- typ_const(spec[[f]])
    if (!is.null(x) && any(x < 0)) v$add("error", "shift_negative", f)
  }
  include_initial <- !identical(spec[["include_initial"]], FALSE)
  if (include_initial && is.null(spec[["capex_id"]])) v$add("error", "no_capex", "capex_id")
  if (!include_initial && is.null(spec[["cost_eur"]]) && is.null(spec[["capex_id"]])) {
    v$add("error", "element_cost_missing", "cost_eur")
  }
  vd <- typ_valuation_date(scenario)
  hy <- typ_const(scenario[["project"]][["horizon_years"]]) %||%
    suppressWarnings(as.double(scenario[["project"]][["horizon_years"]]))
  if (!is.null(life) && length(life) == 1L && life > 0 && !is.null(vd) && length(hy) == 1L &&
        !is.na(hy) && !is.null(inst)) {
    big_l <- max(1, floor(12 * life + 0.5))
    e1 <- if (!is.null(first)) first else grid_add_months(inst, big_l)
    end <- grid_add_months(vd, as.integer(12 * hy))
    span <- grid_months_between(max(e1, vd), end)
    count <- if (e1 > end) 0 else floor(span / big_l) + 1
    if (count > 10) v$add("warning", "many_events", "useful_life_years", value = count)
  }
  v$out
}

#' @noRd
typedef_replacement <- function() {
  p <- vofi_param
  vofi_type(
    name = "replacement", kind = "flow",
    params = list(
      capex_id = p("ref"),
      enabled = p("logical", default = TRUE),
      cost_eur = p("amount", min = 0, unit = "EUR"),
      cost_factor = p("number", default = 1, min = 0),
      price_base_year = p("integer"),
      price_index = p("value", default = list(ref = "market.construction_price_index"),
                      unit = "rate_pa"),
      vat_rate = p("share", default = 0.19),
      install_date = p("timing", required = TRUE),
      install_shift_months = p("number", default = 0, min = 0, unit = "months"),
      useful_life_years = p("number", required = TRUE, min = 0, unit = "years"),
      first_date = p("timing"),
      first_shift_months = p("number", default = 0, min = 0, unit = "months"),
      until_date = p("timing"),
      until_shift_months = p("number", default = 0, min = 0, unit = "months"),
      include_initial = p("logical", default = TRUE),
      overdue = p("enum", values = "vocab:overdue_policy", default = "first_period"),
      classification = p("enum", values = "vocab:classification", default = "erhaltung"),
      active = p("value", default = 1, min = 0, max = 1)
    ),
    rows = "cost",
    validate = replacement_validate,
    build = replacement_build,
    example = list(type = "replacement", asset_id = "b1", measure_id = "m1", capex_id = "cx",
                   install_date = "2027-07-01", useful_life_years = 2, price_index = 0.03,
                   cost_factor = 0.9,
                   .deps = list(cx = list(type = "capex", asset_id = "b1", measure_id = "m1",
                                          cost_eur = 50000, date = "2027-07-01")))
  )
}
