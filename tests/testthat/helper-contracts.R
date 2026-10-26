# Testhelfer (Integrator, Spec 00 Abschnitt 15.1): dünne Hüllen um das Prüfkit
# R/registry-testkit.R (5.6). Alle Helfer laufen im Namensraum des Pakets (interne Funktionen sind
# sichtbar).

#' Prüfraster: "annual" (Jahresraster, H = T), "mixed" (Bauphase 9 Monate monatlich, dann
#' Kalenderjahre, Horizont T Jahre), "oracle_e" (Orakel (e): 3, 3, 3, 3, 12, 12, 12; C = 12).
make_grid <- function(type = c("annual", "mixed", "oracle_e"), T = 6L, # nolint
                      valuation_date = as.Date("2027-01-01")) {
  type <- match.arg(type)
  switch(type,
    annual = vofi_time_grid(valuation_date, as.integer(T)),
    mixed = vofi_time_grid(valuation_date, as.integer(T), construction_months = 9L,
                           construction_step_months = 1L, operation_alignment = "calendar"),
    oracle_e = vofi_time_grid(valuation_date, NULL, construction_months = 12L,
                              periods_months = c(3L, 3L, 3L, 3L, 12L, 12L, 12L))
  )
}

#' Sammlung einer Komponente nach ihrem Typ
helper_collection <- function(comp) {
  type <- comp[["type"]] %||% ""
  if (identical(type, "equity") || reg_has("instrument", type)) "financing" else "components"
}

#' Normalisierte Komponente eines registrierten Typs (Rohparameter wie in YAML)
make_component <- function(type, ..., id = "x", kind = NULL) {
  kind <- kind %||% (if (reg_has("flow", type)) "flow" else "instrument")
  def <- reg_get(kind, type)
  reg_example_component(def, c(list(type = type), list(...)), id = id)
}

#' Spezifikation des Prüfkits
make_spec <- function(grid = make_grid(), ...) reg_test_spec(grid, ...)

#' Laufkontext für Tests (Spec 00 Abschnitt 15.1)
#'
#' `spec`: `NULL`, ein `vofi_spec` oder eine einzelne normalisierte Komponente (aus
#' `make_component()`), die unter `components.<id>` bzw. `financing.<id>` eingesetzt wird.
#' `params`: benannte Liste Pfad -> Rohwert (z. B. `"project.construction_delay_months" = 3`).
#' `market`: rohe Marktannahmen, die über den Prüfkit-Markt gemischt werden.
#' `draws`: `vofi_draws` (z. B. aus `fake_draws()`); ohne `draws` und mit `n > 1` werden leere
#' Ziehungen im Modus "mc" verwendet.
make_ctx <- function(n = 1L, grid = make_grid(), spec = NULL, params = list(), market = list(),
                     draws = NULL, components = list(), perspective = "wu_kommunal",
                     legal_state = as.Date("2026-10-25")) {
  if (!inherits(spec, "vofi_spec")) {
    comp <- spec
    spec <- reg_test_spec(grid, perspective = perspective, legal_state = legal_state,
                          market = deep_merge(reg_test_market_raw(), market))
    if (!is.null(comp)) spec <- path_set(spec, path_join(helper_collection(comp), comp$id), comp)
  }
  for (p in names(params)) spec <- path_set(spec, p, reg_node(params[[p]], p))
  n <- as.integer(n)
  if (is.null(draws) && n > 1L) draws <- fake_draws(n, grid)
  mode <- if (is.null(draws)) "deterministic" else draws$mode
  eng_context_from_parts(grid, spec, draws = draws, components = components,
                         components_base = components, mode = mode,
                         engine_env = reg_engine_env("flows"))
}

#' Ziehungen mit vorgegebenen Werten (names = Zielpfade, flach nach 4.13)
#'
#' `static`: Liste Ziel -> Skalar oder n-Vektor; `paths`: Liste Ziel -> Vektor der Länge T+1
#' oder Matrix n x (T+1).
fake_draws <- function(n, grid, static = list(), paths = list(), mode = "mc") {
  n <- as.integer(n)
  st <- lapply(static, function(v) rep_len(as.double(v), n))
  pa <- lapply(paths, function(m) {
    if (is.matrix(m)) m else matrix(as.double(m), n, grid$T + 1L, byrow = TRUE)
  })
  keys <- c(names(st), names(pa))
  targets <- data.frame(key = keys, target = keys,
                        kind = c(rep("static", length(st)), rep("process", length(pa))),
                        stringsAsFactors = FALSE)
  new_vofi_draws(mode, n = n, sims = seq_len(n), blocks = 1L, block_size = n, static = st,
                 paths = pa, targets = targets, years = grid$years)
}

#' Zeile prüfen: Klasse, Dimension n x (T+1), double, endlich
expect_vofi_row <- function(row, n, T) { # nolint
  testthat::expect_s3_class(row, "vofi_row")
  testthat::expect_identical(dim(row$values), c(as.integer(n), as.integer(T) + 1L))
  testthat::expect_true(is.double(row$values))
  testthat::expect_true(all(is.finite(row$values)))
  invisible(row)
}

#' Rückgabe einer Zahlungskomponente gegen F1-F6, F9 prüfen
expect_vofi_flows_contract <- function(flows, ctx, def = NULL) {
  if (is.null(def)) {
    keys <- if (inherits(flows, "vofi_flows")) vapply(flows$rows, function(r) r$key, "") else
      character(0)
    def <- list(name = "?", rows = keys)
  }
  f <- reg_flow_findings(flows, ctx, def, ctx$n, ctx$grid, "")
  bad <- f[!f$ok, , drop = FALSE]
  testthat::expect(nrow(bad) == 0L,
                   paste(c("Vertragsverletzung:", paste(bad$check, bad$message)), collapse = "\n"))
  invisible(flows)
}

#' Vertragstests eines registrierten Typs (ruft vofi_check_type())
expect_type_contract <- function(name, kind = NULL) {
  err <- tryCatch({
    vofi_check_type(name, kind)
    NULL
  }, error = function(e) e)
  testthat::expect(is.null(err), if (is.null(err)) "" else conditionMessage(err))
  invisible(is.null(err))
}

#' Werte eines Ergebnisses für Laufvergleiche abflachen
helper_run_values <- function(x) {
  if (inherits(x, "vofi_flows")) return(reg_row_values(x))
  if (inherits(x, "vofi_kpi_value")) return(list(v = x$values))
  if (is.list(x)) return(x)
  list(v = x)
}

#' Batch-Invarianz: `fun(n, draws)` liefert ein Ergebnis für n Läufe (vofi_flows,
#' vofi_kpi_value, Matrix n x ., Vektor der Länge n oder benannte Liste davon); Lauf i des
#' Batches muss dem Einzellauf mit den Ziehungen von Lauf i entsprechen (relativ `tol`).
expect_batch_invariance <- function(fun, n = 7L, grid = make_grid(), draws = NULL,
                                    tol = 1e-12) {
  n <- as.integer(n)
  draws <- draws %||% fake_draws(n, grid)
  batch <- helper_run_values(fun(n, draws))
  ok <- vapply(seq_len(n), function(i) {
    single <- helper_run_values(fun(1L, reg_draws_subset(draws, i)))
    reg_same_run(batch, single, i, tol)
  }, logical(1))
  testthat::expect(all(ok), paste("Batch-Invarianz verletzt in Lauf",
                                  utl_collapse(which(!ok))))
  invisible(all(ok))
}

#' Ausdruck darf den globalen RNG-Zustand nicht verändern (F8)
expect_no_rng <- function(expr) {
  before <- reg_rng_state()
  force(expr)
  testthat::expect(identical(before, reg_rng_state()),
                   "Der Ausdruck verändert .Random.seed.")
  invisible(TRUE)
}

#' Invarianten I1, I2, I3a, I3b, N1 eines Ledgers bzw. Ergebnisses als Data Frame
helper_invariants <- function(x, tol = vofi_tol, lmin_zero = TRUE) {
  led <- if (inherits(x, "vofi_ledger")) x else x$ledger
  rows <- led$rows
  v <- led$values
  n <- led$n
  z <- matrix(0, n, led$T + 1L)
  pick <- function(sel) if (any(sel)) Reduce(`+`, v[rows$key[sel]]) else z
  bal_secs <- c("project", "grants", "equity", "loans", "overdraft", "deposit", "tax")
  cash <- rows$cash & rows$section %in% bal_secs
  saldo <- pick(cash)
  vol <- apply(abs(do.call(cbind, lapply(v[rows$key[cash]], function(m) m))), 1L, max)
  vol <- if (length(vol) == 0L) rep(1, n) else pmax(1, vol)
  i1 <- max(abs(saldo) / vol, 0)
  bs <- v[["net_position"]] %||% z
  d_bs <- bs - cbind(0, bs[, -ncol(bs), drop = FALSE])
  flow <- pick(cash & rows$tax_category != "principal") +
    pick(rows$category == "repayment_grant") - pick(rows$category == "disagio") -
    pick(rows$category == "assumed")
  tl <- v[["tax_liability"]] %||% z
  flow <- flow - (tl - cbind(0, tl[, -ncol(tl), drop = FALSE]))
  i2 <- max(abs(d_bs - flow) / vol, 0)
  stocks <- rows$key[rows$section == "stocks" & rows$category == "balance"]
  i3a <- if (length(stocks) > 0L) max(-min(unlist(lapply(v[stocks], min))), 0) else 0
  g <- v[["dep_balance"]] %||% z
  kk <- (v[["od_balance"]] %||% z) + (v[["odp_balance"]] %||% z)
  i3b <- if (lmin_zero) max(pmin(g, kk), 0) else 0
  n1 <- all(vapply(v, function(m) all(is.finite(m)), logical(1)))
  out <- data.frame(
    invariant = c("I1", "I2", "I3a", "I3b", "N1"),
    max_dev = c(i1, i2, i3a, i3b, if (n1) 0 else Inf),
    tol = c(tol$balance_rel, tol$balance_rel, tol$stock_abs, tol$stock_abs, 0),
    stringsAsFactors = FALSE
  )
  out$ok <- out$max_dev <= out$tol
  out
}

#' Invarianten I1-I3, N1 (und N2 über `checks`, falls vorhanden) prüfen
expect_vofi_invariants <- function(x, tol = vofi_tol) {
  inv <- helper_invariants(x, tol)
  bad <- inv[!inv$ok, , drop = FALSE]
  if (!is.null(x$checks) && is.data.frame(x$checks)) {
    bad <- rbind(bad, x$checks[!x$checks$ok, c("invariant", "max_dev", "tol", "ok")])
  }
  testthat::expect(nrow(bad) == 0L,
                   paste("Invarianten verletzt:", utl_collapse(paste0(bad$invariant, " (",
                                                                       bad$max_dev, ")"))))
  invisible(x)
}

#' Code mit strikten Labels ausführen (fehlende Schlüssel und Platzhalter sind Fehler)
with_strict_labels <- function(code) {
  old <- options(vofi.strict_labels = TRUE)
  on.exit(options(old), add = TRUE)
  force(code)
}

#' vofi-Optionen lokal setzen (bis zum Ende des aufrufenden Tests)
local_vofi_options <- function(..., .env = parent.frame()) {
  opts <- list(...)
  old <- options(opts)
  # withr ist über testthat immer verfügbar (testthat importiert withr)
  withr::defer(options(old), envir = .env)
  invisible(old)
}

#' Ist eine Funktion des Pakets noch ein Stub (Phase 0)?
is_stub <- function(fun) {
  f <- get(fun, envir = asNamespace("vofi"))
  any(grepl("core.not_implemented", deparse(body(f)), fixed = TRUE))
}

#' Test überspringen, solange eine der Funktionen ein Stub ist
skip_if_stub <- function(...) {
  for (fun in c(...)) {
    if (is_stub(fun)) testthat::skip(paste0(fun, "() ist noch ein Stub (Phase 0)"))
  }
  invisible(TRUE)
}
