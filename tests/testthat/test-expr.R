# Tests für R/expr.R (WS-B; Spec 00 Abschnitt 4.5 Regel 5). Phase-0-Minimalfassung.

test_that("Whitelist und Pfadsymbole", {
  ast <- expr_parse("pmax(building.living_area_m2 * 150, 0) + market.x")
  expect_s3_class(ast, "vofi_expr")
  expect_setequal(expr_symbols(ast), c("building.living_area_m2", "market.x"))
  expect_error(expr_parse("max(market.x, 1)"), class = "vofi_error_input")
  expect_error(expr_parse("market.x && market.y"), class = "vofi_error_input")
  expect_error(expr_parse("system('ls')"), class = "vofi_error_input")
  expect_error(expr_parse("x + 1"), class = "vofi_error_input")
  expect_error(expr_parse("1 +"), class = "vofi_error_input")
  expect_error(expr_parse("ifelse(market.x > 1, 2)"), class = "vofi_error_input")
})

test_that("Formregel: Skalar -> n-Vektor, Pfad -> n x (T+1)", {
  vals <- list(a.s = 2, a.v = c(1, 2, 3), a.p = matrix(1:12, 3, 4))
  res <- function(p) vals[[p]]
  expect_identical(expr_eval(expr_parse("a.s * 3"), res, 3L, 3L), c(6, 6, 6))
  expect_identical(expr_eval(expr_parse("a.v + a.s"), res, 3L, 3L), c(3, 4, 5))
  m <- expr_eval(expr_parse("a.p - a.v"), res, 3L, 3L)
  expect_identical(dim(m), c(3L, 4L))
  expect_identical(m[, 2], c(3, 3, 3))
  expect_identical(expr_eval(expr_parse("ifelse(a.v > 1, 10, 0)"), res, 3L, 3L), c(0, 10, 10))
  expect_identical(expr_eval(expr_parse("(a.v >= 2) & !(a.v == 3)"), res, 3L, 3L), c(0, 1, 0))
  expect_identical(expr_eval(expr_parse("pmin(a.v, a.s)"), res, 3L, 3L), c(1, 2, 2))
  expect_error(expr_eval(expr_parse("a.fehlt + 1"), res, 3L, 3L), class = "vofi_error_input")
})

test_that("Codes und Wahrheitswerte nur in Vergleich und Logik (R-91)", {
  vals <- list(a.v = c(1, 2, 3), p.reforms = c("stufe_2045", "x"), p.code = "wu_kapges",
               p.flag = TRUE)
  res <- function(p) vals[[p]]
  ev <- function(txt) expr_eval(expr_parse(txt), res, 3L, 3L)
  expect_identical(ev("ifelse('stufe_2045' %in% p.reforms, 1, 0)"), c(1, 1, 1))
  expect_identical(ev("p.code == 'wu_kapges'"), c(1, 1, 1))
  expect_identical(ev("p.code != 'wu_kapges'"), c(0, 0, 0))
  expect_identical(ev("p.flag & (a.v > 1)"), c(0, 1, 1))
  expect_identical(ev("!p.flag | a.v == 3"), c(0, 0, 1))
  expect_identical(ev("(p.flag) == TRUE"), c(1, 1, 1))
  expect_error(ev("p.flag + 1"), class = "vofi_error_input")
  expect_error(ev("p.code > 'a'"), class = "vofi_error_input")
  expect_error(ev("p.code & p.flag"), class = "vofi_error_input")
  expect_error(ev("ifelse(p.flag, 1, 0)"), class = "vofi_error_input")
  expect_error(ev("p.code"), class = "vofi_error_input")
  expect_error(ev("p.flag"), class = "vofi_error_input")
})

test_that("%in% mit zeitabhaengigem Operanden behaelt die Form n x (T+1)", {
  m <- matrix(1:6, 2, 3)
  v <- expr_eval(expr_parse("a.x %in% c(2, 5)"), resolve = function(p) m, n = 2L, T = 2L)
  expect_identical(dim(v), c(2L, 3L))
  expect_equal(v, matrix(c(0, 1, 0, 0, 1, 0), 2, 3))
})
