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

test_that("Vereinigung: CRN über Varianten (gleicher Schlüssel = gleiche Ziehung, 11.10)", {
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
  # B fehlt nur der Partner y des Paars [x, y]: kein Konflikt, keine Warnung
  expect_silent(un <- smp_plan_union(list(pa, pb)))
  raw <- smp_sample(un, 1:2, 9)
  expect_s3_class(raw, "smp_raw")
  da <- smp_materialize(raw, pa, g)
  db <- smp_materialize(raw, pb, g)
  # Variante A: identisch zur Einzelziehung (gleiche Gruppe, gleiche Korrelation)
  expect_identical(da$static, smp_draw(pa, g, 1:2, 9)$static)
  # Variante B übernimmt die korrelierten Uniforms der Vereinigung: x wie in A (CRN)
  expect_identical(db$u$x, da$u$x)
  expect_identical(db$u$x, raw$u$x)
  expect_false(identical(db$u$x, raw$u_indep$x))
  expect_equal(db$static$x, 10 + 10 * da$u$x, tolerance = 1e-14)
  expect_identical(db$u$z, raw$u$z)
  # gleiche Schocks (gleicher Schlüssel, keine Schockkorrelation)
  expect_equal((da$annual$inflation[, 2] - 0.02) / 0.01, (db$annual$inflation[, 2] - 0.03) / 0.02,
               tolerance = 1e-10)
  # Rohziehungen ohne Schlüssel der Variante: Vertragsfehler
  raw_a <- smp_sample(pa, 1:2, 9)
  expect_error(smp_materialize(raw_a, pb, g), class = "vofi_error_contract")
})

test_that("Vereinigung: zusätzlicher Partner in einer Variante verschiebt keine Ziehungen (C-01)", {
  g <- make_grid()
  uni <- function(t) wsc_par(t, "uniform", min = 0, max = 1)
  va <- list(parameters = list(a = uni("shared.a"), b = uni("shared.b")),
             processes = list(mortgage_rate = list(target = "market.mortgage_rate",
                                                   type = "vasicek", r0 = 0.04, theta = 0.0375,
                                                   kappa = 0.12, sigma = 0.007)))
  vb <- list(parameters = list(a = uni("shared.a"), b = uni("shared.b"), c = uni("shared.c")),
             processes = list(mortgage_rate = va$processes$mortgage_rate,
                              inflation = list(target = "market.inflation", type = "ar1",
                                               mu = 0.02, phi = 0.5, sigma = 0.011)),
             correlations = list(parameters = list(list("a", "c", 0.7)),
                                 shocks = list(list("inflation", "mortgage_rate", 0.6))))
  pa <- smp_configure(smp_plan(wsc_spec(va, g), g), n_sim = 2000L, block_size = 200L)
  pb <- smp_configure(smp_plan(wsc_spec(vb, g), g), n_sim = 2000L, block_size = 200L)
  expect_silent(un <- smp_plan_union(list(pa, pb)))
  raw <- smp_sample(un, 1:10, 20261025)
  da <- smp_materialize(raw, pa, g)
  db <- smp_materialize(raw, pb, g)
  for (k in c("a", "b")) expect_identical(da$static[[k]], db$static[[k]])
  expect_identical(da$paths$mortgage_rate, db$paths$mortgage_rate)
  # B erhält trotzdem seine Korrelationen (Rang- bzw. Schockkorrelation)
  expect_equal(stats::cor(db$u$a, db$u$c, method = "spearman"), 0.7, tolerance = 0.03)
  dz <- function(x, phi) x[, -1L, drop = FALSE] - phi * x[, -ncol(x), drop = FALSE]
  zi <- dz(db$annual$inflation, 0.5)
  zm <- dz(db$annual$mortgage_rate, exp(-0.12))
  expect_equal(stats::cor(as.vector(zi), as.vector(zm)), 0.6, tolerance = 0.03)
  # A allein: eigene Ziehungen; in der Vereinigung bleibt b (ohne Gruppe) unverändert
  sa <- smp_draw(pa, g, 1:10, 20261025)
  expect_identical(da$static$b, sa$static$b)
})

test_that("Vereinigung: Konflikt (abweichende Paare, Reparatur, Copula) mit Warnung", {
  g <- make_grid()
  uni <- function(t) wsc_par(t, "uniform", min = 0, max = 1)
  plan <- function(st) smp_configure(smp_plan(wsc_spec(st, g), g), n_sim = 400L)
  pa <- plan(list(parameters = list(x = uni("shared.x"), y = uni("shared.y")),
                  correlations = list(parameters = list(list("x", "y", 0.8)))))
  pc <- plan(list(parameters = list(x = uni("shared.x"), y = uni("shared.y")),
                  correlations = list(parameters = list(list("x", "y", -0.5)))))
  expect_warning(un <- smp_plan_union(list(pa, pc)), class = "vofi_warning_correlation")
  raw <- smp_sample(un, 1:2, 3)
  # erste Variante: Angaben der Vereinigung; zweite: eigene Korrelation aus denselben Strömen
  expect_identical(smp_materialize(raw, pa, g)$static, smp_draw(pa, g, 1:2, 3)$static)
  dc <- smp_materialize(raw, pc, g)
  expect_identical(dc$static, smp_draw(pc, g, 1:2, 3)$static)
  expect_lt(stats::cor(dc$u$x, dc$u$y, method = "spearman"), -0.4)
  # Reparatur der vereinigten Matrix: [a, b, 0.9] und [a, c, 0.9] ohne [b, c]
  p1 <- plan(list(parameters = list(a = uni("shared.a"), b = uni("shared.b")),
                  correlations = list(parameters = list(list("a", "b", 0.9)))))
  p2 <- plan(list(parameters = list(a = uni("shared.a"), c = uni("shared.c")),
                  correlations = list(parameters = list(list("a", "c", 0.9)))))
  w <- testthat::capture_warnings(u12 <- smp_plan_union(list(p1, p2)))
  expect_length(w, 1L)
  expect_match(w, "CRN eingeschr", fixed = TRUE)
  expect_false(is.null(u12$repaired$parameters))
  r12 <- smp_sample(u12, 1:2, 3)
  expect_identical(smp_materialize(r12, p1, g)$static, smp_draw(p1, g, 1:2, 3)$static)
  expect_identical(smp_materialize(r12, p2, g)$static, smp_draw(p2, g, 1:2, 3)$static)
  # andere Copula: die Variante korreliert mit ihrer eigenen Copula
  pg <- plan(list(settings = list(copula = "gaussian"),
                  parameters = list(x = uni("shared.x"), y = uni("shared.y")),
                  correlations = list(parameters = list(list("x", "y", 0.8)))))
  expect_warning(ug <- smp_plan_union(list(pg, pa)), class = "vofi_warning_correlation")
  rg <- smp_sample(ug, 1:2, 3)
  expect_identical(smp_materialize(rg, pg, g)$static, smp_draw(pg, g, 1:2, 3)$static)
  expect_identical(smp_materialize(rg, pa, g)$static, smp_draw(pa, g, 1:2, 3)$static)
})

test_that("Vereinigung: verschiedene Startjahre, Schocks nach Kalenderjahr (C-05)", {
  ga <- make_grid()
  gb <- vofi_time_grid(as.Date("2027-01-01"), 6L, start_year = 2026L)
  infl <- list(processes = list(inflation = list(target = "market.inflation", type = "ar1",
                                                 mu = 0.02, phi = 0.5, sigma = 0.01)))
  pa <- smp_configure(smp_plan(wsc_spec(infl, ga), ga), n_sim = 20L, block_size = 10L)
  pb <- smp_configure(smp_plan(wsc_spec(infl, gb), gb), n_sim = 20L, block_size = 10L)
  expect_identical(pa$years, 2027:2032)
  expect_identical(pb$years, 2026:2032)
  expect_warning(un <- smp_plan_union(list(pa, pb)), class = "vofi_warning_correlation")
  expect_identical(un$years, 2026:2032)
  raw <- smp_sample(un, 1:2, 17)
  expect_identical(dim(raw$z$inflation), c(20L, 6L))
  da <- smp_materialize(raw, pa, ga)
  db <- smp_materialize(raw, pb, gb)
  expect_identical(da$years, 2027:2032)
  # Schock des Kalenderjahres y: (x_y - mu - phi (x_{y-1} - mu)) / sigma
  shock <- function(x) (x[, -1L] - 0.02 - 0.5 * (x[, -ncol(x)] - 0.02)) / 0.01
  za <- shock(da$annual$inflation)                  # Jahre 2028-2032
  zb <- shock(db$annual$inflation)                  # Jahre 2027-2032
  expect_equal(za, zb[, -1L], tolerance = 1e-9)
  expect_equal(zb, raw$z$inflation, tolerance = 1e-9)
  # Variante, deren Jahre nicht in den Rohziehungen liegen: Vertragsfehler
  gl <- vofi_time_grid(as.Date("2027-01-01"), 9L)
  pl <- smp_configure(smp_plan(wsc_spec(infl, gl), gl), n_sim = 20L, block_size = 10L)
  expect_error(smp_materialize(raw, pl, gl), class = "vofi_error_contract")
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
  # Umlaute erscheinen in der Ausgabe nur unter einer UTF-8-Locale unveraendert (Spec 00 15.6);
  # unter LANG=C setzt R sie als <U+00E4> um
  expect_match(out[1], "^Ziehungen .*: 20 L.+ufe in 2 Block")
  if (isTRUE(l10n_info()[["UTF-8"]])) expect_match(out[1], "20 L\u00e4ufe in 2 Block")
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

test_that("Meldungen: Vorschläge für n_sim und Schlüssel im Alias-Hinweis (C-07)", {
  g <- make_grid()
  pl <- wsc_plan(list(parameters = list(a = wsc_par("shared.a", "uniform", min = 0, max = 1))),
                 g)
  msg_of <- function(expr) conditionMessage(tryCatch(expr, error = identity))
  m1 <- msg_of(smp_configure(pl, n_sim = 100L))
  expect_match(m1, "z. B. 200.", fixed = TRUE)
  expect_false(grepl("200 oder 200", m1, fixed = TRUE))
  expect_match(msg_of(smp_configure(pl, n_sim = 450L)), "z. B. 400 oder 600.", fixed = TRUE)
  m2 <- msg_of(suppressMessages(smp_configure(pl, n_sim = 5L, replicates = 10L)))
  expect_match(m2, "z. B. 10.", fixed = TRUE)
  expect_match(msg_of(suppressMessages(smp_configure(pl, n_sim = 25L, replicates = 10L))),
               "z. B. 20 oder 30.", fixed = TRUE)
  expect_error(smp_configure(pl, n_sim = 100L), class = "vofi_error_input")
  # Alias min/max bei truncnorm in Prozessparametern: Hinweis mit <proc>.<param>
  st <- list(processes = list(v = list(target = "market.inflation", type = "iid",
                                       dist_spec = list(dist = "truncnorm", mean = 0, sd = 1,
                                                        min = -1))))
  w <- testthat::capture_warnings(smp_plan(wsc_spec(st, g), g))
  expect_length(w, 1L)
  expect_match(w, "'v.dist_spec'", fixed = TRUE)
  st2 <- list(processes = list(r = list(target = "market.inflation", type = "ar1", mu = 0.02,
                                        phi = list(dist = "truncnorm", mean = 0.5, sd = 0.1,
                                                   min = 0, max = 0.9),
                                        sigma = 0.01)))
  w2 <- testthat::capture_warnings(smp_plan(wsc_spec(st2, g), g))
  expect_true(length(w2) >= 1L && all(grepl("'r.phi'", w2, fixed = TRUE)))
})
