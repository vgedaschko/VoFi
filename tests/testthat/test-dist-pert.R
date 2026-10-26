# Tests für R/dist-pert.R (WS-C; Spec 01 Teil C 1.4.7).

test_that("pert: Prüffälle p1-p8 (α/β, Mittel, sd, q10/q50/q90)", {
  d <- wsc_dist("pert")
  cases <- list(
    list(c(0.95, 1.05, 1.35), c(2, 4), c(1.0833333, 0.071269665, 0.99489398, 1.0755241, 1.1835561)),
    list(c(0.95, 1.10, 1.50), c(2.0909091, 3.9090909),
         c(1.1416667, 0.099053056, 1.0176133, 1.13189, 1.2804662)),
    list(c(0, 2, 12), c(1.6666667, 4.3333333),
         c(3.3333333, 2.031498, 0.911916, 3.0234477, 6.2232185)),
    list(c(0, 1, 6), c(1.6666667, 4.3333333),
         c(1.6666667, 1.015749, 0.455958, 1.5117239, 3.1116093)),
    list(c(2.6, 3.2, 4.0), c(2.7142857, 3.2857143),
         c(3.2333333, 0.26337251, 2.8864917, 3.2254664, 3.5920217)),
    list(c(0.5, 0.7, 1.0), c(2.6, 3.4),
         c(0.71666667, 0.093647431, 0.59430958, 0.7127354, 0.84494477)),
    list(c(0.9, 1.1, 1.4), c(2.6, 3.4),
         c(1.1166667, 0.093647431, 0.99430958, 1.1127354, 1.2449448)),
    list(c(0.82, 1.0, 1.27), c(2.6, 3.4), c(1.015, 0.084282688, 0.90487862, 1.0114619, 1.1304503)),
    list(c(0, 0.02, 0.08), c(2, 4), c(0.026666667, 0.014253933, 0.0089787967, 0.025104814,
                                      0.04671123))
  )
  for (cs in cases) {
    par <- list(min = cs[[1]][1], mode = cs[[1]][2], max = cs[[1]][3])
    p <- dist_pert_par(par)
    expect_equal(c(p$alpha, p$beta), cs[[2]], tolerance = 1e-7)
    m <- d$moments(par)
    expect_equal(c(m$mean, sqrt(m$var)), cs[[3]][1:2], tolerance = 1e-7)
    expect_equal(d$quantile(c(0.1, 0.5, 0.9), par), cs[[3]][3:5], tolerance = 1e-7)
  }
})

test_that("pert: Prüffall p9 (λ = 6) und D1 von p2", {
  d <- wsc_dist("pert")
  par <- list(min = 0, mode = 2, max = 12, lambda = 6)
  p <- dist_pert_par(par)
  expect_equal(c(p$alpha, p$beta), c(2, 6))
  m <- d$moments(par)
  expect_equal(m$mean, 3, tolerance = 1e-14)
  expect_spec(sqrt(m$var), "1.7320508")
  expect_spec(d$quantile(c(0.1, 0.5, 0.9), par), c("0.94588135", "2.7418796", "5.4307793"))
  expect_spec(d$quantile(c(1e-9, 0.5, 1 - 1e-9), list(min = 0.95, mode = 1.10, max = 1.50)),
              c("0.95000895", "1.13189", "1.4982258"))
})

test_that("pert: Golden-PERT auf den LHS-Uniforms (Spec 01 Teil C 1.10.3)", {
  d <- wsc_dist("pert")
  u <- c(0.0770428277, 0.7377466243, 0.8153801601, 0.2168623472, 0.4181502454, 0.9103939940,
         0.5083356354, 0.6902026086, 0.3590937947, 0.1715651234)
  expect_spec(d$quantile(u, list(min = 0.95, mode = 1.10, max = 1.50)),
              c("1.00872837", "1.20510886", "1.23600605", "1.05493489", "1.10973613",
                "1.28741166", "1.13418902", "1.18860953", "1.09397463", "1.04146840"))
})

test_that("pert: Entartung, Modus am Rand, Validierung, Vertrag", {
  d <- wsc_dist("pert")
  expect_identical(d$quantile(c(0, 0.5, 1), list(min = 1, mode = 1, max = 1)), c(1, 1, 1))
  expect_identical(d$moments(list(min = 1, mode = 1, max = 1)), list(mean = 1, var = 0))
  q <- d$quantile(c(0, 0.5, 1), list(min = 0, mode = 0, max = 1))
  expect_identical(q[c(1, 3)], c(0, 1))
  expect_identical(d$point(list(min = 0, mode = 0.2, max = 1), "mode"), 0.2)
  expect_identical(d$validate(list(min = 0.95, mode = 1.10, max = 1.50)), character(0))
  expect_length(d$validate(list(min = 2, mode = 1, max = 3)), 1L)
  expect_length(d$validate(list(min = 0, mode = 1, max = 3, lambda = 0)), 1L)
  expect_length(d$validate(list(min = 0, mode = 1)), 1L)
  expect_type_contract("pert", "distribution")
})
