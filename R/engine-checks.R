# Laufzeit-Invarianten (WS-D, Spec 00 Abschnitt 9.7).
# Phase-0-Minimalfassung, Eigentuemer: WS-D. I1, I2, I3a-c, N1, N2 je Lauf und Periode; bei
# Verstoss vofi_error_engine mit invariant, sim, t, value und den fuenf betragsgroessten Zeilen.

#' Invarianten pruefen (9.7)
#'
#' Phase-0-Minimalfassung, Eigentümer: WS-D.
#' @param core core aus [eng_balance()].
#' @param stop_on_error bei Verstoß `vofi_error_engine` signalisieren.
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
  pick <- function(sel) if (any(sel)) Reduce(`+`, v[rows$key[sel]]) else z
  bal_secs <- c("project", "grants", "equity", "loans", "overdraft", "deposit", "tax")
  cash <- rows$cash & rows$section %in% bal_secs
  abs_sum <- pick(cash & FALSE)
  for (k in rows$key[cash]) abs_sum <- abs_sum + abs(v[[k]])
  vol <- pmax(1, eng_rowmax(abs_sum))
  rel <- function(m) abs(m) / matrix(vol, n, ncol(m))
  i1 <- rel(v$balance_check)
  bs <- v$net_position
  d_bs <- bs - cbind(0, bs[, -n_t, drop = FALSE])
  tl <- v$tax_liability
  flow <- pick(cash & rows$tax_category != "principal") + pick(rows$category == "repayment_grant") -
    pick(rows$category == "disagio") - pick(rows$category == "assumed") -
    (tl - cbind(0, tl[, -n_t, drop = FALSE]))
  i2 <- rel(d_bs - flow)
  stock_keys <- rows$key[rows$section == "stocks" & rows$category == "balance"]
  i3a <- if (length(stock_keys) > 0L) -Reduce(pmin, v[stock_keys]) else z
  g <- v$dep_balance
  kk <- v$od_balance + v$odp_balance
  i3b <- if (isTRUE(core$limits$lmin_zero)) pmin(g, kk) else z
  i3c <- if (!is.null(core$limits$KL)) v$od_balance - core$limits$KL else z
  te <- core$terminal_ex_rv
  n2 <- matrix(abs(te$BS - (bs[, n_t] - te$rv)) / vol, n, 1L)
  n1 <- all(vapply(v, function(m) is.finite(sum(m)) || all(is.finite(m)), logical(1)))
  out <- data.frame(
    invariant = c("I1", "I2", "I3a", "I3b", "I3c", "N1", "N2"),
    max_dev = c(max(i1, 0), max(i2, 0), max(i3a, 0), max(i3b, 0), max(i3c, 0),
                if (n1) 0 else Inf, max(n2, 0)),
    tol = c(tol$balance_rel, tol$balance_rel, tol$stock_abs, tol$stock_abs, tol$stock_abs, 0,
            tol$balance_rel),
    stringsAsFactors = FALSE
  )
  out$ok <- out$max_dev <= out$tol
  if (stop_on_error && !all(out$ok)) {
    bad <- out$invariant[!out$ok][1L]
    m <- switch(bad, I1 = i1, I2 = i2, I3a = i3a, I3b = i3b, I3c = i3c, N2 = n2, z)
    pos <- which(m == max(m), arr.ind = TRUE)[1L, ]
    sim <- as.integer(pos[1L])
    t <- if (identical(bad, "N2")) led$T else as.integer(pos[2L] - 1L)
    j <- t + 1L
    contrib <- vapply(rows$key[cash], function(k) v[[k]][sim, j], double(1))
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
  for (j in seq_len(ncol(m))[-1L]) out <- pmax(out, m[, j])
  out
}

#' Zusammengefasste Meldungen der Markierungen (9.8, 8.8, 2.9)
#'
#' Je Markierungsart höchstens eine Bedingung je Lauf (Anteil der Läufe): `vofi_warning_engine`
#' für `arbitrage` (h > s, 8.8), `stopped` (Fehlbetrag bei `stop`, 2.9), `negative_amortization`
#' (`keep_payment` mit Rate <= Zins, 2.9) und `limit_breach` (Strafzinstranche); `vofi_inform()`
#' für die übrigen logischen Markierungen. `opp_limit_breach` meldet die Unterlassungsalternative
#' selbst (9.5 Nr. 5).
#' @param flags Data Frame der Markierungen (n Zeilen).
#' @return `invisible(Namen der gemeldeten Markierungen)`.
#' @noRd
eng_flag_conditions <- function(flags) {
  warn <- c("arbitrage", "stopped", "negative_amortization", "limit_breach")
  info <- c("shortfall", "reserve_used", "limit_cut", "overdraft_threshold",
            "equity_call_over_savings")
  hit <- character(0)
  for (f in intersect(c(warn, info), names(flags))) {
    x <- flags[[f]]
    if (!is.logical(x) || !any(x, na.rm = TRUE)) next
    share <- mean(x, na.rm = TRUE)
    if (f %in% warn) {
      vofi_warn(paste0("engine.flags.", f), share = share, .class = "vofi_warning_engine")
    } else {
      vofi_inform(paste0("engine.flags.", f), share = share)
    }
    hit <- c(hit, f)
  }
  invisible(hit)
}
