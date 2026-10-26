# Tests für R/conditions.R (Integrator; Spec 00 Abschnitt 2.9).

test_that("vofi_abort: Klassen, Felder, Text aus dem Katalog", {
  e <- tryCatch(vofi_abort("core.file_missing", path = "x.yaml", .class = "vofi_error_input",
                           .data = list(a = 1)),
                error = identity)
  expect_s3_class(e, c("vofi_error_input", "vofi_error", "error", "condition"), exact = TRUE)
  expect_identical(e$key, "core.file_missing")
  expect_identical(e$data, list(a = 1))
  expect_identical(e$args, list(path = "x.yaml"))
  expect_match(conditionMessage(e), "x.yaml", fixed = TRUE)
  expect_false(grepl("[[", conditionMessage(e), fixed = TRUE))
})

test_that("vofi_abort: Default-Klasse f\u00fcr core.not_implemented, Aufruf", {
  f <- function() vofi_abort("core.not_implemented", fun = "f")
  e <- tryCatch(f(), error = identity)
  expect_s3_class(e, "vofi_error_not_implemented")
  expect_identical(deparse(e$call), "f()")
  expect_error(vofi_abort("core.not_implemented", fun = "x"), class = "vofi_error")
})

test_that("vofi_warn und vofi_inform", {
  expect_warning(vofi_warn("core.vocab_alias", code = "a", canonical = "b", path = "p",
                           .class = "vofi_warning_input"),
                 class = "vofi_warning_input")
  w <- tryCatch(vofi_warn("core.vocab_alias", code = "a", canonical = "b", path = "p"),
                warning = identity)
  expect_s3_class(w, c("vofi_warning", "warning", "condition"), exact = TRUE)
  local_vofi_options(vofi.verbose = TRUE)
  expect_message(vofi_inform("core.index_before_assumed", path = "market.x"),
                 class = "vofi_message")
  m <- tryCatch(vofi_inform("core.index_before_assumed", path = "q"), message = identity)
  expect_match(conditionMessage(m), "\n$")
  local_vofi_options(vofi.verbose = FALSE)
  expect_silent(vofi_inform("core.index_before_assumed", path = "market.x"))
})

test_that("nur zul\u00e4ssige Bedingungsklassen", {
  expect_error(vofi_abort("core.file_missing", path = "x", .class = "vofi_error_foo"),
               class = "vofi_error_contract")
  expect_error(vofi_warn("core.file_missing", path = "x", .class = "vofi_error_input"),
               class = "vofi_error_contract")
  expect_error(vofi_inform("core.file_missing", path = "x", .class = "vofi_warning_input"),
               class = "vofi_error_contract")
  tab <- vocab("conditions")
  expect_setequal(tab$code, c(
    "vofi_error_input", "vofi_error_validation", "vofi_error_registry", "vofi_error_contract",
    "vofi_error_engine", "vofi_error_not_implemented", "vofi_error_label", "vofi_warning_input",
    "vofi_warning_plausibility", "vofi_warning_library_outdated", "vofi_warning_engine",
    "vofi_warning_correlation", "vofi_warning_memory", "vofi_message"))
})

test_that("fehlender Schl\u00fcssel: strikt Fehler, sonst [[key]]", {
  local_vofi_options(vofi.strict_labels = FALSE)
  e <- tryCatch(vofi_abort("core.gibt_es_nicht"), error = identity)
  expect_identical(conditionMessage(e), "[[core.gibt_es_nicht]]")
  local_vofi_options(vofi.strict_labels = TRUE)
  expect_error(vofi_abort("core.gibt_es_nicht"), class = "vofi_error_label")
})
