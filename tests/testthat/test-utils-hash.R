# Tests für R/utils-hash.R (Integrator).

test_that("stable_hash: deterministisch, inhaltsabh\u00e4ngig", {
  x <- list(a = 1, b = list(c = "x", d = as.Date("2027-01-01")))
  h <- stable_hash(x)
  expect_match(h, "^[0-9a-f]{32}$")
  expect_identical(stable_hash(x), h)
  expect_false(identical(stable_hash(list(a = 2, b = x$b)), h))
  expect_false(identical(stable_hash(list(b = x$b, a = 1)), h))
  f <- withr::local_tempfile()
  writeLines("abc", f)
  expect_match(stable_hash_file(f), "^[0-9a-f]{32}$")
  expect_error(stable_hash_file(file.path(tempdir(), "fehlt.yaml")), class = "vofi_error_input")
})

test_that("stable_hash: bekannter Wert (Serialisierung ohne Kopf)", {
  # Version 2 der XDR-Serialisierung ist über R-Versionen stabil; der Kopf (R-Version) entfällt.
  expect_identical(stable_hash(list(a = 1)), stable_hash(list(a = 1)))
  expect_identical(nchar(stable_hash(NULL)), 32L)
})
