# Steuer-Hook (WS-D, Spec 00 Abschnitt 10): Generics tax_init/tax_step/tax_finalize mit
# Default-Methoden (vofi_error_registry), Modulobjekt new_tax_module(), Registrierung von
# Fremdmodulen (vofi_register_tax_module()), vereinfachtes Modul ohne Zustand
# (vofi_tax_module_simple(), Klasse vofi_tax_simple vor tax_<name>), Steuer-Eingaben vor der
# Schleife (tax_inputs(), zeilengenau mit Metadaten, R-56) und je Periode (tax_slice(), 10.4)
# mit der Vorzeichenkonvention Ertrag/Zufluss +, Aufwand/Abfluss - (disagio negativ,
# repayment_grant positiv). Der Hook laeuft in jeder Periode inkl. t = 0 (R-21), auch in der
# Unterlassungsalternative und in Wiederholungslaeufen.

#' Steuermodul registrieren
#'
#' Registriert ein Fremd-Steuermodul als Typ der Art `tax` (Spec 00, Abschnitte 5.7, 10.2). Das
#' Modul liefert S3-Methoden für [tax_init()], [tax_step()] und [tax_finalize()] zur Klasse
#' `tax_<name>`; `constructor(params, spec)` erzeugt das Modulobjekt (eine Liste; die Klassen
#' `c("tax_<name>", "vofi_tax_module")` werden ergänzt, falls sie fehlen). Das Modul erhält die
#' Steuer-Eingaben zeilengenau (`uses_inputs = TRUE`). Im Szenario wählt `tax.module: <name>`
#' das Modul; `tax.params` sind seine Parameter (fehlende erhalten den Default aus `params`).
#' Die Defaults der Parameter MÜSSEN eine Steuer von null ergeben (Vertragstest T1).
#'
#' @param name Name des Moduls (`^[a-z][a-z0-9_]*$`).
#' @param constructor Funktion `constructor(params, spec)`, die das Modulobjekt liefert.
#' @param label Anzeigename (Default: `name`).
#' @param perspectives `NULL` (alle) oder zulässige Perspektiven.
#' @param blocked_regimes gesperrte Steuerregime.
#' @param params Parameterschema (benannte Liste von [vofi_param()]).
#' @param overwrite vorhandenes Modul ersetzen.
#' @return `invisible(def)`.
#' @family Erweitern
#' @examples
#' ctor <- function(params, spec) list(name = "beispiel_steuer", params = params)
#' vofi_register_tax_module("beispiel_steuer", ctor, label = "Beispielsteuer",
#'                          params = list(rate = vofi_param("share", default = 0)),
#'                          overwrite = TRUE)
#' "beispiel_steuer" %in% vofi_types("tax")$name
#' @export
vofi_register_tax_module <- function(name, constructor, label = NULL, perspectives = NULL,
                                     blocked_regimes = NULL, params = list(), overwrite = FALSE) {
  if (!utl_is_string(name) || !utl_is_id(name)) {
    vofi_abort("core.registry.name_invalid", name = utl_collapse(format(name)), kind = "tax",
               .class = "vofi_error_input")
  }
  if (!is.function(constructor)) {
    vofi_abort("tax.constructor_invalid", name = name, .class = "vofi_error_input")
  }
  if (!utl_is_flag(overwrite)) {
    vofi_abort("core.arg_flag", arg = "overwrite", .class = "vofi_error_input")
  }
  if (!is.list(params) || (length(params) > 0L && is.null(names(params)))) {
    vofi_abort("core.registry.params_invalid", name = name, .class = "vofi_error_input")
  }
  label <- label %||% name
  user_ctor <- constructor
  ctor <- function(params, spec) {
    m <- user_ctor(params, spec)
    if (!inherits(m, "vofi_tax_module")) {
      m <- tax_as_module(name, params, m)
    }
    m
  }
  example <- list()
  for (p in names(params)) {
    if (inherits(params[[p]], "vofi_param") && !is.null(params[[p]]$default)) {
      example[p] <- list(params[[p]]$default)
    }
  }
  def <- vofi_type(
    name = name, kind = "tax", params = params, label = label,
    labels = list(description = label,
                  params = stats::setNames(as.list(names(params)), names(params)),
                  rows = list()),
    perspectives = perspectives, blocked_regimes = blocked_regimes, uses_inputs = TRUE,
    constructor = ctor, example = example
  )
  reg_add(def, source = "user", overwrite = overwrite)
  invisible(def)
}

#' Vereinfachtes Steuermodul
#'
#' Erzeugt und registriert ein Steuermodul ohne Zustand, das periodenweise rechnet: `fun(inputs,
#' params)` liefert die Steuerzahlung der Periode (n-Vektor oder Skalar; positiv = Zahlung). Das
#' Modul sieht die Steuer-Eingaben der Periode (Spec 00, Abschnitt 10.4), aber keine endogenen
#' Zinsen (dokumentierte Grenze; nur für Experimente, Abschnitt 10.2). `tax_init()` liefert
#' `list()`, `tax_finalize()` eine offene Steuer von 0. Die Klasse des Moduls ist
#' `c("vofi_tax_simple", "tax_<name>", "vofi_tax_module")`; `fun` gilt damit auch für Namen,
#' zu denen es bereits Methoden gibt.
#'
#' @param name Name des Moduls.
#' @param fun Funktion `fun(inputs, params)` -> n-Vektor der Zahlung.
#' @param label Anzeigename.
#' @return `invisible(def)`.
#' @family Erweitern
#' @examples
#' vofi_tax_module_simple("beispiel_einfach", function(inputs, params) 0,
#'                        label = "Einfaches Beispielmodul")
#' "beispiel_einfach" %in% vofi_types("tax")$name
#' @export
vofi_tax_module_simple <- function(name, fun, label = NULL) {
  if (!is.function(fun) || !identical(names(formals(fun)), c("inputs", "params"))) {
    vofi_abort("tax.simple_fun_invalid", name = utl_collapse(format(name)),
               .class = "vofi_error_input")
  }
  force(fun)
  nm <- name
  ctor <- function(params, spec) {
    m <- new_tax_module(nm, params = params, fun = fun)
    # vofi_tax_simple zuerst: die Methoden des einfachen Moduls rufen fun auf, auch wenn es zu
    # tax_<name> bereits Methoden gibt (z. B. eingebaute Module)
    class(m) <- c("vofi_tax_simple", paste0("tax_", nm), "vofi_tax_module")
    m
  }
  vofi_register_tax_module(name, ctor, label = label, overwrite = TRUE)
}

#' Steuermodul-Objekt (intern, Spec 00 Abschnitt 10.2)
#' @param name Name des Moduls; die S3-Klasse ist `tax_<name>`.
#' @param params Parameter des Moduls.
#' @param ... weitere Felder.
#' @return Objekt der Klasse `c("tax_<name>", "vofi_tax_module")`.
#' @noRd
new_tax_module <- function(name, params = list(), ...) {
  structure(list(name = name, params = params, ...),
            class = c(paste0("tax_", name), "vofi_tax_module"))
}

#' Rückgabe eines Nutzerkonstruktors zum Modulobjekt ergänzen
#' @noRd
tax_as_module <- function(name, params, m) {
  m <- if (is.list(m)) unclass(m) else list()
  m$name <- m$name %||% name
  m$params <- m$params %||% params
  structure(m, class = c(paste0("tax_", name), "vofi_tax_module"))
}

#' Steuer-Eingaben vor der Periodenschleife (10.4, R-56)
#'
#' Alle exogenen Zeilen mit `tax_category != "not_applicable"` (auch `cash = FALSE`) zeilengenau
#' als n x (T+1)-Matrizen mit Metadaten; dazu die Metadaten der Instrumentzeilen (Sollzinsen,
#' Gebühren, Disagio, Tilgungszuschuss), deren Werte je Periode aus der Periodenschleife kommen.
#' Vorzeichen: Ertrag/Zufluss +, Aufwand/Abfluss - (Merkzeilen `disagio` negativ,
#' `repayment_grant` positiv).
#' @param exo exogener Ledger.
#' @param ctx Laufkontext.
#' @param inst_rows `NULL` oder Data Frame der Instrumentzeilen (aus `eng_model_rows()`).
#' @return `list(values = list(<key> = n x (T+1)), keys = data.frame, grid)`.
#' @noRd
tax_inputs <- function(exo, ctx, inst_rows = NULL) {
  sel <- exo$rows$tax_category != "not_applicable"
  rows <- exo$rows[sel, , drop = FALSE]
  sign <- ifelse(rows$category == "disagio", -1, 1)
  values <- stats::setNames(lapply(seq_len(nrow(rows)), function(i) {
    sign[i] * exo$values[[rows$key[i]]]
  }), rows$key)
  keys <- tax_keys_df(rows, "exo")
  if (!is.null(inst_rows) && nrow(inst_rows) > 0L) {
    ir <- inst_rows[inst_rows$category %in% c("interest", "fees", "disagio", "repayment_grant"),
                    , drop = FALSE]
    keys <- rbind(keys, tax_keys_df(ir, "inst"))
  }
  rownames(keys) <- NULL
  list(values = values, keys = keys, grid = ctx$grid)
}

#' Metadaten der Steuer-Eingaben (10.4)
#' @noRd
tax_keys_df <- function(rows, source) {
  out <- data.frame(key = rows$key, source = rep(source, nrow(rows)), section = rows$section,
                    category = rows$category, tax_category = rows$tax_category,
                    asset_id = rows$asset_id, measure_id = rows$measure_id, cash = rows$cash,
                    stringsAsFactors = FALSE)
  out$extra <- I(if (nrow(rows) == 0L) list() else unclass(rows$extra))
  out
}

#' Steuer-Eingaben einer Periode (10.4)
#' @param tin Ergebnis von `tax_inputs()` oder `NULL` (Modul mit `uses_inputs = FALSE`).
#' @param j Spalte (t + 1).
#' @param inst_rows benannte Liste der Instrumentzeilen der Periode (n-Vektoren, Vorzeichen nach
#'   10.4) oder `list()`.
#' @param grid `vofi_grid`.
#' @param keys Metadaten (Default: aus `tin` bzw. leer; die Engine übergibt sie vorab erzeugt).
#' @return Liste `t`, `date_end`, `delta`, `year`, `phase`, `exo`, `inst`, `keys`.
#' @noRd
tax_slice <- function(tin, j, inst_rows = list(), grid = tin$grid, keys = NULL) {
  if (is.null(keys)) keys <- if (is.null(tin)) tax_keys_empty() else tin$keys
  list(t = grid$t[j], date_end = grid$date_end[j], delta = grid$delta[j], year = grid$year[j],
       phase = grid$phase[j],
       exo = if (is.null(tin)) list() else lapply(tin$values, function(m) m[, j]),
       inst = if (is.null(tin)) list() else inst_rows, keys = keys)
}

#' Leere Metadaten der Steuer-Eingaben
#' @noRd
tax_keys_empty <- function() {
  out <- data.frame(key = character(0), source = character(0), section = character(0),
                    category = character(0), tax_category = character(0),
                    asset_id = character(0), measure_id = character(0), cash = logical(0),
                    stringsAsFactors = FALSE)
  out$extra <- I(list())
  out
}

#' Laufzahl n aus den Zinsgrößen der Periode (10.4: immer n-Vektoren)
#' @noRd
tax_n_of <- function(interest) max(c(1L, lengths(interest)))

#' Steuer-Hook: Initialisierung
#'
#' S3-Generic des Steuer-Hooks (Spec 00, Abschnitte 10.3, 10.4). Liefert den Anfangszustand des
#' Steuermoduls; die Elemente sind n-Vektoren oder Skalare. Die Default-Methode meldet einen
#' Fehler der Klasse `vofi_error_registry` (keine Methode für das Modul).
#'
#' @param module Steuermodul (Klasse `tax_<name>`).
#' @param params Parameter des Moduls.
#' @param assets Anlagenregister (Liste von [vofi_asset()]).
#' @param measures Maßnahmenregister (Liste von [vofi_measure()]).
#' @param n_sim Anzahl der Läufe n.
#' @return Zustand (Liste).
#' @family Erweitern
#' @examples
#' m <- structure(list(name = "none", params = list()), class = c("tax_none", "vofi_tax_module"))
#' tax_init(m, list(), list(), list(), 2L)
#' @export
tax_init <- function(module, params, assets, measures, n_sim) {
  UseMethod("tax_init")
}

#' @rdname tax_init
#' @export
tax_init.default <- function(module, params, assets, measures, n_sim) {
  vofi_abort("core.registry.tax_no_method", fun = "tax_init",
             module = utl_collapse(class(module)), .class = "vofi_error_registry")
}

#' @rdname tax_init
#' @export
tax_init.vofi_tax_simple <- function(module, params, assets, measures, n_sim) {
  list()
}

#' Steuer-Hook: Steuer der Periode
#'
#' S3-Generic des Steuer-Hooks (Spec 00, Abschnitte 10.3–10.5). Berechnet die Steuerzahlung der
#' Periode t (positiv = Zahlung, negativ = Erstattung); die Engine bucht `-payment` in die Zeile
#' `tax`, Berichtsgrößen (`report`) als Merkzeilen `tax_report_<name>`.
#'
#' @param module Steuermodul (Klasse `tax_<name>`).
#' @param t Periodenindex (0…T).
#' @param inputs Eingaben der Periode (Spec 00, Abschnitt 10.4).
#' @param interest Zinsen der Periode: `exo_soll`, `exo_fees`, `endo_soll`, `endo_haben`,
#'   `endo_wht` (n-Vektoren).
#' @param state Zustand aus [tax_init()] bzw. dem vorigen Aufruf.
#' @param params Parameter des Moduls.
#' @return `list(payment = n-Vektor, state = <Zustand>, report = list(<name> = n-Vektor))`.
#' @family Erweitern
#' @examples
#' m <- structure(list(name = "none", params = list()), class = c("tax_none", "vofi_tax_module"))
#' tax_step(m, 1L, list(), list(exo_soll = c(0, 0), exo_fees = c(0, 0), endo_soll = c(0, 0),
#'                              endo_haben = c(10, 20), endo_wht = c(0, 0)), list(), list())
#' @export
tax_step <- function(module, t, inputs, interest, state, params) {
  UseMethod("tax_step")
}

#' @rdname tax_step
#' @export
tax_step.default <- function(module, t, inputs, interest, state, params) {
  vofi_abort("core.registry.tax_no_method", fun = "tax_step",
             module = utl_collapse(class(module)), .class = "vofi_error_registry")
}

#' @rdname tax_step
#' @export
tax_step.vofi_tax_simple <- function(module, t, inputs, interest, state, params) {
  n <- tax_n_of(interest)
  pay <- module$fun(inputs, params)
  if (!is.numeric(pay) || !(length(pay) %in% c(1L, n)) || any(!is.finite(pay))) {
    vofi_abort("tax.simple_payment_invalid", name = module$name %||% "?", n = n,
               .class = "vofi_error_contract")
  }
  list(payment = rep_len(as.double(pay), n), state = state, report = list())
}

#' Steuer-Hook: offene Steuer am Horizont
#'
#' S3-Generic des Steuer-Hooks (Spec 00, Abschnitte 10.3, 10.5). Liefert die am Horizont offene
#' Steuer (`payment_T`, positiv = Verbindlichkeit), die den Endwert mindert.
#'
#' @param module Steuermodul (Klasse `tax_<name>`).
#' @param T letzter Periodenindex.
#' @param state Zustand nach der letzten Periode.
#' @param terminal_inputs Eingaben am Horizont (Spec 00, Abschnitt 10.4).
#' @param params Parameter des Moduls.
#' @return `list(payment_T = n-Vektor, report = list(<name> = n-Vektor))`.
#' @family Erweitern
#' @examples
#' m <- structure(list(name = "none", params = list()), class = c("tax_none", "vofi_tax_module"))
#' tax_finalize(m, 5L, list(), list(residual_value = c(0, 0)), list())
#' @export
tax_finalize <- function(module, T, state, terminal_inputs, params) { # nolint
  UseMethod("tax_finalize")
}

#' @rdname tax_finalize
#' @export
tax_finalize.default <- function(module, T, state, terminal_inputs, params) { # nolint
  vofi_abort("core.registry.tax_no_method", fun = "tax_finalize",
             module = utl_collapse(class(module)), .class = "vofi_error_registry")
}

#' @rdname tax_finalize
#' @export
tax_finalize.vofi_tax_simple <- function(module, T, state, terminal_inputs, params) { # nolint
  n <- max(c(1L, length(terminal_inputs$residual_value), lengths(terminal_inputs$exo_T)))
  list(payment_T = numeric(n), report = list())
}
