# Laufzeit-Invarianten (WS-D, Spec 00 Abschnitt 9.7) und Meldungen der Markierungen (9.8).
# I1, I2, I3a-c, N1, N2 je Lauf und Periode (Investition und Unterlassungsalternative); bei
# Verstoss vofi_error_engine mit invariant, sim, t, value und den fuenf betragsgroessten Zeilen
# (N1: vofi_error_contract mit der Zeile als Quelle).
# Je Markierungsart hoechstens eine zusammengefasste Bedingung je Lauf mit Anteil der Laeufe.

#' Invarianten pruefen (9.7)
#'
#' N1 (keine `NA`/`NaN`/`Inf`) wird zuerst geprüft; ein Verstoß ist `vofi_error_contract` mit
#' der Zeile als Quelle. Ohne Abbruch (`stop_on_error = FALSE`) gehen nicht endliche Werte nicht
#' in die übrigen Abweichungen ein.
#'
#' Leistung (9.10): Jede zahlungswirksame Zeile wird genau einmal gelesen (Summe der Zeilen ohne
#' Tilgung für I2, Summe der Tilgungszeilen; beide prüfen zugleich N1), jede übrige Zeile über
#' eine Summe. I1, I2 und N2 werden zuerst mit dem Volumen 1 geprüft (Toleranz
#' `balance_rel * max(1, Volumen)` ist mindestens `balance_rel`); nur wenn eine dieser
#' Abweichungen die Toleranz überschreitet, wird das Volumen (2.13) berechnet und die Prüfung
#' exakt wiederholt. `max_dev` ist daher für I1, I2 und N2 die relative Abweichung bzw., solange
#' die Prüfung ohne Volumen besteht, ihre obere Schranke (die absolute Abweichung).
#' @param core core aus `eng_balance()` (Investition oder Unterlassungsalternative).
#' @param stop_on_error bei Verstoß `vofi_error_engine` bzw. `vofi_error_contract` (N1)
#'   signalisieren.
#' @return Data Frame `invariant`, `max_dev`, `tol`, `ok`.
#' @noRd
eng_checks <- function(core, stop_on_error = TRUE) {
  led <- core$ledger
  tol <- vofi_tol
  rows <- led$rows
  v <- led$values
  n <- led$n
  n_t <- led$T + 1L
  z <- matrix(0, n, n_t)
  bal_secs <- c("project", "grants", "equity", "loans", "overdraft", "deposit", "tax")
  cash <- rows$cash & rows$section %in% bal_secs
  ck <- rows$key[cash]
  nonp <- rows$tax_category[cash] != "principal"
  # ein Durchlauf: zahlungswirksame Zeilen ohne Tilgung (I2) und Tilgungszeilen (nur N1)
  flow <- z
  pflow <- z
  for (i in seq_along(ck)) {
    if (nonp[i]) flow <- flow + v[[ck[i]]] else pflow <- pflow + v[[ck[i]]]
  }
  # N1: zahlungswirksame Zeilen ueber die beiden Summen, die uebrigen je Zeile
  other <- setdiff(names(v), ck)
  n1_ok <- is.finite(sum(flow)) && is.finite(sum(pflow)) &&
    all(vapply(other, function(k) is.finite(sum(v[[k]])), logical(1)))
  bad_row <- NULL
  if (!n1_ok) {
    for (k in names(v)) {
      if (!all(is.finite(v[[k]]))) {
        bad_row <- k
        break
      }
    }
  }
  if (stop_on_error && !is.null(bad_row)) {
    vofi_abort("core.contract.row_not_finite", row = bad_row, .class = "vofi_error_contract",
               .data = list(invariant = "N1", row = bad_row))
  }
  n1 <- is.null(bad_row)
  for (k in rows$key[rows$category == "repayment_grant"]) flow <- flow + v[[k]]
  for (k in rows$key[rows$category %in% c("disagio", "assumed")]) flow <- flow - v[[k]]
  # Volumen zunaechst 1 (untere Schranke), exakt nur bei Bedarf (siehe oben)
  vol <- rep(1, n)
  volume <- function() {
    abs_sum <- z
    for (k in ck) abs_sum <- abs_sum + abs(v[[k]])
    pmax.int(1, eng_rowmax(abs_sum))
  }
  bs <- v$net_position
  tl <- v$tax_liability
  lag1 <- function(m) cbind(0, m[, -n_t, drop = FALSE])
  # der n-Vektor laeuft spaltenweise mit: Element [i, j] wird durch vol[i] geteilt
  dev <- list(
    I1 = function() abs(v$balance_check) / vol,
    I2 = function() abs(bs - lag1(bs) - (flow - (tl - lag1(tl)))) / vol,
    I3a = function() {
      if (length(stock_keys) > 0L) -eng_pmin_mat(v[stock_keys]) else z
    },
    I3b = function() if (isTRUE(core$limits$lmin_zero)) eng_pmin_mat(list(g, kk)) else z,
    I3c = function() if (!is.null(core$limits$KL)) v$od_balance - core$limits$KL else z,
    N2 = function() {
      te <- core$terminal_ex_rv
      matrix(abs(te$BS - (bs[, n_t] - te$rv)) / vol, n, 1L)
    }
  )
  stock_keys <- rows$key[rows$section == "stocks" & rows$category == "balance"]
  g <- v$dep_balance
  kk <- v$od_balance + v$odp_balance
  mx <- function(m) max(m, 0, na.rm = TRUE)
  rel <- c(I1 = mx(dev$I1()), I2 = mx(dev$I2()), N2 = mx(dev$N2()))
  if (any(rel > tol$balance_rel)) {
    vol <- volume()
    rel <- c(I1 = mx(dev$I1()), I2 = mx(dev$I2()), N2 = mx(dev$N2()))
  }
  i3a <- if (length(stock_keys) > 0L) {
    mx(-vapply(v[stock_keys], function(m) min(m, na.rm = TRUE), double(1)))
  } else {
    0
  }
  out <- data.frame(
    invariant = c("I1", "I2", "I3a", "I3b", "I3c", "N1", "N2"),
    max_dev = c(rel[["I1"]], rel[["I2"]], i3a, mx(dev$I3b()), mx(dev$I3c()),
                if (n1) 0 else Inf, rel[["N2"]]),
    tol = c(tol$balance_rel, tol$balance_rel, tol$stock_abs, tol$stock_abs, tol$stock_abs, 0,
            tol$balance_rel),
    stringsAsFactors = FALSE
  )
  out$ok <- out$max_dev <= out$tol
  if (stop_on_error && !all(out$ok)) {
    bad <- out$invariant[!out$ok][1L]
    m <- dev[[bad]]()
    pos <- which(m == max(m, na.rm = TRUE), arr.ind = TRUE)[1L, ]
    sim <- as.integer(pos[1L])
    t <- if (identical(bad, "N2")) led$T else as.integer(pos[2L] - 1L)
    j <- t + 1L
    contrib <- vapply(ck, function(k) v[[k]][sim, j], double(1))
    top <- utils::head(contrib[order(-abs(contrib))], 5L)
    vofi_abort("engine.invariant", invariant = bad, sim = sim, t = t, value = max(m),
               rows = utl_collapse(paste0(names(top), " = ", fmt_num(top))),
               .class = "vofi_error_engine",
               .data = list(invariant = bad, sim = sim, t = t, value = max(m), rows = top))
  }
  out
}

#' Zeilenmaximum einer Matrix (vektorisiert über Spalten)
#' @noRd
eng_rowmax <- function(m) {
  out <- m[, 1L]
  for (j in seq_len(ncol(m))[-1L]) out <- pmax.int(out, m[, j])
  out
}

#' Elementweises Minimum gleich großer Matrizen (Dimensionen bleiben erhalten)
#' @param ms Liste von Matrizen (mindestens eine).
#' @noRd
eng_pmin_mat <- function(ms) {
  out <- ms[[1L]]
  for (m in ms[-1L]) out[] <- pmin.int(out, m)
  out
}

#' Zusammengefasste Meldungen der Markierungen (9.8, 8.8, 2.9)
#'
#' Je Markierungsart höchstens eine Bedingung je Lauf (Anteil der Läufe): `vofi_warning_engine`
#' für `arbitrage` (h > s, 8.8), `stopped` (Fehlbetrag bei `stop`, 2.9), `negative_amortization`
#' (`keep_payment` mit Rate <= Zins, 2.9) und `limit_breach` (Strafzinstranche);
#' `vofi_warning_plausibility` für `opp_limit_breach` (Unterlassungsalternative überzieht, 9.5
#' Nr. 5); `vofi_inform()` für die übrigen logischen Markierungen. Aufruf einmal je Lauf
#' (`vofi_run()`, `vofi_sim()`, `vofi_mc()` über alle Chunks), nicht je Chunk.
#' @param flags Data Frame der Markierungen (n Zeilen).
#' @return `invisible(Namen der gemeldeten Markierungen)`.
#' @noRd
eng_flag_conditions <- function(flags) {
  warn <- c("arbitrage", "stopped", "negative_amortization", "limit_breach")
  plaus <- "opp_limit_breach"
  info <- c("shortfall", "reserve_used", "limit_cut", "overdraft_threshold",
            "equity_call_over_savings")
  hit <- character(0)
  for (f in intersect(c(warn, plaus, info), names(flags))) {
    x <- flags[[f]]
    if (!is.logical(x) || !any(x, na.rm = TRUE)) next
    share <- mean(x, na.rm = TRUE)
    if (f %in% warn) {
      vofi_warn(paste0("engine.flags.", f), share = share, .class = "vofi_warning_engine")
    } else if (f %in% plaus) {
      vofi_warn("engine.opp_limit_breach", share = share, .class = "vofi_warning_plausibility")
    } else {
      vofi_inform(paste0("engine.flags.", f), share = share)
    }
    hit <- c(hit, f)
  }
  invisible(hit)
}
