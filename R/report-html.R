# HTML-Bericht (WS-H2, Spec 00 Abschnitte 13, 14 Nr. 26, R-25; Konzept 1.4, 4.5, 4.7, 5.5;
# Memo 07 Paragraf 5; Spec 01 Teil C 3.2, 4.4, 6.4).
# Eigentuemer: WS-H2. Inhalt: vofi_report() erzeugt mit rmarkdown (Suggests) einen
# eigenstaendigen HTML-Bericht im Fachmodus (Wohnungsunternehmen, Genossenschaften) bzw. im
# Haushaltsmodus (Selbstnutzer, Kleinvermieter) und die druckfaehige Kurzvorlage (Gremien bzw.
# Zusammenfassung zum Mitnehmen). Ablauf: Eingaben pruefen -> Berichtsmodell (Abschnitte aus
# Bloecken: Text, Liste, Tabelle, Grafik, Hinweis, Ampel) aus den Ausgabefunktionen von WS-H
# (vofi_table(), vofi_kpis(), vofi_household_view(), vofi_tenant_view(), vofi_plot() und deren
# Formatierungshelfer) -> Pandoc-Markdown (formatneutral; DOCX ist damit technisch vorbereitet,
# Freigabe v1.1) -> rmarkdown::render() mit der Vorlage inst/templates/report/vofi_bericht.Rmd
# und dem Stil vofi_bericht.css. Alle Texte stehen im Label-Katalog unter report.html.*.

# ---------------------------------------------------------------------------------------------
# Exportierte Funktion
# ---------------------------------------------------------------------------------------------

#' Bericht erzeugen
#'
#' Erzeugt einen eigenständigen HTML-Bericht (eine Datei, Grafiken eingebettet) zu einem
#' Ergebnis, einer Simulation oder einem Variantenvergleich (Spec 00, Abschnitt 14 Nr. 26;
#' Konzept 1.4 und 5.5). Der Bericht wird mit rmarkdown und pandoc erzeugt (Pakete rmarkdown
#' und knitr aus Suggests); die Texte sind deutsch, Zahlen stehen im deutschen Format.
#'
#' **Fachmodus** (`mode = "expert"`, Wohnungsunternehmen und Genossenschaften): Management
#' Summary mit zweistufiger Ampel und Primärkennzahl (mit und ohne Restwert; im Vergleich dazu
#' Rendite der Mehrinvestition, Renditekennzahl und Warmmietenänderung je Variante),
#' Variantenvergleich (mit Simulation die Wahrscheinlichkeit „besser als Referenz“, ohne
#' Simulation „besser bzw. schlechter im Basisfall“), Kennzahlen mit und ohne Restwert (auch je
#' WE und je m², bei Vergleichen je Variante), Zeitverläufe, Finanzierung und Förderung mit
#' DSCR und LTV und dem Berechtigungs-Check der Förderprogramme (geprüfte Bedingungen, Grund
#' einer Nichtberechtigung, offene Prüfpunkte und Ausschlüsse, Antragsdatum und Gültigkeit des
#' Programms), Mietersicht (Warmmiete vorher/nachher und gegenüber der Referenz, Rechenweg der
#' Modernisierungsumlage „rechnerisch → gekappt → angesetzt“), Energie und CO2, Risiko mit
#' MC-Fehler, Sensitivitäten (Pflichtsensitivitäten, kritische Werte, Tornado, Spider, global),
#' Annahmenprotokoll mit Herkunft, Bibliotheksständen und Gültigkeitswarnungen (Förderung zum
#' Antragsdatum, sonst zum Rechtsstand), VoFi-Tabelle im Grob-Layout, Prüfungen, Methodik und
#' Hinweise.
#'
#' **Haushaltsmodus** (`mode = "household"`, Selbstnutzer und Kleinvermieter): das Wichtigste
#' in Kürze in Worten („Sie sparen rund … € pro Monat“, gerundet), monatliche Belastung bzw.
#' monatlicher Cashflow je Jahr (Wörter statt Vorzeichen: „spart … €“, „… € mehr“, „Überschuss“,
#' „Zuschuss“), Eigenanteil, Nachschüsse, Amortisation in Worten, Förderung und Kredite mit
#' Förderprüfung, bei Kleinvermietern die zulässige Mieterhöhung durch Modernisierung je
#' Wohnung, Risiko in einfachen Worten („In 8 von 10 simulierten Zukünften …“), „Was passiert,
#' wenn …“ aus den Pflichtsensitivitäten, die wichtigsten Annahmen (bei Vergleichen die Kredite
#' je Variante), ein Glossar und deutlich sichtbare Hinweise.
#'
#' `mode = "auto"` folgt `project.report_mode` des Ergebnisses (Perspektive `wu_*`: Fachmodus,
#' sonst Haushaltsmodus); `"fach"` und `"haushalt"` sind gleichbedeutend mit `"expert"` bzw.
#' `"household"`.
#'
#' **Vorlagen** (`template`): `NULL` bzw. `"bericht"` ist der vollständige Bericht;
#' `"kurzvorlage"` (gleichbedeutend `"gremium"`) die druckfähige Kurzvorlage – im Fachmodus die
#' Entscheidungsvorlage mit 2 bis 4 Seiten für Aufsichtsrat, Vertreterversammlung oder Bank
#' (Beschlussvorschlag, Investition, Finanzierung und Förderung, Kennzahlen mit und ohne
#' Restwert, Restriktionen, die wichtigsten Risiken, Szenariotabelle), im Haushaltsmodus die
#' Zusammenfassung mit 1 bis 2 Seiten. Ein Pfad zu einer eigenen Rmd-Datei verwendet diese
#' Vorlage; sie erhält die Parameter, die sie in ihrem YAML-Kopf deklariert, aus `body`
#' (fertiger Markdown-Text des Berichts), `report` (Berichtsmodell) und `x` (Ergebnis). Eine
#' Liste mit den Feldern `name` (`"bericht"` oder `"kurzvorlage"`), `file` (eigene Rmd-Datei),
#' `sections` (Auswahl der Abschnitte), `author` (Verfasser, Default `meta.author` des
#' Szenarios), `logo` (Bilddatei für den Kopf) und `css` (eigenes Stylesheet) stellt die
#' Vorlage ein. Abschnitte (`sections`) im Fachmodus: `summary`, `variants`, `kpis`,
#' `timeline`, `financing`, `tenant`, `energy`, `risk`, `sensitivity`, `assumptions`,
#' `vofi_table`, `checks`, `method`; im Haushaltsmodus: `summary`, `burden`, `variants`,
#' `funding`, `risk`, `assumptions`, `glossary`, `vofi_table` (die VoFi-Tabelle ist im
#' Haushaltsmodus nur auf Wunsch enthalten); Kurzvorlage im Fachmodus: `decision`,
#' `investment`, `kpis`, `restrictions`, `risks`, `scenarios`; im Haushaltsmodus: `summary`,
#' `burden`, `funding`, `risk`. Die Hinweise (Haftungs-, Steuer-, Rechts- und Förderhinweis)
#' stehen immer am Ende. Abschnitte ohne Daten entfallen (zum Beispiel der Variantenvergleich bei
#' einem Einzelergebnis oder Energie und CO2 ohne Energiezahlungen) bzw. nennen den Grund (die
#' Mietersicht eines Wohnungsunternehmens ohne Mieterdaten, das Risiko ohne Simulation).
#'
#' **Pflichtsensitivitäten** (Spec 01 Teil C 4.4) rechnet der Bericht selbst: je Eintrag aus
#' `analysis.mandatory_sensitivities` ein deterministischer Lauf mit dem Szenario, das das
#' Ergebnis bei seiner Auflösung mitführt (bei Vergleichen je Variante gegen die Referenz). Ein
#' Ergebnis, das mit Laufzeit-Overrides oder einem Szenario-Set gerechnet wurde oder kein
#' Szenario mitführt, nennt die Einträge als „nicht gerechnet“ mit dem Grund.
#'
#' **Ergänzende Objekte:** Statt eines Ergebnisses darf `x` eine Liste sein mit genau einem
#' Ergebnis (`vofi_result`, `vofi_mc_result` oder `vofi_comparison`) und optional
#' Sensitivitätsanalysen ([vofi_sensitivity()], Tornado, Spider, global), dem Szenario
#' (`vofi_scenario`; es hat für die Pflichtsensitivitäten Vorrang) bzw. einer fertigen Tabelle
#' der Pflichtsensitivitäten als Element `mandatory` sowie Zielwertsuchen ([vofi_solve()], zum
#' Beispiel Break-even und kritische Werte; sie stehen im Abschnitt Sensitivitäten und in der
#' Kurzvorlage, das Ergebnis in der Einheit des gesuchten Parameters).
#'
#' DOCX ist technisch vorbereitet und wird mit Version 1.1 freigegeben (R-25); `format =
#' "docx"` meldet deshalb `vofi_error_not_implemented`. Die Kurzvorlage ist für den Druck
#' gestaltet (Druckansicht des Browsers, PDF über „Drucken“).
#'
#' @param x Ergebnisobjekt (`vofi_result`, `vofi_mc_result`, `vofi_comparison`) oder Liste
#'   mit einem Ergebnis und ergänzenden Objekten (siehe Details).
#' @param path Zieldatei (Endung `.html`; ohne Endung wird `.html` ergänzt). Eine vorhandene
#'   Datei wird überschrieben.
#' @param format `"html"` oder `"docx"` (Freigabe v1.1).
#' @param mode `"auto"`, `"expert"` (Fachmodus, auch `"fach"`) oder `"household"`
#'   (Haushaltsmodus, auch `"haushalt"`).
#' @param template optional: `"bericht"`, `"kurzvorlage"` (bzw. `"gremium"`), Pfad einer
#'   eigenen Rmd-Vorlage oder Liste mit `name`, `file`, `sections`, `author`, `logo`, `css`.
#' @param title optional: Titel des Berichts (Default aus dem Szenariotitel).
#' @param open Bericht nach dem Erzeugen im Browser öffnen.
#' @return `invisible(path)` (normalisierter Pfad der erzeugten Datei).
#' @family Berichten
#' @examplesIf interactive()
#' res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("grob_lehrbuch_a"))))
#' datei <- vofi_report(res, file.path(tempdir(), "bericht.html"), mode = "expert")
#' vofi_report(res, file.path(tempdir(), "kurzvorlage.html"), template = "kurzvorlage")
#' @export
vofi_report <- function(x, path, format = c("html", "docx"),
                        mode = c("auto", "expert", "household"), template = NULL, title = NULL,
                        open = interactive()) {
  format <- utl_match_arg(format, c("html", "docx"), "format")
  if (identical(format, "docx")) {
    vofi_abort("report.html.errors.docx_v11", .class = "vofi_error_not_implemented")
  }
  parts <- rep_html_parts(x)
  mode <- rep_html_mode(mode, parts$main)
  opts <- rep_html_template(template, mode)
  if (!is.null(title) && !utl_is_string(title)) {
    vofi_abort("report.html.errors.title", .class = "vofi_error_input")
  }
  if (!utl_is_flag(open)) vofi_abort("report.html.errors.open", .class = "vofi_error_input")
  path <- rep_html_path(path, format)
  rep_html_require("rmarkdown")
  rep_html_require("knitr")
  rep_html_check_pandoc()
  old <- rep_html_utf8_locale()
  if (!is.null(old)) on.exit(Sys.setlocale("LC_CTYPE", old), add = TRUE)
  rc <- rep_html_context(parts, mode, opts)
  model <- rep_html_model(rc, title)
  out <- rep_html_render(model, path, format, opts)
  if (isTRUE(open)) utils::browseURL(out)
  invisible(out)
}

# ---------------------------------------------------------------------------------------------
# Eingaben
# ---------------------------------------------------------------------------------------------

#' Klassen der Hauptobjekte eines Berichts
#' @noRd
rep_html_main_classes <- function() c("vofi_comparison", "vofi_mc_result", "vofi_result")

#' Spalten einer Tabelle der Pflichtsensitivitäten (Spec 01 Teil C 4.4, WS-G)
#' @noRd
rep_html_mandatory_cols <- function() {
  c("id", "label", "kpi", "base", "base_ex_rv", "value", "value_ex_rv", "diff", "diff_ex_rv",
    "status")
}

#' Bestandteile des Berichts aus `x` bestimmen
#'
#' `x` ist ein Ergebnis oder eine Liste mit genau einem Ergebnis und optional
#' Sensitivitätsanalysen (auch als Liste), Zielwertsuchen (`vofi_solution`), Szenario und
#' Tabelle der Pflichtsensitivitäten (Element `mandatory`).
#' @return Liste `main`, `sens` (Liste von `vofi_sensitivity`), `solutions` (Liste von
#'   `vofi_solution`), `scenario`, `mandatory`.
#' @noRd
rep_html_parts <- function(x) {
  out <- list(main = NULL, sens = list(), solutions = list(), scenario = NULL, mandatory = NULL)
  if (inherits(x, rep_html_main_classes())) {
    out$main <- x
    return(out)
  }
  bad <- function(obj) {
    vofi_abort("report.html.errors.x_invalid", cls = rep_class_text(obj),
               .class = "vofi_error_input")
  }
  if (!is.list(x) || is.data.frame(x) || !is.null(attr(x, "class"))) bad(x)
  nms <- names(x) %||% rep("", length(x))
  mains <- list()
  for (i in seq_along(x)) {
    el <- x[[i]]
    nm <- nms[i]
    if (inherits(el, rep_html_main_classes())) {
      mains[[length(mains) + 1L]] <- el
    } else if (inherits(el, "vofi_sensitivity")) {
      out$sens[[length(out$sens) + 1L]] <- el
    } else if (inherits(el, "vofi_solution")) {
      out$solutions[[length(out$solutions) + 1L]] <- el
    } else if (inherits(el, "vofi_scenario")) {
      out$scenario <- el
    } else if (identical(nm, "mandatory") && is.data.frame(el)) {
      miss <- setdiff(rep_html_mandatory_cols(), names(el))
      if (length(miss) > 0L) {
        vofi_abort("report.html.errors.mandatory",
                   cols = utl_collapse(rep_html_mandatory_cols()), .class = "vofi_error_input")
      }
      out$mandatory <- el
    } else if (is.list(el) && !is.data.frame(el) && length(el) > 0L &&
                 all(vapply(el, inherits, logical(1), what = "vofi_sensitivity"))) {
      out$sens <- c(out$sens, unname(el))
    } else {
      bad(el)
    }
  }
  if (length(mains) == 0L) vofi_abort("report.html.errors.x_none", .class = "vofi_error_input")
  if (length(mains) > 1L) {
    vofi_abort("report.html.errors.x_multiple",
               cls = utl_collapse(vapply(mains, function(m) class(m)[1L], "")),
               .class = "vofi_error_input")
  }
  out$main <- mains[[1L]]
  out
}

#' Deterministisches Bezugsergebnis eines Hauptobjekts (Vergleich: Referenz, Simulation:
#' Basisfall)
#' @noRd
rep_html_det <- function(x) {
  if (inherits(x, "vofi_comparison")) x <- rep_comparison_result(x, NULL)
  rep_det_result(x)
}

#' Berichtsmodus bestimmen (Aliase `fach`, `haushalt`; `auto` aus `meta$report_mode`)
#' @noRd
rep_html_mode <- function(mode, main) {
  choices <- c("auto", "expert", "household")
  aliases <- c(fach = "expert", haushalt = "household")
  if (identical(mode, choices)) mode <- "auto"
  if (!utl_is_string(mode) || !(mode %in% c(choices, names(aliases)))) {
    vofi_abort("report.html.errors.mode", value = utl_collapse(format(mode)),
               choices = utl_collapse(c(choices, names(aliases))), .class = "vofi_error_input")
  }
  if (mode %in% names(aliases)) mode <- unname(aliases[mode])
  if (!identical(mode, "auto")) return(mode)
  res <- rep_html_det(main)
  rm <- res$meta$report_mode %||% res$spec$project$report_mode %||% "auto"
  if (rm %in% c("expert", "household")) return(rm)
  persp <- res$meta$perspective %||% res$spec$project$perspective %||% ""
  if (startsWith(persp, "wu_")) "expert" else "household"
}

#' Abschnitte je Vorlage und Modus (kanonische Reihenfolge, ohne Hinweise)
#' @noRd
rep_html_section_ids <- function(name, mode) {
  if (identical(name, "kurzvorlage")) {
    if (identical(mode, "expert")) {
      return(c("decision", "investment", "kpis", "restrictions", "risks", "scenarios"))
    }
    return(c("summary", "burden", "funding", "risk"))
  }
  if (identical(mode, "expert")) {
    return(c("summary", "variants", "kpis", "timeline", "financing", "tenant", "energy", "risk",
             "sensitivity", "assumptions", "vofi_table", "checks", "method"))
  }
  c("summary", "burden", "variants", "funding", "risk", "assumptions", "glossary", "vofi_table")
}

#' Voreingestellte Abschnitte (Haushaltsmodus: VoFi-Tabelle nur auf Wunsch)
#' @noRd
rep_html_default_sections <- function(name, mode) {
  ids <- rep_html_section_ids(name, mode)
  if (identical(name, "bericht") && identical(mode, "household")) ids <- setdiff(ids, "vofi_table")
  ids
}

#' Vorlage und Vorlagenparameter prüfen
#' @param template `NULL`, Name, Pfad oder Liste.
#' @param mode Berichtsmodus (für die Abschnitte).
#' @return Liste `name`, `file`, `sections`, `author`, `logo`, `css`.
#' @noRd
rep_html_template <- function(template, mode) {
  fields <- c("name", "file", "sections", "author", "logo", "css")
  names_ok <- c("bericht", "kurzvorlage", "gremium")
  out <- list(name = "bericht", file = NULL, sections = NULL, author = NULL, logo = NULL,
              css = NULL)
  invalid <- function() {
    vofi_abort("report.html.errors.template", choices = utl_collapse(names_ok),
               fields = utl_collapse(fields), value = utl_collapse(format(template)),
               .class = "vofi_error_input")
  }
  if (is.null(template)) {
    template <- list()
  } else if (utl_is_string(template)) {
    template <- if (template %in% names_ok) list(name = template) else list(file = template)
  } else if (!is.list(template) || is.data.frame(template)) {
    invalid()
  }
  extra <- setdiff(names(template) %||% rep("", length(template)), fields)
  if (length(template) > 0L && (is.null(names(template)) || length(extra) > 0L)) {
    vofi_abort("report.html.errors.template_field",
               value = utl_collapse(if (length(extra) > 0L) extra else "?"),
               fields = utl_collapse(fields), .class = "vofi_error_input")
  }
  check_string <- function(field) {
    v <- template[[field]]
    if (!is.null(v) && !utl_is_string(v)) {
      vofi_abort("report.html.errors.template_value", field = field,
                 what = lbl("report.html.errors.template_value_string"),
                 .class = "vofi_error_input")
    }
    v
  }
  nm <- check_string("name") %||% "bericht"
  if (!(nm %in% names_ok)) invalid()
  out$name <- if (identical(nm, "gremium")) "kurzvorlage" else nm
  file <- check_string("file")
  if (!is.null(file)) {
    if (!file.exists(file) || !grepl("\\.[Rr]md$", file)) {
      vofi_abort("report.html.errors.template_missing", path = file, .class = "vofi_error_input")
    }
    out$file <- normalizePath(file)
  }
  for (f in c("logo", "css")) {
    v <- check_string(f)
    if (!is.null(v)) {
      if (!file.exists(v)) {
        vofi_abort("report.html.errors.file_missing", path = v, field = f,
                   .class = "vofi_error_input")
      }
      out[[f]] <- normalizePath(v)
    }
  }
  out$author <- check_string("author")
  sec <- template$sections
  allowed <- rep_html_section_ids(out$name, mode)
  if (is.null(sec)) {
    out$sections <- rep_html_default_sections(out$name, mode)
  } else {
    if (!is.character(sec) || anyNA(sec)) {
      vofi_abort("report.html.errors.template_value", field = "sections",
                 what = lbl("report.html.errors.template_value_chr"),
                 .class = "vofi_error_input")
    }
    sec <- setdiff(sec, "notes")
    bad <- setdiff(sec, allowed)
    if (length(bad) > 0L) {
      vofi_abort("report.html.errors.sections", value = utl_collapse(bad),
                 choices = utl_collapse(c(allowed, "notes")),
                 suggestion = utl_suggest_text(bad[1L], allowed), .class = "vofi_error_input")
    }
    out$sections <- allowed[allowed %in% sec]
  }
  out
}

#' Zieldatei prüfen (Endung, Verzeichnis)
#' @return normalisierter Pfad (Datei muss noch nicht existieren).
#' @noRd
rep_html_path <- function(path, format = "html") {
  if (!utl_is_string(path) || !nzchar(path)) {
    vofi_abort("report.html.errors.path", value = utl_collapse(format(path)),
               .class = "vofi_error_input")
  }
  ext <- tolower(tools::file_ext(path))
  if (!nzchar(ext)) {
    path <- paste0(path, ".", format)
  } else if (!(ext %in% c("html", "htm"))) {
    vofi_abort("report.html.errors.path_ext", path = path, .class = "vofi_error_input")
  }
  dir <- dirname(path)
  if (!dir.exists(dir)) {
    vofi_abort("report.html.errors.dir_missing", dir = dir, .class = "vofi_error_input")
  }
  file.path(normalizePath(dir), basename(path))
}

#' Ist ein Paket aus Suggests installiert? (eigene Funktion, damit Tests das Fehlen simulieren
#' können, ohne die Meldung selbst zu ersetzen)
#' @noRd
rep_html_has_pkg <- function(pkg) requireNamespace(pkg, quietly = TRUE)

#' Paket aus Suggests verlangen (deutsche Meldung `core.suggests_missing` mit Installationshinweis)
#' @noRd
rep_html_require <- function(pkg) {
  if (!isTRUE(rep_html_has_pkg(pkg))) {
    vofi_abort("core.suggests_missing", pkg = pkg, fun = "vofi_report",
               .class = "vofi_error_input")
  }
  invisible(TRUE)
}

#' pandoc vorhanden (ab Version 2)?
#' @noRd
rep_html_check_pandoc <- function() {
  if (!isTRUE(rmarkdown::pandoc_available("2.0"))) {
    vofi_abort("report.html.errors.pandoc", .class = "vofi_error_input")
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------------------------------
# Berichtskontext
# ---------------------------------------------------------------------------------------------

#' Kontext des Berichts (Ergebnis, Referenz, Simulation, Modus, ergänzende Objekte)
#' @noRd
rep_html_context <- function(parts, mode, opts) {
  x <- parts$main
  cmp <- if (inherits(x, "vofi_comparison")) x else NULL
  base <- if (is.null(cmp)) x else rep_comparison_result(cmp, NULL)
  mc <- if (inherits(base, "vofi_mc_result")) base else NULL
  res <- rep_det_result(base)
  persp <- res$meta$perspective %||% res$spec$project$perspective %||% ""
  cmp_mc <- !is.null(cmp) && (identical(cmp$meta$mode, "mc") ||
                                any(vapply(cmp$results, inherits, logical(1),
                                           what = "vofi_mc_result")))
  rep_label_env$labels <- if (is.null(cmp)) NULL else cmp$meta$variant_labels
  list(x = x, cmp = cmp, base = base, mc = mc, res = res, mode = mode, kind = opts$name,
       opts = opts, sens = parts$sens, solutions = parts$solutions, scenario = parts$scenario,
       mandatory = parts$mandatory,
       perspective = persp, owner = identical(persp, "selbstnutzer"),
       household = identical(mode, "household"), is_mc = !is.null(mc) || cmp_mc,
       plots = isTRUE(rep_html_has_pkg("ggplot2")),
       cache = new.env(parent = emptyenv()))
}

# ---------------------------------------------------------------------------------------------
# Blöcke und Abschnitte des Berichtsmodells
# ---------------------------------------------------------------------------------------------

#' Block: Absätze aus Klartext (wird maskiert)
#' @noRd
rep_html_b_par <- function(text) {
  text <- as.character(text)
  text <- text[!is.na(text) & nzchar(text)]
  if (length(text) == 0L) return(NULL)
  list(type = "par", text = text)
}

#' Block: Aufzählung aus Klartext (wird maskiert)
#' @noRd
rep_html_b_list <- function(items) {
  items <- as.character(items)
  items <- items[!is.na(items) & nzchar(items)]
  if (length(items) == 0L) return(NULL)
  list(type = "list", items = items)
}

#' Block: Zwischenüberschrift (Ebene 2 unter den Abschnitten, Ebene 3 darunter)
#' @noRd
rep_html_b_heading <- function(text, level = 2L) {
  list(type = "heading", text = text, level = as.integer(level))
}

#' Variantenbezeichnungen des laufenden Berichts (aus `cmp$meta$variant_labels`, SN-10)
#' @noRd
rep_label_env <- new.env(parent = emptyenv())

#' Bezeichnung einer Variante im Bericht: „Label“ (Kennung) bzw. die Kennung
#' @param short `TRUE`: nur das Label (Tabellenköpfe, Fließtext).
#' @noRd
rep_vlabel <- function(v, short = FALSE) {
  labs <- rep_label_env$labels
  out <- as.character(v)
  if (is.null(labs)) return(out)
  for (i in seq_along(out)) {
    l <- if (out[i] %in% names(labs)) labs[[out[i]]] else NA_character_
    if (is.na(l) || identical(l, out[i])) next
    out[i] <- if (short) l else paste0(l, " (", out[i], ")")
  }
  out
}

#' Block: Zwischenüberschrift „Variante …“
#' @noRd
rep_html_var_heading <- function(variant, level = 2L) {
  rep_html_b_heading(lbl("report.html.vofi_table.variant_header", variant = rep_vlabel(variant)),
                     level)
}

#' Block: Tabelle aus einer Zeichenmatrix mit Spaltenköpfen
#' @param m Zeichenmatrix (bzw. Data Frame aus Zeichenketten).
#' @param align `NULL` (erste Spalte links, Zahlenspalten rechts) oder Vektor aus `"l"`, `"r"`,
#'   `"c"`.
#' @param caption optional: Tabellenunterschrift.
#' @param wide breite Tabelle (waagrecht rollbar).
#' @param max_rows höchste Zahl angezeigter Zeilen (sonst gekürzt mit Vermerk).
#' @param note optional: Vermerke unter der Tabelle (bei gekürzten Jahrestabellen ergänzt).
#' @noRd
rep_html_b_table <- function(m, align = NULL, caption = NULL, wide = NULL, max_rows = NULL,
                             note = NULL) {
  if (is.data.frame(m)) {
    cn <- names(m)
    m <- as.matrix(m)
    if (length(cn) > 0L) colnames(m) <- cn
  }
  if (!is.matrix(m) || ncol(m) == 0L || nrow(m) == 0L) return(NULL)
  if (isTRUE(attr(m, "picked"))) note <- c(note, lbl("report.html.table.years_shown", step = 5L))
  note <- c(note, attr(m, "note"))
  m[is.na(m)] <- ""
  if (!is.null(max_rows) && nrow(m) > max_rows) {
    note <- c(note, lbl("report.html.table.truncated", shown = as.integer(max_rows),
                        total = as.integer(nrow(m))))
    m <- m[seq_len(max_rows), , drop = FALSE]
  }
  list(type = "table", m = m, align = align, caption = caption,
       wide = wide %||% (ncol(m) > 8L), note = note)
}

#' Block: Grafik (Funktion, die ein ggplot-Objekt liefert; erst beim Schreiben ausgewertet)
#' @noRd
rep_html_b_plot <- function(fun, caption, width = 7.5, height = 4.2) {
  list(type = "plot", fun = fun, caption = caption, width = width, height = height)
}

#' Block: Hinweiskasten (`kind`: `info`, `warning`, `pretax`)
#' @noRd
rep_html_b_callout <- function(kind, text, title = NULL) {
  text <- as.character(text)
  text <- text[!is.na(text) & nzchar(text)]
  if (length(text) == 0L) return(NULL)
  list(type = "callout", kind = kind, text = text, title = title)
}

#' Block: Ampel (zweistufig, 12.9)
#' @param tl Ampel nach 13.1 bzw. `NULL`.
#' @param household Erläuterung in einfachen Worten voranstellen.
#' @noRd
rep_html_b_ampel <- function(tl, household = FALSE) {
  if (is.null(tl) || is.null(tl$level)) {
    return(rep_html_b_callout("info", lbl("report.html.ampel.none")))
  }
  level <- tl$level
  lines <- rep_traffic_lines(tl)
  if (household) {
    lines <- c(lbl(paste0("report.html.ampel.explain_", level), .default = ""), lines)
  }
  list(type = "ampel", level = level,
       title = lbl("report.html.ampel.title", level = rep_html_level_text(level)),
       lines = lines[nzchar(lines)])
}

#' Bezeichnung einer Ampelstufe
#' @noRd
rep_html_level_text <- function(level) {
  lbl(paste0("report.html.ampel.", level), .default = as.character(level))
}

#' Abschnitt des Berichtsmodells
#' @noRd
rep_html_section <- function(id, title, blocks) {
  blocks <- blocks[!vapply(blocks, is.null, logical(1))]
  list(id = id, title = title, blocks = blocks)
}

#' Titel eines Abschnitts (mit Varianten je Modus bzw. Perspektive)
#' @noRd
rep_html_sec_title <- function(id, rc) {
  key <- switch(id,
    summary = , variants = , risk = , assumptions = paste0(id, "_", rc$mode),
    burden = if (rc$owner) "burden_owner" else "burden_landlord",
    funding = "funding_household",
    id
  )
  lbl(paste0("report.html.sections.", key))
}

# ---------------------------------------------------------------------------------------------
# Berichtsmodell
# ---------------------------------------------------------------------------------------------

#' Berichtsmodell: Kopf und Abschnitte
#' @param rc Kontext aus `rep_html_context()`.
#' @param title Titel bzw. `NULL`.
#' @return Liste `meta` (Titel, Kopfzeilen, Klasse) und `sections`.
#' @noRd
rep_html_model <- function(rc, title = NULL) {
  res <- rc$res
  st <- res$spec$meta$title %||% res$meta$scenario_id %||% ""
  key <- paste0(rc$kind, "_", rc$mode)
  title <- title %||% lbl(paste0("report.html.title.", key), title = st)
  sections <- list()
  for (id in rc$opts$sections) {
    sec <- rep_html_build_section(id, rc)
    if (!is.null(sec)) sections[[length(sections) + 1L]] <- sec
  }
  sections[[length(sections) + 1L]] <- rep_html_build_section("notes", rc)
  list(meta = list(title = title, kind = rc$kind, mode = rc$mode,
                   kind_text = lbl(paste0("report.html.kind.", key)),
                   lines = rep_html_head_lines(rc), logo = rc$opts$logo,
                   pretax = rep_html_pretax(rc)),
       sections = sections, x = rc$x)
}

#' Abschnitt erzeugen; Fehler eines Abschnitts erscheinen als Hinweis (mit Warnung)
#' @noRd
rep_html_build_section <- function(id, rc) {
  fun <- get(paste0("rep_html_sec_", id), envir = asNamespace("vofi"), mode = "function")
  title <- rep_html_sec_title(id, rc)
  tryCatch(fun(rc), error = function(e) {
    vofi_warn("report.html.section_failed", section = title, message = conditionMessage(e))
    txt <- lbl("report.html.section_failed", section = title, message = conditionMessage(e))
    rep_html_section(id, title, list(rep_html_b_callout("warning", txt)))
  })
}

#' Kopfzeilen (Variante, Zeitraum, Perspektive, Berechnung, Verfasser, Erstellung)
#' @noRd
rep_html_head_lines <- function(rc) {
  res <- rc$res
  g <- res$grid
  lines <- character(0)
  if (!is.null(rc$cmp)) {
    lines <- c(lines, lbl("report.html.head.comparison", baseline = rc$cmp$baseline %||% "",
                          variants = utl_collapse(rc$cmp$variants %||% character(0))))
  } else {
    lines <- c(lines, lbl("report.html.head.variant", variant = res$meta$variant %||% "base"))
  }
  years <- as.integer(round(sum(g$months[g$t >= 1L]) / 12))
  lines <- c(lines, lbl("report.html.head.period", start = g$valuation_date, end = g$end_date,
                        years = years),
             lbl("report.html.head.perspective",
                 perspective = rep_enum_label("perspective", res$meta$perspective)))
  calc <- if (!is.null(rc$cmp) && rc$is_mc) {
    lbl("report.html.head.calc_cmp_mc",
        n = as.integer(rc$cmp$meta$n_sim %||% rc$base$meta$n_sim %||% NA_integer_))
  } else if (!is.null(rc$mc)) {
    lbl("report.html.head.calc_mc", n = as.integer(rc$mc$meta$n_sim %||% nrow(rc$mc$kpis)))
  } else {
    lbl("report.html.head.calc_det")
  }
  lines <- c(lines, lbl("report.html.head.calc", mode = calc))
  author <- rc$opts$author %||% res$spec$meta$author
  if (utl_is_string(author) && nzchar(author)) {
    lines <- c(lines, lbl("report.html.head.author", author = author))
  }
  c(lines, lbl("report.html.head.created", date = Sys.Date(),
               version = as.character(utils::packageVersion("vofi")),
               contract = VOFI_CONTRACT_VERSION))
}

#' Hinweis „Rechnung vor Ertragsteuern“ im Kopf (bzw. Kurzform des Haftungshinweises)
#' @noRd
rep_html_pretax <- function(rc) {
  tm <- rc$res$meta$tax_module %||% "none"
  if (identical(tm, "none")) lbl("report.html.head.pretax") else
    lbl("report.html.head.disclaimer_short")
}

# ---------------------------------------------------------------------------------------------
# Gemeinsame Daten- und Formatierungshelfer
# ---------------------------------------------------------------------------------------------

#' Einheit einer Kennzahl (unbekannt: EUR)
#' @noRd
rep_html_unit <- function(k) {
  u <- kpi_unit(k)
  if (is.na(u)) "EUR" else u
}

#' Formatierter Kennzahlwert eines Ergebnisses (Lauf 1, mit NA-Begründung)
#' @noRd
rep_html_kv <- function(res, k, digits = 0) {
  if (!(k %in% names(res$kpis))) return(fmt_num(NA))
  rep_fmt_kpi(res$kpis[[k]][1L], rep_html_unit(k), (res$kpi_na[[k]] %||% NA_character_)[1L],
              digits = digits)
}

#' Zahlenwert einer Kennzahl eines Ergebnisses (Lauf 1)
#' @noRd
rep_html_kn <- function(res, k) {
  v <- res$kpis[[k]]
  if (is.null(v)) NA_real_ else as.double(v[1L])
}

#' Ampel eines Einzelergebnisses bzw. einer Simulation (12.9)
#'
#' Vorrang: Feld `traffic_light`, dann `cmp_traffic_light()` (WS-G), sonst beim Einzelergebnis
#' `rep_traffic_light()` (WS-H) und bei der Simulation die Stufe 1 mit Basis `mc` und die
#' Restriktionen nach 12.9 (`rep_html_tl_mc()`).
#' @noRd
rep_html_tl <- function(x) {
  if (!inherits(x, "vofi_mc_result")) return(rep_traffic_light(x))
  if (!is.null(x$traffic_light)) return(x$traffic_light)
  f <- get0("cmp_traffic_light", envir = asNamespace("vofi"), mode = "function",
            inherits = FALSE)
  if (is.function(f)) return(f(x))
  rep_html_tl_mc(x)
}

#' Ampel einer Simulation nach 12.9 (Basis `mc`), solange `cmp_traffic_light()` fehlt
#' @noRd
rep_html_tl_mc <- function(x) {
  det <- x$deterministic
  primary <- x$meta$primary_kpi %||% kpi_primary(x$spec)$kpi
  v <- x$kpis[[primary]]
  if (is.null(v) || is.null(det$kpis[[primary]])) return(NULL)
  num <- function(path, default) rep_spec_number(x$spec, path) %||% default
  green <- num("analysis.traffic_light.green_prob", 0.70)
  red <- num("analysis.traffic_light.red_prob", 0.40)
  rprob <- num("analysis.traffic_light.restriction_prob", 0.30)
  ok <- as.double(v[!is.na(v)])
  if (length(ok) == 0L) return(NULL)
  p <- mean(ok > 0)
  m <- stats::median(ok)
  stage1 <- if (m > 0 && p >= green) "green" else if (p < red) "red" else "yellow"
  p_base <- rep_html_kn(det, primary)
  p_ex <- rep_html_kn(det, paste0(primary, "_ex_rv"))
  if (is.na(p_ex)) p_ex <- p_base
  rv_dep <- !is.na(p_base) && !is.na(p_ex) && ((p_base > 0) != (p_ex > 0))
  notes <- character(0)
  if (rv_dep) {
    notes <- "report.traffic.rv_dependent"
    if (identical(stage1, "green")) stage1 <- "yellow"
  }
  codes <- as.character(unlist(x$spec$analysis$restrictions %||% character(0)))
  n_c <- length(codes)
  restr <- data.frame(code = codes, violated_base = rep(FALSE, n_c), prob = rep(NA_real_, n_c),
                      year = rep(NA_integer_, n_c), value = rep(NA_real_, n_c),
                      threshold = rep(NA_real_, n_c), ko = rep(FALSE, n_c),
                      stringsAsFactors = FALSE)
  for (i in seq_len(n_c)) {
    k <- paste0("restriction_", codes[i])
    b <- rep_html_kn(det, k)
    pr <- if (is.null(x$kpis[[k]])) NA_real_ else suppressWarnings(mean(x$kpis[[k]], na.rm = TRUE))
    if (is.nan(pr)) pr <- NA_real_
    if (is.na(b) && is.na(pr)) {
      notes <- c(notes, lbl("report.traffic.restriction_unchecked",
                            code = rep_restriction_label(codes[i])))
      next
    }
    restr$violated_base[i] <- !is.na(b) && b > 0.5
    restr$prob[i] <- pr
    restr$ko[i] <- restr$violated_base[i] || (!is.na(pr) && pr >= rprob)
  }
  level <- stage1
  if (any(restr$ko) && identical(level, "green")) level <- "yellow"
  list(level = level, stage1 = stage1, basis = "mc", kpi = primary, rv_dependent = rv_dep,
       restrictions = restr, notes = notes)
}

#' Ampel des Hauptobjekts (Einzelergebnis bzw. Simulation; Vergleich: `NULL`)
#' @noRd
rep_html_main_tl <- function(rc) {
  if (!is.null(rc$cmp)) return(NULL)
  rep_html_tl(rc$base)
}

#' Ampel einer Variante eines Vergleichs als Liste nach 13.1 (aus `traffic_light` und
#' `restrictions`)
#'
#' Die Hinweise stammen aus der Spalte `notes` (WS-G: Texte, mit „; “ verbunden), sonst aus
#' Restwertregel, Grundlage und den Restriktionen: `restriction_<c>` ohne Wert im Basisfall
#' und in der Simulation ist „nicht prüfbar“ (12.9, R-101).
#' @noRd
rep_html_cmp_tl <- function(cmp, variant) {
  tl <- cmp$traffic_light
  if (!is.data.frame(tl) || !(variant %in% tl$variant)) return(NULL)
  r <- tl[tl$variant == variant, , drop = FALSE][1L, , drop = FALSE]
  rs <- cmp$restrictions
  rs <- if (is.data.frame(rs) && nrow(rs) > 0L) rs[rs$variant == variant, , drop = FALSE] else
    NULL
  stored <- if ("notes" %in% names(r)) as.character(r$notes) else NA_character_
  if (!is.na(stored) && nzchar(stored)) {
    notes <- strsplit(stored, "; ", fixed = TRUE)[[1L]]
  } else {
    notes <- if (isTRUE(r$rv_dependent)) "report.traffic.rv_dependent" else character(0)
    if (identical(r$basis, "base_only")) notes <- c("report.traffic.no_robustness", notes)
    if (is.data.frame(rs) && nrow(rs) > 0L) {
      vb <- if ("violated_base" %in% names(rs)) rs$violated_base else rep(NA, nrow(rs))
      pr <- if ("prob" %in% names(rs)) rs$prob else rep(NA_real_, nrow(rs))
      for (cd in rs$code[is.na(vb) & is.na(pr)]) {
        notes <- c(notes, lbl("report.traffic.restriction_unchecked",
                              code = rep_restriction_label(cd)))
      }
    }
  }
  list(level = r$level, stage1 = r$stage1 %||% r$level, basis = r$basis, kpi = r$kpi,
       rv_dependent = isTRUE(r$rv_dependent), restrictions = rs, notes = notes[nzchar(notes)])
}

#' Beste Variante eines Vergleichs (Rang 1 ohne Referenz)
#' @noRd
rep_html_best_variant <- function(cmp) {
  rk <- cmp$ranking
  vars <- cmp$variants %||% setdiff(names(cmp$results), cmp$baseline)
  if (is.data.frame(rk) && nrow(rk) > 0L) {
    rk <- rk[order(rk$rank, method = "radix"), , drop = FALSE]
    cand <- rk$variant[rk$variant %in% vars]
    if (length(cand) > 0L) return(cand[1L])
  }
  if (length(vars) > 0L) vars[1L] else NA_character_
}

#' Restriktionen als Zeichenmatrix (12.9)
#' @param r Data Frame `code`, `violated_base`, `prob`, `year`, `value`, `threshold`, `ko`
#'   (optional `variant`).
#' @noRd
rep_html_restr_matrix <- function(r) {
  if (!is.data.frame(r) || nrow(r) == 0L) return(NULL)
  yn <- function(v) ifelse(v %in% TRUE, lbl("report.common.yes"), lbl("report.common.no"))
  m <- cbind(vapply(r$code, rep_restriction_label, "", USE.NAMES = FALSE),
             yn(r$violated_base), fmt_pct(r$prob, 1),
             ifelse(is.na(r$year), fmt_num(NA), sprintf("%d", as.integer(r$year))),
             fmt_num(r$value, 2), fmt_num(r$threshold, 2), yn(r$ko))
  m <- matrix(m, nrow = nrow(r))
  colnames(m) <- c(lbl("report.compare.col_restriction"), lbl("report.compare.col_violated"),
                   lbl("report.compare.col_prob"), lbl("report.compare.col_year"),
                   lbl("report.compare.col_value"), lbl("report.compare.col_threshold"),
                   lbl("report.compare.col_ko"))
  if ("variant" %in% names(r)) {
    m <- cbind(r$variant, m)
    colnames(m)[1L] <- lbl("report.compare.col_variant")
  }
  m
}

#' Matrix „Kennzahl | Wert“ eines Einzelergebnisses
#' @noRd
rep_html_kpi_pairs <- function(res, keys, primary = NULL) {
  keys <- keys[keys %in% names(res$kpis)]
  if (length(keys) == 0L) return(NULL)
  labs <- vapply(keys, function(k) {
    l <- kpi_label(k)
    if (!is.null(primary) && identical(k, primary)) l <- lbl("report.html.kpis.primary_mark",
                                                             label = l)
    l
  }, "", USE.NAMES = FALSE)
  m <- cbind(labs, vapply(keys, function(k) rep_html_kv(res, k), "", USE.NAMES = FALSE))
  m <- matrix(m, ncol = 2L)
  colnames(m) <- c(lbl("report.html.table.kpi"), lbl("report.html.table.value"))
  m
}

#' Statistikzeile einer Kennzahl einer Simulation
#' @noRd
rep_html_stat <- function(mc, k) {
  st <- mc$stats
  if (!is.data.frame(st) || !(k %in% st$kpi)) return(NULL)
  st[st$kpi == k, , drop = FALSE][1L, , drop = FALSE]
}

#' Jahre einer Jahresreihe für Tabellen auswählen (erste Jahre, dann jedes `step`-te, letztes)
#' @param n Anzahl der Zeilen.
#' @return Indizes.
#' @noRd
rep_html_pick_rows <- function(n, head = 5L, step = 5L) {
  if (n <= head + 6L) return(seq_len(n))
  idx <- c(seq_len(head), seq(step, n, by = step), n)
  sort(unique(idx[idx <= n]))
}

#' Ledger-Zeilen eines Laufs nach Abschnitt und Kategorie summieren (Lauf 1, je Periode)
#' @noRd
rep_html_cat_values <- function(res, section, categories, cash = TRUE) {
  led <- res$ledger
  keys <- ledger_select(led, section = section, category = categories, cash = cash)
  out <- numeric(res$grid$T + 1L)
  for (k in keys) out <- out + as.double(led$values[[k]][1L, ])
  out
}

#' Kategorien der Investitionsauszahlungen (wie die Gruppe `investment` von WS-H)
#' @noRd
rep_html_invest_categories <- function() {
  c("land", "acquisition_cost", "capex", "replacement", "relocation_cost")
}

#' Finanzierungsbausteine eines Ergebnisses (Summen über den Horizont, Restschuld in T)
#' @return Data Frame `id`, `label`, `draw`, `interest`, `repay`, `grant`, `balance_end`,
#'   `rate_y1` (Kapitaldienst im ersten vollen Betriebsjahr pro Monat).
#' @noRd
rep_html_instruments <- function(res) {
  led <- res$ledger
  r <- led$rows
  sel <- r$section == "loans"
  ids <- unique(r$source_id[sel])
  ids <- ids[!is.na(ids)]
  if (length(ids) == 0L) return(NULL)
  n_t <- res$grid$T + 1L
  g <- res$grid
  oy <- kpi_op_years(g)
  full <- which(oy$full)
  y1 <- if (length(full) > 0L) oy$cols[[full[1L]]] else integer(0)
  rows <- lapply(ids, function(id) {
    s <- function(cats, cash = TRUE) {
      keys <- r$key[sel & r$source_id == id & r$category %in% cats]
      if (length(keys) == 0L) return(numeric(n_t))
      Reduce(`+`, lapply(keys, function(k) as.double(led$values[[k]][1L, ])))
    }
    debt <- s(c("interest", "fees", "repay"))
    bal <- led$values[[paste0("loan_", id, "_balance")]]
    lab <- rep_html_loan_label(res, id)
    rt <- rep_html_loan_rate(g, s("draw"), s(c("interest", "fees")), s("repay"))
    data.frame(id = id, label = as.character(lab)[1L], draw = sum(s("draw")),
               interest = -sum(s(c("interest", "fees"))),
               repay = -sum(s(c("repay", "repay_balloon", "prepay"))),
               grant = sum(s("repayment_grant")),
               balance_end = if (is.null(bal)) NA_real_ else as.double(bal[1L, n_t]),
               rate_y1 = if (length(y1) > 0L) -sum(debt[y1]) / sum(res$grid$months[y1]) else
                 NA_real_,
               rate = rt$rate, rate_year = rt$year, grace_interest = rt$grace_interest,
               grace_from = rt$grace_from, grace_to = rt$grace_to,
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

#' Rate eines Kredits nach der tilgungsfreien Zeit (SN-01)
#'
#' Rate (Zinsen, Gebühren und Tilgung pro Monat) in der ersten Periode, die vollständig in der
#' Tilgungsphase liegt (zweite Periode mit Tilgung, sonst die erste), mit dem Jahr des
#' Tilgungsbeginns; dazu die Zinsen pro Monat der tilgungsfreien Anlaufjahre nach der
#' Auszahlung.
#' @param g Raster; @param draw,int,repay Zeilen des Kredits (Lauf 1, Vorzeichen des Ledgers).
#' @return Liste `rate`, `year`, `grace_interest`, `grace_from`, `grace_to`.
#' @noRd
rep_html_loan_rate <- function(g, draw, int, repay) {
  na <- list(rate = NA_real_, year = NA_integer_, grace_interest = NA_real_,
             grace_from = NA_integer_, grace_to = NA_integer_)
  tol <- vofi_tol$zero_abs
  rp <- which(abs(repay) > tol & g$months > 0)
  if (length(rp) == 0L) return(na)
  j <- if (length(rp) >= 2L && rp[2L] == rp[1L] + 1L) rp[2L] else rp[1L]
  out <- na
  out$rate <- -(int[j] + repay[j]) / g$months[j]
  out$year <- as.integer(g$year[rp[1L]])
  d0 <- which(abs(draw) > tol)
  if (length(d0) > 0L) {
    gp <- which(seq_along(repay) > d0[1L] & seq_along(repay) < rp[1L] & abs(int) > tol &
                  g$months > 0)
    if (length(gp) > 0L) {
      out$grace_interest <- -sum(int[gp]) / sum(g$months[gp])
      out$grace_from <- as.integer(g$year[min(gp)])
      out$grace_to <- as.integer(g$year[max(gp)])
    }
  }
  out
}

#' Bezeichnung eines Kredits: Label mit Förderprogramm (z. B. „kfw358 (KfW 358)“, SN-10)
#' @noRd
rep_html_loan_label <- function(res, id) {
  fin <- res$spec$financing[[id]] %||% list()
  lab <- as.character(fin$label %||% id)[1L]
  f <- as.character(fin$funding_id %||% NA_character_)[1L]
  prog <- if (is.na(f)) "" else rep_html_program_name(res, f)
  if (nzchar(prog) && !grepl(prog, lab, fixed = TRUE)) paste0(lab, " (", prog, ")") else lab
}

#' Programmbezeichnung eines Förderinstruments (Anbieter und Programmnummer; ohne Nummer die
#' Bezeichnung des Bibliothekseintrags)
#' @noRd
rep_html_program_name <- function(res, f) {
  fs <- res$spec$funding[[f]] %||% list()
  prov <- as.character(exp_code(fs[["provider"]]) %||% "")[1L]
  code <- as.character(fs[["program_code"]] %||% "")[1L]
  if (grepl("^[0-9]+$", code) || !nzchar(code)) return(trimws(paste(prov, code)))
  ents <- res$meta$library$entry %||% character(0)
  ents <- ents[startsWith(ents, "funding/")]
  key <- paste(prov, code)
  memo <- rep_label_env$programs %||% list()
  if (!is.null(memo[[key]])) return(memo[[key]])
  lab <- tryCatch({
    idx <- lib_index(vofi_library_paths())
    hit <- NA_character_
    for (e in ents) {
      pl <- lib_payload(idx, e)$values
      if (identical(as.character(pl$program_code %||% "")[1L], code)) {
        hit <- as.character(lib_get(idx, e)$label %||% NA_character_)[1L]
        break
      }
    }
    hit
  }, error = function(e) NA_character_)
  out <- if (is.na(lab)) trimws(paste(prov, code)) else lab
  memo[[key]] <- out
  rep_label_env$programs <- memo
  out
}

#' Zuschüsse und Steuerermäßigungen eines Ergebnisses (Abschnitt grants)
#' @return Data Frame `label`, `program`, `amount`, `years` bzw. `NULL`.
#' @noRd
rep_html_grants <- function(res) {
  led <- res$ledger
  r <- led$rows
  sel <- which(r$section == "grants" & r$cash)
  if (length(sel) == 0L) return(NULL)
  yrs <- res$grid$year
  rows <- lapply(sel, function(i) {
    v <- as.double(led$values[[r$key[i]]][1L, ])
    nz <- which(abs(v) > vofi_tol$zero_abs)
    if (length(nz) == 0L) return(NULL)
    y <- unique(yrs[nz])
    ytxt <- if (length(y) == 1L) sprintf("%d", y) else sprintf("%d\u2013%d", min(y), max(y))
    prog <- if ("program" %in% names(r)) r$program[i] else NA_character_
    # Bezeichnung: Maßnahmenlabel und Förderprogramm statt Kennungen (SN-10)
    lab <- r$label[i]
    mid <- if ("measure_id" %in% names(r)) r$measure_id[i] else NA_character_
    f <- as.character(names(res$spec$funding %||% list()))
    f <- f[paste0("f_", f, "_grant") %in% r$source_id[i]]
    if (length(f) > 0L) {
      f <- f[1L]
      ml <- if (is.na(mid)) NULL else res$spec$measures[[mid]]$label
      lab <- lbl("report.html.household.grant_label",
                 measure = if (utl_is_string(ml)) ml else (if (is.na(mid)) f else mid))
      prog <- rep_html_program_name(res, f)
    }
    data.frame(label = lab, program = if (is.na(prog)) "" else prog,
               amount = sum(v), years = ytxt, stringsAsFactors = FALSE)
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0L) return(NULL)
  do.call(rbind, rows)
}

#' Summe der Förderung (Zuschüsse und Tilgungszuschüsse)
#' @noRd
rep_html_funding_total <- function(res) {
  g <- rep_html_grants(res)
  ins <- rep_html_instruments(res)
  sum(if (is.null(g)) 0 else g$amount) + sum(if (is.null(ins)) 0 else ins$grant, na.rm = TRUE)
}

#' Bezeichnung einer Eingangsgröße der Simulation (Label des Overlay-Eintrags)
#' @noRd
rep_html_input_label <- function(spec, key) {
  st <- spec$stochastic %||% list()
  find <- function(k) {
    for (blk in c("parameters", "processes")) {
      e <- st[[blk]]
      if (is.list(e) && utl_has_name(e, k) && utl_is_string(e[[k]]$label)) return(e[[k]]$label)
    }
    NULL
  }
  lab <- find(key)
  if (!is.null(lab)) return(lab)
  # Prozessparameter „<prozess>.<parameter>“: Label des Overlay-Eintrags und des Parameters
  # (SN-10)
  if (grepl(".", key, fixed = TRUE)) {
    k <- sub("\\..*$", "", key)
    par <- sub("^[^.]*\\.", "", key)
    lab <- find(k)
    if (!is.null(lab)) {
      return(lbl("report.html.input_param", label = lab,
                 param = lbl(paste0("report.html.input_params.", par), .default = par)))
    }
  }
  key
}

#' Die stärksten Einflussgrößen (Spec 01 Teil C 6.4)
#'
#' Vorrang: Tornado (nach Spannweite), globale Sensitivität (nach |SRRC| bei R² >= 0,7, sonst
#' nach `s1_binned`), Rangkorrelationen der Simulation (nach |Spearman|).
#' @return Zeichenvektor der Bezeichnungen (höchstens `n`).
#' @noRd
rep_html_drivers <- function(rc, n = 3L) {
  for (s in rc$sens) {
    if (identical(s$method, "tornado") && is.data.frame(s$results) && nrow(s$results) > 0L) {
      r <- s$results[order(-abs(s$results$swing), method = "radix"), , drop = FALSE]
      return(utils::head(rep_sens_param_labels(s, r$param), n))
    }
  }
  for (s in rc$sens) {
    g <- s$global
    if (identical(s$method, "global") && is.data.frame(g) && nrow(g) > 0L) {
      r2 <- s$r2_src %||% NA_real_
      by <- if (!is.na(r2) && r2 >= 0.7 && "srrc" %in% names(g)) abs(g$srrc) else
        if ("s1_binned" %in% names(g)) g$s1_binned else abs(g$spearman)
      g <- g[order(-by, method = "radix"), , drop = FALSE]
      return(utils::head(vapply(g$input, function(k) rep_html_input_label(rc$res$spec, k), "",
                                USE.NAMES = FALSE), n))
    }
  }
  mc <- rc$mc
  if (!is.null(mc)) {
    pk <- rep_mc_primary(mc)$kpi
    v <- mc$kpis[[pk]]
    if (!is.null(v)) {
      rk <- rep_rank_correlations(mc, as.double(v))
      if (!is.null(rk)) {
        rk <- rk[!is.na(rk$rho), , drop = FALSE]
        rk <- rk[order(-abs(rk$rho), method = "radix"), , drop = FALSE]
        if (nrow(rk) > 0L) {
          return(utils::head(vapply(rk$input, function(k) rep_html_input_label(mc$spec, k), "",
                                    USE.NAMES = FALSE), n))
        }
      }
    }
  }
  character(0)
}

#' Aufzählung „a, b und c“
#' @noRd
rep_html_join <- function(x) {
  if (length(x) <= 1L) return(utl_collapse(x))
  paste(utl_collapse(x[-length(x)]), lbl("report.html.summary.and"), x[length(x)])
}

#' Satz zu den stärksten Einflussgrößen
#' @noRd
rep_html_drivers_text <- function(rc, household = FALSE) {
  d <- rep_html_drivers(rc)
  if (length(d) == 0L) return(character(0))
  key <- if (household) "report.html.household.drivers" else "report.html.summary.drivers"
  lbl(key, drivers = rep_html_join(d))
}

#' Pflichtsensitivitäten (Spec 01 Teil C 4.4): übergebene Tabelle bzw. mit
#' `cmp_mandatory_sensitivities()` (WS-G) gerechnet
#'
#' Ohne übergebene Tabelle rechnet der Bericht die Pflichtsensitivitäten selbst: mit dem
#' übergebenen Szenario bzw. mit dem Szenario aus dem Auflösungszustand des Ergebnisses
#' (`attr(spec, "scn_state")`, Variante des Ergebnisses; bei Vergleichen je Variante gegen die
#' Referenz). Ergebnisse mit Laufzeit-Overrides oder Szenario-Set werden nicht nachgerechnet,
#' weil ihr Basisfall nicht dem Szenario entspricht. Das Ergebnis wird im Kontext
#' zwischengespeichert; der Grund für „nicht gerechnet“ steht in `rc$cache$mandatory_reason`.
#' @return Data Frame nach `rep_html_mandatory_cols()` bzw. `NULL`.
#' @noRd
rep_html_mandatory <- function(rc) {
  if (!is.null(rc$mandatory)) return(rc$mandatory)
  if (exists("mandatory", envir = rc$cache, inherits = FALSE)) return(rc$cache$mandatory)
  out <- rep_html_mandatory_compute(rc)
  assign("mandatory", out$table, envir = rc$cache)
  assign("mandatory_reason", out$reason, envir = rc$cache)
  out$table
}

#' Szenario und Variante für die Pflichtsensitivitäten (übergeben bzw. aus `scn_state`)
#' @return Liste `scenario`, `variant` bzw. `reason` (Label-Schlüssel des Grundes).
#' @noRd
rep_html_mandatory_source <- function(rc) {
  variant <- rc$res$meta$variant %||% "base"
  if (!is.null(rc$scenario)) return(list(scenario = rc$scenario, variant = variant))
  results <- if (is.null(rc$cmp)) list(rc$base) else
    rc$cmp$results[intersect(c(rc$cmp$baseline, rc$cmp$variants), names(rc$cmp$results))]
  states <- lapply(results, function(r) attr(rep_det_result(r)$spec, "scn_state"))
  ok <- vapply(states, function(s) is.list(s) && inherits(s$scenario, "vofi_scenario"),
               logical(1))
  if (length(states) == 0L || !all(ok)) return(list(reason = "no_scenario"))
  plain <- vapply(states, function(s) length(s$overrides) == 0L && is.null(s$scenario_set),
                  logical(1))
  if (!all(plain)) return(list(reason = "overrides"))
  list(scenario = states[[1L]]$scenario, variant = states[[1L]]$variant %||% variant)
}

#' Pflichtsensitivitäten rechnen (ohne Zwischenspeicher)
#' @return Liste `table` (Data Frame bzw. `NULL`) und `reason` (Text bzw. `NULL`).
#' @noRd
rep_html_mandatory_compute <- function(rc) {
  none <- function(key, ...) {
    list(table = NULL, reason = lbl(paste0("report.html.sensitivity.reason_", key), ...))
  }
  entries <- rc$res$spec$analysis$mandatory_sensitivities %||% list()
  if (length(entries) == 0L && is.null(rc$scenario)) return(list(table = NULL, reason = NULL))
  f <- get0("cmp_mandatory_sensitivities", envir = asNamespace("vofi"), mode = "function",
            inherits = FALSE)
  if (!is.function(f)) return(none("unavailable"))
  src <- rep_html_mandatory_source(rc)
  if (!is.null(src$reason)) return(none(src$reason))
  calc <- function() {
    if (is.null(rc$cmp)) return(f(src$scenario, variant = src$variant, reference = NULL))
    parts <- lapply(rc$cmp$variants %||% character(0), function(v) {
      f(src$scenario, variant = v, reference = rc$cmp$baseline)
    })
    parts <- parts[!vapply(parts, is.null, logical(1))]
    if (length(parts) == 0L) NULL else do.call(rbind, parts)
  }
  # Die Laeufe wiederholen Aufloesung und Bau des Szenarios; deren Meldungen kennt der Nutzer
  # bereits aus dem eigenen Lauf
  tab <- tryCatch(
    withCallingHandlers(calc(),
                        vofi_message = function(m) invokeRestart("muffleMessage"),
                        vofi_warning = function(w) invokeRestart("muffleWarning")),
    error = function(e) structure(list(message = conditionMessage(e)), class = "rep_html_failure")
  )
  if (inherits(tab, "rep_html_failure")) {
    vofi_warn("report.html.sensitivity.mandatory_failed", message = tab$message)
    return(none("failed", message = tab$message))
  }
  if (!is.data.frame(tab)) return(none("unavailable"))
  list(table = tab, reason = NULL)
}

#' Maßgebliche Daten der Gültigkeitsprüfung je Bibliothekseintrag (4.9)
#'
#' Für Einträge `funding/*` das Antragsdatum (`application_date`) der Instrumente, deren Werte
#' aus dem Eintrag stammen (Herkunft der Spezifikation), sonst der Rechtsstand.
#' @param res `vofi_result`.
#' @param entries Bibliotheks-ids.
#' @param ref Rechtsstand (Date).
#' @return Liste `dates` (je Eintrag ein Date-Vektor) und `application` (logisch je Eintrag:
#'   Antragsdatum statt Rechtsstand).
#' @noRd
rep_html_library_dates <- function(res, entries, ref) {
  out <- list(dates = rep(list(ref), length(entries)),
              application = rep(FALSE, length(entries)))
  fund <- res$spec$funding
  is_f <- startsWith(entries, "funding/")
  if (!any(is_f) || !is.list(fund) || length(fund) == 0L) return(out)
  prov <- tryCatch(as.data.frame(res$spec), error = function(e) NULL)
  if (!is.data.frame(prov) || !all(c("path", "entry") %in% names(prov))) return(out)
  prov <- prov[!is.na(prov$entry) & startsWith(as.character(prov$path), "funding."), ,
               drop = FALSE]
  for (i in which(is_f)) {
    paths <- as.character(prov$path[prov$entry == entries[i]])
    ids <- unique(vapply(strsplit(paths, ".", fixed = TRUE), function(s) s[2L], ""))
    ids <- ids[ids %in% names(fund)]
    dates <- lapply(ids, function(f) {
      tryCatch(as.Date(fund_application_date(res$spec, fund[[f]])), error = function(e) NULL)
    })
    dates <- dates[!vapply(dates, function(d) length(d) == 0L, logical(1))]
    if (length(dates) == 0L) next
    d <- do.call(c, dates)
    d <- d[!is.na(d)]
    if (length(d) == 0L) next
    out$dates[[i]] <- sort(unique(d))
    out$application[i] <- TRUE
  }
  out
}

#' Prüfstatus der Bibliothekseinträge (Gültigkeit und Stand nach 4.9, Qualität nach Teil C 3.2)
#'
#' Gültigkeit `[valid_from, valid_to)` zum maßgeblichen Datum (Förderung: Antragsdatum des
#' Instruments, sonst Rechtsstand); Stand `as_of` älter als 6 Monate (Prozesseinträge 12 Monate)
#' vor dem Rechtsstand.
#' @return Data Frame der Einträge mit `status` (Text), `ref_date` (Text der maßgeblichen Daten)
#'   und `flag` (hervorheben) bzw. `NULL`.
#' @noRd
rep_html_library_status <- function(res) {
  lib <- res$meta$library %||% res$spec$library
  if (!is.data.frame(lib) || nrow(lib) == 0L) return(NULL)
  ref <- as.Date(res$meta$legal_state %||% res$grid$valuation_date)
  from <- as.Date(lib$valid_from)
  to <- as.Date(lib$valid_to)
  as_of <- as.Date(lib$as_of)
  entries <- as.character(lib$entry)
  months <- ifelse(startsWith(entries, "processes/"), 12L, 6L)
  limit <- vapply(months, function(mm) {
    as.numeric(seq(ref, by = paste0("-", mm, " months"), length.out = 2L)[2L])
  }, double(1))
  rd <- rep_html_library_dates(res, entries, ref)
  expired <- vapply(seq_along(entries), function(i) {
    d <- rd$dates[[i]]
    any((!is.na(from[i]) & d < from[i]) | (!is.na(to[i]) & d >= to[i]))
  }, logical(1))
  old <- !expired & !is.na(as_of) & as.numeric(as_of) < limit
  q <- as.character(lib$quality %||% rep(NA_character_, nrow(lib)))
  low_q <- !is.na(q) & q %in% c("C", "D")
  status <- rep(lbl("report.html.assumptions.status_ok"), nrow(lib))
  status[low_q] <- vapply(q[low_q], function(qq) {
    lbl(paste0("report.html.assumptions.status_quality_", qq))
  }, "")
  status[old] <- vapply(months[old], function(mm) {
    lbl("report.html.assumptions.status_old", months = as.integer(mm))
  }, "")
  status[expired] <- lbl("report.html.assumptions.status_expired")
  ref_txt <- vapply(seq_along(entries), function(i) {
    key <- if (rd$application[i]) "ref_application" else "ref_legal"
    lbl(paste0("report.html.assumptions.", key), dates = utl_collapse(fmt_date(rd$dates[[i]])))
  }, "")
  data.frame(entry = entries, as_of = as_of, valid_from = from, valid_to = to,
             quality = q, status = status, ref_date = ref_txt, outdated = expired | old,
             flag = expired | old | low_q, stringsAsFactors = FALSE)
}

#' Spezifikationswert als Text (Konstante: Zahl; sonst Darstellung der Wertform)
#' @noRd
rep_html_spec_text <- function(spec, path, unit = "num", res = NULL) {
  fmt <- function(v) switch(unit, pct = fmt_pct(v[1L], 2), eur = fmt_eur(v[1L], 0),
                            fmt_num(v[1L], 2))
  v <- rep_spec_number(spec, path)
  if (!is.null(v)) return(fmt(v))
  node <- path_get(spec, path)
  if (is.null(node)) return(NA_character_)
  # Bezüge und Pfade: aufgelöster Basisfallwert statt des Ausdrucks (SN-06)
  if (!is.null(res)) {
    ctx <- tryCatch(rep_ctx_of(res), error = function(e) NULL)
    if (!is.null(ctx)) {
      sc <- tryCatch(ctx$value_base(path, "scalar"), error = function(e) NULL)
      if (is.numeric(sc) && length(sc) >= 1L && !is.na(sc[1L])) return(fmt(sc))
      pa <- tryCatch(ctx$value_base(path, "path"), error = function(e) NULL)
      if (is.matrix(pa) && ncol(pa) >= 2L && !is.na(pa[1L, 2L])) {
        return(lbl("report.html.assumptions.first_year_base", value = fmt(pa[1L, 2L])))
      }
    }
  }
  rep_value_text(node)
}

# ---------------------------------------------------------------------------------------------
# Abschnitte: Management Summary bzw. Das Wichtigste in Kürze
# ---------------------------------------------------------------------------------------------

#' @noRd
rep_html_sec_summary <- function(rc) {
  title <- rep_html_sec_title("summary", rc)
  blocks <- if (rc$household) rep_html_summary_household(rc) else rep_html_summary_expert(rc)
  rep_html_section("summary", title, blocks)
}

#' Kopfzeilen der Primärkennzahl eines Einzelergebnisses bzw. einer Simulation
#' @noRd
rep_html_lead <- function(rc) {
  res <- rc$res
  if (!is.null(rc$mc)) {
    pk <- rep_mc_primary(rc$mc)
    s <- rep_html_stat(rc$mc, pk$kpi)
    if (is.null(s)) return(character(0))
    u <- rep_html_unit(pk$kpi)
    f <- function(v) rep_fmt_value(v, u, 0)
    out <- lbl("report.html.summary.lead_mc", kpi = kpi_label(pk$kpi), det = f(s$deterministic),
               mean = f(s$mean), median = f(s$q50), q05 = f(s$q05), q95 = f(s$q95),
               se = f(s$se))
    return(c(out, rep_existing_note(pk$note)))
  }
  pk <- rep_primary_kpi(res)
  if (is.na(pk$kpi)) return(character(0))
  c(lbl("report.html.summary.lead_det", kpi = kpi_label(pk$kpi), value = rep_html_kv(res, pk$kpi),
        value_ex = rep_html_kv(res, paste0(pk$kpi, "_ex_rv"))),
    rep_existing_note(pk$note))
}

#' Rendite- und Warmmietenzeilen eines Einzelergebnisses (12.3, 12.3a)
#' @noRd
rep_html_return_lines <- function(res) {
  prim <- kpi_primary(res$spec)
  out <- character(0)
  rk <- prim$return_kpi
  if (rk %in% names(res$kpis)) {
    out <- c(out, lbl("report.html.summary.return", kpi = kpi_label(rk),
                      value = rep_html_kv(res, rk)))
    h <- rep_spec_number(res$spec, "analysis.thresholds.roe_hurdle")
    if (!is.null(h)) out <- c(out, lbl("report.html.summary.hurdle", value = fmt_pct(h, 2)))
  }
  w <- rep_html_kn(res, "warm_rent_change_prepost_y1")
  if (!is.na(w)) {
    out <- c(out, lbl("report.html.summary.warm_rent", value = fmt_eur(w, 2)))
  }
  out
}

#' Kopfkennzahlen als Tabelle (Einzelergebnis: Wert; Simulation: Basisfall, Mittel, Quantile)
#' @noRd
rep_html_head_table <- function(rc) {
  if (!is.null(rc$mc)) {
    m <- rep_mc_stats_matrix(rc$mc, rep_mc_head_kpis(rc$mc))
    if (is.null(m)) return(NULL)
    drop <- c(lbl("report.mc.col_se"), lbl("report.mc.col_q25"), lbl("report.mc.col_q75"),
              lbl("report.mc.col_na"))
    return(m[, !(colnames(m) %in% drop), drop = FALSE])
  }
  pk <- rep_primary_kpi(rc$res)
  rep_html_kpi_pairs(rc$res, rep_head_kpis(rc$res), if (pk$fallback) NULL else pk$kpi)
}

#' Ampeln eines Vergleichs als Zeichenmatrix
#' @noRd
rep_html_cmp_tl_matrix <- function(cmp) {
  tl <- cmp$traffic_light
  if (!is.data.frame(tl) || nrow(tl) == 0L) return(NULL)
  yn <- function(v) ifelse(v %in% TRUE, lbl("report.common.yes"), lbl("report.common.no"))
  ko <- vapply(seq_len(nrow(tl)), function(i) {
    k <- tl$ko_codes[i] %||% ""
    if (is.na(k) || !nzchar(k)) return("")
    codes <- strsplit(k, "[,; ]+")[[1L]]
    utl_collapse(vapply(codes[nzchar(codes)], rep_restriction_label, ""))
  }, "")
  m <- cbind(tl$variant, vapply(tl$level, rep_html_level_text, ""),
             vapply(tl$stage1 %||% tl$level, rep_html_level_text, ""),
             vapply(tl$basis, function(b) lbl(paste0("report.traffic.basis_", b), .default = b),
                    ""),
             yn(tl$rv_dependent), ko)
  m <- matrix(m, nrow = nrow(tl))
  colnames(m) <- c(lbl("report.html.ampel.col_variant"), lbl("report.html.ampel.col_level"),
                   lbl("report.html.ampel.col_stage1"), lbl("report.html.ampel.col_basis"),
                   lbl("report.html.ampel.col_rv"), lbl("report.html.ampel.col_ko"))
  m
}

#' Kopfkennzahlen eines Vergleichs (WS-H) ergänzt um die Rendite der Mehrinvestition, die
#' Renditekennzahl der Perspektive und die Warmmietenänderung (Konzept 1.4 „auf einen Blick“)
#' @noRd
rep_html_cmp_head_kpis <- function(cmp) {
  base_res <- rep_det_result(cmp$results[[cmp$baseline]] %||% cmp$results[[1L]])
  rk <- kpi_primary(base_res$spec)$return_kpi
  extra <- c("incremental_return", "incremental_return_ex_rv", if (utl_is_string(rk)) rk,
             "warm_rent_change_prepost_y1", "warm_rent_change_y1")
  unique(c(rep_cmp_kpis(cmp, head = TRUE), extra[extra %in% cmp$kpi_table$kpi]))
}

#' Kernaussagen eines Vergleichs je Variante (Vergleichsregel, P(besser) bzw. Basisfall)
#'
#' Die Wahrscheinlichkeit „besser als die Referenz“ steht nur bei Simulationen; im
#' deterministischen Vergleich ist sie 0 oder 1 (12.6) und erscheint als „besser bzw.
#' schlechter im Basisfall“ (keine Scheingenauigkeit, Konzept 4.7). Dazu die Rendite der
#' Mehrinvestition und die Rendite- bzw. Warmmietenkennzahl je Variante (Konzept 1.4).
#' @param is_mc Vergleich mit Simulation.
#' @noRd
rep_html_cmp_lead <- function(cmp, is_mc = FALSE) {
  ds <- cmp$diff_stats
  kpi <- "delta_vs_reference"
  out <- character(0)
  base_res <- rep_det_result(cmp$results[[cmp$baseline]] %||% cmp$results[[1L]])
  rk_kpi <- kpi_primary(base_res$spec)$return_kpi
  for (v in cmp$variants %||% character(0)) {
    d <- if (is.data.frame(ds)) ds[ds$variant == v & ds$kpi == kpi, , drop = FALSE] else NULL
    val <- rep_html_cmp_delta(cmp, v, kpi)
    pb <- if (!is.null(d) && nrow(d) > 0L) d$prob_better[1L] else NA_real_
    prob <- if (is_mc && !is.na(pb)) {
      lbl("report.html.summary.lead_cmp_prob", baseline = cmp$baseline, p = pb)
    } else if (!is_mc && !is.na(val) && abs(val) > vofi_tol$zero_abs) {
      lbl(paste0("report.html.summary.lead_cmp_", if (val > 0) "better" else "worse"),
          baseline = cmp$baseline)
    } else {
      ""
    }
    out <- c(out, lbl("report.html.summary.lead_cmp", variant = v, baseline = cmp$baseline,
                      kpi = kpi_label(kpi), value = rep_fmt_value(val, "EUR", 0), prob = prob))
    extra <- character(0)
    for (k in unique(c("incremental_return", rk_kpi, "warm_rent_change_prepost_y1"))) {
      if (!utl_is_string(k) || !(k %in% cmp$kpi_table$kpi)) next
      x <- rep_cmp_value(cmp, v, k)
      if (is.na(x)) next
      extra <- c(extra, lbl("report.html.summary.kpi_item", kpi = kpi_label(k),
                            value = rep_fmt_value(x, rep_html_unit(k), 2)))
    }
    if (length(extra) > 0L) {
      out <- c(out, lbl("report.html.summary.lead_cmp_kpis", variant = v,
                        items = utl_collapse(extra, "; ")))
    }
  }
  rk <- cmp$ranking
  if (is.data.frame(rk) && nrow(rk) > 0L) {
    rk <- rk[order(rk$rank, method = "radix"), , drop = FALSE]
    out <- c(out, lbl("report.html.summary.best", criterion = kpi_label(rk$criterion[1L]),
                      ranking = utl_collapse(paste0(rk$rank, ". ", rk$variant))))
  }
  out
}

#' Management Summary (Fachmodus)
#' @noRd
rep_html_summary_expert <- function(rc) {
  res <- rc$res
  blocks <- list()
  if (!is.null(rc$cmp)) {
    cmp <- rc$cmp
    best <- rep_html_best_variant(cmp)
    blocks <- c(blocks, list(
      rep_html_b_ampel(if (is.na(best)) NULL else rep_html_cmp_tl(cmp, best)),
      rep_html_b_par(rep_html_cmp_lead(cmp, rc$is_mc)),
      rep_html_b_table(rep_html_cmp_tl_matrix(cmp),
                       caption = lbl("report.html.variants.traffic_header")),
      rep_html_b_table(rep_cmp_kpi_matrix(cmp, rep_html_cmp_head_kpis(cmp), short = FALSE),
                       caption = lbl("report.html.variants.kpi_header"))
    ))
    wr <- cmp$differences$warm_rent_change_y1
    if (is.matrix(wr)) {
      for (j in seq_len(ncol(wr))) {
        v <- mean(wr[, j], na.rm = TRUE)
        if (is.finite(v)) {
          txt <- lbl("report.html.summary.warm_rent_ref", baseline = cmp$baseline,
                     variant = colnames(wr)[j] %||% cmp$variants[j], value = fmt_eur(v, 2))
          blocks[[length(blocks) + 1L]] <- rep_html_b_par(txt)
        }
      }
    }
    restr <- rep_html_restr_matrix(cmp$restrictions)
    blocks[[length(blocks) + 1L]] <- if (is.null(restr)) {
      rep_html_b_par(lbl("report.html.summary.restrictions_none"))
    } else {
      rep_html_b_table(restr, caption = lbl("report.html.sections.restrictions"))
    }
  } else {
    tl <- rep_html_main_tl(rc)
    blocks <- c(blocks, list(
      rep_html_b_ampel(tl),
      rep_html_b_par(c(rep_html_lead(rc), rep_html_return_lines(res))),
      rep_html_b_table(rep_html_head_table(rc), caption = lbl("report.html.summary.head_table"))
    ))
    restr <- rep_html_restr_matrix(tl$restrictions)
    blocks[[length(blocks) + 1L]] <- if (is.null(restr)) {
      rep_html_b_par(lbl("report.html.summary.restrictions_none"))
    } else {
      rep_html_b_table(restr, caption = lbl("report.html.sections.restrictions"))
    }
  }
  blocks <- c(blocks, list(rep_html_b_par(rep_html_drivers_text(rc)),
                           rep_html_b_callout("info", rep_result_notes(res))))
  blocks
}

#' Kopfwerte der Haushaltssicht je Variante (WS-H, Attribut `summary`)
#' @noRd
rep_html_hh_summary <- function(rc) {
  if (!is.null(rc$cache$hh)) return(rc$cache$hh)
  hv <- vofi_household_view(rc$x)
  s <- attr(hv, "summary")
  if (!is.data.frame(s)) s <- data.frame()
  rc$cache$hh <- list(view = hv, summary = s)
  rc$cache$hh
}

#' Risikoaussagen in einfachen Worten (Memo 07 Paragraf 5.4)
#' @noRd
rep_html_hh_risk_lines <- function(rc) {
  out <- character(0)
  if (!is.null(rc$cmp)) {
    ds <- rc$cmp$diff_stats
    if (rc$is_mc && is.data.frame(ds)) {
      ds <- ds[ds$kpi == "delta_vs_reference", , drop = FALSE]
      for (i in seq_len(nrow(ds))) {
        if (is.na(ds$prob_better[i])) next
        out <- c(out, lbl("report.html.risk.household_better",
                          count = as.integer(round(10 * ds$prob_better[i])),
                          variant = rep_vlabel(ds$variant[i], short = TRUE),
                          baseline = rep_vlabel(rc$cmp$baseline, short = TRUE)))
      }
    }
    return(out)
  }
  if (is.null(rc$mc)) return(out)
  pk <- rep_mc_primary(rc$mc)
  s <- rep_html_stat(rc$mc, pk$kpi)
  if (is.null(s) || is.na(s$p_neg)) return(out)
  if (identical(pk$kpi, "delta_terminal_value") && !isTRUE(kpi_primary(rc$res$spec)$existing)) {
    out <- c(out, lbl("report.html.risk.household_loss",
                      count = as.integer(round(10 * s$p_neg))))
  } else {
    out <- c(out, lbl("report.html.risk.household_count",
                      count = as.integer(round(10 * (1 - s$p_neg))), label = kpi_label(pk$kpi)))
  }
  out
}

#' Das Wichtigste in Kürze (Haushaltsmodus)
#' @noRd
rep_html_summary_household <- function(rc) {
  hh <- rep_html_hh_summary(rc)
  s <- hh$summary
  blocks <- list()
  fund_res <- rc$res
  if (!is.null(rc$cmp)) {
    best <- rep_html_best_variant(rc$cmp)
    if (!is.na(best)) fund_res <- rep_det_result(rc$cmp$results[[best]])
    blocks[[1L]] <- rep_html_b_ampel(if (is.na(best)) NULL else rep_html_cmp_tl(rc$cmp, best),
                                     household = TRUE)
    for (v in rc$cmp$variants %||% character(0)) {
      txt <- if (nrow(s) > 0L) s$text[s$variant == v] else character(0)
      if (length(txt) == 0L) next
      blocks[[length(blocks) + 1L]] <- rep_html_var_heading(v)
      blocks[[length(blocks) + 1L]] <- rep_html_b_list(txt)
    }
  } else {
    blocks[[1L]] <- rep_html_b_ampel(rep_html_main_tl(rc), household = TRUE)
    blocks[[2L]] <- rep_html_b_list(if (nrow(s) > 0L) s$text else character(0))
  }
  ft <- rep_html_funding_total(fund_res)
  blocks <- c(blocks, list(
    rep_html_b_par(if (ft > vofi_tol$zero_abs) {
      lbl("report.html.household.grants", value = rep_amount_text(ft, "sum"))
    } else {
      lbl("report.html.household.no_grants")
    }),
    rep_html_b_par(c(rep_html_hh_risk_lines(rc), rep_html_drivers_text(rc, household = TRUE)))
  ))
  blocks
}

# ---------------------------------------------------------------------------------------------
# Abschnitt: Variantenvergleich
# ---------------------------------------------------------------------------------------------

#' @noRd
rep_html_sec_variants <- function(rc) {
  cmp <- rc$cmp
  if (is.null(cmp)) return(NULL)
  title <- rep_html_sec_title("variants", rc)
  if (rc$household) return(rep_html_section("variants", title, rep_html_variants_household(rc)))
  kpis <- rep_cmp_kpis(cmp, head = FALSE)
  blocks <- list(
    rep_html_b_table(rep_cmp_kpi_matrix(cmp, kpis, short = FALSE),
                     caption = lbl("report.html.variants.kpi_header")),
    rep_html_b_table(rep_html_diff_matrix(cmp, rc$is_mc),
                     caption = lbl("report.html.variants.diff_header"))
  )
  pb <- if (rc$is_mc) rep_prob_better_text(cmp) else NULL
  if (!rc$is_mc) {
    blocks[[length(blocks) + 1L]] <- rep_html_b_par(rep_html_cmp_det_text(cmp))
  }
  if (!is.null(pb)) {
    blocks[[length(blocks) + 1L]] <- rep_html_b_par(lbl("report.html.variants.prob_better",
                                                        text = pb))
  }
  if (rc$plots) {
    blocks[[length(blocks) + 1L]] <- rep_html_b_plot(function() vofi_plot(cmp, "endwert"),
                                                     lbl("report.plot.title_endwert",
                                                         kpi = kpi_label("delta_terminal_value")))
    if (rc$is_mc) {
      cap <- lbl("report.plot.title_cmp_diff", kpi = kpi_label("delta_vs_reference"),
                 baseline = cmp$baseline)
      fun <- function() vofi_plot(cmp, "differenz", kpi = "delta_vs_reference")
      blocks[[length(blocks) + 1L]] <- rep_html_b_plot(fun, cap)
    }
  }
  blocks <- c(blocks, list(
    rep_html_b_heading(lbl("report.html.variants.traffic_header")),
    rep_html_b_table(rep_html_cmp_tl_matrix(cmp)),
    rep_html_b_list(rep_cmp_status_lines(cmp))
  ))
  restr <- rep_html_restr_matrix(cmp$restrictions)
  if (!is.null(restr)) {
    blocks <- c(blocks, list(rep_html_b_heading(lbl("report.html.variants.restrictions_header")),
                             rep_html_b_table(restr)))
  }
  cd <- cmp$conditional
  if (is.data.frame(cd) && nrow(cd) > 0L) {
    m <- cbind(cd$variant, as.character(cd$branch), vapply(cd$kpi, kpi_label, "",
                                                           USE.NAMES = FALSE),
               fmt_num(cd$mean, 0), fmt_num(cd$q05, 0), fmt_num(cd$q50, 0), fmt_num(cd$q95, 0),
               fmt_pct(cd$prob_better, 1))
    m <- matrix(m, nrow = nrow(cd))
    colnames(m) <- c(lbl("report.compare.col_variant"), lbl("report.compare.col_branch"),
                     lbl("report.mc.col_kpi"), lbl("report.mc.col_mean"), lbl("report.mc.col_q05"),
                     lbl("report.mc.col_median"), lbl("report.mc.col_q95"),
                     lbl("report.compare.col_prob_better"))
    blocks <- c(blocks, list(rep_html_b_heading(lbl("report.html.variants.conditional_header")),
                             rep_html_b_table(m)))
  }
  if (identical(rc$res$spec$project$comparison_mode, "differential")) {
    blocks[[length(blocks) + 1L]] <- rep_html_b_callout("info",
                                                        lbl("report.html.variants.differential"))
  }
  blocks <- c(blocks, list(rep_html_b_heading(lbl("report.html.variants.comparability_header")),
                           rep_html_b_par(trimws(rep_cmp_comparability(cmp)))))
  rep_html_section("variants", title, blocks)
}

#' Vergleich gegen die Referenz als Zeichenmatrix
#'
#' Mit Simulation die Statistik der Differenzen je Lauf (WS-H, `rep_cmp_diff_matrix()`); im
#' deterministischen Vergleich nur der Wert des Basisfalls (Quantile und Wahrscheinlichkeit
#' wären Scheingenauigkeit, Konzept 4.7).
#' @noRd
rep_html_diff_matrix <- function(cmp, is_mc) {
  if (is_mc) return(rep_cmp_diff_matrix(cmp))
  ds <- cmp$diff_stats
  if (!is.data.frame(ds) || nrow(ds) == 0L) return(NULL)
  val <- vapply(seq_len(nrow(ds)), function(i) {
    rep_fmt_value(ds$mean[i], rep_html_unit(ds$kpi[i]), 0)
  }, "")
  m <- cbind(ds$variant, vapply(ds$kpi, kpi_label, "", USE.NAMES = FALSE), val)
  m <- matrix(m, nrow = nrow(ds))
  colnames(m) <- c(lbl("report.compare.col_variant"), lbl("report.mc.col_kpi"),
                   lbl("report.html.variants.col_base_case"))
  m
}

#' Vergleichskennzahl `delta_vs_reference` einer Variante bzw. eines Falls eines Vergleichs
#'
#' Hauptvarianten aus `diff_stats` (Mittel je Lauf), Fälle der Szenario-Sets (z. B.
#' `v2@vorsichtig`, nicht in `differences`/`diff_stats`, 13.3) aus `kpi_table`; die Referenz
#' selbst hat keinen Wert (`NA`).
#' @noRd
rep_html_cmp_delta <- function(cmp, variant, kpi = "delta_vs_reference") {
  if (identical(variant, cmp$baseline)) return(NA_real_)
  ds <- cmp$diff_stats
  if (is.data.frame(ds) && nrow(ds) > 0L) {
    d <- ds[ds$variant == variant & ds$kpi == kpi, , drop = FALSE]
    if (nrow(d) > 0L && !is.na(d$mean[1L])) return(as.double(d$mean[1L]))
  }
  rep_cmp_value(cmp, variant, kpi)
}

#' Ist ein Fall des Vergleichs eine Referenz (Referenzvariante bzw. `<baseline>@<set>` eines
#' statischen Szenario-Sets, `meta$cases`)?
#' @noRd
rep_html_is_reference <- function(cmp, case) {
  if (identical(case, cmp$baseline)) return(TRUE)
  cs <- cmp$meta$cases
  is.data.frame(cs) && all(c("case", "reference") %in% names(cs)) &&
    any(cs$case == case & cs$reference == case)
}

#' Ergebnis eines deterministischen Vergleichs in Worten („besser bzw. schlechter im
#' Basisfall“)
#' @noRd
rep_html_cmp_det_text <- function(cmp) {
  out <- character(0)
  for (v in cmp$variants %||% character(0)) {
    val <- rep_html_cmp_delta(cmp, v)
    if (is.na(val)) next
    key <- if (abs(val) <= vofi_tol$zero_abs) "det_equal" else if (val > 0) "det_better" else
      "det_worse"
    out <- c(out, lbl(paste0("report.html.variants.", key), variant = v,
                      baseline = cmp$baseline, value = rep_fmt_value(abs(val), "EUR", 0)))
  }
  if (length(out) == 0L) return(character(0))
  c(out, lbl("report.html.variants.det_note"))
}

#' Kennzahlen eines Vergleichs für Haushalte (gerundet, Wörter statt Vorzeichen, Memo 07
#' Paragraf 5.4)
#'
#' Cashflow-Kennzahlen als „Überschuss … €“ bzw. „Zuschuss … €“, Ersparnisse als „spart … €“
#' bzw. „… € mehr“, übrige Beträge (Belastung, Eigenanteil, Nachschüsse) gerundet ohne
#' Vorzeichen (Gegenrichtung in Worten).
#' @param kpi Kennzahl (für die Richtung).
#' @noRd
rep_html_hh_fmt <- function(v, unit, kpi = "") {
  if (is.na(v)) return(fmt_num(NA))
  if (startsWith(kpi, "monthly_net_cashflow")) return(rep_html_hh_cash_text(v))
  if (startsWith(kpi, "monthly_saving") || startsWith(kpi, "monthly_cashflow_change")) {
    return(rep_html_hh_diff_text(v))
  }
  if (unit %in% c("EUR_month", "EUR")) {
    kind <- if (identical(unit, "EUR")) "sum" else "month"
    r <- rep_round_household(v, kind)
    if (r >= 0) return(lbl("report.html.household.amount", value = fmt_int(r)))
    return(rep_html_hh_amount(v, "out", kind))
  }
  if (identical(unit, "share")) return(paste0(fmt_int(rep_round_household(v, "pct")), " %"))
  rep_fmt_value(v, unit, 0)
}

#' Varianten im Vergleich (Haushaltsmodus): 4–6 Kennzahlen und Klartext je Variante
#' @noRd
rep_html_variants_household <- function(rc) {
  cmp <- rc$cmp
  keys <- if (rc$owner) {
    c("monthly_burden_y1", "monthly_burden_avg10", "own_contribution", "sum_equity_calls",
      "payback_year", "burden_ratio_max")
  } else {
    c("monthly_net_cashflow_y1", "monthly_net_cashflow_min", "own_contribution",
      "sum_equity_calls", "payback_year")
  }
  # Amortisation gegenüber der Referenz ohne Restwert wie im Klartext (SN-02)
  if ("payback_year_vs_reference_ex_rv" %in% cmp$kpi_table$kpi) {
    keys[keys == "payback_year"] <- "payback_year_vs_reference_ex_rv"
  }
  keys <- keys[keys %in% cmp$kpi_table$kpi]
  vars <- rep_comparison_variants(cmp)
  blocks <- list()
  if (length(keys) > 0L) {
    cells <- vapply(vars, function(v) {
      vapply(keys, function(k) {
        rep_html_hh_fmt(rep_cmp_value(cmp, v, k), rep_html_unit(k), k)
      }, "")
    }, character(length(keys)))
    m <- cbind(vapply(keys, kpi_label, "", USE.NAMES = FALSE), matrix(cells, nrow = length(keys)))
    colnames(m) <- c(lbl("report.html.table.kpi"), rep_vlabel(vars, short = TRUE))
    blocks[[1L]] <- rep_html_b_table(m, caption = lbl("report.html.variants.household_header"))
  }
  s <- rep_html_hh_summary(rc)$summary
  if (nrow(s) > 0L) {
    items <- character(0)
    for (v in cmp$variants %||% character(0)) {
      sv <- s[s$variant == v & s$item %in% c("saving_y1", "saving_avg10", "total_saving",
                                             "cashflow_change_y1", "payback_year"), ,
              drop = FALSE]
      items <- c(items, vapply(sv$text, function(tx) {
        lbl("report.html.variants.household_text", variant = rep_vlabel(v, short = TRUE),
            text = tx)
      }, "", USE.NAMES = FALSE))
    }
    blocks[[length(blocks) + 1L]] <- rep_html_b_list(items)
  }
  blocks
}

# ---------------------------------------------------------------------------------------------
# Abschnitt: Kennzahlen mit und ohne Restwert
# ---------------------------------------------------------------------------------------------

#' Kennzahltabellen eines Einzelergebnisses: mit/ohne Restwert, unabhängig, je WE und m²
#' @noRd
rep_html_kpi_tables <- function(res, compact = FALSE) {
  kp <- vofi_kpis(res)
  if ("sim" %in% names(kp)) kp <- kp[kp$sim == 1L, setdiff(names(kp), "sim"), drop = FALSE]
  if (compact) {
    prim <- kpi_primary(res$spec)
    keep <- c(rep_primary_kpi(res)$kpi, "terminal_value", prim$return_kpi, prim$payback,
              "withdrawal_equivalent", "dscr_min", "icr_min", "ltv_max", "warm_rent_y1",
              "warm_rent_change_prepost_y1", "own_contribution", "sum_equity_calls",
              "min_net_liquidity", "co2_emissions")
    kp <- kp[kp$base %in% keep, , drop = FALSE]
  }
  if (nrow(kp) == 0L) return(list())
  val <- function(i) rep_fmt_kpi(kp$value[i], rep_html_unit(kp$kpi[i]), kp$na_reason[i], 0)
  lab <- function(i) {
    l <- kp$label[i]
    if (isTRUE(kp$primary[i]) && identical(kp$kpi[i], kp$base[i])) {
      l <- lbl("report.html.kpis.primary_mark", label = l)
    }
    l
  }
  per <- list()
  if (!compact) {
    for (p in c("unit", "m2")) {
      alt <- tryCatch(vofi_kpis(res, per = p), vofi_error = function(e) NULL)
      if (!is.null(alt) && "sim" %in% names(alt)) alt <- alt[alt$sim == 1L, , drop = FALSE]
      if (!is.null(alt)) per[[p]] <- alt
    }
  }
  with <- which(kp$rv == "with")
  rows <- lapply(with, function(i) {
    j <- match(paste0(kp$kpi[i], "_ex_rv"), kp$kpi)
    out <- c(lab(i), val(i), if (is.na(j)) "\u2013" else val(j))
    for (p in names(per)) {
      a <- per[[p]]
      ai <- match(kp$kpi[i], a$kpi)
      eur <- kp$unit[i] %in% c("EUR", "EUR_pa", "EUR_month")
      out <- c(out, if (is.na(ai) || !eur) "" else rep_fmt_value(a$value[ai], kp$unit[i], 0))
    }
    c(out, if (is.na(kp$note[i])) "" else kp$note[i])
  })
  blocks <- list()
  if (length(rows) > 0L) {
    m <- do.call(rbind, rows)
    colnames(m) <- c(lbl("report.html.table.kpi"), lbl("report.html.table.with_rv"),
                     lbl("report.html.table.without_rv"),
                     vapply(names(per), function(p) {
                       lbl(paste0("report.html.table.per_", if (p == "unit") "unit" else "m2"))
                     }, ""), lbl("report.html.table.note"))
    if (all(!nzchar(m[, ncol(m)]))) m <- m[, -ncol(m), drop = FALSE]
    blocks[[1L]] <- rep_html_b_table(m, caption = lbl("report.html.table.rv_with_header"))
  }
  ind <- which(kp$rv %in% c("independent", "unknown"))
  if (length(ind) > 0L) {
    m <- cbind(vapply(ind, lab, ""), vapply(ind, val, ""),
               ifelse(is.na(kp$note[ind]), "", kp$note[ind]))
    m <- matrix(m, nrow = length(ind))
    colnames(m) <- c(lbl("report.html.table.kpi"), lbl("report.html.table.value"),
                     lbl("report.html.table.note"))
    cap <- lbl("report.html.table.rv_independent_header")
    blocks[[length(blocks) + 1L]] <- rep_html_b_table(m, caption = cap)
  }
  blocks
}

#' Zeitreihen der Kennzahlen eines Ergebnisses als Tabelle (Jahre in Zeilen)
#' @noRd
rep_html_series_table <- function(res, names = NULL) {
  ser <- res$kpi_series %||% list()
  nms <- names %||% names(ser)
  nms <- nms[nms %in% names(ser)]
  if (length(nms) == 0L) return(NULL)
  years <- sort(unique(unlist(lapply(ser[nms], function(s) as.integer(s$years)))))
  if (length(years) == 0L) return(NULL)
  cols <- lapply(nms, function(nm) {
    s <- ser[[nm]]
    v <- as.double(as.matrix(s$values)[1L, ])
    u <- rep_html_unit(nm)
    vals <- v[match(years, as.integer(s$years))]
    vapply(vals, function(z) rep_fmt_value(z, u, 2), "")
  })
  m <- cbind(sprintf("%d", years), do.call(cbind, cols))
  colnames(m) <- c(lbl("report.html.table.year"), vapply(nms, kpi_label, "", USE.NAMES = FALSE))
  rep_html_pick_matrix(m)
}

#' Zeilen einer Jahrestabelle auswählen (Attribut `picked`, wenn gekürzt)
#' @noRd
rep_html_pick_matrix <- function(m) {
  idx <- rep_html_pick_rows(nrow(m))
  out <- m[idx, , drop = FALSE]
  attr(out, "picked") <- length(idx) < nrow(m)
  out
}

#' @noRd
rep_html_sec_kpis <- function(rc) {
  title <- rep_html_sec_title("kpis", rc)
  if (identical(rc$kind, "kurzvorlage")) return(rep_html_board_kpis(rc, title))
  blocks <- list(rep_html_b_par(lbl("report.html.kpis.intro")))
  if (!is.null(rc$cmp)) {
    # je Variante die Kennzahlen mit und ohne Restwert, je WE und je m2 (Basisfall); der
    # Vergleich der Varianten steht im Abschnitt Variantenvergleich
    if (rc$is_mc) blocks[[2L]] <- rep_html_b_par(lbl("report.html.kpis.cmp_mc_note"))
    for (v in rep_comparison_variants(rc$cmp)) {
      res <- rep_det_result(rc$cmp$results[[v]])
      blocks <- c(blocks, list(rep_html_var_heading(v)), rep_html_kpi_tables(res))
    }
    return(rep_html_section("kpis", title, blocks))
  }
  blocks <- c(blocks, rep_html_kpi_tables(rc$res))
  if (!is.null(rc$mc)) {
    blocks[[length(blocks) + 1L]] <- rep_html_b_table(rep_mc_stats_matrix(rc$mc),
                                                      caption = lbl("report.html.table.mc_header"))
  }
  st <- rep_html_series_table(rc$res)
  if (!is.null(st)) {
    cap <- lbl("report.html.kpis.series_header")
    blocks[[length(blocks) + 1L]] <- rep_html_b_table(st, caption = cap)
  }
  rep_html_section("kpis", title, blocks)
}

# ---------------------------------------------------------------------------------------------
# Abschnitt: Zeitverläufe
# ---------------------------------------------------------------------------------------------

#' @noRd
rep_html_sec_timeline <- function(rc) {
  title <- rep_html_sec_title("timeline", rc)
  if (!rc$plots) {
    return(rep_html_section("timeline", title, list(rep_html_b_par(lbl("report.html.no_ggplot")))))
  }
  if (!is.null(rc$cmp)) {
    cmp <- rc$cmp
    return(rep_html_section("timeline", title, list(
      rep_html_b_par(lbl("report.html.timeline.cmp_note")),
      rep_html_b_plot(function() vofi_plot(cmp, "bestand"), lbl("report.plot.title_cmp_bestand"))
    )))
  }
  res <- rc$res
  blocks <- list(rep_html_b_par(lbl("report.html.timeline.intro")))
  if (!is.null(rc$mc)) blocks[[2L]] <- rep_html_b_par(lbl("report.html.timeline.mc_note"))
  blocks <- c(blocks, list(
    rep_html_b_plot(function() vofi_plot(res, "vermoegen"), lbl("report.plot.title_vermoegen")),
    rep_html_b_plot(function() vofi_plot(res, "differenz"), lbl("report.plot.title_differenz")),
    rep_html_b_plot(function() vofi_plot(res, "zahlungen"), lbl("report.plot.title_zahlungen"))
  ))
  mc <- rc$mc
  if (!is.null(mc) && is.matrix(mc$bands$net_position)) {
    cap <- lbl("report.plot.title_fan", row = lbl("core.rows.net_position"))
    fun <- function() vofi_plot(mc, "fan", row_key = "net_position")
    blocks[[length(blocks) + 1L]] <- rep_html_b_plot(fun, cap)
  }
  rep_html_section("timeline", title, blocks)
}

# ---------------------------------------------------------------------------------------------
# Abschnitt: Finanzierung und Förderung (Fachmodus)
# ---------------------------------------------------------------------------------------------

#' Tabelle der Finanzierungsbausteine
#' @noRd
rep_html_instr_matrix <- function(ins) {
  if (is.null(ins) || nrow(ins) == 0L) return(NULL)
  f <- function(v) rep_fmt_value(v, "EUR", 0)
  m <- cbind(ins$label, f(ins$draw), f(ins$interest), f(ins$repay), f(ins$grant),
             f(ins$balance_end))
  m <- matrix(m, nrow = nrow(ins))
  colnames(m) <- c(lbl("report.html.financing.col_instrument"),
                   lbl("report.html.financing.col_draw"),
                   lbl("report.html.financing.col_interest"),
                   lbl("report.html.financing.col_repay"),
                   lbl("report.html.financing.col_grant"),
                   lbl("report.html.financing.col_balance_end"))
  m
}

#' Tabelle der Zuschüsse
#' @noRd
rep_html_grant_matrix <- function(g) {
  if (is.null(g) || nrow(g) == 0L) return(NULL)
  m <- cbind(g$label, g$program, rep_fmt_value(g$amount, "EUR", 0), g$years)
  m <- matrix(m, nrow = nrow(g))
  colnames(m) <- c(lbl("report.html.financing.col_grant_label"),
                   lbl("report.html.financing.col_program"),
                   lbl("report.html.financing.col_amount"), lbl("report.html.financing.col_years"))
  if (all(!nzchar(g$program))) m <- m[, -2L, drop = FALSE]
  m
}

# ---------------------------------------------------------------------------------------------
# Berechtigungs-Check der Foerderung (Konzept 5.5; Spec 01 Teil B 4.3.1; Memo 07 Paragraf 5.2 e)
# ---------------------------------------------------------------------------------------------

#' Bibliothekseintrag eines Förderinstruments (Herkunft der Werte `funding.<f>.*`)
#' @return Bibliotheks-id bzw. `NA`.
#' @noRd
rep_html_funding_entry <- function(spec, f) {
  prov <- tryCatch(as.data.frame(spec), error = function(e) NULL)
  if (!is.data.frame(prov) || !all(c("path", "entry") %in% names(prov))) return(NA_character_)
  e <- as.character(prov$entry[startsWith(as.character(prov$path), paste0("funding.", f, "."))])
  e <- unique(e[!is.na(e) & startsWith(e, "funding/")])
  if (length(e) == 0L) NA_character_ else e[1L]
}

#' Bezeichnung einer Berechtigungsbedingung (Labels des Expanders, sonst der Schlüssel)
#' @noRd
rep_html_condition_label <- function(key) {
  lbl(paste0("expand.funding.conditions.", key), .default = key)
}

#' Wert einer verletzten Bedingung als Text (Codes von Antragsteller und Projektart mit
#' Bezeichnung)
#' @noRd
rep_html_reason_value <- function(r) {
  v <- r$args$value
  if (is.null(v) || identical(v, "-") || length(v) == 0L) return("")
  enum <- switch(r$code, applicants = "applicant", project_types = "project_type", NULL)
  if (!is.null(enum)) return(rep_enum_label(enum, as.character(v)[1L]))
  if (is.numeric(v)) return(fmt_num(v[1L], if (abs(v[1L] - round(v[1L])) < 1e-9) 0 else 2))
  utl_collapse(format(v))
}

#' Berechtigungs-Check eines Förderinstruments
#'
#' Wertet die automatisch prüfbaren Bedingungen deterministisch zum Antragsdatum aus wie der
#' Expander (`fund_check_eligibility()`, WS-E2) und ergänzt Antragsdatum, Zeitpunkt der Zusage,
#' die Bedingung „Antrag vor Vorhabenbeginn“, Fristen (Fertigstellung) und die Gültigkeit des
#' Bibliothekseintrags zum Antragsdatum. Ausschlüsse (`exclusions`) und nicht prüfbare
#' Bedingungen erscheinen als offene Prüfpunkte.
#' @param res `vofi_result`.
#' @param f id des Instruments.
#' @return Liste `id`, `title`, `eligible`, `status` (Text), `items` (Data Frame `check`,
#'   `result`, `detail`, `state` mit `ok`, `violated`, `open`, `info`), `open` (Texte),
#'   `application` (Text) bzw. `NULL`.
#' @noRd
rep_html_funding_check <- function(res, f) {
  spec <- res$spec
  fs <- spec$funding[[f]]
  if (!is.list(fs)) return(NULL)
  bctx <- list(value_base = function(path, ...) scn_value_base(spec, res$grid, path, "scalar"))
  chk <- fund_check_eligibility(spec, f, fs, bctx)
  el <- fs[["eligibility"]] %||% list()
  # Pruefpunkte in einer lokalen Umgebung sammeln (keine Zuweisung nach aussen, 2.7)
  acc <- new.env(parent = emptyenv())
  acc$items <- list()
  add <- function(check, state, detail = "") {
    result <- lbl(paste0("report.html.funding_check.state_", state))
    acc$items[[length(acc$items) + 1L]] <- data.frame(check = check, result = result,
                                                      detail = detail, state = state,
                                                      stringsAsFactors = FALSE)
  }
  r_codes <- vapply(chk$reasons, function(r) r$code, "")
  r_value <- function(code) {
    i <- match(code, r_codes)
    if (is.na(i)) return("")
    rep_html_reason_value(chk$reasons[[i]])
  }
  o_codes <- vapply(chk$open, function(o) o$code, "")
  state_of <- function(code) {
    if (code %in% r_codes) "violated" else if (code %in% o_codes) "open" else "ok"
  }
  if (length(exp_chr(el[["applicants"]])) > 0L) {
    a <- fund_applicant(spec, fs)
    add(rep_html_condition_label("applicants"), state_of("applicants"),
        rep_enum_label("applicant", a))
  }
  if (length(exp_chr(el[["project_types"]])) > 0L) {
    add(rep_html_condition_label("project_types"), state_of("project_types"),
        rep_enum_label("project_type", spec$project$project_type))
  }
  if (length(exp_chr(el[["measure_types"]])) > 0L) {
    bad <- vapply(chk$errors, function(e) paste0(e$measure, " (", e$measure_type, ")"), "")
    add(lbl("report.html.funding_check.measure_types"),
        if (length(bad) > 0L) "violated" else "ok", utl_collapse(bad))
  }
  cond <- el[["conditions"]] %||% list()
  for (key in names(cond)) {
    v <- cond[[key]]
    if (is.null(v)) next
    if (identical(key, "completion_before")) {
      d <- exp_date(v)
      add(lbl("report.html.funding_check.completion_before"), "info",
          lbl("report.html.funding_check.per_run", date = if (is.null(d)) fmt_num(NA) else d))
      next
    }
    if (identical(key, "requires_beg_em_commitment_months")) {
      add(lbl("report.html.funding_check.requires_commitment",
              months = as.integer(exp_num(v) %||% NA_real_)), "info",
          lbl("report.html.funding_check.see_validation"))
      next
    }
    code <- if (identical(key, "efficiency_standard") &&
                  "efficiency_standard_missing" %in% r_codes) {
      "efficiency_standard_missing"
    } else {
      key
    }
    add(rep_html_condition_label(code), state_of(code), r_value(code))
  }
  open_txt <- character(0)
  for (o in chk$open) {
    if (identical(o$code, "exclusion")) {
      txt <- as.character(o$args$text %||% "")
      add(lbl("report.html.funding_check.exclusion"), "open", txt)
      open_txt <- c(open_txt, lbl("report.html.funding_check.exclusion_text", text = txt))
    } else if (!(o$code %in% names(cond))) {
      add(rep_html_condition_label(o$code), "open")
      open_txt <- c(open_txt, rep_html_condition_label(o$code))
    } else {
      open_txt <- c(open_txt, rep_html_condition_label(o$code))
    }
  }
  # Antragsdatum, Zusage, Antrag vor Vorhabenbeginn, Gueltigkeit des Programms
  ad <- tryCatch(fund_application_date(spec, fs), error = function(e) NULL)
  timing <- exp_code(fs[["approval_timing"]]) %||% "auto"
  app_txt <- if (is.null(ad)) "" else
    lbl("report.html.funding_check.application", date = ad,
        timing = rep_enum_label("approval_timing", timing))
  add(lbl("report.html.funding_check.application_date"), "info", app_txt)
  if (isTRUE(exp_lgl(fs[["application_before_start"]]))) {
    add(lbl("report.html.funding_check.before_start"),
        if (identical(timing, "after_start")) "violated" else "ok",
        rep_enum_label("approval_timing", timing))
  }
  entry <- rep_html_funding_entry(spec, f)
  lib <- res$meta$library %||% spec$library
  if (!is.na(entry) && is.data.frame(lib) && entry %in% lib$entry && !is.null(ad)) {
    r <- lib[lib$entry == entry, , drop = FALSE][1L, , drop = FALSE]
    vf <- as.Date(r$valid_from)
    vt <- as.Date(r$valid_to)
    ok <- (is.na(vf) || vf <= ad) && (is.na(vt) || ad < vt)
    add(lbl("report.html.funding_check.validity", entry = entry), if (ok) "ok" else "violated",
        lbl("report.html.funding_check.validity_range", from = fmt_date(vf),
            to = if (is.na(vt)) "\u2013" else fmt_date(vt)))
  }
  if (isTRUE(chk$override)) {
    add(lbl("report.html.funding_check.override"), "info")
  }
  items <- if (length(acc$items) > 0L) do.call(rbind, acc$items) else NULL
  type <- exp_code(fs[["instrument_type"]])
  prog <- trimws(paste(as.character(exp_code(fs[["provider"]]) %||% ""),
                       as.character(fs[["program_code"]] %||% "")))
  title <- lbl("report.html.funding_check.title", id = f,
               details = utl_collapse(c(if (nzchar(prog)) prog,
                                        if (!is.null(type)) rep_enum_label("instrument_type",
                                                                           type)), ", "))
  reasons <- vapply(seq_along(chk$reasons), function(i) {
    r <- chk$reasons[[i]]
    v <- rep_html_reason_value(r)
    lab <- rep_html_condition_label(r$code)
    if (!nzchar(v)) lab else paste0(lab, ": ", v)
  }, "")
  bad_measures <- vapply(chk$errors, function(e) e$measure, "")
  status <- if (length(chk$errors) > 0L) {
    lbl("report.html.funding_check.status_measure", measures = utl_collapse(bad_measures))
  } else if (!isTRUE(chk$eligible)) {
    lbl("report.html.funding_check.status_not_eligible", reasons = utl_collapse(reasons, "; "))
  } else if (isTRUE(chk$override)) {
    lbl("report.html.funding_check.status_override")
  } else if (length(open_txt) > 0L) {
    lbl("report.html.funding_check.status_open", n = length(unique(open_txt)))
  } else {
    lbl("report.html.funding_check.status_eligible")
  }
  list(id = f, title = title, eligible = isTRUE(chk$eligible) && length(chk$errors) == 0L,
       status = status, items = items, open = unique(open_txt), application = app_txt)
}

#' Berechtigungs-Check aller Förderinstrumente eines Ergebnisses
#' @return Liste der Ergebnisse von `rep_html_funding_check()` (leer ohne Förderinstrumente).
#' @noRd
rep_html_funding_checks <- function(res) {
  fund <- res$spec$funding
  if (!is.list(fund) || length(fund) == 0L) return(list())
  out <- lapply(names(fund), function(f) {
    tryCatch(rep_html_funding_check(res, f), error = function(e) {
      vofi_warn("report.html.funding_check.failed", id = f, message = conditionMessage(e))
      list(id = f, title = f, eligible = NA,
           status = lbl("report.html.funding_check.failed", id = f,
                        message = conditionMessage(e)),
           items = NULL, open = character(0), application = "")
    })
  })
  out[!vapply(out, is.null, logical(1))]
}

#' Blöcke des Berechtigungs-Checks (Fachmodus: Status und Tabelle je Instrument)
#' @noRd
rep_html_funding_check_blocks <- function(res, level = 2L) {
  checks <- rep_html_funding_checks(res)
  if (length(checks) == 0L) return(list())
  blocks <- list(rep_html_b_heading(lbl("report.html.funding_check.header"), level),
                 rep_html_b_par(lbl("report.html.funding_check.intro")))
  for (ck in checks) {
    blocks[[length(blocks) + 1L]] <- rep_html_b_par(lbl("report.html.funding_check.line",
                                                        title = ck$title, status = ck$status))
    it <- ck$items
    if (is.data.frame(it) && nrow(it) > 0L) {
      m <- matrix(c(it$check, it$result, it$detail), ncol = 3L)
      colnames(m) <- c(lbl("report.html.funding_check.col_check"),
                       lbl("report.html.funding_check.col_result"),
                       lbl("report.html.funding_check.col_detail"))
      blocks[[length(blocks) + 1L]] <- rep_html_b_table(m, align = c("l", "l", "l"))
    }
  }
  blocks
}

#' Berechtigungs-Check in einfachen Worten (Haushaltsmodus)
#' @return Zeichenvektor (Aufzählungspunkte).
#' @noRd
rep_html_funding_check_items <- function(res) {
  out <- character(0)
  for (ck in rep_html_funding_checks(res)) {
    out <- c(out, lbl("report.html.funding_check.household_line", title = ck$title,
                      status = ck$status))
    if (length(ck$open) > 0L) {
      out <- c(out, lbl("report.html.funding_check.household_open", title = ck$title,
                        items = utl_collapse(ck$open, "; ")))
    }
    if (nzchar(ck$application)) {
      out <- c(out, lbl("report.html.funding_check.household_application", title = ck$title,
                        text = ck$application))
    }
  }
  out
}

#' Berechtigungs-Check als kompakte Tabelle (Kurzvorlage)
#' @noRd
rep_html_funding_check_matrix <- function(res) {
  checks <- rep_html_funding_checks(res)
  if (length(checks) == 0L) return(NULL)
  m <- do.call(rbind, lapply(checks, function(ck) {
    c(ck$title, ck$status, if (length(ck$open) > 0L) utl_collapse(ck$open, "; ") else "\u2013",
      ck$application)
  }))
  m <- matrix(m, nrow = length(checks))
  colnames(m) <- c(lbl("report.html.funding_check.col_funding"),
                   lbl("report.html.funding_check.col_result"),
                   lbl("report.html.funding_check.col_open"),
                   lbl("report.html.funding_check.col_application"))
  m
}

#' Finanzierungsteil eines Einzelergebnisses
#' @noRd
rep_html_financing_blocks <- function(res, plots = TRUE, level = 2L) {
  ins <- rep_html_instruments(res)
  eq <- sum(rep_html_cat_values(res, "equity", "equity_in"))
  calls <- sum(rep_html_cat_values(res, "equity", c("equity_call", "shortfall")))
  blocks <- list(
    rep_html_b_heading(lbl("report.html.financing.instruments_header"), level),
    if (is.null(ins)) rep_html_b_par(lbl("report.html.financing.no_instruments")) else
      rep_html_b_table(rep_html_instr_matrix(ins)),
    rep_html_b_par(c(lbl("report.html.financing.equity", value = rep_fmt_value(eq, "EUR", 0)),
                     lbl("report.html.financing.equity_calls",
                         value = rep_fmt_value(calls, "EUR", 0))))
  )
  if (plots) {
    blocks <- c(blocks, list(
      rep_html_b_plot(function() vofi_plot(res, "finanzierung"),
                      lbl("report.plot.title_finanzierung")),
      rep_html_b_plot(function() vofi_plot(res, "bestand"), lbl("report.plot.title_bestand"))
    ))
  }
  g <- rep_html_grants(res)
  blocks <- c(blocks, list(rep_html_b_heading(lbl("report.html.financing.grants_header"), level),
                           if (is.null(g)) rep_html_b_par(lbl("report.html.financing.no_grants"))
                           else rep_html_b_table(rep_html_grant_matrix(g))),
              rep_html_try(rep_html_funding_check_blocks(res, level),
                           lbl("report.html.funding_check.header")))
  pv <- rep_html_kn(res, "pv_subsidies")
  if (!is.na(pv)) {
    blocks[[length(blocks) + 1L]] <- rep_html_b_par(lbl("report.html.financing.pv_subsidies",
                                                        value = rep_html_kv(res, "pv_subsidies")))
  }
  cov <- c("dscr_min", "dscr_mean", "dscr_years_below", "dscr_min_new", "icr_min", "ltv_max",
           "ltv_end", "lending_ratio_max")
  cov <- cov[cov %in% names(res$kpis)]
  if (length(cov) > 0L) {
    thr <- rep_spec_number(res$spec, "analysis.thresholds.dscr")
    blocks <- c(blocks, list(
      rep_html_b_heading(lbl("report.html.financing.coverage_header"), level),
      rep_html_b_par(c(lbl("report.html.financing.coverage_intro"),
                       if (!is.null(thr)) lbl("report.html.financing.threshold",
                                              value = fmt_num(thr, 2)))),
      rep_html_b_table(rep_html_kpi_pairs(res, cov))
    ))
    st <- rep_html_series_table(res, c("dscr", "icr", "ltv", "lending_ratio"))
    if (!is.null(st)) {
      cap <- lbl("report.html.financing.series_header")
      blocks[[length(blocks) + 1L]] <- rep_html_b_table(st, caption = cap)
    }
  }
  blocks
}

#' @noRd
rep_html_sec_financing <- function(rc) {
  title <- rep_html_sec_title("financing", rc)
  if (is.null(rc$cmp)) {
    return(rep_html_section("financing", title, rep_html_financing_blocks(rc$res, rc$plots)))
  }
  blocks <- list()
  for (v in rep_comparison_variants(rc$cmp)) {
    res <- rep_det_result(rc$cmp$results[[v]])
    blocks <- c(blocks, list(rep_html_var_heading(v)),
                rep_html_financing_blocks(res, plots = FALSE, level = 3L))
  }
  rep_html_section("financing", title, blocks)
}

# ---------------------------------------------------------------------------------------------
# Abschnitt: Mietersicht (Warmmiete)
# ---------------------------------------------------------------------------------------------

#' @noRd
rep_html_sec_tenant <- function(rc) {
  title <- rep_html_sec_title("tenant", rc)
  tv <- vofi_tenant_view(rc$x)
  has <- is.data.frame(tv) && nrow(tv) > 0L && any(!is.na(tv$warm_rent))
  if (!has) {
    levy <- rep_html_try(rep_html_levy_blocks(rc), lbl("report.html.levy.header"))
    if (!startsWith(rc$perspective, "wu_") && length(levy) == 0L) return(NULL)
    return(rep_html_section("tenant", title,
                            c(list(rep_html_b_par(lbl("report.html.tenant.none"))), levy)))
  }
  f <- function(v) fmt_num(v, 2)
  multi <- length(unique(tv$variant)) > 1L
  idx <- unlist(lapply(split(seq_len(nrow(tv)), factor(tv$variant, levels = unique(tv$variant))),
                       function(ii) ii[rep_html_pick_rows(length(ii))]), use.names = FALSE)
  d <- tv[idx, , drop = FALSE]
  m <- cbind(sprintf("%d", as.integer(d$year)), f(d$rent), f(d$levy), f(d$operating),
             f(d$energy), f(d$warm_rent), f(d$warm_rent_pre), f(d$change_prepost))
  cn <- c(lbl("report.html.table.year"), lbl("report.html.tenant.col_rent"),
          lbl("report.html.tenant.col_levy"), lbl("report.html.tenant.col_operating"),
          lbl("report.html.tenant.col_energy"), lbl("report.html.tenant.col_warm"),
          lbl("report.html.tenant.col_warm_pre"), lbl("report.html.tenant.col_change"))
  if ("change_vs_reference" %in% names(d)) {
    m <- cbind(m, f(d$change_vs_reference))
    cn <- c(cn, lbl("report.html.tenant.col_change_ref"))
  }
  m <- matrix(m, nrow = nrow(d))
  colnames(m) <- cn
  if (multi) {
    m <- cbind(d$variant, m)
    colnames(m)[1L] <- lbl("report.html.table.variant")
  }
  attr(m, "picked") <- length(idx) < nrow(tv)
  blocks <- list(rep_html_b_par(lbl("report.html.tenant.intro")),
                 rep_html_b_table(m, caption = lbl("report.plot.y_eur_m2_month")))
  thr <- rep_spec_number(rc$res$spec, "analysis.thresholds.warm_rent_increase_eur_m2")
  if (!is.null(thr)) {
    blocks[[length(blocks) + 1L]] <- rep_html_b_par(lbl("report.html.tenant.threshold",
                                                        value = fmt_eur(thr, 2)))
  }
  if ("coop_warning" %in% names(tv) && any(tv$coop_warning %in% TRUE)) {
    i <- which(tv$coop_warning %in% TRUE)[1L]
    txt <- lbl("report.html.tenant.coop_warning", year = as.integer(tv$year[i]),
               share = tv$coop_income_share[i], threshold = tv$coop_threshold[i])
    blocks[[length(blocks) + 1L]] <- rep_html_b_callout("warning", txt)
  }
  blocks <- c(blocks, rep_html_try(rep_html_levy_blocks(rc), lbl("report.html.levy.header")))
  if (rc$plots) {
    x <- rc$x
    blocks[[length(blocks) + 1L]] <- rep_html_b_plot(function() rep_plot_warm_rent(x),
                                                     lbl("report.plot.title_warmmiete"))
  }
  rep_html_section("tenant", title, blocks)
}

# ---------------------------------------------------------------------------------------------
# Umlage: Rechenweg rechnerisch -> gekappt -> angesetzt (Spec 01 Teil B 1.9.6; Memo 07
# Paragraf 5.1 Nr. 5 und 5.2 a, c)
# ---------------------------------------------------------------------------------------------

#' Basisfallwert eines Spezifikationspfads (Konstante bzw. über den Auflöser) oder `NULL`
#' @noRd
rep_html_spec_value <- function(spec, grid, path) {
  v <- rep_spec_number(spec, path)
  if (!is.null(v)) return(v[1L])
  out <- tryCatch(suppressWarnings(suppressMessages(scn_value_base(spec, grid, path, "scalar"))),
                  error = function(e) NULL)
  if (is.numeric(out) && length(out) >= 1L && !is.na(out[1L])) as.double(out[1L]) else NULL
}

#' Mietpfad-Komponenten mit Umlagezeilen (`rent_path` mit `levy_rows`)
#' @noRd
rep_html_levy_components <- function(spec) {
  comps <- spec$components %||% list()
  if (length(comps) == 0L) return(character(0))
  names(comps)[vapply(comps, function(cmp) {
    is.list(cmp) && identical(exp_code(cmp[["type"]]), "rent_path") &&
      length(exp_chr(cmp[["levy_rows"]])) > 0L
  }, logical(1))]
}

#' Rückgaben der Komponenten im Basisfall (mit Hilfsgrößen `aux`)
#'
#' Simulation: aus dem gespeicherten Modell; Einzelergebnis: Modell aus der Spezifikation neu
#' gebaut (ohne neue Auflösung; Meldungen des Baus sind bekannt und werden unterdrückt).
#' @return Liste `flows` (benannt nach Komponente) und `grid`.
#' @noRd
rep_html_component_flows <- function(x) {
  res <- rep_det_result(x)
  model <- if (inherits(x, "vofi_mc_result") && inherits(x$model, "vofi_model")) x$model else
    NULL
  if (is.null(model) || is.null(model$base$flows)) {
    model <- withCallingHandlers(vofi_build(res$spec),
                                 vofi_message = function(m) invokeRestart("muffleMessage"),
                                 vofi_warning = function(w) invokeRestart("muffleWarning"))
  }
  list(flows = model$base$flows, grid = model$grid %||% res$grid)
}

#' Rechenweg der Modernisierungsumlage je Maßnahme und Wohnungsgruppe (Basisfall)
#'
#' Aus den Hilfsgrößen des Mietpfads: rechnerischer Jahresbetrag (`levy_<k>_computed`), nach
#' Kappung (`levy_<k>_capped`), angesetzt nach freiwilliger Obergrenze und vor Härtefällen
#' (`levy_<k>_charged`), jeweils in der Wirksamkeitsperiode, mit Verfahren
#' (`levy_<k>_procedure`); je m² Wohnfläche und Monat sowie je Wohnung und Monat.
#' @param x `vofi_result` bzw. `vofi_mc_result`.
#' @return Data Frame `measure`, `group`, `period`, `procedure`, `computed`, `capped`,
#'   `charged` (EUR/Jahr), `area`, `n_units` bzw. `NULL` (keine Umlage).
#' @noRd
rep_html_levy_chain <- function(x) {
  res <- rep_det_result(x)
  spec <- res$spec
  ids <- rep_html_levy_components(spec)
  if (length(ids) == 0L) return(NULL)
  fl <- rep_html_component_flows(x)
  codes <- c("none", "bgb_559", "bgb_559c", "bgb_559e")
  rows <- list()
  for (id in ids) {
    aux <- fl$flows[[id]]$aux
    if (is.null(aux)) next
    comp <- spec$components[[id]]
    group <- as.character(exp_code(comp[["unit_group"]]) %||% id)
    area_m <- aux$area_m2
    area <- if (is.matrix(area_m)) max(area_m[1L, ], na.rm = TRUE) else NA_real_
    n_units <- rep_html_spec_value(spec, fl$grid, paste0("components.", id, ".n_units")) %||%
      rep_html_spec_value(spec, fl$grid, paste0("unit_groups.", group, ".n_units")) %||%
      NA_real_
    for (k in exp_chr(comp[["levy_rows"]])) {
      get_row <- function(fld) {
        m <- aux[[paste0("levy_", k, "_", fld)]]
        if (is.matrix(m)) as.double(m[1L, ]) else NULL
      }
      cp <- get_row("computed")
      cap <- get_row("capped")
      chg <- get_row("charged")
      pr <- get_row("procedure")
      if (is.null(cp) || is.null(cap) || is.null(chg)) next
      hit <- which(abs(cp) > vofi_tol$zero_abs | abs(cap) > vofi_tol$zero_abs |
                     abs(chg) > vofi_tol$zero_abs)
      j <- if (length(hit) > 0L) hit[1L] else NA_integer_
      pc <- if (is.na(j) || is.null(pr)) 0L else as.integer(round(pr[j]))
      code <- codes[min(max(pc, 0L), 3L) + 1L]
      lab <- spec$measures[[k]]$label %||% k
      at <- function(v) if (is.na(j)) 0 else v[j]
      period <- if (is.na(j)) NA_character_ else as.character(fl$grid$label[j])
      rows[[length(rows) + 1L]] <- data.frame(measure = as.character(lab)[1L], group = group,
                                              period = period, procedure = code,
                                              computed = at(cp), capped = at(cap),
                                              charged = at(chg), area = area,
                                              n_units = as.double(n_units),
                                              stringsAsFactors = FALSE)
    }
  }
  if (length(rows) == 0L) return(NULL)
  do.call(rbind, rows)
}

#' Rechenweg der Umlage als Zeichenmatrix (Fachmodus)
#' @noRd
rep_html_levy_matrix <- function(lc) {
  if (!is.data.frame(lc) || nrow(lc) == 0L) return(NULL)
  cell <- function(v, area) {
    m2 <- ifelse(is.finite(area) & area > 0, v / (12 * area), NA_real_)
    vapply(seq_along(v), function(i) {
      lbl("report.html.levy.cell", value = rep_fmt_value(v[i], "EUR", 2),
          per_m2 = fmt_num(m2[i], 2))
    }, "")
  }
  proc <- vapply(lc$procedure, function(p) {
    if (identical(p, "none")) lbl("report.html.levy.procedure_none") else
      rep_enum_label("levy_procedure", p)
  }, "", USE.NAMES = FALSE)
  m <- cbind(lc$measure, lc$group, ifelse(is.na(lc$period), "\u2013", lc$period), proc,
             cell(lc$computed, lc$area), cell(lc$capped, lc$area), cell(lc$charged, lc$area))
  m <- matrix(m, nrow = nrow(lc))
  colnames(m) <- c(lbl("report.html.levy.col_measure"), lbl("report.html.levy.col_group"),
                   lbl("report.html.levy.col_period"), lbl("report.html.levy.col_procedure"),
                   lbl("report.html.levy.col_computed"), lbl("report.html.levy.col_capped"),
                   lbl("report.html.levy.col_charged"))
  m
}

#' Blöcke des Rechenwegs der Umlage (Fachmodus; bei Vergleichen je Variante)
#' @noRd
rep_html_levy_blocks <- function(rc) {
  results <- if (is.null(rc$cmp)) list(rc$base) else
    rc$cmp$results[rep_comparison_variants(rc$cmp)]
  multi <- length(results) > 1L
  blocks <- list()
  for (v in seq_along(results)) {
    m <- rep_html_levy_matrix(rep_html_levy_chain(results[[v]]))
    if (is.null(m)) next
    cap <- if (multi) {
      lbl("report.html.vofi_table.variant_header", variant = names(results)[v])
    } else {
      NULL
    }
    blocks[[length(blocks) + 1L]] <- rep_html_b_table(m, caption = cap)
  }
  if (length(blocks) == 0L) return(list())
  c(list(rep_html_b_heading(lbl("report.html.levy.header")),
         rep_html_b_par(lbl("report.html.levy.intro"))), blocks)
}

#' Zulässige Mieterhöhung durch Modernisierung je Wohnung (Haushaltsmodus, Kleinvermieter)
#' @return Zeichenvektor (Aufzählungspunkte).
#' @noRd
rep_html_levy_household <- function(x) {
  lc <- rep_html_levy_chain(x)
  if (!is.data.frame(lc) || nrow(lc) == 0L) return(character(0))
  vapply(seq_len(nrow(lc)), function(i) {
    r <- lc[i, , drop = FALSE]
    if (is.na(r$period)) {
      return(lbl("report.html.levy.household_none", measure = r$measure))
    }
    per_unit <- function(v) {
      if (!is.finite(r$n_units) || r$n_units <= 0) return(fmt_num(NA))
      rep_amount_text(v / (12 * r$n_units))
    }
    lbl("report.html.levy.household_item", measure = r$measure, period = r$period,
        allowed = per_unit(r$capped), charged = per_unit(r$charged))
  }, "")
}

# ---------------------------------------------------------------------------------------------
# Abschnitt: Energie und CO2
# ---------------------------------------------------------------------------------------------

#' @noRd
rep_html_sec_energy <- function(rc) {
  title <- rep_html_sec_title("energy", rc)
  res <- rc$res
  cats <- c("energy_cost", "co2_cost", "energy_income", "energy_saving")
  oy <- kpi_op_years(res$grid)
  full <- which(oy$full)
  y1 <- if (length(full) > 0L) oy$cols[[full[1L]]] else integer(0)
  rows <- list()
  for (cc in cats) {
    v <- rep_html_cat_values(res, "project", cc)
    if (all(abs(v) <= vofi_tol$zero_abs)) next
    rows[[length(rows) + 1L]] <- c(lbl(paste0("vocab.categories.project.", cc), .default = cc),
                                   if (length(y1) > 0L) rep_fmt_value(sum(v[y1]), "EUR", 0) else
                                     fmt_num(NA),
                                   rep_fmt_value(sum(v), "EUR", 0))
  }
  kp <- c("co2_emissions", "co2_emissions_ex_rv")
  kp <- kp[kp %in% names(res$kpis)]
  cmp_rows <- NULL
  if (!is.null(rc$cmp)) {
    d <- rc$cmp$differences %||% list()
    ck <- intersect(c("co2_reduction", "co2_abatement_cost"), names(d))
    if (length(ck) > 0L) {
      cmp_rows <- do.call(rbind, lapply(ck, function(k) {
        m <- d[[k]]
        vapply(seq_len(ncol(m)), function(j) {
          rep_fmt_value(mean(m[, j], na.rm = TRUE), rep_html_unit(k), 0)
        }, "")
      }))
      cmp_rows <- cbind(vapply(ck, kpi_label, "", USE.NAMES = FALSE),
                        matrix(cmp_rows, nrow = length(ck)))
      colnames(cmp_rows) <- c(lbl("report.html.table.kpi"),
                              colnames(d[[ck[1L]]]) %||% rc$cmp$variants)
    }
  }
  if (length(rows) == 0L && length(kp) == 0L && is.null(cmp_rows)) return(NULL)
  blocks <- list(rep_html_b_par(lbl("report.html.energy.intro")))
  if (length(rows) > 0L) {
    m <- do.call(rbind, rows)
    colnames(m) <- c(lbl("report.html.energy.col_category"),
                     lbl("report.html.energy.col_first_year"), lbl("report.html.energy.col_total"))
    blocks[[length(blocks) + 1L]] <- rep_html_b_table(m)
  } else {
    blocks[[length(blocks) + 1L]] <- rep_html_b_par(lbl("report.html.energy.none"))
  }
  if (length(kp) > 0L) {
    blocks[[length(blocks) + 1L]] <- rep_html_b_table(rep_html_kpi_pairs(res, kp))
  }
  if (!is.null(cmp_rows)) blocks[[length(blocks) + 1L]] <- rep_html_b_table(cmp_rows)
  rep_html_section("energy", title, blocks)
}

# ---------------------------------------------------------------------------------------------
# Abschnitt: Risiko
# ---------------------------------------------------------------------------------------------

#' Gespeicherte Läufe einer Simulation als Szenariotabelle (Basisfall, P5, P50, P95)
#' @noRd
rep_html_runs_matrix <- function(mc) {
  pk <- rep_mc_primary(mc)$kpi
  keys <- unique(c(pk, paste0(pk, "_ex_rv"), "terminal_value"))
  runs <- c(deterministic = "deterministic", p05 = "p05", p50 = "p50", p95 = "p95")
  rows <- list()
  for (nm in names(runs)) {
    r <- if (identical(nm, "deterministic")) mc$deterministic else mc$runs[[nm]]
    if (!inherits(r, "vofi_result")) next
    idx <- rep_mc_run_index(mc, nm)
    run <- lbl(paste0("report.html.risk.run_", if (nm == "deterministic") "det" else nm))
    rows[[length(rows) + 1L]] <- c(run, if (is.na(idx)) "" else sprintf("%d", idx),
                                   vapply(keys, function(k) rep_html_kv(r, k), "",
                                          USE.NAMES = FALSE))
  }
  if (length(rows) == 0L) return(NULL)
  m <- do.call(rbind, rows)
  colnames(m) <- c(lbl("report.html.risk.col_run"), lbl("report.html.risk.col_sim"),
                   vapply(keys, kpi_label, "", USE.NAMES = FALSE))
  m
}

#' Risikoteil einer Simulation (Fachmodus)
#' @noRd
rep_html_risk_mc_blocks <- function(mc, plots) {
  m <- mc$meta
  blocks <- list(
    rep_html_b_par(lbl("report.html.risk.settings", n = as.integer(m$n_sim %||% nrow(mc$kpis)),
                       seed = format(m$seed %||% NA), sampling = m$sampling %||% "",
                       r = as.integer(m$replicates %||% 1L),
                       block = as.integer(m$block_size %||% NA_integer_))),
    rep_html_b_table(rep_mc_stats_matrix(mc, rep_mc_head_kpis(mc)),
                     caption = lbl("report.html.risk.stats_header")),
    rep_html_b_heading(lbl("report.html.risk.words_header")),
    rep_html_b_list(c(rep_mc_risk_lines(mc), rep_mc_se_notes(mc))),
    rep_html_b_callout("info", lbl("report.html.risk.det_note"))
  )
  dec <- mc$decision
  if (!is.null(dec)) {
    pk <- rep_mc_primary(mc)$kpi
    pick <- function(s) if (is.data.frame(s)) s[s$kpi %in% pk, , drop = FALSE] else NULL
    d <- rep_mc_decision(dec, pick)
    lines <- lbl("report.mc.decision_share", p = d$p_approval %||% NA_real_,
                 share = d$share_approved %||% NA_real_)
    for (nm in c("approved", "fallback")) {
      s <- d[[nm]]
      if (is.data.frame(s) && nrow(s) > 0L) {
        lines <- c(lines, lbl(paste0("report.mc.decision_", nm),
                              mean = rep_fmt_value(s$mean[1L], "EUR", 0),
                              q05 = rep_fmt_value(s$q05[1L], "EUR", 0),
                              q95 = rep_fmt_value(s$q95[1L], "EUR", 0)))
      }
    }
    blocks <- c(blocks, list(rep_html_b_heading(lbl("report.html.risk.decision_header",
                                                    funding = d$funding_id %||% "",
                                                    fallback = d$fallback_variant %||% "")),
                             rep_html_b_list(lines)))
  }
  runs <- rep_html_runs_matrix(mc)
  if (!is.null(runs)) {
    blocks <- c(blocks, list(rep_html_b_table(runs, caption = lbl("report.html.risk.runs_header"))))
  }
  if (plots) {
    pk <- rep_mc_primary(mc)$kpi
    blocks <- c(blocks, list(
      rep_html_b_plot(function() vofi_plot(mc, "verteilung"),
                      lbl("report.plot.title_verteilung", kpi = kpi_label(pk))),
      rep_html_b_plot(function() vofi_plot(mc, "cdf"),
                      lbl("report.plot.title_cdf", kpi = kpi_label(pk))),
      rep_html_b_plot(function() vofi_plot(mc, "konvergenz"),
                      lbl("report.plot.title_konvergenz", kpi = kpi_label(pk)))
    ))
    if (!is.null(rep_mc_inputs(mc))) {
      cap <- lbl("report.plot.title_rank_tornado", kpi = kpi_label(pk))
      blocks[[length(blocks) + 1L]] <- rep_html_b_plot(function() vofi_plot(mc, "tornado"), cap)
    }
  }
  blocks
}

#' @noRd
rep_html_sec_risk <- function(rc) {
  title <- rep_html_sec_title("risk", rc)
  if (rc$household) return(rep_html_section("risk", title, rep_html_risk_household(rc)))
  if (!rc$is_mc) {
    return(rep_html_section("risk", title, list(rep_html_b_callout("info",
                                                                   lbl("report.html.risk.no_mc")))))
  }
  if (!is.null(rc$cmp)) {
    cmp <- rc$cmp
    blocks <- list(rep_html_b_table(rep_cmp_diff_matrix(cmp),
                                    caption = lbl("report.html.variants.diff_header")))
    if (rc$plots) {
      blocks[[2L]] <- rep_html_b_plot(function() vofi_plot(cmp, "cdf"),
                                      lbl("report.plot.title_cdf",
                                          kpi = kpi_label("delta_vs_reference")))
    }
    for (v in rep_comparison_variants(cmp)) {
      r <- cmp$results[[v]]
      if (!inherits(r, "vofi_mc_result")) next
      blocks <- c(blocks, list(rep_html_var_heading(v),
                               rep_html_b_table(rep_mc_stats_matrix(r, rep_mc_head_kpis(r))),
                               rep_html_b_list(rep_mc_risk_lines(r))))
    }
    blocks[[length(blocks) + 1L]] <- rep_html_b_callout("info", lbl("report.html.risk.det_note"))
    return(rep_html_section("risk", title, blocks))
  }
  rep_html_section("risk", title, rep_html_risk_mc_blocks(rc$mc, rc$plots))
}

#' „Was passiert, wenn …“ aus den Pflichtsensitivitäten (Haushaltsmodus)
#' @noRd
rep_html_what_if <- function(rc) {
  ms <- rep_html_mandatory(rc)
  if (!is.data.frame(ms) || nrow(ms) == 0L) return(character(0))
  ms <- ms[ms$status %in% c("computed", "no_effect", "same_as_base"), , drop = FALSE]
  multi <- "variant" %in% names(ms) && length(unique(ms$variant)) > 1L
  vapply(seq_len(nrow(ms)), function(i) {
    d <- ms$diff[i]
    r <- rep_round_household(d, "sum")
    key <- if (is.na(d) || r == 0) "same" else if (r > 0) "better" else "worse"
    txt <- lbl(paste0("report.html.household.what_if_", key), value = fmt_int(abs(r)))
    item <- lbl("report.html.household.what_if_item", label = ms$label[i], text = txt)
    if (multi) item <- lbl("report.html.variants.household_text", variant = ms$variant[i],
                           text = item)
    item
  }, "")
}

#' Risiko in einfachen Worten (Haushaltsmodus)
#' @noRd
rep_html_risk_household <- function(rc) {
  blocks <- list()
  if (rc$is_mc) {
    s <- rep_html_hh_summary(rc)$summary
    rng <- if (nrow(s) > 0L) s[s$item == "range", , drop = FALSE] else s
    multi <- length(unique(rng$variant)) > 1L
    rng <- if (nrow(rng) == 0L) character(0) else if (multi) {
      vapply(seq_len(nrow(rng)), function(i) {
        lbl("report.html.variants.household_text", variant = rep_vlabel(rng$variant[i], TRUE),
            text = rng$text[i])
      }, "")
    } else {
      rng$text
    }
    blocks <- list(rep_html_b_list(c(rep_html_hh_risk_lines(rc), rng)),
                   rep_html_b_par(rep_html_drivers_text(rc, household = TRUE)))
    mc <- rc$mc
    if (rc$plots && !is.null(mc)) {
      pk <- rep_mc_primary(mc)$kpi
      blocks[[length(blocks) + 1L]] <- rep_html_b_plot(function() vofi_plot(mc, "verteilung"),
                                                       lbl("report.plot.title_verteilung",
                                                           kpi = kpi_label(pk)))
    }
  } else {
    blocks <- list(rep_html_b_par(c(lbl("report.html.risk.no_mc_household"),
                                    rep_html_drivers_text(rc, household = TRUE))))
  }
  wi <- rep_html_what_if(rc)
  if (length(wi) > 0L) {
    blocks <- c(blocks, list(rep_html_b_heading(lbl("report.html.household.what_if_header")),
                             rep_html_b_list(wi)))
  }
  blocks
}

# ---------------------------------------------------------------------------------------------
# Abschnitt: Sensitivitäten
# ---------------------------------------------------------------------------------------------

#' Tabelle der Pflichtsensitivitäten
#' @noRd
rep_html_mandatory_matrix <- function(ms) {
  if (!is.data.frame(ms) || nrow(ms) == 0L) return(NULL)
  u <- vapply(ms$kpi, rep_html_unit, "", USE.NAMES = FALSE)
  f <- function(v) vapply(seq_along(v), function(i) rep_fmt_value(v[i], u[i], 0), "")
  st <- vapply(ms$status, function(s) {
    lbl(paste0("report.html.sensitivity.status_", s), .default = s)
  }, "", USE.NAMES = FALSE)
  m <- cbind(ms$label, vapply(ms$kpi, kpi_label, "", USE.NAMES = FALSE), f(ms$base),
             f(ms$value), f(ms$diff), f(ms$value_ex_rv), f(ms$diff_ex_rv), st)
  m <- matrix(m, nrow = nrow(ms))
  colnames(m) <- c(lbl("report.html.sensitivity.col_sensitivity"), lbl("report.html.table.kpi"),
                   lbl("report.html.sensitivity.col_base"),
                   lbl("report.html.sensitivity.col_value"),
                   lbl("report.html.sensitivity.col_diff"),
                   lbl("report.html.sensitivity.col_value_ex_rv"),
                   lbl("report.html.sensitivity.col_diff_ex_rv"),
                   lbl("report.html.sensitivity.col_status"))
  if ("variant" %in% names(ms) && length(unique(ms$variant)) > 1L) {
    m <- cbind(ms$variant, m)
    colnames(m)[1L] <- lbl("report.html.table.variant")
  }
  m
}

#' Blöcke der Pflichtsensitivitäten (gerechnet bzw. Liste der hinterlegten Einträge)
#' @noRd
rep_html_mandatory_blocks <- function(rc) {
  blocks <- list(rep_html_b_heading(lbl("report.html.sensitivity.mandatory_header")),
                 rep_html_b_par(lbl("report.html.sensitivity.mandatory_intro")))
  ms <- rep_html_mandatory(rc)
  if (is.data.frame(ms)) {
    blocks[[3L]] <- rep_html_b_table(rep_html_mandatory_matrix(ms))
  } else {
    entries <- rc$res$spec$analysis$mandatory_sensitivities %||% list()
    if (length(entries) == 0L) {
      blocks[[3L]] <- rep_html_b_par(lbl("report.html.sensitivity.none"))
    } else {
      labs <- vapply(entries, function(e) {
        as.character(unlist(e$label %||% e$id %||% ""))[1L]
      }, "")
      ids <- vapply(entries, function(e) as.character(unlist(e$id %||% ""))[1L], "")
      st <- ifelse(ids == "restwert_null", lbl("report.html.sensitivity.status_ex_rv"),
                   lbl("report.html.sensitivity.status_not_computed"))
      m <- matrix(c(labs, st), ncol = 2L)
      colnames(m) <- c(lbl("report.html.sensitivity.col_sensitivity"),
                       lbl("report.html.sensitivity.col_status"))
      reason <- rc$cache$mandatory_reason %||% character(0)
      blocks <- c(blocks, list(rep_html_b_table(m),
                               rep_html_b_callout("warning",
                                                  c(reason,
                                                    lbl("report.html.sensitivity.not_computed")))))
    }
  }
  if (rc$perspective %in% c("selbstnutzer", "kleinvermieter")) {
    blocks[[length(blocks) + 1L]] <- rep_html_b_par(lbl("report.html.sensitivity.deposit_tax_note"))
  }
  blocks
}

#' Ergebnistabelle einer Sensitivitätsanalyse (WS-H, `rep_sens_matrix()`)
#'
#' Die globale Sensitivität mit genau einer Eingangsgröße formt der Bericht selbst (die
#' Tabellenfunktion von WS-H scheitert an der Matrixform einer einzelnen Zeile).
#' @noRd
rep_html_sens_matrix <- function(s, n, unit) {
  g <- s$global
  if (!identical(s$method, "global") || !is.data.frame(g) || nrow(g) != 1L) {
    return(rep_sens_matrix(s, n, unit))
  }
  cols <- intersect(c("spearman", "src", "srrc", "prcc", "s1_binned"), names(g))
  m <- matrix(c(as.character(g$input), vapply(cols, function(cc) fmt_num(g[[cc]], 3), "")),
              nrow = 1L)
  colnames(m) <- c(lbl("report.sensitivity.input"),
                   vapply(cols, function(cc) lbl(paste0("report.sensitivity.", cc)), ""))
  m
}

#' Blöcke erzeugen; ein Fehler ergibt einen Hinweis im Bericht (mit Warnung), die übrigen Blöcke
#' des Abschnitts bleiben erhalten
#' @param expr Ausdruck, der eine Liste von Blöcken liefert.
#' @param what Bezeichnung des Teils (für die Meldung).
#' @noRd
rep_html_try <- function(expr, what) {
  tryCatch(expr, error = function(e) {
    vofi_warn("report.html.block_failed", block = what, message = conditionMessage(e))
    list(rep_html_b_callout("warning", lbl("report.html.block_failed", block = what,
                                           message = conditionMessage(e))))
  })
}

#' Blöcke einer übergebenen Sensitivitätsanalyse (Tornado, Spider, global)
#' @noRd
rep_html_sens_blocks <- function(s, plots) {
  unit <- rep_sens_unit(s)
  method <- lbl(paste0("report.sensitivity.method_", s$method), .default = s$method)
  kpi_txt <- if (utl_is_string(s$kpi)) kpi_label(s$kpi) else ""
  blocks <- list(rep_html_b_heading(lbl("report.html.sensitivity.analysis_header",
                                        method = method, kpi = kpi_txt)))
  if (!is.null(s$base_value) && !is.na(s$base_value)) {
    blocks[[2L]] <- rep_html_b_par(lbl("report.html.sensitivity.base_value",
                                       value = rep_fmt_value(s$base_value, unit, 0)))
  }
  blocks[[length(blocks) + 1L]] <- rep_html_b_table(rep_html_sens_matrix(s, 10L, unit))
  if (identical(s$method, "global") && !is.null(s$r2_src) && !is.na(s$r2_src)) {
    measure <- if (s$r2_src >= 0.7) lbl("report.sensitivity.srrc") else
      lbl("report.sensitivity.s1_binned")
    blocks[[length(blocks) + 1L]] <- rep_html_b_par(lbl("report.html.sensitivity.r2",
                                                        value = fmt_num(s$r2_src, 3),
                                                        measure = measure))
  }
  if (plots) {
    title <- switch(s$method,
      spider = lbl("report.plot.title_spider", kpi = kpi_txt),
      global = lbl("report.plot.title_balken", kpi = kpi_txt,
                   measure = lbl("report.sensitivity.spearman")),
      lbl("report.plot.title_tornado", kpi = kpi_txt)
    )
    blocks[[length(blocks) + 1L]] <- rep_html_b_plot(function() vofi_plot(s), title)
  }
  blocks
}

#' Einheit eines Spezifikationspfads (für Ergebnisse von Zielwertsuchen)
#'
#' Vorrang: Einheit des Parameters aus Registry bzw. Feldkatalog (`val_param_at()`), sonst nach
#' dem letzten Pfadsegment (`rate`, `share`, `quota` als Anteil, Endung `_eur` als EUR);
#' `shared.*` und `market.*` haben kein Schema. Unbekannt: `NA` (Ausgabe als Zahl).
#' @noRd
rep_html_path_unit <- function(spec, path) {
  if (!utl_is_string(path)) return(NA_character_)
  p <- if (is.null(spec)) NULL else tryCatch(val_param_at(spec, path), error = function(e) NULL)
  u <- if (inherits(p, "vofi_param")) p$unit else NULL
  if (utl_is_string(u) && nzchar(u)) return(u)
  seg <- sub("^.*\\.", "", path)
  if (grepl("(^|_)(rate|share|quota)(_|$)", seg)) return("share")
  if (grepl("(^|_)eur$", seg)) return("EUR")
  NA_character_
}

#' Bezeichnung eines Parameterpfads: Label des Overlay-Eintrags mit diesem Ziel und Pfad
#' @noRd
rep_html_param_label <- function(spec, path) {
  if (!utl_is_string(path)) return("")
  st <- spec$stochastic %||% list()
  for (blk in c("parameters", "processes")) {
    for (e in st[[blk]] %||% list()) {
      hit <- is.list(e) && identical(as.character(e$target %||% "")[1L], path)
      if (hit && utl_is_string(e$label)) {
        return(lbl("report.html.sensitivity.param_with_label", label = e$label, path = path))
      }
    }
  }
  path
}

#' Ergebnisse von Zielwertsuchen (`vofi_solution`, 12.8) als Zeichenmatrix
#'
#' Ergebnis in der Einheit des gesuchten Parameters (`rep_html_path_unit()`; z. B. Anteile in
#' Prozent, `shared.*` als Zahl), beim Entnahme-Äquivalent und bei der Rendite der
#' Mehrinvestition in der Einheit der Kennzahl. Der Zielwert steht in der Einheit der Kennzahl,
#' eine Schwelle (`target_source = "threshold:<name>"`) mit Bezeichnung und Wert; er entfällt bei
#' Entnahme-Äquivalent und Rendite der Mehrinvestition (Ziel: Endwertdifferenz null). Vermerke
#' bei fehlender Monotonie, Sprungstellen, Überschreitungswahrscheinlichkeit und die Meldung der
#' Suche.
#' @param sols Liste von `vofi_solution`.
#' @param spec Spezifikation (Einheiten und Bezeichnungen der Parameter) bzw. `NULL`.
#' @noRd
rep_html_solution_matrix <- function(sols, spec = NULL) {
  if (length(sols) == 0L) return(NULL)
  rows <- lapply(sols, function(s) {
    what <- as.character(s$what %||% "")
    val <- s$value %||% NA_real_
    own <- what %in% c("withdrawal_equivalent", "incremental_return")
    value <- if (own) {
      rep_fmt_value(val, rep_html_unit(what), 0)
    } else {
      u <- rep_html_path_unit(spec, s$param)
      if (is.na(u)) fmt_num(val, 2) else rep_fmt_value(val, u, 2)
    }
    kpi <- if (utl_is_string(s$kpi)) s$kpi else ""
    src <- as.character(s$target_source %||% "value")[1L]
    target <- if (own) {
      ""
    } else {
      tv <- rep_fmt_value(s$target %||% NA_real_, if (nzchar(kpi)) rep_html_unit(kpi) else "",
                          0)
      if (startsWith(src, "threshold:")) {
        nm <- sub("^threshold:", "", src)
        lbl("report.html.sensitivity.target_threshold", value = tv,
            name = lbl(paste0("report.html.sensitivity.threshold_", nm), .default = nm))
      } else {
        tv
      }
    }
    pe <- s$prob_exceed %||% NA_real_
    note <- c(if (isFALSE(s$monotone)) lbl("report.html.sensitivity.not_monotone"),
              if (isTRUE(s$jump)) lbl("report.html.sensitivity.jump"),
              if (is.numeric(pe) && length(pe) == 1L && !is.na(pe)) {
                lbl("report.html.sensitivity.prob_exceed", value = fmt_pct(pe, 1))
              },
              if (utl_is_string(s$message)) s$message)
    c(lbl(paste0("report.html.sensitivity.what_", what), .default = what),
      rep_html_param_label(spec, s$param), if (nzchar(kpi)) kpi_label(kpi) else "", target,
      value, utl_collapse(note, "; "))
  })
  m <- do.call(rbind, rows)
  colnames(m) <- c(lbl("report.html.sensitivity.col_what"),
                   lbl("report.sensitivity.param"), lbl("report.html.table.kpi"),
                   lbl("report.html.sensitivity.col_target"),
                   lbl("report.html.sensitivity.col_result"), lbl("report.html.table.note"))
  if (all(!nzchar(m[, ncol(m)]))) m <- m[, -ncol(m), drop = FALSE]
  m
}

#' Blöcke der Zielwertsuchen (Überschrift und Tabelle) bzw. `list()`
#' @noRd
rep_html_solution_blocks <- function(rc) {
  m <- rep_html_solution_matrix(rc$solutions, rc$res$spec)
  if (is.null(m)) return(list())
  list(rep_html_b_heading(lbl("report.html.sensitivity.solutions_header")), rep_html_b_table(m))
}

#' @noRd
rep_html_sec_sensitivity <- function(rc) {
  title <- rep_html_sec_title("sensitivity", rc)
  blocks <- c(rep_html_try(rep_html_mandatory_blocks(rc),
                           lbl("report.html.sensitivity.mandatory_header")),
              rep_html_try(rep_html_solution_blocks(rc),
                           lbl("report.html.sensitivity.solutions_header")))
  if (length(rc$sens) == 0L) {
    blocks[[length(blocks) + 1L]] <- rep_html_b_par(c(
      lbl("report.html.sensitivity.no_analysis"),
      if (!is.null(rc$mc) && !is.null(rep_mc_inputs(rc$mc))) lbl("report.html.sensitivity.mc_ranks")
    ))
  } else {
    for (s in rc$sens) {
      what <- lbl(paste0("report.sensitivity.method_", s$method), .default = s$method)
      blocks <- c(blocks, rep_html_try(rep_html_sens_blocks(s, rc$plots), what))
    }
  }
  blocks <- c(blocks, rep_html_try(list(rep_html_b_par(rep_html_drivers_text(rc))),
                                   lbl("report.html.sensitivity.drivers_header")))
  rep_html_section("sensitivity", title, blocks)
}

# ---------------------------------------------------------------------------------------------
# Abschnitt: Annahmen und Herkunft
# ---------------------------------------------------------------------------------------------

#' Zeilen „Merkmal | Wert“ zum Rechenstand
#' @noRd
rep_html_meta_matrix <- function(rc) {
  res <- rc$res
  m <- res$meta
  g <- res$grid
  mm <- if (!is.null(rc$mc)) rc$mc$meta else if (!is.null(rc$cmp)) rc$cmp$meta else m
  defs <- m$defaults %||% list()
  def_txt <- vapply(defs, function(d) {
    if (is.list(d)) {
      as_of <- if (is.null(d$as_of)) "" else paste0(" (", fmt_date(d$as_of), ")")
      paste0(d$id %||% d$kind %||% "", as_of)
    } else {
      utl_collapse(format(d))
    }
  }, "")
  none <- lbl("report.html.assumptions.none")
  reforms <- m$pending_reforms %||% character(0)
  reforms <- if (length(reforms) > 0L) utl_collapse(reforms) else none
  lib <- m$library_version %||% NA_character_
  if (is.na(lib)) lib <- none
  items <- list(
    c("item_package", paste0(m$package_version %||% "", " (", m$contract_version %||% "", ")")),
    c("item_schema", format(m$schema_version %||% "")),
    c("item_scenario", m$scenario_id %||% ""),
    c("item_variant", m$variant %||% "base"),
    c("item_scenario_set", m$scenario_set %||% none),
    c("item_perspective", rep_enum_label("perspective", m$perspective)),
    c("item_tax", paste0(rep_enum_label("tax_regime", m$tax_regime), "; ", m$tax_module %||% "")),
    c("item_valuation_date", fmt_date(g$valuation_date)),
    c("item_horizon", lbl("report.html.assumptions.item_horizon_value",
                          years = as.integer(round(sum(g$months[g$t >= 1L]) / 12)),
                          end = g$end_date)),
    c("item_legal_state", fmt_date(m$legal_state %||% NA)),
    c("item_reforms", reforms),
    c("item_library_version", lib),
    c("item_seed", paste0(format(mm$seed %||% none), " / ", format(mm$n_sim %||% 1L))),
    c("item_created", if (is.null(m$created)) "" else format(m$created, "%d.%m.%Y %H:%M")),
    c("item_r_version", m$r_version %||% ""),
    c("item_defaults", if (length(def_txt) > 0L) utl_collapse(def_txt, "; ") else none)
  )
  out <- do.call(rbind, lapply(items, function(it) {
    c(lbl(paste0("report.html.assumptions.", it[1L])), it[2L])
  }))
  colnames(out) <- c(lbl("report.html.table.item"), lbl("report.html.table.value"))
  out
}

#' Tabelle der Bibliothekseinträge mit Prüfstatus
#' @noRd
rep_html_library_matrix <- function(ls) {
  if (is.null(ls) || nrow(ls) == 0L) return(NULL)
  q <- ifelse(is.na(ls$quality), "", ls$quality)
  st <- ls$status
  st[ls$flag] <- paste0("\u26a0 ", st[ls$flag])
  m <- cbind(ls$entry, fmt_date(ls$as_of), fmt_date(ls$valid_from),
             ifelse(is.na(ls$valid_to), "\u2013", fmt_date(ls$valid_to)),
             ls$ref_date %||% rep("", nrow(ls)), q, st)
  m <- matrix(m, nrow = nrow(ls))
  colnames(m) <- c(lbl("report.html.assumptions.col_entry"),
                   lbl("report.html.assumptions.col_as_of"),
                   lbl("report.html.assumptions.col_valid_from"),
                   lbl("report.html.assumptions.col_valid_to"),
                   lbl("report.html.assumptions.col_ref_date"),
                   lbl("report.html.assumptions.col_quality"),
                   lbl("report.html.assumptions.col_status"))
  m
}

#' Parameter mit Herkunft als Zeichenmatrix (Override-Kennzeichnung, Qualität C/D markiert)
#' @noRd
rep_html_params_matrix <- function(spec) {
  p <- as.data.frame(spec)
  if (!is.data.frame(p) || nrow(p) == 0L) return(NULL)
  src <- vapply(as.character(p$source_type), function(s) {
    if (is.na(s)) "" else lbl(paste0("report.html.assumptions.source.", s), .default = s)
  }, "", USE.NAMES = FALSE)
  ov <- as.character(p$source_type) %in% c("variant", "scenario_set", "override")
  q <- as.character(p$quality)
  q[is.na(q)] <- ""
  q[q %in% c("C", "D")] <- paste0("\u26a0 ", q[q %in% c("C", "D")])
  entry <- as.character(p$entry)
  entry[is.na(entry)] <- ""
  m <- cbind(p$path, p$value, src, entry, q,
             ifelse(ov, lbl("report.common.yes"), ""))
  m <- matrix(m, nrow = nrow(p))
  colnames(m) <- c(lbl("report.html.assumptions.col_path"),
                   lbl("report.html.assumptions.col_value"),
                   lbl("report.html.assumptions.col_source"),
                   lbl("report.html.assumptions.col_entry"),
                   lbl("report.html.assumptions.col_quality"),
                   lbl("report.html.assumptions.col_override"))
  attr(m, "n_override") <- sum(ov)
  m
}

#' Abweichungen der Parameter einer Variante gegenüber der Referenz
#' @noRd
rep_html_params_diff <- function(spec_v, spec_r) {
  a <- as.data.frame(spec_v)
  b <- as.data.frame(spec_r)
  if (!is.data.frame(a) || nrow(a) == 0L) return(NULL)
  rv <- b$value[match(a$path, b$path)]
  sel <- is.na(rv) | rv != a$value
  if (!any(sel)) return(NULL)
  m <- cbind(a$path[sel], ifelse(is.na(rv[sel]), "\u2013", rv[sel]), a$value[sel])
  m <- matrix(m, ncol = 3L)
  colnames(m) <- c(lbl("report.html.assumptions.col_path"), lbl("report.html.table.from"),
                   lbl("report.html.table.to"))
  m
}

#' @noRd
rep_html_sec_assumptions <- function(rc) {
  title <- rep_html_sec_title("assumptions", rc)
  if (rc$household) return(rep_html_section("assumptions", title, rep_html_assumptions_short(rc)))
  res <- rc$res
  ls <- rep_html_library_status(res)
  date <- as.Date(res$meta$legal_state %||% res$grid$valuation_date)
  blocks <- list(rep_html_b_par(lbl("report.html.assumptions.intro")),
                 rep_html_b_heading(lbl("report.html.assumptions.meta_header")),
                 rep_html_b_table(rep_html_meta_matrix(rc)),
                 rep_html_b_heading(lbl("report.html.assumptions.library_header")))
  if (is.null(ls)) {
    blocks[[length(blocks) + 1L]] <- rep_html_b_par(lbl("report.html.assumptions.no_library"))
  } else {
    out <- ls$entry[ls$outdated]
    blocks[[length(blocks) + 1L]] <- if (length(out) > 0L) {
      rep_html_b_callout("warning", lbl("report.html.assumptions.validity_warning",
                                        n = length(out), date = date,
                                        entries = utl_collapse(out)))
    } else {
      rep_html_b_par(lbl("report.html.assumptions.validity_ok", date = date))
    }
    blocks[[length(blocks) + 1L]] <- rep_html_b_table(rep_html_library_matrix(ls))
  }
  pm <- rep_html_params_matrix(res$spec)
  blocks[[length(blocks) + 1L]] <- rep_html_b_heading(lbl("report.html.assumptions.params_header"))
  if (is.null(pm)) {
    blocks[[length(blocks) + 1L]] <- rep_html_b_par(lbl("report.html.assumptions.no_params"))
  } else {
    n_ov <- attr(pm, "n_override")
    if (n_ov > 0L) {
      blocks[[length(blocks) + 1L]] <- rep_html_b_par(lbl("report.html.assumptions.override_note",
                                                          n = as.integer(n_ov)))
    }
    blocks[[length(blocks) + 1L]] <- rep_html_b_table(pm, wide = TRUE)
  }
  if (!is.null(rc$cmp)) {
    for (v in rc$cmp$variants %||% character(0)) {
      sv <- rep_det_result(rc$cmp$results[[v]])$spec
      d <- rep_html_params_diff(sv, res$spec)
      if (is.null(d)) next
      blocks <- c(blocks, list(rep_html_var_heading(v), rep_html_b_table(d)))
    }
  }
  rep_html_section("assumptions", title, blocks)
}

#' Die wichtigsten Annahmen (Haushaltsmodus)
#' @noRd
rep_html_assumptions_short <- function(rc) {
  res <- rc$res
  sp <- res$spec
  g <- res$grid
  items <- list(
    c("item_valuation_date", fmt_date(g$valuation_date)),
    c("item_horizon", lbl("report.html.assumptions.item_horizon_value",
                          years = as.integer(round(sum(g$months[g$t >= 1L]) / 12)),
                          end = g$end_date)),
    c("item_deposit_rate", rep_html_spec_text(sp, "accounts.deposit_rate_pa", "pct", res)),
    c("item_withholding", rep_html_spec_text(sp, "accounts.deposit_withholding_tax_share", "pct",
                                             res)),
    c("item_overdraft_rate", rep_html_spec_text(sp, "accounts.overdraft_rate_pa", "pct", res)),
    c("item_income", rep_html_spec_text(sp, "household.net_income_month_eur", "eur", res)),
    c("item_rent_now", rep_html_spec_text(sp, "household.current_rent_month_eur", "eur", res))
  )
  rows <- lapply(items, function(it) {
    if (is.na(it[2L])) return(NULL)
    c(lbl(paste0("report.html.assumptions.", it[1L])), it[2L])
  })
  # Kredite je Variante (bei Vergleichen alle Varianten, Referenz zuerst)
  loan_res <- if (is.null(rc$cmp)) list(res) else
    lapply(rc$cmp$results[rep_comparison_variants(rc$cmp)], rep_det_result)
  multi <- length(loan_res) > 1L
  for (v in seq_along(loan_res)) {
    rv <- loan_res[[v]]
    ins <- rep_html_instruments(rv)
    for (i in seq_len(if (is.null(ins)) 0L else nrow(ins))) {
      rate <- rep_html_spec_text(rv$spec, paste0("financing.", ins$id[i], ".rate_pa"), "pct", rv)
      label <- lbl("report.html.assumptions.item_loan", label = ins$label[i])
      if (multi) {
        label <- lbl("report.html.variants.household_text",
                     variant = rep_vlabel(names(loan_res)[v], short = TRUE), text = label)
      }
      value <- lbl("report.html.assumptions.item_loan_value",
                   amount = rep_fmt_value(ins$draw[i], "EUR", 0),
                   rate = if (is.na(rate)) fmt_num(NA) else rate)
      rows[[length(rows) + 1L]] <- c(label, value)
    }
  }
  lib <- res$meta$library_version %||% NA_character_
  if (is.na(lib)) lib <- lbl("report.html.assumptions.none")
  rows <- c(rows, list(
    c(lbl("report.html.assumptions.item_legal_state"), fmt_date(res$meta$legal_state %||% NA)),
    c(lbl("report.html.assumptions.item_library_version"), lib)
  ))
  rows <- rows[!vapply(rows, is.null, logical(1))]
  m <- do.call(rbind, rows)
  colnames(m) <- c(lbl("report.html.table.item"), lbl("report.html.table.value"))
  blocks <- list(rep_html_b_par(lbl("report.html.assumptions.short_intro")), rep_html_b_table(m))
  ls <- rep_html_library_status(res)
  if (!is.null(ls) && any(ls$outdated)) {
    txt <- lbl("report.html.assumptions.validity_warning", n = sum(ls$outdated),
               date = as.Date(res$meta$legal_state %||% g$valuation_date),
               entries = utl_collapse(ls$entry[ls$outdated]))
    blocks[[3L]] <- rep_html_b_callout("warning", txt)
  }
  blocks
}

# ---------------------------------------------------------------------------------------------
# Abschnitte: VoFi-Tabelle, Prüfungen, Methodik
# ---------------------------------------------------------------------------------------------

#' Zeichenmatrix einer VoFi-Tabelle (format.vofi_table von WS-H)
#' @noRd
rep_html_vofi_block <- function(tab) {
  m <- format(tab)
  rep_html_b_table(m, wide = TRUE)
}

#' @noRd
rep_html_sec_vofi_table <- function(rc) {
  title <- rep_html_sec_title("vofi_table", rc)
  sim_of <- function(r) if (inherits(r, "vofi_mc_result")) "deterministic" else 1L
  blocks <- list()
  if (!is.null(rc$cmp)) {
    cmp <- rc$cmp
    for (v in rep_comparison_variants(cmp)) {
      tab <- vofi_table(cmp, sim = sim_of(cmp$results[[v]]), variant = v)
      blocks <- c(blocks, list(rep_html_var_heading(v), rep_html_vofi_block(tab)))
    }
    dt <- cmp$diff_table
    for (v in setdiff(rep_comparison_variants(cmp), cmp$baseline)) {
      d <- if (inherits(dt, "vofi_table")) dt else if (is.list(dt)) dt[[v]] else NULL
      if (!inherits(d, "vofi_table")) next
      blocks <- c(blocks, list(rep_html_b_heading(lbl("report.html.variants.diff_table",
                                                      variant = v, baseline = cmp$baseline)),
                               rep_html_vofi_block(d)))
      if (inherits(dt, "vofi_table")) break
    }
  } else {
    tab <- vofi_table(rc$base, sim = sim_of(rc$base))
    intro <- if (identical(tab$layout, "transposed")) "intro_transposed" else "intro"
    txt <- lbl(paste0("report.html.vofi_table.", intro))
    if (!is.null(rc$mc)) txt <- c(txt, lbl("report.html.vofi_table.mc_note"))
    blocks <- list(rep_html_b_par(txt), rep_html_vofi_block(tab))
  }
  rep_html_section("vofi_table", title, blocks)
}

#' @noRd
rep_html_sec_checks <- function(rc) {
  title <- rep_html_sec_title("checks", rc)
  results <- if (!is.null(rc$cmp)) rc$cmp$results else list(rc$base)
  if (is.null(rc$cmp)) names(results) <- rc$res$meta$variant %||% "base"
  blocks <- list(rep_html_b_par(lbl("report.html.checks.intro")))
  ok_all <- TRUE
  for (v in names(results)) {
    ch <- results[[v]]$checks
    if (!is.data.frame(ch) || nrow(ch) == 0L) next
    ok_all <- ok_all && all(ch$ok %in% TRUE)
    m <- cbind(ch$invariant, formatC(as.double(ch$max_dev), format = "g", digits = 3),
               formatC(as.double(ch$tol), format = "g", digits = 3),
               ifelse(ch$ok %in% TRUE, lbl("report.common.yes"), lbl("report.common.no")))
    m <- matrix(m, nrow = nrow(ch))
    colnames(m) <- c(lbl("report.html.checks.col_invariant"), lbl("report.html.checks.col_max_dev"),
                     lbl("report.html.checks.col_tol"), lbl("report.html.checks.col_ok"))
    if (length(results) > 1L) blocks[[length(blocks) + 1L]] <- rep_html_var_heading(v)
    blocks[[length(blocks) + 1L]] <- rep_html_b_table(m)
  }
  blocks[[length(blocks) + 1L]] <- if (ok_all) {
    rep_html_b_par(lbl("report.html.checks.ok"))
  } else {
    rep_html_b_callout("warning", lbl("report.html.checks.failed"))
  }
  fl <- rc$base$flags
  if (is.data.frame(fl) && nrow(fl) > 1L) {
    cols <- setdiff(names(fl), c("sim", "block", "branch"))
    cols <- cols[vapply(cols, function(cc) is.logical(fl[[cc]]), logical(1))]
    share <- vapply(cols, function(cc) mean(fl[[cc]] %in% TRUE), double(1))
    if (any(share > 0)) {
      labs <- vapply(cols[share > 0], function(f) {
        lbl(paste0("report.flags.", f), .default = f)
      }, "", USE.NAMES = FALSE)
      m <- matrix(c(labs, fmt_pct(share[share > 0], 1)), ncol = 2L)
      colnames(m) <- c(lbl("excel_export.columns.flag"), lbl("excel_export.columns.flag_share"))
      blocks <- c(blocks, list(rep_html_b_heading(lbl("report.html.checks.flags_header")),
                               rep_html_b_table(m)))
    }
  }
  rep_html_section("checks", title, blocks)
}

#' @noRd
rep_html_sec_method <- function(rc) {
  tax_none <- identical(rc$res$meta$tax_module %||% "none", "none")
  keys <- c("vofi", "comparison", "interest", if (rc$is_mc) "mc", if (tax_none) "limits_tax",
            "limits")
  rep_html_section("method", rep_html_sec_title("method", rc),
                   list(rep_html_b_par(vapply(keys, function(k) {
                     lbl(paste0("report.html.method.", k))
                   }, ""))))
}

# ---------------------------------------------------------------------------------------------
# Abschnitte des Haushaltsmodus: Belastung, Förderung, Glossar
# ---------------------------------------------------------------------------------------------

#' Betrag für Haushalte ohne Vorzeichen (Memo 07 Paragraf 5.4 Nr. 4 und 5)
#'
#' `v` ist so ausgerichtet, dass positive Werte der erwarteten Richtung der Spalte entsprechen
#' (Kosten positiv bzw. Erlöse positiv); sie erscheinen als gerundeter Betrag. Werte der
#' Gegenrichtung erscheinen in Worten („Einnahme … €“ in einer Kostenspalte, „Ausgabe … €“ in
#' einer Erlösspalte), nie mit Minuszeichen.
#' @param v Zahlen.
#' @param dir `"out"` (Kostenspalte) oder `"in"` (Erlösspalte).
#' @param kind Rundung (`"month"` bzw. `"sum"`, `rep_round_household()`).
#' @noRd
rep_html_hh_amount <- function(v, dir = "out", kind = "month") {
  vapply(as.double(v), function(x) {
    if (is.na(x)) return(fmt_num(NA))
    r <- rep_round_household(x, kind)
    if (r >= 0) return(fmt_int(r))
    key <- if (identical(dir, "out")) "inflow" else "outflow"
    lbl(paste0("report.html.household.", key), value = fmt_int(abs(r)))
  }, "")
}

#' Zahlung mit wechselnder Richtung in Worten („Einnahme … €“ / „Ausgabe … €“)
#' @noRd
rep_html_hh_signed <- function(v, kind = "month") {
  vapply(as.double(v), function(x) {
    if (is.na(x)) return(fmt_num(NA))
    r <- rep_round_household(x, kind)
    if (r == 0) return(fmt_int(0))
    key <- if (r > 0) "inflow" else "outflow"
    lbl(paste0("report.html.household.", key), value = fmt_int(abs(r)))
  }, "")
}

#' Tabelle der Haushaltssicht einer Variante
#'
#' Selbstnutzer: Bestandteile der monatlichen Belastung, Belastung mit und ohne Tilgung, bei
#' Vergleichen Ersparnis und kumulierte Ersparnis in Worten. Kleinvermieter: Mieten, Förderung
#' und sonstige Erlöse, laufende Kosten, Investitionen, sonstige Zahlungen, Kapitaldienst und
#' Cashflow; die Spalten ergeben zusammen den Cashflow (Spalten ohne Werte entfallen).
#' @return Zeichenmatrix mit den Attributen `picked` und `note` bzw. `NULL`.
#' @noRd
rep_html_burden_matrix <- function(d, owner) {
  if (nrow(d) == 0L) return(NULL)
  idx <- rep_html_pick_rows(nrow(d))
  picked <- length(idx) < nrow(d)
  d <- d[idx, , drop = FALSE]
  yr <- ifelse(d$phase == "construction",
               paste0(lbl("report.html.table.phase_construction"), " ", d$year),
               sprintf("%d", as.integer(d$year)))
  num <- function(col) if (col %in% names(d)) as.double(d[[col]]) else rep(0, nrow(d))
  any_nz <- function(v) any(abs(v) > vofi_tol$zero_abs, na.rm = TRUE)
  note <- NULL
  out <- function(v) rep_html_hh_amount(v, "out")
  if (owner) {
    m <- cbind(yr, out(num("interest") + num("fees")), out(num("repay")),
               out(num("energy") + num("energy_income")), out(num("maintenance")),
               out(num("operating") + num("other")))
    cn <- c("col_interest", "col_repay", "col_energy", "col_maintenance", "col_other")
    if (any(num("current_rent") > 0)) {
      m <- cbind(m, out(num("current_rent")))
      cn <- c(cn, "col_current_rent")
    }
    m <- cbind(m, out(num("burden")), out(num("burden_ex_repay")))
    cn <- c(cn, "col_burden", "col_burden_ex")
    if ("saving" %in% names(d)) {
      m <- cbind(m, vapply(num("saving"), rep_html_hh_diff_text, ""),
                 vapply(num("cumulative_saving"), rep_html_hh_diff_text, "", kind = "sum"))
      cn <- c(cn, "col_saving", "col_cum_saving")
    }
  } else {
    inc <- num("other_income") + num("grants")
    m <- cbind(yr, rep_html_hh_amount(num("rent"), "in"))
    cn <- "col_rent"
    if (any_nz(inc)) {
      m <- cbind(m, rep_html_hh_amount(inc, "in"))
      cn <- c(cn, "col_other_income")
    }
    m <- cbind(m, out(-num("costs")))
    cn <- c(cn, "col_costs")
    if (any_nz(num("investment"))) {
      m <- cbind(m, out(-num("investment")))
      cn <- c(cn, "col_investment")
    }
    if (any_nz(num("other"))) {
      m <- cbind(m, rep_html_hh_signed(num("other")))
      cn <- c(cn, "col_other_flows")
    }
    m <- cbind(m, out(-(num("interest") + num("repay") + num("fees"))),
               vapply(num("cashflow"), rep_html_hh_cash_text, ""))
    cn <- c(cn, "col_debt", "col_cashflow")
    if ("cashflow_change" %in% names(d)) {
      m <- cbind(m, vapply(num("cashflow_change"), rep_html_hh_diff_text, ""))
      cn <- c(cn, "col_change")
    }
    note <- lbl("report.html.household.cashflow_note")
  }
  m <- matrix(m, nrow = nrow(d))
  colnames(m) <- c(lbl("report.html.table.year"),
                   vapply(cn, function(k) lbl(paste0("report.html.household.", k)), "",
                          USE.NAMES = FALSE))
  attr(m, "picked") <- picked
  attr(m, "note") <- note
  m
}

#' Cashflow in Worten („Überschuss … €“ / „Zuschuss … €“)
#' @noRd
rep_html_hh_cash_text <- function(v) {
  if (is.na(v)) return(fmt_num(NA))
  key <- if (rep_round_household(v) >= 0) "report.html.household.surplus" else
    "report.html.household.subsidy"
  lbl(key, value = rep_amount_text(v))
}

#' Differenz in Worten („spart … €“ / „… € mehr“ / „gleich“)
#' @param kind Rundung (`"month"` bzw. `"sum"` für kumulierte Beträge).
#' @noRd
rep_html_hh_diff_text <- function(v, kind = "month") {
  if (is.na(v)) return(fmt_num(NA))
  r <- rep_round_household(v, kind)
  key <- if (r > 0) "saving" else if (r < 0) "more" else "equal"
  lbl(paste0("report.html.household.", key), value = rep_amount_text(v, kind))
}

#' @noRd
rep_html_sec_burden <- function(rc) {
  title <- rep_html_sec_title("burden", rc)
  hv <- rep_html_hh_summary(rc)$view
  intro <- if (rc$owner) "intro_owner" else "intro_landlord"
  blocks <- list(rep_html_b_par(lbl(paste0("report.html.household.", intro))))
  vars <- unique(hv$variant)
  for (v in vars) {
    d <- hv[hv$variant == v, , drop = FALSE]
    if (length(vars) > 1L) blocks[[length(blocks) + 1L]] <- rep_html_var_heading(v)
    blocks[[length(blocks) + 1L]] <- rep_html_b_table(rep_html_burden_matrix(d, rc$owner),
                                                      caption = lbl("report.plot.y_eur_month"))
  }
  if (!rc$owner) {
    results <- if (is.null(rc$cmp)) list(rc$base) else
      rc$cmp$results[rep_comparison_variants(rc$cmp)]
    for (v in seq_along(results)) {
      items <- rep_html_try(rep_html_levy_household(results[[v]]), lbl("report.html.levy.header"))
      if (!is.character(items)) {
        blocks <- c(blocks, items)
        next
      }
      if (length(items) == 0L) next
      if (length(results) > 1L) {
        items <- vapply(items, function(t) {
          lbl("report.html.variants.household_text", variant = names(results)[v], text = t)
        }, "", USE.NAMES = FALSE)
      }
      hdr <- lbl("report.html.levy.household_header")
      seen <- vapply(blocks, function(b) {
        identical(b$type, "heading") && identical(b$text, hdr)
      }, logical(1))
      if (!any(seen)) blocks[[length(blocks) + 1L]] <- rep_html_b_heading(hdr)
      blocks[[length(blocks) + 1L]] <- rep_html_b_list(items)
    }
  }
  if (rc$plots) {
    x <- if (is.null(rc$cmp)) rc$res else rc$cmp
    cap <- lbl(if (rc$owner) "report.plot.title_belastung" else "report.plot.title_cashflow")
    blocks[[length(blocks) + 1L]] <- rep_html_b_plot(function() vofi_plot(x, "belastung"), cap)
  }
  rep_html_section("burden", title, blocks)
}

#' @noRd
rep_html_sec_funding <- function(rc) {
  title <- rep_html_sec_title("funding", rc)
  results <- if (!is.null(rc$cmp)) {
    lapply(rc$cmp$results[rep_comparison_variants(rc$cmp)], rep_det_result)
  } else {
    stats::setNames(list(rc$res), rc$res$meta$variant %||% "base")
  }
  blocks <- list()
  for (v in names(results)) {
    res <- results[[v]]
    if (length(results) > 1L) blocks[[length(blocks) + 1L]] <- rep_html_var_heading(v)
    g <- rep_html_grants(res)
    ins <- rep_html_instruments(res)
    items <- character(0)
    if (is.null(g)) {
      items <- lbl("report.html.household.no_grants")
    } else {
      items <- vapply(seq_len(nrow(g)), function(i) {
        lab <- if (nzchar(g$program[i])) paste0(g$label[i], " (", g$program[i], ")") else
          g$label[i]
        lbl("report.html.household.grant_item", label = lab,
            value = rep_amount_text(g$amount[i], "sum"), years = g$years[i])
      }, "")
    }
    tg <- if (is.null(ins)) 0 else sum(ins$grant, na.rm = TRUE)
    if (tg > vofi_tol$zero_abs) {
      items <- c(items, lbl("report.html.household.grant_item",
                            label = lbl("report.html.financing.col_grant"),
                            value = rep_amount_text(tg, "sum"),
                            years = lbl("report.html.financing.col_instrument")))
    }
    if (is.null(ins)) {
      items <- c(items, lbl("report.html.household.no_loans"))
    } else {
      items <- c(items, vapply(seq_len(nrow(ins)), function(i) {
        if (is.na(ins$rate[i])) {
          return(lbl("report.html.household.loan_item_norate", label = ins$label[i],
                     amount = rep_amount_text(ins$draw[i], "sum"),
                     balance = rep_amount_text(ins$balance_end[i], "sum")))
        }
        grace <- if (is.na(ins$grace_interest[i])) "" else if (ins$grace_from[i] ==
                                                             ins$grace_to[i]) {
          lbl("report.html.household.loan_grace_one", from = ins$grace_from[i],
              interest = rep_amount_text(ins$grace_interest[i]))
        } else {
          lbl("report.html.household.loan_grace", from = ins$grace_from[i],
              to = ins$grace_to[i], interest = rep_amount_text(ins$grace_interest[i]))
        }
        lbl("report.html.household.loan_item", label = ins$label[i],
            amount = rep_amount_text(ins$draw[i], "sum"), year = ins$rate_year[i],
            rate = rep_amount_text(ins$rate[i]), grace = grace,
            balance = rep_amount_text(ins$balance_end[i], "sum"))
      }, ""))
    }
    checks <- rep_html_try(rep_html_funding_check_items(res),
                           lbl("report.html.funding_check.header"))
    if (is.character(checks)) items <- c(items, checks) else
      blocks <- c(blocks, checks)
    oc <- rep_html_kn(res, "own_contribution")
    if (!is.na(oc)) {
      items <- c(items, if (oc > vofi_tol$zero_abs) {
        lbl("report.html.household.own_contribution", value = rep_amount_text(oc, "sum"))
      } else {
        lbl("report.household.text.own_contribution_none")
      })
    }
    blocks[[length(blocks) + 1L]] <- rep_html_b_list(items)
  }
  rep_html_section("funding", title, blocks)
}

#' @noRd
rep_html_sec_glossary <- function(rc) {
  terms <- if (rc$owner) {
    c("burden", "saving", "own", "calls", "payback", "wealth", "rv", "repay", "deposit",
      "simulation", "ratio")
  } else {
    c("cashflow", "own", "calls", "payback", "wealth", "rv", "repay", "deposit", "simulation",
      "warm_rent")
  }
  defs <- lapply(terms, function(t) {
    c(lbl(paste0("report.html.glossary.", t)), lbl(paste0("report.html.glossary.", t, "_def")))
  })
  rep_html_section("glossary", rep_html_sec_title("glossary", rc),
                   list(list(type = "deflist", items = defs)))
}

# ---------------------------------------------------------------------------------------------
# Abschnitt: Hinweise (immer am Ende)
# ---------------------------------------------------------------------------------------------

#' @noRd
rep_html_sec_notes <- function(rc) {
  res <- rc$res
  m <- res$meta
  ls <- rep_html_library_status(res)
  lib <- if (is.null(m$library_version) || is.na(m$library_version)) {
    lbl("report.html.notes.library_unknown")
  } else {
    m$library_version
  }
  items <- c(
    lbl("report.html.notes.disclaimer"),
    rep_result_notes(res),
    lbl("report.html.notes.funding", library = lib),
    lbl("report.html.notes.legal", date = as.Date(m$legal_state %||% res$grid$valuation_date))
  )
  if (length(m$pending_reforms %||% character(0)) > 0L) {
    items <- c(items, lbl("report.html.notes.reforms", reforms = utl_collapse(m$pending_reforms)))
  }
  if (!is.null(ls) && any(ls$outdated)) items <- c(items, lbl("report.html.notes.library_outdated"))
  if (rc$household) items <- c(items, lbl("report.html.notes.household_rounding"))
  rep_html_section("notes", rep_html_sec_title("notes", rc),
                   list(rep_html_b_callout("notes", unique(items))))
}

# ---------------------------------------------------------------------------------------------
# Kurzvorlage (Fachmodus): Beschlussvorschlag, Investition, Kennzahlen, Restriktionen, Risiken,
# Szenariotabelle
# ---------------------------------------------------------------------------------------------

#' @noRd
rep_html_sec_decision <- function(rc) {
  title <- rep_html_sec_title("decision", rc)
  if (!is.null(rc$cmp)) {
    v <- rep_html_best_variant(rc$cmp)
    tl <- if (is.na(v)) NULL else rep_html_cmp_tl(rc$cmp, v)
    obj <- lbl("report.html.board.object_variant", variant = v)
    obj_cap <- lbl("report.html.board.object_variant_cap", variant = v)
  } else {
    tl <- rep_html_main_tl(rc)
    obj <- lbl("report.html.board.object_project")
    obj_cap <- lbl("report.html.board.object_project_cap")
  }
  prop <- if (is.null(tl) || is.null(tl$level)) {
    lbl("report.html.board.proposal_none")
  } else {
    lbl(paste0("report.html.board.proposal_", tl$level), object = obj, object_cap = obj_cap)
  }
  lead <- if (!is.null(rc$cmp)) rep_html_cmp_lead(rc$cmp, rc$is_mc) else rep_html_lead(rc)
  rep_html_section("decision", title, list(
    rep_html_b_ampel(tl),
    rep_html_b_callout("proposal", c(prop, lbl("report.html.board.draft"))),
    rep_html_b_par(lead)
  ))
}

#' Mittelherkunft eines Ergebnisses (EK, Kredite, Zuschüsse, Nachschüsse)
#' @noRd
rep_html_sources <- function(res) {
  ins <- rep_html_instruments(res)
  eq <- sum(rep_html_cat_values(res, "equity", "equity_in"))
  calls <- sum(rep_html_cat_values(res, "equity", c("equity_call", "shortfall")))
  grants <- rep_html_funding_total(res)
  src <- c(lbl("report.html.board.src_equity"), if (!is.null(ins)) ins$label,
           lbl("report.html.board.src_grants"), lbl("report.html.board.src_calls"))
  val <- c(eq, if (!is.null(ins)) ins$draw, grants, calls)
  # Investition: Auszahlungen der Investitionskategorien und negative freie Zahlungen (custom)
  inv <- -sum(rep_html_cat_values(res, "project", rep_html_invest_categories())) -
    sum(pmin(rep_html_cat_values(res, "project", "custom"), 0))
  list(labels = src, values = val, invest = inv)
}

#' @noRd
rep_html_sec_investment <- function(rc) {
  title <- rep_html_sec_title("investment", rc)
  if (!is.null(rc$cmp)) {
    vars <- rep_comparison_variants(rc$cmp)
    srcs <- lapply(vars, function(v) rep_html_sources(rep_det_result(rc$cmp$results[[v]])))
    labs <- unique(unlist(lapply(srcs, function(s) s$labels)))
    inv_row <- c(lbl("report.html.board.col_investment"),
                 vapply(srcs, function(s) rep_fmt_value(s$invest, "EUR", 0), ""))
    rows <- lapply(labs, function(l) {
      c(l, vapply(srcs, function(s) {
        i <- match(l, s$labels)
        if (is.na(i)) "\u2013" else rep_fmt_value(s$values[i], "EUR", 0)
      }, ""))
    })
    m <- do.call(rbind, c(list(inv_row), rows))
    colnames(m) <- c(lbl("report.html.board.col_source"), vars)
    fc <- lapply(vars, function(v) {
      fm <- rep_html_funding_check_matrix(rep_det_result(rc$cmp$results[[v]]))
      if (is.null(fm)) return(NULL)
      out <- cbind(v, fm)
      colnames(out)[1L] <- lbl("report.html.table.variant")
      out
    })
    fc <- fc[!vapply(fc, is.null, logical(1))]
    blocks <- list(rep_html_b_table(m))
    if (length(fc) > 0L) {
      blocks <- c(blocks, list(
        rep_html_b_table(do.call(rbind, fc), caption = lbl("report.html.funding_check.header"))
      ))
    }
    return(rep_html_section("investment", title, blocks))
  }
  s <- rep_html_sources(rc$res)
  m <- cbind(s$labels, rep_fmt_value(s$values, "EUR", 0))
  m <- matrix(m, ncol = 2L)
  colnames(m) <- c(lbl("report.html.board.col_source"), lbl("report.html.board.col_amount"))
  blocks <- list(rep_html_b_par(lbl("report.html.board.investment",
                                    value = rep_fmt_value(s$invest, "EUR", 0))),
                 rep_html_b_table(m))
  pv <- rep_html_kn(rc$res, "pv_subsidies")
  if (!is.na(pv)) {
    blocks[[3L]] <- rep_html_b_par(lbl("report.html.financing.pv_subsidies",
                                       value = rep_html_kv(rc$res, "pv_subsidies")))
  }
  fm <- rep_html_funding_check_matrix(rc$res)
  if (!is.null(fm)) {
    cap <- lbl("report.html.funding_check.header")
    blocks[[length(blocks) + 1L]] <- rep_html_b_table(fm, caption = cap)
  }
  rep_html_section("investment", title, blocks)
}

#' Kennzahlen der Kurzvorlage (mit und ohne Restwert, kompakt) mit einer Grafik
#' @noRd
rep_html_board_kpis <- function(rc, title) {
  if (!is.null(rc$cmp)) {
    cmp <- rc$cmp
    blocks <- c(list(rep_html_b_table(rep_cmp_kpi_matrix(cmp, rep_cmp_kpis(cmp, head = TRUE),
                                                         short = FALSE))),
                rep_html_solution_blocks(rc))
    if (rc$plots) {
      cap <- lbl("report.plot.title_endwert", kpi = kpi_label("delta_terminal_value"))
      blocks[[length(blocks) + 1L]] <- rep_html_b_plot(function() vofi_plot(cmp, "endwert"),
                                                       cap, height = 3.2)
    }
    return(rep_html_section("kpis", title, blocks))
  }
  blocks <- rep_html_kpi_tables(rc$res, compact = TRUE)
  if (!is.null(rc$mc)) {
    blocks[[length(blocks) + 1L]] <- rep_html_b_table(rep_mc_stats_matrix(rc$mc,
                                                                          rep_mc_head_kpis(rc$mc)))
  }
  blocks <- c(blocks, rep_html_solution_blocks(rc))
  if (rc$plots) {
    res <- rc$res
    blocks[[length(blocks) + 1L]] <- rep_html_b_plot(function() vofi_plot(res, "differenz"),
                                                     lbl("report.plot.title_differenz"),
                                                     height = 3.2)
  }
  rep_html_section("kpis", title, blocks)
}

#' @noRd
rep_html_sec_restrictions <- function(rc) {
  title <- rep_html_sec_title("restrictions", rc)
  r <- if (!is.null(rc$cmp)) rc$cmp$restrictions else rep_html_main_tl(rc)$restrictions
  m <- rep_html_restr_matrix(r)
  rep_html_section("restrictions", title, list(
    if (is.null(m)) rep_html_b_par(lbl("report.html.summary.restrictions_none")) else
      rep_html_b_table(m)
  ))
}

#' @noRd
rep_html_sec_risks <- function(rc) {
  title <- rep_html_sec_title("risks", rc)
  d <- rep_html_drivers(rc)
  items <- if (length(d) > 0L) {
    vapply(seq_along(d), function(i) {
      lbl("report.html.board.risk_item", rank = i, label = d[i])
    }, "")
  } else {
    character(0)
  }
  extra <- character(0)
  if (!is.null(rc$mc)) extra <- utils::head(rep_mc_risk_lines(rc$mc), 3L)
  if (!is.null(rc$cmp)) {
    pb <- if (rc$is_mc) rep_prob_better_text(rc$cmp) else NULL
    extra <- if (is.null(pb)) rep_html_cmp_det_text(rc$cmp) else
      lbl("report.html.variants.prob_better", text = pb)
  }
  blocks <- list(
    if (length(items) > 0L) rep_html_b_list(items) else
      rep_html_b_par(lbl("report.html.board.risks_none")),
    rep_html_b_par(extra)
  )
  rep_html_section("risks", title, blocks)
}

#' @noRd
rep_html_sec_scenarios <- function(rc) {
  title <- rep_html_sec_title("scenarios", rc)
  rows <- list()
  if (!is.null(rc$cmp)) {
    cmp <- rc$cmp
    k <- "delta_terminal_value"
    for (v in rep_comparison_variants(cmp)) {
      dvr <- if (rep_html_is_reference(cmp, v)) lbl("report.html.board.reference_row") else
        rep_fmt_value(rep_html_cmp_delta(cmp, v), "EUR", 0)
      rows[[length(rows) + 1L]] <- c(v, rep_fmt_value(rep_cmp_value(cmp, v, k), "EUR", 0),
                                     rep_fmt_value(rep_cmp_value(cmp, v, paste0(k, "_ex_rv")),
                                                   "EUR", 0),
                                     dvr)
    }
    m <- do.call(rbind, rows)
    colnames(m) <- c(lbl("report.html.board.col_scenario"), kpi_label(k),
                     kpi_label(paste0(k, "_ex_rv")), kpi_label("delta_vs_reference"))
    return(rep_html_section("scenarios", title, list(rep_html_b_table(m))))
  }
  res <- rc$res
  pk <- rep_primary_kpi(res)$kpi
  kx <- paste0(pk, "_ex_rv")
  rows[[1L]] <- c(lbl("report.html.board.scenario_base"), rep_html_kv(res, pk),
                  rep_html_kv(res, kx))
  if (!is.null(rc$mc)) {
    for (nm in c("p05", "p50", "p95")) {
      r <- rc$mc$runs[[nm]]
      if (!inherits(r, "vofi_result")) next
      rows[[length(rows) + 1L]] <- c(lbl(paste0("report.html.risk.run_", nm)),
                                     rep_html_kv(r, pk), rep_html_kv(r, kx))
    }
  }
  ms <- rep_html_mandatory(rc)
  if (is.data.frame(ms)) {
    ms <- ms[ms$status %in% c("computed", "no_effect", "same_as_base"), , drop = FALSE]
    for (i in seq_len(nrow(ms))) {
      u <- rep_html_unit(ms$kpi[i])
      rows[[length(rows) + 1L]] <- c(ms$label[i], rep_fmt_value(ms$value[i], u, 0),
                                     rep_fmt_value(ms$value_ex_rv[i], u, 0))
    }
  }
  m <- do.call(rbind, rows)
  colnames(m) <- c(lbl("report.html.board.col_scenario"), kpi_label(pk), kpi_label(kx))
  rep_html_section("scenarios", title, list(rep_html_b_table(m)))
}

# ---------------------------------------------------------------------------------------------
# Pandoc-Markdown
# ---------------------------------------------------------------------------------------------

#' Text für Pandoc-Markdown maskieren (Sonderzeichen, Zeilenumbrüche)
#' @noRd
rep_html_esc <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("([*_`|<>$~^@#{}\\[\\]])", "\\\\\\1", x, perl = TRUE)
  gsub("[\r\n]+", " ", x)
}

#' Text für Pandoc-Metadaten maskieren (Seitentitel)
#'
#' pandoc liest Metadaten als Markdown: Jedes ASCII-Satzzeichen wird mit einem Backslash
#' maskiert, damit der Titel wörtlich (ohne Hervorhebung, HTML oder typografische
#' Anführungszeichen) im Element `<title>` steht.
#' @noRd
rep_html_esc_meta <- function(x) {
  x <- enc2utf8(as.character(x)[1L])
  if (is.na(x)) return("")
  x <- gsub("[\r\n]+", " ", x, perl = TRUE)
  gsub("([!-/:-@\\[-`{-~])", "\\\\\\1", x, perl = TRUE)
}

#' Zeilenanfang maskieren (keine ungewollten Listen: „-“, „+“, „1.“)
#' @noRd
rep_html_esc_start <- function(x) {
  x <- sub("^([-+])", "\\\\\\1", x, perl = TRUE)
  sub("^([0-9]+)([.)])", "\\1\\\\\\2", x, perl = TRUE)
}

#' Ausrichtung einer Tabellenspalte: rechts, wenn sie überwiegend Zahlen enthält
#' @noRd
rep_html_col_align <- function(v) {
  v <- trimws(v)
  v <- v[nzchar(v) & !(v %in% c("\u2013", "-")) & !startsWith(v, fmt_num(NA))]
  if (length(v) == 0L) return("r")
  num <- grepl("^[-+\u2212]?[0-9][0-9.,]*( ?(%|\u20ac|[A-Za-z\u00b2/]+))?$", v)
  if (mean(num) >= 0.6) "r" else "l"
}

#' Zelle einer Tabelle (maskiert; negative Zahlen rot über die Klasse `neg`)
#' @noRd
rep_html_cell <- function(v) {
  e <- rep_html_esc(v)
  neg <- grepl("^-[0-9]", trimws(v))
  e[neg] <- paste0("[", e[neg], "]{.neg}")
  e
}

#' Pipe-Tabelle (Pandoc) aus einem Tabellenblock
#' @noRd
rep_html_md_table <- function(b) {
  m <- b$m
  hdr <- colnames(m) %||% rep("", ncol(m))
  align <- b$align %||% c("l", vapply(seq_len(ncol(m))[-1L], function(j) {
    rep_html_col_align(m[, j])
  }, ""))
  align <- rep_len(align, ncol(m))
  cells <- matrix(rep_html_cell(m), nrow = nrow(m))
  w <- pmin(40L, pmax(3L, vapply(seq_len(ncol(m)), function(j) {
    max(nchar(c(hdr[j], m[, j]), type = "chars"))
  }, integer(1))))
  sep <- vapply(seq_along(w), function(j) {
    d <- strrep("-", w[j])
    switch(align[j], r = paste0(d, ":"), c = paste0(":", d, ":"), paste0(":", d))
  }, "")
  line <- function(v) paste0("| ", paste(v, collapse = " | "), " |")
  out <- c(line(rep_html_esc(hdr)), paste0("|", paste(sep, collapse = "|"), "|"),
           apply(cells, 1L, line))
  if (!is.null(b$caption)) out <- c(out, "", paste0(": ", rep_html_esc(b$caption)))
  if (isTRUE(b$wide)) out <- c("::: {.vofi-wide}", out, ":::")
  if (length(b$note) > 0L) {
    out <- c(out, unlist(lapply(b$note, function(n) c("", rep_html_esc_start(rep_html_esc(n))))))
  }
  out
}

#' Grafik als PNG schreiben (`ggplot2::ggsave()`; Warnungen von ggplot2 werden unterdrückt)
#' @noRd
rep_html_png <- function(plot, file, width, height) {
  withCallingHandlers(
    ggplot2::ggsave(filename = file, plot = plot, device = "png", width = width,
                    height = height, units = "in", dpi = 110, bg = "white"),
    warning = function(w) {
      if (!inherits(w, "vofi_warning")) invokeRestart("muffleWarning")
    }
  )
  invisible(file)
}

#' Markdown eines Blocks
#' @param env Umgebung mit `fig_dir` und Zähler `n_fig`.
#' @noRd
rep_html_md_block <- function(b, env) {
  par <- function(x) rep_html_esc_start(rep_html_esc(x))
  switch(b$type,
    par = c(rbind(par(b$text), "")),
    list = c(paste0("- ", par(b$items)), ""),
    heading = c(paste0(strrep("#", b$level %||% 2L), " ", rep_html_esc(b$text)), ""),
    table = c(rep_html_md_table(b), ""),
    deflist = c(unlist(lapply(b$items, function(it) {
      c(rep_html_esc_start(rep_html_esc(it[1L])), paste0(":   ", rep_html_esc(it[2L])), "")
    })), ""),
    callout = c(paste0("::: {.vofi-callout .vofi-", b$kind, "}"),
                if (!is.null(b$title)) c(paste0("**", rep_html_esc(b$title), "**"), ""),
                if (length(b$text) == 1L) par(b$text) else paste0("- ", par(b$text)),
                ":::", ""),
    ampel = c(paste0("::: {.vofi-ampel .vofi-ampel-", b$level, "}"),
              paste0("**", rep_html_esc(b$title), "**"), "",
              if (length(b$lines) > 0L) paste0("- ", par(b$lines)), ":::", ""),
    plot = rep_html_md_plot(b, env),
    character(0)
  )
}

#' Markdown einer Grafik (PNG-Datei, eingebettet beim Rendern)
#' @noRd
rep_html_md_plot <- function(b, env) {
  env$n_fig <- env$n_fig + 1L
  file <- file.path(env$fig_dir, sprintf("abb_%03d.png", env$n_fig))
  err <- tryCatch({
    rep_html_png(b$fun(), file, b$width, b$height)
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(err)) {
    return(c(paste0("*", rep_html_esc(lbl("report.html.plot_failed", plot = b$caption,
                                          message = err)), "*"), ""))
  }
  c(paste0("![", rep_html_esc(b$caption), "](", file, "){.vofi-abb width=100%}"), "")
}

#' Pandoc-Markdown des ganzen Berichts
#' @param model Berichtsmodell.
#' @param fig_dir Verzeichnis für die Grafiken.
#' @return Zeichenkette (UTF-8).
#' @noRd
rep_html_markdown <- function(model, fig_dir) {
  env <- new.env(parent = emptyenv())
  env$fig_dir <- fig_dir
  env$n_fig <- 0L
  mt <- model$meta
  head <- c("::: {.vofi-kopf}",
            if (!is.null(mt$logo)) c(paste0("![](", mt$logo, "){.vofi-logo}"), ""),
            paste0("[", rep_html_esc(mt$kind_text), "]{.vofi-art}"), "",
            paste0("[", rep_html_esc(mt$title), "]{.vofi-titel}"), "",
            paste0("- ", rep_html_esc_start(rep_html_esc(mt$lines))), "", ":::", "",
            "::: {.vofi-callout .vofi-pretax}", rep_html_esc_start(rep_html_esc(mt$pretax)),
            ":::", "")
  body <- character(0)
  for (sec in model$sections) {
    body <- c(body, paste0("# ", rep_html_esc(sec$title), " {#vofi-", gsub("_", "-", sec$id),
                           "}"), "")
    for (b in sec$blocks) body <- c(body, rep_html_md_block(b, env))
  }
  enc2utf8(paste(c(head, body, ""), collapse = "\n"))
}

#' Klassen des umschließenden Elements (Vorlage und Modus, für den Stil)
#' @noRd
rep_html_body_class <- function(model) {
  paste0("vofi-bericht vofi-art-", model$meta$kind, " vofi-modus-", model$meta$mode)
}

# ---------------------------------------------------------------------------------------------
# Rendern
# ---------------------------------------------------------------------------------------------

#' UTF-8-Zeichentyp für das Rendern sicherstellen (wird beim Verlassen wiederhergestellt)
#'
#' knitr und rmarkdown verarbeiten UTF-8-Texte nur in einem UTF-8-Gebietsschema verlustfrei;
#' unter `LANG=C` wird `LC_CTYPE` vorübergehend auf `C.UTF-8` (bzw. `en_US.UTF-8`) gesetzt.
#' @return bisheriger Wert von `LC_CTYPE` bzw. `NULL` (keine Änderung).
#' @noRd
rep_html_utf8_locale <- function() {
  if (isTRUE(l10n_info()[["UTF-8"]])) return(NULL)
  old <- Sys.getlocale("LC_CTYPE")
  for (loc in c("C.UTF-8", "en_US.UTF-8", "de_DE.UTF-8")) {
    ok <- suppressWarnings(Sys.setlocale("LC_CTYPE", loc))
    if (nzchar(ok)) return(old)
  }
  NULL
}

#' Ausgabeformat (HTML; DOCX technisch vorbereitet, Freigabe v1.1)
#' @noRd
rep_html_output_format <- function(format, css, meta_file, model, dir) {
  full <- identical(model$meta$kind, "bericht")
  args <- c("--metadata-file", meta_file)
  # Der Bericht enthaelt keine Formeln: maskierte Klammern (\\[ ... \\]) und Dollarzeichen sind
  # Text, keine TeX-Mathematik
  ext <- "-tex_math_single_backslash-tex_math_dollars"
  if (identical(format, "docx")) {
    return(rmarkdown::word_document(toc = full, toc_depth = 1L, number_sections = FALSE,
                                    md_extensions = ext, pandoc_args = args))
  }
  before <- file.path(dir, "vofi_vor.html")
  after <- file.path(dir, "vofi_nach.html")
  writeLines(paste0("<div class=\"", rep_html_body_class(model), "\">"), before)
  writeLines("</div>", after)
  rmarkdown::html_document(toc = full, toc_depth = 1L,
                           number_sections = full && identical(model$meta$mode, "expert"),
                           self_contained = TRUE, theme = NULL, highlight = NULL, mathjax = NULL,
                           css = css, section_divs = TRUE, anchor_sections = FALSE,
                           md_extensions = ext,
                           includes = rmarkdown::includes(before_body = before,
                                                          after_body = after),
                           pandoc_args = args)
}

#' Deklarierte Parameter einer Rmd-Vorlage
#' @noRd
rep_html_template_params <- function(rmd) {
  fm <- tryCatch(rmarkdown::yaml_front_matter(rmd), error = function(e) list())
  list(params = names(fm$params %||% list()), output = !is.null(fm$output))
}

#' Bericht rendern
#' @param model Berichtsmodell.
#' @param path Zieldatei (normalisiert).
#' @param format `"html"` (bzw. intern `"docx"`).
#' @param opts Vorlagenparameter.
#' @return Pfad der erzeugten Datei.
#' @noRd
rep_html_render <- function(model, path, format = "html", opts = list()) {
  tmp <- tempfile("vofi_bericht_")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  old <- rep_html_utf8_locale()
  if (!is.null(old)) on.exit(Sys.setlocale("LC_CTYPE", old), add = TRUE)
  fig_dir <- file.path(tmp, "abb")
  dir.create(fig_dir)
  body <- rep_html_markdown(model, fig_dir)
  tpl_dir <- system.file("templates", "report", package = "vofi")
  src <- opts$file %||% file.path(tpl_dir, "vofi_bericht.Rmd")
  rmd <- file.path(tmp, if (is.null(opts$file)) "vofi_bericht.Rmd" else basename(src))
  file.copy(src, rmd, overwrite = TRUE)
  css <- file.path(tmp, "vofi_bericht.css")
  file.copy(opts$css %||% file.path(tpl_dir, "vofi_bericht.css"), css, overwrite = TRUE)
  meta_file <- file.path(tmp, "vofi_meta.yaml")
  meta <- yaml::as.yaml(list(pagetitle = rep_html_esc_meta(model$meta$title), lang = "de"))
  writeBin(charToRaw(enc2utf8(meta)), meta_file)
  tp <- rep_html_template_params(rmd)
  params <- list(body = body, report = model, x = model$x)
  params <- params[names(params) %in% tp$params]
  fmt <- if (!is.null(opts$file) && tp$output) NULL else
    rep_html_output_format(format, css, meta_file, model, tmp)
  # eigene Vorlagen: R-Code relativ zum Verzeichnis der Vorlage
  root <- if (is.null(opts$file)) tmp else dirname(opts$file)
  if (file.exists(path)) unlink(path)
  err <- tryCatch({
    rmarkdown::render(rmd, output_format = fmt, output_file = basename(path),
                      output_dir = dirname(path), intermediates_dir = tmp, knit_root_dir = root,
                      params = params, envir = new.env(parent = globalenv()), quiet = TRUE)
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(err) || !file.exists(path)) {
    vofi_abort("report.html.errors.render", path = path, message = err %||% "",
               .class = "vofi_error_input")
  }
  normalizePath(path)
}
