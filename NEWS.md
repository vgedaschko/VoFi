# vofi 0.1.0 (in Entwicklung)

* Abschlusskorrekturen aus der Verifikation (`docs/pruefung/offene_befunde.md`):
  - Warmmieten-Kennzahlen `warm_rent_y1`, `warm_rent_change_prepost_y1`,
    `restriction_warm_rent` und `warm_rent_change_y1` werten das Bezugsjahr j* aus: das erste
    volle Betriebsjahr ab Wirksamkeit der Maßnahmen (Fertigstellung bzw.
    `rent_law.levy_effective_date`), nicht vor `analysis.stabilization_year`; der Vergleich
    nimmt die Referenz im selben Kalenderjahr, die Ampel-Restriktion und `vofi_solve()`
    (warmmietenneutrale Umlage) folgen (MRE-01, PC-01). Spec 00 §12.2 ergänzt.
  - Anzeige: EUR/m² (auch je Monat und Jahr) mit mindestens 2, EUR/kWh mit mindestens 4
    Nachkommastellen in `print()`, MC-Ausgabe und HTML-Tabellen (MRE-02).
  - Mietpfad: Die 15-Monats-Wartefrist des § 558 beginnt bei Mietbeginn nach dem Stichtag mit
    dem Mietbeginn; Staffelstufen und Erhöhungen der Bindungsmiete setzen sie neu (MRE-04,
    MRE-05).
  - Haushaltsbericht: Kreditrate nach der tilgungsfreien Zeit je Kredit (SN-01), Amortisation
    gegenüber der Referenz ohne Restwert (SN-02), Gesamtersparnis als Differenz der
    Gesamtkosten (SN-03), Nachschüsse als Teil der Gesamtkosten (SN-04), Eigenanteil je Stufe
    mit Vorfinanzierung und Kredithinweis (SN-05), aufgelöste Zinssätze in der
    Annahmentabelle (SN-06), Bandbreite aus der Belastung im Mittel der ersten 10 Jahre je
    Variante (SN-07), Bezeichnungen statt Kennungen (Varianten, Maßnahmen, Programme, Treiber;
    SN-10), Wartung in der Spalte Wartung (SN-11). `vofi_compare()` speichert die
    Variantenlabels in `meta$variant_labels`.
  - Bibliothek 2026.10.2: `costs/bewirtschaftung_immowertv_2026` gilt nach R-88 bis zur
    Fortschreibung fort (`valid_to: null`); die Warnung zum Stichtag 01.01.2027 entfällt.
  - README neu geschrieben (SN-13).

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
* Phase-0-Nacharbeit gesamt (Spec 00 17.6.5, Runden 3 und 4):
  - P0-02: alle Enums aus Spec 01 Teil A 8.1 und Teil B 8 (u. a. `building_type`,
    `component_area`, `maintenance_basis`, `carrier_class` mit `coal`, `heating_system_type`,
    `levy_mode`, `increase_policy`, `applicant`, `energy_class`) sowie die Enums der
    Feldtabellen von Teil A–C (u. a. `kg700_basis`, `effect_start`, `legal_status`) mit
    deutschen Labels; Aliase von `modernization_kind` (`erhaltung`, `heizung`, ...).
  - P0-11 (**inkompatibel**, R-110): Terminparameter `from` von `recurring` und `equity` heißt
    `start_event`.
  - P0-12 (R-110): `from` ist ausschließlich der Bibliotheksverweis; nur ein Wert nach
    `^[a-z][a-z0-9_]*(/[a-z0-9_]+)+$` ist ein Verweis, sonst Validierungsfehler
    `validation.library.ref_not_id` (Hinweis auf `start_event`, auch in `vofi_validate()`);
    Registrierung (C3) verbietet Typparameter `from` und `use`.
  - P0-13 (R-112): `set` und `overrides` von Varianten und Sets dürfen Felder setzen, die erst
    Ableitungsregeln, Typ-Defaults oder `item_defaults` füllen (Feld der Feldtabelle bzw.
    Vorlage bei vorhandenem Elternelement); `replace`/`remove` bleiben streng; `~` in
    `overrides` entfernt das Blatt.
  - P0-14 (R-114): Prüfkit P4 für Prozesse mit `linked` mit `example$.base`
    (simulierter Basisprozess, korrelierte Schocks, `NA` nur ohne Gaußbasis); Weyl-Permutationen
    des Prüfkits für k > 10 unabhängig.
  - Dokumentation: Verweise auf interne Themen und Klammerausdrücke als Code formatiert
    (keine Warnungen „Could not resolve link“ unter roxygen2 8.x).
* Stufe III (WS-H2, WS-X, Integrator):
  - `vofi_report()` (WS-H2) ist kein Stub mehr: eigenständiger HTML-Bericht im Fach- und
    Haushaltsmodus sowie als Kurzvorlage für Gremien (`template = "kurzvorlage"`/`"gremium"`),
    Ampel, Kennzahlen mit und ohne Restwert, Finanzierung mit Förder-Berechtigungs-Check,
    Mietersicht mit Rechenweg der Umlage, Risiko, Pflichtsensitivitäten (aus dem mitgeführten
    Szenario gerechnet), Zielwertsuchen, Annahmenprotokoll, VoFi-Tabelle und Hinweise; DOCX
    folgt mit v1.1 (`vofi_error_not_implemented`).
  - Optionales Steuermodul `tax_flat` (WS-X, Spec 00 10.7, Memo 06 6.2):
    vereinfachte Ertragsteuer-Näherung mit AfA (linear, degressiv, § 7b), § 82b, 15-%-Grenze,
    Verlustmodus, Veranlagungsverzögerung und Steuer auf den Restwert; Parameter in
    `inst/params/steuern_DE.yaml`. Standard bleibt `tax_none`; gesperrt für Selbstnutzer und
    steuerbefreite Rechtsträger. Die Meldung `validation.tax_module_blocked` nennt jetzt den
    Grund der Sperre.
  - Pflichtsensitivität `habenzins_abgeltung` ist mit `tax.module: flat` nicht anwendbar
    (das Modul versteuert die Habenzinsen selbst; sonst Doppelbesteuerung, 10.7).
  - `vofi_build()`: Overrides auf das Förderinstrument eines Entscheidungsknotens (z. B.
    `funding.<f>.approved = 0`) wählen den Zweig und werden nicht mehr an die
    Ausweichvariante weitergereicht (9.11 Nr. 1-3); bisher Validierungsfehler.
* Stufe III (WS-S, Integrator):
  - Referenzszenarien S1-S5 (Spec 01 Teil C 5.1-5.5) als `inst/extdata/examples/s1_*` bis
    `s5_*` mit Excel-Fassungen aller Beispiele; Integrationstests mit allen Prüfwerten.
  - Kredite (8.5): Ein Restbestand bis `stock_abs` (Rundungsrest) nach einer Vertragszahlung
    wird mit ihr getilgt; bisher fiel er im Folgejahr als Tilgung und Zins von ~1e-9 EUR an
    (S1 V2, KfW 261 mit `keep_term` und n_eff = 16).
  - DSCR und ICR (12.3): Jahre mit Kapitaldienst bzw. Zinsen bis `stock_abs` zählen nicht
    (bisher `zero_abs`; `dscr_mean` in S1 V2 lag dadurch bei 4,4e12).
  - Ledger (7.6, R-99, 10.10 Nr. 7): Die Merkzeile `loan_<k>_repayment_grant` eines Kredits
    ohne Tilgungszuschuss trägt `tax_category = not_applicable` statt
    `subsidy_repayment_grant` ohne Maßnahme.
  - Referenz-Engine (Tests): Ausdrucksknoten, Entscheidungsknoten als zwei getrennte Modelle,
    Monatsindex von Zusagedaten, die keine Monatsersten sind (3.4 Nr. 1); Invarianten- und
    Differenztest laufen für alle Beispiele einschließlich S2 und S5.
