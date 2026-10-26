# Gemeinsamer Kern der Kredittypen als Zustandsautomat (WS-F; Spec 00 Abschnitte 8.1-8.7, 8.10;
# Spec 01 Teil A Abschnitt 5). Eigentuemer: WS-F.
#
# Referenzsemantik ist die Monatsuhr nach Spec 00 8.5: Zinsen monatlich mit i_nom / 12 auf den
# Monatsanfangsbestand (R-03), Tilgungen in Vertragsfrequenz (1, 4 oder 12 Zahlungen je Jahr),
# alle Betraege einer Periode am Periodenende. Die Umsetzung rechnet je Periode nur die
# Ereignismonate (Zinsanpassung, Beginn der Tilgungsphase, Vertragszahlung, Faelligkeit) einzeln;
# dazwischen liegende Monate ohne Ereignis haben einen konstanten Bestand, ihre Zinsen werden
# geschlossen (Monatszins x Anzahl der Monate) gerechnet (zulaessig nach 8.1 Nr. 3, Abweichung
# zur Monatsuhr im Bereich der Rundung). Alle Termine sind deterministisch (R-47) und werden in
# init() in einen Ereignisplan je Periode uebersetzt; step() verzweigt nur auf Monate, Perioden
# und Konfiguration, nie auf simulierte Werte (Spec 00 2.8).
#
# Umgesetzt: Nennbetrag als Basisfallwert (R-69), amount_eur auto/topup ueber ctx$auto() (8.7),
# Auszahlung bei start bzw. nach draw_schedule (share/eur), approved je Lauf, Auszahlungskurs
# (Disagio), Bearbeitungsgebuehr, Bereitstellungsprovision mit bereitstellungsfreier Zeit,
# tilgungsfreie Anlaufzeit, Annuitaet mit Laufzeit oder Tilgungssatz (tau und term_years
# zugleich, R-100), Ratentilgung, endfaellig mit Schlusstilgung (repay_balloon), vertragliche
# Rate installment_eur, Zinsbindung mit Anschlusszins (Konstante oder Pfad) und wiederholten
# Anschlussbindungen, Ratenregeln keep_term/keep_tilg_rate/keep_payment je Tilgungsart inkl.
# effektiver Restzahl nach Tilgungszuschuss mit shorten_term (R-100), Tilgungszuschuss (share
# bzw. amount_eur, approved, cut_share, Wirkung shorten_term/reduce_installment), geplante
# Sondertilgungen mit Obergrenze je Vertragsjahr, prepay()/capacity() fuer Ue3 (loan_prepay),
# Bestandsdarlehen (existing, Merkzeile assumed), Rundung auf Cent (round_payments),
# Kombinationsregeln und Plausibilitaeten in validate() (Spec 01 Teil A 5.2, 5.3, 5.5).

# ---------------------------------------------------------------------------------------------
# Parameterschema, Labels, Hilfsfunktionen
# ---------------------------------------------------------------------------------------------

#' Parameterschema der Kredittypen (Spec 00 8.2, Spec 01 Teil A 5.2)
#'
#' Alle Zeitparameter und der Nennbetrag sind `deterministic_only` (R-47, R-69).
#' @param repayment `"annuity"`, `"installment"` oder `"bullet"`.
#' @return benannte Liste von `vofi_param`.
#' @noRd
inst_loan_params <- function(repayment) {
  p <- list(
    amount_eur = vofi_param("amount", required = TRUE, allow_auto = TRUE,
                            deterministic_only = TRUE, unit = "EUR", min = 0),
    approved = vofi_param("value", default = 1, min = 0, max = 1),
    existing = vofi_param("logical", default = FALSE),
    installment_eur = vofi_param("amount", unit = "EUR", min = 0),
    rank = vofi_param("integer", min = 1),
    start = vofi_param("timing", grid_default = "valuation_date"),
    draw_schedule = vofi_param("schedule", deterministic_only = TRUE),
    rate_pa = vofi_param("rate", required = TRUE, min = -0.01, max = 0.25,
                         shapes = c("scalar", "path")),
    payments_per_year = vofi_param("integer", default = 12L),
    term_years = vofi_param("number", deterministic_only = TRUE, min = 0),
    grace_years = vofi_param("number", default = 0, deterministic_only = TRUE, min = 0),
    initial_repayment_pa = vofi_param("rate", min = 0),
    fixed_years = vofi_param("number", deterministic_only = TRUE, min = 0),
    followup_rate_pa = vofi_param("value", default = list(ref = "market.mortgage_rate")),
    followup_spread_pa = vofi_param("rate", default = 0),
    followup_fixed_years = vofi_param("number", deterministic_only = TRUE, min = 0),
    refi_rule = vofi_param("enum", values = "vocab:refi_rule"),
    followup_repayment_pa = vofi_param("rate", min = 0),
    payout_rate = vofi_param("share", default = 1),
    fees = vofi_param("map", fields = list(
      processing_fee_share = vofi_param("share", default = 0),
      commitment_fee_rate_month = vofi_param("share", default = 0),
      commitment_free_months = vofi_param("integer", default = 0L, min = 0),
      commitment_date = vofi_param("timing")
    )),
    repayment_grant = vofi_param("map", fields = list(
      share = vofi_param("share"),
      amount_eur = vofi_param("value", unit = "EUR", min = 0),
      date = vofi_param("timing"),
      year = vofi_param("integer"),
      effect = vofi_param("enum", values = "vocab:repayment_grant_effect",
                          default = "shorten_term"),
      approved = vofi_param("value", default = 1, min = 0, max = 1),
      cut_share = vofi_param("share", default = 0)
    )),
    planned_prepayments = vofi_param("schedule", unit = "EUR"),
    prepay_allowed = vofi_param("logical", default = FALSE),
    prepay_cap_share_pa = vofi_param("share", default = 1),
    auto_buffer_share = vofi_param("share", default = 0),
    auto_round_eur = vofi_param("amount", default = 0, deterministic_only = TRUE, min = 0),
    round_payments = vofi_param("logical", default = FALSE)
  )
  if (!identical(repayment, "annuity")) {
    p$initial_repayment_pa <- NULL
    p$followup_repayment_pa <- NULL
  }
  if (identical(repayment, "bullet")) p$installment_eur <- NULL
  p
}

#' Codes der Meldungen der Kredittypen (Label-Abschnitte `errors` und `msg`)
#'
#' Jeder Code existiert in den Label-Dateien aller drei Kredittypen (Test).
#' @return `list(errors = chr, msg = chr)`.
#' @noRd
inst_loan_codes <- function() {
  list(
    errors = c("ppy", "term_missing", "term_nonpositive", "months_fraction", "grace_too_long",
               "nonpositive", "tau_with_installment", "refi_rule_invalid", "tau_missing",
               "keep_term_needs_term", "existing_forbidden", "existing_start",
               "auto_draw_schedule", "auto_start", "amount_nonpositive",
               "installment_nonpositive", "rank_invalid", "start_before", "draw_share_sum",
               "draw_eur_sum", "draws_exceed", "draw_before_start", "rate_path",
               "payout_rate_range", "commitment_date_range", "grant_share_xor_amount",
               "grant_needs_id", "grant_exceeds", "grant_before_start", "grant_date_year",
               "followup_missing"),
    msg = c("balloon_at_maturity", "existing_installment_missing", "existing_new_build",
            "auto_params_unused", "rate_high", "fee_high", "commitment_fee_high",
            "commitment_fee_window", "prepay_exceeds", "prepay_capped", "prepay_program",
            "negative_amortization", "followup_repayment_unused", "fixed_after_horizon",
            "followup_truncated", "start_after_horizon", "grant_after_horizon",
            "measure_delay", "amount_fixed", "inactive", "auto_zero", "grant_capped",
            "neg_amort_run")
  )
}

#' Label-Schlüssel einer Meldung eines Kredittyps
#' @param type Typname (z. B. `"annuity_loan"`).
#' @param section `"errors"` oder `"msg"`.
#' @param code Code aus `inst_loan_codes()`.
#' @noRd
inst_loan_key <- function(type, section, code) {
  paste0("types.instrument.", type, ".", section, ".", code)
}

#' Typname aus der Komponente bzw. der Tilgungsart
#' @noRd
inst_loan_type <- function(spec, repayment = NULL) {
  tp <- spec[["type"]]
  if (utl_is_string(tp)) return(tp)
  paste0(repayment %||% "annuity", "_loan")
}

#' Laufzeitfehler eines Kredittyps (Eingabe unzulässig; die Validierung meldet ihn vorher)
#' @noRd
inst_loan_abort <- function(spec, code, ...) {
  vofi_abort(inst_loan_key(inst_loan_type(spec), "errors", code), id = spec[["id"]] %||% "?",
             ..., .class = "vofi_error_input")
}

#' Deterministischer Skalar eines Parameters (Basisfallwert, erster Lauf)
#' @noRd
inst_loan_det <- function(ctx, spec, name) {
  v <- ctx$param_base(spec, name)
  if (is.null(v)) NULL else as.double(v[1L])
}

#' Termin eines Parameters der Art timing als Datum (Token `completion` = Fertigstellung)
#' @noRd
inst_loan_date <- function(ctx, spec, name, default) {
  v <- ctx$setting(spec, name)
  if (is.null(v)) return(default)
  if (identical(v, "completion")) return(ctx$grid$completion_date)
  if (inherits(v, "Date")) return(v)
  utl_as_date(v, name)
}

#' Zahlenwert eines normalisierten Knotens (Konstante) bzw. `NULL`
#' @noRd
inst_loan_const <- function(x) {
  if (is.list(x) && identical(x$kind, "const") && is.numeric(x$value) && length(x$value) == 1L) {
    return(as.double(x$value))
  }
  if (is.numeric(x) && length(x) == 1L) return(as.double(x))
  NULL
}

#' Kaufmännische Rundung auf Cent (Spec 01 Teil A 5.2: floor(100 x + 0,5) / 100)
#' @noRd
inst_loan_round <- function(x) floor(100 * x + 0.5) / 100

#' Annuität aus Bestand, Zins je Vertragszahlung und Zahl der Zahlungen (i_s = 0: B / n)
#' @param b n-Vektor Bestand.
#' @param i_s n-Vektor Zins je Vertragszahlung (i_pa / ppy).
#' @param n_rem Zahl der Zahlungen (Skalar oder n-Vektor, >= 1).
#' @noRd
inst_loan_annuity <- function(b, i_s, n_rem) {
  nb <- length(b)
  i_s <- rep_len(as.double(i_s), nb)
  n_rem <- rep_len(as.double(n_rem), nb)
  out <- b / n_rem
  nz <- abs(i_s) > 1e-15
  out[nz] <- b[nz] * i_s[nz] / (1 - (1 + i_s[nz])^(-n_rem[nz]))
  out
}

#' Anzahl der Vertragszahlungsmonate in (m, m_mat] (Spec 00 8.3; `Inf` ohne Laufzeit)
#' @noRd
inst_loan_n_rem <- function(st, m) {
  if (!is.finite(st$m_mat)) return(Inf)
  if (m >= st$m_mat) return(0)
  k_mat <- floor((st$m_mat - st$m_rep) / st$pay_interval)
  k_m <- if (m <= st$m_rep) 0 else floor((m - st$m_rep) / st$pay_interval)
  max(0, k_mat - k_m)
}

#' Zahl der Vertragszahlungen, die die bisherige Rate beim bisherigen Zins für den Bestand braucht
#' (n* in Spec 00 8.6, R-100); elementweise über n, `Inf` bei Rate <= Zins
#' @param rep_code 1 Annuität, 2 Ratentilgung.
#' @noRd
inst_loan_n_star <- function(rep_code, b, inst, i_old, ppy) {
  nb <- length(b)
  out <- rep(Inf, nb)
  inst <- rep_len(as.double(inst), nb)
  pos <- !is.na(inst) & inst > 0
  if (rep_code == 2L) {
    out[pos] <- b[pos] / inst[pos]
    return(out)
  }
  i_s <- rep_len(as.double(i_old), nb) / ppy
  zi <- pos & abs(i_s) <= 1e-15
  out[zi] <- b[zi] / inst[zi]
  nz <- which(pos & !zi)
  if (length(nz) > 0L) {
    x <- 1 - b[nz] * i_s[nz] / inst[nz]
    v <- rep(Inf, length(nz))
    ok <- x > 0
    v[ok] <- -log(x[ok]) / log1p(i_s[nz][ok])
    out[nz] <- v
  }
  out
}

# ---------------------------------------------------------------------------------------------
# init(): Zustand und deterministischer Ereignisplan (Spec 00 8.3, Spec 01 Teil A 5.2)
# ---------------------------------------------------------------------------------------------

#' Ereignisplan je Periode (deterministisch)
#'
#' Je Periode j: Ereignismonate `m` (Zinsanpassung zu Monatsbeginn, Beginn der Tilgungsphase,
#' Vertragszahlung, Fälligkeit) mit Schaltern, Zahl der ereignislosen Monate vor jedem Ereignis
#' (`gap`) und nach dem letzten (`tail`), Spalte des Anschlusszinses (`jstar`), Zahl der Monate
#' mit Bereitstellungsprovision (`n_fee`) und Ende eines Vertragsjahres (`ytd`).
#' @noRd
inst_loan_plan <- function(g, m_start, m_rep, m_mat, pay_int, resets, fee_free_until) {
  n_t <- g$T + 1L
  out <- vector("list", n_t)
  for (j in seq_len(n_t)[-1L]) {
    if (g$months[j] <= 0L) next
    ms <- seq.int(g$month_end[j - 1L] + 1L, g$month_end[j])
    reset <- (ms - 1L) %in% resets
    rep_start <- ms == m_rep + 1
    pay <- ms > m_rep & ((ms - m_rep) %% pay_int) == 0 & ms <= m_mat
    mat <- ms == m_mat
    ev <- reset | rep_start | pay | mat
    em <- ms[ev]
    nxt <- c(ms[1L], em + 1L)
    jstar <- rep(NA_integer_, length(em))
    if (any(reset[ev])) {
      jstar[reset[ev]] <- utl_month_period(g, em[reset[ev]] - 1L) + 1L
    }
    gap <- as.integer(em - nxt[seq_along(em)])
    out[[j]] <- list(
      m = em, gap = gap, tail = as.integer(ms[length(ms)] - nxt[length(nxt)] + 1L),
      reset = reset[ev], rep = rep_start[ev], pay = pay[ev], mat = mat[ev], jstar = jstar,
      run = inst_loan_runs(pay[ev], reset[ev] | rep_start[ev] | mat[ev], gap, pay_int),
      n_fee = sum(ms > fee_free_until),
      ytd = any((ms - m_start) > 0 & ((ms - m_start) %% 12L) == 0L)
    )
  }
  out
}

#' Folgen einfacher Vertragszahlungen innerhalb einer Periode (geschlossen rechenbar)
#'
#' Ereignis k ist einfach, wenn es nur eine Vertragszahlung ist, ein volles Zahlungsintervall
#' seit der vorigen Zahlung derselben Periode liegt (`gap = pay_int - 1`) und die vorige Zahlung
#' die aufgelaufenen Zinsen auf 0 gesetzt hat. `run[k]` = Länge der Folge, die bei k beginnt
#' (>= 2), 1 für einzeln gerechnete Ereignisse, 0 innerhalb einer Folge.
#' @noRd
inst_loan_runs <- function(pay, other, gap, pay_int) {
  ne <- length(pay)
  run <- rep(1L, ne)
  if (ne < 3L) return(run)
  simple <- c(FALSE, pay[-1L] & !other[-1L] & gap[-1L] == pay_int - 1L & pay[-ne])
  k <- 2L
  while (k <= ne) {
    if (simple[k]) {
      e <- k
      while (e < ne && simple[e + 1L]) e <- e + 1L
      if (e > k) {
        run[k] <- e - k + 1L
        run[(k + 1L):e] <- 0L
      }
      k <- e + 1L
    } else {
      k <- k + 1L
    }
  }
  run
}

#' Geschlossene Rechnung einer Folge von K einfachen Vertragszahlungen (8.1 Nr. 3)
#'
#' Ohne Begrenzung gilt je Zahlungsintervall B' = B (1 + i_s) - inst (Annuität) bzw.
#' B' = B - inst (Ratentilgung) mit i_s = i_pa / ppy. Läufe mit Volltilgung innerhalb der Folge
#' und Läufe mit Rate <= Zins rechnet die Funktion für die betroffenen Zeilen Monat für Monat
#' bzw. als konstanten Bestand (identisch zur Monatsuhr).
#' @return `list(b, z, r)` (n-Vektoren: Bestand danach, Zinsen, Tilgung).
#' @noRd
inst_loan_run_closed <- function(b, inst, i_pa, k_run, ppy, pay_int, rep_code) {
  j <- i_pa / ppy
  if (rep_code == 2L) {
    r_cyc <- inst + 0 * b
    r_cyc[r_cyc < 0] <- 0
    b_k <- b - k_run * r_cyc
    z <- k_run * b * j - r_cyc * j * k_run * (k_run - 1) / 2
    r <- b - b_k
    neg <- rep(FALSE, length(b))
  } else {
    q_k <- (1 + j)^k_run
    zi <- abs(j) <= 1e-15
    j_safe <- j
    j_safe[zi] <- 1
    b_k <- b * q_k - inst * (q_k - 1) / j_safe
    b_k[zi] <- b[zi] - k_run * inst[zi]
    neg <- inst <= b * j
    b_k[neg] <- b[neg]
    r <- b - b_k
    z <- k_run * inst - r
    z[neg] <- k_run * b[neg] * j[neg]
  }
  po <- !neg & b_k <= 1e-7 * (b + 1)
  if (any(po)) {
    idx <- which(po)
    bs <- b[idx]
    i12 <- i_pa[idx] / 12
    zs <- rs <- 0 * bs
    for (kk in seq_len(k_run)) {
      acc <- bs * i12 * (pay_int - 1L) + bs * i12
      zs <- zs + acc
      rr <- if (rep_code == 1L) inst[idx] - acc else inst[idx] + 0 * acc
      rr[rr < 0] <- 0
      over <- rr > bs
      rr[over] <- bs[over]
      bs <- bs - rr
      rs <- rs + rr
    }
    b_k[idx] <- bs
    z[idx] <- zs
    r[idx] <- rs
  }
  list(b = b_k, z = z, r = r)
}

#' Monate der Zinsanpassungen in (0, m_mat) innerhalb des Horizonts (Spec 01 Teil A 5.2)
#' @noRd
inst_loan_resets <- function(m_start, fixed, ffix, m_mat, big_m) {
  out <- integer(0)
  if (is.null(fixed)) return(out)
  r <- m_start + round(12 * fixed)
  stp <- if (is.null(ffix)) Inf else round(12 * ffix)
  while (r > 0 && r < m_mat && r < big_m) {
    out <- c(out, as.integer(r))
    if (!is.finite(stp) || stp <= 0) break
    r <- r + stp
  }
  out
}

#' Gutschrifttermin des Tilgungszuschusses (Spec 00 8.2, Spec 01 Teil A 5.2)
#'
#' `date` bzw. `year`; sonst die spätere von Fertigstellung (Maßnahme `measure_id`, sonst
#' Raster) und Ende der letzten Auszahlungsperiode.
#' @noRd
inst_loan_grant_date <- function(ctx, spec, rg, t_last) {
  g <- ctx$grid
  d <- inst_loan_date(ctx, spec, "repayment_grant.date", NULL)
  if (!is.null(d)) return(d)
  y <- rg[["year"]]
  if (!is.null(y)) return(as.Date(sprintf("%04d-01-01", as.integer(y))))
  comp <- g$completion_date
  mid <- spec[["measure_id"]]
  if (utl_is_string(mid)) {
    md <- path_get(ctx$spec, path_join("measures", mid, "completion_date"))
    if (utl_is_string(md)) md <- as.Date(md, optional = TRUE)
    if (inherits(md, "Date") && length(md) == 1L && !is.na(md)) comp <- md
  }
  max(comp, g$date_end[t_last + 1L])
}

#' Auszahlungsplan (Nennbeträge n x (T+1)) und Perioden der ersten und letzten Auszahlung
#' @return `list(commitment, draws, t_first, t_last, inactive)`.
#' @noRd
inst_loan_draw_plan <- function(spec, ctx, existing, auto_mode, t_start) {
  g <- ctx$grid
  n <- ctx$n
  n_t <- g$T + 1L
  if (!is.null(auto_mode)) {
    a <- ctx$auto(spec[["id"]])
    draws <- a$draws
    if (!is.matrix(draws) || !identical(dim(draws), c(as.integer(n), n_t))) {
      draws <- matrix(rep_len(as.double(draws), n * n_t), n, n_t)
    }
    win <- which(g$phase == "construction") - 1L
    if (length(win) == 0L) win <- 0L
    return(list(commitment = rep_len(as.double(a$commitment), n), draws = draws * 1,
                t_first = as.integer(min(win)), t_last = as.integer(max(win)),
                inactive = FALSE))
  }
  commitment <- rep_len(as.double(ctx$param_base(spec, "amount_eur")), n)
  draws <- matrix(0, n, n_t)
  if (existing) {
    return(list(commitment = commitment, draws = draws, t_first = 0L, t_last = 0L,
                inactive = FALSE))
  }
  sched <- path_get(spec, "draw_schedule")
  if (is.null(sched)) {
    if (is.na(t_start)) {
      return(list(commitment = commitment, draws = draws, t_first = NA_integer_,
                  t_last = NA_integer_, inactive = TRUE))
    }
    draws[, t_start + 1L] <- commitment
    return(list(commitment = commitment, draws = draws, t_first = as.integer(t_start),
                t_last = as.integer(t_start), inactive = FALSE))
  }
  amt <- ctx$param_base(spec, "draw_schedule", "path")
  draws <- if (identical(sched$unit, "share")) amt * commitment else amt
  tt <- if (identical(sched$kind, "schedule")) {
    as.integer(grid_period_of(g, sched$dates))
  } else {
    which(colSums(abs(amt)) > 0) - 1L
  }
  tt <- tt[!is.na(tt)]
  if (length(tt) == 0L) {
    return(list(commitment = commitment, draws = draws * 0, t_first = NA_integer_,
                t_last = NA_integer_, inactive = TRUE))
  }
  list(commitment = commitment, draws = draws, t_first = as.integer(min(tt)),
       t_last = as.integer(max(tt)), inactive = FALSE)
}

#' Zustand initialisieren (Spec 00 8.3)
#' @param spec Komponente aus `financing`.
#' @param ctx Laufkontext.
#' @param repayment Tilgungsart.
#' @return `vofi_inst_state`.
#' @noRd
inst_loan_init <- function(spec, ctx, repayment) {
  g <- ctx$grid
  n <- ctx$n
  n_t <- g$T + 1L
  me <- g$month_end
  big_m <- me[n_t]
  zero <- rep(0, n)
  rep_code <- match(repayment, c("annuity", "installment", "bullet"))
  existing <- isTRUE(ctx$setting(spec, "existing"))
  a_node <- path_get(spec, "amount_eur")
  auto_mode <- if (node_is(a_node) && identical(a_node$kind, "auto")) {
    a_node$mode %||% "auto"
  } else {
    NULL
  }
  ppy <- as.integer(ctx$setting(spec, "payments_per_year") %||% 12L)
  if (length(ppy) != 1L || is.na(ppy) || !(ppy %in% c(1L, 4L, 12L))) {
    inst_loan_abort(spec, "ppy", value = utl_collapse(format(ppy)))
  }
  pay_int <- 12L %/% ppy
  term <- inst_loan_det(ctx, spec, "term_years")
  grace <- if (existing) 0 else inst_loan_det(ctx, spec, "grace_years") %||% 0
  has_tau <- rep_code == 1L && !is.null(path_get(spec, "initial_repayment_pa"))
  has_inst <- rep_code != 3L && !is.null(path_get(spec, "installment_eur"))
  if (is.null(term) && !(rep_code == 1L && (has_tau || has_inst))) {
    inst_loan_abort(spec, "term_missing")
  }
  if (!is.null(term) && term <= 0) inst_loan_abort(spec, "term_nonpositive", value = term)
  start <- if (existing) g$valuation_date else
    inst_loan_date(ctx, spec, "start", g$valuation_date)
  t_start <- grid_period_of(g, start)
  if (isTRUE(attr(t_start, "before"))) inst_loan_abort(spec, "start_before", date = start)
  t_start <- as.integer(t_start)
  dp <- inst_loan_draw_plan(spec, ctx, existing, auto_mode, t_start)
  # Hinweise zu deterministischen Sachverhalten nur im deterministischen Lauf (nicht je Chunk)
  if (identical(ctx$mode, "deterministic")) {
    type <- inst_loan_type(spec, repayment)
    if (dp$inactive) ctx$inform(inst_loan_key(type, "msg", "inactive"), id = spec[["id"]] %||% "?")
    if (identical(auto_mode, "auto") && all(dp$commitment <= 0)) {
      ctx$inform(inst_loan_key(type, "msg", "auto_zero"), id = spec[["id"]] %||% "?")
    }
  }
  t_ref <- if (!is.na(t_start)) t_start else dp$t_first
  if (is.na(t_ref)) t_ref <- g$T
  m_start <- if (existing) 0L else as.integer(me[t_ref + 1L])
  t_last <- if (is.na(dp$t_last)) g$T else dp$t_last
  m_a <- if (existing) 0L else as.integer(me[t_last + 1L])
  m_rep <- m_a + round(12 * grace)
  m_mat <- if (is.null(term)) Inf else m_a + round(12 * term)
  resets <- inst_loan_resets(m_start, inst_loan_det(ctx, spec, "fixed_years"),
                             inst_loan_det(ctx, spec, "followup_fixed_years"), m_mat, big_m)
  refi_rule <- ctx$setting(spec, "refi_rule") %||%
    (if (has_tau) "keep_tilg_rate" else "keep_term")
  tau <- if (has_tau) as.double(ctx$param(spec, "initial_repayment_pa")) else
    rep(NA_real_, n)
  tau2 <- if (rep_code == 1L && !is.null(path_get(spec, "followup_repayment_pa"))) {
    as.double(ctx$param(spec, "followup_repayment_pa"))
  } else {
    tau
  }
  if (length(resets) > 0L && rep_code != 3L) {
    if (rep_code == 2L && identical(refi_rule, "keep_tilg_rate")) {
      inst_loan_abort(spec, "refi_rule_invalid", rule = refi_rule)
    }
    if (identical(refi_rule, "keep_tilg_rate") && anyNA(tau2)) {
      inst_loan_abort(spec, "tau_missing")
    }
    if (identical(refi_rule, "keep_term") && !is.finite(m_mat)) {
      inst_loan_abort(spec, "keep_term_needs_term")
    }
  }
  followup <- if (length(resets) > 0L) {
    ctx$param(spec, "followup_rate_pa", "path")
  } else {
    matrix(0, n, n_t)
  }
  rate <- ctx$param(spec, "rate_pa", "path")
  j_rate <- if (identical(auto_mode, "topup")) t_last + 1L else t_ref + 1L
  fee_rate <- if (existing) zero else
    ctx$param(spec, "fees.commitment_fee_rate_month") %||% zero
  fee_share <- if (existing) zero else
    ctx$param(spec, "fees.processing_fee_share") %||% zero
  free <- as.double(ctx$setting(spec, "fees.commitment_free_months") %||% 0)
  cdate <- inst_loan_date(ctx, spec, "fees.commitment_date", start)
  fee_free_until <- utl_month_ceiling(grid_month_pos(g, cdate)) + free
  rg <- path_get(spec, "repayment_grant")
  has_tz <- !existing && is_map(rg) && (!is.null(rg[["share"]]) || !is.null(rg[["amount_eur"]]))
  t_tz <- NA_integer_
  tz_amount <- rep(NA_real_, n)
  tz_share <- NULL
  tz_cut <- zero
  tz_appr <- rep(1, n)
  by_amount <- FALSE
  if (has_tz) {
    tz_date <- inst_loan_grant_date(ctx, spec, rg, t_last)
    t_tz <- as.integer(grid_period_of(g, tz_date))
    tz_appr <- ctx$param(spec, "repayment_grant.approved") %||% rep(1, n)
    tz_cut <- ctx$param(spec, "repayment_grant.cut_share") %||% zero
    by_amount <- !is.null(rg[["amount_eur"]])
    if (by_amount) {
      tz_amount <- as.double(ctx$param(spec, "repayment_grant.amount_eur")) * tz_appr *
        (1 - tz_cut)
    } else {
      tz_share <- as.double(ctx$param(spec, "repayment_grant.share"))
    }
  }
  pp <- path_get(spec, "planned_prepayments")
  planned <- matrix(0, n, n_t)
  if (!is.null(pp)) {
    planned <- ctx$param(spec, "planned_prepayments", "path")
    if (identical(pp$unit, "share")) planned <- planned * dp$commitment
  }
  approved <- if (existing) rep(1, n) else as.double(ctx$param(spec, "approved") %||% rep(1, n))
  st <- list(m_rep = m_rep, m_mat = m_mat, pay_interval = pay_int)
  new_vofi_inst_state(list(
    B = zero, drawn = zero, commitment = dp$commitment, i_pa = as.double(rate[, j_rate]),
    inst = rep(NA_real_, n), accrued = zero, tz_amount = tz_amount, approved = approved,
    prepaid_ytd = zero, tau = tau, neg_amort = rep(FALSE, n),
    repayment = repayment, ppy = ppy, pay_interval = pay_int,
    t_first_draw = as.integer(dp$t_first), m_start = as.integer(m_start), m_A = as.integer(m_a),
    m_rep = as.double(m_rep), m_mat = as.double(m_mat), reset_months = resets,
    fee_free_until = as.double(fee_free_until), inst_set = FALSE, t_tz = t_tz,
    draws = dp$draws, planned = planned, followup = followup,
    par = list(
      type = inst_loan_type(spec, repayment), id = spec[["id"]] %||% "?", rep_code = rep_code,
      kappa = as.double(ctx$param(spec, "payout_rate") %||% rep(1, n)),
      spread = as.double(ctx$param(spec, "followup_spread_pa") %||% zero),
      refi_rule = refi_rule, existing = existing, inactive = dp$inactive, tau2 = tau2,
      has_tau = has_tau,
      effect = ctx$setting(spec, "repayment_grant.effect") %||% "shorten_term",
      has_tz = has_tz, tz_by_amount = by_amount, tz_share = tz_share, tz_cut = tz_cut,
      tz_approved = tz_appr, fee_share = as.double(fee_share), fee_rate = as.double(fee_rate),
      prepay_allowed = isTRUE(ctx$setting(spec, "prepay_allowed")),
      cap_share = as.double(ctx$param(spec, "prepay_cap_share_pa") %||% rep(1, n)),
      installment = if (has_inst) as.double(ctx$param(spec, "installment_eur")) else NULL,
      round = isTRUE(ctx$setting(spec, "round_payments")), has_planned = !is.null(pp),
      n_s = inst_loan_n_rem(st, m_rep),
      plan = inst_loan_plan(g, m_start, m_rep, m_mat, pay_int, resets, fee_free_until)
    )
  ))
}

# ---------------------------------------------------------------------------------------------
# Ratenbestimmung und Zinsanpassung (Spec 00 8.6)
# ---------------------------------------------------------------------------------------------

#' Erste Rate der Tilgungsphase (set_installment)
#' @param b Bestand zu Beginn der ersten Vertragszahlung.
#' @param i_pa gültiger Jahreszins.
#' @noRd
inst_loan_set_installment <- function(st, b, i_pa) {
  p <- st$par
  if (!is.null(p$installment)) return(p$installment)
  basis <- if (p$has_tz && identical(p$effect, "reduce_installment")) b else
    st$commitment * st$approved
  n_s <- max(p$n_s, 1)
  out <- if (p$rep_code == 1L) {
    if (p$has_tau) basis * (i_pa + st$tau) / st$ppy else
      inst_loan_annuity(basis, i_pa / st$ppy, n_s)
  } else if (p$rep_code == 2L) {
    basis / n_s
  } else {
    rep(0, length(b))
  }
  if (isTRUE(p$round)) out <- inst_loan_round(out)
  out
}

#' Rate nach Zinsanpassung je Tilgungsart (refi; nur bei festgelegter Rate)
#'
#' `keep_term` rechnet nach einem zuvor gutgeschriebenen Tilgungszuschuss mit `shorten_term`
#' mit der effektiven Restzahl n_eff = min(n_rem(m - 1), ceiling(n* - 1e-9)) (R-100).
#' @param m Monat, zu dessen Beginn angepasst wird.
#' @param t Periode.
#' @return `list(inst, tau, neg_amort, warn)`.
#' @noRd
inst_loan_refi <- function(st, b, inst, i_old, i_new, m, t) {
  p <- st$par
  rule <- p$refi_rule
  out <- list(inst = inst, tau = st$tau, neg_amort = st$neg_amort, warn = FALSE)
  if (p$rep_code == 3L) return(out)
  if (identical(rule, "keep_term")) {
    n_use <- rep(inst_loan_n_rem(st, m - 1), length(b))
    if (p$has_tz && identical(p$effect, "shorten_term") && !is.na(st$t_tz) && st$t_tz < t) {
      n_star <- inst_loan_n_star(p$rep_code, b, inst, i_old, st$ppy)
      n_use <- pmin(n_use, ceiling(n_star - 1e-9))
    }
    n_use <- pmax(n_use, 1)
    out$inst <- if (p$rep_code == 1L) inst_loan_annuity(b, i_new / st$ppy, n_use) else b / n_use
  } else if (identical(rule, "keep_tilg_rate") && p$rep_code == 1L) {
    out$inst <- b * (i_new + p$tau2) / st$ppy
    out$tau <- p$tau2
  } else if (identical(rule, "keep_payment") && p$rep_code == 1L) {
    neg <- inst <= b * i_new / st$ppy
    out$warn <- any(neg & !st$neg_amort)
    out$neg_amort <- st$neg_amort | neg
    return(out)
  } else {
    return(out)
  }
  if (isTRUE(p$round)) out$inst <- inst_loan_round(out$inst)
  out
}

#' Rate nach Tilgungszuschuss mit reduce_installment (recalc)
#' @param m Monat (Ende der Periode der Gutschrift).
#' @noRd
inst_loan_recalc <- function(st, b, inst, i_pa, m) {
  p <- st$par
  n_rem <- inst_loan_n_rem(st, m)
  out <- inst
  if (p$rep_code == 1L) {
    if (p$has_tau) {
      out <- b * (i_pa + st$tau) / st$ppy
    } else if (is.finite(n_rem)) {
      out <- inst_loan_annuity(b, i_pa / st$ppy, max(n_rem, 1))
    }
  } else if (p$rep_code == 2L && is.finite(n_rem)) {
    out <- b / max(n_rem, 1)
  }
  if (isTRUE(p$round) && p$rep_code != 3L) out <- inst_loan_round(out)
  out
}

# ---------------------------------------------------------------------------------------------
# step(), capacity(), prepay() (Spec 00 8.4, 8.5)
# ---------------------------------------------------------------------------------------------

#' Monatsuhr einer Periode (Spec 00 8.5 Schritte (a)-(g))
#' @return Liste mit Zustand und Periodensummen `Z`, `R`, `RB`, `P`.
#' @noRd
inst_loan_months <- function(st, ev, t, ctx) {
  p <- st$par
  n <- length(st$B)
  zero <- rep(0, n)
  z_sum <- r_sum <- rb_sum <- zero
  b <- st$B
  i_pa <- st$i_pa
  accrued <- st$accrued
  inst <- st$inst
  rep_code <- p$rep_code
  # Schleife über die Ereignismonate; elementweise Begrenzungen als maskierte Zuweisung
  # (gleichwertig zu pmin/pmax, ohne deren Aufrufaufwand in der innersten Schleife)
  gap <- ev$gap
  run <- ev$run
  for (k in seq_along(ev$m)) {
    if (run[k] != 1L) {
      if (run[k] > 1L) {
        cr <- inst_loan_run_closed(b, inst, i_pa, run[k], st$ppy, st$pay_interval, rep_code)
        b <- cr$b
        z_sum <- z_sum + cr$z
        r_sum <- r_sum + cr$r
        accrued <- zero
      }
      next
    }
    if (gap[k] > 0L) {
      z <- b * i_pa / 12 * gap[k]
      z_sum <- z_sum + z
      accrued <- accrued + z
    }
    if (ev$reset[k]) {
      i_new <- st$followup[, ev$jstar[k]] + p$spread
      if (st$inst_set) {
        st$B <- b
        rf <- inst_loan_refi(st, b, inst, i_pa, i_new, ev$m[k], t)
        inst <- rf$inst
        st$tau <- rf$tau
        st$neg_amort <- rf$neg_amort
        if (rf$warn) {
          ctx$warn(inst_loan_key(p$type, "msg", "neg_amort_run"), id = p$id,
                   share = mean(st$neg_amort))
        }
      }
      i_pa <- i_new
    }
    if (ev$rep[k]) accrued <- zero
    z <- b * i_pa / 12
    z_sum <- z_sum + z
    accrued <- accrued + z
    if (ev$pay[k]) {
      if (!st$inst_set) {
        st$i_pa <- i_pa
        inst <- inst_loan_set_installment(st, b, i_pa)
        st$inst_set <- TRUE
      }
      if (rep_code != 3L) {
        r <- if (rep_code == 1L) inst - accrued else inst + zero
        r[r < 0] <- 0
        over <- r > b
        r[over] <- b[over]
        b <- b - r
        r_sum <- r_sum + r
      }
      accrued <- zero
    }
    if (ev$mat[k]) {
      rb_sum <- rb_sum + b
      b <- zero
    }
  }
  if (ev$tail > 0L) {
    z <- b * i_pa / 12 * ev$tail
    z_sum <- z_sum + z
    accrued <- accrued + z
  }
  p_sum <- zero
  if (ev$n_fee > 0L) {
    p_sum <- p$fee_rate * pmax(st$commitment * st$approved - st$drawn, 0) * ev$n_fee
  }
  if (ev$ytd) st$prepaid_ytd <- zero
  st$B <- b
  st$i_pa <- i_pa
  st$accrued <- accrued
  st$inst <- inst
  list(state = st, Z = z_sum, R = r_sum, RB = rb_sum, P = p_sum)
}

#' Ein Schritt des Automaten (Spec 00 8.5)
#' @param state `vofi_inst_state`.
#' @param t Periode.
#' @param ctx Laufkontext.
#' @return `list(state, flows, memo, stocks)` (n-Vektoren, Vorzeichen 8.4).
#' @noRd
inst_loan_step <- function(state, t, ctx) {
  st <- state
  p <- st$par
  n <- length(st$B)
  j <- t + 1L
  zero <- rep(0, n)
  z_sum <- r_sum <- rb_sum <- p_sum <- zero
  ev <- p$plan[[j]]
  if (!is.null(ev) && !isTRUE(p$inactive)) {
    mo <- inst_loan_months(st, ev, t, ctx)
    st <- mo$state
    z_sum <- mo$Z
    r_sum <- mo$R
    rb_sum <- mo$RB
    p_sum <- mo$P
  }
  # (h) Auszahlung bzw. Übernahme des Bestandsdarlehens
  b <- st$B
  assumed <- zero
  d <- zero
  if (isTRUE(p$existing)) {
    if (t == 0L) {
      b <- st$commitment
      assumed <- st$commitment
    }
  } else if (!isTRUE(p$inactive)) {
    d <- st$draws[, j] * st$approved
    if (!is.na(st$t_first_draw) && t == st$t_first_draw) {
      p_sum <- p_sum + p$fee_share * st$commitment * st$approved
    }
  }
  b <- b + d
  st$drawn <- st$drawn + d
  # (i) geplante Sondertilgung
  stp <- zero
  if (isTRUE(p$has_planned)) {
    stp <- pmax(pmin(st$planned[, j], b, pmax(p$cap_share * st$commitment - st$prepaid_ytd, 0)),
                0)
    b <- b - stp
    st$prepaid_ytd <- st$prepaid_ytd + stp
  }
  # (j) Tilgungszuschuss
  tz <- zero
  if (isTRUE(p$has_tz) && !is.na(st$t_tz) && t == st$t_tz) {
    tz_t <- if (isTRUE(p$tz_by_amount)) st$tz_amount else
      p$tz_share * pmin(st$commitment, st$drawn) * p$tz_approved * (1 - p$tz_cut)
    tz_t <- pmax(tz_t, 0)
    capped <- tz_t > b + vofi_tol$stock_abs & st$approved > 0
    if (any(capped)) {
      ctx$inform(inst_loan_key(p$type, "msg", "grant_capped"), id = p$id, share = mean(capped))
    }
    tz <- pmin(tz_t, b)
    b <- b - tz
    if (identical(p$effect, "reduce_installment") && st$inst_set) {
      st$inst <- inst_loan_recalc(st, b, st$inst, st$i_pa, ctx$grid$month_end[j])
    }
  }
  st$B <- b
  kappa <- p$kappa
  list(
    state = st,
    flows = list(draw = kappa * d, repay = -r_sum, repay_balloon = -rb_sum, prepay = -stp,
                 interest = -z_sum, fees = -p_sum),
    memo = list(repayment_grant = tz, disagio = (1 - kappa) * d, assumed = assumed),
    stocks = list(balance = b)
  )
}

#' Zulässige Sondertilgung (Spec 00 8.4, capacity)
#' @noRd
inst_loan_capacity <- function(state, t, ctx) {
  p <- state$par
  cap_rest <- pmax(p$cap_share * state$commitment - state$prepaid_ytd, 0)
  list(balance = state$B, rate_pa = state$i_pa,
       cap = pmin(cap_rest, state$B) * as.double(isTRUE(p$prepay_allowed)))
}

#' Sondertilgung buchen (Spec 00 8.4, prepay; Ue3 am Periodenende, Wirkung ab t + 1)
#' @noRd
inst_loan_prepay <- function(state, amount, t, ctx) {
  cap <- inst_loan_capacity(state, t, ctx)$cap
  used <- pmin(pmax(as.double(amount), 0), cap)
  state$B <- state$B - used
  state$prepaid_ytd <- state$prepaid_ytd + used
  list(state = state, used = used, flows = list(prepay = -used))
}

# ---------------------------------------------------------------------------------------------
# validate(): Kombinationsregeln und Plausibilitäten (Spec 00 8.2, 8.6, 8.7; Spec 01 Teil A
# 5.2, 5.3, 5.5)
# ---------------------------------------------------------------------------------------------

#' Termine der Spezifikation für die Validierung (Stichtag, Fertigstellung, Horizontende)
#' @return Liste oder `NULL`, wenn der Stichtag fehlt.
#' @noRd
inst_loan_val_dates <- function(scenario) {
  p <- scenario[["project"]] %||% list()
  vd <- p[["valuation_date"]]
  if (utl_is_string(vd)) vd <- as.Date(vd, optional = TRUE)
  if (!inherits(vd, "Date") || length(vd) != 1L || is.na(vd)) return(NULL)
  gr <- scenario[["grid"]] %||% list()
  pm <- gr[["periods_months"]]
  hy <- p[["horizon_years"]]
  months <- if (!is.null(pm) && is.numeric(pm)) {
    sum(pm)
  } else if (is.numeric(hy) && length(hy) == 1L && is.finite(hy)) {
    12 * hy
  } else {
    NA_real_
  }
  cm <- gr[["construction_months"]]
  cm <- if (is.numeric(cm) && length(cm) == 1L && is.finite(cm)) cm else 0
  list(valuation = vd, completion = grid_add_months(vd, cm),
       end = if (is.na(months)) as.Date(NA) else grid_add_months(vd, months))
}

#' Datum eines Terminknotens (Date oder Token `completion`) bzw. `NULL`
#' @noRd
inst_loan_val_date <- function(x, dates) {
  if (inherits(x, "Date") && length(x) == 1L && !is.na(x)) return(x)
  if (identical(x, "completion") && !is.null(dates)) return(dates$completion)
  NULL
}

#' Ziele des stochastischen Overlays (parameters und processes)
#' @noRd
inst_loan_overlay_targets <- function(scenario) {
  sto <- scenario[["stochastic"]] %||% list()
  out <- character(0)
  for (blk in c("parameters", "processes")) {
    for (e in sto[[blk]] %||% list()) {
      if (is.list(e) && utl_is_string(e[["target"]])) out <- c(out, e[["target"]])
    }
  }
  out
}

#' Summe konstanter Elemente eines Zahlungsplans (`NULL`, wenn ein Element keine Konstante ist)
#' @noRd
inst_loan_schedule_sum <- function(node) {
  vals <- lapply(node$amounts %||% list(), inst_loan_const)
  if (length(vals) == 0L || any(vapply(vals, is.null, logical(1)))) return(NULL)
  as.double(unlist(vals))
}

#' Ist der Knoten zeitabhängig (Pfadform)?
#' @noRd
inst_loan_is_path_node <- function(x) {
  is.list(x) && utl_is_string(x$kind) &&
    x$kind %in% c("series_t", "series_year", "points", "schedule", "growth")
}

#' Validierung eines Kredits (Ebene 2/3; Befunde `list(severity, code, path, args)`)
#' @param spec normalisierte Komponente.
#' @param scenario Spezifikation (`vofi_spec`).
#' @param repayment `"annuity"`, `"installment"` oder `"bullet"`.
#' @return Liste von Befunden.
#' @noRd
inst_loan_validate <- function(spec, scenario, repayment) {
  acc <- new.env(parent = emptyenv())
  acc$out <- list()
  type <- inst_loan_type(spec, repayment)
  base <- path_join("financing", spec[["id"]] %||% "?")
  add <- function(severity, section, code, field, ...) {
    acc$out[[length(acc$out) + 1L]] <- list(
      severity = severity, code = inst_loan_key(type, section, code),
      path = if (is.null(field)) base else path_join(base, field),
      args = list(id = spec[["id"]] %||% "?", ...)
    )
  }
  err <- function(code, field, ...) add("error", "errors", code, field, ...)
  wrn <- function(code, field, ...) add("warning", "msg", code, field, ...)
  inf <- function(code, field, ...) add("info", "msg", code, field, ...)
  dates <- inst_loan_val_dates(scenario)
  inst_loan_val_core(spec, repayment, err, wrn, inf)
  inst_loan_val_special(spec, scenario, repayment, dates, err, wrn, inf)
  inst_loan_val_terms(spec, scenario, dates, err, wrn, inf)
  inst_loan_val_grant(spec, scenario, dates, err, wrn, inf)
  acc$out
}

#' Laufzeit, Raten, Zinsanpassung (Spec 00 8.2, 8.6; Spec 01 Teil A 5.2)
#' @noRd
inst_loan_val_core <- function(spec, repayment, err, wrn, inf) {
  cst <- inst_loan_const
  ppy <- spec$payments_per_year %||% 12L
  if (!(length(ppy) == 1L && ppy %in% c(1L, 4L, 12L))) {
    err("ppy", "payments_per_year", value = utl_collapse(format(ppy)))
  }
  amount <- cst(spec$amount_eur)
  if (!is.null(amount) && amount == 0) err("amount_nonpositive", "amount_eur", value = amount)
  for (f in c("term_years", "grace_years", "fixed_years", "followup_fixed_years")) {
    v <- cst(spec[[f]])
    if (!is.null(v) && abs(12 * v - round(12 * v)) > 1e-9) err("months_fraction", f, value = v)
  }
  term <- cst(spec$term_years)
  grace <- cst(spec$grace_years) %||% 0
  has_tau <- identical(repayment, "annuity") && !is.null(spec$initial_repayment_pa)
  has_inst <- !identical(repayment, "bullet") && !is.null(spec$installment_eur)
  if (is.null(spec$term_years) && !(identical(repayment, "annuity") && (has_tau || has_inst))) {
    err("term_missing", "term_years")
  }
  if (!is.null(term) && term <= 0) err("term_nonpositive", "term_years", value = term)
  if (!is.null(term) && term > 0 && grace >= term) {
    err("grace_too_long", "grace_years", value = grace, term = term)
  }
  for (f in c("fixed_years", "followup_fixed_years")) {
    v <- cst(spec[[f]])
    if (!is.null(v) && v <= 0) err("nonpositive", f, field = f, value = v)
  }
  if (has_tau && has_inst) err("tau_with_installment", "initial_repayment_pa")
  if (has_tau && !is.null(spec$term_years)) inf("balloon_at_maturity", "initial_repayment_pa")
  inst <- cst(spec$installment_eur)
  if (!is.null(inst) && inst == 0) err("installment_nonpositive", "installment_eur")
  rate <- cst(spec$rate_pa)
  if (identical(repayment, "annuity") && !is.null(inst) && inst > 0 && !is.null(amount) &&
        !is.null(rate) && inst <= amount * rate / ppy) {
    wrn("negative_amortization", "installment_eur", value = inst)
  }
  if (identical(repayment, "bullet")) return(invisible(NULL))
  rule <- spec$refi_rule %||% (if (has_tau) "keep_tilg_rate" else "keep_term")
  if (identical(repayment, "installment") && identical(rule, "keep_tilg_rate")) {
    err("refi_rule_invalid", "refi_rule", rule = rule)
  }
  if (identical(repayment, "annuity") && identical(rule, "keep_tilg_rate") && !has_tau &&
        is.null(spec$followup_repayment_pa)) {
    err("tau_missing", "refi_rule")
  }
  if (identical(rule, "keep_term") && is.null(spec$term_years) && !is.null(spec$fixed_years)) {
    err("keep_term_needs_term", "refi_rule")
  }
  if (!is.null(spec$followup_repayment_pa) && !identical(rule, "keep_tilg_rate")) {
    wrn("followup_repayment_unused", "followup_repayment_pa")
  }
  invisible(NULL)
}

#' Bestandsdarlehen und auto/topup (Spec 00 8.2, 8.7; Spec 01 Teil A 5.3)
#' @noRd
inst_loan_val_special <- function(spec, scenario, repayment, dates, err, wrn, inf) {
  cst <- inst_loan_const
  a_node <- spec$amount_eur
  auto <- node_is(a_node) && identical(a_node$kind, "auto")
  start <- inst_loan_val_date(spec$start, dates)
  vd <- dates$valuation
  if (isTRUE(spec$existing)) {
    forb <- character(0)
    if (auto) forb <- c(forb, "amount_eur")
    if (!is.null(spec$draw_schedule)) forb <- c(forb, "draw_schedule")
    if (!is.null(spec$fees)) forb <- c(forb, "fees")
    kappa <- cst(spec$payout_rate)
    if (!is.null(spec$payout_rate) && !identical(kappa, 1)) forb <- c(forb, "payout_rate")
    if (!is.null(spec$repayment_grant)) forb <- c(forb, "repayment_grant")
    if ((cst(spec$grace_years) %||% 0) > 0) forb <- c(forb, "grace_years")
    for (f in forb) err("existing_forbidden", f, field = f)
    if (!is.null(start) && !is.null(vd) && start != vd) err("existing_start", "start", date = start)
    if (!identical(repayment, "bullet") && is.null(spec$installment_eur)) {
      inf("existing_installment_missing", "installment_eur")
    }
    ptype <- scenario[["project"]][["project_type"]] %||% ""
    if (utl_is_string(ptype) && (identical(ptype, "neubau") || startsWith(ptype, "erwerb"))) {
      wrn("existing_new_build", "existing")
    }
  }
  if (auto) {
    if (!is.null(spec$draw_schedule)) err("auto_draw_schedule", "draw_schedule")
    if (!is.null(start) && !is.null(vd) && start != vd) err("auto_start", "start", date = start)
  } else {
    used <- vapply(c("auto_buffer_share", "auto_round_eur"), function(f) {
      v <- cst(spec[[f]])
      !is.null(v) && v != 0
    }, logical(1))
    if (any(used)) wrn("auto_params_unused", names(used)[used][1L])
  }
  if (inst_loan_is_path_node(spec$rate_pa) && !(auto && identical(a_node$mode, "topup"))) {
    err("rate_path", "rate_pa")
  }
  rate <- cst(spec$rate_pa)
  if (!is.null(rate) && rate > 0.12) wrn("rate_high", "rate_pa", value = rate)
  kappa <- cst(spec$payout_rate)
  if (!is.null(kappa) && kappa <= 0.9) err("payout_rate_range", "payout_rate", value = kappa)
  rank <- spec$rank
  if (!is.null(rank) && is.numeric(rank) && rank < 1) err("rank_invalid", "rank", value = rank)
  prog <- spec$program
  if (isTRUE(spec$prepay_allowed) && utl_is_string(prog) && grepl("^kfw", tolower(prog))) {
    wrn("prepay_program", "prepay_allowed", program = prog)
  }
  targets <- inst_loan_overlay_targets(scenario)
  if (is.list(a_node) && identical(a_node$kind, "ref") && utl_is_string(a_node$path) &&
        a_node$path %in% targets) {
    wrn("amount_fixed", "amount_eur", target = a_node$path)
  }
  mids <- if (utl_is_string(spec$measure_id)) spec$measure_id else character(0)
  if (utl_is_string(spec$funding_id)) {
    fm <- path_get(scenario, path_join("funding", spec$funding_id, "measures"))
    if (is.character(fm)) mids <- c(mids, fm)
  }
  for (mid in unique(mids)) {
    dpath <- path_join("measures", mid, "delay_months")
    dn <- path_get(scenario, dpath)
    if (dpath %in% targets || (is.list(dn) && identical(dn$kind, "dist"))) {
      wrn("measure_delay", if (utl_is_string(spec$measure_id)) "measure_id" else "funding_id",
          measure = mid)
    }
  }
  invisible(NULL)
}

#' Termine: Start, Auszahlungsplan, Gebühren, Zinsbindung, Sondertilgungen
#' @noRd
inst_loan_val_terms <- function(spec, scenario, dates, err, wrn, inf) {
  cst <- inst_loan_const
  amount <- cst(spec$amount_eur)
  vd <- dates$valuation
  start <- inst_loan_val_date(spec$start, dates) %||% vd
  if (!is.null(start) && !is.null(vd) && start < vd) err("start_before", "start", date = start)
  if (!is.null(start) && !is.null(dates) && !is.na(dates$end) && start > dates$end) {
    inf("start_after_horizon", "start", date = start)
  }
  sched <- spec$draw_schedule
  last_draw <- start
  if (is.list(sched) && identical(sched$kind, "schedule")) {
    vals <- inst_loan_schedule_sum(sched)
    if (!is.null(vals)) {
      s <- sum(vals)
      if (identical(sched$unit, "share")) {
        if (abs(s - 1) > 1e-6) err("draw_share_sum", "draw_schedule", value = s)
      } else if (!is.null(amount)) {
        if (s > amount + 1e-6) {
          err("draws_exceed", "draw_schedule", value = s, amount = amount)
        } else if (s < amount - 1e-6) {
          err("draw_eur_sum", "draw_schedule", value = s, amount = amount)
        }
      }
    }
    if (length(sched$dates) > 0L && inherits(sched$dates, "Date")) {
      if (!is.null(start) && min(sched$dates) < start) {
        err("draw_before_start", "draw_schedule", date = min(sched$dates), start = start)
      }
      last_draw <- max(sched$dates)
    }
  }
  fees <- spec$fees
  if (is_map(fees)) {
    pf <- cst(fees$processing_fee_share)
    if (!is.null(pf) && pf > 0.02) wrn("fee_high", "fees.processing_fee_share", value = pf)
    cf <- cst(fees$commitment_fee_rate_month)
    if (!is.null(cf) && cf > 0.005) {
      wrn("commitment_fee_high", "fees.commitment_fee_rate_month", value = cf)
    }
    cd <- inst_loan_val_date(fees$commitment_date, dates)
    if (!is.null(cd) && ((!is.null(start) && cd > start) || (!is.null(vd) && cd < vd))) {
      err("commitment_date_range", "fees.commitment_date", date = cd)
    }
    if (!is.null(cf) && cf > 0 && is.null(sched) && !is.null(cd) && !is.null(start) &&
          cd < start) {
      inf("commitment_fee_window", "fees.commitment_fee_rate_month")
    }
  }
  inst_loan_val_fixation(spec, scenario, dates, start, last_draw, err, wrn, inf)
  pp <- spec$planned_prepayments
  if (is.list(pp) && identical(pp$kind, "schedule") && !identical(pp$unit, "share")) {
    vals <- inst_loan_schedule_sum(pp)
    if (!is.null(vals) && !is.null(amount)) {
      if (sum(vals) > amount + 1e-6) {
        wrn("prepay_exceeds", "planned_prepayments", value = sum(vals), amount = amount)
      }
      cap <- cst(spec$prepay_cap_share_pa) %||% 1
      if (any(vals > cap * amount + 1e-6)) inf("prepay_capped", "planned_prepayments")
    }
  }
  invisible(NULL)
}

#' Zinsbindung und Anschlusszins (Spec 00 8.6, R-45; Spec 01 Teil A 5.2, 5.5)
#' @noRd
inst_loan_val_fixation <- function(spec, scenario, dates, start, last_draw, err, wrn, inf) {
  cst <- inst_loan_const
  fixed <- cst(spec$fixed_years)
  if (is.null(fixed) || fixed <= 0 || is.null(dates) || is.null(start)) return(invisible(NULL))
  term <- cst(spec$term_years)
  ffix <- cst(spec$followup_fixed_years)
  m_start <- grid_months_between(dates$valuation, start)
  m_a <- grid_months_between(dates$valuation, last_draw %||% start)
  m_mat <- if (is.null(term)) Inf else m_a + round(12 * term)
  m_end <- if (is.na(dates$end)) Inf else grid_months_between(dates$valuation, dates$end)
  m_reset <- m_start + round(12 * fixed)
  if (m_reset > m_end) inf("fixed_after_horizon", "fixed_years", value = fixed)
  fu <- spec$followup_rate_pa
  if (m_reset < m_mat && m_reset < m_end && is.list(fu) && identical(fu$kind, "ref") &&
        identical(fu$path, "market.mortgage_rate") &&
        is.null(path_get(scenario, "market.mortgage_rate"))) {
    err("followup_missing", "followup_rate_pa")
  }
  if (!is.null(ffix) && ffix > 0 && is.finite(m_mat) && m_reset < m_mat) {
    rest <- (m_mat - m_reset) %% round(12 * ffix)
    if (rest > 0) inf("followup_truncated", "followup_fixed_years", value = ffix)
  }
  invisible(NULL)
}

#' Tilgungszuschuss (Spec 00 8.2, 8.6; Spec 01 Teil A 5.2)
#' @noRd
inst_loan_val_grant <- function(spec, scenario, dates, err, wrn, inf) {
  rg <- spec$repayment_grant
  if (!is_map(rg) || length(rg) == 0L) return(invisible(NULL))
  cst <- inst_loan_const
  has_share <- !is.null(rg$share)
  has_amount <- !is.null(rg$amount_eur)
  if (has_share == has_amount) err("grant_share_xor_amount", "repayment_grant")
  if (!utl_is_string(spec$measure_id) && !utl_is_string(spec$funding_id)) {
    err("grant_needs_id", "repayment_grant")
  }
  amount <- cst(spec$amount_eur)
  ga <- cst(rg$amount_eur)
  if (!is.null(ga) && !is.null(amount) && ga > amount + 1e-6) {
    err("grant_exceeds", "repayment_grant.amount_eur", value = ga, amount = amount)
  }
  if (!is.null(rg$date) && !is.null(rg$year)) err("grant_date_year", "repayment_grant.date")
  d <- inst_loan_val_date(rg$date, dates)
  if (is.null(d) && !is.null(rg$year) && is.numeric(rg$year)) {
    d <- as.Date(sprintf("%04d-01-01", as.integer(rg$year)))
  }
  start <- inst_loan_val_date(spec$start, dates) %||% dates$valuation
  if (!is.null(d) && !is.null(start) && d < start) {
    err("grant_before_start", "repayment_grant.date", date = d)
  }
  if (!is.null(d) && !is.null(dates) && !is.na(dates$end) && d > dates$end) {
    inf("grant_after_horizon", "repayment_grant.date", date = d)
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------------------------
# Typdefinition
# ---------------------------------------------------------------------------------------------

#' Typdefinition eines Kredittyps aus dem Kern
#' @param name Registry-Name.
#' @param repayment Tilgungsart.
#' @param example Beispiel in Eingabeform (Vertragstests).
#' @noRd
inst_loan_typedef <- function(name, repayment, example) {
  vofi_type(
    name = name, kind = "instrument", params = inst_loan_params(repayment),
    validate = function(spec, scenario) inst_loan_validate(spec, scenario, repayment),
    rows = c("draw", "repay", "repay_balloon", "prepay", "interest", "fees", "repayment_grant",
             "disagio", "assumed", "balance"),
    domain_reads = "measures",
    init = function(spec, ctx) inst_loan_init(spec, ctx, repayment),
    step = function(state, t, ctx) inst_loan_step(state, t, ctx),
    prepay = function(state, amount, t, ctx) inst_loan_prepay(state, amount, t, ctx),
    capacity = function(state, t, ctx) inst_loan_capacity(state, t, ctx),
    repayment = repayment,
    example = example
  )
}
