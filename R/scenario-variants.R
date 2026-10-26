# Varianten und Szenario-Sets (WS-A, Spec 00 Abschnitt 4.11; Spec 01 Teil C 4.1, 4.2).
# extends-Kette (Zyklus = Fehler), Operationen remove -> replace -> set -> overrides -> add mit
# Existenzpruefungen (set/overrides auch auf Vorlagen- und Regelfelder, R-112), Bibliotheks-
# verweise in den Operationen (R-87, Schicht 7 mit entry), Overlay-Eintraege in Varianten
# (R-96), Overlay-Bindung bei deterministischem set/replace (4.7), Szenario-Sets aus global.yaml,
# Profil und Szenario mit Pfadbeschraenkung, genau einem Platzhalter "*" je Pfad, Pruefung der
# Wachstumsform (validation.scenario_set.growth_form_required) und generiertem Set
# "vorsichtig" (WS-G, cmp_cautious()).

#' Varianten eines Szenarios
#'
#' Listet die Basis und alle Varianten mit Bezeichnung, Elternvariante und Beschreibung
#' (Spec 00, Abschnitt 4.11). Die Basis `base` ist implizit vorhanden und hat keine Operationen.
#'
#' @param scenario Objekt der Klasse `vofi_scenario`.
#' @return Data Frame mit den Spalten `variant`, `label`, `extends`, `description`.
#' @family Einlesen
#' @examples
#' vofi_variants(vofi_read_scenario(vofi_example("skeleton")))
#' @export
vofi_variants <- function(scenario) {
  if (!inherits(scenario, "vofi_scenario")) {
    vofi_abort("io.not_scenario", arg = "scenario", .class = "vofi_error_input")
  }
  v <- scenario$variants %||% list()
  chr <- function(f, default = NA_character_) {
    vapply(v, function(e) as.character(e[[f]] %||% default)[1L], "", USE.NAMES = FALSE)
  }
  data.frame(
    variant = c("base", names(v)),
    label = c(lbl("io.variant_base_label"), chr("label")),
    extends = c(NA_character_, chr("extends", "base")),
    description = c(NA_character_, chr("description")),
    stringsAsFactors = FALSE
  )
}

#' extends-Kette einer Variante (Wurzel zuerst)
#' @param variants Map der Varianten.
#' @param variant Name.
#' @return Zeichenvektor der anzuwendenden Varianten (leer für `base`).
#' @noRd
var_chain <- function(variants, variant) {
  if (identical(variant, "base")) return(character(0))
  if (is.null(variants[[variant]])) {
    vofi_abort("io.variant_unknown", variant = variant,
               suggestion = utl_suggest_text(variant, c("base", names(variants))),
               .class = "vofi_error_validation")
  }
  chain <- character(0)
  v <- variant
  while (!identical(v, "base")) {
    if (v %in% chain) {
      vofi_abort("io.variant_cycle", chain = utl_collapse(c(rev(chain), v), " -> "),
                 .class = "vofi_error_validation")
    }
    if (is.null(variants[[v]])) {
      vofi_abort("io.variant_unknown", variant = v,
                 suggestion = utl_suggest_text(v, c("base", names(variants))),
                 .class = "vofi_error_validation")
    }
    chain <- c(chain, v)
    v <- as.character(variants[[v]]$extends %||% "base")[1L]
  }
  rev(chain)
}

#' Operationen einer Variante bzw. eines Szenario-Sets anwenden (4.11)
#'
#' Reihenfolge `remove` -> `replace` -> `set` -> `overrides` -> `add`. Existenzprüfung:
#' `replace`, `remove` und das Entfernen mit `~` in `overrides` verlangen einen existierenden
#' Pfad; für `set` und `overrides` gilt ein Pfad auch dann als vorhanden, wenn sein Elternelement
#' existiert und das Blatt ein Feld der Feldtabellen, einer Ableitungsregel oder der
#' `item_defaults`-Vorlage ist (`var_path_known()`, R-112). Bibliotheksverweise `from:` in den
#' Werten werden vor dem Einsetzen nach den Regeln von Schicht 3 aufgelöst (R-87; Herkunft
#' Schicht 7 mit `entry`). In Set-Pfaden steht höchstens ein Segment `*` (alle ids der
#' Sammlung); die Existenzprüfung gilt je Treffer, kein Treffer ergibt einen Hinweis.
#' @param x Spezifikation (Schicht 7).
#' @param ops Operationen (`set`, `replace`, `add`, `remove`, `overrides`).
#' @param name Name der Variante bzw. des Sets.
#' @param is_set Szenario-Set?
#' @param ctx `NULL` oder Kontext von `vofi_resolve()` (Bibliothek, Herkunft, Vorlagen).
#' @return `list(x, bound, keys)`: Spezifikation, deterministisch gesetzte Pfade (`set`,
#'   `replace`, `overrides`) und die von den Operationen berührten Overlay-Schlüssel.
#' @noRd
var_apply_ops <- function(x, ops, name, is_set = FALSE, ctx = NULL) {
  ops <- ops %||% list()
  unknown <- setdiff(names(ops), var_op_keys(is_set))
  if (length(unknown) > 0L) {
    vofi_abort(if (is_set) "io.scenario_set_key_unknown" else "io.variant_key_unknown",
               name = name, keys = utl_collapse(unknown),
               suggestion = utl_suggest_text(unknown[1L], var_op_keys(is_set)),
               .class = "vofi_error_validation")
  }
  op_name <- if (is_set) "scenario_set" else "variant"
  bound <- character(0)
  touched <- character(0)
  expand <- function(p, op) {
    if (is_set) var_check_set_path(p, name)
    hits <- var_expand_path(x, p, name, is_set)
    if (length(hits) == 0L) {
      vofi_inform("io.scenario_set_no_match", set = name, path = p)
    }
    hits
  }
  check <- function(p, op, relaxed) {
    known <- if (relaxed) var_path_known(x, p, ctx) else path_exists(x, p)
    if (!known) {
      vofi_abort(scn_key("validation.variant.path_missing", "io.variant_path_missing",
                         variant = name, op = op, path = p),
                 variant = name, op = op, path = p, .class = "vofi_error_validation")
    }
  }
  value_of <- function(v, p) var_resolve_value(v, p, ctx, name, op_name)
  for (p0 in as.character(unlist(ops$remove))) {
    for (p in expand(p0, "remove")) {
      check(p, "remove", FALSE)
      x <- path_remove(x, p)
      touched <- c(touched, var_overlay_key(p))
    }
  }
  for (p0 in names(ops$replace)) {
    for (p in expand(p0, "replace")) {
      check(p, "replace", FALSE)
      v <- value_of(ops$replace[[p0]], p)
      x <- path_set(x, p, v)
      var_record(ctx, ops$replace[[p0]], p, name, op_name)
      bound <- c(bound, p)
      touched <- c(touched, var_overlay_key(p), var_dist_keys(v, p))
    }
  }
  for (p0 in names(ops$set)) {
    for (p in expand(p0, "set")) {
      check(p, "set", TRUE)
      v <- value_of(ops$set[[p0]], p)
      old <- path_get(x, p)
      if (is_set) var_check_growth_form(old, v, p, name)
      x <- path_set(x, p, if (is.null(old)) v else scn_merge(old, v, p))
      var_record(ctx, ops$set[[p0]], p, name, op_name)
      bound <- c(bound, p)
      touched <- c(touched, var_overlay_key(p), var_dist_keys(v, p))
    }
  }
  if (!is.null(ops$overrides)) {
    tree <- scn_overrides_tree(ops$overrides)
    for (p0 in var_override_leaves(tree)) {
      v0 <- path_get(tree, p0)
      for (p in expand(p0, "overrides")) {
        if (is.null(v0)) {
          check(p, "overrides", FALSE)
          x <- path_remove(x, p)
        } else {
          check(p, "overrides", TRUE)
          v <- value_of(v0, p)
          old <- path_get(x, p)
          if (is_set) var_check_growth_form(old, v, p, name)
          x <- path_set(x, p, if (is.null(old)) v else scn_merge(old, v, p))
          var_record(ctx, v0, p, name, op_name)
          bound <- c(bound, p)
          touched <- c(touched, var_dist_keys(v, p))
        }
        touched <- c(touched, var_overlay_key(p))
      }
    }
  }
  for (p0 in names(ops$add)) {
    for (p in expand(p0, "add")) {
      if (path_exists(x, p)) {
        vofi_abort("io.variant_path_exists", variant = name, path = p,
                   .class = "vofi_error_validation")
      }
      v <- value_of(ops$add[[p0]], p)
      x <- path_set(x, p, v)
      var_record(ctx, ops$add[[p0]], p, name, op_name)
      touched <- c(touched, var_overlay_key(p), var_dist_keys(v, p))
    }
  }
  list(x = x, bound = unique(bound), keys = unique(touched[!is.na(touched)]))
}

#' Zulässige Schlüssel einer Variante bzw. eines Sets (4.11; Spec 01 Teil C 4.1)
#' @noRd
var_op_keys <- function(is_set) {
  ops <- c("label", "description", "set", "replace", "add", "remove", "overrides")
  if (is_set) c(ops, "generate") else c(ops, "extends")
}

#' Pfad mit Platzhalter `*` auf die Treffer erweitern (nur Szenario-Sets, 4.11)
#' @return Zeichenvektor der Pfade (ohne Platzhalter: der Pfad selbst).
#' @noRd
var_expand_path <- function(x, p, name, is_set) {
  segs <- path_split(p)
  star <- which(segs == "*")
  if (length(star) == 0L) return(p)
  if (!is_set || length(star) > 1L) {
    vofi_abort("io.scenario_set_wildcard", set = name, path = p,
               .class = "vofi_error_validation")
  }
  prefix <- paste(segs[seq_len(star - 1L)], collapse = ".")
  coll <- if (nzchar(prefix)) path_get(x, prefix) else x
  if (!is_map(coll) || length(coll) == 0L || node_is(coll)) return(character(0))
  rest <- segs[-seq_len(star)]
  vapply(names(coll), function(id) paste(c(segs[seq_len(star - 1L)], id, rest), collapse = "."),
         "", USE.NAMES = FALSE)
}

#' Wert einer Operation: Bibliotheksverweise auflösen (R-87), Herkunft der Nutzlast Schicht 7
#' @noRd
var_resolve_value <- function(v, p, ctx, name, op_name) {
  if (is.null(ctx) || is.null(ctx$lc) || !is.list(v)) return(v)
  lc <- ctx$lc
  old <- list(layer = lc$layer, variant = lc$variant)
  lc$layer <- 7L
  lc$variant <- name
  on.exit({
    lc$layer <- old$layer
    lc$variant <- old$variant
  }, add = TRUE)
  lib_resolve(v, p, lc)
}

#' Herkunft der Blätter einer Operation (Schicht 7, Quelle `variant` bzw. `scenario_set`)
#' @noRd
var_record <- function(ctx, v, p, name, op_name) {
  if (is.null(ctx) || is.null(ctx$prv)) return(invisible(NULL))
  info <- prv_info(7L, op_name, file = ctx$file, variant = name)
  own <- lib_strip_refs(v)
  if (is_map(own) && length(own) == 0L && is_map(v) && utl_has_name(v, "from")) {
    return(invisible(NULL))
  }
  prv_record_tree(ctx$prv, own, p, info)
  invisible(NULL)
}

#' Overlay-Schlüssel eines Pfads unter `stochastic.parameters` bzw. `stochastic.processes`
#' @noRd
var_overlay_key <- function(p) {
  m <- regmatches(p, regexec("^stochastic[.](parameters|processes)[.](.+)$", p))[[1L]]
  if (length(m) == 3L) {
    first <- path_split(m[3L])[1L]
    return(paste0(m[2L], ":", first))
  }
  NA_character_
}

#' Schlüssel der Kurzform-Verteilungen in einem Operationswert (Schlüssel = Zielpfad, 4.5)
#' @noRd
var_dist_keys <- function(v, p) {
  if (is_map(v) && !node_is(v) && identical(utl_value_form_kind(v), "dist")) {
    return(paste0("parameters:", p))
  }
  if (node_is(v) && identical(v$kind, "dist")) return(paste0("parameters:", p))
  if (!is_map(v) || node_is(v)) return(character(0))
  unlist(lapply(names(v), function(nm) var_dist_keys(v[[nm]], path_join(p, nm))),
         use.names = FALSE) %||% character(0)
}

#' Szenario-Set auf eine Wachstumsform: nur `growth` ändern (Spec 01 Teil C 4.1)
#'
#' Eine Set-Map mit `growth`, aber ohne `start`, wird in die Basis-Wertform gemischt; liegt der
#' Basispfad nicht als Wachstumsform vor, ist das `validation.scenario_set.growth_form_required`.
#' @noRd
var_check_growth_form <- function(old, v, p, name) {
  if (!is_map(v) || node_is(v) || !utl_has_name(v, "growth") || utl_has_name(v, "start")) {
    return(invisible(TRUE))
  }
  is_growth <- (node_is(old) && identical(old$kind, "growth")) ||
    (is_map(old) && identical(utl_value_form_kind(old), "growth"))
  if (!is_growth) {
    vofi_abort(scn_key("validation.scenario_set.growth_form_required",
                       "io.scenario_set_growth_form", set = name, path = p),
               set = name, path = p, .class = "vofi_error_validation")
  }
  invisible(TRUE)
}

#' Blattpfade der Baumform `overrides` einschließlich der Löschanweisungen `~` (4.11)
#' @param x Teilbaum.
#' @param path Pfad von `x`.
#' @return Zeichenvektor.
#' @noRd
var_override_leaves <- function(x, path = "") {
  if (is.null(x)) return(if (nzchar(path)) path else character(0))
  if (node_is(x) || !is_map(x) || length(x) == 0L ||
        (nzchar(path) && is_value_form(x, path, kind_of = scn_kind_of))) {
    return(if (nzchar(path)) path else character(0))
  }
  out <- lapply(names(x), function(nm) var_override_leaves(x[[nm]], path_join(path, nm)))
  unlist(out, use.names = FALSE) %||% character(0)
}

#' Gilt ein Pfad für `set`/`overrides` als vorhanden? (4.11, R-112)
#'
#' Vorhanden ist ein existierender Pfad, außerdem ein Pfad, dessen Elternelement vorhanden ist
#' (rekursiv, z. B. ein Teilbaum der Vorlage `item_defaults.building`) und dessen Blatt ein Feld
#' des Elternelements nach `var_template_fields()` ist. Neue Elemente von Sammlungen entstehen
#' so nicht (dafür gibt es `add`).
#' @param x Spezifikation (Schicht 7).
#' @param p Pfad.
#' @param ctx `NULL` oder Kontext von `vofi_resolve()` (Vorlagen `item_defaults`).
#' @return `TRUE`/`FALSE`.
#' @noRd
var_path_known <- function(x, p, ctx = NULL) {
  if (path_exists(x, p)) return(TRUE)
  segs <- path_split(p)
  k <- length(segs)
  if (k < 2L) return(FALSE)
  parent <- paste(segs[-k], collapse = ".")
  parent_ok <- path_exists(x, parent) || var_path_known(x, parent, ctx)
  if (!parent_ok) return(FALSE)
  pv <- path_get(x, parent)
  if (!is.null(pv) && (!is_map(pv) || node_is(pv))) return(FALSE)
  segs[k] %in% var_template_fields(x, parent, ctx)
}

#' Felder eines Elternelements nach Feldtabellen, Ableitungsregeln und Vorlagen (R-112)
#'
#' Vereinigung aus (1) den Typparametern und reservierten Metafeldern von
#' `components.<id>`/`financing.<id>` (auch Felder von map-Parametern), (2) dem Schema der
#' Domänenblöcke (`val_domain_schema()`, Feldtabellen von Spec 01), (3) den Zielfeldern der
#' Ableitungsregeln (`scn_rule_fields()`) und (4) den Vorlagen `item_defaults` aus
#' `global.yaml`. Schlüssel für (2) bis (4) ist der Elternpfad ohne die ids der Sammlungen
#' (z. B. `measures.wp.replacement` -> `measures.replacement`); maßgeblich ist der längste
#' passende Schlüssel, darunter wird über map-Felder bzw. Teilbäume der Vorlage gegangen. Ein
#' Elternpfad, der selbst eine Sammlung ist (z. B. `measures`), hat keine Felder.
#' @param x Spezifikation.
#' @param parent Elternpfad.
#' @param ctx `NULL` oder Kontext von `vofi_resolve()`.
#' @return Zeichenvektor der Feldnamen.
#' @noRd
var_template_fields <- function(x, parent, ctx = NULL) {
  segs <- path_split(parent)
  colls <- utl_merge_collections()
  tpl <- character(0)
  i <- 1L
  while (i <= length(segs)) {
    tpl <- c(tpl, segs[i])
    if (paste(tpl, collapse = ".") %in% colls) {
      if (i == length(segs)) return(character(0))
      i <- i + 1L                                   # id des Sammlungselements ueberspringen
    }
    i <- i + 1L
  }
  walk_params <- function(params, rest) {
    for (seg in rest) {
      pp <- params[[seg]]
      if (!inherits(pp, "vofi_param") || !is.list(pp$fields)) return(character(0))
      params <- pp$fields
    }
    names(params)
  }
  walk_template <- function(node, rest) {
    for (seg in rest) {
      node <- if (utl_has_name(node, seg)) node[[seg]] else NULL
      # Wertformen und Knoten der Vorlage sind Blaetter (strukturelle Pruefung, 4.7)
      if (!is_map(node) || node_is(node) || !is.na(utl_value_form_kind(node))) {
        return(character(0))
      }
    }
    names(node)
  }
  longest <- function(keys) {
    hit <- keys[vapply(keys, function(k) {
      ks <- path_split(k)
      length(ks) <= length(tpl) && identical(ks, tpl[seq_along(ks)])
    }, logical(1))]
    if (length(hit) == 0L) NULL else hit[which.max(nchar(hit))]
  }
  out <- character(0)
  if (length(segs) >= 2L && segs[1L] %in% c("components", "financing")) {
    def <- scn_type_def(path_get(x, path_join(segs[1:2]))[["type"]], segs[1L])
    if (!is.null(def)) {
      out <- c(out, walk_params(def$params, segs[-(1:2)]))
      if (length(segs) == 2L) out <- c(out, reg_reserved_fields())
    }
  }
  schema <- val_domain_schema()
  k <- longest(names(schema))
  if (!is.null(k)) out <- c(out, walk_params(schema[[k]], tpl[-seq_along(path_split(k))]))
  rules <- scn_rule_fields()
  key <- paste(tpl, collapse = ".")
  out <- c(out, rules[[key]] %||% character(0))
  items <- ctx$items %||% scn_item_templates()
  k <- longest(names(items))
  if (!is.null(k)) {
    out <- c(out, walk_template(items[[k]], tpl[-seq_along(path_split(k))]))
  }
  unique(out)
}

#' Zulässige Pfade eines Szenario-Sets (4.11; Spec 01 Teil C 4.1)
#'
#' Nur unter `market`, `funding`, `accounts`, `residual_value`, `stochastic`, `tax` und
#' `project.pending_reforms`; `shared.*` ist `validation.scenario_set.path_forbidden` mit Hinweis
#' auf einen szenarioeigenen `market`-Pfad (R-109, N-21).
#' @noRd
var_check_set_path <- function(p, name) {
  first <- path_split(p)[1L]
  ok <- first %in% c("market", "funding", "accounts", "residual_value", "stochastic", "tax") ||
    identical(p, "project.pending_reforms")
  if (!ok) {
    key <- if (identical(first, "shared")) "io.scenario_set_shared" else "io.scenario_set_path"
    vofi_abort(scn_key("validation.scenario_set.path_forbidden", key, set = name, path = p),
               set = name, path = p, .class = "vofi_error_validation")
  }
  invisible(TRUE)
}

#' Szenario-Sets aus global.yaml, Profil und Szenario (später gewinnt, Mischen nach 4.7)
#' @param defaults Liste der Defaults-Dateien (`scn_defaults_load()`).
#' @param scenario_sets Sets des Szenarios.
#' @return Map der Sets.
#' @noRd
var_scenario_sets <- function(defaults, scenario_sets) {
  out <- list()
  srcs <- c(lapply(defaults, function(d) d$sets), list(scenario_sets))
  for (s in srcs) {
    s <- scn_as_map(s, "scenario_sets")
    for (id in names(s)) {
      out[[id]] <- if (is.null(out[[id]])) s[[id]] else scn_merge(out[[id]], s[[id]])
    }
  }
  out
}

#' Szenario-Set prüfen (statisch oder generiert, Spec 01 Teil C 4.1)
#' @return `invisible(TRUE)`; generierte Sets sind ein Fehler (WS-G erzeugt sie).
#' @noRd
var_check_set <- function(set, name) {
  has_ops <- any(c("set", "replace", "add", "remove", "overrides") %in% names(set))
  if (!is.null(set$generate)) {
    if (has_ops) {
      vofi_abort("io.scenario_set_both", set = name, .class = "vofi_error_validation")
    }
    vofi_abort("io.scenario_set_generated", set = name, .class = "vofi_error_input")
  }
  invisible(TRUE)
}

#' Overlay-Bindung für deterministisch gesetzte Ziele aufheben (4.7)
#'
#' Ein Overlay-Eintrag, dessen Ziel eine Operation `set`/`replace`/`overrides` einer Variante
#' bzw. eines Sets oder ein Override der Schicht 8 deterministisch setzt (Ziel = Pfad, Vorfahre
#' oder Nachfahre des Pfads), entfällt für den Lauf (Hinweis), sofern dieselbe Operation den
#' Eintrag nicht selbst neu setzt.
#' @param x Spezifikation.
#' @param bound gesetzte Pfade.
#' @param keys von der Operation berührte Overlay-Schlüssel (`"parameters:<key>"`).
#' @param source Quelle für die Meldung (Variante, Set bzw. `"overrides"`).
#' @return `x` ohne die gebundenen Einträge.
#' @noRd
var_unbind_overlay <- function(x, bound, keys = character(0), source = "") {
  if (length(bound) == 0L || !is_map(x$stochastic)) return(x)
  for (b in c("parameters", "processes")) {
    entries <- x$stochastic[[b]]
    if (!is_map(entries) || length(entries) == 0L) next
    for (k in names(entries)) {
      if (paste0(b, ":", k) %in% keys) next
      tg <- entries[[k]]$target
      if (!utl_is_string(tg)) next
      hit <- bound[bound == tg | startsWith(tg, paste0(bound, ".")) |
                     startsWith(bound, paste0(tg, "."))]
      if (length(hit) == 0L) next
      x$stochastic[[b]][k] <- list(NULL)
      x$stochastic[[b]] <- x$stochastic[[b]][!vapply(x$stochastic[[b]], is.null, logical(1))]
      vofi_inform("io.overlay_unbound", entry = k, target = tg, source = source)
    }
  }
  x
}
