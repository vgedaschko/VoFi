# Test-Steuermodul test_flat (WS-D, Spec 00 Abschnitt 10.10, R-78, Konzept 3.12, L9).
#
# Über vofi_register_tax_module() registriertes Modul mit Pauschalsatz s (`rate`), linearer AfA
# je asset_id (`depreciation_years`, Bemessung = Summe der Zeilen capex_depreciable derselben
# Anlage), sofortigem Verlustausgleich (negative Steuer = Erstattung) und Veranlagungs-Lag
# (`lag` 0 oder 1; bei lag = 1 ist die Steuer der Periode T am Horizont offen, payment_T).
# Steuerliches Ergebnis je Periode E_t: Summe der exogenen Zeilen mit steuerpflichtigen Erträgen
# bzw. abziehbaren Aufwendungen (income_rental, income_other_taxable, subsidy_operating,
# expense_deductible, capex_expensable; Vorzeichen nach 10.4), abzüglich AfA, Sollzinsen und
# Gebühren der Kredite (exo_soll, exo_fees) und der Kontokorrentzinsen (endo_soll), zuzüglich
# der Habenzinsen (endo_haben).
# Bericht: tax_report_taxable_income (E_t) und tax_report_depreciation (AfA_t).
# Die Defaults der Parameter ergeben eine Steuer von 0 (rate = 0, Vertragstest T1).
# Aufräumen: register_tax_test_module() liefert eine Funktion, die den Registerstand
# wiederherstellt (withr::defer(restore())).

tax_test_taxable <- function() {
  c("income_rental", "income_other_taxable", "subsidy_operating", "expense_deductible",
    "capex_expensable")
}

tax_test_init <- function(module, params, assets, measures, n_sim) {
  list(rem = list(), annual = list(), prev = numeric(n_sim), last = numeric(n_sim),
       afa_total = numeric(n_sim))
}

tax_test_step <- function(module, t, inputs, interest, state, params) {
  n <- max(c(1L, lengths(interest)))
  rate <- as.double(params$rate %||% 0)
  years <- as.double(params$depreciation_years %||% 50)
  keys <- inputs$keys
  ex <- keys[keys$source == "exo", , drop = FALSE]
  val <- function(k) rep_len(as.double(inputs$exo[[k]]), n)
  base <- numeric(n)
  for (k in ex$key[ex$tax_category %in% tax_test_taxable()]) base <- base + val(k)
  # lineare AfA je Anlage: Zugang erhöht Bemessung und Jahresbetrag
  afa <- numeric(n)
  cap <- ex[ex$tax_category == "capex_depreciable", , drop = FALSE]
  for (i in seq_len(nrow(cap))) {
    aid <- if (is.na(cap$asset_id[i])) "ohne_anlage" else cap$asset_id[i]
    add <- -val(cap$key[i])
    state$rem[[aid]] <- (state$rem[[aid]] %||% numeric(n)) + add
    state$annual[[aid]] <- (state$annual[[aid]] %||% numeric(n)) + add / years
  }
  for (aid in names(state$rem)) {
    a <- pmin(state$rem[[aid]], state$annual[[aid]] * inputs$delta)
    state$rem[[aid]] <- state$rem[[aid]] - a
    afa <- afa + a
  }
  e <- base - afa - interest$exo_soll - interest$exo_fees - interest$endo_soll +
    interest$endo_haben
  lag <- as.integer(params$lag %||% 0L)
  pay <- if (lag == 1L) rate * state$last else rate * e
  state$last <- e
  state$afa_total <- state$afa_total + afa
  list(payment = pay, state = state, report = list(taxable_income = e, depreciation = afa))
}

tax_test_finalize <- function(module, T, state, terminal_inputs, params) { # nolint
  rate <- as.double(params$rate %||% 0)
  lag <- as.integer(params$lag %||% 0L)
  open <- if (lag == 1L) rate * state$last else 0 * state$last
  list(payment_T = open, report = list())
}

#' Test-Steuermodul registrieren
#' @param name Name des Moduls (S3-Klasse `tax_<name>`).
#' @return Funktion ohne Argumente, die den vorherigen Registerstand wiederherstellt.
register_tax_test_module <- function(name = "test_flat") {
  old <- reg_state$types
  params <- list(rate = vofi_param("share", default = 0),
                 depreciation_years = vofi_param("number", default = 50, min = 1),
                 lag = vofi_param("integer", default = 0L, min = 0, max = 1))
  ctor <- function(params, spec) list(name = name, params = params)
  vofi_register_tax_module(name, ctor, label = "Test-Steuermodul", params = params,
                           overwrite = TRUE)
  ns <- asNamespace("vofi")
  cls <- paste0("tax_", name)
  registerS3method("tax_init", cls, tax_test_init, envir = ns)
  registerS3method("tax_step", cls, tax_test_step, envir = ns)
  registerS3method("tax_finalize", cls, tax_test_finalize, envir = ns)
  function() reg_state$types <- old
}

#' Szenario des Standardmodells: Investition mit Anlage, Mieten, EK, Kontokorrent zu i
#' @param rate Steuersatz s.
#' @param i Soll- und Habenzins.
#' @param lag Veranlagungs-Lag.
tax_test_scenario <- function(rate = 0.3, i = 0.05, lag = 0L, years = 3,
                              rent = c(0, 30000, 40000, 50000), ek = 60000,
                              module = "test_flat") {
  sc <- wsd_scenario(
    rent, ek = list(type = "equity", amount_eur = ek),
    accounts = list(deposit_rate_pa = i, overdraft_rate_pa = i, overdraft_limit_eur = Inf),
    components = list(inv = list(type = "custom_series", category = "capex",
                                 tax_category = "capex_depreciable", asset_id = "geb",
                                 values = c(-100000, rep(0, length(rent) - 1L))))
  )
  sc$components$z$category <- "rent"
  sc$tax <- list(module = module, params = list(rate = rate, depreciation_years = years,
                                                lag = as.integer(lag)))
  sc
}
