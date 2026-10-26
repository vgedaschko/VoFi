# Tests für R/utils-seed.R (Integrator; Spec 00 Abschnitte 11.3, 11.12).

test_that("stream_hash und stream_seed (exakt nach 11.3)", {
  expect_identical(stream_hash(""), 0)
  expect_identical(stream_hash("a"), 97)
  expect_identical(stream_hash("ab"), (97 * 131 + 98) %% 2147483647)
  h <- 0
  for (code in utf8ToInt("par:huelle_kosten:3")) h <- (h * 131 + code) %% 2147483647
  expect_identical(stream_hash("par:huelle_kosten:3"), h)
  expect_identical(stream_seed(20261025, "x"), (20261025 * 1000003 + 120) %% 2147483647)
  expect_true(stream_seed(2147483646, "zzzzzzzzzzzzzzzzzzzz") < 2147483647)
  expect_error(stream_seed(0, "x"), class = "vofi_error_input")
  expect_error(stream_seed(1.5, "x"), class = "vofi_error_input")
  expect_error(stream_seed(2147483647, "x"), class = "vofi_error_input")
})

test_that("with_stream: reproduzierbar, Nutzerzustand bleibt unver\u00e4ndert", {
  withr::local_seed(42)
  before <- .Random.seed
  kind_before <- RNGkind()
  a <- with_stream(20261025, "par:k:1", runif(3))
  b <- with_stream(20261025, "par:k:1", runif(3))
  c2 <- with_stream(20261025, "par:k:2", runif(3))
  expect_identical(a, b)
  expect_false(identical(a, c2))
  expect_identical(.Random.seed, before)
  expect_identical(RNGkind(), kind_before)
  set.seed(stream_seed(20261025, "par:k:1"), kind = "Mersenne-Twister",
           normal.kind = "Inversion", sample.kind = "Rejection")
  expect_identical(runif(3), a)
})

test_that("with_stream: auch ohne vorhandenen Seed und im Fehlerfall", {
  withr::local_preserve_seed()
  if (exists(".Random.seed", envir = globalenv())) rm(".Random.seed", envir = globalenv())
  x <- with_stream(1, "a", runif(1))
  expect_false(exists(".Random.seed", envir = globalenv()))
  set.seed(1)
  before <- .Random.seed
  expect_error(with_stream(1, "a", stop("x")))
  expect_identical(.Random.seed, before)
  old <- suppressWarnings(RNGkind(sample.kind = "Rounding"))
  on.exit(suppressWarnings(RNGkind(old[1], old[2], old[3])), add = TRUE)
  suppressWarnings(with_stream(1, "a", runif(1)))
  expect_identical(RNGkind()[3], "Rounding")
})
