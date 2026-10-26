# Parameterbibliothek (WS-A, Spec 00 Abschnitte 4.7 Schichten 3-4, 4.9, 4.10).
# Ein Eintrag je Datei, id = Pfad relativ zur Bibliothekswurzel ohne Endung; Wurzeln: Paket-
# bibliothek (Schicht 3), danach Nutzerbibliotheken (Schicht 4; spaeter gewinnt, Ueberschattung =
# Warnung; Listenform nur dort, R-13). Aufloesung von `from:` an der Fundstelle (Nutzlast unter
# die lokale Angabe gemischt, lokal gewinnt; Ketten ueber `entry$from`, Zyklus = Fehler; Nutzlast
# ohne Map-Struktur bzw. Wertform ersetzt den Knoten, R-87; Overlay-Eintraege mischen immer,
# R-119), automatische Wahl der legal/*-Eintraege je Thema mit Freigaberegel (R-80),
# Gueltigkeits- und Standpruefung (vofi_warning_library_outdated) und Bibliotheksstand
# (inst/extdata/library/VERSION).

lib_state <- new.env(parent = emptyenv())

#' Einträge der Parameterbibliothek
#'
#' Listet die Einträge der Parameterbibliothek (Paketbibliothek und Nutzerbibliotheken) mit
#' Metadaten und Gültigkeit zum Datum (Spec 00, Abschnitte 4.9, 4.10). Bei gleicher id gewinnt
#' die spätere Wurzel; überschattete Einträge erscheinen nicht, die Spalte `shadows` nennt die
#' überschattete Wurzel.
#'
#' Spalten: `entry` (id), `block`, `topic`, `label`, `quality`, `as_of`, `accessed`,
#' `valid_from`, `valid_to`, `reform`, `release_status`, `legal_status`, `valid` (Datum liegt in
#' `[valid_from, valid_to)`), `outdated` (außerhalb der Gültigkeit oder Stand älter als 6 Monate
#' vor dem Datum, bei Prozess- und Kalibrierungseinträgen 12 Monate), `source_type` (`library`
#' bzw. `user_library`), `root`, `file`, `shadows`, `problems` (Schemaverstöße des Eintrags).
#'
#' @param block `NULL` oder Zielblock (z. B. `"funding"`, `"market"`).
#' @param library_paths Bibliothekswurzeln (Paketbibliothek wird stets zuerst durchsucht).
#' @param date Stichtag der Gültigkeitsprüfung (Default: heute).
#' @return Data Frame mit einer Zeile je Eintrag (sortiert nach id).
#' @family Einlesen
#' @examples
#' lib <- vofi_library()
#' nrow(lib)
#' @export
vofi_library <- function(block = NULL, library_paths = vofi_library_paths(), date = NULL) {
  if (!is.null(block) && (!utl_is_string(block) || !vocab_has("library_block", block))) {
    vofi_abort("core.arg_invalid", arg = "block", value = utl_collapse(format(block)),
               choices = utl_collapse(vocab_codes("library_block")), .class = "vofi_error_input")
  }
  if (!is.character(library_paths)) {
    vofi_abort("core.arg_character", arg = "library_paths", .class = "vofi_error_input")
  }
  date <- if (is.null(date)) Sys.Date() else utl_as_date(date, "date")
  if (length(date) != 1L) {
    vofi_abort("core.arg_scalar", arg = "date", .class = "vofi_error_input")
  }
  index <- lib_index(library_paths)
  ids <- utl_sort(names(index$entries))
  recs <- lapply(ids, function(id) index$entries[[id]])
  if (!is.null(block)) recs <- Filter(function(r) identical(r$block, block), recs)
  if (length(recs) == 0L) return(lib_table(list(), date, index))
  lib_table(recs, date, index)
}

#' Tabelle der Bibliothekseinträge (für `vofi_library()`)
#' @noRd
lib_table <- function(recs, date, index) {
  chr <- function(f) vapply(recs, function(r) as.character(r[[f]] %||% NA_character_)[1L], "")
  dt <- function(f) {
    as.Date(vapply(recs, function(r) as.double(r[[f]] %||% NA_real_), double(1)),
            origin = "1970-01-01")
  }
  valid <- vapply(recs, function(r) lib_valid_at(r, date), logical(1))
  stale <- vapply(recs, function(r) lib_stale_at(r, date), logical(1))
  data.frame(
    entry = chr("id"), block = chr("block"), topic = chr("topic"), label = chr("label"),
    quality = chr("quality"), as_of = dt("as_of"), accessed = dt("accessed"),
    valid_from = dt("valid_from"), valid_to = dt("valid_to"), reform = chr("reform"),
    release_status = chr("release_status"), legal_status = chr("legal_status"),
    valid = valid, outdated = !valid | stale, source_type = chr("source_type"),
    root = chr("root"), file = chr("file"),
    shadows = vapply(recs, function(r) utl_collapse(index$shadowed[[r$id]] %||% character(0)),
                     ""),
    problems = vapply(recs, function(r) utl_collapse(r$problems, "; "), ""),
    stringsAsFactors = FALSE
  )
}

#' Bibliothekspfade
#'
#' Gibt die Bibliothekspfade zurück (Paketbibliothek und Option `vofi.library_paths`) bzw. ergänzt
#' Nutzerpfade. Die Reihenfolge ist die Suchreihenfolge der Schichten 3 und 4 (Spec 00,
#' Abschnitte 2.12, 4.7, 4.9): zuerst die Paketbibliothek, dann die Option, dann `add`; bei
#' gleicher id gewinnt der spätere Pfad (Überschattung mit Warnung).
#'
#' @param add optional: zusätzliche Bibliothekswurzeln.
#' @return Zeichenvektor der Pfade.
#' @family Einlesen
#' @examples
#' vofi_library_paths()
#' @export
vofi_library_paths <- function(add = NULL) {
  if (!is.null(add) && (!is.character(add) || anyNA(add))) {
    vofi_abort("core.arg_character", arg = "add", .class = "vofi_error_input")
  }
  pkg <- lib_package_root()
  opt <- getOption("vofi.library_paths", character(0))
  if (!is.character(opt)) opt <- character(0)
  out <- c(if (nzchar(pkg)) pkg, as.character(opt), add)
  unique(out[nzchar(out)])
}

#' Wurzel der Paketbibliothek (`inst/extdata/library`)
#' @return Pfad oder `""`.
#' @noRd
lib_package_root <- function() system.file("extdata", "library", package = "vofi")

#' Ordner der Bibliothek und ihr Zielblock (4.9; `prices/` -> `market`)
#' @noRd
lib_folders <- function() {
  c(funding = "funding", financing = "financing", legal = "legal", prices = "market",
    market = "market", costs = "costs", processes = "processes", components = "components",
    valuation = "valuation")
}

#' Zulässige Wurzelschlüssel eines Eintrags (4.9, R-88)
#' @noRd
lib_root_keys <- function() {
  c("id", "block", "topic", "schema_version", "label", "source", "as_of", "accessed",
    "valid_from", "valid_to", "quality", "reform", "release", "uncertainty", "from",
    "description", "references", "quality_detail", "legal_state", "notes", "fallback", "values")
}

#' Pflichtschlüssel eines Eintrags (4.9; `valid_to` darf `null` sein)
#' @noRd
lib_required_keys <- function() {
  c("id", "block", "schema_version", "label", "source", "as_of", "valid_from", "valid_to",
    "quality", "values")
}

#' Wurzeln mit Schicht und Quellart (Paketbibliothek: Schicht 3, sonst Schicht 4)
#' @param library_paths Pfade.
#' @return Data Frame `root`, `user`, `layer`, `source_type`.
#' @noRd
lib_roots <- function(library_paths) {
  pkg <- lib_package_root()
  paths <- as.character(library_paths %||% character(0))
  paths <- paths[!is.na(paths) & nzchar(paths)]
  norm <- function(p) normalizePath(p, winslash = "/", mustWork = FALSE)
  roots <- unique(c(if (nzchar(pkg)) norm(pkg), vapply(paths, norm, "", USE.NAMES = FALSE)))
  user <- if (nzchar(pkg)) roots != norm(pkg) else rep(TRUE, length(roots))
  data.frame(root = roots, user = user, layer = ifelse(user, 4L, 3L),
             source_type = ifelse(user, "user_library", "library"), stringsAsFactors = FALSE)
}

#' Index der Bibliothek (zwischengespeichert nach Dateistand)
#' @param library_paths Bibliothekswurzeln.
#' @return Liste `entries` (nach id), `shadowed` (id -> überschattete Wurzeln), `roots`.
#' @noRd
lib_index <- function(library_paths) {
  roots <- lib_roots(library_paths)
  files <- lapply(roots$root, lib_root_files)
  sig <- stable_hash(list(roots$root, lapply(files, function(f) {
    if (length(f) == 0L) return(NULL)
    info <- file.info(f)
    list(f, as.double(info$mtime), info$size)
  })))
  key <- paste(roots$root, collapse = "|")
  hit <- lib_state$index[[key]]
  if (!is.null(hit) && identical(hit$sig, sig)) return(hit$index)
  entries <- list()
  shadowed <- list()
  for (i in seq_len(nrow(roots))) {
    for (f in files[[i]]) {
      for (rec in lib_read_file(f, roots$root[i], roots$user[i])) {
        rec$layer <- roots$layer[i]
        rec$source_type <- roots$source_type[i]
        if (!is.null(entries[[rec$id]])) {
          shadowed[[rec$id]] <- c(shadowed[[rec$id]], entries[[rec$id]]$root)
        }
        entries[[rec$id]] <- rec
      }
    }
  }
  index <- list(entries = entries, shadowed = shadowed, roots = roots)
  if (is.null(lib_state$index)) lib_state$index <- list()
  lib_state$index[[key]] <- list(sig = sig, index = index)
  index
}

#' YAML-Dateien einer Wurzel in den Ordnern der Bibliothek
#' @noRd
lib_root_files <- function(root) {
  if (!dir.exists(root)) return(character(0))
  out <- character(0)
  for (d in names(lib_folders())) {
    dir <- file.path(root, d)
    if (!dir.exists(dir)) next
    out <- c(out, list.files(dir, pattern = "\\.ya?ml$", recursive = TRUE, full.names = TRUE))
  }
  utl_sort(normalizePath(out, winslash = "/", mustWork = FALSE))
}

#' Datei der Bibliothek lesen (ein Eintrag; Listenform nur in Nutzerbibliotheken, R-13)
#' @return Liste von Einträgen.
#' @noRd
lib_read_file <- function(file, root, user) {
  rel <- substring(file, nchar(root) + 2L)
  expected <- sub("\\.ya?ml$", "", rel)
  raw <- tryCatch(io_unmark(io_read_yaml_utf8(file), ""), error = function(e) e)
  if (inherits(raw, "error")) {
    return(list(lib_broken_entry(expected, file, root, rel, conditionMessage(raw))))
  }
  if (is.list(raw) && !is_map(raw) && length(raw) > 0L) {
    if (!user) {
      return(list(lib_broken_entry(expected, file, root, rel, lbl("io.library.list_form"))))
    }
    return(lapply(raw, function(e) lib_parse_entry(e, rel, root, user, expected = NULL)))
  }
  list(lib_parse_entry(raw, rel, root, user, expected = expected))
}

#' Eintrag, der sich nicht lesen ließ (erscheint mit Befund in `vofi_library()`)
#' @noRd
lib_broken_entry <- function(id, file, root, rel, problem) {
  list(id = id, block = NA_character_, file = rel, root = root, values = NULL,
       problems = problem, quality = NA_character_)
}

#' Rohform eines Eintrags in den Index übernehmen und prüfen (4.9, R-88)
#' @param raw Liste (eine Datei bzw. ein Listenelement).
#' @param rel Datei relativ zur Wurzel.
#' @param root Wurzel.
#' @param user Nutzerbibliothek?
#' @param expected erwartete id (Dateipfad) bzw. `NULL` (Listenform).
#' @return Eintrag.
#' @noRd
lib_parse_entry <- function(raw, rel, root, user, expected = NULL) {
  probs <- character(0)
  if (!is_map(raw)) {
    return(lib_broken_entry(expected %||% rel, rel, root, rel, lbl("io.library.not_map")))
  }
  id <- if (utl_is_string(raw$id)) raw$id else expected %||% rel
  if (!is.null(expected) && !identical(raw$id, expected)) {
    probs <- c(probs, lbl("io.library.id_mismatch", id = format(raw$id %||% "NULL"),
                          expected = expected))
  }
  unknown <- setdiff(names(raw), lib_root_keys())
  if (length(unknown) > 0L) {
    probs <- c(probs, lbl("io.library.unknown_keys", keys = utl_collapse(unknown)))
  }
  missing <- setdiff(lib_required_keys(), names(raw))
  if (length(missing) > 0L) {
    probs <- c(probs, lbl("io.library.missing_keys", keys = utl_collapse(missing)))
  }
  folder <- path_split(gsub("/", ".", id, fixed = TRUE))[1L]
  want <- unname(lib_folders()[folder])
  if (!is.na(want) && utl_is_string(raw$block) && !identical(raw$block, want)) {
    probs <- c(probs, lbl("io.library.block_mismatch", block = raw$block, expected = want))
  }
  if (!is.null(raw$from) && !utl_is_library_id(raw$from)) {
    probs <- c(probs, lbl("io.library.from_invalid", value = utl_collapse(format(raw$from))))
  }
  d <- function(x) {
    if (is.null(x)) return(as.Date(NA))
    out <- tryCatch(utl_as_date(as.character(x)), error = function(e) as.Date(NA))
    if (length(out) != 1L) as.Date(NA) else out
  }
  for (f in c("as_of", "valid_from")) {
    if (!is.null(raw[[f]]) && is.na(d(raw[[f]]))) {
      probs <- c(probs, lbl("io.library.date_invalid", field = f,
                            value = utl_collapse(format(raw[[f]]))))
    }
  }
  list(
    id = id, block = as.character(raw$block %||% NA_character_)[1L],
    topic = as.character(raw$topic %||% NA_character_)[1L], label = raw$label,
    file = rel, root = root, user = user,
    quality = as.character(raw$quality %||% NA_character_)[1L],
    quality_detail = raw$quality_detail %||% list(),
    as_of = d(raw$as_of), accessed = d(raw$accessed), valid_from = d(raw$valid_from),
    valid_to = d(raw$valid_to), reform = as.character(raw$reform %||% NA_character_)[1L],
    release = raw$release,
    release_status = as.character(raw$release$status %||% NA_character_)[1L],
    legal_state = raw$legal_state,
    legal_status = as.character(raw$legal_state$status %||% NA_character_)[1L],
    from = raw$from, values = raw$values, uncertainty = raw$uncertainty,
    fallback = raw$fallback, description = raw$description, notes = raw$notes,
    problems = probs
  )
}

#' Liegt das Datum in `[valid_from, valid_to)`?
#' @noRd
lib_valid_at <- function(rec, date) {
  if (is.null(date) || is.na(date)) return(TRUE)
  vf <- rec$valid_from %||% as.Date(NA)
  vt <- rec$valid_to %||% as.Date(NA)
  (is.na(vf) || vf <= date) && (is.na(vt) || date < vt)
}

#' Ist der Stand (`as_of`) zu alt? 6 Monate, Prozess- und Kalibrierungseinträge 12 Monate (4.9)
#' @noRd
lib_stale_at <- function(rec, date) {
  if (is.null(date) || is.na(date) || is.null(rec$as_of) || is.na(rec$as_of)) return(FALSE)
  months <- if (identical(rec$block, "processes")) 12L else 6L
  rec$as_of < grid_add_months(date, -months)
}

#' Eintrag nach id (oder `NULL`)
#' @noRd
lib_get <- function(index, id) {
  if (!utl_is_string(id)) return(NULL)
  index$entries[[id]]
}

#' Nutzlast eines Eintrags mit aufgelöster Kette (`entry$from`, 4.9)
#' @param index Bibliotheksindex.
#' @param id Bibliotheks-id.
#' @param path Fundstelle (für Meldungen).
#' @param stack bisherige Kette (Zyklusschutz).
#' @return Liste `values`, `origin` (benannter Vektor Unterpfad -> id), `chain` (ids), `record`;
#'   `NULL`, wenn der Eintrag fehlt.
#' @noRd
lib_payload <- function(index, id, path = "", stack = character(0)) {
  if (id %in% stack) {
    chain <- utl_collapse(c(stack, id), " -> ")
    vofi_abort(scn_key("validation.library.cycle", "io.library.cycle", path = path,
                       chain = chain),
               path = path, chain = chain, .class = "vofi_error_validation")
  }
  rec <- lib_get(index, id)
  if (is.null(rec)) return(NULL)
  if (length(rec$problems) > 0L) {
    detail <- utl_collapse(rec$problems, "; ")
    vofi_abort(scn_key("validation.library.entry_invalid", "io.library.entry_invalid",
                       path = path, id = id, detail = detail),
               path = path, id = id, detail = detail, .class = "vofi_error_validation")
  }
  own <- rec$values
  own_leaves <- scn_leaves(own)
  if (is.null(rec$from)) {
    origin <- stats::setNames(rep(id, length(own_leaves)), own_leaves)
    return(list(values = own, origin = origin, chain = id, record = rec))
  }
  par <- lib_payload(index, rec$from, path, c(stack, id))
  if (is.null(par)) {
    sug <- utl_suggest_text(rec$from, names(index$entries))
    vofi_abort(scn_key("validation.library.unknown_entry", "io.library.entry_unknown",
                       path = path, id = rec$from, suggestion = sug),
               path = path, id = rec$from, suggestion = sug, .class = "vofi_error_validation")
  }
  vals <- if (is_map(par$values) && is_map(own)) scn_merge(par$values, own) else own %||%
    par$values
  origin <- par$origin
  origin[own_leaves] <- id
  list(values = vals, origin = origin, chain = c(id, par$chain), record = rec)
}

#' Qualitätsstufe eines Blatts aus `quality_detail` (längster passender Unterpfad, R-88)
#' @param rec Eintrag.
#' @param subpath Unterpfad in `values`.
#' @return Stufe `A`–`D`.
#' @noRd
lib_quality_of <- function(rec, subpath) {
  qd <- rec$quality_detail %||% list()
  keys <- names(qd)
  if (length(keys) > 0L && nzchar(subpath)) {
    ok <- keys[subpath == keys | startsWith(subpath, paste0(keys, "."))]
    if (length(ok) > 0L) return(as.character(qd[[ok[which.max(nchar(ok))]]]))
  }
  rec$quality %||% NA_character_
}

#' Ist die Nutzlast eine Map mehrerer Overlay-Vorlagen (Auswahl mit `use:`, R-87)?
#' @noRd
lib_is_template_map <- function(x) {
  is_map(x) && length(x) > 0L && all(vapply(x, function(e) {
    is_map(e) && (utl_has_name(e, "dist") || utl_has_name(e, "type"))
  }, logical(1)))
}

#' Bibliothekskontext eines Auflösungslaufs
#' @param index Bibliotheksindex.
#' @param prv Herkunftsspeicher.
#' @param mode `"error"` (unbekannte Einträge sind Fehler) oder `"drop"` (Defaults-Dateien:
#'   fehlender Eintrag -> Knoten entfällt mit Hinweis, solange die Paketbibliothek unvollständig
#'   ist).
#' @return Umgebung.
#' @noRd
lib_context <- function(index, prv = NULL, mode = "error") {
  lc <- new.env(parent = emptyenv())
  lc$index <- index
  lc$prv <- prv
  lc$mode <- mode
  lc$layer <- NULL
  lc$variant <- NA_character_
  lc$used <- list()
  lc$missing <- character(0)
  lc$shadow_warned <- character(0)
  lc
}

#' Bibliotheksverweise `from:` in einem Teilbaum auflösen (Schicht 3, 4.9)
#' @param x Teilbaum (Rohform bzw. teilweise normalisiert).
#' @param path Pfad von `x`.
#' @param lc Bibliothekskontext.
#' @return aufgelöster Teilbaum (`NULL`, wenn ein Verweis im Modus `"drop"` entfällt).
#' @noRd
lib_resolve <- function(x, path, lc, overlay_entry = FALSE) {
  if (!is.list(x) || is.data.frame(x) || io_is_raw_num(x) || node_is(x)) return(x)
  if (is_map(x) && utl_has_name(x, "from")) {
    return(lib_resolve_site(x, path, lc, overlay_entry = overlay_entry))
  }
  nms <- names(x)
  # Eintraege von stochastic.parameters/processes sind Overlay-Eintraege (R-119)
  entries <- path %in% c("stochastic.parameters", "stochastic.processes")
  dropped <- logical(length(x))
  for (i in seq_along(x)) {
    if (is.null(x[[i]])) next                       # ~ bleibt als Loeschanweisung erhalten
    seg <- if (!is.null(nms) && nzchar(nms[i])) nms[i] else as.character(i)
    v <- lib_resolve(x[[i]], path_join(path, seg), lc, overlay_entry = entries)
    if (is.null(v)) {
      dropped[i] <- TRUE
    } else {
      x[[i]] <- v
    }
  }
  if (any(dropped)) x <- x[!dropped]
  x
}

#' Eine Fundstelle `{from: <id>, use: <unterpfad>, …lokal}` auflösen (4.9, R-87, R-110, R-119)
#' @noRd
lib_resolve_site <- function(x, path, lc, overlay_entry = NULL) {
  from <- x[["from"]]
  if (!utl_is_library_id(from)) {
    vofi_abort("validation.library.ref_not_id", path = path_join(path, "from"),
               value = utl_collapse(format(from)), .class = "vofi_error_validation")
  }
  if (is.null(overlay_entry)) {
    overlay_entry <- grepl("^stochastic[.](parameters|processes)[.][^.]+$", path)
  }
  use <- x[["use"]]
  if (!is.null(use) && !utl_is_string(use)) {
    use_txt <- utl_collapse(format(use))
    vofi_abort(scn_key("validation.library.use_missing", "io.library.use_missing",
                       path = path, id = from, use = use_txt),
               path = path, id = from, use = use_txt, .class = "vofi_error_validation")
  }
  local <- x[setdiff(names(x), c("from", "use"))]
  res <- lib_payload(lc$index, from, path)
  if (is.null(res)) {
    if (identical(lc$mode, "drop")) {
      lc$missing <- unique(c(lc$missing, from))
      return(NULL)
    }
    sug <- utl_suggest_text(from, names(lc$index$entries))
    vofi_abort(scn_key("validation.library.unknown_entry", "io.library.entry_unknown",
                       path = path, id = from, suggestion = sug),
               path = path, id = from, suggestion = sug, .class = "vofi_error_validation")
  }
  lib_warn_shadowed(lc, res$chain)
  payload <- res$values
  origin <- res$origin
  if (!is.null(use)) {
    if (!path_exists(payload, use)) {
      if (identical(lc$mode, "drop")) {
        lc$missing <- unique(c(lc$missing, paste0(from, "#", use)))
        return(NULL)
      }
      key <- if (overlay_entry) {
        scn_key("validation.stochastic.template_use_missing", "io.library.use_missing",
                path = path, id = from, use = use)
      } else {
        scn_key("validation.library.use_missing", "io.library.use_missing",
                path = path, id = from, use = use)
      }
      vofi_abort(key, path = path, id = from, use = use, .class = "vofi_error_validation")
    }
    payload <- path_get(payload, use)
    keep <- names(origin) == use | startsWith(names(origin), paste0(use, "."))
    origin <- origin[keep]
    names(origin) <- sub(paste0("^", gsub(".", "[.]", use, fixed = TRUE), "[.]?"), "",
                         names(origin))
  } else if (overlay_entry && lib_is_template_map(payload)) {
    vofi_abort(scn_key("validation.stochastic.template_use_missing", "io.library.use_missing",
                       path = path, id = from, use = ""),
               path = path, id = from, use = "", .class = "vofi_error_validation")
  }
  lib_record_payload(lc, payload, path, res, origin, use)
  lc$used[[length(lc$used) + 1L]] <- list(id = from, chain = res$chain, path = path)
  payload <- lib_resolve(payload, path, lc)
  local <- lib_resolve(local, path, lc)
  replace <- !is_map(payload) ||
    (!overlay_entry && is_value_form(payload, path, kind_of = scn_kind_of))
  if (replace) {
    if (length(local) > 0L) {
      keys <- utl_collapse(names(local))
      vofi_abort(scn_key("validation.library.local_keys", "io.library.local_keys",
                         path = path, id = from, keys = keys),
                 path = path, id = from, keys = keys, .class = "vofi_error_validation")
    }
    return(payload)
  }
  scn_merge(payload, local, path)
}

#' Blätter einer Nutzlast mit Bibliotheksherkunft aufzeichnen (4.8)
#' @noRd
lib_record_payload <- function(lc, payload, path, res, origin, use) {
  if (is.null(lc$prv)) return(invisible(NULL))
  leaves <- scn_leaves(lib_strip_refs(payload), path)
  if (length(leaves) == 0L && !is_map(payload)) leaves <- path
  for (p in leaves) {
    rel <- if (identical(p, path)) "" else substring(p, nchar(path) + 2L)
    nm <- names(origin) %||% character(0)
    j <- match(rel, nm)
    if (is.na(j) && nzchar(rel)) j <- which(startsWith(nm, paste0(rel, ".")))[1L]
    oid <- if (!is.na(j)) unname(origin[j]) else res$record$id
    rec <- lib_get(lc$index, oid) %||% res$record
    sub <- path_join(if (identical(oid, res$record$id)) use, rel)
    info <- prv_info(lc$layer %||% rec$layer, rec$source_type, file = rec$file, entry = rec$id,
                     variant = lc$variant, valid_from = rec$valid_from, valid_to = rec$valid_to,
                     as_of = rec$as_of, accessed = rec$accessed,
                     quality = lib_quality_of(rec, sub))
    prv_set(lc$prv, p, info)
  }
  invisible(NULL)
}

#' Verweise `{from, use}` aus einem Teilbaum entfernen (nur für die Aufzeichnung der Blätter)
#' @noRd
lib_strip_refs <- function(x) {
  if (!is_map(x) || node_is(x) || length(x) == 0L) return(x)
  if (utl_has_name(x, "from")) x <- x[setdiff(names(x), c("from", "use"))]
  for (nm in names(x)) {
    if (is.list(x[[nm]])) x[[nm]] <- lib_strip_refs(x[[nm]])
  }
  x
}

#' Überschatteten Eintrag einmal je Auflösung melden (Schicht 4, 4.7)
#' @noRd
lib_warn_shadowed <- function(lc, ids) {
  for (id in ids) {
    sh <- lc$index$shadowed[[id]]
    if (length(sh) == 0L || id %in% lc$shadow_warned) next
    lc$shadow_warned <- c(lc$shadow_warned, id)
    rec <- lib_get(lc$index, id)
    vofi_warn("io.library.shadowed", id = id, root = rec$root %||% "",
              shadowed = utl_collapse(sh))
  }
  invisible(NULL)
}

#' legal/*-Einträge je Thema zum Rechtsstand wählen (4.10, R-80)
#'
#' Wählbar sind Einträge mit `valid_from <= legal_state < valid_to`, deren Reformcode (falls
#' gesetzt) in `pending_reforms` steht und die die Freigaberegel erfüllen (A/B; C nur mit
#' `release.status: released` oder dem Sammelcode `unreleased`; D nur über ihren Schaltercode).
#' Einträge mit Reform haben Vorrang, sonst gewinnt das größte `valid_from`. Ohne wählbaren
#' Eintrag ist das Thema inaktiv (nicht in der Liste).
#' @param index Bibliotheksindex.
#' @param legal_state Rechtsstand (`Date`).
#' @param pending Reform- und Schaltercodes.
#' @return benannte Liste `<topic> = list(entry, values, quality, unreleased, chain)`.
#' @noRd
lib_select_legal <- function(index, legal_state, pending = character(0)) {
  recs <- Filter(function(r) identical(r$block, "legal") && utl_is_string(r$topic) &&
                   !is.na(r$topic) && length(r$problems) == 0L, index$entries)
  if (length(recs) == 0L || is.null(legal_state) || is.na(legal_state)) return(list())
  pending <- as.character(pending %||% character(0))
  ok <- vapply(recs, function(r) lib_legal_selectable(r, legal_state, pending), logical(1))
  recs <- recs[ok]
  topics <- utl_sort(unique(vapply(recs, function(r) r$topic, "")))
  out <- list()
  for (tp in topics) {
    cand <- Filter(function(r) identical(r$topic, tp), recs)
    has_reform <- vapply(cand, function(r) !is.na(r$reform), logical(1))
    if (any(has_reform)) cand <- cand[has_reform]
    vf <- vapply(cand, function(r) as.double(r$valid_from %||% -Inf), double(1))
    ids <- vapply(cand, function(r) r$id, "")
    best <- cand[[order(vf, ids, method = "radix")[length(cand)]]]
    pl <- lib_payload(index, best$id, paste0("legal.", tp))
    out[[tp]] <- list(entry = best$id, values = pl$values, quality = best$quality,
                      unreleased = identical(best$quality, "C") &&
                        !identical(best$release_status, "released"),
                      chain = pl$chain)
  }
  out
}

#' Ist ein legal/*-Eintrag zum Rechtsstand automatisch wählbar? (4.10, R-80)
#' @noRd
lib_legal_selectable <- function(rec, legal_state, pending) {
  if (!lib_valid_at(rec, legal_state)) return(FALSE)
  reform <- rec$reform
  if (!is.na(reform) && !(reform %in% pending)) return(FALSE)
  switch(rec$quality %||% "",
    A = , B = TRUE,
    C = identical(rec$release_status, "released") || "unreleased" %in% pending,
    D = !is.na(reform),
    FALSE
  )
}

#' Bibliotheksstand `JJJJ.MM.n` der Paketbibliothek (R-80)
#' @param library_paths Bibliothekswurzeln (die Paketbibliothek ist maßgeblich).
#' @return Zeichenkette oder `NA_character_`.
#' @noRd
lib_version <- function(library_paths = vofi_library_paths()) {
  roots <- lib_roots(library_paths)
  pkg <- roots$root[!roots$user]
  if (length(pkg) == 0L) return(NA_character_)
  f <- file.path(pkg[1L], "VERSION")
  if (!file.exists(f)) return(NA_character_)
  v <- trimws(io_read_lines_utf8(f))
  v <- v[nzchar(v) & !startsWith(v, "#")]
  if (length(v) == 0L) NA_character_ else v[1L]
}
