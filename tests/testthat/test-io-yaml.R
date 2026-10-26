# Tests für R/io-yaml.R (WS-A; Spec 00 Abschnitt 4.6). Phase-0-Minimalfassung.

write_yaml_lines <- function(lines) {
  f <- tempfile(fileext = ".yaml")
  writeLines(enc2utf8(lines), f, useBytes = TRUE)
  f
}

test_that("Handler: Zahlen als double, Inf, Wahrheitswerte, Datumsangaben als Text", {
  f <- write_yaml_lines(c("a: 12", "b: 0.039", "c: .inf", "d: -.inf", "e: 3000000000",
                          "f: yes", "g: true", "h: 2027-01-01", "i: [1, 2.5]",
                          "k: \"M\u00e4rz\""))
  y <- io_read_yaml_utf8(f)
  expect_identical(y$a, 12)
  expect_identical(y$b, 0.039)
  expect_identical(y$c, Inf)
  expect_identical(y$d, -Inf)
  expect_identical(y$e, 3e9)
  expect_identical(y$f, "yes")
  expect_identical(y$g, TRUE)
  expect_identical(y$h, "2027-01-01")
  expect_identical(y$i, c(1, 2.5))
  expect_identical(y$k, "M\u00e4rz")
  nan <- io_read_yaml_utf8(write_yaml_lines("x: .nan"))
  expect_true(io_is_raw_num(nan$x))
  expect_error(io_unmark(nan), class = "vofi_error_input")
  expect_error(io_read_yaml_utf8(tempfile()), class = "vofi_error_input")
})

test_that("Dezimalkomma und Tausenderpunkt werden markiert und mit Pfad entschieden", {
  y <- io_read_yaml_utf8(write_yaml_lines(c("a: 3,5", "b: 150.000", "c: [150.000, 2]")))
  expect_true(io_is_raw_num(y$a))
  expect_true(io_is_raw_num(y$b))
  expect_true(is.list(y$c) && io_is_raw_num(y$c[[1]]))
  expect_warning(v <- io_as_number(y$a, "x.rate_pa"), class = "vofi_warning_input")
  expect_identical(v, 3.5)
  expect_error(io_as_number(y$b, "x.cost_eur", eur = TRUE), class = "vofi_error_input")
  expect_warning(v <- io_as_number(y$b, "x.factor"), class = "vofi_warning_input")
  expect_identical(v, 150)
  expect_error(io_unmark(list(cost_eur = y$b)), class = "vofi_error_input")
  expect_warning(u <- io_unmark(list(f = y$c)), class = "vofi_warning_input")
  expect_identical(u$f, c(150, 2))
})

test_that("Zeichenketten: Prozent, Tausendertrennung, Exponent", {
  expect_warning(v <- io_as_number("3,5 %", "p"), class = "vofi_warning_input")
  expect_equal(v, 0.035)
  expect_warning(v <- io_as_number("3.5%", "p"), class = "vofi_warning_input")
  expect_equal(v, 0.035)
  local_vofi_options(vofi.verbose = FALSE)
  expect_identical(io_as_number("1.234.567", "p"), 1234567)
  expect_identical(io_as_number("150_000", "p"), 150000)
  expect_identical(io_as_number("1e-2", "p"), 0.01)
  expect_identical(io_as_number(".inf", "p"), Inf)
  expect_null(io_as_number("abc", "p"))
  expect_true(io_path_is_eur("components.x.amount_eur"))
  expect_false(io_path_is_eur("components.x.rate_pa"))
})

test_that("A-08: EUR-Beträge erkennt jedes Schlüsselsegment eur (4.6)", {
  expect_true(io_path_is_eur("unit_groups.a.operating.admin_per_unit_eur_pa"))
  expect_true(io_path_is_eur("energy.carriers.gas.base_fee_eur_pa"))
  expect_true(io_path_is_eur("building.maintenance.rate_eur_m2_pa"))
  expect_true(io_path_is_eur("energy.carriers.gas.network_fee_eur_kwh"))
  expect_true(io_path_is_eur("measures.m.cost_kg.eur"))
  expect_true(io_path_is_eur("x.amounts_eur.2"))
  expect_false(io_path_is_eur("x.europe_share"))
  expect_false(io_path_is_eur("x.neuro_pa"))
  expect_false(io_path_is_eur(""))
  base <- c("schema_version: 1", "meta: {scenario_id: t, title: T}",
            paste("project: {perspective: wu_privat, project_type: sanierung_eh,",
                  "valuation_date: 2027-01-01}"))
  e <- expect_error(vofi_read_scenario(write_yaml_lines(c(base, "unit_groups:", "  a:",
                                                          "    operating:",
                                                          "      admin_per_unit_eur_pa: 1.200"))),
                    class = "vofi_error_input")
  expect_identical(e$key, "io.thousands_eur")
  expect_error(vofi_read_scenario(write_yaml_lines(c(base, "energy:", "  carriers:", "    gas:",
                                                     "      base_fee_eur_pa: 1.500"))),
               class = "vofi_error_input")
  expect_error(vofi_read_scenario(write_yaml_lines(c(base, "measures:", "  m1:",
                                                     "    cost_eur: 150.000"))),
               class = "vofi_error_input")
  sc <- vofi_read_scenario(write_yaml_lines(c(base, "energy:", "  carriers:", "    gas:",
                                              "      base_fee_eur_pa: 1500")))
  expect_identical(sc$energy$carriers$gas$base_fee_eur_pa, node_const(1500))
})

test_that("Führende Null: Dezimalkomma 0,02 / -0,5 und 010 nie oktal (4.6)", {
  y <- io_read_yaml_utf8(write_yaml_lines(c("a: 0,02", "b: -0,5", "c: 010", "d: 0x10",
                                            "e: 1:30", "f: 00", "g: 0,08")))
  expect_true(io_is_raw_num(y$a))
  expect_warning(v <- io_as_number(y$a, "accounts.deposit_rate_pa"), class = "vofi_warning_input")
  expect_identical(v, 0.02)
  expect_warning(v <- io_as_number(y$b, "x.growth"), class = "vofi_warning_input")
  expect_identical(v, -0.5)
  expect_identical(io_as_number(y$c, "x.n"), 10)
  expect_identical(node_string(y$c, "x.code"), "010")
  expect_identical(io_as_number(y$f, "x.n"), 0)
  expect_null(io_as_number(y$d, "x.amount_eur"))
  expect_error(io_unmark(list(v = y$d)), class = "vofi_error_input")
  expect_identical(y$e, "1:30")
  expect_warning(v <- io_as_number(y$g, "x.rate_pa"), class = "vofi_warning_input")
  expect_identical(v, 0.08)
  # Ende-zu-Ende: Dezimalkomma mit führender Null im Skeleton
  txt <- readLines(vofi_example("skeleton"), encoding = "UTF-8")
  txt <- sub("deposit_rate_pa: 0.02", "deposit_rate_pa: 0,02", txt, fixed = TRUE)
  expect_true(any(grepl("deposit_rate_pa: 0,02", txt, fixed = TRUE)))
  w <- testthat::capture_warnings(sc <- vofi_read_scenario(write_yaml_lines(txt)))
  expect_true(any(grepl("0,02", w, fixed = TRUE)))
  expect_equal(vofi_run(vofi_build(sc))$kpis$terminal_value, 52830.80, tolerance = 1e-6)
})

test_that("Quotierte Zahlen folgen denselben Regeln wie unquotierte (4.6)", {
  expect_error(io_as_number("40.000", "financing.ek.amount_eur", eur = TRUE),
               class = "vofi_error_input")
  expect_warning(v <- io_as_number("40.000", "x.factor"), class = "vofi_warning_input")
  expect_identical(v, 40)
  expect_identical(io_as_number("0.5", "x.share"), 0.5)
  local_vofi_options(vofi.verbose = FALSE)
  expect_identical(io_as_number("1.234.567", "x.amount_eur", eur = TRUE), 1234567)
  expect_error(node_normalize(list("40.000", 2), vofi_param("amount"), "x.values_eur"),
               class = "vofi_error_input")
})

test_that("Nicht UTF-8-kodierte Datei: eigener Eingabefehler mit Zeile", {
  f <- tempfile(fileext = ".yaml")
  con <- file(f, "wb")
  writeBin(c(charToRaw("a: 1\nb: \"M"), as.raw(0xfc), charToRaw("ller\"\n")), con)
  close(con)
  e <- expect_error(io_read_yaml_utf8(f), class = "vofi_error_input")
  expect_identical(e$key, "io.not_utf8")
  expect_match(conditionMessage(e), "2", fixed = TRUE)
})

test_that("Byte-Order-Mark und Locale C: UTF-8 bleibt erhalten (4.6)", {
  f <- tempfile(fileext = ".yaml")
  con <- file(f, "wb")
  writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw(enc2utf8("titel: \"Grün\"\nn: 2\n"))),
           con)
  close(con)
  y <- io_read_yaml_utf8(f)
  expect_identical(names(y), c("titel", "n"))
  expect_identical(y$titel, "Grün")
  y2 <- withr::with_locale(c(LC_CTYPE = "C"), io_read_yaml_utf8(f))
  expect_identical(y2$titel, "Grün")
  expect_identical(Encoding(y2$titel), "UTF-8")
})

test_that("Fundstellen der Schlüssel (Zeilennummern, best effort, 4.8)", {
  txt <- c("# Kopf", "project:", "  perspective: wu_privat", "  municipality: {a: 1}",
           "components:", "  - id: z", "    type: custom_series", "    values: [1, 2]",
           "\"quoted.key\": 3", "accounts:", "  deposit_rate_pa:", "    ref: market.mortgage_rate")
  loc <- io_yaml_locations(txt)
  expect_identical(unname(loc["project"]), "Zeile 2")
  expect_identical(unname(loc["project.perspective"]), "Zeile 3")
  expect_identical(unname(loc["components.z"]), "Zeile 6")
  expect_identical(unname(loc["components.z.type"]), "Zeile 7")
  expect_identical(unname(loc["quoted.key"]), "Zeile 9")
  expect_identical(io_location_of(loc, "project.municipality.a"), "Zeile 4")
  expect_identical(io_location_of(loc, "accounts.deposit_rate_pa.ref"), "Zeile 12")
  expect_identical(io_location_of(loc, "unbekannt.x"), NA_character_)
  expect_identical(io_location_of(character(0), "a"), NA_character_)
})

test_that("Schreiben: kürzeste verlustfreie Zahldarstellung, Round-Trip über den Leser (4.6)", {
  v <- c(0, 12, -3, 0.039, 1 / 3, 1e-12, 123.456, 150000, 3e9, 2.5e20, Inf, -Inf, NA)
  s <- io_fmt_num(v)
  expect_identical(s[c(1:3, 8)], c("0", "12", "-3", "150000"))
  expect_identical(s[7], "123.4560")
  expect_identical(s[11:13], c(".inf", "-.inf", "~"))
  expect_true(grepl(".", s[10], fixed = TRUE))
  x <- list(a = v[1:12], d = as.Date("2027-01-01"), t = TRUE, f = FALSE, s = "März",
            e = list(), m = list(k = 0.1))
  f <- tempfile(fileext = ".yaml")
  io_write_yaml(x, f, header = c("Kopfzeile", "zweite Zeile"))
  expect_identical(readLines(f, n = 1L, encoding = "UTF-8"), "# Kopfzeile")
  y <- io_unmark(io_read_yaml_utf8(f))
  expect_identical(y$a, v[1:12])
  expect_identical(y$d, "2027-01-01")
  expect_identical(y$t, TRUE)
  expect_identical(y$f, FALSE)
  expect_identical(y$s, "März")
  expect_identical(y$m$k, 0.1)
  expect_length(y$e, 0L)
})
