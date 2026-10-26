# Sichere, vektorisierte Ausdruecke der Wertgrammatik (WS-B, Spec 00 Abschnitt 4.5 Regel 5).
# Phase-0-Minimalfassung, Eigentuemer: WS-B. Umgesetzt: Parser mit Whitelist ueber den
# R-Parser (keine Auswertung beliebigen Codes), Pfadsymbole (mit Punkt), Formregel
# (Laenge 1 -> n-Vektor; n-Vektor -> n x (T+1), sobald ein Operand zeitabhaengig ist), Codes
# und Wahrheitswerte nur in ==, !=, %in%, !, &, | (R-91, Phase-0-Nacharbeit P0-10).
# Offen fuer WS-B: Fehlerposition (Zeile/Spalte) in den Meldungen, Pruefung "nur endliche
# Zweige" mit eigener Meldung je Zweig, Abhaengigkeitsgraph/Zyklen in der Validierung.

#' Zulässige Funktionen und Operatoren (4.5 Regel 5)
#' @noRd
expr_whitelist <- function() {
  c("+", "-", "*", "/", "^", "%%", "(", "<", "<=", ">", ">=", "==", "!=", "&", "|", "!",
    "ifelse", "pmin", "pmax", "abs", "round", "floor", "ceiling", "sqrt", "exp", "log",
    "is.na", "%in%", "c")
}

#' Ausdruck parsen und gegen die Whitelist prüfen
#'
#' Phase-0-Minimalfassung, Eigentümer: WS-B.
#' @param text Zeichenkette, z. B. `"building.living_area_m2 * 150"`.
#' @return Objekt der Klasse `vofi_expr` (`text`, `call`, `symbols`); Syntaxfehler und nicht
#'   zugelassene Funktionen sind `vofi_error_input`.
#' @noRd
expr_parse <- function(text) {
  if (!utl_is_string(text) || !nzchar(trimws(text))) {
    vofi_abort("validation.expr.syntax", text = as.character(text %||% "")[1L], detail = "",
               .class = "vofi_error_input")
  }
  parsed <- tryCatch(parse(text = text, keep.source = FALSE), error = function(e) e)
  if (inherits(parsed, "error") || length(parsed) != 1L) {
    detail <- if (inherits(parsed, "error")) conditionMessage(parsed) else ""
    vofi_abort("validation.expr.syntax", text = text, detail = detail,
               .class = "vofi_error_input")
  }
  call <- parsed[[1L]]
  expr_check(call, text)
  structure(list(text = text, call = call, symbols = expr_collect_symbols(call)),
            class = "vofi_expr")
}

#' AST rekursiv gegen die Whitelist prüfen
#' @noRd
expr_check <- function(e, text) {
  if (is.numeric(e) || is.character(e) || is.logical(e)) return(invisible(TRUE))
  if (is.symbol(e)) {
    s <- as.character(e)
    if (s %in% c("TRUE", "FALSE")) return(invisible(TRUE))
    if (!grepl(".", s, fixed = TRUE)) {
      vofi_abort("validation.expr.symbol", text = text, symbol = s, .class = "vofi_error_input")
    }
    return(invisible(TRUE))
  }
  if (is.call(e)) {
    fn <- e[[1L]]
    name <- if (is.symbol(fn)) as.character(fn) else ""
    if (!(name %in% expr_whitelist())) {
      hint <- switch(name, min = "pmin", max = "pmax", "&&" = "&", "||" = "|", "")
      vofi_abort("validation.expr.function", text = text, fun = name, hint = hint,
                 .class = "vofi_error_input")
    }
    if (identical(name, "ifelse") && length(e) != 4L) {
      vofi_abort("validation.expr.ifelse", text = text, .class = "vofi_error_input")
    }
    for (a in as.list(e)[-1L]) expr_check(a, text)
    return(invisible(TRUE))
  }
  vofi_abort("validation.expr.syntax", text = text, detail = "", .class = "vofi_error_input")
}

#' Pfadsymbole eines Aufrufs sammeln
#' @noRd
expr_collect_symbols <- function(e) {
  if (is.symbol(e)) {
    s <- as.character(e)
    return(if (grepl(".", s, fixed = TRUE)) s else character(0))
  }
  if (is.call(e)) {
    return(unique(unlist(lapply(as.list(e)[-1L], expr_collect_symbols), use.names = FALSE)))
  }
  character(0)
}

#' Alle Pfadsymbole eines Ausdrucks (Abhängigkeiten, Zyklusprüfung)
#' @param ast Objekt der Klasse `vofi_expr`.
#' @return Zeichenvektor.
#' @noRd
expr_symbols <- function(ast) {
  if (!inherits(ast, "vofi_expr")) ast <- expr_parse(ast$text %||% ast)
  ast$symbols %||% character(0)
}

#' Ausdruck vektorisiert auswerten (Formregel 4.5 Regel 5)
#'
#' Phase-0-Minimalfassung, Eigentümer: WS-B.
#' @param ast Objekt der Klasse `vofi_expr`.
#' @param resolve `function(path)` -> Skalar, n-Vektor, n x (T+1); bei nicht-numerischen
#'   Blaettern Codes (`character`) bzw. Wahrheitswerte (`logical`, setting-Semantik, R-91).
#' @param n Anzahl der Läufe.
#' @param T letzter Periodenindex.
#' @return double n-Vektor oder n x (T+1).
#' @noRd
expr_eval <- function(ast, resolve, n, T) { # nolint: object_name_linter. T wie Spec 00 4.5.
  if (!inherits(ast, "vofi_expr")) ast <- expr_parse(ast)
  big_t <- T # nolint: object_name_linter, T_and_F_symbol_linter. T ist der Periodenindex.
  out <- expr_eval_node(ast$call, resolve, as.integer(n), as.integer(big_t), ast$text)
  if (is.character(out)) {
    vofi_abort("validation.expr.not_numeric", text = ast$text, .class = "vofi_error_input")
  }
  if (is.logical(out)) {
    vofi_abort("validation.expr.code_operand", text = ast$text, fun = "",
               .class = "vofi_error_input")
  }
  out <- expr_shape(out, n, big_t)
  storage.mode(out) <- "double"
  out
}

#' Operand auf die gemeinsame Form heben
#' @noRd
expr_shape <- function(x, n, big_t, to_path = FALSE) {
  if (is.character(x)) return(x)
  if (is.logical(x)) x <- as.double(x)
  if (is.matrix(x)) return(x)
  x <- as.double(x)
  if (length(x) == 1L) x <- rep_len(x, n)
  if (length(x) != n) {
    vofi_abort("core.contract.length", what = "expr", expected = n, actual = length(x),
               .class = "vofi_error_contract")
  }
  if (to_path) matrix(x, nrow = n, ncol = big_t + 1L) else x
}

#' Operanden angleichen (Formregel)
#' @noRd
expr_align <- function(args, n, big_t) {
  num <- !vapply(args, is.character, logical(1))
  any_path <- any(vapply(args[num], is.matrix, logical(1)))
  args[num] <- lapply(args[num], expr_shape, n = n, big_t = big_t, to_path = any_path)
  args
}

#' Nicht-numerische Operanden pruefen (4.5 Regel 5, R-91)
#'
#' Codes (`character`) und Wahrheitswerte (`logical`, Blaetter mit `setting`-Semantik) sind nur
#' in `==`, `!=`, `%in%`, `!`, `&`, `|` zulaessig (Codes nur in Vergleichen); das Ergebnis ist
#' 0/1. Jede andere Verwendung ist `vofi_error_input`.
#' @noRd
expr_check_operands <- function(args, name, text) {
  chr <- any(vapply(args, is.character, logical(1)))
  lgl <- any(vapply(args, is.logical, logical(1)))
  if ((chr && !(name %in% c("==", "!="))) ||
      (lgl && !(name %in% c("==", "!=", "!", "&", "|")))) {
    vofi_abort("validation.expr.code_operand", text = text, fun = name,
               .class = "vofi_error_input")
  }
  invisible(TRUE)
}

#' Rekursive Auswertung
#' @noRd
expr_eval_node <- function(e, resolve, n, big_t, text) {
  if (is.numeric(e) || is.logical(e)) return(as.double(e))
  if (is.character(e)) return(e)
  if (is.symbol(e)) {
    s <- as.character(e)
    if (s == "TRUE") return(1)
    if (s == "FALSE") return(0)
    v <- resolve(s)
    if (is.null(v)) {
      vofi_abort("validation.expr.path_missing", text = text, symbol = s,
                 .class = "vofi_error_input")
    }
    return(v)
  }
  name <- as.character(e[[1L]])
  args <- lapply(as.list(e)[-1L], expr_eval_node, resolve = resolve, n = n, big_t = big_t,
                 text = text)
  if (name %in% c("%in%", "c")) {
    if (identical(name, "c")) return(unlist(args))
    res <- as.double(args[[1L]] %in% args[[2L]])
    # Form des ersten Operanden erhalten (Pfad n x (T+1) bzw. n-Vektor)
    if (is.matrix(args[[1L]])) dim(res) <- dim(args[[1L]])
    return(res)
  }
  if (identical(name, "(")) return(args[[1L]])
  expr_check_operands(args, name, text)
  args <- expr_align(args, n, big_t)
  keep_dim <- function(res, like) {
    if (is.matrix(like) && !is.matrix(res)) dim(res) <- dim(like)
    res
  }
  res <- switch(name,
    "+" = if (length(args) == 1L) args[[1L]] else args[[1L]] + args[[2L]],
    "-" = if (length(args) == 1L) -args[[1L]] else args[[1L]] - args[[2L]],
    "*" = args[[1L]] * args[[2L]],
    "/" = args[[1L]] / args[[2L]],
    "^" = args[[1L]]^args[[2L]],
    "%%" = args[[1L]] %% args[[2L]],
    "<" = as.double(args[[1L]] < args[[2L]]),
    "<=" = as.double(args[[1L]] <= args[[2L]]),
    ">" = as.double(args[[1L]] > args[[2L]]),
    ">=" = as.double(args[[1L]] >= args[[2L]]),
    "==" = as.double(args[[1L]] == args[[2L]]),
    "!=" = as.double(args[[1L]] != args[[2L]]),
    "&" = as.double((args[[1L]] != 0) & (args[[2L]] != 0)),
    "|" = as.double((args[[1L]] != 0) | (args[[2L]] != 0)),
    "!" = as.double(args[[1L]] == 0),
    ifelse = {
      if (any(!is.finite(args[[2L]])) || any(!is.finite(args[[3L]]))) {
        vofi_abort("validation.expr.ifelse", text = text, .class = "vofi_error_input")
      }
      cond <- args[[1L]] != 0
      out <- args[[3L]]
      out[cond] <- args[[2L]][cond]
      out
    },
    pmin = do.call(pmin, args),
    pmax = do.call(pmax, args),
    abs = abs(args[[1L]]),
    round = if (length(args) > 1L) round(args[[1L]], args[[2L]][1L]) else round(args[[1L]]),
    floor = floor(args[[1L]]),
    ceiling = ceiling(args[[1L]]),
    sqrt = sqrt(args[[1L]]),
    exp = exp(args[[1L]]),
    log = log(args[[1L]]),
    is.na = as.double(is.na(args[[1L]]))
  )
  keep_dim(res, args[[1L]])
}
