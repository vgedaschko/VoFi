# Tests für R/utils-format.R (Integrator; Spec 00 Abschnitt 2.10).

test_that("deutsches Zahlenformat", {
  expect_identical(fmt_num(1234567.891), "1.234.567,89")
  expect_identical(fmt_num(c(-1234.5, 0, NA)), c("-1.234,50", "0,00", "n. d."))
  expect_identical(fmt_num(-0.001), "0,00")
  expect_identical(fmt_num(Inf), "Inf")
  expect_identical(fmt_num(12.3456, 3), "12,346")
  expect_identical(fmt_int(1234567), "1.234.567")
  expect_identical(fmt_int(5L), "5")
  expect_identical(fmt_pct(0.038), "3,80 %")
  expect_identical(fmt_pct(c(0.051183, NA), 4), c("5,1183 %", "n. d."))
  expect_identical(fmt_eur(1234), "1.234 \u20ac")
  expect_identical(fmt_eur(1234.567, 2), "1.234,57 \u20ac")
  expect_identical(fmt_eur(NA), "n. d.")
  expect_identical(fmt_date(as.Date("2026-10-25")), "25.10.2026")
  expect_identical(fmt_date(c("2027-01-01", NA)), c("01.01.2027", "n. d."))
  expect_identical(fmt_num(numeric(0)), character(0))
})
