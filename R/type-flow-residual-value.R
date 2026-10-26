# Zahlungstyp residual_value: Restwert am Horizont, Marktwertpfad und Restwertpfad (WS-E, Spec 01
# Teil A 6, Spec 00 4.12 Nr. 8, 7.6, 12.2, R-72, R-108). Methoden zero, income_value (Ertragswert
# nach ImmoWertV 2021 mit Restnutzungsdauer nach Anlage 2 und Bewirtschaftungskosten nach Anlage 3),
# market_growth, multiplier, exit_yield, asset_value (Sachwert linear), component
# (Komponenten-Zeitwert) und user_value. Alle Wertpfade sind n x (T+1) (vektorisiert ueber Laeufe
# und Perioden); Schleifen laufen nur ueber Monate, Perioden, Komponenten und Elemente.
# Die Komponente liest Zeilen ihrer Abhaengigkeiten (after) ueber ctx$rows() und die Hilfsgroessen
# der Massnahmen (capex: in_operation, cost_*; replacement: value, value_nominal, life_months) ueber
# ctx$component(); sie erkennt die Rollen an den Hilfsgroessen.

# ---------------------------------------------------------------------------------------------
# Parameterschema und Anlage-2-Tabelle
# ---------------------------------------------------------------------------------------------

#' Koeffizienten der ImmoWertV 2021 Anlage 2 (Punkte p0 bis p20: a, b, c, rel_age_min)
#'
#' Stützzeilen p0, p8, p12, p18–p20 nach Memo 02 (Qualität B), Zwischenzeilen rekonstruiert
#' (Qualität D, Spec 01 Teil A OP-01); identisch mit `valuation/immowertv_anlage1_2_2026`.
#' @return Liste `p0` … `p20` von Listen `a`, `b`, `c`, `rel_age_min`.
#' @noRd
rv_anlage2_table <- function() {
  m <- rbind(
    c(1.2500, 2.6250, 1.5250, 0.60), c(1.2500, 2.6250, 1.5250, 0.60),
    c(1.0767, 2.2757, 1.3878, 0.55), c(0.9033, 1.9263, 1.2505, 0.55),
    c(0.7300, 1.5770, 1.1133, 0.40), c(0.6725, 1.4578, 1.0850, 0.35),
    c(0.6150, 1.3385, 1.0567, 0.30), c(0.5575, 1.2193, 1.0283, 0.25),
    c(0.5000, 1.1000, 1.0000, 0.20), c(0.4660, 1.0270, 0.9906, 0.19),
    c(0.4320, 0.9540, 0.9811, 0.18), c(0.3980, 0.8810, 0.9717, 0.17),
    c(0.3640, 0.8080, 0.9622, 0.16), c(0.3300, 0.7350, 0.9528, 0.15),
    c(0.3040, 0.6760, 0.9506, 0.14), c(0.2780, 0.6170, 0.9485, 0.13),
    c(0.2520, 0.5580, 0.9463, 0.12), c(0.2260, 0.4990, 0.9442, 0.11),
    c(0.2000, 0.4400, 0.9420, 0.10), c(0.2000, 0.4400, 0.9420, 0.10),
    c(0.2000, 0.4400, 0.9420, 0.10)
  )
  stats::setNames(lapply(seq_len(nrow(m)), function(i) {
    list(a = m[i, 1L], b = m[i, 2L], c = m[i, 3L], rel_age_min = m[i, 4L])
  }), paste0("p", 0:20))
}

#' Modernisierungselemente und Höchstpunkte (ImmoWertV 2021 Anlage 2, Tabelle 6.3.3)
#' @noRd
rv_points_max_default <- function() {
  c(roof_insulation = 4, windows_doors = 2, pipes = 2, heating = 2, facade_insulation = 4,
    bathrooms = 2, interior = 2, floor_plan = 2)
}

#' Parameter des Typs residual_value (Struktur des Blocks `residual_value`, Spec 01 Teil A 6.1)
#' @noRd
rv_params <- function() {
  p <- vofi_param
  ref <- function(path) list(ref = path)
  det <- function(default) p("number", default = default, deterministic_only = TRUE)
  tab <- rv_anlage2_table()
  rnd_fields <- lapply(tab, function(row) {
    p("map", fields = lapply(row, det))
  })
  pmax_def <- rv_points_max_default()
  elems <- names(pmax_def)
  pts_fields <- stats::setNames(lapply(elems, function(e) p("number", default = 0, min = 0)),
                                elems)
  basis_enum <- function(default) p("enum", values = "vocab:income_basis", default = default)
  list(
    method = p("enum", values = "vocab:residual_method", default = "zero"),
    sale_cost_share = p("share", default = 0.03),
    path_pre_operation = p("enum", values = "vocab:path_pre_operation", default = "auto"),
    income_value = p("map", fields = list(
      variant = p("enum", values = "vocab:income_value_variant", default = "general"),
      cap_rate = p("value", default = 0.035, min = -0.01, max = 0.12),
      remaining_life_method = p("enum", values = "vocab:remaining_life_method",
                                default = "anlage2"),
      remaining_life_years = p("number", min = 0),
      remaining_life_offset_years = p("number", default = 0),
      gnd_years = p("number", default = 80, min = 0),
      rnd_table = p("map", fields = rnd_fields),
      points_max = p("map", fields = stats::setNames(lapply(pmax_def, det), elems)),
      points_decay_years = p("number", min = 0),
      income_basis = basis_enum("forward"),
      forward_growth = p("value", default = ref("market.rent_growth")),
      cost_forward_growth = p("value", default = ref("market.inflation")),
      include_other_income = p("logical", default = FALSE),
      land_value_eur = p("value", default = ref("building.land_value_eur"), shapes = "scalar"),
      land_value_growth = p("value", default = ref("market.land_value_growth")),
      bwk = p("map", fields = list(
        admin_eur_unit_pa = p("value", default = 367, min = 0),
        maintenance_eur_m2_pa = p("value", default = 14.40, min = 0),
        rent_loss_share = p("share", default = 0.02),
        price_base_year = p("integer", default = 2025L),
        index = p("value", default = ref("market.inflation")),
        admin_source = p("enum", values = "vocab:bwk_source", default = "model"),
        maintenance_source = p("enum", values = "vocab:bwk_source", default = "model"),
        variant_cost_categories = p("ids", default = list("co2_cost", "energy_cost",
                                                          "other_cost")),
        vacancy_from_ledger = p("logical", default = TRUE)
      )),
      bog_eur = p("value", default = 0),
      bog_component_residual = p("logical", default = FALSE),
      stranded_discount_share = p("value", default = 0, min = 0, max = 1),
      liquidation_floor = p("logical", default = TRUE),
      demolition_cost_eur = p("value", default = 0, min = 0)
    )),
    multiplier = p("map", fields = list(
      factor = p("value", default = 20, min = 0),
      basis = p("enum", values = "vocab:multiplier_basis", default = "net_cold_rent_incl_levy"),
      income_basis = basis_enum("forward"),
      forward_growth = p("value", default = ref("market.rent_growth"))
    )),
    exit_yield = p("map", fields = list(
      cap_rate = p("value", default = 0.04, min = 0),
      income_basis = basis_enum("forward"),
      forward_growth = p("value", default = ref("market.rent_growth")),
      cost_forward_growth = p("value", default = ref("market.inflation"))
    )),
    market_growth = p("map", fields = list(
      base_value_eur = p("value", min = 0, shapes = "scalar"),
      growth = p("value", default = ref("market.market_value_growth")),
      uplift_share = p("value", default = 0, min = 0)
    )),
    asset_value = p("map", fields = list(
      life_basis = p("enum", values = "vocab:life_basis", default = "gnd"),
      gnd_years = p("number", default = 80, min = 0),
      kg_include = p("integer", default = list(200L, 300L, 400L, 500L, 700L)),
      include_existing = p("logical", default = TRUE),
      market_adjustment_factor = p("value", default = 1, min = 0),
      uplift_share = p("value", default = 0, min = 0),
      index = p("value", default = ref("market.construction_price_index")),
      land_value_eur = p("value", default = ref("building.land_value_eur"), shapes = "scalar"),
      land_value_growth = p("value", default = ref("market.land_value_growth"))
    )),
    component = p("map", fields = list(
      indexed = p("logical", default = TRUE),
      include_land = p("logical", default = FALSE),
      include_existing = p("enum", values = "vocab:include_existing", default = "auto"),
      existing_growth = p("value", default = ref("market.market_value_growth"))
    )),
    user_value = p("map", fields = list(value_eur = p("value", default = 0, min = 0))),
    n_units = p("number", default = ref("building.n_units"), min = 0),
    living_area_m2 = p("number", default = ref("building.living_area_m2"), min = 0),
    construction_year = p("integer"),
    fictitious_construction_year = p("integer"),
    points_before = p("map", fields = pts_fields),
    points_measures = p("map", fields = list(.key = p("map", fields = pts_fields)), free = TRUE),
    existing_value_eur = p("amount", min = 0, unit = "EUR"),
    completion_event = p("timing", default = "completion")
  )
}

#' Normalisierter Default-Knoten eines (Unter-)Parameters von residual_value
#' @param name Parametername bzw. Unterpfad einer Map (z. B. `"income_value.land_value_eur"`).
#' @return Knoten oder `NULL`.
#' @noRd
rv_param_default <- function(name) {
  pp <- list(fields = rv_params())
  for (s in path_split(name)) {
    pp <- pp$fields[[s]]
    if (is.null(pp)) return(NULL)
  }
  if (is.null(pp$default)) NULL else node_normalize(pp$default, pp, name)
}

#' Parameter lesen; `NULL`, wenn der Knoten fehlt oder ein Bezugsziel nicht existiert
#'
#' Für optionale Domänenwerte wie `existing_value_eur = {ref: building.existing_value_eur}`
#' (Spec 01 Teil A 6.2 Nr. 2) bzw. den Bodenwert: ein fehlender Bestandswert bedeutet „kein
#' Bestand“ statt eines Abbruchs „Bezugsziel existiert nicht“. Fehlt der Knoten, gilt der Default
#' des Parameterschemas (wie bei `ctx$param()`).
#' @noRd
rv_param_opt <- function(ctx, spec, name, shape = "scalar") {
  node <- path_get(spec, name) %||% rv_param_default(name)
  if (is.null(node)) return(NULL)
  tg <- typ_ref_targets(node)
  if (length(tg) > 0L && any(vapply(tg, function(p) is.null(path_get(ctx$spec, p)),
                                    logical(1)))) {
    return(NULL)
  }
  ctx$param(spec, name, shape)
}

# ---------------------------------------------------------------------------------------------
# Gemeinsame Größen (6.3.1)
# ---------------------------------------------------------------------------------------------

#' Rollen der Abhängigkeiten: capex-, replacement- und Erwerbskomponenten
#' @return Liste `capex`, `repl`, `land` (benannte Listen von `vofi_flows`), `ids`.
#' @noRd
rv_deps <- function(ctx, spec) {
  ids <- setdiff(typ_after_ids(spec), spec[["id"]])
  out <- list(capex = list(), repl = list(), land = list(), ids = ids)
  for (id in ids) {
    fl <- ctx$component(id)
    if (!is.null(fl$aux$value_nominal) && !is.null(fl$aux$life_months)) {
      out$repl[[id]] <- fl
    } else if (!is.null(fl$aux$cost_base) && !is.null(fl$aux$in_operation)) {
      out$capex[[id]] <- fl
    }
    keys <- vapply(fl$rows, function(r) r$key, "")
    if ("price_building" %in% keys) out$land[[id]] <- fl
  }
  out
}

#' Summe der Zeilen der Abhängigkeiten nach Kategorien (n x (T+1))
#' @noRd
rv_rows_sum <- function(ctx, categories, tax_category = NULL) {
  if (length(categories) == 0L) return(ctx$zeros())
  rows <- ctx$rows(category = categories, tax_category = tax_category)
  Reduce(`+`, rows, ctx$zeros())
}

#' Ertragsfenster (Spec 01 Teil A 6.3.1): Summe der Zeilen über 12 Monate je Periodenende
#'
#' `forward`: (b_t, b_t + 12 Monate]; Monate jenseits von M_T aus dem Monat 12 Monate früher mal
#' (1 + g) (g = Wachstum der letzten Spalte); `trailing`: (b_t − 12 Monate, b_t].
#' @param x n x (T+1) Periodensummen.
#' @param g n-Vektor Wachstum jenseits des Horizonts.
#' @param basis `"forward"` oder `"trailing"`.
#' @return n x (T+1).
#' @noRd
rv_window <- function(ctx, x, g, basis = "forward") {
  grid <- ctx$grid
  n <- ctx$n
  n_t <- ctx$T + 1L
  xm <- ctx$to_months(x, "spread")
  big_m <- ncol(xm)
  ext <- cbind(xm, matrix(0, n, 12L))
  for (m in big_m + seq_len(12L)) {
    if (m - 12L >= 1L) ext[, m] <- ext[, m - 12L] * (1 + g)
  }
  cs <- matrix(0, n, big_m + 13L)
  for (m in seq_len(big_m + 12L)) cs[, m + 1L] <- cs[, m] + ext[, m]
  me <- grid$month_end
  out <- matrix(0, n, n_t)
  for (j in seq_len(n_t)) {
    out[, j] <- if (identical(basis, "trailing")) {
      cs[, me[j] + 1L] - cs[, max(me[j] - 12L, 0L) + 1L]
    } else {
      cs[, me[j] + 13L] - cs[, me[j] + 1L]
    }
  }
  out
}

#' Wachstum jenseits des Horizonts (Wert der letzten Spalte eines Pfads)
#' @noRd
rv_last <- function(ctx, spec, name) {
  x <- ctx$param(spec, name, "path")
  if (is.null(x)) return(rep(0, ctx$n))
  x[, ctx$T + 1L]
}

#' Bodenwert BW_t = BW_0 · Bestandsindex ab Stichtag (Spec 01 Teil A 6.3.1)
#' @noRd
rv_land_value <- function(ctx, spec, map) {
  bw0 <- rv_param_opt(ctx, spec, paste0(map, ".land_value_eur"))
  if (is.null(bw0)) {
    ctx$abort("types.flow.residual_value.msg.land_value_missing", id = spec[["id"]] %||% "?")
  }
  g <- ctx$param(spec, paste0(map, ".land_value_growth"), "path") %||% ctx$zeros()
  ctx$by_sim(bw0) * ctx$index(g)
}

#' Verschobene Fertigstellung eines Neubaus je Lauf (Spec 01 Teil A 6.3.1)
#'
#' Maßgeblich ist die Hauptmaßnahme: capex-Abhängigkeiten mit Fertigstellung zum
#' Projektfertigstellungstermin (`follows_construction`), verschoben um deren
#' `aux$completion_shift` (Verzug der Maßnahme und Bauzeitverzug); bei mehreren die späteste.
#' Ohne solche Abhängigkeit gilt der Termin `completion_event` über `ctx$timing()` (Token
#' `completion` mit Bauzeitverzug).
#' @return `Date` (Länge n).
#' @noRd
rv_shifted_completion <- function(ctx, spec, deps) {
  n <- ctx$n
  cd <- ctx$grid$completion_date
  shift <- NULL
  for (fl in deps$capex) {
    fcd <- fl$meta$completion_date
    if (!inherits(fcd, "Date") || !isTRUE(as.numeric(fcd) == as.numeric(cd)) ||
          is.null(fl$aux$completion_shift)) {
      next
    }
    s <- fl$aux$completion_shift[, 1L]
    shift <- if (is.null(shift)) s else pmax(shift, s)
  }
  if (is.null(shift)) {
    tm <- ctx$timing(spec, "completion_event") %||% list(date = cd, shift = rep(0, n))
    cd <- tm$date
    shift <- tm$shift
  }
  grid_add_months(rep(cd, n), typ_round_months(shift))
}

#' Baujahr* je Lauf (fiktives Baujahr bzw. Baujahr; Neubauprojekt: verschobene Fertigstellung)
#' @noRd
rv_build_year <- function(ctx, spec, deps = list(capex = list())) {
  n <- ctx$n
  fict <- ctx$setting(spec, "fictitious_construction_year")
  if (!is.null(fict)) return(rep(as.double(fict), n))
  pt <- ctx$project$project_type %||% ""
  if (pt %in% c("neubau", "erwerb_neubau")) {
    return(as.double(utl_year(rv_shifted_completion(ctx, spec, deps))))
  }
  y <- ctx$setting(spec, "construction_year") %||%
    typ_const(ctx$building$construction_year) %||% ctx$building$construction_year
  if (is.null(y)) {
    ctx$abort("types.flow.residual_value.msg.construction_year_missing",
              id = spec[["id"]] %||% "?")
  }
  rep(as.double(y), n)
}

#' Alter a_t = Jahr(b_t) − Baujahr* (n x (T+1))
#' @noRd
rv_age <- function(ctx, spec, deps) {
  yb <- utl_year(ctx$grid$date_end)
  n_t <- ctx$T + 1L
  matrix(yb, ctx$n, n_t, byrow = TRUE) - matrix(rv_build_year(ctx, spec, deps), ctx$n, n_t)
}

#' Restnutzungsdauer nach ImmoWertV 2021 Anlage 2 (vektorisiert)
#'
#' RND = a·ā²/GND − b·ā + c·GND, falls ā/GND ≥ rel_age_min, sonst GND − ā; ā = min(Alter, GND).
#' @param age Alter (Vektor oder Matrix).
#' @param points Modernisierungspunkte (gleiche Form; abgerundet, auf 0…20 begrenzt).
#' @param gnd Gesamtnutzungsdauer (gleiche Form oder Skalar, > 0).
#' @param table Liste `p0` … `p20` mit `a`, `b`, `c`, `rel_age_min`.
#' @return Restnutzungsdauer (gleiche Form wie `age`).
#' @noRd
rv_rnd_anlage2 <- function(age, points, gnd, table) {
  p <- pmin(pmax(floor(points + 1e-9), 0), 20)
  coef <- function(f) {
    unname(vapply(table[paste0("p", 0:20)], function(r) as.double(r[[f]]), double(1)))
  }
  a <- coef("a")[p + 1]
  b <- coef("b")[p + 1]
  c <- coef("c")[p + 1]
  r <- coef("rel_age_min")[p + 1]
  ab <- pmin(pmax(age, 0), gnd)
  out <- ifelse(ab / gnd >= r, a * ab^2 / gnd - b * ab + c * gnd, gnd - ab)
  if (!is.null(dim(age))) dim(out) <- dim(age)
  out
}

#' Anlage-2-Tabelle aus den Parametern (Basisfallwerte, deterministisch)
#' @noRd
rv_table <- function(ctx, spec) {
  stats::setNames(lapply(paste0("p", 0:20), function(k) {
    stats::setNames(lapply(c("a", "b", "c", "rel_age_min"), function(f) {
      v <- ctx$param_base(spec, paste("income_value.rnd_table", k, f, sep = "."))
      if (is.null(v)) NA_real_ else as.double(v[1L])
    }), c("a", "b", "c", "rel_age_min"))
  }), paste0("p", 0:20))
}

#' Wirksamkeit je Maßnahme bis b_t (capex der Maßnahme, kumuliert) und Alter seit Wirkungsbeginn
#' @return Liste je Maßnahmen-id: `active` (0/1, n x (T+1)), `age_years` (n x (T+1)).
#' @noRd
rv_measure_effects <- function(ctx, deps) {
  out <- list()
  me <- matrix(ctx$grid$month_end, ctx$n, ctx$T + 1L, byrow = TRUE)
  for (id in names(deps$capex)) {
    fl <- deps$capex[[id]]
    m <- fl$meta$measure_id %||% id
    in_op <- fl$aux$in_operation
    start <- typ_effect_start_pos(ctx, in_op, fl$aux$active)
    start[is.na(start)] <- Inf
    out[[m]] <- list(active = typ_cumulative_active(ctx, in_op),
                     age_years = pmax(me - matrix(start, ctx$n, ctx$T + 1L), 0) / 12)
  }
  out
}

#' Modernisierungspunkte P_t (Spec 01 Teil A 6.3.3)
#' @noRd
rv_points <- function(ctx, spec, deps) {
  n_t <- ctx$T + 1L
  elems <- names(rv_points_max_default())
  eff <- rv_measure_effects(ctx, deps)
  decay <- ctx$param(spec, "income_value.points_decay_years")
  pm <- spec[["points_measures"]] %||% list()
  total <- ctx$zeros()
  for (el in elems) {
    pts <- ctx$by_sim(ctx$param(spec, paste0("points_before.", el)) %||% rep(0, ctx$n))
    for (m in names(pm)) {
      if (is.null(eff[[m]]) || is.null(pm[[m]][[el]])) next
      v <- ctx$param(spec, paste("points_measures", m, el, sep = "."))
      if (is.null(v)) next
      w <- eff[[m]]$active
      if (!is.null(decay)) w <- w * (eff[[m]]$age_years < matrix(decay, ctx$n, n_t))
      pts <- pts + ctx$by_sim(v) * w
    }
    mx <- ctx$param_base(spec, paste0("income_value.points_max.", el))
    mx <- if (is.null(mx)) rv_points_max_default()[[el]] else mx[1L]
    total <- total + pmin(pts, mx)
  }
  total
}

#' Restnutzungsdauer RND_t nach Verfahren (Spec 01 Teil A 6.3.3)
#' @noRd
rv_rnd <- function(ctx, spec, deps) {
  g <- ctx$grid
  n_t <- ctx$T + 1L
  method <- ctx$setting(spec, "income_value.remaining_life_method") %||% "anlage2"
  gnd <- matrix(ctx$param(spec, "income_value.gnd_years") %||% rep(80, ctx$n), ctx$n, n_t)
  if (identical(method, "manual")) {
    rly <- ctx$param(spec, "income_value.remaining_life_years")
    if (is.null(rly)) {
      ctx$abort("types.flow.residual_value.msg.rnd_manual_missing", id = spec[["id"]] %||% "?")
    }
    tj <- g$tau[n_t]
    return(ctx$by_sim(rly) + ctx$by_period(tj - g$tau))
  }
  age <- rv_age(ctx, spec, deps)
  if (identical(method, "linear")) return(pmax(gnd - pmin(pmax(age, 0), gnd), 0))
  rv_rnd_anlage2(age, rv_points(ctx, spec, deps), gnd, rv_table(ctx, spec))
}

#' Kapitalisierungsfaktor (q^n − 1)/(q^n (q − 1)) mit q = 1 + LZ; LZ = 0: n (ohne Verzweigung)
#' @noRd
rv_kf <- function(lz, n_years) {
  z <- abs(lz) < 1e-12
  (1 - (1 + lz)^(-n_years)) / (lz + z) * (1 - z) + n_years * z
}

# ---------------------------------------------------------------------------------------------
# Methoden (6.3.3 bis 6.3.8)
# ---------------------------------------------------------------------------------------------

#' Ertragswert nach ImmoWertV §§ 27–34 (Spec 01 Teil A 6.3.3)
#' @noRd
rv_income_value <- function(ctx, spec, deps, measures_value) {
  m <- function(f) paste0("income_value.", f)
  n_t <- ctx$T + 1L
  basis <- ctx$setting(spec, m("income_basis")) %||% "forward"
  fg <- rv_last(ctx, spec, m("forward_growth"))
  cg <- rv_last(ctx, spec, m("cost_forward_growth"))
  win <- function(cats, g, tax = NULL) rv_window(ctx, rv_rows_sum(ctx, cats, tax), g, basis)
  income <- c("rent", "modernization_levy")
  if (isTRUE(ctx$setting(spec, m("include_other_income")))) {
    income <- c(income, "other_income", "energy_income")
  }
  roe <- win(income, fg)
  pby <- ctx$setting(spec, m("bwk.price_base_year")) %||% 2025L
  bwk_base <- as.Date(sprintf("%04d-01-01", as.integer(pby) + 1L))
  bwk_g <- ctx$param(spec, m("bwk.index"), "path") %||% ctx$zeros()
  i_bwk <- ctx$index(bwk_g, base_date = bwk_base)
  admin <- if (identical(ctx$setting(spec, m("bwk.admin_source")), "ledger")) {
    tax <- setdiff(vocab_tax_allowed("project", "operating_cost"), "passthrough")
    -win("operating_cost", cg, tax)
  } else {
    ctx$param(spec, m("bwk.admin_eur_unit_pa"), "path") * ctx$by_sim(ctx$param(spec, "n_units")) *
      i_bwk
  }
  maint <- if (identical(ctx$setting(spec, m("bwk.maintenance_source")), "ledger")) {
    -win("maintenance", cg)
  } else {
    ctx$param(spec, m("bwk.maintenance_eur_m2_pa"), "path") *
      ctx$by_sim(ctx$param(spec, "living_area_m2")) * i_bwk
  }
  rls <- ctx$by_sim(ctx$param(spec, m("bwk.rent_loss_share")) %||% rep(0, ctx$n))
  maw <- rls * roe
  vac <- if (isFALSE(ctx$setting(spec, m("bwk.vacancy_from_ledger")))) ctx$zeros() else
    pmax(-win("rent_loss", fg) - rls * roe, 0)
  var_cats <- as.character(ctx$setting(spec, m("bwk.variant_cost_categories")) %||% character(0))
  var <- -win(var_cats, cg)
  re <- roe - (admin + maint + maw + vac + var)
  n_years <- pmax(rv_rnd(ctx, spec, deps) +
                    ctx$by_sim(ctx$param(spec, m("remaining_life_offset_years")) %||%
                                 rep(0, ctx$n)), 0)
  lz <- ctx$param(spec, m("cap_rate"), "path")
  kf <- rv_kf(lz, n_years)
  bw <- rv_land_value(ctx, spec, "income_value")
  ew <- if (identical(ctx$setting(spec, m("variant")), "simplified")) {
    re * kf + bw / (1 + lz)^n_years
  } else {
    (re - bw * lz) * kf + bw
  }
  sd <- ctx$param(spec, m("stranded_discount_share"), "path") %||% ctx$zeros()
  bld <- (ew - bw) * (1 - sd)
  if (!isFALSE(ctx$setting(spec, m("liquidation_floor")))) {
    demo <- ctx$param(spec, m("demolition_cost_eur"), "path") %||% ctx$zeros()
    floor_v <- -demo * ctx$index(bwk_g)
    hit <- bld[, n_t] < floor_v[, n_t]
    if (any(hit)) {
      ctx$inform("types.flow.residual_value.msg.liquidation_floor", id = spec[["id"]] %||% "?",
                 share = mean(hit))
    }
    bld <- pmax(bld, floor_v)
  }
  v <- bw + bld + (ctx$param(spec, m("bog_eur"), "path") %||% ctx$zeros())
  if (isTRUE(ctx$setting(spec, m("bog_component_residual")))) v <- v + measures_value
  v
}

#' Rohertragsvervielfältiger (Spec 01 Teil A 6.3.5)
#' @noRd
rv_multiplier <- function(ctx, spec) {
  basis <- ctx$setting(spec, "multiplier.income_basis") %||% "forward"
  cats <- if (identical(ctx$setting(spec, "multiplier.basis"), "net_cold_rent")) "rent" else
    c("rent", "modernization_levy")
  w <- rv_window(ctx, rv_rows_sum(ctx, cats), rv_last(ctx, spec, "multiplier.forward_growth"),
                 basis)
  ctx$param(spec, "multiplier.factor", "path") * w
}

#' Exit-Rendite auf das NOI-Fenster (Spec 01 Teil A 6.3.5)
#' @noRd
rv_exit_yield <- function(ctx, spec) {
  tab <- vocab("categories")
  noi <- tab[tab$noi & tab$section %in% c("project", "grants"), , drop = FALSE]
  income <- noi$category[noi$sign == "pos" | noi$category == "rent_loss"]
  cost <- setdiff(noi$category, income)
  basis <- ctx$setting(spec, "exit_yield.income_basis") %||% "forward"
  w <- rv_window(ctx, rv_rows_sum(ctx, income), rv_last(ctx, spec, "exit_yield.forward_growth"),
                 basis) +
    rv_window(ctx, rv_rows_sum(ctx, cost), rv_last(ctx, spec, "exit_yield.cost_forward_growth"),
              basis)
  bad <- w[, ctx$T + 1L] <= 0
  if (any(bad)) {
    ctx$inform("types.flow.residual_value.msg.noi_nonpositive", id = spec[["id"]] %||% "?",
               share = mean(bad))
  }
  pmax(w, 0) / ctx$param(spec, "exit_yield.cap_rate", "path")
}

#' Investitionsbasis im Basisfall: −Σ_t der Kategorien land, acquisition_cost, capex
#' @noRd
rv_invest_base <- function(ctx, deps) {
  total <- rep(0, ctx$n)
  for (id in deps$ids) {
    fl <- ctx$component_base(id)
    for (r in fl$rows) {
      if (r$category %in% c("land", "acquisition_cost", "capex")) {
        total <- total - rowSums(r$values)
      }
    }
  }
  total
}

#' Anteil „alle Maßnahmen fertig“ ω_t (Spec 01 Teil A 6.3.4, Spec 00 4.12 Nr. 7, R-71)
#'
#' ω_t = min über die aktiven Maßnahmen von `aux$in_operation`; eine Maßnahme mit a_m = 0 zählt
#' wie eine fehlende (Term `in_operation + 1 − a_m`), ohne aktive Maßnahme ist ω_t = 0.
#' @noRd
rv_all_in_operation <- function(ctx, deps) {
  if (length(deps$capex) == 0L) return(ctx$zeros())
  terms <- lapply(deps$capex, function(fl) {
    a <- fl$aux$active %||% (ctx$zeros() + 1)
    fl$aux$in_operation + (1 - a)
  })
  any_active <- Reduce(pmax, lapply(deps$capex, function(fl) {
    fl$aux$active %||% (ctx$zeros() + 1)
  }))
  Reduce(pmin, terms) * any_active
}

#' Marktwertfortschreibung (Spec 01 Teil A 6.3.4)
#' @noRd
rv_market_growth <- function(ctx, spec, deps) {
  v0 <- ctx$param(spec, "market_growth.base_value_eur") %||%
    rv_param_opt(ctx, spec, "existing_value_eur")
  if (is.null(v0) && !is.null(path_get(ctx$spec, "building.market_value_eur"))) {
    v0 <- ctx$value("building.market_value_eur")
  }
  if (is.null(v0)) v0 <- rv_invest_base(ctx, deps)
  g <- ctx$param(spec, "market_growth.growth", "path") %||% ctx$zeros()
  omega <- rv_all_in_operation(ctx, deps)
  up <- ctx$param(spec, "market_growth.uplift_share", "path") %||% ctx$zeros()
  ctx$by_sim(v0) * ctx$index(g) * (1 + up * omega)
}

#' Position der verschobenen Fertigstellung einer capex-Komponente (Monate seit Stichtag)
#' @noRd
rv_completion_pos <- function(ctx, fl) {
  cd <- fl$meta$completion_date
  if (inherits(cd, "Date") && !is.null(fl$aux$completion_shift)) {
    return(grid_month_pos(ctx$grid, cd) + fl$aux$completion_shift[, 1L])
  }
  start <- typ_effect_start_pos(ctx, fl$aux$in_operation, fl$aux$active)
  start[is.na(start)] <- Inf
  start
}

#' Bestandsanteil eines Erwerbs (Gebäudeanteil des Kaufpreises, Basisfall) und Erwerbsperiode
#' @return `list(amount = n-Vektor, period = n-Vektor)` bzw. `NULL` ohne Erwerb.
#' @noRd
rv_purchase <- function(ctx, deps) {
  if (length(deps$land) == 0L) return(NULL)
  amount <- rep(0, ctx$n)
  period <- rep(NA_integer_, ctx$n)
  for (id in names(deps$land)) {
    fl <- ctx$component_base(id)
    for (r in fl$rows) {
      if (!identical(r$key, "price_building")) next
      amount <- amount - rowSums(r$values)
      for (j in rev(seq_len(ctx$T + 1L))) {
        hit <- abs(r$values[, j]) > 0
        period[hit] <- j - 1L
      }
    }
  }
  list(amount = amount, period = period)
}

#' Fortgeschriebener Wert ab der Erwerbsperiode (0 davor; Index relativ zur Erwerbsperiode)
#' @noRd
rv_from_purchase <- function(ctx, pur, idx) {
  n_t <- ctx$T + 1L
  p <- pur$period
  ok <- !is.na(p)
  i_p <- rep(1, ctx$n)
  i_p[ok] <- idx[cbind(which(ok), p[ok] + 1L)]
  start <- matrix(ifelse(ok, p, n_t), ctx$n, n_t)
  after <- matrix(seq_len(n_t) - 1L, ctx$n, n_t, byrow = TRUE) >= start
  ctx$by_sim(pur$amount) * idx / matrix(i_p, ctx$n, n_t) * after
}

#' Sachwert linear (Spec 01 Teil A 6.3.6)
#' @noRd
rv_asset_value <- function(ctx, spec, deps) {
  g <- ctx$grid
  n <- ctx$n
  n_t <- ctx$T + 1L
  iav <- ctx$index(ctx$param(spec, "asset_value.index", "path") %||% ctx$zeros())
  include_kg <- as.integer(unlist(ctx$setting(spec, "asset_value.kg_include") %||%
                                    c(200L, 300L, 400L, 500L, 700L)))
  gnd <- ctx$param(spec, "asset_value.gnd_years") %||% rep(80, n)
  life_basis <- ctx$setting(spec, "asset_value.life_basis") %||% "gnd"
  me <- matrix(g$month_end, n, n_t, byrow = TRUE)
  life_of <- function(capex_id) {
    for (fl in deps$repl) {
      if (identical(fl$meta$capex_id, capex_id)) return(fl$aux$life_months[, 1L] / 12)
    }
    gnd
  }
  z_total <- ctx$zeros()
  for (id in names(deps$capex)) {
    fl <- deps$capex[[id]]
    kgs <- fl$meta$kg %||% character(0)
    pay <- if (length(kgs) > 0L) {
      keep <- kgs[as.integer(sub("^kg", "", kgs)) %in% include_kg]
      Reduce(`+`, lapply(keep, function(k) fl$aux[[paste0("cost_", k)]]), ctx$zeros())
    } else {
      mid <- fl$meta$measure_id
      kg <- if (utl_is_string(mid)) typ_const(ctx$spec$measures[[mid]][["kg"]]) %||%
        ctx$spec$measures[[mid]][["kg"]] else NULL
      if (is.null(kg) || as.integer(kg[1L]) %in% include_kg) fl$aux$cost_total else ctx$zeros()
    }
    h <- ctx$zeros()
    acc <- rep(0, n)
    for (j in seq_len(n_t)) {
      acc <- acc + pay[, j] / iav[, j]
      h[, j] <- acc * iav[, j]
    }
    life <- if (identical(life_basis, "component")) life_of(id) else gnd
    pos <- rv_completion_pos(ctx, fl)
    alpha <- (me - matrix(pos, n, n_t)) / 12
    z_total <- z_total + h * pmin(1, pmax(0, 1 - alpha / matrix(life, n, n_t)))
  }
  bw <- rv_land_value(ctx, spec, "asset_value")
  ex <- ctx$zeros()
  if (!isFALSE(ctx$setting(spec, "asset_value.include_existing"))) {
    w0 <- rv_param_opt(ctx, spec, "existing_value_eur")
    pur <- rv_purchase(ctx, deps)
    if (!is.null(w0) || !is.null(pur)) {
      a0 <- utl_year(g$valuation_date) - rv_build_year(ctx, spec, deps)
      rest <- pmax(gnd - a0, 1)
      wear <- pmax(0, 1 - ctx$by_period(g$tau) / matrix(rest, n, n_t))
      if (!is.null(w0)) ex <- ex + ctx$by_sim(pmax(w0 - bw[, 1L], 0)) * iav * wear
      if (!is.null(pur)) ex <- ex + rv_from_purchase(ctx, pur, iav) * wear
    }
  }
  up <- ctx$param(spec, "asset_value.uplift_share", "path") %||% ctx$zeros()
  maf <- ctx$param(spec, "asset_value.market_adjustment_factor", "path") %||% (ctx$zeros() + 1)
  (z_total + ex) * (1 + up) * maf + bw
}

#' Zeitwerte der Maßnahmen (Spec 01 Teil A 6.3.7): Ersatzkomponenten und Maßnahmen ohne
#' Nutzungsdauer (Herstellungswert ohne Abschreibung)
#'
#' Bestandsbauteile (`include_initial = FALSE`) zählen nur mit `elements` und nur mit dem
#' Zeitwert ihrer Ersatzinvestitionen im Horizont (`aux$replaced`): die Erstinvestition ist Teil
#' des Bestandswerts (3.2), sonst zählte sie neben W_0 doppelt.
#' @param elements Bestandsbauteile einbeziehen.
#' @param inform Hinweis auf Maßnahmen ohne Nutzungsdauer ausgeben.
#' @noRd
rv_component_paths <- function(ctx, spec, deps, indexed, elements = FALSE, inform = TRUE) {
  total <- ctx$zeros()
  covered <- character(0)
  for (fl in deps$repl) {
    is_element <- isFALSE(fl$meta$include_initial)
    if (!utl_is_string(fl$meta$capex_id) || is_element) {
      if (!(is_element && elements)) next
    }
    covered <- c(covered, fl$meta$capex_id %||% character(0))
    val <- if (indexed) fl$aux$value else fl$aux$value_nominal
    if (is_element) val <- val * (fl$aux$replaced %||% ctx$zeros())
    total <- total + val
  }
  no_life <- setdiff(names(deps$capex), covered)
  if (length(no_life) > 0L) {
    if (inform) {
      ctx$inform("types.flow.residual_value.msg.no_useful_life", id = spec[["id"]] %||% "?",
                 components = utl_collapse(no_life))
    }
    for (id in no_life) {
      cost <- deps$capex[[id]]$aux$cost_total
      acc <- rep(0, ctx$n)
      for (j in seq_len(ctx$T + 1L)) {
        acc <- acc + cost[, j]
        total[, j] <- total[, j] + acc
      }
    }
  }
  total
}

#' Komponenten-Zeitwert (Spec 01 Teil A 6.3.7)
#' @noRd
rv_component <- function(ctx, spec, deps) {
  indexed <- !isFALSE(ctx$setting(spec, "component.indexed"))
  inc <- ctx$setting(spec, "component.include_existing") %||% "auto"
  w0 <- rv_param_opt(ctx, spec, "existing_value_eur")
  pur <- rv_purchase(ctx, deps)
  include_ex <- if (identical(inc, "auto")) !is.null(w0) || !is.null(pur) else
    identical(inc, "true")
  v <- rv_component_paths(ctx, spec, deps, indexed, elements = include_ex, inform = FALSE)
  if (isTRUE(ctx$setting(spec, "component.include_land"))) {
    v <- v + rv_land_value(ctx, spec, "income_value")
  }
  if (include_ex) {
    idx <- ctx$index(ctx$param(spec, "component.existing_growth", "path") %||% ctx$zeros())
    if (!is.null(w0)) v <- v + ctx$by_sim(w0) * idx
    if (!is.null(pur)) v <- v + rv_from_purchase(ctx, pur, idx)
  }
  v
}

#' Wertpfad V_t der gewählten Methode (vor Verkaufskosten)
#' @noRd
rv_method_value <- function(ctx, spec, deps, method, measures_value) {
  switch(method,
    zero = ctx$zeros(),
    income_value = rv_income_value(ctx, spec, deps, measures_value),
    market_growth = rv_market_growth(ctx, spec, deps),
    multiplier = rv_multiplier(ctx, spec),
    exit_yield = rv_exit_yield(ctx, spec),
    asset_value = rv_asset_value(ctx, spec, deps),
    component = rv_component(ctx, spec, deps),
    user_value = ctx$param(spec, "user_value.value_eur", "path") %||% ctx$zeros(),
    ctx$abort("types.flow.residual_value.msg.method_unknown", id = spec[["id"]] %||% "?",
              method = method)
  )
}

#' Wertpfad vor Betriebsbeginn (Spec 01 Teil A 6.2 Nr. 4)
#' @noRd
rv_pre_operation <- function(ctx, spec, deps, v) {
  g <- ctx$grid
  n_t <- ctx$T + 1L
  pre <- which(g$phase == "construction" & seq_len(n_t) < n_t)
  if (length(pre) == 0L) return(v)
  mode <- ctx$setting(spec, "path_pre_operation") %||% "auto"
  if (identical(mode, "auto")) {
    pt <- ctx$project$project_type %||% ""
    mode <- if (pt %in% c("neubau", "erwerb_neubau")) "cost" else "method"
  }
  if (identical(mode, "method")) return(v)
  if (identical(mode, "zero")) {
    v[, pre] <- 0
    return(v)
  }
  inv <- -rv_rows_sum(ctx, c("land", "acquisition_cost", "capex"))
  acc <- rep(0, ctx$n)
  cum <- ctx$zeros()
  for (j in seq_len(n_t)) {
    acc <- acc + inv[, j]
    cum[, j] <- acc
  }
  w0 <- rv_param_opt(ctx, spec, "existing_value_eur")
  if (!is.null(w0)) cum <- cum + ctx$by_sim(w0)
  v[, pre] <- cum[, pre, drop = FALSE]
  v
}

#' Zahlungskomponente residual_value bauen (Spec 01 Teil A 6.3, 6.5)
#' @noRd
residual_value_build <- function(spec, ctx) {
  n_t <- ctx$T + 1L
  id <- spec[["id"]] %||% "?"
  method <- ctx$setting(spec, "method") %||% "zero"
  deps <- rv_deps(ctx, spec)
  indexed <- !isFALSE(ctx$setting(spec, "component.indexed"))
  pm <- rv_component_paths(ctx, spec, deps, indexed, elements = FALSE, inform = TRUE)
  v <- rv_method_value(ctx, spec, deps, method, pm)
  if (!identical(method, "zero")) v <- rv_pre_operation(ctx, spec, deps, v)
  neg <- v < -vofi_tol$zero_abs
  if (any(neg)) {
    ctx$inform("types.flow.residual_value.msg.negative_value", id = id,
               share = mean(rowSums(neg) > 0))
  }
  v <- pmax(v, 0)
  c_share <- ctx$by_sim(ctx$param(spec, "sale_cost_share") %||% rep(0, ctx$n))
  value <- ctx$zeros()
  value[, n_t] <- v[, n_t]
  sale <- ctx$zeros()
  sale[, n_t] <- -c_share[, n_t] * v[, n_t]
  bid <- ctx$building$building_id %||% "b1"
  asset <- spec[["asset_id"]] %||% paste0(bid, "_building")
  vofi_flows(
    vofi_row("value", value, section = "project", category = "residual_value",
             asset_id = asset),
    vofi_row("sale_cost", sale, section = "project", category = "sale_cost"),
    vofi_row("market_value", v, section = "memo", category = "market_value"),
    vofi_row("path_method", v * (1 - c_share), section = "memo", category = "residual_path",
             rv_basis = "method"),
    vofi_row("path_measures", pm * (1 - c_share), section = "memo", category = "residual_path",
             rv_basis = "measures"),
    meta = list(method = method)
  )
}

#' Gibt es im Szenario eine Mietkomponente (Zeilen der Kategorie rent)?
#'
#' Statische Prüfung für validate(): Wohnungsgruppen (Expander `unit_groups`, Teil B),
#' Komponenten des Typs `rent_path` bzw. Komponenten mit `category: rent`.
#' @noRd
rv_has_rent_source <- function(scenario) {
  if (length(scenario[["unit_groups"]] %||% list()) > 0L) return(TRUE)
  for (cmp in scenario[["components"]] %||% list()) {
    if (identical(cmp[["type"]], "rent_path") || identical(cmp[["category"]], "rent")) {
      return(TRUE)
    }
  }
  FALSE
}

#' capex-Abhängigkeiten ohne Wertpfad einer Ersatzkomponente (Maßnahmen ohne Nutzungsdauer)
#' @noRd
rv_capex_without_life <- function(spec, scenario) {
  comps <- scenario[["components"]] %||% list()
  ids <- intersect(setdiff(as.character(unlist(spec[["after"]])), spec[["id"]]), names(comps))
  type <- vapply(ids, function(i) comps[[i]][["type"]] %||% "", character(1))
  capex <- ids[type == "capex"]
  covered <- unlist(lapply(ids[type == "replacement"], function(i) {
    cmp <- comps[[i]]
    if (identical(cmp[["include_initial"]], FALSE)) NULL else cmp[["capex_id"]]
  }))
  setdiff(capex, covered)
}

#' Fehlt ein Wert bzw. das Ziel seines Bezugs im Szenario?
#' @noRd
rv_node_missing <- function(node, scenario) {
  if (is.null(node)) return(TRUE)
  tg <- typ_ref_targets(node)
  length(tg) > 0L && any(vapply(tg, function(p) is.null(path_get(scenario, p)), logical(1)))
}

#' Prüfungen der Komponente residual_value (Spec 01 Teil A 6.6, 6.4)
#'
#' Meldungen im Sondernamensraum `validation.residual.*` (Spec 00 2.10, R-117).
#' @noRd
residual_value_validate <- function(spec, scenario) {
  v <- typ_validator(spec, scenario, "residual")
  method <- spec[["method"]] %||% "zero"
  iv <- spec[["income_value"]] %||% list()
  land <- if (method %in% c("income_value", "asset_value")) {
    lv <- paste0(method, ".land_value_eur")
    path_get(spec, lv) %||% rv_param_default(lv)
  }
  if (method %in% c("income_value", "asset_value") && rv_node_missing(land, scenario)) {
    v$add("error", "land_value_missing", paste0(method, ".land_value_eur"))
  }
  if (method %in% c("income_value", "multiplier", "exit_yield") &&
        (identical(scenario[["project"]][["perspective"]], "selbstnutzer") ||
           !rv_has_rent_source(scenario))) {
    v$add("warning", "no_rent", "method", method = method, value = method)
  }
  if (identical(method, "income_value")) {
    rlm <- iv[["remaining_life_method"]] %||% "anlage2"
    if (identical(rlm, "manual") && is.null(iv[["remaining_life_years"]])) {
      v$add("error", "rnd_manual_missing", "income_value.remaining_life_years")
    }
    if (rlm %in% c("anlage2", "linear") && is.null(spec[["construction_year"]]) &&
          is.null(spec[["fictitious_construction_year"]]) &&
          is.null(scenario[["building"]][["construction_year"]]) &&
          !((scenario[["project"]][["project_type"]] %||% "") %in% c("neubau", "erwerb_neubau"))) {
      v$add("error", "construction_year_missing", "construction_year")
    }
    if (isTRUE(iv[["bog_component_residual"]])) {
      v$add("warning", "double_count", "income_value.bog_component_residual")
    }
    if (!is.null(spec[["fictitious_construction_year"]]) &&
          length(spec[["points_measures"]] %||% list()) > 0L) {
      v$add("warning", "fictitious_and_points", "fictitious_construction_year")
    }
    lz <- typ_const(iv[["cap_rate"]])
    if (!is.null(lz) && any(lz < 0.015 | lz > 0.06)) {
      v$add("warning", "cap_rate_unusual", "income_value.cap_rate", value = lz[1L])
    }
  }
  if (identical(method, "multiplier")) {
    f <- typ_const(spec[["multiplier"]][["factor"]])
    if (!is.null(f) && any(f > 35 | f < 10)) {
      v$add("warning", "factor_unusual", "multiplier.factor", value = f[1L])
    }
  }
  if (identical(method, "component") && identical(spec[["component"]][["include_existing"]],
                                                  "false") &&
        !is.null(scenario[["building"]][["existing_value_eur"]])) {
    v$add("warning", "existing_without_value", "component.include_existing")
  }
  no_life <- rv_capex_without_life(spec, scenario)
  if (length(no_life) > 0L) {
    v$add("info", "no_useful_life", "after", components = utl_collapse(no_life))
  }
  pb <- spec[["points_before"]] %||% list()
  for (el in intersect(names(pb), names(rv_points_max_default()))) {
    x <- typ_const(pb[[el]])
    if (!is.null(x) && any(x > rv_points_max_default()[[el]] | x < 0)) {
      v$add("warning", "points_capped", paste0("points_before.", el), element = el)
    }
  }
  sc <- typ_const(spec[["sale_cost_share"]])
  if (!is.null(sc) && any(sc > 0.08)) v$add("warning", "sale_cost_high", "sale_cost_share")
  v$out
}

#' @noRd
typedef_residual_value <- function() {
  vofi_type(
    name = "residual_value", kind = "flow",
    params = rv_params(),
    rows = c("value", "sale_cost", "market_value", "path_method", "path_measures"),
    domain_reads = c("building", "measures", "market"),
    validate = residual_value_validate,
    build = residual_value_build,
    example = list(
      type = "residual_value", method = "income_value", sale_cost_share = 0.03,
      construction_year = 1975L, points_before = list(heating = 2),
      income_value = list(land_value_eur = 150000, cap_rate = 0.035,
                          bwk = list(price_base_year = 2026L)),
      points_measures = list(m1 = list(facade_insulation = 4)),
      after = c("rent", "cx", "rx"),
      .deps = list(
        rent = list(type = "recurring", amount_eur = 100000, category = "rent",
                    start_event = "2027-01-01", base_date = "2027-01-01"),
        cx = list(type = "capex", asset_id = "b1", measure_id = "m1", cost_eur = 50000,
                  date = "2027-07-01"),
        rx = list(type = "replacement", asset_id = "b1", measure_id = "m1", capex_id = "cx",
                  install_date = "2027-07-01", useful_life_years = 4)
      )
    )
  )
}
