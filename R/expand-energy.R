# Expander energy (WS-E2, Spec 01 Teil B 3.5; Spec 00 4.12, 7.10, R-90, N-14): Zerlegung der
# Energiezustaende (before, after, stages.<s>) in Segmente Zustand x Traeger mit Komponenten
# e_<s>_<c>_cost (energy_cost) und e_<s>_<c>_co2 (co2_cost, Traeger mit Emissionsfaktor > 0),
# Mieterkosten e_tenant (tenant_costs) und PV-Anlage e_pv (pv). Vererbung fehlender Zustandsfelder
# als Bezuege auf den Pfad des definierenden Zustands; Mengen als Ausdruecke ueber Domaenenpfade
# (Teil B 3.3, ohne Alterung); section43 ueber bctx$rule("co2_section43") auf deterministischen
# Eingaben. Gueltigkeitsfenster und Aktivierung bestimmt der Typ (en_state_weights).

#' Vererbbare Zustandsfelder (Teil B 3.2.3)
#' @noRd
exp_en_inherited <- function() {
  c("demand_kwh", "carriers", "efficiency", "efficiency_by_carrier", "jaz", "jaz_plan",
    "heat_pump_carrier", "flow_temperature_c", "section43", "service_eur_pa",
    "efficiency_degradation_pa", "extra_consumption")
}

#' Zustände in zeitlicher Ordnung mit Pfad und Basistermin (Teil B 3.5 Nr. 1)
#' @return Liste je Zustand: `id`, `path`, `node`, `measure`, `date`.
#' @noRd
exp_en_states <- function(x, bctx) {
  en <- x$energy %||% list()
  g <- bctx$grid
  out <- list()
  add <- function(id, st, path) {
    meas <- exp_code(st[["measure"]])
    raw <- st[["start_event"]]
    date <- if (identical(id, "before")) {
      g$valuation_date
    } else if (!is.null(raw) && !identical(raw, "completion")) {
      exp_date(raw, g)
    } else if (!is.null(meas)) {
      exp_measure_completion(x, meas, bctx) %||% g$completion_date
    } else {
      g$completion_date
    }
    list(id = id, path = path, node = st, measure = meas, date = date)
  }
  if (is.list(en$before)) out$before <- add("before", en$before, "energy.before")
  if (is.list(en$after)) out$after <- add("after", en$after, "energy.after")
  for (s in names(en$stages %||% list())) {
    if (s %in% c("before", "after")) bctx$abort("expand.energy.stage_reserved", state = s)
    out[[s]] <- add(s, en$stages[[s]], paste0("energy.stages.", s))
  }
  if (length(out) == 0L) return(out)
  later <- out[names(out) != "before"]
  if (length(later) > 1L) {
    dd <- vapply(later, function(s) as.numeric(s$date %||% NA), double(1))
    if (anyDuplicated(dd[!is.na(dd)])) {
      tie <- names(later)[duplicated(dd) | duplicated(dd, fromLast = TRUE)]
      bctx$abort("expand.energy.state_order", states = utl_collapse(tie))
    }
  }
  dates <- vapply(out, function(s) as.numeric(s$date %||% NA), double(1))
  ord <- order(names(out) != "before", dates, method = "radix")
  out[ord]
}

#' Wärmeträger eines Zustands in kanonischer Form (Pfadbasis der Anteile oder Kurzform)
#' @return `NULL` (keine eigene Angabe) oder Liste `carriers`, `share_path` (Präfix bzw. `NULL`).
#' @noRd
exp_en_own_carriers <- function(x, st, path, first_before) {
  sh <- st$node[["carrier_shares"]]
  if (is.list(sh) && length(sh) > 0L) {
    keep <- vapply(names(sh), function(c) {
      v <- exp_num(sh[[c]])
      is.null(v) || isTRUE(v[1L] > 0)
    }, logical(1))
    return(list(carriers = names(sh)[keep], share_path = paste0(path, ".carrier_shares")))
  }
  hc <- exp_code(st$node[["heating_carrier"]])
  if (!is.null(hc)) return(list(carriers = hc, share_path = NULL))
  if (first_before) {
    he <- exp_code(x$building$heating_existing[["carrier"]])
    if (!is.null(he)) return(list(carriers = he, share_path = NULL))
  }
  NULL
}

#' Definierende Pfade je Zustand und Feld (Vererbung, Teil B 3.2.3)
#' @return Liste je Zustand: benannte Liste Feld -> Pfadpräfix des definierenden Zustands bzw.
#'   für `carriers` die Trägerangabe aus `exp_en_own_carriers()`.
#' @noRd
exp_en_defining <- function(x, states) {
  out <- list()
  prev <- list()
  for (sid in names(states)) {
    st <- states[[sid]]
    cur <- prev
    own <- exp_en_own_carriers(x, st, st$path, identical(sid, "before"))
    if (!is.null(own)) cur$carriers <- own
    cur$new_heating <- !is.null(own) && !identical(sid, "before")
    for (f in setdiff(exp_en_inherited(), "carriers")) {
      if (!is.null(st$node[[f]])) cur[[f]] <- st$path
    }
    out[[sid]] <- cur
    prev <- cur
    prev$new_heating <- NULL
  }
  out
}

#' Wärmepumpenträger eines Zustands (ausdrücklich bzw. einziger Träger der Klasse power_hp)
#' @noRd
exp_en_hp_carrier <- function(x, def) {
  if (!is.null(def$heat_pump_carrier)) {
    return(exp_code(path_get(x, paste0(def$heat_pump_carrier, ".heat_pump_carrier"))))
  }
  carriers <- def$carriers$carriers %||% character(0)
  hp <- carriers[vapply(carriers, function(c) identical(exp_carrier_class(x, c), "power_hp"),
                        logical(1))]
  if (length(hp) == 1L) hp else NULL
}

#' Pfadtext eines Feldes im definierenden Zustand oder `NULL`
#' @noRd
exp_en_field <- function(def, field, sub = NULL) {
  p <- def[[field]]
  if (is.null(p)) return(NULL)
  paste0(p, ".", field, if (!is.null(sub)) paste0(".", sub))
}

#' Wirkungsgrad e_{s,c} als Ausdruckstext (Teil B 3.3)
#' @noRd
exp_en_eff <- function(x, def, sid, c, hp, bctx) {
  if (identical(c, hp)) {
    jaz <- exp_en_field(def, "jaz")
    if (is.null(jaz)) bctx$abort("expand.energy.jaz_missing", state = sid, carrier = c)
    return(jaz)
  }
  ebc <- def$efficiency_by_carrier
  if (!is.null(ebc) && exp_has(x, paste0(ebc, ".efficiency_by_carrier.", c))) {
    return(paste0(ebc, ".efficiency_by_carrier.", c))
  }
  eff <- exp_en_field(def, "efficiency")
  if (!is.null(eff)) return(eff)
  if (exp_carrier_class(x, c) %in% c("district_heating", "power")) return("1")
  bctx$abort("expand.energy.efficiency_missing", state = sid, carrier = c)
}

#' Anteil eines Trägers als Ausdruckstext (Pfad der Anteile bzw. 1 in der Kurzform)
#' @noRd
exp_en_share <- function(def, c) {
  sp <- def$carriers$share_path
  if (is.null(sp)) "1" else paste0(sp, ".", c)
}

#' Faktoren des Performance Gap (Pfad bzw. "1")
#' @noRd
exp_en_gap <- function(x, f) {
  p <- paste0("energy.performance_gap.", f)
  if (exp_has(x, p)) p else "1"
}

#' Verbrauchspfad eines Trägers im Vorzustand (`energy.before.consumption_kwh` bzw. building)
#' @noRd
exp_en_consumption <- function(x, c) {
  for (p in c(paste0("energy.before.consumption_kwh.", c),
              paste0("building.consumption_kwh.", c))) {
    if (exp_has(x, p)) return(p)
  }
  NULL
}

#' Basis des Vorzustands (`measured` bzw. `demand`, Teil B 3.2.2)
#' @noRd
exp_en_basis <- function(x, carriers) {
  b <- exp_code(x$energy$before[["consumption_basis"]])
  if (!is.null(b)) return(b)
  has <- length(carriers) > 0L &&
    all(vapply(carriers, function(c) !is.null(exp_en_consumption(x, c)), logical(1)))
  if (has) "measured" else "demand"
}

#' Nutzwärme eines Zustands als Ausdruckstext (Teil B 3.3)
#' @noRd
exp_en_heat <- function(x, states, defs, sid, bctx) {
  has_before <- "before" %in% names(states)
  q_before <- NULL
  if (has_before) {
    db <- defs$before
    cb <- db$carriers$carriers %||% character(0)
    hpb <- exp_en_hp_carrier(x, db)
    if (identical(exp_en_basis(x, cb), "measured")) {
      parts <- vapply(cb, function(c) {
        paste0(exp_en_consumption(x, c), " * ", exp_en_eff(x, db, "before", c, hpb, bctx))
      }, character(1))
      q_before <- paste0("(", paste(parts, collapse = " + "), ")")
    } else {
      d <- exp_en_field(db, "demand_kwh")
      if (is.null(d)) bctx$abort("expand.energy.demand_missing", state = "before")
      q_before <- paste0("(", d, " * ", exp_en_gap(x, "prebound_factor"), ")")
    }
  }
  if (identical(sid, "before")) return(q_before)
  d <- exp_en_field(defs[[sid]], "demand_kwh")
  if (is.null(d)) bctx$abort("expand.energy.demand_missing", state = sid)
  qc <- paste0("(", d, " * ", exp_en_gap(x, "rebound_factor"), ")")
  if (is.null(q_before)) return(qc)
  paste0("(", q_before, " - ", exp_en_gap(x, "realisation_factor"), " * (", q_before, " - ",
         qc, "))")
}

#' Einbaudatum der Heizung eines Zustands (Teil B 3.2.2)
#' @noRd
exp_en_installation <- function(x, states, defs, sid, bctx, prev_date) {
  st <- states[[sid]]
  own <- exp_date(st$node[["installation_date"]], bctx$grid)
  if (!is.null(own)) return(own)
  if (identical(sid, "before")) {
    iy <- exp_int(x$building$heating_existing[["installation_year"]])
    return(if (is.null(iy)) NULL else as.Date(sprintf("%04d-01-01", iy)))
  }
  if (isTRUE(defs[[sid]]$new_heating)) {
    if (!is.null(st$measure)) {
      return(exp_measure_completion(x, st$measure, bctx) %||% st$date)
    }
    return(st$date)
  }
  prev_date
}

#' Eigentümeranteil der Energie als Knoten (Teil B 3.5 Nr. 5)
#' @noRd
exp_en_owner_share <- function(x) {
  groups <- names(x$unit_groups %||% list())
  if (length(groups) == 0L) {
    return(node_const(if (identical(x$project$perspective, "selbstnutzer")) 1 else 0))
  }
  owners <- exp_owner_groups(x)
  if (length(owners) == 0L) return(node_const(0))
  if (length(owners) == length(groups)) return(node_const(1))
  num <- paste(paste0("unit_groups.", owners, ".living_area_m2"), collapse = " + ")
  den <- paste(paste0("unit_groups.", groups, ".living_area_m2"), collapse = " + ")
  node_expr(paste0("(", num, ") / (", den, ")"))
}

#' Fläche der vermieteten Gruppen als Knoten (tenant_costs)
#' @noRd
exp_en_rented_area <- function(x) {
  rented <- exp_rented_groups(x)
  if (length(rented) == 0L) {
    if (exp_has(x, "building.living_area_m2")) return(node_ref("building.living_area_m2"))
    return(node_const(0))
  }
  exp_sum_node(paste0("unit_groups.", rented, ".living_area_m2"))
}

#' Wohnfläche für das Stufenmodell (building, sonst Summe der Gruppen)
#' @noRd
exp_en_living_area <- function(x, bctx) {
  if (exp_has(x, "building.living_area_m2")) return(node_ref("building.living_area_m2"))
  groups <- names(x$unit_groups %||% list())
  if (length(groups) > 0L) return(exp_sum_node(paste0("unit_groups.", groups, ".living_area_m2")))
  bctx$abort("expand.energy.living_area_missing")
}

#' Ist der Emissionsfaktor eines Trägers im Basisfall > 0?
#' @noRd
exp_en_emits <- function(x, c, bctx) {
  v <- exp_base(bctx, x, paste0("energy.carriers.", c, ".emission_factor_kg_kwh"))
  isTRUE(!is.null(v) && v > 0)
}

#' Komponenten der Energiezustände, Mieterkosten und PV (Teil B 3.5)
#' @noRd
energy_expand <- function(block, scenario, bctx) {
  x <- scenario
  comps <- list()
  states <- exp_en_states(x, bctx)
  defs <- exp_en_defining(x, states)
  rented <- exp_rented_groups(x)
  owner_share <- exp_en_owner_share(x)
  vac_landlord <- !any(vapply(rented, function(g) {
    identical(exp_code(x$unit_groups[[g]][["operating"]][["vacancy_opex_scope"]]), "warm")
  }, logical(1)))
  cdm <- exp_ref(x, "project.construction_delay_months")
  existing <- (x$project$project_type %||% "") %in%
    tryCatch(vocab("project_type")$existing_building, error = function(e) character(0))
  pc <- NULL
  sec43_fun <- NULL
  segs <- list()
  inst_prev <- NULL
  for (sid in names(states)) {
    st <- states[[sid]]
    def <- defs[[sid]]
    carriers <- def$carriers$carriers %||% character(0)
    if (length(carriers) == 0L && length(st$node[["extra_consumption"]] %||% list()) == 0L) {
      # ohne Träger (auch nicht geerbt) keine Segmente; den Fehler meldet die Validierung
      bctx$inform("expand.energy.carriers_missing", state = sid)
      next
    }
    extra <- if (!is.null(def$extra_consumption)) {
      path_get(x, paste0(def$extra_consumption, ".extra_consumption")) %||% list()
    } else {
      list()
    }
    extra_carriers <- unique(vapply(extra, function(e) exp_code(e[["carrier"]]) %||% "",
                                    character(1)))
    all_c <- unique(c(carriers, extra_carriers[nzchar(extra_carriers)]))
    hp <- exp_en_hp_carrier(x, def)
    q <- if (length(carriers) > 0L) exp_en_heat(x, states, defs, sid, bctx) else NULL
    measured <- identical(sid, "before") && identical(exp_en_basis(x, carriers), "measured")
    inst <- exp_en_installation(x, states, defs, sid, bctx, inst_prev)
    inst_prev <- inst
    shares <- vapply(carriers, function(c) {
      sp <- def$carriers$share_path
      if (is.null(sp)) return(1)
      exp_base(bctx, x, paste0(sp, ".", c)) %||% 0
    }, double(1))
    main <- if (length(carriers) > 0L) {
      cand <- carriers[shares == max(shares)]
      exp_sort(cand)[1L]
    } else {
      NULL
    }
    for (c in all_c) {
      id <- paste0("e_", sid, "_", c, "_cost")
      if (nchar(sid) > 12L || nchar(c) > 20L || nchar(id) > 40L || !utl_is_id(id, 40L)) {
        bctx$abort("expand.energy.id_too_long", id = id, state = sid, carrier = c)
      }
      cp <- paste0("energy.carriers.", c, ".")
      cls <- exp_carrier_class(x, c)
      if (is.na(cls)) bctx$abort("expand.energy.class_missing", carrier = c)
      cmp <- list(type = "energy_cost",
                  label = bctx$lbl("expand.energy.segment_label",
                                   state = st$node[["label"]] %||% sid,
                                   carrier = x$energy$carriers[[c]][["label"]] %||% c),
                  state = sid, carrier = c, carrier_class = cls)
      if (c %in% carriers) {
        cmp$quantity_kwh_pa <- if (measured) {
          node_ref(exp_en_consumption(x, c))
        } else {
          node_expr(paste0(q, " * ", exp_en_share(def, c), " / ",
                           exp_en_eff(x, def, sid, c, hp, bctx)))
        }
      }
      xs <- names(extra)[vapply(extra, function(e) identical(exp_code(e[["carrier"]]), c),
                                logical(1))]
      if (length(xs) > 0L) {
        cmp$extra_kwh_pa <- exp_sum_node(paste0(def$extra_consumption, ".extra_consumption.",
                                                xs, ".kwh_pa"))
      }
      if (!measured && !is.null(def$efficiency_degradation_pa)) {
        cmp$efficiency_degradation_pa <- node_ref(exp_en_field(def,
                                                               "efficiency_degradation_pa"))
      }
      if (!is.null(inst)) cmp$installation_date <- inst
      for (f in c("price_eur_kwh", "price_growth", "network_fee_growth", "fee_growth",
                  "network_fee_eur_kwh", "bio_premium_eur_kwh", "base_fee_eur_pa", "vat_rate",
                  "emission_factor_kg_kwh", "ghg_factor_kg_kwh", "co2_price_eur_t")) {
        if (exp_has(x, paste0(cp, f))) cmp[[f]] <- node_ref(paste0(cp, f))
      }
      for (f in c("price_includes", "price_basis")) {
        v <- exp_code(x$energy$carriers[[c]][[f]])
        if (!is.null(v)) cmp[[f]] <- v
      }
      pbd <- exp_date(x$energy$carriers[[c]][["price_base_date"]], bctx$grid)
      if (!is.null(pbd)) cmp$price_base_date <- pbd
      if (identical(c, main) && !is.null(def$service_eur_pa)) {
        cmp$service_eur_pa <- node_ref(exp_en_field(def, "service_eur_pa"))
      }
      s43 <- if (!is.null(def$section43)) {
        exp_lgl(path_get(x, exp_en_field(def, "section43")))
      } else {
        NULL
      }
      if (is.null(s43)) {
        if (is.null(pc)) {
          pc <- exp_rule(bctx, "co2_params")(bctx$legal("co2kostaufg"), bctx$legal("bio_treppe"))
          sec43_fun <- exp_rule(bctx, "co2_section43")
        }
        s43 <- isTRUE(sec43_fun(cls, inst %||% as.Date(NA), existing, pc)[1L])
      }
      cmp$section43 <- s43
      cmp$owner_share <- owner_share
      if (length(rented) > 0L) cmp$unit_groups <- rented
      cmp$vacancy_landlord <- vac_landlord
      if (identical(sid, "before")) cmp$counterfactual_pre <- TRUE
      if (!is.null(cdm)) cmp$construction_delay_months <- cdm
      comps[[id]] <- cmp
      segs[[id]] <- list(state = sid, carrier = c, class = cls, emits = exp_en_emits(x, c, bctx),
                         hp = identical(c, hp), inst = inst, s43 = s43,
                         emergency = isTRUE(exp_lgl(st$node[["emergency_replacement"]])))
    }
  }
  seg_ids <- names(segs)
  emit_ids <- seg_ids[vapply(segs, function(s) s$emits, logical(1))]
  pre_emit <- emit_ids[vapply(segs[emit_ids], function(s) identical(s$state, "before"),
                              logical(1))]
  co2_ids <- character(0)
  if (length(emit_ids) > 0L) {
    area <- exp_en_living_area(x, bctx)
    for (eid in emit_ids) {
      s <- segs[[eid]]
      cid <- sub("_cost$", "_co2", eid)
      cmp <- list(type = "co2_cost", label = bctx$lbl("expand.energy.co2_label",
                                                      state = s$state, carrier = s$carrier),
                  energy_component = eid, all_energy_components = emit_ids,
                  living_area_m2 = area, carrier_class = s$class, section43 = s$s43,
                  emergency_replacement = s$emergency,
                  newbuild_5b = isTRUE(exp_lgl(x$energy$co2_newbuild_5b)),
                  hardship_5d = isTRUE(exp_lgl(x$energy$co2_hardship_5d)),
                  vacancy_landlord = vac_landlord)
      if (identical(s$state, "before") && length(pre_emit) > 0L) {
        cmp$pre_energy_components <- pre_emit
      }
      if (!is.null(s$inst)) cmp$installation_date <- s$inst
      if (exp_has(x, "energy.co2_landlord_share_reduction")) {
        cmp$landlord_share_reduction <- node_ref("energy.co2_landlord_share_reduction")
      }
      cmp$after <- unique(c(eid, emit_ids, cmp$pre_energy_components))
      comps[[cid]] <- cmp
      co2_ids <- c(co2_ids, cid)
    }
  }
  pv_id <- NULL
  if (is.list(x$energy$pv) && length(x$energy$pv) > 0L) {
    pv_id <- "e_pv"
    comps[[pv_id]] <- exp_en_pv(x, bctx, states, defs, segs, owner_share)
  }
  if (exp_energy_tenant(x) && length(seg_ids) > 0L) {
    pre_ids <- seg_ids[vapply(segs, function(s) identical(s$state, "before"), logical(1))]
    pre_co2 <- sub("_cost$", "_co2", intersect(pre_ids, emit_ids))
    cmp <- list(type = "tenant_costs", label = bctx$lbl("expand.energy.tenant_label"),
                energy_components = seg_ids, rented_area_m2 = exp_en_rented_area(x))
    if (length(co2_ids) > 0L) cmp$co2_components <- co2_ids
    if (!is.null(pv_id)) cmp$pv_component <- pv_id
    if (length(pre_ids) > 0L) cmp$pre_energy_components <- pre_ids
    if (length(pre_co2) > 0L) cmp$pre_co2_components <- pre_co2
    cmp$after <- unique(c(seg_ids, co2_ids, pv_id))
    comps$e_tenant <- cmp
  }
  list(components = comps, financing = list(), assets = list(), measures = list())
}

#' Komponente e_pv (Teil B 3.9)
#' @noRd
exp_en_pv <- function(x, bctx, states, defs, segs, owner_share) {
  pv <- x$energy$pv
  pre <- "energy.pv."
  cmp <- list(type = "pv", label = bctx$lbl("expand.energy.pv_label"))
  for (f in c("kwp", "specific_yield_kwh_kwp", "degradation_pa", "self_consumption_share",
              "post_tariff_price_eur_kwh", "internal_price_eur_kwh", "opex_share_of_cost",
              "opex_growth")) {
    if (exp_has(x, paste0(pre, f))) cmp[[f]] <- node_ref(paste0(pre, f))
  }
  meas <- exp_code(pv[["measure"]])
  if (!is.null(meas)) cmp$measure <- meas
  cd <- exp_date(pv[["commissioning_date"]], bctx$grid)
  if (is.null(cd) && !is.null(meas)) cd <- exp_measure_completion(x, meas, bctx)
  if (!is.null(cd)) cmp$commissioning_date <- cd
  mode <- exp_code(pv[["feed_in_mode"]]) %||% "partial"
  cmp$feed_in_mode <- mode
  if (exp_has(x, paste0(pre, "feed_in_tariff_eur_kwh"))) {
    cmp$feed_in_tariff_eur_kwh <- node_ref(paste0(pre, "feed_in_tariff_eur_kwh"))
  } else if (identical(mode, "partial")) {
    mk <- paste0("market.feed_in_tariff.", c("partial_le10kwp", "partial_10_40kwp",
                                             "partial_40_100kwp"))
    if (all(vapply(mk, function(p) exp_has(x, p), logical(1)))) {
      cmp$feed_in_tariff_eur_kwh <- node_expr(paste0(
        "(pmin(energy.pv.kwp, 10) * ", mk[1L], " + pmin(pmax(energy.pv.kwp - 10, 0), 30) * ",
        mk[2L], " + pmin(pmax(energy.pv.kwp - 40, 0), 60) * ", mk[3L], ") / energy.pv.kwp"
      ))
    }
  } else if (exp_has(x, "market.feed_in_tariff.full_le10kwp")) {
    cmp$feed_in_tariff_eur_kwh <- node_ref("market.feed_in_tariff.full_le10kwp")
  }
  ty <- exp_int(pv[["tariff_years"]])
  if (!is.null(ty)) cmp$tariff_years <- ty
  if (exp_has(x, paste0(pre, "opex_eur_pa"))) {
    cmp$opex_eur_pa <- node_ref(paste0(pre, "opex_eur_pa"))
  } else if (!is.null(meas) && exp_has(x, paste0("measures.", meas, ".cost_eur")) &&
               exp_has(x, paste0(pre, "opex_share_of_cost"))) {
    cmp$opex_eur_pa <- node_expr(paste0(pre, "opex_share_of_cost * measures.", meas,
                                        ".cost_eur"))
  }
  bd <- exp_date(pv[["base_date"]], bctx$grid)
  if (!is.null(bd)) cmp$base_date <- bd
  te <- exp_code(pv[["tax_exempt"]])
  if (!is.null(te)) cmp$tax_exempt <- te
  cmp$owner_share <- owner_share
  sc <- exp_code(pv[["self_consumption_carrier"]])
  ids <- character(0)
  for (sid in names(states)) {
    cs <- names(segs)[vapply(segs, function(s) identical(s$state, sid), logical(1))]
    if (length(cs) == 0L) next
    pick <- if (!is.null(sc)) {
      cs[vapply(segs[cs], function(s) identical(s$carrier, sc), logical(1))]
    } else {
      hp <- cs[vapply(segs[cs], function(s) s$hp, logical(1))]
      if (length(hp) > 0L) {
        hp
      } else {
        pw <- cs[vapply(segs[cs], function(s) identical(s$class, "power"), logical(1))]
        utils::head(pw, 1L)
      }
    }
    ids <- c(ids, pick)
  }
  if (length(ids) > 0L) {
    cmp$self_consumption_components <- unique(ids)
    cmp$after <- unique(ids)
  }
  cmp
}

#' @noRd
typedef_expander_energy <- function() {
  vofi_type(name = "energy", kind = "expander", block = "energy", order = 30L,
            expand = energy_expand)
}
