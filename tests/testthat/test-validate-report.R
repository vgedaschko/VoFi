# Tests für R/validate-report.R (WS-B; Spec 00 Abschnitte 13.5, 13.6, 15.6).

wsb_report_scenario <- function() {
  wsb_with("skeleton", function(x) {
    x$accounts$deposit_rate <- 0.02
    x$tax$module <- "flatt"
    x$variants <- list(v1 = list(label = "v1", set = list("accounts.deposit_rate_pa" = 0.03)))
    x
  })
}

test_that("Prüffälle Ausdrücke, Bericht und JSON-Schema (Tabelle)", {
  wsb_expect_cases(wsb_cases_other())
})

test_that("Bericht: eine Zeile je Befund und Variante, format() fasst Varianten zusammen", {
  v <- wsb_validate(wsb_report_scenario())
  expect_s3_class(v, "vofi_validation")
  expect_identical(nrow(v), 4L)
  expect_setequal(v$variant, c("base", "v1"))
  txt <- format(v)
  expect_identical(length(txt), 3L)
  expect_identical(txt[1L], lbl("validation.report.header", errors = 2L, warnings = 0L,
                                infos = 0L))
  expect_true(all(grepl(lbl("validation.report.variants", variants = "base, v1"), txt[2:3],
                        fixed = TRUE)))
  expect_match(txt[2L], "accounts.deposit_rate", fixed = TRUE)
  expect_output(res <- withVisible(print(v)), "Unbekanntes Steuermodul", fixed = TRUE)
  expect_false(res$visible)
  expect_identical(res$value, v)
  expect_output(print(v, max_rows = 1), "1 weitere", fixed = TRUE)
})

test_that("Bericht: Sortierung nach Schwere und Pfad, Fundstelle, max_rows", {
  v <- wsb_validate(wsb_with("domain", function(x) {
    x$unit_groups$a$vacancy_rate <- 0.2
    x$building$property_tax <- NULL
    x$measures$huelle$useful_life_years <- 0
    x
  }), variant = "base")
  rows <- val_report_rows(v)
  rank <- match(rows$severity, c("error", "warning", "info"))
  expect_false(is.unsorted(rank))
  expect_false(is.unsorted(rows$path[rank == 2L]))
  expect_identical(rows$severity[1L], "error")
  v$location[v$code == "validation.range"] <- "scenario.yaml:12"
  txt <- format(v)
  expect_match(txt[2L], lbl("validation.report.location", location = "scenario.yaml:12"),
               fixed = TRUE)
  # nur die Basis: keine Variantenangabe
  expect_false(any(grepl("Varianten:", txt, fixed = TRUE)))
  short <- format(v, max_rows = 0)
  expect_identical(short[2L], lbl("validation.report.more", n = nrow(rows)))
  expect_error(format(v, max_rows = -1), class = "vofi_error_input")
  expect_error(format(v, max_rows = "a"), class = "vofi_error_input")
  expect_identical(length(format(v, max_rows = Inf)), nrow(rows) + 1L)
})

test_that("Leerer Bericht und as.data.frame()", {
  v <- wsb_validate(example_scenario("skeleton"))
  expect_identical(format(v), c(lbl("validation.report.header", errors = 0L, warnings = 0L,
                                    infos = 0L),
                                lbl("validation.report.none")))
  df <- as.data.frame(wsb_validate(wsb_report_scenario()))
  expect_identical(class(df), "data.frame")
  expect_identical(names(df), c("severity", "code", "path", "location", "message", "layer",
                                "variant"))
  expect_identical(rownames(df), as.character(seq_len(nrow(df))))
  df2 <- as.data.frame(wsb_validate(wsb_report_scenario()), row.names = letters[1:4])
  expect_identical(rownames(df2), letters[1:4])
  expect_type(df$layer, "integer")
})

test_that("Filter min_severity und Argumentprüfung", {
  sc <- wsb_with("domain", function(x) {
    x$unit_groups$a$vacancy_rate <- 0.2
    x$building$property_tax <- NULL
    x
  })
  all <- wsb_validate(sc, variant = "base")
  expect_setequal(all$severity, c("warning", "info"))
  w <- wsb_validate(sc, variant = "base", min_severity = "warning")
  expect_identical(unique(w$severity), "warning")
  expect_identical(nrow(wsb_validate(sc, variant = "base", min_severity = "error")), 0L)
  expect_error(wsb_validate(sc, variant = 1), class = "vofi_error_input")
  expect_error(wsb_validate(sc, min_severity = "fatal"))
})

test_that("Jede Meldung der Validierung wird von mindestens einem Prüffall ausgelöst (15.6)", {
  keys <- wsb_label_keys()
  expect_true(length(keys) > 300L)
  covered <- unique(unlist(lapply(wsb_all_cases(), `[[`, "codes")))
  # Befunde der Typprüfungen (validate() der Typen) decken die Typtests ab (wsb_type_keys())
  expect_identical(setdiff(keys, c(covered, wsb_type_keys())), character(0))
  # Keine Prüffälle mit Codes außerhalb des Katalogs
  expect_identical(setdiff(covered, keys), character(0))
})

test_that("Snapshot des Validierungsberichts (Spec 00 15.6)", {
  skip_if_not(l10n_info()[["UTF-8"]])
  v <- wsb_validate(wsb_with("skeleton", function(x) {
    x$accounts$deposit_rate <- 0.02
    x$accounts$overdraft_rate_pa <- 0.5
    x$accounts$deposit_rate_pa <- 0.09
    x$project$comparison_mode <- "differential"
    x$variants <- list(v1 = list(label = "Variante 1",
                                 set = list("accounts.deposit_rate_pa" = 0.03)))
    x
  }))
  expect_snapshot(print(v))
  expect_snapshot(print(v, max_rows = 2))
})
