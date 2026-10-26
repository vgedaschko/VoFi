# Expander measures (WS-E2, Spec 01 Teil A 4.5; Spec 00 4.12, R-18, R-90): je Massnahme die
# Komponenten m_<m>_capex (Typ capex), m_<m>_repl (replacement, Zeitwertpfad und Ersatz),
# m_<m>_maint (maintenance, Instandsetzung in % der Investition) bzw. bei Erwerbstypen
# m_<m>_purchase (land) und m_<m>_acq (acquisition_cost); je Bestandsbauteil m_<e>_repl; fuer das
# Gebaeude m_maintenance; Massnahmen- und Anlagenregister. Numerische Domaenenblaetter gehen als
# Bezuege ein, Termine, Codes und Flags als normalisierte Werte; der Aktivierungsfaktor a_m ist ein
# Ausdruck ueber measures.<m>.active und die Zusagen der Instrumente mit on_reject: drop_measures.

#' Maßnahmentypen des Erwerbs (Teil A 4.5.2)
#' @noRd
exp_m_acq_types <- function() c("erwerb_grundstueck", "erwerb_objekt")

#' Asset-id einer Maßnahme (Teil A 4.5.4): ausdrücklich, eigene Anlage oder Gebäude
#' @noRd
exp_m_asset_id <- function(mm, m, bid) {
  aid <- exp_code(mm[["asset_id"]])
  if (!is.null(aid)) return(aid)
  at <- exp_chr(mm[["asset_type"]])
  if (length(at) == 1L && at %in% c("pv_anlage", "ladeinfrastruktur", "bewegliches_wg",
                                    "aussenanlage")) {
    return(paste0(bid, "_", m))
  }
  paste0(bid, "_building")
}

#' Bezüge auf die vorhandenen numerischen Felder einer Maßnahme
#' @noRd
exp_m_refs <- function(x, m, fields) {
  out <- list()
  for (f in fields) {
    p <- paste0("measures.", m, ".", f)
    if (exp_has(x, p)) out[[f]] <- node_ref(p)
  }
  out
}

#' Verschiebung der Fertigstellung als Ausdruckstext (Teil A 4.6.2 (4), 4.10.1)
#' @noRd
exp_m_shift_text <- function(x, m) {
  mm <- x$measures[[m]] %||% list()
  parts <- if (exp_has(x, paste0("measures.", m, ".delay_months"))) {
    paste0("measures.", m, ".delay_months")
  } else {
    character(0)
  }
  mode <- exp_code(mm[["construction_delay_mode"]]) %||% "none"
  if (!identical(mode, "none") && exp_has(x, "project.construction_delay_months")) {
    parts <- c(parts, "project.construction_delay_months")
  }
  if (length(parts) == 0L) "0" else paste(parts, collapse = " + ")
}

#' Knoten aus einem Ausdruckstext (Pfad -> Bezug, Zahl -> Konstante, sonst Ausdruck)
#' @noRd
exp_text_node <- function(text) {
  if (exp_is_path(text)) return(node_ref(text))
  v <- suppressWarnings(as.double(text))
  if (!is.na(v)) return(node_const(v))
  node_expr(text)
}

#' Ist `cost_eur` einer Maßnahme abgeleitet (aus `cost_kg` bzw. Zahlungsplan in EUR, 4.6.1)?
#' @noRd
exp_m_cost_derived <- function(mm) {
  kg <- mm[["cost_kg"]]
  if (is.list(kg) && length(kg) > 0L) return(TRUE)
  sched <- mm[["payment_schedule"]]
  is.list(sched) && identical(exp_code(sched[["unit"]]) %||% "eur", "eur")
}

#' Komponente m_<m>_capex (Teil A 4.5.2, 4.6.1)
#' @noRd
exp_m_capex <- function(x, m, mm, bctx, a_node, asset_id) {
  num <- c("kg700_share", "contingency_share", "cost_factor", "vat_rate", "price_index",
           "delay_months", "ohnehin_share", "ohnehin_cost_eur")
  if (!exp_m_cost_derived(mm)) num <- c("cost_eur", num)
  cmp <- c(list(type = "capex", label = mm[["label"]] %||% m, measure_id = m,
                asset_id = asset_id),
           exp_m_refs(x, m, num))
  kg <- mm[["cost_kg"]]
  if (is.list(kg) && length(kg) > 0L) {
    cmp$cost_kg <- stats::setNames(lapply(names(kg), function(k) {
      node_ref(paste0("measures.", m, ".cost_kg.", k))
    }), names(kg))
  }
  for (f in c("kg700_basis", "contingency_basis", "payment_profile", "construction_delay_mode",
              "classification")) {
    v <- exp_code(mm[[f]])
    if (!is.null(v)) cmp[[f]] <- v
  }
  cin <- exp_lgl(mm[["cost_is_net"]])
  if (!is.null(cin)) cmp$cost_is_net <- cin
  for (f in c("price_base_year", "duration_months")) {
    v <- exp_int(mm[[f]])
    if (!is.null(v)) cmp[[f]] <- v
  }
  sp <- exp_int(mm[["tax_spread_years"]])
  if (!is.null(sp)) cmp$spread_years <- sp
  es <- exp_code(mm[["effects"]][["start"]])
  if (!is.null(es)) cmp$effect_start <- es
  if (!is.null(mm[["payment_schedule"]])) {
    cmp$payment_schedule <- mm[["payment_schedule"]]
  } else {
    d <- exp_date(mm[["date"]], bctx$grid) %||% exp_date(mm[["year"]], bctx$grid)
    if (!is.null(d)) cmp$date <- d
  }
  cd <- exp_date(mm[["completion_date"]], bctx$grid)
  if (!is.null(cd)) cmp$completion_date <- cd
  cdm <- exp_ref(x, "project.construction_delay_months")
  if (!is.null(cdm)) cmp$construction_delay_months <- cdm
  cmp$active <- a_node
  cmp
}

#' Komponente m_<m>_repl einer Maßnahme (Teil A 4.5.2, 4.10)
#' @noRd
exp_m_repl <- function(x, m, mm, bctx, a_node, asset_id, capex_id) {
  pre <- paste0("measures.", m, ".")
  rp <- mm[["replacement"]] %||% list()
  dates <- exp_measure_dates(x, m, bctx)
  cmp <- list(type = "replacement", label = mm[["label"]] %||% m, measure_id = m,
              asset_id = asset_id, after = capex_id, capex_id = capex_id,
              include_initial = TRUE, enabled = exp_lgl(rp[["enabled"]]) %||% TRUE,
              useful_life_years = node_ref(paste0(pre, "useful_life_years")),
              install_shift_months = exp_text_node(exp_m_shift_text(x, m)),
              active = a_node)
  if (!is.null(dates$completion)) cmp$install_date <- dates$completion
  for (f in c("cost_eur", "cost_factor", "price_index")) {
    p <- paste0(pre, "replacement.", f)
    if (exp_has(x, p)) cmp[[f]] <- node_ref(p)
  }
  if (exp_has(x, paste0(pre, "vat_rate"))) cmp$vat_rate <- node_ref(paste0(pre, "vat_rate"))
  pby <- exp_int(mm[["price_base_year"]])
  if (!is.null(pby)) cmp$price_base_year <- pby
  cls <- exp_code(rp[["classification"]])
  if (!is.null(cls)) cmp$classification <- cls
  cmp
}

#' Komponente m_<m>_maint (Instandsetzung in % der Investition, Teil A 4.4, 4.11)
#' @noRd
exp_m_maint <- function(x, m, mm, asset_id, capex_id, tax_category) {
  cmp <- list(type = "maintenance", label = mm[["label"]] %||% m, measure_id = m,
              asset_id = asset_id, after = capex_id, basis = "share_of_cost",
              capex_id = capex_id,
              share_pa = node_ref(paste0("measures.", m, ".effects.maintenance.share_of_cost_pa")),
              tax_category = tax_category)
  pby <- exp_int(mm[["price_base_year"]])
  if (!is.null(pby)) cmp$price_base_year <- pby
  if (exp_has(x, "building.maintenance.growth")) {
    cmp$growth <- node_ref("building.maintenance.growth")
  }
  cmp
}

#' Komponenten m_<m>_purchase und m_<m>_acq eines Erwerbs (Teil A 4.7, 4.8)
#' @noRd
exp_m_acquisition <- function(x, m, mm, bctx, a_node, bid) {
  pre <- paste0("measures.", m, ".")
  d <- exp_date(mm[["date"]], bctx$grid) %||% exp_date(mm[["year"]], bctx$grid)
  ids <- list(land_asset_id = paste0(bid, "_land"), building_asset_id = paste0(bid, "_building"))
  purchase <- c(list(type = "land", label = mm[["label"]] %||% m, measure_id = m,
                     asset_id = ids$building_asset_id),
                exp_m_refs(x, m, c("purchase_price_eur", "land_share", "delay_months")),
                list(active = a_node), ids)
  if (!is.null(d)) purchase$date <- d
  acq <- c(list(type = "acquisition_cost", label = mm[["label"]] %||% m, measure_id = m,
                asset_id = ids$building_asset_id),
           exp_m_refs(x, m, c("land_share", "grest_rate", "notary_share", "land_registry_share",
                              "broker_share", "other_share", "delay_months")),
           list(active = a_node), ids)
  if (exp_has(x, paste0(pre, "purchase_price_eur"))) {
    acq$basis_eur <- node_ref(paste0(pre, "purchase_price_eur"))
  }
  uc <- isTRUE(exp_lgl(mm[["uniform_contract"]]))
  acq$uniform_contract <- uc
  ucm <- exp_chr(mm[["uniform_contract_measures"]])
  ucm <- ucm[vapply(ucm, function(k) exp_has(x, paste0("measures.", k, ".cost_eur")),
                    logical(1))]
  if (uc && length(ucm) > 0L) {
    acq$construction_basis_eur <- exp_sum_node(paste0("measures.", ucm, ".cost_eur"))
  }
  fs <- exp_code(mm[["federal_state"]]) %||% exp_code(x$project$federal_state)
  if (!is.null(fs)) acq$federal_state <- fs
  ad <- exp_date(mm[["ancillary_date"]], bctx$grid) %||% d
  if (!is.null(ad)) acq$date <- ad
  list(purchase = purchase, acq = acq)
}

#' Komponente m_<e>_repl eines Bestandsbauteils (Teil A 3.2, 4.5.2)
#' @noRd
exp_m_element <- function(x, e, el, bctx, bid, replacing) {
  pre <- paste0("building.elements.", e, ".")
  cmp <- list(type = "replacement", label = el[["label"]] %||% e, measure_id = e,
              asset_id = exp_code(el[["asset_id"]]) %||% paste0(bid, "_building"),
              include_initial = FALSE, enabled = TRUE, classification = "erhaltung")
  iy <- exp_int(el[["installed_year"]])
  cmp$install_date <- if (!is.null(iy)) {
    as.Date(sprintf("%04d-01-01", iy))
  } else {
    bctx$grid$valuation_date %||% exp_date(x$project$valuation_date)
  }
  nr <- exp_date(el[["next_replacement"]], bctx$grid)
  if (!is.null(nr)) cmp$first_date <- nr
  map <- c(useful_life_years = "useful_life_years", cost_eur = "replacement_cost_eur",
           first_shift_months = "next_replacement_delay_months", price_index = "price_index",
           vat_rate = "vat_rate", active = "active")
  for (p in names(map)) {
    path <- paste0(pre, map[[p]])
    if (exp_has(x, path)) cmp[[p]] <- node_ref(path)
  }
  pby <- exp_int(el[["price_base_year"]])
  if (!is.null(pby)) cmp$price_base_year <- pby
  od <- exp_code(el[["overdue"]])
  if (!is.null(od)) cmp$overdue <- od
  if (length(replacing) > 0L) {
    k <- replacing[1L]
    cd <- exp_measure_completion(x, k, bctx)
    if (!is.null(cd)) {
      cmp$until_date <- cd
      a_txt <- exp_activation_text(x, k)
      cmp$until_shift_months <- node_expr(paste0("(", exp_m_shift_text(x, k), ") + (1 - ",
                                                 a_txt, ") * 1200"))
    }
  }
  cmp
}

#' Komponente m_maintenance des Gebäudes (Teil A 3.3, 4.11)
#' @noRd
exp_m_building_maintenance <- function(x, bctx, measures, tax_category, bid) {
  mt <- x$building$maintenance %||% list()
  basis <- exp_code(mt[["basis"]]) %||% "rate"
  if (identical(basis, "auto")) basis <- "rate"
  pre <- "building.maintenance."
  cmp <- list(type = "maintenance", label = bctx$lbl("expand.measures.maintenance_label"),
              asset_id = paste0(bid, "_building"),
              basis = basis, tax_category = tax_category)
  for (f in c("rate_eur_m2_pa", "area_m2", "growth", "vat_rate")) {
    if (exp_has(x, paste0(pre, f))) cmp[[f]] <- node_ref(paste0(pre, f))
  }
  rates <- list()
  for (k in c("lt22y", "ge22y", "ge32y")) {
    p <- paste0(pre, "iibv.rates_eur_m2_pa.", k)
    if (exp_has(x, p)) rates[[k]] <- node_ref(p)
  }
  if (length(rates) > 0L) cmp$iibv_rates <- rates
  if (exp_has(x, paste0(pre, "iibv.adjust_eur_m2_pa"))) {
    cmp$iibv_adjust_eur_m2_pa <- node_ref(paste0(pre, "iibv.adjust_eur_m2_pa"))
  }
  ry <- exp_int(x$building$first_occupancy_year) %||% exp_int(x$building$construction_year)
  if (!is.null(ry)) cmp$reference_year <- ry
  pby <- if (identical(basis, "iibv")) exp_int(mt[["iibv"]][["price_base_year"]]) else NULL
  pby <- pby %||% exp_int(mt[["price_base_year"]])
  if (!is.null(pby)) cmp$price_base_year <- pby
  se <- mt[["start_event"]]
  if (identical(se, "completion")) {
    cmp$start_event <- "completion"
  } else if (!is.null(exp_date(se, bctx$grid))) {
    cmp$start_event <- exp_date(se, bctx$grid)
  }
  to <- exp_date(mt[["to"]], bctx$grid)
  if (!is.null(to)) cmp$to <- to
  capex_of <- function(m) paste0("m_", m, "_capex")
  with_capex <- measures[!(vapply(measures, function(m) {
    exp_code(x$measures[[m]][["measure_type"]]) %||% ""
  }, character(1)) %in% exp_m_acq_types())]
  factors <- list()
  years <- list()
  for (m in with_capex) {
    p <- paste0("measures.", m, ".effects.maintenance.factor")
    if (exp_has(x, p)) {
      factors[[capex_of(m)]] <- node_ref(p)
      py <- paste0("measures.", m, ".effects.maintenance.duration_years")
      if (exp_has(x, py)) years[[capex_of(m)]] <- node_ref(py)
    }
  }
  if (length(factors) > 0L) cmp$factors <- factors
  if (length(years) > 0L) cmp$factor_years <- years
  rbm <- mt[["iibv"]][["reset_by_measures"]]
  reset <- if (is.null(rbm) || identical(exp_code(rbm), "auto")) {
    with_capex[vapply(with_capex, function(m) {
      isTRUE(exp_lgl(x$measures[[m]][["effects"]][["maintenance"]][["reset_age"]]))
    }, logical(1))]
  } else {
    intersect(exp_chr(rbm), with_capex)
  }
  if (length(reset) > 0L) cmp$reset_capex_ids <- capex_of(reset)
  deps <- unique(c(names(factors), if (length(reset) > 0L) capex_of(reset)))
  if (length(deps) > 0L) cmp$after <- deps
  cmp
}

#' Förderwahl einer Maßnahme für das Register (Teil A 4.5.3)
#' @noRd
exp_m_funding_choice <- function(x, m, mm) {
  fc <- exp_code(mm[["funding_choice"]])
  if (!is.null(fc)) return(fc)
  types <- character(0)
  for (fs in x$funding %||% list()) {
    if (m %in% exp_chr(fs[["measures"]])) types <- c(types, exp_code(fs[["instrument_type"]]))
  }
  if ("grant" %in% types) return("beg_zuschuss")
  if (any(c("loan", "loan_with_repayment_grant") %in% types)) return("beg_kredit")
  if ("tax_credit" %in% types) return("35c")
  "keine"
}

#' Herkunft der Klassifikation (Teil A 4.5.3): user, rule (Projektart) oder default (Katalog)
#'
#' Ohne Herkunftszugriff in `bctx` gilt eine Klassifikation, die dem Katalogwert gleicht, als
#' `default` (auch wenn sie ausdrücklich gesetzt ist; Vertragswunsch an WS-A/Integrator).
#' @noRd
exp_m_class_source <- function(x, mm, bctx) {
  cls <- exp_code(mm[["classification"]]) %||% "auto"
  pt <- x$project$project_type %||% ""
  if (pt %in% c("neubau", "erwerb_neubau") && identical(cls, "herstellung")) return("rule")
  if (identical(pt, "erwerb_sanierung") && identical(cls, "auto")) return("rule")
  mt <- exp_code(mm[["measure_type"]]) %||% ""
  cc <- exp_code(exp_m_catalog_types(bctx)[[mt]][["classification_existing"]])
  if (is.null(cc) || identical(cc, "main") || identical(cc, cls)) return("default")
  "user"
}

#' Bibliotheksindex des Build-Kontexts (Wurzeln der Auflösung, `ctx$lib_paths`)
#'
#' `bctx` bietet keinen eigenen Zugriff auf Index bzw. Wurzeln; gelesen wird der Index, über den
#' `bctx$lib()` auflöst (Umgebung der Funktion), sonst der Index der Standardwurzeln.
#' @noRd
exp_lib_index <- function(bctx) {
  env <- if (is.function(bctx$lib)) environment(bctx$lib) else NULL
  idx <- if (is.environment(env)) get0("idx", envir = env, inherits = FALSE) else NULL
  if (is.list(idx) && is.list(idx$entries)) return(idx)
  tryCatch(lib_index(vofi_library_paths()), error = function(e) NULL)
}

#' Typen des Katalogs `costs/massnahmentypen_2026` (nur für die Herkunft der Klassifikation)
#'
#' Liest den Eintrag aus dem Bibliotheksindex der Auflösung (Nutzerbibliotheken überschatten, wie
#' `bctx$lib()`), ohne die Nutzlast erneut zu bilden (A-13: eine Nutzlast je Auflösung über
#' `rule:measure_catalog`).
#' @return benannte Liste je Maßnahmentyp (leer, wenn der Eintrag fehlt).
#' @noRd
exp_m_catalog_types <- function(bctx) {
  rec <- tryCatch(lib_get(exp_lib_index(bctx), "costs/massnahmentypen_2026"),
                  error = function(e) NULL)
  types <- rec$values$types
  if (is.list(types)) types else list()
}

#' Eintrag im Maßnahmenregister (Teil A 4.5.3)
#' @noRd
exp_m_register <- function(x, m, mm, bctx, asset_id, acquisition = FALSE) {
  dates <- exp_measure_dates(x, m, bctx)
  cls <- if (acquisition) "herstellung" else exp_code(mm[["classification"]]) %||% "auto"
  src <- if (acquisition) "rule" else exp_m_class_source(x, mm, bctx)
  pif <- exp_date(mm[["paid_in_full_date"]], bctx$grid) %||%
    (if (is.null(dates)) NULL else dates$dates[length(dates$dates)])
  cc <- exp_lgl(mm[["contractor_certified"]])
  vofi_measure(m, exp_code(mm[["measure_type"]]), classification = cls,
               classification_source = src, completion_date = dates$completion,
               paid_in_full_date = pif, contractor_certified = if (is.null(cc)) NA else cc,
               funding_choice = exp_m_funding_choice(x, m, mm), asset_id = asset_id,
               label = mm[["label"]] %||% m)
}

#' Anlagenregister: Gebäude, Grund und Boden, eigene Anlagen der Maßnahmen (Teil A 4.5.4)
#' @noRd
exp_m_assets <- function(x, bctx, bid, own_assets) {
  out <- list()
  b <- x$building
  vd <- bctx$grid$valuation_date %||% exp_date(x$project$valuation_date)
  ms <- x$measures %||% list()
  types <- vapply(ms, function(mm) exp_code(mm[["measure_type"]]) %||% "", character(1))
  obj <- names(ms)[types == "erwerb_objekt"]
  acq_any <- names(ms)[types %in% exp_m_acq_types()]
  acq_date <- if (length(acq_any) > 0L) {
    mm <- ms[[acq_any[1L]]]
    exp_date(mm[["date"]], bctx$grid) %||% exp_date(mm[["year"]], bctx$grid)
  } else {
    NULL
  }
  if (is.list(b) && length(b) > 0L) {
    pt <- x$project$project_type %||% ""
    fc <- names(ms)[vapply(ms, function(mm) isTRUE(exp_lgl(mm[["follows_construction"]])),
                           logical(1))]
    isd <- if (pt %in% c("neubau", "erwerb_neubau") && length(fc) > 0L) {
      do.call(max, lapply(fc, function(m) exp_measure_completion(x, m, bctx) %||% vd))
    } else if (length(obj) > 0L && !is.null(acq_date)) {
      acq_date
    } else if (pt %in% c("neubau", "erwerb_neubau")) {
      bctx$grid$completion_date %||% vd
    } else {
      fy <- exp_int(b[["first_occupancy_year"]]) %||% exp_int(b[["construction_year"]])
      if (is.null(fy)) vd else as.Date(sprintf("%04d-01-01", fy))
    }
    cs <- exp_base(bctx, x, "building.commercial_share") %||% 0
    land_share <- if (length(obj) > 0L) {
      exp_base(bctx, x, paste0("measures.", obj[1L], ".land_share"))
    } else {
      lv <- exp_base(bctx, x, "building.land_value_eur")
      mv <- exp_base(bctx, x, "building.market_value_eur")
      if (!is.null(lv) && !is.null(mv) && mv > 0) lv / mv else NULL
    }
    land_share <- min(max(land_share %||% 0, 0), 1)
    neubau <- names(ms)[types == "neubau"]
    csd <- if (length(neubau) > 0L) exp_measure_dates(x, neubau[1L], bctx)$first else NULL
    es <- exp_code(b[["efficiency_standard_after"]])
    la <- exp_base(bctx, x, "building.living_area_m2")
    out[[length(out) + 1L]] <- vofi_asset(
      paste0(bid, "_building"), if (cs >= 0.5) "gebaeude_nichtwohnen" else "gebaeude_wohnen",
      isd, land_share = land_share, construction_start_date = csd,
      original_completion_year = exp_int(b[["construction_year"]]),
      acquisition_date = if (length(obj) > 0L) acq_date else NULL,
      living_area_m2 = if (is.null(la)) NULL else max(la, 0),
      efficiency_standard = es, label = exp_code(b[["label"]])
    )
    out[[length(out) + 1L]] <- vofi_asset(paste0(bid, "_land"), "grund_boden",
                                          acq_date %||% vd, land_share = 1)
  }
  seen <- character(0)
  for (a in own_assets) {
    if (a$id %in% seen) next
    seen <- c(seen, a$id)
    out[[length(out) + 1L]] <- vofi_asset(a$id, a$type, a$date %||% vd, label = a$label)
  }
  out
}

#' Expander measures (Teil A 4.5.2)
#' @noRd
measures_expand <- function(block, scenario, bctx) {
  x <- scenario
  acc <- list(components = list(), financing = list())
  regs <- list()
  bid <- exp_code(x$building$building_id) %||% "b1"
  elements <- x$building$elements %||% list()
  dup <- intersect(names(block), names(elements))
  if (length(dup) > 0L) bctx$abort("expand.measures.id_shared", id = dup[1L])
  tax_cat <- if (identical(x$project$perspective, "selbstnutzer")) {
    "expense_nondeductible"
  } else {
    "expense_deductible"
  }
  own_assets <- list()
  for (m in names(block)) {
    mm <- block[[m]] %||% list()
    exp_check_id(bctx, paste0("m_", m, "_purchase"), m, 29L, "measures")
    a_node <- exp_activation_node(x, m)
    mt <- exp_code(mm[["measure_type"]]) %||% ""
    if (mt %in% exp_m_acq_types()) {
      parts <- exp_m_acquisition(x, m, mm, bctx, a_node, bid)
      acc <- exp_put(acc, "components", paste0("m_", m, "_purchase"), parts$purchase, bctx)
      acc <- exp_put(acc, "components", paste0("m_", m, "_acq"), parts$acq, bctx)
      regs[[length(regs) + 1L]] <- exp_m_register(x, m, mm, bctx, paste0(bid, "_building"),
                                                  acquisition = TRUE)
      next
    }
    asset_id <- exp_m_asset_id(mm, m, bid)
    if (!identical(asset_id, paste0(bid, "_building"))) {
      at <- exp_chr(mm[["asset_type"]])
      at <- if (length(at) == 1L) at else "gebaeude_wohnen"
      prev <- Filter(function(a) identical(a$id, asset_id), own_assets)
      if (length(prev) > 0L && !identical(prev[[1L]]$type, at)) {
        bctx$abort("expand.measures.asset_type_conflict", asset_id = asset_id, measure = m)
      }
      own_assets[[length(own_assets) + 1L]] <- list(
        id = asset_id, type = at, date = exp_measure_completion(x, m, bctx),
        label = mm[["label"]] %||% m
      )
    }
    capex_id <- paste0("m_", m, "_capex")
    acc <- exp_put(acc, "components", capex_id,
                   exp_m_capex(x, m, mm, bctx, a_node, asset_id), bctx)
    if (exp_has(x, paste0("measures.", m, ".useful_life_years"))) {
      acc <- exp_put(acc, "components", paste0("m_", m, "_repl"),
                     exp_m_repl(x, m, mm, bctx, a_node, asset_id, capex_id), bctx)
    }
    if (exp_has(x, paste0("measures.", m, ".effects.maintenance.share_of_cost_pa"))) {
      acc <- exp_put(acc, "components", paste0("m_", m, "_maint"),
                     exp_m_maint(x, m, mm, asset_id, capex_id, tax_cat), bctx)
    }
    regs[[length(regs) + 1L]] <- exp_m_register(x, m, mm, bctx, asset_id)
  }
  for (e in names(elements)) {
    el <- elements[[e]] %||% list()
    exp_check_id(bctx, paste0("m_", e, "_repl"), e, 29L, "measures")
    replacing <- names(block)[vapply(names(block), function(m) {
      e %in% exp_chr(block[[m]][["replaces_elements"]])
    }, logical(1))]
    acc <- exp_put(acc, "components", paste0("m_", e, "_repl"),
                   exp_m_element(x, e, el, bctx, bid, replacing), bctx)
    mt <- exp_code(el[["measure_type"]])
    if (!is.null(mt) && vocab_has("measure_types", mt)) {
      regs[[length(regs) + 1L]] <- vofi_measure(
        e, mt, classification = "erhaltung", classification_source = "default",
        completion_date = exp_date(el[["next_replacement"]], bctx$grid),
        asset_id = exp_code(el[["asset_id"]]) %||% paste0(bid, "_building"),
        label = el[["label"]] %||% e
      )
    }
  }
  mt <- x$building$maintenance
  if (exp_building_data(x) && is.list(mt) && !isFALSE(exp_lgl(mt[["enabled"]])) &&
        !identical(exp_code(mt[["basis"]]), "none")) {
    # Teil A 3.3, 4.5.2: die Komponente entsteht immer; ein fehlendes Bezugsziel der Fläche
    # meldet der Expander (I) und die Bezugsprüfung bzw. der Bau (E, R-115), statt sie wegzulassen
    area <- "building.maintenance.area_m2"
    if (!exp_resolvable(x, area)) {
      bctx$inform("expand.measures.maintenance_area_missing", path = area,
                  target = exp_ref_end(x, area))
    }
    acc <- exp_put(acc, "components", "m_maintenance",
                   exp_m_building_maintenance(x, bctx, names(block), tax_cat, bid), bctx)
  }
  list(components = acc$components, financing = list(),
       assets = exp_m_assets(x, bctx, bid, own_assets), measures = regs)
}

#' @noRd
typedef_expander_measures <- function() {
  vofi_type(name = "measures", kind = "expander", block = "measures", order = 10L,
            run_if_blocks = "building", expand = measures_expand)
}
