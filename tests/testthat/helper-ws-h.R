# Testhelfer von WS-H (Ausgabe: Methoden, Tabellen, Sichten, Grafiken, Excel-Export).
#
# Abhängigkeiten zu anderen Paketen (im Bericht an den Integrator genannt):
# 1. Integration (Stufe II): vofi_table(), vofi_ledger(), vofi_plot(), vofi_export_excel(),
#    vofi_tenant_view() und vofi_household_view() stehen nicht mehr in vofi_stubs()
#    (helper-contracts.R); die frühere Hülle um vofi_stubs() ist entfallen.
# 2. vofi_compare(), vofi_mc() und vofi_sensitivity() (WS-G) sind noch Stubs. Vergleiche,
#    Simulationen und Sensitivitätsanalysen entstehen deshalb als vertragsgemäße Attrappen
#    (13.2-13.4): example_mc_result(), example_comparison() (Integrator) sowie wsh_comparison()
#    (Vergleich aus echten Engine-Läufen) und wsh_sensitivity() (alle drei Methoden).

#' Szenario einlesen, bauen und rechnen; Bibliothekswarnungen (Gültigkeit) werden verschluckt,
#' ebenso die erwartete Warnung zur fehlenden Grundsteuer der selbstgenutzten Gruppe `main` in
#' wsh_self_scenario() (die Testszenarien rechnen bewusst ohne Grundsteuer; festgehalten in
#' test-report-views.R, "WS-H-Testszenarien ...")
wsh_run <- function(sc) {
  withr::local_options(vofi.verbose = FALSE)
  withCallingHandlers(
    vofi_run(vofi_build(sc)),
    vofi_warning_library_outdated = function(w) invokeRestart("muffleWarning"),
    vofi_warning_plausibility = function(w) {
      if (identical(w$key, "expand.unit_groups.property_tax_missing_owner")) {
        invokeRestart("muffleWarning")
      }
    }
  )
}

#' Ausdruck auswerten, Gültigkeitswarnungen der Bibliothek verschlucken
wsh_quiet <- function(expr) {
  withCallingHandlers(
    expr,
    vofi_warning_library_outdated = function(w) invokeRestart("muffleWarning")
  )
}

#' example_mc_result() ohne Gültigkeitswarnungen der Bibliothek (Modell aus oracle_a.yaml)
wsh_mc <- function(n_sim = 200L) wsh_quiet(example_mc_result(n_sim))

#' Neutrale Konten für die Testszenarien
wsh_accounts <- function(...) {
  utils::modifyList(list(deposit_rate_pa = 0.02, overdraft_rate_pa = 0.08,
                         overdraft_limit_eur = Inf, min_liquidity_eur = 0,
                         deposit_withholding_tax_share = 0,
                         surplus_order = c("od_repay", "dep_invest"),
                         deficit_order = c("dep_withdraw", "od_draw", "equity_call")),
                    list(...))
}

#' Selbstnutzer-EFH mit Bauphase (6 Monate), Energie, Wartung, Kredit und bisheriger Miete
#'
#' `building` und `unit_groups` liefern nur Flächen und Stammdaten: Baujahr (Pflicht im Bestand,
#' 01a 3.1), keine Instandhaltungspauschale (`maintenance.enabled = FALSE`, sonst m_maintenance
#' nach R-118 a), ausdrückliche Gruppe `main` mit Nebenkostenpauschale 0 (01b 2.2, F-11; sonst
#' u_main_opex mit 1,70 EUR/(m2 Monat)) und Restwertmethode `zero` (sonst rv_value nach Profil).
#' Alle Zahlungen stammen damit aus den Komponenten des Szenarios.
#' @param energy Energiekosten p. a.; @param capex Investition; @param loan Kreditbetrag.
wsh_self_scenario <- function(energy = 3542.5, capex = -30000, loan = 20000, id = "wsh_self",
                              construction = 6L, income = 4000, rent_now = 900) {
  fin <- list(ek = list(type = "equity", amount_eur = 15000))
  if (loan > 0) {
    fin$kredit <- list(type = "annuity_loan", label = "KfW-Kredit", amount_eur = loan,
                       rate_pa = 0.04, term_years = 10, payments_per_year = 12L)
  }
  grid <- if (construction > 0L) {
    list(construction_months = as.integer(construction),
         construction_step_months = as.integer(construction))
  } else {
    list()
  }
  vofi_scenario(list(
    schema_version = 1L, meta = list(scenario_id = id, title = "Selbstnutzer EFH"),
    project = list(perspective = "selbstnutzer", project_type = "sanierung_einzelmassnahmen",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 8L),
    grid = grid,
    building = list(living_area_m2 = 140, n_units = 1L, construction_year = 1995L,
                    maintenance = list(enabled = FALSE)),
    unit_groups = list(main = list(owner_occupied = TRUE, n_units = 1L, living_area_m2 = 140,
                                   operating = list(recoverable_opex_eur_m2_month = 0))),
    household = list(net_income_month_eur = income, current_rent_month_eur = rent_now),
    components = list(
      inv = list(type = "custom_series", label = "W\u00e4rmepumpe", category = "capex",
                 asset_id = "geb", measure_id = "wp",
                 values = c(0, capex, rep(0, 8L))),
      en = list(type = "recurring", label = "Energie", category = "energy_cost",
                amount_eur = energy, growth = 0.02, start_event = "completion"),
      wa = list(type = "recurring", label = "Wartung", category = "maintenance",
                amount_eur = 250, start_event = "completion")
    ),
    financing = fin, accounts = wsh_accounts(), tax = list(module = "none"),
    residual_value = list(method = "zero")
  ))
}

#' Mietwohnungsbau (Perspektive wu_*) mit Miete, Umlage und Mieter-Merkzeilen vorher/nachher
#'
#' `building` ohne Instandhaltungspauschale (sonst m_maintenance) und mit Restwertmethode `zero`:
#' der Restwert steht als eigene Reihe `rw` im Szenario (sonst doppelt bzw. rv_value nach Profil
#' mit income_value und fehlendem Bodenwert).
wsh_tenant_scenario <- function(perspective = "wu_kommunal", levy = 3000, pre = 17157.42,
                                after = 4998, side_income = 0, tenant_power = FALSE,
                                id = "wsh_tenant") {
  comps <- list(
    inv = list(type = "custom_series", label = "Sanierung", values = c(-400000, rep(0, 6L))),
    miete = list(type = "recurring", label = "Nettokaltmiete", category = "rent",
                 amount_eur = 72000, start_event = as.Date("2027-01-01")),
    umlage = list(type = "custom_series", label = "Modernisierungsumlage",
                  category = "modernization_levy", measure_id = "huelle",
                  values = c(0, rep(levy, 6L))),
    bk = list(type = "custom_series", label = "Betriebskosten Mieter", section = "memo",
              category = "tenant_operating_cost", values = c(0, rep(24000, 6L))),
    heiz = list(type = "custom_series", label = "Heizkosten nachher", section = "memo",
                category = "tenant_energy_cost", values = c(0, rep(after, 6L))),
    heiz_vor = list(type = "custom_series", label = "Heizkosten vorher", section = "memo",
                    category = "tenant_energy_cost_pre", values = c(0, rep(pre, 6L))),
    rw = list(type = "custom_series", label = "Restwert", category = "residual_value",
              values = c(rep(0, 6L), 300000))
  )
  if (side_income > 0) {
    if (tenant_power) {
      comps$strom <- list(type = "custom_series", label = "Mieterstrom",
                          category = "energy_income", values = c(0, rep(side_income, 6L)))
    } else {
      comps$stell <- list(type = "recurring", label = "Stellpl\u00e4tze",
                          category = "operating_income", amount_eur = side_income,
                          start_event = as.Date("2027-01-01"))
    }
  }
  vofi_scenario(list(
    schema_version = 1L, meta = list(scenario_id = id, title = "Mietwohnungsbau"),
    project = list(perspective = perspective, project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 6L),
    building = list(living_area_m2 = 1000, n_units = 12L, maintenance = list(enabled = FALSE)),
    components = comps,
    financing = list(ek = list(type = "equity", amount_eur = 150000),
                     bank = list(type = "annuity_loan", amount_eur = 250000, rate_pa = 0.035,
                                 term_years = 20, payments_per_year = 1L)),
    accounts = wsh_accounts(), tax = list(module = "none"),
    residual_value = list(method = "zero"),
    analysis = list(tenant_view = TRUE)
  ))
}

#' Kleinvermieter mit Miete, Bewirtschaftung und Darlehen
wsh_landlord_scenario <- function(rent = 30000, id = "wsh_landlord") {
  vofi_scenario(list(
    schema_version = 1L, meta = list(scenario_id = id, title = "Kleinvermieter"),
    project = list(perspective = "kleinvermieter", project_type = "neubau",
                   valuation_date = as.Date("2027-01-01"), horizon_years = 5L),
    components = list(
      inv = list(type = "custom_series", label = "Kaufpreis", values = c(-500000, rep(0, 5L))),
      miete = list(type = "recurring", label = "Miete", category = "rent",
                   amount_eur = rent, start_event = as.Date("2027-01-01")),
      kosten = list(type = "recurring", label = "Verwaltung", category = "operating_cost",
                    amount_eur = 3000, start_event = as.Date("2027-01-01"))
    ),
    financing = list(ek = list(type = "equity", amount_eur = 150000),
                     bank = list(type = "annuity_loan", amount_eur = 350000, rate_pa = 0.04,
                                 term_years = 25, payments_per_year = 12L)),
    accounts = wsh_accounts(), tax = list(module = "none")
  ))
}

#' Vertragsgemäßer Vergleich (13.3) aus Engine-Ergebnissen (Attrappe für vofi_compare())
#'
#' `kpi_table` mit den skalaren Kennzahlen je Variante; `differences` mit den
#' Vergleichskennzahlen je Lauf aus `kpi_compare_values()` (WS-D2); `diff_stats` und `ranking`
#' aus `delta_vs_reference`.
wsh_comparison <- function(results, baseline = names(results)[1L]) {
  for (v in names(results)) results[[v]]$meta$variant <- v
  vars <- setdiff(names(results), baseline)
  kt <- do.call(rbind, lapply(names(results), function(v) {
    r <- results[[v]]
    k <- names(r$kpis)
    data.frame(variant = v, kpi = k, value = vapply(k, function(kk) r$kpis[[kk]][1L], 0),
               stringsAsFactors = FALSE)
  }))
  rownames(kt) <- NULL
  cmp <- lapply(vars, function(v) kpi_compare_values(results[[v]], results[[baseline]]))
  names(cmp) <- vars
  dnames <- names(cmp[[1L]]$kpis)
  differences <- lapply(dnames, function(k) {
    matrix(vapply(vars, function(v) cmp[[v]]$kpis[[k]][1L], 0), nrow = 1L,
           dimnames = list(NULL, vars))
  })
  names(differences) <- dnames
  dvr <- differences$delta_vs_reference
  d1 <- unname(dvr[1L, ])
  diff_stats <- data.frame(variant = vars, kpi = "delta_vs_reference", mean = d1,
                           se = NA_real_, q05 = d1, q25 = d1, q50 = d1, q75 = d1, q95 = d1,
                           prob_better = as.double(d1 > 0), stringsAsFactors = FALSE)
  score <- c(stats::setNames(0, baseline), dvr[1L, ])
  ord <- names(score)[order(-score, method = "radix")]
  new_vofi_comparison(list(
    results = results, baseline = baseline, variants = vars, scenario_sets = NULL,
    kpi_table = kt, differences = differences, diff_stats = diff_stats,
    ranking = data.frame(variant = ord, rank = seq_along(ord),
                         criterion = "delta_vs_reference", stringsAsFactors = FALSE),
    diff_table = NULL, comparability = new_vofi_validation(),
    traffic_light = data.frame(variant = vars, level = "yellow", stage1 = "yellow",
                               basis = "base_only", kpi = "delta_vs_reference",
                               rv_dependent = FALSE, ko_codes = "", stringsAsFactors = FALSE),
    restrictions = data.frame(variant = vars, code = "burden", violated_base = FALSE,
                              prob = NA_real_, year = NA_integer_, value = 0.2,
                              threshold = 0.4, ko = FALSE, stringsAsFactors = FALSE),
    conditional = NULL, crn = TRUE,
    meta = list(seed = NULL, n_sim = 1L, mode = "deterministic", allow_unequal = FALSE,
                created = as.POSIXct("2026-10-25 12:00:00", tz = "UTC"))
  ))
}

#' Vertragsgemäße Sensitivitätsanalyse (13.4, Attrappe für vofi_sensitivity())
wsh_sensitivity <- function(method = c("tornado", "spider", "global")) {
  method <- match.arg(method)
  params <- data.frame(param = c("components.z.values", "accounts.deposit_rate_pa"),
                       label = c("Zahlungsfolge", "Habenzins"), base = c(1, 0.03),
                       low = c(0.9, 0.02), high = c(1.1, 0.04), source = "delta",
                       stringsAsFactors = FALSE)
  new_vofi_sensitivity(list(
    method = method, kpi = "delta_terminal_value", variant = "base", base_value = 3726.41,
    params = params,
    results = data.frame(param = params$param, value_low = params$low,
                         value_high = params$high, kpi_low = c(-1000, 3000),
                         kpi_high = c(8000, 4500), swing = c(9000, 1500), rank = 1:2,
                         stringsAsFactors = FALSE),
    spider = data.frame(param = rep(params$param, each = 3L), step = rep(-1:1, 2L),
                        value = c(0.9, 1, 1.1, 0.02, 0.03, 0.04),
                        kpi = c(-1000, 3726.41, 8000, 3000, 3726.41, 4500),
                        stringsAsFactors = FALSE),
    global = data.frame(input = c("components.z.values", "market.inflation"),
                        spearman = c(0.81, -0.2), src = c(0.7, -0.1), srrc = c(0.75, -0.15),
                        prcc = c(0.9, -0.3), s1_binned = c(0.6, 0.05),
                        stringsAsFactors = FALSE),
    r2_src = 0.83, meta = list()
  ))
}

#' Simulationsergebnis mit gespeichertem Zahlungsbuch (store = "full") aus Orakel (a):
#' drei Läufe mit skalierten Werten (vertragsgemäß, Finanzierungssaldo bleibt 0)
wsh_mc_full <- function() {
  mc <- wsh_mc()
  led <- mc$deterministic$ledger
  vals <- lapply(led$values, function(m) rbind(m, 1.1 * m, 0.9 * m))
  mc$ledger <- new_vofi_ledger(led$rows, vals, n = 3L, T = led$T)
  mc$kpis$terminal_value_ex_rv[1:3] <- c(1, 1.1, 0.9) * mc$deterministic$kpis$terminal_value_ex_rv
  mc$meta$store <- "full"
  mc
}

#' Vergleich aus zwei Simulationsergebnissen (Attrappe für vofi_compare(..., n_sim > 1)):
#' Referenz "base" = wsh_mc(), Variante "a" mit Endwert und Endwertdifferenz + 2.000 je Lauf
wsh_mc_comparison <- function(n_sim = 200L) {
  cmp <- example_comparison()
  base <- wsh_mc(n_sim)
  a <- base
  a$meta$variant <- "a"
  a$deterministic$meta$variant <- "a"
  for (k in c("terminal_value", "delta_terminal_value")) {
    a$kpis[[k]] <- a$kpis[[k]] + 2000
    a$deterministic$kpis[[k]] <- a$deterministic$kpis[[k]] + 2000
  }
  cmp$results <- list(base = base, a = a)
  d <- a$kpis$delta_terminal_value - base$kpis$delta_terminal_value
  cmp$differences <- list(delta_vs_reference = matrix(d, ncol = 1L,
                                                      dimnames = list(NULL, "a")))
  cmp$meta$mode <- "mc"
  cmp$meta$n_sim <- as.integer(n_sim)
  cmp
}

#' Simulation eines Bestandsprojekts: Primärkennzahl delta_vs_reference (12.3a), die eine
#' Einzelsimulation nicht enthält
wsh_mc_existing <- function() {
  mc <- wsh_mc()
  mc$spec$project$project_type <- "sanierung_einzelmassnahmen"
  mc$deterministic$spec$project$project_type <- "sanierung_einzelmassnahmen"
  mc$meta$primary_kpi <- "delta_vs_reference"
  mc$deterministic$meta$primary_kpi <- "delta_vs_reference"
  mc
}

#' Datei eines Excel-Exports in ein temporäres Verzeichnis (bis zum Testende)
wsh_xlsx <- function(env = parent.frame()) {
  withr::local_tempfile(fileext = ".xlsx", .local_envir = env)
}

#' Blatt lesen (Leerzeichen in Spaltennamen bleiben erhalten)
wsh_read_xlsx <- function(path, sheet, ...) {
  openxlsx::read.xlsx(path, sheet = sheet, sep.names = " ", ...)
}

#' Formeln eines Blatts (Zellbezug -> Formeltext ohne <f>)
wsh_formulas <- function(path, sheet) {
  wb <- openxlsx::loadWorkbook(path)
  i <- match(sheet, names(wb))
  sd <- wb$worksheets[[i]]$sheet_data
  has <- !is.na(sd$f)
  data.frame(row = sd$rows[has], col = sd$cols[has],
             formula = gsub("^<f>|</f>$", "", sd$f[has]), stringsAsFactors = FALSE)
}

#' Zellen eines Blatts als Zahlenmatrix (Zeile, Spalte wie in Excel; leere Zellen NA)
wsh_cells <- function(path, sheet) {
  df <- openxlsx::read.xlsx(path, sheet = sheet, colNames = FALSE, skipEmptyRows = FALSE,
                            skipEmptyCols = FALSE)
  m <- suppressWarnings(apply(as.matrix(df), 2L, as.numeric))
  if (!is.matrix(m)) m <- matrix(m, nrow = nrow(df))
  m
}

#' SUM-Formel über die Zellwerte auswerten (Bereiche A1:B2 und Einzelzellen)
wsh_eval_sum <- function(formula, cells) {
  refs <- regmatches(formula, gregexpr("[A-Z]+[0-9]+(:[A-Z]+[0-9]+)?", formula))[[1L]]
  pos <- function(ref) {
    c(as.integer(sub("^[A-Z]+", "", ref)), openxlsx::convertFromExcelRef(sub("[0-9]+$", "", ref)))
  }
  total <- 0
  for (ref in refs) {
    parts <- strsplit(ref, ":", fixed = TRUE)[[1L]]
    a <- pos(parts[1L])
    b <- if (length(parts) == 2L) pos(parts[2L]) else a
    block <- cells[a[1L]:b[1L], a[2L]:b[2L], drop = FALSE]
    total <- total + sum(block, na.rm = TRUE)
  }
  total
}
