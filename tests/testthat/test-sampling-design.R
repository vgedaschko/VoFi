# Tests für R/sampling-design.R (WS-C; Spec 00 11.11, R-94, R-95, R-114; Spec 01 Teil C 4.3).

design_overlay <- function() {
  list(
    parameters = list(
      faktor = wsc_par("shared.f", "pert", min = 0.9, mode = 1, max = 1.4, apply = "multiply"),
      zuschlag = wsc_par("shared.s", "uniform", min = -1, max = 1, apply = "add"),
      zins = wsc_par("accounts.deposit_rate_pa", "uniform", min = 0.01, max = 0.03)
    ),
    processes = list(
      inflation = list(target = "market.inflation", type = "ar1",
                       mu = list(dist = "normal", mean = 0.02, sd = 0.004), phi = 0.5,
                       sigma = 0.011, x0 = 0.028),
      rent_growth = list(target = "market.rent_growth", type = "linked_ar1", base = "inflation",
                         a = 0.002, b = 0.8, phi = 0.5, sigma = 0.006, u0 = -0.0094),
      fest = list(target = "market.co2_price", type = "fixed_path", years = c(2027, 2033),
                  values = c(55, 85))
    )
  )
}

design_setup <- function(g = make_grid()) {
  spec <- wsc_spec(design_overlay(), g, shared = list(f = 100, s = 10))
  list(spec = spec, plan = smp_plan(spec, g), grid = g)
}

test_that("Design: statische Schlüssel (apply), Zielpfade und Basiswerte je Zeile", {
  s <- design_setup()
  des <- data.frame(faktor = c(NA, 1.2, NA, NA), zuschlag = c(NA, NA, 0.5, NA),
                    zins = c(NA, NA, NA, 0.025), shared.s = c(NA, NA, NA, 99),
                    check.names = FALSE)
  dd <- smp_design(s$plan, s$grid, des)
  expect_identical(dd$mode, "design")
  expect_identical(dd$n, 4L)
  expect_identical(dd$static$faktor, c(1, 1.2, 1, 1))
  expect_identical(dd$targets$apply[dd$targets$key == "faktor"], "multiply")
  expect_identical(dd$static$zins, c(0.02, 0.02, 0.02, 0.025))
  # Zielpfad und Schlüssel auf demselben Ziel: absolute Werte je Zeile
  expect_identical(dd$static$shared.s, c(10, 10, 10.5, 99))
  expect_false("zuschlag" %in% names(dd$static))
  ctx <- eng_context_from_parts(s$grid, s$spec, draws = dd, mode = "design")
  expect_equal(ctx$value("shared.f"), c(100, 120, 100, 100))
  expect_equal(ctx$value("shared.s"), c(10, 10, 10.5, 99))
  expect_identical(ctx$value("accounts.deposit_rate_pa"), c(0.02, 0.02, 0.02, 0.025))
  # nicht genannte Ziele behalten ihren Basiswert (keine Bindung)
  expect_false("market.inflation" %in% dd$targets$target)
  expect_identical(ctx$market("inflation"), ctx$by_sim(0.02))
})

test_that("Design: Prozessschlüssel (Quantilpfad), Prozessparameter (Erwartung), Vorrang", {
  s <- design_setup()
  g <- s$grid
  des <- data.frame(inflation = c(NA, 0.9, NA, NA), "inflation.mu" = c(NA, NA, 0.03, NA),
                    market.inflation = c(NA, NA, NA, 0.05), check.names = FALSE)
  dd <- smp_design(s$plan, g, des)
  p <- dd$paths$inflation
  expect_identical(dim(p), c(4L, g$T + 1L))
  expect_identical(p[1, ], rep(0.02, g$T + 1L))
  pt <- smp_point_par(s$plan, "inflation")
  expect_identical(pt$mu, 0.02)
  q <- wsc_proc("ar1")$quantile_path(pt, g$years, 0.9)
  expect_identical(p[2, ], as.vector(grid_map_years(g, matrix(q, 1L))))
  e <- wsc_proc("ar1")$expected(utils::modifyList(pt, list(mu = 0.03)), g$years)
  expect_identical(p[3, ], as.vector(grid_map_years(g, matrix(e, 1L))))
  expect_identical(p[4, ], rep(0.05, g$T + 1L))
  expect_identical(dd$targets$target[dd$targets$key == "inflation"], "market.inflation")
  # gekoppelter Prozess: Quantilpfad mit par$.base (R-114)
  dl <- smp_design(s$plan, g, data.frame(rent_growth = c(0.1, 0.5)))
  pl <- smp_point_par(s$plan, "rent_growth")
  expect_identical(pl$.base$type, "ar1")
  expect_identical(pl$.base$rho, 0)
  ql <- wsc_proc("linked_ar1")$quantile_path(pl, g$years, 0.1)
  expect_identical(dl$paths$rent_growth[1, ], as.vector(grid_map_years(g, matrix(ql, 1L))))
  expect_spec(wsc_proc("linked_ar1")$quantile_path(pl, 2027:2037, 0.1)[11], "0.002235904")
})

test_that("Design: Entscheidungsschlüssel wählen den Zweig (9.11 Nr. 3)", {
  fund <- list(node = list(approval_probability = 0.8, approval_timing = "before_start",
                           fallback_variant = "alt"))
  g <- make_grid()
  plan <- smp_plan(wsc_spec(list(), g, funding = fund), g)
  dd <- smp_design(plan, g, data.frame(funding.node.approved = c(NA, 0, 1),
                                       check.names = FALSE))
  expect_identical(dd$decision$funding.node.approved, c(1, 0, 1))
  expect_identical(dd$targets$kind, "decision")
  expect_error(smp_design(plan, g, data.frame(funding.node.approved = 0.5,
                                              check.names = FALSE)),
               class = "vofi_error_input")
})

test_that("Design: Fehler (Spalten, Werte, Quantilpfad, Basiswert)", {
  s <- design_setup()
  g <- s$grid
  ei <- "vofi_error_input"
  expect_error(smp_design(s$plan, g, data.frame()), class = ei)
  expect_error(smp_design(s$plan, g, list(zins = 1)), class = ei)
  expect_error(smp_design(s$plan, g, data.frame(zinss = 1)), class = ei)
  expect_error(smp_design(s$plan, g, data.frame(zins = "a")), class = ei)
  expect_error(smp_design(s$plan, g, data.frame(inflation = 1.2)), class = ei)
  expect_error(smp_design(s$plan, g, data.frame(fest = 0.5)), class = ei)
  expect_error(smp_design(s$plan, g, data.frame(shared.gibtsnicht = 1, check.names = FALSE)),
               class = ei)
  # ohne Spezifikation (Vereinigungsplan) kein Basiswert für NA bei replace
  p2 <- s$plan
  p2$spec <- NULL
  expect_error(smp_design(p2, g, data.frame(zins = c(NA, 0.02))), class = ei)
  expect_identical(smp_design(p2, g, data.frame(zins = c(0.01, 0.02)))$static$zins,
                   c(0.01, 0.02))
})

test_that("Design: Prozessparameter in noise und Punktparameter mit Verteilungen", {
  g <- make_grid()
  co2 <- list(
    target = "market.co2_price", type = "scenario_mix",
    scenarios = list(a = list(prob = 1, years = c(2027, 2033), values = c(55, 85))),
    noise = list(phi = 0.5, sigma = list(dist = "uniform", min = 0, max = 0.2))
  )
  st <- list(processes = list(co2 = co2))
  plan <- smp_plan(wsc_spec(st, g), g)
  expect_identical(plan$static$key, "co2.noise.sigma")
  pt <- smp_point_par(plan, "co2")
  expect_equal(pt$noise$sigma, 0.1)
  dd <- smp_design(plan, g, data.frame(co2.noise.sigma = c(0, 0.2), co2 = c(0.5, 0.5),
                                       check.names = FALSE))
  lin <- grid_map_years(g, matrix(c(55, 60, 65, 70, 75, 80, 85), 1L))
  expect_identical(dd$paths$co2[1, ], as.vector(lin))
  expect_true(dd$paths$co2[2, 7] < 85)
})
