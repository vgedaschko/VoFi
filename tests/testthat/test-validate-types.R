# Tests für R/validate-types.R (WS-B; Spec 00 Abschnitte 4.3-4.6, 5.4, 8.9, 10.2, 10.7, 11.4,
# 11.5; Feldtabellen Spec 01 Teile A-C).

test_that("Prüffälle der Ebene 2 (Tabelle)", {
  wsb_registry()
  wsb_expect_cases(wsb_cases_types())
})

test_that("Domänenszenario ohne Befund; unbekannte Felder in Blöcken sind Fehler (R-106)", {
  expect_identical(nrow(vofi_validate(wsb_with("domain"))), 0L)
  sc <- wsb_with("skeleton", function(x) {
    x$accounts$deposit_rate <- 0.02
    x$building <- list(n_units = 4L, unbekannt = 1)
    x$project$municipality <- list(mietpreisbremse_area = TRUE)
    x$meta$version <- "2026-10-25a"
    x$analysis$thresholds <- list(dscr = 1.2)
    x
  })
  v <- vofi_validate(sc)
  hit <- v[v$code == "validation.unknown_field", , drop = FALSE]
  expect_setequal(hit$path, c("accounts.deposit_rate", "building.unbekannt"))
  expect_identical(unique(hit$severity), "error")
  expect_match(hit$message[hit$path == "accounts.deposit_rate"], "deposit_rate_pa", fixed = TRUE)
  expect_error(vofi_build(sc), class = "vofi_error_validation")
})

test_that("Wertebereiche: Intervalle mit ausschließlichen Grenzen, Pfade, Schwere", {
  v <- vofi_validate(wsb_with("domain", function(x) {
    x$measures$huelle$useful_life_years <- 0
    x$measures$huelle$vat_rate <- 0.16
    x$unit_groups$a$vacancy_rate <- 0.2
    x
  }), variant = "base")
  r <- v[v$code == "validation.range", , drop = FALSE]
  expect_identical(r$path, "measures.huelle.useful_life_years")
  expect_match(r$message, "(0, Inf]", fixed = TRUE)
  u <- v[v$code == "validation.unusual", , drop = FALSE]
  expect_identical(u$severity, "warning")
  expect_identical(u$path, "unit_groups.a.vacancy_rate")
  expect_match(u$message, "[0, 0.15]", fixed = TRUE)
  uv <- v[v$code == "validation.unusual_value", , drop = FALSE]
  expect_identical(uv$path, "measures.huelle.vat_rate")
  # Kredite: Bereich aus dem Parameterschema des Typs (WS-F), Pfad des Parameters
  v2 <- vofi_validate(wsb_with("skeleton", function(x) {
    x$financing$bank$amount_eur <- -60000
    x
  }))
  expect_identical(v2$path[v2$code == "validation.range"], "financing.bank.amount_eur")
})

test_that("Plausibilitätsbereiche mit warn_domain nur in Szenarien mit Domänenblöcken", {
  sk <- wsb_with("skeleton")
  expect_identical(sk$project$horizon_years, 3L)
  expect_false("validation.unusual" %in% vofi_validate(sk)$code)
  dom <- wsb_with("domain", function(x) {
    x$project$horizon_years <- 5L
    x$components$z$values <- c(-100000, rep(10000, 5))
    x
  })
  v <- vofi_validate(dom, variant = "base")
  expect_identical(v$path[v$code == "validation.unusual"], "project.horizon_years")
})

test_that("ids: Muster, Länge je Sammlung (R-90), Kollision, reservierte Präfixe", {
  v <- vofi_validate(wsb_with("domain", function(x) {
    x$measures[["m_genau_neunundzwanzig_zeich"]] <- wsb_m()
    x$measures[["m_dreissig_zeichen_lange_id_x1"]] <- wsb_m()
    x$funding <- list(f_dreissig_zeichen_lange_id_ab = list(instrument_type = "grant",
                                                             measures = "huelle"))
    x$energy <- list(stages = list(stufe_dreizehn = list(label = "s")),
                     carriers = list(traeger_mit_einundzwanzig = list(class = "gas")))
    x
  }))
  tl <- v[v$code == "validation.id_too_long", , drop = FALSE]
  expect_setequal(tl$path, c("measures.m_dreissig_zeichen_lange_id_x1",
                             "energy.stages.stufe_dreizehn",
                             "energy.carriers.traeger_mit_einundzwanzig"))
  expect_match(tl$message[tl$path == "energy.stages.stufe_dreizehn"], "12", fixed = TRUE)
  expect_false(any(v$path == "funding.f_dreissig_zeichen_lange_id_ab" &
                     v$code == "validation.id_too_long"))
  expect_identical(nchar("f_dreissig_zeichen_lange_id_ab"), 30L)
  expect_identical(val_id_max_len("unit_groups"), 25L)
  expect_identical(val_generated_user_max("u_x_rent"), "25")
  expect_identical(val_generated_user_max("e_s_c_cost"), "12 / 20")
  expect_identical(val_generated_user_max("x_y"), "40")
})

test_that("Rohformen in Sammlungen: Wertgrammatik, Codes, Aliase, Termine", {
  v <- vofi_validate(wsb_with("domain", function(x) {
    x$measures$huelle$cost_eur <- list(value = 600, per = "m2_living_area")
    x$measures$huelle$modernization_kind <- "energetisch"
    x$measures$huelle$classification <- "erhalt"
    x$measures$huelle$completion_date <- "2028-06-01"
    x$measures$huelle$ohnehin_due_year <- 2040L
    x$unit_groups$a$rent_regime <- "staffel_x"
    x
  }))
  expect_setequal(v$path[v$code == "validation.enum"],
                  c("measures.huelle.classification", "unit_groups.a.rent_regime"))
  expect_match(v$message[v$path == "measures.huelle.classification"], "erhaltung", fixed = TRUE)
  expect_false(any(v$path == "measures.huelle.cost_eur"))
})

test_that("Ketten (8.9), Steuermodul (10.2), Kennzahlen", {
  sc <- example_scenario("skeleton")
  sc$accounts$surplus_order <- c("od_repay", "od_draw", "dep_invest")
  sc$accounts$deficit_order <- c("dep_withdraw", "equity_call", "od_draw")
  sc$tax$module <- "flatt"
  sc$analysis$kpis <- c("terminal_value", "endwert")
  v <- vofi_validate(sc)
  expect_true(all(c("validation.chain_role", "validation.chain_order",
                    "validation.tax_module_unknown", "validation.kpi_unknown") %in% v$code))
  expect_match(v$message[v$code == "validation.tax_module_unknown"], "flat|none")
  sc3 <- example_scenario("skeleton")
  sc3$accounts$surplus_order <- character(0)
  expect_true("validation.required" %in% vofi_validate(vofi_resolve(sc3))$code)
})

test_that("Overlay-Einstellungen: Prüffälle s1-s6 (Teil C 1.2)", {
  wsb_registry()
  with_set <- function(settings, n_keys = 1L) {
    pars <- list(k1 = list(target = "accounts.deposit_rate_pa", dist = "pert", min = 0.01,
                           mode = 0.02, max = 0.03))
    vofi_validate(wsb_with("skeleton", function(x) {
      x$stochastic <- list(settings = settings, parameters = pars)
      x
    }))
  }
  # (s1) 1000 Läufe in Blöcken zu 200: R = 5, Standardfehler grob
  v1 <- with_set(list(n_sim = 1000L))
  expect_identical(v1$code, "validation.stochastic.se_coarse")
  expect_match(v1$message, "5 Bl", fixed = TRUE)
  expect_identical(nrow(with_set(list(n_sim = 10000L))), 0L)
  # (s2) 1100 Läufe: Vorschlag 1000 oder 1200
  v2 <- with_set(list(n_sim = 1100L))
  hit <- v2$message[v2$code == "validation.stochastic.n_sim_not_multiple"]
  expect_match(hit, "1.000 oder 1.200", fixed = TRUE)
  # (s3) antithetic mit lhs
  expect_true("validation.stochastic.antithetic_lhs" %in%
                with_set(list(antithetic = TRUE, sampling = "lhs"))$code)
  expect_false("validation.stochastic.antithetic_lhs" %in%
                 with_set(list(antithetic = TRUE, sampling = "pseudo"))$code)
  # (s5) block_size und replicates zugleich; (s6) nur replicates: Hinweis F21-Modus
  expect_true("validation.stochastic.block_and_replicates" %in%
                with_set(list(block_size = 200L, replicates = 10L))$code)
  v6 <- with_set(list(replicates = 10L, n_sim = 1000L))
  expect_true("validation.stochastic.replicates_mode" %in% v6$code)
  expect_false("validation.stochastic.block_and_replicates" %in% v6$code)
  # Preset ohne n_sim: preview = 1000 Läufe
  expect_true("validation.stochastic.se_coarse" %in% with_set(list(preset = "preview"))$code)
})

test_that("Mindestblockgröße bei Korrelationsgruppen (s4, 1.7.3)", {
  wsb_registry()
  keys <- paste0("k", 1:12)
  pars <- stats::setNames(lapply(seq_along(keys), function(i) {
    list(target = paste0("market.m", i), dist = "pert", min = 0, mode = 0.01, max = 0.02)
  }), keys)
  pairs <- lapply(seq_len(11), function(i) list(keys[i], keys[i + 1L], 0.5))
  v <- vofi_validate(wsb_with("skeleton", function(x) {
    x$market <- stats::setNames(as.list(rep(0.01, 12)), paste0("m", 1:12))
    x$stochastic <- list(settings = list(block_size = 10L, n_sim = 1000L),
                         parameters = pars, correlations = list(parameters = pairs))
    x
  }))
  b <- v[v$code == "validation.stochastic.block_too_small", , drop = FALSE]
  expect_identical(nrow(b), 1L)
  expect_match(b$message, "mindestens 13", fixed = TRUE)
})

test_that("Bausteine der Prüfung: Werte in Roh- und Knotenform", {
  expect_identical(val_as_date("2027-01-01"), as.Date("2027-01-01"))
  expect_identical(val_as_date(2028L, year = TRUE), as.Date("2028-01-01"))
  expect_null(val_as_date(2028L))
  expect_null(val_as_date("bald"))
  expect_identical(val_num(node_const(2)), 2)
  expect_identical(val_num(list(kind = "series_t", values = c(1, 2))), c(1, 2))
  expect_null(val_num(node_ref("market.x")))
  expect_null(val_num("a"))
  expect_true(val_flag("ja"))
  expect_false(val_flag(node_const(0)))
  expect_true(is.na(val_flag("vielleicht")))
  expect_identical(val_interval(0, Inf, TRUE, FALSE), "(0, Inf]")
  expect_identical(val_interval(-0.01, 0.12, TRUE), "(-0.01, 0.12]")
  expect_identical(val_node_numbers(list(kind = "points", years = c(2027L, 2030L),
                                         values = list(node_const(1), node_ref("a.b")))), 1)
  q <- val_node_numbers(list(kind = "quantity", value = node_const(-3), per = "unit"))
  expect_true(isTRUE(attr(q, "lower_only")))
  expect_identical(val_node_numbers(list(kind = "schedule", unit = "share",
                                         dates = as.Date("2027-01-01"), amounts = 1)),
                   numeric(0))
  expect_null(val_codes("vocab:gibts_nicht"))
  expect_true("pv" %in% val_codes("measure_types"))
  expect_identical(val_overlay_meta("processes")[2L], "type")
  expect_identical(val_preset_n_sim("report"), 50000)
  expect_null(val_process_param_range(list(params = list()), "mu"))
  expect_identical(val_process_param_range(list(params = list()), "phi")$excl_lo, TRUE)
  expect_identical(val_process_fixed_params("fixed_path"), "*")
  expect_identical(val_corr_keys(list(list("a", "b", 0.5), list("b", "c", 0.1))),
                   c("a", "b", "c"))
})
