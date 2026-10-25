# Datei von WS-D.
# Phase 0: Stubs der exportierten Funktionen (Spec 00, Abschnitte 2.6 Nr. 2 und 14).
# Eigentuemer: WS-D. Der Eigentuemer ersetzt nur den Rumpf; die Signatur ist
# verbindlich (tests/testthat/test-api.R).

#' Steuermodul registrieren
#'
#' Registriert ein Fremd-Steuermodul; es liefert S3-Methoden für [tax_init()], [tax_step()] und
#' [tax_finalize()] (Spec 00, Abschnitt 10.2).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param name Name des Moduls.
#' @param constructor Funktion `constructor(params, spec)`, die das Modulobjekt liefert.
#' @param label Anzeigename.
#' @param perspectives `NULL` (alle) oder zulässige Perspektiven.
#' @param blocked_regimes gesperrte Steuerregime.
#' @param params Parameterschema (benannte Liste von [vofi_param()]).
#' @param overwrite vorhandenes Modul ersetzen.
#' @return `invisible(def)`.
#' @family Erweitern
#' @export
vofi_register_tax_module <- function(name, constructor, label = NULL, perspectives = NULL,
                                     blocked_regimes = NULL, params = list(), overwrite = FALSE) {
  vofi_abort("core.not_implemented", fun = "vofi_register_tax_module",
             .class = "vofi_error_not_implemented")
}

#' Vereinfachtes Steuermodul
#'
#' Erzeugt und registriert ein Steuermodul ohne Zustand, das periodenweise rechnet: `fun(inputs,
#' params)` liefert die Steuerzahlung der Periode (nur für Experimente; sieht keine endogenen
#' Zinsen; Spec 00, Abschnitt 10.2).
#'
#' Phase 0: noch nicht implementiert (Fehler `vofi_error_not_implemented`).
#'
#' @param name Name des Moduls.
#' @param fun Funktion `fun(inputs, params)` -> n-Vektor der Zahlung.
#' @param label Anzeigename.
#' @return `invisible(def)`.
#' @family Erweitern
#' @export
vofi_tax_module_simple <- function(name, fun, label = NULL) {
  vofi_abort("core.not_implemented", fun = "vofi_tax_module_simple",
             .class = "vofi_error_not_implemented")
}
#' Steuermodul-Objekt (intern, Spec 00 Abschnitt 10.2)
#' @param name Name des Moduls; die S3-Klasse ist `tax_<name>`.
#' @param params Parameter des Moduls.
#' @param ... weitere Felder.
#' @return Objekt der Klasse `c("tax_<name>", "vofi_tax_module")`.
#' @noRd
new_tax_module <- function(name, params = list(), ...) {
  structure(list(name = name, params = params, ...),
            class = c(paste0("tax_", name), "vofi_tax_module"))
}

#' Steuer-Hook: Initialisierung
#'
#' S3-Generic des Steuer-Hooks (Spec 00, Abschnitte 10.3, 10.4). Liefert den Anfangszustand des
#' Steuermoduls; die Elemente sind n-Vektoren oder Skalare. Die Default-Methode meldet einen
#' Fehler der Klasse `vofi_error_registry` (keine Methode für das Modul).
#'
#' @param module Steuermodul (Klasse `tax_<name>`).
#' @param params Parameter des Moduls.
#' @param assets Anlagenregister (Liste von [vofi_asset()]).
#' @param measures Maßnahmenregister (Liste von [vofi_measure()]).
#' @param n_sim Anzahl der Läufe n.
#' @return Zustand (Liste).
#' @family Erweitern
#' @export
tax_init <- function(module, params, assets, measures, n_sim) {
  UseMethod("tax_init")
}

#' @rdname tax_init
#' @export
tax_init.default <- function(module, params, assets, measures, n_sim) {
  vofi_abort("core.registry.tax_no_method", fun = "tax_init",
             module = utl_collapse(class(module)), .class = "vofi_error_registry")
}

#' Steuer-Hook: Steuer der Periode
#'
#' S3-Generic des Steuer-Hooks (Spec 00, Abschnitte 10.3–10.5). Berechnet die Steuerzahlung der
#' Periode t (positiv = Zahlung, negativ = Erstattung); die Engine bucht `-payment` in die Zeile
#' `tax`.
#'
#' @param module Steuermodul (Klasse `tax_<name>`).
#' @param t Periodenindex (0…T).
#' @param inputs Eingaben der Periode (Spec 00, Abschnitt 10.4).
#' @param interest Zinsen der Periode: `exo_soll`, `exo_fees`, `endo_soll`, `endo_haben`,
#'   `endo_wht` (n-Vektoren).
#' @param state Zustand aus [tax_init()] bzw. dem vorigen Aufruf.
#' @param params Parameter des Moduls.
#' @return `list(payment = n-Vektor, state = <Zustand>, report = list(<name> = n-Vektor))`.
#' @family Erweitern
#' @export
tax_step <- function(module, t, inputs, interest, state, params) {
  UseMethod("tax_step")
}

#' @rdname tax_step
#' @export
tax_step.default <- function(module, t, inputs, interest, state, params) {
  vofi_abort("core.registry.tax_no_method", fun = "tax_step",
             module = utl_collapse(class(module)), .class = "vofi_error_registry")
}

#' Steuer-Hook: offene Steuer am Horizont
#'
#' S3-Generic des Steuer-Hooks (Spec 00, Abschnitte 10.3, 10.5). Liefert die am Horizont offene
#' Steuer (`payment_T`, positiv = Verbindlichkeit), die den Endwert mindert.
#'
#' @param module Steuermodul (Klasse `tax_<name>`).
#' @param T letzter Periodenindex.
#' @param state Zustand nach der letzten Periode.
#' @param terminal_inputs Eingaben am Horizont (Spec 00, Abschnitt 10.4).
#' @param params Parameter des Moduls.
#' @return `list(payment_T = n-Vektor, report = list(<name> = n-Vektor))`.
#' @family Erweitern
#' @export
tax_finalize <- function(module, T, state, terminal_inputs, params) { # nolint
  UseMethod("tax_finalize")
}

#' @rdname tax_finalize
#' @export
tax_finalize.default <- function(module, T, state, terminal_inputs, params) { # nolint
  vofi_abort("core.registry.tax_no_method", fun = "tax_finalize",
             module = utl_collapse(class(module)), .class = "vofi_error_registry")
}
