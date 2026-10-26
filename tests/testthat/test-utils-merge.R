# Tests für R/utils-merge.R (Integrator; Spec 00 Abschnitt 4.7).

test_that("deep_merge: Maps rekursiv, Skalare und Sequenzen ersetzen", {
  base <- list(a = 1, b = list(c = 2, d = 3), s = list(1, 2, 3))
  ov <- list(b = list(c = 20), s = list(9), e = "neu")
  m <- deep_merge(base, ov)
  expect_identical(m$a, 1)
  expect_identical(m$b, list(c = 20, d = 3))
  expect_identical(m$s, list(9))
  expect_identical(m$e, "neu")
  expect_identical(deep_merge(1, 2), 2)
  expect_identical(deep_merge(list(a = 1), "x"), "x")
})

test_that("deep_merge: ~ löscht, .replace ersetzt, Wertformen ersetzen ganz", {
  base <- list(a = 1, b = list(c = 2, d = 3))
  ov <- list(a = NULL)
  expect_identical(names(deep_merge(base, ov)), "b")
  rep <- deep_merge(base, list(b = list(.replace = TRUE, x = 1)))
  expect_identical(rep$b, list(x = 1))
  keep <- deep_merge(base, list(b = list(.replace = FALSE, x = 1)))
  expect_identical(keep$b, list(c = 2, d = 3, x = 1))
  vf <- deep_merge(list(r = list(series = list(`2027` = 0.02), fill = "locf")),
                   list(r = list(ref = "market.inflation")))
  expect_identical(vf$r, list(ref = "market.inflation"))
  part <- deep_merge(list(r = list(series = list(`2027` = 0.02), fill = "locf")),
                     list(r = list(fill = "zero")))
  expect_identical(part$r$fill, "zero")
  expect_identical(part$r$series, list(`2027` = 0.02))
  credit <- deep_merge(list(bank = list(type = "annuity_loan", start = 2027, rate_pa = 0.03)),
                       list(bank = list(start = 2028)))
  expect_identical(credit$bank$start, 2028)
  expect_identical(credit$bank$rate_pa, 0.03)
})

test_that("is_value_form: strukturell genau eine Wertform, schemagestützt mit kind_of", {
  expect_true(is_value_form(list(ref = "market.x", scale = 2)))
  expect_true(is_value_form(list(expr = "a.b * 2")))
  expect_true(is_value_form(list(series = list(`2027` = 1), fill = "locf")))
  expect_true(is_value_form(list(years = c(2026, 2030), values = c(1, 2))))
  expect_true(is_value_form(list(schedule = list(`2027-01-01` = 1))))
  expect_true(is_value_form(list(start = 7.2, growth = 0.02)))
  expect_true(is_value_form(list(value = 14, per = "m2_living_area")))
  expect_true(is_value_form(list(dist = "pert", min = 1, mode = 2, max = 3)))
  expect_true(is_value_form(list(from = "prices/co2", use = "mittel")))
  expect_false(is_value_form(list(start = 2028)))
  expect_false(is_value_form(list(ref = "x", foo = 1)))
  expect_false(is_value_form(list(fill = "zero")))
  expect_false(is_value_form(list()))
  expect_false(is_value_form(0.039))
  expect_false(is_value_form(list(from = "a", dist = "b")))
  kind_of <- function(path) if (path == "financing.bank.fees") "map" else "value"
  expect_false(is_value_form(list(value = 1, per = "total"), "financing.bank.fees", kind_of))
  expect_true(is_value_form(list(value = 1, per = "total"), "x", kind_of))
  expect_identical(utl_value_form_kind(list(ref = "a")), "ref")
  expect_true(is_map(list()))
  expect_false(is_map(list(1, 2)))
  expect_false(is_map(data.frame(a = 1)))
})
