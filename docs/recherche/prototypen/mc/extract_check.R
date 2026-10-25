md <- readLines("/home/user/VoFi/docs/recherche/04_monte_carlo.md", encoding = "UTF-8")
st <- grep("^```r$", md); en <- grep("^```$", md)
blocks <- lapply(st, function(s) md[(s + 1):(en[en > s][1] - 1)])
cat("R-Blöcke:", length(blocks), "\n")
ok <- vapply(seq_along(blocks), function(i) { r <- tryCatch({ parse(text = blocks[[i]]); TRUE }, error = function(e) { cat("Block", i, ":", conditionMessage(e), "\n"); FALSE }); r }, logical(1))
cat("syntaktisch ok:", sum(ok), "/", length(ok), "\n")
# Alle Funktionsdefinitionen aus dem Memo in eine frische Umgebung laden (Snippets ohne Definitionen überspringen)
env <- new.env()
for (i in seq_along(blocks)) {
  ex <- parse(text = blocks[[i]])
  for (e in ex) {
    is_def <- is.call(e) && identical(e[[1]], as.name("<-")) && length(e) == 3 &&
      (is.call(e[[3]]) && (identical(e[[3]][[1]], as.name("function")) || identical(e[[3]][[1]], as.name("list"))))
    if (is_def) eval(e, env)
  }
}
cat("Funktionen geladen:", length(ls(env)), "\n")
with(env, {
  sc <- gen_scenarios(10000, 40, 1, "lhs"); k <- vofi_engine(sc, par_default)$kpi
  str(mc_summary(k)[c("p_verlust", "quantil_diff", "cvar", "anteil_rendite_undefiniert")])
  print(se_replicates(k$endwert, 10)); print(quantile_ci(k$endwert, 0.05))
  kB <- vofi_engine(sc, modifyList(par_default, list(invest_base = 2.85e6, saving = 0)))$kpi
  print(unlist(dominance(k$endwert, kB$endwert)))
  base <- gen_scenarios(1, 40, 1, degenerate = TRUE)
  kt <- vofi_engine(tornado_scenarios(base, list(cost_factor = c(0.98, 1.22), delay_m = c(0.5, 7))), par_default)$kpi
  print(kt$endwert_diff - kt$endwert_diff[1])
  print(break_even("cost_factor", c(0.8, 3), base = base, par = par_default))
  print(break_even("cost_factor", c(0.8, 1.2), base = base, par = par_default))
  X <- cbind(baukosten = sc$cost_factor, verzug = sc$delay_m, zins_T = sc$rate[, 40])
  print(round(src(X, k$endwert_diff)$coef, 3)); print(round(prcc(X, k$endwert_diff), 3))
  print(round(sapply(as.data.frame(X), first_order_binned, y = k$endwert_diff), 3))
  spec <- read_stochastic_spec("spec.yaml"); s <- sample_stochastic(spec, n = 2000); print(class(s)); print(names(s$paths))
  print(vofi_rendite(cbind(c(100, 100), 0, c(0, 50), 0, 0), c(150, 220)))
  cv <- mc_convergence(k$endwert); print(tail(cv, 1))
})
