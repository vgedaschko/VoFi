# Spezifikation 01 – Teil A: Feldkatalog Projekt, Investition, Finanzierung, Restwert

| | |
|---|---|
| **Projekt** | VoFi-Werkzeug (R-Paket `vofi`) für Neubau und energetische Sanierung, Wohnungswirtschaft und Privatpersonen |
| **Dokument** | `docs/spec/01a_feldkatalog_projekt_investition_finanzierung.md` (Spec 01, Teil A) |
| **Bezug** | `docs/spec/00_kernvertraege.md` (Spec 00, `contract_version = "1.0.0"`, `schema_version = 1`), `docs/Konzept.md` (§ 2, § 3, § 11.2 F1–F21, § 11.3 A1–C12, Review-Protokoll), Memos 01, 02, 03, 05, 06, 07 |
| **Stand** | 26.10.2026 (Runde 3 „Feldkatalog-Abgleich“ eingearbeitet: Entscheidungen R-85 bis R-109 und N-01 bis N-31 aus Spec 00 §16.3/§17.5; Nachweis in Abschnitt 12) |
| **Status** | Entwurf zur Integration (Rang 3 nach Spec 00 §1.2). Konkretisiert Felder, Defaults und Algorithmen **innerhalb** der Strukturen von Spec 00; wo eine Konkretisierung eine Spec-00-Struktur berühren würde, steht ein Änderungsantrag in Abschnitt 11 (`S01A-nn`) mit Übergangsregel; offene fachliche Punkte stehen in Abschnitt 10; das Review-Protokoll der Runde 3 steht in Abschnitt 12. |
| **Nachbarteile** | Teil B (`01b`): Mietrecht (`rent_path`, §§ 558/559/559a/559c/559e/559f), Betriebskosten, Grundsteuer, Energie/CO2, PV, Haushalt, Mieterkosten, Förderinstrumente (Auslegung). Teil C (`01c`): Stochastik-Overlay, Bibliotheksdaten, Szenario-Sets, Referenzszenarien, MC-Auswertung. Teil A verweist auf B und C, ohne deren Inhalte zu wiederholen. |
| **Eigentümer der Inhalte** | WS-A (Abschnitte 1–2: Schema der Blöcke `meta`, `project`, `grid`, `analysis`, `global.yaml`, Profile), WS-E (Typen `capex`, `land`, `acquisition_cost`, `replacement`, `maintenance`, `equity`, `custom_series`, `recurring`, `share_of`, `residual_value`, Regel `grest`), WS-E2 (Expander `measures`, `residual`; Expander `unit_groups` nach Teil B), WS-F (Kredittypen), WS-D (Konten), WS-L (Bibliothekseinträge aus Abschnitt 8.3), WS-B (Validierungscodes) |

> **Lesehinweis.** Bezeichner, Schlüssel und Codes sind ASCII-snake_case; Labels und Erläuterungen sind deutsch.
> Raten und Anteile sind Dezimalzahlen (`0.039` = 3,9 %), Geldbeträge nominal in EUR brutto (Spec 00 §2.13). Alle
> Testwerte in den Abschnitten „Tests“ sind mit den Skripten in
> `/tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/spec01a/` (Runde 3 zusätzlich
> `…/scratchpad/spec01-review/r3a/`; Python 3.13, skalare
> Referenzimplementierung der Spec-00-Algorithmen; Monatsuhr nach Spec 00 §8.5 reproduziert Test (f) und Test (h) aus Spec 00 §8.10; Skripte sind nicht Teil des Pakets)
> nachgerechnet und auf 2 Dezimalen gerundet angegeben; die Implementierung rechnet ungerundet (Toleranz 1e-6 EUR gegen
> ungerundete Werte, 0,005 EUR gegen die hier gerundeten).

---

## 0. Konventionen dieses Teils

### 0.1 Spalten der Feldtabellen

| Spalte | Inhalt |
|---|---|
| YAML-Pfad | Pfad nach Spec 00 §4.4 (Pfad-Identität §4.13). `<id>` = Sammlungs-id, `<g>` = Wohnungsgruppe, `<m>` = Maßnahme, `<e>` = Bestandsbauteil, `<k>` = Finanzierungsbaustein |
| Typ | `int`, `num`, `chr`, `lgl`, `date`, `timing` (Datum, Jahr oder Token `completion`, Spec 00 §3.9), `enum:<codes>` bzw. `enum:<vokabular>`, `value` (Wertgrammatik §4.5), `amount`/`rate`/`share`/`number` (Wertgrammatik mit Grenzen der DSL-Art, §5.4), `schedule`, `map`, `ids`, `chr[]` |
| Einheit | `EUR`, `EUR/a`, `EUR/m²·a`, `EUR/m²·Monat`, `1/a` (Rate p. a.), `1` (Anteil), `m²`, `a` (Jahre), `Monate`, `Jahr` (Kalenderjahr) |
| Default (Quelle) | Wert bei fehlendem Feld; Quelle: **T** = Typ- bzw. Schema-Default (Schicht 0), **G** = `global.yaml` (Schicht 1; für Elemente von Sammlungen und für optionale Blöcke über `item_defaults`, angewandt nach den Ableitungsregeln, 2.1, Spec 00 §4.7, R-85), **P** = Profil (Schicht 2), **B:`<id>`** = Bibliothekseintrag (Schicht 3 bzw. vom Expander gelesen), **A** = Ableitungsregel (1.4), **E** = vom Expander gesetzt (Herkunft `expander`) |
| Pflicht | `ja`, `nein`, `bedingt` (Bedingung in „Validierung“) |
| Validierung | **E** = Fehler (gesammelt, `vofi_build()` bricht mit `vofi_error_validation` ab), **W** = Warnung (`vofi_warning_plausibility`, bei Eingabeumdeutung `vofi_warning_input`), **I** = Hinweis (`vofi_inform`). Codes in Abschnitt 9 |
| Bedeutung | fachliche Bedeutung |
| Memo-Ref | Herkunft bzw. Begründung (Memo §, Konzept §/Festlegung, Spec 00 §) |

### 0.2 Notation

| Symbol | Bedeutung (Spec 00 §3) |
|---|---|
| t = 0…T, j = t + 1 | Zeitpunkte/Perioden, Spalte j einer n × (T+1)-Matrix |
| m_t, Δ_t, τ_t, M_t, b_t | Periodenlänge in Monaten bzw. Jahren, kumulierte Jahre, kumulierte Monate, Periodenende (Datum) |
| p(d) | `ctx$period_of(d)`: Periode eines Datums (Spec 00 §3.4) |
| P(d, s) | `ctx$shift_period(d, s)`: Periode von d + s Monaten je Lauf (n-Vektor, `NA` jenseits des Horizonts, §3.9) |
| ω_t(a, b) | `ctx$overlap(a, b)`: Monatsanteil der Periode t in [a, b) |
| ω_t(a + s, b) | `ctx$shift_overlap(a, s, b)`: dasselbe mit laufspezifischer Verschiebung s |
| I^S_t(g, d₀) | `ctx$index(g, d₀)`: Stichtagsindex zum Periodenende b_t, bezogen auf d₀ (Bestände, Einmalzahlungen) |
| I^Y_t(g, d₀) | `ctx$index_year(g, d₀)`: Kalenderjahresindex (laufende Jahresbeträge, R-62) |
| d_PB(Y) | Preisstand eines `price_base_year: Y` = **(Y+1)-01-01** (R-35) |
| a_m | Aktivierungsfaktor der Maßnahme m (0/1, Spec 00 §4.12 Nr. 7, R-71) |
| round_m(x) | Rundung einer Verschiebung auf ganze Monate: `floor(x + 0.5)` (Spec 00 §3.9) |

**Vorzeichen:** Zufluss +, Abfluss − aus Sicht des Investors; Merkzeilen der Bestände und Werte (`market_value`,
`residual_path`) positiv. Alle Monatsbeträge einer Periode werden am Periodenende gebucht (Spec 00 §3.7).

**Termine (Spec 00 §3.4 Nr. 1–4, R-98).** Einmalzahlungen (Zahlungsplan, Kaufpreis, Erwerbsnebenkosten, Ersatz,
Einlage, Kreditauszahlung, Tilgungszuschuss) haben ein **Datum** als Termin und werden in `grid_period_of(Termin)`
bzw. laufspezifisch in `ctx$shift_period(Termin, s)` gebucht (ein Datum auf einer Periodengrenze gehört zur Periode,
die dort endet; Termin am Stichtag → t = 0). Laufende Wirkungen gelten ab dem Monat mi(d), der mit dem Datum d
beginnt (ω_t, `ctx$shift_overlap()`). Alle Verschiebungen sind ≥ 0; ein Termin, der je Lauf auch früher liegen
kann, wird als früherer Basistermin mit nichtnegativer Verschiebung modelliert (Spec 00 §3.9, R-105).

### 0.3 Wiederverwendete Algorithmusbausteine

Die Typen dieses Teils verwenden vier Bausteine. Sie sind hier einmal definiert und in den Typabschnitten nur
referenziert. Implementierung als interne Hilfsfunktionen in der Datei des jeweiligen Typs bzw. – bei Mehrfachnutzung
durch WS-E – in `R/type-flow-capex.R` (`capex_payment_plan()`, `capex_index_at()`), nicht exportiert.

**ZP – Zahlungsplan zu Terminen (Einmalzahlungen mit Preisindex).** Eingaben: Ereignisse e = 1…E mit
deterministischem Datum d_e, Gewicht w_e (n-Vektor), Verschiebung s_e (n-Vektor, ganze Monate); Grundbetrag C
(n-Vektor, in Preisen von d₀); Preisindexrate g (n × (T+1)); Preisstand d₀.

```text
I    <- ctx$index(g, d0)                                  # n x (T+1), Stichtagsindex zum Periodenende
X    <- ctx$zeros()
für e in 1..E:                                            # Schleife über Ereignisse (zulässig, 2.8 Nr. 5)
    p  <- ctx$shift_period(d_e, s_e)                      # n-Vektor, NA = jenseits des Horizonts
    ok <- !is.na(p)
    X[cbind(which(ok), p[ok] + 1)] += C[ok] * w_e[ok] * I[cbind(which(ok), p[ok] + 1)]
Zahlungen mit p = NA entfallen (einmal je Komponente vofi_inform "after_horizon" mit Anzahl der Läufe).
```

Die Indexierung erfolgt mit dem Stichtagsindex **der Buchungsperiode** (Periodenende), auch bei verschobenen Terminen
(Spec 00 §3.9 letzter Punkt). Damit bewirkt ein Verzug die Preissteigerung bis zur neuen Buchungsperiode.

**ZPP – Zahlungsprofil über eine Ausführungsdauer.** Ein Termin d mit Ausführungsdauer D Monaten (D ≥ 1) und Profil
f wird in D Monatsereignisse zerlegt: Ereignis k = 1…D mit Datum d_k = d − (D − k) Monate (Ende des k-ten
Ausführungsmonats; d_D = d) und Gewicht w_k = F(k/D) − F((k−1)/D) mit

| Profil `payment_profile` | F(x) |
|---|---|
| `linear` (Default) | x |
| `s_curve` | 3x² − 2x³ (Beta(2,2)-Verteilungsfunktion) |
| `front` | 1 − (1 − x)² |
| `back` | x² |

Danach ZP mit diesen Ereignissen (alle mit derselben Verschiebung s). Auf dem Jahresraster fallen alle Monate eines
Kalenderjahres in dieselbe Periode; das Profil wirkt dann nur über Jahresgrenzen hinweg.

**JB – laufender Jahresbetrag (R-62).** Jahresbetrag A (n-Vektor oder n × (T+1)) in Preisen von d₀, Wachstumsrate g,
Wirkungszeitraum [from, to) mit Verschiebung s:

```text
value_t = sign * A_t * I^Y_t(g, d0) * Δ_t * ω_t(from + s, to)       # Spec 00 §7.12 (recurring)
```

**AF – Aktivierung.** Jede aus einer Maßnahme m abgeleitete Zahlung und Wirkung wird mit a_m multipliziert
(maskiert, vektorisiert). a_m ist ein Parameter `active` (value 0/1) der erzeugten Komponente; der Expander setzt ihn
als `expr` (4.5): `{expr: "measures.<m>.active * funding.<f1>.approved * …"}` über alle Förderinstrumente f mit
`on_reject: drop_measures`, die m fördern (Spec 00 §4.12 Nr. 7). Ohne solche Instrumente: `{ref: measures.<m>.active}`.

### 0.4 Abgrenzung zu Spec 00

Spec 00 legt Strukturen, Signaturen, Ledger-Kategorien, Instrument- und Engine-Algorithmen fest. Teil A nennt je
Block und Typ **alle** Felder (auch die in Spec 00 bereits genannten, mit Verweis), ihre Defaults und Prüfregeln, und
schreibt die Algorithmen dort aus, wo Spec 00 sie offenlässt („Spec 01 konkretisiert“). Stellen, an denen Spec 00
geändert werden müsste, sind als `S01A-nn` markiert (Abschnitt 11).

---

## 1. Szenario-Meta, Projekt, Raster, Perspektive, Analyse

### 1.1 `meta`

| YAML-Pfad | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo-Ref |
|---|---|---|---|---|---|---|---|
| `schema_version` | int | – | – | ja | E: `== 1` | Schemaversion (oberste Ebene) | Spec 00 §4.2 |
| `meta.scenario_id` | chr | – | – | ja | E: `^[a-z][a-z0-9_]*$`, ≤ 40 Zeichen, kein `__` | Kennung des Szenarios; erscheint in `meta` jedes Ergebnisses | Spec 00 §4.3.1 |
| `meta.project_id` | chr | – | `= scenario_id` (A) | nein | E: id-Muster | Projektkennung (Portfolio v2, R-50) | Memo 07 §3.1 |
| `meta.title` | chr | – | – | ja | E: nicht leer; W: > 120 Zeichen | Titel (Bericht, Tabellenkopf) | Spec 00 §4.3.1 |
| `meta.author` | chr | – | `NULL` | nein | – | Verfasser bzw. Stelle | – |
| `meta.description` | chr | – | `NULL` | nein | – | Freitext (Markdown erlaubt) | – |
| `meta.created_date` | date | – | `NULL` | nein | W: nach `project.valuation_date` + 1 Jahr | Erstellungsdatum | – |
| `meta.version` | chr | – | `NULL` | nein | – | freie Versionsangabe des Szenarios (z. B. `"2026-10-25a"`); nur Anzeige | Konzept 5.4 |
| `meta.tags` | chr[] | – | `[]` | nein | E: id-Muster je Eintrag | Schlagworte (Filter, Batch) | – |

### 1.2 `project`

| YAML-Pfad | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo-Ref |
|---|---|---|---|---|---|---|---|
| `project.perspective` | enum:perspective | – | – | ja | E: Code aus `wu_kommunal`, `wu_genossenschaft`, `wu_privat`, `kleinvermieter`, `selbstnutzer` | wählt Profil (Schicht 2), Steuerregime, Berichtsmodus | Spec 00 §4.3.2, R-08, Konzept F9 |
| `project.tax_regime` | enum:tax_regime | – | aus Perspektive (A, Tabelle 1.4) | nein | E: Code; W: Kombination unüblich (z. B. `selbstnutzer` mit `wu_kapges`) | Steuerregime (v1 nur Kennzeichen, Hinweistexte) | Memo 06 §7.1 |
| `project.project_type` | enum:project_type | – | – | ja | E: Code aus `neubau`, `sanierung_eh`, `sanierung_einzelmassnahmen`, `sanierung_stufenweise`, `heizungstausch`, `erwerb_sanierung`, `erwerb_neubau` | Projektart; steuert Ableitungen (1.4), Primärkennzahl (Spec 00 §12.3a) | R-09 |
| `project.comparison_mode` | enum:`absolute`,`differential` | – | `absolute` (G) | nein | W bei `differential` („Vereinfachungsmodus“) | Total-VoFi je Variante bzw. Differenzzahlungen | Konzept F1, R-04 |
| `project.valuation_date` | date | – | – | ja | E: Monatserster; W: vor `legal_state` − 1 Jahr | Bewertungsstichtag t = 0 | Spec 00 §3.1 |
| `project.horizon_years` | int | a | `30` (G); `40` für `neubau`, `erwerb_neubau` (G, `by_project_type`, 2.1) | nein | E: 1 ≤ H ≤ 100; E: Horizontende ≤ Ende Bauphase; W: H < 10 oder H > 60 | Horizont ab Stichtag; Horizontende = Stichtag + 12·H Monate, fest für alle Varianten und Läufe; beim Neubau inklusive Bauzeit | Konzept A3, F16, R-67 |
| `project.application_date` | date | – | `= valuation_date` (A) | nein | W: nach dem frühesten Maßnahmentermin („Antrag nach Vorhabenbeginn“) | Förderstichtag (Degression, Programmwahl) | Memo 02 §9.1 |
| `project.legal_state` | date | – | `= valuation_date` (A) | nein | W: > 6 Monate nach dem Bibliotheksstand | Rechtsstand für `legal/*`, Regeln | Spec 00 §4.10 |
| `project.pending_reforms` | chr[] enum:reform | – | `[]` (G) | nein | E: Codes aus `enums.yaml` (`mietrecht_ii`, `stufe_2045`, `unreleased`) | anhängige Reformen/Szenario-Schalter | D10, Konzept F5 |
| `project.federal_state` | enum:federal_state | – | `NULL` | bedingt | E: Code aus `BW`, `BY`, `BE`, `BB`, `HB`, `HH`, `HE`, `MV`, `NI`, `NW`, `RP`, `SL`, `SN`, `ST`, `SH`, `TH` (Schlüssel von `legal/grunderwerbsteuer_2026`, Spec 00 §2.11, X-27); E: Pflicht, sobald Grunderwerbsteuer anfällt (Maßnahme `erwerb_*` bzw. Komponente `acquisition_cost` ohne `grest_rate`, 4.8) | Bundesland (GrESt, Landesverordnungen) | Spec 00 §7.11 |
| `project.municipality.mietpreisbremse_area` | lgl | – | `false` (G) | nein | – | Gebiet mit Mietpreisbremse (Teil B) | Memo 02 §2.8 |
| `project.municipality.mietpreisbremse_until` | date | – | `NULL` | nein | W: gesetzt bei `mietpreisbremse_area: false` | Ende der Landesverordnung | Memo 02 §2.8 |
| `project.municipality.kappung_15_area` | lgl | – | `false` (G) | nein | – | 15-%-Kappungsgebiet (Teil B) | Memo 02 §2.1 |
| `project.municipality.index_cap_area` | lgl | – | `false` (G) | nein | I: wirkt nur mit `mietrecht_ii` | Indexmieten-Dämpfung (Teil B) | Memo 02 §2.7 |
| `project.municipality.milieuschutz` | lgl | – | `false` (G) | nein | – | Erhaltungs-/Milieuschutzsatzung (§ 9 CO2KostAufG, Teil B) | Konzept 3.8 |
| `project.price_base_year` | int | Jahr | `Jahr(valuation_date) − 1` (A) | nein | E: 1990 ≤ Y ≤ Jahr(valuation_date) + 5; W: Preisindex einer Maßnahme in t = 0 < 1 (F-18) | Default-Preisstand aller Kosten: (Y+1)-01-01 | R-35 |
| `project.construction_delay_months` | number | Monate | `0` (G) | nein | E: ≥ 0; W: > 36 | Bauzeitverzug (stochastisch zulässig): verschiebt Wirkungen „ab Fertigstellung“; Kreditermine bleiben fest | Spec 00 §3.9, R-60 |
| `project.construction_cost_factor` | number | 1 | `1` (G) | nein | E: > 0; W: < 0,8 oder > 2 | **gemeinsamer** Kostenabweichungsfaktor aller Maßnahmen, deren `cost_factor` den Default behält (Konzept 3.2, B9 „gleiches Risiko = gleicher Schlüssel“); Overlay-Ziel für eine projektweite Kostenüberschreitung | Konzept 3.2, B9 |
| `project.reference_variant` | chr | – | `"base"` (G) | bedingt | E: existierende Variante; E: bei Bestandsprojekten (Spec 00 §1.5) eine Variante ≠ Unterlassung, außer `analysis.allow_opportunity_reference: true` | Referenz des Vergleichs (Bestands- bzw. Ohnehin-Variante) | Spec 00 §9.6, R-68 |
| `project.report_mode` | enum:`auto`,`expert`,`household` | – | `auto` (P) | nein | – | Berichtsmodus; `auto` nach 1.4 | D11 |

**Begriffe.** *Bestandsprojekt* = `project_type` ∈ {`sanierung_eh`, `sanierung_einzelmassnahmen`,
`sanierung_stufenweise`, `heizungstausch`} (Spec 00 §1.5). *Neubauprojekt* = `neubau`, `erwerb_neubau`.
*Erwerbsprojekt* = `erwerb_sanierung`, `erwerb_neubau`.

### 1.3 `grid` und Horizont

Felder nach Spec 00 §4.3.3 (der frühere Schalter `horizon_from` entfällt, R-67).

| YAML-Pfad | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo-Ref |
|---|---|---|---|---|---|---|---|
| `grid.construction_months` | int | Monate | `0` (G) | nein | E: ≥ 0; E: < 12·H; W: Neubau-/Erwerbsneubauprojekt mit `0`; W: weicht um > 3 Monate vom spätesten `completion_date` der Maßnahmen mit `follows_construction: true` ab (4.1) | Bauzeit ab Stichtag; Fertigstellung `completion_date` = Stichtag + C Monate | Spec 00 §3.3 |
| `grid.construction_step_months` | int ∈ {1, 3, 6, 12} | Monate | `12` (G) | nein | E: Code; I: `< 12` ohne Bauphase wirkungslos | Periodenlänge in der Bauphase | D2, R-01 |
| `grid.operation_step_months` | int | Monate | `12` (G) | nein | E: v1 nur 12 | Periodenlänge im Betrieb | Spec 00 §3.3 |
| `grid.operation_alignment` | enum:`calendar`,`completion` | – | `calendar` (G) | nein | – | Betriebsjahre als Kalenderjahre (Stub-Periode) oder ab Fertigstellung | Spec 00 §3.3, F-17 |
| `grid.periods_months` | int[] | Monate | `NULL` | nein | E: Einträge ganzzahlig ≥ 1; I: Summe ≠ 12·H | explizites Raster (Orakel (e)) | Spec 00 §3.3 |

**Festlegungen (Konkretisierung von Spec 00 §3.3, R-67, Konzept F16, A3).**

1. Das Horizontende `end_date` = `valuation_date` + 12 · `horizon_years` Monate ist für alle Varianten eines
   Szenarios und alle Läufe identisch. Eine Variante mit abweichender Bauzeit setzt `grid.construction_months` in der
   Variante; das Raster ändert dann die Periodeneinteilung, nicht `end_date` (Spec 00 §9.6 Nr. 2 prüft `end_date`).
2. Beim Neubau enthält `horizon_years` die Bauzeit: Default 40 Jahre ab Stichtag (A3), d. h. bei 24 Monaten Bauzeit
   38 Betriebsjahre.
3. Ein Bauzeitverzug (`project.construction_delay_months`) verschiebt nur die Wirkungen mit dem Termin-Token
   `completion` (Mietbeginn, Betriebskosten, Energiezustand „nachher“, Instandhaltung ab Fertigstellung); Zahlungen der
   Maßnahmen verschieben sich nur nach `measures.<m>.construction_delay_mode` (4.1) und Kredite nie (R-47).

**Tests (WS-A, `test-scenario-layers.R`; Raster: Integrator, Spec 00 §3.8).**

| Nr. | Eingabe | Erwartung |
|---|---|---|
| GA1 | `project_type: neubau`, kein `horizon_years`, `grid.construction_months: 24` | `horizon_years = 40` (Herkunft `global`, Eintrag `by_project_type.neubau`), T = 40, `end_date = 2067-01-01` bei Stichtag 2027-01-01 |
| GA2 | `project_type: sanierung_eh`, kein `horizon_years` | `horizon_years = 30`, `end_date = 2057-01-01` |
| GA3 | Variante `v2` mit `grid.construction_months: 12`, Basis mit 24, beide `horizon_years: 40` | beide `end_date = 2067-01-01`; Basis T = 40 (C = 24, Jahresraster), `v2` T = 40; `vofi_compare()` meldet keinen Rasterfehler für `end_date` |
| GA4 | `horizon_from: completion` im Szenario | E `validation.unknown_key` mit Vorschlag (Feld entfallen, R-67) |

### 1.4 Perspektive, Steuerregime und Ableitungsregeln

Ableitungsregeln setzen Defaults, die von anderen Feldern abhängen (Spec 00 §4.7 „Ableitungsregeln“, R-86; Antrag
S01A-06, entschieden). Sie laufen in `vofi_resolve()` (WS-A, `R/scenario-layers.R`) **nach** Schicht 8 auf der
aufgelösten Variante, **vor** `item_defaults` (2.1) und vor den Expandern, und zwar je Variante, je Szenario-Set und je
Override neu (`by_project_type` wird dagegen als Teil der Schichten 1–2 gemischt, 2.1). Sie setzen nur **fehlende**
Blätter bzw. lösen den Code `auto` eines Enum-Felds auf; ein fehlendes Feld gilt als `auto`. Sie schreiben Werte, Codes
oder Bezugs-/Ausdrucksknoten – Bezüge dürfen auf Blätter zeigen, die erst `item_defaults` füllt –, nie aus
overlay-fähigen numerischen Blättern berechnete Konstanten (Spec 00 §4.12 Nr. 5). Ausgewertet werden deterministische
Termine, Codes, Flags sowie `bctx$legal()`- und `bctx$lib()`-Werte; einzige Ausnahme ist die Ableitung eines Codes aus
Basisfallwerten in 4.5.1 Nr. 6 (Antrag S01A-11). Regeln für Gebäudefelder laufen nur, wenn `building` existiert.
Herkunft `source_type = "type_default"`, `layer = 0`, `entry = "rule:<regel>"` bzw. die Bibliotheks-id, aus der der
Wert stammt. Ableitungsregeln sind **keine** Registry-Regeln (Abschnitt 7); ein Paket, das ihr Ergebnis braucht, liest
das abgeleitete Domänenblatt. Eigentümer ist WS-A (N-07). Die Regeln dieses Teils laufen in der Reihenfolge der
Tabelle, mit einer Ausnahme: Schritt Nr. 6 von `rule:measure_catalog` (4.5.1) läuft nach `rule:cost_from_kg`. Teil B
ergänzt `rule:unit_group_defaults`, `rule:carrier_defaults`, `rule:approval_timing`,
`rule:approval_probability` und `rule:tax_credit_defaults` (Teil B §4, §5).

| Regel | Feld | Ableitung |
|---|---|---|
| `rule:tax_regime` | `project.tax_regime` | `wu_kommunal` → `wu_kommunal`; `wu_genossenschaft` → `wu_eg_befreit`; `wu_privat` → `wu_kapges`; `kleinvermieter` → `privat_vermieter`; `selbstnutzer` → `selbstnutzer` (Spec 00 §4.3.2) |
| `rule:report_mode` | `project.report_mode` = `auto` | `wu_*` → `expert`, sonst `household` (beim Ergebnis aufgelöst, `meta$report_mode`) |
| `rule:dates` | `project.application_date`, `project.legal_state` | `= valuation_date` |
| `rule:price_base_year` | `project.price_base_year` | `Jahr(valuation_date) − 1` |
| `rule:project_id` | `meta.project_id` | `= meta.scenario_id` |
| `rule:tenant_view` | `analysis.tenant_view` | `TRUE` für `wu_*`, sonst `FALSE` (Profilwert, hier nur Rückfall) |
| `rule:building_aggregates` | `building.n_units`, `building.living_area_m2`, `building.land_value_eur`, `building.market_value_eur` | Summe über `unit_groups` als `expr`, wenn im Gebäude nicht angegeben (3.4); `land_value_eur` = `{expr: "building.land_area_m2 * building.land_value_eur_m2"}`, wenn beide gesetzt; `market_value_eur` = `{ref: building.existing_value_eur}`, wenn dieses gesetzt ist (3.1) |
| `rule:first_occupancy` | `building.first_occupancy_year` | `= building.construction_year`; bei Neubauprojekten Jahr(`grid$completion_date` − 1 Tag) |
| `rule:measure_catalog` | fehlende Felder je Maßnahme und Bauteil | Katalogwerte aus `costs/massnahmentypen_2026`, `costs/nutzungsdauern_2026`, `costs/kostenzuschlaege_2026`, `costs/erwerbsnebenkosten_2026` (`entry` = Bibliotheks-id) und abgeleitete Felder (Termine, Projektart, Nutzungsdauer der Hauptmaßnahme, PV-Umsatzsteuer und PV-Leistung, `modernization_kind: none` bei Erhaltung; `entry = "rule:measure_catalog"`); vollständig in 4.5.1 |
| `rule:cost_from_kg` | `measures.<m>.cost_eur` bei `cost_kg` bzw. bei `payment_schedule` mit `unit: eur` | `expr` der Grundkosten K⁰ bzw. Summe der Beträge des Zahlungsplans (4.6.1; X-28) |
| `rule:maintenance_from` | `building.maintenance.from`, `building.maintenance.basis` (fehlend bzw. `auto`) | `from`: Neubauprojekt Token `completion`, Erwerb Erwerbsdatum, sonst `valuation_date`; `basis`: `rate`, wenn `rate_eur_m2_pa` vor `item_defaults` gesetzt ist (Szenario, Variante, Set, Override), sonst Neubauprojekt `iibv`, sonst `rate` (3.3, F-22) |

**Perspektiven (Übersicht der Profilwerte, Details Abschnitt 2):**

| Perspektive | Steuerregime | Bericht | Habenzins | KK-Zins | KK-Limit | D4-Aktion | Zielrendite | Restwert (Default) | Mieterblick |
|---|---|---|---|---|---|---|---|---|---|
| `wu_kommunal` | `wu_kommunal` | Fach | 3,5 % | 5,5 % | ∞ (Warnschwelle) | `penalty_rate` (+2 Pp.) | 3,5 % | Ertragswert | ja |
| `wu_genossenschaft` | `wu_eg_befreit` | Fach | 2,0 % | 5,5 % | ∞ | `penalty_rate` (+2 Pp.) | 2,0 % (Mindestverzinsung) | Ertragswert | ja |
| `wu_privat` | `wu_kapges` | Fach | 3,5 % | 5,5 % | ∞ | `penalty_rate` (+2 Pp.) | 3,5 % | Ertragswert | ja |
| `kleinvermieter` | `privat_vermieter` | Haushalt | 2,5 % | 6,0 % | 0 € | `equity_call` | 2,5 % | Ertragswert | nein |
| `selbstnutzer` | `selbstnutzer` | Haushalt | 2,5 % | 6,0 % | 0 € | `equity_call` | 2,5 % | Sachwert (Neubau) bzw. Komponenten-Zeitwert (Bestand) | nein |

Quelle: Konzept A2 (Konten), A3 (Horizont, Restwert, Verkaufskosten 3 %), A4 (Schwellen), F18 (Habenzins je
Perspektive), R-76. Der Habenzins hat in allen Perspektiven die Untergrenze 0 (`floor: 0`, F-14, Memo 04 §1.2). Mit
unendlichem KK-Limit und unendlicher Markierungsschwelle (WU-Profile) ist `restriction_liquidity` nicht prüfbar (NA
`no_liquidity_limit`, kein K.-o.; W `validation.accounts.liquidity_unchecked`, Spec 00 §12.3, R-101); eine
projektbezogene Kreditlinie bzw. Warnschwelle macht die Restriktion wirksam (5.7).

### 1.5 `analysis`

Felder nach Spec 00 §4.3.14; Werte je Perspektive in Abschnitt 2. Teil C konkretisiert die MC-Auswertung und das Set
„vorsichtig“; hier stehen Schema und Defaults.

| YAML-Pfad | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo-Ref |
|---|---|---|---|---|---|---|---|
| `analysis.kpis` | chr[] \| `"default"` | – | `"default"` (G); Liste je Perspektive (P) | nein | E: registrierte KPI-Schlüssel (inkl. `_ex_rv`-Formen nicht angeben, sie entstehen automatisch); I: perspektivfremde KPI wird `NA` (`not_applicable_perspective`) | Kennzahlensatz des Modells | Spec 00 §9.1 Stufe 9, §12.3 |
| `analysis.primary_kpi` | enum:`auto`,`delta_terminal_value`,`delta_vs_reference` | – | `auto` (G) | nein | E: `delta_terminal_value` bei Bestandsprojekt im Modus `absolute` (`validation.reference_variant_missing`), außer `allow_opportunity_reference = true` (dann W) | Primärkennzahl | Spec 00 §12.3a, R-68 |
| `analysis.allow_opportunity_reference` | lgl | – | `false` (G) | nein | – | erlaubt bei Bestandsprojekten ausdrücklich die Unterlassungsalternative als Referenz | Konzept F17, R-68 |
| `analysis.deterministic_point` | enum:`mode`,`median`,`mean` | – | `mode` (G) | nein | – | Basiswert von Kurzform-Verteilungen ohne `base` | Spec 00 §4.5 Regel 1 |
| `analysis.thresholds.dscr` | num | 1 | `1.2` (G) | nein | E: > 0 | DSCR-Schwelle (Covenant), ab Stabilisierungsjahr | Konzept A4 |
| `analysis.thresholds.burden_share` | share | 1 | `0.40` (G) | nein | – | Schwelle der Belastungsquote (Selbstnutzer) | Konzept A4 |
| `analysis.thresholds.warm_rent_increase_eur_m2` | num | EUR/m²·Monat | `0.50` (G) | nein | E: ≥ 0 | Schwelle des Warmmietenanstiegs | Konzept A4 |
| `analysis.thresholds.roe_hurdle` | rate | 1/a | P: WU kommunal/privat `0.035`, eG `0.020`, privat `0.025` | nein | – | Zielrendite (Lücke zur EK-Rendite im Bericht) | Konzept A2, A4, F18 |
| `analysis.stabilization_year` | int | Jahr | `NULL` (G) = Kalenderjahr des ersten vollen Betriebsjahres | nein | E: im Horizont; W: vor Fertigstellung | Beginn der DSCR-/ICR-Auswertung | Konzept 2.5, A4, R-77 |
| `analysis.lending_value_haircut` | share | 1 | `0.10` (G) | nein | – | Sicherheitsabschlag: Beleihungswert = V_t · (1 − Abschlag) | Konzept 2.5 („Vorschlag 10 %, Abl.“) |
| `analysis.rv_path_basis` | enum:`auto`,`method`,`measures` | – | `auto` (G) | nein | – | Restwertpfad der Vermögensamortisation (`auto` = `measures` im Haushaltsmodus, sonst `method`) | Spec 00 §4.3.14, R-72 |
| `analysis.restrictions` | chr[] ⊆ `dscr`, `liquidity`, `warm_rent`, `burden`, `savings` | – | P (2.3–2.8) | nein | E: Codes; W `validation.accounts.liquidity_unchecked`, wenn `liquidity` gewählt ist und weder Limit noch Markierungsschwelle endlich sind (5.7, R-101) | K.-o.-Kennzeichen der Ampelstufe 2 | Konzept 1.4, R-74 |
| `analysis.traffic_light.green_prob` | share | 1 | `0.70` (G) | nein | E: > `red_prob` | Ampel Stufe 1 grün ab P(besser) | Konzept 1.4, A4 |
| `analysis.traffic_light.red_prob` | share | 1 | `0.40` (G) | nein | – | Ampel Stufe 1 rot unter P(besser) | Konzept 1.4, A4 |
| `analysis.traffic_light.restriction_prob` | share | 1 | `0.30` (G) | nein | – | Stufe 2: Restriktion gilt als verletzt ab P(Verletzung) | Konzept 1.4, A4 |
| `analysis.mandatory_sensitivities` | Liste von Maps | – | P (2.3–2.7; Inhalte Teil C §4.4) | nein | E: je Eintrag `id` (id-Muster, eindeutig), `path` (existierender Pfad), genau eines von `value`, `delta`, `add`; `label` (de) | Pflichtsensitivitäten (Design-Läufe bzw. Schicht 8) | Konzept 3.11, 3.12, A2, B4, F5, R-82 |
| `analysis.tenant_view` | lgl | – | P: `true` für `wu_*`, sonst `false` | nein | W: `true` ohne `unit_groups` | Warmmieten-/Mietersicht | Spec 00 §4.3.14 |

**Default-Kennzahlensätze (`analysis.kpis: default`).** Die Liste wird je Perspektive im Profil geführt
(2.3–2.7); `_ex_rv`-Formen entstehen automatisch (Spec 00 §12.5). Gemeinsamer Kern aller Perspektiven:
`terminal_value`, `terminal_value_opp`, `delta_terminal_value`, `roe_mirr`, `payback_time`, `payback_year`,
`min_net_liquidity`, `max_overdraft`, `max_financing_need`, `sum_equity_calls`, `pv_equity_calls`, `flag_shortfall`,
`flag_limit_breach`, `flag_reserve_used`, `withdrawal_equivalent`, `terminal_value_real`, `own_contribution`,
`pv_subsidies`, `co2_emissions` sowie `restriction_<code>` für jeden Code in `analysis.restrictions`. Zusätze: WU und
Kleinvermieter `roe_irr`, `npv_cf_project`, `irr_cf_project`; WU `dscr_min`, `dscr_mean`, `dscr_years_below`,
`dscr_min_new`, `icr_min`, `ltv_max`, `ltv_end`, `lending_ratio_max`, `warm_rent`, `warm_rent_y1`,
`warm_rent_change_prepost`, `warm_rent_change_prepost_y1`; Kleinvermieter `dscr_min`, `dscr_min_new`, `ltv_max`,
`lending_ratio_max`, `monthly_net_cashflow`, `monthly_net_cashflow_y1`, `monthly_net_cashflow_min`; Selbstnutzer
`monthly_burden`, `monthly_burden_y1`, `monthly_burden_avg10`, `monthly_burden_construction`, `burden_ratio_max`.
Vergleichskennzahlen (`delta_vs_reference`, `incremental_return`, `payback_vs_reference`, `co2_reduction`,
`co2_abatement_cost`, `monthly_saving_*`, `monthly_cashflow_change_y1`, `warm_rent_change_y1`) sind nicht Teil von
`analysis.kpis`; `vofi_compare()` berechnet sie nach Spec 00 §12.6 für die Perspektive passend.

**Pflichtsensitivitäten (Konkretisierung von Spec 00 §4.3.14).** Inhalte je Perspektive nach Konzept 5.5 und
Teil C §4.4 (dort Ausführung und Prüffälle); Ablage in den Profilen (2.3–2.7). `value` darf eine Wertform sein
(z. B. `{ref: market.mortgage_rate}`, Teil C S01C-09) und ersetzt die Form des Basisfalls einschließlich einer
`anchor`-Kopplung; `delta` addiert auf den Basiswert, bei einer Bezugsform mit `anchor` auf den Anker (die Kopplung an
den Zinspfad bleibt erhalten); `add` hängt Codes an eine Liste an (R-82). Ergebnisse tragen
`meta$sensitivity = <id>`.

### 1.6 `tax`

| YAML-Pfad | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo-Ref |
|---|---|---|---|---|---|---|---|
| `tax.module` | chr | – | `"none"` (G) | nein | E: registriertes Steuermodul; E: Sperre nach Perspektive/Regime (Spec 00 §10.2); E: `flat` zusammen mit `accounts.deposit_withholding_tax_share > 0` (§10.7) | Steuermodul | D5 |
| `tax.params` | map | – | `{}` (G) | nein | modulspezifisch | Parameter des Moduls | Spec 00 §10.2 |

Ergebnisse der Perspektiven `kleinvermieter` und `wu_privat` tragen den Steuerwarnhinweis
(`report.tax_warning_<regime>`, WS-H); für `wu_genossenschaft` den Hinweis zu Nebenerlösen (Konzept 3.12, Teil B).

---

## 2. Defaults: `global.yaml` und Perspektiven-Profile

### 2.1 Dateiformat und Mischregeln

`inst/extdata/defaults/global.yaml` (Schicht 1) und `inst/extdata/profiles/<perspective>.yaml` (Schicht 2) haben die
Gestalt eines Szenario-Teilbaums mit reservierten Schlüsseln der obersten Ebene (Spec 00 §4.2 Fußnote ³, §4.7
„Defaults-Dateien“, R-85; Antrag S01A-01, entschieden). In Szenario-, Overlay- und Bibliotheksdateien sind diese
Schlüssel ein Validierungsfehler.

| Schlüssel | Datei | Pflicht | Inhalt |
|---|---|---|---|
| `defaults_meta` | beide | ja | `{kind: global \| profile, id, schema_version: 1, as_of, quality, source, note}`; wird nie gemischt, nur in `meta$defaults` des Ergebnisses und in der Herkunft (`entry`) geführt |
| `by_project_type` | beide | nein | Map `project_type → Teilbaum`; der Teilbaum des aktuellen `project.project_type` wird **unmittelbar nach** der eigenen Datei gemischt (Schicht 1b bzw. 2b, Herkunft `global` bzw. `profile` mit `entry = "<datei>#by_project_type.<code>"`); im Profil gilt R-76 |
| `item_defaults` | nur `global.yaml` | nein | einstufige Map Pfad (Zeichenkette mit Punkten) → Vorlage für **Elemente von Sammlungen** (`measures`, `building.elements`, `unit_groups`, `funding`, `energy.carriers`, `energy.stages`, `financing`, `components`) und für **optionale Blöcke** (`building`, `household`, `energy`, `energy.pv`, `energy.performance_gap`, `energy.before`, `energy.after`, `building.property_tax`, `building.maintenance`). Angewandt nach den Ableitungsregeln (1.4) in aufsteigender Pfadtiefe: je vorhandenem Element `element <- deep_merge(vorlage, element)` (das Element gewinnt), bei optionalen Blöcken nur, wenn der Block existiert. Platzhalter `{id}` in Pfaden von `ref`-/`expr`-Knoten = Element-id; `from:` in Vorlagen wird vorher nach Schicht 3 aufgelöst. Herkunft `global`, `layer = 1`, `entry = "global#item_defaults.<pfad>"` |
| alle übrigen | – | – | Blöcke des Szenarios (Spec 00 §4.2), gemischt nach Spec 00 §4.7. Felder der optionalen Blöcke `building`, `household`, `energy` stehen **nie** hier, sondern nur unter `item_defaults` (N-05); sonst entstünde der Block in jedem Szenario, z. B. in den Orakeln und im Gerüst (Spec 00 Anhang A) ohne Gebäude |

Reihenfolge (Spec 00 §4.7): Schicht 0 (Typ-/Schema-Defaults) → `global.yaml` → `global.yaml#by_project_type` → Profil →
`Profil#by_project_type` → Schichten 3–8 → **Ableitungsregeln** (1.4) → **`item_defaults`** → Expander (4.5, 6.2). Die
spezifische Ableitung läuft vor der allgemeinen Vorlage (R-86): z. B. setzt `rule:maintenance_from` bei einem Neubau
`building.maintenance.basis: iibv`, bevor `item_defaults.building` die übrigen Instandhaltungsfelder füllt. Die
Profilrestriktion von Spec 00 §4.7 (R-76: nur `accounts.*`, `analysis.*`, `residual_value.method`,
`residual_value.sale_cost_share`, `project.horizon_years`, `project.report_mode`, `tax.module`, `scenario_sets`; keine
Felder von Sammlungselementen) gilt **auch** für `by_project_type` im Profil; `global.yaml` ist nicht beschränkt.

**Existenz von Pfaden.** Pfade, die erst eine Ableitungsregel oder `item_defaults` anlegt (z. B.
`measures.<m>.useful_life_years`, `measures.<m>.cost_factor`, `measures.<m>.delay_months`,
`building.maintenance.rate_eur_m2_pa`), existieren im aufgelösten `vofi_spec` und sind dort Overlay- und Designziele.
Varianten-Operationen (Schicht 7) laufen davor; bis zur Entscheidung über S01A-10 setzt eine Variante einen solchen Pfad
über die vorhandene Elternmap (`set: {measures.wp: {cost_factor: 1.2}}`, Map-Merge am existierenden Pfad, Spec 00
§4.11).

`analysis.kpis: "default"` im Szenario bedeutet „Wert der Schicht 2“ (Profilliste). Sequenzen (`kpis`,
`surplus_order`, `deficit_order`, `mandatory_sensitivities`, `restrictions`) werden als Ganzes ersetzt (Spec 00 §4.7).

Bibliotheksverweise (`from:`) in den Defaults werden in Schicht 3 aufgelöst, in `item_defaults` vor der Anwendung der
Vorlage (Spec 00 §4.9); die ids und Unterpfade (`use`) sind die der Einträge in Teil C §3.3–3.8, und **jeder** Verweis
in `global.yaml` und den Profilen MUSS auflösen (PR7, `test-profiles.R`, R-104). Eine Nutzlast ohne Map-Struktur
(Skalar, Sequenz) oder eine Wertform ersetzt den Knoten; lokale Zusatzschlüssel sind dann ein Fehler (R-87; Antrag
S01A-02, entschieden). **Die Datei ist die Vereinigung der Teile (N-04):** Teil A liefert die Blöcke in 2.2 und die
Vorlagen `item_defaults.building`, `item_defaults.measures` und `item_defaults."building.elements"`; Teil B ergänzt
`item_defaults.unit_groups`, `item_defaults.energy`, `item_defaults."energy.carriers"` (mit `price_eur_kwh: {ref:
market.energy_price.{id}}`), `item_defaults."energy.pv"`, `item_defaults."energy.performance_gap"`,
`item_defaults.funding` (u. a. `availability_after_2030: 0.7`), `item_defaults."building.property_tax"` und die Vorlage
des Blocks `household` (Teil B §7.1, Kommentar `# 01b`); Teil C liefert `stochastic.settings` (gleichlautend 2.2) und
die weiteren Standard-Sets (Teil C §4.2).

### 2.2 `inst/extdata/defaults/global.yaml` (Teil-A-Inhalt, vollständig)

```yaml
defaults_meta:
  kind: global
  id: global
  schema_version: 1
  as_of: 2026-10-26
  quality: D                       # Zusammenstellung; Einzelwerte mit Quelle im Kommentar
  source: "Spec 01 Teil A §2.2; Konzept §11.2/§11.3; Memo 03"
  note: "Teil B ergänzt item_defaults (unit_groups, energy, household, funding, building.property_tax), Teil C stochastic.settings und Standard-Sets"

project:
  comparison_mode: absolute        # Konzept F1, R-04
  horizon_years: 30                # Konzept A3 (Sanierung 30 J.)
  pending_reforms: []              # D10
  construction_delay_months: 0     # Spec 00 §3.9
  construction_cost_factor: 1      # Konzept 3.2: Faktor im Basisfall 1
  reference_variant: base
  report_mode: auto
  municipality:
    mietpreisbremse_area: false
    mietpreisbremse_until: null
    kappung_15_area: false
    index_cap_area: false
    milieuschutz: false

grid:
  construction_months: 0
  construction_step_months: 12     # D2, R-01
  operation_step_months: 12
  operation_alignment: calendar
  periods_months: null

accounts:                          # Rückfallwerte = Privatprofil; jedes Profil setzt den Block vollständig
  deposit_rate_pa: {ref: market.mortgage_rate, anchor: 0.025, floor: 0}   # Konzept F18/A2, R-76; Untergrenze 0 (F-14, Memo 04 §1.2)
  overdraft_rate_pa: {ref: market.mortgage_rate, anchor: 0.060}
  overdraft_limit_eur: 0
  penalty_spread_pa: 0.02          # Konzept A2 (+2 Pp.)
  min_liquidity_eur: 0             # Konzept A2
  deposit_withholding_tax_share: 0 # D5, R-40 (Vorschlagswert 0.26375)
  deposit_tax_allowance_eur_pa: 0  # Sparer-Pauschbetrag, Spec 00 §4.3.10
  overdraft_flag_threshold_eur: .inf
  surplus_order: [od_repay, dep_fill_reserve, dep_invest]
  deficit_order: [dep_withdraw, od_draw, dep_use_reserve, equity_call]
  prepay: {buffer_eur: 0, min_spread_pa: 0}

market:                            # deterministischer Basisfall; Werte aus der Bibliothek (Teil C §3.6), Namen Spec 00 §4.3.11
  from: prices/macro_paths_2026    # inflation, construction_price_index, maintenance_index, rent_growth (0,0175),
  use: market                      # rent_growth_new (0,025), land_value_growth und market_value_growth (je 0,015),
                                   # operating_cost_growth ({ref: market.inflation, offset: 0.005}) (N-16)
  mortgage_rate:   {from: prices/interest_rates_2026_10, use: market.mortgage_rate}     # 0,041 (Konzept 3.10)
  bund_yield_10y:  {from: prices/interest_rates_2026_10, use: market.bund_yield_10y}    # 0,034
  mortgage_spread: {from: prices/interest_rates_2026_10, use: market.mortgage_spread}   # 0,007
  co2_price:       {from: prices/co2_price_paths_2026, use: scenarios.mittel}           # Konzept F8
  energy_price:       {from: prices/energy_prices_2026, use: market.energy_price}       # netto; alle 10 kanonischen Träger gas, gas_mfh, oil, lpg, power, power_mfh, heatpump_power, heatpump_power_mfh, district_heating, pellets (N-15, R-103)
  energy_network_fee:                                                                   # netto (§ 5a CO2KostAufG, Teil B); Wachstum über shared (N-15)
    from: prices/energy_prices_2026
    use: market.energy_network_fee
    gas:     {growth: {ref: shared.network_fee_growth_gas}}
    gas_mfh: {growth: {ref: shared.network_fee_growth_gas_mfh}}
  bio_fuel_premium:   {from: prices/energy_prices_2026, use: market.bio_fuel_premium}   # Teil B (Bio-Treppe)
  feed_in_tariff:     {from: prices/eeg_feed_in_2026, use: market.feed_in_tariff}       # partial_le10kwp, partial_10_40kwp, partial_40_100kwp, full_le10kwp (N-16)
  vacancy_fluctuation: 1           # Faktor der jährlichen Leerstandsschwankung, Basis 1 (Ziel des iid-Prozesses, Teil C K9; N-16)

shared:                            # Overlay-Ziele der Vorlage network_fee_growth (Teil C §1.9); wird nie direkt gerechnet
  network_fee_growth_gas: 0.03     # Memo 07 §4.0 (Netzrückbau), wie prices/referenzszenarien_2026
  network_fee_growth_gas_mfh: 0.03

residual_value:
  method: zero                     # Rückfall; jedes Profil setzt die Methode (Konzept A3)
  sale_cost_share: {from: valuation/verkaufskosten_2026, use: sale_cost_share}          # 0,03 (Konzept A3)
  path_pre_operation: auto         # auto | cost | method | zero (6.2)
  income_value:
    variant: general               # ImmoWertV § 28 (allgemein); simplified = § 29
    cap_rate: {from: valuation/liegenschaftszinsen_2026, use: presets.mid_city}        # 0,035 (Konzept B10)
    remaining_life_method: anlage2 # anlage2 | linear | manual
    remaining_life_years: null     # manual: RND am Horizont
    remaining_life_offset_years: 0 # additiver Zuschlag (Ziel des Schocks remaining_life_shock, Teil C)
    gnd_years: {from: valuation/immowertv_anlage1_2_2026, use: gnd_years.mfh}           # 80 (Anlage 1)
    rnd_table: {from: valuation/immowertv_anlage1_2_2026, use: rnd_coefficients}        # Anlage 2 (deterministisch)
    points_max: {from: valuation/immowertv_anlage1_2_2026, use: modernisation_points_max}
    points_decay_years: null       # null = Punkte zählen ohne Alterung
    income_basis: forward          # forward = nächste 12 Monate; trailing = letzte 12 Monate
    forward_growth: {ref: market.rent_growth}
    cost_forward_growth: {ref: market.inflation}
    include_other_income: false
    land_value_eur: {ref: building.land_value_eur}
    land_value_growth: {ref: market.land_value_growth}
    bwk:
      admin_eur_unit_pa: {from: costs/bewirtschaftung_immowertv_2026, use: admin_per_unit_or_efh_eur_pa}   # 367
      maintenance_eur_m2_pa: {from: costs/bewirtschaftung_immowertv_2026, use: maintenance_eur_m2_pa}      # 14,40
      rent_loss_share: {from: costs/bewirtschaftung_immowertv_2026, use: rent_loss_risk_share.residential} # 0,02
      price_base_year: 2025        # Stand 01.01.2026 = Preisstand 2026-01-01 (R-35)
      index: {ref: market.inflation}
      admin_source: model          # model | ledger
      maintenance_source: model    # model | ledger
      variant_cost_categories: [co2_cost, energy_cost, other_cost]
      vacancy_from_ledger: true
    bog_eur: 0                     # besondere objektspezifische Grundstücksmerkmale (+/-)
    bog_component_residual: false  # Zeitwert der Maßnahmen zusätzlich (Doppelzählung, 6.4)
    stranded_discount_share: 0     # Abschlag auf den Gebäudeertragswert (Konzept 3.11)
    liquidation_floor: true
    demolition_cost_eur: 0
  multiplier:
    factor: {from: valuation/kaufpreisfaktoren_2026, use: gross_rent_multiplier}       # 20 (Konzept 3.11)
    basis: net_cold_rent_incl_levy
    income_basis: forward
    forward_growth: {ref: market.rent_growth}
  exit_yield:
    cap_rate: 0.04                 # D (NOI-Rendite am Horizont)
    income_basis: forward
    forward_growth: {ref: market.rent_growth}
    cost_forward_growth: {ref: market.inflation}
  market_growth:
    base_value_eur: null           # null = existing_value_eur, sonst market_value_eur, sonst Investitionskosten (6.3.4)
    growth: {ref: market.market_value_growth}
    uplift_share: 0
  asset_value:
    life_basis: gnd                # gnd | component
    gnd_years: {ref: residual_value.income_value.gnd_years}
    kg_include: [200, 300, 400, 500, 700]
    include_existing: true
    market_adjustment_factor: 1.0  # Sachwertfaktor (Memo 02 §7.3)
    uplift_share: 0                # Effizienzzuschlag (Memo 07 S5)
    index: {ref: market.construction_price_index}
    land_value_eur: {ref: building.land_value_eur}
    land_value_growth: {ref: market.land_value_growth}
  component:
    indexed: true                  # true: Buchwert × Baupreisindex (Konzept 3.11); false: nominaler Buchwert (R-108)
    include_land: false
    include_existing: auto         # auto = Bestandswert bzw. Gebäudeanteil des Kaufpreises fortgeschrieben (6.3.7)
    existing_growth: {ref: market.market_value_growth}
  user_value:
    value_eur: 0

tax:
  module: none                     # D5
  params: {}

analysis:
  kpis: default
  primary_kpi: auto                # Spec 00 §12.3a
  allow_opportunity_reference: false
  deterministic_point: mode
  thresholds: {dscr: 1.2, burden_share: 0.40, warm_rent_increase_eur_m2: 0.50, roe_hurdle: 0.025}   # Konzept A4
  stabilization_year: null         # erstes volles Betriebsjahr (Konzept A4)
  lending_value_haircut: 0.10      # Konzept 2.5 (Vorschlag 10 %, Abl.)
  rv_path_basis: auto
  restrictions: [liquidity]
  traffic_light: {green_prob: 0.70, red_prob: 0.40, restriction_prob: 0.30}                          # Konzept 1.4, A4
  mandatory_sensitivities:
    - {id: restwert_null, path: residual_value.method, value: zero, label: "Restwert = 0"}
    - {id: stufe_2045, path: project.pending_reforms, add: stufe_2045, label: "mit 2045-Stufe (100 % klimaneutraler Brennstoff ab 2045)"}
  tenant_view: false

scenario_sets:                     # Spec 00 §4.11, R-74; Labels und Inhalte nach Teil C §4.2 (N-22)
  foerderstopp:
    label: "Förderstopp: keine Förderzusage"
    description: "Alle Förderinstrumente ohne Zusage (Konzept B12). Bei Entscheidungsknoten realisiert der Basisfall die Ausweichvariante (Spec 00 §9.11 Nr. 3)."
    set: {funding.*.approved: 0}
  vorsichtig:
    label: "Vorsichtig: ungünstige Werte der fünf stärksten Treiber"
    description: "Aus dem Tornado der Primärkennzahl: die fünf Treiber mit dem größten Ausschlag gleichzeitig auf P10 bzw. P90 (Konzept 1.4, B5)."
    generate: {method: cautious, n_drivers: 5, probs: [0.1, 0.9], kpi: auto, params: auto, exclude: []}
  # weitere Standard-Sets wörtlich nach Teil C §4.2: zinsschock, zins_niedrig, stress_2022, co2_niedrig, co2_hoch,
  # gasnetz_rueckbau, mit_2045_stufe (nur auf Anforderung gerechnet)

stochastic:
  settings:                        # Spec 00 §4.3.15 (R-73, R-97); Semantik und Prüfungen Teil C §1.2, §6.1
    preset: standard               # n_sim aus dem Preset (10.000); global.yaml setzt kein n_sim (R-97)
    seed: 20261025
    sampling: lhs
    block_size: 200                # R-73: feste Blockgröße; F21-Modus über replicates (nie beide, Spec 00 §11.4)
    antithetic: false
    copula: iman_conover
    start_year: null
    store: bands
    keep_runs: [p05, p50, p95]
    keep_runs_kpi: delta_terminal_value
    bands: [net_position, dep_balance, od_balance]
    band_probs: [0.05, 0.25, 0.5, 0.75, 0.95]
    auto_funding_approval: true
    convergence: {rel_halfwidth_mean: 0.005, abs_halfwidth_prob: 0.01}   # nur Ausweis converged (R-97)

by_project_type:
  neubau:        {project: {horizon_years: 40}}      # Konzept A3: Neubau 40 J. inkl. Bauzeit
  erwerb_neubau: {project: {horizon_years: 40}}

item_defaults:                     # Spec 00 §4.7 Nr. 3 (R-85); nach den Ableitungsregeln (1.4), Element gewinnt
  building:                        # nur, wenn das Szenario building enthält (N-05)
    building_id: b1
    denkmal: false
    wpb_flag: false
    commercial_share: 0            # Anteil Gewerbe an der Fläche; > 0 -> Warnung Vorsteuer (Spec 00 §7.10)
    n_parking: 0
    maintenance:                   # Instandhaltung (Typ maintenance, 3.3, 4.11); basis und from setzt rule:maintenance_from
      enabled: true
      rate_eur_m2_pa: {from: costs/bewirtschaftung_immowertv_2026, use: maintenance_eur_m2_pa}   # 14,40 (Anlage 3, 2026; B)
      area_m2: {ref: building.living_area_m2}
      price_base_year: 2026        # Jahresbetrag für 2026 (R-35/R-62: Preisstand Ende 2026 = 2027-01-01)
      growth: {ref: market.maintenance_index}
      to: null                     # = end_date
      vat_rate: 0.19
      excludes_explicit_replacements: false
      iibv:
        rates_eur_m2_pa: {from: costs/bewirtschaftung_ii_bv_2026, use: maintenance_eur_m2_pa}   # {lt22y: 11.50, ge22y: 14.58, ge32y: 18.62} (N-02)
        adjust_eur_m2_pa: 0        # Zu-/Abschläge nach maintenance_adjustments_eur_m2_pa (Aufzug +1,63; Kleinreparaturen -1,70)
        price_base_year: 2026
        reset_by_measures: auto    # auto = Maßnahmen mit effects.maintenance.reset_age: true
  measures:                        # je Maßnahme (4.1); Katalog- und abgeleitete Felder setzt vorher rule:measure_catalog (4.5.1)
    delay_months: 0
    active: 1
    cost_factor: {ref: project.construction_cost_factor}
    cost_is_net: false
    price_index: {ref: market.construction_price_index}
    duration_months: 0
    payment_profile: linear
    kg700_basis: kg300_400
    contingency_basis: kg200_700
    replaces_ohnehin: []
    replaces_elements: []
    replacement: {cost_factor: 1.0, classification: erhaltung, price_index: {ref: "measures.{id}.price_index"}}   # {id} in Flussnotation quoten
  "building.elements":             # je Bestandsbauteil (3.2)
    overdue: first_period
    next_replacement_delay_months: 0
    active: 1
    price_index: {ref: market.construction_price_index}
  # 01b: unit_groups, energy, "energy.carriers", "energy.pv", "energy.performance_gap", funding, household,
  #      "building.property_tax" (Teil B §7.1)
```

### 2.3 `inst/extdata/profiles/wu_kommunal.yaml`

```yaml
defaults_meta: {kind: profile, id: wu_kommunal, schema_version: 1, as_of: 2026-10-26, quality: D,
                source: "Konzept A2, A3, A4, F18; Spec 01 Teil A §2.3"}
project:
  report_mode: auto                # -> expert
accounts:
  deposit_rate_pa: {ref: market.mortgage_rate, anchor: 0.035, floor: 0}   # Kalkulationszins = Zielrendite (F18); Untergrenze 0 (F-14)
  overdraft_rate_pa: {ref: market.mortgage_rate, anchor: 0.055}      # Betriebsmittellinie/Cash-Pool (A2)
  overdraft_limit_eur: .inf                                          # Limit als Warnschwelle (R-57)
  penalty_spread_pa: 0.02
  min_liquidity_eur: 0
  deposit_withholding_tax_share: 0
  deposit_tax_allowance_eur_pa: 0
  overdraft_flag_threshold_eur: .inf
  surplus_order: [od_repay, dep_fill_reserve, dep_invest]
  deficit_order: [dep_withdraw, od_draw, dep_use_reserve, penalty_rate]
  prepay: {buffer_eur: 0, min_spread_pa: 0}
residual_value:
  method: income_value             # A3: Ertragswert bei Vermietung
  sale_cost_share: 0.03
tax:
  module: none
analysis:
  kpis: [terminal_value, terminal_value_opp, delta_terminal_value, roe_mirr, roe_irr, payback_time, payback_year,
         min_net_liquidity, max_overdraft, max_financing_need, sum_equity_calls, pv_equity_calls,
         flag_shortfall, flag_limit_breach, flag_reserve_used, withdrawal_equivalent, npv_cf_project,
         irr_cf_project, terminal_value_real,
         dscr_min, dscr_mean, dscr_years_below, dscr_min_new, icr_min, ltv_max, ltv_end, lending_ratio_max,
         warm_rent, warm_rent_y1, warm_rent_change_prepost, warm_rent_change_prepost_y1,
         own_contribution, pv_subsidies, co2_emissions,
         restriction_dscr, restriction_liquidity, restriction_warm_rent]
  thresholds: {dscr: 1.2, burden_share: 0.40, warm_rent_increase_eur_m2: 0.50, roe_hurdle: 0.035}
  restrictions: [dscr, liquidity, warm_rent]
  tenant_view: true
  rv_path_basis: auto
  lending_value_haircut: 0.10
  traffic_light: {green_prob: 0.70, red_prob: 0.40, restriction_prob: 0.30}
  mandatory_sensitivities:
    - {id: restwert_null, path: residual_value.method, value: zero, label: "Restwert = 0"}
    - {id: habenzins_liquiditaet, path: accounts.deposit_rate_pa, value: 0.02, label: "Habenzins 2,0 % (reine Liquiditätsanlage)"}
    - {id: habenzins_kalkulationszins, path: accounts.deposit_rate_pa, value: 0.035, label: "Habenzins = Kalkulationszins 3,5 %"}
    - {id: habenzins_fk, path: accounts.deposit_rate_pa, value: {ref: market.mortgage_rate}, label: "Habenzins = vermiedener FK-Zins"}
    - {id: stufe_2045, path: project.pending_reforms, add: stufe_2045, label: "mit 2045-Stufe (100 % klimaneutraler Brennstoff ab 2045)"}
by_project_type:
  heizungstausch:             {residual_value: {method: component}}   # A3: Komponenten-Zeitwert bei Einzelmaßnahmen
  sanierung_einzelmassnahmen: {residual_value: {method: component}}
```

### 2.4 `inst/extdata/profiles/wu_genossenschaft.yaml`

```yaml
defaults_meta: {kind: profile, id: wu_genossenschaft, schema_version: 1, as_of: 2026-10-26, quality: D,
                source: "Konzept A2, A3, A4, F18, B3; Spec 01 Teil A §2.4"}
project:
  report_mode: auto
accounts:
  deposit_rate_pa: {ref: market.mortgage_rate, anchor: 0.020, floor: 0}   # Mindestverzinsung (F18); Untergrenze 0 (F-14)
  overdraft_rate_pa: {ref: market.mortgage_rate, anchor: 0.055}
  overdraft_limit_eur: .inf
  penalty_spread_pa: 0.02
  min_liquidity_eur: 0
  deposit_withholding_tax_share: 0
  deposit_tax_allowance_eur_pa: 0
  overdraft_flag_threshold_eur: .inf
  surplus_order: [od_repay, dep_fill_reserve, dep_invest]
  deficit_order: [dep_withdraw, od_draw, dep_use_reserve, penalty_rate]
  prepay: {buffer_eur: 0, min_spread_pa: 0}
residual_value:
  method: income_value
  sale_cost_share: 0.03
tax:
  module: none
analysis:
  kpis: [terminal_value, terminal_value_opp, delta_terminal_value, roe_mirr, roe_irr, payback_time, payback_year,
         min_net_liquidity, max_overdraft, max_financing_need, sum_equity_calls, pv_equity_calls,
         flag_shortfall, flag_limit_breach, flag_reserve_used, withdrawal_equivalent, npv_cf_project,
         irr_cf_project, terminal_value_real,
         dscr_min, dscr_mean, dscr_years_below, dscr_min_new, icr_min, ltv_max, ltv_end, lending_ratio_max,
         warm_rent, warm_rent_y1, warm_rent_change_prepost, warm_rent_change_prepost_y1,
         own_contribution, pv_subsidies, co2_emissions,
         restriction_dscr, restriction_liquidity, restriction_warm_rent]
  thresholds: {dscr: 1.2, burden_share: 0.40, warm_rent_increase_eur_m2: 0.50, roe_hurdle: 0.020}
  restrictions: [dscr, liquidity, warm_rent]
  tenant_view: true
  rv_path_basis: auto
  lending_value_haircut: 0.10
  traffic_light: {green_prob: 0.70, red_prob: 0.40, restriction_prob: 0.30}
  mandatory_sensitivities:
    - {id: restwert_null, path: residual_value.method, value: zero, label: "Restwert = 0"}
    - {id: habenzins_kalkulationszins, path: accounts.deposit_rate_pa, value: 0.035, label: "Habenzins = Kalkulationszins 3,5 %"}
    - {id: habenzins_fk, path: accounts.deposit_rate_pa, value: {ref: market.mortgage_rate}, label: "Habenzins = vermiedener FK-Zins"}
    - {id: stufe_2045, path: project.pending_reforms, add: stufe_2045, label: "mit 2045-Stufe (100 % klimaneutraler Brennstoff ab 2045)"}
by_project_type:
  heizungstausch:             {residual_value: {method: component}}   # Memo 07 S3: linearer Komponentenzeitwert
  sanierung_einzelmassnahmen: {residual_value: {method: component}}
```

### 2.5 `inst/extdata/profiles/wu_privat.yaml`

```yaml
defaults_meta: {kind: profile, id: wu_privat, schema_version: 1, as_of: 2026-10-26, quality: D,
                source: "Konzept A1, A2, A3, A4, F18; Spec 01 Teil A §2.5"}
project:
  report_mode: auto
accounts:
  deposit_rate_pa: {ref: market.mortgage_rate, anchor: 0.035, floor: 0}   # Untergrenze 0 (F-14)
  overdraft_rate_pa: {ref: market.mortgage_rate, anchor: 0.055}
  overdraft_limit_eur: .inf
  penalty_spread_pa: 0.02
  min_liquidity_eur: 0
  deposit_withholding_tax_share: 0
  deposit_tax_allowance_eur_pa: 0
  overdraft_flag_threshold_eur: .inf
  surplus_order: [od_repay, dep_fill_reserve, dep_invest]
  deficit_order: [dep_withdraw, od_draw, dep_use_reserve, penalty_rate]
  prepay: {buffer_eur: 0, min_spread_pa: 0}
residual_value:
  method: income_value
  sale_cost_share: 0.03
tax:
  module: none                     # Steuerwarnhinweis wu_kapges (Konzept 3.12, A1)
analysis:
  kpis: [terminal_value, terminal_value_opp, delta_terminal_value, roe_mirr, roe_irr, payback_time, payback_year,
         min_net_liquidity, max_overdraft, max_financing_need, sum_equity_calls, pv_equity_calls,
         flag_shortfall, flag_limit_breach, flag_reserve_used, withdrawal_equivalent, npv_cf_project,
         irr_cf_project, terminal_value_real,
         dscr_min, dscr_mean, dscr_years_below, dscr_min_new, icr_min, ltv_max, ltv_end, lending_ratio_max,
         warm_rent, warm_rent_y1, warm_rent_change_prepost, warm_rent_change_prepost_y1,
         own_contribution, pv_subsidies, co2_emissions,
         restriction_dscr, restriction_liquidity, restriction_warm_rent]
  thresholds: {dscr: 1.2, burden_share: 0.40, warm_rent_increase_eur_m2: 0.50, roe_hurdle: 0.035}
  restrictions: [dscr, liquidity, warm_rent]
  tenant_view: true
  rv_path_basis: auto
  lending_value_haircut: 0.10
  traffic_light: {green_prob: 0.70, red_prob: 0.40, restriction_prob: 0.30}
  mandatory_sensitivities:
    - {id: restwert_null, path: residual_value.method, value: zero, label: "Restwert = 0"}
    - {id: habenzins_liquiditaet, path: accounts.deposit_rate_pa, value: 0.02, label: "Habenzins 2,0 % (reine Liquiditätsanlage)"}
    - {id: habenzins_kalkulationszins, path: accounts.deposit_rate_pa, value: 0.035, label: "Habenzins = Kalkulationszins 3,5 %"}
    - {id: habenzins_fk, path: accounts.deposit_rate_pa, value: {ref: market.mortgage_rate}, label: "Habenzins = vermiedener FK-Zins"}
    - {id: stufe_2045, path: project.pending_reforms, add: stufe_2045, label: "mit 2045-Stufe (100 % klimaneutraler Brennstoff ab 2045)"}
by_project_type:
  heizungstausch:             {residual_value: {method: component}}
  sanierung_einzelmassnahmen: {residual_value: {method: component}}
```

### 2.6 `inst/extdata/profiles/kleinvermieter.yaml`

```yaml
defaults_meta: {kind: profile, id: kleinvermieter, schema_version: 1, as_of: 2026-10-26, quality: D,
                source: "Konzept A2, A3, A4, B4, F18; Spec 01 Teil A §2.6"}
project:
  report_mode: auto                # -> household (Cashflow-Sicht)
accounts:
  deposit_rate_pa: {ref: market.mortgage_rate, anchor: 0.025, floor: 0}   # Fest-/Tagesgeld (F18); Untergrenze 0 (F-14)
  overdraft_rate_pa: {ref: market.mortgage_rate, anchor: 0.060}      # Zwischenfinanzierung (A2)
  overdraft_limit_eur: 0                                             # darüber Nachschuss (A2)
  penalty_spread_pa: 0.02
  min_liquidity_eur: 0
  deposit_withholding_tax_share: 0                                   # B4: aus; Pflichtsensitivität
  deposit_tax_allowance_eur_pa: 0
  overdraft_flag_threshold_eur: .inf
  surplus_order: [od_repay, dep_fill_reserve, dep_invest]
  deficit_order: [dep_withdraw, od_draw, dep_use_reserve, equity_call]
  prepay: {buffer_eur: 0, min_spread_pa: 0}
residual_value:
  method: income_value
  sale_cost_share: 0.03
tax:
  module: none                     # Steuerwarnhinweis privat_vermieter (Konzept 3.12)
analysis:
  kpis: [terminal_value, terminal_value_opp, delta_terminal_value, roe_mirr, roe_irr, payback_time, payback_year,
         min_net_liquidity, max_overdraft, max_financing_need, sum_equity_calls, pv_equity_calls,
         flag_shortfall, flag_limit_breach, flag_reserve_used, withdrawal_equivalent, npv_cf_project,
         irr_cf_project, terminal_value_real,
         dscr_min, dscr_min_new, ltv_max, lending_ratio_max,
         monthly_net_cashflow, monthly_net_cashflow_y1, monthly_net_cashflow_min,
         own_contribution, pv_subsidies, co2_emissions,
         restriction_liquidity, restriction_savings]
  thresholds: {dscr: 1.2, burden_share: 0.40, warm_rent_increase_eur_m2: 0.50, roe_hurdle: 0.025}
  restrictions: [liquidity, savings]
  tenant_view: false
  rv_path_basis: auto              # -> measures (Haushaltsmodus)
  lending_value_haircut: 0.10
  traffic_light: {green_prob: 0.70, red_prob: 0.40, restriction_prob: 0.30}
  mandatory_sensitivities:
    - {id: restwert_null, path: residual_value.method, value: zero, label: "Restwert = 0"}
    - {id: habenzins_abgeltung, path: accounts.deposit_withholding_tax_share, value: 0.26375, label: "Habenzins nach Abgeltungsteuer (25 % + Soli)"}
    - {id: stufe_2045, path: project.pending_reforms, add: stufe_2045, label: "mit 2045-Stufe (100 % klimaneutraler Brennstoff ab 2045)"}
by_project_type:
  heizungstausch:             {residual_value: {method: component}}
  sanierung_einzelmassnahmen: {residual_value: {method: component}}
```

### 2.7 `inst/extdata/profiles/selbstnutzer.yaml`

```yaml
defaults_meta: {kind: profile, id: selbstnutzer, schema_version: 1, as_of: 2026-10-26, quality: D,
                source: "Konzept A2, A3, A4, B4, F18; Spec 01 Teil A §2.7"}
project:
  report_mode: auto                # -> household
accounts:
  deposit_rate_pa: {ref: market.mortgage_rate, anchor: 0.025, floor: 0}   # Untergrenze 0 (F-14)
  overdraft_rate_pa: {ref: market.mortgage_rate, anchor: 0.060}
  overdraft_limit_eur: 0
  penalty_spread_pa: 0.02
  min_liquidity_eur: 0
  deposit_withholding_tax_share: 0                                   # B4: aus; Pflichtsensitivität
  deposit_tax_allowance_eur_pa: 0
  overdraft_flag_threshold_eur: .inf
  surplus_order: [od_repay, dep_fill_reserve, dep_invest]
  deficit_order: [dep_withdraw, od_draw, dep_use_reserve, equity_call]
  prepay: {buffer_eur: 0, min_spread_pa: 0}
residual_value:
  method: component                # A3: Bestand mit Einzelmaßnahmen -> Komponenten-Zeitwert (Memo 07 S4)
  sale_cost_share: 0.03
tax:
  module: none                     # tax_flat gesperrt (Spec 00 §10.2)
analysis:
  kpis: [terminal_value, terminal_value_opp, delta_terminal_value, roe_mirr, payback_time, payback_year,
         min_net_liquidity, max_overdraft, max_financing_need, sum_equity_calls, pv_equity_calls,
         flag_shortfall, flag_limit_breach, flag_reserve_used, withdrawal_equivalent, terminal_value_real,
         monthly_burden, monthly_burden_y1, monthly_burden_avg10, monthly_burden_construction, burden_ratio_max,
         own_contribution, pv_subsidies, co2_emissions,
         restriction_burden, restriction_savings, restriction_liquidity]
  thresholds: {dscr: 1.2, burden_share: 0.40, warm_rent_increase_eur_m2: 0.50, roe_hurdle: 0.025}
  restrictions: [burden, savings, liquidity]
  tenant_view: false
  rv_path_basis: auto              # -> measures
  lending_value_haircut: 0.10
  traffic_light: {green_prob: 0.70, red_prob: 0.40, restriction_prob: 0.30}
  mandatory_sensitivities:
    - {id: restwert_null, path: residual_value.method, value: zero, label: "Restwert = 0"}
    - {id: habenzins_abgeltung, path: accounts.deposit_withholding_tax_share, value: 0.26375, label: "Habenzins nach Abgeltungsteuer (25 % + Soli)"}
    - {id: stufe_2045, path: project.pending_reforms, add: stufe_2045, label: "mit 2045-Stufe (100 % klimaneutraler Brennstoff ab 2045)"}
by_project_type:
  neubau:           {residual_value: {method: asset_value}}       # A3: Sachwert beim Selbstnutzer-EFH (Memo 07 S5)
  erwerb_neubau:    {residual_value: {method: asset_value}}
  erwerb_sanierung: {residual_value: {method: market_growth}}     # Kaufpreis bzw. Bestandswert fortgeschrieben
```

### 2.8 Übersicht der Profilwerte und Herkunft

| Pfad | wu_kommunal | wu_genossenschaft | wu_privat | kleinvermieter | selbstnutzer | Quelle |
|---|---|---|---|---|---|---|
| `accounts.deposit_rate_pa` (Basisfall) | 0,035 | 0,020 | 0,035 | 0,025 | 0,025 | A2, F18 |
| Untergrenze des Habenzinses (`floor`) | 0 | 0 | 0 | 0 | 0 | F-14, Memo 04 §1.2 |
| `accounts.overdraft_rate_pa` | 0,055 | 0,055 | 0,055 | 0,060 | 0,060 | A2 |
| `accounts.overdraft_limit_eur` | ∞ | ∞ | ∞ | 0 | 0 | A2, R-57 (WU: `restriction_liquidity` ohne Projektangabe nicht prüfbar, R-101) |
| `accounts.penalty_spread_pa` | 0,02 | 0,02 | 0,02 | 0,02 | 0,02 | A2 |
| D4-Aktion (`deficit_order`) | `penalty_rate` | `penalty_rate` | `penalty_rate` | `equity_call` | `equity_call` | D4, R-20 |
| `residual_value.method` | income_value (Einzelmaßn./Heizung: component) | dto. | dto. | dto. | component (Neubau: asset_value; Erwerb+Sanierung: market_growth) | A3 |
| `residual_value.sale_cost_share` | 0,03 | 0,03 | 0,03 | 0,03 | 0,03 | A3 |
| `analysis.thresholds.roe_hurdle` | 0,035 | 0,020 | 0,035 | 0,025 | 0,025 | A4, F18 |
| `analysis.thresholds.dscr` | 1,2 | 1,2 | 1,2 | 1,2 | (–) | A4 |
| `analysis.restrictions` | dscr, liquidity, warm_rent | dto. | dto. | liquidity, savings | burden, savings, liquidity | 1.4 |
| `analysis.tenant_view` | true | true | true | false | false | Spec 00 §4.3.14 |
| `project.horizon_years` | 30 (Neubau 40) | dto. | dto. | dto. | dto. | A3 (global) |

**Hinweis zur Kopplung `anchor`.** Im deterministischen Lauf liefert `{ref: market.mortgage_rate, anchor: h}` exakt
den konstanten Wert h (Spalte t ≥ 0: h + (x_t − x_0) = h, weil der Basisfall `mortgage_rate` konstant ist; bei einem
deterministischen Zinspfad folgt h dessen Veränderung). Im MC folgt der Habenzins dem Zinspfad mit festem Abstand, der
Startwert bleibt h (Konzept F18, Spec 00 §4.5). Mit `floor: 0` wird ein negativer Habenzins auf 0 begrenzt (Formel der
Bezugsform: `pmin(pmax(h + (x_t − x_0), floor), cap)`; F-14). Die Pflichtsensitivitäten mit `value` ersetzen die
Kopplung durch den angegebenen Wert (Konstante bzw. bei `habenzins_fk` den Zinspfad selbst, 1.5).

### 2.9 Tests (WS-A, `test-scenario-layers.R`, `test-profiles.R`)

| Nr. | Fall | Erwartung |
|---|---|---|
| PR1 | `selbstnutzer`, `neubau`, ohne `residual_value` | `residual_value.method = "asset_value"`, Herkunft `profile`, `entry = "selbstnutzer#by_project_type.neubau"`; `horizon_years = 40` (`global#by_project_type.neubau`) |
| PR2 | `wu_kommunal`, `heizungstausch` | `method = "component"`; `accounts.deficit_order[4] = "penalty_rate"`; `accounts.overdraft_limit_eur = Inf` |
| PR3 | `kleinvermieter`, Szenario setzt `analysis.kpis: default` | Liste aus 2.6 (31 Einträge); `warm_rent` nicht enthalten |
| PR4 | Profil mit `market.inflation: 0.02` (Testprofil in `fixtures/library`) | E `validation.profile_path_forbidden` (R-76) |
| PR5 | `wu_genossenschaft`, deterministischer Lauf, `market.mortgage_rate: 0.041` | `ctx$value("accounts.deposit_rate_pa", "path")` ist überall 0.020; mit `market.mortgage_rate: {series: {2027: 0.041, 2030: 0.051}, fill: locf}` ist der Wert 0.020 bis 2029 und 0.030 ab 2030; mit `{series: {2027: 0.041, 2030: 0.010}, fill: locf}` 0.020 bis 2029 und 0 ab 2030 (Untergrenze; ohne `floor` −0,011) |
| PR6 | Jede der fünf Dateien | lädt ohne Befund; alle Pfade nach R-76 zulässig; `defaults_meta.kind == "profile"`; `deficit_order` erfüllt die Kettenregeln (Spec 00 §8.9) |
| PR7 | `global.yaml` | jede Sequenz und Map aus 2.2 vorhanden; `stochastic.settings.preset = "standard"`, `block_size = 200`, kein `n_sim`, kein `replicates` (Spec 00 §4.3.15, R-97); **jeder** `from`/`use`-Verweis in `global.yaml` (einschließlich `item_defaults`) und in den Profilen löst gegen die Paketbibliothek auf (Spec 00 §4.9, R-104; u. a. `costs/bewirtschaftung_ii_bv_2026`, N-02); `item_defaults` nur mit Pfaden nach Spec 00 §4.7 Nr. 3; keine Blöcke `building`, `household`, `energy` außerhalb von `item_defaults` (N-05); `market.energy_price` enthält alle 10 kanonischen Träger (N-15) |
| PR8 | Gerüst Spec 00 Anhang A (`wu_privat`, `neubau`, ohne `building`) | aufgelöste Variante ohne Block `building`, keine Komponente `m_maintenance` (N-05, P0-09); Herkunft aller `project.*`-Defaults `global` bzw. `rule:<name>` |
| PR9 | `sanierung_eh` mit `building: {living_area_m2: 1000, construction_year: 1972}` ohne `maintenance` | `building.building_id = "b1"` (Herkunft `global`, `entry = "global#item_defaults.building"`); `building.maintenance.basis = "rate"` (`entry = "rule:maintenance_from"`); `building.maintenance.rate_eur_m2_pa = 14.4` (`entry = "costs/bewirtschaftung_immowertv_2026"`); I `validation.maintenance.default_rate` |
| PR10 | Maßnahme `wp: {measure_type: heizung_waermepumpe_luft, year: 2028, cost_eur: 30000}` ohne weitere Felder; Overlay `stochastic.parameters.d: {target: measures.wp.delay_months, label: "Verzug WP", dist: discrete, values: [0, 12], probs: [0.5, 0.5]}` | `measures.wp.cost_factor = {ref: project.construction_cost_factor}`, `measures.wp.delay_months = 0`, `measures.wp.replacement.price_index = {ref: measures.wp.price_index}` (Herkunft `global#item_defaults.measures`, Platzhalter `{id}` ersetzt); das Overlay-Ziel existiert (kein Fehler) |

---

## 3. Gebäude, Bestandsbauteile, Wohnungsgruppen, Flächen und Mengenbezug

### 3.1 `building`

`building` darf fehlen, wenn nur `components`/`financing` angegeben sind (Orakel, Lehrbuch; Spec 00 §4.2). Dann laufen
die Expander `measures` (ohne Instandhaltung), `unit_groups` und `residual` nicht bzw. ohne Gebäudebezug (4.5, 6.2). Die
Defaults des Blocks (Spalte „(G)“) stehen in `item_defaults.building` (2.2) und entstehen nur, wenn das Szenario
`building` enthält (N-05); Gebäude-Ableitungsregeln (1.4) laufen ebenfalls nur dann.
Felder der Energie-, Förder- und Mietrechtslogik sind mit „Teil B“ markiert; ihre Semantik regelt Teil B, hier stehen
Typ und Ort.

| YAML-Pfad | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo-Ref |
|---|---|---|---|---|---|---|---|
| `building.building_id` | chr | – | `"b1"` (G, `item_defaults.building`) | nein | E: id-Muster, ≤ 20 Zeichen | Gebäudekennung; Präfix der Asset-ids (4.5.4) | R-50 |
| `building.label` | chr | – | `NULL` | nein | – | Anzeigename | – |
| `building.building_type` | enum:`EFH`,`ZFH`,`DHH`,`RH`,`MFH`,`ETW` | – | `NULL` | nein | W: fehlt bei Perspektive `wu_*` oder bei Ertragswert | Gebäudetyp (Kostenfunktionen, GND, Förderung) | Memo 02 §9.2 |
| `building.construction_year` | int | Jahr | `NULL` | bedingt | E: Pflicht bei Bestandsprojekten, bei `residual_value.method ∈ {income_value, asset_value}` mit `remaining_life_method ≠ manual` und bei `maintenance.basis: iibv` außerhalb von Neubauprojekten (im Neubau gilt die Bezugsfertigkeit aus der Fertigstellung, `rule:first_occupancy`); E: ≤ Jahr(`valuation_date`) + 5 | Baujahr | Memo 02 §7.1 |
| `building.first_occupancy_year` | int | Jahr | A (`rule:first_occupancy`): `construction_year`; Neubauprojekt: Jahr(`grid$completion_date` − 1 Tag) | nein | E: ≥ `construction_year` | Bezugsfertigkeit (II. BV § 28 Altersklassen) | Memo 03 §8.1 |
| `building.fictitious_construction_year` | int | Jahr | `NULL` | nein | E: ≥ `construction_year`; W: > Jahr(`valuation_date`) | fiktives Baujahr nach Kernsanierung; ersetzt `construction_year` für die Restnutzungsdauer (6.3.3) | ImmoWertV Anl. 2, Memo 02 §7.1 |
| `building.n_units` | int | WE | A (`rule:building_aggregates`): Σ `unit_groups.<g>.n_units` | bedingt | E: ≥ 1; E: Pflicht bei `wu_*` ohne `unit_groups`; W: ≠ Summe der Wohnungsgruppen (Teil B §1.2) | Wohneinheiten (Bezugsgröße `unit`) | Memo 07 §3.2 |
| `building.living_area_m2` | num | m² | A (`rule:building_aggregates`): Σ `unit_groups.<g>.living_area_m2` | bedingt | E: > 0; W: Abweichung zur Summe der Gruppen > 1 % (Teil B §1.2) | Wohnfläche (WoFlV); Bezugsgröße `m2_living_area` | Memo 07 §3.2 |
| `building.net_floor_area_m2` | num | m² | `NULL` | bedingt | E: Pflicht, sobald `per: m2_net_floor_area` verwendet wird; W: Verhältnis zur Wohnfläche ∉ [1,1; 1,5] | Gebäudenutzfläche A_N (IWU-Kostenfunktionen, Energieausweis) | Memo 03 §6.2, Memo 07 §3.2 |
| `building.n_parking` | int | Stück | `0` (G) | nein | E: ≥ 0 | Stellplätze (Bezugsgröße `parking`) | Memo 02 §9.2 |
| `building.component_areas_m2.<b>` | num | m² | `NULL` | bedingt | E: ≥ 0; `<b>` ∈ Bauteilcodes (3.1.1); E: Pflicht bei `per: m2_component:<b>` ohne Maßnahmenfläche | Bauteilflächen | Memo 07 §6.1 |
| `building.land_area_m2` | num | m² | `NULL` | nein | E: > 0 | Grundstücksfläche | Memo 07 S1 |
| `building.land_value_eur_m2` | value | EUR/m² | `NULL` | nein | E: ≥ 0 | Bodenrichtwert zum Stichtag | Memo 07 S1 |
| `building.land_value_eur` | value | EUR | A (`rule:building_aggregates`): `{expr: "building.land_area_m2 * building.land_value_eur_m2"}`, wenn beide gesetzt | bedingt | E: Pflicht bei Restwert `income_value` und `asset_value`; W: > `market_value_eur` | Bodenwert zum Stichtag (Bezug des Restwerts) | Memo 02 §7.1 |
| `building.market_value_eur` | value | EUR | A (`rule:building_aggregates`): `{ref: building.existing_value_eur}`, wenn dieses gesetzt ist | nein | E: ≥ 0 | Marktwert des Objekts zum Stichtag (Basis `market_growth`, LTV-Plausibilität) | Spec 00 §4.3.4 |
| `building.existing_value_eur` | value | EUR | `NULL` | nein | E: ≥ 0; I: fehlt bei Bestandsprojekt („absolute EK-Rendite NA“); I: gesetzt bei `neubau` (Grundstück als Sacheinlage); E: gesetzt bei `erwerb_*` (Kaufpreis ist Investition); E: in Varianten geändert (4.9) | **Bestandswert** (Verkehrswert vor der Maßnahme, Opportunität „heute verkaufen“): erzeugt die Engine-Merkzeile `equity_in_kind` = Bestandswert − Σ Restschulden der Bestandsdarlehen in t = 0 und den Verkauf in der Unterlassungsalternative | Konzept 2.6, A9, Spec 00 §7.7, R-68 |
| `building.modernization_points_before.<el>` | int | Punkte | `0` je Element | nein | E: 0 ≤ p ≤ Höchstpunkte des Elements (Tabelle 6.3.3) | Modernisierungspunkte des Bestands vor den Maßnahmen (ImmoWertV Anl. 2) | Memo 02 §7.1 |
| `building.commercial_share` | share | 1 | `0` (G) | nein | W bei > 0 („Vorsteuerthematik nicht abgebildet“, Spec 00 §7.10) | Gewerbeanteil an der Fläche | Konzept 3.12 |
| `building.elements.<e>` | map | – | `{}` | nein | 3.2 | Bestandsbauteile mit Ersatzzyklus | Memo 02 §1.5 |
| `building.maintenance` | map | – | G (`item_defaults.building.maintenance`, 2.2) | nein | 3.3 | Instandhaltung (Typ `maintenance`) | Konzept 3.6 |
| `building.energy_class_before`, `…_after`, `building.efficiency_standard_after`, `building.wpb_flag`, `building.denkmal`, `building.serial_renovation`, `building.isfp_available`, `building.heating_existing`, `building.consumption_kwh` | nach Teil B | – | Teil B | Teil B | Teil B | Energie- und Förderattribute | Spec 00 §4.3.4 |

#### 3.1.1 Bauteilcodes (`component_areas_m2`, `m2_component:<b>`)

`roof` (Dach gesamt), `pitched_roof`, `flat_roof`, `top_ceiling` (oberste Geschossdecke), `facade` (Außenwand opak),
`windows` (Fensterfläche), `doors` (Außentüren), `basement_ceiling` (Kellerdecke), `floor_slab` (Bodenplatte),
`partition_unheated` (Wände gegen unbeheizt). Neue Codes nur über das Vokabular `enums.yaml`
(`component_area: {codes: […]}`, Integrator, S01A-09).

### 3.2 `building.elements.<e>` – Bestandsbauteile

Bestandsbauteile sind vorhandene Komponenten, deren Ersatz im Horizont fällig wird (Memo 07 S1 V1: Fassade 2042,
Kessel 2047; S4: Kesselausfall). Der Maßnahmen-Expander erzeugt je Bauteil eine Komponente `m_<e>_repl` vom Typ
`replacement` (4.10) und einen Eintrag im Maßnahmenregister (`measure_id = <e>`, Klassifikation `erhaltung`). Die
Erstinvestition des Bestandsbauteils ist Teil des Bestands (keine Zahlung, kein Komponenten-Zeitwert); Zeitwerte
entstehen nur für Ersatzinvestitionen im Horizont. ids von Bauteilen und Maßnahmen sind gemeinsam eindeutig und
höchstens 29 Zeichen lang (4.5.2 Nr. 1, N-23). Spalte „(G)“ = `item_defaults."building.elements"` (2.2); Katalogwerte
und `price_base_year` setzt `rule:measure_catalog` (4.5.1).

| YAML-Pfad | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo-Ref |
|---|---|---|---|---|---|---|---|
| `…<e>.label` | chr | – | `<e>` | nein | – | Anzeigename | – |
| `…<e>.measure_type` | enum:measure_types | – | – | ja | E: Code des Katalogs (4.2) | Art des Bauteils; liefert Katalogdefaults (Nutzungsdauer, KG, Asset-Typ) | Memo 06 §7.5 |
| `…<e>.installed_year` | int | Jahr | – | bedingt | E: Pflicht ohne `next_replacement`; E: ≤ Jahr(`valuation_date`) | Einbaujahr; Ursprung des Zyklus = (Y)-01-01 | Memo 02 §9.4 |
| `…<e>.useful_life_years` | number | a | A (`rule:measure_catalog`): Katalog → B:`costs/nutzungsdauern_2026` | nein | E: > 0; W: < 5 oder > 80 | Nutzungsdauer (stochastisch zulässig, Spec 00 §3.9) | Konzept 3.4, F19 |
| `…<e>.replacement_cost_eur` | value | EUR | – | ja | E: ≥ 0 (`validation.building.element_cost_missing`, wenn fehlend); Mengenbezug zulässig (3.5) | Kosten je Ersatz in Preisen von `price_base_year` (brutto) | Memo 02 §1.5 |
| `…<e>.price_base_year` | int | Jahr | `project.price_base_year` (A, `rule:measure_catalog`) | nein | wie 1.2 | Preisstand der Ersatzkosten | R-35 |
| `…<e>.price_index` | value | 1/a | `{ref: market.construction_price_index}` (G) | nein | – | Preisindexrate | Memo 02 §1.5 |
| `…<e>.vat_rate` | share | 1 | A: Katalog (meist 0.19) | nein | E: ∈ {0, 0.07, 0.19} (W sonst) | enthaltener USt-Satz | D6 |
| `…<e>.next_replacement` | timing | – | `NULL` | nein | E: ≥ `valuation_date`; W: nach `end_date` | Termin des **ersten** Ersatzes (überschreibt Einbau + Nutzungsdauer) | Memo 07 S4 |
| `…<e>.next_replacement_delay_months` | number | Monate | `0` (G) | nein | E: ≥ 0 (R-105) | laufspezifische Verschiebung des ersten Ersatzes (z. B. Ausfalljahr als diskrete Verteilung in Monaten ab einem früheren Basistermin) | Spec 00 §3.9, Memo 07 S1 V0 |
| `…<e>.overdue` | enum:`first_period`,`valuation`,`skip` | – | `first_period` (G) | nein | W, wenn der erste Ersatztermin ≤ `valuation_date` liegt | Behandlung überfälliger Bauteile: Ersatz am Ende von Periode 1, in t = 0 oder entfallen lassen | – |
| `…<e>.active` | value 0/1 | – | `1` (G) | nein | E: ∈ [0, 1] | Ersatzzyklus findet statt (0 = Bauteil entfällt in dieser Variante) | R-71 |
| `…<e>.kg`, `…<e>.asset_type` | int, enum | – | A: Katalog | nein | wie 4.1 | DIN-276-KG, Asset-Typ | – |

Ein Bauteil, das in einer Variante durch eine Maßnahme ersetzt wird, steht in `measures.<m>.replaces_elements`
(4.1); sein Zyklus endet dann mit der (laufspezifisch verschobenen) Fertigstellung der Maßnahme.

### 3.3 `building.maintenance` – Instandhaltung (Domänenblock zum Typ `maintenance`)

Alle (G)-Werte stehen in `item_defaults.building.maintenance` (2.2) und entstehen nur in Szenarien mit `building`;
`basis` und `from` setzt `rule:maintenance_from` (1.4) vor der Vorlage.

| YAML-Pfad | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo-Ref |
|---|---|---|---|---|---|---|---|
| `building.maintenance.enabled` | lgl | – | `true` (G) | nein | – | Instandhaltungskomponente `m_maintenance` erzeugen | Konzept 3.6 |
| `building.maintenance.basis` | enum:`auto`,`rate`,`iibv`,`none` | – | A (`rule:maintenance_from`, fehlend = `auto`): `rate`, wenn `rate_eur_m2_pa` im Szenario, in der Variante, im Set oder als Override gesetzt ist; sonst Neubauprojekt (`neubau`, `erwerb_neubau`) → `iibv`, sonst `rate` (F-22) | nein | I `validation.maintenance.default_rate`, wenn Satz bzw. Sätze nur aus den Defaults stammen (4.11.4) | `rate`: Satz × Fläche (ImmoWertV-Default 14,40 €/m²); `iibv`: Altersklassen der II. BV ab Bezugsfertigkeit (Neubau: 11,50 €/m² in den ersten 21 Jahren statt der vollen Bestandspauschale); `none`: keine Pauschale | Konzept 3.6, Memo 03 §8, II. BV § 28 |
| `building.maintenance.rate_eur_m2_pa` | value | EUR/m²·a | `14.40` (G über B:`costs/bewirtschaftung_immowertv_2026`, `use: maintenance_eur_m2_pa`) | nein | E: ≥ 0; Pfad zulässig (z. B. `series_year` 10,00 bis 2042, ab 2043 14,40, Memo 07 S1 V2) | Instandhaltungssatz in Preisen von `price_base_year`; Overlay-Ziel `maintenance_level` (Teil C §1.9, `apply: multiply`) | Memo 03 §8.2 |
| `building.maintenance.area_m2` | value | m² | `{ref: building.living_area_m2}` (G) | nein | E: > 0 | Bezugsfläche | – |
| `building.maintenance.price_base_year` | int | Jahr | `2026` (G) | nein | wie 1.2 | Preisstand des Jahresbetrags (Wert gilt für das Jahr 2026; Kalenderjahresindex, 4.11.2) | R-35, R-62 |
| `building.maintenance.growth` | value | 1/a | `{ref: market.maintenance_index}` (G) | nein | – | Fortschreibung (Kalenderjahresindex) | Memo 03 §5.2 |
| `building.maintenance.from`, `.to` | timing \| `auto` | – | `from`: A (`rule:maintenance_from`, fehlend = `auto`): Neubauprojekt → Token `completion`, Erwerb → Erwerbsdatum, sonst `valuation_date`; `to`: `NULL` (G) = `end_date` | nein | E: from < to | Wirkungszeitraum | Spec 00 §3.9 |
| `building.maintenance.vat_rate` | share | 1 | `0.19` (G) | nein | – | enthaltener USt-Satz (Ausweis netto/USt) | D6 |
| `building.maintenance.excludes_explicit_replacements` | lgl | – | `false` (G) | nein | W `validation.maintenance.double_count`, wenn `false`, Pauschale > 0 und im Horizont Ersatzereignisse oder Erhaltungsmaßnahmen liegen; I `validation.maintenance.replacements_excluded` mit Kennwert der expliziten Erneuerungen bei `true` (4.11.4, F-21) | Erklärung, dass der Satz die explizit modellierten Ersatz- und Instandsetzungsmaßnahmen nicht enthält (Satz entsprechend gemindert) | Konzept 3.4 |
| `building.maintenance.iibv.rates_eur_m2_pa.{lt22y,ge22y,ge32y}` | value | EUR/m²·a | `11.50`, `14.58`, `18.62` (G über B:`costs/bewirtschaftung_ii_bv_2026`, `use: maintenance_eur_m2_pa`, N-02) | nein | E: ≥ 0 | Sätze nach Bezugsfertigkeit < 22, ≥ 22, ≥ 32 Jahre | Memo 03 §8.1 |
| `building.maintenance.iibv.adjust_eur_m2_pa` | value | EUR/m²·a | `0` (G) | nein | – | Zu-/Abschläge (Aufzug +1,63; Kleinreparaturen durch Mieter −1,70; Wärmelieferung −0,31; Werte in `costs/bewirtschaftung_ii_bv_2026`, `maintenance_adjustments_eur_m2_pa`) | II. BV § 28 |
| `building.maintenance.iibv.price_base_year` | int | Jahr | `2026` (G) | nein | – | Preisstand der Sätze | – |
| `building.maintenance.iibv.reset_by_measures` | ids \| `auto` | – | `auto` (G) = Maßnahmen mit `effects.maintenance.reset_age: true` | nein | E: Maßnahmen-ids | Maßnahmen, deren Fertigstellung das Alter zurücksetzt (Vollsanierung: „Reset auf Neubauniveau“) | Memo 03 §8.3 |

Für Selbstnutzer gilt derselbe Block; die Zeile trägt dort `tax_category = expense_nondeductible` (4.11.3).
Bauteilbezogene **Instandsetzung** (VDI 2067, % der Investition, ohne Wartung) wird je Maßnahme über
`measures.<m>.effects.maintenance.share_of_cost_pa` angegeben (4.4, 4.11). Wartung, Schornsteinfeger und
Betriebsführung der Anlagen gehören zum Energiezustand (Teil B §3.2.2, `service_eur_pa`) bzw. zum PV-Betrieb
(`energy.pv.opex_share_of_cost`) und stehen weder hier noch in `share_of_cost_pa` (X-10, 4.11.4).

### 3.4 `unit_groups` – Abgrenzung und Schnittstelle

Block `unit_groups.<g>` (Grunddaten, Mietregime, Erlösrisiken, `operating`, `rent_law`) und Expander `unit_groups`
(`u_<g>_rent`, `u_<g>_opex`, `u_<g>_property_tax`, `u_<g>_imputed_rent`, implizite Gruppe `main` beim Selbstnutzer)
regelt **Teil B** (§§ 1.2, 1.6, 2.2, 3.10) einschließlich der Validierungen (Abweichungen Σ Gruppen gegenüber
`building` als W). Teil A steuert bei:

1. **Aggregation (Ableitungsregel `rule:building_aggregates`, 1.4):** Fehlen `building.n_units` bzw.
   `building.living_area_m2`, setzt WS-A sie als `expr`-Knoten auf die Summe über die Gruppen
   (`{expr: "unit_groups.a.n_units + unit_groups.b.n_units"}`), damit Overlay und Varianten auf Gruppenflächen
   durchgreifen (Bezug statt Kopie). Ohne Gruppen und ohne Gebäudewert bleibt das Feld leer (Mengenbezüge darauf: E,
   3.5).
2. **Mengenbezug** `unit` und `m2_living_area` an einer Gruppe (3.5).
3. **Schnittstelle Maßnahmen → Mietpfad:** Die Kostenzeilen von `m_<m>_capex` (Kategorie `capex`, `measure_id = m`)
   sind bereits mit dem Aktivierungsfaktor a_m multipliziert (4.6.3); die Hilfsmatrix `aux$in_operation` (4.6.4)
   liefert den Wirkungsbeginn je Lauf einschließlich a_m und Verzug. `rent_path` liest beides über
   `ctx$component("m_<m>_capex")` (Teil B §1.6 Nr. 5, §1.9.1); der Expander `unit_groups` führt die Komponente in `after`.

**Test (WS-A, `test-scenario-layers.R`).** UG1: Gruppen `a: {n_units: 12, living_area_m2: 600}`,
`b: {n_units: 18, living_area_m2: 1170}`, `c: {n_units: 6, living_area_m2: 630}` (Memo 07 S2) ohne Gebäudewerte →
`building.n_units = 36`, `building.living_area_m2 = 2400` (Herkunft `rule:building_aggregates`); Schicht 8
`unit_groups.a.living_area_m2: 660` → `building.living_area_m2 = 2460`.

### 3.5 Mengenbezug (Wertform `quantity`)

Die Wertform `{value: x, per: <bezug>}` (Spec 00 §4.5, R-91; Antrag S01A-03 entschieden) ergibt `x × Bezugsgröße`. `x` darf jede skalare oder
zeitabhängige Wertform sein; die Bezugsgröße ist deterministisch. **Bezugsobjekt** ist das nächste Domänenobjekt, in
dem der Knoten steht (Bauteil `building.elements.<e>`, Maßnahme `measures.<m>`, Wohnungsgruppe `unit_groups.<g>`),
bei Komponentenparametern die Komponente; danach `building`. Aufgelöst wird in `values-resolve.R` (WS-D,
`res_quantity()`); WS-A prüft beim Normalisieren die Existenz der Bezugsgröße.

| `per` | Bezugsgröße am Bezugsobjekt (Feld) | Rückfall `building` | Einheit von x |
|---|---|---|---|
| `total` | 1 | – | EUR |
| `unit` | `n_units` | `building.n_units` | EUR/WE |
| `m2_living_area` | `living_area_m2` | `building.living_area_m2` | EUR/m² |
| `m2_net_floor_area` | `net_floor_area_m2` | `building.net_floor_area_m2` | EUR/m² A_N (R-91) |
| `m2_component:<b>` | `component_areas_m2.<b>` | `building.component_areas_m2.<b>` | EUR/m² Bauteilfläche |
| `parking` | `n_parking` | `building.n_parking` | EUR/Stellplatz (R-91) |
| `kw` | `kw` | – (E) | EUR/kW |
| `kwp` | `kwp` (PV-Maßnahme `energy.pv.measure`: A `{ref: energy.pv.kwp}`, 4.5.1 Nr. 5) | – (E) | EUR/kWp |
| `kwh` | `kwh` | – (E) | EUR/kWh |

Die Abbildung `per` → Feld ist die von Spec 00 §4.5 (R-91): `kw`, `kwp`, `kwh` lesen das gleichnamige Feld des
Bezugsobjekts (an Maßnahmen `measures.<m>.kw`, `.kwp`, `.kwh`, 4.1); `building` führt diese Felder nicht. Fehlt die
Bezugsgröße an beiden Stellen: E `validation.quantity.reference_missing` (Pfad, `per`). Ein Mengenbezug in
einer Wertform, die eine Komponente per `{ref: …}` liest, wird mit dem Bezugsobjekt **des Ziels** aufgelöst (nicht
dem der lesenden Komponente). Maßnahmen dürfen eigene Teilflächen führen (`measures.<m>.component_areas_m2.<b>`,
z. B. nur die Straßenfassade).

**Tests (WS-D `test-values-resolve.R`, WS-A `test-values-normalize.R`).**

| Nr. | Knoten (Ort) | Daten | Erwartung |
|---|---|---|---|
| Q1 | `building.maintenance.rate_eur_m2_pa` als `{value: 14.40, per: m2_living_area}` | `building.living_area_m2: 1600` | 23.040,00 |
| Q2 | `{value: 367, per: unit}` in einem Feld der Gruppe `unit_groups.std` (Teil-B-Feld) | Gruppe `n_units: 24` | 8.808,00 |
| Q3 | `measures.wdvs.cost_eur: {value: 248, per: m2_component:facade}` | Maßnahme `component_areas_m2.facade: 600`, Gebäude `facade: 1500` | 148.800,00 (Maßnahmenfläche gewinnt) |
| Q4 | wie Q3 ohne Maßnahmenfläche | Gebäude `facade: 1500` | 372.000,00 |
| Q5 | `{value: 1800, per: kw}` in einer Maßnahme ohne `kw` | – | E `validation.quantity.reference_missing` |
| Q6 | `{value: {series: {2027: 10, 2043: 14.4}, fill: locf}, per: m2_living_area}` | 1.600 m² | Pfad: 16.000 bis 2042, 23.040 ab 2043 |
| Q7 | `measures.pv.cost_eur: {value: 1400, per: kwp}` ohne `measures.pv.kwp` | `energy.pv: {kwp: 30, measure: pv}` | `measures.pv.kwp = {ref: energy.pv.kwp}` (Herkunft `rule:measure_catalog`); 42.000,00 |

---

## 4. Maßnahmen und Investition

### 4.1 `measures.<m>` – Feldkatalog

Eine Maßnahme ist eine Investition mit Kosten, Termin, Nutzungsdauer und Wirkungen: Neubau, energetische oder
Ohnehin-Maßnahme, Erwerb. Felder aus Spec 00 §4.3.6 sind übernommen und konkretisiert; maßgeblich für Schema und
Validierung ist diese Tabelle (Spec 00 §4.3 Kopf, R-106; Antrag S01A-07 entschieden). Fehlende Felder werden in zwei
Stufen vorbelegt: zuerst durch `rule:measure_catalog` (4.5.1; Katalog- und abgeleitete Werte, Herkunft `type_default`,
`entry` = Bibliotheks-id bzw. `rule:measure_catalog`; Spalte „A“ bzw. „Katalog“), danach durch die Vorlage
`item_defaults.measures` (2.2; Herkunft `global`; Spalte „(G)“). Dadurch existiert jeder Pfad im aufgelösten `vofi_spec`
und ist Overlay- und Designziel (Varianten: 2.1). Maßnahmen-ids haben höchstens 29 Zeichen (4.5.2 Nr. 1).

| YAML-Pfad | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo-Ref |
|---|---|---|---|---|---|---|---|
| `…<m>.label` | chr | – | `<m>` | nein | – | Anzeigename | – |
| `…<m>.measure_type` | enum:measure_types | – | – | ja | E: Code aus 4.2 | Maßnahmentyp (Katalogdefaults, Register) | Memo 06 §7.5 |
| `…<m>.description` | chr | – | `NULL` | nein | – | Freitext | – |
| `…<m>.date` | date | – | – | bedingt | E: **genau eines** von `date`, `year`, `payment_schedule` (Erwerb: `date` oder `year`); E: ≥ `valuation_date`; I: > `end_date` (Zahlung entfällt) | Zahlungs- bzw. Abschlusstermin (Ende der Ausführung) | Spec 00 §3.4, §4.3.6 |
| `…<m>.year` | int | Jahr | – | bedingt | wie `date` | Termin „zum 1. Januar Y“ (R-35) | Memo 07 §4.0 |
| `…<m>.payment_schedule` | schedule | EUR bzw. 1 | – | bedingt | E: `unit: share` → Σ Anteile = 1 (Toleranz 1e-9); `unit: eur` → Beträge ≥ 0, kein ausdrückliches `cost_eur`/`cost_kg`, Beträge als Zahl, `ref`, `expr` oder `quantity` (sonst E `validation.measures.schedule_amount_form`, 4.6.1); E: Termine ≥ `valuation_date` | Zahlungsplan (Mittelabfluss, A-06); bei `unit: eur` leitet `rule:cost_from_kg` `cost_eur` ab (X-28) | Spec 00 §4.5, Memo 07 S2 |
| `…<m>.duration_months` | int | Monate | `0` (G) | nein | E: ≥ 0; E: nur mit `date`/`year`; E: Beginn der Ausführung ≥ `valuation_date` | Ausführungsdauer vor `date` (ZPP, 0.3) | Memo 02 §1.3 |
| `…<m>.payment_profile` | enum:`linear`,`s_curve`,`front`,`back` | – | `linear` (G) | nein | I: wirkungslos bei `duration_months = 0` | Mittelabflussprofil (ZPP) | Konzept 3.2 |
| `…<m>.completion_date` | date | – | A (`rule:measure_catalog`): `date` bzw. Jahr-Datum; bei Zahlungsplan letzter Termin | nein | E: ≥ erster Zahlungstermin; W: > `end_date` (keine Wirkung im Horizont) | Fertigstellung; Beginn der Wirkungen und des Nutzungsdauerzyklus | Spec 00 §4.3.6 |
| `…<m>.follows_construction` | lgl | – | A (`rule:measure_catalog`): `true` für `neubau`, `erweiterung`, `aufstockung` und für Maßnahmen mit `completion_date == grid$completion_date` bei C > 0 | nein | W: `true` und `completion_date` ≠ Rasterfertigstellung (> 3 Monate) | Teil der Hauptbaumaßnahme (Rasterprüfung 1.3, Default von `construction_delay_mode`) | – |
| `…<m>.construction_delay_mode` | enum:`none`,`last`,`stretch` | – | A (`rule:measure_catalog`): `stretch`, wenn `follows_construction`, sonst `none` | nein | – | Wirkung von `project.construction_delay_months` auf die Zahlungen (4.6.2) | Konzept F16, Memo 04 Tab. 1 |
| `…<m>.delay_months` | number | Monate | `0` (G) | nein | E: ≥ 0 (Spec 00 §3.9, R-105) | laufspezifische Verschiebung aller Zahlungen, der Fertigstellung und der Wirkungen (stochastisch zulässig; ein je Lauf früherer Termin wird als früherer Basistermin mit Verschiebung ≥ 0 modelliert) | Spec 00 §3.9, R-60 |
| `…<m>.active` | value 0/1 | 1 | `1` (G) | nein | E: ∈ [0, 1]; W: Werte ∉ {0, 1} | „Maßnahme findet statt“ (Aktivierung, AF) | Spec 00 §4.12 Nr. 7, R-71 |
| `…<m>.cost_eur` | value (amount) | EUR | – | bedingt | E: genau eines von `cost_eur`, `cost_kg`, `payment_schedule` mit `unit: eur` (Erwerb: `purchase_price_eur`; ein abgeleitetes `cost_eur` mit Herkunft `rule:cost_from_kg` zählt nicht); E: Overlay-/Designziel auf ein abgeleitetes `cost_eur` (`validation.measures.cost_derived`, 4.6.1); E: ≥ 0; Mengenbezug zulässig | Gesamtkosten in Preisen von `price_base_year` (brutto, sofern nicht `cost_is_net`) inkl. Baunebenkosten und Risikozuschlag | Spec 00 §4.3.6, Konzept 3.2 |
| `…<m>.cost_kg.{kg200,kg300,kg400,kg500,kg600,kg700}` | value (amount) | EUR | `0` je KG | bedingt | E: ≥ 0; E: Schlüssel nur aus dieser Liste (KG 100 → Erwerbstyp, KG 800 → Finanzierungsmodul) | Kosten je DIN-276-Kostengruppe | Memo 02 §1.2, Konzept 3.2 |
| `…<m>.kg` | int ∈ {100,…,700} | – | A: Katalog | nein | E: 800 unzulässig („KG 800 berechnet das Finanzierungsmodul“); E: 100 nur bei `erwerb_*` | Kostengruppe der Maßnahme bei `cost_eur` (Zuordnung der Hilfsmatrizen, Sachwert-Filter) | Konzept 3.2 |
| `…<m>.kg700_share` | share | 1 | A: B:`costs/kostenzuschlaege_2026` (`use: share_kg700_of_kg300_400`): `0.20` bei `cost_kg` ohne `kg700`, sonst `0` | nein | W: > 0 und `cost_kg.kg700` gesetzt („doppelte Baunebenkosten“) | Baunebenkosten als Anteil | Konzept F19 |
| `…<m>.kg700_basis` | enum:`kg300_400`,`kg200_600` | – | `kg300_400` (G) | nein | – | Bezugsbasis der Baunebenkosten | Konzept 3.2 |
| `…<m>.contingency_share` | share | 1 | A: B:`costs/kostenzuschlaege_2026` (`use: contingency_share`): `0.10` bei `cost_kg`, sonst `0` | nein | W: Overlay auf `contingency_share` **und** auf `cost_factor` („Kostenrisiko doppelt“, Konzept 3.2) | Risikozuschlag „Unvorhergesehenes“ | Konzept F19, Memo 02 §9.3 |
| `…<m>.contingency_basis` | enum:`kg200_700`,`kg200_600` | – | `kg200_700` (G) | nein | – | Bezugsbasis des Risikozuschlags (Bau + KG 700 bzw. nur Bau) | Memo 07 S1 |
| `…<m>.cost_is_net` | lgl | – | `false` (G) | nein | – | Kosten netto angegeben; brutto = netto × (1 + `vat_rate`) | D6 |
| `…<m>.vat_rate` | share | 1 | A: Katalog (`0.19`; `pv`, `pv_wechselrichter`, `batteriespeicher` `0`); PV-Typen bei vorhandenem `energy.pv`: `expr` nach Spec 00 §7.10 (4.5.1 Nr. 5, X-25) | nein | E: `vat_recoverable` nie; W `validation.measures.pv_vat_conflict`: ausdrücklicher Wert widerspricht dem Basisfallwert der PV-Ableitung; W: ∉ {0, 0.07, 0.19} | enthaltener USt-Satz (Ausweis netto/USt); in der Komponente als Basisfallwert gelesen (4.6.1) | Spec 00 §7.10 |
| `…<m>.cost_factor` | number | 1 | `{ref: project.construction_cost_factor}` (G) | nein | E: > 0 | Kostenabweichungsfaktor auf die Schätzung inkl. Risikozuschlag; Basisfall 1; Overlay-Ziel der Kostenüberschreitung (Teil C) | Konzept 3.2, B9 |
| `…<m>.price_base_year` | int | Jahr | `project.price_base_year` (A, `rule:measure_catalog`) | nein | wie 1.2 | Preisstand der Kosten | R-35 |
| `…<m>.price_index` | value | 1/a | `{ref: market.construction_price_index}` (G) | nein | – | Preisindexrate bis zur Zahlung; `0` = Festpreis | Spec 00 §4.3.6 |
| `…<m>.component_areas_m2.<b>` | num | m² | `NULL` | nein | E: ≥ 0 | Teilflächen der Maßnahme (Mengenbezug, 3.5) | Memo 07 §3.2 |
| `…<m>.kw`, `…<m>.kwp`, `…<m>.kwh` | value | kW, kWp, kWh | `NULL`; Maßnahme `energy.pv.measure`: `kwp` A `{ref: energy.pv.kwp}` (`rule:measure_catalog`) | bedingt | E: Pflicht bei `per: kw`/`kwp`/`kwh` in der Maßnahme ohne Rückfall (3.5); E: > 0 | Nennleistung (z. B. Wärmepumpe), PV-Nennleistung, Energiemenge bzw. Speicherkapazität als Bezugsgröße des Mengenbezugs | Spec 00 §4.5, R-91 |
| `…<m>.useful_life_years` | number | a | A (`rule:measure_catalog`): Katalog → B:`costs/nutzungsdauern_2026`; `rueckbau`, `herrichten_erschliessung`, `baunebenkosten`: Bezug auf die Hauptmaßnahme bzw. GND (4.5.1 Nr. 4, X-26); Erwerb: keine | nein | E: > 0; W: < 5 oder > 100 | Nutzungsdauer (Ersatzzyklus, Zeitwert; stochastisch zulässig) | Konzept 3.4, F19 |
| `…<m>.replacement.enabled` | lgl | – | A (`rule:measure_catalog`): `true`, wenn eine Nutzungsdauer vorliegt und der Katalog Ersatz vorsieht | nein | – | Ersatzinvestitionen erzeugen | Konzept 3.4 |
| `…<m>.replacement.cost_eur` | value (amount) | EUR | `NULL` = Grundkosten der Maßnahme × `replacement.cost_factor` | nein | E: ≥ 0 | Ersatzkosten in Preisen von `price_base_year` | Memo 02 §9.4 |
| `…<m>.replacement.cost_factor` | number | 1 | `1.0` (G) | nein | E: ≥ 0 | Ersatzkosten relativ zu den Erstkosten | Memo 02 §9.4 |
| `…<m>.replacement.price_index` | value | 1/a | `{ref: measures.<m>.price_index}` (G, Platzhalter `{id}`) | nein | – | Preisindexrate der Ersatzkosten | – |
| `…<m>.replacement.classification` | enum | – | `erhaltung` (G) | nein | – | steuerliche Einordnung der Ersatzinvestition | Memo 06 §7.5 |
| `…<m>.ohnehin_share` | share | 1 | A: Katalog (Memo 03 §6.5) | nein | E: nicht zusammen mit `ohnehin_cost_eur`; W: Wert aus dem Katalog bei Perspektive `wu_*` („Ohnehin-Anteil aus der Bibliothek, Angabe empfohlen“) | wirtschaftlicher Ohnehin-Anteil der Kosten | Konzept 2.6, 3.3 |
| `…<m>.ohnehin_cost_eur` | value (amount) | EUR | `NULL` | nein | W: > Gesamtkosten (auf die Gesamtkosten begrenzt) | wirtschaftliche Ohnehin-Kosten in Preisen von `price_base_year` (gleiche Netto-/Brutto-Basis wie die Kosten) | Konzept 3.3 |
| `…<m>.ohnehin_due_date` / `…<m>.ohnehin_due_year` | timing | – | `NULL` | nein | E: höchstens eines; W: nach `end_date` („Vorzieheffekt außerhalb des Horizonts“) | Fälligkeit der Ohnehin-Maßnahme (Information, Kennzahl, Variantenprüfung) | Memo 02 §1.4 |
| `…<m>.classification` | enum:`auto`,`erhaltung`,`herstellung` | – | A (`rule:measure_catalog`): Neubauprojekt → `herstellung`; `erwerb_sanierung` → `auto`; sonst Katalog | nein | – | Einordnung für das Steuermodul (Register) | Memo 06 §7.5 |
| `…<m>.tax_spread_years` | int ∈ 1…5 | a | `NULL` | nein | W: gesetzt bei `classification` ≠ `erhaltung` | Verteilung von Erhaltungsaufwand (§ 82b EStDV), Zeilenfeld `spread_years` | Memo 06 §3.1.3 |
| `…<m>.modernization_kind` | enum:modernization_kind | – | A: Katalog (4.2), sonst `none`; `none` bei ausdrücklicher `classification: erhaltung` bzw. Ohnehin-Anteil 1 im Basisfall (4.5.1 Nr. 6, X-09) | nein | E: Code (Teil B §1.4); I `validation.measures.kind_from_classification`; W `validation.measures.kind_ohnehin_conflict` (ausdrücklicher Code ≠ `none` bei Ohnehin-Anteil 1) | Modernisierungsart (§ 555b BGB); Grundlage der Umlage (Teil B) | Spec 00 §17.3 Nr. 1 |
| `…<m>.asset_type` | enum:asset_types | – | A: Katalog | nein | E: Code | Anlagenart (Register) | Spec 00 §7.2 |
| `…<m>.asset_id` | chr | – | A (4.5.4) | nein | E: id-Muster; E: gleiche id mit anderem `asset_type` | Anlagenregister-id | Memo 06 §7.4 |
| `…<m>.replaces_ohnehin` | ids | – | `[]` (G) | nein | W: id existiert in `project.reference_variant` nicht | ersetzte Ohnehin-Maßnahmen der Referenz (Information, Kennzahl „energiebedingte Mehrkosten“) | Spec 00 §4.3.6, A-05 |
| `…<m>.replaces_elements` | ids | – | `[]` (G) | nein | E: id nicht in `building.elements` | Bestandsbauteile, deren Ersatzzyklus mit der Fertigstellung endet | Konzept 3.4 |
| `…<m>.funding_choice` | enum:`keine`,`beg_zuschuss`,`beg_kredit`,`35c` | – | E: Register aus dem Block `funding` (4.5.3); kein Domänen-Default | nein | E: `35c` zusammen mit BEG/KfW für dieselbe Maßnahme (Spec 00 §10.9) | Förderwahl (Register) | Memo 06 §7.5 |
| `…<m>.contractor_certified` | lgl | – | `NA` | nein | W: `35c` und nicht `true` | Fachunternehmerbescheinigung (§ 35c) | Memo 06 §7.5 |
| `…<m>.paid_in_full_date` | date | – | A (`rule:measure_catalog`): letzter Zahlungstermin | nein | – | vollständige Bezahlung (§ 35c-Fristen) | Memo 06 §7.5 |
| `…<m>.effects` | map | – | `{}` | nein | 4.4 | Wirkungen (Instandhaltung, Restwert, Energie, Miete, Leerstand) | Spec 00 §4.3.6, A-15 |
| `…<m>.rent_law` | map | – | Teil B | nein | Teil B; W: mietrechtlicher Erhaltungsanteil > Ohnehin-Kosten (Konzept 2.6, Plausibilität) | Erhaltungsanteil § 559 Abs. 2 u. a. | Konzept 3.3 |
| **nur `erwerb_grundstueck`, `erwerb_objekt`:** | | | | | | | |
| `…<m>.purchase_price_eur` | value (amount) | EUR | – | ja | E: ≥ 0 | Kaufpreis (Gegenleistung) | Memo 02 §9.3 |
| `…<m>.land_share` | share | 1 | A (`rule:measure_catalog`): `erwerb_grundstueck`: `1`; `erwerb_objekt`: `{expr: "building.land_value_eur / measures.<m>.purchase_price_eur"}`, wenn `land_value_eur` gesetzt | bedingt | E: Pflicht bei `erwerb_objekt` ohne `land_value_eur` | Aufteilung Boden/Gebäude (Kaufpreisaufteilung) | Memo 06 §7.4 |
| `…<m>.uniform_contract` | lgl | – | `false` (A, Erwerbstypen) | nein | – | einheitlicher Vertragsgegenstand: GrESt auch auf die Bauleistung | Spec 00 §7.11 |
| `…<m>.uniform_contract_measures` | ids | – | A (`rule:measure_catalog`): alle Maßnahmen mit `follows_construction` | nein | E: Maßnahmen-ids | Bauleistung, die in die GrESt-Basis eingeht | Memo 06 §3.4 |
| `…<m>.grest_rate` | rate | 1 | `NULL` = Regel `grest` (4.8) | nein | W: Abweichung vom Landessatz | ausdrücklicher GrESt-Satz | Memo 03 §10.3 |
| `…<m>.notary_share`, `…<m>.land_registry_share` | share | 1 | A: `0.010`, `0.005` (B:`costs/erwerbsnebenkosten_2026`, `use: notary_share` bzw. `use: land_registry_share`; Schlüssel nach X-19, Abstimmung Teil C) | nein | W: Summe ∉ [0,011; 0,025] | Notar bzw. Grundbuch (Memo 03: zusammen 1,5 %) | Memo 03 §10.4 |
| `…<m>.broker_share` | share | 1 | `0` (A, Erwerbstypen; Vergleichswert `use: broker_share` 0,0357) | nein | W: > 0,0714 | Maklerprovision Käufer (EFH/ETW an Verbraucher typ. 0,0357) | Memo 03 §10.4 |
| `…<m>.other_share` | share | 1 | `0` (A, Erwerbstypen; Vergleichswert `use: other_share` 0,005) | nein | – | sonstige Erwerbsnebenkosten (Gutachten, Due Diligence, D: 0,005) | Memo 03 §10.4 |
| `…<m>.ancillary_date` | timing | – | `= date` (A, `rule:measure_catalog`) | nein | – | Fälligkeit der Erwerbsnebenkosten | Memo 06 §8 |

### 4.2 Maßnahmentyp-Katalog (`measure_types`)

Codes in `inst/vocab/measure_types.yaml`: genau die 37 Codes dieser Tabelle (Integrator, Spec 00 §2.11, R-89, N-01;
Antrag S01A-09 entschieden). Sammelcodes (`heizung_tausch`, `daemmung_dach`, `daemmung_ogd`, `aussentuer`) gibt es
nicht; Förderlisten (`eligibility.measure_types`, Teil C §3.4) nennen die Einzelcodes, `sonnenschutz` ist in v1 kein Code
(Spec 00 §17.3 Nr. 8 a). Defaults im Bibliothekseintrag `costs/massnahmentypen_2026` (Datenträger WS-L, vollständig mit
37 Typen in Teil C §3.7, Schema 8.3, N-30), Nutzungsdauern mit Verteilungsvorschlag in `costs/nutzungsdauern_2026`
(Teil C). Klassifikation „Bestand“ gilt für Bestands- und Erwerbsprojekte (Erwerb + Sanierung: `auto`), in
Neubauprojekten gilt `herstellung` (BMF 26.01.2026 nach Memo 06 §7.5). ND „Hauptm.“: Bezug auf die Nutzungsdauer der
Hauptmaßnahme (4.5.1 Nr. 4, X-26). Spalte „Instandsetzung“: Vorschlag für `effects.maintenance.share_of_cost_pa`, nur
Instandsetzung (`repair` nach VDI 2067, `costs/wartung_instandsetzung_vdi2067_2026`, Memo 03 §9, Qualität D); Wartung
und Betrieb gehören zum Energiezustand bzw. zum PV-Betrieb in Teil B (X-10); nicht automatisch gesetzt (4.11.4).

| Code | Bedeutung | KG | `asset_type` | Klass. Bestand | ND (a) | Ohnehin | `modernization_kind` | Anlage-2-Element (Punkte) | USt | Ersatz | Instand­setzung |
|---|---|---:|---|---|---:|---:|---|---|---:|:---:|---:|
| `neubau` | Neubau Gebäude gesamt | 300 | `gebaeude_wohnen` | – (`herstellung`) | 80 (GND) | 0 | `none` | – | 0,19 | nein | – |
| `erweiterung` | Anbau | 300 | `gebaeude_wohnen` | `herstellung` | 80 | 0 | `bgb_555b_7` | – | 0,19 | nein | – |
| `aufstockung` | Aufstockung | 300 | `gebaeude_wohnen` | `herstellung` | 80 | 0 | `bgb_555b_7` | – | 0,19 | nein | – |
| `rueckbau` | Abbruch, Rückbau (Ersatzneubau) | 200 | `gebaeude_wohnen` | `herstellung` | Hauptm. | 0 | `none` | – | 0,19 | nein | – |
| `herrichten_erschliessung` | Herrichten, Erschließung, Anschlüsse | 200 | `gebaeude_wohnen` | `herstellung` | Hauptm. | 0 | `none` | – | 0,19 | nein | – |
| `erwerb_grundstueck` | Grundstückskauf | 100 | `grund_boden` | – | – | – | `none` | – | 0 | nein | – |
| `erwerb_objekt` | Kauf bebautes Grundstück | 100 | `gebaeude_wohnen` + `grund_boden` | – | – | – | `none` | – | 0 | nein | – |
| `daemmung_fassade` | WDVS/Fassadendämmung | 300 | `gebaeude_wohnen` | `erhaltung` | 40 | 0,50 | `bgb_555b_1` | `facade_insulation` (4) | 0,19 | ja | – |
| `daemmung_dach_steil` | Steildach mit Neueindeckung und Dämmung | 300 | `gebaeude_wohnen` | `erhaltung` | 50 | 0,70 | `bgb_555b_1` | `roof_insulation` (4) | 0,19 | ja | – |
| `daemmung_dach_flach` | Flachdach mit Abdichtung und Dämmung | 300 | `gebaeude_wohnen` | `erhaltung` | 30 | 0,57 | `bgb_555b_1` | `roof_insulation` (4) | 0,19 | ja | – |
| `daemmung_oberste_geschossdecke` | Dämmung oberste Geschossdecke | 300 | `gebaeude_wohnen` | `erhaltung` | 50 | 0 | `bgb_555b_1` | `roof_insulation` (2) | 0,19 | ja | – |
| `daemmung_kellerdecke` | Dämmung Kellerdecke | 300 | `gebaeude_wohnen` | `erhaltung` | 50 | 0 | `bgb_555b_1` | – | 0,19 | ja | – |
| `fenster` | Fenstertausch | 300 | `gebaeude_wohnen` | `erhaltung` | 40 | 0,85 | `bgb_555b_1` | `windows_doors` (2) | 0,19 | ja | – |
| `aussentueren` | Außentüren | 300 | `gebaeude_wohnen` | `erhaltung` | 40 | 0,85 | `bgb_555b_1` | `windows_doors` (2) | 0,19 | ja | – |
| `putz_anstrich` | Putzausbesserung, Anstrich (Ohnehin) | 300 | `gebaeude_wohnen` | `erhaltung` | 15 | 1,00 | `none` | – | 0,19 | ja | – |
| `instandsetzung` | sonstige Instandsetzung (Ohnehin) | 300 | `gebaeude_wohnen` | `erhaltung` | 25 | 1,00 | `none` | – | 0,19 | ja | – |
| `heizung_waermepumpe_luft` | Luft/Wasser-Wärmepumpe | 400 | `gebaeude_wohnen` | `erhaltung` | 18 | `NULL` (Referenzanlage, Angabe nötig) | `bgb_555b_1a` | `heating` (2) | 0,19 | ja | 0,010 |
| `heizung_waermepumpe_sole` | Sole/Wasser-Wärmepumpe (Gerät) | 400 | `gebaeude_wohnen` | `erhaltung` | 20 | `NULL` | `bgb_555b_1a` | `heating` (2) | 0,19 | ja | 0,010 |
| `heizung_gaskessel` | Gas-Brennwertkessel | 400 | `gebaeude_wohnen` | `erhaltung` | 18 | 1,00 | `none` | `heating` (2) | 0,19 | ja | 0,010 |
| `heizung_pelletkessel` | Pelletkessel | 400 | `gebaeude_wohnen` | `erhaltung` | 20 | `NULL` | `bgb_555b_1a` | `heating` (2) | 0,19 | ja | 0,020 |
| `heizung_fernwaerme` | Fernwärme-Übergabestation | 400 | `gebaeude_wohnen` | `erhaltung` | 25 | `NULL` | `bgb_555b_1a` | `heating` (2) | 0,19 | ja | 0,010 |
| `heizungsverteilung` | Heizkörper, Verteilung, hydraulischer Abgleich | 400 | `gebaeude_wohnen` | `erhaltung` | 40 | `NULL` | `bgb_555b_1` | `heating` (2; mit dem Wärmeerzeuger zusammen höchstens 2, F-24) | 0,19 | ja | – |
| `lueftung_zentral` | Lüftung zentral mit WRG | 400 | `gebaeude_wohnen` | `auto` | 20 | 0 | `bgb_555b_1` | – | 0,19 | ja | 0,015 |
| `lueftung_dezentral` | Lüftung dezentral bzw. Abluft | 400 | `gebaeude_wohnen` | `auto` | 15 | 0 | `bgb_555b_1` | – | 0,19 | ja | 0,015 |
| `pv` | Photovoltaik (Module, Montage) | 400 | `pv_anlage` | `herstellung` | 25 | 0 | `none` | – | 0 (A, 4.5.1 Nr. 5) | ja | 0 (Betrieb: Teil B `energy.pv.opex_share_of_cost`) |
| `pv_wechselrichter` | Wechselrichter | 400 | `pv_anlage` | `erhaltung` | 12 | 0 | `none` | – | 0 (A, 4.5.1 Nr. 5) | ja | – |
| `batteriespeicher` | Batteriespeicher | 400 | `pv_anlage` | `herstellung` | 12 | 0 | `none` | – | 0 (A, 4.5.1 Nr. 5) | ja | – |
| `leitungen` | Leitungen (Strom, Gas, Wasser, Abwasser) | 400 | `gebaeude_wohnen` | `erhaltung` | 40 | `NULL` | `none` | `pipes` (2) | 0,19 | ja | – |
| `baeder` | Bäder, Sanitär | 400 | `gebaeude_wohnen` | `erhaltung` | 25 | `NULL` | `bgb_555b_4` | `bathrooms` (2) | 0,19 | ja | – |
| `innenausbau` | Decken, Böden, Treppen | 300 | `gebaeude_wohnen` | `erhaltung` | 30 | `NULL` | `none` | `interior` (2) | 0,19 | ja | – |
| `grundriss` | wesentliche Grundrissverbesserung | 300 | `gebaeude_wohnen` | `herstellung` | 80 | 0 | `bgb_555b_4` | `floor_plan` (2) | 0,19 | nein | – |
| `aufzug` | Aufzug (Neueinbau bzw. Modernisierung) | 400 | `gebaeude_wohnen` | `herstellung` | 25 | 0 | `bgb_555b_4` | – | 0,19 | ja | – |
| `ladeinfrastruktur` | Ladepunkte | 400 | `ladeinfrastruktur` | `herstellung` | 15 | 0 | `none` | – | 0,19 | ja | – |
| `aussenanlagen` | Außenanlagen, Stellplätze | 500 | `aussenanlage` | `herstellung` | 30 | 0 | `none` | – | 0,19 | ja | – |
| `ausstattung` | Ausstattung (z. B. Küchen) | 600 | `bewegliches_wg` | `herstellung` | 15 | 0 | `none` | – | 0,19 | ja | – |
| `baunebenkosten` | gesonderte Baunebenkosten (KG 700) | 700 | `gebaeude_wohnen` | wie Hauptmaßnahme | Hauptm. | 0 | `none` | – | 0,19 | nein | – |
| `sonstige` | frei | – | `gebaeude_wohnen` | `auto` | – | 0 | `none` | – | 0,19 | nein | – |

Quellen: Nutzungsdauern Memo 03 §9 (F19: Gaskessel 18, Fenster 40, Flachdach 30, Heizkörper 40), Memo 02 §1.5
(Putz/Anstrich 15, Aufzug 25, Bäder 25, Leitungen 40), GND 80 ImmoWertV Anl. 1; Ohnehin-Anteile Memo 03 §6.5 (IWU,
Qualität D; „nur bei Restnutzungsdauer ≤ 5 J. voll ansetzen“, Hinweistext); Klassifikation BMF 26.01.2026 nach Memo 06
§7.5; Anlage-2-Elemente ImmoWertV 2021 Anl. 2 (Tabelle 6.3.3; Heizkörper und Verteilung gehören zur „Modernisierung
der Heizungsanlage“, nicht zu den Leitungssystemen, F-24); Instandsetzung VDI 2067 `repair` (Teil C §3.7). Qualität
der Spalten ND/Ohnehin/Instandsetzung: C–D.

### 4.3 `modernization_kind`

Enum, Bedeutung und Rechtsfolgen (Umlagefähigkeit, § 559e, § 536 Abs. 1a, Aliase) regelt **Teil B §1.4**; Teil A
setzt nur den Default je Maßnahmentyp (Spalte in 4.2, Vorbelegung 4.5.1) und reicht den Code unverändert an das
Maßnahmenregister weiter. Ohne Katalogwert gilt `none`. Für Erhaltungs- und Ersatzmaßnahmen (ausdrückliche
`classification: erhaltung`, Ohnehin-Anteil 1) setzt `rule:measure_catalog` statt des Katalogwerts `none` (4.5.1 Nr. 6,
X-09); ein ausdrücklich angegebener Code bleibt unverändert.

**Abbildung auf Bibliotheksschlüssel (Teil C §3.7).** Die Nutzungsdauer-Defaults der Spalte „ND“ stammen aus
`costs/nutzungsdauern_2026` (Schlüssel in Klammern; Herkunft von `useful_life_years` ist dieser Eintrag, N-30; Typen
ohne Schlüssel aus `costs/massnahmentypen_2026`; `rueckbau`, `herrichten_erschliessung`, `baunebenkosten` folgen der
Hauptmaßnahme, Erwerbstypen haben keine Nutzungsdauer):
`heizung_waermepumpe_luft` (`hp_air_water`), `heizung_waermepumpe_sole` (`hp_brine_water`), `heizung_gaskessel`
(`gas_boiler`), `heizung_pelletkessel` (`pellet_boiler`), `heizung_fernwaerme` (`district_heating_substation`),
`daemmung_fassade` (`etics`), `putz_anstrich` (`plaster_paint`), `fenster` und `aussentueren` (`windows`),
`daemmung_dach_steil` (`roof_pitched_covering`), `daemmung_dach_flach` (`roof_flat_sealing`),
`daemmung_oberste_geschossdecke` und `daemmung_kellerdecke` (`insulation_roof_ceiling`), `pv` (`pv_modules`),
`pv_wechselrichter` (`pv_inverter`), `batteriespeicher` (`battery`), `lueftung_zentral` (`ventilation_central`),
`lueftung_dezentral` (`ventilation_decentral`), `heizungsverteilung` (`heating_distribution`), `leitungen` (`pipes`),
`aufzug` (`elevator`), `baeder` (`bathrooms`), `neubau`/`erweiterung`/`aufstockung`/`grundriss`
(`building_total_immowertv`). Die Spalte „Instandsetzung“ entspricht `repair` aus
`costs/wartung_instandsetzung_vdi2067_2026` (`heat_pump` für beide Wärmepumpen, `gas_boiler`, `pellet_boiler`,
`ventilation` für beide Lüftungstypen, `district_heating_substation`); `service` und `pv_system.total` gehören zum
Energiezustand bzw. zum PV-Betrieb in Teil B (X-10). Die Overlay-Vorlagen (`uncertainty`) dieser Einträge gelten über den Bezug
`measures.<m>.useful_life_years` (Teil C §1.9).

### 4.4 `measures.<m>.effects` – Wirkungen

| YAML-Pfad | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Eigentümer |
|---|---|---|---|---|---|---|---|
| `…effects.start` | enum:`completion`,`next_year` | – | `completion` (T) | nein | – | Beginn der Wirkungen: ab dem Monat, der mit der (verschobenen) Fertigstellung beginnt (mi(d), Spec 00 §3.4 Nr. 1–2, R-98), bzw. ab 1. Januar des Folgejahres (A-03 „effect_start“) | Teil A (`aux$in_operation`, 4.6.4) |
| `…effects.maintenance.factor` | value | 1 | `1` | nein | E: ≥ 0 | Faktor auf die Instandhaltungspauschale ab Wirkungsbeginn | Teil A (4.11) |
| `…effects.maintenance.duration_years` | number | a | `NULL` (= bis Horizont) | nein | E: > 0 | Wirkungsdauer des Faktors | Teil A |
| `…effects.maintenance.reset_age` | lgl | – | `false` | nein | – | setzt das Alter der II.-BV-Klasse zurück (Vollsanierung) | Teil A |
| `…effects.maintenance.share_of_cost_pa` | share | 1/a | `NULL` | nein | W `validation.maintenance.service_double` (zusammen mit Pauschale > 0 ohne `excludes_explicit_replacements`); W `validation.maintenance.service_double_energy` (Wartung zugleich im Energiezustand bzw. PV-Betrieb, 4.11.4) | bauteilbezogene **Instandsetzung** in % der Investition (VDI 2067, ohne Wartung; Vorschlag Spalte „Instandsetzung“ in 4.2) → Komponente `m_<m>_maint` | Teil A |
| `…effects.residual.modernization_points.<el>` | int | Punkte | Katalog (Element, Punkte) | nein | E: 0 ≤ p ≤ Höchstpunkte des Elements | Beitrag zu den Modernisierungspunkten (ImmoWertV Anl. 2) ab Wirkungsbeginn | Teil A (6.3.3) |

Wirkungen auf Energie, Miete und Leerstand stehen **nicht** unter `effects`: Energiezustände verweisen über
`energy.<zustand>.measure` auf die Maßnahme, mietrechtliche Felder stehen in `measures.<m>.rent_law` (Teil B §1.4,
§3.2.2). Die früheren Platzhalter `effects.energy.*`, `effects.rent.*`, `effects.vacancy.*` entfallen (X-24 a); ein
solcher Schlüssel ist E `validation.unknown_key` mit Verweis auf Teil B.

### 4.5 Expander `measures` (`R/expand-measures.R`, WS-E2, `order = 10`)

#### 4.5.1 Katalogvorbelegung und abgeleitete Felder (`rule:measure_catalog`, WS-A, vor `item_defaults`)

`vofi_resolve()` (WS-A) belegt nach Schicht 8, vor `item_defaults` und vor den Expandern fehlende Felder jeder Maßnahme
und jedes Bestandsbauteils vor (Spec 00 §4.7, R-86, N-07). Vorhandene Werte bleiben unverändert; Herkunft
`source_type = "type_default"`, `layer = 0`, `entry` = Bibliotheks-id (Katalogwerte) bzw. `"rule:measure_catalog"`
(abgeleitete Werte). Overlay-Ziele auf vorbelegte Pfade (z. B. `measures.<m>.useful_life_years`, Teil C §1.9) sind damit
zulässig. Die Regel meldet einmal je Variante I `validation.measures.catalog_defaults` mit den gesetzten Feldern.

1. **Katalog** (`costs/massnahmentypen_2026` über `bctx$lib()`; Nutzerbibliotheken überschatten): `kg`, `asset_type`,
   `ohnehin_share` (nur wenn weder `ohnehin_share` noch `ohnehin_cost_eur` gesetzt und der Katalogwert nicht `NULL`
   ist), `modernization_kind` (vorbehaltlich Nr. 6), `vat_rate` (vorbehaltlich Nr. 5),
   `effects.residual.modernization_points`, `replacement.enabled`; `useful_life_years` aus `costs/nutzungsdauern_2026`
   über `useful_life_key` (Herkunft dieser Eintrag, N-30) bzw. aus `useful_life_years` des Katalogs; `kg700_share`
   (`costs/kostenzuschlaege_2026`, `use: share_kg700_of_kg300_400`; 0,20 bei `cost_kg` ohne `kg700`, sonst 0) und
   `contingency_share` (`use: contingency_share`; 0,10 bei `cost_kg`, sonst 0); bei Erwerbstypen `notary_share`,
   `land_registry_share` (`costs/erwerbsnebenkosten_2026`, X-19), `broker_share: 0`, `other_share: 0`,
   `uniform_contract: false`.
2. **Projektart und Termine:** `classification` (Neubauprojekt → `herstellung`; `erwerb_sanierung` → `auto`; sonst
   Spalte „Klass. Bestand“), `price_base_year` = `project.price_base_year`, `completion_date` (`date` bzw. Y-01-01 bzw.
   letzter Termin des Zahlungsplans), `paid_in_full_date` (letzter Zahlungstermin), `follows_construction` und
   `construction_delay_mode` (4.1); Erwerb: `land_share` (4.1), `uniform_contract_measures` (alle Maßnahmen mit
   `follows_construction`), `ancillary_date` = `date`.
3. **Bauteile** (`building.elements.<e>`): `kg`, `asset_type`, `vat_rate` und `useful_life_years` aus dem Katalog des
   `measure_type`, `price_base_year` = `project.price_base_year`.
4. **Nutzungsdauer der Hauptmaßnahme (X-26):** `rueckbau`, `herrichten_erschliessung` und `baunebenkosten` (Teile der
   Herstellung ohne eigene Nutzungsdauer) erhalten `useful_life_years: {ref: measures.<h>.useful_life_years}` mit h =
   erste Maßnahme in YAML-Reihenfolge mit `follows_construction: true` und Nutzungsdauer, ohne solche h
   `{ref: residual_value.income_value.gnd_years}` (GND, 80); `replacement.enabled` bleibt `false` (nur Wertpfad).
   Erwerbstypen erhalten keine Nutzungsdauer (6.3.7).
5. **PV-Umsatzsteuer und PV-Leistung (X-25, Spec 00 §7.10):** Für die Maßnahme `energy.pv.measure` und alle weiteren
   Maßnahmen der Typen `pv`, `pv_wechselrichter`, `batteriespeicher` setzt die Regel bei vorhandenem `energy.pv`
   `vat_rate: {expr: "ifelse(energy.pv.kwp <= <s> | energy.pv.vat_zero_rate_attested, 0, 0.19)"}`; s ist
   `pv_zero_rate.max_kwp_without_proof` aus `bctx$legal("umsatzsteuer")` (`legal/umsatzsteuer_2026`: 30), als Zahl
   eingesetzt (deterministischer Rechtswert). Ohne `energy.pv` bzw. bei inaktivem Thema gilt der Katalogwert 0 mit I
   `validation.measures.pv_vat_unchecked`. Ein ausdrücklicher Wert gewinnt; widerspricht er dem Basisfallwert der
   Ableitung, folgt W `validation.measures.pv_vat_conflict`. Für `energy.pv.measure` setzt die Regel zusätzlich
   `kwp: {ref: energy.pv.kwp}` (Mengenbezug `per: kwp`, 3.5).
6. **Keine Modernisierung bei Erhaltung (X-09):** Fehlt `modernization_kind`, setzt die Regel `none` statt des
   Katalogwerts, wenn (a) `classification: erhaltung` ausdrücklich angegeben ist (Szenario, Variante, Set oder
   Override; nicht der Katalogwert aus Nr. 2) oder (b) der Ohnehin-Anteil im Basisfall 1 ist (`ohnehin_share` = 1 bzw.
   `ohnehin_cost_eur` ≥ Grundkosten K⁰ nach 4.6.2 (1), ausgewertet mit `bctx$value_base()` nach den übrigen
   Vorbelegungen und `rule:cost_from_kg`; Antrag S01A-11). Der Code ist deterministisch; Overlays auf den
   Ohnehin-Anteil ändern ihn nicht. Meldung I `validation.measures.kind_from_classification` mit den betroffenen
   Maßnahmen („keine Modernisierungsumlage; für eine Umlage `modernization_kind` angeben“). Ein ausdrücklicher Code
   ≠ `none` bei Ohnehin-Anteil 1 bleibt und erzeugt W `validation.measures.kind_ohnehin_conflict`. Beispiel Teil C S2:
   `ersatz_wp_2049` und `aufzug_2054` (`classification: erhaltung`) erhalten `none` statt `bgb_555b_1a` bzw.
   `bgb_555b_4` und erzeugen keine Umlagezeilen.

Die Vorbelegung ändert keine vorhandenen Werte und ist damit verträglich mit Spec 00 §4.12 Nr. 1 (Expander ändern
keine Domänenblöcke; fehlende Domänenwerte setzt eine Ableitungsregel von WS-A, R-86). Die übrigen konstanten Defaults
je Maßnahme bzw. Bauteil (Verschiebung, Aktivierung, Kostenfaktor, Preisindex, Profile) setzt danach
`item_defaults.measures` bzw. `item_defaults."building.elements"` (2.2).

#### 4.5.2 Algorithmus (MUSS)

```text
expand(block = scenario$measures, scenario, bctx):
  comps <- list(); assets <- list(); measures_reg <- list(); notes <- list()
  bid <- scenario$building$building_id %||% "b1"
  für m in names(block) (YAML-Reihenfolge):
    M   <- block[[m]]
    a_m <- AF-Ausdruck (0.3): expr "measures.<m>.active * funding.<f>.approved * …" (f mit on_reject: drop_measures,
           m ∈ funding.<f>.measures); sonst ref measures.<m>.active
    falls M$measure_type ∈ {erwerb_grundstueck, erwerb_objekt}:
        comps[[m_<m>_purchase]] <- Typ land (4.7)            mit Bezügen auf purchase_price_eur, land_share, date
        comps[[m_<m>_acq]]      <- Typ acquisition_cost (4.8)
    sonst:
        comps[[m_<m>_capex]]    <- Typ capex (4.6): jeder Parameter p mit Feld M$p -> node_ref("measures.<m>.p")
                                   (außer abgeleitetem cost_eur bei cost_kg, 4.6.1);
                                   cost_kg.kg<k> -> node_ref("measures.<m>.cost_kg.kg<k>"); active <- a_m;
                                   construction_delay_months <- node_ref("project.construction_delay_months");
                                   Termine (date/year/payment_schedule-Termine, completion_date) als Datum
        falls Nutzungsdauer vorhanden (auch ohne Ersatz, für den Zeitwertpfad des Restwerts):
            comps[[m_<m>_repl]] <- Typ replacement (4.10) mit capex_id = m_<m>_capex, include_initial = TRUE,
                                   enabled = replacement.enabled (false: keine Zahlungen, nur Wertpfad),
                                   install_date = completion_date, install_shift_months = Verschiebung der
                                   Fertigstellung (4.6.2), useful_life_years <- node_ref("measures.<m>.useful_life_years"),
                                   cost_eur <- node_ref("measures.<m>.replacement.cost_eur") bzw. NULL (aus capex),
                                   until_date/until_shift_months = Fertigstellung einer ersetzenden Maßnahme (s. u.)
        falls effects.maintenance.share_of_cost_pa gesetzt:
            comps[[m_<m>_maint]] <- Typ maintenance (4.11), basis share_of_cost, capex_id = m_<m>_capex
    measures_reg[[m]] <- vofi_measure(...) nach 4.5.3;  assets nach 4.5.4
  für e in names(building$elements):
    comps[[m_<e>_repl]] <- Typ replacement mit install_date = (installed_year)-01-01, first_date/first_shift_months aus
                           next_replacement/next_replacement_delay_months, overdue, include_initial = FALSE,
                           cost_eur <- node_ref("building.elements.<e>.replacement_cost_eur"), active <- ref …<e>.active;
                           endet bei Fertigstellung einer Maßnahme mit e ∈ replaces_elements (until_date,
                           until_shift_months = deren Verschiebung der Fertigstellung)
    measures_reg[[e]] <- vofi_measure(e, measure_type, classification = "erhaltung", classification_source = "default", …)
  falls building vorhanden, building.maintenance.enabled und basis ≠ none:
    comps[[m_maintenance]] <- Typ maintenance (4.11) mit Bezügen auf building.maintenance.*;
                              factors[[m_<m>_capex]] <- node_ref("measures.<m>.effects.maintenance.factor") und
                              factor_years[[m_<m>_capex]] (duration_years) für Maßnahmen mit Wirkungsfeld;
                              reset_capex_ids = m_<m>_capex der Maßnahmen aus iibv.reset_by_measures (auto: reset_age);
                              from nach rule:maintenance_from; tax_category nach Perspektive (4.11.3);
                              after = alle referenzierten m_<m>_capex
  falls building vorhanden: Assets <bid>_building und <bid>_land (4.5.4)
  rückgabe list(components = comps, financing = list(), assets, measures = measures_reg, notes)
```

Weitere Regeln:

1. **ids** `m_<m>_capex`, `m_<m>_repl`, `m_<m>_maint`, `m_<m>_purchase`, `m_<m>_acq`, `m_<e>_repl`, `m_maintenance`
   (R-18, vollständige Liste Spec 00 §4.12, R-90; Antrag S01A-04 entschieden). Maßnahmen- und Bauteil-ids sind
   gemeinsam eindeutig und höchstens **29** Zeichen lang, damit die längste erzeugte id `m_<m>_purchase` höchstens 40
   Zeichen hat (Spec 00 §4.4 Nr. 2, N-23); die Validierung (WS-B, Ebene 3) prüft jede erzeugte id und nennt die
   zulässige Höchstlänge. Kollision: E.
2. **Bezug statt Kopie** für alle numerischen Domänenblätter (Spec 00 §4.12 Nr. 2, 5). Termine, Codes und Flags werden
   als normalisierte Werte gesetzt (deterministisch).
3. **Ersetzte Bauteile:** Ist e ∈ `measures.<m>.replaces_elements`, endet der Zyklus von `m_<e>_repl` mit der
   Fertigstellung von m: `until_date = completion_date(m)`, `until_shift_months` = Verschiebung der Fertigstellung von
   m, gewichtet mit a_m (bei a_m = 0 läuft der Zyklus weiter: `until_shift_months` wird für a_m = 0 auf
   +12·(Horizont) gesetzt, als `expr`: `"<shift> + (1 - <a_m>) * 1200"`).
4. **Kreditbezug:** Verweist ein Kredit per `measure_id` auf eine Maßnahme mit Overlay auf `delay_months`, meldet die
   Validierung `vofi_warning_plausibility` („Kredittermine bleiben fest“, Spec 00 §3.9).
5. **Ohne `building`:** Maßnahmen sind zulässig (Asset-ids `b1_*`), `m_maintenance` entfällt.

#### 4.5.3 Maßnahmenregister

`vofi_measure(measure_id = m, measure_type, classification, classification_source, completion_date, paid_in_full_date,
contractor_certified, funding_choice, asset_id, label)` mit:

- `classification_source`: `user`, wenn `classification` in der Maßnahme steht; `rule` bei Ableitung aus der Projektart;
  `default` bei Katalogwert.
- `completion_date`: deterministischer Termin **ohne** laufspezifische Verschiebung (Register sind laufunabhängig).
- `funding_choice`: aus `funding` (deterministische Codes): ein Instrument mit m ∈ `measures` und
  `instrument_type: tax_credit` → `35c`; `grant` → `beg_zuschuss`; `loan`/`loan_with_repayment_grant` → `beg_kredit`;
  mehrere: Vorrang `beg_zuschuss` vor `beg_kredit`; sonst `keine`. Ein ausdrücklicher Wert in der Maßnahme gewinnt.
- Erwerbsmaßnahmen erhalten `classification = "herstellung"` (Anschaffung) und das Gebäude-Asset.

#### 4.5.4 Anlagenregister und Asset-ids

| Asset-id | `asset_type` | wann | Felder (`vofi_asset`) |
|---|---|---|---|
| `<bid>_building` | `gebaeude_wohnen` (bei `commercial_share ≥ 0,5`: `gebaeude_nichtwohnen`) | immer, wenn `building` vorhanden | `in_service_date`: Neubauprojekt = späteste `completion_date` der Maßnahmen mit `follows_construction`; Bestand = (`first_occupancy_year`)-01-01; Erwerb = Erwerbsdatum. `original_completion_year` = `construction_year`; `acquisition_date` = Termin von `erwerb_objekt`; `construction_start_date` = erster Zahlungstermin von `neubau`; `land_share` = `land_share` von `erwerb_objekt` bzw. `land_value_eur / market_value_eur` (Basisfall), sonst 0; `living_area_m2`; `efficiency_standard` = `efficiency_standard_after` |
| `<bid>_land` | `grund_boden` | immer, wenn `building` vorhanden | `in_service_date` = Erwerbsdatum bzw. `valuation_date` |
| `<bid>_<m>` | Katalog bzw. Maßnahme: `pv_anlage`, `ladeinfrastruktur`, `bewegliches_wg`, `aussenanlage` | je Maßnahme dieses Typs | `in_service_date` = `completion_date` |
| `measures.<m>.asset_id` | ausdrücklich | Nutzerwahl (z. B. PV, Wechselrichter, Speicher als ein Asset `b1_pv`) | gleiche id mit gleichem Typ zulässig (identische Felder), sonst E |

Maßnahmen an der Gebäudehülle und Technik (`gebaeude_wohnen`) tragen `<bid>_building` (nachträgliche Herstellungs-
bzw. Erhaltungskosten des Gebäudes, Memo 06 §7.4).

#### 4.5.5 Tests (WS-E2, `test-expand-measures.R`)

| Nr. | Fall | Erwartung |
|---|---|---|
| XM1 | Maßnahme `wp: {measure_type: heizung_waermepumpe_luft, year: 2027, cost_eur: 126000}` | Komponenten `m_wp_capex`, `m_wp_repl`; `measures.wp.useful_life_years = 18` (Herkunft `type_default`, `entry = "costs/nutzungsdauern_2026"` über `useful_life_key: hp_air_water`, N-30); `components.m_wp_capex.cost_eur = {ref: measures.wp.cost_eur}`; Register `wp` mit `classification = "erhaltung"`, `classification_source = "default"`, `asset_id = "b1_building"` |
| XM2 | Schicht 8 setzt `measures.wp.cost_eur: 130000` | `components.m_wp_capex.cost_eur` unverändert (Bezug) |
| XM3 | `pv: {measure_type: pv, year: 2028, cost_eur: 45000}` mit `energy.pv: {kwp: 10, measure: pv}` | `asset_id = "b1_pv"`, Asset `b1_pv` mit `asset_type = "pv_anlage"`; `measures.pv.vat_rate = {expr: "ifelse(energy.pv.kwp <= 30 \| energy.pv.vat_zero_rate_attested, 0, 0.19)"}` (Herkunft `rule:measure_catalog`), Basisfallwert 0; mit `kwp: 40` 0.19, mit zusätzlich `vat_zero_rate_attested: true` 0; ausdrücklich `vat_rate: 0` bei `kwp: 40` ohne Attribut → W `validation.measures.pv_vat_conflict`; ohne `energy.pv` → 0 und I `validation.measures.pv_vat_unchecked` |
| XM4 | `measure_type: erwerb_objekt`, `purchase_price_eur: 1200000`, `land_share: 0.25` | `m_<m>_purchase` (Typ `land`) und `m_<m>_acq` (Typ `acquisition_cost`); kein `m_<m>_capex` |
| XM5 | Förderung `f1: {instrument_type: grant, measures: [wp], on_reject: drop_measures}` | `components.m_wp_capex.active = {expr: "measures.wp.active * funding.f1.approved"}`; Register `funding_choice = "beg_zuschuss"` |
| XM6 | Bauteil `kessel: {measure_type: heizung_gaskessel, installed_year: 1998, replacement_cost_eur: 95000}`, Maßnahme `wp` mit `replaces_elements: [kessel]`, `completion_date: 2027-10-01` | `m_kessel_repl` mit `until_date = 2027-10-01`; Register-Eintrag `kessel` |
| XM7 | Neubau `cost_kg: {kg300: 1000000}` ohne `kg700_share` | `kg700_share = 0.20` (`entry = "costs/kostenzuschlaege_2026"`, `use: share_kg700_of_kg300_400`), `contingency_share = 0.10` und I `validation.measures.catalog_defaults` mit Nennung der Felder |
| XM8 | `measure_type: neubau` ohne Förderung, `project_type: sanierung_eh` | W `validation.measures.type_project_mismatch` (Neubau in Bestandsprojekt) |
| XM9 | Teil C S2: `ersatz_wp_2049: {measure_type: heizung_waermepumpe_luft, year: 2049, cost_eur: 160000, classification: erhaltung}`; `fenster_alt: {measure_type: fenster, …, ohnehin_share: 1}`; `fenster_neu: {measure_type: fenster, …, ohnehin_share: 1, modernization_kind: bgb_555b_1}` | `ersatz_wp_2049.modernization_kind = "none"`, `fenster_alt.modernization_kind = "none"` (`entry = "rule:measure_catalog"`), I `validation.measures.kind_from_classification`; `fenster_neu` behält `bgb_555b_1`, W `validation.measures.kind_ohnehin_conflict` (X-09) |
| XM10 | `neubau: {measure_type: neubau, cost_eur: 1000000, follows_construction: true}`, `nk: {measure_type: baunebenkosten, cost_eur: 200000}` | `measures.nk.useful_life_years = {ref: measures.neubau.useful_life_years}` (80), `measures.nk.replacement.enabled = false`; Komponente `m_nk_repl` mit `enabled = FALSE` (nur Wertpfad); ohne Hauptmaßnahme `{ref: residual_value.income_value.gnd_years}` (X-26) |
| XM11 | `payment_schedule: {schedule: {2027-07-01: 100000, 2028-07-01: {ref: shared.rate2}}, unit: eur}` mit `shared.rate2: 50000` | `measures.<m>.cost_eur = {expr: "100000 + shared.rate2"}` (Herkunft `rule:cost_from_kg`), Basisfallwert 150.000; Betrag als Kurzform-Verteilung → E `validation.measures.schedule_amount_form` (X-28) |
| XM12 | Maßnahmen- oder Bauteil-id mit 30 Zeichen (beliebiger Typ) | E (Nutzer-id > 29, N-23; bei Erwerbstypen zusätzlich erzeugte id `m_<m>_purchase` mit 41 > 40 Zeichen); Meldung nennt die Höchstlänge 29 |
| XM13 | Variante setzt `measures.wp.cost_factor: 1.2` (Pfad nur aus `item_defaults`) bzw. `measures.wp: {cost_factor: 1.2}` | erste Form E (Pfad existiert in Schicht 7 nicht, bis zur Entscheidung über S01A-10), zweite Form gültig (Map-Merge) |

### 4.6 Typ `capex` (WS-E, `R/type-flow-capex.R`)

Art `flow`, `grid_invariant = FALSE` (Einmalzahlungen; Monatsprofile werden über Termine abgebildet). Erzeugt vom
Maßnahmen-Expander als `m_<m>_capex` (Metafelder `measure_id = m`, `asset_id` nach 4.5.4); auch direkt in
`components` verwendbar.

#### 4.6.1 Parameter

| Parameter | `vofi_param`-Art | Default | Belegung durch den Expander | Bedeutung |
|---|---|---|---|---|
| `cost_eur` | `amount` | `NULL` | `{ref: measures.<m>.cost_eur}` | Grundkosten in Preisen von `price_base_year` |
| `cost_kg` | `map` (Blätter `amount`: `kg200` … `kg700`) | alle `0` | je Blatt `{ref: measures.<m>.cost_kg.kg<k>}` | Kosten je Kostengruppe |
| `kg700_share`, `contingency_share` | `share` | `0`, `0` | `{ref: …}` | Baunebenkosten- bzw. Risikozuschlag |
| `kg700_basis`, `contingency_basis` | `enum` | `kg300_400`, `kg200_700` | Wert | Bezugsbasen (4.1) |
| `cost_factor` | `number` | `1` | `{ref: measures.<m>.cost_factor}` | Kostenabweichungsfaktor |
| `cost_is_net` | `logical` | `FALSE` | Wert | Kosten netto angegeben |
| `vat_rate` | `share` | `0.19` | `{ref: measures.<m>.vat_rate}` | USt-Satz der Zeilen; gelesen als Basisfallwert `ctx$param_base()` (Zeilenmetadatum und Netto-Brutto-Umrechnung, Spec 00 §7.10), da die PV-Ableitung ein `expr` auf `energy.pv.kwp` ist (4.5.1 Nr. 5) |
| `price_base_year` | `integer` | `project.price_base_year` | Wert | Preisstand; Basisdatum b* = (Y+1)-01-01 (R-35) |
| `price_index` | `value` | `{ref: market.construction_price_index}` | `{ref: measures.<m>.price_index}` | Preisindexrate p. a. (Pfad) |
| `date` | `timing` | `NULL` | Wert (`year: Y` → Y-01-01) | Zahlungstermin bzw. Ende der Ausführung |
| `payment_schedule` | `schedule` | `NULL` | Wert (Termine) bzw. Bezüge auf die Beträge | Zahlungsplan `unit: share` oder `eur` |
| `duration_months` | `integer` | `0` | Wert | Ausführungsdauer D (ZPP, 0.3) |
| `payment_profile` | `enum` | `linear` | Wert | Profil P(x) |
| `completion_date` | `timing` | letzter Zahlungstermin | Wert | Fertigstellung |
| `delay_months` | `number` | `0` | `{ref: measures.<m>.delay_months}` | Verzug der Maßnahme (3.9) |
| `construction_delay_months` | `number` | `0` | `{ref: project.construction_delay_months}` | Bauzeitverzug des Projekts |
| `construction_delay_mode` | `enum` `none`, `last`, `stretch` | `none` | Wert (4.1) | Wirkung des Bauzeitverzugs auf die Zahlungen |
| `effect_start` | `enum` `completion`, `next_year` | `completion` | Wert | Wirkungsbeginn (`aux$in_operation`) |
| `active` | `value` | `1` | AF-Ausdruck a_m (4.5.2) | Aktivierungsfaktor |
| `classification` | `enum` | `auto` | Wert (Register) | steuerliche Einordnung → `tax_category` |
| `tax_category_kg200` | `enum` | `capex_depreciable` | Wert | Steuerkategorie der KG-200-Zeile (`capex_land` für Erschließungsbeiträge, Memo 06 §7.4) |
| `spread_years` | `integer` | `NULL` | `measures.<m>.tax_spread_years` | Zeilenfeld `spread_years` (nur `erhaltung`) |
| `ohnehin_share` | `share` | `NULL` | `{ref: …}` | nur Hilfsgrößen |
| `ohnehin_cost_eur` | `amount` | `NULL` | `{ref: …}` | nur Hilfsgrößen |

**Abgeleitetes `cost_eur` (Ableitungsregel `rule:cost_from_kg`, WS-A).** Ist `cost_kg` gesetzt, setzt WS-A
`measures.<m>.cost_eur` als `expr`-Knoten auf die Grundkosten vor `cost_factor` (Formel K⁰ in 4.6.2 (1)). Ist ein
Zahlungsplan mit `unit: eur` gesetzt, setzt WS-A `cost_eur` als `expr`-Summe der Beträge (X-28): Zahl → Literal; `ref`
→ Pfadsymbol, mit `scale`/`offset` als `(<scale> * <pfad> + <offset>)` und endlichem `floor`/`cap` über `pmax`/`pmin`;
`expr` → `(<text>)`; `quantity` → `(<x> * <Bezugspfad>)` mit dem Bezugspfad nach 3.5. Andere Formen (zeitabhängige
Pfade, Kurzform-Verteilungen) sind E `validation.measures.schedule_amount_form`. Herkunft `type_default`,
`entry = "rule:cost_from_kg"`. Damit lesen Teil B (§1.9.1, K⁰_k; Default des Förderkreditbetrags §4.6) und Kennzahlen
eine einheitliche Kostengröße. Das abgeleitete `cost_eur` ist **kein** Overlay- oder Designziel (Pfad-Identität, keine
stille Umlenkung; R-109, N-20; Antrag S01A-08 abgelehnt): Ein solches Ziel ist E `validation.measures.cost_derived` mit
Vorschlag `measures.<m>.cost_factor` (Kostenrisiko nach Teil C §1.9, `processes/cost_risks_2026`) bzw. der Blätter
`cost_kg.kg<k>`, `kg700_share`, `contingency_share` oder `project.construction_cost_factor`. Ein ausdrückliches
`cost_eur` neben `cost_kg` (z. B. als Override) ist E `validation.measures.cost_source`.
Der Expander verweist dann **nicht** auf `cost_eur`, sondern auf die Blätter.

#### 4.6.2 Algorithmus (MUSS, vektorisiert über n)

```text
b*  <- as.Date(sprintf("%d-01-01", price_base_year + 1))
I   <- ctx$index(ctx$param(spec, "price_index", "path"), base_date = b*)          # n x (T+1), Periodenende
# (1) Grundkosten K0 (n-Vektoren), Preisstand b*
mit cost_kg:  S_k  <- param("cost_kg.kg<k>"), k in {200,…,700}
              B700 <- S_300 + S_400 (kg300_400) bzw. S_200 + … + S_600 (kg200_600)
              K700 <- S_700 + kg700_share * B700
              Bc   <- S_200 + S_300 + S_400 + S_500 + S_600 + K700 (kg200_700) bzw. ohne K700 (kg200_600)
              KC   <- contingency_share * Bc
              K0   <- S_200 + … + S_600 + K700 + KC
mit cost_eur: K0 <- cost_eur;  KC <- contingency_share * cost_eur;  K0 <- K0 + KC
mit payment_schedule unit: eur:  K0 <- Σ_j Betrag_j (Beträge = Grundkosten je Termin)
# (2) brutto, Faktor, Aktivierung
g   <- (1 + vat_rate)^cost_is_net                                                # vat_rate: Basisfallwert (param_base)
K   <- K0 * g * cost_factor * active                                               # n-Vektor
# (3) Zahlungsplan (deterministisch): Termine d_j und Gewichte w_j (Σ w_j = 1)
date/year, D = 0:         d_1 = date, w_1 = 1
date/year, D > 0:         d_k = date - (D - k) Monate, w_k = P(k/D) - P((k-1)/D), k = 1…D   (ZPP, 0.3)
payment_schedule share:   (d_j, w_j) wie angegeben;  eur: w_j = Betrag_j / K0 (je Lauf)
# (4) Verschiebung je Lauf (ganze Monate, 3.9)
CD  <- construction_delay_months;  DM <- delay_months
c_j <- none: 0;  last: CD * [j == J];  stretch: CD * f_j,
       f_j = Monate(d_1 -> d_j) / Monate(d_1 -> d_J) (f_j = 1, wenn J = 1)
t_j <- ctx$shift_period(d_j, DM + c_j)                                             # NA jenseits des Horizonts
# (5) Buchung je Zeile r (Kostengruppen bzw. cost/contingency), Anteil q_r an K (Σ_r q_r = 1):
values_r[i, t_j[i] + 1] -= q_r * w_j * K[i] * I[i, t_j[i] + 1]                     # Index zum (verschobenen) Termin
# (6) Fertigstellung und Wirkungsbeginn
s_c <- DM + CD * [mode != none]
in_operation <- ctx$shift_overlap(completion_date, s_c) * active    (effect_start = completion)
             bzw. Überlappung ab dem 1. Januar nach dem verschobenen Fertigstellungsmonat (next_year)
```

- **Indexierung:** Jede Zahlung trägt den Preisstand zum Ende ihrer (verschobenen) Buchungsperiode (Spec 00 §3.9
  letzter Punkt, ZP in 0.3). Vor dem Stichtag liegende Preisstände (z. B. `price_base_year: 2024`) werden über den
  Vorlauf I_0 nach Spec 00 §3.6 hochgerechnet.
- **Nach dem Horizont** liegende Zahlungsteile entfallen (I `types.flow.capex.msg.after_horizon` mit Anteil der Läufe).
- **Kostenaufteilung q_r:** mit `cost_kg` je Kostengruppe q_k = S_k/K0 (KG 700 einschließlich Zuschlag K700); der
  Risikozuschlag ist eine eigene Zeile `contingency` (q = KC/K0). Ohne `cost_kg` eine Zeile `cost` und ggf.
  `contingency`.

#### 4.6.3 Zeilen

| lokale Zeile | section / category | tax_category | cash | asset / measure | vat_rate |
|---|---|---|---|---|---|
| `cost` | project / `capex` | `classification`: `erhaltung` → `capex_expensable`; `herstellung`, `auto` → `capex_depreciable` | T | `asset_id`, `measure_id` | `vat_rate` |
| `cost_kg200` … `cost_kg700` (Muster `cost_kg*`) | project / `capex` | wie `cost`; `cost_kg200`: `tax_category_kg200` | T | dto. | dto. |
| `contingency` | project / `capex` | wie `cost` | T | dto. | dto. |

Zeilen der Kostengruppen entstehen nur für gesetzte Kostengruppen (Schlüssel vorhanden); Zeilenfeld `spread_years`
bei `erhaltung`. Bei `classification: auto` entscheidet das Steuermodul über das Register (15-%-Grenze,
Memo 06 §7.5); `tax_none` ignoriert die Einordnung.

#### 4.6.4 Hilfsgrößen (`aux`, je n × (T+1))

| Name | Inhalt |
|---|---|
| `cost_total` | −Σ aller Zeilen (positive Bruttozahlungen nominal je Periode) |
| `cost_base` | `by_sim(K)` (Grundkosten brutto × `cost_factor` × a_m im Preisstand b*, ohne Index) |
| `cost_kg<k>` | Zahlungen der Kostengruppe k einschließlich anteiligem Risikozuschlag (q_k + q_C · S_k/Bc) für den Sachwert-Filter (6.3.6) |
| `ohnehin_base` | `by_sim(o)`: `ohnehin_cost_eur · g · active` bzw. `ohnehin_share · K` (Preisstand b*) |
| `modernization_base` | `cost_base − ohnehin_base` („energiebedingte Mehrkosten“, Konzept 2.6) |
| `in_operation` | Monatsanteil je Periode ab Wirkungsbeginn (0…1) × a_m |
| `completion_shift` | `by_sim(s_c)` (Monate) |

Abhängige Komponenten (Ersatz, Instandhaltung, Restwert, Teil B) lesen diese Größen über `ctx$component()`; der
Erzeuger setzt `after`.

#### 4.6.5 Validierung und Randfälle

| Bedingung | Klasse, Schlüssel |
|---|---|
| nicht genau eines von `date`/`year`/`payment_schedule` | E `validation.measures.timing` |
| nicht genau eine Kostenquelle (4.1) | E `validation.measures.cost_source` |
| `payment_schedule` `share` mit Σ ≠ 1 (> 1e-9) | E `validation.measures.schedule_sum` |
| Termin bzw. Ausführungsbeginn vor `valuation_date` | E `validation.measures.before_valuation` (Bestandskosten gehören nicht in die Investition) |
| `completion_date` vor dem ersten Zahlungstermin | E `validation.measures.completion_order` |
| `kg: 800` oder Schlüssel `cost_kg.kg800` | E `validation.measures.kg800` („Finanzierungskosten berechnet das Finanzierungsmodul“) |
| `kg700_share > 0` und `cost_kg.kg700 > 0` | W `validation.measures.kg700_double` |
| Overlay auf `contingency_share` und auf `cost_factor` bzw. `cost_eur` derselben Maßnahme | W `validation.measures.cost_risk_double` (Teil C, Konzept 3.2) |
| Overlay- oder Designziel auf ein abgeleitetes `cost_eur` (`cost_kg` bzw. Zahlungsplan `eur`) | E `validation.measures.cost_derived` mit Vorschlag `cost_factor` (R-109, N-20) |
| `vat_recoverable: true` | E (Spec 00 §7.10) |
| `active` ∉ {0, 1} im Basisfall | W `validation.measures.active_fraction` |
| alle Zahlungen eines Laufs jenseits des Horizonts | I `types.flow.capex.msg.after_horizon` (Anteil der Läufe) |
| `delay_months` stochastisch und Kredit mit `measure_id = m` | W „Kredittermine bleiben fest“ (Spec 00 §3.9) |

#### 4.6.6 Tests (WS-E, `test-type-flow-capex.R`; Werte mit `vref.py` gerechnet)

Raster `annual` = Stichtag 2027-01-01, H = 25 (bzw. 30), C = 0; `G4` = Spec 00 §3.8 (monatliche Bauphase 9 Monate).

| Nr. | Fall | Erwartung |
|---|---|---|
| C1 | `year: 2030`, `cost_eur: 32000`, `price_base_year: 2026`, `price_index: 0.03`, annual | t = 3; `cost[,4] = −34.967,26` (32.000 · 1,03³) |
| C2 | Memo 07 S1 V2: `cost_kg: {kg300: 799500, kg400: 372000}`, `kg700_share: 0.18`, `contingency_share: 0.05`, `price_index: 0` | K700 = 210.870,00; KC = 69.118,50; K = 1.451.488,50; abgeleitetes `cost_eur` = 1.451.488,50; `aux$cost_kg300` (Summe) = 839.475,00, `cost_kg400` = 390.600,00, `cost_kg700` = 221.413,50; V1 (478.000, 0,15, 0,05) = 577.185,00; Differenz V2 − V1 = 874.303,50 |
| C3 | G4, `date: 2027-10-01`, `duration_months: 9`, `payment_profile: s_curve`, `cost_eur: 900000`, `price_index: 0.04`, b* = Stichtag | t = 1…9: −30.965,24; −83.258,52; −120.933,06; −143.843,62; −151.843,98; −144.786,97; −122.524,47; −84.907,36; −31.785,57; Σ −914.848,79; `linear`: t = 1 −100.327,37, t = 9 −102.985,24, Σ −914.861,18 |
| C4 | wie C1, `delay_months` = 0 bzw. 14 (zwei Läufe) | Lauf 1: t = 3, −34.967,26; Lauf 2: Termin 2031-03-01, t = 5, −37.096,77 |
| C4b | `payment_schedule: {2027-07-01: 0.4, 2028-07-01: 0.6}`, `stretch`, `construction_delay_months` 6 bzw. 7 | 1. Zahlung unverändert t = 1; 2. Zahlung 2029-01-01 → t = 2 (6 Monate) bzw. 2029-02-01 → t = 3 (7 Monate) |
| C5 | `cost_eur: 100000`, `cost_is_net: true`, `vat_rate: 0.19`, `price_index: 0` | Zeile −119.000; netto über Spec 00 §7.10 = 100.000, USt 19.000 |
| C6 | C1 mit `active: 0` | alle Zeilen 0; `aux$in_operation` ≡ 0; Ledger enthält die Zeile (stabil) |
| C7 | G4, `completion_date: 2027-10-01`, `construction_delay_mode: stretch`, `construction_delay_months` 0 bzw. 2 | `aux$in_operation[, 10:12]` = (0; 1; 1) bzw. (0; 0,3333; 1) (Spalten t = 9, 10, 11) |
| C8 | `price_base_year: 2024`, `date: 2027-07-01`, `cost_eur: 100000`, `price_index: {ref: market.construction_price_index}` (global.yaml: 2026 0,05 mit `before: first`, 2027 0,035) | I_0 = 1,05² = 1,1025; t = 1: −114.108,75 |
| C9 | Expander-Bezugstest: Schicht 8 `measures.wp.cost_eur` 130.000 | Knoten unverändert (`ref`); Zeile = −130.000 · Index |

### 4.7 Typ `land` (WS-E, `R/type-flow-land.R`)

Kaufpreis eines Erwerbs (Maßnahmentyp `erwerb_grundstueck`, `erwerb_objekt`) als `m_<m>_purchase`.

| Parameter | Art | Default | Expander | Bedeutung |
|---|---|---|---|---|
| `purchase_price_eur` | `amount` | Pflicht | `{ref: measures.<m>.purchase_price_eur}` | Kaufpreis (nominal, Vertragspreis, nicht indexiert) |
| `land_share` | `share` | `1` | `{ref: measures.<m>.land_share}` | Bodenanteil |
| `date` | `timing` | Pflicht | Wert | Zahlungstermin (Besitzübergang) |
| `delay_months` | `number` | `0` | `{ref: measures.<m>.delay_months}` | Verschiebung |
| `active` | `value` | `1` | a_m | Aktivierung |
| `land_asset_id`, `building_asset_id` | `string` | `<bid>_land`, `<bid>_building` | Wert | Anlagenzuordnung |

Algorithmus: t = `ctx$shift_period(date, delay_months)`; `price_land[t] = −P · s · a`; `price_building[t] = −P ·
(1 − s) · a` (beide Zeilen immer vorhanden, ggf. null).

| lokale Zeile | section / category | tax_category | asset | measure | vat |
|---|---|---|---|---|---|
| `price_land` | project / `land` | `capex_land` | `land_asset_id` | `m` | 0 |
| `price_building` | project / `capex` | `capex_depreciable` | `building_asset_id` | `m` | 0 |

Validierung: Termin vor dem Stichtag E (`validation.measures.before_valuation`); `land_share` ∉ [0, 1] E;
`erwerb_objekt` mit `land_share` = 0 oder 1 W („Kaufpreisaufteilung prüfen“, BMF-Arbeitshilfe); Erwerb bei
`project_type` ∉ {`erwerb_sanierung`, `erwerb_neubau`, `neubau`} W `validation.measures.type_project_mismatch`.

### 4.8 Typ `acquisition_cost` (WS-E, `R/type-flow-acquisition-cost.R`) und Regel `grest`

Erwerbsnebenkosten als `m_<m>_acq`.

| Parameter | Art | Default | Expander | Bedeutung |
|---|---|---|---|---|
| `basis_eur` | `amount` | Pflicht | `{ref: measures.<m>.purchase_price_eur}` | Gegenleistung (Kaufpreis) |
| `land_share` | `share` | `1` | `{ref: measures.<m>.land_share}` | Aufteilung Boden/Gebäude |
| `uniform_contract` | `logical` | `FALSE` | Wert | einheitlicher Vertragsgegenstand |
| `construction_basis_eur` | `amount` (Basisfallwert) | `0` | `{expr: "measures.<k1>.cost_eur + …"}` über `uniform_contract_measures` | vereinbarte Bauleistung; gelesen mit `ctx$param_base()` (Vertragspreis bei Erwerb, spätere Kostenabweichungen ändern die GrESt nicht; Spec 00 §6.3) |
| `federal_state` | `string` | `project.federal_state` | Wert | Land |
| `grest_rate` | `rate` | `NULL` | `{ref: measures.<m>.grest_rate}` | ausdrücklicher Satz (an `grest()` als `rate`, sonst `NA`) |
| `notary_share`, `land_registry_share`, `broker_share`, `other_share` | `share` | `0.010`, `0.005`, `0`, `0` | `{ref: …}` | Anteile an `basis_eur` |
| `notary_vat_rate`, `broker_vat_rate`, `other_vat_rate` | `share` | `0.19` | Wert | enthaltene USt (Grundbuch und GrESt: 0) |
| `date` | `timing` | Pflicht | `ancillary_date` | Fälligkeit |
| `delay_months` | `number` | `0` | `{ref: measures.<m>.delay_months}` | Verschiebung |
| `active` | `value` | `1` | a_m | Aktivierung |
| `land_asset_id`, `building_asset_id` | `string` | wie 4.7 | Wert | Zuordnung |

**Regel `grest`** (`R/rules-grest.R`, WS-E, Version `@2025-07-01`, gewählt nach `project.legal_state`; Signatur
nach N-19, Regelkonvention Spec 00 §5.3):

```r
grest(basis_eur, federal_state, rate, P)   # returns = "sim"; keine Defaults, liest kein ctx (R-93)
#  basis_eur      n-Vektor: Gegenleistung (Kaufpreis + Bauleistung)
#  federal_state  chr(1): Code nach enum:federal_state
#  rate           n-Vektor oder NA: ausdrücklicher Satz (grest_rate)
#  P              Nutzlast des Themas grunderwerbsteuer, vom Typ übergeben: ctx$legal("grunderwerbsteuer")
#  rate_used <- ifelse(is.na(rate), P$rates[[federal_state]], rate)
#  -> n-Vektor: rate_used * basis_eur * (basis_eur > P$exemption_threshold_eur)   # Freigrenze § 3 Nr. 1 GrEStG
```

Algorithmus: t = `ctx$shift_period(date, delay_months)`; KP = `basis_eur`, s = `land_share`, C =
`param_base("construction_basis_eur")` · [`uniform_contract`]; GrESt gesamt G = `ctx$rule("grest")(KP + C,
federal_state, grest_rate bzw. NA, ctx$legal("grunderwerbsteuer"))`, Aufteilung `grest_land = −G · KP·s/(KP + C)`,
`grest_building = −G · (KP·(1−s) + C)/(KP + C)`; übrige Positionen x ∈ {notary, registry, broker, other}:
`x_land = −share_x · KP · s`, `x_building = −share_x · KP · (1 − s)`; alle × a_m.

| lokale Zeile | category | tax_category | is_tax | vat_rate | asset |
|---|---|---|---|---|---|
| `grest_land`, `grest_building` | `acquisition_cost` | `acquisition_ancillary` | `grunderwerbsteuer` | 0 | Boden bzw. Gebäude |
| `notary_land`, `notary_building` | `acquisition_cost` | `acquisition_ancillary` | – | `notary_vat_rate` | dto. |
| `registry_land`, `registry_building` | `acquisition_cost` | `acquisition_ancillary` | – | 0 | dto. |
| `broker_land`, `broker_building` | `acquisition_cost` | `acquisition_ancillary` | – | `broker_vat_rate` | dto. |
| `other_land`, `other_building` | `acquisition_cost` | `acquisition_ancillary` | – | `other_vat_rate` | dto. |

Alle Zeilen `measure_id = m`, Abschnitt `project`, `cash = TRUE`. Validierung: GrESt fällig (KP + C > 2.500) ohne
`federal_state` und ohne `grest_rate` → E `validation.acquisition.federal_state_missing`; Thema `grunderwerbsteuer`
inaktiv (kein freigegebener Eintrag, Spec 00 §4.10, R-80) und kein `grest_rate` → E
`validation.acquisition.grest_inactive` (Vorschlag `grest_rate` oder Freigabe von `legal/grunderwerbsteuer_2026`);
`grest_rate` ≠ Landessatz → W; `uniform_contract` ohne Bauleistung → W.

**Tests (WS-E, `test-type-flow-acquisition-cost.R`; Regel `grest` in `test-rules-grest.R`).**

| Nr. | Fall | Erwartung |
|---|---|---|
| A1 | Grundstück 840.000, NW (6,5 %), `land_share: 1`, Default-Anteile | GrESt −54.600; Notar −8.400; Grundbuch −4.200; mit Kaufpreis −907.200 |
| A2 | `erwerb_objekt` 1.200.000, `land_share: 0.25`, BY (3,5 %), `broker_share: 0.0357` | GrESt 42.000 (Boden 10.500 / Gebäude 31.500); Notar 12.000 (3.000 / 9.000); Grundbuch 6.000 (1.500 / 4.500); Makler 42.840 (10.710 / 32.130); Σ 102.840 |
| A3 | Basis 2.400 bzw. 2.600, NW | GrESt 0 bzw. −169,00 |
| A4 | Grundstück 200.000 + Bauleistung 1.000.000, `uniform_contract: true`, NW | GrESt −78.000 (Boden 13.000 / Gebäude 65.000) |
| A5 | wie A4, Lauf mit `measures.<k>.cost_factor` 1,2 | GrESt unverändert −78.000 (Basisfallwert) |
| A6 | `project.federal_state` fehlt, Basis 300.000 | E `validation.acquisition.federal_state_missing` |

### 4.9 Bestandswert als Sacheinlage (`building.existing_value_eur`; Engine, Spec 00 §9.3, §9.5 Nr. 7)

Die Sacheinlage ist **keine Komponente**; die Engine bucht sie aus dem Basisfallwert (`ctx$value_base()`), in allen
Läufen gleich. Teil A legt Semantik, Konsistenzregeln und Prüfungen fest.

1. **Bedeutung:** Verkehrswert des Bestands **vor** den Maßnahmen zum Stichtag (Opportunität „heute verkaufen“,
   Konzept 2.6). Er ist identisch in allen Gebäudevarianten einer Bewertung (Validierung Ebene 3: Varianten dürfen
   `building.existing_value_eur` nicht ändern, E `validation.variants.existing_value_changed`; Szenario-Sets dürfen
   es per Konstruktion nicht).
2. **Zeilen:** Engine `equity_in_kind` (t = 0, W_0 − Σ B_0 der Bestandsdarlehen), Unterlassung `opp_in_kind_sale`
   = W_0 · (1 − `residual_value.sale_cost_share`) − Σ B_0 (Spec 00 §9.5 Nr. 7); Bestandsdarlehen: 5.3.
3. **Zulässigkeit:** Bestandsprojekte (`sanierung_*`, `heizungstausch`) und `neubau` auf eigenem Grundstück (dann
   Grundstückswert als Sacheinlage, I `validation.building.in_kind_land`). Bei `erwerb_*` → E
   `validation.building.existing_value_with_purchase` (Kaufpreis und Sacheinlage doppelt).
4. **Restwert-Konsistenz:** Die Restwertmethoden bewerten am Horizont das **ganze Objekt** (Bestand + Maßnahmen);
   Sacheinlage in t = 0 und Restwert in T beziehen sich damit auf dieselbe Sache. `market_growth` verwendet W_0 als
   Ausgangswert (6.3.4), `component` mit `include_existing: auto` schreibt W_0 als Bestandskomponente fort (6.3.7).
   Ohne Bestandswert enthält der Restwert den Bestand trotzdem; ΔEW gegenüber der Unterlassung enthält ihn dann, und
   nur `delta_vs_reference` ist lesbar (Spec 00 §12.3a).
5. **Prüfungen:** Bestandsprojekt ohne Bestandswert → I `validation.building.no_existing_value` („absolute
   EK-Rendite nicht definiert, Primärkennzahl gegenüber Referenz“); W_0 < Σ B_0 → W `validation.building.negative_in_kind`
   (negative Sacheinlage: Bestand überschuldet); Overlay-Ziel auf `building.existing_value_eur` → W („wirkt nur über
   `market_growth`/`component`; die Sacheinlage bleibt Basisfallwert“).

**Tests.** Pflichtprüffall Spec 00 §9.5 („Sacheinlage“, 300.000 / 285.000 / ΔEW 28.000) unverändert; zusätzlich X1:
W_0 = 2.000.000, Bestandsdarlehen 400.000, `sale_cost_share: 0.03` → `equity_in_kind[,1] = 1.600.000`,
`opp_in_kind_sale = 1.540.000`; X2: `erwerb_sanierung` mit `existing_value_eur` → E
`validation.building.existing_value_with_purchase`.

### 4.10 Typ `replacement` (WS-E, `R/type-flow-replacement.R`)

Ersatzinvestitionen im Nutzungsdauerzyklus einer Maßnahme (`m_<m>_repl`, `include_initial = TRUE`) bzw. eines
Bestandsbauteils (`m_<e>_repl`, `include_initial = FALSE`). Liefert zusätzlich den Zeitwertpfad für den Restwert.

#### 4.10.1 Parameter

| Parameter | Art | Default | Bedeutung |
|---|---|---|---|
| `capex_id` | `ref` (id) | `NULL` | zugehörige `capex`-Komponente (Erstinvestition, Kostenbasis) |
| `enabled` | `logical` | `TRUE` | Ersatzzahlungen erzeugen; `FALSE`: nur Zeitwertpfad der Erstinvestition (`aux`) |
| `cost_eur` | `amount` | `NULL` = `aux$cost_base` von `capex_id` × `cost_factor` | Ersatzkosten im Preisstand b* |
| `cost_factor` | `number` | `1` | Faktor auf die Erstkosten (`measures.<m>.replacement.cost_factor`) |
| `price_base_year`, `price_index` | `integer`, `value` | wie `capex` | Preisstand und Preisindex |
| `vat_rate` | `share` | `0.19` | USt |
| `install_date` | `timing` | Pflicht | Einbau bzw. Fertigstellung der Erstinvestition |
| `install_shift_months` | `number` | `0` | laufspezifische Verschiebung des Einbaus (Expander: `{expr: "measures.<m>.delay_months + project.construction_delay_months"}` bzw. ohne Bauzeitverzug bei `construction_delay_mode: none`) |
| `useful_life_years` | `number` | Pflicht | Nutzungsdauer L (stochastisch zulässig) |
| `first_date` | `timing` | `NULL` = Einbau + L | erster Ersatztermin (Bauteil: `next_replacement`) |
| `first_shift_months` | `number` | `0` | Verschiebung des ersten Ersatztermins (`next_replacement_delay_months`) |
| `until_date`, `until_shift_months` | `timing`, `number` | `NULL`, `0` | Ende des Zyklus (Ersatz durch eine Maßnahme, 4.5.2 Nr. 3) |
| `include_initial` | `logical` | `TRUE` | Wertpfad beginnt mit der Erstinvestition von `capex_id` |
| `overdue` | `enum` `first_period`, `valuation`, `skip` | `first_period` | Behandlung eines vor dem Stichtag fälligen Ersatzes |
| `classification` | `enum` | `erhaltung` | Steuerkategorie der Zeile |
| `active` | `value` | `1` | Aktivierung (bei `cost_eur = NULL` bereits in `cost_base` enthalten und nicht erneut angewendet) |

#### 4.10.2 Algorithmus (MUSS)

```text
L   <- floor(12 * useful_life_years + 0.5)  (n-Vektor, Monate, >= 1)
s0  <- install_shift_months (gerundet);  d0 <- install_date
d1, s1 <- first_date, first_shift_months   falls gesetzt;  sonst d1 <- d0, s1 <- s0 + L
Ersatztermin k (k = 1, 2, …):  e_k = d1 + (s1 + (k - 1) * L) Monate                        # je Lauf
overdue (nur include_initial = FALSE und e_1 <= valuation_date):
   first_period: e_1 <- date_end[1]; e_k <- e_1 + (k-1) L      valuation: e_1 <- valuation_date (t = 0)
   skip:         erstes k mit e_k > valuation_date
Abbruch:  e_k >= until_date + until_shift_months  oder  e_k > end_date
t_k <- ctx$shift_period(d1, s1 + (k - 1) * L) bzw. die Periode des überfälligen Termins
cost[i, t_k + 1] -= C[i] * I[i, t_k + 1]          C = cost_eur (× active) bzw. cost_base(capex) × cost_factor
K_max je Chunk = ceiling(12 * H / min_i L_i) + 1  (Schleife über k, vektorisiert über i; Ergebnis je Lauf unabhängig
                                                   von K_max, daher batch-invariant)
```

**Zeitwertpfad (`aux`):** Mit der letzten Investition vor bzw. in t (Betrag C_last nominal, Periode t_last, Termin
e_last) und dem Alter α_t = Monate(e_last → b_t)/12 (b_t = Periodenende):

```text
value_nominal_t = C_last * max(0, 1 - α_t / L)                                  # nominaler Buchwert (R-108)
value_t         = C_last * I_t / I_{t_last} * max(0, 1 - α_t / L)                # indexiert (Konzept 3.11)
```

Vor der ersten Investition: `include_initial = TRUE` → 0 bis zur Fertigstellung, dann C_0 = Σ `aux$cost_total` der
Erstinvestition mit e_0 = verschobene Fertigstellung; `include_initial = FALSE` → C_0 = C · I_0 (Wiederbeschaffungswert
zum Stichtag) mit e_0 = Einbaudatum (`installed_year`-01-01). Nach `until_date` ist der Wertpfad null (ersetzt).
Zusätzlich `aux$age_years` (α_t) und `aux$life_months` (`by_sim(L)`).

| lokale Zeile | section / category | tax_category | asset / measure | vat |
|---|---|---|---|---|
| `cost` | project / `replacement` | `erhaltung` → `capex_expensable`, sonst `capex_depreciable` | `asset_id`, `measure_id` (Maßnahme bzw. Bauteil-id) | `vat_rate` |

Validierung: L ≤ 0 E; `first_date` vor `install_date` E; `install_shift_months`, `first_shift_months` oder
`until_shift_months` < 0 E (Spec 00 §3.9, R-105); L < 5 Jahre W; mehr als 10 Ersatztermine im Horizont W; Bauteil ohne
`replacement_cost_eur` E `validation.building.element_cost_missing`; `include_initial = TRUE` ohne `capex_id` E.

#### 4.10.3 Tests (WS-E, `test-type-flow-replacement.R`)

Jahresraster ab 2027-01-01, H = 30 (`end_date` 2057-01-01), Preisindex 3 %, b* = Stichtag.

| Nr. | Fall | Erwartung |
|---|---|---|
| R1 | WP 126.000, Fertigstellung 2027-10-01, L = 18, `include_initial` | Erstinvestition t = 1 (C_0 = 129.780,00); Ersatz 2045-10-01 → t = 19, −220.941,76; zweiter Ersatz 2063 außerhalb; `value`: V_0 = 0; V_1 = 127.977,50; V_18 = 8.937,77; V_19 = 217.873,13; V_30 = 114.688,15 (= 126.000 · 1,03³⁰ · 0,375) |
| R2 | R1 mit L = 15,5 (Lauf 2) | Ersatz 2043-04-01 → t = 17, −208.258,80; V_30 = 34.529,77 (Alter 13,75) |
| R3 | Bauteil Kessel, `installed_year: 1998`, L = 18, 95.000, `overdue: first_period` | t = 1: −97.850,00; nächster Ersatz 2046-01-01 → t = 19, −166.583,08; danach 2064 außerhalb |
| R4 | R3 mit Maßnahme WP `replaces_elements: [kessel]`, Fertigstellung 2027-10-01 | `until_date` 2027-10-01 < 2028-01-01: keine Zeile ≠ 0; Wertpfad ab t = 1 null |
| R5 | R4 mit a_WP = 0 (Lauf) | Zyklus des Kessels läuft wie R3 (4.5.2 Nr. 3) |
| R6 | R1, Batch: Läufe mit L ∈ {15,5; 18} in Chunks der Größe 1 und 2 | identische Zeilen je Lauf (Spec 00 §15.5) |

### 4.11 Typ `maintenance` (WS-E, `R/type-flow-maintenance.R`)

Laufende Instandhaltung als Pauschale je m² (`basis: rate`, ImmoWertV Anlage 3), nach II. BV mit Altersklassen
(`basis: iibv`) oder bauteilbezogen in % der Investition (`basis: share_of_cost`, Instandsetzung nach VDI 2067 ohne
Wartung, X-10). Komponenten:
`m_maintenance` (Gebäude, aus `building.maintenance`, 3.3) und `m_<m>_maint` (je Maßnahme mit
`effects.maintenance.share_of_cost_pa`).

#### 4.11.1 Parameter

| Parameter | Art | Default | Bedeutung |
|---|---|---|---|
| `basis` | `enum` `rate`, `iibv`, `share_of_cost` | `rate` | Bemessung |
| `rate_eur_m2_pa` | `amount` | Pflicht bei `rate` | Satz je m² und Jahr im Preisstand b* |
| `area_m2` | `number` | Pflicht bei `rate`/`iibv` | Bezugsfläche (`{ref: building.living_area_m2}`) |
| `iibv_rates` | `map` (`lt22y`, `ge22y`, `ge32y`; `amount`) | Pflicht bei `iibv` | Sätze nach Bezugsfertigkeit (II. BV § 28 Abs. 2) |
| `iibv_adjust_eur_m2_pa` | `amount` | `0` | Zu-/Abschläge (Aufzug +1,63; Kleinreparaturen −1,70; Wärmelieferung −0,31) |
| `reference_year` | `integer` | `building.first_occupancy_year` | Jahr der Bezugsfertigkeit |
| `reset_capex_ids` | `ids` | `[]` | `capex`-Komponenten, deren Fertigstellung das Alter zurücksetzt |
| `share_pa` | `share` | Pflicht bei `share_of_cost` | Anteil der Investition je Jahr |
| `capex_id` | `ref` (id) | Pflicht bei `share_of_cost` | Investition (Kostenbasis `aux$cost_base`, Beginn `aux$in_operation`) |
| `factors` | `map` id → `value` | `{}` | Faktor je wirkender Maßnahme (`{ref: measures.<m>.effects.maintenance.factor}`), Schlüssel = `capex`-Komponente |
| `factor_years` | `map` id → `number` | `{}` | Wirkungsdauer je Faktor (Jahre; fehlt = bis Horizont) |
| `price_base_year`, `growth` | `integer`, `value` | `project.price_base_year`, `{ref: market.maintenance_index}` | Preisstand, Fortschreibung (Kalenderjahresindex) |
| `from`, `to` | `timing` | Expander nach `building.maintenance.from: auto` (3.3), `end_date` | Laufzeit |
| `vat_rate` | `share` | `0.19` | USt |
| `tax_category` | `enum` | `expense_deductible` (`selbstnutzer`: `expense_nondeductible`) | Steuerkategorie |

#### 4.11.2 Algorithmus (MUSS)

```text
b*   <- (price_base_year + 1)-01-01
IY   <- ctx$index_year(ctx$param(spec, "growth", "path"), base_date = b*)                  # R-62
ω    <- ctx$shift_overlap(from$date, from$shift, to$date)                                  # ctx$timing()
rate:           r_t <- rate_eur_m2_pa
iibv:           ref_i <- reference_year bzw. max_{c in reset_capex_ids} (Jahr(verschobene Fertigstellung_c - 1 Tag))
                         nur in Läufen mit a_c = 1 und Fertigstellung vor b_t (je Spalte t)
                age_t <- year[t] - ref_i
                r_t   <- iibv_rates.lt22y (age < 22) | ge22y (22 <= age < 32) | ge32y (age >= 32); + iibv_adjust
share_of_cost:  A_t <- share_pa * cost_base(capex_id) * in_operation(capex_id)            # ohne area
F_t  <- Π_c (1 + (factors[c] - 1) * in_operation_c,t * [Jahre seit Beginn_c < factor_years[c]])
cost <- −(r_t * area_m2 bzw. A_t) * IY_t * Δ_t * ω_t * F_t
```

- Der Satz ist ein **Jahresbetrag** des Preisstands b*; ein Wert „für das Jahr 2026“ (z. B. 14,40 €/m² laut
  Anlage 3 für 2026) hat `price_base_year: 2026` (Preisstand Jahresende 2026 = 2027-01-01, Spec 00 §3.6
  `grid_index_year`). Innerhalb eines Kalenderjahres ist der Index konstant (F10).
- `from: completion` (Neubau) beginnt mit der Fertigstellung einschließlich Bauzeitverzug; in Bestandsprojekten setzt
  der Expander `from` = Stichtag.

| lokale Zeile | section / category | tax_category | vat | noi/burden |
|---|---|---|---|---|
| `cost` | project / `maintenance` | Parameter `tax_category` | `vat_rate` | ja / ja (Spec 00 §7.6) |

#### 4.11.3 Steuerkategorie

Vermieter: `expense_deductible` (sofort abziehbar, Memo 06 §3.1.1); Selbstnutzer: `expense_nondeductible`
(Ableitung im Expander nach `project.perspective`); `capex_expensable` nur durch ausdrückliche Angabe (größere
Erhaltungsmaßnahme als laufende Pauschale, selten).

#### 4.11.4 Doppelzählung Pauschale – Ersatz – Wartung (Validierung Ebene 3)

| Kombination | Befund |
|---|---|
| `building.maintenance.basis ∈ {rate, iibv}`, Pauschale > 0, `excludes_explicit_replacements = false` und im Horizont (Basisfall) mindestens ein Ersatzereignis (`replacement`-Komponente mit `enabled`, aus Maßnahmen oder Bestandsbauteilen) **oder** eine Erhaltungsmaßnahme (`classification: erhaltung` bzw. Ohnehin-Anteil 1, z. B. Dach-Neueindeckung, Anstrich, Kesseltausch als Ohnehin-Maßnahme) | W `validation.maintenance.double_count` („Die Pauschale enthält die Erneuerung von Bauteilen; explizite Ersatz- und Instandsetzungsmaßnahmen zusätzlich führen zu Doppelzählung. Satz mindern und `excludes_explicit_replacements: true` setzen oder Ersatz abschalten.“; F-21) |
| `excludes_explicit_replacements = true` | I `validation.maintenance.replacements_excluded` mit dem Kennwert k = Σ_e C_e / (H · `area_m2`) der expliziten Ersatz- und Erhaltungszahlungen im Horizont (Basisfall, Preisstand b*, ohne Index; €/m²·a) neben dem angesetzten Satz („Ist der Satz um die explizit modellierten Erneuerungen gemindert?“). Keine automatische Minderung: sie wäre eine aus overlay-fähigen Blättern berechnete Konstante (Spec 00 §4.12 Nr. 5; F-21) |
| Satz bzw. Sätze der Pauschale stammen nur aus den Defaults (`rate_eur_m2_pa` bzw. `iibv.rates_eur_m2_pa` mit Herkunft `global`/Bibliothek über `item_defaults`) | I `validation.maintenance.default_rate` („Instandhaltungspauschale nach ImmoWertV Anl. 3 bzw. II. BV aus `global.yaml` angesetzt; projektbezogenen Satz angeben“; F-21) |
| Pauschale > 0 und `m_<m>_maint` (`share_of_cost`) derselben Anlage ohne Bestätigung | W `validation.maintenance.service_double` |
| `m_<m>_maint` und m ist `measure` eines Energiezustands mit `service_eur_pa` > 0 bzw. `energy.pv.measure` mit `opex_share_of_cost` > 0 oder `opex_eur_pa` > 0 (Teil B) | W `validation.maintenance.service_double_energy` („Wartung doppelt: `share_of_cost_pa` umfasst nur die Instandsetzung; Wartung steht im Energiezustand bzw. PV-Betrieb“; X-10) |
| Instandhaltungsersparnis über `effects.maintenance.factor < 1` und zugleich ein mietrechtlicher Erhaltungsanteil (Teil B) | keine Doppelzählung (verschiedene Größen), kein Befund |
| Restwert `income_value` mit `bwk.maintenance_source: ledger` | Restwert verwendet die Ledger-Instandhaltung (6.3.3), kein Befund |

#### 4.11.5 Tests (WS-E, `test-type-flow-maintenance.R`; M8 WS-A `test-scenario-layers.R`)

| Nr. | Fall | Erwartung |
|---|---|---|
| M1 | 14,40 €/m² × 1.600 m², `price_base_year: 2026`, Wachstum 2027 4 %, ab 2028 3 %, annual | 2027 −23.961,60; 2028 −24.680,45; 2029 −25.420,86 |
| M2 | M1 auf G4, `from` = Fertigstellung 2027-10-01 | t = 9: 0; t = 10 (3 Monate): −5.990,40; t = 11: −24.680,45; Summe 2027 = 23.961,60 · 3/12 |
| M3 | `iibv`, Bezug 2004, 1.000 m², Wachstum 0, Reset durch Maßnahme mit Fertigstellung 2030-01-01 | 2027–2029: −14.580; 2030–2050: −11.500; 2051: −14.580; ohne Reset: 2036 Wechsel auf −18.620 |
| M4 | `share_of_cost`, WP 32.000, `share_pa: 0.010` (Instandsetzung nach Katalog 4.2), ab Fertigstellung | −320 je vollem Jahr (Preisstand) |
| M5 | 14,40 × 1.000, Wachstum 0, Maßnahme mit `effects.maintenance.factor: 0.694444` (Memo 07 S1 V2: 10/14,40), Fertigstellung 2030-01-01 | bis 2029 −14.400; ab 2030 −10.000,00 |
| M6 | Pauschale + Bauteil-Ersatz ohne Bestätigung | W `validation.maintenance.double_count` |
| M7 | 14,40 × 1.000 m², `excludes_explicit_replacements: true`, H = 30, zwei Ersatzereignisse je 60.000 (Preisstand b*) | I `validation.maintenance.replacements_excluded` mit Kennwert 4,00 €/m²·a (120.000 / (30 · 1.000)) |
| M8 | `neubau`, C = 24 (Fertigstellung 2029-01-01), H = 40, `building: {living_area_m2: 1000, maintenance: {growth: 0}}` ohne `basis`/`rate_eur_m2_pa` | `basis = "iibv"` (Herkunft `rule:maintenance_from`), Bezugsfertigkeit 2028 (`rule:first_occupancy`); 2027–2028: 0; 2029–2049: −11.500; 2050–2059: −14.580; 2060–2066: −18.620 (F-22); mit `rate_eur_m2_pa: 14.40` im Szenario `basis = "rate"` |

### 4.12 Typ `equity` (Eigenkapital, Block `financing`; Spec 00 §7.12)

Parameter nach Spec 00 §7.12 (verbindlich). Konkretisierung:

- Einmalige Einlage `amount_eur` zum Termin `date` (Periode `period_of(date)`); `contributions`/`withdrawals` als
  Zahlungspläne (Beträge ≥ 0, Vorzeichen setzt der Typ); `contributions_pa`/`withdrawals_pa` als Jahresbeträge
  **ohne Fortschreibung**: `value_t = x_pa · Δ_t · overlap(from, to)_t`.
- Zeilen `in` (equity/`equity_in`, +), `out` (equity/`equity_out`, −); `tax_category = equity`.
- Haushaltseinlagen des Selbstnutzers erzeugt der Expander `household` (Teil B); ein Baustein `ek` mit
  `amount_eur: auto` ist unzulässig (nur Kredite, Spec 00 §8.7) → E.
- Prüfwert E1 (WS-E, `test-type-flow-equity.R`): `contributions_pa: 6000`, `from: 2027-01-01`, `to: 2030-01-01`: annual t = 1…3 je 6.000; G4-Raster
  (H = 6): t = 1…9 je 500, t = 10: 1.500, t = 11, 12: 6.000; Summe 2027 = 6.000 auf beiden Rastern.

### 4.13 Typ `custom_series` (Spec 00 §7.12)

Parameter verbindlich nach Spec 00 §7.12. Konkretisierung: `values` sind Periodenbeträge (keine Δ-Skalierung); ein
Vektor der Länge T+1 wird als `series_t` gelesen; Kategorie `custom` trägt per Default `tax_category = not_applicable`
und löst für S1–S5 den Steuerbereitschaftstest aus (Spec 00 §15.6). Validierung: Vorzeichen widerspricht der Kategorie
(Spec 00 §7.6) → E (Vertragsprüfung F); `section: memo` mit `cash: true` → E. Test CS1 (`test-type-flow-custom-series.R`): `values: [0, -1000, -1000, 0]`,
`category: other_cost` → Zeile wie angegeben; `category: rent` mit negativem Wert → E.

### 4.14 Typ `recurring` (Spec 00 §7.12)

Parameter und Formel verbindlich nach Spec 00 §7.12 (Kalenderjahresindex, Token `completion`, Verschiebung). Teil A
ergänzt: `direction` ist Pflicht bei ±-Kategorien (`passthrough`, `custom`), sonst aus dem Vorzeichen der Kategorie;
`base_date` Default = (`project.price_base_year` + 1)-01-01. Prüfwert F10 (Spec 00; `test-type-flow-recurring.R`): 14.000, 2 %, Basis 2027-01-01 →
Jahressumme 2027 = 14.280,00 auf `annual` und G4.

### 4.15 Typ `share_of` (WS-E, `R/type-flow-share-of.R`)

Anteil an Zeilen anderer Komponenten (z. B. Verwaltungskosten 3 % der Miete, Mietausfallwagnis als Kosten,
Grundsteuer-Leerstandsanteil).

| Parameter | Art | Default | Bedeutung |
|---|---|---|---|
| `of` | `ids` | Pflicht | Quellkomponenten (zugleich `after`) |
| `categories` | `ids` (Kategorien) | `NULL` = alle | Filter nach Kategorie |
| `local_rows` | `ids` | `NULL` = alle | Filter nach lokalem Zeilennamen |
| `share` | `share` (Pfad zulässig) | Pflicht | Anteil |
| `invert` | `logical` | `TRUE` | Vorzeichen umkehren (Kosten als Anteil von Erlösen) |
| `lag_periods` | `integer` ≥ 0 | `0` | Verzögerung in Perioden |
| `category`, `tax_category`, `section` | wie `custom_series` | `other_cost`, Default der Kategorie, `project` | Zielzeile |

Algorithmus: `base = Σ ctx$rows(id = of, category = categories, local_row = local_rows)` (Filter `NULL` = alle;
`id` als Vektor, Filter `local_row` nach Spec 00 §6.2, R-93); `value_t = (−1)^invert
· share_t · base_{t − lag}` (base_{<0} = 0). Zeile `value`; Vorzeichen muss zur Kategorie passen (sonst
`vofi_error_contract`). Zyklen über `of` verbietet die Abhängigkeitsprüfung (Spec 00 §5). Test SO1 (`test-type-flow-share-of.R`): Miete 100.000,
Mietausfall −2.000 (Quelle `u_std_rent`), `share: 0.03`, `category: other_cost` → −2.940,00; mit `lag_periods: 1`
erscheint der Betrag eine Periode später, t = 0 ist 0.

---

## 5. Finanzierung und Konten

### 5.1 Block `financing.<k>` – Überblick

Bausteine sind Eigenkapital (`type: equity`, 4.12) und Kredite (`annuity_loan`, `installment_loan`, `bullet_loan`,
WS-F, gemeinsamer Kern `inst_loan_*`, Spec 00 §8). Die Reihenfolge im Block bestimmt die Kreditposition k (Abschnitt
`loans`, `400 + k`), die Aufrufreihenfolge in der Periodenschleife und den Gleichstand in Ü3. Förderkredite erzeugt
der Expander `funding` als `f_<f>_loan` (Teil B, Parameterbelegung aus `funding/*`, Teil C); sie folgen denselben
Feldern. Teil A konkretisiert die Parameter von Spec 00 §8.2 (Namen und Arten unverändert), Defaults, Prüfungen und
Prüfwerte.

### 5.2 Kreditparameter (`financing.<k>.<param>`)

Spalte „Typ“: A = `annuity_loan`, R = `installment_loan`, E = `bullet_loan`; „det.“ = `deterministic_only`.

| YAML-Pfad | Typ (Art) | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo-Ref |
|---|---|---|---|---|---|---|---|
| `…<k>.type` | chr | – | – | ja | E: registrierter Instrumenttyp | A, R oder E | Spec 00 §8.1 |
| `…<k>.amount_eur` | amount, det., `allow_auto` | EUR | – | ja | E: > 0; E: `auto`/`topup` höchstens je einmal je Variante; E: Overlay-/Designziel (R-69); W: Bezug auf ein Overlay-Ziel („Kreditbetrag bleibt fest“) | Zusage D bzw. Restschuld (Bestand) | Spec 00 §8.2, §8.7 |
| `…<k>.approved` | value 0/1 | 1 | `1` (T); Förderkredit `{ref: funding.<f>.approved}` | nein | E: ∈ [0, 1] | Bewilligung je Lauf | R-71 |
| `…<k>.existing` | lgl | – | `false` (T) | nein | 5.3 | Bestandsdarlehen | R-68 |
| `…<k>.installment_eur` | amount | EUR je Vertragszahlung | `NULL` | nein | E: > 0; W: Annuität ≤ Monatszins des Anfangsbestands (negative Tilgung) | vertragliche Rate (A: Zins + Tilgung; R: Tilgungsrate) | Spec 00 §8.6 |
| `…<k>.rank` | int | – | `NULL` | nein | E: ≥ 1 | Rang der Grundschuld (Anzeige) | Spec 00 §8.2 |
| `…<k>.start` | timing, det. | – | `valuation_date` (T) | nein | E: ≥ Stichtag; E: ≠ Stichtag bei `existing`/`auto`/`topup`; I: nach `end_date` (Kredit entfällt) | Termin der ersten Auszahlung | Spec 00 §8.2 |
| `…<k>.draw_schedule` | schedule, det. Termine | 1 bzw. EUR | `NULL` (voll bei `start`) | nein | E: `share` Σ = 1 bzw. `eur` Σ = `amount_eur` (1e-6); E: erster Termin < `start`; E: mit `existing`/`auto`/`topup` | Teilauszahlungen (Auszahlungsplan der Bauphase) | Memo 01 §2.4 |
| `…<k>.rate_pa` | rate (bei `topup` Pfad) | 1/a | – | ja | E: ∈ [−0,01; 0,25]; W: > 0,12 | Sollzins der ersten Bindung (nominal) | Spec 00 §8.2 |
| `…<k>.payments_per_year` | int ∈ {1, 4, 12}, det. | 1/a | `12` (T) | nein | E: Wert | Vertragsfrequenz | Spec 00 §8.10 |
| `…<k>.term_years` | number, det. (Vielfaches von 1/12) | a | `NULL` | bedingt | E: Pflicht bei R, E und bei A ohne `initial_repayment_pa` und ohne `installment_eur`; E: ≤ `grace_years` | Laufzeit ab Ende der letzten Auszahlung inkl. tilgungsfreier Zeit | Spec 00 §8.2 |
| `…<k>.grace_years` | number, det. | a | `0` (T) | nein | E: ≥ 0; E: > 0 bei `existing` | tilgungsfreie Anlaufjahre | Memo 02 §5.8 |
| `…<k>.initial_repayment_pa` | rate | 1/a | `NULL` | nein | nur A; E: zusammen mit `installment_eur` (`validation.financing.tau_with_installment`); I zusammen mit `term_years` (`validation.financing.balloon_at_maturity`: τ bestimmt die Rate, `term_years` die Fälligkeit mit Schlusstilgung; R-100, N-25) | anfänglicher Tilgungssatz τ | Memo 01 §2.4, Spec 00 §8.2 |
| `…<k>.fixed_years` | number, det. | a | `NULL` (bis Laufzeitende bzw. Horizont) | nein | E: > 0; I: Ende der Bindung nach `end_date` | Zinsbindung ab `start` | Spec 00 §8.6 |
| `…<k>.followup_rate_pa` | value (Pfad) | 1/a | `{ref: market.mortgage_rate}` (T) | nein | E: `market.mortgage_rate` fehlt und Anpassung im Horizont | Anschlusszins | R-45 |
| `…<k>.followup_spread_pa` | rate | 1/a | `0` (T) | nein | – | Aufschlag (z. B. Förderkredit nach Bindungsende: Bankkondition) | Memo 01 §2.4 |
| `…<k>.followup_fixed_years` | number, det. | a | `NULL` (eine Anschlussbindung) | nein | E: > 0 | weitere Zinsbindungen | Spec 00 §8.6 |
| `…<k>.refi_rule` | enum | – | A: `keep_tilg_rate` mit τ (auch zusammen mit `term_years`), sonst `keep_term`; R: `keep_term` | nein | E: R mit `keep_tilg_rate`; E: `keep_term` ohne endliche Laufzeit (Bestand ohne `term_years`) | Ratenregel nach Zinsanpassung; nach einem Tilgungszuschuss mit `shorten_term` rechnet `keep_term` mit der effektiven Restzahl der Raten n_eff, die Laufzeitverkürzung bleibt erhalten (Spec 00 §8.6, R-100, F-10) | Spec 00 §8.6 |
| `…<k>.followup_repayment_pa` | rate | 1/a | `= initial_repayment_pa` | nein | nur `keep_tilg_rate` | τ' | Spec 00 §8.6 |
| `…<k>.payout_rate` | share | 1 | `1` (T) | nein | E: ∈ (0,9; 1]; E: ≠ 1 bei `existing` | Auszahlungskurs κ | Memo 01 §2.4 |
| `…<k>.fees.processing_fee_share` | share | 1 | `0` (T) | nein | W: > 0,02 | Bearbeitungsgebühr, fällig mit der ersten Auszahlung | Memo 01 §2.4 |
| `…<k>.fees.commitment_fee_rate_month` | share | 1/Monat | `0` (T); KfW `0.0015` (B) | nein | W: > 0,005 | Bereitstellungsprovision auf den nicht abgerufenen Betrag | Memo 02 §5.8 |
| `…<k>.fees.commitment_free_months` | int, det. | Monate | `0` (T); KfW `12` (B) | nein | E: ≥ 0 | bereitstellungsfreie Zeit ab `commitment_date` | Memo 02 §5.8 |
| `…<k>.fees.commitment_date` | timing, det. | – | `= start` (T) | nein | E: ≤ `start` und ≥ Stichtag | Beginn der Bereitstellungsfrist (Zusagedatum) | Spec 00 §8.2 |
| `…<k>.repayment_grant.share` | share | 1 | `NULL` | bedingt | E: genau eines von `share`, `amount_eur`; E: ohne `measure_id`/`funding_id` | Tilgungszuschuss in % der Zusage, bezogen auf min(Zusage, abgerufen) | Konzept F15 |
| `…<k>.repayment_grant.amount_eur` | value | EUR | `NULL` | bedingt | E: > Zusage | Tilgungszuschuss als Betrag | Memo 01 E9 |
| `…<k>.repayment_grant.date` / `.year` | timing, det. | – | spätere von `completion_date` der Maßnahme (`measure_id`, deterministisch) und Ende der letzten Auszahlungsperiode | nein | E: vor `start`; I: nach `end_date` (entfällt) | Gutschrifttermin (Datum); Buchung in `grid_period_of(Termin)` nach R-35/R-98, z. B. 2027-10-01 + 3 Monate = 2028-01-01 → t = 1 auf dem Jahresraster ab 2027, wie der Zuschuss mit gleicher Ableitung (Teil B §4.5) | Spec 00 §3.4, §8.6 |
| `…<k>.repayment_grant.effect` | enum `shorten_term`, `reduce_installment` | – | `shorten_term` (T; KfW-Eintrag) | nein | – | Wirkung der Gutschrift | R-07 |
| `…<k>.repayment_grant.approved` | value 0/1 | 1 | `1` (T); Förderkredit `{ref: funding.<f>.approved}` | nein | – | Zuschuss gewährt | R-71 |
| `…<k>.repayment_grant.cut_share` | share | 1 | `0` (T) | nein | E: ∈ [0, 1] | Kürzung bei verfehltem Nachweis (stochastisch zulässig) | Konzept B12, R-84 |
| `…<k>.planned_prepayments` | schedule, det. Termine | EUR | `NULL` | nein | W: Summe > Zusage; I: Kappung durch `prepay_cap_share_pa` | geplante Sondertilgungen | D4 |
| `…<k>.prepay_allowed` | lgl | – | `false` (T) | nein | W: `true` bei KfW-Programm (`program`) | Ü3 darf sondertilgen | R-29 |
| `…<k>.prepay_cap_share_pa` | share | 1/a | `1` (T); Bank typisch `0.05` | nein | – | Obergrenze je Vertragsjahr (Anteil der Zusage) | Memo 01 §2.4 |
| `…<k>.auto_buffer_share`, `…<k>.auto_round_eur` | share, amount | 1, EUR | `0`, `0` (T) | nein | nur mit `auto`/`topup` | Puffer und Rundung des Bedarfs | Spec 00 §8.7 |
| `…<k>.round_payments` | lgl | – | `false` (T) | nein | – | Raten auf Cent (kaufmännisch, `floor(100·x + 0,5)/100`) bei Festlegung und Anpassung | Memo 01 §10 |
| Metafelder `program`, `funding_id`, `measure_id`, `asset_id`, `label` | chr | – | `NULL` | bedingt | E: `repayment_grant` ohne `measure_id`/`funding_id` | Tags der Kreditzeilen | Spec 00 §4.3.8 |

**Deterministische Terminableitung (MUSS, WS-F, `init()`).** Mit `mi(d)` = Monatsindex eines Datums (Monate ab
Stichtag; Monatserste) und `me(t)` = `month_end` der Periode t:
`m_start = me(period_of(start))`; `m_A = me(period_of(letzter Auszahlungstermin))` (bei `auto`/`topup` letzte
Fensterperiode); `m_rep = m_A + 12·grace_years`; `m_mat = m_A + 12·term_years` (∞ ohne Laufzeit);
`reset_months = {m_start + 12·fixed_years + j·12·followup_fixed_years : j = 0, 1, …} ∩ (0, m_mat)`;
`fee_free_until = mi(commitment_date) + commitment_free_months`; `t_tz = period_of(repayment_grant.date)` (Datumstermin
nach Spec 00 §3.4 Nr. 3, R-98; Tilgungszuschüsse bleiben terminfest, R-47). Bei
`existing` gilt m_start = m_A = 0 (Stichtag) und `grace_years = 0`.

**KfW-Varianten.** Ein Förderkredit übernimmt aus `funding/<id>.values.loan.variants.<v>` die Felder `term_years`,
`grace_years`, `fixed_years`, `rate_pa`, ggf. `repayment` (→ Typ), aus `loan.fees` die Gebühren, aus
`loan.prepay_allowed` die Sondertilgungserlaubnis und aus `repayment_grant.effect` die Wirkung (Belegung durch den
Expander `funding`, Teil B; Variante über `funding.<f>.loan_variant`, Default `default_variant`). Effektivzinsen der
Einträge sind Information; gerechnet wird mit `rate_pa` (nominal) nach der Monatsuhr.

### 5.3 Bestandsdarlehen (`existing: true`, R-68)

| Feld | Regel |
|---|---|
| `amount_eur` | Restschuld zum Stichtag (B_0); Merkzeile `loan_<k>_assumed[,1] = B_0`, keine Auszahlung, keine Gebühr |
| `start` | = `valuation_date` (Pflicht; anderer Wert E) |
| `term_years` | Restlaufzeit; Pflicht bei R und E sowie bei A ohne `installment_eur`/`initial_repayment_pa` |
| `fixed_years` | Restzinsbindung ab Stichtag |
| `installment_eur` | vertragliche Monats- bzw. Quartalsrate; empfohlen (I, wenn fehlt: „Rate aus Restlaufzeit berechnet“) |
| `refi_rule` | Default wie 5.2; mit `installment_eur` ohne `term_years` ist nur `keep_payment` oder `keep_tilg_rate` zulässig (E sonst) |
| unzulässig | `auto`/`topup`, `draw_schedule`, `fees`, `payout_rate` ≠ 1, `repayment_grant`, `grace_years` > 0 (E `validation.financing.existing_forbidden`) |
| Varianten | Bestandsdarlehen sind in allen Gebäudevarianten identisch (Spec 00 §9.6 Nr. 2); eine Variante, die ein `existing`-Darlehen ändert, entfernt oder hinzufügt, ist E `validation.variants.existing_debt_changed` |
| Projektart | `existing` in `neubau`/`erwerb_*` → W („Bestandsdarlehen bei Neubau/Erwerb: Ablösung oder Übernahme prüfen“) |

Alle Ledger-Zeilen tragen `existing_debt = TRUE` (DSCR Objekt- vs. Maßnahmenebene, Spec 00 §12.3).

### 5.4 Zeilen (Engine, Spec 00 §7.7, §8.4)

| Schlüssel | section / category | cash | Tags |
|---|---|---|---|
| `loan_<k>_draw` | loans / `draw` | T | `program`, `funding_id`, `measure_id`, `asset_id` des Bausteins |
| `loan_<k>_repay`, `_repay_balloon`, `_prepay` | loans / gleichnamig | T | dto. |
| `loan_<k>_interest`, `_fees` | loans / gleichnamig (`interest_expense`) | T | dto. |
| `loan_<k>_repayment_grant` | loans / `repayment_grant` (memo) | F | `measure_id` Pflicht |
| `loan_<k>_disagio`, `loan_<k>_assumed` | loans / gleichnamig (memo) | F | dto. |
| `loan_<k>_balance` | stocks / `balance` | F | dto. |

### 5.5 Validierung (Ebene 2/3, WS-B; Laufzeit WS-F)

| Bedingung | Klasse, Schlüssel |
|---|---|
| Rate einer Annuität ≤ Zins der ersten Vertragszahlung (`installment_eur` zu klein) | W `validation.financing.negative_amortization` |
| `keep_payment` mit negativer Tilgung im Lauf | `vofi_warning_engine` (Spec 00 §8.6), Markierung `neg_amort` |
| Tilgungszuschuss > Bestand zum Gutschrifttermin | Begrenzung (Spec 00 §8.5 (j)), I mit Anteil der Läufe |
| `auto` und Bauphase ohne Defizit | I „auto-Kredit = 0“ |
| Zusage < abgerufener Betrag (`draw_schedule` `eur`) | E `validation.financing.draws_exceed` |
| Bereitstellungsprovision ohne `draw_schedule` (Vollauszahlung bei `start`) und `commitment_date` < `start` | I (Provision nur zwischen Zusage und Auszahlung) |
| Anschlussbindung endet nach Laufzeitende | I (gekürzt) |
| `payments_per_year` ≠ 12 bei Förderkredit ohne Bibliothekswert | I („Vertragsfrequenz prüfen“, Teil C Qualität D) |
| `initial_repayment_pa` zusammen mit `term_years` | I `validation.financing.balloon_at_maturity` („Schlusstilgung bei Fälligkeit“, R-100) |
| `initial_repayment_pa` zusammen mit `installment_eur` | E `validation.financing.tau_with_installment` (R-100) |
| Kredit mit `measure_id` auf Maßnahme mit stochastischem `delay_months` | W (Spec 00 §3.9) |

### 5.6 Tests (WS-F, `test-type-inst-loan-core.R`; Werte mit der Monatsuhr-Referenz `vref.py`)

Jahresraster ab 2027-01-01, sofern nicht anders angegeben.

| Nr. | Fall | Erwartung |
|---|---|---|
| (f) | Spec 00 §8.10: 100.000, 3,6 %, monatlich, 20 J. | Rate 585,11; Z_1 3.542,98; R_1 3.478,36; B_1 96.521,64 |
| (h) | Spec 00 §8.10: Ratendarlehen 120.000, 2 %, 10 J., Bindung 5, Anschluss 4 % | Z_1 2.290,00; B_5 60.000,00; Z_6 2.180,00; R_6 12.000,00; B_8 24.000,00; B_10 0 |
| L1 | KfW 261 (S1 V2): A, 1.300.000, 3,65 %, `payments_per_year: 1`, 30 J., 5 tilgungsfrei, Bindung 10, Anschluss 4 %, TZ 144.400 zum Termin 2028-01-01 (→ Ende t = 1, R-98), `shorten_term` | Z_1 47.450,00; B_1 1.155.600,00; Z_2…Z_5 je 42.179,40; Annuität (Basis Zusage, 25 Raten) 80.165,66: t = 6 Z 42.179,40, R 37.986,26; B_10 951.288,32; Anpassung `keep_term` mit effektiver Restzahl n_eff = min(20, ⌈n*⌉) = 16, n* = 15,833415 (R-100): Rate 81.639,56, t = 11 Z 38.051,53, R 43.588,03, B_11 907.700,29; letzte Rate t = 26 (2052; Z 3.139,98, R 78.499,58), zusammen 21 Annuitäten 2032–2052 (vor R-100: 20 Raten zu 69.997,46 bis 2056) |
| L2 | L1 mit `reduce_installment` | Rate ab t = 6 (Basis B = 1.155.600) 71.261,11; B_10 999.182,07; nach Anpassung (keep_term mit n_rem = 20, keine Laufzeitverkürzung) 73.521,57 |
| L3 | Raster monatliche Bauphase C = 6, H = 3 (`months = (0,1,1,1,1,1,1,6,12,12)`); A 300.000, 2 %, monatlich, Auszahlungen je 100.000 am 2027-02-01, 2027-05-01, 2027-07-01; Bereitstellung 0,15 %/Monat, 2 Monate frei ab 2027-01-01; 1 J. tilgungsfrei, 10 J. Laufzeit | t = 2: Z −166,67; t = 3: Z −166,67, F −300,00; t = 4: Z −166,67, F −300,00; t = 5: Z −333,33, F −150,00; t = 6: Z −333,33, F −150,00; t = 7: Z −3.000,00; t = 8: Z −5.936,42, R −15.289,07, B 284.710,93; t = 9: Z −5.410,71, R −31.040,27, B 253.670,66; Rate 3.037,58; Σ Zinsen 15.513,80, Σ Provision 900,00 |
| L4 | E 100.000, 5 %, quartalsweise, 5 J., κ = 0,97, Bearbeitung 1 % | t = 0: Auszahlung +97.000, Gebühr −1.000, Disagio (memo) +3.000, B_0 100.000; t = 1…5 Z −5.000; t = 5 Schlusstilgung −100.000 |
| L5 | A 100.000, 3 %, τ = 2 %, monatlich, geplante Sondertilgung 10.000 in t = 2, Obergrenze 5 % p. a. | Rate 416,67; t = 1: Z −2.972,27, R −2.027,73, B 97.972,27; t = 2: Z −2.910,59, R −2.089,41, Sondertilgung −5.000 (gekappt), B 90.882,86; t = 3: Z −2.694,96, R −2.305,04, B 88.577,83 |
| L6 | Bestandsdarlehen A 400.000, 2,5 %, `installment_eur: 2000` (monatlich), Restbindung 3 J., Anschluss 4,5 %, `keep_payment` | t = 0: `assumed` +400.000, keine Auszahlung, B_0 400.000; t = 1: Z −9.838,46, R −14.161,54, B 385.838,46; t = 3: B 356.431,97; t = 4: Z −15.873,18, R −8.126,82; t = 5: B 339.804,99; alle Zeilen `existing_debt = TRUE` |
| L7 | A 200.000, 3,5 %, τ = 2 %, jährlich, Bindung 5, Anschluss 5 %, `keep_tilg_rate` | t = 1: Z −7.000, R −4.000; B_5 178.550,14; Rate danach 12.498,51 (= B_5 · 7 %); t = 6: Z −8.927,51, R −3.571,00 |
| L8 | R 120.000, 2 %, jährlich, 10 J., TZ 12.000 in t = 2, `reduce_installment` | t = 1: Z −2.400, R −12.000; t = 2: R −12.000, TZ 12.000, B 84.000; t = 3: Z −1.680, R −10.500 |
| L9 | L1 mit `approved` = 0 (Lauf) | alle Zeilen 0, Bereitstellungsprovision 0 (Spec 00 §8.5 (d)) |
| L10 | L1 mit `repayment_grant.cut_share` = 0,5 (Lauf) | TZ 72.200; B_1 1.227.800,00 |
| L11 | A 100.000, 3 %, τ = 2 %, monatlich, `term_years: 10` (τ und Laufzeit, R-100) | Rate 416,67 (aus τ); I `validation.financing.balloon_at_maturity`; t = 1: Z −2.972,27, R −2.027,73, B 97.972,27; t = 10: Z −2.344,64, R −2.655,36, Schlusstilgung `repay_balloon` −76.709,76, B_10 0 |

### 5.7 Block `accounts` (Spec 00 §4.3.10, §8.8; Werte je Perspektive 2.3–2.8)

| YAML-Pfad | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo-Ref |
|---|---|---|---|---|---|---|---|
| `accounts.deposit_rate_pa` | value (Pfad) | 1/a | P: `{ref: market.mortgage_rate, anchor: h, floor: 0}` mit h = 0,035 (WU kommunal/privat), 0,020 (eG), 0,025 (privat) | nein | E: ∈ [−0,02; 0,15]; W: > `overdraft_rate_pa` (Spec 00 §8.8) | effektiver Habenzins; Untergrenze 0 im MC (F-14, Memo 04 §1.2) | Konzept A2, F18 |
| `accounts.overdraft_rate_pa` | value (Pfad) | 1/a | P: anchor 0,055 (WU, eG) bzw. 0,060 (privat) | nein | E: ∈ [0; 0,25] | effektiver KK-Zins | Konzept A2 |
| `accounts.overdraft_limit_eur` | value (Pfad, `.inf`) | EUR | P: `.inf` (WU, eG), `0` (privat) | nein | E: ≥ 0; W `validation.accounts.liquidity_unchecked`, wenn `liquidity` ∈ `analysis.restrictions`, das Limit in allen Perioden unendlich und `overdraft_flag_threshold_eur` = ∞ ist (`restriction_liquidity` dann NA `no_liquidity_limit`, kein K.-o.; Spec 00 §12.3, R-101, X-30) | Schwelle der D4-Aktion; WU: Kreditlinie bzw. Cash-Pool-Rahmen projektbezogen angeben (Konzept A2) | Konzept A2, R-76 |
| `accounts.penalty_spread_pa` | value | 1/a | P: `0.02` | nein | E: ≥ 0 | Strafzinsaufschlag | Konzept A2 |
| `accounts.min_liquidity_eur` | value (Pfad) | EUR | P: `0` | nein | E: ≥ 0 | Mindestliquidität L_min | Konzept A2 |
| `accounts.deposit_withholding_tax_share` | share | 1 | P: `0` | nein | W: ∉ {0; 0,26375; 0,278186; 0,279951} | Abgeltungsteuer + Soli (+ KiSt 8 %/9 %) | D5, R-40 |
| `accounts.deposit_tax_allowance_eur_pa` | amount | EUR/a | P: `0` | nein | E: ≥ 0; W: > 2.000 (Pauschbetrag Ehepaar) | Sparer-Pauschbetrag dieser Anlage | Konzept 3.12, R-76 |
| `accounts.overdraft_flag_threshold_eur` | num | EUR | P: `.inf` | nein | E: ≥ 0 | Markierungsschwelle `overdraft_threshold`; ein endlicher Wert macht `restriction_liquidity` auch bei unendlichem Limit prüfbar (KK + KKP > Schwelle) | Spec 00 §9.8, §12.3 |
| `accounts.surplus_order` | chr[] | – | `[od_repay, dep_fill_reserve, dep_invest]` (G) | nein | E: Kettenregeln (Spec 00 §8.9); W: `loan_prepay` (Heuristik) | Überschussverwendung | R-29 |
| `accounts.deficit_order` | chr[] | – | P: WU/eG `[…, penalty_rate]`, privat `[…, equity_call]` | nein | E: Kettenregeln | Defizitdeckung | D4 |
| `accounts.prepay.buffer_eur`, `accounts.prepay.min_spread_pa` | amount, rate | EUR, 1/a | `0`, `0` (G) | nein | E: ≥ 0 | Ü3-Parameter | Memo 01 §3.2 |

**Abgeltungsteuersätze.** w = 0,25 · 1,055 = 0,26375 ohne Kirchensteuer; mit Kirchensteuer k: Abgeltungsteuer
0,25/(1 + 0,25·k), darauf Soli 5,5 % und KiSt k: w(8 %) = 0,278186, w(9 %) = 0,279951.

**Tests (WS-D, `test-engine-accounts.R`).** AC1: G = 100.000 Ende t−1, h = 3 % (Jahresperiode), w = 0,26375 → HZ
3.000,00, WHT 791,25; mit `deposit_tax_allowance_eur_pa: 1000` → WHT 527,50; auf einer Halbjahresperiode (Δ = 0,5)
wa = 500. AC2: `deficit_order: [od_draw, dep_withdraw, equity_call]` → E (erste Aktion nicht `dep_withdraw`).
AC3: `surplus_order` mit `loan_prepay` → einmal W je Lauf. AC4: PR5 (Kopplung `anchor` mit Untergrenze, 2.9). AC5
(WS-B): `wu_kommunal` ohne Angaben → W `validation.accounts.liquidity_unchecked`; mit
`overdraft_flag_threshold_eur: 250000` kein Befund.

---

## 6. Restwert

### 6.1 Block `residual_value` (Spec 00 §4.3.12) – Feldkatalog

Methodenparameter liegen je Methode in einer Untermap (`residual_value.<methode>.<feld>`); damit sind Overlay-Ziele
wie `residual_value.income_value.cap_rate` (Teil C §1.9) adressierbar. Profile setzen nur `method` und
`sale_cost_share` (R-76); alle übrigen Werte kommen aus `global.yaml` (2.2) bzw. dem Szenario.

| YAML-Pfad | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo-Ref |
|---|---|---|---|---|---|---|---|
| `residual_value.method` | enum:residual_method | – | P (2.8); Rückfall `zero` (G) | nein | E: Code; W: `income_value`/`multiplier`/`exit_yield` ohne Mietkomponente; W: `asset_value` bei Vermietung | Bewertungsmethode | Konzept 3.11, A3, R-34 |
| `residual_value.sale_cost_share` | share | 1 | `0.03` (G über B:`valuation/verkaufskosten_2026`; P) | nein | W: > 0,08 | Verkaufskosten am Horizont und beim Bestandsverkauf (Spec 00 §9.5 Nr. 7) | Konzept A3 |
| `residual_value.path_pre_operation` | enum:`auto`,`cost`,`method`,`zero` | – | `auto` (G) | nein | – | Wertpfad vor dem ersten Betriebsjahr (6.2 Nr. 4) | R-72 |
| `…income_value.variant` | enum:`general`,`simplified` | – | `general` (G) | nein | – | allgemeines (§ 28) bzw. vereinfachtes (§ 29) Ertragswertverfahren (rechnerisch gleich bei RE, BW, LZ, n) | Memo 02 §7.1 |
| `…income_value.cap_rate` | value (Pfad zulässig) | 1/a | `0.035` (G über B:`valuation/liegenschaftszinsen_2026`, `presets.mid_city`) | nein | E: ∈ (−0,01; 0,12]; W: < 0,015 oder > 0,06 | Liegenschaftszinssatz LZ (stochastisch zulässig; als Pfad je t die Spalte t, z. B. Kopplung an den Zinspfad nach Teil C K7) | Konzept B10 |
| `…income_value.remaining_life_method` | enum:`anlage2`,`linear`,`manual` | – | `anlage2` (G) | nein | E: `manual` ohne `remaining_life_years` | Restnutzungsdauer: ImmoWertV Anl. 2 mit Modernisierungspunkten; linear GND − Alter; feste Angabe | Memo 02 §7.1 |
| `…income_value.remaining_life_years` | number | a | `NULL` | bedingt | E: ≥ 0; E `validation.residual.rnd_target`: Overlay- oder Designziel bei `remaining_life_method ≠ manual` (Vorschlag `remaining_life_offset_years`, R-109) | RND am Horizont (bei `manual`; Pfad: + (T_J − τ_t)) | – |
| `…income_value.remaining_life_offset_years` | number | a | `0` (G) | nein | – | additiver Zuschlag auf die RND; Ziel des Schocks `remaining_life_shock` (Teil C §1.9). Overlays zielen direkt auf dieses Feld; ein Ziel `remaining_life_years` bei `remaining_life_method ≠ manual` wird nicht umgelenkt, sondern ist E `validation.residual.rnd_target` mit Vorschlag dieses Felds (R-109, N-20; Antrag S01A-08 abgelehnt) | Konzept 3.11 |
| `…income_value.gnd_years` | number | a | `80` (G über B:`valuation/immowertv_anlage1_2_2026`) | nein | E: > 0 | Gesamtnutzungsdauer (Anl. 1) | Memo 03 §9 |
| `…income_value.rnd_table` | map (det.) | – | B:`…anlage1_2_2026` `rnd_coefficients` | nein | E: Schlüssel `p0`…`p20` mit `a`, `b`, `c`, `rel_age_min` | Koeffizienten Anl. 2 (deterministisch, kein Overlay-Ziel) | ImmoWertV Anl. 2 |
| `…income_value.points_max` | map (det.) | Punkte | B:`…anlage1_2_2026` `modernisation_points_max` | nein | Σ = 20 | Höchstpunkte je Element (6.3.3) | ImmoWertV Anl. 2 |
| `…income_value.points_decay_years` | number | a | `NULL` (G) | nein | E: > 0 | Punkte einer Maßnahme zählen nur, solange sie jünger ist (NULL = immer) | – |
| `…income_value.income_basis` | enum:`forward`,`trailing` | – | `forward` (G) | nein | – | Rohertrag der nächsten bzw. letzten 12 Monate (6.3.1) | – |
| `…income_value.forward_growth` | value | 1/a | `{ref: market.rent_growth}` (G) | nein | – | Fortschreibung der Erträge jenseits von T | – |
| `…income_value.cost_forward_growth` | value | 1/a | `{ref: market.inflation}` (G) | nein | – | Fortschreibung der Kosten jenseits von T | – |
| `…income_value.include_other_income` | lgl | – | `false` (G) | nein | – | Kategorie `other_income`/`energy_income` im Rohertrag | – |
| `…income_value.land_value_eur` | value | EUR | `{ref: building.land_value_eur}` (G) | ja | E: fehlt | Bodenwert BW_0 zum Stichtag | Memo 02 §7.1 |
| `…income_value.land_value_growth` | value | 1/a | `{ref: market.land_value_growth}` (G) | nein | – | Bodenwertentwicklung | Memo 07 §4.0 |
| `…income_value.bwk.admin_eur_unit_pa` | value | EUR/WE·a | `367` (G über B:`costs/bewirtschaftung_immowertv_2026`) | nein | E: ≥ 0 | Verwaltungskosten (Modell) | Memo 03 §8.2 |
| `…income_value.bwk.maintenance_eur_m2_pa` | value | EUR/m²·a | `14.40` (G über B) | nein | E: ≥ 0 | Instandhaltung (Modell) | Memo 03 §8.2 |
| `…income_value.bwk.rent_loss_share` | share | 1 | `0.02` (G über B) | nein | – | Mietausfallwagnis MAW (Anteil Rohertrag) | Teil B §2.1 |
| `…income_value.bwk.price_base_year` | int | Jahr | `2025` (G) | nein | – | Preisstand der Modellwerte (Stand 01.01.2026 → 2026-01-01, R-35) | R-35 |
| `…income_value.bwk.index` | value | 1/a | `{ref: market.inflation}` (G) | nein | – | Fortschreibung (VPI, Anl. 3) | ImmoWertV Anl. 3 |
| `…income_value.bwk.admin_source`, `.maintenance_source` | enum:`model`,`ledger` | – | `model` (G) | nein | I: `ledger` ohne Zeilen der Kategorie | Modellansatz oder Ledger-Zeilen (`operating_cost` bzw. `maintenance`) | – |
| `…income_value.bwk.variant_cost_categories` | chr[] | – | `[co2_cost, energy_cost, other_cost]` (G) | nein | E: Kategorien des Abschnitts `project` | variantenabhängige Vermieterkosten, die in die BWK eingehen (Energieeffizienz wirkt auf den Ertragswert) | Konzept 3.11 |
| `…income_value.bwk.vacancy_from_ledger` | lgl | – | `true` (G) | nein | – | Leerstand über MAW hinaus aus `rent_loss` (6.3.3) | – |
| `…income_value.bog_eur` | value | EUR | `0` (G) | nein | – | besondere objektspezifische Grundstücksmerkmale (±) | ImmoWertV § 8 |
| `…income_value.bog_component_residual` | lgl | – | `false` (G) | nein | W bei `true` (6.4) | Zeitwert der Maßnahmen zusätzlich addieren | – |
| `…income_value.stranded_discount_share` | value | 1 | `0` (G) | nein | E: ∈ [0, 1) | Abschlag auf den Gebäudeertragswert (Heizungsersatzbedarf, schlechte Effizienzklasse) | Konzept 3.11 |
| `…income_value.liquidation_floor` | lgl | – | `true` (G) | nein | – | EW ≥ BW − Abbruchkosten (Liquidationswert) | ImmoWertV § 8 Abs. 3 |
| `…income_value.demolition_cost_eur` | value | EUR | `0` (G) | nein | E: ≥ 0 | Freilegungskosten (Preisstand Stichtag, indexiert mit `bwk.index`) | – |
| `…multiplier.factor` | value | 1 | `20` (G über B:`valuation/kaufpreisfaktoren_2026`) | nein | E: > 0; W: ∉ [10, 35] | Rohertragsvervielfältiger | Konzept 3.11 |
| `…multiplier.basis` | enum:`net_cold_rent_incl_levy`,`net_cold_rent` | – | `net_cold_rent_incl_levy` (G) | nein | – | Bezugsgröße | Memo 02 §7.2 |
| `…multiplier.income_basis`, `…multiplier.forward_growth` | wie Ertragswert | | `forward`, `{ref: market.rent_growth}` (G) | nein | – | – | – |
| `…exit_yield.cap_rate` | value | 1/a | `0.04` (G) | nein | E: > 0; W: ∉ [0,02; 0,08] | NOI-Rendite am Horizont | Memo 02 §7.2 |
| `…exit_yield.income_basis`, `.forward_growth`, `.cost_forward_growth` | wie Ertragswert | | (G) | nein | – | – | – |
| `…market_growth.base_value_eur` | value | EUR | `NULL` = `building.existing_value_eur`, sonst `building.market_value_eur`, sonst Investitionsbasis (6.3.4) | nein | E: ≥ 0 | Ausgangswert V_0 | Konzept 3.11 |
| `…market_growth.growth` | value | 1/a | `{ref: market.market_value_growth}` (G) | nein | – | Wertentwicklung | Memo 07 S6 |
| `…market_growth.uplift_share` | value | 1 | `0` (G) | nein | E: ≥ 0 | Wertzuschlag nach Fertigstellung aller Maßnahmen | Memo 07 S5 |
| `…asset_value.life_basis` | enum:`gnd`,`component` | – | `gnd` (G) | nein | – | Alterswertminderung über GND bzw. über die Bauteil-Nutzungsdauern | Memo 02 §7.3 |
| `…asset_value.gnd_years` | number | a | `{ref: residual_value.income_value.gnd_years}` (G) | nein | E: > 0 | GND | – |
| `…asset_value.kg_include` | int[] | – | `[200, 300, 400, 500, 700]` (G) | nein | E: ⊆ {200, …, 700} | einbezogene Kostengruppen (KG 600 Ausstattung nicht im Sachwert) | DIN 276 |
| `…asset_value.include_existing` | lgl | – | `true` (G) | nein | – | Bestandsgebäude (W_0 − BW_0) einbeziehen | – |
| `…asset_value.market_adjustment_factor` | value | 1 | `1.0` (G) | nein | E: > 0 | Sachwertfaktor | Memo 02 §7.3 |
| `…asset_value.uplift_share` | value | 1 | `0` (G) | nein | E: ≥ 0 | Effizienzzuschlag auf den Gebäudesachwert | Memo 07 S5 |
| `…asset_value.index` | value | 1/a | `{ref: market.construction_price_index}` (G) | nein | – | Fortschreibung der Herstellungskosten | ImmoWertV § 36 |
| `…asset_value.land_value_eur`, `.land_value_growth` | wie Ertragswert | | (G) | ja | E: fehlt | Bodenwert | – |
| `…component.indexed` | lgl | – | `true` (G) | nein | – | `true`: Buchwert × Baupreisindex vom Investitionstermin bis b_t (Konzept 3.11); `false`: nominaler Buchwert C_last · max(0, 1 − α_t/L) (Spec 00 §4.12 Nr. 8, R-108, N-24; 6.3.7) | Konzept 3.11 |
| `…component.include_land` | lgl | – | `false` (G) | nein | – | Bodenwert addieren | – |
| `…component.include_existing` | enum:`auto`,`true`,`false` | – | `auto` (G) = einbeziehen, wenn `building.existing_value_eur` gesetzt ist oder ein Erwerb vorliegt (6.3.7) | nein | W: `false` mit gesetztem Bestandswert („Sacheinlage ohne Gegenwert am Horizont“) | Bestandswert W_0 fortgeschrieben addieren (`auto`: wenn gesetzt) | Konzept 2.6 |
| `…component.existing_growth` | value | 1/a | `{ref: market.market_value_growth}` (G) | nein | – | Fortschreibung des Bestandswerts | – |
| `…user_value.value_eur` | value (Pfad zulässig) | EUR | `0` (G) | nein | E: ≥ 0 | vorgegebener Wert V_t (Konstante: nur T, Pfad: je t) | – |

### 6.2 Expander `residual` (`R/expand-residual.R`, WS-E2, `order = 60`)

1. Erzeugt genau eine Komponente `rv_value` vom Typ `residual_value` (WS-E, `R/type-flow-residual-value.R`), sofern
   `method ≠ zero` **oder** Maßnahmen mit Zeitwertpfad existieren (für `rv_basis = measures`, Spec 00 §4.12 Nr. 8);
   sonst eine Komponente mit Nullzeilen (Tabellenstabilität).
2. **Parameter:** numerische Blätter von `residual_value.<method>.*` als `{ref: …}`; deterministische Maps
   (`rnd_table`, `points_max`) und Codes als normalisierte Werte; zusätzlich `n_units`, `living_area_m2`
   (`{ref: building.…}`), `construction_year`/`fictitious_construction_year` (Wert), `points_before` (Bezüge auf
   `building.modernization_points_before.<el>`), `points_measures` (Map Maßnahme → Map Element → Bezug auf
   `measures.<m>.effects.residual.modernization_points.<el>`), `existing_value_eur` (`{ref: building.existing_value_eur}`,
   gelesen als Basisfallwert für `component`/`market_growth` nur, wenn kein Overlay-Ziel darauf zeigt, sonst je Lauf).
3. **Abhängigkeiten (`after`):** alle Komponenten außer `rv_value` und außer Komponenten, die selbst Zeilen anderer
   lesen und `rv_value` lesen könnten (keine; `share_of` darf `rv_value` nicht in `of` führen, E). Der Typ liest
   Zeilen über `ctx$rows()` und die Zeitwertpfade über `ctx$component("m_<m>_repl")$aux`.
4. **Pfad vor Betriebsbeginn** (`path_pre_operation`, Perioden mit `phase == "construction"` und vor dem ersten
   Betriebsmonat): `cost` = kumulierte Investition −Σ_{u≤t} (Kategorien `land`, `acquisition_cost`, `capex`) zuzüglich
   W_0 (falls gesetzt); `method` = Formel der Methode (bei Ertragswert mit den Erträgen des Bestands); `zero` = 0;
   `auto` = `cost` für `neubau`/`erwerb_neubau`, sonst `method`.
5. Ohne `building`: nur `user_value`, `zero`, `market_growth` (mit `base_value_eur`) und `exit_yield` zulässig (E sonst).

### 6.3 Methoden (Typ `residual_value`, MUSS, vektorisiert über n und t)

#### 6.3.1 Gemeinsame Größen

- **Periodenende** b_t, Alter a_t = Jahr(b_t) − Baujahr* mit Baujahr* = `fictitious_construction_year` %||%
  `construction_year` (Neubauprojekt: Jahr der verschobenen Fertigstellung); a_t wird bei GND gekappt
  (min(a_t, GND)), weil die Anl.-2-Parabeln ihren Scheitel erst bei 84–89 Jahren haben.
- **Ertragsfenster** (`income_basis`): `forward` = Summe der Zeilen über die 12 Monate (b_t, b_t + 12 M]; Zeilen werden
  dazu mit `ctx$to_months(x, "spread")` auf Monate verteilt; Monate jenseits von M_T werden aus dem Monat 12 Monate
  früher × (1 + g) extrapoliert (Erträge `forward_growth`, Kosten `cost_forward_growth`, jeweils Wert der letzten
  Spalte). Für t = T ist das Fenster damit „letzte 12 Monate × (1 + g)“. `trailing` = (b_t − 12 M, b_t].
- **Rohertrag** RoE_t = Fenster der Kategorien `rent` + `modernization_levy` (+ `other_income`, `energy_income` bei
  `include_other_income`); `rent_loss` geht **nicht** in den Rohertrag, sondern über MAW/Leerstand in die BWK.
- **Bodenwert** BW_t = BW_0 · `ctx$index(land_value_growth)` (Bestandsindex ab Stichtag).
- **Wertpfad** V_t für t = 0…T nach der Methode; Verkaufskosten SC_t = `sale_cost_share` · V_t.

#### 6.3.2 `zero`

V_t = 0 für alle t; Zeilen `value`, `sale_cost`, `market_value`, `path_method` null (Spec 00 §4.12 Nr. 8).

#### 6.3.3 `income_value` (Ertragswert, ImmoWertV §§ 27–34)

```text
BWK_t  = admin_t + maint_t + MAW_t + VAC_t + VAR_t
  admin_t = admin_eur_unit_pa * n_units * I^bwk_t        (model; I^bwk = ctx$index(bwk.index, (bwk.price_base_year+1)-01-01))
          bzw. −Fenster(operating_cost, nur cash, ohne passthrough)                            (ledger)
  maint_t = maintenance_eur_m2_pa * living_area_m2 * I^bwk_t  bzw. −Fenster(maintenance)        (ledger)
  MAW_t   = rent_loss_share * RoE_t
  VAC_t   = vacancy_from_ledger * pmax(−Fenster(rent_loss) / RoE_t − rent_loss_share, 0) * RoE_t
  VAR_t   = −Fenster(variant_cost_categories)                                                 (Vermieteranteil)
RE_t   = RoE_t − BWK_t
n_t    = pmax(RND_t + remaining_life_offset_years, 0)
q      = 1 + LZ;  KF_t = (q^n_t − 1) / (q^n_t · (q − 1))   (LZ = 0: KF = n_t)
general:     EW_t = (RE_t − BW_t · LZ) · KF_t + BW_t
simplified:  EW_t = RE_t · KF_t + BW_t / q^n_t
Gebäudeanteil G_t = EW_t − BW_t;  G_t <- G_t · (1 − stranded_discount_share)
liquidation_floor: EW_t <- pmax(BW_t + G_t, BW_t − demolition_cost_eur · I^bwk_t)
V_t    = BW_t + G_t + bog_eur  (+ Zeitwert der Maßnahmen bei bog_component_residual, 6.4)
```

**Restnutzungsdauer RND_t:**

- `linear`: RND_t = max(GND − a_t, 0).
- `manual`: RND_t = `remaining_life_years` + (T_J − τ_t) (gleiche Abnahme um 1 je Jahr bis T).
- `anlage2` (ImmoWertV 2021 Anl. 2): Punkte P_t = Σ_el min(points_max[el], before[el] + Σ_m pts_m[el] ·
  [m wirksam bis b_t] · a_m) (Wirksamkeit: `aux$in_operation` der Maßnahme > 0 bis b_t, Alter < `points_decay_years`),
  p = floor(P_t) ∈ {0, …, 20}; (a, b, c, r) = `rnd_table[[p]]`; ā = min(a_t, GND);
  RND_t = a·ā²/GND − b·ā + c·GND, falls ā/GND ≥ r; sonst GND − ā. Die Formel ist an der Schwelle stetig
  (Prüffall: p = 8, ā = 16 → 64,0 = 80 − 16).

**Elemente und Höchstpunkte (Tabelle 6.3.3; Schlüssel wie `valuation/immowertv_anlage1_2_2026`):**

| Element | Code | Höchstpunkte | Katalogbeitrag (4.2) |
|---|---|---:|---|
| Dacherneuerung inkl. Verbesserung der Wärmedämmung | `roof_insulation` | 4 | `daemmung_dach_steil`, `daemmung_dach_flach` 4; `daemmung_oberste_geschossdecke` 2 |
| Modernisierung der Fenster und Außentüren | `windows_doors` | 2 | `fenster`, `aussentueren` 2 |
| Modernisierung der Leitungssysteme (Strom, Gas, Wasser, Abwasser) | `pipes` | 2 | `leitungen` 2 |
| Modernisierung der Heizungsanlage (einschließlich Heizkörper und Verteilung) | `heating` | 2 | `heizung_*` 2; `heizungsverteilung` 2 (zusammen höchstens 2, F-24) |
| Wärmedämmung der Außenwände | `facade_insulation` | 4 | `daemmung_fassade` 4 |
| Modernisierung von Bädern | `bathrooms` | 2 | `baeder` 2 |
| Modernisierung des Innenausbaus | `interior` | 2 | `innenausbau` 2 |
| wesentliche Verbesserung der Grundrissgestaltung | `floor_plan` | 2 | `grundriss` 2 |

Die Koeffizienten der Zwischenzeilen (p ∉ {0, 8, 12, 18–20}) sind gegen den Primärtext zu prüfen (Teil C:
Qualität D; Offene Punkte 10). Kernsanierung: RND höchstens `core_renovation_rnd_max_share_of_gnd` · GND (0,9;
Bibliothek), nur als Prüfung (W bei Überschreitung durch `remaining_life_offset_years`).

#### 6.3.4 `market_growth`

V_0 = `base_value_eur` %||% W_0 %||% `building.market_value_eur` %||% Investitionsbasis (−Σ_t der Kategorien
`land`, `acquisition_cost`, `capex` im Basisfall, `ctx$component_base()`); V_t = V_0 · `ctx$index(growth)`_t ·
(1 + `uplift_share` · ω_t), ω_t = min über Maßnahmen von `aux$in_operation` (1 nach Fertigstellung aller Maßnahmen,
ohne Maßnahmen 0). Für Erwerbsprojekte ist die Investitionsbasis der Kaufpreis einschließlich Nebenkosten.

#### 6.3.5 `multiplier` und `exit_yield`

`multiplier`: V_t = factor · Fenster(`rent` (+ `modernization_levy` bei `net_cold_rent_incl_levy`)).
`exit_yield`: V_t = NOI-Fenster_t / cap_rate mit NOI = Kategorien mit `noi = TRUE` (Spec 00 §7.6) aus zahlungswirksamen
Zeilen; NOI ≤ 0 → V_t = 0 (I mit Anteil der Läufe).

#### 6.3.6 `asset_value` (Sachwert, linear)

```text
für jede capex-Komponente c (Maßnahmen) und KG k ∈ kg_include:
   Zahlungen P_c,k,u = aux$cost_kg<k> (bzw. aux$cost_total ohne Kostengruppen, Zuordnung über measures.<m>.kg)
   Herstellungswert zum Stichtag b_t:  H_c,t = Σ_{u ≤ t} P_c,k,u · I^av_t / I^av_u
   Alter α_c,t ab verschobener Fertigstellung; L = gnd_years (life_basis gnd) bzw. Nutzungsdauer der Maßnahme
   Zeitwert Z_c,t = H_c,t · max(0, 1 − α_c,t / L)        (vor Fertigstellung: H_c,t, Bauzeitwert)
Bestand (include_existing, W_0 gesetzt): E_t = max(W_0 − BW_0, 0) · I^av_t · max(0, 1 − τ_t / max(GND − a_0, 1))
Gebäude:  G_t = (Σ_c Z_c,t + E_t) · (1 + uplift_share) · market_adjustment_factor
V_t = G_t + BW_t
```

Kaufpreis des Gebäudeanteils (`erwerb_*`, Zeile `price_building`) zählt als Bestand mit W_0 := Kaufpreis
(Gebäudeanteil), Alter a_0 nach `construction_year`.

#### 6.3.7 `component` (Komponenten-Zeitwert)

V_t = Σ_r Wertpfad_r,t über alle `replacement`-Komponenten der Maßnahmen + [include_land] · BW_t + Bestand_t mit:

- **Wertpfad:** bei `indexed: true` `aux$value` (Buchwert der letzten Investition × Baupreisindex vom Investitionstermin
  bis b_t, Konzept 3.11), bei `indexed: false` `aux$value_nominal` = **nominaler Buchwert** C_last · max(0, 1 − α_t/L)
  (Spec 00 §4.12 Nr. 8, R-108; 4.10.2). Bauteile `m_<e>_repl` zählen nur mit `include_existing`.
- **Bestand_t** (gemäß `include_existing`; `auto`: wenn `building.existing_value_eur` gesetzt ist oder ein Erwerb
  vorliegt) = W_0 · `ctx$index(existing_growth)`_t. Bei einem Erwerb (`erwerb_objekt`) tritt an die Stelle von W_0 der
  Gebäudeanteil des Kaufpreises (Basisfallwert `purchase_price_eur · (1 − land_share)`, Index ab dem Erwerbstermin, wie
  6.3.6); der Bodenanteil zählt nur über `include_land`, Erwerbsnebenkosten zählen nicht.
- **Erwerbsmaßnahmen** (`erwerb_grundstueck`, `erwerb_objekt`; Typen `land`, `acquisition_cost`) sind keine
  Maßnahmen-Zeitwerte und haben keine Nutzungsdauer (X-26). Teile der Herstellung ohne eigene Nutzungsdauer
  (`rueckbau`, `herrichten_erschliessung`, `baunebenkosten`) erhalten die Nutzungsdauer der Hauptmaßnahme bzw. die GND
  (4.5.1 Nr. 4) und werden damit abgeschrieben. Eine Maßnahme ohne Nutzungsdauer (nur `sonstige` ohne Angabe) geht mit
  ihrem Herstellungswert ohne Abschreibung ein (I `validation.residual.no_useful_life`).

Dieselbe Summe ohne Boden, ohne Bestand und ohne Erwerb ist der Pfad `rv_basis = measures` (6.5), unabhängig von der
gewählten Methode.

#### 6.3.8 `user_value`

V_t = `value_eur` (Pfad bzw. Konstante in allen t); `market_value` = V_t.

### 6.4 Doppelzählung und Konsistenz

| Fall | Regel |
|---|---|
| Ertragswert + Komponenten-Zeitwert | Der Ertragswert kapitalisiert die Wirkung der Maßnahmen bereits (Miete, BWK, Punkte). `bog_component_residual: true` → W `validation.residual.double_count`. Der Pfad `rv_basis = measures` ist davon unberührt (eigene Sicht, Spec 00 §4.12 Nr. 8). |
| Ertragswert mit `admin_source/maintenance_source: ledger` | keine Doppelzählung mit dem Modellansatz; nur eine Quelle je Größe |
| Sachwert + Bestandswert | Bestand nur über `include_existing`; Bestandsbauteile (`m_<e>_repl`) nicht zusätzlich (I) |
| Komponenten-Zeitwert ohne Bestand trotz Sacheinlage | W (6.1, `include_existing: false`) |
| Ersatzinvestition kurz vor T | Zeitwert hoch, Ertragswert unverändert: Hinweis im Bericht (Konzept 3.11), kein Befund |
| Methode `zero` | Ausweis „ohne Restwert“ ist ohnehin immer aktiv (Spec 00 §12.5); `market_value` null → LTV NA (`no_market_value`) |

### 6.5 Zeilen der Komponente `rv_value`

| lokale Zeile | section / category | kind | Spalten | Inhalt | tax_category | Extra |
|---|---|---|---|---|---|---|
| `value` | project / `residual_value` | flow | nur T | +V_T | `disposal_proceeds` | asset `<bid>_building` |
| `sale_cost` | project / `sale_cost` | flow | nur T | −`sale_cost_share` · V_T | `disposal_proceeds` | – |
| `market_value` | memo / `market_value` | stock | 0…T | V_t (vor Verkaufskosten) | `not_applicable` | – |
| `path_method` | memo / `residual_path` | stock | 0…T | RW_t = V_t · (1 − c) | `not_applicable` | `rv_basis = "method"` |
| `path_measures` | memo / `residual_path` | stock | 0…T | (Σ Zeitwerte der Maßnahmen und Ersatzinvestitionen, 6.3.7, ohne Boden, Bestand und Erwerb) · (1 − c) | `not_applicable` | `rv_basis = "measures"` |

Es gilt RW_T(method) = `value` + `sale_cost` in T (Spec 00 §4.12 Nr. 8, Vertragstest). Bei a_m = 0 tragen die
Maßnahmen nichts bei (ihre `aux` sind null).

### 6.6 Validierung

| Bedingung | Klasse, Schlüssel |
|---|---|
| `income_value`/`asset_value` ohne Bodenwert | E `validation.residual.land_value_missing` |
| `income_value` mit `anlage2`/`linear` ohne Baujahr | E `validation.residual.construction_year_missing` |
| `income_value` ohne Mietzeilen (Selbstnutzer) | W `validation.residual.no_rent` (Vorschlag `asset_value`/`component`) |
| RE − BW · LZ ≤ 0 in T | I (Liquidationswert greift bzw. Gebäudewert ≤ 0) mit Anteil der Läufe |
| Punkte eines Elements > Höchstpunkte | Kappung, W |
| `fictitious_construction_year` und Punkte > 0 | W („fiktives Baujahr und Modernisierungspunkte doppelt“) |
| V_T < 0 | E (`vofi_error_contract`, Vorzeichen Kategorie) – kann wegen Kappung nicht auftreten |
| Methode `multiplier` mit `factor` > 35 | W |
| Overlay- oder Designziel `residual_value.income_value.remaining_life_years` bei `remaining_life_method ≠ manual` | E `validation.residual.rnd_target` (Vorschlag `remaining_life_offset_years`; R-109, N-20) |
| Maßnahme ohne Nutzungsdauer bei `component` bzw. `rv_basis = measures` | I `validation.residual.no_useful_life` |

### 6.7 Tests (WS-E, `test-type-flow-residual-value.R`; Werte mit `t_rv.py`)

| Nr. | Fall | Erwartung |
|---|---|---|
| RV1 | Memo 02 Rechenbeispiel 7: RE 60.338, BW 200.000, LZ 3 %, n = 50 | KF 25,729764; EW 1.598.103,92 (`general` = `simplified`) |
| RV2 | Anl. 2, GND 80, Alter 56: Punkte 0 / 8 / 12 / 18 | RND 24,0 / 38,0 / 45,9968 / 58,56; Alter 94 (gekappt 80): 4 P. 21,304, 12 P. 41,456; Alter 30, 0 P.: 50 (linear, 0,375 < 0,60); Stetigkeit p = 8, Alter 16: 64,0 |
| RV3 | Jahresraster T = 3 (2027–2029); Periode 3: Miete 100.000, Mietausfall −3.000, CO2-Kosten Vermieter −1.000; Wachstum Erträge und Kosten 2 %; 10 WE, 700 m², BWK-Modellwerte 367/14,40 mit `bwk.price_base_year: 2025`, Inflation 2 % (I^bwk_T = 1,08243216); MAW 2 %; BW_0 200.000, Bodenwertwachstum 1,5 %; LZ 3 %; RND_T = 40 (`manual`), `sale_cost_share` 3 % | RoE_T 102.000,00; Verwaltung 3.972,53; Instandhaltung 10.910,92; MAW 2.040,00; CO2 1.020,00; Leerstand über MAW 1.020,00; BWK 18.963,44; RE 83.036,56; BW_T 209.135,68; KF 23,114772; V_T = EW 1.983.483,07; `sale_cost` −59.504,49; RW_T 1.923.978,58; Pfad V_2 (Fenster = Periode 3, RND 41, KF 23,412400): RE 81.408,39, V_2 1.967.290,55 |
| RV4 | `multiplier` 20 auf RV3 | V_T 2.040.000 |
| RV5 | `exit_yield` 5 % auf RV3 ohne BWK-Modell (NOI-Fenster 102.000 − 3.060 − 1.020) | V_T 1.958.400 |
| RV6 | `asset_value` (Selbstnutzer-Neubau S5-ähnlich): Herstellung 500.000 Preisstand Stichtag, Fertigstellung 2027-12-01 (Zahlung t = 1, Baupreisindex 3 %), GND 80, `uplift_share` 0,03, BW_0 150.000 mit 1,5 %; Jahresraster H = 30 | Zahlung 515.000; Alter am Horizont 29,083333; Anteil 0,636458; Gebäude 772.425,71; mit Zuschlag 795.598,48; BW_T 234.462,03; V_T 1.030.060,52 |
| RV7 | `market_growth` V_0 400.000, Wachstum 1,75 %, T = 25 | V_T 617.192,21 |
| RV8 | `component` mit R1 (4.10.3) | indexiert V_30 114.688,15; `indexed: false` (nominaler Buchwert, R-108, N-24) 82.853,16 (= 220.941,76 · 0,375; vorher fälschlich 47.250,00 = Preisstand b*, F-09) |
| RV9 | Methode `zero` | `value`, `sale_cost`, `market_value`, `path_method` ≡ 0; `path_measures` wie RV8 (indexiert) × 0,97 = 111.247,51 |
| RV10 | RV3 mit a_m = 0 für alle Maßnahmen | `path_measures` ≡ 0 |
| RV11 | `component`, `indexed: false`, Preisindex 0, Jahresraster ab 2027-01-01, H = 30: `neubau` 1.000.000 mit `follows_construction` und `baunebenkosten` 200.000, beide Fertigstellung 2027-12-01; zusätzlich `erwerb_grundstueck` 300.000 | Nutzungsdauer der Baunebenkosten = Bezug auf die Neubau-Maßnahme (80, 4.5.1 Nr. 4); V_30 = 1.200.000 · (1 − 349/960) = 763.750,00; `path_measures` ohne den Grundstückskauf: 763.750,00 · 0,97 = 740.837,50 (X-26) |

---

## 7. Regelkatalog (paketübergreifend aufgerufene Regeln, Spec 00 §5.3, §17.3 Nr. 1)

| Regel | Datei / Eigentum | Version (gültig ab) | Signatur | Aufrufer | Inhalt |
|---|---|---|---|---|---|
| `grest` | `R/rules-grest.R`, WS-E (Tests `test-rules-grest.R`) | `@2025-07-01` (Thema `grunderwerbsteuer`) | `grest(basis_eur, federal_state, rate, P)` → n-Vektor EUR, `returns: "sim"`; keine Defaults, kein `ctx` (Spec 00 §5.3, N-19) | `acquisition_cost` (4.8) | Satz je Land aus `P$rates` (`legal/grunderwerbsteuer_2026`), Freigrenze `P$exemption_threshold_eur` 2.500 € (Basis ≤ Grenze → 0); `rate` ≠ `NA` gewinnt |

Die Restnutzungsdauer nach Anl. 2 ist **keine** registrierte Regel, sondern eine interne Funktion
`rv_rnd_anlage2(age, points, gnd, table)` in `R/type-flow-residual-value.R`; die Koeffizienten kommen als
deterministischer Parameter `rnd_table` aus der Bibliothek (Gültigkeit über deren `valid_from`). Damit braucht Teil A
keine neue Regeldatei. Die Ableitungsregeln aus 1.4 (`rule:<name>`) sind keine Registry-Regeln und stehen deshalb nicht
in diesem Katalog (Spec 00 §4.7, §5.3, R-86).

---

## 8. Vokabulare und Bibliothek

### 8.1 Vokabulare (Integrator, `inst/vocab/*.yaml`; Antrag S01A-09 entschieden, R-89)

| Vokabular | Codes | Abschnitt |
|---|---|---|
| `measure_types.yaml` | genau die 37 Codes aus Tabelle 4.2, keine Sammelcodes (Spec 00 §2.11, N-01; Phase-0-Nacharbeit P0-01) | 4.2 |
| `enums.yaml: federal_state` | `BW`, `BY`, `BE`, `BB`, `HB`, `HH`, `HE`, `MV`, `NI`, `NW`, `RP`, `SL`, `SN`, `ST`, `SH`, `TH` (Schlüssel von `legal/grunderwerbsteuer_2026`; X-27) | 1.2, 4.8 |
| `enums.yaml: building_type` | `EFH`, `ZFH`, `DHH`, `RH`, `MFH`, `ETW` | 3.1 |
| `enums.yaml: component_area` | `roof`, `pitched_roof`, `flat_roof`, `top_ceiling`, `facade`, `windows`, `doors`, `basement_ceiling`, `floor_slab`, `partition_unheated` | 3.1.1 |
| `enums.yaml: payment_profile` | `linear`, `s_curve`, `front`, `back` | 0.3, 4.6 |
| `enums.yaml: construction_delay_mode` | `none`, `last`, `stretch` | 4.6 |
| `enums.yaml: maintenance_basis` | `auto`, `rate`, `iibv`, `share_of_cost`, `none` (`auto` nur im Domänenblock, aufgelöst durch `rule:maintenance_from`; `share_of_cost` nur am Typ) | 3.3, 4.11 |
| `enums.yaml: overdue_policy` | `first_period`, `valuation`, `skip` | 3.2, 4.10 |
| `enums.yaml: remaining_life_method` | `anlage2`, `linear`, `manual` | 6.1 |
| `enums.yaml: income_basis` | `forward`, `trailing` | 6.1 |
| `enums.yaml: modernization_element` | `roof_insulation`, `windows_doors`, `pipes`, `heating`, `facade_insulation`, `bathrooms`, `interior`, `floor_plan` | 6.3.3 |
| `enums.yaml: modernization_kind` | Teil B §1.4 | 4.3 |
| `enums.yaml: quantity_per` | `total`, `unit`, `m2_living_area`, `m2_net_floor_area`, `m2_component:<b>`, `parking`, `kw`, `kwp`, `kwh` (R-91) | 3.5 |
| `units.yaml` | unverändert | – |

Die weiteren Enums aus R-89 (`levy_procedure`, `bgb_procedure`, `overlay_apply`, `growth_index`, `mc_preset`),
`rule_returns: value` und `na_reasons: no_liquidity_limit` pflegt der Integrator nach Spec 00 §2.11 (P0-02, P0-03).
Teil A verwendet davon `no_liquidity_limit` (1.4, 5.7); Wachstumsformen kommen in den Defaults dieses Teils nur als
Marktpfade vor (Kalenderjahreswert, `index: calendar_year`, N-27).

### 8.2 Verwendete Bibliothekseinträge (Inhalt Teil C §3)

`prices/macro_paths_2026`, `prices/interest_rates_2026_10`, `prices/co2_price_paths_2026`, `prices/energy_prices_2026`,
`prices/eeg_feed_in_2026`, `legal/grunderwerbsteuer_2026`, `legal/umsatzsteuer_2026` (PV-Schwelle, 4.5.1 Nr. 5),
`costs/massnahmentypen_2026` (Schema 8.3), `costs/bewirtschaftung_immowertv_2026`, `costs/bewirtschaftung_ii_bv_2026`
(N-02), `costs/kostenzuschlaege_2026`, `costs/nutzungsdauern_2026`, `costs/wartung_instandsetzung_vdi2067_2026`,
`costs/erwerbsnebenkosten_2026`, `valuation/liegenschaftszinsen_2026`, `valuation/immowertv_anlage1_2_2026`,
`valuation/verkaufskosten_2026`, `valuation/kaufpreisfaktoren_2026`. Alle `from`/`use`-Verweise aus 2.2 wurden in
Runde 3 gegen Teil C §3.6–3.8 geprüft; offen ist nur die Schlüsselbenennung von `costs/erwerbsnebenkosten_2026`
(OP-20) und die Ergänzung der Preise für `lpg`, `power_mfh` in `prices/energy_prices_2026` (N-15, Teil C).

### 8.3 Schema des Eintrags `costs/massnahmentypen_2026` (Datenträger WS-L, Inhalt Teil C §3.7)

Der vollständige Eintrag mit allen 37 Typen der Tabelle 4.2 steht in Teil C §3.7 (N-30); Teil A legt das Schema fest,
das `rule:measure_catalog` (4.5.1) liest. Eintragsschema nach Spec 00 §4.9 und Teil C §3.1 (`block: costs`). Je Typ
unter `values.types.<code>`:

| Schlüssel | Art | Pflicht | Bedeutung (Spalte in 4.2) |
|---|---|---|---|
| `kg` | int ∈ {100, …, 700} bzw. `null` (`sonstige`) | ja | KG |
| `asset_type` | Code aus `asset_types.yaml` bzw. Liste (`erwerb_objekt`: `[gebaeude_wohnen, grund_boden]`) | ja | `asset_type` |
| `classification_existing` | `erhaltung`, `herstellung`, `auto`, `main` (wie Hauptmaßnahme) bzw. `null` (Erwerb) | ja | Klass. Bestand |
| `useful_life_key` | Schlüssel in `costs/nutzungsdauern_2026` | nein | ND über die Bibliothek (4.3) |
| `useful_life_years` | number | nein | ND ohne Bibliotheksschlüssel (z. B. `innenausbau` 30, `instandsetzung` 25) |
| `useful_life` | `main` | nein | ND der Hauptmaßnahme (`rueckbau`, `herrichten_erschliessung`, `baunebenkosten`; 4.5.1 Nr. 4) |
| `ohnehin_share` | share bzw. `null` (Angabe nötig) | ja | Ohnehin |
| `modernization_kind` | Code (Teil B §1.4) | ja | `modernization_kind` |
| `points` | Map Element → Punkte (Tabelle 6.3.3) | nein | Anlage-2-Element |
| `vat_rate` | share | ja | USt (PV-Typen 0; Ableitung 4.5.1 Nr. 5) |
| `replacement` | lgl | ja | Ersatz |
| `repair_key` | Schlüssel in `costs/wartung_instandsetzung_vdi2067_2026` (gelesen: `repair`) | nein | Instandsetzung (Vorschlag, nicht automatisch gesetzt; X-10) |

Höchstens einer von `useful_life_key`, `useful_life_years`, `useful_life` (keiner: Typ ohne Nutzungsdauer, nur Erwerb
und `sonstige`). Prüfung in `test-library.R` (WS-L): Typschlüssel = die 37 Codes von `measure_types.yaml`; Codes in
`asset_type`, `classification_existing`, `modernization_kind` und den Schlüsseln von `points` sind Vokabularcodes (Spec 00
§2.11); jeder `useful_life_key` und `repair_key` existiert im Zieleintrag.

```yaml
id: costs/massnahmentypen_2026
block: costs
schema_version: 1
label: "Maßnahmentypen: Katalogdefaults (KG, Anlagenart, Klassifikation, Nutzungsdauer, Ohnehin-Anteil, Modernisierungsart, Punkte)"
source: {document: "Spec 01 Teil A §4.2; Memo 03 §6.5, §9; Memo 06 §7.5; ImmoWertV Anl. 2", url: "docs/spec/01a_feldkatalog_projekt_investition_finanzierung.md", publisher: "eigene Ableitung"}
as_of: 2026-10-26
valid_from: 2026-01-01
valid_to: null
quality: D
legal_state: {as_of: 2026-10-26, status: derived, reference: "Spec 01 Teil A §4.2"}
values:
  types:
    daemmung_fassade: {kg: 300, asset_type: gebaeude_wohnen, classification_existing: erhaltung, useful_life_key: etics,
                       ohnehin_share: 0.50, modernization_kind: bgb_555b_1, points: {facade_insulation: 4},
                       vat_rate: 0.19, replacement: true}
    heizung_waermepumpe_luft: {kg: 400, asset_type: gebaeude_wohnen, classification_existing: erhaltung,
                       useful_life_key: hp_air_water, ohnehin_share: null, modernization_kind: bgb_555b_1a,
                       points: {heating: 2}, vat_rate: 0.19, replacement: true, repair_key: heat_pump}
    heizungsverteilung: {kg: 400, asset_type: gebaeude_wohnen, classification_existing: erhaltung,
                       useful_life_key: heating_distribution, ohnehin_share: null, modernization_kind: bgb_555b_1,
                       points: {heating: 2}, vat_rate: 0.19, replacement: true}          # F-24: heating statt pipes
    baunebenkosten:   {kg: 700, asset_type: gebaeude_wohnen, classification_existing: main, useful_life: main,
                       ohnehin_share: 0, modernization_kind: none, vat_rate: 0.19, replacement: false}   # X-26
    pv:               {kg: 400, asset_type: pv_anlage, classification_existing: herstellung, useful_life_key: pv_modules,
                       ohnehin_share: 0, modernization_kind: none, vat_rate: 0, replacement: true}
    erwerb_objekt:    {kg: 100, asset_type: [gebaeude_wohnen, grund_boden], classification_existing: null,
                       ohnehin_share: null, modernization_kind: none, vat_rate: 0, replacement: false}
    # … je Zeile der Tabelle 4.2 ein Eintrag (37 Typen), vollständig in Teil C §3.7
```

---

## 9. Validierungsschlüssel (Übersicht für WS-B, `inst/labels/de/validation.yaml`)

Alle Validierungsmeldungen dieses Teils stehen in `inst/labels/de/validation.yaml` (WS-B) unter `validation.<block>.<code>`
bzw. blockübergreifend unter `validation.<code>` (Spec 00 §2.10, R-104, N-17); andere Dateien (früher hier
`inst/i18n/de.yaml`) oder Namensräume gibt es nicht. Schlüssel ohne Präfix `validation.`:

- `measures`: `timing`, `cost_source`, `schedule_sum`, `schedule_amount_form`, `before_valuation`, `completion_order`,
  `kg800`, `kg700_double`, `cost_risk_double`, `cost_derived`, `active_fraction`, `type_project_mismatch`,
  `catalog_defaults`, `pv_vat_conflict`, `pv_vat_unchecked`, `kind_from_classification`, `kind_ohnehin_conflict`
- `building`: `element_cost_missing`, `no_existing_value`, `existing_value_with_purchase`, `negative_in_kind`,
  `in_kind_land`
- `acquisition`: `federal_state_missing`, `grest_inactive`
- `variants`: `existing_value_changed`, `existing_debt_changed`
- `maintenance`: `double_count`, `replacements_excluded`, `default_rate`, `service_double`, `service_double_energy`
- `quantity`: `reference_missing`
- `financing`: `existing_forbidden`, `negative_amortization`, `draws_exceed`, `tau_with_installment`,
  `balloon_at_maturity`
- `accounts`: `liquidity_unchecked` (Spec 00 §12.3, N-17)
- `residual`: `land_value_missing`, `construction_year_missing`, `no_rent`, `double_count`, `rnd_target`,
  `no_useful_life` (Namensraum wörtlich nach N-17/N-20; zum Blocknamen `residual_value` OP-16)
- blockübergreifend: `profile_path_forbidden`, `reference_variant_missing` (Spec 00), `unknown_key`

Geändert in Runde 3: `validation.elements.cost_missing` → `validation.building.element_cost_missing`;
`expand.catalog_defaults` → `validation.measures.catalog_defaults` (die Vorbelegung ist eine WS-A-Ableitungsregel);
entfallen sind `validation.measures.cost_target_redirected` (S01A-08 abgelehnt) und
`validation.accounts.limit_infinite_wu` (ersetzt durch `liquidity_unchecked`). Laufzeitmeldungen der Typen stehen unter
`types.flow.<typ>.msg.<code>` in `inst/labels/de/types/flow/<typ>.yaml` (`after_horizon`, `liquidation_floor`,
`noi_nonpositive`; Spec 00 §2.10).

---

## 10. Offene Punkte

| Nr. | Thema | Stand / Vorschlag | Betroffen |
|---|---|---|---|
| OP-01 | **Anl.-2-Koeffizienten der Zwischenzeilen** (p = 1–7, 9–11, 13–17) | aus Fachkenntnis rekonstruiert, Stützzeilen 0, 8, 12, 18–20 und Prüfwerte nach Memo 02 bestätigt; vor Freigabe gegen ImmoWertV 2021 Anl. 2 prüfen (Teil C: Qualität D je Zeile) | 6.3.3, WS-L |
| OP-02 | ~~Referenzwert S3-T8~~ | **erledigt:** Teil C S3 setzt `component.indexed: false`; nach R-108 ist das der nominale Buchwert (N-24, RV8) | – |
| OP-03 | ~~Preisstand „Kostenstand Y“~~ | **erledigt:** Teil C §5.0 Nr. 4 setzt `price_base_year: Y − 1` (Spec 00 §4.3.2) | – |
| OP-04 | **Zwei Preisstand-Konventionen**: Jahresbeträge „für das Jahr Y“ (`maintenance`, Teil B Verwaltung) mit `price_base_year: Y`; Stichtagswerte „Stand 01.01.Y“ (BWK im Restwert) mit `price_base_year: Y − 1` | Folge von R-35/R-62; dokumentiert in 4.11.2 und 6.1; Bestätigung durch den Integrator steht aus | 2.2, 4.11, 6.3.3 |
| OP-05 | **GrESt-Eintrag Qualität C** (`legal/grunderwerbsteuer_2026`) | automatische Wahl nur mit `release.status: released` (R-80); sonst Thema inaktiv und E `validation.acquisition.grest_inactive`. Teil C/Auftraggeber: Freigabe oder Prüfung der Sätze am Landesrecht | 4.8 |
| OP-06 | ~~`preset`~~ | **erledigt** (R-97, S01C-14): `global.yaml` setzt `preset: standard`, kein `n_sim`, dazu `convergence` (2.2). Der F21-Modus (`replicates`) bleibt nach Spec 00 §17.3 Nr. 5 offen; bei Bestätigung Default in 2.2 und Teil C gemeinsam umstellen | 2.2 |
| OP-07 | **Kreditlimit WU** | entschieden (R-101, X-30): Profilwert `.inf` bleibt (Konzept A2 nennt keine Zahl); `restriction_liquidity` ist dann NA `no_liquidity_limit` (kein K.-o.) mit W `validation.accounts.liquidity_unchecked`; eine projektbezogene Kreditlinie bzw. Warnschwelle wird empfohlen. Offen ist nur, ob der Auftraggeber eine Standardschwelle (z. B. in % der Investition) wünscht | 2.3–2.5, 5.7 |
| OP-08 | **Ertragsfenster** `income_basis: forward` (nächste 12 Monate) gegenüber Stichtagsniveau der ImmoWertV („marktüblich erzielbar zum Stichtag“) | Default `forward` (enthält die Mietentwicklung des Folgejahres); Alternative `trailing`; fachliche Bestätigung | 6.3.1 |
| OP-09 | **Alterung der Modernisierungspunkte** (`points_decay_years`) | keine Rechtsgrundlage für eine starre Frist; Default `NULL` | 6.3.3 |
| OP-10 | **Ohnehin-Anteil der Heizungstypen** (Katalog `NULL`) | Referenzanlage im Einzelfall; Angabe von `ohnehin_cost_eur` bzw. Referenzvariante empfohlen (W) | 4.2 |
| OP-11 | **KG 200 steuerlich** (Erschließungsbeiträge Grund und Boden vs. Hausanschlüsse Gebäude) | Default `capex_depreciable`, Schalter `tax_category_kg200`; ohne Wirkung mit `tax_none` | 4.6 |
| OP-12 | **Sachwert des Bestands** (`asset_value.include_existing`) | vereinfachte lineare Fortschreibung von W_0 − BW_0 über die Rest-GND; genauere Behandlung (Sachwertfaktor des Bestands) v2 | 6.3.6 |
| OP-13 | ~~Overlay-Ziele aus Teil C auf abgeleitete bzw. leere Felder~~ | **entschieden** (S01A-08 abgelehnt, R-109, N-20): keine Umlenkung; Teil C zielt auf `cost_factor` bzw. `remaining_life_offset_years`; sonst E mit Vorschlag (4.6.1, 6.1) | – |
| OP-14 | **Ersatz unmittelbar vor T** | Komponenten-Zeitwert springt, Ertragswert nicht; nur Berichtshinweis (Konzept 3.11) | 6.4 |
| OP-15 | **Vertragsfrequenz und TZ-Wirkung KfW** | Teil C: `payments_per_year` Qualität D, `effect` C; Merkblatt prüfen | 5.2 |
| OP-16 | **Namensraum `validation.residual.*`** (N-17, N-20) gegenüber dem Blocknamen `residual_value` (Spec 00 §2.10: `<block>` = oberster Szenarioblock) | Teil A übernimmt `residual` wörtlich aus N-17/N-20; der Integrator bestätigt die Abkürzung oder benennt einheitlich um | 9, WS-B |
| OP-17 | **Code aus Basisfallwerten** (X-09) | `modernization_kind: none` bei Ohnehin-Anteil 1 wertet numerische Blätter mit `bctx$value_base()` aus; Spec 00 §4.7 lässt für Ableitungsregeln nur Termine, Codes, Flags und Rechts-/Bibliothekswerte zu → Antrag S01A-11 | 4.5.1 Nr. 6 |
| OP-18 | **Varianten auf Pfade aus `item_defaults` bzw. Ableitungsregeln** | Existenzprüfung in Schicht 7 läuft vor diesen Stufen → Antrag S01A-10; bis dahin Map-Merge am Elternpfad (2.1, XM13) | 2.1 |
| OP-19 | **`sonnenschutz`** (sommerlicher Wärmeschutz, BAFA-förderfähig) | in v1 kein Code (Spec 00 §17.3 Nr. 8 a); Aufnahme als 38. Code in v1.1 mit Katalogzeile (Vorschlag: KG 300, `gebaeude_wohnen`, `erhaltung`, ND 20, Ohnehin 0, `bgb_555b_1`, keine Anl.-2-Punkte, Ersatz ja) und Antrag von Teil A; in Runde 3 kein Antrag | 4.2, Teil C §3.4 |
| OP-20 | **Schlüssel von `costs/erwerbsnebenkosten_2026`** (X-19) | Teil A liest `notary_share` (0,010), `land_registry_share` (0,005) und nennt `broker_share` (0,0357), `other_share` (0,005) als Vergleichswerte; der Eintrag führt noch `cost_notary_land_registry_share` (0,015), `cost_broker_buyer_share`, `cost_due_diligence_share`; Umbenennung durch Teil C (WS-L); bis dahin setzt `rule:measure_catalog` die Tabellenwerte 0,010 und 0,005 (Herkunft `rule:measure_catalog`, I `validation.measures.catalog_defaults`) | 4.1, 4.5.1, Teil C §3.7 |
| OP-21 | **PV-Umsatzsteuer von Komponenten ohne `energy.pv`** | Katalogwert 0 mit Hinweis; fachlich prüfen, ob Speicher und Wechselrichter ohne zugehörige, im Szenario beschriebene Anlage den Nullsatz erhalten (§ 12 Abs. 3 Nr. 1 UStG) | 4.5.1 Nr. 5 |

## 11. Änderungsanträge an Spec 00

Entschiedene Anträge tragen die Entscheidung der Runde 3 (Spec 00 §17.5.1); offene Anträge eine Übergangsregel, mit der
die WS-Pakete bis zur Entscheidung arbeiten.

| Nr. | Spec-00-Stelle | Antrag | Begründung | Entscheidung bzw. Übergangsregel |
|---|---|---|---|---|
| S01A-01 | §4.7 (Schichten 1–2), §2.2 (`inst/extdata/defaults`, `profiles`) | Reservierter Schlüssel `by_project_type` in `global.yaml` und Profilen: Teilbaum je `project.project_type`, gemischt unmittelbar nach der jeweiligen Datei; Profilrestriktion R-76 gilt auch dort; reservierter Schlüssel `defaults_meta` (wird nicht gemischt) | Konzept A3 gibt Horizont (Neubau 40 J.) und Restwertmethode je Anwendungsfall vor; ohne den Schlüssel bräuchte es Profile je Projektart | **entschieden: mit Änderung angenommen (R-85).** Zusätzlich reservierter Schlüssel `item_defaults` (nur `global.yaml`), `from:` in Vorlagen zulässig, Defaults optionaler Blöcke nur dort, Anwendung nach Pfadtiefe und **nach** den Ableitungsregeln; umgesetzt in 2.1, 2.2 |
| S01A-02 | §4.9 (Auflösung von `from:`) | Ist die Nutzlast ein Skalar oder eine Sequenz und gibt es keine lokalen Felder, ersetzt sie den Knoten | `global.yaml` bezieht Einzelwerte aus Teil-C-Einträgen (z. B. `presets.mid_city`, `maintenance_eur_m2_pa`) | **entschieden: angenommen (R-87).** Lokale Zusatzschlüssel sind dann ein Fehler; 2.1 |
| S01A-03 | §4.5 (Wertform `quantity`, Liste `per`) | zusätzliche Bezugsgrößen `m2_net_floor_area` (A_N) und `parking` | IWU-Kostenfunktionen je m² A_N (Memo 03 §6.2); Stellplatzkosten (BWK Garage, Teil C) | **entschieden: angenommen (R-91)** mit Abbildung `per` → Feld; 3.5 an Spec 00 angeglichen (`kw`/`kwp`/`kwh` = gleichnamige Felder, 4.1) |
| S01A-04 | §4.12 (Expandertabelle) | Zeile `measures` um `land`, `acquisition_cost`, `maintenance`, `replacement` für Bestandsbauteile ergänzen; Zeile `residual`: id `rv_value` | Teil A erzeugt diese Komponenten aus `measures` und `building` (4.5.2) | **entschieden: mit Änderung angenommen (R-90).** Spec 00 §4.12 ist jetzt die vollständige id-Liste (mit S01B-01); Höchstlängen der ids 4.5.2 Nr. 1 |
| S01A-05 | §6.4 (`bctx`) | Knotenkonstruktor `node_expr(text)` (wie `node_ref`) | §4.12 Nr. 2 und Nr. 7 verlangen `expr`-Knoten | **entschieden: angenommen (R-91)**; `bctx$node_expr()` (Spec 00 §6.4, P0-05) |
| S01A-06 | §4.7/§4.8, §4.12 Nr. 1 | Ableitungsregeln von WS-A nach Schicht 8 und vor den Expandern, füllen nur fehlende Domänenblätter, Herkunft `type_default`/`rule:<regel>` | Katalogdefaults müssen als Domänenpfade existieren (Overlay-Ziele, Teil B) | **entschieden: mit Änderung angenommen (R-86).** Reihenfolge Ableitungsregeln **vor** `item_defaults`; fehlendes Feld = `auto`; Bezüge auf später gefüllte Blätter zulässig; 1.4, 2.1, 4.5.1 |
| S01A-07 | §4.3.1, §4.3.2, §4.3.4, §4.3.6 (Auszüge) | Auszüge um die Felder dieses Teils ergänzen | Schemaprüfung braucht die vollständige Feldliste | **entschieden: mit Änderung angenommen (R-106).** Die Feldtabellen von Spec 01 sind maßgeblich; Spec 00 führt nur Auszüge |
| S01A-08 | §11.2 bzw. §4.7 (Overlay-Normalisierung) | Umlenkung von Overlay-Einträgen auf `cost_factor` bzw. `remaining_life_offset_years` | Teil C zielt auf abgeleitete bzw. leere Felder | **entschieden: abgelehnt (R-109, N-20).** Keine Umlenkung (Pfad-Identität); E `validation.measures.cost_derived` bzw. `validation.residual.rnd_target` mit Vorschlag; 4.6.1, 6.1 |
| S01A-09 | §2.11 (Vokabulare) | Codes nach 8.1 aufnehmen | Validierung der Enums (Ebene 2) | **entschieden: mit Änderung angenommen (R-89)**, ergänzt um `federal_state`, `levy_procedure`, `bgb_procedure`, `overlay_apply`, `growth_index`, `mc_preset`, `quantity_per`, `rule_returns`, `na_reasons`; 8.1 |
| S01A-10 | §4.11 (Existenzprüfung von `set`, `replace`, `overrides`) | Pfade, die nach Schicht 8 durch `item_defaults` oder eine Ableitungsregel angelegt werden, gelten für die Existenzprüfung der Varianten- und Set-Operationen als vorhanden, wenn ihr Elternelement existiert und der Pfad ein Feld der Feldtabelle bzw. der Vorlage ist; der gesetzte Wert gewinnt dann gegen Vorlage und Regel | Varianten wollen Katalog- und Vorlagenfelder einer Maßnahme gezielt ändern (z. B. `measures.wp.cost_factor`, `measures.wp.useful_life_years`); nach R-85/R-86 existieren diese Pfade in Schicht 7 noch nicht | Übergangsregel: Varianten setzen solche Felder über die Elternmap (`set: {measures.wp: {cost_factor: 1.2}}`, Map-Merge am existierenden Pfad, 2.1, XM13) |
| S01A-11 | §4.7 „Ableitungsregeln“ (zulässige Auswertungen), §6.4 (`value_base()`) | Ableitungsregeln dürfen einen **Code** (Enum-Feld ohne Overlay-Fähigkeit) aus Basisfallwerten numerischer Blätter ableiten (`bctx$value_base()`), wie Expander für Register und Anzeige-Tags (§4.12 Nr. 5 (a)) | `rule:measure_catalog` setzt `modernization_kind: none` bei Ohnehin-Anteil 1 (X-09, N-07); der Code ist deterministisch und wird an das Maßnahmenregister weitergereicht | Übergangsregel: WS-A wertet nur Konstanten aus (`ohnehin_share` als Zahl 1, `ohnehin_cost_eur` und Grundkosten als Zahlen); bei anderen Formen gilt nur Bedingung (a) aus 4.5.1 Nr. 6 |

---

## 12. Review-Protokoll Runde 3 (Feldkatalog-Abgleich, 26.10.2026)

Grundlage: Spec 00 in der Fassung mit R-85 bis R-109 (§16.3), §17.1 „Runde 3“ und §17.5 (Entscheidungen zu den
Änderungsanträgen, Befunde mit Spec-00-Bezug, Namens- und Eigentumsentscheidungen N-01 bis N-31, Phase-0-Nacharbeit).
Geprüft wurden alle Entscheidungen und alle Befunde mit Teil A im Geltungsbereich. **Übernommen** = Befund bzw.
Entscheidung gültig und umgesetzt; **teilweise** = gültig, mit anderer bzw. eingeschränkter Umsetzung (Begründung);
**ohne Änderung** = bereits erfüllt oder nicht Gegenstand von Teil A; **abgelehnt** = Befund nicht gültig. Neu
gerechnete Prüfwerte: Skripte `l1.py`, `l11.py` in `…/scratchpad/spec01-review/r3a/` (Monatsuhr nach Spec 00 §8.5/§8.6).

### 12.1 Entscheidungen zu den eigenen Änderungsanträgen (Spec 00 §17.5.1)

| Nr. | Entscheidung | Umsetzung in Teil A |
|---|---|---|
| S01A-01 | mit Änderung angenommen (R-85) | 2.1 neu gefasst (reservierte Schlüssel `defaults_meta`, `by_project_type`, `item_defaults`, Reihenfolge Ableitungsregeln → `item_defaults` → Expander); 2.2: Gebäude-Defaults nach `item_defaults.building`, neue Vorlagen `item_defaults.measures` und `item_defaults."building.elements"` |
| S01A-02 | angenommen (R-87) | 2.1 (lokale Zusatzschlüssel bei skalarer Nutzlast = Fehler) |
| S01A-03 | angenommen (R-91) | 3.5: Abbildung `per` → Feld wie Spec 00 §4.5; `kw`, `kwp`, `kwh` lesen gleichnamige Felder (bisher `power_kw`, `pv_kwp`, `energy_kwh`); neue Maßnahmenfelder `kw`, `kwp`, `kwh` in 4.1; Q5 angepasst, Q7 neu |
| S01A-04 | mit Änderung angenommen (R-90) | 4.5.2 Nr. 1 (Verweis auf die vollständige Liste Spec 00 §4.12) |
| S01A-05 | angenommen (R-91) | keine Textänderung nötig (Konstruktor in Spec 00 §6.4) |
| S01A-06 | mit Änderung angenommen (R-86, Reihenfolge geändert) | 1.4 neu gefasst (vor `item_defaults`, fehlend = `auto`, `layer = 0`), 2.1, 4.5.1 |
| S01A-07 | mit Änderung angenommen (R-106) | 4.1 Kopf (Feldtabellen maßgeblich) |
| S01A-08 | abgelehnt (R-109, N-20) | 4.6.1 und 6.1: Umlenkung gestrichen, E `validation.measures.cost_derived` bzw. `validation.residual.rnd_target` mit Vorschlag; `validation.measures.cost_target_redirected` entfällt; OP-13 geschlossen |
| S01A-09 | mit Änderung angenommen (R-89) | 8.1 (u. a. `federal_state`, `quantity_per`, `maintenance_basis` mit `auto`) |
| S01A-10 | neu (Runde 3) | 2.1, 11 – Existenzprüfung von Varianten für Pfade aus `item_defaults` und Ableitungsregeln |
| S01A-11 | neu (Runde 3) | 4.5.1 Nr. 6, 11 – Ableitung eines Codes aus Basisfallwerten (X-09) |

### 12.2 Namens- und Eigentumsentscheidungen (Spec 00 §17.5.3)

| Nr. | Ergebnis | Umsetzung in Teil A |
|---|---|---|
| N-01 | übernommen | 4.2 Kopf (genau 37 Codes, keine Sammelcodes, `sonnenschutz` nicht in v1); Tabelle unverändert 37 Zeilen; 8.1 |
| N-02 | übernommen | `costs/bewirtschaftung_ii_bv_2026` in 2.2, 3.3, 8.2 |
| N-04 | übernommen (Teil A) | 2.1: Datei als Vereinigung mit den `item_defaults`-Vorlagen von Teil B; Teil-B-Inhalte selbst nicht bearbeitet |
| N-05 | übernommen | 2.2: kein Block `building` mehr außerhalb von `item_defaults`; 3.1, 3.3; PR7, PR8 |
| N-07 | übernommen | 1.4 (Regelnamen unverändert; Inhalt `rule:measure_catalog` um PV-USt, PV-Leistung, `modernization_kind: none`, Hauptmaßnahme ergänzt; `rule:cost_from_kg` um Zahlungsplan `eur`; `rule:building_aggregates` umfasst `land_value_eur`, `market_value_eur`; `rule:maintenance_from` umfasst `basis`) |
| N-13 | übernommen | 0.2 (Terminregel R-98), 4.4 `effects.start`, 5.2 (`repayment_grant.date`, `t_tz`), L1 (Termin 2028-01-01 → t = 1) |
| N-15 | übernommen (Teil A) | 2.2: `market.energy_price` für alle 10 Träger aus der Bibliothek, `market.energy_network_fee.{gas,gas_mfh}.growth` über `shared.network_fee_growth_*` (0,03); Preise für `lpg`, `power_mfh` ergänzt Teil C |
| N-16 | übernommen | 2.2: `bund_yield_10y`, `mortgage_spread`, `operating_cost_growth` (über `macro_paths`), `feed_in_tariff.*`, neu `vacancy_fluctuation: 1` |
| N-17 | übernommen | Abschnitt 9 (Datei `inst/labels/de/validation.yaml`, Schema `validation.<block>.<code>`; `validation.accounts.liquidity_unchecked`, `validation.measures.cost_derived`, `validation.residual.rnd_target`); Abweichung zum Blocknamen als OP-16 |
| N-18 | übernommen | Testdateien `test-type-flow-capex.R`, `-acquisition-cost.R`, `-replacement.R`, `-maintenance.R`, `-residual-value.R`, `-equity.R`, `-custom-series.R`, `-recurring.R`, `-share-of.R`, `test-type-inst-loan-core.R`, `test-rules-grest.R`; `test-profiles.R` (WS-A) |
| N-19 | übernommen | 4.8, 7: `grest(basis_eur, federal_state, rate, P)` ohne Defaults, `returns: "sim"` |
| N-20 | übernommen | 4.6.1, 4.6.5, 6.1, 6.6, OP-13 |
| N-22 | übernommen | 2.2: `foerderstopp` und `vorsichtig` wörtlich nach Teil C §4.2 (Label, Beschreibung, `params: auto`, `exclude: []`) |
| N-23 | übernommen | 3.2, 4.1, 4.5.2 Nr. 1 (≤ 29 statt ≤ 33), XM12 |
| N-24 | übernommen | 4.10.2, 6.1, 6.3.7, RV8 = 82.853,16 |
| N-25 | übernommen | 5.2 (`initial_repayment_pa`, `refi_rule`), 5.5, L1 neu gerechnet, L11 neu |
| N-27 | ohne Änderung | Teil A nutzt Wachstumsformen nur als Marktpfade der Bibliothek (Kalenderjahreswert); Typen schreiben Stichtagsgrößen über `ctx$index()` fort; 8.1 |
| N-29 | ohne Änderung | `grest` bleibt WS-E; Ableitungsregeln WS-A (1.4) |
| N-30 | übernommen (Teil A) | 4.2, 4.3, 4.5.1 Nr. 1, XM1 (Herkunft `costs/nutzungsdauern_2026`), 8.3 als Schema; vollständiger Eintrag in Teil C |
| N-03, N-06, N-08 bis N-12, N-14, N-21, N-26, N-28, N-31 | ohne Änderung | betreffen Teil B bzw. Teil C; Teil A verweist nur (z. B. 4.3 auf Teil B §1.4) |

### 12.3 Befunde

| Nr. | Ergebnis | Prüfung und Umsetzung in Teil A |
|---|---|---|
| X-01 / F-03 | ohne Änderung (bestätigt) | Teil A §4.2 ist die einzige Codequelle mit 37 Codes; die falschen Codes standen in Teil C und Spec 00 Anhang B (dort korrigiert). Klarstellung in 4.2 Kopf |
| X-05 | übernommen (a) | id `costs/bewirtschaftung_ii_bv_2026` (N-02); alle übrigen `from`/`use`-Verweise aus 2.2 gegen Teil C §3.6–3.8 geprüft (lösen auf); PR7 prüft das. (b) betrifft Teil B |
| X-06 | übernommen (Teil A) | 2.1, 2.2 (`item_defaults`, Datei als Vereinigung); Profile setzen weiterhin nur R-76-Pfade |
| X-09 | übernommen | 4.5.1 Nr. 6: `modernization_kind: none` bei ausdrücklicher `classification: erhaltung` bzw. Ohnehin-Anteil 1; I `kind_from_classification`, W `kind_ohnehin_conflict`; XM9. Bedingung (a) nur für ausdrücklich angegebene Klassifikation, weil die steuerliche Katalogklassifikation `erhaltung` im Bestand auch energetische Modernisierungen trifft. Auswertung des Ohnehin-Anteils über Basisfallwerte: Antrag S01A-11 |
| X-10 | übernommen | 4.2 Spalte „Instandsetzung“ nur `repair` (WP 0,010, Gas 0,010, Pellet 0,020, Lüftung 0,015, Fernwärme 0,010, PV 0); 3.3, 4.3, 4.4, 4.11, 4.11.4 neue W `validation.maintenance.service_double_energy`; M4 neu (−320) |
| X-11 | übernommen (in der Fassung von R-98) | eine Konvention: Einmalzahlungen als Datumstermin nach R-35 (0.2, 5.2); der Vorschlag „Monatsereignis in p(m)“ ist durch R-98 abgelehnt. Teil A war bereits datumsbasiert (ZP, `shift_period`), nur Texte präzisiert |
| X-13 | übernommen | 5.2: E nur τ + `installment_eur`, I bei τ + `term_years`; 5.5; L11 |
| X-14 | ohne Änderung | Teil A verlangte bereits ≥ 0 (4.1, 3.2, 1.2); Hinweis auf den früheren Basistermin in 0.2, 4.1, 3.2; Umbau von S4 ist Sache von Teil C (N-26) |
| X-15 | übernommen (Teil A) | XM1 (Herkunft `costs/nutzungsdauern_2026`), 4.3, 8.3 als vollständiges Schema; Inhalt der 37 Zeilen liefert Teil C (N-30) |
| X-19 | übernommen (Teil A) | `use`-Pfade genannt: `share_kg700_of_kg300_400`, `contingency_share` (`costs/kostenzuschlaege_2026`), `notary_share`, `land_registry_share` (`costs/erwerbsnebenkosten_2026`); Umbenennung im Eintrag durch Teil C (OP-20) |
| X-20 | übernommen | ≤ 29 Zeichen (N-23), Prüfung jeder erzeugten id (4.5.2 Nr. 1), XM12 |
| X-21 | übernommen (a) | `grest` ohne `ctx`-Default (4.8, 7); (b), (c) betreffen Teil B |
| X-22 | übernommen (Teil A) | Testdateinamen nach N-18; `R/compare-cautious.R` kommt in Teil A nicht vor |
| X-23 | übernommen | Abschnitt 9; `validation.elements.*` → `validation.building.element_cost_missing`; `expand.catalog_defaults` → `validation.measures.catalog_defaults` |
| X-24 | übernommen (a), (b), (f), (g) | (a) Platzhalter `effects.energy/rent/vacancy` aus 4.4 gestrichen; (b) Verweis 3.4 → Teil B §3.10; (f) Label `foerderstopp` nach Teil C §4.2; (g) OP-02 und OP-13 geschlossen. (c)–(e) betreffen Teil B/C |
| X-25 | übernommen | 4.5.1 Nr. 5 (PV-USt als `expr` nach Spec 00 §7.10, gilt für `energy.pv.measure` und die PV-Typen); 4.1, 4.6.1 (Basisfallwert); XM3 |
| X-26 | übernommen | 4.5.1 Nr. 4 (Nutzungsdauer der Hauptmaßnahme bzw. GND für `rueckbau`, `herrichten_erschliessung`, `baunebenkosten`), 6.3.7 (Erwerb ausgeschlossen, Gebäudeanteil des Kaufpreises als Bestand), 6.5; XM10, RV11 |
| X-27 | übernommen | 1.2, 8.1 (Codes `federal_state`) |
| X-28 | übernommen | 4.6.1 (`rule:cost_from_kg` auch für Zahlungsplan `eur`), 4.1, XM11 |
| X-30 | übernommen (Variante R-101) | WU-Profile behalten `.inf` (kein Zahlenwert in Konzept A2); W `validation.accounts.liquidity_unchecked` (1.4, 1.5, 5.7, AC5); ein endlicher WU-Default wurde nicht eingeführt (keine belastbare Quelle; OP-07) |
| X-32 | übernommen (Teil A) | 2.2: `shared.network_fee_growth_gas`/`_gas_mfh` und `market.energy_network_fee.*.growth` als Bezug; Kommentar mit allen 10 Trägern |
| X-33 | ohne Änderung | Spec 00 §4.12 neu gefasst; die ids von Teil A (4.5.2 Nr. 1, 6.2) stimmen damit überein |
| F-07 | übernommen | wie X-11; L1-Kommentar und 5.2 (TZ und Zuschuss mit gleicher Ableitung in derselben Periode) |
| F-09 | übernommen | RV8 = 82.853,16 (nominaler Buchwert); 4.10.2, 6.1, 6.3.7 |
| F-10 | übernommen | L1 neu: n_eff = 16, Rate 81.639,56, t = 11 Z 38.051,53 / R 43.588,03, letzte Rate 2052 (21 Annuitäten); L2 unverändert (keine Laufzeitverkürzung) |
| F-14 | übernommen | `floor: 0` in `deposit_rate_pa` von `global.yaml` und allen fünf Profilen; 2.8, 5.7; PR5 erweitert (Untergrenze greift: 0 statt −0,011) |
| F-21 | teilweise | übernommen: `double_count` erfasst auch Erhaltungsmaßnahmen (S4-V0), neues I `replacements_excluded` mit Kennwert und I `default_rate` (S3/S4: Pauschale nur aus Defaults); M7, PR9. Nicht übernommen: automatischer Satzabschlag – er wäre eine aus overlay-fähigen Blättern berechnete Konstante (Spec 00 §4.12 Nr. 5). Ausdrückliche Sätze in S3/S4 setzt Teil C |
| F-22 | teilweise | `rule:maintenance_from` setzt bei Neubauprojekten `basis: iibv` (II. BV, 11,50 €/m² in den ersten 21 Jahren), sofern kein Satz angegeben ist; M8. Nicht über `by_project_type` (würde in Szenarien ohne Gebäude einen Block `building` anlegen, N-05); die Variante „gestufter Pfad 30/65/100 %“ wurde nicht gewählt (keine Primärquelle, II. BV ist belegt) |
| F-24 | übernommen | `heizungsverteilung` → Element `heating` (mit dem Wärmeerzeuger höchstens 2 Punkte); 4.2, 6.3.3, 8.3 |

### 12.4 Neu gerechnete bzw. neue Prüfwerte

| Test | alt | neu | Grund |
|---|---|---|---|
| L1 (nach Zinsanpassung) | Rate 69.997,46; t = 11 R 31.945,93; 20 Raten bis 2056 | n_eff = 16 (n* = 15,833415); Rate 81.639,56; t = 11 Z 38.051,53, R 43.588,03, B_11 907.700,29; letzte Rate t = 26 (Z 3.139,98, R 78.499,58) | R-100, F-10 |
| L11 | – | Rate 416,67; t = 1 Z −2.972,27, R −2.027,73; t = 10 Z −2.344,64, R −2.655,36, Schlusstilgung −76.709,76 | R-100, X-13 |
| RV8 (`indexed: false`) | 47.250,00 | 82.853,16 | R-108, F-09 |
| RV11 | – | V_30 763.750,00; `path_measures` 740.837,50 | X-26 |
| M4 | −800 (0,025) | −320 (0,010) | X-10 |
| M7, M8 | – | Kennwert 4,00 €/m²·a; II.-BV-Stufen 11.500 / 14.580 / 18.620 | F-21, F-22 |
| PR5 | – | 0 ab 2030 (Untergrenze) | F-14 |
| Q7, XM9–XM13, PR8–PR10, AC5 | – | siehe Tabellen | R-85, R-86, R-91, X-09, X-25, X-26, X-28 |

Unverändert und erneut bestätigt: L1 bis B_10 (951.288,32), L2 (71.261,11; 999.182,07; 73.521,57), L10
(B_1 1.227.800,00), RV8 indexiert (114.688,15), RV9 (111.247,51).

### 12.5 Phase-0-Nacharbeit (Spec 00 §17.5.4) aus Sicht von Teil A

Keine Datei des Pakets wurde bearbeitet. P0-01 übernimmt die 37 Codes aus 4.2 (unverändert); P0-02 die Enums aus 8.1
(neu: `federal_state`, `maintenance_basis` mit `auto`); P0-06 (`res_quantity()`) entspricht 3.5; P0-07 (`ctx$rows()` mit
`local_row`) nutzt `share_of` (4.15); P0-09 (Gebäude-Defaults nur bei vorhandenem Block, Herkunft `rule:<name>`,
Reihenfolge Ableitungsregeln → `item_defaults` → Expander) entspricht 1.4 und 2.1/2.2.
