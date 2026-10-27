# Periodenalgorithmus und Terminalzustand ohne Restwert (WS-D, Spec 00 Abschnitte 9.3, 9.4).
# Schritte (1)-(7) aus 9.3 je Periode t = 0..T: exogene Zahlungen, Instrumente in
# financing-Reihenfolge (Instrument-Cache ohne loan_prepay, sonst init/step je Lauf mit
# capacity()/prepay() fuer Ue3), Kontozinsen auf Bestaende t-1 (D3), Abgeltungsteuer mit
# Sparer-Pauschbetrag (R-76), Steuer-Hook in jeder Periode vor dem Ausgleich (R-21), Ueberhang
# bei sinkendem Limit (6a), Ueberschuss- und Defizitkette in der konfigurierten Reihenfolge;
# danach offene Steuer am Horizont, Sacheinlage (nur Investition, R-68), Bestandssaldo,
# Finanzierungssaldo, Terminalzustand ohne Restwert (9.4, R-61) und Markierungen (9.8). Mit
# book = FALSE (Wiederholungslaeufe ueber ctx$rebalance(), 12.8) entfallen alle Buchungen;
# Rueckgabe list(BS_T, NS, BS_T_ex_rv, RW_T).
# Leistung (9.10): Die Vorbereitung (Kontoraten, Instrument-Cache, exogene Summen,
# Steuer-Eingaben, uebersetzte Ketten) entsteht je Kontext einmal (Zwischenspeicher in der
# Engine-Umgebung). Die Bestaende G, KK, KKP sind lokale n-Vektoren; die eingebauten
# Ausgleichsaktionen (8.9) rechnet eng_chain_step() direkt mit denselben Formeln wie ihre
# apply()-Funktionen in R/account-actions.R (Gleichheit prueft test-engine-balance.R), andere
# Aktionen (loan_prepay, Nutzer- bzw. ersetzte Typen) laufen ueber apply(). Rueckgaben von
# Instrumenten und Steuermodulen werden auf Laenge (1 oder n) und Endlichkeit geprueft
# (N1, vofi_error_contract mit Quelle).

#' Instrument-Cache: init/step über alle Perioden einmal je Kontext (9.3)
#'
#' Rückgaben von `step()` müssen Länge 1 oder n haben und endlich sein (N1); ein Verstoß ist
#' `vofi_error_contract` mit Baustein und Zeile.
#' @return benannte Liste je Kredit (`flows`, `memo` als n x (T+1), `balance`, `neg_amort`) mit
#'   Attribut `"totals"` (`cash` = Summe der zahlungswirksamen Flüsse, `soll` = Sollzinsen
#'   positiv, `fees` = Gebühren positiv, `bal` = Summe der Bestände).
#' @noRd
eng_inst_cache <- function(model, ctx) {
  n <- ctx$n
  n_t <- ctx$T + 1L
  fl_names <- eng_loan_flow_names()
  mm_names <- eng_loan_memo_names()
  out <- list()
  z <- matrix(0, n, n_t)
  tot <- list(cash = z, soll = z, fees = z, bal = z)
  # Summanden der Summen cash und bal in der Reihenfolge der schrittweisen Rechnung
  # 0 + draw + repay + ... je Kredit (eine Allokation ueber eng_fold_sum())
  cash_terms <- list(z)
  bal_terms <- list(z)
  for (id in names(model$instruments)) {
    k <- model$instruments[[id]]
    st <- k$def$init(k$spec, ctx)
    # Leistung (9.10): eingebaute Kredittypen mit zeilengleichem Zustand (alle Laeufe gleich,
    # z. B. fester Zins) laufen mit einer Zeile; step() rechnet zeilenweise, die auf n Zeilen
    # gehobenen Zeilen sind daher identisch zur Rechnung mit n Zeilen
    one <- if (n > 1L && eng_inst_builtin(k$def)) inst_loan_state_one(st, n) else NULL
    run <- if (is.null(one)) NULL else eng_inst_steps(k$def$step, one, ctx, 1L, n_t, id)
    if (is.null(run)) {
      run <- eng_inst_steps(k$def$step, st, ctx, n, n_t, id)
    } else {
      # Nullzeilen (z. B. Sondertilgung, Disagio) teilen die Nullmatrix z (bis auf das
      # Vorzeichen der Null gleich; eine Allokation weniger je Zeile)
      run$values <- lapply(run$values, function(m) {
        if (isTRUE(all(m == 0))) z else m[rep.int(1L, n), , drop = FALSE]
      })
      if (!is.null(run$neg_amort)) run$neg_amort <- rep_len(run$neg_amort, n)
    }
    v <- run$values
    flows <- v[fl_names]
    memo <- v[mm_names]
    bal <- v$balance
    cash_terms <- c(cash_terms, flows[c("draw", "repay", "repay_balloon", "prepay", "interest",
                                        "fees")])
    tot$soll <- tot$soll - flows$interest
    tot$fees <- tot$fees - flows$fees
    bal_terms[[length(bal_terms) + 1L]] <- bal
    eng_check_finite(memo, id)
    out[[id]] <- list(flows = flows, memo = memo, balance = bal,
                      neg_amort = run$neg_amort %||% rep(FALSE, n))
  }
  tot$cash <- eng_fold_sum(cash_terms)
  tot$bal <- eng_fold_sum(bal_terms)
  # N1 (9.7): nicht endliche Flüsse eines Kredits zeigen sich in den Summen; die Quelle
  # bestimmt die langsame Suche nur im Fehlerfall
  for (tk in names(tot)) {
    if (is.finite(sum(tot[[tk]]))) next
    for (id in names(out)) {
      eng_check_finite(c(out[[id]]$flows, list(balance = out[[id]]$balance)), id)
    }
  }
  attr(out, "totals") <- tot
  out
}

#' Schritte eines Instruments über alle Perioden (Instrument-Cache, 9.3)
#'
#' Sammelt die Spalten je Zeile als Liste und setzt die Matrizen am Ende in einem Schritt
#' zusammen (keine Nullmatrizen und keine Spaltenzuweisungen je Periode, Leistung 9.10).
#' Rückgaben müssen Länge 1 oder `nn` haben und endlich sein (N1, `eng_num()`); fehlende Zeilen
#' sind 0.
#' @param step `step()` des Typs.
#' @param st Zustand aus `init()`.
#' @param nn Zeilen des Zustands (n bzw. 1 bei zeilengleichem Zustand).
#' @param n_t Spalten T + 1.
#' @param id Baustein-id (Meldungen).
#' @return `list(values = list(<Zeile> = nn x (T+1)), neg_amort)`; Zeilen in der Reihenfolge
#'   Flüsse, Merkzeilen, `balance`.
#' @noRd
eng_inst_steps <- function(step, st, ctx, nn, n_t, id) {
  fl_names <- eng_loan_flow_names()
  mm_names <- eng_loan_memo_names()
  keys <- c(fl_names, mm_names, "balance")
  cols <- vector("list", length(keys) * n_t)
  for (j in seq_len(n_t)) {
    r <- step(st, j - 1L, ctx)
    st <- r$state
    i <- j
    rf <- r$flows
    for (f in fl_names) {
      x <- rf[[f]]
      if (!is.null(x)) {
        if (length(x) != nn || !is.double(x) || !is.null(attributes(x))) {
          x <- eng_num(x, nn, f, id)
        }
        cols[[i]] <- x
      }
      i <- i + n_t
    }
    rm <- r$memo
    for (f in mm_names) {
      x <- rm[[f]]
      if (!is.null(x)) {
        if (length(x) != nn || !is.double(x) || !is.null(attributes(x))) {
          x <- eng_num(x, nn, f, id)
        }
        cols[[i]] <- x
      }
      i <- i + n_t
    }
    x <- r$stocks$balance
    if (!is.null(x)) cols[[i]] <- eng_num(x, nn, "balance", id)
  }
  values <- vector("list", length(keys))
  names(values) <- keys
  idx <- seq_len(n_t)
  for (q in seq_along(keys)) {
    values[[q]] <- eng_cols_matrix(cols[idx], nn)
    idx <- idx + n_t
  }
  list(values = values, neg_amort = st$neg_amort)
}

#' Matrix aus einer Liste von Spalten (fehlende Spalte: 0)
#' @param v Liste der Länge T + 1 aus n-Vektoren bzw. `NULL`.
#' @param nn Zeilen.
#' @noRd
eng_cols_matrix <- function(v, nn) {
  e <- lengths(v) == 0L
  if (any(e)) v[e] <- list(rep(0, nn))
  x <- unlist(v, use.names = FALSE)
  dim(x) <- c(nn, length(v))
  x
}

#' Eingebauter Kredittyp mit dem Zustandsautomaten aus R/type-inst-loan-core.R?
#'
#' Nur dann ist der Lauf mit einer Zeile für zeilengleiche Zustände zulässig (Leistung 9.10).
#' @noRd
eng_inst_builtin <- function(def) {
  f <- def$step
  is.function(f) && identical(body(f), quote(inst_loan_step(state, t, ctx))) &&
    identical(environmentName(topenv(environment(f))), "vofi")
}

#' Matrizen eines Bausteins auf Endlichkeit prüfen (N1, 9.7)
#' @param ms benannte Liste von Matrizen bzw. Vektoren.
#' @param source Quelle (Baustein bzw. Modul) für die Meldung.
#' @noRd
eng_check_finite <- function(ms, source) {
  for (nm in names(ms)) {
    if (!is.finite(sum(ms[[nm]])) && !all(is.finite(ms[[nm]]))) {
      vofi_abort("engine.return_not_finite", what = nm, source = source,
                 .class = "vofi_error_contract",
                 .data = list(invariant = "N1", source = source, row = nm))
    }
  }
  invisible(TRUE)
}

#' Zahlungswirksame Flüsse eines Kredits (8.4)
#' @noRd
eng_loan_flow_names <- function() {
  c("draw", "repay", "repay_balloon", "prepay", "interest", "fees")
}

#' Merkzeilen eines Kredits (8.4)
#' @noRd
eng_loan_memo_names <- function() c("repayment_grant", "disagio", "assumed")

#' Rückgabe eines Typs als double n-Vektor (fehlend: 0)
#'
#' Zulässig sind `NULL` (0), Länge 1 (recycelt) und Länge n; andere Längen und nicht numerische
#' Werte sind `vofi_error_contract` (kein stilles Recycling).
#' @param what Name der Rückgabe (Meldung).
#' @param source Quelle (Baustein bzw. Modul).
#' @noRd
eng_num <- function(x, n, what = "value", source = "?") {
  if (is.null(x)) return(rep(0, n))
  k <- length(x)
  if (k == n && is.double(x) && is.null(attributes(x))) return(x)
  if (!is.numeric(x) || !(k == n || k == 1L)) {
    vofi_abort("engine.return_length", what = what, source = source, n = n, actual = k,
               .class = "vofi_error_contract",
               .data = list(invariant = "N1", source = source, row = what))
  }
  if (k == n) as.double(x) else rep(as.double(x), n)
}

#' Rückgabe eines Steuermoduls prüfen: Länge 1 oder n, endlich (N1, 10.5)
#' @noRd
eng_tax_num <- function(x, n, what, module) {
  v <- eng_num(x, n, what, paste0("tax_", module$name %||% "?"))
  if (!is.finite(sum(v))) {
    eng_check_finite(stats::setNames(list(v), what), paste0("tax_", module$name %||% "?"))
  }
  v
}

#' Instrumentzeilen einer Periode für die Steuer-Eingaben (10.4: disagio negativ)
#' @noRd
eng_inst_tax_rows <- function(id, flows, memo) {
  stats::setNames(list(flows$interest, flows$fees, -memo$disagio, memo$repayment_grant),
                  paste0("loan_", id, c("_interest", "_fees", "_disagio", "_repayment_grant")))
}

#' Methode eines Steuer-Generics (Leistung 9.10)
#'
#' Für die eingebauten Klassen `tax_none` und `vofi_tax_simple` (erste Klasse des Moduls) die
#' Methode selbst (dieselbe Methode, die der S3-Dispatch wählen würde, ohne Dispatch je
#' Periode); für alle übrigen Module das Generic.
#' @param module Steuermodul.
#' @param generic `"tax_init"`, `"tax_step"` bzw. `"tax_finalize"`.
#' @noRd
eng_tax_fun <- function(module, generic) {
  ns <- topenv(environment(eng_tax_fun))
  cl <- class(module)[1L]
  if (cl %in% c("tax_none", "vofi_tax_simple")) {
    return(get(paste0(generic, ".", cl), envir = ns, mode = "function"))
  }
  get(generic, envir = ns, mode = "function")
}

#' Vorbereitung der Periodenschleife je Kontext (9.3; Zwischenspeicher)
#'
#' @param model `vofi_model` (Investition oder Unterlassungsalternative).
#' @param ctx Laufkontext.
#' @param exo exogener Ledger.
#' @param engine_env private Engine-Umgebung oder `NULL`.
#' @param setup_key Schlüssel des Zwischenspeichers (`"inv"`, `"opp"`).
#' @return Liste `exo`, `E` (exogene Zahlungen), `F0` (exogene Zahlungen plus Kreditflüsse aus
#'   dem Cache), `use_cache`, `cache`, `totals`, `tin`, `rw_t`, `terminal_inputs`, `acc0`,
#'   `rows_meta`, `tax_keys`, `tax_slices`, `inst_tax`, `chains`, `rt`, `assets`, `measures`,
#'   `tax_step`, `tax_finalize`, `fingerprint`; `cols` (Spalten als Listen) ergänzt
#'   `eng_balance_cols()` beim ersten Wiederholungslauf.
#' @noRd
eng_balance_setup <- function(model, ctx, exo, engine_env = NULL, setup_key = "inv") {
  fp <- list(model$surplus_chain, model$deficit_chain, names(model$instruments),
             model[["tax"]], model$tax_params, model$alternative)
  if (is.environment(engine_env)) {
    hit <- engine_env$setup[[setup_key]]
    if (!is.null(hit) && identical(hit$exo, exo) && identical(hit$fingerprint, fp)) return(hit)
  }
  n_t <- ctx$T + 1L
  insts <- model$instruments
  use_cache <- !eng_has_prepay(model)
  cache <- NULL
  inv_cache <- is.environment(engine_env) && identical(setup_key, "inv")
  if (length(insts) > 0L && use_cache) {
    cache <- if (inv_cache) engine_env$inst_cache else NULL
    if (is.null(cache)) cache <- eng_inst_cache(model, ctx)
    if (inv_cache) engine_env$inst_cache <- cache
  }
  totals <- if (is.null(cache)) NULL else attr(cache, "totals")
  rows_meta <- model$rows_meta[[setup_key]]
  if (is.null(rows_meta) || !identical(rows_meta$ids, names(insts))) {
    rows_meta <- eng_model_rows(insts)
  }
  e_cash <- ledger_sum(exo, section = c("project", "grants", "equity"), cash = TRUE)
  # N1 (9.7): nicht endliche exogene Zeilen mit ihrem Schluessel melden
  if (!is.finite(sum(e_cash))) eng_check_finite(exo$values, "exo")
  tax <- model[["tax"]]
  tin <- if (!is.null(tax) && isTRUE(tax$uses_inputs)) {
    tax_inputs(exo, ctx, rows_meta$loans)
  } else {
    NULL
  }
  rw <- eng_sum_last(exo, ledger_select(exo, category = c("residual_value", "sale_cost")))
  mv_keys <- ledger_select(exo, category = "market_value")
  mv <- if (length(mv_keys) > 0L) eng_sum_last(exo, mv_keys) else NULL
  assets <- ctx$assets()
  measures <- ctx$measures()
  acc0 <- eng_acc_rates(model, ctx, engine_env)
  su <- list(
    exo = exo, E = e_cash, F0 = if (is.null(totals)) e_cash else e_cash + totals$cash,
    use_cache = use_cache, cache = cache, totals = totals, tin = tin, rw_t = rw,
    terminal_inputs = list(exo_T = lapply(exo$values, function(m) m[, n_t]),
                           residual_value = rw, market_value_T = mv,
                           horizon_date = ctx$grid$end_date, assets = assets,
                           measures = measures),
    acc0 = acc0, rows_meta = rows_meta, assets = assets, measures = measures,
    # leere Schluesseltabelle: fest, ueber Laeufe hinweg im Zwischenspeicher
    tax_keys = if (is.null(tin)) eng_memo("tax_keys_empty", list(), tax_keys_empty) else tin$keys,
    chains = eng_chain_compile(model$surplus_chain, model$deficit_chain),
    rt = eng_chain_consts(acc0),
    tax_init = if (is.null(tax)) NULL else eng_tax_fun(tax, "tax_init"),
    tax_step = if (is.null(tax)) NULL else eng_tax_fun(tax, "tax_step"),
    tax_finalize = if (is.null(tax)) NULL else eng_tax_fun(tax, "tax_finalize"),
    fingerprint = fp
  )
  # Module ohne Eingaben (uses_inputs = FALSE, 10.4): Periodenteil der Eingaben je Spalte vorab
  # (haengt nur vom Raster ab; Zwischenspeicher ueber Laeufe hinweg)
  su$tax_slices <- if (is.null(tin)) {
    eng_memo("tax_slices", list(ctx$grid, su$tax_keys), function() {
      lapply(seq_len(n_t), function(j) tax_slice(NULL, j, list(), ctx$grid, su$tax_keys))
    }, size = 8L)
  } else {
    NULL
  }
  # Module mit Eingaben: Instrumentzeilen je Spalte aus dem Cache vorab (10.4)
  su$inst_tax <- if (!is.null(tin) && !is.null(cache)) {
    lapply(seq_len(n_t), function(j) {
      out <- list()
      for (id in names(cache)) {
        cc <- cache[[id]]
        out <- c(out, eng_inst_tax_rows(
          id, list(interest = cc$flows$interest[, j], fees = cc$flows$fees[, j]),
          list(disagio = cc$memo$disagio[, j], repayment_grant = cc$memo$repayment_grant[, j])
        ))
      }
      out
    })
  } else {
    NULL
  }
  if (is.environment(engine_env)) engine_env$setup[[setup_key]] <- su
  su
}

#' Spalten einer Matrix als Liste von n-Vektoren
#' @noRd
eng_cols <- function(m) lapply(seq_len(ncol(m)), function(j) m[, j])

#' Summe der letzten Spalte gewählter Ledger-Zeilen (n-Vektor, leere Auswahl: 0)
#'
#' Gleich `ledger_sum(led, ...)[, T + 1]` (dieselbe Summationsreihenfolge), ohne die ganzen
#' Matrizen zu addieren (Leistung 9.10).
#' @param led `vofi_ledger`.
#' @param keys Zeilenschlüssel.
#' @noRd
eng_sum_last <- function(led, keys) {
  n_t <- led$T + 1L
  if (length(keys) == 0L) return(numeric(led$n))
  out <- led$values[[keys[1L]]][, n_t]
  for (k in keys[-1L]) out <- out + led$values[[k]][, n_t]
  out
}

#' Spalten der Periodenschleife als Listen (Leistung 9.10)
#'
#' Die Periodenschleife liest je Periode Listenelemente statt Matrixspalten; die Listen
#' entstehen beim ersten Lauf eines Kontexts und bleiben im Zwischenspeicher (gebuchter Lauf,
#' Unterlassungsalternative und Wiederholungsläufe, 12.8). Spalten der Kontoraten teilen sich
#' Investition und Unterlassungsalternative (`eng_cols_cached()`).
#' @return `list(F0, h, wa, s, sp, KL, Lmin, soll, fees)` (Listen der Spalten bzw. `NULL`).
#' @noRd
eng_balance_cols <- function(su, engine_env = NULL, setup_key = "inv") {
  if (!is.null(su$cols)) return(su$cols)
  a <- su$acc0
  tot <- su$totals
  cc <- function(m) eng_cols_cached(m, engine_env)
  cols <- list(F0 = eng_cols(su$F0), h = cc(a$h), wa = cc(a$wa), s = cc(a$s), sp = cc(a$sp),
               KL = cc(a$KL), Lmin = cc(a$Lmin),
               soll = if (is.null(tot)) NULL else eng_cols(tot$soll),
               fees = if (is.null(tot)) NULL else eng_cols(tot$fees))
  if (is.environment(engine_env) && !is.null(engine_env$setup[[setup_key]])) {
    engine_env$setup[[setup_key]]$cols <- cols
  }
  cols
}

#' Spalten einer Matrix mit Zwischenspeicher je Kontext (gleiche Matrix: dieselben Spalten)
#' @noRd
eng_cols_cached <- function(m, engine_env = NULL) {
  if (!is.environment(engine_env)) return(eng_cols(m))
  for (e in engine_env$col_cache) if (identical(e$m, m)) return(e$cols)
  cols <- eng_cols(m)
  engine_env$col_cache[[length(engine_env$col_cache) + 1L]] <- list(m = m, cols = cols)
  cols
}

#' Konstanten der Ausgleichsketten aus dem Kontenzustand (8.8)
#' @return `list(zv, thr, acc0)`.
#' @noRd
eng_chain_consts <- function(acc) {
  list(zv = rep(0, length(acc$G)), thr = acc$flag_threshold, acc0 = acc)
}

#' Eingebaute Ausgleichsaktionen, die `eng_chain_step()` direkt rechnet (8.9)
#'
#' `loan_prepay` läuft immer über seine `apply()`-Funktion (Instrumentzustände).
#' @noRd
eng_inline_actions <- function() {
  c("od_repay", "dep_fill_reserve", "dep_invest", "dep_withdraw", "od_draw", "dep_use_reserve",
    "equity_call", "penalty_rate", "stop")
}

#' Aktion direkt rechnen? Nur der eingebaute, unveränderte Typ (Registry-Quelle `vofi`)
#' @noRd
eng_action_inline <- function(a, nm) {
  if (!(nm %in% eng_inline_actions()) || !reg_has("account_action", nm)) return(FALSE)
  identical(reg_source("account_action", nm), "vofi") &&
    identical(a$apply, reg_get("account_action", nm)$apply)
}

#' Ausgleichsketten übersetzen (einmal je Kontext)
#' @return `list(s, d)` mit je `acts` (Typdefinitionen), `code` (Name der direkt gerechneten
#'   Aktion bzw. `""`), `ext` (Zufluss von außen, D4 `equity_call`/`stop`) und `n`.
#' @noRd
eng_chain_compile <- function(surplus, deficit) {
  keys <- eng_inline_keys()
  prog <- function(chain) {
    acts <- unname(chain)
    nm <- vapply(acts, function(a) as.character(a$name %||% "")[1L], character(1))
    code <- nm
    inl <- vapply(seq_along(acts), function(i) eng_action_inline(acts[[i]], nm[i]), logical(1))
    code[!inl] <- ""
    list(acts = acts, code = code, ext = vapply(acts, eng_action_external, logical(1)),
         n = length(acts), all_inline = all(inl),
         icode = match(code, eng_inline_actions()),
         fkeys = lapply(code, function(cd) if (nzchar(cd)) keys[[cd]]$f else character(0)),
         gkeys = lapply(code, function(cd) {
           (if (nzchar(cd)) keys[[cd]]$g else NULL) %||% character(0)
         }))
  }
  list(s = prog(surplus), d = prog(deficit))
}

#' Fluss- und Markierungsnamen der direkt gerechneten Aktionen (Reihenfolge wie in
#' `eng_chain_step()`)
#' @noRd
eng_inline_keys <- function() {
  list(od_repay = list(f = c("odp_repay", "od_repay")), dep_fill_reserve = list(f = "dep_invest"),
       dep_invest = list(f = "dep_invest"), dep_withdraw = list(f = "dep_withdraw"),
       od_draw = list(f = "od_draw", g = "overdraft_threshold"),
       dep_use_reserve = list(f = "dep_withdraw", g = "reserve_used"),
       equity_call = list(f = "equity_call", g = "shortfall"),
       penalty_rate = list(f = "odp_draw", g = c("shortfall", "limit_breach")),
       stop = list(f = "shortfall", g = c("shortfall", "stopped")))
}

#' Ausgleichsketten einer Periode (9.3 Schritt 6)
#'
#' Rechnet die Überschuss- und die Defizitkette mit den Beständen `dep` (G), `kk` (KK) und
#' `kkp` (KKP) als n-Vektoren über alle Kettenglieder (ohne Sprünge über Beträge; 2.8).
#' Eingebaute Aktionen (`code`) werden mit den Formeln aus 8.9 direkt gerechnet, alle übrigen
#' über `apply(acc, amount, t, ctx, inst)` mit dem Kontenzustand `rt$acc0` und den aktuellen
#' Beständen.
#' @param cc übersetzte Ketten (`eng_chain_compile()`).
#' @param s Saldo der Periode (n).
#' @param ist Instrumentzustände (nur ohne Cache) oder `NULL`.
#' @param rt Konstanten der Vorbereitung (`zv`, `thr`, `acc0`).
#' @param lmin,kl Spalte j von L_min und KL (n-Vektoren; KL darf `Inf` sein).
#' @param collect Flüsse und Markierungen sammeln (Buchung).
#' @param skip_external D4-Aktionen mit Zufluss von außen nicht ausführen (Sicht ohne Restwert,
#'   9.4 Nr. 2).
#' @return `list(G, KK, KKP, ist, rest_sur, rest_def, ext, flows, flags, fz)`; `ext` ist der
#'   Zufluss von außen NS (Summe der Flüsse `equity_call` und `shortfall`); `flows`, `flags`
#'   sind unverdichtete benannte Listen (Namen können mehrfach vorkommen) bzw. `NULL` ohne
#'   `collect`; `fz` markiert die Flüsse übersprungener Ketten (in allen Läufen 0).
#' @noRd
eng_chain_step <- function(cc, dep, kk, kkp, s, t, j, ctx, ist, rt, lmin, kl, collect = FALSE,
                           skip_external = FALSE) {
  zero <- vofi_tol$zero_abs
  # Minimum als pmin.int(a, b): Ergebnis a, außer wo b echt kleiner ist (gleichwertig zur
  # maskierten Zuweisung x <- a; x[b < a] <- b[b < a], 2.8 Nr. 2; eine Allokation statt drei,
  # Leistung 9.10); alle Betraege sind endlich (N1), nur das Limit darf Inf sein
  sur <- s * (s > 0)
  def <- sur - s
  ext <- rt$zv
  fv <- NULL
  fn <- NULL
  gv <- NULL
  gn <- NULL
  nf <- 0L
  ng <- 0L
  if (collect) {
    fv <- vector("list", 2L * (cc$s$n + cc$d$n))
    fn <- character(length(fv))
    gv <- vector("list", 2L * cc$d$n)
    gn <- character(length(gv))
  }
  # Leistung (9.10): Eine Kette aus direkt gerechneten Aktionen ohne Betrag in allen Laeufen
  # (sur bzw. def ueberall 0) aendert keinen Bestand; ihre Fluesse sind 0 und ihre
  # Markierungen FALSE (ausser der Schwelle des Kontokorrents, die vom Bestand abhaengt)
  ps <- cc$s
  zi <- integer(0)
  skip_s <- isTRUE(ps$all_inline) && ps$n > 0L && isTRUE(max(sur) <= 0)
  if (skip_s && collect) {
    for (q in seq_len(ps$n)) {
      for (k in ps$fkeys[[q]]) {
        nf <- nf + 1L
        fv[[nf]] <- rt$zv
        fn[nf] <- k
        zi <- c(zi, nf)
      }
    }
  }
  for (q in seq_len(if (skip_s) 0L else ps$n)) {
    switch(ps$code[q],
      od_repay = {
        x1 <- pmin.int(sur, kkp)
        kkp <- kkp - x1
        a <- sur - x1
        x2 <- pmin.int(a, kk)
        kk <- kk - x2
        sur <- sur - (x1 + x2)
        if (collect) {
          fv[[nf + 1L]] <- -x1
          fv[[nf + 2L]] <- -x2
          fn[nf + 1:2] <- c("odp_repay", "od_repay")
          nf <- nf + 2L
        }
      },
      dep_fill_reserve = {
        cap <- lmin - dep
        cap <- cap * (cap > 0)
        x <- pmin.int(sur, cap)
        dep <- dep + x
        sur <- sur - x
        if (collect) {
          nf <- nf + 1L
          fv[[nf]] <- -x
          fn[nf] <- "dep_invest"
        }
      },
      dep_invest = {
        dep <- dep + sur
        if (collect) {
          nf <- nf + 1L
          fv[[nf]] <- -sur
          fn[nf] <- "dep_invest"
        }
        sur <- sur - sur
      },
      {
        r <- eng_action_apply(ps$acts[[q]], sur, dep, kk, kkp, t, j, ctx, ist, rt$acc0)
        dep <- r$acc$G
        kk <- r$acc$KK
        kkp <- r$acc$KKP
        if (!is.null(r$inst)) ist <- r$inst
        sur <- sur - r$used
        if (collect) {
          for (i in seq_along(r$flows)) {
            nf <- nf + 1L
            fv[[nf]] <- r$flows[[i]]
            fn[nf] <- names(r$flows)[i]
          }
          for (i in seq_along(r$flags)) {
            ng <- ng + 1L
            gv[[ng]] <- r$flags[[i]]
            gn[ng] <- names(r$flags)[i]
          }
        }
      }
    )
  }
  pd <- cc$d
  skip_d <- isTRUE(pd$all_inline) && pd$n > 0L && isTRUE(max(def) <= 0)
  if (skip_d && collect) {
    ff <- logical(length(def))
    for (q in seq_len(pd$n)) {
      if (skip_external && pd$ext[q]) next
      for (k in pd$fkeys[[q]]) {
        nf <- nf + 1L
        fv[[nf]] <- rt$zv
        fn[nf] <- k
        zi <- c(zi, nf)
      }
      for (k in pd$gkeys[[q]]) {
        ng <- ng + 1L
        gv[[ng]] <- if (identical(k, "overdraft_threshold")) (kk + kkp) > rt$thr else ff
        gn[ng] <- k
      }
    }
  }
  for (q in seq_len(if (skip_d) 0L else pd$n)) {
    if (skip_external && pd$ext[q]) next
    switch(pd$code[q],
      dep_withdraw = {
        cap <- dep - lmin
        cap <- cap * (cap > 0)
        x <- pmin.int(def, cap)
        dep <- dep - x
        def <- def - x
        if (collect) {
          nf <- nf + 1L
          fv[[nf]] <- x
          fn[nf] <- "dep_withdraw"
        }
      },
      od_draw = {
        cap <- kl - kk
        cap <- cap * (cap > 0)
        x <- pmin.int(def, cap)
        kk <- kk + x
        def <- def - x
        if (collect) {
          nf <- nf + 1L
          fv[[nf]] <- x
          fn[nf] <- "od_draw"
          ng <- ng + 1L
          gv[[ng]] <- (kk + kkp) > rt$thr
          gn[ng] <- "overdraft_threshold"
        }
      },
      dep_use_reserve = {
        x <- pmin.int(def, dep)
        dep <- dep - x
        def <- def - x
        if (collect) {
          nf <- nf + 1L
          fv[[nf]] <- x
          fn[nf] <- "dep_withdraw"
          ng <- ng + 1L
          gv[[ng]] <- x > zero
          gn[ng] <- "reserve_used"
        }
      },
      equity_call = {
        ext <- ext + def
        if (collect) {
          nf <- nf + 1L
          fv[[nf]] <- def
          fn[nf] <- "equity_call"
          ng <- ng + 1L
          gv[[ng]] <- def > zero
          gn[ng] <- "shortfall"
        }
        def <- def - def
      },
      penalty_rate = {
        kkp <- kkp + def
        if (collect) {
          nf <- nf + 1L
          fv[[nf]] <- def
          fn[nf] <- "odp_draw"
          hit <- def > zero
          gv[ng + 1:2] <- list(hit, hit)
          gn[ng + 1:2] <- c("shortfall", "limit_breach")
          ng <- ng + 2L
        }
        def <- def - def
      },
      stop = {
        ext <- ext + def
        if (collect) {
          nf <- nf + 1L
          fv[[nf]] <- def
          fn[nf] <- "shortfall"
          hit <- def > zero
          gv[ng + 1:2] <- list(hit, hit)
          gn[ng + 1:2] <- c("shortfall", "stopped")
          ng <- ng + 2L
        }
        def <- def - def
      },
      {
        r <- eng_action_apply(pd$acts[[q]], def, dep, kk, kkp, t, j, ctx, ist, rt$acc0)
        dep <- r$acc$G
        kk <- r$acc$KK
        kkp <- r$acc$KKP
        if (!is.null(r$inst)) ist <- r$inst
        def <- def - r$used
        if (pd$ext[q]) ext <- eng_flow_sum(r$flows, c("equity_call", "shortfall"), ext)
        if (collect) {
          for (i in seq_along(r$flows)) {
            nf <- nf + 1L
            fv[[nf]] <- r$flows[[i]]
            fn[nf] <- names(r$flows)[i]
          }
          for (i in seq_along(r$flags)) {
            ng <- ng + 1L
            gv[[ng]] <- r$flags[[i]]
            gn[ng] <- names(r$flags)[i]
          }
        }
      }
    )
  }
  if (collect) {
    fv <- stats::setNames(fv[seq_len(nf)], fn[seq_len(nf)])
    gv <- stats::setNames(gv[seq_len(ng)], gn[seq_len(ng)])
  }
  list(G = dep, KK = kk, KKP = kkp, ist = ist, rest_sur = sur, rest_def = def, ext = ext,
       flows = fv, flags = gv, fz = if (collect) seq_len(nf) %in% zi else NULL)
}

#' Ist die schnelle Periodenschleife für Wiederholungsläufe anwendbar? (Leistung 9.10, 12.8)
#'
#' Ohne Buchung, mit Instrument-Cache (bzw. ohne Instrumente) und nur mit direkt gerechneten
#' Aktionen an den Stellen, an denen `eng_chain_step()` sie direkt rechnet (Überschusskette:
#' Ü1, Ü2, Ü4; Defizitkette: D1–D4, `penalty_rate`, `stop`).
#' @noRd
eng_fast_loop_ok <- function(cc, book, has_inst, use_cache) {
  !book && (!has_inst || use_cache) && isTRUE(cc$s$all_inline) && isTRUE(cc$d$all_inline) &&
    all(cc$s$icode %in% 1:3) && all(cc$d$icode %in% 4:9)
}

#' Periodenschleife der Wiederholungsläufe ohne Buchung (9.3, 12.8; Leistung 9.10)
#'
#' Dieselben Schritte und Formeln wie `eng_balance()` mit `eng_chain_step(collect = FALSE)`,
#' die Ausgleichsketten direkt in der Schleife (ohne Funktionsaufruf und Rückgabeliste je
#' Periode). Voraussetzung: `eng_fast_loop_ok()`.
#' @param su Vorbereitung (`eng_balance_setup()`).
#' @param cols Spaltenlisten (`eng_balance_cols()`).
#' @param eo zusätzliche Entnahmen n x (T+1) oder `NULL`.
#' @param tx Steuer-Hook: `list(has, module, state, step, slices, params, tin, keys, grid)`.
#' @return `list(dep, kk, kkp, ns_cols, pre_t, ns_t, tst)`.
#' @noRd
eng_balance_fast_loop <- function(su, cols, cc, n, n_t, eo, w, w_zero, has_inst, tx) {
  zero <- vofi_tol$zero_abs
  zv <- su$rt$zv
  acc0 <- su$acc0
  dep <- acc0$G
  kk <- acc0$KK
  kkp <- acc0$KKP
  c_f0 <- cols$F0
  c_h <- cols$h
  c_wa <- cols$wa
  c_s <- cols$s
  c_sp <- cols$sp
  c_kl <- cols$KL
  c_lm <- cols$Lmin
  c_soll <- cols$soll
  c_fees <- cols$fees
  scode <- cc$s$icode
  dcode <- cc$d$icode - 3L
  has_tax <- tx$has
  tst <- tx$state
  ns_cols <- vector("list", n_t)
  soll <- zv
  fees <- zv
  pre_t <- NULL
  ns_t <- NULL
  for (j in seq_len(n_t)) {
    t <- j - 1L
    f <- c_f0[[j]]
    if (!is.null(eo)) f <- f + eo[, j]
    if (has_inst) {
      soll <- c_soll[[j]]
      fees <- c_fees[[j]]
    }
    hz <- dep * c_h[[j]]
    kz <- kk * c_s[[j]]
    kzp <- kkp * c_sp[[j]]
    if (w_zero) {
      wht <- zv
      s <- f + hz - kz - kzp
    } else {
      wht <- hz - c_wa[[j]]
      wht <- w * (wht * (wht > 0))
      s <- f + hz - wht - kz - kzp
    }
    if (has_tax) {
      inputs <- if (is.null(tx$tin)) tx$slices[[j]] else
        tax_slice(tx$tin, j, su$inst_tax[[j]] %||% list(), tx$grid, tx$keys)
      rtx <- tx$step(tx$module, t, inputs = inputs,
                     interest = list(exo_soll = soll, exo_fees = fees, endo_soll = kz + kzp,
                                     endo_haben = hz, endo_wht = wht),
                     state = tst, params = tx$params)
      tst <- rtx$state
      pay <- rtx$payment
      if (length(pay) != n || !is.double(pay) || !is.null(attributes(pay)) ||
            !is.finite(sum(pay))) {
        pay <- eng_tax_num(pay, n, "payment", tx$module)
      }
      s <- s - pay
    }
    if (j == n_t) pre_t <- list(G = dep, KK = kk, KKP = kkp, ist = NULL, s = s)
    klj <- c_kl[[j]]
    excess <- kk - klj
    excess[excess <= 0] <- 0
    kk <- kk - excess
    s <- s - excess
    # Ausgleichsketten wie eng_chain_step() (Formeln 8.9)
    sur <- s * (s > 0)
    def <- sur - s
    ext <- zv
    for (k in scode) {
      switch(k,
        {
          x1 <- pmin.int(sur, kkp)
          kkp <- kkp - x1
          a <- sur - x1
          x2 <- pmin.int(a, kk)
          kk <- kk - x2
          sur <- sur - (x1 + x2)
        },
        {
          cap <- c_lm[[j]] - dep
          cap <- cap * (cap > 0)
          x <- pmin.int(sur, cap)
          dep <- dep + x
          sur <- sur - x
        },
        {
          dep <- dep + sur
          sur <- sur - sur
        }
      )
    }
    for (k in dcode) {
      switch(k,
        {
          cap <- dep - c_lm[[j]]
          cap <- cap * (cap > 0)
          x <- pmin.int(def, cap)
          dep <- dep - x
          def <- def - x
        },
        {
          cap <- klj - kk
          cap <- cap * (cap > 0)
          x <- pmin.int(def, cap)
          kk <- kk + x
          def <- def - x
        },
        {
          x <- pmin.int(def, dep)
          dep <- dep - x
          def <- def - x
        },
        {
          ext <- ext + def
          def <- def - def
        },
        {
          kkp <- kkp + def
          def <- def - def
        },
        {
          ext <- ext + def
          def <- def - def
        }
      )
    }
    mr <- max(sur, def)
    if (is.na(mr) || mr > zero) eng_chain_rest_abort(list(rest_sur = sur, rest_def = def), t)
    if (j == n_t) ns_t <- ext
    ns_cols[[j]] <- ext
  }
  list(dep = dep, kk = kk, kkp = kkp, ns_cols = ns_cols, pre_t = pre_t, ns_t = ns_t, tst = tst)
}

#' Ausgleichsaktion über ihre `apply()`-Funktion (8.9)
#'
#' Kontenzustand = `acc0` (Raten, Limits) mit den aktuellen Beständen und der Spalte `j`; die
#' Aktion schreibt die Bestände `G`, `KK`, `KKP` fort.
#' @noRd
eng_action_apply <- function(a, amount, dep, kk, kkp, t, j, ctx, ist, acc0) {
  acc <- acc0
  acc$G <- dep
  acc$KK <- kk
  acc$KKP <- kkp
  acc$j <- j
  a$apply(acc, amount, t, ctx, ist)
}

#' Ausgleichsketten mit einem Kontenzustand (Schnittstelle der Aktionen, 8.9)
#'
#' Hülle um `eng_chain_step()` für Aufrufer mit einem Kontenzustand `acc` (8.8): rechnet beide
#' Ketten über alle Kettenglieder und gibt den fortgeschriebenen Zustand zurück.
#' @param skip_external D4-Aktionen mit Zufluss von außen (Zeilen `equity_call`, `shortfall`)
#'   nicht ausführen (Sicht ohne Restwert, 9.4 Nr. 2).
#' @param info übersetzte Ketten (`eng_chain_compile()`) oder `NULL` (dann neu übersetzt).
#' @return `list(acc, ist, flows, flags, rest_sur, rest_def, ext)`; `ext` ist die Summe der
#'   Flüsse `equity_call` und `shortfall` (Zufluss von außen NS, n-Vektor).
#' @noRd
eng_apply_chains <- function(surplus, deficit, acc, s, t, j, ctx, ist, skip_external = FALSE,
                             info = NULL) {
  cc <- info %||% eng_chain_compile(surplus, deficit)
  acc$j <- j
  rt <- eng_chain_consts(acc)
  r <- eng_chain_step(cc, acc$G, acc$KK, acc$KKP, s, t, j, ctx, ist, rt, acc$Lmin[, j],
                      acc$KL[, j], collect = TRUE,
                      skip_external = skip_external)
  acc$G <- r$G
  acc$KK <- r$KK
  acc$KKP <- r$KKP
  list(acc = acc, ist = r$ist, flows = r$flows, flags = r$flags, rest_sur = r$rest_sur,
       rest_def = r$rest_def, ext = r$ext)
}

#' Summe gleichnamiger Flüsse aus `eng_chain_step()`
#' @param flows unverdichtete Flussliste.
#' @param keys Zeilenschlüssel.
#' @param zero Nullvektor (n).
#' @noRd
eng_flow_sum <- function(flows, keys, zero) {
  out <- zero
  nm <- names(flows)
  for (i in which(nm %in% keys)) out <- out + flows[[i]]
  out
}

#' Aktion mit Zufluss von außen (D4 `equity_call`, `stop`; 9.4 Nr. 2, 9.5 Nr. 5)
#' @noRd
eng_action_external <- function(a) any(a$rows %in% c("equity_call", "shortfall"))

#' Bestand eines Kredits nach dem Ausgleich (9.3 Schritt 7)
#' @noRd
eng_inst_balance <- function(e, t, ctx, fallback) {
  if (is.function(e$def$capacity)) as.double(e$def$capacity(e$state, t, ctx)$balance) else
    fallback
}

#' Periodenalgorithmus (9.3)
#'
#' @param model `vofi_model` (für die Unterlassungsalternative mit angepassten Ketten und ohne
#'   Instrumente). `model$tax = NULL` rechnet ohne Steuer-Hook (nur Tests, 10.10 Nr. 1); sonst
#'   läuft der Hook in jeder Periode inkl. t0, auch mit `tax_none` (10.1 Nr. 1).
#' @param ctx Laufkontext.
#' @param exo exogener Ledger (`vofi_ledger`).
#' @param extra_out optionale zusätzliche Entnahmen n x (T+1) (<= 0, 12.8); mit `book = TRUE`
#'   als Zeile `extra_equity_out` gebucht.
#' @param book `FALSE`: keine Ledger-Buchung, Rückgabe `list(BS_T, NS, BS_T_ex_rv, RW_T)`.
#' @param engine_env private Engine-Umgebung (Zwischenspeicher, Instrument-Cache).
#' @param setup_key Schlüssel des Zwischenspeichers (`"inv"` Investition, `"opp"` Alternative).
#' @return core (12.1) bzw. bei `book = FALSE` die Kurzform.
#' @noRd
eng_balance <- function(model, ctx, exo, extra_out = NULL, book = TRUE, engine_env = NULL,
                        setup_key = "inv") {
  g <- ctx$grid
  n <- ctx$n
  n_t <- g$T + 1L
  zero <- vofi_tol$zero_abs
  su <- eng_balance_setup(model, ctx, exo, engine_env, setup_key)
  acc0 <- su$acc0
  rt <- su$rt
  cc <- su$chains
  dep <- acc0$G
  kk <- acc0$KK
  kkp <- acc0$KKP
  w <- acc0$w
  # Anteil der Abgeltungsteuer in allen Laeufen 0: keine Abgeltungsteuer (Leistung 9.10);
  # Pruefungen auf Bestaende bzw. Betraege 0 lohnen erst bei vielen Laeufen
  w_zero <- isTRUE(all(w == 0))
  big <- n >= 64L
  # Spaltenzugriff ueber Spaltenlisten (je Kontext einmal gebildet, Leistung 9.10)
  cols <- eng_balance_cols(su, engine_env, setup_key)
  c_f0 <- cols$F0
  c_h <- cols$h
  c_wa <- cols$wa
  c_s <- cols$s
  c_sp <- cols$sp
  c_kl <- cols$KL
  c_lm <- cols$Lmin
  c_soll <- cols$soll
  c_fees <- cols$fees
  insts <- model$instruments
  ids <- names(insts)
  has_inst <- length(ids) > 0L
  use_cache <- su$use_cache
  cache <- su$cache
  tin <- su$tin
  ist <- NULL
  if (has_inst && !use_cache) {
    ist <- lapply(insts, function(k) list(state = k$def$init(k$spec, ctx), def = k$def))
  }
  eo <- NULL
  if (!is.null(extra_out)) {
    eo <- utl_sim_matrix(g, extra_out, "extra_out")
    if (nrow(eo) != n) eo <- eng_sim_rows(eo, n)
    eng_check_finite(list(extra_out = eo), "extra_out")
  }
  tax <- model[["tax"]]
  has_tax <- !is.null(tax)
  tparams <- model$tax_params
  tst <- if (has_tax) su$tax_init(tax, tparams, su$assets, su$measures, n) else NULL
  step_fun <- su$tax_step
  # tax_none (10.6): Zahlung 0 (numeric(n)), Zustand unverändert, kein Bericht; der Aufruf je
  # Periode entfällt, das Ergebnis wird direkt eingesetzt (Leistung 9.10)
  tax_noop <- has_tax && identical(step_fun, tax_step.tax_none)
  slices <- su$tax_slices
  zv <- rt$zv
  # Zufluss von aussen NS je Periode: nur fuer Wiederholungslaeufe (Rueckgabe, 12.8)
  ns_cols <- if (book) NULL else vector("list", n_t)
  fl_names <- eng_loan_flow_names()
  mm_names <- eng_loan_memo_names()
  soll <- zv
  fees <- zv
  inst_rows <- list()
  if (book) {
    # Spalten der Engine-Zeilen (7.7) und Bestaende als Listen (NULL = 0), Matrizen am Ende
    rec_keys <- eng_rec_keys()
    rec_pos <- stats::setNames(seq_along(rec_keys), rec_keys)
    rc <- vector("list", length(rec_keys) * n_t)
    o_tax <- (rec_pos[["tax"]] - 1L) * n_t
    o_hz <- (rec_pos[["dep_interest"]] - 1L) * n_t
    o_wht <- (rec_pos[["dep_wht"]] - 1L) * n_t
    o_kz <- (rec_pos[["od_interest"]] - 1L) * n_t
    o_kzp <- (rec_pos[["odp_interest"]] - 1L) * n_t
    sc <- vector("list", 3L * n_t)
    loan <- if (has_inst && !use_cache) {
      lapply(ids, function(id) {
        stats::setNames(lapply(c(fl_names, mm_names, "balance"), function(x) {
          matrix(0, n, n_t)
        }), c(fl_names, mm_names, "balance"))
      })
    } else {
      list()
    }
    if (length(loan) > 0L) names(loan) <- ids
    reports <- list()
    fl <- list(reserve_used = rep(FALSE, n), shortfall = rep(FALSE, n),
               limit_cut = rep(FALSE, n), overdraft_threshold = rep(FALSE, n),
               stopped = rep(FALSE, n), limit_breach = rep(FALSE, n))
  }
  pre_t <- NULL
  # Wiederholungslaeufe (book = FALSE) mit Cache und eingebauten Aktionen: schnelle Schleife
  fast <- eng_fast_loop_ok(cc, book, has_inst, use_cache)
  if (fast) {
    lp <- eng_balance_fast_loop(
      su, cols, cc, n, n_t, eo, w, w_zero, has_inst,
      list(has = has_tax && !tax_noop, module = tax, state = tst, step = step_fun,
           slices = slices, params = tparams, tin = tin, keys = su$tax_keys, grid = g)
    )
    dep <- lp$dep
    kk <- lp$kk
    kkp <- lp$kkp
    ns_cols <- lp$ns_cols
    pre_t <- lp$pre_t
    ns_t <- lp$ns_t
    tst <- lp$tst
  }
  for (j in seq_len(if (fast) 0L else n_t)) {
    t <- j - 1L
    # (1) exogene Zahlungen (mit Kreditfluessen aus dem Cache)
    f <- c_f0[[j]]
    if (!is.null(eo)) f <- f + eo[, j]
    # (2) Instrumente in financing-Reihenfolge
    bal_now <- NULL
    if (has_inst) {
      if (use_cache) {
        soll <- c_soll[[j]]
        fees <- c_fees[[j]]
        if (!is.null(tin)) inst_rows <- su$inst_tax[[j]]
      } else {
        soll <- zv
        fees <- zv
        inst_rows <- list()
        bal_now <- list()
        for (id in ids) {
          r <- ist[[id]]$def$step(ist[[id]]$state, t, ctx)
          ist[[id]]$state <- r$state
          fls <- lapply(fl_names, function(x) eng_num(r$flows[[x]], n, x, id))
          names(fls) <- fl_names
          mms <- lapply(mm_names, function(x) eng_num(r$memo[[x]], n, x, id))
          names(mms) <- mm_names
          eng_check_finite(c(fls, mms), id)
          f <- f + fls$draw + fls$repay + fls$repay_balloon + fls$prepay + fls$interest +
            fls$fees
          soll <- soll - fls$interest
          fees <- fees - fls$fees
          bal_now[[id]] <- eng_num(r$stocks$balance, n, "balance", id)
          if (book) {
            for (x in fl_names) loan[[id]][[x]][, j] <- fls[[x]]
            for (x in mm_names) loan[[id]][[x]][, j] <- mms[[x]]
          }
          if (!is.null(tin)) inst_rows <- c(inst_rows, eng_inst_tax_rows(id, fls, mms))
        }
      }
    }
    # (3) Kontozinsen auf die Bestaende Ende t-1 (D3), Abgeltungsteuer mit Pauschbetrag.
    # Leistung (9.10): Zinsen auf einen Bestand, der in allen Laeufen 0 ist, und die
    # Abgeltungsteuer bei Anteil 0 sind 0 und entfallen (Werte gleich, nur das Vorzeichen einer
    # Null kann abweichen)
    hz <- dep * c_h[[j]]
    kk_zero <- big && isTRUE(max(kk) == 0 && min(kk) == 0)
    kzp_zero <- big && isTRUE(max(kkp) == 0 && min(kkp) == 0)
    kz <- if (kk_zero) zv else kk * c_s[[j]]
    kzp <- if (kzp_zero) zv else kkp * c_sp[[j]]
    if (w_zero) {
      wht <- zv
      # (4) vorlaeufiger Saldo
      s <- if (kk_zero) {
        if (kzp_zero) f + hz else f + hz - kzp
      } else {
        if (kzp_zero) f + hz - kz else f + hz - kz - kzp
      }
    } else {
      wht <- hz - c_wa[[j]]
      wht <- w * (wht * (wht > 0))
      s <- f + hz - wht - kz - kzp
    }
    # (5) Steuer-Hook (jede Periode, R-21)
    if (has_tax) {
      rtx <- if (tax_noop) {
        list(payment = numeric(n), state = tst, report = list())
      } else {
        inputs <- if (is.null(tin)) slices[[j]] else tax_slice(tin, j, inst_rows, g, su$tax_keys)
        endo_soll <- if (kzp_zero) kz else if (kk_zero) kzp else kz + kzp
        step_fun(tax, t, inputs = inputs,
                 interest = list(exo_soll = soll, exo_fees = fees, endo_soll = endo_soll,
                                 endo_haben = hz, endo_wht = wht),
                 state = tst, params = tparams)
      }
      tst <- rtx$state
      pay <- rtx$payment
      if (length(pay) != n || !is.double(pay) || !is.null(attributes(pay)) ||
            !is.finite(sum(pay))) {
        pay <- eng_tax_num(pay, n, "payment", tax)
      }
      pay_zero <- big && max(pay) == 0 && min(pay) == 0
      if (!pay_zero) s <- s - pay
      if (book) {
        if (!pay_zero) rc[[o_tax + j]] <- -pay
        reports <- eng_report_add(reports, rtx$report, j, n, n_t, module = tax)
      }
    }
    if (j == n_t) pre_t <- list(G = dep, KK = kk, KKP = kkp, ist = ist, s = s)
    # (6a) Ueberhang bei sinkendem Limit: Zwangstilgung, zusaetzliches Defizit (8.8); ohne
    # Ueberhang (max KK <= min KL) ist excess = 0 und entfaellt
    klj <- c_kl[[j]]
    excess <- NULL
    if (!big || !isTRUE(max(kk) <= min(klj))) {
      excess <- kk - klj
      excess[excess <= 0] <- 0
      kk <- kk - excess
      s <- s - excess
    }
    # (6) Ausgleichsketten
    ch <- eng_chain_step(cc, dep, kk, kkp, s, t, j, ctx, ist, rt, c_lm[[j]], klj,
                         collect = book)
    dep <- ch$G
    kk <- ch$KK
    kkp <- ch$KKP
    ist <- ch$ist
    # Pruefung ueber alle Laeufe (2.8 Nr. 3): nach den Ketten bleibt kein Saldo
    mr <- max(ch$rest_sur, ch$rest_def)
    if (is.na(mr) || mr > zero) eng_chain_rest_abort(ch, t)
    if (j == n_t) ns_t <- ch$ext
    if (!book) {
      ns_cols[[j]] <- ch$ext
      next
    }
    if (!is.null(excess)) fl$limit_cut <- fl$limit_cut | (excess > zero)
    # Fluesse der Periode je Zeile summieren (Reihenfolge der Ketten), dann einmal buchen;
    # Fluesse uebersprungener Ketten (ch$fz, ueberall 0) entfallen
    fv <- ch$flows
    fk <- names(fv)
    fz <- ch$fz %||% logical(length(fv))
    pv <- list()
    for (i in seq_along(fk)) {
      if (fz[i]) next
      k <- fk[i]
      pv[[k]] <- if (is.null(pv[[k]])) fv[[i]] else pv[[k]] + fv[[i]]
    }
    if (!is.null(excess)) {
      pv[["od_repay"]] <- if (is.null(pv[["od_repay"]])) -excess else pv[["od_repay"]] - excess
    }
    pk <- names(pv)
    pos <- rec_pos[pk]
    for (i in seq_along(pk)) {
      if (!is.na(pos[i])) {
        rc[[(pos[i] - 1L) * n_t + j]] <- pv[[i]]
        next
      }
      k <- pk[i]
      id <- if (grepl("^loan_.+_prepay$", k)) sub("^loan_(.*)_prepay$", "\\1", k) else ""
      if (!(id %in% ids) || use_cache) {
        vofi_abort("engine.flow_key_unknown", row = k, .class = "vofi_error_contract")
      }
      # Ue3 ergaenzt die geplanten Sondertilgungen aus step() in derselben Zeile (7.4)
      loan[[id]]$prepay[, j] <- loan[[id]]$prepay[, j] + pv[[i]]
    }
    gk <- names(ch$flags)
    for (i in which(gk %in% names(fl))) {
      if (!isFALSE(any(ch$flags[[i]]))) fl[[gk[i]]] <- fl[[gk[i]]] | ch$flags[[i]]
    }
    # (7) Zinsen und Bestaende (entfallene Zinsen: Spalte 0)
    rc[[o_hz + j]] <- hz
    if (!w_zero) rc[[o_wht + j]] <- -wht
    if (!kk_zero) rc[[o_kz + j]] <- -kz
    if (!kzp_zero) rc[[o_kzp + j]] <- -kzp
    sc[[j]] <- dep
    sc[[n_t + j]] <- kk
    sc[[2L * n_t + j]] <- kkp
    if (has_inst && !use_cache) {
      for (id in ids) loan[[id]]$balance[, j] <- eng_inst_balance(ist[[id]], t, ctx, bal_now[[id]])
    }
  }
  b_t <- if (!has_inst) {
    zv
  } else if (use_cache) {
    su$totals$bal[, n_t]
  } else {
    Reduce(`+`, lapply(ids, function(id) {
      eng_inst_balance(ist[[id]], g$T, ctx, rep(0, n))
    }), zv)
  }
  fin <- if (has_tax) {
    su$tax_finalize(tax, g$T, tst, su$terminal_inputs, tparams)
  } else {
    NULL
  }
  tax_t <- if (has_tax) eng_tax_num(fin$payment_T, n, "payment_T", tax) else zv
  bs_t <- dep - kk - kkp - b_t - tax_t
  term <- eng_terminal_ex_rv(su, ctx, pre_t, ns_t, tax_t, ids, b_t)
  if (!book) {
    return(list(BS_T = bs_t, NS = eng_cols_matrix(ns_cols, n), BS_T_ex_rv = term$BS,
                RW_T = su$rw_t))
  }
  if (has_tax) reports <- eng_report_add(reports, fin$report, n_t, n, n_t, add = TRUE,
                                         module = tax)
  # Engine-Zeilen und Bestaende als Matrizen; nie gebuchte Zeilen teilen eine Nullmatrix
  rec <- vector("list", length(rec_keys))
  names(rec) <- rec_keys
  rec_zero <- logical(length(rec_keys))
  z_mat <- NULL
  idx <- seq_len(n_t)
  for (q in seq_along(rec_keys)) {
    v <- rc[idx]
    if (all(lengths(v) == 0L)) {
      if (is.null(z_mat)) z_mat <- matrix(0, n, n_t)
      rec[[q]] <- z_mat
      rec_zero[q] <- TRUE
    } else {
      rec[[q]] <- eng_cols_matrix(v, n)
    }
    idx <- idx + n_t
  }
  attr(rec, "zero") <- rec_zero
  st_g <- eng_cols_matrix(sc[seq_len(n_t)], n)
  st_kk <- eng_cols_matrix(sc[n_t + seq_len(n_t)], n)
  st_kkp <- eng_cols_matrix(sc[2L * n_t + seq_len(n_t)], n)
  loan_values <- if (use_cache) {
    lapply(cache, function(cc) c(cc$flows, cc$memo, list(balance = cc$balance)))
  } else {
    loan
  }
  neg_amort <- rep(FALSE, n)
  for (id in ids) {
    na <- if (use_cache) cache[[id]]$neg_amort else ist[[id]]$state$neg_amort
    neg_amort <- neg_amort | (na %||% FALSE)
  }
  acc <- acc0
  acc$G <- dep
  acc$KK <- kk
  acc$KKP <- kkp
  eng_assemble_core(model, ctx, su, rec, loan_values, st_g, st_kk, st_kkp, tax_t, term, fl,
                    acc, reports, eo, neg_amort, engine_env)
}

#' Zeilen einer Matrix auf n Läufe heben (eine Zeile wird wiederholt)
#' @noRd
eng_sim_rows <- function(m, n) {
  if (nrow(m) != 1L) {
    vofi_abort("core.contract.length", what = "extra_out", expected = n, actual = nrow(m),
               .class = "vofi_error_contract")
  }
  m[rep(1L, n), , drop = FALSE]
}

#' Rest nach den Ausgleichsketten melden (Kette ohne unbegrenzte Aktion bzw. nicht endlich)
#' @noRd
eng_chain_rest_abort <- function(ch, t) {
  rest <- pmax.int(ch$rest_sur, ch$rest_def)
  if (anyNA(rest)) {
    vofi_abort("engine.chain_not_finite", t = t, .class = "vofi_error_contract",
               .data = list(invariant = "N1", t = t, sim = which(is.na(rest))[1L]))
  }
  vofi_abort("engine.chain_rest", t = t, value = max(rest), .class = "vofi_error_engine",
             .data = list(invariant = "chain", t = t, sim = which.max(rest)))
}

#' Engine-Zeilen der Periodenschleife (7.7, ohne Prüf- und Bestandszeilen)
#' @noRd
eng_rec_keys <- function() {
  c("equity_call", "shortfall", "od_draw", "od_repay", "od_interest", "odp_draw", "odp_repay",
    "odp_interest", "dep_invest", "dep_withdraw", "dep_interest", "dep_wht", "tax")
}

#' Berichtsgrößen des Steuermoduls je Periode sammeln (10.5)
#' @param add `TRUE`: Werte zur Spalte addieren (Bericht aus `tax_finalize()` in T+1).
#' @param module Steuermodul (Quelle der Meldung bei ungültigen Werten) oder `NULL`.
#' @noRd
eng_report_add <- function(reports, report, j, n, n_t, add = FALSE, module = NULL) {
  for (nm in names(report %||% list())) {
    if (is.null(reports[[nm]])) reports[[nm]] <- matrix(0, n, n_t)
    v <- if (is.null(module)) eng_num(report[[nm]], n, nm) else
      eng_tax_num(report[[nm]], n, paste0("report$", nm), module)
    reports[[nm]][, j] <- if (add) reports[[nm]][, j] + v else v
  }
  reports
}

#' Terminalzustand ohne Restwert (9.4, R-61)
#'
#' Wiederholt (6a) und (6) der Periode T ab pre_T mit S' = S_T - RW_T + NS_T; D4-Aktionen mit
#' Zufluss von außen werden nicht ausgeführt, der Rest geht unbegrenzt in die Strafzinstranche
#' (ohne Zinswirkung, T ist der Horizont). Die Steuerzahlung von T bleibt unverändert.
#' @param su Vorbereitung (`eng_balance_setup()`).
#' @param pre Zustand vor (6a) in T: `list(G, KK, KKP, ist, s)`.
#' @return `list(G, KK, KKP, B_total, BS, rv, gap)` (n-Vektoren).
#' @noRd
eng_terminal_ex_rv <- function(su, ctx, pre, ns_t, tax_t, ids, b_t) {
  g <- ctx$grid
  n_t <- g$T + 1L
  rw_t <- su$rw_t
  s <- pre$s - rw_t + ns_t
  kk <- pre$KK
  kl_t <- su$acc0$KL[, n_t]
  excess <- kk - kl_t
  excess[excess <= 0] <- 0
  kk <- kk - excess
  s <- s - excess
  ch <- eng_chain_step(su$chains, pre$G, kk, pre$KKP, s, g$T, n_t, ctx, pre$ist, su$rt,
                       su$acc0$Lmin[, n_t], kl_t, skip_external = TRUE)
  gap <- ch$rest_def
  kkp <- ch$KKP + gap
  b_total <- if (su$use_cache || length(ids) == 0L) {
    b_t
  } else {
    Reduce(`+`, lapply(ids, function(id) {
      eng_inst_balance(ch$ist[[id]], g$T, ctx, rep(0, length(s)))
    }), rep(0, length(s)))
  }
  list(G = ch$G, KK = ch$KK, KKP = kkp, B_total = b_total,
       BS = ch$G - ch$KK - kkp - b_total - tax_t, rv = rw_t, gap = gap)
}

#' Ledger, Bestände, Markierungen zu core zusammensetzen (9.3, 12.1)
#'
#' Die Sacheinlage `equity_in_kind` (R-68) gehört nur zur Investition; die
#' Unterlassungsalternative (`model$alternative == "opportunity"`) erhält stattdessen die
#' exogene Zeile `opp_in_kind_sale` (9.5 Nr. 7). Der Ledger entsteht über `eng_new_ledger()`;
#' N1 prüft `eng_checks()` (immer aktiv, 9.7) in einem Durchlauf.
#' @noRd
eng_assemble_core <- function(model, ctx, su, rec, loan_values, st_g, st_kk, st_kkp, tax_t,
                              term, fl, acc, reports, eo, neg_amort, engine_env = NULL) {
  g <- ctx$grid
  n <- ctx$n
  n_t <- g$T + 1L
  zero <- vofi_tol$zero_abs
  exo <- su$exo
  rm <- su$rows_meta
  ids <- names(model$instruments)
  values <- exo$values
  cats <- c(eng_loan_flow_names(), eng_loan_memo_names())
  for (id in ids) {
    lv <- loan_values[[id]]
    for (cc in cats) values[[paste0("loan_", id, "_", cc)]] <- lv[[cc]]
  }
  # Finanzierungssaldo: exogene Zahlungen und Kreditfluesse (Cache: Summe vorab) plus
  # Engine-Zeilen; nie gebuchte Engine-Zeilen (Nullmatrix) aendern die Summe nicht
  # Summanden in der Reihenfolge der schrittweisen Rechnung, eine Allokation (eng_fold_sum())
  bc_terms <- list(su$F0)
  if (!su$use_cache) {
    for (id in ids) {
      bc_terms <- c(bc_terms, loan_values[[id]][c("draw", "repay", "repay_balloon", "prepay",
                                                  "interest", "fees")])
    }
  }
  rec_zero <- attr(rec, "zero") %||% logical(length(rec))
  attr(rec, "zero") <- NULL
  for (q in seq_along(rec)) {
    k <- names(rec)[q]
    values[[k]] <- rec[[q]]
    if (!rec_zero[q]) bc_terms[[length(bc_terms) + 1L]] <- rec[[q]]
  }
  parts <- list(exo$rows, rm$loans, rm$engine)
  if (!is.null(eo)) {
    values$extra_equity_out <- eo
    bc_terms[[length(bc_terms) + 1L]] <- eo
    parts[[length(parts) + 1L]] <- new_ledger_rows(
      "extra_equity_out", "equity", "equity_out", local_row = "extra_equity_out",
      label_key = "core.rows.extra_equity_out", label = lbl("core.rows.extra_equity_out")
    )
  }
  ev <- if (identical(model$alternative, "opportunity")) NULL else
    ctx$value_base("building.existing_value_eur", "scalar")
  if (!is.null(ev)) {
    assumed0 <- rep(0, n)
    for (id in ids) assumed0 <- assumed0 + loan_values[[id]]$assumed[, 1L]
    eik <- matrix(0, n, n_t)
    eik[, 1L] <- ev - assumed0
    values$equity_in_kind <- eik
    parts[[length(parts) + 1L]] <- new_ledger_rows(
      "equity_in_kind", "equity", "equity_in_kind", local_row = "equity_in_kind",
      label_key = "core.rows.equity_in_kind", label = lbl("core.rows.equity_in_kind")
    )
  }
  if (length(reports) > 0L) {
    parts[[length(parts) + 1L]] <- eng_tax_report_rows(model$tax, names(reports))
    for (nm in names(reports)) values[[paste0("tax_report_", nm)]] <- reports[[nm]]
  }
  bc <- eng_fold_sum(bc_terms)
  values$balance_check <- bc
  parts <- c(parts, list(rm$check, rm$stocks))
  b_total <- if (su$use_cache && length(ids) > 0L) su$totals$bal else matrix(0, n, n_t)
  for (id in ids) {
    values[[paste0("loan_", id, "_balance")]] <- loan_values[[id]]$balance
    if (!su$use_cache) b_total <- b_total + loan_values[[id]]$balance
  }
  tax_liab <- matrix(0, n, n_t)
  tax_liab[, n_t] <- tax_t
  # ohne Kredite ist b_total = 0 und x - 0 = x (auch fuer -0): Subtraktion entfaellt
  bs <- if (length(ids) > 0L) st_g - st_kk - st_kkp - b_total else st_g - st_kk - st_kkp
  bs[, n_t] <- bs[, n_t] - tax_t
  values$od_balance <- st_kk
  values$odp_balance <- st_kkp
  values$dep_balance <- st_g
  values$tax_liability <- tax_liab
  values$net_position <- bs
  # Zeilenmetadaten: nur von den Teilen abhaengig (Zwischenspeicher ueber Laeufe hinweg)
  meta <- eng_memo("core_rows", list(parts), function() {
    mt <- eng_bind_rows(parts)
    if (anyDuplicated(mt$key)) {
      vofi_abort("engine.key_collision", row = mt$key[duplicated(mt$key)][1L],
                 .class = "vofi_error_engine")
    }
    mt <- mt[order(mt$order, method = "radix"), , drop = FALSE]
    rownames(mt) <- NULL
    mt
  }, size = 16L)
  ledger <- eng_new_ledger(meta, values[meta$key], n = n, big_t = g$T)
  call_sum <- eng_fold_sum(list(rec$equity_call, rec$shortfall, rec$odp_draw))
  # Markierungen je Lauf: ist kein Element über der Schwelle (Maximum, ohne Matrixvergleich),
  # ist auch keine Zeilensumme der Vergleichsmatrix positiv (Leistung 9.10)
  no_rows <- rep(FALSE, n)
  hit <- if (isTRUE(max(call_sum) <= zero)) no_rows else rowSums(call_sum > zero) > 0
  first_t <- rep(NA_integer_, n)
  if (any(hit)) {
    first_t[hit] <- max.col((call_sum[hit, , drop = FALSE] > zero) * 1,
                            ties.method = "first") - 1L
  }
  kkp_hit <- if (isTRUE(max(st_kkp) <= zero)) no_rows else rowSums(st_kkp > zero) > 0
  thr <- acc$flag_threshold
  thr_hit <- if (isTRUE(all(thr == Inf))) {
    no_rows
  } else {
    rowSums((st_kk + st_kkp) > thr) > 0
  }
  per <- g$months > 0L
  flags <- eng_df(list(
    reserve_used = fl$reserve_used, shortfall = fl$shortfall | hit,
    shortfall_sum = rowSums(call_sum), first_shortfall_t = as.integer(first_t),
    limit_breach = fl$limit_breach | kkp_hit, limit_cut = fl$limit_cut,
    opp_limit_breach = rep(FALSE, n), ex_rv_gap = term$gap,
    overdraft_threshold = fl$overdraft_threshold | thr_hit,
    stopped = fl$stopped, negative_amortization = neg_amort,
    equity_call_over_savings = eng_flag_savings(ctx, rec$equity_call),
    arbitrage = eng_env_memo(engine_env, "arbitrage", list(acc$h_pa, acc$s_pa), function() {
      rowSums(acc$h_pa[, per, drop = FALSE] > acc$s_pa[, per, drop = FALSE]) > 0
    })
  ), n)
  # Raten der Konten: Investition und Unterlassungsalternative teilen h, w und L_min
  h_net <- eng_env_memo(engine_env, "h_net", list(acc$h, acc$w), function() {
    acc$h - acc$w * pmax(acc$h, 0)
  })
  lmin_zero <- eng_env_memo(engine_env, "lmin_zero", list(acc$Lmin), function() {
    all(acc$Lmin == 0)
  })
  list(
    ledger = ledger,
    stocks = list(G = st_g, KK = st_kk, KKP = st_kkp,
                  B = lapply(loan_values, function(l) l$balance), BS = bs,
                  tax_liability = tax_liab),
    terminal_ex_rv = term, flags = flags,
    rates = list(h = acc$h, h_net = h_net, s = acc$s, sp = acc$sp),
    grid = g, n = n, opp = NULL, view = "with_rv",
    limits = list(KL = acc$KL, lmin_zero = lmin_zero)
  )
}

#' Zwischenspeicher eines Werts je Kontext mit Prüfung der Eingaben (Leistung 9.10)
#'
#' Gibt den gespeicherten Wert zurück, wenn `deps` identisch zu den Eingaben der Speicherung ist
#' (Zeigergleichheit ist der schnelle Fall), sonst `fun()` (und speichert das Ergebnis).
#' @param engine_env private Engine-Umgebung oder `NULL` (dann immer `fun()`).
#' @param key Name des Eintrags.
#' @param deps Liste der Eingaben.
#' @param fun Funktion ohne Argumente.
#' @noRd
eng_env_memo <- function(engine_env, key, deps, fun) {
  if (!is.environment(engine_env)) return(fun())
  hit <- engine_env$memo[[key]]
  if (!is.null(hit) && identical(hit$deps, deps)) return(hit$value)
  v <- fun()
  engine_env$memo[[key]] <- list(deps = deps, value = v)
  v
}

#' Markierung equity_call_over_savings (9.8): Nachschuss eines Betriebsjahres über 12 x
#' Sparfähigkeit
#' @noRd
eng_flag_savings <- function(ctx, calls) {
  n <- ctx$n
  sav <- ctx$value("household.savings_capacity_month_eur", "scalar")
  if (is.null(sav)) return(rep(FALSE, n))
  g <- ctx$grid
  out <- rep(FALSE, n)
  for (y in unique(g$op_year[g$op_year > 0L])) {
    cols <- which(g$op_year == y)
    out <- out | (rowSums(calls[, cols, drop = FALSE]) > 12 * sav + vofi_tol$zero_abs)
  }
  out
}
