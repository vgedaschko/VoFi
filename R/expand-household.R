# Expander household (WS-E2, Spec 01 Teil B 3.10.2; Spec 00 4.12): Einlage des Ersparten
# h_equity (Typ equity, Block financing) und laufende Einlage h_contrib aus dem Einkommen.
# Belastungs-Hilfszeilen entstehen nicht (die Haushaltskennzahlen waehlen Zeilen ueber burden).

#' Expander household (Teil B 3.10.2)
#' @noRd
household_expand <- function(block, scenario, bctx) {
  x <- scenario
  hh <- block %||% list()
  fin <- list()
  others <- vapply(x$financing %||% list(), function(c) identical(c[["type"]], "equity"),
                   logical(1))
  if (exp_has(x, "household.savings_eur")) {
    if (any(others)) {
      bctx$inform("expand.household.equity_exists", ids = utl_collapse(names(others)[others]))
    } else {
      fin$h_equity <- list(type = "equity", label = bctx$lbl("expand.household.equity_label"),
                           amount_eur = node_ref("household.savings_eur"),
                           date = bctx$grid$valuation_date %||%
                             exp_date(x$project$valuation_date))
    }
  }
  if (exp_has(x, "household.contribution_month_eur")) {
    cmp <- list(type = "equity", label = bctx$lbl("expand.household.contribution_label"),
                contributions_pa = node_expr("household.contribution_month_eur * 12"))
    for (f in c("contribution_from", "contribution_to")) {
      v <- hh[[f]]
      if (is.null(v)) next
      d <- if (identical(v, "completion")) "completion" else exp_date(v, bctx$grid)
      if (!is.null(d)) cmp[[if (f == "contribution_from") "start_event" else "to"]] <- d
    }
    fin$h_contrib <- cmp
  }
  list(components = list(), financing = fin, assets = list(), measures = list())
}

#' @noRd
typedef_expander_household <- function() {
  vofi_type(name = "household", kind = "expander", block = "household", order = 50L,
            expand = household_expand)
}
