# Unterlassungsalternative (WS-D, Spec 00 Abschnitt 9.5).
# Exogen: die Einlagen und Entnahmen der Investition unveraendert, deren Nachschuesse und
# Fehlbetraege als Einlage opp_equity_call_in (9.5 Nr. 1, Memo 01 K11); bei Sacheinlage statt
# equity_in_kind der Verkauf des Bestands zum Stichtag nach Verkaufskosten und Abloesung der
# Bestandsdarlehen (opp_in_kind_sale, Basisfallwerte, 9.5 Nr. 7, R-68). Keine Projekt- und
# Foerderzeilen, keine Instrumente, Ketten ohne loan_prepay (Nr. 2); identische Konten,
# Steuermodul und Ziehungen (Nr. 3, 4: derselbe Kontext, CRN). Keine eigenen Nachschuesse
# (R-61): eine D4-Aktion mit Zufluss von aussen (equity_call, stop) wird zu penalty_rate mit
# Regelzins s (R-81); Nutzung der Strafzinstranche setzt opp_limit_breach (Meldung in
# eng_flag_conditions(), einmal je Lauf).

#' Modell der Unterlassungsalternative (9.5 Nr. 2, 3, 5)
#' @param model `vofi_model` der Investition.
#' @return Modell ohne Instrumente mit angepassten Ketten.
#' @noRd
eng_opportunity_model <- function(model) {
  m <- model
  m$instruments <- list()
  keep <- vapply(m$surplus_chain, function(a) !("loan_*_prepay" %in% a$rows), logical(1))
  m$surplus_chain <- m$surplus_chain[keep]
  nd <- length(m$deficit_chain)
  if (nd > 0L && eng_action_external(m$deficit_chain[[nd]])) {
    m$deficit_chain[[nd]] <- reg_get("account_action", "penalty_rate")
    names(m$deficit_chain)[nd] <- "penalty_rate"
    m$accounts$opp_regular_penalty <- TRUE
  }
  m
}

#' Exogener Ledger der Unterlassungsalternative (9.5 Nr. 1, 7)
#' @param ctx Laufkontext der Investition.
#' @param led Ledger der Investition.
#' @param opp_rows vorbereitete Zeilenmetadaten (`eng_model_rows(opp = TRUE)$opp_rows`) oder
#'   `NULL` (dann neu erzeugt).
#' @return `vofi_ledger`.
#' @noRd
eng_opportunity_exo <- function(ctx, led, opp_rows = NULL) {
  n <- ctx$n
  n_t <- ctx$T + 1L
  r <- led$rows
  keys <- r$key[r$section == "equity" & r$category %in% c("equity_in", "equity_out") &
                  r$source_id != "engine"]
  rows <- r[match(keys, r$key), , drop = FALSE]
  values <- led$values[keys]
  if (is.null(opp_rows)) opp_rows <- eng_model_rows(list(), opp = TRUE)$opp_rows
  extra <- list(opp_rows$call_in)
  values$opp_equity_call_in <- led$values$equity_call + led$values$shortfall
  ev <- ctx$value_base("building.existing_value_eur", "scalar")
  if (!is.null(ev)) {
    sale_share <- ctx$value_base("residual_value.sale_cost_share", "scalar") %||% rep(0, n)
    assumed <- ledger_sum(led, category = "assumed")[, 1L]
    sale <- matrix(0, n, n_t)
    sale[, 1L] <- ev * (1 - sale_share) - assumed
    # Basisfallwerte: in allen Laeufen gleich, das Vorzeichen bestimmt die Kategorie (9.5 Nr. 7)
    extra[[2L]] <- if (all(sale[, 1L] >= 0)) opp_rows$sale_in else opp_rows$sale_out
    values$opp_in_kind_sale <- sale
  }
  rows <- eng_bind_rows(c(list(rows), extra))
  ord <- order(rows$order, method = "radix")
  rows <- rows[ord, , drop = FALSE]
  rownames(rows) <- NULL
  new_vofi_ledger(rows, values[rows$key], n = n, T = ctx$T)
}

#' Unterlassungsalternative eines Laufs (9.5)
#'
#' @param model `vofi_model`.
#' @param ctx Laufkontext der Investition (dieselben Ziehungen, CRN).
#' @param core core der Investition.
#' @param engine_env private Engine-Umgebung (gemeinsame Kontoraten) oder `NULL`.
#' @return `list(BS = n x (T+1), EW = n, ledger = <vofi_ledger>, limit_breach = lgl n,
#'   core = <core der Alternative>)`.
#' @noRd
eng_opportunity <- function(model, ctx, core, engine_env = NULL) {
  n_t <- ctx$T + 1L
  exo <- eng_opportunity_exo(ctx, core$ledger, model$rows_meta$opp$opp_rows)
  m <- eng_opportunity_model(model)
  oc <- eng_balance(m, ctx, exo, book = TRUE, engine_env = engine_env, setup_key = "opp")
  breach <- rowSums(oc$stocks$KKP > vofi_tol$zero_abs) > 0
  list(BS = oc$stocks$BS, EW = oc$stocks$BS[, n_t], ledger = oc$ledger, limit_breach = breach,
       core = oc)
}

#' Unterlassungsalternative
#'
#' Berechnet die Unterlassungsalternative zu einem Modell oder Ergebnis: gleiche Einlagen
#' inklusive der Nachschüsse der Investition und gleiche Entnahmen, keine Investition, keine
#' Kredite, keine eigenen Nachschüsse; bei einer Sacheinlage der Verkauf des Bestands zum
#' Stichtag (Spec 00, Abschnitt 9.5). Das Ergebnis enthält den vollständigen VoFi der
#' Alternative (Abschnitte Eigenkapital, Kontokorrent, Geldanlage, Steuern, Prüfung, Bestände)
#' mit der Kennzahl `terminal_value` = EW_U.
#'
#' @param x Objekt der Klasse `vofi_model` (deterministischer Lauf) oder `vofi_result`.
#' @return Objekt der Klasse `vofi_result`.
#' @family Rechnen
#' @examples
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
#' opp <- vofi_opportunity(res)
#' opp$kpis$terminal_value
#' @export
vofi_opportunity <- function(x) {
  if (inherits(x, "vofi_model")) x <- vofi_run(x)
  if (!inherits(x, "vofi_result")) {
    vofi_abort("engine.not_result", arg = "x", .class = "vofi_error_input")
  }
  op <- x$opportunity
  if (is.null(op) || !inherits(op$ledger, "vofi_ledger")) {
    vofi_abort("engine.opportunity_missing", .class = "vofi_error_input")
  }
  led <- op$ledger
  n <- led$n
  ew <- as.double(op$EW)
  kpis <- data.frame(terminal_value = ew, terminal_value_ex_rv = ew)
  kpi_na <- data.frame(terminal_value = rep(NA_character_, n),
                       terminal_value_ex_rv = rep(NA_character_, n), stringsAsFactors = FALSE)
  checks <- op$checks %||% eng_checks(list(ledger = led,
                                           terminal_ex_rv = list(BS = ew, rv = rep(0, n)),
                                           limits = NULL), stop_on_error = FALSE)
  flags <- op$flags %||% x$flags
  meta <- x$meta
  meta$alternative <- "opportunity"
  meta$notes <- c(meta$notes, lbl("engine.opportunity_note"))
  new_vofi_result(list(
    spec = x$spec, grid = x$grid, model_hash = x$model_hash, ledger = led, kpis = kpis,
    kpi_na = kpi_na, kpi_series = list(), opportunity = NULL, checks = checks, flags = flags,
    registers = x$registers, draws = x$draws, decision = NULL, traffic_light = NULL,
    meta = meta
  ))
}
