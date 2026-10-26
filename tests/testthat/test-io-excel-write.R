# Tests für R/io-excel-write.R (WS-A2; Spec 00 Abschnitte 4.6, 4.14): exakte Zahlen,
# Flussnotation, Anführungszeichen, Rückfallkodierungen, Zeitreihen, Zellformate.

mini <- function(...) {
  base <- list(
    schema_version = 1L,
    meta = list(scenario_id = "mini", title = "Mini"),
    project = list(perspective = "wu_privat", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 2L),
    components = list(z = list(type = "custom_series", values = c(-100, 50, 60))),
    financing = list(ek = list(type = "equity", amount_eur = 100))
  )
  extra <- list(...)
  for (nm in names(extra)) base[[nm]] <- extra[[nm]]
  vofi_scenario(base)
}

test_that("Zahlen: kürzeste exakte Darstellung, Inf und NaN als Text", {
  vals <- c(0.1 + 0.2, 1 / 3, pi, 1e300, 5e-324, 123456789.123456789, -0.5, 7.125, 1e-17, 3e9,
            2^60, -1e-300)
  for (v in vals) expect_identical(as.double(io_xl_num_text(v)), v, info = format(v, digits = 17))
  expect_identical(io_xl_cell_num(Inf), list(t = "str", v = ".inf"))
  expect_identical(io_xl_cell_num(-Inf), list(t = "str", v = "-.inf"))
  expect_identical(io_xl_cell_num(NaN), list(t = "str", v = ".nan"))
  expect_null(io_xl_cell_num(NA_real_))
  expect_identical(io_xl_cell_date(as.Date("2027-01-01"))$v, 46388)
  # Zahlenzellen werden exakt geschrieben und gelesen (Seriennummern und volle Genauigkeit)
  f <- xl_tempfile()
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "S")
  io_xl_write_column(wb, "S", 1L, c(list(io_xl_cell_str("k")), lapply(vals, io_xl_cell_num)),
                     1L)
  openxlsx::saveWorkbook(wb, f)
  g <- io_xl_read_grid(f, "S")
  expect_identical(g$num[-1L, 1L], vals)
})

test_that("Flussnotation: verlustfrei zurückgelesen (Handler aus 4.6)", {
  vals <- list("a", "a b", "123", "true", "yes", "~", "", "x: y", "\"q\"", "ä €",
               "zeile\nzwei\tTab", "back\\slash", "market.energy_price.gas", "funding.*.approved",
               0.1 + 0.2, 1e-17, 3e9, -0.5, Inf, -Inf, TRUE, c(1, 2.5), c("a", "b"), list(),
               structure(list(), names = character(0)), list(a = 1, b = list(c = "d")),
               list(1, "a"), list("2027" = 0.02), list(`a.b` = 1), NULL)
  for (v in vals) {
    txt <- io_xl_flow(v)
    back <- io_unmark(yaml::yaml.load(txt, handlers = io_yaml_handlers(), eval.expr = FALSE))
    expect_identical(back, v, info = txt)
  }
  expect_identical(io_xl_flow(as.Date("2027-01-01")), "\"2027-01-01\"")
  expect_identical(io_xl_flow(node_ref("market.x", scale = 2)), "{ref: market.x, scale: 2}")
  expect_identical(io_xl_flow_str(c("abc", "a b", "true", "1x", "x.")),
                   c("abc", "\"a b\"", "\"true\"", "\"1x\"", "\"x.\""))
  expect_identical(io_xl_options_text(list(scale = 2, "a b" = "c")), "scale: 2, \"a b\": c")
})

test_that("Anführungszeichen: nur wo der Leser sonst anders deutet", {
  num <- NULL
  str <- vofi_param("string")
  expect_true(io_xl_needs_quote("", str))
  expect_true(io_xl_needs_quote(" ~ ", str))
  expect_true(io_xl_needs_quote("{x}", str))
  expect_true(io_xl_needs_quote("[x]", str))
  expect_true(io_xl_needs_quote("'x'", str))
  expect_false(io_xl_needs_quote("123", str))
  expect_true(io_xl_needs_quote("123", num))
  expect_true(io_xl_needs_quote("3,5 %", num))
  expect_true(io_xl_needs_quote(".inf", num))
  expect_false(io_xl_needs_quote("abc", num))
  expect_true(io_xl_needs_quote("01.07.2028", vofi_param("date")))
  expect_false(io_xl_needs_quote("2028-07-01", vofi_param("date")))
  lst <- "enum:perspective"
  lab <- io_xl_list(lst)$label[1L]
  expect_true(io_xl_needs_quote(lab, vofi_param("enum", values = "vocab:perspective"), lst))
})

test_that("Rückfall auf YAML-Flussnotation erhält ungewöhnliche Strukturen exakt", {
  sc <- mini(
    market = list(a = 0.02, b = list(ref = "market.a", scale = 2)),
    shared = list(t1 = "123", t2 = "~", t3 = "{x}", t4 = "", t5 = "TRUE", t6 = "Zitat \"a\"\n2"),
    components = list(
      z = list(type = "custom_series", values = c(-100, 50, 60), label = "123"),
      w = list(type = "recurring", amount_eur = 5, label = "~", description = "[keine Liste]")
    ),
    variants = list(
      v = list(label = "V", set = list("market.a" = list(scale = 2, ref = "market.b"),
                                       "market.b" = NULL)),
      w = list(label = "W", remove = list(), overrides = list(market = list(a = list()))),
      x = list(set = list("market.a" = 0.03), label = 42, foo = list(bar = 1))
    ),
    scenario_sets = list(s = list(label = "S", set = list("funding.*.approved" = 0))),
    stochastic = list(
      parameters = list(p = list(dist = "pert", target = "market.a", min = 0, mode = 0.02,
                                 max = 0.05, extra_field = list(a = 1)),
                        q = list(target = "market.a", dist = "unbekannt", par = 1)),
      processes = list(r = list(type = "ar1", target = "market.a", mu = 0.02, phi = 0.5,
                                sigma = list(dist = "uniform", min = 0.01, max = 0.02))),
      correlations = list(parameters = list(c("p", "q")), shocks = list())
    ),
    projekt = list(x = 1)
  )
  f <- xl_tempfile()
  vofi_write_scenario(sc, f)
  back <- vofi_read_scenario(f)
  expect_xl_identical(back, sc)
  expect_identical(back$projekt, list(x = 1))
  expect_identical(back$variants$v$set[["market.a"]], list(scale = 2, ref = "market.b"))
  expect_true("market.b" %in% names(back$variants$v$set))
  expect_identical(back$variants$w$remove, list())
  expect_identical(back$shared$t1, "123")
  expect_identical(back$shared$t4, "")
})

test_that("Elemente ohne Felder, explizite NULL, Schlüssel mit Punkt, Typen als Bezeichnung", {
  sc <- mini(
    measures = list(leer = structure(list(), names = character(0))),
    project = list(perspective = "wu_privat", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 2L,
                   municipality = list(milieuschutz = NULL)),
    funding = list(f = list(
      label = NULL, approved = 1,
      eligibility = list(conditions = list(`unit.owner_occupied` = TRUE))
    )),
    components = list(z = list(type = "custom_series", values = c(-100, 50, 60),
                               category = "other_cost", id = "z"))
  )
  f <- xl_tempfile()
  vofi_write_scenario(sc, f)
  back <- vofi_read_scenario(f)
  expect_xl_identical(back, sc)
  fin <- xl_read_sheet(f, lbl("excel_input.sheets.financing"))
  types <- io_xl_list("types:financing")
  expect_identical(fin[[2L]][3L], types$label[types$code == "equity"])
})

test_that("Zeitreihen: Spalten je Jahr, Periode und Termin; Formen ohne Spalte als YAML", {
  sc <- mini(
    market = list(
      a = list(series = list("2027" = 0.02, "2030" = 0.03), fill = "linear"),
      b = list(years = c(2026, 2030), values = list(60, list(ref = "shared.c")),
               interpolate = "step"),
      d = list(schedule = list("2027-07-01" = 1, "2028-01-01" = 2)),
      e = list(schedule = list("2029-01-01" = 1, "2028-01-01" = 2)),
      g = list(start = 0.06, growth = list(series = list("2027" = 0.01)), index = "period_end"),
      h = list(value = 3, per = "m2_living_area")
    ),
    shared = list(c = 100)
  )
  f <- xl_tempfile()
  vofi_write_scenario(sc, f)
  back <- vofi_read_scenario(f)
  expect_xl_identical(back, sc)
  z <- xl_read_sheet(f, lbl("excel_input.sheets.series"))
  keys <- unlist(z[1L, ], use.names = FALSE)
  expect_identical(keys[-(1:5)], c("2026", "2027", "2027-07-01", "2028", "2030", "t0", "t1",
                                   "t2"))
  expect_identical(z[[1L]][-(1:2)], c("market.a", "market.b", "market.d", "components.z.values"))
  # unsortierter Zahlungsplan bleibt in der Zelle (YAML), Wachstum mit Reihe als Option
  mk <- xl_read_sheet(f, lbl("excel_input.sheets.market"))
  expect_match(mk[[5L]][mk[[1L]] == "market.e"], "^\\{schedule:")
  expect_match(mk[[6L]][mk[[1L]] == "market.g"], "growth: \\{series:")
})

test_that("Fehler beim Schreiben: kein Baum, nicht schreibbarer Pfad", {
  expect_error(io_write_excel(1, tempfile(fileext = ".xlsx")), class = "vofi_error_input")
  sc <- mini()
  e <- expect_error(vofi_write_scenario(sc, file.path(withr::local_tempdir(), "nein", "x.xlsx")),
                    class = "vofi_error_input")
  expect_identical(e$key, "excel_input.write_failed")
})

test_that("Zerlegung in Blätter und Einordnung in die Vorlagenzeilen", {
  x <- list(a = 1, b = list(c = 2, d = list()), e = list(ref = "market.x"),
            f = list(`g.h` = 1), i = NULL)
  lv <- io_xl_leaves(x, "market")
  expect_identical(vapply(lv, function(l) l$path, ""),
                   c("market.a", "market.b.c", "market.b.d", "market.e", "market.f",
                     "market.i"))
  expect_true(io_xl_is_leaf(list(from = "funding/x", use = "y"), "market.k"))
  expect_false(io_xl_is_leaf(list(from = "funding/x", amount_eur = 1), "funding.k"))
  tmpl <- list(list(path = "energy", header = TRUE),
               list(path = "energy.carriers", header = TRUE),
               list(path = "energy.carriers.*.vat_rate", header = FALSE),
               list(path = "energy.before", header = TRUE),
               list(path = "energy.before.demand_kwh", header = FALSE))
  rows <- io_xl_place_leaves(tmpl, list(list(path = "energy.before.demand_kwh", value = 1),
                                        list(path = "energy.carriers.gas.vat_rate", value = 0.19),
                                        list(path = "energy.foo", value = 2)))
  expect_identical(vapply(rows, function(r) r$path, ""),
                   c("energy", "energy.carriers", "energy.carriers.*.vat_rate",
                     "energy.carriers.gas.vat_rate", "energy.before",
                     "energy.before.demand_kwh", "energy.foo"))
  expect_identical(vapply(rows, function(r) r$seq, integer(1)),
                   c(NA, NA, NA, 2L, NA, 1L, 3L))
  expect_identical(io_xl_star_path("energy.carriers.gas.vat_rate"), "energy.carriers.*.vat_rate")
  expect_identical(io_xl_star_path("measures.wp.cost_eur"), "measures.*.cost_eur")
  expect_identical(io_xl_star_path("project.horizon_years"), "project.horizon_years")
})
