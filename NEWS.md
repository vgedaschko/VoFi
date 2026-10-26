# vofi 0.1.0 (in Entwicklung)

* Phase 0 (Integrator): Paketgerüst, Kernverträge (`contract_version` 1.0.0),
  Registry mit Prüfkit, Vokabulare, Label-Katalog, Bedingungsklassen,
  Hilfsfunktionen, vollständiges Zeitraster `vofi_time_grid()` sowie Stubs
  aller exportierten Funktionen nach Spec 00 Abschnitt 14.
* Phase 0b (Integrator, Walking Skeleton nach Spec 00 Anhang A): durchgehende
  Kette `vofi_read_scenario()` -> `vofi_resolve()`/`vofi_validate()` ->
  `vofi_build()` -> `vofi_run()` -> `print()` mit Minimalfassungen in den
  Dateien der späteren Eigentümer: YAML-Leser (4.6), Normalisierung und
  Auflösung der Wertgrammatik, Ausdrücke, Laufkontext, Periodenschleife mit
  Ausgleichsketten, Terminalzustand ohne Restwert, Unterlassungsalternative,
  Invarianten, `tax_none`, Typen `equity`, `custom_series`, `recurring`,
  `bullet_loan`, `annuity_loan`, `installment_loan`, alle Ausgleichsaktionen
  aus 8.9 und die Kennzahlen `terminal_value`, `terminal_value_opp`,
  `delta_terminal_value`. Das Gerüst liefert EW = 52.830,80, EW_U = 42.448,32
  und ΔEW = 10.382,48; Orakel (a) wird bis 1e-10 reproduziert.
* Phase-0-Nacharbeit (Spec 00 17.5.4), soweit sie die Dateien der Phase 0b
  betrifft: Wachstumsform mit Schlüssel `index` (Default `calendar_year` =
  Kalenderjahreswert, `period_end` = Stichtagswert; **Verhaltensänderung**),
  `node_expr()`, Abbildung `per` -> Feld im Mengenbezug, Overlay-Verknüpfung
  `apply` (multiply/add), Codes und Wahrheitswerte in Ausdrücken nur in
  Vergleich und Logik, `ctx$rows()` mit `measure_id`/`local_row`,
  `item_defaults`-Semantik für optionale Blöcke und Herkunft `rule:<name>` der
  Ableitungsregeln (P0-04 bis P0-07, P0-09, P0-10).
* Phase-0-Integration der Reviews (Linsen „vertrag“ und „r-qualitaet“):
  - P0-01 bis P0-03 und P0-08 erledigt: `measure_types` mit den 37 Codes aus Spec 01
    Teil A 4.2 (keine Sammelcodes), Enums `growth_index`, `overlay_apply`, `mc_preset`,
    `levy_procedure` (Alias auch für die Zahl 559), `bgb_procedure`, `quantity_per` um
    `m2_net_floor_area`/`parking`, `rule_returns` um `value`, NA-Code `no_liquidity_limit`;
    Registry: `returns: value`, optionale Prozessfunktion `quantile_path(par, years, p)` mit
    Prüfung P4, `domain_reads` (C3).
  - YAML-Leser: Handler `int#oct`, `int#hex`, `int#base60`, `float#base60` (`0,02`, `-0,5`,
    `010` werden nicht mehr oktal gelesen), quotierte Zahlen nach denselben Regeln wie
    unquotierte (`"40.000"` bei EUR ein Fehler), eigener Fehler für nicht UTF-8-kodierte Dateien.
  - `vofi_build()`: unbekannte Wurzelschlüssel von Szenario und Overrides sind
    Validierungsfehler; Overrides auch in Pfadform; unbekannte Felder der Domänenblöcke
    (`validation.unknown_field`); Wertebereiche des Parameterschemas (`validation.range`);
    Kombinationsregeln der Kredite; Kennzahlen nach `requires` gefiltert.
  - **Verhaltensänderung** Zeitraster (R-98): `grid_overlap()`/`grid_shift_overlap()` runden
    Daten, die keine Monatsersten sind, auf den folgenden Monatsersten (wie
    `grid_shift_months()`).
  - `deep_merge()`/`is_value_form()`: Sammlungseinträge sind ohne `kind_of` nie Wertformen,
    `from:` ist nur mit einer Bibliotheks-id (`/`) ein Verweis.
  - `ctx`: `rows()`/`component_base()` nur für deklarierte Abhängigkeiten; `setting()`/`timing()`
    mit Defaults inkl. rasterabhängiger Termine; Map-Felder mit Default.
  - Engine: zusammengefasste Meldungen je Markierungsart (9.8), `model$tax$uses_inputs`,
    `meta$defaults`, Typlabels der Kreditzeilen, Einzellauf mit `store = "kpi"`.
  - `recurring.growth` als Rate (Prüfung > 1), `vofi_library_paths()` umgesetzt.
  - Testhelfer und Fixtures an die Engine-Struktur angeglichen, Stub-Liste `vofi_stubs()`,
    Batch-Tests auf Identität und N = T+1, `.lintr` ohne `cyclocomp_linter`.

