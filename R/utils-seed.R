# Benannte Zufallsströme (Integrator, Spec 00 Abschnitt 11.3 und 11.12).
# with_stream() ist der EINZIGE Ort, an dem das Paket den RNG-Zustand verändert; der Zustand des
# Nutzers (.Random.seed und RNGkind()) wird danach immer wiederhergestellt.

#' Polynom-Hash eines Stromnamens (exakt in double, Abschnitt 11.3)
#' @param name Stromname, z. B. `"par:huelle_kosten:3"`.
#' @return double in `[0, 2147483646]`.
#' @noRd
stream_hash <- function(name) {
  h <- 0
  for (code in utf8ToInt(enc2utf8(name))) h <- (h * 131 + code) %% 2147483647
  h
}

#' Seed eines benannten Stroms (Abschnitt 11.3)
#' @param seed ganze Zahl in `[1, 2^31 - 2]`.
#' @param name Stromname.
#' @return double, ganzzahlig, in `[0, 2147483646]`.
#' @noRd
stream_seed <- function(seed, name) {
  seed <- utl_check_seed(seed)
  (seed * 1000003 + stream_hash(name)) %% 2147483647
}

#' Seed prüfen
#' @param seed Eingabe.
#' @return double (ganzzahlig) oder Fehler `vofi_error_input`.
#' @noRd
utl_check_seed <- function(seed) {
  if (!utl_is_whole(seed) || seed < 1 || seed > 2147483646) {
    vofi_abort("core.seed_invalid", seed = utl_collapse(format(seed)),
               .class = "vofi_error_input")
  }
  as.double(round(seed))
}

#' Ausdruck in einem benannten Zufallsstrom auswerten
#'
#' Setzt `set.seed(stream_seed(seed, name), kind = "Mersenne-Twister", normal.kind = "Inversion",
#' sample.kind = "Rejection")`, wertet `expr` aus und stellt `.Random.seed` sowie `RNGkind()`
#' des Nutzers wieder her (auch im Fehlerfall).
#' @param seed ganze Zahl in `[1, 2^31 - 2]`.
#' @param name Stromname.
#' @param expr auszuwertender Ausdruck.
#' @return Wert von `expr`.
#' @noRd
with_stream <- function(seed, name, expr) {
  s <- stream_seed(seed, name)
  genv <- globalenv()
  old_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = genv, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = genv, inherits = FALSE) else NULL
  on.exit({
    suppressWarnings(RNGkind(kind = old_kind[1L], normal.kind = old_kind[2L],
                             sample.kind = old_kind[3L]))
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = genv)
    } else if (exists(".Random.seed", envir = genv, inherits = FALSE)) {
      rm(".Random.seed", envir = genv)
    }
  }, add = TRUE)
  set.seed(as.integer(s), kind = "Mersenne-Twister", normal.kind = "Inversion",
           sample.kind = "Rejection")
  force(expr)
}
