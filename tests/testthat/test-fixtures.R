# Tests der gemeinsamen Testfixtures (Integrator; Spec 00 Abschnitt 15.1).

test_that("example_result: vertragsgem\u00e4\u00df, Orakel (a)", {
  r <- example_result()
  expect_s3_class(r, "vofi_result")
  expect_s3_class(r$ledger, "vofi_ledger")
  expect_identical(r$ledger$n, 1L)
  expect_identical(r$ledger$T, 5L)
  expect_vofi_invariants(r)
  expect_equal(r$kpis$terminal_value, 38504.63, tolerance = 1e-7)
  expect_equal(r$kpis$terminal_value_opp, 34778.22, tolerance = 1e-7)
  expect_equal(r$kpis$delta_terminal_value, 3726.41, tolerance = 1e-6)
  expect_equal(r$ledger$values$net_position[1, 6], r$kpis$terminal_value)
  expect_equal(r$opportunity$EW, r$kpis$terminal_value_opp)
  expect_identical(names(r$kpi_na), names(r$kpis))
  na_cols <- names(r$kpis)[is.na(unlist(r$kpis))]
  expect_true(all(!is.na(unlist(r$kpi_na[na_cols]))))
  expect_true(all(unlist(r$kpi_na[!is.na(unlist(r$kpi_na))]) %in% vocab_codes("na_reasons")))
  expect_identical(r$meta$contract_version, VOFI_CONTRACT_VERSION)
  expect_true(all(c("scenario_set", "seed") %in% names(r$meta)))
  inv_opp <- helper_invariants(r$opportunity$ledger)
  expect_true(all(inv_opp$ok))
  expect_identical(r$ledger$rows$key[r$ledger$rows$section == "stocks"],
                   c("loan_ann_balance", "loan_bul_balance", "od_balance", "odp_balance",
                     "dep_balance", "tax_liability", "net_position"))
})

test_that("example_result hat dieselbe Struktur wie das Ergebnis der Engine (Orakel (a))", {
  fx <- example_result()
  en <- vofi_run(vofi_build(example_scenario("oracle_a")))
  cols <- setdiff(names(en$ledger$rows), "extra")
  expect_identical(fx$ledger$rows[, cols], en$ledger$rows[, cols])
  expect_identical(fx$opportunity$ledger$rows[, cols], en$opportunity$ledger$rows[, cols])
  expect_false(anyNA(fx$ledger$rows$label_key))
  expect_false(anyNA(fx$ledger$rows$label))
  for (k in en$ledger$rows$key) {
    expect_equal(fx$ledger$values[[k]], en$ledger$values[[k]], tolerance = 1e-9, info = k)
  }
  for (k in en$opportunity$ledger$rows$key) {
    expect_equal(fx$opportunity$ledger$values[[k]], en$opportunity$ledger$values[[k]],
                 tolerance = 1e-9, info = k)
  }
  expect_identical(names(fx), names(en))
  expect_identical(names(fx$meta), names(en$meta))
  expect_identical(fx$meta$defaults, en$meta$defaults)
  expect_identical(names(fx$flags), names(en$flags))
  expect_identical(fx$checks$invariant, en$checks$invariant)
  expect_true(all(names(en$kpis) %in% names(fx$kpis)))
  for (k in names(en$kpis)) expect_equal(fx$kpis[[k]], en$kpis[[k]], tolerance = 1e-9, info = k)
})

test_that("example_core: vertragsgem\u00e4\u00df", {
  core <- example_core()
  expect_identical(core$n, 7L)
  expect_true(all(helper_invariants(core$ledger)$ok))
  expect_identical(names(core$stocks), c("G", "KK", "KKP", "B", "BS", "tax_liability"))
  expect_identical(names(core$terminal_ex_rv), c("G", "KK", "KKP", "B_total", "BS", "rv", "gap"))
})

test_that("example_mc_result und example_comparison", {
  mc <- example_mc_result(200L)
  expect_s3_class(mc, "vofi_mc_result")
  expect_identical(nrow(mc$kpis), 200L)
  expect_identical(names(mc$stats),
                   c("kpi", "mean", "sd", "se", "se_df", "q05", "q10", "q25", "q50", "q75",
                     "q90", "q95", "p_neg", "p_neg_se", "es05", "expected_loss", "na_share",
                     "n_valid", "deterministic", "converged"))
  expect_false(any(mc$stats$converged))
  expect_s3_class(mc$model, "vofi_model")
  expect_true(isTRUE(helper_converged(100, 0.1, 0.001, 50L)))
  expect_false(helper_converged(100, 0.1, 0.001, 5L))
  expect_identical(dim(mc$bands$net_position), c(6L, 6L))
  expect_identical(names(mc$run_index), c("p05", "p50", "p95"))
  cmp <- example_comparison()
  expect_s3_class(cmp, "vofi_comparison")
  expect_identical(cmp$baseline, "base")
  expect_equal(unname(cmp$differences$delta_vs_reference[1, "a"]), 2000)
  expect_s3_class(cmp$comparability, "vofi_validation")
})

test_that("example_scenario liest die Fixtures (sobald vofi_read_scenario existiert)", {
  expect_true(file.exists(testthat::test_path("fixtures", "scenarios", "skeleton.yaml")))
  expect_true(file.exists(testthat::test_path("fixtures", "scenarios", "oracle_a.yaml")))
  y <- utl_read_yaml(testthat::test_path("fixtures", "scenarios", "oracle_a.yaml"))
  expect_identical(y$financing$ann$type, "annuity_loan")
  expect_identical(y$accounts$overdraft_limit_eur, Inf)
  s <- example_scenario("skeleton")
  expect_s3_class(s, "vofi_scenario")
})
