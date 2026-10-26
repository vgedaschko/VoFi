# Tests für R/report-html.R (WS-H2): vofi_report() – HTML-Bericht im Fach- und Haushaltsmodus,
# Kurzvorlage (Gremien), Argumentprüfung, Pandoc-Markdown, Ampel-Rückfall (Spec 01 Teil C 6.6),
# Pflichtsensitivitäten (Teil C 4.4), Rendern unter LANG=C.UTF-8 und LC_CTYPE=C.

# ---------------------------------------------------------------------------------------------
# Hilfen
# ---------------------------------------------------------------------------------------------

#' UTF-8-Zeichentyp bis zum Ende des Aufrufers (wie in vofi_report(); unter LANG=C sonst
#' Übersetzungswarnungen bei Texten mit Umlauten)
local_utf8 <- function(env = parent.frame()) {
  old <- rep_html_utf8_locale()
  if (!is.null(old)) withr::defer(Sys.setlocale("LC_CTYPE", old), envir = env)
  invisible(old)
}

#' Berichtsmodell ohne Rendern (Kontext wie in vofi_report())
wsh2_model <- function(x, mode = "auto", template = NULL, title = NULL) {
  local_utf8()
  parts <- rep_html_parts(x)
  mode <- rep_html_mode(mode, parts$main)
  opts <- rep_html_template(template, mode)
  rep_html_model(rep_html_context(parts, mode, opts), title)
}

#' Pandoc-Markdown eines Berichtsmodells (Grafiken in ein temporäres Verzeichnis)
wsh2_markdown <- function(model, env = parent.frame()) {
  local_utf8()
  dir <- withr::local_tempdir(.local_envir = env)
  rep_html_markdown(model, dir)
}

#' Ids der Abschnitte eines Modells
wsh2_ids <- function(model) vapply(model$sections, function(s) s$id, "")

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

test_that("fehlendes rmarkdown bzw. pandoc ergibt eine deutsche Meldung", {
  local_utf8()
  res <- example_result()
  dir <- withr::local_tempdir()
  local_mocked_bindings(utl_require = function(pkg, fun) {
    vofi_abort("core.suggests_missing", pkg = pkg, fun = fun, .class = "vofi_error_input")
  })
  e <- tryCatch(vofi_report(res, file.path(dir, "b.html"), open = FALSE), error = identity)
  expect_s3_class(e, "vofi_error_input")
  expect_match(conditionMessage(e), "rmarkdown", fixed = TRUE)
  expect_match(conditionMessage(e), "install.packages", fixed = TRUE)
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

test_that("Ampel der Simulation: Pr\u00fcff\u00e4lle A1-A6, A10-A12 (Teil C 6.6)", {
  local_utf8()
  skip_if(is.function(get0("cmp_traffic_light", envir = asNamespace("vofi"))),
          "cmp_traffic_light() vorhanden (WS-G); R\u00fcckfall nicht aktiv")
  base <- wsh_mc()
  v <- function(n_neg, n_pos) c(rep(-500, n_neg), rep(1200, n_pos))
  a1 <- rep_html_tl(wsh2_tl_mc(v(25, 75), mc = base))
  expect_identical(c(a1$level, a1$stage1, a1$basis), c("green", "green", "mc"))
  expect_false(a1$rv_dependent)
  a2 <- rep_html_tl(wsh2_tl_mc(v(25, 75), base_ex_rv = -10, mc = base))
  expect_identical(a2$level, "yellow")
  expect_true(a2$rv_dependent)
  expect_true("report.traffic.rv_dependent" %in% a2$notes)
  expect_identical(rep_html_tl(wsh2_tl_mc(v(45, 55), mc = base))$level, "yellow")
  expect_identical(rep_html_tl(wsh2_tl_mc(v(65, 35), mc = base))$level, "red")
  r5 <- list(dscr = list(base = 0, mc = c(rep(1, 31), rep(0, 69))))
  a5 <- rep_html_tl(wsh2_tl_mc(v(20, 80), mc = base, restr = r5))
  expect_identical(c(a5$stage1, a5$level), c("green", "yellow"))
  expect_true(a5$restrictions$ko[1L])
  expect_equal(a5$restrictions$prob[1L], 0.31)
  a6 <- rep_html_tl(wsh2_tl_mc(v(20, 80), mc = base, restr = list(burden = list(base = 1, mc = 0))))
  expect_identical(a6$level, "yellow")
  expect_true(a6$restrictions$violated_base[1L])
  expect_identical(rep_html_tl(wsh2_tl_mc(v(30, 70), mc = base))$level, "green")
  expect_identical(rep_html_tl(wsh2_tl_mc(v(60, 40), mc = base))$level, "yellow")
  r12 <- list(liquidity = list(base = NA_real_, mc = NA_real_))
  a12 <- rep_html_tl(wsh2_tl_mc(v(20, 80), mc = base, restr = r12))
  expect_identical(a12$level, "green")
  expect_false(a12$restrictions$ko[1L])
  expect_true(any(grepl(rep_restriction_label("liquidity"), a12$notes, fixed = TRUE)))
  # Vorrang des gespeicherten Felds traffic_light
  mc <- wsh2_tl_mc(v(25, 75), mc = base)
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

test_that("Pflichtsensitivit\u00e4ten: Pr\u00fcfwerte Teil C 4.4, Status, Was-w\u00e4re-wenn", {
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
  # ohne Tabelle und ohne Szenario: hinterlegte Einträge als „nicht gerechnet“
  rc2 <- rep_html_context(rep_html_parts(wsh2_run(wsh_landlord_scenario())), "expert",
                          rep_html_template(NULL, "expert"))
  expect_null(rep_html_mandatory(rc2))
  b <- rep_html_mandatory_blocks(rc2)
  tab <- Filter(function(x) identical(x$type, "table"), b)[[1L]]$m
  expect_true(lbl("report.html.sensitivity.status_ex_rv") %in% tab[, 2L])
  expect_true(lbl("report.html.sensitivity.status_not_computed") %in% tab[, 2L])
})

test_that("Zielwertsuchen (vofi_solution): bei Sensitivit\u00e4ten und in der Kurzvorlage", {
  local_utf8()
  res <- example_result()
  sols <- list(
    new_vofi_solution(list(what = "critical_value", param = "accounts.deposit_rate_pa",
                           kpi = "delta_terminal_value", value = 0.0412)),
    new_vofi_solution(list(what = "withdrawal_equivalent", value = 1234.4, monotone = FALSE,
                           prob_exceed = 0.25))
  )
  p <- rep_html_parts(list(res, sols[[1L]], sols[[2L]]))
  expect_length(p$solutions, 2L)
  m <- rep_html_solution_matrix(p$solutions)
  expect_identical(dim(m), c(2L, 6L))
  expect_identical(unname(m[, 1L]), c(lbl("report.html.sensitivity.what_critical_value"),
                                      lbl("report.html.sensitivity.what_withdrawal_equivalent")))
  expect_identical(unname(m[1L, 5L]), "4,12 %")
  expect_identical(unname(m[2L, 5L]), "1.234 \u20ac")
  expect_identical(unname(m[, 4L]), c("0,00", ""))
  expect_match(m[2L, 6L], lbl("report.html.sensitivity.not_monotone"), fixed = TRUE)
  expect_match(m[2L, 6L], "25,0 %", fixed = TRUE)
  expect_identical(ncol(rep_html_solution_matrix(sols[1L])), 5L)
  expect_null(rep_html_solution_matrix(list()))
  md <- wsh2_markdown(wsh2_model(list(res, sols[[1L]])))
  expect_match(md, lbl("report.html.sensitivity.solutions_header"), fixed = TRUE)
  expect_match(md, "accounts.deposit\\_rate\\_pa", fixed = TRUE)
  k <- wsh2_markdown(wsh2_model(list(res, sols[[1L]]), template = "kurzvorlage"))
  expect_match(k, lbl("report.html.sensitivity.solutions_header"), fixed = TRUE)
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

test_that("Vergleich: P(A besser als B), Rangfolge, Ampel je Variante, Tornado", {
  local_utf8()
  md <- wsh2_markdown(wsh2_model(list(example_comparison(), wsh_sensitivity("tornado")),
                                 "expert"))
  expect_match(md, "P(a besser als base) = 100,00 %", fixed = TRUE)
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

test_that("Haushaltsmodus mit Vergleich: Ersparnis in Worten statt Vorzeichen", {
  local_utf8()
  gas <- wsh2_run(wsh2_self_scenario(energy = 4500, capex = -12000, loan = 0, id = "gas",
                                     grant = 0))
  wp <- wsh2_run(wsh2_self_scenario())
  cmp <- wsh_comparison(list(gas = gas, wp = wp))
  model <- wsh2_model(cmp, "household")
  expect_true("variants" %in% wsh2_ids(model))
  md <- wsh2_markdown(model)
  s <- attr(vofi_household_view(cmp), "summary")
  sv <- s$text[s$variant == "wp" & s$item == "saving_y1"]
  expect_match(md, rep_html_esc(sv), fixed = TRUE)
  expect_match(sv, "Gegen\u00fcber gas", fixed = TRUE)
  expect_false(grepl("\\| -[0-9]", md))  # keine negativen Monatsbetr\u00e4ge in Haushaltstabellen
  expect_match(md, paste("##", lbl("report.html.vofi_table.variant_header", variant = "wp")),
               fixed = TRUE)
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
  self <- wsh2_run(wsh2_self_scenario())
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
  expect_match(c1$text, "P(a besser als base) = 100,00 %", fixed = TRUE)
  expect_match(c1$text, "Spider-Diagramm: Endwertdifferenz", fixed = TRUE)
  k <- wsh2_render(wsh_mc(), template = "gremium", file = "gremium.html")
  expect_false(grepl("id=\"TOC\"", k$html, fixed = TRUE))
  expect_match(k$html, "vofi-art-kurzvorlage", fixed = TRUE)
  expect_match(k$text, "Szenariotabelle", fixed = TRUE)
  expect_match(k$text, "ung\u00fcnstig (P5-Lauf)", fixed = TRUE)
  kh <- wsh2_render(self, template = "kurzvorlage", file = "kurz_haushalt.html")
  expect_match(kh$text, "Kurzfassung: Selbstnutzer EFH", fixed = TRUE)
  expect_false(grepl("Begriffe kurz erkl\u00e4rt", kh$text, fixed = TRUE))
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

test_that("Rendern unter LANG=C.UTF-8 und unter LC_CTYPE=C erh\u00e4lt die Umlaute", {
  skip_if_no_report()
  withr::local_envvar(LANG = "C.UTF-8", LC_ALL = "C.UTF-8")
  r <- wsh2_render(example_result(), template = "kurzvorlage", file = "utf8.html")
  expect_match(r$text, "Investition, Finanzierung und F\u00f6rderung", fixed = TRUE)
  expect_match(r$text, "Entscheidungsvorlage f\u00fcr Aufsichtsrat", fixed = TRUE)
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
