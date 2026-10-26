# Kennzahlen-Registry, Notation und Ausgabe (WS-D2, Spec 00 Abschnitt 12).
# Eigentuemer: WS-D2. Inhalt: Konstruktor der eingebauten Kennzahltypen (kpi_typedef()) mit
# Anwendbarkeitspruefung (Perspektive, Restriktionen, Mietersicht, Policy stop), kpi_compute()
# (12.1, beide Sichten mit und ohne Restwert), core_ex_rv() (9.4), Notation 12.2 als interne
# Hilfsfunktionen (EL, EN, NS, q, NOI, KD, V, Restwertpfad, Betriebsjahre, Stabilisierungsjahr),
# Primaerkennzahl (12.3a), Vergleichskennzahlen je Lauf (12.6, kpi_compare_values()) sowie die
# exportierten Funktionen vofi_kpis() und vofi_register_kpi().

# ---------------------------------------------------------------------------------------------
# Typdefinition und Anwendbarkeit
# ---------------------------------------------------------------------------------------------

#' Eingebaute Kennzahl definieren (12.1)
#'
#' Hülle um `vofi_type()` für die eingebauten Kennzahlen. `fun(core, ctx)` rechnet die Werte;
#' die erzeugte Funktion `compute(core, ctx)` prüft vorher die Anwendbarkeit (Perspektive,
#' Restriktionscode, Mietersicht) und setzt danach bei `stopped = TRUE` die Läufe mit Policy
#' `stop` auf `NA` mit Code `run_stopped` (12.1).
#' @param name Name der Kennzahl.
#' @param fun Funktion `fun(core, ctx)` -> `vofi_kpi_value`.
#' @param unit,shape,rv_variant,higher_is_better,mc_default,perspectives,requires Felder nach 5.3.
#' @param restriction `NULL` oder Restriktionscode (`analysis.restrictions`, Fußnote 5 in 12.3).
#' @param tenant_view nur bei `analysis.tenant_view = TRUE` (Fußnote 3 in 12.3).
#' @param stopped Läufe mit Policy `stop` werden `NA` (`run_stopped`).
#' @param rv_ref Restwertbezug für Ausgaben (12.5, internes Feld `rv_ref` der Definition):
#'   `"with"` (Wert enthält den Restwert; Default bei `rv_variant = TRUE`), `"independent"`
#'   (restwertunabhängig, Vermerk „unabhängig vom Restwert“; Default sonst) oder `"value_path"`
#'   (nutzt den Wertpfad V_t statt des Restwerts, LTV und Beleihungsauslauf). Kennzahlen, deren
#'   Wert den Restwert enthält, ohne dass 12.3 eine Variante `_ex_rv` vorsieht (z. B.
#'   `npv_cf_project`), setzen `"with"`.
#' @return `vofi_typedef`.
#' @noRd
kpi_typedef <- function(name, fun, unit = "EUR", shape = "scalar", rv_variant = FALSE,
                        higher_is_better = TRUE, mc_default = FALSE, perspectives = NULL,
                        requires = character(0), restriction = NULL, tenant_view = FALSE,
                        stopped = FALSE, rv_ref = NULL) {
  force(fun)
  rv_ref <- rv_ref %||% (if (isTRUE(rv_variant)) "with" else "independent")
  compute <- function(core, ctx) {
    code <- kpi_not_applicable(ctx, perspectives, restriction, tenant_view)
    if (!is.null(code)) return(kpi_na_value(core, shape, code))
    res <- fun(core, ctx)
    if (stopped) res <- kpi_apply_stopped(res, core)
    res
  }
  vofi_type(name = name, kind = "kpi", compute = compute, unit = unit, shape = shape,
            rv_variant = rv_variant, higher_is_better = higher_is_better,
            mc_default = mc_default, perspectives = perspectives, requires = requires,
            rv_ref = rv_ref)
}

#' Anwendbarkeit einer Kennzahl (Fußnoten 2 bis 5 in 12.3)
#' @return `NULL` (anwendbar) oder `"not_applicable_perspective"`.
#' @noRd
kpi_not_applicable <- function(ctx, perspectives = NULL, restriction = NULL,
                               tenant_view = FALSE) {
  code <- "not_applicable_perspective"
  if (!is.null(perspectives) && !(ctx$perspective %in% perspectives)) return(code)
  if (!is.null(restriction) && !(restriction %in% kpi_restrictions(ctx))) return(code)
  if (isTRUE(tenant_view) && !kpi_tenant_view(ctx)) return(code)
  NULL
}

#' Kennzahlwert, der in allen Läufen `NA` mit einem Code ist
#' @param core core (für n und Raster).
#' @param shape `"scalar"` oder `"series"`.
#' @param code NA-Begründungscode.
#' @noRd
kpi_na_value <- function(core, shape, code) {
  n <- core$n
  if (identical(shape, "series")) {
    yrs <- kpi_series_years(kpi_op_years(core$grid), core$grid)
    return(vofi_kpi_value(matrix(NA_real_, n, length(yrs)), na_reason = code, years = yrs))
  }
  vofi_kpi_value(rep(NA_real_, n), na_reason = code)
}

#' Läufe mit Policy `stop` auf `NA` (`run_stopped`) setzen (12.1)
#' @noRd
kpi_apply_stopped <- function(res, core) {
  st <- kpi_flag(core, "stopped")
  if (!any(st)) return(res)
  vals <- res$values
  na <- res$na_reason
  if (is.matrix(vals)) vals[st, ] <- NA_real_ else vals[st] <- NA_real_
  na[st] <- "run_stopped"
  vofi_kpi_value(vals, na_reason = na, years = res$years)
}

#' Kennzahlwert aus Werten und einer Liste (Maske, Code) in Vorrangreihenfolge
#'
#' Der erste zutreffende Code gewinnt; betroffene Läufe werden `NA`. Ein Code darf je Lauf
#' verschieden sein (Zeichenvektor der Länge n, z. B. weitergereichte Codes); fehlt er für einen
#' betroffenen Lauf, gilt `not_computed`.
#' @param values n-Vektor bzw. n x P.
#' @param ... Paare `list(mask, code)` (mask: logischer n-Vektor; code: Code bzw. n Codes).
#' @param years bei Reihen.
#' @noRd
kpi_value_codes <- function(values, ..., years = NULL) {
  n <- if (is.matrix(values)) nrow(values) else length(values)
  na <- rep(NA_character_, n)
  for (rule in list(...)) {
    m <- rep_len(as.logical(rule[[1L]]), n)
    m[is.na(m)] <- FALSE
    code <- rep_len(as.character(rule[[2L]]), n)
    code[is.na(code)] <- "not_computed"
    sel <- m & is.na(na)
    na[sel] <- code[sel]
  }
  hit <- !is.na(na)
  if (is.matrix(values)) values[hit, ] <- NA_real_ else values[hit] <- NA_real_
  # verbleibende nicht endliche Werte (z. B. 0/0) sind ein Vertragsfehler der Kennzahl
  vofi_kpi_value(values, na_reason = na, years = years)
}

#' Markierung eines Laufs als logischer n-Vektor (fehlende Spalte: FALSE)
#' @noRd
kpi_flag <- function(core, name) {
  v <- core$flags[[name]]
  if (is.null(v)) return(rep(FALSE, core$n))
  v <- as.logical(v)
  v[is.na(v)] <- FALSE
  v
}

# ---------------------------------------------------------------------------------------------
# Einstellungen aus der Spezifikation (deterministisch)
# ---------------------------------------------------------------------------------------------

#' Rohwert eines Spec-Pfads
#' @noRd
kpi_spec_get <- function(ctx, path) {
  if (is.null(ctx$spec)) return(NULL)
  path_get(ctx$spec, path)
}

#' Numerische Einstellung (Basisfallwert, erster Lauf) mit Default
#' @noRd
kpi_num_setting <- function(ctx, path, default) {
  v <- kpi_spec_get(ctx, path)
  if (is.null(v)) return(default)
  if (is.numeric(v) && !is.list(v)) return(as.double(v[1L]))
  x <- ctx$value_base(path, "scalar")
  if (is.null(x)) default else as.double(x[1L])
}

#' Restriktionscodes der Ampelstufe 2 (`analysis.restrictions`)
#' @noRd
kpi_restrictions <- function(ctx) {
  as.character(unlist(kpi_spec_get(ctx, "analysis.restrictions")))
}

#' Mietersicht aktiv (`analysis.tenant_view`; Rückfall nach `rule:tenant_view`)
#' @noRd
kpi_tenant_view <- function(ctx) {
  v <- kpi_spec_get(ctx, "analysis.tenant_view")
  if (is.null(v)) return(startsWith(ctx$perspective %||% "", "wu_"))
  isTRUE(as.logical(v))
}

#' Haushaltsmodus (`project.report_mode`, `auto`: `wu_*` -> Fachmodus, sonst Haushalt)
#' @noRd
kpi_household_mode <- function(ctx) {
  rm <- ctx$project$report_mode %||% "auto"
  if (identical(rm, "auto")) {
    rm <- if (startsWith(ctx$perspective %||% "", "wu_")) "expert" else "household"
  }
  identical(rm, "household")
}

#' Bestandsprojekt (1.5) und gesetzter Bestandswert (R-68)
#' @return Liste `existing` (lgl), `has_value` (lgl).
#' @noRd
kpi_existing <- function(ctx) {
  pt <- ctx$project$project_type %||% ""
  list(existing = pt %in% vocab("project_type")$existing_building,
       has_value = !is.null(kpi_spec_get(ctx, "building.existing_value_eur")))
}

# ---------------------------------------------------------------------------------------------
# Notation 12.2 (je Lauf, n x (T+1))
# ---------------------------------------------------------------------------------------------

#' Spaltenzahl T + 1
#' @noRd
kpi_nt <- function(core) core$grid$T + 1L

#' Nullmatrix n x (T+1)
#' @noRd
kpi_zeros <- function(core) matrix(0, core$n, kpi_nt(core))

#' Summe der gewählten Ledger-Zeilen (Nullmatrix bei leerer Auswahl oder ohne Ledger)
#' @noRd
kpi_sum <- function(core, ...) {
  if (is.null(core$ledger)) return(kpi_zeros(core))
  ledger_sum(core$ledger, ...)
}

#' Summe der Zeilen mit gegebenen Schlüsseln
#' @noRd
kpi_sum_keys <- function(core, keys) {
  if (length(keys) == 0L) return(kpi_zeros(core))
  Reduce(`+`, core$ledger$values[keys])
}

#' Zahlungswirksame Zeilen der Kategorien mit Merkmal `noi` bzw. `burden` (7.6)
#' @param flag `"noi"` oder `"burden"`.
#' @return Schlüssel.
#' @noRd
kpi_flag_keys <- function(core, flag) {
  if (is.null(core$ledger)) return(character(0))
  tab <- vocab("categories")
  sel <- tab[tab[[flag]], , drop = FALSE]
  r <- core$ledger$rows
  hit <- paste(r$section, r$category, sep = "\r") %in%
    paste(sel$section, sel$category, sep = "\r")
  r$key[hit & r$cash]
}

#' Einlagen EL_t (inkl. Sacheinlage, Nachschüsse, Fehlbeträge; 12.2)
#' @noRd
kpi_el <- function(core) {
  kpi_sum(core, section = "equity",
          category = c("equity_in", "equity_in_kind", "equity_call", "shortfall"))
}

#' Entnahmen EN_t (>= 0; 12.2)
#' @noRd
kpi_en <- function(core) -kpi_sum(core, section = "equity", category = "equity_out")

#' Nachschüsse und Fehlbeträge NS_t (12.2)
#' @noRd
kpi_ns <- function(core) kpi_sum(core, section = "equity", category = c("equity_call", "shortfall"))

#' Aufzinsfaktoren q_t = Prod_{u <= t} (1 + h_net,u), q_0 = 1 (12.2)
#' @noRd
kpi_q <- function(core) {
  h <- core$rates$h_net %||% core$rates$h
  if (is.null(h)) h <- kpi_zeros(core)
  q <- matrix(1, nrow(h), ncol(h))
  if (ncol(h) > 1L) {
    for (j in seq.int(2L, ncol(h))) q[, j] <- q[, j - 1L] * (1 + h[, j])
  }
  q
}

#' Horizont in Jahren T_J = tau[T + 1]
#' @noRd
kpi_tj <- function(core) core$grid$tau[kpi_nt(core)]

#' Endwert EW = BS_T der aktuellen Sicht
#' @noRd
kpi_ew <- function(core) as.double(core$stocks$BS[, kpi_nt(core)])

#' Endwert der Unterlassungsalternative EW_U
#' @noRd
kpi_ew_opp <- function(core) {
  ew <- core$opp$EW
  if (is.null(ew)) ew <- core$opp$BS[, kpi_nt(core)]
  rep_len(as.double(ew), core$n)
}

#' Reinertrag NOI_t (zahlungswirksame Zeilen der Kategorien mit `noi = TRUE`)
#' @noRd
kpi_noi <- function(core) kpi_sum_keys(core, kpi_flag_keys(core, "noi"))

#' Planmäßiger Kapitaldienst KD_t (Zinsen und Tilgung, ohne Schluss- und Sondertilgung, R-46)
#' @param existing `NULL` (alle Kredite), `TRUE` (Bestandsdarlehen), `FALSE` (neue Kredite).
#' @noRd
kpi_kd <- function(core, existing = NULL) {
  -kpi_sum(core, section = "loans", category = c("interest", "repay"), existing_debt = existing)
}

#' Sollzinsen INT_t der Kredite
#' @noRd
kpi_int <- function(core) -kpi_sum(core, section = "loans", category = "interest")

#' Gebühren FEES_t der Kredite
#' @noRd
kpi_fees <- function(core) -kpi_sum(core, section = "loans", category = "fees")

#' Marktwertpfad V_t (Merkzeilen `market_value`)
#' @noRd
kpi_market_value <- function(core) kpi_sum(core, category = "market_value")

#' Summe der Kreditbestände Sum_k B_k,t
#' @noRd
kpi_loan_balance <- function(core) {
  b <- core$stocks$B
  if (length(b) == 0L) return(kpi_zeros(core))
  Reduce(`+`, b)
}

#' Basis des Restwertpfads (`analysis.rv_path_basis`; `auto`: Haushaltsmodus -> `measures`)
#' @noRd
kpi_rv_basis <- function(ctx) {
  b <- kpi_spec_get(ctx, "analysis.rv_path_basis") %||% "auto"
  if (identical(b, "auto")) b <- if (kpi_household_mode(ctx)) "measures" else "method"
  b
}

#' Restwertpfad RWP_t (Merkzeilen `residual_path` der gewählten Basis, R-72)
#' @noRd
kpi_rwp <- function(core, ctx) {
  kpi_sum(core, category = "residual_path", rv_basis = kpi_rv_basis(ctx))
}

#' Vermögen mit Restwertpfad W_t (12.2): BS_t + RWP_t für t < T, W_T = BS_T
#'
#' Grundlage der Vermögensamortisation und des Rückgabepfads `"wealth"` (9.2). In der Sicht ohne
#' Restwert (`core$view == "ex_rv"`) ist W = BS (nur Guthaben und Schulden, R-72).
#' @param core core (12.1).
#' @param ctx Laufkontext.
#' @return n x (T+1).
#' @noRd
kpi_wealth <- function(core, ctx) {
  bs <- core$stocks$BS
  if (identical(core$view, "ex_rv")) return(bs)
  nt <- ncol(bs)
  w <- bs + kpi_rwp(core, ctx)
  w[, nt] <- bs[, nt]
  w
}

# ---------------------------------------------------------------------------------------------
# Betriebsjahre und Stabilisierungsjahr (12.2)
# ---------------------------------------------------------------------------------------------

#' Betriebsjahre des Rasters
#' @param grid `vofi_grid`.
#' @return Liste `P` (Betriebsjahre), `cols` (Spalten je Jahr), `first` (erste Spalte),
#'   `year` (Kalenderjahr der ersten Periode), `months` (Monate je Jahr), `full` (volles Jahr).
#' @noRd
kpi_op_years <- function(grid) {
  oy <- as.integer(grid$op_year)
  p <- sort(unique(oy[oy > 0L]))
  cols <- lapply(p, function(y) which(oy == y))
  first <- vapply(cols, function(cc) cc[1L], integer(1))
  list(P = p, cols = cols, first = first, year = as.integer(grid$year[first]),
       months = vapply(cols, function(cc) sum(grid$months[cc]), double(1)),
       full = as.logical(grid$op_year_full[first]))
}

#' Jahre einer Reihenkennzahl (Kalenderjahr der ersten Periode je Betriebsjahr)
#'
#' Ohne Betriebsjahr eine Spalte mit dem Kalenderjahr der letzten Periode (alle Werte `NA`).
#' @noRd
kpi_series_years <- function(oy, grid) {
  if (length(oy$P) == 0L) return(as.integer(grid$year[grid$T + 1L]))
  oy$year
}

#' Summen einer n x (T+1)-Matrix je Betriebsjahr
#' @return n x |P|.
#' @noRd
kpi_by_year <- function(m, oy) {
  n <- nrow(m)
  out <- matrix(0, n, length(oy$P))
  for (i in seq_along(oy$P)) out[, i] <- rowSums(m[, oy$cols[[i]], drop = FALSE])
  out
}

#' Kalenderjahr der Stabilisierung y_stab (R-77)
#'
#' `analysis.stabilization_year`, Default Kalenderjahr des ersten vollen Betriebsjahres (ohne
#' volles Betriebsjahr: des ersten Betriebsjahres).
#' @noRd
kpi_stab_year <- function(oy, ctx) {
  y <- kpi_spec_get(ctx, "analysis.stabilization_year")
  if (!is.null(y) && length(y) == 1L && !is.na(suppressWarnings(as.integer(y)))) {
    return(as.integer(y))
  }
  if (length(oy$P) == 0L) return(NA_integer_)
  if (any(oy$full)) oy$year[which(oy$full)[1L]] else oy$year[1L]
}

#' Maske der Betriebsjahre in P_stab (erste Periode im Kalenderjahr >= y_stab)
#' @noRd
kpi_stab_mask <- function(oy, ctx) {
  ys <- kpi_stab_year(oy, ctx)
  if (is.na(ys)) return(rep(FALSE, length(oy$P)))
  oy$year >= ys
}

# ---------------------------------------------------------------------------------------------
# Zeilenweise Aggregate ohne Funktionsaufrufe je Lauf (2.8 Nr. 5)
# ---------------------------------------------------------------------------------------------

#' Zeilenminimum über die maskierten Spalten (keine Spalte: `NA`)
#' @param m n x k; @param mask n x k logisch.
#' @noRd
kpi_row_min <- function(m, mask = !is.na(m)) {
  x <- m
  x[!mask] <- Inf
  out <- rep(Inf, nrow(m))
  for (j in seq_len(ncol(m))) out <- pmin(out, x[, j])
  out[!is.finite(out)] <- NA_real_
  out
}

#' Zeilenmaximum über die maskierten Spalten (keine Spalte: `NA`)
#' @noRd
kpi_row_max <- function(m, mask = !is.na(m)) {
  x <- m
  x[!mask] <- -Inf
  out <- rep(-Inf, nrow(m))
  for (j in seq_len(ncol(m))) out <- pmax(out, x[, j])
  out[!is.finite(out)] <- NA_real_
  out
}

#' Index der Spalte, ab der eine Bedingung dauerhaft gilt (Amortisation, 12.3)
#'
#' t* = min{t : ok_u für alle u >= t}; ohne solches t `NA`.
#' @param ok n x k logisch.
#' @return integer n (Spaltenindex) bzw. `NA`.
#' @noRd
kpi_first_permanent <- function(ok) {
  n <- nrow(ok)
  k <- ncol(ok)
  idx <- rep(NA_integer_, n)
  run <- rep(TRUE, n)
  for (j in rev(seq_len(k))) {
    run <- run & ok[, j]
    idx[run] <- j
  }
  idx
}

# ---------------------------------------------------------------------------------------------
# kpi_compute() und Sicht ohne Restwert (12.1, 12.5)
# ---------------------------------------------------------------------------------------------

#' Kennzahlen eines Chunks berechnen (12.1)
#'
#' Rechnet jede Kennzahl auf der Sicht mit Restwert (`<name>`) und bei `rv_variant = TRUE`
#' zusätzlich auf `core_ex_rv()` (`<name>_ex_rv`). Kennzahlen mit `perspectives`, zu denen die
#' Perspektive des Laufs nicht gehört, sind `NA` (`not_applicable_perspective`). Reihen stehen in
#' `series` mit `values`, `years` und `na_reason`.
#' @param kpis Liste von Kennzahl-Definitionen (`vofi_typedef` der Art `kpi`).
#' @param core Ergebnis der Periodenschleife (9.3) inkl. `opp`.
#' @param ctx Laufkontext (Stufe `"kpi"`).
#' @return `list(scalar = data.frame, na = data.frame, series = list())` mit n Zeilen.
#' @noRd
kpi_compute <- function(kpis, core, ctx) {
  n <- core$n
  vals <- list()
  nas <- list()
  series <- list()
  ex <- NULL
  for (def in kpis) {
    views <- list(list(suffix = "", core = core))
    if (isTRUE(def$rv_variant) && !is.null(core$terminal_ex_rv)) {
      if (is.null(ex)) ex <- core_ex_rv(core)
      views[[2L]] <- list(suffix = "_ex_rv", core = ex)
    }
    shape <- def$shape %||% "scalar"
    for (v in views) {
      nm <- paste0(def$name, v$suffix)
      res <- if (!is.null(def$perspectives) && !(ctx$perspective %in% def$perspectives)) {
        kpi_na_value(v$core, shape, "not_applicable_perspective")
      } else {
        def$compute(v$core, ctx)
      }
      kpi_check_result(res, nm, shape, n)
      if (identical(res$shape, "series")) {
        series[[nm]] <- list(values = res$values, years = res$years, na_reason = res$na_reason)
        next
      }
      vals[[nm]] <- res$values
      nas[[nm]] <- res$na_reason
    }
  }
  empty <- data.frame(row.names = seq_len(n))
  list(scalar = if (length(vals) > 0L) as.data.frame(vals, optional = TRUE) else empty,
       na = if (length(nas) > 0L) as.data.frame(nas, stringsAsFactors = FALSE,
                                                optional = TRUE) else empty,
       series = series)
}

#' Rückgabe einer Kennzahl prüfen (Klasse, Form, Länge)
#' @noRd
kpi_check_result <- function(res, nm, shape, n) {
  if (!inherits(res, "vofi_kpi_value")) {
    vofi_abort("kpi.not_kpi_value", kpi = nm, .class = "vofi_error_contract")
  }
  if (!identical(res$shape, shape)) {
    vofi_abort("kpi.shape", kpi = nm, expected = shape, actual = res$shape,
               .class = "vofi_error_contract")
  }
  len <- if (identical(res$shape, "series")) nrow(res$values) else length(res$values)
  if (len != n) vofi_abort("kpi.length", kpi = nm, n = n, .class = "vofi_error_contract")
  invisible(TRUE)
}

#' Sicht ohne Restwert (12.1, 9.4)
#'
#' BS, G, KK, KKP in T aus `terminal_ex_rv`, Restwertzeilen (`residual_value`, `sale_cost`) in
#' T+1 auf 0, Bestandszeilen in T+1 wie `terminal_ex_rv`, `view = "ex_rv"`; Einlagen und
#' Nachschüsse unverändert (9.4).
#' @param core core aus der Periodenschleife.
#' @return core in der Sicht `"ex_rv"`.
#' @noRd
core_ex_rv <- function(core) {
  n_t <- core$grid$T + 1L
  te <- core$terminal_ex_rv
  out <- core
  out$stocks$BS[, n_t] <- te$BS
  out$stocks$G[, n_t] <- te$G
  out$stocks$KK[, n_t] <- te$KK
  out$stocks$KKP[, n_t] <- te$KKP
  led <- core$ledger
  if (!is.null(led)) {
    for (k in ledger_select(led, category = c("residual_value", "sale_cost"))) {
      led$values[[k]][, n_t] <- 0
    }
    set <- list(dep_balance = te$G, od_balance = te$KK, odp_balance = te$KKP,
                net_position = te$BS)
    for (k in intersect(names(set), names(led$values))) led$values[[k]][, n_t] <- set[[k]]
    out$ledger <- led
  }
  out$view <- "ex_rv"
  out
}

# ---------------------------------------------------------------------------------------------
# Primärkennzahl (12.3a) und Beschriftung
# ---------------------------------------------------------------------------------------------

#' Primärkennzahl einer Spezifikation (12.3a, R-65, R-68)
#'
#' `analysis.primary_kpi = "auto"`: `delta_vs_reference` bei Bestandsprojekten im Modus
#' `absolute`, sonst `delta_terminal_value`. Zur Primärkennzahl gehören die Amortisation
#' (`payback_vs_reference` bzw. `payback_time`) und die Rendite (`incremental_return` bzw.
#' `roe_mirr`). `note` ist der Label-Schlüssel des Vermerks zu ΔEW gegenüber der Unterlassung bei
#' Bestandsprojekten („enthält Bestandszahlungen“ bzw. „gegenüber Verkauf zum Stichtag“).
#' @param spec `vofi_spec` (bzw. Liste mit `project`, `analysis`, `building`).
#' @return Liste `kpi`, `payback`, `return_kpi`, `existing`, `note`.
#' @noRd
kpi_primary <- function(spec) {
  p <- spec$project %||% list()
  existing <- (p$project_type %||% "") %in% vocab("project_type")$existing_building
  mode <- p$comparison_mode %||% "absolute"
  sel <- spec$analysis$primary_kpi %||% "auto"
  if (identical(sel, "auto")) {
    sel <- if (existing && identical(mode, "absolute")) "delta_vs_reference" else
      "delta_terminal_value"
  }
  ref <- identical(sel, "delta_vs_reference")
  note <- NA_character_
  if (existing) {
    note <- if (is.null(spec$building$existing_value_eur)) "kpi.notes.contains_existing" else
      "kpi.notes.vs_sale"
  }
  list(kpi = sel, payback = if (ref) "payback_vs_reference" else "payback_time",
       return_kpi = if (ref) "incremental_return" else "roe_mirr", existing = existing,
       note = note)
}

#' Vergleichskennzahlen (12.6): Einheiten, Variante ohne Restwert, Restwertbezug und Richtung
#'
#' `rv`: es gibt eine Variante `_ex_rv` (12.6); `rv_ref`: Restwertbezug des Werts wie bei
#' `kpi_typedef()`. `prob_better_than_ref` und `co2_abatement_cost` leiten sich aus
#' `delta_vs_reference` mit Restwert ab und haben keine Variante ohne Restwert (`"with"`).
#' @noRd
kpi_compare_specs <- function() {
  list(
    delta_vs_reference = list(unit = "EUR", rv = TRUE, rv_ref = "with", hib = TRUE),
    prob_better_than_ref = list(unit = "share", rv = FALSE, rv_ref = "with", hib = TRUE),
    payback_vs_reference = list(unit = "years", rv = TRUE, rv_ref = "with", hib = FALSE),
    payback_year_vs_reference = list(unit = "year", rv = TRUE, rv_ref = "with", hib = FALSE),
    incremental_return = list(unit = "rate_pa", rv = TRUE, rv_ref = "with", hib = TRUE),
    co2_reduction = list(unit = "t_co2", rv = FALSE, rv_ref = "independent", hib = TRUE),
    co2_abatement_cost = list(unit = "EUR_t", rv = FALSE, rv_ref = "with", hib = FALSE),
    monthly_saving_y1 = list(unit = "EUR_month", rv = FALSE, rv_ref = "independent",
                             hib = TRUE),
    monthly_saving_avg10 = list(unit = "EUR_month", rv = FALSE, rv_ref = "independent",
                                hib = TRUE),
    monthly_cashflow_change_y1 = list(unit = "EUR_month", rv = FALSE, rv_ref = "independent",
                                      hib = TRUE),
    warm_rent_change_y1 = list(unit = "EUR_m2_month", rv = FALSE, rv_ref = "independent",
                               hib = FALSE)
  )
}

#' Grundname einer Kennzahlspalte (ohne `_ex_rv`)
#' @noRd
kpi_base_name <- function(name) sub("_ex_rv$", "", name)

#' Anzeigename einer Kennzahl (Katalog, Nutzerlabel, Vergleichskennzahl; `_ex_rv` mit Zusatz)
#' @param name Spaltenname (z. B. `"terminal_value_ex_rv"`).
#' @return character(1).
#' @noRd
kpi_label <- function(name) {
  base <- kpi_base_name(name)
  txt <- if (reg_has("kpi", base)) {
    reg_type_label(reg_get("kpi", base), reg_source("kpi", base))
  } else {
    lbl(paste0("kpi.compare.", base, ".label"), .default = base)
  }
  if (!identical(base, name)) txt <- lbl("kpi.label_ex_rv", label = txt)
  txt
}

#' Einheit einer Kennzahl (Registry bzw. Vergleichskennzahl; unbekannt: `NA`)
#' @noRd
kpi_unit <- function(name) {
  base <- kpi_base_name(name)
  if (reg_has("kpi", base)) return(reg_get("kpi", base)$unit)
  kpi_compare_specs()[[base]]$unit %||% NA_character_
}

#' Restwertbezug und Vermerk einer Kennzahlspalte (12.5, R-52)
#'
#' Klasse `"with"` (Wert mit Restwert, auch ohne Gegenstück `_ex_rv`, z. B. `npv_cf_project`,
#' `co2_abatement_cost`), `"without"` (Spalte `_ex_rv`), `"independent"` (restwertunabhängig)
#' oder `"unknown"` (weder registriert noch Vergleichskennzahl, ohne Gegenstück `_ex_rv`; kein
#' Vermerk). Vermerk `kpi.rv_independent` nur bei echter Restwertunabhängigkeit, bei LTV und
#' Beleihungsauslauf `kpi.notes.value_path` (Wertpfad V_t statt Restwert). Nutzerkennzahlen
#' ohne `rv_variant` gelten nach R-52 als restwertunabhängig.
#' @param name Spaltenname.
#' @param all_names alle Spaltennamen des Ergebnisses (Paare `<name>`/`<name>_ex_rv`).
#' @return Liste `class`, `note` (Label-Schlüssel bzw. `NA`).
#' @noRd
kpi_rv_info <- function(name, all_names = character(0)) {
  base <- kpi_base_name(name)
  if (!identical(base, name)) return(list(class = "without", note = NA_character_))
  ref <- if (reg_has("kpi", base)) {
    def <- reg_get("kpi", base)
    if (isTRUE(def$rv_variant)) "with" else def$rv_ref %||% "independent"
  } else if (!is.null(kpi_compare_specs()[[base]])) {
    kpi_compare_specs()[[base]]$rv_ref
  } else {
    "unknown"
  }
  if (paste0(base, "_ex_rv") %in% all_names) ref <- "with"
  switch(ref,
    independent = list(class = "independent", note = "kpi.rv_independent"),
    value_path = list(class = "independent", note = "kpi.notes.value_path"),
    list(class = ref, note = NA_character_)
  )
}

#' Restwertbezug einer Kennzahlspalte: `"with"`, `"without"`, `"independent"` oder `"unknown"`
#' @param name Spaltenname.
#' @param all_names alle Spaltennamen des Ergebnisses (Paare `<name>`/`<name>_ex_rv`).
#' @noRd
kpi_rv_class <- function(name, all_names = character(0)) kpi_rv_info(name, all_names)$class

# ---------------------------------------------------------------------------------------------
# Vergleichskennzahlen je Lauf (12.6)
# ---------------------------------------------------------------------------------------------

#' Vergleichskennzahlen einer Variante gegen die Referenz je Lauf (12.6)
#'
#' Für `vofi_compare()` (WS-G): beide Läufe mit denselben Rohziehungen (CRN). Erwartet je Seite
#' eine Liste mit `kpis`, `kpi_na` (Data Frames mit n Zeilen, wie `eng_run_chunk()`), optional
#' `paths` (`wealth`, `opp_net_position`, `net_position`; 9.2), `grid` und die Perspektive
#' (`perspective` bzw. `spec$project$perspective`; Default: Argument `perspective`). `q_T` ist
#' der Aufzinsfaktor q_T der Variante (n-Vektor) für `co2_abatement_cost`; fehlt er, ist der Wert
#' `NA` (`not_computed`). `incremental_return` braucht Design-Läufe und steht in
#' `kpi_incremental_return()`. Fehlt einer Seite die zugrunde liegende Kennzahl, ist der Code
#' `not_applicable_perspective`, wenn die Perspektive dieser Seite nicht zu den `perspectives`
#' der Kennzahl gehört, sonst `not_computed` (nicht angefordert bzw. über `requires` entfallen).
#' @param var,ref Ergebnisse der Variante bzw. der Referenz.
#' @param q_T `NULL` oder n-Vektor.
#' @param perspective `NULL` oder Perspektive beider Seiten, falls sie die Seiten nicht tragen.
#' @return `list(kpis = data.frame, na = data.frame)` mit n Zeilen.
#' @noRd
kpi_compare_values <- function(var, ref, q_T = NULL, # nolint: object_name_linter.
                               perspective = NULL) {
  n <- nrow(var$kpis)
  out <- list()
  side <- function(x) {
    x$perspective <- x$perspective %||% x$spec$project$perspective %||% perspective
    x
  }
  var <- side(var)
  ref <- side(ref)
  get_kpi <- function(x, name) {
    if (!(name %in% names(x$kpis))) return(NULL)
    list(values = as.double(x$kpis[[name]]),
         na = as.character(x$kpi_na[[name]] %||% rep(NA_character_, n)))
  }
  # Differenz x - y der Kennzahl `name` je Lauf
  cmp <- function(x, y, name) {
    kpi_cmp_diff(get_kpi(x, name), get_kpi(y, name), n, kpi = name,
                 perspectives = c(x$perspective %||% NA_character_,
                                  y$perspective %||% NA_character_))
  }
  for (sfx in c("", "_ex_rv")) {
    out[[paste0("delta_vs_reference", sfx)]] <- cmp(var, ref, paste0("delta_terminal_value", sfx))
    pb <- kpi_payback_vs_reference_from(var, ref, ex_rv = nzchar(sfx))
    out[[paste0("payback_vs_reference", sfx)]] <- pb$time
    out[[paste0("payback_year_vs_reference", sfx)]] <- pb$year
  }
  out$co2_reduction <- cmp(ref, var, "co2_emissions")
  out$co2_abatement_cost <- kpi_co2_abatement_cost(out$delta_vs_reference, out$co2_reduction,
                                                   q_T)
  # Selbstnutzer: Ersparnis = Belastung der Referenz - Belastung der Variante (positiv = Ersparnis)
  out$monthly_saving_y1 <- cmp(ref, var, "monthly_burden_y1")
  out$monthly_saving_avg10 <- cmp(ref, var, "monthly_burden_avg10")
  # Kleinvermieter: Cashflow der Variante - der Referenz; Warmmiete Variante - Referenz
  out$monthly_cashflow_change_y1 <- cmp(var, ref, "monthly_net_cashflow_y1")
  out$warm_rent_change_y1 <- cmp(var, ref, "warm_rent_y1")
  list(kpis = as.data.frame(lapply(out, function(v) v$values), optional = TRUE),
       na = as.data.frame(lapply(out, function(v) v$na_reason), stringsAsFactors = FALSE,
                          optional = TRUE))
}

#' Differenz a - b zweier Kennzahlen je Lauf mit NA-Weitergabe
#'
#' Fehlt eine Seite, ist das Ergebnis `NA` mit dem Code aus `kpi_cmp_missing_code()`; sonst
#' trägt `NA` den Code der Variante bzw. der Referenz.
#' @param a,b `NULL` (Kennzahl fehlt) oder Liste `values`, `na`.
#' @param kpi Name der zugrunde liegenden Kennzahl.
#' @param perspectives Perspektiven der Seiten a und b (`NA`: unbekannt).
#' @noRd
kpi_cmp_diff <- function(a, b, n, kpi = NULL, perspectives = c(NA_character_, NA_character_)) {
  if (is.null(a) || is.null(b)) {
    miss <- perspectives[c(is.null(a), is.null(b))]
    return(vofi_kpi_value(rep(NA_real_, n), na_reason = kpi_cmp_missing_code(kpi, miss)))
  }
  v <- a$values - b$values
  na <- ifelse(is.na(a$values), a$na, ifelse(is.na(b$values), b$na, NA_character_))
  na[is.na(v) & is.na(na)] <- "not_computed"
  vofi_kpi_value(v, na_reason = na)
}

#' Code einer im Ergebnis fehlenden Kennzahl (12.4)
#'
#' `not_applicable_perspective`, wenn eine bekannte Perspektive der fehlenden Seite nicht zu den
#' `perspectives` der registrierten Kennzahl gehört; sonst `not_computed` (Kennzahl nicht
#' angefordert, über `requires` entfallen oder Perspektive unbekannt).
#' @param kpi Name der Kennzahl bzw. `NULL`.
#' @param persp Perspektiven der Seiten, denen die Kennzahl fehlt.
#' @noRd
kpi_cmp_missing_code <- function(kpi, persp) {
  persp <- persp[!is.na(persp)]
  if (is.null(kpi) || length(persp) == 0L || !reg_has("kpi", kpi)) return("not_computed")
  allowed <- reg_get("kpi", kpi)$perspectives
  if (!is.null(allowed) && any(!(persp %in% allowed))) "not_applicable_perspective" else
    "not_computed"
}

#' Amortisation gegenüber der Referenz aus den Rückgabepfaden (12.6, 9.6 Nr. 9)
#' @return Liste `time`, `year` (`vofi_kpi_value`).
#' @noRd
kpi_payback_vs_reference_from <- function(var, ref, ex_rv = FALSE) {
  n <- nrow(var$kpis)
  need <- c(if (ex_rv) "net_position" else "wealth", "opp_net_position")
  have <- all(need %in% names(var$paths)) && all(need %in% names(ref$paths)) &&
    !is.null(var$grid) && !is.null(ref$grid)
  if (!have) {
    na <- vofi_kpi_value(rep(NA_real_, n), na_reason = "not_computed")
    return(list(time = na, year = na))
  }
  w_of <- function(x) {
    if (!ex_rv) return(x$paths$wealth)
    w <- x$paths$net_position
    tv <- x$kpis$terminal_value_ex_rv
    if (!is.null(tv)) w[, ncol(w)] <- ifelse(is.na(tv), w[, ncol(w)], tv)
    w
  }
  kpi_payback_vs_reference(w_of(var), var$paths$opp_net_position, w_of(ref),
                           ref$paths$opp_net_position, var$grid, ref$grid)
}

# ---------------------------------------------------------------------------------------------
# Exportierte Funktionen
# ---------------------------------------------------------------------------------------------

#' Kennzahlen eines Ergebnisses
#'
#' Liefert die skalaren Kennzahlen eines Ergebnisses mit Bezeichnung, Einheit, Restwertbezug
#' und NA-Begründung (Spec 00, Abschnitte 12.3 bis 12.6). EUR-Kennzahlen (Einheiten `EUR`,
#' `EUR_pa`, `EUR_month`) werden auf Wunsch je Wohneinheit (`building.n_units`) bzw. je m²
#' Wohnfläche (`building.living_area_m2`) ausgewiesen (Konzept 1.4, R-83); übrige Kennzahlen
#' bleiben unverändert. Reihenkennzahlen (z. B. `monthly_burden`) stehen in `x$kpi_series`.
#'
#' Spalten: `kpi` (Spaltenname inkl. `_ex_rv`), `base` (Grundname), `label`, `unit`, `rv`
#' (`"with"` = Wert mit Restwert, auch ohne Gegenstück ohne Restwert wie beim Kapitalwert der
#' Zahlungsfolge; `"without"` = ohne Restwert; `"independent"` = unabhängig vom Restwert;
#' `"unknown"` = Restwertbezug unbekannt, z. B. nicht mehr registrierte Nutzerkennzahl), `per`,
#' `note` (Vermerke, durch „; “ getrennt: „unabhängig vom Restwert“, bei LTV und
#' Beleihungsauslauf der Hinweis auf den Wertpfad, bei der Endwertdifferenz von
#' Bestandsprojekten „enthält Bestandszahlungen“ bzw. „gegenüber Verkauf zum Stichtag“, beim
#' Kapitalwert und internen Zinsfuß der Zahlungsfolge „finanzierungsneutral, vereinfachte
#' Annahmen“, in Simulationen bei Renditen mit undefinierten Läufen der Zensurvermerk),
#' `primary` (Primärkennzahl nach 12.3a), bei
#' deterministischen Ergebnissen `value`, `na_reason`, `na_label` (bei mehreren Läufen zusätzlich
#' `sim`), bei Simulationen `deterministic`, `mean`, `sd`, `q05`, `q50`, `q95`, `p_neg`,
#' `na_share`, `n_valid`, `na_reason` und `na_label` des deterministischen Laufs, bei Vergleichen
#' zusätzlich `variant` (je Variante die Kennzahlen, danach die Vergleichskennzahlen als
#' Mittel über die Läufe).
#'
#' @param x Objekt der Klasse `vofi_result`, `vofi_mc_result` oder `vofi_comparison`.
#' @param which `NULL` (alle) oder Namen von Kennzahlen (Grundnamen oder Spaltennamen).
#' @param rv `"both"`, `"with"` (mit Restwert) oder `"without"` (ohne Restwert); Kennzahlen
#'   ohne Restwertbezug erscheinen in beiden Sichten.
#' @param per `"total"`, `"unit"` (je Wohneinheit) oder `"m2"` (je m² Wohnfläche).
#' @return Data Frame der Kennzahlen.
#' @family Analysieren
#' @examples
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' vofi_kpis(res)
#' vofi_kpis(res, which = "terminal_value", rv = "without")
#' @export
vofi_kpis <- function(x, which = NULL, rv = c("both", "with", "without"),
                      per = c("total", "unit", "m2")) {
  rv <- utl_match_arg(rv, c("both", "with", "without"), "rv")
  per <- utl_match_arg(per, c("total", "unit", "m2"), "per")
  if (!is.null(which) && (!is.character(which) || anyNA(which))) {
    vofi_abort("kpi.errors.which", .class = "vofi_error_input")
  }
  if (inherits(x, "vofi_comparison")) return(kpi_table_comparison(x, which, rv, per))
  if (inherits(x, "vofi_mc_result")) return(kpi_table_mc(x, which, rv, per))
  if (inherits(x, "vofi_result")) return(kpi_table_result(x, which, rv, per))
  vofi_abort("kpi.errors.not_result", cls = utl_collapse(class(x)), .class = "vofi_error_input")
}

#' Kennzahlspalten nach `which` und `rv` wählen
#' @noRd
kpi_select_columns <- function(cols, which, rv) {
  cols <- setdiff(cols, c("sim", "block", "branch"))
  if (!is.null(which)) {
    bad <- which[!(which %in% cols | which %in% kpi_base_name(cols))]
    if (length(bad) > 0L) {
      vofi_abort("kpi.errors.unknown", kpi = utl_collapse(bad),
                 suggestion = utl_suggest_text(bad[1L], unique(kpi_base_name(cols))),
                 .class = "vofi_error_input")
    }
    cols <- cols[cols %in% which | kpi_base_name(cols) %in% which]
  }
  info <- lapply(cols, kpi_rv_info, all_names = cols)
  cls <- vapply(info, function(i) i$class, "")
  keep <- switch(rv, both = rep(TRUE, length(cols)), with = cls != "without",
                 without = cls != "with")
  list(cols = cols[keep], rv = cls[keep],
       note = vapply(info, function(i) i$note, "")[keep])
}

#' Label-Schlüssel der Vermerke je Kennzahlspalte (12.3, 12.3a, 12.4, 12.5)
#'
#' Restwertvermerk aus `kpi_rv_info()`; bei `delta_terminal_value` (beide Sichten) der Vermerk
#' der Primärkennzahl für Bestandsprojekte (`kpi_primary(spec)$note`, 12.3a); bei
#' `npv_cf_project` und `irr_cf_project` „finanzierungsneutral, vereinfachte Annahmen“ (12.3);
#' bei `censored = TRUE` (Rendite mit undefinierten Läufen in der Statistik) der Zensurvermerk
#' (12.4).
#' @param cols Spaltennamen; @param rv_note Restwertvermerke (Schlüssel bzw. `NA`).
#' @param spec Spezifikation des Ergebnisses bzw. `NULL`.
#' @param censored `NULL` oder logischer Vektor je Spalte.
#' @return Liste von Zeichenvektoren (Schlüssel je Spalte).
#' @noRd
kpi_note_keys <- function(cols, rv_note, spec = NULL, censored = NULL) {
  base <- kpi_base_name(cols)
  existing <- if (is.null(spec)) NA_character_ else kpi_primary(spec)$note
  lapply(seq_along(cols), function(i) {
    keys <- rv_note[i]
    if (identical(base[i], "delta_terminal_value")) keys <- c(keys, existing)
    if (base[i] %in% c("npv_cf_project", "irr_cf_project")) {
      keys <- c(keys, "kpi.notes.project_simplified")
    }
    if (isTRUE(censored[i])) keys <- c(keys, "kpi.notes.censored")
    keys[!is.na(keys)]
  })
}

#' Grundgerüst der Kennzahltabelle
#' @param sel Auswahl aus `kpi_select_columns()` (`cols`, `rv`, `note`).
#' @noRd
kpi_table_frame <- function(sel, per, primary, spec = NULL, censored = NULL) {
  cols <- sel$cols
  base <- kpi_base_name(cols)
  keys <- kpi_note_keys(cols, sel$note, spec, censored)
  note <- vapply(keys, function(k) {
    if (length(k) == 0L) NA_character_ else paste(vapply(k, lbl, ""), collapse = "; ")
  }, "", USE.NAMES = FALSE)
  data.frame(
    kpi = cols, base = base,
    label = vapply(cols, kpi_label, "", USE.NAMES = FALSE),
    unit = vapply(cols, kpi_unit, "", USE.NAMES = FALSE),
    rv = sel$rv, per = rep(per, length(cols)),
    note = note,
    primary = base == (primary %||% ""),
    stringsAsFactors = FALSE
  )
}

#' Teiler für Kennzahlen je WE bzw. m² (R-83)
#' @return Zahl (Teiler) bzw. 1 bei `per = "total"`.
#' @noRd
kpi_divisor <- function(spec, grid, per) {
  if (identical(per, "total")) return(1)
  path <- if (identical(per, "unit")) "building.n_units" else "building.living_area_m2"
  v <- NULL
  if (!is.null(spec) && !is.null(path_get(spec, path))) {
    ctx <- eng_context_from_parts(grid, spec)
    v <- ctx$value_base(path, "scalar")
  }
  if (is.null(v) || !is.finite(v[1L]) || v[1L] <= 0) {
    vofi_abort("kpi.errors.per_missing", per = per, field = path, .class = "vofi_error_input")
  }
  as.double(v[1L])
}

#' Spalten, die bei `per` geteilt werden (EUR-Kennzahlen)
#' @noRd
kpi_per_mask <- function(units) units %in% c("EUR", "EUR_pa", "EUR_month")

#' NA-Begründungstexte
#' @noRd
kpi_na_label <- function(codes) {
  vapply(codes, function(cd) {
    if (is.na(cd)) NA_character_ else lbl(paste0("vocab.na_reasons.", cd), .default = cd)
  }, "", USE.NAMES = FALSE)
}

#' Kennzahltabelle eines deterministischen Ergebnisses
#' @noRd
kpi_table_result <- function(x, which, rv, per) {
  sel <- kpi_select_columns(names(x$kpis), which, rv)
  n <- nrow(x$kpis)
  fr <- kpi_table_frame(sel, per, x$meta$primary_kpi, x$spec)
  div <- kpi_divisor(x$spec, x$grid, per)
  scale <- ifelse(kpi_per_mask(fr$unit), div, 1)
  parts <- lapply(seq_len(n), function(i) {
    vals <- vapply(sel$cols, function(k) as.double(x$kpis[[k]][i]), double(1),
                   USE.NAMES = FALSE)
    codes <- vapply(sel$cols, function(k) {
      as.character((x$kpi_na[[k]] %||% NA_character_)[i])
    }, "", USE.NAMES = FALSE)
    d <- fr
    d$value <- vals / scale
    d$na_reason <- codes
    d$na_label <- kpi_na_label(codes)
    if (n > 1L) d <- cbind(data.frame(sim = rep(i, nrow(d))), d)
    d
  })
  out <- do.call(rbind, parts)
  if (is.null(out)) out <- cbind(fr, value = double(0), na_reason = character(0),
                                 na_label = character(0))
  rownames(out) <- NULL
  out
}

#' Kennzahltabelle einer Simulation (Statistik über die Läufe)
#' @noRd
kpi_table_mc <- function(x, which, rv, per) {
  sel <- kpi_select_columns(names(x$kpis), which, rv)
  # Renditen mit undefinierten Läufen: Statistik über die definierten Läufe (Zensurvermerk, 12.4)
  units <- vapply(sel$cols, kpi_unit, "", USE.NAMES = FALSE)
  censored <- vapply(seq_along(sel$cols), function(i) {
    identical(units[i], "rate_pa") && anyNA(x$kpis[[sel$cols[i]]])
  }, logical(1))
  fr <- kpi_table_frame(sel, per, x$meta$primary_kpi, x$spec, censored)
  div <- kpi_divisor(x$spec, x$grid, per)
  scale <- ifelse(kpi_per_mask(fr$unit), div, 1)
  det <- x$deterministic
  stat <- function(k) {
    v <- as.double(x$kpis[[k]])
    ok <- !is.na(v)
    vv <- v[ok]
    q <- if (length(vv) > 0L) stats::quantile(vv, c(0.05, 0.5, 0.95), type = 7, names = FALSE)
    else rep(NA_real_, 3L)
    c(mean = if (length(vv) > 0L) mean(vv) else NA_real_,
      sd = if (length(vv) > 1L) stats::sd(vv) else NA_real_,
      q05 = q[1L], q50 = q[2L], q95 = q[3L],
      p_neg = if (length(vv) > 0L) mean(vv < 0) else NA_real_,
      na_share = if (length(v) > 0L) mean(!ok) else NA_real_, n_valid = sum(ok))
  }
  stat_names <- c("mean", "sd", "q05", "q50", "q95", "p_neg", "na_share", "n_valid")
  st <- if (length(sel$cols) > 0L) do.call(rbind, lapply(sel$cols, stat)) else
    matrix(numeric(0), 0L, 8L, dimnames = list(NULL, stat_names))
  dval <- vapply(sel$cols, function(k) {
    v <- det$kpis[[k]]
    if (is.null(v)) NA_real_ else as.double(v[1L])
  }, double(1), USE.NAMES = FALSE)
  dna <- vapply(sel$cols, function(k) {
    v <- det$kpi_na[[k]]
    if (is.null(v)) NA_character_ else as.character(v[1L])
  }, "", USE.NAMES = FALSE)
  fr$deterministic <- dval / scale
  for (s in c("mean", "sd", "q05", "q50", "q95")) fr[[s]] <- as.double(st[, s]) / scale
  fr$p_neg <- as.double(st[, "p_neg"])
  fr$na_share <- as.double(st[, "na_share"])
  fr$n_valid <- as.integer(st[, "n_valid"])
  fr$na_reason <- dna
  fr$na_label <- kpi_na_label(dna)
  rownames(fr) <- NULL
  fr
}

#' Kennzahltabelle eines Vergleichs (je Variante und Vergleichskennzahlen)
#' @noRd
kpi_table_comparison <- function(x, which, rv, per) {
  parts <- list()
  for (v in names(x$results)) {
    r <- x$results[[v]]
    which_r <- NULL
    if (!is.null(which)) {
      which_r <- which[which %in% c(names(r$kpis), kpi_base_name(names(r$kpis)))]
      if (length(which_r) == 0L) next
    }
    tab <- vofi_kpis(r, which = which_r, rv = rv, per = per)
    if (inherits(r, "vofi_mc_result")) {
      tab$value <- tab$mean
      tab <- tab[, c("kpi", "base", "label", "unit", "rv", "per", "note", "primary", "value",
                     "na_reason", "na_label"), drop = FALSE]
    } else if ("sim" %in% names(tab)) {
      tab <- tab[tab$sim == 1L, setdiff(names(tab), "sim"), drop = FALSE]
    }
    if (nrow(tab) > 0L) parts[[v]] <- cbind(data.frame(variant = rep(v, nrow(tab))), tab)
  }
  diffs <- x$differences %||% list()
  dnames <- names(diffs)
  if (!is.null(which)) dnames <- dnames[dnames %in% which | kpi_base_name(dnames) %in% which]
  if (length(dnames) > 0L) {
    sel <- kpi_select_columns(dnames, NULL, rv)
    ref_res <- x$results[[x$baseline]] %||% x$results[[1L]]
    div <- kpi_divisor(ref_res$spec, ref_res$grid, per)
    for (k in sel$cols) {
      m <- diffs[[k]]
      vars <- colnames(m) %||% x$variants
      i <- match(k, sel$cols)
      rep_sel <- list(cols = rep(k, length(vars)), rv = rep(sel$rv[i], length(vars)),
                      note = rep(sel$note[i], length(vars)))
      fr <- kpi_table_frame(rep_sel, per, x$results[[1L]]$meta$primary_kpi)
      vals <- vapply(seq_len(ncol(m)), function(j) {
        col <- m[, j]
        if (all(is.na(col))) NA_real_ else mean(col, na.rm = TRUE)
      }, double(1))
      fr$value <- vals / ifelse(kpi_per_mask(fr$unit), div, 1)
      fr$na_reason <- ifelse(is.na(vals), "not_computed", NA_character_)
      fr$na_label <- kpi_na_label(fr$na_reason)
      parts[[paste0(".diff_", k)]] <- cbind(data.frame(variant = vars), fr)
    }
  }
  if (length(parts) == 0L) {
    return(data.frame(variant = character(0), kpi = character(0), base = character(0),
                      label = character(0), unit = character(0), rv = character(0),
                      per = character(0), note = character(0), primary = logical(0),
                      value = double(0), na_reason = character(0), na_label = character(0),
                      stringsAsFactors = FALSE))
  }
  out <- do.call(rbind, unname(parts))
  rownames(out) <- NULL
  out
}

#' Kennzahl registrieren
#'
#' Registriert eine Nutzerkennzahl `compute(core, ctx)` (Spec 00, Abschnitte 5.7, 12.1). Die
#' Funktion erhält das Ergebnis der Periodenschleife `core` (Ledger, Bestände, Markierungen,
#' Raten, Unterlassungsalternative) und den Laufkontext `ctx` und liefert ein
#' [vofi_kpi_value()] mit einem Wert je Lauf (bzw. einer Matrix n × P bei Reihen). Mit
#' `rv_variant = TRUE` wird sie zusätzlich auf der Sicht ohne Restwert als `<name>_ex_rv`
#' berechnet; ohne `rv_variant` gilt sie als restwertunabhängig und trägt in `vofi_kpis()` den
#' Vermerk „unabhängig vom Restwert“ (R-52). Die Kennzahl steht danach in `analysis.kpis` zur
#' Verfügung; Perspektiven außerhalb von `perspectives` ergeben `NA` mit Code
#' `not_applicable_perspective`.
#'
#' @param name Name der Kennzahl (`^[a-z][a-z0-9_]*$`, ohne Endung `_ex_rv`).
#' @param compute Funktion `compute(core, ctx)`, die ein [vofi_kpi_value()] liefert.
#' @param label Anzeigename (Default: `name`).
#' @param unit Einheit aus `inst/vocab/units.yaml`.
#' @param shape `"scalar"` oder `"series"`.
#' @param rv_variant zusätzlich ohne Restwert (`<name>_ex_rv`) berechnen.
#' @param higher_is_better Richtung der Kennzahl (`TRUE`, `FALSE` oder `NA`).
#' @param mc_default standardmäßig in der Simulation berechnen.
#' @param perspectives `NULL` (alle) oder zulässige Perspektiven.
#' @param requires benötigte Daten, Teilmenge von `opportunity`, `market_value`,
#'   `household_income`, `living_area`, `tenant_data`.
#' @param overwrite vorhandene Kennzahl ersetzen.
#' @return `invisible(def)`.
#' @family Erweitern
#' @examples
#' vofi_register_kpi(
#'   "ew_tausend", function(core, ctx) {
#'     vofi_kpi_value(core$stocks$BS[, core$grid$T + 1L] / 1000)
#'   },
#'   label = "Endwert in Tausend Euro", unit = "EUR", overwrite = TRUE
#' )
#' "ew_tausend" %in% vofi_types("kpi")$name
#' @export
vofi_register_kpi <- function(name, compute, label = NULL, unit = "EUR",
                              shape = c("scalar", "series"), rv_variant = FALSE,
                              higher_is_better = TRUE, mc_default = FALSE, perspectives = NULL,
                              requires = character(), overwrite = FALSE) {
  if (!utl_is_string(name) || !utl_is_id(name) || grepl("_ex_rv$", name)) {
    vofi_abort("kpi.errors.register_name", name = utl_collapse(format(name)),
               .class = "vofi_error_registry")
  }
  if (!is.function(compute) || !identical(names(formals(compute)), c("core", "ctx"))) {
    vofi_abort("kpi.errors.register_compute", name = name, .class = "vofi_error_registry")
  }
  shape <- utl_match_arg(shape, c("scalar", "series"), "shape")
  label <- label %||% name
  if (!utl_is_string(label)) {
    vofi_abort("kpi.errors.register_field", name = name, field = "label",
               .class = "vofi_error_registry")
  }
  flags <- list(rv_variant = rv_variant, mc_default = mc_default, overwrite = overwrite)
  for (f in names(flags)) {
    if (!utl_is_flag(flags[[f]])) {
      vofi_abort("kpi.errors.register_field", name = name, field = f,
                 .class = "vofi_error_registry")
    }
  }
  def <- vofi_type(name = name, kind = "kpi", compute = compute, label = label,
                   labels = list(description = label, params = list(), rows = list()),
                   unit = unit, shape = shape, rv_variant = rv_variant,
                   higher_is_better = higher_is_better, mc_default = mc_default,
                   perspectives = perspectives, requires = as.character(requires))
  reg_add(def, source = "user", overwrite = overwrite)
}
