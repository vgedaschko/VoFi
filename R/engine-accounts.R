# Konten: Geldanlage, Kontokorrent, Strafzinstranche (WS-D, Spec 00 Abschnitt 8.8).
# acc_init() nach 8.8: Raten als n x (T+1) (effektiv p. a. -> Periodenrate, 3.6), Abgeltungsteuer
# auf positive Habenzinsen oberhalb des Sparer-Pauschbetrags je Periode (wa = Pauschbetrag p. a.
# * delta, R-76), Limit KL (Pfad, .inf zulaessig, fehlt: unbegrenzt), Mindestliquiditaet L_min,
# Markierungsschwelle, Parameter von Ue3 (alle ueber ctx$value(), auch Bezuege und Ausdruecke;
# nicht endliche Werte: N1). Die Raten werden je Kontext einmal berechnet
# (eng_acc_rates(), Zwischenspeicher in der Engine-Umgebung) und von Investition,
# Unterlassungsalternative (sp := s bei D4 equity_call/stop, R-81) und Wiederholungslaeufen
# (ctx$rebalance()) gemeinsam genutzt. Die Markierung arbitrage (h > s, 8.8) setzt die
# Periodenschleife; eng_flag_conditions() meldet sie als vofi_warning_engine.

#' Kontenzustand initialisieren (8.8)
#'
#' Alle Kontoparameter werden über `ctx$value("accounts.<feld>")` aufgelöst (Ziehungen,
#' Bezüge, Ausdrücke; 4.5, 6.3), auch die Parameter von Ü3 (`accounts.prepay.buffer_eur`,
#' `accounts.prepay.min_spread_pa`, Default 0, als n-Vektoren). Nicht endliche Raten, Beträge
#' und Anteile sind `vofi_error_contract` (N1, Quelle `accounts`); das Limit darf `Inf` sein.
#' @param accounts normalisierte Kontoparameter des Modells (`model$accounts`); das Feld
#'   `opp_regular_penalty = TRUE` setzt sp := s (Unterlassungsalternative, 9.5 Nr. 5, R-81).
#' @param ctx Laufkontext.
#' @return Liste nach 8.8 (`G`, `KK`, `KKP` = 0; `h`, `h_pa`, `w`, `wa`, `s`, `s_pa`, `sp`,
#'   `KL`, `Lmin`, `flag_threshold`, `prepay_buffer`, `prepay_min_spread`, `j`).
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
  w <- scalar("deposit_withholding_tax_share")
  allowance <- scalar("deposit_tax_allowance_eur_pa")
  lmin <- path("min_liquidity_eur")
  buffer <- scalar("prepay.buffer_eur")
  min_spread <- scalar("prepay.min_spread_pa")
  eng_check_finite(list(deposit_rate_pa = h_pa, overdraft_rate_pa = s_pa,
                        penalty_spread_pa = spread, deposit_withholding_tax_share = w,
                        deposit_tax_allowance_eur_pa = allowance, min_liquidity_eur = lmin,
                        prepay.buffer_eur = buffer, prepay.min_spread_pa = min_spread),
                   "accounts")
  s <- ctx$rate_eff(s_pa)
  sp <- if (isTRUE(accounts$opp_regular_penalty)) s else ctx$rate_eff(s_pa + spread)
  h <- ctx$rate_eff(h_pa)
  wa <- allowance * ctx$by_period(g$delta)
  wa[, 1L] <- 0
  kl <- ctx$value("accounts.overdraft_limit_eur", "path")
  kl <- if (is.null(kl)) matrix(Inf, n, g$T + 1L) else acc_strip_attr(kl)
  thr <- ctx$value("accounts.overdraft_flag_threshold_eur", "scalar") %||% rep(Inf, n)
  # Limit und Markierungsschwelle: +Inf zulaessig (unbegrenzt), NA/NaN/-Inf nicht
  if (anyNA(kl) || any(kl == -Inf)) acc_abort_not_finite("overdraft_limit_eur")
  if (anyNA(thr)) acc_abort_not_finite("overdraft_flag_threshold_eur")
  list(
    G = rep(0, n), KK = rep(0, n), KKP = rep(0, n),
    h = h, h_pa = h_pa, w = w, wa = wa,
    s = s, s_pa = s_pa, sp = sp, KL = kl, Lmin = lmin,
    flag_threshold = thr, prepay_buffer = buffer, prepay_min_spread = min_spread, j = 1L
  )
}

#' Nicht zulässiger Kontoparameter (N1, 9.7)
#' @noRd
acc_abort_not_finite <- function(field) {
  vofi_abort("engine.return_not_finite", what = field, source = "accounts",
             .class = "vofi_error_contract",
             .data = list(invariant = "N1", source = "accounts", row = field))
}

#' Kontenzustand mit Zwischenspeicher je Kontext (8.8, Leistung 9.10)
#'
#' Investition, Unterlassungsalternative und Wiederholungsläufe eines Chunks nutzen dieselben
#' Raten (gleicher Kontext, CRN); nur sp weicht in der Alternative ab (R-81).
#' @param model `vofi_model` (bzw. Modell der Unterlassungsalternative).
#' @param ctx Laufkontext.
#' @param engine_env private Engine-Umgebung oder `NULL` (ohne Zwischenspeicher).
#' @return Kontenzustand wie `acc_init()`.
#' @noRd
eng_acc_rates <- function(model, ctx, engine_env = NULL) {
  base <- if (is.environment(engine_env)) engine_env$acc_rates else NULL
  if (is.null(base)) {
    base <- acc_init(acc_modify(model$accounts, opp_regular_penalty = FALSE), ctx)
    if (is.environment(engine_env)) engine_env$acc_rates <- base
  }
  if (isTRUE(model$accounts$opp_regular_penalty)) base$sp <- base$s
  base
}

#' Feld einer Liste setzen (auch bei `NULL`-Liste)
#' @noRd
acc_modify <- function(x, ...) {
  x <- x %||% list()
  args <- list(...)
  for (nm in names(args)) x[nm] <- list(args[[nm]])
  x
}

#' Pfadattribute entfernen (Kontoraten werden nicht weiter indexiert)
#' @noRd
acc_strip_attr <- function(x) {
  attr(x, "annual_before") <- NULL
  attr(x, "path") <- NULL
  x
}
