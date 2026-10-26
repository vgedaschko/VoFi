# Tests für R/utils-path.R (Integrator; Spec 00 Abschnitt 4.4 Nr. 4).

test_that("path_split und path_join", {
  expect_identical(path_split("a.b.c"), c("a", "b", "c"))
  expect_identical(path_split(""), character(0))
  expect_identical(path_split(NULL), character(0))
  expect_identical(path_join("a", "", c("b", "c")), "a.b.c")
  expect_identical(path_join(), "")
})

test_that("path_get, path_exists, path_set, path_remove", {
  x <- list(financing = list(bank = list(rate_pa = 0.03, fees = list(share = 0.01))))
  expect_identical(path_get(x, "financing.bank.rate_pa"), 0.03)
  expect_identical(path_get(x, "financing.bank.fees.share"), 0.01)
  expect_null(path_get(x, "financing.bank.ra"))
  expect_identical(path_get(x, ""), x)
  expect_true(path_exists(x, "financing.bank"))
  expect_false(path_exists(x, "financing.kfw"))
  y <- path_set(x, "financing.kfw.rate_pa", 0.01)
  expect_identical(path_get(y, "financing.kfw.rate_pa"), 0.01)
  y <- path_set(y, "financing.bank.rate_pa", list(kind = "const", value = 0.04))
  expect_identical(path_get(y, "financing.bank.rate_pa")$value, 0.04)
  z <- path_remove(y, "financing.bank.fees")
  expect_false(path_exists(z, "financing.bank.fees"))
  expect_identical(path_remove(z, "gibt.es.nicht"), z)
  expect_identical(path_set(x, "", 1), 1)
  expect_error(path_set(list(a = 1), "a.b", 2), class = "vofi_error_input")
  sp <- structure(list(a = list()), class = "vofi_spec")
  expect_s3_class(path_set(sp, "a.b", 1), "vofi_spec")
  expect_null(path_get(list(ab = 1), "a"))
})

test_that("path_leaves: Wertformen und Sequenzen sind Blätter", {
  x <- list(market = list(inflation = list(series = list(`2027` = 0.02), fill = "locf"),
                          energy_price = list(gas = 0.1, power = 0.3)),
            project = list(pending_reforms = c("a", "b"), empty = list()))
  expect_identical(path_leaves(x),
                   c("market.inflation", "market.energy_price.gas", "market.energy_price.power",
                     "project.pending_reforms"))
  expect_identical(path_leaves(NULL), character(0))
})
