# Referenzszenarien S1-S5 und grob_lehrbuch_a aus Spec 01 Teil C §5 ohne falsche Fehler
# (WS-B, Review m5). Die Szenarien stehen als YAML-Listings in der Spezifikation; der Test
# liest sie von dort, weil die Beispieldateien erst WS-S liefert. Er läuft nur im Quellbaum
# (docs/ ist nicht Teil des Pakets) und erst, wenn Bibliothek, Defaults (WS-A, WS-L) und
# Prozesstypen (WS-C) integriert sind.

wsb_spec_examples <- function(file) {
  lines <- readLines(file, encoding = "UTF-8", warn = FALSE)
  out <- list()
  cur <- NULL
  buf <- character(0)
  in_block <- FALSE
  for (ln in lines) {
    if (startsWith(ln, "```")) {
      if (in_block && !is.null(cur)) out[[cur]] <- buf
      in_block <- !in_block
      cur <- NULL
      buf <- character(0)
      next
    }
    if (!in_block) next
    m <- regmatches(ln, regexec("^# inst/extdata/examples/([a-z0-9_]+)\\.yaml", ln))[[1L]]
    if (length(m) == 2L && is.null(cur) && length(buf) == 0L) {
      cur <- m[2L]
      next
    }
    buf <- c(buf, ln)
  }
  out
}

test_that("Referenzszenarien aus Spec 01 Teil C §5: keine falschen Fehler", {
  spec_file <- testthat::test_path("..", "..", "docs", "spec",
                                   "01c_feldkatalog_stochastik_bibliothek_szenarien.md")
  skip_if_not(file.exists(spec_file), "Spezifikation nicht im Quellbaum")
  skip_if_stub("vofi_library", "vofi_read_scenario")
  skip_if_not(nzchar(system.file("extdata", "library", "VERSION", package = "vofi")),
              "Parameterbibliothek (WS-L) fehlt")
  skip_if(nrow(reg_list("process")) == 0L, "Prozesstypen (WS-C) fehlen")
  ex <- wsb_spec_examples(spec_file)
  expect_true(all(c("s1_wu_mfh_1963_eh70", "s2_wu_neubau_mfh_36we", "s3_eg_waermepumpe_pv",
                    "s4_efh_1975_isfp", "s5_neubau_efh_eh40", "grob_lehrbuch_a") %in% names(ex)))
  # Bekannter Widerspruch der Spezifikation (an den Integrator gemeldet): Spec 00 4.11 erlaubt
  # add nur für <sammlung>.<id>; S2, S3 (energy.pv) und S5 (energy.after.extra_consumption.*)
  # verwenden add für andere Pfade.
  known <- c("validation.variants.add_not_collection")
  for (nm in names(ex)) {
    f <- withr::local_tempfile(fileext = ".yaml")
    writeLines(ex[[nm]], f, useBytes = TRUE)
    sc <- suppressWarnings(suppressMessages(vofi_read_scenario(f)))
    v <- suppressWarnings(suppressMessages(vofi_validate(sc)))
    e <- v[v$severity == "error" & !(v$code %in% known), , drop = FALSE]
    # Kennzahlen registriert WS-D2; ohne sie sind kpi-Befunde nicht aussagekräftig
    if (!reg_has("kpi", "roe_irr")) e <- e[e$code != "validation.kpi_unknown", , drop = FALSE]
    expect_identical(nrow(e), 0L, info = paste(nm, wsb_errors(e)))
  }
})
