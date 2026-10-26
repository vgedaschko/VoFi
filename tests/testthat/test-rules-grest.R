# Tests der Rechtsregel grest (WS-E-INV; Spec 00 5.3, 7.11; Spec 01 Teil A 4.8).

test_that("Vertrag und Registrierung der Version ab 2025-07-01", {
  expect_type_contract("grest@2025-07-01", "rule")
  d <- reg_get("rule", "grest@2025-07-01")
  expect_identical(d$rule_name, "grest")
  expect_identical(d$returns, "sim")
  expect_equal(d$valid_from, as.Date("2025-07-01"))
  expect_null(d$valid_to)
  expect_null(d$reform)
  expect_true(lbl_has("types.rule.grest.label"))
})

test_that("Landessatz, Freigrenze und Vorrang des ausdrücklichen Satzes (vektorisiert)", {
  pl <- wsei_grest_payload()
  expect_equal(rule_grest_fun(c(840000, 2400, 2500, 2600), "NW", NA_real_, pl),
               c(54600, 0, 0, 169))
  expect_equal(rule_grest_fun(c(1200000, 1000000), "BY", c(NA, 0.05), pl), c(42000, 50000))
  expect_equal(rule_grest_fun(1000, NA_character_, 0.05, list()), 0)
  expect_equal(rule_grest_fun(10000, NA_character_, 0.05, list()), 500)
  pl2 <- pl
  pl2$exemption_threshold_eur <- 5000
  expect_equal(rule_grest_fun(4000, "NW", NA_real_, pl2), 0)
  for (s in names(pl$rates)) {
    expect_equal(rule_grest_fun(1e6, s, NA_real_, pl), 1e6 * pl$rates[[s]])
  }
})

test_that("Fehlender Satz bei fälliger Steuer ist ein Vertragsfehler", {
  pl <- wsei_grest_payload()
  expect_error(rule_grest_fun(1e6, NA_character_, NA_real_, pl), class = "vofi_error_contract")
  expect_error(rule_grest_fun(1e6, "XX", NA_real_, pl), class = "vofi_error_contract")
  expect_equal(rule_grest_fun(1000, NA_character_, NA_real_, pl), 0)
  expect_type(msg("types.rule.grest.msg.rate_missing", state = "XX"), "character")
})

test_that("Versionswahl über project.legal_state", {
  g <- make_grid()
  ctx <- make_ctx(1L, grid = g, legal_state = as.Date("2026-10-25"))
  f <- ctx$rule("grest")
  expect_equal(f(basis_eur = 1e6, federal_state = "BY", rate = NA_real_,
                 P = wsei_grest_payload()), 35000)
  old <- make_ctx(1L, grid = g, legal_state = as.Date("2025-06-30"))
  expect_error(old$rule("grest"), class = "vofi_error_registry")
})
