# Tests für R/labels.R (Integrator; Spec 00 Abschnitte 2.10, 15.6 "Labels").

test_that("lbl: Schl\u00fcssel, Pr\u00e4fix aus dem Dateipfad, Platzhalter", {
  expect_true(lbl_has("core.rows.balance_check"))
  expect_identical(lbl("core.rows.balance_check"), "Finanzierungssaldo")
  expect_true(lbl_has("vocab.categories.project.capex"))
  expect_true(lbl_has("vocab.tax_categories.income_rental"))
  expect_true(lbl_has("vocab.na_reasons.no_equity"))
  expect_identical(msg("core.not_implemented", fun = "f"), lbl("core.not_implemented", fun = "f"))
  expect_match(lbl("core.not_implemented", fun = "vofi_build"), "vofi_build()", fixed = TRUE)
  expect_true(length(lbl_keys("core.rows")) > 10L)
  expect_true(all(startsWith(lbl_keys("vocab.sections"), "vocab.sections.")))
})

test_that("Platzhalterformate nach 2.10", {
  dir <- withr::local_tempdir()
  writeLines(c(
    'plain: "{x}"', 'int: "{x:int}"', 'num: "{x:num}"', 'pct: "{x:pct}"', 'eur: "{x:eur}"',
    'date: "{x:date}"', 'raw: "{x:raw}"', 'two: "{a} und {b}"', 'brace: "{ref: market.x}"'
  ), file.path(dir, "t.yaml"))
  old_env <- lbl_state$labels
  old_src <- lbl_state$sources
  old_dir <- lbl_state$dir
  withr::defer({
    lbl_state$labels <- old_env
    lbl_state$sources <- old_src
    lbl_state$dir <- old_dir
  })
  expect_identical(lbl_load(dir), 9L)
  expect_identical(lbl("t.plain", x = 1234.5), "1.234,50")
  expect_identical(lbl("t.plain", x = 3L), "3")
  expect_identical(lbl("t.plain", x = "Text"), "Text")
  expect_identical(lbl("t.plain", x = as.Date("2026-10-25")), "25.10.2026")
  expect_identical(lbl("t.plain", x = c("a", "b")), "a, b")
  expect_identical(lbl("t.int", x = 1234567), "1.234.567")
  expect_identical(lbl("t.num", x = 2), "2,00")
  expect_identical(lbl("t.pct", x = 0.038), "3,80 %")
  expect_identical(lbl("t.eur", x = 1234), "1.234 \u20ac")
  expect_identical(lbl("t.date", x = "2027-01-01"), "01.01.2027")
  expect_identical(lbl("t.raw", x = 1234.5), "1234.5")
  expect_identical(lbl("t.two", a = 1L, b = "x"), "1 und x")
  expect_identical(lbl("t.brace"), "{ref: market.x}")
  local_vofi_options(vofi.strict_labels = FALSE)
  expect_identical(lbl("t.two", a = 1L), "1 und {b}")
  local_vofi_options(vofi.strict_labels = TRUE)
  expect_error(lbl("t.two", a = 1L), class = "vofi_error_label")
})

test_that("fehlende Schl\u00fcssel und .default", {
  local_vofi_options(vofi.strict_labels = TRUE)
  expect_error(lbl("core.gibt_es_nicht"), class = "vofi_error_label")
  expect_identical(lbl("core.gibt_es_nicht", .default = "D {x}", x = 1L), "D 1")
  local_vofi_options(vofi.strict_labels = FALSE)
  expect_identical(lbl("core.gibt_es_nicht"), "[[core.gibt_es_nicht]]")
  expect_false(lbl_has("core.gibt_es_nicht"))
  expect_false(lbl_has(NA_character_))
})

test_that("lbl_load: doppelte Schl\u00fcssel und fehlendes Verzeichnis sind Fehler", {
  old_env <- lbl_state$labels
  old_src <- lbl_state$sources
  old_dir <- lbl_state$dir
  withr::defer({
    lbl_state$labels <- old_env
    lbl_state$sources <- old_src
    lbl_state$dir <- old_dir
  })
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "a"))
  writeLines('b: {c: "x"}', file.path(dir, "a.yaml"))
  writeLines('c: "y"', file.path(dir, "a", "b.yaml"))
  expect_error(lbl_load(dir), class = "vofi_error_label")
  expect_error(lbl_load(file.path(dir, "fehlt")), class = "vofi_error_label")
  dir2 <- withr::local_tempdir()
  writeLines(c('k: "M\u00e4rz"', 'liste: [a, b]', 'n: ~', 'yes: "Ja"'), file.path(dir2, "u.yaml"),
             useBytes = TRUE)
  lbl_load(dir2)
  expect_identical(lbl("u.k"), "M\u00e4rz")
  expect_identical(Encoding(lbl("u.k")), "UTF-8")
  expect_identical(lbl("u.liste"), "a\nb")
  expect_identical(lbl("u.yes"), "Ja")
  expect_false(lbl_has("u.n"))
})

test_that("Label-Katalog ist unter Locale C lesbar (UTF-8)", {
  skip_on_cran()
  withr::local_locale(c(LC_CTYPE = "C"))
  old_env <- lbl_state$labels
  old_src <- lbl_state$sources
  old_dir <- lbl_state$dir
  withr::defer({
    lbl_state$labels <- old_env
    lbl_state$sources <- old_src
    lbl_state$dir <- old_dir
  })
  n <- lbl_load(system.file("labels", "de", package = "vofi"))
  expect_true(n > 100L)
  expect_identical(lbl("vocab.sections.grants"), "Zusch\u00fcsse")
})

#' Literale Label-Schlüssel aus allen Funktionen des Namensraums sammeln
helper_label_keys_in_code <- function() {
  ns <- asNamespace("vofi")
  callers <- c("lbl", "msg", "vofi_abort", "vofi_warn", "vofi_inform", "utl_label_error")
  acc <- new.env(parent = emptyenv())
  acc$keys <- character(0)
  walk <- function(e) {
    if (is.call(e)) {
      fn <- e[[1L]]
      fname <- if (is.symbol(fn)) as.character(fn) else if (is.call(fn) &&
                                                           identical(fn[[1L]], as.name("$"))) {
        paste0("$", as.character(fn[[3L]]))
      } else {
        ""
      }
      if ((fname %in% callers || fname %in% c("$abort", "$warn", "$inform", "$lbl")) &&
          length(e) >= 2L && is.character(e[[2L]]) &&
          (is.null(names(e)) || !nzchar(names(e)[2L]) || names(e)[2L] == "key") &&
          !(".default" %in% names(e))) {
        acc$keys <- c(acc$keys, e[[2L]])
      }
      parts <- as.list(e)[-1L]
      for (i in seq_along(parts)) {
        if (!identical(parts[[i]], quote(expr = ))) walk(parts[[i]])
      }
    } else if (is.pairlist(e) || is.expression(e)) {
      parts <- as.list(e)
      for (i in seq_along(parts)) {
        if (!identical(parts[[i]], quote(expr = ))) walk(parts[[i]])
      }
    }
  }
  for (nm in ls(ns, all.names = TRUE)) {
    f <- get(nm, envir = ns)
    if (is.function(f) && !is.primitive(f)) {
      walk(body(f))
      walk(formals(f))
    }
  }
  unique(acc$keys)
}

test_that("jeder in R/ verwendete Label-Schl\u00fcssel existiert (15.6)", {
  keys <- helper_label_keys_in_code()
  expect_true(length(keys) > 50L)
  missing_keys <- keys[!vapply(keys, lbl_has, logical(1))]
  expect_identical(missing_keys, character(0))
})

test_that("Platzhalter 'key' nur in den Label-Fehlertexten (Kollision mit lbl(key, ...))", {
  keys <- lbl_keys()
  uses_key <- keys[vapply(keys, function(k) grepl("{key}", lbl_state$labels[[k]], fixed = TRUE),
                          logical(1))]
  expect_setequal(uses_key, c("core.label_missing", "core.label_placeholder_missing"))
})
