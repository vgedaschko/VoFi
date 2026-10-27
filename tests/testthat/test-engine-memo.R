# Zwischenspeicher reiner Hilfsrechnungen über Läufe hinweg (WS-PERF, Spec 00 Abschnitt 9.10).

test_that("eng_memo: Treffer nur bei identischen Argumenten, neue Rechnung sonst", {
  eng_memo_clear("test_memo_a")
  on.exit(eng_memo_clear("test_memo_a"), add = TRUE)
  calls <- new.env()
  calls$n <- 0L
  f <- function(x) {
    eng_memo("test_memo_a", list(x), function() {
      calls$n <- calls$n + 1L
      x * 2
    })
  }
  expect_identical(f(1:3), c(2, 4, 6))
  expect_identical(f(1:3), c(2, 4, 6))
  expect_identical(calls$n, 1L)
  # gleiche Werte, anderer Typ: kein Treffer (identical())
  expect_identical(f(c(1, 2, 3)), c(2, 4, 6))
  expect_identical(calls$n, 2L)
  expect_identical(f(4L), 8)
  expect_identical(calls$n, 3L)
  expect_identical(f(1:3), c(2, 4, 6))
  expect_identical(calls$n, 3L)
})

test_that("eng_memo: Größe je Art begrenzt (älteste Einträge fallen heraus)", {
  eng_memo_clear("test_memo_b")
  on.exit(eng_memo_clear("test_memo_b"), add = TRUE)
  calls <- new.env()
  calls$n <- 0L
  f <- function(x) {
    eng_memo("test_memo_b", list(x), function() {
      calls$n <- calls$n + 1L
      x
    }, size = 2L)
  }
  for (x in 1:3) f(x)
  expect_identical(calls$n, 3L)
  f(3L)
  f(2L)
  expect_identical(calls$n, 3L)
  f(1L)
  expect_identical(calls$n, 4L)
  expect_length(eng_memo_env[["test_memo_b"]], 2L)
})

test_that("eng_memo: Rechnungen mit Meldung werden nicht gespeichert, Fehler nicht", {
  eng_memo_clear("test_memo_c")
  on.exit(eng_memo_clear("test_memo_c"), add = TRUE)
  calls <- new.env()
  calls$n <- 0L
  f <- function() {
    eng_memo("test_memo_c", list("k"), function() {
      calls$n <- calls$n + 1L
      message("Hinweis")
      1
    })
  }
  expect_message(expect_identical(f(), 1), "Hinweis")
  expect_message(expect_identical(f(), 1), "Hinweis")
  expect_identical(calls$n, 2L)
  expect_null(eng_memo_env[["test_memo_c"]])
  w <- function() {
    eng_memo("test_memo_c", list("w"), function() {
      warning("Warnung")
      2
    })
  }
  expect_warning(w(), "Warnung")
  expect_warning(w(), "Warnung")
  e <- function() eng_memo("test_memo_c", list("e"), function() stop("Fehler"))
  expect_error(e(), "Fehler")
  expect_null(eng_memo_env[["test_memo_c"]])
})

test_that("eng_grid_memo speichert nur kleine Eingaben; eng_memo_clear leert Arten", {
  eng_memo_clear(c("test_memo_d", "test_memo_e"))
  on.exit(eng_memo_clear(c("test_memo_d", "test_memo_e")), add = TRUE)
  calls <- new.env()
  calls$n <- 0L
  f <- function(small) {
    eng_grid_memo("test_memo_d", list(1), small, function() {
      calls$n <- calls$n + 1L
      1
    })
  }
  f(FALSE)
  f(FALSE)
  expect_identical(calls$n, 2L)
  f(TRUE)
  f(TRUE)
  expect_identical(calls$n, 3L)
  eng_memo("test_memo_e", list(1), function() 1)
  expect_true(all(c("test_memo_d", "test_memo_e") %in% ls(eng_memo_env)))
  eng_memo_clear("test_memo_d")
  expect_false("test_memo_d" %in% ls(eng_memo_env))
  expect_true("test_memo_e" %in% ls(eng_memo_env))
  expect_invisible(eng_memo_clear("nicht_vorhanden"))
})

test_that("Läufe mit und ohne Zwischenspeicher ergeben denselben Ledger", {
  model <- suppressMessages(vofi_build(wsd_bench_scenario(20L, 12L)))
  eng_memo_clear()
  a <- suppressWarnings(suppressMessages(vofi_run(model)))
  b <- suppressWarnings(suppressMessages(vofi_run(model)))
  wsp_expect_same(a$ledger$values, b$ledger$values, "Ledger")
  expect_identical(a$ledger$rows, b$ledger$rows)
  expect_identical(a$kpis, b$kpis)
  expect_identical(a$flags, b$flags)
})

test_that("Zeilenmetadaten der Komponenten folgen dem geladenen Label-Katalog", {
  model <- suppressMessages(vofi_build(wsd_bench_scenario(5L, 0L)))
  env <- eng_engine_env(model, quiet = TRUE)
  ctx <- eng_context(model, NULL, env)
  a <- eng_flows(model, ctx, env)$ledger$rows
  old <- lbl_state$labels
  on.exit(lbl_state$labels <- old, add = TRUE)
  # Kopie des Katalogs mit geändertem Label einer Zeile (wie ein erneutes lbl_load())
  new <- list2env(as.list(old, all.names = TRUE),
                  envir = new.env(hash = TRUE, parent = emptyenv()))
  key <- a$label_key[a$source_id == "rent"][1L]
  skip_if(is.na(key) || !exists(key, envir = new, inherits = FALSE), "kein Typlabel")
  assign(key, "Geaenderte Miete", envir = new)
  lbl_state$labels <- new
  b <- eng_flows(model, ctx, env)$ledger$rows
  expect_true(any(grepl("Geaenderte Miete", b$label[b$source_id == "rent"], fixed = TRUE)))
  lbl_state$labels <- old
  d <- eng_flows(model, ctx, env)$ledger$rows
  expect_identical(d, a)
})
