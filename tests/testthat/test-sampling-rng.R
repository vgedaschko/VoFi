# Tests für R/sampling-rng.R (WS-C; Spec 00 11.3, 11.5; Spec 01 Teil C 1.10.3 Golden-Vektoren).

test_that("Golden: stream_hash und stream_seed (Spec 01 Teil C 1.10.3)", {
  golden <- data.frame(
    name = c("par:huelle_kosten:1", "shock:mortgage_rate:1", "scen:co2_price:1", "ic:jaz:3",
             "par:funding.kfw261.approved:10", "par:huelle_kosten:2",
             "par:funding.kfw261.approved:1"),
    hash = c(82619639, 1339347028, 406293088, 696621842, 873314676, 82619640, NA),
    seed = c(1807676916, 916920658, 2131350365, 274195472, 450888306, 1807676917, 1698937791),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(golden))) {
    if (!is.na(golden$hash[i])) expect_identical(stream_hash(golden$name[i]), golden$hash[i])
    expect_identical(stream_seed(20261025, golden$name[i]), golden$seed[i])
  }
  # seed * 1000003 bleibt exakt in double
  expect_lt(2147483646 * 1000003, 2^53)
  expect_identical(smp_stream_name("par", "huelle_kosten", 1L), "par:huelle_kosten:1")
  expect_identical(smp_stream_name("ic", "jaz", 3), "ic:jaz:3")
  expect_identical(smp_stream_name("par", "k", 100000L), "par:k:100000")
})

test_that("Golden: LHS-Uniforms par:huelle_kosten:1 mit m = 10 und PERT darauf", {
  u <- smp_uniforms(20261025, "par:huelle_kosten:1", 10L, "lhs")
  expect_spec(u, c("0.0770428277", "0.7377466243", "0.8153801601", "0.2168623472",
                   "0.4181502454", "0.9103939940", "0.5083356354", "0.6902026086",
                   "0.3590937947", "0.1715651234"))
  expect_identical(sort(floor(u * 10)), as.double(0:9))
  x <- wsc_dist("pert")$quantile(u, list(min = 0.95, mode = 1.10, max = 1.50))
  expect_spec(x, c("1.00872837", "1.20510886", "1.23600605", "1.05493489", "1.10973613",
                   "1.28741166", "1.13418902", "1.18860953", "1.09397463", "1.04146840"))
  # erst sample.int, dann runif (Spec 00 11.5)
  ref <- with_stream(20261025, "par:huelle_kosten:1", {
    s <- sample.int(10)
    (s - runif(10)) / 10
  })
  expect_identical(u, ref)
})

test_that("Golden: Schocks shock:mortgage_rate:1 (Spalte 1, m = 10) und Pseudo-Uniforms", {
  z <- smp_shocks(20261025, "shock:mortgage_rate:1", 10L, 3L, "lhs")
  expect_spec(z[, 1], c("0.14282540", "0.74789624", "0.31988633", "-0.42734243",
                        "1.27760831", "-0.71211298", "1.98313306", "-1.39581165",
                        "-1.15778342", "-0.21440874"))
  # Spaltenweise Erzeugung: mehr Jahre ändern die früheren Spalten nicht
  z5 <- smp_shocks(20261025, "shock:mortgage_rate:1", 10L, 5L, "lhs")
  expect_identical(z5[, 1:3], z)
  for (j in 1:5) expect_identical(sort(floor(pnorm(z5[, j]) * 10 + 1e-12)), as.double(0:9))
  p <- smp_uniforms(20261025, "par:huelle_kosten:1", 5L, "pseudo")
  expect_spec(p, c("0.9472584811", "0.1823872703", "0.7804699554", "0.4783886457",
                   "0.0081785580"))
  zp <- smp_shocks(1, "shock:x:1", 4L, 2L, "pseudo")
  expect_identical(zp, with_stream(1, "shock:x:1", {
    a <- rnorm(4)
    cbind(a, rnorm(4), deparse.level = 0)
  }))
  expect_identical(dim(smp_shocks(1, "shock:x:1", 4L, 0L, "lhs")), c(4L, 0L))
})

test_that("Golden: Default-Blockgröße m = 200 (Blöcke 1 und 2, Bernoulli 0,85)", {
  u1 <- smp_uniforms(20261025, "par:huelle_kosten:1", 200L, "lhs")
  expect_spec(u1[1:5], c("0.6396843421", "0.8825087800", "0.5951837389", "0.1187823656",
                         "0.2526394482"))
  expect_spec(mean(u1), "0.5000569179")
  expect_identical(sort(floor(200 * u1)), as.double(0:199))
  u2 <- smp_uniforms(20261025, "par:huelle_kosten:2", 200L, "lhs")
  expect_spec(u2[1:5], c("0.8671389795", "0.5422675004", "0.1600440787", "0.1734603451",
                         "0.1094319985"))
  ua <- smp_uniforms(20261025, "par:funding.kfw261.approved:1", 200L, "lhs")
  x <- wsc_dist("bernoulli")$quantile(ua, list(p = 0.85))
  expect_identical(sum(x), 170)
  expect_identical(x[1:5], c(1, 1, 1, 1, 0))
})

test_that("Antithetische Variablen: c(v, 1 - v) bzw. c(w, -w) je Block", {
  u <- smp_uniforms(3, "par:k:1", 6L, "pseudo", antithetic = TRUE)
  expect_identical(u[4:6], 1 - u[1:3])
  expect_identical(u[1:3], with_stream(3, "par:k:1", runif(3)))
  z <- smp_shocks(3, "shock:p:1", 6L, 2L, "pseudo", antithetic = TRUE)
  expect_identical(z[4:6, ], -z[1:3, ])
  m <- smp_uniform_matrix(3, "uni:p:1", 6L, 2L, "pseudo", antithetic = TRUE)
  expect_identical(m[4:6, ], 1 - m[1:3, ])
  ml <- smp_uniform_matrix(3, "uni:p:1", 8L, 2L, "lhs")
  for (j in 1:2) expect_identical(sort(floor(ml[, j] * 8)), as.double(0:7))
})

test_that("Läufe und Blöcke: Lauf i gehört zu Block ceiling(i / m)", {
  expect_identical(smp_sims_of(c(1L, 3L), 4L), c(1:4, 9:12))
  expect_identical(smp_block_of(c(1, 200, 201, 1000), 200L), c(1L, 1L, 2L, 5L))
})

test_that("RNG-Hygiene: globaler Zustand und RNGkind des Nutzers bleiben unverändert", {
  withr::local_seed(42)
  kind <- RNGkind()
  before <- .Random.seed
  smp_uniforms(1, "par:a:1", 50L, "lhs")
  smp_shocks(1, "shock:a:1", 50L, 3L, "lhs")
  smp_ic_scores(1, "a", 1L, 50L)
  expect_identical(.Random.seed, before)
  expect_identical(RNGkind(), kind)
  # Scores: Permutation der van-der-Waerden-Scores
  sc <- smp_ic_scores(1, "a", 1L, 50L)
  expect_identical(sort(sc), qnorm(seq_len(50) / 51))
  expect_identical(sc, smp_ic_scores(1, "a", 1L, 50L))
  expect_false(identical(sc, smp_ic_scores(1, "a", 2L, 50L)))
})
