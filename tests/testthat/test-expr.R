# Tests für R/expr.R (WS-B; Spec 00 Abschnitt 4.5 Regel 5, R-91).

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

test_that("Meldungsschlüssel, Positionen und Vorschläge", {
  key <- function(expr) wsb_cond_key(expr)
  msg_of <- function(expr) tryCatch({
    force(expr)
    ""
  }, error = conditionMessage)
  expect_identical(key(expr_parse("   ")), "validation.expr.empty")
  expect_identical(key(expr_parse(NULL)), "validation.expr.empty")
  expect_identical(key(expr_parse(c("a.b", "c.d"))), "validation.expr.empty")
  expect_identical(key(expr_parse("a.v +")), "validation.expr.syntax")
  expect_match(msg_of(expr_parse("a.v +")), lbl("validation.expr.position", line = 1L,
                                                col = 6L), fixed = TRUE)
  expect_match(msg_of(expr_parse("a.v +\n (a.v")), "Zeile 2", fixed = TRUE)
  expect_identical(key(expr_parse("a.v\na.v")), "validation.expr.multiple")
  # Position des Tokens: zweite Zeile, Spalte 2
  m <- msg_of(expr_parse("a.v +\n max(a.v)"))
  expect_match(m, lbl("validation.expr.position", line = 2L, col = 2L), fixed = TRUE)
  expect_match(m, lbl("core.did_you_mean", suggestion = "pmax"), fixed = TRUE)
  expect_match(msg_of(expr_parse("a.v + min(a.v, 1)")), "pmin", fixed = TRUE)
  expect_false(grepl(lbl("core.did_you_mean", suggestion = ""),
                     msg_of(expr_parse("mean(a.v)")), fixed = TRUE))
  expect_identical(key(expr_parse("a.v + b")), "validation.expr.symbol")
  expect_identical(key(expr_parse("a.v + .b")), "validation.expr.symbol")
  expect_identical(key(expr_parse("a.v + b.")), "validation.expr.symbol")
  expect_identical(key(expr_parse("a.v + NA")), "validation.expr.literal")
  expect_identical(key(expr_parse("a.v[1]")), "validation.expr.function")
  expect_identical(key(expr_parse("function(x) x")), "validation.expr.function")
  expect_identical(key(expr_parse("a.v || a.v")), "validation.expr.function")
})

test_that("Benannte Argumente, Stelligkeit und deterministische Operanden", {
  vals <- list(a.v = c(1.234, 2.345, 3.456), p.codes = c("x", "y"))
  res <- function(p) vals[[p]]
  ev <- function(txt) expr_eval(expr_parse(txt), res, 3L, 3L)
  key <- function(txt) wsb_cond_key(ev(txt))
  expect_identical(ev("round(a.v, digits = 1)"), c(1.2, 2.3, 3.5))
  expect_equal(ev("log(a.v * 0 + 100, base = 10)"), c(2, 2, 2))
  expect_identical(key("round(a.v, n = 1)"), "validation.expr.named_arg")
  expect_identical(key("pmax(a.v, na.rm = TRUE)"), "validation.expr.named_arg")
  expect_identical(key("ifelse(a.v > 1, 1)"), "validation.expr.arity")
  expect_identical(key("abs()"), "validation.expr.arity")
  expect_identical(key("round(a.v, a.v)"), "validation.expr.not_deterministic")
  expect_identical(key("c(a.v + 1)"), "validation.expr.not_deterministic")
  expect_identical(key("c(a.v)"), "validation.expr.not_deterministic")
  expect_identical(key("a.v %in% a.v"), "validation.expr.not_deterministic")
  expect_identical(key("a.v %in% pmax(1, 2)"), "validation.expr.not_deterministic")
  expect_identical(ev("'x' %in% p.codes"), c(1, 1, 1))
  expect_identical(ev("'z' %in% c(p.codes, 'w')"), c(0, 0, 0))
  expect_identical(key("a.v %in% p.codes"), "validation.expr.code_operand")
  expect_identical(ev("sqrt(a.v * 0 - 1) * 0 + is.na(sqrt(a.v * 0 - 1))"), c(NaN, NaN, NaN))
  expect_identical(ev("floor(a.v) + ceiling(a.v) + (-a.v + a.v) + +1"), c(4, 6, 8))
  expect_identical(ev("a.v %% 1 >= 0"), c(1, 1, 1))
  expect_identical(ev("2 ^ 3 / 4"), c(2, 2, 2))
  expect_identical(ev("exp(0) + abs(-1)"), c(2, 2, 2))
  expect_identical(key("ifelse(a.v > 2, log(0), 1)"), "validation.expr.ifelse_nonfinite")
  expect_identical(key("1 + a.fehlt"), "validation.expr.path_missing")
  dt <- function(p) as.Date("2027-01-01")
  expect_identical(wsb_cond_key(expr_eval(expr_parse("p.d + 1"), dt, 1L, 1L)),
                   "validation.expr.code_operand")
  lst <- function(p) list(1)
  expect_identical(wsb_cond_key(expr_eval(expr_parse("p.l + 1"), lst, 1L, 1L)),
                   "validation.expr.not_numeric_symbol")
})

test_that("Pfadsymbole aus Text, Knoten und Objekt", {
  ast <- expr_parse("ifelse('a' %in% p.codes, x.y * 2, x.y) + x.z")
  expect_identical(expr_symbols(ast), c("p.codes", "x.y", "x.z"))
  expect_identical(expr_symbols("x.y + 1"), "x.y")
  expect_identical(expr_symbols(list(kind = "expr", text = "x.y + x.y")), "x.y")
  expect_identical(expr_symbols(list(kind = "expr", text = "1", ast = ast)),
                   c("p.codes", "x.y", "x.z"))
  expect_identical(expr_symbols("1 + 2"), character(0))
  expect_identical(expr_parse(ast), ast)
})

test_that("Batch-Invarianz: Lauf i hängt nur von den Werten des Laufs i ab", {
  big_t <- 4L
  s3 <- list(a.v = c(1.5, -2, 4), a.p = matrix(seq_len(15) / 3, 3, big_t + 1L), a.s = 0.5,
             p.code = c("x", "y", "x"))
  txt <- paste("ifelse(a.v > 0, pmax(a.p * a.v, a.s), round(a.p, 1)) +",
               "(p.code == 'x') * floor(a.v) + (a.v %in% c(4, 1.5))")
  r3 <- expr_eval(expr_parse(txt), function(p) s3[[p]], 3L, big_t)
  expect_identical(dim(r3), c(3L, big_t + 1L))
  for (i in 1:3) {
    s1 <- list(a.v = s3$a.v[i], a.p = s3$a.p[i, , drop = FALSE], a.s = s3$a.s,
               p.code = s3$p.code[i])
    r1 <- expr_eval(expr_parse(txt), function(p) s1[[p]], 1L, big_t)
    expect_identical(r1, r3[i, , drop = FALSE])
  }
  # Formfehler der Auflösung sind Vertragsfehler
  expect_error(expr_eval(expr_parse("a.v + 1"), function(p) c(1, 2), 3L, 1L),
               class = "vofi_error_contract")
  expect_error(expr_eval(expr_parse("a.v + 1"), function(p) matrix(1, 3, 3), 3L, 1L),
               class = "vofi_error_contract")
})
