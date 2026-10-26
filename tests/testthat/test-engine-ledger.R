# Tests für R/engine-ledger.R (WS-D; Spec 00 Abschnitte 7.3, 7.4, 7.8). Phase-0-Minimalfassung.

test_that("ledger_select, ledger_sum, ledger_long, ledger_subset_sims, ledger_get", {
  res <- vofi_run(vofi_build(example_scenario("oracle_a")))
  led <- res$ledger
  expect_setequal(ledger_select(led, section = "loans", category = "interest"),
                  c("loan_ann_interest", "loan_bul_interest"))
  expect_identical(ledger_select(led, source_id = "ek"), c("ek__in", "ek__out"))
  expect_identical(ledger_select(led, existing_debt = TRUE), character(0))
  expect_identical(ledger_select(led, rv_basis = "method"), character(0))
  expect_equal(ledger_sum(led, section = "loans", category = "interest")[1, ],
               led$values$loan_ann_interest[1, ] + led$values$loan_bul_interest[1, ])
  expect_identical(ledger_sum(led, category = "market_value"), matrix(0, 1, 6))
  lg <- ledger_long(led)
  expect_identical(nrow(lg), nrow(led$rows) * 6L)
  expect_identical(lg$value[lg$key == "net_position"], led$values$net_position[1, ])
  sub <- ledger_subset_sims(led, 1L)
  expect_identical(sub$values, led$values)
  expect_identical(ledger_get(led, "dep_balance"), led$values$dep_balance)
  expect_error(ledger_get(led, "gibt_es_nicht"), class = "vofi_error_engine")
  dup <- led$rows[1, , drop = FALSE]
  expect_error(ledger_add(led, dup, led$values[1]), class = "vofi_error_engine")
  rows <- eng_stock_rows(c("a", "b"), c("Bank", "KfW"))
  expect_identical(rows$key[1:2], c("loan_a_balance", "loan_b_balance"))
  expect_identical(rows$label[2], "Bestand KfW")
  expect_identical(eng_row_order("project", "custom", 2), 1000 * 100 + 10 * 21 + 2 / 1000)
})
