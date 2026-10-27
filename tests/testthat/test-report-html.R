# Tests für R/report-html.R (WS-H2): vofi_report() – HTML-Bericht im Fach- und Haushaltsmodus,
# Kurzvorlage (Gremien), Argumentprüfung, Pandoc-Markdown, Ampel-Rückfall (Spec 01 Teil C 6.6),
# Pflichtsensitivitäten (Teil C 4.4), Zielwertsuchen (Teil C 6.5), Berechtigungs-Check der
# Förderung (Teil B 4.3.1), Rechenweg der Umlage (Teil B 1.9.6), Rendern in R-Prozessen mit
# LANG=C.UTF-8 und LANG=C.

# ---------------------------------------------------------------------------------------------
# Hilfen
# ---------------------------------------------------------------------------------------------

#' Pandoc-Markdown eines Berichtsmodells (Grafiken in ein temporäres Verzeichnis)
wsh2_markdown <- function(model, env = parent.frame()) {
  local_utf8()
  dir <- withr::local_tempdir(.local_envir = env)
  rep_html_markdown(model, dir)
}

#' Ergebnis ohne Auflösungszustand (der Bericht rechnet dann keine Pflichtsensitivitäten nach;
#' für Tests, deren Gegenstand andere Abschnitte sind)
wsh2_no_state <- function(res) {
  attr(res$spec, "scn_state") <- NULL
  res
}

#' Ist die Pflichtsensitivitätsfunktion von WS-G vorhanden?
wsh2_has_mandatory <- function() {
  is.function(get0("cmp_mandatory_sensitivities", envir = asNamespace("vofi"),
                   inherits = FALSE))
}

#' Spezifikation mit dem Förderinstrument KfW 458 (aufgelöst aus der Bibliothek, Teil B F-2)
wsh2_kfw458_spec <- function(...) {
  e2_resolve(e2_kfw458(...))
}

#' Ergebnis eines Selbstnutzers mit dem Förderblock einer aufgelösten Spezifikation (Herkunft und
#' Bibliotheksstand dazu); der Berechtigungs-Check liest nur die Spezifikation
wsh2_with_funding <- function(spec, res = wsh2_no_state(wsh2_run(wsh2_self_scenario()))) {
  res$spec$funding <- spec$funding
  res$spec$measures <- spec$measures
  attr(res$spec, "provenance") <- attr(spec, "provenance")
  res$meta$library <- spec$library
  res
}

#' Ergebnis mit einer Mietpfad-Komponente mit Umlagezeile k (Prüffall RP-5, Teil B 1.9.6) und
#' die Rückgabe dieser Komponente
wsh2_levy_case <- function(res = example_result()) {
  meas <- list(k = list(modernization_kind = "bgb_555b_1", cost_eur = 673028.5,
                        completion_date = "2027-10-01", ohnehin_share = 0, active = 1))
  rp <- eop_rp(unit_group = "g", living_area_m2 = 1600, n_units = 24L, rent_eur_m2_month = 6.2,
               increase_policy = "fixed_growth", rent_growth = 0.015,
               growth_from = "2029-01-01", growth_applies_to = "total",
               rent_law_measures = list("k"), levy_rows = list("k"),
               voluntary_cap_per_m2 = 1.10, .measures = meas)
  res$spec$components$u_g_rent <- list(type = "rent_path", unit_group = "g", n_units = 24L,
                                       levy_rows = list("k"))
  res$spec$measures$k <- list(label = "Fassadend\u00e4mmung")
  list(res = res, flows = list(flows = list(u_g_rent = rp$flows), grid = rp$grid))
}

#' Simulation mit vorgegebenen Werten der Primärkennzahl (Ampelprüffälle, Teil C 6.6)
wsh2_tl_mc <- function(values, base = 1000, base_ex_rv = base, restr = list(), mc = wsh_mc()) {
  n <- length(values)
  k <- data.frame(sim = seq_len(n), block = 1L, delta_terminal_value = values)
  for (nm in names(restr)) k[[paste0("restriction_", nm)]] <- restr[[nm]]$mc
  mc$kpis <- k
  mc$deterministic$kpis$delta_terminal_value <- base
  mc$deterministic$kpis$delta_terminal_value_ex_rv <- base_ex_rv
  for (nm in names(restr)) {
    mc$deterministic$kpis[[paste0("restriction_", nm)]] <- restr[[nm]]$base
  }
  mc$spec$analysis$restrictions <- names(restr)
  mc$deterministic$spec$analysis$restrictions <- names(restr)
  mc$meta$primary_kpi <- "delta_terminal_value"
  mc$traffic_light <- NULL
  mc
}

# ---------------------------------------------------------------------------------------------
# Argumentprüfung (ohne Rendern)
# ---------------------------------------------------------------------------------------------

test_that("format = docx ist f\u00fcr v1.1 vorbereitet (vofi_error_not_implemented)", {
  local_utf8()
  res <- example_result()
  expect_error(vofi_report(res, tempfile(fileext = ".html"), format = "docx", open = FALSE),
               class = "vofi_error_not_implemented")
  e <- tryCatch(vofi_report(res, "x.html", format = "docx"), error = identity)
  expect_match(conditionMessage(e), "1.1", fixed = TRUE)
  expect_error(vofi_report(res, "x.html", format = "pdf"), class = "vofi_error_input")
})

test_that("x: Ergebnis oder Liste mit genau einem Ergebnis und erg\u00e4nzenden Objekten", {
  local_utf8()
  res <- example_result()
  expect_error(rep_html_parts(1), class = "vofi_error_input")
  expect_error(rep_html_parts(data.frame(a = 1)), class = "vofi_error_input")
  expect_error(rep_html_parts(list()), class = "vofi_error_input")
  e <- tryCatch(rep_html_parts(list(wsh_sensitivity())), error = identity)
  expect_identical(e$key, "report.html.errors.x_none")
  e <- tryCatch(rep_html_parts(list(res, res)), error = identity)
  expect_identical(e$key, "report.html.errors.x_multiple")
  expect_error(rep_html_parts(list(res, "text")), class = "vofi_error_input")
  expect_error(rep_html_parts(list(res, mandatory = data.frame(id = "a"))),
               class = "vofi_error_input")
  p <- rep_html_parts(res)
  expect_identical(p$main, res)
  expect_length(p$sens, 0L)
  sens <- list(wsh_sensitivity("tornado"), wsh_sensitivity("global"))
  p <- rep_html_parts(list(sens, res, mandatory = wsh2_mandatory(),
                           wsh_sensitivity("spider")))
  expect_s3_class(p$main, "vofi_result")
  expect_identical(vapply(p$sens, function(s) s$method, ""), c("tornado", "global", "spider"))
  expect_identical(p$mandatory$id[2L], "habenzins_kalkulationszins")
  sc <- example_scenario("skeleton")
  expect_s3_class(rep_html_parts(list(res, sc))$scenario, "vofi_scenario")
})

test_that("mode: auto aus meta$report_mode bzw. der Perspektive, Aliase fach/haushalt", {
  local_utf8()
  res <- example_result()
  expect_identical(rep_html_mode(c("auto", "expert", "household"), res), "expert")
  expect_identical(rep_html_mode("fach", res), "expert")
  expect_identical(rep_html_mode("haushalt", res), "household")
  expect_identical(rep_html_mode("household", res), "household")
  r2 <- res
  r2$meta$report_mode <- NULL
  r2$spec$project$report_mode <- "auto"
  expect_identical(rep_html_mode("auto", r2), "expert")
  r2$meta$perspective <- "selbstnutzer"
  expect_identical(rep_html_mode("auto", r2), "household")
  expect_identical(rep_html_mode("auto", example_comparison()), "expert")
  expect_identical(rep_html_mode("auto", wsh_mc()), "expert")
  expect_error(rep_html_mode("gremium", res), class = "vofi_error_input")
  expect_error(rep_html_mode(NA_character_, res), class = "vofi_error_input")
})

test_that("template: Namen, eigene Vorlage, Felder und Abschnitte", {
  local_utf8()
  t0 <- rep_html_template(NULL, "expert")
  expect_identical(t0$name, "bericht")
  expect_identical(t0$sections, rep_html_section_ids("bericht", "expert"))
  expect_false("vofi_table" %in% rep_html_template(NULL, "household")$sections)
  expect_true("vofi_table" %in% rep_html_section_ids("bericht", "household"))
  expect_identical(rep_html_template("gremium", "expert")$name, "kurzvorlage")
  expect_identical(rep_html_template("kurzvorlage", "household")$sections,
                   c("summary", "burden", "funding", "risk"))
  t1 <- rep_html_template(list(name = "bericht", sections = c("kpis", "notes", "summary"),
                               author = "Controlling"), "expert")
  expect_identical(t1$sections, c("summary", "kpis"))
  expect_identical(t1$author, "Controlling")
  expect_error(rep_html_template(list(sections = c("kpis", "kpi")), "expert"),
               class = "vofi_error_input")
  e <- tryCatch(rep_html_template(list(sections = "kpi"), "expert"), error = identity)
  expect_match(conditionMessage(e), "kpis", fixed = TRUE)
  expect_error(rep_html_template(list(sections = NA_character_), "expert"),
               class = "vofi_error_input")
  expect_error(rep_html_template(list(farbe = "rot"), "expert"), class = "vofi_error_input")
  expect_error(rep_html_template(list("bericht"), "expert"), class = "vofi_error_input")
  expect_error(rep_html_template(list(name = "brief"), "expert"), class = "vofi_error_input")
  expect_error(rep_html_template(list(author = 1), "expert"), class = "vofi_error_input")
  expect_error(rep_html_template(42, "expert"), class = "vofi_error_input")
  expect_error(rep_html_template("gibt_es_nicht.Rmd", "expert"), class = "vofi_error_input")
  expect_error(rep_html_template(list(logo = "fehlt.png"), "expert"), class = "vofi_error_input")
  expect_error(rep_html_template(list(css = "fehlt.css"), "expert"), class = "vofi_error_input")
  rmd <- withr::local_tempfile(fileext = ".Rmd")
  writeLines(c("---", "params:", "  body: \"\"", "---", "", "Text"), rmd)
  t2 <- rep_html_template(rmd, "expert")
  expect_identical(t2$file, normalizePath(rmd))
  expect_identical(t2$name, "bericht")
  txt <- withr::local_tempfile(fileext = ".txt")
  writeLines("x", txt)
  expect_error(rep_html_template(txt, "expert"), class = "vofi_error_input")
})

test_that("path, title und open werden gepr\u00fcft", {
  local_utf8()
  res <- example_result()
  expect_error(vofi_report(res, 1, open = FALSE), class = "vofi_error_input")
  expect_error(vofi_report(res, "", open = FALSE), class = "vofi_error_input")
  expect_error(vofi_report(res, "bericht.pdf", open = FALSE), class = "vofi_error_input")
  expect_error(vofi_report(res, file.path(tempdir(), "fehlt", "x", "b.html"), open = FALSE),
               class = "vofi_error_input")
  expect_error(vofi_report(res, "b.html", title = 1, open = FALSE), class = "vofi_error_input")
  expect_error(vofi_report(res, "b.html", open = NA), class = "vofi_error_input")
  dir <- withr::local_tempdir()
  expect_identical(rep_html_path(file.path(dir, "bericht")),
                   file.path(normalizePath(dir), "bericht.html"))
  expect_identical(rep_html_path(file.path(dir, "b.HTM")),
                   file.path(normalizePath(dir), "b.HTM"))
})

test_that("fehlendes rmarkdown bzw. knitr ergibt eine deutsche Meldung", {
  local_utf8()
  res <- example_result()
  dir <- withr::local_tempdir()
  # simuliert wird nur die Verfügbarkeit; Meldung und Abbruch kommen aus vofi_report()
  local_mocked_bindings(rep_html_has_pkg = function(pkg) !identical(pkg, "rmarkdown"))
  e <- tryCatch(vofi_report(res, file.path(dir, "b.html"), open = FALSE), error = identity)
  expect_s3_class(e, "vofi_error_input")
  expect_identical(e$key, "core.suggests_missing")
  expect_match(conditionMessage(e), "rmarkdown", fixed = TRUE)
  expect_match(conditionMessage(e), "install.packages", fixed = TRUE)
  expect_match(conditionMessage(e), "vofi_report", fixed = TRUE)
  expect_false(file.exists(file.path(dir, "b.html")))
  local_mocked_bindings(rep_html_has_pkg = function(pkg) !identical(pkg, "knitr"))
  e <- tryCatch(vofi_report(res, file.path(dir, "b.html"), open = FALSE), error = identity)
  expect_match(conditionMessage(e), "knitr", fixed = TRUE)
})

test_that("ohne pandoc: vofi_error_input mit Hinweis", {
  local_utf8()
  skip_if_not_installed("rmarkdown")
  local_mocked_bindings(pandoc_available = function(...) FALSE, .package = "rmarkdown")
  e <- tryCatch(rep_html_check_pandoc(), error = identity)
  expect_s3_class(e, "vofi_error_input")
  expect_match(conditionMessage(e), "pandoc", fixed = TRUE)
})

# ---------------------------------------------------------------------------------------------
# Markdown-Hilfen
# ---------------------------------------------------------------------------------------------

test_that("Maskierung, Zeilenanf\u00e4nge, Tabellen (negative Werte, Ausrichtung, breit)", {
  local_utf8()
  expect_identical(rep_html_esc("a*b_c|d [e] <f> $g @h #i {j}"),
                   "a\\*b\\_c\\|d \\[e\\] \\<f\\> \\$g \\@h \\#i \\{j\\}")
  expect_identical(rep_html_esc("Zeile\nzwei"), "Zeile zwei")
  expect_identical(rep_html_esc(NA), "")
  expect_identical(rep_html_esc_start(c("-5 \u20ac", "+1", "1. Rang", "Text")),
                   c("\\-5 \u20ac", "\\+1", "1\\. Rang", "Text"))
  m <- matrix(c("Endwert", "Rendite", "-1.234 \u20ac", "3,80 %"), ncol = 2L,
              dimnames = list(NULL, c("Kennzahl", "Wert")))
  b <- rep_html_b_table(m, caption = "Kopf")
  md <- rep_html_md_table(b)
  expect_identical(md[1L], "| Kennzahl | Wert |")
  expect_match(md[2L], "^\\|:-+\\|-+:\\|$")
  expect_match(md[3L], "[-1.234 \u20ac]{.neg}", fixed = TRUE)
  expect_true(": Kopf" %in% md)
  wide <- rep_html_b_table(matrix("1", 1L, 10L, dimnames = list(NULL, letters[1:10])))
  expect_true(wide$wide)
  expect_identical(rep_html_md_table(wide)[1L], "::: {.vofi-wide}")
  expect_identical(rep_html_col_align(c("n. d. (keine Amortisation)", "5,12 %", "2031")), "r")
  expect_identical(rep_html_col_align(c("ja", "nein", "g\u00fcltig")), "l")
  expect_null(rep_html_b_table(matrix(character(0), 0L, 2L)))
  long <- rep_html_b_table(matrix(as.character(1:30), ncol = 1L, dimnames = list(NULL, "x")),
                           max_rows = 10L)
  expect_identical(nrow(long$m), 10L)
  expect_match(long$note, "10 von 30", fixed = TRUE)
  expect_identical(rep_html_pick_rows(8L), 1:8)
  expect_identical(rep_html_pick_rows(30L), c(1:5, 10L, 15L, 20L, 25L, 30L))
  expect_identical(rep_html_pick_rows(32L), c(1:5, 10L, 15L, 20L, 25L, 30L, 32L))
  p <- rep_html_pick_matrix(matrix(as.character(1:30), ncol = 1L))
  expect_true(attr(p, "picked"))
  expect_match(rep_html_b_table(p)$note, "jedes 5. Jahr", fixed = TRUE)
  expect_identical(rep_html_join(c("a", "b", "c")), "a, b und c")
  expect_identical(rep_html_join("a"), "a")
})

test_that("Bl\u00f6cke werden zu Pandoc-Markdown (Ampel, Hinweis, Glossar, Grafikfehler)", {
  local_utf8()
  env <- new.env()
  env$fig_dir <- withr::local_tempdir()
  env$n_fig <- 0L
  tl <- list(level = "green", stage1 = "green", basis = "mc", restrictions = NULL,
             notes = character(0))
  md <- rep_html_md_block(rep_html_b_ampel(tl, household = TRUE), env)
  expect_identical(md[1L], "::: {.vofi-ampel .vofi-ampel-green}")
  expect_true(any(grepl("Ampel: gr\u00fcn", md, fixed = TRUE)))
  expect_true(any(grepl(lbl("report.html.ampel.explain_green"), md, fixed = TRUE)))
  none <- rep_html_b_ampel(NULL)
  expect_identical(none$type, "callout")
  md <- rep_html_md_block(rep_html_b_callout("warning", c("a", "b")), env)
  expect_identical(md[1:3], c("::: {.vofi-callout .vofi-warning}", "- a", "- b"))
  md <- rep_html_md_block(list(type = "deflist", items = list(c("Begriff", "Erkl\u00e4rung"))), env)
  expect_identical(md[1:2], c("Begriff", ":   Erkl\u00e4rung"))
  expect_identical(rep_html_md_block(rep_html_b_heading("Teil", 3L), env)[1L], "### Teil")
  bad <- rep_html_b_plot(function() stop("kaputt"), "Grafik X")
  md <- rep_html_md_block(bad, env)
  expect_match(md[1L], "Grafik X", fixed = TRUE)
  expect_match(md[1L], "kaputt", fixed = TRUE)
  expect_null(rep_html_b_par(character(0)))
  expect_null(rep_html_b_list(NA_character_))
})

# ---------------------------------------------------------------------------------------------
# Ampel (Rückfall bis cmp_traffic_light(), Spec 00 12.9, Prüffälle Spec 01 Teil C 6.6)
# ---------------------------------------------------------------------------------------------

test_that("Ampel der Simulation: Prüffälle A1-A6, A10-A12 (Teil C 6.6)", {
  local_utf8()
  # geprüft wird die Rückfallregel rep_html_tl_mc() selbst; ist cmp_traffic_light() (WS-G)
  # vorhanden, muss sie in jedem Prüffall dieselbe Stufe liefern (danach kann der Rückfall
  # entfallen)
  wsg <- get0("cmp_traffic_light", envir = asNamespace("vofi"), mode = "function",
              inherits = FALSE)
  tl <- function(mc) {
    out <- rep_html_tl_mc(mc)
    if (is.function(wsg)) {
      ref <- wsg(mc)
      expect_identical(c(out$level, out$stage1, out$basis), c(ref$level, ref$stage1, ref$basis))
      expect_identical(out$rv_dependent, ref$rv_dependent)
    }
    out
  }
  base <- wsh_mc()
  v <- function(n_neg, n_pos) c(rep(-500, n_neg), rep(1200, n_pos))
  a1 <- tl(wsh2_tl_mc(v(25, 75), mc = base))
  expect_identical(c(a1$level, a1$stage1, a1$basis), c("green", "green", "mc"))
  expect_false(a1$rv_dependent)
  a2 <- tl(wsh2_tl_mc(v(25, 75), base_ex_rv = -10, mc = base))
  expect_identical(a2$level, "yellow")
  expect_true(a2$rv_dependent)
  expect_true("report.traffic.rv_dependent" %in% a2$notes)
  expect_identical(tl(wsh2_tl_mc(v(45, 55), mc = base))$level, "yellow")
  expect_identical(tl(wsh2_tl_mc(v(65, 35), mc = base))$level, "red")
  r5 <- list(dscr = list(base = 0, mc = c(rep(1, 31), rep(0, 69))))
  a5 <- tl(wsh2_tl_mc(v(20, 80), mc = base, restr = r5))
  expect_identical(c(a5$stage1, a5$level), c("green", "yellow"))
  expect_true(a5$restrictions$ko[1L])
  expect_equal(a5$restrictions$prob[1L], 0.31)
  a6 <- tl(wsh2_tl_mc(v(20, 80), mc = base, restr = list(burden = list(base = 1, mc = 0))))
  expect_identical(a6$level, "yellow")
  expect_true(a6$restrictions$violated_base[1L])
  expect_identical(tl(wsh2_tl_mc(v(30, 70), mc = base))$level, "green")
  expect_identical(tl(wsh2_tl_mc(v(60, 40), mc = base))$level, "yellow")
  r12 <- list(liquidity = list(base = NA_real_, mc = NA_real_))
  a12 <- tl(wsh2_tl_mc(v(20, 80), mc = base, restr = r12))
  expect_identical(a12$level, "green")
  expect_false(a12$restrictions$ko[1L])
  expect_true(any(grepl(rep_restriction_label("liquidity"), a12$notes, fixed = TRUE)))
  # Vorrang des gespeicherten Felds traffic_light, dann cmp_traffic_light() bzw. Rückfall
  mc <- wsh2_tl_mc(v(25, 75), mc = base)
  expect_identical(rep_html_tl(mc)$level, "green")
  mc$traffic_light <- list(level = "red", stage1 = "red", basis = "mc")
  expect_identical(rep_html_tl(mc)$level, "red")
  # Einzelergebnis: Basis base_only (WS-H, rep_traffic_light())
  expect_identical(rep_html_tl(example_result())$basis, "base_only")
})

# ---------------------------------------------------------------------------------------------
# Daten der Abschnitte
# ---------------------------------------------------------------------------------------------

test_that("Finanzierungsbausteine, Mittelherkunft und F\u00f6rderung aus dem Zahlungsbuch", {
  local_utf8()
  res <- example_result()
  ins <- rep_html_instruments(res)
  expect_identical(ins$id, c("ann", "bul"))
  expect_equal(ins$draw, c(40000, 30000))
  expect_equal(ins$repay, c(40000, 30000))
  expect_equal(ins$interest, c(2400 + 1974.2486389651453 + 1522.9521962681995 +
                                 1044.5779670094366 + 537.5012839951481, 7500))
  expect_equal(ins$balance_end, c(0, 0))
  expect_equal(ins$rate_y1[2L], 1500 / 12)
  # Rate nach Tilgungsbeginn je Kredit (SN-01): Annuität 40.000 EUR, 6 %, 5 Jahre
  expect_equal(ins$rate[1L], 40000 * 0.06 / (1 - 1.06^-5) / 12, tolerance = 1e-6)
  expect_identical(ins$rate_year[1L], as.integer(res$grid$year[2L]))
  expect_null(rep_html_grants(res))
  src <- rep_html_sources(res)
  expect_equal(src$invest, 100000)
  expect_equal(src$values[src$labels == lbl("report.html.board.src_equity")], 30000)
  self <- wsh2_run(wsh2_self_scenario())
  g <- rep_html_grants(self)
  expect_equal(g$amount, 6000)
  expect_identical(g$program, "beg_em")
  expect_equal(rep_html_funding_total(self), 6000)
})

test_that("F\u00f6rder-Check: Bedingungen, Ausschl\u00fcsse, Antrag (Teil B 4.3.1)", {
  local_utf8()
  spec <- wsh2_kfw458_spec()
  res <- wsh2_with_funding(spec)
  ck <- rep_html_funding_check(res, "kfw458")
  expect_true(ck$eligible)
  it <- ck$items
  ok <- lbl("report.html.funding_check.state_ok")
  open <- lbl("report.html.funding_check.state_open")
  row <- function(check) it[it$check == check, , drop = FALSE]
  expect_identical(row(lbl("expand.funding.conditions.applicants"))$result, ok)
  expect_identical(row(lbl("expand.funding.conditions.applicants"))$detail,
                   rep_enum_label("applicant", "privatperson"))
  expect_identical(row(lbl("report.html.funding_check.measure_types"))$result, ok)
  ex <- row(lbl("report.html.funding_check.exclusion"))
  expect_identical(ex$result, open)
  expect_match(ex$detail, "Fernw\u00e4rme-Anschlusszusage", fixed = TRUE)
  expect_identical(row(lbl("report.html.funding_check.before_start"))$result, ok)
  expect_match(row(lbl("report.html.funding_check.application_date"))$detail, "01.12.2026",
               fixed = TRUE)
  val <- it[startsWith(it$check, "Programm g\u00fcltig"), , drop = FALSE]
  expect_identical(val$result, ok)
  expect_match(val$detail, "21.07.2026", fixed = TRUE)
  expect_identical(ck$status, lbl("report.html.funding_check.status_open", n = 1L))
  expect_match(ck$title, "KfW 458", fixed = TRUE)
  # nicht berechtigt: Antragsteller (Grund im Status, kein Baustein)
  res2 <- res
  res2$spec$project$perspective <- "wu_kommunal"
  ck2 <- rep_html_funding_check(res2, "kfw458")
  expect_false(ck2$eligible)
  expect_match(ck2$status, paste0(lbl("expand.funding.conditions.applicants"), ": ",
                                  rep_enum_label("applicant", "kommunales_unternehmen")),
               fixed = TRUE)
  expect_identical(ck2$items$result[ck2$items$check == lbl("expand.funding.conditions.applicants")],
                   lbl("report.html.funding_check.state_violated"))
  # Fachbericht, Haushaltsbericht und Kurzvorlage zeigen den Check
  md <- wsh2_markdown(wsh2_model(res, "expert"))
  expect_match(md, paste("##", lbl("report.html.funding_check.header")), fixed = TRUE)
  expect_match(md, "Fernw\u00e4rme-Anschlusszusage", fixed = TRUE)
  hh <- wsh2_markdown(wsh2_model(res, "household"))
  expect_match(hh, rep_html_esc(lbl("report.html.funding_check.household_open",
                                    title = ck$title, items = ck$open)), fixed = TRUE)
  expect_match(hh, "Antrag am 01.12.2026", fixed = TRUE)
  k <- wsh2_markdown(wsh2_model(res, "expert", template = "kurzvorlage"))
  expect_match(k, paste(":", lbl("report.html.funding_check.header")), fixed = TRUE)
  expect_match(k, lbl("report.html.funding_check.col_open"), fixed = TRUE)
  # ohne Förderblock kein Check
  expect_length(rep_html_funding_checks(example_result()), 0L)
  expect_length(rep_html_funding_check_blocks(example_result()), 0L)
})

test_that("Bibliotheksstand: G\u00fcltigkeit der F\u00f6rderung zum Antragsdatum (Spec 00 4.9)", {
  local_utf8()
  spec <- wsh2_kfw458_spec()
  res <- wsh2_with_funding(spec)
  res$meta$legal_state <- as.Date("2027-01-01")
  lib <- res$meta$library
  i <- lib$entry == "funding/kfw_458_heizung_privat"
  expect_true(any(i))
  # gültig zum Antragsdatum 01.12.2026, nicht mehr zum Rechtsstand 01.01.2027
  lib$valid_from[i] <- as.Date("2026-07-21")
  lib$valid_to[i] <- as.Date("2026-12-31")
  res$meta$library <- lib
  ls <- rep_html_library_status(res)
  j <- ls$entry == "funding/kfw_458_heizung_privat"
  expect_false(ls$outdated[j] && ls$status[j] == lbl("report.html.assumptions.status_expired"))
  expect_identical(ls$ref_date[j], lbl("report.html.assumptions.ref_application",
                                       dates = "01.12.2026"))
  # erst ab 15.12.2026 gültig: außerhalb der Gültigkeit zum Antragsdatum
  lib$valid_from[i] <- as.Date("2026-12-15")
  lib$valid_to[i] <- NA
  res$meta$library <- lib
  ls <- rep_html_library_status(res)
  expect_identical(ls$status[j], lbl("report.html.assumptions.status_expired"))
  expect_true(ls$outdated[j])
  other <- which(!startsWith(ls$entry, "funding/"))[1L]
  expect_identical(ls$ref_date[other], lbl("report.html.assumptions.ref_legal",
                                           dates = "01.01.2027"))
  m <- rep_html_library_matrix(ls)
  expect_true(lbl("report.html.assumptions.col_ref_date") %in% colnames(m))
})

test_that("Umlage: Rechenweg rechnerisch, gekappt, angesetzt (Pr\u00fcffall RP-5, Teil B 1.9.6)", {
  local_utf8()
  lc <- wsh2_levy_case()
  local_mocked_bindings(rep_html_component_flows = function(x) lc$flows)
  ch <- rep_html_levy_chain(lc$res)
  expect_identical(nrow(ch), 1L)
  expect_equal(c(ch$computed, ch$capped, ch$charged), c(53842.28, 38400, 21120),
               tolerance = 4e-7)
  expect_identical(ch$procedure, "bgb_559")
  expect_identical(ch$period, "2028")
  expect_equal(ch$area, 1600)
  expect_equal(ch$n_units, 24)
  m <- rep_html_levy_matrix(ch)
  expect_identical(unname(m[1L, 5:7]),
                   c("53.842,28 \u20ac (2,80 \u20ac/m\u00b2)",
                     "38.400,00 \u20ac (2,00 \u20ac/m\u00b2)",
                     "21.120,00 \u20ac (1,10 \u20ac/m\u00b2)"))
  expect_identical(unname(m[1L, 4L]), rep_enum_label("levy_procedure", "bgb_559"))
  # Fachbericht: Mietersicht mit Rechenweg; Haushaltsmodus (Kleinvermieter): Erhöhung je WE
  ten <- wsh2_levy_case(wsh2_no_state(wsh2_run(wsh2_tenant_scenario())))
  local_mocked_bindings(rep_html_component_flows = function(x) ten$flows)
  md <- wsh2_markdown(wsh2_model(ten$res, "expert"))
  expect_match(md, paste("##", lbl("report.html.levy.header")), fixed = TRUE)
  expect_match(md, "21.120,00 \u20ac (1,10 \u20ac/m\u00b2)", fixed = TRUE)
  land <- wsh2_levy_case(wsh2_no_state(wsh2_run(wsh_landlord_scenario())))
  local_mocked_bindings(rep_html_component_flows = function(x) land$flows)
  hh <- rep_html_levy_household(land$res)
  expect_identical(hh, lbl("report.html.levy.household_item",
                           measure = "Fassadend\u00e4mmung", period = "2028", allowed = "130",
                           charged = "75"))
  md2 <- wsh2_markdown(wsh2_model(land$res, "household"))
  expect_match(md2, paste("##", lbl("report.html.levy.household_header")), fixed = TRUE)
  # ohne Mietpfad mit Umlagezeilen: kein Rechenweg (kein Modellbau)
  local_mocked_bindings(rep_html_component_flows = function(x) stop("nicht aufrufen"))
  expect_null(rep_html_levy_chain(example_result()))
})

test_that("Bibliotheksstand: G\u00fcltigkeit, Veraltung (6 bzw. 12 Monate) und Qualit\u00e4t C/D", {
  local_utf8()
  res <- example_result()
  res$meta$legal_state <- as.Date("2027-01-01")
  res$meta$library <- data.frame(
    entry = c("legal/a", "funding/b", "prices/c", "processes/d", "costs/e", "legal/f"),
    as_of = as.Date(c("2026-10-25", "2026-10-25", "2026-03-01", "2026-03-01", "2026-10-25",
                      "2026-10-25")),
    valid_from = as.Date(c("2026-01-01", "2027-02-01", "2026-01-01", "2026-01-01",
                           "2026-01-01", "2026-01-01")),
    valid_to = as.Date(c(NA, NA, NA, NA, "2027-01-01", NA)),
    quality = c("A", "B", "B", "B", "B", "D"), stringsAsFactors = FALSE
  )
  ls <- rep_html_library_status(res)
  expect_identical(ls$outdated, c(FALSE, TRUE, TRUE, FALSE, TRUE, FALSE))
  expect_identical(ls$flag, c(FALSE, TRUE, TRUE, FALSE, TRUE, TRUE))
  expect_identical(ls$status[1L], lbl("report.html.assumptions.status_ok"))
  expect_identical(ls$status[2L], lbl("report.html.assumptions.status_expired"))
  expect_identical(ls$status[3L], lbl("report.html.assumptions.status_old", months = 6L))
  expect_identical(ls$status[6L], lbl("report.html.assumptions.status_quality_D"))
  res$meta$library <- res$meta$library[0L, ]
  res$spec$library <- NULL
  expect_null(rep_html_library_status(res))
})

test_that("Einflussgr\u00f6\u00dfen: Tornado nach Spannweite, global nach SRRC bzw. s1, sonst MC", {
  local_utf8()
  rc <- rep_html_context(rep_html_parts(list(example_result(), wsh_sensitivity("tornado"))),
                         "expert", rep_html_template(NULL, "expert"))
  expect_identical(rep_html_drivers(rc), c("Zahlungsfolge", "Habenzins"))
  expect_identical(rep_html_drivers_text(rc),
                   lbl("report.html.summary.drivers", drivers = "Zahlungsfolge und Habenzins"))
  g <- wsh_sensitivity("global")
  g$global$srrc <- c(0.1, -0.9)
  rc$sens <- list(g)
  expect_identical(rep_html_drivers(rc, 1L), "market.inflation")
  g$r2_src <- 0.5
  rc$sens <- list(g)
  expect_identical(rep_html_drivers(rc, 1L), "components.z.values")
  rc_mc <- rep_html_context(rep_html_parts(wsh_mc()), "expert",
                            rep_html_template(NULL, "expert"))
  expect_identical(rep_html_drivers(rc_mc), "components.z.values")
  rc0 <- rep_html_context(rep_html_parts(example_result()), "expert",
                          rep_html_template(NULL, "expert"))
  expect_identical(rep_html_drivers_text(rc0), character(0))
})

test_that("Sensitivitäten: globale Analyse mit einer Eingangsgröße, Fehler je Block", {
  local_utf8()
  g <- wsh_sensitivity("global")
  g$global <- g$global[1L, , drop = FALSE]
  x <- list(example_result(), g, mandatory = wsh2_mandatory())
  expect_no_warning(m <- wsh2_model(x, "expert"))
  sec <- wsh2_section(m, "sensitivity")
  tabs <- Filter(function(b) identical(b$type, "table"), sec$blocks)
  expect_length(tabs, 2L)  # Pflichtsensitivitaeten und globale Sensitivitaet
  expect_identical(nrow(tabs[[1L]]$m), 5L)
  expect_identical(unname(tabs[[2L]]$m[1L, 1:2]), c("components.z.values", "0,810"))
  # ein fehlerhafter Teil verdraengt die uebrigen Teile des Abschnitts nicht
  local_mocked_bindings(rep_html_sens_blocks = function(s, plots) stop("kaputt"))
  expect_warning(m2 <- wsh2_model(x, "expert"), class = "vofi_warning")
  sec2 <- wsh2_section(m2, "sensitivity")
  types <- vapply(sec2$blocks, function(b) b$type, "")
  expect_true("table" %in% types)
  cal <- Filter(function(b) identical(b$type, "callout"), sec2$blocks)
  expect_true(any(vapply(cal, function(b) any(grepl("kaputt", b$text, fixed = TRUE)),
                         logical(1))))
})

test_that("Pflichtsensitivit\u00e4ten: \u00fcbergebene Tabelle, Status, Was-w\u00e4re-wenn", {
  local_utf8()
  ms <- wsh2_mandatory()
  m <- rep_html_mandatory_matrix(ms)
  expect_identical(nrow(m), 5L)
  expect_identical(unname(m[2L, 4L]), "9.869 \u20ac")
  expect_identical(unname(m[3L, 5L]), "-694 \u20ac")
  st <- c(lbl("report.html.sensitivity.status_same_as_base"),
          rep(lbl("report.html.sensitivity.status_computed"), 3L),
          lbl("report.html.sensitivity.status_no_effect"))
  expect_identical(unname(m[, ncol(m)]), st)
  rc <- rep_html_context(rep_html_parts(list(example_result(), mandatory = ms)), "household",
                         rep_html_template(NULL, "household"))
  wi <- rep_html_what_if(rc)
  expect_length(wi, 5L)
  expect_match(wi[2L], "um rund 500 \u20ac schlechter", fixed = TRUE)
  expect_match(wi[4L], "um rund 200 \u20ac besser", fixed = TRUE)
  expect_match(wi[1L], lbl("report.html.household.what_if_same"), fixed = TRUE)
  # mehrere Varianten: Variantenname vor jedem Eintrag (Haushaltsvergleich)
  two <- rbind(ms, transform(ms, variant = "b"))
  rc_two <- rep_html_context(rep_html_parts(list(example_result(), mandatory = two)),
                             "household", rep_html_template(NULL, "household"))
  wi2 <- rep_html_what_if(rc_two)
  expect_length(wi2, 10L)
  expect_match(wi2[1L], "^base: ")
  expect_match(wi2[6L], "^b: ")
  # ohne Tabelle und ohne Szenario: hinterlegte Einträge als „nicht gerechnet“ mit Grund
  rc2 <- rep_html_context(rep_html_parts(wsh2_no_state(wsh2_run(wsh_landlord_scenario()))),
                          "expert", rep_html_template(NULL, "expert"))
  expect_null(rep_html_mandatory(rc2))
  b <- rep_html_mandatory_blocks(rc2)
  tab <- Filter(function(x) identical(x$type, "table"), b)[[1L]]$m
  expect_true(lbl("report.html.sensitivity.status_ex_rv") %in% tab[, 2L])
  expect_true(lbl("report.html.sensitivity.status_not_computed") %in% tab[, 2L])
  why <- Filter(function(x) identical(x$type, "callout"), b)[[1L]]$text
  expected <- if (wsh2_has_mandatory()) "reason_no_scenario" else "reason_unavailable"
  expect_true(lbl(paste0("report.html.sensitivity.", expected)) %in% why)
})

test_that("Pflichtsensitivit\u00e4ten im Standardaufruf: Szenario aus dem Aufl\u00f6sungszustand", {
  local_utf8()
  res <- wsh2_run(wsh_landlord_scenario())
  rc <- rep_html_context(rep_html_parts(res), "expert", rep_html_template(NULL, "expert"))
  src <- rep_html_mandatory_source(rc)
  expect_s3_class(src$scenario, "vofi_scenario")
  expect_identical(src$variant, "base")
  rc0 <- rep_html_context(rep_html_parts(example_result()), "expert",
                          rep_html_template(NULL, "expert"))
  expect_identical(rep_html_mandatory_source(rc0)$reason, "no_scenario")
  ov_model <- withr::with_options(list(vofi.verbose = FALSE), suppressWarnings(
    vofi_build(wsh_landlord_scenario(), overrides = list(accounts.deposit_rate_pa = 0.01))
  ))
  ov <- withr::with_options(list(vofi.verbose = FALSE), suppressWarnings(vofi_run(ov_model)))
  rc_ov <- rep_html_context(rep_html_parts(ov), "expert", rep_html_template(NULL, "expert"))
  expect_identical(rep_html_mandatory_source(rc_ov)$reason, "overrides")
  # übergebenes Szenario hat Vorrang
  sc <- example_scenario("skeleton")
  rc_sc <- rep_html_context(rep_html_parts(list(example_result(), sc)), "expert",
                            rep_html_template(NULL, "expert"))
  expect_identical(rep_html_mandatory_source(rc_sc)$scenario, sc)
  # Zwischenspeicher: einmal gerechnet (bzw. einmal als nicht verfügbar erkannt)
  first <- rep_html_mandatory(rc)
  expect_true(exists("mandatory", envir = rc$cache, inherits = FALSE))
  expect_identical(rep_html_mandatory(rc), first)
  if (!wsh2_has_mandatory()) {
    expect_null(first)
    expect_identical(rc$cache$mandatory_reason,
                     lbl("report.html.sensitivity.reason_unavailable"))
  } else {
    expect_true(is.data.frame(first) && nrow(first) > 0L)
  }
})

test_that("Pflichtsensitivit\u00e4ten: Pr\u00fcfwerte Teil C 4.4 (WS-G)", {
  local_utf8()
  skip_if_not(wsh2_has_mandatory(), "cmp_mandatory_sensitivities() fehlt (WS-G)")
  sk <- vofi_read_scenario(vofi_example("skeleton"))
  res <- wsh2_run(sk)
  rc <- rep_html_context(rep_html_parts(res), "expert", rep_html_template(NULL, "expert"))
  ms <- rep_html_mandatory(rc)
  expect_true(is.data.frame(ms))
  expect_equal(ms$base[1L], 10382.48, tolerance = 4e-7)
  kz <- ms[ms$id == "habenzins_kalkulationszins", , drop = FALSE]
  expect_equal(kz$value, 9869.36, tolerance = 4e-7)
  expect_identical(kz$status, "computed")
  md <- wsh2_markdown(wsh2_model(res, "expert"))
  row <- "| Habenzins = Kalkulationszins 3,5 % | Endwertdifferenz | 10.382 \u20ac | 9.869 \u20ac"
  expect_match(md, row, fixed = TRUE)
  expect_false(grepl(rep_html_esc(lbl("report.html.sensitivity.not_computed")), md,
                     fixed = TRUE))
})

test_that("Zielwertsuchen (vofi_solution): bei Sensitivit\u00e4ten und in der Kurzvorlage", {
  local_utf8()
  res <- example_result()
  sols <- list(
    new_vofi_solution(list(what = "critical_value", param = "accounts.deposit_rate_pa",
                           kpi = "delta_terminal_value", target = 0, target_source = "value",
                           value = 0.0412)),
    new_vofi_solution(list(what = "withdrawal_equivalent", value = 1234.4, monotone = FALSE,
                           prob_exceed = 0.25))
  )
  p <- rep_html_parts(list(res, sols[[1L]], sols[[2L]]))
  expect_length(p$solutions, 2L)
  m <- rep_html_solution_matrix(p$solutions, res$spec)
  expect_identical(dim(m), c(2L, 6L))
  expect_identical(unname(m[, 1L]), c(lbl("report.html.sensitivity.what_critical_value"),
                                      lbl("report.html.sensitivity.what_withdrawal_equivalent")))
  expect_identical(unname(m[1L, 5L]), "4,12 %")  # Einheit rate_pa aus dem Feldkatalog
  expect_identical(unname(m[2L, 5L]), "1.234 EUR/Jahr")  # Einheit der Kennzahl (EUR_pa)
  expect_identical(unname(m[, 4L]), c("0 \u20ac", ""))
  expect_match(m[2L, 6L], lbl("report.html.sensitivity.not_monotone"), fixed = TRUE)
  expect_match(m[2L, 6L], "25,0 %", fixed = TRUE)
  expect_identical(ncol(rep_html_solution_matrix(sols[1L], res$spec)), 5L)
  expect_null(rep_html_solution_matrix(list()))
  md <- wsh2_markdown(wsh2_model(list(res, sols[[1L]])))
  expect_match(md, lbl("report.html.sensitivity.solutions_header"), fixed = TRUE)
  expect_match(md, "accounts.deposit\\_rate\\_pa", fixed = TRUE)
  k <- wsh2_markdown(wsh2_model(list(res, sols[[1L]]), template = "kurzvorlage"))
  expect_match(k, lbl("report.html.sensitivity.solutions_header"), fixed = TRUE)
})

test_that("Zielwertsuchen Teil C 6.5: shared.* als Zahl, Zielwert und Schwelle mit Einheit", {
  local_utf8()
  spec <- example_result()$spec
  spec$stochastic$parameters$rw <- list(target = "shared.rw", label = "Restwert",
                                        dist = "triangular", min = 30000, mode = 40000,
                                        max = 50000)
  sol <- function(target = 0, target_source = "value", ...) {
    new_vofi_solution(list(what = "breakeven", target = target, target_source = target_source,
                           ...))
  }
  sols <- list(
    sol(param = "shared.rw", kpi = "delta_terminal_value", value = 36273.59),
    sol(param = "shared.rent_initial", kpi = "roe_mirr", target = 0.06, value = 41642.14),
    sol(param = "shared.cost_factor_v2", kpi = "dscr_min", target = 1.2,
        target_source = "threshold:dscr", value = 1.25),
    sol(param = "unit_groups.g.rent_eur_m2_month", kpi = "warm_rent_change_prepost_y1",
        value = 9.5),
    sol(param = "accounts.deposit_withholding_tax_share", kpi = "delta_terminal_value",
        value = 0.25)
  )
  m <- rep_html_solution_matrix(sols, spec)
  # Prüfwerte grob_lehrbuch_a (Teil C 6.5): keine Prozentdarstellung für shared.*
  expect_identical(unname(m[, 5L]), c("36.273,59", "41.642,14", "1,25",
                                      paste(fmt_num(9.5, 2), rep_unit_label("EUR_m2_month")),
                                      "25,00 %"))
  expect_false(any(grepl("%", m[1:3, 5L], fixed = TRUE)))
  expect_identical(unname(m[1:3, 4L]), c("0 \u20ac", "6,00 %",
                                         lbl("report.html.sensitivity.target_threshold",
                                             value = "1,20",
                                             name = lbl("report.html.sensitivity.threshold_dscr"))))
  expect_false(any(grepl("threshold:", m, fixed = TRUE)))
  expect_identical(unname(m[1L, 2L]), "Restwert (shared.rw)")
  expect_identical(unname(m[2L, 2L]), "shared.rent_initial")
  expect_identical(rep_html_path_unit(spec, "shared.rw"), NA_character_)
  expect_identical(rep_html_path_unit(spec, "accounts.deposit_rate_pa"), "rate_pa")
  expect_identical(rep_html_path_unit(NULL, "financing.kfw.amount_eur"), "EUR")
  expect_identical(rep_html_path_unit(NULL, "shared.shared_value"), NA_character_)
})

# ---------------------------------------------------------------------------------------------
# Berichtsmodell und Markdown (ohne pandoc)
# ---------------------------------------------------------------------------------------------

test_that("Abschnitte je Modus und Vorlage; Hinweise stehen immer am Ende", {
  local_utf8()
  res <- example_result()
  m <- wsh2_model(res, "expert")
  expect_identical(wsh2_ids(m), c("summary", "kpis", "timeline", "financing", "tenant", "risk",
                                  "sensitivity", "assumptions", "vofi_table", "checks",
                                  "method", "notes"))
  mc <- wsh2_model(example_comparison(), "expert")
  expect_true("variants" %in% wsh2_ids(mc))
  h <- wsh2_model(res, "household")
  expect_identical(wsh2_ids(h), c("summary", "burden", "funding", "risk", "assumptions",
                                  "glossary", "notes"))
  k <- wsh2_model(res, "expert", template = "kurzvorlage")
  expect_identical(wsh2_ids(k), c("decision", "investment", "kpis", "restrictions", "risks",
                                  "scenarios", "notes"))
  kh <- wsh2_model(res, "household", template = "gremium")
  expect_identical(wsh2_ids(kh), c("summary", "burden", "funding", "risk", "notes"))
  s <- wsh2_model(res, "expert", template = list(sections = c("vofi_table", "summary")))
  expect_identical(wsh2_ids(s), c("summary", "vofi_table", "notes"))
  expect_identical(m$meta$title, lbl("report.html.title.bericht_expert", title = "testkit"))
  expect_identical(wsh2_model(res, title = "Eigener Titel")$meta$title, "Eigener Titel")
  expect_identical(k$meta$kind_text, lbl("report.html.kind.kurzvorlage_expert"))
})

test_that("Fachmodus: Kernaussagen, Werte mit und ohne Restwert, Steuer- und Haftungshinweis", {
  local_utf8()
  md <- wsh2_markdown(wsh2_model(example_result(), "expert"))
  expect_match(md, lbl("report.html.sections.summary_expert"), fixed = TRUE)
  expect_match(md, "3.726 \u20ac (ohne Restwert: -36.274 \u20ac)", fixed = TRUE)
  expect_match(md, "Ampel: gelb", fixed = TRUE)
  expect_match(md, lbl("report.notes.tax_none"), fixed = TRUE)
  expect_match(md, rep_html_esc(lbl("report.html.notes.disclaimer")), fixed = TRUE)
  expect_match(md, "keine Steuer-, Rechts-", fixed = TRUE)
  expect_match(md, rep_html_esc(lbl("report.html.head.pretax")), fixed = TRUE)
  expect_match(md, "# Hinweise {#vofi-notes}", fixed = TRUE)
  expect_match(md, "[-36.274 \u20ac]{.neg}", fixed = TRUE)
  row <- "| Endwertdifferenz (Prim\u00e4rkennzahl) | 3.726 \u20ac | [-36.274 \u20ac]{.neg}"
  expect_match(md, row, fixed = TRUE)
  expect_match(md, "je WE", fixed = TRUE)
  expect_match(md, "40.000 \u20ac", fixed = TRUE)  # Aufnahme Annuit\u00e4tendarlehen
  expect_match(md, lbl("report.html.risk.no_mc"), fixed = TRUE)
  expect_match(md, "Zahlungsfolge der Investition", fixed = TRUE)  # VoFi-Tabelle (WS-H)
  expect_match(md, "\\]\\(.*abb_001\\.png\\)", perl = TRUE)
  # deterministisch: zwei Läufe ergeben denselben Text
  strip <- function(x) gsub("\\]\\([^)]*abb_", "](abb_", x)
  expect_identical(strip(md), strip(wsh2_markdown(wsh2_model(example_result(), "expert"))))
})

test_that("ohne ggplot2: Hinweis statt Grafiken", {
  local_utf8()
  parts <- rep_html_parts(example_result())
  rc <- rep_html_context(parts, "expert", rep_html_template(NULL, "expert"))
  rc$plots <- FALSE
  md <- wsh2_markdown(rep_html_model(rc))
  expect_match(md, lbl("report.html.no_ggplot"), fixed = TRUE)
  expect_false(grepl(".png)", md, fixed = TRUE))
})

test_that("fehlerhafter Abschnitt: Hinweis im Bericht und Warnung, der Rest bleibt", {
  local_utf8()
  local_mocked_bindings(rep_html_sec_kpis = function(rc) stop("Testfehler"))
  expect_warning(m <- wsh2_model(example_result(), "expert"), class = "vofi_warning")
  sec <- m$sections[[which(wsh2_ids(m) == "kpis")]]
  expect_identical(sec$blocks[[1L]]$type, "callout")
  expect_match(sec$blocks[[1L]]$text, "Testfehler", fixed = TRUE)
  expect_identical(utils::tail(wsh2_ids(m), 1L), "notes")
})

test_that("Simulation: MC-Fehler, Risiko in Worten, Szenarien P5/P50/P95", {
  local_utf8()
  md <- wsh2_markdown(wsh2_model(wsh_mc(), "expert"))
  expect_match(md, "Monte-Carlo-Simulation mit 200 L\u00e4ufen", fixed = TRUE)
  expect_match(md, "MC-Fehler des Mittelwerts", fixed = TRUE)
  expect_match(md, "In 7 von 10 simulierten Zuk\u00fcnften ist die Endwertdifferenz positiv.",
               fixed = TRUE)
  expect_match(md, "Prozentpunkte (MC-Fehler)", fixed = TRUE)
  expect_match(md, lbl("report.html.risk.run_p05"), fixed = TRUE)
  expect_match(md, rep_html_esc(lbl("report.html.risk.det_note")), fixed = TRUE)
  expect_match(md, lbl("report.mc.se_single"), fixed = TRUE)
  expect_match(md, "Ampel: gelb", fixed = TRUE)  # Restwertregel: ohne Restwert negativ
  expect_match(md, lbl("report.html.sensitivity.mc_ranks"), fixed = TRUE)
  hh <- wsh2_markdown(wsh2_model(wsh_mc(), "household"))
  expect_match(hh, "In 3 von 10 simulierten Zuk\u00fcnften stehen Sie am Ende schlechter da",
               fixed = TRUE)
})

test_that("Vergleich: P(A besser als B) nur mit Simulation, Rangfolge, Ampel, Tornado", {
  local_utf8()
  md <- wsh2_markdown(wsh2_model(list(example_comparison(), wsh_sensitivity("tornado")),
                                 "expert"))
  # deterministisch: keine Wahrscheinlichkeit (0/1 wäre Scheingenauigkeit, 12.6, Konzept 4.7)
  expect_false(grepl("P(a besser als base)", md, fixed = TRUE))
  expect_false(grepl("100,00 %", md, fixed = TRUE))
  expect_match(md, "2.000 \u20ac; im Basisfall besser als base.", fixed = TRUE)
  expect_match(md, lbl("report.html.variants.det_better", variant = "a", baseline = "base",
                       value = "2.000 \u20ac"), fixed = TRUE)
  expect_match(md, lbl("report.html.variants.col_base_case"), fixed = TRUE)
  expect_match(md, "Variante a gegen\u00fcber base", fixed = TRUE)
  expect_match(md, "2.000 \u20ac", fixed = TRUE)
  expect_match(md, "1. a, 2. base", fixed = TRUE)
  expect_match(md, lbl("report.html.variants.traffic_header"), fixed = TRUE)
  expect_match(md, "Tornado: Endwertdifferenz", fixed = TRUE)
  expect_match(md, "Das Ergebnis h\u00e4ngt vor allem von Zahlungsfolge und Habenzins ab.",
               fixed = TRUE)
  mcmp <- wsh2_markdown(wsh2_model(wsh_mc_comparison(), "expert"))
  expect_match(mcmp, "Vergleich mit gemeinsamen Zufallszahlen (200 L\u00e4ufe)", fixed = TRUE)
  expect_match(mcmp, lbl("report.plot.title_cdf", kpi = kpi_label("delta_vs_reference")),
               fixed = TRUE)
  expect_match(mcmp, "P(a besser als base) = 100,00 %", fixed = TRUE)
  expect_match(mcmp, "Wahrscheinlichkeit \u201ebesser als base\u201c 100,00 %", fixed = TRUE)
  k <- wsh2_markdown(wsh2_model(example_comparison(), template = "kurzvorlage"))
  expect_false(grepl("100,00 %", k, fixed = TRUE))
  expect_match(k, lbl("report.html.variants.det_note"), fixed = TRUE)
})

test_that("Vergleich: Kennzahlen je Variante mit und ohne Restwert, Kopfkennzahlen", {
  local_utf8()
  cmp <- example_comparison()
  cmp$kpi_table <- rbind(cmp$kpi_table, wsh2_kpi_rows(cmp, "a", "incremental_return", 0.0961))
  m <- wsh2_model(cmp, "expert")
  sec <- wsh2_section(m, "kpis")
  heads <- vapply(Filter(function(b) identical(b$type, "heading"), sec$blocks),
                  function(b) b$text, "")
  expect_identical(heads, c(lbl("report.html.vofi_table.variant_header", variant = "base"),
                            lbl("report.html.vofi_table.variant_header", variant = "a")))
  caps <- vapply(Filter(function(b) identical(b$type, "table"), sec$blocks),
                 function(b) b$caption %||% "", "")
  expect_true(lbl("report.html.table.rv_with_header") %in% caps)
  expect_false(lbl("report.html.variants.kpi_header") %in% caps)  # kein Duplikat
  tab <- Filter(function(b) identical(b$type, "table"), sec$blocks)[[1L]]$m
  expect_true(lbl("report.html.table.per_unit") %in% colnames(tab))
  md <- wsh2_markdown(m)
  summ <- sub("(?s)# Variantenvergleich.*$", "", md, perl = TRUE)
  expect_match(summ, paste0(kpi_label("incremental_return"), " 9,61 %"), fixed = TRUE)
  expect_match(summ, paste0("| ", kpi_label("incremental_return"), " |"), fixed = TRUE)
})

test_that("Vergleich: Hinweise der Ampel aus traffic_light$notes bzw. aus den Restriktionen", {
  local_utf8()
  cmp <- example_comparison()
  # Integrator: die Fixture trägt wie vofi_compare() (WS-G) die Spalte notes; geprüft wird hier
  # zuerst die Ableitung ohne diese Spalte
  stored <- cmp$traffic_light$notes
  expect_identical(rep_html_cmp_tl(cmp, "a")$notes, strsplit(stored, "; ", fixed = TRUE)[[1L]])
  cmp$traffic_light$notes <- NULL
  tl <- rep_html_cmp_tl(cmp, "a")
  expect_true(all(c("report.traffic.rv_dependent", "report.traffic.no_robustness") %in%
                    tl$notes))
  cmp$restrictions <- data.frame(variant = "a", code = "dscr", violated_base = NA,
                                 prob = NA_real_, year = NA_integer_, value = NA_real_,
                                 threshold = NA_real_, ko = FALSE, stringsAsFactors = FALSE)
  tl <- rep_html_cmp_tl(cmp, "a")
  unchecked <- lbl("report.traffic.restriction_unchecked", code = rep_restriction_label("dscr"))
  expect_true(unchecked %in% tl$notes)
  md <- wsh2_markdown(wsh2_model(cmp, "expert"))
  expect_match(md, rep_html_esc(unchecked), fixed = TRUE)
  cmp$traffic_light$notes <- "Ergebnis h\u00e4ngt am Restwert; Restriktion dscr nicht pr\u00fcfbar"
  tl <- rep_html_cmp_tl(cmp, "a")
  expect_identical(tl$notes, c("Ergebnis h\u00e4ngt am Restwert",
                               "Restriktion dscr nicht pr\u00fcfbar"))
  lines <- rep_html_b_ampel(tl)$lines
  expect_true("Restriktion dscr nicht pr\u00fcfbar" %in% lines)
})

test_that("Kurzvorlage: Szenariotabelle mit \u0394EW der Set-F\u00e4lle, Referenz ohne Wert", {
  local_utf8()
  cmp <- example_comparison()
  base <- cmp$results$base
  vs <- cmp$results$a
  vs$meta$variant <- "a"
  vs$meta$scenario_set <- "vorsichtig"
  vs$kpis$delta_terminal_value <- base$kpis$delta_terminal_value - 6631.50
  cmp$results[["a@vorsichtig"]] <- vs
  cmp$scenario_sets <- "vorsichtig"
  add <- wsh2_kpi_rows(cmp, c("a", "a@vorsichtig", "a@vorsichtig"),
                       c("delta_vs_reference", "delta_terminal_value", "delta_vs_reference"),
                       c(2000, vs$kpis$delta_terminal_value, -6631.50))
  cmp$kpi_table <- rbind(cmp$kpi_table, add)
  expect_identical(colnames(cmp$differences$delta_vs_reference), "a")
  expect_equal(rep_html_cmp_delta(cmp, "a@vorsichtig"), -6631.50)
  expect_equal(rep_html_cmp_delta(cmp, "a"), 2000)
  expect_true(is.na(rep_html_cmp_delta(cmp, "base")))
  sec <- wsh2_section(wsh2_model(cmp, template = "kurzvorlage"), "scenarios")
  m <- sec$blocks[[1L]]$m
  expect_identical(unname(m[, 1L]), c("base", "a", "a@vorsichtig"))
  expect_identical(unname(m[, 4L]), c(lbl("report.html.board.reference_row"), "2.000 \u20ac",
                                      "-6.632 \u20ac"))
  expect_false(any(m[, 4L] == fmt_num(NA)))
})

test_that("Haushaltsmodus: Klartext, gerundete Monatswerte, F\u00f6rderung, Glossar", {
  local_utf8()
  self <- wsh2_run(wsh2_self_scenario())
  md <- wsh2_markdown(wsh2_model(self))
  expect_identical(self$meta$report_mode, "household")
  expect_match(md, lbl("report.html.sections.summary_household"), fixed = TRUE)
  hv <- vofi_household_view(self)
  for (t in attr(hv, "summary")$text) {
    expect_match(md, rep_html_esc_start(rep_html_esc(t)), fixed = TRUE)
  }
  expect_match(md, "Sie erhalten F\u00f6rderung von insgesamt rund 6.000 \u20ac.", fixed = TRUE)
  expect_match(md, rep_html_esc(lbl("report.html.ampel.none")), fixed = TRUE)
  expect_match(md, "Begriffe kurz erkl\u00e4rt", fixed = TRUE)
  expect_match(md, "Monatliche Belastung\n:   ", fixed = TRUE)
  expect_match(md, lbl("report.html.notes.household_rounding"), fixed = TRUE)
  b <- rep_html_burden_matrix(hv, owner = TRUE)
  vals <- suppressWarnings(as.numeric(gsub(".", "", b[, -1L], fixed = TRUE)))
  vals <- vals[!is.na(vals)]
  expect_true(all(vals %% 5 == 0))
  expect_true(all(vals[vals >= 100] %% 10 == 0))
  expect_identical(unname(b[1L, 1L]), paste(lbl("report.html.table.phase_construction"), "2027"))
  land <- wsh2_markdown(wsh2_model(wsh2_run(wsh_landlord_scenario())))
  expect_match(land, "\u00dcberschuss 400 \u20ac", fixed = TRUE)
  expect_match(land, lbl("report.household.text.own_contribution_none"), fixed = TRUE)
  expect_match(land, "Monatlicher Cashflow\n:   ", fixed = TRUE)
})

#' Selbstnutzer-Vergleich Gaskessel (Referenz) gegen Wärmepumpe (ohne Auflösungszustand)
wsh2_self_cmp <- function() {
  gas <- wsh2_no_state(wsh2_run(wsh2_self_scenario(energy = 4500, capex = -12000, loan = 0,
                                                   id = "gas", grant = 0)))
  wp <- wsh2_no_state(wsh2_run(wsh2_self_scenario()))
  wsh_comparison(list(gas = gas, wp = wp))
}

#' Negative Zahlen im Markdown (Zelle „[-…]{.neg}“, Zellanfang oder Fließtext mit Minus)
wsh2_minus <- function(md) {
  l <- strsplit(md, "\n", fixed = TRUE)[[1L]]
  l[grepl("\\[-[0-9]|\\| -[0-9]|(^|[ (])[-\u2212][0-9]", l)]
}

test_that("Haushaltsmodus mit Vergleich: W\u00f6rter statt Vorzeichen in Tabellen und Texten", {
  local_utf8()
  cmp <- wsh2_self_cmp()
  model <- wsh2_model(cmp, "household")
  expect_true("variants" %in% wsh2_ids(model))
  md <- wsh2_markdown(model)
  s <- attr(vofi_household_view(cmp), "summary")
  sv <- s$text[s$variant == "wp" & s$item == "saving_y1"]
  expect_match(md, rep_html_esc(sv), fixed = TRUE)
  expect_match(sv, "Gegen\u00fcber gas", fixed = TRUE)
  expect_identical(wsh2_minus(md), character(0))
  # die Haushaltssicht enthält negative Werte; im Bericht stehen sie in Worten
  hv <- vofi_household_view(cmp)
  expect_true(any(hv$cumulative_saving < 0, na.rm = TRUE) || any(hv$saving < 0, na.rm = TRUE))
  b <- rep_html_burden_matrix(hv[hv$variant == "wp", , drop = FALSE], owner = TRUE)
  cum <- b[, ncol(b)]
  expect_true(all(grepl("^(spart [0-9.]+ \u20ac|[0-9.]+ \u20ac mehr|gleich|n\\. d\\.)$", cum)))
  expect_match(md, paste("##", lbl("report.html.vofi_table.variant_header", variant = "wp")),
               fixed = TRUE)
  # Kennzahlen je Variante: Cashflow als Überschuss/Zuschuss, Beträge ohne Vorzeichen
  expect_identical(rep_html_hh_fmt(-416.3, "EUR_month", "monthly_net_cashflow_y1"),
                   "Zuschuss 420 \u20ac")
  expect_identical(rep_html_hh_fmt(412, "EUR_month", "monthly_net_cashflow_min"),
                   "\u00dcberschuss 410 \u20ac")
  expect_identical(rep_html_hh_fmt(-25, "EUR_month", "monthly_saving_y1"), "25 \u20ac mehr")
  expect_identical(rep_html_hh_fmt(-12345, "EUR", "own_contribution"), "Einnahme 12.300 \u20ac")
  expect_identical(rep_html_hh_fmt(12345, "EUR", "own_contribution"), "12.300 \u20ac")
  expect_identical(rep_html_hh_amount(c(-20, 0, 132)), c("Einnahme 20 \u20ac", "0", "130"))
  expect_identical(rep_html_hh_amount(-20, "in"), "Ausgabe 20 \u20ac")
  expect_identical(rep_html_hh_signed(c(500, -1234, 0)),
                   c("Einnahme 500 \u20ac", "Ausgabe 1.230 \u20ac", "0"))
  expect_identical(rep_html_hh_diff_text(-11520, "sum"), "11.500 \u20ac mehr")
})

test_that("Haushaltsmodus Kleinvermieter: Spalten ergeben den Cashflow, keine Minuszeichen", {
  local_utf8()
  res <- wsh2_no_state(wsh2_run(wsh_landlord_scenario()))
  hv <- vofi_household_view(res)
  hv$other <- 500
  hv$grants <- c(1000, rep(0, nrow(hv) - 1L))
  hv$cashflow <- hv$cashflow + hv$other + hv$grants
  b <- rep_html_burden_matrix(hv, owner = FALSE)
  expect_true(all(c(lbl("report.html.household.col_other_income"),
                    lbl("report.html.household.col_other_flows")) %in% colnames(b)))
  expect_false(lbl("report.html.household.col_investment") %in% colnames(b))
  expect_identical(attr(b, "note"), lbl("report.html.household.cashflow_note"))
  num <- function(x) {
    v <- as.numeric(gsub("[^0-9]", "", x))
    ifelse(grepl("^(Ausgabe|Zuschuss)", x), -v, v)
  }
  for (i in seq_len(nrow(b))) {
    total <- num(b[i, 2L]) + num(b[i, 3L]) - num(b[i, 4L]) + num(b[i, 5L]) - num(b[i, 6L])
    expect_lte(abs(total - num(b[i, 7L])), 35)
  }
  md <- wsh2_markdown(wsh2_model(res, "household"))
  expect_identical(wsh2_minus(md), character(0))
  expect_match(md, rep_html_esc(lbl("report.html.household.cashflow_note")), fixed = TRUE)
})

test_that("Mietersicht und Kurzvorlage (Fachmodus) aus einem Engine-Ergebnis", {
  local_utf8()
  ten <- wsh2_run(wsh2_tenant_scenario())
  md <- wsh2_markdown(wsh2_model(list(ten, mandatory = wsh2_mandatory())))
  expect_match(md, lbl("report.html.sections.tenant"), fixed = TRUE)
  tv <- vofi_tenant_view(ten)
  expect_match(md, paste0("| 2027 | ", fmt_num(tv$rent[1L], 2)), fixed = TRUE)
  expect_match(md, fmt_num(tv$change_prepost[1L], 2), fixed = TRUE)
  expect_match(md, "Warmmieten\u00e4nderung im ersten vollen Jahr (vorher/nachher)", fixed = TRUE)
  expect_match(md, "Habenzins = vermiedener FK-Zins", fixed = TRUE)
  expect_match(md, lbl("report.html.financing.coverage_header"), fixed = TRUE)
  k <- wsh2_markdown(wsh2_model(ten, template = "kurzvorlage"))
  expect_match(k, "# Beschlussvorschlag", fixed = TRUE)
  expect_match(k, "Es wird vorgeschlagen, das Vorhaben unter Vorbehalt", fixed = TRUE)
  expect_match(k, lbl("report.html.board.draft"), fixed = TRUE)
  expect_match(k, "Investition (Auszahlungen", fixed = TRUE)
  expect_match(k, "400.000 \u20ac", fixed = TRUE)
  expect_match(k, "# Szenariotabelle", fixed = TRUE)
  expect_false(grepl("VoFi-Tabelle", k, fixed = TRUE))
  kc <- wsh2_markdown(wsh2_model(example_comparison(), template = "kurzvorlage"))
  expect_match(kc, "Es wird vorgeschlagen, die Variante a unter Vorbehalt", fixed = TRUE)
  expect_match(kc, "| Mittelherkunft | base | a |", fixed = TRUE)
})

test_that("Annahmenprotokoll: Herkunft, Override-Kennzeichnung, Abweichungen der Varianten", {
  local_utf8()
  gl <- wsh_quiet(vofi_run(vofi_build(vofi_read_scenario(vofi_example("grob_lehrbuch_a")))))
  rc <- rep_html_context(rep_html_parts(gl), "expert", rep_html_template(NULL, "expert"))
  pm <- rep_html_params_matrix(gl$spec)
  expect_true(nrow(pm) > 10L)
  expect_true(lbl("report.html.assumptions.source.scenario") %in% pm[, 3L])
  meta <- rep_html_meta_matrix(rc)
  expect_true(gl$meta$library_version %in% meta[, 2L])
  sec <- rep_html_sec_assumptions(rc)
  expect_identical(sec$id, "assumptions")
  a <- gl
  a$spec$accounts$deposit_rate_pa <- 0.05
  d <- rep_html_params_diff(a$spec, gl$spec)
  expect_identical(unname(d[, 1L]), "accounts.deposit_rate_pa")
  expect_null(rep_html_params_diff(gl$spec, gl$spec))
  short <- rep_html_assumptions_short(rc)
  tab <- Filter(function(x) identical(x$type, "table"), short)[[1L]]$m
  expect_true(lbl("report.html.assumptions.item_deposit_rate") %in% tab[, 1L])
})

# ---------------------------------------------------------------------------------------------
# Rendern (rmarkdown und pandoc)
# ---------------------------------------------------------------------------------------------

test_that("Fachbericht eines Ergebnisses: eigenst\u00e4ndige HTML-Datei mit deutschen Inhalten", {
  local_utf8()
  skip_if_no_report()
  res <- example_result()
  expect_no_warning(r <- wsh2_render(res, mode = "expert"))
  expect_true(file.exists(r$path))
  expect_match(r$html, "<html[^>]*lang=\"de\"")
  expect_match(r$html, "<title>Wirtschaftlichkeitsbericht: testkit</title>", fixed = TRUE)
  expect_match(r$html, "id=\"TOC\"", fixed = TRUE)
  expect_match(r$html, "data:image/png;base64,", fixed = TRUE)
  expect_false(grepl("<img src=\"(?!data:)", r$html, perl = TRUE))
  expect_false(grepl("<link[^>]+href=\"(?!data:)[^\"]+\\.css", r$html, perl = TRUE))
  expect_match(r$html, "class=\"vofi-bericht vofi-art-bericht vofi-modus-expert\"", fixed = TRUE)
  expect_match(r$html, "<span class=\"neg\">-36.274 \u20ac</span>", fixed = TRUE)
  expect_match(r$text, "Management Summary: Ergebnis auf einen Blick", fixed = TRUE)
  expect_match(r$text, "Kennzahlen mit und ohne Restwert", fixed = TRUE)
  expect_match(r$text, "Annahmen und Herkunft", fixed = TRUE)
  expect_match(r$text, "Ertragsteuern sind nicht ber\u00fccksichtigt", fixed = TRUE)
  expect_match(r$text, "keine Steuer-, Rechts-, F\u00f6rder- oder Finanzierungsberatung",
               fixed = TRUE)
  expect_match(r$text, "Endwertdifferenz im Basisfall: 3.726 \u20ac", fixed = TRUE)
  expect_match(r$text, "Ampel: gelb", fixed = TRUE)
  expect_false(grepl("nicht verf\u00fcgbar", r$text, fixed = TRUE))
  expect_false(grepl("[[report.", r$text, fixed = TRUE))
  # vorhandene Datei wird überschrieben, Rückgabe unsichtbar
  expect_invisible(vofi_report(res, r$path, template = "kurzvorlage", open = FALSE))
  html2 <- paste(readLines(r$path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_match(html2, "Entscheidungsvorlage", fixed = TRUE)
})

test_that("Haushalt, Simulation, Vergleich rendern; Kurzvorlage ohne Inhaltsverzeichnis", {
  local_utf8()
  skip_if_no_report()
  self <- wsh2_no_state(wsh2_run(wsh2_self_scenario()))
  h <- wsh2_render(self, file = "haushalt.html")
  expect_match(h$text, "Das Wichtigste in K\u00fcrze", fixed = TRUE)
  expect_match(h$text, "Ihre monatliche Belastung betr\u00e4gt im ersten vollen Nutzungsjahr rund",
               fixed = TRUE)
  expect_match(h$text, "F\u00f6rderung und Kredite", fixed = TRUE)
  expect_match(h$text, "Begriffe kurz erkl\u00e4rt", fixed = TRUE)
  expect_match(h$html, "vofi-modus-household", fixed = TRUE)
  m <- wsh2_render(wsh_mc(), mode = "fach", file = "mc.html")
  expect_match(m$text, "Risiko (Monte-Carlo-Simulation)", fixed = TRUE)
  expect_match(m$text, "In 7 von 10 simulierten Zuk\u00fcnften", fixed = TRUE)
  c1 <- wsh2_render(list(example_comparison(), wsh_sensitivity("spider")), file = "cmp.html")
  expect_match(c1$text, "Variantenvergleich", fixed = TRUE)
  expect_match(c1$text, "im Basisfall besser als base", fixed = TRUE)
  expect_false(grepl("100,00 %", c1$text, fixed = TRUE))
  expect_match(c1$text, "Spider-Diagramm: Endwertdifferenz", fixed = TRUE)
  c2 <- wsh2_render(wsh_mc_comparison(), file = "cmp_mc.html")
  expect_match(c2$text, "P(a besser als base) = 100,00 %", fixed = TRUE)
  k <- wsh2_render(wsh_mc(), template = "gremium", file = "gremium.html")
  expect_false(grepl("id=\"TOC\"", k$html, fixed = TRUE))
  expect_match(k$html, "vofi-art-kurzvorlage", fixed = TRUE)
  expect_match(k$text, "Szenariotabelle", fixed = TRUE)
  expect_match(k$text, "ung\u00fcnstig (P5-Lauf)", fixed = TRUE)
  kh <- wsh2_render(self, template = "kurzvorlage", file = "kurz_haushalt.html")
  expect_match(kh$text, "Kurzfassung: Selbstnutzer EFH", fixed = TRUE)
  expect_false(grepl("Begriffe kurz erkl\u00e4rt", kh$text, fixed = TRUE))
})

test_that("Haushaltsmodus rendern: Vergleich und Simulation", {
  local_utf8()
  skip_if_no_report()
  hc <- wsh2_render(wsh2_self_cmp(), mode = "household", file = "haushalt_cmp.html")
  expect_match(hc$html, "vofi-modus-household", fixed = TRUE)
  expect_match(hc$text, lbl("report.html.sections.variants_household"), fixed = TRUE)
  expect_match(hc$text, "Gegen\u00fcber gas", fixed = TRUE)
  expect_match(hc$text, lbl("report.html.household.col_cum_saving"), fixed = TRUE)
  expect_false(grepl("<span class=\"neg\">", hc$html, fixed = TRUE))
  hm <- wsh2_render(wsh_mc(), mode = "household", file = "haushalt_mc.html")
  expect_match(hm$text, lbl("report.html.sections.risk_household"), fixed = TRUE)
  expect_match(hm$text, "In 3 von 10 simulierten Zuk\u00fcnften", fixed = TRUE)
  expect_match(hm$html, "data:image/png;base64,", fixed = TRUE)
  expect_false(grepl("[[report.", hm$text, fixed = TRUE))
})

test_that("Vorlagenparameter: Abschnitte, Verfasser, Logo, Titel, eigenes Stylesheet", {
  local_utf8()
  skip_if_no_report()
  dir <- withr::local_tempdir()
  logo <- file.path(dir, "logo.png")
  grDevices::png(logo, width = 120, height = 60)
  graphics::par(mar = c(0, 0, 0, 0))
  graphics::plot.new()
  grDevices::dev.off()
  css <- file.path(dir, "eigen.css")
  writeLines(".vofi-titel { color: #123456; }", css)
  r <- wsh2_render(example_result(), title = "Gremienvorlage M\u00e4rz",
                   template = list(sections = c("summary"), author = "Abteilung Controlling",
                                   logo = logo, css = css))
  expect_match(r$html, "<title>Gremienvorlage M\u00e4rz</title>", fixed = TRUE)
  expect_match(r$text, "Verfasser: Abteilung Controlling", fixed = TRUE)
  expect_match(r$html, "vofi-logo", fixed = TRUE)
  expect_match(r$html, "#123456", fixed = TRUE)
  expect_false(grepl("Kennzahlen mit und ohne Restwert", r$text, fixed = TRUE))
  expect_match(r$text, "Hinweise", fixed = TRUE)
})

test_that("eigene Rmd-Vorlage erh\u00e4lt body, report und x", {
  local_utf8()
  skip_if_no_report()
  dir <- withr::local_tempdir()
  rmd <- file.path(dir, "eigen.Rmd")
  writeLines(c("---", "params:", "  body: \"\"", "  x: null", "  report: null", "---", "",
               "Eigene Vorlage: `r class(params$x)[1]`, `r length(params$report$sections)`",
               "Abschnitte.", "",
               "```{r, echo = FALSE}", "knitr::asis_output(params$body)", "```"), rmd)
  r <- wsh2_render(example_result(), template = rmd)
  expect_match(r$text, "Eigene Vorlage: vofi_result, 12 Abschnitte.", fixed = TRUE)
  expect_match(r$text, "Management Summary", fixed = TRUE)
  # Fehler in der Vorlage: vofi_error_input mit der Meldung, keine Zieldatei
  bad <- file.path(dir, "fehler.Rmd")
  writeLines(c("---", "params:", "  body: \"\"", "---", "", "```{r}",
               "stop(\"Vorlagenfehler XY\")", "```"), bad)
  out <- file.path(dir, "fehler.html")
  e <- tryCatch(suppressMessages(vofi_report(example_result(), out, template = bad, open = FALSE)),
                error = identity)
  expect_s3_class(e, "vofi_error_input")
  expect_match(conditionMessage(e), "Vorlagenfehler XY", fixed = TRUE)
  expect_false(file.exists(out))
})

#' vofi_report() in einem eigenen R-Prozess mit den Umgebungsvariablen `env` (Gebietsschema
#' beim Start); das Paket wird wie im laufenden Prozess geladen (Quellbaum bzw. installiert)
wsh2_render_child <- function(res, env, dir) {
  rds <- file.path(dir, "res.rds")
  saveRDS(res, rds)
  out <- file.path(dir, paste0("bericht_", gsub("[^A-Za-z0-9]", "_", env[1L]), ".html"))
  pkg <- getNamespaceInfo(asNamespace("vofi"), "path")
  # Quellbaum (devtools/pkgload) bzw. installiertes Paket (R CMD check)
  dev <- file.exists(file.path(pkg, "R", "report-html.R"))
  load <- if (dev) {
    sprintf("suppressMessages(pkgload::load_all(%s, quiet = TRUE, helpers = FALSE))",
            deparse(pkg))
  } else {
    sprintf("suppressMessages(library(vofi, lib.loc = %s))", deparse(dirname(pkg)))
  }
  script <- file.path(dir, "kind.R")
  writeLines(c(load,
               sprintf("res <- readRDS(%s)", deparse(rds)),
               "cat('UTF8', isTRUE(l10n_info()[['UTF-8']]), '\\n')",
               sprintf("vofi_report(res, %s, template = 'kurzvorlage', open = FALSE)",
                       deparse(out)),
               "cat('CTYPE', Sys.getlocale('LC_CTYPE'), '\\n')"), script)
  rscript <- file.path(R.home("bin"), "Rscript")
  log <- suppressWarnings(system2(rscript, c("--no-save", "--no-restore", "--no-init-file",
                                             shQuote(script)),
                                  stdout = TRUE, stderr = TRUE, env = env))
  list(log = log, path = out, status = attr(log, "status") %||% 0L)
}

test_that("Rendern in R-Prozessen mit LANG=C.UTF-8 bzw. LANG=C erh\u00e4lt die Umlaute", {
  skip_if_no_report()
  dir <- withr::local_tempdir()
  res <- example_result()
  for (case in list(list(env = c("LANG=C.UTF-8", "LC_ALL=C.UTF-8"), utf8 = "TRUE"),
                    list(env = c("LANG=C", "LC_ALL=C"), utf8 = "FALSE"))) {
    r <- wsh2_render_child(res, case$env, dir)
    expect_identical(r$status, 0L, info = paste(r$log, collapse = "\n"))
    expect_true(any(grepl(paste("UTF8", case$utf8), r$log, fixed = TRUE)),
                info = paste(r$log, collapse = "\n"))
    # unter LANG=C stellt vofi_report() LC_CTYPE nur vorübergehend um
    if (identical(case$utf8, "FALSE")) {
      expect_true(any(grepl("CTYPE C", r$log, fixed = TRUE)), info = paste(r$log, collapse = "\n"))
    }
    expect_true(file.exists(r$path))
    html <- paste(readLines(r$path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
    expect_match(html, "Investition, Finanzierung und F\u00f6rderung", fixed = TRUE)
    expect_match(html, "Entscheidungsvorlage f\u00fcr Aufsichtsrat", fixed = TRUE)
    expect_match(html, "3.726 \u20ac", fixed = TRUE)
    expect_false(grepl("<U+", html, fixed = TRUE))
  }
})

test_that("Rendern im laufenden Prozess mit LC_CTYPE=C stellt den Zeichentyp wieder her", {
  skip_if_no_report()
  dir <- withr::local_tempdir()
  path <- file.path(dir, "c.html")
  local({
    withr::local_locale(c(LC_CTYPE = "C"))
    expect_false(isTRUE(l10n_info()[["UTF-8"]]))
    vofi_report(example_result(), path, template = "kurzvorlage", open = FALSE)
    expect_identical(Sys.getlocale("LC_CTYPE"), "C")
  })
  html <- paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_match(html, "Investition, Finanzierung und F\u00f6rderung", fixed = TRUE)
  expect_match(html, "3.726 \u20ac", fixed = TRUE)
})

test_that("Seitentitel: Markdown- und HTML-Zeichen erscheinen w\u00f6rtlich im <title>", {
  local_utf8()
  skip_if_no_report()
  expect_identical(rep_html_esc_meta("a*b [c] <d> \"e\" #1"),
                   "a\\*b \\[c\\] \\<d\\> \\\"e\\\" \\#1")
  r <- wsh2_render(example_result(), title = "Titel: \"A\" & <B> *x* #1 [c] $5",
                   template = "kurzvorlage", file = "titel.html")
  t <- regmatches(r$html, regexpr("<title>[^<]*</title>", r$html))
  expect_length(t, 1L)
  expect_match(t, paste0("^<title>Titel: (\"|&quot;)A(\"|&quot;) &amp; &lt;B&gt; \\*x\\* #1 ",
                         "\\[c\\] \\$5</title>$"))
  expect_false(grepl("<em>", t, fixed = TRUE))
  # Klammern und Dollarzeichen sind Text, keine TeX-Mathematik
  expect_match(gsub("\\s+", " ", r$html), "&lt;B&gt; *x* #1 [c] $5</span>", fixed = TRUE)
  expect_false(grepl("class=\"math", r$html, fixed = TRUE))
})

test_that("open = TRUE \u00f6ffnet den Bericht im Browser", {
  local_utf8()
  skip_if_no_report()
  seen <- new.env()
  withr::local_options(browser = function(url) assign("url", url, envir = seen))
  dir <- withr::local_tempdir()
  out <- vofi_report(example_result(), file.path(dir, "auf.html"), template = "kurzvorlage",
                     open = TRUE)
  expect_identical(seen$url, out)
})

test_that("DOCX ist intern technisch vorbereitet (Freigabe v1.1)", {
  local_utf8()
  skip_if_no_report()
  model <- wsh2_model(example_result(), template = "kurzvorlage")
  dir <- withr::local_tempdir()
  out <- rep_html_render(model, file.path(normalizePath(dir), "vorlage.docx"), "docx",
                         rep_html_template("kurzvorlage", "expert"))
  expect_true(file.exists(out))
  expect_identical(rawToChar(readBin(out, "raw", 2L)), "PK")
})
