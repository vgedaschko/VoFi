# Datentest der Parameterbibliothek inst/extdata/library (WS-L).
#
# Grundlage: Spec 00 Abschnitte 2.4 (test-library.R), 2.11 (Codes der Nutzlasten), 4.6 (Zahlen),
# 4.9 (Eintragsschema, from:), 4.10 (Freigaberegel); Spec 01 Teil C Abschnitte 2 (Prozess-
# bibliothek, Pruefwerte 2.8), 3.1 (Eintragsschema), 3.3 (Verzeichnis), 3.4-3.8 (Eintraege) und
# 5.0 (prices/referenzszenarien_2026); Teil A 4.2 und 8.3 (costs/massnahmentypen_2026).
#
# Gelesen wird mit einfachem YAML (readLines(UTF-8) + yaml::yaml.load()); der Bibliotheksresolver
# von WS-A wird nicht vorausgesetzt. Ketten (from:) werden mit deep_merge() (Integrator, Spec 00
# 4.7) aufgeloest: die Nutzlast des Ziels wird unter die eigene Nutzlast gemischt, ~ loescht.

# ---------------------------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------------------------

wsl_env <- new.env(parent = emptyenv())

#' Wurzel der Paketbibliothek
wsl_root <- function() {
  root <- system.file("extdata", "library", package = "vofi")
  if (!nzchar(root)) testthat::skip("Paketbibliothek inst/extdata/library nicht gefunden")
  root
}

#' YAML-Handler: nur true/false logisch (wie die Paketkataloge), ganze Zahlen als double
#' (numerische Ablage nach Spec 00 4.6; sonst wuerden gemischte Sequenzen wie [65, 170.66] Listen)
wsl_handlers <- function() {
  c(utl_yaml_handlers(), list("int" = function(x) as.double(x)))
}

#' Eine YAML-Datei einfach lesen (UTF-8, auch unter Locale C)
wsl_read <- function(file, handlers = wsl_handlers()) {
  txt <- readLines(file, encoding = "UTF-8", warn = FALSE)
  res <- yaml::yaml.load(paste(txt, collapse = "\n"), handlers = handlers, eval.expr = FALSE)
  if (is.null(res)) list() else res
}

#' Relative Pfade aller Eintragsdateien (C-Ordnung)
wsl_files <- function(root = wsl_root()) {
  utl_sort(list.files(root, pattern = "\\.yaml$", recursive = TRUE))
}

#' Alle Eintraege, benannt nach dem aus dem Dateipfad abgeleiteten id (einmal je Testlauf)
wsl_lib <- function() {
  if (is.null(wsl_env$lib)) {
    root <- wsl_root()
    files <- wsl_files(root)
    lib <- lapply(file.path(root, files), wsl_read)
    names(lib) <- sub("\\.yaml$", "", files)
    wsl_env$lib <- lib
  }
  wsl_env$lib
}

#' Nutzlast eines Eintrags mit aufgeloester from:-Kette (Spec 00 4.9)
wsl_payload <- function(id, lib = wsl_lib(), seen = character(0)) {
  if (id %in% seen) stop("from-Zyklus: ", paste(c(seen, id), collapse = " -> "), call. = FALSE)
  e <- lib[[id]]
  if (is.null(e)) stop("unbekannter Eintrag: ", id, call. = FALSE)
  if (is.null(e$from)) return(e$values)
  deep_merge(wsl_payload(e$from, lib, c(seen, id)), e$values)
}

#' Wert am Pfad der Nutzlast (mit Kette)
wsl_get <- function(id, path) path_get(wsl_payload(id), path)

wsl_ids_of <- function(folder, lib = wsl_lib()) {
  grep(paste0("^", folder, "/"), names(lib), value = TRUE)
}

wsl_is_date <- function(x) {
  is.character(x) && length(x) == 1L && grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x) &&
    !is.na(as.Date(x, format = "%Y-%m-%d"))
}

wsl_num <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x)

wsl_str <- function(x) utl_is_string(x) && nzchar(x)

#' Alle Blattpfade mit dem Wert x (z. B. Token "base")
wsl_paths_with_value <- function(x, value, path = "") {
  if (is.list(x)) {
    nms <- names(x)
    if (is.null(nms)) nms <- paste0("[", seq_along(x), "]")
    out <- lapply(seq_along(x), function(i) {
      wsl_paths_with_value(x[[i]], value, path_join(path, nms[i]))
    })
    return(unlist(out, use.names = FALSE) %||% character(0))
  }
  if (is.character(x) && length(x) == 1L && identical(x, value)) path else character(0)
}

#' Enthaelt ein Baum ein Objekt der Klasse cls (z. B. markierte Rohzahlen)?
wsl_has_class <- function(x, cls) {
  if (inherits(x, cls)) return(TRUE)
  is.list(x) && any(vapply(x, wsl_has_class, logical(1), cls = cls))
}

#' Alle Maps mit Schluessel `from` (Bibliotheksverweise) eines Baums
wsl_refs <- function(x, path = "") {
  out <- list()
  if (is.list(x)) {
    if (is_map(x) && length(x) > 0L && utl_has_name(x, "from")) {
      out[[length(out) + 1L]] <- list(from = x[["from"]], use = x[["use"]], path = path)
    }
    nms <- names(x)
    if (is.null(nms)) nms <- paste0("[", seq_along(x), "]")
    for (i in seq_along(x)) out <- c(out, wsl_refs(x[[i]], path_join(path, nms[i])))
  }
  out
}

# --- Verteilungen (Teil C 1.4) und Prozesse (Teil C 1.5, 1.6) --------------------------------

wsl_dist_params <- list(
  fixed = "value", normal = c("mean", "sd"), truncnorm = c("mean", "sd", "lower", "upper"),
  lognormal = c("meanlog", "sdlog", "mean", "sd", "median", "p90", "shift"),
  uniform = c("min", "max"), triangular = c("min", "mode", "max"),
  pert = c("min", "mode", "max", "lambda"),
  beta = c("shape1", "shape2", "mean", "sd", "min", "max"),
  bernoulli = "p", discrete = c("values", "probs"), empirical = "data"
)

#' Probleme einer Verteilungsangabe (leer = gueltig)
wsl_check_dist <- function(d, meta = c("dist", "label", "description", "apply", "base")) {
  type <- d[["dist"]]
  if (!utl_is_string(type) || !(type %in% names(wsl_dist_params))) {
    return(paste("unbekannter Verteilungstyp", format(type)))
  }
  par <- d[setdiff(names(d), meta)]
  p <- character(0)
  extra <- setdiff(names(par), wsl_dist_params[[type]])
  if (length(extra) > 0L) p <- c(p, paste("unbekannte Parameter:", paste(extra, collapse = ", ")))
  g <- function(nm, default = NULL) if (is.null(par[[nm]])) default else par[[nm]]
  has <- function(...) all(c(...) %in% names(par))
  ok <- switch(type,
    fixed = wsl_num(g("value")),
    normal = wsl_num(g("mean")) && wsl_num(g("sd")) && g("sd") >= 0,
    truncnorm = wsl_num(g("mean")) && wsl_num(g("sd")) && g("sd") >= 0 &&
      g("lower", -Inf) < g("upper", Inf),
    lognormal = sum(c(has("meanlog", "sdlog"), has("mean", "sd"), has("median", "p90"))) == 1L,
    uniform = wsl_num(g("min")) && wsl_num(g("max")) && g("min") <= g("max"),
    triangular = ,
    pert = wsl_num(g("min")) && wsl_num(g("mode")) && wsl_num(g("max")) &&
      g("min") <= g("mode") && g("mode") <= g("max") &&
      (is.null(par$lambda) || (wsl_num(par$lambda) && par$lambda > 0)),
    beta = xor(has("shape1", "shape2"), has("mean", "sd")) && g("min", 0) < g("max", 1),
    bernoulli = wsl_num(g("p")) && g("p") >= 0 && g("p") <= 1,
    discrete = {
      v <- g("values")
      pr <- g("probs", rep(1 / length(v), length(v)))
      is.numeric(v) && length(v) >= 1L && all(is.finite(v)) && !anyDuplicated(v) &&
        is.numeric(pr) && length(pr) == length(v) && all(pr >= 0) && abs(sum(pr) - 1) <= 1e-9
    },
    empirical = is.numeric(g("data")) && sum(is.finite(g("data"))) >= 2L
  )
  if (!isTRUE(ok)) p <- c(p, paste("ungueltige Parameter fuer", type))
  p
}

#' Traeger [unten, oben] einer gueltigen Verteilungsangabe
wsl_support <- function(d) {
  switch(d[["dist"]],
    fixed = c(d$value, d$value),
    normal = c(-Inf, Inf),
    truncnorm = c(d$lower %||% -Inf, d$upper %||% Inf),
    lognormal = c(d$shift %||% 0, Inf),
    uniform = , triangular = , pert = c(d$min, d$max),
    beta = c(d$min %||% 0, d$max %||% 1),
    bernoulli = c(0, 1),
    discrete = range(d$values),
    empirical = range(d$data)
  )
}

wsl_is_dist <- function(x) is_map(x) && utl_has_name(x, "dist")

#' Probleme einer statischen Overlay-Vorlage (Teil C 1.3)
wsl_check_static <- function(x) {
  p <- wsl_check_dist(x)
  if (length(p) > 0L) return(p)
  if (!is.null(x[["target"]])) p <- c(p, "Vorlage mit target (Teil C 2.1: ohne target)")
  if (!is.null(x[["apply"]])) {
    if (!(x[["apply"]] %in% vocab_codes("overlay_apply"))) {
      p <- c(p, paste("apply unbekannt:", x[["apply"]]))
    }
    neg <- !identical(x[["dist"]], "bernoulli") && wsl_support(x)[1L] < 0
    if (identical(x[["apply"]], "multiply") && neg) {
      p <- c(p, "apply: multiply mit negativem Traeger (R-94)")
    }
  }
  p
}

wsl_proc_params <- list(
  ar1 = list(req = c("mu", "phi", "sigma"), opt = "x0"),
  linked_ar1 = list(req = "base", opt = c("a", "b", "phi", "sigma", "u0")),
  vasicek = list(req = c("r0", "theta", "kappa", "sigma"), opt = "floor"),
  mr_trend = list(req = c("p0", "phi", "sigma"), opt = c("p_norm", "growth")),
  gbm = list(req = c("p0", "sigma"), opt = "growth"),
  scenario_mix = list(req = "scenarios", opt = "noise"),
  iid = list(req = "dist_spec", opt = character(0)),
  fixed_path = list(req = c("years", "values"), opt = character(0))
)
wsl_token_params <- c("x0", "u0", "r0", "p0", "p_norm")     # Teil C 1.5.1 (R-95)
wsl_unbounded_ok <- c("mu", "a", "b", "theta", "growth", "x0", "r0", "floor", "p0")  # 1.5.2

#' Probleme eines Prozessparameters (Zahl, Verteilung oder Token base)
wsl_check_proc_param <- function(nm, v) {
  if (identical(v, "base")) {
    return(if (nm %in% wsl_token_params) character(0) else paste(nm, ": Token base unzulaessig"))
  }
  open_lo <- FALSE                                    # Traeger links offen (lognormal)
  if (wsl_is_dist(v)) {
    p <- wsl_check_dist(v, meta = "dist")
    if (length(p) > 0L) return(paste(nm, ":", p))
    s <- wsl_support(v)
    lo <- s[1L]
    hi <- s[2L]
    open_lo <- identical(v[["dist"]], "lognormal")
  } else if (wsl_num(v)) {
    lo <- hi <- v
  } else {
    return(paste(nm, ": weder Zahl noch Verteilung noch Token"))
  }
  bounded <- is.finite(lo) && is.finite(hi)
  bad <- !bounded && !(nm %in% wsl_unbounded_ok)      # 1.5.2: unbeschraenkt nur fuer diese
  bad <- bad || switch(nm,
    phi = !(bounded && lo > -1 && hi < 1),
    sigma = lo < 0,
    kappa = !(lo > 0),
    p0 = , p_norm = !(lo > 0 || (open_lo && lo >= 0)),
    growth = is.finite(lo) && lo <= -1,
    FALSE
  )
  if (!isTRUE(bad)) return(character(0))
  paste(nm, ": Wert bzw. Traeger ausserhalb des zulaessigen Bereichs")
}

#' Probleme einer Prozessvorlage (Teil C 1.5, 1.6)
wsl_check_process <- function(x) {
  type <- x[["type"]]
  spec <- if (utl_is_string(type)) wsl_proc_params[[type]] else NULL
  if (is.null(spec)) return(paste("unbekannter Prozesstyp", format(type)))
  par <- x[setdiff(names(x), c("type", "label", "description"))]
  p <- character(0)
  miss <- setdiff(spec$req, names(par))
  if (length(miss) > 0L) p <- c(p, paste("fehlende Parameter:", paste(miss, collapse = ", ")))
  extra <- setdiff(names(par), c(spec$req, spec$opt))
  if (length(extra) > 0L) p <- c(p, paste("unbekannte Parameter:", paste(extra, collapse = ", ")))
  if (!is.null(x[["target"]])) p <- c(p, "Vorlage mit target")
  if (!is.null(x[["apply"]])) p <- c(p, "apply bei Prozessen unzulaessig (R-94)")
  scalar <- setdiff(names(par), c("base", "scenarios", "noise", "dist_spec", "years", "values"))
  for (nm in scalar) p <- c(p, wsl_check_proc_param(nm, par[[nm]]))
  base_ok <- utl_is_string(par$base) && grepl("^[a-z][a-z0-9_]*$", par$base)
  if (identical(type, "linked_ar1") && !base_ok) {
    p <- c(p, "linked_ar1.base ist kein Prozessschluessel")
  }
  if (identical(type, "vasicek") && wsl_num(par$floor) && wsl_num(par$r0) && par$floor > par$r0) {
    p <- c(p, "floor > r0")
  }
  if (identical(type, "scenario_mix")) {
    sc <- par$scenarios
    if (!is_map(sc) || length(sc) == 0L || !all(grepl("^[a-z][a-z0-9_]*$", names(sc)))) {
      p <- c(p, "scenarios ungueltig")
    } else {
      probs <- vapply(sc, function(s) if (wsl_num(s$prob)) s$prob else NA_real_, double(1))
      if (anyNA(probs) || any(probs < 0) || abs(sum(probs) - 1) > 1e-9) p <- c(p, "prob ungueltig")
      for (s in sc) {
        yrs <- s$years
        vals <- s$values
        ok_y <- is.numeric(yrs) && length(yrs) >= 1L && all(diff(yrs) > 0)
        ok_v <- is.numeric(vals) && length(vals) == length(yrs) && all(is.finite(vals))
        if (!(ok_y && ok_v)) p <- c(p, "Szenariopfad ungueltig")
      }
    }
  }
  if (identical(type, "iid")) p <- c(p, wsl_check_dist(par$dist_spec, meta = "dist"))
  if (identical(type, "fixed_path")) {
    ok <- is.numeric(par$years) && all(diff(par$years) > 0) &&
      length(par$values) == length(par$years)
    if (!ok) p <- c(p, "fixed_path ungueltig")
  }
  p
}

#' Vorlagen einer processes/*-Nutzlast: NULL bei Korrelationsliste, sonst benannte Liste
#' (exakter Zugriff: values$dist traefe sonst die Vorlage district_heating)
wsl_templates <- function(values) {
  if (is.null(names(values))) return(NULL)
  if (!is.null(values[["type"]]) || !is.null(values[["dist"]])) return(list(.single = values))
  values
}

# --- Kleine Rechenhilfen fuer Pruefwerte ----------------------------------------------------

wsl_annuity <- function(k, i, n) k * i / (1 - (1 + i)^-n)

wsl_pert <- function(a, c, b, lambda = 4) {
  al <- 1 + lambda * (c - a) / (b - a)
  be <- 1 + lambda * (b - c) / (b - a)
  m <- (a + lambda * c + b) / (lambda + 2)
  list(mean = m, sd = sqrt((m - a) * (b - m) / (lambda + 3)),
       q = function(p) a + (b - a) * stats::qbeta(p, al, be))
}

wsl_tri_q <- function(u, a, c, b) {
  if (b == a) return(rep(a, length(u)))
  fc <- (c - a) / (b - a)
  ifelse(u < fc, a + sqrt(u * (b - a) * (c - a)), b - sqrt((1 - u) * (b - a) * (b - c)))
}

#' Monate zwischen zwei Daten (erster Tag; Antragsdatum, Teil C 3.4 Degression)
wsl_months <- function(from, to) {
  f <- as.POSIXlt(as.Date(from))
  t <- as.POSIXlt(as.Date(to))
  (t$year - f$year) * 12L + (t$mon - f$mon) - as.integer(t$mday < f$mday)
}

#' Wert nach einer Degressionsregel {start, step, every_months, floor} zum Antragsdatum
wsl_degressed <- function(base, rule, date) {
  n <- if (as.Date(date) < as.Date(rule$start)) {
    0L
  } else {
    wsl_months(rule$start, date) %/% rule$every_months + 1L
  }
  max(rule$floor, base + rule$step * n)
}

#' Foerderfaehige Kosten einer Staffel je Gebaeude (Teil C 3.4, KfW 458/459)
wsl_caps_total <- function(tiers, n_units) {
  sum(vapply(tiers, function(t) {
    cnt <- max(0, min(n_units, t$units_to) - t$units_from + 1)
    cnt * t$cap_eur
  }, double(1)))
}

wsl_canonical_markets <- function() {
  c("inflation", "mortgage_rate", "bund_yield_10y", "mortgage_spread", "rent_growth",
    "rent_growth_new", "construction_price_index", "maintenance_index", "land_value_growth",
    "market_value_growth", "operating_cost_growth", "co2_price", "bio_fuel_premium",
    "energy_price", "energy_network_fee", "feed_in_tariff", "vacancy_fluctuation")
}

wsl_carriers <- function() {
  c("gas", "gas_mfh", "oil", "lpg", "power", "power_mfh", "heatpump_power",
    "heatpump_power_mfh", "district_heating", "pellets")
}

#' Verzeichnis der v1-Eintraege (Teil C 2.1 und 3.3)
wsl_expected_ids <- function() {
  ids <- list(
    processes = c(
      "inflation_ar1_2026", "mortgage_rate_vasicek_2026", "bund10_vasicek_2026",
      "mortgage_spread_ar1_2026", "rent_growth_linked_2026", "rent_growth_new_linked_2026",
      "construction_price_linked_2026", "maintenance_cost_linked_2026", "energy_prices_mr_2026",
      "co2_price_corridor_2026", "shock_correlations_2026", "param_correlations_2026",
      "cost_risks_2026", "energy_performance_2026", "funding_risks_2026", "valuation_risks_2026"
    ),
    funding = c(
      "kfw_261_wg_kredit_2026", "kfw_261_eh40", "kfw_261_eh55", "kfw_261_eh70", "kfw_261_eh85",
      "kfw_261_denkmal", "kfw_458_heizung_privat", "kfw_459_heizung_unternehmen",
      "kfw_358_ergaenzungskredit_plus", "kfw_359_ergaenzungskredit", "kfw_297_khn_selbstnutzung",
      "kfw_298_khn_vermietung", "kfw_297_khn_eh55_stufe", "kfw_298_khn_eh55_stufe",
      "kfw_300_wohneigentum_familien", "kfw_308_jung_kauft_alt", "bafa_beg_em_huelle",
      "bafa_beg_em_fachplanung", "estg_35c"
    ),
    legal = c(
      "mietrecht_2026", "mietrecht_559f_2026", "mietrecht_ii_reform", "co2kostaufg_2026",
      "gmodg_bio_treppe_2026", "gmodg_bio_treppe_2045", "behg_ets2_2026",
      "emission_factors_geg_anlage9", "emission_factors_co2cost_2026", "grunderwerbsteuer_2026",
      "umsatzsteuer_2026"
    ),
    prices = c(
      "energy_prices_2026", "co2_price_paths_2026", "co2_price_path_referenzszenarien_2026",
      "interest_rates_2026_10", "macro_paths_2026", "eeg_feed_in_2026", "referenzszenarien_2026"
    ),
    costs = c(
      "massnahmentypen_2026", "bewirtschaftung_ii_bv_2026", "bewirtschaftung_immowertv_2026",
      "betriebskosten_benchmarks_2026", "baukosten_neubau_2026", "kostenzuschlaege_2026",
      "kostenfunktionen_sanierung_iwu_2026", "anlagentechnik_marktpreise_2026",
      "sanierung_eh_pakete_2026", "nutzungsdauern_2026", "wartung_instandsetzung_vdi2067_2026",
      "erwerbsnebenkosten_2026"
    ),
    valuation = c(
      "liegenschaftszinsen_2026", "immowertv_anlage1_2_2026", "verkaufskosten_2026",
      "kaufpreisfaktoren_2026"
    )
  )
  unlist(lapply(names(ids), function(f) paste0(f, "/", ids[[f]])), use.names = FALSE)
}

wsl_root_keys <- c("id", "block", "topic", "schema_version", "label", "description", "source",
                   "references", "as_of", "accessed", "valid_from", "valid_to", "quality",
                   "quality_detail", "legal_state", "reform", "release", "uncertainty", "from",
                   "fallback", "notes", "values")
wsl_required_keys <- c("id", "block", "schema_version", "label", "source", "as_of", "valid_from",
                       "valid_to", "quality", "values")
wsl_folder_block <- c(funding = "funding", legal = "legal", prices = "market", costs = "costs",
                      processes = "processes", valuation = "valuation")
wsl_topics_v1 <- c("mietrecht", "mietrecht_559f", "co2kostaufg", "bio_treppe", "co2_pricing",
                   "emission_factors_geg", "emission_factors_co2cost", "grunderwerbsteuer",
                   "umsatzsteuer")

#' Automatische Rechtsstandsauswahl (Spec 00 4.10) als Testorakel
wsl_select_legal <- function(topic, date, pending = character(0), lib = wsl_lib()) {
  date <- as.Date(date)
  cand <- Filter(function(id) identical(lib[[id]]$topic, topic), wsl_ids_of("legal", lib))
  ok <- vapply(cand, function(id) {
    e <- lib[[id]]
    valid <- as.Date(e$valid_from) <= date && (is.null(e$valid_to) || date < as.Date(e$valid_to))
    if (!valid) return(FALSE)
    if (!is.null(e$reform)) return(e$reform %in% pending)
    if (e$quality %in% c("A", "B")) return(TRUE)
    if (identical(e$quality, "C")) {
      return(identical(e$release$status, "released") || "unreleased" %in% pending)
    }
    FALSE
  }, logical(1))
  cand <- cand[ok]
  if (length(cand) == 0L) return(NULL)
  with_reform <- cand[!vapply(lib[cand], function(e) is.null(e$reform), logical(1))]
  pool <- if (length(with_reform) > 0L) with_reform else cand
  vf <- as.Date(vapply(lib[pool], function(e) e$valid_from, character(1)))
  pool[order(vf, decreasing = TRUE)][1L]
}

# --- Overlay mit allen Vorlagen (Teil C 2.8 Nr. 4) und Listing-Abgleich ---------------------

#' Ziele, die Schicht 1 (global.yaml, Teil A 2.2) fuer das Walking Skeleton bereitstellt
#' (neben market.<name>): Baukostenfaktor und Bauzeitverzug des Projekts, Netzentgeltwachstum
wsl_layer1_targets <- c("project.construction_cost_factor", "project.construction_delay_months",
                        "shared.network_fee_growth_gas")

#' Overlay mit jeder Vorlage jeder Datei in processes/ genau einmal (Teil C 2.8 Nr. 4).
#'
#' Schluessel nach Teil C 1.10.2 (Prozessschluessel = Marktname mit _; statisch <thema>_<objekt>,
#' so dass die Bibliothekspaare [delay_construction, cost_construction] und [prebound, rebound]
#' wirksam sind). Ziele: market.<name> und die Projektfelder aus Schicht 1; statische Vorlagen
#' ohne passendes Feld im Skeleton zielen auf shared.<name> (Teil C 1.9, Spec 00 4.5 Regel 4)
#' mit dem Basiswert aus `shared` (bei apply: replace im Traeger, bei add 0, bei multiply
#' der Satz bzw. Faktor). Ergebnis: list(stochastic, shared).
wsl_overlay_all <- function() {
  ref <- function(target, id, use = NULL) {
    x <- list(target = target, from = id)
    if (!is.null(use)) x$use <- use
    x
  }
  cr <- "processes/cost_risks_2026"
  ep <- "processes/energy_performance_2026"
  fr <- "processes/funding_risks_2026"
  vr <- "processes/valuation_risks_2026"
  mr <- "processes/energy_prices_mr_2026"
  processes <- list(
    inflation = ref("market.inflation", "processes/inflation_ar1_2026"),
    mortgage_rate = ref("market.mortgage_rate", "processes/mortgage_rate_vasicek_2026"),
    bund_yield_10y = ref("market.bund_yield_10y", "processes/bund10_vasicek_2026"),
    mortgage_spread = ref("market.mortgage_spread", "processes/mortgage_spread_ar1_2026"),
    rent_growth = ref("market.rent_growth", "processes/rent_growth_linked_2026"),
    rent_growth_new = ref("market.rent_growth_new", "processes/rent_growth_new_linked_2026"),
    construction_price_index = ref("market.construction_price_index",
                                   "processes/construction_price_linked_2026"),
    maintenance_index = ref("market.maintenance_index", "processes/maintenance_cost_linked_2026"),
    co2_price = ref("market.co2_price", "processes/co2_price_corridor_2026"),
    vacancy_fluctuation = ref("market.vacancy_fluctuation", vr, "vacancy_fluctuation")
  )
  for (c in wsl_carriers()) {
    processes[[paste0("energy_price_", c)]] <- ref(paste0("market.energy_price.", c), mr, c)
  }
  parameters <- list(
    bio_premium = ref("market.bio_fuel_premium", mr, "bio_premium_factor"),
    network_fee_growth = ref("shared.network_fee_growth_gas", mr, "network_fee_growth"),
    # Kosten- und Terminrisiken (Skeleton: neubau)
    cost_construction = ref("project.construction_cost_factor", cr, "overrun_newbuild"),
    cost_retrofit = ref("shared.cost_factor_retrofit", cr, "overrun_retrofit"),
    cost_component = ref("shared.cost_factor_component", cr, "overrun_component"),
    delay_construction = ref("project.construction_delay_months", cr, "delay_newbuild"),
    delay_retrofit = ref("shared.delay_months_retrofit", cr, "delay_retrofit"),
    maintenance_level = ref("shared.maintenance_rate_eur_m2_pa", cr, "maintenance_level"),
    # Performance Gap und realisierte JAZ
    prebound = ref("shared.prebound_factor", ep, "prebound"),
    rebound = ref("shared.rebound_factor", ep, "rebound"),
    rebound_calculated = ref("shared.rebound_factor_calculated", ep, "rebound_calculated"),
    realisation = ref("shared.realisation_factor", ep, "realisation"),
    jaz_air_water_existing = ref("shared.jaz_air_water_existing", ep, "jaz_air_water_existing"),
    jaz_air_water_newbuild = ref("shared.jaz_air_water_newbuild", ep, "jaz_air_water_newbuild"),
    jaz_ground_existing = ref("shared.jaz_ground_existing", ep, "jaz_ground_existing"),
    jaz_air_water_mfh_central = ref("shared.jaz_air_water_mfh_central", ep,
                                    "jaz_air_water_mfh_central"),
    jaz_relative = ref("shared.jaz_factor", ep, "jaz_relative"),
    # Foerder- und Verguetungsrisiken
    funding_available = ref("shared.funding_available_after_2030", fr, "availability_after_2030"),
    feed_in_continuation = ref("shared.feed_in_factor", fr, "feed_in_continuation"),
    payout_delay = ref("shared.payout_delay_months", fr, "payout_delay"),
    repayment_grant_cut = ref("shared.repayment_grant_cut_share", fr, "repayment_grant_cut"),
    # Restwert- und Leerstandsrisiken (K7, K9)
    cap_rate_rv = ref("shared.cap_rate_shock", vr, "cap_rate_shock"),
    rnd_rv = ref("shared.remaining_life_offset_years", vr, "remaining_life_shock"),
    vacancy_level = ref("shared.vacancy_level", vr, "vacancy_level"),
    value_uplift = ref("shared.market_value_uplift_efficiency", vr,
                       "market_value_uplift_efficiency")
  )
  shared <- list(
    cost_factor_retrofit = 1, cost_factor_component = 1, delay_months_retrofit = 0,
    maintenance_rate_eur_m2_pa = wsl_get("costs/bewirtschaftung_immowertv_2026",
                                         "maintenance_eur_m2_pa"),
    prebound_factor = 0.7, rebound_factor = 1.0, rebound_factor_calculated = 1.1,
    realisation_factor = 0.8, jaz_air_water_existing = 3.2, jaz_air_water_newbuild = 3.8,
    jaz_ground_existing = 4.0, jaz_air_water_mfh_central = 2.9, jaz_factor = 1,
    funding_available_after_2030 = 1, feed_in_factor = 1, payout_delay_months = 0,
    repayment_grant_cut_share = 0, cap_rate_shock = 0, remaining_life_offset_years = 0,
    vacancy_level = 0.02, market_value_uplift_efficiency = 0.03
  )
  list(
    stochastic = list(
      processes = processes,
      parameters = parameters,
      correlations = list(shocks = list(from = "processes/shock_correlations_2026"),
                          parameters = list(from = "processes/param_correlations_2026"))
    ),
    shared = shared
  )
}

#' Vorlage eines Overlay-Eintrags {from, use}
wsl_template_of <- function(x, lib = wsl_lib()) {
  v <- lib[[x$from]]$values
  if (is.null(x$use)) v else v[[x$use]]
}

#' Eintrag und Spec-Listing fuer den Vergleich angleichen (dokumentierte Abweichungen).
#' prices/energy_prices_2026: vat_rate.pellets nach Teil B 7.3 (F-16); dem Listing in Teil C 3.6
#' fehlt der Schluessel (Aenderungsantrag an Teil C). Die Ausnahme greift nur, solange das Listing
#' den Schluessel nicht enthaelt; danach zaehlt die Reihenfolge der Map vat_rate nicht.
wsl_listing_pair <- function(id, actual, listing) {
  if (identical(id, "prices/energy_prices_2026") && is_map(actual$values$vat_rate)) {
    if (is.null(listing$values$vat_rate$pellets)) {
      actual$values$vat_rate$pellets <- NULL
    } else if (is_map(listing$values$vat_rate)) {
      ord <- function(m) m[utl_sort(names(m))]
      actual$values$vat_rate <- ord(actual$values$vat_rate)
      listing$values$vat_rate <- ord(listing$values$vat_rate)
    }
  }
  list(actual = actual, listing = listing)
}

# ---------------------------------------------------------------------------------------------
# Bibliotheksstand, Verzeichnis, Lesbarkeit
# ---------------------------------------------------------------------------------------------

test_that("VERSION: eine Zeile JJJJ.MM.n, Stand 2026.10.2 (Spec 00 4.9, R-80)", {
  f <- file.path(wsl_root(), "VERSION")
  expect_true(file.exists(f))
  v <- readLines(f, warn = FALSE)
  expect_length(v, 1L)
  expect_match(v, "^[0-9]{4}\\.(0[1-9]|1[0-2])\\.[1-9][0-9]*$")
  expect_identical(v, "2026.10.2")
})

test_that("Verzeichnis der v1-Eintr\u00e4ge vollst\u00e4ndig, keine fremden Dateien (Teil C 3.3)", {
  root <- wsl_root()
  all_files <- utl_sort(list.files(root, recursive = TRUE, all.files = TRUE))
  expect_setequal(all_files, c("VERSION", paste0(wsl_expected_ids(), ".yaml")))
  ids <- names(wsl_lib())
  expect_setequal(ids, wsl_expected_ids())
  expect_length(ids, 69L)
  counts <- table(sub("/.*$", "", ids))
  folders <- c("costs", "funding", "legal", "prices", "processes", "valuation")
  expect_identical(as.integer(counts[folders]), c(12L, 19L, 11L, 7L, 16L, 4L))
})

test_that("Eintr\u00e4ge sind UTF-8 und parsen unter der Locale C identisch (Spec 00 4.6)", {
  root <- wsl_root()
  files <- wsl_files(root)
  for (f in files) {
    raw <- readBin(file.path(root, f), "raw", file.info(file.path(root, f))$size)
    expect_false(identical(raw[1:3], as.raw(c(0xef, 0xbb, 0xbf))), info = paste(f, "BOM"))
    txt <- readLines(file.path(root, f), encoding = "UTF-8", warn = FALSE)
    expect_true(all(validUTF8(txt)), info = f)
    expect_false(any(grepl("\t", txt, fixed = TRUE)), info = paste(f, "Tabulator"))
    expect_identical(raw[length(raw)], as.raw(0x0a), info = paste(f, "Zeilenende"))
  }
  lib_c <- withr::with_locale(c(LC_CTYPE = "C", LC_COLLATE = "C"), {
    res <- lapply(file.path(root, files), wsl_read)
    names(res) <- sub("\\.yaml$", "", files)
    res
  })
  expect_identical(lib_c, wsl_lib())
})

test_that("Eintr\u00e4ge parsen im Subprozess mit LANG=C und LANG=C.UTF-8 identisch", {
  skip_on_cran()
  skip_on_os("windows")
  rscript <- file.path(R.home("bin"), "Rscript")
  skip_if_not(file.exists(rscript), "Rscript nicht gefunden")
  root <- normalizePath(wsl_root())
  for (lang in c("C", "C.UTF-8")) {
    out <- withr::local_tempfile(fileext = ".rds")
    code <- paste0(
      "root <- ", deparse(root), "; ",
      "files <- sort(list.files(root, pattern = \"[.]yaml$\", recursive = TRUE), ",
      "method = \"radix\"); ",
      "h <- list(\"bool#yes\" = function(x) if (identical(tolower(x), \"true\")) TRUE else x, ",
      "\"bool#no\" = function(x) if (identical(tolower(x), \"false\")) FALSE else x, ",
      "\"int\" = function(x) as.double(x)); ",
      "res <- lapply(file.path(root, files), function(f) yaml::yaml.load(paste(readLines(f, ",
      "encoding = \"UTF-8\", warn = FALSE), collapse = \"\\n\"), handlers = h, ",
      "eval.expr = FALSE)); ",
      "names(res) <- sub(\"[.]yaml$\", \"\", files); ",
      "saveRDS(list(ctype = Sys.getlocale(\"LC_CTYPE\"), lib = res), ", deparse(out), ")"
    )
    log <- suppressWarnings(system2(rscript, c("--vanilla", "-e", shQuote(code)),
                                    env = c(paste0("LANG=", lang), paste0("LC_ALL=", lang)),
                                    stdout = TRUE, stderr = TRUE))
    expect_true(file.exists(out), info = paste(lang, paste(log, collapse = "\n")))
    if (!file.exists(out)) next
    res <- readRDS(out)
    if (identical(lang, "C")) expect_identical(res$ctype, "C")
    expect_identical(res$lib, wsl_lib(), info = lang)
  }
})

test_that("keine mehrdeutigen Zahlen (Tausenderpunkt, Dezimalkomma, f\u00fchrende Null; 4.6)", {
  root <- wsl_root()
  for (f in wsl_files(root)) {
    hits <- character(0)
    h <- c(utl_yaml_handlers(), list(
      "float#fix" = function(x) {
        if (grepl("^[-+]?[1-9][0-9]{0,2}[.][0-9]{3}$", x)) hits <<- c(hits, x)
        as.numeric(x)
      },
      "int" = function(x) {
        if (!grepl("^[-+]?(0|[1-9][0-9]*)$", x)) hits <<- c(hits, x)
        as.numeric(x)
      },
      "int#oct" = function(x) {
        hits <<- c(hits, x)
        x
      }
    ))
    wsl_read(file.path(root, f), handlers = h)
    expect_identical(hits, character(0), info = f)
  }
})

test_that("Paketleser io_read_yaml_utf8() liest alle Eintr\u00e4ge ohne Meldung (Spec 00 4.6)", {
  skip_if_not(exists("io_read_yaml_utf8", mode = "function"), "io_read_yaml_utf8() fehlt")
  root <- wsl_root()
  for (f in wsl_files(root)) {
    x <- NULL
    expect_no_condition(x <- io_read_yaml_utf8(file.path(root, f)))
    expect_false(wsl_has_class(x, "vofi_raw_num"), info = f)
    expect_equal(x, wsl_lib()[[sub("\\.yaml$", "", f)]], info = f)   # int/double gleich
  }
})

# ---------------------------------------------------------------------------------------------
# Eintragsschema (Spec 00 4.9, Teil C 3.1)
# ---------------------------------------------------------------------------------------------

test_that("Eintragsschema: Pflichtfelder, Wurzelschl\u00fcssel, id = Dateipfad, block = Ordner", {
  lib <- wsl_lib()
  for (id in names(lib)) {
    e <- lib[[id]]
    info <- id
    expect_true(is_map(e), info = info)
    expect_true(all(names(e) %in% wsl_root_keys),
                info = paste(id, paste(setdiff(names(e), wsl_root_keys), collapse = ", ")))
    expect_true(all(wsl_required_keys %in% names(e)),
                info = paste(id, paste(setdiff(wsl_required_keys, names(e)), collapse = ", ")))
    expect_identical(e$id, id, info = info)
    expect_match(e$id, utl_library_id_pattern())
    expect_true(all(grepl("^[a-z][a-z0-9_]*$", strsplit(id, "/", fixed = TRUE)[[1L]])), info = info)
    folder <- sub("/.*$", "", id)
    expect_true(e$block %in% vocab_codes("library_block"), info = info)
    expect_identical(e$block, unname(wsl_folder_block[folder]), info = info)
    expect_equal(e$schema_version, 1, info = info)
    expect_true(wsl_str(e$label), info = info)
    expect_true(is.null(e$description) || wsl_str(e$description), info = info)
    expect_true(is.null(e$notes) || wsl_str(e$notes), info = info)
    expect_false(is.null(e$values), info = info)
  }
})

test_that("Eintragsschema: Quellen, Datumsfelder, G\u00fcltigkeit [valid_from, valid_to)", {
  lib <- wsl_lib()
  src_keys <- c("document", "url", "publisher", "section", "date")
  check_source <- function(s, info) {
    expect_true(is_map(s), info = info)
    expect_true(all(names(s) %in% src_keys), info = info)
    expect_true(wsl_str(s$document), info = info)
    expect_true(wsl_str(s$publisher), info = info)
    expect_true(is.null(s$url) || wsl_str(s$url), info = info)
  }
  stand_end <- as.Date("2026-10-31")      # Bibliotheksstand 2026.10.n
  for (id in names(lib)) {
    e <- lib[[id]]
    check_source(e$source, paste(id, "source"))
    for (r in e$references %||% list()) check_source(r, paste(id, "references"))
    expect_true(wsl_is_date(e$as_of), info = id)
    expect_true(as.Date(e$as_of) <= stand_end, info = id)
    expect_true(is.null(e$accessed) || (wsl_is_date(e$accessed) &&
                                          as.Date(e$accessed) <= as.Date(e$as_of)), info = id)
    expect_true(wsl_is_date(e$valid_from), info = id)
    expect_true("valid_to" %in% names(e), info = id)
    if (!is.null(e$valid_to)) {
      expect_true(wsl_is_date(e$valid_to), info = id)
      expect_true(as.Date(e$valid_to) > as.Date(e$valid_from), info = id)
    }
    expect_true(e$quality %in% vocab_codes("quality"), info = id)
  }
  # Prozess- und Kalibrierungseintraege: valid_from 2026-01-01, valid_to null (Teil C 2.1)
  for (id in wsl_ids_of("processes")) {
    expect_identical(lib[[id]]$valid_from, "2026-01-01", info = id)
    expect_null(lib[[id]]$valid_to)
  }
  # Gueltigkeiten nach dem Verzeichnis 3.3
  v <- function(id) c(lib[[id]]$valid_from, lib[[id]]$valid_to %||% NA_character_)
  expect_identical(v("funding/kfw_298_khn_eh55_stufe"), c("2026-04-10", "2027-01-01"))
  expect_identical(v("funding/kfw_297_khn_eh55_stufe"), c("2026-04-10", "2027-01-01"))
  expect_identical(v("funding/estg_35c"), c("2020-01-01", "2030-01-01"))
  expect_identical(v("prices/eeg_feed_in_2026"), c("2026-08-01", "2027-02-01"))
  expect_identical(v("costs/bewirtschaftung_ii_bv_2026"), c("2026-01-01", "2029-01-01"))
  expect_identical(v("costs/bewirtschaftung_immowertv_2026"), c("2026-01-01", NA_character_))
  expect_identical(v("legal/emission_factors_geg_anlage9"), c("2023-01-01", NA_character_))
  expect_identical(v("valuation/immowertv_anlage1_2_2026"), c("2022-01-01", NA_character_))
  expect_identical(v("legal/grunderwerbsteuer_2026"), c("2025-07-01", NA_character_))
})

test_that("Eintragsschema: topic, legal_state, reform, release (Spec 00 4.9, 4.10; N-28)", {
  lib <- wsl_lib()
  for (id in names(lib)) {
    e <- lib[[id]]
    folder <- sub("/.*$", "", id)
    if (folder == "legal") {
      expect_true(wsl_str(e$topic) && e$topic %in% wsl_topics_v1, info = id)
    } else {
      expect_null(e$topic)
    }
    if (folder %in% c("legal", "funding")) expect_false(is.null(e$legal_state), info = id)
    if (!is.null(e$legal_state)) {
      ls <- e$legal_state
      expect_setequal(names(ls), c("as_of", "status", "reference"))
      expect_true(wsl_is_date(ls$as_of), info = id)
      expect_true(ls$status %in% vocab_codes("legal_status"), info = id)
      expect_true(wsl_str(ls$reference), info = id)
      if (identical(ls$status, "pending")) expect_false(is.null(e$reform), info = id)
    }
    if (!is.null(e$reform)) {
      expect_true(e$reform %in% vocab_codes("reform"), info = id)
      expect_true(e$legal_state$status %in% c("pending", "derived"), info = id)
      expect_identical(folder, "legal")
    }
    if (!is.null(e$release)) {
      expect_setequal(names(e$release), c("status", "by", "date"))
      expect_true(e$release$status %in% vocab_codes("release_status"), info = id)
      if (identical(e$release$status, "released")) {
        expect_true(wsl_str(e$release$by) && wsl_is_date(e$release$date), info = id)
      }
    }
  }
  # Themen v1 (Teil C 3.5): jedes Thema hat mindestens einen Eintrag
  topics <- vapply(lib[wsl_ids_of("legal")], function(e) e$topic, character(1))
  expect_setequal(unique(topics), wsl_topics_v1)
})

test_that("Eintragsschema: quality_detail und uncertainty verweisen auf vorhandene Unterpfade", {
  lib <- wsl_lib()
  for (id in names(lib)) {
    e <- lib[[id]]
    payload <- wsl_payload(id)
    qd <- e$quality_detail %||% list()
    expect_true(is_map(qd), info = id)
    for (p in names(qd)) {
      expect_true(qd[[p]] %in% vocab_codes("quality"), info = paste(id, p))
      expect_true(path_exists(payload, p), info = paste(id, "quality_detail", p))
    }
    unc <- e$uncertainty %||% list()
    expect_true(is_map(unc), info = id)
    for (p in names(unc)) {
      expect_true(path_exists(payload, p), info = paste(id, "uncertainty", p))
      expect_identical(wsl_check_static(unc[[p]]), character(0), info = paste(id, p))
    }
  }
})

test_that("uncertainty-Vorlagen: Modus = deterministischer Basiswert (1.11 mode_differs_base)", {
  lib <- wsl_lib()
  n <- 0L
  for (id in names(lib)) {
    unc <- lib[[id]]$uncertainty %||% list()
    for (p in names(unc)) {
      u <- unc[[p]]
      replace <- is.null(u[["apply"]]) || u[["apply"]] == "replace"
      if (!(u[["dist"]] %in% c("triangular", "pert")) || !replace) next
      base <- wsl_get(id, p)
      expect_true(wsl_num(base), info = paste(id, p))
      expect_equal(u$mode, base, tolerance = 1e-12, info = paste(id, p))
      n <- n + 1L
    }
  }
  expect_gt(n, 40L)
  # Niveaufaktor auf den Gaspfad (apply: multiply): Modus 1, Spanne aus 10,5-15,5 ct brutto
  g <- lib[["prices/energy_prices_2026"]]$uncertainty$market.energy_price.gas
  expect_identical(g$apply, "multiply")
  expect_equal(g$mode, 1)
  p0 <- lib[["prices/energy_prices_2026"]]$values$market$energy_price$gas$start
  co2 <- 0.1814 * 0.065
  expect_equal(g$min, (0.105 / 1.19 - co2 - 0.0257) / p0, tolerance = 2e-3)
  expect_equal(g$max, (0.155 / 1.19 - co2 - 0.0257) / p0, tolerance = 2e-3)
})

test_that("fallback dokumentiert jedes Token base (Teil C 1.5.1, 2.8 Nr. 4; R-88, R-95)", {
  lib <- wsl_lib()
  for (id in names(lib)) {
    e <- lib[[id]]
    tokens <- wsl_paths_with_value(e$values, "base")
    if (length(tokens) == 0L) {
      expect_null(e$fallback)
      next
    }
    expect_identical(sub("/.*$", "", id), "processes")
    leaves <- path_leaves(e$fallback)
    expect_setequal(leaves, tokens)
    for (p in leaves) expect_true(wsl_num(path_get(e$fallback, p)), info = paste(id, p))
    # Token nur an Startparametern (x0, u0, r0, p0, p_norm)
    last <- vapply(strsplit(tokens, ".", fixed = TRUE), function(s) s[length(s)], character(1))
    expect_true(all(last %in% wsl_token_params), info = id)
  }
})

test_that("from-Ketten: Ziel existiert, gleicher Block, kein Zyklus (Spec 00 4.9)", {
  lib <- wsl_lib()
  chained <- 0L
  for (id in names(lib)) {
    f <- lib[[id]]$from
    if (is.null(f)) next
    chained <- chained + 1L
    expect_true(utl_is_library_id(f), info = id)
    expect_true(f %in% names(lib), info = paste(id, "->", f))
    expect_identical(lib[[f]]$block, lib[[id]]$block, info = id)
    expect_no_error(wsl_payload(id))
  }
  expect_identical(chained, 13L)
  expect_identical(lib[["funding/kfw_297_khn_eh55_stufe"]]$from, "funding/kfw_298_khn_eh55_stufe")
  expect_identical(lib[["funding/kfw_298_khn_eh55_stufe"]]$from, "funding/kfw_298_khn_vermietung")
  expect_identical(lib[["legal/mietrecht_ii_reform"]]$from, "legal/mietrecht_2026")
  expect_identical(lib[["legal/gmodg_bio_treppe_2045"]]$from, "legal/gmodg_bio_treppe_2026")
  # Zykluserkennung des Testorakels
  bad <- list(a = list(from = "b", values = list()), b = list(from = "a", values = list()))
  expect_error(wsl_payload("a", bad), "Zyklus")
})

# ---------------------------------------------------------------------------------------------
# Freigaberegel und Rechtsstandsauswahl (Spec 00 4.10, R-80, R-88, R-116)
# ---------------------------------------------------------------------------------------------

test_that("Freigaberegel: C tr\u00e4gt release, D tr\u00e4gt reform (legal/*)", {
  lib <- wsl_lib()
  for (id in wsl_ids_of("legal")) {
    e <- lib[[id]]
    if (identical(e$quality, "C")) expect_false(is.null(e$release), info = id)
    if (identical(e$quality, "D")) expect_false(is.null(e$reform), info = id)
  }
  # OP-07: beide C-Eintraege bis zur Fachfreigabe pending
  expect_identical(lib[["legal/mietrecht_559f_2026"]]$release$status, "pending")
  expect_identical(lib[["legal/grunderwerbsteuer_2026"]]$release$status, "pending")
  expect_identical(lib[["legal/gmodg_bio_treppe_2045"]]$reform, "stufe_2045")
  expect_identical(lib[["legal/mietrecht_ii_reform"]]$reform, "mietrecht_ii")
  # release nur bei legal/* (Spec 00 4.9: Pflicht bei legal/* der Qualitaet C)
  others <- setdiff(names(lib), wsl_ids_of("legal"))
  expect_true(all(vapply(lib[others], function(e) is.null(e$release), logical(1))))
})

test_that("Automatische Auswahl je Thema zum Rechtsstand (Spec 00 4.10)", {
  sel <- function(topic, date = "2027-01-01", pending = character(0)) {
    wsl_select_legal(topic, date, pending)
  }
  expect_identical(sel("mietrecht"), "legal/mietrecht_2026")
  expect_null(sel("mietrecht_559f"))                       # C ohne Freigabe: Thema inaktiv
  expect_identical(sel("co2kostaufg"), "legal/co2kostaufg_2026")
  expect_identical(sel("bio_treppe"), "legal/gmodg_bio_treppe_2026")
  expect_identical(sel("co2_pricing"), "legal/behg_ets2_2026")
  expect_identical(sel("emission_factors_geg"), "legal/emission_factors_geg_anlage9")
  expect_identical(sel("emission_factors_co2cost"), "legal/emission_factors_co2cost_2026")
  expect_null(sel("grunderwerbsteuer"))                    # C ohne Freigabe: Thema inaktiv
  expect_identical(sel("umsatzsteuer"), "legal/umsatzsteuer_2026")
  # Reformschalter haben Vorrang vor dem Eintrag ohne Reform (R-82)
  expect_identical(sel("mietrecht", pending = "mietrecht_ii"), "legal/mietrecht_ii_reform")
  expect_identical(sel("bio_treppe", pending = "stufe_2045"), "legal/gmodg_bio_treppe_2045")
  expect_identical(sel("mietrecht", pending = "stufe_2045"), "legal/mietrecht_2026")
  # Sammelcode unreleased (Pruefrechnungen, S3-T4)
  expect_identical(sel("mietrecht_559f", pending = "unreleased"), "legal/mietrecht_559f_2026")
  expect_identical(sel("grunderwerbsteuer", pending = "unreleased"), "legal/grunderwerbsteuer_2026")
  # Fortgeltung der GEG-Emissionsfaktoren (valid_to: null, N-28)
  expect_identical(sel("emission_factors_geg", "2035-01-01"), "legal/emission_factors_geg_anlage9")
  # Rechtsstaende vor dem 29.07.2026 sind in v1 nicht hinterlegt
  expect_null(sel("mietrecht", "2026-07-28"))
  expect_identical(sel("mietrecht", "2026-07-29"), "legal/mietrecht_2026")
  expect_identical(sel("mietrecht", "2026-07-15", "mietrecht_ii"), "legal/mietrecht_ii_reform")
})

test_that("Freigabe je Teil: C/D-Teile in A/B-Eintr\u00e4gen nur als Ausnahmen (R-88, R-116)", {
  lib <- wsl_lib()
  # Ausnahmen nach Spec 00 4.10: Auslegungsannahmen als Defaults von Nutzerfeldern (R-116),
  # Teile, die nur auf ausdrueckliche Nutzerangabe wirken (Schalter), informative Teile ohne
  # automatisch anwendende Regel.
  allowed <- list(
    "legal/mietrecht_2026" = c("interpretation", "s558.funding_deduction_duration_grant_years",
                               "s558.funding_deduction_duration_loan"),
    "legal/co2kostaufg_2026" = c("s5b", "s5d", "s5a.transition", "s9"),
    "legal/behg_ets2_2026" = c("corridor_2027", "ets2.psm.release_volume_mt"),
    "legal/umsatzsteuer_2026" = "pv_zero_rate.above_30kwp"
  )
  for (id in wsl_ids_of("legal")) {
    e <- lib[[id]]
    if (!(e$quality %in% c("A", "B"))) next
    qd <- e$quality_detail %||% list()
    low <- names(qd)[vapply(qd, function(q) q %in% c("C", "D"), logical(1))]
    expect_true(all(low %in% (allowed[[id]] %||% character(0))),
                info = paste(id, paste(setdiff(low, allowed[[id]]), collapse = ", ")))
  }
  # Paragraph 559f ist ein eigener Eintrag (01b 7.3): kein s559f im Mietrechtseintrag
  expect_false(utl_has_name(lib[["legal/mietrecht_2026"]]$values, "s559f"))
})

# ---------------------------------------------------------------------------------------------
# Codes der Nutzlasten sind Vokabularcodes (Spec 00 2.11, R-89)
# ---------------------------------------------------------------------------------------------

test_that("F\u00f6rdereintr\u00e4ge: Codes der Nutzlasten sind Vokabularcodes (2.11, N-01, F-02)", {
  lib <- wsl_lib()
  sub_codes <- function(x, vocab_name, info) {
    if (is.null(x)) return(invisible())
    expect_true(all(as.character(unlist(x)) %in% vocab_codes(vocab_name)),
                info = paste(info, vocab_name, paste(setdiff(unlist(x), vocab_codes(vocab_name)),
                                                     collapse = ", ")))
  }
  for (id in wsl_ids_of("funding")) {
    p <- wsl_payload(id)
    sub_codes(p$eligibility$measure_types, "measure_types", id)
    sub_codes(p$eligibility$applicants, "applicant", id)
    sub_codes(p$eligibility$project_types, "project_type", id)
    sub_codes(p$eligibility$conditions$efficiency_standard, "efficiency_standard", id)
    sub_codes(p$eligibility$conditions$energy_class_at_application, "energy_class", id)
    sub_codes(p$instrument_type, "instrument_type", id)
    sub_codes(p$loan$repayment, "repayment", id)
    for (v in p$loan$variants) sub_codes(v$repayment, "repayment", id)
    sub_codes(p$repayment_grant$effect, "repayment_grant_effect", id)
    sub_codes(names(p$repayment_grant$base_rates), "repayment_grant_class", id)
    sub_codes(p$payout$event, "payout_event", id)
    sub_codes(p$rent_law$grant_counts_as, "grant_counts_as", id)
    sub_codes(p$rent_law$loan_counts_as, "loan_counts_as", id)
    sub_codes(p$rent_law$enables, "bgb_procedure", id)
    sub_codes(p$rate_components$isfp$mode, "bonus_mode", id)
    sub_codes(p$basis$cap_period, "cap_period", id)
    expect_false(is.null(p$instrument_type), info = id)
    expect_true(wsl_str(p$program_code), info = id)
    expect_true(is.logical(p$application_before_start), info = id)
    ap <- p$budget_risk$approval_probability
    expect_true(wsl_num(ap) && ap > 0 && ap <= 1, info = id)
    # Kreditanteil einheitlich unter loan (N-11)
    expect_null(p$basis$max_share_of_eligible_costs)
    if (!is.null(p$loan$default_variant)) {
      expect_true(p$loan$default_variant %in% names(p$loan$variants), info = id)
    }
    for (vn in names(p$loan$variants)) {
      v <- p$loan$variants[[vn]]
      req <- c("term_years", "grace_years", "fixed_years", "rate_pa", "rate_date")
      expect_true(all(req %in% names(v)), info = paste(id, vn))
      expect_true(v$rate_pa >= 0 && v$rate_pa < 0.2 && v$grace_years <= v$term_years,
                  info = paste(id, vn))
      if (!is.null(v$effective_rate_pa)) expect_gte(v$effective_rate_pa, v$rate_pa)
    }
    # Kumulierungsverweise sind Foerdereintraege der Bibliothek (01b 4.11, N-12)
    for (ref in unlist(p$cumulation)) {
      expect_true(ref %in% wsl_ids_of("funding") && ref != id, info = paste(id, ref))
    }
  }
  # Keine Sammelcodes (N-01) und genau die Listen von Teil C 9.1 N-01
  expect_identical(wsl_get("funding/kfw_458_heizung_privat", "eligibility.measure_types"),
                   c("heizung_waermepumpe_luft", "heizung_waermepumpe_sole", "heizung_pelletkessel",
                     "heizung_fernwaerme", "heizungsverteilung"))
  expect_identical(wsl_get("funding/kfw_459_heizung_unternehmen", "eligibility.measure_types"),
                   wsl_get("funding/kfw_458_heizung_privat", "eligibility.measure_types"))
  expect_identical(wsl_get("funding/bafa_beg_em_huelle", "eligibility.measure_types"),
                   c("daemmung_fassade", "daemmung_dach_steil", "daemmung_dach_flach",
                     "daemmung_oberste_geschossdecke", "daemmung_kellerdecke", "fenster",
                     "aussentueren"))
  # Bedingungsschluessel nach 01b 4.3.1: lca_thg statt lca_qng_plus_thg (N-10)
  for (id in c("funding/kfw_298_khn_vermietung", "funding/kfw_297_khn_selbstnutzung",
               "funding/kfw_300_wohneigentum_familien")) {
    expect_identical(wsl_get(id, "eligibility.conditions.lca_thg"), "required")
  }
  expect_null(wsl_get("funding/kfw_308_jung_kauft_alt", "eligibility.conditions.lca_thg"))
  expect_null(wsl_get("funding/kfw_298_khn_eh55_stufe", "eligibility.conditions.lca_thg"))
  cond55 <- wsl_get("funding/kfw_297_khn_eh55_stufe", "eligibility.conditions")
  expect_null(wsl_get("funding/kfw_298_khn_eh55_stufe",
                      "eligibility.conditions.fossil_or_biomass_heating"))
  expect_identical(cond55$oil_gas_heating, "excluded")
  expect_identical(wsl_get("funding/estg_35c", "instrument_type"), "tax_credit")
})

test_that("Mietrecht: Verfahrenslisten bgb_procedure, Modernisierungsarten, Auslegungen (N-06)", {
  for (id in c("legal/mietrecht_2026", "legal/mietrecht_ii_reform")) {
    p <- wsl_payload(id)
    for (path in c("s557a.excludes", "s557b.excludes", "s558.excludes_increases")) {
      codes <- path_get(p, path)
      expect_true(length(codes) > 0L, info = paste(id, path))
      expect_true(all(codes %in% vocab_codes("bgb_procedure")), info = paste(id, path))
    }
    for (path in c("s559.hardship_exclusion_not_for", "s536_1a.scope", "s559e.requires_measure")) {
      codes <- path_get(p, path)
      expect_true(length(codes) > 0L && all(codes %in% vocab_codes("modernization_kind")),
                  info = paste(id, path))
    }
    expect_true(p$interpretation$third_party_allocation %in% vocab_codes("third_party_allocation"))
    expect_true(p$interpretation$s559e_order %in% vocab_codes("s559e_order"))
    expect_true(p$interpretation$s559f_order %in% vocab_codes("s559f_order"))
  }
  # Reform Mietrecht II erbt alles uebrige aus legal/mietrecht_2026
  ii <- wsl_payload("legal/mietrecht_ii_reform")
  expect_equal(ii$s559c$cost_limit_per_unit_eur, 20000)
  expect_identical(ii$s559c$flat_maintenance_share, 0.30)
  expect_identical(ii$s557a$excludes, c("bgb_558", "bgb_559", "bgb_559b", "bgb_559e"))
  expect_equal(ii$s557a$min_step_months, 12)
  expect_identical(ii$s536_1a$scope, c("bgb_555b_1", "bgb_555b_1a"))
  expect_equal(ii$s536_1a$exclusion_months, 3)
  expect_identical(ii$s557b$index, "vpi")
  expect_true(isTRUE(ii$s557b$damping$symmetric))
})

test_that("Grunderwerbsteuer: Schl\u00fcssel = federal_state, S\u00e4tze und Freigrenze (X-27)", {
  p <- wsl_payload("legal/grunderwerbsteuer_2026")
  expect_setequal(names(p$rates), vocab_codes("federal_state"))
  expect_length(p$rates, 16L)
  r <- unlist(p$rates)
  expect_true(all(r >= 0.035 & r <= 0.065))
  expect_equal(r[c("BY", "BE", "NW", "HB", "BW")],
               c(BY = 0.035, BE = 0.060, NW = 0.065, HB = 0.055, BW = 0.050))
  expect_equal(p$exemption_threshold_eur, 2500)
  expect_false(p$uniform_contract_includes_construction)
})

test_that("Ma\u00dfnahmentypen: genau die 37 Codes, Schema Teil A 8.3, Vokabularcodes (N-30)", {
  types <- wsl_get("costs/massnahmentypen_2026", "types")
  nd <- wsl_payload("costs/nutzungsdauern_2026")
  wi <- wsl_payload("costs/wartung_instandsetzung_vdi2067_2026")
  pmax_el <- wsl_get("valuation/immowertv_anlage1_2_2026", "modernisation_points_max")
  expect_identical(names(types), vocab_codes("measure_types"))
  expect_length(types, 37L)
  keys <- c("kg", "asset_type", "classification_existing", "useful_life_key", "useful_life_years",
            "useful_life", "ohnehin_share", "modernization_kind", "points", "vat_rate",
            "replacement", "repair_key")
  required <- c("kg", "asset_type", "classification_existing", "ohnehin_share",
                "modernization_kind", "vat_rate", "replacement")
  for (code in names(types)) {
    t <- types[[code]]
    expect_true(all(names(t) %in% keys), info = code)
    expect_true(all(required %in% names(t)), info = code)
    expect_true(is.null(t$kg) || t$kg %in% c(100, 200, 300, 400, 500, 600, 700), info = code)
    expect_true(all(unlist(t$asset_type) %in% vocab_codes("asset_types")), info = code)
    cl_codes <- c(vocab_codes("classification"), "main")
    expect_true(is.null(t$classification_existing) || t$classification_existing %in% cl_codes,
                info = code)
    expect_true(t$modernization_kind %in% vocab_codes("modernization_kind"), info = code)
    expect_true(all(names(t$points) %in% vocab_codes("modernization_element")), info = code)
    for (el in names(t$points)) expect_lte(t$points[[el]], pmax_el[[el]])
    expect_true(sum(c("useful_life_key", "useful_life_years", "useful_life") %in% names(t)) <= 1L,
                info = code)
    if (!is.null(t[["useful_life_key"]])) {
      expect_true(t[["useful_life_key"]] %in% names(nd), info = code)
    }
    if (!is.null(t[["useful_life"]])) expect_identical(t[["useful_life"]], "main")
    if (!is.null(t$repair_key)) {
      expect_true(t$repair_key %in% names(wi), info = code)
      expect_true(wsl_num(wi[[t$repair_key]]$repair), info = code)
    }
    oh <- t$ohnehin_share
    expect_true(is.null(oh) || (oh >= 0 && oh <= 1), info = code)
    expect_true(t$vat_rate %in% c(0, 0.19), info = code)
    expect_true(is.logical(t$replacement), info = code)
  }
  # ohne Nutzungsdauer nur Erwerb und sonstige (Teil A 8.3)
  no_life <- names(types)[!vapply(types, function(t) {
    any(c("useful_life_key", "useful_life_years", "useful_life") %in% names(t))
  }, logical(1))]
  expect_setequal(no_life, c("erwerb_grundstueck", "erwerb_objekt", "sonstige"))
})

test_that("Ma\u00dfnahmentypen: Katalogwerte = Tabelle Teil A 4.2 (ND, Ohnehin, Punkte, ...)", {
  types <- wsl_get("costs/massnahmentypen_2026", "types")
  nd <- wsl_payload("costs/nutzungsdauern_2026")
  wi <- wsl_payload("costs/wartung_instandsetzung_vdi2067_2026")
  # Tabelle Teil A 4.2: KG, asset_type, Klass. Bestand, ND, Ohnehin (NA = NULL), Art, Punkte,
  # USt, Ersatz, Instandsetzung (NA = kein Vorschlag)
  gw <- "gebaeude_wohnen"
  row <- function(kg, at, cl, life, oh, mk, pts = list(), vat = 0.19, rep = TRUE, ins = NA_real_) {
    list(kg = kg, at = at, cl = cl, life = life, oh = oh, mk = mk, pts = pts, vat = vat,
         rep = rep, ins = ins)
  }
  t42 <- list(
    neubau = row(300, gw, "herstellung", 80, 0, "none", rep = FALSE),
    erweiterung = row(300, gw, "herstellung", 80, 0, "bgb_555b_7", rep = FALSE),
    aufstockung = row(300, gw, "herstellung", 80, 0, "bgb_555b_7", rep = FALSE),
    rueckbau = row(200, gw, "herstellung", "main", 0, "none", rep = FALSE),
    herrichten_erschliessung = row(200, gw, "herstellung", "main", 0, "none", rep = FALSE),
    erwerb_grundstueck = row(100, "grund_boden", NA, NA, NA, "none", vat = 0, rep = FALSE),
    erwerb_objekt = row(100, c(gw, "grund_boden"), NA, NA, NA, "none", vat = 0, rep = FALSE),
    daemmung_fassade = row(300, gw, "erhaltung", 40, 0.5, "bgb_555b_1",
                           list(facade_insulation = 4)),
    daemmung_dach_steil = row(300, gw, "erhaltung", 50, 0.7, "bgb_555b_1",
                              list(roof_insulation = 4)),
    daemmung_dach_flach = row(300, gw, "erhaltung", 30, 0.57, "bgb_555b_1",
                              list(roof_insulation = 4)),
    daemmung_oberste_geschossdecke = row(300, gw, "erhaltung", 50, 0, "bgb_555b_1",
                                         list(roof_insulation = 2)),
    daemmung_kellerdecke = row(300, gw, "erhaltung", 50, 0, "bgb_555b_1"),
    fenster = row(300, gw, "erhaltung", 40, 0.85, "bgb_555b_1", list(windows_doors = 2)),
    aussentueren = row(300, gw, "erhaltung", 40, 0.85, "bgb_555b_1", list(windows_doors = 2)),
    putz_anstrich = row(300, gw, "erhaltung", 15, 1, "none"),
    instandsetzung = row(300, gw, "erhaltung", 25, 1, "none"),
    heizung_waermepumpe_luft = row(400, gw, "erhaltung", 18, NA, "bgb_555b_1a", list(heating = 2),
                                   ins = 0.010),
    heizung_waermepumpe_sole = row(400, gw, "erhaltung", 20, NA, "bgb_555b_1a", list(heating = 2),
                                   ins = 0.010),
    heizung_gaskessel = row(400, gw, "erhaltung", 18, 1, "none", list(heating = 2), ins = 0.010),
    heizung_pelletkessel = row(400, gw, "erhaltung", 20, NA, "bgb_555b_1a", list(heating = 2),
                               ins = 0.020),
    heizung_fernwaerme = row(400, gw, "erhaltung", 25, NA, "bgb_555b_1a", list(heating = 2),
                             ins = 0.010),
    heizungsverteilung = row(400, gw, "erhaltung", 40, NA, "bgb_555b_1", list(heating = 2)),
    lueftung_zentral = row(400, gw, "auto", 20, 0, "bgb_555b_1", ins = 0.015),
    lueftung_dezentral = row(400, gw, "auto", 15, 0, "bgb_555b_1", ins = 0.015),
    pv = row(400, "pv_anlage", "herstellung", 25, 0, "none", vat = 0),
    pv_wechselrichter = row(400, "pv_anlage", "erhaltung", 12, 0, "none", vat = 0),
    batteriespeicher = row(400, "pv_anlage", "herstellung", 12, 0, "none", vat = 0),
    leitungen = row(400, gw, "erhaltung", 40, NA, "none", list(pipes = 2)),
    baeder = row(400, gw, "erhaltung", 25, NA, "bgb_555b_4", list(bathrooms = 2)),
    innenausbau = row(300, gw, "erhaltung", 30, NA, "none", list(interior = 2)),
    grundriss = row(300, gw, "herstellung", 80, 0, "bgb_555b_4", list(floor_plan = 2), rep = FALSE),
    aufzug = row(400, gw, "herstellung", 25, 0, "bgb_555b_4"),
    ladeinfrastruktur = row(400, "ladeinfrastruktur", "herstellung", 15, 0, "none"),
    aussenanlagen = row(500, "aussenanlage", "herstellung", 30, 0, "none"),
    ausstattung = row(600, "bewegliches_wg", "herstellung", 15, 0, "none"),
    baunebenkosten = row(700, gw, "main", "main", 0, "none", rep = FALSE),
    sonstige = row(NA, gw, "auto", NA, 0, "none", rep = FALSE)
  )
  expect_setequal(names(t42), names(types))
  for (code in names(t42)) {
    t <- types[[code]]
    x <- t42[[code]]
    # exakter Zugriff mit [[ ]]: $ wuerde "useful_life" als Praefix von "useful_life_key" treffen
    life <- if (!is.null(t[["useful_life_key"]])) {
      nd[[t[["useful_life_key"]]]]
    } else if (!is.null(t[["useful_life_years"]])) {
      t[["useful_life_years"]]
    } else {
      t[["useful_life"]] %||% NA
    }
    ins <- if (!is.null(t$repair_key)) wi[[t$repair_key]]$repair else NA_real_
    expect_equal(t$kg %||% NA, x$kg, info = code)
    expect_identical(as.character(unlist(t$asset_type)), x$at, info = code)
    expect_identical(t$classification_existing %||% NA, x$cl, info = code)
    expect_equal(life, x$life, info = code)
    expect_equal(t$ohnehin_share %||% NA, x$oh, info = code)
    expect_identical(t$modernization_kind, x$mk, info = code)
    expect_equal(lapply(t$points %||% list(), as.numeric), x$pts, info = code)
    expect_equal(t$vat_rate, x$vat, info = code)
    expect_identical(t$replacement, x$rep, info = code)
    expect_equal(ins, x$ins, info = code)
  }
})

test_that("Marktnutzlasten: kanonische Marktnamen, Tr\u00e4ger, Wertformen (1.9.1, 3.6, N-15)", {
  lib <- wsl_lib()
  for (id in wsl_ids_of("prices")) {
    m <- lib[[id]]$values$market
    if (is.null(m)) {
      expect_identical(id, "prices/co2_price_path_referenzszenarien_2026")
      next
    }
    allowed <- wsl_canonical_markets()
    if (id == "prices/referenzszenarien_2026") {                  # szenarioeigene Pfade (1.9.1)
      allowed <- c(allowed, "construction_price_index_base", "bio_fuel_premium_base")
    }
    expect_true(all(names(m) %in% allowed),
                info = paste(id, paste(setdiff(names(m), allowed), collapse = ", ")))
    expect_true(all(names(m$energy_price) %in% wsl_carriers()), info = id)
    expect_true(all(names(m$energy_network_fee) %in% wsl_carriers()), info = id)
    classes <- c("partial_le10kwp", "partial_10_40kwp", "partial_40_100kwp", "full_le10kwp")
    expect_true(all(names(m$feed_in_tariff) %in% classes), info = id)
    # Wertformen (Spec 00 4.5): Codes von fill, before, interpolate
    walk <- function(x, path) {
      if (!is_map(x)) return(invisible())
      if (!is.null(x$fill)) expect_true(x$fill %in% vocab_codes("series_fill"), info = path)
      if (!is.null(x$before)) expect_true(x$before %in% vocab_codes("series_before"), info = path)
      if (!is.null(x$interpolate)) {
        expect_true(x$interpolate %in% vocab_codes("interpolate"), info = path)
      }
      if (!is.null(x$base_date)) expect_true(wsl_is_date(x$base_date), info = path)
      for (nm in names(x)) walk(x[[nm]], path_join(path, nm))
    }
    walk(m, id)
  }
  # alle zehn kanonischen Traeger in Preis- und Prozessbibliothek (N-15)
  expect_identical(names(lib[["prices/energy_prices_2026"]]$values$market$energy_price),
                   wsl_carriers())
  mr <- lib[["processes/energy_prices_mr_2026"]]$values
  expect_identical(setdiff(names(mr), c("bio_premium_factor", "network_fee_growth")),
                   wsl_carriers())
  expect_identical(names(lib[["prices/eeg_feed_in_2026"]]$values$market$feed_in_tariff),
                   c("partial_le10kwp", "partial_10_40kwp", "partial_40_100kwp", "full_le10kwp"))
  carr <- lib[["prices/referenzszenarien_2026"]]$values$carriers
  for (c in names(carr)) expect_true(carr[[c]]$class %in% vocab_codes("carrier_class"), info = c)
})

# ---------------------------------------------------------------------------------------------
# Prozessbibliothek processes/** (Teil C 2)
# ---------------------------------------------------------------------------------------------

test_that("processes/**: Vorlagen sind g\u00fcltige Overlay-Eintr\u00e4ge ohne target (1.3-1.6)", {
  lib <- wsl_lib()
  n_proc <- 0L
  n_static <- 0L
  for (id in wsl_ids_of("processes")) {
    v <- lib[[id]]$values
    tpl <- wsl_templates(v)
    if (is.null(tpl)) next
    for (nm in names(tpl)) {
      x <- tpl[[nm]]
      info <- paste(id, nm)
      if (!is.null(x[["type"]])) {
        expect_identical(wsl_check_process(x), character(0), info = info)
        n_proc <- n_proc + 1L
      } else {
        expect_identical(wsl_check_static(x), character(0), info = info)
        n_static <- n_static + 1L
      }
      expect_true(is.null(x$label) || wsl_str(x$label), info = info)
    }
  }
  # Prozesse: 9 Einzelprozesse (2.2-2.5), 10 Energietraeger und die iid-Leerstandsschwankung;
  # statische Vorlagen: 2 Energie, 6 Kosten, 9 Performance, 4 Foerderung und 4 Bewertung
  expect_identical(n_proc, 20L)
  expect_identical(n_static, 25L)
  # Testorakel erkennt Fehler
  expect_true(length(wsl_check_process(list(type = "ar1", mu = 0.02, phi = 1.2,
                                            sigma = 0.01))) > 0L)
  expect_true(length(wsl_check_process(list(type = "vasicek", r0 = "base", theta = 0.03, kappa = 0,
                                            sigma = 0.01))) > 0L)
  expect_true(length(wsl_check_process(list(type = "ar1", mu = "base", phi = 0.5,
                                            sigma = 0.01))) > 0L)
  expect_true(length(wsl_check_static(list(dist = "normal", mean = 0, sd = 1,
                                           apply = "multiply"))) > 0L)
  expect_true(length(wsl_check_static(list(dist = "pert", min = 1, mode = 0, max = 2))) > 0L)
  expect_true(length(wsl_check_dist(list(dist = "discrete", values = c(1, 2),
                                         probs = c(0.5, 0.6)))) > 0L)
})

test_that("processes/**: Typen, Ziele und use:-Vorlagen nach der \u00dcbersicht 2.1", {
  lib <- wsl_lib()
  type_of <- function(id) lib[[id]]$values[["type"]]
  expect_identical(type_of("processes/inflation_ar1_2026"), "ar1")
  expect_identical(type_of("processes/mortgage_rate_vasicek_2026"), "vasicek")
  expect_identical(type_of("processes/bund10_vasicek_2026"), "vasicek")
  expect_identical(type_of("processes/mortgage_spread_ar1_2026"), "ar1")
  for (id in c("rent_growth_linked_2026", "rent_growth_new_linked_2026",
               "construction_price_linked_2026", "maintenance_cost_linked_2026")) {
    expect_identical(type_of(paste0("processes/", id)), "linked_ar1")
    expect_identical(lib[[paste0("processes/", id)]]$values$base, "inflation")
  }
  expect_identical(type_of("processes/co2_price_corridor_2026"), "scenario_mix")
  expect_identical(names(lib[["processes/co2_price_corridor_2026"]]$values$scenarios),
                   sprintf("q%02d", 1:20))
  uses <- list(
    "processes/energy_prices_mr_2026" = c(wsl_carriers(), "bio_premium_factor",
                                          "network_fee_growth"),
    "processes/cost_risks_2026" = c("overrun_newbuild", "overrun_retrofit", "overrun_component",
                                    "delay_newbuild", "delay_retrofit", "maintenance_level"),
    "processes/energy_performance_2026" = c("prebound", "rebound", "rebound_calculated",
                                            "realisation", "jaz_air_water_existing",
                                            "jaz_air_water_newbuild", "jaz_ground_existing",
                                            "jaz_air_water_mfh_central", "jaz_relative"),
    "processes/funding_risks_2026" = c("availability_after_2030", "feed_in_continuation",
                                       "payout_delay", "repayment_grant_cut"),
    "processes/valuation_risks_2026" = c("cap_rate_shock", "remaining_life_shock", "vacancy_level",
                                         "vacancy_fluctuation", "market_value_uplift_efficiency")
  )
  for (id in names(uses)) expect_identical(names(lib[[id]]$values), uses[[id]], info = id)
  mr <- lib[["processes/energy_prices_mr_2026"]]$values
  for (c in wsl_carriers()) expect_identical(mr[[c]][["type"]], "mr_trend", info = c)
  expect_identical(lib[["processes/valuation_risks_2026"]]$values$vacancy_fluctuation$type, "iid")
  expect_identical(lib[["processes/funding_risks_2026"]]$values$availability_after_2030$dist,
                   "bernoulli")
  expect_equal(lib[["processes/funding_risks_2026"]]$values$availability_after_2030$p, 0.7)
})

test_that("Korrelationslisten: Paare, Schl\u00fcssel nach 1.10.2, positiv definit (Teil C 2.6)", {
  lib <- wsl_lib()
  check_pairs <- function(pairs, key_pattern, info) {
    expect_null(names(pairs))
    seen <- character(0)
    for (p in pairs) {
      expect_length(p, 3L)
      a <- p[[1L]]
      b <- p[[2L]]
      rho <- p[[3L]]
      expect_true(utl_is_string(a) && utl_is_string(b) && a != b, info = info)
      expect_match(c(a, b), key_pattern)
      expect_true(wsl_num(rho) && abs(rho) <= 1, info = info)
      k <- paste(sort(c(a, b), method = "radix"), collapse = "|")
      expect_false(k %in% seen, info = paste(info, k))
      seen <- c(seen, k)
    }
  }
  shocks <- lib[["processes/shock_correlations_2026"]]$values
  params <- lib[["processes/param_correlations_2026"]]$values
  check_pairs(shocks, "^[a-z][a-z0-9_]*$", "shocks")
  check_pairs(params, "^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)?$", "parameters")
  expect_length(shocks, 66L)
  keys <- utl_sort(unique(unlist(lapply(shocks, function(p) c(p[[1L]], p[[2L]])))))
  expect_length(keys, 12L)
  expect_setequal(keys, c("inflation", "mortgage_rate", paste0("energy_price_", wsl_carriers())))
  # Prozessschluessel = kanonischer Marktname mit _ (1.10.2) und Prozess mit einem Schock (1.7.1);
  # keine Paare mit den strukturell gekoppelten linked_ar1-Prozessen
  expect_false(any(c("rent_growth", "rent_growth_new", "construction_price_index",
                     "maintenance_index", "co2_price") %in% keys))
  m <- diag(length(keys))
  dimnames(m) <- list(keys, keys)
  for (p in shocks) m[p[[1L]], p[[2L]]] <- m[p[[2L]], p[[1L]]] <- p[[3L]]
  expect_identical(sum(m[upper.tri(m)] != 0), 66L)          # vollstaendige 12 x 12-Matrix
  ev <- eigen(m, symmetric = TRUE, only.values = TRUE)$values
  expect_equal(ev, c(6.02276, 1.77122, 1.24778, 0.86560, 0.60781, 0.53472, 0.45012, 0.20000,
                     0.15000, 0.05, 0.05, 0.05), tolerance = 1e-5)
  expect_gt(min(ev), 0)
  k10 <- setdiff(keys, c("energy_price_lpg", "energy_price_power_mfh"))
  expect_equal(eigen(m[k10, k10], symmetric = TRUE, only.values = TRUE)$values,
               c(5.06475, 1.47189, 0.87818, 0.80099, 0.59464, 0.52757, 0.44568, 0.11631, 0.05,
                 0.05), tolerance = 1e-5)
  k8 <- c("inflation", "mortgage_rate",
          paste0("energy_price_", c("gas", "power", "heatpump_power", "oil", "district_heating",
                                    "pellets")))
  expect_equal(eigen(m[k8, k8], symmetric = TRUE, only.values = TRUE)$values,
               c(3.77181, 1.13739, 0.81782, 0.78155, 0.55072, 0.48524, 0.35546, 0.10000),
               tolerance = 1e-5)
  # MFH-Varianten spiegeln die EFH-Prozesse (sonst nicht positiv definit)
  expect_equal(m["energy_price_gas", "energy_price_gas_mfh"], 0.95)
  expect_equal(m["energy_price_power", "energy_price_power_mfh"], 0.95)
  expect_equal(m["energy_price_oil", "energy_price_lpg"], 0.80)
  # Parameterkorrelationen: Prozessparameter-Schluessel <proc>.<param> verweisen auf Parameter
  expect_length(params, 3L)
  pkeys <- unlist(lapply(params, function(p) c(p[[1L]], p[[2L]])))
  dotted <- grep(".", pkeys, fixed = TRUE, value = TRUE)
  expect_setequal(dotted, c("inflation.mu", "mortgage_rate.theta"))
  expect_true(wsl_is_dist(lib[["processes/inflation_ar1_2026"]]$values$mu))
  expect_true("theta" %in% names(lib[["processes/mortgage_rate_vasicek_2026"]]$values))
})

# ---------------------------------------------------------------------------------------------
# Pruefwerte der Prozessbibliothek (Teil C 1.6, 2.8)
# ---------------------------------------------------------------------------------------------

test_that("Pr\u00fcfwerte Inflation AR(1) (Teil C 1.6.1, Bibliotheksdefault mit x0 = 0,028)", {
  v <- wsl_lib()[["processes/inflation_ar1_2026"]]$values
  mu <- v$mu$mean
  smu <- v$mu$sd
  phi <- v$phi
  sig <- v$sigma
  expect_identical(c(mu, smu, phi, sig), c(0.020, 0.004, 0.5, 0.011))
  y <- c(1, 2, 3, 5, 11, 31)
  e <- mu + phi^(y - 1) * (0.028 - mu)
  s <- sqrt(sig^2 * (1 - phi^(2 * (y - 1))) / (1 - phi^2) + (1 - phi^(y - 1))^2 * smu^2)
  expect_equal(e, c(0.028, 0.024, 0.022, 0.0205, 0.020007812, 0.020000000), tolerance = 1e-6)
  expect_equal(s, c(0, 0.01118034, 0.012658989, 0.013219895, 0.013315478, 0.013316656),
               tolerance = 1e-6)
  expect_equal(sig / sqrt(1 - phi^2), 0.012701706, tolerance = 1e-6)
})

test_that("Pr\u00fcfwerte Vasicek-Bauzins (Teil C 1.6.3, 2.8 Nr. 1; r0 = 0,040)", {
  v <- wsl_lib()[["processes/mortgage_rate_vasicek_2026"]]$values
  expect_identical(v$r0, "base")
  th <- v$theta
  ka <- v$kappa
  sg <- v$sigma
  expect_identical(c(th, ka, sg, v$floor), c(0.0375, 0.12, 0.007, 0.005))
  expect_equal(exp(-ka), 0.88692044, tolerance = 1e-6)
  expect_equal(sg * sqrt((1 - exp(-2 * ka)) / (2 * ka)), 0.0066002635, tolerance = 1e-6)
  expect_equal(sg / sqrt(2 * ka), 0.01428869, tolerance = 1e-6)
  expect_equal(log(2) / ka, 5.7762265, tolerance = 1e-6)
  y <- c(1, 2, 6, 11, 21, 31, 41)
  e <- th + (0.040 - th) * exp(-ka * (y - 1))
  s <- sg * sqrt((1 - exp(-2 * ka * (y - 1))) / (2 * ka))
  expect_equal(e, c(0.04, 0.039717301, 0.038872029, 0.038252986, 0.037726795, 0.037568309,
                    0.037520574), tolerance = 1e-6)
  expect_equal(s, c(0, 0.0066002635, 0.011944574, 0.013625164, 0.014229773, 0.014283355,
                    0.014288206), tolerance = 1e-6)
  # 2.8 Nr. 1: Quantile der gekappten Ausgabe (Floor bindet bei q05 nicht)
  z <- stats::qnorm(c(0.05, 0.5, 0.95))
  q <- function(yy) {
    m <- th + (0.040 - th) * exp(-ka * (yy - 1))
    pmax(m + z * sg * sqrt((1 - exp(-2 * ka * (yy - 1))) / (2 * ka)), v$floor)
  }
  expect_equal(q(11), c(0.01584159, 0.03825299, 0.06066439), tolerance = 1e-6)
  expect_equal(q(21), c(0.01432090, 0.03772679, 0.06113269), tolerance = 1e-6)
  expect_equal(q(31), c(0.01407428, 0.03756831, 0.06106234), tolerance = 1e-6)
})

test_that("Pr\u00fcfwerte gekoppelte Prozesse linked_ar1 (Teil C 1.6.2)", {
  lib <- wsl_lib()
  inf <- lib[["processes/inflation_ar1_2026"]]$values
  eb <- function(y, x0 = 0.028) inf$mu$mean + inf$phi^(y - 1) * (x0 - inf$mu$mean)
  vb <- function(y) {
    inf$sigma^2 * (1 - inf$phi^(2 * (y - 1))) / (1 - inf$phi^2) +
      (1 - inf$phi^(y - 1))^2 * inf$mu$sd^2
  }
  eg <- function(p, y, u0, x0 = 0.028) p$a + p$b * eb(y, x0) + p$phi^(y - 1) * u0
  sdg <- function(p, y) sqrt(p$b^2 * vb(y) + p$sigma^2 * (1 - p$phi^(2 * (y - 1))) / (1 - p$phi^2))
  u0_base <- function(p, xdet, x0 = 0.028) xdet - p$a - p$b * x0       # u0: base (1.5.1)
  rent <- lib[["processes/rent_growth_linked_2026"]]$values
  rnew <- lib[["processes/rent_growth_new_linked_2026"]]$values
  cons <- lib[["processes/construction_price_linked_2026"]]$values
  main <- lib[["processes/maintenance_cost_linked_2026"]]$values
  y <- c(1, 2, 3, 11, 31)
  expect_equal(eg(rent, y, 0), c(0.0244, 0.0212, 0.0196, 0.01800625, 0.018), tolerance = 1e-6)
  expect_equal(sdg(rent, 11), 0.012707211, tolerance = 1e-6)
  expect_equal(u0_base(rent, 0.015), -0.0094, tolerance = 1e-12)
  expect_equal(eg(rent, y, -0.0094), c(0.015, 0.0165, 0.01725, 0.01799707, 0.018), tolerance = 1e-6)
  expect_equal(u0_base(rnew, 0.020), -0.013, tolerance = 1e-12)
  expect_equal(eg(rnew, y, -0.013), c(0.020, 0.0225, 0.02375, 0.02499512, 0.025), tolerance = 1e-6)
  expect_equal(eg(cons, c(1, 2, 11, 31), 0), c(0.035, 0.031, 0.027007812, 0.027), tolerance = 1e-6)
  expect_equal(sdg(cons, 11), 0.023808438, tolerance = 1e-6)
  expect_equal(u0_base(cons, 0.040), 0.005, tolerance = 1e-12)
  expect_equal(eg(cons, y, 0.005), c(0.040, 0.03425, 0.0311125, 0.02707513, 0.027),
               tolerance = 1e-6)
  expect_equal(u0_base(main, 0.040), 0.002, tolerance = 1e-12)
  expect_equal(eg(main, y, 0.002), c(0.040, 0.0353, 0.032845, 0.03003474, 0.030), tolerance = 1e-6)
  # Langfristmittel (notes): 0,002 + 0,8 x 0,020 = 0,018
  expect_equal(rent$a + rent$b * inf$mu$mean, 0.018, tolerance = 1e-12)
  # Bibliotheksdefaults mit prices/macro_paths_2026 (pi_2027 = 0,026 = fallback x0)
  macro <- lib[["prices/macro_paths_2026"]]$values$market
  pi27 <- macro$inflation$series[["2027"]]
  expect_equal(pi27, lib[["processes/inflation_ar1_2026"]]$fallback$x0)
  u_r <- u0_base(rent, macro$rent_growth, pi27)
  expect_equal(u_r, -0.0053, tolerance = 1e-12)
  expect_equal(eg(rent, c(1, 2, 11, 31), u_r, pi27), c(0.0175, 0.01775, 0.01799951, 0.018),
               tolerance = 1e-6)
  u_c <- u0_base(cons, macro$construction_price_index$series[["2027"]], pi27)
  expect_equal(u_c, 0.002, tolerance = 1e-12)
  expect_equal(eg(cons, c(1, 2, 11, 31), u_c, pi27), c(0.035, 0.0313, 0.02703278, 0.027),
               tolerance = 1e-6)
})

test_that("Pr\u00fcfwerte Energiepreise mr_trend (Teil C 1.6.4): Erwartungswerte je Tr\u00e4ger", {
  mr <- wsl_lib()[["processes/energy_prices_mr_2026"]]
  # je Traeger: p0, p_norm, phi, sigma, Mittel und sd von g, danach die Erwartungswerte von P in
  # den Jahren 2, 6, 11, 31 und zuletzt der Wert im Jahr 31 bei festem g (Trendmittel)
  tab <- list(
    gas = c(0.06329700, 0.05949660, 0.75, 0.08, 0.02, 0.010,
            0.06357122, 0.06672547, 0.07309457, 0.11235976, 0.10777105),
    gas_mfh = c(0.06042243, 0.05691600, 0.75, 0.08, 0.02, 0.010,
                0.06071659, 0.06379900, 0.06991576, 0.10748624, 0.10309656),
    oil = c(0.09076136, 0.06857460, 0.70, 0.18, 0.02, 0.012,
            0.08510985, 0.07947406, 0.08478237, 0.13189142, 0.12421418),
    lpg = c(0.07061172, 0.06257143, 0.70, 0.15, 0.02, 0.012,
            0.06945872, 0.07059949, 0.07701274, 0.12034492, 0.11333979),
    power = c(0.31816764, 0.30857040, 0.75, 0.04, 0.02, 0.007,
              0.32205552, 0.34333351, 0.37759403, 0.57048917, 0.55893563),
    power_mfh = c(0.27260262, 0.26437981, 0.75, 0.04, 0.02, 0.007,
                  0.27593371, 0.29416447, 0.32351851, 0.48878899, 0.47889004),
    heatpump_power = c(0.22068358, 0.21428160, 0.75, 0.05, 0.02, 0.007,
                       0.22344668, 0.23835497, 0.26219635, 0.39616666, 0.38814350),
    heatpump_power_mfh = c(0.21210671, 0.20571360, 0.75, 0.05, 0.02, 0.007,
                           0.21469985, 0.22888771, 0.25172901, 0.38032611, 0.37262375),
    district_heating = c(0.13331778, 0.12920125, 0.80, 0.07, 0.025, 0.008,
                         0.13579622, 0.14777943, 0.16640173, 0.27828370, 0.27101888),
    pellets = c(0.06774348, 0.06029412, 0.60, 0.09, 0.025, 0.008,
                0.06627570, 0.06887995, 0.07744786, 0.12986112, 0.12647099)
  )
  expect_setequal(names(tab), wsl_carriers())
  e_growth <- function(gm, gs, k) {
    stats::integrate(function(g) (1 + g)^k * stats::dnorm(g, gm, gs), gm - 12 * gs, gm + 12 * gs,
                     rel.tol = 1e-12)$value
  }
  for (c in names(tab)) {
    v <- mr$values[[c]]
    x <- tab[[c]]
    p0 <- mr$fallback[[c]]$p0
    expect_identical(v$p0, "base", info = c)
    expect_identical(v$growth$dist, "normal", info = c)
    expect_equal(c(p0, v$p_norm, v$phi, v$sigma, v$growth$mean, v$growth$sd), x[1:6], info = c)
    ep <- function(y, k_growth) v$p_norm * k_growth * (p0 / v$p_norm)^(v$phi^(y - 1))
    got <- vapply(c(2, 6, 11, 31), function(y) {
      ep(y, e_growth(v$growth$mean, v$growth$sd, y - 1))
    }, double(1))
    expect_equal(got, x[7:10], tolerance = 2e-7, info = c)
    expect_equal(ep(31, (1 + v$growth$mean)^30), x[11], tolerance = 2e-7, info = c)
  }
  # Beispiel ohne Krisenabweichung (p_norm = p0)
  ex <- function(y) 0.0613 * e_growth(0.02, 0.01, y - 1)
  expect_equal(vapply(c(2, 6, 11, 31), ex, double(1)),
               c(0.06252600, 0.06774521, 0.07504800, 0.11576421), tolerance = 2e-7)
  # stationaerer Variationskoeffizient des Rauschens
  cv <- function(phi, s) sqrt(exp(s^2 / (1 - phi^2)) - 1)
  expect_equal(cv(0.75, 0.08), 0.12139231, tolerance = 1e-7)
  expect_equal(cv(0.70, 0.18), 0.256107, tolerance = 1e-5)
  expect_equal(cv(0.60, 0.09), 0.112857, tolerance = 1e-5)
})

test_that("Pr\u00fcfwerte statischer Vorlagen: PERT, Dreieck, diskret (Teil C 1.4.7, 2.7, 3.7)", {
  lib <- wsl_lib()
  tp <- function(id, use) lib[[id]]$values[[use]]
  chk <- function(x, mean, sd, q, info) {
    p <- wsl_pert(x$min, x$mode, x$max)
    expect_equal(c(p$mean, p$sd), c(mean, sd), tolerance = 2e-6, info = info)
    expect_equal(p$q(c(0.1, 0.5, 0.9)), q, tolerance = 2e-6, info = info)
  }
  cr <- "processes/cost_risks_2026"
  ep <- "processes/energy_performance_2026"
  chk(tp(cr, "overrun_newbuild"), 1.0833333, 0.071269665, c(0.99489398, 1.0755241, 1.1835561), "p1")
  chk(tp(cr, "overrun_retrofit"), 1.1416667, 0.099053056, c(1.0176133, 1.13189, 1.2804662), "p2")
  chk(tp(cr, "delay_newbuild"), 3.3333333, 2.031498, c(0.911916, 3.0234477, 6.2232185), "p3")
  chk(tp(cr, "delay_retrofit"), 1.6666667, 1.015749, c(0.455958, 1.5117239, 3.1116093), "p4")
  chk(tp(ep, "jaz_air_water_existing"), 3.2333333, 0.26337251,
      c(2.8864917, 3.2254664, 3.5920217), "p5")
  chk(tp(ep, "prebound"), 0.71666667, 0.093647431, c(0.59430958, 0.7127354, 0.84494477), "p6")
  chk(tp(ep, "rebound_calculated"), 1.1166667, 0.093647431,
      c(0.99430958, 1.1127354, 1.2449448), "p7")
  chk(tp(ep, "rebound"), 1.015, 0.084282688, c(0.90487862, 1.0114619, 1.1304503), "p7a")
  chk(tp("processes/valuation_risks_2026", "vacancy_level"), 0.026666667, 0.014253933,
      c(0.0089787967, 0.025104814, 0.04671123), "p8")
  # D1: p2 an den Raendern
  p2 <- wsl_pert(0.95, 1.10, 1.50)
  expect_equal(p2$q(c(1e-9, 0.5, 1 - 1e-9)), c(0.95000895, 1.13189, 1.4982258), tolerance = 2e-6)
  # Auszahlungsverzug PERT(0; 0; 6) und Kuerzung Tilgungszuschuss (funding_risks, notes)
  pd <- tp("processes/funding_risks_2026", "payout_delay")
  pp <- wsl_pert(pd$min, pd$mode, pd$max)
  expect_equal(pp$mean, 1)
  expect_equal(pp$q(0.9), 2.214256, tolerance = 1e-6)
  rc <- tp("processes/funding_risks_2026", "repayment_grant_cut")
  expect_equal(sum(rc$values * rc$probs), 0.03, tolerance = 1e-12)
  cum <- cumsum(rc$probs)
  cum[length(cum)] <- 1
  qd <- function(u) rc$values[findInterval(u, cum, left.open = TRUE) + 1L]
  expect_identical(qd(c(0.95, 0.96, 1)), c(0, 0.5, 1))
  # Nutzungsdauer Waermepumpe Dreieck(15; 18; 22): Mittel 18,333, q10 16,449, q90 20,327
  u <- lib[["costs/nutzungsdauern_2026"]]$uncertainty$hp_air_water
  expect_equal((u$min + u$mode + u$max) / 3, 18.333, tolerance = 5e-5)
  expect_equal(wsl_tri_q(c(0.1, 0.9), u$min, u$mode, u$max), c(16.449, 20.327), tolerance = 5e-5)
  # Rebound-Konvention F-15: Modus 1 = Basis; Spanne relativ wie Memo 04 (0,9/1,1 bis 1,4/1,1)
  rb <- tp(ep, "rebound")
  expect_equal(rb$mode, 1)
  expect_equal(c(rb$min, rb$max), c(0.9, 1.4) / 1.1, tolerance = 0.01)
  # iid-Vorlage Leerstandsschwankung: Spalte 1 = Mittel 1,0833333
  vf <- tp("processes/valuation_risks_2026", "vacancy_fluctuation")$dist_spec
  expect_equal(wsl_pert(vf$min, vf$mode, vf$max)$mean, 1.0833333, tolerance = 1e-7)
})

test_that("CO2-Korridor: 20 komonotone Quantilpfade des Dreiecks (Teil C 2.5, 2.8 Nr. 3)", {
  lib <- wsl_lib()
  sc <- lib[["processes/co2_price_corridor_2026"]]$values$scenarios
  cp <- lib[["prices/co2_price_paths_2026"]]$values$scenarios
  yrs <- cp$mittel$years
  expect_identical(cp$niedrig$years, yrs)
  expect_identical(cp$hoch$years, yrs)
  lo <- cp$niedrig$values
  mi <- cp$mittel$values
  hi <- cp$hoch$values
  for (k in 1:20) {
    s <- sc[[sprintf("q%02d", k)]]
    expect_equal(s$prob, 0.05)
    expect_identical(s$years, yrs)
    q <- mapply(function(a, c, b) wsl_tri_q((k - 0.5) / 20, a, c, b), lo, mi, hi)
    expect_equal(s$values, q, tolerance = 0.006 / 60, info = sprintf("q%02d", k))
    expect_true(all(abs(s$values - q) <= 0.006), info = sprintf("q%02d", k))
  }
  vals <- do.call(rbind, lapply(sc, function(s) s$values))
  expect_true(all(apply(vals, 2, function(v) all(diff(v) >= 0))))     # komonoton
  expected <- colMeans(vals)
  expect_equal(round(expected, 2), c(65.00, 66.66, 66.66, 84.99, 101.65, 134.99, 181.65, 226.64,
                                     271.64, 331.12, 403.64))
  expect_equal(((lo + mi + hi) / 3)[yrs %in% c(2030, 2040)], c(85.00, 181.6667), tolerance = 1e-6)
  med2030 <- wsl_tri_q(0.5, lo[yrs == 2030], mi[yrs == 2030], hi[yrs == 2030])
  expect_equal(med2030, 83.17, tolerance = 1e-4)
  expect_true(sc$q10$values[yrs == 2030] < med2030 && med2030 < sc$q11$values[yrs == 2030])
  expect_identical(sc$q10$values[yrs == 2030], 82.13)
  expect_identical(sc$q11$values[yrs == 2030], 84.23)
})

# ---------------------------------------------------------------------------------------------
# Preise (Teil C 3.6) und Referenzszenarien (Teil C 5.0)
# ---------------------------------------------------------------------------------------------

test_that("Energiepreise: Ratenreihe = Erwartungspfad der Mean-Reversion (Teil C 3.6, F-08)", {
  lib <- wsl_lib()
  ep <- lib[["prices/energy_prices_2026"]]$values$market$energy_price
  mr <- lib[["processes/energy_prices_mr_2026"]]
  pbar_2026 <- c(gas = 0.05833, gas_mfh = 0.05580, oil = 0.06723, lpg = 0.06134454, power = 0.30252,
                 power_mfh = 0.25919589, heatpump_power = 0.21008, heatpump_power_mfh = 0.20168,
                 district_heating = 0.12605, pellets = 0.05882353)
  for (c in wsl_carriers()) {
    e <- ep[[c]]
    v <- mr$values[[c]]
    g <- v$growth$mean
    expect_identical(e$base_date, "2027-01-01", info = c)
    expect_identical(e$growth$fill, "locf", info = c)
    expect_identical(e$growth$before, "first", info = c)
    s <- unlist(e$growth$series)
    expect_identical(names(s), as.character(2027:2051), info = c)
    expect_equal(s[["2051"]], g, info = c)
    # p_norm = pbar_2026 x (1 + g) (2.4)
    expect_equal(v$p_norm, pbar_2026[[c]] * (1 + g), tolerance = 1e-7, info = c)
    pbar <- v$p_norm / (1 + g)
    yy <- 2026:2060
    det <- pbar * (1 + g)^(yy - 2026) * (e$start / pbar)^(v$phi^(yy - 2026))
    rates <- det[-1] / det[-length(det)] - 1
    # Raten mit acht Nachkommastellen; p_norm selbst ist auf acht Stellen gerundet
    expect_lte(max(abs(unname(s[as.character(2027:2050)]) - rates[1:24])), 5e-8)
    # Pfad aus der Ratenreihe: Abweichung zum exakten Erwartungspfad bis 2057 < 1,5e-4 relativ
    r_used <- vapply(yy[-1], function(y) s[[as.character(min(y, 2051))]], double(1))
    path <- e$start * cumprod(1 + r_used)
    rel <- abs(path / det[-1] - 1)[yy[-1] <= 2057]
    expect_lt(max(rel), if (c == "district_heating") 1.5e-4 else 7.2e-5)
    # fallback p0 der Prozessbibliothek = Basisfall 2027 (R-88)
    expect_equal(mr$fallback[[c]]$p0, e$start * (1 + s[["2027"]]), tolerance = 2e-7, info = c)
    expect_equal(mr$fallback[[c]]$p0, det[2], tolerance = 1e-7, info = c)
    # Konsistenz Basisfall - MC: E[P_y | g] = det(2026 + y), y = 1..31 (Toleranz 2e-4 relativ)
    p0 <- path[1]
    y <- 1:31
    ep_y <- v$p_norm * (1 + g)^(y - 1) * (p0 / v$p_norm)^(v$phi^(y - 1))
    expect_lt(max(abs(ep_y / path[y] - 1)), 2e-4)
  }
  # Pruefwerte det(2027) / det(2037) / det(2057) (exakt bzw. aus der Ratenreihe +- 1,5e-4)
  det_of <- function(c, years) {
    e <- ep[[c]]
    s <- unlist(e$growth$series)
    r <- vapply(2027:max(years), function(y) s[[as.character(min(y, 2051))]], double(1))
    (e$start * cumprod(1 + r))[years - 2026]
  }
  yrs <- c(2027, 2037, 2057)
  expect_equal(det_of("gas", yrs), c(0.06329700, 0.07277935, 0.10777105), tolerance = 1.5e-4)
  expect_equal(det_of("oil", yrs), c(0.09076136, 0.08425657, 0.12421418), tolerance = 1.5e-4)
  expect_equal(det_of("pellets", yrs), c(0.06774348, 0.07723595, 0.12647099), tolerance = 1.5e-4)
  expect_equal(det_of("power", yrs), c(0.31816764, 0.37679493, 0.55893563), tolerance = 1.5e-4)
})

test_that("Energiepreise: Herleitung der Startwerte netto, Komponenten, USt (Teil C 2.4, 3.6)", {
  v <- wsl_lib()[["prices/energy_prices_2026"]]$values
  ep <- v$market$energy_price
  co2 <- function(ef) ef * 0.065                                   # 65 EUR/t netto
  expect_equal(ep$gas$start, 0.120 / 1.19 - co2(0.1814) - 0.0257, tolerance = 1e-5 / 0.06)
  expect_equal(ep$gas_mfh$start, 0.112 / 1.19 - co2(0.1814) - 0.0219, tolerance = 1e-5 / 0.06)
  expect_equal(ep$oil$start, (0.140 - 0.0206) / 1.19, tolerance = 1e-5 / 0.1)
  expect_equal(ep$lpg$start, 0.105 / 1.19 - co2(0.2358), tolerance = 1e-7)
  expect_equal(ep$power$start, 0.375 / 1.19, tolerance = 1e-5 / 0.3)
  expect_equal(ep$power_mfh$start, v$components$power_mfh$total_net)
  expect_equal(ep$heatpump_power$start, 0.260 / 1.19, tolerance = 1e-5 / 0.2)
  expect_equal(ep$district_heating$start, 0.156 / 1.19, tolerance = 1e-5 / 0.13)
  expect_equal(ep$pellets$start, 0.085 / 1.19, tolerance = 1e-7)
  # Netzentgelte netto auf 0,01 ct gerundet (Memo 07 4.0: 3,06 / 2,61 ct brutto)
  expect_equal(v$market$energy_network_fee$gas$start * 1.19, 0.0306, tolerance = 2e-3)
  expect_equal(v$market$energy_network_fee$gas_mfh$start * 1.19, 0.0261, tolerance = 2e-3)
  expect_equal(v$market$bio_fuel_premium$start, 0.060)
  # Grundpreise netto = brutto 180 / 140 / 120 EUR / 1,19
  expect_equal(unlist(v$base_fees_eur_pa) * 1.19, c(gas_efh = 180, heatpump_power_efh = 140,
                                                    power_household = 120), tolerance = 1e-4)
  # USt: 19 % fuer alle Traeger einschliesslich Holzpellets (F-16), 7 % nur Brennholz
  expect_equal(v$vat_rate$standard, 0.19)
  expect_equal(v$vat_rate$pellets, 0.19)
  expect_equal(v$vat_rate$firewood, 0.07)
  # Spannen der Komponenten enthalten die Gesamtpreise
  for (c in setdiff(wsl_carriers(), c("power_mfh", "heatpump_power_mfh"))) {
    k <- v$components[[c]]
    tot <- k$total_incl_co2_65 %||% k$total
    expect_true(tot >= k$range[1] && tot <= k$range[2], info = c)
  }
})

test_that("CO2-Preispfade (Teil C 3.6): Korridore, Fortschreibung nach 2050, Basispfad", {
  lib <- wsl_lib()
  v <- lib[["prices/co2_price_paths_2026"]]$values
  for (s in c("niedrig", "mittel", "hoch")) {
    x <- v$scenarios[[s]]
    expect_identical(x$interpolate, "linear")
    expect_true(all(diff(x$years) > 0))
    v50 <- x$values[x$years == 2050]
    # Stuetzwerte 2060/2070 auf zwei Nachkommastellen gerundet
    expect_lte(abs(x$values[x$years == 2060] - v50 * 1.02^10), 0.005)
    expect_lte(abs(x$values[x$years == 2070] - v50 * 1.02^20), 0.005)
  }
  expect_true(all(v$scenarios$niedrig$values <= v$scenarios$mittel$values &
                    v$scenarios$mittel$values <= v$scenarios$hoch$values))
  expect_identical(v$market$co2_price, v$scenarios$mittel)
})

test_that("CO2-Pfad der Referenzszenarien: Memo-07-Pfad aus den St\u00fctzstellen (3.6, 5.0)", {
  lib <- wsl_lib()
  v <- lib[["prices/co2_price_path_referenzszenarien_2026"]]$values
  sh <- lib[["prices/referenzszenarien_2026"]]$values$shared
  expect_equal(sh$co2_2030, 70 + 2 * 5)
  expect_equal(sh$co2_2040, 105 * 1.03^5, tolerance = 1e-10)
  expect_identical(names(v$series), as.character(2026:2070))
  expect_identical(c(v$fill, v$before), c("locf", "first"))
  env <- list(shared.co2_2030 = sh$co2_2030, shared.co2_2040 = sh$co2_2040)
  ev <- function(node) {
    if (is.numeric(node)) return(node)
    if (!is.null(node$ref)) return(env[[node$ref]])
    eval(parse(text = node$expr), envir = env, enclos = baseenv())
  }
  path <- vapply(v$series, ev, double(1))
  expect_equal(unname(path[as.character(2026:2035)]), c(60, 60, 70, 75, seq(80, 105, by = 5)))
  # shared.co2_2040 ist auf acht Nachkommastellen angegeben (121,72377780)
  expect_equal(unname(path[as.character(2035:2070)]), 105 * 1.03^(0:35), tolerance = 1e-9)
  expect_equal(unname(round(path[c("2040", "2050", "2056", "2066")], 2)),
               c(121.72, 163.59, 195.33, 262.51))
  # gezogene Stuetzstellen wirken: 2030 = 200 -> 2031 = 200 + (105 - 200) / 5
  env$shared.co2_2030 <- 200
  expect_equal(ev(v$series[["2031"]]), 181)
})

test_that("Referenzszenarien: Nettopreise = brutto / 1,19, Konventionen (Teil C 5.0 Nr. 5)", {
  v <- wsl_lib()[["prices/referenzszenarien_2026"]]$values
  ep <- v$market$energy_price
  gross <- c(gas = 0.0815, gas_mfh = 0.0730, heatpump_power = 0.240, heatpump_power_mfh = 0.250,
             power = 0.370)
  # Nettowerte = brutto / 1,19 auf acht Nachkommastellen (Abweichung nach USt <= 6e-9 EUR/kWh,
  # d. h. < 0,001 EUR je Pruefwert)
  for (c in names(gross)) {
    expect_equal(ep[[c]]$start, round(gross[[c]] / 1.19, 8), tolerance = 1e-12, info = c)
    expect_lt(abs(ep[[c]]$start * 1.19 - gross[[c]]), 6e-9)
    expect_equal(ep[[c]]$growth, 0.02, info = c)
  }
  fee <- v$market$energy_network_fee
  expect_equal(fee$gas$start, round(0.0306 / 1.19, 8), tolerance = 1e-12)
  expect_equal(fee$gas_mfh$start, round(0.0261 / 1.19, 8), tolerance = 1e-12)
  expect_identical(v$market$bio_fuel_premium_base$start, 0.060)
  expect_identical(fee$gas$growth$ref, "shared.network_fee_growth_gas")
  expect_identical(fee$gas_mfh$growth$ref, "shared.network_fee_growth_gas_mfh")
  fees <- vapply(v$carriers, function(x) x$base_fee_eur_pa, double(1))
  expect_equal(fees * 1.19, c(gas = 180, gas_mfh = 0, heatpump_power = 140, heatpump_power_mfh = 0,
                              power = 120), tolerance = 1e-8)
  expect_equal(v$carriers$gas$emission_factor_kg_kwh, 0.181)
  # Bruttopreis Gas EFH bei 60 EUR/t: 8,15 + 3,06 + 1,2923 = 12,5023 ct (notes)
  expect_equal((ep$gas$start + v$market$energy_network_fee$gas$start) * 1.19 + 0.181 * 0.060 * 1.19,
               0.125023, tolerance = 1e-5)
  expect_identical(c(v$shared$network_fee_growth_gas, v$shared$construction_price_shift,
                     v$shared$bio_premium_factor), c(0.03, 0L, 1L))
  expect_equal(v$market$mortgage_rate, 0.040)
  expect_identical(v$market$maintenance_index$ref, "market.construction_price_index")
})

test_that("Zinsen, Makropfade, EEG: Querbez\u00fcge zwischen Eintr\u00e4gen (2.2, 2.3, 3.6)", {
  lib <- wsl_lib()
  ir <- lib[["prices/interest_rates_2026_10"]]$values
  expect_equal(ir$market$mortgage_rate, lib[["processes/mortgage_rate_vasicek_2026"]]$fallback$r0)
  expect_equal(ir$market$bund_yield_10y, lib[["processes/bund10_vasicek_2026"]]$fallback$r0)
  expect_equal(ir$market$mortgage_spread, lib[["processes/mortgage_spread_ar1_2026"]]$fallback$x0)
  # KfW-Momentaufnahme 22.10.2026 = Sollzinsen der Foerdereintraege
  snap <- list(
    kfw_261 = "funding/kfw_261_wg_kredit_2026",
    kfw_297_298_standard = "funding/kfw_298_khn_vermietung",
    kfw_297_298_eh55 = "funding/kfw_298_khn_eh55_stufe",
    kfw_300_308 = "funding/kfw_300_wohneigentum_familien",
    kfw_358 = "funding/kfw_358_ergaenzungskredit_plus",
    kfw_359 = "funding/kfw_359_ergaenzungskredit"
  )
  for (k in names(snap)) {
    variants <- wsl_get(snap[[k]], "loan.variants")
    for (vn in names(ir$kfw_snapshot_2026_10_22[[k]])) {
      expect_equal(variants[[vn]]$rate_pa, ir$kfw_snapshot_2026_10_22[[k]][[vn]],
                   info = paste(k, vn))
    }
  }
  expect_equal(wsl_get("funding/kfw_297_khn_eh55_stufe", "loan.variants"),
               wsl_get("funding/kfw_298_khn_eh55_stufe", "loan.variants"))
  # Langfristmittel des Spread-Modells: 0,028 + 0,010 = 0,038 (notes)
  expect_equal(lib[["processes/mortgage_spread_ar1_2026"]]$values$mu, 0.010)
  # Makropfade: langfristig VPI + 0,75 Pp bzw. + 1,0 Pp
  m <- lib[["prices/macro_paths_2026"]]$values$market
  for (y in c("2028", "2029")) {
    pi_y <- m$inflation$series[[y]]
    expect_equal(m$construction_price_index$series[[y]], pi_y + 0.0075, tolerance = 1e-12)
    expect_equal(m$maintenance_index$series[[y]], pi_y + 0.010, tolerance = 1e-12)
  }
  expect_identical(m$operating_cost_growth, list(ref = "market.inflation", offset = 0.005))
  # EEG: Mischsatz S3 (30 kWp) und Einspeiseverguetung (S3-T6)
  fi <- lib[["prices/eeg_feed_in_2026"]]$values$market$feed_in_tariff
  mix <- (10 * fi$partial_le10kwp + 20 * fi$partial_10_40kwp) / 30
  expect_equal(mix, 0.070067, tolerance = 1e-5)
  expect_equal(round(18900 * mix, 2), 1324.26)
  expect_equal(fi$partial_40_100kwp, 0.0545)
  expect_equal(lib[["prices/referenzszenarien_2026"]]$values$market$feed_in_tariff,
               fi[c("partial_le10kwp", "partial_10_40kwp", "partial_40_100kwp")])
})

# ---------------------------------------------------------------------------------------------
# Foerderung (Teil C 3.4)
# ---------------------------------------------------------------------------------------------

test_that("KfW 261: Tilgungszusch\u00fcsse je EH-Stufe und H\u00f6chsts\u00e4tze (Teil C 3.4)", {
  exp_tab <- list(eh40 = c("eh40", 0.10, 0.15, 0.10, 0.15, 0.40),
                  eh55 = c("eh55", 0.05, 0.10, 0.10, 0.15, 0.35),
                  eh70 = c("eh70", 0.00, 0.05, 0.10, 0.05, 0.20),
                  eh85 = c("eh85", 0.00, 0.05, NA, NA, 0.05),
                  denkmal = c("eh_denkmal", 0.05, 0.10, NA, NA, 0.10))
  for (k in names(exp_tab)) {
    id <- paste0("funding/kfw_261_", k)
    p <- wsl_payload(id)
    x <- exp_tab[[k]]
    expect_identical(p$eligibility$conditions$efficiency_standard, x[1])
    br <- p$repayment_grant$base_rates
    expect_equal(c(br$ee, br$nh), as.numeric(x[2:3]))
    b <- p$repayment_grant$bonuses
    expect_equal(c(b$wpb$rate %||% NA_real_, b$sersan$rate %||% NA_real_), as.numeric(x[4:5]),
                 info = k)
    top <- max(unlist(br)) + sum(vapply(b %||% list(), function(z) z$rate, double(1)))
    expect_equal(top, as.numeric(x[6]), tolerance = 1e-12, info = k)
    expect_lte(top, p$repayment_grant$max_total_share + 1e-12)
    # geerbte gemeinsame Konditionen
    expect_identical(p$program_code, "261")
    expect_identical(p$loan$default_variant, "v30_5_10")
    expect_true(p$eligibility$conditions$ee_or_nh_class == "required")
  }
  # Pruefwert k1 (S1-T3): EH 70 EE + WPB, Kredit 1.264.000 + Baubegleitung 36.000 -> 144.400
  p70 <- wsl_payload("funding/kfw_261_eh70")
  rate <- p70$repayment_grant$base_rates$ee + p70$repayment_grant$bonuses$wpb$rate
  tz <- rate * 1264000 + p70$construction_supervision$repayment_grant_share * 36000
  expect_equal(tz, 144400)
  # Pruefwert k2: 150.000 EUR 30/5/10 zu 3,65 %, TZ 10 % -> Annuitaet 9.249,88 bzw. 8.324,90
  v <- p70$loan$variants$v30_5_10
  n <- v$term_years - v$grace_years
  expect_equal(round(wsl_annuity(150000, v$rate_pa, n), 2), 9249.88)
  expect_equal(round(wsl_annuity(150000 * 0.9, v$rate_pa, n), 2), 8324.90)
})

test_that("KfW 458/459: Degression, Zuschussbausteine, Pr\u00fcff\u00e4lle (Teil C 3.4)", {
  p <- wsl_payload("funding/kfw_458_heizung_privat")
  deg <- p$degression
  expect_length(deg, 2L)
  kb <- function(date) wsl_degressed(p$rate_components$klimageschwindigkeit$rate, deg[[1L]], date)
  cap1 <- function(date, pay = p) {
    rule <- Filter(function(r) grepl("cap_eur$", r$target), pay$degression)[[1L]]
    expect_identical(rule$target, "basis.eligible_cost_caps_per_building[1].cap_eur")
    wsl_degressed(pay$basis$eligible_cost_caps_per_building[[1L]]$cap_eur, rule, date)
  }
  dates <- c("2026-07-21", "2027-02-01", "2027-08-01", "2028-02-01", "2028-08-01", "2029-02-01",
             "2029-08-01", "2030-02-01", "2030-08-01", "2035-01-01")
  expect_equal(vapply(dates, kb, double(1)), c(0.16, 0.12, 0.08, 0.04, 0, 0, 0, 0, 0, 0),
               tolerance = 1e-12, ignore_attr = TRUE)
  expect_equal(vapply(dates, cap1, double(1)), c(28000, 27250, 26500, 25750, 25000, 24250, 23500,
                                                 22750, 22000, 22000), ignore_attr = TRUE)
  expect_equal(kb("2027-01-31"), 0.16)
  # Einkommensbonus: Schwellen 30/40/50 TEUR, Verschiebung einmal bei mindestens einem Kind (F-01)
  sch <- p$rate_components$einkommen$schedule_by_taxable_income
  inc <- function(zve, kids = 0L, per_child = sch$child_u18_threshold_shift_per_child) {
    n_shift <- if (kids > 0) (if (isTRUE(per_child)) kids else 1) else 0
    shift <- sch$child_u18_threshold_shift_eur * n_shift
    sch$rates[findInterval(zve - shift, sch$thresholds_eur, left.open = TRUE) + 1L]
  }
  expect_false(sch$child_u18_threshold_shift_per_child)
  grund <- p$rate_components$grund$rate
  capped <- function(r) min(r, p$rate_cap$default)
  # Memo 02 Rechenbeispiel 6: WP 32.000, zvE 45.000 ohne Kind
  wp <- function(date) capped(grund + kb(date) + inc(45000)) * min(32000, cap1(date))
  expect_equal(wp("2027-01-31"), 15680)
  expect_equal(wp("2027-02-01"), 14170)
  expect_equal(wp("2028-08-01"), 10000)
  # S4-T1/T8: zvE 58.000, mindestens ein Kind, Kessel 18 Jahre (kein Klimabonus)
  expect_equal(inc(58000, kids = 2L), 0.10)
  expect_equal(capped(grund + inc(58000, kids = 1L)) * 28000, 11200)
  # zwei Kinder mit Klimabonus: einmalige Verschiebung 15.680; je Kind 0,76 -> Deckel 0,70 -> 19.600
  expect_equal(capped(grund + 0.16 + inc(58000, kids = 2L)) * 28000, 15680)
  expect_equal(capped(grund + 0.16 + inc(58000, kids = 2L, per_child = TRUE)) * 28000, 19600)
  expect_equal(grund * 28000, 8400)                        # Kleinvermieter: nur Grundfoerderung
  expect_equal(p$rate_cap$exceptions[[1L]]$cap, 0.80)
  # KfW 459: Satz 0,30, Boni entfallen, eigene Degression nur fuer die Hoechstkosten (X-02)
  q <- wsl_payload("funding/kfw_459_heizung_unternehmen")
  expect_null(q$rate_components$klimageschwindigkeit)
  expect_null(q$rate_components$einkommen)
  expect_identical(names(q$rate_components), "grund")
  expect_length(q$degression, 1L)
  expect_identical(q$rate_cap, list(default = 0.30, exceptions = list()))
  tiers <- function(date) {
    t <- q$basis$eligible_cost_caps_per_building
    t[[1L]]$cap_eur <- cap1(date, q)
    t
  }
  expect_equal(wsl_caps_total(tiers("2027-01-15"), 12), 151000)
  expect_equal(q$rate_cap$default * min(153560, wsl_caps_total(tiers("2027-01-15"), 12)), 45300)
  expect_equal(wsl_caps_total(tiers("2027-02-01"), 12), 150250)
  expect_equal(q$rate_cap$default * wsl_caps_total(tiers("2027-02-01"), 12), 45075)
  expect_equal(q$rate_cap$default * wsl_caps_total(tiers("2026-10-01"), 10), 40500)   # KfW-Beispiel
  expect_setequal(q$eligibility$applicants,
                  c("unternehmen", "kommunales_unternehmen", "genossenschaft", "contractor",
                    "gemeinnuetzig"))
})

test_that("KfW 358/359, 297/298, 300/308: Konditionen und Pr\u00fcff\u00e4lle (Teil C 3.4)", {
  p358 <- wsl_payload("funding/kfw_358_ergaenzungskredit_plus")
  p359 <- wsl_payload("funding/kfw_359_ergaenzungskredit")
  # S4-T7: 70.000 zu 2,53 %, 25/3/10, jaehrlich -> Zinsen 1.771,00, Annuitaet 22 J. 4.188,12
  v <- p358$loan$variants$v25_3_10
  n <- v$term_years - v$grace_years
  expect_equal(70000 * v$rate_pa, 1771)
  expect_equal(round(wsl_annuity(70000, v$rate_pa, n), 2), 4188.12)
  expect_equal(45000 * v$rate_pa, 1138.5)
  expect_equal(round(wsl_annuity(45000, v$rate_pa, n), 2), 2692.36)
  expect_equal(p358$eligibility$conditions$taxable_income_max_eur, 90000)
  expect_equal(p358$loan$max_share_of_eligible_costs, 1)
  # 359 erbt Kreditanteil (N-11), ohne Einkommensgrenze und ohne Variante 5/1/5
  expect_equal(p359$loan$max_share_of_eligible_costs, 1)
  expect_null(p359$eligibility$conditions$taxable_income_max_eur)
  expect_null(p359$eligibility$conditions$owner_occupied)
  expect_identical(names(p359$loan$variants), c("v10_2_10", "v25_3_10", "v35_5_10"))
  expect_identical(p359$program_code, "359")
  # S2-T2/T4: KfW 298 EH-55-Stufe, 36 WE x 100.000, 35/5/10 zu 2,19 %
  p298e <- wsl_payload("funding/kfw_298_khn_eh55_stufe")
  v <- p298e$loan$variants$v35_5_10
  k <- 36 * p298e$basis$loan_cap_per_unit_eur
  expect_equal(k, 3600000)
  expect_equal(k * v$rate_pa, 78840)
  expect_equal(round(wsl_annuity(k, v$rate_pa, v$term_years - v$grace_years), 2), 164969.40)
  expect_null(p298e$basis$loan_cap_per_unit_qng_eur)
  expect_equal(p298e$budget_risk$approval_probability, 0.80)
  # S5 V1: KfW 297 EH-55-Stufe, 100.000, monatlich -> Zins 182,50, Annuitaet 379,19
  p297e <- wsl_payload("funding/kfw_297_khn_eh55_stufe")
  v <- p297e$loan$variants$v35_5_10
  expect_equal(p297e$loan$payments_per_year, 12)
  expect_equal(100000 * v$rate_pa / 12, 182.5)
  n_m <- 12 * (v$term_years - v$grace_years)
  expect_equal(round(wsl_annuity(100000, v$rate_pa / 12, n_m), 2), 379.19)
  expect_identical(p297e$eligibility$applicants, "privatperson")
  expect_identical(p297e$eligibility$conditions$efficiency_standard, "eh55")
  p297 <- wsl_payload("funding/kfw_297_khn_selbstnutzung")
  expect_identical(p297$eligibility$conditions$efficiency_standard, "eh40")
  expect_identical(p297$loan$default_variant, "v35_5_10")
  # KfW 300 (S5-T2/T3): 2 Kinder -> Grenze 100.000; Hoechstbetrag 170.000 bzw. 220.000 mit QNG
  p300 <- wsl_payload("funding/kfw_300_wohneigentum_familien")
  lim <- p300$eligibility$conditions$taxable_income_max_eur
  limit <- function(kids) lim$base + lim$per_additional_child * (kids - 1)
  expect_equal(limit(1), 90000)
  expect_equal(limit(2), 100000)
  cap <- function(kids, qng = FALSE) {
    r <- Filter(function(z) kids >= z$children_from && kids <= z$children_to,
                p300$basis$loan_cap_by_children_eur)[[1L]]
    if (qng) r$cap_qng else r$cap
  }
  expect_equal(c(cap(2), cap(2, TRUE), cap(3), cap(5, TRUE)), c(170000, 220000, 200000, 270000))
  # KfW 308: eigene Staffel, keine EH-40/LCA-Bedingung, Bestandserwerb
  p308 <- wsl_payload("funding/kfw_308_jung_kauft_alt")
  expect_identical(p308$eligibility$project_types, "erwerb_sanierung")
  expect_identical(vapply(p308$basis$loan_cap_by_children_eur, function(z) z$cap, double(1)),
                   c(140000, 160000, 180000))
  expect_null(p308$eligibility$conditions$efficiency_standard)
  expect_identical(p308$eligibility$conditions$energy_class_at_application, c("F", "G", "H"))
  expect_identical(p308$loan$variants, p300$loan$variants)
})

test_that("BAFA BEG EM und \u00a7 35c: Bausteine und Pr\u00fcff\u00e4lle (Teil C 3.4)", {
  b <- wsl_payload("funding/bafa_beg_em_huelle")
  tier1 <- b$basis$eligible_cost_caps_per_unit_per_calendar_year[[1L]]
  grant <- function(cost, isfp = TRUE, mode = b$rate_components$isfp$mode) {
    cap <- if (isfp) tier1$cap_isfp_eur else tier1$cap_eur
    k <- min(cost, cap)
    bonus <- if (!isfp) 0 else if (mode == "excess_over_threshold") {
      b$rate_components$isfp$rate * max(0, k - b$rate_components$isfp$threshold$single_unit_eur)
    } else {
      b$rate_components$isfp$rate * k
    }
    b$rate_components$grund$rate * k + bonus
  }
  expect_identical(b$rate_components$isfp$mode, "excess_over_threshold")
  expect_equal(grant(85988.87), 10500)                                 # S4-T4, 2030
  expect_equal(grant(85988.87, mode = "whole_amount"), 12000)
  expect_equal(round(grant(55405.82), 2), 9581.16)                     # 2033
  expect_equal(round(grant(55405.82, mode = "whole_amount"), 2), 11081.16)
  expect_equal(grant(40000), 6500)                                     # Beispiel Memo 02
  expect_identical(b$basis$cap_period, "calendar_year")
  f <- wsl_payload("funding/bafa_beg_em_fachplanung")
  expect_equal(f$rate_components$grund$rate, 0.50)
  e <- wsl_payload("funding/estg_35c")
  expect_equal(sum(e$credit$schedule_shares), e$credit$total_share, tolerance = 1e-12)
  expect_equal(e$credit$cap_per_object_eur, e$credit$total_share * 200000)
  expect_equal(e$budget_risk$approval_probability, 1)
  expect_true(all(c("funding/kfw_458_heizung_privat", "funding/bafa_beg_em_huelle",
                    "funding/kfw_261_wg_kredit_2026", "funding/kfw_358_ergaenzungskredit_plus",
                    "funding/kfw_359_ergaenzungskredit") %in% e$cumulation$exclusive_with))
})

# ---------------------------------------------------------------------------------------------
# Recht (Teil C 3.5)
# ---------------------------------------------------------------------------------------------

test_that("Mietrecht: Pr\u00fcff\u00e4lle m1-m5 mit den Parametern der Bibliothek (Teil C 3.5)", {
  m <- wsl_payload("legal/mietrecht_2026")
  f <- wsl_payload("legal/mietrecht_559f_2026")
  # m1: 70 m2, 7,50 EUR/m2, K 60.000, IH 18.000, TZ 3.000, Zinsermaessigung 162
  u <- (60000 - 18000 - 3000) * m$s559$rate_pa - 162
  expect_equal(u, 2958)
  expect_equal(u / 70 / 12, 3.52, tolerance = 1e-3)
  low <- 7.50 < m$s559$low_rent_threshold_eur_m2_month
  cap <- if (low) m$s559$cap_low_rent_eur_m2_month else m$s559$cap_eur_m2_month
  expect_equal(min(u, cap * 70 * 12), 2520)
  # m2: Paragraph 559e, 15.000 EUR/WE, Zuschuss 4.500, Kappe 0,50 EUR/m2
  u <- m$s559e$rate_pa * ((1 - m$s559e$flat_maintenance_share) * 15000 - 4500)
  expect_equal(u, 825)
  expect_equal(min(u, m$s559e$cap_eur_m2_month * 70 * 12), 420)
  # m3 (S3-T3): 0,10 x (0,85 x 153.560 - 45.300) = 8.522,60; gekappt 5.040,00
  u <- m$s559e$rate_pa * ((1 - m$s559e$flat_maintenance_share) * 153560 - 45300)
  expect_equal(u, 8522.60, tolerance = 1e-12)
  expect_equal(min(u, m$s559e$cap_eur_m2_month * 840 * 12), 5040)
  # m4 (S3-T4, Plan-JAZ 2,4 < 2,5): Reihenfolgen halve_then_funds / funds_then_halve
  expect_identical(m$interpretation$s559f_order, "halve_then_funds")
  expect_true(2.4 < f$jaz_threshold)
  k <- 153560 * f$reduction_factor
  u559e <- function(cost) m$s559e$rate_pa * ((1 - m$s559e$flat_maintenance_share) * cost - 45300)
  expect_equal(u559e(k), 1996.30, tolerance = 1e-12)
  expect_equal(u559e(153560) * f$reduction_factor, 4261.30, tolerance = 1e-12)
  # m5 (S1-T4): (874.303,50 - 144.400) x 0,08 - 1.300.000 x 0,0035 = 53.842,28
  expect_equal((874303.50 - 144400) * m$s559$rate_pa - 1300000 * 0.0035, 53842.28,
               tolerance = 1e-12)
  # Paragraph 559f: Grenzfall >= 2,5, Halbierung, Plan-JAZ
  expect_identical(c(f$comparison, f$jaz_basis), c("ge", "plan"))
  expect_equal(f$exceptions$flow_temperature_max_c, 55)
})

test_that("CO2KostAufG, Bio-Treppe, Emissionsfaktoren, USt (Teil C 3.5)", {
  co2 <- wsl_payload("legal/co2kostaufg_2026")
  st <- co2$stage_model
  upper <- vapply(st, function(s) s$upper_kg_m2a, double(1))
  share <- vapply(st, function(s) s$landlord_share, double(1))
  expect_true(all(diff(upper) > 0) && all(diff(share) > 0))
  expect_identical(upper[length(upper)], Inf)
  stage <- function(x) share[which(x < upper)[1L]]                    # Obergrenze exklusiv
  expect_identical(c(stage(27.3), stage(31.7), stage(23.5), stage(11.99), stage(12), stage(60)),
                   c(0.40, 0.40, 0.30, 0, 0.10, 0.95))
  # Rechenbeispiel 4: 1.000 m2, 150 kWh/m2a Gas, EF 0,182 -> 27,3 kg/m2a; 65 EUR/t
  kosten <- 1000 * 150 * 0.182 / 1000 * 65 * 1.19
  expect_equal(kosten, 2111, tolerance = 1 / 2111)
  expect_equal(kosten * stage(27.3), 845, tolerance = 1 / 845)
  expect_equal(kosten * co2$s5a$co2_landlord_share, 1056, tolerance = 1 / 1056)
  # Bio-Treppe: Stufen ab 1. Januar; 2045-Schalter erweitert die Stufen um 100 %
  b26 <- wsl_payload("legal/gmodg_bio_treppe_2026")$min_bio_share
  b45 <- wsl_payload("legal/gmodg_bio_treppe_2045")$min_bio_share
  expect_identical(b26$interpolate, "step")
  expect_identical(b45$years[seq_along(b26$years)], b26$years)
  expect_identical(b45$values[seq_along(b26$values)], b26$values)
  expect_identical(c(utils::tail(b45$years, 1), utils::tail(b45$values, 1)), c(2045, 1))
  expect_identical(wsl_payload("legal/gmodg_bio_treppe_2045")$bio_carriers,
                   wsl_payload("legal/gmodg_bio_treppe_2026")$bio_carriers)
  # EBeV 2030 Anlage 2: Umrechnungen
  ef <- wsl_payload("legal/emission_factors_co2cost_2026")
  expect_equal(ef$natural_gas_hs, 0.0558 * 3.2508, tolerance = 1e-4)
  expect_equal(ef$natural_gas_hi, ef$natural_gas_hs / ef$conversion$gas_hs_to_hi, tolerance = 1e-3)
  expect_equal(ef$heating_oil_hi, 0.074 * 3.6, tolerance = 1e-12)
  expect_equal(ef$lpg_hi, 0.0655 * 3.6, tolerance = 1e-12)
  expect_equal(ef$conversion$heating_oil_kwh_per_litre, 42.8 * 0.845 / 3.6, tolerance = 1e-3)
  geg <- wsl_payload("legal/emission_factors_geg_anlage9")
  expect_equal(c(geg$natural_gas, geg$heating_oil, geg$electricity_grid), c(240, 310, 560))
  ust <- wsl_payload("legal/umsatzsteuer_2026")
  expect_identical(c(ust$standard, ust$reduced), c(0.19, 0.07))
  expect_equal(ust$pv_zero_rate$max_kwp_without_proof, 30)
  behg <- wsl_payload("legal/behg_ets2_2026")
  expect_identical(behg$corridor_2027$status, "adopted_pending")
  expect_true(behg$corridor_2027$status %in% vocab_codes("legal_status"))
  expect_equal(unlist(behg$price_history_eur_t), c(`2021` = 25, `2022` = 30, `2023` = 30,
                                                   `2024` = 45, `2025` = 55))
})

# ---------------------------------------------------------------------------------------------
# Kosten und Bewertung (Teil C 3.7, 3.8)
# ---------------------------------------------------------------------------------------------

test_that("Kosten: IWU-Kostenfunktionen, Bewirtschaftung, Nebenkosten (Teil C 3.7)", {
  iwu <- wsl_payload("costs/kostenfunktionen_sanierung_iwu_2026")
  f <- function(k, x) iwu$envelope[[k]]$a + iwu$envelope[[k]]$b * x
  expect_equal(f("etics_full", 16), 248.32, tolerance = 1e-12)
  expect_equal(f("etics_energy_related", 16), 118.60, tolerance = 1e-12)
  expect_equal(f("pitched_roof_full", 20), 398.80, tolerance = 1e-12)
  expect_equal(f("pitched_roof_energy_related", 20), 113.70, tolerance = 1e-12)
  expect_equal(f("basement_ceiling_no_cladding", 10), 77.50, tolerance = 1e-12)
  expect_equal(f("flat_roof_full", 20), 357.50, tolerance = 1e-12)
  expect_equal(f("top_ceiling_walkable", 20), 118.90, tolerance = 1e-12)
  sysf <- function(k, an) iwu$systems[[k]]$a * an^iwu$systems[[k]]$exponent * an
  expect_equal(sysf("gas_condensing_boiler", 1300), 55000, tolerance = 0.005)
  expect_equal(sysf("gas_condensing_boiler", 180), 21200, tolerance = 0.005)
  w3 <- iwu$windows$extra_cost_2wsv_to_3wsv_mfh
  expect_equal(w3$a * 1.5^w3$exponent, 102, tolerance = 0.005)
  expect_equal(iwu$ohnehin_share$etics, 0.50)
  # Ohnehin-Anteile der IWU = Katalog der Massnahmentypen
  types <- wsl_get("costs/massnahmentypen_2026", "types")
  codes <- c("daemmung_fassade", "daemmung_dach_steil", "daemmung_dach_flach", "fenster")
  oh_types <- vapply(types[codes], function(t) t$ohnehin_share, double(1))
  expect_equal(unname(oh_types),
               unlist(iwu$ohnehin_share[c("etics", "pitched_roof", "flat_roof", "windows")],
                      use.names = FALSE))
  # ImmoWertV Anlage 3: Fortschreibungsreihe endet mit den aktuellen Werten
  bw <- wsl_payload("costs/bewirtschaftung_immowertv_2026")
  expect_equal(bw$history$admin_per_unit_eur_pa[["2026"]], bw$admin_per_unit_or_efh_eur_pa)
  expect_equal(bw$history$maintenance_eur_m2_pa[["2026"]], bw$maintenance_eur_m2_pa)
  expect_equal(bw$rent_loss_risk_share$residential, 0.02)
  iibv <- wsl_payload("costs/bewirtschaftung_ii_bv_2026")
  expect_identical(names(iibv$maintenance_eur_m2_pa), c("lt22y", "ge22y", "ge32y"))
  expect_true(all(diff(unlist(iibv$maintenance_eur_m2_pa)) > 0))
  # Erwerbsnebenkosten: Notar + Grundbuch = 1,5 % (Memo 03 10.4; X-19)
  en <- wsl_payload("costs/erwerbsnebenkosten_2026")
  expect_equal(en$notary_share + en$land_registry_share, 0.015, tolerance = 1e-12)
  expect_identical(names(en),
                   c("notary_share", "land_registry_share", "broker_share", "other_share"))
  kz <- wsl_payload("costs/kostenzuschlaege_2026")
  expect_identical(c(kz$share_kg700_of_kg300_400, kz$contingency_share), c(0.20, 0.10))
  # Plausibilitaet S1 V2: 907 EUR/m2 im Intervall der EH-70-Pakete
  sp <- wsl_lib()[["costs/sanierung_eh_pakete_2026"]]$uncertainty$eh70.cost_eur_m2
  expect_true(907 >= sp$min && 907 <= sp$max)
  bk <- wsl_payload("costs/betriebskosten_benchmarks_2026")
  expect_true(bk$heating_dhw_eur_m2_month$min <= bk$heating_dhw_eur_m2_month$mean &&
                bk$heating_dhw_eur_m2_month$mean <= bk$heating_dhw_eur_m2_month$max)
  # Nutzungsdauern: GND = ImmoWertV Anlage 1
  expect_equal(wsl_get("costs/nutzungsdauern_2026", "building_total_immowertv"),
               wsl_get("valuation/immowertv_anlage1_2_2026", "gnd_years.mfh"))
})

test_that("Bewertung: Restnutzungsdauer Anlage 2, Liegenschaftszins, Faktoren (Teil C 3.8)", {
  a <- wsl_payload("valuation/immowertv_anlage1_2_2026")
  expect_identical(names(a$rnd_coefficients), paste0("p", 0:20))
  expect_identical(names(a$modernisation_points_max), vocab_codes("modernization_element"))
  expect_equal(sum(unlist(a$modernisation_points_max)), 20)
  rnd <- function(points, alter, gnd = 80) {
    k <- a$rnd_coefficients[[paste0("p", points)]]
    if (alter / gnd >= k$rel_age_min) k$a * alter^2 / gnd - k$b * alter + k$c * gnd else gnd - alter
  }
  expect_equal(c(rnd(0, 56), rnd(8, 56), rnd(12, 56), rnd(18, 56)), c(24.0, 38.0, 45.9968, 58.56),
               tolerance = 1e-12)
  expect_equal(rnd(0, 20), 60)                               # junge Gebaeude: GND - Alter
  rel <- vapply(a$rnd_coefficients, function(k) k$rel_age_min, double(1))
  expect_true(all(diff(rel) <= 0))
  # Rechenbeispiel 7: Kapitalisierungsfaktor LZ 3 %, RND 50 = 25,7298
  expect_equal((1 - 1.03^-50) / 0.03, 25.7298, tolerance = 5e-6)
  lz <- wsl_payload("valuation/liegenschaftszinsen_2026")
  expect_true(lz$default_preset %in% names(lz$presets))
  expect_equal(lz$presets[[lz$default_preset]], 0.035)
  expect_true(all(diff(unlist(lz$presets)) > 0))
  kp <- wsl_payload("valuation/kaufpreisfaktoren_2026")
  expect_true(all(vapply(kp$presets, function(r) r[1] < r[2], logical(1))))
  vk <- wsl_payload("valuation/verkaufskosten_2026")
  expect_true(vk$sale_cost_share >= sum(vapply(vk$components, min, double(1))) &&
                vk$sale_cost_share <= sum(vapply(vk$components, max, double(1))))
})

# ---------------------------------------------------------------------------------------------
# Verweise (R-89, R-104) und Abgleich mit der Spezifikation
# ---------------------------------------------------------------------------------------------

test_that("Verweise in Paketdateien (Defaults, Profile, Beispiele) l\u00f6sen auf (R-104)", {
  ext <- system.file("extdata", package = "vofi")
  files <- list.files(ext, pattern = "\\.ya?ml$", recursive = TRUE)
  files <- files[!startsWith(files, "library/")]
  lib <- wsl_lib()
  n <- 0L
  for (f in files) {
    for (r in wsl_refs(wsl_read(file.path(ext, f)))) {
      info <- paste(f, r$path)
      expect_true(utl_is_library_id(r$from),
                  info = paste(info, "from ist keine Bibliotheks-id (R-110)"))
      if (!utl_is_library_id(r$from)) next
      expect_true(r$from %in% names(lib), info = paste(info, r$from))
      if (!is.null(r$use) && r$from %in% names(lib)) {
        expect_true(path_exists(wsl_payload(r$from), r$use), info = paste(info, r$from, r$use))
      }
      n <- n + 1L
    }
  }
  # Bibliothek selbst: keine eingebetteten from-Verweise in Nutzlasten
  for (id in names(lib)) {
    expect_length(wsl_refs(lib[[id]]$values), 0L)
    n <- n + 1L
  }
  expect_gt(n, 0L)
})

test_that("Bibliotheksverweise der Spezifikation (Teil A 2.2, B 7.1, C 5) l\u00f6sen auf", {
  # Verweise aus global.yaml (Teil A 2.2), item_defaults (Teil B 7.1), Profilen, Referenz-
  # szenarien und Overlay-Kern (Teil C 5.0); Liste aus den Spezifikationstexten.
  refs <- list(
    c("prices/macro_paths_2026", "market"),
    c("prices/interest_rates_2026_10", "market.mortgage_rate"),
    c("prices/interest_rates_2026_10", "market.bund_yield_10y"),
    c("prices/interest_rates_2026_10", "market.mortgage_spread"),
    c("prices/co2_price_paths_2026", "scenarios.mittel"),
    c("prices/energy_prices_2026", "market.energy_price"),
    c("prices/energy_prices_2026", "market.energy_network_fee"),
    c("prices/energy_prices_2026", "market.bio_fuel_premium"),
    c("prices/eeg_feed_in_2026", "market.feed_in_tariff"),
    c("valuation/verkaufskosten_2026", "sale_cost_share"),
    c("valuation/liegenschaftszinsen_2026", "presets.mid_city"),
    c("valuation/immowertv_anlage1_2_2026", "gnd_years.mfh"),
    c("valuation/immowertv_anlage1_2_2026", "rnd_coefficients"),
    c("valuation/immowertv_anlage1_2_2026", "modernisation_points_max"),
    c("valuation/kaufpreisfaktoren_2026", "gross_rent_multiplier"),
    c("costs/bewirtschaftung_immowertv_2026", "admin_per_unit_or_efh_eur_pa"),
    c("costs/bewirtschaftung_immowertv_2026", "admin_per_garage_eur_pa"),
    c("costs/bewirtschaftung_immowertv_2026", "maintenance_eur_m2_pa"),
    c("costs/bewirtschaftung_immowertv_2026", "rent_loss_risk_share.residential"),
    c("costs/bewirtschaftung_ii_bv_2026", "maintenance_eur_m2_pa"),
    c("costs/kostenzuschlaege_2026", "share_kg700_of_kg300_400"),
    c("costs/kostenzuschlaege_2026", "contingency_share"),
    c("costs/erwerbsnebenkosten_2026", "notary_share"),
    c("costs/erwerbsnebenkosten_2026", "land_registry_share"),
    c("costs/massnahmentypen_2026", "types"),
    c("processes/energy_prices_mr_2026", "bio_premium_factor"),
    c("processes/energy_prices_mr_2026", "network_fee_growth"),
    c("processes/cost_risks_2026", "overrun_retrofit"),
    c("processes/funding_risks_2026", "feed_in_continuation"),
    c("processes/valuation_risks_2026", "cap_rate_shock"),
    c("processes/valuation_risks_2026", "remaining_life_shock"),
    c("processes/mortgage_rate_vasicek_2026", NA),
    c("processes/inflation_ar1_2026", NA),
    c("processes/shock_correlations_2026", NA),
    c("prices/referenzszenarien_2026", NA),
    c("prices/co2_price_path_referenzszenarien_2026", NA),
    c("funding/estg_35c", NA), c("funding/kfw_261_eh55", NA), c("funding/kfw_261_eh70", NA)
  )
  for (c in wsl_carriers()) refs[[length(refs) + 1L]] <- c("processes/energy_prices_mr_2026", c)
  lib <- wsl_lib()
  for (r in refs) {
    expect_true(r[1] %in% names(lib), info = r[1])
    if (!is.na(r[2])) {
      expect_true(path_exists(wsl_payload(r[1]), r[2]), info = paste(r, collapse = " use "))
    }
  }
  # Basiswerte, auf die sich Teil A 2.2 bezieht
  expect_equal(wsl_get("valuation/verkaufskosten_2026", "sale_cost_share"), 0.03)
  expect_equal(wsl_get("valuation/liegenschaftszinsen_2026", "presets.mid_city"), 0.035)
  expect_equal(wsl_get("valuation/immowertv_anlage1_2_2026", "gnd_years.mfh"), 80)
  expect_equal(wsl_get("valuation/kaufpreisfaktoren_2026", "gross_rent_multiplier"), 20)
  expect_equal(wsl_get("costs/bewirtschaftung_immowertv_2026", "admin_per_unit_or_efh_eur_pa"), 367)
  expect_equal(wsl_get("costs/bewirtschaftung_immowertv_2026", "admin_per_garage_eur_pa"), 48)
  expect_equal(wsl_get("costs/bewirtschaftung_immowertv_2026", "maintenance_eur_m2_pa"), 14.4)
  expect_equal(unlist(wsl_get("costs/bewirtschaftung_ii_bv_2026", "maintenance_eur_m2_pa")),
               c(lt22y = 11.50, ge22y = 14.58, ge32y = 18.62))
  expect_equal(wsl_get("prices/macro_paths_2026", "market.rent_growth"), 0.0175)
  expect_equal(wsl_get("prices/interest_rates_2026_10", "market.mortgage_rate"), 0.041)
})

test_that("Eintr\u00e4ge entsprechen den Listings der Spezifikation (Teil C 2, 3, 5.0)", {
  spec <- testthat::test_path("..", "..", "docs", "spec",
                              "01c_feldkatalog_stochastik_bibliothek_szenarien.md")
  skip_if_not(file.exists(spec), "Spezifikation nicht verf\u00fcgbar (installiertes Paket)")
  lines <- readLines(spec, encoding = "UTF-8", warn = FALSE)
  starts <- which(lines == "```yaml")
  listings <- list()
  for (s in starts) {
    e <- s + which(lines[(s + 1L):length(lines)] == "```")[1L]
    body <- lines[(s + 1L):(e - 1L)]
    m <- regmatches(body[1L], regexec("^# inst/extdata/library/(\\S+)\\.yaml", body[1L]))[[1L]]
    if (length(m) == 2L) {
      listings[[m[2L]]] <- yaml::yaml.load(paste(body, collapse = "\n"), handlers = wsl_handlers(),
                                           eval.expr = FALSE)
    }
  }
  lib <- wsl_lib()
  expect_setequal(names(listings), names(lib))
  for (id in names(lib)) {
    p <- wsl_listing_pair(id, lib[[id]], listings[[id]])
    expect_identical(p$actual, p$listing, info = id)
  }
  # dokumentierte Abweichung: vat_rate.pellets nach Teil B 7.3 (F-16) in der Bibliothek
  id <- "prices/energy_prices_2026"
  expect_equal(lib[[id]]$values$vat_rate$pellets, 0.19)
  # Gegenprobe: nach der Korrektur des Listings (Aenderungsantrag, Schluessel an beliebiger
  # Stelle) bleibt der Abgleich gruen; eine abweichende Angabe im Listing wird erkannt
  fixed <- listings[[id]]
  fixed$values$vat_rate <- c(fixed$values$vat_rate, list(pellets = 0.19))
  p <- wsl_listing_pair(id, lib[[id]], fixed)
  expect_identical(p$actual, p$listing)
  fixed$values$vat_rate$pellets <- 0.07
  p <- wsl_listing_pair(id, lib[[id]], fixed)
  expect_false(identical(p$actual, p$listing))
  # ohne Korrektur: eine fehlerhafte Bibliotheksangabe neben pellets wird weiter erkannt
  wrong <- lib[[id]]
  wrong$values$vat_rate$firewood <- 0.19
  p <- wsl_listing_pair(id, wrong, listings[[id]])
  expect_false(identical(p$actual, p$listing))
})

test_that("Overlay mit jeder use:-Vorlage jeder Datei in processes/ genau einmal (2.8 Nr. 4)", {
  lib <- wsl_lib()
  ov <- wsl_overlay_all()
  st <- ov$stochastic
  expect_named(st, c("processes", "parameters", "correlations"))
  entries <- c(st$processes, st$parameters)
  keys <- names(entries)
  # Overlay-Schluessel (1.3), eindeutig ueber processes und parameters (ein Strom je Schluessel)
  expect_identical(anyDuplicated(keys), 0L)
  expect_true(all(grepl("^[a-z][a-z0-9_]*$", keys) & nchar(keys) <= 40L))
  # jedes Ziel hoechstens einmal (1.1 Nr. 4, Spec 00 11.8)
  targets <- vapply(entries, function(x) x$target, character(1))
  expect_identical(anyDuplicated(targets), 0L)
  # Abdeckung: jede Vorlage jeder Datei genau einmal, use: genau bei Nutzlasten mit mehreren
  # Vorlagen (R-87); die Korrelationslisten ueber correlations
  expected <- character(0)
  for (id in wsl_ids_of("processes")) {
    tpl <- wsl_templates(lib[[id]]$values)
    if (is.null(tpl)) next
    expected <- c(expected, if (identical(names(tpl), ".single")) id else paste(id, names(tpl)))
  }
  used <- vapply(entries, function(x) paste(c(x$from, x$use), collapse = " "), character(1))
  expect_identical(anyDuplicated(used), 0L)
  expect_setequal(used, expected)
  corr <- vapply(st$correlations, function(x) x$from, character(1))
  expect_setequal(c(unique(vapply(entries, function(x) x$from, character(1))), corr),
                  wsl_ids_of("processes"))
  expect_identical(length(expected), 45L)                  # 20 Prozesse, 25 statische Vorlagen
  # Prozessvorlagen unter processes, statische unter parameters (1.3, 1.5)
  for (k in names(st$processes)) {
    expect_false(is.null(wsl_template_of(st$processes[[k]], lib)[["type"]]), info = k)
  }
  for (k in names(st$parameters)) {
    expect_true(wsl_is_dist(wsl_template_of(st$parameters[[k]], lib)), info = k)
  }
  # Prozesse: Ziel market.<name>, Schluessel = Marktname mit _ (1.10.2 Nr. 1)
  ptg <- vapply(st$processes, function(x) x$target, character(1))
  expect_match(ptg, "^market\\.")
  expect_identical(names(ptg), gsub(".", "_", sub("^market\\.", "", unname(ptg)), fixed = TRUE))
  expect_true(all(sub("\\..*$", "", sub("^market\\.", "", ptg)) %in% wsl_canonical_markets()))
  # statische Ziele: market.<name>, Felder aus Schicht 1 oder shared.<name> mit Basiswert
  for (k in names(st$parameters)) {
    x <- st$parameters[[k]]
    tpl <- wsl_template_of(x, lib)
    tg <- x$target
    info <- paste(k, tg)
    if (grepl("^market\\.", tg)) {
      expect_true(sub("^market\\.", "", tg) %in% wsl_canonical_markets(), info = info)
      next
    }
    if (tg %in% wsl_layer1_targets) next
    expect_match(tg, "^shared\\.[a-z][a-z0-9_]*$", info = info)
    b <- ov$shared[[sub("^shared\\.", "", tg)]]
    expect_true(wsl_num(b), info = info)                     # target_no_base (1.11)
    if (!wsl_num(b)) next
    apply <- tpl[["apply"]] %||% "replace"
    if (identical(apply, "replace")) {                       # base_outside_support (1.11)
      s <- wsl_support(tpl)
      expect_true(b >= s[1L] && b <= s[2L], info = info)
      if (tpl$dist %in% c("bernoulli", "discrete")) {
        expect_true(b %in% (tpl$values %||% c(0, 1)), info = info)
      }
    } else if (identical(apply, "add")) {
      expect_identical(b, 0, info = info)                    # Zuschlag auf Basis 0 (K7, N-20)
    } else {
      expect_true(b >= 0, info = info)                       # Faktor bzw. Satz (R-94)
    }
  }
  expect_setequal(names(ov$shared),
                  sub("^shared\\.", "", setdiff(grep("^shared\\.", targets, value = TRUE),
                                                wsl_layer1_targets)))
  # Basiswerte = deterministische Defaults (Konzept B12, Teil A 2.2, Teil C 2.7)
  expect_equal(ov$shared$maintenance_rate_eur_m2_pa, 14.4)
  zero <- c("cap_rate_shock", "remaining_life_offset_years", "delay_months_retrofit",
            "payout_delay_months", "repayment_grant_cut_share")
  expect_identical(unlist(ov$shared[zero], use.names = FALSE), rep(0, length(zero)))
  # die Bibliothekspaare der Parameterkorrelation treffen Schluessel des Overlays (nicht verworfen)
  pairs <- lib[["processes/param_correlations_2026"]]$values
  hit <- vapply(pairs, function(p) all(c(p[[1L]], p[[2L]]) %in% keys), logical(1))
  expect_identical(hit, c(TRUE, TRUE, FALSE))                 # mortgage_rate.theta ist fest
  shock_keys <- unique(unlist(lapply(lib[["processes/shock_correlations_2026"]]$values,
                                     function(p) c(p[[1L]], p[[2L]]))))
  expect_true(all(shock_keys %in% names(st$processes)))
})

test_that("Overlay-Eintr\u00e4ge mit Bibliotheksvorlagen validieren (2.8 Nr. 4; nach WS-A/WS-B)", {
  # Wirksam, sobald vofi_read_scenario() Bibliotheksverweise aufloest (WS-A) und vofi_validate()
  # das Overlay prueft (WS-B); bis dahin uebersprungen. Das Overlay enthaelt jede Vorlage jeder
  # Datei in processes/ (Abdeckung im Test davor).
  skip_if_stub("vofi_read_scenario", "vofi_validate")
  base <- wsl_read(system.file("extdata", "examples", "skeleton.yaml", package = "vofi"))
  ov <- wsl_overlay_all()
  base$shared <- deep_merge(base$shared %||% list(), ov$shared)
  base$stochastic <- ov$stochastic
  path <- withr::local_tempfile(fileext = ".yaml")
  yaml::write_yaml(base, path)
  not_yet <- function(e) testthat::skip(paste("noch nicht implementiert:", conditionMessage(e)))
  spec <- tryCatch(vofi_read_scenario(path), vofi_error_not_implemented = not_yet)
  tryCatch(vofi_resolve(spec), vofi_error_not_implemented = not_yet)   # from: in Schicht 3 (WS-A)
  res <- vofi_validate(spec, min_severity = "error")
  errs <- res[res$severity == "error", , drop = FALSE]
  expect_identical(nrow(errs), 0L, info = paste(errs$code, errs$path, collapse = "; "))
})
