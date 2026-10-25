# Spezifikation 01, Teil B: Feldkatalog Erlöse und Mietrecht, Bewirtschaftung, Energie und CO₂, Förderung

| | |
|---|---|
| **Projekt** | VoFi-Werkzeug (R-Paket `vofi`) für Neubau und energetische Sanierung, Wohnungswirtschaft und Privatpersonen |
| **Dokument** | `docs/spec/01b_feldkatalog_betrieb_energie_foerderung.md` |
| **Teil von** | Spec 01 (Feldkatalog). Teil A (`docs/spec/01a_…`): Szenario, Projekt, Gebäude, Maßnahmen/Capex, Ersatzinvestitionen, Finanzierungsinstrumente, Konten, Restwert, globale Defaults und Profile. Teil C (`docs/spec/01c_…`): Stochastik-Overlay, Bibliothekseinträge, Szenario-Sets, Referenzszenarien S1–S5. |
| **Vertragsbasis** | Spec 00 (`docs/spec/00_kernvertraege.md`, `contract_version = "1.0.0"`, `schema_version = 1`) |
| **Stand / Rechtsstand** | 25.10.2026 |
| **Status** | Entwurf zur Integration. Verbindlich für WS-E (Typen `rent_path`, `operating_cost`, `property_tax`, `energy_cost`, `co2_cost`, `tenant_costs`, `pv`, `imputed_rent`; `rules-mietrecht.R`, `rules-co2kostaufg.R`), WS-E2 (Expander `unit_groups`, `energy`, `funding`, `household`; Typen `grant`, `tax_credit_35c`; `rules-funding.R`), WS-A (Defaults der hier definierten Felder), WS-L (Bibliotheksnutzlast `funding/*`, `prices/energy_*`, `costs/bewirtschaftung_*`), WS-B (Validierungsregeln), WS-D2/WS-H (Eingangsdaten der Mieter- und Haushaltssicht) |
| **Grundlagen** | Spec 00 §§ 3, 4.3, 4.9–4.12, 5, 6, 7, 8.2, 9.11, 10.9, 11.6, 12, 16.3, 17.3, 17.4 (Stand Runde 2, Beschlüsse R-66 bis R-84); Teil C §§ 1.9, 2.7, 3.4–3.6 (Nutzlast der Bibliothekseinträge); Konzept §§ 3.5–3.9, 11.2 (F13, F14, F15, F16), 11.3 (B1–B3, B7, B8, B12), Review-Protokoll; Memo 02 §§ 1.6–1.9, 2, 3, 4, 5 (insb. § 5.8), 9; Memo 03 §§ 2, 3, 7, 8, 9, 11; Memo 04 § 1.2; Memo 06 §§ 3.2, 3.4, 8; Memo 07 §§ 1, 4, 5.4; `docs/recherche/prototypen/vofi_referenz/mietpfad_ref.py` |

> **Lesehinweis.** Teil B legt Felder, Defaults, Algorithmen und Ledger-Zeilen der Erlös-, Bewirtschaftungs-, Energie-
> und Fördertypen fest. Er bewegt sich **innerhalb** der Strukturen von Spec 00 und ändert sie nicht. Wo Spec 00 eine
> Lücke lässt, steht hier eine Übergangslösung, und Abschnitt 10 enthält den zugehörigen Änderungsantrag
> (`S01B-nn`). Alle Prüfwerte in den Testabschnitten sind mit einer unabhängigen skalaren Python-Referenz nach diesem
> Dokument nachgerechnet (Toleranz 0,01 EUR bzw. 1e-6 bei Raten); wo sie Memo 02 oder Memo 07 entnommen sind, ist
> die Konzept-Korrektur (F13, F14) eingearbeitet.

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
   `approved` und `repayment_grant.cut_share` der Förderkredite (4.6) und das Set `foerderstopp` (7.3). Das Feld
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
  (Schicht 1), **(P)** Perspektiven-Profil (Schicht 2), **(B)** Bibliothekseintrag, **(R)** Rechtsstand
  (Rechtsparameter aus `ctx$legal(<thema>)` bzw. Regel über `ctx$rule()`, 0.9), **(A)** abgeleitet (Expander bzw. Typ berechnet den Default aus anderen Feldern; Ableitung in der
  Spalte Bedeutung).
- Validierungskürzel: **E** Validierungsfehler (`vofi_error_validation`), **W** Plausibilitätswarnung
  (`vofi_warning_plausibility`), **I** Hinweis (`vofi_inform`), **O** `vofi_warning_library_outdated`. Meldungs-
  schlüssel stehen unter `validation.b.<feld>` (WS-B) bzw. `types.<kind>.<name>.msg.<code>` (Typ).
- Felder vom Typ `value` sind stochastisch zulässig (Overlay-Ziel), sofern nicht „det.“ (deterministisch,
  `deterministic_only = TRUE`) vermerkt ist. `enum`, `int`, `lgl`, `date`, `timing`, `ids`, `chr` sind immer
  deterministisch (Spec 00 § 5.4).
- Collections mit Nutzer-ids (z. B. `levy_history`, `rate_components`) sind **Maps nach id**, nie Listen, damit jedes
  numerische Blatt adressierbar ist (Spec 00 § 4.4 Nr. 3, § 4.12 Nr. 2).

### 0.4 Monatsrechnung (verbindlich für `rent_path`, `pv`, Termine)

- **Monate.** M = `month_end[T+1]`. Monat m (m = 1…M) umfasst [b₀ + (m−1) Monate, b₀ + m Monate), b₀ =
  `valuation_date`. Monat m gehört zur Periode p(m) = min{t : M_t ≥ m} und zum Kalenderjahr y(m). Monate m ≤ 0 sind
  Historie vor dem Stichtag.
- **Monatsindex eines Datums.** mi(d) = 12·(Jahr(d) − Jahr(b₀)) + Monat(d) − Monat(b₀) + 1 für Monatserste d. Ein
  Datum, das kein Monatserster ist, wird auf den **folgenden** Monatsersten gerundet (Wirkungen beginnen mit vollen
  Monaten). „Wirksam ab d“ heißt: alle Monate m ≥ mi(d).
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

### 0.5 Domänenlesezugriff (Übergangsregel, Änderungsantrag S01B-02)

Die Typen `rent_path`, `grant` und `tax_credit_35c` verarbeiten eine **variable Zahl** von Maßnahmen bzw.
Förderinstrumenten. Spec 00 lässt keine Typparameter mit dynamischen Namen zu. Deshalb gilt:

1. Der Typ erhält die beteiligten ids als Parameter der Art `ids` (z. B. `rent_law_measures`, `funding_ids`) und liest
   deren Daten über **Domänenpfade**: numerische Blätter mit `ctx$value("measures.<id>.…")` (Ziehungen und Overlay
   wirken, Spec 00 § 6.3), Basisfallwerte mit `ctx$value_base()` (R-70), nicht-numerische Blätter (Daten, Codes,
   Flags) aus `ctx$spec` (nur lesen, Spec 00 § 6.2). Dasselbe gilt für die internen Helfer `act()` (0.8),
   `rp_vacancy_share()` (1.8.4) und `en_state_weights()` (3.4); sie lesen nur Domänenpfade, nie Komponenten.
2. Ergebnisse anderer Komponenten liest der Typ ausschließlich über `ctx$component(id)` (inkl. Zeilen-Metadaten wie
   `measure_id`); jede solche id steht zusätzlich in `after` der Komponente (Spec 00 § 6.1 Nr. 3).
3. Der Vertragstest (Spec 00 § 5.6, F1–F10) läuft mit einem `example`, dessen id-Listen leer sind (reiner Mietpfad,
   reiner Zuschuss mit `eligible_cost_eur`). Die Maßnahmenlogik testet die eigene Testdatei des Typs mit
   `eng_context_from_parts(grid, spec, …)` und einer Mini-Spezifikation mit Domänenblöcken.
4. Domänenlesezugriffe sind auf die Blöcke `measures`, `funding`, `financing`, `energy`, `unit_groups`, `building`,
   `household`, `market` beschränkt und dürfen nie endogene Größen lesen (Spec 00 § 4.5 Regel 2).

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

### 0.8 Aktivierungsfaktor und Basisfallwerte (Spec 00 § 4.12 Nr. 7, § 6.3, R-70, R-71)

- **Aktivierungsfaktor.** Für jede Maßnahme k gilt a_k = `measures.<k>.active` × Π_f `funding.<f>.approved` über
  alle Instrumente f mit `on_reject: drop_measures` und k ∈ `funding.<f>.measures`. Teil A bildet a_k im
  Maßnahmen-Expander als `expr`-Knoten für die Kostenkomponenten. Die Typen dieses Teils werten a_k über den
  internen Helfer `act(ctx, k)` aus (`R/type-flow-rent-path.R`, WS-E; dieselbe Formel über `ctx$value()` der
  genannten Pfade, n-Vektor). Die Expander dieses Teils schreiben a_k als `expr`-Knoten, wo ein Parameter den Faktor
  direkt trägt (Zuschüsse, Tilgungszuschuss, PV).
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
  dieses Teils (Abschnitt 5). Regeln lesen weder `ctx` noch die Bibliothek; der Typ übergibt die Nutzlast des
  Themas (`ctx$legal(<thema>)`) an eine Abbildungsregel (`mr_params`, `co2_params`, `fund_35c_params`), deren
  Ergebnis P als letztes Argument an die übrigen Regeln geht. Im Text dieses Teils sind Aufrufe ohne das letzte
  Argument P geschrieben.
- **Themen dieses Teils:** `mietrecht` (§§ 536, 556d–556g, 557a, 557b, 558, 559–559e BGB), `mietrecht_559f`
  (§ 559f BGB, Qualität C), `co2kostaufg`, `bio_treppe`, `emission_factors_co2cost`, `emission_factors_geg`,
  `umsatzsteuer` (nur PV-Nullsatz, 3.9.1). Das Thema `mietrecht_559f` ist ein eigener Eintrag, weil die
  Freigaberegel je Eintrag gilt (Abstimmung mit Teil C, Abschnitt 9).
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

| YAML-Pfad (`unit_groups.<g>.`) | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `label` | chr | – | id | nein | – | Anzeigename | – |
| `n_units` | int ≥ 1 | WE | – | ja | E < 1; W Σ Gruppen ≠ `building.n_units` | Anzahl Wohneinheiten der Gruppe | 02 §1.1 |
| `living_area_m2` | num > 0 | m² | – | ja | E ≤ 0; W Σ Gruppen weicht > 1 % von `building.living_area_m2` ab | Wohnfläche (WoFlV) der Gruppe; Bezug aller €/m²-Größen | 02 §9.2 |
| `owner_occupied` | lgl | – | `false` (G); `true` (P `selbstnutzer`) | nein | E widerspricht `rent_regime` | selbstgenutzte Gruppe: kein Mietpfad, volle Kostenwirkung | 02 §1.11 |
| `rent_regime` | enum:rent_regime | – | `paragraph_558` (G); `cooperative_fee` (P `wu_genossenschaft`); `owner_occupied`, wenn `owner_occupied` | nein | E unbekannter Code | Mietregime: `paragraph_558`, `staffel`, `index`, `bound_social`, `cooperative_fee`, `owner_occupied` | 02 §2, §9.5 |
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
| `levy_history` | map id → {`effective_date` date, `eur_m2_month` num, `heating` lgl, `procedure` enum:levy_procedure} | – | `{}` | nein | E Datum nach Stichtag | Umlagen der letzten 6 Jahre vor dem Stichtag (Kappungsfenster § 559 Abs. 3a; § 559c-Sperre); Beträge sind in `rent_eur_m2_month` enthalten | 02 §2.3 |
| `market_rent_eur_m2_month` | value | EUR/m²·Monat | `null` | nein | W < Miete · 0,7 | Neuvertragsmiete am Markt zum `market_rent_base_date`; `null` schaltet die Wiedervermietungslogik ab | 02 §2.8 |
| `market_rent_growth` | value (Rate) | 1/a | `{ref: market.rent_growth_new}` (G) | nein | – | Wachstum der Neuvertragsmiete | 07 §4.0 |
| `market_rent_base_date` | date | – | `valuation_date` (T) | nein | – | Bezugsdatum der Marktmiete | – |
| `turnover_rate_pa` | value (share) | 1/a | 0,08 (G) | nein | W > 0,25 | Fluktuation (Mieterwechsel je WE und Jahr) | 03 §11; Konzept 3.7 |
| `relet_vacancy_months` | value (num ≥ 0) | Monate | 0 (G) | nein | W > 0 und `vacancy_rate` > 0 („Doppelzählung prüfen“) | zusätzlicher Leerstand je Mieterwechsel; 0 = im strukturellen Leerstand enthalten | 03 §11 |
| `first_use_after_2014_10_01` | lgl | – | (A) `true`, wenn `project_type` ∈ {`neubau`, `erwerb_neubau`} oder `building.construction_year` ≥ 2015 | nein | – | Neubauausnahme der Mietpreisbremse (§ 556f S. 1) | 02 §2.8 |
| `vacancy_rate` | value (share, Pfad) | – | 0,025 (P `wu_*`, `kleinvermieter`; Memo 03 § 11 „Deutschland-Mittel“); 0 (P `selbstnutzer`) | nein | E > 1; W > 0,15 | struktureller Leerstand (Anteil der Fläche) | 03 §11 |
| `rent_default_rate` | value (share, Pfad) | – | 0,01 (G; 0 bei `selbstnutzer`) | nein | W ≥ 0,02 und `vacancy_rate` > 0 („Mietausfallwagnis 2 % gehört in den Restwert“) | Forderungsausfall auf die Sollmiete | 03 §11; 07 S1 |
| `extra_loss_share` | value (share, Pfad) | – | 0 (T) | nein | E > 1 | sonstiger Erlösverlust je Periode (z. B. Erstvermietungsabschlag S2, Minderung S1 als Jahresanteil) | 07 S1, S2 |
| `lease_up_months` | value (num ≥ 0) | Monate | (A) 3 bei Neubau (Memo 03 § 11), sonst 0 | nein | W > 12 | Anlaufleerstand ab `rent_start`, linear abnehmend (1.8.6) | 03 §11 |
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
`delay_months`, `useful_life_years`, `measure_type`.

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
| `procedure` | enum:levy_procedure | – | `auto` (T) | nein | E `559e` bei Kind ≠ `bgb_555b_1a`; W `559` trotz Drittmitteln bei `bgb_555b_1a` | `auto`, `559`, `559c`, `559e` (Verfahrenswahl 1.9.2) | 02 §2.3–2.5 |
| `maintenance_share_method` | enum:maintenance_method | – | `auto` (T) | nein | E Methode ohne Pflichtangaben | Erhaltungsanteil IH (§ 559 Abs. 2): `auto`, `linear_wear`, `fixed_share`, `ohnehin`, `none` (1.9.1) | Konzept 3.3; 02 §1.4 |
| `maintenance_share` | value (share) | – | `null` | bedingt (`fixed_share`) | E > 1 | fester Erhaltungsanteil der Kosten | 02 §1.4 |
| `fictitious_maintenance_cost_eur` | value | EUR (Preisstand der Maßnahme) | (A) Ohnehin-Kosten der Maßnahme (`ohnehin_cost_eur` bzw. `ohnehin_share · cost_eur`) | bedingt (`linear_wear`) | W > `cost_eur`; W > Ohnehin-Kosten („Obergrenze“, Konzept 2.6) | fiktive Erhaltungskosten der erneuerten Bauteile | 02 §1.4 |
| `component_age_years` | value (num ≥ 0) | a | `null` | bedingt (`linear_wear`) | E < 0 | Alter des ersetzten Bauteils bei Fertigstellung | 02 §1.4 |
| `component_life_years` | value (num > 0) | a | (A) `measures.<k>.useful_life_years` | nein | E ≤ 0 | Nutzungsdauer des ersetzten Bauteils | 03 §9 |
| `heating_part_share` | value (share) | – | (A) 1 bei `bgb_555b_1a`, sonst 0 | nein | W > 0 bei Kind ∉ {`bgb_555b_1`, `bgb_555b_1a`} | Kostenanteil „Einbau einer Heizungsanlage“ für die Teilkappung 0,50 €/m² (F14) | Konzept F14 |
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

1. **Implizite Gruppe.** Ist `unit_groups` leer und `perspective = selbstnutzer`, rechnet der Expander mit einer
   impliziten Gruppe `main` (`n_units` = `building.n_units`, `living_area_m2` = `building.living_area_m2`,
   `owner_occupied = true`). Ist `unit_groups` leer bei anderen Perspektiven, entstehen keine Mietkomponenten (I).
2. **Je vermietete Gruppe g** (`owner_occupied = false`) entsteht `u_<g>_rent` (Typ `rent_path`, `label` = Label der
   Gruppe). Je Gruppe entstehen zusätzlich `u_<g>_opex` und `u_<g>_property_tax` (Abschnitt 2), bei selbstgenutzten
   Gruppen mit `imputed_rent_eur_m2_month` zusätzlich `u_<g>_imputed_rent` (Abschnitt 3.10).
3. **Belegung der Parameter.** Numerische Parameter erhalten `{ref: unit_groups.<g>.<feld>}` (bzw. den Pfad im
   Teilbaum `rent_law`), deterministische Felder (Daten, Codes, Flags) werden als normalisierte Werte übernommen
   (Spec 00 § 4.12 Nr. 2). Fehlt ein Domänenfeld, gilt der Typ-Default (Schicht 0).
4. **Mietrechtlich relevante Maßnahmen** `rent_law_measures` = alle k mit g ∈ `measures.<k>.rent_law.unit_groups`
   und `modernization_kind ≠ none`. Für jedes k bestimmt der Expander deterministisch, ob eine Umlagezeile entsteht
   (`levy_<k>`): (a) `measures.<k>.rent_law.levy = auto`, (b) `unit_groups.<g>.rent_law.modernization_levy = auto`,
   (c) `bctx$rule("mr_levy_allowed")(kind, rent_regime, landlord_responsible, procedure)` ist für mindestens ein
   Verfahren wahr (Spec 00 § 4.12 Nr. 5). Ist eine Bedingung verletzt, entsteht keine Umlagezeile (I mit Grund,
   `expand.levy_excluded`); die Maßnahme bleibt in `rent_law_measures`, weil ihre Drittmittel die § 558-Erhöhungen
   kürzen (1.10). Der Typ wiederholt die Prüfung (c) zur Laufzeit je Phase (Staffel, Bindung). Die Zugehörigkeit
   hängt nicht vom Aktivierungsfaktor ab (a_k wirkt zur Laufzeit, 0.8).
5. **Abhängigkeiten.** `cost_components` = alle von Teil A erzeugten Komponenten mit Typ `capex` und Metafeld
   `measure_id` ∈ `rent_law_measures`. `grant_components` = `f_<f>_grant` für alle `funding.<f>` mit `instrument_type =
   grant`, `measures` ∩ `rent_law_measures` ≠ ∅ und `rent_law.grant_counts_as ≠ none` (die ids entstehen später im
   Expander `funding`; die Existenz prüft Validierungsebene 3 nach allen Expandern). `funding_ids` = alle `funding.<f>`
   mit `instrument_type` ∈ {`loan`, `loan_with_repayment_grant`, `interest_subsidy`}, Bezug auf `rent_law_measures` und
   `rent_law.loan_counts_as ≠ none`. `after` = `cost_components` ∪ `grant_components` (∪ `e_tenant` nach Nr. 7).
6. **Mietbindung.** Gibt es `funding.<f>` mit `instrument_type = rent_binding` und g ∈ `funding.<f>.unit_groups`,
   setzt der Expander `rent_regime = bound_social`, `rent_eur_m2_month = {ref: funding.<f>.rent_binding.rent_eur_m2_month}`,
   `bound_increase_pa = {ref: funding.<f>.rent_binding.increase_pa}` und `binding_end` = Bindungsbeginn +
   `rent_binding.years` (Bindungsbeginn = `rent_start`; Datum, deterministisch). Ist `approval_probability < 1`, folgt W
   („Mietbindung wird unabhängig von der Zusage angesetzt; Entscheidungsknoten mit Ausweichvariante verwenden“).
7. **Warmmietenneutrale Umlage.** Bei `rent_law.voluntary_cap_mode = warm_rent_neutral` setzt der Expander
   `tenant_cost_component: e_tenant` und nimmt `e_tenant` in `after` auf (die id entsteht im Expander `energy`;
   Existenzprüfung wie Nr. 5). Kein Zyklus, weil `energy_cost` den Leerstand über den Helfer `rp_vacancy_share()`
   aus der Domäne bestimmt (3.6.2).
8. **Validierung im Expander** (sammelnd): Mietpfad ohne `rent_eur_m2_month` (E), OVM-Modus ohne OVM (E), `staffel`
   ohne Schritte (E), `rent_law_measures` einer Gruppe mit `rent_regime = bound_social` (I, keine Umlage), Mieterstrom
   (`components` vom Typ `custom_series` mit Label- oder Kategoriebezug `energy_income`) ohne Warnhinweis (W, C10).

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
Kostenanteil a_u = a_g · A_u / A_g; die Zeilen sind die Summen über u. Kappung (2 € bzw. 3 €, Schwelle 7 €) und
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
| K_k | aufgewendete Kosten brutto, nominal: −Σ_t Σ Zeilen der `cost_components` mit `category = capex` und `measure_id = k` (realisiert, inkl. Preisindex und Verschiebung) |
| K⁰_k, ρ_k | K⁰_k = `ctx$value("measures.<k>.cost_eur")` (Preisstand der Maßnahme); ρ_k = K_k / K⁰_k (1, falls K⁰_k = 0) |
| o_k | Ohnehin-Quote: `ohnehin_cost_eur / cost_eur` bzw. `ohnehin_share` (Teil A), begrenzt auf [0, 1] |
| IH_k | Erhaltungsanteil nach `maintenance_share_method`: `ohnehin`: o_k · K_k; `linear_wear`: `fictitious_maintenance_cost_eur` · ρ_k · pmin(1, `component_age_years` / `component_life_years`) (fiktive Kosten Default o_k · K⁰_k); `fixed_share`: `maintenance_share` · K_k; `none`: 0. `auto`: `linear_wear`, wenn `component_age_years` gesetzt; sonst `ohnehin`, wenn o_k > 0 (I „Erhaltungsanteil = Ohnehin-Vollkosten, Obergrenze“); sonst 0 (I) |
| a_k | Kostenanteil der Gruppe: `rent_law.allocation[g]`, sonst A_g / Σ_{g' ∈ unit_groups_k} A_{g'} |
| G_k | Zuschüsse: Σ_t Σ Zeilen der `grant_components` mit `category = grant` und `measure_id = k` (bereits × `approved`, Abschnitt 4.5) |
| w_{f,k} | Anteil des Förderkredits f an Maßnahme k: K_k / Σ_{j ∈ funding.<f>.measures} K_j (gleichverteilt, falls Summe 0) |
| TZ_k | Tilgungszuschüsse (Zuschuss i. S. d. § 559a Abs. 1): a_k · Σ_f w_{f,k} · TZ_f mit TZ_f = (`repayment_grant.share` · D_f bzw. `repayment_grant.amount_eur`) · approved_f · `repayment_grant.approved` · (1 − `repayment_grant.cut_share`); D_f = `ctx$value_base("financing.f_<f>_loan.amount_eur")` (Zusage, R-69; abgerufen = D_f · approved_f, Spec 00 § 8.3), approved_f = `financing.f_<f>_loan.approved` |
| Zint_k | Jahresbetrag der Zinsermäßigung: a_k · Σ_f w_{f,k} · L_f · pmax(i^ref_{f,k} − i_f, 0); L_f = D_f · approved_f (Ursprungsbetrag inkl. Baubegleitung), i_f = `…rate_pa`, i^ref = `funding.<f>.rent_law.reference_rate_pa` (Default `{ref: market.mortgage_rate}`) in der Periode des Fertigstellungsmonats mc_k (je Lauf); bei `interest_subsidy`: `interest_subsidy.subsidized_amount_eur · interest_subsidy.rate_reduction_pa · approved` |
| D_k, Z_k | φ_k · (G_k + TZ_k) bzw. φ_k · Zint_k mit φ_k = 1 (`full`) bzw. (K_k − IH_k)/K_k (`proportional`) |
| hv_k | Halbierung § 559f (deterministisch): `ctx$rule("mr_hp_halving")(heat_pump, jp_k, vt_k, building.construction_year, hp_exception, hp_threshold_inclusive)` mit jp_k = `energy.<hp_state>.jaz_plan` bzw. `ctx$value_base("energy.<hp_state>.jaz")` (Plan-JAZ, R-70) und vt_k = `energy.<hp_state>.flow_temperature_c`; 0, wenn das Thema `mietrecht_559f` inaktiv ist (0.9) |
| s43_k | `section43_heating` und nicht `section43_flat` |

#### 1.9.2 Verfahrenswahl (je Lauf, vektorisiert)

```text
dm_k   <- (G_k + TZ_k + Zint_k) > zero_abs                       # Drittmittel in Anspruch genommen
proc_k <- procedure, falls nicht auto
          auto: "559e", falls kind = bgb_555b_1a und fundable_in_principle und dm_k; sonst "559"
proc_k = "559e" und nicht dm_k                     -> "559"   (I: Rückfall auf § 559, Konzept 3.5)
proc_k = "559c" und c_k > P$limit_559c_per_unit    -> "559"   (W: Wertgrenze überschritten; Anteil der Läufe)
           c_k = K_k · a_k / n_units + Σ 559c-Kosten derselben Gruppe der letzten 60 Monate (je WE)
gesperrt, falls eine § 559c-Erhöhung der Gruppe (Historie oder frühere Maßnahme) weniger als P$block_559c_months
           vor me_k wirksam wurde und kind ≠ bgb_555b_6   -> Umlage 0 (W)
nicht zulässig in der Phase von me_k (mr_levy_allowed)     -> Umlage 0 (I)
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
U_g = a_k · U;   u_k = U_g / (12 · A_g)   [EUR/m²·Monat];   hs_k = 1 bei § 559e, sonst heating_part_share_k
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
  - `voluntary_cap_mode = fixed`: vcap = `voluntary_cap_per_m2` (Basisfallwert `ctx$param_base()`); ohne Wert Inf.
  - `voluntary_cap_mode = warm_rent_neutral` (R-70): vcap_g = pmax(0, `saving_eur_m2_month`) der Komponente
    `tenant_cost_component` aus `ctx$component_base()` in der **Bezugsperiode** j*: der ersten Periode mit 12 Monaten,
    die am oder nach dem frühesten Wirksamkeitsmonat me_k der Basisfallrechnung beginnt (bei Wirksamkeit am 1. Januar
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
K558_k(m) = a_k / (12 · A_g) · [ P$kuerzung_rate_grant · (G_k + TZ_k) · 1{mc_k <= m < mc_k + 12 · kuerzung_grant_years}
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
- Modernisierungsumlage nach §§ 559/559e mit Beschlussparameter `voluntary_cap_per_m2` (B3). Profil
  `wu_genossenschaft`: `rent_regime: cooperative_fee`, `modernization_levy: auto`.
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
| `relet_levy_procedures` (`mr_relet_rent`, § 556e Abs. 2) | (Regelkonstante) | §§ 559, 559c | zusätzlich § 559e (Abschnitt 9) |

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
| OVM-Modus ohne `ovm_eur_m2_month` | E (WS-B, `validation.b.ovm_missing`) |
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
| `procedure: 559c` und Kosten je WE über Grenze | W, Rückfall auf § 559 im betroffenen Lauf |
| Härte + freiwillige Obergrenze | Obergrenze zuerst (Rechtsniveau), Härte mindert die Zahlung |
| Fluktuation ohne Marktmiete | Wiedervermietung ohne Wirkung (I einmalig) |
| Mietpreisbremse nach `brake_until` | Marktmiete ohne Begrenzung |
| `vacancy_rate + rent_default_rate > 0,3` | W |
| Laufabhängige Verschiebungen | Masken je Lauf; bei unterschiedlichen me_k in Läufen entstehen verschiedene Kappungsfenster (korrekt) |

### 1.15 Testfälle `rent_path` und Mietrechtsregeln

Gemeinsame Annahmen, wenn nicht anders angegeben: `valuation_date` 2027-01-01, Jahresraster, n = 1 (deterministisch)
sowie n = 2 und n = 7 mit identischen Zeilen (Spec 00 § 2.8 Nr. 8).

| Nr. | Eingabe | Erwartung |
|---|---|---|
| RP-1 (Memo 02 § 2.2, `mietpfad_ref.py`) | A = 70 m², R₀ = 7,50, `ovm_eur_m2_month` 8,00, `rent_growth` 0,025, Maßnahme mit Fertigstellung 2027-03-01 und `ovm_uplift_eur_m2_month` 1,20, `kappung_15_area: true`, `rent_36m_ago` 7,50, `last_558_increase_date` 2026-06-01, `increase_policy: max`; Umlage aus K = 21.000 EUR (IH 0, keine Drittmittel, § 559) mit `levy_effective_date` 2027-03-01 → 2,00 EUR/m² | Monat 3: T = 9,50 > OVM 9,257 (keine Erhöhung); § 558-Erhöhungen (Monat, T): (16; 9,5079), (31; 9,8060), (46; 10,1134), (61; 10,4304), (76; 10,7574), (91; 11,0946), (106; 11,4424); Kappungsgrenze bindet nicht (Monat 16: 10,625). Zeilen: `rent` 2027 6.300,00, 2028 6.305,00, 2029 6.431,85, 2030 6.621,58; `levy_k` 2027 1.400,00, ab 2028 1.680,00 |
| RP-2 | R₀ = 6,00, OVM 8,00 konstant, `rent_36m_ago` 6,00, letzte Erhöhung 2025-01-01, `max` | k = 0,20: T = 7,20 ab Monat 1, 8,00 ab Monat 37; k = 0,15: 6,90 ab Monat 1, 7,935 ab Monat 37, 8,00 ab Monat 73 |
| RP-3 (§ 558 Abs. 5) | wie RP-2 (k = 0,20) mit R₀ = 7,00, OVM 9,00, Maßnahme fertig 2027-01-01 ohne Umlage, Zuschuss G = 10.500 EUR (a = 1) | Kürzung 0,08 · 10.500 / (12 · 70) = 1,00 EUR/m²; T = 7,40 ab Monat 1 (statt 8,40), bis Monat 24 unverändert |
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
| L-2 (S1-T5/T4a) | L-1, T vor Erhöhung 6,20 | gekappt 2,00 EUR/m² = 38.400,00 EUR/a; mit `heating_part_share` 0,256082 (300.000/1.171.500): Heizungsanteil 0,718127 → 0,50 → gesamt 2,586159 → Gesamtkappe 2,00 (38.400,00; angerechneter Heizungsanteil 0,386674); bei T = 7,20: 2,586159 EUR/m² = 49.654,24 EUR/a |
| L-3 (S3-T3, F13) | K = 153.560, G = 45.300, § 559e, A = 840 | 8.522,60 EUR/a (0,845496 EUR/m²) → Kappe 0,50: 5.040,00 → Beschluss 0,35: 3.528,00; `funds_before_flat`: 9.202,10 |
| L-4 (S3-T4, F13) | L-3 mit Wärmepumpe, `jaz_plan` 2,4, Vorlauf 70 °C, Baujahr 1985; Thema `mietrecht_559f` aktiv (freigegebener Eintrag bzw. `pending_reforms: [unreleased]`) | `halve_then_funds`: 1.996,30 EUR/a; `funds_then_halve`: 4.261,30 EUR/a (beide unter 5.040). Lesart Memo 07 (`funds_before_flat`): 2.675,80 bzw. 4.601,05. Plan-JAZ 2,5: keine Halbierung (`hp_threshold_inclusive`); Vorlauf 55 °C: Ausnahme, keine Halbierung; Thema inaktiv: 8.522,60 (wie L-3); realisierte `jaz` 2,0 im MC ändert hv nicht |
| L-5 (Memo 02 Bsp. 1) | K = 60.000, IH 30 % = 18.000, TZ = 3.000, Zint = 60.000 · (3,80 % − 3,53 %) = 162, A = 70, T = 7,50 | U = 2.958,00 EUR/a (3,521429 EUR/m²) → Kappe 3,00: 210,00 EUR/Monat = 2.520,00 EUR/a |
| L-6 (Memo 02 Bsp. 2) | K = 18.000/WE, `procedure: 559c`, keine Zuschüsse | geltendes Recht: W, Rückfall § 559 (IH 0): 1.440,00 EUR/a; `mietrecht_ii`: 1.008,00 EUR/a = 84,00 EUR/Monat |
| L-7 (Memo 02 Bsp. 3) | je WE K = 15.000, G = 4.500, § 559e, 70 m² | 825,00 EUR/a (0,982143 EUR/m²) → 35,00 EUR/Monat = 420,00 EUR/a; § 559 ohne Förderung, IH 40 %: 720,00 EUR/a → ebenfalls 35,00 EUR/Monat |
| L-8 | Vorumlagen 1,50 EUR/m² in 6 Jahren, T = 7,50, neue Umlage 2,00 | angesetzt 1,50 |
| L-9 | Heizungsvorumlage 0,30; neue Maßnahmen gleichzeitig: Heizung 0,40, Hülle 1,00 (T = 7,50) | Heizung 0,20, Hülle 1,00 |
| L-10 | gleichzeitig Heizung 0,80 und Hülle 2,80, T = 7,50, keine Vorumlagen | Heizung 0,454545, Hülle 2,545455 (Heizung 0,80 → 0,50; Summe 3,30 → 3,00, proportional) |
| L-11 (Wirksamkeit) | Erklärung 2027-10-01 / 2027-09-15 / 2027-10-01 mit `announcement_ok: false` | wirksam 2028-01-01 / 2027-12-01 / 2028-07-01 |
| RP-14 (warmmietenneutral) | TC-1 (3.11): A = 1.000 vermietet, R₀ = 6,00, eine Maßnahme (Hülle und Wärmepumpe, `bgb_555b_1`, `heating_part_share` 0,25) mit Umlage rechnerisch 1,20 EUR/m² (Heizungsanteil 0,30 < 0,50, gesamt < 2,00) wirksam 2028-01-01, `voluntary_cap_mode: warm_rent_neutral` | vcap = 1,013285 EUR/m²·Monat (Basisfall 2028); `levy_k` 2028 12.159,42; `warm_rent_change_prepost` 2028 = (12.159,42 + 4.998,00 − 17.157,42) / 12.000 = 0; im MC bei abweichenden Energiepreisen unverändert 12.159,42 |
| RP-15 (Aktivierung) | RP-5 mit `measures.<k>.active` = (1, 0) in zwei Läufen | Lauf 1 wie RP-5; Lauf 2: `levy_k` 0; `rent` 2027 119.040,00, 2028 119.040,00, 2029 120.825,60 |

### 1.16 Sonstige Erlöse

- **Stellplätze, Garagen, Werbeflächen**: Komponenten vom Typ `recurring` mit `category: operating_income` (Spec 00
  R-33, Anhang B); Wachstum über `growth`. Verwaltungskosten je Stellplatz über `unit_groups.<g>.operating`.
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
| `admin_per_unit_eur_pa` | value | EUR/(WE·a) | 367 (B `costs/bewirtschaftung_immowertv_2026`, Qualität B; G); bei `rent_regime: bound_social`: 372,46 (B `costs/bewirtschaftung_ii_bv_2026`); 0 bei `owner_occupied` (P `selbstnutzer`) | nein | W > 1.000 | Verwaltungskosten je WE (Preisstand `price_base_year`); WU überschreiben mit Ist-Kosten | 03 §8.1–8.2; Konzept 3.6 |
| `n_parking` | int ≥ 0 | Stück | 0 | nein | – | Stellplätze/Garagen der Gruppe | 02 §9.6 |
| `admin_per_parking_eur_pa` | value | EUR/(Stp.·a) | 48 (B ImmoWertV 2026); 48,58 (II. BV) | nein | – | Verwaltung je Stellplatz | 03 §8 |
| `nonrecoverable_share_of_rent` | value (share) | – | 0,01 (G; Memo 03 § 8.3, Qualität D); 0 bei `owner_occupied` | nein | W > 0,05 | nicht umlagefähige Betriebskosten in % der Sollmiete inkl. Umlagen | 03 §8.3 |
| `nonrecoverable_eur_m2_pa` | value | EUR/(m²·a) | 0 (T) | nein | W > 0 und Anteil > 0 („Doppelzählung prüfen“) | alternativ bzw. zusätzlich je m² | 02 §9.6 |
| `recoverable_opex_eur_m2_month` | value | EUR/(m²·Monat) | 1,70 (G; eigene Ableitung D: GdW 2024 kalte BK 1,90 abzüglich Grundsteuer ≈ 0,20, Memo 03 § 8.3) | nein | W > 4 | umlagefähige kalte Betriebskosten **ohne** Grundsteuer und ohne Heizung/Warmwasser; Grundlage für Leerstand (Vermieter), Selbstnutzer (voll) und Mietersicht | 03 §8.3; 02 §9.6 |
| `vacancy_opex_scope` | enum `cold`, `warm` | – | `cold` (G) | nein | – | `warm`: `recoverable_opex_eur_m2_month` enthält auch Heizkosten; dann entfallen die Vermieter-Leerstandsanteile in `energy_cost` (Doppelzählung) | 07 S1 |
| `growth` | value (Rate, Pfad) | 1/a | `{ref: market.inflation}` (G) | nein | – | Fortschreibung (VPI, wie ImmoWertV Anl. 3) | 03 §8.2 |
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
| `growth` | `value` (path) | 0 | ref |
| `base_date` | `timing` | Preisstand | Wert |
| `from`, `to` | `timing` | Token `completion`, `end_date` | `rent_start`/`rent_end` der Gruppe (bei Selbstnutzer-Neubau: Token `completion`) |
| `owner_occupied` | `logical` | `false` | Wert |
| `rent_component` | `ref` | `null` | `u_<g>_rent` (vermietete Gruppe) |
| `perspective_tax` | `enum` `deductible`, `nondeductible` | `deductible` | `nondeductible` bei `selbstnutzer` |

**Algorithmus**

```text
I   <- ctx$index_year(growth, base_date);  ov <- ctx$shift_overlap(from, shift_from, to);  D <- by_period(delta)
v   <- rent_component ? ctx$component(rent_component)$aux$vacant_share : 0          # n x (T+1)
Rr  <- rent_component ? Σ Zeilen rent + levy_* der Mietkomponente : 0            # Sollmiete
admin          = −(admin_per_unit · n_units + admin_per_parking · n_parking) · I · D · ov
nonrecoverable = −nonrecoverable_share_of_rent · Rr − nonrecoverable_eur_m2_pa · A · I · D · ov
vacancy_opex   = −recoverable_opex · 12 · A · I · D · ov · v                   (nur vermietete Gruppen)
owner_opex     = −recoverable_opex · 12 · A · I · D · ov                       (nur owner_occupied)
tenant_opex    = +recoverable_opex · 12 · A · I · D · ov                       (Merkzeile, nur vermietete Gruppen;
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

**Tests**: O-1 Verwaltung 24 WE × 367 EUR, Preisstand 2026, VPI 2,8 %/2,2 %: 9.054,62 (2027), 9.253,83 (2028),
9.457,41 (2029). O-2 `nonrecoverable_share_of_rent` 0,01 auf Soll 119.040,00: −1.190,40. O-3 Leerstand 3 %, 1,70 EUR/m²,
1.600 m², VPI 2027 2,8 %: `vacancy_opex` 2027 −1.006,62; `tenant_opex` 2027 +33.553,92 (1,70 · 12 · 1.600 · 1,028).
O-4 F10: Jahressumme 2027 auf Raster `mixed` = `annual` (Toleranz 1e-9 relativ).

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
| `growth` | value (Rate) | 1/a | `{ref: market.inflation}` (G; eigene Annahme D) | nein | – | Fortschreibung (Hebesatzentwicklung) | – |

**Typ `property_tax`** (WS-E, `R/type-flow-property-tax.R`), `grid_invariant = TRUE`. Der Expander erzeugt je Gruppe
`u_<g>_property_tax` mit dem Flächenanteil der Gruppe.

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

**Tests**: O-5 vermietet, 6.000 EUR/a, Leerstand 3 %, VPI 2027 2,8 %: `cost` 2027 −185,04; `tenant_share` +6.168,00.
O-6 Selbstnutzer 1.600 EUR/a: `cost` 2027 −1.644,80. O-7 Neubau, Grundstück 900 EUR/a bis Fertigstellung 2029-01-01
(Bauphase 2027–2028, keine Mieter): `cost` 2027 −925,20 (voll kostenwirksam).

### 2.4 Indizes und Fortschreibung

| Größe | Index | Quelle |
|---|---|---|
| Verwaltung, nicht umlagefähige Kosten, kalte BK, Grundsteuer, Grundpreise, Wartung | `{ref: market.inflation}` über `index_year` (0.7) | Memo 03 § 8.2 (ImmoWertV-Fortschreibung mit VPI) |
| Instandhaltung | Teil A (`market.maintenance_index`) | Memo 07 § 4.0 |
| Mieten | `rent_path` (eigene Monatslogik) | 1.8 |
| Energie, Netzentgelte, CO₂ | Preis- bzw. Pfadangaben je Kalenderjahr (Abschnitt 3.5) | Memo 03 § 2.4 |

Die II.-BV-Werte gelten vom 01.01.2026 bis 31.12.2028 (`valid_to` des Bibliothekseintrags; nächste Anpassung
01.01.2029, Memo 03 § 8.1). Fällt `legal_state` oder der Horizont darüber hinaus, schreibt `growth` sie fort; die
Bibliothek meldet O bei abgelaufener Gültigkeit.

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
Parameterschema, und Overlay-Ziele wie `energy.after.jaz` wirken direkt. Spec 00 § 7.10 nennt „je eine Komponente je
Träger“ (`e_<träger>_cost`); Teil B bildet sie je Zustand × Träger (`e_<zustand>_<träger>_cost`), weil sich Menge,
Einbaudatum (§ 43, § 5a) und Gültigkeitsfenster je Zustand unterscheiden (Änderungsantrag S01B-01).

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
konkretisieren den Block. Kanonische Träger-ids der Bibliothek (Teil C § 1.9.1): `gas`, `gas_mfh`, `oil`, `lpg`,
`power`, `power_mfh`, `heatpump_power`, `heatpump_power_mfh`, `district_heating`, `pellets`.

| YAML-Pfad (`energy.carriers.<c>.`) | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `class` | enum:carrier_class | – | (A) aus der kanonischen id: `gas*` → `gas`, `oil` → `oil`, `lpg` → `lpg`, `power*` → `power`, `heatpump_power*` → `power_hp`, `district_heating` → `district_heating`, `pellets` → `biomass`; sonst Pflicht | bedingt | E unbekannt | `gas`, `oil`, `lpg`, `power`, `power_hp`, `district_heating`, `biomass`, `other`; steuert § 43 GModG und § 5a CO2KostAufG (nur `gas`, `oil`, `lpg`), § 5a-Netzentgelt (nur `gas`) und den JAZ-Bezug (`power_hp`) | 02 §3.3 |
| `price_eur_kwh` | value (Pfad) | EUR/kWh | `{ref: market.energy_price.<c>}` (G) | ja | E fehlt; W Gas > 0,30 | Arbeitspreis **netto ohne Netzentgelt und ohne CO₂-Kosten** (Beschaffung, Vertrieb, Energiesteuer, Konzessionsabgabe, Marge) als Niveau je Kalenderjahr (Teil C, Kopplung K4) | Konzept 3.8 |
| `price_includes` | enum `commodity`, `all` | – | `commodity` (T) | nein | – | `all`: `price_eur_kwh` ist der **Gesamtarbeitspreis** inkl. Netzentgelt und CO₂-Kosten im ersten Rasterjahr (12-Monats-Mittel, B8); der Typ zieht Netzentgelt und CO₂-Kosten dieses Jahres ab und schreibt den Rest fort (3.6.2) | Konzept B8 |
| `price_basis` | enum `net`, `gross` | – | `net` (T) | nein | – | `gross`: alle Preis- und Gebührenangaben des Trägers enthalten USt; der Typ rechnet sie mit `vat_rate` auf netto um | – |
| `price_growth` | value (Rate, Pfad) | 1/a | 0 (T) | nein | I ≠ 0 und `price_eur_kwh` ist Prozessziel bzw. Wachstumsknoten („doppelte Fortschreibung?“) | zusätzliche Fortschreibung über `index_year` (0.7); 0, wenn `price_eur_kwh` bereits ein Pfad je Jahr ist | – |
| `price_base_date` | timing | – | Preisstand (A) | nein | – | Bezug von `price_growth`, `network_fee_growth`, `fee_growth` | – |
| `network_fee_eur_kwh` | value (Pfad) | EUR/kWh | `{ref: market.energy_network_fee.<c>}`, falls der Marktname existiert, sonst 0 (G) | nein | W Klasse `gas` ohne Netzentgelt („§ 5a-Anteil 0“) | Netzentgelt netto (Gas: je kWh H_s) | 07 §4.0 |
| `network_fee_growth` | value (Rate) | 1/a | 0 (T) | nein | I ≠ 0 und der Marktknoten hat ein eigenes Wachstum | zusätzliche Fortschreibung des Netzentgelts (der Bibliotheksknoten trägt das Wachstum 3 % bereits, Teil C § 3.6) | 07 §4.0 |
| `base_fee_eur_pa` | value | EUR/a | 0 (T; Orientierung Teil C `prices/energy_prices_2026.base_fees_eur_pa`) | nein | – | Grundpreis netto je Anschluss | 07 §4.0 |
| `fee_growth` | value (Rate) | 1/a | `{ref: market.inflation}` (G) | nein | – | Fortschreibung von Grundpreis und Wartung | – |
| `vat_rate` | share | – | 0,19 (G); 0,07 bei Klasse `biomass` (Teil C `vat_rate.pellets`, Qualität C) | nein | – | USt auf alle Bestandteile | 03 §2 |
| `emission_factor_kg_kwh` | num | kg CO₂/kWh (Abrechnungseinheit) | (R) Thema `emission_factors_co2cost`: `gas` → `natural_gas_hs` (0,1814), `oil` → `heating_oil_hi` (0,2664), `lpg` → `lpg_hi` (0,2358); sonst 0 | nein | W Klasse `gas` mit 0,200–0,205 („H_i statt H_s?“) | BEHG-/EBeV-Faktor für die **CO₂-Kosten**; biogene Anteile 0 | 03 §3.6; 02 §3.3 |
| `ghg_factor_kg_kwh` | value (Pfad) | kg CO₂-Äq./kWh (Abrechnungseinheit) | (R) Thema `emission_factors_geg` / 1000: `gas` → `natural_gas` × `conversion.gas_hs_to_hi` (0,240 × 0,903 = 0,21672), `oil` → `heating_oil` (0,310), `lpg` → `lpg` (0,270), `power`, `power_hp` → `electricity_grid` (0,560), `district_heating` → `district_heating_chp.gas_oil` (0,180), `biomass` → `wood` (0,020), sonst 0 | nein | O Eintrag abgelaufen (gültig bis 2026-12-31); I Strom konstant („abnehmender Strommix als Pfad empfohlen“) | **Treibhausgasbilanz** für die Kennzahlen `co2_emissions`, `co2_reduction`, `co2_abatement_cost` (Spec 00 § 12.3, § 12.6); keine Kostenwirkung | Konzept 1.4; 02 §3.3 |
| `co2_price_eur_t` | value (Pfad) | EUR/t (netto) | `{ref: market.co2_price}` (G) | bedingt (`emission_factor_kg_kwh` > 0) | E fehlt | CO₂-Preis je Kalenderjahr | 03 §3.4 |
| `bio_premium_eur_kwh` | value (Pfad) | EUR/kWh (netto) | `{ref: market.bio_fuel_premium}` (G) | bedingt (§ 43-Zustand) | W fehlt | Mehrkosten des biogenen Anteils gegenüber fossil | 07 §4.0 |
| `label` | chr | – | Code | nein | – | Anzeige | – |

#### 3.2.2 Zustände `energy.before`, `energy.after`, `energy.stages.<s>`

| YAML-Pfad (`energy.<zustand>.`) | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `from` | timing | – | `before`: `valuation_date` (fest); `after` und `stages`: Fertigstellung von `measure`, ohne `measure` Token `completion` | `stages`: ja, wenn `measure` fehlt | E `before.from` ≠ Stichtag; E Zustände nicht streng zeitlich geordnet | Beginn des Zustands; ein Zustand gilt bis zum Beginn des nächsten **aktiven** Zustands (3.4) | Konzept 3.8 |
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
| `installation_date` | date | – | `before`: 1. Januar von `building.heating_existing.installation_year`; sonst Fertigstellung von `measure` ohne Verschiebung, ohne `measure` `from` | bedingt (fossiler Träger in `after`/`stages`) | E fehlt bei fossilem Träger | Einbaudatum der Heizung (§ 43 GModG, § 5a CO2KostAufG, Bio-Treppe, Alterung) | Konzept 3.8 |
| `section43` | lgl | – | (A) Regel `co2_section43` (3.7.4) | nein | W abweichend von der Ableitung | neue Gas-/Öl-/Flüssiggasheizung nach § 43 GModG (Bio-Treppe, § 5a, keine 15-%-Pauschale § 559e); `false` bei Erfüllungsoption (Hybrid, Solarthermie) | 02 §3.2, §4.1 |
| `emergency_replacement` | lgl | – | `false` (T) | nein | I `true` bei Einbau nach 2027-12-31 (wirkungslos) | Einbau wegen irreparablen Ausfalls höchstens 12 Monate vor dem 01.01.2028: § 5a erst nach 12 Monaten (Teil C `s5a.transition`, Qualität C) | 02 §3.2 |
| `service_eur_pa` | value | EUR/a (netto bzw. `price_basis` des ersten Wärmeträgers) | 0 (T); geerbt | nein | – | Wartung, Schornsteinfeger (umlagefähig); Zuordnung zum Segment des größten Wärmeanteils | 07 S4 |
| `efficiency_degradation_pa` | value (Rate) | 1/a | 0 (T; Bibliothek 0,003 für Wärmepumpen, Memo 03 § 7.2); geerbt | nein | – | jährliche Verschlechterung von `efficiency` bzw. `jaz` ab `installation_date`; nicht bei gemessenem Verbrauch | 03 §7.2 |
| `extra_consumption` | map x → {`carrier` chr, `kwh_pa` value, `label` chr} | – | geerbt | nein | E Träger unbekannt | weiterer Verbrauch (Lüftung, Hilfsstrom, Haushaltsstrom des Selbstnutzers); Segment des Trägers | 07 S5 |
| `label` | chr | – | id | nein | – | Anzeige | – |

`stages`-ids sind Nutzer-ids (Spec 00 § 4.4 Nr. 2) und dürfen nicht `before` oder `after` heißen; höchstens 12 Zeichen
(Segment-ids ≤ 40 Zeichen).

#### 3.2.3 Vererbung

Fehlt in einem Zustand eines der Felder `demand_kwh`, `carrier_shares`/`heating_carrier`, `efficiency`,
`efficiency_by_carrier`, `jaz`, `jaz_plan`, `heat_pump_carrier`, `flow_temperature_c`, `installation_date`,
`section43`, `service_eur_pa`, `efficiency_degradation_pa`, `extra_consumption`, gilt der Wert des zeitlich
vorangehenden Zustands. Der Expander erzeugt dafür **Bezüge auf den Pfad des definierenden Zustands** (z. B.
`{ref: energy.before.efficiency}`), keine Kopien. `from`, `measure`, `consumption_basis`, `consumption_kwh` und
`emergency_replacement` werden nicht vererbt.

#### 3.2.4 Performance Gap `energy.performance_gap` und weitere Felder

| YAML-Pfad | Typ | Einheit | Default (Quelle) | Pflicht | Validierung | Bedeutung | Memo |
|---|---|---|---|---|---|---|---|
| `energy.performance_gap.prebound_factor` | value | – | 0,7 (G; Konzept 3.8 „Prebound-Default“, Bibliothek PERT 0,5/0,7/1,0) | nein | W gesetzt bei `before.consumption_basis = measured` („entfällt“, Teil C `prebound_with_measured`) | Verbrauch/Bedarf **vor** der Maßnahme, nur bei `before.consumption_basis = demand` (B7) | 04 §1.2; B7 |
| `energy.performance_gap.rebound_factor` | value | – | 1,0 (G; Bibliothek PERT 0,9/1,1/1,4) | nein | W < 0,8 oder > 1,6 | Verbrauch/Bedarf **nach** der Maßnahme, auf `demand_kwh` jedes Folgezustands (B7) | 04 §1.2; B7 |
| `energy.performance_gap.realisation_factor` | value | – | 1 (Spec 00) | nein | W < 0,3 oder > 1,2; I ≠ 1 zusammen mit `rebound_factor` ≠ 1 („doppelte Abschläge?“) | einfacher Realisierungsfaktor auf die rechnerische Einsparung (D8) | 04 §1.2 |
| `energy.co2_landlord_share_reduction` | value (share) | – | 0 (G) | nein | W 0 bei `building.denkmal` oder `project.municipality.milieuschutz` („§ 9 prüfen, Faktor 0,5“) | Kürzung des Vermieteranteils nach § 9 CO2KostAufG (Teil C `s9.reduction_factor` 0,5, Qualität C) | 02 §3.1 |
| `energy.co2_hardship_5d` | lgl | – | `false` (G) | nein | W `true` (Voraussetzungen nur über Sekundärquelle belegt, Teil C `s5d`) | Härtefall § 5d (Kleinvermieter): Stufenmodell statt § 5a | 02 §3.2 |
| `energy.co2_newbuild_5b` | lgl | – | `false` (G) | nein | W `false`, obwohl `project_type` ∈ {`neubau`, `erwerb_neubau`}, fossiler Träger, Bauantrag ab 2026-05-13 und Fertigstellung bis 2029-12-31 („§ 5b prüfen“) | § 5a auch für Neubauten nach § 5b (Qualität C, deshalb nur ausdrücklich) | 02 §3.2 |
| `energy.pv` | map | – | `null` | nein | – | PV-Anlage (3.9) | – |

Die 2045-Stufe der Bio-Treppe („100 % klimaneutraler Brennstoff ab 2045“, Konzept F5, A7) ist **kein Feld**, sondern
der Reformcode `stufe_2045` in `project.pending_reforms` (Spec 00 § 4.10, R-82); er aktiviert den Bibliothekseintrag
`legal/gmodg_bio_treppe_2045` (Teil C). Ein Feld `energy.climate_neutral_2045` ist ein Validierungsfehler mit Hinweis
auf den Reformcode.

#### 3.2.5 Startpreis und 12-Monats-Mittel (B8)

Default ist das **12-Monats-Mittel** statt des Spotpreises (Konzept § 3.8, B8). Die Bibliothek (Teil C,
`prices/energy_prices_2026`) liefert je Träger den Nettoarbeitspreis ohne CO₂ und ohne getrennt geführtes Netzentgelt
(`price_includes: commodity`); wer einen Gesamtpreis aus der Abrechnung eingibt, setzt `price_includes: all`. In der
Simulation läuft der Arbeitspreis per Mean-Reversion zum Normalniveau (`mr_trend`, Teil C § 2.4); CO₂-Preis und
Netzentgelt sind eigene Pfade (Kopplung K4).

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
start_j(i) = mi(from_j) + sh_j(i);  sh_j = round(measures.<measure_j>.delay_months) bzw.
             round(project.construction_delay_months) beim Token completion (Spec 00 § 3.9)
a_j(i)     = act(measure_j) (Aktivierungsfaktor 0.8); 1 ohne Maßnahme
A_j(i, m)  = a_j(i) · 1{m >= start_j(i)};  für before: A_0 = 1 für alle m >= 1
w_j(i, m)  = A_j(i, m) · Π_{l > j} (1 − A_l(i, m))
Jahresanteil je Periode:  ω_j[, t] = Σ_{m ∈ t} w_j(·, m) / 12            (n x (T+1), Spalte 1 = 0)
```

Damit gilt bei a_k = 0 der vorangehende Zustand weiter („als fehlte die Maßnahme“, Spec 00 § 4.12 Nr. 7). Bei
Neubau gibt es vor dem ersten Zustand keine Energiekosten (Bauphase). ω ersetzt das Produkt Δ_t · Überlappung; die
Jahressumme ist rasterunabhängig (F10).

### 3.5 Expander `energy` (WS-E2, `R/expand-energy.R`, order 30)

1. **Zustandsfolge.** Zustände nach `from` ordnen (`before` zuerst; Gleichstand = E). Vererbung nach 3.2.3 als Bezüge.
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
   `bctx$rule("co2_params")(bctx$legal("co2kostaufg"), bctx$legal("bio_treppe"))` für die Ableitung von `section43`;
   `bctx$legal("emission_factors_co2cost")` bzw. `bctx$legal("emission_factors_geg")` für die Default-Faktoren der
   Träger, sofern der Nutzer keinen Wert setzt (Bibliothekswerte sind keine Domänenblätter des Szenarios).

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
v    <- rp_vacancy_share(ctx, unit_groups)   (1.8.4, flächengewichtet; 0 ohne Gruppen)
f    <- owner_share + (1 − owner_share) · v · vacancy_landlord                  # Eigentümer- bzw. Vermieterlast (ohne CO2)
work = −f · W;  base_fee = −f · BF;  service = −f · SV
quantity (memo) = +Q;   emission (memo) = +Q · ghg_factor_kg_kwh / 1000          # t CO2-Äq.
```

`rp_vacancy_share(ctx, ids)` ist der interne Helfer aus `R/type-flow-rent-path.R` (WS-E): Er rechnet den
Leerstandsanteil vac_m nach 1.8.4 (struktureller Leerstand, Mieterwechsel, Entmietung während der Arbeiten,
Lease-up, jeweils mit Verschiebung und Aktivierungsfaktor) aus Domänenpfaden und mittelt ihn flächengewichtet je
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
`co2_emissions` (Spec 00 § 12.3); die CO₂-**Kosten** folgen dagegen nur dem BEHG-Faktor in `co2_cost`.

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
| `co2_section43(carrier_class, installation_date, existing_building, PC)` | `params` (lgl) | 2026-07-29 | `TRUE`, wenn `carrier_class` ∈ `bio_heating_classes`, `installation_date >= bio_installed_after` und Bestandsgebäude (`bio_building = existing`) |
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
| `specific_yield_kwh_kwp` | value | kWh/(kWp·a) | 950 (B, Memo 03 § 6.3, Qualität D) | nein | W < 700 oder > 1.200 | spezifischer Ertrag | 03 |
| `degradation_pa` | value (Rate) | 1/a | 0 (T) | nein | – | Ertragsminderung je Jahr | – |
| `self_consumption_share` | value (share) | – | – | ja | E > 1 | Eigenverbrauchsanteil am Ertrag | 07 S3, S5 |
| `self_consumption_carrier` | chr | – | (A) `heat_pump_carrier` des jeweils gültigen Zustands, sonst erster Träger der Klasse `power` | nein | E unbekannt | Träger, dessen Bezug der Eigenverbrauch ersetzt | 07 S3 |
| `feed_in_mode` | enum `partial`, `full` | – | `partial` (T) | nein | E `full` mit `self_consumption_share` > 0 | Teil- bzw. Volleinspeisung | 07 §4.0 |
| `feed_in_tariff_eur_kwh` | value | EUR/kWh | (A) `partial`: `{expr: "(pmin(energy.pv.kwp, 10) * market.feed_in_tariff.partial_le10kwp + pmin(pmax(energy.pv.kwp - 10, 0), 30) * market.feed_in_tariff.partial_10_40kwp) / energy.pv.kwp"}`; `full` (≤ 10 kWp): `{ref: market.feed_in_tariff.full_le10kwp}` | bedingt (> 40 kWp bzw. `full` > 10 kWp: Pflicht) | E fehlt; O Bibliothek `prices/eeg_feed_in_*` außerhalb der Gültigkeit | anzulegender Wert der Einspeisevergütung (Mischsatz nach Leistungsstufen, Teil C § 3.6) | 07 §4.0; 03 §12 |
| `tariff_years` | int | a | 20 (G; Teil C `fixed_years`) | nein | – | Vergütungsdauer ab Inbetriebnahme | 07 S3 |
| `post_tariff_price_eur_kwh` | value | EUR/kWh | 0 (G) | nein | I | Erlös nach Vergütungsende | – |
| `internal_price_eur_kwh` | value | EUR/kWh (brutto) | 0 (G; B3) | nein | W > 0 bei `wu_genossenschaft` („Verrechnung rechtlich prüfen“) | Verrechnungspreis des an Mieter/Mitglieder gelieferten PV-Stroms | 07 S3; Konzept B3 |
| `opex_share_of_cost` | value (share) | 1/a | 0,012 (B, Memo 03 § 9, Qualität D) | nein | – | Betrieb (Wartung, Versicherung, Zähler) in % der Investition | 03 §9 |
| `opex_eur_pa` | value | EUR/a | (A) `{expr: "energy.pv.opex_share_of_cost * measures.<measure>.cost_eur"}`; ohne `measure` Pflicht | nein | – | Betriebskosten (Preisstand der Maßnahme) | 07 S3 |
| `tax_exempt` | enum `auto`, `yes`, `no` | – | `auto` | nein | I `auto` ergibt `no` | Steuerbefreiung § 3 Nr. 72 EStG: `auto` = `kwp` ≤ 30 · max(1, `building.n_units`) und ≤ 100 (Stand JStG 2024; Abschnitt 9) | Konzept 3.12 |
| `vat_zero_rate_attested` | lgl | – | `false` (T) | nein | I `true` („Nachweis der Begünstigung nach § 12 Abs. 3 Nr. 1 UStG erforderlich“); W `kwp` > 30 und `false` („19 % USt auf Lieferung und Installation angesetzt“) | **Begünstigungsattribut** der Anlage (Spec 00 § 7.10, R-84): Nullsteuersatz für Lieferung und Installation auch über 30 kWp | Konzept 3.2, P18 |

**Umsatzsteuer der Investition (Abstimmung Teil A).** Für die Maßnahme `energy.pv.measure` setzt der
Maßnahmen-Expander (Teil A) den Default von `measures.<k>.vat_rate` auf 0, wenn `energy.pv.kwp` ≤
`umsatzsteuer.pv_zero_rate.max_kwp_without_proof` (30) oder `vat_zero_rate_attested = true`, sonst 0,19. Ein
ausdrücklich gesetzter `vat_rate` der Maßnahme gewinnt (W bei Widerspruch). Die Betriebskosten (`opex`) tragen 19 %.

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
| `income_growth` | value (Rate) | 1/a | `{ref: market.inflation}` (Spec 00) | nein | – | Fortschreibung des Einkommens | – |
| `taxable_income_avg_eur` | num | EUR/a | `null` | bedingt (einkommensabhängige Förderung) | E fehlt, wenn eine Förderbedingung es verwendet (4.3) | Ø zu versteuerndes Einkommen des 2. und 3. Kalenderjahres vor Antrag | 02 §5.2, §5.6 |
| `n_children_u18` | int ≥ 0 | – | 0 | nein | – | kindergeldberechtigte Kinder < 18 (Einkommensgrenzen, KfW 300/308) | 02 §5.2 |
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
  `from`/`to` = `contribution_from`/`contribution_to`; nur wenn gesetzt.
- Belastungs-Hilfszeilen entstehen **nicht**: Die Haushaltskennzahlen wählen Zeilen über das Kategoriemerkmal
  `burden` (Spec 00 § 7.6, § 12.3); `current_rent_month_eur` geht nur in `monthly_burden_construction` ein.

#### 3.10.3 Typ `imputed_rent` (WS-E, `R/type-flow-imputed-rent.R`)

Parameter: `area_m2` (number, `{ref: unit_groups.<g>.living_area_m2}`), `rent_eur_m2_month` (value, ref auf
`imputed_rent_eur_m2_month`), `growth` (value, `{ref: unit_groups.<g>.imputed_rent_growth}`), `base_date` (timing,
`valuation_date` + 12 Monate), `from` (timing, Bestand `valuation_date`, Neubau Token `completion`), `to`.
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

Gemeinsame Annahmen wie 1.15. Rechtsstand 2026-10-25 mit den Bibliothekseinträgen aus Teil C § 3.5.

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
| TC-1 (Mieter vorher/nachher) | 1.000 m² vermietet, kein Leerstand; `before` Gas 150.000 kWh_Hs, Arbeitspreis netto 0,0634, Netzentgelt 0,0257, EF 0,18, CO₂ 65 €/t (konstant); `after` ab 2028-01-01: Wärmepumpe 20.000 kWh, 0,21 €/kWh netto | Stufe 27,0 kg/m²·a → 40 %. 2027: `energy` = `energy_pre` = 17.157,42 (15.904,35 + 0,6 · 2.088,45); 2028: `energy` 4.998,00, `energy_pre` 17.157,42; `saving_eur_m2_month` 2028 1,013285 |
| TC-2 (ohne Vorzustand) | Neubau, nur `after` | Zeile `energy_pre` fehlt; `warm_rent_change_prepost` = NA (`no_tenant_data`) |
| PV-1 (S3-T6) | 30 kWp, 900 kWh/kWp, Eigenverbrauch 0,30, `market.feed_in_tariff.partial_le10kwp` 0,0770, `partial_10_40kwp` 0,0666 | Satz 0,0700667; Einspeisung 18.900 kWh → `feed_in` 1.324,26 EUR/a; mit `degradation_pa` 0,003 im 2. Jahr: 1.320,29 |
| PV-2 (S5) | Selbstnutzer, 8 kWp · 950, Eigenverbrauch 0,35, Haushaltsstrom brutto 0,37 €/kWh | `self_consumption` +984,20 EUR/a (2.660 kWh) |
| PV-3 | Eigenverbrauch > Bedarf (Bedarf 1.000 kWh, E · Anteil = 2.660) | S = 1.000, F = E − 1.000 |
| PV-4 (USt-Attribut) | 45 kWp mit `measure`, ohne bzw. mit `vat_zero_rate_attested` | Maßnahme `vat_rate` 0,19 mit W bzw. 0 mit I (Teil A); 25 kWp: 0 ohne Meldung |
| H-1 | `household.savings_eur` 60.000, kein `equity` in `financing` | `h_equity__in` +60.000 in t = 0 |
| H-2 (`imputed_rent`) | 140 m², 9,00 EUR/m², Wachstum 1,5 % | 2027: 15.120,00; 2028: 15.346,80 |
