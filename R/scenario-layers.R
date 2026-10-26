# Schichten, Deep-Merge, Expander-Aufruf (WS-A, Spec 00 Abschnitte 4.7-4.12, 6.4).
# Phase-0-Minimalfassung, Eigentuemer: WS-A. Umgesetzt: Schichten 0 (Typ-Defaults), 1/2 als
# interne Rueckfallwerte (scn_layer_defaults(), bis global.yaml und die Profile vorliegen),
# 5 (Szenario), 6 (Overlay bleibt in spec$stochastic, wirkt nur in MC-Laeufen), 7 (Varianten,
# Szenario-Sets ohne Platzhalter "*"), 8 (Overrides); knotenbewusstes Mischen; abgeleitete
# Projekt-Defaults als Ableitungsregeln (rule:tax_regime, rule:dates, rule:price_base_year) vor
# den item_defaults optionaler Bloecke (nur bei vorhandenem Block, R-85); Expander in
# order-Reihenfolge; Herkunft je Blatt.
# Offen fuer WS-A: Schichten 1-4 aus Dateien (global.yaml, Profile, Bibliothek, Rechtsstand),
# Platzhalter "*" in Szenario-Sets, Build-Kontext scn_bctx() fuer Expander.

#' Variante auflösen
#'
#' Löst eine Variante auf: Schichten 0–8 mischen, Bibliotheksverweise auflösen, Varianten und
#' Szenario-Sets anwenden, Expander ausführen (Spec 00, Abschnitte 4.7–4.12).
#'
#' Phase-0-Minimalfassung (Eigentümer: WS-A): Bibliotheksverweise (`from:`) und die Dateien der
#' Schichten 1–4 werden in Welle 2 ergänzt; bis dahin gelten interne Rückfallwerte.
#'
#' @param scenario Objekt der Klasse `vofi_scenario`.
#' @param variant Variante (Default `"base"`).
#' @param overrides optional: Laufzeit-Overrides (Schicht 8) als verschachtelte Liste.
#' @param scenario_set optional: Name eines Szenario-Sets.
#' @return Objekt der Klasse `vofi_spec`.
#' @family Einlesen
#' @examples
#' spec <- vofi_resolve(vofi_read_scenario(vofi_example("skeleton")))
#' spec$project$tax_regime
#' @export
vofi_resolve <- function(scenario, variant = "base", overrides = NULL, scenario_set = NULL) {
  if (!inherits(scenario, "vofi_scenario")) {
    vofi_abort("io.not_scenario", arg = "scenario", .class = "vofi_error_input")
  }
  if (!utl_is_string(variant)) {
    vofi_abort("core.arg_scalar", arg = "variant", .class = "vofi_error_input")
  }
  sc <- unclass(scenario)
  attr(sc, "source") <- NULL
  attr(sc, "provenance") <- NULL
  variants <- sc$variants %||% list()
  sets <- sc$scenario_sets %||% list()
  x <- sc[setdiff(names(sc), c("variants", "scenario_sets"))]
  layers <- c()
  types <- c()
  entries <- c()
  persp <- x$project$perspective
  defaults <- scn_normalize(scn_layer_defaults(persp))
  prof_paths <- scn_profile_fallback_paths()
  for (p in scn_leaves(defaults)) {
    if (p %in% prof_paths && utl_is_string(persp)) {
      layers[p] <- 2L
      types[p] <- "profile"
      entries[p] <- persp
    } else {
      layers[p] <- 1L
      types[p] <- "global"
      entries[p] <- "global"
    }
  }
  x <- scn_merge(defaults, x)
  for (p in scn_leaves(sc[setdiff(names(sc), c("variants", "scenario_sets"))])) {
    layers[p] <- 5L
    types[p] <- "scenario"
  }
  if (!identical(variant, "base")) {
    if (is.null(variants[[variant]])) {
      vofi_abort("io.variant_unknown", variant = variant,
                 suggestion = utl_suggest_text(variant, c("base", names(variants))),
                 .class = "vofi_error_validation")
    }
    applied <- var_apply_chain(x, variants, variant)
    x <- applied$x
    for (p in applied$paths) {
      layers[p] <- 7L
      types[p] <- "variant"
    }
  }
  if (!is.null(scenario_set)) {
    set <- sets[[scenario_set]]
    if (is.null(set)) {
      vofi_abort("io.scenario_set_unknown", set = scenario_set,
                 suggestion = utl_suggest_text(scenario_set, names(sets)),
                 .class = "vofi_error_validation")
    }
    applied <- var_apply_ops(x, set, scenario_set, is_set = TRUE)
    x <- applied$x
    for (p in applied$paths) {
      layers[p] <- 7L
      types[p] <- "scenario_set"
    }
  }
  if (!is.null(overrides)) {
    overrides <- scn_overrides_tree(overrides)
    x <- scn_merge(x, overrides)
    for (p in scn_leaves(overrides)) {
      layers[p] <- 8L
      types[p] <- "override"
    }
  }
  scn_check_library(x)
  x <- scn_normalize(x)
  x$project <- scn_project_defaults(x$project)
  for (p in names(attr(x$project, "derived"))) {
    layers[p] <- 0L
    types[p] <- "type_default"
    entries[p] <- attr(x$project, "derived")[[p]]
  }
  attr(x$project, "derived") <- NULL
  x <- scn_apply_item_defaults(x)
  item_paths <- attr(x, "item_paths")
  attr(x, "item_paths") <- NULL
  for (p in names(item_paths)) {
    layers[p] <- 1L
    types[p] <- "global"
    entries[p] <- paste0("global#item_defaults.", item_paths[[p]])
  }
  x <- scn_type_defaults(x, layers, types)
  defaults_added <- attr(x, "defaults_added")
  attr(x, "defaults_added") <- NULL
  for (p in defaults_added) {
    layers[p] <- 0L
    types[p] <- "type_default"
  }
  x <- scn_run_expanders(x)
  x$registers <- list(assets = list(), measures = list())
  x$legal <- list()
  x$variant <- variant
  x$scenario_set <- scenario_set
  src <- attr(scenario, "source")
  file <- if (utl_is_string(src$path)) basename(src$path) else NA_character_
  # Herkunft (4.8): Rueckfallwerte der Schichten 1-2 stammen aus den internen Defaults
  # ("<intern>", entry = defaults_meta$id), Typ-Defaults und Ableitungsregeln aus keiner Datei;
  # entries/layers fuer spaeter ueberschriebene Pfade gelten nicht mehr
  for (p in names(types)) {
    if (types[[p]] %in% c("scenario", "variant", "scenario_set", "override") &&
        p %in% names(entries)) {
      entries <- entries[names(entries) != p]
    }
  }
  files <- vapply(types, function(ty) {
    switch(ty, global = , profile = "<intern>", type_default = , override = NA_character_,
           file)
  }, "")
  spec <- new_vofi_spec(x, provenance = scn_provenance(
    x[setdiff(names(x), c("registers", "legal", "variant", "scenario_set", "library"))],
    layer = layers, source_type = types, file = file, files = files, variant = variant,
    entry = entries
  ))
  attr(spec, "defaults_meta") <- scn_defaults_meta(persp)
  spec
}

#' Pfade der Rückfallwerte, die perspektivabhängig sind (Schicht 2, Profil; R-76)
#' @noRd
scn_profile_fallback_paths <- function() {
  c("accounts.overdraft_limit_eur", "accounts.deficit_order")
}

#' `defaults_meta` der internen Rückfallwerte (4.7 Nr. 1, 13.1 `meta$defaults`, R-85)
#'
#' Phase 0: Die Werte aus [scn_layer_defaults()] stehen für `global.yaml` und das Profil der
#' Perspektive, bis WS-A die Dateien liefert; dann tritt deren `defaults_meta` an diese Stelle.
#' @param perspective Perspektive bzw. `NULL`.
#' @return Liste `global` (und `profile`, wenn die Perspektive bekannt ist).
#' @noRd
scn_defaults_meta <- function(perspective = NULL) {
  one <- function(kind, id) {
    list(kind = kind, id = id, schema_version = 1L, as_of = as.Date(NA), quality = NA_character_,
         source = "vofi:scn_layer_defaults", note = NA_character_)
  }
  out <- list(global = one("global", "global"))
  if (utl_is_string(perspective)) out$profile <- one("profile", perspective)
  out
}

#' Knotenbewusstes Mischen zweier Schichten (4.7)
#'
#' Wie [deep_merge()], zusätzlich gelten normalisierte Knoten (`list(kind = ...)`) und
#' Wertformen auf der Override-Seite als Blätter; eine Teil-Map ohne Wertform (z. B.
#' `{fill: zero}`, `{scale: 2}`) wird in einen Basisknoten gemischt.
#' @noRd
scn_merge <- function(base, override, path = "") {
  if (node_is(override) || io_is_raw_num(override)) return(override)
  if (!is_map(base) || !is_map(override)) return(override)
  if (is_value_form(override, path, kind_of = scn_kind_of)) return(override)
  if (utl_has_name(override, ".replace")) {
    replace <- override[[".replace"]]
    override[[".replace"]] <- NULL
    if (isTRUE(replace)) return(override)
  }
  for (nm in names(override)) {
    if (is.null(override[[nm]])) {
      if (utl_has_name(base, nm)) base[[nm]] <- NULL
    } else {
      child <- if (utl_has_name(base, nm)) base[[nm]] else NULL
      base[nm] <- list(scn_merge(child, override[[nm]], path_join(path, nm)))
    }
  }
  base
}

#' Interne Rückfallwerte der Schichten 1 und 2 (Phase 0)
#'
#' Ersetzt `inst/extdata/defaults/global.yaml` und die Perspektiven-Profile, bis WS-A sie nach
#' Spec 01 liefert. Werte = Rückfallwerte aus Spec 01 Teil A, Abschnitt 2.2 ohne
#' Bibliotheksverweise (Kontozinsen als Konstanten der Anker, Konzept A2).
#' @param perspective Perspektive (für die Engpass-Policy, R-20).
#' @return Rohform (Liste wie YAML).
#' @noRd
scn_layer_defaults <- function(perspective = NULL) {
  wu <- utl_is_string(perspective) && startsWith(perspective, "wu_")
  list(
    project = list(comparison_mode = "absolute", horizon_years = 30L,
                   pending_reforms = character(0), construction_delay_months = 0,
                   reference_variant = "base", report_mode = "auto"),
    grid = list(construction_months = 0L, construction_step_months = 12L,
                operation_step_months = 12L, operation_alignment = "calendar"),
    accounts = list(
      deposit_rate_pa = 0.025, overdraft_rate_pa = 0.06,
      overdraft_limit_eur = if (wu) Inf else 0, penalty_spread_pa = 0.02,
      min_liquidity_eur = 0, deposit_withholding_tax_share = 0,
      deposit_tax_allowance_eur_pa = 0, overdraft_flag_threshold_eur = Inf,
      surplus_order = c("od_repay", "dep_fill_reserve", "dep_invest"),
      deficit_order = if (wu) c("dep_withdraw", "od_draw", "dep_use_reserve", "penalty_rate")
      else c("dep_withdraw", "od_draw", "dep_use_reserve", "equity_call"),
      prepay = list(buffer_eur = 0, min_spread_pa = 0)
    ),
    residual_value = list(method = "zero", sale_cost_share = 0.03),
    tax = list(module = "none", params = list()),
    analysis = list(kpis = "default", primary_kpi = "auto", allow_opportunity_reference = FALSE,
                    deterministic_point = "mode")
  )
}

#' Interne Rückfallwerte der `item_defaults` (Phase 0, 4.7 Nr. 3)
#'
#' Ersetzt `global.yaml#item_defaults`, bis WS-A sie nach Spec 01 liefert. Vorlagen optionaler
#' Blöcke gelten nur, wenn der Block existiert (R-85, Phase-0-Nacharbeit P0-09).
#' @return Map Pfad -> Vorlage (Rohform).
#' @noRd
scn_item_defaults <- function() {
  list("building" = list(building_id = "b1"))
}

#' `item_defaults` anwenden (nach den Ableitungsregeln, vor den Expandern; 4.7 Nr. 3)
#'
#' Phase 0: nur optionale Blöcke der obersten Ebene (vorhandener Block gewinnt). Ein Block
#' "existiert", wenn er nicht leer ist (`new_vofi_scenario()` legt alle Blöcke leer an).
#' @param x normalisierte Spezifikation.
#' @return `x` mit Attribut `"item_paths"` (benannter Vektor Blattpfad -> Vorlagenpfad).
#' @noRd
scn_apply_item_defaults <- function(x) {
  tpl <- scn_item_defaults()
  added <- character(0)
  for (b in names(tpl)) {
    if (!is_map(x[[b]]) || length(x[[b]]) == 0L) next
    d <- scn_normalize(tpl[b])[[b]]
    have <- scn_leaves(x[b])
    new <- setdiff(scn_leaves(stats::setNames(list(d), b)), have)
    added <- c(added, stats::setNames(rep(b, length(new)), new))
    x[[b]] <- scn_merge(d, x[[b]], b)
  }
  attr(x, "item_paths") <- added
  x
}

#' Abgeleitete Projekt-Defaults (Ableitungsregeln, 4.3.2, 4.7, R-86)
#'
#' Setzt nur fehlende Blätter; das Attribut `"derived"` nennt je gesetztem Pfad die Regel
#' (`rule:tax_regime`, `rule:dates`, `rule:price_base_year`) für die Herkunft.
#' @noRd
scn_project_defaults <- function(p) {
  if (is.null(p)) return(p)
  vd <- p$valuation_date
  rules <- list(
    tax_regime = list("rule:tax_regime", if (utl_is_string(p$perspective)) {
      vocab("tax_regime")$from_perspective[[p$perspective]]
    }),
    application_date = list("rule:dates", if (inherits(vd, "Date")) vd),
    legal_state = list("rule:dates", if (inherits(vd, "Date")) vd),
    price_base_year = list("rule:price_base_year", if (inherits(vd, "Date")) utl_year(vd) - 1L)
  )
  derived <- character(0)
  for (f in names(rules)) {
    if (is.null(p[[f]]) && !is.null(rules[[f]][[2L]])) {
      p[[f]] <- rules[[f]][[2L]]
      derived[[paste0("project.", f)]] <- rules[[f]][[1L]]
    }
  }
  p$pending_reforms <- p$pending_reforms %||% character(0)
  if (is.null(p$construction_delay_months)) p$construction_delay_months <- node_const(0)
  attr(p, "derived") <- derived
  p
}

#' Typ-Defaults (Schicht 0) in Komponenten und Finanzierungsbausteine einsetzen
#' @return Liste mit Attribut `"defaults_added"` (Pfade).
#' @noRd
scn_type_defaults <- function(x, layers, types) {
  added <- character(0)
  for (coll in c("components", "financing")) {
    for (id in names(x[[coll]])) {
      comp <- x[[coll]][[id]]
      def <- scn_type_def(comp[["type"]], coll)
      if (is.null(def)) next
      for (p in names(def$params)) {
        pp <- def$params[[p]]
        if (is.null(comp[[p]]) && !is.null(pp$default)) {
          comp[p] <- list(node_normalize(pp$default, pp, path_join(coll, id, p)))
          added <- c(added, path_join(coll, id, p))
        }
      }
      for (f in c("label", "description", "origin", "asset_id", "measure_id", "funding_id",
                  "program")) {
        if (!utl_has_name(comp, f)) comp[f] <- list(NULL)
      }
      comp$origin <- comp$origin %||% "scenario"
      comp$after <- comp$after %||% character(0)
      x[[coll]][[id]] <- comp
    }
  }
  attr(x, "defaults_added") <- added
  x
}

#' Art eines Pfads für die Erkennung von Wertformen (4.7 Nr. 1)
#'
#' Oberste Blöcke und Einträge der Sammlungen (z. B. `components.<id>`) sind nie Wertformen,
#' auch wenn sie Schlüssel wie `from` (Termin von `recurring`) tragen.
#' @return `"map"` bzw. `NA_character_` (strukturelle Prüfung).
#' @noRd
scn_kind_of <- function(path) {
  if (length(path_split(path)) == 1L) return("map")
  utl_default_kind_of(path)
}

#' Ist `x` ein Bibliotheksverweis `{from: <id>, ...}` (id mit Schrägstrich, 4.9)?
#' @noRd
scn_is_library_ref <- function(x) {
  is_map(x) && !node_is(x) && utl_is_string(x[["from"]]) && grepl("/", x[["from"]], fixed = TRUE)
}

#' Bibliotheksverweise sind in Phase 0 noch nicht auflösbar (Schicht 3, WS-A)
#' @noRd
scn_check_library <- function(x, path = "") {
  if (is_map(x) && length(x) > 0L && !node_is(x)) {
    if (scn_is_library_ref(x)) scn_unsupported(paste0("from: (", path, ")"))
    for (nm in names(x)) scn_check_library(x[[nm]], path_join(path, nm))
  }
  invisible(TRUE)
}

#' Expander in order-Reihenfolge ausführen (4.12)
#' @noRd
scn_run_expanders <- function(x) {
  ex <- reg_list("expander")
  if (nrow(ex) == 0L) return(x)
  defs <- lapply(ex$name, function(nm) reg_get("expander", nm))
  defs <- defs[order(vapply(defs, function(d) as.double(d$order), double(1)))]
  for (d in defs) {
    if (is.null(x[[d$block]]) || length(x[[d$block]]) == 0L) next
    scn_unsupported(paste0("expander:", d$name))
  }
  x
}

#' Overrides (Schicht 8) in Baumform bringen
#'
#' Zulässig sind die Baumform (`list(financing = list(bank = list(start = 2028)))`) und die
#' Pfadform (`list("financing.bank.start" = 2028)`, wie `set` einer Variante, 4.11); beide dürfen
#' gemischt werden, Pfadschlüssel werden nach der Baumform in Listenreihenfolge gemischt. `NULL`
#' (YAML `~`) entfernt das Blatt.
#' @param overrides benannte Liste.
#' @return Overrides in Baumform.
#' @noRd
scn_overrides_tree <- function(overrides) {
  if (!is_map(overrides)) {
    vofi_abort("io.not_map", path = "overrides", .class = "vofi_error_input")
  }
  dotted <- grepl(".", names(overrides), fixed = TRUE)
  if (!any(dotted)) return(overrides)
  insert <- function(tree, segs, value) {
    seg <- segs[1L]
    if (length(segs) == 1L) {
      tree[seg] <- list(value)                      # NULL bleibt als Loeschanweisung erhalten
      return(tree)
    }
    child <- if (utl_has_name(tree, seg) && is_map(tree[[seg]])) tree[[seg]] else list()
    tree[seg] <- list(insert(child, segs[-1L], value))
    tree
  }
  tree <- overrides[!dotted]
  for (i in which(dotted)) {
    tree <- insert(tree, path_split(names(overrides)[i]), overrides[[i]])
  }
  tree
}

#' Overrides (Schicht 8) auf eine Spezifikation anwenden
#' @noRd
scn_apply_overrides <- function(spec, overrides) {
  prov <- attr(spec, "provenance")
  dmeta <- attr(spec, "defaults_meta")
  x <- unclass(spec)
  attr(x, "provenance") <- NULL
  attr(x, "defaults_meta") <- NULL
  x <- scn_normalize(scn_merge(x, scn_overrides_tree(overrides)))
  x <- scn_type_defaults(x, NULL, NULL)
  attr(x, "defaults_added") <- NULL
  out <- new_vofi_spec(x, provenance = prov)
  attr(out, "defaults_meta") <- dmeta
  out
}
