# Tests des Zahlungstyps share_of (WS-E-INV; Spec 01 Teil A 4.15, Prüfwert SO1).

so_comps <- function(...) {
  list(
    miete = list(type = "recurring", amount_eur = 100000, category = "rent",
                 start_event = "2027-01-01", base_date = "2027-01-01"),
    u_std_rent = list(type = "recurring", amount_eur = 2000, category = "rent_loss",
                      start_event = "2027-01-01", base_date = "2027-01-01"),
    vw = utils::modifyList(list(type = "share_of", of = c("miete", "u_std_rent"),
                                after = c("miete", "u_std_rent"), share = 0.03,
                                category = "other_cost"), list(...))
  )
}

test_that("Vertrag und Registrierung", {
  expect_type_contract("share_of", "flow")
})

test_that("SO1: 3 % von Miete 100.000 abzüglich Mietausfall 2.000 = -2.940", {
  g <- make_grid("annual", T = 5L)
  res <- wsei_build(so_comps(), g)
  v <- wsei_row(res$flows$vw, "value")
  expect_equal(v, c(0, rep(-2940, 5)))
  r <- res$flows$vw$rows[[1]]
  expect_identical(c(r$section, r$category, r$tax_category),
                   c("project", "other_cost", "expense_deductible"))
  expect_vofi_flows_contract(res$flows$vw, res$ctx, reg_get("flow", "share_of"))
  # lag_periods 1: eine Periode später, t = 0 ist 0
  vl <- wsei_row(wsei_build(so_comps(lag_periods = 1L), g)$flows$vw, "value")
  expect_equal(vl, c(0, 0, rep(-2940, 4)))
  vl9 <- wsei_row(wsei_build(so_comps(lag_periods = 9L), g)$flows$vw, "value")
  expect_true(all(vl9 == 0))
})

test_that("Filter categories und local_rows; Anteil als Pfad", {
  g <- make_grid("annual", T = 3L)
  v <- wsei_row(wsei_build(so_comps(categories = "rent"), g)$flows$vw, "value")
  expect_equal(v, c(0, rep(-3000, 3)))
  v2 <- wsei_row(wsei_build(so_comps(local_rows = "value"), g)$flows$vw, "value")
  expect_equal(v2, c(0, rep(-2940, 3)))
  v3 <- wsei_row(wsei_build(so_comps(share = c(0, 0.01, 0.02, 0.03)), g)$flows$vw, "value")
  expect_equal(v3, -c(0, 980, 1960, 2940))
  comps <- list(
    ld = list(type = "land", purchase_price_eur = 100000, land_share = 0.4,
              date = "2027-06-01", measure_id = "m1"),
    nk = list(type = "share_of", of = "ld", after = "ld", local_rows = "price_land",
              share = 0.01, invert = FALSE, category = "other_cost")
  )
  v4 <- wsei_row(wsei_build(comps, g)$flows$nk, "value")
  expect_equal(v4, c(0, -400, 0, 0))
})

test_that("Vorzeichen muss zur Kategorie passen; Abschnitt memo nicht zahlungswirksam", {
  g <- make_grid("annual", T = 3L)
  expect_error(wsei_build(so_comps(invert = FALSE), g), class = "vofi_error_contract")
  f <- wsei_build(so_comps(invert = FALSE, section = "memo", category = "aux_memo"),
                  g)$flows$vw
  expect_false(f$rows[[1]]$cash)
  expect_equal(wsei_row(f, "value"), c(0, rep(2940, 3)))
})

test_that("validate(): Quellen, after, Zyklus auf sich selbst, Verzögerung", {
  sc <- make_spec(make_grid())
  sc$components$miete <- make_component("recurring", amount_eur = 1, category = "rent",
                                        id = "miete")
  sc$components$rw <- make_component("residual_value", method = "fixed", fixed_value_eur = 1,
                                     id = "rw")
  f <- wsei_findings("share_of", of = c("miete", "fehlt", "rw"), share = 0.1, id = "x",
                     scenario = sc)
  expect_true(all(c("of_not_after", "source_unknown", "source_residual") %in% names(f)))
  f <- wsei_findings("share_of", of = c("miete", "x"), after = c("miete", "x"), share = 0.1,
                     id = "x", scenario = sc)
  expect_identical(unname(f["source_self"]), "error")
  f <- wsei_findings("share_of", of = "miete", after = "miete", share = 0.1, lag_periods = -1L,
                     id = "x", scenario = sc)
  expect_identical(unname(f["lag_negative"]), "error")
  f <- wsei_findings("share_of", of = "miete", after = "miete", share = 0.1,
                     category = "draw", id = "x", scenario = sc)
  expect_identical(unname(f["category_invalid"]), "error")
  expect_length(wsei_findings("share_of", of = "miete", after = "miete", share = 0.1, id = "x",
                              scenario = sc), 0L)
})

test_that("Batch-Invarianz", {
  g4 <- make_grid("mixed", T = 4L)
  st <- list(
    "components.miete.amount_eur" = c(1e5, 9e4, 1.2e5),
    "components.vw.share" = c(0.03, 0.02, 0.05)
  )
  dr <- fake_draws(3L, g4, static = st)
  fun <- function(n, draws) wsei_build(so_comps(), g4, n = n, draws = draws)$flows$vw
  expect_batch_invariance(fun, n = 3L, grid = g4, draws = dr)
})
