# Unterlassungsalternative (WS-D, Spec 00 Abschnitt 9.5).
# Phase 0: Stub von vofi_opportunity() (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-D. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).
# Phase-0-Minimalfassung, Eigentuemer: WS-D: eng_opportunity() nach 9.5 Nr. 1-7 (Einlagen und
# Entnahmen der Investition, Nachschuesse als opp_equity_call_in, keine Projekt- und
# Foerderzeilen, keine Instrumente, Ketten ohne loan_prepay, D4 equity_call/stop -> penalty_rate
# zum Regelzins s (R-61, R-81), Verkauf des Bestands bei Sacheinlage, Markierung
# opp_limit_breach mit Warnung). Offen fuer WS-D: vofi_opportunity() als vofi_result.

#' Unterlassungsalternative eines Laufs (9.5)
#'
#' Phase-0-Minimalfassung, Eigentümer: WS-D.
#' @param model `vofi_model`.
#' @param ctx Laufkontext der Investition (dieselben Ziehungen, CRN).
#' @param core core der Investition.
#' @return `list(BS = n x (T+1), EW = n, ledger = <vofi_ledger>, limit_breach = lgl n)`.
#' @noRd
eng_opportunity <- function(model, ctx, core) {
  led <- core$ledger
  n <- ctx$n
  n_t <- ctx$T + 1L
  keys <- led$rows$key[led$rows$section == "equity" &
                         led$rows$category %in% c("equity_in", "equity_out") &
                         led$rows$source_id != "engine"]
  rows <- led$rows[match(keys, led$rows$key), , drop = FALSE]
  values <- led$values[keys]
  calls <- led$values$equity_call + led$values$shortfall
  extra <- new_ledger_rows("opp_equity_call_in", "equity", "equity_in",
                           local_row = "opp_equity_call_in",
                           label_key = "core.rows.opp_equity_call_in",
                           label = lbl("core.rows.opp_equity_call_in"))
  rows <- rbind(rows, extra)
  values$opp_equity_call_in <- calls
  ev <- ctx$value_base("building.existing_value_eur", "scalar")
  if (!is.null(ev)) {
    sale_share <- ctx$value_base("residual_value.sale_cost_share", "scalar") %||% rep(0, n)
    assumed <- Reduce(`+`, led$values[ledger_select(led, category = "assumed")],
                      matrix(0, n, n_t))[, 1L]
    sale <- matrix(0, n, n_t)
    sale[, 1L] <- ev * (1 - sale_share) - assumed
    pos <- all(sale[, 1L] >= 0)
    sale_row <- new_ledger_rows("opp_in_kind_sale", "equity",
                                if (pos) "equity_in" else "equity_out",
                                local_row = "opp_in_kind_sale",
                                label_key = "core.rows.opp_in_kind_sale",
                                label = lbl("core.rows.opp_in_kind_sale"))
    rows <- rbind(rows, sale_row)
    values$opp_in_kind_sale <- sale
  }
  ord <- order(rows$order, method = "radix")
  rows <- rows[ord, , drop = FALSE]
  rownames(rows) <- NULL
  exo <- new_vofi_ledger(rows, values[rows$key], n = n, T = ctx$T)
  m <- model
  m$instruments <- list()
  m$surplus_chain <- m$surplus_chain[names(m$surplus_chain) != "loan_prepay"]
  d4 <- names(m$deficit_chain)[length(m$deficit_chain)]
  if (d4 %in% c("equity_call", "stop")) {
    m$deficit_chain[[length(m$deficit_chain)]] <- reg_get("account_action", "penalty_rate")
    names(m$deficit_chain)[length(m$deficit_chain)] <- "penalty_rate"
    m$accounts$opp_regular_penalty <- TRUE
  }
  oc <- eng_balance(m, ctx, exo, book = TRUE, engine_env = NULL)
  breach <- rowSums(oc$stocks$KKP > vofi_tol$zero_abs) > 0
  if (any(breach)) {
    vofi_warn("engine.opp_limit_breach", share = mean(breach), .class = "vofi_warning_plausibility")
  }
  list(BS = oc$stocks$BS, EW = oc$stocks$BS[, n_t], ledger = oc$ledger, limit_breach = breach)
}

#' Unterlassungsalternative
#'
#' Berechnet die Unterlassungsalternative zu einem Modell oder Ergebnis: gleiche Einlagen
#' inklusive Nachschüsse der Investition und gleiche Entnahmen, keine Investition, keine Kredite,
#' keine eigenen Nachschüsse (Spec 00, Abschnitt 9.5).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Objekt der Klasse `vofi_model` oder `vofi_result`.
#' @return Objekt der Klasse `vofi_result`.
#' @family Rechnen
#' @export
vofi_opportunity <- function(x) {
  vofi_abort("core.not_implemented", fun = "vofi_opportunity",
             .class = "vofi_error_not_implemented")
}
