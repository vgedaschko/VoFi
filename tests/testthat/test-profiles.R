# Datentest von inst/extdata/defaults/global.yaml und den Perspektiven-Profilen (WS-A; Spec 00
# Abschnitte 4.2, 4.7, 4.9, R-76, R-85, R-97, R-104; Spec 01 Teil A 2.9 PR3, PR4, PR6, PR7,
# Teil B 7.1 d5).

profile_ids <- c("wu_kommunal", "wu_genossenschaft", "wu_privat", "kleinvermieter", "selbstnutzer")

#' Alle Bibliotheksverweise der Defaults-Dateien gegen eine Bibliothek auflösen (Modus error)
resolve_default_refs <- function(lib_paths) {
  lc <- lib_context(lib_index(lib_paths), prv_new(), mode = "error")
  files <- c(list(scn_defaults_load("global")),
             lapply(profile_ids, function(p) scn_defaults_load("profile", p)))
  ip <- scn_item_paths()
  for (d in files) {
    lib_resolve(d$tree, "", lc)
    for (code in names(d$bpt)) lib_resolve(d$bpt[[code]], "", lc)
    for (p in names(d$items)) {
      lib_resolve(d$items[[p]], if (p %in% ip$collections) paste0(p, ".{id}") else p, lc)
    }
    lib_resolve(list(scenario_sets = d$sets %||% list()), "", lc)
  }
  unique(vapply(lc$used, function(u) u$id, ""))
}

test_that("PR6: jede der fünf Profildateien lädt ohne Befund, Pfade nach R-76, defaults_meta", {
  expect_setequal(sub("\\.yaml$", "", list.files(system.file("extdata", "profiles",
                                                             package = "vofi"))),
                  profile_ids)
  for (p in profile_ids) {
    path <- scn_defaults_path("profile", p)
    raw <- io_read_yaml_utf8(path)
    expect_identical(scn_check_defaults(raw, "profile", basename(path)), list(), info = p)
    d <- scn_defaults_load("profile", p)
    expect_identical(d$meta$kind, "profile", info = p)
    expect_identical(d$meta$id, p, info = p)
    expect_identical(d$meta$schema_version, 1L, info = p)
    expect_s3_class(d$meta$as_of, "Date")
    expect_length(d$items, 0L)
    leaves <- scn_defaults_leaves(raw[setdiff(names(raw), scn_defaults_reserved())])
    expect_true(all(vapply(leaves, scn_profile_path_ok, logical(1))), info = p)
    expect_true(all(vapply(d$bpt, function(t) {
      all(vapply(scn_defaults_leaves(t), scn_profile_path_ok, logical(1)))
    }, logical(1))), info = p)
  }
})

test_that("PR6: Ausgleichsketten der Profile erfüllen die Kettenregeln (Spec 00 8.9)", {
  local_ws_a_library()
  for (p in profile_ids) {
    local_ws_a_schema()
    sc <- vofi_scenario(ws_a_scenario(perspective = p, horizon_years = 3L))
    v <- ws_a_quiet(vofi_validate(sc))
    expect_false(any(startsWith(v$code, "validation.chain")), info = p)
    spec <- ws_a_resolve(sc)
    expect_identical(spec$accounts$surplus_order[1], "od_repay", info = p)
    expect_identical(spec$accounts$deficit_order[1], "dep_withdraw", info = p)
    expect_identical(ws_a_prov(spec, "accounts.deficit_order")$entry, p, info = p)
  }
})

test_that("PR3: analysis.kpis: default bedeutet die Liste des Profils (Teil A 1.5, 2.1, 2.6)", {
  local_ws_a_library()
  dflt <- function(p) ws_a_scenario(perspective = p, analysis = list(kpis = "default"))
  spec <- ws_a_resolve(dflt("kleinvermieter"))
  kd <- spec$analysis$kpis
  expect_length(kd, 31L)
  expect_false("warm_rent" %in% kd)
  expect_true(all(c("monthly_net_cashflow", "restriction_liquidity",
                    "restriction_savings") %in% kd))
  pk <- ws_a_prov(spec, "analysis.kpis")
  expect_identical(c(pk$layer, pk$source_type, pk$entry, pk$file),
                   c("2", "profile", "kleinvermieter", "profiles/kleinvermieter.yaml"))
  expect_match(pk$location, "^Zeile [0-9]+$")
  expect_null(attr(spec, "kpis_default"))
  wu <- ws_a_resolve(dflt("wu_kommunal"))$analysis$kpis
  expect_length(wu, 37L)
  expect_true("warm_rent" %in% wu)
  expect_length(ws_a_resolve(dflt("selbstnutzer"))$analysis$kpis, 27L)
  # ohne Angabe im Szenario: Wert der Schicht 2 (Profil überschreibt "default" aus global.yaml)
  sc <- ws_a_scenario(perspective = "kleinvermieter")
  sc$analysis$kpis <- NULL
  expect_identical(ws_a_resolve(sc)$analysis$kpis, kd)
  # ausdrückliche Liste im Szenario gewinnt; "default" in einer Variante greift ebenfalls
  v_dflt <- list(v = list(set = list("analysis.kpis" = "default")))
  sc2 <- ws_a_scenario(perspective = "kleinvermieter", variants = v_dflt)
  expect_identical(ws_a_resolve(sc2)$analysis$kpis,
                   c("terminal_value", "terminal_value_opp", "delta_terminal_value"))
  expect_identical(ws_a_resolve(sc2, variant = "v")$analysis$kpis, kd)
  # ohne Profil (Perspektive unbekannt) bleibt "default" (Engine: alle Kennzahlen)
  expect_identical(scn_resolve_kpis_default(list(analysis = list(kpis = "default")),
                                            list2env(list(kpis_default = NULL)))$analysis$kpis,
                   "default")
})

test_that("PR4: Profil mit market.inflation ist ein Befund der Bibliothek (R-76)", {
  raw <- io_read_yaml_utf8(ws_a_lib("profiles", "forbidden_profile.yaml"))
  f <- scn_check_defaults(raw, "profile", "profiles/forbidden_profile.yaml")
  key <- scn_key("validation.profile_path_forbidden", "io.defaults.profile_path",
                 path = "", file = "", allowed = "")
  hit <- Filter(function(x) identical(x$code, key), f)
  expect_true(length(hit) >= 1L)
  expect_true("market.inflation" %in% vapply(hit, function(x) x$path, ""))
  msg <- do.call(lbl, c(list(hit[[1]]$code), hit[[1]]$args))
  expect_match(msg, "accounts.*", fixed = TRUE)
  expect_true(scn_profile_path_ok("accounts.deposit_rate_pa"))
  expect_true(scn_profile_path_ok("scenario_sets.vorsichtig.label"))
  expect_true(scn_profile_path_ok("residual_value.method"))
  expect_false(scn_profile_path_ok("residual_value.income_value.cap_rate"))
  expect_false(scn_profile_path_ok("unit_groups.a.vacancy_rate"))
  expect_false(scn_profile_path_ok("project.valuation_date"))
})

test_that("PR7: global.yaml: Blöcke, Sets, Einstellungen, item_defaults (Teil A 2.2, C 4.2)", {
  path <- scn_defaults_path("global")
  raw <- io_read_yaml_utf8(path)
  expect_identical(scn_check_defaults(raw, "global", "defaults/global.yaml"), list())
  g <- scn_defaults_load("global")
  expect_identical(g$meta$kind, "global")
  expect_identical(g$meta$id, "global")
  expect_true(all(c("project", "grid", "accounts", "market", "shared", "residual_value", "tax",
                    "analysis", "stochastic") %in% names(g$tree)))
  expect_false(any(c("building", "household", "energy") %in% names(raw)))       # N-05
  st <- raw$stochastic$settings
  expect_identical(st$preset, "standard")
  expect_identical(st$block_size, 200)
  expect_null(st$n_sim)
  expect_null(st$replicates)
  expect_identical(st$seed, 20261025)
  ip <- scn_item_paths()
  expect_true(all(names(raw$item_defaults) %in% c(ip$collections, ip$blocks)))
  expect_true(all(c("building", "measures", "building.elements", "unit_groups", "energy",
                    "energy.carriers", "energy.performance_gap", "energy.pv", "funding",
                    "building.property_tax", "household") %in% names(raw$item_defaults)))
  b <- raw$item_defaults$building
  expect_identical(b$maintenance$enabled, TRUE)
  expect_identical(b$building_id, "b1")
  expect_identical(raw$item_defaults$energy.carriers$price_eur_kwh$ref, "market.energy_price.{id}")
  expect_identical(raw$item_defaults$funding$availability_after_2030, 0.7)
  expect_length(raw$item_defaults$energy$performance_gap, 0L)
  expect_true(is.list(raw$item_defaults$energy$performance_gap))
  sets <- names(raw$scenario_sets)
  expect_true(all(c("foerderstopp", "vorsichtig", "zinsschock", "zins_niedrig", "stress_2022",
                    "co2_niedrig", "co2_hoch", "gasnetz_rueckbau", "mit_2045_stufe") %in% sets))
  expect_identical(raw$scenario_sets$foerderstopp$set[["funding.*.approved"]], 0)
  expect_identical(raw$scenario_sets$vorsichtig$generate$n_drivers, 5)
  expect_identical(raw$by_project_type$neubau$project$horizon_years, 40)
  expect_identical(raw$by_project_type$erwerb_neubau$project$horizon_years, 40)
  expect_identical(raw$accounts$deficit_order[4], "equity_call")
  expect_identical(raw$analysis$kpis, "default")
  expect_identical(raw$tax$module, "none")
  # d5: veralteter Wurzelschlüssel ist ein Befund
  bad <- io_read_yaml_utf8(ws_a_lib("defaults", "global_bad.yaml"))
  codes <- vapply(scn_check_defaults(bad, "global", "x"), function(x) x$code, "")
  expect_true("validation.unknown_key" %in% codes)
})

test_that("PR7: jeder from/use-Verweis der Defaults löst gegen die Testbibliothek auf (R-104)", {
  local_ws_a_library()
  used <- resolve_default_refs(vofi_library_paths())
  expect_true(all(c("prices/macro_paths_2026", "prices/interest_rates_2026_10",
                    "prices/energy_prices_2026", "prices/co2_price_paths_2026",
                    "prices/eeg_feed_in_2026", "costs/bewirtschaftung_immowertv_2026",
                    "costs/bewirtschaftung_ii_bv_2026", "valuation/verkaufskosten_2026",
                    "valuation/liegenschaftszinsen_2026", "valuation/immowertv_anlage1_2_2026",
                    "valuation/kaufpreisfaktoren_2026") %in% used))
  spec <- ws_a_resolve(ws_a_scenario())
  expect_true(all(c("gas", "gas_mfh", "oil", "lpg", "power", "power_mfh", "heatpump_power",
                    "heatpump_power_mfh", "district_heating", "pellets") %in%
                    names(spec$market$energy_price)))                                  # N-15
  expect_identical(spec$residual_value$sale_cost_share, node_const(0.03))
})

test_that("PR7: jeder from/use-Verweis löst gegen die Paketbibliothek auf (WS-L)", {
  root <- system.file("extdata", "library", package = "vofi")
  n <- if (nzchar(root)) length(list.files(root, pattern = "\\.ya?ml$", recursive = TRUE)) else 0L
  skip_if(n == 0L, paste("Paketbibliothek inst/extdata/library ist noch leer",
                         "(Lieferung WS-L, Welle 3); Prüfung gegen die Testbibliothek oben"))
  used <- resolve_default_refs(vofi_library_paths())
  expect_true(length(used) > 0L)
  expect_true("costs/bewirtschaftung_ii_bv_2026" %in% used)                           # N-02
  spec <- suppressWarnings(suppressMessages(vofi_resolve(vofi_scenario(ws_a_scenario()))))
  expect_true(all(c("gas", "gas_mfh", "oil", "lpg", "power", "power_mfh", "heatpump_power",
                    "heatpump_power_mfh", "district_heating", "pellets") %in%
                    names(spec$market$energy_price)))
})

test_that("A-11: das Schema kennt alle Felder der Defaults und Regeln (Brücke entfallen)", {
  local_ws_a_library()
  # Seit der Integration von WS-B gibt es keine Schemabrücke mehr: das ungepatchte Schema muss
  # jedes Feld aus global.yaml, den Profilen und den Ableitungsregeln kennen.
  # ws_a_extra_fields() vergleicht mit der Sicht val_domain_schema() (ohne freie Maps und
  # Sequenzen); was dort fehlt, muss im vollständigen Katalog stehen (z. B. tax.params)
  extra <- ws_a_extra_fields()
  catalog <- val_schema_catalog()
  for (b in names(extra)) {
    expect_true(all(extra[[b]] %in% names(catalog[[b]])), info = paste(b, utl_collapse(extra[[b]])))
  }
  sc <- vofi_scenario(ws_a_scenario(
    building = list(construction_year = 1972L, living_area_m2 = 800),
    measures = list(wp = list(measure_type = "heizung_waermepumpe_luft", year = 2028,
                              cost_eur = 30000))
  ))
  v <- ws_a_quiet(vofi_validate(sc))
  uf <- v$path[v$code == "validation.unknown_field"]
  covered <- vapply(uf, function(p) {
    segs <- path_split(p)
    any(vapply(seq_along(segs)[-1L], function(k) {
      segs[k] %in% extra[[paste(segs[seq_len(k - 1L)], collapse = ".")]]
    }, logical(1)))
  }, logical(1))
  expect_true(all(covered), info = utl_collapse(uf[!covered]))
  expect_length(uf, 0L)                                     # Schema von WS-B: keine Brücke
})
