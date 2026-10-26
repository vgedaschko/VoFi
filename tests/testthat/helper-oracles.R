# Testorakel (WS-T; Spec 00 Abschnitt 15.1, 15.3; Memo 01 §10): Szenarien und Sollwerte aus
# tests/testthat/fixtures/oracles/ (Sollwerte erzeugt mit data-raw/export_oracles.py aus der
# unveränderten Python-Referenz data-raw/vofi_ref.py).

#' Verzeichnis der Orakel-Fixtures
oracle_dir <- function() testthat::test_path("fixtures", "oracles")

#' Kennungen aller Orakel (15.1; ergänzt um (h), Spec 00 8.10)
oracle_ids <- function() {
  c("a", "a3", "a_unlevered", "b1", "b2", "c1", "c1_unlevered", "c2", "d", "e", "f", "g", "h")
}

#' Orakel mit Vergleich zweier Varianten (Spalte `variant` in den Sollwerten)
oracle_variant_ids <- function() "g"

#' Kanonisches Szenario eines Orakels (fixtures/oracles/<id>.yaml)
oracle_scenario <- function(id) {
  id <- match.arg(id, oracle_ids())
  skip_if_stub("vofi_read_scenario")
  vofi_read_scenario(file.path(oracle_dir(), paste0(id, ".yaml")))
}

#' Sollwerte eines Orakels
#'
#' @return list(rows = data.frame(row_key, t, value, variant),
#'   kpis = data.frame(kpi, value, na_reason, variant)); `variant` ist NA außer bei (g).
oracle_expected <- function(id) {
  id <- match.arg(id, oracle_ids())
  read <- function(what, cc) {
    f <- file.path(oracle_dir(), paste0(id, "_", what, ".csv"))
    x <- utils::read.csv(f, colClasses = cc, na.strings = "", stringsAsFactors = FALSE)
    if (is.null(x$variant)) x$variant <- NA_character_
    x
  }
  rows <- read("rows", c(row_key = "character", t = "integer", value = "numeric"))
  kpis <- read("kpis", c(kpi = "character", value = "numeric", na_reason = "character"))
  kpis$na_reason[!is.na(kpis$na_reason) & kpis$na_reason == ""] <- NA_character_
  list(rows = rows[, c("row_key", "t", "value", "variant")],
       kpis = kpis[, c("kpi", "value", "na_reason", "variant")])
}

#' Ledger eines Ergebnisses auf die Orakelzeilen abbilden (Spec 00 15.3)
#'
#' @param result `vofi_result` (bzw. Liste mit `ledger` und `opportunity`).
#' @param sim Lauf.
#' @return data.frame(row_key, t, value).
oracle_view <- function(result, sim = 1L) {
  led <- result$ledger
  rows <- led$rows
  v <- led$values
  t1 <- led$T + 1L
  z <- rep(0, t1)
  pick <- function(sel) {
    keys <- rows$key[sel]
    if (length(keys) == 0L) return(z)
    Reduce(`+`, lapply(keys, function(k) v[[k]][sim, ]))
  }
  key <- function(k) if (is.null(v[[k]])) z else v[[k]][sim, ]
  out <- list(
    cf_project = pick(rows$section == "project" & rows$cash),
    grant_cash = pick(rows$section == "grants" & rows$cash),
    equity_in = pick(rows$section == "equity" & rows$category == "equity_in" & rows$cash),
    equity_call = pick(rows$section == "equity" & rows$category == "equity_call"),
    shortfall = pick(rows$section == "equity" & rows$category == "shortfall"),
    equity_out = pick(rows$section == "equity" & rows$category == "equity_out" & rows$cash)
  )
  for (k in unique(rows$source_id[rows$section == "loans"])) {
    p <- paste0("loan_", k, "_")
    out[[paste0(p, "draw")]] <- key(paste0(p, "draw"))
    out[[paste0(p, "repay_total")]] <- key(paste0(p, "repay")) + key(paste0(p, "repay_balloon"))
    for (nm in c("prepay", "interest", "fees", "repayment_grant", "balance")) {
      out[[paste0(p, nm)]] <- key(paste0(p, nm))
    }
  }
  for (nm in c("draw", "repay", "interest", "balance")) {
    out[[paste0("od_", nm)]] <- key(paste0("od_", nm)) + key(paste0("odp_", nm))
  }
  for (nm in c("dep_invest", "dep_withdraw", "dep_interest", "dep_balance", "tax",
               "balance_check", "net_position")) {
    out[[nm]] <- key(nm)
  }
  if (!is.null(result$opportunity$BS)) out$opp_net_position <- result$opportunity$BS[sim, ]
  data.frame(row_key = rep(names(out), each = t1), t = rep(seq_len(t1) - 1L, length(out)),
             value = unlist(out, use.names = FALSE), stringsAsFactors = FALSE)
}

#' Kennzahl mit Raten-Toleranz (Spec 00 15.3: 1e-9 für Raten und Verhältnisse)
oracle_is_rate_kpi <- function(kpi) {
  grepl("^(roe_|irr_|dscr_min|dscr_mean|icr_|ltv_|lending_ratio)", kpi)
}

#' Ist die Kennzahl (ohne Suffix _ex_rv) registriert?
oracle_kpi_registered <- function(kpi) {
  reg_has("kpi", sub("_ex_rv$", "", kpi))
}

#' Szenario eines Orakels bauen und rechnen (nur registrierte Kennzahlen, 4.7 Schicht 8)
#'
#' Kennzahlen der Orakel-YAML, deren Typ noch nicht registriert ist (Lieferung WS-D2), werden
#' über Schicht 8 aus `analysis.kpis` entfernt; sie prüft `expect_oracle()` dann nicht und
#' meldet sie als nicht geprüft. Hinweise der Plausibilitätsprüfung (z. B. Ü3-Heuristik in
#' (a3), 8.9) und Meldungen werden abgefangen.
oracle_result <- function(id, variant = "base", scenario = NULL) {
  skip_if_stub("vofi_read_scenario", "vofi_build", "vofi_run")
  sc <- scenario %||% oracle_scenario(id)
  ks <- sc$analysis$kpis
  ks <- ks[vapply(ks, oracle_kpi_registered, logical(1))]
  withCallingHandlers({
    model <- vofi_build(sc, variant = variant, overrides = list(analysis = list(kpis = ks)))
    res <- vofi_run(model)
  }, vofi_warning_plausibility = function(w) invokeRestart("muffleWarning"),
  vofi_message = function(m) invokeRestart("muffleMessage"))
  attr(res, "model") <- model
  res
}

#' Ergebnis gegen die Sollwerte eines Orakels prüfen (Spec 00 15.3)
#'
#' Zeilen mit `tol` (EUR, Default `vofi_tol$oracle_abs`), Kennzahlen mit `tol` bzw. 1e-9 bei
#' Raten und Verhältnissen; NA-Kennzahlen müssen denselben Begründungscode tragen.
#' @param result vofi_result.
#' @param id Orakel.
#' @param variant Variante bei Orakeln mit Spalte `variant` (Default `base`).
#' @param kpis Kennzahlen prüfen.
#' @return unsichtbar: Namen der Kennzahlen, die nicht geprüft werden konnten (nicht
#'   registriert bzw. nicht im Ergebnis).
expect_oracle <- function(result, id, tol = vofi_tol$oracle_abs, variant = NULL, kpis = TRUE) {
  ex <- oracle_expected(id)
  if (id %in% oracle_variant_ids()) {
    variant <- variant %||% "base"
    ex$rows <- ex$rows[ex$rows$variant == variant, , drop = FALSE]
    ex$kpis <- ex$kpis[ex$kpis$variant == variant, , drop = FALSE]
  }
  view <- oracle_view(result)
  m <- merge(ex$rows, view, by = c("row_key", "t"), all.x = TRUE, suffixes = c("", "_pkg"))
  missing <- unique(m$row_key[is.na(m$value_pkg)])
  testthat::expect(length(missing) == 0L,
                   paste("Orakel", id, ": Zeilen fehlen im Ergebnis:", utl_collapse(missing)))
  dev <- abs(m$value - m$value_pkg)
  bad <- which(!is.na(dev) & dev > tol)
  examples <- sprintf("%s[t=%d]: %.8f statt %.8f", m$row_key[bad], m$t[bad],
                      m$value_pkg[bad], m$value[bad])
  msg <- paste0("Orakel ", id, ": ", length(bad), " Zeilenwerte weichen um mehr als ",
                format(tol), " ab, z. B. ", paste(utils::head(examples, 5L), collapse = "; "))
  testthat::expect(length(bad) == 0L, msg)
  unchecked <- character(0)
  if (kpis) {
    for (q in seq_len(nrow(ex$kpis))) {
      k <- ex$kpis$kpi[q]
      if (!(k %in% names(result$kpis))) {
        unchecked <- c(unchecked, k)
        next
      }
      got <- result$kpis[[k]][1L]
      code <- result$kpi_na[[k]][1L] %||% NA_character_
      want <- ex$kpis$value[q]
      want_code <- ex$kpis$na_reason[q]
      if (is.na(want)) {
        testthat::expect(is.na(got) && identical(code, want_code),
                         sprintf("Orakel %s: %s soll NA (%s) sein, ist %s (%s)", id, k,
                                 want_code, format(got), format(code)))
      } else {
        tk <- if (oracle_is_rate_kpi(k)) 1e-9 else tol
        testthat::expect(!is.na(got) && abs(got - want) <= tk,
                         sprintf("Orakel %s: %s = %.10f statt %.10f (Toleranz %g)", id, k, got,
                                 want, tk))
      }
    }
  }
  invisible(unchecked)
}

#' Referenz-Engine auf ein Orakelszenario anwenden (über das gebaute Modell)
oracle_ref_run <- function(id, variant = "base") {
  res <- oracle_result(id, variant)
  model <- attr(res, "model")
  s <- spec_simple_from_model(model)
  s$kpis <- unique(sub("_ex_rv$", "", oracle_expected(id)$kpis$kpi))
  s$kpis <- setdiff(s$kpis, c("delta_vs_reference", "prob_better_than_ref"))
  ref <- ref_engine_run(s)
  ref$result <- res
  ref
}

#' Ergebnis der Referenz-Engine wie ein vofi_result für oracle_view()/expect_oracle()
ref_as_result <- function(ref) {
  keys <- names(ref$rows)
  sec <- rep("engine", length(keys))
  src <- rep("engine", length(keys))
  for (id in ref$loan_ids) {
    sel <- startsWith(keys, paste0("loan_", id, "_")) & !endsWith(keys, "_balance")
    sec[sel] <- "loans"
    src[sel] <- id
  }
  rows <- data.frame(key = keys, section = sec, category = "", cash = FALSE, source_id = src,
                     stringsAsFactors = FALSE)
  eq <- keys %in% c("equity_call", "shortfall")
  rows$section[eq] <- "equity"
  rows$category[eq] <- keys[eq]
  rows$cash[eq] <- TRUE
  values <- ref$rows
  for (k in names(ref$exo)) {
    r <- ref$exo[[k]]
    rows <- rbind(rows, data.frame(key = k, section = r$section, category = r$category,
                                   cash = isTRUE(r$cash), source_id = sub("__.*$", "", k),
                                   stringsAsFactors = FALSE))
    values[[k]] <- r$values
  }
  list(ledger = list(rows = rows, values = values, n = ref$n, T = ref$T),
       opportunity = list(BS = ref$opp$BS, EW = ref$opp$EW), kpis = ref$kpis,
       kpi_na = ref$kpi_na)
}

#' Absolute Abweichung höchstens `tol` (Namen und Attribute werden ignoriert)
expect_abs <- function(object, expected, tol, info = NULL) {
  a <- as.double(unlist(object, use.names = FALSE))
  b <- as.double(unlist(expected, use.names = FALSE))
  dev <- if (length(a) == length(b)) max(abs(a - b), 0) else Inf
  testthat::expect(isTRUE(dev <= tol),
                   sprintf("Abweichung %g > %g%s: %s statt %s", dev, tol,
                           if (is.null(info)) "" else paste0(" (", info, ")"),
                           paste(format(a, digits = 12), collapse = " "),
                           paste(format(b, digits = 12), collapse = " ")))
  invisible(object)
}

#' Kennzahlwert einer Sollwerttabelle (optional je Variante)
oracle_kpi_value <- function(ex, kpi, variant = NA_character_) {
  k <- ex$kpis
  sel <- k$kpi == kpi & (is.na(variant) | k$variant %in% variant)
  k$value[sel][1L]
}

#' Zeilenwert einer Sollwerttabelle (optional je Variante)
oracle_row_value <- function(ex, key, t, variant = NA_character_) {
  r <- ex$rows
  sel <- r$row_key == key & r$t == t & (is.na(variant) | r$variant %in% variant)
  r$value[sel][1L]
}
