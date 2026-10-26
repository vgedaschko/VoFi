# Herkunft der Blaetter (WS-A, Spec 00 Abschnitt 4.8).
# Jede Schicht (0-8), jeder Bibliotheksverweis, jede Ableitungsregel, jede Vorlage aus
# item_defaults und jeder Expander zeichnet die Blaetter auf, die sie setzt. Massgeblich fuer ein
# Blatt der aufgeloesten Variante ist die zuletzt aufgezeichnete Angabe zum Blatt selbst, zu einem
# Vorfahren (ein Teilbaum wurde als Ganzes gesetzt) oder zu einem Nachfahren (eine Teil-Map wurde
# in eine Wertform gemischt, 4.7). Die Tabelle hat die Spalten aus 4.8.

#' Spalten der Herkunftstabelle (4.8)
#' @noRd
prv_columns <- function() {
  c("path", "layer", "source_type", "file", "entry", "location", "variant", "valid_from",
    "valid_to", "as_of", "accessed", "quality")
}

#' Neuer Herkunftsspeicher (Umgebung, damit Schichten ohne Kopien aufzeichnen)
#' @return Umgebung mit `rec` (Umgebung nach Pfad, Hash) und Zähler `seq`.
#' @noRd
prv_new <- function() {
  e <- new.env(parent = emptyenv())
  e$rec <- new.env(hash = TRUE, parent = emptyenv())
  e$seq <- 0L
  e
}

#' Herkunftsangabe einer Quelle
#' @param layer Schicht 0–8.
#' @param source_type Code aus `source_type` (Vokabular).
#' @param file,entry,location,variant,quality Zeichenketten.
#' @param valid_from,valid_to,as_of,accessed Datumswerte (aus Bibliotheksmetadaten).
#' @return Liste.
#' @noRd
prv_info <- function(layer, source_type, file = NA_character_, entry = NA_character_,
                     location = NA_character_, variant = NA_character_, valid_from = NULL,
                     valid_to = NULL, as_of = NULL, accessed = NULL, quality = NA_character_) {
  d <- function(x) if (inherits(x, "Date") && length(x) == 1L) x else as.Date(NA)
  list(layer = as.integer(layer), source_type = as.character(source_type),
       file = as.character(file %||% NA_character_)[1L],
       entry = as.character(entry %||% NA_character_)[1L],
       location = as.character(location %||% NA_character_)[1L],
       variant = as.character(variant %||% NA_character_)[1L],
       valid_from = d(valid_from), valid_to = d(valid_to), as_of = d(as_of),
       accessed = d(accessed), quality = as.character(quality %||% NA_character_)[1L])
}

#' Angaben für Pfade aufzeichnen
#' @param prv Herkunftsspeicher.
#' @param paths Zeichenvektor der Pfade.
#' @param info Angabe (`prv_info()`).
#' @param quality optional: Qualitätsstufe je Pfad (gleich lang wie `paths`).
#' @param location optional: Fundstelle je Pfad.
#' @return `invisible(NULL)`.
#' @noRd
prv_set <- function(prv, paths, info, quality = NULL, location = NULL) {
  if (is.null(prv) || length(paths) == 0L) return(invisible(NULL))
  for (i in seq_along(paths)) {
    prv$seq <- prv$seq + 1L
    rec <- info
    if (!is.null(quality) && !is.na(quality[i])) rec$quality <- quality[i]
    if (!is.null(location) && !is.na(location[i])) rec$location <- location[i]
    rec$seq <- prv$seq
    assign(paths[i], rec, envir = prv$rec)
  }
  invisible(NULL)
}

#' Alle Blätter eines Teilbaums aufzeichnen
#' @param prv Herkunftsspeicher.
#' @param x Teilbaum.
#' @param prefix Pfad des Teilbaums (`""` = Wurzel).
#' @param info Angabe.
#' @param locations optional: Fundstellen nach Pfad (`io_yaml_locations()`).
#' @return `invisible(character)` der aufgezeichneten Pfade.
#' @noRd
prv_record_tree <- function(prv, x, prefix, info, locations = NULL) {
  paths <- scn_leaves(x, prefix, empty_seq = TRUE)
  if (length(paths) == 0L && nzchar(prefix) && !is.null(x) && !is_map(x)) paths <- prefix
  loc <- if (length(locations) > 0L) {
    vapply(paths, function(p) io_location_of(locations, p), "")
  } else {
    NULL
  }
  prv_set(prv, paths, info, location = loc)
  invisible(paths)
}

#' Präfixindex der Aufzeichnungen: je Vorfahrenpfad die jüngste Aufzeichnung darunter
#' @param prv Herkunftsspeicher.
#' @return Umgebung Präfix -> Pfad der jüngsten Aufzeichnung unterhalb des Präfixes.
#' @noRd
prv_index <- function(prv) {
  nms <- ls(prv$rec, all.names = TRUE, sorted = FALSE)
  desc <- new.env(hash = TRUE, parent = emptyenv())
  if (length(nms) == 0L) return(desc)
  seqs <- vapply(nms, function(p) get(p, envir = prv$rec)$seq, integer(1), USE.NAMES = FALSE)
  segs <- strsplit(nms, ".", fixed = TRUE)
  pre <- lapply(segs, function(s) {
    k <- length(s) - 1L
    if (k < 1L) character(0) else vapply(seq_len(k), function(j) {
      paste(s[seq_len(j)], collapse = ".")
    }, "")
  })
  who <- rep(seq_along(nms), lengths(pre))
  pre <- unlist(pre, use.names = FALSE)
  if (length(pre) == 0L) return(desc)
  o <- order(-seqs[who], method = "radix")
  pre <- pre[o]
  who <- who[o]
  keep <- !duplicated(pre)
  list2env(stats::setNames(as.list(nms[who[keep]]), pre[keep]), envir = desc)
}

#' Maßgebliche Angabe für einen Blattpfad
#'
#' Die jüngste Aufzeichnung zum Pfad selbst, zu einem Vorfahren oder zu einem Nachfahren.
#' @param prv Herkunftsspeicher.
#' @param path Blattpfad.
#' @param idx optional: vorberechneter Präfixindex (`prv_index()`).
#' @return Angabe oder `NULL`.
#' @noRd
prv_lookup <- function(prv, path, idx = NULL) {
  if (length(prv$rec) == 0L) return(NULL)
  if (is.null(idx)) idx <- prv_index(prv)
  segs <- path_split(path)
  anc <- vapply(seq_along(segs), function(k) paste(segs[seq_len(k)], collapse = "."), "")
  cand <- anc[vapply(anc, exists, logical(1), envir = prv$rec, inherits = FALSE)]
  cand <- c(cand, get0(path, envir = idx, inherits = FALSE))
  if (length(cand) == 0L) return(NULL)
  seqs <- vapply(cand, function(p) get(p, envir = prv$rec)$seq, integer(1))
  get(cand[which.max(seqs)], envir = prv$rec)
}

#' Herkunftstabelle der Blätter von `x` (4.8)
#' @param prv Herkunftsspeicher.
#' @param x aufgelöste Liste.
#' @param variant Variante (Rückfall der Spalte `variant`).
#' @param default Angabe für Blätter ohne Aufzeichnung.
#' @return Data Frame nach 4.8.
#' @noRd
prv_table <- function(prv, x, variant = NA_character_,
                      default = prv_info(0L, "type_default")) {
  paths <- scn_leaves(x)
  if (length(paths) == 0L) return(prv_empty_table())
  idx <- prv_index(prv)
  recs <- lapply(paths, function(p) prv_lookup(prv, p, idx) %||% default)
  col <- function(f) vapply(recs, function(r) as.character(r[[f]] %||% NA_character_), "")
  dcol <- function(f) {
    as.Date(vapply(recs, function(r) as.double(r[[f]] %||% NA_real_), double(1)),
            origin = "1970-01-01")
  }
  var <- col("variant")
  var[is.na(var)] <- as.character(variant)
  data.frame(
    path = paths, layer = vapply(recs, function(r) as.integer(r$layer), integer(1)),
    source_type = col("source_type"), file = col("file"), entry = col("entry"),
    location = col("location"), variant = var, valid_from = dcol("valid_from"),
    valid_to = dcol("valid_to"), as_of = dcol("as_of"), accessed = dcol("accessed"),
    quality = col("quality"), stringsAsFactors = FALSE
  )
}

#' Leere Herkunftstabelle (4.8)
#' @noRd
prv_empty_table <- function() {
  d <- as.Date(character(0))
  data.frame(path = character(0), layer = integer(0), source_type = character(0),
             file = character(0), entry = character(0), location = character(0),
             variant = character(0), valid_from = d, valid_to = d, as_of = d, accessed = d,
             quality = character(0), stringsAsFactors = FALSE)
}

#' Blattpfade (Knoten, Werte und Wertformen gelten als Blätter; leere Maps haben keine)
#' @param x Liste.
#' @param path Präfix.
#' @param empty_seq leere Sequenzen der Rohform (`[]`, Liste ohne Namen) als Blätter zählen
#'   (Aufzeichnung der Herkunft; nach dem Normalisieren sind sie z. B. `character(0)`).
#' @return Zeichenvektor.
#' @noRd
scn_leaves <- function(x, path = "", empty_seq = FALSE) {
  if (is.null(x)) return(character(0))
  if (node_is(x) || io_is_raw_num(x) || !is_map(x) ||
        (nzchar(path) && is_value_form(x, path, kind_of = scn_kind_of))) {
    return(if (nzchar(path)) path else character(0))
  }
  if (length(x) == 0L) {
    return(if (empty_seq && nzchar(path) && is.null(names(x))) path else character(0))
  }
  unlist(lapply(names(x), function(nm) scn_leaves(x[[nm]], path_join(path, nm), empty_seq)),
         use.names = FALSE) %||% character(0)
}

#' Herkunftstabelle eines eingelesenen Szenarios (4.8, Schicht 5; Overlay Schicht 6)
#' @param x Liste der Blöcke.
#' @param layer Schicht je Blatt (Skalar oder benannter Vektor nach Pfadpräfix).
#' @param source_type Quellart je Blatt (Skalar oder benannter Vektor nach Pfadpräfix).
#' @param file Datei.
#' @param variant Variante.
#' @param entry `NULL` oder benannter Vektor Blattpfad -> Eintrag.
#' @param files `NULL` oder benannter Vektor Pfadpräfix -> Datei.
#' @param locations `NULL` oder Fundstellen nach Pfad (`io_yaml_locations()`).
#' @return Data Frame nach 4.8.
#' @noRd
scn_provenance <- function(x, layer = 5L, source_type = "scenario", file = NA_character_,
                           variant = NA_character_, entry = NULL, files = NULL,
                           locations = NULL) {
  paths <- scn_leaves(x)
  if (length(paths) == 0L) return(prv_empty_table())
  pick <- function(v, default) {
    if (length(v) == 1L && is.null(names(v))) return(rep(v, length(paths)))
    out <- rep(default, length(paths))
    for (i in seq_along(paths)) {
      segs <- path_split(paths[i])
      for (k in rev(seq_along(segs))) {
        key <- paste(segs[seq_len(k)], collapse = ".")
        if (key %in% names(v)) {
          out[i] <- v[[key]]
          break
        }
      }
    }
    out
  }
  na_date <- as.Date(rep(NA_character_, length(paths)))
  data.frame(
    path = paths, layer = as.integer(pick(layer, 5L)),
    source_type = as.character(pick(source_type, "scenario")),
    file = if (length(files) == 0L) rep(as.character(file), length(paths)) else
      as.character(pick(files, as.character(file))),
    entry = if (length(entry) == 0L) rep(NA_character_, length(paths)) else
      as.character(unname(entry[paths])),
    location = if (length(locations) == 0L) rep(NA_character_, length(paths)) else
      vapply(paths, function(p) io_location_of(locations, p), "", USE.NAMES = FALSE),
    variant = rep(as.character(variant), length(paths)), valid_from = na_date,
    valid_to = na_date, as_of = na_date, accessed = na_date,
    quality = rep(NA_character_, length(paths)), stringsAsFactors = FALSE
  )
}
