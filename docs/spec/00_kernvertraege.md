# Spezifikation 00: Kernverträge des R-Pakets `vofi` (verbindlich)

| | |
|---|---|
| **Projekt** | VoFi-Werkzeug (R-Paket `vofi`) für Neubau und energetische Sanierung, Wohnungswirtschaft und Privatpersonen |
| **Dokument** | `docs/spec/00_kernvertraege.md` |
| **Vertragsversion** | `contract_version = "1.0.0"` (Konstante `VOFI_CONTRACT_VERSION` in `R/contracts.R`) |
| **Schemaversion Szenario** | `schema_version = 1` |
| **Stand** | 26.10.2026 |
| **Status** | **verbindlich** für alle Arbeitspakete (Phase 0 bis 3); Änderungen nur über den Integrator (Abschnitt 1.4); Review Runde 1 eingearbeitet (Abschnitt 17.2); Runde 2 „Abgleich mit dem Konzept“ eingearbeitet (Abschnitt 17.4, R-66 bis R-84); Runde 3 „Feldkatalog-Abgleich“ eingearbeitet (Abschnitt 17.5, R-85 bis R-109; Phase-0-Nacharbeit in 17.5.4) |
| **Grundlage** | Orchestrator-Entscheidungen D1–D14; Recherche-Memos 01, 02, 04, 05, 06, 07 (`docs/recherche/`); Prototypen `docs/recherche/prototypen/`; Konzept `docs/Konzept.md` einschließlich §11.2 (F1–F21), §11.3 (Annahmen bis zur Antwort des Auftraggebers) und Konzept-Review-Protokoll |
| **Folgedokument** | Spec 01 = Feldkatalog in `docs/spec/01a_*.md`, `01b_*.md`, `01c_*.md` (Felder der Domänenblöcke, Typparameter im Detail, Defaults). Spec 01 darf diese Verträge konkretisieren, aber nicht ändern. |

> **Lesehinweis.** Dieses Dokument ist die einzige Quelle der Wahrheit für Schnittstellen, Datenstrukturen, Namen und
> Algorithmen des Rechenkerns. Es ist bewusst in R-Signaturen, Listenstrukturen und Pseudocode geschrieben. Wo die Memos
> voneinander abweichen, gilt die hier getroffene Festlegung. Die Auflösungen sind in Abschnitt 16.3 mit Nummer
> (R-nn) aufgeführt und an der jeweiligen Stelle mit „(R-nn)“ markiert. Bezeichner, Schlüssel und Codes sind
> englisch bzw. ASCII-snake_case. Nutzertexte sind deutsch und stehen ausschließlich in Label-Katalogen.

---

## 1. Zweck, Geltung, Änderungsregeln, Glossar

### 1.1 Zweck

1. Die Spezifikation ermöglicht 6–8 Implementierungsagenten, **parallel auf disjunkten Dateien** zu arbeiten, ohne
   sich abzustimmen. Jede Schnittstelle zwischen Arbeitspaketen ist hier vollständig festgelegt: Signatur, Felder,
   Typen, Dimensionen, Einheiten, Vorzeichen, Fehlerverhalten.
2. Sie legt den **Rechenkern** (Zeitraster, Ledger, Instrumente, Periodenschleife, Ausgleich, Steuer-Hook, Sampler,
   Kennzahlen) so genau fest, dass zwei unabhängige Implementierungen (vektorisierte Engine von WS-D und skalare
   Referenz-Engine von WS-T) dieselben Zahlen liefern.
3. Sie fixiert die **Testorakel** (Memo 01, Beispiele (a)–(f); Vergleichsorakel (g) nach Konzept F17, 15.3) und
   Toleranzen als Abnahmekriterium.

### 1.2 Geltung und Rangfolge

| Rang | Quelle | Bemerkung |
|---:|---|---|
| 1 | Orchestrator-Entscheidungen D1–D14 | Diese Spezifikation setzt sie um. Ein erkannter Widerspruch zu D1–D14 ist ein Fehler dieser Spezifikation und wird an den Integrator gemeldet. |
| 2 | **Diese Spezifikation** (Spec 00) | verbindlich für alle Verträge |
| 3 | Spec 01 (Feldkatalog) | konkretisiert Felder und Defaults innerhalb der hier festgelegten Strukturen |
| 4 | Konzept `docs/Konzept.md` | fachliche Begründung, Festlegungen F1–F21, Annahmen zu offenen Fragen (gelten bis zur Antwort des Auftraggebers); wo diese Spezifikation davon abweicht, steht es mit Begründung in 17.4 |
| 5 | Recherche-Memos 01–07 | Hintergrund; bei Widerspruch zu Rang 1–3 nicht maßgeblich |

### 1.3 Verbindlichkeitsstufen

- **MUSS**: zwingend; Abweichung bricht den Vertrag (Review-Fehler, Vertragstest schlägt fehl).
- **SOLL**: Standard; Abweichung nur mit schriftlicher Begründung im Code-Kommentar und Meldung an den Integrator.
- **KANN**: optional; wenn umgesetzt, dann wie beschrieben.
- Prioritäten für Funktionen: **M** (Muss v1), **S** (Soll v1), **L** (spät in v1, optional), **v1.1**, **v2**.

### 1.4 Änderungsregeln

1. **Eigentum.** Diese Datei, `R/contracts.R`, `R/registry.R`, `R/vocab.R`, `R/labels.R`, `R/conditions.R`,
   `R/time-grid.R`, `R/utils-*.R`, `inst/vocab/*`, `inst/labels/de/core.yaml`, `inst/labels/de/vocab.yaml`,
   `DESCRIPTION`, `NAMESPACE`, `R/zzz.R`, `R/vofi-package.R` und die gemeinsamen Testhelfer gehören dem **Integrator**.
2. **Änderungsantrag.** Ein Agent, der eine Vertragslücke oder einen Vertragsfehler findet, ändert keine
   Integrator-Datei. Er beschreibt den Antrag im Abschnitt „Änderungsanträge“ seiner Abschlussmeldung (Nummer
   `<WS>-<lfd. Nr.>`, betroffener Abschnitt, Problem, Vorschlag) und arbeitet bis zur Entscheidung mit einer
   **internen** (nicht exportierten, modulpräfixierten) Übergangslösung in seinen eigenen Dateien.
3. **Versionierung** von `contract_version` nach SemVer: MAJOR = inkompatible Änderung einer Signatur oder Struktur;
   MINOR = neues optionales Feld, neue Kategorie, neue Funktion; PATCH = Klarstellung ohne Codewirkung. Jede Änderung
   wird in Abschnitt 17.1 (Änderungsprotokoll) mit Datum und betroffenen Arbeitspaketen eingetragen; Review-Befunde
   und ihre Entscheidung stehen in Abschnitt 17.2.
4. **Einfrieren.** Mit Abschluss von Phase 0 ist Version 1.0.0 eingefroren. MAJOR-Änderungen danach nur, wenn ein
   Orakel oder eine Entscheidung D1–D14 sonst nicht erfüllbar ist.
5. **Lücken.** Was hier nicht geregelt ist, darf ein Agent nur **intern** lösen. Er darf keine neuen exportierten
   Funktionen, Szenario-Schlüssel, Ledger-Kategorien, Vokabularcodes oder Label-Dateien außerhalb seiner Zuständigkeit
   anlegen. Neue Typen (eine Datei je Typ) innerhalb der eigenen Zuständigkeit sind erlaubt, sofern ihre Zeilen nur
   bestehende Vokabularcodes verwenden.

### 1.5 Glossar (verbindliche Begriffe)

| Deutsch (Anzeige) | Bezeichner | Art | Definition / Bemerkung |
|---|---|---|---|
| Vollständiger Finanzplan | `vofi` | Paket | Methode nach Grob: alle Zahlungen je Periode, Finanzierungssaldo ≡ 0 |
| Szenario (kanonisch) | `vofi_scenario` | S3-Klasse | eingelesene, normalisierte Eingabe: Basis + Varianten + Overlay + Herkunft (4.13) |
| aufgelöste Variante | `vofi_spec` | S3-Klasse | eine Variante, Schichten gemischt, Bibliothek aufgelöst, expandiert (Komponentenebene) |
| Modell | `vofi_model` | S3-Klasse | rechenfertig: Raster, sortierte Knoten, Instrumente, Ketten, Sampler-Plan, Steuermodul, KPI-Satz |
| Zeitraster | `vofi_grid` | S3-Klasse | Vektor der Periodenlängen in Monaten mit Datums- und Phasenangaben (Abschnitt 3) |
| Zeitpunkt / Periode | `t` (0…T) | ganze Zahl | t = 0: Bewertungsstichtag (Länge 0); Periode t = (Ende t−1, Ende t] |
| Spaltenindex | `j = t + 1` | ganze Zahl | Spalte j einer N × (T+1)-Matrix gehört zu t = j − 1; **Spalte 1 = t0** |
| Simulationslauf | `sim`, Anzahl `n` bzw. `N` | ganze Zahl | Zeile einer N × (T+1)-Matrix; deterministisch: N = 1 |
| Block / Replikat | `block`, `block_size` | ganze Zahl | Einheit der Zufallsziehung = LHS-Replikat fester Größe (Default 200 Läufe; Anzahl R = n_sim / block_size; 11.4, R-73) |
| Zahlungskomponente | `component`, Art `flow` | Registry | erzeugt exogene Ledger-Zeilen (`build(spec, ctx)`) |
| Kreditinstrument | `instrument` | Registry | Zustandsautomat (`init`/`step`/`prepay`/`capacity`) |
| Ausgleichsaktion | `account_action` | Registry | Schritt der Überschuss- bzw. Defizitkette (Ü1–Ü4, D1–D4) |
| Expander | `expander` | Registry | übersetzt Domänenblöcke in Komponenten und Instrumente |
| Rechtsregel | `rule` | Registry | versionierte, vektorisierte Funktion, Auswahl nach `legal_state` |
| Kennzahl | `kpi` | Registry | `compute(core, ctx)` → `vofi_kpi_value` |
| Steuermodul | `tax` | Registry | Objekt mit S3-Methoden `tax_init`/`tax_step`/`tax_finalize` |
| Laufkontext | `ctx` | gesperrte Umgebung | Lesezugriff der Typen auf Raster, Werte, Markt, Register (Abschnitt 6) |
| Ziehungen | `vofi_draws` | S3-Klasse | Ergebnis des Samplers je Chunk (Abschnitt 11.8) |
| Ledger (Zahlungsbuch) | `vofi_ledger` | S3-Klasse | Zeilenmetadaten + Wertmatrizen (Abschnitt 7.4) |
| Zeile | `vofi_row` | Objekt | eine Ledger-Zeile mit Pflicht-Tags (7.1) |
| Rechenkern-Ergebnis | `core` | Liste | Ergebnis der Periodenschleife, Eingabe der Kennzahlen (9.3, 12.1) |
| Abschnitt der VoFi-Tabelle | `section` | Vokabular | `project`, `grants`, `equity`, `loans`, `overdraft`, `deposit`, `tax`, `check`, `stocks`, `memo` |
| Kategorie | `category` | Vokabular | fachliche Zeilenart innerhalb eines Abschnitts (7.6) |
| Steuerkategorie | `tax_category` | Vokabular | Memo 06 §7.2 + `not_applicable` (10.8) |
| zahlungswirksam | `cash` | logisch | `FALSE` z. B. für Tilgungszuschuss, Disagio, Mengen, Marktwert |
| Zahlungsfolge der Investition | Abschnitt `project`, Summe `cf_project` | Anzeige-Summe | Summe aller `project`-Zeilen; existiert nur in der Tabelle, nicht im Ledger (R-19) |
| Investitionszuschuss | Kategorie `grant` | Kategorie | Abschnitt `grants`, Summe `grant_cash` in der Tabelle |
| Einlage / Entnahme / Nachschuss | `equity_in` / `equity_out` / `equity_call` | Kategorie bzw. Engine-Zeile | Nachschuss = Engpass-Policy D4 (endogen) |
| nicht gedeckter Fehlbetrag | `shortfall` | Engine-Zeile | nur bei Policy `stop` (9.3, R-32) |
| Kredit k: Aufnahme, Tilgung, Schlusstilgung, Sondertilgung, Sollzinsen, Gebühren | `loan_<k>_draw`, `_repay`, `_repay_balloon`, `_prepay`, `_interest`, `_fees` | Ledger-Schlüssel | k = id im Block `financing` |
| Tilgungszuschuss / Disagio (Merkzeilen) | `loan_<k>_repayment_grant`, `loan_<k>_disagio` | Ledger-Schlüssel | `cash = FALSE`, `kind = "memo"` |
| Kreditstand | `loan_<k>_balance` | Bestand | B_k,t am Ende von t |
| Kontokorrent (Regeltranche): Aufnahme, Tilgung, Sollzinsen, Stand | `od_draw`, `od_repay`, `od_interest`, `od_balance` | Engine-Zeilen | KK_t |
| Kontokorrent-Strafzinstranche | `odp_draw`, `odp_repay`, `odp_interest`, `odp_balance` | Engine-Zeilen | KKP_t, Policy `penalty_rate` (R-31) |
| Geldanlage: Anlage, Auflösung, Habenzinsen, Stand | `dep_invest`, `dep_withdraw`, `dep_interest`, `dep_balance` | Engine-Zeilen | G_t |
| Abgeltungsteuer auf Habenzinsen | `dep_wht` | Engine-Zeile | Abschnitt `tax`, pauschaler Satz (D5) |
| Ertragsteuern (Slot) | `tax` | Engine-Zeile | v1 = 0 mit Vermerk „nicht berücksichtigt“ |
| offene Steuer am Horizont | `tax_liability` | Bestand | aus `tax_finalize`; mindert den Endwert |
| Finanzierungssaldo | `balance_check` | Prüfzeile | Summe aller zahlungswirksamen Zeilen je t; muss 0 sein (I1) |
| Bestandssaldo | `net_position` | Bestand | BS_t = G_t − KK_t − KKP_t − Σ_k B_k,t − tax_liability_t |
| VoFi-Endwert | `terminal_value` | KPI | EW = BS_T |
| Endwert Unterlassungsalternative | `terminal_value_opp` | KPI | EW_U |
| Endwertdifferenz (Primärkennzahl) | `delta_terminal_value` | KPI | ΔEW = EW − EW_U (D9); Primärkennzahl außer bei Bestandsprojekten (12.3a) |
| Endwertdifferenz zur Referenzvariante | `delta_vs_reference` | KPI | **Vergleichsregel** ΔEW_A − ΔEW_ref: jede Variante gegen ihre eigene Unterlassungsalternative mit ihren eigenen Nachschüssen (12.6, R-27, R-66); Primärkennzahl bei Bestandsprojekten (12.3a) |
| Primärkennzahl | `analysis.primary_kpi` | Code | `auto` (12.3a), `delta_terminal_value` oder `delta_vs_reference` |
| Unterlassungsalternative | `opportunity` | Alternative | gleiche Einlagen inkl. Nachschüsse der Investition und gleiche Entnahmen, keine Investition, keine Kredite, **keine eigenen Nachschüsse** (9.5); bei Sacheinlage: Verkauf des Bestands zum Stichtag (9.5 Nr. 7); bei Bestandsprojekten als Referenz unzulässig, intern für die Vergleichsregel genutzt |
| Referenzvariante | `project.reference_variant` | Schlüssel | Bezug für `vofi_compare()` (9.6); bei Bestandsprojekten **Pflicht** (Bestands- bzw. Ohnehin-Variante, 12.3a, R-68) |
| Bestandsprojekt | `project_type` ∈ {`sanierung_eh`, `sanierung_einzelmassnahmen`, `sanierung_stufenweise`, `heizungstausch`} | Begriff | Projekt an einem vorhandenen Gebäude ohne Erwerb (12.3a) |
| Bestandswert, Sacheinlage | `building.existing_value_eur`, Engine-Zeile `equity_in_kind` | Feld / Zeile | Verkehrswert des Bestands zum Stichtag abzüglich Restschuld der Bestandsdarlehen, zahlungsunwirksame Einlage in t = 0 aller Varianten (9.3, 9.5 Nr. 7, R-68) |
| Bestandsdarlehen | `financing.<k>.existing: true`, Merkzeile `loan_<k>_assumed` | Parameter | auf dem Objekt lastendes Darlehen mit Restschuld in t = 0 ohne Auszahlung, in allen Gebäudevarianten identisch (8.2, R-68) |
| Rendite der Mehrinvestition | `incremental_return` | KPI | konstanter Habenzins h*, bei dem `delta_vs_reference` = 0 wird (12.6, 12.8, R-68) |
| Entscheidungsknoten, Ausweichvariante | `funding.<id>.fallback_variant` | Feld | Förderzusage vor Projektbeginn wählt je Lauf zwischen Variante „mit Zusage“ und Ausweichvariante (9.11, R-71) |
| Restwertpfad | Kategorie `residual_path` | Merkzeile | RW_t = Liquidationswert bei Verkauf in t (nach Verkaufskosten) je Periode (7.6, 12.2, R-72) |
| Basisfallwert | `ctx$param_base()`, `ctx$value_base()`, `ctx$component_base()` | Funktion | deterministischer Wert des Basisfalls des Modells, in allen Läufen gleich (6.3, R-70) |
| Nachfinanzierung | `amount_eur: topup` | Wertform | laufspezifischer Mehrbedarf gegenüber dem Basisfall in der Bauphase (8.7, R-69) |
| Ampel (zweistufig) | `traffic_light` | Ergebnisfeld | Wirtschaftlichkeit (Stufe 1) und Restriktionen als K.-o.-Kennzeichen (Stufe 2) (12.9, R-74) |
| Szenario-Set „vorsichtig“ | `scenario_sets.vorsichtig` (`generate: cautious`) | Szenario-Set | die einflussreichsten Treiber des Tornados gleichzeitig auf ihrem ungünstigen P10/P90-Wert (4.11, R-74) |
| Stabilisierungsjahr | `analysis.stabilization_year` | Feld | erstes Kalenderjahr der DSCR-/ICR-Auswertung (12.3, R-77) |
| Kalenderjahresindex | `grid_index_year()`, `ctx$index_year()` | Funktion | Preisindex, der je Kalenderjahr konstant ist; Pflicht für laufende Jahresbeträge (3.6, 7.12) |
| Verschiebung (stochastischer Termin) | `*_delay_months`, `useful_life_years` | Parameter | laufspezifische Verschiebung von Zahlungsterminen in Zahlungskomponenten (3.9); Instrumente bleiben deterministisch (R-47) |
| Restwert | Kategorie `residual_value` | Kategorie | nur in t = T zulässig; KPI-Varianten `_ex_rv` (12.5) |
| Marktwert (Merkzeile) | Kategorie `market_value` | Kategorie | V_t für LTV, `cash = FALSE` |
| EK-Rentabilität klassisch / modifiziert (R3) / Equity-IRR (R2) | `roe_classic` / `roe_mirr` / `roe_irr` | KPI | Standard ist R3 (D9) |
| Entnahme-Äquivalent | `withdrawal_equivalent` | KPI | 12.8 |
| Dynamische Amortisationsdauer | `payback_time` | KPI | in Jahren τ (12.3); „mit Restwert“ als Vermögensamortisation mit Restwertpfad, `_ex_rv` nur Guthaben und Schulden (R-72) |
| Rechtsstand | `project.legal_state` | Datum | Auswahl von Regeln und Bibliothekseinträgen (4.10) |
| anhängige Reform | `project.pending_reforms` | Codes | Schalter, Standard leer (D10) |
| Parameterbibliothek, Eintrag | `library`, `entry` | Dateien | ein Eintrag je Datei, id = relativer Pfad (4.9) |
| Bibliotheksverweis | `from:` | Wertform | 4.9 |
| Element-Defaults | `item_defaults` (nur `global.yaml`) | reservierter Schlüssel | Vorlage je Sammlung bzw. optionalem Block, nach Schicht 8 und den Ableitungsregeln unter jedes vorhandene Element gemischt (Element gewinnt; 4.7, R-85) |
| Ableitungsregel | `rule:<name>` (WS-A, `R/scenario-layers.R`) | Funktion | setzt nach Schicht 8 und vor `item_defaults` und den Expandern fehlende Domänenblätter aus anderen Feldern (Werte, Codes, Bezugs- und Ausdrucksknoten); keine Registry-Regel (4.7, R-86) |
| Perspektive | `project.perspective` | Code | `wu_kommunal`, `wu_genossenschaft`, `wu_privat`, `kleinvermieter`, `selbstnutzer` (R-08) |
| Steuerregime | `project.tax_regime` | Code | Memo 06 §7.1 (R-08) |
| Ohnehin-Anteil | `ohnehin_share` / `ohnehin_cost_eur` | Feld | Memo 02 §1.4 |
| Modernisierungsumlage | Kategorie `modernization_levy` | Kategorie | §§ 559, 559e BGB; Zeilen `levy_<maßnahme>` der Komponente `rent_path` (R-63) |
| ersparte Miete (Selbstnutzer) | Kategorie `imputed_rent` | Kategorie | kalkulatorisch, `tax_category = imputed_benefit` |
| Fach- / Haushaltsmodus | `report_mode = "expert"` / `"household"` | Code | D11 |
| Stochastik-Overlay | Block `stochastic` | Block | Verteilungen und Prozesse mit `target` (4.3, 11) |
| gemeinsame Zufallszahlen | CRN | Regel | 11.10 |

---

## 2. Paketlayout, Zuständigkeiten, Konventionen

### 2.1 Paketwurzel

Die **Repository-Wurzel `/home/user/VoFi` ist die Paketwurzel** (dort liegen `DESCRIPTION`, `R/`, `inst/`, `tests/`).
`docs/`, `data-raw/`, `bench/` und `.github/` stehen in `.Rbuildignore`. Das Konzept und die Memos bleiben unter `docs/`.

### 2.2 Verzeichnisbaum (vollständig für v1)

```text
VoFi/                                   # Paketwurzel = Repo-Wurzel
├── DESCRIPTION  NAMESPACE  NEWS.md  LICENSE  README.md
├── .Rbuildignore  .lintr  .gitignore
├── R/
│   ├── vofi-package.R  zzz.R  contracts.R  registry.R  registry-testkit.R  vocab.R  labels.R  conditions.R
│   ├── utils-merge.R  utils-path.R  utils-format.R  utils-hash.R  utils-seed.R  utils-misc.R
│   ├── time-grid.R
│   ├── values-normalize.R  values-resolve.R  expr.R  schema.R
│   ├── io-yaml.R  io-excel-read.R  io-excel-write.R  io-excel-template.R
│   ├── scenario-read.R  scenario-layers.R  scenario-library.R  scenario-variants.R  scenario-provenance.R
│   ├── validate-structure.R  validate-types.R  validate-refs.R  validate-plausibility.R  validate-report.R
│   ├── expand-core.R  expand-measures.R  expand-unit-groups.R  expand-funding.R  expand-energy.R
│   ├── expand-residual.R  expand-household.R
│   ├── rules-mietrecht.R  rules-co2kostaufg.R  rules-funding.R  rules-grest.R
│   ├── sampling-rng.R  sampling-plan.R  sampling-dependence.R  sampling-draw.R  sampling-design.R
│   ├── dist-fixed.R  dist-normal.R  dist-truncnorm.R  dist-lognormal.R  dist-uniform.R  dist-triangular.R
│   ├── dist-pert.R  dist-beta.R  dist-bernoulli.R  dist-discrete.R  dist-empirical.R
│   ├── process-ar1.R  process-linked-ar1.R  process-vasicek.R  process-mr-trend.R  process-gbm.R
│   ├── process-scenario-mix.R  process-iid.R  process-fixed-path.R
│   ├── engine-build.R  engine-context.R  engine-flows.R  engine-auto.R  engine-accounts.R
│   ├── engine-balance.R  engine-ledger.R  engine-run.R  engine-checks.R  engine-store.R
│   ├── account-actions.R  opportunity.R
│   ├── tax-hook.R  tax-none.R  tax-flat.R
│   ├── type-flow-equity.R  type-flow-custom-series.R  type-flow-recurring.R  type-flow-capex.R
│   ├── type-flow-land.R  type-flow-acquisition-cost.R  type-flow-replacement.R  type-flow-rent-path.R
│   ├── type-flow-operating-cost.R  type-flow-property-tax.R
│   ├── type-flow-maintenance.R  type-flow-energy-cost.R  type-flow-co2-cost.R  type-flow-pv.R
│   ├── type-flow-grant.R  type-flow-tax-credit-35c.R  type-flow-imputed-rent.R  type-flow-residual-value.R
│   ├── type-flow-share-of.R  type-flow-tenant-costs.R
│   ├── type-inst-loan-core.R  type-inst-annuity-loan.R  type-inst-installment-loan.R  type-inst-bullet-loan.R
│   ├── kpi-core.R  kpi-value.R  kpi-returns.R  kpi-liquidity.R  kpi-realestate.R  kpi-household.R
│   ├── kpi-withdrawal.R
│   ├── mc.R  mc-stats.R  compare.R  sensitivity.R  solve.R
│   ├── methods-scenario.R  methods-result.R  methods-mc.R  methods-compare.R  methods-misc.R
│   ├── report-table.R  report-views.R  report-plot.R  report-excel.R  report-html.R
│   └── app.R
├── inst/
│   ├── extdata/
│   │   ├── defaults/global.yaml
│   │   ├── profiles/{wu_kommunal,wu_genossenschaft,wu_privat,kleinvermieter,selbstnutzer}.yaml
│   │   ├── library/{funding,legal,prices,costs,processes,valuation}/<eintrag>.yaml
│   │   └── examples/{s1_…,s2_…,s3_…,s4_…,s5_…,grob_lehrbuch_a,skeleton}.yaml  *.xlsx
│   ├── labels/de/
│   │   ├── core.yaml  vocab.yaml  engine.yaml  validation.yaml  io.yaml  excel_input.yaml  excel_export.yaml
│   │   ├── sampling.yaml  mc.yaml  kpi.yaml  report.yaml  expand.yaml  tax.yaml
│   │   └── types/<kind>/<name>.yaml    # je registriertem Typ, Ordner = Art (flow, instrument, account_action,
│   │                                   # expander, distribution, process, kpi, tax, rule), 2.10
│   ├── vocab/  sections.yaml  categories.yaml  tax_categories.yaml  asset_types.yaml  measure_types.yaml
│   │           enums.yaml  units.yaml  na_reasons.yaml  conditions.yaml  row_extra_fields.yaml
│   ├── params/steuern_DE.yaml           # nur WS-X (tax_flat)
│   ├── templates/vofi_eingabe.xlsx   templates/report/{vofi_bericht.Rmd,vofi_bericht.css,referenz.docx}
│   ├── schema/vofi-scenario.schema.json
│   └── shiny/vofi/                      # v1.1
├── tests/
│   ├── testthat.R
│   └── testthat/
│       ├── helper-contracts.R  helper-fixtures.R  helper-oracles.R  helper-reference-engine.R
│       ├── helper-<ws>.R               # optional je Arbeitspaket
│       ├── test-<R-datei>.R            # je R-Datei eine Testdatei, gleicher Eigentümer; Name = test- + Name der
│       │                               # R-Datei (z. B. test-type-flow-capex.R, test-type-inst-loan-core.R)
│       ├── test-library.R  test-profiles.R   # Datentests ohne R-Datei: Bibliothek (WS-L), Defaults/Profile (WS-A)
│       ├── test-contract-types.R  test-invariants.R  test-oracles.R  test-batch-invariance.R
│       ├── test-mc-statistics.R  test-io-roundtrip.R  test-scenarios-s1-s5.R  test-snapshots-*.R
│       ├── fixtures/{oracles,scenarios,excel,library}/
│       └── _snaps/
├── vignettes/  vofi-einfuehrung.Rmd  vofi-methodik.Rmd  vofi-szenarien.Rmd  vofi-wohnungsunternehmen.Rmd
│               vofi-selbstnutzer-sanierung.Rmd  vofi-monte-carlo.Rmd  vofi-erweitern.Rmd
├── data-raw/   build_template.R  build_schema.R  build_examples_xlsx.R  export_oracles.py  vofi_ref.py
├── bench/      bench_engine.R  bench_mc.R
└── docs/       Konzept.md  recherche/  spec/
```

### 2.3 Arbeitspakete und Wellen (D14)

Phase 0 ist seriell (Integrator). Danach folgen **vier Wellen mit je 2–4 Paketen**. Der Workflow-Runner führt höchstens
zwei Agenten gleichzeitig aus. Die Paare in der Spalte „Paarung“ laufen zusammen, die Paare einer Welle nacheinander.
Jede Welle endet mit einem Integrator-Merge (Reihenfolge wie in der Tabelle), `roxygen2::roxygenise()`, voller
Testsuite und `R CMD check`.

| Welle | Paarung | Paket | Inhalt | hängt ab von (Vertrag/Mock) |
|---|---|---|---|---|
| 0 | – | **I** Integrator | Verträge, Registry, Prüfkit (`registry-testkit.R`, 5.6), Vokabulare, Labels, Bedingungen, Utils, `time-grid.R`, `vofi_param()`-Konstruktor, Stubs aller Exporte, Testhelfer, CI; Walking Skeleton (Anhang A) mit minimalen Implementierungen aller dafür nötigen Funktionen (YAML-Lesen, Normalisieren inkl. `node_*`, Auflösen ohne Bibliothek, minimaler Ausdrucksauswerter `expr_parse`/`expr_eval` (4.5), Build, Kontext inkl. `eng_context_from_parts()` (6.1), Periodenschleife, `tax_none`, Typen `equity`, `custom_series`, `recurring` (7.12), `bullet_loan`, Aktionen `od_repay`, `dep_invest`, `dep_withdraw`, `od_draw`, `equity_call`, KPIs `terminal_value`, `terminal_value_opp`, `delta_terminal_value`, `print`) – jeweils in der Datei des späteren Eigentümers, der sie übernimmt und ausbaut | – |
| 1 | 1a | **WS-D** Engine | `values-resolve.R`, `engine-*`, `account-actions.R`, `opportunity.R`, `tax-hook.R`, `tax-none.R` | Spec 00, `make_ctx()`, `fake_draws()` |
| 1 | 1a | **WS-T** Orakel/Referenz | Orakel-Fixtures, `helper-oracles.R`, skalare Referenz-Engine, Zufallsszenario-Generator, `test-oracles.R`, `test-invariants.R` | Spec 00 (bewusst anderer Agent als WS-D) |
| 1 | 1b | **WS-C** Sampling | `sampling-*`, `dist-*`, `process-*` | Spec 00 §11 |
| 1 | 1b | **WS-B** Schema/Validierung | `schema.R`, `validate-*`, `expr.R` | Spec 00 §4, §5.4 |
| 2 | 2a | **WS-F** Instrumente | `type-inst-*` | `make_ctx()`, §8 |
| 2 | 2a | **WS-A** Eingabe | `io-yaml.R`, `values-normalize.R`, `scenario-*` (inkl. `item_defaults` und Ableitungsregeln `rule:<name>`, 4.7), Profile, `global.yaml`, `test-profiles.R`, Minimal-Fixtures | §4 |
| 2 | 2b | **WS-E** Zahlungsbausteine und Mietrecht | `type-flow-*` (ohne `grant`, `tax-credit-35c`), `rules-mietrecht.R`, `rules-co2kostaufg.R`, `rules-grest.R` (Regeln, die die eigenen Typen aufrufen, 5.3) | `make_ctx()`, §7 |
| 2 | 2b | **WS-D2** Kennzahlen | `kpi-*` | `example_core()`, §12 |
| 3 | 3a | **WS-E2** Expander/Förderung | `expand-*`, `rules-funding.R`, `type-flow-grant.R`, `type-flow-tax-credit-35c.R` | §4.12, WS-E/F |
| 3 | 3a | **WS-G** Analyse | `mc.R`, `mc-stats.R`, `compare.R`, `sensitivity.R`, `solve.R` | §9, §11, §12 |
| 3 | 3b | **WS-L** Bibliothek | `inst/extdata/library/**` (nur Daten), `test-library.R` | §4.9, §2.11 |
| 3 | 3b | **WS-H** Ausgabe | `methods-*`, `report-table.R`, `report-views.R`, `report-plot.R`, `report-excel.R` | `example_result()`, §13 |
| 4 | 4a | **WS-A2** Excel-Eingabe | `io-excel-*`, `data-raw/build_template.R`, `build_examples_xlsx.R` | §4.14 |
| 4 | 4a | **WS-S** Referenzszenarien | `inst/extdata/examples/s1…s5`, `test-scenarios-s1-s5.R` | alle |
| 4 | 4b | **WS-H2** Bericht | `report-html.R`, `inst/templates/report/*` | WS-H |
| 4 | 4b | **WS-X** Steuer (L) | `tax-flat.R`, `inst/params/steuern_DE.yaml` | §10 |
| nach 4 | – | Verifikation (Phase 3) | Differenztests, Orakel, Invarianten, Metamorphe Tests, Härtung | – |
| v1.1 | – | **WS-J** Shiny | `app.R`, `inst/shiny/vofi/` | API stabil |

### 2.4 Datei-Zuständigkeitskarte (verbindlich)

Testdateien gehören dem Eigentümer der getesteten Datei. Label-Dateien `types/<kind>/<name>.yaml` gehören dem
Eigentümer der Typdatei. S3-Methoden stehen in der Datei des in 13.6 markierten Eigentümers der Klasse (ohne Markierung:
WS-H in `R/methods-*.R`). Ein Agent ändert ausschließlich Dateien seines Pakets.

| Datei(en) | Paket | Exporte bzw. Inhalt |
|---|---|---|
| `DESCRIPTION`, `NAMESPACE`, `NEWS.md`, `LICENSE`, `README.md`, `.Rbuildignore`, `.lintr`, CI | I | – |
| `R/vofi-package.R`, `R/zzz.R` | I | Paketdoku, `.onLoad`, `globalVariables` |
| `R/contracts.R` | I | `vofi_row`, `vofi_flows`, `vofi_asset`, `vofi_measure`, `vofi_kpi_value`; interne Konstruktoren/Validatoren aller Klassen; `VOFI_CONTRACT_VERSION`; Konstante `vofi_tol` (2.13) |
| `R/registry.R` | I | `vofi_type`, `vofi_register_type`, `vofi_types`, `vofi_type_info`, `vofi_check_type` |
| `R/registry-testkit.R` | I | intern: `reg_test_grid`, `reg_fake_draws`, `reg_test_ctx`, `reg_example_core` (Prüfkit der Vertragstests, 5.6) |
| `R/vocab.R`, `R/labels.R`, `R/conditions.R` | I | intern: `vocab_*`, `lbl`, `msg`, `vofi_abort`, `vofi_warn`, `vofi_inform` |
| `R/utils-merge.R`, `utils-path.R`, `utils-format.R`, `utils-hash.R`, `utils-seed.R`, `utils-misc.R` | I | intern: `deep_merge`, `is_value_form`, `path_get/set/remove/exists`, `fmt_*`, `stable_hash`, `with_stream`, `%\|\|%` |
| `R/time-grid.R` | I | `vofi_time_grid`; intern `grid_*` (Abschnitt 3); Methoden `print`/`as.data.frame` für `vofi_grid` |
| `R/values-normalize.R` | WS-A | intern: Wertgrammatik → Knoten (4.5): `node_normalize()`, Knotenkonstruktoren `node_const`, `node_ref`, `node_schedule`, `node_growth`, `node_expr` (6.4, R-91) |
| `R/values-resolve.R` | WS-D | intern: Knoten → N-Vektor / N × (T+1) (6.3), Präfix `res_` |
| `R/expr.R` | WS-B | intern: `expr_parse`, `expr_symbols`, `expr_eval` (4.5); Minimalfassung aus Phase 0 |
| `R/schema.R` | WS-B | `vofi_param`, `vofi_json_schema` |
| `R/io-yaml.R` | WS-A | intern: `io_read_yaml_utf8`, `io_write_yaml`, YAML-Handler |
| `R/io-excel-read.R`, `io-excel-write.R`, `io-excel-template.R` | WS-A2 | `vofi_excel_template` |
| `R/scenario-read.R` | WS-A | `vofi_read_scenario`, `vofi_write_scenario`, `vofi_scenario`, `vofi_example` |
| `R/scenario-layers.R`, `scenario-provenance.R` | WS-A | `vofi_resolve`; intern Aufbau des Build-Kontexts `bctx` (`scn_bctx()`, 6.4), reservierte Schlüssel der Defaults-Dateien, Element-Defaults (`item_defaults`) und Ableitungsregeln `rule:<name>` (4.7, R-85, R-86) |
| `R/scenario-library.R` | WS-A | `vofi_library`, `vofi_library_paths` |
| `R/scenario-variants.R` | WS-A | `vofi_variants` |
| `R/validate-*.R` | WS-B | `vofi_validate`; Methoden für `vofi_validation` in `validate-report.R` |
| `R/expand-*.R`, `R/rules-funding.R` | WS-E2 | intern; `typedef_expander_*`, `typedef_rule_*` (Förderregeln) |
| `R/rules-mietrecht.R`, `R/rules-co2kostaufg.R`, `R/rules-grest.R` | WS-E | intern; `typedef_rule_*` (Mietrecht, CO2KostAufG, Grunderwerbsteuer) |
| `R/sampling-*.R`, `R/dist-*.R`, `R/process-*.R` | WS-C | intern; `typedef_dist_*`, `typedef_process_*`; `smp_plan_union()`; Methoden für `vofi_draws` in `sampling-draw.R` |
| `R/engine-build.R` | WS-D | `vofi_build` |
| `R/engine-run.R` | WS-D | `vofi_run`, `vofi_sim` |
| `R/engine-context.R`, `engine-flows.R`, `engine-auto.R`, `engine-accounts.R`, `engine-balance.R`, `engine-ledger.R`, `engine-checks.R`, `engine-store.R` | WS-D | intern; `eng_context_from_parts()` (6.1) |
| `R/account-actions.R` | WS-D | `typedef_action_*` (alle Aktionen aus 8.9) |
| `R/opportunity.R` | WS-D | `vofi_opportunity` |
| `R/tax-hook.R` | WS-D | `tax_init`, `tax_step`, `tax_finalize`, `vofi_register_tax_module`, `vofi_tax_module_simple` |
| `R/tax-none.R` | WS-D | `typedef_tax_none`, Methoden `tax_*.tax_none` |
| `R/tax-flat.R`, `inst/params/steuern_DE.yaml`, `inst/labels/de/types/tax/flat.yaml` | WS-X | `typedef_tax_flat`, Methoden `tax_*.tax_flat`; Labels inkl. `report.<name>` (10.5) |
| `R/type-flow-*.R` (außer `grant`, `tax-credit-35c`) | WS-E | `typedef_<typ>` |
| `R/type-flow-grant.R`, `R/type-flow-tax-credit-35c.R` | WS-E2 | `typedef_grant`, `typedef_tax_credit_35c` |
| `R/type-inst-*.R` | WS-F | `typedef_annuity_loan`, `typedef_installment_loan`, `typedef_bullet_loan`; intern `inst_loan_*` |
| `R/kpi-*.R` | WS-D2 | `vofi_kpis`, `vofi_register_kpi`; `typedef_kpi_*` |
| `R/mc.R`, `R/mc-stats.R` | WS-G | `vofi_mc` |
| `R/compare.R` | WS-G | `vofi_compare`; intern Ampel (`cmp_traffic_light()`, 12.9) und generiertes Set „vorsichtig“ (`cmp_cautious()`, 4.11); eine eigene Datei `compare-cautious.R` gibt es nicht (R-104) |
| `R/sensitivity.R`, `R/solve.R` | WS-G | `vofi_sensitivity`, `vofi_solve` |
| `R/methods-*.R` | WS-H | S3-Methoden der Klassen ohne Eigentümermarkierung in 13.6 |
| `R/report-table.R`, `R/report-views.R` | WS-H | `vofi_table`, `vofi_ledger`, `vofi_tenant_view`, `vofi_household_view` |
| `R/report-plot.R`, `R/report-excel.R` | WS-H | `vofi_plot`, `vofi_export_excel` |
| `R/report-html.R`, `inst/templates/report/*` | WS-H2 | `vofi_report` |
| `R/app.R` | I (Stub), v1.1 WS-J | `vofi_app` |
| `inst/vocab/*`, `inst/labels/de/core.yaml`, `inst/labels/de/vocab.yaml` | I | Vokabulare (7.5–7.6, 10.8) |
| `inst/labels/de/engine.yaml`, `tax.yaml` | WS-D | `tax.yaml`: Texte des Steuer-Hooks und von `tax_none`; modulspezifische Texte in `types/tax/<modul>.yaml` |
| `inst/labels/de/validation.yaml` | WS-B | |
| `inst/labels/de/io.yaml` | WS-A | |
| `inst/labels/de/excel_input.yaml` | WS-A2 | Schlüssel `excel_input.*` |
| `inst/labels/de/excel_export.yaml` | WS-H | Schlüssel `excel_export.*` |
| `inst/labels/de/sampling.yaml` | WS-C | |
| `inst/labels/de/mc.yaml` | WS-G | |
| `inst/labels/de/kpi.yaml` | WS-D2 | |
| `inst/labels/de/report.yaml` | WS-H (WS-H2 nur `report.html.*`) | |
| `inst/labels/de/expand.yaml` | WS-E2 | |
| `inst/extdata/defaults/global.yaml`, `profiles/*.yaml` | WS-A (Werte nach Spec 01) | |
| `inst/extdata/library/**` | WS-L | |
| `inst/extdata/examples/s*.yaml` | WS-S; `skeleton.yaml` I; `grob_lehrbuch_a.yaml` WS-T | |
| `inst/schema/vofi-scenario.schema.json`, `data-raw/build_schema.R` | WS-B | generiert |
| `inst/templates/vofi_eingabe.xlsx`, `data-raw/build_template.R`, `data-raw/build_examples_xlsx.R` | WS-A2 | generiert |
| `data-raw/export_oracles.py`, `data-raw/vofi_ref.py`, `tests/testthat/fixtures/oracles/*` | WS-T | |
| `tests/testthat.R`, `tests/testthat/helper-contracts.R`, `helper-fixtures.R`, `test-contract-types.R`, `test-batch-invariance.R`, `fixtures/scenarios/{skeleton,oracle_a}.yaml` | I | |
| `tests/testthat/fixtures/scenarios/*` (übrige), `fixtures/library/*` | WS-A | |
| `tests/testthat/test-io-roundtrip.R`, `fixtures/excel/*` | WS-A2 | |
| `tests/testthat/helper-oracles.R`, `helper-reference-engine.R`, `test-oracles.R`, `test-invariants.R` | WS-T | |
| `tests/testthat/helper-tax-test-module.R` | WS-D | Test-Steuermodul mit Pauschalsatz und linearer AfA für die Pflichttests der Schnittstelle ab Phase 1 (10.10, R-78) |
| `inst/extdata/library/VERSION` | WS-L | Bibliotheksstand `JJJJ.MM.n` (4.9, R-80) |
| `tests/testthat/test-library.R` | WS-L | Datentest der Bibliothek: Eintragsschema (4.9), Freigabe (4.10), Codes der Nutzlasten ⊆ Vokabulare (2.11), alle `from`/`use`-Verweise lösen auf (R-89, R-104) |
| `tests/testthat/test-profiles.R` | WS-A | Datentest von `global.yaml` und Profilen: reservierte Schlüssel, Profilpfade (R-76), alle `from`/`use`-Verweise lösen auf (4.7, R-85) |
| `tests/testthat/test-mc-statistics.R` | WS-C (Sampler-Teil) und WS-G (`test-mc-results.R`) | getrennte Dateien |
| `vignettes/*` | Phase 3 (Integrator vergibt) | |
| `bench/bench_engine.R` | WS-D | |
| `bench/bench_mc.R` | WS-G | |

### 2.5 DESCRIPTION (Entwurf, verbindlich bis auf Personenangaben)

```text
Package: vofi
Type: Package
Title: Vollständiger Finanzplan (VoFi) mit Monte-Carlo-Simulation für Wohngebäude
Version: 0.1.0
Authors@R: person("<Vorname>", "<Nachname>", email = "<maintainer@example.org>", role = c("aut", "cre"))
Description: Wirtschaftlichkeitsbewertung von Neubau und energetischer
    Sanierung von Wohngebäuden in Deutschland nach der Methode des
    Vollständigen Finanzplans (Grob) aus Sicht von Wohnungsunternehmen,
    privaten Vermietern und Selbstnutzern. Enthält Szenarien in YAML und
    Excel, eine versionierte Parameterbibliothek, Monte-Carlo-Simulation,
    Varianten-, Sensitivitäts- und Break-even-Analysen sowie Berichte.
License: file LICENSE
Encoding: UTF-8
Language: de
Depends: R (>= 4.1.0)
Imports:
    openxlsx (>= 4.2.5),
    stats,
    tools,
    utils,
    yaml (>= 2.3.5)
Suggests:
    bslib,
    covr,
    DT,
    future (>= 1.33.0),
    future.apply (>= 1.11.0),
    ggplot2 (>= 3.4.0),
    jsonlite,
    knitr,
    rmarkdown,
    shiny (>= 1.8.0),
    testthat (>= 3.0.0),
    withr
VignetteBuilder: knitr
Config/testthat/edition: 3
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.3.1
```

- Lizenz vorläufig `file LICENSE` (intern, Konzept A5). `ByteCompile` wird **nicht** auf `no` gesetzt.
- Gegenüber D13 sind `withr` (Tests: temporäre Dateien, Optionen), `future` (nötig, um in Tests `future::plan()` zu
  setzen; ohnehin Abhängigkeit von `future.apply`) und `jsonlite` (`vofi_json_schema()`) ergänzt. `readxl`, `vdiffr`,
  `lhs`, `plotly`, `Matrix`, `checkmate`, `R6`, `dplyr`, `data.table`, `glue`, `cli`, `rlang` werden **nicht**
  verwendet (R-44).
- Jeder Zugriff auf ein Suggests-Paket MUSS über `requireNamespace(pkg, quietly = TRUE)` geprüft werden. Fehlt es,
  folgt `vofi_abort("core.suggests_missing", pkg = pkg, fun = <Funktion>)` (deutsche Meldung).

### 2.6 NAMESPACE-Politik

1. `NAMESPACE` und `man/` werden **nur** vom Integrator mit `roxygen2::roxygenise()` erzeugt und committet. Agenten
   setzen `@export`-Tags in ihren Dateien, committen aber weder `NAMESPACE` noch `man/`.
2. Alle exportierten Funktionen (Abschnitt 14) existieren nach Phase 0 als **Stub** in der Datei ihres Eigentümers mit
   vollständiger deutscher roxygen-Doku und dem Rumpf `vofi_abort("core.not_implemented", fun = "<name>")`. Der
   Eigentümer ersetzt nur den Rumpf und darf die Signatur nicht ändern.
3. S3-Methoden werden mit `@export` (roxygen erkennt `print.vofi_result` als Methode) bzw. `@exportS3Method` für
   Generics aus Suggests registriert (z. B. `@exportS3Method ggplot2::autoplot` ist **nicht** vorgesehen; Grafiken
   laufen über `plot.*` und `vofi_plot()`).
4. Importe: `@importFrom stats ...` und `@importFrom utils ...` gezielt in `R/vofi-package.R` (Integrator). `yaml`
   und `openxlsx` werden mit `::` aufgerufen und nicht importiert. Kein `@import` ganzer Pakete.
5. Nicht exportierte Funktionen tragen `@noRd` oder `@keywords internal`.
6. roxygen-Doku ist **deutsch** (`Encoding: UTF-8`). `@family`-Gruppen: `Einlesen`, `Validieren`, `Rechnen`,
   `Analysieren`, `Berichten`, `Erweitern`. Beispiele laufen unter 5 s (`n_sim <= 200`), App und Bericht mit
   `@examplesIf interactive()`.

### 2.7 Allgemeine Codierregeln (MUSS)

1. **R-Code ist ASCII.** Keine Umlaute, kein `ß`, kein `€` in Code-Token in `R/` (Bezeichner, Zeichenketten,
   Operatoren) – auch nicht in Zeichenketten. Nutzertexte nur über `lbl()`/`msg()` (2.10). Ausnahme: Kommentare und
   roxygen-Doku (`#'`) dürfen deutsch mit Umlauten sein (D12, `Encoding: UTF-8`; `R CMD check` prüft Kommentare nicht).
   Wo ein Sonderzeichen im Code unvermeidlich ist (z. B. Formatcodes), wird es als Unicode-Escape geschrieben:
   `€` als `"\u20ac"`.
2. Stil: snake_case, Zeilenlänge ≤ 100, `<-` für Zuweisung, `TRUE`/`FALSE` statt `T`/`F`, `seq_len()`/`seq_along()`
   statt `1:n`, `vapply()` statt `sapply()`, ganze Zahlen mit `L`, `[[` statt `$` bei Listen mit Nutzerschlüsseln
   (kein Partial Matching), keine `library()`/`require()`/`attach()` im Paketcode.
3. Keine globalen Seiteneffekte: kein `options()`, `set.seed()`, `setwd()`, `Sys.setenv()` ohne Wiederherstellung
   (einzige Ausnahme: `.onLoad` setzt noch nicht gesetzte `vofi.*`-Optionen, 5.5); RNG nur in `with_stream()` (11.12). Kein `<<-` außer in ausdrücklich dokumentierten Akkumulator-Closures der Engine.
4. Funktionspräfixe für interne Funktionen: `reg_`, `vocab_`, `lbl_`, `grid_`, `val_` (Validierung), `io_`, `scn_`
   (Szenario), `lib_`, `var_`, `node_` (Normalisierung, Knoten), `res_` (Auflösung), `expr_` (Ausdrücke), `exp_`
   (Expander), `rule_`, `smp_`, `dist_`, `proc_`, `eng_`, `acc_`, `inst_`, `tax_`, `kpi_`, `mc_`, `cmp_`, `sens_`,
   `slv_`, `rep_`, `fmt_`, `utl_`. Typdefinitionen: `typedef_*` (5.5).
5. Datumswerte sind `Date`. Zeitstempel (`POSIXct`) nur in `meta`.
6. Jede exportierte Funktion prüft ihre Argumente und meldet Fehler über `vofi_abort()` mit Bedingungsklasse.
7. `lintr`-Konfiguration (`.lintr`): `linters_with_defaults(line_length_linter(100), object_name_linter("snake_case"),
   object_length_linter(40))`; Ausnahmen nur mit `# nolint` und Begründung.
8. **Sortierung ist gebietsschemaunabhängig.** Zeichenketten werden ausschließlich mit `sort(x, method = "radix")`
   bzw. `order(..., method = "radix")` sortiert (C-Ordnung). Das gilt insbesondere für die Discovery (5.5), die
   topologische Sortierung (9.1), Korrelations- und Schockschlüssel (11.6), `scenario_mix`-Szenarien (11.7) und die
   generierte Excel-Vorlage. Hintergrund: `sort()` ohne `method` sortiert unter `C.UTF-8` (ICU) anders als unter `C`.

### 2.8 Vektorisierungsregeln (MUSS)

1. **Jede Zeitreihe ist eine numerische Matrix `n × (T+1)`**, Zeilen = Läufe, Spalten = Zeitpunkte t = 0…T,
   **Spalte 1 = t0**. Es gibt keine Vektoren der Länge T+1 als Wertzeilen und keine 1 × (T+1)-Matrizen, die implizit
   auf n verteilt werden. Zeitvektoren werden ausschließlich über `ctx$by_period(x)` und N-Vektoren über
   `ctx$by_sim(x)` zu Matrizen (6.2).
2. **Kein `if()`, `while()`, `switch()` auf simulierte Werte.** Bedingungen sind nur erlaubt auf t, Spaltenindizes,
   Konfiguration, deterministische Termine (z. B. Ende der Zinsbindung), Typparameter, die als
   `deterministic_only` deklariert sind, und Basisfallwerte (`ctx$param_base()`, `ctx$value_base()`, 6.3; sie sind
   innerhalb eines Modells in allen Läufen gleich, R-70). Wertlogik über `pmax`/`pmin`, Masken (`x * (cond)`), maskierte Zuweisung
   (`x[m] <- y[m]`) oder `ifelse()` (nur wenn beide Zweige endlich sind).
3. `max()`, `min()`, `sum()`, `any()`, `all()` über simulierte Werte nur, wenn ausdrücklich über alle Läufe aggregiert
   werden soll (Kennzahlen, Prüfungen). In der Periodenschleife immer `pmax`/`pmin`.
4. Teilmengen von Matrizen immer mit `drop = FALSE` (`m[i, , drop = FALSE]`, `m[, j, drop = FALSE]`); einzelne
   Spalten in der Schleife als Vektor `m[, j]` sind erlaubt, wenn das Ergebnis ein N-Vektor sein soll.
5. Keine Funktionsaufrufe **je Lauf** (keine Schleifen über Läufe, kein `apply(…, 1, …)` über Läufe im Kern). Schleifen
   nur über Perioden, Monate, Komponenten, Blöcke.
6. Matrizen vorab allozieren, keine wachsenden Objekte und keine `data.frame`-Operationen in der Periodenschleife.
7. **Keine Zufallszahlen außerhalb des Samplers** (`R/sampling-*.R`, `R/dist-*.R`, `R/process-*.R`). Typen,
   Instrumente, Aktionen, Kennzahlen und Expander ziehen nie Zufallszahlen. Der Vertragstest prüft, dass
   `.Random.seed` unverändert bleibt (15.2).
8. Tests laufen mit N = 1, N = 2 und N = T+1 (Recycling-Falle `matrix * zeitvektor`). Das Jahresraster des
   Prüfkits hat deshalb T = 6, sodass N = 7 zugleich N = T+1 ist (5.6).

### 2.9 Bedingungen: Fehler, Warnungen, Meldungen

```r
vofi_abort(key, ..., .class = NULL, .data = list(), .call = NULL)   # signalisiert Fehler, kehrt nie zurück
vofi_warn(key, ..., .class = NULL, .data = list())                  # Warnung (Klasse vofi_warning)
vofi_inform(key, ..., .class = NULL)                                # Meldung, nur wenn getOption("vofi.verbose", TRUE)
```

- `key` ist ein Label-Schlüssel (2.10); der Text entsteht über `msg(key, ...)`. `...` sind benannte Platzhalterwerte.
- Die Bedingung ist eine Liste mit `message`, `call`, `key`, `data` und der Klasse
  `c(.class, "vofi_error", "error", "condition")` bzw. `c(.class, "vofi_warning", "warning", "condition")` bzw.
  `c(.class, "vofi_message", "message", "condition")`.
- **Zulässige Klassen** (`inst/vocab/conditions.yaml`, nur diese):

| Klasse | Bedeutung | typischer Auslöser |
|---|---|---|
| `vofi_error_input` | Eingabe nicht lesbar oder unzulässig formatiert | YAML-Syntax, Excel-Zelle, Tausenderpunkt bei EUR |
| `vofi_error_validation` | Validierung mit Fehlern; Feld `data$report` = `vofi_validation` | `vofi_build()` |
| `vofi_error_registry` | Typ unbekannt, doppelt, Vertrag verletzt bei Registrierung | `vofi_register_type()` |
| `vofi_error_contract` | Rückgabe eines Typs verletzt den Vertrag zur Laufzeit | Dimension, NA, unbekannte Kategorie |
| `vofi_error_engine` | Laufzeitinvariante verletzt (I1–I3) | `eng_checks()`; `data` = Lauf, Periode, Beiträge |
| `vofi_error_not_implemented` | Stub | Phase 0 |
| `vofi_error_label` | Label-Schlüssel fehlt (nur bei `vofi.strict_labels = TRUE`) | Tests |
| `vofi_warning_input` | Eingabe umgedeutet (Dezimalkomma, Prozentzeichen, Alias-Code) | Normalisierer |
| `vofi_warning_plausibility` | Plausibilitätsbefund | Validierungsebene 4 |
| `vofi_warning_library_outdated` | Bibliothekseintrag außerhalb Gültigkeit oder Stand zu alt | 4.9 |
| `vofi_warning_engine` | Rechenhinweis (h > s, negative Tilgung bei `keep_payment`, Fehlbetrag bei `stop`) | Engine |
| `vofi_warning_correlation` | Korrelationsmatrix repariert (max. Abweichung > 0,05) | Sampler |
| `vofi_warning_memory` | Speicherschätzung über `vofi.max_memory_gb` | `vofi_run()` |
| `vofi_message` (Basis) | Information | – |

- Validierungsbefunde werden **gesammelt** (nicht einzeln geworfen) und als `vofi_validation` zurückgegeben (13.5).

### 2.10 Label-Katalog

- **Ablage:** `inst/labels/de/<datei>.yaml`, rekursiv. Der Schlüsselpräfix ist der relative Dateipfad ohne Endung mit
  `/` → `.`: `types/instrument/annuity_loan.yaml` liefert `types.instrument.annuity_loan.*`; `core.yaml` liefert
  `core.*`.
- **Typlabels:** Datei `types/<kind>/<name>.yaml` (Ordner = Art nach 5.1, Name = Registry-Name ohne Präfix), Schlüssel
  `types.<kind>.<name>.*`, z. B. `types.distribution.pert.label`, `types.account_action.od_draw.rows.od_draw`,
  `types.kpi.terminal_value.label`, `types.tax.flat.report.taxable_income`. Rechtsregeln: Datei
  `types/rule/<rulename>.yaml` je Regelname (ohne `@<Datum>`); versionsspezifische Hinweise unter
  `versions.<YYYYMMDD>.note`.
- **Schlüsselschema** `<bereich>.<objekt>.<feld>`, z. B. `core.rows.balance_check`, `core.sections.project`,
  `vocab.categories.project.capex`, `vocab.categories.loans.interest`, `vocab.tax_categories.income_rental`,
  `vocab.na_reasons.no_equity`, `validation.not_number`, `types.instrument.annuity_loan.label`,
  `types.instrument.annuity_loan.params.rate_pa.label`, `types.instrument.annuity_loan.params.rate_pa.help`,
  `types.instrument.annuity_loan.rows.interest`. `kpi.yaml` enthält nur übergreifende Kennzahlentexte (Überschriften,
  Vermerke wie „unabhängig vom Restwert“); NA-Begründungen stehen **ausschließlich** unter `vocab.na_reasons.*`.
- **Validierungsmeldungen (R-104):** alle in `inst/labels/de/validation.yaml` (WS-B), Schlüssel
  `validation.<block>.<code>`; `<block>` ist der oberste Szenarioblock (`project`, `building`, `measures`,
  `unit_groups`, `energy`, `funding`, `financing`, `accounts`, `residual_value`, `analysis`, `stochastic`, …) bzw.
  `library`, `variants`, `scenario_set`, `profile`, `quantity`, `maintenance`, `acquisition`; blockübergreifende Meldungen
  haben die Form `validation.<code>` (bestehend: `validation.not_number`, `validation.unknown_key`,
  `validation.tax_module_blocked`, `validation.reference_variant_missing`, `validation.profile_path_forbidden`).
  Andere Namensräume (z. B. `validation.b.*`) und andere Dateien (z. B. `inst/i18n/*`) gibt es nicht.
- **Pflichtschlüssel je Typ:** `label`, `description`, `params.<p>.label` für jeden Parameter, `rows.<r>` für jede
  deklarierte Zeile bzw. jedes Zeilenmuster (Flows, Instrumente, Aktionen; Muster 5.2), `params.<p>.help` SOLL.
- **Laden:** `.onLoad` ruft `lbl_load(system.file("labels", "de", package = "vofi"))` auf. Doppelte Schlüssel beim
  Laden sind ein Fehler (`vofi_error_label`).
- **Funktionen** (intern, `R/labels.R` und `R/utils-format.R`):

```r
lbl(key, ..., .default = NULL)  # -> character(1); "..." ersetzt {platzhalter}; fehlender Schlüssel:
                                #    vofi.strict_labels = TRUE -> vofi_error_label, sonst .default bzw. "[[key]]"
msg(key, ...)                   # identisch zu lbl(), Name für Meldungstexte
lbl_has(key)                    # -> logical(1)
lbl_load(dir)                   # -> invisible(Anzahl Schlüssel)
fmt_num(x, digits = 2)          # deutsches Zahlenformat "1.234.567,89"; NA -> "n. d."
fmt_int(x)                      # "1.234.567"
fmt_pct(x, digits = 2)          # 0.038 -> "3,80 %"
fmt_eur(x, digits = 0)          # "1.234 €"
fmt_date(x)                     # "25.10.2026"
```

- **Platzhalter:** `{name}` (Zeichen unverändert, Zahlen mit `fmt_num(…, 2)`), `{name:int}`, `{name:pct}`,
  `{name:eur}`, `{name:date}`, `{name:raw}` (`format()` ohne Lokalisierung). Fehlt ein Platzhalterwert, bleibt
  `{name}` sichtbar und es erfolgt in Tests ein Fehler.
- `getOption("vofi.language", "de")` ist reserviert; v1 lädt nur `de`.

### 2.11 Vokabulare

`inst/vocab/*.yaml` enthält **nur Codes und maschinelle Regeln** (ASCII). Deutsche Bezeichnungen stehen in
`inst/labels/de/vocab.yaml` unter `vocab.<datei>.<code>`; Kategorien sind je Abschnitt definiert (7.6) und stehen
daher unter `vocab.categories.<section>.<category>`. Zugriff intern:

```r
vocab_load(dir)                  # .onLoad
vocab(name)                      # -> data.frame bzw. Liste des Vokabulars, z. B. vocab("categories")
vocab_codes(name, field = NULL)  # -> character
vocab_check(name, x, path)       # -> character() oder Fehlertexte; Aliase werden mit vofi_warning_input aufgelöst
```

Jedes Enum in `enums.yaml` hat die Form `name: {codes: [...], aliases: {alt: neu}, default: <code>}`. Aliase dienen
nur der Eingabe-Normalisierung (R-07, R-09, R-34); die Trennung von Codes und Texten folgt R-48; intern und in Ausgaben erscheinen nur kanonische Codes.

**Inhalt v1 (R-89, verbindlich; der Integrator pflegt die Dateien, Spec 01 liefert die Codes):**

- `measure_types.yaml`: genau die 37 Codes der Tabelle Spec 01 Teil A §4.2 (u. a. `daemmung_fassade`,
  `daemmung_dach_steil`, `daemmung_dach_flach`, `daemmung_oberste_geschossdecke`, `daemmung_kellerdecke`, `fenster`,
  `aussentueren`, `heizung_waermepumpe_luft`, `heizung_waermepumpe_sole`, `heizung_gaskessel`, `heizung_pelletkessel`,
  `heizung_fernwaerme`, `heizungsverteilung`, `pv`, `erwerb_grundstueck`, `erwerb_objekt`, `baunebenkosten`,
  `sonstige`). Sammelcodes wie `heizung_tausch`, `daemmung_dach`, `daemmung_ogd`, `aussentuer`, `sonnenschutz` gibt es
  nicht.
- `enums.yaml`: die Enums aus Spec 01 Teil A §8.1 und Teil B §8, dazu
  `federal_state: {codes: [BW, BY, BE, BB, HB, HH, HE, MV, NI, NW, RP, SL, SN, ST, SH, TH]}` (Schlüssel von
  `legal/grunderwerbsteuer`),
  `levy_procedure: {codes: [auto, bgb_559, bgb_559c, bgb_559e], aliases: {"559": bgb_559, "559c": bgb_559c, "559e":
  bgb_559e}, default: auto}` (Aliase auch für die als Zahl gelesene Eingabe `559`),
  `bgb_procedure: {codes: [bgb_557a, bgb_557b, bgb_558, bgb_559, bgb_559b, bgb_559c, bgb_559e]}` (Verfahrenscodes in
  Bibliotheksnutzlasten, z. B. `s557a.excludes`, `rent_law.enables`), `overlay_apply: {codes: [replace, multiply,
  add], default: replace}` (R-94), `growth_index: {codes: [calendar_year, period_end], default: calendar_year}`
  (R-91), `mc_preset: {codes: [preview, standard, report, custom], default: standard}` (R-97); `quantity_per` um
  `m2_net_floor_area` und `parking` ergänzt (R-91); `rule_returns` um `value` ergänzt (R-93).
- `na_reasons.yaml` um `no_liquidity_limit` ergänzt (12.4, R-101).
- **Codes in Bibliotheksnutzlasten** (`eligibility.measure_types`, `eligibility.applicants`,
  `eligibility.project_types`, Verfahrenslisten der Mietrechtsnutzlast) MÜSSEN Vokabularcodes sein; `test-library.R`
  (WS-L) prüft das für jeden Eintrag.

### 2.12 Optionen

| Option | Default | Bedeutung |
|---|---|---|
| `vofi.library_paths` | `character()` | zusätzliche Bibliothekswurzeln (später gewinnt) |
| `vofi.chunk_size` | `2000L` | Läufe je Chunk (wird auf Vielfaches der Blockgröße abgerundet, mindestens 1 Block); bei der Default-Blockgröße 200 = 10 Blöcke je Chunk, bei n_sim = 10.000 also 5 Chunks (Speicherbudget 9.10) |
| `vofi.max_memory_gb` | `2` | Schwelle für `vofi_warning_memory` |
| `vofi.verbose` | `TRUE` | `vofi_inform()` aktiv |
| `vofi.strict_labels` | `FALSE` (Tests: `TRUE`) | fehlende Labels als Fehler |
| `vofi.language` | `"de"` | reserviert |

### 2.13 Numerische Konventionen und Toleranzen

```r
vofi_tol <- list(        # R/contracts.R (I), intern; in ctx als ctx$tol
  balance_rel = 1e-8,    # I1: |balance_check| <= 1e-8 * max(1, Volumen des Laufs)
  stock_abs   = 1e-6,    # I3: Bestände >= -1e-6 EUR
  zero_abs    = 1e-9,    # "praktisch null" in Ketten und KPIs (EUR)
  oracle_abs  = 1e-6,    # Orakel gegen ungerundete Skriptwerte
  oracle_tab  = 0.005    # Orakel gegen gerundete Tabellenwerte (Memo 01)
)
```

- **Volumen** eines Laufs = `max_t sum(abs(zahlungswirksame Zeilen in t))`.
- Gerechnet wird **ohne Rundung**. Rundung nur in der Anzeige (`fmt_*`) und optional in Instrumenten mit
  `round_payments = TRUE` (Cent, Bankpraxis; Standard `FALSE`).
- Geldbeträge sind **nominal in EUR, brutto** (inkl. nicht abziehbarer USt, D6). Raten und Anteile sind Dezimalzahlen
  (`0.039` = 3,9 %).

---

## 3. Zeitraster (`vofi_grid`)

### 3.1 Begriffe

| Symbol | Bezeichner | Bedeutung |
|---|---|---|
| t | `t` | Zeitpunkt 0…T; t = 0 ist der Bewertungsstichtag (`valuation_date`), Periode 0 hat die Länge 0 |
| Periode t | – | Intervall (b_{t−1}, b_t] für t ≥ 1; alle Zahlungen der Periode fallen **am Periodenende b_t** an (nachschüssig, D3) |
| m_t | `months[j]` | Periodenlänge in **ganzen Monaten** (D2); `months[1] = 0` |
| Δ_t | `delta[j]` | Periodenlänge in Jahren = m_t / 12 |
| τ_t | `tau[j]` | kumulierte Zeit in Jahren, τ_0 = 0; Horizont in Jahren T_J = τ_T |
| M_t | `month_end[j]` | kumulierte Monate seit dem Stichtag |
| b_t | `date_end[j]` | Periodenende = `valuation_date` + M_t Monate |

`valuation_date` MUSS ein Monatserster sein (Validierungsfehler sonst). Damit sind alle Periodengrenzen Monatserste.

### 3.2 Objektstruktur

```r
vofi_grid <- structure(list(
  T              = integer(1),        # letzter Periodenindex
  t              = integer(T + 1),    # 0:T
  months         = integer(T + 1),    # Periodenlänge in Monaten, months[1] = 0
  delta          = numeric(T + 1),    # months / 12
  tau            = numeric(T + 1),    # cumsum(delta)
  month_end      = integer(T + 1),    # cumsum(months)
  date_start     = as.Date(...),      # Periodenbeginn b_{t-1}; t = 0: valuation_date
  date_end       = as.Date(...),      # Periodenende b_t;      t = 0: valuation_date
  year           = integer(T + 1),    # Kalenderjahr des Periodenbeginns; t = 0: Jahr(valuation_date)
  phase          = character(T + 1),  # "construction" | "operation"
  op_year        = integer(T + 1),    # Betriebsjahr 1, 2, ... (3.3; calendar: Kalenderjahre, erstes ggf. Teiljahr);
                                      # Bauphase und t0: 0
  op_year_full   = logical(T + 1),    # TRUE, wenn das Betriebsjahr der Periode 12 Monate umfasst
  label          = character(T + 1),  # Anzeige (ASCII): "t0", "2027", "2027/28", "Q1/2027", "01/2027"
  valuation_date = as.Date(...),
  completion_date= as.Date(...),      # valuation_date + construction_months
  end_date       = as.Date(...),      # date_end[T + 1]
  years          = integer(),         # Kalenderjahre der Prozesse: start_year:max(year)
  settings       = list()             # Eingabeparameter von vofi_time_grid()
), class = "vofi_grid")
```

Der Index j = t + 1 adressiert alle Vektoren und Matrixspalten. Typen MÜSSEN fachliche Zeitpunkte über **Daten**
bestimmen (Fertigstellung, Maßnahmendatum, Antragsdatum), nicht über `phase`. `phase` dient der Anzeige, der Auswahl
der Betriebsperioden in Kennzahlen (DSCR, Belastung) und der Bestimmung von `auto`-Beträgen (8.7).

### 3.3 Konstruktion

```r
vofi_time_grid(valuation_date, horizon_years, construction_months = 0L,
               construction_step_months = 12L, operation_step_months = 12L,
               operation_alignment = c("calendar", "completion"),
               periods_months = NULL, start_year = NULL)
```

Algorithmus (MUSS; `add_months(d, k)` = Datum d plus k Kalendermonate):

```text
C  <- construction_months;  cs <- construction_step_months  (in {1, 3, 6, 12})
os <- operation_step_months (v1: nur 12 zulässig, sonst vofi_error_input)
completion <- add_months(valuation_date, C)
falls periods_months angegeben:                    # explizites Raster (z. B. Orakel (e))
    months <- c(0, periods_months)                 # alle Einträge ganzzahlig >= 1
sonst:
    end <- add_months(valuation_date, 12 * horizon_years)   # festes Horizontende (Kalenderdatum, R-67)
    Fehler, falls end <= completion (Horizont kürzer als Bauphase)
    falls cs == 12:                                # Standard: reines Jahresraster ab Stichtag
        months <- c(0, rep(12, horizon_years))
    sonst:                                         # nicht äquidistant: Bauphase fein, Betrieb jährlich
        bau  <- c(rep(cs, C %/% cs), falls C %% cs > 0: C %% cs)
        stub <- falls operation_alignment == "calendar" und completion kein 1. Januar:
                    Monate(completion -> nächster 1. Januar)  sonst 0
        rest <- Monate(completion -> end) - stub
        betr <- c(falls stub > 0: stub, rep(12, rest %/% 12), falls rest %% 12 > 0: rest %% 12)
        months <- c(0, bau, betr)
phase[1] <- "construction" falls C > 0, sonst "operation"
phase[j] (j >= 2) <- "construction" falls date_start[j] < completion, sonst "operation"
op_year[1] <- 0 (t0 ist ein Zeitpunkt); op_year[j] (j >= 2) <- 0 in der Bauphase, sonst
    operation_alignment == "calendar":   year[j] - Jahr(erster Betriebsperiodenbeginn) + 1
                                         (eine Stub-Periode bildet ein eigenes Teil-Betriebsjahr)
    operation_alignment == "completion": floor(Monate(erster Betriebsperiodenbeginn -> date_start[j]) / 12) + 1
op_year_full[j] <- (Summe der months aller Perioden mit demselben op_year > 0) == 12
year[j]    <- Jahr(date_start[j]);  year[1] <- Jahr(valuation_date)
years      <- (start_year %||% Jahr(valuation_date)) : max(year)
```

- Mit `periods_months` wird `horizon_years` nicht verwendet (Hinweis, falls `sum(periods_months) != 12 * horizon_years`).
- Standard ist das **Jahresraster** (D2, R-01). Nicht äquidistante Raster entstehen mit `construction_step_months < 12`
  oder `periods_months`.
- **Festes Horizontende (R-67, Konzept F16):** Das Horizontende ist das Kalenderdatum `end_date` =
  `valuation_date` + 12 · `horizon_years` Monate, für **alle Varianten und alle Läufe**; ein Horizont „ab
  Fertigstellung“ existiert nicht (der frühere Schalter `horizon_from` entfällt, R-02 ist ersetzt). Beim Neubau
  enthält `horizon_years` die Bauzeit (Konzept A3). Eine andere Bauzeit einer Variante (`grid.construction_months`)
  und ein Bauzeitverzug (3.9) verschieben nur Mietbeginn, Bauzeitzinsen und Zahl der Nutzungsjahre, nie `end_date`.
  Varianten mit verschiedener Bauzeit haben dasselbe `end_date`, aber ggf. verschiedene Periodeneinteilungen (9.6
  Nr. 2).
- `vofi_build()` erzeugt das Raster aus `project.valuation_date`, `project.horizon_years` und dem Block `grid` (4.3).

### 3.4 Zuordnung von Datum und Jahr zur Periode (R-35)

```r
grid_period_of(grid, date)        # -> integer, gleiche Länge wie date
grid_period_of_year(grid, year)   # -> integer; Jahr Y bedeutet das Datum Y-01-01
```

- `date == valuation_date` → t = 0; `date > valuation_date` → t = min{ t ≥ 1 : date ≤ date_end[t] };
  `date > end_date` → `NA` (außerhalb des Horizonts); `date < valuation_date` → `NA` mit Attribut `"before"`.
  Zahlungen mit Datum vor dem Stichtag sind ein Validierungsfehler, nach dem Horizont ein Hinweis (sie entfallen).
- Eine Jahresangabe `year: Y` (Maßnahmen, Kredite, Zahlungspläne) bedeutet **„zum 1. Januar Y“** (Memo 07 §4.0:
  `year: 2030` → t = 3 bei Stichtag 01.01.2027). Laufende Wirkungen „ab Jahr Y“ gelten für alle Perioden mit
  `year[j] >= Y`.
- **Einmalzahlungen und laufende Wirkungen (R-98, MUSS für alle Typen):**
  1. *Monate.* Monat m (m = 1…M_T) ist das Intervall (b_0 + (m − 1) Monate, b_0 + m Monate] und gehört zur Periode
     p(m) (3.5); er **beginnt** mit dem Monatsersten d_m = b_0 + (m − 1) Monate. Der Monatsindex eines Monatsersten d
     ist mi(d) = 1 + (Anzahl der Monate von b_0 bis d), also mi(b_0) = 1; ein Datum, das kein Monatserster ist, wird
     für laufende Wirkungen auf den folgenden Monatsersten gerundet.
  2. *Laufende Wirkungen* („wirksam ab d“: Miete, Umlage, Betriebskosten, Energiezustand, Zinsen) gelten für alle
     Monate m ≥ mi(d); ihre Monatsbeträge werden nach 3.7 je Periode summiert.
  3. *Einmalzahlungen* (Auszahlung eines Zuschusses, Tilgungszuschuss, § 35c-Tranche, Kaufpreis, Zahlungsplan,
     Kreditauszahlung, Ersatzinvestition) haben einen **Termin** als Datum und werden nach R-35 in
     `grid_period_of(Termin)` gebucht. Entsteht der Termin aus einem Bezugsdatum und Monatsfristen
     (Fertigstellung + `lag_months` + Verzug), ist er `add_months(Bezugsdatum, lag + Verschiebung)`, laufspezifisch über
     `ctx$shift_period(Bezugsdatum, lag + Verschiebung)` (3.9). Eine Formulierung „Auszahlung im Monat m“ bedeutet
     den Termin d_m (Monatsbeginn). Beispiel: Fertigstellung 2027-10-01 + 3 Monate → Termin 2028-01-01 → auf dem
     Jahresraster ab 2027-01-01 Periode t = 1 (2027), für Zuschuss und Tilgungszuschuss gleichermaßen.
  4. Ein Termin am Stichtag fällt in t = 0.

### 3.5 Indexkonventionen

| Objekt | Form | Index |
|---|---|---|
| Zeitreihe (Ledger, Pfad, Rate) | Matrix `n × (T+1)` | Spalte j = t + 1, Spalte 1 = t0 |
| statische Größe | numerischer Vektor der Länge n | Lauf i |
| interne Monatsrechnung | Matrix `n × M_T` | Spalte m = Monat m (1…M_T); Monat m gehört zu Periode p(m) = min{t : M_t ≥ m} |
| Prozess in Kalenderjahren | Matrix `n × length(years)` | Spalte = Jahr − start_year + 1 |
| Raten in Pfaden | Dezimalzahl **p. a.** | Umrechnung auf Perioden nur über 3.6 |

### 3.6 Umrechnungs- und Zugriffsfunktionen (intern in `R/time-grid.R`, in `ctx` als Closures, 6.2)

```r
grid_rate_eff(grid, r_pa)              # (1 + r_pa)^delta - 1 elementweise; r_pa: n-Vektor oder n x (T+1); Spalte 1 = 0
grid_rate_nom(grid, r_pa)              # r_pa * delta (nominale Periodenrate)
grid_per_period(grid, x_pa)            # Jahresbetrag -> Periodenbetrag: x_pa * delta
grid_index(grid, g, base_date = NULL)  # kumulierter Index n x (T+1) zum PERIODENENDE (Bestandsgrößen, Preisniveau
                                       # an Stichtagen): I_t = I_{t-1} * (1 + g[, t+1])^delta_t;
                                       # I_0 = Vorlauf(base_date -> valuation_date), s. u. (base_date NULL: I_0 = 1).
                                       # Liegt base_date nach dem Stichtag im Horizont, gilt I_t = I*_t / I*(base_date)
                                       # mit I* = Index ab Stichtag (I*_0 = 1) und geometrischer Interpolation
                                       # innerhalb der Periode von base_date.
                                       # Beispiel: g = 0.02, base_date = Stichtag + 12 Monate -> I_t = 1.02^(t-1)
grid_index_year(grid, g, base_date = NULL)  # KALENDERJAHRESINDEX n x (T+1) für laufende Jahresbeträge (R-62):
                                       # Spalte j = Indexstand am Ende des Kalenderjahres year[j], d. h. am
                                       # (year[j] + 1)-01-01, bezogen auf base_date; Spalte 1 (t0) = Wert des
                                       # Jahres Jahr(valuation_date). Jahresrate des Kalenderjahres Y = Wert von g in
                                       # der ersten Periode j >= 2 mit year[j] == Y (für Prozesse und series_year
                                       # exakt, da kalenderjährlich konstant). Innerhalb eines Kalenderjahres ist der
                                       # Index konstant; Jahressummen sind damit auf jedem kalenderjahrbündigen Raster
                                       # identisch (F10). Beispiel: g = 0.02, base_date = 2028-01-01, Jahresraster ab
                                       # 2027 -> Spalte j = 1.02^(j-2) für j >= 2 (Orakel (b))
grid_overlap(grid, from = NULL, to = NULL)  # (T+1)-Vektor: Anteil der Monate von Periode t in [from, to); t0 = 0
grid_months(grid)                      # data.frame(m, period, date_start, date_end, year)
grid_to_periods(grid, x_month)         # n x M_T -> n x (T+1): Summe der Monate je Periode, Spalte 1 = 0
grid_to_months(grid, x, how = c("repeat", "spread"))  # n x (T+1) -> n x M_T; spread = Periodenbetrag / months_t
grid_map_years(grid, x_year)           # n x length(years) -> n x (T+1): Spalte j = Wert des Jahres year[j]
```

**Vorlauf vor dem Stichtag (base_date < valuation_date, z. B. Preisbasis BKI 2024):** Der Faktor I_0 wird über die
Kalenderjahre zwischen base_date und valuation_date aufgebaut (Teiljahre geometrisch anteilig). Für diese Jahre gelten
die Jahreswerte der Wertform, sofern sie welche enthält: `values-resolve.R` (WS-D) hängt an Pfade aus `series_year`-
bzw. `points`-Knoten (auch über `ref`) das Attribut `"annual_before"` an (n × k-Matrix, Spaltennamen = Jahre vor
Jahr(valuation_date)); `grid_index()`, `grid_index_year()` und `ctx$index()`/`ctx$index_year()` verwenden es, wenn es
vorhanden ist. Fehlt es, wird die Rate des Bewertungsjahres `g[, 1]` angesetzt und einmal je Pfad
`vofi_inform("core.index_before_assumed", path = …)` gemeldet. Typen SOLLEN den Pfad aus `ctx$param()` unverändert an
`ctx$index()` bzw. `ctx$index_year()` übergeben, damit das Attribut erhalten bleibt.

**Indexkonvention (R-62):** Laufende Jahresbeträge (Kosten, Erlöse, Zuschüsse je Jahr) werden mit dem
Kalenderjahresindex `grid_index_year()` fortgeschrieben; Bestandsgrößen und Preise an Stichtagen (Marktwert, Restwert,
einmalige Zahlungen zu einem Datum) mit `grid_index()`. Typen, die intern monatlich rechnen (Mietrecht), schreiben ihre
Größen nach ihrer eigenen Fachlogik fort und summieren mit `grid_to_periods()`; ihre Kalenderjahressummen sind damit
ebenfalls rasterunabhängig.

**Zinskonvention (D2, D3, R-03):**

- **Konten** (Geldanlage, Kontokorrent, Strafzinstranche) verzinsen mit `grid_rate_eff()` aus dem effektiven
  Jahreszins: h_t = (1 + h_pa)^Δ_t − 1. Das ist der Default jeder Rate, sofern ein Typ nichts anderes festlegt.
- **Kredite** legen in ihrer Typdefinition die Vertragskonvention fest: nominaler Sollzins mit **monatlicher
  Zinsberechnung i_nom / 12 auf den Monatsanfangsbestand** (8.5). Bei konstantem Bestand ergibt das i_nom · Δ_t und
  reproduziert die Orakel (a)–(e) und Test (f).

### 3.7 Interne Monatsauflösung

Typen DÜRFEN intern monatlich rechnen (Mietrecht: Wartefristen, Wirksamkeitsfristen, Kappungsfenster; Kredite:
Vertragsfrequenz; Bauphase). Sie MÜSSEN mit `grid_to_periods()` auf das Raster summieren. **Buchungskonvention:**
Alle Monatsbeträge einer Periode werden am Periodenende gebucht. Der dadurch entstehende Zinsfehler (bei 12 gleichen
Monatszahlungen etwa 0,458 · h · Jahresbetrag) ist dokumentiert. Eine Matrix 10.000 × 360 Monate belegt rund 29 MB;
Typen SOLLEN Monatsmatrizen nur temporär halten.

### 3.8 Beispiele (verbindlich als Testfälle für `vofi_time_grid()`)

| Fall | Eingabe | Ergebnis |
|---|---|---|
| G1 Jahresraster (S1) | 2027-01-01, H = 30, C = 0 | T = 30, `months = c(0, rep(12, 30))`, `label = c("t0", "2027", …, "2056")`, `grid_period_of_year(g, 2030) == 3` |
| G2 Neubau jährlich (S2) | 2027-01-01, H = 40, C = 24 | T = 40; t = 1, 2 `construction`; t ≥ 3 `operation`; `op_year[4] == 1` |
| G3 Orakel (e) | 2027-01-01, `periods_months = c(3, 3, 3, 3, 12, 12, 12)`, C = 12 | T = 7, `tau = c(0, .25, .5, .75, 1, 2, 3, 4)`, t = 1…4 `construction` |
| G4 Bauphase monatlich | 2027-01-01, H = 30, C = 9, cs = 1, `calendar` | `months = c(0, rep(1, 9), 3, rep(12, 29))`, T = 39, `end_date = 2057-01-01`; `op_year[2:10] == 0`, `op_year[11] == 1` (Stub Okt.–Dez. 2027, `op_year_full[11] == FALSE`), `op_year[12] == 2` (2028, voll) |
| G5 Betrieb ab Fertigstellung | 2027-01-01, H = 30, C = 9, cs = 3, `completion` | `months = c(0, 3, 3, 3, rep(12, 29), 3)`, T = 33, `op_year[5] == 1`, `op_year_full[5] == TRUE`, letztes Betriebsjahr Teiljahr (3 Monate) |

### 3.9 Stochastische Verschiebungen in Zahlungskomponenten (R-60)

Raster, Instrumenttermine und Kettenregeln bleiben deterministisch (R-47). Zahlungskomponenten (Art `flow`) DÜRFEN
Termine **laufspezifisch** verschieben, wenn die Verschiebung als numerischer Parameter vorliegt (Art `number`,
stochastisch zulässig): Bauzeitverzug, Verzögerung einer Maßnahme, stochastische Nutzungs- bzw. Restlebensdauer
(Ausfalljahr eines Bauteils). Verschiebungen werden auf **ganze Monate** gerundet (`floor(x + 0.5)`, Jahre × 12)
und ausschließlich über die folgenden Kontextfunktionen angewendet (vektorisiert, keine Schleife über Läufe):

```r
ctx$shift_period(date, months)             # -> integer n-Vektor: Periode von date + months[i] Monaten je Lauf;
                                           #    NA jenseits des Horizonts (Zahlung entfällt, Hinweis)
ctx$shift_overlap(from, months, to = NULL) # -> n x (T+1): Monatsanteil von Periode t in [from + months[i], to)
ctx$shift_months(from, months, to = NULL)  # -> n x M_T 0/1-Matrix der aktiven Monate (für monatlich rechnende Typen)
```

- Schemafelder (Spec 01 konkretisiert): `project.construction_delay_months` (number ≥ 0, Default 0) verschiebt alle
  Wirkungen „ab Fertigstellung“ (Mietbeginn, Betriebskosten, Energiezustand „nachher“); `measures.<id>.delay_months`
  (number ≥ 0, Default 0) verschiebt Zahlungen und Wirkungen einer Maßnahme; `measures.<id>.useful_life_years` darf
  stochastisch sein und bestimmt den Termin von Ersatzinvestitionen (`replacement`); `funding.<id>.payout_delay_months`
  (number ≥ 0, stochastisch zulässig) verschiebt die Auszahlung von Zuschüssen und § 35c-Tranchen (Verzug beim
  Verwendungsnachweis, Konzept B12; Tilgungszuschüsse von Krediten bleiben terminfest, R-47). Alle Verschiebungen
  sind **≥ 0** (Validierungsfehler sonst); ein Termin, der je Lauf auch früher liegen kann (z. B. Ausfalljahr eines
  Kessels), wird als früherer Basistermin mit nichtnegativer Verschiebung modelliert (Referenzszenario S4, R-105).
  Verschobene Einmalzahlungen folgen 3.4 (R-98).
- Parameter der Art `timing` akzeptieren zusätzlich das Token `completion` (= `grid$completion_date`); es ist der
  Default aller Flow-Termine „ab Fertigstellung“ (z. B. `recurring.from`). `ctx$timing(spec, name)` liefert
  `list(date = Date, shift = double n-Vektor)`: `shift` = Wert von `project.construction_delay_months`, wenn der
  Parameter das Token `completion` trägt, sonst 0. Ausdrückliche Daten werden nicht verschoben. Dadurch trifft ein
  Overlay-Ziel auf `project.construction_delay_months` alle betroffenen Komponenten (Memo 04:
  `construction.delay_months` → dieser Pfad). Vom Maßnahmen-Expander erzeugte Komponenten erhalten den Parameter
  `delay_months: {ref: measures.<id>.delay_months}`.
- Kredite verschieben sich **nicht**; die Mehrbelastung durch Verzug (Bauzeitzinsen, späterer Mietbeginn) entsteht
  über den Ausgleich (Kontokorrent bzw. geringere Anlage). Verweist ein Kredit über `measure_id`/`funding_id` auf eine
  Maßnahme mit stochastischer Verschiebung, folgt `vofi_warning_plausibility` („Kredittermine bleiben fest“).
- Preissteigerung während des Verzugs: `capex` und `replacement` indexieren verschobene Zahlungen mit dem Index zum
  verschobenen Termin (`grid_index()` an der laufspezifischen Periode).

---

## 4. Kanonisches Szenario-Objekt (Schema v1)

### 4.1 Verarbeitungskette und Objekte

```text
YAML / Excel ──► vofi_read_scenario() ──► vofi_scenario   (normalisiert, unaufgelöst: Basis + Varianten + Overlay + Herkunft)
                                             │ vofi_resolve(variant, overrides, scenario_set)
                                             ▼
                                          vofi_spec        (eine Variante: Schichten 0–8 gemischt, from: aufgelöst,
                                             │              Element-Defaults und Ableitungsregeln angewandt (4.7),
                                             │              Expander gelaufen, Werte als Knoten, Herkunft je Blatt)
                                             │ vofi_validate()   (vier Ebenen, sammelt alle Befunde)
                                             ▼ vofi_build()
                                          vofi_model       (Raster, sortierte Komponenten, Instrumente, Ketten,
                                             │              Sampler-Plan, Steuermodul, KPI-Satz, Hash)
                                             ▼ vofi_run() / vofi_mc() / vofi_compare() / vofi_sensitivity()
                              vofi_result | vofi_mc_result | vofi_comparison | vofi_sensitivity
```

### 4.2 Oberste Ebene (Schema v1)

Unbekannte Schlüssel der obersten Ebene sind ein Validierungsfehler (mit Vorschlag per `utils::adist`).³

| Block | Typ | Pflicht | Ebene | Inhalt |
|---|---|---|---|---|
| `schema_version` | integer | ja | Meta | `1` |
| `meta` | Map | ja | Meta | Kennung, Titel, Autor (4.3.1) |
| `project` | Map | ja | Domäne | Perspektive, Projektart, Stichtag, Horizont, Rechtsstand (4.3.2) |
| `grid` | Map | nein | Raster | Bauphase und Rasterschritte (4.3.3) |
| `building` | Map | ja¹ | Domäne | Gebäudedaten (4.3.4) |
| `household` | Map | nein | Domäne | Haushaltsdaten für Selbstnutzer und Kleinvermieter (4.3.5) |
| `unit_groups` | Map nach id | nein | Domäne | Wohnungsgruppen, Mieten, Mietregime (4.3.6a) |
| `measures` | Map nach id | nein | Domäne | Maßnahmen und Bauteile (4.3.6) |
| `energy` | Map | nein | Domäne | Energieträger, Zustände vorher/nachher, Performance Gap (4.3.6b) |
| `funding` | Map nach id | nein | Domäne | Förderinstrumente, meist `from:` Bibliothek (4.3.7) |
| `components` | Map nach id | nein | Komponente | explizite Zahlungskomponenten (`type` + Parameter) (4.3.8) |
| `financing` | Map nach id | nein | Komponente | Eigenkapital und Kredite (`type` + Parameter) (4.3.9) |
| `accounts` | Map | nein² | Engine | Konten, Ausgleichsketten, Engpass-Policy (4.3.10) |
| `market` | Map | nein | Markt | deterministische Marktannahmen (Basisfall) (4.3.11) |
| `residual_value` | Map | nein² | Domäne | Restwertmethode und Parameter (4.3.12) |
| `tax` | Map | nein | Steuer | Steuermodul, Standard `none` (4.3.13) |
| `analysis` | Map | nein² | Auswertung | Kennzahlen, Schwellen, Pflichtsensitivitäten (4.3.14) |
| `stochastic` | Map | nein | Unsicherheit | Overlay nach Abschnitt 11 (4.3.15) |
| `shared` | Map | nein | Hilfe | gemeinsame Bausteine für `{ref: shared.…}` und YAML-Anker; wird nie direkt gerechnet |
| `variants` | Map nach id | nein | Varianten | Varianten als Operationen auf der Basis (4.11) |
| `scenario_sets` | Map nach id | nein | Varianten | deterministische Szenario-Sets (A-24), mit Varianten kreuzbar (4.11) |

¹ `building` darf fehlen, wenn nur `components`/`financing` angegeben sind (Orakel, Lehrbuchbeispiele).
² Defaults aus Profil und `global.yaml` (Schichten 1–2).
³ Die reservierten Wurzelschlüssel `defaults_meta`, `by_project_type` (beide in `global.yaml` und Profilen) und
`item_defaults` (nur `global.yaml`) sind ausschließlich in Defaults-Dateien zulässig (4.7, R-85); in einer
Szenariodatei, einer Overlay-Datei oder einer Nutzerbibliothek sind sie ein Validierungsfehler.

### 4.3 Blöcke (zwei Ebenen; Feldkatalog im Detail: Spec 01)

Die Feldlisten in 4.3.1–4.3.15 sind **Auszüge**. Maßgeblich für Schema, Defaults und Validierung (Ebene 2) sind die
Feldtabellen von Spec 01 Teile A–C (Rang 3, 1.2); ein dort genanntes Feld ist ein gültiger Schlüssel, auch wenn es
hier fehlt (R-106). Strukturen, Semantik und Namen dieser Spezifikation gehen Spec 01 vor.

Typangaben: `chr`, `int`, `num`, `lgl`, `date`, `enum:<vokabular>`, `value` (Wertgrammatik 4.5), `map`, `ids` (Liste
von ids). Einheiten stehen als Suffix im Schlüssel (`_eur`, `_pa`, `_share`, `_m2`, `_months`, `_years`, `_year`,
`_date`, `_eur_m2_month`, `_kwh`, `_kwp`).

#### 4.3.1 `meta`

| Feld | Typ | Default | Bemerkung |
|---|---|---|---|
| `scenario_id` | chr `^[a-z][a-z0-9_]*$` | Pflicht | |
| `project_id` | chr | = `scenario_id` | Portfolio-fähig (v2), R-50 |
| `title` | chr | Pflicht | |
| `author`, `description` | chr | `NULL` | |
| `created_date` | date | `NULL` | |
| `tags` | chr[] | `[]` | |

#### 4.3.2 `project`

| Feld | Typ | Default | Bemerkung |
|---|---|---|---|
| `perspective` | enum:perspective | Pflicht | `wu_kommunal`, `wu_genossenschaft`, `wu_privat`, `kleinvermieter`, `selbstnutzer` |
| `tax_regime` | enum:tax_regime | aus Perspektive | `wu_kommunal`→`wu_kommunal`, `wu_genossenschaft`→`wu_eg_befreit`, `wu_privat`→`wu_kapges`, `kleinvermieter`→`privat_vermieter`, `selbstnutzer`→`selbstnutzer`; weitere: `wu_eg_stpfl`, `wu_gemeinnuetzig` (R-08) |
| `project_type` | enum:project_type | Pflicht | `neubau`, `sanierung_eh`, `sanierung_einzelmassnahmen`, `sanierung_stufenweise`, `heizungstausch`, `erwerb_sanierung`, `erwerb_neubau` (R-09) |
| `comparison_mode` | enum `absolute`, `differential` | `absolute` | R-04 |
| `valuation_date` | date (Monatserster) | Pflicht | t = 0 |
| `horizon_years` | int ≥ 1 | Profil | Länge des Horizonts ab `valuation_date`; Horizontende fest für alle Varianten und Läufe (3.3, R-49, R-67) |
| `application_date` | date | `valuation_date` | Förderstichtag (Antragsdatum) |
| `legal_state` | date | `valuation_date` | Rechtsstand (4.10) |
| `pending_reforms` | chr[] enum:reform | `[]` | z. B. `mietrecht_ii`; Standard aus (D10) |
| `federal_state` | enum:federal_state | `NULL` | Pflicht, sobald Grunderwerbsteuer anfällt |
| `municipality` | map | alle `false` | `mietpreisbremse_area`, `mietpreisbremse_until`, `kappung_15_area`, `index_cap_area`, `milieuschutz` |
| `price_base_year` | int | Jahr(`valuation_date`) − 1 | Preisstand = **1. Januar des Folgejahres** (R-35); „Kostenstand Y“ einer Maßnahme zum 1. Januar Y (Memo 07) ist `price_base_year: Y − 1` |
| `construction_delay_months` | value (number ≥ 0) | `0` | Bauzeitverzug, stochastisch zulässig (3.9, R-60) |
| `reference_variant` | chr | `"base"` | Bezug für `vofi_compare()`; bei Bestandsprojekten Pflicht: eine vorhandene Bestands- bzw. Ohnehin-Variante (12.3a, R-68) |
| `report_mode` | enum `auto`, `expert`, `household` | `auto` | `auto`: `wu_*` → `expert`, sonst `household` |

#### 4.3.3 `grid`

| Feld | Typ | Default |
|---|---|---|
| `construction_months` | int ≥ 0 | `0` |
| `construction_step_months` | int ∈ {1, 3, 6, 12} | `12` |
| `operation_step_months` | int (v1: 12) | `12` |
| `operation_alignment` | enum `calendar`, `completion` | `calendar` |
| `periods_months` | int[] | `NULL` |

#### 4.3.4 `building` (Auszug; vollständig in Spec 01)

`building_id` (chr, Default `"b1"`), `building_type` (enum), `construction_year` (int), `n_units` (int),
`living_area_m2` (num), `net_floor_area_m2` (num), `component_areas_m2` (Map Bauteil → num), `energy_class_before`,
`energy_class_after`, `efficiency_standard_after` (enum), `wpb_flag`, `denkmal` (lgl), `heating_existing` (Map),
`consumption_kwh` (Map Träger → num, Brennwert H_s), `market_value_eur` (value), `land_value_eur` (value),
`existing_value_eur` (value, Default `NULL`; **Bestandswert** = Verkehrswert vor der Maßnahme zum Stichtag,
Opportunität „heute verkaufen“; erzeugt die Sacheinlage `equity_in_kind` und den Verkauf in der
Unterlassungsalternative, 9.3, 9.5 Nr. 7, R-68).

#### 4.3.5 `household`

`net_income_month_eur` (value), `income_growth` (value, Default `{ref: market.inflation}`), `taxable_income_avg_eur`
(num), `n_children_u18` (int), `savings_capacity_month_eur` (value; Markierung, wenn Nachschüsse sie übersteigen),
`current_rent_month_eur` (value, Default `NULL`; bisherige Miete des Selbstnutzers während der Bauphase, nur für
`monthly_burden_construction`, 12.3; keine Ledger-Zeile), `expected_income_tax_eur_pa` (value, Default `NULL`;
voraussichtliche tarifliche Einkommensteuer je Jahr, deckelt die § 35c-Tranchen, 10.9, R-79).

#### 4.3.6 `measures` (je Maßnahme; Auszug)

`label` (chr), `measure_type` (enum:measure_types), Zeitpunkt **genau eines von** `date` (date) | `year` (int) |
`payment_schedule` (Wertform `schedule`), `completion_date` (date, Default letzter Zahlungstermin), `cost_eur` (value,
brutto), `vat_rate` (share, Default 0.19), `price_base_year` (int, Default `project.price_base_year`), `price_index`
(value, Default `{ref: market.construction_price_index}`), `useful_life_years` (number, stochastisch zulässig, 3.9),
`delay_months` (number ≥ 0, Default 0, stochastisch zulässig, 3.9), `ohnehin_share` (share) oder
`ohnehin_cost_eur` (value), `classification` (enum `auto`/`erhaltung`/`herstellung`), `modernization_kind` (enum),
`kg` (int, DIN 276), `asset_type` (enum:asset_types), `replaces_ohnehin` (ids), `effects` (Map, Spec 01),
`active` (value 0/1, Default 1, stochastisch zulässig; „Maßnahme findet statt“, Aktivierungsfaktor 4.12 Nr. 7, R-71).

#### 4.3.6a `unit_groups` (je Wohnungsgruppe; Auszug)

`label`, `n_units` (int), `living_area_m2` (num), `rent_eur_m2_month` (value, Nettokaltmiete), `rent_regime` (enum
`paragraph_558`, `staffel`, `index`, `bound_social`, `cooperative_fee`, `owner_occupied`), `owner_occupied` (lgl),
`rent_growth` (value, Default `{ref: market.rent_growth}`), `vacancy_rate` (value), `rent_roll` (optional Map je WE für
§ 559-Kappung), `rent_law` (Map: `modernization_levy`, `voluntary_cap_per_m2`, `hardship_share`, Spec 01; eine
freiwillige Begrenzung „warmmietenneutral“ wird im Basisfall in der Bezugsperiode nach 6.3 bestimmt und gilt fest in
allen Läufen, R-70, R-102), `imputed_rent_eur_m2_month` (value, Selbstnutzer). Gemeinsame Defaults aller Gruppen
stehen in `global.yaml#item_defaults.unit_groups`; von Nutzung bzw. Perspektive abhängige Defaults (z. B.
Selbstnutzung: keine Verwaltung, kein Leerstand, kein Mietausfall; Genossenschaft: `cooperative_fee`) setzt die
Ableitungsregel `rule:unit_group_defaults` (4.7, R-85, R-86), nicht das Profil (R-76). Der Mietpfad einer Wohnungsgruppe ist **eine** monatlich rechnende
Komponente `rent_path` mit den Zeilen Miete, Mietausfall und Modernisierungsumlage je Maßnahme; §§ 558, 559, 559c,
559e und die Mietpreisbremse sind Rechtsregeln, die diese Komponente aufruft (R-63, 4.12).

#### 4.3.6b `energy` (Auszug)

`carriers` (Map Träger → `{price_eur_kwh: value, base_fee_eur_pa: value, emission_factor_kg_kwh: num, vat_rate: share}`,
Preise meist `{ref: market.energy_price.<träger>}`), `before` und `after` (Zustände: `demand_kwh`, Trägeranteile,
`efficiency` bzw. `jaz` (**realisierte** JAZ, stochastisch zulässig; steuert Strombedarf und Warmmiete), `jaz_plan`
(**Plan-JAZ** des Nachweises nach VDI 4650, `deterministic_only`, Default `NULL` = Basisfallwert von `jaz` über
`ctx$value_base()`; steuert § 559f, R-70), Vorlauftemperatur, `consumption_basis` ∈ `measured`/`demand`, Einbaudatum
der Heizung für § 5a CO2KostAufG), `performance_gap` (Map, **Strukturmodell** nach Konzept B7: `prebound_factor` und
`rebound_factor` (value; Faktoren auf den Bedarf vor bzw. nach der Maßnahme, stochastisch zulässig; mit
Verbrauchsdaten entfällt der Vorher-Faktor), optional `realisation_factor` (value, Default 1; einfacher
Realisierungsfaktor, D8)), `pv` (Map, Spec 01). Weitere Zustände stehen in `stages` (Map nach id, ids ≤ 12 Zeichen).
Trägerfelder ohne Angabe kommen aus `global.yaml#item_defaults.energy.carriers` (z. B. `price_eur_kwh: {ref:
market.energy_price.{id}}`) und aus `rule:carrier_defaults` (Trägerklasse, Faktoren aus `legal/*`, Netzentgelt nur bei
vorhandenem Marktnamen) (4.7, R-85, R-86). Der Energie-Expander erzeugt je Zustand und Träger eigene Komponenten
(7.10, R-90).

#### 4.3.7 `funding` (je Instrument; Datenmodell Memo 02 §5.8)

`from` (Bibliotheks-id), `instrument_type` (enum `grant`, `loan`, `loan_with_repayment_grant`, `interest_subsidy`,
`tax_credit`, `rent_binding`), `measures` (ids), `application_date` (date, Default `project.application_date`),
`approved` (value 0/1, Default 1), `approval_probability` (share; Default über die Ableitungsregel
`rule:approval_probability` (WS-A, 4.7): Basiswert b = `{ref: funding.<f>.budget_risk.approval_probability}` bzw. 1
ohne `budget_risk`; bei `application_date` ≥ 2031-01-01 `{expr: "<b> * funding.<f>.availability_after_2030"}`, sonst
b; R-86), `availability_after_2030` (share, Default 0.7 über `global.yaml#item_defaults.funding`; Verfügbarkeit des
Programms nach 2030, Memo 07 §4.0), `payout_delay_months`
(number ≥ 0, stochastisch zulässig, 3.9), weitere Felder nach Memo 02 §5.8 (Spec 01). § 35c EStG ist
`instrument_type: tax_credit` (R-11). **Zusagerisiko (9.11, R-71):** `approval_timing` (enum `auto`, `before_start`,
`after_start`; `auto` = `before_start`, wenn `application_date` ≤ frühester Termin der Maßnahmen der Variante; der Code
`auto` wird vor den Expandern durch `rule:approval_timing` (WS-A, 4.7, R-86) aufgelöst, sodass alle Verbraucher – Expander,
Validierung, `smp_plan()` (11.6 Nr. 4), `vofi_build()` (9.11) – nur `before_start` bzw. `after_start` lesen),
`fallback_variant` (Varianten-id, Default `NULL`; macht ein `before_start`-Instrument zum **Entscheidungsknoten**),
`on_reject` (enum `balance`, `drop_measures`, Default `balance`; nur ohne Entscheidungsknoten: Lücke über den Ausgleich
bzw. Wegfall der geförderten Maßnahmen).

#### 4.3.8 `components` (je Komponente)

| Feld | Typ | Bemerkung |
|---|---|---|
| `type` | chr (registrierter `flow`-Typ) | Pflicht |
| `label`, `description` | chr | Anzeigename (darf deutsch sein; YAML ist kein R-Code) |
| `after` | ids | ausdrückliche Abhängigkeiten (zusätzlich zu `ref`-Parametern) |
| `asset_id`, `measure_id`, `funding_id`, `program` | chr | Default-Tags für alle Zeilen der Komponente |
| weitere | nach Parameterschema des Typs | Typparameter stehen **flach** neben den Metafeldern (4.13) |

**Reservierte Metafelder** jeder Komponente und jedes Finanzierungsbausteins: `id`, `type`, `label`, `description`,
`after`, `origin`, `asset_id`, `measure_id`, `funding_id`, `program`. Sie sind keine Typparameter; ein Typ darf keinen
Parameter mit einem dieser Namen deklarieren (Registrierungsfehler C3). Typen lesen sie über `spec[["<feld>"]]`.

#### 4.3.9 `financing` (je Baustein)

`type` (chr: `equity` oder registrierter `instrument`-Typ), Metafelder wie 4.3.8, typspezifische Parameter (8.2) flach
daneben. Höchstens ein Baustein je Variante darf `amount_eur: auto` haben und höchstens einer `amount_eur: topup`
(Nachfinanzierung) (8.7); Bestandsdarlehen tragen `existing: true` (8.2) und sind in allen Gebäudevarianten identisch
(9.6 Nr. 2). ids sind über `components` ∪
`financing` gemeinsam eindeutig (Validierungsebene 3), weil `ctx$component()`, `after` und Bezüge beide Sammlungen
adressieren.

#### 4.3.10 `accounts`

| Feld | Typ | Default | Bemerkung |
|---|---|---|---|
| `deposit_rate_pa` | value (Pfad zulässig) | Profil | effektiver Habenzins p. a.; im MC als Abstand zum Zinspfad mit `{ref: …, anchor: <h>}`, sodass der Startwert dem deterministischen Habenzins entspricht (4.5, Konzept F18, R-76) |
| `overdraft_rate_pa` | value (Pfad) | Profil | effektiver KK-Zins p. a. (Kontokorrent bzw. Zwischenfinanzierung); Kopplung wie `deposit_rate_pa` |
| `overdraft_limit_eur` | value (Pfad, `.inf` zulässig) | Profil | Limit der Regeltranche; Überschreitung löst die D4-Aktion aus (WU: `penalty_rate` = Limit als Warnschwelle mit Strafzins und Markierung `limit_breach`; privat: `equity_call` = Nachschuss, Markierung `equity_call_over_savings` bei Überschreiten der Sparfähigkeit; Konzept A2, R-76); sinkt es unter den Stand, wird der Überhang zu Beginn des Ausgleichs zwangsweise getilgt (9.3 Schritt (6a)) |
| `penalty_spread_pa` | value | Profil | Aufschlag der Strafzinstranche auf `overdraft_rate_pa` (Konzept A2) |
| `min_liquidity_eur` | value (Pfad) | Profil | L_min |
| `deposit_withholding_tax_share` | share | `0` | pauschale Abgeltungsteuer auf positive Habenzinsen inkl. Solidaritätszuschlag und optional Kirchensteuer (D5, R-40); Vorschlagswert 0.26375 |
| `deposit_tax_allowance_eur_pa` | amount ≥ 0 | `0` | für diese Anlage verfügbarer Sparer-Pauschbetrag je Jahr; mindert die Bemessung der Abgeltungsteuer (8.8, Konzept 3.12, R-76) |
| `overdraft_flag_threshold_eur` | num | Profil | reine Markierungsschwelle ohne Zinswirkung (`overdraft_threshold`, 9.8) |
| `surplus_order` | chr[] | `[od_repay, dep_fill_reserve, dep_invest]` | erste Aktion MUSS `od_repay`, letzte `dep_invest` sein, Ränge aufsteigend (8.9); `loan_prepay` aktiviert Ü3 (R-29) |
| `deficit_order` | chr[] | Profil: WU `[dep_withdraw, od_draw, dep_use_reserve, penalty_rate]`, privat `[…, equity_call]` | erste Aktion MUSS `dep_withdraw`, letzte `equity_call`, `penalty_rate` oder `stop` sein, Ränge aufsteigend (8.9, R-30) |
| `prepay` | map | `{buffer_eur: 0, min_spread_pa: 0}` | Parameter von Ü3 |

#### 4.3.11 `market`

Map Name → value. Namen sind snake_case, Gruppen als verschachtelte Map (`energy_price: {gas: …, power: …}` ergibt
die Pfade `market.energy_price.gas`). Raten (Inflation, Wachstum, Zinsen) sind Dezimalzahlen p. a. Kanonische Namen
(Spec 01): `inflation`, `rent_growth`, `rent_growth_new`, `construction_price_index`, `maintenance_index`,
`land_value_growth`, `market_value_growth`, `operating_cost_growth`, `mortgage_rate`, `bund_yield_10y`,
`mortgage_spread`, `co2_price`, `energy_price.<träger>`, `energy_network_fee.<träger>`, `bio_fuel_premium`,
`feed_in_tariff.<klasse>` (Klassen `partial_le10kwp`, `partial_10_40kwp`, `partial_40_100kwp`, `full_le10kwp`),
`vacancy_fluctuation` (R-103). Trägercodes nach Spec 01 Teil B §3.2.1 (`gas`, `gas_mfh`, `oil`, `lpg`, `power`,
`power_mfh`, `heatpump_power`, `heatpump_power_mfh`, `district_heating`, `pellets`); für jeden kanonischen Träger
liefern `global.yaml` und die Bibliothek einen Marktpreis `energy_price.<träger>`. **Energiepreise, Netzentgelte,
Bio-Mehrkosten und CO2-Preis sind netto (ohne USt)**; die USt setzt `energy.carriers.<c>.vat_rate` auf.
Komponenten verweisen per `{ref: market.<name>}` darauf.

#### 4.3.12 `residual_value`

`method` (enum:residual_method: `zero`, `market_growth`, `income_value`, `component`, `asset_value`, `multiplier`,
`exit_yield`, `user_value`; R-34), `sale_cost_share` (share, Default 0.03), methodenspezifische Parameter (Spec 01).
Der Ausweis ohne Restwert ist immer aktiv (12.5).

#### 4.3.13 `tax`

`module` (chr, registriertes Steuermodul, Default `"none"`), `params` (Map, modulspezifisch).

#### 4.3.14 `analysis`

| Feld | Typ | Default |
|---|---|---|
| `kpis` | chr[] oder `"default"` | Profil |
| `primary_kpi` | enum `auto`, `delta_terminal_value`, `delta_vs_reference` | `auto` (12.3a) |
| `allow_opportunity_reference` | lgl | `FALSE`; `TRUE` erlaubt bei Bestandsprojekten ausdrücklich die Unterlassungsalternative als Referenz (12.3a, R-68) |
| `deterministic_point` | enum `mode`, `median`, `mean` | `mode` |
| `thresholds` | map | Profil; Schlüssel `dscr`, `burden_share`, `warm_rent_increase_eur_m2`, `roe_hurdle` (Konzept A4; Werte Spec 01) |
| `stabilization_year` | int (Kalenderjahr) | `NULL` = Kalenderjahr des ersten vollen Betriebsjahres; Beginn der DSCR-/ICR-Auswertung (12.3, R-77) |
| `lending_value_haircut` | share | Profil; Sicherheitsabschlag Beleihungswert = V_t × (1 − Abschlag) (12.3, R-72) |
| `rv_path_basis` | enum `auto`, `method`, `measures` | `auto` (= `measures` im Haushaltsmodus, sonst `method`); Restwertpfad der Vermögensamortisation (12.2, R-72) |
| `restrictions` | chr[] aus Enum `restriction` (`enums.yaml`: `dscr`, `liquidity`, `warm_rent`, `burden`, `savings`) | Profil; K.-o.-Kennzeichen der Ampel je Perspektive (12.9, R-74) |
| `traffic_light` | map | `{green_prob, red_prob, restriction_prob}` (Konzept 1.4, A4: 0.70, 0.40, 0.30; Werte Spec 01) |
| `mandatory_sensitivities` | Liste | Profil; je Eintrag `{id, path, label}` und genau eines von `value`, `delta`, `add` (`add` hängt Codes an eine Liste an, z. B. `{path: project.pending_reforms, add: stufe_2045}`); Inhalte nach Konzept 5.5 in Spec 01 (R-82). `value` darf eine Wertform sein (z. B. `{ref: market.mortgage_rate}`); sie ersetzt den Knoten am Pfad einschließlich einer `anchor`-Kopplung. `delta` wirkt bei einer Bezugsform mit `anchor` auf den Anker (die Kopplung bleibt erhalten). Ausgeführt wird jede Pflichtsensitivität als Override in Schicht 8 (R-107) |
| `tenant_view` | lgl | `TRUE` für `wu_*`, sonst `FALSE` |

#### 4.3.15 `stochastic` (Overlay; Semantik Abschnitt 11)

```yaml
stochastic:
  settings:     {preset: standard, n_sim: 10000, seed: 20261025, sampling: lhs, block_size: 200, antithetic: false,
                 copula: iman_conover, start_year: null, store: bands,
                 keep_runs: [p05, p50, p95], keep_runs_kpi: delta_terminal_value,
                 bands: [net_position, dep_balance, od_balance], band_probs: [0.05, 0.25, 0.5, 0.75, 0.95],
                 auto_funding_approval: true,
                 convergence: {rel_halfwidth_mean: 0.005, abs_halfwidth_prob: 0.01}}
  parameters:   {<key>: {target: <pfad>, label: <de>, dist: <verteilung>, <parameter>, base: <optional>,
                         apply: replace | multiply | add, from: <optional>}}
  processes:    {<key>: {target: <pfad>, label: <de>, type: <prozess>, <parameter>, from: <optional>}}
  correlations: {parameters: [[<key_a>, <key_b>, <rho_spearman>]], shocks: [[<proc_a>, <proc_b>, <rho>]]}
```

Das Overlay kann als eigene Datei vorliegen (`vofi_read_scenario(path, stochastic = "datei.yaml")`, Wurzelschlüssel
`stochastic`); es wird über den Block der Szenariodatei gemischt (Datei gewinnt). Statt `block_size` darf
`replicates` (Anzahl der Blöcke, Konzept F21) angegeben werden, beide zugleich sind ein Validierungsfehler (11.4,
R-73).

- **`preset` (R-97):** `preview` = `n_sim` 1.000, `store: kpi`, `keep_runs: []`; `standard` (Default) = 10.000;
  `report` = 50.000; `custom` = nur ausdrückliche Felder. Die Blockgröße bleibt 200, jedes Preset ist ein Präfix des
  größeren (R-73). **Vorrang:** Funktionsargumente (`vofi_mc()`, `vofi_run()`) > ausdrücklich gesetzte Felder aus
  Schichten ≥ 3 (Szenario, Overlay-Datei, Variante, Set, Override) > Werte des Presets > Felder aus Schichten 0–2.
  `global.yaml` setzt `preset: standard` und **kein** `n_sim`. `vofi_mc(preview = TRUE)` entspricht `preset:
  preview`. `convergence` steuert nur den Ausweis `converged` (12.7), keine automatische Verlängerung (v1.1).
- **`apply` (R-94):** nur für statische Einträge (`parameters`), nicht für `processes`; Default `replace`. `multiply`
  nur für Verteilungen mit Träger ⊂ [0, ∞) oder `bernoulli`; bei Zielen der Art `share` wird das Ergebnis auf [0, 1]
  begrenzt (Hinweis). Kurzformen am Ort (4.5) haben immer `apply: replace`. Semantik in 6.3 Schritt 1, 11.2, 11.8,
  11.11.
- **Bibliotheksvorlagen (R-87):** Die Nutzlast eines `processes/*`-Eintrags darf eine Map mehrerer Overlay-Vorlagen
  sein (Auswahl mit `use:`, z. B. `{target: …, from: processes/cost_risks_2026, use: overrun_retrofit}`) bzw. eine
  Sequenz von Korrelationspaaren (`correlations.shocks: {from: processes/shock_correlations_2026}` ersetzt die lokale
  Liste, 4.9).
- **Korrelationspaare (R-96):** Ein Paar aus einer Bibliotheksliste, dessen Schlüssel im Overlay der Variante fehlt,
  wird mit `vofi_inform` verworfen; ein Paar aus der Szenariodatei (einschließlich Varianten und Sets) mit unbekanntem
  Schlüssel ist ein Validierungsfehler.

### 4.4 Sammlungen, ids und Pfade

1. Alle Sammlungen sind **Maps nach id**. Listen mit Feld `id` werden beim Einlesen in Maps umgewandelt (Reihenfolge
   bleibt erhalten; sie bestimmt u. a. die Anzeigereihenfolge der Kredite).
2. ids: `^[a-z][a-z0-9_]*$`, keine Punkte, kein doppelter Unterstrich, höchstens 40 Zeichen. Reserviert sind `base`
   (Variante), `engine` und die Präfixe `m_`, `u_`, `f_`, `e_`, `h_`, `rv_`, `x_` für vom Expander erzeugte
   Komponenten (R-18). ids von `components` und `financing` sind gemeinsam eindeutig (4.3.9). Lokale Zeilennamen und
   Parameternamen folgen demselben Muster (ohne doppelten Unterstrich); dadurch ist der Ledger-Trenner `__` (7.3)
   eindeutig. **Erzeugte ids** (Präfix + Nutzer-id(s) + Rolle, 4.12) unterliegen derselben Grenze von 40 Zeichen; die
   Validierung (Ebene 3, WS-B) prüft jede erzeugte id und meldet bei Überschreitung einen Fehler mit der zulässigen
   Höchstlänge der Nutzer-id (R-90). Daraus folgen die Höchstlängen: Maßnahmen und Bestandsbauteile ≤ 29 Zeichen
   (`m_<m>_purchase`), Wohnungsgruppen ≤ 25 (`u_<g>_property_tax`, `u_<g>_imputed_rent`), Förderinstrumente ≤ 30
   (`f_<f>_subsidy`), Energiezustände (`stages`) ≤ 12 und Träger ≤ 20 (`e_<s>_<c>_cost`).
3. **Pfade** sind punktgetrennte Schlüssel, z. B. `financing.bank.rate_pa`, `measures.huelle.cost_eur`,
   `market.energy_price.gas`, `financing.bank.fees.processing_fee_share` (Feld eines `map`-Parameters).
   Typparameter liegen flach in der Komponente; der Pfad `components.<id>.<param>` ist daher identisch in YAML,
   `vofi_spec`, Overlay-Zielen, Variantenoperationen, Herkunft und `ctx$param()` (4.13). Sequenzen werden nie
   elementweise adressiert (sie werden als Ganzes ersetzt); soll ein Element unsicher sein, verweist das Element per
   `{ref: …}` auf ein adressierbares Blatt (4.5 Regel 4).
4. Pfadfunktionen (intern, `R/utils-path.R`): `path_get(x, path)`, `path_set(x, path, value)`,
   `path_remove(x, path)`, `path_exists(x, path)`, `path_split(path)`, `path_join(...)`, `path_leaves(x)` (alle
   Blattpfade; Wertformen nach `is_value_form()` gelten als Blätter).

### 4.5 Wertgrammatik

Jeder numerische Parameter (Schema-Art `value`, `amount`, `rate`, `share`, `number`) darf eine der folgenden Formen
haben. `values-normalize.R` (WS-A) überführt sie in **Knoten** `list(kind = …, …)`; `values-resolve.R` (WS-D)
wertet Knoten im Laufkontext aus (6.3). Typen sehen nie Rohformen.

| Form | YAML | Knoten | Auswertung (Shape) |
|---|---|---|---|
| Konstante | `0.039` | `list(kind = "const", value = 0.039)` | scalar |
| Reihe je Periode | `[v0, v1, …, vT]` (Länge exakt T+1) | `list(kind = "series_t", values)` | path |
| Reihe je Kalenderjahr | `{series: {2027: 0.028, 2028: 0.022}, fill: locf, before: first}` | `list(kind = "series_year", years, values, fill, before)` | path; Spalte j = Wert für `year[j]`; `fill` ∈ `locf`, `zero`, `linear`; `before` ∈ `first`, `zero` |
| Stützstellen | `{years: [2026, 2030, 2045], values: [60, {ref: shared.co2_2030}, 200], interpolate: linear}` | `list(kind = "points", years, values = list(<knoten>), interpolate)` | path; linear (bzw. `step`) über Kalenderjahre, außerhalb konstant; Elemente von `values` dürfen skalare Knoten sein (Regel 4) |
| Zahlungsplan (einmalig) | `{schedule: {2027-01-01: 100000, 2030: 50000}}` | `list(kind = "schedule", dates, amounts)` | path: Betrag in Periode `grid_period_of(date)`; Jahre nach 3.4; Beträge dürfen selbst `value` sein |
| Bezug | `{ref: market.rent_growth, scale: 1, offset: 0, floor: -.inf, cap: .inf, anchor: null}` | `list(kind = "ref", path, scale, offset, floor, cap, anchor)` | Shape des Ziels; ohne `anchor`: `pmin(pmax(x * scale + offset, floor), cap)`; mit `anchor` a (Zahl): `pmin(pmax(a + scale * (x - x[, 1]) + offset, floor), cap)`, d. h. der Wert folgt dem Pfad x mit festem Abstand, und der Startwert (Spalte 1 = t0) ist a (Habenzins im MC passend zum deterministischen Wert, Konzept F18/A2, R-76) |
| Wachstum | `{start: 7.2, growth: {ref: market.rent_growth}, base_date: null, real: false, index: calendar_year}` | `list(kind = "growth", start, growth, base_date, real, index)` | path: `index: calendar_year` (Default): `start * grid_index_year(g, base_date)` (Kalenderjahreswert, je Kalenderjahr konstant, R-62; wie Prozesse in Kalenderjahren, 11.7); `index: period_end`: `start * grid_index(g, base_date)` (Stichtagswert zum Periodenende, nur für Bestandsgrößen wie einen Marktwertpfad, z. B. Orakel (c)); `base_date` Default = Preisstand (`price_base_year`); `real: true` → nominal g = (1+g)(1+π) − 1 mit π = `market.inflation`. Stichtagsgrößen, die ein Typ selbst fortschreibt, bildet er über `ctx$index()` (R-91) |
| Ausdruck | `{expr: "building.living_area_m2 * 150"}` | `list(kind = "expr", text, ast)` | sichere, vektorisierte Auswertung (Regel 5); Symbole mit Punkt = Pfade |
| Mengenbezug | `{value: 14, per: m2_living_area}` | `list(kind = "quantity", value, per)` | `value × Bezugsgröße`; `per` ∈ `total`, `unit`, `m2_living_area`, `m2_net_floor_area`, `m2_component:<bauteil>`, `parking`, `kw`, `kwp`, `kwh`; Bezugsgröße zuerst am Bezugsobjekt (Parameter der Komponente bzw. Element des Domänenblocks), dann aus `building`: `unit` → `n_units`, `m2_living_area` → `living_area_m2`, `m2_net_floor_area` → `net_floor_area_m2` (A_N), `m2_component:<b>` → `component_areas_m2.<b>`, `parking` → `n_parking`, `kw`/`kwp`/`kwh` → gleichnamiges Feld des Bezugsobjekts (R-91) |
| Verteilung (Kurzform) | `{dist: pert, min: …, mode: …, max: …, base: …}` | wird beim Normalisieren ins Overlay verschoben (Schlüssel = Zielpfad); am Ort bleibt `const` mit Basiswert | scalar |
| Automatisch | `auto` bzw. `topup` | `list(kind = "auto", mode = "auto")` bzw. `mode = "topup"` | nur bei Parametern mit `allow_auto = TRUE` (8.7): `auto` = Betrag aus dem Basisfall, fest in allen Läufen; `topup` = Nachfinanzierung je Lauf (R-69) |
| Bibliotheksverweis | `{from: prices/co2_paths_2026, use: scenarios.mittel, …}` | wird in Schicht 3 aufgelöst (4.9), kein Knoten | – |

Regeln:

1. Der Basiswert einer Kurzform-Verteilung ist `base`, sonst `point(par, analysis.deterministic_point)`.
2. Bezüge und Ausdrücke dürfen keine Zyklen bilden (Validierung Ebene 3) und **nie auf endogene Größen** (Konten,
   Steuern, Ledger-Zeilen) zeigen. Zulässige Ziele: Blätter der Blöcke `project`, `building`, `household`,
   `unit_groups`, `measures`, `energy`, `funding`, `components`, `financing`, `market`, `residual_value`, `shared`.
3. `{ref: …}` auf ein Ziel, auf das ein Prozess des Overlays zeigt, liefert in der MC dessen n × (T+1)-Pfad.
4. **Knoten als Elemente** (R-64): Die Elemente von `values` in `points` und `series_t` sowie die Werte von `series`
   in `series_year` dürfen Zahlen oder skalare Knoten (`const`, `ref`, `expr`) sein. Jedes Element wird als n-Vektor
   aufgelöst, danach wird vektorisiert interpoliert. So wird z. B. der CO2-Preis mit unsicheren Stützstellen 2030 und
   2040 (Memo 07 §4.0) über statische Overlay-Einträge auf `shared.co2_2030` und `shared.co2_2040` abgebildet; ein
   Element, das selbst zeitabhängig ist, ist ein Validierungsfehler.
5. **Ausdrücke** (`R/expr.R`, WS-B; Minimalfassung in Phase 0). Interne Signaturen (MUSS):

   ```r
   expr_parse(text)                  # -> ast (Klasse "vofi_expr"); Syntaxfehler oder nicht zugelassene Funktion
                                     #    -> vofi_error_input mit Position
   expr_symbols(ast)                 # -> character: alle Pfadsymbole (für Abhängigkeiten und Zyklusprüfung)
   expr_eval(ast, resolve, n, T)     # resolve = function(path) -> Skalar, n-Vektor oder n x (T+1) (aus value());
                                     # bei nicht-numerischen Blättern chr bzw. lgl (setting-Semantik, s. u.)
                                     # -> double n-Vektor oder n x (T+1)
   ```

   **Formregel:** Vor jeder binären Operation und jedem Funktionsaufruf werden die Operanden angeglichen: Länge 1 →
   n-Vektor (`rep_len`); ist mindestens ein Operand n × (T+1), werden alle n-Vektoren zeilenweise auf n × (T+1)
   gehoben (wie `ctx$by_sim()`). Zeitvektoren der Länge T+1 gibt es nicht. **Whitelist** (alles andere ist ein Fehler):
   Zahlen, Zeichenketten, `TRUE`/`FALSE`, Pfadsymbole mit Punkt; `+ - * / ^ %%`, unäres `-`/`+`, `(`;
   `< <= > >= == !=` (Ergebnis 0/1 als double); `& | !`; `ifelse` (drei Argumente, nur endliche Zweige); `pmin`,
   `pmax`, `abs`, `round`, `floor`, `ceiling`, `sqrt`, `exp`, `log`, `is.na`; `%in%` und `c()` nur mit
   deterministischen Operanden (Codes). `min`, `max`, `&&`, `||` sind **nicht** zugelassen, weil sie über Läufe
   aggregieren (2.8 Nr. 3); die Fehlermeldung schlägt `pmin`/`pmax` bzw. `&`/`|` vor.

   **Nicht-numerische Pfadsymbole (R-91):** Ein Pfadsymbol auf ein deterministisches nicht-numerisches Blatt (Arten
   `enum`, `ids` bzw. Code-Liste wie `project.pending_reforms`, `logical`, `string`) wird mit der Semantik von
   `ctx$setting()` zu `character` bzw. `logical` aufgelöst; `resolve()` darf für solche Pfade Zeichen- bzw.
   Wahrheitswerte liefern. Solche Operanden sind nur zulässig in `==`, `!=`, `%in%`, `!`, `&`, `|`; das Ergebnis
   ist 0/1 (double). Jede andere Verwendung ist ein Fehler (`vofi_error_input`). `expr_symbols()` meldet auch diese
   Symbole (Abhängigkeiten, Zyklen). Beispiel: `{expr: "ifelse('stufe_2045' %in% project.pending_reforms, 1, 0)"}`.
   Da diese Blätter deterministisch sind, ändert sich der Ausdruck nur über Schicht 8 bzw. ein neues Modell (z. B.
   Pflichtsensitivität mit `add`).

### 4.6 Zahlen, Einheiten, Datumsangaben (YAML-Leser, verbindlich)

YAML wird ausschließlich über `io_read_yaml_utf8(path)` gelesen:
`yaml::yaml.load(paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n"), handlers = …,
eval.expr = FALSE)` (funktioniert auch unter Locale `C`).

| Eingabe | Behandlung |
|---|---|
| `3,5` (Handler `int` bekommt den Rohtext `"3,5"`) bzw. `"3,5"` | → 3.5 mit `vofi_warning_input` |
| `"3,5 %"`, `"3.5%"` | → 0.035, Einheit `%` vermerkt |
| `150.000` (Handler `float#fix`, Muster `^[1-9]\d{0,2}\.\d{3}$`) | bei EUR-Parametern **Fehler** (`vofi_error_input`), sonst Warnung |
| `1.234.567`, `150_000`, `1e-2` (Zeichenketten) | → Zahl mit Hinweis |
| `2026-01-01` | → `Date`, wo das Schema `date` verlangt |
| `ja`/`nein`, `yes`/`no`, `true`/`false` | logisch, nur bei Schema `lgl` |
| `.inf`, `-.inf` | `Inf`, `-Inf` |
| Rate oder Anteil > 1 bei `_pa`/`_share` | **Fehler** mit Vorschlag („3,9 ist als 0.039 oder "3,9 %" anzugeben“) |

**Handler (MUSS, exakte Namen):** `int` (Rohtext; Werte außerhalb des Integer-Bereichs, z. B. `3000000000`, werden
als double angenommen, nie `NA`), `float#fix` (Dezimalzahlen mit Punkt, auch `150.000`), `float#exp`, `float#inf`,
`float#neginf`, `float#nan` (Fehler), `bool#yes`, `bool#no`. **Numerische Ablage:** Alle numerischen Blätter der
Wertgrammatik werden beim Normalisieren als `double` gespeichert; `integer` nur bei Parametern der Art `integer`
(5.4) und bei `schema_version`. Damit ist der Round-Trip YAML → XLSX → Liste (4.14) `identical()`.

Excel-Zellen speichern Zahlen gebietsschemaunabhängig; als Text eingegebene Zahlen wandelt der Excel-Leser mit
denselben Regeln um. Andere Einheiten als die kanonische Einheit eines Parameters werden **nicht** umgerechnet.

### 4.7 Schichten und Deep-Merge

| Nr. | Schicht | Quelle |
|---:|---|---|
| 0 | Typ-Defaults | Parameterschema der Registry (`vofi_param(default = …)`) |
| 1 | Globale Defaults | `inst/extdata/defaults/global.yaml` |
| 2 | Perspektiven-Profil | `inst/extdata/profiles/<perspective>.yaml` |
| 3 | Rechtsstand und Bibliothek | automatisch gewählte `legal/*`-Einträge (4.10) und `from:`-Verweise (Ketten erlaubt, Zyklen Fehler) |
| 4 | Nutzerbibliotheken | `vofi_library_paths()`; gleiche id überschattet den Paketeintrag (Warnung) |
| 5 | Szenario-Basis | Datei |
| 6 | Stochastik-Overlay | Block bzw. Datei `stochastic`; **wirkt nur in MC-Läufen** |
| 7 | Variante(n) | `extends`-Kette, dann Operationen (4.11); danach ggf. Szenario-Set |
| 8 | Laufzeit-Overrides | `overrides` von `vofi_resolve()`/`vofi_build()`, Sensitivität, Shiny |

**Defaults-Dateien (Schichten 1–2, R-85).** `global.yaml` und die Profile haben die Gestalt eines Szenario-Teilbaums
und dürfen daneben diese reservierten Wurzelschlüssel tragen (4.2 Fußnote ³):

1. `defaults_meta: {kind: global | profile, id, schema_version, as_of, quality, source, note}` (Pflicht in jeder
   Defaults-Datei). Wird **nie** gemischt; erscheint in `meta$defaults` des Ergebnisses (13.1) und als `entry` der
   Herkunft der aus der Datei stammenden Blätter.
2. `by_project_type`: Map `project_type → Teilbaum`. Der Teilbaum des aktuellen `project.project_type` wird
   **unmittelbar nach seiner Datei** gemischt (Schicht 1b bzw. 2b; Herkunft `global` bzw. `profile`, `entry =
   "<datei>#by_project_type.<code>"`). Im Profil gilt dafür die Profilrestriktion R-76 (unten).
3. `item_defaults` (**nur** `global.yaml`): einstufige Map Pfad (Zeichenkette mit Punkten, z. B. `"energy.carriers"`)
   → Vorlage. Ist der Pfad eine **Sammlung** (Map nach id: `unit_groups`, `measures`, `funding`, `financing`,
   `components`, `energy.carriers`, `energy.stages`, `building.elements`), wird für jedes vorhandene Element
   `element <- deep_merge(vorlage, element)` gesetzt (das Element gewinnt, einschließlich der Werte, die es über
   `from:` aus der Bibliothek und über die Ableitungsregeln erhalten hat). Ist der Pfad ein **optionaler Block** (`building`, `household`, `energy`,
   `energy.pv`, `energy.performance_gap`, `energy.before`, `energy.after`, `building.property_tax`,
   `building.maintenance`), gilt dasselbe nur, wenn der Block existiert; Defaults optionaler Blöcke stehen deshalb
   **nur** hier und nie als gewöhnlicher Block in `global.yaml` (sonst entstünde der Block in jedem Szenario, z. B. in
   den Orakeln ohne `building`). Vorlagen werden in aufsteigender Pfadtiefe angewandt (`energy` vor
   `energy.carriers`). Der Platzhalter `{id}` in Pfaden von `ref`- und `expr`-Knoten der Vorlage wird durch die
   Element-id ersetzt (z. B. `price_eur_kwh: {ref: market.energy_price.{id}}`). Herkunft `source_type = "global"`,
   `layer = 1`, `entry = "global#item_defaults.<pfad>"`. `from:`-Verweise in einer Vorlage werden vor ihrer Anwendung
   nach den Regeln von Schicht 3 aufgelöst (4.9; Herkunft dann `entry` = Bibliotheks-id, Gültigkeitsprüfung zum
   Rechtsstand der Variante).

Element-Defaults, die von anderen Feldern (Perspektive, Nutzung, Trägerklasse, Instrumentart, Rechtsstand) abhängen,
sind keine Vorlagen, sondern Ableitungsregeln (unten). **Reihenfolge:** Schicht 0 → `global.yaml` →
`global#by_project_type` → Profil → `Profil#by_project_type` → Schichten 3–8 → **Ableitungsregeln** →
**`item_defaults`** → Expander (4.12). Die spezifische Ableitung läuft also vor der allgemeinen Vorlage; beide füllen
nur fehlende Blätter (Beispiel: `rule:unit_group_defaults` setzt für eine selbstgenutzte Gruppe `vacancy_rate: 0`,
danach füllt `item_defaults.unit_groups` bei allen übrigen Gruppen `vacancy_rate: 0.025`).

**Ableitungsregeln (WS-A, `R/scenario-layers.R`, R-86).** Sie laufen in `vofi_resolve()` nach Schicht 8, vor
`item_defaults` und vor den Expandern, und zwar **je Variante, je Szenario-Set und je Override neu** (Varianten können
Elemente hinzufügen). Sie setzen nur **fehlende** Domänenblätter oder lösen den Code `auto` eines Enum-Felds auf (z. B.
`funding.<f>.approval_timing`); ein fehlendes Feld behandeln sie wie `auto`. Sie schreiben Werte, Codes, `ref`- oder
`expr`-Knoten (Bezüge dürfen auf Blätter zeigen, die erst `item_defaults` füllt), **nie** aus overlay-fähigen
numerischen Blättern berechnete Konstanten (analog 4.12 Nr. 5); deterministische Termine, Codes, Flags und
`bctx$legal()`-/`bctx$lib()`-Werte dürfen sie auswerten. Sie sind deterministisch und ziehen keine Zufallszahlen.
Herkunft `source_type = "type_default"`, `layer = 0`, `entry = "rule:<name>"` bzw. die Bibliotheks-id, aus der der
Wert stammt. Ableitungsregeln sind **keine** Registry-Regeln (Art `rule`, 5.3); ein Paket, das ihr Ergebnis braucht,
liest das abgeleitete Domänenblatt. Die Regelliste mit Name, Zielfeld und Ableitung legt Spec 01 fest (Teil A §1.4,
Teil B u. a. `rule:unit_group_defaults`, `rule:carrier_defaults`, `rule:approval_timing`, `rule:approval_probability`,
`rule:tax_credit_defaults`; Teil A `rule:measure_catalog` einschließlich des PV-Nullsatzes nach 7.10).

**Perspektiven-Profile (Schicht 2, R-76):** Ein Profil `inst/extdata/profiles/<perspective>.yaml` darf nur diese
Pfade setzen: `accounts.*` (alle Felder aus 4.3.10 inkl. `deficit_order` und Kopplung über `anchor`), `analysis.*`
(u. a. `kpis`, `thresholds`, `traffic_light`, `restrictions`, `mandatory_sensitivities`, `rv_path_basis`,
`lending_value_haircut`), `residual_value.method`, `residual_value.sale_cost_share`, `project.horizon_years`,
`project.report_mode`, `tax.module` und `scenario_sets` (z. B. `vorsichtig`, `foerderstopp`). Andere Pfade sind ein
Validierungsfehler der Bibliothek; das gilt auch für `by_project_type` im Profil. Profile setzen insbesondere keine
Felder von Sammlungselementen (`unit_groups.<g>.*`, `energy.carriers.<c>.*`); perspektivabhängige Element-Defaults
laufen über Ableitungsregeln (oben). Die Werte je Perspektive (Konzept A2, A3, A4, F18) legt Spec 01 fest.

Merge-Semantik (`R/utils-merge.R`, MUSS):

```r
deep_merge <- function(base, override, path = "") {
  if (!is_map(base) || !is_map(override)) return(override)   # Skalare, Vektoren, Sequenzen: ersetzen
  if (is_value_form(override, path)) return(override)         # Wertform auf der Override-Seite: ganz ersetzen
  if (isTRUE(override[[".replace"]])) { override[[".replace"]] <- NULL; return(override) }
  for (nm in names(override)) {
    if (is.null(override[[nm]])) base[[nm]] <- NULL            # explizites ~ (null) löscht
    else base[[nm]] <- deep_merge(base[[nm]], override[[nm]], path_join(path, nm))
  }
  base
}

is_value_form <- function(x, path = "") {                     # R/utils-merge.R (I)
  # 1. Ist path ein Parameterpfad (components.<id>.<p>, financing.<id>.<p>, Domänenfeld mit Schema), entscheidet die
  #    Schema-Art: Wertform nur bei Art value/amount/rate/share/number/schedule.
  # 2. Sonst (market, shared, unbekannt) strukturell: x ist eine Map, deren Namen vollständig in der Schlüsselmenge
  #    GENAU EINER Wertform liegen und deren Pflichtschlüssel enthalten:
  #      ref {ref*, scale, offset, floor, cap, anchor}    expr {expr*}
  #      series_year {series*, fill, before}              points {years*, values*, interpolate}
  #      schedule {schedule*, unit}                       growth {start*, growth*, base_date, real, index}
  #      quantity {value*, per*}                          dist {dist*, base, <Verteilungsparameter>}
  #      from {from*, use, ...} (Bibliotheksverweis, wird in Schicht 3 aufgelöst)
}
```

- Maps rekursiv, alles andere wird ersetzt; `~` löscht; `.replace: true` ersetzt eine Map vollständig.
- Wertknoten (4.5) gelten als Blätter: Ist die **Override-Seite** eine Wertform, ersetzt sie den Basisknoten als
  Ganzes. Eine Override-Map, die keine Wertform ist (z. B. `{fill: zero}` oder `{scale: 2}`), wird in eine
  Basis-Wertform gemischt. Ein Kreditbaustein mit dem Parameter `start` (8.2) ist keine Wachstumsform, weil weitere
  Schlüssel vorhanden sind bzw. die Schema-Art des Pfads entscheidet; `overrides: {financing: {bank: {start: 2028}}}`
  mischt also nur den Termin.
- Schicht 8 auf einen Pfad, der Ziel eines Overlay-Eintrags ist, macht diesen Pfad für den Lauf deterministisch
  (Overlay-Bindung entfällt, `vofi_inform`). Dasselbe gilt für `set`/`replace` einer Variante (Schicht 7) auf ein
  Overlay-Ziel, sofern die Variante den Overlay-Eintrag nicht selbst neu setzt. Varianten und Sets dürfen
  Overlay-Einträge hinzufügen, ändern und entfernen; `from:`-Verweise in ihren Operationen werden nach der Operation
  aufgelöst (4.11, R-87, R-96).

### 4.8 Herkunft (Provenienz)

`vofi_spec` trägt `attr(spec, "provenance")`, ein Data Frame mit einer Zeile je Blattpfad:

| Spalte | Typ | Inhalt |
|---|---|---|
| `path` | chr | Blattpfad |
| `layer` | int | 0–8 (Schicht, die den Wert zuletzt gesetzt hat) |
| `source_type` | chr | `type_default` (auch Ableitungsregeln), `global` (auch `item_defaults`), `profile`, `legal`, `library`, `user_library`, `scenario`, `overlay`, `variant`, `scenario_set`, `override`, `expander` |
| `file` | chr | Datei (relativ zur Bibliothekswurzel bzw. Szenariodatei) |
| `entry` | chr | Bibliotheks-id; bei Defaults-Dateien `defaults_meta$id`, `"<datei>#by_project_type.<code>"` bzw. `"global#item_defaults.<pfad>"`; bei Ableitungsregeln `"rule:<name>"` (R-85, R-86) |
| `location` | chr | `"Blatt!Zelle"` (Excel) bzw. `"Zeile 42"` (YAML, best effort) |
| `variant` | chr | Variante bzw. Szenario-Set |
| `valid_from`, `valid_to`, `as_of`, `accessed` | date | aus Bibliotheksmetadaten |
| `quality` | chr | `A`–`D`; je Blatt aus `quality_detail` des Eintrags (längster passender Unterpfad), sonst `quality` (R-88) |

`vofi_scenario` trägt die Herkunft der eingelesenen Blätter (Schicht 5) im selben Format.

### 4.9 Parameterbibliothek und `from:`

**Ablage:** ein Eintrag je Datei, `id` = Pfad relativ zur Bibliothekswurzel ohne `.yaml` (z. B.
`funding/kfw_261_eh55`). Wurzeln: `system.file("extdata/library", package = "vofi")`, dann `vofi_library_paths()`
(später gewinnt; Überschattung = Warnung). Listenform (`- id: …`) wird nur in Nutzerbibliotheken akzeptiert und in
Einzeleinträge zerlegt (R-13).

```yaml
id: funding/kfw_261_eh55          # MUSS dem Pfad entsprechen
block: funding                    # Zielblock: funding | financing | market | processes | components | legal | costs | valuation
topic: null                       # nur legal/*: Thema für die automatische Auswahl, z. B. mietrecht
schema_version: 1
label: "BEG WG Kredit 261 – Effizienzhaus 55"
source: {document: "...", url: "...", publisher: KfW}   # Pflicht
as_of: 2026-10-25                 # Pflicht: Stand des Eintrags (D10)
accessed: 2026-10-25              # optional: Abrufdatum der Quelle
valid_from: 2026-07-21            # Pflicht (Antragsdatum bei Förderung)
valid_to: null                    # Pflicht (null = offen)
quality: B                        # Pflicht: A amtlich/Primärquelle geprüft, B Verband/Institut, C Sekundärquelle, D Ableitung/Schätzung
reform: null                      # Code einer anhängigen Reform; Eintrag nur aktiv, wenn in project.pending_reforms
release: null                     # Pflicht bei legal/* mit quality C: {status: released | pending, by: "...", date: ...}
uncertainty: null                 # optional: Vorschlag für Overlay-Einträge
from: null                        # optionale Kette auf einen anderen Eintrag
description: null                 # optional (R-88): Erläuterung (de)
references: []                    # optional: weitere Quellen, je Eintrag wie source
quality_detail: {}                # optional: Unterpfad von values -> A–D (Herkunft je Blatt: längster passender Unterpfad)
legal_state: null                 # Pflicht für legal/* und funding/*: {as_of: <Fassung>, status: <code>, reference: "..."}
notes: null                       # optional: Hinweise, Prüfpunkte
fallback: null                    # optional: numerische Ersatzwerte für Tokens base (11.7); wird nie gemischt
values:                           # Nutzlast, wird unter die lokale Angabe gemischt
  ...
```

Andere Wurzelschlüssel eines Eintrags sind ein Validierungsfehler (R-88). Die Codes von `legal_state.status` legt
Spec 01 Teil C §3.1 fest.

**Auflösung von `from:`** (Schicht 3): An der Fundstelle `{from: <id>, use: <unterpfad>, …lokal}` wird
`payload <- entry$values` (bzw. `path_get(entry$values, use)`) bestimmt, Ketten über `entry$from` rekursiv aufgelöst
(Zyklus → Fehler) und `deep_merge(payload, lokal_ohne_from_use)` eingesetzt (lokal gewinnt). Ist die Nutzlast (nach
`use`) **keine Map** (Skalar, Sequenz) **oder eine Wertform** (z. B. `{years, values}`), ersetzt sie den Knoten;
weitere lokale Schlüssel neben `from` und `use` sind dann ein Validierungsfehler (R-87). Die Herkunft erhält `entry`,
`valid_from`, `valid_to`, `as_of`, `accessed`, `quality` (bzw. die Stufe aus `quality_detail`).

- **Nutzlasten von `processes/*`** dürfen eine Map mehrerer Overlay-Vorlagen sein (Auswahl mit `use:`) bzw. eine
  Sequenz von Korrelationspaaren (ersetzt die lokale Liste nach der Regel oben) (R-87, 4.3.15). R-13 (ein Eintrag je
  Datei) bleibt unberührt.
- **Verweise außerhalb von Schicht 3:** `from:`-Verweise in Operationen von Varianten und Szenario-Sets (`add`, `set`,
  `replace`, `overrides`) und in `item_defaults` werden nach der jeweiligen Operation mit denselben Regeln aufgelöst
  (4.7, 4.11; Herkunft Schicht 7 bzw. 1 mit `entry`).
- Jeder `from`/`use`-Verweis in `global.yaml` und den Profilen MUSS auflösen; `test-profiles.R` (WS-A) prüft das
  (R-104).

**Gültigkeit (D10):** Liegt das maßgebliche Datum außerhalb von [`valid_from`, `valid_to`), folgt
`vofi_warning_library_outdated`. Maßgeblich ist für `funding` das `application_date` des Instruments, sonst
`project.legal_state`. Ist `as_of` älter als 6 Monate vor `legal_state` (Prozess- und Kalibrierungseinträge: 12
Monate), folgt ebenfalls diese Warnung. Jedes Ergebnis speichert den Bibliotheksstand (`meta$library`, 13.1) und
die Versionskennung `JJJJ.MM.n` der Paketbibliothek aus `inst/extdata/library/VERSION` (`meta$library_version`,
Konzept 5.4, R-80).

### 4.10 Rechtsstand und Reformschalter

- `legal/*`-Einträge mit `topic` werden **automatisch** gewählt: je Thema der Eintrag mit größtem `valid_from ≤
  legal_state < valid_to`. Einträge mit `reform: <code>` sind nur wählbar, wenn `<code>` in `pending_reforms` steht,
  und haben dann Vorrang vor dem Eintrag ohne Reform mit überlappender Gültigkeit.
- Rechtsregeln (Registry-Art `rule`, 5.3) werden nach demselben Muster über `ctx$rule(name)` gewählt.
- Beschlossenes und verkündetes Recht ist Standard, auch wenn es erst künftig wirkt (Konzept F5).
- **Freigaberegel (Konzept 6.5, R-80):** Für die automatische Wahl zählen `legal/*`-Einträge der Qualität A und B
  sowie der Qualität C nur mit `release.status: released`. Nicht freigegebene C-Einträge sind nur mit dem Sammelcode
  `unreleased` in `pending_reforms` wählbar (Prüfrechnungen, Ergebnisvermerk). Einträge der Qualität D (eigene
  Ableitung) tragen immer einen Schaltercode in `reform` und sind nie automatisch aktiv. Gibt es für ein Thema keinen
  wählbaren Eintrag, ist es **inaktiv**: `ctx$legal(topic)` und `bctx$legal(topic)` liefern `NULL`, die Typen wenden
  die zugehörige Regel nicht an und vermerken das in `meta$notes` (z. B. § 559f ohne Freigabe: keine Halbierung).
- **Freigabe je Teil (R-88):** Wendet eine Regel einen Teil einer Nutzlast **automatisch** an, dessen Qualität
  (`quality_detail`) unter der Eintragsstufe liegt (C oder D in einem A/B-Eintrag), MUSS dieser Teil ein eigener
  `legal/*`-Eintrag mit eigenem `topic` sein (z. B. `mietrecht_559f`), damit die Freigaberegel greift. Teile, die nur
  auf ausdrückliche Nutzerangabe wirken (Schalter wie § 5b-Neubau, § 5d-Härtefall, Havarie-Übergang § 5a), sind
  ausgenommen.
- **Gültigkeitsende und Fortgeltung (R-88):** `valid_to` wird nur gesetzt, wenn die Rechtsquelle tatsächlich endet
  (Außerkrafttreten, Programmende, Befristung). Gelten Werte bis zu einer Neufassung fort (z. B. Emissionsfaktoren
  GEG Anlage 9), trägt der Eintrag `valid_to: null` und in `notes` den Prüfpunkt der
  erwarteten Neufassung; die Veraltung meldet dann `as_of` (4.9). Ein Thema mit abgelaufenem Eintrag ist inaktiv.
- Reform- und Schaltercodes stehen in `enums.yaml` (`reform: {codes: [mietrecht_ii, stufe_2045, unreleased]}`);
  `stufe_2045` ist der Szenario-Schalter „100 % klimaneutraler Brennstoff ab 2045“ (eigene Ableitung, Standard aus,
  Pflichtsensitivität; Konzept F5, A7, R-82).

### 4.11 Varianten und Szenario-Sets

```yaml
variants:
  <id>:
    label: "<deutsch>"             # Pflicht
    description: "<deutsch>"
    extends: base                  # Default base; Kette erlaubt, Zyklus = Fehler
    set:     {<pfad>: <wert>}      # Pfad MUSS in der Elternvariante existieren; Maps werden gemischt
    replace: {<pfad>: <wert>}      # Pfad MUSS existieren; Teilbaum wird ersetzt
    add:     {<sammlung>.<id>: {...}}   # id DARF NICHT existieren
    remove:  [<pfad>, ...]         # Pfad MUSS existieren
    overrides: {...}               # Baumform = Kurzschrift für set (gleiche Existenzprüfung); ~ = remove
```

- Ausführungsreihenfolge je Variante: Eltern auflösen → `remove` → `replace` → `set` → `overrides` → `add`.
- **Bibliotheksverweise in Operationen (R-87):** `from:`-Verweise in `add`, `set`, `replace` und `overrides` von
  Varianten und Szenario-Sets werden nach der Operation mit den Regeln von Schicht 3 aufgelöst (4.9; Herkunft
  Schicht 7, `entry`). So kann eine investive Variante ein Förderinstrument `{from: funding/…}` hinzufügen.
- **Overlay in Varianten (R-96):** `stochastic.parameters.<key>`, `stochastic.processes.<key>` und
  `stochastic.correlations.*` dürfen in Varianten (und Sets) hinzugefügt, geändert und entfernt werden. Ein
  Overlay-Ziel, das in einer Variante fehlt, ist dort ein Validierungsfehler (R-16); CRN über Varianten laufen über den
  Vereinigungsplan (11.10).
- `base` ist implizit vorhanden und hat keine Operationen. `vofi_variants(scenario)` listet `base` und alle Varianten.
- **Szenario-Sets** (`scenario_sets`) haben dieselbe Syntax ohne `extends`, dürfen aber nur Pfade unter `market`,
  `funding`, `accounts`, `residual_value`, `stochastic`, `tax` und `project.pending_reforms` ändern. Sie werden nach
  der Variante angewendet (Schicht 7) und lassen sich in `vofi_compare(…, scenario_sets = …)` mit jeder Variante
  kreuzen. Ein statisches Set ist ein eigener **Planungsfall**: Sein Modell hat einen eigenen Basisfall-Vorlauf
  (9.1 Stufe 6a), `auto`-Beträge werden für das Set neu bestimmt. In Set-Pfaden darf genau ein Segment `*` stehen
  (alle ids der Sammlung, z. B. `funding.*.approved`); die Existenzprüfung gilt je Treffer, kein Treffer ergibt einen
  Hinweis. `inst/extdata/defaults/global.yaml` liefert die Sets `foerderstopp` (`set: {funding.*.approved: 0}`,
  Konzept B12) und `vorsichtig` (R-74).
- **Szenario-Sets setzen keine `shared`-Blätter** (R-109): Wird ein unsicherer oder szenarioabhängiger Wert in mehreren
  Domänenfeldern gebraucht, legt das Szenario einen eigenen `market`-Pfad an, auf den die Domänenfelder per `ref`
  zeigen; das Set ändert diesen Pfad.
- **Generiertes Set „vorsichtig“ (R-74, Konzept 1.4, B5):** `vorsichtig: {label: …, generate: {method: cautious,
  n_drivers: 5, probs: [0.1, 0.9], kpi: auto, params: auto, exclude: []}}`. `params` (chr[] oder `auto`) nennt die
  Kandidaten (`auto`: alle statischen Overlay-Schlüssel der Rolle `value`, alle unsicheren Prozessparameter, jeder
  Prozess mit `quantile_path()` als Quantilpfad und die Entscheidungsschlüssel, Algorithmus Spec 01 Teil C §4.3),
  `exclude` (chr[]) schließt Kandidaten aus (R-95). WS-G erzeugt es je Variante aus einem Tornado (11.11) der
  Primärkennzahl (12.3a; bei `delta_vs_reference` gemeinsam auf Variante und Referenz angewendet): Die `n_drivers`
  Parameter mit dem größten Ausschlag stehen gleichzeitig auf ihrem für die Kennzahl ungünstigeren Wert (P10 bzw.
  P90 der Overlay-Verteilung bzw. Tornado-Grenze). Ziele dürfen beliebige Designziele sein (11.11, nicht auf die Pfade
  statischer Sets beschränkt). Das Set ist ein **Risikofall** auf dem Basismodell: Es wird als Design-Lauf mit einer
  Zeile gerechnet (Basisfallgrößen wie `auto`-Beträge bleiben fest, R-69); Ergebnis wie ein deterministischer Lauf mit
  `meta$scenario_set = "vorsichtig"`, `meta$mode = "design"` und der Liste der gesetzten Werte in `meta$notes`. Ohne
  Overlay-Einträge gibt es keine Treiber: Hinweis, und das Set gilt für die Ampel als nicht gerechnet (12.9).
- **Ausweichvarianten** (`funding.<id>.fallback_variant`, 9.11) sind gewöhnliche Varianten; sie werden bei Bedarf
  automatisch mitgerechnet, auch wenn sie nicht in `variants` von `vofi_compare()` stehen.
- Sensitivitäten und Break-even-Suchen verwenden **keine** Varianten, sondern Design-Läufe (11.11) bzw. Schicht 8.

### 4.12 Expander (Domäne → Komponenten)

```r
typedef_expander_<name> <- function() vofi_type(
  name = "<name>", kind = "expander", block = "<oberster Block>", order = <int>,
  expand = function(block, scenario, bctx) { ... })      # -> list(components, financing, assets, measures, notes)
```

| Expander | `block` | `order` | erzeugt (Typ → id; m = Maßnahme, e = Bestandsbauteil, g = Wohnungsgruppe, s = Energiezustand, c = Träger, f = Förderinstrument) |
|---|---|---|---|
| `measures` | `measures` | 10 | `capex` → `m_<m>_capex`; `replacement` → `m_<m>_repl` und `m_<e>_repl` (Bestandsbauteile `building.elements`); `land` → `m_<m>_purchase`; `acquisition_cost` → `m_<m>_acq`; `maintenance` → `m_maintenance` (Gebäude) und `m_<m>_maint` (je Maßnahme); Assets; Maßnahmenregister |
| `unit_groups` | `unit_groups` | 20 | `rent_path` → `u_<g>_rent` (eine Komponente je vermieteter Gruppe mit Miete, Mietausfall und Umlage je Maßnahme, R-63); `operating_cost` → `u_<g>_opex`; `property_tax` → `u_<g>_property_tax`; `imputed_rent` → `u_<g>_imputed_rent` |
| `energy` | `energy` | 30 | `energy_cost` → `e_<s>_<c>_cost` und `co2_cost` → `e_<s>_<c>_co2` (je Zustand × Träger, 7.10); `pv` → `e_pv`; `tenant_costs` → `e_tenant` |
| `funding` | `funding` | 40 | `grant` → `f_<f>_grant`; `tax_credit_35c` → `f_<f>_35c`; Förderkredite → `financing.f_<f>_loan`; Zinsverbilligung als `recurring`-Komponente → `f_<f>_subsidy` |
| `household` | `household` | 50 | `equity`-Bausteine → `financing.h_equity`, `financing.h_contrib`; keine Belastungs-Hilfszeilen (die Haushaltssicht entsteht in WS-D2/WS-H aus Tags, 12.3) |
| `residual` | `residual_value` | 60 | `residual_value` → `rv_value` inkl. Merkzeilen `market_value` (V_t) und `residual_path` (RW_t je Periode, `rv_basis` `method` und `measures`, R-72) |

Die Tabelle ist die vollständige id-Liste der Expander in v1 (R-90); ein Expander, der eine weitere Komponente erzeugt,
braucht einen Eintrag hier. Höchstlängen der Nutzer-ids nach 4.4 Nr. 2.

Vertrag (MUSS):

1. Expander laufen in `order`-Reihenfolge in `vofi_resolve()` nach Schicht 8, den Ableitungsregeln und
   `item_defaults` (4.7) auf der aufgelösten Variante. Sie ändern nichts an Domänenblöcken und schreiben nur in
   `components`, `financing`, die Register und die Herkunft (`source_type = "expander"`). Fehlende Domänenwerte, die
   ein Expander braucht, setzt eine Ableitungsregel (WS-A), nicht der Expander (R-86).
2. Erzeugte Komponenten **referenzieren Domänenwerte über `{ref: <domänenpfad>}`** statt Zahlen zu kopieren. Nur so
   wirken Overlay-Ziele auf Domänenpfaden (z. B. `measures.huelle.cost_eur`) und Varianten-Overrides. Produkte
   mehrerer Pfade (z. B. Förderbetrag × `funding.<id>.approved`) entstehen als `expr`-Knoten.
3. Kollidiert eine erzeugte id mit einer vorhandenen, ist das ein Validierungsfehler.
4. `bctx` (Build-Kontext, 6.4) liefert Raster, Rechtsstand, Bibliothek, Regeln und Meldungsfunktionen, aber keine
   Ziehungen.
5. `bctx$rule()` und `bctx$legal()` dürfen **nur auf deterministische Eingaben** angewendet werden (Termine, Codes,
   Flags, Parameter mit `deterministic_only = TRUE`), z. B. Auswahl eines Programms nach Antragsdatum. Wertabhängige
   Regeln (Kappungen, Förderhöchstbeträge, Umlagehöhe) laufen in den Zahlungskomponenten über `ctx$rule()`. Ein
   Expander darf keinen aus numerischen Domänenblättern abgeleiteten Wert als Konstante in eine Komponente schreiben
   (er wäre für Overlay, Tornado und Break-even eingefroren). Prüfung im Expandertest (WS-E2): Jedes numerische
   Domänenblatt, das der Expander liest, wird über Schicht 8 geändert; die erzeugten Komponentenknoten MÜSSEN dabei
   unverändert bleiben (Bezug statt Kopie, Nr. 2). **Ausgenommen** sind (R-92): (a) Blätter bzw. Parameter mit
   `deterministic_only = TRUE` oder der Arten `integer`, `enum`, `logical`, `date`, `timing`, `ids` sowie
   Kreditbeträge und `draw_schedule` (Basisfallwerte, R-69); (b) Elemente von Sequenzen (4.4 Nr. 3), z. B.
   Staffeltabellen, Degressionsstufen, Einkommensstaffeln; (c) Werte aus `bctx$legal()` und `bctx$lib()`, die nicht über
   `from:` in einen Domänenblock gemischt sind. Der Expandertest ändert nur Blätter, die Overlay- oder Designziel sein
   dürfen. Für deterministische Ableitungen nach (a) (z. B. Gewichte von `draw_schedule`, Anzeige-Tag `measure_id`)
   steht `bctx$value_base()` bereit (6.4).
6. **Mietrecht (R-63):** §§ 558 und 559/559e hängen wechselseitig voneinander ab (Kappungsbasis des § 558 enthält die
   § 559-Erhöhungen; die Kappe des § 559 Abs. 3a hängt von der aktuellen Miete vor der Maßnahme und den Umlagen der
   letzten 6 Jahre ab; Memo 02 §2.1–2.3). Deshalb gibt es **keine** eigene Umlagekomponente: Der Expander erzeugt je
   vermieteter Wohnungsgruppe genau eine `rent_path`-Komponente (`u_<g>_rent`), die monatlich rechnet und die Zeilen `rent`, `rent_loss` und
   `levy_<measure_id>` (Kategorie `modernization_levy`, `measure_id` gesetzt) schreibt. Die betroffenen Maßnahmen und
   Förderkomponenten (Abzug nach § 559a) stehen in ihren Parametern bzw. in `after`.
7. **Aktivierungsfaktor (R-71):** Für jede Maßnahme m bildet der Maßnahmen-Expander a_m = `measures.<m>.active` ×
   Π_f `funding.<f>.approved` über alle Instrumente f mit `on_reject: drop_measures`, die m fördern, als `expr`-Knoten.
   Alle Expander MÜSSEN a_m auf sämtliche aus m erzeugten Zahlungen und Wirkungen anwenden (Kosten, Ersatz,
   Energiezustand „nachher“, Instandhaltung, Leerstand, Umlage, Förderung, Restwertanteil), maskiert und vektorisiert
   (2.8). Bei a_m = 0 verhält sich der Lauf so, als fehlte m. **Förderkredite (R-99):** `financing.f_<f>_loan.approved`
   = `{expr: "funding.<f>.approved * pmax(<a_m1>, <a_m2>, …)"}` über die von f geförderten Maßnahmen. Fällt nur ein Teil
   der Maßnahmen weg, bleibt der Kreditbetrag (fest nach R-69); Überschuss bzw. Lücke laufen über den Ausgleich. Ganz
   entfällt der Kredit nur, wenn alle geförderten Maßnahmen entfallen (bzw. die Zusage fehlt).
8. **Restwertpfad (R-72):** Die Komponente `residual_value` schreibt neben den Zeilen in T die Merkzeilen
   `market_value` (V_t = Wert nach der gewählten Methode zum Ende von t, vor Verkaufskosten; Grundlage für LTV und
   Beleihungsauslauf) und `residual_path` (RW_t = Liquidationswert bei Verkauf in t nach Verkaufskosten) für t = 0…T,
   je einmal mit `rv_basis = "method"` (gewählte Methode) und `rv_basis = "measures"` (Komponenten-Zeitwert aller
   Maßnahmen und Ersatzinvestitionen des Registers, Konzept 2.5 Haushaltsmodus). MUSS: RW_T(method) = Summe der Zeilen
   `residual_value` und `sale_cost` in T; bei Methode `zero` sind V_t und RW_t(method) null. **Komponenten-Zeitwert
   (R-108):** ohne Indexierung ist er der nominale Buchwert (nominaler Betrag der letzten Investition × max(0, 1 −
   Alter/Nutzungsdauer)); mit Indexierung wird dieser Betrag mit dem Baupreisindex vom Investitionstermin bis t
   fortgeschrieben (Schalter und Default Spec 01 Teil A §6.3.7).

### 4.13 Objektstrukturen

```r
vofi_scenario <- structure(list(
  schema_version = 1L, meta = list(), project = list(), grid = list(), building = list(),
  household = list(), unit_groups = list(), measures = list(), energy = list(), funding = list(),
  components = list(), financing = list(), accounts = list(), market = list(), residual_value = list(),
  tax = list(), analysis = list(), stochastic = list(), shared = list(), variants = list(),
  scenario_sets = list()
), class = "vofi_scenario",
   source = list(path = chr, format = "yaml" | "excel" | "list", read_time = POSIXct, sha = chr,
                 stochastic_path = chr | NULL),
   provenance = data.frame(...))          # 4.8, nur Schicht 5

vofi_spec <- structure(list(
  meta, project, grid, building, household, unit_groups, measures, energy, funding,   # aufgelöste Domäne
  components = list(<id> = list(id, type, label, description, after, origin, asset_id, measure_id, funding_id,
                                program,                     # reservierte Metafelder (4.3.8)
                                <param> = <knoten>, ...)),   # Typparameter FLACH, Defaults (Schicht 0) eingesetzt;
                                                             # nicht-numerische Parameter als normalisierte Werte
                                                             # (Date, chr, lgl, int), map-Parameter als Liste
  financing  = list(<id> = list(<metafelder>, <param> = <knoten>, ...)),
  accounts, market, residual_value, tax, analysis,
  stochastic,                                         # normalisiertes Overlay inkl. verschobener Kurzformen
  registers  = list(assets = list(<vofi_asset>), measures = list(<vofi_measure>)),
  legal      = list(<topic> = list(entry = chr, values = list())),
  variant    = chr, scenario_set = chr | NULL, library = data.frame(entry, as_of, valid_from, valid_to, quality)
), class = "vofi_spec", provenance = data.frame(...))
# Pfad-Identität (MUSS): path_get(spec, "components.<id>.<param>") liefert den Knoten des Parameters; derselbe Pfad
# ist Overlay-Ziel (11.2), Variantenpfad (4.11), Herkunftspfad (4.8) und Argument von ctx$param() (6.3).

vofi_model <- structure(list(
  spec, grid,                                         # vofi_grid
  nodes        = list(<id> = list(spec, def)),        # flow-Komponenten in Topo-Reihenfolge
  instruments  = list(<id> = list(spec, def)),        # Reihenfolge = financing-Reihenfolge
  equity       = character(),                         # ids der equity-Bausteine (Teil von nodes)
  accounts     = list(...),                           # normalisierte Kontoparameter (8.8)
  surplus_chain = list(<action_def>), deficit_chain = list(<action_def>),
  sampler      = <smp_plan>,                          # 11.2
  tax          = <tax_module>, tax_params = list(),
  kpis         = list(<kpi_def>),
  auto_id      = chr | NULL,                          # Instrument mit amount: auto
  topup_id     = chr | NULL,                          # Instrument mit amount: topup (8.7)
  base         = list(flows = list(<id> = <vofi_flows>, n = 1),   # Basisfall-Vorlauf (9.1 Stufe 6a, R-69, R-70)
                      auto  = list(commitment = num(1), draws = num(T + 1)) | NULL,
                      need0 = num),                  # Basisfall-Bedarf im Fenster W mit festem auto-Plan (8.7)
  decision     = NULL | list(funding_id = chr, key = chr, p = num, fallback_variant = chr,
                             fallback = <vofi_model>),               # Entscheidungsknoten (9.11, R-71)
  hash         = chr,                                 # stable_hash(spec)
  contract_version = VOFI_CONTRACT_VERSION
), class = "vofi_model")
```

### 4.14 Excel-Abbildung (Grundsätze für WS-A2)

1. Excel ist eine **verlustfreie Darstellung derselben kanonischen Liste** (Round-Trip-Test YAML → XLSX → Liste
   identisch). Blätter und Spalten folgen Memo 05 §4.10. Zeile 1 enthält die Maschinenschlüssel (Pfade), Zeile 2 die
   deutschen Überschriften, ab Zeile 3 Daten.
2. Wertformen außer Konstanten werden in der Spalte `form` + `value` kodiert (`ref`, `series_year`, `expr`, …);
   Zeitreihen stehen im Blatt „Zeitreihen“ (eine Spalte je Jahr).
3. Die Vorlage wird aus Registry, Vokabularen und Label-Katalog **generiert** (`vofi_excel_template()`); ein Test
   vergleicht die ausgelieferte Vorlage mit einer frisch generierten.
4. Fehlermeldungen nennen Blatt und Zelle (`location` in 4.8). Lesen ausschließlich mit `openxlsx::read.xlsx()` (R-26).

---

## 5. Registry

### 5.1 Arten (kinds)

| Art | Zweck | Discovery-Name | Pflichtfunktionen (exakte Formals) |
|---|---|---|---|
| `flow` | originäre Zahlungen, Zuschüsse, geplante EK-Ströme, Merkzeilen | `typedef_<name>` | `build(spec, ctx)` |
| `instrument` | Kredite als Zustandsautomaten | `typedef_<name>` | `init(spec, ctx)`, `step(state, t, ctx)`; optional gemeinsam `prepay(state, amount, t, ctx)` und `capacity(state, t, ctx)` |
| `account_action` | Ausgleichsschritte Ü1–Ü4, D1–D4 | `typedef_action_<name>` | `apply(acc, amount, t, ctx, inst)` |
| `expander` | Domänenblöcke → Komponenten | `typedef_expander_<name>` | `expand(block, scenario, bctx)` |
| `distribution` | Verteilungen statischer Größen | `typedef_dist_<name>` | `quantile(u, par)`, `point(par, which)`, `moments(par)`, `validate(par)` |
| `process` | Zeitreihenprozesse (Kalenderjahre) | `typedef_process_<name>` | `simulate(par, z, u, years, linked)`, `expected(par, years)`, `n_shocks(par)`, `n_uniforms(par)`, `validate(par)` |
| `kpi` | Kennzahlen | `typedef_kpi_<name>` | `compute(core, ctx)` |
| `tax` | Steuermodule | `typedef_tax_<name>` | `constructor(params, spec)` (+ S3-Methoden `tax_init/tax_step/tax_finalize.<klasse>`) |
| `rule` | versionierte Rechtsregeln | `typedef_rule_<name>_<yyyymmdd>` | `fun` (Formals je Regelname über alle Versionen identisch, dokumentiert; vektorisiert; 5.3) |

Namen sind je Art eindeutig; `flow`- und `instrument`-Namen sind zusätzlich **gemeinsam** eindeutig, weil `type:` in
`financing` beide Arten zulässt.

### 5.2 Typdefinition `vofi_type()`

```r
vofi_type(name, kind, params = list(), ..., example = NULL, label = NULL, version = 1L)
# -> Objekt der Klasse "vofi_typedef":
list(
  name         = chr,          # ^[a-z][a-z0-9_]*$ ; bei rule: "<rulename>@<YYYY-MM-DD>"
  kind         = chr,          # 5.1
  version      = int,
  label        = chr | NULL,   # nur Nutzertypen (Literal erlaubt); eingebaute: Katalog types.<kind>.<name>.label
  labels       = list() | NULL,# Nutzertypen: list(description, params = list(<p> = chr), rows = list(<r> = chr))
  params       = list(<p> = <vofi_param>),   # Namen nicht aus den reservierten Metafeldern (4.3.8)
  perspectives = chr | NULL,   # NULL = alle
  rows         = chr,          # flow/instrument/account_action: lokale Zeilennamen bzw. Ledger-Schlüssel;
                               # flow: auch Muster "<präfix>_*" (Platzhalter = id oder festes Suffix, s. u.)
  example      = list() | NULL,# Pflicht für flow, instrument, distribution, process, tax
  validate     = function(spec, scenario) | NULL,   # nur flow/instrument: -> list(<vofi_finding>)
  grid_invariant = lgl,        # flow: Jahresbeträge unabhängig vom Raster (Vertragstest F10), Default FALSE
  domain_reads = chr | NULL,   # flow/instrument, optional (R-93): Domänenblöcke, die der Typ über ctx$value(),
                               # ctx$value_base() bzw. ctx$spec liest; Teilmenge von measures, funding, financing,
                               # energy, unit_groups, building, household, market (C3 prüft die Codes; 6.1 Nr. 3)
  ...                          # artspezifische Felder und Funktionen (5.3)
)
```

**Zeilenmuster (flow):** Ein Eintrag `"<präfix>_*"` in `rows` deklariert eine Familie lokaler Zeilennamen
`<präfix>_<x>`; `<x>` ist eine id (Maßnahme, Träger; z. B. `levy_*` → `levy_huelle`) oder eines der festen
USt-Suffixe `vat19`, `vat7`, `vat0` (7.10). Das Label der Familie steht unter `rows.<präfix>_*` und enthält den
Platzhalter `{id}` (Anzeige: Label bzw. id des Objekts). F3 prüft jeden lokalen Namen gegen die Einträge und Muster.

**`example`:** rohe Eingabeform wie in YAML (Liste mit `type` und Parametern, Wertformen unnormalisiert). Das Prüfkit
normalisiert sie selbst (`node_normalize()`), setzt Defaults (Schicht 0) ein und baut daraus die Testkomponente.

### 5.3 Artspezifische Felder und Funktionssignaturen (MUSS)

| Art | Feld / Funktion | Signatur und Rückgabe |
|---|---|---|
| `flow` | `build` | `build(spec, ctx)` → `vofi_flows` (7.2). `spec` = Komponente aus `vofi_spec$components` bzw. `$financing` (für `equity`) |
| `instrument` | `init` | `init(spec, ctx)` → Zustand: Liste (Klasse `vofi_inst_state`) aus n-Vektoren und deterministischen Skalaren (8.3) |
| | `step` | `step(state, t, ctx)` → `list(state, flows = list(draw, repay, repay_balloon, prepay, interest, fees), memo = list(repayment_grant, disagio), stocks = list(balance))`; alle Elemente n-Vektoren; Vorzeichen 8.4 |
| | `prepay` | `prepay(state, amount, t, ctx)` → `list(state, used, flows = list(prepay = -used))`; `0 <= used <= amount` |
| | `capacity` | `capacity(state, t, ctx)` → `list(balance, rate_pa, cap)` (n-Vektoren; `cap` = zulässige Sondertilgung) |
| `account_action` | `role` | `"surplus"` oder `"deficit"` |
| | `rank` | `"U1"`…`"U4"`, `"D1"`…`"D4"` (Anzeige, Validierung der Reihenfolge) |
| | `unlimited` | `TRUE` nur für `dep_invest`, `equity_call`, `penalty_rate`, `stop` |
| | `rows` | Ledger-Schlüssel, die die Aktion schreibt (z. B. `c("od_repay", "odp_repay")`; Kredite: Muster `"loan_*_prepay"`) |
| | `apply` | `apply(acc, amount, t, ctx, inst)` → `list(acc, used, flows = list(<ledger_key> = n-Vektor), flags = list(<flag> = logical n), inst = NULL \| <aktualisierte Instrumentliste>)` (8.9) |
| `expander` | `block`, `order`, `expand` | 4.12 |
| `distribution` | `quantile` | `quantile(u, par)` → numeric, gleiche Länge wie `u`, **monoton nicht fallend** in `u` (Voraussetzung für Iman-Conover und CRN); `bernoulli`: Q(u) = 1{u > 1 − p}; `empirical`: `point(par, "mode")` := Median (R-93) |
| | `point` | `point(par, which = c("mode", "median", "mean"))` → numeric(1) |
| | `moments` | `moments(par)` → `list(mean = num, var = num)` (`NA` erlaubt, wenn nicht endlich) |
| | `validate` | `validate(par)` → character (deutsche Meldungstexte über `msg()`), leer = gültig |
| `process` | `output` | `"level"` (Zinsen, Preise) oder `"rate"` (Wachstumsraten, Inflation) |
| | `linked` | Namen von Parametern, die auf andere Prozesse verweisen (z. B. `"base"` bei `linked_ar1`) |
| | `simulate` | `simulate(par, z, u, years, linked)` → n × length(years); `par`: Liste, Elemente Skalar oder n-Vektor (unsichere Prozessparameter); `z`: n × (length(years) − 1) Standardnormal-Schocks oder `NULL`; `u`: n × `n_uniforms` oder `NULL`; `linked`: benannte Liste n × length(years); Attribut `"scenario"` (integer n) optional |
| | `expected` | `expected(par, years)` → numeric(length(years)) bei Punktparametern |
| | `n_shocks`, `n_uniforms` | `n_shocks(par)` → 0 oder 1; `n_uniforms(par)` → integer ≥ 0; beide hängen **nur von der Struktur** ab (z. B. „`noise` vorhanden“), nie von Parameterwerten, damit Stromzuordnung und Plan-Hash von Variantenparametern unabhängig sind (R-93) |
| | `quantile_path` (optional) | `quantile_path(par, years, p)` → numeric(length(years)): Randquantil der Ausgabe je Jahr zum Niveau p ∈ (0, 1) bei Punktparametern; geschlossen nach Spec 01 Teil C §4.3 für `ar1`, `linked_ar1`, `vasicek` (mit `floor`), `mr_trend`, `gbm`, `scenario_mix`, `iid`; `fixed_path` hat keine. Prozesse ohne `quantile_path` sind keine Kandidaten des Sets „vorsichtig“ (R-95) |
| `kpi` | `compute` | `compute(core, ctx)` → `vofi_kpi_value` (12.1) |
| | `unit`, `shape`, `rv_variant`, `higher_is_better`, `mc_default`, `requires` | `unit` ∈ units.yaml; `shape` `"scalar"`/`"series"`; `rv_variant` lgl; `higher_is_better` lgl oder `NA`; `mc_default` lgl; `requires` ⊆ `c("opportunity", "market_value", "household_income", "living_area", "tenant_data")` |
| `tax` | `constructor` | `constructor(params, spec)` → Modulobjekt (10.2) |
| | `perspectives`, `blocked_regimes` | erlaubte Perspektiven bzw. gesperrte Steuerregime |
| | `uses_inputs` | lgl, Default `TRUE`; `FALSE` (z. B. `tax_none`): die Engine bildet keine `tax_inputs` (10.4) |
| `rule` | `rule_name`, `fun`, `valid_from`, `valid_to`, `reform`, `source`, `returns` | `valid_from` Date; `valid_to` Date oder `NULL`; `reform` chr oder `NULL`; `returns` ∈ `"sim"` (n-Vektor), `"path"` (n × (T+1)), `"params"` (benannte Liste deterministischer Rechtsparameter), `"value"` (deterministischer Wert beliebiger Form, z. B. `logical` oder ein Code; R-93) |

Die Registrierung prüft `identical(names(formals(f)), <soll>)` für jede Pflichtfunktion.

**Regelkonvention (MUSS):** Alle Versionen eines Regelnamens haben identische Formals (geprüft bei der
Registrierung); Argumente sind benannt und vektorisiert (n-Vektoren oder n × (T+1), Skalare werden recycelt), die
Rückgabeform steht in `returns`. Regeln ziehen keine Zufallszahlen und lesen weder `ctx` noch globale Zustände; das
gilt auch für Default-Werte von Formals (kein `legal = ctx$legal(…)`): Der aufrufende Typ übergibt Rechtsparameter als
Argument (Nutzlast von `ctx$legal()` bzw. Ergebnis einer Abbildungsregel, konventionell als letztes Formal `P`).
Eine Regel gehört dem Paket, dessen Typen sie aufrufen (2.4: Mietrecht, CO2KostAufG, Grunderwerbsteuer → WS-E; Förderung →
WS-E2); ruft ein anderes Paket eine Regel auf, MUSS ihr Name mit Formals und Rückgabeform vor dessen Welle in Spec 01
§ „Regelkatalog“ stehen. Wird ein Ergebnis schon in `vofi_resolve()` oder von Paketen früherer Wellen gebraucht
(z. B. Zusagezeitpunkt, Zusagewahrscheinlichkeit), ist es keine Registry-Regel, sondern eine Ableitungsregel von WS-A
(4.7, R-86), deren Ergebnis als Domänenblatt gelesen wird.

### 5.4 Parameter-DSL `vofi_param()`

```r
vofi_param(kind, ..., default = NULL, required = FALSE, min = NULL, max = NULL, unit = NULL,
           stochastic = NULL, values = NULL, allow_auto = FALSE, shapes = NULL,
           deterministic_only = FALSE, fields = NULL)
# -> Klasse "vofi_param": list(kind, default, required, min, max, unit, stochastic, values, allow_auto,
#                              shapes, deterministic_only, fields, extra = list(...))
```

| `kind` | Werte | Default-Grenzen | `shapes`-Default | `stochastic`-Default |
|---|---|---|---|---|
| `number` | value-Grammatik, numerisch | – | `"scalar"` | `TRUE` |
| `amount` | value, EUR | `min = -Inf` | `"scalar"` | `TRUE` |
| `rate` | value, Dezimal p. a. | `[-0.1, 1]`, > 1 Fehler | `"scalar"` | `TRUE` |
| `share` | value | `[0, 1]` | `"scalar"` | `TRUE` |
| `value` | jede Wertform | – | `c("scalar", "path")` | `TRUE` |
| `integer` | ganze Zahl | – | `"scalar"` | `FALSE` |
| `enum` | Code aus `values` (Vektor oder `"vocab:<enum>"`) | – | – | `FALSE` |
| `logical`, `date`, `string` | – | – | – | `FALSE` |
| `timing` | `date`, `year` (3.4) oder Token `completion` (3.9), immer deterministisch | – | – | `FALSE` |
| `schedule` | Wertform `schedule` | – | `"path"` | Beträge `TRUE`, Termine `FALSE` |
| `ref` | id einer Komponente bzw. eines Bausteins | – | – | `FALSE` |
| `ids` | Vektor von ids | – | – | `FALSE` |
| `map` | verschachtelt, `fields = list(<f> = vofi_param(...))` | – | – | je Feld |

**Bedeutung der beiden Schalter (MUSS):**

- `deterministic_only = TRUE` ist die **harte Sperre**: Overlay-, Kurzform- und Design-Ziele auf diesen Pfad sind ein
  Validierungsfehler; der Typ darf auf den Wert verzweigen (2.8 Nr. 2). Gesetzt für alle Zeitparameter von
  Instrumenten (8.2, R-47) und für alle Parameter der Arten `integer`, `enum`, `logical`, `date`, `string`, `timing`,
  `ref`, `ids` (implizit).
- `stochastic` ist nur ein **Hinweis** (Excel-Vorlage, Shiny-Regler, Vorschläge für das Overlay). Ein Overlay-Ziel
  auf einen Parameter mit `stochastic = FALSE` und `deterministic_only = FALSE` ist zulässig und erzeugt
  `vofi_warning_plausibility` („Parameter ist üblicherweise fest“).

`allow_auto = TRUE` erlaubt `auto` und `topup` (nur `amount_eur` von Instrumenten, 8.7).

### 5.5 Registrierung und Discovery

```r
# R/zzz.R (Integrator)
.onLoad <- function(libname, pkgname) {
  ns <- asNamespace(pkgname)
  reg_reset()
  lbl_load(system.file("labels", "de", package = pkgname))
  vocab_load(system.file("vocab", package = pkgname))
  for (f in sort(ls(ns, pattern = "^typedef_"), method = "radix")) {
    reg_add(get(f, envir = ns)(), source = "vofi")
  }
  op <- list(vofi.library_paths = character(), vofi.chunk_size = 2000L, vofi.max_memory_gb = 2,
             vofi.verbose = TRUE, vofi.strict_labels = FALSE, vofi.language = "de")
  toset <- !(names(op) %in% names(options())); if (any(toset)) options(op[toset])
  invisible()
}
```

- Interne Registry-Funktionen (`R/registry.R`): `reg_reset()`, `reg_add(def, source = c("vofi", "user"),
  overwrite = FALSE)`, `reg_get(kind, name)` (Fehler `vofi_error_registry`, wenn unbekannt, mit Vorschlag),
  `reg_has(kind, name)`, `reg_list(kind = NULL)` (Data Frame), `reg_rules(rule_name)` (alle Versionen).
- Registrierung auf oberster Dateiebene ist verboten (Kollation); ausschließlich über `typedef_*` in `.onLoad`.
- Ein neuer eingebauter Typ ist **eine neue R-Datei + eine Label-Datei + eine Testdatei**; keine bestehende Datei
  ändert sich.

### 5.6 Vertragstests (jeder registrierte Typ, automatisch in `test-contract-types.R`)

`vofi_check_type(name, kind = NULL, n = c(1L, 2L, 7L))` führt die Tests aus und wirft bei Verstoß
`vofi_error_contract` mit Liste der Befunde. Es benutzt ausschließlich das **Prüfkit im Paket**
(`R/registry-testkit.R`, I), damit es für Nutzer und unter `R CMD check` ohne `tests/` lauffähig ist:

```r
reg_test_grid(which = c("annual", "mixed"))   # annual: G1-artig, 2027-01-01, H = 6, C = 0 (T = 6, T+1 = 7 = n);
                                              # mixed: G4-artig, 2027-01-01, H = 6, C = 9, cs = 1, calendar
                                              # (gleiches end_date 2033-01-01)
reg_fake_draws(def, n, grid, example)         # vofi_draws mode "mc" mit laufspezifischen Werten (z. B.
                                              # Basis * (1 + 0.1 * (i - 1))) für alle numerischen Parameter des
                                              # Beispiels, die nicht deterministic_only sind
reg_test_ctx(def, n, grid, draws = NULL, example = NULL)   # Kontext über eng_context_from_parts() (6.1)
reg_example_core(n = 7L, T = 6L)              # synthetisches, vertragsgemäßes core (12.1) inkl. opp und
                                              # rebalance()-Attrappe im zugehörigen ctx
```

Die Testhelfer in `tests/testthat/helper-*.R` (15.1) sind dünne Hüllen um diese Funktionen. Ziehungen:
`reg_fake_draws()` mit laufspezifischen Werten für alle stochastischen Parameter des Beispiels.

| Nr. | Art | Prüfung |
|---|---|---|
| C1 | alle | Namensmuster, Eindeutigkeit, gültige Art, Version ganzzahlig |
| C2 | alle | Pflichtfunktionen vorhanden, exakte Formals |
| C3 | alle | Parameterschema gültig; keine reservierten Metafeldnamen (4.3.8) als Parameter; `example` erfüllt das Schema; `domain_reads` ⊆ zulässige Blöcke (5.2) |
| C4 | alle | Labels vorhanden: `types.<kind>.<name>.label`, `.description`, je Parameter `.params.<p>.label`, je Zeile bzw. Zeilenmuster `.rows.<r>` (Nutzertypen: Literale) |
| F1 | flow | `build(example)` liefert `vofi_flows` für alle n und beide Raster |
| F2 | flow | jede Zeile `dim == c(n, T + 1)`, `storage.mode == "double"`, nur endliche Werte |
| F3 | flow | lokale Zeilennamen ⊆ `rows` (Einträge oder Muster `<präfix>_*`), eindeutig, ohne `__` |
| F4 | flow | `section`/`category`/`tax_category`/`cash`/`kind`/`unit` gemäß Vokabular (7.6), Kombination zulässig; `section = "memo"` nur mit `cash = FALSE`; `tax_category = "principal"` ist für Flows verboten |
| F5 | flow | Vorzeichen gemäß Kategorie (Toleranz `zero_abs`) |
| F6 | flow | Pflicht-ids nach Spalte „ids“ in 7.6 (`asset_id` u. a. bei `land`, `acquisition_cost`, `capex`, `replacement`; `measure_id` u. a. bei `capex`, `replacement`, `relocation_cost`, `modernization_levy`, `grant`, `tax_credit`); ids im Register vorhanden |
| F7 | flow, instrument, kpi, rule | **Batch-Invarianz:** Lauf i eines Batches mit n = 7 ist identisch (≤ 1e-12 relativ) zum Einzellauf (n = 1) mit den Ziehungen von Lauf i |
| F8 | flow, instrument, action, kpi, expander | **kein RNG:** `.Random.seed` vor und nach dem Aufruf identisch |
| F9 | flow | Zeilen der Kategorien `residual_value`, `sale_cost` sind nur in Spalte T+1 ungleich 0 |
| F10 | flow mit `grid_invariant = TRUE` | Summe der Perioden je Kalenderjahr auf dem Raster `mixed` = Jahreswert auf dem Raster `annual` (1e-9 relativ), für alle Kalenderjahre, die beide Raster vollständig abdecken; auch mit Wachstum ≠ 0 (Kalenderjahresindex, 3.6). Das `example` MUSS rasterabhängige Termin-Defaults (z. B. `from = completion_date`) explizit setzen |
| I1 | instrument | `init`/`step` über t = 0…T auf beiden Rastern; `flows`/`memo`/`stocks` vollständig, n-Vektoren |
| I2 | instrument | Vorzeichen: `draw ≥ 0`, übrige Flüsse ≤ 0, Merkzeilen ≥ 0, `balance ≥ -stock_abs` |
| I3 | instrument | Bestandsfortschreibung: B_t = B_{t−1} + D_t − T_t − TB_t − ST_t − TZ_t (D_t Nennbetrag) |
| I4 | instrument | `prepay()`: `0 ≤ used ≤ min(amount, cap)`; danach `capacity()$balance` um `used` kleiner |
| A1 | account_action | `0 ≤ used ≤ amount`; Schlüssel ⊆ `rows`; Konto bleibt ≥ 0 |
| A2 | account_action | Vermögensneutralität: Änderung von G − KK − KKP − Σ B_k = **−** Summe der geschriebenen Flüsse (z. B. `dep_invest`: G steigt um a, Zeile −a), außer bei Zuflüssen von außen (`equity_call`, `stop`: Vermögen unverändert, Fluss +a) |
| D1 | distribution | `quantile(c(1e-9, 0.5, 1 - 1e-9), example)` endlich und im Träger; monoton |
| D2 | distribution | `point()` und `moments()` stimmen mit analytischen Werten überein; Stichprobe n = 20.000 innerhalb 4 SE |
| D3 | distribution | `validate()` erkennt ungültige Parameter (Testfälle im Typ-Test) |
| P1 | process | `simulate()` liefert n × length(years); Spalte 1 = Startwert |
| P2 | process | σ = 0 bzw. entartete Parameter: `simulate()` == `expected()` (1e-12) |
| P3 | process | Mittelwert der Simulation innerhalb 4 SE von `expected()`, wo definiert |
| P4 | process mit `quantile_path` | monoton nicht fallend in p; σ = 0: `quantile_path(par, years, p) == expected(par, years)` (1e-12); empirisches p-Quantil der Simulation je Jahr innerhalb 4 SE (R-95) |
| K1 | kpi | `compute(core, ctx)` mit `core <- reg_example_core(n = 7L)` und zugehörigem `ctx` liefert `vofi_kpi_value` mit n Werten; NA nur mit Code aus `na_reasons.yaml` |
| T1 | tax | Modul mit Nullparametern liefert den Vor-Steuer-VoFi exakt (10.10) |

### 5.7 Erweiterung durch Nutzer

```r
vofi_register_type(def, overwrite = FALSE)        # def aus vofi_type(); Nutzertypen brauchen label/labels-Literale
vofi_register_kpi(name, compute, label = NULL, unit = "EUR", shape = c("scalar", "series"),
                  rv_variant = FALSE, higher_is_better = TRUE, mc_default = FALSE,
                  perspectives = NULL, requires = character(), overwrite = FALSE)
vofi_register_tax_module(name, constructor, label = NULL, perspectives = NULL,
                         blocked_regimes = NULL, params = list(), overwrite = FALSE)
vofi_check_type(name, kind = NULL, n = c(1L, 2L, 7L))
```

Registrierte Nutzertypen sind sofort in YAML (`type: <name>`) nutzbar und erscheinen in einer danach erzeugten
Excel-Vorlage. Überschreiben eingebauter Typen nur mit `overwrite = TRUE` (Warnung).

---

## 6. Laufkontext `ctx`

### 6.1 Lebenszyklus und Unveränderlichkeit

1. `eng_context(model, draws)` (WS-D) erzeugt je Chunk bzw. Design-Lauf **eine** Umgebung der Klasse `vofi_ctx`,
   füllt sie und sperrt sie mit `lockEnvironment(ctx, bindings = TRUE)`. Dieselbe Fabrik ohne Modell steht für das
   Prüfkit und Testhelfer bereit: `eng_context_from_parts(grid, spec, draws = NULL, components = list(),
   components_base = components, mode = c("deterministic", "mc", "design"), engine_env = NULL)` (WS-D; Minimalfassung
   aus Phase 0). `components` sind vorab gebaute `vofi_flows` je id (für `ctx$component()`), `components_base` die des
   Basisfalls (für `ctx$component_base()`, R-70), `engine_env` ist die private Engine-Umgebung (6.1 Nr. 3, für
   `ctx$auto()` und `ctx$rebalance()`; im Prüfkit eine Attrappe).
2. Typen DÜRFEN nur lesen und die bereitgestellten Funktionen aufrufen. Sie DÜRFEN keine Referenzen auf `ctx` über
   den Aufruf hinaus speichern und keine Umgebungen verändern.
3. Ergebnisse bereits gebauter Komponenten liegen in einer privaten Umgebung der Engine; Zugriff nur über
   `ctx$component()` und `ctx$rows()` und nur für **deklarierte Abhängigkeiten** (Parameter der Art `ref`,
   Wertbezüge `{ref: components.<id>…}`, Feld `after`). Ein Zugriff auf andere Komponenten ist `vofi_error_contract`.
   Domänenpfade der in `domain_reads` (5.2) genannten Blöcke dürfen über `ctx$value()`, `ctx$value_base()` und
   `ctx$spec` gelesen werden, endogene Größen nie (4.5 Regel 2). Die Einschränkung auf deklarierte Abhängigkeiten gilt
   für Ergebnisse gebauter Komponenten, nicht für Domänenpfade (R-93). Das Prüfkit (5.6) und Typtests übergeben die
   Domänenblöcke über `eng_context_from_parts(grid, spec, …)`.
4. Werte werden je Chunk zwischengespeichert (Schlüssel: Pfad + Shape).

### 6.2 Felder und Funktionen

| Element | Signatur / Typ | Rückgabe / Bedeutung |
|---|---|---|
| `n`, `T` | integer | Läufe im Chunk, letzter Periodenindex |
| `grid` | `vofi_grid` | Raster (Abschnitt 3) |
| `mode` | chr | `"deterministic"`, `"mc"`, `"design"` |
| `sims`, `blocks` | integer | globale Laufnummern (Länge n), Blöcke des Chunks |
| `spec` | `vofi_spec` | aufgelöste Variante (nur lesen) |
| `project`, `building`, `household` | Liste | Kurzzugriff auf die aufgelösten Blöcke |
| `perspective`, `tax_regime`, `legal_state`, `pending_reforms` | chr / Date | aus `project` |
| `param(spec, name, shape = c("scalar", "path"))` | `name` = Parametername oder Unterpfad eines `map`-Parameters (`"fees.processing_fee_share"`, `"repayment_grant.amount_eur"`) | **nur numerische** Parameter (Arten `number`, `amount`, `rate`, `share`, `value`, `schedule`): double n-Vektor bzw. n × (T+1); Pfad `<sammlung>.<spec$id>.<name>`; Auflösung nach 6.3 |
| `setting(spec, name)` | `name` wie bei `param()` | **nicht-numerische** Parameter (`timing` → `Date`, `enum`/`string` → chr, `logical` → lgl, `integer` → int, `ids` → chr, `ref` → chr): deterministischer, normalisierter Wert inkl. Default; nie Ziehungen; `timing` mit `year: Y` liefert `Y-01-01` |
| `value(path, shape = c("scalar", "path"))` | | Wert eines beliebigen numerischen Spec-Pfads (gleiche Auflösung) |
| `param_base(spec, name, shape)`, `value_base(path, shape)` | wie `param()`/`value()` | **Basisfallwert** (Plan- bzw. Erklärungszeitpunkt): Auflösung nach 6.3 ohne Ziehungen und Designwerte, in allen Läufen gleich (R-70) |
| `component_base(id)` | id einer deklarierten Abhängigkeit | `vofi_flows` der Abhängigkeit aus dem Basisfall-Vorlauf (9.1 Stufe 6a), Zeilen auf n gehoben (R-70) |
| `market(name)` | chr, z. B. `"mortgage_rate"`, `"energy_price.gas"` | n × (T+1) = `value(paste0("market.", name), "path")` |
| `index(g, base_date = NULL)` | g: n-Vektor oder n × (T+1) | n × (T+1), `grid_index()` (Periodenende, Bestandsgrößen) |
| `index_year(g, base_date = NULL)` | wie `index()` | n × (T+1), `grid_index_year()` (Kalenderjahresindex, laufende Jahresbeträge, R-62) |
| `timing(spec, name)` | Parameter der Art `timing` | `list(date = Date, shift = double n-Vektor)` (3.9) |
| `shift_period(date, months)`, `shift_overlap(from, months, to = NULL)`, `shift_months(from, months, to = NULL)` | `months`: n-Vektor | laufspezifische Verschiebung (3.9, R-60) |
| `rebalance(extra_out = NULL)` | n × (T+1) zusätzliche Entnahmen (≤ 0) oder `NULL` | nur in Kennzahlen (Stufe 8, sonst `vofi_error_contract`): Neuausgleich des Chunks ohne Ledger-Buchung, mit demselben exogenen Ledger, denselben Ziehungen und dem Instrument-Cache (9.3); Rückgabe `list(BS_T = n, NS = n × (T+1), BS_T_ex_rv = n, RW_T = n)` (12.8) |
| `zeros()` | | n × (T+1) Nullmatrix |
| `by_sim(x)` | x: Skalar oder n-Vektor | n × (T+1), jede Zeile konstant |
| `by_period(x)` | x: Vektor der Länge T+1 | n × (T+1), jede Spalte konstant (**einzige** zulässige Verknüpfung von Zeitvektoren mit Matrizen) |
| `rate_eff(r_pa)`, `rate_nom(r_pa)`, `per_period(x_pa)` | | n × (T+1), 3.6 |
| `period_of(date)`, `period_of_year(year)`, `overlap(from, to)` | | 3.4, 3.6 |
| `to_periods(x_month)`, `to_months(x, how = c("repeat", "spread"))` | | 3.6 |
| `component(id)` | id | `vofi_flows` der Abhängigkeit (Zeilen mit lokalen Schlüsseln, `aux`) |
| `rows(id = NULL, section = NULL, category = NULL, tax_category = NULL, measure_id = NULL, local_row = NULL)` | Filter (`id` darf ein Vektor sein; alle Filter UND-verknüpft, je Filter ein Vektor zulässiger Werte; R-93) | benannte Liste n × (T+1) (Ledger-Schlüssel) aus Abhängigkeiten |
| `auto(id)` | id | `list(commitment = n-Vektor, draws = n × (T+1))` (8.7): bei `auto` aus dem Basisfall, in allen Läufen gleich; bei `topup` je Lauf |
| `rule(name)` | chr | Funktion der zum Rechtsstand gültigen Regelversion (4.10) |
| `legal(topic)` | chr | `values` des gewählten `legal/*`-Eintrags |
| `draw(key)` | Overlay-Schlüssel | n-Vektor bzw. n × (T+1) oder `NULL`; nur für begründete Sonderfälle, Standard ist `param()` |
| `assets()`, `measures()` | | Register bis einschließlich Expander und bereits gebauter Komponenten |
| `lbl(key, ...)` | | Text |
| `abort(key, ..., .class = "vofi_error_contract")`, `warn(key, ..., .class = "vofi_warning_engine")`, `inform(key, ...)` | | wie 2.9, Platzhalter `{where}` = Komponentenpfad wird ergänzt |
| `tol` | Liste | `vofi_tol` (2.13) |

### 6.3 Auflösungsreihenfolge von `param()` und `value()` (MUSS)

```text
p  <- Pfad des Parameters: paste(<sammlung>, spec$id, name, sep = ".") mit <sammlung> = "components" bzw.
      "financing" (z. B. "components.<id>.<name>", "financing.bank.fees.processing_fee_share"); bei value(): Pfad
      wie übergeben (z. B. "market.<name>"). Der Knoten liegt bei path_get(ctx$spec, p) (Pfad-Identität, 4.13).
1  falls mode != "deterministic" und draws einen statischen Schlüssel mit target == p hat:
     apply = replace:  x                                                                      n-Vektor
     apply = multiply: b * x;  apply = add: b + x  (R-94)                                     Shape von b
       mit b = Wert des Knotens am Pfad p nach Schritt 3 (Skalar -> n-Vektor; Pfad: x zeilenweise gehoben wie
       by_sim()); Ziel der Art share: Ergebnis auf [0, 1] begrenzt
2  sonst falls draws einen Prozess mit target == p hat:                                     n x (T+1)-Pfad
3  sonst Knoten am Pfad p auswerten:
     const -> Skalar; series_t / series_year / points / schedule -> Pfad (Elementknoten nach 4.5 Regel 4);
     ref -> value(Zielpfad) (rekursiv, Zyklusschutz), dann scale/offset/floor/cap bzw. anchor (4.5);
     growth -> start * index_year(growth, base_date) bei index = calendar_year (Default),
               start * index(growth, base_date) bei index = period_end (4.5, R-91);
     expr -> expr_eval(ast, resolve = value, n, T) (4.5 Regel 5; nicht-numerische Symbole mit setting-Semantik);
     quantity -> value * Bezugsgröße; auto -> NULL (nur Instrumente, über ctx$auto())
4  Shape: "scalar" angefordert und Ergebnis zeitabhängig  -> vofi_error_contract;
          "scalar" angefordert sonst                       -> as.double(rep_len(x, n)) (immer Länge n, double);
          "path" angefordert und Ergebnis Skalar/n-Vektor  -> by_sim(); Ergebnis immer double n x (T+1)
```

- Im deterministischen Modus ist `draws` leer (11.9); alle Pfade laufen über Schritt 3. **Derselbe Codepfad** gilt
  für N = 1 und N > 1.
- Im Modus `"design"` (Tornado, Spider, Break-even) liefert `draws` gezielt gesetzte Werte je Zeile (11.11).
- **Basisfallwerte (R-70, Konzept 3.5, 3.8):** `param_base()`/`value_base()` werten den Knoten nach Schritt 3 aus und
  lassen die Schritte 1–2 weg, auch rekursiv in Bezügen und Ausdrücken; Designwerte wirken nicht. Ergebnis ist der
  deterministische Basisfall des Modells (Schichten 0–5, 7, 8, Zusagen mit Basiswert), recycelt auf n bzw. n × (T+1).
  `component_base(id)` liest den Basisfall-Vorlauf (`model$base$flows`). Im Modus `"deterministic"` gilt
  `param_base() == param()` und `component_base() == component()`. **Verwendung:** Größen, die zum Planungs- bzw.
  Erklärungszeitpunkt feststehen und auf die spätere Pfade nicht wirken: Plan-JAZ für § 559f (Default von
  `energy.<zustand>.jaz_plan`, 4.3.6b), Preisbasis einer warmmietenneutralen Umlage (Begrenzung aus den
  Basisfall-Heizkosten der Mieter vorher/nachher in der **Bezugsperiode**: die erste Periode mit 12 Monaten, die am
  oder nach dem frühesten Wirksamkeitsmonat der Umlage im Basisfall beginnt; R-102), Kreditbeträge `auto` (8.7). Laufspezifische
  Größen, die zum Erklärungszeitpunkt bekannt sind (realisierte Kosten, tatsächlich gewährte Förderung), lesen Typen
  weiter über `param()` bzw. `component()` (Konzept 3.5).

### 6.4 Build-Kontext `bctx` (Expander)

`bctx` ist eine gesperrte Umgebung mit `grid`, `spec` (teilaufgelöst), `project`, `building`, `legal(topic)`,
`rule(name)`, `lib(id)` (gelesener Bibliothekseintrag), `period_of(date)`, `period_of_year(year)`,
`value_base(path, shape = c("scalar", "path"))` (deterministischer Basisfallwert eines numerischen Domänenpfads nach
6.3 ohne Ziehungen, n = 1; R-92), `lbl`, `abort`, `warn`, `inform` sowie den Knotenkonstruktoren `node_const(x)`,
`node_ref(path, scale = 1, offset = 0, floor = -Inf, cap = Inf)`, `node_schedule(dates, amounts)`,
`node_growth(start, growth, base_date = NULL, index = "calendar_year")` und `node_expr(text)` (ruft `expr_parse()`,
liefert `list(kind = "expr", text, ast)`; R-91). Ziehungen gibt es im Build nicht. **Eigentum:** `bctx` baut
`scn_bctx(spec, grid)` in `R/scenario-layers.R` (WS-A); die Knotenkonstruktoren stehen in `R/values-normalize.R`
(WS-A). `rule()`/`legal()` nur auf deterministische Eingaben (4.12 Nr. 5). `value_base()` dient ausschließlich
deterministischen Ableitungen nach 4.12 Nr. 5 (a) (Gewichte von `draw_schedule`, Anzeige-Tags wie `measure_id`,
Registerfelder); ein Ergebnis von `value_base()` als Wert eines overlay-fähigen Parameters ist ein Vertragsverstoß.

---

## 7. Ledger und Zeilenvertrag

### 7.1 Zeile `vofi_row()`

```r
vofi_row(key, values, section, category, tax_category = NULL, cash = NULL,
         kind = c("flow", "stock", "memo"), unit = "EUR", asset_id = NULL, measure_id = NULL,
         vat_rate = 0, vat_recoverable = FALSE, is_tax = NULL, program = NULL,
         label = NULL, label_key = NULL, ...)
# -> Klasse "vofi_row"
```

| Feld | Typ | Pflicht | Regel |
|---|---|---|---|
| `key` | chr | ja | **lokaler** Zeilenname des Typs (∈ `rows` der Typdefinition bzw. eines Musters, 5.2); den Ledger-Schlüssel setzt die Engine (7.3) |
| `values` | numerische Matrix n × (T+1), `double` | ja | **Bruttobeträge**; Vorzeichen **Zufluss +, Abfluss −** aus Sicht des Investors; Bestände ≥ 0; keine NA/Inf |
| `section` | chr ∈ sections.yaml | ja | Flows dürfen nur `project`, `grants`, `equity` (nur `equity_in`/`equity_out`) und `memo` verwenden |
| `category` | chr ∈ categories.yaml | ja | MUSS zur `section` passen (7.6) |
| `tax_category` | chr ∈ tax_categories.yaml | ja | `NULL` = Default der Kategorie; MUSS zu den erlaubten der Kategorie gehören (7.6); `principal` ist für Flows verboten |
| `cash` | lgl | ja | `NULL` = Default der Kategorie (7.6, Spalte `cash`); in `section = "memo"` ist `cash = TRUE` ein Vertragsfehler (F4) |
| `kind` | chr | ja | `flow` (zahlungswirksam oder Merk-Fluss), `stock` (Bestand), `memo` (Merkposten, auch Mengen) |
| `unit` | chr ∈ units.yaml | ja | `EUR` außer bei Mengen-Merkzeilen (`kWh`, `t_co2`, `m2`, `share`) |
| `asset_id`, `measure_id` | chr | bedingt | 5.6 F6 |
| `vat_rate` | num ∈ [0, 1] | ja | in `values` enthaltener USt-Satz (D6); PV auf oder bei Wohngebäuden: 0 (bis 30 kWp ohne Nachweis, größere Anlagen über ein Attribut je Anlage, 7.10) |
| `vat_recoverable` | lgl | ja | v1 immer `FALSE` (kein Vorsteuerabzug) |
| `is_tax` | chr | nein | `grundsteuer`, `grunderwerbsteuer`, `umsatzsteuer` |
| `program` | chr | bei Förderung | Programmcode (Kumulierung, § 35c-Sperre) |
| `label`, `label_key` | chr | nein | Anzeige; Default `types.<kind>.<typ>.rows.<key>` bzw. `rows.<präfix>_*` mit `{id}`; YAML-`label` der Komponente wird vorangestellt („<Komponente>: <Zeile>“) |
| `...` | | nein | nur Felder aus `inst/vocab/row_extra_fields.yaml`: `tax_period` (int), `spread_years` (int), `use_share_rented` (num), `activity_type` (chr), `stochastic_source` (chr), `allocable_to_tenant` (lgl), `realization` (`actual`/`hypothetical`), `approval_date` (Date), `rv_basis` (`method`/`measures`, nur Kategorie `residual_path`, R-72) |

### 7.2 `vofi_flows()`, `vofi_asset()`, `vofi_measure()`

```r
vofi_flows(..., assets = list(), measures = list(), aux = list(), meta = list())
#  ...      : vofi_row-Objekte
#  aux      : benannte Liste n x (T+1)-Matrizen, die KEINE Ledger-Zeilen sind (z. B. Wärmebedarf), für
#             abhängige Komponenten über ctx$component(id)$aux (R-42)
#  meta     : Liste (Hinweise, Diagnose); erscheint nicht im Ledger
# -> Klasse "vofi_flows": list(rows = list(<vofi_row>), assets, measures, aux, meta)

vofi_asset(asset_id, asset_type, in_service_date, land_share = 0, afa_method = NULL,
           useful_life_override = NULL, construction_start_date = NULL, building_application_date = NULL,
           original_completion_year = NULL, acquisition_date = NULL, living_area_m2 = NULL,
           efficiency_standard = NULL, label = NULL)                       # Klasse "vofi_asset" (R-41)

vofi_measure(measure_id, measure_type, classification = c("auto", "erhaltung", "herstellung"),
             classification_source = c("default", "user", "rule"), completion_date = NULL,
             paid_in_full_date = NULL, contractor_certified = NA,
             funding_choice = c("keine", "beg_zuschuss", "beg_kredit", "35c"), asset_id = NULL,
             label = NULL)                                                 # Klasse "vofi_measure"
```

Die AfA-Bemessungsgrundlage ist **kein** Feld; ein Steuermodul bildet sie aus den Zeilen mit derselben `asset_id`
(Memo 06 §7.4). `asset_type` ∈ `asset_types.yaml` (`gebaeude_wohnen`, `gebaeude_nichtwohnen`, `grund_boden`,
`aussenanlage`, `bewegliches_wg`, `pv_anlage`, `ladeinfrastruktur`); `measure_type` ∈ `measure_types.yaml`.
Doppelte ids im Register sind ein Fehler, außer das Objekt ist identisch.

### 7.3 Ledger-Schlüssel (MUSS)

| Quelle | Schlüssel | Beispiel |
|---|---|---|
| Zahlungskomponente (flow) | `<component_id>__<lokale_zeile>` (Trenner: doppelter Unterstrich) | `m_huelle_capex__cost`, `e_pv__feed_in`, `u_standard_rent__levy_huelle` |
| Eigenkapitalbaustein (`financing`, Typ `equity`) | `<financing_id>__<lokale_zeile>` | `ek__in` |
| Kreditinstrument k | `loan_<k>_<zeile>` (feste Zeilenmenge 8.4, keine Zeile ist `_`-Suffix einer anderen) | `loan_kfw261_interest`, `loan_bank_balance` |
| Engine (feste Schlüssel) | 7.7 | `od_draw`, `dep_balance`, `balance_check` |

Da ids, lokale Zeilennamen und Parameternamen keinen doppelten Unterstrich enthalten (4.4 Nr. 2) und Engine- sowie
Kreditschlüssel nie `__` enthalten, sind Schlüssel per Konstruktion global eindeutig; eine dennoch auftretende
Kollision ist `vofi_error_engine`. Die Bestandteile stehen zusätzlich in den Metadaten (`source_id`, `local_row`),
damit Schlüssel nie geparst werden müssen. **Kennzahlen und Tabellen wählen Zeilen über Tags (Abschnitt, Kategorie,
Steuerkategorie, Quelle), nie über Schlüsselmuster.**

### 7.4 Struktur `vofi_ledger`

```r
vofi_ledger <- structure(list(
  rows = data.frame(                       # eine Zeile je Ledger-Zeile, Reihenfolge = Grob-Layout (order)
    key = chr, section = chr, category = chr, tax_category = chr, cash = lgl,
    kind = chr,                            # "flow" | "stock" | "memo" | "check"
    unit = chr, asset_id = chr, measure_id = chr,       # NA_character_, wenn nicht zutreffend
    vat_rate = num, vat_recoverable = lgl, is_tax = chr, program = chr,
    source_id = chr,                       # Komponenten-, Baustein-, Instrument- oder Konto-id; Engine: "engine"
    existing_debt = lgl,                   # TRUE für alle Zeilen eines Bestandsdarlehens (existing, 8.2, R-77)
    source_type = chr,                     # Typname bzw. "engine"
    origin = chr,                          # "scenario" | "expander:<name>" | "engine" | "library:<id>"
    local_row = chr, label_key = chr, label = chr,
    order = num,                           # Sortierschlüssel (7.8)
    extra = I(list()),                     # Felder aus row_extra_fields.yaml
    stringsAsFactors = FALSE),
  values = list(<key> = matrix(n, T + 1)), # gleiche Reihenfolge wie rows$key
  n = int, T = int
), class = "vofi_ledger")
```

- Orientierung n × (T+1) (Spalten zusammenhängend im Speicher; Zugriff `m[, j]` in der Schleife).
- Interne Zugriffe (`R/engine-ledger.R`, WS-D): `ledger_add(led, rows)`, `ledger_get(led, key)`,
  `ledger_select(led, section = NULL, category = NULL, tax_category = NULL, cash = NULL, kind = NULL,
  source_id = NULL, existing_debt = NULL, rv_basis = NULL)` → Schlüssel, `ledger_sum(led, ...)` → n × (T+1) (Summe der gewählten Zeilen, Nullmatrix bei
  leerer Auswahl), `ledger_subset_sims(led, i)`, `ledger_long(led)` → Data Frame `key, sim, t, value`.

### 7.5 Abschnitte (`inst/vocab/sections.yaml`)

| `section` | Ordnung | Inhalt | zahlungswirksame Zeilen gehen in `balance_check` ein |
|---|---:|---|---|
| `project` | 100 | Zahlungsfolge der Investition (originär) | ja |
| `grants` | 200 | Investitionszuschüsse, laufende Zuschüsse, § 35c | ja |
| `equity` | 300 | Einlagen, Entnahmen, Nachschüsse, Fehlbetrag | ja |
| `loans` | 400 + k | je Kredit ein Block (k = Position in `financing`) | ja (Merkzeilen nein) |
| `overdraft` | 500 | Kontokorrent (Regel- und Strafzinstranche) | ja |
| `deposit` | 600 | Geldanlage | ja |
| `tax` | 700 | Ertragsteuern (Slot), Abgeltungsteuer auf Habenzinsen | ja |
| `check` | 800 | Finanzierungssaldo | – |
| `stocks` | 900 | Bestände und Bestandssaldo | – |
| `memo` | 950 | Merkzeilen (Marktwert, Mietersicht, Mengen, steuerliche Nebenrechnung) | nein |

### 7.6 Kategorien (`inst/vocab/categories.yaml`)

Kategorien sind **je Abschnitt** definiert (Schlüssel `section` + `category`); gleiche Namen in verschiedenen
Abschnitten (z. B. `draw` in `loans` und `overdraft`) sind zulässig; ihre Labels stehen unter
`vocab.categories.<section>.<category>` (2.11). Spalten: Vorzeichen (`+` ≥ 0, `−` ≤ 0, `±`), `noi` (geht in den
Reinertrag NOI ein, 12.3), `burden` (geht in die monatliche Belastung des Selbstnutzers ein, `monthly_burden`;
Vorzeichen umgekehrt), Default-`tax_category`, weitere erlaubte `tax_category`, Pflicht-ids, `cash`-Default.
**Engine-Kategorien** (E) dürfen nur von der Engine erzeugt werden. Zeilen im Abschnitt `memo` sind immer
`cash = FALSE`.

| section | category | VZ | noi | burden | tax_category (Default; erlaubt) | ids | cash |
|---|---|:---:|:---:|:---:|---|---|:---:|
| project | `land` | − | | | `capex_land` | asset | T |
| project | `acquisition_cost` | − | | | `acquisition_ancillary` | asset | T |
| project | `capex` | − | | | `capex_depreciable`; `capex_expensable`, `capex_land` | asset, measure | T |
| project | `replacement` | − | | | `capex_depreciable`; `capex_expensable` | asset, measure | T |
| project | `relocation_cost` | − | | | `expense_deductible`; `capex_depreciable`, `capex_expensable` | measure | T |
| project | `rent` | + | x | | `income_rental` | | T |
| project | `rent_loss` | − | x | | `income_rental` | | T |
| project | `modernization_levy` | + | x | | `income_rental` | measure | T |
| project | `operating_income` | + | x | | `income_other_taxable`; `income_tax_exempt`, `passthrough` | | T |
| project | `operating_cost` | − | x | x | `expense_deductible`; `expense_nondeductible`, `passthrough` | | T |
| project | `property_tax` | − | x | x | `expense_deductible`; `expense_nondeductible` | | T |
| project | `maintenance` | − | x | x | `expense_deductible`; `expense_nondeductible`, `capex_expensable` | | T |
| project | `energy_cost` | − | x | x | `expense_deductible`; `expense_nondeductible` | | T |
| project | `co2_cost` | − | x | x | `expense_deductible`; `expense_nondeductible` | | T |
| project | `energy_income` | + | x | x | `income_tax_exempt`; `income_other_taxable` | | T |
| project | `energy_saving` | + | x | x | `imputed_benefit` | | T |
| project | `imputed_rent` | + | | | `imputed_benefit` | | T |
| project | `other_income` | + | | | `income_other_taxable`; `income_tax_exempt` | | T |
| project | `other_cost` | − | x | x | `expense_deductible`; `expense_nondeductible` | | T |
| project | `passthrough` | ± | | | `passthrough` | | T |
| project | `custom` | ± | | | `not_applicable`; alle außer `principal`, `tax_credit`, `tax_payment` | | T |
| project | `residual_value` | + | | | `disposal_proceeds` | (asset) | T |
| project | `sale_cost` | − | | | `disposal_proceeds` | | T |
| grants | `grant` | + | | | `subsidy_investment` | measure | T |
| grants | `operating_subsidy` | + | x | | `subsidy_operating` | | T |
| grants | `tax_credit` | + | | | `tax_credit` | measure | T |
| equity | `equity_in` | + | | | `equity` | | T |
| equity | `equity_out` | − | | | `equity` | | T |
| equity | `equity_in_kind` (E, memo) | ± | | | `equity` | | F |
| equity | `equity_call` (E) | + | | | `equity` | | T |
| equity | `shortfall` (E) | + | | | `equity` | | T |
| loans | `draw` (E) | + | | | `principal` | | T |
| loans | `repay` (E) | − | | x | `principal` | | T |
| loans | `repay_balloon` (E) | − | | | `principal` | | T |
| loans | `prepay` (E) | − | | | `principal` | | T |
| loans | `interest` (E) | − | | x | `interest_expense` | | T |
| loans | `fees` (E) | − | | x | `interest_expense` | | T |
| loans | `repayment_grant` (E, memo) | + | | | `subsidy_repayment_grant` | measure oder funding (R-99) | F |
| loans | `disagio` (E, memo) | + | | | `interest_expense` | | F |
| loans | `assumed` (E, memo) | + | | | `principal` | | F |
| overdraft | `draw`, `repay`, `interest` (E) | +, −, − | | | `principal`, `principal`, `interest_expense` | | T |
| deposit | `invest`, `withdraw`, `interest` (E) | −, +, ± | | | `principal`, `principal`, `interest_income` | | T |
| tax | `income_tax` (E) | ± | | | `tax_payment` | | T |
| tax | `withholding_tax` (E) | − | | | `tax_payment` | | T |
| check | `balance_check` (E) | ± | | | `not_applicable` | | F |
| stocks | `balance` (E) | + | | | `not_applicable` | | F |
| stocks | `tax_liability` (E) | ± | | | `not_applicable` | | F |
| stocks | `net_position` (E) | ± | | | `not_applicable` | | F |
| memo | `market_value` | + | | | `not_applicable` | (asset) | F |
| memo | `residual_path` | + | | | `not_applicable` | (asset) | F |
| memo | `tenant_energy_cost`, `tenant_operating_cost` | + | | | `not_applicable` | | F |
| memo | `tenant_energy_cost_pre` | + | | | `not_applicable` | | F |
| memo | `energy_quantity` (Einheit kWh), `co2_emission` (t_co2: t CO2-Äq.; Treibhausgasbilanz **aller** Energieträger nach `ghg_factor_kg_kwh`, GEG Anlage 9; nicht der BEHG-Kostenfaktor; R-101) | + | | | `not_applicable` | | F |
| memo | `tax_report` | ± | | | `not_applicable` | | F |
| memo | `aux_memo` | ± | | | `not_applicable` | | F |

Merkzeilen der Mietersicht und Mengen werden als **positive Beträge bzw. Mengen** geführt. `market_value`,
`residual_path` und Mengen sind `kind = "stock"` bzw. `"memo"`. `market_value` (V_t) und `residual_path` (RW_t, mit
`rv_basis`) schreibt die Komponente `residual_value` nach 4.12 Nr. 8 (R-72). `tenant_energy_cost_pre` sind die Heiz-
und Warmwasserkosten der Mieter im Zustand vor der Maßnahme mit denselben Preis- und Mengenpfaden (Mieteranteil,
Grundlage der Warmmietenänderung „vorher/nachher“, 12.3, R-83); sie schreibt der Typ `tenant_costs`. Die Pflicht-id
der Merkzeile `repayment_grant` (F6 sinngemäß für Instrumente) ist `measure_id` oder `funding_id`; ein Förderkredit
trägt `funding_id` und als Anzeige-Tag `measure_id` der von ihm geförderten Maßnahme mit den größten Basisfallkosten
(`bctx$value_base()`, R-99). Zeilen der Kategorie `custom` sind für Lehrbuch- und Orakelfälle gedacht; der
Test „Steuerbereitschaft“ (15.6) verlangt für S1–S5, dass keine zahlungswirksame Zeile `not_applicable` trägt.

### 7.7 Engine-Zeilen (feste Schlüssel)

| Schlüssel | section / category | kind | Bestimmung (9.3) |
|---|---|---|---|
| `equity_call` | equity / equity_call | flow | Aktion D4 `equity_call` |
| `shortfall` | equity / shortfall | flow | Aktion D4 `stop` |
| `extra_equity_out` | equity / equity_out | flow | Zusatzentnahme des Entnahme-Äquivalents (9.3, 12.8); nur in Wiederholungsläufen, nie im gespeicherten Ledger |
| `equity_in_kind` | equity / equity_in_kind | memo | Sacheinlage in t = 0: `building.existing_value_eur` − Σ Anfangsbestände der Bestandsdarlehen; nur wenn der Bestandswert gesetzt ist (9.3, R-68) |
| `opp_equity_call_in`, `opp_in_kind_sale` | equity / equity_in (negativ: equity_out) | flow | nur in der Unterlassungsalternative: Nachschüsse der Investition bzw. Verkaufserlös des Bestands in t = 0 (9.5 Nr. 1, 7) |
| `loan_<k>_draw`, `_repay`, `_repay_balloon`, `_prepay`, `_interest`, `_fees` | loans / gleichnamig | flow | Instrument `step()`, Ü3 `loan_prepay` schreibt in `_prepay` |
| `loan_<k>_repayment_grant`, `loan_<k>_disagio`, `loan_<k>_assumed` | loans / gleichnamig | memo | Instrument `step()`; `_assumed` = übernommener Anfangsbestand eines Bestandsdarlehens in t = 0 (8.5 (h), R-68) |
| `loan_<k>_balance` | stocks / balance | stock | Instrumentzustand nach Ausgleich |
| `od_draw`, `od_repay`, `od_interest`, `od_balance` | overdraft / … ; stocks / balance | flow / stock | Regeltranche KK |
| `odp_draw`, `odp_repay`, `odp_interest`, `odp_balance` | overdraft / … ; stocks / balance | flow / stock | Strafzinstranche KKP (R-31) |
| `dep_invest`, `dep_withdraw`, `dep_interest`, `dep_balance` | deposit / … ; stocks / balance | flow / stock | Geldanlage G |
| `dep_wht` | tax / withholding_tax | flow | Abgeltungsteuer auf positive Habenzinsen |
| `tax` | tax / income_tax | flow | `-tax_step()$payment`; Label „Ertragsteuern“, Vermerk „nicht berücksichtigt“ bei `tax_none` |
| `tax_liability` | stocks / tax_liability | stock | 0 bis T−1; in T `tax_finalize()$payment_T` (positiv = Verbindlichkeit) |
| `balance_check` | check / balance_check | check | Summe aller `cash`-Zeilen der Abschnitte 100–700 je t; MUSS ≈ 0 sein |
| `net_position` | stocks / net_position | stock | BS_t = G − KK − KKP − Σ B_k − tax_liability |

Die Engine-Zeilen für Kredite, Konten, `tax`, `balance_check` und `net_position` existieren **immer** (auch wenn sie
null sind), damit die Tabelle stabil ist. `odp_*`, `dep_wht`, `shortfall`, `equity_call` werden in der Anzeige mit
`detail = "standard"` ausgeblendet, wenn sie in allen Läufen null sind.

### 7.8 Grob-Layout (Reihenfolge der VoFi-Tabelle)

`order = 1000 * section_order + 10 * category_rank + komponentenposition / 1000`. Innerhalb eines Abschnitts folgen
die Kategorien der Tabellenreihenfolge in 7.6; Kredite bilden je k einen Block (`section_order = 400 + k`) mit den
Zeilen `draw, repay, repay_balloon, prepay, interest, fees` und den Merkzeilen `repayment_grant, disagio, assumed`;
die Sacheinlage `equity_in_kind` steht als Merkzeile im Abschnitt `equity` nach `equity_in`. Die
Bestände folgen in `stocks` in der Reihenfolge Kredite (k), `od_balance`, `odp_balance`, `dep_balance`,
`tax_liability`, `net_position`. `vofi_table()` (WS-H) zeigt zusätzlich die Anzeige-Summen `cf_project`
(„Zahlungsfolge der Investition“, Summe Abschnitt `project`) und `grant_cash` (Summe `grants`) (R-19).

### 7.9 Aggregationsregeln

1. **Finanzierungssaldo:** `balance_check[, j] = Σ values[[k]][, j]` über alle Zeilen mit `cash = TRUE` und
   `section ∈ {project, grants, equity, loans, overdraft, deposit, tax}`.
2. **Anzeige `detail = "standard"`:** Summen je (section, category); Kredite je k und Kategorie; Komponenten-Label
   entfällt. **`detail = "full"`:** jede Ledger-Zeile.
3. Summen **über Läufe** stehen nie im Ledger; sie sind Sache der Ergebnis- und Statistikfunktionen.
4. Die Grob-Tabelle nach Memo 01 §2.2 entspricht `detail = "standard"`: Zeile 1 = `cf_project` (aufklappbar),
   Zeile 2 = `grant_cash`, Zeilen 3–4 = `equity_in`/`equity_out` (+ `equity_call`), Zeilen 5–9 je Kredit, 10–12
   Kontokorrent, 13–15 Geldanlage, 16 Steuern, 17 Finanzierungssaldo, danach Bestände.

### 7.10 Umsatzsteuer (D6, R-24)

- `values` sind **brutto** (inkl. nicht abziehbarer USt). Netto und USt werden **verlustfrei abgeleitet**:
  `net = values / (1 + vat_rate)`, `vat = values - net`. `vofi_ledger(x, vat = TRUE)` und der Excel-Export geben
  Brutto, Netto und USt getrennt aus. Damit gilt die Pflicht „netto und USt getrennt gespeichert“ (Memo 06 §8) als
  erfüllt (Metadatum `vat_rate` je Zeile, Ableitung deterministisch).
- Kostenkomponenten mit gemischten Sätzen erzeugen je Satz eine eigene Zeile mit festem Suffix: `<zeile>_vat19`,
  `<zeile>_vat7`, `<zeile>_vat0` (deklariert als Einträge oder Muster `<zeile>_*`, 5.2); eine Komponente mit nur
  einem Satz verwendet den Grundnamen ohne Suffix. Der Energie-Expander erzeugt je Zustand s und Träger c eine
  Komponente `e_<s>_<c>_cost` (Typ `energy_cost`) und für Träger mit Emissionsfaktor > 0 `e_<s>_<c>_co2` (Typ
  `co2_cost`), nicht dynamische Zeilen (R-90). Standardsatz 0.19; 0.07
  nur, wo einschlägig; PV-Lieferung und -Installation auf oder bei Wohngebäuden 0 (§ 12 Abs. 3 Nr. 1 UStG): bis 30 kWp
  ohne Nachweis, größere Anlagen nur mit gesetztem Begünstigungsattribut der Anlage (Feldname Spec 01) und Hinweis auf
  den Nachweis (Konzept 3.2, P18, R-84). Den Default von `measures.<m>.vat_rate` der PV-Maßnahme (`energy.pv.measure`)
  setzt die Ableitungsregel `rule:measure_catalog` (WS-A, 4.7) als `expr`-Knoten: 0, wenn `energy.pv.kwp` höchstens
  die Schwelle aus `bctx$legal("umsatzsteuer")` beträgt oder `energy.pv.vat_zero_rate_attested` gilt, sonst 0.19; ein
  ausdrücklicher Wert gewinnt (Warnung bei Widerspruch; R-86). Das Zeilenmetadatum `vat_rate` ist der Basisfallwert
  (`ctx$param_base()`). `vat_recoverable = TRUE` ist in v1 ein Validierungsfehler
  (Vorsteuer v2). Bei Gewerbeeinheiten bzw. Mischnutzung: `vofi_warning_plausibility` („Vorsteuerthematik nicht
  abgebildet“).

### 7.11 Nicht-Ertragsteuern (D6)

| Steuer | Abbildung | Typ / Kategorie | Tags |
|---|---|---|---|
| Grunderwerbsteuer | Satz je Bundesland aus `legal/grunderwerbsteuer` (Gültigkeit), Bemessung Kaufpreis bzw. Gegenleistung (Schalter `uniform_contract` bezieht die Bauleistung ein), Freigrenze 2.500 €, Zeitpunkt Erwerb | `acquisition_cost` (Regel `rule_grest`) | `is_tax = "grunderwerbsteuer"`, `tax_category = acquisition_ancillary`, `asset_id` |
| Grundsteuer | Jahresbetrag (direkt oder Messbetrag × Hebesatz) mit Fortschreibung; beim Vermieter umlagefähig, **kostenwirksam** nur im Leerstandsanteil, in der Bauphase und bei Selbstnutzung | `property_tax` | `is_tax = "grundsteuer"`; umgelegter Teil nur als Merkzeile `tenant_operating_cost` |
| Umsatzsteuer | Bestandteil der Bruttokosten | `vat_rate` je Zeile | `is_tax = "umsatzsteuer"` nur für reine USt-Zeilen (v2) |

### 7.12 Basistypen für Phase 0 und Orakel (verbindliche Parameter)

Diese drei Zahlungstypen entstehen in Phase 0 (Integrator, im Auftrag von WS-E) und werden von Walking Skeleton,
Orakeln und Referenzszenarien benutzt. Ihre Parameter sind Teil dieses Vertrags.

| Typ | Art / Block | Parameter (Art, Default) | Zeilen |
|---|---|---|---|
| `equity` | flow, im Block `financing` | `amount_eur` (amount, 0; einmalige Einlage), `date` (timing, `valuation_date`), `contributions` (schedule, Beträge ≥ 0), `contributions_pa` (value, Jahresbetrag, 0), `withdrawals` (schedule, Beträge ≥ 0), `withdrawals_pa` (value, 0), `from`/`to` (timing, `valuation_date`/`end_date`; nur für `*_pa`) | `in` (equity/`equity_in`), `out` (equity/`equity_out`, negativ gebucht) |
| `custom_series` | flow | `values` (value, Shape path: **Periodenbeträge ohne Δ-Skalierung**, Pflicht), `section` (enum `project`/`grants`/`memo`, `project`), `category` (Kategorie des Abschnitts, `custom`), `tax_category` (nicht `principal`), `cash` (in `memo` stets `FALSE`), `kind`, `unit` (Defaults der Kategorie) | `value` |
| `recurring` | flow | `amount_eur` (amount ≥ 0, Shape scalar, Jahresbetrag in Preisen von `base_date`, Pflicht), `growth` (value, 0), `base_date` (timing, Preisstand nach `project.price_base_year`), `from` (timing, Token `completion`), `to` (timing, `end_date`), `category` (Kategorie der Abschnitte `project`/`grants`, `other_cost`), `direction` (enum `inflow`/`outflow`, nur bei ±-Kategorien), `tax_category` | `value` = ± `amount_eur` · `index_year(growth, base_date)` · Δ_t · `shift_overlap(from, shift, to)` (Kalenderjahresindex, 3.6; Verschiebung, 3.9); `grid_invariant = TRUE` |

Wachstum wird bei `recurring` ausschließlich über `growth` angegeben (eine Wachstumsform in `amount_eur` ist ein
Validierungsfehler). Der Index ist innerhalb eines Kalenderjahres konstant (R-62); damit ist die Jahressumme auf jedem
kalenderjahrbündigen Raster identisch (F10), auch bei Wachstum ≠ 0. Beispiel Orakel (b): `amount_eur: 14000`,
`growth: 0.02`, `base_date: 2028-01-01`, `category: rent` ergibt 14.000 · 1,02^(t−1) für t = 1…10. Prüfwert F10
(`amount_eur: 14000`, `growth: 0.02`, `base_date` = Stichtag 2027-01-01, `from` = Stichtag): Jahressumme 2027 auf dem
Raster `annual` und auf dem Raster `mixed` jeweils 14.280,00 (eine Indexierung zum Periodenende ergäbe auf `mixed`
14.157,09). Ohne ausdrückliche Kategorie meldet die Validierung für `wu_*` einen Hinweis („Kategorie `other_cost`
angenommen“); `other_cost` ist NOI-relevant (7.6).

---

## 8. Instrumente als Zustandsautomaten; Konten und Ausgleichsaktionen

### 8.1 Grundsätze (MUSS)

1. Kredite sind Zustandsautomaten (`init`/`step`/`prepay`/`capacity`), die die Engine in der Periodenschleife für
   t = 0…T in der Reihenfolge des Blocks `financing` aufruft. Die drei eingebauten Typen `annuity_loan`,
   `installment_loan`, `bullet_loan` teilen sich den Kern `inst_loan_*` (`R/type-inst-loan-core.R`) mit
   `repayment ∈ {"annuity", "installment", "bullet"}`.
2. **Zeitparameter sind deterministisch** (`start`, Zahlungsplan-Termine, `term_years`, `grace_years`, `fixed_years`,
   `followup_fixed_years`, Termin des Tilgungszuschusses, `payments_per_year`) (R-47); sie sind mit
   `deterministic_only = TRUE` deklariert (5.4). Zinssätze, Anteile und `approved` dürfen stochastisch sein.
   Damit sind alle `if`-Abfragen im Automaten Abfragen auf Monate und Perioden.
   **Kreditbeträge haben keine Voraussicht (R-69, Konzept F15):** Nennbetrag und Auszahlungsplan werden im Basisfall
   bestimmt und gelten in allen Läufen (deterministisch, MC, Design); Instrumente lesen `amount_eur` und die Beträge
   von `draw_schedule` über `ctx$param_base()` (6.3). Laufspezifisch sind nur `approved` (Kredit bewilligt ja/nein)
   und die Nachfinanzierung `topup` (8.7). Mehrkosten eines Laufs deckt der Ausgleich bzw. `topup`.
3. **Referenzsemantik ist die Monatsuhr** (8.5): Zinsen werden monatlich mit i_nom / 12 auf den Monatsanfangsbestand
   berechnet; **Tilgungen** (Raten, Schlusstilgung) erfolgen in Vertragsfrequenz; **Zinsen gelten als in der
   Rasterperiode gezahlt, in der sie entstehen** (Bauzeit- und Zwischenzinsen werden je Rasterperiode fällig, Orakel
   (e)); alle Beträge einer Periode werden am Periodenende gebucht. Auf dem Jahresraster ist das ohne Wirkung; auf
   unterjährigen Bauphasenperioden zeigt die Zeile `loan_<k>_interest` daher auch bei `payments_per_year = 1` Zinsen je
   Periode. Eine Option „Zinsen mit der Rate“ ist v2.
   Eine Implementierung DARF schneller rechnen (z. B. geschlossen je Periode, wenn in der Periode keine unterjährigen
   Ereignisse liegen), MUSS aber bis 1e-9 relativ identische Ergebnisse liefern (Test gegen die Monatsuhr).
4. Kredite hängen nicht vom Ausgleich ab, außer über Ü3 (`loan_prepay`) am Periodenende; die Wirkung zeigt sich erst
   ab t+1. Die Rechnung bleibt nicht zirkulär (D3).

### 8.2 Parameter der Kredittypen (gemeinsam; Typ-spezifisch markiert)

| Parameter | `vofi_param`-Art | Default | Bedeutung |
|---|---|---|---|
| `amount_eur` | `amount`, `allow_auto`, `deterministic_only` | Pflicht | Nennbetrag (Zusage) D, fest in allen Läufen (Basisfallwert, 8.1 Nr. 2); `auto`/`topup` nach 8.7; bei `existing` die Restschuld zum Stichtag |
| `approved` | `value` (0/1) | `1` | Kredit bewilligt; Auszahlungen D_t × approved je Lauf (Förderkredite: Zusage × max der Aktivierungsfaktoren der geförderten Maßnahmen, 4.12 Nr. 7, R-71, R-99) |
| `existing` | `logical` | `FALSE` | **Bestandsdarlehen** (R-68): Bestand B_0 = `amount_eur` in t = 0 ohne Auszahlung (Merkzeile `assumed`), `start = valuation_date`, `term_years` = Restlaufzeit, `fixed_years` = Restzinsbindung; nicht zulässig mit `auto`/`topup`, `draw_schedule`, `fees`, `payout_rate` ≠ 1, `repayment_grant` (Validierungsfehler) |
| `installment_eur` | `amount` | `NULL` | vertragliche Rate je Vertragszahlung (Annuität: Zins + Tilgung; Ratentilgung: Tilgungsrate); ersetzt `set_installment` (8.6); vorgesehen für Bestandsdarlehen |
| `rank` | `integer` | `NULL` | Rang der Grundschuld (Anzeige, Beleihungsraum; keine Rechenwirkung in v1) |
| `start` | `timing` | `valuation_date` | Termin der ersten Auszahlung (Periodenende); `start: 2030` = 2030-01-01 |
| `draw_schedule` | `schedule` | `NULL` (voll bei `start`) | Teilauszahlungen `{schedule: {<datum/jahr>: <anteil>}, unit: share}` (Summe 1) oder `unit: eur` (Summe = Zusage, Validierung) |
| `rate_pa` | `rate` | Pflicht | nominaler Sollzins p. a. der ersten Zinsbindung (bei `topup` auch Pfad, 8.7) |
| `payments_per_year` | `integer` ∈ {1, 4, 12} | `12` | Vertragsfrequenz (Orakel verwenden 1) |
| `term_years` | `number` (Vielfaches von 1/12) | `NULL` | Laufzeit ab Ende der letzten Auszahlung inkl. tilgungsfreier Zeit; Pflicht für `installment_loan`, `bullet_loan`; bei `annuity_loan` Pflicht, wenn `initial_repayment_pa` fehlt |
| `grace_years` | `number` (Vielfaches von 1/12) | `0` | tilgungsfreie Anlaufzeit ab Ende der letzten Auszahlung |
| `initial_repayment_pa` | `rate` | `NULL` | nur `annuity_loan`: anfänglicher Tilgungssatz τ, Annuität A = Basis · (i + τ); zusammen mit `term_years` zulässig (τ bestimmt die Rate, `term_years` die Fälligkeit mit Schlusstilgung, Hinweis; 8.6, R-100); zusammen mit `installment_eur` ein Validierungsfehler |
| `fixed_years` | `number` | `NULL` (= bis Laufzeitende bzw. Horizont) | Zinsbindung ab `start` |
| `followup_rate_pa` | `value` (scalar/path) | `{ref: market.mortgage_rate}` | Anschlusszins (Beobachtung 8.6) |
| `followup_spread_pa` | `rate` | `0` | Aufschlag auf den Anschlusszins |
| `followup_fixed_years` | `number` | `NULL` (eine Anschlussbindung bis Laufzeitende) | weitere Zinsbindungen (wiederholte Anpassung) |
| `refi_rule` | `enum` `keep_term`, `keep_tilg_rate`, `keep_payment` | `keep_tilg_rate`, falls `initial_repayment_pa` gesetzt, sonst `keep_term` | Ratenbestimmung nach Zinsanpassung (Memo 01 §2.4 (7)), je Tilgungsart nach 8.6; bei `installment_loan` ist `keep_tilg_rate` ein Validierungsfehler, bei `bullet_loan` wird der Parameter ignoriert |
| `followup_repayment_pa` | `rate` | `= initial_repayment_pa` | τ' für `keep_tilg_rate` |
| `payout_rate` | `share` | `1` | Auszahlungskurs κ (Disagio = 1 − κ) |
| `fees` | `map` | alle 0 | `processing_fee_share` (Anteil der Zusage, fällig mit der ersten Auszahlung), `commitment_fee_rate_month` (z. B. 0.0015), `commitment_free_months` (z. B. 12), `commitment_date` (Default = `start`) |
| `repayment_grant` | `map` | `NULL` | `share` (Anteil der Zusage, bezogen auf min(Zusage, abgerufener Betrag), Konzept F15) **oder** `amount_eur` (value); `date`/`year` (Gutschrift am Periodenende, timing; Default: spätere von `completion_date` und Ende der letzten Auszahlungsperiode); `effect` ∈ `shorten_term` (Default), `reduce_installment` (R-07); `approved` (value 0/1, Default 1); `cut_share` (share, Default 0, stochastisch zulässig: Kürzung bzw. Rückforderung bei verfehltem Nachweis, Konzept B12) |
| `planned_prepayments` | `schedule` | `NULL` | geplante Sondertilgungen (immer möglich, D4) |
| `prepay_allowed` | `logical` | `FALSE` | darf von Ü3 sondergetilgt werden (KfW: `FALSE`) |
| `prepay_cap_share_pa` | `share` | `1` | Obergrenze je Vertragsjahr (Anteil der Zusage) für planmäßige und regelbasierte Sondertilgungen zusammen |
| `auto_buffer_share`, `auto_round_eur` | `share`, `amount` | `0`, `0` | nur bei `amount_eur: auto` bzw. `topup` (8.7) |
| `round_payments` | `logical` | `FALSE` | Raten auf Cent runden |
| `program`, `funding_id`, `measure_id`, `asset_id` | Metafelder (4.3.8), keine Typparameter | `NULL` | Tags; `repayment_grant` erfordert `measure_id` oder `funding_id` |

Alle Zeitparameter der Tabelle (`start`, Termine von `draw_schedule` und `planned_prepayments`, `term_years`,
`grace_years`, `fixed_years`, `followup_fixed_years`, `repayment_grant.date`/`year`, `payments_per_year`,
`fees.commitment_date`, `fees.commitment_free_months`) tragen `deterministic_only = TRUE`, ebenso `amount_eur` (R-69);
ein Overlay- oder Designziel auf einen Kreditbetrag ist damit ein Validierungsfehler. Zeigt `amount_eur` per Bezug auf
ein Overlay-Ziel (z. B. `funding.<id>.amount_eur`), folgt `vofi_warning_plausibility` („Kreditbetrag bleibt fest“).
Die Unsicherheit der Bewilligung läuft ausschließlich über `approved`.

### 8.3 Zustand

```r
state <- structure(list(
  # n-Vektoren
  B = num, drawn = num, commitment = num, i_pa = num,
  inst = num,            # Rate je Vertragszahlung: Annuität A_s bzw. Tilgungsrate R_s; NA bis zur Festlegung
  accrued = num,         # seit Tilgungsbeginn bzw. letzter Vertragszahlung aufgelaufene Zinsen
  tz_amount = num,       # Tilgungszuschuss vor Begrenzung (amount_eur bzw. share; × approved × (1 - cut_share))
  approved = num,        # Kredit bewilligt (0/1), laufspezifisch
  prepaid_ytd = num,     # Sondertilgungen im laufenden Vertragsjahr
  tau = num,             # Tilgungssatz für keep_tilg_rate
  neg_amort = lgl,       # Markierung keep_payment mit Rate <= Zins
  # deterministische Skalare und Pläne (Monate ab Stichtag; Monat m = (b0 + m-1 Monate, b0 + m Monate])
  repayment = chr, ppy = int, pay_interval = int,        # 12 / ppy
  t_first_draw = int,    # deterministisch: Periode des ersten Auszahlungstermins (auto: erste Fensterperiode, 8.7)
  m_start = int, m_A = int,                               # m_A = month_end der letzten Auszahlungsperiode
  m_rep = int,           # m_A + 12 * grace_years (Beginn der Tilgungsphase)
  m_mat = num,           # m_A + 12 * term_years oder Inf
  reset_months = int,    # Monate, nach denen der Zins angepasst wird
  fee_free_until = int,  # Monatsindex von commitment_date + commitment_free_months
  inst_set = lgl,        # Rate festgelegt (deterministisch, da Termine deterministisch)
  t_tz = int,            # Periode der Tilgungszuschuss-Gutschrift oder NA
  draws = matrix,        # n x (T+1) Nennbeträge der Auszahlungen
  planned = matrix,      # n x (T+1) geplante Sondertilgungen
  followup = matrix,     # n x (T+1) Anschlusszinspfad (ohne Spread)
  par = list()           # kappa, effect, refi_rule, spread, fee-Parameter, prepay-Parameter, tags
), class = "vofi_inst_state")
```

Vertragszahlungsmonate: `pay(m) = (m > m_rep) && ((m - m_rep) %% pay_interval == 0) && (m <= m_mat)`.
Restzahlungen `n_rem(m) = Anzahl der Vertragszahlungsmonate in (m, m_mat]` (deterministisch; `Inf` ohne Laufzeit).

### 8.4 Signaturen und Vorzeichen

```r
init(spec, ctx)                 # -> state
step(state, t, ctx)             # -> list(state,
                                #         flows  = list(draw = +κ·D, repay = -R, repay_balloon = -RB, prepay = -ST,
                                #                       interest = -Z, fees = -P),
                                #         memo   = list(repayment_grant = +TZ, disagio = +(1-κ)·D,
                                #                       assumed = +B_0 (nur t = 0 bei existing, sonst 0)),
                                #         stocks = list(balance = B))           # alle n-Vektoren
prepay(state, amount, t, ctx)   # -> list(state, used, flows = list(prepay = -used))
capacity(state, t, ctx)         # -> list(balance = B, rate_pa = i_pa, cap = pmin(cap_rest, B) * prepay_allowed)
```

Die Engine bucht `flows` in `loan_<k>_<name>` (Abschnitt `loans`, zahlungswirksam), `memo` in
`loan_<k>_repayment_grant`/`loan_<k>_disagio`/`loan_<k>_assumed` (`cash = FALSE`) und `stocks$balance` nach dem
Ausgleich in `loan_<k>_balance`. Ü3-Sondertilgungen landen ebenfalls in `loan_<k>_prepay`. Alle Zeilen eines
Bestandsdarlehens tragen `existing_debt = TRUE` (7.4).

### 8.5 Algorithmus `step()` (Referenzsemantik Monatsuhr, MUSS)

```text
step(state, t, ctx):
  Z <- R <- RB <- P <- 0                         # n-Vektoren
  für m in (M_{t-1}+1) .. M_t:                   # Monate der Periode t (t = 0: keine)
    (a) falls (m - 1) in reset_months:           # Zinsanpassung zu Monatsbeginn
          j* <- grid_period_of(Ende von Monat m-1) + 1;  i_pa <- followup[, j*] + spread
          falls inst_set: inst <- refi(B, i_pa, refi_rule)                       # 8.6
    (b) falls m == m_rep + 1: accrued <- 0       # Beginn der Tilgungsphase
    (c) z <- B * i_pa / 12;  Z <- Z + z;  accrued <- accrued + z
    (d) falls m > fee_free_until: P <- P + fee_rate_month * pmax(commitment * approved - drawn, 0)
    (e) falls pay(m):
          falls nicht inst_set: inst <- set_installment(state); inst_set <- TRUE   # 8.6
          r <- annuity:     pmin(pmax(inst - accrued, 0), B)
               installment: pmin(inst, B)
               bullet:      0
          B <- B - r;  R <- R + r;  accrued <- 0
    (f) falls m == m_mat: RB <- RB + B;  B <- 0  # Schlusstilgung des Restes
    (g) falls m Ende eines Vertragsjahres seit m_start: prepaid_ytd <- 0
  Ereignisse am Periodenende (Reihenfolge MUSS):
    (h) falls existing und t == 0: B <- commitment;  assumed <- commitment;  D <- 0   # Bestandsdarlehen, keine Gebühr
        sonst: D <- draws[, t+1] * approved;  falls t == t_first_draw:
                   P <- P + processing_fee_share * commitment * approved
        B <- B + D;  drawn <- drawn + D
    (i) ST <- pmin(planned[, t+1], B, pmax(cap_share * commitment - prepaid_ytd, 0))
        B <- B - ST;  prepaid_ytd <- prepaid_ytd + ST
    (j) falls t == t_tz: TZ <- pmin(tz_t, B);  B <- B - TZ
          mit tz_t = tz_amount bei amount_eur bzw. share * pmin(commitment, drawn) * approved_tz * (1 - cut_share)
          falls effect == "reduce_installment" und inst_set: inst <- recalc(B, i_pa)   # 8.6
        sonst TZ <- 0
  rückgabe flows/memo/stocks nach 8.4
```

### 8.6 Ratenbestimmung, Zinsanpassung, Tilgungszuschuss

Mit i_s = i_pa / ppy und n_s = (m_mat − m_rep) / pay_interval (Anzahl der Vertragszahlungen der Tilgungsphase):

| Fall | `set_installment` (erste Vertragszahlung der Tilgungsphase) |
|---|---|
| Basis | `basis = commitment * approved` bei `effect = shorten_term` oder ohne Tilgungszuschuss; `basis = B` (Bestand bei Tilgungsbeginn) bei `effect = reduce_installment` |
| vertragliche Rate | ist `installment_eur` gesetzt (Bestandsdarlehen): `inst = installment_eur` (keine Formel; Annuität: Zahlung, Ratentilgung: Tilgungsrate) |
| Annuität mit τ | `inst = basis * (i_pa + tau) / ppy`; ist zusätzlich `term_years` gesetzt, bestimmt τ die Rate und `term_years` nur `m_mat` (Schlusstilgung in (f), R-100) |
| Annuität mit Laufzeit | `inst = basis * i_s / (1 - (1 + i_s)^(-n_s))`; bei i_s = 0: `basis / n_s` (nur ohne τ) |
| Ratentilgung | `inst = basis / n_s` |
| endfällig | keine Rate; Tilgung nur in (f) |

| Regel | `refi(B, i', rule)` bei Zinsanpassung (nur wenn `inst_set`), **je Tilgungsart** |
|---|---|
| `keep_term`, Annuität | `inst = B * i'_s / (1 - (1 + i'_s)^(-n_rem))` mit n_rem = n_rem(m − 1); bei i'_s = 0: `B / n_rem`; erfordert endliche Laufzeit (Validierung) |
| `keep_term`, Ratentilgung | `inst = B / n_rem` (reine Tilgungsrate; ohne Sondertilgung und Tilgungszuschuss gleich der bisherigen Rate) |
| `keep_tilg_rate`, Annuität | `inst = B * (i' + tau') / ppy` mit τ' = `followup_repayment_pa` |
| `keep_tilg_rate`, Ratentilgung | nicht zulässig (Validierungsfehler) |
| `keep_payment`, Annuität | `inst` unverändert; `neg_amort <- neg_amort \| (inst <= B * i'_s)` → `vofi_warning_engine` |
| `keep_payment`, Ratentilgung | `inst` (Tilgungsrate) unverändert |
| endfällig | keine Rate; Zinsanpassung ändert nur `i_pa` |
| `recalc(B, i)` nach Tilgungszuschuss | Annuität mit Laufzeit: Formel `keep_term`; Annuität mit τ: `B * (i + tau) / ppy`; Ratentilgung: `B / n_rem` |

In Schritt (e) von 8.5 ist `inst` bei Ratentilgung stets die **reine Tilgungsrate** (Zinsen laufen getrennt über (c)).

**Restlaufzeit bei `keep_term` nach Laufzeitverkürzung (R-100):** Ist vor einer Zinsanpassung ein Tilgungszuschuss
mit `effect = shorten_term` gutgeschrieben (t_tz < t), gilt in `refi(…, keep_term)` statt n_rem(m − 1) die
**effektive Restzahl** n_eff = min(n_rem(m − 1), ⌈n* − 1e-9⌉) mit n* = Zahl der Vertragszahlungen, die die bisherige
Rate beim bisherigen Zins für den Bestand B braucht: Annuität n* = −log(1 − B · i_s / inst) / log(1 + i_s) (i_s = 0:
B / inst; inst ≤ B · i_s: n* = ∞), Ratentilgung n* = B / inst. Die Laufzeitverkürzung bleibt damit über die Anpassung
erhalten (elementweise über n, keine Verzweigung auf simulierte Werte). Ohne Tilgungszuschuss bzw. mit
`reduce_installment` bleibt n_rem(m − 1). Test (h) und die Orakel (a)–(f) sind nicht betroffen.

**Zinsanpassung (R-45):** Die erste Anpassung erfolgt nach `m_start + 12 * fixed_years` Monaten (`m_start` =
`month_end` der Periode von `start`), weitere alle `12 * followup_fixed_years` Monate. Der neue Zins ist der Wert des
Anschlusszinspfads in der Spalte der Periode, in der der Anpassungsmonat endet (bei Jahresraster: der Wert des Jahres
vor dem Anpassungstermin, Memo 04 §2.3), zuzüglich `followup_spread_pa`. Liegt die Anpassung vor Tilgungsbeginn, wird
nur `i_pa` geändert; die Rate entsteht später aus dem dann gültigen Zins. Fehlt `market.mortgage_rate` und liegt eine
Anpassung im Horizont, ist das ein Validierungsfehler.

**Tilgungszuschuss (Memo 01 E9, K7):** Gutschrift am Ende von `t_tz` nach planmäßiger Leistung, Auszahlung und
geplanter Sondertilgung, zahlungsunwirksam, höchstens bis zum Bestand; bei `share` bezogen auf den festen
Zusagebetrag, höchstens auf den bis `t_tz` abgerufenen Betrag (Konzept F15). `shorten_term` lässt die Rate (auf Basis des
Nennbetrags) unverändert; `reduce_installment` berechnet sie neu (liegt `t_tz` in der tilgungsfreien Zeit, wirkt
die Neuberechnung über `basis = B` bei Tilgungsbeginn).

### 8.7 `amount_eur: auto` und `topup` (WS-D, `R/engine-auto.R`; R-69, Konzept F15)

Höchstens ein Instrument je Variante mit `auto` und höchstens eines mit `topup`; `draw_schedule` muss leer sein;
`start = valuation_date`; nicht mit `existing`. **`auto` hat keine Voraussicht:** Der Betrag wird **einmal** im
Basisfall-Vorlauf von `vofi_build()` bestimmt (9.1 Stufe 6a; n = 1, Schichten 0–5, 7, 8, Zusagen mit Basiswert) und
gilt als Zusage- bzw. Vertragsbetrag mit festem Auszahlungsplan in **allen** Läufen des Modells (deterministisch, MC,
Design-Läufe einschließlich Set „vorsichtig“). Nur ein neues Modell (Schicht 8, statisches Szenario-Set,
`vofi_solve(rebuild = TRUE)`) bestimmt ihn neu. Bedarf (gemeinsam für `auto` und `topup`):

```text
W      <- Spalten j mit phase[j] == "construction" (inkl. t0); ohne Bauphase W <- {1}
c[, j] <- Σ exogene cash-Zeilen (project, grants, equity) in j
          + Σ_{k != auto, topup} payout_rate_k * approved_k * draws_k[, j]  (+ bei topup: payout_rate_auto * draws_auto[, j])
need   <- pmax(laufendes Maximum über j in W von (-cumsum(c[, W])), 0)          # Zeilen x |W|

auto (Basisfall-Vorlauf, eine Zeile):
  need_b <- need;  cash_j <- diff(c(0, need_b));  D_j <- cash_j * (1 + auto_buffer_share) / payout_rate
  commitment <- Σ_j D_j, aufgerundet auf ein Vielfaches von auto_round_eur (falls > 0);
                die Rundungsdifferenz wird der letzten Fensterperiode zugeschlagen
  model$base$auto <- list(commitment, draws = D (Länge T+1, außerhalb W null))
  model$base$need0 <- need des Basisfalls mit diesem festen auto-Plan (ohne auto-Instrument: need)
topup (je Chunk und Lauf, vor der Periodenschleife, Stufe 4 in 9.2):
  need_0 <- model$base$need0
  ex     <- laufendes Maximum über j in W von pmax(need[, j] - need_0[j], 0)        # Mehrbedarf ggü. Basisfall
  cash_j <- diff(c(0, ex));  D_j <- cash_j * (1 + auto_buffer_share) / payout_rate;  commitment <- Σ_j D_j (je Lauf)
beide:
  m_A    <- month_end der letzten Fensterperiode (deterministisch, auch wenn D dort 0 ist)
  t_first_draw <- t der ersten Fensterperiode (deterministisch); die Bearbeitungsgebühr
                  processing_fee_share * commitment fällt in dieser Periode an (8.5 (h))
```

`ctx$auto(id)` liefert `list(commitment, draws)` (bei `auto` aus `model$base$auto`, auf n Zeilen gehoben; bei
`topup` aus der privaten Engine-Umgebung des Chunks). Bauzeitzinsen und Gebühren sind nicht im Bedarf enthalten; sie
laufen über den Ausgleich. Kostenüberschreitungen, Verzug und nicht bewilligte Förderkredite oder Zuschüsse eines
Laufs ändern `auto` **nicht**; sie laufen über den Ausgleich bzw. über `topup`. Für `topup` darf `rate_pa` ein Pfad
sein (z. B. `{ref: market.mortgage_rate, offset: 0.01}`, „Zinspfad des Laufs plus Aufschlag“); maßgeblich ist sein
Wert in der letzten Fensterperiode. Im Basisfall ist der `topup`-Betrag null.

### 8.8 Konten (Geldanlage, Kontokorrent, Strafzinstranche)

`acc_init(model$accounts, ctx)` (WS-D, `R/engine-accounts.R`) liefert:

```r
acc <- list(
  G = numeric(n), KK = numeric(n), KKP = numeric(n),   # Bestände (vor Ausgleich in t: Stand Ende t-1)
  h    = n x (T+1),  # grid_rate_eff(deposit_rate_pa); Spalte 1 = 0
  h_pa = n x (T+1),  # deposit_rate_pa (effektiv p. a.) für den Ü3-Vergleich
  w    = numeric(1), # deposit_withholding_tax_share
  wa   = n x (T+1),  # Sparer-Pauschbetrag je Periode: deposit_tax_allowance_eur_pa * delta_t; Spalte 1 = 0 (R-76)
  s    = n x (T+1),  # grid_rate_eff(overdraft_rate_pa)
  sp   = n x (T+1),  # grid_rate_eff(overdraft_rate_pa + penalty_spread_pa)
  KL   = n x (T+1),  # overdraft_limit_eur (Inf zulässig)
  Lmin = n x (T+1),  # min_liquidity_eur
  flag_threshold = numeric(1), prepay_buffer = numeric(1), prepay_min_spread = numeric(1),
  j = integer(1)     # aktuelle Spalte, von der Engine vor dem Ausgleich gesetzt
)
```

Validierung: `s ≥ h` in allen Perioden, sonst `vofi_warning_engine` (Arbitrage, Memo 01 §3.1 Nr. 6); negative
Habenzinsen sind zulässig; die Abgeltungsteuer wirkt nur auf positive Habenzinsen oberhalb des Pauschbetrags:
WHT = w · pmax(HZ − wa, 0). `h_net` in `core$rates` (9.3) bleibt die Näherung h − w · pmax(h, 0) ohne Pauschbetrag.

**Sinkendes Limit:** `KL` darf ein fallender Pfad sein. Liegt der Stand KK (Ende t−1) über `KL[, j]`, wird der
Überhang zu Beginn des Ausgleichs zwangsweise getilgt und als zusätzliches Defizit durch die Defizitkette gedeckt
(9.3 Schritt (6a)); Markierung `limit_cut`.

### 8.9 Ausgleichsaktionen (`R/account-actions.R`, WS-D)

Alle Formeln elementweise über n; `a` = Eingangsbetrag (≥ 0), `j = acc$j`.

| Aktion | role / rank | Wirkung | geschriebene Zeilen | Flags |
|---|---|---|---|---|
| `od_repay` | surplus / U1 | `x1 = pmin(a, KKP)`, `KKP -= x1`; `x2 = pmin(a - x1, KK)`, `KK -= x2`; `used = x1 + x2` | `odp_repay = -x1`, `od_repay = -x2` | – |
| `dep_fill_reserve` | surplus / U2 | `x = pmin(a, pmax(Lmin[, j] - G, 0))`, `G += x` | `dep_invest = -x` | – |
| `loan_prepay` | surplus / U3 | nur t > 0; Kredite mit `prepay_allowed` je Lauf absteigend nach `i_pa` geordnet (Gleichstand: `financing`-Reihenfolge); berechtigt, wenn `i_pa > h_pa[, j] * (1 - w) + prepay_min_spread`; verfügbar `avail = pmax(a - pmax(Lmin[, j] + prepay_buffer - G, 0), 0)`; je Rang r = 1…K: `x_k = pmin(avail_rest * (rang_k == r) * berechtigt_k, capacity_k$cap)`, `prepay(state_k, x_k)` | `loan_<k>_prepay = -x_k` | – |
| `dep_invest` | surplus / U4, unbegrenzt | `G += a`, `used = a` | `dep_invest = -a` | – |
| `dep_withdraw` | deficit / D1 | `x = pmin(a, pmax(G - Lmin[, j], 0))`, `G -= x` | `dep_withdraw = +x` | – |
| `od_draw` | deficit / D2 | `x = pmin(a, pmax(KL[, j] - KK, 0))`, `KK += x` | `od_draw = +x` | `overdraft_threshold = (KK + KKP) > flag_threshold` |
| `dep_use_reserve` | deficit / D3 | `x = pmin(a, G)`, `G -= x` | `dep_withdraw = +x` | `reserve_used = x > zero_abs` |
| `equity_call` | deficit / D4, unbegrenzt | `used = a` | `equity_call = +a` | `shortfall = a > zero_abs` |
| `penalty_rate` | deficit / D4, unbegrenzt | `KKP += a`, `used = a` | `odp_draw = +a` | `shortfall`, `limit_breach` |
| `stop` | deficit / D4, unbegrenzt | `used = a` | `shortfall = +a` | `shortfall`, `stopped` |

Kettenregeln (Validierung, Verstoß = Validierungsfehler): jede Aktion höchstens einmal; `surplus_order` beginnt mit
`od_repay` und endet mit `dep_invest`; `deficit_order` beginnt mit `dep_withdraw` und endet mit genau einer
D4-Aktion; die Ränge sind innerhalb jeder Kette **streng aufsteigend** (U1 < U2 < U3 < U4, D1 < D2 < D3 < D4);
optionale Aktionen (`dep_fill_reserve`, `loan_prepay`, `od_draw`, `dep_use_reserve`) dürfen fehlen. Ü3 ist
standardmäßig aus und wird nur durch Aufnahme von `loan_prepay` in `surplus_order` aktiviert; dann einmal je Lauf
`vofi_warning_plausibility` mit Hinweis auf den Heuristik-Charakter (Memo 01 §3.2, R-29; Konzept F4, R-76). Aus den Kettenregeln folgt: Bei L_min = 0 gilt per
Konstruktion G · (KK + KKP) = 0 (I3b).

### 8.10 Vertragsfrequenz und Aggregation (Test (f))

Die Monatsuhr aggregiert Zinsen und Tilgungen der Vertragszahlungen einer Periode exakt; der Bestand am Periodenende
ist exakt. Prüfwerte (Memo 01 §10.7, Darlehen 100.000, 3,6 % nominal, monatliche Annuität, 240 Monate, Jahresraster):
Monatsrate 585,11; Zinsen Jahr 1 = 3.542,98; Tilgung Jahr 1 = 3.478,36; Restschuld Ende Jahr 1 = 96.521,64.

**Test (h) Ratendarlehen mit Zinsanpassung (WS-F, Pflicht; bis Runde 1 als „(g)“ bezeichnet, umbenannt wegen des
Vergleichsorakels (g), R-66):** `installment_loan` 120.000 €, `term_years: 10`,
`payments_per_year: 12`, `rate_pa: 0.02`, `fixed_years: 5`, `followup_rate_pa: 0.04`, `refi_rule` Default
(`keep_term`), Jahresraster ab 2027-01-01. Sollwerte: Tilgungsrate 1.000,00 €/Monat in allen 120 Monaten (auch nach
der Anpassung in Monat 61); Zinsen Jahr 1 = 2.290,00; Restschuld Ende Jahr 5 = 60.000,00; Zinsen Jahr 6 = 2.180,00;
Tilgung Jahr 6 = 12.000,00; Restschuld Ende Jahr 8 = 24.000,00; Restschuld Ende Jahr 10 = 0. Variante
`refi_rule: keep_tilg_rate` → Validierungsfehler.

---

## 9. Engine: Stufen, Periodenalgorithmus, Alternativen, Invarianten

### 9.1 Build-Stufen `vofi_build(x, variant = "base", overrides = NULL, scenario_set = NULL)`

```text
1  spec   <- vofi_resolve(x, variant, overrides, scenario_set)    # falls x ein vofi_scenario ist (WS-A)
2  report <- vofi_validate(spec); falls Fehler: vofi_abort("engine.validation_failed",
                                     .class = "vofi_error_validation", .data = list(report = report))
3  grid   <- vofi_time_grid(...) aus project + grid
4  nodes  <- flow-Komponenten (components + equity-Bausteine aus financing), Abhängigkeitsgraph aus
             ref-Parametern, {ref: components.<id>…}, after; topologische Sortierung (Kahn, Gleichstand
             alphabetisch nach id, method = "radix"); Zyklus -> vofi_error_validation mit Pfad
5  instruments <- instrument-Bausteine in financing-Reihenfolge; höchstens ein auto, höchstens ein topup
6  accounts, surplus_chain, deficit_chain <- normalisiert und geprüft (8.8, 8.9)
6a base   <- eng_base_run(model)       # Basisfall-Vorlauf (R-69, R-70): ctx im Modus "deterministic" (n = 1,
             Zusagen mit ihrem Wert nach Schichten 0–5, 7, 8, Entscheidungsknoten in V stets 1, 9.11 Nr. 2),
             eng_flows() in Topo-Reihenfolge, auto-Betrag (8.7);
             Ergebnis model$base = list(flows, auto, need0) (4.13); Grundlage von ctx$component_base() und ctx$auto()
7  sampler <- smp_plan(spec)                                       # 11.2 (WS-C)
8  tax    <- Konstruktor des Steuermoduls; Sperren nach perspective/tax_regime (10.2)
9  kpis   <- KPI-Definitionen nach analysis.kpis (Profil-Default), gefiltert nach perspectives/requires
9a decision <- falls die Variante einen Entscheidungsknoten hat (9.11): vofi_build(x, fallback_variant,
             overrides, scenario_set) -> model$decision$fallback; erfordert x als vofi_scenario
10 hash   <- stable_hash(spec)                                     # utils-hash.R
-> vofi_model (4.13)
```

### 9.2 Lauf-Stufen `vofi_run(model, n_sim = 1L, seed = NULL, store = …, chunk_size = …)`

```text
n_sim == 1  -> mode "deterministic", ein Chunk, store "full" (bei "auto")
n_sim  > 1  -> mode "mc"; seed <- seed %||% stochastic$settings$seed (fehlt beides: vofi_error_input);
               block_size <- settings$block_size (Default 200) bzw. n_sim / settings$replicates (11.4);
               Chunks = ganze Blöcke
für jeden Chunk:
  1 draws <- smp_draw(model$sampler, model$grid, blocks, seed, mode)       # WS-C; mit raw: smp_materialize()
  2 ctx   <- eng_context(model, draws)                                      # 6.1
  3 exo   <- eng_flows(model, ctx)            # flow-Komponenten in Topo-Reihenfolge -> exogener Ledger + Register;
                                              # + extra_rows (Differential-Modus, 9.6 Nr. 6)
  4 eng_auto_amounts(model, ctx, exo)         # 8.7: auto aus model$base (fest), topup je Lauf
  5 core  <- eng_balance(model, ctx, exo)     # 9.3 inkl. Instrument-Cache und Terminalzustand ohne Restwert (9.4)
  6 core$opp <- eng_opportunity(model, ctx, core)                           # 9.5
  7 eng_checks(core)                          # 9.7
  8 kpi   <- kpi_compute(model$kpis[kpis], core, ctx)                       # 12; nur angeforderte Kennzahlen
  9 eng_store(acc_store, core, kpi, draws, store)                           # 9.9
Chunks zusammenführen; bei MC: Bänder, Statistik, keep_runs (vofi_sim) -> vofi_result bzw. vofi_mc_result
```

**Arbeitsteilung WS-D / WS-G:** WS-D liefert den Chunk-Lauf (Stufen 1–9) als interne Funktion

```r
eng_run_chunk(model, blocks, seed, mode = c("mc", "deterministic", "design"),
              store = c("full", "bands", "kpi"), design = NULL, bands = NULL,
              raw = NULL, extra_rows = NULL, return_paths = character(), kpis = NULL)
#  raw          : Rohziehungen aus smp_sample(<Vereinigungsplan>, blocks, seed) (CRN, 11.10); gesetzt ->
#                 draws <- smp_materialize(raw, model$sampler, model$grid) statt smp_draw()
#  extra_rows   : vofi_ledger mit n Zeilen (exogen, z. B. negierte project-/grants-Zeilen der Referenz, 9.6 Nr. 6)
#  return_paths : Namen von Pfaden je Lauf, die zurückgegeben werden, auch bei store = "kpi":
#                 "net_position", "opp_net_position", "wealth" (W_t, 12.2), "dep_balance", "od_balance",
#                 "equity_calls"
#  kpis         : NULL = alle Kennzahlen des Modells; sonst Teilmenge (Design-, Bisektions-, uniroot-Läufe)
# -> list(kpis = data.frame, kpi_na = data.frame, kpi_series = list(), flags = data.frame,
#         inputs = data.frame, features = data.frame, ledger = <vofi_ledger> | NULL,
#         decision = num[n] | NULL (Werte der Entscheidungsschlüssel, 9.11),
#         band_values = list(<row_key> = matrix(n, T + 1)), opp = list(BS, EW),
#         paths = list(<name> = matrix(n, T + 1)), registers = list(assets, measures),
#         draws = <vofi_draws> | NULL (nur store = "full"), checks = data.frame, draws_meta = list())
```

sowie `vofi_run()` für `n_sim = 1` und `vofi_sim()`. `vofi_run(n_sim > 1)` bildet `store = "auto"` auf `"bands"` ab
und delegiert an `vofi_mc(model, n_sim = n_sim, seed = seed, store = store, chunk_size = chunk_size)`; WS-G
implementiert in `vofi_mc()` die Chunk-Schleife über `eng_run_chunk()`, Bänder, Statistik (12.7), `keep_runs` und
`parallel`. In `vofi_mc()` ist `store = NULL` der Default; Auflösung: Argument, sonst `stochastic$settings$store`,
sonst `"bands"`.

### 9.3 Periodenalgorithmus `eng_balance(model, ctx, exo, extra_out = NULL, book = TRUE)` (MUSS)

`extra_out` ist eine optionale n × (T+1)-Matrix zusätzlicher Entnahmen (≤ 0), die nur das Entnahme-Äquivalent (12.8)
verwendet; sie wird als Zeile `extra_equity_out` (Abschnitt `equity`, Kategorie `equity_out`) geführt. Mit
`book = FALSE` (Wiederholungsläufe über `ctx$rebalance()`) bucht die Engine keine Ledger-Zeilen und liefert nur
`list(BS_T, NS, BS_T_ex_rv, RW_T)`.

**Instrument-Cache (MUSS, Leistung):** Enthält `surplus_chain` kein `loan_prepay`, hängen die Instrumentflüsse nicht
vom Ausgleich ab. Die Engine rechnet `init`/`step` dann je Kontext **einmal** (erster Aufruf von `eng_balance()` im
Chunk) und legt `inst_cache = list(<k> = list(flows = list(<name> = n × (T+1)), memo = list(…), balance = n × (T+1)))`
in der privaten Engine-Umgebung ab; alle Wiederholungsläufe (9.4, `ctx$rebalance()`) lesen den Cache. Mit
`loan_prepay` wird jedes Mal neu gerechnet. Ergebnisse mit und ohne Cache sind identisch (Test WS-D).

```text
acc <- acc_init(model$accounts, ctx)
ist <- falls Cache vorhanden: NULL, sonst lapply(instruments, init)
E   <- ledger_sum(exo, section = c("project", "grants", "equity"), cash = TRUE) (+ extra_out)   # n x (T+1)
tin <- falls model$tax$uses_inputs: tax_inputs(exo, ctx), sonst NULL                             # 10.4
tst <- tax_init(model$tax, model$tax_params, ctx$assets(), ctx$measures(), n)
rec <- rec_alloc(model, ctx)                                  # Engine-Zeilen 7.7 als Nullmatrizen
für j in 1..T+1  (t = j - 1):
  (1) F   <- E[, j]                                           # exogene Zahlungen der Periode
  (2) für jedes Instrument k (financing-Reihenfolge):
        r <- Cache-Spalte j bzw. step(ist[[k]], t, ctx); ist[[k]] <- r$state
        F <- F + r$flows$draw + r$flows$repay + r$flows$repay_balloon + r$flows$prepay
               + r$flows$interest + r$flows$fees
        buche r$flows, r$memo in Spalte j
  (3) HZ  <- acc$G   * acc$h[, j]                             # Zinsen auf Bestände Ende t-1 (D3)
      WHT <- acc$w   * pmax(HZ - acc$wa[, j], 0)              # Sparer-Pauschbetrag (8.8, R-76)
      KZ  <- acc$KK  * acc$s[, j]
      KZP <- acc$KKP * acc$sp[, j]
  (4) S   <- F + HZ - WHT - KZ - KZP                          # vorläufiger Saldo
  (5) rt  <- tax_step(model$tax, t, inputs = tax_slice(tin, j, Instrumentzeilen aus (2)),
                      interest = list(exo_soll = Σ_k -interest_k, exo_fees = Σ_k -fees_k,
                                      endo_soll = KZ + KZP, endo_haben = HZ, endo_wht = WHT),
                      state = tst, params = model$tax_params)
      tst <- rt$state;  S <- S - rt$payment;  tax[, j] <- -rt$payment;  buche rt$report als Merkzeilen
      falls j == T+1: sichere (acc, ist, S) als pre_T                # für 9.4
  (6a) Limitüberhang (sinkendes Limit, 8.8): excess <- pmax(acc$KK - acc$KL[, j], 0)
       acc$KK <- acc$KK - excess;  od_repay[, j] += -excess;  S <- S - excess
       Markierung limit_cut <- limit_cut | (excess > zero_abs)
  (6) acc$j <- j;  sur <- pmax(S, 0);  def <- pmax(-S, 0)
      für a in surplus_chain: r <- a$apply(acc, sur, t, ctx, ist); acc <- r$acc
                              falls r$inst: ist <- r$inst; sur <- sur - r$used; buche r$flows (additiv), r$flags
      für a in deficit_chain: r <- a$apply(acc, def, t, ctx, ist); acc <- r$acc
                              falls r$inst: ist <- r$inst; def <- def - r$used; buche r$flows (additiv), r$flags
      falls max(sur, def) > zero_abs: vofi_error_engine
  (7) dep_interest[, j] <- HZ;  dep_wht[, j] <- -WHT;  od_interest[, j] <- -KZ;  odp_interest[, j] <- -KZP
      dep_balance[, j] <- acc$G;  od_balance[, j] <- acc$KK;  odp_balance[, j] <- acc$KKP
      loan_<k>_balance[, j] <- r$stocks$balance aus (2) minus Ü3-Sondertilgung der Periode
                               (Typen mit capacity(): capacity(ist[[k]], t, ctx)$balance)
nach der Schleife:
  fin <- tax_finalize(model$tax, ctx$T, tst, terminal_inputs, model$tax_params)
  tax_liability[, T+1] <- fin$payment_T;  buche fin$report als Merkzeilen
  equity_in_kind[, 1]  <- value_base("building.existing_value_eur") − Σ_{k existing} loan_<k>_assumed[, 1]
                          (nur falls der Bestandswert gesetzt ist; Merkzeile, nicht zahlungswirksam, R-68)
  net_position  <- dep_balance - od_balance - odp_balance - Σ_k loan_<k>_balance - tax_liability
  balance_check <- Σ aller cash-Zeilen der Abschnitte project … tax
  terminal_ex_rv <- 9.4
  core <- list(ledger, stocks, terminal_ex_rv, flags (9.8), rates = list(h, h_net = h - w*pmax(h,0), s, sp),
               grid = ctx$grid, n = ctx$n, opp = NULL, view = "with_rv")
```

Eigenschaften: In t = 0 entstehen keine Kontozinsen (Bestände 0, Δ_0 = 0) und keine Kreditzinsen (keine Monate).
Der Steuer-Hook läuft in **jeder** Periode inkl. t = 0 (R-21), auch mit `tax_none`. `E` enthält nur die Abschnitte
`project`, `grants` und `equity`; zahlungswirksame Zeilen anderer Abschnitte kann ein Flow nicht erzeugen (F4).

### 9.4 Terminalzustand ohne Restwert (MUSS)

`RW_T = Σ` der Zeilen mit Kategorie `residual_value` und `sale_cost` in Spalte T+1; `NS_T` = Summe der Zeilen
`equity_call` und `shortfall` des Basislaufs in Spalte T+1. Die Engine wiederholt die Schritte (6a) und (6) der
Periode T ab `pre_T` mit dem Saldo `S' = S_T − RW_T + NS_T` nach folgenden Regeln (R-61):

1. Vermögensneutrale Aktionen (Ü1–Ü4, D1–D3, `penalty_rate`) laufen wie konfiguriert.
2. Eine D4-Aktion mit **Zufluss von außen** (`equity_call`, `stop`) wird nicht ausgeführt. Der danach verbleibende
   Fehlbetrag wird intern und unbegrenzt in die Strafzinstranche gebucht (`KKP += Rest`; keine Zinswirkung mehr, da T
   der Horizont ist).
3. Damit sind Einlagen und Nachschüsse beider Sichten identisch, und es gilt **per Konstruktion**
   BS_T,exRV = BS_T − RW_T (N2, Toleranz I1).

Gespeichert wird `core$terminal_ex_rv = list(G, KK, KKP, B_total, BS, rv = RW_T, gap)` (n-Vektoren); `gap` ist der
nach Nr. 2 intern gebuchte Betrag (Finanzierungslücke ohne Restwert, ≥ 0). Die Steuerzahlung von T wird unverändert
übernommen (dokumentierte Vereinfachung, wirkt nur bei aktivem Steuermodul).

**Prüffall (Pflicht, WS-T, `test-invariants.R`):** T = 1, Privatprofil (`overdraft_limit_eur: 0`,
`deficit_order: [dep_withdraw, od_draw, equity_call]`), h = s = 0; EK 100.000 und Investition −100.000 in t = 0;
t = 1: Kosten −5.000, Restwert +90.000. Soll: BS_T = 85.000; BS_T,exRV = −5.000; `gap` = 5.000; Nachschüsse in beiden
Sichten 0; N2 erfüllt. Dasselbe Szenario mit `overdraft_limit_eur: .inf` ergibt BS_T,exRV = −5.000 und `gap` = 0.

### 9.5 Unterlassungsalternative `eng_opportunity()` / `vofi_opportunity()` (MUSS)

1. **Exogene Zeilen:** alle Zeilen des Abschnitts `equity` des Investitionslaufs: geplante `equity_in`/`equity_out`
   unverändert, `equity_call` und `shortfall` des Investitionslaufs als exogene Einlage `opp_equity_call_in`
   (Kategorie `equity_in`, Label „Nachschuss aus der Investition“) (Memo 01 K11).
2. **Keine** Projekt- und Förderzeilen, **keine** Instrumente; Ketten ohne `loan_prepay`.
3. **Identische Konten** (Raten, Limits, L_min, Abgeltung, Ketten) und **identisches Steuermodul** mit denselben
   Parametern (Memo 01 E11) (R-23).
4. **Dieselben Ziehungen**: derselbe `ctx` (stochastische Habenzinsen, CRN).
5. **Keine eigenen Nachschüsse (R-61):** Die Alternative erhält nie Zuflüsse von außen. Ist die D4-Aktion der Kette
   `equity_call` oder `stop`, läuft die Alternative mit `penalty_rate` (Tranche KKP, unbegrenzt), die dann zum
   **Regelzins** s verzinst wird (in der Alternative sp := s, d. h. kein Strafzinsaufschlag; die Haushaltsperspektive
   kennt keinen Strafzins, gleiche Kontokonditionen nach Konzept 2.6; R-81); ist sie `penalty_rate`, bleibt sie
   (Zins sp). Damit hat die Alternative exakt die Einlagen und Entnahmen der
   Investition (D9, Memo 01 §4.2: „Braucht U selbst KK, bleibt die Rangidentität erhalten“), ΔEW ist ein Vergleich bei
   gleichen Einlagen, und die R3-Rangidentität (15.4) gilt. Nutzt die Alternative KKP, setzt die Engine die
   Markierung `opp_limit_breach` und meldet einmal `vofi_warning_plausibility` („Unterlassungsalternative überzieht:
   die geplanten Entnahmen übersteigen das Vermögen ohne Investition“).
6. Lauf über `eng_balance()`; Ergebnis `core$opp = list(BS = n × (T+1), EW = n-Vektor, ledger = <bei store "full">)`.
7. **Sacheinlage und Bestandsdarlehen (R-68, Konzept 2.6):** Ist `building.existing_value_eur` = W_0 gesetzt, erhält
   die Alternative statt der Sacheinlage in t = 0 die exogene Zeile `opp_in_kind_sale` = W_0 · (1 −
   `residual_value.sale_cost_share`) − Σ_{k existing} B_0,k (Verkauf zum Stichtag nach Verkaufskosten und Ablösung der
   Bestandsdarlehen zum Nennwert, ohne Vorfälligkeitsentschädigung; Kategorie `equity_in`, bei negativem Wert
   `equity_out`; Basisfallwerte, in allen Läufen gleich). Bestandsdarlehen laufen in der Alternative nicht (keine
   Instrumente, Nr. 2). Ohne Bestandswert enthält die Alternative weder Sacheinlage noch Verkauf; ΔEW gegenüber der
   Unterlassung enthält dann die Bestandszahlungen und die Bestandsdarlehen (9.6 Nr. 7).

Ohne Entnahmen und ohne Kontokorrent gilt I6: EW_U = Σ_t EL_t · Π_{u>t}(1 + h_net,u) (mit Sacheinlage: EL_0 durch
`opp_in_kind_sale` ersetzt).

**Prüffall (Pflicht, WS-T):** T = 5, h = s = 0, `penalty_spread_pa: 0`, EK 10.000 in t = 0, Projekt −10.000 in
t = 0 und +5.000 je Jahr, Entnahmen 4.000 je Jahr, KL = 0, `equity_call`. Soll: EW = 5.000, keine Nachschüsse; EW_U = −10.000 (KKP), keine
Nachschüsse der Alternative; ΔEW = 15.000; `opp_limit_breach = TRUE`.

**Prüffall Sacheinlage (Pflicht, WS-T, R-68):** `project_type: sanierung_einzelmassnahmen`, T = 1, Jahresraster,
h = 2 %, s = 8 %, kein Bar-EK; `building.existing_value_eur: 500000`; Bestandsdarlehen `bullet_loan` mit
`existing: true`, `amount_eur: 200000`, `rate_pa: 0.03`, `term_years: 5`, `payments_per_year: 1`; t = 1: Miete
+30.000, Restwert 510.000, `sale_cost_share: 0.03` (RW_T = 494.700). Soll: t = 0 Sacheinlage `equity_in_kind` =
300.000, `loan_<k>_assumed` = 200.000, BS_0 = −200.000 (I2 erfüllt); t = 1 Zinsen −6.000, EW = 318.700,00;
`opp_in_kind_sale` = 285.000, EW_U = 290.700,00; ΔEW = 28.000,00; `roe_mirr` = 6,2333 % (318.700 / 300.000 − 1).
Dasselbe ohne `existing_value_eur`: EW = 318.700, EW_U = 0, `roe_*` NA mit Code `no_existing_value`.

### 9.6 Vergleich von Alternativen `vofi_compare()` (WS-G)

1. **Modelle:** je Variante (gekreuzt mit statischen `scenario_sets`) ein `vofi_model`, bei Entscheidungsknoten
   samt Modell der Ausweichvariante (9.11); generierte Sets („vorsichtig“) als Designzeile auf dem Modell der Variante
   und ihrer Referenz (4.11); Referenz = `baseline` bzw. `project.reference_variant`.
2. **Vergleichbarkeit** (Memo 01 §5.1, Konzept 2.6), geprüft im deterministischen Lauf: identischer Stichtag und
   identisches **Horizontende** (`valuation_date`, `end_date`; R-67); identische Kontenparameter und Ketten; identische
   geplante EK-Zeilen (`equity_in`/`equity_out`, Toleranz `oracle_abs`); identische Sacheinlage
   (`building.existing_value_eur`) und identische Bestandsdarlehen (alle `existing`-Bausteine mit gleichen Parametern;
   R-68); identische Restwertmethode; identisches Steuermodul. Verstoß → `vofi_error_validation`, außer
   `allow_unequal = TRUE` (dann Warnung und Befund im Ergebnis). **Nicht geprüft** werden die endogenen Nachschüsse
   (`equity_call`, `shortfall`): Ungleiche Nachschüsse sind **kein** Vergleichbarkeitsfehler; sie werden je Variante
   ausgewiesen (`sum_equity_calls`, `pv_equity_calls`) und durch die Vergleichsregel (Nr. 4) neutralisiert (Konzept
   F17, R-66). Eine abweichende Periodeneinteilung bei gleichem Horizontende (z. B. andere Bauzeit) ist zulässig
   (Nr. 9).
3. **CRN:** ein gemeinsamer Sampler-Plan über die Vereinigung aller Overlay-Schlüssel aller Varianten einschließlich
   ihrer Ausweichvarianten (9.11), ein Seed (11.10): je Chunk `raw <- smp_sample(smp_plan_union(plans), blocks, seed)`
   und je Variante `eng_run_chunk(model_A, blocks, seed, raw = raw, return_paths = c("net_position",
   "opp_net_position", "wealth"))`; die Pfade dienen `payback_vs_reference` (12.6).
4. **Vergleichsregel (R-27, R-66, Konzept F17):** Kennzahlen je Lauf: `delta_vs_reference = ΔEW_A − ΔEW_ref` (und
   `_ex_rv`), d. h. jede Variante gegen ihre **eigene** Unterlassungsalternative mit ihren **eigenen** Nachschüssen
   (9.5 Nr. 1). Ohne Nachschüsse gilt `delta_vs_reference` = EW_A − EW_ref; nutzt keine der beiden Alternativen
   Kontokorrent oder KKP und ist `deposit_tax_allowance_eur_pa` = 0, gilt `delta_vs_reference` = EW_A − EW_ref −
   Σ_t (NS^A_t − NS^ref_t) · q_T / q_t (Identität, Orakel (g)). Wahrscheinlichkeiten und Quantile werden **je Lauf auf Differenzen** gebildet, nie aus
   Quantilen der Einzelverteilungen.
5. **Differenz-VoFi** (nur Erklärung, deterministisch): zeilenweise Differenz der Grob-Tabellen (7.9) A − Referenz;
   nur bei identischem Raster (`months`), sonst `diff_table = NULL` mit Hinweis.
6. **Modus `differential`** (S, R-04): Die Variante erhält zusätzlich die negierten Zeilen der Abschnitte `project`
   und `grants` der Referenzvariante desselben Laufs (gleiche Rohziehungen) über `eng_run_chunk(…, extra_rows = …)`;
   Finanzierung und Konten der Variante bleiben; Ergebnis und Bericht tragen den Vermerk „Vereinfachungsmodus
   Differenzzahlungen“.
7. **Bestandsprojekte** (12.3a, R-68): Bei Bestandsprojekten (1.5) im Modus `absolute` enthält jede Variante die
   ohnehin anfallenden Bestandszahlungen (Mieten, Energie, CO2, Instandhaltung, Restwert des ganzen Gebäudes) und die
   Bestandsdarlehen, die Unterlassungsalternative nicht. Maßgeblich sind dann `delta_vs_reference`,
   `payback_vs_reference` und als Rendite `incremental_return` gegenüber der Bestands- bzw. Ohnehin-Variante
   (`project.reference_variant`, Pflicht nach 12.3a). ΔEW gegenüber der Unterlassung wird mit dem Vermerk „enthält
   Bestandszahlungen, nicht als Vorteilhaftigkeit lesbar“ ausgewiesen, mit Bestandswert mit dem Vermerk „gegenüber
   Verkauf zum Stichtag“ (9.5 Nr. 7).
8. **Entscheidungsknoten** (9.11): Varianten mit Knoten gehen als Kompositum (Zweig je Lauf) in den Vergleich ein;
   Differenzen, Wahrscheinlichkeiten und Ampel beziehen sich auf die Komposita, bedingte Ergebnisse stehen in
   `results[[v]]$decision` (13.1, 13.2).
9. **Pfadbasierte Vergleiche bei abweichendem Raster:** `payback_vs_reference` und die Fächer der Differenz werden
   auf den gemeinsamen Periodenenden `intersect(date_end_A, date_end_ref)` ausgewertet (Bestände sind Stichtagswerte);
   bei identischem Raster sind das alle Perioden. Jahresbezogene Vergleichskennzahlen (12.6) beziehen sich je Variante
   auf ihr erstes volles Betriebsjahr.

### 9.7 Laufzeit-Invarianten (immer aktiv, `eng_checks()`)

| Nr. | Prüfung (je Lauf und Periode) | Toleranz | Verstoß |
|---|---|---|---|
| I1 | `abs(balance_check) <= tol` | `balance_rel * max(1, Volumen)` | `vofi_error_engine` |
| I2 | ΔBS_t = Σ cash-Zeilen mit `tax_category != "principal"` + Σ `repayment_grant` − Σ `disagio` − Σ `assumed` − Δ`tax_liability` (BS_{−1} := 0; `assumed` nur in t = 0, R-68) | wie I1 | `vofi_error_engine` |
| I3a | G, KK, KKP, B_k ≥ −`stock_abs` | `stock_abs` | `vofi_error_engine` |
| I3b | falls L_min ≡ 0: `pmin(G, KK + KKP) <= stock_abs` (gilt wegen der verbindlichen Kettenregeln 8.9) | `stock_abs` | `vofi_error_engine` |
| I3c | KK ≤ KL + `stock_abs` (sinkendes Limit über Schritt (6a)) | `stock_abs` | `vofi_error_engine` |
| N1 | keine `NA`/`NaN`/`Inf` in Ledger-Matrizen | – | `vofi_error_contract` (mit Quelle der Zeile) |
| N2 | `BS_T,exRV == BS_T − RW_T` (per Konstruktion nach 9.4, auch bei `equity_call`/`stop`) | wie I1 | `vofi_error_engine` |

Die Fehlerdaten enthalten `invariant`, `sim`, `t`, `value` und die fünf betragsgrößten Zeilen der Periode.
`result$checks` (13.1) enthält je Prüfung die maximale Abweichung, die Toleranz und `ok`. I4–I6 sind Testinvarianten
(15.4).

### 9.8 Markierungen (`core$flags`, Data Frame mit n Zeilen)

| Spalte | Typ | Bedeutung |
|---|---|---|
| `reserve_used` | lgl | D3 in irgendeiner Periode |
| `shortfall` | lgl | D4 in irgendeiner Periode |
| `shortfall_sum` | num | Summe der D4-Beträge |
| `first_shortfall_t` | int | erste Periode mit D4 oder `NA` |
| `limit_breach` | lgl | KKP > 0 in irgendeiner Periode |
| `limit_cut` | lgl | sinkendes Limit hat in irgendeiner Periode eine Zwangstilgung ausgelöst (9.3 (6a)) |
| `opp_limit_breach` | lgl | Unterlassungsalternative nutzt die Strafzinstranche (9.5 Nr. 5) |
| `ex_rv_gap` | num | `terminal_ex_rv$gap` (9.4) |
| `overdraft_threshold` | lgl | KK + KKP > `overdraft_flag_threshold_eur` |
| `stopped` | lgl | Policy `stop` ausgelöst (Kennzahlen werden `NA` mit Code `run_stopped`) |
| `negative_amortization` | lgl | `keep_payment` mit Rate ≤ Zins |
| `equity_call_over_savings` | lgl | Nachschuss eines Betriebsjahres > 12 × `household.savings_capacity_month_eur` |
| `arbitrage` | lgl | h_pa > s_pa in irgendeiner Periode |

Je Markierungsart gibt ein Lauf höchstens **eine** zusammengefasste Warnung bzw. Meldung aus (Anteil der Läufe).

### 9.9 Speicherstrategie und Chunks (Memo 04 E10, Memo 05 §6.9)

| `store` | speichert | Standard für |
|---|---|---|
| `full` | vollständigen Ledger aller Läufe | N = 1 |
| `bands` | KPIs, KPI-NA-Gründe, Markierungen, statische Ziehungen, Pfadmerkmale aller Läufe; Fächerbänder der `bands`-Zeilen; vollständige `vofi_result` für `keep_runs` | MC |
| `kpi` | wie `bands`, ohne Bänder und `keep_runs` | große N |
| `auto` | `full` bei N = 1, sonst `bands` | – |

- `chunk_size` wird auf ein Vielfaches der Blockgröße abgerundet (mindestens ein Block). Chunks laufen sequenziell;
  `parallel = TRUE` (KANN, R-28) verteilt Chunks über `future.apply::future_lapply()` ohne eigene Zufallszahlen in den
  Workern; Ergebnisse sind identisch.
- Vor dem Lauf: Speicherschätzung `(Zeilen Investition + Zeilen Alternative + Steuer-Eingabezeilen) × chunk × (T+1)
  × 8 Byte × 3`; über `vofi.max_memory_gb` → `vofi_warning_memory` mit Vorschlag (kleinerer `chunk_size`). Mit dem
  Default `chunk_size = 2000` belegt ein Chunk mit 90 Zeilen und T+1 = 84 rund 120 MB Ledger; `tax_inputs` entfallen
  bei `tax_none` (`uses_inputs = FALSE`, 10.4).
- Bänder: Die n_sim × (T+1)-Matrizen der Bandzeilen werden über Chunks gesammelt; am Ende je Spalte
  `stats::quantile(x, band_probs, type = 7)` und Mittelwert; danach verworfen.
- `keep_runs` (`p05`, `p50`, `p95`, allgemein `p<zz>`): Lauf mit kleinstem |x_i − q_p(x)| für die KPI
  `keep_runs_kpi` (Gleichstand: kleinster Index); Neuberechnung mit `vofi_sim()`.

### 9.10 Leistungsbudget (Abnahme, `skip_on_cran()`)

| Vorgang | Ziel v1 |
|---|---|
| deterministischer Lauf bis 83 Perioden (ohne Einlesen), ohne Entnahme-Äquivalent | < 50 ms |
| Entnahme-Äquivalent zusätzlich (deterministisch, Instrument-Cache, 12.8) | < 100 ms |
| MC 10.000 × 53 Perioden inkl. KPIs, Unterlassung, Bänder | < 1,5 s |
| MC 10.000 × 83 Perioden | < 3 s |
| Vergleich 5 Varianten × 10.000 × 53 (CRN) | < 8 s |
| Tornado 20 Parameter × 2 (ein Design-Lauf, nur die angeforderte Kennzahl) | < 1 s |
| Spitzenspeicher MC 10.000 × 83, `bands` | < 1 GB |
| Variante mit Entscheidungsknoten (V und Ausweichvariante, 9.11) | ≤ 2 × Budget der Variante ohne Knoten |
| Set „vorsichtig“ (Tornado + ein Design-Lauf) bzw. `incremental_return` (zwei Design-Läufe à 41 Zeilen + Verfeinerung) | je < 1,5 s |

### 9.11 Entscheidungsknoten der Förderzusage (R-71, Konzept 3.9, B12, D8)

1. **Knoten:** Ein Förderinstrument f der Variante V ist ein Entscheidungsknoten, wenn `funding.<f>.approval_timing`
   `before_start` ergibt (4.3.7) und `funding.<f>.fallback_variant` = F gesetzt ist. v1: höchstens ein Knoten je
   Variante; F MUSS existieren, darf f nicht enthalten und selbst keinen Knoten haben (sonst
   `vofi_error_validation`); F darf die Referenzvariante sein. Bei `before_start` mit unsicherer Zusage ohne
   `fallback_variant`: einfache Ziehung (Nr. 6) und `vofi_warning_plausibility` („Ausweichvariante fehlt; der
   Ausgleich deckt die Förderlücke“).
2. **Modelle:** `vofi_build(x, V)` baut F mit (9.1 Stufe 9a, `model$decision`). Im Modell V wird
   `funding.<f>.approved` **stets mit 1** gerechnet („mit Zusage“), auch unter Szenario-Sets.
3. **Zweig:** Der Zusageschlüssel k = `funding.<f>.approved` hat die Rolle `decision` (11.6 Nr. 4): Er wird gezogen
   (Bernoulli, CRN), wirkt aber nicht auf sein Ziel. Zweig je Lauf b_i = Wert von k ∈ {0, 1}; im deterministischen Lauf
   b = Wert von k nach den Schichten 0–5, 7, 8 (Basiswert 1; unter dem Set `foerderstopp` 0); in Design-Läufen wählt eine
   Designspalte k den Zweig.
4. **Kompositum:** V und F laufen auf allen Läufen mit denselben Rohziehungen (Vereinigungsplan, 11.10). Je Lauf gilt
   für jede Kennzahl, jeden Rückgabepfad, jede Bandzeile und jede Markierung x_i = b_i · x^V_i + (1 − b_i) · x^F_i
   (zeilenweise Auswahl; V und F haben denselben KPI-Satz, sonst Validierungsfehler). `kpis` trägt die Spalte `branch`
   (1 = Zusage, 0 = Ausweichvariante). `vofi_sim(mc, i)` liefert das Ergebnis des realisierten Zweigs; `keep_runs`
   wählt auf dem Kompositum. Deterministisch ist das Ergebnis das des realisierten Zweigs; das des anderen Zweigs
   steht in `decision$alternative` (13.1).
5. **Bedingte Auswertung:** „mit Zusage“ = Statistik von V über alle Läufe, „ohne Zusage, dann Ausweichvariante“ =
   Statistik von F über alle Läufe (`decision$stats_approved`, `decision$stats_fallback`, 13.2). Das ist exakt, weil
   Entscheidungsschlüssel in keiner Korrelationsgruppe stehen dürfen (11.6 Nr. 4).
6. **Einfache Ziehung** (Instrumente ohne Knoten, z. B. spätere Stufen, Programmverfügbarkeit nach 2030): k hat die
   Rolle `value` und wirkt im selben Modell (R-55). `on_reject: balance` (Default): Förderbeträge × approved, die Lücke
   deckt der Ausgleich bzw. `topup` (8.7); `on_reject: drop_measures`: die geförderten Maßnahmen entfallen über den
   Aktivierungsfaktor a_m (4.12 Nr. 7). Rechtsregeln rechnen in beiden Fällen mit der je Lauf gewährten Förderung
   (§ 559 statt § 559e, kein Abzug nach § 559a, keine Kürzung nach § 558 Abs. 5; Konzept 3.5).
7. **Restrisiken nach Zusage** (Konzept B12): Kürzung bzw. Rückforderung des Tilgungszuschusses über
   `repayment_grant.cut_share` (8.2), Auszahlungsverzug über `funding.<id>.payout_delay_months` (3.9); Voreinstellung 0.

---

## 10. Steuer-Hook

### 10.1 Grundsätze (D5, Memo 06 §7)

1. v1 ist ein **Vor-Steuer-VoFi**. Der Hook ist trotzdem Pflicht: `tax_init`/`tax_step`/`tax_finalize` laufen in
   **jedem** Lauf (auch Unterlassungsalternative, Design-Läufe, MC) mit dem Standardmodul `tax_none`.
2. Die Zeile `tax` („Ertragsteuern“) ist immer sichtbar; bei `tax_none` trägt sie den Vermerk
   `core.rows.tax_note_none` („nicht berücksichtigt“) in Tabelle, Excel und Bericht.
3. Steuer in t hängt nur von Informationen bis einschließlich t ab (Zinsen auf Bestände t−1); keine Zirkularität.
4. Jede Ledger-Zeile trägt `tax_category`; Investitionen und Förderung tragen `asset_id`/`measure_id`; Anlagen- und
   Maßnahmenregister existieren ab v1 (7.2). Damit braucht ein späteres Modul kein Refactoring.

### 10.2 Modulobjekt und Registrierung

```r
typedef_tax_none <- function() vofi_type(
  name = "none", kind = "tax", params = list(), perspectives = NULL, blocked_regimes = NULL,
  uses_inputs = FALSE,
  constructor = function(params, spec) new_tax_module("none", params = params),
  example = list())
new_tax_module(name, params = list(), ...)   # intern (R/tax-hook.R):
# -> structure(list(name = name, params = params, ...), class = c(paste0("tax_", name), "vofi_tax_module"))
```

- `tax.module: <name>` im Szenario wählt den Registry-Eintrag `kind = "tax"`, `name = <name>`; die S3-Klasse ist
  `tax_<name>`.
- **Sperren:** `vofi_build()` prüft `perspective ∈ perspectives` (falls gesetzt) und `tax_regime ∉ blocked_regimes`;
  Verstoß → `vofi_error_validation` (`validation.tax_module_blocked`). `tax_flat` ist für `selbstnutzer`,
  `wu_eg_befreit` und `wu_gemeinnuetzig` gesperrt (Memo 06 §6.2).
- `vofi_register_tax_module(name, constructor, …)` (5.7) registriert Fremdmodule; sie liefern S3-Methoden für die
  drei Generics.
- `vofi_tax_module_simple(name, fun, label = NULL)` erzeugt ein Modul ohne Zustand, das **periodenweise** rechnet:
  `fun(inputs, params)` → n-Vektor `payment` der Periode, `inputs` wie in 10.4 (Periode t); `tax_step()` des Moduls
  ruft `fun` auf, `tax_init()` liefert `list()`, `tax_finalize()` liefert 0. Es sieht keine endogenen Zinsen
  (dokumentierte Grenze, nur für Experimente).

### 10.3 Generics (exportiert, `R/tax-hook.R`)

```r
tax_init(module, params, assets, measures, n_sim)           # -> state (Liste; Elemente n-Vektoren oder Skalare)
tax_step(module, t, inputs, interest, state, params)        # -> list(payment = n, state = <state>, report = list(<name> = n))
tax_finalize(module, T, state, terminal_inputs, params)     # -> list(payment_T = n, report = list(<name> = n))
```

Default-Methoden (`tax_init.default` usw.) werfen `vofi_error_registry` („keine Methode für Steuermodul …“).

### 10.4 Eingaben

```r
inputs <- list(                                   # tax_slice(tin, j, inst_rows)
  t = int, date_end = Date, delta = num, year = int, phase = chr,
  exo  = list(<ledger_key> = n-Vektor),           # Spalte j der exogenen Zeilen, ZEILENGENAU (keine Aggregation)
  inst = list(<ledger_key> = n-Vektor),           # Instrumentzeilen der Periode (interest, fees, disagio, repayment_grant)
  keys = data.frame(key, source = c("exo", "inst"), section, category, tax_category, asset_id, measure_id,
                    cash, extra = I(list()),     # extra: Felder aus row_extra_fields.yaml (spread_years,
                    stringsAsFactors = FALSE)    # use_share_rented, activity_type, tax_period, ...)
)
# Vorzeichen im Steuer-Input (MUSS): Ertrag/Zufluss +, Aufwand/Abfluss -. Merkzeilen mit Aufwandscharakter
# (Kategorie disagio, Ledger +) gehen NEGATIV ein; repayment_grant (Ledger +) positiv. Damit lassen sich
# Zeilen gleicher tax_category vorzeichenrichtig addieren.
interest <- list(exo_soll = n,      # Σ Sollzinsen der Kredite in t (positiv)
                 exo_fees = n,      # Σ Gebühren/Provisionen der Kredite in t (positiv)
                 endo_soll = n,     # KZ + KZP (positiv)
                 endo_haben = n,    # HZ brutto (mit Vorzeichen)
                 endo_wht = n)      # einbehaltene Abgeltungsteuer (positiv)
terminal_inputs <- list(exo_T = list(<key> = n), residual_value = n, market_value_T = n | NULL,
                        horizon_date = Date, assets = list(), measures = list())
```

`tax_inputs(exo, ctx)` (WS-D) stellt vor der Schleife die exogenen Zeilen (alle mit `tax_category !=
"not_applicable"`, auch `cash = FALSE`) zeilengenau als n × (T+1)-Matrizen mit Metadaten bereit (R-56);
Aggregationen (z. B. je `tax_category` und `asset_id`) bildet das Modul selbst. Bei Modulen mit
`uses_inputs = FALSE` (z. B. `tax_none`) entfällt der Aufruf, `inputs$exo` und `inputs$inst` sind leere Listen.

### 10.5 Rückgaben und Buchung

| Rückgabe | Buchung durch die Engine |
|---|---|
| `payment` (n) | Zeile `tax` in Spalte j = `-payment` (Zahlung positiv, Erstattung negativ, R-22); verringert S vor dem Ausgleich |
| `report` (benannte n-Vektoren) | Merkzeilen `tax_report_<name>` (Abschnitt `memo`, Kategorie `tax_report`, `cash = FALSE`, Label `types.tax.<modul>.report.<name>` aus der Labeldatei des Moduls) |
| `state` | wird an den nächsten `tax_step()` übergeben; MUSS vektorisiert über n sein |
| `payment_T` (n) | Bestand `tax_liability` in Spalte T+1 (positiv = am Horizont offene Steuerschuld, mindert EW; negativ = Forderung) |

Ein Veranlagungs-Lag (`lag = 1`) ist Sache des Modulzustands; die am Horizont offene Steuer gehört in `payment_T`
(Memo 06 §7.11).

### 10.6 `tax_none` (WS-D, Pflicht)

`uses_inputs = FALSE`; `tax_init` → `list()`; `tax_step` → `list(payment = numeric(n), state = state, report = list())`;
`tax_finalize` → `list(payment_T = numeric(n), report = list())`. Der Vertragstest T1 verlangt, dass ein Lauf mit
`tax_none` bitgleich zu einem Lauf ohne Hook-Aufruf ist.

### 10.7 `tax_flat` (L, WS-X, optional spät in v1, Standard aus)

Spezifikation nach Memo 06 §6.2: steuerliches Ergebnis E_t = steuerpflichtige Einnahmen − abziehbare Aufwendungen −
Erhaltungsaufwand (sofort oder § 82b) − AfA (linear bzw. degressiv je Anlage, Bemessung aus `capex_depreciable` +
`acquisition_ancillary` − `subsidy_*` derselben `asset_id`) − Sollzinsen (`exo_soll + exo_fees + endo_soll`)
[+ Habenzinsen nur bei Unternehmen]; Satz s_t als Zeitreihe (`inst/params/steuern_DE.yaml`); Verlustmodus `sofort`
oder `vortrag`; `lag` ∈ {0, 1}; private Habenzinsen getrennt mit Abgeltungssatz. Ist `tax.module = "flat"` und
zugleich `accounts.deposit_withholding_tax_share > 0`, ist das ein Validierungsfehler (Doppelbesteuerung). Label
„vereinfachte Näherung – keine Steuerberatung“. Pflichttests 10.10.

### 10.8 Vokabular `tax_category` (`inst/vocab/tax_categories.yaml`, Memo 06 §7.2)

| Code | Bedeutung | erzeugt von |
|---|---|---|
| `income_rental` | Kaltmiete, Umlage, Mietausfall | `rent_path` (Zeilen `rent`, `rent_loss`, `levy_*`) |
| `income_other_taxable` | sonstige steuerpflichtige Erlöse (`activity_type` für Kürzungsquoten) | `operating_income`, `other_income` |
| `income_tax_exempt` | steuerfrei (PV § 3 Nr. 72 EStG) | `pv` |
| `imputed_benefit` | ersparte Miete, Energieeinsparung (nicht steuerbar) | `imputed_rent`, `energy_saving` |
| `passthrough` | Betriebskosten-Umlagen (Saldo 0) | `operating_cost`, `passthrough` |
| `expense_deductible` | abziehbare Aufwendungen (Verwaltung, Instandhaltung, nicht umgelegte BK, Grundsteuer bei Leerstand) | Bewirtschaftungstypen |
| `expense_nondeductible` | nicht abziehbar (Selbstnutzer, privat) | Bewirtschaftungstypen bei Selbstnutzung |
| `capex_depreciable` | HK/AK abschreibbar (mit `asset_id`) | `capex`, `replacement` |
| `capex_land` | Grund und Boden | `land` |
| `capex_expensable` | Erhaltungsaufwand (mit `measure_id`, `spread_years`) | `capex` mit `classification = erhaltung` |
| `acquisition_ancillary` | GrESt, Notar, Grundbuch, Makler (Aufteilung Boden/Gebäude) | `acquisition_cost` |
| `subsidy_investment` | Investitionszuschuss | `grant` |
| `subsidy_repayment_grant` | Tilgungszuschuss (unbar) | Instrument-Merkzeile |
| `subsidy_operating` | laufende Zuschüsse | `operating_subsidy` |
| `interest_expense` | Sollzinsen, Gebühren, Disagio | Instrumente, Kontokorrent |
| `interest_income` | Habenzinsen | Geldanlage |
| `principal` | Darlehensauszahlung, Tilgung, Anlage/Auflösung | Instrumente, Konten |
| `equity` | Einlage, Entnahme, Nachschuss | Eigenkapital |
| `disposal_proceeds` | Restwert, Veräußerungserlös, Verkaufskosten | `residual_value` |
| `tax_credit` | Steuerermäßigung als Zahlung (§ 35c) – **Förderinstrument, nicht Steuermodul** (R-11) | `tax_credit_35c` |
| `tax_payment` | Steuerzahlungen (Slot `tax`, Abgeltungsteuer `dep_wht`) | Engine |
| `not_applicable` | Bestände, Prüfzeilen, Mengen, Merkposten, Lehrbuchzeilen `custom` | Engine, `custom` |

### 10.9 Abgrenzungen

| Thema | Abbildung in v1 | Grund |
|---|---|---|
| § 35c EStG | Förderinstrument (`instrument_type: tax_credit`) → Komponente `tax_credit_35c`: Tranchen 7 %/7 %/6 % der förderfähigen Aufwendungen in den drei Veranlagungsjahren ab Abschluss, je Jahr max. 14.000/14.000/12.000 €, gesamt max. 40.000 € je Objekt; die Energieberatung (§ 35c Abs. 1 S. 4, Anteil 0,50) zählt außerhalb des Jahresdeckels, aber innerhalb des Gesamtdeckels von 40.000 € je Objekt; **Zahlung** der Tranche des Veranlagungsjahres Y im Monat, der mit dem Zeitpunkt 31.12.Y + `payout_delay_months` endet, d. h. zum Termin `add_months((Y+1)-01-01, payout_delay_months)` nach 3.4 (R-98; Default 12 = Dezember Y+1, Termin (Y+2)-01-01; Default über `rule:tax_credit_defaults`, R-86); Ausschluss mit BEG/KfW für dieselbe Maßnahme (Validierungsfehler; Prüfung über die ganze `from:`-Kette und `program_code`, Spec 01 Teil B); **Deckel** je Veranlagungsjahr durch `household.expected_income_tax_eur_pa` (Tranche = min(Tranche, voraussichtliche tarifliche ESt); nicht nutzbare Beträge verfallen; `vofi_warning_plausibility`, wenn gedeckelt wird oder das Feld fehlt; ohne Feld keine Deckelung) (Konzept 3.9, L22, R-79) | D5 (R-11) |
| Abgeltungsteuer auf Habenzinsen | Kontoparameter `deposit_withholding_tax_share` (Default 0, R-40) und `deposit_tax_allowance_eur_pa` (Sparer-Pauschbetrag, Default 0, R-76), Zeile `dep_wht`; gilt auch in der Unterlassungsalternative; Pflichtsensitivität für Selbstnutzer und Kleinvermieter (Konzept B4, über `analysis.mandatory_sensitivities`) | D5 |
| Grunderwerbsteuer, Grundsteuer, USt | normale Kostenzeilen (7.10, 7.11) | D6 |
| Steuermodule und `tax_credit`-Zeilen | Module MÜSSEN `tax_credit`-Zeilen ignorieren (keine Doppelzählung) | – |

### 10.10 Pflichttests der Schnittstelle (Memo 06 §7.12)

**Ab Phase 1 mit Test-Steuermodul (R-78, Konzept 3.12, L9):** WS-D liefert in `tests/testthat/helper-tax-test-module.R`
ein über `vofi_register_tax_module()` registriertes Modul `test_flat` (Pauschalsatz s, lineare AfA je `asset_id`,
sofortiger Verlustausgleich, Parameter `lag`). Die Tests Nr. 2–4 und 6 laufen ab Welle 1 mit diesem Modul (WS-D) und
werden mit `tax_flat` wiederholt, sobald WS-X liefert.

1. `tax_none` ⇒ Ergebnis identisch mit einem Lauf ohne Hook (bitgleich).
2. Test-Modul bzw. `tax_flat` mit s = 0 ⇒ identisch mit dem Vor-Steuer-VoFi (WS-D; WS-X für `tax_flat`).
3. Standardmodell-Test: s konstant, sofortiger Verlustausgleich, `lag = 0`, Soll = Haben = i ⇒ Endwert nach
   Steuern = analytischer Wert mit Kalkulationszins i(1 − s) (WS-D mit Test-Modul; WS-X für `tax_flat`).
4. AfA-Summe über die Nutzungsdauer = Bemessungsgrundlage (WS-D mit Test-Modul; WS-X für `tax_flat`).
5. `tax_flat` lässt sich für `selbstnutzer` nicht aktivieren (WS-X).
6. Ergebnis invariant gegen die Chunk-Größe (WS-D mit Test-Modul).
7. „Steuerbereitschaft“: In S1–S5 hat jede zahlungswirksame Zeile eine `tax_category != not_applicable`; jede
   `capex_*`-, `acquisition_ancillary`- und `subsidy_*`-Zeile verweist auf ein vorhandenes Asset bzw. eine Maßnahme.

---

## 11. Sampler und stochastische Schnittstelle

### 11.1 Trennung

Zufallszahlen entstehen **ausschließlich** in `R/sampling-*.R`, `R/dist-*.R` und `R/process-*.R` (WS-C), und nur
innerhalb von `with_stream()`. Der Sampler-Plan entsteht in `vofi_build()`, die Ziehungen je Chunk in `vofi_run()`.
Typen sehen Ziehungen nur über `ctx$param()`/`ctx$market()` (bzw. ausnahmsweise `ctx$draw()`).

### 11.2 Plan `smp_plan(spec)` (WS-C)

```r
plan <- structure(list(
  settings  = list(n_sim, seed, sampling, block_size, replicates, antithetic, copula, start_year, store,
                   keep_runs, keep_runs_kpi, bands, band_probs, auto_funding_approval),
                   # block_size: Default 200; replicates: NULL oder Anzahl der Blöcke (Alternative, 11.4)
  static    = data.frame(key, target, dist, label, source,     # source: "overlay" | "inline" | "funding_auto" | "process_param"
                         role,                                 # "value" (wirkt auf target) | "decision" (Zweigwahl, 9.11)
                         apply,                                # "replace" | "multiply" | "add" (R-94; inline, funding_auto,
                                                               # process_param und decision: immer "replace")
                         stringsAsFactors = FALSE),
  static_par = list(<key> = list(...)),                        # Verteilungsparameter (Punktwerte)
  processes = list(<key> = list(target, type, par = list(), linked = list(), label, source)),
  proc_order = character(),                                    # Topo-Reihenfolge (linked_ar1 nach Basisprozess)
  correlations = list(parameters = matrix | NULL,              # Spearman, dimnames = keys
                      shocks = matrix | NULL),                 # Schockkorrelation, dimnames = process keys
  hash = chr
), class = "smp_plan")
```

Schlüssel: Overlay-Namen (`parameters`, `processes`); verschobene Kurzformen: Zielpfad (z. B.
`measures.huelle.cost_eur`); unsichere Prozessparameter: `<prozess>.<parameter>` (z. B. `inflation.mu`);
automatische Förderzusage: `funding.<id>.approved` (11.6.4). **Ziele** sind Pfade nach der Pfad-Identität (4.13):
Komponentenparameter als `components.<id>.<param>` bzw. `financing.<id>.<param>` (flach, ohne `params`), Felder von
`map`-Parametern als `financing.<id>.<param>.<feld>`, Hilfswerte unter `shared.<name>` (z. B. Stützstellen, 4.5
Regel 4). `static` und `processes` sind nach Schlüssel mit `method = "radix"` sortiert (2.7 Nr. 8).

### 11.3 Ströme und Seeds (MUSS)

```r
stream_hash <- function(name) {             # Polynom-Hash, exakt in double
  h <- 0
  for (code in utf8ToInt(name)) h <- (h * 131 + code) %% 2147483647
  h
}
stream_seed <- function(seed, name) (seed * 1000003 + stream_hash(name)) %% 2147483647
with_stream(seed, name, expr)   # set.seed(stream_seed(seed, name), kind = "Mersenne-Twister",
                                #          normal.kind = "Inversion", sample.kind = "Rejection");
                                # stellt .Random.seed und RNGkind() des Nutzers danach wieder her
```

| Strom | Inhalt |
|---|---|
| `par:<key>:<b>` | Uniforms der statischen Größe `key` in Block b |
| `shock:<proc>:<b>` | Standardnormal-Schocks des Prozesses in Block b |
| `scen:<proc>:<b>` | Uniform für den Szenarioindex (`scenario_mix`) |
| `uni:<proc>:<b>` | weitere Uniforms eines Prozesses (`n_uniforms > 1`) |
| `ic:<key>:<b>` | Permutation der Iman-Conover-Scores der Spalte `key` in Block b (je Schlüssel ein eigener Strom) |

`seed` ist eine ganze Zahl in [1, 2^31 − 2]. Kein anderer Code setzt Seeds.

### 11.4 Blöcke, Replikate, Chunks (D8, R-73; ersetzt R-14)

- **Feste Blockgröße:** `block_size` m (Default **200**) = Läufe je **Block**; ein Block ist ein unabhängiges
  LHS-Replikat (bzw. ein Pseudo-Block). Anzahl der Blöcke R = n_sim / m; n_sim MUSS ein Vielfaches von m sein (sonst
  `vofi_error_input` mit Vorschlag des nächsten Vielfachen). Mit den Defaults: Vorschau n_sim = 1.000 → R = 5,
  Standard 10.000 → R = 50, Tail-Kennzahlen 50.000 → R = 250.
- **Alternative Konzept F21:** Ist statt `block_size` `replicates` R gesetzt, gilt m = n_sim / R (n_sim MUSS durch R
  teilbar sein). Dann hängen alle Ziehungen von n_sim ab; `vofi_inform` weist darauf hin. Beide Angaben zugleich sind
  ein Validierungsfehler.
- Lauf i (global, 1…n_sim) gehört zu Block b = ⌈i / m⌉, lokaler Index i − (b − 1)m. Die Ziehungen von Lauf i hängen
  nur von Seed, Schlüssel, m und b ab, **nicht von n_sim**: Eine Erhöhung von n_sim um ganze Blöcke lässt alle
  bisherigen Läufe unverändert (die Vorschau mit 1.000 Läufen sind die ersten 1.000 Läufe des Standardlaufs).
- Iman-Conover und LHS wirken **je Block**. Der Standardfehler ergibt sich aus den R Blockmitteln (12.7); bei R < 10
  wird er als „grob“ gekennzeichnet (wenige Freiheitsgrade), bei R = 1 gilt die naive Formel mit Hinweis.
- Chunks bestehen aus ganzen Blöcken; Ergebnisse sind unabhängig von Chunk-Größe und Worker-Zahl.
- `vofi_sim(mc, i)` rechnet nur Block b neu und liefert Lauf i (identisch zum Batch).
- Eine Änderung von `block_size` (bzw. im F21-Modus von `n_sim` oder `replicates`) ändert alle Ziehungen
  (dokumentiert).
- **Mindestblockgröße:** Bei Iman-Conover MUSS m ≥ max(2, d + 1) gelten (d = Anzahl der Schlüssel der
  Korrelationsgruppe), sonst ist cor(S) singulär; Verstoß → `vofi_error_input` mit Vorschlag (größere Blockgröße).
  Mit m = 200 sind Gruppen bis d = 199 statische Schlüssel zulässig; praxisübliche Overlays haben 5–30 Schlüssel.
- **Abwägung (R-73):** Kleinere Blöcke schichten je Block feiner und kosten etwas LHS-Varianzreduktion (Prototyp
  Memo 04 §4.1, n = 1.000: Mittelwert ×14,8 mit einem Block gegenüber ×11,5 mit Blöcken zu 100 Läufen; Tail-Quantile
  praktisch unverändert); dafür ist jeder Lauf unabhängig von n_sim reproduzierbar, die Vorschau ein Präfix des
  Standardlaufs, `vofi_sim()` billig, und schon die Vorschau liefert R = 5 Replikate für den Standardfehler. Die
  Rangkorrelation je Block bleibt durch Iman-Conover erhalten (Abweichung der gepoolten Rangkorrelation ±0,02 bei
  n = 20.000, 15.6).

### 11.5 Erzeugung der Basiszahlen

| Größe | `sampling: lhs` (Default) | `sampling: pseudo` |
|---|---|---|
| statisch, je Block | `u <- (sample.int(m) - runif(m)) / m` (erst `sample.int`, dann `runif`) | `u <- runif(m)` |
| Schocks, je Block | Spalte für Spalte y = 1…Y−1: `qnorm((sample.int(m) - runif(m)) / m)` | Spalte für Spalte: `rnorm(m)` |
| Szenarioindex | eine Uniform je Lauf wie statisch | wie statisch |

- Spaltenweise Erzeugung garantiert: Mehr Jahre verändern die früheren Spalten nicht (CRN bei Varianten mit anderem
  Horizont).
- `antithetic: true` nur mit `pseudo` und geradem m: `v <- runif(m/2); u <- c(v, 1 - v)`; Schocks `rbind(w, -w)`.
  Mit `lhs` ist `antithetic` ein Validierungsfehler.

### 11.6 Abhängigkeiten

1. **Statische Größen:** Paare `[a, b, ρ_S]` → Spearman-Matrix der beteiligten Schlüssel; Pearson-Ziel
   ρ = 2 sin(π ρ_S / 6); Reparatur nicht positiv definiter Matrizen durch **Eigenwert-Clipping** (ε = 1e-6, danach
   Einheitsdiagonale); max. Abweichung > 0,05 → `vofi_warning_correlation`; reparierte Matrix in `meta`
   (R-38: kein `Matrix::nearPD`).
2. **Copula** `iman_conover` (Default): je Block auf der Uniform-Matrix der Gruppe, Spalten in **kanonischer
   Reihenfolge** `sort(keys, method = "radix")` (unabhängig von YAML-Reihenfolge und Gebietsschema): Scores
   a_i = Φ⁻¹(i/(m+1)), Score-Matrix mit unabhängig permutierten Spalten (je Spalte Strom `ic:<key>:<b>`,
   `sample(a)`),
   T = S Q⁻¹ P (cor(S) = QᵀQ, Ziel C = PᵀP), dann jede Uniform-Spalte nach den Rängen von T umsortieren
   (`ties.method = "first"`). Die Menge der Werte je Spalte bleibt exakt erhalten. Option `gaussian`:
   U' = Φ(Φ⁻¹(U) · chol(R)) je Block. t-Copula: v2 (R-39).
3. **Die Korrelation wird auf Uniform-Ebene induziert, die Quantilfunktion danach angewendet** (R-59). So nutzen
   Varianten mit verschiedenen Verteilungsparametern desselben Schlüssels dieselben Ränge (CRN).
4. **Förderzusage** (D8): Ist `stochastic.settings.auto_funding_approval = true` und hat ein Förderinstrument
   `approval_probability < 1` ohne Overlay-Eintrag auf `funding.<id>.approved`, erzeugt `smp_plan()` den Schlüssel
   `funding.<id>.approved` mit `dist: bernoulli, p = approval_probability` (R-55). Der deterministische Basiswert ist 1.
   `smp_plan()` liest dafür den Basisfallwert des abgeleiteten Felds `approval_probability` und den aufgelösten Code
   von `approval_timing` (4.3.7, R-86); eine eigene Ableitung im Sampler gibt es nicht.
   Ist das Instrument ein Entscheidungsknoten (9.11), erhält der Schlüssel (automatisch oder aus dem Overlay) die
   **Rolle `decision`**: Er wird wie jeder statische Schlüssel gezogen (Strom `par:<key>:<b>`, CRN), aber nur in
   `draws$decision` abgelegt und nicht auf sein Ziel angewendet (11.8). Entscheidungsschlüssel MÜSSEN 0/1-wertig sein
   und dürfen in keiner Korrelationsgruppe stehen (Validierungsfehler, R-71).
5. **Prozessschocks:** Korrelationsmatrix über Prozesse mit `n_shocks = 1` (Prozessschlüssel in kanonischer
   Reihenfolge `sort(…, method = "radix")`), Reparatur wie 1, Korrelation je Block über alle Jahresspalten mit einer
   Multiplikation `Z %*% chol(R)` (Memo 04 §3.5).
6. Unsichere Prozessparameter nehmen unter ihrem Schlüssel `<prozess>.<parameter>` an Parameterkorrelationen teil.
7. **Korrelationspaare mit fehlendem Schlüssel (R-96):** Paare aus Bibliotheksverweisen (`from:`), deren Schlüssel im
   Plan der Variante fehlt, verwirft `smp_plan()` mit `vofi_inform`; Paare aus der Szenariodatei, aus Varianten oder
   Sets mit unbekanntem Schlüssel sind ein Validierungsfehler. `smp_plan_union()` vereinigt die bereinigten Listen.

### 11.7 Prozesse in Kalenderjahren (R-15, R-58)

- `years = start_year : max(grid$year)` mit `start_year = settings$start_year %||% Jahr(valuation_date)`;
  Y = length(years). `simulate()` liefert n × Y; **Spalte 1 = Startwert** (`x0`, `r0`, `p0` bzw. Basispfad), Schocks
  wirken ab Spalte 2 (z hat Y − 1 Spalten).
- Abbildung auf das Raster: `paths[[key]] <- grid_map_years(grid, annual)` (Spalte j = Wert des Jahres `year[j]`).
  Prozesse mit `output = "rate"` liefern Jahresraten; Verbraucher rechnen über `ctx$rate_eff()`/`ctx$index()`.
- Prozesse zielen auf Pfade, deren Parameter `"path"` zulassen (in der Regel `market.<name>`); `target` MUSS im
  Schema existieren (R-16). Unsichere Stützstellen eines Pfads (z. B. CO2-Preis 2030/2040 als Dreiecksverteilungen,
  linear interpoliert, Memo 07 §4.0) werden nicht als Prozess, sondern als statische Overlay-Einträge auf
  `shared`-Blätter abgebildet, auf die die `points`-Elemente verweisen (4.5 Regel 4). Der deterministische Basiswert des Ziels MUSS vorhanden sein (sonst Validierungsfehler).

| Typ | Parameter | Definition (je Lauf, Jahr y ≥ 2) |
|---|---|---|
| `ar1` | `mu`, `phi`, `sigma`, `x0` (Default `mu`) | x_y = μ + φ(x_{y−1} − μ) + σ z_y |
| `linked_ar1` | `base` (Prozess), `a`, `b`, `phi`, `sigma`, `u0` (Default 0) | g_y = a + b · base_y + u_y; u_y = φ u_{y−1} + σ z_y; u_1 = u0 (R-95) |
| `vasicek` | `r0`, `theta`, `kappa`, `sigma`, `floor` (Default −Inf) | r_y = θ + (r_{y−1} − θ)e^{−κ} + σ√((1 − e^{−2κ})/(2κ)) z_y; Ausgabe `pmax(r, floor)` (Zustand ungekappt); `expected` = `pmax(θ + (r0 − θ) e^{−κ(y−1)}, floor)` (P2 gilt auch bei bindendem Floor, R-95) |
| `mr_trend` | `p0`, `growth`, `phi`, `sigma`, `p_norm` (Default `p0`) | P_y = p̄ (1 + g)^{y−1} exp(Y_y − v_y/2) mit p̄ = `p_norm`; Y_y = φY_{y−1} + σ z_y; v_y = φ² v_{y−1} + σ²; Y_1 = ln(p0/p̄), v_1 = 0; `expected` = p̄ (1 + g)^{y−1} (p0/p̄)^{φ^{y−1}} (Mean-Reversion vom Startniveau p0, z. B. 12-Monats-Mittel, zum Normalpreis p̄, Konzept B8; mit `p_norm = p0` die bisherige Formel; R-95) |
| `gbm` | `p0`, `growth`, `sigma` | ln P_y = ln P_{y−1} + ln(1 + g) − σ²/2 + σ z_y |
| `scenario_mix` | `scenarios: {<name>: {prob, years, values}}`, `noise: {phi, sigma}` | Szenario S je Lauf aus einer Uniform (Szenarien **alphabetisch** nach Name geordnet, `method = "radix"`, kumulierte Wahrscheinlichkeiten); X_y = x^{(S)}_y · exp(Y_y − v_y/2) mit AR(1)-Rauschen wie `mr_trend`; Attribut `scenario` |
| `iid` | `dist_spec` (Verteilung) | X_y = Q(Φ(z_y)); Spalte 1 = `point(dist_spec, "mean")` |
| `fixed_path` | `years`, `values` | deterministisch, lineare Interpolation; `n_shocks = 0` |

`bootstrap` und Regimewechsel sind v2 (R-39). Jeder numerische Prozessparameter darf eine Verteilung sein (S→P).

**Token `base` für Startparameter (R-95):** Die Startparameter `x0` (`ar1`), `u0` (`linked_ar1`), `r0` (`vasicek`),
`p0` und `p_norm` (`mr_trend`) sowie `p0` (`gbm`) dürfen das Token `base` tragen. `smp_plan()` setzt dafür den
Basisfallwert x_det des Ziels (`value_base`, Schichten 0–5, 7, 8, n = 1) in der ersten Rasterspalte j ≥ 2 mit
`year[j] == start_year` ein (T = 0: Spalte 1); `u0 = base` bedeutet u0 = x_det − a − b · base_1 (g_1 = x_det). Damit
startet jeder Prozess exakt am deterministischen Basisfall (Konzept F18). Bibliothekseinträge mit Token tragen im
Metadatenfeld `fallback` (4.9) dokumentierende Zahlenwerte; der Sampler verwendet sie nicht.

**Pfadmerkmale** (`draws$features`, für globale Sensitivität): je Prozess `<key>.mean` (Mittel über die Jahre der
Betriebsperioden), `<key>.end` (Wert in `year[T+1]`), `<key>.at<jahr>` (Werte an Zinsanpassungsterminen von Krediten,
die den Prozess über `followup_rate_pa` nutzen), `<key>.scenario` (bei `scenario_mix`).

### 11.8 Ziehungsobjekt `vofi_draws`

```r
smp_sample(plan, blocks, seed)                 # -> roh: korrelierte Uniforms u, korrelierte Schocks z, Szenario-Uniforms
smp_materialize(raw, plan, grid)               # -> vofi_draws: Quantilfunktionen, Prozesse, Abbildung aufs Raster
smp_draw(plan, grid, blocks, seed, mode = c("mc", "deterministic"))   # = smp_materialize(smp_sample(...)); deterministisch: leer
smp_design(plan, grid, design)                 # -> vofi_draws mode "design" (11.11)
smp_plan_union(plans)                          # WS-C: Liste von smp_plan -> smp_plan über die Vereinigung aller
                                               # Schlüssel (CRN, 11.10); gleicher Schlüssel mit anderem Ziel oder
                                               # statisch vs. Prozess -> vofi_error_validation; abweichende
                                               # Korrelationen -> vofi_warning_correlation

draws <- structure(list(
  mode = chr, n = int, sims = int, blocks = int, block_size = int,
  static = list(<key> = num[n]),               # nach Korrelation und Quantilfunktion (nur Rolle "value"); bei
                                               # apply multiply/add die Ziehung x (Faktor bzw. Zuschlag), nicht b*x
                                               # bzw. b+x (Verknüpfung in 6.3 Schritt 1, R-94)
  decision = list(<key> = num[n]),             # Entscheidungsschlüssel 0/1 (Rolle "decision", 9.11); sonst leer
  u = list(<key> = num[n]),                    # korrelierte Uniforms (Diagnose, CRN-Tests)
  targets = data.frame(key, target, kind,      # kind: "static" | "process" | "decision"
                       apply,                  # wie plan$static$apply; Prozesse: "replace"
                       stringsAsFactors = FALSE),
  annual = list(<proc> = matrix(n, Y)),
  paths = list(<proc> = matrix(n, T + 1)),
  years = int,
  scenario_index = list(<proc> = int[n]),
  features = data.frame(),                     # n Zeilen
  meta = list(seed, sampling, block_size, replicates, copula, antithetic,
              rng_kind = c("Mersenne-Twister", "Inversion", "Rejection"),
              repaired = list(parameters = NULL, shocks = NULL), plan_hash)
), class = "vofi_draws")
```

Zusicherungen: `length(static[[k]]) == n`; `dim(paths[[k]]) == c(n, T + 1)`; jedes `target` höchstens einmal
(statisch und Prozess auf dasselbe Ziel ist ein Validierungsfehler).

### 11.9 Deterministischer Lauf

`mode = "deterministic"`, n = 1, keine Schlüssel: Alle Werte kommen aus der deterministischen Spezifikation (Schichten
0–5, 7, 8), Kurzform-Verteilungen haben ihren Basiswert bereits am Zielpfad (4.5), Förderzusagen haben ihren
Basiswert (1; unter dem Set `foerderstopp` 0; Entscheidungsknoten nach 9.11 Nr. 3), Marktpfade
sind die Basiswerte aus `market` (R-17). Engine, Kontext und Kennzahlen laufen **unverändert** (D1, D8). Der
deterministische Wert entspricht im Allgemeinen nicht dem MC-Erwartungswert; Ausgaben weisen darauf hin.

### 11.10 Gemeinsame Zufallszahlen (CRN, Pflicht)

1. Gleicher Schlüssel = gleiche Ziehung (benannte Ströme); ein zusätzlicher unkorrelierter Schlüssel verschiebt
   keine anderen Ziehungen; die Reihenfolge im YAML, die Reihenfolge der Korrelationspaare und das Gebietsschema
   sind unerheblich (kanonische Ordnung, 11.6). Tritt ein Schlüssel einer Korrelationsgruppe hinzu, ändern sich die
   Ränge der Gruppe (unvermeidlich), nicht aber ihre Randverteilungen.
2. `vofi_compare()` und Szenario-Sets: **ein** Plan über die Vereinigung aller Overlay-Schlüssel aller Varianten
   (`smp_plan_union(plans)`, einschließlich der Pläne von Ausweichvarianten, 9.11), **ein** Seed, gleiche `n_sim` und
   gleiche Blockgröße; je Chunk einmal
   `raw <- smp_sample(union, blocks, seed)`, je Variante `smp_materialize(raw, plan_variante, grid)` über
   `eng_run_chunk(…, raw = raw)` (9.2). Weichen die Korrelationsangaben zwischen Varianten ab, folgt
   `vofi_warning_correlation` („CRN eingeschränkt“).
3. Die Unterlassungsalternative nutzt denselben `ctx` (gleiche Habenzinspfade).
4. Differenzen werden je Lauf gebildet. Test: zwei identische Varianten ergeben Differenz `identical(…, 0)` in jedem
   Lauf.

### 11.11 Design-Läufe (Tornado, Spider, Break-even)

`smp_design(plan, grid, design)` mit `design` = Data Frame, eine Zeile je Lauf, Spalten = Zielpfade (numerische
Blätter, z. B. `measures.huelle.cost_eur`, `market.mortgage_rate`), Overlay-Schlüssel statischer Einträge,
Prozessschlüssel `<proc>` oder Prozessparameter `<proc>.<param>`. Nicht genannte Ziele behalten ihren Basiswert.
Bedeutung der Spalten (R-94, R-95):

- **Zielpfad:** setzt den absoluten Wert des Ziels; eine Overlay-Bindung auf diesem Ziel entfällt in der Zeile.
- **Overlay-Schlüssel** eines statischen Eintrags: setzt dessen Ziehung x; die Verknüpfung nach `apply` (6.3
  Schritt 1) gilt wie in der MC (bei `multiply` ist x der Faktor, bei `add` der Zuschlag). Bei Kurzformen ist der
  Schlüssel der Zielpfad und `apply = replace`, beide Lesarten stimmen überein.
- **Prozessparameter** `<proc>.<param>`: erzeugt je Zeile den Pfad `expected(par_zeile, years)`.
- **Prozessschlüssel** `<proc>` mit Wert p ∈ (0, 1): setzt den Pfad `quantile_path(par, years, p)` (5.3); Prozesse
  ohne `quantile_path` sind keine Designspalten.
Zeile 1 ist der Basisfall. Ein Tornado mit k Parametern ist **ein** Lauf mit n = 1 + 2k Zeilen (Memo 04 §7.1). Werte
für `low`/`high`: Default P10/P90 der Overlay-Verteilung des Ziels, sonst Basis × (1 ∓ `delta`). Basisfallgrößen
(`auto`-Beträge, `ctx$param_base()`, `ctx$component_base()`) bleiben in Design-Läufen fest (R-69, R-70). Eine
Designspalte auf einen Entscheidungsschlüssel wählt den Zweig (9.11 Nr. 3). Kreditbeträge sind keine Designziele
(8.2). Das Set „vorsichtig“ ist eine Designzeile aus den ungünstigen Tornado-Werten (4.11, R-74).

### 11.12 RNG-Hygiene

Kein Code außer `with_stream()` verändert den RNG-Zustand; der globale Zustand des Nutzers ist nach jedem Aufruf
unverändert (Test). Das Paket setzt nie `future::plan()`. Worker erzeugen nur Ziehungen über benannte Ströme ihrer
Blöcke; Ergebnisse sind dadurch unabhängig von Worker-Zahl und Chunk-Größe.

---

## 12. Kennzahlen (KPI-Registry)

### 12.1 Signatur und Rückgabe

```r
typedef_kpi_<name> <- function() vofi_type(name = "<name>", kind = "kpi", compute = function(core, ctx) { ... },
  unit = "EUR", shape = "scalar", rv_variant = TRUE, higher_is_better = TRUE, mc_default = TRUE,
  perspectives = NULL, requires = character())

vofi_kpi_value(values, na_reason = NULL, years = NULL)
#  scalar: values num[n]; na_reason chr[n] (NA_character_, wo definiert)
#  series: values matrix n x P; years int[P] (Kalenderjahr bzw. Betriebsjahr-Label); na_reason chr[n]
#  Jeder NA-Wert MUSS einen Code aus inst/vocab/na_reasons.yaml tragen.

kpi_compute(kpis, core, ctx)   # -> list(scalar = data.frame(n Zeilen), na = data.frame(n Zeilen, chr),
                               #         series = list(<name> = list(values, years)))
core_ex_rv(core)               # Sicht ohne Restwert: BS[, T+1], G/KK/KKP in T aus terminal_ex_rv,
                               # Restwertzeilen in T+1 auf 0, view = "ex_rv"; Einlagen und Nachschüsse
                               # unverändert (9.4); Kennzahlen mit rv_variant = TRUE werden auf
                               # beiden Sichten berechnet: <name> und <name>_ex_rv
kpi_withdrawal_equivalent(core, ctx, tol = NULL, max_iter = 80L)   # R/kpi-withdrawal.R (WS-D2), 12.8
```

`core` (Eingabe): `ledger` (vollständig für den Chunk), `stocks` (`G`, `KK`, `KKP`, `B` (Liste je k), `BS`,
`tax_liability`), `terminal_ex_rv`, `flags`, `rates` (`h`, `h_net`, `s`, `sp`), `opp` (`BS`, `EW`), `grid`, `n`,
`view` (`"with_rv"` bzw. `"ex_rv"`). Wiederholte Ausgleichsläufe stehen Kennzahlen nur über `ctx$rebalance()` zur
Verfügung (6.2); `core` enthält weder Modell noch exogenen Ledger.
Ist `flags$stopped`, sind alle wertbasierten Kennzahlen des Laufs `NA` mit Code `run_stopped`.

### 12.2 Notation (je Lauf, n-Vektoren bzw. n × (T+1))

| Symbol | Definition |
|---|---|
| EL_t | `ledger_sum(section = "equity", category = c("equity_in", "equity_in_kind", "equity_call", "shortfall"))` (Sacheinlage in t = 0 eingeschlossen, R-68) |
| EN_t | `-ledger_sum(category = "equity_out")` (≥ 0) |
| NS_t | `equity_call + shortfall` |
| RW_T | Summe der Kategorien `residual_value`, `sale_cost` in Spalte T+1 |
| h_net,t | `rates$h_net[, j]`; q_t = Π_{u=1..t}(1 + h_net,u), q_0 = 1 |
| BS_t, BS^U_t | `stocks$BS`, `opp$BS`; EW = BS_T, EW_U = BS^U_T |
| NOI_t | Summe der zahlungswirksamen Zeilen der Kategorien mit `noi = TRUE` (7.6) |
| KD_t | `-ledger_sum(section = "loans", category = c("interest", "repay"))` (planmäßig: ohne `repay_balloon`, `prepay`, `fees`; R-46); **Objektebene**, alle Kredite inkl. Bestandsdarlehen |
| KD^ex_t, KD^new_t | wie KD_t, eingeschränkt auf `existing_debt = TRUE` bzw. `FALSE` (Bestandsdarlehen bzw. neue Kredite, R-77) |
| INT_t | `-ledger_sum(section = "loans", category = "interest")` |
| V_t | `ledger_sum(category = "market_value")` (Wertpfad der gewählten Restwertmethode, vor Verkaufskosten, 4.12 Nr. 8) |
| RWP_t | `ledger_sum(category = "residual_path", rv_basis = b)` mit b = `analysis.rv_path_basis` (`auto`: `measures` im Haushaltsmodus, sonst `method`); ohne solche Zeilen 0 (R-72) |
| W_t | Vermögen mit Restwertpfad: W_t = BS_t + RWP_t für t < T, W_T = BS_T (der Restwert steckt in T bereits in BS_T) |
| Betriebsjahre y | `P = sort(unique(op_year[op_year > 0]))`; Summen über Perioden mit `op_year == y`; Teil-Betriebsjahre (`op_year_full = FALSE`, 3.3) zählen mit; „erstes Betriebsjahr“ (`_y1`) = das erste **volle** Betriebsjahr, `_avg10` = Mittel der ersten min(10, \|P_voll\|) vollen Jahre |
| P_stab | Betriebsjahre y ∈ P, deren erste Periode im Kalenderjahr ≥ y_stab liegt; y_stab = `analysis.stabilization_year`, Default Kalenderjahr des ersten vollen Betriebsjahres (Stabilisierungsjahr, R-77) |
| FEES_t | `-ledger_sum(section = "loans", category = "fees")` |
| T_J | `tau[T + 1]` |

### 12.3 Kennzahlen v1

| Schlüssel | Einheit | rv | Formel | NA-Codes | MC-Default |
|---|---|:---:|---|---|:---:|
| `terminal_value` | EUR | x | EW = BS_T | `run_stopped` | x |
| `terminal_value_opp` | EUR | | EW_U | – | x |
| `delta_terminal_value` (**primär**, D9) | EUR | x | EW − EW_U | `run_stopped` | x |
| `roe_classic` (R1) | Anteil | x | (EW / EL_0)^{1/T_J} − 1, nur wenn EL_0 > 0, EL_t = 0 für t ≥ 1, EN ≡ 0, EW > 0 | `no_existing_value`¹, `no_equity` (EL_0 ≤ zero_abs), `multiple_equity_flows`, `equity_lost` | x |
| `roe_mirr` (R3, **Standard**) | Anteil | x | Zähler = EW + Σ_t EN_t · q_T/q_t; Nenner = Σ_t EL_t / q_t; (Zähler/Nenner)^{1/T_J} − 1 | `no_existing_value`¹, `no_equity` (Nenner ≤ zero_abs), `equity_lost` (Zähler ≤ 0) | x |
| `roe_irr` (R2, ergänzend) | Anteil | x | r mit Σ_t c_t (1+r)^{−τ_t} = 0, c_t = −EL_t + EN_t, c_T += EW; vektorisierte Bisektion auf [−0,99; 1], Auswertung rückwärts mit (1+r)^{−Δ_t} (Horner) | `no_existing_value`¹, `no_equity`, `equity_lost`, `irr_ambiguous` (> 1 Vorzeichenwechsel), `irr_out_of_range` | |
| `payback_time` | Jahre | x | **Vermögensamortisation** (R-72): d_t = W_t − BS^U_t (mit Restwertpfad, 12.2); `_ex_rv`: d_t = BS_t − BS^U_t auf `core_ex_rv(core)` („ohne Restwert“, nur Guthaben und Schulden); t* = min{t : d_u ≥ −tol_u ∀u ≥ t}, tol_u = 1e-9·max(1, abs(BS^U_u)); Wert τ_{t*} | `no_payback` | x |
| `payback_year` | Jahr | x | `year[t* + 1]` (Kalenderjahr der Periode t*) | `no_payback` | x |
| `min_net_liquidity` | EUR | x | min_t (G_t − KK_t − KKP_t) | – | x |
| `max_overdraft` | EUR | x | max_t (KK_t + KKP_t) | – | x |
| `max_financing_need` | EUR | x | max_t (KK_t + KKP_t + Σ_{u≤t} NS_u) | – | x |
| `sum_equity_calls` | EUR | | Σ_t NS_t | – | x |
| `pv_equity_calls` | EUR | | Σ_t NS_t / q_t | – | |
| `flag_shortfall`, `flag_limit_breach`, `flag_reserve_used` | 0/1 | | aus `flags` | – | x |
| `dscr_min` | Verhältnis | | **Objektebene** (inkl. Bestandsdarlehen): min_y NOI_y / KD_y über y ∈ P_stab mit KD_y > zero_abs (Bauphase und Jahre vor dem Stabilisierungsjahr zählen nicht, R-77) | `no_debt_service` | x |
| `dscr_mean` | Verhältnis | | Mittel derselben Jahre | `no_debt_service` | |
| `dscr_years_below` | Jahre | | Anzahl y ∈ P_stab mit DSCR_y < `thresholds$dscr` | `no_debt_service` | x |
| `dscr_min_new` | Verhältnis | | **Maßnahmenebene** (nur neue Kredite): min_y (NOI_y − KD^ex_y) / KD^new_y über y ∈ P_stab mit KD^new_y > zero_abs; ohne Bestandsdarlehen = `dscr_min` (R-77) | `no_debt_service` | |
| `icr_min` | Verhältnis | | min_y NOI_y / INT_y über y ∈ P_stab mit INT_y > zero_abs | `no_debt_service` | |
| `ltv_max` | Anteil | | max_t (Σ_k B_k,t + KK_t + KKP_t) / V_t über t mit V_t > zero_abs (Schulden / Marktwert) | `no_market_value` | x |
| `ltv_end` | Anteil | | Wert in T | `no_market_value` | |
| `lending_ratio_max` | Anteil | | **Beleihungsauslauf**: max_t Σ_k B_k,t / (V_t · (1 − `analysis.lending_value_haircut`)) über t mit V_t > zero_abs (nur Darlehen, R-72) | `no_market_value` | |
| `withdrawal_equivalent` | EUR/Jahr | x | 12.8 | `no_solution` | |
| `npv_cf_project` | EUR | | Σ_t cf_t / q_t, cf = cash-Zeilen `project` + `grants` („finanzierungsneutral, vereinfachte Annahmen“) | – | |
| `irr_cf_project` | Anteil | | IZF von cf mit τ | `irr_ambiguous`, `irr_out_of_range` | |
| `terminal_value_real` | EUR | x | EW / Π_{u=1..T}(1 + π_u)^{Δ_u}, π = `market.inflation` | `no_inflation_path` | |
| `monthly_burden` (series) | EUR/Monat | | je Betriebsjahr y: −Σ (zahlungswirksame Zeilen mit `burden = TRUE`, 7.6) / Σ months_t | `no_operation_period` | x² |
| `monthly_burden_y1`, `monthly_burden_avg10` | EUR/Monat | | erstes volles Betriebsjahr bzw. Mittel der ersten min(10, \|P_voll\|) vollen Betriebsjahre | `no_operation_period` | x² |
| `monthly_burden_construction` | EUR/Monat | | Bauphase (Perioden mit `phase == "construction"`, t ≥ 1): [−Σ zahlungswirksame Zeilen mit `burden = TRUE` (inkl. Bauzeitzinsen und Bereitstellungsprovision) + `household.current_rent_month_eur` × Σ months_t] / Σ months_t („Doppelbelastung“, Memo 07 Persona e) | `no_construction_period` | x² |
| `burden_ratio_max` | Anteil | | max_y `monthly_burden_y` / Einkommen_y; Einkommen = `household.net_income_month_eur` × Index(`income_growth`) | `no_household_income` | x² |
| `monthly_net_cashflow` (series) | EUR/Monat | | je Betriebsjahr y: [Σ zahlungswirksame Zeilen der Abschnitte `project` und `grants` ohne Kategorien `residual_value`, `sale_cost` − KD_y − FEES_y] / Σ months_t; positiv = monatlicher Überschuss, negativ = monatlicher Zuschuss (Memo 07 §5.2 Persona c) | `no_operation_period` | x⁴ |
| `monthly_net_cashflow_y1`, `monthly_net_cashflow_min` | EUR/Monat | | erstes volles Betriebsjahr bzw. Minimum über alle Betriebsjahre | `no_operation_period` | x⁴ |
| `warm_rent` (series), `warm_rent_y1` | EUR/m²/Monat | | (rent + modernization_levy + tenant_energy_cost + tenant_operating_cost) / (A_vm × Monate) je Betriebsjahr; A_vm = Σ `living_area_m2` der Gruppen mit `owner_occupied = false` (ohne Gruppen: `building.living_area_m2`; R-101) | `no_tenant_data`, `no_living_area` (A_vm ≤ zero_abs) | x³ |
| `warm_rent_change_prepost` (series), `warm_rent_change_prepost_y1` | EUR/m²/Monat | | Warmmietenänderung **„vorher/nachher“** je Betriebsjahr: (modernization_levy + tenant_energy_cost − tenant_energy_cost_pre) / (A_vm × Monate), A_vm wie `warm_rent`; nur Mieteranteile (ohne Vermieteranteile an CO2-Kosten und § 5a-Netzentgelten; R-83) | `no_tenant_data`, `no_living_area` (A_vm ≤ zero_abs) | x³ |
| `own_contribution` | EUR | | **Eigenanteil nach Förderung**: −Σ_t (zahlungswirksame Zeilen der Kategorien `land`, `acquisition_cost`, `capex`, `relocation_cost`, `grant`, `tax_credit`) − Σ_t Σ_{k neu} `draw_k` (Investition abzüglich Zuschüsse und neuer Kredite, nominal, ohne Ersatzinvestitionen; R-83) | – | x (², ⁴) |
| `pv_subsidies` | EUR | | Förderbarwert: Σ_t (Zeilen der Kategorien `grant`, `operating_subsidy`, `tax_credit` + Merkzeilen `repayment_grant`) / q_t (ohne Zinsverbilligung; R-83) | – | |
| `co2_emissions` | t CO2 | | Σ_t Merkzeilen `co2_emission` (Treibhausgasbilanz aller Träger, 7.6; R-83, R-101) | – | |
| `restriction_dscr` | 0/1 | | 1, wenn DSCR_y < `thresholds$dscr` für ein y ∈ P_stab (Objektebene) | `no_debt_service` | x⁵ |
| `restriction_liquidity` | 0/1 | | 1, wenn in einer Periode KKP > zero_abs (Limit überschritten), `stop` ausgelöst oder KK + KKP > `overdraft_flag_threshold_eur`; nicht prüfbar, wenn `overdraft_limit_eur` in allen Perioden unendlich ist und `overdraft_flag_threshold_eur` = ∞ (R-101; die Validierung meldet dann `vofi_warning_plausibility` `validation.accounts.liquidity_unchecked`) | `no_liquidity_limit` | x⁵ |
| `restriction_warm_rent` | 0/1 | | 1, wenn `warm_rent_change_prepost_y1` > `thresholds$warm_rent_increase_eur_m2` | `no_tenant_data` | x⁵ |
| `restriction_burden` | 0/1 | | 1, wenn `burden_ratio_max` > `thresholds$burden_share` | `no_household_income` | x⁵ |
| `restriction_savings` | 0/1 | | 1, wenn `flags$equity_call_over_savings` (Nachschuss eines Betriebsjahres über der Sparfähigkeit) | `no_household_income` | x⁵ |

¹ nur bei Bestandsprojekten (1.5) ohne `building.existing_value_eur`: die absolute EK-Rendite ist dann nicht
definiert; maßgeblich ist `incremental_return` (12.6, Konzept 2.5, R-68). ² nur Perspektive `selbstnutzer`
(Belastungssicht; Mieten fließen nicht ein). ³ nur bei `analysis.tenant_view = TRUE`. ⁴ nur Perspektive
`kleinvermieter` (Haushaltsmodus des Vermieters: Cashflow statt Belastung, weil die Belastung die Mieteinnahmen nicht
enthält). ⁵ nur für Codes in `analysis.restrictions` (sonst NA `not_applicable_perspective`); Grundlage der
Restriktionsstufe der Ampel (12.9, R-74). `roe_classic` und `roe_mirr` sind bei nur einer Einlage in t = 0 identisch
(Memo 01 E4).

### 12.3a Primärkennzahl (D9, R-65, R-68)

`analysis.primary_kpi = "auto"` ergibt `delta_vs_reference` (mit `payback_vs_reference` und als Rendite
`incremental_return`), wenn das Projekt ein Bestandsprojekt ist (`project_type` ∈ {`sanierung_eh`,
`sanierung_einzelmassnahmen`, `sanierung_stufenweise`, `heizungstausch`}, 1.5) und
`comparison_mode = "absolute"`; sonst `delta_terminal_value`. Grund: Im Bestand enthält jede Variante die ohnehin
anfallenden Mieten, Energie-, CO2- und Instandhaltungskosten, die Unterlassungsalternative nicht; ΔEW und
`payback_time` gegenüber der Unterlassung sind dort nicht als Vorteilhaftigkeit lesbar (z. B. Memo 07 S4:
ΔEW ≈ −Endwert der Energiekosten, `no_payback`, obwohl V1 besser ist als V0). Folgen: `print()`, `summary()`,
Bericht und Ampel stellen die Primärkennzahl voran; ΔEW gegenüber der Unterlassung trägt den Vermerk „enthält
Bestandszahlungen“ (mit Bestandswert: „gegenüber Verkauf zum Stichtag“, 9.5 Nr. 7). **Referenzpflicht (R-68,
Konzept 2.6, F17; ersetzt die Plausibilitätswarnung aus Runde 1):** Bei Bestandsprojekten im Modus `absolute` ist die
reine Unterlassungsalternative als Referenz unzulässig. Die Validierung (Ebene 3) meldet `vofi_error_validation`
(`validation.reference_variant_missing`), wenn `project.reference_variant` keine vorhandene Variante bezeichnet, wenn
das Szenario neben ihr keine weitere Variante enthält oder wenn `analysis.primary_kpi = delta_terminal_value` gesetzt
ist, außer `analysis.allow_opportunity_reference = TRUE` (dann `vofi_warning_plausibility`, und die Primärkennzahl ist
ΔEW mit Vermerk). Die Absolut-Rendite `roe_*` ist bei Bestandsprojekten nur mit Bestandswert definiert (sonst NA
`no_existing_value`, 12.3). Bei `erwerb_sanierung` und `erwerb_neubau` bleibt ΔEW primär (die
Unterlassung „nicht erwerben“ ist die richtige Alternative); für die Sanierungsentscheidung nach dem Erwerb wird eine
Referenzvariante empfohlen (Hinweis).

### 12.4 NA-Begründungscodes (`inst/vocab/na_reasons.yaml`)

`no_equity`, `multiple_equity_flows`, `equity_lost`, `irr_ambiguous`, `irr_out_of_range`, `no_payback`,
`no_debt_service`, `no_market_value`, `no_household_income`, `no_tenant_data`, `no_living_area`,
`no_inflation_path`, `no_operation_period`, `no_construction_period`, `no_solution` (keine eindeutige Lösung im
Suchintervall), `run_stopped`, `not_applicable_perspective`, `not_computed`, `no_existing_value` (Bestandsprojekt ohne
Bestandswert, R-68), `no_co2_reduction` (keine CO2-Minderung gegenüber der Referenz, R-83), `no_liquidity_limit`
(Liquiditätsrestriktion ohne endliches Limit und ohne endliche Markierungsschwelle nicht prüfbar, R-101). Labels ausschließlich unter `vocab.na_reasons.<code>` (2.10). Undefinierte Renditen sind **nie** −100 % (D9, R-05); Grafiken DÜRFEN sie nur als ausdrücklich
gekennzeichnete Zensur darstellen. Die MC-Statistik weist den NA-Anteil je Kennzahl getrennt aus.

### 12.5 Mit und ohne Restwert (D9, R-52)

Alle Kennzahlen mit `rv = x` werden zusätzlich als `<name>_ex_rv` auf `core_ex_rv(core)` berechnet. Kennzahlen ohne
Restwertbezug (DSCR, ICR, Belastung, monatlicher Cashflow, Warmmiete, Nachschüsse, Eigenanteil, Restriktionen) sind
per Definition restwertunabhängig und tragen in Ausgaben den Vermerk „unabhängig vom Restwert“; LTV und
Beleihungsauslauf nutzen den Wertpfad V_t, nicht den Restwert in T. Die Unterlassungsalternative hat keinen Restwert
(ein Bestandsverkauf zum Stichtag ist eine Einlage, 9.5 Nr. 7). Die Vermögensamortisation „mit Restwert“ nutzt den
Restwertpfad W_t (12.2, R-72).

### 12.6 Vergleichskennzahlen (`vofi_compare()`, je Lauf)

| Schlüssel | Formel |
|---|---|
| `delta_vs_reference`, `_ex_rv` | ΔEW_A − ΔEW_ref (Vergleichsregel, R-27, R-66, 9.6 Nr. 4) |
| `prob_better_than_ref` | Anteil der Läufe mit `delta_vs_reference > 0` (MC; deterministisch 0/1) |
| `payback_vs_reference`, `payback_year_vs_reference` | wie `payback_time` mit d_t = (W^A_t − BS^{U,A}_t) − (W^ref_t − BS^{U,ref}_t) (Vermögensamortisation mit Restwertpfad, R-72); `_ex_rv` mit BS statt W auf der Sicht ohne Restwert; Pfade je Lauf über `return_paths` (9.2), bei abweichendem Raster auf den gemeinsamen Periodenenden (9.6 Nr. 9) |
| `incremental_return`, `_ex_rv` | **Rendite der Mehrinvestition** (R-68, Konzept 2.5): konstanter Habenzins h* mit g(h*) = 0, g(h) = `delta_vs_reference` bei `accounts.deposit_rate_pa` = h in Variante, Referenz und beiden Unterlassungsalternativen; definiert nur, wenn g im Suchintervall genau einen Vorzeichenwechsel hat und fallend ist (Mehrinvestition), sonst NA `no_solution`; Algorithmus 12.8; v1 nur deterministisch (in der MC NA `not_computed`) |
| `co2_reduction`, `co2_abatement_cost` | `co2_emissions` der Referenz − der Variante (t CO2) bzw. −(`delta_vs_reference` / q_T) / `co2_reduction` (EUR/t; NA `no_co2_reduction`, wenn die Minderung ≤ 0 ist; R-83) |
| `monthly_saving_y1`, `monthly_saving_avg10` | `selbstnutzer`: `monthly_burden` der Referenz − `monthly_burden` der Variante (positiv = Ersparnis) |
| `monthly_cashflow_change_y1` | `kleinvermieter`: `monthly_net_cashflow_y1` der Variante − der Referenz (positiv = mehr Überschuss) |
| `warm_rent_change_y1` | `warm_rent_y1` Variante − Referenz (Warmmietenänderung „gegenüber Referenz“; „vorher/nachher“ ist `warm_rent_change_prepost_y1`, 12.3) |

Die Ampel ist keine Kennzahl je Lauf, sondern eine Auswertung über Basisfall, Set „vorsichtig“ und MC (12.9).

### 12.7 MC-Statistik (`mc_stats()`, WS-G)

Je skalarer Kennzahl x über gültige Läufe: `mean`, `sd`, `se` (Replikat-SE = sd(Blockmittel)/√R mit R = n_sim /
`block_size` Blöcken, 11.4; `se_df = R − 1`; bei R < 10 Kennzeichnung „grob“; bei R = 1: sd/√n mit Hinweis
„überschätzt bei LHS“), Quantile `q05, q10, q25, q50, q75, q90, q95` (`type = 7`), `p_neg` = mean(x < 0) mit SE, `es05` = Mittel
der Werte ≤ q05 (EUR, nicht negiert; Label „Mittel der schlechtesten 5 %“), `expected_loss` = mean(pmax(−x, 0)),
`na_share`, `n_valid`; optional verteilungsfreie Konfidenzintervalle der Quantile über Ordnungsstatistiken
(Memo 04 §4.4). Für 0/1-Kennzahlen (u. a. `restriction_*` = Verletzungswahrscheinlichkeit): Anteil mit SE. Der
deterministische Wert steht daneben. **Konvergenzausweis (R-97, R-101):** Spalte `converged` (lgl) =
(t_{R−1; 0,975} · se / |mean| < `convergence.rel_halfwidth_mean`) und (t_{R−1; 0,975} · `p_neg_se` <
`convergence.abs_halfwidth_prob`); bei R < 10 stets `FALSE` (Hinweis „grob“); keine automatische Verlängerung in v1. Bei Entscheidungsknoten gilt die Statistik für das Kompositum; die bedingten
Statistiken stehen in `decision` (9.11 Nr. 5, 13.2).

### 12.8 Löser (`vofi_solve()`, `R/kpi-withdrawal.R`, `R/solve.R`)

**Entnahme-Äquivalent** E* (je Lauf; Memo 01 §4.6, I5). Implementierung (MUSS):
`typedef_kpi_withdrawal_equivalent()$compute(core, ctx)` ruft `kpi_withdrawal_equivalent(core, ctx)`;
`vofi_solve(what = "withdrawal_equivalent")` (WS-G) rechnet den deterministischen Lauf und ruft dieselbe Funktion mit
`tol` des Aufrufs (absolut, EUR/Jahr).

```text
kpi_withdrawal_equivalent(core, ctx, tol = NULL, max_iter = 80L)  # -> vofi_kpi_value (n Werte, NA "no_solution")
  tol NULL -> 1e-6 (deterministisch) bzw. 1e-2 (MC)
  r(E)  <- ctx$rebalance(extra_out = -by_sim(E) * by_period(delta))   # E je Jahr, gebucht E·Δ_t in t >= 1
  BS(E) <- r(E)$BS_T (core$view == "with_rv") bzw. r(E)$BS_T_ex_rv (core$view == "ex_rv", 9.4)
  f(E)  =  BS(E) - Σ_t ΔNS_t(E) · q_T / q_t - EW_U
  ΔNS(E): r(E)$NS minus NS des Basislaufs (E = 0) (Opportunitätswert, macht f monoton; in beiden Sichten gleich)
  EW_U:   core$opp$EW (Unterlassungsalternative OHNE Zusatzentnahme)
Klammer: lo = pmin(ΔEW, 0)/T_J - 1, hi = pmax(ΔEW, 0)/T_J + 1; falls f(lo) < 0 oder f(hi) > 0: Intervall je Lauf
         bis zu 30-mal verdoppeln, sonst NA "no_solution"
Verfahren: vektorisierte Bisektion (Referenz) oder Illinois-Verfahren (Regula falsi mit Halbierung bei Stagnation)
         auf derselben Klammer; f ist stückweise linear und monoton, Illinois konvergiert in wenigen Schritten.
         Abbruch je Lauf, wenn hi - lo < tol; höchstens max_iter Iterationen.
```

Jede Auswertung von f ist ein Ausgleichslauf **ohne** neue Instrumentberechnung (Instrument-Cache, 9.3), daher
kostet eine Iteration im deterministischen Fall unter 1 ms. Prüfwerte: (a) 672,44; (b1) 731,23; (b2) 950,13;
(c1) 2.300,89 (Toleranz 1e-6). Standard: deterministisch berechnet, in der MC und in Design-Läufen nur auf
Anforderung (`analysis.kpis` bzw. Argument `kpis` enthält `withdrawal_equivalent`) (R-51).

**Break-even / kritischer Wert (allgemeine Zielwertsuche, R-75, Konzept 2.5, P13):** `f(x) = KPI(x) − target`,
x = Wert am Pfad `param`, ausgewertet über Design-Läufe (11.11, n = 1 je Auswertung) bzw. Schicht 8, falls der Pfad
kein numerisches Blatt ist oder `rebuild = TRUE` (dann werden Basisfallgrößen wie `auto`-Kreditbeträge je Auswertung
neu bestimmt, z. B. für die maximal tragbare Investition mit mitwachsendem Darlehen). `kpi = NULL` ist die
Primärkennzahl (12.3a). `target` ist eine Zahl oder `"threshold:<name>"` (Wert aus `analysis.thresholds`).
Vergleichskennzahlen (12.6) werden gegen `reference` (Default `project.reference_variant`) mit derselben Designmatrix
für Variante und Referenz gerechnet. Intervall-Default: [min, max] der Overlay-Verteilung, sonst Basis × [0,5; 1,5].
**Monotonieprüfung:** zuerst ein Design-Lauf mit 11 äquidistanten Stützstellen; gleiches Vorzeichen überall →
Ergebnis `NA` mit Meldung „Kein kritischer Wert im Intervall“; mehr als ein Vorzeichenwechsel oder nicht monotone
Stützwerte → `monotone = FALSE` und `vofi_warning_plausibility`, gesucht wird im ersten Wechselintervall. Danach
`stats::uniroot(tol = tol · max(1, |x|))` im Wechselintervall; |f(x*)| > 1 EUR (bzw. 1e-4 bei Verhältnissen und
Anteilen) → Kennzeichnung „Sprungstelle“. Bei vorhandener Overlay-Verteilung zusätzlich P(X > x*). Dynamische
Break-even-Miete (D11) = Break-even mit `param` = Anfangsmiete der Wohnungsgruppe. Prüfwert: (c1) Break-even-NOI_1 =
9.869,14.

| Zielwertsuche (Konzept 2.5) | `kpi` | `target` | typische `param` |
|---|---|---|---|
| Break-even (ΔEW = 0) | `NULL` (Primärkennzahl) | `0` | Miete, Investition, Energie- bzw. CO2-Preis, Anschlusszins, Leerstand, Förderquote, Restnutzungsdauer, Liegenschaftszins, Restwertfaktor |
| Zielrenditemiete | `roe_mirr` | `"threshold:roe_hurdle"` | Anfangsmiete; bei Bestandsprojekten ohne Bestandswert gleichwertig: Primärkennzahl = 0 mit `accounts.deposit_rate_pa` = Zielrendite (weil g fallend ist: `incremental_return` ≥ Zielrendite ⇔ `delta_vs_reference` ≥ 0 bei h = Zielrendite; Konzept 2.5) |
| DSCR-Break-even, kostendeckendes Nutzungsentgelt | `dscr_min` | `"threshold:dscr"` | Miete bzw. Nutzungsentgelt, Investition, Anschlusszins |
| Liquiditäts-Break-even | `min_net_liquidity` | `0` | Miete, Investition, Förderquote |
| warmmietenneutrale Umlage | `warm_rent_change_prepost_y1` | `0` | freiwillige Umlagebegrenzung der Wohnungsgruppe |
| notwendige Förderung | `NULL` | `0` | Förderquote bzw. Förderbetrag |
| maximal tragbare Investition | `NULL`, `dscr_min` oder `burden_ratio_max` | `0` bzw. Schwelle | Investitionskosten (`rebuild = TRUE`, wenn die Darlehen mitwachsen sollen) |

**Rendite der Mehrinvestition** (`incremental_return`, `vofi_solve(what = "incremental_return")`, WS-G, R-68):
g(h) = `delta_vs_reference`(h) für Variante und Referenz bei `accounts.deposit_rate_pa` = h (Designspalte, auch in
beiden Unterlassungsalternativen). Ein Design-Lauf je Modell mit 41 äquidistanten Stützstellen auf
`interval` (Default [−0,02; 0,15]); genau ein Vorzeichenwechsel mit fallendem g, sonst NA `no_solution`; danach
Illinois-Verfahren bzw. Bisektion im Wechselintervall bis `tol` (Default 1e-8). Mit und ohne Restwert (`_ex_rv` auf
`delta_vs_reference_ex_rv`). Deterministisch; in der MC v1 nicht je Lauf (`not_computed`).

### 12.9 Ampel (`cmp_traffic_light()`, WS-G, R-74, Konzept 1.4, A4)

Eingaben: Primärkennzahl P (12.3a) mit und ohne Restwert im Basisfall; falls vorhanden MC-Ergebnis und Ergebnis des
Sets „vorsichtig“ (4.11); Restriktionskennzahlen `restriction_<c>` für c ∈ `analysis.restrictions` (12.3); Schwellen
`analysis.traffic_light` (`green_prob`, `red_prob`, `restriction_prob`). Ordnung `red` < `yellow` < `green`.

```text
Stufe 1 (Wirtschaftlichkeit, gewählte Restwertmethode):
  MC vorhanden (basis = "mc"):        p = Anteil der Läufe mit P > 0, m = Median(P)
                                      green, wenn m > 0 und p >= green_prob; red, wenn p < red_prob; sonst yellow
  sonst „vorsichtig“ (basis = "cautious"): green, wenn P_base > 0 und P_vorsichtig > 0; red, wenn beide <= 0; sonst yellow
  sonst (basis = "base_only"):        yellow, wenn P_base > 0, sonst red; Hinweis „keine Robustheitsprüfung“
  Restwertregel: (P_base > 0) != (P_base_ex_rv > 0) -> Stufe 1 höchstens yellow, Hinweis „Ergebnis hängt am
                 Restwert“ (rv_dependent = TRUE)
Stufe 2 (Restriktionen als K.-o.-Kennzeichen, je c):
  violated_base = restriction_c im Basisfall == 1;  prob = MC-Mittel von restriction_c (NA ohne MC)
  ko_c = violated_base | (prob >= restriction_prob)
  restriction_c NA (z. B. no_liquidity_limit) -> ko_c = FALSE, Hinweis „Restriktion nicht prüfbar“ (R-101)
level = Stufe 1, gedeckelt auf yellow, falls ein ko_c zutrifft
```

Zu jeder verletzten Restriktion bestimmt WS-G aus dem Basisfall Jahr und Betrag der ersten Verletzung (z. B.
DSCR-Wert und Kalenderjahr, KK-Überschreitung in EUR, Warmmietenanstieg in EUR/m²) für den Hinweistext. Rückgabe als
Feld `traffic_light`: `vofi_compare()` füllt es je Variante gegen die Referenz (13.3), `vofi_mc()` für Modelle mit
Primärkennzahl `delta_terminal_value` (13.2); für einen deterministischen `vofi_result` bleibt das Feld `NULL`, und
`summary()` bzw. `vofi_report()` rufen bei Bedarf die interne Funktion `cmp_traffic_light(x)` auf (Basis
`base_only`). Für Bestandsprojekte gibt es die Ampel nur im Vergleich. Bei Entscheidungsknoten gilt das Kompositum
(9.11).

---

## 13. Ergebnisklassen

### 13.1 `vofi_result` (deterministischer Lauf bzw. Einzellauf)

```r
structure(list(
  spec        = <vofi_spec>,
  grid        = <vofi_grid>,
  model_hash  = chr,
  ledger      = <vofi_ledger>,                    # n = 1 (bzw. n bei store = "full" in internen Läufen)
  kpis        = data.frame(),                     # n Zeilen; Spalten = KPI-Schlüssel inkl. _ex_rv
  kpi_na      = data.frame(),                     # gleiche Form, NA-Begründungscodes (chr)
  kpi_series  = list(<name> = list(values = matrix(n, P), years = int)),
  opportunity = list(ledger = <vofi_ledger>,      # Abschnitte equity, deposit, overdraft, tax, check, stocks
                     BS = matrix(n, T + 1), EW = num),
  checks      = data.frame(invariant = chr, max_dev = num, tol = num, ok = lgl),
  flags       = data.frame(),                     # 9.8
  registers   = list(assets = list(), measures = list()),
  draws       = <vofi_draws> | NULL,
  decision    = NULL | list(funding_id, fallback_variant, p_approval = num, branch = 1L | 0L,   # 9.11 (R-71)
                            alternative = <vofi_result>),   # Ergebnis des nicht realisierten Zweigs
  traffic_light = NULL | list(level, stage1, basis = "mc" | "cautious" | "base_only", kpi, rv_dependent = lgl,
                            restrictions = data.frame(code, violated_base, prob, year, value, threshold, ko),
                            notes = chr),                    # 12.9 (R-74)
  meta        = list(package_version, contract_version, schema_version, scenario_id, project_id, building_id,
                     variant, scenario_set, mode, n_sim, seed, sim_index, legal_state, pending_reforms,
                     library = data.frame(entry, as_of, valid_from, valid_to, quality), library_version,
                     defaults = list(<defaults_meta von global.yaml und Profil>),   # 4.7 (R-85)
                     tax_module, perspective, tax_regime, report_mode, comparison_mode, primary_kpi, store,
                     runtime_sec, created, r_version, notes = chr)
), class = "vofi_result")
```

### 13.2 `vofi_mc_result`

```r
structure(list(
  spec, grid, model = <vofi_model>,               # für vofi_sim()
  kpis       = data.frame(sim = int, block = int, branch = int, ...),   # n_sim Zeilen; branch nur mit Knoten (9.11)
  kpi_na     = data.frame(sim = int, ...),
  kpi_series = list(<name> = list(quantiles = matrix(length(band_probs), P), mean = num, years = int)),
  inputs     = data.frame(sim = int, ...),        # statische Ziehungen je Schlüssel
  features   = data.frame(sim = int, ...),        # Pfadmerkmale
  flags      = data.frame(sim = int, ...),
  bands      = list(<row_key> = matrix(length(band_probs) + 1, T + 1)),  # Zeilen q05 … q95, mean
  runs       = list(p05 = <vofi_result>, p50 = <vofi_result>, p95 = <vofi_result>),
  run_index  = c(p05 = int, p50 = int, p95 = int),
  deterministic = <vofi_result>,
  stats      = data.frame(kpi, mean, sd, se, se_df, q05, q10, q25, q50, q75, q90, q95, p_neg, p_neg_se, es05,
                          expected_loss, na_share, n_valid, deterministic, converged),   # converged: 12.7 (R-97)
  checks     = data.frame(invariant, max_dev, tol, ok, n_runs),
  ledger     = <vofi_ledger> | NULL,              # nur store = "full"
  decision   = NULL | list(funding_id, fallback_variant, key, p_approval, share_approved,   # 9.11 (R-71)
                           stats_approved = <wie stats, Variante „mit Zusage“>,
                           stats_fallback = <wie stats, „ohne Zusage, dann Ausweichvariante“>),
  traffic_light = NULL | <wie 13.1>,              # 12.9 (nur Primärkennzahl delta_terminal_value)
  meta       = list(..., seed, n_sim, sampling, replicates (= R), block_size, copula, antithetic, chunk_size,
                    repaired = list(), rng_kind, plan_hash, keep_runs_kpi)
), class = "vofi_mc_result")
```

### 13.3 `vofi_comparison`

```r
structure(list(
  results       = list(<variant> = <vofi_result | vofi_mc_result>),
  baseline      = chr, variants = chr, scenario_sets = chr | NULL,
  kpi_table     = data.frame(variant, kpi, value, ...),   # deterministisch: Wert; MC: mean, q50
  differences   = list(<kpi> = matrix(n_sim, length(variants))),   # je Lauf, z. B. delta_vs_reference
  diff_stats    = data.frame(variant, kpi, mean, se, q05, q25, q50, q75, q95, prob_better),
  ranking       = data.frame(variant, rank, criterion),
  diff_table    = <vofi_table> | NULL,            # Differenz-VoFi (Erklärung, deterministisch; NULL bei abweichendem Raster)
  comparability = <vofi_validation>,              # ungleiche Nachschüsse sind kein Befund (9.6 Nr. 2)
  traffic_light = data.frame(variant, level, stage1, basis, kpi, rv_dependent, ko_codes),   # 12.9 (R-74)
  restrictions  = data.frame(variant, code, violated_base, prob, year, value, threshold, ko),
  conditional   = data.frame(variant, branch, kpi, mean, q05, q50, q95, prob_better) | NULL, # 9.11 Nr. 5
  crn           = TRUE,
  meta          = list(seed, n_sim, mode, allow_unequal, created)
), class = "vofi_comparison")
```

### 13.4 `vofi_sensitivity`, `vofi_solution`

```r
structure(list(
  method = "tornado" | "spider" | "global", kpi = chr, variant = chr, base_value = num,
  params  = data.frame(param, label, base, low, high, source),
  results = data.frame(param, value_low, value_high, kpi_low, kpi_high, swing, rank),   # tornado
  spider  = data.frame(param, step, value, kpi),                                       # spider
  global  = data.frame(input, spearman, src, srrc, prcc, s1_binned), r2_src = num,     # global (aus MC)
  meta    = list()
), class = "vofi_sensitivity")

structure(list(what, param, kpi, target, target_source = chr,   # target_source: "value" | "threshold:<name>"
               value, kpi_at_value, iterations, interval, jump = lgl, monotone = lgl,
               reference = chr | NULL, rebuild = lgl,
               prob_exceed = num | NA, message = chr), class = "vofi_solution")   # 12.8 (R-75)
```

### 13.5 Weitere Klassen

| Klasse | Struktur |
|---|---|
| `vofi_validation` | `data.frame(severity ∈ {error, warning, info}, code (Label-Schlüssel), path, location, message, layer, variant)` mit Klasse `c("vofi_validation", "data.frame")` |
| `vofi_table` | `list(data = data.frame(row_key, label, section, level, <periodenspalten>), layout, detail, periods, sim, variant, format = list(neg_red = TRUE, digits = 2))` |
| `vofi_grid`, `vofi_draws`, `vofi_scenario`, `vofi_spec`, `vofi_model`, `vofi_ledger` | Abschnitte 3.2, 11.8, 4.13, 7.4 |
| `vofi_finding` | `list(severity, code, path, args)` (Rückgabe von `validate()`-Funktionen der Typen) |

### 13.6 Pflicht-S3-Methoden (WS-H, außer markiert)

| Klasse | `print` | `summary` | `format` | `plot` | `as.data.frame` | weitere |
|---|:---:|:---:|:---:|:---:|:---:|---|
| `vofi_scenario` | x | x | | | | |
| `vofi_spec` | x | | | | x (Parameterliste mit Herkunft) | |
| `vofi_model` | x | | | | | |
| `vofi_grid` (I) | x | | | | x | |
| `vofi_draws` (WS-C) | x | | | | x (statische Ziehungen) | |
| `vofi_validation` (WS-B) | x | | x | | x | |
| `vofi_result` | x (Kopf-KPIs + gekürzte Tabelle) | x | x (Zeichenmatrix, deutsches Zahlenformat) | x | x (`what = c("ledger", "kpis")`, `format = c("long", "wide")`) | |
| `vofi_mc_result` | x (Statistik mit SE, Quantilen, deterministischem Wert) | x | x | x (`type = c("verteilung", "fan", "cdf", "konvergenz", "streu", "tornado")`) | x (`what = c("kpis", "inputs", "features", "bands", "stats")`) | `quantile()` |
| `vofi_comparison` | x | x | x | x (`type = c("endwert", "differenz", "cdf", "bestand", "belastung")`) | x | |
| `vofi_sensitivity` | x | | | x (Tornado/Spider/Balken) | x | |
| `vofi_solution` (WS-G) | x | | | | | |
| `vofi_table` | x | | x | | x | |

`summary.<klasse>()` liefert ein Objekt `summary_<klasse>` mit eigener `print`-Methode. Alle Ausgaben verwenden
`fmt_*` und den Label-Katalog; `local_reproducible_output(width = 100)` in Snapshots. `plot.*()` ruft
`vofi_plot()` auf (ggplot2 aus Suggests, Prüfung über `requireNamespace`).

---

## 14. Exportierte API (vollständig, v1)

Jede Funktion existiert nach Phase 0 als Stub mit dieser Signatur in der Datei ihres Eigentümers (2.4).

| Nr. | Signatur | Rückgabe | Beschreibung (deutsch) | Paket |
|---:|---|---|---|---|
| 1 | `vofi_read_scenario(path, format = c("auto", "yaml", "excel"), stochastic = NULL, library_paths = vofi_library_paths())` | `vofi_scenario` | Liest ein Szenario aus YAML oder Excel und normalisiert es (optional mit separater Stochastik-Datei). | WS-A |
| 2 | `vofi_write_scenario(scenario, path, format = c("auto", "yaml", "excel"), resolved = FALSE, variant = "base", overwrite = FALSE)` | `invisible(path)` | Schreibt ein Szenario (auf Wunsch aufgelöst) als YAML oder Excel. | WS-A (Excel: WS-A2) |
| 3 | `vofi_scenario(x, source = NULL)` | `vofi_scenario` | Erzeugt ein kanonisches Szenario aus einer R-Liste. | WS-A |
| 4 | `vofi_example(name = NULL)` | chr | Pfad eines mitgelieferten Beispielszenarios bzw. Namen aller Beispiele. | WS-A |
| 5 | `vofi_excel_template(path, example = NULL, overwrite = FALSE)` | `invisible(path)` | Erzeugt die Excel-Eingabevorlage aus Registry, Vokabularen und Labels. | WS-A2 |
| 6 | `vofi_library(block = NULL, library_paths = vofi_library_paths(), date = NULL)` | data.frame | Listet Bibliothekseinträge mit Metadaten und Gültigkeit zum Datum. | WS-A |
| 7 | `vofi_library_paths(add = NULL)` | chr | Gibt die Bibliothekspfade zurück bzw. ergänzt Nutzerpfade. | WS-A |
| 8 | `vofi_variants(scenario)` | data.frame | Listet Basis und Varianten mit Bezeichnung und Eltern. | WS-A |
| 9 | `vofi_resolve(scenario, variant = "base", overrides = NULL, scenario_set = NULL)` | `vofi_spec` | Löst eine Variante auf (Schichten, Bibliothek, Varianten, Expander). | WS-A |
| 10 | `vofi_validate(x, variant = NULL, min_severity = c("info", "warning", "error"))` | `vofi_validation` | Prüft Szenario bzw. Spezifikation auf vier Ebenen und sammelt alle Befunde. | WS-B |
| 11 | `vofi_json_schema(path = NULL)` | chr bzw. `invisible(path)` | Exportiert das Eingabeschema als JSON-Schema für Editoren. | WS-B |
| 12 | `vofi_time_grid(valuation_date, horizon_years, construction_months = 0L, construction_step_months = 12L, operation_step_months = 12L, operation_alignment = c("calendar", "completion"), periods_months = NULL, start_year = NULL)` | `vofi_grid` | Erzeugt das Zeitraster (Vektor der Periodenlängen) mit festem Horizontende (R-67). | I |
| 13 | `vofi_build(x, variant = "base", overrides = NULL, scenario_set = NULL)` | `vofi_model` | Baut aus Szenario oder Spezifikation ein rechenfertiges Modell. | WS-D |
| 14 | `vofi_run(model, n_sim = 1L, seed = NULL, store = c("auto", "full", "bands", "kpi"), chunk_size = getOption("vofi.chunk_size", 2000L))` | `vofi_result` bzw. `vofi_mc_result` | Berechnet den VoFi deterministisch (n_sim = 1) oder als Monte-Carlo-Simulation. | WS-D |
| 15 | `vofi_mc(model, n_sim = NULL, seed = NULL, sampling = NULL, block_size = NULL, store = NULL, bands = NULL, keep_runs = NULL, parallel = FALSE, chunk_size = getOption("vofi.chunk_size", 2000L), preview = FALSE)` | `vofi_mc_result` | Monte-Carlo-Simulation; nicht gesetzte (`NULL`) Argumente aus `stochastic$settings` (dort alternativ `replicates`, 11.4), `store` zulässig `"bands"`, `"kpi"`, `"full"` (Default `"bands"`); `preview = TRUE` rechnet 1.000 Läufe (= die ersten 1.000 Läufe des Standardlaufs, R-73) und entspricht `stochastic.settings.preset: preview` (4.3.15, R-97); Entscheidungsknoten als Kompositum (9.11). | WS-G |
| 16 | `vofi_sim(x, i)` | `vofi_result` | Rechnet Lauf i einer Simulation mit vollständiger VoFi-Tabelle nach (identisch zum Batch). | WS-D |
| 17 | `vofi_opportunity(x)` | `vofi_result` | Unterlassungsalternative zu einem Modell oder Ergebnis. | WS-D |
| 18 | `vofi_compare(x, variants = NULL, baseline = NULL, scenario_sets = NULL, n_sim = 1L, seed = NULL, store = c("auto", "bands", "kpi"), allow_unequal = FALSE)` | `vofi_comparison` | Vergleicht Varianten als vollständige VoFis mit gemeinsamen Zufallszahlen (Vergleichsregel ΔEW_A − ΔEW_B, Ausweichvarianten, Set „vorsichtig“, Ampel; 9.6, 9.11, 12.9). | WS-G |
| 19 | `vofi_sensitivity(x, params = NULL, method = c("tornado", "spider", "global"), probs = c(0.1, 0.9), delta = NULL, steps = 5L, kpi = NULL, variant = "base", reference = NULL)` | `vofi_sensitivity` | Tornado und Spider (ein Design-Lauf) bzw. globale Sensitivität aus einer Simulation; `kpi = NULL` = Primärkennzahl, Vergleichskennzahlen gegen `reference` (Default `project.reference_variant`). | WS-G |
| 20 | `vofi_solve(x, what = c("breakeven", "critical_value", "withdrawal_equivalent", "incremental_return"), param = NULL, kpi = NULL, target = 0, interval = NULL, tol = 1e-8, variant = "base", reference = NULL, rebuild = FALSE)` | `vofi_solution` | Allgemeine Zielwertsuche (Kennzahl, Zielwert oder Schwelle `"threshold:<name>"`, Monotonieprüfung), Entnahme-Äquivalent, Rendite der Mehrinvestition (12.8, R-75). | WS-G (Entnahme-Äquivalent: WS-D2) |
| 21 | `vofi_kpis(x, which = NULL, rv = c("both", "with", "without"), per = c("total", "unit", "m2"))` | data.frame | Kennzahlen eines Ergebnisses mit Bezeichnung, Einheit und NA-Begründung; EUR-Kennzahlen optional je WE (`building.n_units`) bzw. je m² Wohnfläche (Konzept 1.4, P23, R-83). | WS-D2 |
| 22 | `vofi_table(x, sim = 1L, layout = c("grob", "transposed"), detail = c("standard", "full"), periods = NULL, variant = NULL)` | `vofi_table` | VoFi-Tabelle im Grob-Layout bzw. transponiert. | WS-H |
| 23 | `vofi_ledger(x, format = c("long", "wide"), sim = NULL, vat = FALSE)` | data.frame | Zahlungsbuch im Long- oder Wide-Format, optional mit Netto/USt. | WS-H |
| 24 | `vofi_plot(x, type = NULL, ...)` | ggplot | Grafiken zu Ergebnis, Simulation, Vergleich und Sensitivität. | WS-H |
| 25 | `vofi_export_excel(x, path, overwrite = FALSE, sheets = NULL)` | `invisible(path)` | Excel-Export mit Annahmen, Prüfungen und Saldo-Formel. | WS-H |
| 26 | `vofi_report(x, path, format = c("html", "docx"), mode = c("auto", "expert", "household"), template = NULL, title = NULL, open = interactive())` | `invisible(path)` | HTML-Bericht im Fach- oder Haushaltsmodus (DOCX vorbereitet, Freigabe v1.1, R-25). | WS-H2 |
| 27 | `vofi_tenant_view(x, variant = NULL)` | data.frame | Nutzerkostensicht: Warmmiete je Jahr und Variante. | WS-H |
| 28 | `vofi_household_view(x, variant = NULL)` | data.frame | Haushaltssicht: Selbstnutzer monatliche Belastung (inkl. Bauphase, zusätzlich „ohne Tilgung“), Ersparnis, Belastungsquote, Eigenanteil, Nachschüsse, Vermögensamortisation mit Zeitwert der Maßnahmen je Jahr; Kleinvermieter monatlicher Cashflow (Überschuss/Zuschuss) je Jahr. | WS-H |
| 29 | `vofi_app(scenario = NULL, launch.browser = interactive(), ...)` | – | Startet den Shiny-Viewer (v1: Stub mit Hinweis auf v1.1). | I / WS-J |
| 30 | `vofi_type(name, kind, params = list(), ..., example = NULL, label = NULL, version = 1L)` | `vofi_typedef` | Definiert einen Bausteintyp. | I |
| 31 | `vofi_register_type(def, overwrite = FALSE)` | `invisible(def)` | Registriert einen Typ in der Registry. | I |
| 32 | `vofi_types(kind = NULL)` | data.frame | Listet registrierte Typen. | I |
| 33 | `vofi_type_info(name, kind = NULL)` | Liste | Beschreibung, Parameter und Zeilen eines Typs. | I |
| 34 | `vofi_check_type(name, kind = NULL, n = c(1L, 2L, 7L))` | `invisible(TRUE)` | Führt die Vertragstests für einen Typ aus. | I |
| 35 | `vofi_param(kind, ..., default = NULL, required = FALSE, min = NULL, max = NULL, unit = NULL, stochastic = NULL, values = NULL, allow_auto = FALSE, shapes = NULL, deterministic_only = FALSE, fields = NULL)` | `vofi_param` | Beschreibt einen Typparameter (Parameter-DSL). | WS-B (Konstruktor: I in Phase 0) |
| 36 | `vofi_row(key, values, section, category, tax_category = NULL, cash = NULL, kind = c("flow", "stock", "memo"), unit = "EUR", asset_id = NULL, measure_id = NULL, vat_rate = 0, vat_recoverable = FALSE, is_tax = NULL, program = NULL, label = NULL, label_key = NULL, ...)` | `vofi_row` | Erzeugt eine Ledger-Zeile mit Pflicht-Tags. | I |
| 37 | `vofi_flows(..., assets = list(), measures = list(), aux = list(), meta = list())` | `vofi_flows` | Bündelt die Rückgabe einer Zahlungskomponente. | I |
| 38 | `vofi_asset(asset_id, asset_type, in_service_date, land_share = 0, afa_method = NULL, useful_life_override = NULL, construction_start_date = NULL, building_application_date = NULL, original_completion_year = NULL, acquisition_date = NULL, living_area_m2 = NULL, efficiency_standard = NULL, label = NULL)` | `vofi_asset` | Eintrag im Anlagenregister. | I |
| 39 | `vofi_measure(measure_id, measure_type, classification = c("auto", "erhaltung", "herstellung"), classification_source = c("default", "user", "rule"), completion_date = NULL, paid_in_full_date = NULL, contractor_certified = NA, funding_choice = c("keine", "beg_zuschuss", "beg_kredit", "35c"), asset_id = NULL, label = NULL)` | `vofi_measure` | Eintrag im Maßnahmenregister. | I |
| 40 | `vofi_kpi_value(values, na_reason = NULL, years = NULL)` | `vofi_kpi_value` | Rückgabeobjekt einer Kennzahl mit NA-Begründung. | I |
| 41 | `vofi_register_kpi(name, compute, label = NULL, unit = "EUR", shape = c("scalar", "series"), rv_variant = FALSE, higher_is_better = TRUE, mc_default = FALSE, perspectives = NULL, requires = character(), overwrite = FALSE)` | `invisible(def)` | Registriert eine Kennzahl. | WS-D2 |
| 42 | `vofi_register_tax_module(name, constructor, label = NULL, perspectives = NULL, blocked_regimes = NULL, params = list(), overwrite = FALSE)` | `invisible(def)` | Registriert ein Steuermodul. | WS-D |
| 43 | `vofi_tax_module_simple(name, fun, label = NULL)` | `invisible(def)` | Vereinfachtes Steuermodul ohne Zustand (Experimente). | WS-D |
| 44 | `tax_init(module, params, assets, measures, n_sim)` | Zustand | S3-Generic: Initialisierung des Steuermoduls. | WS-D |
| 45 | `tax_step(module, t, inputs, interest, state, params)` | `list(payment, state, report)` | S3-Generic: Steuer der Periode t. | WS-D |
| 46 | `tax_finalize(module, T, state, terminal_inputs, params)` | `list(payment_T, report)` | S3-Generic: am Horizont offene Steuer. | WS-D |

Zusätzlich exportiert: alle S3-Methoden aus 13.6. **Nicht** exportiert sind `lbl`, `msg`, `fmt_*`, `grid_*`,
`ledger_*`, `smp_*`, `eng_*`, `kpi_*`, `typedef_*` und alle übrigen internen Funktionen.

---

## 15. Testvertrag

### 15.1 Testhelfer (Signaturen)

```r
# helper-contracts.R (I) – dünne Hüllen um das Prüfkit R/registry-testkit.R (5.6)
make_grid(type = c("annual", "mixed", "oracle_e"), T = 6L, valuation_date = as.Date("2027-01-01"))
make_ctx(n = 1L, grid = make_grid(), spec = NULL, params = list(), market = list(), draws = NULL,
         components = list(), perspective = "wu_kommunal", legal_state = as.Date("2026-10-25"))
fake_draws(n, grid, static = list(), paths = list(), mode = "mc")      # names = Zielpfade (flach, 4.13)
expect_vofi_row(row, n, T)
expect_vofi_flows_contract(flows, ctx, def = NULL)
expect_type_contract(name, kind = NULL)                                # ruft vofi_check_type()
expect_batch_invariance(fun, n = 7L, grid = make_grid(), draws = NULL, tol = 1e-12)
expect_no_rng(expr)
expect_vofi_invariants(x, tol = vofi_tol)                              # I1–I3, N1, N2
with_strict_labels(code)
local_vofi_options(..., .env = parent.frame())

# helper-fixtures.R (I)
example_scenario(name = c("skeleton", "oracle_a"))                     # vofi_scenario aus fixtures/scenarios
example_core(n = 7L, T = 6L)                                           # = reg_example_core(); core (12.1) für KPI-Tests
example_result()                                                       # vertragsgemäßes vofi_result aus den Tabellenwerten von Orakel (a), ohne Engine
example_mc_result(n_sim = 200L)                                        # synthetisch, vertragsgemäß
example_comparison()

# helper-oracles.R (WS-T)
oracle_ids()        # c("a", "a3", "a_unlevered", "b1", "b2", "c1", "c1_unlevered", "c2", "d", "e", "f", "g")
oracle_scenario(id)                                                    # vofi_scenario aus fixtures/oracles/<id>.yaml
oracle_expected(id)                                                    # list(rows = data.frame(row_key, t, value), kpis = data.frame(kpi, value, variant))
                                                                       # variant = NA außer bei (g)
oracle_view(result)                                                    # Ledger -> Orakel-Zeilenschlüssel (15.3)
expect_oracle(result, id, tol = vofi_tol$oracle_abs)

# helper-reference-engine.R (WS-T)
ref_engine_run(spec_simple)                 # skalare Referenz-Engine (Schleifen je Lauf und Periode), ca. 150 Zeilen
ref_scenario_generator(seed, n = 200L)      # Zufallsszenarien (feste Seeds) für Differenztests
spec_simple_from_model(model)               # Übersetzung unterstützter Modelle in die Referenz-Eingabe

# helper-tax-test-module.R (WS-D, R-78)
register_tax_test_module(name = "test_flat")   # registriert ein Modul mit params: rate (s), depreciation_years,
                                               # lag (0/1); lineare AfA je asset_id, sofortiger Verlustausgleich
```

### 15.2 Vertragstests

`test-contract-types.R` (I) iteriert über `vofi_types()` und ruft `expect_type_contract()` für jeden Typ (5.6).
Zusätzlich je Datei die Tests des Eigentümers. Jeder neue Typ ist ohne weiteren Code automatisch geprüft.

### 15.3 Orakel (Memo 01 §10, WS-T)

**Herkunft der Sollwerte:** `data-raw/export_oracles.py` ruft die unveränderten Funktionen aus
`data-raw/vofi_ref.py` (Kopie von `docs/recherche/prototypen/vofi_referenz/vofi_ref.py`) auf und schreibt
`tests/testthat/fixtures/oracles/<id>_rows.csv` (`row_key,t,value`, ungerundet, `%.12g`) und `<id>_kpis.csv`
(`kpi,value`). **Toleranz:** 1e-6 (EUR) bzw. 1e-9 (Raten) gegen diese Werte; 0,005 EUR bzw. 5e-7 (Raten) gegen die
gerundeten Tabellenwerte des Memos.

**Modellierung der Orakelszenarien** (`fixtures/oracles/<id>.yaml`): Stichtag 2027-01-01; Jahresraster (außer (e));
Zahlungsfolge als `custom_series` (Kategorie `custom`), Restwert als eigene Komponente (Kategorie `residual_value`,
nur in T); Bausteine `ek` (equity), Kredite `ann`, `bul`, `foe`, `bau` mit `payments_per_year: 1`;
`accounts`: Raten wie im Memo, `overdraft_limit_eur: .inf` ((c2): 0), `min_liquidity_eur: 0`,
`surplus_order: [od_repay, dep_invest]` ((a3): `[od_repay, loan_prepay, dep_invest]` mit `ann.prepay_allowed: true`),
`deficit_order: [dep_withdraw, od_draw, equity_call]`, `deposit_withholding_tax_share: 0`, `tax.module: none`.
(b) und (c): Einzahlungsüberschüsse als `recurring` mit Kategorie `rent` (NOI-relevant, für DSCR), z. B. (c):
`amount_eur: 12000`, `growth: 0.02`, `base_date: 2028-01-01` (Break-even-Pfad `components.noi.amount_eur`); die
Investition als `custom_series` (Kategorie `custom`); (c): Marktwert als `custom_series` mit `section: memo`,
`category: market_value`, `values: {start: 280000, growth: 0.02, index: period_end}` (Stichtagswert zum Periodenende,
V_t = 280.000 · 1,02^t; R-91). (e): `grid.periods_months: [3, 3, 3, 3, 12, 12, 12]`, `construction_months: 12`.

**Abbildung Ledger → Orakelzeilen (`oracle_view()`):**

| Orakelzeile | `row_key` | Aggregation |
|---|---|---|
| Zahlungsfolge z_t | `cf_project` | Σ Abschnitt `project` |
| Zuschüsse | `grant_cash` | Σ Abschnitt `grants` |
| EK: Einlage / Nachschuss / Entnahme | `equity_in` / `equity_call` / `equity_out` | je Kategorie |
| Kredit: Aufnahme / Tilgung / Sondertilgung / Sollzinsen / Bereitstellungsprov. | `loan_<k>_draw` / `loan_<k>_repay_total` / `loan_<k>_prepay` / `loan_<k>_interest` / `loan_<k>_fees` | `repay_total = repay + repay_balloon` |
| Kredit: Tilgungszuschuss / Bestand | `loan_<k>_repayment_grant` / `loan_<k>_balance` | |
| Kontokorrent: Aufnahme / Tilgung / Sollzinsen / Bestand | `od_draw` / `od_repay` / `od_interest` / `od_balance` | jeweils inkl. `odp_*` |
| Geldanlage: Anlage / Auflösung / Habenzinsen / Bestand | `dep_invest` / `dep_withdraw` / `dep_interest` / `dep_balance` | |
| Steuern / Finanzierungssaldo / Bestandssaldo | `tax` / `balance_check` / `net_position` | |

**Pflicht-Orakel und Kernwerte** (Tabellenwerte; maßgeblich sind die CSV-Skriptwerte):

| id | Inhalt | Kernwerte |
|---|---|---|
| (a) | Lehrbuch-VoFi: Annuität 40.000 @ 6 %, 5 J.; endfällig 30.000 @ 5 %; EK 30.000; h = 3 %, s = 10 % | EW 38.504,63; EW_U 34.778,22; ΔEW 3.726,41; R1 = R2 = R3 = 5,1183 %; `payback_time` 5, ohne RW `no_payback`; min. Nettoliquidität −6.491,30; max. KK 6.491,30; Entnahme-Äquivalent 672,44; KW(3 %) 10.195,96; IZF 5,5636 %; BS^U = 30.000,00; 30.900,00; 31.827,00; 32.781,81; 33.765,26; 34.778,22 |
| (a_unlevered) | (a) ohne Kredite, EK 100.000 | EW 127.747,32; R3 5,0196 % |
| (a3) | (a) mit Ü3 für das Annuitätendarlehen | EW 39.139,97; ΔEW 4.361,75; R3 5,4629 %; Sondertilgung t = 3: 11.863,72; Geldanlage t = 5: 39.139,97 |
| (b1) | Ratentilgung 150.000 @ 2 %, 10 J., 2 tilgungsfrei, TZ 22.500 in t = 1, `shorten_term`; h = 2 %, s = 8 % | EW 70.432,51; EW_U 60.949,72; ΔEW 9.482,79; R3 3,4857 %; max. KK 6.421,70; Entnahme-Äquivalent 731,23; DSCR t = 1…9: 4,67; 5,60; 0,68; 0,71; 0,74; 0,77; 0,80; 0,83; 1,07 (t = 10 kein Kapitaldienst); KW(2 %) −13.524,20; IZF 0,9458 % |
| (b2) | wie (b1), `reduce_installment` | EW 71.353,38; ΔEW 10.403,66; R3 3,6202 %; kein KK; Entnahme-Äquivalent 950,13; Tilgung je 15.937,50 ab t = 3; DSCR min 0,79 |
| (c1) | 100 % FK, Annuität 300.000 @ 3,8 %, τ = 2 %; h = 2,5 %, s = 9 %; KK unbegrenzt | EW 34.957,28; EW_U 0; ΔEW 34.957,28; R1/R2/R3 `no_equity`; max. KK 59.114,48; Entnahme-Äquivalent 2.300,89; Break-even-NOI_1 9.869,14; LTV t = 0: 107,14 %; IZF 5,1616 %; DSCR min 0,69 |
| (c1_unlevered) | (c) eigenfinanziert, EK 300.000 | EW 477.695,18; R3 4,7618 % |
| (c2) | wie (c1), KK-Limit 0, `equity_call` | EW 99.392,07; EW_U 45.263,66; ΔEW 54.128,41; R1 `no_equity`; R3 10,8879 %; R2 16,9699 %; Σ Nachschüsse 39.544,46; Barwert 35.359,90 |
| (d) | (a) mit allen Zinsen 5 % | EW 41.004,58; EW_U 38.288,45; ΔEW 2.716,13 = KW(5 %) · 1,05^5 (I4); R1 6,4492 % |
| (e) | Bauphase quartalsweise, Baudarlehen 400.000 in 4 Tranchen, 3,6 % nominal, Bereitstellungsprov. 0,25 %/Monat nach 3 Monaten, ein tilgungsfreies Quartal, τ = 2 %; h = 2,5 %, s = 9 % effektiv | EW 156.540,56; EW_U 110.381,29; ΔEW 46.159,27; R3 11,8553 %; `payback_time` 4; max. KK 11.530,53; Provision t = 2: −1.500, t = 3: −750; Periodenhabenzins Quartal 0,0061922463 |
| (f) | Monatsannuität 100.000 @ 3,6 %, 240 Monate, Jahresperiode (Instrumenttest mit `make_ctx`) | Rate 585,11; Zinsen Jahr 1: 3.542,98; Tilgung Jahr 1: 3.478,36; Restschuld 96.521,64 |
| (g) | **Vergleichsregel** (Konzept F17, R-66; Handrechnung WS-T, kein Memo-Skript): T = 2, Jahresraster, h = 2 %, s = 8 %, `penalty_spread_pa: 0.02`, KL = 0, `deficit_order: [dep_withdraw, od_draw, equity_call]`, EK 10.000 in t = 0 in beiden Varianten; Referenz B (`base`): Zahlungsfolge −10.000 / +1.000 / +12.000; Variante A: −10.000 / −3.000 / +16.000 | A: Nachschuss t = 1: 3.000; EW_A 16.000,00; EW_U,A 13.464,00; ΔEW_A 2.536,00. B: keine Nachschüsse; EW_B 13.020,00; EW_U,B 10.404,00; ΔEW_B 2.616,00. `delta_vs_reference`(A) = −80,00 = (EW_A − EW_B = 2.980,00) − 3.000 · 1,02; `sum_equity_calls` A 3.000, `pv_equity_calls` A 2.941,18; Vergleichbarkeitsbericht ohne Fehler trotz ungleicher Nachschüsse |

Für jedes Orakel gilt zusätzlich: max |Finanzierungssaldo| ≤ 1e-8 · Volumen und Vermögensfortschreibung (I2) erfüllt.
Orakel (g) wird mit `vofi_compare(oracle_scenario("g"), variants = "a", baseline = "base")` gerechnet;
`g_kpis.csv` trägt die Spalte `variant`.

### 15.4 Invarianten (`test-invariants.R`, WS-T)

Für alle Beispielszenarien und Orakel deterministisch sowie für **alle** Läufe einer MC mit n = 2.000
(`store = "full"`):

| Nr. | Test |
|---|---|
| I1–I3 | Laufzeitprüfungen 9.7 (zusätzlich zur Engine unabhängig nachgerechnet) |
| I4 | vollkommener Kapitalmarkt: alle Zinsen gleich i (Haben, Soll, Kredite), keine Gebühren, kein Disagio, **nur Jahresraster und `payments_per_year = 1`** (sonst sind nominaler Kreditzins mit Monatsuhr und effektiver Kontozins nicht äquivalent), KK unbegrenzt, keine D4-Zuflüsse ⇒ ΔEW = (1+i)^T · [KW_i(z) + KW_i(ZU) + KW_i(TZ)] (Orakel (d), (b2), 50 Zufallsszenarien) |
| I5 | Entnahme-Zielfunktion f aus 12.8 (inkl. ΔNS-Korrektur) streng fallend in der konstanten Zusatzentnahme: f(E + 1) − f(E) < 0; sind zusätzlich h_net ≥ 0, s ≥ 0 und sp ≥ 0 in allen Perioden, gilt f(E + 1) − f(E) ≤ −T_J + 1e-9 (auch bei `equity_call`, Orakel (c2)) |
| I6 | Unterlassungsalternative ohne Entnahmen, ohne KK und mit `deposit_tax_allowance_eur_pa` = 0: EW_U = Σ_t EL_t · q_T / q_t (mit Sacheinlage: EL_0 durch `opp_in_kind_sale` ersetzt, 9.5 Nr. 7) |
| V1 | Vergleichsregel (9.6 Nr. 4): für 50 Zufallsszenarien mit zwei Varianten ohne KK der Alternativen gilt `delta_vs_reference` = EW_A − EW_ref − Σ_t (NS^A_t − NS^ref_t) · q_T / q_t (1e-8 relativ) und Orakel (g) |
| R3 | Rangidentität: sign(`roe_mirr` − r_U) = sign(ΔEW), r_U = R3 der Unterlassungsalternative mit **denselben** EL und EN wie die Investition (gilt, weil die Alternative keine eigenen Nachschüsse erhält, 9.5 Nr. 5); geprüft auch am Prüffall 9.5 |
| N2 | Terminalzustand ohne Restwert: Prüffall 9.4 (Privatprofil mit Restwert, KL = 0, `equity_call`) und alle Orakel |
| G | Zufallsszenario-Generator (WS-T): erzeugt für I4 nur Szenarien mit Jahresraster, `payments_per_year = 1`, ohne Gebühren/Disagio und mit unbegrenztem KK; für die Schranke von I5 nur h_net, s, sp ≥ 0 |

### 15.5 Batch- und Reproduzierbarkeitstests (`test-batch-invariance.R`, I)

1. **Lauf i im Batch = Einzellauf i:** MC mit n = 7, `block_size = 7`; für jedes i ist `vofi_sim(mc, i)$ledger`
   identisch zur Zeile i des Batch-Ledgers (`store = "full"`).
2. **Entartung:** alle Verteilungen entartet (min = mode = max = Basiswert, σ = 0) ⇒ jeder MC-Lauf = deterministischer
   Lauf (1e-10).
3. **Chunk-Invarianz:** `chunk_size` = 1 Block vs. alle Blöcke ⇒ identisch; sequenziell vs. `future::plan(multisession,
   workers = 2)` ⇒ identisch (`skip_on_cran()`).
4. **Reproduzierbarkeit:** gleicher Seed ⇒ identisch; anderer Seed ⇒ verschieden; globaler RNG-Zustand unverändert;
   ein zusätzlicher Overlay-Parameter lässt alle übrigen Ziehungen unverändert.
5. **CRN:** zwei identische Varianten ⇒ `delta_vs_reference` exakt 0 in jedem Lauf.
6. **Rasterinvarianz der Kredite:** Jahresannuität auf Jahresraster = auf Raster mit monatlicher Bauphase bei gleichen
   Vertragsterminen (1e-9); Tilgungen und Bestände je Kalenderjahr identisch, Zinsen je Kalenderjahr identisch.
7. **Kanonische Ordnung im Sampler:** Umordnen der Overlay-Einträge und der Korrelationspaare im YAML sowie Lauf
   unter `LC_COLLATE=C` und `C.UTF-8` ergibt identische Ziehungen (`identical()`); Blockgröße m ≤ d einer
   Korrelationsgruppe ergibt `vofi_error_input` (11.4).
8. **Instrument-Cache:** Lauf mit Cache (ohne `loan_prepay`) = Lauf mit erzwungener Neuberechnung (`identical()`).
9. **Präfix-Stabilität (R-73):** Die Läufe 1…1.000 einer MC mit n_sim = 10.000 sind `identical()` zu einer MC mit
   n_sim = 1.000 (gleicher Seed, gleiche Blockgröße); n_sim = 1.100 bei `block_size = 200` ergibt `vofi_error_input`.
10. **Feste Kreditbeträge (R-69):** In einer MC mit stochastischen Baukosten und `amount_eur: auto` ist `commitment`
    in allen Läufen gleich dem deterministischen Wert; mit `topup` ist dessen Betrag im Basisfall 0 und je Lauf gleich
    dem Mehrbedarf gegenüber dem Basisfall.
11. **Entscheidungsknoten (R-71):** Das Kompositum ist je Lauf identisch zur getrennten Rechnung von V (bei b_i = 1)
    bzw. F (bei b_i = 0) mit denselben Rohziehungen; der Anteil der Zusagen je Block weicht wegen LHS um höchstens
    1/m von p ab; `decision$stats_approved` = Statistik der getrennten MC von V.

### 15.6 Weitere Pflichttests

| Bereich | Inhalt | Eigentümer |
|---|---|---|
| MC-Statistik | Memo 04 §9 (Momente innerhalb 4 SE, LHS exakt geschichtet je Block, Iman-Conover ±0,02 bei n = 20.000 mit `block_size = 200` und identische Ränder, nearPD, Prozesse, Floor); Entscheidungsschlüssel ohne Zielwirkung und nicht korrelierbar | WS-C |
| MC-Ergebnisse | Replikat-SE mit R = n_sim / `block_size` (Kennzeichnung „grob“ bei R < 10), Quantile, ES, Konvergenz, `keep_runs`, Kompositum und bedingte Statistik (9.11) | WS-G |
| Vergleich, Ampel, Zielwertsuche | Orakel (g) und V1; Vergleichbarkeit trotz ungleicher Nachschüsse; Referenzpflicht im Bestand (12.3a); Ampel-Fälle je Basis (`mc`, `cautious`, `base_only`), Restwertregel und K.-o.-Deckel (12.9); Set „vorsichtig“ = ungünstige Tornado-Werte; `vofi_solve()` mit Schwellen-Ziel, Monotonieprüfung und `incremental_return` (12.8) | WS-G |
| Bestand und Restwertpfad | Prüffall Sacheinlage (9.5); `dscr_min` vs. `dscr_min_new` mit Bestandsdarlehen; `payback_time` mit `residual_path` (W_t) und ohne Restwert; RW_T(method) = Restwertzeilen in T (4.12 Nr. 8) | WS-T, WS-D2, WS-E |
| Eingabe | YAML-Handler (4.6), Deep-Merge, `~`, `.replace`, `from:`-Ketten und Zyklen, Gültigkeitswarnungen, Varianten-Existenzprüfungen, Expander-Referenzen, Round-Trip YAML ↔ XLSX, Vorlage = generierte Vorlage | WS-A, WS-A2 |
| Validierung | jede Meldung in `validation.yaml` wird mindestens einmal ausgelöst | WS-B |
| Labels | jeder in `R/` verwendete Schlüssel (`lbl("…")`, `msg("…")`, `vofi_abort("…")`) existiert; jede Typdatei hat ihre Pflichtlabels | I |
| ASCII | Code-Token aller Dateien in `R/` sind ASCII: `utils::getParseData(parse(f, keep.source = TRUE))`, geprüft werden alle Token außer `COMMENT` (insbesondere `STR_CONST`, `SYMBOL`, `SYMBOL_FUNCTION_CALL`); deutsche Kommentare und roxygen-Doku sind erlaubt (2.7 Nr. 1). Ergänzend muss `R CMD check` die Prüfung „non-ASCII characters“ bestehen | I |
| Steuerbereitschaft | 10.10 Nr. 7 für S1–S5 | WS-S |
| Referenzszenarien | alle Prüfwerte S*-T* aus Memo 07 §4 bzw. Spec 01 Teil C §5; Testkatalog Memo 07 §6.2. Konventionen: Kredite in S1–S4 mit `payments_per_year: 1` (die Prüfwerte sind Jahresannuitäten), in **S5 mit `payments_per_year: 12`** (Monatsraten, Memo 07 §4.5; R-105); „Kostenstand Y“ einer Maßnahme zum 1. Januar Y wird als `price_base_year: Y − 1` erfasst (R-35); die Validierung meldet `vofi_warning_plausibility`, wenn eine Maßnahme in t = 0 einen Preisindex < 1 erhält; Verschiebungen sind ≥ 0 (3.9) | WS-S |
| Rechtsregeln | Rechenbeispiele 1–7 aus Memo 02, Mietpfad-Testfall Memo 02 §2.2, Regeltests Memo 07 §6.2 | WS-E (Mietrecht, CO2KostAufG, GrESt); Förderregeln WS-E2 (R-104) |
| Bibliothek, Defaults | `test-library.R`: Eintragsschema, Freigabe, Codes ⊆ Vokabulare, Verweise; `test-profiles.R`: reservierte Schlüssel, Profilpfade, alle `from`/`use`-Verweise lösen auf (2.4) | WS-L, WS-A |
| Metamorphe Tests | Skalierung aller Beträge mit k ⇒ EW × k; Komponente mit Betrag 0 ändert nichts; höhere Miete ⇒ EW ≥; höherer KK-Zins ⇒ EW ≤; Restwert aus ⇒ EW sinkt; nur Label geändert ⇒ identisch | Phase 3 |
| Differenztests | Referenz-Engine vs. Engine auf 200 Zufallsszenarien (1e-8 relativ) | WS-T / Phase 3 |
| Snapshots | `print`/`format` aller Klassen, Validierungsbericht, VoFi-Tabelle, deutsche Meldungen; `skip_if_not(l10n_info()[["UTF-8"]])` | WS-H, WS-B |
| Leistung | 9.10 (`skip_on_cran()`) | WS-D, WS-G |

### 15.7 Definition of Done je Datei

Deutsche roxygen-Doku (exportierte Funktionen mit Beispiel), Testabdeckung ≥ 90 % für `engine-*`, `sampling-*`,
`dist-*`, `process-*`, `scenario-*`, `values-*`, `validate-*`, `type-*`, `kpi-*` und ≥ 80 % gesamt
(`covr::package_coverage()`), Vertragstests grün, `lintr` ohne Befund, kein Nicht-ASCII in Code-Token in `R/`
(15.6), Labels vollständig,
`R CMD check` (`LANG=C.UTF-8`) mit 0 Errors, 0 Warnings und nur begründeten Notes.

---

## 16. Rückverfolgbarkeit und aufgelöste Widersprüche

### 16.1 Entscheidungen D1–D14 → Abschnitte

| Entscheidung | Umsetzung in |
|---|---|
| D1 Paket `vofi`, Architektur A, Matrizen N × (T+1), N = 1 deterministisch, Registry mit Arten, `typedef_*` | 2.2, 2.8, 5, 6, 7.4, 11.9 |
| D2 Raster als Periodenvektor (Monate), Standard jährlich, nicht äquidistant ab v1, Zinsumrechnung, interne Monatsrechnung, Vertragsfrequenz | 3 (inkl. Kalenderjahresindex 3.6, Verschiebungen 3.9), 7.12, 8.1, 8.5, 8.10 |
| D3 Zinsen nachschüssig auf Bestände t−1 | 3.6, 8.1 Nr. 4, 9.3 Schritt (3) |
| D4 Ausgleichsketten, Engpass-Policy je Profil, Ü3 standardmäßig aus (Warnung bei Aktivierung), geplante Sondertilgungen | 4.3.10, 4.7 (Profile), 8.2, 8.9, 9.3 Schritt (6), R-76 |
| D5 Vor-Steuer-VoFi, Pflicht-Hook mit `tax_none`, Tags, Register, `tax_flat` (L), § 35c als Förderinstrument (Deckel durch voraussichtliche ESt), Abgeltungsoption mit Sparer-Pauschbetrag, Schnittstellentests mit Test-Modul ab Phase 1 | 7.1, 7.2, 10, 4.3.5, 4.3.7, 4.3.10, R-76, R-78, R-79 |
| D6 Bruttokosten, USt getrennt ableitbar, PV 0 %, GrESt, Grundsteuer | 7.10, 7.11 |
| D7 kanonisches Szenario, YAML + Excel, Schichten, Herkunft, Expander, Varianten, Overlay | 4 |
| D8 Sampler getrennt, Ströme, replizierte LHS (Blöcke fester Größe, Default 200; Wortlaut „10 Blöcke“ siehe R-73 und 17.3), Iman-Conover je Block, Gauß-Copula, Cholesky, CRN, N-Defaults, Speicherstrategie, Performance Gap (Strukturmodell), Bernoulli-Förderzusage als Entscheidungsknoten mit Ausweichvariante bzw. einfache Ziehung | 9.9, 9.11, 11, 4.3.6b, 4.3.15, R-71, R-73 |
| D9 Primär ΔEW (im Bestand gegenüber der Referenzvariante, 12.3a), Vergleichsregel ΔEW_A − ΔEW_B, R3, NA mit Codes, Rendite der Mehrinvestition, Entnahme-Äquivalent, Amortisation (ohne Restwert und mit Restwertpfad), DSCR ab Stabilisierungsjahr (Objekt- und Maßnahmenebene), LTV und Beleihungsauslauf, Liquidität, allgemeine Zielwertsuche, Warmmiete (vorher/nachher und gegen Referenz), Haushaltssicht (Selbstnutzer: Belastung inkl. Bauphase, Eigenanteil; Kleinvermieter: monatlicher Cashflow), mit/ohne Restwert, zweistufige Ampel | 9.4, 9.5, 9.6, 12, R-66, R-68, R-72, R-74, R-75, R-77, R-83 |
| D10 Reformschalter (inkl. Schalter `stufe_2045`), versionierter Rechtsstand, Freigaberegel, Gültigkeit und Warnungen | 4.9, 4.10, R-80, R-82 |
| D11 Umfang (Portfolio v2, BV v2, WEG v2, Shiny v1.1, HTML v1) | 4.3.1 (`project_id`, `building_id`), 13, 14 (Nr. 26, 29) |
| D12 englische Bezeichner, ASCII, Label-Kataloge, deutsche roxygen-Doku, `R CMD check` sauber | 2.6, 2.7, 2.10, 15.7 |
| D13 minimale Imports, Suggests | 2.5 |
| D14 Phase 0 + parallele Wellen, disjunkte Dateien | 1.4, 2.3, 2.4 |

### 16.2 Adaptivitätsanforderungen (Memo 07) → Abschnitte

| ID | Abschnitt | ID | Abschnitt | ID | Abschnitt |
|---|---|---|---|---|---|
| A-01 | 3, 4.3.2 | A-10 | 4.3.7, 7.6 (`grant`), 3.9 (Verzug) | A-19 | 12.8 (allgemeine Zielwertsuche, R-75) |
| A-02 | 3, 8.5, 12.3 (Monatswerte) | A-11 | 4.5, Typ `recurring`/`custom_series` | A-20 | 12.3 (`warm_rent`), 14 Nr. 27 |
| A-03 | 4.3.6, 3.4 | A-12 | 4.3.11, 4.5 (`growth`) | A-21 | 11 |
| A-04 | 4.11 | A-13 | 4.9, 4.10 | A-22 | 10 |
| A-05 | 4.3.6 (`ohnehin_*`), 9.6 | A-14 | 4.5 (`quantity`) | A-23 | 4.3.1, 4.3.4 (ids), v2 |
| A-06 | 3.3, 4.3.6 (`payment_schedule`) | A-15 | 4.3.6 (`effects`), 4.3.6b (JAZ, Performance Gap), Spec 01 | A-24 | 4.11 (`scenario_sets` inkl. `foerderstopp` und generiertem `vorsichtig`) |
| A-07 | 8 | A-16 | 4.3.12, 4.12 Nr. 8 (Restwertpfad), 12.5 | A-25 | 4.6, 9.1, `vofi_validate()` |
| A-08 | 8.6 | A-17 | 4.12, Regeln (Spec 01) | | |
| A-09 | 8.8, 8.9, 9.6 | A-18 | 4.12, Regeln (Spec 01) | | |

### 16.3 Aufgelöste Widersprüche zwischen den Memos

| Nr. | Thema | Memos / Positionen | Festlegung |
|---|---|---|---|
| R-01 | Standardraster | Memo 01 E7: Bauphase monatlich als Standard; Memo 07 A-02: jährlich, unterjährig v2 | D2: Jahresraster Standard, nicht äquidistant ab v1 (`construction_step_months`) |
| R-02 | Horizontbezug | Memo 01 §5.5, Memo 05 §6.1, Konzept A3: ab Fertigstellung; Memo 07 §4: Kalenderjahre ab Start | **ersetzt durch R-67** (Runde 2): festes Horizontende ab Stichtag, Schalter `horizon_from` entfällt |
| R-03 | Periodenzins | D2: (1+r)^(m/12) − 1; Memo 01 §3.1: Kredite i_nom · Δ | Konten effektiv (Default); Kredite nominal mit Monatsuhr i_nom/12 (Typkonvention), Orakel (e) |
| R-04 | Vergleichsmodus | Memo 02: `differential` Standard für Sanierung; Memo 01 E6: Total-VoFi | `absolute` Standard, `differential` als gekennzeichneter Vereinfachungsmodus (S) |
| R-05 | undefinierte Rendite | Memo 04 §6.1: −100 % + Markierung; Memo 01 E5: NA | NA mit Code; −100 % nur als gekennzeichnete Grafikoption |
| R-06 | KPI-Schlüssel | Memo 04: `endwert`, `endwert_diff`, `vofi_rendite`; Memo 07 §5.5: `terminal_value_diff`, `equity_return_vofi`, `payback_year_wealth`, `prob_better_than_ref`, `modernisation_levy` | englische Schlüssel nach 12.3/12.6: `delta_terminal_value`, `roe_mirr`, `payback_year`, `delta_vs_reference`, `prob_better_than_ref`, Kategorie `modernization_levy`; Memo-07-Labels gelten als deutsche Labels |
| R-07 | Wirkung Tilgungszuschuss | Memo 01: `shorten_term`/`reduce_installment`; Memo 02: `reduce_principal`/`reduce_annuity`/`shorten_term`; Memo 07: `term_reduction`/`payment_reduction` | Memo-01-Codes kanonisch; Aliase `reduce_annuity`, `payment_reduction` → `reduce_installment`, `term_reduction` → `shorten_term`; `reduce_principal` beschreibt jeden TZ und ist kein Wirkungscode |
| R-08 | Perspektiven | Memo 02 (5 Codes) vs. Memo 06 (7 Steuerregime) | `project.perspective` (Memo 02) + `project.tax_regime` (Memo 06) mit Default-Abbildung |
| R-09 | Projektarten | Memo 02 vs. Memo 07 (`sanierung_stufenweise`) | Vereinigung in `enums.yaml`, ergänzt um `erwerb_neubau` |
| R-10 | Steuerumfang v1 | Memo 01: Pauschalsteuer v1.1; Memo 02: Grenzsteuersatz v1.1; Memo 05/06: `tax_flat` v1-L, `tax_selfuse` v1-S | D5: `tax_flat` L (optional, aus); `tax_selfuse` entfällt (§ 35c → Förderung, Abgeltung → Kontoparameter) |
| R-11 | § 35c | Memo 06: Generator im Steuermodul, `tax_credit` als Modulausgabe | Förderinstrument `instrument_type: tax_credit`, Typ `tax_credit_35c`, Abschnitt `grants`; Steuermodule ignorieren diese Zeilen |
| R-12 | Bibliotheksmetadaten | Memo 05: `accessed`; Memo 02: `uncertainty`; D10: `as_of`; Konzept: Qualitätsstufe | Pflicht `source`, `as_of`, `valid_from`, `valid_to`, `quality`; optional `accessed`, `uncertainty`, `topic`, `reform` |
| R-13 | Bibliotheksformat | Memo 02: Listen mit `id`; Memo 05: ein Eintrag je Datei | ein Eintrag je Datei; Listen nur in Nutzerbibliotheken, werden zerlegt |
| R-14 | Blockgröße | Memo 05 §6.3: fester Block = 1.000 Läufe; Memo 04/D8: 10 Replikate | **ersetzt durch R-73** (Runde 2): feste Blockgröße 200, `replicates` als Alternative |
| R-15 | Zeitachse der Prozesse | Memo 04: jährlich in Kalenderjahren; D2: nicht äquidistantes Raster | Prozesse in Kalenderjahren, Abbildung über Jahr des Periodenbeginns; Raten über `rate_eff`/`index` |
| R-16 | Overlay-Ziele | Memo-04-Beispiele mit Pfaden außerhalb des Schemas (`construction.cost_factor`, `revenue.*`) | `target` MUSS ein existierender Schema-Pfad sein |
| R-17 | Basiswert deterministisch | Memo 05 §6.3: `point()`/`expected()`; Overlay-Prinzip: deterministischer Wert am Ziel | deterministischer Wert der Schichten 0–5, 7, 8; `point()` nur für Kurzformen ohne Basis |
| R-18 | ids erzeugter Komponenten | Memo 05 §4.9: `measures.huelle.capex` | Präfixschema `m_<id>_<rolle>` usw.; Punkte sind Pfadtrenner |
| R-19 | Zeile `cf_project` | Memo 01: eine Zeile; Memo 05: Komponentenzeilen | granularer Ledger; `cf_project`, `grant_cash` nur als Tabellensummen |
| R-20 | Engpass-Policy | Memo 01 §3.2, D4 | Profil: WU `penalty_rate`, privat `equity_call`; `stop` verfügbar |
| R-21 | Steuer-Hook in t = 0 | Memo 06 §7.8: Schleife t = 1…T | Hook in t = 0…T |
| R-22 | Steuervorzeichen | Memo 05: `tax = −payment`; Memo 06: Erstattung negativ | identisch: `payment` > 0 Zahlung, Zeile `tax = −payment` |
| R-23 | Konten der Unterlassungsalternative | Memo 01 §4.2: gleiche Konditionen inkl. Limit; Python-Referenz: unbegrenztes KK | identische Konten, Ketten und Policy (Orakel unberührt) |
| R-24 | USt-Speicherung | Memo 05: `vat_rate` je Zeile, brutto; Memo 06: netto und USt getrennt | brutto + `vat_rate`; Netto/USt verlustfrei abgeleitet und getrennt ausgegeben |
| R-25 | DOCX-Bericht | Memo 05: v1; D11: HTML v1, DOCX optional; Konzept F12 | DOCX technisch vorbereitet, Freigabe v1.1 |
| R-26 | Excel lesen | Memo 05: openxlsx; D13: readxl nur falls nötig | nur `openxlsx::read.xlsx()` |
| R-27 | Vergleichsmaß | Memo 04 §6.3: EW_A − EW_B; Memo 05 §6.6: ΔEW_A − ΔEW_B | `delta_vs_reference = ΔEW_A − ΔEW_ref` (korrigiert unterschiedliche Nachschüsse; sonst identisch) |
| R-28 | Parallelisierung | Memo 05: `parallel`-Argument; Memo 04 E12, Konzept: keine in v1 | Argument vorhanden (stabile API), Umsetzung KANN, Ergebnisse identisch |
| R-29 | Aktivierung Ü3 | Memo 05: Schalter; Memo 01: Puffer | nur über `loan_prepay` in `surplus_order`; Parameter `accounts.prepay` |
| R-30 | D4 in der Kette | Memo 05: Policy als letztes Kettenelement; Profil-Defaults | eine Quelle: letztes Element von `deficit_order` |
| R-31 | Strafzins | Memo 01: zweite KK-Tranche | eigene Zeilen `odp_*`, eigener Bestand `odp_balance`; Ü1 tilgt zuerst KKP |
| R-32 | Policy `stop` | Memo 01: Abbruch bzw. NA | kein Abbruch: Zeile `shortfall`, Markierung `stopped`, Kennzahlen NA `run_stopped`, Warnung |
| R-33 | `running_costs` (Memo 07 §6.1) | eigener Block | Komponenten vom Typ `recurring` im Block `components` |
| R-34 | Restwertmethoden | Memo 01, 02, 07 mit verschiedenen Codes | kanonisch `zero`, `market_growth`, `income_value`, `component`, `asset_value`, `multiplier`, `exit_yield`, `user_value`; Aliase: `none` → `zero`, `linear_book_value`/`component_book_value` → `component`, `ertragswert_allg`/`ertragswert_vereinf` → `income_value` (Parameter `variant`), `sachwert_linear` → `asset_value` |
| R-35 | Zeitzuordnung | Memo 07: `year: 2030` → t = 3; Memo 06: Daten | Jahr Y = Y-01-01; Datum → Periode mit date_start < d ≤ date_end; Preisstand = 1. Januar nach `price_base_year` |
| R-36 | Sensitivitätsmethoden | Memo 05: `regression`; Memo 04 §7.4: globale Maße | `method = "global"` (Spearman, SRC, SRRC, PRCC, binned S1) |
| R-37 | Validierungsbibliothek | Memo 04 §9: `checkmate` | keine; eigene DSL (D13) |
| R-38 | nearPD | Memo 04 §3.3: `Matrix::nearPD` als Option | nur Eigenwert-Clipping (Base R) |
| R-39 | Bootstrap, t-Copula | Memo 04 E3 (Bootstrap), §3.2 (t-Copula) | beide v2 (D8) |
| R-40 | Abgeltungsteuer-Default | Memo 06 §6.1: an für Selbstnutzer; Konzept B4: aus | Default 0 in allen Profilen; Schalter mit Pflichthinweis |
| R-41 | Asset-Zeitpunkt | Memo 05: `in_service_period`; Memo 06: `in_service_date` | `in_service_date` (Date) |
| R-42 | `vofi_flows(memo = )` | Memo 05: `memo`-Liste | `aux` (Hilfsmatrizen ohne Ledger-Bezug); Merkzeilen sind `vofi_row(kind = "memo")` |
| R-43 | Rastereinheit | Memo 05: `delta` in Jahren; D2: Monate | Raster speichert `months` (int) und `delta` = months/12 |
| R-44 | Suggests | D13 vs. Memo 05 (`vdiffr`, `jsonlite`, `withr`, `future`) | D13 + `withr`, `future`, `jsonlite`; kein `vdiffr` |
| R-45 | Anschlusszins-Beobachtung | Memo 04 §2.3 „Jahr vor dem Reset“; Memo 05 Prototyp: Spalte t+1 | Wert der Periode, in der der Anpassungsmonat endet (= Jahr vor dem Termin bei Jahresraster) |
| R-46 | DSCR-Kapitaldienst | Memo 01 §6 (ohne Sondertilgung, ohne Schlusstilgung); Python: alle Tilgungen | Zeile `repay_balloon` getrennt; KD = interest + repay |
| R-47 | stochastische Termine | Memo 04 §5.3 (maskierte Resets) | Zeitparameter der Instrumente deterministisch in v1; laufspezifische Verschiebungen nur in Zahlungskomponenten (R-60) |
| R-48 | deutsche Texte in Vokabularen | Memo 05 §5.11: Vokabulardatei enthält deutsche Bedeutung | Codes in `inst/vocab`, Texte in `inst/labels/de/vocab.yaml` |
| R-49 | Ort von `horizon_years` | Memo 05 §4.2: `grid` mit Horizontbezug; Memo 02/07: `project` | `project.horizon_years`, Schritte in `grid` (Horizontbezug fest ab Stichtag, R-67) |
| R-50 | Portfolio-Fähigkeit | Memo 07 §3.1: ids project → building → variant | `meta.project_id`, `building.building_id`, `variant` in `meta` jedes Ergebnisses |
| R-51 | Entnahme-Äquivalent | Memo 05: „später“; D9: v1 | v1: deterministisch Standard, MC auf Anforderung; Nachschuss-Korrektur macht f monoton |
| R-52 | „alle KPIs mit/ohne Restwert“ | D9 | `_ex_rv` für restwertabhängige KPIs; übrige als „unabhängig vom Restwert“ gekennzeichnet |
| R-53 | Bänder über Chunks | Memo 04 §5.5 (Histogramme) vs. Memo 05 §6.9 (Matrizen) | gesammelte Matrizen der Bandzeilen, exakte Quantile |
| R-54 | Qualitätsstufen | Konzept §5.4 (A–D) | Pflichtfeld `quality` in Bibliothekseinträgen und Herkunft |
| R-55 | Förderzusage | D8: Bernoulli je Instrument | automatischer Overlay-Schlüssel `funding.<id>.approved`, abschaltbar; bei Entscheidungsknoten Rolle `decision` (R-71) |
| R-56 | Steuer-Eingabematrizen | Memo 06 §7.3: n × T | n × (T+1) |
| R-57 | Kommunale WU-Engpass-Policy bei unbegrenztem Limit | Memo 01: WU-Limit unbegrenzt; Konzept A2: Limit als Warnschwelle, darüber `penalty_rate` | Profil setzt `overdraft_limit_eur` und `overdraft_flag_threshold_eur`; `penalty_rate` greift erst bei endlichem Limit (Limitsemantik und Profilwerte präzisiert in R-76) |
| R-58 | Startwert der Prozesse | Memo 04 Prototyp: Jahre ab `start_year + 1` | Spalte 1 = Jahr(valuation_date) = Startwert; Schocks ab Spalte 2 |
| R-59 | CRN bei variantenspezifischen Verteilungen | Memo 04 §8.2: Vereinigung aller Größen | gemeinsamer Plan; Korrelation auf Uniform-Ebene, Quantilfunktion je Variante |
| R-60 | stochastische Termine in Zahlungskomponenten | Memo 04 (Bauzeitverzug PERT, Nutzungsdauern), Memo 07 S1/S2/S4 (Verzug, Ausfalljahr) vs. R-47 | Raster und Instrumente deterministisch; Flows verschieben laufspezifisch über `ctx$timing()`/`ctx$shift_*()` (3.9); Schemapfade `project.construction_delay_months`, `measures.<id>.delay_months`, `measures.<id>.useful_life_years` |
| R-61 | Zuflüsse von außen in Hilfsläufen | Memo 01 §4.2 (gleiche Einlagen; „braucht U selbst KK“), Memo 01 K11; Profil-Default `equity_call` | weder die Sicht ohne Restwert (9.4) noch die Unterlassungsalternative (9.5) erhalten eigene Nachschüsse; Fehlbeträge laufen über KKP; N2 und R3-Rangidentität gelten per Konstruktion |
| R-62 | Indexierung laufender Jahresbeträge | D2 (rasterunabhängige Ergebnisse) vs. Indexierung zum Periodenende | Kalenderjahresindex `grid_index_year()` für laufende Beträge, `grid_index()` für Bestände und Stichtagswerte (3.6) |
| R-63 | Mietpfad und Modernisierungsumlage | Memo 02 §2.1–2.3 (wechselseitige Abhängigkeit § 558/§ 559), Memo 05 (getrennte Komponenten) | eine monatliche Komponente `rent_path` je Wohnungsgruppe mit Zeilen `rent`, `rent_loss`, `levy_<maßnahme>`; §§ 558/559/559c/559e als Regeln (WS-E) |
| R-64 | unsichere Stützstellen | Memo 07 §4.0 (CO2-Preis 2030/2040 als Dreiecksverteilungen) vs. 4.4 Nr. 3 (Sequenzen nicht elementweise adressierbar) | Elemente von `points`/`series_*` dürfen skalare Knoten sein; Unsicherheit über `shared`-Blätter (4.5 Regel 4) |
| R-65 | Primärkennzahl im Bestand | D9 (ΔEW primär) vs. Memo 01 Z. 79 („bzw. gegen Ohnehin-/Bestandsvarianten“), Memo 07 S4 | `analysis.primary_kpi = auto`: Sanierung/Heizungstausch im Modus `absolute` → `delta_vs_reference`, sonst ΔEW (12.3a); Referenzpflicht verschärft in R-68 |

**Runde 2: Abgleich mit dem Konzept** (Konzept §11.1–11.3 und Konzept-Review; Einzelnachweis in 17.4):

| Nr. | Thema | Positionen | Festlegung |
|---|---|---|---|
| R-66 | Vergleichsregel, Nachschüsse | Konzept F17, 2.5, L1 (Orakel (g)); Spec Runde 1: R-27, Test „(g)“ Ratendarlehen | `delta_vs_reference` = ΔEW_A − ΔEW_ref ist die Vergleichsregel; ungleiche endogene Nachschüsse sind kein Vergleichbarkeitsfehler (9.6 Nr. 2, 4); Identität mit aufgezinster Nachschussdifferenz; neues Orakel (g) (15.3), Ratendarlehen-Test in **(h)** umbenannt (8.10); Invariante V1 (15.4) |
| R-67 | Horizontende | Konzept F16, A3, L2 vs. R-02 (`horizon_from = completion` wählbar) | festes Kalenderdatum `end_date` = Stichtag + Horizont für alle Varianten und Läufe; `horizon_from` entfällt (3.3, 4.3.3, 14 Nr. 12); Vergleichbarkeit über Stichtag und Horizontende, abweichende Periodeneinteilung zulässig, Pfadvergleiche auf gemeinsamen Periodenenden (9.6 Nr. 2, 9) |
| R-68 | Bestandsobjekte | Konzept 2.5, 2.6, 3.10, F17, A9, P1, P7 vs. R-65/F-08 (nur Plausibilitätswarnung) | Bestandswert `building.existing_value_eur` als Sacheinlage `equity_in_kind` in t = 0 (abzüglich Bestandsdarlehen), in der Unterlassungsalternative Verkauf nach Verkaufskosten und Ablösung (9.5 Nr. 7); Bestandsdarlehen `existing: true` mit Merkzeile `assumed`, in allen Gebäudevarianten identisch (8.2, 9.6 Nr. 2); ohne Bestandswert `roe_*` NA `no_existing_value`; KPI `incremental_return`; Referenzvariante im Bestand Pflicht (Validierungsfehler, Ausnahme `allow_opportunity_reference`) (12.3a) |
| R-69 | Kreditbeträge | Konzept F15, 3.10, P10 vs. 8.7 Runde 1 (`auto` je Lauf, Förderausfall erhöht `auto`) | `auto` einmal im Basisfall-Vorlauf bestimmt, fest in allen Läufen und Design-Zeilen; Kreditbeträge `deterministic_only`, Instrumente lesen sie als Basisfallwert; Bewilligungsrisiko über `approved`; optionale Nachfinanzierung `topup` (Mehrbedarf gegenüber dem Basisfall); Tilgungszuschuss auf min(Zusage, abgerufen) (8.1, 8.2, 8.5, 8.7, 9.1 Stufe 6a) |
| R-70 | Plan- und Basisfallwerte | Konzept 3.5, 3.8, P5, P6 (Plan-JAZ für § 559f, warmmietenneutrale Umlage im Basisfall fest) | `ctx$param_base()`, `ctx$value_base()`, `ctx$component_base()` liefern den deterministischen Basisfall; Feld `jaz_plan` (`deterministic_only`, Default Basisfallwert von `jaz`); warmmietenneutrale Begrenzung aus Basisfallwerten (6.2, 6.3, 4.3.6a, 4.3.6b) |
| R-71 | Förderzusage als Entscheidungsknoten | Konzept 3.9, B12, D8, P3 vs. R-55 (nur Bernoulli im selben Modell) | `funding.<id>.fallback_variant`, `approval_timing`, `on_reject`; Zusageschlüssel mit Rolle `decision`; Kompositlauf V/Ausweichvariante mit CRN und bedingter Auswertung; einfache Ziehung mit Ausgleich oder Wegfall der Stufe (`measures.<id>.active`, Aktivierungsfaktor) (9.11, 4.12 Nr. 7, 11.6 Nr. 4, 13.1–13.3) |
| R-72 | Restwertpfad | Konzept 3.11, 2.5, L5, P7 vs. `payback_time` mit RW nur in T | Merkzeilen `market_value` (V_t) und `residual_path` (RW_t, `rv_basis` `method`/`measures`) je Periode; Vermögensamortisation mit W_t = BS_t + RW_t; `analysis.rv_path_basis` (Haushaltsmodus: Zeitwert der Maßnahmen); Beleihungsauslauf `lending_ratio_max` getrennt von LTV (4.12 Nr. 8, 12.2, 12.3, 12.6) |
| R-73 | LHS-Blöcke | Konzept F21, D8 („10 Blöcke“), Memo 04 E6 vs. Memo 05 §6.3 (fester Block) und Integratorvorgabe Runde 2 (Lauf i unabhängig von n_sim) | **feste Blockgröße** `block_size` = 200 (Vorschau R = 5, Standard R = 50); Lauf i unabhängig von n_sim und Chunking, Vorschau = Präfix des Standardlaufs; `replicates` als Alternative (F21-Modus); SE aus Blockmitteln mit `se_df`, „grob“ bei R < 10; Iman-Conover-Mindestgröße m ≥ d + 1 (11.4); ersetzt R-14. Abweichung vom Wortlaut D8 und von F21 ist zur Bestätigung offen (17.3) |
| R-74 | Ampel und Set „vorsichtig“ | Konzept 1.4, A4, B5, P11, L4 vs. 12.6 Runde 1 (einstufig, deterministisch über Pflichtsensitivität „Restwert = 0“) | zweistufige Ampel mit Restwertregel, Basis `mc`/`cautious`/`base_only` und Restriktionen als K.-o.-Kennzeichen (`restriction_*`, `analysis.restrictions`, `restriction_prob`) (12.9); generiertes Set `vorsichtig` als Designzeile aus den ungünstigen Tornado-Werten, Bibliotheksstandard in `global.yaml` (4.11) |
| R-75 | Zielwertsuche | Konzept 2.5, 1.3, P13 vs. 12.8 Runde 1 (nur ΔEW = 0 als Standard) | `vofi_solve()` für jede Kennzahl und jeden Zielwert (auch `"threshold:<name>"`), Vergleichskennzahlen gegen `reference`, Monotonieprüfung, `rebuild`; Tabelle der Standard-Zielwertsuchen (12.8, 13.4, 14 Nr. 19–20) |
| R-76 | Konten je Perspektive | Konzept A2, F18, F4, B4, 3.12 | strukturelle Felder: `deposit_tax_allowance_eur_pa` (Sparer-Pauschbetrag), Limitsemantik (Limit = Schwelle der D4-Aktion), Profil-Defaults für `penalty_spread_pa`, `min_liquidity_eur`, `overdraft_flag_threshold_eur`; Kopplung an den Zinspfad über `ref` mit `anchor`; zulässige Profilpfade (4.3.10, 4.5, 4.7, 8.8); Ü3-Aktivierung mit Warnung (8.9); Werte in Spec 01 |
| R-77 | DSCR-Ebenen, Stabilisierungsjahr | Konzept 2.5, P7 | DSCR/ICR nur über Betriebsjahre ab `analysis.stabilization_year`; Objektebene (`dscr_min`, alle Kredite) und Maßnahmenebene (`dscr_min_new`); Ledger-Spalte `existing_debt` (7.4, 12.2, 12.3) |
| R-78 | Pflichttests der Steuer-Schnittstelle | Konzept 3.12, L9 vs. 10.10 Runde 1 (Tests 2–4 bei WS-X) | Test-Steuermodul `test_flat` in `tests/` (WS-D), Tests ab Welle 1, Wiederholung mit `tax_flat` (10.10, 2.4, 15.1) |
| R-79 | § 35c-Deckel | Konzept 3.9, L22 vs. 10.9 Runde 1 (Bestätigung `sufficient_income_tax`) | Deckel je Jahr durch `household.expected_income_tax_eur_pa`, nicht nutzbare Beträge verfallen, Warnung (10.9, 4.3.5) |
| R-80 | Freigaberegel und Bibliotheksstand | Konzept 6.5, 5.4, F5 | Metadatum `release`; automatische Wahl nur für Qualität A/B und freigegebene C-Einträge, D nie automatisch; inaktive Themen; Sammelcode `unreleased`; `meta$library_version` aus `inst/extdata/library/VERSION` (4.9, 4.10, 13.1) |
| R-81 | Fehlbeträge der Unterlassungsalternative (17.3 Nr. 3 aus Runde 1) | R-61 (KKP zu sp) vs. Konzept 2.6 (gleiche Kontokonditionen), F13-Grundsatz (vorsichtigere Lesart) | bei D4 = `equity_call`/`stop` verzinst die Alternative ihre KKP-Tranche zum Regelzins s (kein Strafzinsaufschlag); bei `penalty_rate` bleibt sp; Rangidentität unberührt (9.5 Nr. 5) |
| R-82 | 2045-Stufe, Pflichtsensitivitäten | Konzept F5, A7, P9, 5.5 | Schaltercode `stufe_2045` im Vokabular `reform` (Standard aus); Pflichtsensitivitäten als Liste `{id, path, label}` mit genau einem von `value`, `delta`, `add`, Inhalte je Profil in Spec 01; Szenario-Sets dürfen `project.pending_reforms` setzen (4.3.14, 4.10, 4.11) |
| R-83 | Ergänzende Kennzahlen | Konzept 1.4, 2.5, P6, P23, L3 | `warm_rent_change_prepost(_y1)` mit Merkzeile `tenant_energy_cost_pre`; `own_contribution`; `pv_subsidies`; `co2_emissions`, `co2_reduction`, `co2_abatement_cost`; `vofi_kpis(per = …)` je WE und m²; Haushaltssicht „ohne Tilgung“ (7.6, 12.3, 12.6, 14 Nr. 21, 28) |
| R-84 | Feldauszüge | Konzept 3.2 (P18), B7, B12 | PV über 30 kWp per Attribut 0 % USt (7.10); Performance Gap als Strukturmodell (4.3.6b); `funding.<id>.payout_delay_months` stochastisch (3.9, 4.3.7); `repayment_grant.cut_share` (8.2) |

**Runde 3: Feldkatalog-Abgleich** (Änderungsanträge S01A/S01B/S01C und Befunde X-nn/F-nn der Konsistenzprüfung von
Spec 01; Einzelnachweis in 17.5):

| Nr. | Thema | Positionen | Festlegung |
|---|---|---|---|
| R-85 | Defaults-Dateien | S01A-01 (`by_project_type`, `defaults_meta`), X-06 (Element-Defaults von Teil B ohne zulässigen Ort, Profilwerte für Gruppenfelder entgegen R-76) | reservierte Wurzelschlüssel `defaults_meta`, `by_project_type` (unmittelbar nach der eigenen Datei gemischt, im Profil mit R-76) und `item_defaults` (nur `global.yaml`; Vorlage je Sammlung bzw. optionalem Block, nach Schicht 8 und den Ableitungsregeln unter jedes Element gemischt, Element gewinnt, Platzhalter `{id}`; Defaults optionaler Blöcke nur dort); sonst Validierungsfehler (4.2, 4.7, 4.8, 13.1) |
| R-86 | Ableitungsregeln | S01A-06, X-06, X-07 (Förderregeln von WS-E2 in früheren Wellen aufgerufen), S01B-13, X-25 (PV-USt) | WS-A-Regeln `rule:<name>` nach Schicht 8, **vor** `item_defaults` (spezifisch vor allgemein; abweichend vom Antrag) und vor den Expandern, je Variante/Set/Override neu; setzen nur fehlende Blätter bzw. lösen `auto` auf, schreiben Werte, Codes, `ref`-/`expr`-Knoten, nie berechnete Konstanten; Herkunft `type_default`/`rule:<name>`; `rule:approval_timing`, `rule:approval_probability` (mit neuem Feld `availability_after_2030`) statt Registry-Regeln `fund_approval_*`; PV-Nullsatz als `expr`-Knoten aus `rule:measure_catalog` (4.3.7, 4.7, 5.3, 7.10, 11.6) |
| R-87 | Auflösung von `from:` | S01A-02 (`deep_merge(Skalar, {})`), S01C-11 (a), S01C-13 | Nutzlast ohne Map-Struktur (Skalar, Sequenz) oder Wertform ersetzt den Knoten, lokale Zusatzschlüssel sind dann Fehler; `from:` in Varianten-/Set-Operationen und `item_defaults` wird nach der Operation aufgelöst; `processes/*`-Nutzlasten als Map mehrerer Vorlagen (`use:`) bzw. als Korrelationsliste (4.3.15, 4.7, 4.9, 4.11) |
| R-88 | Bibliothekseintrag und Freigabe | S01C-08, S01C-02 (`fallback`), S01B-09, X-29 | Eintragsschema um `description`, `references`, `quality_detail` (Herkunft je Blatt), `legal_state` (Pflicht für `legal/*`, `funding/*`), `notes`, `fallback` ergänzt, andere Wurzelschlüssel Fehler; automatisch angewandte C/D-Teile eines A/B-Eintrags als eigener Eintrag mit eigenem Thema; `valid_to` nur bei tatsächlichem Ende, Fortgeltung mit `valid_to: null` (4.8, 4.9, 4.10) |
| R-89 | Vokabulare v1 | S01A-09, X-01 (Codes der Fördernutzlasten nicht im Katalog), X-08 (`559` vs. `bgb_559`), X-27 | 37 Maßnahmentypen aus Teil A §4.2 (keine Sammelcodes), Enums aus Teil A §8.1/Teil B §8, `federal_state`, `levy_procedure` mit `bgb_`-Codes und Aliasen, `bgb_procedure`, `overlay_apply`, `growth_index`, `mc_preset`; Codes in Bibliotheksnutzlasten ⊆ Vokabulare (Test WS-L) (2.11, Anhang B) |
| R-90 | Expander-ids | S01A-04, S01B-01, X-33, X-20 | vollständige id-Liste je Expander (u. a. `m_<m>_purchase`, `m_<m>_acq`, `m_maintenance`, `m_<e>_repl`, `u_<g>_opex`, `e_<s>_<c>_cost`/`_co2`, `e_pv`, `e_tenant`, `f_<f>_35c`, `f_<f>_subsidy`, `h_equity`, `h_contrib`, `rv_value`); Energiekomponenten je Zustand × Träger; Prüfung „erzeugte id ≤ 40“ mit Höchstlängen der Nutzer-ids (4.4, 4.12, 7.10) |
| R-91 | Wertgrammatik | S01A-03, S01A-05, S01B-06, X-12 | `quantity.per` + `m2_net_floor_area`, `parking`; `node_expr()`; Wachstumsform als **Kalenderjahreswert** (`index: calendar_year`, Default) bzw. Stichtagswert (`index: period_end`, Orakel (c)); nicht-numerische Pfadsymbole in Ausdrücken mit `setting`-Semantik nur in Vergleichen und Logik (4.5, 4.7, 6.3, 6.4, 15.3) |
| R-92 | Expandertest, Basisfall im Build | S01B-04, S01B-10 | Ausnahmen des Expandertests (deterministische Arten, Kreditbeträge, `draw_schedule`, Sequenzelemente, Rechts- und Bibliothekswerte); `bctx$value_base()` nur für deterministische Ableitungen (4.12 Nr. 5, 6.4) |
| R-93 | Typverträge | S01B-02, S01B-05, S01C-04, S01C-05, X-21 | optionales Typdef-Feld `domain_reads` und Domänenlesezugriff (6.1 Nr. 3); `ctx$rows()` mit Filtern `measure_id`, `local_row`, `id` als Vektor; Quantilfunktionen monoton (Bernoulli 1{u > 1 − p}, `empirical` mode = Median); `n_shocks`/`n_uniforms` nur strukturabhängig; `returns: value`; Regeln ohne `ctx` auch in Defaults von Formals (5.2, 5.3, 5.6, 6.2) |
| R-94 | Overlay-Verknüpfung `apply` | S01C-01 | `apply` ∈ `replace`, `multiply`, `add` für statische Einträge; `ctx$param()` liefert b · x bzw. b + x; `draws$static` = x; Designspalte „Schlüssel“ setzt x, Designspalte „Zielpfad“ den absoluten Wert (4.3.15, 6.3, 11.2, 11.8, 11.11) |
| R-95 | Prozesse | S01C-02, S01C-03, S01C-10, S01C-12 | Token `base` für Startparameter (Start am Basisfall); `linked_ar1.u0`; `mr_trend.p_norm` (Mean-Reversion zum Normalpreis); `vasicek.expected` mit Floor; optionale Funktion `quantile_path()` und Prozess-Designspalten; `generate.params`/`exclude` des Sets „vorsichtig“ (4.11, 5.3, 5.6 P4, 11.7, 11.11) |
| R-96 | Overlay in Varianten, Korrelationspaare | S01C-11 (b), S01C-08 | Overlay-Einträge dürfen in Varianten und Sets hinzugefügt, geändert, entfernt werden; fehlende Ziele sind dort Fehler; Bibliothekspaare mit fehlendem Schlüssel werden verworfen, Szenariopaare sind Fehler (4.3.15, 4.7, 4.11, 11.6) |
| R-97 | Presets, Konvergenz | S01C-14 | `settings.preset` (`preview`/`standard`/`report`/`custom`) mit Vorrangregel (Argumente > Schichten ≥ 3 > Preset > Schichten 0–2), `global.yaml` ohne `n_sim`; `settings.convergence`, Spalte `converged` (4.3.15, 12.7, 13.2, 14 Nr. 15) |
| R-98 | Termine von Einmalzahlungen | F-07, X-11 (zwei Konventionen für Monate und Daten), S01B-12 | eine Regel: Monat m = (b_0 + (m − 1), b_0 + m] Monate; laufende Wirkungen ab mi(d); Einmalzahlungen haben ein Datum als Termin (Bezugsdatum + Fristen + Verschiebung) und werden nach R-35 gebucht; „im Monat m“ = Monatsbeginn; § 35c-Termin `add_months((Y+1)-01-01, payout_delay_months)`; Energieberatung außerhalb des Jahres-, innerhalb des Gesamtdeckels. X-11-Vorschlag „Monatsereignis in p(m)“ abgelehnt (3.4, 3.9, 10.9) |
| R-99 | Förderkredite | S01B-10, S01B-11 | `approved` = Zusage × max a_m der geförderten Maßnahmen, Kreditbetrag bei Teilwegfall fest; Merkzeile `repayment_grant` mit `measure_id` oder `funding_id`, Anzeige-Tag `measure_id` = größte geförderte Maßnahme im Basisfall (4.12 Nr. 7, 7.6, 8.2) |
| R-100 | Annuitätendarlehen | X-13, F-10 | τ und `term_years` zugleich zulässig (Rate aus τ, Fälligkeit aus `term_years`), τ mit `installment_eur` Fehler; nach Gutschrift eines Tilgungszuschusses mit `shorten_term` rechnet `keep_term` mit der effektiven Restzahl der Raten (Laufzeitverkürzung bleibt erhalten) (8.2, 8.6) |
| R-101 | Kennzahlen | S01B-03, S01B-07, X-30, S01C-14 | Warmmiete je **vermietetem** m²; `co2_emission` = Treibhausgasbilanz aller Träger; `restriction_liquidity` ohne endliches Limit und ohne endliche Schwelle NA `no_liquidity_limit` (kein K.-o.); `converged` (7.6, 12.3, 12.4, 12.7, 12.9) |
| R-102 | Bezugsperiode „warmmietenneutral“ | S01B-08 | erste Periode mit 12 Monaten, die am oder nach dem frühesten Wirksamkeitsmonat der Umlage im Basisfall beginnt (4.3.6a, 6.3) |
| R-103 | Marktnamen | S01C-07, X-32 | kanonische Namen + `operating_cost_growth`, `bund_yield_10y`, `mortgage_spread`, `feed_in_tariff.<klasse>`, `vacancy_fluctuation`; Trägercodes nach Teil B §3.2.1 mit Marktpreis für jeden kanonischen Träger; Energiepreise, Netzentgelte, Bio-Mehrkosten und CO2-Preis netto (4.3.11) |
| R-104 | Dateien, Tests, Labels | X-07 (Testeigentum Rechtsregeln), X-22, X-23 | Set „vorsichtig“ in `R/compare.R`; Testdateien `test-<R-datei>.R`, Datentests `test-library.R` (WS-L) und `test-profiles.R` (WS-A); Validierungsschlüssel `validation.<block>.<code>` in `inst/labels/de/validation.yaml`; Rechtsregeltests bei WS-E bzw. WS-E2 (2.2, 2.4, 2.10, 15.6) |
| R-105 | Referenzszenario-Konventionen | S01C-06, X-14 | S5 mit `payments_per_year: 12`, S1–S4 mit 1; Verschiebungen ≥ 0, vorgezogene Termine als früherer Basistermin mit Verschiebung (3.9, 15.6, 17.2 F-18) |
| R-106 | Feldlisten | S01A-07 | Feldlisten in 4.3 sind Auszüge; maßgeblich für Schema und Validierung sind die Feldtabellen von Spec 01 (4.3) |
| R-107 | Pflichtsensitivitäten | S01C-09 | `value` darf eine Wertform sein und ersetzt den Knoten einschließlich `anchor`; `delta` wirkt bei `anchor` auf den Anker; Ausführung als Override in Schicht 8 (4.3.14) |
| R-108 | Komponenten-Zeitwert | F-09 | ohne Indexierung nominaler Buchwert der letzten Investition × Restanteil, mit Indexierung zusätzlich Baupreisindex; Prüfwert RV8 = 82.853,16 (4.12 Nr. 8; Spec 01 Teil A §6.7) |
| R-109 | Abgelehnte Anträge | S01A-08 (Umlenkung von Overlay-Zielen), S01C-15 (`shared` in Szenario-Sets) | keine stille Umlenkung (Pfad-Identität, R-16): Ziel auf abgeleitetes `cost_eur` bzw. auf `remaining_life_years` bei Methode ≠ `manual` ist ein Validierungsfehler mit Vorschlag des Ersatzziels; Szenario-Sets bleiben auf die Umfeldpfade beschränkt, szenarioeigener `market`-Pfad als Muster (4.11) |

---

## 17. Review-Protokoll

### 17.1 Änderungsprotokoll

| Version | Datum | Änderung | betroffene Pakete |
|---|---|---|---|
| 1.0.0 | 25.10.2026 | Erstfassung | alle |
| 1.0.0 | 25.10.2026 | Überarbeitung nach Review Runde 1 (49 Befunde, 17.2); vor dem Einfrieren in Phase 0, daher ohne Versionssprung. Neue Auflösungen R-60 bis R-65 | alle |
| 1.0.0 | 25.10.2026 | **Runde 2: Abgleich mit Konzept** (Konzept §11.1–11.3 und Konzept-Review-Protokoll; 21 Abgleichpunkte, 17.4); vor dem Einfrieren in Phase 0, daher ohne Versionssprung. Neue Auflösungen R-66 bis R-84; R-02 und R-14 ersetzt; Signaturänderungen in 14 Nr. 12, 15, 19, 20, 21 | alle; Schwerpunkte WS-D, WS-G, WS-D2, WS-C, WS-F, WS-E/E2, WS-A, WS-L, WS-T, Spec 01 |
| 1.0.0 | 26.10.2026 | **Runde 3: Feldkatalog-Abgleich** (37 Änderungsanträge S01A-01–09, S01B-01–13, S01C-01–15 und 19 Befunde mit Spec-00-Bezug aus der Konsistenzprüfung von Spec 01; 17.5): 35 Anträge angenommen (davon 17 mit Änderung), 2 abgelehnt (S01A-08, S01C-15). Neue Auflösungen R-85 bis R-109; verbindliche Namens- und Eigentumsentscheidungen N-01 bis N-31 (17.5.3). Vor dem Einfrieren, daher ohne Versionssprung; die Änderungen sind additiv (MINOR/PATCH) bis auf den Vokabularbestand `measure_types` und die Auswertung der Wachstumsform, die bereits geschriebenen Phase-0-Code betreffen (**Phase-0-Nacharbeit**, 17.5.4) | I (Phase-0-Nacharbeit), WS-A, WS-B, WS-C, WS-D, WS-E, WS-E2, WS-F, WS-G, WS-L, WS-S, WS-T, Spec 01 A–C |

### 17.2 Review-Befunde Runde 1 (zwei adversariale Reviews: Linse „finanz“ F-nn, Linse „software“ S-nn)

Geprüft gegen diese Spezifikation, die Memos 01–07 und – wo möglich – durch Nachrechnen bzw. Ausführen in R 4.3.3.
Entscheidung: **übernommen** (Befund gültig, Empfehlung umgesetzt), **teilweise** (Befund gültig, andere oder
eingeschränkte Lösung), **abgelehnt** (Befund ungültig). Kein Befund wurde abgelehnt.

| ID | Linse | Schwere | Abschnitt(e) | Entscheidung | Begründung |
|---|---|---|---|---|---|
| F-01 | finanz | blocker | 9.4, 9.7 N2, 12.1 | übernommen | Nachgerechnet bestätigt: `equity_call` in der Ex-RV-Wiederholung bricht N2. Neu: S' = S_T − RW_T + NS_T, D4-Zuflüsse werden durch interne KKP-Buchung ersetzt (`gap`), N2 gilt per Konstruktion, Prüffall in 9.4 (R-61). |
| F-02 | finanz | blocker | 8.2, 8.6, 8.10 | übernommen | Bestätigt (Annuitätenformel als Tilgungsrate). `refi` je Tilgungsart: Ratentilgung `keep_term` = B/n_rem, `keep_payment` = Rate unverändert, `keep_tilg_rate` = Validierungsfehler; Pflichttest (g) mit Sollwerten (seit Runde 2: Test (h), R-66). |
| F-03 | finanz | blocker | 9.5, 15.4 | übernommen | Bestätigt; widerspricht D9 und Memo 01 §4.2. Die Alternative erhält keine eigenen Nachschüsse; `equity_call`/`stop` laufen dort als `penalty_rate` (KKP, Konditionen nach R-23 statt KK zu s), Flag `opp_limit_breach`, Prüffall ΔEW = 15.000. |
| F-04 | finanz | major | 15.4 I4, I5 | übernommen | I5 auf f aus 12.8 (mit ΔNS) umgestellt, Schranke −T_J nur bei nichtnegativen Zinsen; I4 auf Jahresraster, ppy = 1, ohne Gebühren/Disagio und mit unbegrenztem KK beschränkt; Generatorregel G für WS-T. |
| F-05 | finanz | major | 3.6, 7.12, 5.6 F10 | übernommen | Abweichung −8,6e-3 nachgerechnet. Kalenderjahresindex `grid_index_year()`/`ctx$index_year()` für laufende Jahresbeträge (R-62); `recurring` umgestellt, F10 gilt auch bei Wachstum; Konvention für alle laufenden Beträge festgelegt. |
| F-06 | finanz | major | 4.12, 2.2, 4.3.6a, 10.8 | übernommen | Zyklus § 558/§ 559 bestätigt (Memo 02 §2.1–2.3, `mietpfad_ref.py`). Eine monatliche Komponente `rent_path` mit Zeilen `rent`, `rent_loss`, `levy_<maßnahme>`; §§ 558/559/559c/559e als Regeln; `type-flow-modernization-levy.R` gestrichen (R-63). |
| F-07 | finanz | major | 12.3, 12.6, 14 Nr. 28 | übernommen | Bestätigt (Memo 07 §5.2 Persona c). Neue Kennzahlen `monthly_net_cashflow` (+ `_y1`, `_min`) und `monthly_cashflow_change_y1` für `kleinvermieter`; `monthly_burden`/`burden_ratio_max` nur `selbstnutzer`. |
| F-08 | finanz | major | 4.3.14, 9.6 Nr. 7, 12.3a | teilweise | Problem bestätigt (Memo 07 S4). `analysis.primary_kpi = auto` macht `delta_vs_reference` bei Sanierung/Heizungstausch (Modus `absolute`) zur Primärkennzahl, ΔEW mit Vermerk; fehlende Referenzvariante nur als Plausibilitätswarnung (kein Pflichtfehler, damit Einzelvarianten rechenbar bleiben); `erwerb_*` behält ΔEW. |
| F-09 | finanz | major | 3.9, 4.3.2, 4.3.6, 5.4, 6.2 | teilweise | Bestätigt (Memo 04, Memo 07 S1/S2/S4). Laufspezifische Verschiebungen in Zahlungskomponenten (Token `completion`, `ctx$timing()`, `ctx$shift_*()`, Pfade `project.construction_delay_months`, `measures.<id>.delay_months`, stochastische Nutzungsdauer); Raster und Kredittermine bleiben deterministisch (R-47), Bauzeitzinsen nur über den Ausgleich (R-60). |
| F-10 | finanz | major | 4.4, 4.5 Regel 4, 11.7 | übernommen | Bestätigt. Elemente von `points`/`series_*` dürfen skalare Knoten sein; Unsicherheit über statische Overlay-Einträge auf `shared`-Blätter (R-64); kein neuer Prozesstyp nötig. |
| F-11 | finanz | minor | 8.8, 9.3 (6a), 9.8 | übernommen | Bestätigt. Limitüberhang wird zu Beginn des Ausgleichs zwangsweise getilgt und als Defizit durch die Kette gedeckt (Policy greift), Flag `limit_cut`; I3c bleibt gültig. |
| F-12 | finanz | minor | 8.1 Nr. 3 | teilweise | Beobachtung zutreffend; Orakel (e) verlangt die Buchung je Rasterperiode. Semantik ausdrücklich festgeschrieben (Zinsen in der Rasterperiode ihres Entstehens, Tilgungen in Vertragsfrequenz); Parameter `interest_payment` erst v2. |
| F-13 | finanz | minor | 5.6 A2 | übernommen | Vorzeichenfehler bestätigt (`dep_invest`: G +a, Zeile −a); A2 auf „− Summe der geschriebenen Flüsse“ korrigiert. |
| F-14 | finanz | minor | 5.6 F4, 7.1, 7.6, 7.12, 9.3 | übernommen | Bestätigt. `principal` für Flows verboten, `memo` nur mit `cash = FALSE` (F4), `E` auf `project`/`grants`/`equity` beschränkt; I1/I2 damit konsistent. |
| F-15 | finanz | minor | 10.4 | übernommen | Bestätigt. `tax_inputs` zeilengenau mit Metadaten und `extra`; Vorzeichenkonvention im Steuer-Input (Aufwand negativ, `disagio` negativ eingestellt). |
| F-16 | finanz | minor | 7.6, 7.12 | übernommen | Bestätigt. `other_cost` ist NOI-relevant; Hinweis bei `recurring` ohne Kategorie für `wu_*`. |
| F-17 | finanz | minor | 3.2, 3.3, 3.8, 12.2 | übernommen | Bestätigt (G4: 15-monatiges Betriebsjahr 1). `calendar`: Betriebsjahre = Kalenderjahre, Stub als Teiljahr, neues Feld `op_year_full`; `_y1`-Kennzahlen auf das erste volle Jahr; Sollwerte G4/G5. |
| F-18 | finanz | minor | 4.3.2, 15.6 | übernommen | Bestätigt. S1–S5 mit `payments_per_year: 1`; „Kostenstand Y“ → `price_base_year: Y − 1`; Plausibilitätswarnung bei Preisindex < 1 in t = 0. **Runde 3 (R-105, S01C-06):** S5 abweichend mit `payments_per_year: 12` (Monatsraten nach Memo 07 §4.5). |
| F-19 | finanz | minor | 4.3.5, 12.3, 12.4 | übernommen | Bestätigt (Memo 07 Persona e). Kennzahl `monthly_burden_construction` mit optionaler bisheriger Miete `household.current_rent_month_eur` (ohne Ledger-Zeile, ΔEW unberührt), NA-Code `no_construction_period`. |
| F-20 | finanz | minor | Anhang B | übernommen | Bestätigt. Variante `ohnehin` entfernt `modernization_kind` und setzt `ohnehin_share: 1`, `classification: erhaltung` (Map-Merge am existierenden Pfad, 4.11). |
| F-21 | finanz | minor | 3.6 | teilweise | Bestätigt. Jahreswerte vor dem Stichtag aus `series_year`/`points` über das Pfadattribut `annual_before`; fehlen sie, Rate des Bewertungsjahres mit Hinweis. Keine neue ctx-Funktion. |
| S-01 | software | blocker | 9.4, 9.7 N2 | übernommen | Gleicher Befund wie F-01, gleiche Lösung; Nachschüsse beider Sichten identisch, damit `_ex_rv`-Kennzahlen zur Alternative passen; Prüffall Privatprofil mit Restwert. |
| S-02 | software | blocker | 4.3.8, 4.4, 4.13, 6.2, 6.3, 11.2 | übernommen | Bestätigt. Typparameter flach mit reservierten Metafeldern, Pfad-Identität YAML = Spec = Overlay = Herkunft = `ctx$param()`; `param()` mit Map-Unterpfaden, neue Funktion `ctx$setting()` für nicht-numerische Parameter. |
| S-03 | software | major | 6.2, 12.1, 12.8 | übernommen | Bestätigt. `ctx$rebalance(extra_out)` (nur in Kennzahlen, ohne Buchung, mit Instrument-Cache), Signatur `kpi_withdrawal_equivalent(core, ctx, tol, max_iter)`, `vofi_solve()` verweist darauf. |
| S-04 | software | major | 9.2, 9.6, 11.8, 11.10 | übernommen | Bestätigt. `eng_run_chunk()` um `raw`, `extra_rows`, `return_paths`, `kpis` erweitert; Rückgabe mit `paths`, `registers`, `draws`; `smp_plan_union()` mit Eigentümer WS-C. |
| S-05 | software | major | 11.3, 11.4, 11.6, 15.5 | übernommen | Locale-Abhängigkeit und `chol`-Abbruch nachgeprüft. Kanonische Ordnung `method = "radix"`, Strom `ic:<key>:<b>`, Mindestblockgröße m ≥ max(2, d + 1), Test 15.5 Nr. 7. |
| S-06 | software | major | 3.6, 5.6 F10, 7.12 | übernommen | Wie F-05 (14.157,09 vs. 14.280,00 nachgerechnet); zusätzlich Prüfraster mit gleichem `end_date` und Pflicht, rasterabhängige Termin-Defaults im `example` explizit zu setzen. |
| S-07 | software | major | 4.3.10, 8.9, 9.7 I3b | übernommen | Bestätigt. Kettenregeln verbindlich: `od_repay` zuerst, `dep_withdraw` zuerst, Ränge streng aufsteigend, Verstoß = Validierungsfehler; I3b folgt daraus. |
| S-08 | software | major | 8.8, 9.3, 9.7 I3c | übernommen | Wie F-11; Zwangstilgung mit Deckung durch die Kette statt reiner Umbuchung nach KKP, damit Guthaben und Policy (privat: Nachschuss) greifen. |
| S-09 | software | major | 4.4, 4.7 | teilweise | Bestätigt. `is_value_form()` schemagestützt bzw. strukturell (vollständige Schlüsselmenge genau einer Wertform), Prüfung auf der Override-Seite; Umbenennung von `start` nicht nötig, weil ein Kreditbaustein die Strukturregel nie erfüllt. |
| S-10 | software | major | 2.2, 2.10, 2.11, 5.6 C4, 7.1, 10.5, 12.4 | übernommen | Bestätigt. Schlüssel `types.<kind>.<name>.*`, Dateien `types/<kind>/<name>.yaml`, Regeln ohne `@Datum`; KPI-Labels unter `types.kpi`; NA-Codes nur `vocab.na_reasons`; Kategorien `vocab.categories.<section>.<category>`. |
| S-11 | software | major | 2.7 Nr. 1, 15.6, 15.7 | übernommen | Mit R 4.3.3 nachgeprüft (`showNonASCIIfile` meldet Kommentare, `R CMD check` nicht). ASCII-Test über `getParseData()` ohne `COMMENT`; Euro-Zeichen im Code als Unicode-Escape. |
| S-12 | software | major | 2.4, 5.2, 5.6, 6.1, 15.1 | übernommen | Bestätigt. Prüfkit `R/registry-testkit.R` (I) mit `reg_test_grid`, `reg_fake_draws`, `reg_test_ctx`, `reg_example_core`; `eng_context_from_parts()` (WS-D); `example` in Rohform; K1 mit `ctx`. |
| S-13 | software | major | 2.3, 2.4, 4.5 Regel 5, 6.3 | übernommen | Bestätigt. Signaturen `expr_parse`/`expr_symbols`/`expr_eval`, Formregel, Whitelist (ohne `min`/`max`/`&&`/`\|\|`), Minimalfassung in Phase 0. |
| S-14 | software | major | 2.3, 2.4, 5.1, 5.3 | übernommen | Alternative gewählt: `rules-mietrecht.R`, `rules-co2kostaufg.R`, `rules-grest.R` gehen an WS-E (Welle 2b), Regelkonvention mit `returns`; Spec-01-Katalog nur für paketübergreifend aufgerufene Regeln. |
| S-15 | software | major | 2.12, 9.2, 9.3, 9.9, 9.10, 10.4, 12.8 | übernommen | Bestätigt. Instrument-Cache ohne `loan_prepay`, Argument `kpis`, Illinois-Verfahren erlaubt, eigenes Budget für das Entnahme-Äquivalent, `vofi.chunk_size` 2000, keine `tax_inputs` bei `uses_inputs = FALSE`. Toleranz 1e-6 bleibt (Orakel), weil der Cache die Iteration billig macht. |
| S-16 | software | minor | 9.2, 14 Nr. 15 | übernommen | Bestätigt. `vofi_run()` bildet `auto` auf `bands` ab; `vofi_mc(store = NULL)` mit Auflösung Argument → Settings → `bands`. |
| S-17 | software | minor | 6.3 | übernommen | Nachgeprüft (`x[m] <- y[m]` verlängert). Schritt 4: `scalar` immer `as.double(rep_len(x, n))`, `path` immer double n × (T+1). |
| S-18 | software | minor | 7.1, 9.3, 14 Nr. 36 | übernommen | Bestätigt. `cash = NULL` (Kategorie-Default), `E` mit Abschnittsfilter, `cash = TRUE` in `memo` ist Vertragsfehler. |
| S-19 | software | minor | 4.6 | übernommen | Nachgeprüft (`150.000` → `float#fix`, `3,5` als Rohtext an `int`, Überlauf → `NA`). Handlernamen festgelegt, `int` nimmt große Zahlen als double, numerische Blätter als double gespeichert. |
| S-20 | software | minor | 4.3.9, 4.4, 7.3, 7.7 | teilweise | Mehrdeutigkeit bestätigt. Trenner `__` für Komponenten- und EK-Schlüssel, ids über `components` ∪ `financing` eindeutig, `x_extra_equity_out` → `extra_equity_out`; Präfix-Reservierungen entfallen, da Engine- und Kreditschlüssel nie `__` enthalten. |
| S-21 | software | minor | 2.4, 2.2, 6.4, 10.5 | übernommen | Bestätigt. Eigentümer für `bctx`/`node_*` (WS-A), `vofi_tol` (I), Methoden in der Datei des Klasseneigentümers, Tests/Fixtures/Bench/README zugeordnet, Modul-Labels in `types/tax/<modul>.yaml`, `excel.yaml` aufgeteilt. |
| S-22 | software | minor | 10.2 | übernommen | Bestätigt. `vofi_tax_module_simple()` rechnet periodenweise (`fun(inputs, params)` → n-Vektor); keine MAJOR-Änderung an `tax_init()`. |
| S-23 | software | minor | 2.7 Nr. 8, 5.5, 9.1, 11.6, 11.7 | übernommen | Nachgeprüft (C vs. C.UTF-8). `sort()`/`order()` stets mit `method = "radix"`. |
| S-24 | software | minor | 2.8 Nr. 8, 5.6, 15.1 | übernommen | Bestätigt. Jahresprüfraster mit T = 6, damit n = 7 = T+1; Signatur `n = c(1L, 2L, 7L)` bleibt. |
| S-25 | software | minor | 5.2, 7.10 | übernommen | Bestätigt. Feste USt-Suffixe `_vat19`/`_vat7`/`_vat0`, je Energieträger eine Komponente, Zeilenmuster `<präfix>_*` mit Label-Platzhalter `{id}`. |
| S-26 | software | minor | 8.3, 8.7 | übernommen | Bestätigt. `t_first_draw` = erste Fensterperiode (deterministisch), Bearbeitungsgebühr auf die Zusage in dieser Periode. |
| S-27 | software | minor | 4.12 Nr. 5, 6.4 | übernommen | Bestätigt. `bctx$rule()`/`legal()` nur auf deterministische Eingaben; wertabhängige Regeln in Flows über `ctx$rule()`; Validierung meldet aus Overlay-Zielen abgeleitete Konstanten. |
| S-28 | software | minor | 5.4, 8.1 Nr. 2, 8.2 | übernommen | Bestätigt. `deterministic_only` = harte Sperre (auch implizit für nicht-numerische Arten), `stochastic` = Hinweis mit Plausibilitätswarnung; Zeitparameter in 8.2 ausdrücklich gesperrt. |

Summe: 49 Befunde; 43 übernommen (S-14 mit der vom Review genannten Alternative), 6 teilweise (F-08, F-09,
F-12, F-21, S-09, S-20), 0 abgelehnt.

### 17.3 Offene Punkte nach Runde 2

1. **Spec 01** konkretisiert (Stand Runde 1): Parameter von `rent_path` (Maßnahmenbezug, § 559a-Abzug, Strategie der
   § 558-Erhöhungen), die Verschiebungsfelder (3.9) je Typ, `household.current_rent_month_eur`, den Regelkatalog für
   paketübergreifend aufgerufene Regeln (5.3) und das Enum `modernization_kind`. **Neu aus Runde 2:** Profilwerte je
   Perspektive für alle Konto- und Analysefelder (4.3.10, 4.3.14, 4.7; Konzept A2, A3, A4, F18 inkl. `anchor`-Kopplung
   im MC), Inhalte von `mandatory_sensitivities` (Konzept 5.5), `restrictions` je Perspektive, Werte von
   `traffic_light` und `thresholds`, `lending_value_haircut`; Felder `building.existing_value_eur`,
   `household.expected_income_tax_eur_pa`, `measures.<id>.active`, `energy.<zustand>.jaz_plan`, Vorlauftemperatur,
   `performance_gap` (Strukturmodell), `funding.<id>.{approval_timing, fallback_variant, on_reject}`,
   PV-Begünstigungsattribut, Modus „warmmietenneutral“ in `rent_law`; Parameter `existing`, `installment_eur`,
   `rank`, `approved`, `repayment_grant.cut_share` der Kredittypen; Sets `foerderstopp` und `vorsichtig` in
   `global.yaml`.
2. **Option „Zinsen mit der Rate“** (`interest_payment`, F-12) und stochastische Kredittermine bleiben v2 (R-47);
   damit verschiebt ein Bauzeitverzug Bereitstellungszinsen in v1 nicht (dokumentierte Grenze zu Konzept 4.2).
3. ~~Rate der eigenen Fehlbeträge der Unterlassungsalternative~~ – **erledigt** durch R-81 (Regelzins s bei
   `equity_call`/`stop`, sp bei `penalty_rate`).
4. **Leistungsbudget** (9.10) mit Instrument-Cache und `chunk_size = 2000` ist durch den Benchmark von WS-D/WS-G in
   Welle 1/3 zu bestätigen, jetzt einschließlich Entscheidungsknoten, Set „vorsichtig“ und `incremental_return`; bei
   Überschreitung entscheidet der Integrator über Toleranz bzw. Budget.
5. **Bestätigung R-73 durch Orchestrator bzw. Auftraggeber:** Die feste Blockgröße 200 weicht vom Wortlaut D8
   („LHS in 10 Blöcken“) und von Konzept F21 („10 Replikate zu je N/10“) ab. Begründung in 11.4; der F21-Modus bleibt
   über `stochastic.settings.replicates: 10` ohne Codeänderung verfügbar. Wird F21 bestätigt, ist nur der Default in
   11.4 umzustellen.
6. **`incremental_return` je Lauf in der MC** (verteilte Rendite der Mehrinvestition) ist v1.1; v1 rechnet sie
   deterministisch (12.6, 12.8).
7. **Entscheidungsknoten:** v1 erlaubt höchstens einen Knoten je Variante und keine Ketten von Ausweichvarianten
   (9.11 Nr. 1); mehrstufige Entscheidungsbäume sind v2.
8. **Neu aus Runde 3:** (a) Maßnahmentyp `sonnenschutz` (sommerlicher Wärmeschutz, BAFA-förderfähig) ist in v1 kein
   Katalogcode (N-01); Aufnahme als 38. Code nur über einen Antrag von Teil A mit Katalogzeile. (b) Automatische
   Blockerweiterung bis zum Konvergenzkriterium (`converged`) ist v1.1 (R-97). (c) Energiepreis-Basisfall: Ob der
   deterministische Pfad dem Erwartungswert des `mr_trend` folgt (Mean-Reversion zum Normalpreis, Befund F-08 von
   Teil B/C), entscheidet Teil C mit der Bibliothek; Spec 00 stellt dafür `p_norm` und `quantile_path()` bereit (R-95).
   (d) Regel `mr_levy_allowed`: Abbildung `bgb_559c` → `bgb_559` für die Ausschlussprüfung nach § 557a (N-06) ist
   fachlich durch Teil B zu bestätigen.

### 17.4 Runde 2: Abgleich mit dem Konzept (Einzelnachweis)

Geprüft wurden Konzept §11.1 (D1–D14), §11.2 (F1–F21), §11.3 (Annahmen A1–C12, gelten bis zur Antwort des
Auftraggebers) und die Übernahmeliste des Konzept-Review-Protokolls gegen alle Abschnitte dieser Spezifikation.
Übernommen wurde, was Verträge, Strukturen oder Engine-Semantik berührt; reine Feld-Defaults gehen an Spec 01 (17.3
Nr. 1). Spalte „Änderung“ nennt die geänderten Abschnitte.

| Nr. | Konzept | Abgleichpunkt | Ergebnis | Änderung |
|---|---|---|---|---|
| K-01 | F17, 2.5, 2.6, L1, 8.3 WS-T | Vergleichsregel ΔEW_A − ΔEW_B mit eigenen Nachschüssen; ungleiche Nachschüsse kein Fehler; Orakel (g) | übernommen (R-66); Namenskollision mit dem Spec-Test „(g)“ Ratendarlehen aufgelöst: Konzept-Orakel bleibt **(g)**, Ratendarlehen-Test heißt **(h)** | 1.1, 1.5, 8.10, 9.6 Nr. 2–4, 12.6, 15.1, 15.3 (Orakel (g) mit Sollwerten), 15.4 V1, 15.6, 16.3 |
| K-02 | F16, A3, 2.8, L2 | Horizontende als festes Kalenderdatum für alle Varianten und Läufe | übernommen (R-67); R-02 ersetzt, `horizon_from` gestrichen; abweichende Bauzeiten bleiben vergleichbar (gleiches `end_date`) | 3.3, 4.3.2, 4.3.3, 9.6 Nr. 2, 5, 9, 14 Nr. 12, 16.3 (R-02, R-49) |
| K-03 | 2.6, 3.10, A9, P1, P7, F17 | Bestandswert als Sacheinlage (inkl. Behandlung in der Unterlassungsalternative), Bestandsdarlehen identisch in allen Gebäudevarianten, Rendite der Mehrinvestition, reine Unterlassung als Referenz unzulässig | übernommen (R-68); Prüffall Sacheinlage mit Sollwerten; Plausibilitätswarnung aus F-08 durch Validierungsfehler mit ausdrücklicher Ausnahme ersetzt | 1.5, 4.3.2, 4.3.4, 4.3.9, 4.3.14, 7.4, 7.6, 7.7, 7.8, 8.2, 8.4, 8.5, 9.3, 9.5 Nr. 7, 9.6 Nr. 2, 7, 9.7 I2, 12.2, 12.3, 12.3a, 12.4, 12.6, 12.8 |
| K-04 | F15, 3.10, 4.2, P10 | Kreditbeträge im Basisfall fest, keine Neubemessung je Lauf; optionale Nachfinanzierung; Tilgungszuschuss auf festen Zusagebetrag | übernommen (R-69): Basisfall-Vorlauf in `vofi_build()`, `amount_eur` `deterministic_only` und als Basisfallwert gelesen, `approved` je Kredit, `topup` | 4.3.9, 4.5, 4.13, 5.4, 6.2, 8.1, 8.2, 8.3, 8.5, 8.6, 8.7, 9.1, 9.2, 11.11, 15.5 Nr. 10 |
| K-05 | 3.5, 3.8, 4.2, P5, P6 | Plan-JAZ (deterministisch, § 559f) getrennt von realisierter JAZ (stochastisch); Beschluss- bzw. warmmietenneutrale Umlage im Basisfall fest | übernommen (R-70): allgemeiner Mechanismus Basisfallwerte (`ctx$param_base()`, `value_base()`, `component_base()`), Feld `jaz_plan` | 1.5, 2.8 Nr. 2, 4.3.6a, 4.3.6b, 6.1, 6.2, 6.3 |
| K-06 | 3.9, 4.2, 4.5, B12, D8, P3 | Förderzusage vor Projektbeginn als Entscheidungsknoten mit Ausweichvariante und bedingter Auswertung; einfache Bernoulli-Ziehung für spätere Stufen; Restrisiken nach Zusage | übernommen (R-71): Felder `approval_timing`, `fallback_variant`, `on_reject`, `measures.<id>.active`; Rolle `decision` im Sampler; Kompositlauf; Set `foerderstopp` | 3.9, 4.3.6, 4.3.7, 4.11, 4.12 Nr. 7, 4.13, 9.1, 9.2, 9.6 Nr. 3, 8, 9.11 (neu), 11.2, 11.6, 11.8, 11.9, 11.10, 11.11, 13.1–13.3, 15.5 Nr. 11 |
| K-07 | 3.11, 2.5, L5, P7, P8 | Restwertpfad RW_t je Periode für Vermögensamortisation, Haushaltsmodus, LTV und Beleihungsauslauf | übernommen (R-72): Merkzeile `residual_path` mit `rv_basis`, W_t, `rv_path_basis`, `lending_ratio_max` | 4.3.14, 4.12, 7.1, 7.4, 7.6, 12.2, 12.3, 12.5, 12.6, 9.2 |
| K-08 | F21, 4.3, D8, L20 | LHS-Replikate: Konzept N/10 gegenüber reproduzierbarer fester Blockgröße | **Integratorentscheidung** (R-73): feste Blockgröße 200 (Vorschau R = 5, Standard R = 50), F21 als Alternative `replicates`. Hinweis: Die Spezifikation verwendete nach Runde 1 bereits N/10 (R-14); die feste Blockgröße ist eine **Änderung**. Abweichung vom Wortlaut D8 und von F21 offen zur Bestätigung (17.3 Nr. 5) | 1.5, 2.12, 4.3.15, 9.2, 11.2, 11.4, 11.8, 11.10, 12.7, 13.2, 14 Nr. 15, 15.5 Nr. 1, 9, 15.6, 16.1 (D8), 16.3 (R-14), Anhang B |
| K-09 | 1.4, A4, B5, 7.1, P11, L4 | zweistufige Ampel mit Restwertregel und Restriktionen als K.-o.-Kennzeichen; Szenario-Set „vorsichtig“ in v1 | übernommen (R-74); bisherige deterministische Ampelregel („Restwert = 0“) ersetzt | 1.5, 4.3.14, 4.11, 12.3 (`restriction_*`), 12.6, 12.9 (neu), 13.1–13.3, 15.6 |
| K-10 | 2.5, 1.3, 4.6, P13 | Zielwertsuchen über ΔEW = 0 hinaus (Zielrenditemiete, DSCR- und Liquiditäts-Break-even, kostendeckendes Nutzungsentgelt, warmmietenneutrale Umlage, notwendige Förderung, maximal tragbare Investition) | übernommen (R-75): `vofi_solve()` und `vofi_sensitivity()` mit `kpi = NULL`, Schwellenzielen, `reference`, `rebuild`, Monotonieprüfung | 12.8, 13.4, 14 Nr. 19, 20 |
| K-11 | A2, F18, B4, 3.12, F4 | profilabhängige Konto-Defaults (nur Struktur) | übernommen (R-76): Sparer-Pauschbetrag, Limitsemantik, `anchor`-Kopplung an den Zinspfad, zulässige Profilpfade, Ü3-Warnung; Werte an Spec 01 | 4.3.10, 4.5, 4.7, 8.8, 8.9, 9.3 |
| K-12 | 2.5, P7 | DSCR ab Stabilisierungsjahr, Objekt- und Maßnahmenebene | übernommen (R-77) | 4.3.14, 7.4, 8.4, 12.2, 12.3 |
| K-13 | 3.12, L9, 8.3 WS-D | Pflichttests der Steuer-Schnittstelle mit Test-Steuermodul ab Phase 1 | übernommen (R-78); widersprach 10.10 (Tests 2–4 bei WS-X) | 2.4, 10.10, 15.1 |
| K-14 | 3.9, L22 | § 35c: voraussichtliche tarifliche ESt deckelt und warnt | übernommen (R-79); widersprach 10.9 (Pflichtbestätigung `sufficient_income_tax`) | 4.3.5, 10.9 |
| K-15 | 6.5, 5.4, F5 | Freigaberegel für Rechtsregeln, Bibliotheksversion | übernommen (R-80) | 2.4, 4.9, 4.10, 13.1 |
| K-16 | F5, A7, P9, 5.5 | 2045-Stufe als Szenario-Schalter mit Pflichtsensitivität | übernommen (R-82) | 4.3.14, 4.10, 4.11 |
| K-17 | 1.4, 2.5, P6, P23, L3 | Warmmiete vorher/nachher, Eigenanteil, Förderbarwert, CO2-Kennzahlen, Kennzahlen je WE/m², Haushaltssicht „ohne Tilgung“ | übernommen (R-83) | 7.6, 12.3, 12.4, 12.6, 14 Nr. 21, 28 |
| K-18 | 3.2 (P18), B7, B12 | PV > 30 kWp per Attribut, Performance Gap als Strukturmodell, stochastischer Auszahlungsverzug, Kürzung des Tilgungszuschusses | übernommen (R-84) | 3.9, 4.3.6b, 4.3.7, 7.1, 7.10, 8.2 |
| K-19 | 2.6, F13-Grundsatz | offener Punkt 17.3 Nr. 3 aus Runde 1 (Zins der Fehlbeträge der Unterlassungsalternative) | entschieden (R-81) | 9.5 Nr. 5, 17.3 |
| K-20 | 8.4 (Reihenfolge D → C → F → E → A → B → A2 → H), 5.3 (Schichten), 5.4 („Abrufdatum“), 4.2 (Verzug → Bereitstellungszinsen) | weitere Abweichungen geprüft | keine Vertragsänderung: Wellen und Merge-Reihenfolge regelt 2.3 (Spezifikation geht in technischen Details vor, Konzept Anhang B); Schichtenmodell 4.7 deckungsgleich; maßgeblich für die Veraltungswarnung bleibt `as_of`; Bereitstellungszinsen bei Verzug bleiben v2 (17.3 Nr. 2) | – |
| K-21 | – | redaktionell | Pipe-Zeichen in Codeabschnitten von Tabellenzellen maskiert (`\|`), damit die Tabellen in 2.4, 5.3, 8.6 und 17.2 korrekt dargestellt werden | 2.4, 5.3, 8.6, 17.2 |

### 17.5 Runde 3: Feldkatalog-Abgleich (Einzelnachweis)

Geprüft wurden die Änderungsanträge der drei Teile von Spec 01 (Abschnitte „Änderungsanträge an Spec 00“:
S01A-01–09, S01B-01–13, S01C-01–15) mit der Vorbewertung durch den Auditor sowie die Befunde der teilübergreifenden
Konsistenzprüfung (X-nn) und der fachlichen Prüfung (F-nn), soweit sie Spec 00 betreffen. Spalte „Auditor“ =
Vorbewertung (`accept`, `accept_modified`, `reject`), Spalte „Entscheidung“ = Integrator (**bestätigt** bzw.
**geändert** mit Begründung). SemVer-Einstufung nach 1.4 Nr. 3; die Version bleibt 1.0.0 (vor dem Einfrieren).

#### 17.5.1 Änderungsanträge

| Nr. | Auditor | Entscheidung | Begründung | Änderung in Spec 00 | R | SemVer |
|---|---|---|---|---|---|---|
| S01A-01 | accept_modified | angenommen mit Änderung (bestätigt, ergänzt) | `by_project_type` für Konzept A3 nötig, `defaults_meta` braucht einen Platz, Teil B braucht Element-Defaults (X-06). Ergänzt: `from:` in Vorlagen zulässig, Defaults optionaler Blöcke nur in `item_defaults` (sonst entstünde z. B. `building` in den Orakeln), Anwendung in Pfadtiefe, Reihenfolge **nach** den Ableitungsregeln | 4.2 Fn. ³, 4.7 „Defaults-Dateien“, 4.8, 4.3.6a, 4.3.6b, 4.3.7, 13.1 `meta$defaults`, 1.5 | R-85 | MINOR |
| S01A-02 | accept | angenommen (bestätigt) | `deep_merge(Skalar, {})` liefert die leere Map; `global.yaml` und S1–S5 brauchen skalare bzw. Listen-Nutzlasten | 4.9 „Auflösung von `from:`“ | R-87 | PATCH |
| S01A-03 | accept | angenommen (bestätigt) | IWU-Kostenfunktionen je A_N, Stellplatzkosten; additiv | 4.5 Mengenbezug (mit Abbildung `per` → Feld) | R-91 | MINOR |
| S01A-04 | accept_modified | angenommen mit Änderung (bestätigt) | Tabelle unvollständig und widersprüchlich (X-33); einmalig vollständig neu gefasst, inkl. S01B-01 | 4.12 Tabelle | R-90 | PATCH |
| S01A-05 | accept | angenommen (bestätigt) | 4.12 Nr. 2 und Nr. 7 verlangen `expr`-Knoten | 6.4, 2.4 | R-91 | MINOR |
| S01A-06 | accept_modified | angenommen mit Änderung (Reihenfolge geändert) | Ableitungsregeln nötig (Overlay- und Designziele auf Katalogpfaden). **Geändert:** sie laufen **vor** `item_defaults`, weil spezifische Defaults (Selbstnutzung, Instrumentart) sonst von der allgemeinen Vorlage verdeckt würden; fehlendes Feld = `auto`; Bezüge auf später gefüllte Blätter zulässig | 4.7 „Ableitungsregeln“, 4.8, 4.12 Nr. 1, 5.3 Regelkonvention, 1.5 | R-86 | MINOR |
| S01A-07 | accept_modified | angenommen mit Änderung (bestätigt) | vollständige Feldliste in Spec 00 wäre eine zweite Quelle | 4.3 Kopf | R-106 | PATCH |
| S01A-08 | reject | abgelehnt (bestätigt) | stille Umlenkung bricht die Pfad-Identität (R-16); Teil C zielt direkt auf `cost_factor` bzw. `remaining_life_offset_years` | keine (N-20) | R-109 | – |
| S01A-09 | accept_modified | angenommen mit Änderung (bestätigt, ergänzt) | Codes für Ebene 2 nötig; ergänzt um `bgb_procedure` (Verfahrenslisten der Mietrechtsnutzlast, X-08), `overlay_apply`, `growth_index`, `mc_preset`, `quantity_per`, `rule_returns`, `na_reasons` | 2.11 „Inhalt v1“, Anhang B | R-89 | MINOR |
| S01B-01 | accept | angenommen (bestätigt) | Menge, Einbaudatum, Bio-Treppe je Zustand verschieden; ids ≤ 40 bei Zustand ≤ 12, Träger ≤ 20 | 7.10, 4.12, 4.4 Nr. 2 | R-90 | PATCH |
| S01B-02 | accept_modified | angenommen mit Änderung (bestätigt) | Lesezugriff über `ctx$spec`/`ctx$value()` besteht; nur deklarative Angabe und Klarstellung | 5.2, 5.6 C3, 6.1 Nr. 3 | R-93 | MINOR |
| S01B-03 | accept | angenommen (bestätigt) | Mieterzeilen nur für vermietete Flächen | 12.3 `warm_rent`, `warm_rent_change_prepost` | R-101 | PATCH |
| S01B-04 | accept_modified | angenommen mit Änderung (bestätigt) | Sequenzen und Rechtswerte sind keine Domänenblätter; deterministische Arten keine Designziele | 4.12 Nr. 5 | R-92 | PATCH |
| S01B-05 | accept_modified | angenommen mit Änderung (bestätigt) | Mietpfad, Förderung und `share_of` lesen Zeilen je Maßnahme bzw. lokaler Zeile | 6.2 `rows()` | R-93 | MINOR |
| S01B-06 | accept | angenommen **mit Änderung** (Integrator) | Kalenderjahreswert richtig für laufende Preise (F10). **Geändert:** Die Wachstumsform beschreibt auch Stichtagsgrößen ohne Typlogik (Orakel (c): Marktwert-Merkzeile `{start: 280000, growth: 0.02}`, LTV t = 0 = 107,14 %); mit reinem Kalenderjahresindex wäre V_0 = 285.600 und das Orakel verletzt. Daher Schlüssel `index` (`calendar_year` Default, `period_end` für Stichtagswerte) | 4.5 Wachstum, 4.7 `is_value_form`, 6.3 Schritt 3, 6.4, 15.3 (c) | R-91 | MINOR, **Phase-0-Nacharbeit** |
| S01B-07 | accept | angenommen (bestätigt) | Minderung und Vermeidungskosten sonst ohne Strom/Fernwärme | 7.6 Merkzeile, 12.3 `co2_emissions` | R-101 | PATCH |
| S01B-08 | accept | angenommen (bestätigt) | im Erklärungsjahr gilt der Zustand nur anteilig | 6.3 Verwendung, 4.3.6a | R-102 | PATCH |
| S01B-09 | accept | angenommen (bestätigt) | Freigabe gilt je Eintrag | 4.10 | R-88 | PATCH |
| S01B-10 | accept | angenommen mit Änderung (Integrator, ergänzt) | Widerspruch 8.2/7.6. Ergänzt: der Anzeige-Tag „größte Maßnahme im Basisfall“ braucht einen Basisfallwert im Build; dafür `bctx$value_base()` (nur deterministische Ableitungen) | 7.6, 6.4, 4.12 Nr. 5 | R-99, R-92 | PATCH/MINOR |
| S01B-11 | accept | angenommen (bestätigt) | verträglich mit R-69, R-71 | 4.12 Nr. 7, 8.2 | R-99 | PATCH |
| S01B-12 | accept | angenommen (bestätigt; Termin über R-98 formuliert) | eindeutige Termine und Deckel; „Monat, der mit 31.12.Y + Verzug endet“ = Termin `add_months((Y+1)-01-01, Verzug)` nach 3.4 | 10.9 | R-98 | PATCH |
| S01B-13 | accept_modified | angenommen mit Änderung (bestätigt, präzisiert) | Default nach Memo 07 nötig, Registry-Regel von WS-E2 in früheren Wellen nicht nutzbar (X-07). Präzisiert: ohne `budget_risk` Basiswert 1, der Verfügbarkeitsfaktor gilt trotzdem ab 2031 | 4.3.7, 11.6 Nr. 4 | R-86 | MINOR |
| S01C-01 | accept_modified | angenommen mit Änderung (bestätigt, ergänzt) | Faktorform der Bibliothek ohne Umbau des Ziels; ergänzt: Kurzformen immer `replace`, Spalte `apply` in `draws$targets` | 4.3.15, 6.3 Schritt 1, 11.2, 11.8, 11.11 | R-94 | MINOR |
| S01C-02 | accept_modified | angenommen mit Änderung (bestätigt) | Start am Basisfall (F18); `fallback` nur dokumentierend | 11.7, 4.9 | R-95, R-88 | MINOR |
| S01C-03 | accept | angenommen (bestätigt) | Defaults erhalten die bisherigen Formeln; Konzept B8 | 11.7 Tabelle | R-95 | MINOR |
| S01C-04 | accept | angenommen (bestätigt) | Iman-Conover und CRN brauchen monotone Quantile | 5.3 | R-93 | PATCH |
| S01C-05 | accept | angenommen (bestätigt) | Stromzuordnung und Plan-Hash unabhängig von Parametern | 5.3 | R-93 | PATCH |
| S01C-06 | accept | angenommen (bestätigt) | Prüfwerte S5 sind Monatsraten | 15.6, 17.2 F-18 | R-105 | PATCH |
| S01C-07 | accept_modified | angenommen mit Änderung (bestätigt, ergänzt) | Zwei-Faktor-Zins, PV, Leerstand; ergänzt: Marktpreis für jeden kanonischen Träger (X-32) | 4.3.11 | R-103 | MINOR |
| S01C-08 | accept_modified | angenommen mit Änderung (bestätigt) | Herkunft je Blatt, Rechtsstand je Eintrag; vollständige Liste der Wurzelschlüssel | 4.8, 4.9, 4.3.15, 11.6 Nr. 7 | R-88, R-96 | MINOR |
| S01C-09 | accept | angenommen (bestätigt) | „Habenzins = vermiedener FK-Zins“ als Bezug; Ausführung in Schicht 8 | 4.3.14 | R-107 | PATCH |
| S01C-10 | accept_modified | angenommen mit Änderung (bestätigt) | stärkste Treiber sind Prozesse; Quantilpfad braucht Vertragsfunktion und eindeutige Designspalte | 4.11, 5.3, 5.6 P4, 11.11 | R-95 | MINOR |
| S01C-11 | accept | angenommen (bestätigt) | S1–S5 brauchen Förderinstrumente und Overlay-Schlüssel nur in der investiven Variante | 4.7, 4.9, 4.11 | R-87, R-96 | MINOR |
| S01C-12 | accept | angenommen (bestätigt) | P2 auch bei bindendem Floor | 11.7 | R-95 | PATCH |
| S01C-13 | accept | angenommen (bestätigt) | verträglich mit R-13 über `use`; Korrelationslisten über S01A-02 | 4.9, 4.3.15 | R-87 | PATCH |
| S01C-14 | accept_modified | angenommen mit Änderung (bestätigt) | Presets nützlich; ohne Vorrangregel wirkungslos | 4.3.15, 12.7, 13.2, 14 Nr. 15 | R-97, R-101 | MINOR |
| S01C-15 | reject | abgelehnt (bestätigt) | Sets ändern nur das Umfeld; `shared` würde die Pfadbeschränkung umgehen | 4.11 (Muster) | R-109 | – |

Summe: 37 Anträge; 18 unverändert angenommen, 17 mit Änderung angenommen (davon S01B-06 und S01B-10 abweichend vom
Auditor, S01A-06 mit geänderter Reihenfolge), 2 abgelehnt.

#### 17.5.2 Befunde mit Spec-00-Bezug

| Nr. | Schwere | Entscheidung | Änderung in Spec 00 | R |
|---|---|---|---|---|
| X-01 | blocker | übernommen | Vokabular `measure_types` = 37 Codes aus Teil A, keine Sammelcodes; Anhang B `heizung_waermepumpe_luft`; Prüfregel „Codes der Nutzlasten ⊆ Vokabular“ (WS-L); Listen der Fördereinträge N-01 | R-89 |
| X-06 | blocker | übernommen | `item_defaults` und Ableitungsregeln; Profile setzen keine Elementfelder | R-85, R-86 |
| X-07 | major | übernommen | Zusagezeitpunkt und -wahrscheinlichkeit als WS-A-Ableitungsregeln; Regelkonvention 5.3; Testeigentum Rechtsregeln in 15.6 (WS-E, Förderregeln WS-E2) | R-86, R-104 |
| X-11 | major | teilweise | ausdrückliche Regel in 3.4, aber **eine** Konvention statt zwei (siehe F-07): Einmalzahlungen mit Datumstermin nach R-35, laufende Wirkungen nach Monaten; der Vorschlag „Monatsereignis in p(m)“ entfällt | R-98 |
| X-12 | major | übernommen | 4.5 Regel 5: nicht-numerische Pfadsymbole mit `setting`-Semantik, nur in Vergleich und Logik | R-91 |
| X-13 | major | übernommen | 8.2, 8.6: τ + `term_years` zulässig, τ + `installment_eur` Fehler | R-100 |
| X-14 | major | übernommen (Klarstellung) | 3.9: Verschiebungen ≥ 0, vorgezogene Termine als früherer Basistermin | R-105 |
| X-20 | minor | übernommen | 4.4 Nr. 2: Prüfung erzeugter ids ≤ 40 mit Höchstlängen der Nutzer-ids | R-90 |
| X-21 | minor | übernommen | 5.3: `returns: value`; Regeln ohne `ctx` auch in Defaults von Formals | R-93 |
| X-22 | minor | übernommen | 2.2, 2.4, 15.6: Datentests `test-library.R`, `test-profiles.R`; Set „vorsichtig“ in `R/compare.R` | R-104 |
| X-23 | minor | übernommen | 2.10: Namensraum `validation.<block>.<code>` in `inst/labels/de/validation.yaml` | R-104 |
| X-25 | minor | übernommen | 7.10: PV-Nullsatz als `expr`-Knoten aus `rule:measure_catalog`; Zeilenmetadatum = Basisfallwert | R-86 |
| X-27 | minor | übernommen | 2.11: Codes `federal_state` | R-89 |
| X-29 | minor | übernommen | 4.10: `valid_to` nur bei tatsächlichem Ende; Fortgeltung mit `valid_to: null` | R-88 |
| X-30 | minor | übernommen (Variante „nur bei endlichem Limit zählen“) | 12.3, 12.4, 12.9: NA `no_liquidity_limit`, kein K.-o., Plausibilitätswarnung; ein endlicher WU-Default ist Sache von Teil A | R-101 |
| X-33 | minor | übernommen | 4.12 Tabelle neu (mit S01A-04, S01B-01) | R-90 |
| F-07 | major | übernommen (Variante „Datumssemantik“) | 3.4 Nr. 3: Termin = Bezugsdatum + Fristen, Buchung nach R-35; Zuschuss und Tilgungszuschuss mit gleicher Ableitung fallen in dieselbe Periode; F-1, F-16, S3-T2 und Kommentare in Teil B/C anzupassen (N-13) | R-98 |
| F-09 | major | übernommen | 4.12 Nr. 8: Komponenten-Zeitwert ohne Indexierung = nominaler Buchwert; RV8 = 82.853,16 | R-108 |
| F-10 | major | übernommen | 8.6: `keep_term` nach `shorten_term` mit effektiver Restzahl; L1 und S1-T8 neu rechnen | R-100 |

#### 17.5.3 Verbindliche Namens- und Eigentumsentscheidungen (für die Überarbeitung von Spec 01)

Die Bearbeiter der Teile A–C übernehmen diese Festlegungen wörtlich; bei Widerspruch zu Spec 01 gilt diese Liste.

| Nr. | Gegenstand | Festlegung | umsetzen in |
|---|---|---|---|
| N-01 | Maßnahmentypen (X-01, F-03) | einzige Quelle: 37 Codes Teil A §4.2. KfW 458 (vererbt an 459): `eligibility.measure_types: [heizung_waermepumpe_luft, heizung_waermepumpe_sole, heizung_pelletkessel, heizung_fernwaerme, heizungsverteilung]`. BAFA Hülle: `[daemmung_fassade, daemmung_dach_steil, daemmung_dach_flach, daemmung_oberste_geschossdecke, daemmung_kellerdecke, fenster, aussentueren]`. `sonnenschutz`, `heizung_tausch`, `daemmung_dach`, `daemmung_ogd`, `aussentuer` gibt es nicht | 01c §3.4; 01b §4.3.1 (unverändert E) |
| N-02 | II. BV (X-05a) | Bibliotheks-id `costs/bewirtschaftung_ii_bv_2026` | 01a §2.2, §3.3, §8.2 |
| N-03 | ImmoWertV-Bewirtschaftung (X-05b, F-17) | `use`-Schlüssel der Bibliothek gelten: `admin_per_unit_or_efh_eur_pa`, `admin_per_garage_eur_pa` | 01b §7.1 |
| N-04 | Defaults von Teil B (X-06) | `unit_groups_defaults` → `item_defaults."unit_groups"`; `energy_defaults.carriers` → `item_defaults."energy.carriers"` (mit `price_eur_kwh: {ref: market.energy_price.{id}}`, `co2_price_eur_t`, `bio_premium_eur_kwh` als Bezüge); `energy_defaults.performance_gap` → `item_defaults."energy.performance_gap"`; `energy_defaults.pv` → `item_defaults."energy.pv"`; übrige `energy_defaults.*` → `item_defaults."energy"`; `funding_defaults` → `item_defaults."funding"` (`on_reject: balance`, `approval_timing: auto`, `payout_delay_months: 0`, `availability_after_2030: 0.7`); `payout_delay_months_tax_credit` → `rule:tax_credit_defaults` (12 bei `instrument_type: tax_credit`); `building_defaults.property_tax` → `item_defaults."building.property_tax"`; `scenario_sets.foerderstopp` bleibt gewöhnlicher Block. 01b §7.2 (Profiltabelle) entfällt (Inhalt N-08). `network_fee_eur_kwh` „falls der Marktname existiert“ → `rule:carrier_defaults` | 01b §7.1, §7.2, §1.2, §2.2, §3.2.1 (Spalten (G)/(P)); 01a §2.1, §2.2 (Datei = Vereinigung) |
| N-05 | Defaults optionaler Blöcke (R-85) | Felder von `building`, `household`, `energy` (z. B. `building_id`, `building.maintenance`) stehen nur unter `item_defaults."building"` usw., nie als gewöhnlicher Block in `global.yaml`; Profile setzen keine Elementfelder | 01a §2.2 |
| N-06 | Mietrechtliche Verfahrenscodes (X-08) | `levy_procedure` = `auto`, `bgb_559`, `bgb_559c`, `bgb_559e` (Aliase `559`, `559c`, `559e`, auch als Zahl gelesen); Bibliothekslisten (`s557a.excludes`, `s558.excludes_increases`, `rent_law.enables`) nur mit `bgb_procedure`-Codes; `mr_levy_allowed` vergleicht innerhalb der `bgb_`-Familie, `bgb_559c` zählt bei der Ausschlussprüfung als `bgb_559` (fachlich zu bestätigen, 17.3 Nr. 8 d); S1: `rent_law: {procedure: bgb_559}` | 01b §1.4, §1.9.2, §5.1, §8; 01c §3.5, S1 |
| N-07 | Ableitungsregeln (R-86, X-07) | Eigentümer WS-A (`R/scenario-layers.R`); Namen: Teil A `rule:tax_regime`, `rule:report_mode`, `rule:dates`, `rule:price_base_year`, `rule:project_id`, `rule:tenant_view`, `rule:building_aggregates`, `rule:first_occupancy`, `rule:measure_catalog` (inkl. PV-USt nach 7.10 und `modernization_kind: none` bei Erhaltung bzw. Ohnehin-Anteil 1, X-09), `rule:cost_from_kg` (inkl. `payment_schedule` mit `unit: eur`, X-28), `rule:maintenance_from`; Teil B `rule:unit_group_defaults`, `rule:carrier_defaults`, `rule:approval_timing`, `rule:approval_probability`, `rule:tax_credit_defaults`. Die Registry-Regeln `fund_approval_probability`, `fund_approval_timing` entfallen; Expander, Validierung, Sampler und `vofi_build()` lesen `funding.<f>.approval_timing` bzw. `.approval_probability` | 01a §1.4; 01b §4.2, §4.9, §5.1, §5.4 (neuer Unterabschnitt „Ableitungsregeln“) |
| N-08 | `rule:unit_group_defaults` (X-06) | `owner_occupied` fehlt → `true` bei `project.perspective = selbstnutzer`, sonst `false`; bei `owner_occupied = true`: `rent_regime: owner_occupied`, `vacancy_rate: 0`, `rent_default_rate: 0`, `operating.admin_per_unit_eur_pa: 0`, `operating.admin_per_parking_eur_pa: 0`, `operating.nonrecoverable_share_of_rent: 0`; bei `wu_genossenschaft` und vermieteter Gruppe: `rent_regime: cooperative_fee`; alle übrigen Gruppenwerte aus `item_defaults."unit_groups"` (z. B. `vacancy_rate: 0.025`) | 01b §1.2, §2.2 |
| N-09 | Verfügbarkeit nach 2030 (S01B-13) | Feld `funding.<f>.availability_after_2030` (statt `funding_defaults.post2030_availability`); die Overlay-Vorlage in `processes/funding_risks_2026` heißt `availability_after_2030` (statt `availability_post2030`) | 01b §4.2, §5.4; 01c §1.9, §2.1, §2.7 |
| N-10 | Fakten der Neubauförderung (X-04, F-06) | zwei Symbole: `facts.lca_thg` (Bedingung `conditions.lca_thg: required`, ersetzt `lca_qng_plus_thg`; Grundförderung) und `facts.qng` (nur Deckel `*_qng`); S5 V2/V2b `facts: {lca_thg: true}`, S2 V2 `facts: {lca_thg: true, qng: true}` | 01b §4.3.1, §4.3.2, §4.4; 01c kfw_297/298/300, S2, S5 |
| N-11 | Kreditanteil (X-17) | einheitlich `loan.max_share_of_eligible_costs` | 01c kfw_358/359; 01b §4.6 |
| N-12 | Kumulierung (X-18, F-20) | `cumulation.exclusive_with` gilt gegen die ganze `from:`-Kette und `program_code`; `estg_35c.exclusive_with` um KfW 358/359 ergänzt | 01b §4.11; 01c `funding/estg_35c` |
| N-13 | Termine (R-98, F-07, X-11) | Monat m = (b_0 + (m − 1), b_0 + m] Monate (01b §0.4 anpassen); Auszahlungen als Datum (Fertigstellung + `lag_months` + Verzug) nach R-35; F-1 (KfW 459: Termin 2028-01-01 → t = 1), F-16 (2029-01-01 → Periode 2028), Vertragsbeispiel `grant` (Zusage am Stichtag → t = 0), S3-T2-Periode und Kommentare S1/S3/S4 angleichen | 01b §0.4, §4.5, §4.8, §4.12; 01c S1, S3, S4 |
| N-14 | Energiekomponenten (R-90) | `e_<s>_<c>_cost`, `e_<s>_<c>_co2`; Zustands-ids `before`, `after`, `stages.<s>` (≤ 12 Zeichen); Träger-ids ≤ 20 | 01b §3.1, §3.5 |
| N-15 | Trägercodes und Marktpreise (X-32, R-103) | kanonisch: `gas`, `gas_mfh`, `oil`, `lpg`, `power`, `power_mfh`, `heatpump_power`, `heatpump_power_mfh`, `district_heating`, `pellets`; für **jeden** ein `market.energy_price.<c>` in `global.yaml` und `prices/energy_prices_2026` (`lpg`, `power_mfh` ergänzen, Qualität C/D); `market.energy_network_fee.gas`, `.gas_mfh` mit `growth: {ref: shared.network_fee_growth_<c>}` und `shared.network_fee_growth_gas`, `_gas_mfh` (0.03) in `global.yaml` wie in den Referenzszenarien | 01a §2.2 (`market`, `shared`); 01b §3.2.1; 01c §2.4, §3.6 |
| N-16 | Marktnamen (S01C-07) | zusätzlich `operating_cost_growth`, `bund_yield_10y`, `mortgage_spread`, `feed_in_tariff.{partial_le10kwp, partial_10_40kwp, partial_40_100kwp, full_le10kwp}`, `vacancy_fluctuation`; der PV-Default-Ausdruck nutzt `partial_40_100kwp` (X-24 d) | 01a §2.2; 01b §3.9.1; 01c §1.9.1 |
| N-17 | Validierungsschlüssel (X-23) | `validation.<block>.<code>` in `inst/labels/de/validation.yaml` (WS-B); `validation.b.*` → z. B. `validation.unit_groups.ovm_missing`; neue Schlüssel `validation.accounts.liquidity_unchecked`, `validation.measures.cost_derived`, `validation.residual.rnd_target` | 01a §9; 01b §0.3, §8; 01c §1.11 |
| N-18 | Testdateien (X-22) | `test-<R-datei>.R`: `test-type-flow-capex.R`, `test-type-flow-replacement.R`, `test-type-flow-maintenance.R`, `test-type-flow-residual-value.R`, `test-type-inst-loan-core.R` usw.; Datentests `test-library.R` (WS-L), `test-profiles.R` (WS-A); Set „vorsichtig“ in `R/compare.R` (`cmp_cautious()`) | 01a §4.6.6, §4.10.3, §4.11.5, §5.6, §6.7; 01b §1.15 ff.; 01c §4.3 |
| N-19 | Regelsignaturen (X-21) | `grest(basis_eur, federal_state, rate, P)` ohne Defaults (P = Nutzlast `grunderwerbsteuer`, vom Typ übergeben), `returns: sim`; `mr_levy_allowed`, `co2_section43`: `returns: value`; Aufrufe mit allen Formals (01b §1.6 Nr. 4) | 01a §4.8, §7; 01b §1.6, §5.1 |
| N-20 | Overlay-Ziele (S01A-08 abgelehnt) | Kostenrisiko auf `measures.<id>.cost_factor` bzw. `project.construction_cost_factor`, RND-Zuschlag auf `residual_value.income_value.remaining_life_offset_years`; ein Ziel `measures.<id>.cost_eur` bei `cost_kg` bzw. `remaining_life_years` bei Methode ≠ `manual` ist E mit Vorschlag (`validation.measures.cost_derived`, `validation.residual.rnd_target`); Hinweis „Umlenkung, S01A-08“ streichen | 01a §4.6.1, §6.1, OP-13; 01c §1.9 |
| N-21 | Szenario-Sets (S01C-15 abgelehnt) | keine `shared.*`-Pfade in Sets; Muster „szenarioeigener `market`-Pfad, auf den das Domänenfeld per `ref` zeigt“ | 01c §4.1, §5 |
| N-22 | Label `foerderstopp` (X-24 f) | maßgeblich ist 01c §4.2 („Förderstopp: keine Förderzusage“) | 01a §2.2; 01b §7.1 |
| N-23 | Höchstlängen der ids (X-20) | Maßnahmen und Bauteile ≤ 29, Gruppen ≤ 25, Förderinstrumente ≤ 30, Zustände ≤ 12, Träger ≤ 20 (4.4 Nr. 2) | 01a §4.5.2 Nr. 1; 01b §1.2, §3.2.2, §4.2 |
| N-24 | Komponenten-Zeitwert (F-09) | `indexed: false` = nominaler Buchwert; RV8 = 82.853,16 | 01a §6.3.7, §6.7 |
| N-25 | Annuitätendarlehen (X-13, F-10) | τ + `term_years` zulässig (I „Schlusstilgung bei Fälligkeit“), E nur τ + `installment_eur`; `keep_term` nach `shorten_term` mit effektiver Restzahl (8.6): L1 und S1-T8 neu rechnen | 01a §5.2, §5.6; 01c S1, S5 |
| N-26 | Referenzszenarien (R-105) | S5 `payments_per_year: 12`; S4 `gaskessel` mit `year: 2028`, `delay_months: 24`, Verteilung `discrete [0, 12, 24, 36, 48, 60]`, `wp_2050` → `year: 2048` mit `delay_months: {ref: measures.gaskessel.delay_months}` (X-14) | 01c S4, S5 |
| N-27 | Wachstumsform (R-91) | Marktpfade als Wachstumsform sind Kalenderjahreswerte (Prüffall 01c z3 unverändert); `index: period_end` nur für Stichtagsgrößen; Orakel (c) mit `index: period_end` (WS-T) | 01b §0.7 (Verweis); 01c §4.2; WS-T Fixture (c) |
| N-28 | Bibliothekseintrag (R-88) | Teil C §3.1 ist die Konkretisierung von 4.9; `legal_state` Pflicht für `legal/*` und `funding/*`; `legal/emission_factors_geg_anlage9` mit `valid_to: null` und Prüfpunkt „Neuwerte ab 2027“ (X-29) | 01c §3.1, §3.5; 01b §3.2.1 (Spalte `ghg_factor_kg_kwh`) |
| N-29 | Regel-Eigentum | Mietrecht, CO2KostAufG, GrESt: WS-E (`rules-mietrecht.R`, `rules-co2kostaufg.R`, `rules-grest.R`, Welle 2b); Förderregeln `fund_degression`, `fund_income_rate`, `fund_staffel_cap`, `fund_35c_params`: WS-E2 (`rules-funding.R`), nur vom Expander `funding` und den Typen `grant`, `tax_credit_35c` aufgerufen; Ableitungsregeln: WS-A (N-07); Tests beim jeweiligen Eigentümer | 01b §5.1 |
| N-30 | Katalogeintrag `costs/massnahmentypen_2026` (X-15) | Datenträger WS-L, vollständig mit 37 Typen in Teil C §3.3/§3.7 (Schema Teil A §8.3); `useful_life_key` verweist auf `costs/nutzungsdauern_2026`, Herkunft von `useful_life_years` ist dieser Eintrag (XM1); `kfw_297_*` und `kfw_261_eh40/55/85/denkmal` als eigene Listings | 01c §3.3, §3.4, §3.7; 01a §4.5.5 |
| N-31 | Domänenlesezugriff (S01B-02) | `rent_path`, `grant`, `tax_credit_35c`, `energy_cost`, `co2_cost`, `tenant_costs`, `pv` deklarieren `domain_reads`; die Übergangsregel 01b §0.5 wird zur Vertragsregel (6.1 Nr. 3) | 01b §0.5 und Typabschnitte |

#### 17.5.4 Phase-0-Nacharbeit (Integrator; betrifft bereits geschriebenen Code)

Version bleibt 1.0.0. Die folgenden Punkte ändern Dateien, die in Phase 0 bereits angelegt sind; sie sind vor dem
Einfrieren (1.4 Nr. 4) und vor Welle 1 zu erledigen. Nicht betroffen sind Signaturen exportierter Funktionen (14).

| Nr. | Datei(en) | Änderung | Art | Grund |
|---|---|---|---|---|
| P0-01 | `inst/vocab/measure_types.yaml`, `inst/labels/de/vocab.yaml`, `tests/testthat/test-vocab.R` | vorläufige 23 Codes durch die 37 Codes aus Teil A §4.2 ersetzen (entfallen: `heizung_tausch`, `daemmung_dach`, `daemmung_ogd`, `aussentuer`, `sonnenschutz`, `heizung_optimierung`, `lueftung`, `solarthermie`, `speicher`, `sanitaer`, `elektro`, `barrierefreiheit`); Labels `vocab.measure_types.*`; Test Z. 74 (`heizung_tausch`) auf `heizung_waermepumpe_luft` | inkompatibel (Vokabular) | R-89, X-01 |
| P0-02 | `inst/vocab/enums.yaml`, `inst/labels/de/vocab.yaml` | neue Enums `levy_procedure` (Aliase auch für numerische Eingabe), `bgb_procedure`, `overlay_apply`, `growth_index`, `mc_preset` sowie die Enums aus Teil A §8.1 und Teil B §8 nach deren Überarbeitung; `quantity_per` + `m2_net_floor_area`, `parking`; `rule_returns` + `value` | additiv | R-89, R-91, R-93, R-94, R-97 |
| P0-03 | `inst/vocab/na_reasons.yaml`, Labels | `no_liquidity_limit` | additiv | R-101 |
| P0-04 | `R/utils-merge.R` (`utl_value_form_keys()`), `tests/testthat/test-utils-merge.R` | Wachstumsform: optionaler Schlüssel `index` | additiv | R-91 |
| P0-05 | `R/values-normalize.R` | `node_growth(start, growth, base_date = NULL, index = "calendar_year")`, `node_growth_raw()` liest `index`; neuer Konstruktor `node_expr(text)` | additiv | R-91 |
| P0-06 | `R/values-resolve.R` | `res_growth()`: Default `grid_index_year()`, `grid_index()` nur bei `index: period_end` (**Verhaltensänderung**); `res_quantity()`: Abbildung `per` → Feld (`unit` → `n_units`, `m2_net_floor_area` → `net_floor_area_m2`, `parking` → `n_parking`); `res_draw()`: `apply` multiply/add (Spalte `apply` in `draws$targets`); `res_expr()`: nicht-numerische Symbole mit `setting`-Semantik an `expr_eval()` | Verhalten + additiv | R-91, R-94 |
| P0-07 | `R/engine-context.R` | `ctx$rows(id, section, category, tax_category, measure_id = NULL, local_row = NULL)`, `id` als Vektor | additiv | R-93 |
| P0-08 | `R/registry.R`, `R/registry-testkit.R` | optionales Feld `domain_reads` (flow, instrument; C3 prüft Codes); optionale Prozessfunktion `quantile_path(par, years, p)` (C2-Formals, Prüfung P4); `returns: value` bei Regeln (Batch-Prüfung wie `params`) | additiv | R-93, R-95 |
| P0-09 | `R/scenario-layers.R` | Rückfallwerte der Schichten 1–2: Felder optionaler Blöcke (z. B. `building.building_id`) nur, wenn der Block existiert (`item_defaults`-Semantik), damit Szenarien ohne `building` keinen Block erhalten; abgeleitete Projekt-Defaults mit Herkunft `entry = "rule:<name>"`; Reihenfolge Ableitungsregeln → `item_defaults` → Expander | Verhalten | R-85, R-86 |
| P0-10 | `R/expr.R` (Minimalfassung) | Codes und Wahrheitswerte als Operanden nur in `==`, `!=`, `%in%`, `!`, `&`, `\|` (Fehler sonst), Ergebnis 0/1 | Präzisierung | R-91 |

---

## Anhang A: Walking Skeleton (Phase 0, `inst/extdata/examples/skeleton.yaml`)

```yaml
schema_version: 1
meta: {scenario_id: skeleton, title: "Gerüst: Minimalszenario"}
project: {perspective: wu_privat, project_type: neubau, valuation_date: 2027-01-01, horizon_years: 3}
components:
  z: {type: custom_series, label: "Zahlungsfolge", values: [-100000, 30000, 40000, 50000]}
financing:
  ek:   {type: equity, amount_eur: 40000}
  bank: {type: bullet_loan, amount_eur: 60000, rate_pa: 0.05, term_years: 3, payments_per_year: 1}
accounts:
  deposit_rate_pa: 0.02
  overdraft_rate_pa: 0.08
  overdraft_limit_eur: .inf
  surplus_order: [od_repay, dep_invest]
  deficit_order: [dep_withdraw, od_draw, equity_call]
analysis: {kpis: [terminal_value, terminal_value_opp, delta_terminal_value]}
```

Erwartung (Handrechnung): t = 0 Saldo 0; t = 1: 30.000 − 3.000 = 27.000 angelegt; t = 2: 40.000 − 3.000 + 540 =
37.540 angelegt (G = 64.540); t = 3: 50.000 − 3.000 − 60.000 + 1.290,80 = −11.709,20 aufgelöst. **EW = 52.830,80;
EW_U = 40.000 · 1,02³ = 42.448,32; ΔEW = 10.382,48**; Finanzierungssaldo 0 in jeder Periode. Abnahme Phase 0:
`vofi_read_scenario(vofi_example("skeleton")) |> vofi_build() |> vofi_run() |> print()` läuft und liefert diese Werte.

## Anhang B: Beispielszenario mit allen Blöcken (gekürzt, zur Orientierung)

```yaml
schema_version: 1
meta: {scenario_id: mfh_musterstr_12, title: "Energetische Sanierung MFH Musterstraße 12", author: "Controlling"}
project:
  perspective: wu_kommunal
  project_type: sanierung_eh
  valuation_date: 2027-01-01
  horizon_years: 30
  legal_state: 2026-10-25
  federal_state: NW
  reference_variant: ohnehin
grid: {construction_months: 9, construction_step_months: 1}
building: {building_type: MFH, construction_year: 1972, n_units: 18, living_area_m2: 1250,
           component_areas_m2: {roof: 520, facade: 1400, windows: 260}}
unit_groups:
  standard: {n_units: 18, living_area_m2: 1250, rent_eur_m2_month: 7.20, rent_regime: paragraph_558}
measures:
  huelle: {label: "Dämmung Fassade/Dach, Fenster", year: 2027, cost_eur: 1350000, ohnehin_share: 0.25,
           useful_life_years: 40, measure_type: daemmung_fassade, modernization_kind: bgb_555b_1}
  waermepumpe: {label: "Wärmepumpe", year: 2027, cost_eur: 450000, useful_life_years: 20,
                measure_type: heizung_waermepumpe_luft, modernization_kind: bgb_555b_1a}
funding:
  kfw261: {from: funding/kfw_261_eh55, measures: [huelle, waermepumpe], amount_eur: 1200000}
components:
  stellplaetze: {type: recurring, label: "Stellplatzmiete", category: operating_income,
                 amount_eur: 7200, growth: {ref: market.inflation}, from: 2027-10-01}
financing:
  ek:   {type: equity, amount_eur: 400000}
  bank: {type: annuity_loan, amount_eur: auto, rate_pa: 0.039, initial_repayment_pa: 0.02,
         fixed_years: 10, followup_rate_pa: {ref: market.mortgage_rate}}
accounts: {deposit_rate_pa: 0.02, overdraft_rate_pa: 0.055, overdraft_limit_eur: 250000,
           deficit_order: [dep_withdraw, od_draw, dep_use_reserve, penalty_rate]}
market:
  inflation: {series: {2027: 0.028, 2028: 0.022}, fill: locf}
  rent_growth: 0.015
  construction_price_index: 0.03
  mortgage_rate: 0.04
  co2_price: {from: prices/co2_price_paths_2026, use: scenarios.mittel}
residual_value: {method: income_value, sale_cost_share: 0.03}
tax: {module: none}
stochastic:
  settings: {n_sim: 10000, seed: 20261025, sampling: lhs, block_size: 200}
  parameters:
    huelle_kosten: {target: measures.huelle.cost_eur, label: "Kosten Gebäudehülle",
                    dist: pert, min: 1250000, mode: 1350000, max: 1750000}
  processes:
    mortgage_rate: {target: market.mortgage_rate, from: processes/mortgage_rate_vasicek_2026}
  correlations:
    shocks: []
variants:
  ohnehin:
    label: "Ohnehin-Sanierung"
    remove: [measures.waermepumpe, funding.kfw261, measures.huelle.modernization_kind]
    set:                           # Map am existierenden Pfad wird gemischt (4.11); keine Umlage auf Ohnehin-Kosten
      measures.huelle: {cost_eur: 337500, ohnehin_share: 1, classification: erhaltung,
                        label: "Instandsetzung Fassade/Dach, Fenster"}
scenario_sets:
  zinsschock: {label: "Zinsschock", set: {market.mortgage_rate: 0.065}}
```
