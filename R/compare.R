# Vergleich von Alternativen (WS-G, Spec 00 Abschnitte 4.11, 9.6, 9.11, 11.10, 12.6, 12.9, 13.3;
# Spec 01 Teil C 4.3, 4.4, 6.6).
# vofi_compare(): Faelle = Varianten (gekreuzt mit statischen Szenario-Sets), je Fall ein Modell
# (bei Entscheidungsknoten samt Ausweichvariante), Vergleichbarkeitspruefung im
# deterministischen Lauf (Stichtag, Horizontende, Konten und Ketten, geplante EK-Zeilen,
# Sacheinlage, Bestandsdarlehen, Restwertmethode, Steuermodul; ungleiche Nachschuesse sind kein
# Befund), Vergleichsregel delta_vs_reference = dEW_A - dEW_ref je Lauf (R-27, R-66) mit den
# Vergleichskennzahlen aus kpi_compare_values() (WS-D2) und prob_better_than_ref, gemeinsame
# Zufallszahlen ueber einen Vereinigungsplan und je Chunk dieselben Rohziehungen fuer alle Faelle
# (11.10), Modus differential (9.6 Nr. 6), Rendite der Mehrinvestition (deterministisch, 12.8),
# Differenz-VoFi (nur bei gleichem Raster), Ampel (cmp_traffic_light(), 12.9), generiertes Set
# "vorsichtig" (cmp_cautious(), 4.11, Teil C 4.3) und Pflichtsensitivitaeten
# (cmp_mandatory_sensitivities(), Teil C 4.4, fuer den Bericht).
# Die Vergleichskennzahlen (12.6) sind keine Registry-Typen (Spec 00 2.4: typedef_kpi_* in
# R/kpi-*.R; Spec 01 Teil A: nicht Teil von analysis.kpis); Einheiten, Restwertbezug und Labels
# kommen aus kpi_compare_specs() und kpi.compare.* (WS-D2), vofi_compare() fuellt sie je Lauf.

#' Varianten vergleichen
#'
#' Vergleicht Varianten als vollständige VoFis mit gemeinsamen Zufallszahlen (Spec 00,
#' Abschnitte 9.6, 9.11, 11.10, 12.6, 12.9). Je Lauf gilt die Vergleichsregel
#' `delta_vs_reference` = ΔEW der Variante − ΔEW der Referenz, jede gegen ihre eigene
#' Unterlassungsalternative mit ihren eigenen Nachschüssen (R-27, R-66); Wahrscheinlichkeiten
#' und Quantile werden je Lauf auf den Differenzen gebildet. Ungleiche Nachschüsse sind kein
#' Vergleichbarkeitsfehler; Stichtag, Horizontende, Konten, geplante Einlagen und Entnahmen,
#' Sacheinlage, Bestandsdarlehen, Restwertmethode und Steuermodul müssen übereinstimmen (sonst
#' Fehler `vofi_error_validation`, mit `allow_unequal = TRUE` Warnung und Befund).
#'
#' Statische Szenario-Sets werden mit jeder Variante gekreuzt (Fall `<variante>@<set>`, Referenz
#' `<baseline>@<set>`); das generierte Set „vorsichtig“ wird je Variante aus einem Tornado der
#' Vergleichskennzahl als Designzeile auf Variante und Referenz gerechnet (Fall
#' `<variante>@vorsichtig`) und geht in die Ampel ein. Varianten mit Entscheidungsknoten der
#' Förderzusage gehen als Kompositum ein, bedingte Ergebnisse stehen in `conditional`.
#'
#' Im Modus `differential` (`project.comparison_mode`, Spec 00 Abschnitt 9.6 Nr. 6) erhält die
#' Variante in jedem Lauf die negierten Zahlungen der Abschnitte `project` und `grants` der
#' Referenz desselben Laufs; das gilt auch für die Design-Läufe des Sets „vorsichtig“, der
#' Rendite der Mehrinvestition, der Pflichtsensitivitäten sowie für `vofi_sensitivity()` und
#' `vofi_solve()` mit Vergleichskennzahlen. `delta_vs_reference` ist dann das ΔEW der Variante
#' selbst (Vermerk „Vereinfachungsmodus Differenzzahlungen“).
#'
#' @param x Objekt der Klasse `vofi_scenario`.
#' @param variants `NULL` (alle) oder Namen der Varianten.
#' @param baseline Referenzvariante (Default `project.reference_variant`, sonst `"base"`).
#' @param scenario_sets optional: Szenario-Sets, die mit den Varianten gekreuzt werden.
#' @param n_sim Anzahl der Läufe (1 = deterministisch).
#' @param seed Seed der Simulation.
#' @param store `"auto"`, `"bands"` oder `"kpi"`.
#' @param allow_unequal Vergleich trotz Vergleichbarkeitsbefunden (mit Warnung).
#' @return Objekt der Klasse `vofi_comparison`.
#' @family Analysieren
#' @examples
#' sc <- vofi_read_scenario(vofi_example("skeleton"))
#' sc$variants <- list(mehr = list(label = "Mehr Miete",
#'                                 set = list("components.z.values" = c(-100000, 31000,
#'                                                                     41000, 51000))))
#' cmp <- vofi_compare(sc, variants = "mehr")
#' cmp$differences$delta_vs_reference
#' @export
vofi_compare <- function(x, variants = NULL, baseline = NULL, scenario_sets = NULL, n_sim = 1L,
                         seed = NULL, store = c("auto", "bands", "kpi"), allow_unequal = FALSE) {
  t0 <- proc.time()[["elapsed"]]
  if (!inherits(x, "vofi_scenario")) {
    vofi_abort("mc.compare.not_scenario", arg = "x", .class = "vofi_error_input")
  }
  store <- utl_match_arg(store, c("auto", "bands", "kpi"), "store")
  n_sim <- utl_check_whole(n_sim, "n_sim", min = 1)
  if (!utl_is_flag(allow_unequal)) mc_abort_flag("allow_unequal")
  if (!is.null(seed)) seed <- utl_check_seed(seed)
  setup <- cmp_setup(x, variants, baseline, scenario_sets)
  models <- lapply(seq_len(nrow(setup$cases)), function(i) {
    cmp_with_qt(cmp_build(x, setup$cases$variant[i], setup$cases$scenario_set[i]))
  })
  names(models) <- setup$cases$case
  det_run <- mc_capture(lapply(models, cmp_det_run))
  dets <- det_run$value
  comp <- cmp_comparability(models, dets, setup$cases, allow_unequal)
  cmp_check_differential(models, setup$cases)
  mode <- if (n_sim > 1L) "mc" else "deterministic"
  out <- if (identical(mode, "mc")) {
    cmp_run_mc(models, dets, setup, n_sim, seed, if (store == "auto") "bands" else store)
  } else {
    cmp_run_det(models, dets, setup)
  }
  conds <- c(det_run$conditions, out$conditions)
  cautious <- NULL
  if (length(setup$generated) > 0L) {
    cz <- mc_capture(cmp_generated_sets(models, dets, setup))
    cautious <- cz$value
    conds <- c(conds, cz$conditions)
    for (nm in names(cautious$results)) out$results[[nm]] <- cautious$results[[nm]]
  }
  # Markierungen je Fall, gleiche Meldungen mehrerer Fälle einmal (9.8)
  fl <- mc_capture(for (cs in names(out$results)) eng_flag_conditions(out$results[[cs]]$flags))
  mc_emit_conditions(c(conds, fl$conditions))
  cmp_assemble(out, models, setup, comp, cautious, mode, n_sim, seed, allow_unequal, t0)
}

# ---------------------------------------------------------------------------------------------
# Fälle, Modelle, Sets
# ---------------------------------------------------------------------------------------------

#' Name der internen Kennzahl q_T (Aufzinsfaktor der Variante, 12.2; WS-D2-09)
#' @noRd
cmp_qt_name <- function() ".cmp_q_t"

#' Modell mit der internen Kennzahl q_T (für die CO2-Vermeidungskosten, 12.6)
#'
#' Die Engine liefert q_T nicht als Rückgabepfad (Änderungsantrag WS-D2-09); WS-G ergänzt dafür
#' eine interne Kennzahl, die aus `core$rates` den Aufzinsfaktor q_T bildet. Sie erscheint in
#' keinem Ergebnis.
#' @noRd
cmp_with_qt <- function(model) {
  if (is.null(model)) return(model)
  def <- kpi_typedef(cmp_qt_name(), function(core, ctx) {
    vofi_kpi_value(kpi_q(core)[, kpi_nt(core)])
  }, unit = "share", higher_is_better = NA, mc_default = FALSE)
  model$kpis[[cmp_qt_name()]] <- def
  if (!is.null(model$decision)) model$decision$fallback <- cmp_with_qt(model$decision$fallback)
  model
}

#' Interne Kennzahl q_T aus einem Modell entfernen (für gespeicherte Modelle, `vofi_sim()`)
#' @noRd
cmp_drop_qt <- function(model) {
  if (is.null(model)) return(model)
  model$kpis[[cmp_qt_name()]] <- NULL
  if (!is.null(model$decision)) model$decision$fallback <- cmp_drop_qt(model$decision$fallback)
  model
}

#' Interne Kennzahl q_T aus einem Chunk-Ergebnis entfernen
#' @noRd
cmp_strip_qt <- function(ch) {
  nm <- cmp_qt_name()
  if (!is.null(ch$kpis[[nm]])) ch$kpis[[nm]] <- NULL
  if (!is.null(ch$kpi_na[[nm]])) ch$kpi_na[[nm]] <- NULL
  ch
}

#' Szenario-Sets aus global.yaml, Profil und Szenario (4.11)
#' @noRd
cmp_set_defs <- function(x) {
  persp <- x$project$perspective
  if (is.list(persp)) persp <- persp$value %||% persp[[1L]]
  var_scenario_sets(scn_defaults_stack(persp), unclass(x)$scenario_sets)
}

#' Fälle des Vergleichs bestimmen (Varianten, Referenz, gekreuzte statische Sets)
#' @return Liste `baseline`, `variants`, `sets` (statisch), `generated` (benannte Liste der
#'   generate-Angaben), `cases` (Data Frame `case`, `variant`, `scenario_set`, `reference`).
#' @noRd
cmp_setup <- function(x, variants = NULL, baseline = NULL, scenario_sets = NULL) {
  all_v <- vofi_variants(x)$variant
  ref <- baseline %||% x$project$reference_variant %||% "base"
  if (is.list(ref)) ref <- ref$value %||% ref[[1L]]
  if (!utl_is_string(ref) || !(ref %in% all_v)) {
    vofi_abort("mc.compare.variant_unknown", variant = utl_collapse(format(ref)),
               suggestion = utl_suggest_text(as.character(ref)[1L], all_v),
               .class = "vofi_error_input")
  }
  vars <- variants %||% setdiff(all_v, ref)
  if (!is.character(vars) || anyNA(vars)) {
    vofi_abort("mc.arg_character", arg = "variants", .class = "vofi_error_input")
  }
  bad <- setdiff(vars, all_v)
  if (length(bad) > 0L) {
    vofi_abort("mc.compare.variant_unknown", variant = utl_collapse(bad),
               suggestion = utl_suggest_text(bad[1L], all_v), .class = "vofi_error_input")
  }
  vars <- unique(setdiff(vars, ref))
  if (length(vars) == 0L) {
    vofi_abort("mc.compare.no_variants", baseline = ref, .class = "vofi_error_input")
  }
  static <- character(0)
  generated <- list()
  if (!is.null(scenario_sets)) {
    if (!is.character(scenario_sets) || anyNA(scenario_sets)) {
      vofi_abort("mc.arg_character", arg = "scenario_sets", .class = "vofi_error_input")
    }
    defs <- cmp_set_defs(x)
    bad <- setdiff(scenario_sets, names(defs))
    if (length(bad) > 0L) {
      vofi_abort("mc.compare.set_unknown", set = utl_collapse(bad),
                 suggestion = utl_suggest_text(bad[1L], names(defs)),
                 .class = "vofi_error_input")
    }
    for (s in unique(scenario_sets)) {
      if (!is.null(defs[[s]]$generate)) generated[[s]] <- defs[[s]]$generate else
        static <- c(static, s)
    }
  }
  all_cases <- c(ref, vars)
  cases <- data.frame(case = all_cases, variant = all_cases, scenario_set = NA_character_,
                      reference = ref, stringsAsFactors = FALSE)
  for (s in static) {
    cases <- rbind(cases, data.frame(case = paste0(all_cases, "@", s), variant = all_cases,
                                     scenario_set = s, reference = paste0(ref, "@", s),
                                     stringsAsFactors = FALSE))
  }
  vt <- vofi_variants(x)
  labels <- stats::setNames(ifelse(is.na(vt$label) | !nzchar(vt$label), vt$variant, vt$label),
                            vt$variant)[all_cases]
  list(baseline = ref, variants = vars, sets = static, generated = generated,
       requested_sets = scenario_sets, cases = cases, labels = labels)
}

#' Modell eines Falls bauen (Variante, optional statisches Set)
#' @noRd
cmp_build <- function(x, variant, scenario_set = NA_character_) {
  vofi_build(x, variant = variant,
             scenario_set = if (is.na(scenario_set)) NULL else scenario_set)
}

#' Rückgabepfade für den Vergleich (9.6 Nr. 3)
#' @noRd
cmp_paths <- function() c("net_position", "opp_net_position", "wealth")

#' Seite eines Vergleichs aus einem Chunk-Ergebnis (für `kpi_compare_values()`)
#' @param with_ref_rows `TRUE`, wenn der Lauf die negierten project-/grants-Zeilen der Referenz
#'   enthält (Modus differential, 9.6 Nr. 6); nur dann ist das eigene ΔEW der Vorteil gegenüber
#'   der Referenz.
#' @noRd
cmp_side <- function(ch, model, with_ref_rows = FALSE) {
  list(kpis = ch$kpis, kpi_na = ch$kpi_na, kpi_series = ch$kpi_series, paths = ch$paths,
       grid = model$grid,
       perspective = model$spec$project$perspective, spec = model$spec,
       q_T = ch$kpis[[cmp_qt_name()]], differential = isTRUE(with_ref_rows))
}

#' Ist das Modell im Modus differential (9.6 Nr. 6)?
#' @noRd
cmp_is_differential <- function(model) {
  identical(model$spec$project$comparison_mode, "differential")
}

#' Neutrale Referenzseite für die Vermögensgrößen im Modus differential
#'
#' Die Variante enthält die negierten Zahlungen der Referenz bereits; ΔEW, Vermögens- und
#' Bestandspfade der Referenz gehen daher mit 0 ein (`delta_vs_reference` = eigenes ΔEW,
#' `payback_vs_reference` aus dem eigenen Vermögensvorteil, `co2_abatement_cost` aus diesem
#' `delta_vs_reference`). Nicht monetäre Vergleichsgrößen (CO2, Belastung, Warmmiete) bleiben
#' die der Referenz.
#' @noRd
cmp_neutral_ref <- function(ref, var) {
  n <- nrow(var$kpis)
  for (k in c("delta_terminal_value", "delta_terminal_value_ex_rv", "terminal_value_ex_rv")) {
    if (is.null(var$kpis[[k]]) && is.null(ref$kpis[[k]])) next
    ref$kpis[[k]] <- rep(0, n)
    if (!is.null(ref$kpi_na)) ref$kpi_na[[k]] <- rep(NA_character_, n)
  }
  for (nm in c("wealth", "net_position", "opp_net_position")) {
    if (!is.null(ref$paths[[nm]])) ref$paths[[nm]][] <- 0
  }
  ref
}

#' Vergleichskennzahlen einer Variante gegen die Referenz je Lauf (12.6, 9.6 Nr. 4, 6)
#'
#' `kpi_compare_values()` (WS-D2) mit q_T der Variante; dazu `prob_better_than_ref` = 1, wenn
#' `delta_vs_reference > 0` (deterministisch 0/1, in der MC ist der Mittelwert die
#' Wahrscheinlichkeit). Enthält die Variantenseite die negierten Zahlungen der Referenz
#' (`var$differential`, Modus `differential`), ist ihr ΔEW selbst der Vorteil gegenüber der
#' Referenz; ΔEW und Vermögenspfade der Referenz gehen dann mit 0 ein (`cmp_neutral_ref()`).
#' @return `list(kpis = data.frame, na = data.frame)` mit n Zeilen.
#' @noRd
cmp_compare_sides <- function(var, ref) {
  qt <- var$q_T
  if (isTRUE(var$differential)) ref <- cmp_neutral_ref(ref, var)
  cv <- kpi_compare_values(var, ref, q_T = qt)
  k <- cv$kpis
  na <- cv$na
  dvr <- k$delta_vs_reference
  k$prob_better_than_ref <- as.double(dvr > 0)
  na$prob_better_than_ref <- na$delta_vs_reference
  list(kpis = k, na = na)
}

#' Vergleichsspalten in ein Kennzahlergebnis übernehmen (Data Frames mit gleichen Zeilen)
#' @noRd
cmp_add_columns <- function(kpis, kpi_na, cv) {
  for (nm in names(cv$kpis)) {
    kpis[[nm]] <- as.double(cv$kpis[[nm]])
    kpi_na[[nm]] <- as.character(cv$na[[nm]])
  }
  list(kpis = kpis, kpi_na = kpi_na)
}

# ---------------------------------------------------------------------------------------------
# Deterministische Läufe und Design-Läufe
# ---------------------------------------------------------------------------------------------

#' Deterministischer Lauf eines Falls mit Rückgabepfaden (bei Entscheidungsknoten der
#' realisierte Zweig, der andere in `decision$alternative`; 9.11 Nr. 4)
#' @param extra_rows `NULL` oder negierte Zeilen der Referenz (Modus differential, 9.6 Nr. 6).
#' @param with_ref_rows `TRUE`, wenn der Lauf die Zeilen der Referenz enthält (`cmp_side()`).
#' @return Liste `result` (`vofi_result`), `side` (für die Vergleichskennzahlen), `model`
#'   (Modell des realisierten Zweigs); bei Entscheidungsknoten zusätzlich `approved` und
#'   `fallback` (je Zweig `result`, `side`, `model`).
#' @noRd
cmp_det_run <- function(model, extra_rows = NULL, with_ref_rows = FALSE) {
  one <- function(m) {
    t0 <- proc.time()[["elapsed"]]
    ch <- eng_run_chunk(m, blocks = 1L, seed = NULL, mode = "deterministic", store = "full",
                        return_paths = cmp_paths(), extra_rows = extra_rows)
    side <- cmp_side(ch, m, with_ref_rows)
    res <- eng_result(m, cmp_strip_qt(ch), mode = "deterministic", store = "full", seed = NULL,
                      runtime = proc.time()[["elapsed"]] - t0)
    list(result = res, side = side, model = m)
  }
  dec <- model$decision
  if (is.null(dec)) return(one(model))
  b <- as.integer(dec$branch %||% 1L)
  realized <- one(if (b == 1L) model else dec$fallback)
  other <- one(if (b == 1L) dec$fallback else model)
  realized$result$decision <- list(funding_id = dec$funding_id,
                                   fallback_variant = dec$fallback_variant, p_approval = dec$p,
                                   branch = b, alternative = other$result)
  realized$approved <- if (b == 1L) realized else other
  realized$fallback <- if (b == 1L) other else realized
  realized
}

#' Ist `cn` eine zulässige Designspalte des Plans (11.11)? (wie `smp_design_class()`, ohne
#' Fehler)
#' @noRd
cmp_design_known <- function(plan, cn) {
  if (!inherits(plan, "smp_plan")) return(FALSE)
  st <- plan$static
  if (cn %in% st$key || cn %in% names(plan$processes)) return(TRUE)
  segs <- path_split(cn)
  if (length(segs) >= 2L && segs[1L] %in% names(plan$processes)) {
    def <- reg_get("process", plan$processes[[segs[1L]]]$type)
    if (segs[2L] %in% names(def$params)) return(TRUE)
  }
  if (!is.null(plan$spec) && !is.null(path_get(plan$spec, cn))) return(TRUE)
  cn %in% st$target
}

#' Design-Lauf eines Modells (11.11), bei Entscheidungsknoten als Kompositum (9.11 Nr. 3, 4)
#'
#' Spalten, die der Plan eines Modells nicht kennt (z. B. ein Overlay-Schlüssel nur der
#' Variante), bleiben für dieses Modell auf dem Basiswert. Eine Spalte mit dem
#' Entscheidungsschlüssel wählt den Zweig, sonst gilt der Zweig des Basisfalls.
#' @param design Data Frame der Designzeilen.
#' @param extra_rows `NULL` oder negierte Zeilen der Referenz je Designzeile (Modus
#'   differential, 9.6 Nr. 6; in beiden Zweigen eines Entscheidungsknotens).
#' @return Chunk-Ergebnis wie `eng_run_chunk()` (mit `n` Zeilen).
#' @noRd
cmp_design_run <- function(model, design, kpis = NULL, store = "kpi",
                           return_paths = character(), extra_rows = NULL) {
  run1 <- function(m) {
    keep <- vapply(names(design), function(cn) cmp_design_known(m$sampler, cn), logical(1))
    d <- design[, keep, drop = FALSE]
    if (ncol(d) == 0L) d <- data.frame(row.names = seq_len(nrow(design)))
    sel <- if (is.null(kpis)) NULL else intersect(kpis, names(m$kpis))
    eng_run_chunk(m, blocks = 1L, seed = NULL, mode = "design", store = store, design = d,
                  return_paths = return_paths, kpis = sel, extra_rows = extra_rows)
  }
  dec <- model$decision
  if (is.null(dec)) return(run1(model))
  mc_composite(run1(model), run1(dec$fallback))
}

#' Design-Läufe von Variante und Referenz mit derselben Designmatrix (11.11, 12.8)
#'
#' Im Modus differential der Variante (9.6 Nr. 6) wird die Referenz je Designzeile mit
#' vollständigem Ledger gerechnet; ihre negierten project-/grants-Zeilen gehen als
#' `extra_rows` in den Lauf der Variante, deren Seite dann `differential = TRUE` trägt.
#' @return Liste `var`, `ref` (Seiten nach `cmp_side()`), `var_chunk`, `ref_chunk`,
#'   `differential`.
#' @noRd
cmp_design_pair <- function(model_v, model_r, design, kpis = NULL, store = "kpi",
                            return_paths = character()) {
  diff <- cmp_is_differential(model_v)
  if (diff) cmp_check_grid(model_v, model_r)
  cr <- cmp_design_run(model_r, design, kpis = kpis, store = if (diff) "full" else store,
                       return_paths = return_paths)
  extra <- if (diff) cmp_differential_rows(cr$ledger) else NULL
  if (diff && !identical(store, "full")) {
    cr$ledger <- NULL
    cr$draws <- NULL
    cr$opp$ledger <- NULL
  }
  cv <- cmp_design_run(model_v, design, kpis = kpis, store = store,
                       return_paths = return_paths, extra_rows = extra)
  list(var = cmp_side(cv, model_v, diff), ref = cmp_side(cr, model_r), var_chunk = cv,
       ref_chunk = cr, differential = diff)
}

#' Ergebnis eines Design-Laufs mit einer Zeile als `vofi_result` (4.11, R-74)
#' @param extra_rows,with_ref_rows wie `cmp_det_run()`.
#' @noRd
cmp_design_result <- function(model, design, set_name, notes = character(0),
                              extra_rows = NULL, with_ref_rows = FALSE) {
  t0 <- proc.time()[["elapsed"]]
  ch <- cmp_design_run(model, design, store = "full", return_paths = cmp_paths(),
                       extra_rows = extra_rows)
  side <- cmp_side(ch, model, with_ref_rows)
  res <- eng_result(model, cmp_strip_qt(ch), mode = "design", store = "full", seed = NULL,
                    runtime = proc.time()[["elapsed"]] - t0)
  res$meta$scenario_set <- set_name
  res$meta$notes <- c(res$meta$notes, notes)
  if (isTRUE(with_ref_rows)) {
    res$meta$notes <- c(res$meta$notes, lbl("mc.compare.differential_note"))
  }
  list(result = res, side = side)
}

# ---------------------------------------------------------------------------------------------
# Vergleichbarkeit (9.6 Nr. 2, R-66, R-67, R-68)
# ---------------------------------------------------------------------------------------------

#' Befund der Vergleichbarkeitsprüfung
#' @noRd
cmp_finding <- function(severity, code, case, path, ...) {
  data.frame(severity = severity, code = code, path = path, location = NA_character_,
             message = msg(code, ...), layer = NA_integer_, variant = case,
             stringsAsFactors = FALSE)
}

#' Kumulierte geplante Einlagen bzw. Entnahmen an den Periodenenden
#' @noRd
cmp_equity_cum <- function(res, category) {
  led <- res$ledger
  keys <- ledger_select(led, section = "equity", category = category)
  keys <- keys[!startsWith(keys, "opp_")]
  v <- if (length(keys) == 0L) rep(0, led$T + 1L) else
    colSums(do.call(rbind, lapply(keys, function(k) led$values[[k]][1L, ])))
  stats::setNames(cumsum(v), as.character(as.numeric(res$grid$date_end)))
}

#' Bestandsdarlehen einer Spezifikation (Parameter ohne Beschriftung)
#' @noRd
cmp_existing_loans <- function(spec) {
  fin <- spec$financing %||% list()
  ex <- Filter(function(f) {
    e <- f$existing
    if (is.list(e)) e <- e$value %||% e[[1L]]
    isTRUE(as.logical(e))
  }, fin)
  lapply(ex, function(f) f[setdiff(names(f), c("label", "description"))])
}

#' Basiswert eines Spec-Pfads (Zahl oder Knoten; ohne Wert `NULL`)
#' @noRd
cmp_spec_value <- function(spec, path, grid = NULL) {
  v <- path_get(spec, path)
  if (is.null(v)) return(NULL)
  if (is.numeric(v) && !is.list(v)) return(as.double(v))
  if (is.character(v) || is.logical(v)) return(v)
  # Konstantenknoten ohne Raster (der Rasteraufbau ist teuer)
  if (is.list(v) && identical(v$kind, "const") && is.numeric(v$value)) {
    return(as.double(v$value))
  }
  g <- grid %||% eng_build_grid(spec)
  tryCatch(res_value(res_context(spec, g, 1L), path, "scalar", base = TRUE),
           error = function(e) NULL)
}

#' Vergleichbarkeit der Fälle gegen ihre Referenz (9.6 Nr. 2)
#'
#' Geprüft im deterministischen Lauf: Stichtag und Horizontende, Kontenparameter und Ketten,
#' geplante Einlagen und Entnahmen (Toleranz `oracle_abs`, an den gemeinsamen Periodenenden),
#' Sacheinlage, Bestandsdarlehen, Restwertmethode und Steuermodul. Endogene Nachschüsse werden
#' nicht geprüft. Befunde sind Fehler (`vofi_error_validation`), mit `allow_unequal = TRUE`
#' Warnungen.
#' @return `vofi_validation`.
#' @noRd
cmp_comparability <- function(models, dets, cases, allow_unequal = FALSE) {
  sev <- if (allow_unequal) "warning" else "error"
  acc <- new.env(parent = emptyenv())
  acc$out <- list()
  add <- function(...) acc$out[[length(acc$out) + 1L]] <- cmp_finding(...)
  tol <- vofi_tol$oracle_abs
  for (i in seq_len(nrow(cases))) {
    cs <- cases$case[i]
    rf <- cases$reference[i]
    if (identical(cs, rf)) next
    ma <- models[[cs]]
    mr <- models[[rf]]
    ra <- dets[[cs]]$result
    rr <- dets[[rf]]$result
    if (!identical(ma$grid$valuation_date, mr$grid$valuation_date)) {
      add(sev, "mc.comparability.valuation_date", cs, "project.valuation_date", variant = cs,
          reference = rf)
    }
    if (!identical(ma$grid$end_date, mr$grid$end_date)) {
      add(sev, "mc.comparability.end_date", cs, "project.horizon_years", variant = cs,
          reference = rf)
    }
    if (!identical(stable_hash(ma$accounts), stable_hash(mr$accounts))) {
      add(sev, "mc.comparability.accounts", cs, "accounts", variant = cs, reference = rf)
    }
    for (cat in c("equity_in", "equity_out")) {
      ca <- cmp_equity_cum(ra, cat)
      cr <- cmp_equity_cum(rr, cat)
      common <- intersect(names(ca), names(cr))
      dev <- max(abs(ca[common] - cr[common]), abs(ca[length(ca)] - cr[length(cr)]), 0)
      if (dev > tol) {
        add(sev, "mc.comparability.equity", cs, "financing", variant = cs, reference = rf,
            category = cat, value = dev)
      }
    }
    ka <- ledger_sum(ra$ledger, category = "equity_in_kind")[1L, 1L]
    kr <- ledger_sum(rr$ledger, category = "equity_in_kind")[1L, 1L]
    if (abs(ka - kr) > tol) {
      add(sev, "mc.comparability.in_kind", cs, "building.existing_value_eur", variant = cs,
          reference = rf)
    }
    if (!identical(stable_hash(cmp_existing_loans(ma$spec)),
                   stable_hash(cmp_existing_loans(mr$spec)))) {
      add(sev, "mc.comparability.existing_loans", cs, "financing", variant = cs,
          reference = rf)
    }
    if (!identical(stable_hash(ma$spec$residual_value$method),
                   stable_hash(mr$spec$residual_value$method))) {
      add(sev, "mc.comparability.residual_method", cs, "residual_value.method", variant = cs,
          reference = rf)
    }
    if (!identical(ma$spec$tax$module %||% "none", mr$spec$tax$module %||% "none") ||
          !identical(stable_hash(ma$tax_params), stable_hash(mr$tax_params))) {
      add(sev, "mc.comparability.tax_module", cs, "tax.module", variant = cs, reference = rf)
    }
    if (identical(ma$spec$project$comparison_mode, "differential")) {
      add("info", "mc.comparability.differential", cs, "project.comparison_mode",
          variant = cs)
    }
  }
  rep <- new_vofi_validation(val_bind(acc$out))
  errs <- rep[rep$severity == "error", , drop = FALSE]
  if (nrow(errs) > 0L) {
    vofi_abort("mc.compare.not_comparable", n = nrow(errs),
               details = utl_collapse(errs$message, sep = " | "),
               .class = "vofi_error_validation", .data = list(report = rep))
  }
  if (any(rep$severity == "warning")) {
    vofi_warn("mc.compare.unequal", n = sum(rep$severity == "warning"),
              .class = "vofi_warning_plausibility")
  }
  rep
}

#' Modus differential: nur bei gleichem Raster von Variante und Referenz (9.6 Nr. 6)
#' @noRd
cmp_check_differential <- function(models, cases) {
  for (i in seq_len(nrow(cases))) {
    cs <- cases$case[i]
    rf <- cases$reference[i]
    if (identical(cs, rf)) next
    if (identical(models[[cs]]$spec$project$comparison_mode, "differential") &&
          !identical(models[[cs]]$grid$months, models[[rf]]$grid$months)) {
      vofi_abort("mc.compare.differential_grid", variant = cs, reference = rf,
                 .class = "vofi_error_validation")
    }
  }
  invisible(TRUE)
}

#' Negierte Zahlungen der Abschnitte project und grants der Referenz (9.6 Nr. 6)
#' @param led Ledger der Referenz (n Läufe).
#' @return `vofi_ledger` mit den Zusatzzeilen bzw. `NULL`.
#' @noRd
cmp_differential_rows <- function(led) {
  if (is.null(led)) return(NULL)
  keys <- ledger_select(led, section = c("project", "grants"), cash = TRUE)
  if (length(keys) == 0L) return(NULL)
  rows <- led$rows[match(keys, led$rows$key), , drop = FALSE]
  new_keys <- paste0("ref_", keys)
  rows$key <- new_keys
  rows$source_id <- paste0("ref_", rows$source_id)
  rows$origin <- "engine"
  rows$label <- vapply(rows$label, function(l) lbl("mc.compare.differential_row", label = l),
                       "", USE.NAMES = FALSE)
  rownames(rows) <- NULL
  values <- lapply(keys, function(k) -led$values[[k]])
  names(values) <- new_keys
  new_vofi_ledger(rows, values, n = led$n, T = led$T)
}

# ---------------------------------------------------------------------------------------------
# Deterministischer Vergleich
# ---------------------------------------------------------------------------------------------

#' Rendite der Mehrinvestition (12.6, 12.8): g(h) = delta_vs_reference bei Habenzins h in
#' Variante, Referenz und beiden Unterlassungsalternativen (Designspalte
#' `accounts.deposit_rate_pa`), mit und ohne Restwert
#' @return Liste `with`, `ex_rv` (`vofi_kpi_value` mit Attribut `"solver"`), `g` (Funktion
#'   h -> Matrix der Werte mit und ohne Restwert).
#' @noRd
cmp_incremental_return <- function(model_v, model_r, interval = c(-0.02, 0.15), n_grid = 41L,
                                   tol = 1e-8) {
  cache <- new.env(parent = emptyenv())
  kp <- c("delta_terminal_value")
  dtv <- function(ch, ex_rv) {
    k <- ch$kpis
    v <- if (ex_rv) k$delta_terminal_value_ex_rv %||% k$delta_terminal_value else
      k$delta_terminal_value
    as.double(v)
  }
  g_both <- function(h) {
    keys <- sprintf("%.17g", h)
    miss <- unique(h[!vapply(keys, exists, logical(1), envir = cache, inherits = FALSE)])
    if (length(miss) > 0L) {
      d <- data.frame(accounts.deposit_rate_pa = miss, check.names = FALSE)
      # Modus differential: die Variante enthaelt je Zeile die negierten Zahlungen der Referenz,
      # ihr dEW ist dann selbst delta_vs_reference (9.6 Nr. 6)
      pr <- cmp_design_pair(model_v, model_r, d, kpis = kp)
      a <- dtv(pr$var_chunk, FALSE)
      a_ex <- dtv(pr$var_chunk, TRUE)
      if (pr$differential) {
        b <- rep(0, length(miss))
        b_ex <- b
      } else {
        b <- dtv(pr$ref_chunk, FALSE)
        b_ex <- dtv(pr$ref_chunk, TRUE)
      }
      for (i in seq_along(miss)) {
        assign(sprintf("%.17g", miss[i]), c(a[i] - b[i], a_ex[i] - b_ex[i]), envir = cache)
      }
    }
    t(vapply(keys, function(k) get(k, envir = cache, inherits = FALSE), double(2)))
  }
  r1 <- kpi_incremental_return(function(h) g_both(h)[, 1L], interval, n_grid, tol)
  r2 <- kpi_incremental_return(function(h) g_both(h)[, 2L], interval, n_grid, tol)
  list(with = r1, ex_rv = r2, g = g_both)
}

#' Vergleichskennzahlen eines deterministischen Falls gegen seine Referenz (inkl. Rendite der
#' Mehrinvestition)
#' @return `list(kpis, na)` (eine Zeile).
#' @noRd
cmp_det_compare <- function(models, dets, cs, rf, incremental = TRUE) {
  cv <- cmp_compare_sides(dets[[cs]]$side, dets[[rf]]$side)
  if (incremental) {
    ir <- tryCatch(cmp_incremental_return(models[[cs]], models[[rf]]),
                   vofi_error = function(e) NULL)
    for (sfx in c("", "_ex_rv")) {
      v <- if (is.null(ir)) vofi_kpi_value(NA_real_, na_reason = "no_solution") else
        ir[[if (nzchar(sfx)) "ex_rv" else "with"]]
      cv$kpis[[paste0("incremental_return", sfx)]] <- as.double(v$values)
      cv$na[[paste0("incremental_return", sfx)]] <- as.character(v$na_reason)
    }
  }
  cv
}

#' Deterministischer Vergleich (n_sim = 1)
#' @return Liste `results`, `compare` (Vergleichskennzahlen je Fall), `conditions`.
#' @noRd
cmp_run_det <- function(models, dets, setup) {
  cases <- setup$cases
  results <- list()
  compare <- list()
  run <- mc_capture({
    for (i in seq_len(nrow(cases))) {
      cs <- cases$case[i]
      rf <- cases$reference[i]
      res <- dets[[cs]]$result
      if (!identical(cs, rf)) {
        if (identical(models[[cs]]$spec$project$comparison_mode, "differential")) {
          dets[[cs]] <- cmp_det_differential(models[[cs]], dets[[rf]])
          res <- dets[[cs]]$result
        }
        cv <- cmp_det_compare(models, dets, cs, rf)
        compare[[cs]] <- cv
        added <- cmp_add_columns(res$kpis, res$kpi_na, cv)
        res$kpis <- added$kpis
        res$kpi_na <- added$kpi_na
      }
      results[[cs]] <- res
    }
    NULL
  })
  list(results = results, compare = compare, conditions = run$conditions, dets = dets)
}

#' Deterministischer Lauf einer Variante im Modus differential (9.6 Nr. 6)
#'
#' Wie `cmp_det_run()` mit den negierten project-/grants-Zeilen des deterministischen Laufs der
#' Referenz (bei Entscheidungsknoten in beiden Zweigen) und dem Vermerk
#' „Vereinfachungsmodus Differenzzahlungen“.
#' @noRd
cmp_det_differential <- function(model, det_ref) {
  extra <- cmp_differential_rows(det_ref$result$ledger)
  out <- cmp_det_run(model, extra_rows = extra, with_ref_rows = TRUE)
  note <- lbl("mc.compare.differential_note")
  out$result$meta$notes <- c(out$result$meta$notes, note)
  alt <- out$result$decision$alternative
  if (!is.null(alt)) {
    alt$meta$notes <- c(alt$meta$notes, note)
    out$result$decision$alternative <- alt
  }
  out
}

#' Deterministische Läufe von Variante und Referenz für Vergleichskennzahlen (im Modus
#' differential mit den negierten Zeilen der Referenz in der Variante)
#' @return Liste `var`, `ref` (je wie `cmp_det_run()`).
#' @noRd
cmp_det_pair <- function(model_v, model_r) {
  dr <- cmp_det_run(model_r)
  dv <- if (cmp_is_differential(model_v)) {
    cmp_check_grid(model_v, model_r)
    cmp_det_differential(model_v, dr)
  } else {
    cmp_det_run(model_v)
  }
  list(var = dv, ref = dr)
}

#' Modus differential braucht dasselbe Zeitraster von Variante und Referenz (9.6 Nr. 6)
#' @noRd
cmp_check_grid <- function(model_v, model_r) {
  if (!identical(model_v$grid$months, model_r$grid$months)) {
    vofi_abort("mc.compare.differential_grid", variant = model_v$spec$variant %||% "-",
               reference = model_r$spec$variant %||% "-", .class = "vofi_error_validation")
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------------------------------
# Vergleich in der Simulation (CRN, 11.10)
# ---------------------------------------------------------------------------------------------

#' Monte-Carlo-Vergleich mit gemeinsamen Zufallszahlen (9.6 Nr. 3, 11.10)
#'
#' Ein Vereinigungsplan über alle Fälle und Ausweichvarianten, ein Seed, gleiche Blockgröße; je
#' Chunk einmal `smp_sample()` und je Fall `eng_run_chunk(..., raw = raw)`. Die
#' Vergleichskennzahlen werden je Lauf auf den Differenzen gebildet und als Spalten in die
#' Kennzahlen des Falls übernommen; danach Sammler und Statistik je Fall wie `vofi_mc()`.
#' @noRd
cmp_run_mc <- function(models, dets, setup, n_sim, seed, store) {
  t0 <- proc.time()[["elapsed"]]
  cases <- setup$cases
  base_model <- models[[setup$baseline]]
  cfg0 <- mc_config(base_model, n_sim = n_sim, seed = seed, store = store,
                    return_paths = cmp_paths())
  cfgs <- list()
  for (cs in cases$case) {
    m <- models[[cs]]
    cfg <- mc_config(m, n_sim = cfg0$n_sim, seed = cfg0$seed, store = store,
                     sampling = cfg0$settings$sampling, block_size = cfg0$block_size,
                     return_paths = cmp_paths(),
                     kpis = unique(c(mc_kpi_names(m, cfg0$keep_runs_kpi),
                                     intersect(cmp_needed_kpis(), names(m$kpis)))))
    cfg$model$sampler <- mc_align_plan(cfg$model$sampler, cfg0$model$sampler)
    if (!is.null(cfg$model$decision)) {
      fb <- cfg$model$decision$fallback
      fb$sampler <- mc_align_plan(fb$sampler, cfg0$model$sampler)
      cfg$model$decision$fallback <- fb
    }
    cfgs[[cs]] <- cfg
  }
  plans <- list()
  for (cs in cases$case) {
    plans[[length(plans) + 1L]] <- cfgs[[cs]]$model$sampler
    if (!is.null(cfgs[[cs]]$model$decision)) {
      plans[[length(plans) + 1L]] <- cfgs[[cs]]$model$decision$fallback$sampler
    }
  }
  union <- smp_plan_union(plans)
  for (cs in cases$case) eng_warn_prepay(cfgs[[cs]]$model)
  eng_check_memory(base_model, cfg0$chunk_runs * nrow(cases))
  chunk_fun <- function(blocks) cmp_mc_chunk(cfgs, cases, union, blocks, seed = cfg0$seed)
  run <- mc_run_chunks(cfg0$chunks, chunk_fun, FALSE)
  results <- list()
  conditional <- list()
  det_cmp <- list()
  for (i in seq_len(nrow(cases))) {
    cs <- cases$case[i]
    rf <- cases$reference[i]
    det <- dets[[cs]]$result
    if (!identical(cs, rf)) {
      if (identical(models[[cs]]$spec$project$comparison_mode, "differential")) {
        dets[[cs]] <- cmp_det_differential(models[[cs]], dets[[rf]])
        det <- dets[[cs]]$result
      }
      cv <- cmp_det_compare(models, dets, cs, rf)
      det_cmp[[cs]] <- cv
      added <- cmp_add_columns(det$kpis, det$kpi_na, cv)
      det$kpis <- added$kpis
      det$kpi_na <- added$kpi_na
    }
    chunks <- lapply(run$chunks, function(ch) ch[[cs]])
    cfg_cs <- cfgs[[cs]]
    cfg_cs$kpis <- setdiff(cfg_cs$kpis, cmp_qt_name())
    results[[cs]] <- mc_assemble(cmp_drop_qt(cfg_cs$model), cfg_cs, chunks, det, t0)
    if (!identical(cs, rf) && !is.null(models[[cs]]$decision)) {
      conditional[[cs]] <- cmp_conditional_mc(chunks, cs)
    }
  }
  list(results = results, conditions = run$conditions, conditional = conditional,
       compare = det_cmp, dets = dets, cfg = cfg0)
}

#' Kennzahlen, die die Vergleichskennzahlen brauchen (12.6)
#' @noRd
cmp_needed_kpis <- function() {
  c("terminal_value", "terminal_value_opp", "delta_terminal_value", "co2_emissions",
    "monthly_burden_y1", "monthly_burden_avg10", "monthly_net_cashflow_y1", "warm_rent_y1",
    cmp_qt_name())
}

#' Ein Chunk des MC-Vergleichs: alle Fälle mit denselben Rohziehungen (CRN)
#' @return benannte Liste je Fall wie `mc_chunk()`.
#' @noRd
cmp_mc_chunk <- function(cfgs, cases, union, blocks, seed) {
  raw <- smp_sample(union, blocks, seed)
  out <- list()
  is_diff <- vapply(seq_len(nrow(cases)), function(i) {
    cases$case[i] != cases$reference[i] &&
      identical(cfgs[[cases$case[i]]]$model$spec$project$comparison_mode, "differential")
  }, logical(1))
  need_ledger <- unique(cases$reference[is_diff])
  run <- function(m, cfg, store, extra = NULL) {
    ch <- eng_run_chunk(m, blocks = blocks, seed = seed, mode = "mc", store = store,
                        bands = cfg$bands, raw = raw, return_paths = cfg$return_paths,
                        kpis = cfg$kpis, extra_rows = extra)
    mc_fill_bands(ch, m, cfg, store)
  }
  order_cases <- c(which(cases$case == cases$reference),
                   which(cases$case != cases$reference))
  ref_led <- list()
  for (i in order_cases) {
    cs <- cases$case[i]
    rf <- cases$reference[i]
    cfg <- cfgs[[cs]]
    m <- cfg$model
    store <- if (cs %in% need_ledger) "full" else cfg$store
    extra <- if (is_diff[i]) cmp_differential_rows(ref_led[[rf]]) else NULL
    if (is.null(m$decision)) {
      ch <- run(m, cfg, store, extra)
      v <- NULL
      f <- NULL
    } else {
      cv <- run(m, cfg, store, extra)
      cf <- run(m$decision$fallback, cfg, store, extra)
      ch <- mc_composite(cv, cf)
      v <- cmp_strip_qt(cv[c("kpis", "kpi_na", "sims", "blocks", "n")])
      f <- cmp_strip_qt(cf[c("kpis", "kpi_na", "sims", "blocks", "n")])
    }
    if (cs %in% need_ledger) {
      ref_led[[cs]] <- ch$ledger
      if (!identical(cfg$store, "full")) {
        ch$ledger <- NULL
        ch$draws <- NULL
        ch$opp$ledger <- NULL
      }
    }
    out[[cs]] <- list(chunk = ch, v = v, f = f)
  }
  for (i in seq_len(nrow(cases))) {
    cs <- cases$case[i]
    rf <- cases$reference[i]
    if (identical(cs, rf)) next
    cv <- cmp_compare_sides(cmp_side(out[[cs]]$chunk, cfgs[[cs]]$model, is_diff[i]),
                            cmp_side(out[[rf]]$chunk, cfgs[[rf]]$model))
    added <- cmp_add_columns(out[[cs]]$chunk$kpis, out[[cs]]$chunk$kpi_na, cv)
    n <- nrow(added$kpis)
    added$kpis$incremental_return <- rep(NA_real_, n)
    added$kpis$incremental_return_ex_rv <- rep(NA_real_, n)
    added$kpi_na$incremental_return <- rep("not_computed", n)
    added$kpi_na$incremental_return_ex_rv <- rep("not_computed", n)
    out[[cs]]$chunk$kpis <- added$kpis
    out[[cs]]$chunk$kpi_na <- added$kpi_na
    if (!is.null(out[[cs]]$v)) {
      # Modus differential: das eigene dEW des Zweigs ist bereits der Vorteil (9.6 Nr. 6)
      ref_dtv <- if (is_diff[i]) 0 else as.double(out[[rf]]$chunk$kpis$delta_terminal_value)
      cond_v <- as.double(out[[cs]]$v$kpis$delta_terminal_value) - ref_dtv
      cond_f <- as.double(out[[cs]]$f$kpis$delta_terminal_value) - ref_dtv
      out[[cs]]$cond <- list(v = cond_v, f = cond_f, sims = out[[cs]]$chunk$sims)
    }
  }
  for (cs in names(out)) {
    out[[cs]]$chunk <- cmp_strip_qt(out[[cs]]$chunk)
    out[[cs]]$chunk$paths <- list()
  }
  out
}

#' Bedingte Vergleichsstatistik je Zweig (9.11 Nr. 5, 13.3 `conditional`)
#' @noRd
cmp_conditional_mc <- function(chunks, cs) {
  conds <- Filter(Negate(is.null), lapply(chunks, function(ch) ch$cond))
  if (length(conds) == 0L) return(NULL)
  rows <- lapply(c(1L, 0L), function(b) {
    x <- unlist(lapply(conds, function(cc) if (b == 1L) cc$v else cc$f), use.names = FALSE)
    cmp_cond_row(cs, b, x)
  })
  do.call(rbind, rows)
}

#' Zeile der bedingten Statistik
#' @noRd
cmp_cond_row <- function(cs, branch, x) {
  v <- x[!is.na(x)]
  q <- if (length(v) > 0L) stats::quantile(v, c(0.05, 0.5, 0.95), type = 7, names = FALSE) else
    rep(NA_real_, 3L)
  data.frame(variant = cs, branch = as.integer(branch), kpi = "delta_vs_reference",
             mean = if (length(v) > 0L) mean(v) else NA_real_, q05 = q[1L], q50 = q[2L],
             q95 = q[3L], prob_better = if (length(x) > 0L) mean(!is.na(x) & x > 0) else
               NA_real_,
             stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------------------------
# Generierte Sets („vorsichtig“, 4.11, Teil C 4.3)
# ---------------------------------------------------------------------------------------------

#' Generierte Sets je Variante rechnen
#' @return Liste `results` (`<variante>@<set>`), `info` (Treiber, Tornado, Designzeile, Wert
#'   je Variante).
#' @noRd
cmp_generated_sets <- function(models, dets, setup) {
  results <- list()
  info <- list()
  for (s in names(setup$generated)) {
    gen <- setup$generated[[s]]
    for (v in setup$variants) {
      cz <- cmp_cautious(models[[v]], models[[setup$baseline]], gen = gen, set_name = s,
                         kpi = "delta_vs_reference")
      key <- paste0(v, "@", s)
      info[[key]] <- cz
      if (!is.null(cz$result)) results[[key]] <- cz$result
    }
  }
  list(results = results, info = info)
}

#' Generiertes Set „vorsichtig“ (R-74, Spec 01 Teil C 4.3)
#'
#' Tornado (ein Design-Lauf mit 1 + 2k Zeilen) der Kennzahl `kpi` (`auto`: Primärkennzahl; bei
#' `delta_vs_reference` dieselbe Designmatrix für Variante und Referenz); die `n_drivers`
#' Kandidaten mit dem größten Ausschlag (ohne Ausschlag <= 1e-9 · max(1, |KPI_base|); Prozess
#' und eigener Parameter nicht zugleich) stehen gemeinsam auf ihrer ungünstigen Seite; die
#' Designzeile wird als Lauf mit einer Zeile gerechnet (Basisfallgrößen fest, R-69).
#' @param model Modell der Variante.
#' @param ref_model Modell der Referenz (für Vergleichskennzahlen) bzw. `NULL`.
#' @param gen Angaben `generate` (`n_drivers`, `probs`, `kpi`, `params`, `exclude`).
#' @param set_name Name des Sets.
#' @param kpi Kennzahl, falls `gen$kpi` `auto` ist.
#' @return Liste `row` (Designzeile), `drivers` (Data Frame `param`, `value`, `side`, `swing`),
#'   `tornado` (`vofi_sensitivity`), `result` (`vofi_result` mit Vergleichskennzahlen),
#'   `value`, `value_ex_rv` (Kennzahl in der Designzeile), `kpi`; ohne Treiber `result = NULL`.
#' @noRd
cmp_cautious <- function(model, ref_model = NULL, gen = list(), set_name = "vorsichtig",
                         kpi = NULL) {
  n_drivers <- as.integer(unlist(gen$n_drivers %||% 5L))[1L]
  probs <- as.double(unlist(gen$probs %||% c(0.1, 0.9)))
  k <- unlist(gen$kpi %||% "auto")
  if (identical(k, "auto")) k <- kpi %||% kpi_primary(model$spec)$kpi
  params <- unlist(gen$params %||% "auto")
  if (identical(params, "auto")) params <- NULL
  exclude <- as.character(unlist(gen$exclude %||% character(0)))
  setup <- sens_setup_models(model, if (k %in% sens_compare_kpis()) ref_model else NULL, k)
  cands <- sens_candidates(setup, params, probs, delta = NULL, exclude = exclude)
  tornado <- sens_result("tornado", setup, sens_tornado(setup, cands), probs = probs)
  res <- tornado$results
  base <- tornado$base_value
  thr <- 1e-9 * max(1, abs(base), na.rm = TRUE)
  ok <- !is.na(res$swing) & res$swing > thr
  res <- res[ok, , drop = FALSE]
  res <- res[order(-res$swing, res$param, method = "radix"), , drop = FALSE]
  chosen <- character(0)
  for (p in res$param) {
    if (length(chosen) >= n_drivers) break
    clash <- startsWith(p, paste0(chosen, ".")) | startsWith(chosen, paste0(p, "."))
    if (any(clash)) next
    chosen <- c(chosen, p)
  }
  out <- list(row = NULL, drivers = NULL, tornado = tornado, result = NULL, value = NA_real_,
              value_ex_rv = NA_real_, kpi = k)
  if (length(chosen) == 0L) {
    vofi_inform("mc.cautious.no_drivers", set = set_name)
    return(out)
  }
  hib <- setup$hib
  sel <- res[match(chosen, res$param), , drop = FALSE]
  low_worse <- if (isFALSE(hib)) sel$kpi_low > sel$kpi_high else sel$kpi_low < sel$kpi_high
  value <- ifelse(low_worse, sel$value_low, sel$value_high)
  drivers <- data.frame(param = sel$param, value = value,
                        side = ifelse(low_worse, "low", "high"), swing = sel$swing,
                        stringsAsFactors = FALSE)
  row <- as.data.frame(as.list(stats::setNames(value, sel$param)), check.names = FALSE,
                       optional = TRUE)
  shown <- paste0(drivers$param, " = ", format(drivers$value, digits = 6))
  notes <- lbl("mc.cautious.note", set = set_name, values = utl_collapse(shown))
  if (is.null(setup$ref_model)) {
    rv <- cmp_design_result(setup$model, row, set_name, notes)
    result <- rv$result
  } else {
    # dieselbe Designzeile auf Referenz und Variante; im Modus differential erhaelt die Variante
    # die negierten Zeilen der Referenz aus deren Designzeile (9.6 Nr. 6)
    rr <- cmp_design_result(setup$ref_model, row, set_name, notes)
    diff <- cmp_is_differential(setup$model)
    if (diff) cmp_check_grid(setup$model, setup$ref_model)
    extra <- if (diff) cmp_differential_rows(rr$result$ledger) else NULL
    rv <- cmp_design_result(setup$model, row, set_name, notes, extra_rows = extra,
                            with_ref_rows = diff)
    result <- rv$result
    cv <- cmp_compare_sides(rv$side, rr$side)
    added <- cmp_add_columns(result$kpis, result$kpi_na, cv)
    result$kpis <- added$kpis
    result$kpi_na <- added$kpi_na
  }
  out$row <- row
  out$drivers <- drivers
  out$result <- result
  out$value <- as.double(result$kpis[[k]] %||% NA_real_)[1L]
  kx <- paste0(sub("_ex_rv$", "", k), "_ex_rv")
  out$value_ex_rv <- as.double(result$kpis[[kx]] %||% NA_real_)[1L]
  out
}

# ---------------------------------------------------------------------------------------------
# Ampel (12.9, R-74, Spec 01 Teil C 6.6)
# ---------------------------------------------------------------------------------------------

#' Zahl aus der Spezifikation (Konstante bzw. Basisfallwert) mit Default
#' @noRd
cmp_spec_num <- function(spec, path, default = NA_real_, grid = NULL) {
  v <- tryCatch(cmp_spec_value(spec, path, grid), error = function(e) NULL)
  if (is.null(v) || !is.numeric(v) || length(v) == 0L || is.na(v[1L])) default else
    as.double(v[1L])
}

#' Schwellen der Ampel (`analysis.traffic_light`, Defaults 0,70 / 0,40 / 0,30)
#' @noRd
cmp_tl_thresholds <- function(spec, grid = NULL) {
  num <- function(nm, default) {
    cmp_spec_num(spec, paste0("analysis.traffic_light.", nm), default, grid)
  }
  list(green_prob = num("green_prob", 0.70), red_prob = num("red_prob", 0.40),
       restriction_prob = num("restriction_prob", 0.30))
}

#' Zweistufige Ampel aus Eingaben (12.9)
#'
#' Stufe 1 (Wirtschaftlichkeit): Basis `mc` (p = Anteil der Läufe mit P > 0, nicht definierte
#' Läufe zählen nicht als positiv; m = Median der definierten Läufe): green bei m > 0 und
#' p >= green_prob, red bei p < red_prob, sonst yellow; Basis `cautious`: green bei P_base > 0
#' und P_vorsichtig > 0, red bei beiden <= 0, sonst yellow; Basis `base_only`: yellow bei
#' P_base > 0, sonst red. Restwertregel: (P_base > 0) != (P_base_ex_rv > 0) deckelt Stufe 1 auf
#' yellow. Stufe 2: K.-o., wenn die Restriktion im Basisfall verletzt ist oder ihre
#' MC-Wahrscheinlichkeit >= restriction_prob ist; nicht prüfbare Restriktionen (NA) sind kein
#' K.-o. Das Ergebnis ist Stufe 1, bei einem K.-o. höchstens yellow.
#' @param p_base,p_base_ex_rv Primärkennzahl im Basisfall mit und ohne Restwert.
#' @param mc `NULL` oder Werte der Primärkennzahl je Lauf.
#' @param p_cautious `NULL` oder Wert im Set „vorsichtig“.
#' @param restrictions Data Frame `code`, `violated_base` (lgl/NA), `prob` (NA ohne MC),
#'   optional `year`, `value`, `threshold`.
#' @param thresholds Liste `green_prob`, `red_prob`, `restriction_prob`.
#' @param kpi Name der Primärkennzahl.
#' @return Liste `level`, `stage1`, `basis`, `kpi`, `rv_dependent`, `restrictions` (mit `ko`),
#'   `notes`, `p`, `median`.
#' @noRd
cmp_traffic_light_core <- function(p_base, p_base_ex_rv = p_base, mc = NULL, p_cautious = NULL,
                                   restrictions = NULL,
                                   thresholds = list(green_prob = 0.70, red_prob = 0.40,
                                                     restriction_prob = 0.30),
                                   kpi = "delta_terminal_value") {
  lev <- c("red", "yellow", "green")
  notes <- character(0)
  pos <- function(x) isTRUE(!is.na(x) && x > 0)
  p <- NA_real_
  med <- NA_real_
  if (!is.null(mc) && length(mc) > 0L) {
    basis <- "mc"
    x <- as.double(mc)
    p <- mean(!is.na(x) & x > 0)
    med <- if (any(!is.na(x))) stats::median(x, na.rm = TRUE) else NA_real_
    stage1 <- if (isTRUE(med > 0) && p >= thresholds$green_prob) "green" else
      if (p < thresholds$red_prob) "red" else "yellow"
  } else if (!is.null(p_cautious) && !is.na(p_cautious)) {
    basis <- "cautious"
    stage1 <- if (pos(p_base) && pos(p_cautious)) "green" else
      if (!pos(p_base) && !pos(p_cautious)) "red" else "yellow"
  } else {
    basis <- "base_only"
    stage1 <- if (pos(p_base)) "yellow" else "red"
    notes <- c(notes, lbl("mc.traffic_light.no_robustness"))
  }
  rv_dep <- !identical(pos(p_base), pos(p_base_ex_rv))
  if (rv_dep) {
    if (match(stage1, lev) > 2L) stage1 <- "yellow"
    notes <- c(notes, lbl("mc.traffic_light.rv_dependent"))
  }
  rs <- restrictions
  if (is.null(rs) || nrow(rs) == 0L) {
    rs <- data.frame(code = character(0), violated_base = logical(0), prob = numeric(0),
                     year = integer(0), value = numeric(0), threshold = numeric(0),
                     ko = logical(0), stringsAsFactors = FALSE)
  } else {
    for (f in c("year", "value", "threshold")) {
      if (is.null(rs[[f]])) rs[[f]] <- if (f == "year") NA_integer_ else NA_real_
    }
    vb <- as.logical(rs$violated_base)
    pr <- as.double(rs$prob)
    unchecked <- is.na(vb) & is.na(pr)
    rs$ko <- (!is.na(vb) & vb) | (!is.na(pr) & pr >= thresholds$restriction_prob)
    rs$ko[unchecked] <- FALSE
    for (cd in rs$code[unchecked]) {
      # deutsche Bezeichnung der Restriktion (Label-Katalog der Ausgabeschicht), sonst Code
      notes <- c(notes, lbl("mc.traffic_light.restriction_unchecked",
                            code = lbl(paste0("report.traffic.restriction_", cd), .default = cd)))
    }
    for (i in which(rs$ko)) {
      notes <- c(notes, cmp_restriction_note(rs[i, , drop = FALSE]))
    }
    rs <- rs[, c("code", "violated_base", "prob", "year", "value", "threshold", "ko"),
             drop = FALSE]
  }
  level <- stage1
  if (any(rs$ko) && match(level, lev) > 2L) level <- "yellow"
  list(level = level, stage1 = stage1, basis = basis, kpi = kpi, rv_dependent = rv_dep,
       restrictions = rs, notes = notes, p = p, median = med)
}

#' Hinweistext zu einer verletzten Restriktion (Jahr und Betrag der ersten Verletzung)
#' @noRd
cmp_restriction_note <- function(r) {
  yr <- if (is.na(r$year)) "-" else as.character(r$year)
  # Belastungsquote als Prozentsatz, uebrige Groessen als Zahl
  fmt <- if (identical(r$code, "burden")) function(v) fmt_pct(v, 1) else function(v) fmt_num(v, 2)
  val <- if (is.na(r$value)) "-" else fmt(r$value)
  thr <- if (is.na(r$threshold)) "-" else fmt(r$threshold)
  prob <- if (is.na(r$prob)) "-" else fmt_pct(r$prob, 1)
  switch(r$code,
    dscr = lbl("mc.traffic_light.ko_dscr", year = yr, value = val, threshold = thr,
               prob = prob),
    liquidity = lbl("mc.traffic_light.ko_liquidity", year = yr, value = val, threshold = thr,
                    prob = prob),
    warm_rent = lbl("mc.traffic_light.ko_warm_rent", year = yr, value = val, threshold = thr,
                    prob = prob),
    burden = lbl("mc.traffic_light.ko_burden", year = yr, value = val, threshold = thr,
                 prob = prob),
    savings = lbl("mc.traffic_light.ko_savings", year = yr, value = val, threshold = thr,
                  prob = prob),
    lbl("mc.traffic_light.ko_other", code = r$code, prob = prob)
  )
}

#' Jahr, Betrag und Schwelle der ersten Verletzung einer Restriktion im Basisfall (12.9)
#' @param res `vofi_result` (Basisfall).
#' @param code Restriktionscode (`dscr`, `liquidity`, `warm_rent`, `burden`, `savings`).
#' @return Liste `year`, `value`, `threshold`.
#' @noRd
cmp_restriction_detail <- function(res, code) {
  none <- list(year = NA_integer_, value = NA_real_, threshold = NA_real_)
  if (is.null(res) || is.null(res$ledger)) return(none)
  spec <- res$spec
  thr <- function(name, default = NA_real_) {
    cmp_spec_num(spec, paste0("analysis.thresholds.", name), default, res$grid)
  }
  kv <- function(k) {
    v <- res$kpis[[k]]
    if (is.null(v)) NA_real_ else as.double(v[1L])
  }
  out <- tryCatch({
    core <- list(ledger = ledger_subset_sims(res$ledger, 1L), grid = res$grid, n = 1L)
    g <- res$grid
    switch(code,
      dscr = {
        t1 <- thr("dscr", 1.2)
        oy <- kpi_op_years(g)
        noi <- kpi_by_year(kpi_noi(core), oy)[1L, ]
        kd <- kpi_by_year(kpi_kd(core), oy)[1L, ]
        mask <- kpi_stab_mask(oy, list(spec = spec)) & kd > kpi_kd_tol()
        d <- ifelse(mask, noi / ifelse(kd > 0, kd, 1), NA_real_)
        hit <- which(!is.na(d) & d < t1)
        if (length(hit) > 0L) {
          list(year = oy$year[hit[1L]], value = d[hit[1L]], threshold = t1)
        } else {
          list(year = NA_integer_, value = kv("dscr_min"), threshold = t1)
        }
      },
      liquidity = {
        v <- res$ledger$values
        kk <- v$od_balance[1L, ] + (v$odp_balance %||% matrix(0, 1L, g$T + 1L))[1L, ]
        odp <- (v$odp_balance %||% matrix(0, 1L, g$T + 1L))[1L, ]
        t1 <- cmp_spec_num(spec, "accounts.overdraft_flag_threshold_eur", Inf, g)
        hit <- which(odp > vofi_tol$zero_abs | kk > t1)
        if (length(hit) > 0L) {
          list(year = as.integer(g$year[hit[1L]]), value = kk[hit[1L]],
               threshold = if (is.finite(t1)) t1 else NA_real_)
        } else {
          t1_out <- if (is.finite(t1)) t1 else NA_real_
          list(year = NA_integer_, value = max(kk), threshold = t1_out)
        }
      },
      warm_rent = {
        oy <- kpi_op_years(g)
        # Bezugsjahr j* wie warm_rent_change_prepost_y1 (MRE-01)
        i <- kpi_warm_y1_index(eng_context_from_parts(g, res$spec, mode = "deterministic"), oy)
        yr <- if (is.na(i)) NA_integer_ else oy$year[i]
        list(year = as.integer(yr), value = kv("warm_rent_change_prepost_y1"),
             threshold = thr("warm_rent_increase_eur_m2", 0.5))
      },
      burden = {
        t1 <- thr("burden_share", 0.4)
        r <- cmp_burden_ratio_years(res, core)
        hit <- which(!is.na(r$ratio) & r$ratio > t1)
        if (length(hit) > 0L) {
          list(year = r$year[hit[1L]], value = r$ratio[hit[1L]], threshold = t1)
        } else {
          list(year = NA_integer_, value = kv("burden_ratio_max"), threshold = t1)
        }
      },
      savings = {
        oy <- kpi_op_years(g)
        ns <- kpi_by_year(kpi_ns(core), oy)[1L, ]
        cap <- 12 * cmp_spec_num(spec, "household.savings_capacity_month_eur", NA_real_, g)
        # erstes Betriebsjahr mit Nachschuss ueber der Sparfaehigkeit
        # (flags$equity_call_over_savings)
        hit <- which(!is.na(ns) & ns > cap + vofi_tol$zero_abs)
        if (length(ns) == 0L) {
          none
        } else if (length(hit) > 0L) {
          list(year = as.integer(oy$year[hit[1L]]), value = ns[hit[1L]], threshold = cap)
        } else {
          i <- which.max(ns)
          list(year = NA_integer_, value = ns[i], threshold = cap)
        }
      },
      none
    )
  }, error = function(e) none)
  out
}

#' Belastungsquote je Betriebsjahr im Basisfall (wie `burden_ratio_max`, 12.3)
#'
#' Monatliche Belastung je Betriebsjahr / Einkommen des Jahres (`household.net_income_month_eur`
#' × Kalenderjahresindex von `household.income_growth`, Preisstand `project.price_base_year`).
#' @param res `vofi_result` (Basisfall).
#' @param core Kern mit `ledger` (ein Lauf), `grid`, `n`.
#' @return Liste `year` (Kalenderjahr je Betriebsjahr), `ratio` (`NA` ohne Einkommen).
#' @noRd
cmp_burden_ratio_years <- function(res, core) {
  g <- res$grid
  oy <- kpi_op_years(g)
  na <- list(year = oy$year, ratio = rep(NA_real_, length(oy$year)))
  if (length(oy$P) == 0L) return(na)
  ctx <- eng_context_from_parts(g, res$spec, mode = "deterministic")
  inc <- ctx$value("household.net_income_month_eur", "scalar")
  if (is.null(inc)) return(na)
  growth <- ctx$value("household.income_growth", "path")
  if (is.null(growth)) growth <- 0
  idx <- ctx$index_year(growth, base_date = kpi_price_base_date(ctx, g))
  income <- as.double(inc)[1L] * idx[1L, oy$first]
  burden <- kpi_monthly_by_year(kpi_burden(core), oy)[1L, ]
  list(year = oy$year, ratio = ifelse(income > vofi_tol$zero_abs, burden / income, NA_real_))
}

#' Restriktionen der Ampel aus Basisfall und Simulation (12.9 Stufe 2)
#' @param det `vofi_result` des Basisfalls.
#' @param kpis `NULL` oder Kennzahlen der Läufe.
#' @return Data Frame `code`, `violated_base`, `prob`, `year`, `value`, `threshold`.
#' @noRd
cmp_restrictions <- function(det, kpis = NULL) {
  codes <- as.character(unlist(det$spec$analysis$restrictions %||% character(0)))
  if (length(codes) == 0L) return(NULL)
  rows <- lapply(codes, function(cd) {
    k <- paste0("restriction_", cd)
    b <- det$kpis[[k]]
    vb <- if (is.null(b) || is.na(b[1L])) NA else isTRUE(b[1L] == 1)
    pr <- NA_real_
    if (!is.null(kpis) && !is.null(kpis[[k]])) {
      x <- as.double(kpis[[k]])
      if (any(!is.na(x))) pr <- mean(x, na.rm = TRUE)
    }
    d <- if (isTRUE(vb) || isTRUE(pr > 0)) cmp_restriction_detail(det, cd) else
      list(year = NA_integer_, value = NA_real_, threshold = NA_real_)
    data.frame(code = cd, violated_base = vb, prob = pr, year = as.integer(d$year),
               value = as.double(d$value), threshold = as.double(d$threshold),
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

#' Ampel eines Ergebnisses (12.9)
#'
#' Für `vofi_mc_result` mit Basis `mc`, für `vofi_result` mit Basis `cautious` (wenn
#' `cautious` angegeben ist) bzw. `base_only`. Primärkennzahl nach 12.3a; fehlt sie im Ergebnis
#' (z. B. `delta_vs_reference` außerhalb eines Vergleichs bei Bestandsprojekten), gibt es keine
#' Ampel (`NULL`).
#' @param x `vofi_result` oder `vofi_mc_result`.
#' @param kpi `NULL` (Primärkennzahl) oder Kennzahl.
#' @param cautious `NULL` oder Wert der Kennzahl im Set „vorsichtig“.
#' @return Liste nach 13.1 (`level`, `stage1`, `basis`, `kpi`, `rv_dependent`,
#'   `restrictions`, `notes`) bzw. `NULL`.
#' @noRd
cmp_traffic_light <- function(x, kpi = NULL, cautious = NULL) {
  is_mc <- inherits(x, "vofi_mc_result")
  det <- if (is_mc) x$deterministic else x
  if (is.null(det)) return(NULL)
  kpi <- kpi %||% kpi_primary(x$spec)$kpi
  if (is.null(det$kpis[[kpi]])) return(NULL)
  p_base <- as.double(det$kpis[[kpi]][1L])
  kx <- paste0(kpi, "_ex_rv")
  p_ex <- if (is.null(det$kpis[[kx]])) p_base else as.double(det$kpis[[kx]][1L])
  mc <- if (is_mc) x$kpis[[kpi]] else NULL
  restr <- cmp_restrictions(det, if (is_mc) x$kpis else NULL)
  out <- cmp_traffic_light_core(p_base, p_ex, mc = mc, p_cautious = cautious,
                                restrictions = restr,
                                thresholds = cmp_tl_thresholds(x$spec, det$grid), kpi = kpi)
  out[c("level", "stage1", "basis", "kpi", "rv_dependent", "restrictions", "notes")]
}

# ---------------------------------------------------------------------------------------------
# Differenz-VoFi (9.6 Nr. 5)
# ---------------------------------------------------------------------------------------------

#' Differenz-VoFi A - Referenz (Erklärung, deterministisch; nur bei gleichem Raster)
#'
#' Zeilenweise Differenz der Grob-Tabellen (`vofi_table()`, WS-H) nach `row_key`; fehlende
#' Zeilen zählen als 0. Bei abweichendem Raster oder ohne Tabellenfunktion `NULL`.
#' @return `vofi_table` bzw. `NULL` (mit Attribut `"note"`).
#' @noRd
cmp_diff_table <- function(res_a, res_r, variant = NULL) {
  if (!identical(res_a$grid$months, res_r$grid$months)) {
    return(structure(list(), note = "grid"))
  }
  ta <- tryCatch(vofi_table(res_a), vofi_error = function(e) NULL)
  tr <- tryCatch(vofi_table(res_r), vofi_error = function(e) NULL)
  if (!inherits(ta, "vofi_table") || !inherits(tr, "vofi_table")) {
    return(structure(list(), note = "table"))
  }
  da <- ta$data
  dr <- tr$data
  meta_cols <- c("row_key", "label", "section", "level")
  pcols <- setdiff(names(da), meta_cols)
  pcols <- pcols[vapply(pcols, function(cn) is.numeric(da[[cn]]), logical(1))]
  keys <- c(da$row_key, setdiff(dr$row_key, da$row_key))
  out <- rbind(da[, intersect(names(da), meta_cols), drop = FALSE],
               dr[match(setdiff(dr$row_key, da$row_key), dr$row_key),
                  intersect(names(dr), meta_cols), drop = FALSE])
  for (cn in pcols) {
    a <- da[[cn]][match(keys, da$row_key)]
    b <- if (is.null(dr[[cn]])) rep(0, length(keys)) else dr[[cn]][match(keys, dr$row_key)]
    a[is.na(a)] <- 0
    b[is.na(b)] <- 0
    out[[cn]] <- a - b
  }
  rownames(out) <- NULL
  tab <- ta
  tab$data <- out
  tab$variant <- variant %||% res_a$meta$variant
  tab
}

# ---------------------------------------------------------------------------------------------
# Ergebnis (13.3)
# ---------------------------------------------------------------------------------------------

#' Vergleichskennzahlen, die als Differenzen je Lauf in `differences` stehen (12.6, 13.3)
#' @noRd
cmp_diff_kpis <- function() {
  c("delta_vs_reference", "delta_vs_reference_ex_rv", "payback_vs_reference",
    "payback_vs_reference_ex_rv", "co2_reduction", "monthly_saving_y1", "monthly_saving_avg10",
    "monthly_cashflow_change_y1", "warm_rent_change_y1")
}

#' Wahrscheinlichkeit „besser als Referenz“ je Differenzkennzahl (NA ohne Richtung)
#' @noRd
cmp_prob_better <- function(kpi, x) {
  if (length(x) == 0L || startsWith(kpi, "payback")) return(NA_real_)
  hib <- kpi_compare_specs()[[kpi_base_name(kpi)]]$hib %||% TRUE
  if (isTRUE(hib)) mean(!is.na(x) & x > 0) else mean(!is.na(x) & x < 0)
}

#' Ergebnisobjekt des Vergleichs zusammensetzen (13.3)
#' @noRd
cmp_assemble <- function(out, models, setup, comp, cautious, mode, n_sim, seed, allow_unequal,
                         t0) {
  cases <- setup$cases
  results <- out$results
  is_mc <- identical(mode, "mc")
  cmp_cases <- cases[cases$case != cases$reference, , drop = FALSE]
  kp_of <- function(r) if (inherits(r, "vofi_mc_result")) r$kpis else r$kpis
  # Differenzen je Lauf
  differences <- list()
  for (k in cmp_diff_kpis()) {
    cols <- lapply(cmp_cases$case, function(cs) {
      v <- kp_of(results[[cs]])[[k]]
      if (is.null(v)) NA_real_ else as.double(v)
    })
    if (all(vapply(cols, function(v) all(is.na(v)), logical(1)))) next
    nr <- max(vapply(cols, length, integer(1)))
    m <- matrix(NA_real_, nr, length(cols), dimnames = list(NULL, cmp_cases$case))
    for (j in seq_along(cols)) m[, j] <- rep_len(cols[[j]], nr)
    differences[[k]] <- m
  }
  if (is.null(differences$delta_vs_reference)) {
    differences$delta_vs_reference <- matrix(NA_real_, 1L, nrow(cmp_cases),
                                             dimnames = list(NULL, cmp_cases$case))
  }
  # Statistik der Differenzen
  ds <- list()
  for (k in names(differences)) {
    m <- differences[[k]]
    for (j in seq_len(ncol(m))) {
      cs <- colnames(m)[j]
      x <- m[, j]
      v <- x[!is.na(x)]
      q <- if (length(v) > 0L) stats::quantile(v, c(0.05, 0.25, 0.5, 0.75, 0.95), type = 7,
                                               names = FALSE) else rep(NA_real_, 5L)
      se <- NA_real_
      if (is_mc && length(v) > 1L) {
        blk <- results[[cs]]$kpis$block
        se <- mc_block_se(v, blk[!is.na(x)])$se
      }
      mv <- if (length(v) > 0L) mean(v) else NA_real_
      ds[[length(ds) + 1L]] <- data.frame(variant = cs, kpi = k, mean = mv, se = se,
                                          q05 = q[1L], q25 = q[2L], q50 = q[3L], q75 = q[4L],
                                          q95 = q[5L], prob_better = cmp_prob_better(k, x),
                                          stringsAsFactors = FALSE)
    }
  }
  diff_stats <- if (length(ds) > 0L) do.call(rbind, ds) else NULL
  # Kennzahltabelle
  kt <- list()
  for (cs in names(results)) {
    r <- results[[cs]]
    set <- cases$scenario_set[match(cs, cases$case)]
    if (is.na(set) && grepl("@", cs, fixed = TRUE)) set <- sub("^.*@", "", cs)
    if (inherits(r, "vofi_mc_result")) {
      st <- r$stats
      if (nrow(st) == 0L) next
      kt[[cs]] <- data.frame(variant = cs, scenario_set = set, kpi = st$kpi, value = st$mean,
                             mean = st$mean, q50 = st$q50, deterministic = st$deterministic,
                             na_share = st$na_share, stringsAsFactors = FALSE)
    } else {
      cols <- names(r$kpis)
      if (length(cols) == 0L) next
      kt[[cs]] <- data.frame(variant = cs, scenario_set = set, kpi = cols,
                             value = vapply(cols, function(k) as.double(r$kpis[[k]][1L]),
                                            double(1)),
                             na_reason = vapply(cols, function(k) {
                               as.character((r$kpi_na[[k]] %||% NA_character_)[1L])
                             }, ""), stringsAsFactors = FALSE)
    }
  }
  kpi_table <- do.call(rbind, unname(kt))
  rownames(kpi_table) <- NULL
  # Rangfolge (Fälle ohne Set; Referenz = 0)
  main <- c(setup$baseline, setup$variants)
  crit <- vapply(main, function(cs) {
    if (identical(cs, setup$baseline)) return(0)
    x <- differences$delta_vs_reference[, cs]
    if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
  }, double(1))
  ord <- order(-crit, method = "radix", na.last = TRUE)
  ranking <- data.frame(variant = main[ord], rank = seq_along(main),
                        criterion = "delta_vs_reference", value = crit[ord],
                        stringsAsFactors = FALSE)
  rownames(ranking) <- NULL
  # Differenz-VoFi (erste Variante gegen die Referenz)
  det_of <- function(cs) {
    r <- results[[cs]]
    if (inherits(r, "vofi_mc_result")) r$deterministic else r
  }
  dt <- cmp_diff_table(det_of(setup$variants[1L]), det_of(setup$baseline),
                       setup$variants[1L])
  notes <- character(0)
  if (!inherits(dt, "vofi_table")) {
    key <- if (identical(attr(dt, "note"), "grid")) "mc.compare.diff_grid" else
      "mc.compare.diff_unavailable"
    notes <- c(notes, lbl(key))
    dt <- NULL
  }
  # Ampel und Restriktionen je Fall gegen die Referenz
  tl <- list()
  rs <- list()
  for (cs in cmp_cases$case) {
    r <- results[[cs]]
    det <- det_of(cs)
    cz <- NULL
    for (s in names(setup$generated)) {
      inf <- cautious$info[[paste0(cs, "@", s)]]
      if (!is.null(inf) && !is.na(inf$value)) cz <- inf$value
    }
    p_base <- as.double(det$kpis$delta_vs_reference[1L])
    p_ex <- as.double((det$kpis$delta_vs_reference_ex_rv %||% det$kpis$delta_vs_reference)[1L])
    mcv <- if (inherits(r, "vofi_mc_result")) r$kpis$delta_vs_reference else NULL
    restr <- cmp_restrictions(det, if (is.null(mcv)) NULL else r$kpis)
    res_tl <- cmp_traffic_light_core(p_base, p_ex, mc = mcv, p_cautious = cz,
                                     restrictions = restr,
                                     thresholds = cmp_tl_thresholds(det$spec, det$grid),
                                     kpi = "delta_vs_reference")
    ko_codes <- res_tl$restrictions$code[res_tl$restrictions$ko]
    tl[[cs]] <- data.frame(variant = cs, level = res_tl$level, stage1 = res_tl$stage1,
                           basis = res_tl$basis, kpi = res_tl$kpi,
                           rv_dependent = res_tl$rv_dependent,
                           ko_codes = utl_collapse(ko_codes),
                           notes = utl_collapse(res_tl$notes, sep = "; "),
                           stringsAsFactors = FALSE)
    if (nrow(res_tl$restrictions) > 0L) {
      rs[[cs]] <- cbind(data.frame(variant = rep(cs, nrow(res_tl$restrictions)),
                                   stringsAsFactors = FALSE), res_tl$restrictions)
    }
  }
  traffic_light <- do.call(rbind, unname(tl))
  rownames(traffic_light) <- NULL
  restrictions <- if (length(rs) > 0L) do.call(rbind, unname(rs)) else
    data.frame(variant = character(0), code = character(0), violated_base = logical(0),
               prob = numeric(0), year = integer(0), value = numeric(0),
               threshold = numeric(0), ko = logical(0), stringsAsFactors = FALSE)
  rownames(restrictions) <- NULL
  # bedingte Ergebnisse (Entscheidungsknoten)
  conditional <- NULL
  if (is_mc && length(out$conditional) > 0L) {
    conditional <- do.call(rbind, unname(out$conditional))
  } else if (!is_mc) {
    cond <- list()
    for (cs in cmp_cases$case) {
      if (is.null(models[[cs]]$decision)) next
      d <- out$dets[[cs]]
      rf <- cmp_cases$reference[match(cs, cmp_cases$case)]
      for (b in c(1L, 0L)) {
        br <- if (b == 1L) d$approved else d$fallback
        # bedingter Vorteil je Zweig gegen die Referenz (Modus differential: eigenes dEW)
        dv <- cmp_compare_sides(br$side, out$dets[[rf]]$side)$kpis$delta_vs_reference[1L]
        cond[[length(cond) + 1L]] <- cmp_cond_row(cs, b, as.double(dv))
      }
    }
    if (length(cond) > 0L) conditional <- do.call(rbind, cond)
  }
  if (!is.null(conditional)) rownames(conditional) <- NULL
  meta <- list(seed = if (is_mc) out$cfg$seed else seed, n_sim = as.integer(n_sim),
               mode = mode, allow_unequal = allow_unequal, created = Sys.time(),
               cases = cases, variant_labels = setup$labels, cautious = cautious$info,
               notes = notes,
               runtime_sec = proc.time()[["elapsed"]] - t0,
               differential = any(vapply(models, function(m) {
                 identical(m$spec$project$comparison_mode, "differential")
               }, logical(1))))
  if (isTRUE(meta$differential)) meta$notes <- c(meta$notes, lbl("mc.compare.differential_note"))
  new_vofi_comparison(list(
    results = results, baseline = setup$baseline, variants = setup$variants,
    scenario_sets = setup$requested_sets, kpi_table = kpi_table, differences = differences,
    diff_stats = diff_stats, ranking = ranking, diff_table = dt, comparability = comp,
    traffic_light = traffic_light, restrictions = restrictions, conditional = conditional,
    crn = TRUE, meta = meta
  ))
}

# ---------------------------------------------------------------------------------------------
# Pflichtsensitivitäten (Spec 01 Teil C 4.4, R-82, R-107)
# ---------------------------------------------------------------------------------------------

#' Override einer Pflichtsensitivität (Schicht 8)
#'
#' `value`: ersetzt den Knoten am Pfad (auch eine Bezugsform mit `anchor`); `delta`: Zahl +
#' delta bzw. bei einer Bezugsform mit `anchor` der Anker + delta (Kopplung bleibt); `add`:
#' hängt Codes an eine Liste an. Mit dem Steuermodul `flat` ist eine Sensitivität auf
#' `accounts.deposit_withholding_tax_share` nicht anwendbar (Spec 00 10.7; das Modul versteuert
#' die Habenzinsen selbst).
#' @param spec aufgelöste Spezifikation (Basiswerte).
#' @param entry Eintrag `{id, path, label, value | delta | add}`.
#' @return Liste `overrides` (Pfadform) bzw. `NULL` (nicht anwendbar).
#' @noRd
cmp_mandatory_override <- function(spec, entry) {
  path <- entry$path
  # Steuermodul flat versteuert die Habenzinsen selbst (privat getrennt mit Abgeltungssatz,
  # Unternehmen im Ergebnis; Spec 00 10.7). Eine pauschale Abgeltungsteuer der Konten waere
  # dort Doppelbesteuerung (Validierungsfehler validation.tax_flat_withholding); die
  # Pflichtsensitivitaet `habenzins_abgeltung` (Profil kleinvermieter) ist nicht anwendbar.
  if (identical(path, "accounts.deposit_withholding_tax_share") &&
        identical(spec$tax$module, "flat")) {
    return(NULL)
  }
  node <- path_get(spec, path)
  if (!is.null(entry$value)) return(stats::setNames(list(entry$value), path))
  if (!is.null(entry$add)) {
    cur <- node
    if (is.list(cur) && !is.null(cur$value)) cur <- cur$value
    new <- unique(c(as.character(unlist(cur)), as.character(unlist(entry$add))))
    return(stats::setNames(list(new), path))
  }
  if (!is.null(entry$delta)) {
    d <- as.double(unlist(entry$delta))[1L]
    if (is.numeric(node) && !is.list(node)) return(stats::setNames(list(node + d), path))
    if (is.list(node) && identical(node$kind, "const") && is.numeric(node$value)) {
      return(stats::setNames(list(node$value + d), path))
    }
    if (is.list(node) && identical(node$kind, "ref") && !is.null(node$anchor)) {
      nd <- node[setdiff(names(node), "kind")]
      nd$anchor <- as.double(unlist(node$anchor))[1L] + d
      return(stats::setNames(list(nd), path))
    }
    v <- cmp_spec_value(spec, path)
    if (is.numeric(v)) return(stats::setNames(list(v[1L] + d), path))
  }
  NULL
}

#' Pflichtsensitivitäten (Spec 01 Teil C 4.4)
#'
#' Je Eintrag aus `analysis.mandatory_sensitivities` ein deterministischer Lauf mit dem Eintrag
#' als Override der Schicht 8 (neues Modell, Ableitungsregeln und `auto`-Beträge neu), bei
#' Vergleichen gemeinsam auf Variante und Referenz. Ausgabe: Primärkennzahl mit und ohne
#' Restwert, Differenz zum Basisfall und Status (`same_as_base`: Override ändert den Basiswert
#' nicht; `no_effect`: ohne Wirkung auf das Ergebnis; `computed`; `not_applicable`).
#' @param x `vofi_scenario`.
#' @param variant Variante.
#' @param reference `NULL` oder Referenzvariante (dann `delta_vs_reference`).
#' @return Data Frame `variant`, `id`, `label`, `path`, `kpi`, `base`, `base_ex_rv`, `value`,
#'   `value_ex_rv`, `diff`, `diff_ex_rv`, `status`.
#' @noRd
cmp_mandatory_sensitivities <- function(x, variant = "base", reference = NULL) {
  if (!inherits(x, "vofi_scenario")) {
    vofi_abort("mc.compare.not_scenario", arg = "x", .class = "vofi_error_input")
  }
  m0 <- vofi_build(x, variant = variant)
  r0 <- if (is.null(reference)) NULL else vofi_build(x, variant = reference)
  entries <- m0$spec$analysis$mandatory_sensitivities %||% list()
  kpi <- if (is.null(reference)) kpi_primary(m0$spec)$kpi else "delta_vs_reference"
  if (identical(kpi, "delta_vs_reference") && is.null(reference)) kpi <- "delta_terminal_value"
  eval_pair <- function(mv, mr) {
    if (is.null(mr)) {
      dv <- cmp_det_run(cmp_with_qt(mv))
      return(c(as.double(dv$result$kpis[[kpi]][1L]),
               as.double((dv$result$kpis[[paste0(kpi, "_ex_rv")]] %||%
                            dv$result$kpis[[kpi]])[1L])))
    }
    # Modus differential: Variante mit den negierten Zeilen der Referenz (9.6 Nr. 6)
    pr <- cmp_det_pair(cmp_with_qt(mv), cmp_with_qt(mr))
    cv <- cmp_compare_sides(pr$var$side, pr$ref$side)
    c(cv$kpis$delta_vs_reference[1L], cv$kpis$delta_vs_reference_ex_rv[1L])
  }
  base <- eval_pair(m0, r0)
  rows <- lapply(entries, function(e) {
    is_const <- function(v) {
      is.list(v) && !is.null(v$value) && !is.null(v$kind) && identical(v$kind, "const")
    }
    e <- lapply(e, function(v) if (is_const(v)) v$value else v)
    ov <- cmp_mandatory_override(m0$spec, e)
    id <- as.character(unlist(e$id %||% NA_character_))[1L]
    lab <- as.character(unlist(e$label %||% id))[1L]
    row <- data.frame(variant = variant, id = id, label = lab,
                      path = as.character(unlist(e$path))[1L], kpi = kpi, base = base[1L],
                      base_ex_rv = base[2L], value = NA_real_, value_ex_rv = NA_real_,
                      diff = NA_real_, diff_ex_rv = NA_real_, status = "not_applicable",
                      stringsAsFactors = FALSE)
    if (is.null(ov)) return(row)
    mv <- vofi_build(x, variant = variant, overrides = ov)
    same <- identical(stable_hash(path_get(mv$spec, e$path)),
                      stable_hash(path_get(m0$spec, e$path)))
    mr <- if (is.null(reference)) NULL else vofi_build(x, variant = reference, overrides = ov)
    val <- eval_pair(mv, mr)
    row$value <- val[1L]
    row$value_ex_rv <- val[2L]
    row$diff <- val[1L] - base[1L]
    row$diff_ex_rv <- val[2L] - base[2L]
    tol <- 1e-9 * max(1, abs(base), na.rm = TRUE)
    row$status <- if (same) "same_as_base" else
      if (isTRUE(abs(row$diff) <= tol && abs(row$diff_ex_rv) <= tol)) "no_effect" else
        "computed"
    row
  })
  if (length(rows) == 0L) {
    return(data.frame(variant = character(0), id = character(0), label = character(0),
                      path = character(0), kpi = character(0), base = numeric(0),
                      base_ex_rv = numeric(0), value = numeric(0), value_ex_rv = numeric(0),
                      diff = numeric(0), diff_ex_rv = numeric(0), status = character(0),
                      stringsAsFactors = FALSE))
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}
