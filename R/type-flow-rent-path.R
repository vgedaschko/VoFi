# Zahlungstyp rent_path: Mietpfad einer Wohnungsgruppe als eine monatlich rechnende Komponente
# (WS-E, Spec 00 Abschnitte 3.4, 3.7, 4.3.6a, 4.12 Nr. 6, R-63; Spec 01 Teil B Abschnitte 0.4-0.8,
# 1.7-1.15). Die Komponente rechnet je Lauf (vektorisiert) einen repräsentativen Mietvertrag mit
# Basismiete B und Umlagen L_k je Maßnahme; Zeilen rent, rent_loss und levy_<k>. §§ 558, 559-559f,
# Staffel-/Indexmiete, Mietpreisbremse und Bindung stehen als Rechtsregeln in R/rules-mietrecht.R.
# Gemeinsame Helfer dieses Teils (auch für energy_cost, pv und die Fördertypen von WS-E2):
# act() (Aktivierungsfaktor, 0.8), rp_vacancy_share() (Leerstandsanteil aus der Domäne, 3.6.2),
# rp_signal()/rp_meta_notes() (laufbezogene Meldungen I/W mit Anteil der Läufe, 1.14) und die
# Monatshelfer rp_*.

# nolint start: object_name_linter. P wie im Regelkatalog (Teil B 5.1)

# ---------------------------------------------------------------------------------------------
# Monatsraster (Teil B 0.4)
# ---------------------------------------------------------------------------------------------

#' Monate des Rasters: Kalenderjahr, Kalendermonat und Periode je Monat m = 1…M
#' @noRd
rp_months <- function(grid) {
  big_m <- grid$month_end[grid$T + 1L]
  m <- seq_len(big_m)
  m0 <- utl_month(grid$valuation_date) - 1L
  list(M = big_m, m = m, year = utl_year(grid$valuation_date) + (m0 + m - 1L) %/% 12L,
       moy = (m0 + m - 1L) %% 12L + 1L, period = utl_month_period(grid, m))
}

#' Monatsindex mi(d) eines Datums für laufende Wirkungen (Teil B 0.4)
#'
#' mi(Stichtag) = 1; Daten, die keine Monatserste sind, werden auf den folgenden Monatsersten
#' gerundet. `NA` bleibt `NA`.
#' @return double-Vektor ganzzahliger Werte.
#' @noRd
rp_mi <- function(grid, date) {
  if (length(date) == 0L) return(numeric(0))
  d <- as.Date(date)
  out <- rep(NA_real_, length(d))
  ok <- !is.na(d)
  if (any(ok)) out[ok] <- utl_month_ceiling(grid_month_pos(grid, d[ok])) + 1
  out
}

#' Monatsindex des Monats, in dem ein Datum liegt (Monatsanfang, abgerundet; Teil B 1.9.4)
#' @noRd
rp_mi_floor <- function(grid, date) {
  if (length(date) == 0L) return(numeric(0))
  d <- as.Date(date)
  vd <- grid$valuation_date
  as.double((utl_year(d) - utl_year(vd)) * 12L + utl_month(d) - utl_month(vd) + 1L)
}

#' Verschiebung in ganzen Monaten (floor(x + 0,5), Spec 00 3.9)
#' @noRd
rp_shift <- function(x) floor(as.double(x) + 0.5)

#' Spalte j*(Y) des Kalenderjahressatzes (Teil B 0.4): erste Periode j >= 2 mit year[j] = Y;
#' nach dem Raster die letzte, vor dem Raster die zweite Spalte
#' @noRd
rp_year_col <- function(grid, years) {
  yr <- grid$year
  n_t <- length(yr)
  if (n_t < 2L) return(rep(1L, length(years)))
  cand <- yr[-1L]
  vapply(years, function(y) {
    j <- which(cand == y)
    if (length(j) > 0L) return(j[1L] + 1L)
    if (y > max(cand)) return(n_t)
    if (y < min(cand)) return(2L)
    max(which(cand <= y)) + 1L
  }, integer(1))
}

#' Kalenderjahreswerte einer Pfadmatrix je Monat (n x M)
#' @noRd
rp_year_months <- function(grid, mo, x) {
  x[, rp_year_col(grid, mo$year), drop = FALSE]
}

#' Periodenwerte einer Pfadmatrix je Monat (n x M; Wert der Periode p(m))
#' @noRd
rp_period_months <- function(mo, x) {
  x[, mo$period + 1L, drop = FALSE]
}

#' Logarithmischer Monatsindex I_g(m) = Π (1 + g_{y(μ)})^(1/12) (Teil B 0.4)
#' @param rate_m n x M Kalenderjahressätze je Monat.
#' @param rate_before n-Vektor des Satzes vor dem Raster (Spalte 2).
#' @return Liste mit `L` (n x (M+1), Spalte 1 = Monat 0), `rb`, `rl` (log-Monatsraten).
#' @noRd
rp_log_index <- function(rate_m, rate_before) {
  n <- nrow(rate_m)
  big_m <- ncol(rate_m)
  lm <- log1p(rate_m) / 12
  cl <- matrix(0, n, big_m + 1L)
  for (m in seq_len(big_m)) cl[, m + 1L] <- cl[, m] + lm[, m]
  list(L = cl, rb = log1p(rate_before) / 12,
       rl = if (big_m > 0L) lm[, big_m] else log1p(rate_before) / 12, M = big_m)
}

#' Logarithmischer Index an Monat(en) mm (Skalar oder n-Vektor) je Lauf
#' @noRd
rp_log_index_at <- function(li, mm) {
  n <- nrow(li$L)
  mm <- rep_len(as.double(mm), n)
  out <- numeric(n)
  inside <- mm >= 0 & mm <= li$M
  if (any(inside)) out[inside] <- li$L[cbind(which(inside), mm[inside] + 1)]
  lo <- mm < 0
  out[lo] <- mm[lo] * li$rb[lo]
  hi <- mm > li$M
  out[hi] <- li$L[hi, li$M + 1L] + (mm[hi] - li$M) * li$rl[hi]
  out
}

#' Monatsreihe x(m) eines Niveaus mit Bezugsmonat m0: x0 * I(m) / I(m0) (n x M)
#' @noRd
rp_level_path <- function(li, x0, m0) {
  base <- rp_log_index_at(li, m0)
  exp(li$L[, -1L, drop = FALSE] - base) * x0
}

#' Monatsmatrix -> Monatsmittel je Periode (n x (T+1), Spalte 1 = 0)
#' @noRd
rp_period_mean <- function(ctx, x_m) {
  s <- ctx$to_periods(x_m)
  mon <- ctx$by_period(pmax(ctx$grid$months, 1L))
  out <- s / mon
  out[, 1L] <- 0
  out
}

# ---------------------------------------------------------------------------------------------
# Laufbezogene Meldungen (Teil B 1.14, 3.6.5)
# ---------------------------------------------------------------------------------------------

#' Laufbezogene Meldung eines Typs (I bzw. W mit Anteil der betroffenen Läufe)
#'
#' Meldet die Bedingung je Bau einmal über `ctx$inform()` bzw. `ctx$warn()` mit dem Platzhalter
#' `share` (Anteil der Läufe des Chunks) und gibt den Eintrag für `meta$messages` zurück. Die
#' Prüfung aggregiert ausdrücklich über alle Läufe (Spec 00 § 2.8 Nr. 3); die Zeilen hängen nicht
#' von ihr ab.
#' @param ctx Laufkontext.
#' @param key Label-Schlüssel der Meldung.
#' @param hit logischer n-Vektor der betroffenen Läufe (`NA` = nicht betroffen).
#' @param level `"inform"` (I) oder `"warn"` (W).
#' @param ... weitere Platzhalter.
#' @return `list(key, level, share)` oder `NULL`, wenn kein Lauf betroffen ist.
#' @noRd
rp_signal <- function(ctx, key, hit, level = c("inform", "warn"), ...) {
  level <- utl_match_arg(level, c("inform", "warn"), "level")
  hit <- rep_len(as.logical(hit), ctx$n)
  hit[is.na(hit)] <- FALSE
  if (!any(hit)) return(NULL)
  share <- mean(hit)
  if (identical(level, "warn")) ctx$warn(key, share = share, ...) else
    ctx$inform(key, share = share, ...)
  list(key = key, level = level, share = share)
}

#' Vermerke und Meldungen für `meta` (Texte, Schlüssel, Meldungsliste)
#' @param notes Schlüssel reiner Vermerke.
#' @param messages Liste der Einträge aus `rp_signal()` (`NULL`-Einträge werden entfernt).
#' @param ... Platzhalter der Texte.
#' @noRd
rp_meta_notes <- function(notes, messages = list(), ...) {
  messages <- Filter(Negate(is.null), messages)
  keys <- unique(c(notes, vapply(messages, function(x) x$key, "")))
  shares <- stats::setNames(vapply(messages, function(x) x$share, 0),
                            vapply(messages, function(x) x$key, ""))
  texts <- vapply(keys, function(k) {
    lbl(k, ..., share = if (k %in% names(shares)) shares[[k]] else 1)
  }, "")
  list(notes = texts, note_keys = keys, messages = unname(messages))
}

# ---------------------------------------------------------------------------------------------
# Domänenlesezugriff (Teil B 0.5)
# ---------------------------------------------------------------------------------------------

#' Rohwert eines Domänenpfads (nur lesen)
#' @noRd
rp_raw <- function(ctx, path) path_get(ctx$spec, path)

#' Numerischer Domänenwert (n-Vektor bzw. n x (T+1)) oder `default`
#' @noRd
rp_num <- function(ctx, path, default = NULL, shape = "scalar") {
  raw <- rp_raw(ctx, path)
  if (is.null(raw)) return(default)
  ctx$value(path, shape) %||% default
}

#' Code (Zeichenkette) aus einem Domänen- bzw. Parameterwert; Aliase eines Enums werden
#' kanonisiert
#' @noRd
rp_code <- function(x, enum = NULL) {
  if (is.null(x) || length(x) == 0L) return(NULL)
  if (is.list(x) && identical(x[["kind"]], "const")) x <- x[["value"]]
  if (is.list(x)) x <- unlist(x, use.names = FALSE)
  if (is.numeric(x)) x <- format(x, scientific = FALSE, trim = TRUE)
  if (is.logical(x)) x <- tolower(as.character(x))
  x <- as.character(x)[1L]
  if (is.na(x)) return(NULL)
  if (!is.null(enum)) {
    sp <- tryCatch(utl_vocab_spec(paste0("vocab:", enum)), error = function(e) NULL)
    if (!is.null(sp) && x %in% names(sp$aliases)) x <- unname(sp$aliases[[x]])
  }
  x
}

#' Wahrheitswert aus einem Rohwert bzw. `default`
#' @noRd
rp_lgl <- function(x, default = FALSE) {
  if (is.null(x) || length(x) == 0L) return(default)
  if (is.list(x) && identical(x[["kind"]], "const")) x <- x[["value"]]
  if (is.logical(x)) return(isTRUE(x[1L]))
  if (is.numeric(x)) return(isTRUE(x[1L] > 0.5))
  tolower(as.character(x[1L])) %in% c("true", "yes", "ja", "on", "1")
}

#' ids aus einem Rohwert
#' @noRd
rp_ids <- function(x) {
  if (is.null(x) || length(x) == 0L) return(character(0))
  as.character(unlist(x, use.names = FALSE))
}

#' Datum aus einem Rohwert (Date, ISO-Zeichenkette, Jahr, {date|year}, Token `completion`)
#' @noRd
rp_as_date <- function(x, grid = NULL) {
  if (is.null(x) || length(x) == 0L) return(NULL)
  if (inherits(x, "Date")) return(x[1L])
  if (is.list(x)) {
    if (!is.null(x[["date"]])) return(rp_as_date(x[["date"]], grid))
    if (!is.null(x[["year"]])) return(rp_as_date(x[["year"]], grid))
    if (identical(x[["kind"]], "const")) return(rp_as_date(x[["value"]], grid))
    return(NULL)
  }
  if (is.character(x)) {
    if (identical(x[1L], "completion")) return(grid$completion_date)
    if (identical(x[1L], "valuation_date")) return(grid$valuation_date)
    if (identical(x[1L], "end_date")) return(grid$end_date)
    d <- as.Date(x[1L], optional = TRUE)
    if (!is.na(d)) return(d)
    y <- suppressWarnings(as.integer(x[1L]))
    if (!is.na(y) && y >= 1000L) return(as.Date(sprintf("%04d-01-01", y)))
    return(NULL)
  }
  if (is.numeric(x) && !is.na(x[1L]) && x[1L] >= 1000) {
    return(as.Date(sprintf("%04d-01-01", as.integer(x[1L]))))
  }
  NULL
}

#' Fertigstellungstermin einer Maßnahme (completion_date, date, year bzw. letzter Termin des
#' Zahlungsplans; Teil A 4.1) ohne Verschiebung
#' @noRd
rp_measure_completion <- function(ctx, k) {
  ms <- ctx$spec$measures[[k]] %||% list()
  d <- rp_as_date(ms[["completion_date"]], ctx$grid) %||% rp_as_date(ms[["date"]], ctx$grid) %||%
    rp_as_date(ms[["year"]], ctx$grid)
  if (!is.null(d)) return(d)
  ds <- rp_schedule_dates(ms[["payment_schedule"]])
  if (length(ds) > 0L) return(max(ds))
  NULL
}

#' Termine eines Zahlungsplans (Knoten oder Rohform)
#' @noRd
rp_schedule_dates <- function(x) {
  if (is.null(x)) return(as.Date(character(0)))
  if (is.list(x) && identical(x[["kind"]], "schedule")) return(as.Date(x$dates))
  if (is.list(x) && is.list(x[["schedule"]])) {
    ds <- lapply(names(x[["schedule"]]), function(k) rp_as_date(k))
    ds <- Filter(Negate(is.null), ds)
    if (length(ds) == 0L) return(as.Date(character(0)))
    return(do.call(c, ds))
  }
  as.Date(character(0))
}

#' Erster Zahlungstermin bzw. Beginn der Ausführung einer Maßnahme (Teil B 1.4 works_start_date)
#' @noRd
rp_measure_first_date <- function(ctx, k) {
  ms <- ctx$spec$measures[[k]] %||% list()
  ds <- rp_schedule_dates(ms[["payment_schedule"]])
  if (length(ds) > 0L) return(min(ds))
  y <- rp_as_date(ms[["year"]], ctx$grid)
  if (!is.null(y)) return(y)
  d <- rp_as_date(ms[["date"]], ctx$grid)
  if (!is.null(d)) {
    dur <- suppressWarnings(as.integer(mr_num(ms[["duration_months"]]) %||% 0))
    return(grid_add_months(d, -dur))
  }
  rp_measure_completion(ctx, k)
}

#' Verschiebung einer Maßnahme in Monaten je Lauf (measures.<k>.delay_months, gerundet)
#' @noRd
rp_measure_shift <- function(ctx, k, base = FALSE) {
  path <- paste0("measures.", k, ".delay_months")
  if (is.null(rp_raw(ctx, path))) return(rep(0, ctx$n))
  v <- if (base) ctx$value_base(path) else ctx$value(path)
  rp_shift(v %||% rep(0, ctx$n))
}

#' Aktivierungsfaktor a_k einer Maßnahme (Teil B 0.8)
#'
#' a_k = `measures.<k>.active` × Π_f `funding.<f>.approved` über alle Instrumente f mit
#' `on_reject: drop_measures`, die k fördern; ausgewertet über `ctx$value()` (n-Vektor). Eine
#' unbekannte Maßnahme hat den Faktor 1.
#' @param ctx Laufkontext.
#' @param k Maßnahmen-id.
#' @return n-Vektor.
#' @noRd
act <- function(ctx, k) {
  n <- ctx$n
  if (is.null(k) || !utl_is_string(k)) return(rep(1, n))
  a <- rep_len(rp_num(ctx, paste0("measures.", k, ".active"), rep(1, n)), n)
  for (f in names(ctx$spec$funding %||% list())) {
    fs <- ctx$spec$funding[[f]]
    if (!identical(rp_code(fs[["on_reject"]]), "drop_measures")) next
    if (!(k %in% rp_ids(fs[["measures"]]))) next
    a <- a * rep_len(rp_num(ctx, paste0("funding.", f, ".approved"), rep(1, n)), n)
  }
  a
}

# ---------------------------------------------------------------------------------------------
# Leerstand und Verluste (Teil B 1.8.4)
# ---------------------------------------------------------------------------------------------

#' Bauzeitfenster einer Maßnahme in der Wohnung (W_k) mit Minderungsausschluss (X_k)
#' @return Liste `mws`, `mc` (n-Vektoren der Monatsindizes), `a`, `alpha`, `nu`, `excl_months`.
#' @noRd
rp_works <- function(ctx, k, P, base = FALSE) {
  g <- ctx$grid
  n <- ctx$n
  ms <- ctx$spec$measures[[k]] %||% list()
  rl <- ms[["rent_law"]] %||% list()
  s <- rp_measure_shift(ctx, k, base)
  comp <- rp_measure_completion(ctx, k)
  mc <- if (is.null(comp)) rep(Inf, n) else rp_mi(g, comp) + s
  ws <- rp_as_date(rl[["works_start_date"]], g) %||% rp_measure_first_date(ctx, k) %||% comp
  mws <- if (is.null(ws)) mc else rp_mi(g, ws) + s
  a <- if (base) rep(1, n) else act(ctx, k)
  pre <- paste0("measures.", k, ".rent_law.")
  alpha <- a * rep_len(rp_num(ctx, paste0(pre, "works_rent_reduction_share"), 0), n)
  nu <- a * rep_len(rp_num(ctx, paste0(pre, "works_vacancy_share"), 0), n)
  kind <- rp_code(ms[["modernization_kind"]], "modernization_kind") %||% "none"
  excl <- if (kind %in% (P$minderung_exclusion_kinds %||% character(0))) {
    P$minderung_exclusion_months %||% 0
  } else {
    0
  }
  list(mws = mws, mc = mc, a = a, alpha = alpha, nu = nu, excl_months = excl, kind = kind)
}

#' Monatliche Belegungsfaktoren (Teil B 1.8.4)
#' @param vs_m,vr_m n x M struktureller Leerstand bzw. Leerstand durch Mieterwechsel.
#' @param lu_months n-Vektor Anlaufmonate.
#' @param mi_rs,mi_re n-Vektoren erster aktiver Monat bzw. erster inaktiver Monat.
#' @param works Liste aus `rp_works()`.
#' @return Liste `act`, `vac`, `lu`, `wv` (Π (1 − ν W)), `wm` (Π (1 − α W (1 − X))).
#' @noRd
rp_vac_core <- function(mo, n, vs_m, vr_m, lu_months, mi_rs, mi_re, works) {
  big_m <- mo$M
  mm <- matrix(as.double(mo$m), n, big_m, byrow = TRUE)
  rs <- matrix(rep_len(as.double(mi_rs), n), n, big_m)
  re <- matrix(rep_len(as.double(mi_re), n), n, big_m)
  act_m <- (mm >= rs & mm < re) * 1
  lu_n <- rp_shift(rep_len(lu_months, n))
  lu_m <- matrix(lu_n, n, big_m)
  kappa <- mm - rs + 1
  lu <- matrix(0, n, big_m)
  on <- lu_m > 0 & kappa >= 1 & kappa <= lu_m
  lu[on] <- (lu_m[on] - kappa[on] + 0.5) / lu_m[on]
  wv <- matrix(1, n, big_m)
  wm <- matrix(1, n, big_m)
  for (w in works) {
    ws <- matrix(w$mws, n, big_m)
    wc <- matrix(w$mc, n, big_m)
    wk <- (mm >= ws & mm < wc) * 1
    xk <- (mm >= ws & mm < ws + w$excl_months) * 1
    wv <- wv * (1 - matrix(w$nu, n, big_m) * wk)
    wm <- wm * (1 - matrix(w$alpha, n, big_m) * wk * (1 - xk))
  }
  vac <- 1 - (1 - vs_m) * (1 - vr_m) * wv * (1 - lu)
  list(act = act_m, vac = vac, lu = lu, wv = wv, wm = wm)
}

#' Mietrechtlich relevante Maßnahmen einer Gruppe aus der Domäne (Teil B 1.6 Nr. 4)
#' @noRd
rp_group_measures <- function(ctx, gid) {
  out <- character(0)
  for (k in names(ctx$spec$measures %||% list())) {
    ms <- ctx$spec$measures[[k]]
    kind <- rp_code(ms[["modernization_kind"]], "modernization_kind") %||% "none"
    if (identical(kind, "none")) next
    groups <- rp_ids(ms[["rent_law"]][["unit_groups"]])
    if (length(groups) == 0L || gid %in% groups) out <- c(out, k)
  }
  out
}

#' Beginn der Vermietung einer Gruppe aus der Domäne (Teil B 1.2 rent_start)
#' @noRd
rp_group_rent_start <- function(ctx, gid, construction_delay_months) {
  g <- ctx$grid
  raw <- rp_raw(ctx, paste0("unit_groups.", gid, ".rent_start"))
  if (is.null(raw)) {
    pt <- rp_code(ctx$project[["project_type"]]) %||% ""
    raw <- if (pt %in% c("neubau", "erwerb_neubau")) "completion" else g$valuation_date
  }
  if (identical(raw, "completion")) {
    return(rp_mi(g, g$completion_date) + rp_shift(rep_len(construction_delay_months, ctx$n)))
  }
  rep(rp_mi(g, rp_as_date(raw, g) %||% g$valuation_date), ctx$n)
}

#' Leerstandsanteil von Wohnungsgruppen aus Domänenpfaden (Teil B 3.6.2)
#'
#' Rechnet vac_m nach 1.8.4 (struktureller Leerstand, Mieterwechsel, Entmietung während der
#' Arbeiten, Lease-up; mit Verschiebungen und Aktivierungsfaktor) je Gruppe aus der Domäne,
#' mittelt ihn je Periode über die aktiven Monate und gewichtet die Gruppen mit ihrer Fläche. Das
#' Ergebnis ist mit `aux$vacant_share` der Mietkomponenten identisch, hängt aber nicht von ihnen
#' ab (kein Zyklus über die warmmietenneutrale Umlage).
#' @param ctx Laufkontext.
#' @param ids ids der vermieteten Gruppen.
#' @param construction_delay_months n-Vektor (Verschiebung beim Token `completion`).
#' @return n x (T+1); ohne Gruppen 0.
#' @noRd
rp_vacancy_share <- function(ctx, ids, construction_delay_months = rep(0, ctx$n)) {
  n <- ctx$n
  ids <- rp_ids(ids)
  if (length(ids) == 0L) return(ctx$zeros())
  g <- ctx$grid
  mo <- rp_months(g)
  P <- ctx$rule("mr_params")(ctx$legal("mietrecht"), ctx$legal("mietrecht_559f"))
  num <- 0
  den <- 0
  for (gid in ids) {
    pre <- paste0("unit_groups.", gid, ".")
    area <- rep_len(rp_num(ctx, paste0(pre, "living_area_m2"), 1), n)
    vs <- rp_num(ctx, paste0(pre, "vacancy_rate"), ctx$zeros(), "path")
    tr <- rp_num(ctx, paste0(pre, "turnover_rate_pa"), ctx$zeros(), "path")
    relet <- rep_len(rp_num(ctx, paste0(pre, "relet_vacancy_months"), 0), n)
    lu <- rep_len(rp_num(ctx, paste0(pre, "lease_up_months"), 0), n)
    mi_rs <- rp_group_rent_start(ctx, gid, construction_delay_months)
    re <- rp_as_date(rp_raw(ctx, paste0(pre, "rent_end")), g)
    mi_re <- if (is.null(re)) rep(Inf, n) else rep(rp_mi(g, re), n)
    works <- lapply(rp_group_measures(ctx, gid), function(k) rp_works(ctx, k, P))
    vr <- rp_period_months(mo, tr) * matrix(relet, n, mo$M) / 12
    core <- rp_vac_core(mo, n, rp_period_months(mo, vs), vr, lu, mi_rs, mi_re, works)
    vsh <- rp_active_mean(ctx, core$vac, core$act)
    num <- num + vsh * area
    den <- den + area
  }
  num / den
}

#' Mittel einer Monatsgröße über die aktiven Monate je Periode (0 ohne aktive Monate)
#' @noRd
rp_active_mean <- function(ctx, x_m, act_m) {
  s <- ctx$to_periods(x_m * act_m)
  d <- ctx$to_periods(act_m)
  out <- s / pmax(d, 1)
  out[d <= 0] <- 0
  out[, 1L] <- 0
  out
}

# ---------------------------------------------------------------------------------------------
# Eingaben der Komponente (Teil B 1.7, 1.8.1)
# ---------------------------------------------------------------------------------------------

#' Parameter, Rechtsstand und Monatspfade einer Mietkomponente
#' @noRd
rp_inputs <- function(spec, ctx) {
  g <- ctx$grid
  n <- ctx$n
  mo <- rp_months(g)
  big_m <- mo$M
  notes <- character(0)
  P <- ctx$rule("mr_params")(ctx$legal("mietrecht"), ctx$legal("mietrecht_559f"))
  if (!isTRUE(P$active)) notes <- c(notes, "types.flow.rent_path.msg.topic_inactive")
  set <- function(nm) ctx$setting(spec, nm)
  par <- function(nm, shape = "scalar") ctx$param(spec, nm, shape)
  path_or <- function(nm, default) {
    v <- par(nm, "path")
    if (is.null(v)) ctx$by_sim(default) else v
  }
  gid <- set("unit_group") %||% "g"
  regime <- set("rent_regime") %||% "paragraph_558"
  policy <- set("increase_policy") %||% "auto"
  ovm0 <- par("ovm_eur_m2_month")
  if (identical(policy, "auto")) policy <- if (is.null(ovm0)) "fixed_growth" else "max"
  ovm_policy <- policy %in% c("max", "interval", "capped")
  area <- rep_len(par("living_area_m2"), n)
  r0 <- rep_len(par("rent_eur_m2_month"), n)
  rs <- ctx$timing(spec, "rent_start") %||% list(date = g$valuation_date, shift = rep(0, n))
  mi_rs <- rp_mi(g, rs$date) + rp_shift(rep_len(rs$shift, n))
  re <- ctx$timing(spec, "rent_end")
  mi_re <- if (is.null(re)) rep(Inf, n) else rp_mi(g, re$date) + rp_shift(rep_len(re$shift, n))
  # Steigerung (fixed_growth) und Wachstum der Vergleichsmiete: Kalenderjahressätze je Monat
  growth <- path_or("rent_growth", 0)
  g_m <- rp_year_months(g, mo, growth)
  gf <- set("growth_from")
  mi_gf <- if (!is.null(gf)) {
    rep(rp_mi(g, gf), n)
  } else {
    first <- mi_rs + 12
    moy_first <- (utl_month(g$valuation_date) - 1 + first - 1) %% 12 + 1
    first + (1 - moy_first) %% 12
  }
  # Kappungsgrenze § 558 Abs. 3
  kap <- par("kappung_rate")
  if (is.null(kap)) {
    kap15 <- isTRUE(set("kappung_15_area"))
    kap <- if (kap15) P$kappung_rate_15 %||% P$kappung_rate_default else P$kappung_rate_default
    kap <- kap %||% Inf
  }
  kap <- rep_len(kap, n)
  # Vergleichsmiete, Marktmiete
  li_g <- rp_log_index(g_m, growth[, min(2L, ncol(growth))])
  ovm_base <- set("ovm_base_date") %||% g$valuation_date
  m0_ovm <- rp_mi(g, ovm_base) - 1
  mkt0 <- par("market_rent_eur_m2_month")
  mkt_m <- NULL
  if (!is.null(mkt0)) {
    mg <- path_or("market_rent_growth", 0)
    li_mkt <- rp_log_index(rp_year_months(g, mo, mg), mg[, min(2L, ncol(mg))])
    mkt_base <- set("market_rent_base_date") %||% g$valuation_date
    mkt_m <- rp_level_path(li_mkt, rep_len(mkt0, n), rp_mi(g, mkt_base) - 1)
  }
  turnover <- path_or("turnover_rate_pa", 0)
  turnover_m <- rp_period_months(mo, turnover)
  fluct <- !is.null(mkt_m)
  turnover_no_market <- if (is.null(mkt_m)) rowSums(turnover > 0) > 0 else rep(FALSE, n)
  # Phasen (deterministisch)
  phase <- rep("p558", big_m)
  staffel <- NULL
  mb_end <- NA_real_
  if (identical(regime, "staffel")) {
    node <- spec[["staffel_steps"]]
    dates <- if (is.list(node) && identical(node$kind, "schedule")) as.Date(node$dates) else
      as.Date(character(0))
    vals <- par("staffel_steps", "path")
    if (length(dates) > 0L && !is.null(vals)) {
      per <- grid_period_of(g, dates)
      keep <- !is.na(per) & dates > g$valuation_date
      dates <- dates[keep]
      per <- per[keep]
      ord <- order(dates)
      dates <- dates[ord]
      per <- per[ord]
      staffel <- list(months = rp_mi(g, dates),
                      values = vals[, per + 1L, drop = FALSE])
      last_m <- if (length(dates) > 0L) max(staffel$months) else -Inf
    } else {
      last_m <- -Inf
    }
    after <- if (identical(set("after_staffel_regime"), "index")) "index" else "p558"
    phase[] <- after
    phase[mo$m < last_m + 12] <- "staffel"
  } else if (identical(regime, "bound_social")) {
    be <- ctx$timing(spec, "binding_end")
    mb_end <- if (is.null(be)) Inf else rp_mi(g, be$date)
    after <- if (identical(set("after_binding_regime"), "index")) "index" else "p558"
    phase[] <- after
    phase[mo$m < mb_end] <- "bound"
  } else if (identical(regime, "index")) {
    phase[] <- "index"
  }
  idx_rate <- path_or("index_rate", 0)
  idx_prev_m <- idx_rate[, rp_year_col(g, mo$year - 1L), drop = FALSE]
  bip <- path_or("bound_increase_pa", 0)
  # Verluste
  vs <- path_or("vacancy_rate", 0)
  def_rate <- path_or("rent_default_rate", 0)
  extra <- path_or("extra_loss_share", 0)
  hard <- path_or("hardship_share", 0)
  relet <- rep_len(par("relet_vacancy_months") %||% 0, n)
  lease_up <- rep_len(par("lease_up_months") %||% 0, n)
  # Mietpreisbremse
  pt <- rp_code(ctx$project[["project_type"]]) %||% ""
  first_use <- set("first_use_after_2014_10_01")
  if (is.null(first_use)) {
    cy <- suppressWarnings(as.double(mr_num(ctx$building[["construction_year"]]) %||% NA))
    first_use <- pt %in% c("neubau", "erwerb_neubau") || (!is.na(cy) && cy >= 2015)
  }
  month_dates <- grid_add_months(rep(g$valuation_date, big_m), mo$m - 1L)
  # Auslegungen: Default ist der Rechtsstand
  interp <- list(
    attribution = set("drittmittel_attribution") %||% (P$attribution[1L] %||% "full"),
    flat_order = set("flat_559e_order") %||% (P$flat_559e_order[1L] %||% "flat_before_funds"),
    hp_order = set("hp_reduction_order") %||% (P$hp_order[1L] %||% "halve_then_funds"),
    section43_flat = set("section43_flat") %||% (P$section43_flat %||% FALSE),
    hp_inclusive = set("hp_threshold_inclusive"),
    interest_in_559e = set("interest_subsidy_in_559e") %||% TRUE,
    kuerzung = set("kuerzung_558_5") %||% TRUE
  )
  kgy <- par("kuerzung_grant_years") %||% rep(P$kuerzung_grant_years %||% 0, n)
  kly <- par("kuerzung_loan_years")
  led <- set("levy_effective_delay_months") %||% (P$levy_effective_delay_months %||% 3)
  last558 <- set("last_558_increase_date") %||% grid_add_months(g$valuation_date, -12L)
  list(
    grid = g, n = n, mo = mo, M = big_m, P = P, notes = notes, gid = gid, regime = regime,
    turnover_no_market = turnover_no_market,
    policy = policy, ovm_policy = ovm_policy, area = area, r0 = r0, mi_rs = mi_rs,
    mi_re = mi_re,
    g_m = g_m, mi_gf = mi_gf, applies_to = set("growth_applies_to") %||% "total",
    kap = kap, ovm0 = ovm0, li_g = li_g, m0_ovm = m0_ovm, mkt_m = mkt_m, fluct = fluct,
    turnover_m = turnover_m, phase = phase, staffel = staffel, mb_end = mb_end,
    idx_prev_m = idx_prev_m, index_month = set("index_adjust_month") %||% 1L,
    index_cap_area = isTRUE(set("index_cap_area")),
    index_min = P$index_min_months %||% 12, bip_m = rp_year_months(g, mo, bip),
    post_binding_kappung = isTRUE(set("post_binding_kappung")),
    vs_m = rp_period_months(mo, vs), def_m = rp_period_months(mo, def_rate),
    extra_m = rp_period_months(mo, extra), hard_m = rp_period_months(mo, hard),
    relet = relet, lease_up = lease_up,
    brake_area = isTRUE(set("brake_area")), brake_until = set("brake_until"),
    first_use = isTRUE(first_use), month_dates = month_dates,
    interval = set("interval_months") %||% 36L,
    vshare = par("voluntary_558_cap_share"),
    cm = set("voluntary_558_cap_months") %||% 36L,
    rent36 = rep_len(par("rent_36m_ago_eur_m2_month") %||% r0, n),
    m_last0 = min(rp_mi(g, last558), 0),
    levy_mode = set("modernization_levy") %||% "auto",
    cap_mode = set("voluntary_cap_mode") %||% "fixed",
    interp = interp, kgy = rep_len(kgy, n), kly = if (is.null(kly)) NULL else rep_len(kly, n),
    levy_delay = as.double(led), n_units = set("n_units") %||% 1L
  )
}

# ---------------------------------------------------------------------------------------------
# Maßnahmen: Umlage, Kürzung, Bauzeit (Teil B 1.9, 1.10)
# ---------------------------------------------------------------------------------------------

#' Summe der Zeilen von Abhängigkeiten über alle Perioden (n-Vektor)
#' @noRd
rp_rows_total <- function(ctx, ids, category, k) {
  ids <- rp_ids(ids)
  if (length(ids) == 0L) return(NULL)
  rows <- ctx$rows(id = ids, category = category, measure_id = k)
  if (length(rows) == 0L) return(NULL)
  rowSums(Reduce(`+`, rows))
}

#' Zustand eines Energieblocks (before, after oder stages.<s>) als Pfadpräfix
#' @noRd
rp_state_path <- function(state) {
  if (state %in% c("before", "after")) paste0("energy.", state) else
    paste0("energy.stages.", state)
}

#' Energiezustand mit `measure: k`
#' @noRd
rp_state_of_measure <- function(ctx, k) {
  en <- ctx$spec$energy %||% list()
  for (s in c("before", "after")) {
    if (identical(rp_code(en[[s]][["measure"]]), k)) return(s)
  }
  for (s in names(en[["stages"]] %||% list())) {
    if (identical(rp_code(en[["stages"]][[s]][["measure"]]), k)) return(s)
  }
  NULL
}

#' Wärmepumpenträger eines Zustands (heat_pump_carrier bzw. einziger Träger der Klasse power_hp)
#' @noRd
rp_hp_carrier <- function(ctx, state) {
  if (is.null(state)) return(NULL)
  st <- rp_raw(ctx, rp_state_path(state)) %||% list()
  hc <- rp_code(st[["heat_pump_carrier"]])
  if (!is.null(hc)) return(hc)
  carriers <- c(names(st[["carrier_shares"]] %||% list()), rp_code(st[["heating_carrier"]]))
  hp <- Filter(function(c) {
    identical(rp_code(rp_raw(ctx, paste0("energy.carriers.", c, ".class"))), "power_hp") ||
      grepl("^heatpump_power", c)
  }, unique(carriers))
  if (length(hp) == 1L) hp else NULL
}

#' Klassen der Wärmeträger eines Zustands (Teil B 3.2.2)
#'
#' Träger aus `carrier_shares` mit Anteil > 0 (kanonische Form, Default `{<heating_carrier>: 1}`)
#' bzw. `heating_carrier`; je Träger die Klasse aus `energy.carriers.<c>.class`. Ein Zustand ohne
#' eigene Trägerangabe hat keine neue Heizung (leeres Ergebnis).
#' @param sp Pfadpräfix des Zustands (`energy.after`, `energy.stages.<s>`).
#' @return Zeichenvektor der Klassen (ohne fehlende).
#' @noRd
rp_state_heating_classes <- function(ctx, sp) {
  st <- rp_raw(ctx, sp) %||% list()
  shares <- st[["carrier_shares"]]
  carriers <- character(0)
  if (is.list(shares) && length(shares) > 0L) {
    for (cr in names(shares)) {
      v <- mr_num(shares[[cr]])
      if (is.null(v) || isTRUE(v[1L] > 0)) carriers <- c(carriers, cr)
    }
  }
  hc <- rp_code(st[["heating_carrier"]])
  if (!is.null(hc)) carriers <- c(carriers, hc)
  cls <- vapply(unique(carriers), function(cr) {
    rp_code(rp_raw(ctx, paste0("energy.carriers.", cr, ".class"))) %||% NA_character_
  }, "")
  unname(cls[!is.na(cls)])
}

#' Daten einer mietrechtlich relevanten Maßnahme k für die Gruppe (Teil B 1.9.1-1.9.4, 1.10)
#' @noRd
rp_measure <- function(spec, ctx, inp, k, levy_rows, cost_ids, grant_ids, funding_ids) {
  g <- inp$grid
  n <- inp$n
  P <- inp$P
  zero <- ctx$tol$zero_abs
  ms <- ctx$spec$measures[[k]] %||% list()
  rl <- ms[["rent_law"]] %||% list()
  pre <- paste0("measures.", k, ".")
  kind <- rp_code(ms[["modernization_kind"]], "modernization_kind") %||% "none"
  w <- rp_works(ctx, k, P)
  a <- w$a
  s <- rp_measure_shift(ctx, k)
  s_base <- rp_measure_shift(ctx, k, base = TRUE)
  comp <- rp_measure_completion(ctx, k)
  # Kosten (realisiert, inkl. Index und Verschiebung) und Ohnehin-Anteil
  k0 <- rep_len(rp_num(ctx, paste0(pre, "cost_eur"), 0), n)
  kc <- rp_rows_total(ctx, cost_ids, "capex", k)
  cost <- if (is.null(kc)) a * k0 else -kc
  rho <- ifelse(k0 > 0, cost / pmax(k0, 1e-300), 1)
  o_cost <- rp_num(ctx, paste0(pre, "ohnehin_cost_eur"))
  o <- if (!is.null(o_cost)) {
    ifelse(k0 > 0, rep_len(o_cost, n) / pmax(k0, 1e-300), 0)
  } else {
    rep_len(rp_num(ctx, paste0(pre, "ohnehin_share"), 0), n)
  }
  o <- pmin(pmax(o, 0), 1)
  method <- rp_code(rl[["maintenance_share_method"]], "maintenance_method") %||% "auto"
  age <- rp_num(ctx, paste0(pre, "rent_law.component_age_years"))
  if (identical(method, "auto")) method <- if (!is.null(age)) "linear_wear" else "ohnehin"
  ih <- switch(method,
    ohnehin = o * cost,
    linear_wear = {
      fict <- rp_num(ctx, paste0(pre, "rent_law.fictitious_maintenance_cost_eur")) %||% (o * k0)
      life <- rp_num(ctx, paste0(pre, "rent_law.component_life_years")) %||%
        rp_num(ctx, paste0(pre, "useful_life_years"), rep(Inf, n))
      rep_len(fict, n) * rho * pmin(1, rep_len(age %||% 0, n) / pmax(rep_len(life, n), 1e-9))
    },
    fixed_share = rep_len(rp_num(ctx, paste0(pre, "rent_law.maintenance_share"), 0), n) * cost,
    rep(0, n)
  )
  # Kostenanteil der Gruppe (lambda)
  lam <- rp_num(ctx, paste0(pre, "rent_law.allocation.", inp$gid))
  if (is.null(lam)) {
    groups <- rp_ids(rl[["unit_groups"]])
    if (length(groups) == 0L) groups <- names(ctx$spec$unit_groups %||% list())
    if (inp$gid %in% groups && length(groups) > 1L) {
      areas <- lapply(groups, function(x) {
        rep_len(rp_num(ctx, paste0("unit_groups.", x, ".living_area_m2"), 0), n)
      })
      tot <- Reduce(`+`, areas)
      own <- areas[[match(inp$gid, groups)]]
      lam <- ifelse(tot > 0, own / pmax(tot, 1e-300), 0)
    } else {
      lam <- rep(1, n)
    }
  }
  lam <- rep_len(lam, n)
  # Drittmittel: Zuschüsse, Tilgungszuschuss, Zinsermäßigung (§ 559a)
  grants <- rp_rows_total(ctx, grant_ids, "grant", k) %||% rep(0, n)
  tz <- rep(0, n)
  zint <- rep(0, n)
  kz_loan <- list()
  mc <- w$mc
  per_mc <- pmin(pmax(utl_month_period(g, pmin(pmax(mc, 1), inp$M)), 1L), g$T)
  for (f in rp_ids(funding_ids)) {
    fs <- ctx$spec$funding[[f]] %||% list()
    fm <- rp_ids(fs[["measures"]])
    if (!(k %in% fm)) next
    if (identical(rp_code(fs[["rent_law"]][["loan_counts_as"]]), "none")) next
    itype <- rp_code(fs[["instrument_type"]]) %||% "loan"
    costs_f <- lapply(fm, function(j) {
      if (identical(j, k)) return(cost)
      kj <- rp_rows_total(ctx, cost_ids, "capex", j)
      if (is.null(kj)) {
        act(ctx, j) * rep_len(rp_num(ctx, paste0("measures.", j, ".cost_eur"), 0), n)
      } else {
        -kj
      }
    })
    tot_f <- Reduce(`+`, costs_f)
    wfk <- ifelse(tot_f > 0, cost / pmax(tot_f, 1e-300), 1 / length(fm))
    ref_path <- paste0("funding.", f, ".rent_law.reference_rate_pa")
    iref <- rp_num(ctx, ref_path, NULL, "path") %||% ctx$market("mortgage_rate")
    iref_mc <- iref[cbind(seq_len(n), per_mc + 1L)]
    if (identical(itype, "interest_subsidy")) {
      ip <- paste0("funding.", f, ".interest_subsidy.")
      zf <- rep_len(rp_num(ctx, paste0(ip, "subsidized_amount_eur"), 0), n) *
        rep_len(rp_num(ctx, paste0(ip, "rate_reduction_pa"), 0), n) *
        rep_len(rp_num(ctx, paste0("funding.", f, ".approved"), 1), n)
      st <- rp_as_date(rp_raw(ctx, paste0(ip, "start_event")), g)
      ml <- if (is.null(st)) mc else rep(rp_mi(g, st), n)
      yrs <- inp$kly %||% rep_len(rp_num(ctx, paste0(ip, "years"), Inf), n)
    } else {
      lp <- paste0("financing.f_", f, "_loan.")
      d_f <- rep_len(ctx$value_base(paste0(lp, "amount_eur")) %||% 0, n)
      appr <- rep_len(rp_num(ctx, paste0(lp, "approved"), 1), n)
      l_f <- d_f * appr
      i_f <- rep_len(rp_num(ctx, paste0(lp, "rate_pa"), 0), n)
      zf <- l_f * pmax(iref_mc - i_f, 0)
      if (isTRUE(P$repayment_grant_as_grant)) {
        rg <- paste0(lp, "repayment_grant.")
        rg_amt <- rp_num(ctx, paste0(rg, "amount_eur"))
        rg_share <- rp_num(ctx, paste0(rg, "share"))
        base_tz <- if (!is.null(rg_amt)) rep_len(rg_amt, n) * appr else
          rep_len(rg_share %||% 0, n) * l_f
        tz_f <- base_tz * rep_len(rp_num(ctx, paste0(rg, "approved"), 1), n) *
          (1 - rep_len(rp_num(ctx, paste0(rg, "cut_share"), 0), n))
        tz <- tz + a * wfk * tz_f
      }
      st <- rp_as_date(rp_raw(ctx, paste0(lp, "start")), g)
      ml <- if (is.null(st)) rep(1, n) else rep(rp_mi(g, st), n)
      yrs <- inp$kly %||% rep_len(rp_num(ctx, paste0(lp, "fixed_years"), Inf), n)
    }
    zint <- zint + a * wfk * zf
    kz_loan[[length(kz_loan) + 1L]] <- list(amount = a * wfk * zf, from = ml, years = yrs)
  }
  # § 559f: Halbierung (Plan-JAZ als Basisfallwert)
  hp_state <- rp_code(rl[["hp_state"]]) %||% rp_state_of_measure(ctx, k)
  hp_flag <- rl[["heat_pump"]]
  heat_pump <- if (is.null(hp_flag)) !is.null(rp_hp_carrier(ctx, hp_state)) else rp_lgl(hp_flag)
  hv <- rep(0, n)
  jaz_plan_missing <- FALSE
  if (heat_pump && isTRUE(P$active_559f)) {
    jp <- NA_real_
    vt <- NA_real_
    if (!is.null(hp_state)) {
      sp <- rp_state_path(hp_state)
      jp <- mr_num(rp_raw(ctx, paste0(sp, ".jaz_plan")))
      if (is.null(jp)) {
        jaz_plan_missing <- TRUE
        jp <- if (is.null(rp_raw(ctx, paste0(sp, ".jaz")))) NA_real_ else
          ctx$value_base(paste0(sp, ".jaz"))[1L]
      }
      vt <- mr_num(rp_raw(ctx, paste0(sp, ".flow_temperature_c"))) %||% NA_real_
    }
    cy <- mr_num(ctx$building[["construction_year"]]) %||% NA_real_
    hv <- rep_len(ctx$rule("mr_hp_halving")(
      TRUE, jp[1L], vt[1L], cy[1L], rp_code(rl[["hp_exception"]], "hp_exception") %||% "auto",
      inp$interp$hp_inclusive %||% NA, P
    ), n)
  }
  # § 43 GModG (keine 15-%-Pauschale in § 559e)
  s43h <- rl[["section43_heating"]]
  if (is.null(s43h)) {
    st_name <- rp_state_of_measure(ctx, k)
    s43h <- FALSE
    if (!is.null(st_name)) {
      sp <- rp_state_path(st_name)
      raw43 <- rp_raw(ctx, paste0(sp, ".section43"))
      if (!is.null(raw43)) {
        s43h <- rp_lgl(raw43)
      } else {
        # Wärmeträger des Zustands: carrier_shares (kanonisch, 3.2.2) bzw. heating_carrier
        cls <- rp_state_heating_classes(ctx, sp)
        if (length(cls) > 0L && !is.null(comp)) {
          pc <- ctx$rule("co2_params")(ctx$legal("co2kostaufg"), ctx$legal("bio_treppe"))
          inst <- rp_as_date(rp_raw(ctx, paste0(sp, ".installation_date")), g) %||% comp
          existing <- !((rp_code(ctx$project[["project_type"]]) %||% "") %in%
                          c("neubau", "erwerb_neubau"))
          s43h <- any(ctx$rule("co2_section43")(cls, rep(inst, length(cls)),
                                                rep(existing, length(cls)), pc))
        }
      }
    }
  }
  s43 <- rp_lgl(s43h) && !isTRUE(inp$interp$section43_flat)
  # Verfahren und Jahresbeträge je Verfahren
  rule_annual <- ctx$rule("mr_levy_annual")
  ann <- function(proc) {
    rule_annual(proc, cost, ih, grants, tz, zint, inp$interp$attribution, hv,
                inp$interp$hp_order, inp$interp$flat_order, s43,
                isTRUE(inp$interp$interest_in_559e), P)
  }
  u_by <- list(bgb_559 = ann("bgb_559"), bgb_559c = ann("bgb_559c"), bgb_559e = ann("bgb_559e"))
  dm <- (grants + tz + zint) > zero
  proc_set <- rp_code(rl[["procedure"]], "levy_procedure") %||% "auto"
  fundable <- rp_lgl(rl[["fundable_in_principle"]], TRUE)
  proc <- if (identical(proc_set, "auto")) {
    ifelse(kind == "bgb_555b_1a" & fundable & dm, "bgb_559e", "bgb_559")
  } else {
    rep(proc_set, n)
  }
  # Rückfall auf § 559 (I): § 559e verlangt, bzw. bei auto grundsätzlich förderfähig, aber ohne
  # in Anspruch genommene Drittmittel (Förderung fällt aus, Konzept 3.5)
  fallback_559e <- (proc == "bgb_559e" |
                      (identical(proc_set, "auto") & kind == "bgb_555b_1a" & fundable)) & !dm
  proc[fallback_559e] <- "bgb_559"
  hs <- rep_len(rp_num(ctx, paste0(pre, "rent_law.heating_part_share"),
                       if (identical(kind, "bgb_555b_1a")) 1 else 0), n)
  # Wirksamkeit (1.9.4)
  eff <- rp_as_date(rl[["levy_effective_date"]], g)
  decl <- rp_as_date(rl[["declaration_date"]], g) %||% comp
  defect <- if (rp_lgl(rl[["announcement_ok"]], TRUE)) 0 else (P$levy_delay_defective_months %||% 6)
  if (!is.null(eff)) {
    me <- rep(rp_mi(g, eff), n)
    me_base <- me[1L]
  } else if (!is.null(decl)) {
    base_m <- rp_mi_floor(g, decl) + inp$levy_delay + defect
    me <- base_m + s
    me_base <- base_m + s_base[1L]
  } else {
    me <- rep(Inf, n)
    me_base <- Inf
  }
  levy <- k %in% levy_rows && identical(inp$levy_mode, "auto") &&
    identical(rp_code(rl[["levy"]], "levy_mode") %||% "auto", "auto")
  # Kürzungsbeträge § 558 Abs. 5 (EUR/m²·Monat der Gruppe je Monat)
  kz <- NULL
  if (inp$ovm_policy && isTRUE(inp$interp$kuerzung) && isTRUE(P$active)) {
    mm <- matrix(as.double(inp$mo$m), n, inp$M, byrow = TRUE)
    fac <- lam / (12 * inp$area)
    gr_amt <- (P$kuerzung_rate_grant %||% 0) * (grants + tz)
    win <- (mm >= matrix(mc, n, inp$M) & mm < matrix(mc + 12 * inp$kgy, n, inp$M)) * 1
    kz <- win * matrix(fac * gr_amt, n, inp$M)
    for (kl in kz_loan) {
      wl <- (mm >= matrix(kl$from, n, inp$M) & mm < matrix(kl$from + 12 * kl$years, n, inp$M))
      kz <- kz + wl * matrix(fac * kl$amount, n, inp$M)
    }
  }
  uplift <- rep_len(rp_num(ctx, paste0(pre, "rent_law.ovm_uplift_eur_m2_month"), 0), n)
  list(
    id = k, kind = kind, levy = levy, a = a, s = s, mc = mc, me = me, me_base = me_base,
    works = w, lambda = lam, cost = cost, maintenance = ih, grants = grants, tz = tz,
    zint = zint, hv = hv, s43 = s43, u_by = u_by, proc = proc, hs = hs, dm = dm,
    fallback_559e = fallback_559e,
    landlord = rp_lgl(rl[["landlord_responsible"]], !identical(kind, "bgb_555b_6")),
    c559 = cost * lam, uses_559c = any(proc == "bgb_559c"), kz = kz, uplift = uplift,
    comprehensive = rp_lgl(rl[["comprehensive_modernization"]], FALSE),
    heat_pump = heat_pump, jaz_plan_missing = jaz_plan_missing,
    hp_state_missing = heat_pump && is.null(hp_state) && isTRUE(P$active_559f)
  )
}

#' Kappung des Heizungsanteils, Gesamtkappe und freiwillige Obergrenze für gleichzeitig wirksame
#' Umlagen (Teil B 1.8.2 (e), 1.9.5; Reihenfolge F14)
#'
#' @param u n x K Umlagen je m² vor Kappung (0 für Maßnahmen ohne Ereignis).
#' @param hs n x K Heizungsanteile.
#' @param rent_before n-Vektor Miete vor der Erhöhung (B + Σ L).
#' @param prior_6y,prior_heat_6y n-Vektoren der Vorumlagen im Kappungsfenster.
#' @param vcap n-Vektor freiwillige Obergrenze der kumulierten Umlagen (Inf = keine).
#' @param levy_sum n-Vektor bisherige Umlagen Σ L.
#' @param P Rechtsparameter.
#' @param cap_total,cap_heating Regeln `mr_levy_cap_total`, `mr_levy_cap_heating`.
#' @return Liste `l` (angesetzt), `capped` (nach Kappungen, vor Obergrenze), `heat`
#'   (angesetzter Heizungsanteil), `binding` (Kappung bindet).
#' @noRd
rp_levy_caps <- function(u, hs, rent_before, prior_6y, prior_heat_6y, vcap, levy_sum, P,
                         cap_total = mr_levy_cap_total, cap_heating = mr_levy_cap_heating) {
  h <- u * hs
  big_h <- rowSums(h)
  big_n <- rowSums(u - h)
  room_t <- cap_total(rent_before, prior_6y, P)
  room_h <- cap_heating(prior_heat_6y, P)
  sh <- ifelse(big_h > 0, pmin(1, room_h / pmax(big_h, 1e-300)), 1)
  tot <- big_n + sh * big_h
  st <- ifelse(tot > 0, pmin(1, room_t / pmax(tot, 1e-300)), 1)
  capped <- ((u - h) + h * sh) * st
  lsum <- rowSums(capped)
  room_v <- pmax(vcap - levy_sum, 0)
  sv <- ifelse(lsum > 0, pmin(1, room_v / pmax(lsum, 1e-300)), 1)
  list(l = capped * sv, capped = capped, heat = h * sh * st * sv,
       binding = (sh < 1 | st < 1) & (big_h + big_n) > 0)
}

# ---------------------------------------------------------------------------------------------
# Monatsschleife (Teil B 1.8.2)
# ---------------------------------------------------------------------------------------------

#' Mietvertrag einer Einheit (Gruppe bzw. Wohnung der Mieterliste) monatlich rechnen
#' @param unit Liste `area`, `r0`, `rent36`, `m_last0`, `hist`, `lam_rel`, `n_we`.
#' @return Liste mit Monatsmatrizen `B`, `L` (Liste je Maßnahme) und Hilfsgrößen je Periode.
#' @noRd
rp_simulate <- function(ctx, inp, meas, unit, vcap) {
  n <- inp$n
  big_m <- inp$M
  P <- inp$P
  g <- inp$grid
  mo <- inp$mo
  nk <- length(meas)
  win6 <- (P$cap_window_months %||% 72) - 1
  off <- as.integer(max(73, win6 + 2, inp$cm + 1, 37, (P$lookback_559c_months %||% 0) + 1,
                        (P$block_559c_months %||% 0) + 1))
  ncol_h <- big_m + off
  ix <- function(m) m + off
  t_hist <- matrix(0, n, ncol_h)
  inc <- matrix(0, n, ncol_h)
  inc_h <- matrix(0, n, ncol_h)
  hm <- seq.int(1L - off, 0L)
  m_last0 <- unit$m_last0
  t_hist[, ix(hm)] <- unit$rent36
  last559c <- rep(-Inf, n)
  for (h in unit$hist) {
    if (is.finite(h$mi) && h$mi >= 1 - off && h$mi <= 0) {
      inc[, ix(h$mi)] <- inc[, ix(h$mi)] + h$value
      if (h$heating) inc_h[, ix(h$mi)] <- inc_h[, ix(h$mi)] + h$value
    }
    cols <- hm[hm >= h$mi & hm < m_last0]
    if (length(cols) > 0L) t_hist[, ix(cols)] <- t_hist[, ix(cols)] + h$value
    if (identical(h$procedure, "bgb_559c")) last559c <- pmax(last559c, h$mi)
  }
  late <- hm[hm >= m_last0]
  if (length(late) > 0L) t_hist[, ix(late)] <- unit$r0
  cum <- matrix(0, n, ncol_h + 1L)
  cum_h <- matrix(0, n, ncol_h + 1L)
  for (cc in seq_len(off)) {
    cum[, cc + 1L] <- cum[, cc] + inc[, cc]
    cum_h[, cc + 1L] <- cum_h[, cc] + inc_h[, cc]
  }
  csum <- function(cm, m) cm[, ix(m) + 1L]
  any_559c <- any(vapply(meas, function(x) isTRUE(x$uses_559c), logical(1)))
  c559 <- if (any_559c) matrix(0, n, ncol_h) else NULL
  kz_m <- NULL
  for (x in meas) if (!is.null(x$kz)) kz_m <- if (is.null(kz_m)) x$kz else kz_m + x$kz
  ovm_m <- inp[["ovm_m"]]
  b <- unit$r0
  lev <- matrix(0, n, nk)
  m_last <- rep(m_last0, n)
  m_last_idx <- inp$mi_rs
  fab <- rep(identical(inp$regime, "bound_social"), n)
  proc_rec <- matrix("none", n, max(nk, 1L))
  b_m <- matrix(0, n, big_m)
  l_m <- lapply(seq_len(nk), function(i) matrix(0, n, big_m))
  n_t <- g$T + 1L
  aux_k <- lapply(seq_len(nk), function(i) {
    list(computed = matrix(0, n, n_t), capped = matrix(0, n, n_t), charged = matrix(0, n, n_t),
         procedure = matrix(0, n, n_t), binding = rep(FALSE, n), proc = rep("none", n),
         limit_559c = rep(FALSE, n), locked = rep(FALSE, n), not_allowed = rep(FALSE, n))
  })
  levy_idx <- which(vapply(meas, function(x) isTRUE(x$levy), logical(1)))
  staffel_absorb <- rep(FALSE, n)
  rule_allowed <- ctx$rule("mr_levy_allowed")
  rule_cap_t <- ctx$rule("mr_levy_cap_total")
  rule_cap_h <- ctx$rule("mr_levy_cap_heating")
  rule_target <- ctx$rule("mr_558_target")
  rule_index <- ctx$rule("mr_index_adjustment")
  rule_brake <- ctx$rule("mr_brake_applies")
  rule_relet <- ctx$rule("mr_relet_rent")
  proc_code <- c(none = 0, bgb_559 = 1, bgb_559c = 2, bgb_559e = 3)
  relet_procs <- P$relet_levy_procedures %||% character(0)
  mpb <- P$mpb_modernization_months %||% 36
  limit_559c <- P$limit_559c_per_unit %||% Inf
  block_559c <- P$block_559c_months %||% 0
  look_559c <- P$lookback_559c_months %||% 0
  for (m in seq_len(big_m)) {
    ph <- inp$phase[m]
    lsum <- if (nk > 0L) rowSums(lev) else rep(0, n)
    if (m > 1L && ph == "index" && inp$phase[m - 1L] != "index") {
      m_last_idx[] <- m - inp$index_min
    }
    # (a) Staffel
    # Bekannte Einschränkung (Spec-Befund, Änderungsantrag zu 1.8.2 (a)): Die Staffelstufe setzt
    # die Gesamtmiete; eine während der Staffel zulässige Umlage (§ 559e) wird dabei aufgezehrt.
    if (ph == "staffel" && !is.null(inp$staffel)) {
      sidx <- match(m, inp$staffel$months)
      if (!is.na(sidx)) {
        staffel_absorb <- staffel_absorb | lsum > 1e-12
        b <- inp$staffel$values[, sidx] - lsum
      }
    }
    # (b) Index
    if (ph == "index" && mo$moy[m] == inp$index_month) {
      ok <- (m - m_last_idx) >= inp$index_min
      infl <- rule_index(inp$idx_prev_m[, m], inp$index_cap_area, P)
      b <- ifelse(ok, b * (1 + infl), b)
      m_last_idx[ok] <- m
    }
    # (c) Bindung
    if (ph == "bound" && mo$moy[m] == 1L) {
      ok <- m >= inp$mi_rs + 12
      b <- ifelse(ok, b * (1 + inp$bip_m[, m]), b)
    }
    # (d) feste Steigerung
    if (ph == "p558" && identical(inp$policy, "fixed_growth")) {
      ok <- m >= inp$mi_gf & ((m - inp$mi_gf) %% 12 == 0)
      f <- 1 + inp$g_m[, m]
      b_new <- if (identical(inp$applies_to, "base")) b * f else (b + lsum) * f - lsum
      b <- ifelse(ok, b_new, b)
      m_last[ok] <- m
    }
    # (e) Umlagen
    if (length(levy_idx) > 0L) {
      u <- matrix(0, n, nk)
      hs <- matrix(0, n, nk)
      on_k <- matrix(FALSE, n, nk)
      prior_559c <- if (any_559c && look_559c > 0) {
        lo <- max(m - look_559c, 1L - off)
        rowSums(c559[, ix(lo):ix(m - 1L), drop = FALSE])
      } else {
        rep(0, n)
      }
      for (kk in levy_idx) {
        x <- meas[[kk]]
        ev <- x$me == m
        proc <- x$proc
        if (isTRUE(x$uses_559c)) {
          ck <- x$c559 * unit$lam_rel / unit$n_we + prior_559c
          over <- proc == "bgb_559c" & ck > limit_559c
          aux_k[[kk]]$limit_559c <- aux_k[[kk]]$limit_559c | (ev & over)
          proc[over] <- "bgb_559"
        }
        allowed <- rule_allowed(x$kind, inp$regime, ph, x$landlord, proc, P)
        locked <- (m - last559c) < block_559c & x$kind != "bgb_555b_6"
        uu <- x$u_by$bgb_559
        uu[proc == "bgb_559c"] <- x$u_by$bgb_559c[proc == "bgb_559c"]
        uu[proc == "bgb_559e"] <- x$u_by$bgb_559e[proc == "bgb_559e"]
        live <- ev & m < inp$mi_re & x$a > 0.5
        aux_k[[kk]]$not_allowed <- aux_k[[kk]]$not_allowed | (live & !allowed & isTRUE(P$active))
        aux_k[[kk]]$locked <- aux_k[[kk]]$locked | (live & allowed & locked)
        on <- ev & allowed & !locked & m < inp$mi_re
        on_k[, kk] <- on
        u[, kk] <- ifelse(on, x$lambda * uu / (12 * inp$area), 0)
        hs[, kk] <- ifelse(proc == "bgb_559e", 1, x$hs)
        proc_rec[on, kk] <- proc[on]
        jj <- mo$period[m] + 1L
        aux_k[[kk]]$computed[on, jj] <- (unit$lam_rel * x$lambda * uu)[on]
        aux_k[[kk]]$procedure[ev, jj] <- unname(proc_code[ifelse(on, proc, "none")])[ev]
        aux_k[[kk]]$proc[on] <- proc[on]
      }
      tb <- b + lsum
      p6 <- csum(cum, m - 1L) - csum(cum, m - 1L - win6)
      p6h <- csum(cum_h, m - 1L) - csum(cum_h, m - 1L - win6)
      res <- rp_levy_caps(u, hs, tb, p6, p6h, vcap, lsum, P, rule_cap_t, rule_cap_h)
      lev <- lev + res$l
      inc[, ix(m)] <- inc[, ix(m)] + rowSums(res$l)
      inc_h[, ix(m)] <- inc_h[, ix(m)] + rowSums(res$heat)
      jj <- mo$period[m] + 1L
      for (kk in levy_idx) {
        on <- on_k[, kk]
        aux_k[[kk]]$capped[on, jj] <- (res$capped[, kk] * 12 * unit$area)[on]
        aux_k[[kk]]$charged[on, jj] <- (res$l[, kk] * 12 * unit$area)[on]
        aux_k[[kk]]$binding[on] <- res$binding[on]
        is_c <- on & proc_rec[, kk] == "bgb_559c" & res$l[, kk] > 0
        last559c[is_c] <- m
        if (any_559c) {
          c559[is_c, ix(m)] <- c559[is_c, ix(m)] +
            (meas[[kk]]$c559 * unit$lam_rel / unit$n_we)[is_c]
        }
      }
    }
    cum[, ix(m) + 1L] <- cum[, ix(m)] + inc[, ix(m)]
    cum_h[, ix(m) + 1L] <- cum_h[, ix(m)] + inc_h[, ix(m)]
    lsum <- if (nk > 0L) rowSums(lev) else rep(0, n)
    # (f) § 558
    if (ph == "p558" && inp$ovm_policy && isTRUE(P$active) && !is.null(ovm_m)) {
      wait <- P$wait_months %||% 15
      okw <- (m - m_last) >= wait & inp$act[, m] > 0.5
      if (identical(inp$policy, "interval")) okw <- okw & (m - m_last) >= inp$interval
      t_cur <- b + lsum
      base <- t_hist[, ix(m - 36L)]
      s559 <- csum(cum, m) - csum(cum, m - 36L)
      kz <- if (is.null(kz_m)) 0 else kz_m[, m]
      vol <- if (identical(inp$policy, "capped") && !is.null(inp$vshare)) {
        t_hist[, ix(m - inp$cm)] * (1 + inp$vshare) + csum(cum, m) - csum(cum, m - inp$cm)
      } else {
        Inf
      }
      kr <- ifelse(fab & !inp$post_binding_kappung, Inf, inp$kap)
      tgt <- rule_target(ovm_m[, m], base, s559, kz, kr, vol)
      up <- okw & tgt > t_cur + 1e-9
      b <- ifelse(up, b + (tgt - t_cur), b)
      m_last[up] <- m
      fab[up] <- FALSE
    }
    # (g) Fluktuation und Wiedervermietung
    if (inp$fluct) {
      # nur in Monaten mit Mietvertrag (act), wie (f): vor rent_start keine Wiedervermietung
      fm <- inp$turnover_m[, m] / 12 * inp$act[, m]
      t_cur <- b + lsum
      z <- rep(0, n)
      cd <- rep(FALSE, n)
      for (kk in seq_len(nk)) {
        x <- meas[[kk]]
        recent <- (m - x$me) < mpb & proc_rec[, kk] %in% relet_procs
        z <- z + lev[, kk] * recent
        if (isTRUE(x$comprehensive)) cd <- cd | (x$mc <= m & x$a > 0.5)
      }
      ba <- rule_brake(inp$brake_area, inp$brake_until %||% as.Date(NA), inp$month_dates[m],
                       inp$first_use, cd, P)
      ovm_now <- if (is.null(ovm_m)) rep(0, n) else ovm_m[, m]
      ovm_un <- if (is.null(inp[["ovm_unmod_m"]])) ovm_now else inp[["ovm_unmod_m"]][, m]
      rn <- rule_relet(inp$mkt_m[, m], ovm_now, ovm_un, t_cur, z, ba, P)
      b <- (1 - fm) * b + fm * rn
      if (nk > 0L) lev <- lev * (1 - fm)
    }
    # (h) Speichern
    lsum <- if (nk > 0L) rowSums(lev) else rep(0, n)
    t_hist[, ix(m)] <- b + lsum
    b_m[, m] <- b
    for (kk in seq_len(nk)) l_m[[kk]][, m] <- lev[, kk]
  }
  list(B = b_m, L = l_m, aux = aux_k, kz_m = kz_m, staffel_absorb = staffel_absorb)
}

# ---------------------------------------------------------------------------------------------
# Komponente
# ---------------------------------------------------------------------------------------------

#' Umlagen der Historie einer Einheit (levy_history; Teil B 1.2)
#' @noRd
rp_history <- function(ctx, prefix) {
  hist <- rp_raw(ctx, prefix) %||% list()
  out <- list()
  for (h in names(hist)) {
    e <- hist[[h]]
    d <- rp_as_date(e[["effective_date"]], ctx$grid)
    if (is.null(d)) next
    v <- rp_num(ctx, paste0(prefix, ".", h, ".eur_m2_month"), 0)
    out[[length(out) + 1L]] <- list(mi = rp_mi(ctx$grid, d), value = rep_len(v, ctx$n),
                                    heating = rp_lgl(e[["heating"]], FALSE),
                                    procedure = rp_code(e[["procedure"]], "levy_procedure") %||%
                                      "bgb_559")
  }
  out
}

#' Einheiten der Rechnung: Gruppe oder Wohnungen der Mieterliste (Teil B 1.8.8)
#' @noRd
rp_units <- function(spec, ctx, inp) {
  roll <- rp_ids(ctx$setting(spec, "rent_roll_units"))
  pre <- paste0("unit_groups.", inp$gid)
  if (length(roll) == 0L) {
    return(list(list(area = inp$area, r0 = inp$r0, rent36 = inp$rent36, m_last0 = inp$m_last0,
                     hist = rp_history(ctx, paste0(pre, ".levy_history")), lam_rel = rep(1, inp$n),
                     n_we = max(1L, as.integer(inp$n_units)))))
  }
  lapply(roll, function(u) {
    up <- paste0(pre, ".rent_roll.", u)
    area_u <- rep_len(rp_num(ctx, paste0(up, ".living_area_m2"), 0), inp$n)
    r0_u <- rep_len(rp_num(ctx, paste0(up, ".rent_eur_m2_month"), inp$r0), inp$n)
    last <- rp_as_date(rp_raw(ctx, paste0(up, ".last_558_increase_date")), inp$grid)
    list(area = area_u, r0 = r0_u,
         rent36 = rep_len(rp_num(ctx, paste0(up, ".rent_36m_ago_eur_m2_month"), r0_u), inp$n),
         m_last0 = if (is.null(last)) inp$m_last0 else min(rp_mi(inp$grid, last), 0),
         hist = rp_history(ctx, paste0(up, ".levy_history")),
         lam_rel = area_u / pmax(inp$area, 1e-300), n_we = 1L)
  })
}

#' Freiwillige Obergrenze der kumulierten Umlagen (Teil B 1.9.5)
#' @noRd
rp_voluntary_cap <- function(spec, ctx, inp, meas) {
  n <- inp$n
  g <- inp$grid
  if (!identical(inp$cap_mode, "warm_rent_neutral")) {
    v <- ctx$param(spec, "voluntary_cap_per_m2")
    return(list(vcap = if (is.null(v)) rep(Inf, n) else rep_len(v, n), no_saving = rep(FALSE, n)))
  }
  tid <- ctx$setting(spec, "tenant_cost_component")
  levy_meas <- Filter(function(x) isTRUE(x$levy), meas)
  if (is.null(tid) || length(levy_meas) == 0L) {
    return(list(vcap = rep(0, n), no_saving = rep(TRUE, n)))
  }
  me_min <- min(vapply(levy_meas, function(x) as.double(x$me_base), double(1)))
  starts <- c(0, g$month_end[-(g$T + 1L)]) + 1
  cand <- which(seq_along(g$months) >= 2L & g$months == 12L & starts >= me_min)
  fl <- ctx$component_base(tid)
  sav <- fl$aux$saving_eur_m2_month
  if (length(cand) == 0L || is.null(sav)) {
    return(list(vcap = rep(0, n), no_saving = rep(TRUE, n)))
  }
  v <- rep_len(pmax(0, sav[, cand[1L]]), n)
  list(vcap = v, no_saving = v <= 0)
}

#' Mietpfad bauen (build() des Typs rent_path)
#' @noRd
rp_build <- function(spec, ctx) {
  inp <- rp_inputs(spec, ctx)
  n <- inp$n
  big_m <- inp$M
  g <- inp$grid
  set <- function(nm) ctx$setting(spec, nm)
  levy_rows <- rp_ids(set("levy_rows"))
  ids <- unique(c(rp_ids(set("rent_law_measures")), levy_rows))
  meas <- lapply(ids, function(k) {
    rp_measure(spec, ctx, inp, k, levy_rows, set("cost_components"), set("grant_components"),
               set("funding_ids"))
  })
  names(meas) <- ids
  # Vergleichsmiete mit Modernisierungszuschlägen (aktueller Zustand bzw. ohne jüngere Zuschläge)
  if (!is.null(inp$ovm0)) {
    mm <- matrix(as.double(inp$mo$m), n, big_m, byrow = TRUE)
    lvl <- matrix(rep_len(inp$ovm0, n), n, big_m)
    lvl_un <- lvl
    for (x in meas) {
      up <- matrix(x$a * x$uplift, n, big_m)
      lvl <- lvl + up * (mm >= matrix(x$mc, n, big_m))
      lvl_un <- lvl_un + up * (mm >= matrix(x$mc + 36, n, big_m))
    }
    idx <- exp(inp$li_g$L[, -1L, drop = FALSE] - rp_log_index_at(inp$li_g, inp$m0_ovm))
    inp$ovm_m <- lvl * idx
    inp[["ovm_unmod_m"]] <- lvl_un * idx
  }
  # Belegung (1.8.4)
  works <- lapply(meas, function(x) x$works)
  vr <- inp$turnover_m * matrix(inp$relet, n, big_m) / 12
  core <- rp_vac_core(inp$mo, n, inp$vs_m, vr, inp$lease_up, inp$mi_rs, inp$mi_re, works)
  inp$act <- core$act
  vc <- rp_voluntary_cap(spec, ctx, inp, meas)
  units <- rp_units(spec, ctx, inp)
  sims <- lapply(units, function(u) rp_simulate(ctx, inp, meas, u, vc$vcap))
  occ <- (1 - inp$vs_m) * (1 - vr) * core$wm * core$wv * (1 - core$lu) * (1 - inp$extra_m)
  coll <- 1 - inp$def_m
  nk <- length(meas)
  rent_m <- matrix(0, n, big_m)
  levy_m <- lapply(seq_len(nk), function(i) matrix(0, n, big_m))
  t_lvl <- b_lvl <- l_lvl <- matrix(0, n, big_m)
  area_tot <- 0
  for (i in seq_along(units)) {
    u <- units[[i]]
    s <- sims[[i]]
    rent_m <- rent_m + s$B * u$area * core$act
    lsum_u <- matrix(0, n, big_m)
    for (kk in seq_len(nk)) {
      levy_m[[kk]] <- levy_m[[kk]] + s$L[[kk]] * u$area * (1 - inp$hard_m) * core$act
      lsum_u <- lsum_u + s$L[[kk]]
    }
    t_lvl <- t_lvl + (s$B + lsum_u) * u$area
    b_lvl <- b_lvl + s$B * u$area
    l_lvl <- l_lvl + lsum_u * u$area
    area_tot <- area_tot + u$area
  }
  levy_tot <- if (nk > 0L) Reduce(`+`, levy_m) else matrix(0, n, big_m)
  loss_m <- -(rent_m + levy_tot) * (1 - occ * coll)
  rows <- list()
  cooperative <- identical(inp$regime, "cooperative_fee")
  rows[[1L]] <- vofi_row(
    "rent", ctx$to_periods(rent_m), section = "project", category = "rent",
    label_key = if (cooperative) "types.flow.rent_path.rows.rent_cooperative" else NULL
  )
  rows[[2L]] <- vofi_row("rent_loss", ctx$to_periods(loss_m), section = "project",
                         category = "rent_loss")
  aux <- list()
  for (kk in seq_len(nk)) {
    x <- meas[[kk]]
    if (!(x$id %in% levy_rows)) next
    rows[[length(rows) + 1L]] <- vofi_row(paste0("levy_", x$id), ctx$to_periods(levy_m[[kk]]),
                                          section = "project", category = "modernization_levy",
                                          measure_id = x$id)
    for (fld in c("computed", "capped", "charged", "procedure")) {
      v <- Reduce(`+`, lapply(sims, function(s) s$aux[[kk]][[fld]]))
      if (identical(fld, "procedure")) v <- sims[[1L]]$aux[[kk]][[fld]]
      aux[[paste0("levy_", x$id, "_", fld)]] <- v
    }
  }
  at <- matrix(rep_len(area_tot, n), n, big_m)
  aux$vacant_share <- rp_active_mean(ctx, core$vac, core$act)
  aux$rent_level <- rp_period_mean(ctx, t_lvl / at)
  aux$base_level <- rp_period_mean(ctx, b_lvl / at)
  aux$levy_level <- rp_period_mean(ctx, l_lvl / at)
  aux$ovm_level <- if (is.null(inp[["ovm_m"]])) ctx$zeros() else
    rp_period_mean(ctx, inp[["ovm_m"]])
  aux$market_level <- if (is.null(inp$mkt_m)) ctx$zeros() else rp_period_mean(ctx, inp$mkt_m)
  kz_all <- sims[[1L]]$kz_m
  aux$kuerzung_level <- if (is.null(kz_all)) ctx$zeros() else rp_period_mean(ctx, kz_all)
  vcm <- ctx$by_sim(vc$vcap)
  vcm[, 1L] <- 0
  aux$voluntary_cap_level <- vcm
  aux$area_m2 <- ctx$by_sim(inp$area)
  mn <- rp_meta_notes(rp_notes(inp, meas), rp_messages(ctx, inp, meas, sims, vc),
                      group = inp$gid)
  meta <- list(
    notes = mn$notes,
    note_keys = mn$note_keys,
    messages = mn$messages,
    levy = lapply(stats::setNames(meas, ids), function(x) {
      pr <- sims[[1L]]$aux[[match(x$id, ids)]]$proc
      list(procedure_share = vapply(c("none", "bgb_559", "bgb_559c", "bgb_559e"),
                                    function(p) mean(pr == p), double(1)),
           cap_binding_share = mean(sims[[1L]]$aux[[match(x$id, ids)]]$binding),
           fallback_559e_share = mean(x$fallback_559e))
    })
  )
  vofi_flows(rows, aux = aux, meta = meta)
}

#' Vermerke des Mietpfads ohne Laufbezug (Themen inaktiv; Teil B 0.9, 1.14)
#'
#' `topic_559f_inactive` nur, wenn eine Umlage einer Wärmepumpenmaßnahme betroffen ist.
#' @noRd
rp_notes <- function(inp, meas) {
  hp <- any(vapply(meas, function(x) isTRUE(x$levy) && isTRUE(x$heat_pump), logical(1)))
  c(inp$notes,
    if (hp && !isTRUE(inp$P$active_559f)) "types.flow.rent_path.msg.topic_559f_inactive")
}

#' Laufbezogene Meldungen des Mietpfads (Teil B 1.9.2, 1.10, 1.14)
#' @param sims Ergebnisse von `rp_simulate()` je Einheit.
#' @param vc Ergebnis von `rp_voluntary_cap()`.
#' @return Liste der Einträge aus `rp_signal()`.
#' @noRd
rp_messages <- function(ctx, inp, meas, sims, vc) {
  n <- inp$n
  gid <- inp$gid
  pre <- "types.flow.rent_path.msg."
  sig <- function(code, hit, level) rp_signal(ctx, paste0(pre, code), hit, level, group = gid)
  none <- rep(FALSE, n)
  levy_k <- which(vapply(meas, function(x) isTRUE(x$levy), logical(1)))
  ev_any <- function(fld) {
    out <- none
    for (kk in levy_k) {
      for (s in sims) out <- out | s$aux[[kk]][[fld]]
    }
    out
  }
  per_k <- function(fun) {
    out <- none
    for (kk in levy_k) out <- out | rep_len(fun(meas[[kk]]), n)
    out
  }
  after_end <- per_k(function(x) {
    is.finite(x$me) & (x$me > inp$M | x$me >= inp$mi_re) & x$a > 0.5
  })
  above <- none
  if (inp$ovm_policy && isTRUE(inp$P$active) && !is.null(inp[["ovm_m"]])) {
    m1 <- pmin(pmax(inp$mi_rs, 1), inp$M)
    above <- inp$r0 > 1.2 * inp[["ovm_m"]][cbind(seq_len(n), m1)]
  }
  funds <- none
  if (!inp$ovm_policy) {
    for (x in meas) funds <- funds | (x$grants + x$tz + x$zint) > ctx$tol$zero_abs
  }
  absorb <- none
  for (s in sims) absorb <- absorb | s$staffel_absorb
  list(
    sig("limit_559c", ev_any("limit_559c"), "warn"),
    sig("blocked_559c", ev_any("locked"), "warn"),
    sig("levy_not_allowed", ev_any("not_allowed"), "inform"),
    sig("levy_after_end", after_end, "inform"),
    sig("fallback_559", per_k(function(x) x$fallback_559e & x$a > 0.5), "inform"),
    sig("hp_state_missing", per_k(function(x) isTRUE(x$hp_state_missing)), "warn"),
    sig("jaz_plan_missing", per_k(function(x) isTRUE(x$jaz_plan_missing)), "inform"),
    sig("rent_above_ovm", above, "inform"),
    sig("turnover_without_market", inp$turnover_no_market, "inform"),
    sig("kuerzung_only_ovm", funds, "inform"),
    sig("warm_neutral_no_saving", vc$no_saving, "warn"),
    sig("staffel_absorbs_levy", absorb, "inform")
  )
}

#' @noRd
typedef_rent_path <- function() {
  p <- vofi_param
  vofi_type(
    name = "rent_path", kind = "flow",
    params = list(
      unit_group = p("string", required = TRUE),
      living_area_m2 = p("number", required = TRUE, min = 0, unit = "m2"),
      n_units = p("integer", required = TRUE, min = 1),
      rent_eur_m2_month = p("value", required = TRUE, shapes = "scalar", unit = "EUR_m2_month"),
      rent_regime = p("enum", values = "vocab:rent_regime", default = "paragraph_558"),
      rent_start = p("timing", grid_default = "valuation_date"),
      rent_end = p("timing", grid_default = "end_date"),
      increase_policy = p("enum", values = "vocab:increase_policy", default = "auto"),
      rent_growth = p("value", default = list(ref = "market.rent_growth"), unit = "rate_pa"),
      growth_from = p("timing"),
      growth_applies_to = p("enum", values = "vocab:growth_applies_to", default = "total"),
      ovm_eur_m2_month = p("value", shapes = "scalar", unit = "EUR_m2_month"),
      ovm_base_date = p("date", grid_default = "valuation_date"),
      interval_months = p("integer", default = 36L, min = 15),
      voluntary_558_cap_share = p("share"),
      voluntary_558_cap_months = p("integer", default = 36L, min = 12),
      rent_36m_ago_eur_m2_month = p("value", shapes = "scalar", unit = "EUR_m2_month"),
      last_558_increase_date = p("date"),
      kappung_rate = p("share"),
      kappung_15_area = p("logical", default = FALSE),
      market_rent_eur_m2_month = p("value", shapes = "scalar", unit = "EUR_m2_month"),
      market_rent_growth = p("value", default = list(ref = "market.rent_growth_new"),
                             unit = "rate_pa"),
      market_rent_base_date = p("date", grid_default = "valuation_date"),
      turnover_rate_pa = p("value", default = 0, unit = "rate_pa"),
      relet_vacancy_months = p("number", default = 0, min = 0, unit = "months"),
      brake_area = p("logical", default = FALSE),
      brake_until = p("date", default = "2029-12-31"),
      first_use_after_2014_10_01 = p("logical"),
      vacancy_rate = p("value", default = 0, unit = "share"),
      rent_default_rate = p("value", default = 0, unit = "share"),
      extra_loss_share = p("value", default = 0, unit = "share"),
      lease_up_months = p("number", default = 0, min = 0, unit = "months"),
      staffel_steps = p("schedule", unit = "EUR_m2_month"),
      after_staffel_regime = p("enum", values = c("paragraph_558", "index"),
                               default = "paragraph_558"),
      index_rate = p("value", default = list(ref = "market.inflation"), unit = "rate_pa"),
      index_adjust_month = p("integer", default = 1L, min = 1, max = 12),
      index_cap_area = p("logical", default = FALSE),
      bound_increase_pa = p("value", default = 0, unit = "rate_pa"),
      binding_end = p("timing"),
      after_binding_regime = p("enum", values = c("paragraph_558", "index"),
                               default = "paragraph_558"),
      post_binding_kappung = p("logical", default = FALSE),
      modernization_levy = p("enum", values = "vocab:levy_mode", default = "auto"),
      voluntary_cap_per_m2 = p("value", shapes = "scalar", unit = "EUR_m2_month"),
      voluntary_cap_mode = p("enum", values = "vocab:voluntary_cap_mode", default = "fixed"),
      tenant_cost_component = p("ref"),
      hardship_share = p("value", default = 0, unit = "share"),
      drittmittel_attribution = p("enum", values = "vocab:third_party_allocation"),
      flat_559e_order = p("enum", values = "vocab:s559e_order"),
      hp_reduction_order = p("enum", values = "vocab:s559f_order"),
      section43_flat = p("logical"),
      hp_threshold_inclusive = p("logical"),
      interest_subsidy_in_559e = p("logical", default = TRUE),
      kuerzung_558_5 = p("logical", default = TRUE),
      kuerzung_grant_years = p("number", min = 0, unit = "years"),
      kuerzung_loan_years = p("number", min = 0, unit = "years"),
      levy_effective_delay_months = p("integer", min = 0),
      rent_law_measures = p("ids", default = list()),
      levy_rows = p("ids", default = list()),
      cost_components = p("ids", default = list()),
      grant_components = p("ids", default = list()),
      funding_ids = p("ids", default = list()),
      rent_roll_units = p("ids", default = list())
    ),
    rows = c("rent", "rent_loss", "levy_*"),
    grid_invariant = TRUE,
    domain_reads = c("measures", "funding", "financing", "energy", "unit_groups", "building"),
    build = function(spec, ctx) rp_build(spec, ctx),
    example = list(type = "rent_path", unit_group = "g1", living_area_m2 = 700, n_units = 10L,
                   rent_eur_m2_month = 7.5, rent_start = "2027-01-01",
                   growth_from = "2028-01-01", rent_growth = 0.015, vacancy_rate = 0.02,
                   rent_default_rate = 0.01)
  )
}

# nolint end
