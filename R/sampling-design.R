# Design-Läufe (WS-C; Spec 00 Abschnitt 11.11, R-94, R-95, R-114; Spec 01 Teil C 1.3, 4.3).
# smp_design(plan, grid, design) übersetzt eine Designmatrix (eine Zeile je Lauf) in ein
# Ziehungsobjekt im Modus "design" für Tornado, Spider, Break-even und das Set "vorsichtig".
# smp_point_par() liefert die Punktparameter eines Prozesses (mit par$.base für gekoppelte).

#' Punktparameter eines Prozesses des Plans
#'
#' Verteilungsangaben → `point(…, "mean")` (auch in `noise`), ein verbliebenes Token `u0 = base`
#' → x_det − a − b · Startwert der Basis; bei Prozessen mit `linked` zusätzlich
#' `par$.base = list(type, par, rho)` mit Typ, Punktparametern und Schockkorrelation des
#' Basisprozesses (rekursiv, R-114).
#' @param plan `smp_plan`.
#' @param key Prozessschlüssel.
#' @param override benannte Liste einzelner Parameterwerte (Designzeile `<proc>.<param>`).
#' @return Liste der Parameter.
#' @noRd
smp_point_par <- function(plan, key, override = list()) {
  pr <- plan$processes[[key]]
  def <- reg_get("process", pr$type)
  par <- pr$par
  for (nm in names(par)) {
    v <- par[[nm]]
    if (proc_is_dist(v)) {
      par[[nm]] <- proc_dist_mean(v)
    } else if (is.list(v) && !is.null(names(v)) && !(nm %in% c("scenarios", "dist_spec"))) {
      for (f in names(v)) if (proc_is_dist(v[[f]])) par[[nm]][[f]] <- proc_dist_mean(v[[f]])
    }
  }
  for (nm in names(override)) {
    segs <- path_split(nm)
    par <- if (length(segs) == 1L) {
      utl_fill_defaults(par[setdiff(names(par), nm)], stats::setNames(list(override[[nm]]), nm))
    } else {
      path_set(par, nm, override[[nm]])
    }
  }
  if (length(def$linked) > 0L) {
    bk <- pr$linked[[def$linked[1L]]]
    bpar <- smp_point_par(plan, bk)
    rho <- 0
    sh <- plan$correlations$shocks
    if (!is.null(sh) && all(c(key, bk) %in% rownames(sh))) {
      rho <- as.double(plan$corr_pearson$shocks[key, bk])
    }
    par$.base <- list(type = plan$processes[[bk]]$type, par = bpar, rho = rho)
    if (proc_is_token(par[["u0"]])) {
      start <- reg_get("process", plan$processes[[bk]]$type)$expected(bpar, plan$years)[1L]
      par$u0 <- pr$x_det - (par[["a"]] %||% 0) - (par[["b"]] %||% 1) * start
    }
  }
  par
}

#' Design-Ziehungen (Spec 00 11.11)
#'
#' Spalten der Designmatrix: **Zielpfad** (setzt den absoluten Wert des Ziels; eine
#' Overlay-Bindung entfällt in der Zeile), **Overlay-Schlüssel** eines statischen Eintrags (setzt
#' die Ziehung x; `apply` wie in der MC), **Entscheidungsschlüssel** (Zweigwahl 0/1),
#' **Prozessparameter** `<proc>.<param>` (Pfad `expected(par_zeile, years)`) und
#' **Prozessschlüssel** `<proc>` mit p ∈ (0, 1) (Pfad `quantile_path(par, years, p)`). `NA`
#' bedeutet „Basiswert“ (Zielpfad und `replace`: Basisfallwert des Ziels; `multiply`: 1; `add`:
#' 0; Prozess: deterministischer Basispfad). Nicht genannte Ziele behalten ihren Basiswert.
#' Vorrang je Zeile und Ziel: Zielpfad vor Schlüssel; beim Prozess Zielpfad vor `<proc>` vor
#' `<proc>.<param>`.
#' @param plan `smp_plan` der Variante.
#' @param grid `vofi_grid`.
#' @param design Data Frame (eine Zeile je Lauf).
#' @return `vofi_draws` im Modus `"design"`.
#' @noRd
smp_design <- function(plan, grid, design) {
  smp_check_plan(plan)
  if (!is.data.frame(design) || nrow(design) == 0L) {
    vofi_abort("sampling.design_invalid", .class = "vofi_error_input")
  }
  n <- nrow(design)
  cols <- names(design)
  for (cn in cols) {
    if (!is.numeric(design[[cn]]) && !all(is.na(design[[cn]]))) {
      vofi_abort("sampling.design_not_numeric", column = cn, .class = "vofi_error_input")
    }
  }
  cls <- vapply(cols, function(cn) smp_design_class(plan, cn), "")
  st <- plan$static
  proc_targets <- vapply(plan$processes, function(p) p$target, "")
  base_ctx <- smp_design_ctx(plan, grid)
  static <- list()
  decision <- list()
  paths <- list()
  acc <- new.env(parent = emptyenv())
  acc$rows <- list()
  add_target <- function(key, target, kind, apply) {
    acc$rows[[length(acc$rows) + 1L]] <- data.frame(key = key, target = target, kind = kind,
                                                    apply = apply, stringsAsFactors = FALSE)
  }
  # Entscheidungsschlüssel
  for (cn in cols[cls == "decision"]) {
    v <- as.double(design[[cn]])
    tgt <- st$target[st$key == cn]
    b <- smp_base_scalar(base_ctx, tgt, 1)
    v[is.na(v)] <- b
    if (!all(v %in% c(0, 1))) {
      vofi_abort("sampling.design_decision", column = cn, .class = "vofi_error_input")
    }
    decision[[cn]] <- v
    add_target(cn, tgt, "decision", "replace")
  }
  # statische Ziele (Zielpfad und/oder Overlay-Schlüssel)
  path_cols <- cols[cls == "target"]
  key_cols <- cols[cls == "static"]
  key_tg <- stats::setNames(st$target[match(key_cols, st$key)], key_cols)
  all_tg <- utl_sort(unique(c(path_cols[!(path_cols %in% proc_targets)], key_tg)))
  for (tg in all_tg) {
    pc <- if (tg %in% path_cols) design[[tg]] else rep(NA_real_, n)
    kc <- names(key_tg)[key_tg == tg]
    ap <- if (length(kc) > 0L) st$apply[st$key == kc[1L]] else "replace"
    kv <- if (length(kc) > 0L) as.double(design[[kc[1L]]]) else rep(NA_real_, n)
    has_p <- !is.na(pc)
    has_k <- !is.na(kv)
    if (all(has_p)) {
      static[[tg]] <- as.double(pc)
      add_target(tg, tg, "static", "replace")
      next
    }
    if (!any(has_p) && length(kc) > 0L && (ap != "replace" || all(has_k))) {
      kv[!has_k] <- if (ap == "multiply") 1 else 0
      static[[kc[1L]]] <- kv
      add_target(kc[1L], tg, "static", ap)
      next
    }
    b <- smp_value_base(base_ctx, tg)
    if (is.null(b)) {
      vofi_abort("sampling.design_no_base", column = tg, .class = "vofi_error_input")
    }
    b <- matrix(as.double(b), nrow = 1L)
    absval <- function(i) {
      if (has_p[i]) return(rep(pc[i], ncol(b)))
      if (has_k[i]) {
        return(switch(ap, multiply = b[1L, ] * kv[i], add = b[1L, ] + kv[i],
                      rep(kv[i], ncol(b))))
      }
      b[1L, ]
    }
    mat <- t(vapply(seq_len(n), absval, numeric(ncol(b))))
    if (ncol(b) == 1L) mat <- matrix(mat, ncol = 1L)
    # Schlüssel des Eintrags: Zielpfad, wenn eine Zielpfadspalte beteiligt ist, sonst der
    # Overlay-Schlüssel (dann mit absoluten Werten und apply = replace)
    ek <- if (tg %in% path_cols || length(kc) == 0L) tg else kc[1L]
    if (all(apply(mat, 1L, function(r) all(r == r[1L])))) {
      static[[ek]] <- mat[, 1L]
      add_target(ek, tg, "static", "replace")
    } else {
      paths[[ek]] <- if (ncol(mat) == grid$T + 1L) mat else matrix(mat[, 1L], n, grid$T + 1L)
      add_target(ek, tg, "process", "replace")
    }
  }
  # Prozesse
  for (p in utl_sort(names(plan$processes))) {
    pr <- plan$processes[[p]]
    pcol <- if (p %in% cols && cls[[p]] == "process") as.double(design[[p]]) else NULL
    tcol <- if (pr$target %in% cols) as.double(design[[pr$target]]) else NULL
    par_cols <- cols[cls == "process_param" & startsWith(cols, paste0(p, "."))]
    if (is.null(pcol) && is.null(tcol) && length(par_cols) == 0L) next
    if (!is.null(pcol) && any(!is.na(pcol) & (pcol <= 0 | pcol >= 1))) {
      vofi_abort("sampling.design_p_range", column = p, .class = "vofi_error_input")
    }
    def <- reg_get("process", pr$type)
    bpath <- NULL
    mat <- matrix(0, n, grid$T + 1L)
    for (i in seq_len(n)) {
      if (!is.null(tcol) && !is.na(tcol[i])) {
        mat[i, ] <- tcol[i]
        next
      }
      ov <- list()
      for (pc in par_cols) {
        if (!is.na(design[[pc]][i])) ov[[substring(pc, nchar(p) + 2L)]] <- design[[pc]][i]
      }
      if (!is.null(pcol) && !is.na(pcol[i])) {
        q <- def$quantile_path %||% function(par, years, p) rep(NA_real_, length(years))
        a <- q(smp_point_par(plan, p, ov), grid$years, pcol[i])
        if (anyNA(a)) {
          vofi_abort("sampling.design_quantile_unavailable", column = p,
                     .class = "vofi_error_input")
        }
        mat[i, ] <- grid_map_years(grid, matrix(a, nrow = 1L))
      } else if (length(ov) > 0L) {
        a <- def$expected(smp_point_par(plan, p, ov), grid$years)
        mat[i, ] <- grid_map_years(grid, matrix(a, nrow = 1L))
      } else {
        if (is.null(bpath)) {
          bpath <- smp_value_base(base_ctx, pr$target)
          if (is.null(bpath)) {
            vofi_abort("sampling.design_no_base", column = p, .class = "vofi_error_input")
          }
          bpath <- rep_len(as.double(bpath), grid$T + 1L)
        }
        mat[i, ] <- bpath
      }
    }
    paths[[p]] <- mat
    add_target(p, pr$target, "process", "replace")
  }
  targets <- if (length(acc$rows) > 0L) do.call(rbind, acc$rows) else NULL
  new_vofi_draws("design", n = n, sims = seq_len(n), blocks = 1L, block_size = n,
                 static = static, decision = decision, targets = targets, paths = paths,
                 years = grid$years,
                 meta = list(seed = NA_real_, sampling = "design", block_size = n,
                             replicates = 1L, copula = NA_character_, antithetic = FALSE,
                             rng_kind = c("Mersenne-Twister", "Inversion", "Rejection"),
                             repaired = list(parameters = NULL, shocks = NULL),
                             plan_hash = plan$hash, design_columns = cols))
}

#' Art einer Designspalte
#' @return `"decision"`, `"static"`, `"process"`, `"process_param"` oder `"target"`.
#' @noRd
smp_design_class <- function(plan, cn) {
  st <- plan$static
  hit <- match(cn, st$key)
  if (!is.na(hit) && st$source[hit] != "process_param") {
    return(if (st$role[hit] == "decision") "decision" else "static")
  }
  if (cn %in% names(plan$processes)) return("process")
  segs <- path_split(cn)
  if (length(segs) >= 2L && segs[1L] %in% names(plan$processes)) {
    pr <- plan$processes[[segs[1L]]]
    def <- reg_get("process", pr$type)
    if (segs[2L] %in% names(def$params)) return("process_param")
  }
  if (!is.null(plan$spec) && !is.null(path_get(plan$spec, cn))) return("target")
  if (cn %in% st$target) return("target")
  choices <- c(st$key, names(plan$processes))
  vofi_abort("sampling.design_column_unknown", column = cn,
             suggestion = utl_suggest_text(cn, choices), .class = "vofi_error_input")
}

#' Basisfall-Kontext für Design-Läufe (aus der Spezifikation des Plans)
#' @noRd
smp_design_ctx <- function(plan, grid) {
  if (is.null(plan$spec)) return(NULL)
  smp_base_ctx(plan$spec, grid)
}

#' Skalarer Basisfallwert eines Ziels (Spalte 1) bzw. Rückfallwert
#' @noRd
smp_base_scalar <- function(ctx, path, default) {
  if (is.null(ctx) || !utl_is_string(path)) return(default)
  v <- smp_value_base(ctx, path)
  if (is.null(v) || !is.numeric(v)) default else as.double(v)[1L]
}
