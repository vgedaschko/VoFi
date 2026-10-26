# Spezifikation 01, Teil B: Feldkatalog Erlöse und Mietrecht, Bewirtschaftung, Energie und CO₂, Förderung

| | |
|---|---|
| **Projekt** | VoFi-Werkzeug (R-Paket `vofi`) für Neubau und energetische Sanierung, Wohnungswirtschaft und Privatpersonen |
| **Dokument** | `docs/spec/01b_feldkatalog_betrieb_energie_foerderung.md` |
| **Teil von** | Spec 01 (Feldkatalog). Teil A (`docs/spec/01a_…`): Szenario, Projekt, Gebäude, Maßnahmen/Capex, Ersatzinvestitionen, Finanzierungsinstrumente, Konten, Restwert, globale Defaults und Profile. Teil C (`docs/spec/01c_…`): Stochastik-Overlay, Bibliothekseinträge, Szenario-Sets, Referenzszenarien S1–S5. |
| **Vertragsbasis** | Spec 00 (`docs/spec/00_kernvertraege.md`, `contract_version = "1.0.0"`, `schema_version = 1`) |
| **Stand / Rechtsstand** | 26.10.2026 (Review-Runde 3; Runde 4 „Restbefunde“ eingearbeitet, Abschnitt 12) / Rechtsstand 25.10.2026 |
| **Status** | Entwurf zur Integration. Verbindlich für WS-E (Typen `rent_path`, `operating_cost`, `property_tax`, `energy_cost`, `co2_cost`, `tenant_costs`, `pv`, `imputed_rent`; `rules-mietrecht.R`, `rules-co2kostaufg.R`), WS-E2 (Expander `unit_groups`, `energy`, `funding`, `household`; Typen `grant`, `tax_credit_35c`; `rules-funding.R`), WS-A (Element-Defaults `item_defaults` und Ableitungsregeln `rule:unit_group_defaults`, `rule:carrier_defaults`, `rule:approval_timing`, `rule:approval_probability`, `rule:tax_credit_defaults`, Abschnitte 5.5 und 7.1), WS-L (Bibliotheksnutzlast `funding/*`, `prices/energy_*`, `costs/bewirtschaftung_*`), WS-B (Validierungsregeln), WS-C, WS-D und WS-G (lesen die abgeleiteten Felder `funding.<f>.approval_timing` und `.approval_probability`; Zusageschlüssel, Entscheidungsknoten in `vofi_build()`), WS-D2/WS-H (Eingangsdaten der Mieter- und Haushaltssicht) |
| **Grundlagen** | Spec 00 §§ 3, 4.3, 4.7, 4.9–4.12, 5, 6, 7, 8.2, 9.11, 10.9, 11.6, 12, 16.3, 17.3, 17.5 (Stand Runde 3, Beschlüsse R-66 bis R-109, Namens- und Eigentumsentscheidungen N-01 bis N-31); Teil C §§ 1.9, 2.7, 3.4–3.6 (Nutzlast der Bibliothekseinträge); Konzept §§ 3.5–3.9, 11.2 (F13, F14, F15, F16), 11.3 (B1–B3, B7, B8, B12), Review-Protokoll; Memo 02 §§ 1.6–1.9, 2, 3, 4, 5 (insb. § 5.8), 9; Memo 03 §§ 2, 3, 7, 8, 9, 11; Memo 04 § 1.2; Memo 06 §§ 3.2, 3.4, 8; Memo 07 §§ 1, 4, 5.4; `docs/recherche/prototypen/vofi_referenz/mietpfad_ref.py` |

> **Lesehinweis.** Teil B legt Felder, Defaults, Algorithmen und Ledger-Zeilen der Erlös-, Bewirtschaftungs-, Energie-
> und Fördertypen fest. Er bewegt sich **innerhalb** der Strukturen von Spec 00 und ändert sie nicht. Wo Spec 00 eine
> Lücke lässt, steht hier eine Übergangslösung, und Abschnitt 10 enthält den zugehörigen Änderungsantrag
> (`S01B-nn`). Die Anträge S01B-01 bis S01B-13 sind in Runde 3 entschieden (Spec 00 § 17.5.1, R-85 bis R-109),
> S01B-14 in Runde 4 (Spec 00 § 17.6.2, R-111); alle sind hier eingearbeitet. Die Abschnitte 11 und 12 protokollieren
> die Überarbeitung. Alle Prüfwerte in den Testabschnitten sind mit
> einer unabhängigen skalaren Python-Referenz nach diesem Dokument nachgerechnet (Toleranz 0,01 EUR bzw. 1e-6 bei
> Raten); wo sie Memo 02 oder Memo 07 entnommen sind, ist die Konzept-Korrektur (F13, F14) eingearbeitet.

---

## 0. Geltung, Abgrenzung, Konventionen

### 0.1 Geltung

1. Teil B konkretisiert Spec 00 § 4.3.5 (`household`), § 4.3.6 (Teilbaum `measures.<id>.rent_law`, Enum
   `modernization_kind`), § 4.3.6a (`unit_groups`), § 4.3.6b (`energy`), § 4.3.7 (`funding`), § 4.12 (Expander
   `unit_groups`, `energy`, `funding`, `household`), § 5.3 (Regelkatalog für paketübergreifend aufgerufene Regeln),
   § 3.9 (Verschiebungsfelder je Typ) und § 7 (Zeilen der Typen). Damit sind die Punkte aus Spec 00 § 17.3 Nr. 1 für
   diesen Teil erledigt (`rent_path`-Parameter, Verschiebungsfelder, `household.current_rent_month_eur`,
   Regelkatalog, Enum `modernization_kind`), ebenso die Punkte aus Runde 2, soweit sie diesen Teil betreffen:
   `household.expected_income_tax_eur_pa` (3.10.1), `energy.<zustand>.jaz_plan` und Vorlauftemperatur (3.2.2),
   `performance_gap` als Strukturmodell (3.2.4), `funding.<id>.{approval_timing, fallback_variant, on_reject}`
   (4.2, 4.9), PV-Begünstigungsattribut (3.9.1), Modus „warmmietenneutral“ in `rent_law` (1.3, 1.9.5), Parameter
   `approved` und `repayment_grant.cut_share` der Förderkredite (4.6) und das Set `foerderstopp` (7.1, 7.2). Das Feld
   `measures.<id>.active` definiert Teil A; Teil B wendet den daraus gebildeten Aktivierungsfaktor an (0.8).
2. Ein Widerspruch zu Spec 00 ist ein Fehler dieses Dokuments. Neue Vokabularcodes (Enums) sind in Abschnitt 8
   aufgeführt; sie werden vom Integrator in `inst/vocab/enums.yaml` übernommen. Neue Ledger-Kategorien werden **nicht**
   eingeführt.
3. Auslegungen, die Konzept § 11.2/§ 11.3 vorgibt (F13, F14, B1, B2, B3, B7, B8, B12), sind die **Voreinstellung**;
   jede ist als Parameter umschaltbar. Grundsatz bei unklarer Auslegung: Die Voreinstellung wählt die für den
   Vermieter vorsichtigere Lesart (niedrigere zulässige Umlage, höhere Vermieterkosten) (Konzept F13).

### 0.2 Abgrenzung zu Teil A und Teil C

| Thema | Teil B (dieses Dokument) | Teil A | Teil C |
|---|---|---|---|
| Wohnungsgruppen, Mietpfad, Mietrecht | ganz (`unit_groups`, `rent_path`, Regeln) | – | Referenzwerte S1/S3 |
| Maßnahmen | nur Teilbaum `measures.<id>.rent_law` und Enum `modernization_kind` | übrige Felder (Kosten, Termine, `completion_date`, `delay_months`, `ohnehin_*`, `classification`, `kg`, `asset_type`, `effects`), Typen `capex`, `replacement` | Verteilungen |
| Bewirtschaftung | `operating_cost`, `property_tax`, Teilbäume `unit_groups.<g>.operating`, `building.property_tax` | `maintenance` (Instandhaltung inkl. Instandhaltungsersparnis, Doppelzählung mit Ersatz) | – |
| Energie, CO₂, PV, Warmmiete | ganz (`energy`, `energy_cost`, `co2_cost`, `tenant_costs`, `pv`) | PV-Investition als Maßnahme (`asset_type: pv_anlage`, USt 0) | Energiepreis- und CO₂-Prozesse, Bibliothekswerte |
| Förderung | ganz (`funding`, `grant`, `tax_credit_35c`, `rules-funding.R`; Auswertung der Nutzlast) | Kredittypen (`annuity_loan` …, Spec 00 § 8) | Bibliothekseinträge `funding/*` (Daten) |
| Recht (`legal/*`) | Regeln (Logik) und Abbildung der Nutzlast auf Regelparameter (0.9, 5) | Grunderwerbsteuer, Umsatzsteuer der Maßnahmen | Bibliothekseinträge (Zahlen, Themen, Freigabe) |
| Selbstnutzer | `household`, `imputed_rent`, Expander `household`, Definitionen der Haushaltssicht | – | S4, S5 |
| Restwert inkl. Mietausfallwagnis 2 % (ImmoWertV) | – | ganz | – |
| Stochastik | Kennzeichnung stochastisch zulässiger Felder | – | ganz |

### 0.3 Konventionen der Feldtabellen

- Spalten: **YAML-Pfad** | **Typ** (Spec 00 § 4.3: `chr`, `int`, `num`, `lgl`, `date`, `timing`, `enum:<name>`,
  `value`, `map`, `ids`, `schedule`) | **Einheit** | **Default (Quelle)** | **Pflicht** | **Validierung** |
  **Bedeutung** | **Memo**.
- Quellenkürzel des Defaults: **(T)** Typ-Default (Schicht 0), **(G)** `inst/extdata/defaults/global.yaml`
  (Schicht 1; bei Feldern von Sammlungselementen und optionalen Blöcken die Vorlage
  `global#item_defaults.<pfad>`, 7.1, Spec 00 § 4.7, R-85), **(AR)** Ableitungsregel `rule:<name>` von WS-A (5.5;
  läuft nach Schicht 8, **vor** `item_defaults` und vor den Expandern, setzt nur fehlende Blätter, Spec 00 § 4.7,
  R-86), **(B)** Bibliothekseintrag, **(R)** Rechtsstand (Rechtsparameter aus `ctx$legal(<thema>)` bzw. Regel über
  `ctx$rule()`, 0.9), **(A)** abgeleitet (Expander bzw. Typ bestimmt den Wert deterministisch aus anderen Feldern
  für die eigene Komponente bzw. Rechnung, **ohne** ihn in die Domäne zu schreiben, Spec 00 § 4.12 Nr. 1; Ableitung
  in der Spalte Bedeutung). Ein Default, den ein anderes Paket bzw. eine frühere Welle als Domänenblatt braucht oder
  der Overlay- bzw. Designziel sein kann, ist immer (G) oder (AR). Perspektivenprofile (Schicht 2) setzen keine
  Felder dieses Teils (Spec 00 § 4.7, R-76).
- Validierungskürzel: **E** Validierungsfehler (`vofi_error_validation`), **W** Plausibilitätswarnung
  (`vofi_warning_plausibility`), **I** Hinweis (`vofi_inform`), **O** `vofi_warning_library_outdated`. Meldungs-
  schlüssel stehen unter `validation.<block>.<code>` in `inst/labels/de/validation.yaml` (WS-B; z. B.
  `validation.unit_groups.ovm_missing`, Spec 00 § 2.10, R-104), Meldungen der Expander unter
  `expand.<expander>.<code>` (`inst/labels/de/expand.yaml`, WS-E2) und Meldungen der Typen unter
  `types.<kind>.<name>.msg.<code>`.
- Felder vom Typ `value` sind stochastisch zulässig (Overlay-Ziel), sofern nicht „det.“ (deterministisch,
  `deterministic_only = TRUE`) vermerkt ist. `enum`, `int`, `lgl`, `date`, `timing`, `ids`, `chr` sind immer
  deterministisch (Spec 00 § 5.4).
- Collections mit Nutzer-ids (z. B. `levy_history`, `rate_components`) sind **Maps nach id**, nie Listen, damit jedes
  numerische Blatt adressierbar ist (Spec 00 § 4.4 Nr. 3, § 4.12 Nr. 2).

### 0.4 Monatsrechnung (verbindlich für `rent_path`, `pv`, Termine)

- **Monate (Spec 00 § 3.4 Nr. 1, R-98).** M = `month_end[T+1]`. Monat m (m = 1…M) ist das Intervall
  (b₀ + (m−1) Monate, b₀ + m Monate], b₀ = `valuation_date`; er **beginnt** mit dem Monatsersten d_m = b₀ + (m−1)
  Monate. Monat m gehört zur Periode p(m) = min{t : M_t ≥ m} und zum Kalenderjahr y(m) = Jahr(d_m). Monate m ≤ 0
  sind Historie vor dem Stichtag.
- **Monatsindex eines Datums (laufende Wirkungen).** mi(d) = 12·(Jahr(d) − Jahr(b₀)) + Monat(d) − Monat(b₀) + 1 für
  Monatserste d, also mi(b₀) = 1 und mi(d_m) = m. Ein Datum, das kein Monatserster ist, wird für laufende Wirkungen
  auf den **folgenden** Monatsersten gerundet (Wirkungen beginnen mit vollen Monaten). „Wirksam ab d“ (Miete, Umlage,
  Betriebskosten, Energiezustand, PV) heißt: alle Monate m ≥ mi(d).
- **Termine von Einmalzahlungen (R-98).** Auszahlungen von Zuschüssen, § 35c-Tranchen und Tilgungszuschüssen haben
  einen **Termin als Datum**: Bezugsdatum + Monatsfristen + laufspezifische Verschiebung, gebucht in
  `grid_period_of(Termin)` (R-35: t = min{t ≥ 1 : Termin ≤ date_end[t]}, ein Termin gleich einem Periodenende gehört
  also zu der Periode, die dort endet; ein Termin am Stichtag gehört zu t = 0), laufspezifisch über `ctx$shift_period(Bezugsdatum, Fristen + Verschiebung)`. Sie laufen **nicht** über den
  Monatsindex. Beispiel: Fertigstellung 2027-10-01 + 3 Monate → Termin 2028-01-01 → Jahresraster ab 2027-01-01:
  Periode t = 1 (2027), für Zuschuss und Tilgungszuschuss gleichermaßen.
- **Laufspezifische Verschiebung** (Spec 00 § 3.9): mi_i = mi(d) + s_i mit s_i = floor(x_i + 0,5), x_i in Monaten.
  Alle Masken entstehen über `ctx$shift_months()` bzw. vektorisierte Vergleiche `mi_i == m`; keine Schleife über
  Läufe.
- **Kalenderjahressatz.** Für eine Rate g (n × (T+1), p. a.) ist g_Y := g[, j*(Y)] mit j*(Y) = min{j ≥ 2 :
  year[j] = Y}; für Y > year[T+1] gilt die letzte Spalte, für Y < year[2] die Spalte 2. Das entspricht der Regel von
  `grid_index_year()` (Spec 00 § 3.6).
- **Monatlicher Index.** I_g(m) = Π_{μ=1…m} (1 + g_{y(μ)})^{1/12}, I_g(0) = 1, für m < 0: I_g(m) =
  (1 + g_{year[2]})^{m/12}. Bei konstantem g ist I_g(m) = (1 + g)^{m/12} (wie `mietpfad_ref.py`).
- **Aggregation.** Monatsbeträge werden mit `ctx$to_periods()` je Periode summiert und am Periodenende gebucht
  (Spec 00 § 3.7). Hilfsgrößen (`aux`) sind Monatsmittel je Periode: x̄_t = Σ_{m∈t} x(m) / m_t (Spalte 1 = 0).
- **Leistung (SOLL).** Monatsschleifen iterieren nur über aktive Monate; Monate ohne Ereignis (keine Steigerung, keine
  Wirksamkeit, keine Fluktuation) dürfen geschlossen fortgeschrieben werden, wenn das Ergebnis bis 1e-9 relativ
  identisch ist. Monatsmatrizen n × M werden nur temporär gehalten.

### 0.5 Domänenlesezugriff (Vertragsregel Spec 00 § 5.2, § 6.1 Nr. 3; R-93, N-31)

Die Typen `rent_path`, `grant` und `tax_credit_35c` verarbeiten eine **variable Zahl** von Maßnahmen bzw.
Förderinstrumenten, die Energietypen eine variable Zahl von Zuständen und Gruppen. Spec 00 lässt keine Typparameter
mit dynamischen Namen zu. Deshalb gilt (S01B-02, entschieden mit Änderung):

1. Der Typ erhält die beteiligten ids als Parameter der Art `ids` (z. B. `rent_law_measures`, `funding_ids`) und liest
   deren Daten über **Domänenpfade**: numerische Blätter mit `ctx$value("measures.<id>.…")` (Ziehungen und Overlay
   wirken, Spec 00 § 6.3), Basisfallwerte mit `ctx$value_base()` (R-70), nicht-numerische Blätter (Daten, Codes,
   Flags) aus `ctx$spec` (nur lesen, Spec 00 § 6.2). Dasselbe gilt für die internen Helfer `act()` (0.8),
   `rp_vacancy_share()` (1.8.4) und `en_state_weights()` (3.4); sie lesen nur Domänenpfade, nie Komponenten (auch
   keine Komponentenparameter `components.<id>.<p>`).
2. Ergebnisse anderer Komponenten liest der Typ ausschließlich über `ctx$component(id)` bzw. `ctx$rows(id, …,
   measure_id = …)` (Filter `measure_id`, `local_row`, `id` als Vektor; Spec 00 § 6.2, R-93, S01B-05); jede solche id
   steht zusätzlich in `after` der Komponente (Spec 00 § 6.1 Nr. 3).
3. Jeder dieser Typen deklariert das Typdef-Feld `domain_reads` (Spec 00 § 5.2; C3 prüft die Codes):

   | Typ | `domain_reads` |
   |---|---|
   | `rent_path` | `measures`, `funding`, `financing`, `energy`, `unit_groups`, `building` |
   | `energy_cost` | `energy`, `measures`, `funding`, `unit_groups` |
   | `co2_cost` | `energy` |
   | `tenant_costs` | `energy`, `unit_groups` |
   | `pv` | `energy`, `measures`, `funding` |
   | `grant` | `measures`, `funding` |
   | `tax_credit_35c` | `measures`, `funding`, `household` |

   `project` ist kein Domänenleseblock: deterministische Projektfelder liefert `ctx$project`, die Verschiebung
   `project.construction_delay_months` wirkt über Parameter der Art `timing` mit Token `completion` (`ctx$timing()`,
   Spec 00 § 3.9) bzw. über den Parameter `construction_delay_months` der Energietypen (3.6.1).
4. Der Vertragstest (Spec 00 § 5.6, F1–F10) läuft mit einem `example`, dessen id-Listen leer sind (reiner Mietpfad,
   reiner Zuschuss mit `eligible_cost_eur`). Die Maßnahmenlogik testet die eigene Testdatei des Typs
   (`test-type-flow-rent-path.R`, `test-type-flow-grant.R` usw., N-18) mit `eng_context_from_parts(grid, spec, …)`
   und einer Mini-Spezifikation mit Domänenblöcken.
5. Domänenlesezugriffe dürfen nie endogene Größen lesen (Spec 00 § 4.5 Regel 2).

### 0.6 Vorzeichen, Einheiten, Brutto

- Ledger-Zeilen: Zufluss +, Abfluss − (Spec 00 § 7.1); Merkzeilen (`memo`) sind positive Beträge bzw. Mengen.
- Geldbeträge sind brutto (Spec 00 § 2.13, D6). Mieten sind umsatzsteuerfrei (`vat_rate = 0`). Energiepreis-
  bestandteile werden **netto** eingegeben und mit `vat_rate` aufgeschlagen (Konzept § 3.8), außer bei
  `price_basis: gross`.
- Mietniveaus in EUR/m²·Monat (Nettokaltmiete), Energiepreise in EUR/kWh, CO₂-Preise in EUR/t (netto),
  Emissionsfaktoren in kg CO₂/kWh der Abrechnungseinheit (Erdgas: Brennwert H_s, Konzept F11).

### 0.7 Fortschreibung laufender Jahresbeträge (R-62)

Laufende Jahresbeträge der Typen dieses Teils (Verwaltung, Grundsteuer, Wartung, Grundpreise, PV-Betrieb, Haushalts-
größen) folgen der Konvention von `recurring` (Spec 00 § 7.12):

```text
Betrag[, j] = a · ctx$index_year(g, base_date)[, j] · delta[j] · Überlappung[, j]
```

`base_date` ist, wenn nicht anders angegeben, der Preisstand (1. Januar nach `project.price_base_year`, R-35).
Beispiel (Prüfwert O-1): Verwaltung 24 WE × 367 EUR = 8.808 EUR/a, Preisstand 2026 (base_date 2027-01-01), VPI 2,8 %
(2027) und 2,2 % (ab 2028): 2027: 9.054,62; 2028: 9.253,83; 2029: 9.457,41 EUR.

Ausnahmen mit **Stichtagsniveau** (der Eingabewert gilt unverändert im ersten Jahr): Mietpfad (eigene Monatslogik,
Spec 00 § 3.6 letzter Absatz) und `imputed_rent` (base_date = `valuation_date` + 12 Monate).

**Wachstumsform (R-91, N-27; S01B-06 entschieden mit Änderung).** Marktpfade und Domänenfelder in der Wachstumsform
`{start, growth}` (z. B. `market.energy_price.<c>`, Netzentgelte) sind **Kalenderjahreswerte** (`index:
calendar_year`, Default; `start · grid_index_year(g, base_date)`), also innerhalb eines Kalenderjahres konstant und
auf jedem kalenderjahrbündigen Raster gleich (F10). `index: period_end` ist nur für Stichtagsgrößen ohne Typlogik
gedacht (z. B. einen Marktwertpfad); die Typen dieses Teils verwenden ihn nicht.

### 0.8 Aktivierungsfaktor und Basisfallwerte (Spec 00 § 4.12 Nr. 7, § 6.3, R-70, R-71)

- **Aktivierungsfaktor.** Für jede Maßnahme k gilt a_k = `measures.<k>.active` × Π_f `funding.<f>.approved` über
  alle Instrumente f mit `on_reject: drop_measures` und k ∈ `funding.<f>.measures`. Teil A bildet a_k im
  Maßnahmen-Expander als `expr`-Knoten für die Kostenkomponenten. Die Typen dieses Teils werten a_k über den
  internen Helfer `act(ctx, k)` aus (`R/type-flow-rent-path.R`, WS-E): dieselbe Formel über `ctx$value()` der
  genannten Domänenpfade (n-Vektor; Domänenlesezugriff 0.5, kein Lesen von Komponentenparametern). Sie stimmt mit dem
  Parameter `active` der Kostenkomponente (Teil A „AF“) überein, weil beide denselben Ausdruck auswerten. Die
  Expander dieses Teils schreiben a_k als `expr`-Knoten, wo ein Parameter den Faktor direkt trägt (Zuschüsse,
  Tilgungszuschuss, PV).
- **Wirkung** (MUSS): a_k wirkt auf alle aus k abgeleiteten Größen dieses Teils: Umlage und Kürzungsbeträge
  (1.9, 1.10), OVM-Zuschlag, Minderung und Entmietung während der Arbeiten (1.8.4), Energiezustand mit
  `measure: k` (3.4), PV (3.9), Zuschüsse und Steuerermäßigung (4.5, 4.8). Bei a_k = 0 verhält sich der Lauf so,
  als fehlte k. Die Rechnung bleibt vektorisiert (Masken `a_k > 0.5`, Spec 00 § 2.8).
- **Basisfallwerte.** Größen, die zum Planungs- bzw. Erklärungszeitpunkt feststehen, lesen die Typen über
  `ctx$param_base()`, `ctx$value_base()` bzw. `ctx$component_base()`: Plan-JAZ für § 559f (`energy.<zustand>.jaz_plan`,
  Default Basisfallwert von `jaz`), die Obergrenze einer warmmietenneutralen Umlage (1.9.5) und Kreditbeträge
  (`amount_eur` der Förderkredite, 4.6). Realisierte Kosten und die je Lauf gewährte Förderung lesen sie über
  `param()`, `value()` bzw. `component()` (Konzept 3.5).

### 0.9 Rechtsstand: Themen, Regeln, Freigabe (Spec 00 § 4.9, § 4.10, § 5.3, R-80)

- Zahlen des Rechts stehen in den Bibliothekseinträgen `legal/*` (Teil C § 3.5); die **Logik** steht in den Regeln
  dieses Teils (Abschnitt 5). Regeln lesen weder `ctx` noch die Bibliothek, auch nicht in Default-Werten ihrer
  Formals (Spec 00 § 5.3, R-93); der Typ übergibt die Nutzlast des
  Themas (`ctx$legal(<thema>)`) an eine Abbildungsregel (`mr_params`, `co2_params`; für die Fördernutzlast analog `fund_35c_params`), deren
  Ergebnis P als letztes Argument an die übrigen Regeln geht. Im Text dieses Teils sind Aufrufe ohne das letzte
  Argument P geschrieben.
- **Themen dieses Teils:** `mietrecht` (§§ 536, 556d–556g, 557a, 557b, 558, 559–559e BGB), `mietrecht_559f`
  (§ 559f BGB, Qualität C), `co2kostaufg`, `bio_treppe`, `emission_factors_co2cost`, `emission_factors_geg`,
  `umsatzsteuer` (nur PV-Nullsatz, 3.9.1). Das Thema `mietrecht_559f` ist ein eigener Eintrag, weil die
  Freigaberegel je Eintrag gilt (Abstimmung mit Teil C, 7.3; S01B-09 angenommen, Spec 00 § 4.10 „Freigabe je Teil“,
  R-88).
- **Inaktives Thema** (kein wählbarer Eintrag, z. B. C-Eintrag ohne Freigabe und ohne `unreleased`): `ctx$legal()`
  liefert `NULL`; die Abbildungsregel setzt die betroffenen Parameter auf `NULL`, und der Typ wendet die zugehörige
  Regel **nicht** an (§ 559f: keine Halbierung; `co2kostaufg`: kein Vermieteranteil; `bio_treppe`: kein biogener
  Anteil) und vermerkt das in `meta$notes` (`types.flow.<typ>.msg.topic_inactive`). Ist `mietrecht` inaktiv, ist
  das ein Validierungsfehler, sobald eine vermietete Gruppe existiert (ohne Mietrecht kein Mietpfad).
- **Reformcodes:** `mietrecht_ii` (1.12) und `stufe_2045` (3.2.4) wirken nur über `project.pending_reforms` und die
  Einträge mit `reform: <code>`; Teil B kennt keine eigenen Schalterfelder dafür.

---

## 1. Erlöse und Mietrecht

### 1.1 Überblick

```text
unit_groups.<g> ──────────┐
measures.<k>.rent_law ────┤  Expander unit_groups (order 20)
funding.<f> (§ 559a) ─────┤──►  u_<g>_rent           (rent_path, je vermietete Gruppe genau eine, R-63)
project.municipality ─────┘     u_<g>_opex           (operating_cost, Abschnitt 2.2)
                                u_<g>_property_tax   (property_tax, Abschnitt 2.3)
                                u_<g>_imputed_rent   (imputed_rent, nur selbstgenutzte Gruppen, Abschnitt 3.10)

u_<g>_rent  after:  m_<k>_* (capex-Komponenten der umgelegten Maßnahmen, Teil A), f_<f>_grant (grant, Abschnitt 4.5),
                    e_tenant (nur warm_rent_neutral)
            liest:  measures.<k>.*, funding.<f>.*, financing.f_<f>_loan.*, energy.<zustand>.{measure,
                    heat_pump_carrier, jaz_plan, jaz, flow_temperature_c, section43} (Domänenlesezugriff 0.5)
            Recht:  ctx$legal("mietrecht"), ctx$legal("mietrecht_559f")                    (0.9)
            ruft:   mr_params, mr_558_target, mr_levy_annual, mr_levy_cap_total, mr_levy_cap_heating, mr_hp_halving,
                    mr_levy_allowed, mr_index_adjustment, mr_relet_rent, mr_brake_applies   (Regelkatalog, Abschnitt 5)
            Basisfall: component_base(e_tenant) nur im Modus warm_rent_neutral             (1.9.5)
            Zeilen: rent, rent_loss, levy_<k>                                             (Abschnitt 1.13)
            aux:    vacant_share, rent_level, levy_level, ovm_level, levy_<k>_computed, …  (Abschnitt 1.13)
```

Der Mietpfad rechnet je Wohnungsgruppe **monatlich** einen repräsentativen Mietvertrag („Durchschnittswohnung“) mit
Basismiete B (ohne Umlagen) und Umlagen L_k je Maßnahme k; T = B + Σ_k L_k ist die vertragliche Nettokaltmiete. Die
Ledger-Zeilen sind **Sollbeträge bei Vollvermietung**; Leerstand, Forderungsausfall, Minderung und Anlaufverluste
stehen in `rent_loss`. Mit `rent_roll` wird derselbe Algorithmus je Wohnung gerechnet und summiert (Abschnitt 1.8.8).

### 1.2 Block `unit_groups.<g>` (Grunddaten, Mietregime, Erlösrisiken)

Gruppen-ids sind Nutzer-ids nach Spec 00 § 4.4 Nr. 2 mit **höchstens 25 Zeichen** (längste erzeugte id
`u_<g>_property_tax` bzw. `u_<g>_imputed_rent` ≤ 40; N-23). Gemeinsame Defaults stehen in
`global#item_defaults.unit_groups` (7.1); von Nutzung und Perspektive abhängige Defaults setzt
`rule:unit_group_defaults` (5.5, N-08).

| YAML-Pfad (`unit_groups.<g>.`) | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `label` | chr | – | id | nein | – | Anzeigename | – |
| `n_units` | int ≥ 1 | WE | – | ja | E < 1; W Σ Gruppen ≠ `building.n_units` | Anzahl Wohneinheiten der Gruppe | 02 §1.1 |
| `living_area_m2` | num > 0 | m² | – | ja | E ≤ 0; W Σ Gruppen weicht > 1 % von `building.living_area_m2` ab | Wohnfläche (WoFlV) der Gruppe; Bezug aller €/m²-Größen | 02 §9.2 |
| `owner_occupied` | lgl | – | (AR) `rule:unit_group_defaults`: `true` bei `project.perspective = selbstnutzer`, sonst `false` | nein | E widerspricht `rent_regime` | selbstgenutzte Gruppe: kein Mietpfad, volle Kostenwirkung | 02 §1.11 |
| `rent_regime` | enum:rent_regime | – | (AR) `owner_occupied`, wenn `owner_occupied`; `cooperative_fee` bei `wu_genossenschaft` und vermieteter Gruppe; sonst `paragraph_558` (G) | nein | E unbekannter Code | Mietregime: `paragraph_558`, `staffel`, `index`, `bound_social`, `cooperative_fee`, `owner_occupied` | 02 §2, §9.5 |
| `rent_eur_m2_month` | value | EUR/m²·Monat | – | ja, außer `owner_occupied` | E ≤ 0; W > 30 | Nettokaltmiete der Gruppe: Bestand = vertragliche Miete zum Stichtag **einschließlich** früherer Umlagen; Neubau = Erstvermietungsmiete ab `rent_start`; `bound_social` = Bewilligungsmiete | 02 §1.6 |
| `rent_start` | timing | – | (A) `valuation_date` bei Bestand; Token `completion` bei `project_type` ∈ {`neubau`, `erwerb_neubau`} | nein | E vor Stichtag | Beginn der Mietzahlungen; Token `completion` verschiebt mit `project.construction_delay_months` | 07 S2 |
| `rent_end` | timing | – | `end_date` (T) | nein | E vor `rent_start` | Ende der Vermietung (z. B. Abriss) | – |
| `rent_growth` | value (Rate, Pfad) | 1/a | `{ref: market.rent_growth}` (Spec 00) | nein | Raten-Grenzen | `fixed_growth`: Steigerung der Miete; OVM-Modi: Wachstum der Vergleichsmiete | 07 §4.0 |
| `increase_policy` | enum:increase_policy | – | `auto` (G) | nein | E OVM-Modus ohne `ovm_eur_m2_month` | `auto` (= `max`, wenn `ovm_eur_m2_month` gesetzt, sonst `fixed_growth`), `fixed_growth`, `max`, `interval`, `capped` | 02 §2.1 |
| `growth_from` | timing | – | (A) erster 1. Januar ≥ `rent_start` + 12 Monate | nein | W vor `rent_start` + 12 Monate | erster Steigerungstermin bei `fixed_growth`; danach jährlich | 07 S1/S2 |
| `growth_applies_to` | enum `total`, `base` | – | `total` (G) | nein | – | `fixed_growth` auf Gesamtmiete inkl. Umlagen (Steigerung = § 558-Erhöhung) oder nur auf die Basismiete | 07 S1 |
| `ovm_eur_m2_month` | value | EUR/m²·Monat | `null` | bedingt (OVM-Modi) | E fehlt bei `max`/`interval`/`capped`; W < 0,8 · Miete | ortsübliche Vergleichsmiete des **aktuellen** Zustands zum `ovm_base_date`; Modernisierungszuschläge über `measures.<k>.rent_law.ovm_uplift_eur_m2_month` | 02 §2.1 |
| `ovm_base_date` | date | – | `valuation_date` (T) | nein | – | Bezugsdatum von `ovm_eur_m2_month` | – |
| `interval_months` | int ≥ 15 | Monate | 36 (G) | nein | E < 15 | Mindestabstand bei `interval` | 02 §2.1 |
| `voluntary_558_cap_share` | value (share) | – | `null` | nein | – | freiwillige Obergrenze der § 558-Erhöhungen je Fenster (Selbstverpflichtung) bei `capped` | 02 §9.5 |
| `voluntary_558_cap_months` | int ≥ 12 | Monate | 36 (G) | nein | – | Fenster der freiwilligen Obergrenze | – |
| `rent_36m_ago_eur_m2_month` | value | EUR/m²·Monat | (A) = `rent_eur_m2_month` | nein | I fehlt im OVM-Modus („Kappungsbasis = aktuelle Miete angenommen“) | Miete 36 Monate vor dem Stichtag (Kappungsbasis) | Konzept 3.5 |
| `last_558_increase_date` | date | – | (A) `valuation_date` − 12 Monate | nein | E nach Stichtag | Wirksamkeit der letzten § 558-Erhöhung; Default = früheste nächste Erhöhung zum Stichtag + 3 Monate (§ 558b) | 02 §2.1 |
| `levy_history` | map id → {`effective_date` date, `eur_m2_month` num, `heating` lgl, `procedure` enum:levy_procedure} | – | `{}` | nein | E Datum nach Stichtag; E `procedure: auto` | Umlagen der letzten 6 Jahre vor dem Stichtag (Kappungsfenster § 559 Abs. 3a; § 559c-Sperre); Beträge sind in `rent_eur_m2_month` enthalten | 02 §2.3 |
| `market_rent_eur_m2_month` | value | EUR/m²·Monat | `null` | nein | W < Miete · 0,7 | Neuvertragsmiete am Markt zum `market_rent_base_date`; `null` schaltet die Wiedervermietungslogik ab | 02 §2.8 |
| `market_rent_growth` | value (Rate) | 1/a | `{ref: market.rent_growth_new}` (G) | nein | – | Wachstum der Neuvertragsmiete | 07 §4.0 |
| `market_rent_base_date` | date | – | `valuation_date` (T) | nein | – | Bezugsdatum der Marktmiete | – |
| `turnover_rate_pa` | value (share) | 1/a | 0,08 (G) | nein | W > 0,25 | Fluktuation (Mieterwechsel je WE und Jahr) | 03 §11; Konzept 3.7 |
| `relet_vacancy_months` | value (num ≥ 0) | Monate | 0 (G) | nein | W > 0 und `vacancy_rate` > 0 („Doppelzählung prüfen“) | zusätzlicher Leerstand je Mieterwechsel; 0 = im strukturellen Leerstand enthalten | 03 §11 |
| `first_use_after_2014_10_01` | lgl | – | (A) `true`, wenn `project_type` ∈ {`neubau`, `erwerb_neubau`} oder `building.construction_year` ≥ 2015 | nein | – | Neubauausnahme der Mietpreisbremse (§ 556f S. 1) | 02 §2.8 |
| `vacancy_rate` | value (share, Pfad) | – | 0,025 (G; Memo 03 § 11 „Deutschland-Mittel“); 0 bei `owner_occupied` (AR) | nein | E > 1; W > 0,15 | struktureller Leerstand (Anteil der Fläche) | 03 §11 |
| `rent_default_rate` | value (share, Pfad) | – | 0,01 (G); 0 bei `owner_occupied` (AR) | nein | W ≥ 0,02 und `vacancy_rate` > 0 („Mietausfallwagnis 2 % gehört in den Restwert“) | Forderungsausfall auf die Sollmiete | 03 §11; 07 S1 |
| `extra_loss_share` | value (share, Pfad) | – | 0 (T) | nein | E > 1 | sonstiger Erlösverlust je Periode (z. B. Erstvermietungsabschlag S2, Minderung S1 als Jahresanteil) | 07 S1, S2 |
| `lease_up_months` | value (num ≥ 0) | Monate | (AR) 3 bei vermieteter Gruppe und `project_type` ∈ {`neubau`, `erwerb_neubau`} (Memo 03 § 11); sonst 0 (G) | nein | W > 12 | Anlaufleerstand ab `rent_start`, linear abnehmend (1.8.6) | 03 §11 |
| `staffel_steps` | schedule (Beträge EUR/m²·Monat) | EUR/m²·Monat | `null` | bedingt (`staffel`) | E fehlt; E Staffel < 12 Monate Abstand | Staffelmiete: neue Gesamtmiete ab Datum (§ 557a) | 02 §2.6 |
| `after_staffel_regime` | enum `paragraph_558`, `index` | – | `paragraph_558` (G) | nein | – | Regime nach der letzten Staffel (+ 12 Monate) | 02 §2.6 |
| `index_rate` | value (Rate, Pfad) | 1/a | `{ref: market.inflation}` (G) | nein | – | VPI-Veränderung p. a. (Indexmiete § 557b) | 02 §2.7 |
| `index_adjust_month` | int 1–12 | – | 1 (G) | nein | – | Kalendermonat der jährlichen Anpassung | – |
| `bound_increase_pa` | value (Rate) | 1/a | 0 (T) | nein | – | zulässige jährliche Steigerung der Bewilligungsmiete (`bound_social`) | 02 §5.7 |
| `binding_end` | timing | – | (A) aus `funding.<f>.rent_binding` | bedingt (`bound_social`) | E fehlt | Ende der Mietbindung | 02 §5.7 |
| `after_binding_regime` | enum `paragraph_558`, `index` | – | `paragraph_558` (G) | nein | – | Regime nach Bindungsende | 02 §9.8 |
| `post_binding_kappung` | lgl | – | `false` (G) | nein | – | `false`: erste § 558-Erhöhung nach Bindungsende ohne Kappung (vereinfachte Lesart von § 558 Abs. 4) | 02 §2.1 |
| `imputed_rent_eur_m2_month` | value | EUR/m²·Monat | `null` | nein | I bei `selbstnutzer` und gesetzt („Kauf-oder-Miete-Sicht aktiv“) | ersparte Miete (nur selbstgenutzte Gruppen, Abschnitt 3.10) | 02 §1.6 |
| `imputed_rent_growth` | value (Rate) | 1/a | `{ref: market.rent_growth}` (G) | nein | – | Fortschreibung der ersparten Miete | – |
| `rent_roll` | map uid → {`living_area_m2`, `rent_eur_m2_month`, `rent_36m_ago_eur_m2_month`, `last_558_increase_date`, `levy_history`} | – | `null` | nein | E Σ Fläche ≠ `living_area_m2` (> 0,5 %); E Anzahl ≠ `n_units`; W > 50 Einträge (Laufzeit) | Mieterliste je WE für die Kappung je Wohnung (§ 559 Abs. 3a: 2 € vs. 3 €) | 07 S1, S6 |
| `operating` | map | – | Abschnitt 2.2 | nein | – | Bewirtschaftungsparameter der Gruppe | – |
| `rent_law` | map | – | Abschnitt 1.3 | nein | – | Mietrechtsparameter der Gruppe | – |

### 1.3 Teilbaum `unit_groups.<g>.rent_law` (Umlage und Auslegungen)

Die drei Felder `modernization_levy`, `voluntary_cap_per_m2`, `hardship_share` sind in Spec 00 § 4.3.6a genannt; die
übrigen konkretisieren diesen Teilbaum.

| YAML-Pfad (`unit_groups.<g>.rent_law.`) | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `modernization_levy` | enum:levy_mode | – | `auto` (G) | nein | – | `auto`: rechtlich zulässige Umlage je Maßnahme; `none`: keine Umlage (z. B. Beschluss) | Spec 00 4.3.6a |
| `voluntary_cap_per_m2` | value | EUR/m²·Monat | `null` | nein | E < 0; E zusammen mit `voluntary_cap_mode: warm_rent_neutral` | freiwillige Obergrenze der **kumulierten** Umlagen aller Maßnahmen der Gruppe (Beschluss, Genossenschaft); fest in allen Läufen; wirkt als min(Beschluss, rechtliches Maximum) | 07 S1, S3; Konzept 3.5 |
| `voluntary_cap_mode` | enum:voluntary_cap_mode | – | `fixed` (G) | nein | W `warm_rent_neutral` ohne Zustand `before` („keine Vorher-Heizkosten, Obergrenze 0“) | `fixed`: Obergrenze = `voluntary_cap_per_m2` (bzw. keine); `warm_rent_neutral`: Obergrenze = Heizkostenersparnis der Mieter je m² im Basisfall (1.9.5, Spec 00 § 4.3.6a, R-70) | Konzept 3.5, P6 |
| `hardship_share` | value (share) | – | 0 (G) | nein | E > 1 | Anteil der Umlage, der wegen Härte (§ 559 Abs. 4/5) oder Streit nicht durchsetzbar ist | 02 §1.8; 07 S1 |
| `drittmittel_attribution` | enum `full`, `proportional` | – | (R) `mietrecht.interpretation.third_party_allocation` (`full`; Konzept F14) | nein | – | Zurechnung von Zuschüssen, Tilgungszuschuss und Zinsermäßigung zum Modernisierungsanteil: voll oder anteilig ((K − IH)/K) | Konzept F14, B1 |
| `flat_559e_order` | enum `flat_before_funds`, `funds_before_flat` | – | (R) `mietrecht.interpretation.s559e_order` (`flat_before_funds`; F13) | nein | – | § 559e: 0,10 · (0,85 · K − D) bzw. 0,10 · 0,85 · (K − D) | Konzept F13 |
| `hp_reduction_order` | enum `halve_then_funds`, `funds_then_halve` | – | (R) `mietrecht.interpretation.s559f_order` (`halve_then_funds`; B1) | nein | – | § 559f: Reihenfolge Halbierung / Drittmittelabzug | Konzept B1 |
| `section43_flat` | lgl | – | (R) `mietrecht.interpretation.s559e_flat_for_section43` (`false`; B1) | nein | – | `true`: 15-%-Pauschale des § 559e auch bei Heizung nach § 43 GModG | Konzept B1 |
| `interest_subsidy_in_559e` | lgl | – | `true` (G; vorsichtigere Lesart) | nein | – | Zinsermäßigung (§ 559a Abs. 2) mindert auch die § 559e-Umlage | Abschnitt 9 |
| `hp_threshold_inclusive` | lgl | – | (R) `mietrecht_559f.comparison == ge` (`true`) | nein | – | § 559f erfüllt bei Plan-JAZ ≥ 2,5 (`true`) bzw. > 2,5 (`false`) | Konzept 10.2 |
| `kappung_rate` | value (share) | – | (R) `mietrecht.s558.cap_share` (0,20); `cap_share_tight_market` (0,15) bei `project.municipality.kappung_15_area` | nein | E > 0,20 | Kappungsgrenze § 558 Abs. 3 in 36 Monaten | 02 §2.1 |
| `kuerzung_558_5` | lgl | – | `true` (G) | nein | – | Kürzungsbeträge nach § 558 Abs. 5 anwenden (nur OVM-Modi) | 02 §2.2 |
| `kuerzung_grant_years` | value (num) | a | (R) `mietrecht.s558.funding_deduction_duration_grant_years` (12; B1, Qualität D) | nein | – | Dauer der Kürzung bei Zuschüssen/Tilgungszuschuss ab Fertigstellung | Konzept B1 |
| `kuerzung_loan_years` | value (num) | a | `null` (= Zinsbindung `fixed_years` des Kredits; (R) `funding_deduction_duration_loan: fixed_period`; B1) | nein | – | Dauer der Kürzung bei Zinsverbilligung ab Kreditbeginn | Konzept B1 |
| `levy_effective_delay_months` | int | Monate | (R) `mietrecht.s559.effective_month_offset` (3) | nein | – | Wirksamkeit der Umlage: Beginn des dritten Monats nach dem Monat der Erklärung (§ 559b Abs. 2) | 02 §2.3 |

### 1.4 Teilbaum `measures.<k>.rent_law` und Enum `modernization_kind`

Teil A definiert die übrigen Maßnahmenfelder. Die hier verwendeten sind: `modernization_kind`, `cost_eur`,
`ohnehin_share` bzw. `ohnehin_cost_eur`, `completion_date`, `date`/`year`/`payment_schedule` (erster Zahlungstermin),
`delay_months`, `useful_life_years`, `measure_type`, `kg`, `active`, `classification`. `cost_eur` existiert für jede
Maßnahme als Domänenblatt: bei `cost_kg` und bei Zahlungsplänen mit `unit: eur` setzt es die Ableitungsregel
`rule:cost_from_kg` (Teil A, X-28). Die Vorbelegung von `modernization_kind` aus dem Katalog setzt
`rule:measure_catalog` (Teil A); sie ergibt `none`, wenn `classification: erhaltung` angegeben ist oder der
Ohnehin-Anteil 1 beträgt (X-09), sodass Erhaltungs- und Ersatzmaßnahmen nicht in `rent_law_measures` (1.6 Nr. 4)
gelangen. Die Platzhalter `effects.rent.*`, `effects.vacancy.*` und `effects.energy.*` gibt es nicht (Teil A § 4.4):
Vergleichsmietenzuschlag und Bauzeitverluste stehen in `measures.<k>.rent_law` (unten), Energiewirkungen in den
Zuständen `energy.<zustand>` mit `measure: <k>` (Spec 00 § 4.3.6b, 3.2.2).

**Enum `modernization_kind`** (`inst/vocab/enums.yaml`, Default `none`):

| Code | Bedeutung (§ 555b BGB) | Umlage § 559 | § 559e möglich | § 536 Abs. 1a (3 Monate) | bei Indexmiete umlagefähig | Heizungskappe 0,50 €/m² |
|---|---|:---:|:---:|:---:|:---:|:---:|
| `none` | keine Modernisierung (Instandsetzung, Ohnehin) | nein | nein | nein | – | – |
| `bgb_555b_1` | energetische Modernisierung (Endenergie, Bezug zur Mietsache) | ja | nein | ja | nur wenn `landlord_responsible = false` | für `heating_part_share` |
| `bgb_555b_1a` | Einbau/Aufstellung einer Heizungsanlage (§ 42 GModG) | ja | ja | nur `mietrecht_ii` | ja | ja |
| `bgb_555b_2` | Einsparung nicht erneuerbarer Primärenergie/Klimaschutz ohne Bezug zur Mietsache | **nein** | nein | nein | – | – |
| `bgb_555b_3` | Wasserverbrauch | ja | nein | nein | nur `landlord_responsible = false` | – |
| `bgb_555b_4` | Gebrauchswerterhöhung | ja | nein | nein | dito | – |
| `bgb_555b_4a` | Glasfaser-Netz | ja (W: Einschränkungen § 559 Abs. 1 i. V. m. § 556 Abs. 3a prüfen) | nein | nein | dito | – |
| `bgb_555b_5` | allgemeine Wohnverhältnisse | ja | nein | nein | dito | – |
| `bgb_555b_6` | vom Vermieter nicht zu vertretende Umstände | ja | nein | nein | ja | – |
| `bgb_555b_7` | Schaffung neuen Wohnraums | **nein** | nein | nein | – | – |

Aliase (Eingabe): `erhaltung`, `instandsetzung` → `none`; `energetisch` → `bgb_555b_1`; `heizung` → `bgb_555b_1a`.

| YAML-Pfad (`measures.<k>.rent_law.`) | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `levy` | enum:levy_mode | – | `auto` (T) | nein | I `auto` bei `modernization_kind: none` wirkungslos | Umlage für diese Maßnahme erklären (`auto`) oder nicht (`none`) | – |
| `procedure` | enum:levy_procedure | – | `auto` (T) | nein | E `bgb_559e` bei Kind ≠ `bgb_555b_1a`; W `bgb_559` trotz Drittmitteln bei `bgb_555b_1a` | `auto`, `bgb_559`, `bgb_559c`, `bgb_559e` (Verfahrenswahl 1.9.2); Aliase `559`, `559c`, `559e` (auch als Zahl `559` gelesen) mit `vofi_warning_input` (Spec 00 § 2.11, R-89, N-06) | 02 §2.3–2.5 |
| `maintenance_share_method` | enum:maintenance_method | – | `auto` (T) | nein | E Methode ohne Pflichtangaben | Erhaltungsanteil IH (§ 559 Abs. 2): `auto`, `linear_wear`, `fixed_share`, `ohnehin`, `none` (1.9.1) | Konzept 3.3; 02 §1.4 |
| `maintenance_share` | value (share) | – | `null` | bedingt (`fixed_share`) | E > 1 | fester Erhaltungsanteil der Kosten | 02 §1.4 |
| `fictitious_maintenance_cost_eur` | value | EUR (Preisstand der Maßnahme) | (A) Ohnehin-Kosten der Maßnahme (`ohnehin_cost_eur` bzw. `ohnehin_share · cost_eur`) | bedingt (`linear_wear`) | W > `cost_eur`; W > Ohnehin-Kosten („Obergrenze“, Konzept 2.6) | fiktive Erhaltungskosten der erneuerten Bauteile | 02 §1.4 |
| `component_age_years` | value (num ≥ 0) | a | `null` | bedingt (`linear_wear`) | E < 0 | Alter des ersetzten Bauteils bei Fertigstellung | 02 §1.4 |
| `component_life_years` | value (num > 0) | a | (A) `measures.<k>.useful_life_years` | nein | E ≤ 0 | Nutzungsdauer des ersetzten Bauteils | 03 §9 |
| `heating_part_share` | value (share) | – | (A) 1 bei `bgb_555b_1a`, sonst 0 | nein | W > 0 bei Kind ∉ {`bgb_555b_1`, `bgb_555b_1a`} | Kostenanteil „Einbau einer Heizungsanlage“ für die Teilkappung 0,50 €/m² (F14). Auf einer Sammelmaßnahme (Hülle und Heizung in einer Maßnahme) ist der Anteil eine Näherung, weil Erhaltungsanteil, Drittmittel und Zinsermäßigung dann nicht je Bauteil zugeordnet werden (L-2); genauer sind getrennte Maßnahmen | Konzept F14 |
| `section43_heating` | lgl | – | (A) `section43` des Zustands mit `measure: <k>` (3.2.2, Regel `co2_section43`, 3.7.4) | nein | – | Heizung nach § 43 GModG: keine 15-%-Pauschale in § 559e (B1) | 02 §2.5 |
| `fundable_in_principle` | lgl | – | `true` (T) | nein | – | § 559e: Maßnahme „dem Grunde nach förderfähig“ | 02 §2.5 |
| `hp_state` | chr (Zustands-id) | – | (A) der Zustand mit `measure: <k>` | nein | E unbekannt | Energiezustand, aus dem Plan-JAZ (`jaz_plan`) und Vorlauftemperatur (`flow_temperature_c`) für § 559f gelesen werden (keine Kopie der Felder) | Spec 00 4.3.6b |
| `heat_pump` | lgl | – | (A) `true`, wenn `hp_state` einen `heat_pump_carrier` hat | nein | W `true` ohne `hp_state` („§ 559f-Halbierung angenommen“) | Maßnahme ist eine Wärmepumpe (§ 559f) | 07 §1.2 |
| `hp_exception` | enum:hp_exception | – | `auto` (T) | nein | – | `auto` (Baujahr > 1996 bzw. Vorlauf ≤ 55 °C), `none`, `building_after_1996`, `flow_temperature` | 07 §1.2 |
| `landlord_responsible` | lgl | – | (A) `false` bei `bgb_555b_6`, sonst `true` | nein | – | vom Vermieter zu vertreten (Indexmiete § 557b Abs. 2) | 02 §2.7 |
| `unit_groups` | ids | – | (A) alle Gruppen | nein | E unbekannte Gruppe | Gruppen, deren Wohnungen die Maßnahme betrifft | – |
| `allocation` | map gid → share | – | (A) flächenanteilig über `unit_groups` (inkl. selbstgenutzter Gruppen) | nein | E Σ ≠ 1 (Toleranz 1e-9) | Kostenverteilung auf Gruppen (§ 559 Abs. 3) | 02 §2.3 |
| `declaration_date` | timing | – | (A) `measures.<k>.completion_date` | nein | E vor Fertigstellung (W) | Zugang der Erhöhungserklärung; verschiebt mit `delay_months` | 02 §2.3 |
| `levy_effective_date` | date | – | `null` | nein | E vor Stichtag + 1 Monat | Wirksamkeitsdatum (überschreibt die Ableitung 1.9.4; Testfälle, bereits erklärte Umlagen) | – |
| `announcement_ok` | lgl | – | `true` (T) | nein | – | `false`: Wirksamkeit + 6 Monate (§ 559b Abs. 2 S. 2) | 02 §2.3 |
| `works_start_date` | timing | – | (A) erster Zahlungstermin der Maßnahme | nein | E nach Fertigstellung | Beginn der Bauarbeiten in der Wohnung | 02 §1.8 |
| `works_rent_reduction_share` | value (share) | – | 0 (T) | nein | E > 1 | Mietminderung während der Arbeiten (bewohnt) | 02 §1.8 |
| `works_vacancy_share` | value (share) | – | 0 (T) | nein | E > 1 | Anteil der Wohnungen, die während der Arbeiten leer stehen (Umsetzung, Entmietung) | 02 §1.8 |
| `ovm_uplift_eur_m2_month` | value | EUR/m²·Monat (Stand `ovm_base_date`) | 0 (T) | nein | W > 2 | Zuschlag der Vergleichsmiete für den modernisierten Zustand ab Fertigstellung | 07 S1 |
| `comprehensive_modernization` | lgl | – | `false` (T) | nein | – | umfassende Modernisierung (§ 556f S. 2): Mietpreisbremse gilt nicht für Wiedervermietungen danach | 02 §2.8 |

### 1.5 Verwendete Felder anderer Blöcke (Eigentum Teil A bzw. Spec 00)

| Pfad | Verwendung im Mietpfad |
|---|---|
| `project.municipality.kappung_15_area` | Kappungsgrenze 15 % (`mr_params`, `cap_share_tight_market`) |
| `project.municipality.mietpreisbremse_area`, `.mietpreisbremse_until` | Mietpreisbremse bei Wiedervermietung (Default `until` = 2029-12-31, Memo 02 § 2.8) |
| `project.municipality.index_cap_area` | Indexmietendämpfung (nur `mietrecht_ii`) |
| `project.pending_reforms`, `project.legal_state` | Auswahl der Regelversion (Spec 00 § 4.10) |
| `project.project_type`, `building.construction_year` | Neubauausnahme § 556f, Ausnahme § 559f (Baujahr > 1996) |
| `measures.<k>.*` (1.4) | Kosten, Termine, Verschiebung, Ohnehin-Anteil |
| `energy.<zustand>.{measure, heat_pump_carrier, jaz_plan, jaz, flow_temperature_c, section43}` | Wärmepumpen- und § 43-Erkennung je Maßnahme; Plan-JAZ über `ctx$value_base()` (0.8) |
| `measures.<k>.active`, `funding.<f>.{approved, on_reject}` | Aktivierungsfaktor a_k (0.8) |
| `funding.<f>.*` (Abschnitt 4.2), `financing.f_<f>_loan.{amount_eur, approved, rate_pa, start, fixed_years, repayment_grant.share, repayment_grant.amount_eur, repayment_grant.approved, repayment_grant.cut_share}` | § 559a-Drittmittel, § 558 Abs. 5 |
| `market.rent_growth`, `market.rent_growth_new`, `market.inflation`, `market.mortgage_rate` | Wachstum, Indexmiete, Referenzzins der Zinsermäßigung |

### 1.6 Expander `unit_groups` (Mietteil; WS-E2, `R/expand-unit-groups.R`, order 20)

1. **Implizite Gruppe.** Ist `unit_groups` leer und `perspective = selbstnutzer`, legt die Ableitungsregel
   `rule:unit_group_defaults` (5.5) die Gruppe `main` als Domänenelement an (`n_units: {ref: building.n_units}`,
   `living_area_m2: {ref: building.living_area_m2}`, `owner_occupied = true`; Bezüge statt Kopien, N-08a);
   `item_defaults` wirkt dann auch auf sie.
   Der Expander legt keine Domänenelemente an (Spec 00 § 4.12 Nr. 1). Ist `unit_groups` leer bei anderen
   Perspektiven, entstehen keine Mietkomponenten (I).
2. **Je vermietete Gruppe g** (`owner_occupied = false`) entsteht `u_<g>_rent` (Typ `rent_path`, `label` = Label der
   Gruppe). Je Gruppe entsteht zusätzlich `u_<g>_opex` (Abschnitt 2.2). `u_<g>_property_tax` (Abschnitt 2.3) entsteht
   nur, wenn `building.property_tax` den Jahresbetrag angibt, also `amount_eur_pa` oder `assessment_amount_eur` und
   `municipal_multiplier` (dann gibt es den Pflichtparameter `amount_eur_pa` des Typs immer); sonst keine Komponente
   (I bei vermieteten Gruppen „Grundsteuer wirkt nur im Leerstand, nicht angegeben“, W beim Selbstnutzer
   `validation.building.property_tax_missing`; nur `land_amount_eur_pa` bzw. `amount_after_completion_eur_pa` ohne
   Jahresbetrag: E; X-16). Bei selbstgenutzten Gruppen mit `imputed_rent_eur_m2_month`
   entsteht zusätzlich `u_<g>_imputed_rent` (Abschnitt 3.10).
3. **Belegung der Parameter.** Numerische Parameter erhalten `{ref: unit_groups.<g>.<feld>}` (bzw. den Pfad im
   Teilbaum `rent_law`), deterministische Felder (Daten, Codes, Flags) werden als normalisierte Werte übernommen
   (Spec 00 § 4.12 Nr. 2). Fehlt ein Domänenfeld auch nach den Ableitungsregeln und `item_defaults` (5.5, 7.1), gilt
   der Typ-Default (Schicht 0).
4. **Mietrechtlich relevante Maßnahmen** `rent_law_measures` = alle k mit g ∈ `measures.<k>.rent_law.unit_groups`
   und `modernization_kind ≠ none`. Für jedes k bestimmt der Expander deterministisch, ob eine Umlagezeile entsteht
   (`levy_<k>`): (a) `measures.<k>.rent_law.levy = auto`, (b) `unit_groups.<g>.rent_law.modernization_levy = auto`,
   (c) `bctx$rule("mr_levy_allowed")(kind, rent_regime, phase, landlord_responsible, procedure, P)` mit
   P = `bctx$rule("mr_params")(bctx$legal("mietrecht"), bctx$legal("mietrecht_559f"))` ist für mindestens eine
   Kombination wahr, vektorisiert über alle Phasen der Gruppe (`rent_phase` aus `rent_regime`, `after_staffel_regime`
   bzw. `after_binding_regime`) und alle Verfahren (`bgb_559`, `bgb_559c`, `bgb_559e` bzw. das gesetzte Verfahren)
   (Spec 00 § 4.12 Nr. 5; Aufruf mit allen Formals, N-19). Ist eine Bedingung verletzt, entsteht keine Umlagezeile (I
   mit Grund, `expand.unit_groups.levy_excluded`); die Maßnahme bleibt in `rent_law_measures`, weil ihre Drittmittel
   die § 558-Erhöhungen kürzen (1.10). Der Typ wiederholt die Prüfung (c) zur Laufzeit für die Phase des
   Wirksamkeitsmonats und das je Lauf gewählte Verfahren. Die Zugehörigkeit hängt nicht vom Aktivierungsfaktor ab
   (a_k wirkt zur Laufzeit, 0.8).
5. **Abhängigkeiten.** `cost_components` = alle von Teil A erzeugten Komponenten mit Typ `capex` und Metafeld
   `measure_id` ∈ `rent_law_measures`. `grant_components` = `f_<f>_grant` für alle `funding.<f>` mit `instrument_type =
   grant`, `measures` ∩ `rent_law_measures` ≠ ∅ und `rent_law.grant_counts_as ≠ none` (die ids entstehen später im
   Expander `funding`; die Existenz prüft Validierungsebene 3 nach allen Expandern). `funding_ids` = alle `funding.<f>`
   mit `instrument_type` ∈ {`loan`, `loan_with_repayment_grant`, `interest_subsidy`}, Bezug auf `rent_law_measures` und
   `rent_law.loan_counts_as ≠ none`. `after` = `cost_components` ∪ `grant_components` (∪ `e_tenant` nach Nr. 7).
6. **Mietbindung.** Gibt es `funding.<f>` mit `instrument_type = rent_binding` und g ∈ `funding.<f>.unit_groups`,
   setzt der Expander in der Komponente `u_<g>_rent` (nicht in der Domäne) `rent_regime = bound_social`,
   `rent_eur_m2_month = {ref: funding.<f>.rent_binding.rent_eur_m2_month}`,
   `bound_increase_pa = {ref: funding.<f>.rent_binding.increase_pa}` und `binding_end` = Bindungsbeginn +
   `rent_binding.years` (Bindungsbeginn = `rent_start`; Datum, deterministisch). Ist der Basisfallwert von
   `funding.<f>.approval_probability` (abgeleitetes Domänenblatt, 5.5) kleiner als 1, folgt W
   („Mietbindung wird unabhängig von der Zusage angesetzt; Entscheidungsknoten mit Ausweichvariante verwenden“).
7. **Warmmietenneutrale Umlage.** Bei `rent_law.voluntary_cap_mode = warm_rent_neutral` setzt der Expander
   `tenant_cost_component: e_tenant` und nimmt `e_tenant` in `after` auf (die id entsteht im Expander `energy`;
   Existenzprüfung wie Nr. 5). Kein Zyklus, weil `energy_cost` den Leerstand über den Helfer `rp_vacancy_share()`
   aus der Domäne bestimmt (3.6.2).
8. **Validierung im Expander** (sammelnd): Mietpfad ohne `rent_eur_m2_month` (E), OVM-Modus ohne OVM (E), `staffel`
   ohne Schritte (E), `rent_law_measures` einer Gruppe mit `rent_regime = bound_social` (I, keine Umlage), Mieterstrom
   (`components` vom Typ `custom_series` mit Label- oder Kategoriebezug `energy_income`) ohne Warnhinweis (W, C10),
   erzeugte id > 40 Zeichen (E mit zulässiger Höchstlänge der Gruppen-id 25, Spec 00 § 4.4 Nr. 2, R-90).

### 1.7 Typ `rent_path` (WS-E, `R/type-flow-rent-path.R`) – Parameter

Art `flow`, `grid_invariant = TRUE` (Monatsrechnung, Spec 00 § 3.6). Alle Parameter liegen flach in der Komponente.

| Parameter | `vofi_param`-Art | Default (T) | Belegung durch den Expander | Bedeutung |
|---|---|---|---|---|
| `unit_group` | `string` | Pflicht | g | Gruppen-id für Domänenzugriffe (Kostenverteilung) |
| `living_area_m2` | `number` (> 0) | Pflicht | ref | Fläche A |
| `n_units` | `integer` | Pflicht | Wert | Wohnungen (§ 559c-Grenze je WE) |
| `rent_eur_m2_month` | `value` (scalar) | Pflicht | ref | Ausgangsmiete R₀ |
| `rent_regime` | `enum` (vocab:rent_regime) | `paragraph_558` | Wert | Regime |
| `rent_start`, `rent_end` | `timing` | `valuation_date`, `end_date` | Wert/Token | aktive Monate |
| `increase_policy` | `enum` | `auto` | Wert | Strategie |
| `rent_growth` | `value` (path) | `{ref: market.rent_growth}` | ref | Rate g |
| `growth_from` | `timing` | (A) | Wert | erster Steigerungstermin |
| `growth_applies_to` | `enum` | `total` | Wert | |
| `ovm_eur_m2_month` | `value` | `null` | ref | OVM₀ |
| `ovm_base_date` | `date` | `valuation_date` | Wert | |
| `interval_months` | `integer` | 36 | Wert | |
| `voluntary_558_cap_share` | `share` | `null` | ref | |
| `voluntary_558_cap_months` | `integer` | 36 | Wert | |
| `rent_36m_ago_eur_m2_month` | `value` | (A) = R₀ | ref | |
| `last_558_increase_date` | `date` | `valuation_date` − 12 Monate | Wert | |
| `kappung_rate` | `share` | `null` (= Rechtsstand, 1.3) | ref, falls `rent_law.kappung_rate` gesetzt | k |
| `kappung_15_area` | `logical` | `false` | `project.municipality.kappung_15_area` | Kappungsgebiet 15 % |
| `market_rent_eur_m2_month` | `value` | `null` | ref | |
| `market_rent_growth` | `value` (path) | `{ref: market.rent_growth_new}` | ref | |
| `market_rent_base_date` | `date` | `valuation_date` | Wert | |
| `turnover_rate_pa` | `value` | 0 | ref | f |
| `relet_vacancy_months` | `number` | 0 | ref | |
| `brake_area` | `logical` | `false` | `project.municipality.mietpreisbremse_area` | |
| `brake_until` | `date` | 2029-12-31 | `project.municipality.mietpreisbremse_until` | |
| `first_use_after_2014_10_01` | `logical` | (A) | Wert | |
| `vacancy_rate`, `rent_default_rate`, `extra_loss_share` | `value` (path) | 0, 0, 0 | ref | Verluste |
| `lease_up_months` | `number` | 0 | ref bzw. (A) | |
| `staffel_steps` | `schedule` | `null` | ref | |
| `after_staffel_regime` | `enum` | `paragraph_558` | Wert | |
| `index_rate` | `value` (path) | `{ref: market.inflation}` | ref | |
| `index_adjust_month` | `integer` | 1 | Wert | |
| `index_cap_area` | `logical` | `false` | `project.municipality.index_cap_area` | |
| `bound_increase_pa` | `value` | 0 | ref | |
| `binding_end` | `timing` | `null` | Wert | |
| `after_binding_regime` | `enum` | `paragraph_558` | Wert | |
| `post_binding_kappung` | `logical` | `false` | Wert | |
| `modernization_levy` | `enum` (vocab:levy_mode) | `auto` | Wert | |
| `voluntary_cap_per_m2` | `value` | `null` | ref | |
| `voluntary_cap_mode` | `enum` (vocab:voluntary_cap_mode) | `fixed` | Wert | 1.9.5 |
| `tenant_cost_component` | `ref` | `null` | `e_tenant` bei `warm_rent_neutral` | Basisfall-Heizkosten der Mieter (`component_base`) |
| `hardship_share` | `value` | 0 | ref | h |
| `drittmittel_attribution`, `flat_559e_order`, `hp_reduction_order` | `enum` | `null` (= Rechtsstand, 1.3) | Wert, falls gesetzt | Auslegungen |
| `section43_flat`, `hp_threshold_inclusive` | `logical` | `null` (= Rechtsstand, 1.3) | Wert, falls gesetzt | |
| `interest_subsidy_in_559e`, `kuerzung_558_5` | `logical` | `true`, `true` | Wert | |
| `kuerzung_grant_years`, `kuerzung_loan_years` | `number` | `null` (= Rechtsstand), `null` | ref, falls gesetzt | |
| `levy_effective_delay_months` | `integer` | `null` (= Rechtsstand, 3) | Wert, falls gesetzt | |
| `rent_law_measures` | `ids` | `[]` | 1.6 Nr. 4 | mietrechtlich relevante Maßnahmen (Umlage, § 558 Abs. 5) |
| `levy_rows` | `ids` | `[]` | 1.6 Nr. 4 (a)–(c) | Teilmenge mit Umlagezeile `levy_<k>` |
| `cost_components` | `ids` | `[]` | 1.6 Nr. 5 | Capex-Komponenten (auch in `after`) |
| `grant_components` | `ids` | `[]` | 1.6 Nr. 5 | Zuschusskomponenten (auch in `after`) |
| `funding_ids` | `ids` | `[]` | 1.6 Nr. 5 | Förderkredite/Zinsverbilligung (Domänenlesezugriff) |
| `rent_roll_units` | `ids` | `[]` | Schlüssel von `rent_roll` | Mieterliste (1.8.8) |

`levy_history` ist kein Typparameter; der Typ liest es über `ctx$spec` aus `unit_groups.<unit_group>.levy_history`
(Domänenlesezugriff 0.5; fehlt der Block, gilt `{}`).

`example` (Vertragstest, rein, ohne Maßnahmen): `{type: rent_path, unit_group: g1, living_area_m2: 700, n_units: 10,
rent_eur_m2_month: 7.5, rent_start: 2027-01-01, growth_from: 2028-01-01, rent_growth: 0.015, vacancy_rate: 0.02,
rent_default_rate: 0.01}`.

### 1.8 Algorithmus `rent_path`

#### 1.8.1 Vorberechnung (deterministisch und je Lauf)

```text
A      <- living_area_m2;  R0 <- rent_eur_m2_month (n)
mi()   <- Monatsindex (0.4); M <- month_end[T+1]
act[m] <- 1, wenn mi(rent_start) + s_rent <= m < mi(rent_end)  (s_rent: Shift aus ctx$timing(spec, "rent_start"))
P      <- ctx$rule("mr_params")(ctx$legal("mietrecht"), ctx$legal("mietrecht_559f"))   # Rechtsparameter (5.2)
k      <- kappung_rate, falls gesetzt; sonst P$kappung_rate_15 bei kappung_15_area = true, sonst
          P$kappung_rate_default (0,20)
Auslegungen: Parameter mit Default null (1.7) erhalten den Wert aus P (P$attribution, P$flat_559e_order, …, 5.2)
a_k    <- act(ctx, k) je k ∈ rent_law_measures (0.8);  vcap <- Obergrenze nach 1.9.5 (n-Vektor oder Inf)
phase[m] (deterministisch): staffel   für m < mi(letzte Staffel) + 12, falls rent_regime = staffel;
                            bound     für m < mi(binding_end),       falls rent_regime = bound_social;
                            index     falls rent_regime = index bzw. after_* = index;
                            p558      sonst (paragraph_558, cooperative_fee, nach Staffel/Bindung)
Historie (m = -71…0):
  T_hist[m] <- rent_36m_ago + Σ_{h ∈ levy_history: mi(h.effective_date) <= m} h.eur_m2_month   für m <  mi(last_558)
  T_hist[m] <- R0                                                                               für m >= mi(last_558)
  inc[m]    <- Σ levy_history mit mi(effective_date) = m;  inc_h[m] <- dito nur heating = true
m_last <- mi(last_558_increase_date)          # n-Vektor (ganzzahlig, laufabhängig nach dem ersten Ereignis)
B <- R0 (n);  L_k <- 0 (n) je k ∈ rent_law_measures;   T = B + Σ L_k
OVM_m <- (ovm_eur_m2_month + Σ_k a_k · uplift_k · [m >= mc_k]) · I_g(m − mi(ovm_base_date))  # mc_k: Fertigstellungs-
                                                                                          # monat inkl. Shift
MKT_m <- market_rent_eur_m2_month · I_{g_new}(m − mi(market_rent_base_date))
Umlagen je Maßnahme k (1.9): U_k (n, EUR/a für Gruppe g), u_k = U_k / (12 A), Heizungsanteil hs_k,
  Wirksamkeitsmonat me_k (n), Kürzung K558_k (1.10)
```

#### 1.8.2 Monatsschleife (m = 1…M), Reihenfolge MUSS

```text
(a) Staffel:   phase = staffel und m = mi(Staffeldatum):         B <- Staffelwert − Σ L_k
(b) Index:     phase = index, Monat(m) = index_adjust_month, m − m_last_idx >= 12:
               π <- ctx$rule("mr_index_adjustment")(index_rate_{y(m)−1}, index_cap_area);  B <- B · (1 + π)
               (Satz des Vorjahres; Basismiete, Umlagen bleiben nominal fest; m_last_idx <- m)
(c) Bindung:   phase = bound, Monat(m) = 1, m >= mi(rent_start) + 12:  B <- B · (1 + bound_increase_pa_{y(m)})
(d) Steigerung fixed_growth (phase = p558): m >= mi(growth_from) und (m − mi(growth_from)) mod 12 = 0:
               f <- 1 + rent_growth_{y(m)};  total: B <- (B + Σ L_k) · f − Σ L_k;   base: B <- B · f;  m_last <- m
(e) Umlagen:   S <- {k : me_k == m} (Maske je Lauf); für die Läufe mit S ≠ ∅:
               Tb  <- B + Σ L_k                                     # Miete vor der Erhöhung
               p6  <- Σ inc[m−71 … m−1];  p6h <- Σ inc_h[m−71 … m−1] # Umlagen der letzten 6 Jahre
               roomT <- ctx$rule("mr_levy_cap_total")(Tb, p6);  roomH <- ctx$rule("mr_levy_cap_heating")(p6h)
               h_k <- u_k · hs_k;  H <- Σ_S h_k;  N <- Σ_S (u_k − h_k)
               σ_h <- pmin(1, roomH / H) (1, falls H = 0);  tot <- N + σ_h·H
               σ_t <- pmin(1, roomT / tot) (1, falls tot = 0)
               l_k <- ((u_k − h_k) + σ_h · h_k) · σ_t                # Teilkappung Heizung zuerst, dann Gesamt (F14)
               falls vcap < Inf: room_v <- pmax(vcap − Σ L_j, 0); σ_v <- pmin(1, room_v / Σ_S l_k)
                                 l_k <- l_k · σ_v
               L_k <- L_k + l_k;  inc[m] += Σ_S l_k;  inc_h[m] += Σ_S σ_h·h_k·σ_t·σ_v
(f) § 558:     phase = p558, policy ∈ {max, interval, capped}, act[m] = 1,
               okw <- (m − m_last >= P$wait_months) & (policy ≠ interval | m − m_last >= interval_months)
               T   <- B + Σ L_k;  base <- T_hist[m − 36];  s559 <- Σ inc[m−35 … m]
               kz  <- kuerzung_558_5 ? Σ_k K558_k(m) : 0
               vol <- policy = capped ? T_hist[m − cm] · (1 + voluntary_558_cap_share) + Σ inc[m−cm+1 … m] : Inf
               kr  <- Inf für die erste Erhöhung nach binding_end bei post_binding_kappung = false, sonst k
               tgt <- ctx$rule("mr_558_target")(OVM_m, base, s559, kz, kr, vol)
               up  <- okw & (tgt > T + 1e-9);  B[up] <- B[up] + (tgt − T)[up];  m_last[up] <- m
(g) Fluktuation (nur wenn market_rent_eur_m2_month gesetzt und turnover_rate_pa > 0):
               fm <- turnover_rate_pa_{p(m)} / 12;  T <- B + Σ L_k
               Z  <- Σ_k L_k · [m − me_k < P$mpb_modernization_months]              # § 556e Abs. 2 (Näherung)
               ba <- ctx$rule("mr_brake_applies")(brake_area, brake_until, Datum(m), first_use_after_2014_10_01,
                                                  comprehensive_done(m))
               Rn <- ctx$rule("mr_relet_rent")(MKT_m, OVM_m, OVM_m^{ohne Zuschläge < 36 Mon.}, T, Z, ba)
               T' <- (1 − fm) · T + fm · Rn;  L_k <- (1 − fm) · L_k;  B <- T' − Σ L_k
(h) Speichern: T_hist[m] <- B + Σ L_k;  Monatswerte B_m, L_{k,m} für Zahlungen und aux
```

`cm` = `voluntary_558_cap_months`. `comprehensive_done(m)` = 1, wenn eine Maßnahme mit
`comprehensive_modernization = true` vor Monat m fertiggestellt ist (Näherung, Abschnitt 9). In Phase `staffel` und
`bound` entfallen (d) und (f); Umlagen (e) nur, wenn `mr_levy_allowed` für das gewählte Verfahren und die Phase wahr
ist (Staffel: nur § 559e und nur ohne `mietrecht_ii`; Bindung: keine).

#### 1.8.3 Sollbeträge je Monat

```text
rent_m     = B_m · A · act[m]
levy_{k,m} = L_{k,m} · A · (1 − hardship_share) · act[m]
```

#### 1.8.4 Verluste je Monat

```text
v_s   = vacancy_rate_{p(m)}                                   # struktureller Leerstand
v_r   = turnover_rate_pa_{p(m)} · relet_vacancy_months / 12   # Leerstand durch Mieterwechsel
w     = Π_k [1 − α_k · W_k(m) · (1 − X_k(m))] · [1 − ν_k · W_k(m)]
          W_k(m) = 1 für mi(works_start_k) + s_k <= m < mc_k (Bauzeit in der Wohnung, a-Anteil der Gruppe > 0)
          X_k(m) = 1 für die ersten P$minderung_exclusion_months Monate ab Arbeitsbeginn, wenn das Kind von k in
                   P$minderung_exclusion_kinds liegt (§ 536 Abs. 1a)
          α_k = a_k · works_rent_reduction_share, ν_k = a_k · works_vacancy_share
lu    = (L_u − κ + 0,5) / L_u für κ = m − mi_rent_start + 1 ∈ {1…L_u}, sonst 0   (L_u = round(lease_up_months))
occ   = (1 − v_s) · (1 − v_r) · w · (1 − lu) · (1 − extra_loss_share_{p(m)})
coll  = 1 − rent_default_rate_{p(m)}
loss_m = −(rent_m + Σ_k levy_{k,m}) · (1 − occ · coll)
vac_m  = 1 − (1 − v_s) · (1 − v_r) · Π_k (1 − ν_k · W_k(m)) · (1 − lu)     # Leerstandsanteil für Bewirtschaftung/Energie
                                     # = Helfer rp_vacancy_share() je Gruppe (auch für energy_cost, 3.6.2)
```

Die Verlustfaktoren wirken **multiplikativ** (kein Verlust über 100 %). Minderung (α) und `extra_loss_share` zählen
nicht als Leerstand (`vac_m`), weil die Wohnungen bewohnt sind.

#### 1.8.5 Aggregation und Zeilen

```text
rent      = ctx$to_periods(rent_m)          # n x (T+1), Spalte 1 = 0
levy_<k>  = ctx$to_periods(levy_{k,m})      # je k ∈ levy_rows, auch wenn in allen Läufen 0
rent_loss = ctx$to_periods(loss_m)
```

#### 1.8.6 Lease-up

Linearer Anlauf über L_u Monate: Verlustanteil im κ-ten Monat (L_u − κ + 0,5)/L_u, Summe = L_u/2 Monatsmieten
(Prüfwert RP-10). Er verschiebt sich mit `rent_start`.

#### 1.8.7 Startbedingungen und Historie

- Eine Umlage mit Wirksamkeit vor dem ersten aktiven Monat (Neubau) ist ein Validierungsfehler; Umlagen setzen einen
  Bestandsmietvertrag voraus.
- Ohne `levy_history` sind die Kappungsfenster leer; mit Historie zählen frühere Umlagen bis 72 Monate zurück.
- `last_558_increase_date` steuert nur die Wartefrist; Erhöhungen nach §§ 559, 560 setzen sie nicht zurück
  (Memo 02 § 2.1).

#### 1.8.8 Mieterliste (`rent_roll`)

Ist `rent_roll` gesetzt, rechnet der Typ 1.8.1–1.8.4 je Wohnung u mit deren `living_area_m2`, Miete, Historie und
Kostenanteil λ_u = λ_g · A_u / A_g; die Zeilen sind die Summen über u. Kappung (2 € bzw. 3 €, Schwelle 7 €) und
§ 559c-Grenze wirken damit je Wohnung. Die Schleife über Wohnungen ist zulässig (deterministische Anzahl, Spec 00
§ 2.8 Nr. 5); die Laufzeit steigt linear mit der Anzahl (W > 50).

### 1.9 Umlage je Maßnahme (§§ 559, 559a, 559c, 559e, 559f BGB)

Für jede Maßnahme k ∈ `levy_rows` und die Gruppe g (Index g im Folgenden weggelassen, wo eindeutig). Alle Größen sind
n-Vektoren; die Umlage richtet sich **je Lauf** nach den realisierten Kosten und der tatsächlich gewährten Förderung
(Konzept § 3.5, Spec 00 § 9.11 Nr. 6). Spätere Energiepreis- oder JAZ-Pfade ändern sie nicht. Alle Beträge enthalten
den Aktivierungsfaktor a_k (0.8): K_k und G_k über die Zeilen der Kosten- und Zuschusskomponenten, TZ_k und Zint_k
über den Faktor a_k selbst; bei a_k = 0 entfällt die Umlage.

#### 1.9.1 Eingangsgrößen

| Größe | Bestimmung |
|---|---|
| K_k | aufgewendete Kosten brutto, nominal: −Σ_t Σ `ctx$rows(id = cost_components, category = "capex", measure_id = k)` (realisiert, inkl. Preisindex und Verschiebung; Filter nach Spec 00 § 6.2, R-93) |
| K⁰_k, ρ_k | K⁰_k = `ctx$value("measures.<k>.cost_eur")` (Preisstand der Maßnahme; das Blatt existiert immer, bei `cost_kg` bzw. Zahlungsplan mit `unit: eur` über `rule:cost_from_kg`, Teil A); ρ_k = K_k / K⁰_k (1, falls K⁰_k = 0) |
| o_k | Ohnehin-Quote: `ohnehin_cost_eur / cost_eur` bzw. `ohnehin_share` (Teil A), begrenzt auf [0, 1] |
| IH_k | Erhaltungsanteil nach `maintenance_share_method`: `ohnehin`: o_k · K_k; `linear_wear`: `fictitious_maintenance_cost_eur` · ρ_k · pmin(1, `component_age_years` / `component_life_years`) (fiktive Kosten Default o_k · K⁰_k); `fixed_share`: `maintenance_share` · K_k; `none`: 0. `auto`: `linear_wear`, wenn `component_age_years` gesetzt; sonst `ohnehin`, wenn o_k > 0 (I „Erhaltungsanteil = Ohnehin-Vollkosten, Obergrenze“); sonst 0 (I) |
| λ_k | Kostenanteil der Gruppe: `rent_law.allocation[g]`, sonst A_g / Σ_{g' ∈ unit_groups_k} A_{g'} (nicht zu verwechseln mit dem Aktivierungsfaktor a_k) |
| G_k | Zuschüsse: Σ_t Σ `ctx$rows(id = grant_components, category = "grant", measure_id = k)` (bereits × `approved`, Abschnitt 4.5) |
| w_{f,k} | Anteil des Förderkredits f an Maßnahme k: K_k / Σ_{j ∈ funding.<f>.measures} K_j (gleichverteilt, falls Summe 0) |
| TZ_k | Tilgungszuschüsse (Zuschuss i. S. d. § 559a Abs. 1): a_k · Σ_f w_{f,k} · TZ_f mit TZ_f = (`repayment_grant.share` · D_f bzw. `repayment_grant.amount_eur`) · approved_f · `repayment_grant.approved` · (1 − `repayment_grant.cut_share`); D_f = `ctx$value_base("financing.f_<f>_loan.amount_eur")` (Zusage, R-69; abgerufen = D_f · approved_f, Spec 00 § 8.3), approved_f = `financing.f_<f>_loan.approved` |
| Zint_k | Jahresbetrag der Zinsermäßigung: a_k · Σ_f w_{f,k} · L_f · pmax(i^ref_{f,k} − i_f, 0); L_f = D_f · approved_f (Ursprungsbetrag inkl. Baubegleitung), i_f = `…rate_pa`, i^ref = `funding.<f>.rent_law.reference_rate_pa` (Default `{ref: market.mortgage_rate}`) in der Periode des Fertigstellungsmonats mc_k (je Lauf); bei `interest_subsidy`: `interest_subsidy.subsidized_amount_eur · interest_subsidy.rate_reduction_pa · approved` |
| D_k, Z_k | φ_k · (G_k + TZ_k) bzw. φ_k · Zint_k mit φ_k = 1 (`full`) bzw. (K_k − IH_k)/K_k (`proportional`) |
| hv_k | Halbierung § 559f (deterministisch): `ctx$rule("mr_hp_halving")(heat_pump, jp_k, vt_k, building.construction_year, hp_exception, hp_threshold_inclusive)` mit jp_k = `energy.<hp_state>.jaz_plan` bzw. `ctx$value_base("energy.<hp_state>.jaz")` (Plan-JAZ, R-70) und vt_k = `energy.<hp_state>.flow_temperature_c`; 0, wenn das Thema `mietrecht_559f` inaktiv ist (0.9) |
| s43_k | `section43_heating` und nicht `section43_flat` |

#### 1.9.2 Verfahrenswahl (je Lauf, vektorisiert)

```text
dm_k   <- (G_k + TZ_k + Zint_k) > zero_abs                       # Drittmittel in Anspruch genommen
proc_k <- procedure, falls nicht auto (Codes der Familie levy_procedure, N-06)
          auto: "bgb_559e", falls kind = bgb_555b_1a und fundable_in_principle und dm_k; sonst "bgb_559"
proc_k = "bgb_559e" und nicht dm_k                  -> "bgb_559"   (I: Rückfall auf § 559, Konzept 3.5)
proc_k = "bgb_559c" und c_k > P$limit_559c_per_unit -> "bgb_559"   (W: Wertgrenze überschritten; Anteil der Läufe)
           c_k = K_k · λ_k / n_units + Σ 559c-Kosten derselben Gruppe der letzten 60 Monate (je WE)
gesperrt, falls eine § 559c-Erhöhung der Gruppe (Historie oder frühere Maßnahme) weniger als P$block_559c_months
           vor me_k wirksam wurde und kind ≠ bgb_555b_6   -> Umlage 0 (W)
nicht zulässig in der Phase von me_k: mr_levy_allowed(kind, rent_regime, phase(me_k), landlord_responsible,
           proc_k, P) = FALSE                              -> Umlage 0 (I)
```

#### 1.9.3 Jahresbetrag vor Kappungen (`mr_levy_annual`)

```text
§ 559 :  hv & halve_then_funds:  B = 0,5 · (K − IH) − D
         hv & funds_then_halve:  B = 0,5 · (K − IH − D)
         sonst:                     B = K − IH − D
         U = pmax(0, P$rate_559 · B − Z)                                   # § 559a Abs. 2: Zinsermäßigung vom Jahresbetrag
§ 559c:  B = (1 − P$flat_559c) · K − φc · (G + TZ),  φc = 1 (full) bzw. 1 − P$flat_559c (pro_rata)
         U = pmax(0, P$rate_559 · B)                                       # Zinsermäßigung nicht anwendbar
§ 559e:  f   = 0, falls s43; sonst P$flat_559e;   IH43 = IH, falls s43; sonst 0
         K'  = 0,5 · K und IH43' = 0,5 · IH43, falls hv & halve_then_funds; sonst K' = K, IH43' = IH43
         flat_before_funds:  B = (1 − f) · K' − IH43' − D           # F13: 0,10 · (0,85 · K − D)
         funds_before_flat:   B = (1 − f) · (K' − D) − IH43'
         falls hv & funds_then_halve:  B = 0,5 · B
         U = pmax(0, P$rate_559e · B − [interest_subsidy_in_559e] · Z)
U_g = λ_k · U;   u_k = U_g / (12 · A_g)   [EUR/m²·Monat];   hs_k = 1 bei § 559e, sonst heating_part_share_k
```

#### 1.9.4 Wirksamkeit

```text
mc_k = mi(completion_date_k) + s_k                                         # s_k = round(delay_months_k), je Lauf
me_k = mi(levy_effective_date_k), falls gesetzt (keine Verschiebung)
       sonst mi(Monatsanfang(declaration_date_k) + P$levy_effective_delay_months
                + [nicht announcement_ok] · P$levy_delay_defective_months) + s_k
```

Monatsanfang = Erster des Zugangsmonats (abgerundet). Beispiel: Fertigstellung und Erklärung am 2027-10-01 →
wirksam ab 2028-01-01 (S1, S3); Zugang am 2027-09-15 → ab 2027-12-01.

#### 1.9.5 Kappung, freiwillige Obergrenze, Härte

- `mr_levy_cap_total(rent_before, prior_6y)` = pmax((rent_before < P$cap_low_threshold ? P$cap_low : P$cap_high) −
  prior_6y, 0); `rent_before` = T vor der Erhöhung (inkl. früherer Umlagen), `prior_6y` = Summe der Umlagen mit
  Wirksamkeit in den 71 Vormonaten (inkl. `levy_history`).
- `mr_levy_cap_heating(prior_heat_6y)` = pmax(P$cap_heating − prior_heat_6y, 0) (§ 559 Abs. 3a S. 3, § 559e).
- Reihenfolge (F14): erst Heizungsanteil kappen, dann die Gesamtkappe; mehrere Maßnahmen mit gleichem
  Wirksamkeitsmonat werden proportional gekürzt (1.8.2 (e)).
- **Freiwillige Obergrenze** vcap (EUR/m²·Monat, kumuliert über alle Umlagen der Gruppe), fest in allen Läufen
  (Beschluss, Konzept § 3.5; Spec 00 § 4.3.6a):
  - `voluntary_cap_mode = fixed`: vcap = `voluntary_cap_per_m2` über `ctx$param()` (Designwerte einer Zielwertsuche
    wirken; ein Overlay-Eintrag darauf ist W „Beschluss ist fest“); ohne Wert Inf.
  - `voluntary_cap_mode = warm_rent_neutral` (R-70, R-102): vcap_g = pmax(0, `saving_eur_m2_month`) der Komponente
    `tenant_cost_component` aus `ctx$component_base()` in der **Bezugsperiode** j* (Spec 00 § 6.3, § 4.3.6a): der ersten Periode mit 12 Monaten,
    die am oder nach dem frühesten Wirksamkeitsmonat me_k des Basisfalls (Verschiebung mit
    `ctx$value_base("measures.<k>.delay_months")`) beginnt (bei Wirksamkeit am 1. Januar
    das Kalenderjahr der Wirksamkeit). `saving_eur_m2_month` = (`energy_pre` − `energy`) / (vermietete Fläche ·
    Monate), 3.8. Damit ist `warm_rent_change_prepost` in j* ≤ 0 und = 0, wenn die Obergrenze bindet. Die
    Begrenzung gilt für alle späteren Umlagen der Gruppe gleich (eine Obergrenze je Gruppe).
  - Gegenprobe und Variante mit eigenem Zielwert: `vofi_solve(kpi = "warm_rent_change_prepost_y1", target = 0,
    param = "unit_groups.<g>.rent_law.voluntary_cap_per_m2")` im Modus `fixed` (Spec 00 § 12.8).
- `hardship_share` mindert nur die Zahlung (1.8.3), nicht das rechtliche Mietniveau T (Kappungs- und § 558-Basis).

#### 1.9.6 Rechenweg im Bericht

Je Maßnahme und Gruppe liefert `aux` die Kette „rechnerisch → gekappt → angesetzt“: `levy_<k>_computed` (U_g, EUR/a),
`levy_<k>_capped` (l_k · 12 · A nach Kappung), `levy_<k>_charged` (nach freiwilliger Obergrenze, vor Härte), jeweils
in der Spalte der Wirksamkeitsperiode (sonst 0), sowie `levy_<k>_procedure` (Code 0 keine, 1 § 559, 2 § 559c, 3 § 559e).
Beispiel S1 V2 (Prüfwerte L-1, L-2, RP-5): rechnerisch 53.842,28 EUR/a (2,804285 EUR/m²·Monat) → Kappe 2,00 EUR/m²
(Miete vor Erhöhung 6,20 < 7,00) → 38.400,00 EUR/a → Beschluss 1,10 EUR/m² → 21.120,00 EUR/a.

### 1.10 Kürzungsbeträge nach § 558 Abs. 5

Nur in den OVM-Modi (`max`, `interval`, `capped`) und bei `kuerzung_558_5 = true`. Für jede k ∈ `rent_law_measures`
(auch ohne Umlagezeile):

```text
K558_k(m) = λ_k / (12 · A_g) · [ P$kuerzung_rate_grant · (G_k + TZ_k) · 1{mc_k <= m < mc_k + 12 · kuerzung_grant_years}
                              + Σ_f w_{f,k} · L_f · pmax(i^ref − i_f, 0) · 1{ml_f <= m < ml_f + 12 · y_f} ]
   ml_f = mi(financing.f_<f>_loan.start);  y_f = kuerzung_loan_years %||% financing.f_<f>_loan.fixed_years
```

Die Kürzung wird in 1.8.2 (f) **nach** der Kappungsgrenze vom Zielwert abgezogen (Memo 02 § 2.1; Auslegung offen,
Abschnitt 9) und wirkt auf jede § 558-Erhöhung im Kürzungszeitraum. Die Zurechnung `proportional` gilt hier nicht
(volle Drittmittel der Wohnung). Bei `fixed_growth` gibt es keine § 558-Prüfung; liegen Drittmittel vor, folgt I
(„Kürzung nach § 558 Abs. 5 nur in den Vergleichsmieten-Modi abgebildet“).

### 1.11 Genossenschaft (`cooperative_fee`)

- Nutzungsverträge sind Mietverträge; §§ 558 ff. gelten unverändert. `cooperative_fee` rechnet wie
  `paragraph_558`; Labels lauten „Nutzungsentgelt“ statt „Nettokaltmiete“ (Label-Schlüssel
  `types.flow.rent_path.rows.rent_cooperative`, Auswahl über `rent_regime`).
- Modernisierungsumlage nach §§ 559/559e mit Beschlussparameter `voluntary_cap_per_m2` (B3). Bei
  `perspective = wu_genossenschaft` setzt `rule:unit_group_defaults` für vermietete Gruppen `rent_regime:
  cooperative_fee` (5.5, N-08); `modernization_levy: auto` kommt aus `item_defaults` (7.1). Das Profil setzt keine
  Gruppenfelder (Spec 00 § 4.7, R-76).
- Kostendeckendes Nutzungsentgelt: Zielwertsuche `vofi_solve()` mit `param = unit_groups.<g>.rent_eur_m2_month` und
  Ziel `dscr_min = analysis.thresholds.dscr` bzw. `delta_vs_reference = 0` (Spec 00 § 12.8, WS-G).
- PV-Strom an Mitglieder: Default 0 ct (`energy.pv.internal_price_eur_kwh = 0`, B3); der Vorteil fällt den
  Mitgliedern über die Heizkosten zu (Abschnitt 3.8).

### 1.12 Reformschalter `mietrecht_ii` (Standard aus, D10)

Aktiv nur, wenn `mietrecht_ii` ∈ `project.pending_reforms`; dann wählt `ctx$legal("mietrecht")` den Eintrag
`legal/mietrecht_ii_reform` (Teil C, Kette auf `legal/mietrecht_2026`, Spec 00 § 4.10). Die Regeln sind dieselben;
die Unterschiede stehen in der Nutzlast und wirken über `mr_params`:

| Größe in P (5.2) | Nutzlast (Teil C) | geltend | `mietrecht_ii` (BT-Drs. 21/6807) |
|---|---|---|---|
| `limit_559c_per_unit` | `s559c.cost_limit_per_unit_eur` | 10.000 EUR | 20.000 EUR |
| `minderung_exclusion_kinds` | `s536_1a.scope` | `bgb_555b_1` | `bgb_555b_1`, `bgb_555b_1a` |
| `staffel_excludes` (`mr_levy_allowed` bei Staffelmiete) | `s557a.excludes` | §§ 558, 559, 559b ausgeschlossen, § 559e zulässig | auch § 559e ausgeschlossen |
| `index_damping` (`mr_index_adjustment`) | `s557b.damping` | `NULL` (π) | in `index_cap_area`: π, falls \|π\| ≤ 3 %; sonst ±3 % + 0,5 · (π ∓ 3 %) |
| `relet_levy_procedures` (`mr_relet_rent`, § 556e Abs. 2) | (Regelkonstante) | `bgb_559`, `bgb_559c` | zusätzlich `bgb_559e` (Abschnitt 9) |

### 1.13 Zeilen, Hilfsgrößen, Diagnose

| lokale Zeile | section | category | tax_category | cash | kind | `measure_id` | VZ | Label (`types.flow.rent_path.rows.*`) |
|---|---|---|---|:---:|---|---|:---:|---|
| `rent` | project | `rent` | `income_rental` | T | flow | – | + | „Nettokaltmiete (Soll)“ bzw. „Nutzungsentgelt (Soll)“ |
| `rent_loss` | project | `rent_loss` | `income_rental` | T | flow | – | − | „Erlösminderung (Leerstand, Ausfall, Minderung)“ |
| `levy_*` (je k ∈ `levy_rows`) | project | `modernization_levy` | `income_rental` | T | flow | k | + | „Modernisierungsumlage {id}“ |

Alle Zeilen: `unit = "EUR"`, `vat_rate = 0`. `rows = c("rent", "rent_loss", "levy_*")`.

`aux` (n × (T+1), Spalte 1 = 0): `vacant_share` (Monatsmittel vac_m über aktive Monate), `rent_level`,
`base_level`, `levy_level` (Monatsmittel von T, B, Σ L in EUR/m²·Monat), `ovm_level`, `market_level`,
`kuerzung_level`, `voluntary_cap_level` (vcap, Inf als NA), `area_m2` (A in jeder Spalte), `levy_<k>_computed`, `levy_<k>_capped`, `levy_<k>_charged`,
`levy_<k>_procedure` (1.9.6). `meta`: je Maßnahme Anteil der Läufe je Verfahren und mit bindender Kappung,
gesammelte Hinweise.

### 1.14 Randfälle und Validierung

| Fall | Behandlung |
|---|---|
| OVM-Modus ohne `ovm_eur_m2_month` | E (WS-B, `validation.unit_groups.ovm_missing`) |
| Miete > OVM zu Beginn | keine § 558-Erhöhung bis OVM > T (kein Fehler); I bei T > 1,2 · OVM |
| `increase_policy = interval` mit `interval_months < 15` | E |
| Staffel mit Erhöhung und Umlage im selben Monat | Staffel (a) vor Umlage (e) |
| Umlage, deren Wirksamkeit nach `rent_end` oder nach dem Horizont liegt | entfällt (I) |
| Maßnahme in Gruppe mit `bound_social` | keine Umlage (I); Kürzung entfällt mangels § 558 in der Bindung |
| Umlage bei Neubau (`rent_start` ≥ Wirksamkeit) | E |
| K − IH − D ≤ 0 | Umlage 0, Zeile bleibt (Bericht: „Drittmittel übersteigen die umlagefähigen Kosten“) |
| Wärmepumpe ohne `jaz_plan` | Plan-JAZ = Basisfallwert von `jaz` (I); `heat_pump = true` ohne `hp_state`: W, § 559f-Halbierung angewendet (vorsichtige Lesart) |
| Thema `mietrecht_559f` inaktiv (C-Eintrag ohne Freigabe) | keine Halbierung, Vermerk in `meta$notes` (Spec 00 § 4.10, R-80) |
| a_k = 0 in einem Lauf | keine Umlage, kein OVM-Zuschlag, keine Bauzeitverluste, keine Kürzung für k in diesem Lauf |
| `warm_rent_neutral` ohne `before` bzw. ohne Ersparnis | vcap = 0 (W), Umlage 0 |
| `procedure: bgb_559c` und Kosten je WE über Grenze | W, Rückfall auf § 559 im betroffenen Lauf |
| `procedure: 559` (Zahl) bzw. `"559c"` (Alias) | Normalisierung auf `bgb_559` bzw. `bgb_559c` mit `vofi_warning_input` (Spec 00 § 2.11) |
| Härte + freiwillige Obergrenze | Obergrenze zuerst (Rechtsniveau), Härte mindert die Zahlung |
| Fluktuation ohne Marktmiete | Wiedervermietung ohne Wirkung (I einmalig) |
| Mietpreisbremse nach `brake_until` | Marktmiete ohne Begrenzung |
| `vacancy_rate + rent_default_rate > 0,3` | W |
| Laufabhängige Verschiebungen | Masken je Lauf; bei unterschiedlichen me_k in Läufen entstehen verschiedene Kappungsfenster (korrekt) |

### 1.15 Testfälle `rent_path` und Mietrechtsregeln

Gemeinsame Annahmen, wenn nicht anders angegeben: `valuation_date` 2027-01-01, Jahresraster, n = 1 (deterministisch)
sowie n = 2 und n = 7 mit identischen Zeilen (Spec 00 § 2.8 Nr. 8). Testdateien (N-18): `test-type-flow-rent-path.R`
(RP-*) und `test-rules-mietrecht.R` (L-*), beide WS-E (Spec 00 § 15.6, R-104).

| Nr. | Eingabe | Erwartung |
|---|---|---|
| RP-1 (Memo 02 § 2.2, `mietpfad_ref.py`) | A = 70 m², R₀ = 7,50, `ovm_eur_m2_month` 8,00, `rent_growth` 0,025, Maßnahme mit Fertigstellung 2027-03-01 und `ovm_uplift_eur_m2_month` 1,20, `kappung_15_area: true`, `rent_36m_ago` 7,50, `last_558_increase_date` 2026-06-01, `increase_policy: max`; Umlage aus K = 21.000 EUR (IH 0, keine Drittmittel, § 559) mit `levy_effective_date` 2027-03-01 → 2,00 EUR/m² | Monat 3: T = 9,50 > OVM 9,257 (keine Erhöhung); § 558-Erhöhungen (Monat, T): (16; 9,5079), (31; 9,8060), (46; 10,1134), (61; 10,4304), (76; 10,7574), (91; 11,0946), (106; 11,4424); Kappungsgrenze bindet nicht (Monat 16: 10,625). Zeilen: `rent` 2027 6.300,00, 2028 6.305,00, 2029 6.431,85, 2030 6.621,58; `levy_k` 2027 1.400,00, ab 2028 1.680,00 |
| RP-2 | R₀ = 6,00, OVM 8,00 konstant, `rent_36m_ago` 6,00, letzte Erhöhung 2025-01-01, `max` | k = 0,20: T = 7,20 ab Monat 1, 8,00 ab Monat 37; k = 0,15: 6,90 ab Monat 1, 7,935 ab Monat 37, 8,00 ab Monat 73 |
| RP-3 (§ 558 Abs. 5) | wie RP-2 (k = 0,20) mit R₀ = 7,00, OVM 9,00, Maßnahme fertig 2027-01-01 ohne Umlage, Zuschuss G = 10.500 EUR (λ = 1) | Kürzung 0,08 · 10.500 / (12 · 70) = 1,00 EUR/m²; T = 7,40 ab Monat 1 (statt 8,40), bis Monat 24 unverändert |
| RP-4 (S1 V1) | A = 1.600, R₀ = 6,20, `fixed_growth`, 0,015, `growth_from` 2028-01-01 | `rent` 2027 119.040,00; 2028 120.825,60; 2029 122.637,98; 2030 124.477,55; 2031 126.344,72. Mit `vacancy_rate` 0,03 und `rent_default_rate` 0,01: `rent_loss` 2027 −4.725,89, 2028 −4.796,78 |
| RP-5 (S1 V2) | wie RP-4, `growth_from` 2029-01-01, `total`, Umlage U = 53.842,28 EUR/a wirksam 2028-01-01, `voluntary_cap_per_m2` 1,10 | `levy_k` 2028–2031 je 21.120,00; `rent` 2027 119.040,00; 2028 119.040,00; 2029 121.142,40; 2030 123.276,34; 2031 125.442,28. Ohne Beschluss: `levy_k` 2028 38.400,00 |
| RP-6 (Fluktuation, Mietpreisbremse) | A = 100, R₀ = 8,00, `rent_growth` 0, OVM 9,00, Marktmiete 11,00 (konstant), `turnover_rate_pa` 0,12, `brake_area: true` (bis 2029-12-31) | T nach 12 Monaten 8,215869 (stationär 9,90); `rent` 2027 9.742,90. Ohne Bremse: T₁₂ = 8,340845, `rent` 2027 9.825,63 |
| RP-8 (Staffel) | A = 100, R₀ = 8,00, Staffeln 2028-01-01: 8,30; 2029-07-01: 8,60 | `rent` 2027 9.600,00; 2028 9.960,00; 2029 10.140,00; Umlagen nach § 559 in der Laufzeit: 0 (I) |
| RP-9 (Index) | A = 100, R₀ = 8,00, `index_rate` 2027: 0,028, ab 2028: 0,022 | `rent` 2027 9.600,00; 2028 9.868,80; 2029 10.085,91. `mietrecht_ii` + `index_cap_area`, π = 5 %: 2028 9.984,00 (4 %), 2029 10.383,36 |
| RP-10 (Lease-up) | A = 100, R₀ = 10,00, `lease_up_months` 4 | `rent_loss` Monate 1–4: −875, −625, −375, −125; Jahr 2027: −2.000,00 |
| RP-11 (Minderung, § 536 Abs. 1a) | A = 100, R₀ = 10,00, Arbeiten 2027-01-01 bis 2027-10-01, α = 0,20, Kind `bgb_555b_1` | `rent_loss` 2027 −1.200,00 (6 von 9 Monaten); Kind `bgb_555b_4`: −1.800,00 |
| RP-12 (Förderung fällt aus) | S3-Heizung K = 153.560, `ohnehin_cost_eur` 45.360, Zuschuss mit `approved = 0`, A = 840, R₀ = 6,40, Kind `bgb_555b_1a`, `procedure: auto` | Rückfall § 559: U = 8.656,00 EUR/a (0,858730 EUR/m²) → Heizungskappe 0,50 → 5.040,00 EUR/a (wie mit Förderung: „bindet die Kappung, entlastet Förderung nur den Vermieter“) |
| RP-13 (Batch) | RP-5 mit n = 7, `delay_months` = 0, 3, 6, …, 18 je Lauf | Lauf i identisch mit Einzellauf (F7); Wirksamkeit ab Monat 13 + 3(i − 1) |
| L-1 (S1-T4, F14) | K = 1.451.488,50, IH = 577.185,00 (`ohnehin`), TZ = 144.400, Zint = 1.300.000 · (4,00 % − 3,65 %) = 4.550, `full` | U = 53.842,28 EUR/a (2,804285 EUR/m²·Monat bei 1.600 m²); `proportional`: 60.245,25; Lesart Memo 07 (TZ voll, Zinsermäßigung anteilig, Faktor 0,602350): 55.651,59 |
| L-2 (synthetischer Aggregatfall auf Basis S1-T4/T5; **nicht** S1-T4a) | L-1 als **eine** Sammelmaßnahme, T vor Erhöhung 6,20 | gekappt 2,00 EUR/m² = 38.400,00 EUR/a; mit `heating_part_share` 0,256082 (300.000/1.171.500, Näherung nach 1.4): Heizungsanteil 0,718127 → 0,50 → gesamt 2,586159 → Gesamtkappe 2,00 (38.400,00; angerechneter Heizungsanteil 0,386674); bei T = 7,20: 2,586159 EUR/m² = 49.654,24 EUR/a. Die Rechnung je Maßnahme (S1-T4a, Teil C: eigener Erhaltungsanteil und TZ-/Zinsanteil der Heizung) ergibt bei T = 7,20 einen anderen Wert; beide kappen bei T = 6,20 auf 2,00 |
| L-3 (S3-T3, F13) | K = 153.560, G = 45.300, § 559e, A = 840 | 8.522,60 EUR/a (0,845496 EUR/m²) → Kappe 0,50: 5.040,00 → Beschluss 0,35: 3.528,00; `funds_before_flat`: 9.202,10 |
| L-4 (S3-T4, F13) | L-3 mit Wärmepumpe, `jaz_plan` 2,4, Vorlauf 70 °C, Baujahr 1985; Thema `mietrecht_559f` aktiv (freigegebener Eintrag bzw. `pending_reforms: [unreleased]`) | `halve_then_funds`: 1.996,30 EUR/a; `funds_then_halve`: 4.261,30 EUR/a (beide unter 5.040). Lesart Memo 07 (`funds_before_flat`): 2.675,80 bzw. 4.601,05. Plan-JAZ 2,5: keine Halbierung (`hp_threshold_inclusive`); Vorlauf 55 °C: Ausnahme, keine Halbierung; Thema inaktiv: 8.522,60 (wie L-3); realisierte `jaz` 2,0 im MC ändert hv nicht |
| L-5 (Memo 02 Bsp. 1) | K = 60.000, IH 30 % = 18.000, TZ = 3.000, Zint = 60.000 · (3,80 % − 3,53 %) = 162, A = 70, T = 7,50 | U = 2.958,00 EUR/a (3,521429 EUR/m²) → Kappe 3,00: 210,00 EUR/Monat = 2.520,00 EUR/a |
| L-6 (Memo 02 Bsp. 2) | K = 18.000/WE, `procedure: bgb_559c`, keine Zuschüsse | geltendes Recht: W, Rückfall § 559 (IH 0): 1.440,00 EUR/a; `mietrecht_ii`: 1.008,00 EUR/a = 84,00 EUR/Monat |
| L-7 (Memo 02 Bsp. 3) | je WE K = 15.000, G = 4.500, § 559e, 70 m² | 825,00 EUR/a (0,982143 EUR/m²) → 35,00 EUR/Monat = 420,00 EUR/a; § 559 ohne Förderung, IH 40 %: 720,00 EUR/a → ebenfalls 35,00 EUR/Monat |
| L-8 | Vorumlagen 1,50 EUR/m² in 6 Jahren, T = 7,50, neue Umlage 2,00 | angesetzt 1,50 |
| L-9 | Heizungsvorumlage 0,30; neue Maßnahmen gleichzeitig: Heizung 0,40, Hülle 1,00 (T = 7,50) | Heizung 0,20, Hülle 1,00 |
| L-10 | gleichzeitig Heizung 0,80 und Hülle 2,80, T = 7,50, keine Vorumlagen | Heizung 0,454545, Hülle 2,545455 (Heizung 0,80 → 0,50; Summe 3,30 → 3,00, proportional) |
| L-11 (Wirksamkeit) | Erklärung 2027-10-01 / 2027-09-15 / 2027-10-01 mit `announcement_ok: false` | wirksam 2028-01-01 / 2027-12-01 / 2028-07-01 |
| L-12 (`mr_levy_allowed`, N-06) | Phase `staffel`, Kind `bgb_555b_1a`, Verfahren `bgb_559` / `bgb_559c` / `bgb_559e`; dasselbe mit `mietrecht_ii`; Phase `index` mit Kind `bgb_555b_1` (`landlord_responsible: true`) / `bgb_555b_1a` / `bgb_555b_6` | geltendes Recht: FALSE / FALSE (`bgb_559c` zählt als `bgb_559`) / TRUE; `mietrecht_ii`: FALSE / FALSE / FALSE; Index: FALSE / TRUE / TRUE (Verfahren `bgb_559`) |
| L-13 (Alias) | `measures.<k>.rent_law.procedure: 559` (YAML-Zahl) bzw. `"559e"` | normalisiert `bgb_559` bzw. `bgb_559e` mit `vofi_warning_input`; Ergebnis identisch zur kanonischen Eingabe |
| RP-14 (warmmietenneutral) | TC-1 (3.11): A = 1.000 vermietet, R₀ = 6,00, eine Maßnahme (Hülle und Wärmepumpe, `bgb_555b_1`, `heating_part_share` 0,25) mit Umlage rechnerisch 1,20 EUR/m² (Heizungsanteil 0,30 < 0,50, gesamt < 2,00) wirksam 2028-01-01, `voluntary_cap_mode: warm_rent_neutral` | vcap = 1,013285 EUR/m²·Monat (Basisfall 2028); `levy_k` 2028 12.159,42; `warm_rent_change_prepost` 2028 = (12.159,42 + 4.998,00 − 17.157,42) / 12.000 = 0; im MC bei abweichenden Energiepreisen unverändert 12.159,42 |
| RP-15 (Aktivierung) | RP-5 mit `measures.<k>.active` = (1, 0) in zwei Läufen | Lauf 1 wie RP-5; Lauf 2: `levy_k` 0; `rent` 2027 119.040,00, 2028 119.040,00, 2029 120.825,60 |

### 1.16 Sonstige Erlöse

- **Stellplätze, Garagen, Werbeflächen**: Komponenten vom Typ `recurring` mit `category: operating_income` (Spec 00
  R-33, Anhang B); Betrag z. B. als Mengenbezug `{value: …, per: parking}` (Bezugsgröße `n_parking`, Spec 00 § 4.5,
  R-91), Wachstum über `growth`. Verwaltungskosten je Stellplatz über `unit_groups.<g>.operating`.
- **PV-Einspeisung und PV-Eigenverbrauch**: Typ `pv` (Abschnitt 3.9).
- **Mieterstrom, gemeinschaftliche Gebäudeversorgung** (§§ 42a, 42b EnWG): in v1 nur als `custom_series` mit
  `category: energy_income`; die Validierung meldet W („Mieterstrom nur als frei definierte Zahlungsreihe; Modul v2“,
  Konzept C10). Bei `perspective = wu_genossenschaft` zusätzlich der Hinweis zur Befreiungsgrenze (Abschnitt 3.9.3).

---

## 2. Bewirtschaftung

### 2.1 Abgrenzung

- Umlagefähige Betriebskosten (BetrKV) sind beim Vermieter **durchlaufend**. Kostenwirksam sind nur: Leerstand,
  nicht umlagefähige Positionen, Verwaltung, die Grundsteuer im Leerstand, in der Bauphase und bei Selbstnutzung,
  CO₂-Vermieteranteil, § 5a-Netzentgeltanteil und Bio-Mehrkostenanteil (Abschnitt 3) (Konzept § 3.6, Memo 02 § 1.7).
- Instandhaltung (Pauschale je m², baualtersabhängig, Instandhaltungsersparnis durch Maßnahmen, Prüfung der
  Doppelzählung mit Ersatzinvestitionen) ist der Typ `maintenance` in **Teil A**. `operating_cost` enthält keine
  Instandhaltung.
- Heiz- und Warmwasserkosten einschließlich umlagefähiger Wartung der Heizung stehen im Energieteil
  (`energy_cost.service`, Abschnitt 3.6), nicht hier.
- Das Mietausfallwagnis (2 % des Rohertrags, ImmoWertV) ist eine Bewertungsgröße des Restwerts (Teil A); im
  Zahlungsstrom wirken Leerstand und Forderungsausfall (`rent_path`, 1.8.4).

### 2.2 Teilbaum `unit_groups.<g>.operating` und Typ `operating_cost`

**Domänenfelder**

| YAML-Pfad (`unit_groups.<g>.operating.`) | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `admin_per_unit_eur_pa` | value | EUR/(WE·a) | 367 (G: `{from: costs/bewirtschaftung_immowertv_2026, use: admin_per_unit_or_efh_eur_pa}`, Qualität B, N-03); bei `rent_regime: bound_social` (ausdrücklich oder über ein Instrument `rent_binding` der Gruppe): 372,46 (AR, Wert aus `costs/bewirtschaftung_ii_bv_2026`, `admin_per_unit_eur_pa`); 0 bei `owner_occupied` (AR) | nein | W > 1.000 | Verwaltungskosten je WE (Preisstand `price_base_year`); WU überschreiben mit Ist-Kosten | 03 §8.1–8.2; Konzept 3.6 |
| `n_parking` | int ≥ 0 | Stück | 0 | nein | – | Stellplätze/Garagen der Gruppe (Bezugsgröße von `per: parking`, Spec 00 § 4.5) | 02 §9.6 |
| `admin_per_parking_eur_pa` | value | EUR/(Stp.·a) | 48 (G: `{from: costs/bewirtschaftung_immowertv_2026, use: admin_per_garage_eur_pa}`); 48,58 bei `bound_social` (AR, II. BV `admin_per_garage_eur_pa`); 0 bei `owner_occupied` (AR) | nein | – | Verwaltung je Stellplatz | 03 §8 |
| `nonrecoverable_share_of_rent` | value (share) | – | 0,01 (G; Memo 03 § 8.3, Qualität D); 0 bei `owner_occupied` (AR) | nein | W > 0,05 | nicht umlagefähige Betriebskosten in % der Sollmiete inkl. Umlagen | 03 §8.3 |
| `nonrecoverable_eur_m2_pa` | value | EUR/(m²·a) | 0 (T) | nein | W > 0 und Anteil > 0 („Doppelzählung prüfen“) | alternativ bzw. zusätzlich je m² | 02 §9.6 |
| `recoverable_opex_eur_m2_month` | value | EUR/(m²·Monat) | 1,70 (G; eigene Ableitung D: GdW 2024 kalte BK 1,90 abzüglich Grundsteuer ≈ 0,20, Memo 03 § 8.3) | nein | W > 4; W `validation.unit_groups.owner_opex_double` bei selbstgenutzter Gruppe, wenn der Wert aus `item_defaults` stammt (Herkunft `global#item_defaults.unit_groups`) und das Szenario zugleich eine eigene Komponente der Kategorie `operating_cost` oder `other_cost` enthält („Pauschale enthält Gebäudeversicherung, Wasser, Abwasser, Müll; Wert für die Gruppe ausdrücklich setzen, z. B. 0“, F-11) | umlagefähige kalte Betriebskosten nach BetrKV (u. a. Wasser/Abwasser, Müll, Straßenreinigung, Gebäudeversicherung, Allgemeinstrom, Hauswart, Gartenpflege) **ohne** Grundsteuer und ohne Heizung/Warmwasser; Grundlage für Leerstand (Vermieter), Selbstnutzer (voll) und Mietersicht. Der Wert ist ein Mittel für Mehrfamilienhäuser; Selbstnutzer eines EFH setzen ihre eigenen Nebenkosten | 03 §8.3; 02 §9.6 |
| `vacancy_opex_scope` | enum `cold`, `warm` | – | `cold` (G) | nein | – | `warm`: `recoverable_opex_eur_m2_month` enthält auch Heizkosten; dann entfallen die Vermieter-Leerstandsanteile in `energy_cost` (Doppelzählung) | 07 S1 |
| `growth` | value (Rate, Pfad) | 1/a | `{ref: market.inflation}` (G) | nein | – | Fortschreibung der Verwaltungskosten (VPI, wie ImmoWertV Anl. 3) | 03 §8.2 |
| `opex_growth` | value (Rate, Pfad) | 1/a | `{ref: market.operating_cost_growth}` (G; Teil C: VPI + 0,5 Pp, Kopplung K11, Qualität D) | nein | – | Fortschreibung der Betriebskosten je m² (`recoverable_opex_eur_m2_month`, `nonrecoverable_eur_m2_pa`) | 03 §5 |
| `base_date` | timing | – | Preisstand (A, R-35) | nein | – | Preisstand der Eingaben | Spec 00 R-35 |

**Typ `operating_cost`** (WS-E, `R/type-flow-operating-cost.R`), `grid_invariant = TRUE`.

| Parameter | `vofi_param`-Art | Default (T) | Expander-Belegung |
|---|---|---|---|
| `n_units` | `integer` | 1 | `unit_groups.<g>.n_units` |
| `living_area_m2` | `number` | Pflicht | ref |
| `admin_per_unit_eur_pa`, `admin_per_parking_eur_pa` | `amount` | 0, 0 | ref |
| `n_parking` | `integer` | 0 | Wert |
| `nonrecoverable_share_of_rent` | `share` | 0 | ref |
| `nonrecoverable_eur_m2_pa` | `amount` | 0 | ref |
| `recoverable_opex_eur_m2_month` | `amount` | 0 | ref |
| `vacancy_opex_scope` | `enum` | `cold` | Wert |
| `growth`, `opex_growth` | `value` (path) | 0, 0 | ref |
| `base_date` | `timing` | Preisstand | Wert |
| `start_event`, `to` | `timing` | Token `completion`, `end_date` | `rent_start`/`rent_end` der Gruppe (bei Selbstnutzer-Neubau: Token `completion`); Name nach Spec 00 § 4.9, R-110 |
| `owner_occupied` | `logical` | `false` | Wert |
| `rent_component` | `ref` | `null` | `u_<g>_rent` (vermietete Gruppe) |
| `perspective_tax` | `enum` `deductible`, `nondeductible` | `deductible` | `nondeductible` bei `selbstnutzer` |

**Algorithmus**

```text
I   <- ctx$index_year(growth, base_date);  Io <- ctx$index_year(opex_growth, base_date)
ov  <- ctx$shift_overlap(start_event, shift_start, to);  D <- by_period(delta)
v   <- rent_component ? ctx$component(rent_component)$aux$vacant_share : 0          # n x (T+1)
Rr  <- rent_component ? Σ Zeilen rent + levy_* der Mietkomponente : 0            # Sollmiete
admin          = −(admin_per_unit · n_units + admin_per_parking · n_parking) · I · D · ov
nonrecoverable = −nonrecoverable_share_of_rent · Rr − nonrecoverable_eur_m2_pa · A · Io · D · ov
vacancy_opex   = −recoverable_opex · 12 · A · Io · D · ov · v                  (nur vermietete Gruppen)
owner_opex     = −recoverable_opex · 12 · A · Io · D · ov                      (nur owner_occupied)
tenant_opex    = +recoverable_opex · 12 · A · Io · D · ov                      (Merkzeile, nur vermietete Gruppen;
                                                                              Vollvermietungsbasis für die Warmmiete)
```

**Zeilen**

| lokale Zeile | section | category | tax_category | cash | VZ |
|---|---|---|---|:---:|:---:|
| `admin` | project | `operating_cost` | `expense_deductible` (Selbstnutzer `expense_nondeductible`) | T | − |
| `nonrecoverable` | project | `operating_cost` | dito | T | − |
| `vacancy_opex` | project | `operating_cost` | `expense_deductible` | T | − |
| `owner_opex` | project | `operating_cost` | `expense_nondeductible` | T | − |
| `tenant_opex` | memo | `tenant_operating_cost` | `not_applicable` | F | + |

Zeilen, deren Parameter in allen Läufen 0 sind, entfallen (Ausnahme: `admin` bleibt immer, damit die Tabelle stabil
ist). `vat_rate` = 0,19 für `vacancy_opex`, `owner_opex`, `nonrecoverable` (Lieferleistungen), 0 für `admin`
(Personalkosten, Näherung; nur Anzeige).

**Tests** (`test-type-flow-operating-cost.R`, WS-E): O-1 Verwaltung 24 WE × 367 EUR, Preisstand 2026, VPI 2,8 %/2,2 %: 9.054,62 (2027), 9.253,83 (2028),
9.457,41 (2029). O-2 `nonrecoverable_share_of_rent` 0,01 auf Soll 119.040,00: −1.190,40. O-3 Leerstand 3 %, 1,70 EUR/m²,
1.600 m², `opex_growth` = VPI 2027 2,8 %: `vacancy_opex` 2027 −1.006,62; `tenant_opex` 2027 +33.553,92 (1,70 · 12 · 1.600 · 1,028).
O-4 F10: Jahressumme 2027 auf Raster `mixed` = `annual` (Toleranz 1e-9 relativ). O-8 (Defaults, `test-profiles.R`
bzw. `test-scenario-layers.R`, WS-A): Gruppe ohne `operating` bei `wu_kommunal` → `admin_per_unit_eur_pa` 367 (Herkunft
`costs/bewirtschaftung_immowertv_2026`), bei `selbstnutzer` → 0 (Herkunft `rule:unit_group_defaults`), bei
`rent_regime: bound_social` → 372,46 (Herkunft `costs/bewirtschaftung_ii_bv_2026`).

### 2.3 Teilbaum `building.property_tax` und Typ `property_tax`

**Domänenfelder** (Eigentum Teil B; übrige `building`-Felder Teil A)

| YAML-Pfad (`building.property_tax.`) | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `amount_eur_pa` | value | EUR/a | `null` | bedingt (Selbstnutzer, Bauphase) | I fehlt bei Vermietung („wirkt nur im Leerstand“); W fehlt bei `selbstnutzer` | Jahresbetrag (Preisstand); alternativ Messbetrag × Hebesatz | 06 §3.4, §8 |
| `assessment_amount_eur` | value | EUR | `null` | nein | E zusammen mit `amount_eur_pa` | Grundsteuermessbetrag | 06 §8 |
| `municipal_multiplier` | value (num) | – (5,00 = 500 %) | `null` | bedingt | E fehlt bei Messbetrag | Hebesatz | 06 §8 |
| `land_amount_eur_pa` | value | EUR/a | (A) = `amount_eur_pa` | nein | – | Grundsteuer in der Bauphase (unbebautes Grundstück, ggf. Grundsteuer C) | 06 §3.4 |
| `amount_after_completion_eur_pa` | value | EUR/a | `null` (= unverändert) | nein | – | Betrag nach Neubewertung | 06 §8 |
| `after_completion_from` | timing | – | (A) 1. Januar nach Fertigstellung (Nachfeststellung) | nein | – | Wirksamkeit der Neubewertung | 06 §8 |
| `growth` | value (Rate) | 1/a | `{ref: market.inflation}` (G: `item_defaults."building.property_tax"`, nur wenn der Block existiert; eigene Annahme D) | nein | – | Fortschreibung (Hebesatzentwicklung) | – |

**Typ `property_tax`** (WS-E, `R/type-flow-property-tax.R`), `grid_invariant = TRUE`. Der Expander erzeugt je Gruppe
`u_<g>_property_tax` mit dem Flächenanteil der Gruppe, **nur** wenn der Block einen Betrag angibt (1.6 Nr. 2, X-16);
der Pflichtparameter `amount_eur_pa` zeigt damit nie auf einen fehlenden Pfad.

| Parameter | Art | Default (T) | Expander-Belegung |
|---|---|---|---|
| `amount_eur_pa` | `amount` | Pflicht | `{expr: "building.property_tax.amount_eur_pa * <Flächenanteil>"}` bzw. Messbetrag × Hebesatz × Anteil; Flächenanteil = `unit_groups.<g>.living_area_m2 / (Σ Gruppenflächen)` als Ausdruck über Domänenpfade |
| `land_amount_eur_pa`, `amount_after_completion_eur_pa` | `amount` | `null` | dito |
| `after_completion_from` | `timing` | `null` | Wert |
| `growth`, `base_date` | `value`, `timing` | 0, Preisstand | ref, Wert |
| `occupancy_from` | `timing` | `valuation_date` | `rent_start` der Gruppe (Neubau: Token `completion`) |
| `owner_occupied` | `logical` | `false` | Wert |
| `rent_component` | `ref` | `null` | `u_<g>_rent` |

**Algorithmus**

```text
a(t)  = land_amount vor occupancy_from (+Shift); amount_eur_pa ab occupancy_from; amount_after_completion ab
        after_completion_from (Monatsanteile über ctx$shift_overlap)
X(t)  = a(t) · I_year(t) · delta_t                                                 # Jahresbetrag der Periode
e(t)  = 1 vor occupancy_from (keine Mieter) bzw. bei owner_occupied; sonst vacant_share(t) der Mietkomponente
cost        = −e · X                                                                (Vermieter- bzw. Eigentümerlast)
tenant_share = +X, nur vermietete Gruppen ab occupancy_from (Vollvermietungsbasis wie die Sollmiete; der
               Leerstandsanteil steht zusätzlich in cost, weil die Merkzeile die Mietersicht je m² abbildet)
```

| lokale Zeile | section | category | tax_category | cash | `is_tax` | VZ |
|---|---|---|---|:---:|---|:---:|
| `cost` | project | `property_tax` | `expense_deductible` (Selbstnutzer `expense_nondeductible`) | T | `grundsteuer` | − |
| `tenant_share` | memo | `tenant_operating_cost` | `not_applicable` | F | – | + |

**Tests** (`test-type-flow-property-tax.R`, WS-E): O-5 vermietet, 6.000 EUR/a, Leerstand 3 %, VPI 2027 2,8 %: `cost` 2027 −185,04; `tenant_share` +6.168,00.
O-6 Selbstnutzer 1.600 EUR/a: `cost` 2027 −1.644,80. O-7 Neubau, Grundstück 900 EUR/a bis Fertigstellung 2029-01-01
(Bauphase 2027–2028, keine Mieter): `cost` 2027 −925,20 (voll kostenwirksam). O-7a (Expander, `test-expand-unit-groups.R`,
WS-E2): Szenario ohne `building.property_tax` → keine Komponente `u_<g>_property_tax`, I (vermietet) bzw. W
(Selbstnutzer); mit `assessment_amount_eur` ohne `municipal_multiplier` → E.

### 2.4 Indizes und Fortschreibung

| Größe | Index | Quelle |
|---|---|---|
| Verwaltung, Grundsteuer, Grundpreise, Wartung | `{ref: market.inflation}` über `index_year` (0.7) | Memo 03 § 8.2 (ImmoWertV-Fortschreibung mit VPI) |
| Betriebskosten je m² (kalte BK, nicht umlagefähige Kosten je m²) | `{ref: market.operating_cost_growth}` (VPI + 0,5 Pp, Teil C K11) | Memo 03 § 5 |
| Instandhaltung | Teil A (`market.maintenance_index`) | Memo 07 § 4.0 |
| Mieten | `rent_path` (eigene Monatslogik) | 1.8 |
| Energie, Netzentgelte, CO₂ | Preis- bzw. Pfadangaben je Kalenderjahr (Abschnitt 3.5) | Memo 03 § 2.4 |

Die II.-BV-Werte gelten vom 01.01.2026 bis 31.12.2028 (`valid_to` des Bibliothekseintrags; nächste Anpassung
01.01.2029, Memo 03 § 8.1). Fällt `legal_state` oder der Horizont darüber hinaus, schreibt `growth` sie fort; die
Bibliothek meldet O bei abgelaufener Gültigkeit. Die ImmoWertV-Modellansätze (`costs/bewirtschaftung_immowertv_2026`)
gelten bis 2027-01-01; ab `legal_state` 2027 meldet die Bibliothek O, bis Teil C den Eintrag 2027 ergänzt.

---

## 3. Energie und CO₂

### 3.1 Überblick: Zustände, Segmente, Kostenträger

Das Energiemodell beschreibt das Gebäude in zeitlich aufeinanderfolgenden **Zuständen** (`before`, `after`, weitere
`stages`). Die Felder eines Zustands sind die von Spec 00 § 4.3.6b: `demand_kwh`, Trägeranteile (`carrier_shares`),
`efficiency` bzw. `jaz` (realisiert) und `jaz_plan` (Plan), Vorlauftemperatur (`flow_temperature_c`),
`consumption_basis`, Einbaudatum der Heizung (`installation_date`). Der Expander zerlegt jeden Zustand in
**Segmente** (Zustand × Energieträger). Je Segment entsteht eine Komponente `energy_cost` und für Träger mit
Emissionsfaktor eine Komponente `co2_cost`. Bedarf, Wirkungsgrad, JAZ und Performance Gap gehen als Ausdrucksknoten
über Domänenpfade in die Segmentmenge ein (Bezug statt Kopie, Spec 00 § 4.12 Nr. 2). Damit hat jeder Typ ein festes
Parameterschema, und Overlay-Ziele wie `energy.after.jaz` wirken direkt. Die Komponenten entstehen je Zustand ×
Träger (`e_<s>_<c>_cost`, `e_<s>_<c>_co2`), weil sich Menge, Einbaudatum (§ 43, § 5a) und Gültigkeitsfenster je
Zustand unterscheiden (S01B-01 angenommen; Spec 00 § 7.10, § 4.12, R-90, N-14). Zustands-ids (`before`, `after`,
`stages.<s>`) haben höchstens 12, Träger-ids höchstens 20 Zeichen (Spec 00 § 4.4 Nr. 2).

```text
energy.before / energy.after / energy.stages.<s>   ──►  Expander energy (order 30)
  demand_kwh, carrier_shares, efficiency, jaz, …         e_<s>_<c>_cost  (energy_cost, je Zustand × Träger)
energy.carriers.<c>, energy.performance_gap              e_<s>_<c>_co2   (co2_cost, Träger mit Emissionsfaktor > 0)
energy.pv                                                e_pv            (pv)
unit_groups (Leerstand, Selbstnutzung)                   e_tenant        (tenant_costs: Merkzeilen energy, energy_pre)
```

Kostenträger je Segment: Den Anteil **o** der Energie trägt der Eigentümer voll (selbstgenutzte Fläche;
Selbstnutzer o = 1). Vom vermieteten Rest (1 − o) trägt der Vermieter den Leerstandsanteil v voll und vom vermieteten,
belegten Teil die Anteile nach CO2KostAufG (Stufenmodell bzw. § 5a); den Rest tragen die Mieter (Konzept § 3.1,
Tabelle „Welche Zahlungsreihen gelten für welche Perspektive“).

### 3.2 Block `energy` (Feldkatalog)

#### 3.2.1 Energieträger `energy.carriers.<c>`

Spec 00 § 4.3.6b nennt `price_eur_kwh`, `base_fee_eur_pa`, `emission_factor_kg_kwh`, `vat_rate`; die übrigen Felder
konkretisieren den Block. Kanonische Träger-ids (Spec 00 § 4.3.11, R-103, N-15; alle zehn bleiben): `gas`, `gas_mfh`,
`oil`, `lpg`, `power`, `power_mfh`, `heatpump_power`, `heatpump_power_mfh`, `district_heating`, `pellets`. Für jeden
kanonischen Träger liefern `global.yaml` (Teil A) und `prices/energy_prices_2026` (Teil C) einen Marktpreis
`market.energy_price.<c>`; für `gas` und `gas_mfh` zusätzlich `market.energy_network_fee.<c>` mit `growth: {ref:
shared.network_fee_growth_<c>}` (`shared.network_fee_growth_gas`, `_gas_mfh` = 0,03 in `global.yaml`). Andere
Träger-ids sind zulässig (≤ 20 Zeichen); sie brauchen `class` und einen eigenen Preis (Bezug auf einen vorhandenen
Marktnamen oder Wert). Trägerfelder ohne Angabe kommen aus `rule:carrier_defaults` (AR, 5.5) und
`item_defaults."energy.carriers"` (G, 7.1).

| YAML-Pfad (`energy.carriers.<c>.`) | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `class` | enum:carrier_class | – | (AR) `rule:carrier_defaults` aus der kanonischen id: `gas`, `gas_mfh` → `gas`, `oil` → `oil`, `lpg` → `lpg`, `power`, `power_mfh` → `power`, `heatpump_power`, `heatpump_power_mfh` → `power_hp`, `district_heating` → `district_heating`, `pellets` → `biomass`; sonst Pflicht | bedingt | E fehlt bei nicht kanonischer id; E unbekannt | `gas`, `oil`, `lpg`, `coal`, `power`, `power_hp`, `district_heating`, `biomass`, `other`; steuert § 43 GModG und § 5a CO2KostAufG (nur `gas`, `oil`, `lpg`), § 5a-Netzentgelt (nur `gas`), den JAZ-Bezug (`power_hp`) und das Symbol `heating.replaced_fossil_functional` (4.3.2) | 02 §3.3 |
| `price_eur_kwh` | value (Pfad) | EUR/kWh | `{ref: "market.energy_price.{id}"}` (G, `item_defaults."energy.carriers"`, Platzhalter `{id}` = Träger-id) | ja | E Bezug auf fehlenden Marktnamen (nicht kanonische id ohne eigenen Preis); W Gas > 0,30 | Arbeitspreis **netto ohne Netzentgelt und ohne CO₂-Kosten** (Beschaffung, Vertrieb, Energiesteuer, Konzessionsabgabe, Marge) als Niveau je Kalenderjahr (Teil C, Kopplung K4) | Konzept 3.8 |
| `price_includes` | enum `commodity`, `all` | – | `commodity` (T) | nein | – | `all`: `price_eur_kwh` ist der **Gesamtarbeitspreis** inkl. Netzentgelt und CO₂-Kosten im ersten Rasterjahr (12-Monats-Mittel, B8); der Typ zieht Netzentgelt und CO₂-Kosten dieses Jahres ab und schreibt den Rest fort (3.6.2) | Konzept B8 |
| `price_basis` | enum `net`, `gross` | – | `net` (T) | nein | – | `gross`: alle Preis- und Gebührenangaben des Trägers enthalten USt; der Typ rechnet sie mit `vat_rate` auf netto um | – |
| `price_growth` | value (Rate, Pfad) | 1/a | 0 (T) | nein | I ≠ 0 und `price_eur_kwh` ist Prozessziel bzw. Wachstumsknoten („doppelte Fortschreibung?“) | zusätzliche Fortschreibung über `index_year` (0.7); 0, wenn `price_eur_kwh` bereits ein Pfad je Jahr ist | – |
| `price_base_date` | timing | – | Preisstand (A) | nein | – | Bezug von `price_growth`, `network_fee_growth`, `fee_growth` | – |
| `network_fee_eur_kwh` | value (Pfad) | EUR/kWh | (AR) `rule:carrier_defaults`: `{ref: market.energy_network_fee.<c>}`, falls der Marktname nach Schicht 8 existiert, sonst 0 | nein | W Klasse `gas` ohne Netzentgelt („§ 5a-Anteil 0“) | Netzentgelt netto (Gas: je kWh H_s) | 07 §4.0 |
| `network_fee_growth` | value (Rate) | 1/a | 0 (T) | nein | I ≠ 0 und der Marktknoten hat ein eigenes Wachstum | zusätzliche Fortschreibung des Netzentgelts (der Bibliotheksknoten trägt das Wachstum 3 % bereits, Teil C § 3.6) | 07 §4.0 |
| `base_fee_eur_pa` | value | EUR/a | 0 (T; Orientierung Teil C `prices/energy_prices_2026.base_fees_eur_pa`) | nein | – | Grundpreis netto je Anschluss | 07 §4.0 |
| `fee_growth` | value (Rate) | 1/a | `{ref: market.inflation}` (G) | nein | – | Fortschreibung von Grundpreis und Wartung | – |
| `vat_rate` | share | – | 0,19 (G) für alle Träger, auch Holzpellets (19 % seit 01.01.2024, Memo 03 § 2.1; F-16) | nein | I 0,07 bei Klasse `biomass` („ermäßigter Satz nur für Brennholz/Scheitholz; Pellets 19 %“) | USt auf alle Bestandteile | 03 §2 |
| `emission_factor_kg_kwh` | num | kg CO₂/kWh (Abrechnungseinheit) | (AR) `rule:carrier_defaults` aus `bctx$legal("emission_factors_co2cost")` (Wert, Herkunft = Bibliotheks-id): `gas` → `natural_gas_hs` (0,1814), `oil` → `heating_oil_hi` (0,2664), `lpg` → `lpg_hi` (0,2358), `biomass` → `wood` (0); `coal`: kein Bibliothekswert (W „CO₂-Faktor für Kohle angeben, CO₂-Kosten 0 angesetzt“); sonst 0 | nein | W Klasse `gas` mit 0,200–0,205 („H_i statt H_s?“) | BEHG-/EBeV-Faktor für die **CO₂-Kosten**; biogene Anteile 0 | 03 §3.6; 02 §3.3 |
| `ghg_factor_kg_kwh` | value (Pfad) | kg CO₂-Äq./kWh (Abrechnungseinheit) | (AR) `rule:carrier_defaults` aus `bctx$legal("emission_factors_geg")` / 1000: `gas` → `natural_gas` × `conversion.gas_hs_to_hi` aus `emission_factors_co2cost` (0,240 × 0,903 = 0,21672), `oil` → `heating_oil` (0,310), `lpg` → `lpg` (0,270), `coal` → `hard_coal` (0,400), `power`, `power_hp` → `electricity_grid` (0,560), `district_heating` → `district_heating_chp.gas_oil` (0,180), `biomass` → `wood` (0,020), sonst 0 | nein | O über `as_of` des Eintrags (Fortgeltung mit `valid_to: null`, Neufassung ab 2027 ungeprüft; Spec 00 § 4.10, R-88, N-28); I Strom konstant („abnehmender Strommix als Pfad empfohlen“) | **Treibhausgasbilanz** für die Kennzahlen `co2_emissions`, `co2_reduction`, `co2_abatement_cost` (Spec 00 § 12.3, § 12.6, R-101); keine Kostenwirkung | Konzept 1.4; 02 §3.3 |
| `co2_price_eur_t` | value (Pfad) | EUR/t (netto) | `{ref: market.co2_price}` (G) | bedingt (`emission_factor_kg_kwh` > 0) | E fehlt | CO₂-Preis je Kalenderjahr | 03 §3.4 |
| `bio_premium_eur_kwh` | value (Pfad) | EUR/kWh (netto) | `{ref: market.bio_fuel_premium}` (G) | bedingt (§ 43-Zustand) | W fehlt | Mehrkosten des biogenen Anteils gegenüber fossil | 07 §4.0 |
| `label` | chr | – | Code | nein | – | Anzeige | – |

#### 3.2.2 Zustände `energy.before`, `energy.after`, `energy.stages.<s>`

| YAML-Pfad (`energy.<zustand>.`) | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `start_event` | timing | – | `before`: `valuation_date` (fest); `after` und `stages`: Fertigstellung von `measure`, ohne `measure` Token `completion` | `stages`: ja, wenn `measure` fehlt | E `before.start_event` ≠ Stichtag; E Zustände nicht streng zeitlich geordnet; E `validation.library.ref_not_id` bei einem Schlüssel `from` (Spec 00 § 4.9, R-110) | Beginn des Zustands; ein Zustand gilt bis zum Beginn des nächsten **aktiven** Zustands (3.4) | Konzept 3.8 |
| `measure` | chr (Maßnahmen-id) | – | `null` | nein | E unbekannt; E dieselbe Maßnahme in zwei Zuständen | Zustand beginnt mit Fertigstellung der Maßnahme; Verschiebung `measures.<k>.delay_months`; Aktivierungsfaktor a_k (0.8) | Spec 00 3.9, 4.12 Nr. 7 |
| `consumption_basis` | enum `measured`, `demand` | – | `before`: `measured`, wenn `consumption_kwh` (bzw. `building.consumption_kwh`) gesetzt ist, sonst `demand`; übrige: `demand` | nein | E `measured` außerhalb `before`; W `before` mit `demand` („Verbrauchsdaten dringend empfohlen“, B7) | Basis der Energiemenge | Konzept 3.8, B7 |
| `consumption_kwh` | map Träger → value | kWh/a (Abrechnungseinheit) | (A) `building.consumption_kwh` (Spec 00 § 4.3.4, Erdgas H_s) | bedingt (`measured`) | E Träger nicht in `carrier_shares`; E fehlt | gemessener Endenergieverbrauch für Heizung und Warmwasser (3-Jahres-Mittel, witterungsbereinigt) | 03 §7.1 |
| `demand_kwh` | value | kWh/a (Nutzwärme Heizung + TWW) | geerbt (3.2.3) | bedingt (`demand`; Folgezustände) | E fehlt; Mengenform `{value, per: m2_living_area}` zulässig | rechnerischer Wärmebedarf (Nutzwärme) | 03 §7.1 |
| `carrier_shares` | map Träger → value (share) | – | (A) `{<heating_carrier>: 1}`; geerbt | ja (`before` bei Bestand, erster Zustand bei Neubau) | E Σ ≠ 1 (Toleranz 1e-9); E Träger unbekannt | Anteile der Träger an der Nutzwärme (Hybrid z. B. `{heatpump_power: 0.8, gas: 0.2}`) | – |
| `heating_carrier` | chr (Träger-id) | – | `null` | nein | E zusammen mit `carrier_shares` | Kurzform für genau einen Wärmeträger | – |
| `efficiency` | value | kWh Nutzwärme / kWh Endenergie | 1 bei Klassen `district_heating`, `power` (T); geerbt | bedingt (Wärmeträger außer dem WP-Träger, ohne Eintrag in `efficiency_by_carrier`) | E fehlt; W > 1,1 bei Klasse `gas`/`oil` | Nutzungsgrad (Erdgas bezogen auf H_s) | 07 S4 |
| `efficiency_by_carrier` | map Träger → value | – | `{}` | nein | E Träger nicht in `carrier_shares` | abweichende Nutzungsgrade je Träger (Hybrid) | – |
| `jaz` | value | – | geerbt | bedingt (`heat_pump_carrier` gesetzt) | E fehlt; W < 2 oder > 5 | **realisierte JAZ** (stochastisch zulässig); bestimmt Strombedarf und Warmmiete | Spec 00 4.3.6b; Konzept 3.8 |
| `jaz_plan` | num (**det.**) | – | `null` = `ctx$value_base("energy.<zustand>.jaz")` (Spec 00 R-70) | nein | E Overlay- oder Designziel; I `null` bei Wärmepumpe mit Umlage („Plan-JAZ = Basisfall-JAZ angenommen“) | **Plan-JAZ** des Nachweises nach VDI 4650; steuert ausschließlich § 559f (1.9.1) | Spec 00 4.3.6b; Konzept 3.5 |
| `heat_pump_carrier` | chr (Träger-id) | – | (A) einziger Träger der Klasse `power_hp` in `carrier_shares`; sonst `null` | nein | E mehrere `power_hp`-Träger ohne Angabe; E Träger nicht in `carrier_shares` | Träger, auf den `jaz` wirkt (Wärmepumpe); bei Klasse `power` nur ausdrücklich | – |
| `flow_temperature_c` | num (det.) | °C | `null`; geerbt | nein | W > 75 bei Wärmepumpe | Vorlauftemperatur (Ausnahme § 559f bei ≤ 55 °C) | 07 §1.2 |
| `installation_date` | date | – | `before`: 1. Januar von `building.heating_existing.installation_year`; Zustand, der `carrier_shares` bzw. `heating_carrier` selbst setzt (neue Heizung): Fertigstellung von `measure` ohne Verschiebung (ohne `measure`: `start_event`); sonst geerbt | bedingt (fossiler Träger in `after`/`stages`) | E fehlt bei fossilem Träger | Einbaudatum der Heizung (§ 43 GModG, § 5a CO2KostAufG, Bio-Treppe, Alterung) | Konzept 3.8 |
| `section43` | lgl | – | (A) Regel `co2_section43` (3.7.4) | nein | W abweichend von der Ableitung | neue Gas-/Öl-/Flüssiggasheizung nach § 43 GModG (Bio-Treppe, § 5a, keine 15-%-Pauschale § 559e); `false` bei Erfüllungsoption (Hybrid, Solarthermie) | 02 §3.2, §4.1 |
| `emergency_replacement` | lgl | – | `false` (T) | nein | I `true` bei Einbau nach 2027-12-31 (wirkungslos) | Einbau wegen irreparablen Ausfalls höchstens 12 Monate vor dem 01.01.2028: § 5a erst nach 12 Monaten (Teil C `s5a.transition`, Qualität C) | 02 §3.2 |
| `service_eur_pa` | value | EUR/a (netto bzw. `price_basis` des ersten Wärmeträgers) | 0 (T); geerbt | nein | W `validation.maintenance.service_double_energy`, wenn > 0 und für `measure` dieses Zustands eine Komponente `m_<measure>_maint` (Teil A, `effects.maintenance.share_of_cost_pa`) existiert („Wartung doppelt? Instandhaltungssatz der Maßnahme umfasst nur die Instandsetzung“, X-10) | **Wartung** der Wärmeerzeugung, Schornsteinfeger (umlagefähig); Zuordnung zum Segment des größten Wärmeanteils. Abgrenzung (X-10): Die Wartung gehört hierher (bzw. zu `energy.pv.opex_*`), die Instandsetzung zum Instandhaltungssatz der Maßnahme in Teil A (`effects.maintenance.share_of_cost_pa`, nur Instandsetzung) | 07 S4 |
| `efficiency_degradation_pa` | value (Rate) | 1/a | 0 (T; Bibliothek 0,003 für Wärmepumpen, Memo 03 § 7.2); geerbt | nein | – | jährliche Verschlechterung von `efficiency` bzw. `jaz` ab `installation_date`; nicht bei gemessenem Verbrauch | 03 §7.2 |
| `extra_consumption` | map x → {`carrier` chr, `kwh_pa` value, `label` chr} | – | geerbt | nein | E Träger unbekannt | weiterer Verbrauch (Lüftung, Hilfsstrom, Haushaltsstrom des Selbstnutzers); Segment des Trägers | 07 S5 |
| `label` | chr | – | id | nein | – | Anzeige | – |

`stages`-ids sind Nutzer-ids (Spec 00 § 4.4 Nr. 2) und dürfen nicht `before` oder `after` heißen; höchstens 12 Zeichen,
Träger-ids höchstens 20 Zeichen (Segment-ids `e_<s>_<c>_cost` ≤ 40 Zeichen; N-14, N-23).

#### 3.2.3 Vererbung

Fehlt in einem Zustand eines der Felder `demand_kwh`, `carrier_shares`/`heating_carrier`, `efficiency`,
`efficiency_by_carrier`, `jaz`, `jaz_plan`, `heat_pump_carrier`, `flow_temperature_c`, `installation_date` (nur ohne
neue Heizung, 3.2.2), `section43`, `service_eur_pa`, `efficiency_degradation_pa`, `extra_consumption`, gilt der Wert des
zeitlich vorangehenden Zustands. Der Expander erzeugt dafür **Bezüge auf den Pfad des definierenden Zustands** (z. B.
`{ref: energy.before.efficiency}`), keine Kopien. `start_event`, `measure`, `consumption_basis`, `consumption_kwh` und
`emergency_replacement` werden nicht vererbt.

#### 3.2.4 Performance Gap `energy.performance_gap` und weitere Felder

| YAML-Pfad | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `energy.performance_gap.prebound_factor` | value | – | 0,7 (G, `item_defaults."energy.performance_gap"`; Konzept 3.8 „Prebound-Default“, Bibliothek PERT 0,5/0,7/1,0) | nein | W ausdrücklich gesetzt (Herkunft ≠ `global`) oder Overlay-Ziel bei `before.consumption_basis = measured` („entfällt“, Teil C `prebound_with_measured`) | Verbrauch/Bedarf **vor** der Maßnahme, nur bei `before.consumption_basis = demand` (B7) | 04 §1.2; B7 |
| `energy.performance_gap.rebound_factor` | value | – | 1,0 (G; Bibliothek: Vorlage `rebound` PERT 0,82/1,0/1,27 mit Modus 1,0; `rebound_calculated` PERT 0,9/1,1/1,4 nur zur Basis 1,1, Teil C § 2.7) | nein | W < 0,8 oder > 1,6; W `validation.energy.rebound_base_differs`, wenn ein Overlay-Eintrag auf diesen Pfad einen Modus ≠ Basiswert hat („Basisfall 1,0, MC-Modus 1,1: Ist der Rebound im Bedarf schon enthalten? Sonst `rebound_factor: 1.1` setzen“, F-15) | Verbrauch/Bedarf **nach** der Maßnahme, auf `demand_kwh` jedes Folgezustands (B7). **Konvention (F-15):** `demand_kwh` eines Folgezustands ist die erwartete Nutzwärme **einschließlich** Nutzerverhalten nach der Maßnahme (wie in S1–S5); deshalb ist der Default 1. Ist `demand_kwh` ein reiner Rechenbedarf (GEG-Nachweis, Bedarfsausweis), setzt der Nutzer `rebound_factor` auf den Bibliotheksmodus 1,1 | 04 §1.2; B7 |
| `energy.performance_gap.realisation_factor` | value | – | 1 (Spec 00) | nein | W < 0,3 oder > 1,2; I ≠ 1 zusammen mit `rebound_factor` ≠ 1 („doppelte Abschläge?“) | einfacher Realisierungsfaktor auf die rechnerische Einsparung (D8) | 04 §1.2 |
| `energy.co2_landlord_share_reduction` | value (share) | – | 0 (G, `item_defaults."energy"`) | nein | W 0 bei `building.denkmal` oder `project.municipality.milieuschutz` („§ 9 prüfen, Faktor 0,5“) | Kürzung des Vermieteranteils nach § 9 CO2KostAufG (Teil C `s9.reduction_factor` 0,5, Qualität C) | 02 §3.1 |
| `energy.co2_hardship_5d` | lgl | – | `false` (G) | nein | W `true` (Voraussetzungen nur über Sekundärquelle belegt, Teil C `s5d`) | Härtefall § 5d (Kleinvermieter): Stufenmodell statt § 5a | 02 §3.2 |
| `energy.co2_newbuild_5b` | lgl | – | `false` (G) | nein | W `false`, obwohl `project_type` ∈ {`neubau`, `erwerb_neubau`}, fossiler Träger, Bauantrag ab 2026-05-13 und Fertigstellung bis 2029-12-31 („§ 5b prüfen“) | § 5a auch für Neubauten nach § 5b (Qualität C, deshalb nur ausdrücklich) | 02 §3.2 |
| `energy.pv` | map | – | `null` (Felddefaults aus `item_defaults."energy.pv"` nur, wenn der Block existiert) | nein | – | PV-Anlage (3.9) | – |

Die 2045-Stufe der Bio-Treppe („100 % klimaneutraler Brennstoff ab 2045“, Konzept F5, A7) ist **kein Feld**, sondern
der Reformcode `stufe_2045` in `project.pending_reforms` (Spec 00 § 4.10, R-82); er aktiviert den Bibliothekseintrag
`legal/gmodg_bio_treppe_2045` (Teil C). Ein Feld `energy.climate_neutral_2045` ist ein Validierungsfehler mit Hinweis
auf den Reformcode.

#### 3.2.5 Startpreis und 12-Monats-Mittel (B8)

Default ist das **12-Monats-Mittel** statt des Spotpreises (Konzept § 3.8, B8). Die Bibliothek (Teil C,
`prices/energy_prices_2026`) liefert je Träger den Nettoarbeitspreis ohne CO₂ und ohne getrennt geführtes Netzentgelt
(`price_includes: commodity`); wer einen Gesamtpreis aus der Abrechnung eingibt, setzt `price_includes: all`. In der
Simulation läuft der Arbeitspreis per Mean-Reversion zum Normalniveau (`mr_trend` mit `p_norm`, Teil C § 2.4, Spec 00
§ 11.7, R-95); CO₂-Preis und Netzentgelt sind eigene Pfade (Kopplung K4). Wie der **deterministische** Pfad
`market.energy_price.<c>` gebildet wird (Trend vom Startpreis oder Erwartungswert des `mr_trend` mit Rückkehr zum
Normalpreis, Befund F-08), legt Teil C mit der Bibliothek fest (Spec 00 § 17.3 Nr. 8 c); die Typen dieses Teils lesen
den Pfad unverändert als Kalenderjahreswert (0.7).

#### 3.2.6 Energie- und Förderattribute im Block `building`

Spec 00 § 4.3.4 nennt die Felder; Teil A verweist für ihre Bedeutung auf Teil B.

| YAML-Pfad (`building.`) | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `energy_class_before`, `energy_class_after` | enum:energy_class (`A+`, `A`, `B`, `C`, `D`, `E`, `F`, `G`, `H`) | – | `null` | nein | – | Effizienzklasse des Energieausweises vor bzw. nach der Maßnahme (Förderbedingungen, § 5d CO2KostAufG, WPB) | 02 §5 |
| `efficiency_standard_after` | enum:efficiency_standard (`eh40`, `eh55`, `eh70`, `eh85`, `eh_denkmal`, `none`) | – | `none` (G, `item_defaults."building"`) | nein | W „nicht berechtigt (Effizienzhausstandard nicht angegeben)“, wenn ein Instrument `conditions.efficiency_standard` verlangt und der Wert `none` aus dem Default stammt (X-03); Varianten setzen das Feld mit `set`, deshalb trägt die Basis den Pfad ausdrücklich (`none`, Spec 00 § 4.11), weil `item_defaults` erst nach Schicht 7 wirkt | erreichter Effizienzhausstandard (KfW 261, 297/298) | 02 §5.3 |
| `wpb_flag` | lgl | – | `false` (G, `item_defaults."building"`) | nein | I `energy_class_before = H` und `false` | Worst Performing Building (Teil C `eligibility.conditions.wpb_definition`) | 02 §5.3 |
| `denkmal` | lgl | – | `false` (G, `item_defaults."building"`) | nein | – | Baudenkmal bzw. besonders erhaltenswerte Bausubstanz (§ 9 CO2KostAufG, KfW Denkmal) | 02 §3.1 |
| `serial_renovation` | lgl | – | `false` (G, `item_defaults."building"`) | nein | – | serielle Sanierung (Default von `funding.<f>.facts.serial_renovation`) | 02 §5.3 |
| `isfp_available` | lgl | – | `false` (G, `item_defaults."building"`) | nein | – | individueller Sanierungsfahrplan liegt vor (Default von `funding.<f>.facts.isfp`) | 02 §5.4 |
| `heating_existing` | map {`carrier` chr, `installation_year` int, `type` enum:heating_system_type, `label` chr} | – | `null` | bedingt (Bestand) | E Träger unbekannt | Bestandsheizung: Default von `energy.before.heating_carrier` und `energy.before.installation_date`; `type` ∈ `central` (Default), `floor` (Etagenheizung), `single_room` (Einzelöfen) für das Fördersymbol `heating.replaced_fossil_functional` (4.3.2, F-18) | 07 S1, S4; 07 §1 |
| `consumption_kwh` | map Träger → num | kWh/a (Erdgas H_s) | `null` | nein | W Erdgas < 50 kWh/m²·a („H_i?“) | gemessener Verbrauch (Default von `energy.before.consumption_kwh`) | 03 §7.1 |

### 3.3 Bedarfs- und Verbrauchsmodell

```text
r  = performance_gap.realisation_factor;  fpre = prebound_factor (nur before mit demand);  fpost = rebound_factor
eff_{s,c}(Y) = e_{s,c} · (1 + d_s)^-(Y − Jahr(installation_date_s))^+      Alterung je Kalenderjahr Y (nicht bei measured)
   e_{s,c}  = jaz_s                                        für c = heat_pump_carrier_s
            = efficiency_by_carrier_s[c] %||% efficiency_s  sonst
Nutzwärme:
   Q_b  = Σ_c consumption_kwh_b[c] · e_{b,c}                (before, measured)
        = demand_kwh_b · fpre                               (before, demand)
   für jeden Folgezustand s:  Qc_s = demand_kwh_s · fpost
                              Q_s  = Q_b − r · (Q_b − Qc_s),  falls ein before existiert;  sonst Q_s = Qc_s  (Neubau)
Endenergie je Segment (s, c):
   F_{b,c} = consumption_kwh_b[c]                           (before, measured; keine Alterung)
   F_{s,c} = Q_s · share_{s,c} / eff_{s,c}(Y)               (sonst)
   X_{s,c} = Σ_{x ∈ extra_consumption_s : carrier = c} kwh_pa_x
```

Die Einsparung wird gegen den **realisierten** Ausgangsverbrauch gerechnet (Memo 04 § 1.2: ΔQ = Q_pre − Q_post,
Realisierungsgrad auf die rechnerische Einsparung). Bei gemessenem Ausgangsverbrauch entfällt f_pre (B7). Sind für
den `before`-Zustand bei `measured` Folgezustände vorhanden, ist `efficiency` (bzw. `e_{b,c}`) Pflicht, weil die
Nutzwärme Q_b daraus folgt.

### 3.4 Gültigkeitsfenster und Aktivierung (`en_state_weights`)

Der interne Helfer `en_state_weights(ctx, state)` (WS-E, `R/type-flow-energy-cost.R`, Domänenlesezugriff 0.5)
liefert je Lauf und Monat das Gewicht w_s(i, m) ∈ {0, 1} eines Zustands:

```text
Zustände in zeitlicher Ordnung s_0, s_1, …, s_J  (s_0 = before bzw. bei Neubau der erste Zustand)
start_j(i) = mi(start_event_j) + sh_j(i);  sh_j = round(measures.<measure_j>.delay_months) bzw. beim Token completion
             round(Parameter construction_delay_months der Komponente) (= {ref: project.construction_delay_months},
             3.6.1; Spec 00 § 3.9); round = floor(x + 0,5)
a_j(i)     = act(measure_j) (Aktivierungsfaktor 0.8); 1 ohne Maßnahme
A_j(i, m)  = a_j(i) · 1{m >= start_j(i)};  für before: A_0 = 1 für alle m >= 1
w_j(i, m)  = A_j(i, m) · Π_{l > j} (1 − A_l(i, m))
Jahresanteil je Periode:  ω_j[, t] = Σ_{m ∈ t} w_j(·, m) / 12            (n x (T+1), Spalte 1 = 0)
```

Damit gilt bei a_k = 0 der vorangehende Zustand weiter („als fehlte die Maßnahme“, Spec 00 § 4.12 Nr. 7). Bei
Neubau gibt es vor dem ersten Zustand keine Energiekosten (Bauphase). ω ersetzt das Produkt Δ_t · Überlappung; die
Jahressumme ist rasterunabhängig (F10).

### 3.5 Expander `energy` (WS-E2, `R/expand-energy.R`, order 30)

1. **Zustandsfolge.** Zustände nach `start_event` ordnen (`before` zuerst; Gleichstand = E). Vererbung nach 3.2.3 als Bezüge.
2. **Segmente.** Je Zustand s und Träger c ∈ `carrier_shares_s` ∪ {Träger von `extra_consumption_s`} eine Komponente
   `e_<s>_<c>_cost` (Typ `energy_cost`); für Träger mit `emission_factor_kg_kwh > 0` zusätzlich `e_<s>_<c>_co2` (Typ
   `co2_cost`). ids > 40 Zeichen sind E mit Vorschlag kürzerer Zustands- bzw. Träger-ids.
3. **Menge.** `quantity_kwh_pa` = Ausdrucksknoten nach 3.3 (ohne Alterung) über Domänenpfade, `extra_kwh_pa` =
   Summe der Zusatzverbräuche des Trägers. Beispiel S4 V1 Stufe 2 (Ausgangsverbrauch gemessen, Wärmepumpe):
   `{expr: "(energy.before.consumption_kwh.gas * energy.before.efficiency - energy.performance_gap.realisation_factor * (energy.before.consumption_kwh.gas * energy.before.efficiency - energy.s2.demand_kwh * energy.performance_gap.rebound_factor)) * energy.s2.carrier_shares.heatpump_power / energy.s2.jaz"}`.
   Für `before` mit `measured`: `{ref: energy.before.consumption_kwh.<c>}`.
4. **Preise und Flags.** `price_eur_kwh`, `network_fee_eur_kwh`, `base_fee_eur_pa`, `co2_price_eur_t`,
   `bio_premium_eur_kwh`, `ghg_factor_kg_kwh` als Bezüge auf `energy.carriers.<c>.*`; `class`, `price_includes`,
   `price_basis`, `installation_date`, `section43`, `emergency_replacement` als Werte. Der Grundpreis eines Trägers
   gehört zum Segment (s, c); `service_eur_pa` zum Segment mit dem größten Anteil in `carrier_shares_s` (Gleichstand:
   erste Träger-id nach `sort(method = "radix")`).
5. **Kostenträger.** `owner_share` = `{expr: "<Σ Flächen selbstgenutzter Gruppen> / <Σ Gruppenflächen>"}`; ohne
   Gruppen 1 bei `selbstnutzer`, sonst 0. `unit_groups` = ids der vermieteten Gruppen (Leerstandshelfer 3.6.2);
   `vacancy_landlord` = `false`, wenn eine vermietete Gruppe `operating.vacancy_opex_scope = warm` hat.
6. **Aktivierung und Fenster.** `state` = s; Fenster und Aktivierung bestimmt der Typ über `en_state_weights` (3.4).
   Der Expander schreibt keine aus Verschiebungen oder Aktivierungen abgeleiteten Konstanten.
7. **Vorzustand.** Segmente von `before` erhalten `counterfactual_pre: true` (Grundlage der Merkzeile
   `tenant_energy_cost_pre`, 3.8).
8. **Querbezüge.** `co2_cost` erhält `energy_component` (eigenes Segment) und `all_energy_components` (alle Segmente
   mit Emissionsfaktor > 0, auch in `after`); für `before`-Segmente zusätzlich `pre_energy_components` (alle
   `before`-Segmente mit Emissionsfaktor > 0). `e_tenant` (Typ `tenant_costs`) entsteht, wenn es vermietete Gruppen
   gibt oder `analysis.tenant_view = true`; `e_pv` (Typ `pv`), wenn `energy.pv` gesetzt ist.
9. **Regeln** (deterministisch, Spec 00 § 4.12 Nr. 5): `bctx$rule("co2_section43")` mit
   `bctx$rule("co2_params")(bctx$legal("co2kostaufg"), bctx$legal("bio_treppe"))` für die Ableitung von `section43`
   (Wert der Art `logical` in der Komponente; das Domänenblatt bleibt unberührt, 0.3 (A)). Die Default-Faktoren der
   Träger (`emission_factor_kg_kwh`, `ghg_factor_kg_kwh`), die Trägerklasse und das Netzentgelt setzt **nicht** der
   Expander, sondern vorher `rule:carrier_defaults` (5.5) als Domänenblätter (Spec 00 § 4.12 Nr. 1, R-86); der
   Expander liest sie wie jedes andere Trägerfeld.
10. **Zeitparameter.** Jede Komponente `energy_cost` erhält `construction_delay_months: {ref:
   project.construction_delay_months}` (3.4; Domänenlesezugriff ohne Block `project`, 0.5 Nr. 3).
11. **id-Prüfung.** Erzeugte ids > 40 Zeichen sind E mit den Höchstlängen Zustand 12 und Träger 20 (Spec 00 § 4.4
   Nr. 2, R-90).

### 3.6 Typ `energy_cost` (WS-E, `R/type-flow-energy-cost.R`)

Art `flow`, `grid_invariant = TRUE` (Mengen mit Monatsgewichten, Preise je Kalenderjahr).

#### 3.6.1 Parameter

| Parameter | Art | Default (T) | Bedeutung |
|---|---|---|---|
| `state` | `string` | Pflicht | Zustands-id (Fenster und Aktivierung, 3.4) |
| `carrier`, `carrier_class` | `string`, `enum` | Pflicht | Träger und Klasse |
| `quantity_kwh_pa` | `value` (path) | 0 | Endenergie für Heizung und Warmwasser je Jahr (Abrechnungseinheit), ohne Alterung |
| `extra_kwh_pa` | `value` (path) | 0 | Zusatzverbrauch des Trägers (ohne Alterung) |
| `efficiency_degradation_pa` | `rate` | 0 | Alterung (3.3); 0 für gemessene Verbräuche |
| `installation_date` | `date` | `valuation_date` | Einbau (Alterung, Bio-Treppe, § 5a) |
| `price_eur_kwh` | `value` (path) | Pflicht | 3.2.1 |
| `price_includes`, `price_basis` | `enum` | `commodity`, `net` | 3.2.1 |
| `price_growth`, `network_fee_growth`, `fee_growth` | `value` (path) | 0, 0, 0 | Fortschreibung |
| `price_base_date` | `timing` | Preisstand | Bezug der Fortschreibung |
| `network_fee_eur_kwh`, `bio_premium_eur_kwh` | `value` (path) | 0, 0 | |
| `base_fee_eur_pa`, `service_eur_pa` | `amount` | 0, 0 | Grundpreis, Wartung |
| `vat_rate` | `share` | 0,19 | |
| `emission_factor_kg_kwh` | `number` | 0 | CO₂-Kosten |
| `ghg_factor_kg_kwh` | `value` (path) | 0 | Treibhausgasbilanz |
| `co2_price_eur_t` | `value` (path) | 0 | |
| `section43` | `logical` | `false` | Bio-Treppe |
| `owner_share` | `share` | 0 | o |
| `unit_groups` | `ids` | `[]` | vermietete Gruppen (Leerstandshelfer) |
| `vacancy_landlord` | `logical` | `true` | Leerstandsanteil trägt der Vermieter |
| `counterfactual_pre` | `logical` | `false` | zusätzlich kontrafaktischen Vorzustand rechnen (3.6.3) |
| `construction_delay_months` | `number` | 0 | Bauzeitverzug für Zustände und Gruppen mit Token `completion` (3.4, `rp_vacancy_share()`); Expander: `{ref: project.construction_delay_months}` |

`example` (Vertragstest): `{type: energy_cost, state: before, carrier: gas, carrier_class: gas, quantity_kwh_pa:
24500, price_eur_kwh: 0.0634, network_fee_eur_kwh: 0.0257, emission_factor_kg_kwh: 0.181, ghg_factor_kg_kwh:
0.21672, co2_price_eur_t: 65, owner_share: 1}` (ohne Domänenblock `energy` gilt w = 1 ab dem Stichtag).

#### 3.6.2 Algorithmus

```text
ω    <- en_state_weights(ctx, state)  (3.4)                                     # n x (T+1)
age  <- pmax(year[j] − Jahr(installation_date), 0);  deg <- by_period((1 + efficiency_degradation_pa)^age)
Q    <- (quantity_kwh_pa · deg + extra_kwh_pa) · ω                              # kWh je Periode
vf   <- price_basis == "gross" ? 1/(1 + vat_rate) : 1                          # auf netto
nf   <- network_fee_eur_kwh · vf · index_year(network_fee_growth, price_base_date)
β    <- section43 ? ctx$rule("bio_share_section43")(by_period(year), PC) : 0     # PC = co2_params(…), 3.7.4
co2u <- emission_factor_kg_kwh / 1000 · co2_price_eur_t · (1 − β)              # EUR/kWh netto
c    <- price_eur_kwh · vf · index_year(price_growth, price_base_date)
        bei price_includes = "all":  c <- (price_eur_kwh · vf − nf[, 2] − co2u[, 2]) · index_year(price_growth, …)
                                     (Abzug der Werte des ersten Rasterjahres, Spalte j = 2, je Lauf)
bio  <- β · bio_premium_eur_kwh
W    <- Q · (c + nf + bio) · (1 + vat_rate)                                    # Arbeitspreis brutto ohne CO2
NFg  <- Q · nf · (1 + vat_rate);   BIOg <- Q · bio · (1 + vat_rate);   CO2g <- Q · co2u · (1 + vat_rate)
BF   <- base_fee_eur_pa · vf · (1 + vat_rate) · index_year(fee_growth, price_base_date) · ω
SV   <- service_eur_pa  · vf · (1 + vat_rate) · index_year(fee_growth, price_base_date) · ω
v    <- rp_vacancy_share(ctx, unit_groups, ctx$param(spec, "construction_delay_months"))   (1.8.4; 0 ohne Gruppen)
f    <- owner_share + (1 − owner_share) · v · vacancy_landlord                  # Eigentümer- bzw. Vermieterlast (ohne CO2)
work = −f · W;  base_fee = −f · BF;  service = −f · SV
quantity (memo) = +Q;   emission (memo) = +Q · ghg_factor_kg_kwh / 1000          # t CO2-Äq.
```

Preis-, Netzentgelt-, CO₂-Preis- und Bio-Pfade gehen mit ihrem **Kalenderjahreswert** ein (Spalte der ersten
Periode des Kalenderjahres, 0.4), damit sie innerhalb eines Jahres konstant sind (R-62). Wachstumsknoten liefern
diesen Wert mit `index: calendar_year` bereits selbst (S01B-06 entschieden mit Änderung, Spec 00 § 4.5, R-91, 0.7).

`rp_vacancy_share(ctx, ids, construction_delay_months)` ist der interne Helfer aus `R/type-flow-rent-path.R` (WS-E):
Er rechnet den Leerstandsanteil vac_m nach 1.8.4 (struktureller Leerstand, Mieterwechsel, Entmietung während der
Arbeiten, Lease-up, jeweils mit Verschiebung und Aktivierungsfaktor; `rent_start` mit Token `completion` verschiebt
um den übergebenen n-Vektor `construction_delay_months`) aus Domänenpfaden und mittelt ihn flächengewichtet je
Periode. Er ist mit `aux$vacant_share` der Mietkomponenten identisch (Test E-9), hängt aber nicht von ihnen ab. So
entsteht kein Zyklus `rent_path` → `e_tenant` → `energy_cost` → `rent_path` (warmmietenneutrale Umlage, 1.9.5).

#### 3.6.3 Kontrafaktischer Vorzustand (`counterfactual_pre`)

Für Segmente von `before` rechnet der Typ dieselben Größen ein zweites Mal mit ω_cf = Δ_t (Zustand gilt über den
ganzen Horizont, ohne Fenster und ohne Aktivierung) und schreibt sie nur in `aux` mit Präfix `cf_`: `cf_kwh`,
`cf_co2_kg`, `cf_work_gross`, `cf_fees_gross`, `cf_network_gross`, `cf_bio_gross`, `cf_co2_gross`. Preis- und
Mengenpfade sind dieselben wie in der eigentlichen Rechnung (Spec 00 § 7.6: „mit denselben Preis- und Mengenpfaden“).

#### 3.6.4 Zeilen und Hilfsgrößen

| lokale Zeile | section | category | tax_category | cash | unit | VZ |
|---|---|---|---|:---:|---|:---:|
| `work` | project | `energy_cost` | `expense_deductible` (Selbstnutzer `expense_nondeductible`) | T | EUR | − |
| `base_fee` | project | `energy_cost` | dito | T | EUR | − |
| `service` | project | `energy_cost` | dito | T | EUR | − |
| `quantity` | memo | `energy_quantity` | `not_applicable` | F | kWh | + |
| `emission` | memo | `co2_emission` | `not_applicable` | F | t_co2 | + |

`vat_rate` der Zeilen = `vat_rate` des Trägers. Zeilen, die in allen Läufen 0 sind, bleiben erhalten (stabile
Tabelle). `aux`: `kwh` (Q), `co2_kg` (Q · EF · (1 − β), Grundlage des Stufenmodells), `work_gross` (W),
`network_gross` (NFg), `bio_gross` (BIOg), `co2_gross` (CO2g), `fees_gross` (BF + SV), `unit_price_gross`
((c + nf + bio)(1 + vat)), `beta` (β), `owner_share`, `vacancy` (v), `cost_share_owner_landlord` (f), `weight` (ω)
sowie die `cf_`-Größen (3.6.3).

Die Merkzeile `emission` enthält die **Treibhausgasbilanz aller Träger** (auch Strom und Fernwärme) und speist
`co2_emissions` (Spec 00 § 12.3); die CO₂-**Kosten** folgen dagegen nur dem BEHG-Faktor in `co2_cost`
(S01B-07 angenommen, Spec 00 § 7.6, § 12.3, R-101).

#### 3.6.5 Randfälle

- ω = 0 (Fenster leer, Zustand nach Horizont, Maßnahme inaktiv): alle Zeilen 0, keine Warnung.
- `price_includes = all` und negativer Restpreis (CO₂ + Netzentgelt > Gesamtpreis): E bei deterministischem Wert,
  sonst `pmax(…, 0)` mit W (Anteil der Läufe).
- Klasse `district_heating` mit `emission_factor_kg_kwh > 0`: CO₂-Aufteilung nach Stufenmodell auf den ausgewiesenen
  CO₂-Anteil (Teil C `district_heating: co2_cost_in_heat_price`); ohne Faktor keine Aufteilung.
- Selbstnutzer (o = 1): volle Kosten; Vermieter ohne Leerstand: alle Zahlungszeilen 0 (Kosten tragen die Mieter,
  Merkzeile in `tenant_costs`).

### 3.7 Typ `co2_cost` und Regeln des CO2KostAufG (WS-E, `R/type-flow-co2-cost.R`, `R/rules-co2kostaufg.R`)

#### 3.7.1 Parameter

| Parameter | Art | Default (T) | Bedeutung |
|---|---|---|---|
| `energy_component` | `ref` | Pflicht | eigenes Segment (`energy_cost`) |
| `all_energy_components` | `ids` | `[]` | alle Segmente mit Emissionsfaktor > 0 (Stufenmodell), in `after` |
| `pre_energy_components` | `ids` | `[]` | `before`-Segmente mit Emissionsfaktor > 0 (kontrafaktisches Stufenmodell), in `after` |
| `living_area_m2` | `number` | Pflicht (`{ref: building.living_area_m2}`) | Bezugsfläche (Wohnfläche) |
| `carrier_class` | `enum` | Pflicht | |
| `section43`, `emergency_replacement`, `newbuild_5b`, `hardship_5d` | `logical` | `false` | § 5a, Übergang, § 5b, § 5d |
| `installation_date` | `date` | Pflicht bei `section43` | |
| `landlord_share_reduction` | `share` | 0 | § 9 |
| `vacancy_landlord` | `logical` | `true` | wie `energy_cost` |

#### 3.7.2 Algorithmus

```text
E     <- ctx$component(energy_component)$aux
PC    <- ctx$rule("co2_params")(ctx$legal("co2kostaufg"), ctx$legal("bio_treppe"))     # NULL-Felder = Thema inaktiv
spez  <- Σ_{s ∈ all_energy_components} aux_s$co2_kg / (living_area_m2 · delta)          # kg/(m²·a); delta = 0 -> 0
sS    <- ctx$rule("co2_stage_share")(spez, PC)                                          # Stufenmodell (10 Stufen)
d5    <- ctx$rule("co2_s5a_dates")(section43 | newbuild_5b, installation_date, emergency_replacement,
                                    hardship_5d, PC)                                    # Termine oder NA
a5    <- ctx$overlap(d5$co2_from, NULL);  a5n <- ctx$overlap(d5$network_from, NULL);  a5b <- ctx$overlap(d5$bio_from, NULL)
         (Monatsanteil je Periode, by_period; 0 bei NA)
s     <- (a5 · PC$s5a_co2_share + (1 − a5) · sS) · (1 − landlord_share_reduction)
o     <- E$owner_share;  v <- E$vacancy · vacancy_landlord;  occ <- (1 − o) · (1 − v)
co2_owner            = −o · E$co2_gross
co2_vacancy          = −(1 − o) · v · E$co2_gross
co2_landlord         = −occ · s · E$co2_gross
network_fee_landlord = −occ · a5n · PC$s5a_network_share · E$network_gross                (nur carrier_class = gas)
bio_landlord         = −occ · a5b · PC$s5a_bio_share · pmin(E$beta, PC$s5a_bio_cap) / E$beta · E$bio_gross
                       (0, falls beta = 0)
```

Ist das Thema `co2kostaufg` inaktiv (Spec 00 § 4.10), gilt sS = s = 0 und a5 = 0: Die CO₂-Kosten der vermieteten,
belegten Fläche tragen die Mieter, `meta$notes` vermerkt „CO2KostAufG nicht angewendet“. Ist `bio_treppe` inaktiv,
gilt β = 0.

**Kontrafaktischer Vorzustand.** Für `before`-Segmente (E enthält `cf_`-Größen) rechnet der Typ zusätzlich spez_cf =
Σ_{pre_energy_components} cf_co2_kg / (living_area_m2 · delta), sS_cf, s_cf mit denselben Terminen und schreibt die
Mieteranteile `cf_tenant_co2_gross`, `cf_tenant_network_reduction`, `cf_tenant_bio_reduction` in `aux` (Formeln wie
3.7.3 mit `cf_`-Größen).

#### 3.7.3 Zeilen und Hilfsgrößen

| lokale Zeile | section | category | tax_category | cash | unit | VZ |
|---|---|---|---|:---:|---|:---:|
| `co2_owner` | project | `co2_cost` | `expense_nondeductible` (Selbstnutzer) bzw. `expense_deductible` | T | EUR | − |
| `co2_vacancy` | project | `co2_cost` | `expense_deductible` | T | EUR | − |
| `co2_landlord` | project | `co2_cost` | `expense_deductible` | T | EUR | − |
| `network_fee_landlord` | project | `energy_cost` | `expense_deductible` | T | EUR | − |
| `bio_landlord` | project | `energy_cost` | `expense_deductible` | T | EUR | − |

`vat_rate` = `vat_rate` des Trägers. Die Merkzeile `emission` schreibt `energy_cost` (3.6.4), nicht `co2_cost`.
`aux`: `landlord_share` (s), `specific_kg_m2` (spez), `stage_share` (sS), `s5a_active` (a5), `tenant_co2_gross`
((1 − o) · (1 − s) · CO2g, Vollvermietungsbasis), `tenant_network_reduction` ((1 − o) · a5n · `s5a_network_share` ·
NFg), `tenant_bio_reduction` ((1 − o) · a5b · `s5a_bio_share` · pmin(β, cap)/β · BIOg) und die `cf_`-Größen.

#### 3.7.4 Regeln und Rechtsparameter (Themen `co2kostaufg`, `bio_treppe`)

Die Regeln enthalten die Logik; die Zahlen stammen aus den Bibliothekseinträgen der Themen (Teil C § 3.5). Die Regel
`co2_params` bildet die Nutzlast auf kurze Namen ab:

| Name in `PC` | Nutzlast (Teil C) | Wert 2026-07-29 |
|---|---|---|
| `stage_upper`, `stage_share` | `co2kostaufg.stage_model[].upper_kg_m2a`, `.landlord_share` | 12, 17, …, 52, ∞ → 0; 0,10; …; 0,80; 0,95 |
| `s5a_installed_after` | `co2kostaufg.s5a.applies_to_installed_after` | 2026-07-29 |
| `s5a_co2_from`, `s5a_co2_share` | `s5a.co2_from`, `s5a.co2_landlord_share` | 2028-01-01; 0,5 |
| `s5a_network_from`, `s5a_network_share` | `s5a.network_fee_from`, `s5a.network_fee_landlord_share` | 2028-01-01; 0,5 |
| `s5a_bio_from`, `s5a_bio_share`, `s5a_bio_cap` | `s5a.bio_premium_from`, `.bio_premium_landlord_share`, `.bio_premium_max_fuel_share` | 2029-01-01; 0,5; 0,30 |
| `s5a_breakdown_months`, `s5a_suspension_months` | `s5a.transition.breakdown_install_months_before`, `.suspension_months` | 12; 12 |
| `bio_heating_classes`, `bio_installed_after`, `bio_building` | `bio_treppe.applies_to.heating_types`, `.installed_after`, `.building` | gas, oil, lpg; 2026-07-29; existing |
| `bio_years`, `bio_shares` | `bio_treppe.min_bio_share.years`, `.values` (Stufen ab 1. Januar) | 2029, 2030, 2035, 2040 → 0,10; 0,15; 0,30; 0,60; mit `stufe_2045` zusätzlich 2045 → 1,00 |

| Regel (Formals) | `returns` | Version (`valid_from`) | Inhalt |
|---|---|---|---|
| `co2_params(lp_co2, lp_bio)` | `params` | 2023-01-01 | Abbildung der Tabelle oben; fehlt `lp_co2` bzw. `s5a`: `stage_*` bzw. `s5a_*` = `NULL` |
| `co2_stage_share(specific_kg_m2_pa, PC)` | `path` | 2023-01-01 | Vermieteranteil nach Anlage CO2KostAufG: Stufe mit `specific < stage_upper` (Untergrenze einschließlich, Obergrenze ausschließlich): < 12 → 0; [12, 17) → 0,10; … ; [47, 52) → 0,80; ≥ 52 → 0,95; `NULL` → 0 |
| `co2_section43(carrier_class, installation_date, existing_building, PC)` | `value` (lgl; R-93, N-19) | 2026-07-29 | `TRUE`, wenn `carrier_class` ∈ `bio_heating_classes`, `installation_date >= bio_installed_after` und Bestandsgebäude (`bio_building = existing`) |
| `co2_s5a_dates(section43_or_5b, installation_date, emergency_replacement, hardship_5d, PC)` | `params` | 2026-07-29 | `NA`, wenn nicht `section43_or_5b`, bei `hardship_5d` oder ohne `s5a`; sonst `co2_from` = `s5a_co2_from` + (`emergency_replacement` und `installation_date >= s5a_co2_from − s5a_breakdown_months` ? `s5a_suspension_months` : 0) Monate; `network_from`, `bio_from` analog |
| `bio_share_section43(period_year, PC)` | `path` | 2026-07-29 | Stufenfunktion `bio_years`/`bio_shares` (0 vor der ersten Stufe); `NULL` → 0 |

Biogene Anteile tragen keinen CO₂-Preis (Memo 07 § 4.0). Erfüllt ein Hybrid- oder Solarthermie-Konzept die Pflicht
nach § 43 anderweitig, setzt der Nutzer `section43: false` im Zustand (W „Erfüllungsoption, Bio-Treppe entfällt“).

### 3.8 Typ `tenant_costs` (WS-E, `R/type-flow-tenant-costs.R`) – Heizkosten der Mieter (Warmmiete)

**Parameter:** `energy_components` (ids, alle Segmente), `co2_components` (ids), `pv_component` (ref, `null`),
`pre_energy_components` (ids, Segmente von `before`), `pre_co2_components` (ids), `rented_area_m2` (number, Σ
vermieteter Gruppenflächen als Ausdruck), alle Komponenten-ids auch in `after`.

```text
für jedes Segment s:   r_s = (1 − o_s) · [W_s + BF_s + SV_s]                     # Vollvermietungsbasis (ohne v)
für jedes co2-Segment: r_c = tenant_co2_gross − tenant_network_reduction − tenant_bio_reduction
pv:    b_pv = self_kwh_rented · unit_price_self − internal_charge                 # Vorteil der Mieter aus PV-Eigenverbrauch
energy (memo)     = Σ_s r_s + Σ_c r_c − b_pv                                       # >= 0
Vorzustand (nur mit before):
       r_s^cf = (1 − o_s) · [cf_work_gross_s + cf_fees_gross_s];   r_c^cf = cf_tenant_co2_gross − cf_…_reduction
       b_pv^cf = b_pv, falls energy.pv.measure = null (Bestandsanlage), sonst 0
energy_pre (memo) = Σ_{s ∈ pre} r_s^cf + Σ_{c ∈ pre} r_c^cf − b_pv^cf
```

| lokale Zeile | section | category | tax_category | cash | VZ |
|---|---|---|---|:---:|:---:|
| `energy` | memo | `tenant_energy_cost` | `not_applicable` | F | + |
| `energy_pre` | memo | `tenant_energy_cost_pre` | `not_applicable` | F | + |

Ohne Zustand `before` (Neubau) entfällt `energy_pre`; die Kennzahl `warm_rent_change_prepost` meldet dann
`no_tenant_data`. `aux`: `energy_eur_m2_month` (`energy / (rented_area_m2 · months)`), `energy_pre_eur_m2_month`,
`saving_eur_m2_month` ((energy_pre − energy) / (rented_area_m2 · months); 0 bei months = 0),
`co2_landlord_relief_eur_m2_month`.

Die Kennzahlen `warm_rent(_y1)` und `warm_rent_change_prepost(_y1)` (Spec 00 § 12.3) bilden daraus mit `rent`,
`modernization_levy` und `tenant_operating_cost` die Warmmiete bzw. ihre Änderung „vorher/nachher“; die Heizkosten
der Mieter enthalten nur den Mieteranteil, also ohne die Vermieteranteile an CO₂-Kosten, § 5a-Netzentgelten und
Bio-Mehrkosten (Konzept § 2.5, P6).

### 3.9 Typ `pv` (WS-E, `R/type-flow-pv.R`)

#### 3.9.1 Domänenfelder `energy.pv`

| YAML-Pfad (`energy.pv.`) | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `kwp` | value (num > 0) | kWp | – | ja | W > 100 | Nennleistung | 07 S3, S5 |
| `measure` | chr | – | `null` | nein | E unbekannt | Maßnahme der Investition (Teil A, `asset_type: pv_anlage`); `null` = Bestandsanlage | – |
| `commissioning_date` | timing | – | Fertigstellung von `measure`, sonst `valuation_date` | nein | – | Inbetriebnahme (EEG-Satz, Laufzeit, Alterung) | 07 §4.0 |
| `specific_yield_kwh_kwp` | value | kWh/(kWp·a) | 950 (G, `item_defaults."energy.pv"`; Memo 03 § 6.3, Qualität D) | nein | W < 700 oder > 1.200 | spezifischer Ertrag | 03 |
| `degradation_pa` | value (Rate) | 1/a | 0 (T) | nein | – | Ertragsminderung je Jahr | – |
| `self_consumption_share` | value (share) | – | – | ja | E > 1 | Eigenverbrauchsanteil am Ertrag | 07 S3, S5 |
| `self_consumption_carrier` | chr | – | (A) `heat_pump_carrier` des jeweils gültigen Zustands, sonst erster Träger der Klasse `power` | nein | E unbekannt | Träger, dessen Bezug der Eigenverbrauch ersetzt | 07 S3 |
| `feed_in_mode` | enum `partial`, `full` | – | `partial` (T) | nein | E `full` mit `self_consumption_share` > 0 | Teil- bzw. Volleinspeisung | 07 §4.0 |
| `feed_in_tariff_eur_kwh` | value | EUR/kWh | (A) `partial`: `{expr: "(pmin(energy.pv.kwp, 10) * market.feed_in_tariff.partial_le10kwp + pmin(pmax(energy.pv.kwp - 10, 0), 30) * market.feed_in_tariff.partial_10_40kwp + pmin(pmax(energy.pv.kwp - 40, 0), 60) * market.feed_in_tariff.partial_40_100kwp) / energy.pv.kwp"}` (Marktnamen nach Spec 00 § 4.3.11, N-16); `full` (≤ 10 kWp): `{ref: market.feed_in_tariff.full_le10kwp}` | bedingt (`partial` > 100 kWp bzw. `full` > 10 kWp: Pflicht) | E fehlt; O Bibliothek `prices/eeg_feed_in_*` außerhalb der Gültigkeit | anzulegender Wert der Einspeisevergütung (Mischsatz nach Leistungsstufen, Teil C § 3.6) | 07 §4.0; 03 §12 |
| `tariff_years` | int | a | 20 (G; Teil C `fixed_years`) | nein | – | Vergütungsdauer ab Inbetriebnahme | 07 S3 |
| `post_tariff_price_eur_kwh` | value | EUR/kWh | 0 (G) | nein | I | Erlös nach Vergütungsende | – |
| `internal_price_eur_kwh` | value | EUR/kWh (brutto) | 0 (G; B3) | nein | W > 0 bei `wu_genossenschaft` („Verrechnung rechtlich prüfen“) | Verrechnungspreis des an Mieter/Mitglieder gelieferten PV-Stroms | 07 S3; Konzept B3 |
| `opex_share_of_cost` | value (share) | 1/a | 0,012 (G, `item_defaults."energy.pv"`; Memo 03 § 9, Qualität D) | nein | W `validation.maintenance.service_double_energy`, wenn > 0 und `m_<energy.pv.measure>_maint` existiert (X-10) | Betrieb (Wartung, Versicherung, Zähler) in % der Investition; die Instandsetzung der PV-Maßnahme ist im Katalog von Teil A 0 | 03 §9 |
| `opex_eur_pa` | value | EUR/a | (A) `{expr: "energy.pv.opex_share_of_cost * measures.<measure>.cost_eur"}`; ohne `measure` Pflicht | nein | – | Betriebskosten (Preisstand der Maßnahme) | 07 S3 |
| `tax_exempt` | enum `auto`, `yes`, `no` | – | `auto` | nein | I `auto` ergibt `no` | Steuerbefreiung § 3 Nr. 72 EStG: `auto` = `kwp` ≤ 30 · max(1, `building.n_units`) und ≤ 100 (Stand JStG 2024; Abschnitt 9) | Konzept 3.12 |
| `vat_zero_rate_attested` | lgl | – | `false` (T) | nein | I `true` („Nachweis der Begünstigung nach § 12 Abs. 3 Nr. 1 UStG erforderlich“); W `kwp` > 30 und `false` („19 % USt auf Lieferung und Installation angesetzt“) | **Begünstigungsattribut** der Anlage (Spec 00 § 7.10, R-84): Nullsteuersatz für Lieferung und Installation auch über 30 kWp | Konzept 3.2, P18 |

**Umsatzsteuer der Investition (Spec 00 § 7.10, R-86, X-25).** Den Default von `measures.<k>.vat_rate` der Maßnahme
`energy.pv.measure` setzt die Ableitungsregel `rule:measure_catalog` (WS-A, Teil A) als `expr`-Knoten, nicht der
Expander: `{expr: "ifelse(energy.pv.kwp <= 30 | energy.pv.vat_zero_rate_attested, 0, 0.19)"}`, die Schwelle 30 aus
`bctx$legal("umsatzsteuer")$pv_zero_rate$max_kwp_without_proof` als Konstante eingesetzt (Rechtswert, R-92 (c));
`vat_zero_rate_attested` ist ein logisches Pfadsymbol nach R-91. Das Zeilenmetadatum `vat_rate` ist der Basisfallwert
(`ctx$param_base()`). Ein ausdrücklich gesetzter `vat_rate` der Maßnahme gewinnt (W bei Widerspruch). Die
Betriebskosten (`opex`) tragen 19 %.

#### 3.9.2 Algorithmus und Zeilen

```text
w_pv <- 1{m >= mi(commissioning_date) + s_c} · act(measure)       (Monatsgewicht; ω_pv = Σ_{m∈t} w_pv / 12)
age  <- pmax(year[j] − Jahr(commissioning_date), 0)
E    <- kwp · specific_yield_kwh_kwp · (1 − degradation_pa)^age · ω_pv                     # kWh
Dm   <- Σ_{seg ∈ self_consumption_components} aux_seg$kwh                                  # Bezug des Trägers
S    <- pmin(E · self_consumption_share, Dm);   F <- E − S
ωT   <- Jahresanteil der Monate in [commissioning + s_c, commissioning + s_c + 12 · tariff_years)
feed_in            = +F · (feed_in_tariff · ωT/ω_pv + post_tariff_price · (1 − ωT/ω_pv))  # ω_pv > 0
p_s  <- Σ aux$work_gross / Σ aux$kwh der Eigenverbrauchssegmente (Bruttopreis je kWh; 0, wenn kein Bezug)
self_consumption   = +o · S · p_s                                                          # Selbstnutzer bzw. o-Anteil
internal_sale      = +(1 − o) · S · internal_price_eur_kwh                                 # Vermieter
opex               = −opex_eur_pa · index_year(inflation, Preisstand) · ω_pv
generation (memo)  = +E;  feed_in_kwh (memo) = +F
```

`self_consumption_components` (ids) sind die Segmente des Eigenverbrauchsträgers in allen Zuständen (je Periode
wirkt nur das gültige, weil die übrigen ω = 0 haben).

| lokale Zeile | section | category | tax_category | cash | unit | VZ |
|---|---|---|---|:---:|---|:---:|
| `feed_in` | project | `energy_income` | `income_tax_exempt` (§ 3 Nr. 72 erfüllt) bzw. `income_other_taxable` | T | EUR | + |
| `self_consumption` | project | `energy_saving` | `imputed_benefit` | T | EUR | + |
| `internal_sale` | project | `energy_income` | `income_other_taxable` | T | EUR | + |
| `opex` | project | `operating_cost` | `expense_deductible` (Selbstnutzer `expense_nondeductible`) | T | EUR | − |
| `generation`, `feed_in_kwh` | memo | `energy_quantity` | `not_applicable` | F | kWh | + |

`vat_rate` 0 für `feed_in`, `self_consumption`, `internal_sale` (Kleinunternehmer, § 19 UStG; D6), 0,19 für `opex`.
`aux`: `self_kwh` (S), `self_kwh_rented` ((1 − o) · S), `unit_price_self` (p_s), `internal_charge` ((1 − o) · S ·
`internal_price_eur_kwh`).

Die Segmente des Eigenverbrauchsträgers buchen den **vollen** Bezug; die Zeile `self_consumption` gleicht den
vermiedenen Bezug aus (Zahlung netto korrekt, keine Zirkularität: `pv` hängt von `energy_cost` ab, nicht umgekehrt).
Die Merkzeile `emission` der Stromsegmente bleibt brutto (vor PV); die Kennzahl `co2_emissions` ist deshalb für
PV-Varianten konservativ (Abschnitt 9).

#### 3.9.3 Hinweise

- Mieterstrom und gemeinschaftliche Gebäudeversorgung nur über `custom_series` (1.16).
- Steuerbefreite Vermietungsgenossenschaft: Je Betriebsjahr Quote q = (Σ `energy_income` + `operating_income` +
  `other_income`) / (Σ `rent` + `modernization_levy` + Zähler). W ab q > 0,05 bzw. > 0,15 bei Mieterstrom (Hälfte der
  Grenzen 10 % bzw. 30 % nach § 5 Abs. 1 Nr. 10 KStG, Konzept § 3.12); Ausgabe durch WS-H (`report-views.R`).
- Wechselrichtertausch und Modulersatz sind Ersatzinvestitionen (Teil A).

### 3.10 Selbstnutzer: Block `household`, Typ `imputed_rent`, Expander `household`, Haushaltssicht

#### 3.10.1 Block `household` (Spec 00 § 4.3.5, konkretisiert)

| YAML-Pfad (`household.`) | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `net_income_month_eur` | value | EUR/Monat | `null` | nein (Pflicht für `burden_ratio_max`) | W fehlt bei `selbstnutzer` | Haushaltsnettoeinkommen inkl. Kindergeld | 07 §5.4 |
| `income_growth` | value (Rate) | 1/a | `{ref: market.inflation}` (G, `item_defaults."household"`; Spec 00 § 4.3.5) | nein | – | Fortschreibung des Einkommens | – |
| `taxable_income_avg_eur` | num | EUR/a | `null` | bedingt (einkommensabhängige Förderung) | E fehlt, wenn eine Förderbedingung es verwendet (4.3) | Ø zu versteuerndes Einkommen des 2. und 3. Kalenderjahres vor Antrag | 02 §5.2, §5.6 |
| `n_children_u18` | int ≥ 0 | – | 0 (G) | nein | – | kindergeldberechtigte Kinder < 18 (Einkommensgrenzen, KfW 300/308; Schwellenverschiebung KfW 458 einmal ab einem Kind, 4.3.2) | 02 §5.2 |
| `savings_capacity_month_eur` | value | EUR/Monat | `null` | nein | – | Sparfähigkeit (Markierung `equity_call_over_savings`) | Spec 00 9.8 |
| `current_rent_month_eur` | value | EUR/Monat | `null` | nein | I fehlt bei Selbstnutzer-Neubau/Erwerb („Doppelbelastung in der Bauphase nicht ausgewiesen“) | bisherige **Warmmiete** bis zum Einzug; nur Kennzahl `monthly_burden_construction`, keine Ledger-Zeile, konstant nominal | Spec 00 4.3.5, 12.3; 07 S5 |
| `expected_income_tax_eur_pa` | value (Pfad zulässig) | EUR/a | `null` | nein | W fehlt bei einem Instrument `tax_credit` („§ 35c ohne Deckelung“); W Tranche > Wert („Steuerermäßigung gedeckelt“) | voraussichtliche tarifliche Einkommensteuer je Veranlagungsjahr; deckelt die § 35c-Tranchen (4.8, Spec 00 § 10.9, R-79) | Konzept 3.9, L22 |
| `savings_eur` | value | EUR | `null` | nein | W gesetzt und `financing` enthält einen `equity`-Baustein („Doppelzählung“) | Erspartes, das als Einlage in t = 0 eingesetzt wird (Expander `household`) | 07 S4 |
| `contribution_month_eur` | value | EUR/Monat | `null` | nein | – | geplante laufende Einlage aus dem Einkommen | – |
| `contribution_from`, `contribution_to` | timing | – | `valuation_date`, `end_date` | nein | – | Zeitraum der laufenden Einlage | – |

#### 3.10.2 Expander `household` (WS-E2, `R/expand-household.R`, order 50)

- `h_equity` (Typ `equity`, im Block `financing`): `amount_eur = {ref: household.savings_eur}`, `date =
  valuation_date`; nur wenn `savings_eur` gesetzt ist und kein anderer `equity`-Baustein existiert.
- `h_contrib` (Typ `equity`): `contributions_pa = {expr: "household.contribution_month_eur * 12"}`,
  `start_event`/`to` = `contribution_from`/`contribution_to`; nur wenn gesetzt.
- Belastungs-Hilfszeilen entstehen **nicht**: Die Haushaltskennzahlen wählen Zeilen über das Kategoriemerkmal
  `burden` (Spec 00 § 7.6, § 12.3); `current_rent_month_eur` geht nur in `monthly_burden_construction` ein.

#### 3.10.3 Typ `imputed_rent` (WS-E, `R/type-flow-imputed-rent.R`)

Parameter: `area_m2` (number, `{ref: unit_groups.<g>.living_area_m2}`), `rent_eur_m2_month` (value, ref auf
`imputed_rent_eur_m2_month`), `growth` (value, `{ref: unit_groups.<g>.imputed_rent_growth}`), `base_date` (timing,
`valuation_date` + 12 Monate), `start_event` (timing, Bestand `valuation_date`, Neubau Token `completion`), `to`.
`value = area_m2 · rent_eur_m2_month · 12 · index_year(growth, base_date) · delta · overlap`; Zeile `value`
(project/`imputed_rent`/`imputed_benefit`, T, +); `grid_invariant = TRUE`. Nur für den Vergleich „Kaufen oder
Mieten“; in Variantenvergleichen gleicher Gebäude hebt sie sich auf (I).

#### 3.10.4 Definitionen der Haushaltssicht (Eingangsdaten für WS-D2/WS-H)

| Größe | Definition (Konzept § 2.5, Memo 07 § 5.4, Spec 00 § 12.3) |
|---|---|
| monatliche Belastung | −Σ zahlungswirksame Zeilen mit `burden = TRUE` (Kategorien `operating_cost`, `property_tax`, `maintenance`, `energy_cost`, `co2_cost`, `energy_income`, `energy_saving`, `other_cost`, Kredit-`repay`, `interest`, `fees`) je Betriebsjahr / Σ Monate; Investitionen aus Eigenmitteln und Zuschüsse zählen nicht (Einmalbeträge) |
| monatliche Belastung „ohne Tilgung“ | wie oben ohne Kategorie `repay` (Kostensicht, R-83) |
| Ersparnis bzw. Mehrkosten pro Monat | `monthly_saving_y1`, `monthly_saving_avg10` (Spec 00 § 12.6): Belastung der Referenz − Belastung der Variante; positiv = Ersparnis |
| Doppelbelastung Bauphase | `monthly_burden_construction` mit `current_rent_month_eur` |
| Eigenanteil heute nach Förderung | Kennzahl `own_contribution` (Spec 00 § 12.3, R-83): Investition abzüglich Zuschüsse, Steuerermäßigung und neuer Kredite, nominal; die Typen dieses Teils liefern dafür die Zeilen `grant` und `tax_credit` mit `measure_id` |
| Belastungsquote | `burden_ratio_max` (Spec 00 § 12.3) mit `household.net_income_month_eur` × Index(`income_growth`); Schwelle `analysis.thresholds.burden_share` |

### 3.11 Testfälle Energie, CO₂, PV, Mieterkosten, Haushalt

Gemeinsame Annahmen wie 1.15. Rechtsstand 2026-10-25 mit den Bibliothekseinträgen aus Teil C § 3.5. Testdateien
(N-18): `test-type-flow-energy-cost.R` (E-*), `test-type-flow-co2-cost.R` und `test-rules-co2kostaufg.R` (C-*),
`test-type-flow-tenant-costs.R` (TC-*), `test-type-flow-pv.R` (PV-*), `test-type-flow-imputed-rent.R` (H-2), alle
WS-E; `test-expand-household.R` (H-1, WS-E2).

| Nr. | Eingabe | Erwartung |
|---|---|---|
| C-1 (Memo 02 Bsp. 4) | MFH 1.000 m², Gas 150.000 kWh_Hs, EF 0,182, vat 0,19, Vermieter, kein Leerstand | 27.300 kg → 27,3 kg/m²·a → Stufe [27, 32) → 40 %. CO₂-Kosten brutto / Vermieter Stufe / § 5a: 55 €/t: 1.786,79 / 714,71 / 893,39; 65 €/t: 2.111,66 / 844,66 / 1.055,83; 100 €/t: 3.248,70 / 1.299,48 / 1.624,35; 150 €/t: 4.873,05 / 1.949,22 / 2.436,53 |
| C-2 (S1-T9) | 280.000 kWh_Hs, EF 0,181, 1.600 m² | 31,675 kg/m²·a → 40 % |
| C-3 (S3-T5) | 109.200 kWh_Hs, EF 0,181, 840 m² | 23,530 kg/m²·a → 30 % |
| C-4 (S1-T10, § 5a 2028) | Zustand `after` mit Gas-Brennwertkessel (Einbau 2027-10-01, `section43` abgeleitet), 255.000 kWh_Hs, EF 0,181, CO₂ 70 €/t, Netzentgelt netto 0,0219 €/kWh, vat 0,19 | 2028: `co2_landlord` −1.922,36 (CO₂ brutto 3.844,71 × 0,5); `network_fee_landlord` −3.322,78 (6.645,55 × 0,5); 2027: Stufenmodell |
| C-5 (Bio-Treppe) | wie C-4, 2035 (β = 0,30, CO₂ 105 €/t, Bio-Mehrkosten netto 0,06 €/kWh) | CO₂ brutto 4.036,95 → `co2_landlord` −2.018,47; Bio brutto 5.462,10 → `bio_landlord` −2.731,05; 2040 (β = 0,60): Bio brutto 10.924,20, `bio_landlord` −2.731,05 (Deckel 30 %) |
| C-5a (`stufe_2045`) | wie C-5, Jahr 2045 | ohne Reformcode β = 0,60; mit `pending_reforms: [stufe_2045]` β = 1,00 und CO₂-Kosten 0 |
| C-6 (Stufengrenzen) | spez = 11,999 / 12,0 / 16,999 / 17,0 / 31,9 / 32,0 / 51,99 / 52,0 | 0 / 0,10 / 0,10 / 0,20 / 0,40 / 0,50 / 0,80 / 0,95 |
| C-7 (Leerstand) | CO₂ brutto 1.000, v = 0,05, Stufe 30 %, o = 0 | `co2_vacancy` −50,00; `co2_landlord` −285,00; Mieter-Merkzeile (Vollvermietungsbasis) 700,00 |
| C-8 (Übergang § 5a) | Einbau 2027-06-01 mit `emergency_replacement: true` | a5 = 0 in 2028, 1 ab 2029 |
| C-9 (Selbstnutzer) | o = 1, Gas 24.500 kWh, CO₂ 60 €/t, EF 0,181 | `co2_owner` 2027 −316,62 (24.500 · 0,181 · 60 / 1000 · 1,19); keine Vermieterzeilen |
| C-10 (Thema inaktiv) | C-1 mit Bibliothek ohne wählbaren Eintrag `co2kostaufg` | `co2_landlord` 0; Mieter-Merkzeile 2.111,66 (65 €/t); `meta$notes` „CO2KostAufG nicht angewendet“ |
| E-1 (S4-T5/T6) | Zustand mit `heat_pump_carrier: heatpump_power`, Nutzwärme 21.560 kWh, `jaz` 2,9; `price_basis: gross` 0,24 €/kWh, Grundpreis 140, Wartung 250, Fortschreibung 0 | 7.434,48 kWh; Kosten 2.174,28 EUR/a (181,19 EUR/Monat) |
| E-2 (S4-T6) | Gas 24.500 kWh, Gesamtpreis brutto 0,125 (`price_includes: all`, `price_basis: gross`), Grundpreis 180, Wartung 300 | 3.542,50 EUR/a; Ersparnis E-1 gegenüber E-2: 114,02 EUR/Monat |
| E-3 (S4 Zustände) | Stufe 2: Nutzwärme 21.560 · 0,75, `jaz` 3,2; Stufe 3: 21.560 · 0,75 · 0,72, `jaz` 3,5 | 5.053,125 bzw. 3.326,40 kWh_el |
| E-4 (Performance Gap) | `before` Bedarf 30.000 (`demand`), `prebound_factor` 0,7; `after` Bedarf 12.000, `rebound_factor` 1,1, `jaz` 3,0 | r = 1: Q = 13.200, 4.400 kWh_el; r = 0,8: Q = 14.760, 4.920 kWh_el |
| E-5 (Teiljahr) | Zustandswechsel 2027-10-01 (S1 V2), Gas 280.000 kWh/a vorher, Wärmepumpe 120.000 / 2,9 nachher | 2027: Gas 210.000 kWh; Strom 10.344,83 kWh; ab 2028: 41.379,31 kWh_el |
| E-6 (`price_includes: all`) | Gesamt brutto 0,125, Netzentgelt netto 0,0257, EF 0,181, CO₂ 60 (2027) / 70 (2028), Fortschreibung 0 | Rest netto 0,068482; Preis brutto je kWh 2027 0,125000, 2028 0,127154 |
| E-7 (F10) | E-1 auf Raster `mixed` | Jahressummen 2027–2032 identisch mit `annual` (1e-9 relativ) |
| E-8 (Treibhausgasbilanz) | `before` Gas 150.000 kWh_Hs (Default-Faktor 0,21672), `after` ab 2028-01-01 Wärmepumpe 20.000 kWh (0,560) | `emission` 2027 32,508 t; 2028 11,200 t; Differenz zur Variante ohne Maßnahme je Jahr ab 2028 21,308 t (Beitrag zu `co2_reduction`) |
| E-9 (Leerstandshelfer) | RP-4 mit `vacancy_rate` 0,03, `lease_up_months` 0; RP-10 (Lease-up 4) | `rp_vacancy_share` = `aux$vacant_share` der Mietkomponente (1e-12) |
| E-10 (Aktivierung) | E-5 mit `measures.<k>.active` = (1, 0) in zwei Läufen | Lauf 1 wie E-5; Lauf 2: Gas 280.000 kWh in allen Jahren, Strom 0 |
| E-11 (Trägerdefaults, `test-scenario-layers.R`, WS-A) | `energy.carriers: {gas: {}, pellets: {}, kohle: {price_eur_kwh: 0.09}}`, Rechtsstand 2026-10-25 | `gas`: `class` gas, `price_eur_kwh` `{ref: market.energy_price.gas}` (Herkunft `global#item_defaults.energy.carriers`), `network_fee_eur_kwh` `{ref: market.energy_network_fee.gas}`, `emission_factor_kg_kwh` 0,1814, `ghg_factor_kg_kwh` 0,21672 (Herkunft `rule:carrier_defaults` bzw. Bibliotheks-id), `vat_rate` 0,19; `pellets`: `biomass`, Netzentgelt 0, EF 0, THG 0,020, `vat_rate` 0,19; `kohle`: E (`class` fehlt bei nicht kanonischer id); mit `class: coal`: THG 0,400, EF 0 mit W |
| E-12 (Rebound-Konvention) | E-4 mit Overlay `rebound_calculated` (PERT 0,9; 1,1; 1,4) auf `energy.performance_gap.rebound_factor`, Basiswert 1,0; dazu Overlay `rebound` (PERT 0,82; 1,0; 1,27) | W `validation.energy.rebound_base_differs`; mit `rebound_factor: 1.1` keine Meldung; Vorlage `rebound` (Modus 1,0): keine Meldung |
| TC-1 (Mieter vorher/nachher) | 1.000 m² vermietet, kein Leerstand; `before` Gas 150.000 kWh_Hs, Arbeitspreis netto 0,0634, Netzentgelt 0,0257, EF 0,18, CO₂ 65 €/t (konstant); `after` ab 2028-01-01: Wärmepumpe 20.000 kWh, 0,21 €/kWh netto | Stufe 27,0 kg/m²·a → 40 %. 2027: `energy` = `energy_pre` = 17.157,42 (15.904,35 + 0,6 · 2.088,45); 2028: `energy` 4.998,00, `energy_pre` 17.157,42; `saving_eur_m2_month` 2028 1,013285 |
| TC-2 (ohne Vorzustand) | Neubau, nur `after` | Zeile `energy_pre` fehlt; `warm_rent_change_prepost` = NA (`no_tenant_data`) |
| PV-1 (S3-T6) | 30 kWp, 900 kWh/kWp, Eigenverbrauch 0,30, `market.feed_in_tariff.partial_le10kwp` 0,0770, `partial_10_40kwp` 0,0666 | Satz 0,0700667; Einspeisung 18.900 kWh → `feed_in` 1.324,26 EUR/a; mit `degradation_pa` 0,003 im 2. Jahr: 1.320,29 |
| PV-1a (Stufe 40–100 kWp) | 60 kWp, 950 kWh/kWp, Eigenverbrauch 0,20, Sätze wie PV-1 und `partial_40_100kwp` 0,0545 | Satz (10 · 0,0770 + 30 · 0,0666 + 20 · 0,0545) / 60 = 0,0643000; Einspeisung 45.600 kWh → `feed_in` 2.932,08 EUR/a; 100 kWp: Satz 0,0603800; 120 kWp `partial` ohne `feed_in_tariff_eur_kwh`: E |
| PV-2 (S5) | Selbstnutzer, 8 kWp · 950, Eigenverbrauch 0,35, Haushaltsstrom brutto 0,37 €/kWh | `self_consumption` +984,20 EUR/a (2.660 kWh) |
| PV-3 | Eigenverbrauch > Bedarf (Bedarf 1.000 kWh, E · Anteil = 2.660) | S = 1.000, F = E − 1.000 |
| PV-4 (USt-Attribut) | 45 kWp mit `measure`, ohne bzw. mit `vat_zero_rate_attested` | Maßnahme `vat_rate` (Knoten aus `rule:measure_catalog`) 0,19 mit W bzw. 0 mit I (Teil A); 25 kWp: 0 ohne Meldung; Overlay auf `energy.pv.kwp` (Basis 28, MC bis 35): Zeilenmetadatum `vat_rate` = Basisfallwert 0 |
| H-1 | `household.savings_eur` 60.000, kein `equity` in `financing` | `h_equity__in` +60.000 in t = 0 |
| H-2 (`imputed_rent`) | 140 m², 9,00 EUR/m², Wachstum 1,5 % | 2027: 15.120,00; 2028: 15.346,80 |

---

## 4. Förderung

### 4.1 Generisches Fördermodell und Abbildung

Ein Förderinstrument ist ein Eintrag `funding.<f>` mit Bibliotheksbezug (`from: funding/<id>`, Nutzlast Teil C § 3.4
nach Memo 02 § 5.8) und Szenarioangaben (Maßnahmen, Antragsdatum, Fakten, Zusage). Ein neues Programm braucht keinen
Code, nur einen Eintrag nach diesem Schema (Konzept § 5.6). Der Expander `funding` (WS-E2, `R/expand-funding.R`,
order 40) wertet Berechtigung, Degression und Bedingungen **deterministisch** aus und erzeugt die Zahlungsbausteine;
wertabhängige Größen (Bemessung auf realisierten Kosten, Deckel, Zusage je Lauf) rechnen die Typen.

| `instrument_type` | erzeugt | Typ | Ledger |
|---|---|---|---|
| `grant` | `f_<f>_grant` (`components`) | `grant` (4.5) | grants/`grant` je Maßnahme (`grant_<m>`) |
| `loan` | `f_<f>_loan` (`financing`) | `annuity_loan`, `installment_loan`, `bullet_loan` (Spec 00 § 8, Teil A) | loans/* |
| `loan_with_repayment_grant` | `f_<f>_loan` mit `repayment_grant` (Baubegleitung in der Zusage) | dito | loans/* und Merkzeile `repayment_grant` |
| `interest_subsidy` | `f_<f>_subsidy` (`components`) | `recurring` (Spec 00 § 7.12) | grants/`operating_subsidy` |
| `tax_credit` | `f_<f>_35c` (`components`) | `tax_credit_35c` (4.8) | grants/`tax_credit` je Maßnahme (`credit_<m>`) |
| `rent_binding` | keine eigene Komponente | – | wirkt im Expander `unit_groups` (1.6 Nr. 6) |

```text
funding.<f> {from: funding/<id>, measures, application_date, facts, …}
   │  Schicht 3: Nutzlast gemischt (lokal gewinnt), Gültigkeit nach application_date (O)
   ▼
Expander funding (order 40)
   1 Berechtigung (eligibility, 4.3.1)            -> W „nicht berechtigt“ und kein Baustein, sonst weiter
   2 Degression nach application_date (4.3.3)     -> Ausdrücke mit Bezug auf die Nutzlast
   3 Bedingungen der Satzbausteine (4.3.2)        -> aktive Bausteine, Höchstsatz
   4 Bemessungsgrundlage und Deckel (4.4)         -> Deckel in EUR, förderfähige Anteile
   5 Bausteine f_<f>_grant | f_<f>_loan | f_<f>_subsidy | f_<f>_35c  (4.5–4.8)
   6 Zusage: approval_timing (Code aus rule:approval_timing), Entscheidungsknoten, on_reject (4.9)
   7 Kumulierung (4.11)                           -> E bzw. W
```

Vor dem Expander laufen die Ableitungsregeln `rule:approval_timing`, `rule:approval_probability` und
`rule:tax_credit_defaults` (5.5) und danach `item_defaults."funding"` (7.1); der Expander liest die abgeleiteten
Domänenblätter und leitet sie nicht selbst her (Spec 00 § 4.12 Nr. 1, R-86, N-07). Förderinstrument-ids haben
höchstens 30 Zeichen (`f_<f>_subsidy` ≤ 40; Spec 00 § 4.4 Nr. 2, N-23).

### 4.2 Feldtabelle `funding.<f>`

Ebene: **[L]** Nutzlast des Bibliothekseintrags (überschreibbar), **[S]** Szenarioangabe. Felder aus Spec 00 § 4.3.7:
`from`, `instrument_type`, `measures`, `application_date`, `approved`, `approval_probability`,
`availability_after_2030`, `payout_delay_months`, `approval_timing`, `fallback_variant`, `on_reject`.

| YAML-Pfad (`funding.<f>.`) | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `from` | chr | – | `null` | nein | E unbekannter Eintrag; O außerhalb [`valid_from`, `valid_to`) zum `application_date` | Bibliotheks-id [S] | Spec 00 4.9 |
| `label` | chr | – | Label des Eintrags | nein | – | Anzeige | – |
| `instrument_type` | enum:instrument_type | – | (B) | ja | E unbekannt | Art des Instruments (4.1) [L] | Spec 00 4.3.7 |
| `provider`, `program_code` | chr | – | (B) | nein | – | Anzeige, Kumulierung, Jahresdeckel [L] | 02 §5.8 |
| `measures` | ids | – | – | ja (außer `rent_binding`) | E unbekannte Maßnahme; E leer | geförderte Maßnahmen [S] | Spec 00 4.3.7 |
| `unit_groups` | ids | – | alle Gruppen | nein | E unbekannt | Wohnungsgruppen (WE-Zahl der Deckel, Selbstnutzung, Mietbindung) [S] | – |
| `applicant` | enum:applicant | – | (A) aus der Perspektive: `wu_kommunal` → `kommunales_unternehmen`, `wu_genossenschaft` → `genossenschaft`, `wu_privat` → `unternehmen`, `kleinvermieter` → `privatperson_vermieter`, `selbstnutzer` → `privatperson` | nein | W nicht in `eligibility.applicants` (Oberbegriff `privatperson` nach 4.3.1) | Antragsteller [S] | 02 §5.8 |
| `application_date` | date | – | `project.application_date` (Spec 00) | nein | O; W „förderschädlicher Vorhabenbeginn“ nach dem frühesten Termin der Maßnahmen des Instruments bei `application_before_start`, außer bei ausdrücklichem `approval_timing: before_start` (eine Meldung je Instrument, R-111) | Antragsdatum: Gültigkeit, Degression, Einkommensbasis [S] | Spec 00 4.3.7 |
| `approved` | value (0/1) | – | 1 (G, `item_defaults."funding"`; Spec 00 § 4.3.7; als Domänenblatt nötig für Overlay-Ziel, Bezüge und Set `foerderstopp`, 0.3) | nein | E Wert ∉ {0, 1} | Zusage je Lauf; Ziel des automatischen Bernoulli-Schlüssels (Spec 00 § 11.6 Nr. 4) bzw. eines Overlay-Eintrags [S] | Spec 00 9.11 |
| `approval_probability` | value (share) | – | (AR) `rule:approval_probability` (5.5; S01B-13 entschieden mit Änderung, R-86): Basiswert b = `{ref: funding.<f>.budget_risk.approval_probability}` bzw. 1 ohne `budget_risk`; bei `application_date` ≥ 2031-01-01 `{expr: "<b> * funding.<f>.availability_after_2030"}`, sonst b | nein | W < 0,5; I Overlay auf `approved` vorhanden („automatischer Schlüssel entfällt“) | Zusagewahrscheinlichkeit [L/S]; liest `smp_plan()` als Basisfallwert (Spec 00 § 11.6 Nr. 4) | 07 §4.0; Konzept 4.2 |
| `availability_after_2030` | value (share) | – | 0,7 (G, `item_defaults."funding"`; Memo 07 § 4.0, D) | nein | E > 1 | Verfügbarkeit des Programms nach 2030; wirkt nur über `approval_probability` bei Antrag ab 2031 (N-09; Overlay-Vorlage `processes/funding_risks_2026`, `use: availability_after_2030`) [S] | 07 §4.0 |
| `application_before_start` | lgl | – | (B) | nein | – | Programmbedingung „Antrag vor Vorhabenbeginn“ [L] | Konzept 3.9 |
| `approval_timing` | enum `auto`, `before_start`, `after_start` | – | `auto`; aufgelöst durch (AR) `rule:approval_timing` (5.5): `before_start`, wenn `application_date` ≤ frühester Termin der Maßnahmen **des Instruments**, sonst `after_start`; Instrument ohne Maßnahmen: frühester Termin aller Maßnahmen der Variante (Spec 00 § 4.3.7, R-111) | nein | W „förderschädlicher Vorhabenbeginn“ nur bei `application_before_start = true` und einem Antrag nach dem frühesten Termin der Maßnahmen des Instruments (gleichbedeutend mit `auto` → `after_start`; Meldung von `application_date`); ein ausdrückliches `after_start` bei rechtzeitigem Antrag („Zusage erst nach Vorhabenbeginn“, Beginn auf eigenes Risiko) meldet nichts; ein ausdrückliches `before_start` erklärt den Vorhabenbeginn nach dem Antrag (z. B. wenn der Termin einer Maßnahme mit `year` nur den Zahlungsansatz zum 1. Januar beschreibt, Teil C S3 V2) und unterdrückt die W (R-111) | Zeitpunkt der Zusage relativ zum Baubeginn (4.9); alle Verbraucher (Expander, Validierung, `smp_plan()`, `vofi_build()`) lesen nur den aufgelösten Code [S] | Spec 00 4.3.7 |
| `fallback_variant` | chr (Varianten-id) | – | `null` | nein | E nach Spec 00 § 9.11 Nr. 1 | Ausweichvariante; macht ein `before_start`-Instrument zum Entscheidungsknoten [S] | Spec 00 9.11 |
| `on_reject` | enum `balance`, `drop_measures` | – | `balance` (G, `item_defaults."funding"`) | nein | I gesetzt bei Entscheidungsknoten („wirkungslos“) | Lücke über den Ausgleich bzw. Wegfall der geförderten Maßnahmen (0.8) [S] | Spec 00 9.11 |
| `payout_delay_months` | value (number ≥ 0) | Monate | 0 (G, `item_defaults."funding"`; Spec 00 § 9.11 Nr. 7); `tax_credit`: 12 (AR, `rule:tax_credit_defaults`; Spec 00 § 10.9) | nein | E < 0 | zusätzlicher Auszahlungsverzug je Lauf, stochastisch zulässig (Teil C `payout_delay`); verschiebt den Termin nach R-98 (4.5, 4.8) [S] | Konzept B12 |
| `payout` | map {`event` enum:payout_event, `lag_months` int} | – | (B); sonst `{event: completion_proof, lag_months: 0}` | nein | E unbekanntes Ereignis | Auszahlungsereignis und Regelverzug [L] | 02 §5.8 |
| `eligibility` | map {`applicants`, `project_types`, `measure_types`, `conditions`, `exclusions`} | – | (B) | nein | 4.3.1 | Berechtigung [L] | 02 §5.8 |
| `eligibility_override` | lgl | – | `false` | nein | I `true` („Berechtigung vom Nutzer bestätigt“) | automatisch prüfbare Berechtigungsbedingungen übergehen [S] | – |
| `basis` | map | – | (B) | nein | 4.4 | Bemessungsgrundlage, Höchstbeträge, KG-Filter [L] | 02 §5.8 |
| `eligible_shares` | map Maßnahme → value (share) | – | 1 je Maßnahme (T); 0 bei `kg` ∉ `basis.eligible_cost_kg` (I) | nein | E > 1; E Maßnahme ∉ `measures` | förderfähiger Anteil der Maßnahmenkosten [S] | 02 §5.8 |
| `eligible_cost_eur` | value | EUR | `null` | nein | I gesetzt („ersetzt die Ableitung aus den Maßnahmenkosten“) | feste förderfähige Kosten [S] | – |
| `rate_components` | map id → {`rate` value, `condition` chr, `schedule_by_taxable_income` map, `threshold` map, `mode` enum, …} | – | (B) | nein | E Bedingung ungültig (4.3.2) | Satzbausteine (Grundförderung, Boni) [L] | 02 §5.8 |
| `rate_cap` | map {`default` value, `exceptions` Sequenz {condition, cap}} | – | (B); sonst `{default: 1}` | nein | – | Höchstfördersatz [L] | 02 §5.8 |
| `degression` | Sequenz {`target`, `start`, `step`, `every_months`, `floor`} | – | (B) `[]` | nein | E `target` existiert nicht; I (statt E), wenn das Ziel in einem Baustein liegt, den die `from:`-Kette mit `~` entfernt hat (4.3.3, X-02) | Absenkung nach Antragsdatum (4.3.3) [L] | 02 §5.8 |
| `amount_eur` | value | EUR | Kredite: (A) 4.6; übrige: `null` | bedingt (`interest_subsidy` ohne `subsidized_amount_eur`) | W Bezug auf ein Overlay-Ziel bei Krediten („Kreditbetrag bleibt fest“, Spec 00 § 8.2) | Kreditbetrag (Zusage) bzw. fester Zuschussbetrag [S] | Spec 00 8.2 |
| `loan` | map {`repayment`, `payments_per_year`, `variants`, `default_variant`, `term_ranges`, `fees`, `prepay_allowed`, `followup`, `max_share_of_eligible_costs`} | – | (B) | bedingt (Kredite) | E Laufzeit außerhalb `term_ranges`; E `basis.max_share_of_eligible_costs` (falscher Ort, Vorschlag `loan.max_share_of_eligible_costs`, N-11) | Kreditkonditionen [L]; `loan.max_share_of_eligible_costs` (share, Default 1) ist der Höchstanteil des Kredits an den förderfähigen Kosten (4.6) | 02 §5.8 |
| `loan_variant` | chr | – | (B) `loan.default_variant` | nein | E unbekannte Variante | gewählte Konditionenvariante [S] | – |
| `repayment_grant` | map {`base_rates` {ee, nh}, `bonuses` id → {rate, condition}, `cap_per_unit_basis_eur`, `max_total_share`, `payout`, `effect`} | – | (B) | bedingt (`loan_with_repayment_grant`) | – | Tilgungszuschuss [L] | 02 §5.3 |
| `repayment_grant.class` | enum `ee`, `nh` | – | (A) `nh`, wenn `facts.nh_class`; sonst `ee` | nein | W weder `facts.ee_class` noch `facts.nh_class` bei `eligibility.conditions.ee_or_nh_class: required` | Basissatz der EE- bzw. NH-Klasse [S] | – |
| `repayment_grant.cut_share` | value (share) | – | 0 (Spec 00 § 8.2) | nein | E > 1 | Kürzung bzw. Rückforderung bei verfehltem Nachweis, stochastisch zulässig (Teil C `repayment_grant_cut`, B12) [S] | Konzept B12 |
| `construction_supervision` | map {`repayment_grant_share`, `cap_efh_eur`, `cap_mfh_per_unit_eur`, `cap_mfh_total_eur`} | – | (B) | nein | – | Baubegleitung als Teil der Zusage [L] | 02 §5.3 |
| `construction_support_eur` | value | EUR | 0 | nein | W über dem Deckel („gekappt“) | Kosten der Baubegleitung, die der Kredit mitfinanziert [S] | 07 S1 |
| `interest_subsidy` | map {`subsidized_amount_eur` value, `rate_reduction_pa` value, `years` int, `start_event` timing} | – | (B)/(S); `start_event` = früheste Fertigstellung (R-110) | bedingt (`interest_subsidy`) | E fehlt | Zinsverbilligung als laufender Zuschuss [L/S] | 02 §5.8 |
| `rent_binding` | map {`rent_eur_m2_month` value, `increase_pa` value, `years` int} | – | (B)/(S) | bedingt (`rent_binding`) | E fehlt | Mietbindung (1.6 Nr. 6) [L/S] | 02 §5.7 |
| `rent_law` | map {`grant_counts_as`, `loan_counts_as`, `enables`, `reference_rate_pa`} | – | (B); sonst `grant_counts_as: zuschuss_559a_abs1`, `loan_counts_as: zinsverbilligung_559a_abs2`, `reference_rate_pa: {ref: market.mortgage_rate}` | nein | – | mietrechtliche Wirkung (4.10) [L/S] | Konzept F14 |
| `cumulation` | map {`exclusive_with`, `combinable_with`, `requires`, `max_total_share`} | – | (B) | nein | 4.11 | Kumulierung [L] | 02 §5.8 |
| `budget_risk` | map {`approval_probability`} | – | (B) | nein | – | Haushalts- und Zusagerisiko [L] | Konzept 4.2 |
| `facts` | map Symbol → lgl/num | – | `{}` | nein | E Bedingung verwendet ein fehlendes Symbol (außer Symbolen mit Default nach 4.3.2) | Angaben für Bedingungen: `serial_renovation`, `isfp`, `ee_class`, `nh_class`, `lca_thg` (Lebenszyklusanalyse mit QNG-PLUS-THG-Grenze, Fördervoraussetzung), `qng` (QNG-Zertifikat, nur höhere Deckel), `heating_replaced_fossil_functional`, `heat_pump_origin_eu`, `energy_efficiency_expert`, `contractor_certified` (4.3.2, N-10) [S] | – |
| `credit` | map {`total_share`, `schedule_shares`, `cap_per_object_eur`, `energy_advice_share`, `capped_by_expected_income_tax`} | – | (B) | bedingt (`tax_credit`) | – | § 35c EStG (4.8) [L] | 02 §5.7 |
| `energy_advice_cost_eur` | value | EUR | 0 | nein | – | Kosten des Energieberaters (§ 35c Abs. 1 S. 4) [S] | 02 §5.7 |
| `prior_credit_used_eur` | value | EUR | 0 | nein | E > `credit.cap_per_object_eur` | für dasselbe Objekt bereits genutzte Steuerermäßigung [S] | – |

### 4.3 Berechtigung, Bedingungen, Degression

#### 4.3.1 Berechtigung (`eligibility`)

Der Expander prüft die automatisch prüfbaren Bedingungen deterministisch zum `application_date`. Ist eine verletzt
und `eligibility_override = false`, folgt W „nicht berechtigt (<Bedingung>)“, das Instrument erzeugt **keine**
Bausteine, und der Berechtigungs-Check des Berichts (Konzept § 5.5) führt den Grund. Unbekannte Schlüssel in
`conditions` sind kein Fehler; sie erscheinen als offene Prüfpunkte im Berechtigungs-Check (I).

| Schlüssel | Prüfung |
|---|---|
| `applicants` | `applicant` ∈ Liste; **Oberbegriff:** `privatperson_vermieter` erfüllt auch einen Listeneintrag `privatperson` (Privatpersonen einschließlich vermieteter Wohnungen, Memo 02 § 5.1–5.3, Memo 07 § 1; F-02). Programme nur für Selbstnutzer schließen Vermieter über `conditions.owner_occupied: required` aus, Boni nur für Selbstnutzer über `unit.owner_occupied` in der Bausteinbedingung |
| `project_types` | `project.project_type` ∈ Liste |
| `measure_types` | `measures.<m>.measure_type` ∈ Liste für alle m (sonst Maßnahme nicht förderfähig: E). Die Listen der Nutzlast enthalten nur Codes aus `inst/vocab/measure_types.yaml` (37 Codes, Teil A § 4.2; N-01, R-89; geprüft in `test-library.R`) |
| `conditions.owner_occupied: required` | Symbol `unit.owner_occupied` = 1 |
| `conditions.taxable_income_max_eur` | Zahl: `household.taxable_income_avg_eur` ≤ Wert; Map `{base, per_additional_child}`: ≤ base + per_additional_child · max(`n_children_u18` − 1, 0) |
| `conditions.children_u18_min` | `household.n_children_u18` ≥ Wert |
| `conditions.efficiency_standard` | `building.efficiency_standard_after` = Wert (Feld fehlt bzw. `none`: W „nicht berechtigt (Effizienzhausstandard nicht angegeben)“) |
| `conditions.ee_or_nh_class: required` | `facts.ee_class` oder `facts.nh_class` |
| `conditions.lca_thg: required` | `facts.lca_thg` (Lebenszyklusanalyse mit Einhaltung der THG-Grenze nach QNG-PLUS; Fördervoraussetzung der Neubauförderung). Ersetzt den früheren Schlüssel `lca_qng_plus_thg` (N-10); `facts.qng` (QNG-Zertifikat) erfüllt die Bedingung nicht allein, sondern schaltet nur die höheren Deckel frei (4.4) |
| `conditions.fossil_or_biomass_heating: excluded`, `oil_gas_heating: excluded` | kein Träger der Klassen `gas`, `oil`, `lpg` (bzw. zusätzlich `biomass`) im Zustand nach der Maßnahme |
| `conditions.building_age_min_years` | Jahr(`application_date`) − `building.construction_year` ≥ Wert |
| `conditions.min_investment_eur` | Basisfallkosten der Maßnahmen ≥ Wert (W statt E, weil wertabhängig) |
| `conditions.energy_class_at_application` | `building.energy_class_before` ∈ Liste |
| `conditions.completion_before` | wird je Lauf im Typ geprüft (4.8) |
| `conditions.requires_beg_em_commitment_months` | ein Instrument aus `cumulation.requires` mit `application_date` höchstens so viele Monate vor diesem (W) |
| `conditions.energy_efficiency_expert`, `contractor_certified: required` | `facts.<schlüssel>` (fehlt: I „bitte bestätigen“) |
| `exclusions` | Text; immer als Prüfpunkt im Bericht (I) |

#### 4.3.2 Bedingungsausdrücke und Symbole

Bedingungen (`rate_components.<id>.condition`, `repayment_grant.bonuses.<id>.condition`,
`rate_cap.exceptions[].condition`) sind Ausdrücke der Grammatik von Spec 00 § 4.5 Regel 5 mit Ergebnis 0/1. Sie
dürfen nur **deterministische** Symbole enthalten (Spec 00 § 4.12 Nr. 5); ein Symbol auf ein `value`-Feld ist E.
Nicht-numerische Symbole (Codes, Flags) sind nach R-91 nur in `==`, `!=`, `%in%`, `!`, `&`, `|` zulässig, z. B.
`building.efficiency_standard_after == 'eh40'`. Der Expander wertet sie mit der internen Funktion
`fund_eval_condition()` aus und ersetzt zuvor die reservierten Symbole:

| Symbol | Bedeutung |
|---|---|
| `building.<feld>` | deterministische Gebäudefelder (`wpb_flag`, `denkmal`, `construction_year`, `n_units`; Codes mit `==`) |
| `funding.this.<fakt>` | `funding.<f>.facts.<fakt>`; Defaults: `isfp` = `building.isfp_available`, `serial_renovation` = `building.serial_renovation`, `ee_class`/`nh_class`/`lca_thg`/`qng` = `false` |
| `unit.owner_occupied` | 1, wenn alle Gruppen in `funding.<f>.unit_groups` selbstgenutzt sind (bzw. Perspektive `selbstnutzer` ohne Gruppen; nach `rule:unit_group_defaults` gibt es dann die Gruppe `main`) |
| `heating.replaced_fossil_functional` | 1, wenn der Zustand `before` einen Wärmeträger der Klasse `oil`, `coal` oder `power` (Nachtspeicher, Direktheizung) hat, einen der Klasse `gas` mit `building.heating_existing.type = floor` (Gasetagenheizung, unabhängig vom Alter) oder einen der Klassen `gas`/`biomass` mit Alter ≥ `rate_components.<id>.min_age_gas_biomass_years` zum Antragsdatum (Alter = Jahr(`application_date`) − Jahr(`before.installation_date`)); `facts.heating_replaced_fossil_functional` überschreibt (Memo 07 § 1: Öl, Kohle, Nachtspeicher, Gasetage; F-18) |
| `taxable_income_adj` | `household.taxable_income_avg_eur` − `child_u18_threshold_shift_eur` · min(`household.n_children_u18`, 1): Verschiebung der Einkommensschwellen **einmal** bei mindestens einem kindergeldberechtigten Kind unter 18 (Memo 02 § 5.2 „Grenzen pauschal +10.000 EUR“, Memo 07 § 1; F-01). Mit `schedule_by_taxable_income.child_u18_threshold_shift_per_child: true` (lgl, Default `false`) je Kind |
| `application_year` | Jahr(`application_date`) |

Ein Satzbaustein ohne `condition` ist immer aktiv. Ein Baustein mit `~` (YAML null) in der Nutzlast entfällt (Kette
`from:`, z. B. KfW 459 ohne Einkommensbonus).

#### 4.3.3 Degression und Einkommensstaffel

```text
Degression je Eintrag {target, start, step, every_months, floor}:
   k = 0, falls application_date < start;  sonst k = 1 + floor(Monate(application_date − start) / every_months)
   Wert = pmax(Wert₀ + k · step, floor)   (step < 0)  bzw.  pmin(Wert₀ + k · step, floor)  (step > 0)
Einkommensstaffel {thresholds_eur [t₁ < … < t_J], rates [r₁ … r_{J+1}]}:
   i = 1 + Σ_j 1{taxable_income_adj > t_j};  Satz = r_i            (Schwellen einschließlich: x ≤ t₁ → r₁)
```

`target` ist ein Pfad in der Nutzlast; ein Index `[i]` (1-basiert) adressiert ein Element einer Staffeltabelle.
Existiert das Ziel nicht, ist das E; **Ausnahme (X-02, F-04):** Liegt das Ziel in einem Baustein, den die
`from:`-Kette des Instruments mit `~` entfernt hat (z. B. `rate_components.klimageschwindigkeit` in KfW 459), entfällt
der Degressionseintrag mit I („Degression auf entfernten Baustein ignoriert“). Teil C ersetzt die Sequenz in KfW 459
zusätzlich vollständig.
Zielt die Degression auf ein Map-Blatt (z. B. `rate_components.klimageschwindigkeit.rate`), schreibt der Expander
einen Ausdruck mit Bezug (`{expr: "pmax(funding.<f>.rate_components.klimageschwindigkeit.rate - 0.16, 0)"}`); Werte in
Sequenzen (Staffeltabellen, Degressionsstufen, Einkommensstaffel) sind deterministische Tabellenwerte und gehen als
Konstanten ein (Spec 00 § 4.4 Nr. 3: Sequenzen werden nicht elementweise adressiert; S01B-04 entschieden mit
Änderung, Spec 00 § 4.12 Nr. 5 (b), R-92).

Prüfwerte (Teil C, KfW 458): Antrag 2027-02-01 → k = 1: Klimageschwindigkeitsbonus 0,12, förderfähig 1. WE 27.250;
2028-08-01 → k = 4: 0,00 und 25.000; 2030-08-01 → k = 8: 22.000 (Untergrenze).

### 4.4 Bemessungsgrundlage und Höchstbeträge

```text
N_f     = Σ n_units der Gruppen in funding.<f>.unit_groups (Default building.n_units)
K_m     = −Σ_t Σ capex-Zeilen mit measure_id = m (realisiert, brutto, inkl. Preisindex, Verschiebung und a_m)
K^e_m   = e_m · K_m      (e_m = eligible_shares.m);   bei eligible_cost_eur: K^e = eligible_cost_eur · max_m a_m
Deckel (deterministisch aus der Nutzlast, Konstante je Instrument und Gruppe):
  eligible_cost_caps_per_building / _per_unit_per_calendar_year (Staffel {units_from, units_to, cap_eur[, cap_isfp_eur]}):
        cap = Σ_{u=1..N_f} cap_eur(u)   (Stufe der u-ten WE; mit facts.isfp: cap_isfp_eur)
  cap_efh_eur / cap_mfh_per_unit_eur / cap_mfh_total_eur:
        cap = cap_efh_eur bei N_f = 1, sonst min(cap_mfh_per_unit_eur · N_f, cap_mfh_total_eur)
  loan_cap_per_unit_eur [_qng_eur bei facts.qng]: Kreditdeckel = Wert · N_f
  loan_cap_by_children_eur: Stufe nach household.n_children_u18 (cap bzw. cap_qng bei facts.qng)
  (facts.qng wirkt nur auf die Deckel; die Berechtigung prüft facts.lca_thg, 4.3.1, N-10)
cap_period = calendar_year: Deckelgruppen γ nach dem Kalenderjahr der Fertigstellung (ohne Verschiebung,
             deterministisch); sonst eine Gruppe
```

Prüfwerte: S3 (12 WE, KfW 459): 28.000 + 5 · 15.000 + 6 · 8.000 = 151.000; EFH BAFA Hülle: 30.000 bzw. 60.000 mit
iSFP; Baubegleitung KfW 261 bei 24 WE: min(4.000 · 24, 40.000) = 40.000. `distribution: equal_per_unit` (gleichmäßige
Verteilung auf die WE) ändert die Summe für das Gebäude nicht (I).

### 4.5 Typ `grant` (WS-E2, `R/type-flow-grant.R`)

Art `flow`, `grid_invariant = TRUE` (Einmalzahlungen mit Datumstermin nach R-98, 0.4).

| Parameter | Art | Default (T) | Belegung durch den Expander | Bedeutung |
|---|---|---|---|---|
| `measures` | `ids` | `[]` | `funding.<f>.measures` | Maßnahmen (Zeilen `grant_<m>`) |
| `cost_components` | `ids` | `[]` | capex-Komponenten der Maßnahmen (auch in `after`) | Kosten K_m |
| `eligible_cost_eur` | `value` | `null` | ref | feste Bemessung |
| `rate` | `value` | Pflicht | Ausdruck: Σ aktiver Satzbausteine (mit Degression und Einkommensstaffel) | r |
| `rate_cap` | `value` | 1 | ref bzw. Ausdruck (Ausnahme nach Bedingung) | r_cap |
| `bonus_rate` | `value` | 0 | Satzbaustein mit `threshold` (z. B. iSFP) | r_b |
| `bonus_threshold_eur` | `amount` | 0 | `threshold.single_unit_eur` bei N_f = 1, sonst `cap_without_bonus` (Deckel ohne Bonus) | Schwelle |
| `bonus_mode` | `enum` `excess_over_threshold`, `whole_amount` | `excess_over_threshold` | `threshold`-Baustein `mode` | Bonusbasis |
| `cost_cap_eur` | `amount` | `.inf` | Deckel nach 4.4 (je Gruppe) | cap |
| `cap_period` | `enum` vocab:cap_period | `total` | `basis.cap_period` | Deckelgruppen γ: eine Gruppe bzw. je Kalenderjahr der Fertigstellung (deterministisch, ohne Verschiebung) |
| `amount_eur` | `value` | `null` | `{ref: funding.<f>.amount_eur}`, falls gesetzt | fester Zuschuss |
| `approved` | `value` | 1 | `{ref: funding.<f>.approved}` | Zusage je Lauf |
| `payout_event` | `enum` vocab:payout_event | `completion_proof` | `payout.event` | Auszahlungsereignis |
| `payout_lag_months` | `integer` | 0 | `payout.lag_months` | Regelverzug |
| `payout_delay_months` | `number` | 0 | `{ref: funding.<f>.payout_delay_months}` | Verzug je Lauf (3.9) |
| `application_date` | `date` | `valuation_date` | `funding.<f>.application_date` | Ereignis `commitment` |

**Algorithmus.**

```text
K_m, K^e_m nach 4.4 mit e_m = ctx$value("funding.<funding_id>.eligible_shares.<m>") (Domänenlesezugriff 0.5;
fehlt der Pfad: 1);  a_m <- act(ctx, m);  funding_id = Metafeld der Komponente
je Gruppe γ:  Kγ  = Σ_{m ∈ γ} K^e_m
              Kffγ = pmin(Kγ, cost_cap_eur)
              Bγ  = excess_over_threshold: pmax(Kffγ − bonus_threshold_eur, 0);  whole_amount: Kffγ
              Gγ  = pmin(rate · Kffγ + bonus_rate · Bγ, rate_cap · Kffγ)
              amount_eur gesetzt: Gγ = amount_eur · (Σ_{m∈γ} K⁰_m · a_m) / Σ_{m} K⁰_m   (K⁰ = Basisfallkosten)
G_m = Gγ · K^e_m / Kγ  (0, falls Kγ = 0);   G_m <- G_m · approved
Auszahlungstermin (R-98, Spec 00 § 3.4 Nr. 3; Datum, nicht Monatsindex):
   completion_proof: Termin_m = add_months(completion_date_m, payout_lag_months + s_m + round(payout_delay_months))
                     p_m      = ctx$shift_period(completion_date_m, payout_lag_months + s_m + round(payout_delay_months))
                     (s_m = round(measures.<m>.delay_months), round = floor(x + 0,5))
   commitment:       p_m      = ctx$shift_period(application_date, payout_lag_months + round(payout_delay_months))
grant_<m> = G_m in der Periode p_m (Termin am Stichtag: t = 0); p_m = NA (Termin nach dem Horizont): nicht gebucht
            (I, Anteil der Läufe)
```

Zuschuss und Tilgungszuschuss (4.6) mit gleicher Ableitung (Fertigstellung + gleiche Frist) fallen damit ohne
laufspezifische Verschiebung in dieselbe Periode (F-07); der Tilgungszuschuss bleibt terminfest (R-47), der Zuschuss
verschiebt sich mit `delay_months` und `payout_delay_months`.

| lokale Zeile | section | category | tax_category | cash | `measure_id` | VZ |
|---|---|---|---|:---:|---|:---:|
| `grant_*` (je m ∈ `measures`) | grants | `grant` | `subsidy_investment` | T | m | + |

`vat_rate = 0`. `aux`: `eligible_cost` (Σ Kγ), `capped_cost` (Σ Kffγ), `rate_effective` (Σ Gγ / Σ Kffγ), `grant_gross`
(Σ Gγ vor `approved`), jeweils in der Spalte der Auszahlung. `example` (Vertragstest): `{type: grant,
measure_id: m1, eligible_cost_eur: 100000, rate: 0.3, cost_cap_eur: 80000, payout_event: commitment,
application_date: 2027-01-01}` → Zeile `grant_m1` +24.000 in t = 0 (Spalte 1; Termin = Stichtag 2027-01-01 der
Prüfraster, R-98, N-13); ohne Parameter `measures` entsteht genau eine Zeile `grant_<measure_id>` aus dem Metafeld
`measure_id` (Spec 00 § 4.3.8).

**Randfälle.** Kγ ≤ 0: Zuschuss 0. Kostensteigerung im Lauf erhöht den Zuschuss bis zum Deckel (Bemessung auf den
realisierten Kosten, Konzept § 3.5). Bei a_m = 0 ist K_m = 0 und damit G_m = 0. Ein Zuschuss vor dem Stichtag
(bereits ausgezahlt) gehört nicht in das Modell (I).

### 4.6 Förderkredite (Expander → `financing.f_<f>_loan`)

| Parameter des Kredittyps (Spec 00 § 8.2) | Belegung |
|---|---|
| `type` | `loan.variants.<v>.repayment` bzw. `loan.repayment`: `annuity` → `annuity_loan`, `installment` → `installment_loan`, `bullet` → `bullet_loan` |
| `amount_eur` | `{ref: funding.<f>.amount_eur}`; ohne `funding.<f>.amount_eur` (A) der Ausdruck `{expr: "pmin((<Σ_m funding.<f>.eligible_shares.m · measures.m.cost_eur>) * funding.<f>.loan.max_share_of_eligible_costs, <Kreditdeckel>) + pmin(funding.<f>.construction_support_eur, <Deckel Baubegleitung>)"}` (Pfad `loan.max_share_of_eligible_costs`, Default 1, N-11; `measures.m.cost_eur` existiert immer, `rule:cost_from_kg`); ausgewertet als **Basisfallwert** (`deterministic_only`, R-69; Ausnahme (a) des Expandertests, R-92) mit W „Kreditbetrag aus Kostenschätzung (Preisstand); bitte Zusagebetrag eintragen“ |
| `approved` | `{expr: "funding.<f>.approved * pmax(<a_m1>, <a_m2>, …)"}` (Kredit entfällt, wenn alle geförderten Maßnahmen entfallen; bei Teilwegfall bleibt der Kreditbetrag fest; `<a_m>` = Ausdruck des Aktivierungsfaktors, 0.8; S01B-11 angenommen, Spec 00 § 4.12 Nr. 7, R-99) |
| `start`, `draw_schedule` | frühester Zahlungstermin der Maßnahmen; Teilauszahlungen nach den Zahlungsplänen der Maßnahmen, gewichtet mit den Basisfallkosten aus `bctx$value_base("measures.<m>.cost_eur")` (`unit: share`, deterministisch; R-92) |
| `rate_pa` | `{ref: funding.<f>.loan.variants.<v>.rate_pa}` |
| `term_years`, `grace_years`, `fixed_years` | Werte der Variante (deterministisch) |
| `payments_per_year` | `loan.payments_per_year` |
| `fees` | `{processing_fee_share, commitment_fee_rate_month, commitment_free_months}` als Bezüge auf `loan.fees.*` |
| `prepay_allowed` | `loan.prepay_allowed` |
| `followup_rate_pa` | `{ref: market.mortgage_rate}` bei `followup: market` |
| `repayment_grant.share` | `{expr: "(t * pmin(funding.<f>.amount_eur - cs, <cap_per_unit_basis_eur · N_f>) + <construction_supervision.repayment_grant_share> * cs) / funding.<f>.amount_eur"}` mit t = pmin(Basissatz der Klasse + Σ aktiver Boni, `max_total_share`) als Bezüge und cs = gekappte Baubegleitung |
| `repayment_grant.date` | Termin `add_months(späteste Fertigstellung der Maßnahmen, repayment_grant.payout.lag_months)` (ohne Verschiebung, deterministisch; Buchung nach R-35 in `grid_period_of(date)`, R-98) |
| `repayment_grant.effect` | `repayment_grant.effect` |
| `repayment_grant.approved` | 1 (die Zusage wirkt über `approved` des Kredits; Spec 00 § 8.3: Gutschrift = share · min(Zusage, abgerufen) · (1 − `cut_share`)) |
| `repayment_grant.cut_share` | `{ref: funding.<f>.repayment_grant.cut_share}` |
| Metafelder | `funding_id = f` (Pflicht-id der Merkzeile `repayment_grant`, Spec 00 § 7.6), `measure_id` = Anzeige-Tag: geförderte Maßnahme mit den größten Basisfallkosten nach `bctx$value_base("measures.<m>.cost_eur")` (Gleichstand: erste id nach `sort(method = "radix")`; S01B-10 entschieden mit Änderung, R-99, R-92), `program = program_code` |

Wird die Zusage im Lauf versagt (`approved = 0`), entfallen Auszahlungen und Tilgungszuschuss; die Lücke deckt der
Ausgleich bzw. `topup` (Spec 00 § 8.7), bei `on_reject: drop_measures` entfallen die Maßnahmen (0.8).

### 4.7 Zinsverbilligung (`interest_subsidy` → `f_<f>_subsidy`)

Typ `recurring` (Spec 00 § 7.12): `amount_eur` = `{expr: "funding.<f>.interest_subsidy.subsidized_amount_eur *
funding.<f>.interest_subsidy.rate_reduction_pa * funding.<f>.approved * <a>"}` (a = pmax der Aktivierungsfaktoren),
`growth` 0, `start_event` = `interest_subsidy.start_event`, `to` = `start_event` + `years`, `category: operating_subsidy` (Abschnitt
`grants`, `tax_category: subsidy_operating`). Die Annahme eines konstanten verbilligten Betrags ist eine Näherung; ein
tilgungsabhängiger Verlauf braucht `custom_series` (I).

### 4.8 Typ `tax_credit_35c` (WS-E2, `R/type-flow-tax-credit-35c.R`)

§ 35c EStG ist `instrument_type: tax_credit` (Spec 00 R-11, § 10.9). Art `flow`.

| Parameter | Art | Default (T) | Belegung | Bedeutung |
|---|---|---|---|---|
| `measures`, `cost_components` | `ids` | `[]` | wie `grant` | Aufwendungen |
| `eligible_cost_eur` | `value` | `null` | ref | feste Aufwendungen |
| `share_y1`, `share_y2`, `share_y3` | `share` | 0,07; 0,07; 0,06 | `credit.schedule_shares` (Sequenz, Konstanten) | Tranchen |
| `total_share` | `share` | 0,20 | `{ref: funding.<f>.credit.total_share}` | Gesamtsatz |
| `cap_total_eur` | `amount` | 40.000 | `{ref: funding.<f>.credit.cap_per_object_eur}` | Höchstbetrag je Objekt |
| `energy_advice_cost_eur`, `energy_advice_share` | `value`, `share` | 0; 0,50 | ref | Energieberatung |
| `prior_used_eur` | `value` | 0 | `{ref: funding.<f>.prior_credit_used_eur}` | bereits genutzt |
| `income_tax_cap_eur_pa` | `value` (path) | `null` | `{ref: household.expected_income_tax_eur_pa}`, wenn `credit.capped_by_expected_income_tax` | Deckel je Veranlagungsjahr (R-79) |
| `completion_before` | `date` | 2030-01-01 | `eligibility.conditions.completion_before` | Abschlussfrist |
| `approved` | `value` | 1 | ref | |
| `payout_delay_months` | `number` | 12 | `{ref: funding.<f>.payout_delay_months}` (Domänendefault 12 über `rule:tax_credit_defaults`, 5.5) | Zahlung nach Ende des Veranlagungsjahres |

```text
K     <- Σ_m K_m (realisiert, inkl. a_m) bzw. eligible_cost_eur · max_m a_m
dc    <- max_m add_months(completion_date_m, s_m)   (Abschlussdatum je Lauf; s_m = round(delay_months_m))
Y₀    <- Jahr(dc);  Y₀⁰ <- dasselbe ohne Verschiebung;  ok <- dc < completion_before
cap_i <- share_i · cap_total_eur / total_share          # 14.000; 14.000; 12.000
rem   <- pmax(cap_total_eur − prior_used_eur, 0)
für i = 1, 2, 3 (Veranlagungsjahr Y_i = Y₀ + i − 1):
   x_i <- pmin(share_i · K, cap_i) + [i = 1] · energy_advice_share · energy_advice_cost_eur
          (Energieberatung außerhalb des Jahresdeckels, innerhalb des Gesamtdeckels; Spec 00 § 10.9, R-98)
   x_i <- pmin(x_i, ESt_{Y_i}), falls income_tax_cap_eur_pa gesetzt (Kalenderjahreswert, 0.4); nicht nutzbare Beträge verfallen
   x_i <- pmin(x_i, rem);  rem <- rem − x_i;   x_i <- x_i · ok · approved
   Termin (R-98, S01B-12 angenommen): add_months((Y_i + 1)-01-01, payout_delay_months), Buchung in
          grid_period_of(Termin); laufspezifisch p_i = ctx$shift_period((Y₀⁰ + i)-01-01,
          12 · (Y₀ − Y₀⁰) + round(payout_delay_months)); Default 12 → Termin (Y_i + 2)-01-01, d. h. Periode des
          Kalenderjahres Y_i + 1 auf dem Jahresraster; Termin nach dem Horizont (NA): nicht gebucht (I)
credit_<m> = Σ_i x_i (in der Periode p_i) · K_m / K
```

| lokale Zeile | section | category | tax_category | cash | `measure_id` | VZ |
|---|---|---|---|:---:|---|:---:|
| `credit_*` (je m) | grants | `tax_credit` | `tax_credit` | T | m | + |

`aux`: `tranche_1`…`tranche_3` (vor Steuerdeckel), `capped_by_tax` (0/1). **Validierung:** Perspektive ≠
`selbstnutzer` bzw. Gruppen nicht selbstgenutzt (E); Gebäudealter < 10 Jahre bei Beginn (E,
`eligibility.conditions.building_age_min_years`); dieselbe Maßnahme in einem BEG- bzw. KfW-Instrument (E,
`cumulation.exclusive_with` geprüft gegen die ganze `from:`-Kette und `program_code`, 4.11, Spec 00 § 10.9, N-12);
`ok = 0` in einem Teil der Läufe (W mit Anteil, z. B. wegen
Bauzeitverzug); Deckelung durch `expected_income_tax_eur_pa` bzw. fehlendes Feld (W, R-79). Steuermodule ignorieren
`tax_credit`-Zeilen (Spec 00 § 10.9).

### 4.9 Zusage, Entscheidungsknoten und Ausfall (Spec 00 § 9.11, R-71)

1. **Zeitpunkt.** Die Ableitungsregel `rule:approval_timing` (WS-A, 5.5) löst `auto` bzw. ein fehlendes Feld vor den
   Expandern auf: `before_start`, wenn `application_date` ≤ frühester Termin (`date`, `year` als 1. Januar bzw.
   erster Termin von `payment_schedule`, ohne Verschiebung) der Maßnahmen des Instruments, sonst `after_start`; ein
   Instrument ohne Maßnahmen (z. B. `rent_binding`) bezieht sich auf den frühesten Termin aller Maßnahmen der Variante,
   ohne Maßnahmen gilt `before_start` (Spec 00 § 4.3.7, R-111; S01B-14 angenommen). Der
   Expander, die Validierung (WS-B), `smp_plan()` (WS-C) und `vofi_build()` (WS-D) lesen nur den aufgelösten Code
   (Spec 00 § 4.3.7, R-86, N-07); eine Registry-Regel `fund_approval_timing` gibt es nicht.
2. **Entscheidungsknoten.** `before_start` und `fallback_variant` gesetzt: Der Expander validiert die Bedingungen von
   Spec 00 § 9.11 Nr. 1 (höchstens ein Knoten je Variante, Ausweichvariante ohne f und ohne eigenen Knoten) und
   schreibt nichts Zusätzliches; `vofi_build()` (WS-D, `R/engine-build.R`) erkennt den Knoten am Domänenblatt und
   baut die Ausweichvariante, WS-C gibt dem Zusageschlüssel die Rolle `decision`. In der Variante selbst ist
   `approved` = 1.
3. **Einfache Ziehung** (ohne Knoten, z. B. spätere Stufen, Verfügbarkeit nach 2030): `approved` wirkt im selben
   Modell; `on_reject: balance` → Beträge × `approved` (Zuschuss, Kredit, Tilgungszuschuss, Zinsverbilligung,
   § 35c); `on_reject: drop_measures` → zusätzlich a_m = 0 für die geförderten Maßnahmen (0.8; Kosten, Zustand
   „nachher“, Umlage, Instandhaltung entfallen).
4. **Rechtsfolgen je Lauf** (Spec 00 § 9.11 Nr. 6): `rent_path` rechnet mit der gewährten Förderung (§ 559 statt
   § 559e, kein Abzug nach § 559a, keine Kürzung nach § 558 Abs. 5), weil G_k, TZ_k und Zint_k `approved` enthalten.
5. **Restrisiken nach Zusage** (Konzept B12): `repayment_grant.cut_share` (4.6) und `payout_delay_months` (4.5,
   4.8); Voreinstellung 0 (§ 35c: Zahlungsverzug 12 über `rule:tax_credit_defaults`).
6. **Szenario-Set `foerderstopp`** (Label „Förderstopp: keine Förderzusage“ nach Teil C § 4.2, N-22; `set:
   {funding.*.approved: 0}`, Spec 00 § 4.11): Knoten nehmen den Zweig der Ausweichvariante, alle übrigen Instrumente
   fallen nach Nr. 3 aus.

### 4.10 Mietrechtliche Wirkung

| Feld | Code | Wirkung im Mietpfad |
|---|---|---|
| `rent_law.grant_counts_as` | `zuschuss_559a_abs1` (Default) | G_k mindert die umlagefähigen Kosten (§ 559a Abs. 1) und begründet Kürzungsbeträge nach § 558 Abs. 5 (8 % p. a. für `kuerzung_grant_years`) |
| | `none` | keine Wirkung (z. B. Neubau, Selbstnutzung) |
| `rent_law.loan_counts_as` | `zinsverbilligung_559a_abs2` (Default) | Zinsermäßigung Zint_k mindert den Jahresbetrag (§ 559a Abs. 2); Tilgungszuschuss gilt als Zuschuss (`mietrecht.s559a.repayment_grant_as_grant`) |
| | `none` | keine Wirkung |
| `rent_law.enables` | `[bgb_559e]` | Information: das Instrument ist Drittmittel im Sinne des § 559e (Verfahrenswahl 1.9.2 prüft je Lauf, ob Drittmittel gewährt sind) |
| `rent_law.reference_rate_pa` | value | Marktzins für die Zinsermäßigung (Teil C `s559a.market_rate_reference: first_mortgage_at_completion`), Default `{ref: market.mortgage_rate}` in der Periode der Fertigstellung |

Mietbindung (`rent_binding`) siehe 1.6 Nr. 6; Genossenschaft und PV-Verrechnung siehe 1.11.

### 4.11 Kumulierung

- `cumulation.exclusive_with` (Bibliotheks-ids; N-12, X-18, F-20): Ein Eintrag x der Liste von f trifft ein anderes
  Instrument g der Variante, wenn x in der **ganzen `from:`-Kette** von g liegt (z. B. `funding/kfw_261_eh70` →
  `funding/kfw_261_wg_kredit_2026`, `funding/kfw_459_heizung_unternehmen` → `funding/kfw_458_heizung_privat`) oder
  wenn der `program_code` des Eintrags x (`bctx$lib(x)`) gleich dem `program_code` von g ist (auch bei Instrumenten
  ohne `from`). Die Prüfung läuft in beide Richtungen (Liste von f gegen g und Liste von g gegen f). Fördern f und g
  eine gemeinsame Maßnahme, ist das E (insbesondere § 35c mit BEG einschließlich der Ergänzungskredite KfW 358/359,
  Spec 00 § 10.9; die Liste von `funding/estg_35c` ergänzt Teil C).
- `cumulation.requires`: Fehlt jedes Instrument der Liste in der Variante, folgt W („Ergänzungskredit setzt eine
  BEG-Zusage voraus“).
- `cumulation.max_total_share` (falls gesetzt): W, wenn im Basisfall Σ Zuschüsse und Tilgungszuschüsse einer
  Maßnahme den Anteil der Kosten übersteigen; ohne Angabe W, wenn sie die Kosten übersteigen.
- Instrumente mit gleichem `program_code` und Jahresdeckel (`cap_period: calendar_year`) in derselben Variante: W
  („Jahresdeckel gemeinsam; Maßnahmen in einem Instrument führen“).

### 4.12 Testfälle Förderung

Gemeinsame Annahmen wie 1.15; Nutzlasten aus Teil C § 3.4. Termine nach R-98 (0.4): Auszahlungen sind Datumstermine,
gebucht in `grid_period_of(Termin)`; auf dem Jahresraster ab 2027-01-01 gehört der Termin `(Y+1)-01-01` zur Periode Y.
Testdateien (N-18): `test-type-flow-grant.R`, `test-type-flow-tax-credit-35c.R`, `test-expand-funding.R`,
`test-rules-funding.R` (WS-E2); F-9 und F-15 (Ableitungsregeln) zusätzlich `test-scenario-layers.R` (WS-A).

| Nr. | Eingabe | Erwartung |
|---|---|---|
| F-1 (S3-T1/T2, KfW 459) | 12 WE, Wärmepumpe K = 153.560 (brutto), Grundsatz 0,30, Höchstsatz 0,30, Fertigstellung 2027-10-01, `payout.lag_months` 3 | Deckel 151.000; Termin 2028-01-01 → `grant_<m>` +45.300,00 in t = 1 (Periode 2027; N-13) |
| F-2 (Memo 02 Bsp. 6, KfW 458) | EFH, Wärmepumpe 32.000, zvE 45.000, keine Kinder, Ölkessel, Antrag 2026-12-01 | Sätze 0,30 + 0,16 + 0,10 = 0,56 ≤ 0,70; 0,56 · 28.000 = 15.680,00 |
| F-2a (Kinder, F-01) | F-2 mit zvE 58.000 und 2 Kindern unter 18 | `taxable_income_adj` = 58.000 − 10.000 · min(2, 1) = 48.000 → Einkommensbonus 0,10; 0,56 · 28.000 = 15.680,00. Mit `child_u18_threshold_shift_per_child: true`: 38.000 → 0,30; Summe 0,76 > Höchstsatz 0,70 (Ausnahme 0,80 erst bei ≤ 30.000) → 0,70 · 28.000 = 19.600,00 |
| F-3 (S4-T1/T8) | zvE 58.000, 1 Kind, Gaskessel Einbau 2008 (Alter 18 zum Antrag 2026) | `taxable_income_adj` 48.000 → 0,10; kein Klimageschwindigkeitsbonus; 0,40 · 28.000 = 11.200,00 |
| F-4 (Degression) | F-2 mit Antrag 2027-02-01 / 2028-08-01 / 2030-08-01 (zvE 45.000) | 0,52 · 27.250 = 14.170,00 / 0,40 · 25.000 = 10.000,00 / 0,40 · 22.000 = 8.800,00 |
| F-4a (Degression auf entfernten Baustein, X-02) | KfW 459 (Kette auf KfW 458, `klimageschwindigkeit: ~`) mit geerbter Degression, Antrag 2027-02-01, 12 WE | Eintrag auf `rate_components.klimageschwindigkeit.rate` entfällt mit I, kein E; Höchstkosten 1. WE 27.250 → Deckel 27.250 + 5 · 15.000 + 6 · 8.000 = 150.250 |
| F-5 (Höchstsatz-Ausnahme) | F-2 mit zvE 28.000 | Sätze 0,86 → Ausnahme 0,80 (`unit.owner_occupied & taxable_income_adj <= 30000`): 22.400,00 |
| F-6 (S4-T4, BAFA Hülle, iSFP) | EFH, 2030: K = 85.988,87; 2033: K = 55.405,82 | 2030: 0,15 · 60.000 + 0,05 · 30.000 = 10.500,00 (`whole_amount` 12.000,00; ohne iSFP 4.500,00); 2033: 0,15 · 55.405,82 + 0,05 · 25.405,82 = 9.581,16 (`whole_amount` 11.081,16); Memo 02: Fassade 40.000 → 6.500,00 |
| F-6a (Jahresdeckel) | EFH, iSFP, Fassade 40.000 und Fenster 30.000 in einem Instrument | beide 2028 fertig: Gruppe 70.000 → 60.000 → 10.500,00, `grant_fassade` 6.000,00, `grant_fenster` 4.500,00; Fenster 2029 fertig: 6.500,00 und 4.500,00 |
| F-6b (Antragsteller, F-02) | KfW 458 (`applicants: [privatperson, weg]`), Perspektive `kleinvermieter` (`applicant` = `privatperson_vermieter`), vermietete Gruppe, Wärmepumpe 32.000, Ölkessel | berechtigt (Oberbegriff `privatperson`); nur Grundförderung 0,30 (Boni verlangen `unit.owner_occupied`) → 0,30 · 28.000 = 8.400,00; KfW 297 (`owner_occupied: required`): W „nicht berechtigt“ |
| F-7 (S1-T3, KfW 261 EH 70 EE + WPB) | 24 WE, Kredit investiv 1.264.000 + Baubegleitung 36.000 (Deckel 40.000), Basissatz `ee` 0,00, Bonus WPB 0,10, Fertigstellung 2027-10-01, `repayment_grant.payout.lag_months` 3 (wie S1) | `amount_eur` 1.300.000; `repayment_grant.share` 0,1110769; Gutschrift 144.400,00 zum Termin 2028-01-01 → t = 1 (Periode 2027), dieselbe Periode wie F-1; mit dem Bibliothekswert `lag_months` 6: Termin 2028-04-01 → Periode 2028; `approved` 0: keine Auszahlung, keine Gutschrift; `cut_share` 0,5: 72.200,00 |
| F-8 (§ 35c) | Fertigstellung 2028-06-01, `payout_delay_months` 12 (Default aus `rule:tax_credit_defaults`) | Termine 2030-01-01 / 2031-01-01 / 2032-01-01 → Perioden 2029 / 2030 / 2031 (t = 3, 4, 5). K 80.000: 5.600 / 5.600 / 4.800; K 250.000: 14.000 / 14.000 / 12.000; mit `expected_income_tax_eur_pa` 4.000: 4.000 / 4.000 / 4.000 (W); Energieberatung 2.000 (K 80.000): 6.600 / 5.600 / 4.800; `prior_credit_used_eur` 30.000 (K 250.000): 10.000 / 0 / 0; Fertigstellung durch Verzug 2030-02-01: 0 (W) |
| F-9 (Zeitpunkt, Knoten) | Antrag 2026-11-01, erster Maßnahmentermin des Instruments 2027-03-01, `fallback_variant: ohne_foerderung` | `rule:approval_timing` → `before_start` (Herkunft `rule:approval_timing`), Entscheidungsknoten; Basisfall Zweig 1; Set `foerderstopp`: Zweig 0 (Ergebnis der Ausweichvariante); Antrag 2027-06-01: `after_start` und W (`application_before_start`); Stufensanierung (S4): Instrument einer späteren Stufe mit Antrag vor deren erstem Termin → `before_start`, auch wenn frühere Maßnahmen der Variante vorher beginnen (S4 V1 `bafa_2030`, `kfw358_2030`, `kfw358_2033`: `before_start`, keine W); ausdrückliches `after_start` mit Antrag vor dem Termin (S4 `bafa_2033`): einfache Ziehung, keine W; Instrument `rent_binding` ohne Maßnahmen, Antrag 2027-06-01, früheste Maßnahme der Variante 2027-03-01: `after_start`; Variante ohne Maßnahmen: `before_start`; Antrag 2027-01-15 nach dem Termin 2027-01-01 einer Maßnahme mit `year: 2027` und ausdrücklichem `before_start` (S3 V2): keine W (R-111) |
| F-10 (`drop_measures`) | einfache Ziehung, `approved` = (1, 0) in zwei Läufen | Lauf 2: a_m = 0 → `grant_<m>` 0, Zustand `after` inaktiv (E-10), `levy_<m>` 0 (RP-15), Kosten 0 (Teil A) |
| F-11 (`balance`) | wie F-10 mit `on_reject: balance` | Lauf 2: Zuschuss 0, Kosten unverändert, Umlage nach § 559 (RP-12) |
| F-12 (Kumulierung) | § 35c und KfW 458 für dieselbe Maßnahme; § 35c und `funding/kfw_261_eh70` (Kette auf `kfw_261_wg_kredit_2026`); § 35c und ein Instrument ohne `from` mit `program_code: "458"`; KfW 358 ohne 458 bzw. BAFA | E; E (`from:`-Kette, N-12); E (`program_code`); W |
| F-13 (Berechtigung KfW 300, N-10) | zvE 105.000, 2 Kinder (Grenze 100.000) / zvE 85.000 mit `facts: {lca_thg: true}` / zvE 85.000 mit `facts: {lca_thg: true, qng: true}` / zvE 85.000 ohne `facts` | W „nicht berechtigt“, kein Baustein / berechtigt, Kreditdeckel 170.000 (S5 V2) / berechtigt, Kreditdeckel 220.000 / W „nicht berechtigt (lca_thg)“ |
| F-14 (Zinsverbilligung) | verbilligt 100.000, 1,0 Prozentpunkte, 10 Jahre ab 2028-01-01 | `f_<f>_subsidy__value` +1.000,00 je Jahr 2028–2037 |
| F-15 (Zusagewahrscheinlichkeit, `rule:approval_probability`) | `budget_risk.approval_probability` 0,90; Antrag 2031-03-01 bzw. 2030-12-01; ohne `budget_risk` mit Antrag 2031-03-01 | 0,63 bzw. 0,90 (Knoten `{expr: "funding.<f>.budget_risk.approval_probability * funding.<f>.availability_after_2030"}` bzw. `{ref: …}`); ohne `budget_risk`: 0,70 (S01B-13 präzisiert) |
| F-16 (Auszahlungsverzug) | F-1 mit `payout_delay_months` 9 bzw. 12 | Termin 2028-10-01 bzw. 2029-01-01 → in beiden Fällen t = 2 (Periode 2028; N-13) |
| F-17 (Klimageschwindigkeitsbonus, F-18) | EFH selbstgenutzt, Wärmepumpe 32.000, zvE 70.000, Antrag 2026-12-01; Bestand Gasetagenheizung (`heating_existing.type: floor`) Baujahr 2016 bzw. Kohleofen (`class: coal`) | Symbol `heating.replaced_fossil_functional` = 1 (unabhängig vom Alter); 0,30 + 0,16 = 0,46 · 28.000 = 12.880,00; derselbe Gaskessel als `central`: 0,30 · 28.000 = 8.400,00 |

---

## 5. Regelkatalog (Spec 00 § 5.3)

### 5.1 Übersicht

Alle Regeln sind vektorisiert, ziehen keine Zufallszahlen und lesen weder `ctx` noch die Bibliothek, auch nicht in
Default-Werten ihrer Formals (Spec 00 § 5.3, R-93). Das letzte Formal `P` ist die Ausgabe der Abbildungsregel des
Themas (0.9). „MUSS“ markiert Regeln, die ein anderes Paket aufruft; sie sind vor dessen Welle verbindlich. Eigentum
(N-29): Mietrecht und CO2KostAufG bei WS-E (`rules-mietrecht.R`, `rules-co2kostaufg.R`, Welle 2b), Förderregeln bei
WS-E2 (`rules-funding.R`, Welle 3a, nur vom Expander `funding` und den Typen `grant`, `tax_credit_35c` aufgerufen);
Tests beim Eigentümer (`test-rules-mietrecht.R`, `test-rules-co2kostaufg.R`, `test-rules-funding.R`; Spec 00 § 15.6,
R-104). Ergebnisse, die schon in `vofi_resolve()` oder in Paketen früherer Wellen gebraucht werden (Zusagezeitpunkt,
Zusagewahrscheinlichkeit, Element-Defaults), sind keine Registry-Regeln, sondern Ableitungsregeln von WS-A (5.5).

| Regel | Formals | `returns` | Versionen (`valid_from`) | Eigentümer | aufgerufen von | Katalog |
|---|---|---|---|---|---|---|
| `mr_params` | `(lp, lp_559f)` | `params` | 2026-07-29 | WS-E (`rules-mietrecht.R`) | `rent_path`; Expander `unit_groups` (WS-E2) | **MUSS** |
| `mr_levy_allowed` | `(kind, rent_regime, phase, landlord_responsible, procedure, P)` | `value` (lgl; R-93, N-19) | 2026-07-29 | WS-E | Expander `unit_groups` (WS-E2, `bctx`), `rent_path` | **MUSS** |
| `mr_558_target` | `(ovm, base_36m, increases_36m, kuerzung, cap_share, voluntary_cap)` | `sim` | 2026-07-29 | WS-E | `rent_path` | – |
| `mr_levy_annual` | `(procedure, cost, maintenance, grants, repayment_grants, interest_reduction, attribution, hp_halving, hp_order, flat_order, section43, interest_in_559e, P)` | `sim` | 2026-07-29 | WS-E | `rent_path`; WS-H (Rechenweg im Bericht) | **MUSS** |
| `mr_levy_cap_total` | `(rent_before, prior_6y, P)` | `sim` | 2026-07-29 | WS-E | `rent_path` | – |
| `mr_levy_cap_heating` | `(prior_heat_6y, P)` | `sim` | 2026-07-29 | WS-E | `rent_path` | – |
| `mr_hp_halving` | `(heat_pump, jaz_plan, flow_temperature_c, construction_year, exception, threshold_inclusive, P)` | `sim` | 2026-07-29 | WS-E | `rent_path` | – |
| `mr_index_adjustment` | `(inflation_prev_year, index_cap_area, P)` | `sim` | 2026-07-29 | WS-E | `rent_path` | – |
| `mr_brake_applies` | `(brake_area, brake_until, date, first_use_after_2014_10_01, comprehensive_done, P)` | `sim` | 2026-07-29 | WS-E | `rent_path` | – |
| `mr_relet_rent` | `(market_rent, ovm, ovm_unmodernized, current_rent, levy_recent, brake_applies, P)` | `sim` | 2026-07-29 | WS-E | `rent_path` | – |
| `co2_params` | `(lp_co2, lp_bio)` | `params` | 2023-01-01 | WS-E (`rules-co2kostaufg.R`) | `energy_cost`, `co2_cost`, `rent_path` (Ableitung `section43_heating`); Expander `energy`, `unit_groups` (WS-E2) | **MUSS** |
| `co2_section43` | `(carrier_class, installation_date, existing_building, PC)` | `value` (lgl; R-93, N-19) | 2026-07-29 | WS-E | Expander `energy`, `unit_groups` (WS-E2, `bctx`), `rent_path` | **MUSS** |
| `co2_stage_share` | `(specific_kg_m2_pa, PC)` | `path` | 2023-01-01 | WS-E | `co2_cost`; WS-H (Bericht Energie und CO₂) | **MUSS** |
| `co2_s5a_dates` | `(section43_or_5b, installation_date, emergency_replacement, hardship_5d, PC)` | `params` | 2026-07-29 | WS-E | `co2_cost` | – |
| `bio_share_section43` | `(period_year, PC)` | `path` | 2026-07-29 | WS-E | `energy_cost` | – |
| `fund_degression` | `(value, application_date, start, step, every_months, floor)` | `value` | 2026-07-21 | WS-E2 (`rules-funding.R`) | Expander `funding` | – |
| `fund_income_rate` | `(taxable_income_adj, thresholds, rates)` | `value` | 2026-07-21 | WS-E2 | Expander `funding` | – |
| `fund_staffel_cap` | `(n_units, table, use_isfp)` | `value` | 2026-07-21 | WS-E2 | Expander `funding` | – |
| `fund_35c_params` | `(credit)` | `params` | 2020-01-01 | WS-E2 | `tax_credit_35c` | – |

Die früheren Registry-Regeln `fund_approval_probability` und `fund_approval_timing` entfallen (N-07); ihre Inhalte
stehen als `rule:approval_probability` und `rule:approval_timing` in 5.5. `fund_degression`, `fund_income_rate` und
`fund_staffel_cap` liefern deterministische Einzelwerte bzw. Tabellenwerte (`returns: value`, keine benannte Liste).

Für den Rechtsstand vor dem 29.07.2026 sind in v1 keine Versionen hinterlegt (Teil C, `legal/mietrecht_2026`
notes); `legal_state` < 2026-07-29 ergibt für Themen ohne Eintrag „inaktiv“ (0.9) und für `mietrecht` E.

### 5.2 `mr_params`: Abbildung der Nutzlast `mietrecht` und `mietrecht_559f`

| Name in P | Nutzlast (Teil C § 3.5) | Wert (geltend) |
|---|---|---|
| `kappung_rate_default`, `kappung_rate_15` | `s558.cap_share`, `s558.cap_share_tight_market` | 0,20; 0,15 |
| `wait_months` | `s558.waiting_months` | 15 |
| `kuerzung_rate_grant`, `kuerzung_grant_years` | `s558.funding_deduction_grant_share_pa`, `s558.funding_deduction_duration_grant_years` | 0,08; 12 (D) |
| `rate_559`, `cap_high`, `cap_low`, `cap_low_threshold`, `cap_heating` | `s559.rate_pa`, `s559.cap_eur_m2_month`, `s559.cap_low_rent_eur_m2_month`, `s559.low_rent_threshold_eur_m2_month`, `s559.heating_cap_eur_m2_month` | 0,08; 3,00; 2,00; 7,00; 0,50 |
| `cap_window_months` | `s559.cap_window_years` · 12 | 72 |
| `levy_effective_delay_months`, `levy_delay_defective_months` | `s559.effective_month_offset`, `s559.delay_if_defective_notice_months` | 3; 6 |
| `hardship_excluded_kinds` | `s559.hardship_exclusion_not_for` | `bgb_555b_1`, `bgb_555b_1a` (W bei `hardship_share` > 0 für diese Kinder) |
| `repayment_grant_as_grant` | `s559a.repayment_grant_as_grant` | `true` |
| `limit_559c_per_unit`, `flat_559c`, `lookback_559c_months`, `block_559c_months` | `s559c.cost_limit_per_unit_eur`, `.flat_maintenance_share`, `.lookback_years` · 12, `.lock_years` · 12 | 10.000; 0,30; 60; 60 |
| `rate_559e`, `flat_559e`, `cap_559e` | `s559e.rate_pa`, `.flat_maintenance_share`, `.cap_eur_m2_month` | 0,10; 0,15; 0,50 |
| `staffel_excludes` | `s557a.excludes` (Codes `bgb_procedure`, N-06) | `bgb_558`, `bgb_559`, `bgb_559b`; `mietrecht_ii`: zusätzlich `bgb_559e` |
| `index_excludes`, `index_559_only_if_not_attributable`, `index_heating_1a_allowed` | `s557b.excludes`, `.s559_only_if_not_attributable`, `.heating_1a_allowed` | `bgb_558`; `true`; `true` |
| `index_min_months`, `index_damping` | `s557b.min_months_unchanged`, `s557b.damping` | 12; `NULL` |
| `brake_cap_share`, `brake_until_default`, `brake_newbuild_after`, `brake_comprehensive_exempt` | `s556d.cap_share_over_ovm`, `.ordinance_until`, `.newbuild_first_use_after`, `.first_letting_after_comprehensive_modernisation_exempt` | 0,10; 2029-12-31; 2014-10-01; `true` |
| `minderung_exclusion_months`, `minderung_exclusion_kinds` | `s536_1a.exclusion_months`, `s536_1a.scope` | 3; `bgb_555b_1` |
| `attribution`, `flat_559e_order`, `hp_order`, `section43_flat` | `interpretation.third_party_allocation`, `.s559e_order`, `.s559f_order`, `.s559e_flat_for_section43` | `full`; `flat_before_funds`; `halve_then_funds`; `false` |
| `mpb_modernization_months` | Regelkonstante (§ 556e Abs. 2: Modernisierung der letzten drei Jahre) | 36 |
| `hp_jaz_threshold`, `hp_inclusive`, `hp_factor`, `hp_exc_year`, `hp_exc_flow` | `mietrecht_559f.jaz_threshold`, `.comparison == ge`, `.reduction_factor`, `.exceptions.construction_year_after`, `.exceptions.flow_temperature_max_c` | 2,5; `true`; 0,5; 1996; 55 — alle `NULL`, wenn das Thema inaktiv ist |

`mr_hp_halving` liefert 0 (keine Halbierung), wenn `hp_jaz_threshold` `NULL` ist; sonst 1, wenn `heat_pump` und
nicht (JAZ ≥ bzw. > Schwelle) und nicht Ausnahme (`exception` = `auto`: Baujahr > `hp_exc_year` oder Vorlauf ≤
`hp_exc_flow`; `building_after_1996`, `flow_temperature`: nur diese; `none`: keine). Der Faktor `hp_factor` (0,5) geht
in `mr_levy_annual` ein.

**`mr_levy_allowed(kind, rent_regime, phase, landlord_responsible, procedure, P)`** (`returns: value`, lgl n-Vektor,
vektorisiert über alle Argumente; N-06, N-19). `procedure` ∈ `bgb_559`, `bgb_559c`, `bgb_559e` (kanonische Codes von
`levy_procedure`; `auto` ist vor dem Aufruf aufgelöst). Für die Ausschlussprüfung gilt p* = `bgb_559`, falls
`procedure = bgb_559c`, sonst p* = `procedure` (Abbildung `bgb_559c` → `bgb_559`, fachlich bestätigt, siehe unten).

```text
FALSE, falls kind ∈ {none, bgb_555b_2, bgb_555b_7} oder rent_regime = owner_occupied
FALSE, falls procedure = bgb_559e und kind ≠ bgb_555b_1a            (s559e.requires_measure)
phase = bound   : FALSE
phase = staffel : !(p* %in% P$staffel_excludes)
phase = index   : !(p* %in% P$index_excludes) & (kind = bgb_555b_1a & P$index_heating_1a_allowed
                                                 | !landlord_responsible | !P$index_559_only_if_not_attributable)
phase = p558    : TRUE                                               (paragraph_558, cooperative_fee, nach Staffel/Bindung)
```

**Fachliche Bestätigung `bgb_559c` → `bgb_559` (Spec 00 § 17.3 Nr. 8 d):** bestätigt. § 559c Abs. 1 BGB regelt kein
eigenes Erhöhungsrecht, sondern ein vereinfachtes **Berechnungsverfahren** für die Mieterhöhung nach § 559 (pauschaler
Erhaltungsabzug 30 % anstelle des Abzugs nach § 559 Abs. 2; § 559 Abs. 4 und § 559a Abs. 2 S. 1–3 nicht anwendbar).
Der Ausschluss „Erhöhungen nach den §§ 558 bis 559b“ während einer Staffelmiete (§ 557a Abs. 2 S. 2) erfasst deshalb
auch die nach § 559c berechnete Erhöhung; dasselbe gilt für die Beschränkung bei Indexmiete (§ 557b Abs. 2: Erhöhung
nach § 559 nur bei nicht zu vertretenden Maßnahmen) und für die Sperrfrist des § 559c Abs. 4, die ausdrücklich
Erhöhungen nach §§ 559, 559e erfasst. Die Lesart ist zugleich die für den Vermieter vorsichtigere (0.1 Nr. 3). Ein
Freigabevermerk der Rechtsprüfung bleibt Teil des Bibliothekseintrags `legal/mietrecht_2026` (Qualität A; Abschnitt 9
Nr. 6).

### 5.3 `co2_params`

Abbildung siehe 3.7.4.

### 5.4 Förderregeln

- `fund_degression(...)` und `fund_income_rate(...)` nach 4.3.3; `fund_staffel_cap(n_units, table, use_isfp)` nach
  4.4 (Summe der Stufenwerte je WE). `fund_income_rate` erhält bereits `taxable_income_adj` (einmalige
  Kinderverschiebung, 4.3.2).
- `fund_35c_params(credit)` liefert `share_y1..3`, `total_share`, `cap_total`, `energy_advice_share` und die
  Jahresdeckel `cap_i` (4.8); fehlende Felder: Werte des Gesetzes (0,07/0,07/0,06; 0,20; 40.000; 0,50).
- Zusagezeitpunkt und Zusagewahrscheinlichkeit sind keine Registry-Regeln mehr (5.5, N-07).

### 5.5 Ableitungsregeln dieses Teils (WS-A, `R/scenario-layers.R`; Spec 00 § 4.7, R-86, N-07, N-08, N-08a)

Ableitungsregeln laufen in `vofi_resolve()` nach Schicht 8 und den Ableitungsregeln von Teil A (§ 1.4, insbesondere
`rule:dates`, `rule:building_aggregates`, `rule:measure_catalog`, `rule:cost_from_kg`), **vor** `item_defaults` (7.1)
und vor den Expandern, je Variante, Szenario-Set und Override neu. Sie setzen nur **fehlende** Domänenblätter bzw.
lösen `auto` auf (ein fehlendes Feld gilt als `auto`), schreiben Werte, Codes, `ref`- oder `expr`-Knoten und nie aus
overlay-fähigen numerischen Blättern berechnete Konstanten; Werte aus `bctx$legal()` und `bctx$lib()` dürfen sie als
Konstanten einsetzen. Herkunft `source_type = "type_default"`, `layer = 0`, `entry = "rule:<name>"` bzw. die
Bibliotheks-id, aus der ein Wert stammt. Reihenfolge innerhalb dieses Teils wie in der Tabelle. Ein Paket, das ein
Ergebnis braucht, liest das Domänenblatt (WS-B, WS-C, WS-D, WS-E, WS-E2, WS-G).

| Regel | Zielfelder | Ableitung |
|---|---|---|
| `rule:unit_group_defaults` | `unit_groups` (implizite Gruppe), je Gruppe g: `owner_occupied`, `rent_regime`, `vacancy_rate`, `rent_default_rate`, `lease_up_months`, `operating.admin_per_unit_eur_pa`, `operating.admin_per_parking_eur_pa`, `operating.nonrecoverable_share_of_rent` | (0) `unit_groups` leer, `project.perspective = selbstnutzer` und `building` vorhanden: Element `main` mit `n_units: {ref: building.n_units}`, `living_area_m2: {ref: building.living_area_m2}` (Bezüge statt Kopien, R-86), `owner_occupied: true` (1.6 Nr. 1). (1) `owner_occupied` fehlt → `true` bei `selbstnutzer`, sonst `false`. (2) `owner_occupied = true`: `rent_regime: owner_occupied`, `vacancy_rate: 0`, `rent_default_rate: 0`, `operating.admin_per_unit_eur_pa: 0`, `operating.admin_per_parking_eur_pa: 0`, `operating.nonrecoverable_share_of_rent: 0` (N-08). (3) vermietete Gruppe bei `perspective = wu_genossenschaft`: `rent_regime: cooperative_fee` (N-08). (4) vermietete Gruppe mit `rent_regime: bound_social` oder in `unit_groups` eines Instruments `instrument_type: rent_binding`: `operating.admin_per_unit_eur_pa` und `operating.admin_per_parking_eur_pa` aus `bctx$lib("costs/bewirtschaftung_ii_bv_2026")` (`admin_per_unit_eur_pa` 372,46, `admin_per_garage_eur_pa` 48,58; Herkunft = Bibliotheks-id). (5) vermietete Gruppe bei `project_type` ∈ {`neubau`, `erwerb_neubau`}: `lease_up_months: 3` (Memo 03 § 11). Alle übrigen Gruppenwerte, auch `vacancy_rate: 0.025` für vermietete Gruppen, kommen aus `item_defaults."unit_groups"`. (0), (4) und (5) ergänzen N-08 um von Perspektive, `rent_regime` bzw. `project_type` abhängige Werte, die sonst Expander bzw. Profil trügen; vom Integrator bestätigt als N-08a (Spec 00 § 17.5.3, R-118) |
| `rule:carrier_defaults` | je Träger c: `class`, `network_fee_eur_kwh`, `emission_factor_kg_kwh`, `ghg_factor_kg_kwh` | `class` aus der kanonischen id (3.2.1; sonst keine Ableitung, E in WS-B). `network_fee_eur_kwh: {ref: market.energy_network_fee.<c>}`, falls der Marktpfad nach Schicht 8 existiert, sonst 0. `emission_factor_kg_kwh` und `ghg_factor_kg_kwh` nach Trägerklasse aus `bctx$legal("emission_factors_co2cost")` bzw. `bctx$legal("emission_factors_geg")` (Tabelle 3.2.1; Werte, Herkunft = gewählte Bibliotheks-id). Thema inaktiv: Faktor 0 und W („Emissionsfaktoren nicht verfügbar“). Preise, USt, Fortschreibung, CO₂-Preis und Bio-Mehrkosten kommen aus `item_defaults."energy.carriers"` |
| `rule:approval_timing` | je Instrument f: `approval_timing` | `auto` bzw. fehlend → `before_start`, wenn `application_date` (Instrument, sonst `project.application_date`) ≤ frühester Termin der Maßnahmen von `funding.<f>.measures` (`date`; `year` als 1. Januar; erster Termin von `payment_schedule`; ohne Verschiebung), sonst `after_start`; Instrument ohne Maßnahmen (`rent_binding`): frühester Termin aller Maßnahmen der Variante, ohne Maßnahmen `before_start` (Spec 00 § 4.3.7, R-111). Ausdrückliche Codes bleiben (4.9 Nr. 1) |
| `rule:approval_probability` | je Instrument f: `approval_probability` | fehlt: b = `{ref: funding.<f>.budget_risk.approval_probability}`, wenn der Pfad (meist über `from:`) existiert, sonst 1; bei `application_date` ≥ 2031-01-01 `{expr: "<b> * funding.<f>.availability_after_2030"}` (Ausdruck mit dem Bezug bzw. der Zahl 1; `availability_after_2030` füllt danach `item_defaults."funding"` mit 0,7), sonst b (S01B-13; Spec 00 § 4.3.7) |
| `rule:tax_credit_defaults` | je Instrument f mit `instrument_type: tax_credit`: `payout_delay_months` | fehlt → 12 (Zahlung im Dezember des Folgejahres, Termin (Y+2)-01-01; Spec 00 § 10.9). Für alle übrigen Instrumente setzt `item_defaults."funding"` 0 |

Teil-B-Felder, die **nicht** über Ableitungsregeln laufen, sondern nur in der eigenen Komponente bzw. Rechnung
abgeleitet werden (0.3 (A)): `rent_start`, `growth_from`, `first_use_after_2014_10_01`, `binding_end`,
`rent_36m_ago_eur_m2_month`, `last_558_increase_date`, die Felder in `measures.<k>.rent_law` mit (A), die
Zustandsfelder `heat_pump_carrier`, `installation_date`, `section43`, `consumption_basis` und die Vererbung (3.2.3),
`energy.pv.commissioning_date`, `self_consumption_carrier`, `feed_in_tariff_eur_kwh`, `opex_eur_pa`,
`funding.<f>.applicant` und `repayment_grant.class`. Sie sind deterministisch, werden nur von Expandern und Typen dieses
Teils gebraucht und sind keine Overlay-Ziele; wer ein Overlay auf einen solchen Pfad setzen will, gibt den Wert
ausdrücklich an (sonst E „Overlay-Ziel fehlt“, Spec 00 § 4.11, R-96).

---

## 6. Verschiebungsfelder je Typ (Spec 00 § 3.9)

Laufspezifische Verschiebungen wirken nur über die genannten Felder; alle übrigen Termine sind deterministisch.

| Typ | verschobene Termine | Quelle der Verschiebung |
|---|---|---|
| `rent_path` | `rent_start` (Token `completion`), Fertigstellung mc_k, Erklärung und Wirksamkeit me_k, Arbeitsbeginn, OVM-Zuschlag, Kürzungsbeginn | `project.construction_delay_months` bzw. `measures.<k>.delay_months` |
| `operating_cost`, `property_tax`, `imputed_rent` | `start_event` (Token `completion`), `occupancy_from`, `after_completion_from` | `project.construction_delay_months` |
| `energy_cost`, `co2_cost` (über `en_state_weights`) | Beginn der Zustände | `measures.<measure>.delay_months` bzw. Parameter `construction_delay_months` (= `{ref: project.construction_delay_months}`); § 43-Status, Einbaudatum für § 5a und Bio-Treppe bleiben deterministisch (Basisfall) |
| `pv` | `commissioning_date`, Ende der Vergütung | `measures.<energy.pv.measure>.delay_months` |
| `tenant_costs` | keine eigenen (folgt den Segmenten) | – |
| `grant` | Auszahlungstermin (Datum nach R-98, `ctx$shift_period()`) | `measures.<m>.delay_months` (Ereignis `completion_proof`) und `funding.<f>.payout_delay_months` |
| `tax_credit_35c` | Abschluss (Veranlagungsjahre), Zahlungstermin (R-98) | `measures.<m>.delay_months`, `funding.<f>.payout_delay_months` |
| Förderkredite `f_<f>_loan` | keine (Zeitparameter `deterministic_only`, Spec 00 § 8.1 Nr. 2, R-47) | – |
| `f_<f>_subsidy` (`recurring`) | `start_event` mit Token `completion` | `project.construction_delay_months` |

Masken entstehen über `ctx$shift_months()`, `ctx$shift_overlap()` bzw. `ctx$shift_period()`; Verschiebungen werden
auf ganze Monate gerundet (0.4) und sind ≥ 0 (Validierungsfehler sonst; ein Termin, der je Lauf auch früher liegen
kann, wird als früherer Basistermin mit nichtnegativer Verschiebung modelliert; Spec 00 § 3.9, R-105).
Tilgungszuschüsse der Förderkredite bleiben terminfest (R-47).

---

## 7. Defaults für `global.yaml` und Bibliothek

### 7.1 `inst/extdata/defaults/global.yaml`: Element-Defaults dieses Teils (WS-A; Spec 00 § 4.7, R-85, N-04)

Die Felddefaults dieses Teils stehen unter dem reservierten Wurzelschlüssel `item_defaults` von `global.yaml`
(nur dort zulässig, Spec 00 § 4.2 Fußnote ³). Die Map ist die Vereinigung mit den Vorlagen von Teil A (§ 2.2); je Pfad
gibt es genau einen Schlüssel (bei `"building"` vereinigt WS-A die Felder beider Teile in einer Vorlage). Eine
Vorlage füllt erst nach Schicht 7 fehlende Blätter; `replace` und `remove` auf solche Blätter verlangen deshalb, dass
die Basis den Pfad selbst trägt; `set` und `overrides` dürfen sie setzen, wenn das Elternelement existiert und das Blatt
ein Feld der Vorlage bzw. der Feldtabellen ist (Spec 00 § 4.11, R-112). S1 trägt `building.efficiency_standard_after:
none` dennoch ausdrücklich in der Basis (X-03). Anwendung nach Schicht 8 und den Ableitungsregeln (5.5), vor den Expandern: für jedes
**vorhandene** Element einer Sammlung bzw. für jeden **vorhandenen** optionalen Block gilt `element <-
deep_merge(vorlage, element)` (das Element gewinnt), in aufsteigender Pfadtiefe (`energy` vor `energy.carriers` und
`energy.performance_gap`); `{id}` in `ref`-/`expr`-Pfaden steht für die Element-id (in YAML als Zeichenkette zu quoten, z. B. `{ref: "market.energy_price.{id}"}`, weil `{` sonst eine Flow-Map öffnet); `from:` in einer Vorlage wird vor
ihrer Anwendung aufgelöst (Herkunft = Bibliotheks-id). Herkunft sonst `source_type = "global"`, `entry =
"global#item_defaults.<pfad>"`. Optionale Blöcke (`energy`, `energy.pv`, `energy.performance_gap`,
`building.property_tax`) entstehen durch `item_defaults` nicht neu (N-05). Ausnahmen sind Teilbäume, die eine Vorlage
selbst enthält (Spec 00 § 4.7, R-118): der leere Teilbaum `performance_gap: {}` in der Vorlage `energy`, der den Block
anlegt, sobald `energy` existiert, damit die Strukturfaktoren immer als Domänenblätter (Overlay-Ziele) vorhanden sind,
und `maintenance` in der Vorlage `building` (Teil A § 3.3: `building.maintenance` mit `enabled: true` in jedem Szenario
mit `building`).

```yaml
item_defaults:
  # 01b: Elementvorlagen (Teil A ergänzt dieselbe Map, z. B. "building", "measures")
  "unit_groups":                    # owner_occupied und nutzungsabhängige Werte: rule:unit_group_defaults (5.5)
    rent_regime: paragraph_558      # Rückfall für vermietete Gruppen ohne Genossenschaft
    increase_policy: auto
    growth_applies_to: total
    interval_months: 36
    voluntary_558_cap_months: 36
    turnover_rate_pa: 0.08
    relet_vacancy_months: 0
    vacancy_rate: 0.025             # Memo 03 § 11 „Deutschland-Mittel“; Selbstnutzung 0 über rule:unit_group_defaults
    rent_default_rate: 0.01
    lease_up_months: 0              # Neubau 3 über rule:unit_group_defaults
    after_staffel_regime: paragraph_558
    index_adjust_month: 1
    after_binding_regime: paragraph_558
    post_binding_kappung: false
    rent_growth: {ref: market.rent_growth}
    market_rent_growth: {ref: market.rent_growth_new}
    index_rate: {ref: market.inflation}
    imputed_rent_growth: {ref: market.rent_growth}
    rent_law:
      modernization_levy: auto
      voluntary_cap_mode: fixed
      hardship_share: 0
      interest_subsidy_in_559e: true
      kuerzung_558_5: true
      # Auslegungen ohne Eintrag: Defaults aus dem Thema mietrecht, Teilbaum interpretation (legal/mietrecht_2026; 1.3, Spec 00 § 4.10, R-116)
    operating:
      admin_per_unit_eur_pa: {from: costs/bewirtschaftung_immowertv_2026, use: admin_per_unit_or_efh_eur_pa}   # 367 (N-03)
      admin_per_parking_eur_pa: {from: costs/bewirtschaftung_immowertv_2026, use: admin_per_garage_eur_pa}    # 48 (N-03)
      nonrecoverable_share_of_rent: 0.01
      recoverable_opex_eur_m2_month: 1.70
      vacancy_opex_scope: cold
      growth: {ref: market.inflation}
      opex_growth: {ref: market.operating_cost_growth}
  "energy":                         # nur, wenn das Szenario einen Block energy hat
    performance_gap: {}             # legt den Teilbaum an; Werte aus "energy.performance_gap"
    co2_landlord_share_reduction: 0
    co2_hardship_5d: false
    co2_newbuild_5b: false
  "energy.carriers":                # class, Netzentgelt, Emissionsfaktoren: rule:carrier_defaults (5.5)
    price_eur_kwh: {ref: "market.energy_price.{id}"}   # Platzhalter in YAML quoten (Flow-Syntax)
    price_includes: commodity
    price_basis: net
    vat_rate: 0.19                  # auch Holzpellets (19 % seit 2024, F-16)
    fee_growth: {ref: market.inflation}
    co2_price_eur_t: {ref: market.co2_price}
    bio_premium_eur_kwh: {ref: market.bio_fuel_premium}
  "energy.performance_gap":
    prebound_factor: 0.7
    rebound_factor: 1.0             # demand_kwh der Folgezustände enthält den Rebound (3.2.4, F-15)
    realisation_factor: 1
  "energy.pv":                      # nur, wenn energy.pv existiert
    specific_yield_kwh_kwp: 950
    degradation_pa: 0
    tariff_years: 20
    post_tariff_price_eur_kwh: 0
    internal_price_eur_kwh: 0
    opex_share_of_cost: 0.012
    feed_in_mode: partial
    tax_exempt: auto
    vat_zero_rate_attested: false
  "funding":                        # approval_timing/-probability: rule:approval_*; tax_credit-Verzug: rule:tax_credit_defaults
    approved: 1                     # Spec 00 § 4.3.7; Domänenblatt (Ziel des Zusageschlüssels, Bezüge wie S4 kfw358_2033)
    on_reject: balance
    approval_timing: auto           # dokumentiert den Default; rule:approval_timing löst vorher auf
    payout_delay_months: 0
    availability_after_2030: 0.7    # N-09 (Memo 07 § 4.0)
  "building.property_tax":          # nur, wenn building.property_tax existiert (X-16)
    growth: {ref: market.inflation}
  "household":                      # nur, wenn household existiert (N-05; Felder 3.10.1)
    income_growth: {ref: market.inflation}
    n_children_u18: 0
  "building":                       # Teil-B-Felder (3.2.6) der Vorlage "building" von Teil A § 2.2; WS-A führt
    efficiency_standard_after: none #   einen gemeinsamen Schlüssel (Vereinigung auf Feldebene)
    wpb_flag: false
    denkmal: false
    serial_renovation: false
    isfp_available: false

# scenario_sets (gewöhnlicher Block, kein item_default): Inhalt ausschließlich nach Teil C § 4.2 (einzige Quelle,
#   N-22, R-118), u. a. foerderstopp „Förderstopp: keine Förderzusage“ mit set: {funding.*.approved: 0}
```

Die früheren Schlüssel `unit_groups_defaults`, `energy_defaults`, `funding_defaults`, `building_defaults` und
`funding_defaults.payout_delay_months_tax_credit` entfallen (N-04): Sie wären unbekannte Wurzelschlüssel (Spec 00
§ 4.2). Ebenso entfallen die Profilwerte für Gruppenfelder (frühere Tabelle 7.2): Profile setzen keine Felder von
Sammlungselementen (Spec 00 § 4.7, R-76); die perspektivabhängigen Werte setzt `rule:unit_group_defaults` (N-08).
`analysis.tenant_view` ist ein Profilwert nach Teil A (§ 2.3–2.7, Rückfall `rule:tenant_view`). `test-profiles.R`
(WS-A) prüft, dass alle `from`/`use`-Verweise der Vorlagen auflösen (Spec 00 § 4.9, R-104).

**Prüfwerte (WS-A, `test-scenario-layers.R`):** (d1) Selbstnutzer ohne `unit_groups` → Gruppe `main` mit
`owner_occupied: true`, `rent_regime: owner_occupied`, `vacancy_rate: 0`, `operating.admin_per_unit_eur_pa: 0`
(Herkunft `rule:unit_group_defaults`), `operating.recoverable_opex_eur_m2_month: 1.70` (Herkunft
`global#item_defaults.unit_groups`). (d2) `wu_genossenschaft`, Gruppe ohne `rent_regime` → `cooperative_fee`;
`wu_kommunal` → `paragraph_558` (Herkunft `global#item_defaults.unit_groups`). (d3) Szenario mit `energy` ohne
`performance_gap` → `energy.performance_gap.prebound_factor` 0,7 vorhanden; Szenario ohne `energy` → kein Block
`energy`. (d4) Funding-Element `{from: funding/estg_35c, measures: [m1]}` → `payout_delay_months` 12 (Herkunft
`rule:tax_credit_defaults`), `availability_after_2030` 0,7, `approval_timing` aufgelöst. (d5) Wurzelschlüssel
`energy_defaults` in `global.yaml` → E (`validation.unknown_key`).

### 7.2 Szenario-Set und Pflichtsensitivität

- `foerderstopp` nach Teil C § 4.2 (einzige Quelle, N-22, R-118; Spec 00 § 4.11, Konzept B12); Wirkung 4.9 Nr. 6.
- Pflichtsensitivität „mit 2045-Stufe“ (Konzept § 5.5, Teil C § 4.4): `{id: stufe_2045, path:
  project.pending_reforms, add: stufe_2045, label: "mit 2045-Stufe (100 % klimaneutraler Brennstoff ab 2045)"}` in
  `analysis.mandatory_sensitivities` aller Profile (Teil A). Sie wird **immer gerechnet**; ohne Zustand mit `section43
  = true` ändert sie das Ergebnis nicht und erscheint im Bericht als „ohne Wirkung“ (Regel von Teil C § 4.4, X-24 e).

### 7.3 Bibliothek (Abstimmung Teil C, WS-L)

- `legal/mietrecht_559f_2026` ist ein eigener Eintrag (`topic: mietrecht_559f`, `quality: C`, `release: {status:
  pending}`); in `legal/mietrecht_2026` gibt es kein `s559f` (0.9; umgesetzt in Teil C).
- Verfahrenslisten der Mietrechtsnutzlast (`s557a.excludes`, `s558.excludes_increases`, `rent_law.enables`) nur mit
  Codes des Vokabulars `bgb_procedure` (N-06, R-89).
- Fördernutzlasten: `eligibility.measure_types` nur mit den 37 Codes von Teil A § 4.2 (N-01); `conditions.lca_thg`
  statt `lca_qng_plus_thg` (N-10); `loan.max_share_of_eligible_costs` statt `basis.…` (N-11); KfW 459 mit eigener
  Sequenz `degression` (X-02); `funding/estg_35c.cumulation.exclusive_with` um KfW 358/359 ergänzt (N-12).
- `prices/energy_prices_2026`: Marktpreis für jeden kanonischen Träger (auch `lpg`, `power_mfh`, N-15),
  `vat_rate.pellets: 0.19` (F-16); `market.feed_in_tariff.partial_40_100kwp` (vorhanden, 0,0545) wird vom
  PV-Default-Ausdruck genutzt (3.9.1, N-16).
- `legal/emission_factors_geg_anlage9` mit `valid_to: null` und Prüfpunkt „Neuwerte ab 2027“ (N-28, X-29); sonst wäre
  das Thema ab `legal_state` 2027 inaktiv und `ghg_factor_kg_kwh` 0.

---

## 8. Vokabular für `inst/vocab/enums.yaml` (Integrator)

Keine neuen Ledger-Kategorien. Neue bzw. konkretisierte Enums dieses Teils (Übernahme durch den Integrator nach
Phase-0-Nacharbeit P0-02, Spec 00 § 17.5.4; Form `name: {codes, aliases, default}`, Spec 00 § 2.11):

| Enum | Codes |
|---|---|
| `rent_regime` | `paragraph_558`, `staffel`, `index`, `bound_social`, `cooperative_fee`, `owner_occupied` (Spec 00) |
| `increase_policy` | `auto`, `fixed_growth`, `max`, `interval`, `capped` |
| `growth_applies_to` | `total`, `base` |
| `levy_mode` | `auto`, `none` |
| `levy_procedure` | `auto`, `bgb_559`, `bgb_559c`, `bgb_559e`; Aliase `"559"` → `bgb_559`, `"559c"` → `bgb_559c`, `"559e"` → `bgb_559e` (auch für die als Zahl gelesene Eingabe `559`); Default `auto` (Spec 00 § 2.11, N-06) |
| `bgb_procedure` | Spec 00 § 2.11 (`bgb_557a`, `bgb_557b`, `bgb_558`, `bgb_559`, `bgb_559b`, `bgb_559c`, `bgb_559e`); nur in Bibliotheksnutzlasten, Regelparameter `staffel_excludes`, `index_excludes`, `relet_levy_procedures` |
| `maintenance_method` | `auto`, `linear_wear`, `fixed_share`, `ohnehin`, `none` |
| `modernization_kind` | `none`, `bgb_555b_1`, `bgb_555b_1a`, `bgb_555b_2`, `bgb_555b_3`, `bgb_555b_4`, `bgb_555b_4a`, `bgb_555b_5`, `bgb_555b_6`, `bgb_555b_7` (Aliase 1.4) |
| `hp_exception` | `auto`, `none`, `building_after_1996`, `flow_temperature` |
| `third_party_allocation` (Feld `drittmittel_attribution`) | `full`, `proportional` |
| `s559e_order` (Feld `flat_559e_order`) | `flat_before_funds`, `funds_before_flat` |
| `s559f_order` (Feld `hp_reduction_order`) | `halve_then_funds`, `funds_then_halve` |
| `voluntary_cap_mode` | `fixed`, `warm_rent_neutral` |
| `vacancy_opex_scope` | `cold`, `warm` |
| `carrier_class` | `gas`, `oil`, `lpg`, `coal`, `power`, `power_hp`, `district_heating`, `biomass`, `other` (`coal` neu, F-18) |
| `heating_system_type` (Feld `building.heating_existing.type`) | `central`, `floor`, `single_room`; Default `central` (neu, F-18) |
| `consumption_basis` | `measured`, `demand` |
| `price_includes` | `commodity`, `all` |
| `price_basis` | `net`, `gross` |
| `feed_in_mode` | `partial`, `full` |
| `pv_tax_exempt` | `auto`, `yes`, `no` |
| `instrument_type` | `grant`, `loan`, `loan_with_repayment_grant`, `interest_subsidy`, `tax_credit`, `rent_binding` (Spec 00) |
| `applicant` | `privatperson`, `privatperson_vermieter`, `weg`, `unternehmen`, `kommunales_unternehmen`, `genossenschaft`, `gemeinnuetzig`, `koerperschaft`, `contractor` |
| `approval_timing` | `auto`, `before_start`, `after_start` (Spec 00; `auto` löst `rule:approval_timing` auf) |
| `on_reject` | `balance`, `drop_measures` (Spec 00) |
| `payout_event` | `completion_proof`, `commitment` |
| `grant_counts_as` | `zuschuss_559a_abs1`, `none` |
| `loan_counts_as` | `zinsverbilligung_559a_abs2`, `none` |
| `repayment_grant_class` | `ee`, `nh` |
| `bonus_mode` | `excess_over_threshold`, `whole_amount` |
| `cap_period` | `total`, `calendar_year` |
| `rent_phase` (intern, `mr_levy_allowed`) | `p558`, `staffel`, `index`, `bound` |
| `efficiency_standard` | `eh40`, `eh55`, `eh70`, `eh85`, `eh_denkmal`, `none` (3.2.6) |
| `energy_class` | `A+`, `A`, `B`, `C`, `D`, `E`, `F`, `G`, `H` (3.2.6) |

Meldungsschlüssel (N-17, Spec 00 § 2.10, R-104): Validierung (WS-B, `inst/labels/de/validation.yaml`) nach dem Schema
`validation.<block>.<code>`, u. a. `validation.unit_groups.ovm_missing`, `validation.unit_groups.owner_opex_double`,
`validation.building.property_tax_missing`, `validation.energy.rebound_base_differs`,
`validation.maintenance.service_double_energy`, `validation.funding.not_eligible`; der Namensraum `validation.b.*`
entfällt. Expander (WS-E2, `inst/labels/de/expand.yaml`): `expand.unit_groups.levy_excluded`,
`expand.funding.not_eligible`, `expand.funding.condition_unchecked`, `expand.funding.degression_target_removed`.
Typen: `types.flow.<typ>.msg.topic_inactive`, `types.flow.grant.msg.not_eligible`,
`types.flow.tax_credit_35c.msg.capped_by_tax`.

---

## 9. Offene Punkte (fachlich-juristisch zu prüfen)

Jeder Punkt hat eine Voreinstellung (vorsichtigere Lesart, 0.1 Nr. 3) und einen Schalter; die Freigabe erfolgt über die
Bibliothek (Qualität, `release`) bzw. die Auslegungsfelder in `unit_groups.<g>.rent_law`.

1. **§ 559f BGB** (Qualität C, nur Memo 07): Wortlaut, Grenzfall „≥ 2,5“ oder „> 2,5“, Ausnahmen (Baujahr > 1996,
   Vorlauf ≤ 55 °C), Reihenfolge Halbierung/Drittmittelabzug (`halve_then_funds`), Plan-JAZ als Maßstab. Bis zur
   Freigabe ist das Thema `mietrecht_559f` inaktiv, also **keine** Halbierung (Spec 00 R-80); das ist für den
   Vermieter nicht die vorsichtigere Lesart und muss im Bericht sichtbar sein.
2. **§ 559e und § 43 GModG:** Reichweite der 15-%-Pauschale bei einer neuen Heizung nach § 43 (Voreinstellung: keine
   Pauschale, Abzug des tatsächlichen Erhaltungsanteils) und Reihenfolge Pauschale/Drittmittel (F13: 0,10 · (0,85 ·
   K − D)).
3. **Zinsermäßigung in § 559e:** Ob § 559a Abs. 2 auch die § 559e-Umlage mindert (Voreinstellung ja).
4. **§ 559a Zurechnung:** Drittmittel voll (`full`, F14) oder anteilig zum Modernisierungsanteil; Lesart Memo 07
   (Zuschuss voll, Zinsermäßigung anteilig) als Alternative dokumentiert (L-1).
5. **§ 558 Abs. 5:** Dauer der Kürzung bei Zuschüssen (12 Jahre, D) und Zinsverbilligung (Zinsbindung),
   Reihenfolge Kürzung nach Kappung, Kürzung auch ohne Umlage der Maßnahme; Kappungsbasis ohne §§ 559–560-Erhöhungen.
6. **§ 559c:** Abzug von Zuschüssen trotz Pauschale, Sperrfrist 5 Jahre, Wertgrenze je WE inkl. früherer § 559c-Kosten.
   Die Einordnung als Berechnungsverfahren der Erhöhung nach § 559 (Ausschluss bei Staffelmiete, Beschränkung bei
   Indexmiete; Abbildung `bgb_559c` → `bgb_559` in `mr_levy_allowed`) ist in Runde 3 fachlich bestätigt (5.2, N-06,
   Spec 00 § 17.3 Nr. 8 d); offen bleibt nur der Freigabevermerk der Rechtsprüfung.
7. **Staffel- und Indexmiete:** § 559e während einer Staffel (zulässig nach geltendem Recht, ausgeschlossen mit
   Mietrecht II), § 559 bei Indexmiete nur für nicht zu vertretende Maßnahmen, Näherung des Anpassungstermins.
8. **Mietpreisbremse:** Näherung zu § 556e Abs. 2 (Umlagen der letzten 36 Monate), umfassende Modernisierung
   (§ 556f S. 2) als Flag, Ende der Verordnungen 2029-12-31.
9. **§ 536 Abs. 1a:** Minderungsausschluss 3 Monate nur für § 555b Nr. 1 (geltend) bzw. zusätzlich Nr. 1a (Mietrecht II).
10. **Härtefälle** (§ 559 Abs. 4, 5): pauschaler Anteil `hardship_share`; Ausschluss für §§ 555b Nr. 1, 1a.
11. **CO2KostAufG:** § 5a (Beginn 2028/2029, Übergang bei Havarie, Qualität C), § 5b Neubau (C, nur ausdrücklich),
    § 5d Härtefall (C), § 9 Kürzung (C), 30-%-Deckel des Bio-Mehrkostenanteils, Mischnutzung (`non_residential_split`
    nicht abgebildet).
12. **Bio-Treppe:** Stufen ab 1. Januar, Erfüllungsoptionen (Hybrid, Solarthermie) nur über `section43: false`;
    2045-Stufe ist eine Ableitung (`stufe_2045`, D).
13. **Treibhausgasbilanz:** Faktor Netzstrom 0,560 kg/kWh (GEG Anlage 9) überschätzt die Emissionen von
    Wärmepumpen; der Eintrag gilt mit `valid_to: null` fort, bis die Neufassung ab 2027 geprüft ist (N-28, X-29); ein
    abnehmender Strommix als Pfad ist empfohlen. Für Kohle (`class: coal`) fehlt ein BEHG-Kostenfaktor in
    `legal/emission_factors_co2cost_2026` (W, CO₂-Kosten 0; Teil C kann ihn ergänzen).
14. **PV:** § 3 Nr. 72 EStG (30 kWp je Einheit, 100 kWp je Steuerpflichtigem, Stand JStG 2024), § 12 Abs. 3 UStG über
    30 kWp nur mit Nachweis, EEG-Reform 2027 (fester Vergütungssatz für Neuanlagen). Erledigt: Satz 40–100 kWp im
    Default-Ausdruck (3.9.1, N-16); über 100 kWp bleibt der Satz Pflichtangabe (Direktvermarktung).
15. **Förderung:** iSFP-Bonus (`excess_over_threshold` vs. `whole_amount`), KfW-459-Staffel (analog 458, D),
    Wirkung des Tilgungszuschusses (Laufzeitverkürzung) und Baubegleitung, BAFA-Jahresdeckel bei mehreren Instrumenten,
    Kumulierungshöchstgrenzen. Erledigt in Runde 3: Schwellenverschiebung **einmal** bei mindestens einem Kind
    (Memo 02 § 5.2, Memo 07 § 1; F-01, Schalter `child_u18_threshold_shift_per_child`); Symbol
    `heating.replaced_fossil_functional` mit Kohle und Gasetagenheizung (F-18; Einzelöfen `single_room` nur über
    `facts`); Antragsteller `privatperson` als Oberbegriff für vermietende Privatpersonen (F-02); getrennte Fakten
    `lca_thg` und `qng` (N-10).
16. **§ 35c EStG:** Veranlagungsjahre ab Abschluss, Energieberatung außerhalb des Jahresdeckels, aber im Gesamtdeckel,
    Inhalt der Änderung vom 29.06.2026, Abschluss vor 2030-01-01.
17. **Grundsteuer:** Nachfeststellung nach Fertigstellung (1. Januar des Folgejahres), Grundsteuer C.
18. **Bewirtschaftung:** II. BV (gebundener Wohnraum) gegenüber ImmoWertV (Modellansätze), Leerstands-Betriebskosten
    1,70 EUR/m² (D). Der Wert ist ein MFH-Mittel einschließlich Gebäudeversicherung; für Selbstnutzer eines EFH ist er
    meist zu hoch und kann mit einer eigenen Kostenkomponente doppelt zählen (F-11; W `owner_opex_double`). Offen:
    eigener Selbstnutzer-Default (über eine Ergänzung von `rule:unit_group_defaults`, Entscheidung Integrator, weil
    N-08 den Regelinhalt festlegt) oder ausdrückliche Angabe in S4/S5 (Teil C). **Entschieden (Runde 4, N-08a):** kein
    eigener Selbstnutzer-Default in v1; ausdrückliche Angabe (S4, S5 mit 0, Teil C F-11), W `owner_opex_double` bleibt.
19. **Genossenschaft:** Nutzungsentgelt nach §§ 558 ff., Befreiungsgrenzen § 5 Abs. 1 Nr. 10 KStG, PV-Verrechnung an
    Mitglieder (B3).
20. ~~**Warmmietenneutral:** Bezugsjahr der Ersparnis und Basis „vermietete Fläche“~~ – **erledigt** (S01B-08 →
    R-102, S01B-03 → R-101).
21. ~~**Energiepreis-Basisfall (F-08)**~~ – **erledigt** (Teil C § 2.4, § 3.6, OP-19; Spec 00 § 17.3 Nr. 8 c): Der
    Basisfall ist der Erwartungspfad der Mean-Reversion; Teil B liest den Pfad unverändert (3.2.5).
22. ~~**Rebound-Konvention (F-15)**~~ – **erledigt** (Teil C F-15): `demand_kwh` der Folgezustände enthält den
    Rebound (Default 1,0); die Vorlage `rebound` hat den Modus 1,0, `rebound_calculated` (Modus 1,1) gilt nur für
    reinen Rechenbedarf; W `rebound_base_differs` bleibt für abweichende Overlays (3.2.4, E-12).
23. ~~**Zusagezeitpunkt (S01B-14)**~~ – **erledigt** (Runde 4, R-111): Bezug „frühester Termin der Maßnahmen **des
    Instruments**“, ohne Maßnahmen der Variante (Spec 00 § 4.3.7; 4.2, 4.9 Nr. 1, 5.5, F-9).
24. ~~**Holzpellets (F-16)**~~ – **erledigt** (Teil C OP-08): 19 % USt seit 2024 als Default; Brennholz/Scheitholz
    (7 %) nur ausdrücklich; `vat_rate.pellets`, `p0`, `p_norm` und Prüffall in Teil C neu gerechnet.
25. **Grundsteuer optional (X-16):** Ohne Angabe in `building.property_tax` entsteht keine Komponente (I bzw. W);
    bei Selbstnutzern trägt eine eigene Kostenkomponente die Grundsteuer (S5).

---

## 10. Änderungsanträge an Spec 00 und Abstimmungspunkte

### 10.1 Änderungsanträge an Spec 00

Stand nach Runde 3 (Spec 00 § 17.5.1). Spalte „Umsetzung in Teil B“ nennt die Abschnitte, in denen die Entscheidung
eingearbeitet ist; die frühere Übergangslösung entfällt jeweils.

| Nr. | Spec 00 | Antrag | Entscheidung (Runde 3) | Umsetzung in Teil B |
|---|---|---|---|---|
| S01B-01 | § 7.10, § 4.12 | Energiekomponenten je Zustand × Träger (`e_<s>_<c>_cost`, `e_<s>_<c>_co2`) | **entschieden: angenommen** (R-90; ids ≤ 40 bei Zustand ≤ 12, Träger ≤ 20, N-14) | 3.1, 3.2.2, 3.5 |
| S01B-02 | § 5.2, § 5.6, § 6.1 | optionales Typdef-Feld `domain_reads` | **entschieden: angenommen mit Änderung** (R-93; Lesezugriff über `ctx$spec`/`ctx$value()` bestand, nur deklarative Angabe und Klarstellung 6.1 Nr. 3, Prüfung C3; Typenliste N-31) | 0.5 (jetzt Vertragsregel mit Tabelle `domain_reads`) |
| S01B-03 | § 12.3 | Warmmiete je vermietetem m² | **entschieden: angenommen** (R-101) | 3.8 |
| S01B-04 | § 4.12 Nr. 5 | Ausnahmen des Expandertests für Sequenzen und Rechtswerte | **entschieden: angenommen mit Änderung** (R-92; dazu deterministische Arten, Kreditbeträge, `draw_schedule`) | 4.3.3, 3.5 Nr. 9, 4.6 |
| S01B-05 | § 6.2 | Filter `measure_id` in `ctx$rows()` | **entschieden: angenommen mit Änderung** (R-93; zusätzlich `local_row` und `id` als Vektor) | 0.5 Nr. 2, 1.9.1 |
| S01B-06 | § 4.5, § 6.3 | Wachstumsknoten als Kalenderjahreswert | **entschieden: angenommen mit Änderung** (R-91; Schlüssel `index: calendar_year` (Default) bzw. `period_end` für Stichtagsgrößen wie Orakel (c); N-27) | 0.7, 3.6.2 |
| S01B-07 | § 7.6, § 12.3 | `co2_emission` = Treibhausgasbilanz aller Träger | **entschieden: angenommen** (R-101) | 3.6.4 |
| S01B-08 | § 4.3.6a, § 6.3 | Bezugsperiode „warmmietenneutral“ | **entschieden: angenommen** (R-102) | 1.9.5 |
| S01B-09 | § 4.10 | automatisch angewandte C-Teile als eigener Eintrag | **entschieden: angenommen** (R-88, „Freigabe je Teil“) | 0.9, 7.3 |
| S01B-10 | § 7.6 | Merkzeile `repayment_grant` mit `measure_id` oder `funding_id` | **entschieden: angenommen mit Änderung** (R-99, R-92; Anzeige-Tag über `bctx$value_base()`, nur deterministische Ableitungen) | 4.6 (Metafelder) |
| S01B-11 | § 4.12 Nr. 7, § 8.2 | Kreditzusage bei teilweisem Wegfall | **entschieden: angenommen** (R-99) | 4.6 |
| S01B-12 | § 10.9 | Zahlungstermin § 35c, Energieberatung | **entschieden: angenommen**, Termin über R-98 formuliert (`add_months((Y+1)-01-01, payout_delay_months)`) | 4.8 |
| S01B-13 | § 4.3.7, § 11.6 Nr. 4 | Default `approval_probability` mit Verfügbarkeit nach 2030 | **entschieden: angenommen mit Änderung** (R-86; Ableitungsregel `rule:approval_probability` statt Registry-Regel, Feld `availability_after_2030` (N-09), ohne `budget_risk` Basiswert 1, Faktor 0,7 trotzdem ab 2031) | 4.2, 5.5, 7.1 |
| **S01B-14** (neu) | § 4.3.7 (`approval_timing: auto`) | Klarstellung: `auto` = `before_start`, wenn `application_date` ≤ frühester Termin der Maßnahmen **des Instruments** (`funding.<f>.measures`), nicht „der Variante“ | Förderrechtlich bezieht sich „Vorhabenbeginn“ auf das geförderte Vorhaben; bei Stufensanierung (S4) wäre ein Instrument einer späteren Stufe sonst immer `after_start` und meldete fälschlich „förderschädlicher Vorhabenbeginn“ | **entschieden (Runde 4): angenommen** (Orchestrator-Entscheidung, R-111), ergänzt: Instrument ohne Maßnahmen bezieht sich auf den frühesten Termin aller Maßnahmen der Variante (ohne Maßnahmen `before_start`); W „förderschädlicher Vorhabenbeginn“ nur bei Antrag nach dem Termin; umgesetzt in 4.2, 4.9 Nr. 1, 5.5, F-9 |

Erledigt durch Runde 2 (frühere Anträge dieses Teils): Default der realisierten JAZ als Planwert (jetzt
`jaz_plan` mit Default Basisfallwert von `jaz`, R-70) und Kennzahlen „Warmmiete vorher/nachher“ sowie „Eigenanteil
nach Förderung“ (`warm_rent_change_prepost`, `own_contribution`, R-83).

### 10.2 Abstimmungspunkte mit Teil A, Teil C und dem Integrator (keine Änderung an Spec 00)

| Teil | Punkt | Stand Runde 4 |
|---|---|---|
| A | Aktivierungsfaktor a_m als Ausdruck je Maßnahme (0.8); dieselbe Formel im Helfer `act()` | bestätigt; `act()` liest nur Domänenpfade |
| A | PV-Nullsatz der Maßnahme (3.9.1) | entschieden: `expr`-Knoten aus `rule:measure_catalog` (R-86, X-25) |
| A | `measures.<k>.kg`, `measure_type` für den KG-Filter und die Berechtigung (4.3.1, 4.4) | abgestimmt: Teil A § 4.1 (`kg` aus dem Katalog, `measure_type`), § 4.2 |
| A | Kredittypen: Belegung der Förderkredite nach 4.6; `draw_schedule` aus Maßnahmen-Zahlungsplänen | abgestimmt: Teil A § 5.1, § 5.2 (KfW-Varianten, `approved`, `draw_schedule`), Teil B 4.6 |
| A | Struktur von `global.yaml` | entschieden: `item_defaults` (R-85); Vorlagen dieses Teils in 7.1, Vereinigung mit Teil A § 2.2 |
| A | `rule:measure_catalog` setzt `modernization_kind: none` bei Erhaltung bzw. Ohnehin-Anteil 1 (X-09); `rule:cost_from_kg` auch für Zahlungspläne mit `unit: eur` (X-28) | entschieden (N-07); Teil B setzt es voraus (1.4, 1.9.1, 4.6) |
| A | Instandhaltungssatz `effects.maintenance.share_of_cost_pa` nur Instandsetzung, Wartung in `service_eur_pa` bzw. PV-`opex` (X-10) | Teil B: W `service_double_energy` (3.2.2, 3.9.1); Katalogspalte in Teil A |
| A | Platzhalter `measures.<m>.effects.rent/vacancy/energy` entfallen; Verweis Teil A § 3.4 auf 01b § 3.10 (Haushalt) | erledigt in Teil A (Runde 3, 01a § 12.3 X-24 a, b) |
| C | eigener Eintrag `legal/mietrecht_559f_2026`; Auslegungscodes `proportional`, `flat_before_funds`, `halve_then_funds` | erledigt in Teil C |
| C | Overlay-Ziel `energy.<zustand>.jaz`; `energy.climate_neutral_2045` entfällt | erledigt in Teil C (X-24 c) |
| C | Bedingungssymbole der Fördernutzlast nach 4.3.2 (`funding.this.*`, `unit.owner_occupied`, `heating.replaced_fossil_functional`, `taxable_income_adj`); neuer Schalter `child_u18_threshold_shift_per_child` (Default `false`) | erledigt in Teil C (Runde 3: Symbole in den Nutzlasten 01c § 3.4; KfW 458 mit `child_u18_threshold_shift_per_child: false`, F-01) |
| C | Fördernutzlasten nach 7.3 (N-01, N-10, N-11, N-12, X-02), Szenarien: S1 `building.efficiency_standard_after: none` in der Basis und `eh70` in V2 (X-03), S5 V2/V2b `facts: {lca_thg: true}`, S2 V2 `{lca_thg: true, qng: true}` (N-10), S1 `rent_law: {procedure: bgb_559}` (N-06), S2 `modernization_kind: none` für Ersatz-WP und Aufzug (X-09) | erledigt in Teil C (Runde 3, 01c § 9.1, § 9.2) |
| C | S4/S5: `unit_groups.<g>.operating.recoverable_opex_eur_m2_month` ausdrücklich setzen (z. B. 0, wenn eine eigene Komponente die Nebenkosten trägt; F-11) | erledigt in Teil C (F-11: S4, S5 mit 0) |
| C | `s558.excludes_increases` enthält `bgb_560`, das nicht im Vokabular `bgb_procedure` (Spec 00 § 2.11) steht | erledigt in Teil C (`bgb_560` gestrichen, `excludes_increases: [bgb_559, bgb_559c, bgb_559e]`, N-06) |
| C | Energiepreis-Basisfall (F-08), Rebound-Vorlage (F-15), Pellets-USt (F-16), BEHG-Faktor Kohle | erledigt in Teil C (F-08, F-15, F-16; 01c § 9.2); offen nur der BEHG-Faktor Kohle (01c OP-21; 9 Nr. 13) |
| I | `rule:unit_group_defaults` enthält über N-08 hinaus die II.-BV-Verwaltung bei `bound_social` und `lease_up_months: 3` bei Neubau (5.5 Nr. 4, 5), weil beide Werte von Feldern abhängen und sonst nur Profil bzw. Expander sie trügen | bestätigt (Runde 4): N-08a (Spec 00 § 17.5.3, R-118), einschließlich der impliziten Gruppe `main` mit Bezügen; kein eigener Selbstnutzer-Default für Nebenkosten (9 Nr. 18) |
| I | Enums `heating_system_type` und `carrier_class` + `coal` (8) | Übernahme mit P0-02 (im Phase-0-Code noch offen, Spec 00 § 17.6.5) |
| I | Platzhalter `{id}` in Flow-YAML: Die Schreibweise `{ref: market.energy_price.{id}}` (Spec 00 § 4.3.6b, § 4.7) ist kein gültiges YAML (die innere `{` öffnet eine Flow-Map); in `global.yaml` und in den Beispielen von Spec 00 als `{ref: "market.energy_price.{id}"}` bzw. in Blockform schreiben | übernommen (Runde 4, R-118): Spec 00 § 4.3.6b, § 4.7 und N-04 schreiben `{ref: "market.energy_price.{id}"}` |

---

## 11. Review-Protokoll Runde 3

Grundlage: Integratorentscheidungen zu den Änderungsanträgen (Spec 00 § 17.5.1), Namens- und Eigentumsentscheidungen
N-01 bis N-31 (§ 17.5.3), Befunde der Konsistenzprüfung (X-nn) und der fachlichen Prüfung (F-nn) mit Bezug auf Teil B.
Nachrechnung der geänderten und neuen Prüfwerte mit einer skalaren Python-Referenz (Termine nach R-35/R-98,
KfW-458-Staffel, PV-Mischsatz); Ergebnis unten.

### 11.1 Übernommene Entscheidungen

| Nr. | Umsetzung in Teil B |
|---|---|
| S01B-01 … S01B-13 | 10.1 als „entschieden“ markiert; Übergangslösungen durch die Vertragsfassung ersetzt (0.5, 0.7, 1.9.1, 1.9.5, 3.1, 3.6.2, 3.6.4, 4.3.3, 4.6, 4.8, 5.5) |
| N-03 | `use: admin_per_unit_or_efh_eur_pa`, `admin_per_garage_eur_pa` (2.2, 7.1) |
| N-04, N-05 | 7.1 neu als `item_defaults` (`"unit_groups"`, `"energy"`, `"energy.carriers"` mit `{ref: market.energy_price.{id}}`, `"energy.performance_gap"`, `"energy.pv"`, `"funding"` mit `availability_after_2030: 0.7`, `"building.property_tax"`); `payout_delay_months_tax_credit` → `rule:tax_credit_defaults`; Netzentgelt „falls Marktname existiert“ → `rule:carrier_defaults`; Profiltabelle 7.2 gestrichen; Default-Spalten in 1.2, 2.2, 3.2.1, 3.2.4, 4.2 auf (G)/(AR) umgestellt; neues Quellenkürzel (AR) in 0.3 |
| N-06 | `levy_procedure` = `auto`, `bgb_559`, `bgb_559c`, `bgb_559e` mit Aliasen (1.4, 1.9.2, 1.12, 1.14, L-6, 8); `mr_levy_allowed` mit Algorithmus und Bestätigung `bgb_559c` → `bgb_559` (5.2); Prüffälle L-12, L-13 |
| N-07, N-29 | neuer Abschnitt 5.5 (Ableitungsregeln WS-A); `fund_approval_*` aus dem Regelkatalog gestrichen (5.1, 5.4); Eigentum und Testdateien in 5.1; Kopfzeile „Status“ angepasst; Knotenerkennung bei `vofi_build()` = WS-D (4.9 Nr. 2) |
| N-08 | Inhalt von `rule:unit_group_defaults` (5.5) wörtlich; ergänzt um implizite Gruppe, II.-BV-Verwaltung bei `bound_social` und Lease-up bei Neubau (Bestätigung erbeten, 10.2) |
| N-09 | Feld `funding.<f>.availability_after_2030` (4.2, 5.5, 7.1) |
| N-10 | Fakten `lca_thg` (Berechtigung) und `qng` (Deckel) (4.2, 4.3.1, 4.3.2, 4.4); F-13 erweitert |
| N-11 | `loan.max_share_of_eligible_costs` ausdrücklich (4.2, 4.6) |
| N-12 | Kumulierungsprüfung über die ganze `from:`-Kette und `program_code`, beidseitig (4.11, 4.8); F-12 erweitert |
| N-13 | Monatsintervall (b₀ + (m − 1), b₀ + m] und Datumstermine (0.4, 4.5, 4.6, 4.8); F-1, F-7, F-8, F-16 und Vertragsbeispiel `grant` neu |
| N-14, N-23 | id-Höchstlängen Gruppen 25, Instrumente 30, Zustände 12, Träger 20 (1.2, 1.6 Nr. 8, 3.1, 3.2.2, 3.5 Nr. 11, 4.1) |
| N-15, N-16 | zehn kanonische Träger mit Marktpreis, Netzentgelt-Wachstum über `shared.network_fee_growth_<c>` (3.2.1); PV-Ausdruck mit `partial_40_100kwp` (3.9.1, PV-1a) |
| N-17 | Validierungsschlüssel `validation.<block>.<code>` (0.3, 1.14, 8) |
| N-18 | Testdateinamen `test-<R-datei>.R` (1.15, 2.2, 2.3, 3.11, 4.12, 5.1, 7.1) |
| N-19 | `mr_levy_allowed`, `co2_section43`: `returns: value`; Aufruf mit allen Formals (1.6 Nr. 4, 1.9.2, 3.7.4, 5.1) |
| N-22 | Label `foerderstopp` „Förderstopp: keine Förderzusage“ (4.9 Nr. 6, 7.1) |
| N-27 | Verweis auf die Wachstumsform als Kalenderjahreswert (0.7) |
| N-28 | `ghg_factor_kg_kwh`: Fortgeltung mit `valid_to: null`, O über `as_of` (3.2.1, 7.3) |
| N-31 | `domain_reads` je Typ (0.5 Nr. 3); `act()` ohne Lesen von Komponentenparametern (0.8); Energietypen mit Parameter `construction_delay_months` statt Lesen von `project` (3.4, 3.5 Nr. 10, 3.6.1, 3.6.2) |
| R-91 (X-12) | Code-Symbole in Förderbedingungen nur in Vergleich und Logik (4.3.2) |
| R-92 | Ausnahmen des Expandertests und `bctx$value_base()` für `draw_schedule` und Anzeige-Tag (4.6) |
| R-105 | Verschiebungen ≥ 0 (6) |
| N-01, N-02, N-20, N-21, N-24, N-25, N-26, N-30 | betreffen Teil A bzw. C; in Teil B nur Verweise (4.3.1 Codes der Nutzlast) bzw. keine Änderung |

### 11.2 Befunde

| Befund | Ergebnis | Umsetzung bzw. Begründung |
|---|---|---|
| X-01 | gültig, Teil B unverändert E | 4.3.1: Codes der Nutzlast ⊆ Vokabular (Test in `test-library.R`); Korrektur der Listen in Teil C (N-01) |
| X-02 | gültig | 4.2, 4.3.3: Degression auf mit `~` entfernten Baustein → I statt E; F-4a (Deckel 150.250) |
| X-03 | gültig für Teil C | 3.2.6, 4.3.1: Meldungstext und Hinweis, dass die Basis den Pfad tragen muss; Korrektur S1 in Teil C |
| X-04 | gültig | wie N-10 (4.3.1, 4.3.2, 4.4, F-13) |
| X-05 (b) | gültig | wie N-03 (7.1); (a) betrifft Teil A |
| X-06 | gültig | wie N-04, N-05, N-08 (5.5, 7.1) |
| X-07 | gültig | wie N-07 (4.9, 5.1, 5.4, 5.5); WS-D statt WS-G für `vofi_build()` |
| X-08 | gültig | wie N-06 |
| X-09 | gültig für Teil A/C | 1.4: Voraussetzung `modernization_kind: none` bei Erhaltung dokumentiert; Umsetzung in `rule:measure_catalog` (Teil A) und S2 (Teil C) |
| X-10 | gültig | 3.2.2, 3.9.1: Abgrenzung Wartung (Teil B) / Instandsetzung (Teil A), W `validation.maintenance.service_double_energy` |
| X-11 | teilweise (wie Spec 00) | eine Konvention nach R-98: Monatsintervall nach Spec 00 § 3.4 (0.4), Einmalzahlungen als Datumstermin (4.5, 4.6, 4.8); der Vorschlag „Monatsereignis in p(m)“ entfällt |
| X-12 | gültig (Spec 00) | 4.3.2 Verweis auf R-91 |
| X-16 | gültig | 1.6 Nr. 2, 2.3: `u_<g>_property_tax` nur bei Betrag bzw. Messbetrag und Hebesatz; sonst I/W; O-7a |
| X-17 | gültig | wie N-11 |
| X-18 | gültig | wie N-12 |
| X-20 | gültig | wie N-23 |
| X-21 (b, c) | gültig | wie N-19; außerdem `fund_degression`, `fund_income_rate`, `fund_staffel_cap` mit `returns: value` (5.1), weil sie Einzel- bzw. Tabellenwerte liefern |
| X-23 | gültig | wie N-17; Expander-Meldungen unter `expand.<expander>.<code>` (`inst/labels/de/expand.yaml`, Spec 00 § 2.4) |
| X-24 (c–f) | gültig | (c) Behauptung im früheren Abschnitt 7.4 gestrichen (jetzt 7.3); (d) PV-Ausdruck (3.9.1); (e) „ohne Wirkung“ nach Teil C (7.2); (f) Label nach Teil C (7.1) |
| X-25 | gültig | 3.9.1: PV-USt-Default als `expr`-Knoten aus `rule:measure_catalog`, nicht Expander; PV-4 erweitert |
| X-28 | gültig für Teil A | 1.4, 1.9.1, 4.6: `measures.<m>.cost_eur` existiert immer (`rule:cost_from_kg`) |
| X-29 | gültig | wie N-28 (3.2.1, 7.3, 9 Nr. 13) |
| X-32 | gültig | wie N-15 (3.2.1); Marktpreise `lpg`, `power_mfh` in Teil A/C |
| X-33 | gültig (Spec 00) | 3.1 und 4.1 entsprechen der neuen Tabelle Spec 00 § 4.12 |
| F-01 | **gültig** | Memo 02 § 5.2 („Grenzen pauschal +10.000 EUR“ mit Kind) und Memo 07 § 1 („bei mind. einem minderjährigen Kind“) bestätigen eine einmalige Verschiebung: `taxable_income_adj` mit min(n, 1) (4.3.2), Schalter `child_u18_threshold_shift_per_child`, Prüffall F-2a (15.680,00; je Kind 19.600,00 nach Höchstsatz 0,70). Die Rechnung im Befund (21.280) übersah den Höchstsatz 0,70 |
| F-02 | **gültig** | Oberbegriff `privatperson` umfasst `privatperson_vermieter` (4.3.1); alle Einträge, die nur `privatperson` nennen, verlangen bereits `owner_occupied` (geprüft in Teil C: KfW 297, 300, 358 und § 35c); Prüffall F-6b |
| F-04 | gültig | wie X-02 |
| F-06 | gültig | wie N-10 (Faktum `lca_thg` statt `lca_qng_plus`) |
| F-07 | gültig | wie N-13 |
| F-08 | gültig, **nicht in Teil B umgesetzt** | Zuständigkeit Teil C (Spec 00 § 17.3 Nr. 8 c); 3.2.5 verweist darauf, 9 Nr. 21 |
| F-11 | gültig | Bedeutung der Pauschale präzisiert, W `validation.unit_groups.owner_opex_double` (2.2); ein eigener Selbstnutzer-Default ist nicht eingeführt, weil N-08 den Inhalt von `rule:unit_group_defaults` festlegt (9 Nr. 18, 10.2); Korrektur in S4/S5 an Teil C |
| F-12 | gültig | L-2 als synthetischer Aggregatfall gekennzeichnet; Hinweis zur Näherung bei `heating_part_share` (1.4) |
| F-15 | gültig, Variante „Konvention dokumentieren“ | Default 1,1 hätte S1–S5 verändert (S1 setzt Bedarf „inkl. Rebound“); 3.2.4: `demand_kwh` enthält den Rebound, W `rebound_base_differs`, E-12; Bibliotheksvorlage an Teil C |
| F-16 | gültig | `vat_rate` 0,19 auch für Pellets (3.2.1, 7.1); Neurechnung der Bibliothekswerte in Teil C |
| F-17 | gültig | wie N-03 |
| F-18 | gültig | Trägerklasse `coal`, Feld `building.heating_existing.type` (`floor` = Gasetagenheizung), Symbol erweitert (3.2.1, 3.2.6, 4.3.2, 8); Prüffall F-17 (12.880,00 bzw. 8.400,00) |
| F-20 | gültig | wie N-12 |

Zusätzlich in Runde 3 festgestellt: Die Vorlagen-Schreibweise `{ref: market.energy_price.{id}}` aus Spec 00
(§ 4.3.6b, § 4.7) lässt sich als YAML nicht laden; 7.1 quotet den Pfad, der Hinweis steht in 10.2.

Abgelehnt wurde in Teil B kein Befund. Nicht in Teil B umgesetzt (Zuständigkeit anderer Teile): F-08 und die
Datenkorrekturen zu X-01, X-03, X-09, X-28, X-32, F-11, F-15 (Bibliotheksvorlage), F-16 (Bibliothekswerte).

### 11.3 Nachgerechnete Prüfwerte

| Prüfwert | Rechnung | Ergebnis |
|---|---|---|
| F-1 | Termin add_months(2027-10-01, 3) = 2028-01-01, `grid_period_of` → t = 1 | Periode 2027 (bisher 2028), Betrag 45.300,00 unverändert |
| F-7 | Termin 2028-01-01 (lag 3) → t = 1; lag 6 → 2028-04-01 → t = 2 | Periode 2027 bzw. 2028, Betrag 144.400,00 unverändert |
| F-8 | Termine 2030-01-01, 2031-01-01, 2032-01-01 → t = 3, 4, 5 | Perioden 2029 / 2030 / 2031 (unverändert) |
| F-16 | 2028-10-01 → t = 2; 2029-01-01 → t = 2 | beide Periode 2028 (bisher 2028 bzw. 2029) |
| Vertragsbeispiel `grant` | Termin = Stichtag 2027-01-01 | t = 0 (bisher „erste Periode“) |
| F-2a | adj = 48.000 → 0,10; 0,56 · 28.000; je Kind adj 38.000 → 0,30, min(0,76; 0,70) · 28.000 | 15.680,00; 19.600,00 |
| F-4a | 27.250 + 5 · 15.000 + 6 · 8.000 | 150.250 |
| F-6b | 0,30 · 28.000 | 8.400,00 |
| F-17 | 0,46 · 28.000; 0,30 · 28.000 | 12.880,00; 8.400,00 |
| PV-1a | (10 · 0,0770 + 30 · 0,0666 + 20 · 0,0545)/60 = 0,0643; 45.600 kWh · 0,0643; 100 kWp: 0,06038 | 2.932,08; 0,0603800 |
| PV-1 (Kontrolle) | unverändert | 0,0700667; 1.324,26; 1.320,29 |

Alle übrigen Prüfwerte (RP-*, L-*, O-*, C-*, E-*, TC-*, H-*, F-2 bis F-6a, F-9 bis F-15) sind von den Änderungen nicht
betroffen: Laufende Wirkungen bleiben beim Monatsindex mi(d), und die Defaultwerte sind unverändert, nur ihr Ort ist
neu (Ausnahme `vat_rate` der Pellets 0,07 → 0,19, die kein Prüfwert dieses Teils verwendet).

---

## 12. Review-Protokoll Runde 4 (Restbefunde, 26.10.2026)

Grundlage: Spec 00 §17.6 (Befunde K3-01 bis K3-19, Antrag S01B-14, Abstimmungspunkte aus 10.2, Auflösungen R-110
bis R-119, Ergänzung N-08a). K3-01 und K3-02 folgen Orchestrator-Entscheidungen.

| Punkt | Entscheidung | Umsetzung in Teil B |
|---|---|---|
| K3-01 (R-110) | Terminparameter heißen `start_event` | 2.2 (`operating_cost`), 3.2.2 (`energy.<zustand>.start_event`, E bei Schlüssel `from`), 3.2.3, 3.4, 3.5 Nr. 1, 3.10.2, 3.10.3, 4.2 (`interest_subsidy.start_event`), 4.7, 6 |
| K3-02, S01B-14 (R-111) | angenommen: Bezug Maßnahmen des Instruments, ohne Maßnahmen die der Variante; W „förderschädlicher Vorhabenbeginn“ hängt am Antragsdatum | 4.2 (`application_date`, `approval_timing`), 4.9 Nr. 1, 5.5, F-9 (Fälle S4, S3 V2, `rent_binding`), 9 Nr. 23, 10.1 |
| K3-05 (R-119) | Statusvermerke aktualisiert | 10.2 (Spalte „Stand Runde 4“), 9 Nr. 21, 22, 24 |
| K3-09 (R-118) | Teilbäume einer Vorlage entstehen mit ihrem Block | 7.1 |
| K3-10 (R-118, N-08a) | bestätigt; Schritt (0) mit Bezügen statt Kopien | 1.6 Nr. 1, 5.5, 9 Nr. 18 (kein eigener Selbstnutzer-Default), 10.2 |
| K3-11 (R-118) | Standard-Sets nur in Teil C §4.2 | 7.1 (Verweis statt Kopie) |
| K3-16 (R-116) | Auslegungs-Defaults bleiben (R) aus `legal/mietrecht_2026` | 7.1 (Kommentar); 1.3 unverändert |
| S01A-10 (R-112) | `set`/`overrides` auf Vorlagenfelder zulässig | 7.1 (Kopf) |
| Zusatzprüfung (R-119) | `approved: 1` als Vorlage; Rebound-Vorlagen nach Teil C §2.7 | 4.2, 7.1; 3.2.4, E-12 |

Prüfwerte: F-9 und E-12 erweitert, alle übrigen unverändert. Phase-0-Nacharbeit aus Sicht von Teil B (Spec 00
§17.6.5): P0-02 (Enums aus 8, u. a. `carrier_class` mit `coal`, `heating_system_type`) ist im Code noch offen.
