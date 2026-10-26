# Tests für R/scenario-provenance.R (WS-A; Spec 00 Abschnitt 4.8).

test_that("Herkunftsspeicher: die letzte Angabe zu Blatt, Vorfahre bzw. Nachfahre gilt", {
  prv <- prv_new()
  g <- prv_info(1L, "global", file = "defaults/global.yaml", entry = "global")
  prv_record_tree(prv, list(a = list(b = 1, c = 2), d = list()), "", g)
  expect_identical(sort(names(prv$rec)), c("a.b", "a.c", "d"))
  v <- prv_info(7L, "variant", variant = "v1")
  prv_set(prv, "a", v)                             # Teilbaum als Ganzes ersetzt
  expect_identical(prv_lookup(prv, "a.b")$layer, 7L)
  o <- prv_info(8L, "override")
  prv_set(prv, "a.c.x", o)                         # Teil-Map in eine Wertform gemischt
  expect_identical(prv_lookup(prv, "a.c")$source_type, "override")
  expect_identical(prv_lookup(prv, "a.b")$source_type, "variant")
  expect_null(prv_lookup(prv, "z"))
  expect_null(prv_lookup(prv_new(), "a"))
})

test_that("Herkunftstabelle mit den Spalten aus 4.8, Qualität und Fundstelle je Blatt", {
  prv <- prv_new()
  lib <- prv_info(3L, "library", file = "prices/x.yaml", entry = "prices/x",
                  valid_from = as.Date("2026-01-01"), as_of = as.Date("2026-10-25"),
                  quality = "B")
  prv_set(prv, c("market.inflation", "market.co2"), lib, quality = c("A", NA))
  prv_record_tree(prv, list(project = list(horizon_years = 30)), "",
                  prv_info(5L, "scenario", file = "s.yaml"),
                  locations = c(project = "Zeile 2", "project.horizon_years" = "Zeile 3"))
  x <- list(market = list(inflation = node_const(0.02), co2 = node_const(55)),
            project = list(horizon_years = 30L, perspective = "wu_privat"))
  tab <- prv_table(prv, x, variant = "base")
  expect_identical(names(tab), prv_columns())
  expect_identical(tab$path, c("market.inflation", "market.co2", "project.horizon_years",
                               "project.perspective"))
  expect_identical(tab$quality, c("A", "B", NA, NA))
  expect_identical(tab$layer, c(3L, 3L, 5L, 0L))
  expect_identical(tab$source_type[4], "type_default")
  expect_identical(tab$location[3], "Zeile 3")
  expect_identical(tab$valid_from[1], as.Date("2026-01-01"))
  expect_identical(tab$variant, rep("base", 4L))
  expect_s3_class(tab$as_of, "Date")
  e <- prv_empty_table()
  expect_identical(names(e), prv_columns())
  expect_identical(nrow(prv_table(prv, list(), "base")), 0L)
})

test_that("Blattpfade: Knoten, Wertformen und Rohzahlen sind Blätter, leere Maps nicht", {
  x <- list(m = list(a = node_const(1), b = list(ref = "market.x"), c = list(d = list()),
                     e = list(from = "prices/x", use = "y"), f = list(1, 2), g = character(0)))
  expect_identical(scn_leaves(x), c("m.a", "m.b", "m.e", "m.f", "m.g"))
  expect_identical(scn_leaves(list(b = list(ref = "market.x"))), "b.ref")
  expect_identical(scn_leaves(list(p = list()), empty_seq = TRUE), "p")
  expect_identical(scn_leaves(list(p = structure(list(), names = character(0))),
                              empty_seq = TRUE), character(0))
  expect_identical(scn_leaves(NULL), character(0))
  expect_identical(scn_leaves(list(components = list(k = list(from = "funding/a", x = 1)))),
                   c("components.k.from", "components.k.x"))
})

test_that("Herkunft des eingelesenen Szenarios: Schicht 5, Overlay Schicht 6 mit eigener Datei", {
  x <- list(project = list(horizon_years = 3L),
            stochastic = list(parameters = list(k = list(target = "market.x", dist = "normal"))))
  tab <- scn_provenance(x, layer = c(stochastic = 6L), source_type = c(stochastic = "overlay"),
                        file = "s.yaml", files = c(stochastic = "o.yaml"),
                        locations = c("project.horizon_years" = "Zeile 4"))
  expect_identical(tab$layer, c(5L, 6L, 6L))
  expect_identical(tab$source_type, c("scenario", "overlay", "overlay"))
  expect_identical(tab$file, c("s.yaml", "o.yaml", "o.yaml"))
  expect_identical(tab$location, c("Zeile 4", NA, NA))
  expect_identical(nrow(scn_provenance(list())), 0L)
  ent <- scn_provenance(list(a = 1), entry = c(a = "rule:x"))
  expect_identical(ent$entry, "rule:x")
})
