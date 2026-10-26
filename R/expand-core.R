# Gemeinsame Hilfsfunktionen der Domaenen-Expander (WS-E2, Spec 00 4.12, 6.4; Spec 01 Teil A 4.5,
# 6.2; Teil B 1.6, 3.5, 3.10.2, 4). Expander laufen nach Schicht 8, den Ableitungsregeln und den
# item_defaults; sie aendern keine Domaenenbloecke, schreiben nur Komponenten,
# Finanzierungsbausteine, Register und Hinweise und setzen fuer numerische Domaenenblaetter
# Bezuege statt Kopien (R-92).
# Die Datei enthaelt die Lesehilfen fuer teilaufgeloeste Domaenenwerte (Konstantenknoten, Daten als
# Zeichenkette, Jahre), die Knotenbausteine, die id-Pruefung, den Aktivierungsfaktor (Teil B 0.8)
# und die deterministische Vorauswertung der Foerderinstrumente (Berechtigung, Bausteine), die die
# Expander unit_groups, energy und funding gemeinsam nutzen.

# ---------------------------------------------------------------------------------------------
# Lesehilfen für Domänenwerte
# ---------------------------------------------------------------------------------------------

#' Zahl(en) aus einem Domänenwert (Zahl, Konstante, Periodenreihe, Zeichenkette) oder `NULL`
#' @param x Wert bzw. Knoten.
#' @return double oder `NULL` (Bezüge, Ausdrücke und Pfade ergeben `NULL`).
#' @noRd
exp_num <- function(x) {
  if (is.null(x) || length(x) == 0L) return(NULL)
  if (is.list(x) && !is.null(x[["kind"]])) {
    if (identical(x[["kind"]], "const")) return(exp_num(x[["value"]]))
    if (identical(x[["kind"]], "series_t")) {
      v <- vapply(x[["values"]], function(e) exp_num(e)[1L] %||% NA_real_, double(1))
      return(if (anyNA(v)) NULL else v)
    }
    return(NULL)
  }
  if (is.list(x)) x <- unlist(x, use.names = FALSE)
  if (is.logical(x)) return(NULL)
  v <- suppressWarnings(as.double(x))
  if (length(v) == 0L || anyNA(v)) NULL else v
}

#' Ganzzahl aus einem Domänenwert oder `NULL`
#' @noRd
exp_int <- function(x) {
  v <- exp_num(x)
  if (is.null(v)) NULL else as.integer(round(v[1L]))
}

#' Wahrheitswert aus einem Domänenwert (`TRUE`, `"true"`, 1) oder `NULL`
#' @noRd
exp_lgl <- function(x) {
  if (is.null(x) || length(x) == 0L) return(NULL)
  if (is.list(x) && identical(x[["kind"]], "const")) x <- x[["value"]]
  if (is.list(x)) x <- unlist(x, use.names = FALSE)
  if (is.logical(x)) return(if (is.na(x[1L])) NULL else x[1L])
  if (is.numeric(x)) return(isTRUE(x[1L] != 0))
  v <- tolower(as.character(x[1L]))
  if (v %in% c("true", "yes", "ja", "1")) return(TRUE)
  if (v %in% c("false", "no", "nein", "0")) return(FALSE)
  NULL
}

#' Zeichenvektor (ids, Codes) aus einem Domänenwert
#' @noRd
exp_chr <- function(x) {
  if (is.null(x) || length(x) == 0L) return(character(0))
  if (is.list(x) && identical(x[["kind"]], "const")) x <- x[["value"]]
  out <- as.character(unlist(x, use.names = FALSE))
  out[!is.na(out)]
}

#' Einzelner Code (Zeichenkette) oder `NULL`; Aliase eines Enums werden kanonisiert
#' @noRd
exp_code <- function(x, enum = NULL) rp_code(x, enum)

#' Datum aus einem Domänenwert (Date, ISO-Zeichenkette, Jahr, `{date|year}`, Token `completion`)
#' @param x Wert.
#' @param grid `vofi_grid` (für den Token `completion`) oder `NULL`.
#' @return `Date` oder `NULL`.
#' @noRd
exp_date <- function(x, grid = NULL) {
  if (is.null(x) || length(x) == 0L) return(NULL)
  if (identical(x, "completion")) return(grid$completion_date)
  if (identical(x, "valuation_date")) return(grid$valuation_date)
  if (identical(x, "end_date")) return(grid$end_date)
  d <- rp_as_date(x, grid)
  if (is.null(d) || is.na(d)) NULL else d
}

#' Existiert ein Domänenpfad (Wert ungleich `NULL`)?
#' @noRd
exp_has <- function(x, path) !is.null(path_get(x, path))

#' Ist ein Domänenblatt auflösbar (vorhanden; ein Bezug zeigt auf ein vorhandenes Blatt)?
#' @noRd
exp_resolvable <- function(x, path, depth = 0L) {
  v <- path_get(x, path)
  if (is.null(v)) return(FALSE)
  if (is.list(v) && identical(v[["kind"]], "ref") && depth < 10L) {
    return(exp_resolvable(x, v[["path"]], depth + 1L))
  }
  TRUE
}

#' Letztes Ziel einer Bezugskette (der fehlende Pfad bei nicht auflösbaren Bezügen)
#' @noRd
exp_ref_end <- function(x, path, depth = 0L) {
  v <- path_get(x, path)
  if (is.list(v) && identical(v[["kind"]], "ref") && depth < 10L) {
    return(exp_ref_end(x, v[["path"]], depth + 1L))
  }
  path
}

#' Enthält `building` Gebäudedaten (nicht nur Werte wie `existing_value_eur`)?
#'
#' Teil A 3.1: Ohne Gebäudebezug laufen Instandhaltung und Restwert nicht. Ein Block, der nur
#' den Bestandswert bzw. Boden- und Marktwerte trägt (Sacheinlage), gilt als ohne Gebäudebezug.
#' @noRd
exp_building_data <- function(x) {
  b <- x$building
  if (!is.list(b) || length(b) == 0L) return(FALSE)
  any(c("living_area_m2", "n_units", "construction_year", "building_type",
        "net_floor_area_m2") %in% names(b))
}

#' Bezugsknoten auf einen vorhandenen Domänenpfad, sonst `NULL`
#' @noRd
exp_ref <- function(x, path) if (exp_has(x, path)) node_ref(path) else NULL

#' Ausdrucksknoten aus einem Text
#' @noRd
exp_expr <- function(text) node_expr(text)

#' Zahlenwert als Text für Ausdrücke (ohne wissenschaftliche Notation, volle Genauigkeit)
#' @noRd
exp_fmt <- function(v) {
  v <- as.double(v)
  out <- vapply(v, function(z) {
    if (is.infinite(z)) return(if (z > 0) "1e300" else "-1e300")
    s <- sprintf("%.15g", z)
    if (grepl("^-", s)) paste0("(", s, ")") else s
  }, character(1))
  out
}

#' Summe von Ausdrucksteilen als Knoten (ein Bezug bleibt Bezug, leere Summe = Konstante 0)
#' @param parts Zeichenvektor von Teilausdrücken (Pfade oder Ausdrücke).
#' @noRd
exp_sum_node <- function(parts) {
  parts <- parts[nzchar(parts)]
  if (length(parts) == 0L) return(node_const(0))
  if (length(parts) == 1L && exp_is_path(parts)) return(node_ref(parts))
  node_expr(paste(parts, collapse = " + "))
}

#' Ist ein Text ein reiner Domänenpfad (Symbol mit Punkt)?
#' @noRd
exp_is_path <- function(text) {
  utl_is_string(text) && grepl("^[A-Za-z_][A-Za-z0-9_]*([.][A-Za-z0-9_]+)+$", text)
}

#' Basisfallwert eines Domänenpfads (Skalar) oder `NULL`
#'
#' Konstanten direkt, sonst über `bctx$value_base()` (Bezüge, Ausdrücke, Mengenbezüge); nicht
#' auflösbare Werte ergeben `NULL`.
#' @noRd
exp_base <- function(bctx, x, path) {
  raw <- path_get(x, path)
  if (is.null(raw)) return(NULL)
  v <- exp_num(raw)
  if (!is.null(v)) return(v[1L])
  out <- tryCatch(suppressWarnings(suppressMessages(bctx$value_base(path))),
                  error = function(e) NULL)
  if (is.numeric(out) && length(out) >= 1L && !is.na(out[1L])) as.double(out[1L]) else NULL
}

#' Basisfallwert eines Pfads einer (ergänzten) Spezifikation über den Auflöser (Skalar oder `NULL`)
#'
#' Für Knoten, die der Expander selbst erzeugt hat (z. B. Ausdrücke in neuen Komponenten), die
#' `bctx$value_base()` auf der ursprünglichen Spezifikation nicht kennt.
#' @noRd
exp_eval_base <- function(x, grid, path) {
  raw <- path_get(x, path)
  if (is.null(raw)) return(NULL)
  v <- exp_num(raw)
  if (!is.null(v)) return(v[1L])
  if (is.null(grid)) return(NULL)
  out <- tryCatch(suppressWarnings(suppressMessages(
    res_value(res_context(x, grid, 1L), path, "scalar", base = TRUE)
  )), error = function(e) NULL)
  if (is.numeric(out) && length(out) >= 1L && !is.na(out[1L])) as.double(out[1L]) else NULL
}

#' Sortierung mit `method = "radix"` (Spec 00 2.8)
#' @noRd
exp_sort <- function(x) sort(as.character(x), method = "radix")

# ---------------------------------------------------------------------------------------------
# ids und Meldungen
# ---------------------------------------------------------------------------------------------

#' Erzeugte id prüfen (≤ 40 Zeichen, id-Muster; Spec 00 4.4 Nr. 2, R-90)
#' @param bctx Build-Kontext.
#' @param id erzeugte id.
#' @param user_id Nutzer-id, aus der die id entsteht.
#' @param user_max zulässige Höchstlänge der Nutzer-id.
#' @param expander Name des Expanders (Meldungsschlüssel `expand.<expander>.id_too_long`).
#' @return `id` (unsichtbar).
#' @noRd
exp_check_id <- function(bctx, id, user_id, user_max, expander) {
  if (nchar(id) > 40L || nchar(user_id) > user_max || !utl_is_id(id, max_len = 40L)) {
    bctx$abort(paste0("expand.", expander, ".id_too_long"), id = id, user_id = user_id,
               max = user_max)
  }
  invisible(id)
}

#' Komponente in einer Ergebnisliste ablegen (Kollision innerhalb eines Expanders: E)
#' @noRd
exp_put <- function(acc, coll, id, comp, bctx) {
  if (!is.null(acc[[coll]][[id]])) {
    bctx$abort("expand.id_duplicate", id = id)
  }
  acc[[coll]][[id]] <- comp
  acc
}

# ---------------------------------------------------------------------------------------------
# Aktivierungsfaktor (Teil B 0.8, Spec 00 4.12 Nr. 7, R-71)
# ---------------------------------------------------------------------------------------------

#' Instrumente mit `on_reject: drop_measures`, die eine Maßnahme fördern
#' @param x teilaufgelöste Spezifikation.
#' @param m Maßnahmen-id.
#' @return Zeichenvektor der Instrument-ids (YAML-Reihenfolge).
#' @noRd
exp_drop_funding <- function(x, m) {
  fund <- x$funding %||% list()
  ids <- names(fund)
  ids[vapply(ids, function(f) {
    fs <- fund[[f]]
    identical(exp_code(fs[["on_reject"]]), "drop_measures") &&
      m %in% exp_chr(fs[["measures"]]) &&
      !identical(exp_code(fs[["instrument_type"]]), "rent_binding")
  }, logical(1))]
}

#' Ausdruckstext des Aktivierungsfaktors a_m
#'
#' `measures.<m>.active * funding.<f>.approved * …` über alle Instrumente f mit
#' `on_reject: drop_measures` und m ∈ `funding.<f>.measures`; ohne solche Instrumente der Pfad
#' `measures.<m>.active` (fehlt das Feld: `"1"`).
#' @noRd
exp_activation_text <- function(x, m) {
  parts <- if (exp_has(x, paste0("measures.", m, ".active"))) {
    paste0("measures.", m, ".active")
  } else {
    character(0)
  }
  drop <- exp_drop_funding(x, m)
  if (length(drop) > 0L) parts <- c(parts, paste0("funding.", drop, ".approved"))
  if (length(parts) == 0L) return("1")
  paste(parts, collapse = " * ")
}

#' Knoten des Aktivierungsfaktors a_m (Bezug bzw. Ausdruck)
#' @noRd
exp_activation_node <- function(x, m) {
  txt <- exp_activation_text(x, m)
  if (identical(txt, "1")) return(node_const(1))
  if (exp_is_path(txt)) node_ref(txt) else node_expr(txt)
}

# ---------------------------------------------------------------------------------------------
# Maßnahmen: Termine
# ---------------------------------------------------------------------------------------------

#' Termine einer Maßnahme ohne Verschiebung (Teil A 4.1, 4.5.1 Nr. 2)
#'
#' @return Liste `dates` (Zahlungstermine, sortiert), `first`, `completion`, `weights`
#'   (Anteile je Termin nach Zahlungsplan, Summe 1, Basisfall) oder `NULL`, wenn kein Termin.
#' @noRd
exp_measure_dates <- function(x, m, bctx = NULL) {
  ms <- x$measures[[m]] %||% list()
  grid <- if (is.null(bctx)) NULL else bctx$grid
  sched <- ms[["payment_schedule"]]
  dates <- NULL
  weights <- NULL
  if (!is.null(sched)) {
    if (!node_is(sched)) {
      sched <- tryCatch(node_normalize(sched, vofi_param("schedule"), "payment_schedule"),
                        error = function(e) NULL)
    }
    if (is.list(sched) && inherits(sched$dates, "Date")) {
      ord <- order(as.numeric(sched$dates))
      dates <- sched$dates[ord]
      amt <- vapply(seq_along(sched$dates), function(i) {
        el <- if (is.list(sched$amounts)) sched$amounts[[i]] else sched$amounts[i]
        v <- exp_num(el)
        if (!is.null(v)) return(v[1L])
        if (is.null(bctx)) return(NA_real_)
        eval_sched <- function() {
          res_value(res_context(x, grid, 1L), paste0("measures.", m, ".payment_schedule"),
                    "scalar", base = TRUE, node = el)
        }
        tmp <- tryCatch(suppressWarnings(suppressMessages(eval_sched())),
                        error = function(e) NULL)
        if (is.numeric(tmp)) tmp[1L] else NA_real_
      }, double(1))[ord]
      if (anyNA(amt) || sum(amt) <= 0) amt <- rep(1, length(dates))
      weights <- amt / sum(amt)
    }
  }
  if (is.null(dates)) {
    d <- exp_date(ms[["date"]], grid) %||% exp_date(ms[["year"]], grid)
    if (is.null(d)) return(NULL)
    dur <- exp_int(ms[["duration_months"]]) %||% 0L
    if (dur > 0L) {
      k <- seq_len(dur)
      prof <- exp_code(ms[["payment_profile"]]) %||% "linear"
      dates <- grid_add_months(rep(d, dur), -(dur - k))
      weights <- capex_profile(prof, k / dur) - capex_profile(prof, (k - 1L) / dur)
    } else {
      dates <- d
      weights <- 1
    }
  }
  comp <- exp_date(ms[["completion_date"]], grid) %||% dates[length(dates)]
  list(dates = dates, weights = weights, first = dates[1L], completion = comp)
}

#' Fertigstellung einer Maßnahme ohne Verschiebung (oder `NULL`)
#' @noRd
exp_measure_completion <- function(x, m, bctx = NULL) {
  exp_measure_dates(x, m, bctx)$completion
}

# ---------------------------------------------------------------------------------------------
# Wohnungsgruppen
# ---------------------------------------------------------------------------------------------

#' Ist eine Wohnungsgruppe selbstgenutzt? (`owner_occupied`, Default nach Perspektive)
#' @noRd
exp_group_owner <- function(x, g) {
  v <- exp_lgl(x$unit_groups[[g]][["owner_occupied"]])
  if (!is.null(v)) return(v)
  identical(x$project$perspective, "selbstnutzer")
}

#' Vermietete Wohnungsgruppen (YAML-Reihenfolge)
#' @noRd
exp_rented_groups <- function(x) {
  gs <- names(x$unit_groups %||% list())
  gs[!vapply(gs, function(g) exp_group_owner(x, g), logical(1))]
}

#' Selbstgenutzte Wohnungsgruppen (YAML-Reihenfolge)
#' @noRd
exp_owner_groups <- function(x) {
  gs <- names(x$unit_groups %||% list())
  gs[vapply(gs, function(g) exp_group_owner(x, g), logical(1))]
}

# ---------------------------------------------------------------------------------------------
# Regeln mit Rückfall
# ---------------------------------------------------------------------------------------------

#' Regelfunktion zum Rechtsstand; ohne wählbare Version die früheste Version mit Hinweis
#'
#' Die Förderregeln gelten ab 2026-07-21; ein früherer Rechtsstand mit einem Förderinstrument
#' nutzt die früheste Version (I `expand.rule_fallback`), statt die Auflösung abzubrechen.
#' @noRd
exp_rule <- function(bctx, name) {
  f <- tryCatch(bctx$rule(name), vofi_error_registry = function(e) NULL)
  if (!is.null(f)) return(f)
  versions <- reg_rules(name)
  if (length(versions) == 0L) return(bctx$rule(name))
  vf <- vapply(versions, function(d) as.double(d$valid_from), double(1))
  d <- versions[[order(vf, method = "radix")[1L]]]
  bctx$inform("expand.rule_fallback", rule = name, version = d$name)
  d$fun
}

# ---------------------------------------------------------------------------------------------
# Bedingungsausdrücke der Förderung (Teil B 4.3.2)
# ---------------------------------------------------------------------------------------------

#' Bedingungsausdruck deterministisch auswerten (`fund_eval_condition()`, Teil B 4.3.2)
#'
#' Grammatik nach Spec 00 4.5 Regel 5 (Vergleiche, `&`, `|`, `!`, `%in%`, `c()`, Grundrechenarten,
#' `pmin`, `pmax`, `abs`); Symbole werden über `lookup(symbol)` aufgelöst (Zahl, Wahrheitswert oder
#' Code). Ein unbekanntes Symbol (`lookup` liefert `NULL`) ist ein Fehler.
#' @param text Ausdruck.
#' @param lookup Funktion Symbol -> Wert.
#' @param on_error Funktion(key, ...) für Meldungen (Default `vofi_abort` als Validierungsfehler).
#' @return `TRUE`/`FALSE`.
#' @noRd
fund_eval_condition <- function(text, lookup, on_error = NULL) {
  fail <- on_error %||% function(key, ...) {
    vofi_abort(key, ..., .class = "vofi_error_validation")
  }
  if (is.logical(text) && length(text) == 1L && !is.na(text)) return(text)
  if (!utl_is_string(text)) fail("expand.funding.condition_invalid", condition = format(text))
  e <- tryCatch(parse(text = text, keep.source = FALSE), error = function(err) NULL)
  if (is.null(e) || length(e) != 1L) fail("expand.funding.condition_invalid", condition = text)
  ev <- function(node) {
    if (is.numeric(node) || is.logical(node) || is.character(node)) return(node)
    if (is.symbol(node)) {
      s <- as.character(node)
      if (s %in% c("TRUE", "FALSE")) return(s == "TRUE")
      v <- lookup(s)
      if (is.null(v)) fail("expand.funding.condition_symbol", condition = text, symbol = s)
      return(v)
    }
    if (!is.call(node)) fail("expand.funding.condition_invalid", condition = text)
    fn <- as.character(node[[1L]])
    args <- lapply(as.list(node)[-1L], ev)
    switch(fn,
      "(" = args[[1L]],
      "!" = !as.logical(args[[1L]]),
      "&" = as.logical(args[[1L]]) & as.logical(args[[2L]]),
      "|" = as.logical(args[[1L]]) | as.logical(args[[2L]]),
      "==" = identical(as.character(args[[1L]]), as.character(args[[2L]])) ||
        (is.numeric(args[[1L]]) && is.numeric(args[[2L]]) && isTRUE(args[[1L]] == args[[2L]])),
      "!=" = !(identical(as.character(args[[1L]]), as.character(args[[2L]])) ||
                 (is.numeric(args[[1L]]) && is.numeric(args[[2L]]) &&
                    isTRUE(args[[1L]] == args[[2L]]))),
      "<" = as.double(args[[1L]]) < as.double(args[[2L]]),
      "<=" = as.double(args[[1L]]) <= as.double(args[[2L]]),
      ">" = as.double(args[[1L]]) > as.double(args[[2L]]),
      ">=" = as.double(args[[1L]]) >= as.double(args[[2L]]),
      "+" = if (length(args) == 1L) as.double(args[[1L]]) else
        as.double(args[[1L]]) + as.double(args[[2L]]),
      "-" = if (length(args) == 1L) -as.double(args[[1L]]) else
        as.double(args[[1L]]) - as.double(args[[2L]]),
      "*" = as.double(args[[1L]]) * as.double(args[[2L]]),
      "/" = as.double(args[[1L]]) / as.double(args[[2L]]),
      "%in%" = as.character(args[[1L]]) %in% as.character(unlist(args[[2L]])),
      "c" = unlist(args),
      "pmin" = do.call(pmin, lapply(args, as.double)),
      "pmax" = do.call(pmax, lapply(args, as.double)),
      "abs" = abs(as.double(args[[1L]])),
      fail("expand.funding.condition_invalid", condition = text)
    )
  }
  out <- ev(e[[1L]])
  isTRUE(as.logical(out)[1L])
}

# ---------------------------------------------------------------------------------------------
# Förderinstrumente: deterministische Vorauswertung (Teil B 4.1–4.4)
# ---------------------------------------------------------------------------------------------

#' Antragsteller eines Instruments (`funding.<f>.applicant`, Default aus der Perspektive)
#' @noRd
fund_applicant <- function(x, fs) {
  a <- exp_code(fs[["applicant"]])
  if (!is.null(a)) return(a)
  switch(x$project$perspective %||% "",
    wu_kommunal = "kommunales_unternehmen",
    wu_genossenschaft = "genossenschaft",
    wu_privat = "unternehmen",
    kleinvermieter = "privatperson_vermieter",
    selbstnutzer = "privatperson",
    NA_character_
  )
}

#' Wohnungsgruppen eines Instruments (Default: alle Gruppen)
#' @noRd
fund_groups <- function(x, fs) {
  g <- exp_chr(fs[["unit_groups"]])
  if (length(g) == 0L) g <- names(x$unit_groups %||% list())
  g
}

#' Zahl der Wohneinheiten N_f eines Instruments (Teil B 4.4; Basisfall, deterministisch)
#' @noRd
fund_n_units <- function(x, fs, bctx) {
  gs <- exp_chr(fs[["unit_groups"]])
  if (length(gs) > 0L) {
    n <- vapply(gs, function(g) {
      exp_base(bctx, x, paste0("unit_groups.", g, ".n_units")) %||% 0
    }, double(1))
    return(as.integer(round(sum(n))))
  }
  nb <- exp_base(bctx, x, "building.n_units")
  if (!is.null(nb)) return(as.integer(round(nb)))
  gs <- names(x$unit_groups %||% list())
  if (length(gs) == 0L) return(1L)
  as.integer(round(sum(vapply(gs, function(g) {
    exp_base(bctx, x, paste0("unit_groups.", g, ".n_units")) %||% 0
  }, double(1)))))
}

#' Symbol `unit.owner_occupied` eines Instruments (Teil B 4.3.2)
#' @noRd
fund_owner_occupied <- function(x, fs) {
  gs <- fund_groups(x, fs)
  if (length(gs) == 0L) return(identical(x$project$perspective, "selbstnutzer"))
  all(vapply(gs, function(g) exp_group_owner(x, g), logical(1)))
}

#' Antragsdatum eines Instruments (Instrument, sonst Projekt, sonst Stichtag)
#' @noRd
fund_application_date <- function(x, fs) {
  exp_date(fs[["application_date"]]) %||% exp_date(x$project$application_date) %||%
    exp_date(x$project$valuation_date)
}

#' Klasse eines Energieträgers (Domänenblatt `energy.carriers.<c>.class`, sonst kanonische id)
#' @noRd
exp_carrier_class <- function(x, c) {
  cl <- exp_code(x$energy$carriers[[c]][["class"]])
  if (!is.null(cl)) return(cl)
  switch(c,
    gas = , gas_mfh = "gas", oil = "oil", lpg = "lpg", power = , power_mfh = "power",
    heatpump_power = , heatpump_power_mfh = "power_hp", district_heating = "district_heating",
    pellets = "biomass", coal = "coal", NA_character_
  )
}

#' Wärmeträger eines Energiezustands (Anteile > 0 bzw. `heating_carrier`; ohne Angabe geerbt)
#' @param x Spezifikation.
#' @param path Pfadpräfix des Zustands.
#' @noRd
exp_state_carriers <- function(x, path) {
  st <- path_get(x, path) %||% list()
  sh <- st[["carrier_shares"]]
  if (is.list(sh) && length(sh) > 0L) {
    keep <- vapply(names(sh), function(c) {
      v <- exp_num(sh[[c]])
      is.null(v) || isTRUE(v[1L] > 0)
    }, logical(1))
    return(names(sh)[keep])
  }
  hc <- exp_code(st[["heating_carrier"]])
  if (!is.null(hc)) return(hc)
  character(0)
}

#' Symbol `heating.replaced_fossil_functional` (Teil B 4.3.2, F-18)
#' @param min_age Mindestalter für Gas/Biomasse (Jahre).
#' @noRd
fund_replaced_fossil <- function(x, fs, min_age) {
  fact <- exp_lgl(fs[["facts"]][["heating_replaced_fossil_functional"]])
  if (!is.null(fact)) return(fact)
  carriers <- exp_state_carriers(x, "energy.before")
  he <- x$building$heating_existing %||% list()
  if (length(carriers) == 0L) carriers <- exp_chr(he[["carrier"]])
  if (length(carriers) == 0L) return(FALSE)
  classes <- vapply(carriers, function(c) exp_carrier_class(x, c), character(1))
  if (any(classes %in% c("oil", "coal", "power"))) return(TRUE)
  type <- exp_code(he[["type"]]) %||% "central"
  if (any(classes == "gas") && identical(type, "floor")) return(TRUE)
  inst <- exp_date(x$energy$before$installation_date) %||%
    exp_date(he[["installation_year"]])
  ad <- fund_application_date(x, fs)
  age <- if (is.null(inst) || is.null(ad)) NA_real_ else utl_year(ad) - utl_year(inst)
  isTRUE(any(classes %in% c("gas", "biomass")) && !is.na(age) && age >= (min_age %||% Inf))
}

#' Zu versteuerndes Einkommen nach Kinderverschiebung (`taxable_income_adj`, Teil B 4.3.2)
#' @param sched Staffel `schedule_by_taxable_income` (für die Verschiebung) oder `NULL`.
#' @noRd
fund_taxable_income_adj <- function(x, sched = NULL) {
  ti <- exp_num(x$household$taxable_income_avg_eur)
  if (is.null(ti)) return(NULL)
  kids <- exp_num(x$household$n_children_u18) %||% 0
  shift <- exp_num(sched[["child_u18_threshold_shift_eur"]]) %||% 0
  per_child <- isTRUE(exp_lgl(sched[["child_u18_threshold_shift_per_child"]]))
  ti[1L] - shift[1L] * (if (per_child) kids[1L] else min(kids[1L], 1))
}

#' Auflöser der Bedingungssymbole eines Instruments (Teil B 4.3.2)
#' @param comp Satzbaustein (für `min_age_gas_biomass_years`, Staffel) oder `NULL`.
#' @param fail optional: Funktion(key, ...) für Fehler; fehlt das zu versteuernde Einkommen für
#'   `taxable_income_adj`, meldet sie `expand.funding.taxable_income_missing` (statt
#'   `expand.funding.condition_symbol` über `fund_eval_condition()`).
#' @noRd
fund_lookup <- function(x, f, fs, comp = NULL, fail = NULL) {
  facts <- fs[["facts"]] %||% list()
  sched <- comp[["schedule_by_taxable_income"]]
  if (is.null(sched)) {
    for (rc in fs[["rate_components"]] %||% list()) {
      if (is.list(rc[["schedule_by_taxable_income"]])) {
        sched <- rc[["schedule_by_taxable_income"]]
        break
      }
    }
  }
  min_age <- exp_num(comp[["min_age_gas_biomass_years"]])
  if (is.null(min_age)) {
    for (rc in fs[["rate_components"]] %||% list()) {
      v <- exp_num(rc[["min_age_gas_biomass_years"]])
      if (!is.null(v)) {
        min_age <- v
        break
      }
    }
  }
  value_of <- function(v) {
    l <- exp_lgl(v)
    if (is.logical(v) || (is.list(v) && is.logical(v[["value"]]))) return(l)
    n <- exp_num(v)
    if (!is.null(n)) return(n[1L])
    if (!is.null(l)) return(l)
    exp_code(v)
  }
  function(sym) {
    if (identical(sym, "unit.owner_occupied")) return(fund_owner_occupied(x, fs))
    if (identical(sym, "heating.replaced_fossil_functional")) {
      return(fund_replaced_fossil(x, fs, min_age))
    }
    if (identical(sym, "taxable_income_adj")) {
      v <- fund_taxable_income_adj(x, sched)
      if (is.null(v) && is.function(fail)) fail("expand.funding.taxable_income_missing")
      return(v)
    }
    if (identical(sym, "application_year")) {
      ad <- fund_application_date(x, fs)
      return(if (is.null(ad)) NULL else utl_year(ad))
    }
    if (startsWith(sym, "funding.this.")) {
      key <- substring(sym, 14L)
      v <- facts[[key]]
      if (!is.null(v)) return(value_of(v))
      return(switch(key,
        isfp = exp_lgl(x$building$isfp_available) %||% FALSE,
        serial_renovation = exp_lgl(x$building$serial_renovation) %||% FALSE,
        ee_class = , nh_class = , lca_thg = , qng = FALSE,
        NULL
      ))
    }
    if (startsWith(sym, "building.")) {
      v <- path_get(x, sym)
      if (is.null(v)) {
        if (sym %in% c("building.wpb_flag", "building.denkmal", "building.serial_renovation",
                       "building.isfp_available")) {
          return(FALSE)
        }
        return(NULL)
      }
      if (is.list(v) && !identical(v[["kind"]], "const")) return(NULL)
      return(value_of(v))
    }
    if (startsWith(sym, "funding.")) {
      v <- path_get(x, sym)
      if (is.null(v) || (is.list(v) && !identical(v[["kind"]], "const"))) return(NULL)
      return(value_of(v))
    }
    if (startsWith(sym, "project.") || startsWith(sym, "household.")) {
      v <- path_get(x, sym)
      if (is.null(v) || (is.list(v) && !identical(v[["kind"]], "const") &&
                           !is.null(v[["kind"]]))) {
        return(NULL)
      }
      return(value_of(v))
    }
    NULL
  }
}

#' Fakt eines Instruments (`facts.<key>`, Default nach Teil B 4.3.2)
#' @noRd
fund_fact <- function(x, fs, key) {
  isTRUE(fund_lookup(x, "", fs)(paste0("funding.this.", key)))
}

#' Berechtigung eines Instruments deterministisch prüfen (Teil B 4.3.1)
#'
#' @return Liste `eligible` (lgl), `reasons` (Liste von `list(code, args)` der verletzten
#'   Bedingungen, W), `open` (Liste offener Prüfpunkte, I), `errors` (Liste, E: nicht förderfähige
#'   Maßnahmentypen), `override` (lgl).
#' @noRd
fund_check_eligibility <- function(x, f, fs, bctx) {
  override <- isTRUE(exp_lgl(fs[["eligibility_override"]]))
  # Befunde in einer lokalen Umgebung sammeln (keine Zuweisung nach aussen, Spec 00 2.7 Nr. 3)
  acc <- new.env(parent = emptyenv())
  acc$reasons <- list()
  acc$open <- list()
  errors <- list()
  el <- fs[["eligibility"]] %||% list()
  bad <- function(code, ...) {
    acc$reasons[[length(acc$reasons) + 1L]] <- list(code = code, args = list(...))
  }
  open <- function(code, ...) {
    acc$open[[length(acc$open) + 1L]] <- list(code = code, args = list(...))
  }
  ms <- exp_chr(fs[["measures"]])
  mt_ok <- exp_chr(el[["measure_types"]])
  if (length(mt_ok) > 0L) {
    for (m in ms) {
      mt <- exp_code(x$measures[[m]][["measure_type"]])
      if (!is.null(mt) && !(mt %in% mt_ok)) {
        errors[[length(errors) + 1L]] <- list(measure = m, measure_type = mt)
      }
    }
  }
  apps <- exp_chr(el[["applicants"]])
  if (length(apps) > 0L) {
    a <- fund_applicant(x, fs)
    ok <- !is.na(a) && (a %in% apps || (identical(a, "privatperson_vermieter") &&
                                          "privatperson" %in% apps))
    if (!ok) bad("applicants", value = a %||% "-")
  }
  pts <- exp_chr(el[["project_types"]])
  if (length(pts) > 0L && !(x$project$project_type %||% "" %in% pts)) {
    bad("project_types", value = x$project$project_type %||% "-")
  }
  cond <- el[["conditions"]] %||% list()
  lk <- fund_lookup(x, f, fs)
  ad <- fund_application_date(x, fs)
  for (key in names(cond)) {
    v <- cond[[key]]
    if (is.null(v)) next
    req <- identical(exp_code(v), "required")
    switch(key,
      owner_occupied = if (req && !isTRUE(lk("unit.owner_occupied"))) bad(key),
      taxable_income_max_eur = {
        ti <- exp_num(x$household$taxable_income_avg_eur)
        lim <- if (is.list(v) && !is.null(v[["base"]])) {
          kids <- exp_num(x$household$n_children_u18) %||% 0
          (exp_num(v[["base"]]) %||% Inf) +
            (exp_num(v[["per_additional_child"]]) %||% 0) * max(kids[1L] - 1, 0)
        } else {
          exp_num(v)[1L]
        }
        if (is.null(ti)) bad(key, value = "-") else if (ti[1L] > lim) bad(key, value = ti[1L])
      },
      children_u18_min = {
        kids <- exp_num(x$household$n_children_u18) %||% 0
        if (kids[1L] < (exp_num(v) %||% 0)[1L]) bad(key, value = kids[1L])
      },
      efficiency_standard = {
        es <- exp_code(x$building$efficiency_standard_after) %||% "none"
        if (identical(es, "none")) {
          bad("efficiency_standard_missing")
        } else if (!identical(es, exp_code(v))) {
          bad(key, value = es)
        }
      },
      ee_or_nh_class = if (req && !(isTRUE(lk("funding.this.ee_class")) ||
                                      isTRUE(lk("funding.this.nh_class")))) {
        bad(key)
      },
      lca_thg = if (req && !isTRUE(lk("funding.this.lca_thg"))) bad(key),
      fossil_or_biomass_heating = , oil_gas_heating = if (identical(exp_code(v), "excluded")) {
        excl <- if (key == "oil_gas_heating") c("gas", "oil", "lpg") else
          c("gas", "oil", "lpg", "biomass")
        cls <- fund_after_classes(x, ms)
        if (any(cls %in% excl)) bad(key, value = utl_collapse(intersect(cls, excl)))
      },
      building_age_min_years = {
        cy <- exp_num(x$building$construction_year)
        if (is.null(cy) || is.null(ad)) {
          open(key)
        } else if (utl_year(ad) - cy[1L] < exp_num(v)[1L]) {
          bad(key, value = utl_year(ad) - cy[1L])
        }
      },
      min_investment_eur = {
        tot <- sum(vapply(ms, function(m) {
          exp_base(bctx, x, paste0("measures.", m, ".cost_eur")) %||% 0
        }, double(1)))
        if (tot < exp_num(v)[1L]) bad(key, value = tot)
      },
      energy_class_at_application = {
        ec <- exp_code(x$building$energy_class_before)
        if (is.null(ec)) open(key) else if (!(ec %in% exp_chr(v))) bad(key, value = ec)
      },
      completion_before = NULL,
      requires_beg_em_commitment_months = NULL,
      energy_efficiency_expert = , contractor_certified = if (req) {
        fv <- exp_lgl(fs[["facts"]][[key]])
        if (is.null(fv)) open(key) else if (!fv) bad(key)
      },
      open(key)
    )
  }
  for (ex in exp_chr(el[["exclusions"]])) open("exclusion", text = ex)
  reasons <- if (override) list() else acc$reasons
  list(eligible = length(reasons) == 0L, reasons = reasons, open = acc$open, errors = errors,
       override = override)
}

#' Klassen der Wärmeträger im Zustand nach den Maßnahmen eines Instruments
#'
#' Zustand mit `measure` ∈ Maßnahmen des Instruments, sonst `after`; ohne Trägerangabe der
#' geerbte Träger des Vorzustands.
#' @noRd
fund_after_classes <- function(x, ms) {
  en <- x$energy %||% list()
  paths <- c(if (!is.null(en$after)) "energy.after",
             if (length(en$stages) > 0L) paste0("energy.stages.", names(en$stages)))
  hit <- Filter(function(p) {
    exp_code(path_get(x, p)[["measure"]]) %in% ms
  }, paths)
  p <- if (length(hit) > 0L) hit[[1L]] else if (!is.null(en$after)) "energy.after" else NULL
  carriers <- if (is.null(p)) character(0) else exp_state_carriers(x, p)
  if (length(carriers) == 0L) carriers <- exp_state_carriers(x, "energy.before")
  unique(vapply(carriers, function(c) exp_carrier_class(x, c), character(1)))
}

#' Vorauswertung aller Instrumente einer Variante (ohne Meldungen)
#'
#' @return benannte Liste je Instrument: `type`, `measures`, `eligible`, `check` (Ergebnis von
#'   `fund_check_eligibility()`), `component` (erzeugte id oder `NULL`), `collection`.
#' @noRd
fund_plan <- function(x, bctx) {
  fund <- x$funding %||% list()
  out <- list()
  for (f in names(fund)) {
    fs <- fund[[f]]
    type <- exp_code(fs[["instrument_type"]]) %||% NA_character_
    chk <- fund_check_eligibility(x, f, fs, bctx)
    id <- switch(type,
      grant = paste0("f_", f, "_grant"),
      loan = , loan_with_repayment_grant = paste0("f_", f, "_loan"),
      interest_subsidy = paste0("f_", f, "_subsidy"),
      tax_credit = paste0("f_", f, "_35c"),
      NULL
    )
    out[[f]] <- list(type = type, measures = exp_chr(fs[["measures"]]),
                     eligible = chk$eligible, check = chk,
                     component = if (chk$eligible) id else NULL,
                     collection = if (type %in% c("loan", "loan_with_repayment_grant")) {
                       "financing"
                     } else {
                       "components"
                     })
  }
  out
}

#' Liegen vermietete Gruppen bzw. die Mietersicht vor (Bedingung von `e_tenant`, Teil B 3.5 Nr. 8)?
#' @noRd
exp_energy_tenant <- function(x) {
  en <- x$energy %||% list()
  has_state <- !is.null(en$before) || !is.null(en$after) || length(en$stages %||% list()) > 0L
  has_state && (length(exp_rented_groups(x)) > 0L || isTRUE(exp_lgl(x$analysis$tenant_view)))
}
