# Validierung Ebene 4 und blockbezogene Konsistenzregeln der Feldtabellen (WS-B; Spec 00
# Abschnitte 4.9, 4.10, 8.2, 8.6, 9.11, 10.9, 12.3; Spec 01 Teil A 1-6, Teil B 1-4, Teil C 1.11).
#
# Je Block die Regeln der Spalte "Validierung" der Feldtabellen von Spec 01, die ueber Art und
# Bereich eines einzelnen Felds hinausgehen: Pflichtangaben unter Bedingungen, Reihenfolgen von
# Terminen, Summen, Kombinationen (Fehler), sowie Plausibilitaetswarnungen und Hinweise.
# Regeln, die nur fuer Szenarien mit Domaenenbloecken gelten (Gebaeude, Massnahmen, Wohnungs-
# gruppen, Energie, Foerderung, Haushalt), laufen nur dort; reine Komponentenszenarien (Orakel,
# Lehrbuchbeispiele, Geruest; Spec 00 4.2 Fn. 1) bleiben ohne Befund. Gelesen werden Werte in
# Roh- und Knotenform; numerische Werte im Basisfall (val_base(), n = 1, ohne Ziehungen).

#' Ebene 4 einer Spezifikation
#' @param vc Prüfkontext.
#' @noRd
val_plausibility <- function(vc) {
  val_plaus_project(vc)
  val_plaus_grid(vc)
  val_plaus_analysis(vc)
  val_plaus_accounts(vc)
  val_plaus_financing(vc)
  val_plaus_library(vc)
  val_plaus_acquisition_components(vc)
  if (!vc$domain) return(invisible(NULL))
  val_plaus_building(vc)
  val_plaus_elements(vc)
  val_plaus_property_tax(vc)
  val_plaus_measures(vc)
  val_plaus_measure_rent_law(vc)
  val_plaus_acquisition(vc)
  val_plaus_maintenance(vc)
  val_plaus_unit_groups(vc)
  val_plaus_energy(vc)
  val_plaus_pv(vc)
  val_plaus_funding(vc)
  val_plaus_cumulation(vc)
  val_plaus_household(vc)
  val_plaus_residual(vc)
  invisible(NULL)
}

#' Feste Zahl oder Basisfallwert eines Pfads (Skalar)
#' @noRd
val_bv <- function(vc, path) {
  v <- val_num(path_get(vc$spec, path))
  if (length(v) == 1L) return(v)
  val_base_scalar(vc, path)
}

#' Projektart, Perspektive
#' @noRd
val_project_type <- function(vc) val_str(vc$spec$project$project_type) %||% ""

#' @noRd
val_perspective <- function(vc) val_str(vc$spec$project$perspective) %||% ""

#' Neubauprojekt (`neubau`, `erwerb_neubau`; Teil A 1.2)
#' @noRd
val_is_new_build <- function(vc) val_project_type(vc) %in% c("neubau", "erwerb_neubau")

#' Fertigstellung nach Raster (Stichtag + Bauzeit)
#' @noRd
val_grid_completion <- function(vc) {
  if (is.null(vc$vd)) return(NULL)
  c_m <- val_num(vc$spec$grid$construction_months) %||% 0
  grid_add_months(vc$vd, as.integer(round(c_m[1L])))
}

# ---------------------------------------------------------------------------------------------
# project, meta, grid, analysis, accounts (Teil A 1.1-1.5, 5.7)
# ---------------------------------------------------------------------------------------------

#' project und meta (Teil A 1.1, 1.2)
#' @noRd
val_plaus_project <- function(vc) {
  p <- vc$spec$project %||% list()
  persp <- val_perspective(vc)
  regime <- val_str(p$tax_regime)
  if (nzchar(persp) && !is.null(regime)) {
    expected <- tryCatch(vocab("tax_regime")$from_perspective[[persp]], error = function(e) NULL)
    wu_p <- startsWith(persp, "wu_")
    wu_r <- startsWith(regime, "wu_")
    if (wu_p != wu_r || (!wu_p && !is.null(expected) && !identical(regime, expected))) {
      val_add(vc, "warning", "validation.project.tax_regime_unusual", "project.tax_regime",
              value = regime, perspective = persp)
    }
  }
  if (identical(val_str(p$comparison_mode), "differential")) {
    val_add(vc, "warning", "validation.project.comparison_differential",
            "project.comparison_mode")
  }
  ls <- val_as_date(p$legal_state)
  if (!is.null(vc$vd) && !is.null(ls) && vc$vd < grid_add_months(ls, -12L)) {
    val_add(vc, "warning", "validation.project.legal_state_far", "project.valuation_date",
            value = ls)
  }
  pby <- val_num(p$price_base_year)
  if (length(pby) == 1L && !is.null(vc$vd) && pby > utl_year(vc$vd) + 5) {
    val_add(vc, "error", "validation.project.price_base_year", "project.price_base_year",
            value = as.integer(pby), max = as.integer(utl_year(vc$vd) + 5))
  }
  mu <- p$municipality
  if (is_map(mu)) {
    if (!is.null(mu$mietpreisbremse_until) &&
          !isTRUE(val_flag(mu$mietpreisbremse_area))) {
      val_add(vc, "warning", "validation.project.mietpreisbremse_until",
              "project.municipality.mietpreisbremse_until")
    }
    if (isTRUE(val_flag(mu$index_cap_area)) &&
          !("mietrecht_ii" %in% (val_chr_list(p$pending_reforms) %||% character(0)))) {
      val_add(vc, "info", "validation.project.index_cap_inactive",
              "project.municipality.index_cap_area")
    }
  }
  if ("unreleased" %in% (val_chr_list(p$pending_reforms) %||% character(0))) {
    val_add(vc, "warning", "validation.library.unreleased_used", "project.pending_reforms")
  }
  app <- val_as_date(p$application_date)
  first <- val_first_measure_date(vc)
  if (!is.null(app) && !is.null(first) && app > first && val_explicit(vc,
                                                                      "project.application_date")) {
    val_add(vc, "warning", "validation.project.application_late", "project.application_date",
            value = app, first = first)
  }
  cd <- val_as_date(vc$spec$meta$created_date)
  if (!is.null(cd) && !is.null(vc$vd) && cd > grid_add_months(vc$vd, 12L)) {
    val_add(vc, "warning", "validation.meta.created_late", "meta.created_date", value = cd)
  }
  invisible(NULL)
}

#' Frühester Termin aller Maßnahmen
#' @noRd
val_first_measure_date <- function(vc) {
  ms <- vc$spec$measures
  if (!is_map(ms) || length(ms) == 0L) return(NULL)
  d <- val_dates_c(lapply(ms, val_measure_first_date))
  if (length(d) == 0L) NULL else min(d)
}

#' Fertigstellung einer Maßnahme ohne Verschiebung (completion_date, date, year, letzter
#' Zahlungstermin)
#' @noRd
val_measure_completion <- function(m) {
  if (!is_map(m)) return(NULL)
  d <- val_as_date(m$completion_date) %||% val_as_date(m$date) %||%
    val_as_date(m$year, year = TRUE)
  if (!is.null(d)) return(d)
  sd <- val_schedule_dates(m$payment_schedule)
  if (length(sd) == 0L) NULL else max(sd)
}

#' grid (Teil A 1.3)
#' @noRd
val_plaus_grid <- function(vc) {
  g <- vc$spec$grid %||% list()
  hy <- val_num(vc$spec$project$horizon_years)
  cm <- val_num(g$construction_months)
  if (length(cm) == 1L && length(hy) == 1L && hy >= 1 && cm >= 12 * hy) {
    val_add(vc, "error", "validation.grid.construction_horizon", "grid.construction_months",
            value = as.integer(cm), max = as.integer(12 * hy - 1))
  }
  cm0 <- if (length(cm) == 1L) cm else 0
  if (vc$domain && val_is_new_build(vc) && cm0 == 0) {
    val_add(vc, "warning", "validation.grid.no_construction", "grid.construction_months")
  }
  st <- val_num(g$construction_step_months)
  if (length(st) == 1L && st < 12 && cm0 == 0 &&
        val_explicit(vc, "grid.construction_step_months")) {
    val_add(vc, "info", "validation.grid.step_ineffective", "grid.construction_step_months")
  }
  pm <- val_num(g$periods_months)
  if (length(pm) >= 1L && length(hy) == 1L && sum(pm) != 12 * hy) {
    val_add(vc, "info", "validation.grid.periods_sum", "grid.periods_months",
            value = as.integer(sum(pm)), expected = as.integer(12 * hy))
  }
  comp <- val_grid_completion(vc)
  ms <- vc$spec$measures
  if (!is.null(comp) && cm0 > 0 && is_map(ms)) {
    ends <- val_dates_c(lapply(names(ms), function(m) {
      if (!isTRUE(val_flag(ms[[m]]$follows_construction))) return(NULL)
      val_as_date(ms[[m]]$completion_date) %||% val_measure_first_date(ms[[m]])
    }))
    if (length(ends) > 0L && abs(grid_months_between(comp, max(ends))) > 3) {
      val_add(vc, "warning", "validation.grid.completion_mismatch", "grid.construction_months",
              value = max(ends), completion = comp)
    }
  }
  invisible(NULL)
}

#' analysis (Teil A 1.5)
#' @noRd
val_plaus_analysis <- function(vc) {
  a <- vc$spec$analysis %||% list()
  tl <- a$traffic_light
  if (is_map(tl)) {
    g <- val_num(tl$green_prob)
    r <- val_num(tl$red_prob)
    if (length(g) == 1L && length(r) == 1L && g <= r) {
      val_add(vc, "error", "validation.analysis.traffic_light_order",
              "analysis.traffic_light.green_prob", value = g, red = r)
    }
  }
  sy <- val_num(a$stabilization_year)
  if (length(sy) == 1L && !is.null(vc$vd) && !is.null(vc$end_date)) {
    if (sy < utl_year(vc$vd) || sy > utl_year(vc$end_date)) {
      val_add(vc, "error", "validation.analysis.stabilization_year",
              "analysis.stabilization_year", value = as.integer(sy))
    } else {
      comp <- val_grid_completion(vc)
      if (!is.null(comp) && sy < utl_year(comp)) {
        val_add(vc, "warning", "validation.analysis.stabilization_early",
                "analysis.stabilization_year", value = as.integer(sy))
      }
    }
  }
  if (vc$domain && isTRUE(val_flag(a$tenant_view)) &&
        length(val_ids(vc, "unit_groups")) == 0L) {
    val_add(vc, "warning", "validation.analysis.tenant_view_no_groups", "analysis.tenant_view")
  }
  ms <- a$mandatory_sensitivities
  if (is.list(ms) && !is_map(ms) && length(ms) > 0L) {
    ids <- character(0)
    for (i in seq_along(ms)) {
      e <- ms[[i]]
      path <- path_join("analysis.mandatory_sensitivities", i)
      if (!is_map(e)) next
      id <- val_str(e$id)
      if (is.null(id)) {
        val_add(vc, "error", "validation.required", path_join(path, "id"))
      } else if (id %in% ids) {
        val_add(vc, "error", "validation.analysis.sensitivity_id", path_join(path, "id"),
                value = id)
      }
      ids <- c(ids, id)
      tp <- val_str(e$path)
      if (is.null(tp)) {
        val_add(vc, "error", "validation.required", path_join(path, "path"))
      } else if (!path_exists(vc$spec, tp) && is.null(val_param_at(vc$spec, tp))) {
        val_add(vc, "error", "validation.analysis.sensitivity_path", path_join(path, "path"),
                value = tp)
      }
      n_ops <- sum(c("value", "delta", "add") %in% names(e))
      if (n_ops != 1L) {
        val_add(vc, "error", "validation.analysis.sensitivity_op", path, value = n_ops)
      }
      if (!is.null(tp) && (path_exists(vc$spec, tp) || !is.null(val_param_at(vc$spec, tp)))) {
        val_sensitivity_ops(vc, e, tp, path)
      }
      if (is.null(e$label)) val_add(vc, "error", "validation.required", path_join(path, "label"))
    }
  }
  invisible(NULL)
}

#' Operation einer Pflichtsensitivität gegen die Art des Zielpfads (Spec 00 4.3.14, R-82)
#'
#' `value` hat die Art des Ziels (Code bei enum, Code-Liste bei ids, Wertform bei Zahlenzielen);
#' `delta` ist nur bei Zahlenzielen, `add` nur bei Code-Listen zulässig.
#' @param vc Prüfkontext.
#' @param e Eintrag der Liste.
#' @param tp Zielpfad.
#' @param path Pfad des Eintrags.
#' @noRd
val_sensitivity_ops <- function(vc, e, tp, path) {
  p <- val_param_at(vc$spec, tp)
  tn <- path_get(vc$spec, tp)
  numeric_target <- if (!is.null(p)) {
    p$kind %in% c(val_numeric_kinds(), "integer")
  } else {
    val_is_value(tn) || (is.numeric(tn) && !is.list(tn))
  }
  codes_target <- !is.null(p) && identical(p$kind, "ids")
  if (!is.null(e$value)) {
    vp <- path_join(path, "value")
    if (!is.null(p)) {
      val_check_value(vc, e$value, p, vp)
    } else if (numeric_target) {
      val_check_number(vc, e$value, vofi_param("value"), vp)
    }
  }
  if (!is.null(e$delta) && !numeric_target) {
    val_add(vc, "error", "validation.analysis.sensitivity_op_kind", path_join(path, "delta"),
            op = "delta", target = tp)
  }
  if (!is.null(e$add)) {
    if (codes_target) {
      val_check_ids(vc, e$add, p, path_join(path, "add"))
    } else {
      val_add(vc, "error", "validation.analysis.sensitivity_op_kind", path_join(path, "add"),
              op = "add", target = tp)
    }
  }
  invisible(NULL)
}

#' accounts (Teil A 5.7; Spec 00 8.8, 12.3)
#' @noRd
val_plaus_accounts <- function(vc) {
  a <- vc$spec$accounts %||% list()
  restr <- val_chr_list(vc$spec$analysis$restrictions) %||% character(0)
  if ("liquidity" %in% restr) {
    lim <- val_base(vc, "accounts.overdraft_limit_eur", "path") %||%
      val_num(a$overdraft_limit_eur)
    thr <- val_num(a$overdraft_flag_threshold_eur) %||% Inf
    if (length(lim) > 0L && all(is.infinite(lim)) && all(is.infinite(thr))) {
      val_add(vc, "warning", "validation.accounts.liquidity_unchecked",
              "accounts.overdraft_limit_eur")
    }
  }
  dep <- val_base(vc, "accounts.deposit_rate_pa", "path")
  od <- val_base(vc, "accounts.overdraft_rate_pa", "path")
  if (length(dep) > 0L && length(dep) == length(od) && any(dep > od + 1e-12)) {
    val_add(vc, "warning", "validation.accounts.deposit_above_overdraft",
            "accounts.deposit_rate_pa")
  }
  if ("loan_prepay" %in% (val_chr_list(a$surplus_order) %||% character(0))) {
    val_add(vc, "warning", "validation.accounts.loan_prepay", "accounts.surplus_order")
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Finanzierung (Teil A 5.2, 5.3, 5.5; Spec 00 8.2, 8.6)
# ---------------------------------------------------------------------------------------------

#' Kreditbausteine: Bestandsdarlehen, Termine, Auszahlungsplan, Tilgung, Tilgungszuschuss
#' @noRd
val_plaus_financing <- function(vc) {
  fin <- vc$spec$financing
  targets <- val_overlay_targets(vc)
  for (id in names(fin)) {
    comp <- fin[[id]]
    def <- if (is_map(comp)) scn_type_def(comp$type, "financing") else NULL
    if (!identical(def$kind, "instrument")) next
    path <- path_join("financing", id)
    amount <- comp$amount_eur
    is_auto <- (node_is(amount) && identical(amount$kind, "auto")) ||
      (utl_is_string(amount) && amount %in% c("auto", "topup"))
    start <- val_as_date(comp[["start"]], year = TRUE)
    if (isTRUE(val_flag(comp$existing))) {
      gy <- val_num(comp$grace_years)
      pr <- val_num(comp$payout_rate)
      forbidden <- c(amount_eur = is_auto, draw_schedule = !is.null(comp$draw_schedule),
                     fees = is_map(comp$fees) && length(Filter(Negate(is.null), comp$fees)) > 0L &&
                       any(vapply(comp$fees, function(v) any(val_num(v) %||% 1 != 0),
                                  logical(1))),
                     payout_rate = length(pr) == 1L && pr != 1,
                     repayment_grant = !is.null(comp$repayment_grant),
                     grace_years = length(gy) == 1L && gy > 0)
      for (f in names(forbidden)[forbidden]) {
        val_add(vc, "error", "validation.financing.existing_forbidden", path_join(path, f),
                field = f)
      }
      if (!is.null(start) && !is.null(vc$vd) && start != vc$vd) {
        val_add(vc, "error", "validation.financing.existing_start", path_join(path, "start"),
                value = start)
      }
      if (vc$domain && (val_is_new_build(vc) || startsWith(val_project_type(vc), "erwerb_"))) {
        val_add(vc, "warning", "validation.financing.existing_new_build", path)
      }
    } else if (!is.null(start) && !is.null(vc$vd) && start < vc$vd) {
      val_add(vc, "error", "validation.before_valuation", path_join(path, "start"), value = start)
    }
    if (!is.null(start) && !is.null(vc$end_date) && start >= vc$end_date) {
      val_add(vc, "info", "validation.financing.after_horizon", path_join(path, "start"),
              value = start)
    }
    ds <- comp$draw_schedule
    if (node_is(ds) && identical(ds$kind, "schedule")) {
      amts <- val_num(list(kind = "series_t", values = ds$amounts)) %||%
        vapply(ds$amounts, function(a) val_num(a) %||% NA_real_, double(1))
      total <- sum(amts)
      amt <- if (is_auto) NULL else val_bv(vc, path_join(path, "amount_eur"))
      if (!anyNA(amts)) {
        if (identical(ds$unit, "share")) {
          if (abs(total - 1) > 1e-6) val_add(vc, "error", "validation.financing.draw_schedule_sum",
                                             path_join(path, "draw_schedule"), value = total)
        } else if (!is.null(amt)) {
          if (total > amt + 1e-6) {
            val_add(vc, "error", "validation.financing.draws_exceed",
                    path_join(path, "draw_schedule"), value = total, amount = amt)
          } else if (total < amt - 1e-6) {
            val_add(vc, "error", "validation.financing.draw_schedule_sum",
                    path_join(path, "draw_schedule"), value = total)
          }
        }
      }
      if (!is.null(start) && length(ds$dates) > 0L && min(ds$dates) < start) {
        val_add(vc, "error", "validation.financing.draw_before_start",
                path_join(path, "draw_schedule"), value = min(ds$dates))
      }
    }
    tau <- comp$initial_repayment_pa
    if (!is.null(tau) && !is.null(comp$installment_eur)) {
      val_add(vc, "error", "validation.financing.tau_with_installment",
              path_join(path, "initial_repayment_pa"))
    } else if (!is.null(tau) && !is.null(comp$term_years)) {
      val_add(vc, "info", "validation.financing.balloon_at_maturity",
              path_join(path, "initial_repayment_pa"))
    }
    inst <- val_num(comp$installment_eur)
    if (identical(comp$type, "annuity_loan") && length(inst) == 1L && !is_auto) {
      amt <- val_bv(vc, path_join(path, "amount_eur"))
      rate <- val_bv(vc, path_join(path, "rate_pa"))
      ppy <- val_num(comp$payments_per_year) %||% 12
      if (!is.null(amt) && !is.null(rate) && inst <= amt * rate / ppy[1L]) {
        val_add(vc, "warning", "validation.financing.negative_amortization",
                path_join(path, "installment_eur"), value = inst)
      }
    }
    rg <- comp$repayment_grant
    if (is_map(rg) && length(rg) > 0L) {
      if (!utl_is_string(comp$measure_id) && !utl_is_string(comp$funding_id)) {
        val_add(vc, "error", "validation.financing.repayment_grant_tag",
                path_join(path, "repayment_grant"))
      }
      if (!is.null(rg$share) && !is.null(rg$amount_eur)) {
        val_add(vc, "error", "validation.financing.repayment_grant_both",
                path_join(path, "repayment_grant"))
      }
      ra <- val_bv(vc, path_join(path, "repayment_grant", "amount_eur"))
      amt <- if (is_auto) NULL else val_bv(vc, path_join(path, "amount_eur"))
      if (!is.null(ra) && !is.null(amt) && ra > amt) {
        val_add(vc, "error", "validation.financing.repayment_grant_high",
                path_join(path, "repayment_grant", "amount_eur"), value = ra, amount = amt)
      }
    }
    if (isTRUE(val_flag(comp$prepay_allowed)) && utl_is_string(comp$program)) {
      val_add(vc, "warning", "validation.financing.prepay_program",
              path_join(path, "prepay_allowed"))
    }
    fees <- comp$fees
    if (is_map(fees)) {
      pf <- val_num(fees$processing_fee_share)
      cf <- val_num(fees$commitment_fee_rate_month)
      if ((length(pf) == 1L && pf > 0.02) || (length(cf) == 1L && cf > 0.005)) {
        val_add(vc, "warning", "validation.financing.fee_high", path_join(path, "fees"))
      }
    }
    for (t in val_node_targets(amount)) {
      if (!is.null(t$target) && t$target %in% targets) {
        val_add(vc, "warning", "validation.financing.amount_overlay",
                path_join(path, "amount_eur"), target = t$target)
      }
    }
    mid <- val_str(comp$measure_id)
    if (!is.null(mid) && path_join("measures", mid, "delay_months") %in% targets) {
      val_add(vc, "warning", "validation.financing.delay_fixed_dates", path, measure = mid)
    }
  }
  invisible(NULL)
}

#' Ziele aller Overlay-Einträge
#' @noRd
val_overlay_targets <- function(vc) {
  st <- vc$spec$stochastic
  out <- character(0)
  for (kind in c("parameters", "processes")) {
    for (e in st[[kind]] %||% list()) {
      if (is_map(e) && utl_is_string(e$target)) out <- c(out, e$target)
    }
  }
  unique(out)
}

# ---------------------------------------------------------------------------------------------
# Bibliothek: Gültigkeit und Stand (Spec 00 4.9, 4.10; Teil C 1.11, 3.1)
# ---------------------------------------------------------------------------------------------

#' Liegt ein Pfad in einem nicht gelesenen Teilbaum? (R-115)
#'
#' Untermap einer nicht gelesenen Restwertmethode (Teil A 6.1) oder Teilbaum unter einer Map
#' mit `enabled: false` (Spec 00 4.5 Regel 2).
#' @noRd
val_path_unread <- function(vc, path) {
  segs <- path_split(path)
  for (k in seq_len(max(0L, length(segs) - 1L))) {
    node <- path_get(vc$spec, paste(segs[seq_len(k)], collapse = "."))
    if (is_map(node) && !node_is(node) && identical(val_flag(node$enabled), FALSE)) {
      return(TRUE)
    }
  }
  val_rv_unread(vc, segs)
}

#' Untermap einer nicht gelesenen Restwertmethode? (R-115; Teil A 6.1, 6.2 Nr. 5)
#' @param segs Pfadsegmente.
#' @noRd
val_rv_unread <- function(vc, segs) {
  if (length(segs) < 2L || !identical(segs[1L], "residual_value")) return(FALSE)
  methods <- val_codes("vocab:residual_method") %||% character(0)
  if (!(segs[2L] %in% methods)) return(FALSE)
  method <- val_str(vc$spec$residual_value$method) %||% "zero"
  b <- vc$spec$building
  if (!identical(segs[2L], method)) return(TRUE)
  !(is_map(b) && length(b) > 0L) && !(method %in% val_rv_methods_without_building())
}

#' Gültigkeitsfenster und Stand der verwendeten Bibliothekseinträge
#' @noRd
val_plaus_library <- function(vc) {
  prov <- vc$prov
  cols <- c("entry", "valid_from", "valid_to", "as_of")
  if (!is.data.frame(prov) || !all(cols %in% names(prov)) || nrow(prov) == 0L) {
    return(invisible(NULL))
  }
  lib <- vapply(as.character(prov$entry), function(e) utl_is_library_id(e), logical(1))
  if (!any(lib)) return(invisible(NULL))
  legal <- val_as_date(vc$spec$project$legal_state) %||% vc$vd
  done <- character(0)
  for (i in which(lib)) {
    entry <- as.character(prov$entry[i])
    path <- as.character(prov$path[i])
    if (val_path_unread(vc, path)) next          # nicht gelesener Teilbaum (R-115)
    segs <- path_split(path)
    scope <- if (segs[1L] %in% c("funding", "stochastic") && length(segs) >= 3L) {
      paste(segs[1:3], collapse = ".")
    } else {
      segs[1L]
    }
    tag <- paste(entry, scope)
    if (tag %in% done) next
    done <- c(done, tag)
    ref <- legal
    if (identical(segs[1L], "funding") && length(segs) >= 2L) {
      ref <- val_as_date(vc$spec$funding[[segs[2L]]]$application_date) %||%
        val_as_date(vc$spec$project$application_date) %||% legal
    }
    vf <- prov$valid_from[i]
    vt <- prov$valid_to[i]
    if (!is.null(ref) && ((!is.na(vf) && ref < vf) || (!is.na(vt) && ref >= vt))) {
      val_add(vc, "warning", "validation.library.outdated", path, entry = entry, date = ref)
    }
    ao <- prov$as_of[i]
    process <- startsWith(entry, "processes/")
    months <- if (process) 12L else 6L
    if (!is.null(legal) && !is.na(ao) && ao < grid_add_months(legal, -months)) {
      key <- if (process) "validation.stochastic.library_outdated" else "validation.library.stale"
      val_add(vc, "warning", key, path, entry = entry, as_of = ao, months = months)
    }
    if (identical(entry, "processes/energy_prices_mr_2026") &&
          identical(segs[1L], "stochastic") && length(segs) >= 3L) {
      e <- path_get(vc$spec, paste(segs[1:3], collapse = "."))
      sy <- val_num(vc$spec$stochastic$settings$start_year) %||%
        (if (!is.null(vc$vd)) utl_year(vc$vd) else NULL)
      if (is_map(e) && !identical(e$p_norm, "base") && !is.null(e$p_norm) &&
            length(sy) == 1L && sy != 2027) {
        val_add(vc, "info", "validation.stochastic.p_norm_start_year",
                paste(segs[1:3], collapse = "."), value = as.integer(sy))
      }
    }
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Gebäude, Bestandsbauteile, Grundsteuer (Teil A 3.1, 3.2, 4.9; Teil B 2.3, 3.2.6)
# ---------------------------------------------------------------------------------------------

#' building (Teil A 3.1, 4.9)
#' @noRd
val_plaus_building <- function(vc) {
  spec <- vc$spec
  b <- spec$building
  pt <- val_project_type(vc)
  persp <- val_perspective(vc)
  groups <- spec$unit_groups %||% list()
  if (!is_map(b) || length(b) == 0L) {
    if (startsWith(persp, "wu_") && length(groups) == 0L && length(spec$measures) > 0L) {
      val_add(vc, "error", "validation.building.n_units_missing", "building.n_units")
    }
    return(invisible(NULL))
  }
  method <- val_str(spec$residual_value$method) %||% "zero"
  if (is.null(b$building_type) && (startsWith(persp, "wu_") || identical(method,
                                                                         "income_value"))) {
    val_add(vc, "warning", "validation.building.type_missing", "building.building_type")
  }
  cy <- val_num(b$construction_year)
  y0 <- if (!is.null(vc$vd)) utl_year(vc$vd) else NULL
  basis <- val_str(b$maintenance$basis)
  need_cy <- pt %in% val_existing_project_types() ||
    (identical(basis, "iibv") && !val_is_new_build(vc))
  if (length(cy) == 0L && need_cy) {
    val_add(vc, "error", "validation.building.construction_year_missing",
            "building.construction_year")
  }
  if (length(cy) == 1L && !is.null(y0) && cy > y0 + 5) {
    val_add(vc, "error", "validation.building.construction_year_future",
            "building.construction_year", value = as.integer(cy), max = as.integer(y0 + 5))
  }
  fo <- val_num(b$first_occupancy_year)
  if (length(fo) == 1L && length(cy) == 1L && fo < cy) {
    val_add(vc, "error", "validation.building.occupancy_before_construction",
            "building.first_occupancy_year", value = as.integer(fo))
  }
  fy <- val_num(b$fictitious_construction_year)
  if (length(fy) == 1L) {
    if (length(cy) == 1L && fy < cy) {
      val_add(vc, "error", "validation.building.fictitious_before_construction",
              "building.fictitious_construction_year", value = as.integer(fy))
    } else if (!is.null(y0) && fy > y0) {
      val_add(vc, "warning", "validation.building.fictitious_future",
              "building.fictitious_construction_year", value = as.integer(fy))
    }
  }
  if (startsWith(persp, "wu_") && length(groups) == 0L && is.null(b$n_units)) {
    val_add(vc, "error", "validation.building.n_units_missing", "building.n_units")
  }
  if (length(groups) > 0L) {
    nu <- val_bv(vc, "building.n_units")
    s_nu <- sum(vapply(names(groups), function(g) {
      val_bv(vc, path_join("unit_groups", g, "n_units")) %||% NA_real_
    }, double(1)))
    if (length(nu) == 1L && !is.na(s_nu) && abs(nu - s_nu) > 1e-9) {
      val_add(vc, "warning", "validation.unit_groups.sum_units", "building.n_units", value = nu,
              sum = s_nu)
    }
    la <- val_bv(vc, "building.living_area_m2")
    s_la <- sum(vapply(names(groups), function(g) {
      val_bv(vc, path_join("unit_groups", g, "living_area_m2")) %||% NA_real_
    }, double(1)))
    if (length(la) == 1L && !is.na(s_la) && la > 0 && abs(la - s_la) / la > 0.01) {
      val_add(vc, "warning", "validation.unit_groups.sum_area", "building.living_area_m2",
              value = la, sum = s_la)
    }
  }
  nfa <- val_num(b$net_floor_area_m2)
  la <- val_bv(vc, "building.living_area_m2")
  if (length(nfa) == 1L && length(la) == 1L && la > 0 && (nfa / la < 1.1 || nfa / la > 1.5)) {
    val_add(vc, "warning", "validation.building.nfa_ratio", "building.net_floor_area_m2",
            value = nfa / la)
  }
  lv <- val_bv(vc, "building.land_value_eur")
  mv <- val_bv(vc, "building.market_value_eur")
  if (length(lv) == 1L && length(mv) == 1L && lv > mv) {
    val_add(vc, "warning", "validation.building.land_above_market", "building.land_value_eur",
            value = lv, market = mv)
  }
  ev <- b$existing_value_eur
  if (is.null(ev)) {
    if (pt %in% val_existing_project_types()) {
      val_add(vc, "info", "validation.building.no_existing_value", "building.existing_value_eur")
    }
  } else {
    if (startsWith(pt, "erwerb_")) {
      val_add(vc, "error", "validation.building.existing_value_with_purchase",
              "building.existing_value_eur")
    } else if (identical(pt, "neubau")) {
      val_add(vc, "info", "validation.building.in_kind_land", "building.existing_value_eur")
    }
    w0 <- val_bv(vc, "building.existing_value_eur")
    debt <- 0
    for (id in names(spec$financing)) {
      comp <- spec$financing[[id]]
      if (isTRUE(val_flag(comp$existing))) {
        debt <- debt + (val_bv(vc, path_join("financing", id, "amount_eur")) %||% 0)
      }
    }
    if (length(w0) == 1L && w0 < debt) {
      val_add(vc, "warning", "validation.building.negative_in_kind",
              "building.existing_value_eur", value = w0, debt = debt)
    }
  }
  pmax <- spec$residual_value$income_value$points_max
  pts <- b$modernization_points_before
  if (is_map(pts) && is_map(pmax)) {
    for (el in names(pts)) {
      v <- val_num(pts[[el]])
      mx <- val_num(pmax[[el]])
      if (length(v) == 1L && length(mx) == 1L && v > mx) {
        val_add(vc, "error", "validation.building.points_max",
                path_join("building.modernization_points_before", el), value = v, max = mx)
      }
    }
  }
  cs <- val_num(b$commercial_share)
  if (length(cs) == 1L && cs > 0) {
    val_add(vc, "warning", "validation.building.commercial_share", "building.commercial_share")
  }
  if (identical(val_str(b$energy_class_before), "H") &&
        identical(val_flag(b$wpb_flag), FALSE)) {
    val_add(vc, "info", "validation.building.wpb_hint", "building.wpb_flag")
  }
  gas <- val_num(b$consumption_kwh$gas)
  if (length(gas) == 1L && length(la) == 1L && la > 0 && gas / la < 50) {
    val_add(vc, "warning", "validation.building.consumption_low", "building.consumption_kwh.gas",
            value = gas / la)
  }
  invisible(NULL)
}

#' Bestandsbauteile (Teil A 3.2)
#' @noRd
val_plaus_elements <- function(vc) {
  els <- vc$spec$building$elements
  if (!is_map(els) || length(els) == 0L) return(invisible(NULL))
  y0 <- if (!is.null(vc$vd)) utl_year(vc$vd) else NULL
  for (e in names(els)) {
    el <- els[[e]]
    if (!is_map(el)) next
    path <- path_join("building.elements", e)
    iy <- val_num(el$installed_year)
    nr <- val_as_date(el[["next_replacement"]], year = TRUE)
    if (length(iy) == 0L && is.null(el[["next_replacement"]])) {
      val_add(vc, "error", "validation.building.element_installed_missing",
              path_join(path, "installed_year"))
    }
    if (length(iy) == 1L && !is.null(y0) && iy > y0) {
      val_add(vc, "error", "validation.building.element_installed_future",
              path_join(path, "installed_year"), value = as.integer(iy))
    }
    if (!is.null(nr) && !is.null(vc$vd) && nr < vc$vd) {
      val_add(vc, "error", "validation.building.element_next_before",
              path_join(path, "next_replacement"), value = nr)
    }
    if (!is.null(nr) && !is.null(vc$end_date) && nr > vc$end_date) {
      val_add(vc, "warning", "validation.building.element_next_after",
              path_join(path, "next_replacement"), value = nr)
    }
    if (is.null(nr) && length(iy) == 1L && !is.null(y0)) {
      ul <- val_bv(vc, path_join(path, "useful_life_years"))
      if (length(ul) == 1L && iy + ul <= y0) {
        val_add(vc, "warning", "validation.building.element_overdue", path,
                value = as.integer(iy + ul))
      }
    }
  }
  invisible(NULL)
}

#' Grundsteuer (Teil B 2.3, 1.6 Nr. 2, X-16)
#' @noRd
val_plaus_property_tax <- function(vc) {
  b <- vc$spec$building
  if (!is_map(b) || length(b) == 0L) return(invisible(NULL))
  pt <- b$property_tax
  path <- "building.property_tax"
  has_amount <- is_map(pt) && !is.null(pt$amount_eur_pa)
  has_assess <- is_map(pt) && !is.null(pt$assessment_amount_eur)
  if (has_amount && has_assess) {
    val_add(vc, "error", "validation.building.property_tax_both",
            path_join(path, "assessment_amount_eur"))
  }
  if (has_assess && is.null(pt$municipal_multiplier)) {
    val_add(vc, "error", "validation.building.property_tax_multiplier",
            path_join(path, "municipal_multiplier"))
  }
  annual <- has_amount || (has_assess && !is.null(pt$municipal_multiplier))
  if (!annual && is_map(pt) && (!is.null(pt$land_amount_eur_pa) ||
                                  !is.null(pt$amount_after_completion_eur_pa))) {
    val_add(vc, "error", "validation.building.property_tax_land_only", path)
  } else if (!annual && !has_assess) {
    # Messbetrag ohne Hebesatz meldet bereits property_tax_multiplier
    owner <- identical(val_perspective(vc), "selbstnutzer")
    val_add(vc, if (owner) "warning" else "info", "validation.building.property_tax_missing",
            path)
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Maßnahmen (Teil A 4.1, 4.5.1, 4.6.5, 4.7; Teil B 1.4)
# ---------------------------------------------------------------------------------------------

#' Erwerbstypen (Teil A 4.2)
#' @noRd
val_purchase_types <- function() c("erwerb_grundstueck", "erwerb_objekt")

#' PV-Typen (Teil A 4.5.1 Nr. 5)
#' @noRd
val_pv_types <- function() c("pv", "pv_wechselrichter", "batteriespeicher")

#' Maßnahmen: Termine, Kostenquelle, Zahlungsplan, Kostengruppen, Ohnehin, Klassifikation
#' @noRd
val_plaus_measures <- function(vc) {
  spec <- vc$spec
  ms <- spec$measures
  if (!is_map(ms) || length(ms) == 0L) return(invisible(NULL))
  pt <- val_project_type(vc)
  persp <- val_perspective(vc)
  grid_comp <- val_grid_completion(vc)
  assets <- list()
  catalog <- character(0)
  for (m in names(ms)) {
    x <- ms[[m]]
    if (!is_map(x)) next
    path <- path_join("measures", m)
    mt <- val_str(x$measure_type) %||% ""
    purchase <- mt %in% val_purchase_types()
    n_timing <- sum(!vapply(x[c("date", "year", "payment_schedule")], is.null, logical(1)))
    if (n_timing != 1L || (purchase && !is.null(x$payment_schedule))) {
      val_add(vc, "error", "validation.measures.timing", path, value = n_timing)
    }
    ps <- x$payment_schedule
    unit <- if (node_is(ps) || is_map(ps)) ps$unit else NULL
    derived <- identical(val_prov_entry(vc, path_join(path, "cost_eur")), "rule:cost_from_kg")
    if (!purchase) {
      sources <- c(cost_eur = !is.null(x$cost_eur) && !derived, cost_kg = !is.null(x$cost_kg),
                   payment_schedule = !is.null(ps) && !identical(unit, "share"))
      if (sum(sources) != 1L) {
        val_add(vc, "error", "validation.measures.cost_source", path,
                value = utl_collapse(names(sources)[sources]))
      }
    } else if (is.null(x$purchase_price_eur)) {
      val_add(vc, "error", "validation.required", path_join(path, "purchase_price_eur"))
    }
    psn <- if (is.null(ps)) NULL else val_as_node(ps, path_join(path, "payment_schedule"))
    if (node_is(psn) && identical(psn$kind, "schedule")) {
      ps <- psn
      if (identical(unit, "share")) {
        amts <- vapply(as.list(ps$amounts), function(a) val_num(a) %||% NA_real_, double(1))
        if (!anyNA(amts) && abs(sum(amts) - 1) > 1e-9) {
          val_add(vc, "error", "validation.measures.schedule_sum",
                  path_join(path, "payment_schedule"), value = sum(amts))
        }
      } else if (is.list(ps$amounts)) {
        for (a in ps$amounts) {
          ok <- is.numeric(a) || (node_is(a) && a$kind %in% c("const", "ref", "expr",
                                                              "quantity"))
          if (!ok) {
            val_add(vc, "error", "validation.measures.schedule_amount_form",
                    path_join(path, "payment_schedule"),
                    form = if (node_is(a)) a$kind else class(a)[1L])
            break
          }
        }
      }
    }
    first <- val_measure_first_date(x)
    dur <- val_num(x$duration_months) %||% 0
    if (!is.null(first) && !is.null(vc$vd)) {
      begin <- if (dur[1L] > 0) grid_add_months(first, -as.integer(dur[1L])) else first
      if (begin < vc$vd) {
        val_add(vc, "error", "validation.measures.before_valuation", path, value = begin)
      }
    }
    if (dur[1L] > 0 && !is.null(ps)) {
      val_add(vc, "error", "validation.measures.duration_timing",
              path_join(path, "duration_months"))
    }
    comp_date <- val_as_date(x$completion_date)
    if (!is.null(comp_date) && !is.null(first) && comp_date < first) {
      val_add(vc, "error", "validation.measures.completion_order",
              path_join(path, "completion_date"), value = comp_date, first = first)
    }
    if (!is.null(vc$end_date)) {
      if (!is.null(comp_date) && comp_date > vc$end_date) {
        val_add(vc, "warning", "validation.measures.completion_after_horizon",
                path_join(path, "completion_date"), value = comp_date)
      }
      if (!is.null(first) && first > vc$end_date) {
        val_add(vc, "info", "validation.measures.after_horizon", path, value = first)
      }
    }
    if (isTRUE(val_flag(x$follows_construction)) && !is.null(grid_comp)) {
      cd <- comp_date %||% first
      if (!is.null(cd) && abs(grid_months_between(grid_comp, cd)) > 3) {
        val_add(vc, "warning", "validation.measures.follows_mismatch",
                path_join(path, "follows_construction"), value = cd, completion = grid_comp)
      }
    }
    kg <- val_num(x[["kg"]])
    if ((length(kg) == 1L && kg == 800) || utl_has_name(x$cost_kg %||% list(), "kg800")) {
      val_add(vc, "error", "validation.measures.kg800", path)
    }
    if (length(kg) == 1L && kg == 100 && !purchase) {
      val_add(vc, "error", "validation.measures.kg100", path_join(path, "kg"))
    }
    k7 <- val_bv(vc, path_join(path, "kg700_share"))
    c7 <- val_bv(vc, path_join(path, "cost_kg", "kg700"))
    if (length(k7) == 1L && length(c7) == 1L && k7 > 0 && c7 > 0) {
      val_add(vc, "warning", "validation.measures.kg700_double", path_join(path, "kg700_share"))
    }
    act <- val_bv(vc, path_join(path, "active"))
    if (length(act) == 1L && !(act %in% c(0, 1))) {
      val_add(vc, "warning", "validation.measures.active_fraction", path_join(path, "active"),
              value = act)
    }
    if (isTRUE(val_flag(x$vat_recoverable))) {
      val_add(vc, "error", "validation.measures.vat_recoverable",
              path_join(path, "vat_recoverable"))
    }
    if (!is.null(x$payment_profile) && dur[1L] == 0 &&
          val_explicit(vc, path_join(path, "payment_profile"))) {
      val_add(vc, "info", "validation.measures.profile_ineffective",
              path_join(path, "payment_profile"))
    }
    if (!is.null(x$ohnehin_share) && !is.null(x$ohnehin_cost_eur)) {
      val_add(vc, "error", "validation.measures.ohnehin_both", path)
    }
    oc <- val_bv(vc, path_join(path, "ohnehin_cost_eur"))
    ce <- val_bv(vc, path_join(path, "cost_eur"))
    if (length(oc) == 1L && length(ce) == 1L && oc > ce) {
      val_add(vc, "warning", "validation.measures.ohnehin_exceeds",
              path_join(path, "ohnehin_cost_eur"), value = oc, cost = ce)
    }
    if (!is.null(x$ohnehin_due_date) && !is.null(x$ohnehin_due_year)) {
      val_add(vc, "error", "validation.measures.ohnehin_due_both", path)
    }
    due <- val_as_date(x$ohnehin_due_date, year = TRUE) %||%
      val_as_date(x$ohnehin_due_year, year = TRUE)
    if (!is.null(due) && !is.null(vc$end_date) && due > vc$end_date) {
      val_add(vc, "warning", "validation.measures.ohnehin_due_after", path, value = due)
    }
    os_entry <- val_prov_entry(vc, path_join(path, "ohnehin_share"))
    if (startsWith(persp, "wu_") && !is.null(x$ohnehin_share) &&
          !is.na(os_entry) && startsWith(os_entry, "costs/")) {
      val_add(vc, "warning", "validation.measures.ohnehin_catalog",
              path_join(path, "ohnehin_share"))
    }
    cls <- val_str(x$classification)
    if (!is.null(x$tax_spread_years) && !identical(cls, "erhaltung")) {
      val_add(vc, "warning", "validation.measures.tax_spread_class",
              path_join(path, "tax_spread_years"))
    }
    share1 <- val_ohnehin_one(vc, m)
    kind <- val_str(x$modernization_kind)
    kind_entry <- val_prov_entry(vc, path_join(path, "modernization_kind"))
    if (!is.null(kind) && !identical(kind, "none") && share1 &&
          val_explicit(vc, path_join(path, "modernization_kind"))) {
      val_add(vc, "warning", "validation.measures.kind_ohnehin_conflict",
              path_join(path, "modernization_kind"), value = kind)
    }
    if (identical(kind, "none") && identical(kind_entry, "rule:measure_catalog") &&
          (identical(cls, "erhaltung") || share1)) {
      val_add(vc, "info", "validation.measures.kind_from_classification",
              path_join(path, "modernization_kind"))
    }
    if ((purchase && !(pt %in% c("erwerb_sanierung", "erwerb_neubau", "neubau"))) ||
          (identical(mt, "neubau") && pt %in% val_existing_project_types())) {
      val_add(vc, "warning", "validation.measures.type_project_mismatch",
              path_join(path, "measure_type"), value = mt, project_type = pt)
    }
    if (identical(mt, "erwerb_objekt") && is.null(x$land_share) &&
          is.null(spec$building[["land_value_eur"]])) {
      val_add(vc, "error", "validation.required", path_join(path, "land_share"))
    }
    aid <- val_str(x$asset_id)
    at <- val_str(x$asset_type)
    if (!is.null(aid) && !is.null(at)) {
      if (!is.null(assets[[aid]]) && !identical(assets[[aid]], at)) {
        val_add(vc, "error", "validation.measures.asset_type_conflict", path_join(path, "asset_id"),
                value = aid)
      }
      assets[[aid]] <- assets[[aid]] %||% at
    }
    if (mt %in% val_pv_types() || identical(val_str(spec$energy$pv$measure), m)) {
      val_measure_pv_vat(vc, m, x)
    }
    fl <- vc$prov
    if (is.data.frame(fl) && "entry" %in% names(fl)) {
      hit <- startsWith(fl$path, paste0(path, ".")) &
        (fl$entry %in% "rule:measure_catalog" | startsWith(fl$entry %||% "", "costs/"))
      hit[is.na(hit)] <- FALSE
      catalog <- c(catalog, fl$path[hit])
    }
  }
  val_funding_choice(vc)
  if (length(catalog) > 0L) {
    shown <- utils::head(catalog, 10L)
    val_add(vc, "info", "validation.measures.catalog_defaults", "measures",
            value = utl_collapse(shown), n = length(catalog))
  }
  invisible(NULL)
}

#' Ohnehin-Anteil 1 im Basisfall (Teil A 4.5.1 Nr. 6)
#' @noRd
val_ohnehin_one <- function(vc, m) {
  path <- path_join("measures", m)
  os <- val_bv(vc, path_join(path, "ohnehin_share"))
  if (length(os) == 1L && abs(os - 1) < 1e-12) return(TRUE)
  oc <- val_bv(vc, path_join(path, "ohnehin_cost_eur"))
  ce <- val_bv(vc, path_join(path, "cost_eur"))
  length(oc) == 1L && length(ce) == 1L && oc >= ce && ce > 0
}

#' PV-Umsatzsteuer (Teil A 4.5.1 Nr. 5, X-25)
#' @noRd
val_measure_pv_vat <- function(vc, m, x) {
  path <- path_join("measures", m, "vat_rate")
  pv <- vc$spec$energy$pv
  if (!is_map(pv) || length(pv) == 0L) {
    val_add(vc, "info", "validation.measures.pv_vat_unchecked", path)
    return(invisible(NULL))
  }
  if (is.null(x$vat_rate) || !val_explicit(vc, path)) return(invisible(NULL))
  vat <- val_bv(vc, path)
  kwp <- val_bv(vc, "energy.pv.kwp")
  att <- isTRUE(val_flag(pv$vat_zero_rate_attested))
  if (length(vat) == 1L && length(kwp) == 1L) {
    expected <- if (kwp <= 30 || att) 0 else 0.19
    if (abs(vat - expected) > 1e-12) {
      val_add(vc, "warning", "validation.measures.pv_vat_conflict", path, value = vat,
              expected = expected)
    }
  }
  invisible(NULL)
}

#' § 35c und BEG/KfW für dieselbe Maßnahme; Fachunternehmerbescheinigung (Spec 00 10.9)
#' @noRd
val_funding_choice <- function(vc) {
  fund <- vc$spec$funding
  if (!is_map(fund) || length(fund) == 0L) return(invisible(NULL))
  by_type <- lapply(fund, function(f) val_str(f$instrument_type) %||% "")
  for (m in val_ids(vc, "measures")) {
    covers <- function(f) m %in% (val_chr_list(f$measures) %||% character(0))
    hits <- names(fund)[vapply(fund, covers, logical(1))]
    types <- unlist(by_type[hits])
    if ("tax_credit" %in% types && any(types != "tax_credit")) {
      val_add(vc, "error", "validation.measures.funding_choice_35c", path_join("measures", m),
              value = utl_collapse(hits))
    }
    if ("tax_credit" %in% types &&
          !isTRUE(val_flag(vc$spec$measures[[m]]$contractor_certified))) {
      val_add(vc, "warning", "validation.measures.contractor_35c",
              path_join("measures", m, "contractor_certified"))
    }
  }
  invisible(NULL)
}

#' Teilbaum measures.<m>.rent_law (Teil B 1.4)
#' @noRd
val_plaus_measure_rent_law <- function(vc) {
  ms <- vc$spec$measures
  states <- c("before", "after", val_ids(vc, "energy.stages"))
  for (m in names(ms)) {
    x <- ms[[m]]
    rl <- if (is_map(x)) x$rent_law else NULL
    if (!is_map(rl) || length(rl) == 0L) next
    path <- path_join("measures", m, "rent_law")
    kind <- val_str(x$modernization_kind) %||% "none"
    if (identical(val_str(rl[["levy"]]), "auto") && identical(kind, "none")) {
      val_add(vc, "info", "validation.measures.levy_ineffective", path_join(path, "levy"))
    }
    if (identical(val_str(rl$procedure), "bgb_559e") && !identical(kind, "bgb_555b_1a")) {
      val_add(vc, "error", "validation.measures.levy_procedure", path_join(path, "procedure"),
              value = kind)
    }
    fm <- val_bv(vc, path_join(path, "fictitious_maintenance_cost_eur"))
    ce <- val_bv(vc, path_join("measures", m, "cost_eur"))
    if (length(fm) == 1L && length(ce) == 1L && fm > ce) {
      val_add(vc, "warning", "validation.measures.fictitious_maintenance_high",
              path_join(path, "fictitious_maintenance_cost_eur"), value = fm, cost = ce)
    }
    hp <- val_bv(vc, path_join(path, "heating_part_share"))
    if (length(hp) == 1L && hp > 0 && !(kind %in% c("bgb_555b_1", "bgb_555b_1a"))) {
      val_add(vc, "warning", "validation.measures.heating_part_kind",
              path_join(path, "heating_part_share"), value = kind)
    }
    hs <- val_str(rl$hp_state)
    if (!is.null(hs) && !(hs %in% states)) {
      val_add(vc, "error", "validation.measures.hp_state_unknown", path_join(path, "hp_state"),
              value = hs, suggestion = utl_suggest_text(hs, states))
    }
    if (isTRUE(val_flag(rl$heat_pump)) && is.null(hs)) {
      val_add(vc, "warning", "validation.measures.hp_state_missing", path_join(path, "heat_pump"))
    }
    al <- rl$allocation
    if (is_map(al) && length(al) > 0L) {
      s <- sum(vapply(al, function(v) val_num(v) %||% NA_real_, double(1)))
      if (!is.na(s) && abs(s - 1) > 1e-9) {
        val_add(vc, "error", "validation.measures.allocation_sum", path_join(path, "allocation"),
                value = s)
      }
    }
    comp <- val_as_date(x$completion_date) %||% val_measure_first_date(x)
    dd <- val_as_date(rl$declaration_date, year = TRUE)
    if (!is.null(dd) && !is.null(comp) && dd < comp) {
      val_add(vc, "warning", "validation.measures.declaration_early",
              path_join(path, "declaration_date"), value = dd)
    }
    le <- val_as_date(rl$levy_effective_date)
    if (!is.null(le) && !is.null(vc$vd) && le < grid_add_months(vc$vd, 1L)) {
      val_add(vc, "error", "validation.measures.levy_effective_early",
              path_join(path, "levy_effective_date"), value = le)
    }
    ws <- val_as_date(rl$works_start_date, year = TRUE)
    if (!is.null(ws) && !is.null(comp) && ws > comp) {
      val_add(vc, "error", "validation.measures.works_after_completion",
              path_join(path, "works_start_date"), value = ws)
    }
  }
  invisible(NULL)
}

#' Ausdrückliche Komponenten `acquisition_cost` ohne Satz verlangen das Bundesland (Teil A 1.2)
#'
#' Gilt auch in Szenarien ohne Domänenblöcke; vom Expander erzeugte Komponenten prüft die
#' Maßnahmenregel (`val_plaus_acquisition()`). Ohne Grunderwerbsteuer (Gegenleistung im
#' Basisfall bis zur Freigrenze) entfällt die Pflicht.
#' @noRd
val_plaus_acquisition_components <- function(vc) {
  comps <- vc$spec$components
  if (!is_map(comps) || !is.null(val_str(vc$spec$project$federal_state))) {
    return(invisible(NULL))
  }
  legal <- vc$spec$legal$grunderwerbsteuer
  threshold <- val_num(legal$values$exemption_threshold_eur %||%
                         legal$exemption_threshold_eur) %||% 2500
  for (id in names(comps)) {
    comp <- comps[[id]]
    if (!is_map(comp) || !identical(comp$type, "acquisition_cost")) next
    if (!identical(comp$origin %||% "scenario", "scenario")) next
    if (!is.null(comp$grest_rate) || !is.null(val_str(comp$federal_state))) next
    path <- path_join("components", id)
    basis <- (val_bv(vc, path_join(path, "basis_eur")) %||% Inf) +
      (val_bv(vc, path_join(path, "construction_basis_eur")) %||% 0)
    if (basis > threshold[1L]) {
      val_add(vc, "error", "validation.acquisition.federal_state_missing",
              "project.federal_state", measure = id)
    }
  }
  invisible(NULL)
}

#' Erwerb: Grunderwerbsteuer und Erwerbsnebenkosten (Teil A 4.7, 4.8)
#' @noRd
val_plaus_acquisition <- function(vc) {
  spec <- vc$spec
  ms <- spec$measures
  fs <- val_str(spec$project$federal_state)
  legal <- spec$legal$grunderwerbsteuer
  threshold <- val_num(legal$values$exemption_threshold_eur %||% legal$exemption_threshold_eur) %||%
    2500
  rates <- legal$values$rates %||% legal$rates
  for (m in names(ms)) {
    x <- ms[[m]]
    if (!is_map(x) || !(val_str(x$measure_type) %||% "") %in% val_purchase_types()) next
    path <- path_join("measures", m)
    price <- val_bv(vc, path_join(path, "purchase_price_eur")) %||% 0
    uc <- isTRUE(val_flag(x[["uniform_contract"]]))
    cons <- 0
    if (uc) {
      ids <- val_chr_list(x$uniform_contract_measures) %||% character(0)
      for (k in ids) cons <- cons + (val_bv(vc, path_join("measures", k, "cost_eur")) %||% 0)
      if (length(ids) == 0L) {
        val_add(vc, "warning", "validation.acquisition.uniform_without_construction",
                path_join(path, "uniform_contract"))
      }
    }
    basis <- price + cons
    rate <- val_bv(vc, path_join(path, "grest_rate"))
    if (basis > threshold && is.null(rate)) {
      if (is.null(fs)) {
        val_add(vc, "error", "validation.acquisition.federal_state_missing",
                "project.federal_state", measure = m)
      }
      if (is.null(legal)) {
        val_add(vc, "error", "validation.acquisition.grest_inactive", path_join(path, "grest_rate"))
      }
    }
    if (!is.null(rate) && basis > threshold) {
      land_rate <- if (!is.null(fs) && is_map(rates)) val_num(rates[[fs]]) else NULL
      if (rate == 0) {
        val_add(vc, "warning", "validation.acquisition.grest_zero", path_join(path, "grest_rate"),
                value = basis)
      } else if (length(land_rate) == 1L && abs(rate - land_rate) > 1e-12) {
        val_add(vc, "warning", "validation.acquisition.grest_rate_deviation",
                path_join(path, "grest_rate"), value = rate, expected = land_rate)
      }
    }
    if (identical(x$measure_type, "erwerb_objekt")) {
      ls <- val_bv(vc, path_join(path, "land_share"))
      if (length(ls) == 1L && ls %in% c(0, 1)) {
        val_add(vc, "warning", "validation.acquisition.land_share_extreme",
                path_join(path, "land_share"), value = ls)
      }
    }
    no <- val_bv(vc, path_join(path, "notary_share"))
    lr <- val_bv(vc, path_join(path, "land_registry_share"))
    if (length(no) == 1L && length(lr) == 1L && (no + lr < 0.011 || no + lr > 0.025)) {
      val_add(vc, "warning", "validation.acquisition.ancillary_sum", path, value = no + lr)
    }
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Instandhaltung (Teil A 3.3, 4.11.4)
# ---------------------------------------------------------------------------------------------

#' Instandhaltung: Doppelzählung, Defaults, Wartung, Zeitraum
#' @noRd
val_plaus_maintenance <- function(vc) {
  spec <- vc$spec
  mt <- spec$building$maintenance
  if (!is_map(mt) || length(mt) == 0L) return(invisible(NULL))
  path <- "building.maintenance"
  s <- val_as_date(mt$start_event, year = TRUE)
  e <- val_as_date(mt$to, year = TRUE)
  if (!is.null(s) && !is.null(e) && s >= e) {
    val_add(vc, "error", "validation.maintenance.window", path_join(path, "to"), value = e)
  }
  if (identical(val_flag(mt$enabled), FALSE)) return(invisible(NULL))
  basis <- val_str(mt$basis) %||% "auto"
  if (identical(basis, "auto")) basis <- if (val_is_new_build(vc)) "iibv" else "rate"
  if (!(basis %in% c("rate", "iibv"))) return(invisible(NULL))
  rate_paths <- if (identical(basis, "rate")) path_join(path, "rate_eur_m2_pa") else
    path_join(path, "iibv.rates_eur_m2_pa", c("lt22y", "ge22y", "ge32y"))
  rates <- unlist(lapply(rate_paths, function(p) val_base(vc, p, "path")))
  flat <- length(rates) > 0L && any(rates > 0)
  ms <- spec$measures %||% list()
  repl <- any(vapply(names(ms), function(m) {
    x <- ms[[m]]
    isTRUE(val_flag(x$replacement$enabled)) || identical(val_str(x$classification),
                                                         "erhaltung") || val_ohnehin_one(vc, m)
  }, logical(1))) ||
    any(vapply(spec$building$elements %||% list(), function(el) {
      !identical(val_num(el$active), 0)
    }, logical(1)))
  excl <- isTRUE(val_flag(mt$excludes_explicit_replacements))
  if (flat && !excl && repl) {
    val_add(vc, "warning", "validation.maintenance.double_count",
            path_join(path, "excludes_explicit_replacements"))
  }
  if (excl) {
    hy <- val_num(spec$project$horizon_years)
    area <- val_bv(vc, path_join(path, "area_m2")) %||% val_bv(vc, "building.living_area_m2")
    total <- 0
    for (el in names(spec$building$elements %||% list())) {
      total <- total + (val_bv(vc, path_join("building.elements", el,
                                             "replacement_cost_eur")) %||% 0)
    }
    for (m in names(ms)) {
      if (identical(val_str(ms[[m]]$classification), "erhaltung") || val_ohnehin_one(vc, m)) {
        total <- total + (val_bv(vc, path_join("measures", m, "cost_eur")) %||% 0)
      }
    }
    k <- if (length(hy) == 1L && length(area) == 1L && area > 0) total / (hy * area) else NA_real_
    val_add(vc, "info", "validation.maintenance.replacements_excluded",
            path_join(path, "excludes_explicit_replacements"), value = k)
  }
  defaults_only <- length(rate_paths) > 0L && all(vapply(rate_paths, function(p) {
    pl <- val_prov_lookup(vc$prov, p)
    !is.na(pl$layer) && pl$layer <= 4L
  }, logical(1)))
  if (flat && defaults_only) {
    val_add(vc, "info", "validation.maintenance.default_rate", rate_paths[1L])
  }
  share_ms <- names(ms)[vapply(ms, function(x) {
    v <- val_num(x$effects$maintenance$share_of_cost_pa)
    length(v) == 1L && v > 0
  }, logical(1))]
  if (flat && !excl && length(share_ms) > 0L) {
    val_add(vc, "warning", "validation.maintenance.service_double",
            path_join("measures", share_ms[1L], "effects.maintenance.share_of_cost_pa"))
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Wohnungsgruppen (Teil B 1.2, 1.3, 2.2)
# ---------------------------------------------------------------------------------------------

#' Wohnungsgruppen: Mietregime, Termine, OVM, Verluste, Mieterliste, Umlage, Betrieb
#' @noRd
val_plaus_unit_groups <- function(vc) {
  spec <- vc$spec
  groups <- spec$unit_groups
  if (!is_map(groups) || length(groups) == 0L) return(invisible(NULL))
  persp <- val_perspective(vc)
  own_costs <- any(vapply(spec$components %||% list(), function(c) {
    identical(c$origin %||% "scenario", "scenario") &&
      (val_str(c$category) %||% "") %in% c("operating_cost", "other_cost")
  }, logical(1)))
  for (g in names(groups)) {
    x <- groups[[g]]
    if (!is_map(x)) next
    path <- path_join("unit_groups", g)
    owner <- isTRUE(val_flag(x$owner_occupied))
    regime <- val_str(x$rent_regime)
    if ((owner && !is.null(regime) && !identical(regime, "owner_occupied")) ||
          (identical(regime, "owner_occupied") && identical(val_flag(x$owner_occupied), FALSE))) {
      val_add(vc, "error", "validation.unit_groups.regime_conflict", path_join(path, "rent_regime"),
              value = regime %||% "")
    }
    if (!owner && is.null(x$rent_eur_m2_month) && !identical(regime, "owner_occupied")) {
      val_add(vc, "error", "validation.unit_groups.rent_missing",
              path_join(path, "rent_eur_m2_month"))
    }
    rs <- val_as_date(x$rent_start, year = TRUE)
    re <- val_as_date(x$rent_end, year = TRUE)
    if (!is.null(rs) && !is.null(vc$vd) && rs < vc$vd) {
      val_add(vc, "error", "validation.unit_groups.rent_start_before",
              path_join(path, "rent_start"), value = rs)
    }
    if (!is.null(rs) && !is.null(re) && re < rs) {
      val_add(vc, "error", "validation.unit_groups.rent_end_order", path_join(path, "rent_end"),
              value = re)
    }
    rent <- val_bv(vc, path_join(path, "rent_eur_m2_month"))
    ovm <- val_bv(vc, path_join(path, "ovm_eur_m2_month"))
    ip <- val_str(x$increase_policy)
    if (!is.null(ip) && ip %in% c("max", "interval", "capped")) {
      if (is.null(x$ovm_eur_m2_month)) {
        val_add(vc, "error", "validation.unit_groups.ovm_missing",
                path_join(path, "ovm_eur_m2_month"), value = ip)
      }
      if (is.null(x$rent_36m_ago_eur_m2_month)) {
        val_add(vc, "info", "validation.unit_groups.kappung_basis",
                path_join(path, "rent_36m_ago_eur_m2_month"))
      }
    }
    if (length(rent) == 1L && length(ovm) == 1L) {
      if (ovm < 0.8 * rent) {
        val_add(vc, "warning", "validation.unit_groups.ovm_low",
                path_join(path, "ovm_eur_m2_month"), value = ovm, rent = rent)
      } else if (rent > 1.2 * ovm) {
        val_add(vc, "info", "validation.unit_groups.rent_above_ovm",
                path_join(path, "rent_eur_m2_month"), value = rent, ovm = ovm)
      }
    }
    gf <- val_as_date(x$growth_from, year = TRUE)
    if (!is.null(gf) && !is.null(rs) && gf < grid_add_months(rs, 12L)) {
      val_add(vc, "warning", "validation.unit_groups.growth_early", path_join(path, "growth_from"),
              value = gf)
    }
    hist_dates <- list(val_as_date(x$last_558_increase_date))
    lh <- x$levy_history
    if (is_map(lh)) {
      for (k in names(lh)) {
        hist_dates[[length(hist_dates) + 1L]] <- val_as_date(lh[[k]]$effective_date)
        if (identical(val_str(lh[[k]]$procedure), "auto")) {
          val_add(vc, "error", "validation.unit_groups.levy_history_auto",
                  path_join(path, "levy_history", k, "procedure"))
        }
      }
    }
    hist_dates <- val_dates_c(hist_dates)
    if (length(hist_dates) > 0L && !is.null(vc$vd) && any(hist_dates > vc$vd)) {
      val_add(vc, "error", "validation.unit_groups.history_after_valuation", path,
              value = max(hist_dates))
    }
    mr <- val_bv(vc, path_join(path, "market_rent_eur_m2_month"))
    if (length(mr) == 1L && length(rent) == 1L && mr < 0.7 * rent) {
      val_add(vc, "warning", "validation.unit_groups.market_rent_low",
              path_join(path, "market_rent_eur_m2_month"), value = mr, rent = rent)
    }
    vac <- val_bv(vc, path_join(path, "vacancy_rate")) %||% 0
    rvm <- val_bv(vc, path_join(path, "relet_vacancy_months")) %||% 0
    rdr <- val_bv(vc, path_join(path, "rent_default_rate")) %||% 0
    if (rvm > 0 && vac > 0) {
      val_add(vc, "warning", "validation.unit_groups.vacancy_double",
              path_join(path, "relet_vacancy_months"))
    }
    if (rdr >= 0.02 && vac > 0) {
      val_add(vc, "warning", "validation.unit_groups.default_rate_high",
              path_join(path, "rent_default_rate"), value = rdr)
    }
    if (vac + rdr > 0.3) {
      val_add(vc, "warning", "validation.unit_groups.losses_high", path, value = vac + rdr)
    }
    if (identical(regime, "staffel")) {
      st <- x$staffel_steps
      if (is.null(st)) {
        val_add(vc, "error", "validation.unit_groups.staffel_missing",
                path_join(path, "staffel_steps"))
      } else {
        d <- val_schedule_dates(st)
        if (length(d) > 1L && any(vapply(seq_len(length(d) - 1L), function(i) {
          grid_months_between(d[i], d[i + 1L]) < 12
        }, logical(1)))) {
          val_add(vc, "error", "validation.unit_groups.staffel_interval",
                  path_join(path, "staffel_steps"))
        }
      }
    }
    if (identical(regime, "bound_social") && is.null(x$binding_end)) {
      val_add(vc, "error", "validation.unit_groups.binding_end_missing",
              path_join(path, "binding_end"))
    }
    if (identical(persp, "selbstnutzer") && !is.null(x$imputed_rent_eur_m2_month)) {
      val_add(vc, "info", "validation.unit_groups.imputed_rent_active",
              path_join(path, "imputed_rent_eur_m2_month"))
    }
    rr <- x$rent_roll
    if (is_map(rr) && length(rr) > 0L) {
      areas <- vapply(rr, function(u) val_num(u$living_area_m2) %||% NA_real_, double(1))
      la <- val_bv(vc, path_join(path, "living_area_m2"))
      nu <- val_bv(vc, path_join(path, "n_units"))
      if ((length(la) == 1L && !anyNA(areas) && la > 0 && abs(sum(areas) - la) / la > 0.005) ||
            (length(nu) == 1L && length(rr) != nu)) {
        val_add(vc, "error", "validation.unit_groups.rent_roll_mismatch",
                path_join(path, "rent_roll"))
      }
      if (length(rr) > 50L) {
        val_add(vc, "warning", "validation.unit_groups.rent_roll_large",
                path_join(path, "rent_roll"), value = length(rr))
      }
    }
    rl <- x$rent_law
    if (is_map(rl)) {
      mode <- val_str(rl$voluntary_cap_mode)
      if (identical(mode, "warm_rent_neutral")) {
        if (!is.null(rl$voluntary_cap_per_m2)) {
          val_add(vc, "error", "validation.unit_groups.cap_mode_conflict",
                  path_join(path, "rent_law.voluntary_cap_per_m2"))
        }
        if (!is_map(spec$energy$before) || length(spec$energy$before) == 0L) {
          val_add(vc, "warning", "validation.unit_groups.cap_mode_no_before",
                  path_join(path, "rent_law.voluntary_cap_mode"))
        }
      }
    }
    op <- x$operating
    if (is_map(op)) {
      nr <- val_bv(vc, path_join(path, "operating.nonrecoverable_eur_m2_pa")) %||% 0
      ns <- val_bv(vc, path_join(path, "operating.nonrecoverable_share_of_rent")) %||% 0
      if (nr > 0 && ns > 0) {
        val_add(vc, "warning", "validation.unit_groups.nonrecoverable_double",
                path_join(path, "operating"))
      }
      rp <- path_join(path, "operating.recoverable_opex_eur_m2_month")
      ent <- val_prov_entry(vc, rp)
      if (owner && own_costs && !is.null(op$recoverable_opex_eur_m2_month) &&
            identical(ent, "global#item_defaults.unit_groups")) {
        val_add(vc, "warning", "validation.unit_groups.owner_opex_double", rp)
      }
    }
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Energie und PV (Teil B 3.2, 3.9)
# ---------------------------------------------------------------------------------------------

#' Klasse eines Trägers (ausdrücklich oder aus der kanonischen id, Teil B 3.2.1)
#' @noRd
val_carrier_class <- function(vc, cid) {
  cl <- val_str(vc$spec$energy$carriers[[cid]]$class)
  if (!is.null(cl)) return(cl)
  switch(cid, gas = , gas_mfh = "gas", oil = "oil", lpg = "lpg", power = , power_mfh = "power",
         heatpump_power = , heatpump_power_mfh = "power_hp",
         district_heating = "district_heating", pellets = "biomass", NA_character_)
}

#' Starttermin eines Energiezustands (Teil B 3.2.2): Datum bzw. Jahr, Token `completion`,
#' Fertigstellung der Maßnahme; `before` ohne Angabe am Stichtag, übrige ohne Angabe und ohne
#' Maßnahme mit dem Token `completion`
#' @noRd
val_state_start <- function(vc, s, x) {
  ev <- x$start_event
  st <- val_as_date(ev, year = TRUE)
  if (!is.null(st)) return(st)
  if (identical(ev, "completion")) return(val_grid_completion(vc))
  if (utl_is_string(x$measure)) return(val_measure_completion(vc$spec$measures[[x$measure]]))
  if (identical(s, "before")) return(vc$vd)
  if (is.null(ev)) return(val_grid_completion(vc))
  NULL
}

#' Zeitliche Ordnung der Energiezustände (Teil B 3.2.2, 3.4, 3.5 Nr. 1)
#'
#' Die Zustände werden nach ihrem Starttermin geordnet (nicht nach der Reihenfolge im YAML);
#' `after` muss nicht der letzte Zustand sein. `before` ist immer der erste Zustand s_0 (3.4);
#' ein Zustand, der am Stichtag beginnt, löst ihn sofort ab. E bei gleichem Starttermin zweier
#' übriger Zustände und bei einem Zustand, der vor `before` beginnt.
#' @param vc Prüfkontext.
#' @param starts benannte Liste Zustand -> Starttermin.
#' @noRd
val_energy_state_order <- function(vc, starts) {
  if (length(starts) < 2L) return(invisible(NULL))
  d <- do.call(c, unname(starts))
  names(d) <- names(starts)
  rest <- d[names(d) != "before"]
  tie <- duplicated(rest) | duplicated(rest, fromLast = TRUE)
  before_late <- "before" %in% names(d) && any(rest < d[["before"]])
  if (any(tie) || before_late) {
    ord <- order(d, method = "radix")
    val_add(vc, "error", "validation.energy.state_order", "energy",
            value = utl_collapse(paste0(names(d)[ord], " (", format(d[ord]), ")")))
  }
  invisible(NULL)
}

#' Energieträger, Zustände, Performance Gap, CO2-Felder
#' @noRd
val_plaus_energy <- function(vc) {
  spec <- vc$spec
  en <- spec$energy
  if (!is_map(en) || length(en) == 0L) return(invisible(NULL))
  carriers <- en$carriers %||% list()
  for (cid in names(carriers)) {
    x <- carriers[[cid]]
    path <- path_join("energy.carriers", cid)
    cls <- val_carrier_class(vc, cid)
    if (is.na(cls)) {
      val_add(vc, "error", "validation.energy.carrier_class_missing", path_join(path, "class"))
      next
    }
    pr <- val_bv(vc, path_join(path, "price_eur_kwh"))
    if (identical(cls, "gas") && length(pr) == 1L && pr > 0.30) {
      val_add(vc, "warning", "validation.energy.gas_price_high", path_join(path, "price_eur_kwh"),
              value = pr)
    }
    if (identical(cls, "gas") && is.null(x$network_fee_eur_kwh)) {
      val_add(vc, "warning", "validation.energy.network_fee_missing",
              path_join(path, "network_fee_eur_kwh"))
    }
    vat <- val_bv(vc, path_join(path, "vat_rate"))
    if (identical(cls, "biomass") && length(vat) == 1L && abs(vat - 0.07) < 1e-12) {
      val_add(vc, "info", "validation.energy.vat_biomass", path_join(path, "vat_rate"))
    }
    ef <- val_bv(vc, path_join(path, "emission_factor_kg_kwh"))
    if (identical(cls, "gas") && length(ef) == 1L && ef >= 0.200 && ef <= 0.205) {
      val_add(vc, "warning", "validation.energy.emission_hi",
              path_join(path, "emission_factor_kg_kwh"), value = ef)
    }
    if (cls %in% c("gas", "oil", "lpg", "coal")) {
      if (is.null(x$co2_price_eur_t)) {
        val_add(vc, "error", "validation.energy.co2_price_missing",
                path_join(path, "co2_price_eur_t"))
      }
      if (is.null(x$bio_premium_eur_kwh)) {
        val_add(vc, "warning", "validation.energy.bio_premium_missing",
                path_join(path, "bio_premium_eur_kwh"))
      }
    }
  }
  states <- list()
  if (is_map(en$before)) states$before <- en$before
  for (s in names(en$stages %||% list())) states[[s]] <- en$stages[[s]]
  if (is_map(en$after)) states$after <- en$after
  starts <- list()
  measures_seen <- character(0)
  for (s in names(states)) {
    x <- states[[s]]
    if (!is_map(x) || length(x) == 0L) next
    path <- if (s %in% c("before", "after")) path_join("energy", s) else path_join("energy.stages",
                                                                                   s)
    st <- val_as_date(x$start_event, year = TRUE)
    if (identical(s, "before") && !is.null(st) && !is.null(vc$vd) && st != vc$vd) {
      val_add(vc, "error", "validation.energy.before_start", path_join(path, "start_event"),
              value = st)
    }
    st <- val_state_start(vc, s, x)
    if (!is.null(st)) starts[[s]] <- st
    me <- val_str(x$measure)
    if (!is.null(me)) {
      if (me %in% measures_seen) {
        val_add(vc, "error", "validation.energy.measure_twice", path_join(path, "measure"),
                value = me)
      }
      measures_seen <- c(measures_seen, me)
    }
    cb <- val_str(x$consumption_basis)
    if (identical(cb, "measured") && !identical(s, "before")) {
      val_add(vc, "error", "validation.energy.measured_outside_before",
              path_join(path, "consumption_basis"))
    }
    if (identical(s, "before") && identical(cb, "demand")) {
      val_add(vc, "warning", "validation.energy.demand_basis",
              path_join(path, "consumption_basis"))
    }
    shares <- x$carrier_shares
    if (is_map(shares) && length(shares) > 0L) {
      sv <- vapply(shares, function(v) val_num(v) %||% NA_real_, double(1))
      if (!anyNA(sv) && abs(sum(sv) - 1) > 1e-9) {
        val_add(vc, "error", "validation.energy.shares_sum", path_join(path, "carrier_shares"),
                value = sum(sv))
      }
      if (!is.null(x$heating_carrier)) {
        val_add(vc, "error", "validation.energy.heating_carrier_both",
                path_join(path, "heating_carrier"))
      }
      ck <- x$consumption_kwh
      if (is_map(ck)) {
        for (cid in setdiff(names(ck), names(shares))) {
          val_add(vc, "error", "validation.energy.consumption_carrier",
                  path_join(path, "consumption_kwh", cid), value = cid)
        }
      }
    }
    eff <- val_bv(vc, path_join(path, "efficiency"))
    heat <- val_str(x$heating_carrier) %||% (if (is_map(shares)) names(shares)[1L] else NULL)
    if (length(eff) == 1L && eff > 1.1 && !is.null(heat) &&
          val_carrier_class(vc, heat) %in% c("gas", "oil")) {
      val_add(vc, "warning", "validation.energy.efficiency_high", path_join(path, "efficiency"),
              value = eff)
    }
    ft <- val_num(x$flow_temperature_c)
    if (length(ft) == 1L && ft > 75 && !is.null(x[["jaz"]])) {
      val_add(vc, "warning", "validation.energy.flow_temperature_high",
              path_join(path, "flow_temperature_c"), value = ft)
    }
    inst <- val_as_date(x$installation_date)
    if (isTRUE(val_flag(x$emergency_replacement)) && !is.null(inst) &&
          inst > as.Date("2027-12-31")) {
      val_add(vc, "info", "validation.energy.emergency_ineffective",
              path_join(path, "emergency_replacement"))
    }
  }
  val_energy_state_order(vc, starts)
  pg <- en$performance_gap
  if (is_map(pg)) {
    rf <- val_bv(vc, "energy.performance_gap.realisation_factor")
    rb <- val_bv(vc, "energy.performance_gap.rebound_factor")
    if (length(rf) == 1L && length(rb) == 1L && rf != 1 && rb != 1) {
      val_add(vc, "info", "validation.energy.double_reduction",
              "energy.performance_gap.realisation_factor")
    }
    if (!is.null(pg$prebound_factor) &&
          identical(val_str(en$before$consumption_basis), "measured") &&
          val_explicit(vc, "energy.performance_gap.prebound_factor")) {
      val_add(vc, "warning", "validation.energy.prebound_measured",
              "energy.performance_gap.prebound_factor")
    }
  }
  red <- val_bv(vc, "energy.co2_landlord_share_reduction")
  protected <- isTRUE(val_flag(spec$building$denkmal)) ||
    isTRUE(val_flag(spec$project$municipality$milieuschutz))
  if (length(red) == 1L && red == 0 && protected) {
    val_add(vc, "warning", "validation.energy.co2_reduction_check",
            "energy.co2_landlord_share_reduction")
  }
  if (isTRUE(val_flag(en$co2_hardship_5d))) {
    val_add(vc, "warning", "validation.energy.co2_hardship", "energy.co2_hardship_5d")
  }
  for (m in names(spec$measures %||% list())) {
    v <- val_num(spec$measures[[m]]$effects$maintenance$share_of_cost_pa)
    if (!(length(v) == 1L && v > 0)) next
    for (s in names(states)) {
      x <- states[[s]]
      sv <- val_num(x$service_eur_pa)
      if (identical(val_str(x$measure), m) && length(sv) == 1L && sv > 0) {
        path <- if (s %in% c("before", "after")) path_join("energy", s) else
          path_join("energy.stages", s)
        val_add(vc, "warning", "validation.maintenance.service_double_energy",
                path_join(path, "service_eur_pa"), measure = m)
      }
    }
    pv <- en$pv
    if (is_map(pv) && identical(val_str(pv$measure), m)) {
      os <- val_num(pv$opex_share_of_cost) %||% 0
      oe <- val_num(pv$opex_eur_pa) %||% 0
      if (os > 0 || oe > 0) {
        val_add(vc, "warning", "validation.maintenance.service_double_energy", "energy.pv",
                measure = m)
      }
    }
  }
  invisible(NULL)
}

#' PV (Teil B 3.9.1)
#' @noRd
val_plaus_pv <- function(vc) {
  pv <- vc$spec$energy$pv
  if (!is_map(pv) || length(pv) == 0L) return(invisible(NULL))
  sc <- val_bv(vc, "energy.pv.self_consumption_share")
  if (identical(val_str(pv$feed_in_mode), "full") && length(sc) == 1L && sc > 0) {
    val_add(vc, "error", "validation.energy.pv_full_self", "energy.pv.feed_in_mode")
  }
  att <- val_flag(pv$vat_zero_rate_attested)
  kwp <- val_bv(vc, "energy.pv.kwp")
  # Pflicht nur jenseits der Ableitung (Teil B 3.9.1): partial > 100 kWp, full > 10 kWp
  mode <- val_str(pv$feed_in_mode) %||% "partial"
  limit <- if (identical(mode, "full")) 10 else 100
  if (is.null(pv$feed_in_tariff_eur_kwh) && length(kwp) == 1L && kwp > limit) {
    val_add(vc, "error", "validation.energy.pv_tariff_missing", "energy.pv.feed_in_tariff_eur_kwh",
            value = kwp, mode = mode)
  }
  if (isTRUE(att)) {
    val_add(vc, "info", "validation.energy.pv_vat_attested", "energy.pv.vat_zero_rate_attested")
  } else if (length(kwp) == 1L && kwp > 30) {
    val_add(vc, "warning", "validation.energy.pv_vat_full", "energy.pv.kwp", value = kwp)
  }
  ip <- val_bv(vc, "energy.pv.internal_price_eur_kwh")
  if (length(ip) == 1L && ip > 0 && identical(val_perspective(vc), "wu_genossenschaft")) {
    val_add(vc, "warning", "validation.energy.pv_internal_price",
            "energy.pv.internal_price_eur_kwh")
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Förderung (Teil B 4.2-4.4, 4.11)
# ---------------------------------------------------------------------------------------------

#' Reservierte Symbole der Förderbedingungen (Teil B 4.3.2)
#' @noRd
val_condition_reserved <- function(s) {
  startsWith(s, "funding.this.") || s %in% c("unit.owner_occupied",
                                             "heating.replaced_fossil_functional",
                                             "taxable_income_adj", "application_year")
}

#' Reservierte Symbole der Förderbedingungen ohne Punkt (Teil B 4.3.2)
#' @noRd
val_condition_plain_symbols <- function() c("taxable_income_adj", "application_year")

#' Bedingungsausdruck prüfen (Teil B 4.3.2)
#' @noRd
val_check_condition <- function(vc, text, path) {
  if (is.null(text)) return(invisible(NULL))
  ast <- tryCatch(expr_parse(text, reserved = val_condition_plain_symbols()),
                  error = function(e) e)
  if (inherits(ast, "error")) {
    val_add(vc, "error", "validation.funding.condition_invalid", path,
            detail = conditionMessage(ast))
    return(invisible(NULL))
  }
  for (s in expr_symbols(ast)) {
    if (val_condition_reserved(s)) next
    p <- val_param_at(vc$spec, s)
    if (!startsWith(s, "building.") || is.null(p) || p$kind %in% val_numeric_kinds()) {
      val_add(vc, "error", "validation.funding.condition_symbol", path, symbol = s)
    }
  }
  invisible(NULL)
}

#' Förderinstrumente: Bezüge, Berechtigung, Zeitpunkt, Bausteine, Kredit, Bedingungen
#' @noRd
val_plaus_funding <- function(vc) {
  spec <- vc$spec
  fund <- spec$funding
  if (!is_map(fund) || length(fund) == 0L) return(invisible(NULL))
  pt <- val_project_type(vc)
  persp <- val_perspective(vc)
  owner_any <- identical(persp, "selbstnutzer") ||
    any(vapply(spec$unit_groups %||% list(), function(g) isTRUE(val_flag(g$owner_occupied)),
               logical(1)))
  for (f in names(fund)) {
    x <- fund[[f]]
    if (!is_map(x)) next
    path <- path_join("funding", f)
    type <- val_str(x$instrument_type) %||% ""
    ms <- val_chr_list(x$measures) %||% character(0)
    if (length(ms) == 0L && !identical(type, "rent_binding")) {
      val_add(vc, "error", "validation.funding.measures_empty", path_join(path, "measures"))
    }
    if (type %in% c("interest_subsidy", "rent_binding") && is.null(x[[type]])) {
      val_add(vc, "error", "validation.funding.block_missing", path_join(path, type), field = type)
    }
    override <- isTRUE(val_flag(x$eligibility_override))
    if (override) {
      val_add(vc, "info", "validation.funding.eligibility_override",
              path_join(path, "eligibility_override"))
    }
    el <- x[["eligibility"]]
    if (is_map(el) && !override) {
      ptypes <- val_chr_list(el$project_types)
      if (length(ptypes) > 0L && !(pt %in% ptypes)) {
        val_add(vc, "warning", "validation.funding.not_eligible", path,
                condition = "project_types", value = pt)
      }
      mtypes <- val_chr_list(el$measure_types)
      if (length(mtypes) > 0L) {
        for (m in ms) {
          mt <- val_str(spec$measures[[m]]$measure_type)
          if (!is.null(mt) && !(mt %in% mtypes)) {
            val_add(vc, "warning", "validation.funding.not_eligible", path,
                    condition = "measure_types", value = mt)
          }
        }
      }
      apps <- val_chr_list(el$applicants)
      ap <- val_str(x$applicant)
      if (length(apps) > 0L && !is.null(ap)) {
        ok <- ap %in% apps || (identical(ap, "privatperson_vermieter") &&
                                 "privatperson" %in% apps)
        if (!ok) {
          val_add(vc, "warning", "validation.funding.not_eligible", path,
                  condition = "applicants", value = ap)
        }
      }
      cond <- el$conditions
      if (is_map(cond)) {
        if (identical(val_str(cond$owner_occupied), "required") && !owner_any) {
          val_add(vc, "warning", "validation.funding.not_eligible", path,
                  condition = "owner_occupied", value = persp)
        }
        es <- val_str(cond$efficiency_standard)
        have <- val_str(spec$building$efficiency_standard_after) %||% "none"
        if (!is.null(es) && !identical(es, have)) {
          val_add(vc, "warning", "validation.funding.not_eligible", path,
                  condition = "efficiency_standard", value = have)
        }
        if (identical(val_str(cond$ee_or_nh_class), "required")) {
          facts <- x$facts %||% list()
          if (is.null(facts$ee_class) && is.null(facts$nh_class)) {
            val_add(vc, "warning", "validation.funding.class_missing",
                    path_join(path, "repayment_grant.class"))
          }
        }
        if (!is.null(cond$taxable_income_max_eur) &&
              is.null(spec$household$taxable_income_avg_eur)) {
          val_add(vc, "error", "validation.household.taxable_income_missing",
                  "household.taxable_income_avg_eur", funding = f)
        }
      }
    }
    app <- val_as_date(x$application_date) %||% val_as_date(spec$project$application_date) %||%
      vc$vd
    first <- val_dates_c(lapply(ms, function(m) val_measure_first_date(spec$measures[[m]])))
    explicit_before <- identical(val_str(x$approval_timing), "before_start") &&
      val_explicit(vc, path_join(path, "approval_timing"))
    if (isTRUE(val_flag(x$application_before_start)) && !is.null(app) && length(first) > 0L &&
          app > min(first) && !explicit_before) {
      val_add(vc, "warning", "validation.funding.start_before_application",
              path_join(path, "application_date"), value = app, first = min(first))
    }
    apr <- val_bv(vc, path_join(path, "approval_probability"))
    if (length(apr) == 1L && apr < 0.5) {
      val_add(vc, "warning", "validation.funding.approval_low",
              path_join(path, "approval_probability"), value = apr)
    }
    es <- x$eligible_shares
    if (is_map(es)) {
      for (m in setdiff(names(es), ms)) {
        val_add(vc, "error", "validation.funding.eligible_share_measure",
                path_join(path, "eligible_shares", m), value = m)
      }
    }
    if (!is.null(x$eligible_cost_eur)) {
      val_add(vc, "info", "validation.funding.eligible_cost_set",
              path_join(path, "eligible_cost_eur"))
    }
    loan <- x[["loan"]]
    if (is_map(x$basis) && !is.null(x$basis$max_share_of_eligible_costs)) {
      val_add(vc, "error", "validation.funding.basis_loan_share",
              path_join(path, "basis.max_share_of_eligible_costs"))
    }
    if (is_map(loan)) {
      vars <- names(loan$variants %||% list())
      lv <- val_str(x$loan_variant) %||% val_str(loan$default_variant)
      if (!is.null(x$loan_variant) && !(x$loan_variant %in% vars)) {
        val_add(vc, "error", "validation.funding.loan_variant_unknown",
                path_join(path, "loan_variant"), value = utl_collapse(format(x$loan_variant)),
                suggestion = utl_suggest_text(as.character(x$loan_variant)[1L], vars))
      } else if (!is.null(lv) && lv %in% vars) {
        val_loan_term_range(vc, loan, lv, path)
      }
    }
    cr <- x$credit
    pc <- val_bv(vc, path_join(path, "prior_credit_used_eur"))
    cap <- if (is_map(cr)) val_num(cr$cap_per_object_eur) else NULL
    if (length(pc) == 1L && length(cap) == 1L && pc > cap) {
      val_add(vc, "error", "validation.funding.prior_credit",
              path_join(path, "prior_credit_used_eur"), value = pc, max = cap)
    }
    for (i in seq_along(x$degression %||% list())) {
      d <- x$degression[[i]]
      tgt <- if (is_map(d)) val_str(d$target) else NULL
      if (!is.null(tgt) && !val_library_subpath_exists(x, tgt)) {
        val_add(vc, "error", "validation.funding.degression_target",
                path_join(path, "degression", i, "target"), value = tgt)
      }
    }
    for (k in names(x$rate_components %||% list())) {
      val_check_condition(vc, val_str(x$rate_components[[k]]$condition),
                          path_join(path, "rate_components", k, "condition"))
    }
    for (k in names(x$repayment_grant$bonuses %||% list())) {
      b <- x$repayment_grant$bonuses[[k]]
      if (is_map(b)) val_check_condition(vc, val_str(b$condition),
                                         path_join(path, "repayment_grant.bonuses", k,
                                                   "condition"))
    }
    ex <- x$rate_cap$exceptions
    for (i in seq_along(if (is.list(ex)) ex else list())) {
      if (is_map(ex[[i]])) val_check_condition(vc, val_str(ex[[i]]$condition),
                                               path_join(path, "rate_cap.exceptions", i,
                                                         "condition"))
    }
  }
  invisible(NULL)
}

#' Laufzeit eines Förderkredits in den zulässigen Spannen (Teil B 4.2 loan)
#' @noRd
val_loan_term_range <- function(vc, loan, lv, path) {
  v <- loan$variants[[lv]]
  ranges <- loan$term_ranges
  if (!is_map(v) || !is_map(ranges)) return(invisible(NULL))
  rep <- val_str(v$repayment) %||% val_str(loan$repayment) %||% "annuity"
  rg <- ranges[[rep]]
  if (is.null(rg)) return(invisible(NULL))
  if (is_map(rg)) rg <- list(rg)
  term <- val_num(v$term_years)
  grace <- val_num(v$grace_years) %||% 0
  if (length(term) != 1L) return(invisible(NULL))
  ok <- any(vapply(rg, function(r) {
    tr <- val_num(r$term)
    gr <- val_num(r$grace)
    in_t <- length(tr) == 2L && term >= tr[1L] && term <= tr[2L]
    in_g <- is.null(gr) || length(gr) != 2L || (grace >= gr[1L] && grace <= gr[2L]) ||
      identical(rep, "bullet")
    in_t && in_g
  }, logical(1)))
  if (!ok) {
    val_add(vc, "error", "validation.funding.loan_term_range", path_join(path, "loan.variants",
                                                                         lv),
            value = term)
  }
  invisible(NULL)
}

#' Programmcode eines Bibliothekseintrags (Nutzlast `values.program_code`, über die Kette)
#'
#' Liest den Eintrag aus den Wurzeln `vofi_library_paths()` (bei gleicher id gewinnt der
#' spätere Pfad, Spec 00 4.9); `NULL`, wenn der Eintrag fehlt oder keinen Programmcode hat.
#' @param id Bibliotheks-id.
#' @noRd
val_lib_program_code <- function(id) {
  roots <- rev(tryCatch(vofi_library_paths(), error = function(e) character(0)))
  seen <- character(0)
  while (utl_is_string(id) && utl_is_library_id(id) && !(id %in% seen)) {
    seen <- c(seen, id)
    files <- file.path(roots, paste0(id, ".yaml"))
    files <- files[file.exists(files)]
    if (length(files) == 0L) return(NULL)
    e <- tryCatch(utl_read_yaml(files[1L]), error = function(err) NULL)
    if (!is_map(e)) return(NULL)
    pc <- if (is_map(e$values)) val_str(e$values$program_code) else NULL
    if (!is.null(pc)) return(pc)
    id <- e$from
  }
  NULL
}

#' Kumulierung (Teil B 4.11, N-12, X-18)
#'
#' Ein Eintrag x von `exclusive_with` trifft ein Instrument g, wenn x in der `from:`-Kette von g
#' liegt oder der Programmcode des Bibliothekseintrags x gleich dem `program_code` von g ist
#' (auch ohne `from`); geprüft wird in beide Richtungen.
#' @noRd
val_plaus_cumulation <- function(vc) {
  fund <- vc$spec$funding
  if (!is_map(fund) || length(fund) == 0L) return(invisible(NULL))
  prov <- vc$prov
  chain <- lapply(stats::setNames(names(fund), names(fund)), function(f) {
    out <- character(0)
    if (is.data.frame(prov) && "entry" %in% names(prov)) {
      hit <- startsWith(prov$path, paste0("funding.", f, "."))
      out <- unique(as.character(prov$entry[hit]))
      out <- out[!is.na(out) & vapply(out, utl_is_library_id, logical(1))]
    }
    unique(c(out, val_str(fund[[f]]$from)))
  })
  code_of <- vapply(fund, function(x) val_str(x$program_code) %||% NA_character_, "")
  lib_codes <- new.env(parent = emptyenv())
  lib_code <- function(x) {
    if (!exists(x, envir = lib_codes, inherits = FALSE)) {
      assign(x, val_lib_program_code(x) %||% NA_character_, envir = lib_codes)
    }
    get(x, envir = lib_codes, inherits = FALSE)
  }
  hits <- function(list_x, g) {
    if (any(list_x %in% chain[[g]])) return(TRUE)
    if (is.na(code_of[[g]])) return(FALSE)
    any(vapply(list_x, function(x) identical(lib_code(x), code_of[[g]]), logical(1)))
  }
  done <- character(0)
  for (f in names(fund)) {
    cu <- fund[[f]]$cumulation
    if (!is_map(cu)) next
    path <- path_join("funding", f, "cumulation")
    excl <- val_chr_list(cu$exclusive_with) %||% character(0)
    for (g in setdiff(names(fund), f)) {
      excl_g <- val_chr_list(fund[[g]]$cumulation$exclusive_with) %||% character(0)
      if (!(hits(excl, g) || hits(excl_g, f))) next
      common <- intersect(val_chr_list(fund[[f]]$measures) %||% character(0),
                          val_chr_list(fund[[g]]$measures) %||% character(0))
      tag <- paste(sort(c(f, g)), collapse = "\r")
      if (length(common) > 0L && !(tag %in% done)) {
        done <- c(done, tag)
        val_add(vc, "error", "validation.funding.cumulation_exclusive",
                path_join(path, "exclusive_with"), other = g, measure = common[1L])
      }
    }
    req <- val_chr_list(cu$requires) %||% character(0)
    if (length(req) > 0L && !any(vapply(setdiff(names(fund), f), function(g) hits(req, g),
                                        logical(1)))) {
      val_add(vc, "warning", "validation.funding.cumulation_requires",
              path_join(path, "requires"), value = utl_collapse(req))
    }
  }
  codes <- code_of
  yearly <- vapply(fund, function(x) {
    identical(val_str(if (is_map(x$basis)) x$basis$cap_period else NULL), "calendar_year")
  }, logical(1))
  for (code in unique(codes[!is.na(codes) & yearly])) {
    ids <- names(fund)[codes %in% code & yearly]
    if (length(ids) > 1L) {
      val_add(vc, "warning", "validation.funding.annual_cap_shared", path_join("funding", ids[2L]),
              value = code)
    }
  }
  val_cumulation_total_share(vc)
  invisible(NULL)
}

#' Zuschüsse und Tilgungszuschüsse je Maßnahme gegen die Kosten (Teil B 4.11)
#'
#' Basisfallwerte ausdrücklicher Beträge: Instrumente `grant` mit `amount_eur` (auf ihre
#' Maßnahmen nach Kosten aufgeteilt) und Tilgungszuschüsse der Finanzierungsbausteine mit
#' `measure_id` (`repayment_grant.amount_eur` bzw. `share` x `amount_eur`). Grenze ist der
#' kleinste `cumulation.max_total_share` der Instrumente der Maßnahme, ohne Angabe die Kosten.
#' Aus Fördersätzen abgeleitete Beträge entstehen erst in den Fördertypen (WS-E2).
#' @noRd
val_cumulation_total_share <- function(vc) {
  spec <- vc$spec
  ms <- val_ids(vc, "measures")
  if (length(ms) == 0L) return(invisible(NULL))
  cost <- vapply(ms, function(m) {
    v <- val_bv(vc, path_join("measures", m, "cost_eur"))
    if (length(v) == 1L && is.finite(v)) v else NA_real_
  }, double(1))
  sub <- stats::setNames(numeric(length(ms)), ms)
  cap <- stats::setNames(rep(NA_real_, length(ms)), ms)
  fund <- spec$funding %||% list()
  for (f in names(fund)) {
    x <- fund[[f]]
    if (!is_map(x)) next
    fm <- intersect(val_chr_list(x$measures) %||% character(0), ms)
    if (length(fm) == 0L) next
    sh <- val_bv(vc, path_join("funding", f, "cumulation", "max_total_share"))
    if (length(sh) == 1L && is.finite(sh)) cap[fm] <- pmin(cap[fm], sh, na.rm = TRUE)
    if (!identical(val_str(x$instrument_type), "grant")) next
    a <- val_bv(vc, path_join("funding", f, "amount_eur"))
    if (length(a) != 1L || !is.finite(a) || anyNA(cost[fm]) || sum(cost[fm]) <= 0) next
    sub[fm] <- sub[fm] + a * cost[fm] / sum(cost[fm])
  }
  for (k in names(spec$financing %||% list())) {
    comp <- spec$financing[[k]]
    mid <- if (is_map(comp)) val_str(comp$measure_id) else NULL
    if (is.null(mid) || !(mid %in% ms) || !is_map(comp$repayment_grant)) next
    path <- path_join("financing", k)
    rg <- val_bv(vc, path_join(path, "repayment_grant", "amount_eur"))
    if (is.null(rg)) {
      share <- val_bv(vc, path_join(path, "repayment_grant", "share"))
      amt <- val_bv(vc, path_join(path, "amount_eur"))
      rg <- if (length(share) == 1L && length(amt) == 1L) share * amt else NULL
    }
    if (length(rg) == 1L && is.finite(rg)) sub[[mid]] <- sub[[mid]] + rg
  }
  for (m in ms) {
    if (is.na(cost[[m]]) || sub[[m]] <= 0) next
    share <- if (is.na(cap[[m]])) 1 else cap[[m]]
    if (sub[[m]] > share * cost[[m]] + 1e-6) {
      val_add(vc, "warning", "validation.funding.cumulation_total_share",
              path_join("measures", m), value = sub[[m]], share = share, cost = cost[[m]])
    }
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Haushalt und Restwert (Teil B 3.10.1; Teil A 6.1, 6.4, 6.6)
# ---------------------------------------------------------------------------------------------

#' Haushalt (Teil B 3.10.1)
#' @noRd
val_plaus_household <- function(vc) {
  spec <- vc$spec
  hh <- spec$household %||% list()
  persp <- val_perspective(vc)
  if (identical(persp, "selbstnutzer")) {
    if (is.null(hh$net_income_month_eur)) {
      val_add(vc, "warning", "validation.household.income_missing",
              "household.net_income_month_eur")
    }
    if ((val_is_new_build(vc) || startsWith(val_project_type(vc), "erwerb_")) &&
          is.null(hh$current_rent_month_eur)) {
      val_add(vc, "info", "validation.household.current_rent_missing",
              "household.current_rent_month_eur")
    }
  }
  types <- vapply(spec$funding %||% list(), function(f) val_str(f$instrument_type) %||% "", "")
  if ("tax_credit" %in% types && is.null(hh$expected_income_tax_eur_pa)) {
    val_add(vc, "warning", "validation.household.income_tax_missing",
            "household.expected_income_tax_eur_pa")
  }
  if (!is.null(hh$savings_eur)) {
    eq <- any(vapply(spec$financing %||% list(), function(c) {
      identical(c$type, "equity") && identical(c$origin %||% "scenario", "scenario")
    }, logical(1)))
    if (eq) val_add(vc, "warning", "validation.household.savings_double", "household.savings_eur")
  }
  invisible(NULL)
}

#' Restwert (Teil A 6.1, 6.4, 6.6); nur mit building (6.1: Szenarien ohne building gültig)
#' @noRd
val_plaus_residual <- function(vc) {
  spec <- vc$spec
  rv <- spec$residual_value
  b <- spec$building
  if (!is_map(rv) || !is_map(b) || length(b) == 0L) return(invisible(NULL))
  method <- val_str(rv$method) %||% "zero"
  sub <- rv[[method]] %||% list()
  if (method %in% c("income_value", "asset_value")) {
    lvp <- path_join("residual_value", method, "land_value_eur")
    lv <- sub[["land_value_eur"]]
    target_missing <- (node_is(lv) && identical(lv$kind, "ref") &&
                         is.null(path_get(spec, lv$path))) ||
      (is_map(lv) && utl_is_string(lv$ref) && is.null(path_get(spec, lv$ref)))
    if (is.null(lv) || target_missing) {
      val_add(vc, "error", "validation.residual.land_value_missing", lvp)
    }
  }
  rented <- any(vapply(spec$unit_groups %||% list(), function(g) {
    !isTRUE(val_flag(g$owner_occupied))
  }, logical(1))) || any(vapply(spec$components %||% list(), function(c) {
    identical(val_str(c$category), "rent")
  }, logical(1)))
  if (identical(method, "income_value")) {
    rlm <- val_str(sub$remaining_life_method) %||% "anlage2"
    if (rlm %in% c("anlage2", "linear") && is.null(b$construction_year) &&
          is.null(b$first_occupancy_year) && is.null(b$fictitious_construction_year) &&
          !val_is_new_build(vc)) {
      val_add(vc, "error", "validation.residual.construction_year_missing",
              "building.construction_year")
    }
    if (identical(rlm, "manual") && is.null(sub$remaining_life_years)) {
      val_add(vc, "error", "validation.residual.manual_years_missing",
              "residual_value.income_value.remaining_life_years")
    }
    if (isTRUE(val_flag(sub$bog_component_residual))) {
      val_add(vc, "warning", "validation.residual.double_count",
              "residual_value.income_value.bog_component_residual")
    }
    pts <- b$modernization_points_before
    has_pts <- is_map(pts) && any(vapply(pts, function(v) (val_num(v) %||% 0) > 0, logical(1)))
    if (!is.null(b$fictitious_construction_year) && has_pts) {
      val_add(vc, "warning", "validation.residual.fictitious_points",
              "building.fictitious_construction_year")
    }
  }
  if (method %in% c("income_value", "multiplier", "exit_yield") && !rented) {
    val_add(vc, "warning", "validation.residual.no_rent", "residual_value.method", value = method)
  }
  if (identical(method, "asset_value") && rented) {
    val_add(vc, "warning", "validation.residual.asset_value_rented", "residual_value.method")
  }
  if (identical(method, "component")) {
    ie <- sub$include_existing
    ie <- if (utl_is_flag(ie)) tolower(as.character(ie)) else val_str(ie)
    if (identical(ie, "false") && !is.null(b$existing_value_eur)) {
      val_add(vc, "warning", "validation.residual.existing_excluded",
              "residual_value.component.include_existing")
    }
  }
  basis <- val_str(spec$analysis$rv_path_basis) %||% "auto"
  if (identical(method, "component") || identical(basis, "measures")) {
    for (m in names(spec$measures %||% list())) {
      x <- spec$measures[[m]]
      if ((val_str(x$measure_type) %||% "") %in% val_purchase_types()) next
      if (is.null(x$useful_life_years)) {
        val_add(vc, "info", "validation.residual.no_useful_life",
                path_join("measures", m, "useful_life_years"))
      }
    }
  }
  invisible(NULL)
}
