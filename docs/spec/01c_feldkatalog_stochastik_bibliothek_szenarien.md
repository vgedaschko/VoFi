# Spezifikation 01 – Teil C: Feldkatalog Stochastik, Parameterbibliothek, Szenario-Sets, Referenzszenarien, MC-Auswertung

| | |
|---|---|
| **Projekt** | VoFi-Werkzeug (R-Paket `vofi`) |
| **Dokument** | `docs/spec/01c_feldkatalog_stochastik_bibliothek_szenarien.md` (Spec 01, Teil C) |
| **Bezug** | `docs/spec/00_kernvertraege.md` (Spec 00, `contract_version = "1.0.0"`, `schema_version = 1`), `docs/Konzept.md`, Memos 02, 03, 04, 07, Prototyp `docs/recherche/prototypen/mc/spec.yaml` |
| **Stand** | 25.10.2026 |
| **Status** | Entwurf zur Integration (Rang 3 nach Spec 00 §1.2). Konkretisiert Spec 00 §4.3.14, §4.3.15, §4.9–4.11, §9.11, §11, §12.7–12.9 und §15.6 (Referenzszenarien) innerhalb der dort festgelegten Strukturen; abgeglichen mit Spec 00 Runde 2 (R-66 bis R-84). Wo eine Konkretisierung eine Spec-00-Struktur erweitern müsste, steht ein Änderungsantrag in Abschnitt 8 (`S01C-nn`); bis zur Entscheidung gilt die dort genannte Übergangsregel. |
| **Eigentümer der Inhalte** | WS-C (Abschnitt 1, Sampler-Semantik), WS-L (Abschnitte 2–3, Bibliotheksdaten), WS-A (Abschnitt 4: Schema und Auflösung der Szenario-Sets; Profile), WS-G (Abschnitte 4.3, 4.4, 6), WS-S (Abschnitt 5) |
| **Nachbarteile** | Teil A (`01a`): Szenario-, Gebäude-, Maßnahmen-, Capex-, Ersatz-, Finanzierungs-, Konten-, Restwert-Felder, globale Defaults und Profile. Teil B (`01b`): Mietrecht, Betriebskosten, Energie/CO2, PV, Haushalt, Mieterkosten, Algorithmen der Förderinstrumente. Teil C liefert die **Daten** der Fördereinträge; ihre **Auslegung** regelt Teil B. |

> **Lesehinweis.** Bezeichner, Schlüssel und Codes sind ASCII-snake_case, Labels und Erläuterungen deutsch. Raten und
> Anteile sind Dezimalzahlen (`0.039` = 3,9 %), Geldbeträge nominal in EUR brutto (Spec 00 §2.13), **Energiepreisbestandteile im Block `market` und in
> `energy.carriers` netto** (01b §0.6; USt über `vat_rate`). Felder, deren Name
> von Teil A bzw. B festgelegt wird und bei Redaktionsschluss noch nicht feststand, tragen den Kommentar `# 01a` bzw.
> `# 01b`; der hier verwendete Name ist der wahrscheinlichste und ist bei der Integration gegen 01a/01b abzugleichen.

---

## 0. Konventionen dieses Teils

### 0.1 Spalten der Feldtabellen

| Spalte | Inhalt |
|---|---|
| YAML-Pfad | Pfad nach Spec 00 §4.4 (Pfad-Identität §4.13); `<key>` = Overlay-Schlüssel, `<id>` = Sammlungs-id |
| Typ | `int`, `num`, `chr`, `lgl`, `date`, `enum:<werte>`, `value` (Wertgrammatik §4.5), `map`, `list`, `num[]`, `chr[]`; `dist` = Verteilungsangabe nach 1.4 oder Zahl |
| Einheit | physikalische bzw. monetäre Einheit; `1` = dimensionslos; `1/a` = Rate p. a.; `Pp` = Prozentpunkte (nur im Text, Werte stets dezimal) |
| Default | Wert, der gilt, wenn das Feld fehlt; `–` = kein Default; `Pflicht` steht in der Spalte „Pflicht“ |
| Pflicht | `ja`, `nein`, `bedingt` (Bedingung in „Validierung“) |
| Validierung | Prüfregel; Verstoß ist ein Fehler (`E`), eine Warnung (`W`, `vofi_warning_plausibility` bzw. `_input`) oder ein Hinweis (`I`) |
| Bedeutung | fachliche Bedeutung |
| Quelle/Memo-Ref | Herkunft des Defaults (Memo §, Konzept §, Spec-00 §) |

### 0.2 Markierungen

- **Qualitätsstufen** A–D nach Spec 00 §4.9 / R-54: A amtlich/Primärquelle geprüft, B Verband/Institut geprüft,
  C Sekundärquelle, D eigene Ableitung/Expertenschätzung. Werte der Stufen C/D sind in den Bibliothekseinträgen über
  `quality` bzw. `quality_detail` (3.1) ausdrücklich gekennzeichnet und zusätzlich mit `# C` / `# D` kommentiert.
- **„Sek.“** = nur über Sekundärquelle belegt (Konzept §10.2); **„Abl.“** = eigene Ableitung.
- **`S01C-nn`** = Änderungsantrag an Spec 00 (Abschnitt 8).
- **MUSS/SOLL/KANN** wie Spec 00 §1.3.

### 0.3 Notation (Prozesse und Ziehungen)

| Symbol | Bedeutung |
|---|---|
| y = 1 … Y | Index der Prozessjahre; y = 1 ist `start_year` (Spec 00 §11.7: Spalte 1 = Startwert); Jahr = `start_year + y − 1` |
| u | Uniform aus (0, 1) nach Spec 00 §11.5 (LHS je Block oder Pseudo), nach Korrelation (§11.6) |
| z_y | Standardnormal-Schock des Jahres y ≥ 2 (Spec 00 §11.5), nach Kreuzkorrelation |
| Q(u; par) | Quantilfunktion der Verteilung (`quantile(u, par)`, Spec 00 §5.3) |
| m | Blockgröße `block_size` (Default 200; im F21-Modus m = n_sim / `replicates`), Spec 00 §11.4, R-73 |
| Φ, φ | Standardnormal-Verteilungsfunktion bzw. -dichte |

---

## 1. Stochastik-Overlay (`stochastic`)

### 1.1 Struktur, Verarbeitung, Grundsätze

Der Block `stochastic` (Spec 00 §4.3.15, Schicht 6) beschreibt Unsicherheit als **Overlay** auf deterministische
Eingaben. Er besteht aus genau vier Unterblöcken; weitere Schlüssel sind ein Validierungsfehler (`E`, mit
`utils::adist`-Vorschlag):

```yaml
stochastic:
  settings:     {...}                       # 1.2
  parameters:   {<key>: {...}, ...}         # 1.3, 1.4 – statische Größen: eine Ziehung je Lauf
  processes:    {<key>: {...}, ...}         # 1.5, 1.6 – Zeitreihen in Kalenderjahren: ein Pfad je Lauf
  correlations: {parameters: [[a, b, rho_s], ...], shocks: [[p, q, rho], ...]}   # 1.7
```

Verbindliche Grundsätze (aus Spec 00 §11, Memo 04 §1.1, Konzept §4.2):

1. **Basisfall bleibt unverändert.** Das Overlay wirkt nur in MC-Läufen (`mode = "mc"`) und in Design-Läufen über
   seine Verteilungen (`mode = "design"`, 11.11). Der deterministische Wert jedes Ziels kommt aus den Schichten 0–5, 7,
   8 (R-17); er MUSS vorhanden sein (Spec 00 §11.7).
2. **Struktur vor Statistik.** Bekannte Zusammenhänge werden als Kopplung in der deterministischen Wertform
   (`ref`, `expr`) oder als gekoppelter Prozess (`linked_ar1`) abgebildet (1.8), nicht über Korrelationen.
3. **Gleiches Risiko = gleicher Schlüssel**, verwandte Risiken = getrennte Schlüssel mit Rangkorrelation (Konzept B9,
   Default ρ_S = 0,7) (1.10).
4. **Jedes Ziel höchstens einmal** (statisch oder Prozess, Spec 00 §11.8). Ein Ziel mit
   `deterministic_only = TRUE` (Spec 00 §5.4) ist ein Validierungsfehler; ein Ziel mit `stochastic = FALSE` erzeugt
   `W` („Parameter ist üblicherweise fest“).
5. **Kurzform.** Eine Verteilungsangabe am Ort (`cost_eur: {dist: pert, min: …, mode: …, max: …}`) wird beim
   Normalisieren in `stochastic.parameters` verschoben; Schlüssel = Zielpfad (z. B. `measures.huelle.cost_eur`), am
   Ort bleibt `const` mit dem Basiswert (`base`, sonst `point(par, analysis.deterministic_point)`, Spec 00 §4.5 Regel 1).
   Kurzformen sind in Varianten zulässig; ihr Schlüssel ist dann ebenfalls der Zielpfad (CRN über Varianten mit
   gleichem Zielpfad).
6. **Bibliotheksverweis.** Jeder Overlay-Eintrag darf `from: <library-id>` tragen (Spec 00 §4.9); die Nutzlast wird
   **unter** die lokale Angabe gemischt (lokal gewinnt). Typische Form: `{target: …, from: processes/…}`.
7. **Overlay als eigene Datei** (`vofi_read_scenario(path, stochastic = "datei.yaml")`, Wurzelschlüssel
   `stochastic`) wird über den Block der Szenariodatei gemischt (Datei gewinnt).

### 1.2 `stochastic.settings`

Defaults stehen in Schicht 1 (`inst/extdata/defaults/global.yaml`, # 01a) mit den hier genannten Werten.
Argumente von `vofi_mc()`/`vofi_run()` gehen vor (Spec 00 §9.2, §14 Nr. 15).

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle/Memo-Ref |
|---|---|---|---|---|---|---|---|
| `stochastic.settings.preset` | enum:`preview`,`standard`,`report`,`custom` | – | `standard` | nein | E bei unbekanntem Code | setzt `n_sim` nach 6.1, sofern nicht ausdrücklich angegeben; die Blockgröße bleibt 200, sodass jedes Preset ein Präfix des größeren ist (S01C-14) | Konzept §4.3, Memo 04 E9, R-73 |
| `stochastic.settings.n_sim` | int | Läufe | `10000` (aus `preset`) | nein | E: ≥ 2 für MC; E: `n_sim %% block_size == 0` (`vofi_error_input` mit Vorschlag des nächsten Vielfachen); im F21-Modus `n_sim %% replicates == 0` | Anzahl Läufe | Spec 00 §11.4, R-73 |
| `stochastic.settings.seed` | int | – | `20261025` (global.yaml) | ja für MC | E: ganzzahlig in [1, 2^31 − 2]; fehlt Argument und Feld → `vofi_error_input` | Master-Seed der benannten Ströme | Spec 00 §11.3, §9.2 |
| `stochastic.settings.sampling` | enum:`lhs`,`pseudo` | – | `lhs` | nein | – | Basiszahlen (Spec 00 §11.5) | D8, Memo 04 E6 |
| `stochastic.settings.block_size` | int | Läufe je Block | `200` | nein | E: ≥ 2; E: m ≥ max(2, d + 1), d = Größe der größten Korrelationsgruppe (1.7.3); E: zugleich mit `replicates` gesetzt | Läufe je LHS-Block (= Replikat); R = n_sim / m Blöcke; Lauf i hängt nur von Seed, Schlüssel, m und b = ⌈i/m⌉ ab | Spec 00 §11.4, R-73 |
| `stochastic.settings.replicates` | int \| null | Blöcke | `null` | nein | E: ≥ 1; E: zugleich mit `block_size`; I: „Ziehungen hängen von n_sim ab“ | **F21-Modus:** Anzahl der Blöcke, m = n_sim / R (Konzept F21, „10 Replikate zu je N/10“) | Konzept F21, Spec 00 §11.4 |
| `stochastic.settings.antithetic` | lgl | – | `false` | nein | E: `true` nur mit `sampling: pseudo` und geradem m | antithetische Variablen | Spec 00 §11.5 |
| `stochastic.settings.copula` | enum:`iman_conover`,`gaussian` | – | `iman_conover` | nein | – | Abhängigkeit statischer Größen (1.7) | Spec 00 §11.6 |
| `stochastic.settings.start_year` | int \| null | Jahr | `null` = Jahr(`valuation_date`) | nein | E: `start_year` ≤ Jahr(`valuation_date`); W bei `start_year` < Jahr(`valuation_date`) − 1 | erstes Prozessjahr (Spalte 1) | Spec 00 §11.7, R-58 |
| `stochastic.settings.store` | enum:`bands`,`kpi`,`full` | – | `bands` | nein | W bei `full` und n_sim > 2.000 (Speicher, 9.9) | Speicherumfang (Spec 00 §9.9) | Spec 00 §9.9 |
| `stochastic.settings.keep_runs` | chr[] | – | `[p05, p50, p95]` | nein | E: Muster `^p[0-9]{2}$`, ohne Duplikate | vollständig nachgerechnete Läufe | Spec 00 §9.9 |
| `stochastic.settings.keep_runs_kpi` | chr | – | `delta_terminal_value` | nein | E: skalare KPI des Modells | Auswahlkennzahl für `keep_runs` | Spec 00 §9.9 |
| `stochastic.settings.bands` | chr[] | – | `[net_position, dep_balance, od_balance]` | nein | E: Ledger-Schlüssel des Modells (Bestands- oder Flusszeilen) | Fächerbänder | Spec 00 §9.9 |
| `stochastic.settings.band_probs` | num[] | 1 | `[0.05, 0.25, 0.5, 0.75, 0.95]` | nein | E: streng steigend in (0, 1) | Quantile der Bänder | Spec 00 §13.2 |
| `stochastic.settings.auto_funding_approval` | lgl | – | `true` | nein | – | automatischer Bernoulli-Schlüssel `funding.<id>.approved` (Spec 00 §11.6 Nr. 4, R-55); bei Entscheidungsknoten (`fallback_variant`) mit Rolle `decision` (Spec 00 §9.11, R-71) | D8 |
| `stochastic.settings.convergence` | map `{rel_halfwidth_mean, abs_halfwidth_prob}` | 1 | `{0.005, 0.01}` | nein | E: Werte in (0, 1) | Konvergenzkriterien für den Ausweis `converged` (6.1, S01C-14); keine automatische Verlängerung in v1 | Memo 04 §4.4 |

**Prüffälle (WS-C/WS-B):** (s1) `n_sim: 1000` mit Default `block_size: 200` → R = 5, SE-Kennzeichnung „grob“
(se_df = 4); `n_sim: 10000` → R = 50; (s2) `n_sim: 1100` → `vofi_error_input` mit Vorschlag 1000 oder 1200 (Spec 00
§15.5 Nr. 9); (s3) `antithetic: true, sampling: lhs` → E; (s4) Korrelationsgruppe mit d = 12 Schlüsseln und
`block_size: 10` (m = 10 < 13) → `vofi_error_input` (Spec 00 §15.5 Nr. 7); (s5) `block_size: 200` und
`replicates: 10` zugleich → E; (s6) `replicates: 10, n_sim: 1000` → m = 100 mit Hinweis (F21-Modus); (s7)
Präfix: Läufe 1…1.000 von `n_sim: 10000` sind `identical()` zu `n_sim: 1000` (Spec 00 §15.5 Nr. 9).

### 1.3 `stochastic.parameters.<key>` (statische Größen)

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle/Memo-Ref |
|---|---|---|---|---|---|---|---|
| `…<key>` | Map | – | – | – | E: Schlüssel `^[a-z][a-z0-9_]*$`, ≤ 40 Zeichen (Overlay-Namen) bzw. Zielpfad (verschobene Kurzform) | Overlay-Schlüssel = Stromname `par:<key>:<b>` | Spec 00 §11.2, §11.3 |
| `…<key>.target` | chr (Pfad) | – | – | ja | E: Pfad existiert in jeder Variante, die den Eintrag enthält (R-16); E: numerisches Blatt (Arten `number`, `amount`, `rate`, `share`, `value`, `schedule`-Betrag) bzw. `shared.<name>`; E: nicht `deterministic_only`; E: kein zweites Ziel gleichen Pfads | Zielpfad (Pfad-Identität) | Spec 00 §4.13, §11.2 |
| `…<key>.label` | chr (de) | – | Label des Zielparameters aus dem Katalog | nein | – | Anzeige | Spec 00 §4.3.15 |
| `…<key>.description` | chr (de) | – | `null` | nein | – | Erläuterung, Herkunft der Annahme | – |
| `…<key>.dist` | enum (11 Typen, 1.4) | – | – | ja | E: registrierter Verteilungstyp | Verteilung | Spec 00 §5.1 |
| `…<key>.<verteilungsparameter>` | num bzw. num[] | Einheit des Ziels (bei `apply: multiply` dimensionslos) | je Typ | je Typ | `validate(par)` des Typs (1.4) | Verteilungsparameter | 1.4 |
| `…<key>.apply` | enum:`replace`,`multiply`,`add` | – | `replace` | nein | E: `multiply` nur bei Verteilungen mit Träger ⊂ [0, ∞) **oder** bei Bernoulli; W bei `add`/`multiply` auf Ziele der Art `share` (Ergebnis wird auf [0, 1] begrenzt, I) | Wirkung der Ziehung x auf den Basiswert b des Ziels: `replace` → x; `multiply` → b · x; `add` → b + x (b n-Vektor oder n × (T+1)-Pfad) (**S01C-01**) | Konzept §3.2 („Faktor auf die Kostenschätzung“), Memo 04 §1.2 |
| `…<key>.base` | num | wie Ziel | `null` | nein | W, wenn `base` ≠ deterministischer Wert des Ziels; E, wenn `base` außerhalb des Trägers (bei `apply: replace`) | nur Kurzform: deterministischer Basiswert am Ort; im Overlay Prüfwert | Spec 00 §4.5 Regel 1 |
| `…<key>.from` | chr (Bibliotheks-id) | – | `null` | nein | E: Eintrag existiert, `block: processes` | Vorlage aus `processes/**` (Abschnitt 2) | Spec 00 §4.9 |

**Semantik von `apply` (S01C-01, Übergangsregel bis zur Entscheidung).** `ctx$param()`/`ctx$value()` liefern in
Schritt 1 von Spec 00 §6.3 bei `multiply` bzw. `add` den Ausdruck `b ⊙ x` bzw. `b + x`, wobei b der in Schritt 3
ausgewertete deterministische Knoten ist (Skalar → n-Vektor, Pfad → n × (T+1), x zeilenweise gehoben wie
`ctx$by_sim()`). `draws$static[[key]]` enthält immer x (Faktor bzw. Zuschlag), `draws$u[[key]]` die Uniform. Im
Design-Lauf (Spec 00 §11.11) gilt dieselbe Verknüpfung mit dem Design-Wert x. Die Referenzszenarien (Abschnitt 5)
verwenden `apply` nur als `replace`; Faktoren und Zuschläge wirken dort über `shared`-Blätter in `expr`-Angaben
(Muster 5.0 Nr. 6), sodass sie unabhängig von der Entscheidung über S01C-01 rechnen.

**Prüffall apply (WS-C/WS-D):** Ziel `measures.huelle.cost_eur` mit Basiswert 543.301,50; `dist: pert, min: 0.95,
mode: 1.10, max: 1.50, apply: multiply`; Uniform u = 0,0770428277 (Golden-Vektor 1.10.3, Lauf 1) → x = 1,00872837 →
`ctx$param()` = 548.043,58 (± 0,01).

### 1.4 Verteilungstypen (Registry-Art `distribution`, `R/dist-<name>.R`, WS-C)

Gemeinsame Regeln für alle Typen (MUSS):

- `quantile(u, par)` ist **monoton nicht fallend** in u (Spec 00 §5.3), vektorisiert, liefert für
  `u ∈ {1e-9, 0.5, 1 − 1e-9}` endliche Werte im Träger (Vertragstest D1).
- `point(par, which)` mit `which ∈ {mode, median, mean}`; `median` = `quantile(0.5, par)`.
- `moments(par)` = Mittelwert und Varianz **der Verteilung, die `quantile()` tatsächlich erzeugt** (bei `empirical`
  der interpolierten Quantilfunktion), `NA` nur bei nicht endlichen Momenten.
- **Entartung zulässig:** `sd = 0`, `min = max`, `min = mode = max`, `sdlog = 0` sind gültig und ergeben den
  konstanten Wert (Spec 00 §15.5 Nr. 2).
- `validate(par)` gibt deutsche Meldungen über `msg("sampling.dist.<name>.<code>", …)` zurück (Label-Datei
  `inst/labels/de/types/distribution/<name>.yaml`).
- Numerische Ablage: alle Parameter `double`; Vektoren (`values`, `probs`, `data`) als `double`.
- PERT/Beta-Quantile DÜRFEN tabelliert werden (4.098 Stützstellen, in den Rändern nach `pnorm(seq(-7, 7, …))`
  verdichtet, lineare Interpolation; maximaler Fehler ≤ 1e-7 · (max − min)); die Tabelle hängt nur von `par` ab
  (Batch-Invarianz F7) (Memo 04 §2.1).

#### 1.4.1 `fixed`

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.value` | num | wie Ziel | – | ja | E: endlich | konstanter Wert | Memo 04 §2.1 |

Q(u) = value; point = value; mean = value, var = 0. **Prüffall:** `value: 3` → `quantile(c(0.1, 0.9))` = (3, 3),
`moments` = (3, 0). Zweck: Entartungstests, Abschalten einzelner Unsicherheiten.

#### 1.4.2 `normal`

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.mean` | num | wie Ziel | – | ja | E: endlich | Mittelwert μ | Memo 04 §2.1 |
| `…<key>.sd` | num | wie Ziel | – | ja | E: ≥ 0 | Standardabweichung σ | |

Q(u) = μ + σ Φ⁻¹(u); mode = median = mean = μ; var = σ². W, wenn das Ziel die Art `share` hat oder
P(X < 0) > 1e-3 bei einem nichtnegativen Ziel (Empfehlung `truncnorm`, Memo 04 §2.1). **Prüffall:** `mean: 0, sd:
0.004` → q10/q50/q90 = −0,0051262063 / 0 / 0,0051262063.

#### 1.4.3 `truncnorm`

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.mean` | num | wie Ziel | – | ja | E: endlich | μ der **Mutterverteilung** | Memo 04 §2.1 |
| `…<key>.sd` | num | wie Ziel | – | ja | E: ≥ 0 | σ der Mutterverteilung | |
| `…<key>.lower` | num | wie Ziel | `-.inf` | nein | E: `lower < upper`; E: Φ(β) − Φ(α) > 1e-12 | untere Schranke a (Alias `min`, mit `vofi_warning_input`) | Memo 07 §6.1 (Alias) |
| `…<key>.upper` | num | wie Ziel | `.inf` | nein | wie oben | obere Schranke b (Alias `max`) | |

Mit α = (a − μ)/σ, β = (b − μ)/σ, Z = Φ(β) − Φ(α):
Q(u) = μ + σ Φ⁻¹(Φ(α) + u Z) (für Φ(α) > 0,5 numerisch über die obere Flanke:
Q(u) = μ − σ Φ⁻¹(Φ(−α) − u (Φ(−α) − Φ(−β)))); mean = μ + σ (φ(α) − φ(β))/Z;
var = σ² [1 + (α φ(α) − β φ(β))/Z − ((φ(α) − φ(β))/Z)²]; mode = min(max(μ, a), b). σ = 0 → Q ≡ min(max(μ, a), b).

**Prüffälle:** (t1) μ = 0,0275, σ = 0,0075, [0,01; 0,05] (S4 KfW-358-Zins): mean 0,027665271, sd 0,0072101237,
q10/q50/q90 = 0,018248918 / 0,027579575 / 0,037101672. (t2) μ = 0, σ = 1, [−1; 2]: mean 0,22963718, var 0,51976254
(Memo 04 §9 KS-Test). (t3) `lower: 0.05, upper: 0.01` → E.

#### 1.4.4 `lognormal` (Formen meanlog/sdlog, mean/sd, median/p90)

Genau **eine** der drei Parameterformen; zusätzlich optional `shift` s. Y = X − s ist lognormal(m, σ_l).

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.meanlog` | num | log | – | bedingt (Form a) | E: endlich | m | Memo 03 §17 (Konvention) |
| `…<key>.sdlog` | num | log | – | bedingt (Form a) | E: ≥ 0 | σ_l | |
| `…<key>.mean` | num | wie Ziel | – | bedingt (Form b) | E: mean > shift | Mittelwert von X | Memo 04 §2.1 |
| `…<key>.sd` | num | wie Ziel | – | bedingt (Form b) | E: ≥ 0 | Standardabweichung von X | |
| `…<key>.median` | num | wie Ziel | – | bedingt (Form c) | E: median > shift | Median von X | Memo 04 §2.1 |
| `…<key>.p90` | num | wie Ziel | – | bedingt (Form c) | E: p90 ≥ median | 90-%-Quantil von X | |
| `…<key>.shift` | num | wie Ziel | `0` | nein | E: endlich | Verschiebung s | |

Umrechnung (MUSS, beim Normalisieren, Ergebnis in `smp_plan()$static_par` als `meanlog`, `sdlog`, `shift`):
Form b: σ_l² = ln(1 + sd²/(mean − s)²), m = ln(mean − s) − σ_l²/2. Form c: m = ln(median − s),
σ_l = (ln(p90 − s) − ln(median − s)) / Φ⁻¹(0,9) (Φ⁻¹(0,9) = 1,2815515655). E, wenn mehrere Formen oder keine
vollständig angegeben sind. Q(u) = s + exp(m + σ_l Φ⁻¹(u)); median = s + e^m; mean = s + e^{m + σ_l²/2};
mode = s + e^{m − σ_l²}; var = (e^{σ_l²} − 1) e^{2m + σ_l²}. W bei Zielen der Art `share` (unbeschränkt; Memo 04:
Lognormal(2 %, P90 5 %) liefert bei N = 10.000 Maxima um 35 %).

**Prüffälle:** (l1) mean 1,1, sd 0,1 → meanlog 0,09119493, sdlog 0,090722098; q10/q50/q90 = 0,97524153 / 1,0954825 /
1,2305485. (l2) median 0,02, p90 0,05 → meanlog −3,912023, sdlog 0,71498546, mean 0,025824777, q99 0,10553442,
q9999 0,2856522 (Warnhinweis Quote). (l3) meanlog 0, sdlog 0,25 → mean 1,0317434, var 0,068653994. (l4) Form a und b
zugleich → E.

#### 1.4.5 `uniform`

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.min` | num | wie Ziel | – | ja | E: min ≤ max | untere Grenze a | Memo 04 §2.1 |
| `…<key>.max` | num | wie Ziel | – | ja | | obere Grenze b | |

Q(u) = a + (b − a) u; mode := median := mean = (a + b)/2; var = (b − a)²/12. **Prüffall:** [0; 0,30] (S2 Green
Premium) → mean 0,15, sd 0,08660254, q10 0,03, q90 0,27.

#### 1.4.6 `triangular`

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.min` | num | wie Ziel | – | ja | E: min ≤ mode ≤ max | a | Memo 04 §2.1 |
| `…<key>.mode` | num | wie Ziel | – | ja | | c | |
| `…<key>.max` | num | wie Ziel | – | ja | | b | |

F_c = (c − a)/(b − a); Q(u) = a + √(u (b − a)(c − a)) für u < F_c, sonst b − √((1 − u)(b − a)(b − c)); a = b → Q ≡ a.
mean = (a + b + c)/3; var = (a² + b² + c² − ab − ac − bc)/18.

**Prüffälle:** (d1) (0; 3; 12) → mean 5, var 6,5 (Memo 04 §9). (d2) (2,6; 2,9; 3,3) (S1 JAZ) → mean 2,9333333,
sd 0,14337209, q10/q50/q90 = 2,7449138 / 2,9258343 / 3,132668. (d3) (60; 90; 200) (CO2 2030, Memo 07) → mean
116,66667, sd 30,09245, q10/q50/q90 = 80,493902 / 112,25036 / 160,75717. (d4) (80; 150; 300) → mean 176,66667,
sd 45,886333. (d5) `mode: 4, max: 3` → E.

#### 1.4.7 `pert`

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.min` | num | wie Ziel | – | ja | E: min ≤ mode ≤ max | a | Memo 04 §2.1 |
| `…<key>.mode` | num | wie Ziel | – | ja | | c (wahrscheinlichster Wert) | |
| `…<key>.max` | num | wie Ziel | – | ja | | b | |
| `…<key>.lambda` | num | 1 | `4` | nein | E: > 0 | Formparameter λ | Memo 04 §2.1 |

α = 1 + λ (c − a)/(b − a), β = 1 + λ (b − c)/(b − a); Q(u) = a + (b − a) · qbeta(u, α, β); mean = (a + λc + b)/(λ + 2);
var = (mean − a)(b − mean)/(λ + 3); mode = c. **Standard für Expertenschätzungen.**

| Prüffall | (min; mode; max) | α / β | mean | sd | q10 | q50 | q90 |
|---|---|---|---:|---:|---:|---:|---:|
| p1 Baukosten Neubau | 0,95; 1,05; 1,35 | 2 / 4 | 1,0833333 | 0,071269665 | 0,99489398 | 1,0755241 | 1,1835561 |
| p2 Baukosten Sanierung | 0,95; 1,10; 1,50 | 2,0909091 / 3,9090909 | 1,1416667 | 0,099053056 | 1,0176133 | 1,13189 | 1,2804662 |
| p3 Verzug Neubau (Monate) | 0; 2; 12 | 1,6666667 / 4,3333333 | 3,3333333 | 2,031498 | 0,911916 | 3,0234477 | 6,2232185 |
| p4 Verzug Sanierung | 0; 1; 6 | 1,6666667 / 4,3333333 | 1,6666667 | 1,015749 | 0,455958 | 1,5117239 | 3,1116093 |
| p5 JAZ Bestand | 2,6; 3,2; 4,0 | 2,7142857 / 3,2857143 | 3,2333333 | 0,26337251 | 2,8864917 | 3,2254664 | 3,5920217 |
| p6 Prebound f_pre | 0,5; 0,7; 1,0 | 2,6 / 3,4 | 0,71666667 | 0,093647431 | 0,59430958 | 0,7127354 | 0,84494477 |
| p7 Rebound f_post | 0,9; 1,1; 1,4 | 2,6 / 3,4 | 1,1166667 | 0,093647431 | 0,99430958 | 1,1127354 | 1,2449448 |
| p8 Leerstandsniveau | 0; 0,02; 0,08 | 2 / 4 | 0,026666667 | 0,014253933 | 0,0089787967 | 0,025104814 | 0,04671123 |
| p9 λ = 6 | 0; 2; 12 | 3 / 3 | – | – | 0,94588135 (q10) | 2,7418796 | 5,4307793 |

p9: mean 3,0, sd 1,7320508 (λ = 6 verschiebt Masse zum Modus). D1: p2 `quantile(c(1e-9, .5, 1-1e-9))` =
(0,95000895; 1,13189; 1,4982258).

#### 1.4.8 `beta` (verallgemeinert auf [min, max])

Genau eine Form: (a) `shape1`, `shape2` oder (b) `mean`, `sd` (bezogen auf X ∈ [min, max]).

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.shape1` | num | 1 | – | bedingt (a) | E: > 0 | α | Memo 07 §4.1 (Beta-Angaben) |
| `…<key>.shape2` | num | 1 | – | bedingt (a) | E: > 0 | β | |
| `…<key>.mean` | num | wie Ziel | – | bedingt (b) | E: min < mean < max | Mittelwert | |
| `…<key>.sd` | num | wie Ziel | – | bedingt (b) | E: 0 < sd² < (mean − min)(max − mean) | Standardabweichung | |
| `…<key>.min` | num | wie Ziel | `0` | nein | E: min < max | untere Grenze | |
| `…<key>.max` | num | wie Ziel | `1` | nein | | obere Grenze | |

Form b → mit μ' = (mean − min)/(max − min), v' = sd²/(max − min)²: k = μ'(1 − μ')/v' − 1, α = μ' k, β = (1 − μ') k.
Q(u) = min + (max − min) qbeta(u, α, β); mode = min + (max − min)(α − 1)/(α + β − 2) für α, β > 1, sonst Rand (α ≤ 1 →
min, β ≤ 1 → max; α = β = 1 → Mitte). **Prüffälle:** (b1) mean 0,08, sd 0,05 (S1 Härtefallquote) → α = 2,2752,
β = 26,1648; q10/q50/q90 = 0,025017748 / 0,070264881 / 0,14811714. (b2) mean 0,03, sd 0,02 (S1 Leerstand V1) →
α = 2,1525, β = 69,5975, q50 = 0,025740945. (b3) α = 2, β = 5 auf [0; 10] → mean 2,8571429, var 2,5510204.

#### 1.4.9 `bernoulli`

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.p` | num | 1 | – | ja | E: 0 ≤ p ≤ 1 | Erfolgswahrscheinlichkeit | Memo 04 §2.1, D8 |

**Q(u) = 1{u > 1 − p}** (monoton nicht fallend; die Memo-04-Form 1{u < p} verletzt Spec 00 §5.3 und ist unzulässig,
S01C-04). mean = p; var = p(1 − p); mode = 1{p ≥ 0,5}; median = Q(0,5) = 1{p > 0,5}. Mit LHS enthält jeder Block
genau ⌊p m⌋ oder ⌈p m⌉ Einsen. Deterministischer Basiswert von `funding.<id>.approved` ist 1 (Spec 00 §11.6 Nr. 4;
unter dem Set `foerderstopp` 0). Ist das Instrument ein **Entscheidungsknoten** (`funding.<id>.fallback_variant`
gesetzt, Spec 00 §9.11), erhält der Schlüssel die Rolle `decision`: gleiche Ziehung (Strom `par:<key>:<b>`), aber
keine Wirkung auf das Ziel, sondern Zweigwahl je Lauf; Entscheidungsschlüssel MÜSSEN `bernoulli` (bzw. 0/1-wertig)
sein und dürfen in keiner Korrelationsgruppe stehen (E `decision_correlated`, R-71). Rangkorrelationen mit
Bernoulli-Schlüsseln der Rolle `value` erzeugen I („Bindungen: Zielkorrelation nicht erreichbar“, Memo 04 §3.4).
**Prüffälle:** p = 0,85: Q(c(1e-9, 0.5, 1 − 1e-9)) = (0, 1, 1); Q(0,15) = 0, Q(0,1500001) = 1; m = 200 → je Block
genau 170 Einsen (Golden 1.10.3: Block 1 von `funding.kfw261.approved`, erste fünf Läufe 1, 1, 1, 1, 0).

#### 1.4.10 `discrete`

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.values` | num[] | wie Ziel | – | ja | E: ≥ 1 Element, endlich, ohne Duplikate | Ausprägungen | Memo 04 §2.1 |
| `…<key>.probs` | num[] | 1 | gleich verteilt | nein | E: gleiche Länge, ≥ 0, \|Σ − 1\| ≤ 1e-9 | Wahrscheinlichkeiten | |

MUSS: (values, probs) werden nach `values` aufsteigend sortiert (`order(values, method = "radix")`), P_k = kumulierte
Summe mit **P_K := 1 exakt**; Q(u) = v_k mit k = min{k : P_k ≥ u} (`findInterval(u, P, left.open = TRUE) + 1`).
mean = Σ p_k v_k; mode = v mit größtem p (Gleichstand: kleinster Wert); median = Q(0,5). Eine Ganzzahl-Zielgröße
(Ausfalljahr) MUSS ganzzahlige `values` haben (sonst W).

**Prüffall:** values 2028…2033, probs gleich (S4 Kesselausfall) → mean 2030,5, var 2,9166667; Q(0,1) = 2028,
Q(1/6) = 2028, Q(1/6 + 1e-12) = 2029, Q(0,5) = 2030, Q(0,9) = 2033.

#### 1.4.11 `empirical`

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.data` | num[] | wie Ziel | – | ja | E: ≥ 2 endliche Werte; W bei < 10 Werten | Stichprobe (z. B. eigene Kostenüberschreitungen) | Memo 04 §2.1 |

Mit s_(1) ≤ … ≤ s_(n): Q(u) = `stats::quantile(data, u, type = 7)` (lineare Interpolation der Ordnungsstatistiken);
mean = (1/(n−1)) Σ_{i=1}^{n−1} (s_(i) + s_(i+1))/2; E[X²] = (1/(n−1)) Σ (s_(i)² + s_(i) s_(i+1) + s_(i+1)²)/3;
mode := median (S01C-04). **Prüffall:** data (0,98; 1,02; 1,05; 1,08; 1,12; 1,20; 1,35) → q10/q50/q90 = 1,004 / 1,08 /
1,26; mean 1,1058333 (≠ Stichprobenmittel 1,1142857), var 0,0087159722.

### 1.5 `stochastic.processes.<key>` (gemeinsame Felder)

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle/Memo-Ref |
|---|---|---|---|---|---|---|---|
| `…<key>` | Map | – | – | – | E: Schlüssel `^[a-z][a-z0-9_]*$`, ≤ 40 Zeichen, eindeutig über `parameters` ∪ `processes` | Prozessschlüssel = Stromname `shock:<key>:<b>`, `scen:<key>:<b>` | Spec 00 §11.3 |
| `…<key>.target` | chr (Pfad) | – | – | ja | E: Pfad existiert, Parameter erlaubt Shape `path` (i. d. R. `market.<name>`, auch `accounts.<rate>`, `shared.<name>`); E: deterministischer Basiswert vorhanden | Zielpfad | Spec 00 §11.7, R-16 |
| `…<key>.type` | enum (8 Typen, 1.6) | – | – | ja | E: registrierter Prozesstyp | Prozesstyp | Spec 00 §5.1, §11.7 |
| `…<key>.label` | chr (de) | – | Label des Ziels | nein | – | Anzeige | Spec 00 §4.3.15 |
| `…<key>.description` | chr (de) | – | `null` | nein | – | Erläuterung | – |
| `…<key>.<prozessparameter>` | num \| `dist` \| Token | je Typ | je Typ | je Typ | `validate(par)` (1.6); Verteilungen nur für numerische Skalarparameter (1.5.2) | Prozessparameter | 1.6 |
| `…<key>.from` | chr | – | `null` | nein | E: Eintrag `block: processes` | Bibliotheksvorlage (Abschnitt 2) | Spec 00 §4.9 |

#### 1.5.1 Token `base` für Startparameter (S01C-02)

Die Startparameter `x0` (`ar1`), `u0` (`linked_ar1`), `r0` (`vasicek`), `p0` und `p_norm` (`mr_trend`) sowie `p0`
(`gbm`) DÜRFEN das Token `base` tragen. Bedeutung: **Spalte 1 des Prozesses = deterministischer Basiswert des Ziels im
Startjahr.** `smp_plan()` ermittelt diesen Wert x_det als Wert des Ziels in der ersten Rasterspalte j ≥ 2 mit
`year[j] == start_year` (Kalenderjahreskonvention wie `grid_index_year()`, Spec 00 §3.6); existiert keine solche Spalte
(T = 0), gilt Spalte 1. Die Auswertung erfolgt mit n = 1 im deterministischen Kontext (Schichten 0–5, 7, 8, keine
Ziehungen) und ist damit für alle Läufe gleich. Es gilt: `x0 = base` → x0 := x_det; `r0 = base` → r0 := x_det;
`p0 = base` → p0 := x_det; `p_norm = base` → p̄ := x_det (keine Krisenabweichung); `u0 = base` →
u0 := x_det − a − b · base_1 (Rest so, dass g_1 = x_det; das Langfristniveau a + b · E[base] bleibt unverändert).
Damit erfüllen die Bibliotheksprozesse Konzept F18 („Startwert entspricht dem deterministischen Wert“) für jedes
Szenario. **Übergangsregel bis zur Entscheidung:** WS-C löst das Token intern in `smp_plan()` auf; jeder
Bibliothekseintrag trägt im Metadatenfeld `fallback` den numerischen Ersatzwert (Abschnitt 2), den WS-S bei Ablehnung
in die Szenarien übernimmt.

#### 1.5.2 Prozessparameter als Verteilungen (S→P)

Jeder numerische Skalarparameter (`mu`, `phi`, `sigma`, `x0`, `a`, `b`, `r0`, `theta`, `kappa`, `floor`, `p0`,
`growth`, `p_norm`, `noise.phi`, `noise.sigma`) darf eine Verteilungsangabe nach 1.4 sein (Spec 00 §11.7). Der
Sampler zieht sie als statische Schlüssel `<proc>.<param>` (bei Unterfeldern `<proc>.noise.sigma`), Strom
`par:<proc>.<param>:<b>`; sie nehmen unter diesem Namen an `correlations.parameters` teil (Spec 00 §11.6 Nr. 6) und
erscheinen in `inputs` und in der Sensitivität. `simulate()` erhält sie als n-Vektor (Spec 00 §5.3).

Validierung: Der **Träger** der Verteilung MUSS im zulässigen Bereich des Parameters liegen (E): `phi`, `noise.phi`
∈ (−1, 1) → nur beschränkte Verteilungen (`uniform`, `triangular`, `pert`, `beta`, `truncnorm` mit Schranken,
`discrete`, `empirical`, `fixed`); `sigma`, `kappa` > 0 bzw. ≥ 0 → Träger ⊂ [0, ∞); unbeschränkte Verteilungen
(`normal`, `lognormal`) nur für `mu`, `a`, `b`, `theta`, `growth`, `x0`, `r0`, `floor`, `p0` (`p0`, `p_norm`: Träger
> 0). Szenariopfade und -gewichte von `scenario_mix` sowie Parameter in `iid.dist_spec` und `fixed_path` sind **nicht**
verteilbar (E mit Hinweis „statischen Schlüssel und Ausdruck verwenden“).

#### 1.5.3 Gemeinsame Typpflichten (WS-C)

- `simulate(par, z, u, years, linked)` → n × Y, **Spalte 1 = Startwert**, Schocks ab Spalte 2 (Spec 00 §11.7).
- `n_shocks(par)` und `n_uniforms(par)` hängen **nur von der Struktur** ab, nicht von Parameterwerten (S01C-05):
  `ar1`, `linked_ar1`, `vasicek`, `mr_trend`, `gbm`, `iid` → 1 Schock, 0 Uniforms; `scenario_mix` → 1 Schock genau dann,
  wenn `noise` angegeben ist, und 1 Uniform (Strom `scen:`); `fixed_path` → 0/0. So verschiebt ein späteres σ > 0 keine
  Ziehungen.
- `expected(par, years)` bei Punktparametern (Verteilungsparameter → `point(…, "mean")`); P2 (σ = 0 ⇒
  `simulate == expected`, 1e-12) und P3 (Mittel innerhalb 4 SE, wo definiert) nach Spec 00 §5.6.
- Ausgabeart `output` (`level`/`rate`) wie in 1.6; Abbildung aufs Raster über `grid_map_years()` (Spec 00 §11.7).
- Pfadmerkmale `draws$features` nach Spec 00 §11.7 (`<key>.mean`, `<key>.end`, `<key>.at<jahr>`, `<key>.scenario`).

### 1.6 Prozesstypen (Registry-Art `process`, `R/process-<name>.R`, WS-C)

#### 1.6.1 `ar1` (Inflation, Wachstumsraten)

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.mu` | num \| dist | 1/a | – | ja | E: endlich | Langfristmittel μ | Memo 04 §2.2 (b) |
| `…<key>.phi` | num \| dist | 1 | – | ja | E: \|φ\| < 1; W: φ < 0 (Oszillation) | Persistenz φ | |
| `…<key>.sigma` | num \| dist | 1/a | – | ja | E: ≥ 0 | Schock-Std.-Abw. σ_ε | |
| `…<key>.x0` | num \| dist \| `base` | 1/a | `mu` | nein | E: endlich | Startwert (Spalte 1) | Spec 00 §11.7 |

`output = "rate"`. x_1 = x0; x_y = μ + φ (x_{y−1} − μ) + σ z_y (y ≥ 2). expected: μ + φ^{y−1}(x0 − μ).
Var(x_y | μ) = σ²(1 − φ^{2(y−1)})/(1 − φ²); mit μ ~ (Mittel μ̄, Std.-Abw. s_μ):
Var(x_y) = σ²(1 − φ^{2(y−1)})/(1 − φ²) + (1 − φ^{y−1})² s_μ²; Lag-1-Autokorrelation stationär φ.

**Prüffall (Bibliotheksdefault `processes/inflation_ar1_2026`, μ ~ N(0,020; 0,004), φ = 0,5, σ = 0,011,
x0 = 0,028):**

| y | 1 | 2 | 3 | 5 | 11 | 31 |
|---|---:|---:|---:|---:|---:|---:|
| E[x_y] | 0,028 | 0,024 | 0,022 | 0,0205 | 0,020007812 | 0,020000000 |
| sd(x_y) | 0 | 0,01118034 | 0,012658989 | 0,013219895 | 0,013315478 | 0,013316656 |

Stationär (μ fest): sd 0,012701706; mit μ-Unsicherheit 0,013316656. Prototyp (Memo 04 §2.2): sd 0,0124 bei σ = 0,01,
φ = 0,6 (Soll 0,0125).

#### 1.6.2 `linked_ar1` (strukturelle Kopplung: Miete, Baupreise, Instandhaltung an Inflation; Zinsspread)

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.base` | chr (Prozessschlüssel) | – | – | ja | E: Prozess existiert, kein Zyklus, `base != key`; Topo-Reihenfolge `proc_order` | Basisprozess (`linked = "base"`) | Spec 00 §11.7, §5.3 |
| `…<key>.a` | num \| dist | 1/a | `0` | nein | E: endlich | Niveau a | Memo 04 §2.2 (b) |
| `…<key>.b` | num \| dist | 1 | `1` | nein | E: endlich; W: b < 0 | Kopplungsfaktor b | |
| `…<key>.phi` | num \| dist | 1 | `0` | nein | E: \|φ\| < 1 | Persistenz des Rests | |
| `…<key>.sigma` | num \| dist | 1/a | `0` | nein | E: ≥ 0 | Schock-Std.-Abw. des Rests | |
| `…<key>.u0` | num \| `base` | 1/a | `0` | nein | E: endlich | Startrest u_1 (Spec 00: u_1 = 0 ist der Default; Parameter S01C-03); `base` nach 1.5.1 (S01C-02) | Konzept F18 |

`output = "rate"`. g_y = a + b · base_y + u_y; u_1 = u0; u_y = φ u_{y−1} + σ z_y (y ≥ 2).
expected: a + b · expected(base) + φ^{y−1} u0. Ohne Schockkorrelation zum Basisprozess:
Var(g_y) = b² Var(base_y) + σ²(1 − φ^{2(y−1)})/(1 − φ²). Eine zusätzliche Schockkorrelation zum Basisprozess ist
zulässig, erzeugt aber I („Doppelzählung Kopplung + Korrelation“, Memo 04 §3.1).

**Prüffälle (Basis = Inflation aus 1.6.1 mit x0 = 0,028):**

| Fall | a / b / φ / σ / u0 | E[g_1] | E[g_2] | E[g_3] | E[g_11] | E[g_31] | sd(g_11) |
|---|---|---:|---:|---:|---:|---:|---:|
| Bestandsmiete, u0 = 0 | 0,002 / 0,8 / 0,5 / 0,006 / 0 | 0,0244 | 0,0212 | 0,0196 | 0,01800625 | 0,018 | 0,012707211 |
| Bestandsmiete, `u0: base`, x_det = 0,015 (S1–S4) | … / u0 = −0,0094 | 0,015 | 0,0165 | 0,01725 | 0,01799707 | 0,018 | 0,012707211 |
| Neuvertragsmiete, `u0: base`, x_det = 0,020 (S2) | 0,005 / 1,0 / 0,5 / 0,02 / −0,013 | 0,020 | 0,0225 | 0,02375 | 0,02499512 | 0,025 | – |
| Baupreise, u0 = 0 | 0,007 / 1,0 / 0,65 / 0,015 / 0 | 0,035 | 0,031 | – | 0,027007812 | 0,027 | 0,023808438 |
| Baupreise, `u0: base`, x_det = 0,040 (S-Konvention 2027) | … / u0 = 0,005 | 0,040 | 0,03425 | 0,0311125 | 0,02707513 | 0,027 | 0,023808438 |
| Instandhaltung, `u0: base`, x_det = 0,040 | 0,010 / 1,0 / 0,65 / 0,015 / 0,002 | 0,040 | 0,0353 | 0,032845 | 0,03003474 | 0,030 | – |

Bibliotheksdefaults mit `prices/macro_paths_2026` (π_2027 = 0,026): Bestandsmiete x_det = 0,0175 → u0 = −0,0053,
E[g] = 0,0175 / 0,01775 / 0,01799951 / 0,018 (y = 1, 2, 11, 31); Baupreise x_det = 0,035 → u0 = 0,002, E[g] = 0,035 /
0,0313 / 0,02703278 / 0,027.

#### 1.6.3 `vasicek` (Bauzins, Bundrendite)

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.r0` | num \| dist \| `base` | 1/a | – | ja | E: endlich | Startwert r_1 | Memo 04 §2.2 (d) |
| `…<key>.theta` | num \| dist | 1/a | – | ja | E: endlich | Gleichgewichtsniveau θ | |
| `…<key>.kappa` | num \| dist | 1/a | – | ja | E: > 0 | Rückkehrgeschwindigkeit κ | |
| `…<key>.sigma` | num \| dist | 1/a | – | ja | E: ≥ 0 | Momentan-Volatilität σ | |
| `…<key>.floor` | num \| dist | 1/a | `-.inf` | nein | E: floor ≤ r0 (W, wenn floor > θ) | Untergrenze **nur der Ausgabe** | |

`output = "level"`. Zustand r_1 = r0; r_y = θ + (r_{y−1} − θ) e^{−κ} + σ √((1 − e^{−2κ})/(2κ)) z_y; Ausgabe
`pmax(r, floor)` (Zustand ungekappt). **expected = pmax(θ + (r0 − θ) e^{−κ(y−1)}, floor)** (S01C-12; damit gilt P2 auch,
wenn der Floor bindet). Stationär: sd = σ/√(2κ), Halbwertszeit ln 2/κ, AR(1)-Äquivalent φ = e^{−κ},
σ_ε = σ √((1 − φ²)/(2κ)). P3 prüft den ungekappten Zustand (Testhilfe `floor = -.inf`).

**Prüffall (Default `processes/mortgage_rate_vasicek_2026` mit r0 = 0,040, θ = 0,0375, κ = 0,12, σ = 0,007,
floor = 0,005):** φ = 0,88692044, σ_ε = 0,0066002635, stationäre sd 0,01428869, Halbwertszeit 5,7762265 Jahre.

| y | 1 | 2 | 6 | 11 | 21 | 31 | 41 |
|---|---:|---:|---:|---:|---:|---:|---:|
| E[r_y] (Zustand) | 0,04 | 0,039717301 | 0,038872029 | 0,038252986 | 0,037726795 | 0,037568309 | 0,037520574 |
| sd(r_y) | 0 | 0,0066002635 | 0,011944574 | 0,013625164 | 0,014229773 | 0,014283355 | 0,014288206 |
| E[max(r_y, 0,005)] | 0,04 | 0,039717301 | 0,038880087 | 0,038285765 | 0,037778916 | 0,037623729 | 0,037576681 |
| P(r_y < 0,005) | 0 | 7,2e-8 | 0,0022858 | 0,0073323 | 0,0107275 | 0,0112992 | 0,0114217 |

Golden-Pfad (1.10.3, Lauf 1, m = 10): r = 0,0400000000; 0,0406599864; 0,0494826935; 0,0441105157 (y = 1…4).

#### 1.6.4 `mr_trend` (Energiepreise; Mean-Reversion um einen Trend, optional vom Krisenniveau zum Normalpreis)

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.p0` | num \| dist \| `base` | EUR/kWh (Einheit des Ziels) | – | ja | E: > 0 | Startwert P_1 (12-Monats-Mittel) | Memo 03 §2.4, Konzept B8 |
| `…<key>.p_norm` | num \| dist \| `base` | wie p0 | `p0` | nein | E: > 0; W: \|ln(p0/p_norm)\| > 0,7 | Normalpreis p̄ im Startjahr (Anker der Mean-Reversion) (S01C-03) | Memo 03 §2.4 „Normalpreis B̄“ |
| `…<key>.growth` | num \| dist | 1/a | `0` | nein | E: > −1 | nominales Trendwachstum g | Memo 04 §2.2 (e) |
| `…<key>.phi` | num \| dist | 1 | – | ja | E: \|φ\| < 1 | Persistenz der Log-Abweichung | Memo 03 §2.3 |
| `…<key>.sigma` | num \| dist | 1 | – | ja | E: ≥ 0 | Std.-Abw. der Log-Innovation | |

`output = "level"`. P_y = p̄ (1 + g)^{y−1} exp(Y_y − v_y/2), Y_1 = ln(p0/p̄), v_1 = 0, Y_y = φ Y_{y−1} + σ z_y,
v_y = φ² v_{y−1} + σ². Mit p̄ = p0 (Default) ist das exakt die Formel aus Spec 00 §11.7. **expected:**
E[P_y] = p̄ (1 + g)^{y−1} (p0/p̄)^{φ^{y−1}} (die Krisenabweichung baut sich geometrisch ab; der Rauschterm hat
Erwartung 1). Variationskoeffizient des Rauschens: √(exp(σ²(1 − φ^{2(y−1)})/(1 − φ²)) − 1), stationär bei φ = 0,75,
σ = 0,08: 0,12139231. Bei verteiltem g: E[P_y] = p̄ E[(1 + g)^{y−1}] (p0/p̄)^{φ^{y−1}}.

**Prüffälle (Bibliothek, `growth` ~ N(Mittel; sd), Werte in EUR/kWh, „E|g“ = mit g = Mittel):**

| Prozess | p0 / p̄ / φ / σ / g | E[P_2] | E[P_6] | E[P_11] | E[P_31] | E[P_31] \| g fest |
|---|---|---:|---:|---:|---:|---:|
| Gas EFH (Hs) ohne CO2 und Netzentgelt | 0,06335 / 0,05833 / 0,75 / 0,08 / N(0,02; 0,01) | 0,06329700 | 0,06573832 | 0,07174468 | 0,11015703 | 0,10565828 |
| Gas MFH (Hs) ohne CO2 und Netzentgelt | 0,06043 / 0,05580 / 0,75 / 0,08 / N(0,02; 0,01) | 0,06042243 | 0,06284453 | 0,06862183 | 0,10537904 | 0,10107542 |
| Haushaltsstrom | 0,31513 / 0,30252 / 0,75 / 0,04 / N(0,02; 0,007) | 0,31816764 | 0,33741797 | 0,37040312 | 0,55930412 | 0,54797710 |
| Wärmepumpenstrom EFH | 0,21849 / 0,21008 / 0,75 / 0,05 / N(0,02; 0,007) | 0,22068358 | 0,23422615 | 0,25719733 | 0,38839937 | 0,38053351 |
| Wärmepumpenstrom MFH | 0,21008 / 0,20168 / 0,75 / 0,05 / N(0,02; 0,007) | 0,21210671 | 0,22494362 | 0,24693497 | 0,37286941 | 0,36531807 |
| Heizöl (Hi) ohne CO2 | 0,10034 / 0,06723 / 0,70 / 0,18 / N(0,02; 0,012) | 0,09076136 | 0,07950492 | 0,08340252 | 0,12930566 | 0,12177894 |
| Fernwärme | 0,13109 / 0,12605 / 0,80 / 0,07 / N(0,025; 0,008) | 0,13331778 | 0,14454597 | 0,16247989 | 0,27149893 | 0,26441123 |
| Holzpellets (Hi) | 0,07944 / 0,06542 / 0,60 / 0,09 / N(0,025; 0,008) | 0,07534104 | 0,07518856 | 0,08407154 | 0,14090122 | 0,13722288 |
| Beispiel ohne Krisenabweichung (`p_norm` = p0) | 0,0613 / 0,0613 / 0,75 / 0,08 / N(0,02; 0,01) | 0,06252600 | 0,06774521 | 0,07504800 | 0,11576421 | 0,11103647 |

Alle Werte **netto** (ohne USt; # 01b §3.2.1: `price_eur_kwh` netto, `price_basis: net`, USt über `vat_rate`).
Variationskoeffizient des Rauschens stationär: Gas 0,121392; Strom 0,060530; WP-Strom 0,075701; Heizöl 0,256107;
Fernwärme 0,117065; Pellets 0,112857.

Prototyp (Memo 04 §10.3): p0 = 0,10, p̄ = p0, g ~ N(0,02; 0,01), φ 0,75, σ 0,08 → E[P_41] = 0,238 (Spalte 41 bei
y = 1 … 41 ab 2026: 0,10 · E[(1+g)^40]).

#### 1.6.5 `gbm` (Option, nicht Default für Energiepreise)

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.p0` | num \| dist \| `base` | wie Ziel | – | ja | E: > 0 | Startwert | Memo 04 §2.2 (a) |
| `…<key>.growth` | num \| dist | 1/a | `0` | nein | E: > −1 | erwartete Wachstumsrate g | |
| `…<key>.sigma` | num \| dist | 1 | – | ja | E: ≥ 0; W: σ √(Y − 1) > 0,6 („Pfade sehr breit“) | Volatilität | |

`output = "level"`. ln P_y = ln P_{y−1} + ln(1 + g) − σ²/2 + σ z_y; E[P_y] = p0 (1 + g)^{y−1}; Median
p0 (1 + g)^{y−1} e^{−σ²(y−1)/2}. **Prüffall:** p0 = 1, g = 0,02, σ = 0,1, y = 31 → E = 1,8113616, Median 1,5590534.

#### 1.6.6 `scenario_mix` (CO2-Korridore, Regulierungsszenarien)

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.scenarios` | Map Name → Map | – | – | ja | E: ≥ 1 Szenario; Namen `^[a-z][a-z0-9_]*$` | Szenarien | Spec 00 §11.7 |
| `…<key>.scenarios.<name>.prob` | num | 1 | – | ja | E: ≥ 0; \|Σ prob − 1\| ≤ 1e-9 | Gewicht | |
| `…<key>.scenarios.<name>.years` | int[] | Jahr | – | ja | E: streng steigend, ≥ 1 Element | Stützjahre | |
| `…<key>.scenarios.<name>.values` | num[] | wie Ziel | – | ja | E: gleiche Länge, endlich (keine Knoten, 1.5.2) | Stützwerte | |
| `…<key>.noise` | Map \| null | – | `null` | nein | – | multiplikatives AR(1)-Log-Rauschen | |
| `…<key>.noise.phi` | num \| dist | 1 | `0` | nein | E: \|φ\| < 1 | Persistenz | Memo 03 §3.4 |
| `…<key>.noise.sigma` | num \| dist | 1 | `0` | nein | E: ≥ 0 | Std.-Abw. | |

`output = "level"`. Szenarien in Reihenfolge `sort(names, method = "radix")` (Namen mit führenden Nullen, z. B.
`q01`…`q20`, damit die Ordnung der Bedeutung entspricht); kumulierte Gewichte mit letztem Wert := 1; Szenario
S = k mit k = min{k : P_k ≥ u}, u aus Strom `scen:<key>:<b>` (LHS bzw. Pseudo wie statische Größen). x^{(k)}_y =
lineare Interpolation der Stützwerte in Jahr y (außerhalb konstant); X_y = x^{(S)}_y · exp(Y_y − v_y/2) mit Y, v wie
`mr_trend` (Y_1 = v_1 = 0); ohne `noise` X_y = x^{(S)}_y. Attribut `scenario` = k (1-basiert in kanonischer
Ordnung); Merkmal `<key>.scenario`. expected: Σ_k p_k x^{(k)}_y.

**Komonotoner Dreieckskorridor (Konzept B6, Memo 03 §3.4).** Die Bibliothek bildet die komonotone Ziehung
Q_tri(u; niedrig_y, mittel_y, hoch_y) für alle Stützjahre mit **einem** u je Lauf als `scenario_mix` mit K = 20
gleichgewichtigen Quantilpfaden ab: Pfad k = Q_tri((k − 0,5)/K; …) je Stützjahr (Abschnitt 2.5). Mit LHS ist der
Szenarioindex exakt geschichtet. Diskretisierungsfehler (berechnet): Mittelwerte −1,7e-4 relativ (2030: 84,985 statt
85,000), Standardabweichungen −1,0 % relativ. Ein eigener Prozesstyp ohne Diskretisierung ist für v1.1 vorgemerkt
(Abschnitt 7).

**Prüffall (Prototyp-Spezifikation Memo 04 §10.2):** Szenarien `niedrig` 0,3 / `mittel` 0,5 / `hoch` 0,2. Die
kanonische Ordnung ist alphabetisch (`hoch`, `mittel`, `niedrig`), nicht die YAML-Reihenfolge → kumuliert (0,2; 0,7;
1) → u = 0,15 → Szenario 1 `hoch`; u = 0,25 → 2 `mittel`; u = 0,75 → 3 `niedrig`. Expected 2030 = 0,2 · 200 +
0,5 · 120 + 0,3 · 70 = 121. (Die Bibliothek verwendet deshalb Namen `q01`…`q20`, deren alphabetische Ordnung der
Quantilordnung entspricht.)

#### 1.6.7 `iid` (jährlich unabhängige Schwankung)

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.dist_spec` | Map (Verteilung nach 1.4) | wie Ziel | – | ja | E: gültige Verteilung, Parameter nicht verteilt (1.5.2) | Jahresverteilung | Memo 04 §2.2 (g) |

`output = "level"`. X_1 = point(dist_spec, "mean"); X_y = Q(Φ(z_y); dist_spec) (y ≥ 2); expected = mean für alle
Jahre. Die Schocks dürfen mit anderen Prozessen korreliert sein. Ein Niveau mit Jahresschwankung entsteht als
Produkt eines statischen Schlüssels und eines `iid`-Prozesses über einen Ausdruck am Ziel (1.8, K9). **Prüffall:**
`dist_spec: {dist: pert, min: 0.5, mode: 1.0, max: 2.0}` → Spalte 1 = 1,0833333, Spaltenmittel ab y = 2 innerhalb
4 SE von 1,0833333.

#### 1.6.8 `fixed_path` (deterministischer Pfad im MC, Stresspfad)

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `…<key>.years` | int[] | Jahr | – | ja | E: streng steigend | Stützjahre | Spec 00 §11.7 |
| `…<key>.values` | num[] | wie Ziel | – | ja | E: gleiche Länge, endlich | Stützwerte | |

`output` = `level` (bei Zielen der Art `rate` gilt `rate`, nur Anzeige). Lineare Interpolation, außerhalb konstant;
n_shocks = n_uniforms = 0; expected = simulate. Zweck: einen Marktpfad im MC festhalten, während andere variieren.

### 1.7 `stochastic.correlations`

#### 1.7.1 Feldkatalog

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `stochastic.correlations.parameters` | list of [chr, chr, num] | – | `[]` | nein | E: beide Schlüssel sind statische Schlüssel der Rolle `value` (`parameters`, `<proc>.<param>`, `funding.<id>.approved` ohne Entscheidungsknoten, verschobene Kurzformen); E `decision_correlated`: Schlüssel der Rolle `decision` (Spec 00 §11.6 Nr. 4, R-71); E: \|ρ_S\| ≤ 1; E: a ≠ b; E: dasselbe Paar zweimal mit verschiedenem ρ; W: \|ρ_S\| = 1 (wird repariert) | Rangkorrelationen (Spearman) statischer Größen | Spec 00 §11.6 Nr. 1–3 |
| `stochastic.correlations.shocks` | list of [chr, chr, num] | – | `[]` | nein | E: beide Schlüssel sind Prozesse mit n_shocks = 1; sonst wie oben | Korrelation (Pearson) der Jahresschocks z | Spec 00 §11.6 Nr. 5 |

Paare aus einem Bibliotheksverweis (`{from: processes/…}`), deren Schlüssel im Plan fehlen, werden mit
`vofi_inform("sampling.corr_pair_dropped", …)` verworfen; Paare aus der Szenariodatei mit unbekanntem Schlüssel sind E
(S01C-08). Die Reihenfolge der Paare und der Schlüssel ist ohne Wirkung (kanonische Ordnung, Spec 00 §11.10 Nr. 1).

#### 1.7.2 Statische Größen: Iman–Conover (Default) bzw. Gauß-Copula

1. Gruppe G = Vereinigung aller Schlüssel in `correlations.parameters`, kanonisch sortiert
   (`sort(keys, method = "radix")`); d = |G|. Zielmatrix: Einheitsmatrix, Paare eingetragen, **Pearson-Umrechnung**
   ρ = 2 sin(π ρ_S/6) (ρ_S = 0,3/0,5/0,7/0,8/0,9 → 0,31286893/0,51763809/0,7167359/0,81347329/0,907981).
2. Reparatur (1.7.4), dann je Block b: Scores a_i = Φ⁻¹(i/(m + 1)), i = 1…m; Spalte j der Score-Matrix S =
   `with_stream(seed, "ic:<key_j>:<b>", sample(a))`; T = S Q⁻¹ P mit Q = chol(cor(S)), P = chol(C) (obere Dreiecke);
   jede Uniform-Spalte nach den Rängen von T umsortieren (`ties.method = "first"`). Die Wertemenge je Spalte bleibt
   exakt erhalten (LHS-Schichtung bleibt).
3. Quantilfunktion **nach** der Korrelation auf die Uniforms (R-59).
4. `copula: gaussian`: U' = Φ(Φ⁻¹(U) · chol(C)) je Block (zerstört die LHS-Schichtung teilweise; Memo 04 §3.2).

#### 1.7.3 Mindestblockgröße

m ≥ max(2, d + 1) (Spec 00 §11.4, R-73); sonst `vofi_error_input` mit Vorschlag `block_size ≥ d + 1`. Mit dem
Default `block_size: 200` sind Gruppen bis d = 199 zulässig, unabhängig von n_sim (auch in der Vorschau). Im
F21-Modus (`replicates` R) gilt m = n_sim/R, Vorschlag n_sim ≥ R · (d + 1); Beispiel d = 6, R = 10 → n_sim ≥ 70.

#### 1.7.4 Reparatur nicht positiv definiter Matrizen (MUSS, R-38)

`R <- (R + t(R))/2`; Eigenzerlegung (`eigen(symmetric = TRUE)`); falls min λ < ε = 1e-6: λ ← max(λ, ε), Rücktransformation,
Reskalierung auf Einheitsdiagonale; max |ΔR| > 0,05 → `vofi_warning_correlation` mit Matrix vor/nach; reparierte Matrix in
`draws$meta$repaired$parameters` bzw. `$shocks`. Kein `Matrix::nearPD`.

**Prüffall (Memo 04 §3.3):** Spearman-Eingabe (a,b) 0,9, (a,c) −0,6, (b,c) 0,2 → Pearson-Ziel (0,907981; −0,618034;
0,209057), Eigenwerte (2,0087; 1,1935; −0,2022) → repariert (0,766160; −0,522453; 0,147684), max |ΔR| = 0,14182 →
Warnung. (Ohne Pearson-Umrechnung ergäbe das Clipping (0,772317; −0,515891; 0,145746), wie in Memo 04 genannt; maßgeblich
ist die Reihenfolge „erst umrechnen, dann reparieren“.)

#### 1.7.5 Prozessschocks: Cholesky

Matrix über alle Prozesse mit n_shocks = 1 in kanonischer Ordnung; Reparatur wie 1.7.4; je Block eine Multiplikation
`Z %*% chol(R)` über alle Jahresspalten (zeithomogen; Spec 00 §11.6 Nr. 5). Schock- und Niveaukorrelation
unterscheiden sich: für zwei AR(1) mit φ₁, φ₂ gilt stationär Corr = ρ √((1 − φ₁²)(1 − φ₂²))/(1 − φ₁ φ₂) (Beispiel
Inflation φ = 0,5 und Vasicek φ = e^{−0,12}, ρ = 0,4 → Niveaukorrelation 0,2875). Bei gleichem φ ist sie gleich ρ.
Die Default-Matrix (Abschnitt 2.6, zehn Prozesse) hat den kleinsten Eigenwert 0,05 (positiv definit, `chol` läuft).

### 1.8 Kopplungen (strukturell, Konzept §4.2 „Struktur vor Statistik“)

Kopplungen sind **keine** eigenen Overlay-Felder. Sie entstehen über (i) Wertformen der deterministischen Basis
(`ref`, `expr`; ein `ref` auf ein Prozessziel liefert in der MC dessen Pfad, Spec 00 §4.5 Regel 3) oder (ii)
`linked_ar1`. Damit gilt die Kopplung im Basisfall und in jedem Lauf gleich.

| Nr. | Kopplung | Abbildung (Default) | Wirkung im Basisfall | Quelle |
|---|---|---|---|---|
| K1 | Bestandsmiete folgt der Inflation | Prozess `rent_growth` (`linked_ar1`, base `inflation`, a = 0,002, b = 0,8, `u0: base`) auf `market.rent_growth` | Startjahr unverändert (`u0: base`) | Memo 04 §1.2, Konzept §4.2 |
| K2 | Indexmiete = VPI | `rent_regime: index` liest `market.inflation` (# 01b), keine Zusatzangabe | – | Memo 02 §2.7 |
| K3 | Habenzins, KK-Zins folgen dem Bauzins | `accounts.deposit_rate_pa: {ref: market.mortgage_rate, anchor: <h>, floor: 0}`, `accounts.overdraft_rate_pa: {ref: market.mortgage_rate, anchor: <s>}` (Spec 00 §4.5 „Bezug“ mit `anchor`, R-76): Wert = a + (x − x[, 1]), Startwert = deterministischer Zins; Profilwerte # 01a | identisch (bei konstantem Basispfad) | Memo 04 §1.2, Konzept A2/F18 |
| K4 | Energiepreis = Commodity/Rest + Netzentgelt + CO2 × EF | Prozesse auf `market.energy_price.<träger>` (ohne CO2 und ohne getrennt geführtes Netzentgelt), `market.energy_network_fee.<träger>` deterministisch mit Wachstum, `market.co2_price` als Korridor; Summe bildet der Typ `energy_cost` (# 01b) | – | Konzept §3.8, Memo 03 §2.4 |
| K5 | Bio-Mehrkosten folgen Gaspreis/CO2 nicht, eigene Unsicherheit | `market.bio_fuel_premium` mit statischem Faktor (`apply: multiply`, triangular 0,5/1/1,67 ≙ 3/6/10 ct) | – | Memo 07 §4.0 |
| K6 | Baupreise, Instandhaltung folgen der Inflation | `linked_ar1` (a = 0,007 bzw. 0,010, b = 1, `u0: base`) auf `market.construction_price_index`, `market.maintenance_index` | Startjahr unverändert | Memo 04 §2.3, Memo 03 §5.2 |
| K7 | Liegenschaftszins/Exit-Rendite folgt dem Zins am Horizont | `residual_value.<methode>.cap_rate: {expr: "0.035 + 0.5 * (market.mortgage_rate - 0.040)"}` (Spalte T+1 maßgeblich, # 01a) plus statischer Zuschlag `apply: add` (normal 0; 0,005) | identisch bei r = 4,0 % | Memo 04 §1.2 (β = 0,5) |
| K8 | Haushaltseinkommen folgt der Inflation | `household.income_growth` Default `{ref: market.inflation}` (Spec 00 §4.3.5) | – | Spec 00 |
| K9 | Leerstand = Niveau × Jahresschwankung | `unit_groups.<id>.vacancy_rate: {expr: "shared.vacancy_level * market.vacancy_fluctuation"}`, statisch auf `shared.vacancy_level`, `iid` auf `market.vacancy_fluctuation` (Basis 1) | identisch | Memo 04 §1.2 |
| K10 | CO2-Vermieteranteil folgt dem realisierten Verbrauch | Stufenmodell bzw. § 5a in `co2_cost` auf dem stochastischen Verbrauch (# 01b) | – | Memo 04 §3.1 |
| K11 | Betriebskosten folgen VPI + Spread | `{ref: market.inflation, offset: 0.005}` | – | Memo 03 §5 (operating_cost_growth) |
| K12 | Bauzins = Bundrendite + Spread (Alternative zu Vasicek direkt, F7) | `market.mortgage_rate: {expr: "market.bund_yield_10y + market.mortgage_spread"}`, Prozesse auf beiden Summanden (2.2) | identisch | Memo 03 §4.3, Konzept F7 |

**Prüffall K3 (WS-D):** Basis `market.mortgage_rate = 0.041` (konstant), `accounts.deposit_rate_pa: {ref:
market.mortgage_rate, anchor: 0.035, floor: 0}` → deterministisch 0,035 in allen Perioden; MC mit Golden-Pfad
(1.6.3: 0,04; 0,0406599864; 0,0494826935; 0,0441105157) → 0,035; 0,0356599864; 0,0444826935; 0,0391105157 (Wert
= 0,035 + (r_y − r_1)). Ohne `anchor` (Form `offset: -0.006`) läge der Startwert im Lauf bei r_1 − 0,006 = 0,034 ≠
0,035; deshalb ist `anchor` die Default-Kopplung (Konzept F18).

### 1.9 Ziele (`target`) und Abbildung auf Parameterpfade

Ziele folgen der Pfad-Identität (Spec 00 §4.13): `components.<id>.<param>`, `financing.<id>.<param>` (flach),
Map-Felder `financing.<id>.<param>.<feld>`, Domänenblätter, `market.<name>`, `shared.<name>`. Ein Prozess wirkt über
`grid_map_years()` (Spalte j = Wert des Jahres `year[j]`), eine statische Größe als n-Vektor (bei Pfadzielen
zeilenweise konstant, `ctx$by_sim()`); Komponenten sehen beides nur über `ctx$param()`/`ctx$market()`.

| Ziel (Pfad) | Art / Shape | typische Unsicherheit (Default) | Bibliothek (Abschnitt 2) | Fachteil |
|---|---|---|---|---|
| `market.inflation` | rate / path | `ar1` | `processes/inflation_ar1_2026` | 01a (market) |
| `market.mortgage_rate` | rate / path | `vasicek` (F7) | `processes/mortgage_rate_vasicek_2026` | 01a |
| `market.bund_yield_10y`, `market.mortgage_spread` | rate / path | `vasicek` + `ar1` (Alternative) | `processes/bund10_vasicek_2026`, `processes/mortgage_spread_ar1_2026` | 01a (neue Namen, 1.9.1) |
| `market.rent_growth`, `market.rent_growth_new` | rate / path | `linked_ar1` | `processes/rent_growth_linked_2026`, `processes/rent_growth_new_linked_2026` | 01a/01b |
| `market.construction_price_index`, `market.maintenance_index` | rate / path | `linked_ar1` | `processes/construction_price_linked_2026`, `processes/maintenance_cost_linked_2026` | 01a |
| `market.energy_price.<träger>` | value / path (EUR/kWh netto) | `mr_trend` | `processes/energy_prices_mr_2026` (`use: <träger>`) | 01b |
| `market.co2_price` | value / path (EUR/t) | `scenario_mix` (Korridor) | `processes/co2_price_corridor_2026` | 01b |
| `market.bio_fuel_premium` | value / path | statisch `apply: multiply` | `processes/energy_prices_mr_2026` (`use: bio_premium_factor`) | 01b |
| `shared.network_fee_growth_<träger>` (Wachstum im `growth`-Knoten von `market.energy_network_fee.<träger>`) | rate / scalar | `triangular` | `processes/energy_prices_mr_2026` (`use: network_fee_growth`) | 01b |
| `measures.<id>.cost_factor` (Basis 1; Default `{ref: project.construction_cost_factor}`) bzw. `project.construction_cost_factor` (alle Maßnahmen) | number / scalar | `pert` (Faktor; Vorlagen mit `apply: multiply` wirken auf Basis 1 wie `replace`) | `processes/cost_risks_2026` (`use: overrun_retrofit` \| `overrun_newbuild` \| `overrun_component`) | 01a 4.1 (Umlenkung von `cost_eur`, S01A-08) |
| `project.construction_delay_months` | number / scalar | `pert` | `processes/cost_risks_2026` (`use: delay_newbuild`) | Spec 00 §3.9 |
| `measures.<id>.delay_months` | number / scalar | `pert` | `processes/cost_risks_2026` (`use: delay_retrofit`) | Spec 00 §3.9 |
| `measures.<id>.useful_life_years` | number / scalar | `triangular` (aus `costs/nutzungsdauern_2026.uncertainty`) | – | 01a |
| `energy.performance_gap.prebound_factor` / `.rebound_factor` / `.realisation_factor` | value / scalar | `pert` | `processes/energy_performance_2026` (`use: prebound` \| `rebound` \| `realisation`) | 01b |
| `energy.<zustand>.jaz` (realisierte JAZ; **nicht** `jaz_plan`, das `deterministic_only` ist und § 559f steuert, R-70) | number / scalar | `pert` | `processes/energy_performance_2026` (`use: jaz_air_water_existing` u. a.) | 01b §3.2.2 |
| `funding.<id>.approved` | value 0/1 | `bernoulli` (automatisch aus `approval_probability`; Verfügbarkeit nach 2030 `p = 0.7`); Rolle `decision` bei Entscheidungsknoten | Fördereinträge `budget_risk`; `processes/funding_risks_2026` (`use: availability_post2030`) | Spec 00 §9.11, §11.6 Nr. 4, 01b |
| `funding.<id>.payout_delay_months` | number ≥ 0 / scalar | `pert` (Auszahlungsverzug nach Zusage, Konzept B12) | `processes/funding_risks_2026` (`use: payout_delay`) | Spec 00 §3.9, R-84, 01b |
| `funding.<id>.repayment_grant.cut_share` (Förderkredite; sonst `financing.<id>.repayment_grant.cut_share`) | share / scalar | `discrete` (Kürzung/Rückforderung bei verfehltem Nachweis) | `processes/funding_risks_2026` (`use: repayment_grant_cut`) | Spec 00 §8.2, R-84, 01b 4.2 |
| `measures.<id>.active` | value 0/1 / scalar | `bernoulli` (Maßnahme findet statt, z. B. spätere Stufe) | – | Spec 00 §4.3.6, R-71 |
| `residual_value.income_value.cap_rate` (bzw. `exit_yield.cap_rate`) | rate / path (Spalte T+1) | `truncnorm` bzw. `apply: add` normal | `processes/valuation_risks_2026` (`use: cap_rate_shock`) | 01a 6.1 |
| `residual_value.income_value.remaining_life_years` (`manual`) bzw. `.remaining_life_offset_years` (sonst; Umlenkung von `apply: add`, S01A-08) | number / scalar | `triangular` bzw. Zuschlag triangular (−5; 0; 5) | `processes/valuation_risks_2026` (`use: remaining_life_shock`) | 01a 6.1 |
| `unit_groups.<id>.vacancy_rate` | share / path | `pert` bzw. `beta` | `processes/valuation_risks_2026` (`use: vacancy_level`) | 01b |
| `unit_groups.<id>.rent_law.hardship_share` | share / scalar | `beta` | – | 01b |
| `unit_groups.<id>.rent_eur_m2_month` | value / scalar | `normal` | – | 01b |
| `accounts.deposit_rate_pa` | rate / path | Kopplung K3; alternativ `normal` (S4) | – | 01a |
| `financing.<id>.rate_pa` | rate / scalar | `truncnorm` (spätere Förderkredite) | – | Spec 00 §8.2 |
| `building.maintenance.rate_eur_m2_pa` bzw. `components.<id>.amount_eur` (Typ `recurring`) | amount / scalar | `pert` `apply: multiply` (Niveaufaktor; ohne S01C-01 über `shared`-Faktor im `expr`, 5.2) | `processes/cost_risks_2026` (`use: maintenance_level`) | 01a 3.3, Spec 00 §7.12 |
| `shared.<name>` | beliebig (Stützstellen, Faktoren) | statisch | – | Spec 00 §4.5 Regel 4, R-64 |

#### 1.9.1 Kanonische Marktnamen, die die Stochastikbibliothek bedient

`inflation`, `mortgage_rate`, `bund_yield_10y`, `mortgage_spread`, `rent_growth`, `rent_growth_new`,
`construction_price_index`, `maintenance_index`, `land_value_growth`, `market_value_growth`, `co2_price`,
`bio_fuel_premium`, `energy_price.<träger>`, `energy_network_fee.<träger>`, `feed_in_tariff.<klasse>`,
`vacancy_fluctuation`. Trägercodes (# 01b, hier verwendet): `gas`, `gas_mfh`, `oil`, `lpg`, `power`, `power_mfh`,
`heatpump_power`, `heatpump_power_mfh`, `district_heating`, `pellets`. Spec 00 §4.3.11 nennt bereits `inflation`,
`rent_growth`, `rent_growth_new`, `construction_price_index`, `maintenance_index`, `land_value_growth`,
`market_value_growth`, `mortgage_rate`, `co2_price`, `energy_price.<träger>`, `energy_network_fee.<träger>`,
`bio_fuel_premium`; neu sind `bund_yield_10y`, `mortgage_spread`, `feed_in_tariff.<klasse>`, `vacancy_fluctuation`
(Konkretisierung nach Spec 00 §4.3.11 „Kanonische Namen (Spec 01)“; Abgleich mit 01a).

### 1.10 Schlüssel- und Stromnamen, CRN-Regeln, Golden-Vektoren

#### 1.10.1 Stromnamen (Spec 00 §11.3, verbindlich)

| Strom | Schlüssel | Beispiel |
|---|---|---|
| `par:<key>:<b>` | statische Größe, unsicherer Prozessparameter, Förderzusage, verschobene Kurzform | `par:cost_huelle:3`, `par:inflation.mu:1`, `par:funding.kfw261.approved:10`, `par:measures.huelle.cost_eur:2` |
| `shock:<proc>:<b>` | Schocks des Prozesses | `shock:mortgage_rate:1` |
| `scen:<proc>:<b>` | Szenario-Uniform (`scenario_mix`) | `scen:co2_price:7` |
| `uni:<proc>:<b>` | weitere Uniforms (v1 ungenutzt) | – |
| `ic:<key>:<b>` | Score-Permutation Iman–Conover | `ic:cost_huelle:3` |

b ist der globale Blockindex 1…R mit R = n_sim / `block_size` (dezimal, ohne führende Nullen); Lauf i gehört zu
Block ⌈i/m⌉, die Ströme eines Blocks hängen nicht von n_sim ab (Spec 00 §11.4, R-73). Schlüssel sind ASCII (id-Regeln Spec 00
§4.4); Kurzform-Schlüssel enthalten Punkte, keine weiteren Sonderzeichen.

#### 1.10.2 Namenskonventionen (SOLL, CRN)

1. Prozessschlüssel = kanonischer Marktname mit `_` statt `.` (`inflation`, `mortgage_rate`, `energy_price_gas`,
   `co2_price`). Bibliotheks-Korrelationen (2.6) verwenden diese Schlüssel.
2. Statische Schlüssel `<thema>_<objekt>`: `cost_<measure_id>`, `delay_construction`, `delay_<measure_id>`,
   `life_<measure_id>`, `jaz_<measure_id>`, `prebound`, `rebound`, `vacancy_<group>`, `hardship_<group>`,
   `cap_rate_rv`, `rnd_rv`, `rate_<financing_id>`.
3. **Gleiches Risiko = gleicher Schlüssel** in allen Varianten (Zinspfad, Prebound des Haushalts, Kesselausfall).
   **Verwandte Risiken** (Baukosten zweier Ausführungen) = getrennte Schlüssel + `[cost_a, cost_b, 0.7]` (Konzept B9).
4. Ein zusätzlicher unkorrelierter Schlüssel verschiebt keine anderen Ziehungen; ein neuer Schlüssel in einer
   Korrelationsgruppe ändert die Ränge der Gruppe, nicht ihre Ränder (Spec 00 §11.10).

#### 1.10.3 Golden-Vektoren (Pflichttest WS-C, `test-sampling-rng.R`)

`stream_hash`/`stream_seed` nach Spec 00 §11.3; seed · 1000003 bleibt < 2^53 (max. 2,147490088e15), exakt in double.

| Name | `stream_hash` | `stream_seed(20261025, name)` |
|---|---:|---:|
| `par:huelle_kosten:1` | 82619639 | 1807676916 |
| `shock:mortgage_rate:1` | 1339347028 | 916920658 |
| `scen:co2_price:1` | 406293088 | 2131350365 |
| `ic:jaz:3` | 696621842 | 274195472 |
| `par:funding.kfw261.approved:10` | 873314676 | 450888306 |

LHS-Uniforms `par:huelle_kosten:1`, m = 10 (erst `sample.int(m)`, dann `runif(m)`, R 4.3.3, Mersenne-Twister/
Inversion/Rejection): 0,0770428277; 0,7377466243; 0,8153801601; 0,2168623472; 0,4181502454; 0,9103939940;
0,5083356354; 0,6902026086; 0,3590937947; 0,1715651234 (`sort(floor(u · 10)) == 0:9`). PERT(0,95; 1,10; 1,50) darauf:
1,00872837; 1,20510886; 1,23600605; 1,05493489; 1,10973613; 1,28741166; 1,13418902; 1,18860953; 1,09397463;
1,04146840. Schocks `shock:mortgage_rate:1`, Spalte 1 (y = 2): 0,14282540; 0,74789624; 0,31988633; −0,42734243;
1,27760831; −0,71211298; 1,98313306; −1,39581165; −1,15778342; −0,21440874. Pseudo `runif(5)` im Strom
`par:huelle_kosten:1`: 0,9472584811; 0,1823872703; 0,7804699554; 0,4783886457; 0,0081785580.

**Default-Blockgröße m = 200** (R-73): `par:huelle_kosten:1` u[1:5] = 0,6396843421; 0,8825087800; 0,5951837389;
0,1187823656; 0,2526394482 (Blockmittel 0,5000569179, Schichtung `sort(floor(200 u)) == 0:199`);
`par:huelle_kosten:2` (hash 82619640, seed 1807676917) u[1:5] = 0,8671389795; 0,5422675004; 0,1600440787;
0,1734603451; 0,1094319985. `par:funding.kfw261.approved:1` (seed 1698937791), p = 0,85: 170 Einsen, erste fünf
Läufe 1, 1, 1, 1, 0. Die Läufe 1…200 sind bei n_sim = 1.000 und 10.000 identisch (Präfix-Test, Spec 00 §15.5 Nr. 9).

### 1.11 Validierungsregeln des Overlays (Sammelliste für WS-B, Codes `validation.stochastic.*`)

| Code | Schwere | Regel |
|---|---|---|
| `unknown_key` | E | unbekannter Schlüssel in `stochastic` oder in einem Eintrag (mit Vorschlag) |
| `target_missing` | E | `target` fehlt oder existiert nicht (R-16) |
| `target_deterministic_only` | E | Ziel ist `deterministic_only` (Zeitparameter von Krediten, Codes, Plan-JAZ) |
| `target_duplicate` | E | Ziel doppelt (statisch/statisch, statisch/Prozess, Prozess/Prozess) |
| `target_not_path` | E | Prozessziel erlaubt Shape `path` nicht |
| `target_no_base` | E | deterministischer Basiswert des Ziels fehlt |
| `target_usually_fixed` | W | Ziel mit `stochastic = FALSE` |
| `dist_invalid` | E | `validate(par)` liefert Meldungen |
| `base_outside_support` | E | Basiswert außerhalb des Trägers (`apply: replace`) |
| `mode_differs_base` | I | Modus (PERT/Dreieck) ≠ deterministischer Basiswert (Memo 04 §10.1; erwartet z. B. bei Verzug 0 vs. Modus 2) |
| `share_unbounded` | W | `normal`/`lognormal` auf Ziel der Art `share` |
| `process_param_support` | E | Träger einer Parameterverteilung außerhalb des zulässigen Bereichs (1.5.2) |
| `linked_cycle` | E | Zyklus über `linked_ar1.base` |
| `corr_unknown_key`, `corr_self`, `corr_conflict`, `corr_range` | E | 1.7.1 |
| `corr_ties` | I | Rangkorrelation mit `bernoulli`/`discrete` |
| `corr_double_counting` | I | Schockkorrelation zwischen `linked_ar1` und seinem Basisprozess |
| `block_too_small` | E (`vofi_error_input` bei Laufstart) | m < max(2, d + 1) |
| `n_sim_not_multiple` | E (`vofi_error_input`) | n_sim kein Vielfaches von `block_size` (bzw. von `replicates` im F21-Modus), Vorschlag des nächsten Vielfachen |
| `block_and_replicates` | E | `block_size` und `replicates` zugleich gesetzt |
| `se_coarse` | I | R = n_sim/m < 10: Standardfehler „grob“ (se_df = R − 1) |
| `decision_correlated` | E | Schlüssel der Rolle `decision` (Entscheidungsknoten) in einer Korrelationsgruppe oder nicht 0/1-wertig (R-71) |
| `credit_amount_target` | E | Overlay- oder Designziel auf `financing.<id>.amount_eur` (`deterministic_only`, R-69); Unsicherheit über `approved` |
| `jaz_plan_target` | E | Overlay-Ziel auf `jaz_plan` (`deterministic_only`, R-70) |
| `antithetic_lhs` | E | `antithetic: true` mit `lhs` |
| `cost_risk_double` | W | Kostenüberschreitungsfaktor auf eine Maßnahme, deren Risikozuschlag selbst stochastisch ist (Konzept §3.2) |
| `prebound_with_measured` | W | `prebound_factor` stochastisch, obwohl `consumption_basis: measured` (Konzept B7) |
| `library_outdated` | W (`vofi_warning_library_outdated`) | Prozess-/Kalibrierungseintrag mit `as_of` älter als 12 Monate vor `legal_state` (Spec 00 §4.9) |

---

## 2. Kalibrierte Default-Stochastikbibliothek (`inst/extdata/library/processes/**`, WS-L)

### 2.1 Übersicht

Alle Einträge folgen dem Eintragsschema 3.1 mit `block: processes`. Prozess- und Kalibrierungseinträge lösen nach
12 Monaten `vofi_warning_library_outdated` aus (Spec 00 §4.9). Die Nutzlast `values` ist ein Overlay-Eintrag ohne
`target` (bzw. eine Map solcher Einträge, Auswahl mit `use:`); lokal gewinnt. Eintragsübergreifend gilt `valid_from:
2026-01-01`, `valid_to: null` (Kalibrierungen haben keine Rechtsgültigkeit; maßgeblich ist das Alter `as_of`).

| id | `use:` | Typ | übliches Ziel | Overlay-Schlüssel (SOLL, 1.10.2) | Qualität | Quelle |
|---|---|---|---|---|---|---|
| `processes/inflation_ar1_2026` | – | `ar1` | `market.inflation` | `inflation` | D (φ, σ aus Daten: A) | Memo 04 §2.3, Memo 03 §5.1 |
| `processes/mortgage_rate_vasicek_2026` | – | `vasicek` | `market.mortgage_rate` | `mortgage_rate` | D (κ, σ aus SUD119: A) | Memo 04 §2.3, E13; Konzept F7 |
| `processes/bund10_vasicek_2026` | – | `vasicek` | `market.bund_yield_10y` | `bund_yield_10y` | D | Memo 03 §4.3 |
| `processes/mortgage_spread_ar1_2026` | – | `ar1` | `market.mortgage_spread` | `mortgage_spread` | D | Memo 03 §4.3 |
| `processes/rent_growth_linked_2026` | – | `linked_ar1` | `market.rent_growth` | `rent_growth` | D | Memo 04 §1.2, Konzept §4.2 |
| `processes/rent_growth_new_linked_2026` | – | `linked_ar1` | `market.rent_growth_new` | `rent_growth_new` | D | Memo 04 §1.2, Memo 03 §5.3 |
| `processes/construction_price_linked_2026` | – | `linked_ar1` | `market.construction_price_index` | `construction_price_index` | D (a, φ, σ aus Eurostat: A) | Memo 04 §2.3 |
| `processes/maintenance_cost_linked_2026` | – | `linked_ar1` | `market.maintenance_index` | `maintenance_index` | D | Memo 03 §5.2 |
| `processes/energy_prices_mr_2026` | `gas`, `gas_mfh`, `power`, `heatpump_power`, `heatpump_power_mfh`, `oil`, `district_heating`, `pellets`, `bio_premium_factor`, `network_fee_growth` | `mr_trend`; statisch | `market.energy_price.<träger>` u. a. | `energy_price_<träger>` | D (φ, σ aus HVPI: A) | Memo 03 §2.3–2.4, Memo 04 §2.3, Konzept B8/F20 |
| `processes/co2_price_corridor_2026` | – | `scenario_mix` (20 Quantilpfade) | `market.co2_price` | `co2_price` | D | Memo 03 §3.4, Konzept B6/F8 |
| `processes/shock_correlations_2026` | – | Liste | `stochastic.correlations.shocks` | – | D | Memo 03 §2.3, Memo 04 §2.3, Konzept §4.2 |
| `processes/param_correlations_2026` | – | Liste | `stochastic.correlations.parameters` | – | D | Memo 04 §3.1 |
| `processes/cost_risks_2026` | `overrun_newbuild`, `overrun_retrofit`, `overrun_component`, `delay_newbuild`, `delay_retrofit`, `maintenance_level` | statisch | `measures.<id>.cost_factor` bzw. `project.construction_cost_factor`, `project.construction_delay_months`, `measures.<id>.delay_months`, `building.maintenance.rate_eur_m2_pa` | `cost_<id>`, `delay_construction`, `delay_<id>`, `maint_level` | D | Memo 04 §1.2, Memo 07 §4.0/§4.3, Konzept §4.2 |
| `processes/energy_performance_2026` | `prebound`, `rebound`, `realisation`, `jaz_air_water_existing`, `jaz_air_water_newbuild`, `jaz_ground_existing`, `jaz_air_water_mfh_central`, `jaz_relative` | statisch | `energy.performance_gap.*`, `energy.<zustand>.jaz` | `prebound`, `rebound`, `realisation`, `jaz_<id>` | C/D | Memo 04 §1.2, Memo 03 §7.2, Konzept B7 |
| `processes/funding_risks_2026` | `availability_post2030`, `feed_in_continuation`, `payout_delay`, `repayment_grant_cut` | statisch | `funding.<id>.approved`, `market.feed_in_tariff.<klasse>`, `funding.<id>.payout_delay_months`, `funding.<id>.repayment_grant.cut_share` | `funding.<id>.approved`, `feed_in`, `payout_delay_<id>`, `tz_cut_<id>` | D | Memo 07 §4.0, Konzept B12, Spec 00 §9.11 Nr. 7 |
| `processes/valuation_risks_2026` | `cap_rate_shock`, `remaining_life_shock`, `vacancy_level`, `vacancy_fluctuation`, `market_value_uplift_efficiency` | statisch; `iid` | `residual_value.*`, `shared.vacancy_level`, `market.vacancy_fluctuation` | `cap_rate_rv`, `rnd_rv`, `vacancy_<group>`, `vacancy_fluct` | D | Memo 04 §1.2, Memo 07 §4.0, Konzept §4.2 |

Förderzusagewahrscheinlichkeiten stehen in den Fördereinträgen (`budget_risk.approval_probability`, 3.4) und erzeugen
den automatischen Schlüssel `funding.<id>.approved` (Spec 00 §11.6 Nr. 4). Nutzungsdauer-Verteilungen stehen im Feld
`uncertainty` von `costs/nutzungsdauern_2026` (3.7).

### 2.2 Zinsen

```yaml
# inst/extdata/library/processes/mortgage_rate_vasicek_2026.yaml   (Standard, Konzept F7)
id: processes/mortgage_rate_vasicek_2026
block: processes
schema_version: 1
label: "Bauzins 10 J. (Anschlussfinanzierung): Vasicek mit Untergrenze"
source:
  document: "Deutsche Bundesbank, MFI-Zinsstatistik SUD119 (BBIM1.M.DE.B.A2C.P.R.A.2250.EUR.N), 01/2003-08/2026; eigene Kalibrierung (Memo 04 §2.3)"
  url: "https://api.statistiken.bundesbank.de/rest/data/BBIM1/M.DE.B.A2C.P.R.A.2250.EUR.N"
  publisher: "Deutsche Bundesbank"
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D                       # theta normativ gesetzt (Stichprobenmittel 2,74 % durch Niedrigzinsphase verzerrt)
quality_detail: {kappa: A, sigma: A, r0: A}
fallback: {r0: 0.041}            # Default-Bauzins 10 J. (Memo 03 §4.1, Konzept §3.10); S1–S5: 0.040
values:
  type: vasicek
  label: "Bauzins 10 J. Zinsbindung (Anschlusszins)"
  r0: base                       # Startwert = deterministischer Bauzins des Szenarios (1.5.1)
  theta: 0.0375                  # Option Parameterunsicherheit: {dist: normal, mean: 0.0375, sd: 0.005}
  kappa: 0.12                    # OLS Jahresmittel 0,13; Monatsdaten 0,089 (Memo 04 §2.3)
  sigma: 0.007                   # Jahresmittel 0,0054; sd 12-Monats-Änderung 0,0060; Punktvolatilität höher angesetzt
  floor: 0.005
notes: "Ausgabe gekappt, Zustand ungekappt (Spec 00 §11.7). Anschlusszins = Pfadwert der Periode des Anpassungsmonats (R-45)."
```

```yaml
# inst/extdata/library/processes/bund10_vasicek_2026.yaml   (Alternative: zwei Faktoren, Konzept F7; mit K12)
id: processes/bund10_vasicek_2026
block: processes
schema_version: 1
label: "Rendite Bundesanleihe 10 J.: Vasicek"
source:
  document: "Deutsche Bundesbank BBSIS (Svensson) 1973-2025, eigene Auswertung (Memo 03 §4.2-4.3)"
  url: "https://api.statistiken.bundesbank.de/rest/data/BBSIS"
  publisher: "Deutsche Bundesbank"
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
fallback: {r0: 0.034}            # Svensson 10 J. am 23.10.2026: 3,39 %
values:
  type: vasicek
  label: "Bundrendite 10 J."
  r0: base
  theta: {dist: triangular, min: 0.020, mode: 0.028, max: 0.035}   # normativ: r* 0,5-1 % + Inflation 2 % + Laufzeitprämie
  kappa: 0.12                    # Spanne 0,06-0,20
  sigma: 0.0075                  # Spanne 0,0055-0,0095
  floor: -0.01
```

```yaml
# inst/extdata/library/processes/mortgage_spread_ar1_2026.yaml   (Alternative, mit K12)
id: processes/mortgage_spread_ar1_2026
block: processes
schema_version: 1
label: "Spread Bauzins (> 10 J.) über Bund 10 J.: AR(1)"
source:
  document: "Bundesbank SUD119 minus BBSIS 10 J., Monatswerte 2003-08/2026: Mittel 1,21 Pp, sd 0,40, seit 2015 1,43, 08/2026 0,67 (Memo 03 §4.2)"
  url: "https://api.statistiken.bundesbank.de/rest/data/"
  publisher: "Deutsche Bundesbank"
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
fallback: {x0: 0.007}
values:
  type: ar1
  label: "Bauzins-Spread"
  mu: 0.010                      # Spanne 0,006-0,015; Wohnungsunternehmen 0,006-0,009
  phi: 0.7
  sigma: 0.002
  x0: base
notes: "Langfristmittel Bauzins = 0,028 + 0,010 = 0,038 (Standardprozess: theta 0,0375)."
```

### 2.3 Inflation, Mieten, Baupreise, Instandhaltung

```yaml
# inst/extdata/library/processes/inflation_ar1_2026.yaml
id: processes/inflation_ar1_2026
block: processes
schema_version: 1
label: "Inflation VPI: AR(1) mit unsicherem Langfristmittel"
source:
  document: "Eurostat HVPI DE prc_hicp_aind 1997-2025 (AR(1): mu 2,02 %, phi 0,55, sigma_e 1,43 Pp); Projektionen Bundesbank 06/2026, EZB 09/2026 (Memo 04 §2.3, Memo 03 §5.1)"
  url: "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/prc_hicp_aind"
  publisher: "Eurostat; Deutsche Bundesbank; EZB"
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
quality_detail: {phi: A, sigma: A}
fallback: {x0: 0.026}            # prices/macro_paths_2026: 2027 2,6 %; S1–S5: 0,028
values:
  type: ar1
  label: "Inflationsrate VPI"
  mu: {dist: normal, mean: 0.020, sd: 0.004}   # Konzept §4.2: N(2,0 %; 0,3-0,5 Pp)
  phi: 0.5
  sigma: 0.011                   # Memo 04: 0,010-0,012; Memo 03: 0,0145 (inkl. 2022/23)
  x0: base
```

```yaml
# inst/extdata/library/processes/rent_growth_linked_2026.yaml
id: processes/rent_growth_linked_2026
block: processes
schema_version: 1
label: "Bestandsmietsteigerung, gekoppelt an die Inflation"
source:
  document: "HVPI CP041 Nettokaltmieten 2000-2025 +1,35 % p. a. (sd 0,35 Pp), GdW 2010-2024 +2,2 % p. a.; Kopplung b = 0,6-0,8 (Memo 04 §1.2, Memo 03 §5.3, Konzept §4.2)"
  url: "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/prc_hicp_aind"
  publisher: "Eurostat; GdW"
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
fallback: {u0: 0.0}
values:
  type: linked_ar1
  label: "Mietsteigerung Bestand p. a."
  base: inflation                # Prozessschlüssel der Inflation im selben Overlay
  a: 0.002
  b: 0.8
  phi: 0.5
  sigma: 0.006
  u0: base
notes: "Langfristmittel 0,002 + 0,8 · 0,020 = 0,018 (Memo 03 Default 0,0175). Keine Schockkorrelation zur Inflation (strukturell gekoppelt). Die rechtliche Logik (§ 558-Kappung, Index, Staffel) wirkt im Typ rent_path (# 01b)."
```

```yaml
# inst/extdata/library/processes/rent_growth_new_linked_2026.yaml
id: processes/rent_growth_new_linked_2026
block: processes
schema_version: 1
label: "Neuvertrags-/Marktmietsteigerung, gekoppelt an die Inflation"
source:
  document: "ImmoScout24 WohnBarometer Q2/2026, GREIX Q4/2025, vdp Q4/2025 (Sek.); Memo 04 §1.2 (sigma 2-3 Pp)"
  url: "https://www.immobilienscout24.de/unternehmen/fileadmin/user_upload/WohnBarometer_Q2_2026_Miete.pdf"
  publisher: "ImmoScout24; IfW Kiel; vdp"
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
fallback: {u0: 0.0}
values:
  type: linked_ar1
  label: "Mietsteigerung Neuvertrag/Markt p. a."
  base: inflation
  a: 0.005                       # Langfristmittel 0,025 (Memo 03: 2,5 %, Spanne 0-5 %)
  b: 1.0
  phi: 0.5
  sigma: 0.02
  u0: base
```

```yaml
# inst/extdata/library/processes/construction_price_linked_2026.yaml
id: processes/construction_price_linked_2026
block: processes
schema_version: 1
label: "Baupreisindex Wohngebäude, gekoppelt an die Inflation"
source:
  document: "Eurostat sts_copi_a PRC_PRR DE 1997-2025: Mittel 2,68 %, AR(1) phi 0,65, Prämie über HVPI 0,73 Pp, Korrelation 0,88 (Memo 04 §2.3); Destatis 08/2026 +5,5 % (Memo 03 §5.2)"
  url: "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_copi_a"
  publisher: "Eurostat; Destatis"
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
quality_detail: {phi: A}
fallback: {u0: 0.0}
values:
  type: linked_ar1
  label: "Baupreissteigerung p. a."
  base: inflation
  a: 0.007                       # Memo 03: VPI + 0,75 Pp (Spanne 0-2 Pp)
  b: 1.0                         # Regression 1,74 (Rest-sd 1,6 Pp); b = 1,0-1,5 (Memo 04)
  phi: 0.65
  sigma: 0.015
  u0: base
```

```yaml
# inst/extdata/library/processes/maintenance_cost_linked_2026.yaml
id: processes/maintenance_cost_linked_2026
block: processes
schema_version: 1
label: "Kostensteigerung Instandhaltung, gekoppelt an die Inflation"
source:
  document: "HVPI CP0432 2000-2025 +3,67 % p. a.; Destatis Instandhaltung Wohngebäude 08/2026 +6,0 % (Memo 03 §5.2)"
  url: "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/prc_hicp_aind"
  publisher: "Eurostat; Destatis"
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
fallback: {u0: 0.0}
values:
  type: linked_ar1
  label: "Kostensteigerung Instandhaltung p. a."
  base: inflation
  a: 0.010                       # VPI + 1,0 Pp (Spanne 0-2 Pp)
  b: 1.0
  phi: 0.65
  sigma: 0.015
  u0: base
```

### 2.4 Energiepreise (Mean-Reversion vom 12-Monats-Mittel zum Normalpreis, Konzept B8)

Konvention (K4, # 01b §3.2.1): `market.energy_price.<träger>` ist der **Arbeitspreis netto (ohne USt) ohne
CO2-Komponente und ohne getrennt geführtes Netzentgelt** („Commodity + Rest“; Gas: Netzentgelt netto in
`market.energy_network_fee.gas`); Strom, Wärmepumpenstrom, Fernwärme und Pellets ohne getrenntes Netzentgelt. Die
USt rechnet der Typ `energy_cost` über `energy.carriers.<c>.vat_rate` (Default 0,19; Pellets 0,07, C, Prüfpunkt
Anlage 2 Nr. 48 UStG). p0 = 12-Monats-Mittel (Nov. 2025–Okt. 2026), p_norm = Normalpreis (Memo 03 §2.4, real 2026,
D); nominales Trendwachstum g = realer Trend + 2,0 % Inflation. Herleitung Gas EFH: Gesamtpreis 12,0 ct brutto =
10,084 ct netto inkl. CO2 bei 65 €/t (0,1814 kg/kWh_Hs · 65 €/t = 1,179 ct netto) und Netzentgelt 2,57 ct netto →
p0 = 6,335 ct; p_norm = 10,0/1,19 − 2,57 = 5,833 ct; MFH: 11,2/1,19 − 1,179 − 2,19 = 6,043 ct, p_norm = 9,80 ·
(10,0/10,6)/1,19 − 2,19 = 5,58 ct (D). Übrige Träger: brutto/1,19 (Pellets /1,07).

```yaml
# inst/extdata/library/processes/energy_prices_mr_2026.yaml
id: processes/energy_prices_mr_2026
block: processes
schema_version: 1
label: "Energiepreise 2026 (netto): Mean-Reversion um Trend (ohne CO2-Komponente)"
source:
  document: "BDEW Gas-/Strompreisanalyse 08/2026, BNetzA Monitoringbericht 2025, waermepreise.info 04/2026, DEPI 10/2026; HVPI-Teilindizes DE 1996-2025, eigene AR(1)-Schätzung realer Log-Preise (Memo 03 §2.1-2.4, Memo 04 §2.3)"
  url: "https://www.bdew.de/media/documents/BDEW_Gaspreisanalyse_082026.pdf"
  publisher: "BDEW; BNetzA; Eurostat; DEPI"
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D                                  # Normalpreise und Trends: Expertenschätzung
quality_detail: {gas.p0: B, gas_mfh.p0: B, power.p0: A, heatpump_power.p0: D, heatpump_power_mfh.p0: D, oil.p0: C, district_heating.p0: B, pellets.p0: C}
fallback:                                   # EUR/kWh netto
  gas: {p0: 0.06335}
  gas_mfh: {p0: 0.06043}
  power: {p0: 0.31513}
  heatpump_power: {p0: 0.21849}
  heatpump_power_mfh: {p0: 0.21008}
  oil: {p0: 0.10034}
  district_heating: {p0: 0.13109}
  pellets: {p0: 0.07944}
values:
  gas:                                      # Erdgas EFH, Hs, ohne CO2 und Netzentgelt
    type: mr_trend
    label: "Erdgaspreis EFH (ohne CO2, ohne Netzentgelt)"
    p0: base
    p_norm: 0.05833
    growth: {dist: normal, mean: 0.020, sd: 0.010}
    phi: 0.75                               # Memo 03: 0,79 (real 1996-2025); Memo 04: 0,75-0,8
    sigma: 0.08                             # Memo 04/Konzept F20: 8 %; historisch 10,2 % nominal (inkl. 2022)
  gas_mfh:
    type: mr_trend
    label: "Erdgaspreis MFH (ohne CO2, ohne Netzentgelt)"
    p0: base
    p_norm: 0.05580                         # D
    growth: {dist: normal, mean: 0.020, sd: 0.010}
    phi: 0.75
    sigma: 0.08
  power:
    type: mr_trend
    label: "Haushaltsstrompreis"
    p0: base
    p_norm: 0.30252
    growth: {dist: normal, mean: 0.020, sd: 0.007}
    phi: 0.75
    sigma: 0.04                             # Konzept §4.2/F20: 4 %; Memo 03: 4,5 %
  heatpump_power:
    type: mr_trend
    label: "Wärmepumpenstrom EFH (separater Zähler)"
    p0: base
    p_norm: 0.21008
    growth: {dist: normal, mean: 0.020, sd: 0.007}
    phi: 0.75
    sigma: 0.05                             # Memo 03 §17
  heatpump_power_mfh:
    type: mr_trend
    label: "Wärmepumpenstrom Zentral-WP MFH"
    p0: base
    p_norm: 0.20168                         # D
    growth: {dist: normal, mean: 0.020, sd: 0.007}
    phi: 0.75
    sigma: 0.05
  oil:
    type: mr_trend
    label: "Heizölpreis (Hi, ohne CO2)"
    p0: base
    p_norm: 0.06723
    growth: {dist: normal, mean: 0.020, sd: 0.012}
    phi: 0.70
    sigma: 0.18
  district_heating:
    type: mr_trend
    label: "Fernwärmepreis (Mischpreis)"
    p0: base
    p_norm: 0.12605
    growth: {dist: normal, mean: 0.025, sd: 0.008}
    phi: 0.80
    sigma: 0.07
  pellets:
    type: mr_trend
    label: "Holzpelletpreis (Hi)"
    p0: base
    p_norm: 0.06542
    growth: {dist: normal, mean: 0.025, sd: 0.008}
    phi: 0.60
    sigma: 0.09
  bio_premium_factor:                       # statisch, Ziel market.bio_fuel_premium
    dist: triangular
    label: "Faktor Biomethan-Mehrkosten"
    min: 0.5                                # 3 ct/kWh netto bei Basis 6 ct
    mode: 1.0
    max: 1.6667                             # 10 ct/kWh netto
    apply: multiply
  network_fee_growth:                       # statisch, Ziel shared.network_fee_growth_<träger>
    dist: triangular
    label: "Wachstum Gasnetzentgelte p. a."
    min: 0.0
    mode: 0.03
    max: 0.08
notes: "Schockkorrelationen in processes/shock_correlations_2026. Spotalternative Heizöl 17,2 ct (prices/energy_prices_2026)."
```

### 2.5 CO2-Preis: Korridore mit komonotoner Dreiecksziehung

Deterministischer Basispfad: `prices/co2_price_paths_2026`, `use: scenarios.mittel` (3.6). MC: 20 Quantilpfade
q_k = Q_tri((k − 0,5)/20; niedrig, mittel, hoch) je Stützjahr (Konzept B6: komonoton, mittel = Modus), nach 2050
+2 %/a nominal (real konstant, Abl.). Rauschen standardmäßig aus; Option `noise: {phi: 0.5, sigma: 0.10}` (Memo 03 §3.4).

```yaml
# inst/extdata/library/processes/co2_price_corridor_2026.yaml
id: processes/co2_price_corridor_2026
block: processes
schema_version: 1
label: "CO2-Preis Gebäude (BEHG bis 2027, ab 2028 EU-ETS 2): komonotoner Korridor niedrig/mittel/hoch"
source:
  document: "Memo 03 §3.4 (Korridore; hoch = UBA/Prognos Rahmendaten THG-Projektionen 2026); Diskretisierung K = 20 (Spec 01 Teil C §1.6.6)"
  url: "https://www.umweltbundesamt.de/system/files/medien/11850/publikationen/2026-04/2026_Rahmendatenpapier.pdf"
  publisher: "UBA/Prognos; eigene Ableitung"
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
values:
  type: scenario_mix
  label: "CO2-Preis (EUR/t, nominal, netto)"
  scenarios:
    q01: {prob: 0.05, years: &co2y [2026, 2027, 2028, 2030, 2032, 2035, 2040, 2045, 2050, 2060, 2070], values: [65.00, 57.50, 49.33, 60.92, 68.44, 88.11, 117.50, 142.75, 168.00, 204.79, 249.63]}
    q02: {prob: 0.05, years: *co2y, values: [65.00, 59.33, 52.50, 65.25, 74.62, 97.71, 130.31, 159.40, 188.49, 229.77, 280.09]}
    q03: {prob: 0.05, years: *co2y, values: [65.00, 60.59, 54.68, 68.23, 78.87, 104.32, 139.13, 170.87, 202.60, 246.97, 301.05]}
    q04: {prob: 0.05, years: *co2y, values: [65.00, 61.61, 56.46, 70.65, 82.33, 109.69, 146.30, 180.19, 214.07, 260.95, 318.10]}
    q05: {prob: 0.05, years: *co2y, values: [65.00, 62.50, 57.99, 72.75, 85.32, 114.33, 152.50, 188.25, 223.99, 273.04, 332.83]}
    q06: {prob: 0.05, years: *co2y, values: [65.00, 63.29, 59.36, 74.62, 88.00, 118.48, 158.04, 195.45, 232.85, 283.84, 346.00]}
    q07: {prob: 0.05, years: *co2y, values: [65.00, 64.01, 60.63, 76.39, 90.44, 122.27, 163.10, 202.02, 240.94, 293.70, 358.02]}
    q08: {prob: 0.05, years: *co2y, values: [65.00, 64.68, 61.93, 78.23, 92.88, 125.78, 167.78, 208.11, 248.43, 302.83, 369.15]}
    q09: {prob: 0.05, years: *co2y, values: [65.00, 65.32, 63.28, 80.14, 95.41, 129.05, 172.21, 213.93, 255.65, 311.64, 379.89]}
    q10: {prob: 0.05, years: *co2y, values: [65.00, 65.97, 64.69, 82.13, 98.06, 132.22, 176.78, 219.98, 263.18, 320.82, 391.08]}
    q11: {prob: 0.05, years: *co2y, values: [65.00, 66.65, 66.17, 84.23, 100.84, 135.53, 181.58, 226.33, 271.08, 330.45, 402.81]}
    q12: {prob: 0.05, years: *co2y, values: [65.00, 67.38, 67.73, 86.43, 103.77, 139.02, 186.63, 233.02, 279.41, 340.60, 415.19]}
    q13: {prob: 0.05, years: *co2y, values: [65.00, 68.14, 69.38, 88.77, 106.88, 142.72, 191.99, 240.11, 288.24, 351.36, 428.31]}
    q14: {prob: 0.05, years: *co2y, values: [65.00, 68.96, 71.15, 91.27, 110.20, 146.67, 197.72, 247.70, 297.68, 362.88, 442.34]}
    q15: {prob: 0.05, years: *co2y, values: [65.00, 69.84, 73.06, 93.98, 113.79, 150.95, 203.91, 255.90, 307.89, 375.31, 457.50]}
    q16: {prob: 0.05, years: *co2y, values: [65.00, 70.81, 75.16, 96.94, 117.73, 155.63, 210.70, 264.88, 319.07, 388.94, 474.12]}
    q17: {prob: 0.05, years: *co2y, values: [65.00, 71.90, 77.50, 100.25, 122.13, 160.87, 218.29, 274.93, 331.58, 404.19, 492.70]}
    q18: {prob: 0.05, years: *co2y, values: [65.00, 73.15, 80.21, 104.08, 127.22, 166.93, 227.07, 286.56, 346.04, 421.82, 514.20]}
    q19: {prob: 0.05, years: *co2y, values: [65.00, 74.70, 83.54, 108.80, 133.48, 174.38, 237.88, 300.86, 363.84, 443.52, 540.65]}
    q20: {prob: 0.05, years: *co2y, values: [65.00, 76.94, 88.39, 115.65, 142.58, 185.21, 253.57, 321.63, 389.69, 475.03, 579.06]}
notes: "Erwartungspfad (Stützjahre) 65,00; 66,66; 66,66; 84,99; 101,65; 134,99; 181,65; 226,64; 271,64; 331,12; 403,64 (exakt dreieckig: 85,00 in 2030, 181,67 in 2040). Merkmal co2_price.scenario = Quantilindex 1-20 für bedingte Auswertungen."
```

YAML-Anker und -Aliase (`&co2y`, `*co2y`) sind zulässig (Memo 05 §4.8); `io_read_yaml_utf8()` löst sie auf.

### 2.6 Korrelationen

```yaml
# inst/extdata/library/processes/shock_correlations_2026.yaml
id: processes/shock_correlations_2026
block: processes
schema_version: 1
label: "Korrelation der Jahresschocks (geschrumpft)"
source:
  document: "Korrelation jährlicher Änderungen HVPI-Teilindizes, Baupreise, Bund 10 J. 2001-2025, um 30-40 % geschrumpft (Memo 03 §2.3, §17 correlation_innovations); VPI-Gas 0,6, Gas-Strom 0,5, VPI-Bauzins 0,4 (Memo 04 §2.3, Konzept §4.2)"
  url: "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/prc_hicp_aind"
  publisher: "Eurostat; Deutsche Bundesbank; eigene Ableitung"
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
values:                                    # [Prozess a, Prozess b, rho]; Schlüssel nach 1.10.2
  - [inflation, mortgage_rate, 0.40]
  - [inflation, energy_price_gas, 0.60]
  - [inflation, energy_price_gas_mfh, 0.60]
  - [inflation, energy_price_power, 0.40]
  - [inflation, energy_price_heatpump_power, 0.40]
  - [inflation, energy_price_heatpump_power_mfh, 0.40]
  - [inflation, energy_price_oil, 0.40]
  - [inflation, energy_price_district_heating, 0.40]
  - [inflation, energy_price_pellets, 0.45]
  - [mortgage_rate, energy_price_gas, 0.35]
  - [mortgage_rate, energy_price_gas_mfh, 0.35]
  - [mortgage_rate, energy_price_power, 0.30]
  - [mortgage_rate, energy_price_heatpump_power, 0.30]
  - [mortgage_rate, energy_price_heatpump_power_mfh, 0.30]
  - [mortgage_rate, energy_price_oil, 0.20]
  - [mortgage_rate, energy_price_district_heating, 0.20]
  - [mortgage_rate, energy_price_pellets, 0.35]
  - [energy_price_gas, energy_price_gas_mfh, 0.95]
  - [energy_price_gas, energy_price_power, 0.50]
  - [energy_price_gas, energy_price_heatpump_power, 0.50]
  - [energy_price_gas, energy_price_heatpump_power_mfh, 0.50]
  - [energy_price_gas, energy_price_oil, 0.35]
  - [energy_price_gas, energy_price_district_heating, 0.50]
  - [energy_price_gas, energy_price_pellets, 0.45]
  - [energy_price_gas_mfh, energy_price_power, 0.50]
  - [energy_price_gas_mfh, energy_price_heatpump_power, 0.50]
  - [energy_price_gas_mfh, energy_price_heatpump_power_mfh, 0.50]
  - [energy_price_gas_mfh, energy_price_oil, 0.35]
  - [energy_price_gas_mfh, energy_price_district_heating, 0.50]
  - [energy_price_gas_mfh, energy_price_pellets, 0.45]
  - [energy_price_power, energy_price_heatpump_power, 0.90]
  - [energy_price_power, energy_price_heatpump_power_mfh, 0.90]
  - [energy_price_heatpump_power, energy_price_heatpump_power_mfh, 0.95]
  - [energy_price_power, energy_price_oil, 0.30]
  - [energy_price_heatpump_power, energy_price_oil, 0.30]
  - [energy_price_heatpump_power_mfh, energy_price_oil, 0.30]
  - [energy_price_power, energy_price_district_heating, 0.20]
  - [energy_price_heatpump_power, energy_price_district_heating, 0.20]
  - [energy_price_heatpump_power_mfh, energy_price_district_heating, 0.20]
  - [energy_price_power, energy_price_pellets, 0.50]
  - [energy_price_heatpump_power, energy_price_pellets, 0.50]
  - [energy_price_heatpump_power_mfh, energy_price_pellets, 0.50]
  - [energy_price_oil, energy_price_district_heating, 0.25]
  - [energy_price_oil, energy_price_pellets, 0.35]
  - [energy_price_district_heating, energy_price_pellets, 0.20]
notes: "Keine Paare mit rent_growth, construction_price_index, maintenance_index (strukturell gekoppelt). Fehlende Schlüssel werden verworfen (1.7.1). MFH-Varianten tragen dieselben Korrelationen wie die EFH-Prozesse (sonst nicht positiv definit: ohne Spiegelung kleinster Eigenwert −0,389). Prüfwerte: volle 10 × 10-Matrix kleinster Eigenwert 0,05 (Eigenwerte 5,06475; 1,47189; 0,87818; 0,80099; 0,59464; 0,52757; 0,44568; 0,11631; 0,05; 0,05); Teilmatrix der acht Kernprozesse inflation, mortgage_rate, energy_price_{gas, power, heatpump_power, oil, district_heating, pellets}: 3,77181; 1,13739; 0,81782; 0,78155; 0,55072; 0,48524; 0,35546; 0,10000 (positiv definit, keine Reparatur)."
```

Verwendung: `stochastic.correlations.shocks: {from: processes/shock_correlations_2026}` (die Nutzlast ist eine
Sequenz und ersetzt die lokale Liste; eigene Paare über eine zweite, lokale Liste sind nicht mischbar – wer ergänzen
will, kopiert die Liste).

```yaml
# inst/extdata/library/processes/param_correlations_2026.yaml
id: processes/param_correlations_2026
block: processes
schema_version: 1
label: "Rangkorrelationen statischer Größen (Defaults)"
source:
  document: "Memo 04 §3.1 (Kosten-Verzug 0,5; Prebound-Rebound 0,3; Inflationsmittel-Zinsniveau 0,5); Konzept B9 (verwandte Kostenrisiken 0,7)"
  url: "docs/recherche/04_monte_carlo.md"
  publisher: "eigene Ableitung"
as_of: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
values:
  - [delay_construction, cost_construction, 0.5]
  - [prebound, rebound, 0.3]
  - [inflation.mu, mortgage_rate.theta, 0.5]      # nur wirksam, wenn theta als Verteilung gesetzt ist
```

### 2.7 Statische Vorlagen

```yaml
# inst/extdata/library/processes/cost_risks_2026.yaml
id: processes/cost_risks_2026
block: processes
schema_version: 1
label: "Kosten- und Terminrisiken (Faktoren auf die Kostenschätzung inkl. Risikozuschlag)"
source:
  document: "Memo 04 §1.2 (PERT-Defaults), Memo 07 §4.0, §4.3 (Komponententausch), Konzept §3.2 und §4.2"
  url: "docs/recherche/04_monte_carlo.md"
  publisher: "eigene Ableitung (Expertenschätzung)"
as_of: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
values:
  overrun_newbuild:   {dist: pert, label: "Baukostenabweichung Neubau (Faktor)", min: 0.95, mode: 1.05, max: 1.35, apply: multiply}
  overrun_retrofit:   {dist: pert, label: "Baukostenabweichung Sanierung im Bestand (Faktor)", min: 0.95, mode: 1.10, max: 1.50, apply: multiply}
  overrun_component:  {dist: pert, label: "Kostenabweichung Komponententausch (Faktor)", min: 0.95, mode: 1.00, max: 1.20, apply: multiply}
  delay_newbuild:     {dist: pert, label: "Bauzeitverzug Neubau (Monate)", min: 0, mode: 2, max: 12}
  delay_retrofit:     {dist: pert, label: "Bauzeitverzug Sanierung (Monate)", min: 0, mode: 1, max: 6}
  maintenance_level:  {dist: pert, label: "Instandhaltungs-/Bewirtschaftungsniveau (Faktor)", min: 0.85, mode: 1.0, max: 1.3, apply: multiply}
notes: "Rangkorrelation Kosten-Verzug 0,5 (processes/param_correlations_2026). Basisfall: Faktor 1, Verzug 0 (I mode_differs_base erwartet)."
```

```yaml
# inst/extdata/library/processes/energy_performance_2026.yaml
id: processes/energy_performance_2026
block: processes
schema_version: 1
label: "Einsparrealisierung (Performance Gap) und realisierte JAZ"
source:
  document: "Memo 04 §1.2 (Prebound/Rebound, Realisierungsgrad); Fraunhofer ISE WP-QS im Bestand über 42watt (Sek.), Memo 03 §7.2; Konzept B7"
  url: "https://42watt.de/magazin/jahresarbeitszahl"
  publisher: "Fraunhofer ISE (Sek.); eigene Ableitung"
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
quality_detail: {jaz_air_water_existing: C, jaz_ground_existing: C}
values:
  prebound:      {dist: pert, label: "Prebound-Faktor (Verbrauch/Bedarf vor Sanierung)", min: 0.5, mode: 0.7, max: 1.0}
  rebound:       {dist: pert, label: "Rebound-Faktor (Verbrauch/Bedarf nach Sanierung)", min: 0.9, mode: 1.1, max: 1.4}
  realisation:   {dist: pert, label: "Realisierungsgrad der berechneten Einsparung", min: 0.4, mode: 0.8, max: 1.05}
  jaz_air_water_existing:    {dist: pert, label: "JAZ Luft/Wasser-WP Bestand (realisiert)", min: 2.6, mode: 3.2, max: 4.0}
  jaz_air_water_newbuild:    {dist: pert, label: "JAZ Luft/Wasser-WP Neubau (realisiert)", min: 3.2, mode: 3.8, max: 4.6}
  jaz_ground_existing:       {dist: pert, label: "JAZ Sole/Wasser-WP Bestand (realisiert)", min: 3.4, mode: 4.0, max: 4.8}
  jaz_air_water_mfh_central: {dist: pert, label: "JAZ Zentral-WP MFH inkl. WW (realisiert)", min: 2.4, mode: 2.9, max: 3.5}
  jaz_relative:              {dist: pert, label: "JAZ realisiert relativ zum Planwert", min: 0.8125, mode: 1.0, max: 1.25, apply: multiply}
notes: "Mit Verbrauchsdaten (consumption_basis: measured) entfällt prebound (W prebound_with_measured). Die Plan-JAZ (VDI 4650, § 559f) ist deterministic_only und nie Ziel (# 01b)."
```

```yaml
# inst/extdata/library/processes/funding_risks_2026.yaml
id: processes/funding_risks_2026
block: processes
schema_version: 1
label: "Förder- und Vergütungsrisiken"
source:
  document: "Memo 07 §4.0 (Förderverfügbarkeit nach 2030 p = 0,7; EEG-Reform p = 0,5), Konzept B12 (Kürzung TZ, Voreinstellung 0)"
  url: "docs/recherche/07_use_cases_referenzszenarien.md"
  publisher: "eigene Ableitung"
as_of: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
values:
  availability_post2030: {dist: bernoulli, label: "Förderprogramm nach 2030 verfügbar", p: 0.7}   # einfache Ziehung (Rolle value, on_reject), kein Entscheidungsknoten
  feed_in_continuation:  {dist: bernoulli, label: "feste Einspeisevergütung für Neuanlagen fortgeführt", p: 0.5, apply: multiply}
  payout_delay:          {dist: pert, label: "Auszahlungsverzug Zuschuss nach Zusage (Monate)", min: 0, mode: 0, max: 6}   # Voreinstellung im Basisfall 0 (Spec 00 §9.11 Nr. 7)
  repayment_grant_cut:   {dist: discrete, label: "Kürzung bzw. Rückforderung Tilgungszuschuss (Anteil)", values: [0.0, 0.5, 1.0], probs: [0.95, 0.04, 0.01]}   # D; Basiswert 0 (Konzept B12)
notes: "Ziele: availability_post2030 -> funding.<id>.approved eines Instruments ohne Entscheidungsknoten (sonst übernimmt der automatische Schlüssel mit Rolle decision); payout_delay -> funding.<id>.payout_delay_months; repayment_grant_cut -> funding.<id>.repayment_grant.cut_share (01b 4.2; über den Expander auf financing.f_<id>_loan). Prüfwerte: PERT(0; 0; 6) (α = 1, β = 5) Mittel 1,0, q90 2,214256; discrete(0; 0,5; 1) Mittel 0,03, q95 = 0 (Q(0,95) = 0), q96 = 0,5."
```

```yaml
# inst/extdata/library/processes/valuation_risks_2026.yaml
id: processes/valuation_risks_2026
block: processes
schema_version: 1
label: "Restwert- und Leerstandsrisiken"
source:
  document: "Memo 04 §1.2 (Exit-Rendite y0 + 0,5 (r_T - r0) + eps, sd 0,4 Pp; Leerstand PERT(0; 2 %; 8 %)); Memo 07 §4.0 (Liegenschaftszins ± 0,5 Pp, RND ± 5 J.); Konzept §4.2"
  url: "docs/recherche/04_monte_carlo.md"
  publisher: "eigene Ableitung"
as_of: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
values:
  cap_rate_shock:       {dist: truncnorm, label: "Zuschlag Liegenschaftszins (absolut)", mean: 0.0, sd: 0.005, lower: -0.015, upper: 0.015, apply: add}
  remaining_life_shock: {dist: triangular, label: "Abweichung Restnutzungsdauer (Jahre)", min: -5, mode: 0, max: 5, apply: add}
  vacancy_level:        {dist: pert, label: "Leerstandsquote (Niveau)", min: 0.0, mode: 0.02, max: 0.08}
  vacancy_fluctuation:  {type: iid, label: "jährliche Leerstandsschwankung (Faktor)", dist_spec: {dist: pert, min: 0.5, mode: 1.0, max: 2.0}}
  market_value_uplift_efficiency: {dist: pert, label: "Effizienzaufschlag Marktwert Selbstnutzer", min: 0.0, mode: 0.03, max: 0.08}
notes: "cap_rate_shock zusätzlich zur strukturellen Kopplung K7; vacancy_fluctuation ist ein Prozess (Ziel market.vacancy_fluctuation, Basis 1)."
```

### 2.8 Prüfwerte der Bibliotheksdefaults (WS-C `test-process-*.R`, WS-L `test-library.R`)

1. **Vasicek (r0 = 0,040):** Werte nach 1.6.3; Quantile der Ausgabe in y = 11 (2037 bei Start 2027): q05 0,01584159,
   q50 0,03825299, q95 0,06066439; y = 21: 0,01432090 / 0,03772679 / 0,06113269; y = 31: 0,01407428 / 0,03756831 /
   0,06106234.
2. **Inflation:** Werte nach 1.6.1; Simulation (n = 200.000, Pseudo, Seed 1): mittlere Inflation y = 2…31: Mittel
   0,02027, sd 0,00550; Preisniveau y = 31 relativ zu y = 1: Mittel 1,8449, q05 1,3956, q95 2,3739 (Plausibilität, keine
   exakte Sollgröße).
3. **Gekoppelte Prozesse:** 1.6.2. **Energie:** 1.6.4. **CO2:** Erwartungspfad 2.5 (notes); Szenario 10 und 11
   umschließen den Median des exakten Dreiecks (2030: Median 83,17 zwischen q10 82,13 und q11 84,23).
4. **Bibliotheksintegrität:** Jede Datei in `processes/` lässt sich als Overlay-Eintrag mit einem passenden Ziel
   validieren (`vofi_validate()` ohne Fehler); `use:`-Unterpfade existieren; `fallback` deckt jedes Token `base` ab.

---

## 3. Parameterbibliothek: Eintragsschema und vollständige v1-Einträge (`inst/extdata/library/**`, WS-L)

### 3.1 Eintragsschema (Konkretisierung von Spec 00 §4.9, R-12, R-13)

Ein Eintrag je Datei; `id` = Pfad relativ zur Bibliothekswurzel ohne `.yaml`. Schlüssel der obersten Ebene außer den
hier genannten sind ein Validierungsfehler.

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle |
|---|---|---|---|---|---|---|---|
| `id` | chr | – | – | ja | E: gleich Dateipfad; Segmente `^[a-z][a-z0-9_]*$` | Kennung | Spec 00 §4.9 |
| `block` | enum:`funding`,`financing`,`market`,`processes`,`components`,`legal`,`costs`,`valuation` | – | – | ja | E: passt zum Ordner (`prices/` → `market`) | Zielblock | Spec 00 §4.9 |
| `topic` | chr | – | `null` | bedingt | E: Pflicht für `legal/*` mit automatischer Auswahl; Themen nach 3.5 | Thema der automatischen Rechtsstandsauswahl | Spec 00 §4.10 |
| `schema_version` | int | – | `1` | ja | E: 1 | Schemaversion | Spec 00 §4.9 |
| `label` | chr (de) | – | – | ja | – | **Titel** des Eintrags (ein Feld `title` gibt es nicht) | Spec 00 §4.9 |
| `description` | chr (de) | – | `null` | nein | – | Erläuterung | – |
| `source` | Map | – | – | ja | E: `document` und `publisher` nicht leer | Hauptquelle: `document`, `url`, `publisher`, optional `section`, `date` | R-12 |
| `references` | list of Map | – | `[]` | nein | wie `source` | weitere Quellen | – |
| `as_of` | date | – | – | ja | W: älter als 6 Monate (Prozess-/Kalibrierungseinträge 12 Monate) vor `legal_state` → `vofi_warning_library_outdated` | Stand des Eintrags | D10, Spec 00 §4.9 |
| `accessed` | date | – | `null` | nein | – | Abrufdatum der Quelle | R-12 |
| `valid_from` | date | – | – | ja | E: Datum | Beginn der Gültigkeit (bei `funding`: Antragsdatum) | Spec 00 §4.9 |
| `valid_to` | date \| null | – | – | ja | E: > `valid_from` | Ende der Gültigkeit, **exklusiv** (Intervall [valid_from, valid_to)); „gültig bis 31.12.2026“ ⇒ `valid_to: 2027-01-01` | Spec 00 §4.9 |
| `quality` | enum:`A`,`B`,`C`,`D` | – | – | ja | – | Qualitätsstufe des Eintrags | R-54 |
| `quality_detail` | Map Unterpfad → `A`–`D` | – | `{}` | nein | E: Unterpfad existiert in `values` | abweichende Stufe einzelner Werte; Herkunft eines Blatts = längster passender Unterpfad, sonst `quality` (**S01C-08**) | Konzept §6.4 |
| `legal_state` | Map | – | `null` | bedingt | E: Pflicht für `legal/*` und `funding/*` | Rechtsstand der Quelle: `as_of` (Fassung), `status`, `reference` (Fundstelle) (**S01C-08**) | Konzept §5.4, F5 |
| `legal_state.status` | enum:`in_force`,`enacted`,`adopted_pending`,`pending`,`administrative`,`derived`,`market` | – | – | bedingt | E: `pending` ⇒ `reform` gesetzt; E: `reform` gesetzt ⇒ Status `pending` oder `derived` | geltend / verkündet, künftig wirksam / beschlossen, Zustimmung oder Verkündung ausstehend / anhängig (Reformschalter) / Richtlinie, Merkblatt / eigene Ableitung / Marktdaten | Konzept F5 |
| `reform` | chr (enum:reform) | – | `null` | bedingt | E: Code in `enums.yaml` (`mietrecht_ii`, `stufe_2045`, `unreleased`); E: Pflicht bei `legal/*` mit `quality: D` (nie automatisch, R-80) | Eintrag nur aktiv mit `project.pending_reforms`; hat dann Vorrang vor dem Eintrag ohne Reform (Spec 00 §4.10) | Spec 00 §4.10, R-82 |
| `release` | Map `{status: released \| pending, by: chr, date: date}` | – | `null` | bedingt | E: Pflicht bei `legal/*` mit `quality: C`; W: `status: released` ohne `by`/`date` | **Freigabe** von C-Einträgen: automatisch wählbar nur mit `released`; sonst nur mit Sammelcode `unreleased` in `pending_reforms` (Ergebnisvermerk); ohne wählbaren Eintrag ist das Thema inaktiv | Spec 00 §4.9–4.10, Konzept 6.5, R-80 |
| `uncertainty` | Map Unterpfad → Overlay-Vorlage (1.3) | – | `null` | nein | E: gültige Verteilungsangabe | Vorschlag für Overlay-Einträge (z. B. Nutzungsdauern) | R-12 |
| `from` | chr | – | `null` | nein | E: Eintrag existiert, kein Zyklus | Kette (Nutzlast des Ziels wird unter `values` gemischt) | Spec 00 §4.9 |
| `fallback` | Map | – | `null` | nein | E: deckt jedes Token `base` ab | numerische Ersatzwerte für Tokens (1.5.1, **S01C-02**); wird nie gemischt | – |
| `notes` | chr (de) | – | `null` | nein | – | Hinweise, offene Prüfpunkte | – |
| `values` | beliebig | – | – | ja | E: Wertformen bzw. Felder des Zielblocks | Nutzlast; an der Fundstelle `{from, use, …lokal}` unter die lokale Angabe gemischt | Spec 00 §4.9 |

**Bibliotheksstand (R-80):** `inst/extdata/library/VERSION` enthält eine Zeile `JJJJ.MM.n`; Stand dieses Katalogs
**`2026.10.1`** (Stichtag der Werte 2026-10-25). Jede inhaltliche Änderung eines Eintrags erhöht n, ein neuer
Monatsstand setzt n = 1; der Wert erscheint in `meta$library_version` jedes Ergebnisses (Spec 00 §4.9, §13.1).
WS-L prüft in `test-library.R`: Format der Datei, jede Datei hat die Pflichtfelder dieser Tabelle, `legal/*` der
Qualität C trägt `release`, `legal/*` der Qualität D trägt `reform`.

### 3.2 Qualitätskennzeichnung und ungeprüfte Werte

(1) „Sek.“-Werte (nur Sekundärquelle) tragen mindestens C, eigene Ableitungen D.
(2) Die Herkunft (Spec 00 §4.8) übernimmt je Blatt die Stufe aus `quality_detail`/`quality`. (3) Annahmenprotokoll
(Bericht, Excel-Blatt „Annahmen“) hebt C/D hervor. (4) Werte, die vor Freigabe am Primärtext zu prüfen sind (Konzept
§10.2), stehen zusätzlich in `notes` unter „Prüfpunkte:“. (5) In den YAML-Listings dieses Abschnitts markiert
`# C` / `# D` ein Blatt, das von der Eintragsstufe abweicht.

### 3.3 Verzeichnis der v1-Einträge

| id | block | topic / reform | gültig | Qualität | Inhalt |
|---|---|---|---|---|---|
| `funding/kfw_261_wg_kredit_2026` | funding | – | ab 2026-07-21 | B (TZ-Wirkung C) | BEG WG Kredit 261: gemeinsame Kreditkonditionen, Baubegleitung |
| `funding/kfw_261_eh40`, `_eh55`, `_eh70`, `_eh85`, `_denkmal` | funding | – | ab 2026-07-21 | B | Tilgungszuschüsse je EH-Stufe (Kette auf `kfw_261_wg_kredit_2026`) |
| `funding/kfw_458_heizung_privat` | funding | – | ab 2026-07-21 | C | Heizungsförderung Privatpersonen inkl. Degression |
| `funding/kfw_459_heizung_unternehmen` | funding | – | ab 2026-07-21 | C (Staffel D) | Heizungsförderung Unternehmen/Genossenschaften |
| `funding/kfw_358_ergaenzungskredit_plus`, `funding/kfw_359_ergaenzungskredit` | funding | – | ab 2026-09-24 | A (Konditionen) / B | Ergänzungskredite BEG EM |
| `funding/kfw_297_khn_selbstnutzung`, `funding/kfw_298_khn_vermietung` | funding | – | ab 2026-09-17 | A/B | Klimafreundlicher Neubau Standard (EH 40, EH 40 + QNG) |
| `funding/kfw_297_khn_eh55_stufe`, `funding/kfw_298_khn_eh55_stufe` | funding | – | 2026-04-10 bis 2027-01-01 | A/B | KFN EH-55-Stufe (befristet, Budgetvorbehalt) |
| `funding/kfw_300_wohneigentum_familien` | funding | – | ab 2026-07-21 | A/B | Wohneigentum für Familien (Neubau) |
| `funding/kfw_308_jung_kauft_alt` | funding | – | ab 2026-07-21 | C | Wohneigentum für Familien – Bestandserwerb |
| `funding/bafa_beg_em_huelle` | funding | – | ab 2026-07-21 | C | BEG EM Gebäudehülle inkl. iSFP-Bonus |
| `funding/bafa_beg_em_fachplanung` | funding | – | ab 2026-07-21 | C | Fachplanung/Baubegleitung 50 % |
| `funding/estg_35c` | funding | – | bis 2030-01-01 | B | Steuerermäßigung § 35c EStG (`instrument_type: tax_credit`, R-11) |
| `legal/mietrecht_2026` | legal | `mietrecht` | ab 2026-07-29 | A | §§ 536, 556d–556g, 557a, 557b, 558, 559, 559a, 559c, 559e BGB, Auslegungsparameter |
| `legal/mietrecht_559f_2026` | legal | `mietrecht_559f` | ab 2026-07-29 | C (`release: pending`) | § 559f BGB: JAZ-Schwelle, Halbierung, Ausnahmen (01b 7.4) |
| `legal/mietrecht_ii_reform` | legal | `mietrecht` / `mietrecht_ii` | ab 2026-07-01 | B | Mietrecht II (BT-Drs. 21/6807, anhängig) |
| `legal/co2kostaufg_2026` | legal | `co2kostaufg` | ab 2026-07-29 | B (§§ 5b, 5d C) | Stufenmodell, § 5a, § 9 |
| `legal/gmodg_bio_treppe_2026` | legal | `bio_treppe` | ab 2026-07-29 | B | Bio-Treppe § 43 Abs. 1 GModG |
| `legal/gmodg_bio_treppe_2045` | legal | `bio_treppe` / `stufe_2045` | ab 2026-07-29 | D | Bio-Treppe mit abgeleiteter 2045-Stufe (Schalter, Pflichtsensitivität) |
| `legal/behg_ets2_2026` | legal | `co2_pricing` | ab 2026-01-01 | B (2027 C) | BEHG-Preise, Korridore 2026/2027, ETS 2 ab 2028, Preisstabilitätsmechanismus |
| `legal/emission_factors_geg_anlage9` | legal | `emission_factors_geg` | 2023-01-01 bis 2027-01-01 | A | Emissionsfaktoren GEG/GModG Anlage 9 |
| `legal/emission_factors_co2cost_2026` | legal | `emission_factors_co2cost` | ab 2021-01-01 | A | Emissionsfaktoren BEHG/EBeV 2030 Anlage 2, Umrechnungen |
| `legal/grunderwerbsteuer_2026` | legal | `grunderwerbsteuer` | ab 2025-07-01 | C (`release: pending`; bis zur Freigabe nur mit `unreleased`) | Steuersätze je Land, Freigrenze |
| `legal/umsatzsteuer_2026` | legal | `umsatzsteuer` | ab 2023-01-01 | A | Steuersätze, PV-Nullsatz, Wohnraumvermietung |
| `prices/energy_prices_2026` | market | – | ab 2026-01-01 | B (WP-Strom D, Öl/Pellets C) | Energiepreise 2026 (12-Monats-Mittel), Komponenten, Normalpreise, Grundpreise |
| `prices/co2_price_paths_2026` | market | – | ab 2026-01-01 | D (hoch: A) | CO2-Korridore niedrig/mittel/hoch |
| `prices/co2_price_path_referenzszenarien_2026` | market | – | ab 2026-01-01 | D | CO2-Pfad der Referenzszenarien (Memo 07 §4.0) mit unsicheren Stützstellen |
| `prices/interest_rates_2026_10` | market | – | ab 2026-08-01 | A | Zinsniveaus Okt. 2026, KfW-Konditionen 22.10.2026 |
| `prices/macro_paths_2026` | market | – | ab 2026-01-01 | B | Inflation, Baupreise, Instandhaltung, Mieten, Bodenwert, Betriebskosten (deterministische Defaults) |
| `prices/eeg_feed_in_2026` | market | – | 2026-08-01 bis 2027-02-01 | C | EEG-Einspeisevergütung |
| `prices/referenzszenarien_2026` | market | – | ab 2026-01-01 | D | Markt- und Preisannahmen der Referenzszenarien S1–S5 (Memo 07 §4.0, netto umgerechnet; 5.0) |
| `costs/bewirtschaftung_ii_bv_2026` | costs | – | 2026-01-01 bis 2029-01-01 | B (Sek.-Bestätigung C) | II. BV §§ 26, 28, 29 |
| `costs/bewirtschaftung_immowertv_2026` | costs | – | 2026-01-01 bis 2027-01-01 | B | ImmoWertV Anlage 3 (Modellansätze 2026) |
| `costs/betriebskosten_benchmarks_2026` | costs | – | ab 2026-01-01 | C/D | Betriebskosten, nicht umlagefähige Kosten |
| `costs/baukosten_neubau_2026` | costs | – | ab 2026-01-01 | B/D | Kostenkennwerte Neubau |
| `costs/kostenzuschlaege_2026` | costs | – | ab 2026-01-01 | D | Baunebenkosten KG 700, Unvorhergesehenes |
| `costs/kostenfunktionen_sanierung_iwu_2026` | costs | – | ab 2026-01-01 | B (Faktor 1,12 D) | IWU-Kostenfunktionen × 1,12, Ohnehin-Anteile |
| `costs/anlagentechnik_marktpreise_2026` | costs | – | ab 2026-01-01 | C/D | WP, PV, Speicher, Erdsonde |
| `costs/sanierung_eh_pakete_2026` | costs | – | ab 2026-01-01 | D | Top-down-Kosten Komplettsanierung (Plausibilität) |
| `costs/nutzungsdauern_2026` | costs | – | ab 2026-01-01 | C/D | Nutzungsdauern Bauteile/Anlagen mit Verteilungen |
| `costs/wartung_instandsetzung_vdi2067_2026` | costs | – | ab 2026-01-01 | D | Wartung/Instandsetzung in % der Investition |
| `costs/erwerbsnebenkosten_2026` | costs | – | ab 2026-01-01 | C/D | Notar, Grundbuch, Makler, Due Diligence |
| `valuation/liegenschaftszinsen_2026` | valuation | – | ab 2026-01-01 | D (Referenzen B/C) | Liegenschaftszinssätze (Lage-Presets) |
| `valuation/immowertv_anlage1_2_2026` | valuation | – | ab 2022-01-01 | B (Zwischenzeilen D) | Gesamtnutzungsdauer, Restnutzungsdauer bei Modernisierung |
| `valuation/verkaufskosten_2026` | valuation | – | ab 2026-01-01 | D | Verkaufskosten am Horizont |
| `valuation/kaufpreisfaktoren_2026` | valuation | – | ab 2026-01-01 | D | Rohertragsvervielfältiger |
| `processes/*` (Abschnitt 2) | processes | – | ab 2026-01-01 | D | Stochastik-Defaults |

### 3.4 Förderung (`funding/**`)

Die Felder der Nutzlast folgen dem Datenmodell Memo 02 §5.8 (Spec 00 §4.3.7); ihre Auswertung (Bemessung, Satzbausteine,
Bedingungen, Degression, Kumulierung, mietrechtliche Wirkung) regelt **Teil B** (# 01b). Bedingungen stehen als
Ausdrücke in der Grammatik von Spec 00 §4.5 Regel 5 bzw. als Codes, die Teil B auswertet. Zinssätze sind nominale
Sollzinsen p. a. (Effektivzins informativ). `approval_probability` speist den automatischen Bernoulli-Schlüssel
(Spec 00 §11.6 Nr. 4; Konzept §4.2: p(Zusage) 0,8–0,95, Werte D).

```yaml
# inst/extdata/library/funding/kfw_261_wg_kredit_2026.yaml
id: funding/kfw_261_wg_kredit_2026
block: funding
schema_version: 1
label: "BEG WG Kredit 261 – Sanierung zum Effizienzhaus (gemeinsame Konditionen)"
source: {document: "KfW-Merkblatt 261/262, Richtlinie BEG WG (BAnz 02.09.2026); Konditionenanzeiger 22.10.2026", url: "https://www.kfw.de/inlandsfoerderung/Privatpersonen/Bestehende-Immobilie/F%C3%B6rderprodukte/Bundesf%C3%B6rderung-f%C3%BCr-effiziente-Geb%C3%A4ude-Wohngeb%C3%A4ude-Kredit-(261-262)/", publisher: "KfW"}
references:
  - {document: "KfW-Konditionenanzeiger", url: "https://www.kfw-formularsammlung.de/KonditionenanzeigerINet/KonditionenAnzeiger", publisher: KfW, date: 2026-10-22}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-07-21
valid_to: null
quality: B
quality_detail: {repayment_grant.effect: C, loan.payments_per_year: D, eligibility.conditions.wpb_definition: C, budget_risk: D}
legal_state: {as_of: 2026-09-02, status: administrative, reference: "Richtlinie BEG WG, BAnz AT 02.09.2026; Konditionen seit 21.07.2026, Zinsen gültig ab 29.09.2026"}
values:
  instrument_type: loan_with_repayment_grant
  provider: KfW
  program_code: "261"
  application_before_start: true            # Antrag vor Vorhabenbeginn (Entscheidungsknoten, Konzept §3.9)
  budget_risk: {approval_probability: 0.95}
  eligibility:
    applicants: [privatperson, weg, unternehmen, kommunales_unternehmen, genossenschaft, gemeinnuetzig, koerperschaft]
    project_types: [sanierung_eh, sanierung_stufenweise, erwerb_sanierung]
    conditions:
      ee_or_nh_class: required              # EE-Klasse (>= 65 % EE-Wärme) oder NH-Klasse ist seit 21.07.2026 Pflicht
      wpb_definition: "Energieausweis Klasse H oder Baujahr <= 1957 und >= 75 % Außenwand unsaniert"   # C, Auslegung 17.07.2026 prüfen
  basis:
    loan_cap_per_unit_eur: 150000
    eligible_cost_kg: [300, 400, 700]
  loan:
    max_share_of_eligible_costs: 1.0
    repayment: annuity
    payments_per_year: 12                   # D: im Merkblatt prüfen (Memo 02 §5.8)
    variants:
      v10_2_10: {term_years: 10, grace_years: 2, fixed_years: 10, rate_pa: 0.0301, effective_rate_pa: 0.0305, rate_date: 2026-09-29}
      v20_3_10: {term_years: 20, grace_years: 3, fixed_years: 10, rate_pa: 0.0353, effective_rate_pa: 0.0359, rate_date: 2026-09-29}
      v30_5_10: {term_years: 30, grace_years: 5, fixed_years: 10, rate_pa: 0.0365, effective_rate_pa: 0.0371, rate_date: 2026-09-29}
      b10_10_10: {repayment: bullet, term_years: 10, grace_years: 10, fixed_years: 10, rate_pa: 0.0371, effective_rate_pa: 0.0377, rate_date: 2026-09-29}
    default_variant: v30_5_10
    term_ranges: {annuity: [{term: [4, 10], grace: [1, 2]}, {term: [11, 20], grace: [1, 3]}, {term: [21, 30], grace: [1, 5]}], bullet: {term: [4, 10]}}
    fees: {processing_fee_share: 0.0, commitment_fee_rate_month: 0.0015, commitment_free_months: 12, commitment_extension_max_months: 36}
    prepay_allowed: false                   # nur Gesamtrückzahlung mit Vorfälligkeitsentschädigung
    followup: market                        # Anschlusszins aus market.mortgage_rate
  repayment_grant:
    cap_per_unit_basis_eur: 150000          # TZ-Bemessung je WE höchstens auf 150.000 EUR
    max_total_share: 0.40                   # EH 40 NH + WPB + SerSan
    payout: {event: completion_proof, lag_months: 6}
    effect: shorten_term                    # Default Laufzeitverkürzung (C, Stand 2024); reduce_installment auf Antrag
  construction_supervision:                 # Baubegleitung: Zusatzkredit mit 50 % Tilgungszuschuss
    repayment_grant_share: 0.50
    cap_efh_eur: 10000
    cap_mfh_per_unit_eur: 4000
    cap_mfh_total_eur: 40000
  rent_law:
    grant_counts_as: zuschuss_559a_abs1     # Tilgungszuschuss wie Zuschuss
    loan_counts_as: zinsverbilligung_559a_abs2
  cumulation: {exclusive_with: [funding/estg_35c]}
notes: "Prüfpunkte: Wirkung des Tilgungszuschusses (Laufzeitverkürzung) und Zahlungsfrequenz im Merkblatt; WPB-Definition nach Auslegung vom 17.07.2026."
```

```yaml
# inst/extdata/library/funding/kfw_261_eh70.yaml   (eh40, eh55, eh85, denkmal analog; Werte in der Tabelle unten)
id: funding/kfw_261_eh70
block: funding
schema_version: 1
label: "BEG WG Kredit 261 – Effizienzhaus 70"
from: funding/kfw_261_wg_kredit_2026
source: {document: "KfW-Merkblatt 261, Tilgungszuschüsse seit 21.07.2026", url: "https://www.kfw.de/261", publisher: KfW}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-07-21
valid_to: null
quality: B
quality_detail: {repayment_grant.bonuses: C}
legal_state: {as_of: 2026-09-02, status: administrative, reference: "Richtlinie BEG WG, BAnz AT 02.09.2026"}
values:
  eligibility: {conditions: {efficiency_standard: eh70}}
  repayment_grant:
    base_rates: {ee: 0.00, nh: 0.05}
    bonuses:
      wpb:    {rate: 0.10, condition: "building.wpb_flag"}
      sersan: {rate: 0.05, condition: "funding.this.serial_renovation"}   # 01b: Bedingungssymbole
```

| id | `efficiency_standard` | `base_rates` (ee / nh) | Bonus WPB | Bonus SerSan | Höchstsatz (Prüfwert) |
|---|---|---|---:|---:|---|
| `funding/kfw_261_eh40` | `eh40` | 0,10 / 0,15 | 0,10 | 0,15 | 0,40 (NH + WPB + SerSan) |
| `funding/kfw_261_eh55` | `eh55` | 0,05 / 0,10 | 0,10 | 0,15 | 0,35 |
| `funding/kfw_261_eh70` | `eh70` | 0,00 / 0,05 | 0,10 | 0,05 | 0,20 |
| `funding/kfw_261_eh85` | `eh85` | 0,00 / 0,05 | – | – | 0,05 |
| `funding/kfw_261_denkmal` | `eh_denkmal` | 0,05 / 0,10 | – | – | 0,10 |

**Prüffälle (Teil B wertet aus, WS-E2 testet):** (k1) S1: EH 70 EE + WPB, Kredit investiv 1.264.000 € + Baubegleitung
36.000 € → TZ = 0,10 · 1.264.000 + 0,50 · 36.000 = 144.400,00 € (S1-T3). (k2) Rechenbeispiel 5 Memo 02: 150.000 € 30/5/10,
3,65 %, TZ 10 % → Annuität ab Jahr 6 ohne TZ 9.249,88 €/a, mit Neuberechnung 8.324,90 €/a (jährlich vereinfacht).

```yaml
# inst/extdata/library/funding/kfw_458_heizung_privat.yaml
id: funding/kfw_458_heizung_privat
block: funding
schema_version: 1
label: "BEG EM Heizungsförderung für Privatpersonen (KfW 458)"
source: {document: "KfW-Merkblatt 458, Richtlinie BEG EM (BAnz 27.08.2026); Konditionen seit 21.07.2026", url: "https://www.kfw.de/458", publisher: KfW}
references:
  - {document: "Sekundärquellen zu Bonusbausteinen und Degression (greenox, DUH-Factsheet)", url: "https://greenox-group.de/warmepumpe/", publisher: "div.", date: 2026-07}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-07-21
valid_to: null
quality: C                                  # Einzelheiten Sek. (Konzept §10.2)
quality_detail: {rate_components.grund: B, budget_risk: D}
legal_state: {as_of: 2026-08-27, status: administrative, reference: "Richtlinie BEG EM, BAnz AT 27.08.2026"}
values:
  instrument_type: grant
  provider: KfW
  program_code: "458"
  application_before_start: true
  budget_risk: {approval_probability: 0.90}
  eligibility:
    applicants: [privatperson, weg]
    measure_types: [heizung_tausch]
    exclusions: ["dezentrale Heizung bei verbindlicher Fernwärme-Anschlusszusage innerhalb von 3 Jahren"]
  basis:
    eligible_cost_caps_per_building:        # Staffel nach Zahl der WE, gleichmäßige Verteilung
      - {units_from: 1, units_to: 1, cap_eur: 28000}
      - {units_from: 2, units_to: 6, cap_eur: 15000}
      - {units_from: 7, units_to: .inf, cap_eur: 8000}
    distribution: equal_per_unit
  rate_components:
    grund: {rate: 0.30}
    klimageschwindigkeit:
      rate: 0.16
      condition: "unit.owner_occupied & heating.replaced_fossil_functional"   # Öl, Kohle, Nachtspeicher, Gasetage; Gas/Biomasse >= 20 Jahre
      min_age_gas_biomass_years: 20
    einkommen:
      condition: "unit.owner_occupied"
      schedule_by_taxable_income: {thresholds_eur: [30000, 40000, 50000], rates: [0.40, 0.30, 0.10, 0.00], child_u18_threshold_shift_eur: 10000}
      income_basis: "Durchschnitt zvE 2. und 3. Kalenderjahr vor Antrag"
  rate_cap:
    default: 0.70
    exceptions: [{condition: "unit.owner_occupied & taxable_income_adj <= 30000", cap: 0.80}]
  degression:                               # Antragsdatum maßgeblich; Halbjahresschritte
    - {target: rate_components.klimageschwindigkeit.rate, start: 2027-02-01, step: -0.04, every_months: 6, floor: 0.0}
    - {target: "basis.eligible_cost_caps_per_building[1].cap_eur", start: 2027-02-01, step: -750, every_months: 6, floor: 22000}
  payout: {event: completion_proof, lag_months: 3}
  rent_law: {grant_counts_as: zuschuss_559a_abs1, enables: [bgb_559e]}
  cumulation: {exclusive_with: [funding/estg_35c], combinable_with: [funding/kfw_358_ergaenzungskredit_plus, funding/kfw_359_ergaenzungskredit]}
notes: "Angekündigt für Q1/2027 (nicht enthalten): WP-Grundförderung 15 % + 15 % Wertschöpfungsbonus für EU-Geräte (Parameter heat_pump_origin_eu, # 01b). Prüfpunkte: Bonusbedingungen, Deckel 80 %, Degressionsende der 1.-WE-Höchstkosten."
```

**Degressionstabelle (Prüfwerte, abgeleitet aus `degression`):**

| Antragsdatum ab | Klimageschwindigkeitsbonus | förderfähig 1. WE |
|---|---:|---:|
| 2026-07-21 | 0,16 | 28.000 |
| 2027-02-01 | 0,12 | 27.250 |
| 2027-08-01 | 0,08 | 26.500 |
| 2028-02-01 | 0,04 | 25.750 |
| 2028-08-01 | 0,00 | 25.000 |
| 2029-02-01 | 0,00 | 24.250 |
| 2029-08-01 | 0,00 | 23.500 |
| 2030-02-01 | 0,00 | 22.750 |
| 2030-08-01 (und später) | 0,00 | 22.000 |

Prüffälle (Memo 02 Rechenbeispiel 6, Memo 07 S4): WP 32.000 €, zvE 45.000 € ohne Kind: Antrag bis 31.01.2027 →
56 % × 28.000 = 15.680,00 €; ab 01.02.2027 → 52 % × 27.250 = 14.170,00 €; ab 01.08.2028 → 40 % × 25.000 = 10.000,00 €.
S4: zvE 58.000 € − 10.000 € (Kind) = 48.000 € → Einkommensbonus 0,10 (S4-T1); Kessel Bj. 2008 (18 J.) → kein
Klimageschwindigkeitsbonus → 40 % × 28.000 = 11.200,00 € (S4-T8).

```yaml
# inst/extdata/library/funding/kfw_459_heizung_unternehmen.yaml
id: funding/kfw_459_heizung_unternehmen
block: funding
schema_version: 1
label: "BEG EM Heizungsförderung für Unternehmen – Wohngebäude (KfW 459)"
from: funding/kfw_458_heizung_privat
source: {document: "KfW-Merkblatt 459 (Konditionen seit 21.07.2026)", url: "https://www.kfw.de/459", publisher: KfW}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-07-21
valid_to: null
quality: C
quality_detail: {basis.eligible_cost_caps_per_building: D}   # Staffel analog 458 angenommen (Konzept B2)
legal_state: {as_of: 2026-08-27, status: administrative, reference: "Richtlinie BEG EM, BAnz AT 27.08.2026"}
values:
  program_code: "459"
  eligibility:
    applicants: [unternehmen, kommunales_unternehmen, genossenschaft, contractor, gemeinnuetzig]
  rate_components:
    klimageschwindigkeit: ~                 # entfällt (nur Selbstnutzer)
    einkommen: ~
  rate_cap: {default: 0.30, exceptions: []}
  budget_risk: {approval_probability: 0.90}
notes: "Beispiel KfW: 10 WE -> 135.000 EUR förderfähig -> max. 40.500 EUR. Prüffall S3 (12 WE): 28.000 + 5 x 15.000 + 6 x 8.000 = 151.000 EUR; Zuschuss 0,30 x min(153.560; 151.000) = 45.300,00 EUR (S3-T1, S3-T2)."
```

```yaml
# inst/extdata/library/funding/kfw_358_ergaenzungskredit_plus.yaml   (359 analog, Werte unten)
id: funding/kfw_358_ergaenzungskredit_plus
block: funding
schema_version: 1
label: "BEG EM Ergänzungskredit Plus (KfW 358, einkommensabhängig)"
source: {document: "KfW-Merkblatt 358/359 09/2026 (gültig ab 24.09.2026); Konditionenanzeiger 22.10.2026", url: "https://www.kfw.de/358-359", publisher: KfW}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-09-24
valid_to: null
quality: B
quality_detail: {loan.variants: A, budget_risk: D}
legal_state: {as_of: 2026-09-24, status: administrative, reference: "Merkblatt 358/359, Stand 09/2026"}
values:
  instrument_type: loan
  provider: KfW
  program_code: "358"
  application_before_start: false
  budget_risk: {approval_probability: 0.95}
  eligibility:
    applicants: [privatperson]
    conditions:
      owner_occupied: required
      taxable_income_max_eur: 90000          # Durchschnitt zvE 2. und 3. Jahr vor Antrag
      requires_beg_em_commitment_months: 12  # BEG-EM-Zusage höchstens 12 Monate alt
  basis:
    loan_cap_per_unit_eur: 120000
    max_share_of_eligible_costs: 1.0         # praktisch Kosten minus Zuschuss
  loan:
    repayment: annuity
    payments_per_year: 12                    # D
    variants:
      v5_1_5:   {term_years: 5, grace_years: 1, fixed_years: 5, rate_pa: 0.0001, rate_date: 2026-10-22}
      v10_2_10: {term_years: 10, grace_years: 2, fixed_years: 10, rate_pa: 0.0148, effective_rate_pa: 0.0149, rate_date: 2026-10-22}
      v25_3_10: {term_years: 25, grace_years: 3, fixed_years: 10, rate_pa: 0.0253, effective_rate_pa: 0.0256, rate_date: 2026-10-22}
      v35_5_10: {term_years: 35, grace_years: 5, fixed_years: 10, rate_pa: 0.0268, effective_rate_pa: 0.0271, rate_date: 2026-10-22}
    default_variant: v25_3_10
    prepay_allowed: false
    followup: market
  rent_law: {loan_counts_as: zinsverbilligung_559a_abs2}
  cumulation: {requires: [funding/kfw_458_heizung_privat, funding/bafa_beg_em_huelle]}
```

| id | Antragsberechtigt | Einkommensgrenze | Varianten (rate_pa; Effektivzins) |
|---|---|---|---|
| `funding/kfw_358_ergaenzungskredit_plus` | natürliche Personen, selbstgenutztes EFH/ETW | zvE ≤ 90.000 € | 5/1/5: 0,0001; 10/2/10: 0,0148 (0,0149); 25/3/10: 0,0253 (0,0256); 35/5/10: 0,0268 (0,0271) |
| `funding/kfw_359_ergaenzungskredit` | alle übrigen (Unternehmen, WEG, Vermieter) | – | 10/2/10: 0,0453 (0,0463); 25/3/10: 0,0462 (0,0472); 35/5/10: 0,0463 (0,0473) |

Prüffall S4-T7: 358, 70.000 €, 25/3/10, 2,53 %, Jahresraster, `payments_per_year: 1` → Zinsen 2030–2032 1.771,00 €/a,
Annuität 22 J. 4.188,12 €/a; 45.000 € (2033) → 1.138,50 €/a bzw. 2.692,36 €/a.

```yaml
# inst/extdata/library/funding/kfw_298_khn_vermietung.yaml   (297 analog: applicants [privatperson], owner_occupied)
id: funding/kfw_298_khn_vermietung
block: funding
schema_version: 1
label: "Klimafreundlicher Neubau Wohngebäude (KfW 298, Vermietung/Unternehmen) – Standard"
source: {document: "KfW-Merkblatt 297/298; Konditionen Standard ab 17.09.2026", url: "https://www.kfw.de/297-298", publisher: KfW}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-09-17
valid_to: null
quality: B
quality_detail: {loan.variants: A, budget_risk: D}
legal_state: {as_of: 2026-09-17, status: administrative, reference: "Programm KFN, Merkblatt 297/298"}
values:
  instrument_type: loan
  provider: KfW
  program_code: "298"
  application_before_start: true
  budget_risk: {approval_probability: 0.90}
  eligibility:
    applicants: [unternehmen, kommunales_unternehmen, genossenschaft, privatperson_vermieter]
    project_types: [neubau, erwerb_neubau]
    conditions: {efficiency_standard: eh40, lca_qng_plus_thg: required, fossil_or_biomass_heating: excluded}
  basis:
    loan_cap_per_unit_eur: 100000
    loan_cap_per_unit_qng_eur: 150000        # mit QNG-Zertifikat (PLUS/PREMIUM)
  loan:
    repayment: annuity
    payments_per_year: 12                    # D
    variants:
      v10_2_10: {term_years: 10, grace_years: 2, fixed_years: 10, rate_pa: 0.0194, effective_rate_pa: 0.0196, rate_date: 2026-10-22}
      v25_3_10: {term_years: 25, grace_years: 3, fixed_years: 10, rate_pa: 0.0281, effective_rate_pa: 0.0285, rate_date: 2026-10-22}
      v35_5_10: {term_years: 35, grace_years: 5, fixed_years: 10, rate_pa: 0.0294, effective_rate_pa: 0.0298, rate_date: 2026-10-22}
    default_variant: v35_5_10
    fees: {commitment_fee_rate_month: 0.0015, commitment_free_months: 12}
    prepay_allowed: false
    followup: market
  rent_law: {loan_counts_as: none}           # Neubau: keine Modernisierungsumlage
```

```yaml
# inst/extdata/library/funding/kfw_298_khn_eh55_stufe.yaml   (297 analog)
id: funding/kfw_298_khn_eh55_stufe
block: funding
schema_version: 1
label: "Klimafreundlicher Neubau – EH-55-Stufe (KfW 298), befristet bis 31.12.2026"
from: funding/kfw_298_khn_vermietung
source: {document: "KfW-Merkblatt 297/298, Variante EH 55 (ab 10.04.2026); Budget 800 Mio. EUR 2025/2026", url: "https://www.kfw.de/297-298", publisher: KfW}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-04-10
valid_to: 2027-01-01
quality: B
quality_detail: {budget_risk: D}
legal_state: {as_of: 2026-04-10, status: administrative, reference: "KFN EH 55 (seit 16.12.2025), Haushaltsvorbehalt"}
values:
  eligibility: {conditions: {efficiency_standard: eh55, lca_qng_plus_thg: ~, oil_gas_heating: excluded, building_permit: required}}
  basis: {loan_cap_per_unit_eur: 100000, loan_cap_per_unit_qng_eur: ~}
  budget_risk: {approval_probability: 0.80}   # Memo 07 S2: Verfügbarkeit p = 0,8
  loan:
    variants:
      v10_2_10: {term_years: 10, grace_years: 2, fixed_years: 10, rate_pa: 0.0100, effective_rate_pa: 0.0100, rate_date: 2026-10-22}
      v25_3_10: {term_years: 25, grace_years: 3, fixed_years: 10, rate_pa: 0.0203, effective_rate_pa: 0.0205, rate_date: 2026-10-22}
      v35_5_10: {term_years: 35, grace_years: 5, fixed_years: 10, rate_pa: 0.0219, effective_rate_pa: 0.0221, rate_date: 2026-10-22}
notes: "Ab 2027 entspricht das gesetzliche Referenzniveau etwa EH 55 (Abl.). Prüffall S2-T2/T4: 36 WE x 100.000 = 3.600.000 EUR; Zinsen tilgungsfreie Jahre 78.840 EUR/a; Annuität 30 J. 164.969,40 EUR/a."
```

`funding/kfw_297_khn_selbstnutzung` und `funding/kfw_297_khn_eh55_stufe`: identisch mit 298 bzw. 298-EH-55 bis auf
`program_code: "297"`, `eligibility.applicants: [privatperson]`, `eligibility.conditions.owner_occupied: required`.
Prüffall S5 V1: 297 EH-55-Stufe 100.000 €, 35/5/10, 2,19 %, monatlich → Zins 182,50 €/Monat, Annuität 379,19 €/Monat.

```yaml
# inst/extdata/library/funding/kfw_300_wohneigentum_familien.yaml
id: funding/kfw_300_wohneigentum_familien
block: funding
schema_version: 1
label: "Wohneigentum für Familien – Neubau (KfW 300)"
source: {document: "KfW-Merkblatt 300; Konditionenanzeiger 22.10.2026", url: "https://www.kfw.de/300", publisher: KfW}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-07-21
valid_to: null
quality: B
quality_detail: {loan.variants: A, budget_risk: D}
legal_state: {as_of: 2026-07-21, status: administrative, reference: "Merkblatt 300"}
values:
  instrument_type: loan
  provider: KfW
  program_code: "300"
  application_before_start: true
  budget_risk: {approval_probability: 0.90}
  eligibility:
    applicants: [privatperson]
    project_types: [neubau, erwerb_neubau]
    conditions:
      owner_occupied: required
      children_u18_min: 1
      taxable_income_max_eur: {base: 90000, per_additional_child: 10000}   # 1 Kind 90.000; 2 Kinder 100.000; ...
      efficiency_standard: eh40
      lca_qng_plus_thg: required
  basis:
    loan_cap_by_children_eur:               # ohne / mit QNG-Zertifikat
      - {children_from: 1, children_to: 2, cap: 170000, cap_qng: 220000}
      - {children_from: 3, children_to: 4, cap: 200000, cap_qng: 250000}
      - {children_from: 5, children_to: .inf, cap: 220000, cap_qng: 270000}
  loan:
    repayment: annuity
    payments_per_year: 12
    variants:
      v10_2_10:  {term_years: 10, grace_years: 2, fixed_years: 10, rate_pa: 0.0001, rate_date: 2026-10-22}
      v25_3_10:  {term_years: 25, grace_years: 3, fixed_years: 10, rate_pa: 0.0072, effective_rate_pa: 0.0072, rate_date: 2026-10-22}
      v35_5_10:  {term_years: 35, grace_years: 5, fixed_years: 10, rate_pa: 0.0100, effective_rate_pa: 0.0100, rate_date: 2026-10-22}
      b10_10_10: {repayment: bullet, term_years: 10, grace_years: 10, fixed_years: 10, rate_pa: 0.0115, rate_date: 2026-10-22}
    default_variant: v35_5_10
    fees: {commitment_fee_rate_month: 0.0015, commitment_free_months: 12}
    prepay_allowed: false
    followup: market
notes: "Prüffälle S5-T2/T3: zvE 85.000 EUR, 2 Kinder (Grenze 100.000) -> berechtigt, Höchstbetrag 170.000 EUR; zvE 105.000 EUR -> nicht berechtigt (Berechtigungs-Check, Fallback V2b)."
```

```yaml
# inst/extdata/library/funding/kfw_308_jung_kauft_alt.yaml
id: funding/kfw_308_jung_kauft_alt
block: funding
schema_version: 1
label: "Wohneigentum für Familien – Bestandserwerb „Jung kauft Alt“ (KfW 308)"
from: funding/kfw_300_wohneigentum_familien
source: {document: "KfW-Produktseite 308 (Sek. für Staffel)", url: "https://www.kfw.de/308", publisher: KfW}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-07-21
valid_to: null
quality: C
legal_state: {as_of: 2026-07-21, status: administrative, reference: "Produktinformation 308"}
values:
  program_code: "308"
  eligibility:
    project_types: [erwerb_sanierung]
    conditions:
      efficiency_standard: ~
      lca_qng_plus_thg: ~
      energy_class_at_application: [F, G, H]
      only_residential_property_in_de: required
      renovation_obligation: {months: 54, target: eh85_ee}     # C (ursprünglich EH 70 EE; prüfen)
  basis:
    loan_cap_by_children_eur:
      - {children_from: 1, children_to: 1, cap: 140000}
      - {children_from: 2, children_to: 2, cap: 160000}
      - {children_from: 3, children_to: .inf, cap: 180000}
notes: "Sanierungskosten nicht über 308, sondern über 261. Prüfpunkte: Staffel 140/160/180 TEUR, Einkommensgrenzen, Zielstandard."
```

```yaml
# inst/extdata/library/funding/bafa_beg_em_huelle.yaml
id: funding/bafa_beg_em_huelle
block: funding
schema_version: 1
label: "BEG EM Einzelmaßnahmen Gebäudehülle (BAFA) inkl. iSFP-Bonus"
source: {document: "BAFA, Richtlinie BEG EM i. d. F. vom 21.07.2026; Infoblatt förderfähige Kosten (Sek.)", url: "https://www.bafa.de/beg-em", publisher: BAFA}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-07-21
valid_to: null
quality: C                                   # Sek.; Auslegung iSFP-Bonus offen (Konzept B2)
quality_detail: {budget_risk: D}
legal_state: {as_of: 2026-07-21, status: administrative, reference: "Richtlinie BEG EM, BAnz AT 27.08.2026"}
values:
  instrument_type: grant
  provider: BAFA
  program_code: "beg_em_huelle"
  application_before_start: true
  budget_risk: {approval_probability: 0.90}
  eligibility:
    applicants: [privatperson, weg, unternehmen, kommunales_unternehmen, genossenschaft, gemeinnuetzig]
    measure_types: [daemmung_fassade, daemmung_dach, daemmung_ogd, daemmung_kellerdecke, fenster, aussentuer, sonnenschutz]
    conditions: {building_age_min_years: 5, min_investment_eur: 300, energy_efficiency_expert: required}
  basis:
    eligible_cost_caps_per_unit_per_calendar_year:
      - {units_from: 1, units_to: 1, cap_eur: 30000, cap_isfp_eur: 60000}
      - {units_from: 2, units_to: 6, cap_eur: 15000, cap_isfp_eur: 30000}
      - {units_from: 7, units_to: .inf, cap_eur: 8000, cap_isfp_eur: 15000}
    cap_period: calendar_year
  rate_components:
    grund: {rate: 0.15}
    isfp:
      rate: 0.05
      condition: "funding.this.isfp"
      threshold: {single_unit_eur: 30000, multi_unit: cap_without_bonus}   # Bonus erst ab Mindestinvestition
      mode: excess_over_threshold            # Default (Memo 02); Alternative whole_amount
  payout: {event: completion_proof, lag_months: 6}
  rent_law: {grant_counts_as: zuschuss_559a_abs1}
  cumulation: {exclusive_with: [funding/estg_35c], combinable_with: [funding/kfw_358_ergaenzungskredit_plus, funding/kfw_359_ergaenzungskredit]}
notes: "Angekündigt Q1/2027 (nicht enthalten): WPB-Bonus +5 Pp für Dämmung aus iSFP. Prüffälle S4-T4: 2030 min(85.988,87; 60.000) -> 0,15 x 60.000 + 0,05 x 30.000 = 10.500,00 EUR (Alternative 12.000,00); 2033: 0,15 x 55.405,82 + 0,05 x 25.405,82 = 9.581,16 EUR (Alternative 11.081,16); Beispiel Memo 02: 40.000 EUR Fassade EFH -> 6.500 EUR."
```

```yaml
# inst/extdata/library/funding/bafa_beg_em_fachplanung.yaml
id: funding/bafa_beg_em_fachplanung
block: funding
schema_version: 1
label: "BEG EM Fachplanung und Baubegleitung (BAFA)"
source: {document: "BAFA BEG EM (Sek.)", url: "https://www.bafa.de/beg-em", publisher: BAFA}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-07-21
valid_to: null
quality: C
legal_state: {as_of: 2026-07-21, status: administrative, reference: "Richtlinie BEG EM"}
values:
  instrument_type: grant
  provider: BAFA
  program_code: "beg_em_fachplanung"
  application_before_start: true
  budget_risk: {approval_probability: 0.90}  # D
  rate_components: {grund: {rate: 0.50}}
  basis: {cap_efh_eur: 5000, cap_mfh_per_unit_eur: 2000, cap_mfh_total_eur: 20000}
  payout: {event: completion_proof, lag_months: 6}
```

```yaml
# inst/extdata/library/funding/estg_35c.yaml
id: funding/estg_35c
block: funding
schema_version: 1
label: "Steuerermäßigung für energetische Maßnahmen an selbstgenutztem Wohneigentum (§ 35c EStG)"
source: {document: "§ 35c EStG; zuletzt geändert durch Art. 7 G. v. 29.06.2026 (BGBl. 2026 I Nr. 197)", url: "https://www.gesetze-im-internet.de/estg/__35c.html", publisher: BMJ}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2020-01-01
valid_to: 2030-01-01                         # Abschluss der Maßnahme vor dem 01.01.2030
quality: B
legal_state: {as_of: 2026-06-29, status: in_force, reference: "§ 35c EStG"}
values:
  instrument_type: tax_credit
  program_code: "estg_35c"
  application_before_start: false
  budget_risk: {approval_probability: 1.0}   # Rechtsanspruch, keine Haushaltsbindung
  eligibility:
    applicants: [privatperson]
    conditions: {owner_occupied: required, building_age_min_years: 10, contractor_certified: required, completion_before: 2030-01-01}
  credit:
    total_share: 0.20
    schedule_shares: [0.07, 0.07, 0.06]      # Jahr der Fertigstellung, Folgejahr, übernächstes Jahr
    cap_per_object_eur: 40000                # = 200.000 EUR Aufwendungen
    energy_advice_share: 0.50
    capped_by_expected_income_tax: true      # household.expected_income_tax_eur_pa (# 01b); nicht nutzbare Beträge verfallen
  cumulation: {exclusive_with: [funding/kfw_458_heizung_privat, funding/bafa_beg_em_huelle, funding/kfw_261_wg_kredit_2026]}
notes: "Prüfpunkt: Inhalt der Änderung vom 29.06.2026 nicht geprüft (Memo 02 §5.7). Ausweis im Abschnitt grants, Kategorie tax_credit (R-11)."
```

### 3.5 Recht (`legal/**`)

Automatische Auswahl je `topic` nach Spec 00 §4.10. Themen v1: `mietrecht`, `mietrecht_559f`, `co2kostaufg`,
`bio_treppe`, `co2_pricing`, `emission_factors_geg`, `emission_factors_co2cost`, `grunderwerbsteuer`, `umsatzsteuer`.
Einträge der Qualität C ohne Freigabe (`mietrecht_559f`, `grunderwerbsteuer`) sind bis zur Fachfreigabe nur mit
`project.pending_reforms: [unreleased]` aktiv; sonst ist das Thema inaktiv (§ 559f: keine Halbierung; GrESt: E
`validation.acquisition.grest_inactive` ohne `grest_rate`, Teil A 4.8). Die Regeln,
die diese Werte lesen, gehören WS-E (Spec 00 §5.3, Teil B); Feldnamen der Nutzlast sind die Parameternamen der
Regeln (# 01b).

```yaml
# inst/extdata/library/legal/mietrecht_2026.yaml
id: legal/mietrecht_2026
block: legal
topic: mietrecht
schema_version: 1
label: "Mietrecht BGB, Stand GModG (in Kraft seit 29.07.2026)"
source: {document: "BGB §§ 536, 555b, 556d-556g, 557a, 557b, 558, 559-559f i. d. F. des Gesetzes vom 23.07.2026 (BGBl. 2026 I Nr. 226)", url: "https://www.gesetze-im-internet.de/bgb/", publisher: BMJ}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-07-29
valid_to: null
quality: A
quality_detail: {interpretation: D, s558.funding_deduction_duration_grant_years: D}
legal_state: {as_of: 2026-07-29, status: in_force, reference: "BGB, zuletzt geändert durch Art. 6 GModG-Änderungsgesetz (BGBl. 2026 I Nr. 226)"}
values:
  s558:
    waiting_months: 15                    # Miete seit 15 Monaten unverändert (ohne §§ 559-560)
    request_min_months_after_last: 12
    effective_month_offset: 3             # ab Beginn des dritten Kalendermonats nach Zugang (§ 558b)
    cap_share: 0.20                       # in 3 Jahren
    cap_share_tight_market: 0.15          # project.municipality.kappung_15_area
    cap_window_months: 36
    ovm_lookback_years: 6
    excludes_increases: [bgb_559, bgb_559e, bgb_560]
    funding_deduction_grant_share_pa: 0.08          # § 558 Abs. 5: 8 % des Zuschusses p. a.
    funding_deduction_duration_grant_years: 12      # D, strittig (Konzept B1)
    funding_deduction_duration_loan: fixed_period   # D: Dauer der Zinsbindung
  s559:
    rate_pa: 0.08
    cap_window_years: 6
    cap_eur_m2_month: 3.00
    cap_low_rent_eur_m2_month: 2.00
    low_rent_threshold_eur_m2_month: 7.00
    heating_cap_eur_m2_month: 0.50        # Heizungsanteil (§ 555b Nr. 1, 1a) innerhalb der Gesamtkappe
    effective_month_offset: 3
    delay_if_defective_notice_months: 6   # § 559b Abs. 2 (auch bei > 10 % Kostenabweichung)
    cost_deviation_threshold: 0.10
    hardship_exclusion_not_for: [bgb_555b_1, bgb_555b_1a]
  s559a:
    grants_reduce_costs: true             # Zuschüsse inkl. Tilgungszuschuss (Praxis)
    repayment_grant_as_grant: true
    interest_reduction: "(i_markt - i_foerder) x Ursprungsbetrag p. a."
    market_rate_reference: first_mortgage_at_completion
  s559c:
    cost_limit_per_unit_eur: 10000
    flat_maintenance_share: 0.30
    interest_reduction_applicable: false  # § 559a Abs. 2 nicht anwendbar; Zuschüsse abziehen (Lesart prüfen)
    lookback_years: 5
    lock_years: 5
  s559e:
    rate_pa: 0.10
    flat_maintenance_share: 0.15
    flat_not_for_section43_heating: true  # Pauschale nicht für neue Gas-/Öl-/Flüssiggasheizung nach § 43 GModG
    cap_eur_m2_month: 0.50
    cap_window_years: 6
    requires_third_party_funds: true      # ohne in Anspruch genommene Drittmittel: § 559
    requires_measure: bgb_555b_1a
  # § 559f (JAZ-Schwelle) als eigener Eintrag legal/mietrecht_559f_2026 (Qualität C, Freigabe ausstehend; 01b 7.4)
  s557a: {excludes: [bgb_558, bgb_559, bgb_559b], min_step_months: 12, mietpreisbremse_per_step: true}
  s557b:
    index: vpi
    min_months_unchanged: 12
    excludes: [bgb_558]
    s559_only_if_not_attributable: true
    heating_1a_allowed: true
    effective_month_offset: 2
  s556d:
    cap_share_over_ovm: 0.10
    ordinance_until: 2029-12-31
    newbuild_first_use_after: 2014-10-01
    first_letting_after_comprehensive_modernisation_exempt: true
  s536_1a: {exclusion_months: 3, scope: [bgb_555b_1]}
  interpretation:                         # Auslegungs-Defaults (vorsichtigere Lesart, Konzept F13/F14/B1); gelesen als Defaults von unit_groups.<g>.rent_law (01b §1.3)
    third_party_allocation: full          # -> drittmittel_attribution: full | proportional (F14)
    s559e_order: flat_before_funds        # -> flat_559e_order: 0,10 x (0,85 K - D) (F13); Alternative funds_before_flat
    s559f_order: halve_then_funds         # -> hp_reduction_order (B1); Alternative funds_then_halve
    heating_cap_order: heating_first      # Teilkappung Heizungsanteil vor Gesamtkappe (F14; in 01b fest)
    s559e_flat_for_section43: false       # -> section43_flat: keine 15-%-Pauschale bei § 43-Heizung (B1)
notes: "Prüfpunkte (Konzept §10.2): § 559f Wortlaut, Grenzfall und Ausnahmen; Reichweite der 15-%-Pauschale bei § 43-Heizungen; Dauer der Kürzung nach § 558 Abs. 5; BGH-Urteile zu Erhaltungsanteil und § 558/§ 559. Rechtsstände vor dem 29.07.2026 sind in v1 nicht hinterlegt."
```

**Prüffälle (WS-E, aus Memo 02/07, Konzept F13/F14):** (m1) Rechenbeispiel 1: 70 m², 7,50 €/m², K 60.000, IH 18.000,
TZ 3.000, Zinsermäßigung 162 → U = 2.958 €/a = 3,52 €/m²·Monat → Kappe 3,00 → 2.520 €/a. (m2) Rechenbeispiel 3 (§ 559e):
15.000 €/WE, Zuschuss 4.500 → 0,10 · (0,85 · 15.000 − 4.500) = 825 €/a → Kappe 0,50 €/m² → 420 €/a. (m3) S3-T3:
0,10 · (0,85 · 153.560 − 45.300) = 8.522,60 €/a; gekappt 0,50 · 840 · 12 = 5.040,00 €/a. (m4) S3-T4 (Plan-JAZ 2,4,
Vorlauf > 55 °C): `halve_then_funds` 0,10 · (0,85 · 76.780 − 45.300) = 1.996,30 €/a; `funds_then_halve`
0,10 · (0,85 · 153.560 − 45.300) · 0,5 = 4.261,30 €/a. (m5) S1-T4: (874.303,50 − 144.400) · 0,08 − 1.300.000 · 0,0035 =
53.842,28 €/a. (m6) § 558 Mietpfad Memo 02 §2.2 (Monat 16: 9,51 €/m²; Monat 106: 11,44 €/m²).

```yaml
# inst/extdata/library/legal/mietrecht_559f_2026.yaml
id: legal/mietrecht_559f_2026
block: legal
topic: mietrecht_559f
schema_version: 1
label: "§ 559f BGB: Halbierung der Umlagebasis bei Wärmepumpen mit Plan-JAZ unter 2,5"
source: {document: "Memo 07 §1.2 (einzige Fundstelle; Gesetzestext am Stichtag nicht geprüft), Konzept §10.2", url: "docs/recherche/07_use_cases_referenzszenarien.md", publisher: "Sekundärquelle"}
as_of: 2026-10-25
valid_from: 2026-07-29
valid_to: null
quality: C
release: {status: pending, by: null, date: null}   # Spec 00 §4.10 (R-80): bis zur Fachfreigabe nur mit pending_reforms: [unreleased]
legal_state: {as_of: 2026-07-29, status: in_force, reference: "§ 559f BGB i. d. F. GModG-Änderungsgesetz (Wortlaut, Grenzfall und Ausnahmen prüfen)"}
values:
  jaz_threshold: 2.5
  comparison: ge                          # ">= 2,5" (Grenzfall prüfen) -> rent_law.hp_threshold_inclusive
  reduction_factor: 0.5                   # sonst nur 50 % der Kosten ansetzbar
  jaz_basis: plan                         # Plan-JAZ VDI 4650 Bl. 1, Nachweis vor Inbetriebnahme (R-70)
  exceptions: {construction_year_after: 1996, flow_temperature_max_c: 55}
notes: "Ohne Freigabe ist das Thema inaktiv: keine Halbierung (Spec 00 §4.10 Beispiel). Prüfwerte S3-T4 (5.3) mit pending_reforms: [unreleased]."
```

```yaml
# inst/extdata/library/legal/mietrecht_ii_reform.yaml
id: legal/mietrecht_ii_reform
block: legal
topic: mietrecht
reform: mietrecht_ii
schema_version: 1
label: "Mietrecht II (Regierungsentwurf, anhängig)"
from: legal/mietrecht_2026
source: {document: "BT-Drs. 21/6807 vom 01.07.2026 (Kabinett 29.04.2026; Anhörung Rechtsausschuss 14.10.2026)", url: "https://dserver.bundestag.de/btd/21/068/2106807.pdf", publisher: "Deutscher Bundestag"}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-07-01
valid_to: null
quality: B
legal_state: {as_of: 2026-07-01, status: pending, reference: "BT-Drs. 21/6807; Inkrafttreten am Tag nach Verkündung, Möblierung/Kurzzeit 1. Tag des 4. Folgemonats"}
values:
  s559c: {cost_limit_per_unit_eur: 20000}
  s557a: {excludes: [bgb_558, bgb_559, bgb_559b, bgb_559e]}
  s557b:
    damping: {threshold_pa: 0.03, excess_share_ignored: 0.5, symmetric: true, only_in_ordinance_areas: true}   # project.municipality.index_cap_area
  s536_1a: {scope: [bgb_555b_1, bgb_555b_1a]}
notes: "Nur aktiv mit project.pending_reforms: [mietrecht_ii] (D10). Beispiel Begründung: Inflation 5 % -> Indexerhöhung 4 %."
```

```yaml
# inst/extdata/library/legal/co2kostaufg_2026.yaml
id: legal/co2kostaufg_2026
block: legal
topic: co2kostaufg
schema_version: 1
label: "Kohlendioxidkostenaufteilungsgesetz (Wohngebäude), Stand GModG"
source: {document: "CO2KostAufG Anlage zu §§ 5-7; §§ 5a-5d i. d. F. Art. 5 GModG-Änderungsgesetz (BGBl. 2026 I Nr. 226)", url: "https://www.gesetze-im-internet.de/co2kostaufg/", publisher: BMJ}
references:
  - {document: "Haufe 04.08.2026 (§§ 5b, 5d)", url: "https://www.haufe.de/immobilien/", publisher: Haufe}
  - {document: "GÖRG 17.07.2026", url: "https://www.goerg.de/de/aktuelles/veroeffentlichungen/17-07-2026/gebaeudemodernisierungsgesetz-gmodg-schafft-geg-ab-was-sich-aendert-und-was-bleibt", publisher: GÖRG}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-07-29
valid_to: null
quality: B
quality_detail: {s5b: C, s5d: C, s5a.transition: C, s9: C}
legal_state: {as_of: 2026-07-29, status: in_force, reference: "CO2KostAufG §§ 5-7, 5a-5d, 9; § 5a wirksam ab 01.01.2028 bzw. 01.01.2029"}
values:
  stage_model:                            # kg CO2/(m2 Wohnfläche a): Obergrenze (exklusiv) -> Vermieteranteil
    - {upper_kg_m2a: 12,   landlord_share: 0.00}
    - {upper_kg_m2a: 17,   landlord_share: 0.10}
    - {upper_kg_m2a: 22,   landlord_share: 0.20}
    - {upper_kg_m2a: 27,   landlord_share: 0.30}
    - {upper_kg_m2a: 32,   landlord_share: 0.40}
    - {upper_kg_m2a: 37,   landlord_share: 0.50}
    - {upper_kg_m2a: 42,   landlord_share: 0.60}
    - {upper_kg_m2a: 47,   landlord_share: 0.70}
    - {upper_kg_m2a: 52,   landlord_share: 0.80}
    - {upper_kg_m2a: .inf, landlord_share: 0.95}
  s5a:                                    # neue Heizung nach § 43 Abs. 1 GModG (Gas/Öl/Flüssiggas), eingebaut nach 29.07.2026
    applies_to_installed_after: 2026-07-29
    co2_from: 2028-01-01
    co2_landlord_share: 0.5
    network_fee_from: 2028-01-01
    network_fee_landlord_share: 0.5       # Gasnetzentgelte (§ 40 Abs. 3 Nr. 4 EnWG)
    bio_premium_from: 2029-01-01
    bio_premium_landlord_share: 0.5
    bio_premium_max_fuel_share: 0.30      # Vermieteranteil nur bis 30 % biogener Anteil
    transition: {breakdown_install_months_before: 12, suspension_months: 12}   # C (Havarie)
  s5b: {newbuild_applies: true, building_application_from: 2026-05-13, completed_until: 2029-12-31}   # C
  s5d:                                    # C: Härtefall Kleinvermieter, Stufenmodell gilt weiter
    max_rented_units: 6
    energy_classes: [G, H]
    rent_below_ovm_share: 0.85
    rent_below_ovm_share_tight_market: 0.70
    tenant_information: text_form
  s9: {reduction_factor: 0.5}             # C: öffentlich-rechtliche Beschränkungen (Denkmal, Milieuschutz)
  district_heating: co2_cost_in_heat_price
  non_residential_split: 0.5
notes: "Prüffall Rechenbeispiel 4 (Memo 02): 1.000 m2, 150 kWh_Hs/m2a Gas, EF 0,182 -> 27,3 kg/m2a -> 40 %; bei 65 EUR/t Kosten brutto 2.111 EUR/a, Vermieter 845 EUR/a (§ 5a: 1.056 EUR/a). S1-T9: 31,7 kg/m2a -> 40 %; S3-T5: 23,5 kg/m2a -> 30 %."
```

```yaml
# inst/extdata/library/legal/gmodg_bio_treppe_2026.yaml
id: legal/gmodg_bio_treppe_2026
block: legal
topic: bio_treppe
schema_version: 1
label: "Bio-Treppe für neue fossile Heizungen im Bestand (§ 43 Abs. 1 GModG)"
source: {document: "GModG § 43 Abs. 1 i. d. F. vom 23.07.2026 (BGBl. 2026 I Nr. 226)", url: "https://www.buzer.de/43_GModG.htm", publisher: "BMJ/buzer.de"}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-07-29
valid_to: null
quality: B
legal_state: {as_of: 2026-07-29, status: in_force, reference: "GModG § 43 Abs. 1; § 42a (Grüngasquote) angekündigt"}
values:
  applies_to: {heating_types: [gas, oil, lpg], installed_after: 2026-07-29, building: existing}
  min_bio_share: {years: [2029, 2030, 2035, 2040], values: [0.10, 0.15, 0.30, 0.60], interpolate: step}
  newbuild_zero_emission_from: 2030-01-01
  bio_carriers: [biomethan, biooel, biogenes_fluessiggas, wasserstoff]
notes: "Stufen gelten ab 1. Januar des Jahres. Erfüllungsoptionen (Solarthermie, WRG, WP-Hybrid) # 01b."
```

```yaml
# inst/extdata/library/legal/gmodg_bio_treppe_2045.yaml
id: legal/gmodg_bio_treppe_2045
block: legal
topic: bio_treppe
reform: stufe_2045                         # Schaltercode nach Spec 00 §4.10 (R-82)
schema_version: 1
label: "Bio-Treppe mit abgeleiteter Stufe 100 % klimaneutraler Brennstoff ab 2045"
from: legal/gmodg_bio_treppe_2026
source: {document: "Ableitung aus dem Klimaneutralitätsziel 2045 bzw. angekündigtem § 42a (Konzept §3.8)", url: "docs/Konzept.md", publisher: "eigene Ableitung"}
as_of: 2026-10-25
valid_from: 2026-07-29
valid_to: null
quality: D
legal_state: {as_of: 2026-07-29, status: derived, reference: "keine Gesetzesstufe; Szenario-Schalter, Voreinstellung aus"}
values:
  min_bio_share: {years: [2029, 2030, 2035, 2040, 2045], values: [0.10, 0.15, 0.30, 0.60, 1.00], interpolate: step}
notes: "Nur aktiv mit project.pending_reforms: [stufe_2045] (Pflichtsensitivität stufe_2045, 4.4; Szenario-Sets dürfen pending_reforms setzen, R-82). Qualität D: nie automatisch (Spec 00 §4.10). Status derived; der Schaltercode dient nur der Aktivierung. Ersetzt das Feld energy.climate_neutral_2045 aus 01b §3.2.4 (Abgleich, Offene Punkte)."
```

```yaml
# inst/extdata/library/legal/behg_ets2_2026.yaml
id: legal/behg_ets2_2026
block: legal
topic: co2_pricing
schema_version: 1
label: "CO2-Bepreisung Gebäude: BEHG-Preise und -Korridore, EU-ETS 2 ab 2028"
source: {document: "BEHG; Drittes BEHG-Änderungsgesetz (BT-Drs. 21/7869, BR-Drs. 462/26); RL 2003/87/EG Art. 30h", url: "https://dserver.bundestag.de/brd/2026/0462-26.pdf", publisher: "Bundestag/Bundesrat"}
references:
  - {document: "UBA Climate Change 15/2026 (MSR)", url: "https://www.umweltbundesamt.de/system/files/medien/11850/publikationen/2026-03/15_2026_CC.pdf", publisher: UBA}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: B
quality_detail: {corridor_2027: C, ets2.psm.release_volume_mt: C}
legal_state: {as_of: 2026-10-15, status: in_force, reference: "BEHG; Korridor 2027: Bundestag 15.10.2026 beschlossen, Bundesrat ausstehend (adopted_pending)"}
values:
  price_history_eur_t: {2021: 25, 2022: 30, 2023: 30, 2024: 45, 2025: 55}
  corridor_2026: {min: 55, max: 65, first_auction_2026_07_01: 65}
  corridor_2027: {min: 55, max: 65, status: adopted_pending, surplus_price: 71, buyback_price: 73}
  ets2:
    start: 2028-01-01
    first_auction: 2027-01-18             # C
    psm: {trigger_eur2020: 45, trigger_nominal_2027_approx: 56, release_volume_mt: 40, release_volume_legacy_mt: 20, max_releases_per_year: 2}
notes: "Preisannahme mit Statusvermerk (Konzept F5). Memo 02/03 widersprechen sich beim Verfahrensstand 2027 und bei der Freigabemenge (20 vs. 40 Mio.)."
```

```yaml
# inst/extdata/library/legal/emission_factors_geg_anlage9.yaml
id: legal/emission_factors_geg_anlage9
block: legal
topic: emission_factors_geg
schema_version: 1
label: "Emissionsfaktoren GEG/GModG Anlage 9 (Energieausweis), Fassung bis 31.12.2026"
source: {document: "GModG Anlage 9 (Fassung m. W. v. 01.01.2023)", url: "https://www.buzer.de/Anlage_9_GModG.htm", publisher: "BMJ/buzer.de"}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2023-01-01
valid_to: 2027-01-01
quality: A
legal_state: {as_of: 2023-01-01, status: in_force, reference: "Neufassung durch G. v. 23.07.2026 ab 01.01.2027 (neue Werte ungeprüft)"}
values:                                   # g CO2-Äq./kWh Endenergie (Hi-Basis nach DIN V 18599)
  heating_oil: 310
  natural_gas: 240
  lpg: 270
  hard_coal: 400
  lignite: 430
  biogas: 140
  biogas_on_site: 75
  bio_lpg: 180
  bio_oil: 210
  bio_oil_on_site: 105
  wood: 20
  electricity_grid: 560
  electricity_on_site_pv_wind: 0
  electricity_displacement_mix: 860
  ambient_geothermal_solar: 0
  process_waste_heat: 40
  municipal_waste_incineration: 20
  district_heating_chp: {coal: 300, gas_oil: 180, renewable: 40}
  district_heating_boiler: {coal: 400, gas_oil: 300, renewable: 60}
notes: "Nur Energieausweis/Klassifizierung; CO2-Kosten mit legal/emission_factors_co2cost_2026. Hinweis auf 2027er Werte (Strom 100 g/kWh) ungeprüft (C) und nicht übernommen."
```

```yaml
# inst/extdata/library/legal/emission_factors_co2cost_2026.yaml
id: legal/emission_factors_co2cost_2026
block: legal
topic: emission_factors_co2cost
schema_version: 1
label: "Emissionsfaktoren für CO2-Kosten (BEHG/EBeV 2030 Anlage 2) und Umrechnungen"
source: {document: "EBeV 2030 Anlage 2 (Standardwerte)", url: "https://gesetze.legal/bund/ebev_2030/anlage_2", publisher: BMJ}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2021-01-01
valid_to: null
quality: A
legal_state: {as_of: 2026-10-25, status: in_force, reference: "EBeV 2030 Anlage 2; gleiche Werte im CO2KostAufG"}
values:                                   # kg CO2/kWh
  natural_gas_hs: 0.1814                  # 0,0558 t/GJ x 3,2508 GJ/MWh_Hs
  natural_gas_hi: 0.2009
  heating_oil_hi: 0.2664                  # 0,074 t/GJ
  lpg_hi: 0.2358                          # 0,0655 t/GJ
  wood: 0.0
  biomethane: 0.0                         # nachhaltigkeitszertifiziert
  conversion:
    gas_hs_to_hi: 0.903
    heating_oil_kwh_per_litre: 10.05      # 42,8 GJ/t x 0,845 kg/l
    pellets_kwh_per_kg: 5.0               # C
notes: "Memo 02 nennt für Erdgas 0,0561 t/GJ (0,202 kg/kWh_Hi); maßgeblich EBeV 0,0558. Referenzszenarien S1-S5 verwenden als Szenarioeinstellung 0,181 kg/kWh_Hs (Memo 07 §4.0)."
```

```yaml
# inst/extdata/library/legal/grunderwerbsteuer_2026.yaml
id: legal/grunderwerbsteuer_2026
block: legal
topic: grunderwerbsteuer
schema_version: 1
label: "Grunderwerbsteuersätze der Länder"
source: {document: "Landesgesetze; Übersicht baufi24; Bremisches Gesetzblatt Nr. 9 vom 05.02.2025", url: "https://www.baufi24.de/grunderwerbsteuer/", publisher: "baufi24; Freie Hansestadt Bremen"}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2025-07-01
valid_to: null
quality: C                                # Konzept §10.2: Sätze nicht im Original verifiziert
release: {status: pending, by: null, date: null}   # Spec 00 §4.10 (R-80): bis zur Fachfreigabe nur mit pending_reforms: [unreleased] wählbar
legal_state: {as_of: 2025-07-01, status: in_force, reference: "GrEStG § 11 i. V. m. Landesrecht; Bremen: Rücknahmeantrag zum 01.01.2027 (Drs. 21/1941) offen"}
values:
  rates: {BW: 0.050, BY: 0.035, BE: 0.060, BB: 0.065, HB: 0.055, HH: 0.055, HE: 0.060, MV: 0.060, NI: 0.050, NW: 0.065, RP: 0.050, SL: 0.065, SN: 0.055, ST: 0.050, SH: 0.065, TH: 0.050}
  exemption_threshold_eur: 2500           # Freigrenze § 3 Nr. 1 GrEStG
  uniform_contract_includes_construction: false   # Default des Schalters (Spec 00 §7.11)
```

```yaml
# inst/extdata/library/legal/umsatzsteuer_2026.yaml
id: legal/umsatzsteuer_2026
block: legal
topic: umsatzsteuer
schema_version: 1
label: "Umsatzsteuersätze für Bau-, Energie- und PV-Leistungen"
source: {document: "UStG §§ 4 Nr. 12, 12 Abs. 1, 2, 3 Nr. 1", url: "https://www.gesetze-im-internet.de/ustg_1980/", publisher: BMJ}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2023-01-01
valid_to: null
quality: A
quality_detail: {pv_zero_rate.above_30kwp: C}
legal_state: {as_of: 2023-01-01, status: in_force, reference: "UStG"}
values:
  standard: 0.19
  reduced: 0.07
  pv_zero_rate: {max_kwp_without_proof: 30, above_30kwp: attribute_required}   # Reichweite > 30 kWp prüfen (Konzept §10.2)
  residential_letting_exempt: true        # § 4 Nr. 12: kein Vorsteuerabzug -> Bruttokosten (D6)
```

### 3.6 Preise (`prices/**`, `block: market`)

Die Nutzlast enthält einen Teilbaum `market` mit Wertformen, die über `market: {from: prices/<id>, use: market}`
übernommen werden (lokal gewinnt), sowie informative Komponenten.

```yaml
# inst/extdata/library/prices/energy_prices_2026.yaml
id: prices/energy_prices_2026
block: market
schema_version: 1
label: "Energiepreise 2026 (12-Monats-Mittel, netto) mit Komponenten und Normalpreisen"
source: {document: "BDEW Gas-/Strompreisanalyse 08/2026; BNetzA Monitoringbericht 2025; waermepreise.info 04/2026; DEPI 10/2026; Destatis (Memo 03 §2.1-2.4)", url: "https://www.bdew.de/media/documents/BDEW_Gaspreisanalyse_082026.pdf", publisher: "BDEW; BNetzA; AGFW/BDEW/VKU; DEPI"}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: B
quality_detail: {market.energy_price.heatpump_power: D, market.energy_price.heatpump_power_mfh: D, market.energy_price.oil: C, market.energy_price.pellets: C, components.oil.spot_eur_kwh: C, market.bio_fuel_premium: D, components.normal_price_excl_co2: D, base_fees: C}
legal_state: {as_of: 2026-10-25, status: market, reference: "Marktdaten"}
values:
  market:
    energy_price:                         # EUR/kWh NETTO, ohne CO2-Komponente und ohne getrennt geführtes Netzentgelt (K4, # 01b §3.2.1)
      gas:                {start: 0.06335, growth: 0.02}
      gas_mfh:            {start: 0.06043, growth: 0.02}
      power:              {start: 0.31513, growth: 0.02}
      heatpump_power:     {start: 0.21849, growth: 0.02}
      heatpump_power_mfh: {start: 0.21008, growth: 0.02}
      oil:                {start: 0.10034, growth: 0.02}
      district_heating:   {start: 0.13109, growth: 0.025}
      pellets:            {start: 0.07944, growth: 0.025}   # brutto 8,5 ct / 1,07 (USt-Satz C)
    energy_network_fee:                   # EUR/kWh netto
      gas:     {start: 0.0257, growth: 0.03}   # Memo 07 §1.3, §4.0; Wachstum Netzrückbau (Overlay: Szenario verweist auf shared, 1.9)
      gas_mfh: {start: 0.0219, growth: 0.03}
    bio_fuel_premium: {start: 0.060, growth: 0.02}   # Biomethan-Mehrkosten 6,0 ct netto (Memo 07 §4.0), D
  components:                             # informativ (Herleitung, Plausibilisierung), EUR/kWh BRUTTO
    gas:     {total_incl_co2_65: 0.120, co2_component_at_65: 0.0140, network_fee: 0.0306, range: [0.105, 0.155]}
    gas_mfh: {total_incl_co2_65: 0.112, co2_component_at_65: 0.0140, network_fee: 0.0261, range: [0.098, 0.145]}
    power:   {total: 0.375, range: [0.32, 0.42]}
    heatpump_power: {total: 0.260, range: [0.20, 0.31]}
    oil:     {total_incl_co2_65: 0.140, co2_component_at_65: 0.0206, spot_eur_kwh: 0.172, range: [0.095, 0.19]}
    district_heating: {total: 0.156, range: [0.125, 0.175], net_spread: [0.08, 0.36]}
    pellets: {total: 0.085, range: [0.065, 0.105]}
    normal_price_excl_co2: {gas: 0.100, oil: 0.080, district_heating: 0.150, power: 0.360, heatpump_power: 0.250, pellets: 0.070}
    company_net: {gas_mfh: 0.094, district_heating: 0.131, power_common: 0.270, heatpump_power: 0.210}
  base_fees_eur_pa: {gas_efh: 151.26, heatpump_power_efh: 117.65, power_household: 100.84}   # netto; brutto 180/140/120 (Memo 07 §4.0, C)
  vat_rate: {standard: 0.19, pellets: 0.07}   # pellets C (Prüfpunkt)
uncertainty:
  market.energy_price.gas: {dist: triangular, min: 0.0508, mode: 0.06335, max: 0.0928}   # netto, aus Spanne 10,5-15,5 ct brutto inkl. CO2 und Netzentgelt
notes: "Deterministischer Default = 12-Monats-Mittel mit Trendwachstum; die MC kehrt zum Normalpreis zurück (processes/energy_prices_mr_2026), daher liegt der MC-Erwartungswert bei Gas, Öl, Pellets unter dem Basisfall (Konzept §3.8, B8). Neuverträge 01.10.2026: Gas 13,8 ct, Strom 38,9 ct (Beobachtung)."
```

```yaml
# inst/extdata/library/prices/co2_price_paths_2026.yaml
id: prices/co2_price_paths_2026
block: market
schema_version: 1
label: "CO2-Preispfade Gebäude, nominal (niedrig / mittel / hoch)"
source: {document: "Memo 03 §3.4: hoch = UBA/Prognos Rahmendaten THG-Projektionen 2026; mittel = Analystenerwartung nach MSR-Reform plus Extrapolation; niedrig = Preisdämpfung PSM", url: "https://www.umweltbundesamt.de/system/files/medien/11850/publikationen/2026-04/2026_Rahmendatenpapier.pdf", publisher: "UBA/Prognos; eigene Ableitung"}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
quality_detail: {scenarios.hoch: A}
legal_state: {as_of: 2026-10-25, status: market, reference: "Preisannahmen; Status BEHG 2027 in legal/behg_ets2_2026"}
values:
  scenarios:                               # EUR/t netto; nach 2050 +2 %/a (Abl.)
    niedrig: {years: [2026, 2027, 2028, 2030, 2032, 2035, 2040, 2045, 2050, 2060, 2070], values: [65, 55, 45, 55, 60, 75, 100, 120, 140, 170.66, 208.03], interpolate: linear}
    mittel:  {years: [2026, 2027, 2028, 2030, 2032, 2035, 2040, 2045, 2050, 2060, 2070], values: [65, 65, 60, 75, 90, 130, 170, 210, 250, 304.75, 371.49], interpolate: linear}
    hoch:    {years: [2026, 2027, 2028, 2030, 2032, 2035, 2040, 2045, 2050, 2060, 2070], values: [65, 80, 95, 125, 155, 200, 275, 350, 425, 518.07, 631.53], interpolate: linear}
  market:
    co2_price: {years: [2026, 2027, 2028, 2030, 2032, 2035, 2040, 2045, 2050, 2060, 2070], values: [65, 65, 60, 75, 90, 130, 170, 210, 250, 304.75, 371.49], interpolate: linear}
notes: "Verwendung: market.co2_price: {from: prices/co2_price_paths_2026, use: scenarios.mittel}. Kosten je kWh bei 65 EUR/t: Gas 1,18 ct netto / 1,40 ct brutto (Hs), Heizöl 1,73 / 2,06 ct (Hi); je +10 EUR/t Gas +0,22 ct brutto."
```

```yaml
# inst/extdata/library/prices/co2_price_path_referenzszenarien_2026.yaml
id: prices/co2_price_path_referenzszenarien_2026
block: market
schema_version: 1
label: "CO2-Preispfad der Referenzszenarien S1-S5 (Memo 07 §4.0) mit unsicheren Stützstellen 2030/2040"
source: {document: "Memo 07 §4.0: 60 EUR/t 2026/2027, 70 EUR/t 2028, +5 EUR/t p. a. bis 2035 (105), danach +3 % p. a.", url: "docs/recherche/07_use_cases_referenzszenarien.md", publisher: "eigene Festlegung (Referenzszenarien)"}
as_of: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
legal_state: {as_of: 2026-10-25, status: derived, reference: "Szenarioannahme"}
values:                                   # setzt shared.co2_2030 (Basis 80) und shared.co2_2040 (Basis 105 x 1,03^5) im Szenario voraus
  series:
    2026: 60
    2027: 60
    2028: 70
    2029: {expr: "(70 + shared.co2_2030) / 2"}
    2030: {ref: shared.co2_2030}
    2031: {expr: "shared.co2_2030 + 1 * (105 - shared.co2_2030) / 5"}
    2032: {expr: "shared.co2_2030 + 2 * (105 - shared.co2_2030) / 5"}
    2033: {expr: "shared.co2_2030 + 3 * (105 - shared.co2_2030) / 5"}
    2034: {expr: "shared.co2_2030 + 4 * (105 - shared.co2_2030) / 5"}
    2035: 105
    2036: {expr: "105 * (shared.co2_2040 / 105)^(1/5)"}
    2037: {expr: "105 * (shared.co2_2040 / 105)^(2/5)"}
    2038: {expr: "105 * (shared.co2_2040 / 105)^(3/5)"}
    2039: {expr: "105 * (shared.co2_2040 / 105)^(4/5)"}
    2040: {ref: shared.co2_2040}
    2041: {expr: "shared.co2_2040 * 1.03^1"}
    2042: {expr: "shared.co2_2040 * 1.03^2"}
    2043: {expr: "shared.co2_2040 * 1.03^3"}
    2044: {expr: "shared.co2_2040 * 1.03^4"}
    2045: {expr: "shared.co2_2040 * 1.03^5"}
    2046: {expr: "shared.co2_2040 * 1.03^6"}
    2047: {expr: "shared.co2_2040 * 1.03^7"}
    2048: {expr: "shared.co2_2040 * 1.03^8"}
    2049: {expr: "shared.co2_2040 * 1.03^9"}
    2050: {expr: "shared.co2_2040 * 1.03^10"}
    2051: {expr: "shared.co2_2040 * 1.03^11"}
    2052: {expr: "shared.co2_2040 * 1.03^12"}
    2053: {expr: "shared.co2_2040 * 1.03^13"}
    2054: {expr: "shared.co2_2040 * 1.03^14"}
    2055: {expr: "shared.co2_2040 * 1.03^15"}
    2056: {expr: "shared.co2_2040 * 1.03^16"}
    2057: {expr: "shared.co2_2040 * 1.03^17"}
    2058: {expr: "shared.co2_2040 * 1.03^18"}
    2059: {expr: "shared.co2_2040 * 1.03^19"}
    2060: {expr: "shared.co2_2040 * 1.03^20"}
    2061: {expr: "shared.co2_2040 * 1.03^21"}
    2062: {expr: "shared.co2_2040 * 1.03^22"}
    2063: {expr: "shared.co2_2040 * 1.03^23"}
    2064: {expr: "shared.co2_2040 * 1.03^24"}
    2065: {expr: "shared.co2_2040 * 1.03^25"}
    2066: {expr: "shared.co2_2040 * 1.03^26"}
    2067: {expr: "shared.co2_2040 * 1.03^27"}
    2068: {expr: "shared.co2_2040 * 1.03^28"}
    2069: {expr: "shared.co2_2040 * 1.03^29"}
    2070: {expr: "shared.co2_2040 * 1.03^30"}
  fill: locf                               # nach 2070 konstant
  before: first
notes: "Deterministisch (shared.co2_2030 = 80, shared.co2_2040 = 105 x 1,03^5 = 121,72377780): exakt Memo 07 (2026-2035 linear, danach +3 % p. a.; z. B. 2040: 121,72; 2050: 163,59; 2056: 195,33; 2066: 262,51). Overlay der Referenzszenarien: shared.co2_2030 ~ triangular(60; 90; 200), shared.co2_2040 ~ triangular(80; 150; 300), Rangkorrelation 0,8 (D). Zwischen 2030 und 2035 linear, zwischen 2035 und 2040 geometrisch interpoliert, ab 2040 +3 % p. a. vom gezogenen Wert."
```

```yaml
# inst/extdata/library/prices/interest_rates_2026_10.yaml
id: prices/interest_rates_2026_10
block: market
schema_version: 1
label: "Zinsniveaus Oktober 2026 (MFI-Zinsstatistik, Zinsstruktur, EZB, KfW)"
source: {document: "Deutsche Bundesbank BBIM1 (SUD101-SUD189), BBSIS, BBIN1; KfW-Konditionenanzeiger 22.10.2026", url: "https://api.statistiken.bundesbank.de/rest/data/", publisher: "Deutsche Bundesbank; KfW"}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-08-01
valid_to: null
quality: A
quality_detail: {market.mortgage_rate: A, rates.top_mortgage_10y_broker: C, rates.company_loan_long: D}
legal_state: {as_of: 2026-10-25, status: market, reference: "Marktdaten"}
values:
  market:
    mortgage_rate: 0.041                  # Default-Bauzins 10 J. (SUD119 08/2026: 4,04 %; Dr. Klein ab 4,16 %)
    bund_yield_10y: 0.034                 # Svensson 23.10.2026: 3,39 %
    mortgage_spread: 0.007
  rates:
    mortgage_10y_plus_effective: 0.0404   # SUD119 08/2026
    mortgage_5_10y: 0.0381
    mortgage_1_5y: 0.0403
    mortgage_variable: 0.0440
    mortgage_all_incl_costs: 0.0405       # SUD131
    top_mortgage_10y_broker: 0.0416       # C (13.10.2026)
    company_loan_long: 0.039              # D; SUD148 3,86 % (besichert 3,24 %)
    company_loan_5_10y: 0.0424
    overdraft_company: 0.0508
    overdraft_household: 0.0946
    deposit_overnight_household: 0.0051
    deposit_1y_household: 0.0228
    deposit_1_2y_household: 0.0264
    deposit_gt2y_household: 0.0272
    bund_10y_sep_avg: 0.0364
    bund_5y: 0.0336
    bund_1y: 0.0304
    ecb_deposit_facility: 0.0250          # seit 10.09.2026
  kfw_snapshot_2026_10_22:                # Sollzinsen (Effektivzins in den Fördereinträgen)
    kfw_261: {v10_2_10: 0.0301, v20_3_10: 0.0353, v30_5_10: 0.0365, b10_10_10: 0.0371}
    kfw_297_298_standard: {v10_2_10: 0.0194, v25_3_10: 0.0281, v35_5_10: 0.0294}
    kfw_297_298_eh55: {v10_2_10: 0.0100, v25_3_10: 0.0203, v35_5_10: 0.0219}
    kfw_300_308: {v10_2_10: 0.0001, v25_3_10: 0.0072, v35_5_10: 0.0100, b10_10_10: 0.0115}
    kfw_358: {v10_2_10: 0.0148, v25_3_10: 0.0253, v35_5_10: 0.0268}
    kfw_359: {v10_2_10: 0.0453, v25_3_10: 0.0462, v35_5_10: 0.0463}
    kfw_124: {v25_3_10: 0.0454, v35_5_10: 0.0456}
    kfw_159: {v20_3_10: 0.0388, v30_5_10: 0.0396}
  account_defaults_konzept_a2:            # Vorbelegung der Profile (# 01a), Konzept A2/F18
    wu: {deposit_rate_pa: 0.035, overdraft_rate_pa: 0.055, penalty_spread_pa: 0.02}
    genossenschaft: {deposit_rate_pa: 0.020, overdraft_rate_pa: 0.055, penalty_spread_pa: 0.02}
    privat: {deposit_rate_pa: 0.025, overdraft_rate_pa: 0.060, overdraft_limit_eur: 0}
notes: "KfW-Zinsen werden bei Zusage fixiert und ändern sich teils wöchentlich (Momentaufnahme)."
```

```yaml
# inst/extdata/library/prices/macro_paths_2026.yaml
id: prices/macro_paths_2026
block: market
schema_version: 1
label: "Deterministische Makropfade (Inflation, Baupreise, Instandhaltung, Mieten, Bodenwert, Betriebskosten)"
source: {document: "Destatis PM 364 (VPI 09/2026 +3,3 %); Bundesbank 06/2026; EZB 09/2026; Gemeinschaftsdiagnose Frühjahr 2026; Destatis Baupreise 08/2026 (Memo 03 §5)", url: "https://www.destatis.de/DE/Presse/Pressemitteilungen/2026/10/PD26_364_611.html", publisher: "Destatis; Deutsche Bundesbank; EZB"}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: B
quality_detail: {market.rent_growth_new: C, market.land_value_growth: D, market.operating_cost_growth: D}
legal_state: {as_of: 2026-10-25, status: market, reference: "Projektionen und Marktdaten"}
values:
  market:
    inflation: {series: {2026: 0.030, 2027: 0.026, 2028: 0.021, 2029: 0.020}, fill: locf, before: first}
    construction_price_index: {series: {2026: 0.050, 2027: 0.035, 2028: 0.0285, 2029: 0.0275}, fill: locf, before: first}   # langfristig VPI + 0,75 Pp
    maintenance_index: {series: {2026: 0.055, 2027: 0.040, 2028: 0.031, 2029: 0.030}, fill: locf, before: first}           # langfristig VPI + 1,0 Pp
    rent_growth: 0.0175                   # Bestand (0,5 / 1,75 / 3,0 %)
    rent_growth_new: 0.025                # Neuvertrag/Markt (0 / 2,5 / 5,0 %)
    land_value_growth: 0.015              # D (Memo 07 §4.0)
    market_value_growth: 0.015            # D
    operating_cost_growth: {ref: market.inflation, offset: 0.005}   # D
uncertainty:
  market.rent_growth: {dist: triangular, min: 0.005, mode: 0.0175, max: 0.030}
  market.rent_growth_new: {dist: triangular, min: 0.0, mode: 0.025, max: 0.050}
notes: "Referenzszenarien S1-S5 verwenden eigene Pfade (Memo 07 §4.0, 5.0)."
```

```yaml
# inst/extdata/library/prices/eeg_feed_in_2026.yaml
id: prices/eeg_feed_in_2026
block: market
schema_version: 1
label: "EEG-Einspeisevergütung (Inbetriebnahme 01.08.2026 bis 31.01.2027)"
source: {document: "DGS-Arbeitshilfe EEG-Vergütungssätze 01.08.2026; EEG-Novelle (Kabinett 29.07.2026, Sek.)", url: "https://www.dgs.de/wp-content/uploads/2026/08/260801_dgs_arbeitshilfe_eeg_verguetungssaetze.pdf", publisher: "DGS"}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-08-01
valid_to: 2027-02-01
quality: C
legal_state: {as_of: 2026-08-01, status: in_force, reference: "EEG 2023 §§ 48, 49; Reform 2027 anhängig (Wegfall fester Vergütung < 25 kWp)"}
values:
  market:
    feed_in_tariff:                        # EUR/kWh, fest 20 Jahre ab Inbetriebnahme
      partial_le10kwp: 0.0770
      partial_10_40kwp: 0.0666
      partial_40_100kwp: 0.0545             # D: 5,74 ct (02/2024) x 0,99^5 (Degression), Prüfpunkt; 01b 7.4
      full_le10kwp: 0.1222
  degression_per_half_year: 0.01           # Memo 07 §4.0 (C)
  fixed_years: 20
notes: "Mischsatz S3 (30 kWp): (10 x 7,70 + 20 x 6,66)/30 = 7,0067 ct/kWh; Einspeisung 18.900 kWh -> 1.324,26 EUR/a (S3-T6). Unsicherheit Neuanlagen ab 2027: processes/funding_risks_2026 (use: feed_in_continuation)."
```

### 3.7 Kosten (`costs/**`)

```yaml
# inst/extdata/library/costs/bewirtschaftung_ii_bv_2026.yaml
id: costs/bewirtschaftung_ii_bv_2026
block: costs
schema_version: 1
label: "II. Berechnungsverordnung: Pauschalen ab 01.01.2026 (Kostenmiete)"
source: {document: "VdW Bayern, II. BV Anpassung der Pauschalen zum 01.01.2026 (VPI Okt. 2025 123,0 / Okt. 2022 113,5 = +8,37 %)", url: "https://www.vdwbayern.de/wp-content/uploads/2025/11/VdW_Zweite-Berechnungsverordnung_Pauschalen_2026_fin.pdf", publisher: "VdW Bayern"}
references:
  - {document: "Haus & Grund Düsseldorf / Haufe (Bestätigung, Sek.)", url: "https://www.haufe.de/immobilien/", publisher: Haufe}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: 2029-01-01                       # nächste Anpassung 01.01.2029
quality: B                                 # Förderbank-Merkblatt; amtliche Bekanntmachung nicht eingesehen (Konzept §3.6)
legal_state: {as_of: 2026-01-01, status: in_force, reference: "II. BV §§ 26, 28, 29"}
values:
  admin_per_unit_eur_pa: 372.46
  admin_per_garage_eur_pa: 48.58
  maintenance_eur_m2_pa: {lt22y: 11.50, ge22y: 14.58, ge32y: 18.62}   # nach Bezugsfertigkeit
  maintenance_adjustments_eur_m2_pa: {commercial_heat_supply: -0.31, elevator: 1.63, small_repairs_by_tenant: -1.70}
  cosmetic_repairs_by_landlord_eur_m2_pa: 13.75   # Haufe: 13,76
  maintenance_per_garage_eur_pa: 110.13           # Haufe: 110,11
  rent_loss_risk_share: 0.02
  indexation: {index: vpi, every_years: 3, next: 2029-01-01}
```

```yaml
# inst/extdata/library/costs/bewirtschaftung_immowertv_2026.yaml
id: costs/bewirtschaftung_immowertv_2026
block: costs
schema_version: 1
label: "ImmoWertV Anlage 3: Modellansätze Bewirtschaftungskosten 2026"
source: {document: "Oberer Gutachterausschuss Brandenburg, Bewirtschaftungskosten 2022-2026 (BewKo 2026)", url: "https://gutachterausschuss.brandenburg.de/sixcms/media.php/9/BewKo_2026.pdf", publisher: "OGA Brandenburg"}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: 2027-01-01                       # jährliche Fortschreibung (Januar)
quality: B
legal_state: {as_of: 2026-01-01, status: in_force, reference: "ImmoWertV 2021 Anlage 3, fortgeschrieben mit VPI (Basis 2021)"}
values:
  admin_per_unit_or_efh_eur_pa: 367
  admin_per_condo_eur_pa: 439
  admin_per_garage_eur_pa: 48
  maintenance_eur_m2_pa: 14.4              # Mieter trägt Schönheitsreparaturen; keine Baualtersstaffel
  maintenance_per_garage_eur_pa: 108
  rent_loss_risk_share: {residential: 0.02, commercial: 0.04}
  admin_commercial_share_of_gross_rent: 0.03
  history: {admin_per_unit_eur_pa: {2022: 312, 2023: 339, 2024: 351, 2025: 359, 2026: 367}, maintenance_eur_m2_pa: {2022: 12.2, 2023: 13.2, 2024: 13.8, 2025: 14.0, 2026: 14.4}}
  indexation: {index: vpi, every_years: 1}
```

```yaml
# inst/extdata/library/costs/betriebskosten_benchmarks_2026.yaml
id: costs/betriebskosten_benchmarks_2026
block: costs
schema_version: 1
label: "Betriebskosten-Benchmarks und nicht umlagefähige Kosten"
source: {document: "Deutscher Mieterbund, Betriebskostenspiegel (Abrechnungsjahr 2024); GdW Daten und Trends 2025/26 (Memo 03 §8.3)", url: "https://mieterbund.de/aktuelles/meldungen/mieterbund-veroeffentlicht-aktuellen-betriebskostenspiegel-fuer-deutschland/", publisher: "DMB; GdW"}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: C
quality_detail: {opex_nonrecoverable_share: D, maintenance_selfuser_share_of_construction_cost_pa: D, vacancy_operating_cost_eur_m2_month: D}
legal_state: {as_of: 2026-10-25, status: market, reference: "Benchmarks"}
values:
  operating_cost_total_eur_m2_month: 2.67          # DMB 2024; alle Arten bis 3,68
  heating_dhw_eur_m2_month: {mean: 1.32, min: 0.46, max: 2.18}
  cold_gdw_eur_m2_month: 1.90
  warm_gdw_eur_m2_month: 1.64
  space_heating_cost_mfh_2025_eur_m2_pa: {heatpump: 8.80, pellets: 9.36, oil: 12.97, gas: 13.92, district_heating: 16.02}   # Techem (C)
  opex_nonrecoverable_share: 0.01                   # Anteil Nettokaltmiete (0,5-2,5 %)
  maintenance_selfuser_share_of_construction_cost_pa: 0.012   # (0,8-1,8 %)
  vacancy_operating_cost_eur_m2_month: 2.50         # Memo 07 S1 (Leerstands-BK)
  belwertv_min_management_cost_share: 0.15
uncertainty:
  opex_nonrecoverable_share: {dist: triangular, min: 0.005, mode: 0.01, max: 0.025}
  maintenance_selfuser_share_of_construction_cost_pa: {dist: triangular, min: 0.008, mode: 0.012, max: 0.018}
```

```yaml
# inst/extdata/library/costs/baukosten_neubau_2026.yaml
id: costs/baukosten_neubau_2026
block: costs
schema_version: 1
label: "Kostenkennwerte Neubau 2026 (brutto, je m2 Wohnfläche)"
source: {document: "ARGE e. V., Wohnungsbau in Deutschland 2026 (März 2026), Median Großstädte Q4/2025; Fortschreibung +4 % (Memo 03 §6.1)", url: "https://mieterbund.de/app/uploads/2026/03/studie_zum_wohnungsbau_2026.pdf", publisher: "ARGE e. V."}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: B
quality_detail: {cost_newbuild_efh_kg300_400_eur_m2: D, surcharge_eh40_vs_minimum_share: D, share_kg200_500_600_of_kg300_400: D}
legal_state: {as_of: 2026-03-01, status: market, reference: "Marktdaten"}
values:
  cost_newbuild_mfh_kg300_400_eur_m2: 3750         # Median im Intervall 3.500-3.750
  cost_newbuild_mfh_kg200_700_eur_m2: 4800         # Median 4.631,07 (+3,5 %)
  cost_newbuild_mfh_full_incl_land_eur_m2: 5400    # informativ
  cost_newbuild_efh_kg300_400_eur_m2: 3000
  share_kg200_500_600_of_kg300_400: 0.06
  surcharge_eh40_vs_minimum_share: 0.05            # EH 40 ggü. GModG-Mindeststandard (≈ EH 55)
uncertainty:
  cost_newbuild_mfh_kg300_400_eur_m2: {dist: triangular, min: 3000, mode: 3750, max: 5000}
  cost_newbuild_mfh_kg200_700_eur_m2: {dist: triangular, min: 3300, mode: 4800, max: 8600}
  cost_newbuild_efh_kg300_400_eur_m2: {dist: triangular, min: 2300, mode: 3000, max: 4000}
  surcharge_eh40_vs_minimum_share: {dist: triangular, min: 0.03, mode: 0.05, max: 0.08}
```

```yaml
# inst/extdata/library/costs/kostenzuschlaege_2026.yaml
id: costs/kostenzuschlaege_2026
block: costs
schema_version: 1
label: "Baunebenkosten (KG 700) und Risikozuschlag Unvorhergesehenes"
source: {document: "Memo 03 §6.1 (KG 700 20 %), Memo 02 §1.2 (18 %; Unvorhergesehenes 10 %); Konzept F19", url: "docs/Konzept.md", publisher: "eigene Ableitung"}
as_of: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
legal_state: {as_of: 2026-10-25, status: derived, reference: "Konzept F19"}
values:
  share_kg700_of_kg300_400: 0.20
  contingency_share: 0.10                          # auf Bau + KG 700; Kostenüberschreitungsfaktor wirkt zusätzlich (Konzept §3.2)
uncertainty:
  share_kg700_of_kg300_400: {dist: triangular, min: 0.15, mode: 0.20, max: 0.25}
notes: "Ist der Risikozuschlag stochastisch und zugleich ein Kostenüberschreitungsfaktor gesetzt, warnt die Validierung (cost_risk_double)."
```

```yaml
# inst/extdata/library/costs/kostenfunktionen_sanierung_iwu_2026.yaml
id: costs/kostenfunktionen_sanierung_iwu_2026
block: costs
schema_version: 1
label: "IWU-Kostenfunktionen Sanierung, Preisstand 2023 x 1,12 = 2026 (brutto)"
source: {document: "IWU (Müller, Fiedler, Koch), Working Paper Anpassung der Kostenfunktionen 2022/2023 (08.08.2024); Fortschreibung 2023->2026 Faktor 1,12 (Memo 03 §6.2-6.5)", url: "https://iwu.de/fileadmin/publikationen/energie/2024_IWU_MuellerEtAl_WorkingPaper-Anpassung-Kostenfunktionen-2022-2023.pdf", publisher: IWU}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: B
quality_detail: {index_factor_2023_to_2026: D, windows.full_cost_triple_glazing_eur_m2: D, ohnehin_share: D}
legal_state: {as_of: 2024-08-08, status: market, reference: "Kostenfunktionen nach Hinz 2015, fortgeschrieben"}
values:
  index_factor_2023_to_2026: 1.12                 # bereits in den Koeffizienten unten enthalten
  envelope_eur_m2_component: {formula: "a + b * x_cm"}   # x = Dämmstoffdicke in cm
  envelope:
    etics_full:                     {a: 169.6, b: 4.92}   # x = 16: 248,3
    etics_energy_related:           {a: 36.2,  b: 5.15}   # x = 16: 118,6
    cavity_insulation:              {a: 18.7,  b: 2.98}
    basement_ceiling_no_cladding:   {a: 55.1,  b: 2.24}   # x = 10: 77,5
    basement_ceiling_with_cladding: {a: 97.3,  b: 2.78}
    basement_ceiling_top_side:      {a: 16.2,  b: 2.93}
    pitched_roof_full:              {a: 291.8, b: 5.35}   # x = 20: 398,8
    pitched_roof_energy_related:    {a: 21.9,  b: 4.59}
    pitched_roof_retrofit_only:     {a: 63.3,  b: 4.49}
    flat_roof_full:                 {a: 199.9, b: 7.88}   # x = 20: 357,5
    flat_roof_energy_related:       {a: 41.6,  b: 5.58}
    top_ceiling_walkable:           {a: 52.3,  b: 3.33}   # x = 20: 118,9
    top_ceiling_not_walkable:       {a: 6.9,   b: 1.98}
  windows:
    full_cost_triple_glazing_eur_m2: 850          # D (Marktpreis 2026, nicht in IWU)
    extra_cost_2wsv_to_3wsv_mfh: {a: 112.9, exponent: -0.255}   # EUR/m2 Fensterfläche, x = m2/Stück; F = 1,5 -> 102
    extra_cost_2wsv_to_3wsv_efh: {a: 103.2, exponent: -0.191}
    extra_cost_2wsv_to_passive_mfh: {a: 402.2, exponent: -0.136}
  doors_eur_m2: {mfh: 2237, efh: 2623}
  systems_eur_m2_an: {formula: "a * A_N^exponent"}   # A_N Gebäudenutzfläche (ca. 1,2-1,35 x Wfl.); Gesamtkosten = spez. Kosten x A_N
  systems:
    gas_condensing_boiler:           {a: 1734.7, exponent: -0.518}   # EFH A_N 180: ca. 21.200; MFH 1.300: ca. 55.000
    district_heating_substation:     {a: 1270.3, exponent: -0.487}
    district_heating_connection:     {a: 1024.7, exponent: -0.614}
    gas_connection:                  {a: 299.1,  exponent: -0.49}
    pellet_boiler:                   {a: 4850.9, exponent: -0.587}
    oil_boiler:                      {a: 2304.5, exponent: -0.536}
    heating_distribution:            {a: 1277.6, exponent: -0.533}
    ventilation_central_hr:          {a: 693.9,  exponent: -0.364}
    ventilation_decentral_hr:        {a: 1510.8, exponent: -0.652}
    exhaust_ventilation:             {a: 1936.3, exponent: -0.78}
    solar_thermal_dhw_with_new_boiler: {a: 2095.9, exponent: -0.489}
    architect_fees:                  {a: 1337.8, exponent: -0.599}
    energy_advice:                   {a: 26.7,   exponent: -0.339}
  ohnehin_share:                                   # Instandsetzungsanteil an Vollkosten bei fälliger Erneuerung
    etics: 0.50
    pitched_roof: 0.70
    flat_roof: 0.57
    windows: 0.85
    basement_ceiling: 0.0
    top_ceiling: 0.0
    cavity_insulation: 0.0
    ventilation: 0.0
    heating_replacement: reference_system_cost     # Ohnehin = Kosten der Referenzanlage (Gas-Brennwert)
    rule: "nur bei Restnutzungsdauer <= 5 Jahre voll, sonst anteilig nach Restwert (linear)"
uncertainty:
  index_factor_2023_to_2026: {dist: triangular, min: 1.09, mode: 1.12, max: 1.16}
  windows.full_cost_triple_glazing_eur_m2: {dist: triangular, min: 600, mode: 850, max: 1300}
  ohnehin_share.etics: {dist: triangular, min: 0.40, mode: 0.50, max: 0.65}
  ohnehin_share.pitched_roof: {dist: triangular, min: 0.60, mode: 0.70, max: 0.80}
  ohnehin_share.flat_roof: {dist: triangular, min: 0.45, mode: 0.57, max: 0.65}
  ohnehin_share.windows: {dist: triangular, min: 0.75, mode: 0.85, max: 0.90}
notes: "Prüfwerte: WDVS 16 cm 169,6 + 4,92 x 16 = 248,32 EUR/m2 (energiebedingt 118,60; Ohnehin-Anteil 0,52); Steildach 20 cm 398,80 / 113,70; Kellerdecke 10 cm 77,50; Gas-BW MFH A_N 1.300: 1.734,7 x 1300^-0,518 x 1300 = 55.0 TEUR (gerundet). Basis: Abrechnungen bis 2015, nur indexiert (Memo 03 §15)."
```

```yaml
# inst/extdata/library/costs/anlagentechnik_marktpreise_2026.yaml
id: costs/anlagentechnik_marktpreise_2026
block: costs
schema_version: 1
label: "Marktpreise Anlagentechnik 2026: Wärmepumpen, PV, Speicher (brutto)"
source: {document: "VZ RLP Angebotsauswertung 10/2024-05/2025, Aroundhome 04/2026, 42watt 03/2026, Fraunhofer ISE (über 42watt) (Memo 03 §6.3)", url: "https://www.aroundhome.de/heizung/waermepumpe/preise-kosten", publisher: "div. (Sek.)"}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: C
quality_detail: {cost_hp_mfh_per_kw_eur: D, cost_borehole_per_m_eur: D, cost_pv_mfh_per_kwp_net_eur: D, cost_battery_per_kwh_eur: D, cost_inverter_replacement_per_kwp_eur: D, pv_specific_yield_kwh_kwp: D}
legal_state: {as_of: 2026-10-25, status: market, reference: "Marktdaten (Sek.)"}
values:
  cost_hp_air_water_efh_eur: 32000           # inkl. Installation
  cost_hp_brine_water_efh_eur: 45000         # inkl. Erdsonden
  cost_borehole_per_m_eur: 110
  cost_hp_mfh_per_kw_eur: 1800               # Kaskade inkl. Hydraulik je kW_th
  cost_pv_small_per_kwp_eur: 1350            # <= 30 kWp, USt 0 %
  cost_pv_mfh_per_kwp_net_eur: 1100          # 30-100 kWp, netto
  cost_battery_per_kwh_eur: 550
  cost_inverter_replacement_per_kwp_eur: 150
  pv_specific_yield_kwh_kwp: 950
uncertainty:
  cost_hp_air_water_efh_eur: {dist: triangular, min: 22000, mode: 32000, max: 50000}
  cost_hp_brine_water_efh_eur: {dist: triangular, min: 35000, mode: 45000, max: 60000}
  cost_hp_mfh_per_kw_eur: {dist: triangular, min: 1200, mode: 1800, max: 2800}
  cost_pv_small_per_kwp_eur: {dist: triangular, min: 1000, mode: 1350, max: 1800}
  cost_battery_per_kwh_eur: {dist: triangular, min: 300, mode: 550, max: 800}
  pv_specific_yield_kwh_kwp: {dist: triangular, min: 800, mode: 950, max: 1100}
```

```yaml
# inst/extdata/library/costs/sanierung_eh_pakete_2026.yaml
id: costs/sanierung_eh_pakete_2026
block: costs
schema_version: 1
label: "Komplettsanierung auf Effizienzhaus-Niveau (top-down, nur Plausibilisierung)"
source: {document: "Ariadne (Sek.), Ratgeber 2026, GdW (Memo 03 §6.4)", url: "docs/recherche/03_parameter_defaults.md", publisher: "div. (Sek.)"}
as_of: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
legal_state: {as_of: 2026-10-25, status: market, reference: "Plausibilitätswerte"}
values:                                       # EUR/m2 Wohnfläche brutto inkl. KG 700, ohne Förderung
  eh85: {cost_eur_m2: 750,  ohnehin_share: 0.40}
  eh70: {cost_eur_m2: 1050, ohnehin_share: 0.40}
  eh55: {cost_eur_m2: 1350, ohnehin_share: 0.35}
uncertainty:
  eh85.cost_eur_m2: {dist: triangular, min: 500, mode: 750, max: 1100}
  eh70.cost_eur_m2: {dist: triangular, min: 750, mode: 1050, max: 1500}
  eh55.cost_eur_m2: {dist: triangular, min: 950, mode: 1350, max: 1900}
notes: "Plausibilitätsprüfung (W): Bottom-up-Kosten einer EH-Sanierung außerhalb [min, max]. Prüfwert S1 V2: 907 EUR/m2 in [750; 1.500] für EH 70."
```

```yaml
# inst/extdata/library/costs/nutzungsdauern_2026.yaml
id: costs/nutzungsdauern_2026
block: costs
schema_version: 1
label: "Nutzungsdauern von Bauteilen und Anlagen (Jahre)"
source: {document: "VDI 2067-1 (über TUM/Immowelt, Sek.), BBSR/BNB Nutzungsdauern 2017 (Original nicht abrufbar), ImmoWertV 2021 Anlage 1 (Memo 03 §9; Konzept F19)", url: "https://www.nachhaltigesbauen.de/", publisher: "VDI; BBSR"}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
quality_detail: {hp_air_water: C, hp_brine_water: C, gas_boiler: C, building_total_immowertv: B}
legal_state: {as_of: 2026-10-25, status: market, reference: "Richtwerte; Abgleich mit Originaltabellen ausstehend"}
values:
  hp_air_water: 18
  hp_brine_water: 20
  borehole: 50
  gas_boiler: 18                              # Memo 02: 20 (F19)
  pellet_boiler: 20
  district_heating_substation: 25
  solar_thermal: 20                           # Memo 02
  etics: 40
  plaster_paint: 15                           # Memo 02
  windows: 40                                 # Holz-Alu/Alu 50; Memo 02: 35/45 (F19)
  windows_wood_alu: 50
  roof_pitched_covering: 50
  roof_flat_sealing: 30                       # Memo 02: 25 (F19)
  insulation_roof_ceiling: 50
  pv_modules: 25
  pv_inverter: 12                             # Memo 02: 13 (F19)
  battery: 12
  ventilation_central: 20
  ventilation_decentral: 15
  heating_distribution: 40                    # Memo 02: Heizkörper 30, Flächenheizung 50 (F19)
  dhw_storage: 20                             # Memo 02
  pipes: 40                                   # Memo 02
  elevator: 25                                # Memo 02
  bathrooms: 25                               # Memo 02
  electrical: 40                              # Memo 02
  building_total_immowertv: 80
uncertainty:                                  # Overlay-Vorlagen für measures.<id>.useful_life_years
  hp_air_water: {dist: triangular, min: 15, mode: 18, max: 22}
  hp_brine_water: {dist: triangular, min: 17, mode: 20, max: 25}
  borehole: {dist: triangular, min: 40, mode: 50, max: 60}
  gas_boiler: {dist: triangular, min: 15, mode: 18, max: 25}
  pellet_boiler: {dist: triangular, min: 15, mode: 20, max: 25}
  district_heating_substation: {dist: triangular, min: 20, mode: 25, max: 30}
  etics: {dist: triangular, min: 30, mode: 40, max: 50}
  windows: {dist: triangular, min: 30, mode: 40, max: 50}
  roof_pitched_covering: {dist: triangular, min: 40, mode: 50, max: 70}
  roof_flat_sealing: {dist: triangular, min: 20, mode: 30, max: 35}
  insulation_roof_ceiling: {dist: triangular, min: 40, mode: 50, max: 60}
  pv_modules: {dist: triangular, min: 20, mode: 25, max: 30}
  pv_inverter: {dist: triangular, min: 10, mode: 12, max: 15}
  battery: {dist: triangular, min: 10, mode: 12, max: 15}
  ventilation_central: {dist: triangular, min: 15, mode: 20, max: 25}
  ventilation_decentral: {dist: triangular, min: 12, mode: 15, max: 20}
  heating_distribution: {dist: triangular, min: 30, mode: 40, max: 50}
notes: "Memo 04 nennt für die WP PERT(12; 18; 25); Default hier Dreieck nach Memo 03. Prüfwert Dreieck(15; 18; 22): Mittel 18,333, q10 16,449, q90 20,327. Nutzungsdauern werden auf ganze Monate gerundet (Spec 00 §3.9)."
```

```yaml
# inst/extdata/library/costs/wartung_instandsetzung_vdi2067_2026.yaml
id: costs/wartung_instandsetzung_vdi2067_2026
block: costs
schema_version: 1
label: "Instandsetzung und Wartung in % der Investition p. a. (VDI-2067-Größenordnung)"
source: {document: "VDI 2067-1:2012 (Größenordnung, Originaltabelle nicht eingesehen) (Memo 03 §9)", url: "https://www.vdi.de/richtlinien", publisher: VDI}
as_of: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
legal_state: {as_of: 2026-10-25, status: market, reference: "vor Freigabe gegen VDI 2067-1 prüfen"}
values:
  heat_pump: {repair: 0.010, service: 0.015}
  gas_boiler: {repair: 0.010, service: 0.020}
  pellet_boiler: {repair: 0.020, service: 0.030}
  ventilation: {repair: 0.015, service: 0.020}
  pv_system: {total: 0.012}                   # Memo 07 S3: 1,5 %
  district_heating_substation: {repair: 0.010, service: 0.010}
```

```yaml
# inst/extdata/library/costs/erwerbsnebenkosten_2026.yaml
id: costs/erwerbsnebenkosten_2026
block: costs
schema_version: 1
label: "Erwerbsnebenkosten (ohne Grunderwerbsteuer)"
source: {document: "Kaufnebenkostenrechner 2026 (GNotKG-basiert, Sek.) (Memo 03 §10.4)", url: "https://baufivergleich.de/kaufnebenkosten-rechner/", publisher: "baufivergleich.de"}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: C
quality_detail: {cost_due_diligence_share: D}
legal_state: {as_of: 2026-10-25, status: market, reference: "Marktdaten; Maklerhalbteilung § 656c BGB nur EFH/ETW an Verbraucher"}
values:
  cost_notary_land_registry_share: 0.015
  cost_broker_buyer_share: 0.0357
  cost_due_diligence_share: 0.005
uncertainty:
  cost_notary_land_registry_share: {dist: triangular, min: 0.011, mode: 0.015, max: 0.020}
  cost_broker_buyer_share: {dist: triangular, min: 0.0, mode: 0.0357, max: 0.0714}
  cost_due_diligence_share: {dist: triangular, min: 0.002, mode: 0.005, max: 0.010}
```

### 3.8 Bewertung (`valuation/**`)

```yaml
# inst/extdata/library/valuation/liegenschaftszinsen_2026.yaml
id: valuation/liegenschaftszinsen_2026
block: valuation
schema_version: 1
label: "Liegenschaftszinssätze Wohnen (Lage-Presets)"
source: {document: "OGA Brandenburg Liegenschaftszinssätze 2025 (Kauffälle 2023-2025); BewG §§ 188, 256; vdp Q4/2025 (Memo 03 §10.1)", url: "https://gutachterausschuss.brandenburg.de/sixcms/media.php/9/LIZI_2025_OGA.pdf", publisher: "OGA Brandenburg; BMJ; vdp"}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
quality_detail: {references.brandenburg_2023_2025: B, references.bewg_188_rental: C, references.bewg_256: C}
legal_state: {as_of: 2026-04-01, status: market, reference: "Grundstücksmarktberichte; regionale Werte des Gutachterausschusses vorrangig"}
values:
  presets: {a_metropolis: 0.025, large_city: 0.030, mid_city: 0.035, rural_shrinking: 0.045}
  default_preset: mid_city                    # Konzept B10: generisch Mittelstadt
  references:
    brandenburg_2023_2025: {berliner_umland: 0.032, weiterer_metropolenraum: 0.035, kreisfreie_staedte: 0.028}
    bewg_188_rental: 0.035
    bewg_256: {efh_zfh: 0.025, condo: 0.030, rental_le6_units: 0.040, rental_gt6_units: 0.045}
    germany_mfh_2018: 0.0326                  # Memo 02 §7.1 (Sek.)
uncertainty:
  presets.a_metropolis: {dist: triangular, min: 0.015, mode: 0.025, max: 0.035}
  presets.large_city: {dist: triangular, min: 0.022, mode: 0.030, max: 0.040}
  presets.mid_city: {dist: triangular, min: 0.025, mode: 0.035, max: 0.045}
  presets.rural_shrinking: {dist: triangular, min: 0.035, mode: 0.045, max: 0.065}
```

```yaml
# inst/extdata/library/valuation/immowertv_anlage1_2_2026.yaml
id: valuation/immowertv_anlage1_2_2026
block: valuation
schema_version: 1
label: "ImmoWertV 2021 Anlage 1 (Gesamtnutzungsdauer) und Anlage 2 (Restnutzungsdauer bei Modernisierung)"
source: {document: "ImmoWertV 2021 Anlagen 1 und 2 (Text am Stichtag nicht abrufbar, HTTP 503; Memo 02 §7.1, Memo 03 §9)", url: "https://www.gesetze-im-internet.de/immowertv_2022/", publisher: BMJ}
as_of: 2026-10-25
accessed: 2026-10-25
valid_from: 2022-01-01
valid_to: null
quality: B
quality_detail: {rnd_coefficients.p1: D, rnd_coefficients.p2: D, rnd_coefficients.p3: D, rnd_coefficients.p4: D, rnd_coefficients.p5: D, rnd_coefficients.p6: D, rnd_coefficients.p7: D, rnd_coefficients.p9: D, rnd_coefficients.p10: D, rnd_coefficients.p11: D, rnd_coefficients.p13: D, rnd_coefficients.p14: D, rnd_coefficients.p15: D, rnd_coefficients.p16: D, rnd_coefficients.p17: D}
legal_state: {as_of: 2022-01-01, status: in_force, reference: "ImmoWertV vom 14.07.2021, Anlagen 1-2"}
values:
  gnd_years: {efh: 80, zfh: 80, mfh: 80}
  modernisation_points_max: {roof_insulation: 4, windows_doors: 2, pipes: 2, heating: 2, facade_insulation: 4, bathrooms: 2, interior: 2, floor_plan: 2}   # Summe 20
  rnd_formula: "RND = a * Alter^2 / GND - b * Alter + c * GND, falls Alter/GND >= rel_age_min; sonst RND = GND - Alter"
  rnd_coefficients:                           # Punkte -> a, b, c, rel_age_min; Zeilen p0, p8, p12, p18-p20 aus Memo 02 (B), übrige aus Fachkenntnis (D, am Text prüfen)
    p0:  {a: 1.2500, b: 2.6250, c: 1.5250, rel_age_min: 0.60}
    p1:  {a: 1.2500, b: 2.6250, c: 1.5250, rel_age_min: 0.60}
    p2:  {a: 1.0767, b: 2.2757, c: 1.3878, rel_age_min: 0.55}
    p3:  {a: 0.9033, b: 1.9263, c: 1.2505, rel_age_min: 0.55}
    p4:  {a: 0.7300, b: 1.5770, c: 1.1133, rel_age_min: 0.40}
    p5:  {a: 0.6725, b: 1.4578, c: 1.0850, rel_age_min: 0.35}
    p6:  {a: 0.6150, b: 1.3385, c: 1.0567, rel_age_min: 0.30}
    p7:  {a: 0.5575, b: 1.2193, c: 1.0283, rel_age_min: 0.25}
    p8:  {a: 0.5000, b: 1.1000, c: 1.0000, rel_age_min: 0.20}
    p9:  {a: 0.4660, b: 1.0270, c: 0.9906, rel_age_min: 0.19}
    p10: {a: 0.4320, b: 0.9540, c: 0.9811, rel_age_min: 0.18}
    p11: {a: 0.3980, b: 0.8810, c: 0.9717, rel_age_min: 0.17}
    p12: {a: 0.3640, b: 0.8080, c: 0.9622, rel_age_min: 0.16}
    p13: {a: 0.3300, b: 0.7350, c: 0.9528, rel_age_min: 0.15}
    p14: {a: 0.3040, b: 0.6760, c: 0.9506, rel_age_min: 0.14}
    p15: {a: 0.2780, b: 0.6170, c: 0.9485, rel_age_min: 0.13}
    p16: {a: 0.2520, b: 0.5580, c: 0.9463, rel_age_min: 0.12}
    p17: {a: 0.2260, b: 0.4990, c: 0.9442, rel_age_min: 0.11}
    p18: {a: 0.2000, b: 0.4400, c: 0.9420, rel_age_min: 0.10}
    p19: {a: 0.2000, b: 0.4400, c: 0.9420, rel_age_min: 0.10}
    p20: {a: 0.2000, b: 0.4400, c: 0.9420, rel_age_min: 0.10}
  core_renovation_rnd_max_share_of_gnd: 0.90
notes: "Prüfwerte (Memo 02 §7.1): Baujahr 1970, Stichtag 2026 (Alter 56), GND 80: 0 Punkte -> RND 24,0; 8 -> 38,0; 12 -> 46,0 (45,9968); 18 -> 58,56. Rechenbeispiel 7: RE 60.338 EUR, BW 200.000, LZ 3 %, RND 50 -> KF 25,7298, EW ca. 1.598.100 EUR."
```

```yaml
# inst/extdata/library/valuation/verkaufskosten_2026.yaml
id: valuation/verkaufskosten_2026
block: valuation
schema_version: 1
label: "Verkaufskosten am Horizont"
source: {document: "Memo 03 §10.4 (D), Memo 02 §7.5 (Makler 0-3,57 %, sonstige 0,1-0,5 %), Konzept §3.11 (Default 3 %)", url: "docs/Konzept.md", publisher: "eigene Ableitung"}
as_of: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
legal_state: {as_of: 2026-10-25, status: derived, reference: "Konzept §3.11, A3"}
values:
  sale_cost_share: 0.03                       # Default residual_value.sale_cost_share (Spec 00 §4.3.12)
  components: {broker_seller_share: [0.0, 0.0357], other_share: [0.001, 0.005]}
uncertainty:
  sale_cost_share: {dist: triangular, min: 0.0, mode: 0.03, max: 0.05}
notes: "Keine Vorfälligkeitsentschädigung am Horizont (Konzept §10.3)."
```

```yaml
# inst/extdata/library/valuation/kaufpreisfaktoren_2026.yaml
id: valuation/kaufpreisfaktoren_2026
block: valuation
schema_version: 1
label: "Kaufpreisfaktoren (Rohertragsvervielfältiger)"
source: {document: "OGA Brandenburg (Berliner Umland Ø 20,7) und Marktberichte (Memo 03 §10.2; Memo 02 §7.2)", url: "https://gutachterausschuss.brandenburg.de/", publisher: "OGA Brandenburg; eigene Ableitung"}
as_of: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
legal_state: {as_of: 2026-10-25, status: market, reference: "Lage-Presets"}
values:
  gross_rent_multiplier: 20                   # Konzept §3.11 (Vervielfältiger Default 20)
  presets: {a: [25, 32], b: [18, 25], c: [14, 20], d_east_shrinking: [10, 15]}
uncertainty:
  gross_rent_multiplier: {dist: triangular, min: 12, mode: 20, max: 30}
```

---

## 4. Szenario-Sets und Pflichtsensitivitäten

### 4.1 Feldkatalog `scenario_sets.<id>` (Konkretisierung Spec 00 §4.11)

Ein Szenario-Set ist entweder **statisch** (Operationen `set`/`replace`/`add`/`remove`/`overrides`; eigener
Planungsfall mit eigenem Basisfall-Vorlauf, `auto`-Beträge neu bestimmt) oder **generiert** (`generate`; Risikofall
auf dem Basismodell, eine Designzeile, Basisfallgrößen fest, R-69, R-74). Beides zugleich ist E.

| YAML-Pfad | Typ | Einheit | Default | Pflicht | Validierung | Bedeutung | Quelle/Memo-Ref |
|---|---|---|---|---|---|---|---|
| `scenario_sets.<id>` | map | – | – | – | E: id `^[a-z][a-z0-9_]*$`, nicht `base`; E: id auch Varianten-id | Set (Schicht 7, nach der Variante) | Spec 00 §4.11 |
| `….label` | chr (de) | – | – | ja | – | Anzeigename | Spec 00 §2.10 |
| `….description` | chr (de) | – | `null` | nein | – | Erläuterung im Bericht (Szenariotabelle) | – |
| `….set`, `….replace`, `….add`, `….remove`, `….overrides` | wie Varianten | – | – | bedingt (mind. eine Operation oder `generate`) | E: Pfade nur unter `market`, `funding`, `accounts`, `residual_value`, `stochastic`, `tax`, `project.pending_reforms`; E: höchstens ein Segment `*` je Pfad; E: Existenz je Treffer; I: Wildcard ohne Treffer | Operationen (Reihenfolge wie Varianten: `remove` → `replace` → `set` → `overrides` → `add`) | Spec 00 §4.11, R-71 |
| `….generate` | map | – | `null` | nein | E: zusammen mit Operationen | generiertes Set | Spec 00 §4.11, R-74 |
| `….generate.method` | enum:`cautious` | – | `cautious` | ja (in `generate`) | E: anderer Code (v1) | „ungünstige Werte der stärksten Treiber“ | Konzept B5 |
| `….generate.n_drivers` | int | – | `5` | nein | E: ≥ 1 | Anzahl der Treiber | Konzept 1.4 |
| `….generate.probs` | num[2] | 1 | `[0.1, 0.9]` | nein | E: 0 < p_lo < 0,5 < p_hi < 1 | Tornado-Grenzen (P10/P90) | Spec 00 §11.11 |
| `….generate.kpi` | chr | – | `auto` | nein | E: skalare Kennzahl des Modells oder `auto` (= Primärkennzahl, Spec 00 §12.3a) | Bewertungskennzahl des Tornados | Spec 00 §4.11 |
| `….generate.params` | chr[] \| `auto` | – | `auto` | nein | E: Designziele nach Spec 00 §11.11 | Kandidaten; `auto` = 4.3 Nr. 1 | 4.3 |
| `….generate.exclude` | chr[] | – | `[]` | nein | E: Kandidat existiert | ausgeschlossene Kandidaten (z. B. `funding.*.approved`, wenn „Förderstopp“ getrennt berichtet wird) | – |

Statische Sets mit Marktpfaden, die als **Wachstumsform** vorliegen, ändern nur `growth` (Override-Map ohne `start`
wird nach Spec 00 §4.7 in die Basis-Wertform gemischt). Liegt der Basispfad nicht als Wachstumsform vor, meldet die
Validierung E `validation.scenario_set.growth_form_required` mit dem betroffenen Pfad. Ein Set auf ein Overlay-Ziel
macht es im Set deterministisch (Spec 00 §4.7 letzter Absatz); in der MC unter einem Set laufen die übrigen
Overlay-Einträge weiter.

### 4.2 Standard-Sets (`inst/extdata/defaults/global.yaml`, Schicht 1; Ablage # 01a)

`foerderstopp` und `vorsichtig` sind nach Spec 00 §4.11 Pflicht (gleichlautend in Teil A §2.2); die übrigen Sets
ergänzt WS-A aus dieser Liste in `global.yaml`. Sie stehen zur Wahl in `vofi_compare(…, scenario_sets = …)` bereit
und werden nur auf Anforderung gerechnet. Alle Werte D (eigene
Ableitung), Belege in den Kommentaren.

```yaml
scenario_sets:
  foerderstopp:
    label: "Förderstopp: keine Förderzusage"
    description: "Alle Förderinstrumente ohne Zusage (Konzept B12). Bei Entscheidungsknoten realisiert der Basisfall die Ausweichvariante (Spec 00 §9.11 Nr. 3)."
    set: {funding.*.approved: 0}
  vorsichtig:
    label: "Vorsichtig: ungünstige Werte der fünf stärksten Treiber"
    description: "Aus dem Tornado der Primärkennzahl: die fünf Treiber mit dem größten Ausschlag gleichzeitig auf P10 bzw. P90 (Konzept 1.4, B5)."
    generate: {method: cautious, n_drivers: 5, probs: [0.1, 0.9], kpi: auto, params: auto}
  zinsschock:
    label: "Zinsschock: Bauzins 6,5 %"
    description: "Bauzins und Anschlusszins dauerhaft 6,5 % (+2,4 Pp ggü. 10/2026; Größenordnung 2022: +2,7 Pp in zwölf Monaten)."
    set: {market.mortgage_rate: 0.065}
  zins_niedrig:
    label: "Niedrigzins: Bauzins 2,5 %"
    set: {market.mortgage_rate: 0.025}
  stress_2022:
    label: "Stress wie 2022: Energiepreis-, Inflations-, Baukosten- und Zinsschock"
    description: "Krisenjahr 2027 nach dem Muster 2022/2023 (VPI 6,9 %/5,9 %, Baupreise 16,4 %/8,5 %, Bauzins +2,7 Pp, Energie-Commodity zweifach), danach Rückkehr."
    set:
      market.inflation: {series: {2027: 0.069, 2028: 0.059, 2029: 0.022}, fill: locf, before: first}          # Destatis VPI 2022/2023
      market.construction_price_index: {series: {2027: 0.164, 2028: 0.085, 2029: 0.031, 2030: 0.030}, fill: locf, before: first}   # Destatis Baupreise Wohngebäude 2022/2023/2024
      market.mortgage_rate: {years: [2027, 2028, 2032, 2037], values: [0.041, 0.068, 0.060, 0.050], interpolate: linear}
      market.energy_price.*: {growth: {series: {2027: 1.04, 2028: -0.235, 2029: -0.184, 2030: -0.150, 2031: 0.020}, fill: locf}}   # Faktor auf den Basispfad 2,0 / 1,5 / 1,2 / 1,0
  co2_niedrig:
    label: "CO2-Preis niedrig (Preisdämpfung)"
    set: {market.co2_price: {years: [2026, 2027, 2028, 2030, 2032, 2035, 2040, 2045, 2050, 2060, 2070], values: [65, 55, 45, 55, 60, 75, 100, 120, 140, 170.66, 208.03], interpolate: linear}}
  co2_hoch:
    label: "CO2-Preis hoch (UBA/Prognos)"
    set: {market.co2_price: {years: [2026, 2027, 2028, 2030, 2032, 2035, 2040, 2045, 2050, 2060, 2070], values: [65, 80, 95, 125, 155, 200, 275, 350, 425, 518.07, 631.53], interpolate: linear}}
  gasnetz_rueckbau:
    label: "Gasnetzrückbau: Netzentgelte +8 % p. a."
    set: {market.energy_network_fee.*: {growth: 0.08}}   # Obergrenze des Dreiecks (0; 3; 8 %), Memo 07 §4.0
  mit_2045_stufe:
    label: "Mit 2045-Stufe (100 % klimaneutraler Brennstoff ab 2045)"
    description: "Schaltercode stufe_2045 (Spec 00 §4.10, R-82). Ersetzt die Liste pending_reforms; zusätzliche Reformen im Set wiederholen."
    set: {project.pending_reforms: [stufe_2045]}
```

**Prüffälle (WS-A, WS-G):** (z1) `foerderstopp` auf S2 V1 (Knoten mit Ausweichvariante `v1b`): deterministischer
Zweig b = 0, Ergebnis = V1b, `decision$alternative` = V1 (Spec 00 §9.11 Nr. 3). (z2) `foerderstopp` auf ein Szenario
ohne Förderung: I („Wildcard ohne Treffer“), Ergebnis identisch zum Basisfall. (z3) `stress_2022` auf einen
Energiepreis `{start: 0.06335, growth: 0.02}` (Preisstand 2026, Stichtag 2027-01-01): Preisniveau am Ende der Jahre
2027 / 2028 / 2029 / 2030 / 2031 = 0,12923 / 0,09886 / 0,08067 / 0,06857 / 0,06994 EUR/kWh netto, d. h. Faktor auf
den Basispfad (0,06335 · 1,02^k) = 2,0 / 1,5 / 1,2 / 1,0 / 1,0 (Toleranz 1e-4 durch Rundung der Raten). (z4) `stress_2022` auf einen konstanten
Energiepreis `0.06335` → E `growth_form_required`. (z5) `mit_2045_stufe` + Bibliothek: Thema `bio_treppe` wählt
`legal/gmodg_bio_treppe_2045` (Vorrang des Reformeintrags, Spec 00 §4.10). (z6) Ein Set mit `measures.*.cost_eur` →
E (Pfad außerhalb der zulässigen Blöcke; Kostenschocks laufen über `market.construction_price_index` oder das Set
„vorsichtig“).

### 4.3 Generiertes Set „vorsichtig“ (Algorithmus, WS-G, `R/compare-cautious.R` # 01a)

1. **Kandidaten** (`params: auto`), kanonisch sortiert (`method = "radix"`): (a) alle statischen Overlay-Schlüssel der
   Rolle `value` (Ziel = Designspalte; low/high = Q(p_lo), Q(p_hi) der Verteilung, bei `apply: multiply|add` die
   verknüpften Werte nach 1.3); (b) alle unsicheren Prozessparameter `<proc>.<param>` (Designspalte nach Spec 00
   §11.11, Pfad = `expected(par_zeile)`); (c) jeder Prozess ohne unsicheren Parameter als **Quantilpfad** seines Ziels:
   je Jahr y das p-Quantil der Randverteilung (ar1, vasicek, linked_ar1 mit Gaußbasis: `expected_y + Φ⁻¹(p) · sd_y`
   geschlossen; mr_trend, gbm: Lognormal-Quantil; vasicek mit `floor`: `pmax(…, floor)`; scenario_mix: Szenario,
   dessen kumulierte Wahrscheinlichkeit in aufsteigender Ordnung des Szenariomittels über die Betriebsjahre zuerst
   p erreicht; iid: konstante Quantilreihe; fixed_path: kein Kandidat) (S01C-10); (d) Schlüssel der Rolle `decision`
   als Zweigwahl (Q(p) der Bernoulli: P10 = 1{0,1 > 1 − p}). Ausgeschlossen: `generate.exclude`.
2. **Tornado:** ein Design-Lauf mit 1 + 2k Zeilen (Spec 00 §11.11) auf der Kennzahl `kpi` (bei `delta_vs_reference`
   dieselbe Designmatrix für Variante und Referenz, Spec 00 §12.8). Swing_j = |KPI_hi − KPI_lo|.
3. **Auswahl:** die n = min(`n_drivers`, k) Kandidaten mit größtem Swing (Gleichstand: kanonische Ordnung), ohne
   Kandidaten mit Swing ≤ 1e-9 · max(1, |KPI_base|). Ungünstige Seite je Kandidat: der Wert mit dem kleineren KPI
   (bei `higher_is_better = FALSE` dem größeren).
4. **Designzeile:** alle n Kandidaten zugleich auf ihrer ungünstigen Seite, übrige auf dem Basiswert; Lauf mit n = 1
   (`meta$mode = "design"`, `meta$scenario_set = "vorsichtig"`, gesetzte Werte in `meta$notes`). Ohne Kandidaten:
   Hinweis, das Set gilt für die Ampel als nicht gerechnet (Spec 00 §12.9).
5. Der Tornado wird im Ergebnis mitgeliefert (`vofi_sensitivity`, 13.4) und ist mit `vofi_sensitivity(method =
   "tornado", probs = c(0.1, 0.9))` identisch.

**Prüffall (WS-G, synthetisch, linear):** KPI = 100 + 10 x1 − 5 x2 + 1 x3 mit x1, x2, x3 ~ U(−1; 1) (P10 = −0,8,
P90 = 0,8). Swings 16 / 8 / 1,6. `n_drivers: 2` → x1 = −0,8, x2 = +0,8 → KPI_vorsichtig = 88; `n_drivers: 5` → 87,2.
Mit einem vierten Schlüssel x4 ~ U(−1; 1) ohne Wirkung: unverändert (Swing 0 ausgeschlossen). Prozess-Quantilpfad
Vasicek r0 = 0,040 (1.6.3), y = 11: sd_11 = 0,01362516; P90-Pfad 0,05571434, P10-Pfad 0,02079164 (Toleranz 1e-8; P95 = 0,06066439 wie 2.8 Nr. 1).

### 4.4 Pflichtsensitivitäten (`analysis.mandatory_sensitivities`, Profilwerte; Ablage # 01a)

Je Eintrag `{id, path, label}` und genau eines von `value`, `delta`, `add` (Spec 00 §4.3.14, R-82). Ausführung
(WS-G): je Eintrag ein deterministischer Lauf mit dem Eintrag als Schicht-8-Override (neues Modell, `auto` neu
bestimmt), bei Vergleichen gemeinsam auf Variante und Referenz; Ausgabe Primärkennzahl mit und ohne Restwert sowie
Differenz zum Basisfall. `value` darf eine Wertform sein (z. B. `{ref: market.mortgage_rate}`, S01C-09). Einträge,
deren Override den Basiswert nicht ändert, erscheinen im Bericht als „entspricht dem Basisfall“; Einträge ohne
Wirkung auf das Ergebnis (z. B. 2045-Stufe ohne fossilen Erzeuger) als „ohne Wirkung“.

| Profil | id | `path` | Wert | Label | Konzept |
|---|---|---|---|---|---|
| alle | `restwert_null` | `residual_value.method` | `value: zero` | „Restwert = 0“ | 5.5, A3 |
| alle | `stufe_2045` | `project.pending_reforms` | `add: stufe_2045` | „mit 2045-Stufe (100 % klimaneutraler Brennstoff ab 2045)“ | F5, A7, R-82 |
| `wu_kommunal`, `wu_privat` | `habenzins_liquiditaet` | `accounts.deposit_rate_pa` | `value: 0.02` | „Habenzins 2,0 % (reine Liquiditätsanlage)“ | A2, F18 |
| `wu_kommunal`, `wu_privat`, `wu_genossenschaft` | `habenzins_kalkulationszins` | `accounts.deposit_rate_pa` | `value: 0.035` | „Habenzins = Kalkulationszins 3,5 %“ | A2, A4, F18 |
| `wu_kommunal`, `wu_privat`, `wu_genossenschaft` | `habenzins_fk` | `accounts.deposit_rate_pa` | `value: {ref: market.mortgage_rate}` | „Habenzins = vermiedener FK-Zins“ | A2 |
| `selbstnutzer`, `kleinvermieter` | `habenzins_abgeltung` | `accounts.deposit_withholding_tax_share` | `value: 0.26375` | „Habenzins nach Abgeltungsteuer (25 % + Soli)“ | B4, 3.12 |

```yaml
# Profil wu_kommunal (Ausschnitt, # 01a); wu_privat gleich; wu_genossenschaft ohne habenzins_liquiditaet
analysis:
  mandatory_sensitivities:
    - {id: restwert_null, path: residual_value.method, value: zero, label: "Restwert = 0"}
    - {id: habenzins_liquiditaet, path: accounts.deposit_rate_pa, value: 0.02, label: "Habenzins 2,0 % (reine Liquiditätsanlage)"}
    - {id: habenzins_kalkulationszins, path: accounts.deposit_rate_pa, value: 0.035, label: "Habenzins = Kalkulationszins 3,5 %"}
    - {id: habenzins_fk, path: accounts.deposit_rate_pa, value: {ref: market.mortgage_rate}, label: "Habenzins = vermiedener FK-Zins"}
    - {id: stufe_2045, path: project.pending_reforms, add: stufe_2045, label: "mit 2045-Stufe (100 % klimaneutraler Brennstoff ab 2045)"}
---
# Profil selbstnutzer bzw. kleinvermieter (Ausschnitt, # 01a)
analysis:
  mandatory_sensitivities:
    - {id: restwert_null, path: residual_value.method, value: zero, label: "Restwert = 0"}
    - {id: habenzins_abgeltung, path: accounts.deposit_withholding_tax_share, value: 0.26375, label: "Habenzins nach Abgeltungsteuer (25 % + Soli)"}
    - {id: stufe_2045, path: project.pending_reforms, add: stufe_2045, label: "mit 2045-Stufe (100 % klimaneutraler Brennstoff ab 2045)"}
```

Kirchensteuer und Sparer-Pauschbetrag (`deposit_tax_allowance_eur_pa`, R-76) setzt der Nutzer; der Bericht nennt die
Fehlerrichtung: Mit Brutto-Habenzins unterschätzt die Rechnung den Vorteil einer eigenfinanzierten Maßnahme (Konzept
3.12).

**Prüffälle (Walking Skeleton, Spec 00 Anhang A; h = 2 %, deterministisch, Toleranz 0,005 EUR):**

| Sensitivität | EW | EW_U | ΔEW | Herleitung |
|---|---:|---:|---:|---|
| Basis | 52.830,80 | 42.448,32 | 10.382,48 | Spec 00 Anhang A |
| `habenzins_kalkulationszins` (0,035) | 54.218,075 | 44.348,715 | 9.869,36 | G_2 = 64.945; t = 3: 50.000 − 3.000 − 60.000 + 2.273,075 |
| `habenzins_fk` (0,04, Pfad konstant) | 54.683,20 | 44.994,56 | 9.688,64 | G_2 = 65.080 |
| `habenzins_abgeltung` (0,26375, Pauschbetrag 0) | 52.345,83 | 41.793,15 | 10.552,68 | Habenzins netto 2 % · 0,73625 = 1,4725 %; Geldanlage und Unterlassung gleich besteuert |
| `restwert_null` | 52.830,80 | 42.448,32 | 10.382,48 | kein Restwert im Skelett (Prüfung „entspricht dem Basisfall“) |

Bei S1 (Habenzins im Szenario 2,0 %, F18) entspricht `habenzins_liquiditaet` dem Basisfall; `habenzins_kalkulationszins`
zeigt den Unterschied zum Profilwert 3,5 %.

---

## 5. Referenzszenarien S1–S5 und `grob_lehrbuch_a` (`inst/extdata/examples/`, WS-S)

### 5.0 Gemeinsame Konventionen (verbindlich für WS-S)

1. **Dateien und ids:** `s1_wu_mfh_1963_eh70.yaml`, `s2_wu_neubau_mfh_36we.yaml`, `s3_eg_waermepumpe_pv.yaml`,
   `s4_efh_1975_isfp.yaml`, `s5_neubau_efh_eh40.yaml`, `grob_lehrbuch_a.yaml` (dazu `skeleton.yaml`, Spec 00
   Anhang A). `vofi_example()` listet sie; `meta.scenario_id` = Dateiname ohne `.yaml`.
2. **Basis = Referenzvariante.** `base` ist die Referenz aus Memo 07 (S1 V1, S2 V1, S3 V1, S4 V0, S5 V1);
   `project.reference_variant: base`. Bei Bestandsprojekten (S1, S3, S4) ist das die Referenzpflicht nach Spec 00
   §12.3a; Primärkennzahl `delta_vs_reference` (`incremental_return` deterministisch). Varianten-ids `v<n>_<kurz>`.
3. **Zeit:** Stichtag 2027-01-01, Jahresraster, `year: Y` = 1. Januar Y (Spec 00 §3.4); Horizontende fest
   (R-67). Kredite mit `payments_per_year: 1` (Spec 00 §15.6), **außer S5** (Prüfwerte sind Monatsraten,
   `payments_per_year: 12`, S01C-06).
4. **Preisstände (R-35):** `project.price_base_year: 2026` (Preisstand 1.1.2027) für laufende Jahresbeträge „Preisbasis
   2026“ in allen Szenarien. Maßnahmen: S1–S3 „Kostenstand 2027“ (Maßnahmen 2027 und Ersatz) → `price_base_year:
   2026`; S2-Ersatz und S4 „Preisbasis/Kostenstand 2026“ → je Maßnahme `price_base_year: 2025` (Index ab 1.1.2026;
   Vorlaufjahr 2026 über `series_year` mit Schlüssel 2026, Spec 00 §3.6); S5 Festpreis → `price_index: 0`; S2-Investition
   (nominal 2027/28) → `price_index: 0`.
5. **Energiepreise netto** (01b §0.6, §3.2.1): Die Brutto-Preise aus Memo 07 §4.0 stehen in
   `prices/referenzszenarien_2026` als Nettowerte mit acht Nachkommastellen (= brutto / 1,19; Abweichung nach USt
   < 3e-9 EUR/kWh, d. h. < 0,001 EUR je Prüfwert). CO2-Preis netto in EUR/t nach Memo 07 (60/60/70, +5 €/t bis 2035,
   danach +3 %) über `prices/co2_price_path_referenzszenarien_2026` mit den Stützstellen `shared.co2_2030` und
   `shared.co2_2040`. Emissionsfaktor Erdgas **0,181** kg/kWh_Hs als Szenarioeinstellung (Memo 07; Bibliothek
   0,1814, F19).
6. **Stochastik (F20):** Prozesse aus Abschnitt 2 (Vasicek-Bauzins, AR(1)-Inflation, Mean-Reversion-Energiepreise mit
   den Normalpreisen der Bibliothek, CO2-Stützstellen Dreieck(60; 90; 200)/(80; 150; 300) mit ρ_S 0,8,
   Netzentgeltwachstum Dreieck(0; 3; 8 %), Bio-Mehrkostenfaktor Dreieck(0,5; 1; 1,67), Baupreisindex additiv
   N(0; 1,2 Pp) nach Memo 07 §4.0). Die Random-Walk-Defaults aus Memo 07 §4.0 entfallen. Szenariospezifische
   Verteilungen nach Memo 07 §4.1–4.5. Variantenspezifische Overlay-Einträge stehen in der Variante (`add`/`set`
   unter `stochastic.parameters`); gleiches Risiko = gleicher Schlüssel mit variantenspezifischen Parametern (CRN,
   R-59), verwandte Kostenrisiken getrennt mit ρ_S 0,7 (B9). Faktoren und Zuschläge wirken über `shared`-Blätter
   (Basiswert 1 bzw. 0): Kostenfaktoren über `measures.<m>.cost_factor: {ref: shared.cost_factor_<v>}` (Teil A
   4.1), Baupreisindex, Bio-Mehrkosten und Instandhaltungsniveau über `expr`-Angaben; damit sind die Szenarien
   unabhängig von S01C-01.
7. **Zusagerisiko:** Nur S2 modelliert die Verfügbarkeit der EH-55-Stufe als Entscheidungsknoten (Spec 00 §9.11,
   Konzept S2). Übrige Förderinstrumente tragen `approval_probability: 1.0` (Memo 07 sieht dort kein Zusagerisiko
   vor), außer S4 Stufe 3 (BAFA 2033: einfache Ziehung p = 0,7, KfW 358 2033 per Bezug gekoppelt).
8. **Prüfwerte:** Toleranz ±0,01 EUR (Beträge), ±0,1 % (Annuitäten, Memo 07), 1e-6 relativ (Energiemengen), sofern
   nicht anders angegeben; Prüfwerte „(Preisbasis 2026)“ gelten für die **unindexierten** Jahresbeträge, d. h. mit
   Override `market.*` Wachstum 0 bzw. als Hilfsgröße vor Fortschreibung. Konzeptkorrekturen F13/F14 sind
   eingearbeitet (S1-T4, S3-T3, S3-T4). MC-Erwartungen gelten für n_sim = 10.000, Seed 20261025, `block_size` 200:
   Eingangsmomente innerhalb 4 SE, Rangkorrelationen ±0,02 (Spec 00 §15.6); qualitative Hypothesen sind keine
   Sollwerte (Konzept §9, F20).
9. Feldnamen nach Teil A (Maßnahmen 4.1/4.2, `building.maintenance` 3.3, Restwert 6.1) und Teil B (Energiezustände
   3.2, PV 3.9, Förderung 4.2, Mietrecht 1.2–1.4), Stand 2026-10-26. Instandhaltung immer über
   `building.maintenance` (Teil A legt die Pauschale per Default an; keine zusätzliche `recurring`-Instandhaltung).
   Förderkredite entstehen im Expander `funding` (`financing.f_<f>_loan`, Teil B 4.6; Start = frühester
   Maßnahmentermin, Teilauszahlungen nach den Zahlungsplänen).

```yaml
# inst/extdata/library/prices/referenzszenarien_2026.yaml
id: prices/referenzszenarien_2026
block: market
schema_version: 1
label: "Markt- und Preisannahmen der Referenzszenarien S1-S5 (Memo 07 §4.0, Energiepreise netto)"
source: {document: "Memo 07 §4.0 Default-Indizes, Default-Energiepreise (Preisbasis 2026, brutto), Finanzmarkt-Defaults; Konzept F19, F20", url: "docs/recherche/07_use_cases_referenzszenarien.md", publisher: "eigene Festlegung (Referenzszenarien)"}
as_of: 2026-10-25
valid_from: 2026-01-01
valid_to: null
quality: D
legal_state: {as_of: 2026-10-25, status: derived, reference: "Szenarioannahmen Memo 07 §4.0"}
values:
  market:
    inflation: {series: {2027: 0.028, 2028: 0.022}, fill: locf, before: first}
    construction_price_index: {expr: "market.construction_price_index_base + shared.construction_price_shift"}
    construction_price_index_base: {series: {2027: 0.040, 2028: 0.030}, fill: locf, before: first}
    maintenance_index: {ref: market.construction_price_index}
    land_value_growth: 0.015
    market_value_growth: 0.015
    rent_growth: 0.015                    # Bestand § 558
    rent_growth_new: 0.020                # Neubau
    mortgage_rate: 0.040                  # Anschlusszins deterministisch
    energy_price:                         # EUR/kWh NETTO ohne CO2 und Netzentgelt, Preisbasis 2026, Wachstum „Rest“ 2,0 %
      gas:                {start: 0.06848739, growth: 0.02}   # Erdgas EFH: Rest 8,15 ct brutto
      gas_mfh:            {start: 0.06134454, growth: 0.02}   # Erdgas MFH: Rest 7,30 ct brutto
      heatpump_power:     {start: 0.20168067, growth: 0.02}   # WP-Strom EFH 24,0 ct brutto
      heatpump_power_mfh: {start: 0.21008403, growth: 0.02}   # WP-Strom MFH 25,0 ct brutto inkl. Grundpreis
      power:              {start: 0.31092437, growth: 0.02}   # Haushaltsstrom 37,0 ct brutto
    energy_network_fee:                   # EUR/kWh netto (Hs)
      gas:     {start: 0.02571429, growth: {ref: shared.network_fee_growth_gas}}       # 3,06 ct brutto (2,57 netto)
      gas_mfh: {start: 0.02193277, growth: {ref: shared.network_fee_growth_gas_mfh}}   # 2,61 ct brutto (2,19 netto)
    bio_fuel_premium: {expr: "market.bio_fuel_premium_base * shared.bio_premium_factor"}
    bio_fuel_premium_base: {start: 0.060, growth: 0.02}       # 6,0 ct netto (7,14 brutto)
    feed_in_tariff: {partial_le10kwp: 0.0770, partial_10_40kwp: 0.0666, partial_40_100kwp: 0.0545}   # IBN bis 31.01.2027, 20 J. fest
  shared:
    network_fee_growth_gas: 0.03
    network_fee_growth_gas_mfh: 0.03
    co2_2030: 80                          # 70 + 2 x 5
    co2_2040: 121.72377780                # 105 x 1,03^5
    construction_price_shift: 0           # Overlay-Ziel (additiv, Basis 0)
    bio_premium_factor: 1                 # Overlay-Ziel (Faktor, Basis 1)
  carriers:                               # informativ (Werte der Referenzszenarien je Träger; die Szenarien setzen sie in energy.carriers)
    gas:                {class: gas, emission_factor_kg_kwh: 0.181, base_fee_eur_pa: 151.26050420, vat_rate: 0.19}   # Grundpreis 180 EUR brutto
    gas_mfh:            {class: gas, emission_factor_kg_kwh: 0.181, base_fee_eur_pa: 0, vat_rate: 0.19}              # Grundpreis im Arbeitspreis
    heatpump_power:     {class: power_hp, base_fee_eur_pa: 117.64705882, vat_rate: 0.19}                             # 140 EUR brutto
    heatpump_power_mfh: {class: power_hp, base_fee_eur_pa: 0, vat_rate: 0.19}
    power:              {class: power, base_fee_eur_pa: 100.84033613, vat_rate: 0.19}                                # 120 EUR brutto
notes: "Brutto je kWh (Preisbasis 2026, CO2 60 EUR/t): Gas EFH 8,15 + 3,06 + 1,2923 = 12,5023 ct (Memo 07 rundet auf 12,50); Gas MFH 7,30 + 2,61 + 1,2923 = 11,2023 ct (11,20). Deterministischer CO2-Pfad über prices/co2_price_path_referenzszenarien_2026."
```

**Gemeinsamer Overlay-Kern** (in jedem Szenario ausgeschrieben; Prozessschlüssel nach 1.10.2):

```yaml
stochastic:
  settings: {n_sim: 10000, seed: 20261025, sampling: lhs, block_size: 200, store: bands}
  processes:
    mortgage_rate: {target: market.mortgage_rate, from: processes/mortgage_rate_vasicek_2026}   # r0: base = 0,040
    inflation:     {target: market.inflation, from: processes/inflation_ar1_2026}                # x0: base = 0,028
    # energy_price_<c>: {target: market.energy_price.<c>, from: processes/energy_prices_mr_2026, use: <c>} je genutztem Träger
  parameters:
    co2_2030: {target: shared.co2_2030, label: "CO2-Preis 2030", dist: triangular, min: 60, mode: 90, max: 200}
    co2_2040: {target: shared.co2_2040, label: "CO2-Preis 2040", dist: triangular, min: 80, mode: 150, max: 300}
    bio_premium_factor: {target: shared.bio_premium_factor, from: processes/energy_prices_mr_2026, use: bio_premium_factor, apply: replace}   # Dreieck(0,5; 1; 1,6667) ≙ 3/6/10 ct netto
    construction_price_shift: {target: shared.construction_price_shift, label: "Abweichung Baupreisindex p. a.", dist: normal, mean: 0, sd: 0.012}   # Memo 07 §4.0: N(Basis; 1,2 Pp)
  correlations:
    parameters: [[co2_2030, co2_2040, 0.8]]
    shocks: {from: processes/shock_correlations_2026}     # Paare ohne Schlüssel im Plan werden verworfen (1.7.1)
```

### 5.1 S1 – Kommunales WU: MFH 1963 auf EH 70 EE gegenüber Ohnehin-Sanierung (30 Jahre)

Quelle Memo 07 §4.1, Konzept §9 S1, F14, F18, F19. Basis = V1 Ohnehin-Sanierung, Variante `v2_eh70`. Kostenaufteilung
der Maßnahmen (Bauleistung × (1 + KG 700) × 1,05): V1 Faktor 1,15 · 1,05 = 1,2075, V2 1,18 · 1,05 = 1,239.

| Maßnahme | Bauleistung | Gesamtkosten | Ohnehin-Kosten | Modernisierungskosten | Art |
|---|---:|---:|---:|---:|---|
| V1 `ohnehin_fassade` (Gerüst, Putz/Anstrich) | 105.000 | 126.787,50 | = Kosten | – | Erhaltung |
| V1 `ohnehin_fenster` (2-fach) | 266.000 | 321.195,00 | = Kosten | – | Erhaltung |
| V1 `ohnehin_heizung` (Gas-BW, Abgleich) | 107.000 | 129.202,50 | = Kosten | – | Erhaltung |
| **Summe V1** | 478.000 | **577.185,00** | | | |
| V2 `huelle` (Gerüst, WDVS 16 cm, Decken, Fenster 3-fach) | 799.500 | 990.580,50 | 447.982,50 | 542.598,00 | `bgb_555b_1` |
| V2 `heizung` (WP-Kaskade, Heizkörper, TWW, Elektro, Abgleich) | 300.000 | 371.700,00 | 129.202,50 | 242.497,50 | `bgb_555b_1a`, Verfahren § 559 |
| V2 `lueftung` (Abluftanlage) | 72.000 | 89.208,00 | 0 | 89.208,00 | `bgb_555b_1` |
| **Summe V2** | 1.171.500 | **1.451.488,50** | 577.185,00 | **874.303,50** | |

```yaml
# inst/extdata/examples/s1_wu_mfh_1963_eh70.yaml
schema_version: 1
meta:
  scenario_id: s1_wu_mfh_1963_eh70
  title: "S1 – Kommunales Wohnungsunternehmen: Sanierung MFH 1963 auf EH 70 EE gegenüber Ohnehin-Sanierung"
  author: "WS-S (Referenzszenario, Memo 07 §4.1)"
  created_date: 2026-10-25
  tags: [referenzszenario, s1, bestand, sanierung]
project:
  perspective: wu_kommunal
  project_type: sanierung_eh
  comparison_mode: absolute
  valuation_date: 2027-01-01
  horizon_years: 30                         # 2027-2056, Horizontende 2057-01-01
  application_date: 2026-12-15
  legal_state: 2026-10-25
  pending_reforms: []
  price_base_year: 2026                     # Kostenstand 2027 (= Preisstand 1.1.2027) bzw. Preisbasis 2026 der Jahresbeträge (R-35)
  reference_variant: base                   # V1 Ohnehin-Sanierung (Referenzpflicht im Bestand, Spec 00 §12.3a)
  report_mode: expert
grid: {construction_months: 0}
building:
  building_type: MFH
  construction_year: 1963
  n_units: 24
  living_area_m2: 1600
  net_floor_area_m2: 2000                   # A_N
  component_areas_m2: {facade: 1500, windows: 380, top_ceiling: 400, basement_ceiling: 400}
  energy_class_before: H
  wpb_flag: true                            # Worst Performing Building (Bonus KfW 261)
  denkmal: false
  heating_existing: {carrier: gas_mfh, installation_year: 1998}
  consumption_kwh: {gas_mfh: 280000}        # Ø 3 Jahre, Hs
  land_value_eur: 504000                    # Bodenwert 2026 (Fortschreibung residual_value.income_value.land_value_growth)
  existing_value_eur: null                  # Memo 07 ohne Bestandswert -> roe_* NA (no_existing_value)
  maintenance:
    rate_eur_m2_pa: 14.40                   # 23.040 EUR/a (Preisbasis 2026); V2: Pfad 10,00 2028-2042
    excludes_explicit_replacements: true    # Ersatz 2042/2047 nicht in der Pauschale (Memo 07)
unit_groups:
  bestand:
    label: "24 WE Bestand"
    n_units: 24
    living_area_m2: 1600
    rent_regime: paragraph_558
    rent_eur_m2_month: 6.20                 # 119.040 EUR/a Soll
    increase_policy: fixed_growth
    rent_growth: 0.015
    growth_from: 2028-01-01                 # V2: 2029-01-01
    growth_applies_to: total
    vacancy_rate: 0.03                      # V2: 0,01
    rent_default_rate: 0.01
    extra_loss_share: {series: {2027: 0.0125, 2028: 0}, fill: locf, before: first}   # Mietminderung Bauphase; V2: 0,075
    rent_law:
      modernization_levy: auto
      voluntary_cap_per_m2: null            # V2: 1.10 (Beschluss warmmietenneutral)
      hardship_share: 0
    operating:
      admin_per_unit_eur_pa: 367            # 8.808 EUR/a (2026), VPI
      nonrecoverable_share_of_rent: 0
      recoverable_opex_eur_m2_month: 2.50   # Leerstandsbedingte Betriebskosten
      vacancy_opex_scope: cold
measures:
  ohnehin_fassade:
    label: "Gerüst, Putzausbesserung und Anstrich"
    measure_type: putz_anstrich             # ND 15 -> Ersatz 2042 (Memo 07: 82.500, Kostenstand 2027)
    year: 2027
    completion_date: 2027-10-01
    cost_eur: 126787.50                     # 105.000 x 1,15 x 1,05
    cost_factor: {ref: shared.cost_factor_v1}
    ohnehin_share: 1
    classification: erhaltung
    useful_life_years: 15
    replacement: {enabled: true, cost_eur: 82500}
  ohnehin_fenster:
    label: "Fenstertausch 2-fach (U_w 1,3)"
    measure_type: fenster
    year: 2027
    completion_date: 2027-10-01
    cost_eur: 321195.00                     # 266.000 x 1,2075
    cost_factor: {ref: shared.cost_factor_v1}
    ohnehin_share: 1
    classification: erhaltung
    modernization_kind: none                # Verbesserung bewusst nicht umgelegt (Memo 07)
    useful_life_years: 40
  ohnehin_heizung:
    label: "Gas-Brennwertkessel inkl. Abgas, Speicher, hydraulischer Abgleich"
    measure_type: heizung_gaskessel
    year: 2027
    completion_date: 2027-10-01
    cost_eur: 129202.50                     # 107.000 x 1,2075
    cost_factor: {ref: shared.cost_factor_v1}
    ohnehin_share: 1
    classification: erhaltung
    useful_life_years: 20                   # Memo 07 (Szenarioeinstellung, F19)
    replacement: {enabled: false}           # Ersatz 2047 als eigene Maßnahme (Zustandswechsel bei 2045-Stufe)
  ersatz_heizung_2047:
    label: "Heizungsersatz 2047 (Gas-BW; mit 2045-Stufe Wärmepumpe)"
    measure_type: heizung_gaskessel
    year: 2047
    completion_date: 2047-01-01
    cost_eur: {expr: "95000 + shared.v1_wp_2047 * (300000 - 95000)"}   # WP-Ersatz 300.000 (D, wie V2-Heizung ohne Nebenkosten)
    classification: erhaltung
    useful_life_years: 20
shared:
  from: prices/referenzszenarien_2026       # network_fee_growth_*, co2_2030/2040, construction_price_shift, bio_premium_factor
  use: shared
  cost_factor_v1: 1
  cost_factor_v2: 1
  maintenance_saving_v2: 4.40               # EUR/m2 a (14,40 - 10,00)
  v1_wp_2047: {expr: "ifelse('stufe_2045' %in% project.pending_reforms, 1, 0)"}   # Pflichtsensitivität stufe_2045 (Konzept S1)
energy:
  carriers:
    gas_mfh: {emission_factor_kg_kwh: 0.181}          # Preise per Default aus market (netto), USt 0,19
    heatpump_power_mfh: {}
  before:
    efficiency: 0.87                         # Messverbrauch 280.000 kWh -> Nutzwärme 243.600 kWh
    service_eur_pa: 1512.60504202            # 1.800 EUR brutto
  after:
    measure: ohnehin_heizung
    demand_kwh: 242250                       # 255.000 kWh Gas x 0,95 (Memo 07: Wirkungsgradgewinn ≈ 9 %)
    heating_carrier: gas_mfh                 # neue Heizung -> installation_date 2027-10-01, § 43, § 5a ab 2028
    efficiency: 0.95
  stages:
    ersatz2047:
      measure: ersatz_heizung_2047
      carrier_shares: {gas_mfh: {expr: "1 - shared.v1_wp_2047"}, heatpump_power_mfh: {ref: shared.v1_wp_2047}}
      efficiency_by_carrier: {gas_mfh: 0.95}
      heat_pump_carrier: heatpump_power_mfh
      jaz: 2.7                               # D: unsanierter Bestand, Vorlauf > 55 °C
      flow_temperature_c: 60
financing:
  ek: {type: equity, amount_eur: 151488.50}  # EK-Budget gleich je Variante (V1: 1.488,50 als Geldanlage)
  bank:
    type: annuity_loan
    label: "Kapitalmarktdarlehen"
    amount_eur: 427185
    start: 2027-01-01
    rate_pa: 0.04
    term_years: 20
    fixed_years: 10
    payments_per_year: 1
    followup_rate_pa: {ref: market.mortgage_rate}
    refi_rule: keep_term
accounts:
  deposit_rate_pa: {ref: market.mortgage_rate, anchor: 0.02}     # Szenarioeinstellung 2,0 % (F18; Profil 0,035)
  overdraft_rate_pa: {ref: market.mortgage_rate, anchor: 0.055}
market:
  from: prices/referenzszenarien_2026
  use: market
  co2_price: {from: prices/co2_price_path_referenzszenarien_2026}
residual_value:
  method: income_value
  sale_cost_share: 0.03
  income_value:
    cap_rate: 0.035
    remaining_life_method: manual
    remaining_life_years: 15                 # V2: 25
tax: {module: none}
analysis:
  stabilization_year: 2028
stochastic:
  settings: {n_sim: 10000, seed: 20261025, sampling: lhs, block_size: 200, store: bands}
  processes:
    mortgage_rate: {target: market.mortgage_rate, from: processes/mortgage_rate_vasicek_2026}
    inflation: {target: market.inflation, from: processes/inflation_ar1_2026}
    energy_price_gas_mfh: {target: market.energy_price.gas_mfh, from: processes/energy_prices_mr_2026, use: gas_mfh}
    energy_price_heatpump_power_mfh: {target: market.energy_price.heatpump_power_mfh, from: processes/energy_prices_mr_2026, use: heatpump_power_mfh}
  parameters:
    co2_2030: {target: shared.co2_2030, label: "CO2-Preis 2030", dist: triangular, min: 60, mode: 90, max: 200}
    co2_2040: {target: shared.co2_2040, label: "CO2-Preis 2040", dist: triangular, min: 80, mode: 150, max: 300}
    network_fee_growth_gas_mfh: {target: shared.network_fee_growth_gas_mfh, from: processes/energy_prices_mr_2026, use: network_fee_growth}
    bio_premium_factor: {target: shared.bio_premium_factor, from: processes/energy_prices_mr_2026, use: bio_premium_factor, apply: replace}
    construction_price_shift: {target: shared.construction_price_shift, label: "Abweichung Baupreisindex p. a.", dist: normal, mean: 0, sd: 0.012}
    rent_growth: {target: unit_groups.bestand.rent_growth, label: "Mietsteigerung § 558", dist: normal, mean: 0.015, sd: 0.006}
    cost_factor_v1: {target: shared.cost_factor_v1, label: "Kostenabweichung Ohnehin-Sanierung", dist: pert, min: 0.95, mode: 1.05, max: 1.25}
    cost_factor_v2: {target: shared.cost_factor_v2, label: "Kostenabweichung EH-70-Sanierung", from: processes/cost_risks_2026, use: overrun_retrofit, apply: replace}
    vacancy: {target: unit_groups.bestand.vacancy_rate, label: "Leerstand", dist: beta, mean: 0.03, sd: 0.02}
    hardship: {target: unit_groups.bestand.rent_law.hardship_share, label: "Härtefallquote § 559 Abs. 4", dist: beta, mean: 0.08, sd: 0.05}
    cap_rate_rv: {target: residual_value.income_value.cap_rate, label: "Liegenschaftszins 2056", dist: truncnorm, mean: 0.035, sd: 0.005, lower: 0.02, upper: 0.06}
    rnd_rv: {target: residual_value.income_value.remaining_life_years, label: "Restnutzungsdauer 2056", dist: triangular, min: 10, mode: 15, max: 20}
  correlations:
    parameters: [[cost_factor_v1, cost_factor_v2, 0.7], [co2_2030, co2_2040, 0.8]]
    shocks: {from: processes/shock_correlations_2026}
variants:
  v2_eh70:
    label: "V2 Energetische Sanierung EH 70 EE (KfW 261 mit WPB-Bonus)"
    remove: [financing.bank, measures.ohnehin_fassade, measures.ohnehin_fenster, measures.ohnehin_heizung,
             measures.ersatz_heizung_2047, energy.stages]
    replace:
      energy.after:
        measure: heizung
        demand_kwh: 120000                  # 75 kWh/m2 a inkl. Rebound
        heating_carrier: heatpump_power_mfh
        jaz: 2.9                            # realisiert (Basis); jaz_plan = Basisfallwert (R-70)
        jaz_plan: 2.9                       # VDI 4650, Vorlauf <= 55 °C -> § 559f erfüllt
        flow_temperature_c: 55
        service_eur_pa: 2016.80672269       # 2.400 EUR brutto
    set:
      building.maintenance.rate_eur_m2_pa: {series: {2027: 14.40, 2028: {expr: "14.40 - shared.maintenance_saving_v2"}, 2043: 14.40}, fill: locf, before: first}
      unit_groups.bestand.vacancy_rate: 0.01
      unit_groups.bestand.extra_loss_share: {series: {2027: 0.075, 2028: 0}, fill: locf, before: first}
      unit_groups.bestand.growth_from: 2029-01-01
      unit_groups.bestand.rent_law.voluntary_cap_per_m2: 1.10      # Beschluss: 21.120 EUR/a ab 01.01.2028
      residual_value.income_value.remaining_life_years: 25
      stochastic.parameters.vacancy: {mean: 0.01, sd: 0.008}       # gleicher Schlüssel, CRN
      stochastic.parameters.rnd_rv: {min: 18, mode: 25, max: 32}
    add:
      measures.huelle:
        label: "WDVS 16 cm, oberste Geschossdecke, Kellerdecke, Fenster 3-fach, Gerüst"
        measure_type: daemmung_fassade
        year: 2027
        completion_date: 2027-10-01
        cost_eur: 990580.50                 # 799.500 x 1,18 x 1,05
        cost_factor: {ref: shared.cost_factor_v2}
        ohnehin_cost_eur: {expr: "447982.50 * shared.cost_factor_v1"}   # = Ohnehin-Fassade + Ohnehin-Fenster (V1)
        modernization_kind: bgb_555b_1
        useful_life_years: 40
      measures.heizung:
        label: "Luft/Wasser-WP-Kaskade 2 x 45 kW, Heizkörper, Frischwasserstationen, Elektro, Abgleich"
        measure_type: heizung_waermepumpe_luft
        year: 2027
        completion_date: 2027-10-01
        cost_eur: 371700.00                 # 300.000 x 1,239
        cost_factor: {ref: shared.cost_factor_v2}
        ohnehin_cost_eur: {expr: "129202.50 * shared.cost_factor_v1"}
        modernization_kind: bgb_555b_1a
        rent_law: {procedure: "559"}        # § 559 statt § 559e (Teilkappung 0,50 EUR/m2, F14; 01b 1.4)
        useful_life_years: 20               # Memo 07: Erzeuger/Peripherie 2047
        replacement: {enabled: true, cost_eur: 180000}   # Kostenstand 2027
      measures.lueftung:
        label: "Zentrale Abluftanlage"
        measure_type: lueftung_dezentral
        year: 2027
        completion_date: 2027-10-01
        cost_eur: 89208.00                  # 72.000 x 1,239
        cost_factor: {ref: shared.cost_factor_v2}
        ohnehin_cost_eur: 0
        modernization_kind: bgb_555b_1
        useful_life_years: 20
        replacement: {enabled: false}       # Memo 07 ohne Ersatz im Horizont
      measures.anstrich_wdvs_2047:
        label: "WDVS-Anstrich"
        measure_type: putz_anstrich
        year: 2047
        cost_eur: 45000                     # Kostenstand 2027
        classification: erhaltung
        useful_life_years: 15
      funding.kfw261:
        from: funding/kfw_261_eh70
        measures: [huelle, heizung, lueftung]
        application_date: 2026-12-15
        amount_eur: 1300000                 # Zusage inkl. Baubegleitung (investiv 1.264.000)
        construction_support_eur: 36000     # Baubegleitung, TZ 50 %
        loan_variant: v30_5_10              # 30 J., 5 tilgungsfrei, 10 J. fest, 3,65 %
        loan: {payments_per_year: 1}        # Spec 00 §15.6 (Bibliothek: 12)
        repayment_grant: {payout: {lag_months: 3}}   # Gutschrift 2028-01-01 (S1-T8)
        facts: {ee_class: true}             # EH 70 EE
        approval_probability: 1.0           # Memo 07: kein Zusagerisiko in S1
      stochastic.parameters.jaz_v2: {target: energy.after.jaz, label: "JAZ WP-Kaskade (realisiert)", dist: triangular, min: 2.6, mode: 2.9, max: 3.3}
      stochastic.parameters.demand_after_v2: {target: energy.after.demand_kwh, label: "Nutzwärme nach Sanierung", dist: triangular, min: 104000, mode: 120000, max: 144000}
      stochastic.parameters.maintenance_saving_v2: {target: shared.maintenance_saving_v2, label: "Instandhaltungsersparnis V2", dist: triangular, min: 2.0, mode: 4.4, max: 6.0}
scenario_sets:
  ohne_wpb:
    label: "ohne WPB-Status (Tilgungszuschuss 0 % statt 10 %)"
    set: {funding.*.repayment_grant.bonuses.wpb.rate: 0}   # Pfad aus funding/kfw_261_eh70; in base ohne Treffer (Hinweis); Hypothese: V2 verliert 126.400 EUR
```

Nicht abgebildet (Abweichungen): Mietspiegelvorteil V2 (Memo 07: Dreieck(0; 0,2; 0,5) €/m² ab 2030) wirkt nur in den
OVM-Modi des Mietpfads; S1 rechnet nach Memo 07 mit fester Steigerung (`fixed_growth`), daher entfällt er
(Variante `v2_ovm` mit `increase_policy: max` und `measures.huelle.rent_law.ovm_uplift_eur_m2_month` als Beispiel,
01b 1.4). Die Beschlussumlage 1,10 €/m² ist fest (S1-T6); die rechnerisch warmmietenneutrale Obergrenze liefert
`unit_groups.bestand.rent_law.voluntary_cap_mode: warm_rent_neutral` (01b 1.3, im Basisfall bestimmt, R-70; Hypothese
≈ 1,07 €/m²). Optionale Varianten V0, V3, V4 nicht im Pflichtumfang (Konzept C7).

**Prüfwerte S1 (deterministisch):**

| Nr. | Größe | Soll | Herkunft |
|---|---|---:|---|
| S1-T1 | Gesamtinvestition V2 / V1 | 1.451.488,50 / 577.185,00 | Memo 07 |
| S1-T2 | Modernisierungskosten V2 (§ 559 Abs. 2) | 874.303,50 | Memo 07 |
| S1-T3 | Tilgungszuschuss KfW 261 (10 % × 1.264.000 + 50 % × 36.000) | 144.400,00 | Memo 07 |
| S1-T4 | Umlage rechnerisch vor Kappungen: (874.303,50 − 144.400) × 8 % − 1.300.000 × 0,35 % (Zurechnung `full`) | 53.842,28 €/a = 2,804285 €/m²·Monat | **Konzept F14** (Memo 07: 55.651,59) |
| S1-T4a | nach Teilkappung Heizungsanteil (`heizung` 15.276,37 → 0,50 €/m² = 9.600,00; `huelle` 32.418,90; `lueftung` 6.147,02) | 48.165,91 €/a = 2,508641 €/m²·Monat | WS-S, F14 (neu) |
| S1-T5 | nach Gesamtkappe 2,00 €/m² (Miete 6,20 < 7,00): proportional `huelle` 25.845,78, `lueftung` 4.900,67, `heizung` 7.653,55 | 38.400,00 €/a | Memo 07, 01b 1.9.5 |
| S1-T6 | angesetzte Umlage (Beschluss 1,10 €/m²) ab 2028-01-01 | 21.120,00 €/a | Memo 07 |
| S1-T7 | Annuität V1 (427.185 @ 4 %, 20 J.) / Restschuld 31.12.2036 / Anschluss 4,00 % | 31.433,02 / 254.949,95 / 31.433,02 €/a | Memo 07 |
| S1-T7a | Sensitivität Anschluss 4,25 % | 31.825,43 €/a | Memo 07 |
| S1-T8 | KfW-Zinsen 2027 / 2028–2031 / Annuität ab 2032 (Laufzeitverkürzung) / Restschuld 31.12.2036 / Annuitätenjahre | 47.450,00 / 42.179,40 / 80.165,66 €/a / 951.288,32 / 21 | Memo 07 |
| S1-T8a | Alternative `reduce_installment`: Annuität / Restschuld 31.12.2036 | 71.261,11 €/a / 999.182,07 | Memo 07 |
| S1-T9 | CO2-Intensität Bestand (280.000 × 0,181 / 1.600) / Vermieteranteil 2027 | 31,675 kg/m²·a (31,7) / 40 % | Memo 07 |
| S1-T10 | Vermieteranteil CO2 V1 ab 2028 (§ 5a, Kessel 2027-10-01) | 50 % | Memo 07 |
| S1-T11 | t = 0: Mittelverwendung = Mittelherkunft; V1: 577.185 = 150.000 + 427.185 (Geldanlage 1.488,50); V2: 1.451.488,50 = 151.488,50 + 1.300.000 | Invariante | Memo 07 |
| S1-T12 | höherer CO2-Preis (Set `co2_hoch`) ⇒ `delta_vs_reference` (V2) steigt | Monotonie | Memo 07 |
| S1-T13 | Verwaltung 2027 / 2028 (8.808 × 1,028; × 1,022) | 9.054,62 / 9.253,83 | 01b O-1 |
| S1-T14 | WP-Strom V2 ab 2028 (120.000 / 2,9) / Gas V1 ab 2028 (242.250 / 0,95) / Gas 2027 (9 Monate Altbestand) | 41.379,31 / 255.000,00 / 210.000,00 kWh | Memo 07 |
| S1-T15 | Pflichtsensitivität `stufe_2045`: `shared.v1_wp_2047` = 1, Ersatz 2047 = 300.000 (Kostenstand 2027), Zustand `ersatz2047` zu 100 % Wärmepumpe | Strukturtest | Konzept S1 |
| S1-T16 | Instandhaltung V1 2027 (14,40 × 1.600 × 1,04) / V2 2028 (10,00 × 1.600 × 1,04 × 1,03) / V2 2043 (14,40 × 1.600 × 1,04 × 1,03^16) | 23.961,60 / 17.139,20 / 38.451,33 | Teil A M1, M5 |

**MC-Erwartungen S1:** (m1) Mittel der Eingänge: Kosten V2 1.657.116,04 (PERT-Mittel 1,1416667), V1 615.664,00
(1,0666667), JAZ 2,9333, Nutzwärme 122.666,67 kWh, Liegenschaftszins 0,0350222, RND V1 15 / V2 25, CO2 2030 116,67 /
2040 176,67 €/t; Spearman(cost_factor_v1, cost_factor_v2) 0,70 ± 0,02. (m2) Gleiche Schlüssel `vacancy`, `rnd_rv`
in V1 und V2: identische Uniforms je Lauf (CRN-Test). (m3) Degenerierte Verteilungen (min = mode = max = Basis,
σ = 0) ⇒ jeder Lauf = deterministischer Basisfall (Spec 00 §15.5 Nr. 2). (m4) Hypothesen (Memo 07, F20 neu zu
prüfen): P(`delta_vs_reference_ex_rv` > 0) klein (< 0,2), P(`delta_vs_reference` > 0) > 0,5; die drei stärksten
Treiber im Tornado sind RND, Liegenschaftszins und Kostenfaktor V2; Vorzeichenwechsel bei RND V2 ≲ 18 J. bzw.
LZ ≳ 4,5 % (`vofi_solve(param = "residual_value.income_value.remaining_life_years", variant = "v2_eh70")`). Ampel höchstens Gelb wegen der
Restwertregel (Spec 00 §12.9).

### 5.2 S2 – Kommunales WU: Neubau MFH 36 WE mit KfW 298, Anschlussfinanzierung, Entscheidungsknoten (40 Jahre)

Quelle Memo 07 §4.2, Konzept §9 S2 (Entscheidungsknoten EH-55-Stufe mit Ausweichvariante V1b, DSCR ab 2029).
Basis = V1 (EH 55 mit KfW 298 EH-55-Stufe), Varianten `v1b_ohne_kfw` (Ausweichvariante) und `v2_eh40_qng`.
Testkonvention (Memo 07): Das Bankdarlehen ist voll zum Stichtag ausgezahlt (Restschuld S2-T6 setzt zehn
Jahresraten ab 2027 voraus); der KfW-Kredit folgt dem Zahlungsplan der Maßnahmen (40 % Ende 2027, 60 % Ende 2028,
Teil B 4.6; Bereitstellungsprovision 0 in der Freizeit); Überschüsse der Bauphase liegen als Geldanlage zu 2,0 %.

```yaml
# inst/extdata/examples/s2_wu_neubau_mfh_36we.yaml
schema_version: 1
meta:
  scenario_id: s2_wu_neubau_mfh_36we
  title: "S2 – Kommunales Wohnungsunternehmen: Neubau MFH 36 WE mit KfW 298 und Anschlussfinanzierung"
  author: "WS-S (Referenzszenario, Memo 07 §4.2)"
  created_date: 2026-10-25
  tags: [referenzszenario, s2, neubau, entscheidungsknoten]
project:
  perspective: wu_kommunal
  project_type: neubau
  comparison_mode: absolute
  valuation_date: 2027-01-01
  horizon_years: 40                         # 2027-2066, Horizontende 2067-01-01
  application_date: 2026-12-15              # Antrag EH-55-Stufe bis 31.12.2026, Baugenehmigung liegt vor
  legal_state: 2026-10-25
  price_base_year: 2026
  construction_delay_months: 0
  reference_variant: base                   # V1
  report_mode: expert
grid: {construction_months: 24, construction_step_months: 12}   # Bauzeit 2027-2028, Bezug 2029-01-01
building:
  building_type: MFH
  construction_year: 2028
  n_units: 36                               # 12 x 50 + 18 x 65 + 6 x 105 m2
  living_area_m2: 2400
  efficiency_standard_after: eh55
  land_value_eur: 900000                    # Memo 07: Bodenwert 900.000 (inkl. Nebenkosten) x 1,015^40
  maintenance:                              # Jahre 1-5 nach Bezug 4,00; 6-15: 9,00; ab 16: 14,40 EUR/m2 a (Preisbasis 2026)
    rate_eur_m2_pa: {series: {2029: {expr: "4.00 * shared.maintenance_factor"}, 2034: {expr: "9.00 * shared.maintenance_factor"}, 2044: {expr: "14.40 * shared.maintenance_factor"}}, fill: locf, before: first}
    excludes_explicit_replacements: true
unit_groups:
  wohnen:
    label: "36 WE Neubau"
    n_units: 36
    living_area_m2: 2400
    rent_regime: paragraph_558
    rent_eur_m2_month: {ref: shared.rent_initial}   # Erstvermietungsmiete 13,00 ab rent_start (Token completion)
    increase_policy: fixed_growth
    rent_growth: 0.02
    growth_from: 2030-01-01
    vacancy_rate: {series: {2029: 0, 2030: 0.01}, fill: locf, before: first}
    rent_default_rate: {series: {2029: 0, 2030: 0.01}, fill: locf, before: first}
    extra_loss_share: {series: {2029: 0.08, 2030: 0}, fill: locf, before: first}   # Erstvermietungsabschlag 2029
    lease_up_months: 0
    operating:
      admin_per_unit_eur_pa: 367            # 13.212 EUR/a (2026), VPI
      nonrecoverable_share_of_rent: 0.01
measures:
  grundstueck:
    label: "Grundstück 2.000 m2 x 420 EUR inkl. 7,14 % Erwerbsnebenkosten (pauschal)"
    measure_type: erwerb_grundstueck
    date: 2027-01-01
    purchase_price_eur: 900000              # Memo 07: 840.000 + 60.000 Nebenkosten als Gesamtbetrag
    grest_rate: 0                           # in den pauschalen Nebenkosten enthalten (W: Abweichung vom Landessatz)
    notary_share: 0
    land_registry_share: 0
  bauwerk:
    label: "Bauwerk KG 300+400 (3.600 EUR/m2)"
    measure_type: neubau
    payment_schedule: {schedule: {2027-12-31: 0.40, 2028-12-31: 0.60}, unit: share}
    completion_date: 2029-01-01
    cost_eur: 8640000
    cost_factor: {ref: shared.cost_factor_bau}
    price_index: 0                          # Kostenstand 2027/28 nominal
  nebenkosten:
    label: "Herrichten/Erschließung KG 200, Außenanlagen KG 500, Baunebenkosten KG 700 (20 %)"
    measure_type: baunebenkosten
    payment_schedule: {schedule: {2027-12-31: 0.40, 2028-12-31: 0.60}, unit: share}
    completion_date: 2029-01-01
    cost_eur: 2160000                       # 144.000 + 288.000 + 1.728.000
    cost_factor: 1
    price_index: 0
  ersatz_wp_2049:
    label: "WP-Ersatz"
    measure_type: heizung_waermepumpe_luft
    year: 2049
    cost_eur: 160000                        # V2: 150.000
    price_base_year: 2025                   # Preisbasis 2026 (5.0 Nr. 4)
    classification: erhaltung
    useful_life_years: 20
  aufzug_2054:
    label: "Aufzug-Modernisierung"
    measure_type: aufzug
    year: 2054
    cost_eur: 60000
    price_base_year: 2025
    classification: erhaltung
    useful_life_years: 25
shared:
  from: prices/referenzszenarien_2026
  use: shared
  rent_initial: 13.00
  green_premium_v2: 0
  cost_factor_bau: 1
  maintenance_factor: 1
energy:
  carriers:
    heatpump_power_mfh: {}
  after:                                    # Neubau: Zustand ab Fertigstellung (Token completion)
    demand_kwh: 120000                      # D: 50 kWh/m2 a (EH 55, wie S5 V1)
    heating_carrier: heatpump_power_mfh
    jaz: 3.0                                # D
    flow_temperature_c: 35
    service_eur_pa: 2016.80672269           # D
components:
  stellplaetze:
    type: recurring
    label: "Stellplatzmiete 24 x 35 EUR/Monat"
    category: operating_income
    amount_eur: 10080
    growth: 0.02
    base_date: 2030-01-01                   # 2029: 10.080 EUR (S2-T7)
    from: completion
financing:
  ek: {type: equity, amount_eur: 3000000}
  bank:
    type: annuity_loan
    label: "Kapitalmarktdarlehen"
    amount_eur: 5100000                     # V1b: 8.700.000; V2: 3.858.400
    start: 2027-01-01                       # Testkonvention: voll zum Stichtag (S2-T6)
    rate_pa: 0.04
    initial_repayment_pa: 0.02              # Annuität 306.000 EUR/a
    fixed_years: 10
    payments_per_year: 1
    followup_rate_pa: {ref: market.mortgage_rate}
    refi_rule: keep_payment                 # Fortführung mit gleicher Rate bis Volltilgung
funding:
  kfw298:
    from: funding/kfw_298_khn_eh55_stufe    # 100.000 EUR/WE, 35/5/10, 2,19 %; approval_probability 0,80 (Bibliothek)
    measures: [bauwerk, nebenkosten]
    application_date: 2026-12-15
    amount_eur: 3600000
    loan_variant: v35_5_10
    loan: {payments_per_year: 1}            # Spec 00 §15.6
    approval_timing: before_start
    fallback_variant: v1b_ohne_kfw          # Entscheidungsknoten (Spec 00 §9.11)
accounts:
  deposit_rate_pa: {ref: market.mortgage_rate, anchor: 0.02}     # Szenarioeinstellung (F18)
  overdraft_rate_pa: {ref: market.mortgage_rate, anchor: 0.055}
market:
  from: prices/referenzszenarien_2026
  use: market
residual_value:
  method: income_value
  sale_cost_share: 0.03
  income_value:
    cap_rate: 0.030
    remaining_life_method: manual
    remaining_life_years: 42                # GND 80 - Alter 38
tax: {module: none}
analysis:
  stabilization_year: 2029
stochastic:
  settings: {n_sim: 10000, seed: 20261025, sampling: lhs, block_size: 200, store: bands}
  processes:
    mortgage_rate: {target: market.mortgage_rate, from: processes/mortgage_rate_vasicek_2026}   # gemeinsamer Pfad für 2037 und 2047
    inflation: {target: market.inflation, from: processes/inflation_ar1_2026}
    energy_price_heatpump_power_mfh: {target: market.energy_price.heatpump_power_mfh, from: processes/energy_prices_mr_2026, use: heatpump_power_mfh}
  parameters:
    cost_construction: {target: shared.cost_factor_bau, label: "Baukostenabweichung Bauwerk", from: processes/cost_risks_2026, use: overrun_newbuild, apply: replace}
    delay_construction: {target: project.construction_delay_months, label: "Bauzeitverzug", from: processes/cost_risks_2026, use: delay_newbuild}
    rent_initial: {target: shared.rent_initial, label: "Erstvermietungsmiete", dist: normal, mean: 13.00, sd: 0.80}
    rent_growth: {target: unit_groups.wohnen.rent_growth, label: "Mietsteigerung", dist: normal, mean: 0.02, sd: 0.007}
    cap_rate_rv: {target: residual_value.income_value.cap_rate, label: "Liegenschaftszins 2066", dist: truncnorm, mean: 0.030, sd: 0.005, lower: 0.02, upper: 0.06}
    maintenance_factor: {target: shared.maintenance_factor, label: "Instandhaltungsniveau", dist: triangular, min: 0.8, mode: 1.0, max: 1.3}
    construction_price_shift: {target: shared.construction_price_shift, label: "Abweichung Baupreisindex p. a.", dist: normal, mean: 0, sd: 0.012}
    # funding.kfw298.approved: automatisch Bernoulli(0,80), Rolle decision (Spec 00 §11.6 Nr. 4)
  correlations:
    parameters: [[delay_construction, cost_construction, 0.5]]
    shocks: {from: processes/shock_correlations_2026}
variants:
  v1b_ohne_kfw:
    label: "V1b EH 55 ohne KfW (EH-55-Stufe nicht verfügbar)"
    remove: [funding.kfw298]
    set: {financing.bank.amount_eur: 8700000}   # Annuität 522.000 EUR/a
  v2_eh40_qng:
    label: "V2 EH 40 + QNG mit KfW 298 (150.000 EUR/WE), PV 40 kWp, Lüftung mit WRG"
    remove: [funding.kfw298]
    set:
      building.efficiency_standard_after: eh40
      measures.bauwerk.cost_eur: 9072000                                   # +5 %
      measures.nebenkosten.cost_eur: 2286400                               # 144.000 + 288.000 + 1.814.400 + QNG/LCA 40.000
      measures.ersatz_wp_2049.cost_eur: 150000
      financing.bank.amount_eur: 3858400                                   # Annuität 231.504 EUR/a
      unit_groups.wohnen.rent_eur_m2_month: {expr: "shared.rent_initial + shared.green_premium_v2"}
      energy.after.demand_kwh: 84000                                       # D: 35 kWh/m2 a
      energy.after.jaz: 3.2                                                # D
    add:
      funding.kfw298_qng:
        from: funding/kfw_298_khn_vermietung  # EH 40 + QNG: 150.000 EUR/WE, 35/5/10, 2,94 %
        measures: [bauwerk, nebenkosten]
        application_date: 2026-12-15
        amount_eur: 5400000
        facts: {qng: true}
        loan_variant: v35_5_10
        loan: {payments_per_year: 1}
        approval_probability: 1.0           # Memo 07: Risiko nur für die EH-55-Stufe
      measures.pv:
        label: "PV-Anlage 40 kWp"
        measure_type: pv
        payment_schedule: {schedule: {2028-12-31: 1.0}, unit: share}
        completion_date: 2029-01-01
        cost_eur: 44000                     # 1.100 EUR/kWp netto (costs/anlagentechnik_marktpreise_2026)
        vat_rate: 0                         # mit Begünstigungsnachweis (> 30 kWp, R-84)
        price_index: 0
        useful_life_years: 25
        replacement: {enabled: false}
      measures.wechselrichter_2044:
        label: "Wechselrichtertausch PV"
        measure_type: pv_wechselrichter
        year: 2044
        cost_eur: 6000
        price_base_year: 2025
        classification: erhaltung
        useful_life_years: 12
      energy.pv:
        kwp: 40
        measure: pv
        specific_yield_kwh_kwp: 950
        self_consumption_share: 0.30        # D: WP und Allgemeinstrom
        feed_in_tariff_eur_kwh: 0.0640      # D: 6,66 ct x 0,99^4 (IBN 01/2029)
        vat_zero_rate_attested: true
      stochastic.parameters.green_premium_v2: {target: shared.green_premium_v2, label: "Green Premium EH 40", dist: uniform, min: 0, max: 0.30}
```

Die Bauwerkskosten V2 sind ohne PV angegeben (Memo 07: PV in der Bauwerkssumme „+5 %“ enthalten; hier getrennt
ausgewiesen, D). Mit PV-Anlage 44.000 € steigt die V2-Summe auf 12.302.400 €; für S2-T1 (12.258.400 €) zählt WS-S
die Maßnahme `pv` nicht mit (Test über `measure_id`).

**Prüfwerte S2 (deterministisch):**

| Nr. | Größe | Soll | Herkunft |
|---|---|---:|---|
| S2-T1 | Gesamtkosten V1 / V2 (ohne `pv`) | 11.700.000 / 12.258.400 | Memo 07 |
| S2-T2 | KfW-Beträge V1 / V2 (100.000 bzw. 150.000 €/WE × 36) | 3.600.000 / 5.400.000 | Memo 07 |
| S2-T3 | Bankdarlehen V1 / V1b / V2 | 5.100.000 / 8.700.000 / 3.858.400 | Memo 07 |
| S2-T4 | KfW-Zinsen tilgungsfreie Jahre mit Vollauszahlung (2029–2033) V1 / V2; 2028 auf 40 % | 78.840,00 / 158.760,00 €/a; 31.536,00 / 63.504,00 | Memo 07; WS-S |
| S2-T4a | KfW-Annuität ab 2034 (30 J. nach 5 tilgungsfreien Jahren ab letzter Auszahlung) V1 / V2 | 164.969,40 / 273.371,56 €/a | Memo 07 |
| S2-T5 | Bank-Annuität V1 / V1b / V2 | 306.000 / 522.000 / 231.504 €/a | Memo 07 |
| S2-T6 | Restschuld Bank 31.12.2036 V1 / V2 | 3.875.377,07 (±1) / 2.931.912,73 (±1) | Memo 07 |
| S2-T7 | Rohertrag Soll 2029 (2.400 × 13,00 × 12 + 10.080) | 384.480,00 | Memo 07 |
| S2-T8 | Mieterträge 2027 und 2028 | 0 | Memo 07 |
| S2-T9 | Verwaltung 2029 (13.212 × 1,028 × 1,022²) | 14.186,11 | 01b O-1 |
| S2-T10 | Entscheidungsknoten deterministisch: Zweig b = 1 → Ergebnis V1; unter `foerderstopp`: b = 0 → Ergebnis V1b, `decision$alternative` = V1 | Strukturtest | Spec 00 §9.11 |
| S2-T11 | Vergleichbarkeit V1/V2: gleiches Horizontende 2067-01-01, Raster gleich | Strukturtest | R-67 |

**MC-Erwartungen S2:** (m1) Zusageschlüssel `funding.kfw298.approved` (Bernoulli 0,8, Rolle `decision`): je Block
exakt 160 von 200 Zusagen, `decision$share_approved` = 0,80 exakt; Kompositum je Lauf = V1 bei b_i = 1, V1b bei
b_i = 0 (Spec 00 §15.5 Nr. 11); `decision$stats_approved` = Statistik einer getrennten MC von V1. (m2) Eingänge:
Kostenfaktor Mittel 1,0833333 (Bauwerk V1 9.360.000), Verzug 3,3333 Monate, Spearman(Verzug, Kosten) 0,50 ± 0,02,
Erstvermietungsmiete 13,00 (sd 0,80), Instandhaltungsfaktor 1,0333, Liegenschaftszins 0,0302762 (trunkiert, sd
0,0047076), Green Premium 0,15. (m3) Hypothesen (Memo 07, F20): V1 > V2 (P(`delta_vs_reference`(V2) < 0) > 0,5,
gerechnet gegen das Kompositum), V2 > V1b; Streuung dominiert vom Anschlusszins 2037 (globale Sensitivität:
`mortgage_rate.at2037` größter Beitrag); Break-even-Miete für `roe_mirr` = 4 % (`vofi_solve(param =
"shared.rent_initial", kpi = "roe_mirr", target = 0.04)`) im Bereich 15–17 €/m².

### 5.3 S3 – Genossenschaft: Heizungstausch Gas → Wärmepumpe + PV 30 kWp, 12 WE (20 Jahre)

Quelle Memo 07 §4.3, Konzept §9 S3, F13, B3, P5. Basis = V1 Gas-Brennwert (Ohnehin), Variante `v2_wp_pv`, Testvariante
`v2_jaz_test` (Plan-JAZ 2,4, Vorlauf 70 °C: § 559f-Ausnahme nicht erfüllt). Abweichung von Memo 07 nach Konzept B3:
PV-Strom an Mitglieder 0 ct (`internal_price_eur_kwh: 0`); die Memo-Annahme 20 ct steht als Set `pv_verrechnung_20ct`.

```yaml
# inst/extdata/examples/s3_eg_waermepumpe_pv.yaml
schema_version: 1
meta:
  scenario_id: s3_eg_waermepumpe_pv
  title: "S3 – Genossenschaft: Heizungstausch Gas auf Wärmepumpe mit PV im 12-WE-Gebäude (§ 559e)"
  author: "WS-S (Referenzszenario, Memo 07 §4.3)"
  created_date: 2026-10-25
  tags: [referenzszenario, s3, bestand, heizungstausch, genossenschaft]
project:
  perspective: wu_genossenschaft
  project_type: heizungstausch
  comparison_mode: absolute
  valuation_date: 2027-01-01
  horizon_years: 20                         # 2027-2046, Horizontende 2047-01-01
  application_date: 2027-01-15              # KfW 459 vor Absenkung zum 01.02.2027
  legal_state: 2026-10-25
  price_base_year: 2026
  reference_variant: base                   # V1 Gas-Brennwert (Ohnehin)
  report_mode: expert
grid: {construction_months: 0}
building:
  building_type: MFH
  construction_year: 1985
  n_units: 12
  living_area_m2: 840
  heating_existing: {carrier: gas_mfh, installation_year: 2002}   # Vorlauf 70 °C, Heizlast ≈ 42 kW
  consumption_kwh: {gas_mfh: 109200}
unit_groups:
  mitglieder:
    label: "12 Genossenschaftswohnungen"
    n_units: 12
    living_area_m2: 840
    rent_regime: cooperative_fee
    rent_eur_m2_month: 6.40                 # Nutzungsentgelt, 64.512 EUR/a
    increase_policy: fixed_growth
    rent_growth: 0.015
    growth_from: 2028-01-01
    vacancy_rate: 0.01
    rent_default_rate: 0
    rent_law:
      modernization_levy: auto
      voluntary_cap_per_m2: null            # V2: 0.35 (Vorstandsbeschluss)
      hardship_share: 0
measures:
  gas_bw:
    label: "Gas-Brennwertkessel inkl. Abgas und Planung (Ohnehin)"
    measure_type: heizung_gaskessel
    year: 2027
    completion_date: 2027-10-01
    cost_eur: 45360                         # 38.000 + 4.000 + 8 % Planung
    ohnehin_share: 1
    classification: erhaltung
    useful_life_years: 20                   # Memo 07 (F19)
shared:
  from: prices/referenzszenarien_2026
  use: shared
  cost_factor_v2: 1
energy:
  carriers:
    gas_mfh: {emission_factor_kg_kwh: 0.181}
    heatpump_power_mfh: {}
  before:
    efficiency: 0.87                        # 109.200 kWh -> Nutzwärme 95.004 kWh
    flow_temperature_c: 70
    service_eur_pa: 714.28571429            # 600 + 250 EUR brutto
  after:
    measure: gas_bw
    demand_kwh: 95000                       # -> 100.000 kWh Gas bei η 0,95
    heating_carrier: gas_mfh
    efficiency: 0.95
financing:
  ek: {type: equity, amount_eur: 50000}     # V1: 45.360 eingesetzt, Rest Geldanlage
accounts:
  deposit_rate_pa: {ref: market.mortgage_rate, anchor: 0.02}     # Mindestverzinsung (= Profil wu_genossenschaft)
  overdraft_rate_pa: {ref: market.mortgage_rate, anchor: 0.055}
market:
  from: prices/referenzszenarien_2026
  use: market
  co2_price: {from: prices/co2_price_path_referenzszenarien_2026}
  pv_internal_price_s3: 0                   # Verrechnungspreis PV-Strom an Mitglieder (Konzept B3); Set pv_verrechnung_20ct
residual_value:
  method: component                         # linearer Komponentenzeitwert, kein Gebäudewerteffekt (= Profil für heizungstausch)
  sale_cost_share: 0
  component: {indexed: false}               # Memo 07 nominal (S3-T8; Teil A OP-02)
tax: {module: none}
analysis:
  stabilization_year: 2028
stochastic:
  settings: {n_sim: 10000, seed: 20261025, sampling: lhs, block_size: 200, store: bands}
  processes:
    inflation: {target: market.inflation, from: processes/inflation_ar1_2026}
    energy_price_gas_mfh: {target: market.energy_price.gas_mfh, from: processes/energy_prices_mr_2026, use: gas_mfh}
    energy_price_heatpump_power_mfh: {target: market.energy_price.heatpump_power_mfh, from: processes/energy_prices_mr_2026, use: heatpump_power_mfh}
  parameters:
    co2_2030: {target: shared.co2_2030, label: "CO2-Preis 2030", dist: triangular, min: 60, mode: 90, max: 200}
    co2_2040: {target: shared.co2_2040, label: "CO2-Preis 2040", dist: triangular, min: 80, mode: 150, max: 300}
    network_fee_growth_gas_mfh: {target: shared.network_fee_growth_gas_mfh, from: processes/energy_prices_mr_2026, use: network_fee_growth}
    bio_premium_factor: {target: shared.bio_premium_factor, from: processes/energy_prices_mr_2026, use: bio_premium_factor, apply: replace}
    hardship: {target: unit_groups.mitglieder.rent_law.hardship_share, label: "Anteil WE mit Härtefall", dist: beta, mean: 0.05, sd: 0.03}
  correlations:
    parameters: [[co2_2030, co2_2040, 0.8]]
    shocks: {from: processes/shock_correlations_2026}
variants:
  v2_wp_pv:
    label: "V2 Wärmepumpen-Kaskade mit PV 30 kWp (KfW 459, § 559e)"
    remove: [measures.gas_bw]
    replace:
      energy.after:
        measure: heizung_wp
        demand_kwh: 95000
        heating_carrier: heatpump_power_mfh
        jaz: 3.1
        jaz_plan: 3.1
        flow_temperature_c: 55
        service_eur_pa: 756.30252101        # 900 EUR brutto
    set:
      unit_groups.mitglieder.rent_law.voluntary_cap_per_m2: 0.35   # Beschluss: 3.528 EUR/a ab 2028
    add:
      measures.heizung_wp:
        label: "WP-Kaskade 2 x 22 kW, Heizkörper, Frischwasserstation, Elektro, Demontage, Planung"
        measure_type: heizung_waermepumpe_luft
        year: 2027
        completion_date: 2027-10-01
        cost_eur: 153560                    # 88.000 + 21.600 + 18.000 + 8.000 + 4.000 + 10 % = 13.960
        cost_factor: {ref: shared.cost_factor_v2}
        ohnehin_cost_eur: 45360             # nur für den Rückfall auf § 559 (01b 1.9.2)
        modernization_kind: bgb_555b_1a     # Verfahren auto -> § 559e (Drittmittel)
        useful_life_years: 20               # Memo 07 (F19)
      measures.pv:
        label: "PV 30 kWp (1.150 EUR/kWp) + Messkonzept"
        measure_type: pv
        year: 2027
        completion_date: 2027-01-01         # IBN bis 31.01.2027 (Vergütungssatz), 20 Jahre genutzt
        cost_eur: 38500
        cost_factor: {ref: shared.cost_factor_v2}
        vat_rate: 0                         # § 12 Abs. 3 UStG (<= 30 kWp)
        useful_life_years: 25
      energy.pv:
        kwp: 30
        measure: pv
        commissioning_date: 2027-01-01
        specific_yield_kwh_kwp: 900
        self_consumption_share: 0.30        # WP und Allgemeinstrom
        tariff_years: 20                    # Vergütung (10 x 7,70 + 20 x 6,66)/30 = 7,0067 ct (Default-Ausdruck 01b 3.9.1)
        internal_price_eur_kwh: {ref: market.pv_internal_price_s3}   # Konzept B3: 0 (Memo 07: 0,20)
        opex_share_of_cost: 0.015           # 577,50 EUR/a
      funding.kfw459:
        from: funding/kfw_459_heizung_unternehmen
        measures: [heizung_wp]
        application_date: 2027-01-15
        payout: {lag_months: 3}             # Auszahlung 2028-01-01 (01b F-1)
        approval_probability: 1.0           # Memo 07: kein Zusagerisiko
      financing.bank:
        type: annuity_loan
        label: "Bankdarlehen"
        amount_eur: 142060
        start: 2027-01-01
        rate_pa: 0.039
        term_years: 15
        fixed_years: 15
        payments_per_year: 1
      stochastic.parameters.jaz: {target: energy.after.jaz, label: "JAZ realisiert", dist: triangular, min: 2.6, mode: 3.1, max: 3.4}
      stochastic.parameters.pv_self_share: {target: energy.pv.self_consumption_share, label: "Eigenverbrauchsquote PV", dist: triangular, min: 0.20, mode: 0.30, max: 0.40}
      stochastic.parameters.pv_yield: {target: energy.pv.specific_yield_kwh_kwp, label: "PV-Ertrag", dist: normal, mean: 900, sd: 60}
      stochastic.parameters.cost_factor_v2: {target: shared.cost_factor_v2, label: "Kostenabweichung Komponententausch", from: processes/cost_risks_2026, use: overrun_component, apply: replace}
  v2_jaz_test:
    label: "Testfall § 559f: Plan-JAZ 2,4, Vorlauf 70 °C"
    extends: v2_wp_pv
    set:
      project.pending_reforms: [unreleased]   # Thema mietrecht_559f ist C ohne Freigabe (Spec 00 §4.10)
      energy.after.jaz_plan: 2.4
      energy.after.flow_temperature_c: 70
      unit_groups.mitglieder.rent_law.voluntary_cap_per_m2: null
scenario_sets:
  pv_verrechnung_20ct:
    label: "PV-Strom an Mitglieder zu 20 ct/kWh (Memo 07, rechtlich prüfen)"
    set: {market.pv_internal_price_s3: 0.20}
```

Szenario-Sets dürfen `energy` nicht ändern (Spec 00 §4.11); deshalb verweist `energy.pv.internal_price_eur_kwh` auf
den szenarioeigenen Marktpfad `market.pv_internal_price_s3`, den das Set setzt (Muster für Sets auf Domänenwerte).

**Prüfwerte S3 (deterministisch):**

| Nr. | Größe | Soll | Herkunft |
|---|---|---:|---|
| S3-T1 | förderfähige Höchstkosten 12 WE (28.000 + 5 × 15.000 + 6 × 8.000) | 151.000 | Memo 07 |
| S3-T2 | Zuschuss KfW 459 (30 % × min(153.560; 151.000)), Auszahlung 2028-01-01 | 45.300,00 | Memo 07 |
| S3-T3 | § 559e rechnerisch 0,10 × (0,85 × 153.560 − 45.300) / gekappt 0,50 €/m² / angesetzt 0,35 €/m² | 8.522,60 / 5.040,00 / 3.528,00 €/a | **Konzept F13** (Memo 07: 9.202,10) |
| S3-T4 | `v2_jaz_test` (§ 559f, Thema `mietrecht_559f` über `pending_reforms: [unreleased]` aktiv): `halve_then_funds` 0,10 × (0,85 × 76.780 − 45.300) / `funds_then_halve` 0,5 × 0,10 × (0,85 × 153.560 − 45.300) | 1.996,30 / 4.261,30 €/a | **Konzept F13** (Memo 07: 2.675,80 / 4.601,05); 01b L-4 |
| S3-T4a | V2 mit Plan-JAZ 3,1 und Vorlauf 55 °C: keine Halbierung (Ausnahme bzw. JAZ ≥ 2,5) | = S3-T3 | Konzept P5 |
| S3-T5 | CO2-Stufe Bestand (109.200 × 0,181 / 840) | 23,53 kg/m²·a → 30 % | Memo 07 |
| S3-T6 | Einspeiseerlös PV (18.900 kWh × 7,00667 ct) | 1.324,26 €/a | Memo 07 |
| S3-T7 | Annuität Bankdarlehen (142.060 @ 3,9 %, 15 J.) | 12.687,85 €/a | Memo 07 |
| S3-T8 | Restwert 2047-01-01: PV 5/25 × 38.500 / WP (0,75/20 × 153.560) / Kessel V1 (0,75/20 × 45.360) | 7.700,00 / 5.758,50 / 1.701,00 | Memo 07 (PV); WS-S (Fertigstellung 2027-10-01, Memo rundet auf null) |
| S3-T9 | WP-Strom V2 (95.000 / 3,1) / PV-Eigenverbrauch / Netzbezug | 30.645,16 / 8.100,00 / 22.545,16 kWh | Memo 07 |
| S3-T10 | Heizkosten Mitglieder (Preisbasis 2026): V1 100.000 × 11,20234 ct + 850 / V2 22.545,16 × 25 ct + 900 | 12.052,34 / 6.536,29 €/a (0,6484 €/m²·Monat) | WS-S (Memo 07: 12.050 bzw. 8.157 mit 20 ct Verrechnung) |
| S3-T11 | PV-Betriebskosten (1,5 % × 38.500) | 577,50 €/a | Memo 07 |

**MC-Erwartungen S3:** (m1) Eingänge: JAZ 3,0333, Eigenverbrauch 0,30, PV-Ertrag 900 (sd 60), Kostenfaktor 1,025,
Härtefall Beta(2,5889; 49,1889) Mittel 0,05. (m2) Die realisierte JAZ ändert die Umlage in keinem Lauf (Plan-JAZ
`deterministic_only`, R-70): `levy_heizung_wp_computed` je Lauf = 0,10 × (0,85 × 153.560 · f − 0,30 × min(153.560 · f;
151.000)) mit dem Kostenfaktor f des Laufs, unabhängig von `jaz`; wegen f ≥ 0,95 in jedem Lauf über der Kappe
(gekappt 5.040 €/a, angesetzt 3.528 €/a). (m3) Hypothesen (Memo 07, F20): `delta_vs_reference`(V2) > 0 mit P > 0,8, Größenordnung +20 bis +60 T€;
Warmmiete der Mitglieder V2 im ersten vollen Jahr leicht unter V1 (`warm_rent_change_y1` < 0, im Mittel
≈ −0,04 €/m²·Monat, mit 0-ct-Verrechnung deutlicher); stärkste Treiber Strompreis, realisierte JAZ, Gaspreis.

### 5.4 S4 – Selbstnutzer EFH 1975: stufenweise Sanierung nach iSFP gegenüber „Gaskessel behalten“ (25 Jahre)

Quelle Memo 07 §4.4, §6.1, Konzept §9 S4, B2, B4, B12. Basis = V0 (Gaskessel behalten, Ersatz bei Ausfall),
Variante `v1_isfp_stufen`, optional `v2_nur_wp`, `v3_alles_2027`. Kostenstand 2026 → `price_base_year: 2025` je
Maßnahme, Baupreisindex 3,0 % ab 2026 (Memo 07: Ausführungskosten = Kosten × 1,03^(Y − 2026)). Ausfalljahr des
Altkessels als Verschiebung `delay_months` der Maßnahme `gaskessel` (Basis 2030, MC 2028–2033); der Heizungsersatz
2050 folgt dieser Verschiebung (Nutzungsdauer 20 J.).

```yaml
# inst/extdata/examples/s4_efh_1975_isfp.yaml
schema_version: 1
meta:
  scenario_id: s4_efh_1975_isfp
  title: "S4 – Selbstnutzer EFH Baujahr 1975: stufenweise Sanierung nach iSFP gegenüber Gaskessel behalten"
  author: "WS-S (Referenzszenario, Memo 07 §4.4)"
  created_date: 2026-10-25
  tags: [referenzszenario, s4, bestand, selbstnutzer, haushaltsmodus]
project:
  perspective: selbstnutzer
  project_type: sanierung_stufenweise
  comparison_mode: absolute
  valuation_date: 2027-01-01
  horizon_years: 25                         # 2027-2051, Horizontende 2052-01-01
  application_date: 2026-12-15              # KfW 458: Bonus 16 % und Höchstkosten 28.000 EUR
  legal_state: 2026-10-25
  price_base_year: 2026                     # laufende Beträge Preisbasis 2026
  reference_variant: base                   # V0 Gaskessel behalten
  report_mode: household
grid: {construction_months: 0}
building:
  building_type: EFH
  construction_year: 1975
  n_units: 1
  living_area_m2: 140
  component_areas_m2: {roof: 160, windows: 28, facade: 180, basement_ceiling: 75}
  heating_existing: {carrier: gas, installation_year: 2005}   # 21 Jahre: Klimageschwindigkeitsbonus
  consumption_kwh: {gas: 24500}             # Hs, Nutzwärme 21.560 kWh (iSFP-Bedarf 230 kWh/m2 a -> Prebound ≈ 0,76)
  isfp_available: true                      # iSFP liegt vor (Bonus BAFA, Default funding.<f>.facts.isfp)
household:
  taxable_income_avg_eur: 58000             # Ø 2023/2024; minus 10.000 je Kind -> 48.000 -> Einkommensbonus 10 %
  n_children_u18: 1
  net_income_month_eur: 4800
  savings_eur: 60000                        # Erspartes (Expander household -> equity)
unit_groups:
  haus:
    label: "Selbstgenutztes EFH"
    n_units: 1
    living_area_m2: 140
    owner_occupied: true
measures:
  gaskessel:
    label: "Gas-Brennwertkessel nach Ausfall des Altkessels"
    measure_type: heizung_gaskessel
    year: 2030
    delay_months: 0                         # MC: -24 ... +36 (Ausfalljahr 2028-2033)
    cost_eur: 12500                         # Kostenstand 2026 -> 14.068,86 (2030)
    price_base_year: 2025
    classification: erhaltung
    useful_life_years: 20
    replacement: {enabled: false}           # Ersatz explizit (wp_2050)
  dach_2032:
    label: "Dach-Neueindeckung mit GModG-Mindestdämmung (U <= 0,24)"
    measure_type: daemmung_dach_steil
    year: 2032
    cost_eur: 40000                         # -> 47.762,09
    price_base_year: 2025
    ohnehin_share: 1
    classification: erhaltung
    useful_life_years: 50
  anstrich_2033:
    label: "Fassadenanstrich inkl. Gerüst"
    measure_type: putz_anstrich
    year: 2033
    cost_eur: 11600                         # -> 14.266,54
    price_base_year: 2025
    classification: erhaltung
    useful_life_years: 15
    replacement: {enabled: false}           # Memo 07 ohne Folgeanstrich 2048
  fenster_2042:
    label: "Fenstertausch 2-fach (U_w 1,3)"
    measure_type: fenster
    year: 2042
    cost_eur: {value: 700, per: "m2_component:windows"}   # 19.600 -> 31.452,25
    price_base_year: 2025
    ohnehin_share: 1
    classification: erhaltung
    useful_life_years: 35
  wp_2050:
    label: "Heizungsersatz durch Wärmepumpe (Ende Nutzungsdauer Kessel)"
    measure_type: heizung_waermepumpe_luft
    year: 2050
    delay_months: {ref: measures.gaskessel.delay_months}
    cost_eur: 32000                         # -> 65.049,41; ohne Förderung (Memo 07)
    price_base_year: 2025
    useful_life_years: 20
shared:
  from: prices/referenzszenarien_2026
  use: shared
  saving_stage2: 0.25
  saving_stage3: 0.28
energy:
  carriers:
    gas: {emission_factor_kg_kwh: 0.181, base_fee_eur_pa: 151.26050420}     # 180 EUR brutto
    heatpump_power: {base_fee_eur_pa: 117.64705882}                         # 140 EUR brutto
  before:
    efficiency: 0.88
    service_eur_pa: 252.10084034            # 300 EUR brutto
  after:
    measure: gaskessel
    demand_kwh: 21560
    heating_carrier: gas                    # neue Heizung: § 43, Bio-Treppe
    efficiency: 0.94
  stages:
    dach:
      measure: dach_2032
      demand_kwh: {expr: "21560 * 0.88"}    # 18.972,8 kWh
    fenster:
      measure: fenster_2042
      demand_kwh: {expr: "21560 * 0.88 * 0.95"}   # 18.024,16 kWh
    wp:
      measure: wp_2050
      heating_carrier: heatpump_power
      jaz: 3.0
      service_eur_pa: 210.08403361          # 250 EUR brutto
financing: {}                               # Einlage aus household.savings_eur (Expander household, 01b)
accounts:
  deposit_rate_pa: 0.025                    # Memo 07; MC: truncnorm (statisch, Memo 07 §4.4)
  overdraft_rate_pa: {ref: market.mortgage_rate, anchor: 0.060}   # Ergänzungskredit
  overdraft_limit_eur: .inf                 # Szenarioeinstellung (Memo 07: Fehlbeträge automatisch; Profil: 0 mit Nachschuss)
  deficit_order: [dep_withdraw, od_draw, equity_call]
market:
  from: prices/referenzszenarien_2026
  use: market
  construction_price_index_base: {series: {2026: 0.030}, fill: locf, before: first}   # 3,0 % ab 2026
  co2_price: {from: prices/co2_price_path_referenzszenarien_2026}
residual_value:
  method: component                         # Zeitwert der Maßnahmen (= Profil selbstnutzer), Pflichtausweis ohne Restwert
  sale_cost_share: 0
tax: {module: none}
stochastic:
  settings: {n_sim: 10000, seed: 20261025, sampling: lhs, block_size: 200, store: bands}
  processes:
    mortgage_rate: {target: market.mortgage_rate, from: processes/mortgage_rate_vasicek_2026}   # Anschluss KfW 358 nach 10 J.
    inflation: {target: market.inflation, from: processes/inflation_ar1_2026}
    energy_price_gas: {target: market.energy_price.gas, from: processes/energy_prices_mr_2026, use: gas}
    energy_price_heatpump_power: {target: market.energy_price.heatpump_power, from: processes/energy_prices_mr_2026, use: heatpump_power}
  parameters:
    co2_2030: {target: shared.co2_2030, label: "CO2-Preis 2030", dist: triangular, min: 60, mode: 90, max: 200}
    co2_2040: {target: shared.co2_2040, label: "CO2-Preis 2040", dist: triangular, min: 80, mode: 150, max: 300}
    network_fee_growth_gas: {target: shared.network_fee_growth_gas, from: processes/energy_prices_mr_2026, use: network_fee_growth}
    bio_premium_factor: {target: shared.bio_premium_factor, from: processes/energy_prices_mr_2026, use: bio_premium_factor, apply: replace}
    construction_price_shift: {target: shared.construction_price_shift, label: "Abweichung Baupreisindex p. a.", dist: normal, mean: 0, sd: 0.012}
    deposit_rate: {target: accounts.deposit_rate_pa, label: "Habenzins", dist: truncnorm, mean: 0.025, sd: 0.0075, lower: 0, upper: 0.06}
    boiler_failure: {target: measures.gaskessel.delay_months, label: "Ausfall Altkessel (Verschiebung ggü. 2030)", dist: discrete, values: [-24, -12, 0, 12, 24, 36]}
  correlations:
    parameters: [[co2_2030, co2_2040, 0.8]]
    shocks: {from: processes/shock_correlations_2026}
variants:
  v1_isfp_stufen:
    label: "V1 iSFP stufenweise: WP 2027, Dach + Fenster 2030, Fassade + Kellerdecke 2033"
    remove: [measures.gaskessel, measures.dach_2032, measures.anstrich_2033, measures.fenster_2042, measures.wp_2050,
             energy.stages, stochastic.parameters.boiler_failure]
    replace:
      energy.after:
        measure: wp_2027
        demand_kwh: 21560
        heating_carrier: heatpump_power
        jaz: 2.9
        service_eur_pa: 210.08403361
    set:
      stochastic.correlations.parameters: [[co2_2030, co2_2040, 0.8], [jaz_s1, jaz_s2, 0.7], [jaz_s2, jaz_s3, 0.7], [jaz_s1, jaz_s3, 0.7]]   # D: dieselbe Anlage
    add:
      measures.wp_2027:
        label: "Luft/Wasser-WP 10 kW inkl. 3 Heizkörper, Demontage"
        measure_type: heizung_waermepumpe_luft
        year: 2027
        cost_eur: 32000                     # -> 32.960,00
        price_base_year: 2025
        useful_life_years: 20
        replacement: {enabled: false}       # Ersatz explizit (wp_ersatz_2047)
      measures.dach_fenster_2030:
        label: "Dach (Aufsparrendämmung, U <= 0,14) und Fenster 3-fach"
        measure_type: daemmung_dach_steil
        year: 2030
        cost_eur: {expr: "building.component_areas_m2.roof * 320 + building.component_areas_m2.windows * 900"}   # 76.400 -> 85.988,87
        price_base_year: 2025
        useful_life_years: 45               # Dach 50, Fenster 35 (kostengewichtet)
      measures.fassade_2033:
        label: "WDVS 16 cm, Kellerdecke, Gerüst"
        measure_type: daemmung_fassade
        year: 2033
        cost_eur: {expr: "building.component_areas_m2.facade * 210 + building.component_areas_m2.basement_ceiling * 50 + 3500"}   # 45.050 -> 55.405,82
        price_base_year: 2025
        useful_life_years: 40
      measures.wp_ersatz_2047:
        label: "WP-Ersatz (Erzeuger)"
        measure_type: heizung_waermepumpe_luft
        year: 2047
        cost_eur: 25000                     # -> 46.507,36
        price_base_year: 2025
        classification: erhaltung
        useful_life_years: 20
      energy.stages:
        stufe2:
          measure: dach_fenster_2030
          demand_kwh: {expr: "21560 * (1 - shared.saving_stage2)"}                               # 16.170
          jaz: 3.2
        stufe3:
          measure: fassade_2033
          demand_kwh: {expr: "21560 * (1 - shared.saving_stage2) * (1 - shared.saving_stage3)"}  # 11.642,4
          jaz: 3.5
      funding.kfw458_wp:
        from: funding/kfw_458_heizung_privat
        measures: [wp_2027]
        application_date: 2026-12-15
        payout: {lag_months: 12}            # Auszahlung 2028-01-01
        approval_probability: 1.0
      funding.bafa_2030:
        from: funding/bafa_beg_em_huelle    # iSFP-Bonus nur auf den Betrag > 30.000 (Default, Konzept B2)
        measures: [dach_fenster_2030]
        application_date: 2029-12-01
        payout: {lag_months: 12}            # 2031-01-01
        approval_probability: 1.0
      funding.bafa_2033:
        from: funding/bafa_beg_em_huelle
        measures: [fassade_2033]
        application_date: 2032-12-01        # approval_timing auto -> after_start (einfache Ziehung)
        payout: {lag_months: 12}            # 2034-01-01
        approval_probability: 0.7           # Förderverfügbarkeit nach 2030 (Konzept B12)
        on_reject: balance
      funding.kfw358_2030:
        from: funding/kfw_358_ergaenzungskredit_plus
        measures: [dach_fenster_2030]
        application_date: 2029-12-01
        amount_eur: 70000
        loan_variant: v25_3_10              # 25/3/10, 2,53 %; Auszahlung zum Maßnahmentermin 2030-01-01
        loan: {payments_per_year: 1}
        approval_probability: 1.0
      funding.kfw358_2033:
        from: funding/kfw_358_ergaenzungskredit_plus
        measures: [fassade_2033]
        application_date: 2032-12-01
        amount_eur: 45000
        loan_variant: v25_3_10
        loan: {payments_per_year: 1}
        approved: {ref: funding.bafa_2033.approved}   # Ergänzungskredit nur mit BEG-EM-Förderung
        approval_probability: 1.0
      stochastic.parameters.saving_stage2: {target: shared.saving_stage2, label: "Einsparwirkung Stufe 2", dist: triangular, min: 0.18, mode: 0.25, max: 0.30}
      stochastic.parameters.saving_stage3: {target: shared.saving_stage3, label: "Einsparwirkung Stufe 3", dist: triangular, min: 0.20, mode: 0.28, max: 0.33}
      stochastic.parameters.jaz_s1: {target: energy.after.jaz, label: "JAZ Zustand 1", dist: triangular, min: 2.6, mode: 2.9, max: 3.2}
      stochastic.parameters.jaz_s2: {target: energy.stages.stufe2.jaz, label: "JAZ Zustand 2", dist: triangular, min: 2.9, mode: 3.2, max: 3.5}
      stochastic.parameters.jaz_s3: {target: energy.stages.stufe3.jaz, label: "JAZ Zustand 3", dist: triangular, min: 3.2, mode: 3.5, max: 3.8}
      stochastic.parameters.rate_kfw358_2030: {target: funding.kfw358_2030.loan.variants.v25_3_10.rate_pa, label: "Zins KfW 358 (2030)", dist: truncnorm, mean: 0.0275, sd: 0.0075, lower: 0.01, upper: 0.05}
      stochastic.parameters.rate_kfw358_2033: {target: funding.kfw358_2033.loan.variants.v25_3_10.rate_pa, label: "Zins KfW 358 (2033)", dist: truncnorm, mean: 0.0275, sd: 0.0075, lower: 0.01, upper: 0.05}
  v2_nur_wp:
    label: "V2 nur Wärmepumpe 2027, Hülle zu den Ohnehin-Terminen"
    remove: [measures.gaskessel, measures.wp_2050, stochastic.parameters.boiler_failure]
    replace:
      energy.after:
        measure: wp_2027
        demand_kwh: 21560
        heating_carrier: heatpump_power
        jaz: 2.9
        service_eur_pa: 210.08403361
      energy.stages:
        dach: {measure: dach_2032, demand_kwh: {expr: "21560 * 0.88"}, jaz: 3.0}
        fenster: {measure: fenster_2042, demand_kwh: {expr: "21560 * 0.88 * 0.95"}}
    add:
      measures.wp_2027: {label: "Luft/Wasser-WP 10 kW", measure_type: heizung_waermepumpe_luft, year: 2027, cost_eur: 32000, price_base_year: 2025, useful_life_years: 20, replacement: {enabled: false}}
      measures.wp_ersatz_2047: {label: "WP-Ersatz", measure_type: heizung_waermepumpe_luft, year: 2047, cost_eur: 25000, price_base_year: 2025, classification: erhaltung, useful_life_years: 20}
      funding.kfw458_wp: {from: funding/kfw_458_heizung_privat, measures: [wp_2027], application_date: 2026-12-15, payout: {lag_months: 12}, approval_probability: 1.0}
```

`v3_alles_2027` (optional, Prüfwert Jahresdeckel) entsteht aus `v1_isfp_stufen` mit `year: 2027` für alle Stufen
und je einem BAFA- und KfW-358-Instrument 2027; Prüfwert der Förderung: Hülle 10.500,00 € (förderfähig gedeckelt auf
60.000 € in **einem** Kalenderjahr) + WP 15.680,00 € (Memo 07).

**Prüfwerte S4 (deterministisch):**

| Nr. | Größe | Soll | Herkunft |
|---|---|---:|---|
| S4-T1 | effektives zvE (`taxable_income_adj` = 58.000 − 10.000 · 1) / Einkommensbonus | 48.000 / 10 % | Memo 07, 01b 4.3.2, F-3 |
| S4-T2 | KfW-458-Zuschuss (56 % × min(32.960; 28.000)), Auszahlung 2028-01-01 | 15.680,00 | Memo 07 |
| S4-T3 | Ausführungskosten V1 2027 / 2030 / 2033 / 2047 | 32.960,00 / 85.988,87 / 55.405,82 / 46.507,36 | Memo 07 |
| S4-T3a | Ausführungskosten V0 2030 / 2032 / 2033 / 2042 / 2050 | 14.068,86 / 47.762,09 / 14.266,54 / 31.452,25 / 65.049,41 | Memo 07 |
| S4-T4 | BAFA 2030 / 2033 (`excess_over_threshold`) / Alternative `whole_amount` | 10.500,00 / 9.581,16 / 12.000,00 und 11.081,16 | Memo 07, B2 |
| S4-T5 | WP-Strom je Zustand (21.560/2,9; 16.170/3,2; 11.642,4/3,5) | 7.434,48 / 5.053,13 / 3.326,40 kWh | Memo 07 |
| S4-T5a | V0 Gas je Zustand (21.560/0,94; 18.972,8/0,94; 18.024,16/0,94) | 22.936,17 / 20.183,83 / 19.174,64 kWh | Memo 07 |
| S4-T6 | Energie + Wartung Zustand 1 (Preisbasis 2026): V0 24.500 × 12,50234 ct + 180 + 300 / V1 7.434,48 × 24 ct + 140 + 250 / Ersparnis | 3.543,07 / 2.174,28 €/a / 114,07 €/Monat | WS-S (Memo 07 rundet den Gaspreis auf 12,50 ct: 3.542,50 bzw. 114,02) |
| S4-T7 | KfW 358 (2030): Zinsen 2030–2032 / Annuität ab 2033 (22 J.); KfW 358 (2033): 2033–2035 / ab 2036 | 1.771,00 / 4.188,12; 1.138,50 / 2.692,36 €/a | Memo 07 |
| S4-T8 | Regel Klimageschwindigkeitsbonus: Kessel Bj. 2008 (18 J.) → 0 % → 40 % × 28.000 | 11.200,00 | Memo 07 (Variante `building.heating_existing.installation_year: 2008`) |
| S4-T9 | Regel Antragsdatum 02/2027: Bonus 12 %, Höchstkosten 27.250 → 52 % × 27.250 | 14.170,00 | Memo 07 (`application_date: 2027-02-15`) |
| S4-T10 | Pflichtsensitivität `habenzins_abgeltung`: Habenzins netto 2,5 % × 0,73625 = 1,840625 % in Variante und Unterlassung | Strukturtest | Konzept S4, 4.4 |
| S4-T11 | Referenzpflicht: `analysis.primary_kpi = delta_terminal_value` ohne `allow_opportunity_reference` → `validation.reference_variant_missing` | Validierungstest | Spec 00 §12.3a |

**MC-Erwartungen S4:** (m1) Ausfalljahr diskret gleichverteilt: Verschiebung Mittel +6 Monate (2030,5), je Block
genau 200/6-Schichtung (⌊·⌋/⌈·⌉ je Wert 33 oder 34); `wp_2050` verschiebt sich je Lauf mit, bei +24 und +36 Monaten
liegt er nach dem Horizontende (entfällt, Hinweis). (m2) BAFA 2033: Zusageanteil je Block exakt 140/200; in Läufen
ohne Zusage `funding.kfw358_2033.approved` = 0 (Kopplung) und Fehlbetrag über den Ergänzungskredit 6,0 %. (m3)
Eingänge: Einsparung Stufe 2 0,24333, Stufe 3 0,27, KfW-358-Zins 0,0276653 (trunkiert), Habenzins 0,0250115;
Spearman(jaz_s1, jaz_s2) 0,70 ± 0,02. (m4) Hypothesen (Memo 07, F20): P(`delta_vs_reference`(V2) > 0) > 0,9;
P(`delta_vs_reference`(V1) > 0) ≈ 0,4–0,6; `monthly_saving_avg10`(V1) < 0 in den Kreditjahren ab 2036 (+100 bis
+250 €/Monat Mehrbelastung).

### 5.5 S5 – Familie, Neubau EFH: EH 40 mit KfW 300 gegenüber GModG-Standard mit KfW 297 EH-55-Stufe (30 Jahre)

Quelle Memo 07 §4.5, Konzept §9 S5. Basis = V1 (Standard ≈ EH 55, KfW 297 EH-55-Stufe), Variante `v2_eh40_kfw300`,
optional `v2b_eh40_ohne_kfw300` (Fallback bei fehlender Berechtigung, S5-T3) und `v1b_ohne_kfw`. Festpreis-Bauvertrag
2027 (`price_index: 0`), Bauzeit 03–12/2027, Bezug 2028-01-01. Monatsraten (`payments_per_year: 12`, S01C-06);
Testkonvention Memo 07: Darlehen voll zum Stichtag ausgezahlt, Raten ab Januar 2027, Zinsbindung bis 31.12.2036;
deshalb sind Bauwerk und Nebenkosten zum Stichtag angesetzt (der Förderkredit startet nach Teil B 4.6 am ersten
Maßnahmentermin). Ein realistischer Zahlungsplan verschiebt nur die Zinsen der Geldanlage und die ersten KfW-Raten.

```yaml
# inst/extdata/examples/s5_neubau_efh_eh40.yaml
schema_version: 1
meta:
  scenario_id: s5_neubau_efh_eh40
  title: "S5 – Familie, Neubau EFH: EH 40 mit KfW 300 gegenüber GModG-Standard mit KfW 297 (EH-55-Stufe)"
  author: "WS-S (Referenzszenario, Memo 07 §4.5)"
  created_date: 2026-10-25
  tags: [referenzszenario, s5, neubau, selbstnutzer, haushaltsmodus]
project:
  perspective: selbstnutzer
  project_type: neubau
  comparison_mode: absolute
  valuation_date: 2027-01-01
  horizon_years: 30                         # 2027-2056, Horizontende 2057-01-01 (Profil: Neubau 40, Memo 07: 30)
  application_date: 2026-12-15              # EH-55-Stufe bis 31.12.2026, Baugenehmigung vorhanden
  legal_state: 2026-10-25
  price_base_year: 2026
  reference_variant: base                   # V1
  report_mode: household
grid: {construction_months: 12, construction_step_months: 12}   # Bauzeit 2027, Bezug 2028-01-01
building:
  building_type: EFH
  construction_year: 2027
  n_units: 1
  living_area_m2: 140
  efficiency_standard_after: eh55           # GModG-Mindeststandard (≈ EH 55); V2: eh40
  land_value_eur: 150000                    # 500 m2 x 300 EUR (Sachwert: Bodenwert fortgeschrieben 1,5 % p. a.)
  maintenance:
    rate_eur_m2_pa: 10.0                    # Instandhaltungsrücklage 1.400 EUR/a (Memo 07), ab Fertigstellung
household:
  taxable_income_avg_eur: 85000             # Ø 2023/2024; KfW 300: <= 90.000 + 10.000 je weiterem Kind
  n_children_u18: 2
  net_income_month_eur: 6300                # inkl. Kindergeld
  current_rent_month_eur: 1250              # Warmmiete bis Einzug (Doppelbelastung 2027)
  savings_eur: 180000
unit_groups:
  haus:
    label: "Selbstgenutztes EFH"
    n_units: 1
    living_area_m2: 140
    owner_occupied: true
measures:
  grundstueck:
    label: "Grundstück 500 m2 x 300 EUR + 10 % Erwerbsnebenkosten (pauschal)"
    measure_type: erwerb_grundstueck
    date: 2027-01-01
    purchase_price_eur: 165000              # Memo 07: 150.000 + 15.000 Nebenkosten als Gesamtbetrag
    grest_rate: 0                           # in den pauschalen Nebenkosten enthalten (W)
    notary_share: 0
    land_registry_share: 0
  bauwerk:
    label: "Bauwerk KG 300+400 (3.000 EUR/m2)"
    measure_type: neubau
    date: 2027-01-01                        # Testkonvention: Zahlung zum Stichtag, damit Förderkredit ab 2027-01 voll (01b 4.6)
    completion_date: 2028-01-01
    cost_eur: 420000                        # V2: 420.000 x (1 + Mehrkosten EH 40)
    price_index: 0                          # Festpreis-Bauvertrag 2027
  nebenkosten:
    label: "Baunebenkosten KG 700 (12 %), Hausanschlüsse KG 200, Außenanlagen KG 500"
    measure_type: baunebenkosten
    date: 2027-01-01
    completion_date: 2028-01-01
    cost_eur: 95400                         # 50.400 + 20.000 + 25.000; V2: + 3.000 LCA/EEE
    price_index: 0
  kueche:
    label: "Küche KG 600"
    measure_type: ausstattung               # nicht im Sachwert (asset_value.kg_include ohne 600)
    date: 2027-12-31
    cost_eur: 15000
    price_index: 0
    useful_life_years: 15
    replacement: {enabled: false}
  pv:
    label: "PV-Anlage 8 kWp"
    measure_type: pv
    date: 2027-12-01
    completion_date: 2027-12-01             # IBN 12/2027
    cost_eur: 11000
    vat_rate: 0
    price_index: 0
    useful_life_years: 25
    replacement: {enabled: false}
shared:
  from: prices/referenzszenarien_2026
  use: shared
  eh40_surcharge: 0.06                      # Mehrkosten EH 40 (Anteil an KG 300+400)
  efficiency_premium_v2: 0.03               # Effizienzzuschlag Sachwert V2
  feed_in_flag: 1                           # EEG-Vergütung für Neuanlagen < 25 kWp fortgeführt
energy:
  carriers:
    power: {base_fee_eur_pa: 100.84033613}  # Haushaltsstrom 37 ct, Grundpreis 120 EUR brutto (ein Zähler mit PV)
  after:                                    # Zustand ab Fertigstellung (Token completion)
    demand_kwh: 7000                        # 50 kWh/m2 a; V2: 4.900
    heating_carrier: power
    heat_pump_carrier: power                # WP am Haushaltszähler (Klasse power: ausdrücklich, 01b 3.2.2)
    jaz: 3.5                                # V2: 3,8
    flow_temperature_c: 35
    service_eur_pa: 210.08403361            # WP-Wartung 250 EUR brutto
    extra_consumption:
      haushalt: {carrier: power, kwh_pa: 3500, label: "Haushaltsstrom"}
  pv:
    kwp: 8
    measure: pv
    commissioning_date: 2027-12-01
    specific_yield_kwh_kwp: 950
    self_consumption_share: 0.35            # V2: 0,33
    feed_in_tariff_eur_kwh: {expr: "0.0755 * shared.feed_in_flag"}   # IBN 12/2027 (7,70 ct −1 %/Halbjahr), 20 J. fest
    tariff_years: 20
    opex_eur_pa: 150
components:
  grundsteuer_versicherung:
    type: recurring
    label: "Grundsteuer und Gebäudeversicherung"
    category: other_cost
    amount_eur: 1600
    growth: {ref: market.inflation}
    from: completion
financing:
  bank:
    type: annuity_loan
    label: "Bankdarlehen"
    amount_eur: 426400                      # V2: 384.600
    start: 2027-01-01                       # Testkonvention: voll zum Stichtag (S5-T4..T6)
    rate_pa: 0.041
    initial_repayment_pa: 0.02              # 2.167,53 EUR/Monat
    term_years: 35                          # Ziel Volltilgung bis 2062 (Anschluss keep_term)
    fixed_years: 10
    payments_per_year: 12
    followup_rate_pa: {ref: market.mortgage_rate}
    refi_rule: keep_term
    fees: {commitment_fee_rate_month: 0.0025, commitment_free_months: 6}   # ohne Wirkung bei Vollauszahlung
funding:
  kfw297:
    from: funding/kfw_297_khn_eh55_stufe    # 35/5/10, 2,19 %; Auszahlung zum ersten Maßnahmentermin (01b 4.6)
    measures: [bauwerk, nebenkosten]
    application_date: 2026-12-15
    amount_eur: 100000
    loan_variant: v35_5_10
    loan: {payments_per_year: 12}
    approval_probability: 1.0               # Memo 07: kein Zusagerisiko modelliert
accounts:
  deposit_rate_pa: {ref: market.mortgage_rate, anchor: 0.025}
  overdraft_rate_pa: {ref: market.mortgage_rate, anchor: 0.060}
market:
  from: prices/referenzszenarien_2026
  use: market
  co2_price: {from: prices/co2_price_path_referenzszenarien_2026}
residual_value:
  method: asset_value                       # Sachwert vereinfacht (= Profil selbstnutzer/neubau)
  sale_cost_share: 0.03
  asset_value:
    market_adjustment_factor: 1.0
    uplift_share: 0                         # V2: Effizienzzuschlag
tax: {module: none}
analysis:
  stabilization_year: 2028
stochastic:
  settings: {n_sim: 10000, seed: 20261025, sampling: lhs, block_size: 200, store: bands}
  processes:
    mortgage_rate: {target: market.mortgage_rate, from: processes/mortgage_rate_vasicek_2026}   # Anschluss 2037 (Fächer, Quantile 5/50/95 %)
    inflation: {target: market.inflation, from: processes/inflation_ar1_2026}
    energy_price_power: {target: market.energy_price.power, from: processes/energy_prices_mr_2026, use: power}
  parameters:
    demand_after: {target: energy.after.demand_kwh, label: "Nutzwärme", dist: triangular, min: 5600, mode: 7000, max: 8400}   # 40/50/60 kWh/m2 a
    feed_in_flag: {target: shared.feed_in_flag, label: "EEG-Vergütung < 25 kWp fortgeführt", from: processes/funding_risks_2026, use: feed_in_continuation, apply: replace}
    construction_price_shift: {target: shared.construction_price_shift, label: "Abweichung Baupreisindex p. a.", dist: normal, mean: 0, sd: 0.012}
  correlations:
    shocks: {from: processes/shock_correlations_2026}
variants:
  v2_eh40_kfw300:
    label: "V2 EH 40 + LCA mit KfW 300 (170.000 EUR, 1,00 %)"
    remove: [funding.kfw297]
    set:
      building.efficiency_standard_after: eh40
      measures.bauwerk.cost_eur: {expr: "420000 * (1 + shared.eh40_surcharge)"}   # 445.200
      measures.nebenkosten.cost_eur: 98400
      financing.bank.amount_eur: 384600     # 1.955,05 EUR/Monat
      energy.after.demand_kwh: 4900
      energy.after.jaz: 3.8
      energy.pv.self_consumption_share: 0.33
      residual_value.asset_value.uplift_share: {ref: shared.efficiency_premium_v2}
      stochastic.parameters.demand_after: {min: 3920, mode: 4900, max: 6300}   # 28/35/45 kWh/m2 a; gleicher Schlüssel (CRN)
    add:
      energy.after.extra_consumption.lueftung: {carrier: power, kwh_pa: 400, label: "Lüftung mit WRG"}
      funding.kfw300:
        from: funding/kfw_300_wohneigentum_familien   # Stufe 1 EH 40: 170.000 EUR, 35/5/10, 1,00 %
        measures: [bauwerk, nebenkosten]
        application_date: 2026-12-15
        amount_eur: 170000
        loan_variant: v35_5_10
        loan: {payments_per_year: 12}
        approval_probability: 1.0
      components.lueftungsfilter:
        type: recurring
        label: "Lüftungsfilter"
        category: maintenance
        amount_eur: 120
        growth: {ref: market.inflation}
        from: completion
      stochastic.parameters.eh40_surcharge: {target: shared.eh40_surcharge, label: "Mehrkosten EH 40", dist: triangular, min: 0.03, mode: 0.06, max: 0.10}
      stochastic.parameters.efficiency_premium_v2: {target: shared.efficiency_premium_v2, label: "Effizienzzuschlag Restwert", dist: uniform, min: 0, max: 0.06}
  v2b_eh40_ohne_kfw300:
    label: "V2b EH 40 ohne KfW-300-Berechtigung (KfW 297 Standard 100.000 EUR, 2,94 %)"
    extends: v2_eh40_kfw300
    remove: [funding.kfw300]
    set: {financing.bank.amount_eur: 454600}
    add:
      funding.kfw297_standard:
        from: funding/kfw_297_khn_selbstnutzung
        measures: [bauwerk, nebenkosten]
        application_date: 2026-12-15
        amount_eur: 100000
        loan_variant: v35_5_10              # 2,94 %
        loan: {payments_per_year: 12}
        approval_probability: 1.0
  v1b_ohne_kfw:
    label: "V1b Standard ohne KfW (EH-55-Stufe ausgelaufen)"
    remove: [funding.kfw297]
    set: {financing.bank.amount_eur: 526400}
```

**Prüfwerte S5 (deterministisch; Monatsraten):**

| Nr. | Größe | Soll | Herkunft |
|---|---|---:|---|
| S5-T1 | Gesamtkosten V1 / V2 | 706.400 / 734.600 | Memo 07 |
| S5-T2 | KfW-300-Berechtigung: zvE 85.000 ≤ 90.000 + 10.000 · (2 − 1) = 100.000 → ja; Kreditdeckel Stufe 1 | ja; 170.000 | Memo 07, 01b 4.3.1, F-13 |
| S5-T3 | Negativtest `household.taxable_income_avg_eur: 105000` in V2 → nicht berechtigt: W „nicht berechtigt“, KfW 300 erzeugt keinen Baustein (01b 4.3.1, F-13); Fehlbetrag 170.000 über den Ausgleich (Nachschuss, Profil privat), Hinweis auf `v2b_eh40_ohne_kfw300` | Validierungstest | Memo 07, 01b F-13 |
| S5-T4 | Monatsraten Jahre 1–5 (2027–2031) V1: 2.167,53 + 182,50 / V2: 1.955,05 + 141,67 | 2.350,03 / 2.096,72 | Memo 07 |
| S5-T5 | Monatsraten Jahre 6–10 (2032–2036) V1: 2.167,53 + 379,19 / V2: 1.955,05 + 546,79 | 2.546,73 / 2.501,84 | Memo 07 |
| S5-T6 | Restschuld nach 120 Monaten Bank V1 / V2; KfW V1 / V2 | 321.200,85 (±1) / 289.713,52; 87.540,04 / 145.085,47 | Memo 07 (321.201 / 289.714; 87.540 / 145.085) |
| S5-T7 | KfW-300-Annuität V2 ab Monat 61 | 546,79 €/Monat | Memo 07 |
| S5-T8 | WP-Strom V1 (7.000 / 3,5) / V2 (4.900 / 3,8) + Lüftung 400 | 2.000,00 / 1.289,47 + 400 kWh | Memo 07 |
| S5-T9 | Bank V1 2027 (Monatsuhr, Spec 00 §8.5, Rate ungerundet 2.167,5333): Zinsen / Tilgung / Restschuld 31.12.2027; KfW-Zinsen 2027 | 17.320,31 / 8.690,09 / 417.709,91; 2.190,00 | WS-S |

**MC-Erwartungen S5:** (m1) Anschlusszins 2037 als Fächer: `paths$mortgage_rate` Quantile 2037 nach 1.6.3
(Vasicek r0 = 0,040, y = 11 ab 2027: q05 0,01584159, q50 0,03825299, q95 0,06066439); die Anschlussrate 2037 streut
entsprechend. (m2) Eingänge: Mehrkosten EH 40 Mittel 0,063333, Nutzwärme V1 7.000 / V2 5.040 (36 × 140),
Einspeisevergütung je Block exakt 100 von 200 Läufen 7,55 ct, Effizienzzuschlag Mittel 0,03. (m3) Hypothesen
(Memo 07, F20): P(`delta_vs_reference`(V2) > 0) > 0,8 („wegen der Förderung, nicht wegen der Energiekosten“: die
Betriebskosten V2 liegen ≈ 50 €/a über V1); `burden_ratio_max` 0,38–0,42 → Restriktion `burden` (Schwelle 0,40)
in einem Teil der Läufe verletzt; Ampel daher höchstens Gelb, falls P(Verletzung) ≥ 0,30 (Spec 00 §12.9).

### 5.6 `grob_lehrbuch_a` – Lehrbuch-VoFi (Orakel (a)) als Beispiel mit Overlay

Zweck: kleinstes vollständiges Beispiel mit beiden Kreditarten, Kontokorrent, Geldanlage und Restwert (Spec 00 §15.3
Orakel (a); Memo 01 §10) für Einstieg, Dokumentation und MC-Rechenprobe. Der Restwert ist eine eigene Komponente der
Kategorie `residual_value` (nur in T) mit dem unsicheren Blatt `shared.rw`; der Endwert ist linear im Restwert
(EW = BS_T, Zuflüsse in T werden nicht mehr verzinst), deshalb sind alle MC-Kennzahlen geschlossen bekannt.

```yaml
# inst/extdata/examples/grob_lehrbuch_a.yaml
schema_version: 1
meta: {scenario_id: grob_lehrbuch_a, title: "Lehrbuch-VoFi (a): Annuitäten- und endfälliges Darlehen, Restwert", author: "WS-T (Orakel (a))"}
project: {perspective: wu_privat, project_type: neubau, valuation_date: 2027-01-01, horizon_years: 5}
components:
  z:  {type: custom_series, label: "Zahlungsfolge", values: [-100000, 6000, 10000, 30000, 8000, 30000]}
  rw: {type: custom_series, label: "Restwert", category: residual_value, values: [0, 0, 0, 0, 0, {ref: shared.rw}]}
shared: {rw: 40000}
financing:
  ek:  {type: equity, amount_eur: 30000}
  ann: {type: annuity_loan, label: "Annuitätendarlehen", amount_eur: 40000, rate_pa: 0.06, term_years: 5, payments_per_year: 1}
  bul: {type: bullet_loan, label: "Endfälliges Darlehen", amount_eur: 30000, rate_pa: 0.05, term_years: 5, payments_per_year: 1}
accounts:
  deposit_rate_pa: 0.03
  overdraft_rate_pa: 0.10
  overdraft_limit_eur: .inf
  min_liquidity_eur: 0
  surplus_order: [od_repay, dep_invest]
  deficit_order: [dep_withdraw, od_draw, equity_call]
  deposit_withholding_tax_share: 0
residual_value: {method: zero}            # Restwert über Komponente rw (Spec 00 §15.3)
tax: {module: none}
analysis:
  kpis: [terminal_value, terminal_value_opp, delta_terminal_value, roe_classic, roe_mirr, roe_irr, payback_time,
         min_net_liquidity, max_overdraft, withdrawal_equivalent, npv_cf_project, irr_cf_project]
stochastic:
  settings: {n_sim: 10000, seed: 20261025, sampling: lhs, block_size: 200}
  parameters:
    rw: {target: shared.rw, label: "Restwert", dist: triangular, min: 30000, mode: 40000, max: 50000}
```

**Prüfwerte (deterministisch, Spec 00 §15.3 (a)):** EW 38.504,63; EW_U 34.778,22; ΔEW 3.726,41; R1 = R2 = R3 =
5,1183 %; `payback_time` 5, ohne Restwert `no_payback`; min. Nettoliquidität −6.491,30; max. KK 6.491,30;
Entnahme-Äquivalent 672,44; KW(3 %) 10.195,96; IZF 5,5636 %; Annuität 9.495,86 (Tilgung t = 1 7.095,86).
**Zielwertsuche:** `vofi_solve(x, param = "shared.rw", target = 0)` → kritischer Restwert 36.273,59 (= 40.000 −
3.726,41), `prob_exceed` = P(RW > 36.273,59) = 0,803210; `vofi_solve(x, param = "shared.rw", kpi = "roe_mirr",
target = 0.06)` → 41.642,14 (EW* = 30.000 · 1,06⁵ = 40.146,77).

**MC-Erwartungen (geschlossen, n_sim = 10.000; Mittel innerhalb 4 SE, Quantile innerhalb ihrer
Ordnungsstatistik-Konfidenzintervalle):**

| Größe | Soll | Herleitung |
|---|---:|---|
| mean / sd von `terminal_value` | 38.504,63 / 4.082,48 | EW = 38.504,63 + (RW − 40.000); sd Dreieck = 10.000/√6 |
| mean `delta_terminal_value` | 3.726,41 | |
| q05 / q50 / q95 `delta_terminal_value` | −3.111,31 / 3.726,41 / 10.564,13 | Q_Dreieck(p) − 40.000 + 3.726,41 |
| `p_neg` | 0,196790 | F_Dreieck(36.273,59) = 6.273,59² / (20.000 · 10.000) |
| `es05` | −4.165,40 | E[ΔEW \| ΔEW ≤ q05] |
| `expected_loss` | 411,53 | E[max(−ΔEW, 0)] |
| `na_share` von `payback_time` | 0,196790 | Amortisation in t = 5 genau bei ΔEW ≥ 0, sonst `no_payback` |
| `terminal_value_ex_rv` | 38.504,63 − 40.000 = −1.495,37 in jedem Lauf | Sicht ohne Restwert |

### 5.7 Walking Skeleton

`skeleton.yaml` bleibt wie Spec 00 Anhang A (ohne Overlay). Prüfwerte der Pflichtsensitivitäten auf dem Skelett:
Abschnitt 4.4.

---

## 6. MC-Ausgabe und Auswertung (WS-G; `vofi_mc()`, `mc_stats()`, `vofi_sensitivity()`, `vofi_solve()`, Ampel)

### 6.1 Presets und Stichprobenumfang (`stochastic.settings.preset`, S01C-14)

| Preset | `n_sim` | Blöcke R (m = 200) | `store` | `keep_runs` | Zweck | Quelle |
|---|---:|---:|---|---|---|---|
| `preview` | 1.000 | 5 (SE „grob“) | `kpi` | `[]` | Shiny, schnelle Vorschau; Präfix des Standardlaufs | Memo 04 E9, R-73 |
| `standard` (Default) | 10.000 | 50 | `bands` | `[p05, p50, p95]` | Regelfall | Memo 04 E9 |
| `report` | 50.000 | 250 | `bands` | `[p05, p50, p95]` | Bericht, Tail-Kennzahlen (ES, Quantile ≤ 5 %) | Memo 04 E9, §4.4 |
| `custom` | aus `n_sim` | n_sim/m | Feld | Feld | ausdrückliche Angaben | – |

`vofi_mc(preview = TRUE)` entspricht `preset: preview` (Spec 00 §14 Nr. 15). Ausdrücklich gesetzte Felder gehen dem
Preset vor. Die Präfix-Eigenschaft (Spec 00 §11.4) erlaubt die schrittweise Erhöhung: Vorschau → Standard → Bericht
rechnet nur die zusätzlichen Blöcke (Ergebnis identisch zur Neuberechnung).

**Konvergenzkriterien** (Ausweis, keine automatische Verlängerung in v1; Memo 04 §4.4): `mc_stats()` liefert je
Primärkennzahl `converged` = (relative Halbbreite des Mittels t_{R−1; 0,975} · se / |mean| < 0,005) **und**
(Halbbreite von `p_neg` t_{R−1; 0,975} · p_neg_se < 0,01); bei R < 10 immer `FALSE` mit Hinweis „grob“. Felder
`stochastic.settings.convergence: {rel_halfwidth_mean: 0.005, abs_halfwidth_prob: 0.01}` (S01C-14). Automatische
Blockerweiterung bis zum Kriterium: v1.1.

### 6.2 Gespeicherte Ausgaben (Spec 00 §9.9, §13.2)

| `store` | `kpis`, `kpi_na`, `inputs`, `features`, `flags` | `bands` (Zeilen `bands` × `band_probs` + Mittel) | `runs` (`keep_runs`) | `ledger` | `kpi_series` (Quantile je Jahr) |
|---|:---:|:---:|:---:|:---:|:---:|
| `kpi` | x | – | x | – | x |
| `bands` (Default) | x | x | x | – | x |
| `full` (W bei n_sim > 2.000) | x | x | x | x | x |

Default-Bänder `[net_position, dep_balance, od_balance]` (Spec 00 §4.3.15); der Bericht ergänzt je Perspektive
(Profil, # 01a): WU `dscr`-Reihe über `kpi_series`, Selbstnutzer `monthly_burden`, Kleinvermieter
`monthly_net_cashflow`. `keep_runs` wählt die Läufe, deren `keep_runs_kpi` dem Quantil am nächsten liegt (Gleichstand:
kleinster Laufindex); bei Entscheidungsknoten auf dem Kompositum (Spec 00 §9.11 Nr. 4).

### 6.3 Statistik je Kennzahl (Konkretisierung Spec 00 §12.7)

| Spalte (`stats`) | Definition | Label (de) |
|---|---|---|
| `mean`, `sd` | über gültige Läufe (`n_valid`) | Mittelwert, Standardabweichung |
| `se`, `se_df` | sd der R Blockmittel / √R; se_df = R − 1 (R < 10: Kennzeichnung „grob“; R = 1: sd/√n mit Hinweis) | MC-Fehler (Standardfehler) |
| `q05` … `q95` | `quantile(type = 7)`; KI über Ordnungsstatistiken k_lo = qbinom(0,025; n; p), k_hi = qbinom(0,975; n; p) + 1 (Memo 04 §4.4) | Quantile |
| `p_neg`, `p_neg_se` | mean(x < 0); SE aus den Blockanteilen | Wahrscheinlichkeit eines Nachteils |
| `es05` | Mittel der Werte ≤ q05 (nicht negiert) | Mittel der schlechtesten 5 % |
| `expected_loss` | mean(pmax(−x, 0)) | erwarteter Nachteil |
| `na_share`, `n_valid` | Anteil NA (nach Code getrennt in `kpi_na`) | Anteil nicht definiert |
| `deterministic` | Wert des Basisfalls | Basisfall |
| Vergleich (`diff_stats`) | `prob_better` = mean(Δ > 0), SE wie `p_neg` | Wahrscheinlichkeit „besser als Referenz“ |

**Prüffall (WS-G, `test-mc-stats.R`):** x = (−3, −1, 0, 2, 4, 5, 7, 8, 10, 12), Blockgröße 5 (R = 2): mean 4,4; sd
4,926121; Blockmittel 0,4 / 8,4 → se 4,0 (naiv 1,557776), se_df 1, „grob“; Quantile q05/q10/q25/q50/q75/q90/q95 =
−2,1 / −1,2 / 0,5 / 4,5 / 7,75 / 10,2 / 11,1; p_neg 0,2 (Blockanteile 0,4 / 0) → p_neg_se 0,2; es05 −3;
expected_loss 0,4; 95-%-KI des Mittels mit t_{1; 0,975} = 12,7062: [−46,42; 55,22]; `converged = FALSE`.

### 6.4 Sensitivität (`vofi_sensitivity()`, Spec 00 §11.11, §13.4)

| Methode | Default | Ausgabe |
|---|---|---|
| `tornado` | `probs = c(0.1, 0.9)`; Kandidaten wie 4.3 Nr. 1; ohne Overlay-Verteilung `delta` (Default 0,2) relativ zum Basiswert; Anzeige der 10 größten Swings | `results` mit `swing`, `rank`; Grundlage des Sets „vorsichtig“ |
| `spider` | `steps = 5` je Seite zwischen P05 und P95 der Overlay-Verteilung bzw. Basis × (1 ± `delta`) | `spider` (param, step, value, kpi) |
| `global` | aus einer MC (`inputs` und `features`, 11.7) | `global`: Spearman, SRC (lineare Regression standardisiert), SRRC (auf Rängen), PRCC (partielle Rangkorrelation), `s1_binned` = Var(E[y \| Klasse(x)]) / Var(y) mit 20 gleich besetzten Klassen (Populationsvarianz der Klassenmittel); `r2_src` |

Rangfolge der Treiber im Bericht: nach |SRRC|, wenn R²(SRRC-Regression) ≥ 0,7, sonst nach `s1_binned`; die drei
stärksten Treiber erscheinen im Fazit in Worten (Konzept 1.4). Entscheidungsschlüssel und `feature`-Spalten mit
konstantem Wert werden ausgelassen (I).

**Prüffall (synthetisch):** y = 2 x1 + x2, x1, x2 ~ U(0; 1) unabhängig (n = 10.000 LHS): SRC 0,894427 / 0,447214
(= 2/√5, 1/√5; ±0,005); Spearman 0,900 / 0,426 (±0,01); `s1_binned` 0,798 / 0,200 (exakt 0,8 / 0,2 abzüglich
Klassierungsfehler 0,002; ±0,01); Tornado mit P10/P90: Swings 1,6 / 0,8.

### 6.5 Zielwertsuchen (Konkretisierung Spec 00 §12.8)

Schwellen (`analysis.thresholds`, Profilwerte nach Konzept A4; gleichlautend in Teil A §1.5, §2.3–2.8; `lending_value_haircut`
0,10 = Konzept 2.5 „Vorschlag 10 %, Abl.“, D) und Standardparameter der Zielwertsuchen:

| Profil | `roe_hurdle` | `dscr` | `burden_share` | `warm_rent_increase_eur_m2` | `lending_value_haircut` |
|---|---:|---:|---:|---:|---:|
| `wu_kommunal`, `wu_privat` | 0,035 | 1,2 | 0,40 | 0,50 | 0,10 |
| `wu_genossenschaft` | 0,020 | 1,2 | 0,40 | 0,50 | 0,10 |
| `kleinvermieter` | 0,025 | 1,2 | 0,40 | 0,50 | 0,10 |
| `selbstnutzer` | 0,025 | (1,2, ohne Wirkung) | 0,40 | (0,50, ohne Wirkung) | 0,10 |

| Zielwertsuche | Aufruf (Beispiel) | Default-Intervall | Prüfwert |
|---|---|---|---|
| Break-even (Primärkennzahl = 0) | `vofi_solve(x, param = "shared.rw")` | [min, max] der Overlay-Verteilung, sonst Basis × [0,5; 1,5] | `grob_lehrbuch_a`: 36.273,59; Orakel (c1) Break-even-NOI_1 9.869,14 |
| Zielrenditemiete | `vofi_solve(x, param = "shared.rent_initial", kpi = "roe_mirr", target = "threshold:roe_hurdle")` | Basis × [0,5; 1,5] | `grob_lehrbuch_a` mit `kpi = roe_mirr`, `target = 0.06`: 41.642,14 |
| DSCR-Break-even, kostendeckendes Nutzungsentgelt | `vofi_solve(x, param = "unit_groups.<g>.rent_eur_m2_month", kpi = "dscr_min", target = "threshold:dscr")` | Basis × [0,5; 1,5] | Strukturtest S2 (Monotonie in der Miete) |
| Liquiditäts-Break-even | `kpi = "min_net_liquidity"`, `target = 0` | Basis × [0,5; 1,5] | `grob_lehrbuch_a`: kein Wechsel im Intervall für `shared.rw` (min. Nettoliquidität hängt nicht vom Restwert in T ab) → NA mit Meldung |
| warmmietenneutrale Umlage | Standard: `unit_groups.<g>.rent_law.voluntary_cap_mode: warm_rent_neutral` (01b 1.3, im Basisfall bestimmt, fest in allen Läufen, R-70); Gegenprobe `vofi_solve(x, param = "unit_groups.<g>.rent_law.voluntary_cap_per_m2", kpi = "warm_rent_change_prepost_y1", target = 0)` | [0; gesetzliche Kappe] | S1 V2: Hypothese ≈ 1,07 €/m² (Memo 07: Heizkostensenkung 1,07 €/m²; Beschluss 1,10) |
| notwendige Förderung | `param = "funding.<id>.amount_eur"` bzw. Förderquote, `target = 0` | [0; Höchstbetrag] | Strukturtest |
| maximal tragbare Investition | `param = "shared.cost_factor_v2"`, `kpi = NULL` bzw. `"dscr_min"`/`"burden_ratio_max"`, `rebuild = TRUE` bei `auto`-Darlehen | [0,5; 2] | Strukturtest S1 |
| Rendite der Mehrinvestition | `vofi_solve(x, what = "incremental_return", variant = "v2_eh70")` | [−0,02; 0,15], 41 Stützstellen | S1, S3 (deterministisch; MC v1.1) |

Für Bestandsprojekte ohne Bestandswert ist die Zielrenditemiete über `delta_vs_reference = 0` bei
`accounts.deposit_rate_pa = roe_hurdle` zu rechnen (Spec 00 §12.8 Tabelle); WS-G setzt das automatisch, wenn
`roe_mirr` NA `no_existing_value` ist (Hinweis im Ergebnis).

### 6.6 Ampel und Restriktionen (Profilwerte zu Spec 00 §12.9; Ablage # 01a)

| Profil | `analysis.traffic_light` | `analysis.restrictions` |
|---|---|---|
| `wu_kommunal`, `wu_privat`, `wu_genossenschaft` | `{green_prob: 0.70, red_prob: 0.40, restriction_prob: 0.30}` | `[dscr, liquidity, warm_rent]` |
| `kleinvermieter` | wie oben | `[liquidity, savings]` |
| `selbstnutzer` | wie oben | `[burden, liquidity, savings]` |

Werte nach Konzept 1.4 und A4. `overdraft_flag_threshold_eur` (Restriktion `liquidity`) ist ein Kontofeld (Teil A).

**Prüffälle Ampel (WS-G, synthetische Eingaben P = Primärkennzahl):**

| Nr. | Basis | Eingaben | Stufe 1 | Stufe 2 | Ergebnis |
|---|---|---|---|---|---|
| A1 | `mc` | p = 0,75, Median 1.200, P_base > 0, P_base_ex_rv > 0 | green | keine Verletzung | **green** |
| A2 | `mc` | p = 0,75, Median 1.200, P_base_ex_rv < 0 | green → höchstens yellow (Restwertregel) | – | **yellow**, `rv_dependent = TRUE` |
| A3 | `mc` | p = 0,55 | yellow | – | **yellow** |
| A4 | `mc` | p = 0,35 | red | – | **red** |
| A5 | `mc` | p = 0,80; `restriction_dscr`: Basis 0, MC-Mittel 0,31 | green | ko (0,31 ≥ 0,30) | **yellow** |
| A6 | `mc` | p = 0,80; `restriction_burden`: Basis 1 | green | ko (Basis verletzt) | **yellow** |
| A7 | `cautious` | P_base > 0, P_vorsichtig > 0 | green | – | **green** |
| A8 | `cautious` | P_base > 0, P_vorsichtig ≤ 0 | yellow | – | **yellow** |
| A9 | `base_only` | P_base > 0 | yellow (Hinweis „keine Robustheitsprüfung“) | – | **yellow** |
| A10 | `mc` | p = 0,70 genau, Median > 0 | green (≥) | – | **green** |
| A11 | `mc` | p = 0,40 genau | yellow (red nur bei p < 0,40) | – | **yellow** |

---

## 7. Offene Punkte

| Nr. | Thema | Stand / Übergangsregel | Klärung durch |
|---|---|---|---|
| OP-01 | **Blockgröße (R-73)** gegenüber Konzept F21 („10 Replikate zu je N/10“) | Teil C folgt R-73 (`block_size: 200`, Vorschau R = 5 mit SE „grob“); F21-Modus über `replicates` vollständig spezifiziert (1.2, 1.7.3); Golden-Vektoren für m = 10 und m = 200 (1.10.3). Bei Bestätigung von F21 ändern sich nur die Defaults in 1.2 und 6.1 | Orchestrator/Auftraggeber (Spec 00 §17.3 Nr. 5) |
| OP-02 | **Energiepreise netto** | erledigt: Bibliothek, Referenzszenarien und 01b §0.6/§3.2.1 führen Arbeitspreise, Netzentgelte und Bio-Mehrkosten netto; CO2-Preis netto; `network_fee_growth` des Trägers bleibt 0, weil der Marktknoten das Wachstum trägt (01b: I bei Doppelung) | – |
| OP-03 | **2045-Schalter** | erledigt: nur Reformcode `stufe_2045` (Spec 00 §4.10, R-82) mit `legal/gmodg_bio_treppe_2045`; das frühere Feld `energy.climate_neutral_2045` ist in 01b §3.2.4 ein Validierungsfehler | – |
| OP-04 | **Bibliotheks-id II. BV** | Teil B und Teil C verwenden `costs/bewirtschaftung_ii_bv_2026`; Teil A §2.2 (`global.yaml`, `building.maintenance.iibv`) verweist noch auf `costs/bewirtschaftung_iibv_2026` | 01a |
| OP-05 | **Abgleich mit Teil A/B (Stand 2026-10-26)** | Referenzszenarien auf die Feldnamen von 01a (Maßnahmentypen 4.2, `cost_factor`, `replacement.*`, `building.maintenance`, `residual_value.<methode>.*`, `erwerb_grundstueck`) und 01b (Zustände ohne Erzeugerliste, `heating_carrier`, `jaz`/`jaz_plan` je Zustand, `funding.<f>.loan`, `loan_variant`, `construction_support_eur`, `facts`, `payout.lag_months`) umgestellt; Auslegungscodes der Bibliothek wie von 01b übernommen (`proportional`, `flat_before_funds`, `halve_then_funds`). Restliche Annahmen: `measures.<m>.rent_law.procedure: "559"` (01b 1.4), `loan: {payments_per_year: 1}` als lokale Überschreibung der Nutzlast | 01a, 01b, WS-S |
| OP-06 | **Grundstück mit pauschalen Nebenkosten** (S2, S5) | Memo 07 nennt Grundstück inkl. 7,14 % bzw. 10 % Nebenkosten als einen Betrag; abgebildet als `erwerb_grundstueck` mit `grest_rate: 0` und Notar/Grundbuch 0 (W „Abweichung vom Landessatz“, Teil A 4.8). Alternative: Kaufpreis und Nebenkosten getrennt mit `federal_state` und freigegebenem GrESt-Eintrag (ändert S2-T1, S5-T1) | WS-S |
| OP-07 | **C-Einträge ohne Freigabe** (`legal/grunderwerbsteuer_2026`, `legal/mietrecht_559f_2026`) | `release: pending` → Themen inaktiv bis zur Fachfreigabe (Spec 00 §4.10): GrESt nur mit `grest_rate` (sonst E `validation.acquisition.grest_inactive`, Teil A 4.8), § 559f ohne Halbierung (S3-T4 rechnet mit `pending_reforms: [unreleased]`). Primärprüfung der 16 Landessätze und des § 559f-Wortlauts vor v1-Freigabe | WS-L, Fachstelle (Konzept B14) |
| OP-08 | **USt-Satz Holzpellets** | Bibliothek rechnet Pellets mit 7 % (Anlage 2 Nr. 48 UStG, C); vor Freigabe prüfen | WS-L |
| OP-09 | **Rundungen in Memo 07** | Teil C gibt motor-exakte Sollwerte an (S4-T6 3.543,07 statt 3.542,50; S3-T10; S3-T8 Restwerte der Heizungen bei Fertigstellung 10/2027); WS-S verwendet die Werte aus Abschnitt 5 | WS-S |
| OP-10 | **Testkonvention Vollauszahlung** (S2, S5) | Prüfwerte setzen die Auszahlung aller Darlehen zum Stichtag voraus; realistische Abrufpläne mit Bereitstellungsprovision sind als zusätzliche Varianten möglich, ändern dann S2-T6/S5-T6 | WS-S |
| OP-11 | **CO2-Unsicherheit der Referenzszenarien** | S1–S5 verwenden die Stützstellen aus Memo 07 §4.0 (Dreieck 2030/2040, ρ 0,8); die Bibliothek bietet zusätzlich den Korridor nach Memo 03/Konzept B6 (`processes/co2_price_corridor_2026`). Konzept F20 nennt nur Energie- und Inflationsprozesse; Annahme: CO2 bleibt Szenarioeinstellung (F19) | Auftraggeber |
| OP-12 | **Mietspiegelvorteil S1** | nicht abgebildet (S1 rechnet mit fester Steigerung); Beispielvariante mit OVM-Modus offen | WS-S, 01b |
| OP-13 | **Set „vorsichtig“ und Zusageschlüssel** | Kandidat nach 4.3 Nr. 1 (d); Zweigwahl kann unter den Treibern sein. Alternative: Ausschluss per `generate.exclude: [funding.*.approved]`, wenn „Förderstopp“ getrennt berichtet wird | Auftraggeber |
| OP-14 | **Profilwerte für Analysefelder** (`thresholds`, `traffic_light`, `restrictions`, `mandatory_sensitivities`, `lending_value_haircut`) | erledigt: 4.4, 6.5, 6.6 stimmen mit den Profilen in Teil A §2.3–2.8 überein; `lending_value_haircut` 0,10 bleibt D (Konzept 2.5) | – |
| OP-15 | **Prozesstyp CO2-Korridor ohne Diskretisierung** | v1: 20 Quantilpfade als `scenario_mix` (1.6.6, 2.5; Fehler −1,7e-4 im Mittel, −1 % in der sd); eigener Typ `triangular_corridor` v1.1 | WS-C |
| OP-16 | **Automatische Blockerweiterung** bis zum Konvergenzkriterium (6.1) | v1 nur Ausweis `converged`; Erweiterung um ganze Blöcke ist dank Präfix-Eigenschaft billig, v1.1 | WS-G |
| OP-17 | **Bedauern und Dominanz** (Memo 04 §6.3: E[max(EW_B − EW_A, 0)], stochastische Dominanz) | nicht in `diff_stats` (Spec 00 §13.3); v1.1 | WS-G |
| OP-18 | **Prüfpunkte der Bibliothek** vor Freigabe (Konzept §10.2): BEG-Richtlinienfassungen, KfW 458/459-Details, BAFA iSFP-Bonus, ImmoWertV-Zwischenzeilen (D), IWU-Fortschreibungsfaktor 1,12 (D), Nutzungsdauern (D), § 559f-Quelle | in `notes` der Einträge („Prüfpunkte:“) und `quality_detail` | WS-L, Fachstelle |

---

## 8. Änderungsanträge an Spec 00

Bis zur Entscheidung gilt jeweils die genannte Übergangsregel. Die Referenzszenarien (Abschnitt 5) brauchen
zwingend S01C-06 (S5) und S01C-11 (Förderinstrumente und Overlay-Einträge in Varianten); über die
Stochastikbibliothek nutzen sie S01C-02, S01C-03 und S01C-13 (Übergang: Zahlen aus `fallback` statt Token,
`p_norm = p0`, ein Eintrag je Datei) und S01C-01 nur in der Form `apply: replace` (Übergang: Feld weglassen, wenn die
Bibliotheksvorlagen ohne `apply` geführt werden).

| Nr. | Spec-00-Abschnitt | Antrag | Begründung | Übergangsregel |
|---|---|---|---|---|
| S01C-01 | §4.3.15, §6.3, §11.8 | Overlay-Feld `apply: replace \| multiply \| add` je statischem Eintrag: `ctx$param()` liefert b ⊙ x bzw. b + x (b = deterministischer Knoten, x = Ziehung); `draws$static` enthält x | Faktoren und Zuschläge auf beliebige Ziele (Baupreisindex, Liegenschaftszins, Bio-Mehrkosten, Instandhaltungsniveau) ohne Neudefinition des Basiswerts; Bibliotheksvorlagen in Faktorform (Memo 04). Teil A lenkt `multiply` auf `measures.<m>.cost_eur` nach `cost_factor` und `add` auf die RND nach `remaining_life_offset_years` um (S01A-08); S01C-01 verallgemeinert das | Faktoren über `shared`-Blätter und `expr` bzw. `cost_factor` (5.0 Nr. 6) |
| S01C-02 | §11.7, §4.9 | Token `base` für Startparameter (`x0`, `r0`, `p0`, `u0`, `p_norm`): Wert des deterministischen Ziels im Startjahr; Bibliotheksfeld `fallback` mit Zahlen für Tokens | Prozesse starten exakt am Basisfall (keine Sprünge zwischen deterministischem und MC-Lauf); Bibliothek unabhängig vom Szenario | Zahlen statt Token |
| S01C-03 | §11.7 (Tabelle) | `linked_ar1`: Parameter `u0` (u_1 = u0, Default 0); `mr_trend`: Parameter `p_norm` (Normalpreis p̄; Y_1 = ln(p0/p̄); E[P_y] = p̄ (1 + g)^{y−1} (p0/p̄)^{φ^{y−1}}) | Startjahr unverändert bei Kopplung; Mean-Reversion vom 12-Monats-Mittel zum Normalpreis (Konzept B8) ohne Verschiebung des langfristigen Mittels | `u0 = 0`, `p_norm = p0` (Spec-00-Formel) |
| S01C-04 | §5.3 | Quantilfunktionen MÜSSEN monoton nicht fallend sein; Bernoulli Q(u) = 1{u > 1 − p}; `empirical`: mode := median | Iman–Conover und CRN setzen Monotonie voraus; die Form 1{u < p} (Memo 04) kehrt die Ränge um | – (reine Klarstellung) |
| S01C-05 | §5.3 | `n_shocks(par)`/`n_uniforms(par)` hängen nur von der Struktur ab, nicht von Parameterwerten | Stromzuordnung und Plan-Hash unabhängig von Varianten-Parametern (CRN) | – |
| S01C-06 | §15.6 | Konvention „Kredite mit `payments_per_year: 1`“ für S1–S4; **S5 mit 12** | S5-Prüfwerte sind Monatsraten (Memo 07 §4.5) | S5 mit 12 |
| S01C-07 | §4.3.11 | Kanonische Marktnamen ergänzen: `bund_yield_10y`, `mortgage_spread`, `feed_in_tariff.<klasse>`, `vacancy_fluctuation`; Satz „Energiepreise und Netzentgelte netto (ohne USt)“ | Zwei-Faktor-Zinsmodell (F7), EEG-Sätze, Leerstandsschwankung (Memo 04); Konsistenz mit 01b | Namen gelten als szenarioeigene Marktpfade |
| S01C-08 | §4.9 | Eintragsschema: `quality_detail` (Unterpfad → Stufe), `legal_state` als Map (`as_of`, `status`, `reference`), `references`, `notes`; Korrelationspaare aus Bibliotheksverweisen mit fehlendem Schlüssel werden mit `vofi_inform` verworfen | Herkunft je Blatt (Konzept 6.4), Rechtsstand je Eintrag (F5); wiederverwendbare Korrelationslisten | Felder als zusätzliche Schlüssel tolerieren |
| S01C-09 | §4.3.14 | `mandatory_sensitivities.<i>.value` darf eine Wertform sein (z. B. `{ref: market.mortgage_rate}`) | „Habenzins = vermiedener FK-Zins“ folgt dem Zinspfad (Konzept A2) | Zahl 0,04 |
| S01C-10 | §4.11, §11.11 | Tornado-Grenzen für Prozessziele = Quantilpfade der Randverteilung (4.3 Nr. 1 (c)); Felder `generate.params`, `generate.exclude` | Zins-, Energie- und CO2-Risiken gehören zu den stärksten Treibern; ohne Regel fehlen sie im Set „vorsichtig“ | nur statische Schlüssel und Prozessparameter |
| S01C-11 | §4.7, §4.9, §4.11 | (a) `from:`-Verweise in Varianten (`add`, `set`, `replace`) und Szenario-Sets werden nach der Operation mit denselben Regeln wie in Schicht 3 aufgelöst (Herkunft: Schicht 7, `entry`); (b) Overlay-Einträge dürfen in Varianten hinzugefügt, geändert und entfernt werden (`stochastic.parameters.<key>`, `stochastic.correlations.*`); ein Overlay-Ziel, das in einer Variante fehlt, ist dort ein Validierungsfehler | Förderinstrumente und Messgrößen existieren oft nur in der investiven Variante (S1–S5); CRN über den Vereinigungsplan (§11.10) setzt variantenspezifische Schlüssel voraus | keine (von S1–S5 benötigt) |
| S01C-12 | §11.7 | `vasicek`: `expected` liefert pmax(θ + (r0 − θ) e^{−κ(y−1)}, floor) | Konsistenz mit der gekappten Ausgabe (Design-Läufe, Quantilpfade) | ungekappt |
| S01C-13 | §4.3.15 | Overlay-Einträge der Bibliothek dürfen als Map mehrerer Einträge vorliegen (Auswahl mit `use:`), Korrelationslisten als `values`-Liste | eine Datei je Thema (Energiepreise, Kostenrisiken) | eine Datei je Eintrag |
| S01C-14 | §4.3.15, §12.7 | `stochastic.settings.preset` (`preview`/`standard`/`report`/`custom`, 6.1) und `stochastic.settings.convergence` (Ausweis `converged` in `stats`) | Memo 04 E9, §4.4; Präfix-Eigenschaft (R-73) | Argumente `n_sim`/`preview` |
| S01C-15 | §4.11 | Szenario-Sets dürfen zusätzlich `shared.*` setzen | `shared`-Blätter sind die Anker unsicherer Stützstellen und Faktoren (CO2 2030/2040, Netzentgeltwachstum); Sets wie `co2_hoch` könnten sie direkt setzen | szenarioeigene Marktpfade (Muster 5.3) |
