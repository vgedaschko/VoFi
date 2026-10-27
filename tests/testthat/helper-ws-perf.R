# Hilfsfunktionen der Leistungstests und der Gleichheitstests der schnellen Wege (WS-PERF,
# Spec 00 Abschnitt 9.10).

#' Vorgegebene Ziehungen für einen Chunk ohne Sampler (statische Größen und Prozesspfade)
#'
#' Wie bench/bench_engine.R: Miete und KfW-Zins je Lauf verschieden, Anschlusszins und
#' Mietwachstum als Pfade. Mit `uniform = TRUE` sind alle Läufe gleich (zeilengleiche Wege).
#' @param model `vofi_model` aus `wsd_bench_scenario()`.
#' @param n Läufe.
#' @param uniform alle Läufe gleich.
wsp_draws <- function(model, n, uniform = FALSE) {
  g <- model$grid
  u <- if (uniform) rep(0.5, n) else (seq_len(n) - 0.5) / n
  st <- list("components.rent.amount_eur" = 185000 * (0.85 + 0.3 * u),
             "financing.kfw.rate_pa" = 0.015 + 0.01 * u)
  pa <- list("market.mortgage_rate" = matrix(0.03 + 0.03 * u, n, g$T + 1L),
             "market.rent_growth" = matrix(0.005 + 0.02 * rev(u), n, g$T + 1L))
  keys <- c(names(st), names(pa))
  targets <- data.frame(key = keys, target = keys,
                        kind = c(rep("static", length(st)), rep("process", length(pa))),
                        apply = "replace", stringsAsFactors = FALSE)
  new_vofi_draws("mc", n = n, sims = seq_len(n), blocks = seq_len(max(1L, n %/% 200L)),
                 block_size = min(n, 200L), static = st, paths = pa, targets = targets,
                 years = g$years)
}

#' Werte zweier Läufe vergleichen: identisch bis auf das Vorzeichen der Null
#'
#' `identical()` behandelt 0 und -0 als gleich; Attribute und Typen müssen übereinstimmen.
#' @param a,b Listen von Matrizen bzw. Vektoren (gleiche Namen).
wsp_expect_same <- function(a, b, info = NULL) {
  expect_identical(names(a), names(b), info = info)
  for (k in names(a)) expect_identical(a[[k]], b[[k]], info = paste(info, k))
}

#' Ergebnis eines Chunks auf die verglichenen Teile reduziert
wsp_chunk_parts <- function(res) {
  list(kpis = res$kpis, kpi_na = res$kpi_na, flags = res$flags, checks = res$checks,
       band_values = res$band_values, opp_checks = res$opp$checks)
}
