# Konten: Geldanlage, Kontokorrent, Strafzinstranche (WS-D, Spec 00 Abschnitt 8.8).
# Phase-0-Minimalfassung, Eigentuemer: WS-D. acc_init() nach 8.8 vollstaendig (Raten als
# n x (T+1), Sparer-Pauschbetrag je Periode, Limit- und Reservepfade); die Markierung
# arbitrage (s < h) meldet eng_flag_conditions() als vofi_warning_engine (einmal je Lauf, 9.8).
# Offen fuer WS-D: Pruefung der Kontoparameter in der Validierung statt zur Laufzeit.

#' Kontenzustand initialisieren (8.8)
#' @param accounts normalisierte Kontoparameter des Modells (`model$accounts`); das Feld
#'   `opp_regular_penalty = TRUE` setzt sp := s (Unterlassungsalternative, 9.5 Nr. 5, R-81).
#' @param ctx Laufkontext.
#' @return Liste nach 8.8.
#' @noRd
acc_init <- function(accounts, ctx) {
  n <- ctx$n
  g <- ctx$grid
  path <- function(f) {
    v <- ctx$value(paste0("accounts.", f), "path")
    if (is.null(v)) ctx$zeros() else acc_strip_attr(v)
  }
  scalar <- function(f, default = 0) {
    v <- ctx$value(paste0("accounts.", f), "scalar")
    if (is.null(v)) rep(default, n) else v
  }
  h_pa <- path("deposit_rate_pa")
  s_pa <- path("overdraft_rate_pa")
  spread <- path("penalty_spread_pa")
  s <- ctx$rate_eff(s_pa)
  sp <- if (isTRUE(accounts$opp_regular_penalty)) s else ctx$rate_eff(s_pa + spread)
  h <- ctx$rate_eff(h_pa)
  wa <- scalar("deposit_tax_allowance_eur_pa") * ctx$by_period(g$delta)
  wa[, 1L] <- 0
  kl <- path("overdraft_limit_eur")
  if (identical(ctx$value("accounts.overdraft_limit_eur", "path"), NULL)) kl[] <- Inf
  thr <- ctx$value("accounts.overdraft_flag_threshold_eur", "scalar") %||% rep(Inf, n)
  prepay <- accounts$prepay %||% list()
  list(
    G = rep(0, n), KK = rep(0, n), KKP = rep(0, n),
    h = h, h_pa = h_pa, w = scalar("deposit_withholding_tax_share"), wa = wa,
    s = s, s_pa = s_pa, sp = sp, KL = kl, Lmin = path("min_liquidity_eur"),
    flag_threshold = thr, prepay_buffer = acc_prepay_value(prepay$buffer_eur),
    prepay_min_spread = acc_prepay_value(prepay$min_spread_pa), j = 1L
  )
}

#' Pfadattribute entfernen (Kontoraten werden nicht weiter indexiert)
#' @noRd
acc_strip_attr <- function(x) {
  attr(x, "annual_before") <- NULL
  attr(x, "path") <- NULL
  x
}

#' Parameter von Ü3 (accounts.prepay) als Zahl
#' @noRd
acc_prepay_value <- function(x) {
  if (is.null(x)) return(0)
  if (node_is(x)) return(as.double(x$value %||% 0))
  as.double(x)
}
