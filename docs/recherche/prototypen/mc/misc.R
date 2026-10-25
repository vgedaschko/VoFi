vec_bisect <- function(f, lo, hi, iter = 50) {        # f: Vektor -> Vektor, monoton steigend
  for (k in seq_len(iter)) { mid <- (lo + hi) / 2; up <- f(mid) > 0; hi[up] <- mid[up]; lo[!up] <- mid[!up] }
  (lo + hi) / 2
}
# VoFi-Rendite bei mehreren EK-Zuführungen: sum_t EK[,t] (1+r)^(T-t) = EW  (Newton, vektorisiert)
vofi_rendite <- function(EK, EW, iter = 30, r0 = 0.05) {   # EK: N x (T+1), Spalte 1 = t0
  T <- ncol(EK) - 1; e <- T - (0:T); r <- rep(r0, nrow(EK)); ok <- EW > 0 & rowSums(EK) > 0
  for (k in seq_len(iter)) {
    q <- outer(1 + r, e, "^"); f <- rowSums(EK * q) - EW
    df <- rowSums(EK * sweep(q, 2, e, "*") / (1 + r))
    r <- pmax(r - f / df, -0.99)
  }
  ifelse(ok, r, NA_real_)
}
EK <- cbind(c(100, 100, 50), 0, c(0, 50, 50), 0, 0); EW <- c(150, 220, 0)
r <- vofi_rendite(EK, EW); print(r)
print(c((150/100)^(1/4) - 1)); print(100*(1+r[2])^4 + 50*(1+r[2])^2)
print(vec_bisect(function(x) x^2 - c(2, 9, 16), rep(0, 3), rep(10, 3)))
