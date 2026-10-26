# Tests für R/zzz.R und R/vofi-package.R (Integrator; Spec 00 Abschnitte 2.12, 5.5).

test_that(".onLoad: Kataloge geladen, Optionen gesetzt", {
  expect_true(length(lbl_keys()) > 300L)
  expect_true(length(vocab_state$data) >= 10L)
  expect_identical(getOption("vofi.chunk_size"), 2000L)
  expect_identical(getOption("vofi.max_memory_gb"), 2)
  expect_identical(getOption("vofi.language"), "de")
  expect_identical(getOption("vofi.library_paths"), character())
  expect_true(is.logical(getOption("vofi.verbose")))
  expect_true(is.logical(getOption("vofi.strict_labels")))
  expect_true(is.list(reg_state$types))
  expect_setequal(names(reg_state$types), reg_kinds())
})

test_that(".onLoad \u00fcberschreibt gesetzte Optionen nicht", {
  local_vofi_options(vofi.chunk_size = 400L)
  ns <- asNamespace("vofi")
  old_types <- reg_state$types
  withr::defer(reg_state$types <- old_types)
  ns$.onLoad(NULL, "vofi")
  expect_identical(getOption("vofi.chunk_size"), 400L)
})
