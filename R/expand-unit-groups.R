# Expander unit_groups (WS-E2, Spec 01 Teil B 1.6, 2.2, 2.3, 3.10): je vermieteter Gruppe der
# Mietpfad u_<g>_rent (rent_path), je Gruppe die Bewirtschaftungskosten u_<g>_opex
# (operating_cost), die Grundsteuer u_<g>_property_tax (nur mit Jahresbetrag in
# building.property_tax) und fuer selbstgenutzte Gruppen mit ersparter Miete u_<g>_imputed_rent.
# Mietrechtlich relevante Massnahmen, Umlagezeilen (mr_levy_allowed ueber bctx$rule auf
# deterministischen Eingaben), Kosten- und Zuschusskomponenten, Foerderkredite und Mietbindung
# werden deterministisch bestimmt; numerische Domaenenblaetter gehen als Bezuege ein.

#' Rent-Start einer Gruppe (Wert bzw. Token `completion`; Teil B 1.2)
#' @return `Date`, `"completion"` oder `NULL` (= Stichtag, Typ-Default).
#' @noRd
exp_ug_rent_start <- function(x, g, bctx) {
  raw <- x$unit_groups[[g]][["rent_start"]]
  if (identical(raw, "completion")) return("completion")
  d <- exp_date(raw, bctx$grid)
  if (!is.null(d)) return(d)
  if ((x$project$project_type %||% "") %in% c("neubau", "erwerb_neubau")) return("completion")
  NULL
}

#' Datum eines Rent-Starts (Token `completion` = Rasterfertigstellung ohne Verschiebung)
#' @noRd
exp_ug_start_date <- function(start, bctx) {
  if (identical(start, "completion")) return(bctx$grid$completion_date)
  start %||% bctx$grid$valuation_date
}

#' Bezugsfelder einer Gruppe (Pfad -> Parameter), nur vorhandene Blätter
#' @noRd
exp_ug_refs <- function(x, g, map) {
  out <- list()
  for (p in names(map)) {
    path <- paste0("unit_groups.", g, ".", map[[p]])
    if (exp_has(x, path)) out[[p]] <- node_ref(path)
  }
  out
}

#' Phasen einer Gruppe für `mr_levy_allowed` (Teil B 1.6 Nr. 4)
#' @noRd
exp_ug_phases <- function(regime, ug) {
  to_phase <- function(r) {
    switch(r %||% "paragraph_558", staffel = "staffel", index = "index", bound_social = "bound",
           "p558")
  }
  ph <- to_phase(regime)
  if (identical(regime, "staffel")) {
    ph <- c(ph, to_phase(exp_code(ug[["after_staffel_regime"]]) %||% "paragraph_558"))
  }
  if (identical(regime, "bound_social")) {
    ph <- c(ph, to_phase(exp_code(ug[["after_binding_regime"]]) %||% "paragraph_558"))
  }
  unique(ph)
}

#' Mietrechtlich relevante Maßnahmen einer Gruppe und ihre Umlagezeilen (Teil B 1.6 Nr. 4)
#' @return Liste `measures`, `levy`, `excluded` (benannt: Maßnahme -> Grund).
#' @noRd
exp_ug_rent_law <- function(x, g, regime, bctx) {
  ug <- x$unit_groups[[g]] %||% list()
  all_groups <- names(x$unit_groups %||% list())
  rlm <- character(0)
  for (k in names(x$measures %||% list())) {
    mm <- x$measures[[k]]
    kind <- exp_code(mm[["modernization_kind"]], "modernization_kind") %||% "none"
    if (identical(kind, "none")) next
    gs <- exp_chr(mm[["rent_law"]][["unit_groups"]])
    if (length(gs) == 0L) gs <- all_groups
    if (g %in% gs) rlm <- c(rlm, k)
  }
  levy <- character(0)
  excluded <- list()
  if (length(rlm) == 0L) return(list(measures = rlm, levy = levy, excluded = excluded))
  group_mode <- exp_code(ug[["rent_law"]][["modernization_levy"]]) %||% "auto"
  mrp <- NULL
  allowed_fun <- NULL
  phases <- exp_ug_phases(regime, ug)
  for (k in rlm) {
    mm <- x$measures[[k]]
    rl <- mm[["rent_law"]] %||% list()
    kind <- exp_code(mm[["modernization_kind"]], "modernization_kind")
    if (!identical(exp_code(rl[["levy"]]) %||% "auto", "auto")) {
      excluded[[k]] <- "measure_levy_none"
      next
    }
    if (!identical(group_mode, "auto")) {
      excluded[[k]] <- "group_levy_none"
      next
    }
    if (is.null(mrp)) {
      mrp <- exp_rule(bctx, "mr_params")(bctx$legal("mietrecht"), bctx$legal("mietrecht_559f"))
      allowed_fun <- exp_rule(bctx, "mr_levy_allowed")
    }
    proc <- exp_code(rl[["procedure"]], "levy_procedure") %||% "auto"
    procs <- if (identical(proc, "auto")) c("bgb_559", "bgb_559c", "bgb_559e") else proc
    lr <- exp_lgl(rl[["landlord_responsible"]]) %||% !identical(kind, "bgb_555b_6")
    grid <- expand.grid(phase = phases, procedure = procs, stringsAsFactors = FALSE)
    ok <- allowed_fun(kind = rep(kind, nrow(grid)), rent_regime = rep(regime, nrow(grid)),
                      phase = grid$phase, landlord_responsible = rep(lr, nrow(grid)),
                      procedure = grid$procedure, P = mrp)
    if (any(ok)) levy <- c(levy, k) else excluded[[k]] <- "law"
  }
  list(measures = rlm, levy = levy, excluded = excluded)
}

#' Komponente u_<g>_rent (Teil B 1.6 Nr. 2–7, 1.7)
#' @noRd
exp_ug_rent <- function(x, g, bctx, plan, tenant_id) {
  ug <- x$unit_groups[[g]] %||% list()
  pre <- paste0("unit_groups.", g, ".")
  regime <- exp_code(ug[["rent_regime"]], "rent_regime") %||% "paragraph_558"
  cmp <- list(type = "rent_path", label = ug[["label"]] %||% g, unit_group = g)
  num <- c(living_area_m2 = "living_area_m2", rent_eur_m2_month = "rent_eur_m2_month",
           rent_growth = "rent_growth", ovm_eur_m2_month = "ovm_eur_m2_month",
           voluntary_558_cap_share = "voluntary_558_cap_share",
           rent_36m_ago_eur_m2_month = "rent_36m_ago_eur_m2_month",
           kappung_rate = "rent_law.kappung_rate",
           market_rent_eur_m2_month = "market_rent_eur_m2_month",
           market_rent_growth = "market_rent_growth", turnover_rate_pa = "turnover_rate_pa",
           relet_vacancy_months = "relet_vacancy_months", vacancy_rate = "vacancy_rate",
           rent_default_rate = "rent_default_rate", extra_loss_share = "extra_loss_share",
           lease_up_months = "lease_up_months", index_rate = "index_rate",
           bound_increase_pa = "bound_increase_pa",
           voluntary_cap_per_m2 = "rent_law.voluntary_cap_per_m2",
           hardship_share = "rent_law.hardship_share",
           kuerzung_grant_years = "rent_law.kuerzung_grant_years",
           kuerzung_loan_years = "rent_law.kuerzung_loan_years")
  cmp <- c(cmp, exp_ug_refs(x, g, num))
  nu <- exp_base(bctx, x, paste0(pre, "n_units"))
  if (!is.null(nu)) cmp$n_units <- as.integer(round(nu))
  cmp$rent_regime <- regime
  codes <- c(increase_policy = "increase_policy", growth_applies_to = "growth_applies_to",
             after_staffel_regime = "after_staffel_regime",
             after_binding_regime = "after_binding_regime")
  for (p in names(codes)) {
    v <- exp_code(ug[[codes[[p]]]])
    if (!is.null(v)) cmp[[p]] <- v
  }
  rl <- ug[["rent_law"]] %||% list()
  for (p in c("modernization_levy", "voluntary_cap_mode", "drittmittel_attribution",
              "flat_559e_order", "hp_reduction_order")) {
    v <- exp_code(rl[[p]])
    if (!is.null(v)) cmp[[p]] <- v
  }
  for (p in c("section43_flat", "hp_threshold_inclusive", "interest_subsidy_in_559e",
              "kuerzung_558_5")) {
    v <- exp_lgl(rl[[p]])
    if (!is.null(v)) cmp[[p]] <- v
  }
  led <- exp_int(rl[["levy_effective_delay_months"]])
  if (!is.null(led)) cmp$levy_effective_delay_months <- led
  for (p in c("post_binding_kappung")) {
    v <- exp_lgl(ug[[p]])
    if (!is.null(v)) cmp[[p]] <- v
  }
  for (p in c("interval_months", "voluntary_558_cap_months", "index_adjust_month")) {
    v <- exp_int(ug[[p]])
    if (!is.null(v)) cmp[[p]] <- v
  }
  for (p in c("ovm_base_date", "last_558_increase_date", "market_rent_base_date")) {
    v <- exp_date(ug[[p]], bctx$grid)
    if (!is.null(v)) cmp[[p]] <- v
  }
  for (p in c("growth_from", "rent_end", "binding_end")) {
    raw <- ug[[p]]
    v <- if (identical(raw, "completion")) "completion" else exp_date(raw, bctx$grid)
    if (!is.null(v)) cmp[[p]] <- v
  }
  start <- exp_ug_rent_start(x, g, bctx)
  if (!is.null(start)) cmp$rent_start <- start
  if (!is.null(ug[["staffel_steps"]])) cmp$staffel_steps <- ug[["staffel_steps"]]
  fu <- exp_lgl(ug[["first_use_after_2014_10_01"]])
  if (is.null(fu)) {
    cy <- exp_num(x$building$construction_year)
    fu <- (x$project$project_type %||% "") %in% c("neubau", "erwerb_neubau") ||
      (!is.null(cy) && cy[1L] >= 2015)
  }
  cmp$first_use_after_2014_10_01 <- fu
  mun <- x$project$municipality %||% list()
  flags <- c(kappung_15_area = "kappung_15_area", brake_area = "mietpreisbremse_area",
             index_cap_area = "index_cap_area")
  for (p in names(flags)) {
    v <- exp_lgl(mun[[flags[[p]]]])
    if (!is.null(v)) cmp[[p]] <- v
  }
  bu <- exp_date(mun[["mietpreisbremse_until"]], bctx$grid)
  if (!is.null(bu)) cmp$brake_until <- bu
  rr <- names(ug[["rent_roll"]] %||% list())
  if (length(rr) > 0L) cmp$rent_roll_units <- rr
  # Mietbindung (Nr. 6)
  for (f in names(plan)) {
    fs <- x$funding[[f]]
    if (!identical(plan[[f]]$type, "rent_binding")) next
    if (!(g %in% fund_groups(x, fs))) next
    bp <- paste0("funding.", f, ".rent_binding.")
    cmp$rent_regime <- "bound_social"
    regime <- "bound_social"
    if (exp_has(x, paste0(bp, "rent_eur_m2_month"))) {
      cmp$rent_eur_m2_month <- node_ref(paste0(bp, "rent_eur_m2_month"))
    }
    if (exp_has(x, paste0(bp, "increase_pa"))) {
      cmp$bound_increase_pa <- node_ref(paste0(bp, "increase_pa"))
    }
    yrs <- exp_num(fs[["rent_binding"]][["years"]])
    if (!is.null(yrs)) {
      cmp$binding_end <- grid_add_months(exp_ug_start_date(start, bctx), round(12 * yrs[1L]))
    }
    ap <- exp_base(bctx, x, paste0("funding.", f, ".approval_probability"))
    if (!is.null(ap) && ap < 1) bctx$warn("expand.unit_groups.binding_unconditional", group = g,
                                          funding = f)
    break
  }
  law <- exp_ug_rent_law(x, g, regime, bctx)
  for (k in names(law$excluded)) {
    bctx$inform("expand.unit_groups.levy_excluded", group = g, measure = k,
                reason = bctx$lbl(paste0("expand.unit_groups.levy_reason.", law$excluded[[k]])))
  }
  if (identical(regime, "bound_social") && length(law$measures) > 0L) {
    bctx$inform("expand.unit_groups.bound_no_levy", group = g)
    law$levy <- character(0)
  }
  capex <- names(x$components %||% list())
  cost_ids <- paste0("m_", law$measures, "_capex")
  cost_ids <- cost_ids[cost_ids %in% capex]
  grants <- character(0)
  loans <- character(0)
  for (f in names(plan)) {
    pl <- plan[[f]]
    if (!isTRUE(pl$eligible) || length(intersect(pl$measures, law$measures)) == 0L) next
    rlaw <- x$funding[[f]][["rent_law"]] %||% list()
    if (identical(pl$type, "grant") &&
          !identical(exp_code(rlaw[["grant_counts_as"]]), "none")) {
      grants <- c(grants, pl$component)
    }
    if (pl$type %in% c("loan", "loan_with_repayment_grant", "interest_subsidy") &&
          !identical(exp_code(rlaw[["loan_counts_as"]]), "none")) {
      loans <- c(loans, f)
    }
  }
  if (length(law$measures) > 0L) cmp$rent_law_measures <- law$measures
  if (length(law$levy) > 0L) cmp$levy_rows <- law$levy
  if (length(cost_ids) > 0L) cmp$cost_components <- cost_ids
  if (length(grants) > 0L) cmp$grant_components <- grants
  if (length(loans) > 0L) cmp$funding_ids <- loans
  after <- c(cost_ids, grants)
  if (identical(cmp$voluntary_cap_mode, "warm_rent_neutral") && !is.null(tenant_id)) {
    cmp$tenant_cost_component <- tenant_id
    after <- c(after, tenant_id)
  }
  if (length(after) > 0L) cmp$after <- unique(after)
  cmp
}

#' Komponente u_<g>_opex (Teil B 2.2)
#' @noRd
exp_ug_opex <- function(x, g, bctx, owner, start, rent_id) {
  ug <- x$unit_groups[[g]] %||% list()
  op <- ug[["operating"]] %||% list()
  num <- c(admin_per_unit_eur_pa = "operating.admin_per_unit_eur_pa",
           admin_per_parking_eur_pa = "operating.admin_per_parking_eur_pa",
           nonrecoverable_share_of_rent = "operating.nonrecoverable_share_of_rent",
           nonrecoverable_eur_m2_pa = "operating.nonrecoverable_eur_m2_pa",
           recoverable_opex_eur_m2_month = "operating.recoverable_opex_eur_m2_month",
           growth = "operating.growth", opex_growth = "operating.opex_growth",
           living_area_m2 = "living_area_m2")
  cmp <- c(list(type = "operating_cost",
                label = bctx$lbl("expand.unit_groups.opex_label", group = ug[["label"]] %||% g)),
           exp_ug_refs(x, g, num))
  nu <- exp_base(bctx, x, paste0("unit_groups.", g, ".n_units"))
  if (!is.null(nu)) cmp$n_units <- as.integer(round(nu))
  np <- exp_int(op[["n_parking"]])
  if (!is.null(np)) cmp$n_parking <- np
  vs <- exp_code(op[["vacancy_opex_scope"]])
  if (!is.null(vs)) cmp$vacancy_opex_scope <- vs
  bd <- exp_date(op[["base_date"]], bctx$grid)
  if (!is.null(bd)) cmp$base_date <- bd
  cmp$owner_occupied <- owner
  cmp$start_event <- start %||% bctx$grid$valuation_date
  end <- ug[["rent_end"]]
  ed <- if (identical(end, "completion")) "completion" else exp_date(end, bctx$grid)
  if (!is.null(ed)) cmp$to <- ed
  if (identical(x$project$perspective, "selbstnutzer")) cmp$perspective_tax <- "nondeductible"
  if (!is.null(rent_id)) {
    cmp$rent_component <- rent_id
    cmp$after <- rent_id
  }
  cmp
}

#' Komponente u_<g>_property_tax (Teil B 2.3) oder `NULL`
#' @noRd
exp_ug_property_tax <- function(x, g, bctx, owner, start, rent_id) {
  pt <- x$building$property_tax %||% list()
  pre <- "building.property_tax."
  groups <- names(x$unit_groups %||% list())
  share <- if (length(groups) > 1L) {
    areas <- paste0("unit_groups.", groups, ".living_area_m2")
    paste0("unit_groups.", g, ".living_area_m2 / (", paste(areas, collapse = " + "), ")")
  } else {
    NULL
  }
  with_share <- function(text) {
    if (is.null(share)) exp_text_node(text) else node_expr(paste0("(", text, ") * ", share))
  }
  base <- if (exp_has(x, paste0(pre, "amount_eur_pa"))) {
    paste0(pre, "amount_eur_pa")
  } else if (exp_has(x, paste0(pre, "assessment_amount_eur")) &&
               exp_has(x, paste0(pre, "municipal_multiplier"))) {
    paste0(pre, "assessment_amount_eur * ", pre, "municipal_multiplier")
  } else {
    NULL
  }
  if (is.null(base)) return(NULL)
  cmp <- list(type = "property_tax",
              label = bctx$lbl("expand.unit_groups.property_tax_label",
                               group = x$unit_groups[[g]][["label"]] %||% g),
              amount_eur_pa = with_share(base))
  for (f in c("land_amount_eur_pa", "amount_after_completion_eur_pa")) {
    if (exp_has(x, paste0(pre, f))) cmp[[f]] <- with_share(paste0(pre, f))
  }
  acf <- pt[["after_completion_from"]]
  acd <- if (identical(acf, "completion")) "completion" else exp_date(acf, bctx$grid)
  if (!is.null(acd)) cmp$after_completion_from <- acd
  if (exp_has(x, paste0(pre, "growth"))) cmp$growth <- node_ref(paste0(pre, "growth"))
  bd <- exp_date(pt[["base_date"]], bctx$grid)
  if (!is.null(bd)) cmp$base_date <- bd
  if (!is.null(start)) cmp$occupancy_from <- start
  cmp$owner_occupied <- owner
  if (!is.null(rent_id)) {
    cmp$rent_component <- rent_id
    cmp$after <- rent_id
  }
  cmp
}

#' Komponente u_<g>_imputed_rent (Teil B 3.10.3) oder `NULL`
#' @noRd
exp_ug_imputed <- function(x, g, bctx, start) {
  pre <- paste0("unit_groups.", g, ".")
  if (!exp_has(x, paste0(pre, "imputed_rent_eur_m2_month"))) return(NULL)
  cmp <- c(list(type = "imputed_rent",
                label = bctx$lbl("expand.unit_groups.imputed_label",
                                 group = x$unit_groups[[g]][["label"]] %||% g)),
           exp_ug_refs(x, g, c(area_m2 = "living_area_m2",
                               rent_eur_m2_month = "imputed_rent_eur_m2_month",
                               growth = "imputed_rent_growth")))
  vd <- bctx$grid$valuation_date %||% exp_date(x$project$valuation_date)
  if (!is.null(vd)) cmp$base_date <- grid_add_months(vd, 12L)
  if (!is.null(start)) cmp$start_event <- start
  cmp
}

#' Expander unit_groups (Teil B 1.6)
#' @noRd
unit_groups_expand <- function(block, scenario, bctx) {
  x <- scenario
  comps <- list()
  if (length(block) == 0L) {
    bctx$inform("expand.unit_groups.no_groups")
    return(list(components = comps, financing = list(), assets = list(), measures = list()))
  }
  plan <- fund_plan(x, bctx)
  tenant_id <- if (exp_energy_tenant(x)) "e_tenant" else NULL
  has_amount <- exp_has(x, "building.property_tax.amount_eur_pa") ||
    exp_has(x, "building.property_tax.assessment_amount_eur")
  if (exp_has(x, "building.property_tax.assessment_amount_eur") &&
        !exp_has(x, "building.property_tax.municipal_multiplier")) {
    bctx$abort("expand.unit_groups.multiplier_missing")
  }
  if (!has_amount && (exp_has(x, "building.property_tax.land_amount_eur_pa") ||
                        exp_has(x, "building.property_tax.amount_after_completion_eur_pa"))) {
    bctx$abort("expand.unit_groups.property_tax_amount_missing")
  }
  for (g in names(block)) {
    exp_check_id(bctx, paste0("u_", g, "_property_tax"), g, 25L, "unit_groups")
    owner <- exp_group_owner(x, g)
    start <- exp_ug_rent_start(x, g, bctx)
    rent_id <- NULL
    if (!owner) {
      rent_id <- paste0("u_", g, "_rent")
      comps[[rent_id]] <- exp_ug_rent(x, g, bctx, plan, tenant_id)
    }
    comps[[paste0("u_", g, "_opex")]] <- exp_ug_opex(x, g, bctx, owner, start, rent_id)
    ptx <- exp_ug_property_tax(x, g, bctx, owner, start, rent_id)
    if (!is.null(ptx)) {
      comps[[paste0("u_", g, "_property_tax")]] <- ptx
    } else if (owner) {
      bctx$warn("expand.unit_groups.property_tax_missing_owner", group = g)
    } else {
      bctx$inform("expand.unit_groups.property_tax_missing", group = g)
    }
    if (owner) {
      imp <- exp_ug_imputed(x, g, bctx, start)
      if (!is.null(imp)) comps[[paste0("u_", g, "_imputed_rent")]] <- imp
    }
  }
  list(components = comps, financing = list(), assets = list(), measures = list())
}

#' @noRd
typedef_expander_unit_groups <- function() {
  vofi_type(name = "unit_groups", kind = "expander", block = "unit_groups", order = 20L,
            expand = unit_groups_expand)
}
