# Zahlungstyp maintenance: laufende Instandhaltung als Pauschale je m2 (ImmoWertV Anlage 3), nach
# II. BV mit Altersklassen oder bauteilbezogen in % der Investition (WS-E, Spec 01 Teil A 4.11).
# Jahresbetrag mit Kalenderjahresindex (R-62), Wirkungszeitraum ueber ctx$timing() und
# ctx$shift_overlap() (3.9), Faktoren wirkender Massnahmen ueber deren aux$in_operation.

#' Beginn der Wirkung je Lauf aus einem Monatsanteilspfad (aux$in_operation)
#'
#' Position (Monate seit Stichtag) des ersten wirksamen Monats: in der ersten Periode j mit
#' positivem Anteil gilt Beginn = Monatsende der Periode − Anteil × Periodenmonate; ohne Wirkung
#' `NA`.
#' @param in_op n x (T+1) Monatsanteile.
#' @return double n-Vektor.
#' @noRd
typ_effect_start_pos <- function(ctx, in_op) {
  g <- ctx$grid
  out <- rep(NA_real_, ctx$n)
  for (j in seq_len(ctx$T + 1L)[-1L]) {
    hit <- is.na(out) & in_op[, j] > 1e-12
    out[hit] <- g$month_end[j] - in_op[hit, j] * g$months[j]
  }
  out
}

#' Wirksamkeit bis zum Periodenende (kumuliert, 0/1) aus einem Monatsanteilspfad
#' @noRd
typ_cumulative_active <- function(ctx, in_op) {
  done <- ctx$zeros()
  for (j in seq_len(ctx$T + 1L)[-1L]) done[, j] <- pmax(done[, j - 1L], in_op[, j] > 1e-12)
  done
}

#' Sätze der II. BV nach Altersklasse je Lauf und Periode (Spec 01 Teil A 4.11.2)
#' @noRd
maintenance_iibv_rate <- function(ctx, spec) {
  g <- ctx$grid
  n <- ctx$n
  n_t <- ctx$T + 1L
  ref_year <- ctx$setting(spec, "reference_year") %||%
    typ_const(ctx$building$first_occupancy_year) %||% ctx$building$first_occupancy_year %||%
    typ_const(ctx$building$construction_year) %||% ctx$building$construction_year
  if (is.null(ref_year)) {
    ctx$abort("types.flow.maintenance.msg.no_reference_year", id = spec[["id"]] %||% "?")
  }
  ref <- matrix(as.double(ref_year), n, n_t)
  for (c in as.character(ctx$setting(spec, "reset_capex_ids") %||% character(0))) {
    in_op <- ctx$component(c)$aux$in_operation
    if (is.null(in_op)) next
    start <- typ_effect_start_pos(ctx, in_op)
    start_date <- grid_add_months(rep(g$valuation_date, n), ifelse(is.na(start), 0, start))
    y_c <- utl_year(start_date - 1L)
    done <- typ_cumulative_active(ctx, in_op)
    ref <- ref * (1 - done) + pmax(ref, matrix(y_c, n, n_t)) * done
  }
  age <- matrix(g$year, n, n_t, byrow = TRUE) - ref
  r <- function(f) ctx$param(spec, paste0("iibv_rates.", f), "path")
  lt <- r("lt22y")
  ge22 <- r("ge22y")
  ge32 <- r("ge32y")
  if (is.null(lt) || is.null(ge22) || is.null(ge32)) {
    ctx$abort("types.flow.maintenance.msg.no_iibv_rates", id = spec[["id"]] %||% "?")
  }
  adj <- ctx$param(spec, "iibv_adjust_eur_m2_pa", "path") %||% ctx$zeros()
  lt * (age < 22) + ge22 * (age >= 22 & age < 32) + ge32 * (age >= 32) + adj
}

#' Faktoren wirkender Maßnahmen F_t (Spec 01 Teil A 4.11.2)
#' @noRd
maintenance_factors <- function(ctx, spec) {
  g <- ctx$grid
  n <- ctx$n
  n_t <- ctx$T + 1L
  out <- matrix(1, n, n_t)
  ids <- names(spec[["factors"]]) %||% character(0)
  period_start <- matrix(c(0, g$month_end[-n_t]), n, n_t, byrow = TRUE)
  for (c in ids) {
    f <- ctx$param(spec, paste0("factors.", c), "path")
    if (is.null(f)) next
    in_op <- ctx$component(c)$aux$in_operation
    if (is.null(in_op)) {
      ctx$abort("types.flow.maintenance.msg.no_in_operation", id = spec[["id"]] %||% "?",
                component = c)
    }
    fy <- ctx$param(spec, paste0("factor_years.", c))
    within <- matrix(1, n, n_t)
    if (!is.null(fy)) {
      start <- typ_effect_start_pos(ctx, in_op)
      start[is.na(start)] <- Inf
      within <- ((period_start - matrix(start, n, n_t)) / 12 < matrix(fy, n, n_t)) * 1
    }
    out <- out * (1 + (f - 1) * in_op * within)
  }
  out
}

#' Zahlungskomponente maintenance bauen (Spec 01 Teil A 4.11.2)
#' @noRd
maintenance_build <- function(spec, ctx) {
  g <- ctx$grid
  n <- ctx$n
  zero <- rep(0, n)
  id <- spec[["id"]] %||% "?"
  basis <- ctx$setting(spec, "basis") %||% "rate"
  bstar <- typ_price_base_date(ctx, spec)
  iy <- ctx$index_year(ctx$param(spec, "growth", "path") %||% zero, base_date = bstar)
  st <- ctx$timing(spec, "start_event") %||% list(date = g$valuation_date, shift = zero)
  om <- ctx$shift_overlap(st$date, st$shift, ctx$setting(spec, "to"))
  amount_pa <- if (identical(basis, "share_of_cost")) {
    capex_id <- ctx$setting(spec, "capex_id")
    share <- ctx$param(spec, "share_pa", "path")
    if (!utl_is_string(capex_id) || is.null(share)) {
      ctx$abort("types.flow.maintenance.msg.share_incomplete", id = id)
    }
    cap <- ctx$component(capex_id)
    share * cap$aux$cost_base * cap$aux$in_operation
  } else {
    area <- ctx$param(spec, "area_m2")
    if (is.null(area)) ctx$abort("types.flow.maintenance.msg.no_area", id = id)
    rate <- if (identical(basis, "iibv")) {
      maintenance_iibv_rate(ctx, spec)
    } else {
      ctx$param(spec, "rate_eur_m2_pa", "path") %||%
        ctx$abort("types.flow.maintenance.msg.no_rate", id = id)
    }
    rate * ctx$by_sim(area)
  }
  cost <- -amount_pa * iy * ctx$by_period(g$delta) * om * maintenance_factors(ctx, spec)
  tc <- ctx$setting(spec, "tax_category") %||%
    if (identical(ctx$perspective, "selbstnutzer")) "expense_nondeductible" else
      "expense_deductible"
  vofi_flows(vofi_row("cost", cost, section = "project", category = "maintenance",
                      tax_category = tc, asset_id = spec[["asset_id"]],
                      measure_id = spec[["measure_id"]],
                      vat_rate = typ_base_scalar(ctx, spec, "vat_rate", 0.19)))
}

#' Explizite Erneuerungen eines Szenarios im Horizont (Basisfall, Preisstand, ohne Index)
#'
#' Für die Hinweise zur Doppelzählung (Spec 01 Teil A 4.11.4): Ersatzkomponenten mit `enabled`
#' und Erhaltungsmaßnahmen (`capex` mit `classification: erhaltung` bzw. Ohnehin-Anteil 1).
#' Beträge werden nur aus Konstanten bestimmt (Bezüge bleiben unberücksichtigt).
#' @return `list(any = lgl, amount = num)`.
#' @noRd
maintenance_explicit_renewals <- function(scenario) {
  comps <- scenario[["components"]] %||% list()
  vd <- typ_valuation_date(scenario)
  hy <- typ_const(scenario[["project"]][["horizon_years"]]) %||%
    suppressWarnings(as.double(scenario[["project"]][["horizon_years"]]))
  end <- if (!is.null(vd) && length(hy) == 1L && !is.na(hy)) {
    grid_add_months(vd, as.integer(12 * hy))
  } else {
    NULL
  }
  found <- FALSE
  amount <- 0
  for (cmp in comps) {
    type <- cmp[["type"]] %||% ""
    if (identical(type, "replacement") && !identical(cmp[["enabled"]], FALSE)) {
      found <- TRUE
      life <- typ_const(cmp[["useful_life_years"]])
      cost <- typ_const(cmp[["cost_eur"]])
      inst <- typ_spec_date(cmp[["install_date"]])
      if (is.null(cost) && utl_is_string(cmp[["capex_id"]])) {
        cost <- typ_const(comps[[cmp[["capex_id"]]]][["cost_eur"]])
      }
      if (!is.null(life) && !is.null(cost) && !is.null(inst) && !is.null(end) && life[1] > 0) {
        big_l <- max(1, floor(12 * life[1] + 0.5))
        first <- typ_spec_date(cmp[["first_date"]]) %||% grid_add_months(inst, big_l)
        e <- first
        while (e <= end) {
          if (e > vd) amount <- amount + cost[1]
          e <- grid_add_months(e, big_l)
        }
      }
    } else if (identical(type, "capex")) {
      oh <- typ_const(cmp[["ohnehin_share"]])
      if (identical(cmp[["classification"]], "erhaltung") || (!is.null(oh) && any(oh >= 1))) {
        found <- TRUE
        cost <- typ_const(cmp[["cost_eur"]])
        if (!is.null(cost)) amount <- amount + cost[1]
      }
    }
  }
  list(any = found, amount = amount, years = if (length(hy) == 1L) hy else NA_real_)
}

#' Prüfungen der Komponente maintenance (Spec 01 Teil A 4.11.1, 4.11.4)
#' @noRd
maintenance_validate <- function(spec, scenario) {
  v <- typ_validator(spec, scenario, "maintenance")
  basis <- spec[["basis"]] %||% "rate"
  if (identical(basis, "rate") && is.null(spec[["rate_eur_m2_pa"]])) {
    v$add("error", "rate_missing", "rate_eur_m2_pa")
  }
  if (basis %in% c("rate", "iibv") && is.null(spec[["area_m2"]])) {
    v$add("error", "area_missing", "area_m2")
  }
  if (identical(basis, "iibv") && is.null(spec[["iibv_rates"]])) {
    v$add("error", "iibv_rates_missing", "iibv_rates")
  }
  if (identical(basis, "share_of_cost") &&
        (is.null(spec[["share_pa"]]) || is.null(spec[["capex_id"]]))) {
    v$add("error", "share_incomplete", "share_pa")
  }
  st <- typ_spec_date(spec[["start_event"]])
  to <- typ_spec_date(spec[["to"]])
  if (!is.null(st) && !is.null(to) && st >= to) v$add("error", "start_after_to", "to")
  if (basis %in% c("rate", "iibv")) {
    rate <- typ_const(spec[["rate_eur_m2_pa"]])
    positive <- identical(basis, "iibv") || is.null(rate) || any(rate > 0)
    excl <- isTRUE(scenario[["building"]][["maintenance"]][["excludes_explicit_replacements"]])
    ren <- maintenance_explicit_renewals(scenario)
    if (positive && ren$any && !excl) {
      v$add("warning", "double_count")
    }
    area <- typ_const(spec[["area_m2"]]) %||%
      typ_const(scenario[["building"]][["living_area_m2"]])
    if (excl && ren$any) {
      k <- if (!is.null(area) && area[1] > 0 && !is.na(ren$years) && ren$years > 0) {
        ren$amount / (ren$years * area[1])
      } else {
        NA_real_
      }
      v$add("info", "replacements_excluded", value = k)
    }
  }
  v$out
}

#' @noRd
typedef_maintenance <- function() {
  p <- vofi_param
  vofi_type(
    name = "maintenance", kind = "flow",
    params = list(
      basis = p("enum", values = c("rate", "iibv", "share_of_cost"), default = "rate"),
      rate_eur_m2_pa = p("amount", min = 0, unit = "EUR_m2_pa", shapes = c("scalar", "path")),
      area_m2 = p("number", min = 0),
      iibv_rates = p("map", fields = list(
        lt22y = p("amount", min = 0, unit = "EUR_m2_pa"),
        ge22y = p("amount", min = 0, unit = "EUR_m2_pa"),
        ge32y = p("amount", min = 0, unit = "EUR_m2_pa")
      )),
      iibv_adjust_eur_m2_pa = p("amount", default = 0, unit = "EUR_m2_pa"),
      reference_year = p("integer"),
      reset_capex_ids = p("ids", default = list()),
      share_pa = p("share", shapes = c("scalar", "path")),
      capex_id = p("ref"),
      factors = p("map", fields = list("*" = p("value", min = 0))),
      factor_years = p("map", fields = list("*" = p("number", min = 0))),
      price_base_year = p("integer"),
      growth = p("value", default = list(ref = "market.maintenance_index"), unit = "rate_pa"),
      start_event = p("timing", grid_default = "valuation_date"),
      to = p("timing", grid_default = "end_date"),
      vat_rate = p("share", default = 0.19),
      tax_category = p("enum", values = c("expense_deductible", "expense_nondeductible",
                                          "capex_expensable"))
    ),
    rows = "cost",
    grid_invariant = TRUE,
    validate = maintenance_validate,
    build = maintenance_build,
    example = list(type = "maintenance", basis = "rate", rate_eur_m2_pa = 14.4,
                   area_m2 = list(ref = "building.living_area_m2"), price_base_year = 2026L,
                   growth = 0.025, start_event = "2027-01-01", factors = list(cx = 0.8),
                   after = "cx",
                   .deps = list(cx = list(type = "capex", asset_id = "b1", measure_id = "m1",
                                          cost_eur = 30000, date = "2028-01-01",
                                          price_index = 0)))
  )
}
