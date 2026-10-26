# Sichere, vektorisierte Ausdruecke der Wertgrammatik (WS-B, Spec 00 Abschnitt 4.5 Regel 5).
# Der Text wird mit dem R-Parser in einen Syntaxbaum zerlegt (keine Auswertung beliebigen Codes)
# und rekursiv gegen eine Whitelist geprueft; ausgewertet wird ausschliesslich durch einen
# eigenen Interpreter ueber den Baum. Pfadsymbole (mit Punkt) werden ueber resolve() gelesen,
# Operanden nach der Formregel angeglichen (Laenge 1 -> n-Vektor; n-Vektoren zeilenweise auf
# n x (T+1), sobald ein Operand zeitabhaengig ist). Codes und Wahrheitswerte (setting-Semantik)
# sind nur in Vergleichen und logischen Verknuepfungen zulaessig (R-91). Fehler sind
# vofi_error_input mit Position (Zeile, Spalte) im Ausdruckstext.

#' Zulässige Funktionen und Operatoren (4.5 Regel 5)
#' @return Zeichenvektor.
#' @noRd
expr_whitelist <- function() {
  c("+", "-", "*", "/", "^", "%%", "(", "<", "<=", ">", ">=", "==", "!=", "&", "|", "!",
    "ifelse", "pmin", "pmax", "abs", "round", "floor", "ceiling", "sqrt", "exp", "log",
    "is.na", "%in%", "c")
}

#' Zulässige Anzahl der Argumente je Funktion bzw. Operator
#'
#' @return Liste `name -> c(min, max)`.
#' @noRd
expr_arity <- function() {
  one <- c(1L, 1L)
  two <- c(2L, 2L)
  list("+" = c(1L, 2L), "-" = c(1L, 2L), "*" = two, "/" = two, "^" = two, "%%" = two,
       "(" = one, "<" = two, "<=" = two, ">" = two, ">=" = two, "==" = two, "!=" = two,
       "&" = two, "|" = two, "!" = one, ifelse = c(3L, 3L), pmin = c(1L, Inf),
       pmax = c(1L, Inf), abs = one, round = c(1L, 2L), floor = one, ceiling = one,
       sqrt = one, exp = one, log = c(1L, 2L), is.na = one, "%in%" = two, c = c(1L, Inf))
}

#' Vorschlag für nicht zugelassene Funktionen, die über Läufe aggregieren (2.8 Nr. 3)
#' @param name Funktionsname.
#' @return Vorschlag oder `""`.
#' @noRd
expr_hint <- function(name) {
  switch(name, min = "pmin", max = "pmax", "&&" = "&", "||" = "|", sum = "+", "")
}

#' Ausdruck parsen und gegen die Whitelist prüfen
#'
#' @param text Zeichenkette, z. B. `"building.living_area_m2 * 150"`.
#' @return Objekt der Klasse `vofi_expr` (`text`, `call`, `symbols`); Syntaxfehler und nicht
#'   zugelassene Funktionen, Symbole oder Werte sind `vofi_error_input` mit Position.
#' @noRd
expr_parse <- function(text) {
  if (inherits(text, "vofi_expr")) return(text)
  if (!utl_is_string(text) || !nzchar(trimws(text))) {
    vofi_abort("validation.expr.empty", text = utl_collapse(format(text %||% "")),
               .class = "vofi_error_input")
  }
  parsed <- tryCatch(parse(text = text, keep.source = FALSE), error = function(e) e)
  if (inherits(parsed, "error")) {
    vofi_abort("validation.expr.syntax", text = text,
               position = expr_parse_error_position(conditionMessage(parsed), text),
               .class = "vofi_error_input")
  }
  if (length(parsed) != 1L) {
    vofi_abort("validation.expr.multiple", text = text, n = length(parsed),
               .class = "vofi_error_input")
  }
  call <- parsed[[1L]]
  expr_check(call, text)
  structure(list(text = text, call = call, symbols = expr_collect_symbols(call)),
            class = "vofi_expr")
}

#' Position eines Syntaxfehlers aus der Meldung des R-Parsers
#'
#' Der Parser meldet `<text>:<zeile>:<spalte>: ...`; Spalte 0 bedeutet „Ende der Zeile davor“.
#' @param message Meldung des Parsers.
#' @param text Ausdruckstext.
#' @return Positionstext (deutsch, über den Label-Katalog).
#' @noRd
expr_parse_error_position <- function(message, text) {
  m <- regmatches(message, regexec("<text>:([0-9]+):([0-9]+):", message))[[1L]]
  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  if (length(lines) == 0L) lines <- ""
  if (length(m) == 3L) {
    line <- as.integer(m[2L])
    col <- as.integer(m[3L])
  } else {
    line <- length(lines)
    col <- 0L
  }
  if (col <= 0L) {
    line <- min(max(line - 1L, 1L), length(lines))
    col <- nchar(lines[line]) + 1L
  }
  expr_format_position(line, col)
}

#' Positionstext „Zeile l, Spalte c“
#' @noRd
expr_format_position <- function(line, col) {
  msg("validation.expr.position", line = as.integer(line), col = as.integer(col))
}

#' Position eines Tokens im Ausdruckstext (erstes Vorkommen)
#' @param text Ausdruckstext.
#' @param token Text des Tokens (Funktionsname, Symbol, Operator).
#' @return Positionstext.
#' @noRd
expr_token_position <- function(text, token) {
  pd <- tryCatch(utils::getParseData(parse(text = text, keep.source = TRUE)),
                 error = function(e) NULL)
  if (is.data.frame(pd) && nrow(pd) > 0L) {
    hit <- pd[pd$terminal & pd$text == token, , drop = FALSE]
    if (nrow(hit) > 0L) {
      hit <- hit[order(hit$line1, hit$col1, method = "radix"), , drop = FALSE]
      return(expr_format_position(hit$line1[1L], hit$col1[1L]))
    }
  }
  loc <- regexpr(token, text, fixed = TRUE)
  expr_format_position(1L, if (loc > 0L) as.integer(loc) else 1L)
}

#' Fehler eines Ausdrucks mit Position des Tokens
#' @noRd
expr_fail <- function(key, text, token, ...) {
  vofi_abort(key, text = text, position = expr_token_position(text, token), ...,
             .class = "vofi_error_input")
}

#' Name einer Funktion bzw. eines Operators in einem Aufruf
#' @noRd
expr_call_name <- function(e) {
  fn <- e[[1L]]
  if (is.symbol(fn)) as.character(fn) else ""
}

#' Ist `e` ein Literal (Zahl, Zeichenkette, TRUE/FALSE)?
#' @noRd
expr_is_literal <- function(e) {
  (is.numeric(e) || is.character(e) || (is.logical(e) && !anyNA(e))) && length(e) == 1L
}

#' Ist `e` ein Pfadsymbol (Symbol mit Punkt)?
#' @noRd
expr_is_path <- function(e) {
  is.symbol(e) && grepl(".", as.character(e), fixed = TRUE)
}

#' AST rekursiv gegen die Whitelist prüfen
#' @param e Teilbaum.
#' @param text Ausdruckstext (für Meldungen).
#' @return `invisible(TRUE)`.
#' @noRd
expr_check <- function(e, text) {
  if (is.logical(e) && length(e) == 1L && is.na(e)) {
    expr_fail("validation.expr.literal", text, "NA", value = "NA")
  }
  if (expr_is_literal(e)) return(invisible(TRUE))
  if (is.symbol(e)) {
    s <- as.character(e)
    if (s %in% c("TRUE", "FALSE")) return(invisible(TRUE))
    if (!grepl(".", s, fixed = TRUE) || !grepl("^[A-Za-z][A-Za-z0-9_.]*[A-Za-z0-9_]$", s)) {
      expr_fail("validation.expr.symbol", text, s, symbol = s)
    }
    return(invisible(TRUE))
  }
  if (is.call(e)) {
    name <- expr_call_name(e)
    if (!(name %in% expr_whitelist())) {
      if (!nzchar(name)) {
        vofi_abort("validation.expr.syntax", text = text,
                   position = expr_format_position(1L, 1L), .class = "vofi_error_input")
      }
      hint <- expr_hint(name)
      expr_fail("validation.expr.function", text, name, fun = name,
                hint = if (nzchar(hint)) lbl("core.did_you_mean", suggestion = hint) else "")
    }
    args <- as.list(e)[-1L]
    nms <- names(args) %||% rep("", length(args))
    allowed_names <- switch(name, round = "digits", log = "base", character(0))
    bad_names <- nms[nzchar(nms) & !(nms %in% allowed_names)]
    if (length(bad_names) > 0L) {
      expr_fail("validation.expr.named_arg", text, name, fun = name, arg = bad_names[1L])
    }
    ar <- expr_arity()[[name]]
    if (length(args) < ar[1L] || length(args) > ar[2L]) {
      expr_fail("validation.expr.arity", text, name, fun = name, n = length(args))
    }
    if (name %in% c("round", "log") && length(args) == 2L && !is.numeric(args[[2L]])) {
      expr_fail("validation.expr.not_deterministic", text, name, fun = name)
    }
    if (identical(name, "c")) {
      for (a in args) {
        if (!(expr_is_literal(a) || expr_is_path(a))) {
          expr_fail("validation.expr.not_deterministic", text, "c", fun = "c")
        }
      }
    }
    if (identical(name, "%in%")) {
      rhs <- args[[2L]]
      ok <- expr_is_literal(rhs) || expr_is_path(rhs) ||
        (is.call(rhs) && identical(expr_call_name(rhs), "c"))
      if (!ok) expr_fail("validation.expr.not_deterministic", text, "%in%", fun = "%in%")
    }
    for (a in args) expr_check(a, text)
    return(invisible(TRUE))
  }
  vofi_abort("validation.expr.syntax", text = text, position = expr_format_position(1L, 1L),
             .class = "vofi_error_input")
}

#' Pfadsymbole eines Aufrufs sammeln
#' @noRd
expr_collect_symbols <- function(e) {
  if (is.symbol(e)) {
    s <- as.character(e)
    return(if (grepl(".", s, fixed = TRUE)) s else character(0))
  }
  if (is.call(e)) {
    out <- unlist(lapply(as.list(e)[-1L], expr_collect_symbols), use.names = FALSE)
    return(unique(out %||% character(0)))
  }
  character(0)
}

#' Alle Pfadsymbole eines Ausdrucks (Abhängigkeiten, Zyklusprüfung)
#'
#' Auch Pfadsymbole auf nicht-numerische Blätter (Codes, Wahrheitswerte) werden gemeldet
#' (R-91).
#' @param ast Objekt der Klasse `vofi_expr`, Ausdrucksknoten `list(kind = "expr", text, ast)`
#'   oder Ausdruckstext.
#' @return Zeichenvektor (eindeutig, Reihenfolge des ersten Vorkommens).
#' @noRd
expr_symbols <- function(ast) {
  if (!inherits(ast, "vofi_expr")) {
    ast <- if (is.list(ast)) ast$ast %||% expr_parse(ast$text) else expr_parse(ast)
  }
  ast$symbols %||% character(0)
}

#' Ausdruck vektorisiert auswerten (Formregel 4.5 Regel 5)
#'
#' @param ast Objekt der Klasse `vofi_expr` (oder Ausdruckstext).
#' @param resolve `function(path)` -> Skalar, n-Vektor oder n x (T+1); bei nicht-numerischen
#'   Blättern Codes (`character`) bzw. Wahrheitswerte (`logical`, setting-Semantik, R-91);
#'   `NULL`, wenn der Pfad nicht existiert.
#' @param n Anzahl der Läufe.
#' @param T letzter Periodenindex.
#' @return double n-Vektor oder n x (T+1).
#' @noRd
expr_eval <- function(ast, resolve, n, T) { # nolint: object_name_linter. T wie Spec 00 4.5.
  if (!inherits(ast, "vofi_expr")) ast <- expr_parse(ast)
  big_t <- as.integer(T) # nolint: object_name_linter, T_and_F_symbol_linter. Periodenindex.
  env <- new.env(parent = emptyenv())
  env$cache <- list()
  env$resolve <- resolve
  env$n <- as.integer(n)
  env$big_t <- big_t
  env$text <- ast$text
  out <- expr_eval_node(ast$call, env)
  if (is.character(out) || is.logical(out)) {
    vofi_abort("validation.expr.not_numeric", text = ast$text, .class = "vofi_error_input")
  }
  out <- expr_shape(out, env$n, big_t)
  storage.mode(out) <- "double"
  out
}

#' Operand auf die gemeinsame Form heben
#' @noRd
expr_shape <- function(x, n, big_t, to_path = FALSE) {
  if (is.character(x)) return(x)
  if (is.logical(x)) x <- as.double(x)
  if (is.matrix(x)) {
    if (nrow(x) != n || ncol(x) != big_t + 1L) {
      vofi_abort("core.contract.length", what = "expr", expected = n,
                 actual = utl_collapse(dim(x), " x "), .class = "vofi_error_contract")
    }
    storage.mode(x) <- "double"
    return(x)
  }
  x <- as.double(x)
  if (length(x) == 1L) x <- rep_len(x, n)
  if (length(x) != n) {
    vofi_abort("core.contract.length", what = "expr", expected = n, actual = length(x),
               .class = "vofi_error_contract")
  }
  if (to_path) matrix(x, nrow = n, ncol = big_t + 1L) else x
}

#' Numerische Operanden angleichen (Formregel)
#' @noRd
expr_align <- function(args, env) {
  num <- !vapply(args, is.character, logical(1))
  any_path <- any(vapply(args[num], is.matrix, logical(1)))
  args[num] <- lapply(args[num], expr_shape, n = env$n, big_t = env$big_t, to_path = any_path)
  args
}

#' Nicht-numerische Operanden prüfen (4.5 Regel 5, R-91)
#'
#' Codes (`character`) sind nur in `==`, `!=` (gegen Codes) zulässig, Wahrheitswerte
#' (`logical`, setting-Semantik) in `==`, `!=`, `!`, `&`, `|`; das Ergebnis ist 0/1. Jede andere
#' Verwendung ist `vofi_error_input`.
#' @noRd
expr_check_operands <- function(args, name, env) {
  is_chr <- vapply(args, is.character, logical(1))
  is_lgl <- vapply(args, is.logical, logical(1))
  bad <- (any(is_chr) && (!(name %in% c("==", "!=")) || !all(is_chr))) ||
    (any(is_lgl) && !(name %in% c("==", "!=", "!", "&", "|")))
  if (bad) {
    expr_fail("validation.expr.code_operand", env$text, name, fun = name)
  }
  invisible(TRUE)
}

#' Pfadsymbol auflösen (mit Zwischenspeicher je Auswertung)
#' @noRd
expr_resolve_symbol <- function(s, env) {
  if (utl_has_name(env$cache, s)) return(env$cache[[s]])
  v <- env$resolve(s)
  if (is.null(v)) {
    expr_fail("validation.expr.path_missing", env$text, s, symbol = s)
  }
  if (inherits(v, "Date")) {
    expr_fail("validation.expr.code_operand", env$text, s, fun = s)
  }
  if (is.factor(v)) v <- as.character(v)
  if (!is.numeric(v) && !is.character(v) && !is.logical(v)) {
    expr_fail("validation.expr.not_numeric_symbol", env$text, s, symbol = s)
  }
  env$cache[s] <- list(v)
  v
}

#' Rekursive Auswertung
#' @noRd
expr_eval_node <- function(e, env) {
  if (is.numeric(e)) return(as.double(e))
  if (is.logical(e)) return(as.double(e))
  if (is.character(e)) return(e)
  if (is.symbol(e)) {
    s <- as.character(e)
    if (s == "TRUE") return(1)
    if (s == "FALSE") return(0)
    return(expr_resolve_symbol(s, env))
  }
  name <- expr_call_name(e)
  raw_args <- as.list(e)[-1L]
  args <- lapply(raw_args, expr_eval_node, env = env)
  if (identical(name, "(")) return(args[[1L]])
  if (identical(name, "c")) return(expr_eval_c(args, raw_args, env))
  if (identical(name, "%in%")) return(expr_eval_in(args, raw_args, env))
  expr_check_operands(args, name, env)
  if (all(vapply(args, is.logical, logical(1)))) {
    args <- lapply(args, as.double)
  }
  args <- expr_align(args, env)
  keep_dim <- function(res, like) {
    if (is.matrix(like) && !is.matrix(res)) dim(res) <- dim(like)
    res
  }
  bin <- function(f) f(args[[1L]], args[[2L]])
  res <- switch(name,
    "+" = if (length(args) == 1L) args[[1L]] else bin(`+`),
    "-" = if (length(args) == 1L) -args[[1L]] else bin(`-`),
    "*" = bin(`*`),
    "/" = bin(`/`),
    "^" = bin(`^`),
    "%%" = bin(`%%`),
    "<" = as.double(bin(`<`)),
    "<=" = as.double(bin(`<=`)),
    ">" = as.double(bin(`>`)),
    ">=" = as.double(bin(`>=`)),
    "==" = as.double(bin(`==`)),
    "!=" = as.double(bin(`!=`)),
    "&" = as.double((args[[1L]] != 0) & (args[[2L]] != 0)),
    "|" = as.double((args[[1L]] != 0) | (args[[2L]] != 0)),
    "!" = as.double(args[[1L]] == 0),
    ifelse = expr_eval_ifelse(args, env),
    pmin = do.call(pmin, unname(args)),
    pmax = do.call(pmax, unname(args)),
    abs = abs(args[[1L]]),
    round = if (length(args) > 1L) round(args[[1L]], args[[2L]][1L]) else round(args[[1L]]),
    floor = floor(args[[1L]]),
    ceiling = ceiling(args[[1L]]),
    sqrt = suppressWarnings(sqrt(args[[1L]])),
    exp = exp(args[[1L]]),
    log = if (length(args) > 1L) {
      suppressWarnings(log(args[[1L]], base = args[[2L]][1L]))
    } else {
      suppressWarnings(log(args[[1L]]))
    },
    is.na = as.double(is.na(args[[1L]]))
  )
  keep_dim(res, args[[1L]])
}

#' ifelse(): Bedingung 0/1, beide Zweige endlich (4.5 Regel 5)
#' @noRd
expr_eval_ifelse <- function(args, env) {
  for (k in 2:3) {
    if (any(!is.finite(args[[k]]))) {
      expr_fail("validation.expr.ifelse_nonfinite", env$text, "ifelse")
    }
  }
  cond <- args[[1L]] != 0
  out <- args[[3L]]
  out[cond] <- args[[2L]][cond]
  out
}

#' c(): nur deterministische Operanden (Literale bzw. Codes aus Pfadsymbolen)
#'
#' Pfadsymbole in `c()` müssen Codes bzw. Wahrheitswerte liefern; numerische Pfadsymbole sind
#' nicht zulässig, weil sie je Lauf verschieden sein können (Batch-Invarianz).
#' @noRd
expr_eval_c <- function(args, raw_args, env) {
  for (i in seq_along(args)) {
    if (expr_is_path(raw_args[[i]]) && !is.character(args[[i]]) && !is.logical(args[[i]])) {
      expr_fail("validation.expr.not_deterministic", env$text, "c", fun = "c")
    }
  }
  if (any(vapply(args, is.character, logical(1)))) {
    return(as.character(unlist(lapply(args, function(a) {
      if (is.logical(a)) tolower(as.character(a)) else as.character(a)
    }))))
  }
  as.double(unlist(args))
}

#' %in%: Ergebnis 0/1 in der Form des ersten Operanden; rechte Seite deterministisch
#' @noRd
expr_eval_in <- function(args, raw_args, env) {
  lhs <- args[[1L]]
  rhs <- args[[2L]]
  if (expr_is_path(raw_args[[2L]]) && !is.character(rhs) && !is.logical(rhs)) {
    expr_fail("validation.expr.not_deterministic", env$text, "%in%", fun = "%in%")
  }
  if (is.logical(lhs)) lhs <- tolower(as.character(lhs))
  if (is.logical(rhs)) rhs <- tolower(as.character(rhs))
  if (xor(is.character(lhs), is.character(rhs))) {
    expr_fail("validation.expr.code_operand", env$text, "%in%", fun = "%in%")
  }
  res <- as.double(lhs %in% rhs)
  if (is.matrix(lhs)) dim(res) <- dim(lhs)
  res
}
