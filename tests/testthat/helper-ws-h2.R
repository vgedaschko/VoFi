# Testhelfer von WS-H2 (HTML-Bericht, vofi_report()).
#
# Abhängigkeiten zu anderen Paketen (Stand nach der Integration Stufe III):
# 1. vofi_report() ist geliefert und steht nicht mehr in vofi_stubs() (helper-contracts.R); die
#    frühere Hülle um vofi_stubs() ist entfallen.
# 2. Die Fixtures example_mc_result(), example_comparison(), wsh_comparison(), wsh_sensitivity()
#    und wsh_mc_comparison() haben die Struktur der echten WS-G-Objekte
#    (test-output-real-objects.R); der Bericht mit echten vofi_mc_result-, vofi_comparison-,
#    vofi_sensitivity- und vofi_solution-Objekten wird in test-report-real-objects.R geprüft.
# 3. Die Testszenarien von WS-H (wsh_self_scenario(), wsh_tenant_scenario()) werden um Baujahr,
#    Wohnungsgruppe und Bodenwert ergänzt (für Förder-Check und Ertragswert).

#' UTF-8-Zeichentyp bis zum Ende des Aufrufers (wie in vofi_report(); unter LANG=C sonst
#' Übersetzungswarnungen bei Texten mit Umlauten); auch für test-report-real-objects.R
local_utf8 <- function(env = parent.frame()) {
  old <- rep_html_utf8_locale()
  if (!is.null(old)) withr::defer(Sys.setlocale("LC_CTYPE", old), envir = env)
  invisible(old)
}

#' Berichtsmodell ohne Rendern (Kontext wie in vofi_report(); auch für test-report-real-objects.R)
wsh2_model <- function(x, mode = "auto", template = NULL, title = NULL) {
  local_utf8()
  parts <- rep_html_parts(x)
  mode <- rep_html_mode(mode, parts$main)
  opts <- rep_html_template(template, mode)
  rep_html_model(rep_html_context(parts, mode, opts), title)
}

#' Ids der Abschnitte eines Modells
wsh2_ids <- function(model) vapply(model$sections, function(s) s$id, "")

#' Abschnitt eines Modells nach id
wsh2_section <- function(model, id) model$sections[[match(id, wsh2_ids(model))]]

#' Zeilen der Kennzahltabelle eines Vergleichs in dessen Spaltenstruktur
#'
#' Integrator (Stufe III): die Fixture example_comparison() hat seit Stufe II die Spalten von
#' vofi_compare() (WS-G, u. a. `scenario_set`, `na_reason`); übrige Spalten bleiben NA,
#' `scenario_set` folgt aus dem Fall `<variante>@<set>`.
wsh2_kpi_rows <- function(cmp, variant, kpi, value) {
  add <- data.frame(variant = variant, kpi = kpi, value = value, stringsAsFactors = FALSE)
  for (cl in setdiff(names(cmp$kpi_table), names(add))) add[[cl]] <- NA
  if ("scenario_set" %in% names(add)) {
    add$scenario_set <- ifelse(grepl("@", variant, fixed = TRUE), sub("^[^@]*@", "", variant),
                               NA_character_)
  }
  add[names(cmp$kpi_table)]
}

#' Bericht erzeugbar? (rmarkdown, knitr, pandoc ab 2.0)
skip_if_no_report <- function() {
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not_installed("knitr")
  testthat::skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc nicht verf\u00fcgbar")
}

#' Selbstnutzer-EFH (WS-H) mit Baujahr, Wohnungsgruppe und einem Zuschuss (BEG)
wsh2_self_scenario <- function(grant = 6000, ...) {
  sc <- wsh_self_scenario(...)
  sc$building$construction_year <- 1975L
  sc$unit_groups <- list(main = list(n_units = 1L, living_area_m2 = 140, owner_occupied = TRUE))
  if (grant > 0) {
    sc$components$zuschuss <- list(type = "custom_series", label = "BEG-Zuschuss W\u00e4rmepumpe",
                                   section = "grants", category = "grant", measure_id = "wp",
                                   program = "beg_em", values = c(0, 0, grant, rep(0, 7L)))
  }
  sc
}

#' Mietwohnungsbau (WS-H) mit Bodenwert für den Ertragswert
wsh2_tenant_scenario <- function(...) {
  sc <- wsh_tenant_scenario(...)
  sc$building$land_value_eur <- 100000
  sc
}

#' Ergebnis eines Szenarios ohne Meldungen
wsh2_run <- function(sc) {
  withr::local_options(vofi.verbose = FALSE)
  withCallingHandlers(
    vofi_run(vofi_build(sc)),
    vofi_warning = function(w) invokeRestart("muffleWarning")
  )
}

#' Bericht in eine temporäre Datei rendern; liefert Pfad, HTML und Klartext
wsh2_render <- function(x, ..., file = "bericht.html", env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  path <- file.path(dir, file)
  out <- vofi_report(x, path, ..., open = FALSE)
  html <- paste(readLines(out, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  list(path = out, html = html, text = wsh2_plain(html))
}

#' Klartext eines HTML-Dokuments (ohne Tags, eingebettete Daten und Entitäten)
wsh2_plain <- function(html) {
  body <- sub("^.*<body[^>]*>", "", html)
  body <- gsub("<script.*?</script>", " ", body, perl = TRUE)
  body <- gsub("<style.*?</style>", " ", body, perl = TRUE)
  txt <- gsub("<[^>]+>", " ", body)
  txt <- gsub("&lt;", "<", txt, fixed = TRUE)
  txt <- gsub("&gt;", ">", txt, fixed = TRUE)
  txt <- gsub("&quot;", "\"", txt, fixed = TRUE)
  txt <- gsub("&#39;", "'", txt, fixed = TRUE)
  txt <- gsub("&amp;", "&", txt, fixed = TRUE)
  gsub("\\s+", " ", txt)
}

#' Pflichtsensitivitäten als Tabelle nach Spec 01 Teil C 4.4 (Attrappe für
#' cmp_mandatory_sensitivities(), WS-G): Prüfwerte des Walking Skeleton (h = 2 %)
wsh2_mandatory <- function() {
  data.frame(
    variant = "base",
    id = c("restwert_null", "habenzins_kalkulationszins", "habenzins_fk",
           "habenzins_abgeltung", "stufe_2045"),
    label = c("Restwert = 0", "Habenzins = Kalkulationszins 3,5 %",
              "Habenzins = vermiedener FK-Zins",
              "Habenzins nach Abgeltungsteuer (25 % + Soli)",
              "mit 2045-Stufe (100 % klimaneutraler Brennstoff ab 2045)"),
    path = c("residual_value.method", "accounts.deposit_rate_pa", "accounts.deposit_rate_pa",
             "accounts.deposit_withholding_tax_share", "project.pending_reforms"),
    kpi = "delta_terminal_value", base = 10382.48, base_ex_rv = 10382.48,
    value = c(10382.48, 9869.36, 9688.64, 10552.68, 10382.48),
    value_ex_rv = c(10382.48, 9869.36, 9688.64, 10552.68, 10382.48),
    diff = c(0, -513.12, -693.84, 170.20, 0),
    diff_ex_rv = c(0, -513.12, -693.84, 170.20, 0),
    status = c("same_as_base", "computed", "computed", "computed", "no_effect"),
    stringsAsFactors = FALSE
  )
}
