# Tests für R/io-excel-template.R (WS-A2; Spec 00 Abschnitt 4.14 Nr. 3, Memo 05 Abschnitt 4.10,
# 15.6 "Vorlage = generierte Vorlage").

xl_template_cache <- new.env(parent = emptyenv())

#' Frisch generierte Vorlage (einmal je Testdatei; nur Paketbibliothek)
xl_template <- function() {
  if (is.null(xl_template_cache$path) || !file.exists(xl_template_cache$path)) {
    p <- tempfile(fileext = ".xlsx")
    withr::with_options(list(vofi.library_paths = character(0)), vofi_excel_template(p))
    xl_template_cache$path <- p
  }
  xl_template_cache$path
}

test_that("vofi_excel_template: Argumente, Endung, vorhandene Datei, Beispiel", {
  f <- withr::local_tempfile(fileext = ".xlsx")
  expect_error(vofi_excel_template(1), class = "vofi_error_input")
  expect_error(vofi_excel_template(NULL), class = "vofi_error_input")
  e <- expect_error(vofi_excel_template(withr::local_tempfile(fileext = ".xls")),
                    class = "vofi_error_input")
  expect_identical(e$key, "excel_input.extension")
  expect_error(vofi_excel_template(f, overwrite = NA), class = "vofi_error_input")
  writeLines("x", f)
  e <- expect_error(vofi_excel_template(f), class = "vofi_error_input")
  expect_identical(e$key, "excel_input.file_exists")
  e <- expect_error(vofi_excel_template(f, example = 1, overwrite = TRUE),
                    class = "vofi_error_input")
  expect_identical(e$key, "excel_input.example_invalid")
  expect_error(vofi_excel_template(f, example = "gibt_es_nicht", overwrite = TRUE),
               class = "vofi_error_input")
  e <- expect_error(vofi_excel_template(file.path(withr::local_tempdir(), "fehlt", "v.xlsx")),
                    class = "vofi_error_input")
  expect_identical(e$key, "excel_input.write_failed")
})

test_that("Vorlage: Blätter in Reihenfolge, Maschinenschlüssel, Überschriften", {
  f <- xl_template()
  roles <- io_xl_roles()
  expect_identical(openxlsx::getSheetNames(f), vapply(roles, io_xl_sheet_name, "",
                                                      USE.NAMES = FALSE))
  for (r in setdiff(roles, "instructions")) {
    d <- xl_read_sheet(f, io_xl_sheet_name(r))
    keys <- unlist(d[1L, ], use.names = FALSE)
    if (io_xl_kind(r) == "wide") {
      expect_identical(keys, vapply(io_xl_wide_columns(r), function(cl) cl$key, ""), info = r)
    } else if (!(r %in% c("lists", "series"))) {
      expect_identical(keys, io_xl_fixed_columns(r), info = r)
      expect_identical(unlist(d[2L, ], use.names = FALSE),
                       unname(vapply(io_xl_fixed_columns(r), io_xl_column_label, "")), info = r)
    }
  }
  z <- xl_read_sheet(f, io_xl_sheet_name("series"))
  expect_identical(unlist(z[1L, ], use.names = FALSE),
                   c(io_xl_fixed_columns("series"), as.character(2025:2075)))
  a <- xl_read_sheet(f, io_xl_sheet_name("instructions"))
  expect_identical(a[[1L]][1L], lbl("excel_input.instructions.title"))
  expect_true(any(grepl(lbl("excel_input.instructions.legend_input"), a[[1L]], fixed = TRUE)))
})

test_that("Vorlage: jedes Feld des Katalogs hat eine Zeile bzw. Spalte, mit Einheit und Vorgabe", {
  f <- xl_template()
  cat <- val_schema_catalog()
  walk <- function(fields, prefix) {
    out <- character(0)
    for (nm in setdiff(names(fields), ".key")) {
      p <- fields[[nm]]
      path <- paste0(prefix, ".", nm)
      coll <- p$extra[["collection"]]
      out <- c(out, if (is.character(coll)) {
        walk(cat[[coll]], paste0(path, ".*"))
      } else if (io_xl_param_is_fixed_map(p)) {
        walk(p$fields, path)
      } else {
        path
      })
    }
    out
  }
  for (r in c("project", "household", "building")) {
    d <- xl_read_sheet(f, io_xl_sheet_name(r))
    for (b in io_xl_kv_blocks(r)) {
      expected <- walk(cat[[b]], b)
      expect_true(all(expected %in% d[[1L]]), info = paste(b, setdiff(expected, d[[1L]])))
    }
  }
  st <- xl_read_sheet(f, io_xl_sheet_name("settings"))
  expect_true(all(paste0("stochastic.settings.", c("preset", "n_sim", "seed", "block_size")) %in%
                    st[[1L]]))
  mk <- xl_read_sheet(f, io_xl_sheet_name("market"))
  expect_true(all(c("market.inflation", "market.energy_price.gas", "market.co2_price",
                    "market.feed_in_tariff.full_le10kwp", "shared") %in% mk[[1L]]))
  for (r in c("unit_groups", "measures", "funding")) {
    keys <- unlist(xl_read_sheet(f, io_xl_sheet_name(r))[1L, ], use.names = FALSE)
    expected <- walk(cat[[r]], r)
    expect_true(all(sub(paste0("^", r, "[.]"), "", expected) %in% keys), info = r)
  }
  fin <- unlist(xl_read_sheet(f, io_xl_sheet_name("financing"))[1L, ], use.names = FALSE)
  for (t in io_xl_financing_types()) {
    pn <- names(scn_type_def(t, "financing")$params)
    expect_true(all(pn %in% sub("[.].*$", "", fin)), info = t)
  }
  p <- xl_read_sheet(f, io_xl_sheet_name("project"))
  row <- function(path) p[p[[1L]] == path, ]
  expect_identical(row("project.comparison_mode")[[7L]], "absolute")
  expect_identical(row("project.comparison_mode")[[8L]], lbl("excel_input.default_sources.global"))
  expect_identical(row("accounts.deposit_rate_pa")[[8L]],
                   lbl("excel_input.default_sources.profile"))
  expect_identical(row("project.tax_regime")[[8L]], lbl("excel_input.default_sources.rule"))
  expect_identical(row("project.valuation_date")[[3L]], lbl("vocab.units.date"))
  expect_identical(row("project.perspective")[[2L]], lbl("excel_input.fields.perspective"))
})

test_that("Vorlage: Auswahllisten, ausgeblendete Zeile 1 und Blätter, Formate, Grauschaltung", {
  f <- xl_template()
  lists <- xl_read_sheet(f, io_xl_sheet_name("lists"))
  keys <- unlist(lists[1L, ], use.names = FALSE)
  expect_true(all(c("enum:perspective", "enum:perspective#label", "forms", "types:financing",
                    "types:distribution", "logical", "library:funding") %in% keys))
  j <- match("enum:perspective#label", keys)
  persp <- io_xl_list("enum:perspective")
  expect_identical(lists[[j]][3:(2 + nrow(persp))], persp$label)
  expect_identical(lists[[j - 1L]][3:(2 + nrow(persp))], persp$code)
  expect_true(lbl("vocab.enums.perspective.selbstnutzer") %in% persp$label)
  dir <- withr::local_tempdir()
  utils::unzip(f, exdir = dir)
  wbxml <- paste(readLines(file.path(dir, "xl", "workbook.xml"), warn = FALSE,
                           encoding = "UTF-8"), collapse = "")
  for (r in c("lists", "meta")) {
    expect_match(wbxml, paste0("name=\"", io_xl_sheet_name(r), "\"[^>]*state=\"hidden\""),
                 info = r)
  }
  sx <- function(r) {
    i <- match(r, io_xl_roles())
    paste(readLines(file.path(dir, "xl", "worksheets", sprintf("sheet%d.xml", i)), warn = FALSE,
                    encoding = "UTF-8"), collapse = "")
  }
  expect_match(sx("project"), "<row r=\"1\"[^>]*hidden=\"1\"")
  expect_match(sx("project"), "dataValidation type=\"list\"", fixed = TRUE)
  expect_match(sx("project"), io_xl_sheet_name("lists"), fixed = TRUE)
  expect_match(sx("financing"), "<cfRule type=\"expression\"")
  expect_match(sx("financing"), "dataValidation type=\"list\"", fixed = TRUE)
  styles <- paste(readLines(file.path(dir, "xl", "styles.xml"), warn = FALSE, encoding = "UTF-8"),
                  collapse = "")
  expect_match(styles, "0.00%", fixed = TRUE)
  expect_match(styles, "#,##0 €", fixed = TRUE)
  expect_true(length(list.files(file.path(dir, "xl"), pattern = "^comments", recursive = TRUE)) >
                0L)
})

test_that("ausgelieferte Vorlage entspricht einer frisch generierten Vorlage", {
  shipped <- system.file("templates", "vofi_eingabe.xlsx", package = "vofi")
  expect_true(nzchar(shipped) && file.exists(shipped))
  skip_if_not(nzchar(shipped) && file.exists(shipped))
  fresh <- xl_template()
  sheets <- openxlsx::getSheetNames(fresh)
  expect_identical(openxlsx::getSheetNames(shipped), sheets)
  hint <- "Vorlage veraltet: Rscript data-raw/build_template.R ausfuehren und einchecken."
  for (s in sheets) {
    a <- xl_read_sheet(shipped, s)
    b <- xl_read_sheet(fresh, s)
    if (s == io_xl_sheet_name("meta")) {
      a <- a[a[[1L]] != "package_version", , drop = FALSE]
      b <- b[b[[1L]] != "package_version", , drop = FALSE]
    }
    expect_identical(a, b, info = paste(s, "-", hint))
  }
})

test_that("Labels: Felder, Spalten, Blätter, Wertformen, Aktionen vollständig", {
  cat <- val_schema_catalog()
  walk <- function(fields) {
    out <- character(0)
    for (nm in names(fields)) {
      p <- fields[[nm]]
      if (nm != ".key") out <- c(out, nm)
      if (identical(p$kind, "map")) out <- c(out, walk(p$fields))
    }
    out
  }
  names_all <- unique(c(unlist(lapply(cat, walk)), reg_reserved_fields(), "from", "use"))
  for (t in io_xl_financing_types()) {
    names_all <- c(names_all, walk(scn_type_def(t, "financing")$params))
  }
  missing <- unique(names_all[!vapply(paste0("excel_input.fields.", unique(names_all)), lbl_has,
                                      logical(1))])
  expect_identical(missing, character(0))
  for (r in io_xl_roles()) {
    nm <- io_xl_sheet_name(r)
    chars <- strsplit(nm, "", fixed = TRUE)[[1L]]
    expect_true(nchar(nm) <= 31L && !any(chars %in% c("[", "]", ":", "*", "?", "/", "\\")),
                info = r)
    for (k in io_xl_fixed_columns(r)) {
      expect_true(lbl_has(paste0("excel_input.columns.", sub("^[.]", "", k))), info = k)
    }
    if (!(r %in% c("instructions", "lists", "meta"))) {
      expect_true(lbl_has(paste0("excel_input.sheet_help.", r)), info = r)
    }
  }
  for (r in c("unit_groups", "measures", "funding", "financing", "parameters")) {
    for (cl in io_xl_wide_columns(r)) {
      if (startsWith(cl$key, ".")) {
        expect_true(lbl_has(paste0("excel_input.columns.", sub("^[.]", "", cl$key))), info = cl$key)
      }
    }
  }
  for (code in io_xl_list("forms")$code) {
    expect_true(lbl_has(paste0("excel_input.form_help.", code)), info = code)
  }
  for (code in io_xl_list("actions:sets")$code) {
    expect_true(lbl_has(paste0("excel_input.actions.", code)), info = code)
  }
  for (code in io_xl_list("corr")$code) {
    expect_true(lbl_has(paste0("excel_input.correlation_kinds.", code)), info = code)
  }
  for (code in c("type", "global", "profile", "rule", "vocab")) {
    expect_true(lbl_has(paste0("excel_input.default_sources.", code)), info = code)
  }
  for (k in c("enum", "ids", "timing", "string", "schedule", "map", "integer")) {
    expect_true(lbl_has(paste0("excel_input.kinds.", k)))
  }
  for (b in c("meta", "project", "building_elements", "energy_carriers", "energy_stages",
              "stochastic_settings", "shared", "market")) {
    expect_true(lbl_has(paste0("excel_input.blocks.", b)), info = b)
  }
})

test_that("Vorgaben, Einheiten, Formate und Auswahllisten der Felder", {
  cat <- val_schema_catalog()
  d <- io_xl_default_info("project.comparison_mode", cat$project$comparison_mode)
  expect_identical(d, list(text = "absolute", source = lbl("excel_input.default_sources.global")))
  d <- io_xl_default_info("measures.*.cost_factor", cat$measures$cost_factor)
  expect_identical(d$text, "{ref: project.construction_cost_factor}")
  d <- io_xl_default_info("energy.carriers.*.price_eur_kwh",
                          cat[["energy.carriers"]]$price_eur_kwh)
  expect_identical(d$text, "{ref: \"market.energy_price.{id}\"}")
  d <- io_xl_default_info("measures.wp.kg", cat$measures$kg)
  expect_identical(d$source, lbl("excel_input.default_sources.rule"))
  ann <- reg_get("instrument", "annuity_loan")$params
  d <- io_xl_default_info("financing.*.payments_per_year", ann$payments_per_year)
  expect_identical(d, list(text = "12", source = lbl("excel_input.default_sources.type")))
  p_align <- vofi_param("enum", values = "vocab:payment_profile")
  d <- io_xl_default_info("grid.operation_alignment", p_align)
  expect_identical(d$source, lbl("excel_input.default_sources.global"))
  d <- io_xl_default_info("x.y", vofi_param("enum", values = "vocab:payment_profile"))
  expect_identical(d, list(text = "linear", source = lbl("excel_input.default_sources.vocab")))
  expect_identical(io_xl_default_info("x", NULL), list(text = "", source = ""))
  expect_identical(io_xl_unit_code(vofi_param("rate"), "a.b"), "rate_pa")
  expect_identical(io_xl_unit_code(vofi_param("share"), "a.b"), "share")
  expect_identical(io_xl_unit_code(vofi_param("amount"), "a.b"), "EUR")
  expect_identical(io_xl_unit_code(NULL, "market.x_eur_m2_month"), "EUR_m2_month")
  expect_identical(io_xl_unit_code(NULL, "accounts.deposit_rate_pa"), "rate_pa")
  expect_identical(io_xl_unit_code(NULL, "energy.x_kwh_pa"), "kWh_pa")
  expect_true(is.na(io_xl_unit_code(NULL, "market.x")))
  expect_identical(io_xl_num_fmt(vofi_param("rate"), "a"), "0.00%")
  expect_identical(io_xl_num_fmt(vofi_param("amount"), "a"), "#,##0 €")
  expect_identical(io_xl_num_fmt(NULL, "a.b_eur_kwh"), "#,##0.0000 €")
  expect_identical(io_xl_num_fmt(vofi_param("date"), "a"), "DATE")
  expect_null(io_xl_num_fmt(NULL, "a.b"))
  expect_identical(io_xl_param_list(cat$project$perspective), "enum:perspective")
  expect_identical(io_xl_param_list(cat$measures$measure_type), "vocab:measure_types")
  expect_identical(io_xl_param_list(vofi_param("logical")), "logical")
  expect_null(io_xl_param_list(vofi_param("number")))
  expect_match(io_xl_param_list(cat$unit_groups$after_staffel_regime), "^codes:")
  l <- io_xl_list(io_xl_param_list(cat$unit_groups$after_staffel_regime))
  expect_identical(l$code, c("paragraph_558", "index"))
  expect_false(anyDuplicated(l$label) > 0L)
  lst <- io_xl_list_df(c("a", "b", "c"), c("X", "X", "c"))
  expect_identical(lst$label, c("X (a)", "X (b)", "c"))
  lst <- io_xl_list_df(c("a", "b"), c("b", ""))
  expect_identical(lst$label, c("b (a)", "b (b)"))
  lst <- io_xl_list_df(c("a", "b"), c("b", "B"))
  expect_identical(lst$label, c("b (a)", "B"))
  expect_identical(io_xl_market_label("market.energy_price.gas"),
                   paste0(lbl("excel_input.market.energy_price"), ": ",
                          lbl("excel_input.carriers.gas")))
  expect_identical(io_xl_market_unit("market.inflation"), "rate_pa")
  expect_identical(io_xl_market_unit("market.co2_price"), "EUR_t")
  expect_true(is.na(io_xl_market_unit("market.eigenes")))
  expect_identical(io_xl_field_label("building.component_areas_m2.roof"),
                   lbl("vocab.enums.component_area.roof"))
  expect_identical(io_xl_param_at("components.z.values", c("components.z" = "custom_series"))$kind,
                   "value")
  expect_identical(io_xl_param_at("financing.b.after", character(0))$kind, "ids")
  expect_identical(io_xl_param_at("financing.b.label", character(0))$kind, "string")
  expect_null(io_xl_param_at("financing.b.rate_pa", character(0)))
  expect_null(io_xl_param_at("stochastic.processes.k.r0.x", character(0)))
  expect_identical(io_xl_param_at("project.valuation_date")$kind, "date")
})
