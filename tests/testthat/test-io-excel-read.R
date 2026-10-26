# Tests für R/io-excel-read.R (WS-A2; Spec 00 Abschnitte 4.6, 4.8, 4.14, R-26): von Hand
# angelegte Arbeitsmappen, Zahlen- und Textregeln, Fundstellen in Meldungen, Fehlerfälle.

sheet <- function(role) lbl(paste0("excel_input.sheets.", role))

kv_book <- function(rows, role = "project", extra = list(), path = NULL) {
  path <- path %||% tempfile(fileext = ".xlsx")
  sheets <- c(stats::setNames(list(xl_kv_sheet(rows)), sheet(role)), extra)
  xl_make_book(sheets, path)
}

read_quiet <- function(path) suppressWarnings(suppressMessages(vofi_read_scenario(path)))

test_that("von Hand angelegte Arbeitsmappe des Skeletts rechnet wie die YAML-Datei", {
  fin_types <- io_xl_list("types:financing")
  forms <- io_xl_list("forms")
  persp <- io_xl_list("enum:perspective")
  f <- xl_tempfile()
  projekt <- xl_kv_sheet(list(
    list("schema_version", 1),
    list("meta.scenario_id", "skeleton"),
    list("meta.title", "Gerüst: Minimalszenario"),
    list("project.perspective", persp$label[persp$code == "wu_privat"]),
    list("project.project_type", "neubau"),
    list("project.valuation_date", as.Date("2027-01-01")),
    list("project.horizon_years", xl_text("3")),
    list("accounts.deposit_rate_pa", 0.02),
    list("accounts.overdraft_rate_pa", 0.08),
    list("accounts.overdraft_limit_eur", ".inf"),
    list("accounts.surplus_order", "od_repay, dep_invest"),
    list("accounts.deficit_order", "dep_withdraw, od_draw, equity_call"),
    list("analysis.kpis", "terminal_value, terminal_value_opp, delta_terminal_value")
  ))
  finanz <- list(
    list(".id", "type", "amount_eur", "rate_pa", "term_years", "payments_per_year"),
    list("id", "Typ", "Betrag", "Zins", "Laufzeit", "Zahlungen"),
    list("ek", fin_types$label[fin_types$code == "equity"], 40000),
    list("bank", "bullet_loan", 60000, 0.05, 3, 1)
  )
  komp <- list(
    as.list(io_xl_fixed_columns("components")), list("id"),
    list("z", "custom_series", "label", NULL, NULL, NULL, "Zahlungsfolge"),
    list(NULL, NULL, "values", NULL, NULL, forms$label[forms$code == "series_t"], "z_werte")
  )
  zeit <- list(
    c(as.list(io_xl_fixed_columns("series")), list("t0", "t1", "t2", "t3")),
    list("id"),
    list("z_werte", NULL, "series_t", NULL, NULL, -100000, 30000, 40000, 50000)
  )
  sheets <- list(projekt, finanz, komp, zeit)
  names(sheets) <- c(sheet("project"), sheet("financing"), sheet("components"), sheet("series"))
  xl_make_book(sheets, f)
  sc <- vofi_read_scenario(f)
  ref <- vofi_read_scenario(vofi_example("skeleton"))
  expect_identical(sc$project$perspective, "wu_privat")
  expect_identical(sc$project$horizon_years, 3L)
  expect_identical(sc$financing$ek$type, "equity")
  expect_identical(sc$accounts$surplus_order, c("od_repay", "dep_invest"))
  expect_identical(sc$components$z$values, ref$components$z$values)
  for (b in c("meta", "accounts", "analysis")) {
    expect_identical(sc[[b]][order(names(sc[[b]]))], ref[[b]][order(names(ref[[b]]))], info = b)
  }
  res <- xl_quiet_run(sc)
  expect_equal(res$kpis$terminal_value, 52830.80, tolerance = 1e-8)
  expect_equal(res$kpis$terminal_value_opp, 42448.32, tolerance = 1e-8)
  expect_equal(res$kpis$delta_terminal_value, 10382.48, tolerance = 1e-8)
  expect_true(all(res$checks$ok))
  prov <- attr(sc, "provenance")
  expect_identical(prov$location[prov$path == "financing.bank.rate_pa"],
                   paste0(sheet("financing"), "!D4"))
  expect_identical(prov$location[prov$path == "components.z.values"],
                   paste0(sheet("components"), "!G4"))
})

test_that("Zahlen als Text: Regeln aus 4.6 mit Blatt und Zelle in der Meldung", {
  f <- kv_book(list(list("market.a", xl_text("3,5")), list("market.b", xl_text("3,5 %")),
                    list("market.c", xl_text("1.234.567")), list("market.d", xl_text("0.039"))),
               role = "market")
  acc <- new.env(parent = emptyenv())
  acc$w <- NULL
  sc <- withCallingHandlers(suppressMessages(vofi_read_scenario(f)),
                            vofi_warning_input = function(cond) {
                              acc$w <- c(acc$w, conditionMessage(cond))
                              invokeRestart("muffleWarning")
                            })
  w <- acc$w
  expect_identical(sc$market$a, node_const(3.5))
  expect_identical(sc$market$b, node_const(0.035))
  expect_identical(sc$market$c, node_const(1234567))
  expect_identical(sc$market$d, node_const(0.039))
  expect_length(w, 2L)
  expect_true(any(grepl(paste0("Excel: ", sheet("market"), "!E3"), w, fixed = TRUE)))
  expect_true(any(grepl(paste0("Excel: ", sheet("market"), "!E4"), w, fixed = TRUE)))
  # Tausenderpunkt bei EUR als Text: Fehler mit Zelle; als Zahlenzelle eindeutig
  f2 <- kv_book(list(list("accounts.min_liquidity_eur", xl_text("150.000"))))
  e <- expect_error(vofi_read_scenario(f2), class = "vofi_error_input")
  expect_identical(e$key, "io.thousands_eur")
  expect_match(conditionMessage(e), paste0(sheet("project"), "!E3"), fixed = TRUE)
  expect_identical(e$data$location, paste0(sheet("project"), "!E3"))
  f3 <- kv_book(list(list("accounts.min_liquidity_eur", 150.5), list("meta.title", "x"),
                     list("accounts.overdraft_limit_eur", 7.125)))
  sc3 <- vofi_read_scenario(f3)
  expect_identical(sc3$accounts$overdraft_limit_eur, node_const(7.125))
  # Rate über 1: Fehler der Normalisierung mit Zelle
  f4 <- kv_book(list(list("meta.title", "x"), list("accounts.deposit_rate_pa", 3.9)))
  e4 <- expect_error(vofi_read_scenario(f4), class = "vofi_error_input")
  expect_identical(e4$key, "io.rate_above_one")
  expect_match(conditionMessage(e4), paste0(sheet("project"), "!E4"), fixed = TRUE)
})

test_that("Datum, Wahrheitswerte, Codes, Listen, NULL, Anführungszeichen, YAML in der Zelle", {
  persp <- io_xl_list("enum:perspective")
  forms <- io_xl_list("forms")
  f <- kv_book(list(
    list("project.valuation_date", xl_text("01.01.2027")),
    list("project.application_date", xl_text("2026-12-01")),
    list("project.perspective", persp$label[persp$code == "selbstnutzer"]),
    list("project.project_type", "sanierung_eh"),
    list("project.municipality.milieuschutz", "ja"),
    list("project.municipality.kappung_15_area", TRUE),
    list("project.municipality.mietpreisbremse_until", "~"),
    list("meta.tags", "a, b_c"),
    list("meta.title", "\"123\""),
    list("market.x", 0.02),
    list("market.y", "{ref: market.x, scale: 2}"),
    list("market.z", "market.x", forms$label[forms$code == "ref"], "offset: 0.01"),
    list("market.w", "market.x * 2", "expr"),
    list("market.v", 7.2, "growth", "growth: {ref: market.x}"),
    list("market.u", "[1, 2.5, 3]"),
    list("shared.code", "\"auto\"")
  ))
  sc <- vofi_read_scenario(f)
  expect_identical(sc$project$valuation_date, as.Date("2027-01-01"))
  expect_identical(sc$project$application_date, as.Date("2026-12-01"))
  expect_identical(sc$project$perspective, "selbstnutzer")
  expect_true(sc$project$municipality$milieuschutz)
  expect_true(sc$project$municipality$kappung_15_area)
  expect_true("mietpreisbremse_until" %in% names(sc$project$municipality))
  expect_null(sc$project$municipality$mietpreisbremse_until)
  expect_identical(sc$meta$tags, c("a", "b_c"))
  expect_identical(sc$meta$title, "123")
  expect_identical(sc$market$y$kind, "ref")
  expect_identical(sc$market$y$scale, 2)
  expect_identical(sc$market$z$path, "market.x")
  expect_identical(sc$market$z$offset, 0.01)
  expect_identical(sc$market$w$kind, "expr")
  expect_identical(sc$market$v$kind, "growth")
  expect_identical(sc$market$v$growth$path, "market.x")
  expect_identical(sc$market$u$kind, "series_t")
  expect_identical(sc$shared$code, "auto")
})

test_that("breite und lange Blätter ohne interne Spalten; Zeitreihen-Kopf aus Zeile 2", {
  f <- xl_tempfile()
  mass <- list(
    list(".id", "measure_type", "year", "cost_eur", "payment_schedule"),
    list("id"),
    list("wp", "heizung_waermepumpe_luft", 2028, 126000),
    list("plan", "aussenanlagen", NULL, NULL, "{timeseries: plan_zp}")
  )
  zeit <- list(
    c(as.list(io_xl_fixed_columns("series")), list(NULL, NULL)),
    c(list("id", NULL, NULL, NULL, NULL), list("2028", "01.07.2029")),
    list("plan_zp", NULL, "schedule", NULL, "unit: eur", 1000, 2000)
  )
  proz <- list(
    as.list(io_xl_fixed_columns("processes")), list("id"),
    list("zins", "market.mortgage_rate", "vasicek", "r0", NULL, 0.04),
    list(NULL, NULL, NULL, "sigma", NULL, 0.01)
  )
  sheets <- list(mass, zeit, proz)
  names(sheets) <- c(sheet("measures"), sheet("series"), sheet("processes"))
  xl_make_book(sheets, f)
  sc <- vofi_read_scenario(f)
  expect_identical(names(sc$measures), c("wp", "plan"))
  expect_identical(sc$measures$wp$year, 2028L)
  expect_identical(sc$measures$wp$cost_eur, node_const(126000))
  ps <- sc$measures$plan$payment_schedule
  expect_identical(ps$kind, "schedule")
  expect_identical(ps$dates, as.Date(c("2028-01-01", "2029-07-01")))
  expect_identical(ps$amounts, c(1000, 2000))
  expect_identical(sc$stochastic$processes$zins,
                   list(target = "market.mortgage_rate", type = "vasicek", r0 = 0.04, sigma = 0.01))
})

test_that("Auswahllisten der Datei übersetzen veraltete Bezeichnungen; Rolle als Blattname", {
  f <- xl_tempfile()
  listen <- list(list("enum:perspective", "enum:perspective#label"), list("Code", "Liste"),
                 list("wu_privat", "Alte Bezeichnung WU"))
  sheets <- list(xl_kv_sheet(list(list("project.perspective", "Alte Bezeichnung WU"))), listen)
  names(sheets) <- c("project", sheet("lists"))
  xl_make_book(sheets, f)
  expect_identical(vofi_read_scenario(f)$project$perspective, "wu_privat")
})

test_that("Fehler nennen Blatt und Zelle: Pfade, ids, Wertformen, YAML, Zeitreihen", {
  err <- function(rows, key, role = "project", extra = list()) {
    f <- kv_book(rows, role = role, extra = extra)
    e <- expect_error(vofi_read_scenario(f), class = "vofi_error_input")
    expect_identical(e$key, key)
    e
  }
  e <- err(list(list("energy.carriers.*.vat_rate", 0.19)), "excel_input.placeholder_path")
  expect_match(conditionMessage(e), paste0(sheet("project"), "!A3"), fixed = TRUE)
  err(list(list("market.x", 1), list("market.x.y", 2)), "excel_input.path_conflict",
      role = "market")
  err(list(list("market.x", 1), list("market.x", 2)), "excel_input.path_duplicate",
      role = "market")
  e <- err(list(list("market.x", "{a: [1, 2}")), "excel_input.yaml_invalid", role = "market")
  expect_match(conditionMessage(e), paste0(sheet("market"), "!E3"), fixed = TRUE)
  err(list(list("market.x", "a", "nicht_da")), "excel_input.form_unknown", role = "market")
  err(list(list("market.x", 1, NULL, "scale: 2")), "excel_input.options_without_form",
      role = "market")
  err(list(list("market.x", NULL, "ref")), "excel_input.form_value_missing", role = "market")
  err(list(list("market.x", "fehlt", "series_year")), "excel_input.series_missing",
      role = "market")
  err(list(list(NULL, 5)), "excel_input.path_missing")
  zeit <- list(c(as.list(io_xl_fixed_columns("series")), list("t0", "t2")), list("id"),
               list("lu", NULL, "series_t", NULL, NULL, 1, 2))
  err(list(list("market.x", "lu", "series_t")), "excel_input.series_gap", role = "market",
      extra = stats::setNames(list(zeit), sheet("series")))
  zeit2 <- list(c(as.list(io_xl_fixed_columns("series")), list("t0", "t0")), list("id"),
                list("lu", NULL, "series_t", NULL, NULL, 1, 2))
  e <- err(list(list("market.x", "lu", "series_t")), "excel_input.series_key_duplicate",
           role = "market", extra = stats::setNames(list(zeit2), sheet("series")))
  expect_match(conditionMessage(e), "'t0'", fixed = TRUE)
  wide <- list(list(".id", "label"), list("id"), list("a", "A"), list("a", "B"))
  err(list(list("meta.title", "x")), "excel_input.duplicate_id",
      extra = stats::setNames(list(wide), sheet("unit_groups")))
  wide2 <- list(list(".id", "label"), list("id"), list(NULL, "ohne id"))
  err(list(list("meta.title", "x")), "excel_input.id_missing",
      extra = stats::setNames(list(wide2), sheet("unit_groups")))
  long <- list(as.list(io_xl_fixed_columns("components")), list("id"),
               list("z", "custom_series", NULL, NULL, NULL, NULL, 5))
  err(list(list("meta.title", "x")), "excel_input.param_missing",
      extra = stats::setNames(list(long), sheet("components")))
  nokey <- list(list("path", "label"), list("x"), list("meta.title", "t"))
  f <- xl_tempfile()
  xl_make_book(stats::setNames(list(nokey), sheet("project")), f)
  e <- expect_error(vofi_read_scenario(f), class = "vofi_error_input")
  expect_identical(e$key, "excel_input.column_missing")
})

test_that("Datei- und Mappenfehler, unbenutzte Zeitreihen, neuere Vorlagenversion", {
  txt <- withr::local_tempfile(fileext = ".xlsx")
  writeLines("a: 1", txt)
  e <- expect_error(vofi_read_scenario(txt), class = "vofi_error_input")
  expect_identical(e$key, "excel_input.read_failed")
  f <- xl_tempfile()
  xl_make_book(list(Notizen = list(list("x"))), f)
  e <- expect_error(vofi_read_scenario(f), class = "vofi_error_input")
  expect_identical(e$key, "excel_input.no_sheets")
  f2 <- xl_tempfile()
  sheets <- list(xl_kv_sheet(list(list("meta.title", "a"))),
                 xl_kv_sheet(list(list("meta.title", "b"))))
  names(sheets) <- c(sheet("project"), "project")
  xl_make_book(sheets, f2)
  e <- expect_error(vofi_read_scenario(f2), class = "vofi_error_input")
  expect_identical(e$key, "excel_input.sheet_duplicate")
  zeit <- list(c(as.list(io_xl_fixed_columns("series")), list("2027")), list("id"),
               list("frei", NULL, "series_year", NULL, NULL, 0.02))
  meta <- list(as.list(io_xl_fixed_columns("meta")), list("k"),
               list("template_version", io_xl_template_version() + 1))
  f3 <- kv_book(list(list("meta.title", "x")),
                extra = stats::setNames(list(zeit, meta), c(sheet("series"), sheet("meta"))))
  expect_message(
    expect_warning(vofi_read_scenario(f3), class = "vofi_warning_input"),
    class = "vofi_message"
  )
})

test_that("leere Vorlage ergibt ein leeres Szenario mit schema_version", {
  f <- xl_tempfile()
  vofi_excel_template(f, overwrite = TRUE)
  sc <- vofi_read_scenario(f)
  expect_s3_class(sc, "vofi_scenario")
  expect_identical(sc$schema_version, 1L)
  expect_length(sc$components, 0L)
  expect_length(sc$project, 0L)
})

test_that("Zellarten: Zahlen- und Textzellen in gemischten Spalten werden unterschieden", {
  f <- xl_tempfile()
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "S")
  openxlsx::writeData(wb, "S", "k", startRow = 1L, startCol = 1L)
  openxlsx::writeData(wb, "S", 7.125, startRow = 2L, startCol = 1L)
  openxlsx::writeData(wb, "S", "7.125", startRow = 3L, startCol = 1L)
  openxlsx::writeData(wb, "S", TRUE, startRow = 4L, startCol = 1L)
  openxlsx::writeData(wb, "S", "TRUE", startRow = 5L, startCol = 1L)
  openxlsx::writeData(wb, "S", "x", startRow = 6L, startCol = 1L)
  openxlsx::writeData(wb, "S", "123", startRow = 1L, startCol = 3L)
  openxlsx::saveWorkbook(wb, f)
  g <- io_xl_read_grid(f, "S")
  expect_identical(g$type[1:6, 1L], c("str", "num", "str", "bool", "str", "str"))
  expect_identical(io_xl_grid_cell(g, 2L, 1L), list(t = "num", v = 7.125))
  expect_identical(io_xl_grid_cell(g, 3L, 1L), list(t = "str", v = "7.125"))
  expect_identical(io_xl_grid_cell(g, 4L, 1L), list(t = "bool", v = TRUE))
  expect_identical(io_xl_grid_cell(g, 1L, 3L), list(t = "str", v = "123"))
  expect_null(io_xl_grid_cell(g, 2L, 3L))
  expect_null(io_xl_grid_cell(g, 99L, 1L))
})

test_that("Zelldeutung: Datumszellen, Jahre als Termin, Bezeichnungen, Flussnotation", {
  rs <- io_xl_new_reader("x.xlsx")
  date_p <- vofi_param("date")
  tim_p <- vofi_param("timing")
  num <- function(v) list(t = "num", v = v)
  str <- function(v) list(t = "str", v = v)
  expect_identical(io_xl_decode_cell(num(46388), date_p, "p", rs), "2027-01-01")
  expect_identical(io_xl_decode_cell(num(2028), tim_p, "p", rs), 2028)
  expect_identical(io_xl_decode_cell(num(2028), date_p, "p", rs), 2028)
  expect_identical(io_xl_decode_cell(str("1.7.2028"), tim_p, "p", rs), "2028-07-01")
  expect_identical(io_xl_decode_cell(str("completion"), tim_p, "p", rs), "completion")
  expect_identical(io_xl_decode_cell(str("  ~ "), NULL, "p", rs), io_xl_null())
  expect_null(io_xl_decode_cell(str("   "), NULL, "p", rs))
  expect_identical(io_xl_decode_cell(str("'a b'"), NULL, "p", rs), "a b")
  expect_identical(io_xl_decode_cell(str("{}"), NULL, "p", rs),
                   structure(list(), names = character(0)))
  expect_identical(io_xl_decode_cell(str("[]"), NULL, "p", rs), list())
  expect_message(expect_identical(io_xl_decode_cell(str("1e5"), NULL, "p", rs), 1e5),
                 class = "vofi_message")
  expect_identical(io_xl_decode_cell(str("abc"), NULL, "p", rs), "abc")
  expect_identical(io_xl_decode_cell(str("123"), vofi_param("string"), "p", rs), "123")
  expect_identical(io_xl_decode_cell(list(t = "bool", v = FALSE), NULL, "p", rs), FALSE)
  expect_identical(io_xl_decode_cell(str("x, y"), vofi_param("ids"), "p", rs), c("x", "y"))
  expect_identical(io_xl_series_key(num(2027)), "2027")
  expect_identical(io_xl_series_key(num(46388)), "2027-01-01")
  expect_identical(io_xl_series_key(str("t 3")), "t3")
  expect_identical(io_xl_series_key(str("01.07.2027")), "2027-07-01")
  expect_true(is.na(io_xl_series_key(str("abc"))))
  expect_true(is.na(io_xl_series_key(num(12.5))))
})

test_that("Varianten und Szenario-Sets: Zellen nach dem Schema des Zielpfads (Review A2-01)", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  x <- scn_input_tree(sc)
  x$variants <- list(v1 = list(
    label = "V1",
    set = list(project.valuation_date = "2027-07-01", project.perspective = "wu_privat"),
    overrides = list(project = list(application_date = "2026-11-01"))
  ))
  x$scenario_sets <- list(s1 = list(label = "S1",
                                    set = list("funding.*.application_date" = "2027-03-01")))
  f <- xl_tempfile()
  vofi_write_scenario(vofi_scenario(x), f)
  var_sheet <- sheet("variants")
  set_sheet <- sheet("scenario_sets")
  # Bearbeitung wie in einem deutschen Excel: Datum als Datumszelle, Auswahl als Bezeichnung,
  # Datum als Text TT.MM.JJJJ
  v <- xl_read_sheet(f, var_sheet)
  s <- xl_read_sheet(f, set_sheet)
  vcol <- match(".value", unlist(v[1L, ]))
  scol <- match(".value", unlist(s[1L, ]))
  vrow <- function(p) which(v[[match(".path", unlist(v[1L, ]))]] == p)
  persp <- io_xl_list("enum:perspective")
  wb <- openxlsx::loadWorkbook(f)
  openxlsx::writeData(wb, var_sheet, as.Date("2028-01-01"), startCol = vcol,
                      startRow = vrow("project.valuation_date"))
  openxlsx::writeData(wb, var_sheet, persp$label[persp$code == "selbstnutzer"],
                      startCol = vcol, startRow = vrow("project.perspective"))
  openxlsx::writeData(wb, var_sheet, "01.02.2027", startCol = vcol,
                      startRow = vrow("project.application_date"))
  openxlsx::writeData(wb, set_sheet, as.Date("2027-04-01"), startCol = scol,
                      startRow = which(s[[match(".path", unlist(s[1L, ]))]] ==
                                         "funding.*.application_date"))
  openxlsx::saveWorkbook(wb, f, overwrite = TRUE)
  back <- vofi_read_scenario(f)
  expect_identical(back$variants$v1$set,
                   list(project.valuation_date = "2028-01-01",
                        project.perspective = "selbstnutzer"))
  expect_identical(back$variants$v1$overrides$project$application_date, "2027-02-01")
  expect_identical(back$scenario_sets$s1$set[["funding.*.application_date"]], "2027-04-01")
  locs <- attr(back, "source")$locations
  expect_identical(locs[["variants.v1.set.project.valuation_date"]],
                   paste0(var_sheet, "!", openxlsx::int2col(vcol), vrow("project.valuation_date")))
  r <- suppressWarnings(suppressMessages(vofi_resolve(back, "v1")))
  expect_identical(r$project$valuation_date, as.Date("2028-01-01"))
  expect_identical(r$project$perspective, "selbstnutzer")
  expect_identical(r$project$application_date, as.Date("2027-02-01"))
  # Felder ohne Zielschema (generate) bleiben in der allgemeinen Wertgrammatik
  expect_null(io_xl_variant_param("generate", "probs"))
  expect_identical(io_xl_variant_param("set", "funding.*.approved")$kind,
                   io_xl_param_at("funding.x.approved")$kind)
  expect_identical(io_xl_variant_param("overrides", "project.valuation_date")$kind, "date")
  expect_null(io_xl_variant_param("set", NULL))
})

test_that("Arbeitsmappen im 1904-Datumssystem werden umgerechnet (Review A2-03)", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  f <- xl_tempfile()
  vofi_write_scenario(sc, f)
  expect_identical(io_xl_date_origin(f), "1900-01-01")
  prj <- sheet("project")
  p <- xl_read_sheet(f, prj)
  row <- which(p[[1L]] == "project.valuation_date")
  wb <- openxlsx::loadWorkbook(f)
  # wie eine 1904-Mappe (Excel für den Mac bis 2011): Seriennummer um 1462 Tage kleiner
  wb$workbook$workbookPr <- "<workbookPr date1904=\"1\"/>"
  openxlsx::writeData(wb, prj, 46388 - 1462, startCol = 5L, startRow = row)
  openxlsx::saveWorkbook(wb, f, overwrite = TRUE)
  expect_identical(io_xl_date_origin(f), "1904-01-01")
  back <- vofi_read_scenario(f)
  expect_identical(back$project$valuation_date, as.Date("2027-01-01"))
  expect_identical(io_xl_serial_date(46388), as.Date("2027-01-01"))
  expect_identical(io_xl_serial_date(46388 - 1462, "1904-01-01"), as.Date("2027-01-01"))
  expect_identical(io_xl_series_key(list(t = "num", v = 46388 - 1462), "1904-01-01"),
                   "2027-01-01")
  rs <- io_xl_new_reader("x.xlsx")
  rs$date_origin <- "1904-01-01"
  expect_identical(io_xl_decode_cell(list(t = "num", v = 44926), vofi_param("date"), "p", rs),
                   "2027-01-01")
})

test_that("Blätter ohne Rolle: Warnung bei umbenanntem Datenblatt, sonst Hinweis (Review A2-04)", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  f <- xl_tempfile()
  vofi_write_scenario(sc, f)
  wb <- openxlsx::loadWorkbook(f)
  openxlsx::renameWorksheet(wb, sheet("financing"), "Finanzierung (2)")
  openxlsx::addWorksheet(wb, "Notizen")
  openxlsx::writeData(wb, "Notizen", "eigene Notiz", startRow = 5L)
  openxlsx::addWorksheet(wb, "Leer")
  openxlsx::saveWorkbook(wb, f, overwrite = TRUE)
  acc <- new.env(parent = emptyenv())
  acc$w <- list()
  acc$m <- list()
  back <- withCallingHandlers(
    vofi_read_scenario(f),
    vofi_warning = function(w) {
      acc$w <- c(acc$w, list(w))
      invokeRestart("muffleWarning")
    },
    vofi_message = function(m) {
      acc$m <- c(acc$m, list(m))
      invokeRestart("muffleMessage")
    }
  )
  expect_length(back$financing, 0L)
  wkeys <- vapply(acc$w, function(w) w$key, "")
  expect_identical(wkeys, "excel_input.sheet_ignored")
  expect_s3_class(acc$w[[1L]], "vofi_warning_input")
  expect_match(conditionMessage(acc$w[[1L]]), "Finanzierung (2)", fixed = TRUE)
  expect_match(conditionMessage(acc$w[[1L]]), sheet("financing"), fixed = TRUE)
  mkeys <- vapply(acc$m, function(m) m$key, "")
  expect_identical(mkeys, "excel_input.sheet_not_read")
  expect_match(conditionMessage(acc$m[[1L]]), "Notizen", fixed = TRUE)
})
