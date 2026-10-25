# Zeitraster vofi_grid (Integrator, Spec 00 Abschnitt 3).
# Index j = t + 1 adressiert alle Vektoren und Matrixspalten; Spalte 1 = t0 (Länge 0).
# Alle Periodengrenzen sind Monatserste (valuation_date MUSS ein Monatserster sein).

#' Zeitraster erzeugen
#'
#' Erzeugt das Zeitraster des VoFi als Vektor der Periodenlängen in ganzen Monaten mit Datums-,
#' Phasen- und Betriebsjahresangaben (Spec 00, Abschnitt 3). Das Horizontende ist das feste
#' Kalenderdatum `valuation_date` + 12 · `horizon_years` Monate (R-67). Standard ist das
#' Jahresraster; mit `construction_step_months < 12` entsteht ein nicht äquidistantes Raster
#' (Bauphase fein, Betrieb jährlich), mit `periods_months` ein explizites Raster.
#'
#' @param valuation_date Bewertungsstichtag (t = 0) als `Date` oder ISO-Zeichenkette; MUSS ein
#'   Monatserster sein.
#' @param horizon_years Länge des Horizonts in Jahren ab dem Stichtag (ganze Zahl ≥ 1). Wird mit
#'   `periods_months` nicht verwendet und darf dann `NULL` sein.
#' @param construction_months Dauer der Bauphase in Monaten (ganze Zahl ≥ 0).
#' @param construction_step_months Periodenlänge der Bauphase in Monaten: 1, 3, 6 oder 12.
#' @param operation_step_months Periodenlänge der Betriebsphase in Monaten (v1: nur 12).
#' @param operation_alignment `"calendar"` (Betriebsperioden = Kalenderjahre, erstes ggf. als
#'   Teiljahr) oder `"completion"` (Betriebsjahre ab Fertigstellung).
#' @param periods_months optional: explizite Periodenlängen in Monaten (ohne t0), z. B.
#'   `c(3, 3, 3, 3, 12, 12, 12)`.
#' @param start_year erstes Kalenderjahr der Prozesse (Default: Jahr des Stichtags).
#' @return Objekt der Klasse `vofi_grid` (Liste mit `T`, `t`, `months`, `delta`, `tau`,
#'   `month_end`, `date_start`, `date_end`, `year`, `phase`, `op_year`, `op_year_full`, `label`,
#'   `valuation_date`, `completion_date`, `end_date`, `years`, `settings`).
#' @family Rechnen
#' @examples
#' g <- vofi_time_grid(as.Date("2027-01-01"), horizon_years = 30)
#' g$T
#' g2 <- vofi_time_grid("2027-01-01", 30, construction_months = 9,
#'                      construction_step_months = 1)
#' head(as.data.frame(g2), 12)
#' @export
vofi_time_grid <- function(valuation_date, horizon_years, construction_months = 0L,
                           construction_step_months = 12L, operation_step_months = 12L,
                           operation_alignment = c("calendar", "completion"),
                           periods_months = NULL, start_year = NULL) {
  vd <- utl_as_date(valuation_date, "valuation_date")
  if (length(vd) != 1L) {
    vofi_abort("core.arg_scalar", arg = "valuation_date", .class = "vofi_error_input")
  }
  if (utl_mday(vd) != 1L) {
    vofi_abort("core.grid.valuation_not_first", date = vd, .class = "vofi_error_input")
  }
  operation_alignment <- utl_match_arg(operation_alignment, c("calendar", "completion"),
                                       "operation_alignment")
  cm <- utl_check_whole(construction_months, "construction_months", min = 0)
  cs <- utl_check_whole(construction_step_months, "construction_step_months", min = 1)
  if (!(cs %in% c(1L, 3L, 6L, 12L))) {
    vofi_abort("core.grid.construction_step", value = cs, .class = "vofi_error_input")
  }
  os <- utl_check_whole(operation_step_months, "operation_step_months", min = 1)
  if (os != 12L) {
    vofi_abort("core.grid.operation_step", value = os, .class = "vofi_error_input")
  }
  hy <- NULL
  if (is.null(periods_months)) {
    if (missing(horizon_years) || is.null(horizon_years)) {
      vofi_abort("core.arg_missing", arg = "horizon_years", .class = "vofi_error_input")
    }
    hy <- utl_check_whole(horizon_years, "horizon_years", min = 1)
  } else if (!missing(horizon_years) && !is.null(horizon_years)) {
    hy <- utl_check_whole(horizon_years, "horizon_years", min = 1)
  }
  completion <- grid_add_months(vd, cm)

  if (!is.null(periods_months)) {
    pm <- periods_months
    if (!is.numeric(pm) || length(pm) == 0L || anyNA(pm) ||
        any(abs(pm - round(pm)) > 1e-9) || any(pm < 1)) {
      vofi_abort("core.grid.periods_invalid", value = utl_collapse(format(pm)),
                 .class = "vofi_error_input")
    }
    months <- c(0L, as.integer(round(pm)))
    if (!is.null(hy) && sum(months) != 12L * hy) {
      vofi_inform("core.grid.periods_horizon", months = sum(months), years = hy)
    }
  } else {
    end <- grid_add_months(vd, 12L * hy)
    if (end <= completion) {
      vofi_abort("core.grid.horizon_short", horizon = hy, construction = cm,
                 .class = "vofi_error_input")
    }
    if (cs == 12L) {
      months <- c(0L, rep(12L, hy))
    } else {
      bau <- c(rep(cs, cm %/% cs), if (cm %% cs > 0L) cm %% cs)
      total_op <- grid_months_between(completion, end)
      stub <- 0L
      if (operation_alignment == "calendar" && utl_month(completion) != 1L) {
        stub <- 13L - utl_month(completion)
      }
      stub <- min(stub, total_op)
      rest <- total_op - stub
      betr <- c(if (stub > 0L) stub, rep(12L, rest %/% 12L), if (rest %% 12L > 0L) rest %% 12L)
      months <- c(0L, as.integer(bau), as.integer(betr))
    }
  }
  months <- as.integer(months)
  n_t <- length(months)
  big_t <- n_t - 1L
  month_end <- cumsum(months)
  date_end <- grid_add_months(rep(vd, n_t), month_end)
  date_start <- c(vd, date_end[-n_t])
  year <- utl_year(date_start)
  year[1L] <- utl_year(vd)
  phase <- ifelse(date_start < completion, "construction", "operation")
  phase[1L] <- if (cm > 0L) "construction" else "operation"

  op_year <- integer(n_t)
  op_idx <- which(seq_len(n_t) >= 2L & phase == "operation")
  if (length(op_idx) > 0L) {
    first <- op_idx[1L]
    if (operation_alignment == "calendar") {
      op_year[op_idx] <- year[op_idx] - year[first] + 1L
    } else {
      op_year[op_idx] <- as.integer(
        grid_months_between(date_start[first], date_start[op_idx]) %/% 12L + 1L
      )
    }
  }
  op_months <- tapply(months[op_year > 0L], op_year[op_year > 0L], sum)
  op_year_full <- op_year > 0L & op_months[as.character(op_year)] %in% 12L
  op_year_full[is.na(op_year_full)] <- FALSE
  sy <- if (is.null(start_year)) utl_year(vd) else utl_check_whole(start_year, "start_year")
  if (sy > utl_year(vd)) {
    vofi_abort("core.grid.start_year", start_year = sy, year = utl_year(vd),
               .class = "vofi_error_input")
  }
  delta <- months / 12
  new_vofi_grid(list(
    T = big_t,
    t = seq.int(0L, big_t),
    months = months,
    delta = delta,
    tau = cumsum(delta),
    month_end = as.integer(month_end),
    date_start = date_start,
    date_end = date_end,
    year = as.integer(year),
    phase = as.character(phase),
    op_year = as.integer(op_year),
    op_year_full = as.logical(unname(op_year_full)),
    label = utl_grid_labels(date_start, date_end, months),
    valuation_date = vd,
    completion_date = completion,
    end_date = date_end[n_t],
    years = seq.int(sy, max(year)),
    settings = list(valuation_date = vd, horizon_years = hy, construction_months = cm,
                    construction_step_months = cs, operation_step_months = os,
                    operation_alignment = operation_alignment,
                    periods_months = if (is.null(periods_months)) NULL else months[-1L],
                    start_year = start_year)
  ))
}

#' Konstruktor und Validator für vofi_grid
#' @param x Liste mit den Feldern aus Abschnitt 3.2.
#' @return Objekt der Klasse `vofi_grid`.
#' @noRd
new_vofi_grid <- function(x) {
  x <- structure(x, class = "vofi_grid")
  validate_vofi_grid(x)
  x
}

#' @noRd
validate_vofi_grid <- function(x) {
  req <- c("T", "t", "months", "delta", "tau", "month_end", "date_start", "date_end", "year",
           "phase", "op_year", "op_year_full", "label", "valuation_date", "completion_date",
           "end_date", "years", "settings")
  miss <- setdiff(req, names(x))
  if (length(miss) > 0L) {
    vofi_abort("core.contract.fields_missing", class = "vofi_grid", fields = utl_collapse(miss),
               .class = "vofi_error_contract")
  }
  n_t <- x$T + 1L
  lens <- vapply(req[2:13], function(f) length(x[[f]]), integer(1))
  if (any(lens != n_t) || x$months[1L] != 0L) {
    vofi_abort("core.contract.grid_lengths", .class = "vofi_error_contract")
  }
  invisible(x)
}

# ---------------------------------------------------------------------------------------------
# Datumsarithmetik (Monate)
# ---------------------------------------------------------------------------------------------

#' @noRd
utl_year <- function(d) as.integer(format(d, "%Y"))
#' @noRd
utl_month <- function(d) as.integer(format(d, "%m"))
#' @noRd
utl_mday <- function(d) as.integer(format(d, "%d"))

#' Tage im Monat
#' @noRd
utl_days_in_month <- function(y, m) {
  ny <- y + m %/% 12L
  nm <- m %% 12L + 1L
  first_next <- as.Date(sprintf("%04d-%02d-01", ny, nm))
  as.integer(format(first_next - 1L, "%d"))
}

#' Datum plus k Kalendermonate (vektorisiert; Tag wird auf das Monatsende begrenzt)
#' @param d `Date`.
#' @param k ganze Zahl(en).
#' @return `Date`.
#' @noRd
grid_add_months <- function(d, k) {
  n <- max(length(d), length(k))
  if (n == 0L) return(as.Date(character(0)))
  d <- rep_len(d, n)
  k <- rep_len(as.integer(round(k)), n)
  out <- rep(as.Date(NA), n)
  ok <- !is.na(d) & !is.na(k)
  if (any(ok)) {
    y <- utl_year(d[ok])
    m <- utl_month(d[ok]) - 1L + k[ok]
    ny <- y + m %/% 12L
    nm <- m %% 12L + 1L
    day <- pmin(utl_mday(d[ok]), utl_days_in_month(ny, nm))
    out[ok] <- as.Date(sprintf("%04d-%02d-%02d", ny, nm, day))
  }
  out
}

#' Ganze Monate zwischen zwei Monatsersten (d2 - d1)
#' @noRd
grid_months_between <- function(d1, d2) {
  (utl_year(d2) - utl_year(d1)) * 12L + (utl_month(d2) - utl_month(d1))
}

#' Position eines Datums in Monaten seit dem Stichtag (stetig, Tag anteilig)
#' @param grid `vofi_grid`.
#' @param date `Date`.
#' @return double (gleiche Länge wie `date`).
#' @noRd
grid_month_pos <- function(grid, date) {
  vd <- grid$valuation_date
  y <- utl_year(date)
  m <- utl_month(date)
  d <- utl_mday(date)
  (y - utl_year(vd)) * 12 + (m - utl_month(vd)) + (d - 1) / utl_days_in_month(y, m)
}

#' Anzeige-Labels der Perioden (ASCII)
#' @noRd
utl_grid_labels <- function(date_start, date_end, months) {
  n_t <- length(months)
  out <- character(n_t)
  out[1L] <- "t0"
  if (n_t < 2L) return(out)
  for (j in 2:n_t) {
    y <- utl_year(date_start[j])
    m <- utl_month(date_start[j])
    k <- months[j]
    last <- grid_add_months(date_end[j], -1L)
    ly <- utl_year(last)
    lm <- utl_month(last)
    out[j] <- if (k == 12L && m == 1L) {
      sprintf("%d", y)
    } else if (k == 12L) {
      sprintf("%d/%02d", y, (y + 1L) %% 100L)
    } else if (k == 1L) {
      sprintf("%02d/%d", m, y)
    } else if (k == 3L && (m - 1L) %% 3L == 0L) {
      sprintf("Q%d/%d", (m - 1L) %/% 3L + 1L, y)
    } else if (k == 6L && m %in% c(1L, 7L)) {
      sprintf("H%d/%d", if (m == 1L) 1L else 2L, y)
    } else if (ly == y) {
      sprintf("%02d-%02d/%d", m, lm, y)
    } else {
      sprintf("%02d/%d-%02d/%d", m, y, lm, ly)
    }
  }
  out
}

# ---------------------------------------------------------------------------------------------
# Zuordnung Datum/Jahr -> Periode (3.4, R-35)
# ---------------------------------------------------------------------------------------------

#' Periode eines Datums
#'
#' `date == valuation_date` ergibt t = 0; `date > valuation_date` ergibt
#' t = min{t >= 1 : date <= date_end[t]}; nach dem Horizontende `NA`; vor dem Stichtag `NA` mit
#' Attribut `"before"` (logischer Vektor, `TRUE` an diesen Stellen).
#' @param grid `vofi_grid`.
#' @param date `Date`-Vektor (oder ISO-Zeichenketten).
#' @return integer gleicher Länge mit Attribut `"before"`.
#' @noRd
grid_period_of <- function(grid, date) {
  if (!inherits(date, "Date")) date <- as.Date(date, optional = TRUE)
  x <- as.numeric(date)
  v <- as.numeric(grid$date_end)
  i <- findInterval(x, v, left.open = TRUE)
  out <- as.integer(i)
  before <- !is.na(x) & x < v[1L]
  out[before] <- NA_integer_
  out[!is.na(x) & x > v[length(v)]] <- NA_integer_
  attr(out, "before") <- before
  out
}

#' Periode einer Jahresangabe (Jahr Y bedeutet den 1. Januar Y)
#' @param grid `vofi_grid`.
#' @param year ganze Zahl(en).
#' @return integer (siehe [grid_period_of()]).
#' @noRd
grid_period_of_year <- function(grid, year) {
  grid_period_of(grid, as.Date(sprintf("%04d-01-01", as.integer(year))))
}

# ---------------------------------------------------------------------------------------------
# Formen: n x (T+1)
# ---------------------------------------------------------------------------------------------

#' Nullmatrix n x (T+1)
#' @noRd
grid_zeros <- function(grid, n = 1L) matrix(0, as.integer(n), grid$T + 1L)

#' Skalar oder n-Vektor -> n x (T+1), jede Zeile konstant (wie `ctx$by_sim()`)
#' @noRd
grid_by_sim <- function(grid, x, n = length(x)) {
  x <- as.double(x)
  if (!(length(x) %in% c(1L, n))) {
    vofi_abort("core.contract.length", what = "by_sim", expected = n, actual = length(x),
               .class = "vofi_error_contract")
  }
  matrix(rep_len(x, n), nrow = n, ncol = grid$T + 1L)
}

#' Vektor der Länge T+1 -> n x (T+1), jede Spalte konstant (wie `ctx$by_period()`)
#' @noRd
grid_by_period <- function(grid, x, n = 1L) {
  x <- as.double(x)
  if (length(x) != grid$T + 1L) {
    vofi_abort("core.contract.length", what = "by_period", expected = grid$T + 1L,
               actual = length(x), .class = "vofi_error_contract")
  }
  matrix(x, nrow = as.integer(n), ncol = grid$T + 1L, byrow = TRUE)
}

#' Rate bzw. Betrag als n x (T+1)-Matrix (Skalar, n-Vektor oder Matrix)
#' @noRd
utl_sim_matrix <- function(grid, x, what = "x") {
  if (is.matrix(x)) {
    if (ncol(x) != grid$T + 1L) {
      vofi_abort("core.contract.length", what = what, expected = grid$T + 1L,
                 actual = ncol(x), .class = "vofi_error_contract")
    }
    storage.mode(x) <- "double"
    return(x)
  }
  grid_by_sim(grid, x, length(x))
}

# ---------------------------------------------------------------------------------------------
# Umrechnungen (3.6)
# ---------------------------------------------------------------------------------------------

#' Effektive Periodenrate (1 + r_pa)^delta - 1; Spalte 1 = 0
#' @param grid `vofi_grid`.
#' @param r_pa Skalar, n-Vektor oder n x (T+1).
#' @return n x (T+1).
#' @noRd
grid_rate_eff <- function(grid, r_pa) {
  r <- utl_sim_matrix(grid, r_pa, "r_pa")
  d <- grid_by_period(grid, grid$delta, nrow(r))
  out <- (1 + r)^d - 1
  out[, 1L] <- 0
  out
}

#' Nominale Periodenrate r_pa * delta
#' @inheritParams grid_rate_eff
#' @noRd
grid_rate_nom <- function(grid, r_pa) {
  r <- utl_sim_matrix(grid, r_pa, "r_pa")
  r * grid_by_period(grid, grid$delta, nrow(r))
}

#' Jahresbetrag -> Periodenbetrag x_pa * delta
#' @param grid `vofi_grid`.
#' @param x_pa Skalar, n-Vektor oder n x (T+1).
#' @noRd
grid_per_period <- function(grid, x_pa) {
  x <- utl_sim_matrix(grid, x_pa, "x_pa")
  x * grid_by_period(grid, grid$delta, nrow(x))
}

#' Kalenderjahresraten (für Kalenderjahresindex und Vorlauf)
#'
#' Rate des Kalenderjahres Y >= Jahr(Stichtag) = Wert von g in der ersten Periode j >= 2 mit
#' year[j] == Y (sonst die Periode, die den 1. Januar Y enthält; jenseits des Rasters die letzte
#' Spalte). Jahre vor dem Stichtagsjahr: Attribut `"annual_before"` (n x k, Spaltennamen =
#' Jahre), sonst `g[, 1]` mit Meldung `core.index_before_assumed`.
#' @return n x length(yrs).
#' @noRd
utl_calendar_rates <- function(grid, g, before, yrs, path = NULL) {
  n <- nrow(g)
  y0 <- utl_year(grid$valuation_date)
  idx <- seq_along(grid$year)
  out <- matrix(0, n, length(yrs))
  assumed <- FALSE
  if (!is.null(before)) {
    before <- as.matrix(before)
    if (nrow(before) == 1L && n > 1L) before <- before[rep(1L, n), , drop = FALSE]
    byears <- suppressWarnings(as.integer(colnames(before)))
  }
  for (k in seq_along(yrs)) {
    y <- yrs[k]
    if (y >= y0) {
      j <- which(idx >= 2L & grid$year == y)[1L]
      if (is.na(j)) {
        cand <- which(idx >= 2L & grid$year <= y)
        j <- if (length(cand) > 0L) max(cand) else 1L
      }
      out[, k] <- g[, j]
    } else if (!is.null(before) && ncol(before) > 0L && !all(is.na(byears))) {
      col <- match(y, byears)
      if (is.na(col)) col <- if (y < min(byears, na.rm = TRUE)) which.min(byears) else which.max(byears)
      out[, k] <- before[, col]
    } else {
      out[, k] <- g[, 1L]
      assumed <- TRUE
    }
  }
  if (assumed) vofi_inform("core.index_before_assumed", path = path %||% "?")
  out
}

#' Niveau-Funktion über Kalenderjahre (Bezug: 1. Januar von yrs[1])
#' @return Funktion `level(date)` -> n-Vektor.
#' @noRd
utl_calendar_level <- function(rates, yrs) {
  n <- nrow(rates)
  lend <- matrix(0, n, length(yrs))
  acc <- rep(1, n)
  for (k in seq_along(yrs)) {
    acc <- acc * (1 + rates[, k])
    lend[, k] <- acc
  }
  list(
    end_of_year = function(y) lend[, y - yrs[1L] + 1L, drop = FALSE],
    at = function(d) {
      y <- utl_year(d)
      k <- y - yrs[1L] + 1L
      frac <- (utl_month(d) - 1 + (utl_mday(d) - 1) / utl_days_in_month(y, utl_month(d))) / 12
      start <- if (k == 1L) rep(1, n) else lend[, k - 1L]
      start * (1 + rates[, k])^frac
    }
  )
}

#' Kumulierter Index zum Periodenende (Bestandsgrößen, Preise an Stichtagen)
#'
#' I_t = I_{t-1} * (1 + g[, t+1])^delta_t. `base_date = NULL`: I_0 = 1. `base_date` vor dem
#' Stichtag: I_0 = Vorlauf über die Kalenderjahre zwischen `base_date` und Stichtag (Teiljahre
#' geometrisch anteilig, Jahreswerte aus Attribut `"annual_before"`, sonst `g[, 1]` mit Meldung).
#' `base_date` nach dem Stichtag: I_t = I*_t / I*(base_date), geometrisch interpoliert innerhalb
#' der Periode von `base_date` (jenseits des Horizonts mit der Rate der letzten Periode).
#' @param grid `vofi_grid`.
#' @param g Wachstumsrate p. a.: Skalar, n-Vektor oder n x (T+1); optional mit Attributen
#'   `"annual_before"` und `"path"` (für die Meldung).
#' @param base_date `NULL` oder Datum der Preisbasis.
#' @return n x (T+1).
#' @noRd
grid_index <- function(grid, g, base_date = NULL) {
  gm <- utl_sim_matrix(grid, g, "g")
  n <- nrow(gm)
  n_t <- grid$T + 1L
  istar <- matrix(1, n, n_t)
  if (n_t >= 2L) {
    for (j in 2:n_t) istar[, j] <- istar[, j - 1L] * (1 + gm[, j])^grid$delta[j]
  }
  if (is.null(base_date)) return(istar)
  bd <- utl_as_date(base_date, "base_date")
  vd <- grid$valuation_date
  if (bd == vd) return(istar)
  if (bd > vd) {
    p <- grid_period_of(grid, bd)
    if (is.na(p)) {
      yrs <- (grid_month_pos(grid, bd) - grid$month_end[n_t]) / 12
      level <- istar[, n_t] * (1 + gm[, n_t])^yrs
    } else {
      j <- p + 1L
      yrs <- (grid_month_pos(grid, bd) - grid$month_end[j - 1L]) / 12
      level <- istar[, j - 1L] * (1 + gm[, j])^yrs
    }
    return(istar / matrix(level, n, n_t))
  }
  yrs <- seq.int(utl_year(bd), utl_year(vd))
  rates <- utl_calendar_rates(grid, gm, attr(g, "annual_before"), yrs, attr(g, "path"))
  lv <- utl_calendar_level(rates, yrs)
  i0 <- lv$at(vd) / lv$at(bd)
  istar * matrix(i0, n, n_t)
}

#' Kalenderjahresindex für laufende Jahresbeträge (R-62)
#'
#' Spalte j = Indexstand am Ende des Kalenderjahres year[j] (am (year[j] + 1)-01-01) bezogen auf
#' `base_date` (Default: Stichtag); Spalte 1 (t0) = Wert des Stichtagsjahres. Innerhalb eines
#' Kalenderjahres ist der Index konstant. Jahresrate des Kalenderjahres Y = Wert von g in der
#' ersten Periode j >= 2 mit year[j] == Y.
#' @inheritParams grid_index
#' @return n x (T+1).
#' @noRd
grid_index_year <- function(grid, g, base_date = NULL) {
  gm <- utl_sim_matrix(grid, g, "g")
  n <- nrow(gm)
  n_t <- grid$T + 1L
  vd <- grid$valuation_date
  bd <- if (is.null(base_date)) vd else utl_as_date(base_date, "base_date")
  ymin <- min(utl_year(vd), utl_year(bd))
  ymax <- max(c(grid$year, utl_year(bd)))
  yrs <- seq.int(ymin, ymax)
  rates <- utl_calendar_rates(grid, gm, attr(g, "annual_before"), yrs, attr(g, "path"))
  lv <- utl_calendar_level(rates, yrs)
  base <- lv$at(bd)
  out <- matrix(0, n, n_t)
  for (j in seq_len(n_t)) out[, j] <- lv$end_of_year(grid$year[j])[, 1L] / base
  out
}

#' Anteil der Monate jeder Periode im Intervall [from, to)
#' @param grid `vofi_grid`.
#' @param from,to `NULL` (offen) oder Datum.
#' @return numerischer Vektor der Länge T+1; t0 = 0.
#' @noRd
grid_overlap <- function(grid, from = NULL, to = NULL) {
  s <- if (is.null(from)) -Inf else grid_month_pos(grid, utl_as_date(from, "from"))
  e <- if (is.null(to)) Inf else grid_month_pos(grid, utl_as_date(to, "to"))
  n_t <- grid$T + 1L
  pe <- grid$month_end
  ps <- c(0, pe[-n_t])
  len <- pmax(0, pmin(pe, e) - pmax(ps, s))
  out <- ifelse(grid$months > 0L, len / pmax(grid$months, 1L), 0)
  out[1L] <- 0
  out
}

#' Monatstabelle des Rasters
#' @param grid `vofi_grid`.
#' @return data.frame(m, period, date_start, date_end, year) mit M_T Zeilen.
#' @noRd
grid_months <- function(grid) {
  big_m <- grid$month_end[grid$T + 1L]
  m <- seq_len(big_m)
  vd <- grid$valuation_date
  ds <- grid_add_months(rep(vd, big_m), m - 1L)
  data.frame(
    m = m,
    period = utl_month_period(grid, m),
    date_start = ds,
    date_end = grid_add_months(rep(vd, big_m), m),
    year = utl_year(ds),
    stringsAsFactors = FALSE
  )
}

#' Periode p(m) = min{t : M_t >= m} der Monate m
#' @noRd
utl_month_period <- function(grid, m) {
  as.integer(findInterval(m, grid$month_end, left.open = TRUE))
}

#' Monatsmatrix n x M_T -> n x (T+1) (Summe je Periode, Spalte 1 = 0)
#' @param grid `vofi_grid`.
#' @param x_month n x M_T.
#' @return n x (T+1).
#' @noRd
grid_to_periods <- function(grid, x_month) {
  if (is.null(dim(x_month))) x_month <- matrix(x_month, nrow = 1L)
  big_m <- grid$month_end[grid$T + 1L]
  if (ncol(x_month) != big_m) {
    vofi_abort("core.contract.length", what = "x_month", expected = big_m,
               actual = ncol(x_month), .class = "vofi_error_contract")
  }
  out <- matrix(0, nrow(x_month), grid$T + 1L)
  for (j in seq_len(grid$T + 1L)[-1L]) {
    if (grid$months[j] > 0L) {
      cols <- (grid$month_end[j - 1L] + 1L):grid$month_end[j]
      out[, j] <- rowSums(x_month[, cols, drop = FALSE])
    }
  }
  out
}

#' Periodenmatrix n x (T+1) -> Monatsmatrix n x M_T
#' @param grid `vofi_grid`.
#' @param x n x (T+1).
#' @param how `"repeat"` (Monatswert = Periodenwert) oder `"spread"` (Periodenbetrag / Monate).
#' @return n x M_T.
#' @noRd
grid_to_months <- function(grid, x, how = c("repeat", "spread")) {
  how <- utl_match_arg(how, c("repeat", "spread"), "how")
  x <- utl_sim_matrix(grid, x, "x")
  big_m <- grid$month_end[grid$T + 1L]
  p <- utl_month_period(grid, seq_len(big_m)) + 1L
  out <- x[, p, drop = FALSE]
  if (how == "spread") {
    out <- out / matrix(grid$months[p], nrow(x), big_m, byrow = TRUE)
  }
  dimnames(out) <- NULL
  out
}

#' Prozessmatrix in Kalenderjahren -> n x (T+1) (Spalte j = Wert des Jahres year[j])
#' @param grid `vofi_grid`.
#' @param x_year n x length(years).
#' @return n x (T+1).
#' @noRd
grid_map_years <- function(grid, x_year) {
  if (is.null(dim(x_year))) x_year <- matrix(x_year, nrow = 1L)
  cols <- grid$year - grid$years[1L] + 1L
  if (any(cols < 1L) || max(cols) > ncol(x_year)) {
    vofi_abort("core.contract.length", what = "x_year", expected = length(grid$years),
               actual = ncol(x_year), .class = "vofi_error_contract")
  }
  out <- x_year[, cols, drop = FALSE]
  dimnames(out) <- NULL
  out
}

# ---------------------------------------------------------------------------------------------
# Laufspezifische Verschiebungen (3.9, R-60); in ctx als shift_period/shift_overlap/shift_months
# ---------------------------------------------------------------------------------------------

#' Verschiebung in ganzen Monaten runden (floor(x + 0.5))
#' @noRd
utl_round_shift <- function(months) floor(as.double(months) + 0.5)

#' Periode von date + months[i] Monaten je Lauf
#' @param grid `vofi_grid`.
#' @param date Datum (Länge 1).
#' @param months n-Vektor der Verschiebung in Monaten (wird gerundet).
#' @return integer n-Vektor; `NA` jenseits des Horizonts.
#' @noRd
grid_shift_period <- function(grid, date, months) {
  d <- utl_as_date(date, "date")
  m <- utl_round_shift(months)
  out <- grid_period_of(grid, grid_add_months(rep(d, length(m)), m))
  attr(out, "before") <- NULL
  out
}

#' Monatsanteil jeder Periode in [from + months[i], to) je Lauf
#' @param grid `vofi_grid`.
#' @param from Datum (Länge 1).
#' @param months n-Vektor der Verschiebung in Monaten (wird gerundet).
#' @param to `NULL` oder Datum.
#' @return n x (T+1).
#' @noRd
grid_shift_overlap <- function(grid, from, months, to = NULL) {
  s <- grid_month_pos(grid, utl_as_date(from, "from")) + utl_round_shift(months)
  e <- if (is.null(to)) Inf else grid_month_pos(grid, utl_as_date(to, "to"))
  n <- length(s)
  n_t <- grid$T + 1L
  pe <- grid$month_end
  ps <- c(0, pe[-n_t])
  pe_m <- matrix(pmin(pe, e), n, n_t, byrow = TRUE)
  ps_m <- matrix(ps, n, n_t, byrow = TRUE)
  s_m <- matrix(s, n, n_t)
  len <- pmax(0, pe_m - pmax(ps_m, s_m))
  den <- matrix(pmax(grid$months, 1L), n, n_t, byrow = TRUE)
  out <- len / den
  out[, 1L] <- 0
  out
}

#' 0/1-Matrix der aktiven Monate (Monat m aktiv, wenn sein Beginn in [from + months[i], to) liegt)
#' @inheritParams grid_shift_overlap
#' @return n x M_T.
#' @noRd
grid_shift_months <- function(grid, from, months, to = NULL) {
  s <- grid_month_pos(grid, utl_as_date(from, "from")) + utl_round_shift(months)
  e <- if (is.null(to)) Inf else grid_month_pos(grid, utl_as_date(to, "to"))
  n <- length(s)
  big_m <- grid$month_end[grid$T + 1L]
  start <- matrix(seq_len(big_m) - 1, n, big_m, byrow = TRUE)
  s_m <- matrix(s, n, big_m)
  (start >= s_m - 1e-9 & start < e) * 1
}

# ---------------------------------------------------------------------------------------------
# S3-Methoden (Integrator, 13.6)
# ---------------------------------------------------------------------------------------------

#' Zeitraster als Data Frame
#'
#' @param x Objekt der Klasse `vofi_grid`.
#' @param row.names,optional nicht verwendet (Kompatibilität mit [as.data.frame()]).
#' @param ... nicht verwendet.
#' @return Data Frame mit einer Zeile je Zeitpunkt t = 0…T und den Spalten `t`, `label`,
#'   `date_start`, `date_end`, `months`, `delta`, `tau`, `year`, `phase`, `op_year`,
#'   `op_year_full`.
#' @family Rechnen
#' @examples
#' as.data.frame(vofi_time_grid("2027-01-01", 3))
#' @export
as.data.frame.vofi_grid <- function(x, row.names = NULL, optional = FALSE, ...) { # nolint
  data.frame(
    t = x$t, label = x$label, date_start = x$date_start, date_end = x$date_end,
    months = x$months, delta = x$delta, tau = x$tau, year = x$year, phase = x$phase,
    op_year = x$op_year, op_year_full = x$op_year_full,
    stringsAsFactors = FALSE
  )
}

#' Zeitraster ausgeben
#'
#' @param x Objekt der Klasse `vofi_grid`.
#' @param n Anzahl der angezeigten Perioden.
#' @param ... nicht verwendet.
#' @return `invisible(x)`.
#' @family Rechnen
#' @examples
#' print(vofi_time_grid("2027-01-01", 30, construction_months = 9,
#'                      construction_step_months = 1))
#' @export
print.vofi_grid <- function(x, n = 12L, ...) {
  cat(lbl("core.grid.print_header", T = x$T, start = x$valuation_date, end = x$end_date,
          completion = x$completion_date), "\n", sep = "")
  df <- as.data.frame(x)
  df$date_start <- fmt_date(df$date_start)
  df$date_end <- fmt_date(df$date_end)
  df$delta <- round(df$delta, 4)
  df$tau <- round(df$tau, 4)
  print(utils::head(df, n), row.names = FALSE)
  if (nrow(df) > n) {
    cat(lbl("core.grid.print_more", n = as.integer(nrow(df) - n)), "\n", sep = "")
  }
  invisible(x)
}
