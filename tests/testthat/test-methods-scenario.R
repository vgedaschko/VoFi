# Tests für R/methods-scenario.R (WS-H): Methoden der Klassen vofi_scenario, vofi_spec und
# vofi_model (Spec 00 Abschnitte 4.8, 4.13, 13.6).

test_that("print.vofi_scenario und summary.vofi_scenario", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  out <- capture.output(res <- print(sc))
  expect_identical(res, sc)
  expect_match(out[1L], lbl("report.scenario.header"), fixed = TRUE)
  expect_true(any(grepl("skeleton", out, fixed = TRUE)))
  expect_true(any(grepl("01.01.2027", out, fixed = TRUE)))
  expect_true(any(grepl(lbl("vocab.enums.perspective.wu_privat"), out, fixed = TRUE)))
  s <- summary(sc)
  expect_s3_class(s, "summary_vofi_scenario")
  expect_identical(unname(s$components[, 1L]), "z")
  expect_identical(unname(s$financing[, 1L]), c("ek", "bank"))
  expect_true("financing" %in% s$counts$block)
  out2 <- capture.output(print(s))
  expect_true(any(grepl(lbl("report.scenario.components_header"), out2, fixed = TRUE)))
  expect_true(any(grepl("bullet_loan", out2, fixed = TRUE)))
  # Varianten, Szenario-Sets und Overlay
  sc2 <- sc
  sc2$variants <- list(a = list(label = "Variante A"))
  sc2$scenario_sets <- list(vorsichtig = list(generate = "cautious"))
  out3 <- capture.output(print(sc2))
  expect_true(any(grepl("base, a", out3, fixed = TRUE)))
  expect_true(any(grepl("vorsichtig", out3, fixed = TRUE)))
})

test_that("print.vofi_spec und as.data.frame.vofi_spec (Parameterliste mit Herkunft, 4.8)", {
  sp <- wsh_quiet(vofi_resolve(vofi_read_scenario(vofi_example("skeleton"))))
  out <- capture.output(print(sp))
  expect_match(out[1L], "base", fixed = TRUE)
  expect_true(any(grepl(lbl("report.scenario.financing_header"), out, fixed = TRUE)))
  expect_true(any(grepl("scenario:", out, fixed = TRUE)))
  df <- as.data.frame(sp)
  expect_true(all(c("path", "block", "kind", "value", "value_num", "layer", "source_type",
                    "file", "entry", "location", "variant", "valid_from", "valid_to",
                    "as_of", "accessed", "quality") %in% names(df)))
  expect_false(anyDuplicated(df$path) > 0L)
  r <- df[df$path == "financing.bank.amount_eur", ]
  expect_identical(r$kind, "const")
  expect_identical(r$value_num, 60000)
  expect_identical(r$value, "60.000")
  expect_identical(r$source_type, "scenario")
  expect_identical(df$value[df$path == "project.valuation_date"], "01.01.2027")
  z <- df[df$path == "components.z.values", ]
  expect_identical(z$kind, "series_t")
  expect_match(z$value, "[-100.000; 30.000; 40.000; 50.000]", fixed = TRUE)
  expect_true(all(df$block[df$block != ""] %in% names(unclass(sp))))
  fin <- as.data.frame(sp, blocks = "financing")
  expect_true(all(fin$block == "financing"))
  # Knoten als Text
  expect_identical(rep_value_text(node_ref("market.mortgage_rate")),
                   lbl("report.scenario.kind_ref", path = "market.mortgage_rate"))
  expect_identical(rep_value_text(list(kind = "expr", text = "a + b")),
                   lbl("report.scenario.kind_expr", text = "a + b"))
  expect_match(rep_value_text(list(kind = "growth", start = node_const(100),
                                   growth = node_const(0.02))), "0,02", fixed = TRUE)
  expect_identical(rep_value_text(TRUE), lbl("report.common.yes"))
  expect_identical(rep_num_text(c(0.03, 1234.5, 0, NA)), c("0,03", "1.234,5", "0", "n. d."))
})

test_that("as.data.frame.vofi_spec: Hilfswerte unter shared und Schemaversion (4.5, 4.8)", {
  sc <- wsh_quiet(vofi_read_scenario(vofi_example("grob_lehrbuch_a")))
  sp <- wsh_quiet(vofi_resolve(sc))
  df <- as.data.frame(sp)
  rw <- df[df$path == "shared.rw", ]
  expect_identical(nrow(rw), 1L)
  expect_identical(rw$block, "shared")
  expect_identical(rw$value_num, 40000)
  expect_identical(rw$source_type, "scenario")
  # jede Herkunftszeile erscheint in der Parameterliste
  pv <- attr(sp, "provenance")
  expect_true(all(pv$path %in% df$path))
  expect_true("schema_version" %in% df$path)
  expect_identical(as.data.frame(sp, blocks = "shared")$path,
                   sort(df$path[df$block == "shared"], method = "radix"))
})

test_that("print.vofi_scenario: Umfang des Stochastik-Overlays (4.3.15)", {
  sc <- wsh_quiet(vofi_read_scenario(vofi_example("grob_lehrbuch_a")))
  expect_identical(names(sc$stochastic$parameters), "rw")
  out <- capture.output(print(sc))
  expect_true(paste0("  ", lbl("report.scenario.stochastic", n = 1L)) %in% out)
  sc$stochastic$processes <- list(infl = list(target = "market.inflation", type = "ar1"))
  out2 <- capture.output(print(sc))
  expect_true(paste0("  ", lbl("report.scenario.stochastic", n = 2L)) %in% out2)
  sk <- vofi_read_scenario(vofi_example("skeleton"))
  sk$stochastic <- NULL
  expect_false(any(grepl(lbl("report.scenario.stochastic", n = 0L), capture.output(print(sk)),
                         fixed = TRUE)))
})

test_that("rep_count: Häufigkeiten in C-Ordnung (2.7 Nr. 8)", {
  x <- c("scenario", "Zeile", "global", "scenario", "library", NA, "_x")
  cnt <- rep_count(x)
  expect_identical(names(cnt), c("Zeile", "_x", "global", "library", "scenario"))
  expect_identical(unname(cnt), c(1L, 1L, 1L, 1L, 2L))
  expect_identical(length(rep_count(character(0))), 0L)
  # Herkunft je Quelle in summary() eines Szenarios
  s <- summary(vofi_read_scenario(vofi_example("skeleton")))
  expect_identical(s$provenance, c(scenario = 26L))
})

test_that("print.vofi_model", {
  m <- wsh_quiet(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
  out <- capture.output(res <- print(m))
  expect_identical(res, m)
  expect_match(out[1L], "skeleton", fixed = TRUE)
  expect_true(any(grepl("bank (bullet_loan)", out, fixed = TRUE)))
  expect_true(any(grepl("od_repay > dep_invest", out, fixed = TRUE)))
  expect_true(any(grepl(m$hash, out, fixed = TRUE)))
  # model$sampler ist stets ein smp_plan (Spec 00 4.13, 9.1 Stufe 7); das Gerüst ist
  # deterministisch und hat einen Plan ohne Ziele
  expect_s3_class(m$sampler, "smp_plan")
  expect_true(paste0("  ", lbl("report.model.sampler", n = 0L)) %in% out)
  expect_false(paste0("  ", lbl("report.model.no_sampler")) %in% out)
  # Plan nach 11.2: statische Ziehungen (static) und Prozesse (processes)
  m$sampler <- list(settings = list(n_sim = 100L),
                    static = data.frame(key = c("a", "b"), target = c("x.a", "x.b"),
                                        stringsAsFactors = FALSE),
                    processes = list(infl = list(target = "market.inflation", type = "ar1")))
  out2 <- capture.output(print(m))
  expect_true(paste0("  ", lbl("report.model.sampler", n = 3L)) %in% out2)
  m$sampler$static <- data.frame(key = character(0), target = character(0))
  m$sampler$processes <- list()
  out3 <- capture.output(print(m))
  expect_true(paste0("  ", lbl("report.model.sampler", n = 0L)) %in% out3)
  # ohne Plan (kein smp_plan, z. B. von Hand gebautes Modell): Zweig no_sampler
  m$sampler <- NULL
  out4 <- capture.output(print(m))
  expect_true(paste0("  ", lbl("report.model.no_sampler")) %in% out4)
})

test_that("Snapshots von print() und summary() eines Szenarios (15.6)", {
  skip_if_not(l10n_info()[["UTF-8"]])
  local_reproducible_output(width = 100)
  sc <- vofi_read_scenario(testthat::test_path("fixtures", "scenarios", "skeleton.yaml"))
  expect_snapshot(print(sc), transform = function(x) sub("Quelle: .*", "Quelle: <Datei>", x))
  expect_snapshot(print(summary(sc)))
})
