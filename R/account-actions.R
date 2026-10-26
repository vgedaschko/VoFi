# Ausgleichsaktionen Ue1-Ue4, D1-D4 (WS-D, Spec 00 Abschnitt 8.9).
# Alle zehn Aktionen aus 8.9 (die Ketten der Profile verwenden auch dep_fill_reserve,
# dep_use_reserve und penalty_rate; die Unterlassungsalternative braucht penalty_rate, 9.5 Nr. 5).
# Signatur: apply(acc, amount, t, ctx, inst) -> list(acc, used, flows, flags, inst). Alle Formeln
# elementweise ueber n (pmin.int/pmax.int, keine Verzweigung auf simulierte Werte).
# `inst` ist eine benannte Liste je Kredit k: list(state = <vofi_inst_state>, def = <typedef>).
# Die Warnung zur Heuristik von loan_prepay meldet eng_warn_prepay() einmal je Lauf.

#' Ergebnis einer Ausgleichsaktion
#' @noRd
acc_result <- function(acc, used, flows = list(), flags = list(), inst = NULL) {
  list(acc = acc, used = used, flows = flows, flags = flags, inst = inst)
}

#' Ue1 Kontokorrent tilgen (zuerst Strafzinstranche KKP, dann Regeltranche KK)
#' @noRd
typedef_action_od_repay <- function() {
  vofi_type(
    name = "od_repay", kind = "account_action", role = "surplus", rank = "U1",
    rows = c("od_repay", "odp_repay"),
    apply = function(acc, amount, t, ctx, inst) {
      x1 <- pmin.int(amount, acc$KKP)
      acc$KKP <- acc$KKP - x1
      x2 <- pmin.int(amount - x1, acc$KK)
      acc$KK <- acc$KK - x2
      acc_result(acc, x1 + x2, flows = list(odp_repay = -x1, od_repay = -x2))
    }
  )
}

#' Ue2 Liquiditätsreserve auffüllen (bis L_min)
#' @noRd
typedef_action_dep_fill_reserve <- function() {
  vofi_type(
    name = "dep_fill_reserve", kind = "account_action", role = "surplus", rank = "U2",
    rows = "dep_invest",
    apply = function(acc, amount, t, ctx, inst) {
      x <- pmin.int(amount, pmax.int(acc$Lmin[, acc$j] - acc$G, 0))
      acc$G <- acc$G + x
      acc_result(acc, x, flows = list(dep_invest = -x))
    }
  )
}

#' Ue3 Sondertilgung (Heuristik, standardmäßig aus; R-29)
#' @noRd
typedef_action_loan_prepay <- function() {
  vofi_type(
    name = "loan_prepay", kind = "account_action", role = "surplus", rank = "U3",
    rows = "loan_*_prepay",
    apply = function(acc, amount, t, ctx, inst) {
      n <- length(amount)
      used <- rep(0, n)
      if (t <= 0L || length(inst) == 0L) return(acc_result(acc, used, inst = NULL))
      j <- acc$j
      avail <- pmax.int(amount - pmax.int(acc$Lmin[, j] + acc$prepay_buffer - acc$G, 0), 0)
      ids <- names(inst)
      caps <- list()
      rates <- matrix(-Inf, n, length(ids))
      elig <- matrix(FALSE, n, length(ids))
      for (q in seq_along(ids)) {
        e <- inst[[ids[q]]]
        if (!is.function(e$def$capacity)) next
        cp <- e$def$capacity(e$state, t, ctx)
        caps[[ids[q]]] <- as.double(cp$cap)
        rates[, q] <- as.double(cp$rate_pa)
        elig[, q] <- cp$rate_pa > acc$h_pa[, j] * (1 - acc$w) + acc$prepay_min_spread
      }
      if (length(caps) == 0L) return(acc_result(acc, used, inst = NULL))
      # Rang je Lauf: absteigend nach Zins, Gleichstand financing-Reihenfolge
      rank <- matrix(0L, n, length(ids))
      for (q in seq_along(ids)) {
        higher <- rates > rates[, q] |
          (rates == rates[, q] & matrix(seq_along(ids) < q, n, length(ids), byrow = TRUE))
        rank[, q] <- 1L + rowSums(higher)
      }
      flows <- list()
      rest <- avail
      for (r in seq_along(ids)) {
        for (q in seq_along(ids)) {
          if (is.null(caps[[ids[q]]])) next
          e <- inst[[ids[q]]]
          x <- pmin.int(rest * (rank[, q] == r) * elig[, q], caps[[ids[q]]])
          x <- pmax.int(x, 0)
          p <- e$def$prepay(e$state, x, t, ctx)
          inst[[ids[q]]]$state <- p$state
          u <- as.double(p$used)
          rest <- rest - u
          used <- used + u
          key <- paste0("loan_", ids[q], "_prepay")
          flows[[key]] <- (flows[[key]] %||% 0) - u
        }
      }
      acc_result(acc, used, flows = flows, inst = inst)
    }
  )
}

#' Ue4 Geldanlage (unbegrenzt)
#' @noRd
typedef_action_dep_invest <- function() {
  vofi_type(
    name = "dep_invest", kind = "account_action", role = "surplus", rank = "U4",
    unlimited = TRUE, rows = "dep_invest",
    apply = function(acc, amount, t, ctx, inst) {
      acc$G <- acc$G + amount
      acc_result(acc, amount, flows = list(dep_invest = -amount))
    }
  )
}

#' D1 Geldanlage auflösen (bis L_min)
#' @noRd
typedef_action_dep_withdraw <- function() {
  vofi_type(
    name = "dep_withdraw", kind = "account_action", role = "deficit", rank = "D1",
    rows = "dep_withdraw",
    apply = function(acc, amount, t, ctx, inst) {
      x <- pmin.int(amount, pmax.int(acc$G - acc$Lmin[, acc$j], 0))
      acc$G <- acc$G - x
      acc_result(acc, x, flows = list(dep_withdraw = x))
    }
  )
}

#' D2 Kontokorrent ziehen (bis zum Limit)
#' @noRd
typedef_action_od_draw <- function() {
  vofi_type(
    name = "od_draw", kind = "account_action", role = "deficit", rank = "D2",
    rows = "od_draw",
    apply = function(acc, amount, t, ctx, inst) {
      x <- pmin.int(amount, pmax.int(acc$KL[, acc$j] - acc$KK, 0))
      acc$KK <- acc$KK + x
      acc_result(acc, x, flows = list(od_draw = x),
                 flags = list(overdraft_threshold = (acc$KK + acc$KKP) > acc$flag_threshold))
    }
  )
}

#' D3 Liquiditätsreserve verwenden
#' @noRd
typedef_action_dep_use_reserve <- function() {
  vofi_type(
    name = "dep_use_reserve", kind = "account_action", role = "deficit", rank = "D3",
    rows = "dep_withdraw",
    apply = function(acc, amount, t, ctx, inst) {
      x <- pmin.int(amount, acc$G)
      acc$G <- acc$G - x
      acc_result(acc, x, flows = list(dep_withdraw = x),
                 flags = list(reserve_used = x > vofi_tol$zero_abs))
    }
  )
}

#' D4 Nachschuss (Zufluss von außen, unbegrenzt)
#' @noRd
typedef_action_equity_call <- function() {
  vofi_type(
    name = "equity_call", kind = "account_action", role = "deficit", rank = "D4",
    unlimited = TRUE, rows = "equity_call",
    apply = function(acc, amount, t, ctx, inst) {
      acc_result(acc, amount, flows = list(equity_call = amount),
                 flags = list(shortfall = amount > vofi_tol$zero_abs))
    }
  )
}

#' D4 Strafzinstranche (unbegrenzt, Zins sp)
#' @noRd
typedef_action_penalty_rate <- function() {
  vofi_type(
    name = "penalty_rate", kind = "account_action", role = "deficit", rank = "D4",
    unlimited = TRUE, rows = "odp_draw",
    apply = function(acc, amount, t, ctx, inst) {
      acc$KKP <- acc$KKP + amount
      hit <- amount > vofi_tol$zero_abs
      acc_result(acc, amount, flows = list(odp_draw = amount),
                 flags = list(shortfall = hit, limit_breach = hit))
    }
  )
}

#' D4 Fehlbetrag ausweisen (kein Abbruch, R-32)
#' @noRd
typedef_action_stop <- function() {
  vofi_type(
    name = "stop", kind = "account_action", role = "deficit", rank = "D4",
    unlimited = TRUE, rows = "shortfall",
    apply = function(acc, amount, t, ctx, inst) {
      hit <- amount > vofi_tol$zero_abs
      acc_result(acc, amount, flows = list(shortfall = amount),
                 flags = list(shortfall = hit, stopped = hit))
    }
  )
}
