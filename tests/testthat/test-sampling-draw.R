# Tests für R/sampling-draw.R (WS-C; Spec 00 11.4-11.8, 11.10; Spec 01 Teil C 1.3, 1.9).

overlay <- function() {
  list(
    settings = list(seed = 20261025),
    parameters = list(
      huelle_kosten = wsc_par("shared.cost", "pert", min = 0.95, mode = 1.10, max = 1.50,
                              apply = "multiply"),
      zins = wsc_par("accounts.deposit_rate_pa", "uniform", min = 0.01, max = 0.03)
    ),
    processes = list(
      inflation = list(target = "market.inflation", type = "ar1",
                       mu = list(dist = "normal", mean = 0.02, sd = 0.004), phi = 0.5,
                       sigma = 0.011, x0 = "base"),
      rent_growth = list(target = "market.rent_growth", type = "linked_ar1", base = "inflation",
                         a = 0.002, b = 0.8, phi = 0.5, sigma = 0.006, u0 = "base"),
      mortgage_rate = list(target = "market.mortgage_rate", type = "vasicek", r0 = "base",
                           theta = 0.0375, kappa = 0.12, sigma = 0.007, floor = 0.005),
      co2_price = list(target = "market.co2_price", type = "scenario_mix",
                       scenarios = list(niedrig = list(prob = 0.5, years = c(2027, 2033),
                                                       values = c(55, 60)),
                                        hoch = list(prob = 0.5, years = c(2027, 2033),
                                                    values = c(55, 200))))
    ),
    correlations = list(shocks = list(list("inflation", "mortgage_rate", 0.4)))
  )
}

test_that("Ziehungsobjekt: Struktur, Zusicherungen (11.8) und Metadaten", {
  g <- make_grid()
  dr <- wsc_draw(overlay(), 20L, block_size = 10L, grid = g, shared = list(cost = 543301.50))
  expect_s3_class(dr, "vofi_draws")
  expect_identical(dr$mode, "mc")
  expect_identical(c(dr$n, dr$block_size), c(20L, 10L))
  expect_identical(dr$sims, 1:20)
  expect_identical(dr$blocks, 1:2)
  expect_identical(names(dr$static), c("huelle_kosten", "inflation.mu", "zins"))
  for (k in names(dr$static)) expect_length(dr$static[[k]], 20L)
  for (k in names(dr$paths)) expect_identical(dim(dr$paths[[k]]), c(20L, g$T + 1L))
  expect_identical(dim(dr$annual$inflation), c(20L, length(g$years)))
  expect_identical(dr$years, g$years)
  tg <- dr$targets
  expect_identical(tg$kind, c(rep("static", 3L), rep("process", 4L)))
  expect_identical(tg$apply[tg$key == "huelle_kosten"], "multiply")
  expect_false(anyDuplicated(tg$target) > 0L)
  expect_identical(dr$scenario_index$co2_price, as.integer(dr$features$co2_price.scenario))
  expect_true(all(dr$scenario_index$co2_price %in% 1:2))
  expect_identical(dr$meta$block_size, 10L)
  expect_identical(dr$meta$replicates, 2L)
  expect_identical(dr$meta$rng_kind, c("Mersenne-Twister", "Inversion", "Rejection"))
  expect_identical(dr$meta$seed, 20261025)
  expect_identical(dr$meta$copula, "iman_conover")
  expect_match(dr$meta$plan_hash, "^[0-9a-f]{32}$")
  expect_identical(validate_vofi_draws(dr, g$T), dr)
  # Uniforms von Lauf 1: Golden-Vektor (m = 10)
  expect_spec(dr$u$huelle_kosten[1], "0.0770428277")
  expect_spec(dr$static$huelle_kosten[1], "1.0087283674")
  # Start der Prozesse am Basisfall (x_det), Spalte 1 = Startwert
  expect_identical(unique(dr$annual$inflation[, 1]), 0.02)
  expect_identical(unique(dr$annual$rent_growth[, 1]), 0.015)
  expect_identical(unique(dr$paths$mortgage_rate[, 1]), 0.04)
  expect_true(all(dr$paths$mortgage_rate >= 0.005))
  expect_identical(unique(dr$paths$co2_price[, 1]), 55)
})

test_that("Prüffall apply (Spec 01 Teil C 1.3): Faktor x in draws, b * x im Kontext", {
  g <- make_grid()
  spec <- wsc_spec(overlay(), g, shared = list(cost = 543301.50))
  plan <- smp_configure(smp_plan(spec, g), n_sim = 10L, block_size = 10L)
  dr <- smp_draw(plan, g, 1L, 20261025)
  ctx <- eng_context_from_parts(g, spec, draws = dr, mode = "mc")
  expect_spec(ctx$value("shared.cost")[1], "548043.64")
  expect_equal(ctx$value("shared.cost"), 543301.50 * dr$static$huelle_kosten, tolerance = 1e-14)
  expect_identical(ctx$value("accounts.deposit_rate_pa"), dr$static$zins)
  expect_identical(ctx$market("inflation"), dr$paths$inflation)
  # Basisfall ohne Ziehungen
  expect_identical(ctx$value_base("shared.cost"), rep(543301.50, 10L))
  # Designzeilen: Overlay-Schlüssel setzt x, Zielpfad den absoluten Wert
  des <- data.frame(huelle_kosten = c(NA, 1.2, NA), shared.cost = c(NA, NA, 600000),
                    check.names = FALSE)
  dd <- smp_design(plan, g, des)
  cd <- eng_context_from_parts(g, spec, draws = dd, mode = "design")
  expect_spec(cd$value("shared.cost"), c("543301.50", "651961.80", "600000.00"))
})

test_that("Lauf i hängt nur von Seed, Schlüssel, m und b ab (R-73)", {
  g <- make_grid()
  plan <- wsc_plan(overlay(), g, n_sim = 30L, block_size = 10L)
  all3 <- smp_draw(plan, g, 1:3, 5)
  only2 <- smp_draw(plan, g, 2L, 5)
  rows <- 11:20
  for (k in names(all3$static)) expect_identical(only2$static[[k]], all3$static[[k]][rows])
  for (k in names(all3$paths)) {
    expect_identical(only2$paths[[k]], all3$paths[[k]][rows, , drop = FALSE])
  }
  expect_identical(only2$sims, 11:20)
  expect_identical(only2$features, `rownames<-`(all3$features[rows, , drop = FALSE], NULL))
  expect_identical(smp_draw(plan, g, c(3L, 1L), 5)$static$zins,
                   c(all3$static$zins[21:30], all3$static$zins[1:10]))
  # anderer Seed: andere Ziehungen
  expect_false(identical(smp_draw(plan, g, 1L, 6)$static$zins, all3$static$zins[1:10]))
})

test_that("Gemischtes Raster: Abbildung der Kalenderjahre auf die Perioden", {
  gm <- make_grid("mixed")
  dr <- wsc_draw(overlay(), 10L, block_size = 10L, grid = gm)
  a <- dr$annual$inflation
  p <- dr$paths$inflation
  expect_identical(dim(p), c(10L, gm$T + 1L))
  expect_identical(p, grid_map_years(gm, a))
  expect_identical(p[, gm$year == 2027], matrix(a[, 1], 10L, sum(gm$year == 2027)))
})

test_that("u0 = base je Lauf bei unsicherem Startwert der Basis (g_1 = x_det)", {
  st <- overlay()
  st$processes$inflation$x0 <- list(dist = "uniform", min = 0.01, max = 0.03)
  dr <- wsc_draw(st, 20L, block_size = 10L)
  expect_true(length(unique(dr$annual$inflation[, 1])) > 1L)
  expect_equal(dr$annual$rent_growth[, 1], rep(0.015, 20L), tolerance = 1e-15)
  expect_identical(dr$annual$inflation[, 1], dr$static$inflation.x0)
})

test_that("Entscheidungsschlüssel: gezogen, in draws$decision, ohne Zielwirkung (R-71)", {
  fund <- list(node = list(approval_probability = 0.85, approval_timing = "before_start",
                           fallback_variant = "v1b"),
               kfw = list(approval_probability = 0.5, approved = 1))
  g <- make_grid()
  spec <- wsc_spec(list(), g, funding = fund)
  plan <- smp_configure(smp_plan(spec, g), n_sim = 200L)
  dr <- smp_draw(plan, g, 1L, 20261025)
  expect_identical(names(dr$decision), "funding.node.approved")
  expect_identical(names(dr$static), "funding.kfw.approved")
  expect_identical(sum(dr$decision$funding.node.approved), 170)
  expect_identical(sum(dr$static$funding.kfw.approved), 100)
  expect_identical(dr$targets$kind, c("static", "decision"))
  expect_identical(dr$u$funding.node.approved,
                   smp_uniforms(20261025, "par:funding.node.approved:1", 200L))
  ctx <- eng_context_from_parts(g, spec, draws = dr, mode = "mc")
  expect_identical(ctx$value("funding.kfw.approved"), dr$static$funding.kfw.approved)
  expect_identical(ctx$draw("funding.node.approved"), dr$decision$funding.node.approved)
  expect_null(ctx$value("funding.node.approved"))
})

test_that("Vereinigung: CRN über Varianten, abweichende Korrelation je Variante", {
  g <- make_grid()
  va <- list(parameters = list(x = wsc_par("shared.x", "uniform", min = 0, max = 1),
                               y = wsc_par("shared.y", "pert", min = 0, mode = 1, max = 2)),
             processes = list(inflation = list(target = "market.inflation", type = "ar1",
                                               mu = 0.02, phi = 0.5, sigma = 0.01)),
             correlations = list(parameters = list(list("x", "y", 0.8))))
  vb <- list(parameters = list(x = wsc_par("shared.x", "uniform", min = 10, max = 20),
                               z = wsc_par("shared.z", "normal", mean = 0, sd = 1)),
             processes = list(inflation = list(target = "market.inflation", type = "ar1",
                                               mu = 0.03, phi = 0.5, sigma = 0.02)))
  pa <- smp_configure(smp_plan(wsc_spec(va, g), g), n_sim = 20L, block_size = 10L)
  pb <- smp_configure(smp_plan(wsc_spec(vb, g), g), n_sim = 20L, block_size = 10L)
  un <- smp_plan_union(list(pa, pb))
  raw <- smp_sample(un, 1:2, 9)
  expect_s3_class(raw, "smp_raw")
  da <- smp_materialize(raw, pa, g)
  db <- smp_materialize(raw, pb, g)
  # Variante A: identisch zur Einzelziehung (gleiche Korrelation)
  expect_identical(da$static, smp_draw(pa, g, 1:2, 9)$static)
  # Variante B ohne Korrelationsgruppe: x unkorreliert, gleiche Schocks (gleicher Schlüssel)
  expect_identical(db$static$x, smp_draw(pb, g, 1:2, 9)$static$x)
  expect_identical(db$u$z, raw$u$z)
  expect_equal((da$annual$inflation[, 2] - 0.02) / 0.01, (db$annual$inflation[, 2] - 0.03) / 0.02,
               tolerance = 1e-10)
  expect_identical(db$u$x, raw$u_indep$x)
  expect_false(identical(da$u$x, raw$u_indep$x))
  # Rohziehungen ohne Schlüssel der Variante: Vertragsfehler
  raw_a <- smp_sample(pa, 1:2, 9)
  expect_error(smp_materialize(raw_a, pb, g), class = "vofi_error_contract")
})

test_that("Deterministischer Modus, Seed- und Blockprüfung", {
  g <- make_grid()
  plan <- wsc_plan(overlay(), g, n_sim = 20L, block_size = 10L)
  d0 <- smp_draw(plan, g, 1L, NULL, mode = "deterministic")
  expect_identical(d0$mode, "deterministic")
  expect_identical(d0$n, 1L)
  expect_length(d0$static, 0L)
  expect_error(smp_draw(plan, g, 1L, NULL), class = "vofi_error_input")
  expect_error(smp_draw(plan, g, c(1L, 1L), 1), class = "vofi_error_input")
  expect_error(smp_draw(plan, g, 0L, 1), class = "vofi_error_input")
  expect_error(smp_sample("plan", 1L, 1), class = "vofi_error_input")
  expect_error(smp_materialize(list(), plan, g), class = "vofi_error_contract")
  # Plan ohne stochastische Größen: leere, aber gültige Ziehungen
  p0 <- wsc_plan(list(), g, n_sim = 4L, block_size = 2L)
  e <- smp_draw(p0, g, 1:2, 1)
  expect_identical(e$n, 4L)
  expect_identical(nrow(e$targets), 0L)
})

test_that("Pfadmerkmale: mean, end, at<jahr> (Zinsanpassung) und scenario", {
  g <- vofi_time_grid(as.Date("2027-01-01"), 12L)
  spec <- wsc_spec(overlay(), g)
  spec$financing$bank <- list(id = "bank", type = "annuity_loan",
                              followup_rate_pa = list(kind = "ref", path = "market.mortgage_rate"),
                              fixed_years = list(kind = "const", value = 5),
                              followup_fixed_years = list(kind = "const", value = 5))
  plan <- smp_configure(smp_plan(spec, g), n_sim = 10L, block_size = 10L)
  dr <- smp_draw(plan, g, 1L, 3)
  f <- dr$features
  expect_identical(nrow(f), 10L)
  expect_true(all(c("inflation.mean", "inflation.end", "mortgage_rate.at2031",
                    "mortgage_rate.at2036", "co2_price.scenario") %in% names(f)))
  yrs <- g$years
  expect_equal(f$inflation.mean, rowMeans(dr$annual$inflation[, yrs %in% 2027:2038]))
  expect_identical(f$inflation.end, dr$annual$inflation[, yrs == 2038])
  expect_identical(f$mortgage_rate.at2031, dr$paths$mortgage_rate[, 6])
  expect_identical(f$mortgage_rate.at2036, dr$paths$mortgage_rate[, 11])
  expect_false(any(grepl("^inflation\\.at", names(f))))
})

test_that("Methoden print() und as.data.frame() für vofi_draws", {
  dr <- wsc_draw(overlay(), 20L, block_size = 10L, shared = list(cost = 1))
  out <- utils::capture.output(print(dr))
  expect_match(out[1], "20 L\u00e4ufe in 2 Block")
  expect_true(any(grepl("huelle_kosten", out)))
  expect_true(any(grepl("mortgage_rate", out)))
  utils::capture.output(res <- print(dr))
  expect_identical(res, dr)
  df <- as.data.frame(dr)
  expect_identical(names(df), c("sim", "block", "huelle_kosten", "inflation.mu", "zins"))
  expect_identical(df$block, rep(1:2, each = 10L))
  expect_identical(df$zins, dr$static$zins)
  e <- new_vofi_draws("mc", n = 2L)
  expect_match(utils::capture.output(print(e))[2], "keine")
  expect_identical(names(as.data.frame(e)), c("sim", "block"))
  many <- list(parameters = stats::setNames(lapply(1:25, function(i) {
    wsc_par(paste0("shared.k", i), "uniform", min = 0, max = 1)
  }), sprintf("k%02d", 1:25)))
  dm <- wsc_draw(many, 4L, block_size = 2L)
  expect_true(any(grepl("weitere 5", utils::capture.output(print(dm)))))
})
