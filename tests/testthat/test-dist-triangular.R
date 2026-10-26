# Tests für R/dist-triangular.R (WS-C; Spec 01 Teil C 1.4.6).

tri <- function(a, c0, b) list(min = a, mode = c0, max = b)

test_that("triangular: Prüffälle d1-d4", {
  d <- wsc_dist("triangular")
  m1 <- d$moments(tri(0, 3, 12))
  expect_equal(m1$mean, 5)
  expect_equal(m1$var, 6.5)
  p2 <- tri(2.6, 2.9, 3.3)
  expect_spec(d$moments(p2)$mean, "2.9333333")
  expect_spec(sqrt(d$moments(p2)$var), "0.14337209")
  expect_spec(d$quantile(c(0.1, 0.5, 0.9), p2), c("2.7449138", "2.9258343", "3.132668"))
  p3 <- tri(60, 90, 200)
  expect_spec(d$moments(p3)$mean, "116.66667")
  expect_spec(sqrt(d$moments(p3)$var), "30.09245")
  expect_spec(d$quantile(c(0.1, 0.5, 0.9), p3), c("80.493902", "112.25036", "160.75717"))
  p4 <- tri(80, 150, 300)
  expect_spec(d$moments(p4)$mean, "176.66667")
  expect_spec(sqrt(d$moments(p4)$var), "45.886333")
})

test_that("triangular: Knick bei F_c, Ränder, Modus am Rand, Entartung", {
  d <- wsc_dist("triangular")
  p <- tri(0, 3, 12)
  expect_equal(d$quantile(0.25, p), 3, tolerance = 1e-14)
  expect_identical(d$quantile(c(0, 1), p), c(0, 12))
  expect_equal(d$quantile(0.5, tri(0, 0, 1)), 1 - sqrt(0.5), tolerance = 1e-14)
  expect_equal(d$quantile(0.5, tri(0, 1, 1)), sqrt(0.5), tolerance = 1e-14)
  expect_identical(d$quantile(c(0, 0.5, 1), tri(4, 4, 4)), c(4, 4, 4))
  expect_identical(d$point(p, "mode"), 3)
  expect_equal(d$point(p, "median"), d$quantile(0.5, p))
  u <- seq(0, 1, by = 0.001)
  expect_true(all(diff(d$quantile(u, p)) >= 0))
})

test_that("triangular: Validierung (Prüffall d5)", {
  d <- wsc_dist("triangular")
  expect_length(d$validate(tri(0, 4, 3)), 1L)
  expect_length(d$validate(list(min = 0, max = 3)), 1L)
  expect_identical(d$validate(tri(1, 1, 1)), character(0))
  expect_type_contract("triangular", "distribution")
})
