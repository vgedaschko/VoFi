# Integrator (Stufe III): HTML-Bericht von WS-H2 mit den echten Ergebnisobjekten von WS-G
# (vofi_mc_result, vofi_comparison, vofi_sensitivity, vofi_solution; Spec 00 13.2-13.4, 14 Nr. 26).
# WS-H2 wurde gegen die Fixtures (helper-fixtures.R, helper-ws-h.R) gebaut und nur lokal mit
# WS-G geprüft; diese Tests sichern den Bericht mit echten Objekten dauerhaft ab: Rendern ohne
# Warnung, Pflichtsensitivitäten mit dem mitgeführten Szenario gerechnet, Szenario-Sets und
# Entscheidungsknoten im Vergleich, Haushaltsmodus ohne Minuszeichen.

int_rep_quiet <- function(expr) {
  withCallingHandlers(expr, message = function(m) invokeRestart("muffleMessage"))
}

int_rep_grob <- function() {
  sc <- vofi_read_scenario(vofi_example("grob_lehrbuch_a"))
  wsg_quiet(vofi_build(sc))
}

int_rep_status <- function(code) lbl(paste0("report.html.sensitivity.status_", code))

test_that("vofi_report mit echtem vofi_result, vofi_mc_result, vofi_sensitivity, vofi_solution", {
  local_utf8()
  skip_if_no_report()
  m <- int_rep_grob()
  res <- wsg_quiet(vofi_run(m))
  mc <- wsg_quiet(vofi_mc(m, n_sim = 400L, seed = 1L))
  tor <- wsg_quiet(vofi_sensitivity(m, method = "tornado"))
  glo <- wsg_quiet(vofi_sensitivity(mc, method = "global"))
  sol <- wsg_quiet(vofi_solve(m, what = "breakeven", param = "accounts.deposit_rate_pa",
                              kpi = "delta_terminal_value"))
  # Einzelergebnis: Pflichtsensitivitäten aus dem mitgeführten Szenario (Teil C 4.4)
  expect_no_warning(r <- int_rep_quiet(wsh2_render(res, mode = "expert", file = "res.html")))
  expect_true(file.exists(r$path))
  expect_match(r$text, lbl("report.html.sensitivity.mandatory_header"), fixed = TRUE)
  expect_match(r$text, int_rep_status("computed"), fixed = TRUE)
  expect_false(grepl(int_rep_status("not_computed"), r$text, fixed = TRUE))
  expect_false(grepl("[[report.", r$text, fixed = TRUE))
  # Simulation mit Tornado, globaler Sensitivität (eine Eingangsgröße) und Zielwertsuche
  expect_no_warning(f <- int_rep_quiet(wsh2_render(list(mc, tor, glo, sol), mode = "expert",
                                                   file = "mc.html")))
  expect_match(f$text, "Risiko (Monte-Carlo-Simulation)", fixed = TRUE)
  expect_match(f$text, "Tornado: Endwertdifferenz", fixed = TRUE)
  expect_match(f$text, "accounts.deposit_rate_pa", fixed = TRUE)
  expect_match(f$text, int_rep_status("computed"), fixed = TRUE)
  expect_false(grepl("[[report.", f$text, fixed = TRUE))
  # Haushaltsmodus und Kurzvorlage
  expect_no_warning(h <- int_rep_quiet(wsh2_render(mc, mode = "household", file = "mc_h.html")))
  expect_false(grepl("class=\"neg\"", h$html, fixed = TRUE))
  expect_match(h$html, "vofi-modus-household", fixed = TRUE)
  expect_no_warning(k <- int_rep_quiet(wsh2_render(res, template = "kurzvorlage",
                                                   file = "res_k.html")))
  expect_match(k$html, "vofi-art-kurzvorlage", fixed = TRUE)
})

test_that("vofi_report mit echtem vofi_comparison: Entscheidungsknoten und Set foerderstopp (MC)", {
  local_utf8()
  skip_if_no_report()
  sc <- wsg_decision_scenario(n_sim = 200L, p = 0.6)
  cmp <- wsg_quiet(vofi_compare(sc, variants = "base", baseline = "ohne",
                                scenario_sets = "foerderstopp", n_sim = 200L))
  expect_s3_class(cmp, "vofi_comparison")
  expect_true("base@foerderstopp" %in% names(cmp$results))
  expect_no_warning(r <- int_rep_quiet(wsh2_render(cmp, mode = "expert", file = "cmp.html")))
  expect_match(r$text, "Variantenvergleich", fixed = TRUE)
  expect_match(r$text, "base@foerderstopp", fixed = TRUE)
  expect_match(r$text, "besser als ohne", fixed = TRUE)
  # Pflichtsensitivitäten je Variante gegen die Referenz (delta_vs_reference)
  expect_match(r$text, int_rep_status("computed"), fixed = TRUE)
  expect_false(grepl("[[report.", r$text, fixed = TRUE))
  expect_no_warning(k <- int_rep_quiet(wsh2_render(cmp, template = "gremium", file = "cmp_k.html")))
  expect_match(k$text, "Szenariotabelle", fixed = TRUE)
  # Referenzzeilen: Referenzvariante und ihr Set-Fall ohne@foerderstopp (Referenz der Set-Fälle)
  sec <- wsh2_section(wsh2_model(cmp, template = "kurzvorlage"), "scenarios")
  tab <- sec$blocks[[1L]]$m
  expect_identical(unname(tab[, 1L]), c("ohne", "base", "ohne@foerderstopp", "base@foerderstopp"))
  expect_identical(unname(tab[c(1L, 3L), 4L]), rep(lbl("report.html.board.reference_row"), 2L))
  expect_identical(unname(tab[4L, 4L]), "0 \u20ac")
  expect_no_warning(h <- int_rep_quiet(wsh2_render(cmp, mode = "household", file = "cmp_h.html")))
  expect_false(grepl("class=\"neg\"", h$html, fixed = TRUE))
  expect_match(h$text, "base@foerderstopp besser als ohne", fixed = TRUE)
})

test_that("vofi_report mit echtem deterministischem vofi_comparison", {
  local_utf8()
  skip_if_no_report()
  sc <- wsg_scenario(variants = wsg_variant_a(components.z.values = wsg_z_a))
  cmp <- wsg_quiet(vofi_compare(sc))
  expect_no_warning(r <- int_rep_quiet(wsh2_render(cmp, mode = "expert", file = "cmp_det.html")))
  expect_match(r$text, "im Basisfall besser als base", fixed = TRUE)
  expect_false(grepl("[[report.", r$text, fixed = TRUE))
})

test_that("vofi_report mit tax_flat (Kleinvermieter): Abgeltung-Sensitivität nicht anwendbar", {
  local_utf8()
  skip_if_no_report()
  sc <- wsx_scenario(params = list(rate = 0.3, lag = 0L),
                     project = list(perspective = "kleinvermieter"))
  res <- wsg_quiet(suppressWarnings(vofi_run(wsx_build(sc))))
  r <- int_rep_quiet(suppressWarnings(wsh2_render(res, mode = "expert", file = "flat.html")))
  expect_match(r$text, int_rep_status("not_applicable"), fixed = TRUE)
  expect_false(grepl(int_rep_status("not_computed"), r$text, fixed = TRUE))
  # Vermerk des Moduls statt "Ertragsteuern nicht berücksichtigt" und Steuerwarnhinweis
  expect_match(r$text, lbl("types.tax.flat.note"), fixed = TRUE)
  expect_false(grepl(lbl("report.notes.tax_none"), r$text, fixed = TRUE))
  expect_false(grepl("Steuerwarnhinweis", r$text, fixed = TRUE))
  expect_false(grepl("[[report.", r$text, fixed = TRUE))
})
