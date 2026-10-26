# Vokabulare (Integrator, Spec 00 Abschnitte 2.11, 7.5, 7.6, 10.8, 12.4).
# inst/vocab/*.yaml enthält nur Codes und maschinelle Regeln (ASCII); deutsche Bezeichnungen
# stehen im Label-Katalog unter vocab.<datei>.<code> (Kategorien: vocab.categories.<section>.<code>,
# Enums: vocab.enums.<enum>.<code>).

vocab_state <- new.env(parent = emptyenv())
vocab_state$data <- list()
vocab_state$raw <- list()
vocab_state$dir <- NULL

#' Vokabulare laden (.onLoad)
#' @param dir Verzeichnis, z. B. `system.file("vocab", package = "vofi")`.
#' @return `invisible(Namen der geladenen Vokabulare)`.
#' @noRd
vocab_load <- function(dir) {
  if (!utl_is_string(dir) || !nzchar(dir) || !dir.exists(dir)) {
    vofi_abort("core.vocab_dir_missing", dir = as.character(dir %||% "NULL")[1L],
               .class = "vofi_error_input")
  }
  files <- utl_sort(list.files(dir, pattern = "\\.ya?ml$"))
  raw <- list()
  for (f in files) raw[[sub("\\.ya?ml$", "", f)]] <- utl_read_yaml(file.path(dir, f))
  data <- list()
  for (nm in names(raw)) {
    x <- raw[[nm]]
    data[[nm]] <- switch(nm,
      sections = utl_vocab_sections(x),
      categories = utl_vocab_categories(x),
      units = data.frame(code = names(x),
                         dim = vapply(x, function(e) as.character(e$dim %||% NA), ""),
                         row = vapply(x, function(e) isTRUE(e$row), logical(1)),
                         stringsAsFactors = FALSE, row.names = NULL),
      conditions = data.frame(code = names(x),
                              base = vapply(x, function(e) as.character(e$base), ""),
                              stringsAsFactors = FALSE, row.names = NULL),
      row_extra_fields = utl_vocab_extra_fields(x),
      enums = utl_vocab_enums(x),
      if (!is.null(x$codes)) {
        data.frame(code = as.character(unlist(x$codes)), stringsAsFactors = FALSE)
      } else {
        x
      }
    )
  }
  vocab_state$raw <- raw
  vocab_state$data <- data
  vocab_state$dir <- dir
  vocab_state$cat_index <- NULL                 # Index von vocab_category() neu aufbauen
  invisible(names(data))
}

#' @noRd
utl_vocab_sections <- function(x) {
  data.frame(
    code = names(x),
    order = vapply(x, function(e) as.double(e$order), double(1)),
    balance = vapply(x, function(e) isTRUE(e$balance), logical(1)),
    flow = vapply(x, function(e) isTRUE(e$flow), logical(1)),
    stringsAsFactors = FALSE, row.names = NULL
  )
}

#' @noRd
utl_vocab_categories <- function(x) {
  defaults <- x$defaults %||% list()
  rows <- list()
  for (sec in names(x$categories)) {
    cats <- x$categories[[sec]]
    for (i in seq_along(cats)) {
      e <- utl_fill_defaults(cats[[i]], defaults)
      rows[[length(rows) + 1L]] <- list(
        section = sec, category = names(cats)[i], rank = i,
        sign = as.character(e$sign), noi = isTRUE(e$noi), burden = isTRUE(e$burden),
        tax_category = as.character(e$tax),
        tax_allowed = as.character(unlist(e$tax_allowed)),
        tax_excluded = as.character(unlist(e$tax_excluded)),
        ids = as.character(unlist(e$ids)), ids_optional = as.character(unlist(e$ids_optional)),
        cash = isTRUE(e$cash), engine = isTRUE(e$engine), flow_ok = isTRUE(e$flow_ok),
        kind = as.character(e$kind), unit = as.character(e$unit)
      )
    }
  }
  col <- function(f, type) vapply(rows, function(r) r[[f]], type)
  lst <- function(f) I(lapply(rows, function(r) r[[f]]))
  data.frame(
    section = col("section", ""), category = col("category", ""), rank = col("rank", 1L),
    sign = col("sign", ""), noi = col("noi", TRUE), burden = col("burden", TRUE),
    tax_category = col("tax_category", ""), tax_allowed = lst("tax_allowed"),
    tax_excluded = lst("tax_excluded"), ids = lst("ids"), ids_optional = lst("ids_optional"),
    cash = col("cash", TRUE), engine = col("engine", TRUE), flow_ok = col("flow_ok", TRUE),
    kind = col("kind", ""), unit = col("unit", ""),
    stringsAsFactors = FALSE
  )
}

#' @noRd
utl_vocab_extra_fields <- function(x) {
  lapply(x, function(e) {
    list(type = as.character(e$type), values = as.character(unlist(e$values)),
         categories = as.character(unlist(e$categories)))
  })
}

#' @noRd
utl_vocab_enums <- function(x) {
  lapply(x, function(e) {
    al <- e$aliases %||% list()
    e$codes <- as.character(unlist(e$codes))
    e$aliases <- stats::setNames(as.character(unlist(al)), names(al))
    e$patterns <- as.character(unlist(e$patterns))
    e$default <- if (is.null(e$default)) NULL else as.character(e$default)
    e
  })
}

#' Vokabular abrufen
#'
#' @param name Name der Vokabulardatei (`"sections"`, `"categories"`, `"tax_categories"`,
#'   `"asset_types"`, `"measure_types"`, `"units"`, `"na_reasons"`, `"conditions"`,
#'   `"row_extra_fields"`, `"enums"`) oder Name eines Enums aus `enums.yaml`.
#' @return Data Frame (Codetabellen) bzw. Liste (Enums, Zusatzfelder).
#' @noRd
vocab <- function(name) {
  d <- vocab_state$data
  if (utl_is_string(name) && name %in% names(d)) return(d[[name]])
  if (utl_is_string(name) && name %in% names(d[["enums"]])) return(d[["enums"]][[name]])
  vofi_abort("core.vocab_unknown_vocab", name = as.character(name)[1L],
             suggestion = utl_suggest_text(as.character(name)[1L],
                                           c(names(d), names(d[["enums"]]))),
             .class = "vofi_error_contract")
}

#' Codes eines Vokabulars
#'
#' @param name Vokabular (siehe `vocab()`); zusätzlich `"categories:<section>"`,
#'   `"enums:<enum>"` und `"vocab:<enum>"` (Form aus `vofi_param(values = )`).
#' @param field bei `"categories"`: Abschnitt; bei `"enums"`: Name des Enums.
#' @return Zeichenvektor der kanonischen Codes.
#' @noRd
vocab_codes <- function(name, field = NULL) {
  utl_vocab_spec(name, field)$codes
}

#' Codes, Aliase und Muster eines Vokabulars bestimmen
#' @noRd
utl_vocab_spec <- function(name, field = NULL) {
  if (!utl_is_string(name)) {
    vofi_abort("core.vocab_unknown_vocab", name = "?", suggestion = "",
               .class = "vofi_error_contract")
  }
  if (grepl(":", name, fixed = TRUE)) {
    parts <- strsplit(name, ":", fixed = TRUE)[[1L]]
    name <- if (parts[1L] %in% c("vocab", "enums")) "enums" else parts[1L]
    field <- parts[2L]
  }
  d <- vocab_state$data
  empty <- list(codes = character(0), aliases = character(0), patterns = character(0))
  if (identical(name, "categories")) {
    tab <- vocab("categories")
    codes <- if (is.null(field)) unique(tab$category) else tab$category[tab$section == field]
    if (!is.null(field) && !(field %in% tab$section)) {
      vofi_abort("core.vocab_unknown_vocab", name = paste0("categories:", field),
                 suggestion = utl_suggest_text(field, unique(tab$section)),
                 .class = "vofi_error_contract")
    }
    return(utl_fill_defaults(list(codes = codes), empty))
  }
  if (identical(name, "enums") || (!(name %in% names(d)) && name %in% names(d[["enums"]]))) {
    enum <- if (identical(name, "enums")) field else name
    e <- d[["enums"]][[enum %||% ""]]
    if (is.null(e)) {
      vofi_abort("core.vocab_unknown_vocab", name = paste0("enums:", enum %||% ""),
                 suggestion = utl_suggest_text(enum %||% "", names(d[["enums"]])),
                 .class = "vofi_error_contract")
    }
    return(list(codes = e$codes, aliases = e$aliases, patterns = e$patterns))
  }
  v <- vocab(name)
  codes <- if (is.data.frame(v)) v$code else names(v)
  utl_fill_defaults(list(codes = as.character(codes)), empty)
}

#' Codes prüfen
#'
#' Unbekannte Codes ergeben Fehlertexte; Aliase werden mit `vofi_warning_input` gemeldet (die
#' Auflösung übernimmt `vocab_resolve()`).
#' @param name Vokabular (siehe `vocab_codes()`).
#' @param x Zeichenvektor.
#' @param path Pfad für die Meldung.
#' @return `character()` oder Fehlertexte (deutsch, über `msg()`).
#' @noRd
vocab_check <- function(name, x, path = NULL) {
  spec <- utl_vocab_spec(name)
  x <- as.character(x)
  out <- character(0)
  for (code in unique(x)) {
    if (is.na(code)) {
      out <- c(out, msg("core.vocab_unknown_code", code = "NA", vocab = name,
                        path = path %||% "", suggestion = ""))
    } else if (code %in% spec$codes || utl_match_patterns(code, spec$patterns)) {
      next
    } else if (code %in% names(spec$aliases)) {
      vofi_warn("core.vocab_alias", code = code, canonical = spec$aliases[[code]],
                path = path %||% "", .class = "vofi_warning_input")
    } else {
      out <- c(out, msg("core.vocab_unknown_code", code = code, vocab = name,
                        path = path %||% "",
                        suggestion = utl_suggest_text(code, spec$codes)))
    }
  }
  out
}

#' Codes auf kanonische Codes abbilden
#'
#' Aliase werden ersetzt (mit `vofi_warning_input`); unbekannte Codes sind ein Fehler
#' `vofi_error_input`.
#' @inheritParams vocab_check
#' @return Zeichenvektor kanonischer Codes.
#' @noRd
vocab_resolve <- function(name, x, path = NULL) {
  spec <- utl_vocab_spec(name)
  x <- as.character(x)
  bad <- !(x %in% spec$codes) & !(x %in% names(spec$aliases)) &
    !vapply(x, utl_match_patterns, logical(1), patterns = spec$patterns)
  if (any(bad)) {
    code <- x[bad][1L]
    vofi_abort("core.vocab_unknown_code", code = code, vocab = name, path = path %||% "",
               suggestion = utl_suggest_text(code, spec$codes), .class = "vofi_error_input")
  }
  is_alias <- x %in% names(spec$aliases)
  if (any(is_alias)) {
    for (code in unique(x[is_alias])) {
      vofi_warn("core.vocab_alias", code = code, canonical = spec$aliases[[code]],
                path = path %||% "", .class = "vofi_warning_input")
    }
    x[is_alias] <- unname(spec$aliases[x[is_alias]])
  }
  x
}

#' Passt ein Code auf eines der Muster (`"m2_component:*"`)?
#' @noRd
utl_match_patterns <- function(code, patterns) {
  if (length(patterns) == 0L || is.na(code)) return(FALSE)
  for (p in patterns) {
    if (endsWith(p, "*")) {
      pre <- substr(p, 1L, nchar(p) - 1L)
      if (startsWith(code, pre) && nchar(code) > nchar(pre)) return(TRUE)
    } else if (identical(code, p)) {
      return(TRUE)
    }
  }
  FALSE
}

#' Ist der Code im Vokabular (ohne Aliase)?
#' @noRd
vocab_has <- function(name, code) {
  spec <- utl_vocab_spec(name)
  code %in% spec$codes | vapply(as.character(code), utl_match_patterns, logical(1),
                                patterns = spec$patterns)
}

#' Regeln einer Kategorie (eine Zeile aus categories.yaml)
#' @param section Abschnitt.
#' @param category Kategorie.
#' @return Liste der Felder oder `NULL`, wenn die Kombination nicht existiert.
#' @noRd
vocab_category <- function(section, category) {
  if (is.null(vocab_state$cat_index)) {
    tab <- vocab("categories")
    idx <- new.env(hash = TRUE, parent = emptyenv())
    for (i in seq_len(nrow(tab))) {
      row <- as.list(tab[i, , drop = FALSE])
      for (f in c("tax_allowed", "tax_excluded", "ids", "ids_optional")) {
        row[[f]] <- row[[f]][[1L]]
      }
      assign(paste0(tab$section[i], "\r", tab$category[i]), row, envir = idx)
    }
    vocab_state$cat_index <- idx
  }
  if (!utl_is_string(section) || !utl_is_string(category)) return(NULL)
  get0(paste0(section, "\r", category), envir = vocab_state$cat_index, inherits = FALSE)
}

#' Erlaubte Steuerkategorien einer Kategorie
#' @inheritParams vocab_category
#' @return Zeichenvektor (Default zuerst).
#' @noRd
vocab_tax_allowed <- function(section, category) {
  cat_row <- vocab_category(section, category)
  if (is.null(cat_row)) return(character(0))
  if ("*" %in% cat_row$tax_allowed) {
    all_codes <- vocab_codes("tax_categories")
    return(unique(c(cat_row$tax_category, setdiff(all_codes, cat_row$tax_excluded))))
  }
  unique(c(cat_row$tax_category, cat_row$tax_allowed))
}

#' Ordnung eines Abschnitts (7.5)
#' @noRd
vocab_section_order <- function(section) {
  tab <- vocab("sections")
  tab$order[match(section, tab$code)]
}
