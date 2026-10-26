# Code-Token aller Dateien in R/ sind ASCII (Integrator; Spec 00 Abschnitte 2.7 Nr. 1, 15.6).
# Geprüft werden alle Token außer COMMENT; deutsche Kommentare und roxygen-Doku sind erlaubt.

test_that("Code-Token in R/ sind ASCII (Quelltext, falls verfügbar)", {
  rdir <- testthat::test_path("..", "..", "R")
  skip_if_not(dir.exists(rdir), "Quelltext R/ nicht verfügbar (installiertes Paket)")
  files <- list.files(rdir, pattern = "\\.[Rr]$", full.names = TRUE)
  expect_true(length(files) > 10L)
  for (f in files) {
    src <- readLines(f, encoding = "UTF-8", warn = FALSE)
    pd <- utils::getParseData(parse(f, keep.source = TRUE, encoding = "UTF-8"))
    tok <- pd[pd$terminal & pd$token != "COMMENT", , drop = FALSE]
    # Rohtext des Tokens aus der Quelldatei (getParseData() löst \u-Escapes in Zeichenketten auf)
    raw <- vapply(seq_len(nrow(tok)), function(i) {
      l1 <- tok$line1[i]
      l2 <- tok$line2[i]
      if (l1 == l2) return(substr(src[l1], tok$col1[i], tok$col2[i]))
      paste(c(substring(src[l1], tok$col1[i]), if (l2 > l1 + 1L) src[(l1 + 1L):(l2 - 1L)],
              substr(src[l2], 1L, tok$col2[i])), collapse = "\n")
    }, character(1))
    bad <- tok[grepl("[^\\x01-\\x7F]", raw, perl = TRUE), , drop = FALSE]
    expect_identical(nrow(bad), 0L,
                     info = paste(basename(f), paste(bad$line1, bad$text, collapse = "; ")))
  }
})

test_that("Symbole der Funktionskörper im Namensraum sind ASCII (installiertes Paket)", {
  # Zeichenketten dürfen zur Laufzeit Nicht-ASCII enthalten, wenn sie im Quelltext als
  # Unicode-Escape stehen ("\\u20ac"); geprüft werden hier nur Bezeichner.
  ns <- asNamespace("vofi")
  acc <- new.env(parent = emptyenv())
  acc$bad <- character(0)
  check <- function(e, where) {
    if (is.symbol(e)) {
      if (grepl("[^\\x01-\\x7F]", as.character(e), perl = TRUE)) acc$bad <- c(acc$bad, where)
    } else if (is.call(e) || is.pairlist(e)) {
      parts <- as.list(e)
      for (i in seq_along(parts)) {
        if (!identical(parts[[i]], quote(expr = ))) check(parts[[i]], where)
      }
    }
  }
  for (nm in ls(ns, all.names = TRUE)) {
    f <- get(nm, envir = ns)
    if (is.function(f) && !is.primitive(f)) {
      check(body(f), nm)
      check(formals(f), nm)
    }
  }
  expect_identical(unique(acc$bad), character(0))
})
