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

test_that("eng_fold_sum: bitgleich zur Linksfaltung, auch über Blöcke von 100 Summanden", {
  set.seed(11)
  mk <- function() {
    m <- matrix(stats::rnorm(12) * 10^sample(-8:8, 12, TRUE), 3L, 4L)
    m[sample(12, 2)] <- c(0, -0)
    m
  }
  for (k in c(1L, 2L, 3L, 99L, 100L, 101L, 250L)) {
    x <- lapply(seq_len(k), function(i) mk())
    expect_identical(eng_fold_sum(x), Reduce(`+`, x), info = k)
  }
  # Sonderwerte
  x <- list(matrix(c(Inf, 1, -0, 0), 2L), matrix(c(1, -Inf, -0, -0), 2L), matrix(0, 2L, 2L))
  expect_identical(eng_fold_sum(x), Reduce(`+`, x))
  expect_identical(1 / eng_fold_sum(list(matrix(-0), matrix(-0))), matrix(-Inf))
  # Abzug: gleich bis auf das Vorzeichen der Null
  a <- lapply(1:5, function(i) mk())
  m <- lapply(1:3, function(i) mk())
  expect_identical(eng_fold_sum(a, minus = m), Reduce(`-`, m, Reduce(`+`, a)))
  expect_identical(eng_fold_sum(list(), minus = m), Reduce(`-`, m, matrix(0, 3L, 4L)))
  expect_null(eng_fold_sum(list()))
  one <- mk()
  expect_identical(eng_fold_sum(list(one)), one)
  # ledger_sum nutzt die Faltung
  led <- new_vofi_ledger(new_ledger_rows(c("a", "b", "c"), "project",
                                         c("rent", "operating_cost", "rent")),
                         list(a = matrix(1, 2L, 3L), b = matrix(-0.5, 2L, 3L),
                              c = matrix(0.25, 2L, 3L)), n = 2L, T = 2L)
  expect_identical(ledger_sum(led, section = "project"),
                   (matrix(1, 2L, 3L) + matrix(-0.5, 2L, 3L)) + matrix(0.25, 2L, 3L))
})

test_that("eng_df = data.frame() für einfache Spalten, sonst über data.frame()", {
  for (n in c(1L, 7L)) {
    cols <- list(a = rep(TRUE, n), b = seq_len(n) / 3, c = seq_len(n), d = rep("x", n))
    expect_identical(eng_df(cols, n), data.frame(cols, stringsAsFactors = FALSE), info = n)
  }
  # benannte Vektoren (Zeilennamen), Recycling und ungültige Namen: Weg über data.frame()
  named <- list(a = c(x = 1, y = 2), b = c(TRUE, FALSE))
  expect_identical(eng_df(named, 2L), data.frame(named, stringsAsFactors = FALSE))
  rec <- list(a = c(1, 2), b = TRUE)
  expect_identical(eng_df(rec, 2L), data.frame(rec, stringsAsFactors = FALSE))
  odd <- list(`a b` = c(1, 2))
  expect_identical(eng_df(odd, 2L), data.frame(odd, stringsAsFactors = FALSE))
  # Prüfungen und Markierungen eines Laufs sind gewöhnliche Data Frames
  p <- wsd_parts(wsd_skeleton())
  ck <- eng_checks(p$core)
  expect_identical(ck, data.frame(invariant = ck$invariant, max_dev = ck$max_dev, tol = ck$tol,
                                  ok = ck$ok, stringsAsFactors = FALSE))
  expect_identical(p$core$flags, data.frame(as.list(p$core$flags)))
})
