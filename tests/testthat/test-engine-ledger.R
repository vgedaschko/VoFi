# Tests für R/engine-ledger.R (WS-D; Spec 00 Abschnitte 7.3, 7.4, 7.7, 7.8, 10.5).

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

test_that("eng_bind_rows: schnelles Zusammenfügen mit kompakten Zeilennamen und extra", {
  a <- new_ledger_rows(c("a", "b"), "project", "custom")
  b <- new_ledger_rows("c", "memo", "tax_report", cash = FALSE, kind = "memo")
  out <- eng_bind_rows(list(a, NULL, b))
  expect_identical(out$key, c("a", "b", "c"))
  expect_identical(attr(out, "row.names"), 1:3)
  expect_s3_class(out$extra, "AsIs")
  expect_length(out$extra, 3L)
  ref <- rbind(a, b)
  rownames(ref) <- NULL
  for (cn in setdiff(names(ref), "extra")) expect_identical(out[[cn]], ref[[cn]], info = cn)
  expect_identical(nrow(eng_bind_rows(list())), 0L)
  expect_identical(eng_bind_rows(list(a))$key, c("a", "b"))
})

test_that("eng_loan_rows: Tags des Bausteins auf allen Kreditzeilen, Labels, Ordnung", {
  model <- wsd_skeleton()
  k <- model$instruments$bank
  comp <- k$spec
  comp$measure_id <- "m1"
  comp$asset_id <- "geb"
  rows <- eng_loan_rows("bank", 1L, comp, k$def)
  expect_identical(nrow(rows), 9L)
  expect_true(all(rows$measure_id == "m1"))
  expect_true(all(rows$asset_id == "geb"))
  expect_true(all(rows$source_id == "bank"))
  expect_identical(order(rows$order), 1:9)
  expect_true(all(nzchar(rows$label)))
  # Merkzeile repayment_grant (7.6, R-99, 10.10 Nr. 7): ohne Tilgungszuschuss nicht steuerrelevant,
  # mit Tilgungszuschuss subsidy_repayment_grant; die übrigen Zeilen nach dem Vokabular
  tc <- function(r) r$tax_category[r$category == "repayment_grant"]
  expect_identical(tc(rows), "not_applicable")
  expect_identical(rows$tax_category[rows$category == "interest"], "interest_expense")
  comp$repayment_grant <- list(amount_eur = 1000, date = as.Date("2028-01-01"))
  expect_identical(tc(eng_loan_rows("bank", 1L, comp, k$def)), "subsidy_repayment_grant")
  comp$repayment_grant <- list(share = 0.1)
  expect_identical(tc(eng_loan_rows("bank", 1L, comp, k$def)), "subsidy_repayment_grant")
  comp$existing <- TRUE
  expect_identical(tc(eng_loan_rows("bank", 1L, comp, k$def)), "not_applicable")
})

test_that("eng_model_rows: modellfeste Zeilen, Alternative mit opp-Zeilen", {
  model <- wsd_skeleton()
  rm <- eng_model_rows(model$instruments)
  expect_identical(rm$ids, "bank")
  expect_false("balance_check" %in% rm$engine$key)
  expect_identical(rm$check$key, "balance_check")
  expect_true("loan_bank_balance" %in% rm$stocks$key)
  expect_null(rm$opp_rows)
  ro <- eng_model_rows(list(), opp = TRUE)
  expect_identical(ro$opp_rows$call_in$category, "equity_in")
  expect_identical(ro$opp_rows$sale_in$category, "equity_in")
  expect_identical(ro$opp_rows$sale_out$category, "equity_out")
  expect_identical(ro$opp_rows$sale_out$key, "opp_in_kind_sale")
})

test_that("eng_tax_report_rows: Merkzeilen tax_report_<name> mit Label oder Namen", {
  m <- new_tax_module("test_x")
  rows <- eng_tax_report_rows(m, c("a", "b"))
  expect_identical(rows$key, c("tax_report_a", "tax_report_b"))
  expect_true(all(rows$section == "memo" & rows$category == "tax_report"))
  expect_false(any(rows$cash))
  expect_identical(rows$label, c("a", "b"))
  expect_identical(rows$label_key, c("types.tax.test_x.report.a", "types.tax.test_x.report.b"))
  expect_null(eng_tax_report_rows(m, character(0)))
})
