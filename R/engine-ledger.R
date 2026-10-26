# Ledger-Zugriffe und Engine-Zeilen (WS-D, Spec 00 Abschnitte 7.3, 7.4, 7.7, 7.8).
# Phase-0-Minimalfassung, Eigentuemer: WS-D. Umgesetzt: ledger_add/get/select/sum/subset_sims/
# long, Metadaten der Komponenten-, Kredit- und Engine-Zeilen mit Grob-Ordnung (7.8).
# Offen fuer WS-D: ledger_select(rv_basis = ...) ueber das Zusatzfeld der Merkzeilen
# residual_path ist umgesetzt; Steuer-Merkzeilen tax_report_<name> (10.5) bei aktiven Modulen.

#' Zeilen an einen Ledger anhängen
#' @param led `vofi_ledger` oder `NULL`.
#' @param rows Data Frame aus `new_ledger_rows()`.
#' @param values benannte Liste n x (T+1).
#' @return `vofi_ledger` (sortiert nach `order`, stabil).
#' @noRd
ledger_add <- function(led, rows, values) {
  if (is.null(led)) {
    all_rows <- rows
    all_values <- values
  } else {
    all_rows <- rbind(led$rows, rows)
    all_values <- c(led$values, values)
  }
  if (anyDuplicated(all_rows$key)) {
    vofi_abort("engine.key_collision", row = all_rows$key[duplicated(all_rows$key)][1L],
               .class = "vofi_error_engine")
  }
  ord <- order(all_rows$order, method = "radix")
  all_rows <- all_rows[ord, , drop = FALSE]
  rownames(all_rows) <- NULL
  n <- if (length(all_values) > 0L) nrow(all_values[[1L]]) else 1L
  big_t <- if (length(all_values) > 0L) ncol(all_values[[1L]]) - 1L else 0L
  new_vofi_ledger(all_rows, all_values[all_rows$key], n = n, T = big_t)
}

#' Werte einer Ledger-Zeile
#' @noRd
ledger_get <- function(led, key) {
  v <- led$values[[key]]
  if (is.null(v)) {
    vofi_abort("engine.key_unknown", row = key, .class = "vofi_error_engine")
  }
  v
}

#' Schlüssel nach Tags auswählen (nie nach Schlüsselmustern, 7.3)
#' @return Zeichenvektor der Schlüssel.
#' @noRd
ledger_select <- function(led, section = NULL, category = NULL, tax_category = NULL,
                          cash = NULL, kind = NULL, source_id = NULL, existing_debt = NULL,
                          rv_basis = NULL) {
  r <- led$rows
  keep <- rep(TRUE, nrow(r))
  if (!is.null(section)) keep <- keep & r$section %in% section
  if (!is.null(category)) keep <- keep & r$category %in% category
  if (!is.null(tax_category)) keep <- keep & r$tax_category %in% tax_category
  if (!is.null(cash)) keep <- keep & r$cash == cash
  if (!is.null(kind)) keep <- keep & r$kind %in% kind
  if (!is.null(source_id)) keep <- keep & r$source_id %in% source_id
  if (!is.null(existing_debt)) keep <- keep & r$existing_debt == existing_debt
  if (!is.null(rv_basis)) {
    rb <- vapply(r$extra, function(e) e$rv_basis %||% NA_character_, "")
    keep <- keep & !is.na(rb) & rb %in% rv_basis
  }
  r$key[keep]
}

#' Summe der gewählten Zeilen (Nullmatrix bei leerer Auswahl)
#' @return n x (T+1).
#' @noRd
ledger_sum <- function(led, ...) {
  keys <- ledger_select(led, ...)
  if (length(keys) == 0L) return(matrix(0, led$n, led$T + 1L))
  Reduce(`+`, led$values[keys])
}

#' Ledger auf einzelne Läufe einschränken
#' @noRd
ledger_subset_sims <- function(led, i) {
  vals <- lapply(led$values, function(m) m[i, , drop = FALSE])
  new_vofi_ledger(led$rows, vals, n = length(i), T = led$T)
}

#' Ledger im Long-Format (key, sim, t, value)
#' @noRd
ledger_long <- function(led) {
  n <- led$n
  n_t <- led$T + 1L
  keys <- led$rows$key
  data.frame(
    key = rep(keys, each = n * n_t),
    sim = rep(rep(seq_len(n), times = n_t), times = length(keys)),
    t = rep(rep(seq_len(n_t) - 1L, each = n), times = length(keys)),
    value = unlist(lapply(led$values[keys], as.vector), use.names = FALSE),
    stringsAsFactors = FALSE
  )
}

#' Ordnungswert einer Zeile (7.8): 1000 * Abschnitt + 10 * Kategorie + Position / 1000
#' @noRd
eng_row_order <- function(section, category, position = 0) {
  cat_row <- vocab_category(section, category)
  1000 * vocab_section_order(section) + 10 * cat_row$rank + position / 1000
}

#' Label einer Zeile mit Platzhalter {id}
#' @noRd
eng_row_label <- function(label_key, id_label = NULL, prefix = NULL) {
  txt <- if (is.null(id_label)) lbl(label_key) else lbl(label_key, id = id_label)
  if (!is.null(prefix) && utl_is_string(prefix) && nzchar(prefix)) paste0(prefix, ": ", txt) else
    txt
}

#' Anzeigetext einer Typzeile (7.1, 2.10)
#'
#' Katalogschlüssel `types.<kind>.<typ>.rows.<r>`; Nutzertypen (5.7) tragen ihre Texte als
#' Literale in `def$labels$rows`. Ohne beides gilt `fallback_key` (z. B. `core.rows.loan_<r>`
#' mit Platzhalter `{id}`).
#' @param def Typdefinition.
#' @param label_key Katalogschlüssel der Zeile.
#' @param row Name der Zeile bzw. des Musters in `def$rows`.
#' @param id Platzhalterwert `{id}` (Muster) bzw. `NULL`.
#' @param prefix Label der Komponente (wird mit ": " vorangestellt) bzw. `NULL`.
#' @param fallback_key Ersatzschlüssel bzw. `NULL`.
#' @param fallback_id Platzhalterwert für `fallback_key`.
#' @noRd
eng_type_row_label <- function(def, label_key, row, id = NULL, prefix = NULL,
                               fallback_key = NULL, fallback_id = NULL) {
  lit <- (def$labels$rows %||% list())[[row]]
  if (!lbl_has(label_key) && utl_is_string(lit)) {
    txt <- if (is.null(id)) lit else gsub("{id}", id, lit, fixed = TRUE)
    return(if (utl_is_string(prefix) && nzchar(prefix)) paste0(prefix, ": ", txt) else txt)
  }
  if (!lbl_has(label_key) && !is.null(fallback_key)) {
    return(eng_row_label(fallback_key, fallback_id))
  }
  eng_row_label(label_key, id, prefix = prefix)
}

#' Ledger-Zeilen der Kreditinstrumente: Schlüssel loan_<k>_<zeile> (7.3, 8.4)
#'
#' Label nach 7.1: Typlabel `types.instrument.<typ>.rows.<zeile>` mit vorangestelltem Label bzw.
#' id des Bausteins; ohne Typlabel `core.rows.loan_<zeile>`.
#' @param id Baustein-id.
#' @param k Position des Kredits in financing.
#' @param comp normalisierte Komponente (Tags, Label).
#' @param def Typdefinition.
#' @return Data Frame (Flüsse und Merkzeilen; der Bestand steht im Abschnitt stocks).
#' @noRd
eng_loan_rows <- function(id, k, comp, def) {
  cats <- c("draw", "repay", "repay_balloon", "prepay", "interest", "fees", "repayment_grant",
            "disagio", "assumed")
  keys <- paste0("loan_", id, "_", cats)
  shown <- comp$label %||% id
  tkeys <- paste0(reg_label_prefix(def), ".rows.", cats)
  core_keys <- paste0("core.rows.loan_", cats)
  label_key <- ifelse(vapply(tkeys, lbl_has, logical(1)), tkeys, core_keys)
  labels <- vapply(seq_along(cats), function(i) {
    eng_type_row_label(def, tkeys[i], cats[i], prefix = shown, fallback_key = core_keys[i],
                       fallback_id = shown)
  }, "")
  new_ledger_rows(
    keys, "loans", cats, measure_id = ifelse(cats == "repayment_grant",
                                             comp$measure_id %||% NA_character_, NA_character_),
    asset_id = NA_character_, program = comp$program %||% NA_character_, source_id = id,
    existing_debt = isTRUE(comp$existing), source_type = def$name,
    origin = comp$origin %||% "scenario", local_row = cats,
    label_key = unname(label_key), label = labels,
    order = 1000 * (400 + k) + 10 * seq_along(cats)
  )
}

#' Engine-Zeilen der Konten, Steuern und Prüfung (7.7)
#' @noRd
eng_engine_rows <- function() {
  spec <- list(
    equity_call = c("equity", "equity_call"), shortfall = c("equity", "shortfall"),
    od_draw = c("overdraft", "draw"), od_repay = c("overdraft", "repay"),
    od_interest = c("overdraft", "interest"), odp_draw = c("overdraft", "draw"),
    odp_repay = c("overdraft", "repay"), odp_interest = c("overdraft", "interest"),
    dep_invest = c("deposit", "invest"), dep_withdraw = c("deposit", "withdraw"),
    dep_interest = c("deposit", "interest"), dep_wht = c("tax", "withholding_tax"),
    tax = c("tax", "income_tax"), balance_check = c("check", "balance_check")
  )
  keys <- names(spec)
  sec <- vapply(spec, `[`, "", 1L)
  cat <- vapply(spec, `[`, "", 2L)
  ord <- vapply(seq_along(keys), function(i) {
    eng_row_order(sec[i], cat[i]) + if (startsWith(keys[i], "odp_")) 5 else 0
  }, double(1))
  labels <- vapply(keys, function(k) lbl(paste0("core.rows.", k)), "")
  new_ledger_rows(keys, sec, cat, local_row = keys, label_key = paste0("core.rows.", keys),
                  label = labels, order = ord)
}

#' Bestandszeilen (7.8: Kredite, od, odp, dep, tax_liability, net_position)
#' @param loan_ids ids der Kredite in financing-Reihenfolge.
#' @param labels Anzeigenamen der Kredite.
#' @noRd
eng_stock_rows <- function(loan_ids, labels = loan_ids) {
  lk <- if (length(loan_ids) > 0L) paste0("loan_", loan_ids, "_balance") else character(0)
  loan_rows <- if (length(lk) > 0L) {
    new_ledger_rows(lk, "stocks", "balance", source_id = loan_ids, local_row = "balance",
                    label_key = "core.rows.loan_balance",
                    label = vapply(labels, function(l) lbl("core.rows.loan_balance", id = l), ""),
                    order = 900000 + seq_along(lk))
  } else {
    NULL
  }
  other <- c("od_balance", "odp_balance", "dep_balance", "tax_liability", "net_position")
  cats <- c("balance", "balance", "balance", "tax_liability", "net_position")
  rows <- new_ledger_rows(other, "stocks", cats, local_row = other,
                          label_key = paste0("core.rows.", other),
                          label = vapply(other, function(k) lbl(paste0("core.rows.", k)), ""),
                          order = c(900100, 900101, 900102, 900200, 900300))
  rbind(loan_rows, rows)
}
