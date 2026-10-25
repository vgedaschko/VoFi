# Laufkontext ctx (WS-D, Spec 00 Abschnitt 6).
# Phase 0 (P0a): Stub der Fabrik eng_context_from_parts(), die das Prüfkit
# (R/registry-testkit.R) und die Testhelfer verwenden. Minimalfassung: Phase 0b (Walking
# Skeleton); Eigentümer und Ausbau: WS-D.

#' Laufkontext aus Einzelteilen (Prüfkit, Testhelfer; Spec 00 Abschnitt 6.1)
#'
#' Erzeugt eine gesperrte Umgebung der Klasse `vofi_ctx` mit den Feldern und Funktionen aus
#' Spec 00, Abschnitt 6.2, ohne Modell.
#'
#' Vertrag für die Umsetzung (vom Prüfkit vorausgesetzt):
#' - `n` = `draws$n`, wenn `draws` gesetzt ist, sonst 1; `mode` wie übergeben.
#' - `components` sind vorab gebaute `vofi_flows` je id (für `ctx$component()`/`ctx$rows()`),
#'   `components_base` die des Basisfalls (für `ctx$component_base()`).
#' - `engine_env` ist `NULL` oder eine Umgebung mit `stage` (`"flows"`, `"balance"`, `"kpi"`),
#'   `rebalance(extra_out)` und `auto(id)`; `ctx$rebalance()` delegiert an
#'   `engine_env$rebalance` (nur bei `stage == "kpi"`, sonst `vofi_error_contract`),
#'   `ctx$auto(id)` an `engine_env$auto`.
#' - `ctx$assets()`/`ctx$measures()` enthalten mindestens `spec$registers`.
#' @param grid `vofi_grid`.
#' @param spec `vofi_spec`.
#' @param draws `NULL` oder `vofi_draws`.
#' @param components benannte Liste von `vofi_flows` (Abhängigkeiten).
#' @param components_base `vofi_flows` des Basisfalls.
#' @param mode `"deterministic"`, `"mc"` oder `"design"`.
#' @param engine_env private Engine-Umgebung bzw. Attrappe.
#' @return gesperrte Umgebung der Klasse `vofi_ctx`.
#' @noRd
eng_context_from_parts <- function(grid, spec, draws = NULL, components = list(),
                                   components_base = components,
                                   mode = c("deterministic", "mc", "design"),
                                   engine_env = NULL) {
  vofi_abort("core.not_implemented", fun = "eng_context_from_parts",
             .class = "vofi_error_not_implemented")
}
