# Kennzahlen-Registry und Ausgabe (WS-D2, Spec 00 Abschnitt 12).
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-D2. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).
# Phase-0-Minimalfassung, Eigentuemer: WS-D2: kpi_compute() und core_ex_rv() (12.1) sind
# umgesetzt (Sicht mit und ohne Restwert, Spalten <name> und <name>_ex_rv); vofi_kpis() und
# vofi_register_kpi() bleiben Stubs fuer Welle 2.

#' Kennzahlen eines Chunks berechnen (12.1)
#'
#' Phase-0-Minimalfassung, Eigentümer: WS-D2.
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
    if (isTRUE(def$rv_variant)) {
      if (is.null(ex)) ex <- core_ex_rv(core)
      views[[2L]] <- list(suffix = "_ex_rv", core = ex)
    }
    for (v in views) {
      res <- def$compute(v$core, ctx)
      if (!inherits(res, "vofi_kpi_value")) {
        vofi_abort("kpi.not_kpi_value", kpi = def$name, .class = "vofi_error_contract")
      }
      nm <- paste0(def$name, v$suffix)
      if (identical(res$shape, "series")) {
        series[[nm]] <- list(values = res$values, years = res$years)
        next
      }
      if (length(res$values) != n) {
        vofi_abort("kpi.length", kpi = nm, n = n, .class = "vofi_error_contract")
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

#' Sicht ohne Restwert (12.1, 9.4)
#'
#' Phase-0-Minimalfassung, Eigentümer: WS-D2. BS, G, KK, KKP in T aus `terminal_ex_rv`,
#' Restwertzeilen in T+1 auf 0, `view = "ex_rv"`; Einlagen und Nachschüsse unverändert.
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

#' Kennzahlen eines Ergebnisses
#'
#' Liefert die Kennzahlen eines Ergebnisses mit Bezeichnung, Einheit und NA-Begründung;
#' EUR-Kennzahlen optional je Wohneinheit bzw. je m² Wohnfläche (Spec 00, Abschnitt 12).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param x Objekt der Klasse `vofi_result`, `vofi_mc_result` oder `vofi_comparison`.
#' @param which `NULL` (alle) oder Namen von Kennzahlen.
#' @param rv `"both"`, `"with"` (mit Restwert) oder `"without"` (ohne Restwert).
#' @param per `"total"`, `"unit"` (je Wohneinheit) oder `"m2"` (je m² Wohnfläche).
#' @return Data Frame der Kennzahlen.
#' @family Analysieren
#' @export
vofi_kpis <- function(x, which = NULL, rv = c("both", "with", "without"),
                      per = c("total", "unit", "m2")) {
  vofi_abort("core.not_implemented", fun = "vofi_kpis",
             .class = "vofi_error_not_implemented")
}

#' Kennzahl registrieren
#'
#' Registriert eine Nutzerkennzahl `compute(core, ctx)` (Spec 00, Abschnitte 5.7, 12.1).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param name Name der Kennzahl.
#' @param compute Funktion `compute(core, ctx)`, die ein [vofi_kpi_value()] liefert.
#' @param label Anzeigename.
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
#' @export
vofi_register_kpi <- function(name, compute, label = NULL, unit = "EUR",
                              shape = c("scalar", "series"), rv_variant = FALSE,
                              higher_is_better = TRUE, mc_default = FALSE, perspectives = NULL,
                              requires = character(), overwrite = FALSE) {
  vofi_abort("core.not_implemented", fun = "vofi_register_kpi",
             .class = "vofi_error_not_implemented")
}
