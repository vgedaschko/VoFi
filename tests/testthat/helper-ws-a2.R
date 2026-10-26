# Testhelfer von WS-A2 (Excel-Eingabe und Vorlage; Spec 00 Abschnitt 4.14).

#' Blöcke eines Szenarios ohne Attribute (Vergleich der kanonischen Liste)
xl_blocks <- function(sc) {
  x <- unclass(sc)
  attributes(x) <- list(names = names(x))
  x
}

#' Pfad einer Fixture von WS-A2
xl_fixture <- function(...) testthat::test_path("fixtures", "excel", ...)

#' Temporäre xlsx-Datei (wird am Ende des Tests gelöscht)
xl_tempfile <- function(env = parent.frame()) {
  withr::local_tempfile(fileext = ".xlsx", .local_envir = env)
}

#' Deterministischer Lauf ohne Hinweise und ohne Veraltungswarnungen der Bibliothek
#' (`costs/bewirtschaftung_immowertv_2026` gilt bis 2027-01-01, vgl. helper-ws-a.R)
xl_quiet_run <- function(sc) {
  withCallingHandlers(
    vofi_run(vofi_build(sc)),
    vofi_warning_library_outdated = function(w) invokeRestart("muffleWarning"),
    message = function(m) invokeRestart("muffleMessage")
  )
}

#' Szenario als xlsx schreiben und wieder einlesen
xl_roundtrip <- function(sc, path = NULL) {
  path <- path %||% tempfile(fileext = ".xlsx")
  vofi_write_scenario(sc, path, overwrite = TRUE)
  vofi_read_scenario(path)
}

#' Erste Abweichung zweier Listen (Pfad und beide Werte) für aussagekräftige Fehlermeldungen
xl_first_diff <- function(a, b, path = "") {
  if (identical(a, b)) return(NULL)
  if (is.list(a) && is.list(b) && !is.null(names(a)) && identical(names(a), names(b))) {
    for (nm in names(a)) {
      d <- xl_first_diff(a[[nm]], b[[nm]], paste0(path, ".", nm))
      if (!is.null(d)) return(d)
    }
  }
  paste0(path, ": ", paste(utils::capture.output(utils::str(a)), collapse = " "), " <-> ",
         paste(utils::capture.output(utils::str(b)), collapse = " "))
}

#' Erwartung: Round-Trip ergibt dieselbe kanonische Liste
expect_xl_identical <- function(back, sc) {
  d <- xl_first_diff(xl_blocks(back), xl_blocks(sc))
  testthat::expect(is.null(d), paste("Round-Trip nicht identisch:", d))
  invisible(back)
}

#' Arbeitsmappe aus Blättern bauen, wie ein Nutzer sie anlegt (Zeilen als Listen von Zellen)
#'
#' `sheets`: benannte Liste Blattname -> Liste von Zeilen; jede Zeile ist eine Liste von Werten
#' (Zahl, Text, logisch, Date oder NULL für leer), Spalte für Spalte ab A. Werte der Klasse
#' `xl_text` werden als Textzelle geschrieben (auch Zahlen).
xl_make_book <- function(sheets, path) {
  wb <- openxlsx::createWorkbook()
  for (nm in names(sheets)) {
    openxlsx::addWorksheet(wb, nm)
    rows <- sheets[[nm]]
    for (i in seq_along(rows)) {
      for (j in seq_along(rows[[i]])) {
        v <- rows[[i]][[j]]
        if (is.null(v)) next
        if (inherits(v, "xl_text")) v <- as.character(unclass(v))
        openxlsx::writeData(wb, nm, v, startCol = j, startRow = i, colNames = FALSE)
      }
    }
  }
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  invisible(path)
}

#' Textzelle (Zahl als Text eingegeben)
xl_text <- function(x) structure(as.character(x), class = "xl_text")

#' Kopfzeilen eines Blatts der Vorlage (Maschinenschlüssel, deutsche Überschriften)
xl_head <- function(role) {
  keys <- io_xl_fixed_columns(role)
  list(as.list(keys), as.list(vapply(keys, io_xl_column_label, "")))
}

#' Minimales Projektblatt (Schlüssel-Wert) mit Zeilen `list(pfad, wert[, wertform, optionen])`
xl_kv_sheet <- function(rows) {
  head <- xl_head("project")
  body <- lapply(rows, function(r) {
    cells <- vector("list", 11L)
    cells[1L] <- list(r[[1L]])
    cells[5L] <- list(r[[2L]])
    if (length(r) >= 3L) cells[4L] <- list(r[[3L]])
    if (length(r) >= 4L) cells[6L] <- list(r[[4L]])
    cells
  })
  c(head, body)
}

#' Explizite NULL-Einträge rekursiv entfernen (YAML schreibt sie nicht, Excel behält sie)
xl_drop_null <- function(x) {
  if (!is.list(x) || is.data.frame(x)) return(x)
  if (!is.null(names(x))) {
    keep <- !vapply(x, is.null, logical(1))
    x <- x[keep]
  }
  for (i in seq_along(x)) if (is.list(x[[i]])) x[[i]] <- xl_drop_null(x[[i]])
  x
}

#' Zellinhalt eines Blatts einer xlsx-Datei (read.xlsx ohne Kopfzeile)
xl_read_sheet <- function(path, sheet) {
  openxlsx::read.xlsx(path, sheet = sheet, colNames = FALSE, skipEmptyRows = FALSE,
                      skipEmptyCols = FALSE, na.strings = character(0))
}

#' xlsx-Fixtures neu erzeugen (nur bei Formatänderungen von Hand aufrufen)
xl_build_fixtures <- function(dir = xl_fixture()) {
  for (name in c("skeleton", "rich")) {
    sc <- vofi_read_scenario(file.path(dir, paste0(name, ".yaml")))
    vofi_write_scenario(sc, file.path(dir, paste0(name, ".xlsx")), overwrite = TRUE)
  }
  invisible(dir)
}

#' Inhalt der Arbeitsblatt-XML-Dateien einer xlsx-Datei (Datenüberprüfung, Ausblendung)
xl_sheet_xml <- function(path, index) {
  dir <- withr::local_tempdir()
  utils::unzip(path, files = sprintf("xl/worksheets/sheet%d.xml", index), exdir = dir)
  paste(readLines(file.path(dir, "xl", "worksheets", sprintf("sheet%d.xml", index)),
                  warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

#' Ist eine Zelle gesperrt (Blattschutz)? Stil der Zelle aus `openxlsx::loadWorkbook()`;
#' ohne Stil bzw. ohne Angabe gilt die Excel-Vorgabe „gesperrt“.
xl_cell_locked <- function(wb, sheet, row, col) {
  locked <- TRUE
  for (so in wb$styleObjects) {
    if (!identical(so$sheet, sheet)) next
    if (any(so$rows == row & so$cols == col)) locked <- !isFALSE(so$style$locked)
  }
  locked
}

#' Kein Aufruf von `<<-` im Rumpf einer Funktion (Codierregel 2.7 Nr. 3)
xl_uses_superassign <- function(f) {
  walk <- function(e) {
    if (is.call(e) && identical(e[[1L]], as.name("<<-"))) return(TRUE)
    if (is.call(e) || is.pairlist(e)) {
      parts <- as.list(e)
      for (i in seq_along(parts)) {
        if (!identical(parts[[i]], quote(expr = )) && walk(parts[[i]])) return(TRUE)
      }
    }
    FALSE
  }
  walk(body(f)) || walk(formals(f))
}
