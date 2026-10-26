# Kreditbetraege amount_eur: auto und topup (WS-D, Spec 00 Abschnitt 8.7, R-69, Konzept F15).
# Bedarf im Fenster W (Bauphase inkl. t0; ohne Bauphase nur t0): Summe der exogenen
# zahlungswirksamen Zeilen (project, grants, equity) plus Auszahlungen der uebrigen Kredite
# (payout_rate * approved * D, aus init()/step() der Instrumente, 8.4), bei topup zusaetzlich die
# Auszahlung des festen auto-Plans; need = laufendes Maximum von -cumsum(c) (>= 0).
# auto: einmal im Basisfall-Vorlauf (vofi_build(), 9.1 Stufe 6a), fest in allen Laeufen
# (deterministisch, MC, Design); topup: je Chunk und Lauf vor der Periodenschleife (9.2 Stufe 4)
# als Mehrbedarf gegenueber dem Basisfall (need0). Bauzeitzinsen und Gebuehren sind nicht im
# Bedarf enthalten; sie laufen ueber den Ausgleich.

#' Fenster W der Bedarfsrechnung (8.7): Spalten der Bauphase inkl. t0, sonst nur t0
#' @param grid `vofi_grid`.
#' @return aufsteigende Spaltenindizes (zusammenhängend ab 1).
#' @noRd
eng_auto_window <- function(grid) {
  w <- which(grid$phase == "construction")
  if (length(w) == 0L) return(1L)
  seq_len(max(c(1L, w)))
}

#' Instrumente mit amount_eur auto bzw. topup (8.7) und ihre Zulässigkeit
#'
#' Höchstens ein Instrument mit `auto` und höchstens eines mit `topup`; beide ohne
#' `draw_schedule`, mit `start` am Stichtag und nicht als Bestandsdarlehen (`existing`).
#' @param instruments Instrumente des Modells (`eng_build_instruments()`).
#' @param grid `vofi_grid` (Stichtag, Fertigstellung) oder `NULL` (ohne Terminprüfung).
#' @return `list(auto = id | NULL, topup = id | NULL)`.
#' @noRd
eng_auto_ids <- function(instruments, grid = NULL) {
  auto <- topup <- NULL
  for (id in names(instruments)) {
    a <- instruments[[id]]$spec$amount_eur
    if (node_is(a) && identical(a$kind, "auto")) {
      if (identical(a$mode, "topup")) topup <- c(topup, id) else auto <- c(auto, id)
    }
  }
  if (length(auto) > 1L || length(topup) > 1L) {
    vofi_abort("engine.auto_multiple", .class = "vofi_error_validation")
  }
  for (id in c(auto, topup)) {
    sp <- instruments[[id]]$spec
    sched <- sp$draw_schedule
    bad <- character(0)
    if (is.list(sched) && length(sched$dates) > 0L) bad <- c(bad, "draw_schedule")
    if (isTRUE(sp$existing)) bad <- c(bad, "existing")
    st <- sp$start
    if (!is.null(st) && !is.null(grid)) {
      d <- if (identical(st, "completion")) grid$completion_date else
        tryCatch(utl_as_date(st, "start"), error = function(e) NULL)
      if (is.null(d) || !identical(as.numeric(d), as.numeric(grid$valuation_date))) {
        bad <- c(bad, "start")
      }
    }
    if (length(bad) > 0L) {
      vofi_abort("engine.auto_forbidden", id = id, fields = utl_collapse(bad),
                 .class = "vofi_error_validation")
    }
  }
  list(auto = auto, topup = topup)
}

#' Zahlungen c im Fenster W (8.7)
#'
#' @param model `vofi_model`.
#' @param ctx Laufkontext.
#' @param exo exogener Ledger.
#' @param window Spalten von W.
#' @param with_auto bei topup: Auszahlung des festen auto-Plans einbeziehen.
#' @return n x |W|.
#' @noRd
eng_auto_cash <- function(model, ctx, exo, window, with_auto = FALSE) {
  cw <- ledger_sum(exo, section = c("project", "grants", "equity"), cash = TRUE)[, window,
                                                                                 drop = FALSE]
  skip <- c(model$auto_id, model$topup_id)
  for (id in setdiff(names(model$instruments), skip)) {
    k <- model$instruments[[id]]
    st <- k$def$init(k$spec, ctx)
    for (q in seq_along(window)) {
      r <- k$def$step(st, window[q] - 1L, ctx)
      st <- r$state
      cw[, q] <- cw[, q] + as.double(r$flows$draw %||% 0)
    }
  }
  if (with_auto && length(model$auto_id) == 1L) {
    a <- model$base$auto
    k <- model$instruments[[model$auto_id]]
    kappa <- ctx$param_base(k$spec, "payout_rate") %||% rep(1, ctx$n)
    cw <- cw + kappa * matrix(a$draws[window], ctx$n, length(window), byrow = TRUE)
  }
  cw
}

#' Bedarf: laufendes Maximum von -cumsum(c) über W, mindestens 0 (8.7)
#' @param cw n x |W|.
#' @return n x |W|.
#' @noRd
eng_auto_need <- function(cw) {
  need <- cw
  cum <- rep(0, nrow(cw))
  run <- rep(0, nrow(cw))
  for (q in seq_len(ncol(cw))) {
    cum <- cum + cw[, q]
    run <- pmax.int(run, -cum)
    need[, q] <- run
  }
  need
}

#' Auszahlungsplan aus einem laufenden Bedarf (8.7)
#' @param need n x |W| (monoton nicht fallend).
#' @param buffer `auto_buffer_share` (n-Vektor).
#' @param payout `payout_rate` (n-Vektor).
#' @return n x |W| Nennbeträge D.
#' @noRd
eng_auto_plan <- function(need, buffer, payout) {
  cash <- need - cbind(0, need[, -ncol(need), drop = FALSE])
  cash * (1 + buffer) / payout
}

#' auto-Betrag im Basisfall-Vorlauf bestimmen (9.1 Stufe 6a, R-69)
#'
#' @param model `vofi_model` (ohne `base`).
#' @param ctx deterministischer Kontext des Basisfalls (n = 1).
#' @param exo exogener Ledger des Basisfalls.
#' @return `list(auto = NULL | list(commitment, draws, window), need0 = NULL | num[|W|])`.
#' @noRd
eng_auto_base <- function(model, ctx, exo) {
  if (length(model$auto_id) == 0L && length(model$topup_id) == 0L) {
    return(list(auto = NULL, need0 = NULL))
  }
  g <- ctx$grid
  window <- eng_auto_window(g)
  cw <- eng_auto_cash(model, ctx, exo, window)
  need <- eng_auto_need(cw)
  if (length(model$auto_id) == 0L) return(list(auto = NULL, need0 = as.double(need[1L, ])))
  k <- model$instruments[[model$auto_id]]
  buffer <- ctx$param_base(k$spec, "auto_buffer_share") %||% 0
  payout <- ctx$param_base(k$spec, "payout_rate") %||% 1
  rnd <- ctx$param_base(k$spec, "auto_round_eur") %||% 0
  d <- eng_auto_plan(need[1L, , drop = FALSE], buffer[1L], payout[1L])[1L, ]
  commitment <- sum(d)
  if (rnd[1L] > 0) {
    rounded <- ceiling(commitment / rnd[1L] - 1e-9) * rnd[1L]
    d[length(d)] <- d[length(d)] + (rounded - commitment)
    commitment <- rounded
  }
  draws <- numeric(g$T + 1L)
  draws[window] <- d
  if (commitment <= vofi_tol$zero_abs) {
    vofi_inform("engine.auto_zero", id = model$auto_id)
  }
  auto <- list(commitment = commitment, draws = draws, window = window - 1L)
  cw0 <- cw + payout[1L] * matrix(d, nrow(cw), length(window), byrow = TRUE)
  list(auto = auto, need0 = as.double(eng_auto_need(cw0)[1L, ]))
}

#' auto aus dem Basisfall (fest), topup je Lauf (9.2 Stufe 4, 8.7)
#'
#' Legt den topup-Plan des Chunks in `engine_env$topup` ab; `ctx$auto()` liest ihn dort.
#' @param model `vofi_model`.
#' @param ctx Laufkontext des Chunks.
#' @param exo exogener Ledger des Chunks.
#' @param engine_env private Engine-Umgebung.
#' @return `invisible(NULL | list(commitment, draws, window))`.
#' @noRd
eng_auto_amounts <- function(model, ctx, exo, engine_env = NULL) {
  if (length(model$topup_id) == 0L) return(invisible(NULL))
  g <- ctx$grid
  n <- ctx$n
  window <- eng_auto_window(g)
  cw <- eng_auto_cash(model, ctx, exo, window, with_auto = TRUE)
  need <- eng_auto_need(cw)
  need0 <- model$base$need0 %||% rep(0, length(window))
  over <- pmax(need - matrix(need0, n, length(window), byrow = TRUE), 0)
  ex <- over
  run <- rep(0, n)
  for (q in seq_along(window)) {
    run <- pmax.int(run, over[, q])
    ex[, q] <- run
  }
  k <- model$instruments[[model$topup_id]]
  buffer <- ctx$param(k$spec, "auto_buffer_share") %||% rep(0, n)
  payout <- ctx$param(k$spec, "payout_rate") %||% rep(1, n)
  d <- eng_auto_plan(ex, buffer, payout)
  draws <- matrix(0, n, g$T + 1L)
  draws[, window] <- d
  topup <- list(commitment = rowSums(d), draws = draws, window = window - 1L)
  if (is.environment(engine_env)) engine_env$topup <- topup
  invisible(topup)
}
