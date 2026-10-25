# Recherche-Memo 02: Domänenmodell Zahlungsströme Wohnungswirtschaft, Rechtsrahmen und Förderung (Stand 25.10.2026)

**Projekt:** VoFi-Tool in R (Vollständiger Finanzplan nach Grob, inkl. Monte-Carlo-Simulation)
**Gegenstand:** Neubau und energetische Sanierung von Wohngebäuden in Deutschland aus Sicht von Wohnungsunternehmen, Kleinvermietern und Selbstnutzern
**Rechtsstand / Datenstand:** 25.10.2026 (alle Webquellen am 25.10.2026 abgerufen, sofern nicht anders angegeben)
**Status:** Recherche- und Entscheidungsgrundlage für Konzeptphase. Keine Rechtsberatung. Alle volatilen Werte gehören in YAML-Parameterbibliotheken (siehe Abschnitt 9 und 10).

---

## 0. Zusammenfassung (Management Summary)

1. **Rechtslage hat sich 2026 stark bewegt.** Drei Entwicklungen sind für das Tool zentral:
   - **Gebäudemodernisierungsgesetz (GModG)**: verkündet 28.07.2026 (BGBl. 2026 I Nr. 226), erste Stufe in Kraft seit **29.07.2026**. Die **65-%-EE-Regel für neue Heizungen ist entfallen**; an ihre Stelle tritt für neue Gas-/Öl-/Flüssiggasheizungen im Bestand eine **"Bio-Treppe"** (Mindestanteil biogener Brennstoffe/Wasserstoff: 10 % ab 2029, 15 % ab 2030, 30 % ab 2035, 60 % ab 2040). Neubauten müssen ab **01.01.2030 Nullemissionsgebäude** sein. Das neue Referenzgebäude (Wegfall des Faktors 0,55, ungefähr GEG-55-Niveau) gilt voraussichtlich ab dem 1. Tag des 6. Folgemonats nach Verkündung, also **ab 01.01.2027** (eigene Ableitung, siehe 4.1).
   - **CO2KostAufG** wurde durch das GModG um **§§ 5a–5d** ergänzt: Bei **neu eingebauten Gas-/Öl-/Flüssiggasheizungen** (Heizung nach § 43) gilt ab 01.01.2028 eine **pauschale 50/50-Teilung der CO2-Kosten und der Gasnetzentgelte**, ab 01.01.2029 zusätzlich hälftige Teilung der Mehrkosten des Bio-Anteils (bis 30 % Brennstoffanteil). Das 10-Stufen-Modell bleibt für alle übrigen Fälle bestehen.
   - **BEG-Reform zum 21.07.2026**: Tilgungszuschüsse in KfW 261 deutlich gesenkt (EH 85/70 EE: 0 %, EH 55 EE: 5 %, EH 40 EE: 10 %), EE-Klasse ist jetzt Pflicht, Kredithöchstbetrag einheitlich 150.000 EUR/WE. Heizungsförderung (KfW 458/459): Grundförderung 30 %, Klimageschwindigkeitsbonus 16 % mit **halbjährlicher Degression um 4 Pp ab 01.02.2027 (entfällt ab 01.08.2028)**, Einkommensbonus neu gestaffelt (40/30/10 %), Effizienzbonus entfallen, förderfähige Kosten 1. WE 28.000 EUR mit **Degression um 750 EUR je Halbjahr ab 01.02.2027**.
2. **CO2-Preis:** BEHG-Korridor 2026 **55–65 EUR/t**; die Verlängerung des Korridors **55–65 EUR/t für 2027** hat der Bundestag am **15.10.2026** beschlossen (Bundesrat stand zum Abrufzeitpunkt aus). **ETS2-Vollstart (Preis im Endkundenpreis) 01.01.2028**, Preisstabilitätsmechanismus mit Auslöseschwelle 45 EUR/t (Preise 2020). Ab 2028 ist der CO2-Preis ein zentraler stochastischer Treiber der Monte-Carlo-Simulation.
3. **Mietrecht:** Mietpreisbremse bis **31.12.2029** verlängert (Länderverordnungen nötig). Die Reform **"Mietrecht II"** (BT-Drs. 21/6807) ist **noch nicht beschlossen** (Anhörung 14.10.2026). Relevant für das Tool: Indexmieten-Dämpfung in angespannten Gebieten (Indexanstieg über 3 %/Jahr zählt nur zur Hälfte), Anhebung der Wertgrenze des vereinfachten Verfahrens § 559c von 10.000 auf **20.000 EUR**, Minderungsausschluss 3 Monate auch für Heizungsmaßnahmen (§ 555b Nr. 1a), Ausschluss von § 559e bei Staffelmiete. Das Tool braucht deshalb **versionierte Rechtsstände** ("legal_state") mit Schalter für anhängige Reformen.
4. **Modellierungsempfehlung:** Mietrecht und Bauphase in einer **Monats-Engine** abbilden (15-Monats-Wartefrist, Wirksamkeitsfristen, Kappung in 3-Jahres-Fenstern, Bereitstellungszinsen), dann **jährlich in den VoFi aggregieren**. Förderprogramme **nicht hart codieren**, sondern über ein **generisches Förderinstrument-Schema** (Zuschuss, Förderkredit, Tilgungszuschuss, Zinsverbilligung, Steuerermäßigung, Miet-/Belegungsbindung) mit Gültigkeitszeitraum, Degression, Kostendeckeln je WE-Staffel, Kumulierungsregeln und mietrechtlicher Wirkung (§ 559a/§ 558 Abs. 5).
5. **Ertragsteuern:** Empfehlung, in v1 auszuklammern (Vorsteuer-VoFi), aber eine **Steuerzeile/Steuer-Slot** im Datenmodell vorzusehen. Für Kleinvermieter ist ein einfaches Grenzsteuersatz-Modul (v1.1) mit geringem Aufwand machbar und entscheidungsrelevant; für Wohnungsunternehmen (KSt/GewSt, erweiterte Kürzung, Vermietungsgenossenschaften) ist die Komplexität hoch.

---

## 1. Zahlungsstrom-Komponenten (Domänenmodell)

### 1.1 Grundstruktur des Domänenmodells

Vorgeschlagene Entitäten (Namen in R/YAML englisch, Beschreibung deutsch):

| Entität | Bedeutung | Wesentliche Attribute |
|---|---|---|
| `project` | Vorhaben (Neubau, Sanierung, Heizungstausch, Erwerb + Sanierung) | Typ, Bewertungsstichtag, Horizont, Perspektive, Bundesland, Gemeindestatus (Mietpreisbremse, Kappung 15 %, Milieuschutz) |
| `building` | Gebäude | Typ, Baujahr, Wohnfläche, Nutzfläche (NRF nach DIN 277 für GModG), Energieklasse vorher/nachher, Effizienzhausstufe, WPB-Status, Denkmal |
| `unit_group` | Gruppe gleichartiger Wohneinheiten | Anzahl, Fläche je WE, Mietregime, Ausgangsmiete, Selbstnutzung ja/nein, Bindung |
| `measure` | Einzelmaßnahme / Bauteil | DIN-276-KG, Kosten, Nutzungsdauer, Sowieso-Kosten und Fälligkeit, mietrechtlicher Instandhaltungsanteil, Modernisierungsart (§ 555b Nr. 1/1a/3/4/5/6), Fördereignung |
| `energy_system` | Wärme-/Stromversorgung vorher/nachher | Energieträger-Mix, Endenergie, Bio-Anteil-Pfad, Emissionsfaktoren, PV |
| `funding_instrument` | Förderinstrument aus Bibliothek | siehe Abschnitt 5.8 |
| `financing` | Finanzierungsbausteine | EK, Darlehen, Förderkredite, Genossenschaftsanteile |
| `scenario` | Variante (Mit/Ohne, Varianten A/B/C) | Parameter-Overrides, Zufallsverteilungen |
| `legal_state` | Versionierter Rechtsstand | Stichtag, Schalter für anhängige Reformen |

**Betrachtungsmodus** (wichtig für Sanierung):
- `absolute`: alle Zahlungen des Objekts mit Maßnahme (Investorensicht, z. B. Neubau, Erwerb).
- `differential`: Zahlungen **Mit-Maßnahme minus Ohne-Maßnahme** (Referenzszenario "Unterlassungsalternative" mit Sowieso-Instandhaltung). Standard für energetische Sanierung, weil nur so energiebedingte Mehrkosten und Mehrerlöse sauber getrennt werden.

### 1.2 Investitionsauszahlungen nach DIN 276 (Fassung 2018-12)

DIN 276:2018-12 gliedert die Kosten im Bauwesen in 8 Kostengruppen (KG). Eine neuere Fassung ist mir zum Stichtag nicht bekannt (unsicher; vor Implementierung prüfen).

| KG | Bezeichnung | Inhalt (Auswahl) | Modellhinweis |
|---|---|---|---|
| 100 | Grundstück | Kaufpreis, Grundstücksnebenkosten (Grunderwerbsteuer, Notar, Grundbuch, Makler, Vermessung), Freimachen | GrESt 3,5–6,5 % je Bundesland; Notar/Grundbuch ca. 1,5–2,0 %; Makler 0–3,57 %. Alternative: Erbbaurecht (laufender Erbbauzins statt Kaufpreis) |
| 200 | Vorbereitende Maßnahmen | Herrichten (Abbruch, Altlasten), öffentliche/nicht öffentliche Erschließung, Hausanschlüsse, Ausgleichsabgaben | Neubau relevant; bei Sanierung ggf. Rückbau |
| 300 | Bauwerk – Baukonstruktionen | Gründung, Wände, Decken, Dach, Fenster, Dämmung | Kernposten; bei Sanierung je Bauteil als `measure` |
| 400 | Bauwerk – Technische Anlagen | Heizung, Lüftung, Sanitär, Elektro, PV, Aufzüge | Heizung separat wegen § 559e/§ 43 GModG/BEG EM |
| 500 | Außenanlagen und Freiflächen | Wege, Stellplätze, Grün | Stellplätze ggf. eigener Erlösstrom |
| 600 | Ausstattung und Kunstwerke | Küchen, Möblierung | Möblierung beeinflusst Mietpreisbremse (Mietrecht II: Möblierungszuschlag) |
| 700 | Baunebenkosten | Bauherrenaufgaben, Planung (HOAI), Gutachten, Energieberatung/Baubegleitung, Genehmigungen, Versicherungen | Typisch 15–25 % von KG 300+400 (Erfahrungswert, unsicher); Energieeffizienz-Experte ist förderfähig |
| 800 | Finanzierung | Bauzeitzinsen, Bereitstellungszinsen, Bearbeitungsgebühren, Bürgschaften | **Nicht als Input eingeben**, sondern aus dem Finanzierungsmodul berechnen (Doppelzählung vermeiden) |

**Umsatzsteuer:** Wohnraumvermietung ist nach § 4 Nr. 12 UStG steuerfrei; ein Vorsteuerabzug ist ausgeschlossen. Alle Investitions- und Bewirtschaftungskosten sind daher **brutto (inkl. 19 % USt)** anzusetzen. Ausnahme: PV-Anlagen bis 30 kWp unterliegen dem Nullsteuersatz (§ 12 Abs. 3 UStG). Parameter `vat_rate_costs`.

**Kostenansätze:** Neubaukosten (z. B. BKI-Baukosten, ARGE Kiel) und Sanierungskosten je Bauteil sind sehr regional und zeitabhängig. Sie gehören als **€/m²-Kennwerte mit Unsicherheitsband** in eine Kostenbibliothek (nicht Teil dieses Memos). Für die MC-Simulation: Baukostenrisiko als multiplikativer Faktor (z. B. Dreiecksverteilung 0,95 / 1,05 / 1,25) plus Baupreisindex-Fortschreibung bis Vergabe.

### 1.3 Planungs- und Bauzeit, Bauzeit- und Bereitstellungszinsen

**Zeitparameter (Richtwerte, Erfahrungswerte, unsicher):**

| Vorhaben | Planung + Genehmigung | Bauzeit |
|---|---|---|
| Neubau MFH | 12–24 Monate (Bau-Turbo § 246e BauGB kann verkürzen) | 15–24 Monate |
| Neubau EFH | 6–12 Monate | 6–12 Monate |
| Komplettsanierung MFH bewohnt | 6–12 Monate | 3–9 Monate je Bauabschnitt |
| Serielle Sanierung | 6–12 Monate (Vorfertigung) | wenige Wochen vor Ort |
| Heizungstausch | 1–6 Monate | 1–4 Wochen |

**Mittelabflussprofil:** linear, S-Kurve (z. B. Beta-Verteilung) oder Ratenplan (bei Bauträgerkauf MaBV § 3 Abs. 2). Parameter `draw_schedule`.

**Formeln (Monatsraster, m = Monat der Bauphase):**
- Ausgezahlter Darlehensbestand `D_m`, nicht abgerufener Zusagebetrag `U_m`.
- Bauzeitzinsen: `BZ = Σ_m D_m · i_soll / 12`
- Bereitstellungszinsen: `BP = Σ_{m > m_frei} U_m · b_monat`
  - KfW: 0,15 % pro Monat ab dem 13. Monat nach Zusage (KfW 261, 297/298) [Q15, Q18].
  - Geschäftsbanken: typischerweise 0,25 % pro Monat nach 3–12 bereitstellungszinsfreien Monaten (Marktüblich, unsicher).
- Finanzierungsreihenfolge (Parameter): EK zuerst, dann Förderkredit, dann Bankdarlehen, oder pro rata.

Die Bauphase wird im VoFi entweder als Periode(n) vor t=0 (Investitionszeitpunkt) aufgezinst oder als eigene Jahre mit negativen Salden abgebildet. Empfehlung: Bauphase als **eigene Perioden** im Zeitraster, damit Bauzeitzinsen, Bereitstellungszinsen und Mietausfall während der Sanierung explizit sichtbar werden.

### 1.4 Ohnehin-/Sowieso-Kosten vs. energiebedingte Mehrkosten

Zwei unterschiedliche Begriffe müssen getrennt werden:

1. **Wirtschaftliche Sowieso-Kosten** (Investorensicht, Differenzbetrachtung): Kosten, die im Ohne-Szenario ohnehin anfallen würden (z. B. Putzerneuerung, Fenstertausch am Ende der Nutzungsdauer, Kesseltausch). Sie fallen im Ohne-Szenario **zum Fälligkeitszeitpunkt** `t_due` an, nicht zwingend heute (Vorzieheffekt).
   - Energiebedingte Mehrkosten: `K_mehr = K_mit − K_sowieso` (bei gleichem Zeitpunkt).
   - Bei vorgezogener Maßnahme: Barwertvergleich `K_mit(t0)` vs. `K_sowieso(t_due) · (1+g_bau)^(t_due−t0) / (1+i)^(t_due−t0)` – ergibt sich im VoFi automatisch, wenn beide Szenarien gerechnet werden.
2. **Mietrechtlicher Instandhaltungsanteil** (§ 559 Abs. 2 BGB): Kosten, die für Erhaltungsmaßnahmen erforderlich gewesen wären, gehören nicht zu den umlagefähigen Kosten; sie sind ggf. zu schätzen, der **Abnutzungsgrad** der erneuerten Teile ist zu berücksichtigen [Q13]. Nach BGH (Urteil vom 17.06.2020 – VIII ZR 81/19, nach meinem Kenntnisstand; zu verifizieren) ist ein Abzug auch dann vorzunehmen, wenn das Bauteil noch nicht mangelhaft ist, aber einen nicht unerheblichen Teil seiner Nutzungsdauer bereits erreicht hat.
   - Modellformel: `IH_anteil = K_erhaltung_fiktiv · min(1, Alter_Bauteil / ND_Bauteil)` (lineare Abnutzung; Parameter `maintenance_share_method = "linear_wear" | "fixed_share" | "flat_559c" | "flat_559e"`).
   - Pauschalen: § 559c: 30 % (vereinfachtes Verfahren), § 559e: 15 % (Heizungsanlage, nicht bei Heizung nach § 43 GModG, d. h. neuer fossiler Heizung mit Bio-Treppe).
   - Erfahrungswerte für umfassende energetische Modernisierungen: 20–50 % Instandhaltungsanteil (stark bauteil- und zustandsabhängig; unsicher, als Verteilung modellieren).

### 1.5 Ersatz- und Reinvestitionen (Bauteil-Nutzungsdauern)

Für den Betrachtungszeitraum (typisch 20–40 Jahre) sind Ersatzinvestitionen für kurzlebige Komponenten zwingend. Richtwerte (Quelle: BNB-Tabelle "Nutzungsdauern von Bauteilen" des BBSR, letzter Stand 2017, wird laut Lobbyregister-Eintrag 2025 überarbeitet [Q33]; VDI 2067 Blatt 1:2012). **Die folgenden Werte sind Richtwerte aus meinem Fachwissen und vor Übernahme in die Bibliothek gegen die Originaltabellen zu prüfen.**

| Komponente | Nutzungsdauer (Jahre), Richtwert | Bandbreite |
|---|---|---|
| Gas-Brennwertkessel | 20 | 15–25 |
| Wärmepumpe Luft/Wasser | 18 | 15–25 |
| Wärmepumpe Sole/Wasser (Gerät) / Erdsonde | 20 / 50 | – |
| Pelletkessel | 20 | 15–20 |
| Fernwärme-Übergabestation | 25 | 20–30 |
| Solarthermie | 20 | 20–25 |
| PV-Module / Wechselrichter | 25 / 13 | 20–30 / 10–15 |
| Lüftungsanlage mit WRG (zentral) | 20 | 15–25 |
| Warmwasserspeicher | 20 | 15–20 |
| Heizkörper / Flächenheizung | 30 / 50 | – |
| Rohrleitungen (Heizung, Trinkwasser) | 40 | 30–50 |
| Fenster Kunststoff/Holz / Holz-Alu | 35 / 45 | 30–50 |
| WDVS (System) / Putz-Anstrich | 40 / 15 | 30–50 / 10–20 |
| Steildacheindeckung / Flachdachabdichtung | 50 / 25 | 40–60 / 20–30 |
| Dämmung oberste Geschossdecke, Kellerdecke | 50 | 40–60 |
| Aufzug | 25 | 20–30 |
| Sanitärobjekte, Bäder | 25 | 20–30 |
| Elektroinstallation | 40 | 30–50 |

Modell: `replacement_cost_t = K_0 · f_ersatz · (1 + g_baupreis)^t` zu `t = t_0 + k·ND`; Restwert am Horizont linear `K · (1 − Restlaufzeitanteil)` (siehe 7.4), damit kurze Horizonte nicht benachteiligen.

### 1.6 Erlöse

| Erlösart | Formel / Logik | Rechtsrahmen |
|---|---|---|
| Nettokaltmiete (Soll) | `NKM_t = Σ_WE Fläche · Miete_€/m²·Monat · 12` | §§ 556d–561 BGB, siehe Abschnitt 2 |
| Modernisierungsumlage | Zuschlag nach § 559/559c/559e, bleibt dauerhaft Teil der Miete | Abschnitt 2.3 |
| Stellplätze / Garagen | `n · Miete_€/Monat · 12` (nicht Wohnraummietrecht, wenn separat vermietet) | frei vereinbar |
| PV: Einspeisung | `E_PV · Anteil_Einspeisung · Vergütung` | EEG, Werte BNetzA (halbjährliche Degression; aktuelle Sätze aus Energie-Memo) |
| PV: Mieterstrom | `E_PV · Anteil_Mieterverbrauch · Preis_Mieterstrom` + Mieterstromzuschlag | § 42a EnWG: Preis ≤ 90 % des Grundversorgungstarifs; Zuschlag § 21 Abs. 3 EEG |
| PV: Gemeinschaftliche Gebäudeversorgung | wie Mieterstrom, ohne Vollversorgungspflicht | § 42b EnWG (seit 2024) |
| Sonstige (Werbeflächen, Mobilfunk) | Pauschal | – |
| Selbstnutzer: ersparte Miete (optional, kalkulatorisch) | `Fläche · Vergleichsmiete · 12` | nur für Vergleich Kauf vs. Miete |
| Selbstnutzer: Energiekostenersparnis | `Σ_Träger (E_ohne − E_mit) · Preis_t` + Grundpreisdifferenzen | Abschnitt 1.8 |

### 1.7 Bewirtschaftungskosten (Vermieterperspektive, nicht umlagefähig)

Umlagefähige Betriebskosten (BetrKV) sind für den Vermieter grundsätzlich **durchlaufend** und werden im VoFi nicht gerechnet, **außer**:
- Betriebskosten auf **leerstehende** Einheiten (Leerstands-Betriebskosten),
- **CO2-Kosten-Vermieteranteil** nach CO2KostAufG (Abschnitt 3),
- ab 2028 **50 % der Gasnetzentgelte** und ab 2029 50 % der Bio-Mehrkosten bei neuen fossilen Heizungen (§ 5a CO2KostAufG),
- nicht umlagefähige Positionen (z. B. Bankgebühren, Teile der Hauswartkosten, Reparaturanteile).

**Modellansätze (Referenzwerte 2026):**

| Position | ImmoWertV Anlage 3, fortgeschrieben ab 01.01.2026 [Q26] | II. BV (§§ 26, 28) ab 01.01.2026 [Q27] | Hinweis |
|---|---|---|---|
| Verwaltungskosten je WE (MFH) bzw. je Gebäude (EFH/ZFH) | 367 EUR/a | 372,46 EUR/a | WU real oft höher (Vollkosten) |
| Verwaltung je Eigentumswohnung | 439 EUR/a | 445,32 EUR/a | – |
| Verwaltung je Garage/Stellplatz | 48 EUR/a | 48,58 EUR/a | – |
| Instandhaltung Wohnen | 14,40 EUR/m²·a | 11,50 (< 22 J.) / 14,58 (≥ 22 J.) / 18,62 (≥ 32 J.) EUR/m²·a | II. BV nach Bezugsfertigkeit gestaffelt; nächste Anpassung II. BV 01.01.2029 |
| Instandhaltung Garagenstellplatz | 108 EUR/a | – | – |
| Mietausfallwagnis | 2 % des Rohertrags (Wohnen) | 2 % (§ 29 II. BV) | zusätzlich strukturellen Leerstand separat modellieren |

Empfehlung: Default nach ImmoWertV-Modellansatz (bundeseinheitlich, jährlich indexiert über VPI), für WU überschreibbar mit eigenen Ist-Kosten. Fortschreibung mit Index (`cost_index_growth`, MC-Parameter).

**Leerstand und Mietausfall** getrennt modellieren:
- `structural_vacancy_rate` (struktureller Leerstand, regional; Neubau in Wachstumsregionen ≈ 0–1 %, schrumpfende Regionen > 5 %),
- `rent_loss_risk_rate` (Mietausfallwagnis, Forderungsausfall, 2 %),
- `turnover_rate` (Fluktuation, typ. 6–10 %/a in WU-Beständen, unsicher) mit `relet_vacancy_months` (Leerstand je Mieterwechsel),
- Erstvermietungsphase Neubau (`lease_up_months`).

### 1.8 Sanierungsspezifische Zahlungen

| Position | Logik | Parameter |
|---|---|---|
| Mietminderung während Bauarbeiten | Minderung `α` der Miete für Bauzeit; bei energetischer Modernisierung (§ 555b Nr. 1) **3 Monate Minderungsausschluss** (§ 536 Abs. 1a BGB); Mietrecht II würde dies auf Heizungsmaßnahmen (§ 555b Nr. 1a) erweitern [Q9] | `rent_reduction_rate_works` (typ. 10–30 % bewohnt, 100 % unbewohnbar), `minderung_exclusion_months` = 3 |
| Leerstand / Entmietung | Volle Mietausfälle + Leerstands-BK; bei umfassender Modernisierung Erstvermietung **ohne Mietpreisbremse** (§ 556f S. 2 BGB) | `vacancy_during_works_months`, `decant_share` |
| Umzugs-/Hotel-/Umsetzwohnungskosten | Aufwendungsersatz an Mieter (§ 555a Abs. 3, § 555d Abs. 6 BGB) | `relocation_cost_per_unit` |
| Entmietungsprämien/Abfindungen | freiwillig, marktüblich sehr variabel | `tenant_compensation_per_unit` |
| Sonderkündigungsrecht Mieter | § 555e (nach Ankündigung), § 561 (nach Erhöhung) → Fluktuationsspitze | `turnover_spike_after_works` |
| Härteeinwand | § 559 Abs. 4/5: Umlage ganz/teilweise ausgeschlossen, wenn sie für den Mieter eine nicht zu rechtfertigende Härte bedeutet; die Ausschlussgründe für den Härteeinwand (allgemein üblicher Zustand, vom Vermieter nicht zu vertretende Umstände) gelten nicht für Heizungsmaßnahmen nach § 555b Nr. 1/1a | `umlage_realization_rate` (MC) |

### 1.9 Energiekosten (Selbstnutzer) und Energie-Bilanz (alle Perspektiven)

`Energiekosten_t = Σ_Träger [E_Träger,t · p_Träger,t + Grundpreis_Träger,t]`, wobei
- `E` = Endenergie (Verbrauch). Bei Bedarfsausweisdaten: **Prebound-Faktor** `φ` (unsanierte Gebäude verbrauchen oft deutlich weniger als der Bedarf; Größenordnung 0,6–0,9, unsicher) und **Rebound-Faktor** nach Sanierung: `E_verbrauch = E_bedarf · φ`.
- `p_t = p_0 · Π(1+g_s)` plus **explizite CO2-Komponente**: `p_t = p_ohneCO2,t + EF · CO2-Preis_t · (1+USt)`; so wird der ETS2-Effekt transparent (z. B. Erdgas: 65 EUR/t ≈ 1,18 ct/kWh(Hs) netto ≈ 1,41 ct/kWh brutto; eigene Berechnung).
- Ab 2029 für neue fossile Heizungen: `p_mix = (1−β_t) · p_fossil + β_t · p_bio` mit Bio-Treppe `β_t` ∈ {0,10; 0,15; 0,30; 0,60}.

Referenz-Energiepreise 2026 (Startwerte, Haushalte, brutto):

| Träger | Wert | Quelle |
|---|---|---|
| Erdgas EFH (20.000 kWh/a) | 11,93 ct/kWh (Neukundentarife, inkl. anteiligem Grundpreis), 2026 bisher | BDEW Gaspreisanalyse 08/2026 [Q29] |
| Erdgas MFH | 11,17 ct/kWh | BDEW Gaspreisanalyse 08/2026 [Q29] |
| Haushaltsstrom (3.500 kWh/a) | 37,0 ct/kWh | BDEW Strompreisanalyse 2026 [Q29] |
| Wärmepumpentarif | ca. 21–28 ct/kWh (Spanne Neukunden/Bestand; Sekundärquellen) | unsicher |
| Heizöl | 118,11 EUR/hl ohne USt (Destatis, Juli 2026, laut Sekundärquelle) | unsicher |

Die Energiepreispfade werden im Energie-/MC-Memo vertieft; hier nur der Hinweis, dass sie **perspektivenabhängig** in den Cashflow eingehen: beim Selbstnutzer vollständig, beim Vermieter nur über CO2-Anteil, Netzentgeltanteil (§ 5a), Leerstand und mittelbar über Mieterhöhungsspielräume (Warmmietenneutralität).

### 1.10 Restwert / Verkaufserlös am Horizont

Siehe Abschnitt 7. Im VoFi am Ende von Periode T: `+ Restwert_netto − Restschuld − Vorfälligkeitsentschädigung`.

### 1.11 Übersicht: welche Zahlungsreihe gilt für welche Perspektive

| Zahlungsreihe | WU (Vermietung) | Genossenschaft | Kleinvermieter | Selbstnutzer |
|---|---|---|---|---|
| Investition KG 100–700 | ja | ja | ja | ja |
| Förderzuschüsse / Tilgungszuschüsse | ja | ja | ja | ja (plus Einkommens- und Klimageschwindigkeitsbonus) |
| Nettokaltmiete / Nutzungsentgelt | ja | ja (Nutzungsentgelt) | ja | nein (optional kalkulatorisch) |
| Modernisierungsumlage | ja | ja (oft freiwillig reduziert) | ja | nein |
| Stellplatz, PV, Mieterstrom | ja | ja | ja | PV-Eigenverbrauch/Einspeisung |
| Verwaltung, Instandhaltung, MAW | ja | ja | ja (Verwaltung oft Eigenleistung) | Instandhaltung ja |
| CO2-Vermieteranteil, § 5a-Netzentgelte | ja | ja | ja | nein (volle Energiekosten) |
| Energiekosten | nur Leerstand | nur Leerstand | nur Leerstand | ja, voll |
| Grundsteuer, Gebäudeversicherung | umlagefähig (nur Leerstand) | dito | dito | ja |
| Geschäftsanteile (EK der Mitglieder), Dividende | – | ja | – | – |
| Erbbauzins | optional | optional | optional | optional |
| Restwert | ja | ja | ja | ja |
| Ertragsteuern | Slot (v1 aus) | Slot | Slot | i. d. R. nicht relevant (außer § 35c, § 23 EStG) |

---

## 2. Mietrecht und quantitative Regeln

### 2.1 § 558 BGB – Mieterhöhung bis zur ortsüblichen Vergleichsmiete

Rechtsstand (Fassung seit 01.01.2020) [Q13]:
- **Wartefrist:** Die Miete muss im Zeitpunkt des Wirksamwerdens **seit 15 Monaten unverändert** sein; Erhöhungsverlangen frühestens 1 Jahr nach der letzten Erhöhung. **Erhöhungen nach §§ 559–560 bleiben unberücksichtigt.**
- **Vergleichsmiete:** Entgelte der letzten **6 Jahre**; Merkmale Art, Größe, Ausstattung, Beschaffenheit, Lage **einschließlich energetischer Ausstattung und Beschaffenheit**.
- **Kappungsgrenze:** innerhalb von 3 Jahren höchstens **+20 %**, in per Landesverordnung bestimmten Gebieten **+15 %** (Verordnung jeweils höchstens 5 Jahre); **Erhöhungen nach §§ 559–560 sind ausgenommen**.
- **Abs. 4:** Kappungsgrenze gilt nicht bei Wegfall der öffentlichen Bindung in Höhe der zuletzt gezahlten Fehlbelegungs-/Ausgleichszahlung.
- **Abs. 5 (wichtig für Förderung!):** Vom Jahresbetrag der Erhöhung sind **Drittmittel i. S. d. § 559a abzuziehen**, bei Zuschüssen mit **8 % des Zuschusses** pro Jahr ("Kürzungsbetrag").
- Wirksamkeit: ab Beginn des dritten Kalendermonats nach Zugang des Verlangens (§ 558b BGB).
- **Mietrecht II** ändert § 558 nicht (Kappungsgrenzen bleiben 20/15 %) [Q9]. Frühere Koalitionspläne (Absenkung auf 11 %) sind nicht Bestandteil des Entwurfs.

**Modellformel (Monatsraster):**

```
R_558_max(m) = min( OVM(m),
                    R(m−36) · (1 + k) + Σ_{τ ∈ (m−36, m]} ΔR_559(τ) )
               − Kürzungsbetrag(m) / (12 · Fläche)
zulässig, wenn m − m_letzte_558 ≥ 15 und R_558_max(m) > R(m)
```
mit `k ∈ {0,20; 0,15}`, `OVM(m)` = ortsübliche Vergleichsmiete für den **aktuellen** (ggf. modernisierten) Zustand, Wachstum `g_OVM` (MC-Parameter). Strategieparameter `rent_increase_policy`: "maximal" (jede zulässige Erhöhung sofort), "interval" (z. B. alle 36 Monate), "capped" (freiwillige Obergrenze, z. B. kommunale Selbstverpflichtung).

### 2.2 Zusammenspiel Modernisierungsumlage und spätere § 558-Erhöhungen

- Der Umlagebetrag nach § 559/559e wird **dauerhafter Bestandteil der Miete** (kein Abschmelzen).
- Er zählt **nicht** zur Kappungsgrenze und **nicht** zur 15-Monats-Wartefrist des § 558.
- Eine spätere § 558-Erhöhung ist nur möglich, soweit die (bereits um die Umlage erhöhte) Miete unter der Vergleichsmiete des **modernisierten** Zustands liegt. Die Umlage "verbraucht" also den durch die Modernisierung entstandenen Vergleichsmietenspielraum. Doppelte Berücksichtigung derselben Maßnahme in § 558 und § 559 ist unzulässig (nach meinem Kenntnisstand BGH, Urteil vom 16.12.2020 – VIII ZR 367/18, zur Kombination von § 558 und § 559; vor Implementierung juristisch verifizieren).
- **Kürzungsbeträge** (§ 558 Abs. 5): Fördermittel mindern auch spätere § 558-Erhöhungen (Zuschuss: 8 % p. a.; zinsverbilligte Darlehen: Jahresbetrag der Zinsermäßigung). Die zeitliche Dauer der Kürzung ist in Rechtsprechung/Literatur umstritten (unsicher) → Parameter `kuerzung_duration_years` (Default z. B. 12 Jahre für Zuschüsse ≈ 1/8 %, Dauer der Zinsbindung für Darlehen).

**Rechenbeispiel (eigene Simulation, Monatsraster):** Ausgangsmiete 7,50 EUR/m², Umlage 2,00 EUR/m² wirksam ab Monat 3, Vergleichsmiete modernisiert 9,20 EUR/m² (+2,5 %/a), Kappung 15 %.
- Monat 3: Miete 9,50 EUR/m² liegt **über** der Vergleichsmiete (9,26) → keine § 558-Erhöhung möglich.
- Erste § 558-Erhöhung in Monat 16 (auf 9,51), danach alle 15 Monate entlang der Vergleichsmiete (Monat 31: 9,81; Monat 46: 10,11; … Monat 106: 11,44 EUR/m²).
- Die Kappungsgrenze (7,50 · 1,15 + 2,00 = 10,63 EUR/m²) bindet hier nicht; bindend ist die Vergleichsmiete.

→ Test-Case für die Mietpfad-Engine.

### 2.3 § 559 BGB – Modernisierungsumlage (Regelverfahren)

Rechtsstand (Fassung seit 01.01.2024) [Q13]:
- **Umlagesatz:** jährliche Miete + **8 %** der für die Wohnung aufgewendeten Kosten (Maßnahmen nach § 555b Nr. 1, 3, 4, 5, 6; Nr. 4a mit Einschränkungen).
- **Abzug Erhaltungsanteil** (Abs. 2), Verteilung auf Wohnungen (Abs. 3).
- **Kappung (Abs. 3a):** Erhöhung der Monatsmiete innerhalb von 6 Jahren (ohne §§ 558, 560) höchstens **3,00 EUR/m²**; bei Ausgangsmiete **< 7,00 EUR/m² höchstens 2,00 EUR/m²**. Bei Einbau/Aufstellung einer **Heizungsanlage** (Nr. 1 oder 1a) zusätzlich: insoweit höchstens **0,50 EUR/m² in 6 Jahren**; die Grenzen nach Satz 1/2 bleiben unberührt.
- **Härteeinwand** (Abs. 4/5).
- **Drittmittel (§ 559a):**
  - Zuschüsse (öffentliche und Dritter) gehören nicht zu den aufgewendeten Kosten → **von den Kosten abziehen**.
  - Zinsverbilligte/zinslose öffentliche Darlehen → Erhöhungsbetrag mindert sich um den **Jahresbetrag der Zinsermäßigung** = `(i_markt − i_förder) · Ursprungsdarlehensbetrag`; maßgeblich ist der marktübliche Zins für **erstrangige Hypotheken bei Beendigung der Maßnahme**.
  - Mittel von Förderinstituten des Bundes/der Länder (KfW, Landesförderbanken) gelten als öffentliche Mittel; Mieterdarlehen/Mietvorauszahlungen wie öffentliche Darlehen.
  - **Tilgungszuschüsse** sind wie Zuschüsse zu behandeln (eigene Einordnung, gängige Praxis).
- Wirksamkeit: ab Beginn des dritten Monats nach Zugang der Erklärung; Verlängerung um 6 Monate bei fehlender/fehlerhafter Ankündigung oder > 10 % Abweichung (§ 559b Abs. 2).

**Formel (je Wohnung w):**

```
U_w,jahr = 0,08 · (K_w − IH_w − Z_w) − Σ_Darlehen (i_markt − i_förder) · L_w
U_w,monat,m² = U_w,jahr / (12 · A_w)
U_w,monat,m²,gekappt = min( U_w,monat,m², Kappe(R_w,vorher) − Σ U_frühere_6J ),
   Kappe = 3,00 falls R_vorher ≥ 7,00 sonst 2,00;
   Heizungsanteil zusätzlich ≤ 0,50 − Σ Heizungsumlagen_frühere_6J
```

**Rechenbeispiel 1 (eigene Berechnung):** 1 WE, 70 m², Ausgangsmiete 7,50 EUR/m². Kosten energetische Modernisierung 60.000 EUR, Instandhaltungsanteil 30 % = 18.000 EUR, KfW 261 EH 55 EE: Kredit 60.000 EUR mit 5 % Tilgungszuschuss = 3.000 EUR; KfW-Zins 3,53 % vs. Marktzins 3,80 % → Zinsermäßigung 162 EUR/a.
- `U = 0,08 · (60.000 − 18.000 − 3.000) − 162 = 3.120 − 162 = 2.958 EUR/a` = 3,52 EUR/m²·Monat
- Kappung 3,00 EUR/m² → **210,00 EUR/Monat (2.520 EUR/a)**.
→ Die Kappung bindet; jeder weitere Förder-Euro senkt die realisierbare Umlage hier **nicht**, was die Fördermittel-Anreizwirkung für Vermieter verändert (wichtiger Effekt fürs Tool).

### 2.4 § 559c BGB – Vereinfachtes Verfahren

Rechtsstand (Fassung seit 01.01.2024) [Q13]:
- Anwendbar, wenn die geltend gemachten Kosten je Wohnung **vor Abzug der Pauschale ≤ 10.000 EUR**.
- **Pauschaler Erhaltungsabzug 30 %**.
- § 559 Abs. 4 (Härte) und **§ 559a Abs. 2 S. 1–3 (Zinsverbilligung) nicht anwendbar** (Härte jedoch anwendbar bei Heizungsmaßnahmen nach Nr. 1/1a); Zuschüsse (§ 559a Abs. 1) bleiben abzuziehen (Lesart des Wortlauts; zu verifizieren).
- Anrechnung früherer Modernisierungskosten der letzten 5 Jahre (Abs. 2); **Sperrfrist 5 Jahre** für weitere § 559/559e-Erhöhungen (Abs. 4, Ausnahmen).
- **Mietrecht II (anhängig):** Wertgrenze **20.000 EUR** [Q9]. Übergangsregel: maßgeblich ist die Ankündigung vor/nach Inkrafttreten.

**Rechenbeispiel 2:** Kosten 18.000 EUR/WE, keine Zuschüsse. Geltendes Recht: nicht zulässig (> 10.000) → Regelverfahren. Nach Mietrecht II: zulässig, `U = 0,08 · 18.000 · 0,70 = 1.008 EUR/a = 84 EUR/Monat`.

### 2.5 § 559e BGB – Heizungsanlage (Fassung seit 29.07.2026)

Rechtsstand nach GModG (Gesetz vom 23.07.2026, BGBl. I Nr. 226, in Kraft 29.07.2026) [Q13]:
- Voraussetzung: Maßnahme nach **§ 555b Nr. 1a** (Einbau/Aufstellung einer Heizungsanlage i. S. v. **§ 42 GModG**), **dem Grunde nach förderfähig**, und Drittmittel wurden **in Anspruch genommen**.
- **Umlagesatz 10 %** der aufgewendeten Kosten **abzüglich der in Anspruch genommenen Drittmittel**.
- **Pauschal 15 %** der Kosten gelten als Erhaltungskosten – **gilt nicht für Kosten des Einbaus einer Heizungsanlage nach § 43** (neue Gas-/Öl-/Flüssiggasheizung mit Bio-Treppe).
- **Kappung 0,50 EUR/m² in 6 Jahren**; die Grenzen des § 559 Abs. 3a dürfen bei zusätzlichen § 559-Erhöhungen nicht überschritten werden.
- Wird trotz Förderfähigkeit keine Förderung in Anspruch genommen → nur § 559 (8 %, Kappung 0,50 EUR/m² für den Heizungsanteil).

**Formel:** `U_559e,jahr = 0,10 · (0,85 · K_w − D_w)`; `U_monat,m² = min(U/(12·A), 0,50 − frühere Heizungsumlagen)`.

**Rechenbeispiel 3 (eigene Berechnung):** MFH 6 WE à 70 m², Wärmepumpe 90.000 EUR (15.000 EUR/WE); förderfähige Höchstkosten (KfW 459) 28.000 + 5 · 15.000 = 103.000 EUR → Zuschuss 30 % · 90.000 = 27.000 EUR (4.500 EUR/WE).
- `U = 0,10 · (0,85 · 15.000 − 4.500) = 825 EUR/a` = 0,98 EUR/m²·Monat → **Kappung 0,50 → 35,00 EUR/Monat je WE (420 EUR/a)**.
- Vergleich § 559 ohne Förderung, Instandhaltungsanteil 40 %: 720 EUR/a = 0,86 EUR/m² → ebenfalls 35,00 EUR/Monat.
→ Bei Heizungstausch bindet die 0,50-EUR-Kappe fast immer; die Förderung entlastet dann faktisch den **Vermieter** (geringere Eigenmittel), nicht die Miete.

### 2.6 § 557a BGB – Staffelmiete

- Staffeln als **Euro-Beträge**, jede Staffel mind. 1 Jahr.
- Während der Laufzeit **keine Erhöhungen nach §§ 558–559b**; Mietrecht II würde **§ 559e ausdrücklich einbeziehen** [Q9] → bei Staffelmiete ist **keine Modernisierungsumlage** möglich (Ausnahme nach h. M. nicht für freiwillige Modernisierung).
- Mietpreisbremse gilt für **jede Staffel** (§ 557a Abs. 4).
- Modell: `rent_regime = "staffel"`, `staffel_steps = [{from, rent_per_m2}]`; nach Ablauf → § 558-Regime.

### 2.7 § 557b BGB – Indexmiete

Rechtsstand (Fassung seit 01.01.2024) [Q13]:
- Miete folgt dem **Verbraucherpreisindex** (Destatis); mind. 1 Jahr unverändert (ohne §§ 559–560).
- **§ 558 ausgeschlossen.**
- **§ 559/§ 559e nur für Maßnahmen, die der Vermieter nicht zu vertreten hat** (z. B. gesetzlich vorgeschrieben) – **Ausnahme: Heizungsmaßnahmen nach § 555b Nr. 1a sind umlagefähig**. Freiwillige energetische Hüllsanierung ist bei Indexmiete **nicht umlagefähig** → wichtige Regel für das Tool.
- Mietpreisbremse nur für die Ausgangsmiete.
- Wirksam ab übernächstem Monat nach Zugang der Erklärung (Textform).
- **Mietrecht II (anhängig, BT-Drs. 21/6807):** neuer Abs. 4: Übersteigt der Indexanstieg in einem Jahr **3 %**, bleibt **die Hälfte des übersteigenden Teils** unberücksichtigt – nur in Gebieten, die die Länder per Verordnung (max. 5 Jahre) bestimmen. Gilt symmetrisch auch bei Deflation; jahresweise ab Mietbeginn/letzter Erhöhung, zeitanteilig für angebrochene Jahre. Beispiel Begründung: Inflation 5 % → Erhöhung 4 % [Q9]. Der Referentenentwurf (starre 3,5-%-Grenze) ist überholt.

**Formel (Mietrecht II, je Jahr j):** `Δ_zul = π_j` falls `π_j ≤ 3 %`, sonst `3 % + 0,5 · (π_j − 3 %)` (bei Deflation analog `π_j < −3 %` → `−3 % + 0,5 · (π_j + 3 %)`; Symmetrie laut Begründung, genaue Lesart bei Implementierung prüfen).

### 2.8 Mietpreisbremse §§ 556d–556g BGB

- Wiedervermietungsmiete in Gebieten mit Landesverordnung höchstens **OVM + 10 %** (§ 556d Abs. 1).
- Ausnahmen/Besonderheiten: Vormiete bleibt geschützt (§ 556e Abs. 1); Modernisierung in den letzten 3 Jahren → Zuschlag in Höhe einer fiktiven § 559-Erhöhung (§ 556e Abs. 2; Mietrecht II ergänzt § 559e); **Neubau: Wohnungen, die nach dem 01.10.2014 erstmals genutzt und vermietet werden, sind dauerhaft ausgenommen** (§ 556f S. 1); **erste Vermietung nach umfassender Modernisierung ausgenommen** (§ 556f S. 2).
- **Laufzeit:** Verordnungsermächtigung verlängert, Gebiete können bis **31.12.2029** bestimmt werden (Bundestag 26.06.2025, Bundesrat 11.07.2025; Quellenlage zum Bundestagsdatum widersprüchlich) [Q14]. Länder haben verlängert (z. B. Berlin ab 01.01.2026 bis Ende 2029, Hamburg). Eine Expertenkommission soll bis 31.12.2026 Vorschläge u. a. zu Bußgeldern vorlegen. Die Neubau-Ausnahme (Stichtag 01.10.2014) wurde nach meinem Kenntnisstand nicht geändert (Sekundärquellen, nicht im BGBl. geprüft).
- **Mietrecht II (anhängig):** Möblierungszuschlag max. 1 %/Monat des Zeitwerts der Einrichtung, Vermutung der Angemessenheit bis 10 % der Nettokaltmiete bei Vollmöblierung; Auskunftspflicht; Kurzzeitvermietung max. 6 (8) Monate.

**Modell Neuvertragsmiete:**
```
R_neu(m) = R_markt(m)                             falls keine Bremse oder Ausnahme (Neubau, umfassende Modernisierung)
R_neu(m) = max( min(R_markt(m), 1,10 · OVM(m) + Z_556e2), R_vormiete )   sonst
```
Bestandsmiete im Portfolio: Kohorten- oder Fluktuationsmodell: `R̄_t = (1 − f) · R_bestand,t + f · R_neu,t`.

### 2.9 Status-Tabelle Mietrecht (versionierte Rechtsstände)

| Regel | geltend (25.10.2026) | Mietrecht II (BT-Drs. 21/6807, anhängig) | Schalter |
|---|---|---|---|
| § 558 Kappung | 20 % / 15 % | unverändert | – |
| § 559 Satz / Kappe | 8 %; 3 / 2 EUR/m²; Heizung 0,50 | unverändert | – |
| § 559c Wertgrenze | 10.000 EUR | 20.000 EUR | `mietrecht_ii` |
| § 559e | 10 %, 15 % Pauschale (nicht § 43-Heizung), 0,50 EUR/m² | Folgeänderungen (§ 557a, § 556e, § 561, § 555c) | `mietrecht_ii` |
| § 536 Abs. 1a Minderungsausschluss | 3 Monate, nur § 555b Nr. 1 | 3 Monate, Nr. 1 **und 1a** | `mietrecht_ii` |
| § 557b Indexmiete | voller VPI | Dämpfung > 3 % (Hälfte) in Verordnungsgebieten | `mietrecht_ii` + `index_cap_area` |
| Mietpreisbremse | bis 31.12.2029 (Länder-VO) | Möblierung, Kurzzeit | `mietpreisbremse_area` |

Stand Gesetzgebung Mietrecht II: Kabinett 29.04.2026; BT-Drs. 21/6807 vom 01.07.2026; 1. Lesung 09.07.2026; Bundesrat forderte Nachbesserungen (12.06.2026), Gegenäußerung ablehnend; Anhörung Rechtsausschuss 14.10.2026; Union fordert Lockerungen (Kurzzeitmiete, Schonfrist) [Q9, Q10, Q11]. Inkrafttreten: am Tag nach Verkündung, Möblierung/Kurzzeit erst am 1. Tag des 4. Folgemonats.

---

## 3. CO2-Kostenaufteilungsgesetz (CO2KostAufG) und CO2-Preis

### 3.1 Stufenmodell Wohngebäude (Anlage zu §§ 5–7 CO2KostAufG) [Q7]

| Stufe | CO2-Ausstoß kg CO2/(m² Wohnfläche · a) | Anteil Mieter | Anteil Vermieter |
|---|---|---|---|
| 1 | < 12 | 100 % | 0 % |
| 2 | 12 bis < 17 | 90 % | 10 % |
| 3 | 17 bis < 22 | 80 % | 20 % |
| 4 | 22 bis < 27 | 70 % | 30 % |
| 5 | 27 bis < 32 | 60 % | 40 % |
| 6 | 32 bis < 37 | 50 % | 50 % |
| 7 | 37 bis < 42 | 40 % | 60 % |
| 8 | 42 bis < 47 | 30 % | 70 % |
| 9 | 47 bis < 52 | 20 % | 80 % |
| 10 | ≥ 52 | 5 % | 95 % |

Weitere Regeln (Kurzfassung; Detailwortlaut bei Implementierung prüfen):
- Ermittlung jährlich mit der Heizkostenabrechnung aus Brennstoffmenge und Emissionsfaktor laut Lieferantenrechnung; Bezug: Wohnfläche.
- Selbstversorgung des Mieters (z. B. Gasetagenheizung): Mieter ermittelt, Vermieter erstattet seinen Anteil (§ 6).
- Öffentlich-rechtliche Beschränkungen (Denkmalschutz, Erhaltungs-/Milieuschutzsatzung), die einer wesentlichen energetischen Verbesserung entgegenstehen: Vermieteranteil wird gekürzt (Halbierung bzw. Entfall; § 9) → Parameter `co2_landlord_share_reduction`.
- Nichtwohngebäude: grundsätzlich 50/50 (für das Tool nicht relevant).
- Fernwärme: CO2-Kosten im Wärmepreis enthalten, Ausweisung durch Versorger erforderlich.

### 3.2 Neu durch GModG: §§ 5a–5d CO2KostAufG (in Kraft seit 29.07.2026) [Q8]

- **§ 5a (Bestandsgebäude):** Vermieter, die eine Heizungsanlage nach **§ 43 Abs. 1** (neue Gas-, Öl-, Flüssiggasheizung mit Bio-Treppe) einbauen und betreiben:
  - ab **01.01.2028**: **Gasnetzentgelte** (§ 40 Abs. 3 Nr. 4 EnWG) **hälftig**,
  - ab **01.01.2028**: **CO2-Kosten pauschal hälftig** (abweichend vom Stufenmodell),
  - ab **01.01.2029**: Kosten des **verpflichtenden biogenen Brennstoffanteils** hälftig, soweit der Anteil **höchstens 30 %** des verbrauchten Brennstoffs ausmacht (Preisbestandteil nach § 3 Abs. 1 Nr. 6).
  - Übergang: Einbau wegen irreparablen Ausfalls < 12 Monate vor 01.01.2028 → 12 Monate keine Anwendung.
- **§ 5b (Neubau):** entsprechende Anwendung auf Neubauten, die bis Ende 2029 errichtet werden, sofern Bauantrag ab 13.05.2026 (laut Haufe 04.08.2026; Wortlaut nicht vollständig geprüft).
- **§ 5c:** Evaluierung 2036.
- **§ 5d (Härtefall Kleinvermieter):** Stufenmodell gilt weiter, wenn u. a. ≤ 6 vermietete Wohnungen, Effizienzklasse G oder H, Miete < 85 % der OVM (in angespannten Märkten < 70 %), Information des Mieters in Textform (laut Haufe; fünf Voraussetzungen insgesamt).
- Ein Evaluationsbericht des BMWE zum CO2KostAufG wurde im April 2026 vorgelegt; konkrete Abschaffungspläne des Stufenmodells sind nicht bekannt (Haufe).

### 3.3 Berechnung der CO2-Kosten

```
CO2_t  [t]     = Σ_Träger E_Träger,t [kWh_Hi] · EF_Träger [kg/kWh_Hi] / 1000
spez_t [kg/m²] = CO2_t · 1000 / Wohnfläche
Kosten_t [EUR] = CO2_t · P_CO2,t · (1 + USt)
Vermieter_t    = s(spez_t) · Kosten_t            (Stufenmodell)
               = 0,5 · Kosten_t                  (§ 5a, neue § 43-Heizung ab 2028)
```
Emissionsfaktoren (Standardwerte nach BEHG-Berichterstattung, eigene Umrechnung; im Tool aus Lieferantenrechnung überschreibbar):
- Erdgas: 0,0561 t/GJ (Hi) = **0,202 kg/kWh_Hi** ≈ 0,182 kg/kWh_Hs (Hs/Hi ≈ 1,11). **Achtung Hs/Hi-Verwechslung**: Gas wird in kWh_Hs abgerechnet.
- Heizöl EL: 0,074 t/GJ = **0,266 kg/kWh_Hi** (≈ 2,65 kg/l).
- Flüssiggas: ca. 0,239 kg/kWh_Hi (unsicher).
- Biogene Anteile: 0 im BEHG/ETS2-Sinne (nachhaltigkeitszertifiziert).

**Rechenbeispiel 4 (eigene Berechnung):** MFH 1.000 m², Erdgas 150 kWh_Hs/m²a → 27,3 t CO2/a, 27,3 kg/m²a → Stufe 5 → Vermieter 40 %.

| CO2-Preis (EUR/t netto) | Kosten brutto (EUR/a) | Vermieter Stufenmodell (EUR/a) | Vermieter § 5a (50 %) |
|---|---|---|---|
| 55 | 1.787 | 715 | 893 |
| 65 | 2.111 | 845 | 1.056 |
| 100 | 3.248 | 1.299 | 1.624 |
| 150 | 4.873 | 1.949 | 2.436 |

### 3.4 CO2-Preis: BEHG und ETS2 (Preisbibliothek)

| Jahr | Preis (EUR/t, netto) | Status / Quelle |
|---|---|---|
| 2021 | 25 | Festpreis BEHG |
| 2022 | 30 | Festpreis |
| 2023 | 30 | Festpreis (Erhöhung ausgesetzt) |
| 2024 | 45 | Festpreis |
| 2025 | 55 | Festpreis |
| 2026 | 55–65 (Korridor, Versteigerung) | BEHG [Q4, Q5] |
| 2027 | 55–65 (Korridor) | 3. BEHG-Änderungsgesetz, Drs. 21/7869; **Bundestag beschlossen 15.10.2026** (303 ja / 210 nein / 52 Enth.); Überschussmengenpreis 71 EUR, Rückkaufpreis 73 EUR; Bundesrat (BR-Drs. 462/26) stand zum Abruf aus [Q4] |
| ab 2028 | ETS2-Marktpreis | ETS2-Vollstart 01.01.2028 (Verschiebung um ein Jahr, EU-Einigung Nov. 2025; nationale Umsetzung TEHG); Auktionen ab 18.01.2027 laut Sekundärquelle; Preisstabilitätsmechanismus: Freigabe aus Marktstabilitätsreserve ab **45 EUR/t in Preisen 2020** (≈ 60 EUR nominal 2027/28), zusätzliche 20 Mio. Zertifikate je Freigabe, bis 2 Freigaben/Jahr; Ratsbeschluss Oktober 2026 (Amtsblatt-Veröffentlichung nicht geprüft) [Q6] |

**MC-Empfehlung:** 2026/2027 Gleichverteilung im Korridor (oder Punktwert 65 als konservativer Wert, da Versteigerungen am oberen Rand zu erwarten), ab 2028 log-normaler Pfad mit Szenario-Mischung (z. B. "MSR wirkt" mit Median 60–80 EUR, "Knappheit" Median 120–200 EUR bis 2030; Prognosen in Sekundärquellen streuen von moderat bis 100–250 EUR/t [Q3]). Werte ausschließlich in `params/co2_price.yaml`.

---

## 4. GEG / GModG und Effizienzhausstandards

### 4.1 Stand Gebäudemodernisierungsgesetz (GModG) [Q1, Q2, Q3]

| Datum | Schritt |
|---|---|
| 24.02.2026 | Eckpunkte (Wegfall pauschale 65-%-Vorgabe) |
| 13.05.2026 | Kabinettsbeschluss |
| 21.05.2026 | Bundestag verschiebt (Omnibus) die 65-%-Frist für Gemeinden > 100.000 EW vom 01.07. auf 01.11.2026 (BGBl. 2026 I Nr. 191, Art. 8) – durch GModG faktisch überholt |
| 10.07.2026 | Bundestag (3. Lesung) und Bundesrat |
| 28.07.2026 | Verkündung BGBl. 2026 I Nr. 226 |
| **29.07.2026** | Inkrafttreten Stufe 1 (Art. 1, 5, 6, 8): neue Wärmeversorgungsregeln §§ 42–46, Evaluation § 9a, Gebäudeautomation § 56 (erste Fassung), Quartier § 107; CO2KostAufG §§ 5a–5d; BGB § 555b Nr. 1a/§ 559e angepasst |
| 1. Tag des 6. Folgemonats (eigene Ableitung: **01.01.2027**) | Art. 2: neue Normen/Bilanzierung (DIN/TS 18599:2025-10, Nutzfläche = beheizte NRF nach DIN 277), **neues Referenzgebäude ohne Faktor 0,55**, MEPS für Nichtwohngebäude, neue Energieausweise (digital, Klassen A–G für NWG), Ökobilanzierung |
| 01.01.2028 | Nullemissionsstandard für neue öffentliche NWG; LCA-Bericht für Neubauten > 1.000 m² |
| **01.01.2030** | **Nullemissionsstandard für alle Neubauten** (§ 10 Abs. 2 Nr. 3: keine CO2-Emissionen aus fossilen Brennstoffen am Standort); LCA-Bericht für alle Neubauten |

**Kerninhalte mit Wirtschaftlichkeitsrelevanz:**
- **65-%-EE-Regel für neue Heizungen entfällt**, ebenso Betriebsverbote (§§ 71, 71b–72 GEG gestrichen, d. h. auch die 30-Jahre-Austauschpflicht für Konstanttemperaturkessel). Freie Wahl: Wärmepumpe, Hybrid, Biomasse, Fernwärme, **Gas/Öl wieder zulässig**.
- **Bio-Treppe (§ 43 Abs. 1)** für neue Gas-/Öl-/Flüssiggasheizungen im Bestand: Anteil Biomethan, Bioöl, biogenes Flüssiggas, Wasserstoff (grün/blau/orange/türkis) inkl. Derivate: **10 % ab 01.01.2029, 15 % ab 2030, 30 % ab 2035, 60 % ab 2040**. Erfüllungsoptionen: Solarthermie (vereinfachte Flächenvorgaben 2029–2034), RLT mit WRG, Wärmepumpen-Hybrid (Mindestleistung WP), bis 2035 vereinfacht; Nachweispflichten (§ 96: Lieferbelege 5 Jahre aufbewahren).
- **§ 42a**: Grüngas-/Grünheizölquote für Inverkehrbringer, Gesetz bis 01.12.2026 angekündigt; ab 2045 vollständige Umstellung.
- **Neubau:** Ab Art. 2 entspricht der zulässige Primärenergiebedarf dem neuen Referenzgebäude (Gesetzgeber: annähernd früheres GEG-55-Niveau); baulicher Wärmeschutz bleibt zweite Anforderung. Ab 2030 Nullemissionsgebäude → **fossile Wärmeerzeuger im Neubau ab 2030 faktisch ausgeschlossen**; eine 15-%-Bio-Beimischung reicht nicht.
- **Stromdirektheizung (§ 46):** Hüllanforderungen Neubau 45 %, Bestand 30 % besser als gesetzlich.
- **Förderung für Heizungstausch** laut BMWSB "bis mindestens 2029 abgesichert".
- **Mieterschutz** nur über CO2KostAufG §§ 5a–5d und § 559e (keine 15-%-Pauschale bei § 43-Heizung). Weitergehende Vorschläge (Ausschluss fossiler Heizungen von der Umlage, "Technologieausgleichsfaktor") wurden nach Quellenlage **nicht** Gesetz (unsicher).
- **Evaluation 2030** mit Nachsteuerungsmechanismus (§ 9a) → Regulierungsrisiko für fossile Heizungen über den Horizont (MC-Szenario "Nachschärfung 2030").

**Wichtige Modellfolge:** Das Tool muss für neue fossile Heizungen den **Bio-Anteil-Pfad** (Preisaufschlag Biomethan/Bioöl, MC-Parameter), die **§ 5a-Kostenteilung** und das **Restwert-/Stranded-Asset-Risiko** abbilden; für Wärmepumpen die Strompreis- und JAZ-Unsicherheit. Die Bezeichnung des Gesetzes ist in Verweisnormen uneinheitlich ("GEG"/"GModG"); im Tool neutral `building_energy_law` mit Paragrafenbezug verwenden.

### 4.2 Effizienzhausstandards (BEG WG) – Definition

Anforderungen relativ zum Referenzgebäude (Jahres-Primärenergiebedarf Qp und Transmissionswärmeverlust H'T), Stand BEG WG (aus meinem Fachwissen, vor Implementierung gegen Technische Mindestanforderungen prüfen):

| Stufe | Qp (% Referenz) | H'T (% Referenz) | Hinweis |
|---|---|---|---|
| EH 40 | 40 | 55 | – |
| EH 55 | 55 | 70 | – |
| EH 70 | 70 | 85 | – |
| EH 85 | 85 | 100 | – |
| EH Denkmal | 160 | 175 | auch besonders erhaltenswerte Bausubstanz |
| **EE-Klasse** | – | – | ≥ 65 % des Wärmebedarfs aus erneuerbaren Energien, unvermeidbarer Abwärme oder WRG; **seit 21.07.2026 Fördervoraussetzung** für EH-Sanierung (kein eigener Bonus mehr) [Q24] |
| **NH-Klasse** | – | – | Qualitätssiegel Nachhaltiges Gebäude (QNG) → höherer Tilgungszuschuss (+5 Pp) |
| **WPB** (Worst Performing Building) | – | – | Wohngebäude mit Energieausweis-Klasse **H** (oder schlechter); alternativ Baujahr ≤ 1957 und ≥ 75 % der Außenwandfläche energetisch unsaniert (laut BEG-Auslegung vom 17.07.2026 Einschränkungen für bestimmte Gebäudearten; zu prüfen) [Q25] → +10 Pp Tilgungszuschuss bei EH 40/55/70 |
| **SerSan** (serielle Sanierung) | – | – | +15 Pp (EH 40/55), +5 Pp (EH 70), kumulierbar mit WPB/NH |

**Offene Frage:** Mit dem neuen Referenzgebäude ab 01.01.2027 (Art. 2 GModG) verschiebt sich die Bezugsbasis der EH-Stufen. Ob BEG-Richtlinien die EH-Definitionen anpassen, war nicht recherchierbar → im Tool EH-Stufe als **Kategorie** (Input) führen, nicht aus Qp berechnen.

**Neubau (KFN):** EH 40 + QNG-PLUS-Lebenszyklusanforderungen (LCA; ohne Öl/Gas/Biomasse) bzw. **EH 55 (neu seit 16.12.2025, ohne Öl/Gas, Biomasse zulässig, 800 Mio. EUR Budget 2025/2026, Haushaltsvorbehalt)** [Q18]. Da das neue gesetzliche Referenzniveau ab 2027 etwa EH-55 entspricht, ist die KFN-EH-55-Förderung faktisch eine Förderung des künftigen Mindeststandards (Hinweis für Szenarien).

### 4.3 iSFP-Bonus (individueller Sanierungsfahrplan)

- BEG EM (BAFA, Gebäudehülle/Anlagentechnik): **+5 Pp** (15 % → 20 %), Verdopplung der förderfähigen Höchstkosten (30.000 → 60.000 EUR für 1. WE; 15.000 → 30.000 je WE 2–6; 8.000 → 15.000 ab 7. WE) [Q23].
- **Seit 21.07.2026:** Bonus nur, wenn die förderfähigen Ausgaben in einem Antrag die Mindestinvestition erreichen (Gebäude mit 1 WE: **30.000 EUR**; mehrere WE: Höchstgrenze ohne Bonus, z. B. 3 WE = 60.000 EUR), und **nur auf den Betrag oberhalb** dieser Schwelle [Q23].
  - Beispiel (Sekundärquelle): 40.000 EUR Fassadendämmung EFH → 15 % · 40.000 + 5 % · 10.000 = 6.500 EUR.
- Gilt nicht für Heizungstausch (KfW 458/459).
- WPB-Bonus für Dämmmaßnahmen in BEG EM voraussichtlich ab Q1 2027 (Höhe laut Kanzlei-Analyse +5 Pp; BAFA nennt keine Höhe), Voraussetzung geförderter iSFP [Q23, Q24].

---

## 5. Förderprogramme (Stand 25.10.2026) und generisches Datenmodell

> Alle Konditionen stehen unter **Haushaltsvorbehalt**, ohne Rechtsanspruch. Antrag grundsätzlich **vor Vorhabenbeginn** (Abschluss Liefer-/Leistungsvertrag). Zinssätze werden **bei Zusage** fixiert. Zinsangaben aus der KfW-Konditionenübersicht, Stand **22.10.2026** [Q22].

### 5.1 BEG WG – KfW 261 "Wohngebäude – Kredit" (Sanierung zum Effizienzhaus) [Q15]

- **Typ:** Förderkredit mit **Tilgungszuschuss**; Richtlinie BAnz 02.09.2026; Konditionen seit 21.07.2026.
- **Antragsberechtigt:** Privatpersonen, WEG, Unternehmen, kommunale Unternehmen, Genossenschaften, gemeinnützige Organisationen, Körperschaften.
- **Kredithöchstbetrag:** **150.000 EUR je WE** (alle EH-Stufen).
- **Tilgungszuschuss (je WE, auf max. 150.000 EUR):**

| Stufe | EE | NH | Boni |
|---|---|---|---|
| EH 40 | 10 % (15.000) | 15 % (22.500) | WPB +10 Pp, SerSan +15 Pp |
| EH 55 | 5 % (7.500) | 10 % (15.000) | WPB +10 Pp, SerSan +15 Pp |
| EH 70 | 0 % | 5 % (7.500) | WPB +10 Pp, SerSan +5 Pp |
| EH 85 | 0 % | 5 % (7.500) | – |
| EH Denkmal | 5 % (7.500) | 10 % (15.000) | – |

  Maximal (EH 40 NH + WPB + SerSan) 40 % = 60.000 EUR/WE.
- **Laufzeit/Tilgungsfreiheit/Zinsbindung (Annuität):** 4–10 J./1–2 J./10 J.; 11–20 J./1–3 J./10 J.; 21–30 J./1–5 J./10 J.; endfällig 4–10 J.
- **Zins (22.10.2026, gültig ab 29.09.2026):** 10/2/10: 3,01 % (eff. 3,05 %); 20/3/10: 3,53 % (3,59 %); 30/5/10: 3,65 % (3,71 %); 10/10/10 endfällig: 3,71 % (3,77 %).
- **Bereitstellung:** Abruffrist 12 Monate, automatische Verlängerung bis 36 Monate; **0,15 %/Monat ab 13. Monat**.
- **Sondertilgung:** nicht möglich; vorzeitige Gesamtrückzahlung mit Vorfälligkeitsentschädigung.
- **Baubegleitung:** Zusatzkredit mit 50 % Tilgungszuschuss (EFH bis 10.000 EUR; MFH 4.000 EUR/WE, max. 40.000 EUR).
- **Mietrecht:** Tilgungszuschuss = Zuschuss (§ 559a Abs. 1); Zinsvorteil ggü. Hypothekenmarktzins = Zinsermäßigung (§ 559a Abs. 2). Aktuell liegt der KfW-Zins nur geringfügig unter Marktniveau → Subventionswert hauptsächlich im Tilgungszuschuss.

**Rechenbeispiel 5 (eigene Berechnung, jährlich vereinfacht):** 150.000 EUR, 30/5/10, 3,65 %, Tilgungszuschuss 10 % (15.000 EUR) nach 2 Jahren gutgeschrieben.
- Anlaufjahre: Zinsen 5.475 EUR/a (nach Gutschrift 4.927,50 EUR/a).
- Annuität ab Jahr 6: ohne Zuschuss 9.249,88 EUR/a; mit Zuschuss, wenn die Annuität auf die reduzierte Restschuld berechnet wird: 8.324,90 EUR/a; alternativ bei gleicher Annuität **Laufzeitverkürzung** auf ca. 21,2 statt 25 Tilgungsjahre.
- Subventionsbarwert ggü. Marktkredit 3,90 % (Diskont 3,90 %): ≈ **18.400 EUR** (davon der überwiegende Teil Tilgungszuschuss).
→ Tool braucht Parameter `grant_effect = "reduce_annuity" | "shorten_term"` (Vorgehen der KfW je Produkt im Merkblatt prüfen) und `payment_frequency` (monatlich/vierteljährlich).

### 5.2 BEG EM – Heizungsförderung KfW 458 (Privatpersonen) / 459 (Unternehmen) / 422 (Kommunen) [Q16, Q17]

- **Typ:** Zuschuss auf förderfähige Kosten; Konditionen seit 21.07.2026, Richtlinie BAnz 27.08.2026.
- **Bausteine (458):**
  - Grundförderung **30 %** (alle Antragsteller, auch vermietete WE),
  - **Klimageschwindigkeitsbonus 16 %** (nur **selbstgenutzte** WE; Austausch funktionstüchtiger alter fossiler Heizung mit fachgerechter Entsorgung); **Degression −4 Pp je Halbjahr** ab 01.02.2027 (12 % ab 01.02.2027, 8 % ab 01.08.2027, 4 % ab 01.02.2028, **0 % für Anträge ab 01.08.2028**),
  - **Einkommensbonus** (nur Selbstnutzer; zu versteuerndes Haushaltseinkommen): ≤ 30.000 EUR: 40 %; 30.001–40.000: 30 %; 40.001–50.000: 10 %; > 50.000: 0 %. Mit kindergeldberechtigtem Kind < 18: Grenzen pauschal +10.000 EUR (≤ 40.000: 40 %; 40.001–50.000: 30 %; 50.001–60.000: 10 %),
  - **Effizienzbonus entfallen**,
  - **Obergrenze:** grundsätzlich **70 %**, **80 %** nur für Selbstnutzer mit zvE ≤ 30.000 EUR (bzw. ≤ 40.000 EUR mit Kind).
- **Förderfähige Höchstkosten je Gebäude:** 1. WE **28.000 EUR**, 2.–6. WE je 15.000 EUR, ab 7. WE je 8.000 EUR; gleichmäßige Verteilung auf die WE; **Degression 1. WE −750 EUR je Halbjahr ab 01.02.2027**.
- **459 (Unternehmen, Genossenschaften, kommunale Unternehmen, Contractoren):** 30 % Zuschuss, gleiche Höchstkosten (Beispiel KfW: 10 WE → 135.000 EUR → max. 40.500 EUR).
- **Angekündigt ab Q1 2027:** "Wertschöpfungsbonus"/"Made in Europe": Wärmepumpen aus Nicht-EU-Produktion ggf. nur 15 % Grundförderung (Details BMWE im 2. Halbjahr 2026) → Parameter `heat_pump_origin_eu`.
- **Fernwärme-Ausschluss** (nach Merkblatt): dezentrale Heizungen nicht förderfähig bei verbindlicher kommunaler Fernwärmeanschlusszusage innerhalb von 3 Jahren [Q24].
- **Ergänzungskredit 358/359** kombinierbar (5.4).

**Rechenbeispiel 6 (eigene Berechnung):** EFH-Selbstnutzer, WP 32.000 EUR, zvE 45.000 EUR ohne Kind:

| Antragszeitpunkt | Fördersatz | förderfähig | Zuschuss |
|---|---|---|---|
| bis 31.01.2027 | 30 + 16 + 10 = 56 % | 28.000 | 15.680 EUR |
| ab 01.02.2027 | 30 + 12 + 10 = 52 % | 27.250 | 14.170 EUR |
| ab 01.08.2028 | 30 + 0 + 10 = 40 % | 25.000 | 10.000 EUR |

→ Antragszeitpunkt ist ein entscheidungsrelevanter Parameter (Timing-Option); Degressionsregeln müssen datengetrieben sein.

### 5.3 BEG EM – Gebäudehülle, Anlagentechnik, Heizungsoptimierung, Fachplanung (BAFA) [Q23]

- Gebäudehülle (Dämmung Wand/Dach/Decken/Boden, Fenster, Außentüren, Vorhangfassaden, außenliegender Sonnenschutz): **15 %**, +5 Pp iSFP (siehe 4.3); Mindestinvestition 300 EUR brutto; Gebäude ≥ 5 Jahre alt; Energieeffizienz-Experte erforderlich.
- Höchstgrenzen: 30.000 / 15.000 / 8.000 EUR (ohne iSFP) bzw. 60.000 / 30.000 / 15.000 EUR (mit iSFP) je WE (1. / 2.–6. / ab 7.).
- Anlagentechnik (außer Heizung) und Heizungsoptimierung: nach meinem Kenntnisstand ebenfalls 15 % (+5 Pp iSFP); Fachplanung/Baubegleitung 50 % (Werte nicht neu geprüft, unsicher).
- Antragsberechtigt: alle Eigentümergruppen inkl. Unternehmen.

### 5.4 Ergänzungskredit KfW 358 / 359 [Q21]

- **Typ:** Förderkredit für Einzelmaßnahmen mit **bereits zugesagtem** BEG-EM-Zuschuss (Zusage ≤ 12 Monate alt).
- **358 ("Plus"):** natürliche Personen, **selbstgenutztes** EFH/ETW, Haushaltseinkommen **≤ 90.000 EUR** (Durchschnitt zvE 2. und 3. Jahr vor Antrag) → Zinsverbilligung.
- **359:** übrige (auch Unternehmen, WEG, MFH-Eigentümer) zu marktnäheren Konditionen.
- **Betrag:** bis 100 % der förderfähigen Kosten, max. **120.000 EUR je WE** (in der Praxis Kosten minus Zuschuss).
- Laufzeit bis 35 Jahre, Zinsbindung bis 10 Jahre; Merkblatt 09/2026, gültig ab 24.09.2026.
- **Zins (22.10.2026):** 358: 10/2/10: 1,48 % (eff. 1,49 %); 25/3/10: 2,53 % (2,56 %); 35/5/10: 2,68 % (2,71 %); 5/1/5: 0,01 %. 359: 10/2/10: 4,53 % (4,63 %); 25/3/10: 4,62 % (4,72 %); 35/5/10: 4,63 % (4,73 %).

### 5.5 Neubau: Klimafreundlicher Neubau KFN 297 (Selbstnutzung) / 298 (Vermietung, Unternehmen) [Q18, Q22]

- **Typ:** zinsverbilligter Förderkredit **ohne** Tilgungszuschuss.
- **Kredithöchstbetrag je WE:** 100.000 EUR (EH 55 bzw. EH 40 ohne QNG), **150.000 EUR mit QNG** (EH 40 + QNG-PLUS/PREMIUM).
- Anforderungen: EH 55 ohne Öl/Gas (Biomasse zulässig, Baugenehmigung bei Antrag); EH 40 + LCA nach QNG-PLUS ohne Öl/Gas/Biomasse; EH 40 + QNG-Zertifikat.
- Laufzeiten: 4–10 J. (1–2 tilgungsfrei), 11–25 J. (1–3), 26–35 J. (1–5), Zinsbindung 10 J.; endfällig 4–10 J.
- **Zins (22.10.2026):** Standard (EH 40, ab 17.09.2026): 10/2/10: 1,94 %; 25/3/10: 2,81 % (eff. 2,85 %); 35/5/10: 2,94 % (2,98 %). **EH 55 (ab 10.04.2026):** 10/2/10: 1,00 %; 25/3/10: 2,03 % (2,05 %); 35/5/10: 2,19 % (2,21 %).
- Bereitstellungsprovision 0,15 %/Monat ab 13. Monat.
- **KNN 296** (Klimafreundlicher Neubau im Niedrigpreissegment): 10/2/10: 0,01 %; 25/3/10: 1,37 %; 35/5/10: 1,60 % (Bedingungen nicht im Detail geprüft).

### 5.6 Wohneigentum für Familien KfW 300 (Neubau) und 308 (Bestandserwerb "Jung kauft Alt") [Q19, Q20, Q22]

**KfW 300:** Familien mit Kind(ern), Haushaltseinkommen (zvE) ≤ 90.000 EUR (1 Kind), 100.000 (2), 110.000 (3), 120.000 (4), 130.000 (5) + 10.000 je weiterem Kind. **EH 40** (KFN-Anforderungen). Kredithöchstbetrag: 170.000 EUR (1–2 Kinder) / 200.000 (3–4) / 220.000 (ab 5); mit QNG 220.000 / 250.000 / 270.000 EUR. Zins (22.10.2026): 10/2/10: 0,01 %; 25/3/10: 0,72 %; 35/5/10: 1,00 %; 10/10/10: 1,15 %.

**KfW 308:** Kauf einer selbstgenutzten Bestandsimmobilie der **Energieeffizienzklasse F, G oder H** (Ausweis bei Antrag), einzige Wohnimmobilie in DE; Kreditbetrag **140.000–180.000 EUR** nach Kinderzahl (laut KfW-Seite; ältere Werte 100.000–150.000 überholt; Staffel 140/160/180 laut Sekundärquelle); Einkommensgrenzen wie Familienförderung (90.000 EUR mit 1 Kind, + 10.000 je weiterem Kind; laut Suchergebnis ggf. abweichend formuliert, prüfen). **Sanierungspflicht** innerhalb von 54 Monaten auf mindestens **EH 85 EE** bzw. EH Denkmal EE (neuere Produktinfo; ursprünglich EH 70 EE; prüfen). Sanierungskosten nicht über 308, sondern über **261**. Zins wie 300.

### 5.7 Weitere Instrumente

- **KfW 124 Wohneigentumsprogramm** (marktnah, 21.10.2026: 25/3/10: 4,54 %), **KfW 134 Genossenschaftsanteile** (25/3/10: 0,74 %; 35/5/10: 1,02 %), **KfW 159 Altersgerecht Umbauen** (Kredit, ca. 3,1–4,0 %).
- **Soziale Wohnraumförderung der Länder** (generisch; Beispiel NRW, Förderrichtlinie Öffentliches Wohnen 2025, Änderung vom 23.03.2026 [Q30]):
  - zinsgünstige Förderdarlehen (z. T. 0 % in den ersten Jahren, später Anhebung), **Tilgungsnachlass** (NRW 2026: 30 % bzw. 35 % bei 25 bzw. 30 Jahren Zweckbindung, in teuren Mietstufen höher; Werte aus fragmentierter Quelle, prüfen),
  - **Mietpreisbindung**: Bewilligungsmiete je m² nach Mietstufe/Einkommensgruppe, zulässige jährliche Steigerung (NRW-Beispiel 1,7 %/a; programmabhängig),
  - **Belegungsbindung**: Vermietung nur an WBS-Berechtigte, Bindungsdauer 20–35 Jahre,
  - nach Bindungsende: Übergang auf § 558 (Kappungsgrenze gilt nicht in Höhe der weggefallenen Ausgleichszahlung, § 558 Abs. 4),
  - in Altfällen (vor 2002) Kostenmiete nach II. BV/NMV.
- **§ 35c EStG (nur Erwähnung, Steuer):** Steuerermäßigung für energetische Maßnahmen an **selbstgenutztem** Wohneigentum, 20 % der Aufwendungen verteilt auf 3 Jahre (7 % / 7 % / 6 %), **max. 40.000 EUR je Objekt** (entspricht 200.000 EUR Aufwand), Abschluss vor 01.01.2030; Energieberatung 50 %; **nicht kumulierbar mit BEG** für dieselbe Maßnahme. § 35c wurde zuletzt durch Art. 7 des Gesetzes vom 29.06.2026 (BGBl. 2026 I Nr. 197) geändert – Inhalt der Änderung nicht geprüft [Q31]. Im Tool als Instrumenttyp `tax_credit` vorsehen, in v1 inaktiv bzw. als einfache Zahlungsreihe (Selbstnutzer ohne sonstige Steuerlogik möglich, da nur Steuerminderung = Einzahlung).

### 5.8 Generisches Datenmodell für Förderinstrumente

**Anforderungen aus der Programmanalyse:**
1. Typen: Zuschuss, Förderkredit (annuitätisch/endfällig, tilgungsfreie Anlaufjahre, Zinsbindung), Tilgungszuschuss, reine Zinsverbilligung, Steuerermäßigung, Miet-/Belegungsbindung (Gegenleistung).
2. Bemessungsgrundlage: förderfähige Kosten mit **gestaffelten Höchstbeträgen je WE** (1. / 2.–6. / ab 7.), gleichmäßige Verteilung, je Gebäude oder je WE; Kreditbetrag als Bemessung für Tilgungszuschuss.
3. Satzbausteine mit **Bedingungen** (Selbstnutzung, Einkommen, Kinderzahl, Austausch fossiler Altanlage, WPB, NH, SerSan, iSFP, Herkunft WP) und **Gesamt-Obergrenze** (70/80 %).
4. **Schwellenwerte** (iSFP-Bonus nur oberhalb 30.000 EUR) und **Verdopplung von Höchstgrenzen** (iSFP).
5. **Zeitabhängigkeit:** Gültigkeit von/bis (Antragsdatum), **Degression** (Satz und Höchstbetrag, Halbjahresschritte), Auslaufen.
6. **Zeitpunkte:** Antrag vor Vorhabenbeginn, Auszahlung nach Verwendungsnachweis (Verzögerung in Monaten), Gutschrift Tilgungszuschuss.
7. **Kumulierung:** Ausschluss (z. B. § 35c vs. BEG), Höchstförderquote öffentlicher Mittel, Kombinationspflicht (358/359 nur mit EM-Zusage).
8. **Mietrechtliche Wirkung:** Zuschuss (Kostenabzug, § 558 Abs. 5: 8 %), Zinsverbilligung (Jahresbetrag), Laufzeit der Kürzung.
9. **Risiko:** Haushaltsvorbehalt (Wahrscheinlichkeit der Bewilligung), Programmänderung → MC-Parameter.
10. **Quelle und Stand** je Eintrag (Pflichtfelder).

**YAML-Schema (Vorschlag), Beispiel KfW 261 EH 55:**

```yaml
- id: kfw_261_eh55
  name_de: "BEG WG Kredit 261 – Effizienzhaus 55"
  provider: KfW
  program_code: "261"
  instrument_type: loan_with_repayment_grant   # grant | loan | loan_with_repayment_grant | interest_subsidy | tax_credit | rent_binding
  source: {url: "https://www.kfw.de/...(261-262)/", accessed: 2026-10-25, document: "Richtlinie BEG WG, BAnz 02.09.2026"}
  valid_from: 2026-07-21        # Antragsdatum
  valid_to: null
  budget_risk: {approval_probability: 0.95}   # Haushaltsvorbehalt, MC
  eligibility:
    applicants: [privatperson, weg, unternehmen, kommunales_unternehmen, genossenschaft]
    project_types: [sanierung]
    conditions:
      efficiency_standard: EH55
      ee_class: required
  basis:
    loan_cap_per_unit: 150000
    eligible_cost_kg: [300, 400, 700]       # förderfähige Kostengruppen (vereinfachend)
  loan:
    max_share_of_eligible_costs: 1.0
    variants:
      - {term_years: 20, grace_years: 3, fixed_years: 10, nominal_rate: 0.0353, effective_rate: 0.0359, rate_date: 2026-09-29}
      - {term_years: 30, grace_years: 5, fixed_years: 10, nominal_rate: 0.0365, effective_rate: 0.0371, rate_date: 2026-09-29}
    repayment: annuity
    payment_frequency: 12          # zu prüfen
    commitment_fee: {monthly_rate: 0.0015, free_months: 12}
    prepayment: {special_repayment: false}
    after_fixation: market          # Anschlusszins aus Zinsszenario
  repayment_grant:
    base_rate: {ee: 0.05, nh: 0.10}
    bonuses:
      - {id: wpb, rate: 0.10, condition: "building.wpb == TRUE"}
      - {id: sersan, rate: 0.15, condition: "measure.serial == TRUE"}
    cap_per_unit_basis: 150000
    payout: {event: verwendungsnachweis, lag_months: 6}
    effect: reduce_principal        # reduce_annuity | shorten_term
  rent_law:
    grant_counts_as: zuschuss_559a_abs1
    loan_counts_as: zinsverbilligung_559a_abs2
  cumulation:
    exclusive_with: [estg_35c]
```

**Beispiel KfW 458 (Zuschuss mit Bonusbausteinen, Degression):**

```yaml
- id: kfw_458_heizung_privat
  instrument_type: grant
  source: {url: "https://www.kfw.de/...(458)/", accessed: 2026-10-25, document: "Richtlinie BEG EM, BAnz 27.08.2026"}
  valid_from: 2026-07-21
  basis:
    eligible_cost_caps_per_building:      # Stufen nach WE-Anzahl
      - {units_from: 1, units_to: 1, cap: 28000}
      - {units_from: 2, units_to: 6, cap: 15000}
      - {units_from: 7, units_to: .inf, cap: 8000}
    distribution: equal_per_unit
  rate_components:
    - {id: grund, rate: 0.30}
    - {id: klimageschwindigkeit, rate: 0.16, condition: "unit.owner_occupied & heating.replaced_fossil_functional"}
    - id: einkommen
      condition: "unit.owner_occupied"
      schedule_by_taxable_income:
        thresholds: [30000, 40000, 50000]
        rates: [0.40, 0.30, 0.10, 0.00]
        child_u18_threshold_shift: 10000
  rate_cap:
    default: 0.70
    exceptions: [{condition: "unit.owner_occupied & taxable_income_adj <= 30000", cap: 0.80}]
  degression:
    - {target: rate_components.klimageschwindigkeit, start: 2027-02-01, step: -0.04, every_months: 6, floor: 0.0, end_rule: "0 ab 2028-08-01"}
    - {target: eligible_cost_caps_per_building[1], start: 2027-02-01, step: -750, every_months: 6}
  payout: {event: verwendungsnachweis, lag_months: 3}
  rent_law: {grant_counts_as: zuschuss_559a_abs1, enables: [bgb_559e]}
```

**Generische Berechnungsformel Zuschuss:**

```
K_ff     = min( K_eligible, Σ_WE Cap_staffel(n_WE, Datum) )
r        = min( Σ_k r_k(Bedingungen, Datum), r_cap(Bedingungen) )
G        = r · K_ff + Σ_Schwellenboni r_b · max(0, min(K, Cap_b) − S_b)
Tilgungszuschuss TZ = r_TZ · min(L, L_cap · n_WE)
Ergänzungskredit L_E = min(K_ff_EM − G, 120.000 · n_WE)
```

**Subventionsbarwert** (Kennzahl für Vergleich der Programme): `SBW = L − PV_{i_markt}(Zahlungen_Förderkredit)`; zusätzlich Ausweis "Förderquote = (Zuschüsse + SBW) / Investition".

---

## 6. Perspektiven und Zielfunktionen

### 6.1 Wohnungsunternehmen (kommunal, genossenschaftlich, privatwirtschaftlich)

| Ziel | Kennzahl(en) im VoFi-Output | Hinweis |
|---|---|---|
| Rendite | VoFi-Endwert, **VoFi-EK-Rendite** `r = (EW_T / EK_0)^(1/T) − 1`, Kapitalwert, Annuität | Zielrendite (Hurdle) als Parameter |
| Kapitaldienstfähigkeit | **DSCR_t** = (Mieterträge − nicht umlagefähige Bewirtschaftung) / Kapitaldienst; Minimum und Jahr des Minimums; ISCR; Cashflow nach Kapitaldienst | Covenants typisch 1,1–1,3 (unsicher) |
| Finanzierungsstruktur | LTV/Beleihungsauslauf, EK-Bindung, Liquiditätsunterdeckung (Kontokorrent) | – |
| Break-even | **Kostendeckende (Break-even-)Miete** je m² für Zielrendite/DSCR; erforderlicher Zuschuss | Zielwertsuche |
| Gemeinwohl/Mieter | Nettokaltmiete und **Warmmiete vorher/nachher**, Warmmietenneutralität (ΔNKM vs. ΔHeizkosten Mieter), Mietbelastung | besonders kommunal/Genossenschaft |
| Klima | CO2-Minderung t/a, kumuliert; **CO2-Vermeidungskosten** EUR/t; CO2-Kostenrisiko (Vermieteranteil); Pfadvergleich (z. B. CRREM, außerhalb v1) | – |
| Risiko (MC) | Verteilung VoFi-EK-Rendite, P(DSCR < 1), Value-at-Risk Endwert, Sensitivitäten (Tornado) | – |

**Genossenschaft:** Nutzungsentgelt statt Miete (Nutzungsverträge sind Mietverträge, §§ 558 ff. anwendbar), Förderzweck statt Renditemaximierung → Zielfunktion "kostendeckendes Nutzungsentgelt" bei Mindest-DSCR und Mindestliquidität; Finanzierungsquelle **Geschäftsanteile** (Pflichtanteile je WE, ggf. KfW 134) mit Dividende (0–4 %); oft freiwillig reduzierte Modernisierungsumlage.
**Kommunal:** Gesellschafterauftrag (Mietobergrenzen, Selbstverpflichtungen), Ausschüttungserwartung, Gesellschafterdarlehen; Ausweis Fördermittelbedarf.
**Privatwirtschaftlich:** Rendite, Exit-Wert, Portfolio-Wertentwicklung (Ertragswert vorher/nachher).

### 6.2 Kleinvermieter (Privatperson, 1–ca. 15 WE)

- VoFi-Endwert und EK-Rendite (Vorsteuer in v1), monatlicher Liquiditätssaldo, Eigenkapitalbedarf, Kapitaldienstdeckung.
- Rechtliche Engpässe stärker abbilden: § 559c (vereinfachtes Verfahren), Kappungen, Härtefälle, CO2KostAufG § 5d (Härtefall Kleinvermieter).
- **Steuer** hier am entscheidungsrelevantesten (AfA, Werbungskosten, Erhaltungsaufwand sofort/verteilt § 82b EStDV, anschaffungsnahe Herstellungskosten 15-%-Grenze § 6 Abs. 1 Nr. 1a EStG, § 23 EStG 10-Jahres-Frist) → v1.1-Kandidat.

### 6.3 Selbstnutzer

- **Wohnkosten/TCO:** jährliche bzw. monatliche Gesamtkosten (Kapitaldienst + Energie + Instandhaltung + Grundsteuer/Versicherung) Mit vs. Ohne Maßnahme.
- **Energiekostenersparnis**, **Amortisationszeit** (statisch/dynamisch), Endvermögen inkl. Restwert (VoFi-Endwert), Vermögenszuwachs.
- **Belastungsquote** = (Kapitaldienst + Wohnnebenkosten) / Haushaltsnettoeinkommen; Liquiditätstest.
- **Wertsteigerung:** Restwerteffekt der Energieklasse (Parameter `value_uplift_energy_class`, unsicher, MC).
- Optional: Vergleich Kaufen vs. Mieten (ersparte Miete kalkulatorisch).
- Förderspezifika: Einkommensbonus, Klimageschwindigkeitsbonus, 358-Zinsvorteil, ggf. § 35c (alternativ).

---

## 7. Restwert / Verkaufserlös am Horizont

### 7.1 Ertragswertverfahren (ImmoWertV 2021, §§ 27–34)

```
Rohertrag       RoE_T  = Σ marktüblich erzielbare Nettokaltmieten im Jahr T+1
Bewirtschaftung BWK_T  = Verwaltung + Instandhaltung + Mietausfallwagnis (+ nicht umlagefähige BK)
Reinertrag      RE_T   = RoE_T − BWK_T
Barwertfaktor   KF     = (q^n − 1) / (q^n · (q − 1)),   q = 1 + LZ,  n = RND_T
Allgemein (§ 28):    EW = (RE − BW · LZ) · KF + BW  (± besondere objektspezifische Grundstücksmerkmale)
Vereinfacht (§ 29):  EW = RE · KF + BW / q^n
```
- **LZ** = Liegenschaftszinssatz (Gutachterausschuss, regional): Großstädte Wohnen grob 1,5–3,5 %, ländlich 3,5–6 % (Sekundärquellen und ältere Auswertung: Bundesdurchschnitt MFH ≈ 3,26 % auf Basis 2018 [Q36]; aktuelle Werte aus Grundstücksmarktberichten). MC-Parameter.
- **Gesamtnutzungsdauer** Wohngebäude (EFH, ZFH, MFH): 80 Jahre (ImmoWertV Anlage 1).
- **Restnutzungsdauer** bei modernisierten Gebäuden: ImmoWertV **Anlage 2** [Q28]:
  `RND = a · Alter²/GND − b · Alter + c · GND`, anzuwenden ab relativem Alter (Alter/GND) ≥ Schwelle, sonst `RND = GND − Alter`.
  Punkteraster: Dach inkl. Dämmung 4, Fenster/Außentüren 2, Leitungssysteme 2, Heizung 2, Außenwanddämmung 4, Bäder 2, Innenausbau 2, Grundriss 2 (Summe 20). Koeffizienten (Auszug): 0 Pkt: a=1,25 b=2,625 c=1,525 (ab 60 %); 8 Pkt: 0,50/1,10/1,00 (ab 20 %); 12 Pkt: 0,364/0,808/0,9622 (ab 16 %); 18–20 Pkt: 0,20/0,44/0,942 (ab 10 %). Vollständige Tabelle 0–20 Punkte in Parameterbibliothek übernehmen (liegt vor, siehe Q28). Kernsanierung: RND bis 90 % der GND.
  - Beispiel (eigene Berechnung): Baujahr 1970, Stichtag 2026, GND 80: 0 Pkt → RND 24 J.; 8 Pkt → 38 J.; 12 Pkt → 46 J.; 18 Pkt → 58,6 J. → **Sanierung erhöht den Restwert über die RND deutlich** (wichtig für Differenzbetrachtung).
- **Bewirtschaftungskosten** nach Anlage 3 (2026: 367 EUR/WE, 14,40 EUR/m², MAW 2 %).
- **Rechenbeispiel 7 (eigene Berechnung):** MFH 10 WE, 700 m², 9,00 EUR/m²: RoE 75.600 EUR; BWK 15.262 EUR (20,2 %); RE 60.338 EUR; BW 200.000 EUR; LZ 3 %; RND 50 → KF 25,7298; **EW ≈ 1.598.100 EUR** (allgemeines und vereinfachtes Verfahren identisch bei konstantem RE); Rohertragsfaktor 21,1.

### 7.2 Vervielfältiger / Kaufpreisfaktor / Exit-Yield

`RW_T = NKM_{T+1} · F_T` bzw. `RW_T = NOI_{T+1} / y_exit`. Faktoren regional (grob: Top-Städte 22–30, B-Städte 17–23, ländlich 12–18; Erfahrungswerte, unsicher). Vorteil: einfach, marktnah; Nachteil: ignoriert Restnutzungsdauer und Energiezustand, außer man koppelt `F_T` an die Energieklasse (Parameter `multiplier_adjustment_by_energy_class`).

### 7.3 Sachwert-Restwert (linear)

`RW_T = Σ_c HK_c · (1 + g_bau)^T · max(0, 1 − Alter_c,T / ND_c) · SWF + BW_T`, mit Sachwertfaktor (Marktanpassung) `SWF`. Für Selbstnutzer-EFH die marktübliche Logik (Sachwertverfahren); für Maßnahmen-Differenzbetrachtung sinnvoll als **komponentenbasierter Restbuchwert** der Maßnahme (VDI-2067-artig): `RW_Maßnahme = K · (1 − (T − t_0)/ND)` (bei T < t_0 + ND).

### 7.4 Null-Restwert

Konservativ; geeignet für reine Maßnahmenbetrachtung mit Horizont ≈ Nutzungsdauer. Default nicht empfohlen (verzerrt gegen langlebige Hüllmaßnahmen).

### 7.5 Transaktionskosten und Exit

- Verkäuferseitig: Makler 0–3,57 % (inkl. USt), Vorfälligkeitsentschädigung bei Verkauf innerhalb der Zinsbindung (Parameter oder Berechnung Aktiv-Passiv-Methode vereinfacht), sonstige 0,1–0,5 %.
- Käuferseitige Erwerbsnebenkosten (GrESt 3,5–6,5 %, Notar/Grundbuch 1,5–2 %, Makler) reduzieren nicht den Verkehrswert, sind aber bei Erwerbsszenarien (t=0) Investitionsauszahlungen.
- **Grunderwerbsteuersätze 2026** (Sekundärquelle, gegen Landesrecht prüfen [Q32]): Bayern 3,5 %; Thüringen 5,0 % (seit 2024); Sachsen 5,5 % (seit 2023); Bremen 5,5 % (seit 01.07.2025); Brandenburg, NRW, Saarland, Schleswig-Holstein 6,5 %; übrige Länder 5,0–6,0 % (Einzelwerte in `params/grunderwerbsteuer.yaml` mit Quelle pflegen).
- Bodenwert-Fortschreibung `BW_T = BW_0 · (1 + g_boden)^T` (MC).

**Empfehlung Default:** Wohnungsunternehmen/Kleinvermieter → Ertragswert (allgemein) mit RND nach Anlage 2; Selbstnutzer → Sachwert bzw. Vergleichswert-Proxy (Wert/m² · Energieklassen-Uplift); Maßnahmen-Differenzbetrachtung → Ertragswert-Differenz Mit/Ohne oder Komponenten-Restbuchwert. Netto-Restwert immer abzüglich Verkäufer-Transaktionskosten.

---

## 8. Einschätzung Ertragsteuern (Komplexitätsgrad)

| Perspektive | Steuerlogik | Komplexität | Empfehlung |
|---|---|---|---|
| Selbstnutzer | keine laufende Einkommensteuer auf Nutzung; § 35c als Steuerermäßigung; Veräußerung nach 10 Jahren steuerfrei (§ 23 EStG) | gering | v1: § 35c optional als einfache Einzahlungsreihe (alternativ zur BEG) |
| Kleinvermieter | ESt mit Grenzsteuersatz, AfA (§ 7 Abs. 4 EStG 3 % für Neubau ab 2023, 2 %/2,5 % Bestand), degressive AfA/Sonder-AfA § 7b (Neubau), Erhaltungsaufwand sofort/verteilt, 15-%-Grenze, Verlustverrechnung, Zuschussbehandlung (Minderung AHK oder Einnahme) | mittel | **v1.1: vereinfachtes Modul** (konstanter Grenzsteuersatz, sofortige Verlustverrechnung, lineare AfA) |
| Wohnungsunternehmen (Kapitalgesellschaft) | KSt + SolZ + GewSt mit erweiterter Kürzung (§ 9 Nr. 1 S. 2 GewStG), Zinsschranke, Verlustvorträge, Organschaft | hoch | aus v1/v1.1 ausklammern |
| Genossenschaft | Vermietungsgenossenschaft ggf. steuerbefreit (§ 5 Abs. 1 Nr. 10 KStG, 10-%-Grenze) | mittel–hoch | ausklammern, Hinweis im Report |

**Begründung:** Das Vorsteuer-VoFi ist für Vergleiche von Maßnahmenvarianten (Fördervarianten, Heizsysteme, Timing) gut geeignet, da Steuereffekte die Rangfolge meist weniger stark verändern als Förderung und Mietrecht. Der VoFi nach Grob enthält ohnehin eine Steuerzeile; diese wird im Datenmodell als `tax_payments_t` (v1 = 0) vorgesehen, mit Schnittstelle `tax_module(cashflows, params) -> tax_t`.

---

## 9. Liste der modellierbaren Parameter (Input-Schema)

Legende: **MC** = sinnvoller Kandidat für stochastische Modellierung; Quellenkürzel [Qx] siehe Abschnitt 11. Defaults sind Startwerte, keine Empfehlungen für konkrete Projekte.

### 9.1 Meta, Szenario, Rechtsstand

| Schlüssel | Einheit | Bedeutung | Default / Bandbreite | MC |
|---|---|---|---|---|
| `scenario_id` | Text | Kennung der Variante | – | – |
| `valuation_date` | Datum | Bewertungsstichtag (t=0) | – | – |
| `application_date` | Datum | Förderantragsdatum (steuert Programmgültigkeit/Degression) | = valuation_date | – |
| `horizon_years` | a | Betrachtungszeitraum | 30 (WU), 20–30 (Selbstnutzer) | – |
| `engine_time_step` | enum | interne Zeitauflösung | `month` (Miete/Bau), Aggregation `year` | – |
| `perspective` | enum | `wu_kommunal`, `wu_genossenschaft`, `wu_privat`, `kleinvermieter`, `selbstnutzer` | – | – |
| `project_type` | enum | `neubau`, `sanierung_eh`, `sanierung_einzelmassnahmen`, `heizungstausch`, `erwerb_sanierung` | – | – |
| `comparison_mode` | enum | `absolute` / `differential` (Mit minus Ohne) | differential bei Sanierung | – |
| `legal_state` | Datum/Text | Rechtsstand der Regelbibliothek | 2026-10-25 | – |
| `pending_reforms` | Liste | aktivierte anhängige Reformen | [] (optional `mietrecht_ii`) | Szenario |
| `federal_state` | enum | Bundesland (GrESt, Verordnungen) | – | – |
| `mietpreisbremse_area` | bool + Datum bis | Gebiet mit Mietpreisbremse | – | – |
| `kappung_15_area` | bool | Gebiet mit 15-%-Kappung | – | – |
| `index_cap_area` | bool | Gebiet mit Indexmieten-Dämpfung (nur Mietrecht II) | false | – |
| `milieuschutz` / `denkmal` | bool | Beschränkungen (CO2KostAufG § 9, EH Denkmal) | false | – |
| `cpi_inflation` | %/a | Verbraucherpreisindex (Indexmiete, Kostenindizes) | 2,0 | MC |

### 9.2 Gebäude, Einheiten, Energiezustand

| Schlüssel | Einheit | Bedeutung | Default / Bandbreite | MC |
|---|---|---|---|---|
| `building_type` | enum | EFH, ZFH, DHH, RH, MFH, ETW | – | – |
| `construction_year` | Jahr | Baujahr | – | – |
| `n_units` | Anzahl | Wohneinheiten | – | – |
| `living_area_m2` | m² | Wohnfläche (WoFlV) je Unit-Gruppe | – | – |
| `net_floor_area_m2` | m² | beheizte NRF (GModG-Bezugsfläche ab 2027) | – | – |
| `n_parking_garage` / `n_parking_outdoor` | Anzahl | Stellplätze | 0 | – |
| `energy_class_before` / `_after` | A+–H | Energieeffizienzklasse | – | – |
| `efficiency_standard_after` | enum | EH40, EH55, EH70, EH85, EH_Denkmal, none | – | – |
| `ee_class` / `nh_class` | bool | EE-/NH-Klasse erreicht | – | – |
| `wpb_flag` | bool | Worst Performing Building | – | – |
| `serial_renovation` | bool | serielle Sanierung | false | – |
| `isfp_available` | bool + Datum | geförderter iSFP vorhanden (Bonus 15 Jahre) | false | – |
| `final_energy_before` / `_after` | kWh/m²a je Träger | Endenergie Bedarf | – | – |
| `prebound_factor` / `rebound_factor` | – | Verbrauch/Bedarf vor bzw. nach Sanierung | 0,8 / 1,0 (unsicher) | MC |
| `heating_before` / `heating_after` | enum | Gas, Öl, Flüssiggas, WP-Luft, WP-Sole, Hybrid, Fernwärme, Pellet, Strom-direkt | – | – |
| `heating_is_section43` | bool | neue fossile Heizung nach § 43 (Bio-Treppe, § 5a) | abgeleitet | – |
| `bio_share_path` | %/Jahr | Bio-Treppe 0,10 (2029), 0,15 (2030), 0,30 (2035), 0,60 (2040) [Q1] | Gesetz | – |
| `heat_pump_spf` | – | Jahresarbeitszahl | 3,0 (Spanne 2,5–4,0) | MC |
| `heat_pump_origin_eu` | bool | Herkunft WP (Wertschöpfungsbonus ab 2027) | true | – |
| `emission_factor` | kg/kWh_Hi je Träger | Gas 0,202; Öl 0,266; Flüssiggas 0,239 | Q-Liste | – |
| `hs_hi_ratio_gas` | – | Brennwert/Heizwert | 1,11 | – |
| `gnd_years` | a | Gesamtnutzungsdauer | 80 | – |
| `modernization_points_before` / `_after` | Punkte 0–20 | ImmoWertV Anlage 2 | – | – |

### 9.3 Investitionskosten und Bauphase

| Schlüssel | Einheit | Bedeutung | Default / Bandbreite | MC |
|---|---|---|---|---|
| `land_price` | EUR | Grundstückskaufpreis (KG 100) | – | – |
| `land_transfer_tax_rate` | % | Grunderwerbsteuer | Land: 3,5–6,5 [Q32] | – |
| `notary_registry_rate` | % | Notar + Grundbuch | 1,5–2,0 | – |
| `broker_rate_purchase` | % | Makler Erwerb | 0–3,57 | – |
| `ground_lease` | bool | Erbbaurecht statt Kauf | false | – |
| `ground_rent_rate` | %/a vom BW | Erbbauzins | 2–4 | – |
| `ground_rent_indexation` | %/a | Wertsicherung Erbbauzins | = CPI | MC |
| `cost_kg200` … `cost_kg600` | EUR oder EUR/m² | Kosten je KG | Kostenbibliothek | MC (Faktor) |
| `cost_kg700_rate` | % von KG 300+400 | Baunebenkosten | 18 (15–25) | MC |
| `contingency_rate` | % | Risikozuschlag Unvorhergesehenes | 10 (5–15) | MC |
| `construction_cost_factor` | – | Baukosten-Abweichungsfaktor | Dreieck 0,95/1,05/1,25 | MC |
| `construction_price_growth` | %/a | Baupreisindex bis Vergabe/Ersatzinvestition | 3,0 | MC |
| `vat_rate_costs` | % | USt auf Kosten (kein Vorsteuerabzug) | 19 (PV ≤ 30 kWp: 0) | – |
| `planning_months` / `construction_months` | Monate | Planungs-/Bauzeit | Tab. 1.3 | MC |
| `draw_schedule` | enum/Vektor | Mittelabfluss | linear / S-Kurve / MaBV | – |
| `construction_loan_rate` | %/a | Zins Bauzwischenfinanzierung | Marktszenario | MC |
| `commitment_fee_monthly` | %/Monat | Bereitstellungszins | KfW 0,15; Bank 0,25 | – |
| `commitment_free_months` | Monate | bereitstellungszinsfreie Zeit | KfW 12; Bank 3–12 | – |
| `measures[]` | Liste | Maßnahmen (siehe 9.4) | – | – |

### 9.4 Maßnahmen (je `measure`)

| Schlüssel | Einheit | Bedeutung | Default | MC |
|---|---|---|---|---|
| `measure_id`, `kg` | Text, KG | Kennung, Kostengruppe | – | – |
| `cost` | EUR brutto | Kosten | – | MC |
| `lifetime_years` | a | Nutzungsdauer (Ersatzzyklus) | Tab. 1.5 | MC |
| `replacement_cost_factor` | – | Ersatzkosten relativ zu Erstkosten | 1,0 | – |
| `sowieso_cost` | EUR | wirtschaftliche Ohnehin-Kosten (Ohne-Szenario) | – | MC |
| `sowieso_due_year` | Jahr | Fälligkeit der Ohnehin-Maßnahme | – | MC |
| `component_age` | a | Alter des ersetzten Bauteils (Abnutzungsgrad) | – | – |
| `maintenance_share_method` | enum | `linear_wear`, `fixed_share`, `flat_559c`, `flat_559e` | linear_wear | – |
| `maintenance_share_rent_law` | % | mietrechtlicher Instandhaltungsanteil | 20–50 | MC |
| `modernization_type` | enum | § 555b Nr. 1, 1a, 3, 4, 4a, 5, 6 / Erhaltung | – | – |
| `funding_eligible` | Liste IDs | zulässige Förderinstrumente | – | – |
| `modernization_points` | Punkte | Beitrag zur RND (Anlage 2) | – | – |

### 9.5 Erlöse und Mietrecht

| Schlüssel | Einheit | Bedeutung | Default / Bandbreite | MC |
|---|---|---|---|---|
| `rent_regime` | enum | `paragraph_558`, `staffel`, `index`, `bound_social`, `cooperative_fee`, `owner_occupied` | – | – |
| `initial_rent_per_m2` | EUR/m²·Monat | Ausgangs-Nettokaltmiete | – | – |
| `ovm_per_m2_unmod` / `_mod` | EUR/m²·Monat | Vergleichsmiete unmodernisiert/modernisiert | Mietspiegel | MC |
| `ovm_growth` | %/a | Wachstum Vergleichsmiete | 2,0–3,0 | MC |
| `market_rent_new_lease` | EUR/m²·Monat | Angebots-/Neuvertragsmiete | – | MC |
| `market_rent_growth` | %/a | Wachstum Marktmiete | – | MC |
| `kappung_rate` | % / 3 J. | Kappungsgrenze | 20 bzw. 15 | – |
| `rent_increase_policy` | enum | `max`, `interval`, `capped` | max | – |
| `voluntary_increase_cap` | %/a | Selbstverpflichtung (kommunal/Genossenschaft) | null | – |
| `mpb_factor` | – | Mietpreisbremse Faktor auf OVM | 1,10 | – |
| `first_use_after_2014_10_01` | bool | Neubau-Ausnahme § 556f S. 1 | abgeleitet | – |
| `comprehensive_modernization` | bool | Ausnahme § 556f S. 2 | false | – |
| `turnover_rate` | %/a | Fluktuation | 8 (5–12) | MC |
| `relet_vacancy_months` | Monate | Leerstand je Mieterwechsel | 1–3 | MC |
| `lease_up_months` | Monate | Erstvermietung Neubau | 3–6 | MC |
| `staffel_steps` | Liste | Staffelmieten (Datum, EUR/m²) | – | – |
| `index_threshold` / `index_excess_share` | % / – | Mietrecht II: 3 % / 0,5 | nur bei Schalter | – |
| `umlage_rate_559` | % | Modernisierungsumlage | 8 | – |
| `umlage_rate_559e` | % | Heizungsumlage | 10 | – |
| `umlage_cap_high` / `_low` / `_low_threshold` | EUR/m² | 3,00 / 2,00 / 7,00 | Gesetz | – |
| `umlage_cap_heating` | EUR/m² / 6 J. | 0,50 | Gesetz | – |
| `flat_maintenance_559e` | % | 15 (nicht § 43-Heizung) | Gesetz | – |
| `simplified_559c_limit` / `_flat` | EUR / % | 10.000 (Mietrecht II: 20.000) / 30 | Gesetz | – |
| `market_mortgage_rate_559a` | %/a | Marktzins erstrangige Hypothek bei Maßnahmenende | Zinsszenario | MC |
| `umlage_effective_delay_months` | Monate | Wirksamkeit (§ 559b) | 3 (bzw. 9) | – |
| `umlage_realization_rate` | % | Anteil durchsetzbarer Umlage (Härte, Streit) | 90–100 | MC |
| `kuerzung_duration_years` | a | Dauer Kürzungsbeträge § 558 Abs. 5 | 12 (Zuschuss), Zinsbindung (Darlehen) – unsicher | – |
| `works_rent_reduction_rate` | % | Mietminderung während Bauzeit | 15 (0–100) | MC |
| `minderung_exclusion_months` | Monate | Minderungsausschluss § 536 Abs. 1a | 3 | – |
| `parking_rent_month` | EUR/Monat | Stellplatzmiete | regional | MC |
| `pv_kwp`, `pv_yield_kwh_per_kwp` | kWp, kWh/kWp·a | PV-Leistung, Ertrag | 950 (850–1.100) | MC |
| `pv_self_consumption_share` | % | Eigen-/Mieterstromanteil | 30–60 | MC |
| `mieterstrom_price` | ct/kWh | ≤ 90 % Grundversorgungstarif (§ 42a EnWG) | – | MC |
| `feed_in_tariff`, `mieterstrom_premium` | ct/kWh | EEG-Vergütung, Mieterstromzuschlag | BNetzA-Werte | – |

### 9.6 Bewirtschaftung, CO2 und Risiken

| Schlüssel | Einheit | Bedeutung | Default / Bandbreite | MC |
|---|---|---|---|---|
| `admin_cost_per_unit` | EUR/WE·a | Verwaltung | 367 (ImmoWertV 2026) bzw. 372,46 (II. BV) | – |
| `admin_cost_per_condo` / `_per_parking` | EUR/a | Verwaltung ETW / Stellplatz | 439 / 48 | – |
| `maintenance_cost_per_m2` | EUR/m²·a | Instandhaltung | 14,40 (ImmoWertV); II. BV 11,50/14,58/18,62 | MC |
| `maintenance_parking` | EUR/Stellplatz·a | Instandhaltung Garage | 108 | – |
| `cost_index_growth` | %/a | Fortschreibung Bewirtschaftungskosten | = CPI | MC |
| `rent_loss_risk_rate` | % RoE | Mietausfallwagnis | 2 | MC |
| `structural_vacancy_rate` | % | struktureller Leerstand | 0–5 regional | MC |
| `non_recoverable_opex_per_m2` | EUR/m²·a | nicht umlagefähige Betriebskosten | 0,5–2,0 (unsicher) | MC |
| `vacancy_opex_per_m2` | EUR/m²·a | Betriebskosten Leerstand | 25–35 (BK-Spiegel-Größenordnung, unsicher) | – |
| `co2_regime` | enum | `stufenmodell`, `par5a_half`, `par5d_hardship`, `selbstnutzer_full` | abgeleitet | – |
| `co2_stage_table` | Tabelle | 10-Stufen-Modell [Q7] | Gesetz | – |
| `co2_landlord_share_reduction` | % | Kürzung § 9 (Denkmal/Milieuschutz) | 0 / 50 / 100 | – |
| `co2_price_path` | EUR/t | CO2-Preis je Jahr | 2026–27: 55–65; ab 2028 ETS2 | MC |
| `gas_network_fee` | ct/kWh | Gasnetzentgelt (für § 5a) | ca. 2 (unsicher) | MC |
| `bio_fuel_premium` | ct/kWh | Mehrpreis Bio-Anteil (für § 5a ab 2029) | unsicher, Energie-Memo | MC |
| `relocation_cost_per_unit` | EUR/WE | Umzug/Hotel/Umsetzwohnung | 2.000–8.000 (unsicher) | MC |
| `tenant_compensation_per_unit` | EUR/WE | Entmietungsprämie | 0–20.000 (unsicher) | MC |
| `vacancy_during_works_months` | Monate | Leerstand Sanierung | 0 (bewohnt) bis 12 | MC |
| `turnover_spike_after_works` | % | zusätzliche Kündigungen § 555e/§ 561 | 0–10 | MC |

### 9.7 Energie (Selbstnutzer, Leerstand, Warmmieten-Kennzahl)

| Schlüssel | Einheit | Bedeutung | Default | MC |
|---|---|---|---|---|
| `energy_price_<carrier>` | ct/kWh brutto | Arbeitspreis ohne CO2-Komponente (Startjahr) | Gas EFH 11,93 / MFH 11,17; Strom 37,0; WP-Tarif 21–28 [Q29] | MC |
| `energy_base_fee_<carrier>` | EUR/a | Grundpreis | Tarif | – |
| `energy_price_growth_<carrier>` | %/a real | Preisentwicklung ohne CO2 | Energie-Memo | MC |
| `vat_rate_energy` | % | USt Energie | 19 | – |
| `household_net_income` | EUR/Monat | für Belastungsquote | – | – |
| `taxable_income_household` | EUR/a | zvE für Einkommensbonus/358 | – | – |
| `n_children_u18` | Anzahl | Kinder (Bonus, KfW 300/308) | 0 | – |
| `imputed_rent_per_m2` | EUR/m²·Monat | kalkulatorische ersparte Miete | optional | MC |
| `value_uplift_energy_class` | % | Wertsteigerung je Klassenverbesserung | 0–3 % je Klasse (unsicher) | MC |

### 9.8 Förderung (Projektebene; Instrumentparameter siehe 5.8)

| Schlüssel | Einheit | Bedeutung | Default | MC |
|---|---|---|---|---|
| `funding_instruments_applied` | Liste IDs | gewählte Instrumente aus Bibliothek | – | – |
| `funding_approval_probability` | % | Haushaltsvorbehalt / Bewilligungsrisiko | 95 | MC |
| `funding_payout_lag_months` | Monate | Auszahlung nach Fertigstellung | 3–6 | MC |
| `owner_occupied_units` | Anzahl | selbstgenutzte WE (Boni) | – | – |
| `old_heating_functional_fossil` | bool | Bedingung Klimageschwindigkeitsbonus | – | – |
| `district_heating_commitment` | bool | Ausschluss dezentraler Heizung (Merkblatt) | false | – |
| `social_binding_years` | a | Miet-/Belegungsbindung | 25–30 | – |
| `social_rent_per_m2` | EUR/m²·Monat | Bewilligungsmiete | Landesprogramm | – |
| `social_rent_increase` | %/a | zulässige Steigerung in Bindung | 1,5–2,0 (NRW-Bsp. 1,7) | – |
| `post_binding_transition` | enum | Übergang nach Bindung (`ovm_no_cap_up_to_ausgleich`, `paragraph_558`) | – | – |

### 9.9 Finanzierung (Schnittstelle; Detail im Finanzierungs-Memo)

| Schlüssel | Einheit | Bedeutung | Default | MC |
|---|---|---|---|---|
| `equity_initial` | EUR | Eigenkapital t=0 | – | – |
| `loans[]` | Liste | Betrag, Zins, Zinsbindung, Laufzeit, tilgungsfreie Jahre, Tilgungsart, Zahlungsfrequenz, Disagio | – | – |
| `refinancing_rate_after_fixation` | %/a | Anschlusszins | Zinsszenario | MC |
| `credit_rate_overdraft` / `investment_rate` | %/a | Soll-/Habenzins VoFi-Ausgleich | – | MC |
| `member_shares_per_unit` / `dividend_rate` | EUR / %/a | Genossenschaftsanteile, Dividende | – | – |
| `grant_effect` | enum | Tilgungszuschuss: `reduce_annuity`, `shorten_term` | produktabhängig | – |

### 9.10 Restwert

| Schlüssel | Einheit | Bedeutung | Default | MC |
|---|---|---|---|---|
| `residual_method` | enum | `ertragswert_allg`, `ertragswert_vereinf`, `multiplier`, `exit_yield`, `sachwert_linear`, `component_book_value`, `zero` | ertragswert_allg | – |
| `cap_rate_lz` | % | Liegenschaftszinssatz | regional, 2,0–5,0 | MC |
| `rnd_method` | enum | `anlage2`, `linear`, `manual` | anlage2 | – |
| `land_value_initial` / `land_value_growth` | EUR / %/a | Bodenwert, Fortschreibung | – | MC |
| `rent_multiplier` / `exit_yield` | – / % | Kaufpreisfaktor / Exit-Rendite | regional | MC |
| `sachwertfaktor` | – | Marktanpassung Sachwert | 0,8–1,4 | MC |
| `sales_cost_rate` | % | Verkäufer-Transaktionskosten | 2–4 | – |
| `prepayment_penalty_method` | enum | `none`, `simplified`, `manual` | simplified | – |

### 9.11 Steuer-Slot (v1 inaktiv)

| Schlüssel | Einheit | Bedeutung | Default |
|---|---|---|---|
| `tax_mode` | enum | `none`, `simple_income_tax` (v1.1), `corporate` (später) | none |
| `marginal_tax_rate` | % | Grenzsteuersatz inkl. SolZ/KiSt | – |
| `depreciation_rate` | %/a | AfA-Satz | 3 (Neubau ab 2023) / 2 |
| `grant_tax_treatment` | enum | Zuschuss mindert AHK / Einnahme | – |
| `estg_35c_enabled` | bool | Steuerermäßigung § 35c (Selbstnutzer, alternativ BEG) | false |

---

## 10. Empfehlungen für Architektur und Parameterbibliotheken

1. **Parameterbibliotheken (YAML, mit `source`, `accessed`, `valid_from`, `valid_to`, `uncertainty`-Feld):**
   - `params/legal/mietrecht.yaml` (versionierte Regeln, Schalter `mietrecht_ii`),
   - `params/legal/co2kostaufg.yaml` (Stufentabelle, § 5a-Daten, Kürzungen),
   - `params/legal/building_energy_law.yaml` (Bio-Treppe, Nullemission 2030, Stichtage),
   - `params/funding/*.yaml` (ein Eintrag je Instrumentvariante, Schema 5.8),
   - `params/prices/co2_price.yaml`, `energy_prices.yaml`, `interest_rates.yaml` (KfW-Konditionen mit Datum),
   - `params/costs/bewirtschaftung.yaml` (ImmoWertV Anlage 3 und II. BV, jahresweise),
   - `params/valuation/immowertv_anlage2.yaml` (RND-Koeffizienten), `grunderwerbsteuer.yaml`, `lifetimes.yaml`.
2. **Regel-Engines als getrennte, testbare Funktionen** (je Paragraf eine Funktion, Eingabe = Zustand + Parameter, Ausgabe = zulässige Miete/Umlage), damit Gesetzesänderungen nur YAML + kleine Funktion betreffen.
3. **Monats-Engine für Mietpfad und Bauphase**, jährliche VoFi-Aggregation.
4. **Differenzbetrachtung** als First-Class-Konzept (zwei Szenarien, Differenz-VoFi).
5. **Validierung beim Laden:** Warnung, wenn `application_date` außerhalb `valid_from/valid_to` liegt oder `accessed` älter als z. B. 6 Monate ist ("Parameter veraltet").
6. **Testfälle** aus den Rechenbeispielen 1–7 und der Mietpfad-Simulation (Abschnitt 2.2) übernehmen.

---

## 11. Quellen (alle abgerufen am 25.10.2026, sofern nicht anders angegeben)

- [Q1] BBSR GModG-Infoportal, Inhalt und Verfahren (Stand 28.07.2026): https://www.gmodg.bund.de/GModG/DE/Home/startseite/GModG_News/GModG_News-node.html
- [Q2] BMWSB Pressemitteilung "Bundeskabinett beschließt Gebäudemodernisierungsgesetz" (13.05.2026): https://www.bmwsb.bund.de/SharedDocs/pressemitteilungen/DE/2026/05/pm-gmodg.html
- [Q3] BDB Mitgliederinformation GModG 2026 (Grundlage Gesetzesbeschluss 10.07.2026, BR-Drs. 409/26; erstellt 16.07.2026): https://www.baumeister-online.de/app/uploads/2026/07/BDB_Kurzbriefing_GModG_Website_final.pdf ; ergänzend Sekundärquellen zu ETS2-Prognosen: https://www.c-ober.de/blog/ets-2-verschiebung-behg-co2-kosten-2027/
- [Q4] Deutscher Bundestag, Textarchiv KW 39/2026 "CO2-Preis soll 2027 stabil gehalten werden" (Abstimmung 15.10.2026; Drs. 21/7869, 21/8252, 21/8626): https://www.bundestag.de/dokumente/textarchiv/2026/kw39-de-brennstoffemissionshandelsgesetz-1211312 ; hib 692/2026: https://www.bundestag.de/presse/hib/kurzmeldungen-1210950 ; BR-Drs. 462/26: https://dserver.bundestag.de/brd/2026/0462-26.pdf
- [Q5] ADVANT Beiten, "BEHG-Novelle: CO2-Preis bleibt 2027 im Korridor von 55 bis 65 Euro" (21.09.2026): https://www.advant-beiten.com/aktuelles/behg-novelle-co2-preis-bleibt-2027-im-korridor-von-55-bis-65-euro
- [Q6] ETS2-Preisstabilitätsmechanismus: Euronews (18.02.2026): https://www.euronews.com/2026/02/18/eu-countries-back-tool-to-regulate-carbon-price-spikes-ahead-of-tax-on-cars-and-buildings ; oEnergetice (09.10.2026): https://oenergetice.cz/en/co2-emissions/ets-2-under-control-eu-approves-mechanism-to-keep-allowance-prices-in-check ; IHK Schwaben: https://www.ihk.de/schwaben/produktmarken/energie/aktuelles-zum-thema-energie/verschiebung-des-ets-2-handels-6830228
- [Q7] CO2KostAufG, Anlage (Stufenmodell): https://www.gesetze-im-internet.de/co2kostaufg/anlage.html
- [Q8] § 5a CO2KostAufG (Wortlaut): https://lxgesetze.de/co2kostaufg/5a ; Haufe "CO2-Kosten: Vermieter zahlen deutlich mehr" (04.08.2026): https://www.haufe.de/immobilien/wirtschaft-politik/co2-preis-inwiefern-muessen-sich-vermieter-beteiligen_84342_525922.html
- [Q9] BT-Drs. 21/6807 (01.07.2026), Entwurf eines Gesetzes zur Änderung des Rechts der Wohn- und Geschäftsraummiete: https://dserver.bundestag.de/btd/21/068/2106807.pdf
- [Q10] Deutscher Bundestag, Anhörung Rechtsausschuss 14.10.2026: https://www.bundestag.de/dokumente/textarchiv/2026/kw42-pa-recht-mieten-1221718
- [Q11] Haufe "Mietrechtsreform 2026: Was CDU und CSU noch ändern wollen" (15.10.2026): https://www.haufe.de/immobilien/wirtschaft-politik/mietrechtsreform-2026_84342_684280.html
- [Q12] KPMG Law "Mietrechtsreform 2026 …" (16.02.2026, aktualisiert 05.05.2026): https://kpmg-law.de/mietrechtsreform-2026-setzt-engere-rahmenbedingungen-fuer-vermieter/
- [Q13] BGB-Normen (dejure.org, jeweils aktuelle Fassung): § 555b https://dejure.org/gesetze/BGB/555b.html ; § 557b https://dejure.org/gesetze/BGB/557b.html ; § 558 https://dejure.org/gesetze/BGB/558.html ; § 559 https://dejure.org/gesetze/BGB/559.html ; § 559a https://dejure.org/gesetze/BGB/559a.html ; § 559c https://dejure.org/gesetze/BGB/559c.html ; § 559e https://dejure.org/gesetze/BGB/559e.html
- [Q14] Mietpreisbremse bis 2029: Haufe https://www.haufe.de/immobilien/wirtschaft-politik/gesetzentwurf-mietpreisbremse-wird-nachgebessert_84342_472902.html ; LTO https://www.lto.de/recht/nachrichten/n/bundestag-verlaengert-mietpreisbremse-bis-2029 ; NWB https://www.nwb-experten-blog.de/?p=22826 ; Berlin: https://www.haufe.de/immobilien/wirtschaft-politik/berlin-fuehrt-mietpreisbremse-zum-1-juni-ein_84342_302448.html
- [Q15] KfW 261 Wohngebäude – Kredit: https://www.kfw.de/inlandsfoerderung/Privatpersonen/Bestehende-Immobilie/F%C3%B6rderprodukte/Bundesf%C3%B6rderung-f%C3%BCr-effiziente-Geb%C3%A4ude-Wohngeb%C3%A4ude-Kredit-(261-262)/
- [Q16] KfW 458 Heizungsförderung für Privatpersonen: https://www.kfw.de/inlandsfoerderung/Privatpersonen/Bestehende-Immobilie/F%C3%B6rderprodukte/Heizungsf%C3%B6rderung-f%C3%BCr-Privatpersonen-Wohngeb%C3%A4ude-(458)/
- [Q17] KfW 459 Heizungsförderung für Unternehmen – Wohngebäude: https://www.kfw.de/inlandsfoerderung/Unternehmen/Wohnwirtschaft/F%C3%B6rderprodukte/Heizungsf%C3%B6rderung-f%C3%BCr-Unternehmen-Wohngeb%C3%A4ude-%28459%29/
- [Q18] KfW 297/298 Klimafreundlicher Neubau: https://www.kfw.de/inlandsfoerderung/Privatpersonen/Neubau/F%C3%B6rderprodukte/Klimafreundlicher-Neubau-Wohngeb%C3%A4ude-(297-298)/
- [Q19] KfW 300 Wohneigentum für Familien: https://www.kfw.de/inlandsfoerderung/Privatpersonen/Neubau/F%C3%B6rderprodukte/Wohneigentum-f%C3%BCr-Familien-(300)/
- [Q20] KfW 308 Wohneigentum für Familien – Bestandserwerb: https://www.kfw.de/inlandsfoerderung/Privatpersonen/Bestehende-Immobilie/F%C3%B6rderprodukte/Wohneigentum-f%C3%BCr-Familien-Bestandserwerb-(308)/ ; Produktinfo: https://www.kfw.de/PDF/Download-Center/F%C3%B6rderprogramme-(Inlandsf%C3%B6rderung)/PDF-Dokumente/Produktinfos/6000005220_Produktinfo_308.pdf
- [Q21] KfW 358/359 Ergänzungskredit: https://www.kfw.de/inlandsfoerderung/Privatpersonen/Bestehende-Immobilie/F%C3%B6rderprodukte/Einzelma%C3%9Fnahmen-Erg%C3%A4nzungskredit-Wohngeb%C3%A4ude-(358-359)/ ; Merkblatt: https://www.kfw.de/PDF/Download-Center/F%C3%B6rderprogramme-(Inlandsf%C3%B6rderung)/PDF-Dokumente/6000005135_M_358_359.pdf
- [Q22] KfW Konditionenübersicht (Stand 22.10.2026): https://www.kfw-formularsammlung.de/KonditionenanzeigerINet/KonditionenAnzeiger
- [Q23] BAFA BEG EM Gebäudehülle: https://www.bafa.de/DE/Energie/Effiziente_Gebaeude/Sanierung_Wohngebaeude/Gebaeudehuelle/gebaeudehuelle_node.html
- [Q24] ADVANT Beiten "BEG-Reform im Juli 2026 gestartet" (03.08.2026): https://www.advant-beiten.com/en/news/beg-reform-im-juli-2026-gestartet-was-danach-fuer-die-antragsteller-gilt
- [Q25] WPB-Definition (BEG-Auslegung 17.07.2026): https://www.ingenieurkammer.de/fileadmin/dokumente/Downloads_PDF/News_Dokumente/20260717_WPB-Definition.pdf ; KfW WPB-Seite: https://www.kfw.de/inlandsfoerderung/Bundesf%C3%B6rderung-f%C3%BCr-effiziente-Geb%C3%A4ude/Worst-Performing-Building-%28WPB%29/
- [Q26] Oberer Gutachterausschuss Brandenburg, Bewirtschaftungskosten nach Anlage 3 ImmoWertV 2022–2026: https://gutachterausschuss.brandenburg.de/sixcms/media.php/9/BewKo_2026.pdf
- [Q27] II. BV-Pauschalen ab 01.01.2026: Haus & Grund München (05.12.2025): https://www.haus-und-grund-muenchen.de/documents/press_articles/20251205_pi_mieterhhung%20bei%20sozialwohnungen%20zum%201.1.2026.pdf ; Thüringer Aufbaubank: https://dokumente.aufbaubank.de/862739-TAB_Erfassungsbogen_Objektwirtschaftlichkeitsberechnung.pdf
- [Q28] ImmoWertV Anlage 2 (Restnutzungsdauer): https://gesetze.legal/bund/immowertv/anlage_2 ; Anlage 3: https://www.gesetze-im-internet.de/immowertv_2022/anlage_3.html
- [Q29] BDEW Gaspreisanalyse 08/2026: https://www.bdew.de/media/documents/BDEW_Gaspreisanalyse_082026.pdf ; BDEW Strompreisanalyse: https://www.bdew.de/service/daten-und-grafiken/bdew-strompreisanalyse/ ; Heizkosten/Heizöl (Sekundärquelle): https://www.cleanthinking.de/?p=1073584
- [Q30] NRW.BANK Mietwohnraumförderung Neuschaffung: https://www.nrwbank.de/de/foerderung/foerderprodukte/15346/mietwohnraumfoerderung---neuschaffung.html ; Kreis Warendorf FRL 2026: https://serviceportal.kreis-warendorf.de/detail/-/vr-bis-detail/dokument/85549/download
- [Q31] § 35c EStG (Änderungshistorie): https://www.buzer.de/35c_EStG.htm
- [Q32] Grunderwerbsteuersätze (Sekundärquelle): https://www.finanz-tools.de/grunderwerbsteuer/bundeslaender-tabelle
- [Q33] Lobbyregister-Eintrag zur Aktualisierung der BBSR-Nutzungsdauertabelle (Stand 2017): https://www.lobbyregister.bundestag.de/inhalte-der-interessenvertretung/regelungsvorhabensuche/RV0016183/190564
- [Q34] KfW Pressemitteilung Jung kauft Alt: https://www.kfw.de/%C3%9Cber-die-KfW/Newsroom/Aktuelles/Pressemitteilungen-Details_820928.html
- [Q35] Umweltinstitut-Gutachten Abwälzbarkeit (07/2026, Hintergrund Mieterschutz GModG): https://umweltinstitut.org/wp-content/uploads/2026/07/2026-07-Gutachten-Abwaelzbarkeit-Betriebs-und-Investitionskosten.pdf
- [Q36] Staiber, Liegenschaftszinssätze der 81 größten Städte (GuG 2022): https://www.hfwu.de/fileadmin/user_upload/FWR/Personalprofiles_FWR/staiber.markus/Veroeffentlichungen/GuG_2022_06_Beitrag_Rul_Staiber_FV.pdf

**Ausdrücklich unsichere bzw. nicht im Original geprüfte Angaben** (vor Übernahme in Bibliotheken verifizieren): BGH-Aktenzeichen (VIII ZR 81/19, VIII ZR 367/18), Bauteil-Nutzungsdauern (Tab. 1.5), EH-Definitionen Qp/H'T (Tab. 4.2), § 5b/§ 5d CO2KostAufG-Details, KfW-308-Staffel und Sanierungsstandard, BEG-EM-Sätze Anlagentechnik/Fachplanung, NRW-Tilgungsnachlässe, Grunderwerbsteuersätze einzelner Länder, Liegenschaftszinsen und Kaufpreisfaktoren, Inkrafttreten Art. 2 GModG (abgeleitet 01.01.2027), Bundesratsbeschluss zur BEHG-Änderung 2027, Amtsblatt-Veröffentlichung ETS2-Änderung, Zahlungsfrequenz und Tilgungszuschuss-Wirkung (Annuität vs. Laufzeit) bei KfW-Krediten.

---

## 12. Offene Fragen an den Auftraggeber

1. Sollen anhängige Reformen (Mietrecht II) standardmäßig aktiviert oder nur als Szenario-Schalter angeboten werden?
2. Welche Perspektive hat Priorität für v1 (z. B. kommunales WU + Selbstnutzer), und sollen Genossenschaften eine eigene Zielfunktion (kostendeckendes Nutzungsentgelt) erhalten?
3. Soll die soziale Wohnraumförderung für konkrete Länder (z. B. NRW, Bayern) als Bibliothekseintrag gepflegt werden oder nur generisch?
4. Soll für Kleinvermieter in v1.1 ein vereinfachtes Einkommensteuermodul ergänzt werden?
5. Welche Restwertmethode soll Default sein, und sind regionale Liegenschaftszinsen/Mietspiegeldaten verfügbar (Nutzer-Input oder Bibliothek)?
6. Sollen Eigentümergemeinschaften (WEG, Beschlussfassung, Kostenverteilung) und gemischt genutzte Gebäude in v1 abgedeckt werden?
