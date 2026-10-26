# Basiszahlen der Ziehungen (WS-C; Spec 00 Abschnitte 11.3, 11.5, 11.12; Spec 01 Teil C 1.10).
# Alle Zufallszahlen entstehen in benannten Strömen je Schlüssel und Block über with_stream()
# (R/utils-seed.R, Integrator): par:<key>:<b>, shock:<proc>:<b>, scen:<proc>:<b>,
# uni:<proc>:<b>, ic:<key>:<b>. Die Ziehungen eines Blocks hängen nur von Seed, Schlüssel,
# Blockgröße m und Blockindex b ab (nicht von n_sim, R-73).

#' Name eines Zufallsstroms
#'
#' `"<prefix>:<key>:<b>"` mit dem globalen Blockindex b dezimal ohne führende Nullen.
#' @param prefix `"par"`, `"shock"`, `"scen"`, `"uni"` oder `"ic"`.
#' @param key Schlüssel.
#' @param b Blockindex (ganze Zahl ≥ 1).
#' @return Zeichenkette.
#' @noRd
smp_stream_name <- function(prefix, key, b) {
  paste0(prefix, ":", key, ":", format(as.integer(b), scientific = FALSE, trim = TRUE))
}

#' LHS-Uniforms eines Blocks im laufenden Strom: (sample.int(m) − runif(m))/m
#'
#' Erst `sample.int()`, dann `runif()` (Spec 00 11.5); jede der m Schichten ((k − 1)/m, k/m]
#' enthält genau einen Wert. Nur innerhalb von `with_stream()` aufrufen.
#' @noRd
smp_lhs_column <- function(m) (sample.int(m) - stats::runif(m)) / m

#' Uniforms eines Blocks (statische Größe bzw. Szenarioindex)
#'
#' `lhs`: `(sample.int(m) − runif(m))/m`; `pseudo`: `runif(m)`; `antithetic` (nur `pseudo`, m
#' gerade): `v <- runif(m/2); c(v, 1 − v)`.
#' @param seed Seed.
#' @param name Stromname.
#' @param m Blockgröße.
#' @param sampling `"lhs"` oder `"pseudo"`.
#' @param antithetic antithetische Variablen.
#' @return double m-Vektor in (0, 1).
#' @noRd
smp_uniforms <- function(seed, name, m, sampling = "lhs", antithetic = FALSE) {
  with_stream(seed, name, {
    if (identical(sampling, "lhs")) {
      smp_lhs_column(m)
    } else if (isTRUE(antithetic)) {
      v <- stats::runif(m %/% 2L)
      c(v, 1 - v)
    } else {
      stats::runif(m)
    }
  })
}

#' Uniform-Matrix eines Blocks mit k Spalten aus einem Strom (Spalte für Spalte)
#' @return Matrix m × k.
#' @noRd
smp_uniform_matrix <- function(seed, name, m, k, sampling = "lhs", antithetic = FALSE) {
  with_stream(seed, name, {
    out <- matrix(0, m, k)
    for (j in seq_len(k)) {
      out[, j] <- if (identical(sampling, "lhs")) {
        smp_lhs_column(m)
      } else if (isTRUE(antithetic)) {
        v <- stats::runif(m %/% 2L)
        c(v, 1 - v)
      } else {
        stats::runif(m)
      }
    }
    out
  })
}

#' Standardnormal-Schocks eines Blocks (Spalte für Spalte, Spec 00 11.5)
#'
#' `lhs`: je Spalte `qnorm((sample.int(m) − runif(m))/m)`; `pseudo`: `rnorm(m)`; `antithetic`:
#' je Spalte `w <- rnorm(m/2); c(w, −w)` (entspricht `rbind(W, −W)`). Spaltenweise Erzeugung:
#' mehr Jahre verändern die früheren Spalten nicht (CRN bei anderem Horizont).
#' @param seed Seed.
#' @param name Stromname `shock:<proc>:<b>`.
#' @param m Blockgröße.
#' @param k Anzahl Spalten (Jahre − 1).
#' @return Matrix m × k.
#' @noRd
smp_shocks <- function(seed, name, m, k, sampling = "lhs", antithetic = FALSE) {
  if (k <= 0L) return(matrix(0, m, 0L))
  with_stream(seed, name, {
    out <- matrix(0, m, k)
    if (identical(sampling, "lhs")) {
      # Uniforms Spalte für Spalte im Strom, danach eine vektorisierte Transformation
      for (j in seq_len(k)) out[, j] <- sample.int(m) - stats::runif(m)
      out <- stats::qnorm(out / m)
    } else if (isTRUE(antithetic)) {
      h <- m %/% 2L
      for (j in seq_len(k)) {
        w <- stats::rnorm(h)
        out[, j] <- c(w, -w)
      }
    } else {
      for (j in seq_len(k)) out[, j] <- stats::rnorm(m)
    }
    out
  })
}

#' Iman-Conover-Scores eines Schlüssels in Block b
#'
#' Scores a_i = Φ⁻¹(i/(m + 1)), i = 1…m (van der Waerden), unabhängig permutiert im Strom
#' `ic:<key>:<b>` (`sample(a)`). Ist cor(S) des Blocks singulär (bei kleinen Blöcken mit
#' m nahe d + 1 möglich), permutiert `smp_ic_block_scores()` neu: Versuch k ≥ 1 im Unterstrom
#' `ic:<key>:<b>:<k>`.
#' @param retry Nummer des Versuchs (0 = Strom nach Spec 00 11.3).
#' @return double m-Vektor.
#' @noRd
smp_ic_scores <- function(seed, key, b, m, retry = 0L) {
  a <- stats::qnorm(seq_len(m) / (m + 1))
  name <- smp_stream_name("ic", key, b)
  if (retry > 0L) name <- paste0(name, ":", format(as.integer(retry), trim = TRUE))
  with_stream(seed, name, sample(a))
}

#' Score-Matrix eines Blocks mit regulärer Korrelationsmatrix
#'
#' Spalten in der Ordnung `keys` aus `smp_ic_scores()`; ist cor(S) singulär
#' (`smp_ic_chol()` liefert `NULL`), folgen deterministisch weitere Versuche aus den
#' Unterströmen `ic:<key>:<b>:<k>` (k = 1, 2, …, höchstens `max_retry`). Die Ziehungen hängen
#' damit weiter nur von Seed, Schlüsseln, m und b ab.
#' @return Matrix m × d (Attribute `retry` = Anzahl der Neupermutationen, `chol` = oberer
#'   Cholesky-Faktor von cor(S) bzw. `NULL`).
#' @noRd
smp_ic_block_scores <- function(seed, keys, b, m, max_retry = 50L) {
  draw <- function(k) {
    sc <- vapply(keys, function(key) smp_ic_scores(seed, key, b, m, k), numeric(m))
    if (!is.matrix(sc)) sc <- matrix(sc, nrow = m)
    sc
  }
  k <- 0L
  sc <- draw(k)
  q <- smp_ic_chol(sc)
  while (is.null(q) && k < max_retry) {
    k <- k + 1L
    sc <- draw(k)
    q <- smp_ic_chol(sc)
  }
  attr(sc, "retry") <- k
  attr(sc, "chol") <- q
  sc
}

#' Globale Laufnummern der Blöcke
#' @param blocks globale Blockindizes.
#' @param m Blockgröße.
#' @return integer-Vektor der Läufe (Block für Block).
#' @noRd
smp_sims_of <- function(blocks, m) {
  as.integer(unlist(lapply(as.integer(blocks), function(b) (b - 1L) * m + seq_len(m)),
                    use.names = FALSE))
}

#' Block eines globalen Laufs: b = ⌈i/m⌉
#' @noRd
smp_block_of <- function(i, m) as.integer((as.integer(i) - 1L) %/% as.integer(m) + 1L)
