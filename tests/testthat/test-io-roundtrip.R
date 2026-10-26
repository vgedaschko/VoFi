# Round-Trip YAML <-> XLSX (WS-A2; Spec 00 Abschnitte 4.6 "Numerische Ablage", 4.8, 4.14 Nr. 1,
# 15.6 "Eingabe"): Excel ist eine verlustfreie Darstellung derselben kanonischen Liste.

test_that("Skelett: YAML -> XLSX -> Liste ist identisch, Herkunft nennt Blatt und Zelle", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  f <- xl_tempfile()
  expect_identical(vofi_write_scenario(sc, f), f)
  back <- vofi_read_scenario(f)
  expect_xl_identical(back, sc)
  src <- attr(back, "source")
  expect_identical(src$format, "excel")
  expect_identical(basename(src$path), basename(f))
  prov <- attr(back, "provenance")
  expect_identical(names(prov), prv_columns())
  expect_true(all(prov$layer == 5L))
  expect_true(all(prov$source_type == "scenario"))
  expect_true(all(grepl("^[^!]+![A-Z]+[0-9]+$", prov$location)))
  loc <- function(p) prov$location[prov$path == p]
  expect_match(loc("financing.bank.rate_pa"), paste0("^", lbl("excel_input.sheets.financing"),
                                                     "!"))
  expect_match(loc("project.valuation_date"), paste0("^", lbl("excel_input.sheets.project"),
                                                     "!E[0-9]+$"))
  expect_match(loc("components.z.values"), paste0("^", lbl("excel_input.sheets.components"),
                                                  "!G[0-9]+$"))
  # Ergebnis wie aus YAML (Prüfwerte des Skeletts, Spec 00 Anhang A)
  res <- xl_quiet_run(back)
  expect_equal(res$kpis$terminal_value, 52830.80, tolerance = 1e-8)
  expect_equal(res$kpis$terminal_value_opp, 42448.32, tolerance = 1e-8)
  expect_equal(res$kpis$delta_terminal_value, 10382.48, tolerance = 1e-8)
})

test_that("grob_lehrbuch_a: Round-Trip identisch, Reihe mit Bezug als Element, Overlay", {
  sc <- vofi_read_scenario(vofi_example("grob_lehrbuch_a"))
  back <- xl_roundtrip(sc, xl_tempfile())
  expect_xl_identical(back, sc)
  expect_identical(back$components$rw$values$values[[6L]]$kind, "ref")
  expect_identical(back$stochastic$parameters$rw$dist, "triangular")
  r1 <- xl_quiet_run(sc)$kpis
  r2 <- xl_quiet_run(back)$kpis
  expect_identical(r2, r1)
})

test_that("reichhaltiges Szenario: alle Blöcke, Wertformen, Varianten, Sets und Overlay", {
  sc <- vofi_read_scenario(xl_fixture("rich.yaml"))
  f <- xl_tempfile()
  vofi_write_scenario(sc, f)
  back <- vofi_read_scenario(f)
  expect_xl_identical(back, sc)
  # gezielte Stichproben der heiklen Werte
  expect_identical(back$market$precise$value, 0.30000000000000004)
  expect_identical(back$market$tiny$value, 1e-17)
  expect_identical(back$market$huge$value, 3e9)
  expect_identical(back$market$label_text, "123")
  expect_identical(back$unit_groups$a$rent_eur_m2_month$value, 7.125)
  expect_identical(back$accounts$overdraft_limit_eur$value, Inf)
  expect_identical(back$energy$carriers$gas, structure(list(), names = character(0)))
  expect_identical(back$tax$params, structure(list(), names = character(0)))
  expect_identical(back$project$pending_reforms, character(0))
  expect_identical(back$meta$description, "Zwei Zeilen\nmit Umlauten äöü ß und Euro €")
  expect_identical(back$measures$huelle$payment_schedule$dates,
                   as.Date(c("2027-07-01", "2028-01-01")))
  expect_true("growth" %in% names(back$variants$v1$overrides$components$wart))
  expect_null(back$variants$v1$overrides$components$wart$growth)
  expect_identical(back$stochastic$correlations$shocks,
                   list(from = "processes/shock_correlations_2026"))
  expect_identical(back$stochastic$correlations$parameters,
                   list(list("kosten", "zins", 0.3), list("kosten", "diskret", -0.2)))
  expect_identical(names(back), names(sc))
  # Herkunft: Elemente breiter Blätter und Zeitreihen
  prov <- attr(back, "provenance")
  loc <- function(p) prov$location[prov$path == p]
  expect_match(loc("unit_groups.a.rent_eur_m2_month"),
               paste0("^", lbl("excel_input.sheets.unit_groups"), "!"))
  expect_match(loc("stochastic.parameters.kosten.min"),
               paste0("^", lbl("excel_input.sheets.parameters"), "!E[0-9]+$"))
  # Varianten tragen keine Herkunftszeilen (4.8: nur Blätter der Schicht 5/6); die Fundstellen
  # stehen in den Quellangaben
  locs <- attr(back, "source")$locations
  expect_match(locs[["variants.v1.set.measures.huelle.cost_eur"]],
               paste0("^", lbl("excel_input.sheets.variants"), "!H[0-9]+$"))
})

test_that("XLSX -> YAML -> XLSX: dieselbe kanonische Liste in beide Richtungen", {
  sc <- vofi_read_scenario(xl_fixture("rich.yaml"))
  f1 <- xl_tempfile()
  vofi_write_scenario(sc, f1)
  from_xl <- vofi_read_scenario(f1)
  y <- withr::local_tempfile(fileext = ".yaml")
  vofi_write_scenario(from_xl, y)
  back_yaml <- vofi_read_scenario(y)
  f2 <- xl_tempfile()
  vofi_write_scenario(back_yaml, f2)
  back_xl <- vofi_read_scenario(f2)
  expect_xl_identical(back_xl, back_yaml)
  expect_identical(xl_blocks(back_yaml)$financing, xl_blocks(from_xl)$financing)
  expect_identical(xl_blocks(back_yaml)$stochastic, xl_blocks(from_xl)$stochastic)
})

test_that("aufgelöste Variante als XLSX: erneutes Auflösen ergibt dieselbe Rechnung", {
  sc <- vofi_read_scenario(vofi_example("grob_lehrbuch_a"))
  f <- xl_tempfile()
  suppressWarnings(suppressMessages(vofi_write_scenario(sc, f, resolved = TRUE)))
  rs <- vofi_read_scenario(f)
  expect_length(rs$variants, 0L)
  expect_identical(rs$accounts$deposit_rate_pa, node_const(0.03))
  r1 <- xl_quiet_run(sc)$kpis
  r2 <- xl_quiet_run(rs)$kpis
  expect_identical(r2, r1)
  # dieselbe Variante als YAML aufgelöst geschrieben ergibt dieselben Blöcke. YAML lässt leere
  # Blöcke und explizite NULL-Einträge (z. B. project.municipality.mietpreisbremse_until aus
  # global.yaml) weg; Excel behält beide (Reihenfolge der Blöcke im Blatt _meta, NULL als ~).
  y <- withr::local_tempfile(fileext = ".yaml")
  suppressWarnings(suppressMessages(vofi_write_scenario(sc, y, resolved = TRUE)))
  a <- xl_blocks(rs)
  b <- xl_blocks(vofi_read_scenario(y))
  expect_setequal(names(a), names(b))
  expect_identical(xl_drop_null(a[names(b)]), xl_drop_null(b))
  expect_true("mietpreisbremse_until" %in% names(a$project$municipality))
})

test_that("separate Stochastik-Datei zu einer Excel-Szenariodatei (Schicht 6)", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  f <- xl_tempfile()
  vofi_write_scenario(sc, f)
  ov <- withr::local_tempfile(fileext = ".yaml")
  writeLines(c("stochastic:", "  settings: {n_sim: 400, seed: 7}", "  parameters:",
               "    zins: {target: financing.bank.rate_pa, dist: normal, mean: 0.05, sd: 0.01}"),
             ov)
  back <- vofi_read_scenario(f, stochastic = ov)
  expect_identical(back$stochastic$settings$n_sim, 400L)
  expect_identical(back$stochastic$parameters$zins$dist, "normal")
  prov <- attr(back, "provenance")
  st <- prov[prov$path == "stochastic.parameters.zins.dist", ]
  expect_identical(c(st$layer, st$source_type), c(6L, "overlay"))
  expect_identical(prov$location[prov$path == "meta.title"],
                   attr(vofi_read_scenario(f), "provenance")$location[prov$path == "meta.title"])
})

test_that("Vorlage mit Beispiel entspricht vofi_write_scenario() und liest verlustfrei", {
  sc <- vofi_read_scenario(vofi_example("grob_lehrbuch_a"))
  f <- xl_tempfile()
  expect_identical(vofi_excel_template(f, example = "grob_lehrbuch_a"), f)
  expect_xl_identical(vofi_read_scenario(f), sc)
  f2 <- xl_tempfile()
  vofi_excel_template(f2, example = sc)
  expect_xl_identical(vofi_read_scenario(f2), sc)
})

test_that("in Excel geänderte Werte werden gelesen (Bearbeitung einer geschriebenen Datei)", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  f <- xl_tempfile()
  vofi_write_scenario(sc, f)
  fin <- lbl("excel_input.sheets.financing")
  d <- xl_read_sheet(f, fin)
  row <- which(d[[1L]] == "bank")
  col <- which(unlist(d[1L, ]) == "rate_pa")
  prj <- lbl("excel_input.sheets.project")
  p <- xl_read_sheet(f, prj)
  prow <- which(p[[1L]] == "project.horizon_years")
  wb <- openxlsx::loadWorkbook(f)
  openxlsx::writeData(wb, fin, 0.045, startCol = col, startRow = row)
  openxlsx::writeData(wb, prj, 4, startCol = 5L, startRow = prow)
  openxlsx::saveWorkbook(wb, f, overwrite = TRUE)
  back <- vofi_read_scenario(f)
  expect_identical(back$financing$bank$rate_pa, node_const(0.045))
  expect_identical(back$project$horizon_years, 4L)
  expect_identical(back$components, sc$components)
})

test_that("Fixtures im Excel-Format (eingecheckt) lesen sich wie ihre YAML-Quelle", {
  # Die xlsx-Fixtures erzeugt data-raw/build_examples_xlsx.R bzw. die Funktion
  # xl_build_fixtures() (helper-ws-a2.R); sie sichern das Dateiformat gegen Änderungen ab.
  # Sie stammen vom Schreiber vor den Review-Fixes (ohne Blattschutz, Varianten ohne Zielschema)
  # und prüfen damit zugleich, dass ältere Dateien derselben Vorlagenversion lesbar bleiben.
  for (name in c("skeleton", "rich")) {
    xl <- xl_fixture(paste0(name, ".xlsx"))
    yml <- xl_fixture(paste0(name, ".yaml"))
    expect_xl_identical(vofi_read_scenario(xl), vofi_read_scenario(yml))
  }
})

test_that("Varianten und Sets: Werte nach dem Zielschema, verlustfrei (Review A2-01)", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  x <- scn_input_tree(sc)
  x$variants <- list(
    v1 = list(
      label = "V1",
      set = list(project.valuation_date = "2028-01-01", project.perspective = "selbstnutzer",
                 meta.title = "123", project.pending_reforms = "a, b",
                 project.application_date = "2028-1-1", accounts.deposit_rate_pa = 0.025),
      replace = list(project.perspective = lbl("vocab.enums.perspective.selbstnutzer")),
      overrides = list(project = list(valuation_date = "2029-01-01", horizon_years = 4),
                       meta = list(title = "3,5"))
    )
  )
  x$scenario_sets <- list(
    s1 = list(label = "S1", set = list("funding.*.application_date" = "2027-03-01",
                                       "funding.*.approved" = 0)),
    s2 = list(label = "S2", generate = list(method = "cautious", probs = c(0.1, 0.9)))
  )
  sc2 <- vofi_scenario(x)
  f <- xl_tempfile()
  vofi_write_scenario(sc2, f)
  back <- vofi_read_scenario(f)
  expect_xl_identical(back, sc2)
  # Darstellung wie im Zielfeld: Datumszelle, Bezeichnung, Text ohne Anführungszeichen
  vs <- lbl("excel_input.sheets.variants")
  g <- io_xl_read_grid(f, vs)
  keys <- io_xl_grid_keys(g)
  jp <- match(".path", keys)
  jv <- match(".value", keys)
  cell <- function(action, p) {
    a <- io_xl_list("actions:variants")
    i <- which(g$str[, jp] == p & g$str[, match(".action", keys)] == a$label[a$code == action])
    io_xl_grid_cell(g, i, jv)
  }
  expect_identical(cell("set", "project.valuation_date"), list(t = "num", v = 46753))
  expect_identical(cell("set", "project.perspective")$v,
                   lbl("vocab.enums.perspective.selbstnutzer"))
  expect_identical(cell("set", "meta.title"), list(t = "str", v = "123"))
  expect_identical(cell("set", "project.pending_reforms")$v, "\"a, b\"")
  expect_identical(cell("set", "project.application_date")$v, "2028-1-1")
  expect_identical(cell("replace", "project.perspective")$v,
                   io_xl_quote(lbl("vocab.enums.perspective.selbstnutzer")))
  expect_identical(cell("overrides", "project.valuation_date"), list(t = "num", v = 47119))
})

test_that("Zeichenketten true/false in beliebiger Schreibweise bleiben erhalten (Review A2-02)", {
  sc <- vofi_read_scenario(vofi_example("skeleton"))
  x <- scn_input_tree(sc)
  x$meta$title <- "true"
  x$shared <- list(a = "False", b = "tRuE", c = "TRUE", d = " true")
  x$components$z$label <- "false"
  x$variants <- list(v = list(label = "True", set = list(meta.title = "false", shared.a = "true"),
                              remove = "shared.b"))
  sc2 <- vofi_scenario(x)
  f <- xl_tempfile()
  vofi_write_scenario(sc2, f)
  back <- vofi_read_scenario(f)
  expect_xl_identical(back, sc2)
  expect_identical(back$meta$title, "true")
  expect_identical(back$shared$b, "tRuE")
  expect_identical(back$components$z$label, "false")
  expect_identical(back$variants$v$set$meta.title, "false")
  # Schreibregeln: Anführungszeichen; die Prüfung beim Schreiben deutet Zellen wie openxlsx
  str <- vofi_param("string")
  for (s in c("true", "True", "FALSE", " false ")) expect_true(io_xl_needs_quote(s, str), info = s)
  expect_identical(io_xl_id_cell("true")$v, "\"true\"")
  expect_identical(io_xl_as_read(io_xl_cell_str("tRuE")), io_xl_cell_str("TRUE"))
  expect_identical(io_xl_as_read(io_xl_cell_str(" true")), io_xl_cell_str(" true"))
  st <- io_xl_new_state(NULL)
  enc <- list(form = NULL, value = io_xl_cell_str("true"), options = NULL)
  expect_false(io_xl_check_raw(enc, "true", "variants.v.set.meta.title", str, st))
  enc$value <- io_xl_cell_str("\"true\"")
  expect_true(io_xl_check_raw(enc, "true", "variants.v.set.meta.title", str, st))
})
