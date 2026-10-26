# Zahlungstyp capex: Investitionskosten einer Massnahme (WS-E, Spec 01 Teil A 4.6, Bausteine 0.3).
# Die Datei enthaelt ausserdem die von mehreren Investitionstypen (capex, replacement, land,
# acquisition_cost, maintenance, residual_value) gemeinsam genutzten Hilfsfunktionen (Teil A 0.3:
# Zahlungsplan ZP/ZPP, Index zum Termin, Aktivierung, Befunde der validate()-Funktionen).
# Alle Rechnungen sind ueber die Laeufe vektorisiert (n-Vektoren bzw. n x (T+1)); Schleifen laufen
# nur ueber Zahlungsereignisse, Zeilen und Komponenten (Spec 00 2.8).

# ---------------------------------------------------------------------------------------------
# Gemeinsame Hilfsfunktionen der Investitionstypen
# ---------------------------------------------------------------------------------------------

#' Zahlenwert(e) eines konstanten Knotens (für validate())
#'
#' Liefert die Zahl einer Konstante bzw. die Zahlen einer numerischen Periodenreihe; für alle
#' anderen Wertformen `NULL` (Bezüge, Ausdrücke und Pfade prüft die Validierung von WS-B bzw.
#' die Laufzeit).
#' @param x Knoten oder Zahl.
#' @return double oder `NULL`.
#' @noRd
typ_const <- function(x) {
  if (is.numeric(x) && !is.list(x)) return(as.double(x))
  if (is.list(x) && identical(x[["kind"]], "const") && is.numeric(x[["value"]])) {
    return(as.double(x[["value"]]))
  }
  if (is.list(x) && identical(x[["kind"]], "series_t") && is.numeric(x[["values"]])) {
    return(as.double(x[["values"]]))
  }
  NULL
}

#' Bezugsziele aller Knoten einer Struktur (ref-Pfade und Pfadsymbole von Ausdrücken)
#' @param x Knoten bzw. Liste von Knoten.
#' @return Zeichenvektor.
#' @noRd
typ_ref_targets <- function(x) {
  if (!is.list(x)) return(character(0))
  if (node_is(x)) {
    own <- switch(x[["kind"]],
      ref = x[["path"]],
      expr = expr_symbols(x[["ast"]] %||% expr_parse(x[["text"]])),
      character(0)
    )
    subs <- x[intersect(names(x), c("values", "amounts", "start", "growth", "value"))]
    return(c(own, unlist(lapply(subs, typ_ref_targets), use.names = FALSE)))
  }
  unlist(lapply(x, typ_ref_targets), use.names = FALSE) %||% character(0)
}

#' Ist ein Parameterknoten fehlend oder die Konstante 0 (Strukturentscheidung, deterministisch)?
#' @noRd
typ_is_zero_node <- function(x) {
  if (is.null(x)) return(TRUE)
  v <- typ_const(x)
  !is.null(v) && length(v) == 1L && isTRUE(v == 0)
}

#' Division mit Ergebnis `a` statt NaN/Inf bei `b == 0` (vektorisiert, ohne Verzweigung)
#' @noRd
typ_safe_div <- function(a, b) a / (b + (b == 0))

#' Preisbasis b* = (price_base_year + 1)-01-01 (R-35); ohne Angabe `project.price_base_year`
#' @param ctx Laufkontext.
#' @param spec Komponente.
#' @param name Name des Parameters mit dem Preisstand (Art `integer`).
#' @return `Date`.
#' @noRd
typ_price_base_date <- function(ctx, spec = NULL, name = "price_base_year") {
  y <- if (is.null(spec)) NULL else ctx$setting(spec, name)
  if (is.null(y)) {
    y <- ctx$project$price_base_year
    if (is.list(y)) y <- typ_const(y)
  }
  if (is.null(y) || !is.numeric(y) || length(y) != 1L || is.na(y)) {
    y <- utl_year(ctx$grid$valuation_date) - 1L
  }
  as.Date(sprintf("%04d-01-01", as.integer(round(y)) + 1L))
}

#' Basisfallwert eines Anteils als Skalar (Zeilenmetadaten wie `vat_rate`, Spec 00 7.10)
#' @noRd
typ_base_scalar <- function(ctx, spec, name, default) {
  v <- ctx$param_base(spec, name)
  if (is.null(v)) return(default)
  as.double(v[1L])
}

#' Einzelne Elemente eines Zahlungsplans je Lauf auflösen (Termine, Beträge als n-Vektoren)
#'
#' Die Elemente eines `schedule`-Knotens dürfen Zahlen oder skalare Knoten sein (4.5 Regel 4).
#' Jedes Element wird über `ctx$param()` bzw. `ctx$param_base()` als n-Vektor aufgelöst; dazu wird
#' es in einer lokalen Kopie der Komponente unter einem eindeutigen Hilfsnamen abgelegt
#' (Sequenzelemente sind keine eigenen Overlay-Ziele, 4.4 Nr. 3; Bezüge auf Blätter wirken über
#' deren Pfad).
#' @param ctx Laufkontext.
#' @param spec Komponente.
#' @param name Parametername des Zahlungsplans.
#' @param type Typname (Label-Schlüssel der Fehlermeldung `types.flow.<typ>.msg.not_schedule`).
#' @param base Basisfallwerte (`ctx$param_base()`).
#' @return `NULL` oder `list(dates = Date, amounts = list(<n-Vektor>), unit = chr)`, nach Termin
#'   sortiert.
#' @noRd
typ_schedule_parts <- function(ctx, spec, name, type, base = FALSE) {
  node <- spec[[name]]
  if (is.null(node)) return(NULL)
  if (!node_is(node)) node <- node_normalize(node, vofi_param("schedule"), name)
  if (!identical(node[["kind"]], "schedule")) {
    ctx$abort(paste0("types.flow.", type, ".msg.not_schedule"), param = name,
              id = spec[["id"]] %||% "?")
  }
  dates <- node$dates
  amounts <- node$amounts
  els <- vector("list", length(dates))
  for (i in seq_along(dates)) {
    el <- if (is.numeric(amounts) && !is.list(amounts)) amounts[i] else amounts[[i]]
    tmp <- spec
    hn <- paste0(name, "_element_", i)
    tmp[[hn]] <- el
    v <- if (base) ctx$param_base(tmp, hn) else ctx$param(tmp, hn)
    els[[i]] <- as.double(v)
  }
  ord <- order(as.numeric(dates))
  list(dates = dates[ord], amounts = els[ord], unit = node$unit %||% "eur")
}

#' Wert einer n x (T+1)-Matrix je Lauf in der Periode p (NA jenseits des Horizonts)
#' @param x n x (T+1).
#' @param p integer n-Vektor (Periode, NA erlaubt).
#' @return double n-Vektor.
#' @noRd
capex_index_at <- function(x, p) {
  out <- rep(NA_real_, length(p))
  ok <- !is.na(p)
  if (any(ok)) out[ok] <- x[cbind(which(ok), p[ok] + 1L)]
  out
}

#' Betrag je Lauf in die Periode p buchen (Läufe mit p = NA entfallen)
#' @param x n x (T+1).
#' @param p integer n-Vektor.
#' @param amount double n-Vektor.
#' @return n x (T+1).
#' @noRd
typ_book <- function(x, p, amount) {
  ok <- !is.na(p)
  if (any(ok)) {
    idx <- cbind(which(ok), p[ok] + 1L)
    x[idx] <- x[idx] + amount[ok]
  }
  x
}

#' Hinweis "Zahlungen jenseits des Horizonts entfallen" (einmal je Komponente, mit Laufanteil)
#' @param lost logischer n-Vektor (Lauf mit entfallener Zahlung).
#' @noRd
typ_inform_after_horizon <- function(ctx, spec, type, lost) {
  if (any(lost)) {
    ctx$inform(paste0("types.flow.", type, ".msg.after_horizon"), id = spec[["id"]] %||% "?",
               share = mean(lost))
  }
  invisible(NULL)
}

#' Laufspezifische Verschiebung als gerundete ganze Monate (floor(x + 0.5), Spec 00 3.9)
#' @noRd
typ_round_months <- function(x) floor(as.double(x) + 0.5)

#' Verschiebungsparameter (Art number, Default 0) als n-Vektor
#' @noRd
typ_shift_param <- function(ctx, spec, name) {
  v <- ctx$param(spec, name)
  if (is.null(v)) rep(0, ctx$n) else as.double(v)
}

#' Abhängigkeiten einer Komponente aus dem Metafeld `after`
#' @noRd
typ_after_ids <- function(spec) as.character(unlist(spec[["after"]]))

#' Steuerkategorie einer Investitionszeile nach der Klassifikation (Spec 01 Teil A 4.6.3, 4.10.2)
#' @noRd
typ_capex_tax <- function(classification) {
  if (identical(classification, "erhaltung")) "capex_expensable" else "capex_depreciable"
}

#' Sammler für Befunde einer validate()-Funktion (Spec 00 5.2; Codes = Label-Schlüssel)
#'
#' Die Befunde verwenden die Schlüssel `types.flow.<typ>.errors.<code>` der Label-Datei des
#' Typs; Platzhalter `{id}` (Komponenten-id) wird immer gesetzt.
#' @param spec Komponente.
#' @param scenario `vofi_spec` (bzw. Liste mit `financing`).
#' @param type Typname.
#' @return Umgebung mit `add(severity, code, field, ...)` und `out` (Liste der Befunde).
#' @noRd
typ_validator <- function(spec, scenario, type) {
  acc <- new.env(parent = emptyenv())
  acc$out <- list()
  id <- spec[["id"]] %||% "?"
  coll <- if (id %in% names(scenario[["financing"]])) "financing" else "components"
  acc$add <- function(severity, code, field = NULL, ...) {
    acc$out[[length(acc$out) + 1L]] <- list(
      severity = severity, code = paste0("types.flow.", type, ".errors.", code),
      path = path_join(coll, id, field), args = c(list(id = id), list(...))
    )
    invisible(NULL)
  }
  acc
}

#' Datum eines timing-Parameters in validate() (normalisierter Wert; Token completion = NULL)
#' @noRd
typ_spec_date <- function(x) {
  if (inherits(x, "Date") && length(x) == 1L && !is.na(x)) return(x)
  NULL
}

#' Stichtag eines Szenarios bzw. einer aufgelösten Variante (für validate())
#' @noRd
typ_valuation_date <- function(scenario) {
  vd <- scenario[["project"]][["valuation_date"]]
  if (inherits(vd, "Date") && length(vd) == 1L && !is.na(vd)) vd else NULL
}

#' Zahlungsprofil F(x) der Ausführungsdauer (Spec 01 Teil A 0.3, ZPP)
#' @noRd
capex_profile <- function(profile, x) {
  switch(profile,
    s_curve = 3 * x^2 - 2 * x^3,
    front = 1 - (1 - x)^2,
    back = x^2,
    x
  )
}

#' Kostengruppen-Codes von `cost_kg` (DIN 276, KG 100 und 800 sind unzulässig)
#' @noRd
capex_kg_codes <- function() paste0("kg", c(200L, 300L, 400L, 500L, 600L, 700L))

# ---------------------------------------------------------------------------------------------
# capex: Kosten, Zahlungsplan, Buchung, Hilfsgrößen
# ---------------------------------------------------------------------------------------------

#' Zahlungsplan der Maßnahme: Termine d_j und Gewichte w_j bzw. Beträge (Spec 01 Teil A 4.6.2 (3))
#'
#' `date`/`year` ohne Ausführungsdauer: ein Termin mit Gewicht 1; mit Ausführungsdauer D: D
#' Monatsereignisse nach ZPP (0.3); Zahlungsplan `unit: share`: Termine mit Anteilen;
#' `unit: eur`: Termine mit Beträgen (Grundkosten je Termin).
#' @return `list(dates, weights = list(<n-Vektor>), unit = "share" | "eur")`.
#' @noRd
capex_payment_plan <- function(ctx, spec) {
  n <- ctx$n
  parts <- typ_schedule_parts(ctx, spec, "payment_schedule", "capex")
  if (!is.null(parts)) {
    return(list(dates = parts$dates, weights = parts$amounts, unit = parts$unit))
  }
  d <- ctx$setting(spec, "date")
  if (is.null(d)) ctx$abort("types.flow.capex.msg.no_timing", id = spec[["id"]] %||% "?")
  d <- utl_as_date(d, "date")
  dur <- as.integer(ctx$setting(spec, "duration_months") %||% 0L)
  if (dur <= 0L) return(list(dates = d, weights = list(rep(1, n)), unit = "share"))
  prof <- ctx$setting(spec, "payment_profile") %||% "linear"
  k <- seq_len(dur)
  dates <- grid_add_months(rep(d, dur), -(dur - k))
  w <- capex_profile(prof, k / dur) - capex_profile(prof, (k - 1L) / dur)
  list(dates = dates, weights = lapply(w, function(x) rep(x, n)), unit = "share")
}

#' Verschiebung der Zahlungstermine durch den Bauzeitverzug (Spec 01 Teil A 4.6.2 (4))
#' @param dates sortierte Termine (Länge J).
#' @param cd n-Vektor Bauzeitverzug in Monaten.
#' @param mode `"none"`, `"last"` oder `"stretch"`.
#' @return Liste von J n-Vektoren c_j.
#' @noRd
capex_delay_offsets <- function(dates, cd, mode) {
  big_j <- length(dates)
  if (identical(mode, "none")) return(rep(list(0 * cd), big_j))
  if (identical(mode, "last")) return(lapply(seq_len(big_j), function(j) cd * (j == big_j)))
  span <- grid_months_between(dates[1L], dates[big_j])
  f <- if (big_j == 1L || span == 0L) rep(1, big_j) else
    grid_months_between(rep(dates[1L], big_j), dates) / span
  lapply(seq_len(big_j), function(j) cd * f[j])
}

#' Grundkosten der Maßnahme je Zeile (Spec 01 Teil A 4.6.2 (1))
#'
#' @return `list(mode, rows = list(<zeile> = n-Vektor), alloc = list(<kg> = n-Vektor),
#'   k0 = n-Vektor)`; `rows` sind die Beträge im Preisstand b* vor Bruttofaktor, Kostenfaktor und
#'   Aktivierung; `alloc` die Anteile des Risikozuschlags je Kostengruppe (Summe 1 über die Basis).
#' @noRd
capex_cost_parts <- function(ctx, spec, plan) {
  n <- ctx$n
  zero <- rep(0, n)
  cs <- ctx$param(spec, "contingency_share") %||% zero
  has_cont <- !typ_is_zero_node(spec[["contingency_share"]])
  kg <- spec[["cost_kg"]]
  if (is.list(kg) && length(kg) > 0L) {
    codes <- capex_kg_codes()
    s <- stats::setNames(lapply(codes, function(k) {
      ctx$param(spec, paste0("cost_kg.", k)) %||% zero
    }), codes)
    share700 <- ctx$param(spec, "kg700_share") %||% zero
    b700 <- if (identical(ctx$setting(spec, "kg700_basis") %||% "kg300_400", "kg200_600")) {
      s$kg200 + s$kg300 + s$kg400 + s$kg500 + s$kg600
    } else {
      s$kg300 + s$kg400
    }
    k700 <- s$kg700 + share700 * b700
    basis700 <- !identical(ctx$setting(spec, "contingency_basis") %||% "kg200_700", "kg200_600")
    bc <- s$kg200 + s$kg300 + s$kg400 + s$kg500 + s$kg600 + if (basis700) k700 else 0
    kc <- cs * bc
    s$kg700 <- k700
    keys <- intersect(codes, names(kg))
    if (!typ_is_zero_node(spec[["kg700_share"]])) keys <- union(keys, "kg700")
    keys <- codes[codes %in% keys]
    rows <- stats::setNames(lapply(keys, function(k) s[[k]]), paste0("cost_", keys))
    in_basis <- c(kg200 = TRUE, kg300 = TRUE, kg400 = TRUE, kg500 = TRUE, kg600 = TRUE,
                  kg700 = basis700)
    alloc <- stats::setNames(lapply(keys, function(k) {
      if (in_basis[[k]]) typ_safe_div(s[[k]], bc) else zero
    }), keys)
    k0 <- s$kg200 + s$kg300 + s$kg400 + s$kg500 + s$kg600 + k700 + kc
    if (has_cont) rows$contingency <- kc
    return(list(mode = "kg", rows = rows, alloc = alloc, k0 = k0))
  }
  if (identical(plan$unit, "eur") && !is.null(spec[["payment_schedule"]])) {
    k0 <- Reduce(`+`, plan$weights, zero)
    return(list(mode = "eur", rows = list(cost = k0), alloc = list(), k0 = k0))
  }
  cost <- ctx$param(spec, "cost_eur")
  if (is.null(cost)) {
    ctx$abort("types.flow.capex.msg.no_cost", id = spec[["id"]] %||% "?")
  }
  rows <- list(cost = cost)
  if (has_cont) rows$contingency <- cs * cost
  list(mode = "eur_total", rows = rows, alloc = list(), k0 = cost + cs * cost)
}

#' Wirkungsbeginn je Lauf (Spec 01 Teil A 4.6.2 (6), 4.4 `effects.start`)
#' @param cd Fertigstellung (Datum).
#' @param s_c n-Vektor Verschiebung der Fertigstellung in ganzen Monaten.
#' @param effect_start `"completion"` oder `"next_year"`.
#' @return n x (T+1) Monatsanteile ab Wirkungsbeginn.
#' @noRd
capex_in_operation <- function(ctx, cd, s_c, effect_start) {
  if (!identical(effect_start, "next_year")) return(ctx$shift_overlap(cd, s_c))
  shifted <- grid_add_months(rep(cd, length(s_c)), s_c)
  jan <- as.Date(sprintf("%04d-01-01", utl_year(cd)))
  ctx$shift_overlap(jan, 12 * (utl_year(shifted) + 1L - utl_year(cd)))
}

#' Zahlungskomponente capex bauen (Spec 01 Teil A 4.6.2)
#' @noRd
capex_build <- function(spec, ctx) {
  n <- ctx$n
  zero <- rep(0, n)
  plan <- capex_payment_plan(ctx, spec)
  parts <- capex_cost_parts(ctx, spec, plan)
  vat <- typ_base_scalar(ctx, spec, "vat_rate", 0.19)
  gross <- if (isTRUE(ctx$setting(spec, "cost_is_net"))) 1 + vat else 1
  cost_factor <- ctx$param(spec, "cost_factor") %||% rep(1, n)
  active <- ctx$param(spec, "active") %||% rep(1, n)
  gfa <- gross * cost_factor * active
  k_total <- parts$k0 * gfa
  bstar <- typ_price_base_date(ctx, spec)
  idx <- ctx$index(ctx$param(spec, "price_index", "path") %||% zero, base_date = bstar)
  dm <- typ_shift_param(ctx, spec, "delay_months")
  cdm <- typ_shift_param(ctx, spec, "construction_delay_months")
  mode <- ctx$setting(spec, "construction_delay_mode") %||% "none"
  offsets <- capex_delay_offsets(plan$dates, cdm, mode)
  x <- lapply(parts$rows, function(r) ctx$zeros())
  lost <- rep(FALSE, n)
  for (j in seq_along(plan$dates)) {
    p <- ctx$shift_period(plan$dates[j], dm + offsets[[j]])
    i_j <- capex_index_at(idx, p)
    w <- plan$weights[[j]]
    lost <- lost | (is.na(p) & abs(w) > 0 & abs(gfa) > 0)
    for (r in names(parts$rows)) {
      amount <- if (identical(parts$mode, "eur")) w else parts$rows[[r]] * w
      x[[r]] <- typ_book(x[[r]], p, -amount * gfa * i_j)
    }
  }
  typ_inform_after_horizon(ctx, spec, "capex", lost)
  cd <- ctx$setting(spec, "completion_date")
  cd <- if (is.null(cd)) plan$dates[length(plan$dates)] else utl_as_date(cd, "completion_date")
  s_c <- typ_round_months(dm + cdm * !identical(mode, "none"))
  in_op <- capex_in_operation(ctx, cd, s_c, ctx$setting(spec, "effect_start") %||% "completion")
  in_op <- in_op * ctx$by_sim(active)
  cls <- ctx$setting(spec, "classification") %||% "auto"
  tax <- typ_capex_tax(cls)
  spread <- ctx$setting(spec, "spread_years")
  extra <- if (identical(cls, "erhaltung") && !is.null(spread)) {
    list(spread_years = as.integer(spread))
  } else {
    list()
  }
  rows <- lapply(names(x), function(r) {
    tc <- if (identical(r, "cost_kg200")) ctx$setting(spec, "tax_category_kg200") %||% tax else
      tax
    do.call(vofi_row, c(list(r, x[[r]], section = "project", category = "capex",
                             tax_category = tc, asset_id = spec[["asset_id"]],
                             measure_id = spec[["measure_id"]], vat_rate = vat), extra))
  })
  cost_total <- -Reduce(`+`, x, ctx$zeros())
  aux <- list(cost_total = cost_total, cost_base = ctx$by_sim(k_total))
  if (identical(parts$mode, "kg")) {
    cont <- x$contingency %||% ctx$zeros()
    for (k in names(parts$alloc)) {
      aux[[paste0("cost_", k)]] <- -(x[[paste0("cost_", k)]] +
                                       cont * ctx$by_sim(parts$alloc[[k]]))
    }
  }
  oh_cost <- ctx$param(spec, "ohnehin_cost_eur")
  oh_share <- ctx$param(spec, "ohnehin_share")
  oh <- if (!is.null(oh_cost)) oh_cost * gross * active else if (!is.null(oh_share)) {
    oh_share * k_total
  } else {
    zero
  }
  oh <- pmin(pmax(oh, 0), pmax(k_total, 0))
  aux$ohnehin_base <- ctx$by_sim(oh)
  aux$modernization_base <- ctx$by_sim(k_total - oh)
  aux$in_operation <- in_op
  aux$completion_shift <- ctx$by_sim(s_c)
  aux$active <- ctx$by_sim(active)
  vofi_flows(rows, aux = aux,
             meta = list(completion_date = cd, payment_dates = plan$dates,
                         measure_id = spec[["measure_id"]], cost_mode = parts$mode,
                         kg = names(parts$alloc)))
}

#' Prüfungen der Komponente capex (Spec 01 Teil A 4.6.5)
#' @noRd
capex_validate <- function(spec, scenario) {
  v <- typ_validator(spec, scenario, "capex")
  has_date <- !is.null(spec[["date"]])
  sched <- spec[["payment_schedule"]]
  has_sched <- !is.null(sched)
  if (has_date + has_sched != 1L) v$add("error", "timing")
  unit <- if (has_sched && is.list(sched)) sched[["unit"]] %||% "eur" else NA_character_
  kg <- spec[["cost_kg"]]
  has_kg <- is.list(kg) && length(kg) > 0L
  n_cost <- (!is.null(spec[["cost_eur"]])) + has_kg + identical(unit, "eur")
  if (n_cost != 1L) v$add("error", "cost_source")
  if (has_kg) {
    bad <- setdiff(names(kg), capex_kg_codes())
    if (length(bad) > 0L) v$add("error", "kg_invalid", "cost_kg", value = utl_collapse(bad))
    s700 <- typ_const(kg[["kg700"]])
    s_share <- typ_const(spec[["kg700_share"]])
    if (!is.null(s700) && !is.null(s_share) && any(s700 > 0) && any(s_share > 0)) {
      v$add("warning", "kg700_double", "kg700_share")
    }
  }
  if (has_sched && is.list(sched) && identical(unit, "share")) {
    w <- vapply(sched[["amounts"]] %||% list(), function(a) typ_const(a)[1L] %||% NA_real_,
                double(1))
    if (length(w) > 0L && !anyNA(w) && abs(sum(w) - 1) > 1e-9) {
      v$add("error", "schedule_sum", "payment_schedule", value = sum(w))
    }
  }
  if (identical(unit, "eur") && !typ_is_zero_node(spec[["contingency_share"]])) {
    v$add("warning", "contingency_ignored", "contingency_share")
  }
  dur <- spec[["duration_months"]] %||% 0L
  if (has_sched && is.numeric(dur) && dur > 0) {
    v$add("error", "duration_schedule", "duration_months")
  }
  vd <- typ_valuation_date(scenario)
  d <- typ_spec_date(spec[["date"]])
  first <- NULL
  if (!is.null(d)) {
    first <- if (is.numeric(dur) && dur > 0) grid_add_months(d, -as.integer(dur)) else d
  } else if (has_sched && is.list(sched) && inherits(sched[["dates"]], "Date")) {
    first <- min(sched[["dates"]])
  }
  if (!is.null(vd) && !is.null(first) && first < vd) {
    v$add("error", "before_valuation", if (has_sched) "payment_schedule" else "date",
          date = first)
  }
  cd <- typ_spec_date(spec[["completion_date"]])
  if (!is.null(cd) && !is.null(first)) {
    pay1 <- if (!is.null(d) && is.numeric(dur) && dur > 0) grid_add_months(d, 1L - dur) else
      first
    if (cd < pay1) v$add("error", "completion_order", "completion_date", date = cd)
  }
  a <- typ_const(spec[["active"]])
  if (!is.null(a) && any(!(a %in% c(0, 1)))) v$add("warning", "active_fraction", "active")
  if (is.null(spec[["asset_id"]]) || is.null(spec[["measure_id"]])) {
    v$add("error", "ids_missing")
  }
  vat <- typ_const(spec[["vat_rate"]])
  if (!is.null(vat) && !all(vat %in% c(0, 0.07, 0.19))) {
    v$add("warning", "vat_unusual", "vat_rate", value = vat[1L])
  }
  for (f in c("delay_months", "construction_delay_months")) {
    x <- typ_const(spec[[f]])
    if (!is.null(x) && any(x < 0)) v$add("error", "shift_negative", f)
  }
  v$out
}

#' @noRd
typedef_capex <- function() {
  p <- vofi_param
  kg_fields <- stats::setNames(lapply(capex_kg_codes(), function(k) {
    p("amount", default = 0, min = 0, unit = "EUR")
  }), capex_kg_codes())
  vofi_type(
    name = "capex", kind = "flow",
    params = list(
      cost_eur = p("amount", min = 0, unit = "EUR"),
      cost_kg = p("map", fields = kg_fields),
      kg700_share = p("share", default = 0),
      contingency_share = p("share", default = 0),
      kg700_basis = p("enum", values = "vocab:kg700_basis", default = "kg300_400"),
      contingency_basis = p("enum", values = "vocab:contingency_basis", default = "kg200_700"),
      cost_factor = p("number", default = 1, min = 0),
      cost_is_net = p("logical", default = FALSE),
      vat_rate = p("share", default = 0.19),
      price_base_year = p("integer"),
      price_index = p("value", default = list(ref = "market.construction_price_index"),
                      unit = "rate_pa"),
      date = p("timing"),
      payment_schedule = p("schedule"),
      duration_months = p("integer", default = 0L),
      payment_profile = p("enum", values = "vocab:payment_profile", default = "linear"),
      completion_date = p("timing"),
      delay_months = p("number", default = 0, min = 0, unit = "months"),
      construction_delay_months = p("number", default = 0, min = 0, unit = "months"),
      construction_delay_mode = p("enum", values = "vocab:construction_delay_mode",
                                  default = "none"),
      effect_start = p("enum", values = "vocab:effect_start", default = "completion"),
      active = p("value", default = 1, min = 0, max = 1),
      classification = p("enum", values = "vocab:classification", default = "auto"),
      tax_category_kg200 = p("enum", values = c("capex_depreciable", "capex_expensable",
                                                "capex_land"),
                             default = "capex_depreciable"),
      spread_years = p("integer"),
      ohnehin_share = p("share"),
      ohnehin_cost_eur = p("amount", min = 0, unit = "EUR")
    ),
    rows = c("cost", paste0("cost_", capex_kg_codes()), "contingency"),
    validate = capex_validate,
    build = capex_build,
    example = list(type = "capex", asset_id = "b1", measure_id = "m1",
                   cost_kg = list(kg300 = 80000, kg400 = 40000), kg700_share = 0.15,
                   contingency_share = 0.05, date = "2027-10-01", duration_months = 6L,
                   payment_profile = "s_curve", price_index = 0.03, delay_months = 2,
                   construction_delay_months = 1, construction_delay_mode = "stretch",
                   ohnehin_share = 0.3, classification = "erhaltung", spread_years = 3L)
  )
}
