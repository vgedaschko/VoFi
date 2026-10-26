# Zahlungstyp maintenance: laufende Instandhaltung als Pauschale je m2 (ImmoWertV Anlage 3), nach
# II. BV mit Altersklassen oder bauteilbezogen in % der Investition (WS-E, Spec 01 Teil A 4.11).
# Jahresbetrag mit Kalenderjahresindex (R-62), Wirkungszeitraum ueber ctx$timing() und
# ctx$shift_overlap() (3.9), Faktoren wirkender Massnahmen ueber deren aux$in_operation.

#' Beginn der Wirkung je Lauf aus einem Monatsanteilspfad (aux$in_operation)
#'
#' Position (Monate seit Stichtag) des ersten wirksamen Monats: in der ersten Periode j mit
#' positivem Anteil gilt Beginn = Monatsende der Periode − Anteil × Periodenmonate; ohne Wirkung
#' `NA`. Ist der Pfad mit einem Aktivierungsfaktor multipliziert (capex: `aux$active`), wird der
#' Anteil zuvor durch ihn geteilt (Bruchteile von a_m verschieben den Beginn nicht).
#' @param in_op n x (T+1) Monatsanteile.
#' @param active n x (T+1) Aktivierungsfaktor oder `NULL`.
#' @return double n-Vektor.
#' @noRd
typ_effect_start_pos <- function(ctx, in_op, active = NULL) {
  g <- ctx$grid
  sh <- if (is.null(active)) in_op else in_op / (active + (active == 0))
  out <- rep(NA_real_, ctx$n)
  for (j in seq_len(ctx$T + 1L)[-1L]) {
    hit <- is.na(out) & sh[, j] > 1e-12
    out[hit] <- g$month_end[j] - sh[hit, j] * g$months[j]
  }
  out
}

#' Monatsanteil je Periode im Fenster `[start, end)` (Positionen in Monaten seit Stichtag)
#' @param start,end double n-Vektoren (`NA` bzw. `Inf` zulässig).
#' @return n x (T+1), Spalte t = 0 null.
#' @noRd
typ_window_share <- function(ctx, start, end) {
  g <- ctx$grid
  n <- ctx$n
  n_t <- ctx$T + 1L
  start[is.na(start)] <- Inf
  pe <- matrix(g$month_end, n, n_t, byrow = TRUE)
  ps <- matrix(c(0, g$month_end[-n_t]), n, n_t, byrow = TRUE)
  len <- pmax(0, pmin(pe, matrix(end, n, n_t)) - pmax(ps, matrix(start, n, n_t)))
  len[!is.finite(len)] <- 0
  out <- len / matrix(pmax(g$months, 1L), n, n_t, byrow = TRUE)
  out[, 1L] <- 0
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
    fl <- ctx$component(c)
    in_op <- fl$aux$in_operation
    if (is.null(in_op)) next
    start <- typ_effect_start_pos(ctx, in_op, fl$aux$active)
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
#'
#' Der Faktor wirkt mit dem Monatsanteil der Periode ab Wirkungsbeginn der Maßnahme
#' (`aux$in_operation`, einschließlich a_m); mit Wirkungsdauer `factor_years` monatsgenau im
#' Fenster `[Beginn, Beginn + 12 · factor_years)`.
#' @noRd
maintenance_factors <- function(ctx, spec) {
  n <- ctx$n
  n_t <- ctx$T + 1L
  out <- matrix(1, n, n_t)
  ids <- names(spec[["factors"]]) %||% character(0)
  for (c in ids) {
    f <- ctx$param(spec, paste0("factors.", c), "path")
    if (is.null(f)) next
    fl <- ctx$component(c)
    in_op <- fl$aux$in_operation
    if (is.null(in_op)) {
      ctx$abort("types.flow.maintenance.msg.no_in_operation", id = spec[["id"]] %||% "?",
                component = c)
    }
    fy <- ctx$param(spec, paste0("factor_years.", c))
    share <- in_op
    if (!is.null(fy)) {
      start <- typ_effect_start_pos(ctx, in_op, fl$aux$active)
      a <- if (is.null(fl$aux$active)) 1 else fl$aux$active
      share <- typ_window_share(ctx, start, start + 12 * fy) * a
    }
    out <- out * (1 + (f - 1) * share)
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
#' Für die Hinweise zur Doppelzählung (Spec 01 Teil A 4.11.4): Ersatztermine der
#' `replacement`-Komponenten mit `enabled` im Horizont (Basisfall, mit Überfälligkeit und Ende
#' durch eine ersetzende Maßnahme, `typ_repl_events()`) und Erhaltungsmaßnahmen (`capex` mit
#' `classification: erhaltung` bzw. Ohnehin-Anteil 1 und Zahlung im Horizont). Beträge sind
#' Basisfallwerte; Bezüge auf Domänenpfade werden aufgelöst.
#' @return `list(any = lgl, amount = num, years = num)`.
#' @noRd
maintenance_explicit_renewals <- function(scenario, base, grid) {
  comps <- scenario[["components"]] %||% list()
  found <- FALSE
  amount <- 0
  for (cid in names(comps)) {
    cmp <- comps[[cid]]
    type <- cmp[["type"]] %||% ""
    if (identical(type, "replacement")) {
      ev <- typ_repl_events(cmp, cid, base, grid, scenario)
      k <- length(ev$dates)
      if (k > 0L) {
        found <- TRUE
        if (!is.na(ev$cost)) amount <- amount + k * ev$cost
      }
    } else if (identical(type, "capex")) {
      oh <- base(path_join("components", cid, "ohnehin_share"))
      erh <- identical(cmp[["classification"]], "erhaltung") || (!is.null(oh) && any(oh >= 1))
      d <- typ_spec_date(cmp[["date"]])
      sd <- cmp[["payment_schedule"]][["dates"]]
      first <- if (!is.null(d)) d else if (inherits(sd, "Date")) min(sd) else NULL
      in_h <- is.null(grid) || is.null(first) || first <= grid$end_date
      if (erh && in_h && !(isTRUE(base(path_join("components", cid, "active")) == 0))) {
        found <- TRUE
        cost <- typ_capex_base_cost(cmp, cid, base)
        if (!is.null(cost)) amount <- amount + cost
      }
    }
  }
  hy <- typ_const(scenario[["project"]][["horizon_years"]]) %||%
    suppressWarnings(as.double(scenario[["project"]][["horizon_years"]]))
  list(any = found, amount = amount, years = if (length(hy) == 1L) hy else NA_real_)
}

#' Leaf-Pfade eines Parameters für die Herkunftsprüfung (Bezugsziele bzw. eigener Pfad)
#' @noRd
maintenance_leaf_paths <- function(spec, path, name) {
  node <- path_get(spec, name)
  if (is.null(node)) return(character(0))
  targets <- typ_ref_targets(node)
  if (length(targets) > 0L) targets else path_join(path, name)
}

#' Stammt der Satz der Pauschale nur aus Defaults (Herkunft vor Schicht 5, 4.11.4)?
#' @noRd
maintenance_default_rate <- function(spec, scenario, path, basis) {
  prov <- attr(scenario, "provenance")
  if (!is.data.frame(prov) || !all(c("path", "layer", "source_type") %in% names(prov))) {
    return(FALSE)
  }
  names_p <- if (identical(basis, "iibv")) {
    paste0("iibv_rates.", c("lt22y", "ge22y", "ge32y"))
  } else {
    "rate_eur_m2_pa"
  }
  leaves <- unique(unlist(lapply(names_p, function(nm) maintenance_leaf_paths(spec, path, nm))))
  if (length(leaves) == 0L) return(FALSE)
  defaults <- c("type_default", "global", "profile", "library")
  all(vapply(leaves, function(lf) {
    hit <- prov$path == lf | startsWith(prov$path, paste0(lf, "."))
    any(hit) && isTRUE(all(prov$source_type[hit] %in% defaults & prov$layer[hit] < 5L))
  }, logical(1)))
}

#' Ist die Pauschale (rate bzw. iibv) im Basisfall > 0?
#' @noRd
maintenance_flat_positive <- function(cmp, cid, base) {
  basis <- cmp[["basis"]] %||% "rate"
  if (!(basis %in% c("rate", "iibv"))) return(FALSE)
  if (identical(basis, "iibv")) return(TRUE)
  r <- base(path_join("components", cid, "rate_eur_m2_pa"))
  is.null(r) || any(r > 0)
}

#' Wartung im Energiezustand bzw. PV-Betrieb für die Maßnahme m (Spec 01 Teil A 4.11.4, Teil B)
#' @noRd
maintenance_energy_service <- function(scenario, m, base) {
  if (!utl_is_string(m)) return(FALSE)
  en <- scenario[["energy"]] %||% list()
  states <- c(list(before = en[["before"]], after = en[["after"]]), en[["stages"]] %||% list())
  paths <- c("energy.before", "energy.after", paste0("energy.stages.", names(en[["stages"]])))
  for (i in seq_along(states)) {
    st <- states[[i]]
    if (!is.list(st) || !identical(st[["measure"]], m)) next
    s <- base(path_join(paths[i], "service_eur_pa"))
    if (!is.null(s) && any(s > 0)) return(TRUE)
  }
  pv <- en[["pv"]]
  if (is.list(pv) && identical(pv[["measure"]], m)) {
    for (f in c("opex_share_of_cost", "opex_eur_pa")) {
      x <- base(path_join("energy.pv", f))
      if (!is.null(x) && any(x > 0)) return(TRUE)
    }
  }
  FALSE
}

#' Prüfungen der Komponente maintenance (Spec 01 Teil A 4.11.1, 4.11.4)
#' @noRd
maintenance_validate <- function(spec, scenario) {
  v <- typ_validator(spec, scenario, "maintenance")
  base <- typ_base_resolver(scenario)
  path <- path_join(v$coll, v$id)
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
  # Wertegrenzen der Map-Felder mit freien Schlüsseln (4.4: factor >= 0, duration_years > 0)
  for (c in names(spec[["factors"]])) {
    f <- base(path_join(path, "factors", c))
    if (!is.null(f) && any(f < 0)) {
      v$add("error", "validation.range", paste0("factors.", c), value = min(f), min = "0",
            max = "Inf", interval = val_interval(0, Inf))
    }
  }
  for (c in names(spec[["factor_years"]])) {
    y <- base(path_join(path, "factor_years", c))
    if (!is.null(y) && any(y <= 0)) {
      v$add("error", "factor_years_nonpositive", paste0("factor_years.", c), value = min(y))
    }
  }
  excl <- isTRUE(scenario[["building"]][["maintenance"]][["excludes_explicit_replacements"]])
  if (basis %in% c("rate", "iibv")) {
    grid <- typ_scenario_grid(scenario)
    ren <- maintenance_explicit_renewals(scenario, base, grid)
    if (maintenance_flat_positive(spec, v$id, base) && ren$any && !excl) {
      v$add("warning", "double_count")
    }
    if (excl) {
      area <- base(path_join(path, "area_m2")) %||% base("building.living_area_m2")
      k <- if (!is.null(area) && area[1L] > 0 && !is.na(ren$years) && ren$years > 0) {
        ren$amount / (ren$years * area[1L])
      } else {
        NA_real_
      }
      v$add("info", "replacements_excluded", value = k)
    }
    if (maintenance_default_rate(spec, scenario, path, basis)) {
      field <- if (identical(basis, "iibv")) "iibv_rates" else "rate_eur_m2_pa"
      v$add("info", "default_rate", field)
    }
  } else if (identical(basis, "share_of_cost")) {
    comps <- scenario[["components"]] %||% list()
    flat <- vapply(names(comps), function(cid) {
      cmp <- comps[[cid]]
      identical(cmp[["type"]], "maintenance") && !identical(cid, v$id) &&
        maintenance_flat_positive(cmp, cid, base)
    }, logical(1))
    if (any(flat) && !excl) v$add("warning", "service_double", "share_pa")
    if (maintenance_energy_service(scenario, spec[["measure_id"]], base)) {
      v$add("warning", "service_double_energy", "share_pa", measure = spec[["measure_id"]])
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
      factors = p("map", fields = list(.key = p("value", min = 0)), free = TRUE),
      factor_years = p("map", fields = list(.key = p("number", min = 0)), free = TRUE),
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
