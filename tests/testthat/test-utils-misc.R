# Tests für R/utils-misc.R (Integrator).

test_that("%||%, utl_sort, utl_suggest", {
  expect_identical(NULL %||% 1, 1)
  expect_identical(2 %||% 1, 2)
  expect_identical(utl_sort(c("b", "B", "a", "_x")), c("B", "_x", "a", "b"))
  expect_identical(utl_sort(character(0)), character(0))
  expect_identical(utl_suggest("wu_privatt", c("wu_privat", "selbstnutzer")), "wu_privat")
  expect_null(utl_suggest("xyzxyzxyz", c("a", "b")))
  expect_match(utl_suggest_text("annuity_lon", c("annuity_loan")), "annuity_loan")
  expect_identical(utl_suggest_text("qqqqqq", c("a")), "")
})

test_that("ids, Pr\u00fcfungen, Datumswerte", {
  expect_identical(utl_is_id(c("bank", "kfw_261", "Bank", "a__b", "1a", strrep("a", 41))),
                   c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE))
  expect_true(utl_is_whole(3))
  expect_false(utl_is_whole(3.5))
  expect_false(utl_is_whole(NA_real_))
  expect_identical(utl_check_whole(4, "x", min = 1), 4L)
  expect_error(utl_check_whole(0, "x", min = 1), class = "vofi_error_input")
  expect_identical(utl_as_date("2027-01-01"), as.Date("2027-01-01"))
  expect_null(utl_as_date(NULL, allow_null = TRUE))
  expect_error(utl_as_date("01.01.2027"), class = "vofi_error_input")
  expect_error(utl_as_date(NULL), class = "vofi_error_input")
  expect_identical(utl_match_arg(c("a", "b"), c("a", "b")), "a")
  expect_identical(utl_match_arg("b", c("a", "b")), "b")
  expect_error(utl_match_arg("c", c("a", "b")), class = "vofi_error_input")
  expect_identical(utl_fill_defaults(list(a = 1), list(a = 2, b = NULL))$a, 1)
  expect_true("b" %in% names(utl_fill_defaults(list(a = 1), list(b = NULL))))
})

test_that("utl_read_yaml: Kataloge UTF-8, yes/no bleiben Text", {
  f <- withr::local_tempfile(fileext = ".yaml")
  writeLines(c("yes: a", "on: b", "x: true", "n: 2026-10-25", "k: [1, 2]"), f)
  y <- utl_read_yaml(f)
  expect_identical(names(y), c("yes", "on", "x", "n", "k"))
  expect_identical(y$x, TRUE)
  expect_identical(y$n, "2026-10-25")
  expect_error(utl_read_yaml(file.path(tempdir(), "fehlt.yaml")), class = "vofi_error_input")
  writeLines("a: [1, 2", f)
  expect_error(utl_read_yaml(f), class = "vofi_error_input")
  writeLines("", f)
  expect_identical(utl_read_yaml(f), list())
})

test_that("utl_require meldet fehlende Suggests-Pakete", {
  expect_true(utl_require("stats", "f"))
  expect_error(utl_require("keinPaketMitDiesemNamen", "vofi_plot"), class = "vofi_error_input")
})
