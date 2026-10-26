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
  Ableitungsregeln (P0-04 bis P0-07, P0-09, P0-10). Offen: P0-01 bis P0-03
  (Vokabulare) und P0-08 (Registry).

