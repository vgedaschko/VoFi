# Deutsches Zahlen- und Datumsformat für Anzeigen (Integrator, Spec 00 Abschnitt 2.10).
# Gerechnet wird ohne Rundung; gerundet wird nur hier (Abschnitt 2.13).

#' Zahl im deutschen Format
#'
#' `fmt_num(1234567.891)` ergibt `"1.234.567,89"`; `NA` ergibt `"n. d."`.
#' @param x numerischer Vektor.
#' @param digits Nachkommastellen.
#' @return Zeichenvektor gleicher Länge.
#' @noRd
fmt_num <- function(x, digits = 2) {
  x <- suppressWarnings(as.double(x))
  out <- rep("n. d.", length(x))
  ok <- !is.na(x)
  if (any(ok)) {
    v <- round(x[ok], digits)
    v[v == 0] <- 0                                   # keine negative Null ("-0,00")
    fin <- is.finite(v)
    s <- character(length(v))
    if (any(fin)) {
      s[fin] <- formatC(v[fin], format = "f", digits = digits, big.mark = ".",
                        decimal.mark = ",")
    }
    s[!fin] <- ifelse(v[!fin] > 0, "Inf", "-Inf")
    out[ok] <- s
  }
  out
}

#' Ganze Zahl im deutschen Format (`"1.234.567"`)
#' @param x numerischer Vektor.
#' @return Zeichenvektor.
#' @noRd
fmt_int <- function(x) fmt_num(x, digits = 0)

#' Prozent im deutschen Format (`0.038` ergibt `"3,80 %"`)
#' @param x Anteil (Dezimalzahl).
#' @param digits Nachkommastellen der Prozentzahl.
#' @return Zeichenvektor.
#' @noRd
fmt_pct <- function(x, digits = 2) {
  x <- suppressWarnings(as.double(x))
  out <- fmt_num(100 * x, digits)
  ok <- !is.na(x)
  out[ok] <- paste0(out[ok], " %")
  out
}

#' Eurobetrag im deutschen Format (`"1.234 €"`)
#' @param x Betrag in EUR.
#' @param digits Nachkommastellen.
#' @return Zeichenvektor.
#' @noRd
fmt_eur <- function(x, digits = 0) {
  x <- suppressWarnings(as.double(x))
  out <- fmt_num(x, digits)
  ok <- !is.na(x)
  out[ok] <- paste0(out[ok], " \u20ac")
  enc2utf8(out)
}

#' Datum im deutschen Format (`"25.10.2026"`)
#' @param x `Date` oder ISO-Zeichenkette.
#' @return Zeichenvektor; `NA` ergibt `"n. d."`.
#' @noRd
fmt_date <- function(x) {
  if (!inherits(x, "Date")) x <- as.Date(x, optional = TRUE)
  out <- format(x, "%d.%m.%Y")
  out[is.na(x)] <- "n. d."
  out
}
