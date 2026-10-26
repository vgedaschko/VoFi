# Testhelfer des Samplers (WS-C). Bauen Spezifikationen mit Stochastik-Overlay ohne den
# Szenario-Leser (WS-A): Grundlage ist die Prüfkit-Spezifikation reg_test_spec() (Integrator).

#' Verteilungs- bzw. Prozessdefinition aus der Registry
wsc_dist <- function(name) reg_get("distribution", name)
wsc_proc <- function(name) reg_get("process", name)

#' Spezifikation mit Stochastik-Overlay
#'
#' `stochastic`: Liste mit `settings`, `parameters`, `processes`, `correlations` (Rohform wie in
#' YAML nach dem Einlesen). `market`, `shared`, `funding`: Ergänzungen der Prüfkit-Spezifikation
#' (Zahlen werden zu Knoten).
wsc_spec <- function(stochastic = list(), grid = make_grid(), market = list(), shared = list(),
                     funding = list(), provenance = NULL) {
  spec <- reg_test_spec(grid, market = deep_merge(reg_test_market_raw(), market))
  for (nm in names(shared)) spec$shared[[nm]] <- reg_node(shared[[nm]], paste0("shared.", nm))
  if (length(funding) > 0L) {
    for (f in names(funding)) {
      fe <- funding[[f]]
      for (fld in names(fe)) {
        if (is.numeric(fe[[fld]])) {
          fe[[fld]] <- reg_node(fe[[fld]], paste("funding", f, fld, sep = "."))
        }
      }
      spec$funding[[f]] <- fe
    }
  }
  spec$stochastic <- stochastic
  if (!is.null(provenance)) attr(spec, "provenance") <- provenance
  spec
}

#' Plan einer Spezifikation mit gesetzten Laufeinstellungen
wsc_plan <- function(stochastic, grid = make_grid(), ..., n_sim = NULL, block_size = NULL,
                     seed = NULL) {
  plan <- smp_plan(wsc_spec(stochastic, grid, ...), grid)
  smp_configure(plan, n_sim = n_sim, block_size = block_size, seed = seed)
}

#' Ziehungen für n_sim Läufe
wsc_draw <- function(stochastic, n_sim, block_size = 200L, seed = 20261025, grid = make_grid(),
                     ...) {
  plan <- wsc_plan(stochastic, grid, ..., n_sim = n_sim, block_size = block_size)
  smp_draw(plan, grid, smp_blocks(plan, n_sim), seed)
}

#' Statischer Overlay-Eintrag
wsc_par <- function(target, dist, ...) c(list(target = target, dist = dist), list(...))

#' Vergleich mit gerundeten Prüfwerten der Spezifikation
#'
#' `expected` als Zeichenketten wie in der Spec (Dezimalkomma oder -punkt, z. B. "0,027665271"):
#' zulässig ist die Rundungsabweichung der angegebenen letzten Stelle, |x − e| ≤ slack · 0,5 ·
#' 10^(−Nachkommastellen) (slack = 2 erlaubt eine Einheit der letzten Stelle, z. B. bei
#' Prüfwerten aus numerischer Integration).
expect_spec <- function(actual, expected, slack = 1.0001) {
  s <- gsub(",", ".", gsub("[[:space:]]", "", expected), fixed = TRUE)
  e <- as.double(s)
  dec <- ifelse(grepl(".", s, fixed = TRUE), nchar(sub("^[^.]*[.]", "", s)), 0L)
  tol <- slack * 0.5 * 10^(-dec) + 1e-13 * abs(e)
  a <- as.double(actual)
  ok <- length(a) == length(e) && all(is.finite(a)) && all(abs(a - e) <= tol)
  testthat::expect(ok, paste0("Abweichung vom Pr\u00fcfwert: actual = ",
                              paste(format(a, digits = 12), collapse = " "), "; expected = ",
                              paste(expected, collapse = " ")))
  invisible(actual)
}

#' Empirisches p-Quantil einer Stichprobe gegen einen Quantilwert (wie P4 des Prüfkits)
#'
#' Zulässig, wenn p in [P(X < q) − 4 SE, P(X ≤ q) + 4 SE] liegt (SE = √(p(1 − p)/n)); damit
#' sind auch Punktmassen abgedeckt.
expect_quantile_near <- function(x, q, p, info = NULL) {
  n <- length(x)
  se <- sqrt(p * (1 - p) / n)
  tol <- 1e-9 * max(1, abs(q))
  lo <- mean(x < q - tol)
  hi <- mean(x <= q + tol)
  ok <- is.finite(q) && p >= lo - 4 * se && p <= hi + 4 * se
  testthat::expect(ok, paste0("p = ", p, ": q = ", format(q, digits = 10), ", P(X < q) = ", lo,
                              ", P(X <= q) = ", hi, if (!is.null(info)) paste0(" (", info, ")")))
  invisible(ok)
}
