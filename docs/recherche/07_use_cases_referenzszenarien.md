# 07 – Nutzergruppen, Anwendungsfälle, Adaptivitätsanforderungen und Referenzszenarien

**Projekt:** VoFi-Tool (Vollständiger Finanzplan nach Grob, mit Monte-Carlo-Simulation) für Neubau und energetische Sanierung von Wohngebäuden in Deutschland
**Stand der Recherche:** 25.10.2026 (Werte mit Quellenangabe [Qn], Annahmen mit (A) gekennzeichnet)
**Status:** Entwurf zur Abstimmung mit dem Auftraggeber
**Konventionen:** R-Bezeichner und Eingabeschlüssel englisch in `snake_case`; alle nutzerseitigen Texte deutsch. Ertragsteuern sind in v1 ausgeklammert (Vor-Steuer-VoFi). Beträge brutto (inkl. USt.), da Wohnraumvermietung und Selbstnutzung keinen Vorsteuerabzug erlauben.
**Bezug zu den anderen Memos:** 01 (VoFi-Methodik: Zeit- und Zinskonventionen, nachschüssige Rekursion), 02 (Recht und Förderung: verbindliche Parameter), 04 (Monte Carlo: Default-Verteilungen und Prozesse), 05 (R-Architektur: Eingabeschema), 06 (Steuern). Bei Abweichungen gelten die Fachmemos; dieses Memo übernimmt deren Werte für die Referenzszenarien (abgeglichen am 25.10.2026: Bio-Treppe nach Memo 02, MC-Defaults nach Memo 04, YAML-Grammatik nach Memo 05).

---

## 0. Kurzfassung

**Kernaussagen**

1. **Fünf Personas, zwei Nutzungsmodi.** Die fünf Zielgruppen (kommunales Wohnungsunternehmen, Genossenschaft, privater Kleinvermieter, Selbstnutzer im Bestand, Selbstnutzer im Neubau) brauchen dieselbe Rechenlogik, aber unterschiedliche Voreinstellungen, Kennzahlen und Berichte. Empfehlung: eine Rechenmaschine, zwei Berichtsmodi – „Fachmodus“ (Wohnungswirtschaft: VoFi-Tabelle, EK-Rendite, DSCR, €/m² Wfl.) und „Haushaltsmodus“ (Selbstnutzer/Kleinvermieter: monatliche Belastung, Ersparnis pro Monat, Amortisationsjahr, Ampel).
2. **Vollkostenvergleich von Varianten als Grundprinzip.** Jede Variante (Nichtstun, Ohnehin-Sanierung, energetische Stufe A/B, Ersatzneubau) wird mit allen Zahlungen vollständig gerechnet; Differenzen werden danach gebildet. Der **Ohnehin-Anteil** wird zusätzlich je Maßnahme erfasst, weil ihn § 559 BGB (Erhaltungsabzug) und die Kennzahl „energiebedingte Mehrkosten“ benötigen.
3. **Der Rechtsrahmen hat sich 2026 stark verändert** und ändert sich weiter halbjährlich: BEG-Reform zum 21.07.2026 (u. a. kein Tilgungszuschuss mehr für EH 70 EE ohne Bonus, Einkommensstaffel bei KfW 458, Degression ab 01.02.2027), Gebäudemodernisierungsgesetz (GModG, verkündet 28.07.2026: 65-%-Regel entfällt, Bio-Treppe ab 2029, hälftige Teilung von CO₂-Kosten und Gasnetzentgelten bei neu eingebauten fossilen Heizungen ab 2028, neuer § 559f BGB zur Jahresarbeitszahl). **Folge für das Tool:** Förderregeln und Rechtsparameter müssen als versionierte, stichtagsbezogene Regelobjekte gepflegt werden – nicht als Konstanten im Code.
4. **Fünf vollständig spezifizierte Referenzszenarien (S1–S5)** mit Zahlenstand 2026 werden in Abschnitt 4 definiert, inklusive deterministischer Prüfwerte für Integrationstests (Förderbeträge, Umlage, Annuitäten, Kappungen) und Vorschlägen für stochastische Parameter.
5. **Restwert dominiert lange Horizonte.** In S1 und S2 entscheidet die Restwertannahme (Restnutzungsdauer, Liegenschaftszins) häufig über das Vorzeichen des Variantenvergleichs. Ergebnisse sind deshalb immer **mit und ohne Restwert** auszuweisen.
6. **Portfolio-Aggregation erst in v2**, das Datenmodell (Projekt → Gebäude → Variante → Maßnahme/Darlehen) soll sie aber von Anfang an zulassen.

**Wichtigste Entscheidungsvorschläge für v1** (Details in Abschnitt 3): jährliche VoFi-Periodik mit exakter Darlehensrechnung; beliebiger Start und Horizont; Maßnahmen und Darlehen in beliebigen Perioden; Anschlussfinanzierung automatisch; benutzerdefinierte Zahlungsreihen mit Index/Wachstum; Mengenbezug gesamt / je WE / je m² / je Bauteilfläche; Mietrechtsmodul (§§ 558, 559, 559a, 559e, 559f BGB) und CO₂KostAufG (inkl. neuem § 5a); Restwertverfahren wählbar; Nutzerperspektive (Warmmiete) als abgeleitete Sicht; MC über beliebige numerische Parameter mit Verteilungsbibliothek und Korrelationen.

---

## 1. Rahmendaten Stand Oktober 2026 (nur soweit für die Szenarien nötig)

> **Volatilitätswarnung:** Mehrere Werte stammen aus Sekundärquellen (Ratgeberportale), weil Primärtexte (BEG-Richtlinien in der Fassung vom 21.07./02.09.2026, GModG-Volltext) nicht maschinenlesbar abrufbar waren. Diese Werte sind mit „Sek.“ markiert und vor der Übernahme in die Parameterbibliothek am Primärtext zu prüfen. Die Fachmemos zu Förderung, Energie und Mietrecht sollen die verbindlichen Werte liefern; dieses Memo verwendet sie nur zur Parametrierung der Referenzszenarien.

### 1.1 Förderung

| Programm | Kerndaten (Stand) | Quelle |
|---|---|---|
| **KfW 261** BEG Wohngebäude-Kredit (Sanierung zum Effizienzhaus) | Kredit bis 150.000 €/WE; Tilgungszuschuss (TZ) **seit 21.07.2026**: EH 40 EE 10 % / NH 15 %, EH 55 EE 5 % / NH 10 %, **EH 70 EE 0 % / NH 5 %**, EH 85 EE 0 % / NH 5 %, Denkmal EE 5 % / NH 10 %; **WPB-Bonus +10 Pp** (EH 40/55/70); Serielle Sanierung +15 Pp (EH 40/55) bzw. +5 Pp (EH 70); Baubegleitung MFH 4.000 €/WE, max. 40.000 €/Vorhaben, 50 % TZ; Laufzeiten 4–30 J., 1–5 tilgungsfreie Jahre, Zinsbindung 10 J.; Bereitstellungsprovision 0,15 %/Monat ab Monat 13; TZ-Gutschrift nach Abschluss | [Q2], [Q3] (Sek.) |
| KfW 261 Zins | Höchstsollzins 30/5/10: **3,65 %** (eff. 3,71 %), 20/3/10: 3,53 %, gültig ab 29.09.2026 | [Q1] |
| TZ-Verrechnung | Grundsatz Laufzeitverkürzung; ratenreduzierende Anrechnung auf Antrag möglich | [Q32] (Sek., Stand 2024) |
| **KfW 297/298** Klimafreundlicher Neubau (297 Selbstnutzung, 298 Vermietung) | EH 55 und EH 40 ohne QNG: bis **100.000 €/WE**; EH 40 mit QNG-PLUS/PREMIUM: bis **150.000 €/WE**; EH 40 erfordert LCA (THG-Grenzwert QNG-PLUS) und keine Öl-/Gas-/Biomasseheizung; **EH-55-Stufe** (keine fossile Heizung, Baugenehmigung nötig) befristet **bis 31.12.2026**, Budget 800 Mio. € (2025+2026), Mittelvorbehalt | [Q4], [Q6], [Q33] |
| KfW 297/298 Zins | Standard (EH 40) 35/5/10: **2,94 %** Soll (eff. 2,98 %), 25/3/10: 2,81 %; EH-55-Stufe 35/5/10: **2,19 %** Soll (eff. 2,21 %), 10/2/10: 1,00 % (Signalzins) | [Q1], [Q5] |
| **KfW 300** Wohneigentum für Familien | Mind. 1 Kind < 18; zvE ≤ 90.000 € (1 Kind) + 10.000 €/weiteres Kind (Ø 2./3. Vorjahr); Standard **EH 40** (Stufe 1: LCA mit QNG-PLUS-THG-Grenze; Stufe 2: mit QNG-Zertifikat); Kredithöchstbetrag 1–2 Kinder 170.000/220.000 €, 3–4 Kinder 200.000/250.000 €, ab 5 Kinder 220.000/270.000 € (ohne/mit QNG) | [Q7] |
| KfW 300 Zins | 35/5/10: **1,00 %** Soll; 25/3/10: 0,72 %; 10/10/10: 1,15 % | [Q1] |
| **KfW 458** Heizungsförderung Privatpersonen (Zuschuss) | **Seit 21.07.2026:** Grundförderung 30 % (alle Eigentümer, auch Vermieter/WEG); Klimageschwindigkeitsbonus (nur Selbstnutzer, Ersatz funktionsfähiger Öl-/Kohle-/Nachtspeicher-/Gasetagen- oder ≥ 20 J. alter Gas-/Biomasseheizung) **16 % bis 31.01.2027**, dann −4 Pp je Halbjahr bis 0 % ab 01.08.2028; Einkommensbonus (nur Selbstnutzer): zvE ≤ 30.000 € 40 %, ≤ 40.000 € 30 %, ≤ 50.000 € 10 %; Familienzuschlag: zvE −10.000 € bei mind. einem minderjährigen Kind; Deckel 70 % (80 % bei zvE ≤ 30.000 €); förderfähige Kosten 1. WE **28.000 €** (−750 € je Halbjahr ab 01.02.2027, 22.000 € ab 01.08.2030), WE 2–6 je 15.000 €, ab WE 7 je 8.000 €; Effizienzbonus und Emissionsminderungszuschlag entfallen; geplant Q1/2027: WP-Grundförderung 15 % + 15 % Wertschöpfungsbonus für EU-Geräte | [Q8] (Sek.), [Q11] |
| **KfW 459** Heizungsförderung Unternehmen – Wohngebäude | max. 30 % der förderfähigen Kosten; Höchstbeträge nach Zahl der WE (1. WE sinkt ab 01.02.2027 halbjährlich um 750 €) | [Q9] |
| **KfW 358/359** Ergänzungskredit | 358 („Plus“, Selbstnutzer zvE ≤ 90.000 €) 25/3/10: **2,53 %**, 10/2/10: 1,48 %; 359 (ohne Einkommensgrenze) 25/3/10: 4,62 %; bis 120.000 €/WE; setzt BEG-EM-Zusage voraus; laut Fachpresse von der Juli-Reform nicht betroffen | [Q1], [Q8], [Q11] |
| **BAFA BEG EM Gebäudehülle** | Grundförderung 15 % (Dämmung, Fenster, Türen, sommerlicher Wärmeschutz); förderfähige Kosten je WE und Kalenderjahr 30.000 € (60.000 € mit iSFP); **iSFP-Bonus +5 Pp seit 21.07.2026 erst ab 30.000 € förderfähiger Investition** (1 WE; bei mehreren WE Schwelle = Höchstgrenze ohne Bonus) und nach Memo 02 nur auf den Betrag oberhalb der Schwelle (Default; einzelne Sekundärquellen lesen es als Bonus auf den Gesamtbetrag); Staffel bei MFH 1./2.–6./ab 7. WE: 30/15/8 T€ (60/30/15 T€ mit iSFP); Fachplanung/Baubegleitung 50 % (EFH max. 5.000 €; MFH 2.000 €/WE, max. 20.000 €); geplant Q1/2027: WPB-Bonus +5 Pp für Dämmung aus iSFP | [Q10] (Sek.) |
| Laufzeit BEG-Richtlinie | bis Ende 2030 – Förderung späterer Sanierungsstufen ist **unsicher** | [Q8] (Sek.) |

### 1.2 Rechtsrahmen (Gebäude, Mietrecht, CO₂)

| Thema | Stand | Quelle |
|---|---|---|
| **GModG** (ersetzt GEG) | Bundestag 10.07.2026, Bundesrat ohne Einspruch; Gesetz vom 23.07.2026, **BGBl. 2026 I Nr. 226 vom 28.07.2026**; Heizungsregeln in Kraft seit 29.07.2026; weitere Teile am ersten Tag des sechsten Folgemonats, Stufen 01.01.2028 und 01.01.2030; 65-%-EE-Pflicht entfällt; fossile Heizungen wieder zulässig, aber **Bio-Treppe** für neue Gas-/Öl-/Flüssiggasheizungen nach § 43 Abs. 1 GModG: 10 % ab 01.01.2029, 15 % ab 2030, 30 % ab 2035, 60 % ab 2040 (Stufen lt. Memo 02); Ziel klimaneutrale Brennstoffe 2045 | [Q12] (teils Sek.) |
| GModG Neubau | Faktor 0,55 auf Referenzgebäude entfällt, Referenzgebäude neu definiert (Bundesregierung: Niveau unverändert; Kammern: faktische Absenkung), voraussichtlich anzuwenden ab 01.01.2027 (Ableitung Memo 02); **Nullemissionsgebäude ab 01.01.2030** für alle Neubauten, LCA-Bericht Pflicht | [Q13], Memo 02 |
| **CO₂KostAufG** | 10-Stufen-Modell nach kg CO₂/(m² Wfl.·a): < 12 → Vermieter 0 %; 12–< 17 → 10 %; 17–< 22 → 20 %; 22–< 27 → 30 %; 27–< 32 → 40 %; 32–< 37 → 50 %; 37–< 42 → 60 %; 42–< 47 → 70 %; 47–< 52 → 80 %; ≥ 52 → 95 % | Gesetzestext (bekannt), [Q12] |
| **Neu: § 5a CO₂KostAufG** (GModG) | Für nach § 43 GModG neu eingebaute Gas-/Öl-/Flüssiggasheizungen: **ab 01.01.2028** 50/50-Teilung der CO₂-Kosten (statt Stufenmodell) und der **Gasnetzentgelte**; **ab 01.01.2029** 50/50 der Mehrkosten beigemischter biogener Brennstoffe, Vermieteranteil begrenzt auf 30 % der Brennstoffmenge; Ausnahmen (Havarie < 12 Monate vor 2028), Härtefallregel § 5d; Neubau-Erstreckung § 5b | [Q12] (Sek.) |
| **§ 559 BGB** | 8 % p. a. der Modernisierungskosten; Erhaltungsanteil abzuziehen; Kappung 3 €/m² in 6 Jahren (2 €/m² bei Miete < 7 €/m²) | [Q14] |
| **§ 559a BGB** | Zuschüsse mindern umlagefähige Kosten; bei zinsverbilligten Darlehen Kürzung um den Jahresbetrag der Zinsermäßigung | Gesetzestext |
| **§ 559e BGB** (Fassung GModG, seit 29.07.2026) | Heizungsmodernisierung mit Förderung: 10 % p. a. der Kosten abzüglich Drittmittel; **pauschal 15 % Erhaltungsabzug** (nicht für Heizungen i. S. d. § 43 GModG – Auslegung prüfen); Kappung **0,50 €/m²/Monat in 6 Jahren** | [Q12], [Q14] |
| **Neu: § 559f BGB** | Bei Wärmepumpen volle Umlage nur mit Nachweis **JAZ ≥ 2,5** (VDI 4650 Bl. 1, vor Inbetriebnahme); sonst nur 50 % der Kosten ansetzbar; Ausnahmen u. a. Baujahr nach 1996, Vorlauftemperatur ≤ 55 °C | [Q12] |
| § 559c BGB (vereinfachtes Verfahren) | weiterhin 10.000 € Grenze, 30 % Pauschalabzug; Verdopplung auf 20.000 € politisch vereinbart, noch nicht umgesetzt | [Q14] |
| Mietpreisbremse | bis 31.12.2029 verlängert | [Q15] |
| **CO₂-Preis BEHG** | 2026 Versteigerung im Korridor 55–65 €/t; Gesetzentwurf: Korridor 55–65 €/t auch 2027 (BT-Drs. 21/7869, noch nicht verabschiedet); EU-ETS 2 verschoben auf 2028 | [Q16] |

### 1.3 Zinsen, Preise, Kosten

| Größe | Wert | Quelle |
|---|---|---|
| Bauzinsen 10 J. (Privat) | ab 4,16 % eff. (13.10.2026), 15–30 J.: 4,3–4,7 %; Anstieg seit Sommer | [Q19] |
| KfW 124 (Marktnähe) | 35/5/10: 4,56 % Soll | [Q1] |
| EZB-Einlagensatz | 2,50 % (Anhebung 10.09.2026) | [Q20] (Sek.) |
| Festgeld 5 J. | Spitze 3,67 %; Tagesgeld Ø 1,85 % (06/2026) | [Q21] |
| Inflation DE | 09/2026: +3,3 % (Energie +14,9 %, „Iran-Krieg“) | [Q22] |
| Baupreise Wohngebäude | 08/2026: +5,5 % gg. Vj.; Instandhaltung Wohngebäude +6,0 % | [Q23] |
| Herstellungskosten Geschosswohnungsbau (Großstädte, Q4/2025, brutto) | Median **4.631 €/m² Wfl.** (Spanne 3.200–8.600); Bauwerkskosten (KG 300+400) Median im Intervall **3.500–3.750 €/m² Wfl.**; inkl. Grundstück Median ca. **5.390 €/m²**; freifinanziert < 20 €/m² Kaltmiete „nicht darstellbar“ | [Q24] |
| Bewirtschaftungskosten ImmoWertV Anl. 3, ab 01.01.2026 | Verwaltung **367 €/WE·a** (ETW 439 €), Instandhaltung **14,40 €/m² Wfl.·a**, Mietausfallwagnis 2 % | [Q25] |
| Gaspreis Haushalte | Neuverträge 01.10.2026: **13,8 ct/kWh** (EFH, 20.000 kWh); Ø 2026 bis August: EFH 11,93 ct, MFH 11,17 ct; Gasnetzentgelte 2026: 2,57 ct (EFH) / 2,19 ct (MFH) netto; Gasspeicherumlage entfällt ab 2026 | [Q17] |
| Strompreis Haushalte | Ø 2026: 37,0 ct/kWh; Neuverträge 01.10.2026: 38,9 ct/kWh | [Q17] |
| Wärmepumpentarif | Ø 24 ct/kWh + 140 €/a Grundpreis (Spanne 20–29 ct) | [Q18] |
| EEG-Einspeisevergütung (IBN 01.08.2026–31.01.2027, Teileinspeisung) | ≤ 10 kWp: 7,70 ct; 10–40 kWp: 6,66 ct; Reform für < 25 kWp ab 2027 in Diskussion | [Q26] |
| PV-Kosten | Ø ca. 1.015 €/kWp (Fraunhofer ISE, 03/2026); kleine Anlagen 1.000–1.300 €/kWp | [Q27] (Sek.) |
| Luft/Wasser-WP | EFH 22.000–35.000 € (Spanne 15.000–47.000 €); MFH-Kaskaden 1.100–1.600 €/kW | [Q28] (Sek.) |
| Mieten | Angebotsmiete Bestand bundesweit Q2/2026: 8,97 €/m²; kalkulatorische Neubaumiete Großstädte 18–20 €/m²; Genossenschaften Sachsen Ø 5,75 €/m²; Gewobag Ø 7,01 €/m² | [Q29], [Q30] |

---

## 2. Personas, Fragestellungen und abgeleitete Anforderungen

### 2.1 Persona (a): Controllerin in einem kommunalen Wohnungsunternehmen

| Aspekt | Beschreibung |
|---|---|
| Steckbrief | Kaufmännische Projektcontrollerin, kommunale Wohnungsgesellschaft (5.000–20.000 WE), entscheidet mit Technik und Geschäftsführung über Modernisierung oder Neubau von MFH mit 24–60 WE; Vorlage an Aufsichtsrat. Gesellschafterin Kommune erwartet Klimapfad (Klimaneutralität), Sozialverträglichkeit und Werterhalt bei moderater Rendite. |
| Typische Fragen | Lohnt sich EH 70 oder EH 55 gegenüber der Ohnehin-Instandsetzung? Welche Modernisierungsumlage ist rechtlich möglich und welche sozialpolitisch gewollt (warmmietenneutral)? Was bringen KfW-Zinsvorteil und Tilgungszuschuss nach der Reform 21.07.2026? Wie wirkt die CO₂-Kostenteilung (Stufenmodell bzw. § 5a) auf das Ergebnis? Sanierung oder Ersatzneubau? Ist Neubau mit 13 €/m² überhaupt darstellbar – welche Miete bräuchte ich (Kostenmiete/Break-even)? Wie robust ist das Ergebnis gegenüber Zinsen in 10 Jahren und Baukostenüberschreitungen? |
| Kennt/liefert (Inputs) | Objektstammdaten aus ERP (WE, Wfl., Baujahr, Mieterliste mit Einzelmieten, Leerstand), Mietspiegel und Vergleichsmiete, Kostenschätzung nach DIN 276 vom Architekten (inkl. Ohnehin-Anteil auf Nachfrage), Energieausweis und Verbrauchsabrechnungen, Instandhaltungsplanung, Finanzierungsangebote der Hausbanken, Förderzusagen, Unternehmensparameter (Kalkulationszins/Zielrendite 3–5 %, Mietsteigerungsannahmen, Inflation, Leerstand), Bodenrichtwert, Liegenschaftszins (Gutachterausschuss). |
| Braucht (Outputs) | VoFi-Tabelle je Variante; VoFi-Endwert und VoFi-EK-Rendite; Differenz-Endwert gegenüber Referenz (mit/ohne Restwert); jährlicher Cashflow und Liquiditätsbedarf; Kapitaldienstdeckungsgrad (DSCR), Beleihungsauslauf; Miet- und Warmmietenpfad in €/m² Wfl./Monat; Umlageberechnung mit Kappung; Förderbarwert; CO₂-Minderung (t/a) und CO₂-Vermeidungskosten (€/t); Tornado-Diagramm und MC-Verteilung (P(Variante besser), 5-%-Quantil); Break-even-Miete/Zielwertsuche; exportierbare Tabellen (Excel) und Entscheidungsvorlage (PDF/Word). |
| Entscheidungskriterium | Primär: Differenz-VoFi-Endwert ≥ 0 bzw. VoFi-EK-Rendite ≥ Zielrendite (z. B. 3,5 %); Nebenbedingungen: Warmmietenneutralität oder max. Warmmietenanstieg (z. B. ≤ 0,50 €/m²), Liquidität (kein Kontokorrent über Limit), DSCR ≥ 1,2, CO₂-Zielpfad. |
| Typischer Horizont | Sanierung 25–30 Jahre (Restnutzungsdauer), Neubau 40–50 Jahre; Unternehmensplanung 10 Jahre (Mittelfristplanung) als Ausschnitt. |
| Typische Finanzierung | 10–25 % EK (Innenfinanzierung), KfW 261 bzw. 298 bis Höchstbetrag, Kapitalmarktdarlehen 10–20 J. Zinsbindung mit 1,5–3 % Anfangstilgung, ggf. Landesförderung (soziale Wohnraumförderung mit Tilgungsnachlass und Belegungsbindung), Anschlussfinanzierung nach Zinsbindung. |
| Fallstricke | Ohnehin-Abgrenzung (GModG-Bauteilanforderungen bei Erneuerung lösen Dämmpflicht aus); Doppelzählung von pauschaler Instandhaltung und expliziten Ersatzinvestitionen; Kappung je Wohnung (nicht nur Durchschnitt); Restwertdominanz; Mietminderung während der Bauphase; leerstandsbedingte Betriebskosten. |
| Abgeleitete Anforderungen | A-03, A-04, A-05, A-06, A-07, A-09, A-11, A-12, A-13, A-14, A-15, A-16, A-17, A-19, A-20 (siehe Abschnitt 3). |

### 2.2 Persona (b): Vorstand/Technik einer Wohnungsgenossenschaft

| Aspekt | Beschreibung |
|---|---|
| Steckbrief | Kaufmännischer Vorstand und technischer Leiter einer Genossenschaft (500–3.000 WE); Mitgliederorientierung, Förderzweck statt Gewinnmaximierung; häufig steuerbefreite Vermietungsgenossenschaft (§ 5 Abs. 1 Nr. 10 KStG) – Vor-Steuer-VoFi daher sachgerecht. |
| Typische Fragen | Können wir den Heizungstausch Gas → Wärmepumpe (+ PV) kostendeckend finanzieren, ohne das Nutzungsentgelt über ein mitgliederverträgliches Maß zu erhöhen? Wie viel der rechtlich möglichen Umlage (§ 559e, max. 0,50 €/m²) setzen wir an? Wie entwickeln sich die Gesamtwohnkosten (Warmmiete) der Mitglieder in beiden Varianten? Wie stark belastet uns die neue 50/50-Teilung von CO₂ und Gasnetzentgelten, wenn wir noch einmal Gas einbauen? |
| Kennt/liefert (Inputs) | Nutzungsentgelte (Ø und je WE), Heizkostenabrechnungen, Angebote Heizungsbauer/PV, Instandhaltungsrücklage, Finanzierungskonditionen (häufig sehr gute Bonität), Beschlusslage (Vorstand/Aufsichtsrat/Vertreterversammlung), ggf. Spareinrichtung bzw. Mitgliederdarlehen. |
| Braucht (Outputs) | Nutzungsentgelt- und Warmmietenpfad (€/m²·Monat) je Variante; Kostendeckung/Liquidität der Genossenschaft; Differenz-Endwert bei niedrigem Kalkulationszins (1,5–3 %); Barwert der Mehrkosten; Förderung; CO₂; Sensitivität der Mitgliederbelastung gegenüber Strompreis und JAZ. |
| Entscheidungskriterium | „Kostendeckend bei mitgliederverträglichem Nutzungsentgelt“: Differenz-Endwert ≥ 0 bei Mindestverzinsung 2 %, Warmmiete der Mitglieder nicht höher als in der Referenz (oder Anstieg ≤ Schwelle), Liquidität gesichert. |
| Typischer Horizont | 20–30 Jahre; bei Komponentenmaßnahmen (Heizung) Lebensdauer der Anlage (≈ 20 J.). |
| Typische Finanzierung | Hoher EK-Anteil, Bankdarlehen (Volltilger), KfW-Zuschüsse (459), ggf. Spareinrichtung; selten Kapitalmarkt-Großkredite. |
| Fallstricke | Umlage bei Genossenschaften satzungs- und beschlussabhängig (oft freiwillig unter Rechtsrahmen); PV-Stromverrechnung an Mitglieder (Heizkostenverordnung, gemeinschaftliche Gebäudeversorgung) rechtlich prüfen; Zwei-Perspektiven-Logik (Genossenschaft und Mitglieder) zwingend. |
| Abgeleitete Anforderungen | A-04, A-09, A-10, A-12, A-13, A-14, A-17, A-18, A-20, A-21. |

### 2.3 Persona (c): Privater Kleinvermieter mit 6-WE-Mehrfamilienhaus

| Aspekt | Beschreibung |
|---|---|
| Steckbrief | 55–65 Jahre, Eigentümer eines MFH (Baujahr 1950er–1970er, 6 WE, ca. 400 m² Wfl.), verwaltet selbst oder mit Hausverwaltung, begrenzte Finanzkenntnisse, Liquidität und Altersvorsorge stehen im Vordergrund. |
| Typische Fragen | Muss ich die alte Gasheizung jetzt ersetzen, und womit? Wie viel darf ich auf die Miete umlegen (§ 559 vs. § 559e, § 559f JAZ-Nachweis)? Muss ich „zuschießen“? Was kostet mich die CO₂-Kostenbeteiligung, wenn ich wieder Gas einbaue (ab 2028 50 % CO₂ + 50 % Netzentgelte)? Lohnt sich die Fassade zusätzlich? Was bleibt nach Steuern (→ v2)? |
| Kennt/liefert (Inputs) | Mieten je Wohnung, Gasabrechnung, Angebote von Handwerkern, Hausbank-Konditionen, eigenes Erspartes; selten DIN-276-Kostengliederung oder Ohnehin-Anteil – braucht **Vorschlagswerte** (Bibliothek) und einfache Eingabe. |
| Braucht (Outputs) | Monatlicher Cashflow („Was bleibt pro Monat?“), rechtlich zulässige Mieterhöhung je Wohnung mit Kappung, Förderübersicht, Zuschussbedarf pro Monat/Jahr, Amortisationsjahr, Vermögensvergleich nach N Jahren, einfache Risikoaussage. |
| Entscheidungskriterium | Kein dauerhaft negativer Cashflow, Amortisation innerhalb des persönlichen Horizonts, Vermögenszuwachs; häufig Einfachheit und Mieterfrieden. |
| Typischer Horizont | 10–20 Jahre (Alter, Vererbung, Verkauf). |
| Typische Finanzierung | Erspartes + Hausbank-Annuitätendarlehen, KfW 261 oder Ergänzungskredit 359 (358 nur Selbstnutzer), Zuschüsse KfW 458 (Grundförderung 30 %) bzw. BAFA. |
| Fallstricke | **Ertragsteuern** (Erhaltungsaufwand sofort abziehbar vs. AfA, anschaffungsnaher Aufwand) beeinflussen die Vorteilhaftigkeit stark – in v1 ausgeklammert, daher deutlicher Warnhinweis im Bericht; Einzelmieten < 7 €/m² (2-€-Kappung). |
| Abgeleitete Anforderungen | A-11, A-12, A-13, A-22 (Steuermodul v2), Haushaltsmodus-Bericht. |

### 2.4 Persona (d): Selbstnutzer eines Einfamilienhauses Baujahr 1975 (stufenweise Sanierung nach iSFP)

| Aspekt | Beschreibung |
|---|---|
| Steckbrief | Paar 45–55 J. mit Kind, EFH 1975 (140 m²), Gasheizung ≥ 20 Jahre alt, individueller Sanierungsfahrplan (iSFP) vom Energieberater liegt vor; Budget begrenzt, Sanierung in Stufen. |
| Typische Fragen | Was spare ich pro Monat, wenn ich jetzt eine Wärmepumpe einbaue? Lohnt sich die Wärmepumpe vor der Dämmung? Wann hat sich das bezahlt gemacht? Was passiert, wenn ich die Gasheizung behalte und sie in ein paar Jahren kaputtgeht? Wie viel Zuschuss bekomme ich (Einkommensbonus, Klimageschwindigkeitsbonus, iSFP-Bonus) – und was, wenn es 2033 keine Förderung mehr gibt? Stufenweise oder alles auf einmal? |
| Kennt/liefert (Inputs) | Gasverbrauch (kWh/a) aus Abrechnungen, Wohnfläche, Baujahr, iSFP mit Maßnahmen, Kosten und Einsparprognose, zvE und Kinderzahl, Erspartes, gewünschte Monatsbelastung; keine Kenntnis von Kalkulationszins oder Annuitätenformel. |
| Braucht (Outputs) | **Monatliche Belastung** (Kredit + Energie + Wartung) je Variante und Jahr, **Ersparnis/Mehrkosten pro Monat**, **Amortisationsjahr**, Gesamtkosten über 25 Jahre, Förderbeträge je Stufe, Zeitstrahl der Stufen, Bandbreite („in 7 von 10 Zukünften günstiger“), Klartext-Fazit. |
| Entscheidungskriterium | Niedrigere Gesamtkosten über den eigenen Horizont bei tragbarer Monatsbelastung; Sicherheit gegen Energiepreisanstiege; Komfort und Werterhalt (qualitativ). |
| Typischer Horizont | 15–25 Jahre (Alter, geplanter Verbleib). |
| Typische Finanzierung | Erspartes, KfW 458 (Zuschuss), BAFA (Zuschuss), KfW 358/359 Ergänzungskredit, ggf. Modernisierungskredit der Hausbank; Alternative § 35c EStG (Steuer – in v1 ausgeklammert). |
| Fallstricke | Prebound-Effekt (realer Verbrauch < Bedarf) → Einsparungen nicht aus Bedarfsausweis ableiten; JAZ ändert sich mit den Stufen; Förderdeckel je Kalenderjahr; Ohnehin-Maßnahmen haben eigene (spätere) Zeitpunkte und müssen bedingte GModG-Anforderungen erfüllen; Tilgung ist Vermögensaufbau, keine Kosten. |
| Abgeleitete Anforderungen | A-03, A-04, A-05, A-10, A-13, A-14, A-15, A-16, A-21, Haushaltsmodus-Bericht. |

### 2.5 Persona (e): Familie, die ein neues Einfamilienhaus baut (KfW 300/297)

| Aspekt | Beschreibung |
|---|---|
| Steckbrief | Familie mit 2 Kindern, zvE ≈ 85.000 €, Grundstück im Umland einer Mittelstadt, Angebot eines Bauträgers/Fertighausanbieters für „GModG-Standard“ und „EH 40“. |
| Typische Fragen | Rechnet sich EH 40 gegenüber dem gesetzlichen Standard, wenn ich KfW 300 mit 1 % Zins bekomme? Wie hoch ist meine Monatsrate in den ersten 10 Jahren und danach? Was passiert, wenn die Zinsen 2037 bei 6 % liegen? Wie viel Restschuld habe ich nach 10 Jahren? Bekomme ich KfW 300 überhaupt (Einkommensgrenze)? Was, wenn die EH-55-Stufe der KfW 297 Ende 2026 ausläuft? |
| Kennt/liefert (Inputs) | Grundstückspreis und Nebenkosten, Hausangebot(e) mit Mehrpreis EH 40, Einkommen und Kinder, EK, Bankkonditionen, aktuelle Miete bis Einzug. |
| Braucht (Outputs) | Monatsrate je Phase (tilgungsfreie Jahre, Zinsbindung, Anschluss), **Belastungsquote** (Rate + Nebenkosten in % des Nettoeinkommens), Restschuld bei Zinsbindungsende, Zinsänderungsrisiko (Fächerdiagramm), Mehrkosten vs. Fördervorteil, Energiekosten, Vermögen nach 30 Jahren. |
| Entscheidungskriterium | Tragbarkeit (Belastungsquote ≤ 35–40 %), geringste Gesamtkosten, Robustheit gegen Zinsanstieg. |
| Typischer Horizont | 30–35 Jahre (Darlehenslaufzeit). |
| Typische Finanzierung | 20–30 % EK, KfW 300 bzw. 297, ggf. KfW 124, Bankdarlehen (10–15 J. Zinsbindung), Anschlussfinanzierung. |
| Fallstricke | Förderfähigkeit (Einkommen, Kinder, EH 40 + LCA), Antragsfristen und Mittelvorbehalt; Bereitstellungszinsen und Doppelbelastung (Miete + Rate) in der Bauphase; Einspeisevergütung nach EEG-Reform 2027 unsicher. |
| Abgeleitete Anforderungen | A-02, A-06, A-07, A-08, A-13, A-14, A-16, A-19, A-21, Haushaltsmodus-Bericht. |

### 2.6 Querschnittsmatrix Persona × Funktion

| Funktion | (a) WU | (b) Geno | (c) Kleinvermieter | (d) Selbstnutzer Bestand | (e) Selbstnutzer Neubau |
|---|:-:|:-:|:-:|:-:|:-:|
| Modernisierungsumlage §§ 559/559a/559e/559f | ●● | ●● | ●● | – | – |
| CO₂KostAufG / § 5a (Vermieteranteil) | ●● | ●● | ●● | – | – |
| Nutzerperspektive (Warmmiete) | ●● | ●● | ● | – | – |
| Gestufte Maßnahmen über Jahre | ● | ● | ● | ●● | – |
| Bauphase mit Zahlungsplan | ●● (Neubau) | ○ | ○ | – | ●● |
| Mehrere Darlehen, Anschlussfinanzierung | ●● | ● | ● | ● | ●● |
| Förderregeln mit Einkommens-/Kinderlogik | – | – | – | ●● | ●● |
| Restwert Ertragswert | ●● | ● | ● | – | – |
| Restwert Zeitwert/Sachwert | ● | ●● | ● | ●● | ●● |
| Monatliche Belastung, Amortisation (Haushaltsmodus) | ○ | ● | ●● | ●● | ●● |
| VoFi-Tabelle, EK-Rendite (Fachmodus) | ●● | ●● | ● | ○ | ○ |
| Break-even / Zielwertsuche | ●● | ● | ● | ○ | ● |
| Monte Carlo | ●● | ● | ● | ● | ●● |
| Steuern | (○, meist steuerbefreit/irrelevant) | (○) | ●● (v2) | ○ (§ 35c, v2) | – |
| Portfolio | ●● (v2) | ● (v2) | – | – | – |

●● zentral, ● wichtig, ○ optional, – nicht relevant

---

## 3. Adaptivitätsanforderungen

Priorität: **M** = Muss v1, **S** = Soll v1, **v2** = späteres Release. Die Spalte „Begründung“ verweist auf Personas (a–e) und Szenarien (S1–S5).

| ID | Anforderung | Inhalt / Ausgestaltung | Begründung | Prio |
|---|---|---|---|---|
| A-01 | **Beliebiger Horizont und Startjahr** | `start_year`, `horizon_years` frei; Zeitachse in Kalenderjahren; separates `price_base_year` für Kostenangaben; t = 0 ≙ Investitionszeitpunkt (Beginn `start_year`), laufende Zahlungen nachschüssig je Jahr | alle; S1–S5 mit 20–40 J. | M |
| A-02 | **Periodizität** | VoFi jährlich; Darlehen intern exakt (monatlich oder vierteljährlich wählbar) und jahresweise aggregiert; Ausgabe zusätzlich als Monatswerte (÷ 12) für den Haushaltsmodus; Bauphase optional mit Monats-/Quartalsauflösung für Bereitstellungsprovision (v2) | (d), (e); S2, S5 | M (unterjährige VoFi: v2) |
| A-03 | **Maßnahmen zu beliebigen Perioden** | Maßnahme = Objekt mit `year`, `cost` (+ Mengenbezug), `cost_basis_year`, `price_index`, `lifetime_years`, `ohnehin_cost` oder Verweis auf Ohnehin-Maßnahme, `subsidies`, `effects` (Energie, Instandhaltung, Leerstand, Miete), `effect_start` (Jahr der Maßnahme / Folgejahr / anteilig) | (d); S4 (Stufen 2027/2030/2033) | M |
| A-04 | **Mehrere Varianten je Projekt** | beliebig viele Varianten (Nichtstun, Ohnehin, Stufe A/B, Ersatzneubau, Teilvarianten); eine `reference_variant`; paarweiser Vergleich und Ranking; gemeinsame Bausteine über `shared`-Block oder YAML-Anker; Vererbung `extends` nur mit expliziten `remove`/`replace`-Operationen (sonst Fehlerquelle) | alle; S1 (V0–V4), S2 (V1/V1b/V2/V3), S4 (V0–V3) | M |
| A-05 | **Ohnehin-Logik doppelt abbildbar** | (1) Vollkostenvergleich: Ohnehin als eigene Variante mit eigenen Zeitpunkten; (2) Differenzkostenansatz: `ohnehin_cost` je Maßnahme für § 559 und die Kennzahl „energiebedingte Mehrkosten“; Konsistenzprüfung beider Angaben; Hinweis auf bedingte Anforderungen des GModG bei Bauteilerneuerung (Ohnehin-Dach mit Mindestdämmung) | (a), (d); S1, S4 | M |
| A-06 | **Bauphase / Zahlungsplan** | Investition über mehrere Perioden verteilt (`payment_schedule`), Mieterträge ab Bezugsjahr, Erstvermietungsabschlag, Mietminderung während Bauarbeiten im Bestand | (a), (e); S1, S2, S5 | M |
| A-07 | **Mehrere Darlehen unterschiedlicher Art** | Annuitätendarlehen, Abzahlungs-(Raten-)darlehen, endfällig; tilgungsfreie Anlaufjahre; Zinsbindung ≠ Laufzeit; Tilgungszuschuss (Prozent vom Kreditbetrag, je Teilbetrag unterschiedlich, Gutschriftjahr, Wirkung `term_reduction` oder `payment_reduction`); Tilgungsnachlass (Landesförderung); Bereitstellungsprovision; Disagio; Sondertilgung (nur wo zulässig – KfW: nein); Auszahlungszeitpunkt/-reihenfolge; Bausparvertrag und Forward-Darlehen | (a), (e); S1, S2, S5 | M (Bauspar/Forward: v2) |
| A-08 | **Anschlussfinanzierung** | automatisch bei Zinsbindungsende: Restschuld × Anschlusszins (deterministisch, Szenario oder MC-Pfad); Neuberechnung der Annuität auf Restlaufzeit oder Fortführung mit Ziel-Tilgungssatz; Option Volltilgung aus Guthaben | (a), (e); S1, S2, S5 | M |
| A-09 | **VoFi-Ausgleichsmechanik** | Defizite automatisch über Kontokorrent/Ergänzungskredit (Sollzins), Überschüsse als Geldanlage (Habenzins), optional Entnahmen; EK-Budget je Projekt gleich für alle Varianten (nicht verwendetes EK wird angelegt) → faire Vergleichbarkeit | alle | M |
| A-10 | **Zuschüsse mit Auszahlungsverzug** | Zuschuss fließt in Jahr t + k (Verwendungsnachweis); Zwischenfinanzierung über VoFi-Konto; Verwendung wählbar (Liquidität oder Sondertilgung) | (b), (d); S3, S4 | M |
| A-11 | **Benutzerdefinierte Zahlungsreihen** | beliebige Ein-/Auszahlungszeilen mit Start/Ende, Betrag, Mengenbezug, Wachstum (konstant %, Index, Stufen, Zeitreihe), Kategorie (z. B. Betriebskosten nicht umlagefähig), Flag `allocable_to_tenant`, Variantenbezug | alle (Sonderfälle wie Stellplätze, Mieterstrom, Umzugskosten) | M |
| A-12 | **Indizes** | VPI, Baupreisindex, Instandhaltungsindex, Mietindex, Bodenwert, Energiepreiskomponenten; jede Zeile referenziert einen Index; Indizes deterministisch oder stochastisch | alle | M |
| A-13 | **Überschreibbare Parameterbibliotheken** | versionierte Bibliotheken (YAML/CSV) mit Quelle, Abrufdatum, Gültigkeitszeitraum: Förderprogramme als **Regelobjekte mit Stichtag** (Antragsdatum entscheidet), Energieträger (Preiskomponenten, Emissionsfaktoren), CO₂-Pfade, Bio-Treppe, Mietrecht (Sätze/Kappungen), CO₂KostAufG-Tabelle, Bewirtschaftungskosten (ImmoWertV), Kostenkennwerte, Nutzungsdauern, Liegenschaftszinsen; projektspezifische Overrides mit Protokoll (welcher Wert woher) | alle; Reform 21.07.2026 und Degression ab 01.02.2027 | M |
| A-14 | **Mengenbezug** | Eingaben als `total`, `per_unit` (WE), `per_m2_living_area`, `per_m2_component` (Fassade, Dach, Fenster …), `per_kw`, `per_kwp`, `per_kwh`; Umrechnung über Gebäudedaten; Ausgabe wahlweise gesamt, je WE, je m² Wfl. und Monat | (a), (b): €/m²·Monat; (d), (e): € gesamt/Monat | M |
| A-15 | **Energiebilanz vereinfacht** | Wärmebedarf je Zustand (Zeitintervalle) oder als Faktor-Wirkung je Maßnahme; Bedarf vs. Verbrauch mit Prebound-/Rebound-Faktoren; mehrere Energieträger je Variante; JAZ zeitabhängig je Zustand; PV vereinfacht (Ertrag, Eigenverbrauchsquote, Einspeisevergütung mit IBN-Datum und Vergütungsdauer) | (a), (b), (d); S1, S3, S4 | M (stündliche PV-/WP-Simulation: v2) |
| A-16 | **Restwertverfahren wählbar** | `none`, `linear_book_value` (Komponenten-Zeitwert), `income_value` (Ertragswert ImmoWertV vereinfacht: Bodenwert, Reinertrag, Liegenschaftszins, RND), `asset_value` (Sachwert vereinfacht), `multiplier` (Vervielfältiger × Jahresrohertrag), `user_value`; Ergebnis immer auch ohne Restwert | (a), (b), (d), (e); S1–S5 | M |
| A-17 | **Mietrechtsmodul** | § 558 vereinfacht (Steigerungspfad bis Vergleichsmiete, Kappungsgrenze 15/20 % in 3 J.); § 559 (8 %, Erhaltungsabzug, Kappung 3/2 €/m² je WE), § 559a (Zuschüsse, Zinsermäßigung – Zurechnung wählbar), § 559e (10 %, 15 % Pauschale, 0,50 €/m²), § 559f (JAZ-Schwelle 2,5 → 50 %), freiwillige Kappung/Warmmietenneutralität, Härtefallquote; Mietpreisbremse bei Neuvermietung (S) | (a), (b), (c); S1, S3 | M (§ 558 detailliert: S) |
| A-18 | **CO₂KostAufG und § 5a** | Stufenmodell nach kg CO₂/m²·a; ab 2028 50/50 für neu eingebaute fossile Heizungen inkl. Gasnetzentgelte, ab 2029 Bio-Mehrkosten mit 30-%-Mengendeckel; Einbaudatum der Heizung als Attribut | (a), (b), (c); S1, S3 | M |
| A-19 | **Zielwertsuche** | Break-even-Miete, maximal tragbare Investition, notwendige Förderung, Break-even-Gaspreis/CO₂-Preis (eindimensional, z. B. über Nullstellensuche) | (a), (e); S2 | S |
| A-20 | **Perspektiven** | Eigentümer-VoFi (Haupt); Nutzerkostensicht (Nettokaltmiete + Umlage + Heiz-/Warmwasserkosten + sonstige BK = Warmmiete) als abgeleitete Tabelle je Variante; optional vollständige Mieter-VoFi (v2) | (a), (b); S1, S3 | M (Mieter-VoFi: v2) |
| A-21 | **Monte Carlo** | jeder numerische Parameter (auch Index-Pfade, Ereigniszeitpunkte wie Kesselausfall, Förderverfügbarkeit als Bernoulli) stochastisch; Verteilungsbibliothek (normal, lognormal, trunkiert, Dreieck, PERT, Beta, Gleich, diskret, Bernoulli, Random Walk/AR(1), Mean-Reversion für Zinsen); Korrelationen über Gauß-Copula; gemeinsame Zufallszahlen für alle Varianten eines Laufs (Common Random Numbers); Seed; Ergebnis-Quantile, P(Variante besser), Konvergenzdiagnostik | alle | M (zeitreihenmodelle: S) |
| A-22 | **Steuern** | Ertragsteuer (AfA, Erhaltungsaufwand, § 35c, Verlustverrechnung), Grunderwerbsteuer als Eingabe | (c), (d) | v2 (Hook im Datenmodell M) |
| A-23 | **Portfolio** | mehrere Gebäude/Projekte aggregieren, gemeinsame Finanzierung/Budgetrestriktion, Maßnahmenpriorisierung nach CO₂-Pfad | (a), (b) | v2 (siehe 3.1) |
| A-24 | **Szenario-Sets (deterministisch)** | benannte Szenarien (z. B. „Hochpreis-CO₂“, „Zinsschock“, „Förderstopp“) als Overlay auf Basisparameter; Vergleichstabelle | (a), (e) | S |
| A-25 | **Validierung und Plausibilisierung** | Schemaprüfung, Pflichtfelder, Einheitenprüfung, Warnungen (z. B. Umlage > Kappung, Belastungsquote > 40 %, Bedarf ≫ Verbrauch ohne Prebound-Faktor, Ohnehin > Vollkosten) | alle | M |

### 3.1 Bewertung Portfolio-Aggregation (v1 oder später?)

- **Nutzen:** hoch für (a) und (b) – Investitionsbudget, Klimapfad des Gesamtbestands, Verschuldungsgrenzen, Priorisierung („welche 5 von 40 Gebäuden zuerst“).
- **Komplexität:** gemeinsame Finanzierung (Konzernfinanzierung statt Objektfinanzierung), Budget- und Liquiditätsrestriktionen über Gebäude hinweg, Kopplung von Maßnahmenzeitpunkten, Ergebnisdarstellung; MC über Portfolios verlangt korrelierte Gebäudeparameter.
- **Empfehlung:** **v2.** In v1 nur (i) Datenmodell mit eindeutigen IDs `project → building → variant` und (ii) einfache Summation deterministischer Zahlungsreihen mehrerer Projekte als Hilfsfunktion („Batch-Lauf mit Summenzeile“, ohne gemeinsame Finanzierung). Damit sind spätere Portfolio-Funktionen ohne Bruch des Eingabeformats möglich.

### 3.2 Gebäude- vs. WE- vs. m²-Eingaben

- **Gebäudeebene** (Default): Flächen, Gesamtkosten, Energieverbrauch, Darlehen.
- **WE-Ebene** (optional, „Mieterliste“): Einzelmieten und -flächen sind für die § 559-Kappung (2 €/m² bei Miete < 7 €/m²) und § 558 je Wohnung nötig; Förderhöchstbeträge je WE (KfW 261: 150.000 €/WE; KfW 458/459: Staffel 1./2.–6./ab 7. WE).
- **m²-Ebene:** Kostenkennwerte und Bewirtschaftungskosten; Unterscheidung **Wohnfläche** (Mietrecht, CO₂KostAufG, Bewirtschaftung) und **Gebäudenutzfläche A_N** (Energieausweis/Effizienzhaus) mit Umrechnungsfaktor (MFH typ. 1,2–1,35).
- Regel: Jede Eingabe trägt ihre Einheit; das Tool rechnet intern immer in Gesamtbeträgen und gibt auf Wunsch je WE/je m² aus.

---

## 4. Referenzszenarien S1–S5

### 4.0 Gemeinsame Konventionen und Default-Parameter

**Zeitachse:** Projektstart `start_year = 2027` für alle Szenarien (Anträge bis Ende 2026 zur Sicherung der aktuellen Förderkonditionen). t = 0 ≙ 01.01.2027; Periode t (t ≥ 1) ≙ Kalenderjahr 2026 + t, nachschüssig zum 31.12. Eine Maßnahme mit `year: 2030` wird zu t = 3 (01.01.2030) ausgezahlt und wirkt ab dem Jahr 2030 (Periode t = 4). Ausnahme: explizite Zahlungspläne (S2).

**Preisbasis:** Kostenangaben in Preisbasis Q4/2026 („2026“), indexiert mit Baupreisindex bis zum Ausführungsjahr; Ausnahme S5 (Festpreis-Bauvertrag 2027) und S1/S2/S3 Maßnahmen 2027 (Kostenstand 2027 bereits enthalten). Alle Beträge brutto.

**Default-Indizes (A, deterministische Basis):**

| Index | 2027 | ab 2028 | Begründung |
|---|---|---|---|
| VPI | 2,8 % | 2,2 % | Inflation 09/2026 3,3 % [Q22], langfristig nahe EZB-Ziel |
| Baupreisindex / Instandhaltung | 4,0 % | 3,0 % | +5,5 % bzw. +6,0 % 08/2026 [Q23], langfristig über VPI |
| Bodenwert | 1,5 % | 1,5 % | (A) |
| Mieten Bestand (§ 558) | 1,5 % | 1,5 % | (A), moderat für kommunale/genossenschaftliche Bestände |
| Mieten Neubau | 2,0 % | 2,0 % | (A); Empirica erwartet 3–4 % Marktmieten [Q29] |

**Default-Energiepreise (Preisbasis 2026, brutto, A auf Basis [Q17], [Q18], [Q26]):**

| Energieträger | Arbeitspreis | davon Netzentgelt | davon CO₂ (60 €/t) | Rest (Beschaffung, Vertrieb, Steuern) | Grundpreis | Wachstum Rest | Wachstum Netzentgelt |
|---|---|---|---|---|---|---|---|
| Erdgas EFH | 12,50 ct/kWh | 3,06 ct (2,57 netto) | 1,29 ct | 8,15 ct | 180 €/a | 2,0 % | 3,0 % (Netzrückbau) |
| Erdgas MFH | 11,20 ct/kWh | 2,61 ct (2,19 netto) | 1,29 ct | 7,30 ct | im Arbeitspreis | 2,0 % | 3,0 % |
| WP-Strom EFH | 24,0 ct/kWh | – | – | 24,0 ct | 140 €/a | 2,0 % | – |
| WP-Strom MFH | 25,0 ct/kWh (inkl. Grundpreis) | – | – | – | – | 2,0 % | – |
| Haushaltsstrom | 37,0 ct/kWh | – | – | – | 120 €/a | 2,0 % | – |
| Einspeisung PV (IBN bis 31.01.2027) | ≤ 10 kWp 7,70 ct; 10–40 kWp 6,66 ct | – | – | – | – | fix 20 J. | – |
| Biomethan-Mehrkosten ggü. Erdgas | 6,0 ct/kWh netto (7,14 brutto) | – | – | – | – | 2,0 % | – |

**CO₂-Preispfad (A, nominal, netto):** 2026: 60 €/t; 2027: 60 €/t (Korridor 55–65 [Q16]); 2028: 70 €/t (ETS-2-Start); +5 €/t p. a. bis 2035 (105 €/t); danach +3 % p. a. CO₂-Kosten brutto = Emissionsfaktor × Preis × 1,19.

**Emissionsfaktor Erdgas:** 0,181 kg CO₂/kWh (bezogen auf Brennwert H_s; ≙ 0,201 kg/kWh H_i nach BEHG-Standardwert) – (A), im Energiememo zu verifizieren. Biomethan-Anteil: CO₂-Preis entfällt auf den Bio-Anteil.

**Bio-Treppe für nach dem 29.07.2026 eingebaute Gaskessel (§ 43 Abs. 1 GModG, Stufen wie Memo 02):** 2029: 10 %; 2030–2034: 15 %; 2035–2039: 30 %; 2040–2044: 60 %; ab 2045: 100 % klimaneutraler Brennstoff (A – Ableitung aus dem Klimaneutralitätsziel 2045, keine ausdrückliche Gesetzesstufe; im Fachmemo zu klären).

**Finanzmarkt-Defaults (A):** Kapitalmarktdarlehen WU 4,00 % (10 J. fest), privat 4,10 % Soll (10 J. fest); Anschlusszins deterministisch **4,00 %** (Niveau 10/2026 fortgeschrieben; bewusst etwas konservativer als der Erwartungspfad des Zinsprozesses aus Memo 04 mit θ = 3,75 %); Habenzins WU 2,0 %, privat 2,5 %; Kontokorrent/Ergänzungskredit WU 5,5 %, privat 6,0 %; KfW-Zinsen laut Konditionenanzeiger 22.10.2026 [Q1], bei späterer Inanspruchnahme (S4: 2030, 2033) gleich angenommen (MC variiert).

**Default-MC-Verteilungen (gelten, sofern im Szenario nichts anderes steht):**

| Parameter | Verteilung (Vorschlag) | Kommentar |
|---|---|---|
| VPI p. a. | Pfadmittel ~ N(2,2 %; 0,6 Pp), jährliche Abweichung N(0; 0,8 Pp), AR(1) φ = 0,5 | Korrelation mit Baupreis ρ = 0,6, mit Zins ρ = 0,4 |
| Baupreisindex p. a. | N(3,0 %; 1,2 Pp) | |
| Gas-Beschaffungskomponente | Lognormaler Random Walk, Drift +2,0 % nominal, σ = 12 % p. a. | ρ(Gas, Strom) = 0,6 |
| Stromkomponente | Lognormaler Random Walk, Drift +2,0 %, σ = 8 % p. a. | |
| Gasnetzentgelte (Wachstum) | Dreieck(0 %; 3 %; 8 %) p. a. | Netzrückbau, sinkende Kundenzahl |
| CO₂-Preis 2030 / 2040 | Dreieck(60; 90; 200) / Dreieck(80; 150; 300) €/t, Interpolation linear | ETS-2-Unsicherheit |
| Biomethan-Mehrkosten | Dreieck(3; 6; 10) ct/kWh netto | |
| Anschlusszins | Vasicek wie Memo 04: r₀ ≈ 4,0 %, θ 3,75 %, κ 0,12, σ 0,7 Pp p. a., Floor 0,5 %; Option θ ~ N(3,75 %; 0,5 Pp) | Habenzins und Kontokorrent als Spread zum Pfad (Memo 04) |
| Baukostenabweichung | Neubau PERT(0,95; 1,05; 1,35), Sanierung im Bestand PERT(0,95; 1,10; 1,50) als Faktor (Memo 04) | einfache Komponententauschmaßnahmen szenariospezifisch enger |
| Mietsteigerung | N(Basis; 0,6 Pp) | |
| Leerstand | Niveau PERT(0; Basis; 8 %) (Memo 04), jährliche Schwankung iid | |
| JAZ | Bestand PERT(2,6; 3,2; 4,0), Neubau PERT(3,2; 3,8; 4,6) (Memo 04); szenariospezifisch Modus = Basiswert | |
| Prebound-/Rebound-Faktor | f_pre PERT(0,5; 0,7; 1,0), f_post PERT(0,9; 1,1; 1,4), ρ_S ≈ 0,3 (Memo 04) | entfällt f_pre, wenn Verbrauchsdaten vorliegen (S1, S3, S4) |
| Liegenschaftszins (Restwert) | N(Basis; 0,5 Pp), trunkiert [2 %; 6 %] | |
| Restnutzungsdauer am Horizont | Dreieck(Basis − 5; Basis; Basis + 5) J. | |
| Förderverfügbarkeit nach 2030 | Bernoulli(p = 0,7) | S4 Stufe 3 |
| Einspeisevergütung Neuanlagen ab 2027 (< 25 kWp) | Bernoulli(p = 0,5): Vergütung wie 2026 −1 %/Halbjahr, sonst 0 | EEG-Reform [Q26] |

### 4.1 S1 – Kommunales Wohnungsunternehmen: energetische Sanierung eines MFH (1963) auf EH 70 EE vs. Ohnehin-Sanierung

**Steckbrief**

| Merkmal | Wert |
|---|---|
| Persona | (a) Controllerin kommunales WU |
| Horizont | 30 Jahre: 2027–2056 (t = 0 … 30) |
| Perspektiven | Eigentümer-VoFi (Haupt), Mieter-Warmmiete (abgeleitet) |
| Referenzvariante | V1 Ohnehin-Sanierung |
| Pflichtvarianten für Tests | V1, V2 |
| Optionale Varianten | V0 Nichtstun, V3 EH 55 EE (Stufe B), V4 Ersatzneubau |

**Gebäude**

| Parameter | Wert | Q/A |
|---|---|---|
| Baujahr, Typ | 1963, Zeilenbau, 4 Vollgeschosse, 2 Aufgänge, unbeheizter Dachboden, unbeheizter Keller | A |
| Wohneinheiten | 24 WE, Ø 66,7 m² | Vorgabe |
| Wohnfläche | 1.600 m² | Vorgabe |
| Gebäudenutzfläche A_N | 2.000 m² (Faktor 1,25) | A |
| Grundstück | 1.800 m², Bodenrichtwert 280 €/m² → Bodenwert 504.000 € (2026) | A |
| Bauteilflächen | Außenwand opak 1.500 m², Fenster 380 m², oberste Geschossdecke 400 m², Kellerdecke 400 m² | A |
| Heizung Bestand | zentraler Gas-Niedertemperaturkessel Bj. 1998 (200 kW), zentrale TWW mit Zirkulation | A |
| Energieausweis (Bedarf) | Endenergie 255 kWh/(m² A_N·a) → **Klasse H → Worst Performing Building (WPB)** (WPB-Definition der BEG-WG-Richtlinie prüfen) | A |
| Verbrauch (Ø 3 Jahre) | 280.000 kWh_Hs Gas/a ≙ 175 kWh/(m² Wfl.·a) (Heizung + TWW) → Prebound-Faktor 280.000 / 510.000 ≈ 0,55 | A |
| CO₂-Intensität Bestand | 280.000 × 0,181 = 50,7 t/a → **31,7 kg/(m²·a)** → Stufe 27–< 32 → Vermieteranteil 40 % | berechnet |

**Varianten**

| ID | Bezeichnung | Inhalt |
|---|---|---|
| V0 (optional) | Nichtstun | nur Mindestinstandhaltung, Heizungsersatz bei Ausfall (MC: Ausfalljahr diskret gleichverteilt 2027–2030) durch Gas-Brennwert; Leerstand steigt (3 % → 6 % ab 2035) |
| **V1** | **Ohnehin-Sanierung** | Gerüst, Putzausbesserung + Anstrich (< 10 % Putzerneuerung, löst keine Dämmpflicht aus), Fenstertausch 2-fach (U_w = 1,3 nach GModG-Mindestanforderung), Gas-Brennwertkessel (Einbau 2027, also nach 29.07.2026 → § 5a CO₂KostAufG), hydraulischer Abgleich |
| **V2** | **Energetische Sanierung EH 70 EE** | WDVS 16 cm, Dämmung oberste Geschossdecke und Kellerdecke, Fenster 3-fach (U_w ≈ 0,9), Luft/Wasser-WP-Kaskade 2 × 45 kW mit Puffer, Frischwasserstationen, teilweiser Heizkörpertausch, hydraulischer Abgleich, zentrale Abluftanlage; KfW 261 mit WPB-Bonus |
| V3 (optional) | EH 55 EE (Stufe B) | wie V2, zusätzlich 20 cm WDVS, Lüftung mit WRG, PV 30 kWp; Kosten V2 × 1,18 (A); TZ 5 % + 10 % WPB = 15 % |
| V4 (optional) | Ersatzneubau | Abriss (Rückbau 150 €/m² Wfl. = 240.000 €), Umzugs-/Entschädigungskosten 5.000 €/WE, Nachverdichtung auf 30 WE/2.000 m² Wfl. mit Kennwerten aus S2 (EH 55), 2 Jahre Bauzeit ohne Mieteinnahmen, Neubaumiete 12,50 €/m² |

**Investitionskosten (Kostenstand 2027, brutto)**

| Position | V1 Ohnehin | V2 EH 70 EE | Mengenbasis |
|---|---|---|---|
| Gerüst | 22.500 € | 22.500 € | 1.500 m² × 15 € |
| Fassade | 82.500 € (Putz/Anstrich 55 €/m²) | 360.000 € (WDVS 240 €/m²) | 1.500 m² |
| Oberste Geschossdecke | – | 32.000 € (80 €/m²) | 400 m² |
| Kellerdecke | – | 24.000 € (60 €/m²) | 400 m² |
| Fenster | 266.000 € (700 €/m², 2-fach) | 361.000 € (950 €/m², 3-fach) | 380 m² |
| Heizung/TWW | 95.000 € (Gas-BW inkl. Abgas, Speicher) + 12.000 € (Abgleich) | 300.000 € (WP-Kaskade 126.000, Heizkörper 65.000, TWW 40.000, Elektro/Netzanschluss 25.000, Abgleich/Sonstiges 44.000) | – |
| Lüftung | – | 72.000 € (Abluft, 3.000 €/WE) | 24 WE |
| **Summe Bauleistung** | **478.000 €** | **1.171.500 €** | |
| Baunebenkosten KG 700 | 15 % → 71.700 € | 18 % → 210.870 € (davon Baubegleitung EEE 36.000 €) | |
| Unvorhergesehenes | 5 % → 27.485 € | 5 % → 69.118,50 € | auf Bau + KG 700 |
| **Gesamtinvestition** | **577.185,00 €** (361 €/m²) | **1.451.488,50 €** (907 €/m²; 60.479 €/WE) | |
| Ohnehin-Anteil von V2 | – | 577.185 € (39,8 %) → **Modernisierungskosten 874.303,50 €** | |

**Mieten und Erlöse**

| Parameter | V1 | V2 | Q/A |
|---|---|---|---|
| Nettokaltmiete Ø 2026 | 6,20 €/m²·Monat (119.040 €/a Soll) | 6,20 €/m²·Monat | A (Bandbreite kommunaler Bestände [Q30]) |
| Ortsübliche Vergleichsmiete | 7,10 €/m² (unsaniert) | 7,60 €/m² (energetisch modernisiert) | A |
| Mietsteigerung § 558 | 1,5 % p. a. ab 2028 | 1,5 % p. a. auf Gesamtmiete inkl. Umlage ab 2029 | A |
| Modernisierungsumlage | keine (konservativ; Fenster-Verbesserung nicht umgelegt) | rechnerisch 55.651,59 €/a (2,90 €/m²·Monat), Kappung 2,00 €/m² → 38.400 €/a; **Unternehmensbeschluss: warmmietenneutral 1,10 €/m²·Monat = 21.120 €/a ab 01.01.2028** | berechnet/A |
| Härtefälle § 559 Abs. 4 | – | deterministisch 0 WE; MC: Anteil der WE ohne Umlage Beta(Mittel 8 %) | A |
| Leerstand | 3,0 % | 1,0 % | A |
| Mietminderung Bauphase 2027 | 1,25 % der Jahressollmiete | 7,5 % der Jahressollmiete | A |
| Uneinbringliche Forderungen | 1,0 % | 1,0 % | A |

**Bewirtschaftung (Eigentümer, nicht umlagefähig)**

| Position | V1 | V2 | Index |
|---|---|---|---|
| Verwaltung | 367 €/WE·a = 8.808 €/a (2026) | gleich | VPI |
| Instandhaltung (pauschal) | 14,40 €/m²·a = 23.040 €/a (2026) | 2028–2042: 10,00 €/m²·a; ab 2043: 14,40 €/m²·a | Baupreisindex |
| Leerstandsbedingte Betriebskosten | 2,50 €/m²·Monat × leerstehende Fläche | gleich | VPI |
| Explizite Ersatzinvestitionen (nicht in Pauschale) | 2042: Fassade erneut 82.500 €; 2047: Kesselersatz 95.000 € | 2047: WP-Erzeuger/Peripherie 180.000 €; 2047: WDVS-Anstrich 45.000 € | Baupreisindex, Kostenstand 2027 |

**Energie und CO₂**

| Parameter | V1 Ohnehin (Gas-BW ab 10/2027) | V2 EH 70 EE (WP ab 10/2027) |
|---|---|---|
| Wärmebezug | Gas 280.000 kWh/a bis Umstellung, danach 255.000 kWh/a (Wirkungsgradgewinn ≈ 9 %) | Gas 280.000 kWh × 0,75 im Jahr 2027 (Heizperiode bis Umschluss), ab 2028 Nutzwärme 75 kWh/m²·a = 120.000 kWh/a (inkl. Rebound) |
| Erzeuger | η ≈ 0,95 | JAZ 2,9 (VDI 4650, Vorlauf ≤ 55 °C → § 559f erfüllt) → **41.379 kWh_el/a** |
| Preis Mieterseite 2026 | Gas MFH 11,20 ct/kWh | WP-Strom MFH 25,0 ct/kWh |
| Wartung/Schornsteinfeger (umlagefähig) | 1.800 €/a | 2.400 €/a |
| Heiz-/WW-Kosten Mieter (Preisbasis 2026) | 1,73 €/m²·Monat (Bestand) bzw. ≈ 1,58 €/m² (neuer Kessel) | **0,66 €/m²·Monat** |
| CO₂ | 2027: Stufenmodell (28,8 kg/m²·a → 40 %); **ab 2028 § 5a: 50 % CO₂**; ab 2028 **50 % Gasnetzentgelte** (Vermieter); ab 2029 50 % der Bio-Mehrkosten (max. 30 % der Menge) | 2027: Stufenmodell auf Restgasmenge; ab 2028 keine CO₂-Kosten |
| Vermieterkosten Energie (Größenordnung) | 2028: CO₂-Anteil 255.000 kWh × 0,181 kg × 70 €/t × 1,19 × 0,5 ≈ 1.920 € + Netzentgeltanteil 255.000 × 2,61 ct × 0,5 ≈ 3.330 € → ≈ 5.250 €/a, steigend; ab 2035 zusätzlich Bio-Mehrkostenanteil (30 % Menge × 7,14 ct × 0,5) ≈ 2.730 €/a (Preisbasis 2026) | ≈ 0 € |

**Finanzierung**

| Parameter | V1 | V2 |
|---|---|---|
| EK-Budget (gleich je Variante, A-09) | 151.488,50 €: davon 150.000 € eingesetzt, 1.488,50 € als Geldanlage zu 2,0 % | 151.488,50 € vollständig eingesetzt |
| Darlehen 1 | Kapitalmarkt 427.185 €, Annuität, Sollzins 4,00 % fest 10 J., Volltilgung 20 J. → **31.433,02 €/a**; Anschluss 2037 zu 4,00 % → Annuität unverändert 31.433,02 €/a (Testfall „gleicher Zins“); Sensitivität 4,25 % → 31.825,43 €/a | **KfW 261**: 1.300.000 € (investiv 1.264.000 € + Baubegleitung 36.000 €), Laufzeit 30 J., 5 tilgungsfreie J., Zinsbindung 10 J., Sollzins **3,65 %** |
| Tilgungszuschuss | – | 10 % (EH 70 EE 0 % + WPB 10 Pp) × 1.264.000 € = 126.400 € + 50 % × 36.000 € = 18.000 € → **144.400 €**, Gutschrift 01/2028 |
| Zinszahlung tilgungsfreie Jahre | – | 2027: 47.450 €; 2028–2031: 1.155.600 × 3,65 % = **42.179,40 €/a** |
| Annuität ab 2032 | – | TZ-Wirkung Laufzeitverkürzung (Default): **80.165,66 €/a** (Annuität des Ursprungsbetrags über 25 J.), Ende nach 21 Annuitätenjahren; Alternative Ratenreduzierung: **71.261,11 €/a** |
| Restschuld Ende Zinsbindung (31.12.2036) | 254.949,95 € | 951.288,32 € (Laufzeitverkürzung) bzw. 999.182,07 € (Ratenreduzierung); Anschluss 2037 zu 4,00 % (Basis) |
| Habenzins / Kontokorrent | 2,0 % / 5,5 % | 2,0 % / 5,5 % |

**Restwert 2056 (Ertragswert, ImmoWertV vereinfacht)**

| Parameter | V1 | V2 |
|---|---|---|
| Bodenwert 2056 | 504.000 € × 1,015³⁰ ≈ 787.800 € | gleich |
| Rohertrag 2056 | Nettokaltmiete × 12 (inkl. Umlage, ohne Leerstandsabzug) | gleich |
| Bewirtschaftungskosten | Verwaltung 367 €/WE (VPI), Instandhaltung 14,40 €/m² (Baupreisindex), Mietausfallwagnis 2 % | gleich |
| Liegenschaftszins | 3,5 % | 3,5 % |
| Restnutzungsdauer | 15 Jahre | 25 Jahre |
| Plausibilitätswert (nominal, kein Testwert) | ≈ 1,72 Mio. € | ≈ 2,65 Mio. € |

> Hinweis: Die Restwertdifferenz (≈ 0,93 Mio. € nominal 2056) ist größer als die Netto-Mehrinvestition und hängt fast vollständig an RND und Liegenschaftszins. Bericht immer mit und ohne Restwert sowie mit Tornado für RND/LZ.

**Erwartetes qualitatives Ergebnis (Hypothesen, durch Implementierung zu bestätigen)**

1. **Ohne Restwert:** V2 schlechter als V1 (Netto-Mehrinvestition ≈ 730 T€ nach Zuschuss; laufende Vorteile aus Umlage 21 T€, vermiedenen Vermieter-Energiekosten 5–8 T€, geringerem Leerstand ≈ 2,4 T€, geringerer Instandhaltung ≈ 7 T€ sowie vermiedenen Ersatzinvestitionen 2042 reichen nicht).
2. **Mit Restwert (Ertragswert):** V2 besser als V1; Vorzeichen kippt bei RND V2 ≲ 18 J. oder LZ ≳ 4,5 %.
3. **Hebel:** Umlage auf rechtliches Maximum (2,00 €/m²) verbessert V2 um ≈ 17 T€/a; **ohne WPB-Status (TZ 0 %) verliert V2 126.400 €** – die Reform vom 21.07.2026 macht den WPB-Bonus zum Kernkriterium für EH 70.
4. **Mieter:** Warmmiete V2 ≈ neutral (Umlage 1,10 € vs. Heizkostensenkung ≈ 1,07 €/m²); V1 steigt langfristig durch CO₂-Preis, Netzentgelte und Bio-Treppe (Mieter tragen 50 % bzw. den Bio-Anteil oberhalb von 30 % voll).
5. **CO₂:** Minderung ≈ 45–50 t/a direkt (ohne Strom-Emissionen) → CO₂-Vermeidungskosten (€/t) als Kennzahl.

**KPIs:** Differenz-VoFi-Endwert V2 − V1 (mit/ohne Restwert); VoFi-EK-Rendite je Variante; minimaler Kontostand und Kontokorrent-Spitzenbedarf; DSCR je Jahr; Umlage €/m² vs. Kappung; Warmmiete €/m²·Monat je Variante und Jahr; Förderbarwert (TZ + Zinsvorteil); CO₂-Minderung und -Vermeidungskosten; Vermögens-Amortisationsjahr.

**Stochastische Parameter (MC) – zusätzlich zu den Defaults**

| Parameter | Verteilung |
|---|---|
| Investitionskosten V2 / V1 | Sanierungs-Default PERT(0,95; 1,10; 1,50) / PERT(0,95; 1,05; 1,25), Rangkorrelation 0,7 |
| JAZ V2 | Dreieck(2,6; 2,9; 3,3) |
| Nutzwärme nach Sanierung | Dreieck(65; 75; 90) kWh/m²·a |
| Leerstand V1 / V2 | Beta(Mittel 3 %) / Beta(Mittel 1 %) |
| Härtefallquote | Beta(Mittel 8 %, sd 5 %) |
| Liegenschaftszins 2056 | N(3,5 %; 0,5 Pp) |
| RND 2056 V1 / V2 | Dreieck(10; 15; 20) / Dreieck(18; 25; 32) |
| Anschlusszins 2037 | Vasicek (Default) |
| Instandhaltungsersparnis V2 | Dreieck(2,0; 4,4; 6,0) €/m²·a |
| Mietspiegelvorteil V2 (zusätzliches § 558-Potenzial) | Dreieck(0; 0,2; 0,5) €/m² ab 2030 |

**Prüfwerte für Integrationstests (deterministisch, Toleranz ±0,01 € bzw. ±0,1 % bei Annuitäten)**

| Nr. | Größe | Erwartung |
|---|---|---|
| S1-T1 | Gesamtinvestition V2 / V1 | 1.451.488,50 € / 577.185,00 € |
| S1-T2 | Modernisierungskosten V2 (§ 559 Abs. 2) | 874.303,50 € |
| S1-T3 | Tilgungszuschuss KfW 261 | 144.400,00 € (126.400 + 18.000) |
| S1-T4 | Umlage rechnerisch: (874.303,50 − 144.400) × 8 % − Zinsermäßigung anteilig (1.300.000 × 0,60235 × 0,35 % = 2.740,69 €) | 55.651,59 €/a = 2,90 €/m²·Monat |
| S1-T5 | Kappung (Miete < 7 €/m² → 2 €/m²) | 38.400,00 €/a |
| S1-T6 | angesetzte Umlage (Beschluss) | 21.120,00 €/a |
| S1-T7 | Annuität V1 | 31.433,02 €/a |
| S1-T8 | KfW-Zinsen 2028–2031 / Annuität ab 2032 (Laufzeitverkürzung) | 42.179,40 €/a / 80.165,66 €/a |
| S1-T9 | CO₂-Intensität Bestand / Vermieteranteil | 31,7 kg/m²·a / 40 % |
| S1-T10 | Vermieteranteil CO₂ V1 ab 2028 | 50 % (§ 5a) |
| S1-T11 | Invariante | Summe Mittelverwendung t = 0 = Summe Mittelherkunft (EK + Darlehen) je Variante |
| S1-T12 | Monotonie | höherer CO₂-Preis → Differenz-Endwert V2 − V1 steigt |

---

### 4.2 S2 – Kommunales Wohnungsunternehmen: Neubau MFH (36 WE, 2.400 m²) mit KfW 298, Kapitalmarktdarlehen und Anschlussfinanzierung

**Steckbrief**

| Merkmal | Wert |
|---|---|
| Persona | (a) |
| Horizont | 40 Jahre: 2027–2066; Bauzeit 2027–2028, Bezug 01.01.2029 |
| Referenzvariante | V1 EH 55 mit KfW 298 EH-55-Stufe |
| Pflichtvarianten für Tests | V1, V1b, V2 |
| Optionale Variante | V3 EH 55 mit Landesförderung (Platzhalter, landesspezifisch) |

**Gebäude**

| Parameter | Wert | Q/A |
|---|---|---|
| Typ | Geschosswohnungsbau, 4 Geschosse + Staffel, Aufzug, keine Tiefgarage, 24 oberirdische Stellplätze | A |
| Wohnungsmix | 12 × 50 m² (2 Zi.), 18 × 65 m² (3 Zi.), 6 × 105 m² (4–5 Zi.) = 2.400 m² | A |
| Grundstück | 2.000 m² × 420 €/m² + 7,14 % Erwerbsnebenkosten ≈ 900.000 € (≙ 375 €/m² Wfl.) | A (Mittelstadt) |
| Heizung | zentrale Luft/Wasser-WP (beide Varianten; KfW verlangt keine fossile Heizung) | Q [Q4] |

**Varianten**

| ID | Bezeichnung | Standard | Förderung |
|---|---|---|---|
| **V1** | EH 55 mit KfW 298 EH-55-Stufe | GModG-Mindeststandard, EH 55, WP | KfW 298 EH 55: 100.000 €/WE = 3.600.000 €, Antrag bis 31.12.2026, Baugenehmigung liegt vor |
| **V1b** | EH 55 ohne KfW (Mittel erschöpft/Frist verpasst) | wie V1 | keine |
| **V2** | EH 40 + QNG-PLUS | EH 40, LCA, QNG-Zertifikat, WP + PV 40 kWp, Lüftung mit WRG | KfW 298 mit QNG: 150.000 €/WE = 5.400.000 € |
| V3 (optional) | EH 55 + soziale Wohnraumförderung (Platzhalter) | wie V1 | z. B. 11 WE gebunden (Miete 7,50 €/m², 25 J.), Landesdarlehen 2.200 €/m² gebundene Fläche, 0,5 % für 20 J., Tilgungsnachlass 25 % – Werte landesspezifisch, nur als Demonstrationsfall für Tilgungsnachlass und Belegungsbindung |

**Investitionskosten (brutto, Kostenstand 2027/28)**

| Position | V1/V1b EH 55 | V2 EH 40 QNG | Basis |
|---|---|---|---|
| Grundstück inkl. NK (KG 100) | 900.000 € | 900.000 € | A |
| Herrichten/Erschließung (KG 200) | 144.000 € | 144.000 € | 60 €/m² Wfl. |
| Bauwerk (KG 300+400) | 8.640.000 € | 9.072.000 € | 3.600 €/m² bzw. +5 % (A; ARGE-Median 3.500–3.750 €/m² [Q24]) |
| Außenanlagen inkl. Stellplätze (KG 500) | 288.000 € | 288.000 € | 120 €/m² Wfl. |
| Baunebenkosten (KG 700) | 1.728.000 € | 1.814.400 € | 20 % von KG 300+400 |
| QNG-Zertifizierung/LCA | – | 40.000 € | A |
| **Summe** | **11.700.000 €** (4.875 €/m²; 4.500 €/m² ohne Grundstück) | **12.258.400 €** (5.108 €/m²) | |
| Zahlungsplan | t = 0: Grundstück; 2027: 40 % der übrigen Kosten; 2028: 60 % | gleich | A |

**Mieten und Erlöse**

| Parameter | Wert | Q/A |
|---|---|---|
| Erstvermietungsmiete 2029 | 13,00 €/m²·Monat netto kalt (unter Marktniveau 18–20 €/m² der Großstädte [Q24], [Q29]) | A |
| Stellplätze | 24 × 35 €/Monat | A |
| Jahresrohertrag (Soll) 2029 | 374.400 € + 10.080 € = **384.480 €** | berechnet |
| Erstvermietungsabschlag 2029 | 8 % | A |
| Mietsteigerung | 2,0 % p. a. ab 2030 | A |
| Green Premium V2 | 0 €/m² (Basis) | A |
| Leerstand / Forderungsausfall | 1,0 % / 1,0 % ab 2030 | A |

**Bewirtschaftung (Eigentümer)**

| Position | Wert |
|---|---|
| Verwaltung | 367 €/WE·a (2026, VPI) = 13.212 €/a |
| Instandhaltung (altersabhängig, Preisbasis 2026, Baupreisindex) | Jahre 1–5 nach Bezug 4,00 €/m²; 6–15: 9,00 €/m²; ab 16: 14,40 €/m² |
| Explizite Ersatzinvestitionen | WP-Ersatz 2049: 160.000 € (V1) / 150.000 € (V2); Wechselrichter PV 2044 (V2): 6.000 €; Aufzug-Modernisierung 2054: 60.000 € (Preisbasis 2026) |
| Nicht umlagefähige Betriebskosten | 1,0 % des Rohertrags |

**Finanzierung**

| Parameter | V1 | V1b | V2 |
|---|---|---|---|
| EK | 3.000.000 € | 3.000.000 € | 3.000.000 € |
| KfW 298 | 3.600.000 €; 35/5/10; Sollzins **2,19 %** | – | 5.400.000 €; 35/5/10; Sollzins **2,94 %** |
| KfW-Zins in tilgungsfreien Jahren | 78.840 €/a | – | 158.760 €/a |
| KfW-Annuität danach (30 J.) | 164.969,40 €/a | – | 273.371,56 €/a |
| Kapitalmarktdarlehen | 5.100.000 €; 4,00 % fest 10 J.; 2 % Anfangstilgung → **306.000 €/a** | 8.700.000 €; gleiche Konditionen → 522.000 €/a | 3.858.400 €; gleiche Konditionen → **231.504 €/a** |
| Restschuld Bank Ende 2036 | 3.875.377 € | – | 2.931.913 € |
| Anschluss 2037 | Bank und KfW zu 4,00 % (Basis), KfW: Annuität auf Restlaufzeit; Bank: Fortführung mit gleicher Rate bis Volltilgung | | |
| Abrufreihenfolge | EK → KfW → Bank; KfW-Zusage 03/2027, vollständiger Abruf bis 02/2028 → Bereitstellungsprovision 0 € (Testannahme) | | |
| Bauzeitzinsen | über VoFi-Konto (Kontokorrent 5,5 %) | | |

**Restwert 2066**

Ertragswert: Liegenschaftszins 3,0 %, Gebäudealter 38 J., GND 80 → RND 42 J., Bodenwert 900.000 € × 1,015⁴⁰; Bewirtschaftungskosten nach ImmoWertV (indexiert). Alternative zur Plausibilisierung: Sachwert vereinfacht (Herstellungskosten indexiert × (1 − 38/80) + Bodenwert).

**Erwartetes qualitatives Ergebnis (Hypothesen)**

1. **Cashflow nach Kapitaldienst** in den ersten Betriebsjahren negativ (Größenordnung −30 bis −60 T€/a) → Kontokorrentbedarf; Bruttoanfangsrendite ≈ 3,3 % (V1) bzw. 3,1 % (V2) liegt unter dem Kapitalmarktzins.
2. **V1 > V2** unter den Konditionen 10/2026: Der Zinsvorteil der EH-55-Stufe (3,6 Mio. € × (4,00 − 2,19) % ≈ 65 T€/a) übersteigt den des EH 40 QNG (5,4 Mio. € × (4,00 − 2,94) % ≈ 57 T€/a), und V2 kostet 558 T€ mehr.
3. **V2 > V1b:** Ist die EH-55-Stufe nicht verfügbar, dreht das Ergebnis zugunsten von EH 40 QNG → zentrale Botschaft: Förderverfügbarkeit zum Antragszeitpunkt ist entscheidungsrelevant.
4. **Break-even-Miete** für VoFi-EK-Rendite 4 %: Hypothese 15–17 €/m² (V1).
5. Zinsänderungsrisiko 2037 (Restschuld Bank ≈ 3,9 Mio. € in V1) prägt die Streuung der MC-Ergebnisse.

**KPIs:** VoFi-Endwert und VoFi-EK-Rendite; Break-even-Miete; Kontokorrent-Spitzenbedarf; DSCR; LTV; Restschuld zum Zinsbindungsende; Subventionsbarwert (Barwert des KfW-Zinsvorteils); Warmmiete der Mieter (Information); CO₂ (Information).

**Stochastische Parameter (MC)**

| Parameter | Verteilung |
|---|---|
| Baukostenabweichung (Bauwerk) | Neubau-Default PERT(0,95; 1,05; 1,35) |
| Bauzeitverzug | PERT(0; 2; 12) Monate (Memo 04), Rangkorrelation 0,5 mit Kostenüberschreitung → Mietausfall, Bauzeitzinsen |
| Erstvermietungsmiete | N(13,00; 0,80) €/m² |
| Mietsteigerung | N(2,0 %; 0,7 Pp) |
| Anschlusszins 2037 und 2047 | Vasicek (Default), gemeinsamer Pfad |
| Liegenschaftszins 2066 | N(3,0 %; 0,5 Pp) |
| Instandhaltung | Faktor Dreieck(0,8; 1,0; 1,3) |
| Green Premium V2 | Gleich(0; 0,30) €/m² |
| Verfügbarkeit EH-55-Stufe | Bernoulli(p = 0,8) – bei 0 wird V1 zu V1b (nur in Szenario-Analyse, nicht im Default-Lauf) |

**Prüfwerte**

| Nr. | Größe | Erwartung |
|---|---|---|
| S2-T1 | Gesamtkosten V1 / V2 | 11.700.000 € / 12.258.400 € |
| S2-T2 | KfW-Beträge V1 / V2 | 3.600.000 € / 5.400.000 € (Höchstbetrag 100.000 bzw. 150.000 €/WE × 36) |
| S2-T3 | Bankdarlehen V1 / V1b / V2 | 5.100.000 € / 8.700.000 € / 3.858.400 € |
| S2-T4 | KfW-Zinsen tilgungsfreie Jahre V1 / V2 | 78.840 €/a / 158.760 €/a |
| S2-T5 | Bank-Annuität V1 / V2 | 306.000 €/a / 231.504 €/a |
| S2-T6 | Restschuld Bank 31.12.2036 V1 | 3.875.377 € (±1 €) |
| S2-T7 | Rohertrag Soll 2029 | 384.480 € (vor Erstvermietungsabschlag) |
| S2-T8 | keine Mieteinnahmen 2027–2028 | Summe Mieterträge t = 1, 2 = 0 |

---

### 4.3 S3 – Genossenschaft: Heizungstausch Gas → Wärmepumpe + PV im 12-WE-Gebäude (§ 559e)

**Steckbrief**

| Merkmal | Wert |
|---|---|
| Persona | (b) |
| Horizont | 20 Jahre: 2027–2046 |
| Perspektiven | Genossenschaft (VoFi) und Mitglieder (Nutzungsentgelt + Heizkosten) |
| Referenzvariante | V1 Gas-Brennwert (Ohnehin) |
| Pflichtvarianten | V1, V2 |
| Optional | V3 WP ohne PV; V4 Hybrid (WP + Gas-Spitzenlast) |

**Gebäude**

| Parameter | Wert | Q/A |
|---|---|---|
| Baujahr/Typ | 1985 (WSchVO 1984), 3 Geschosse, 12 WE à 70 m² = **840 m² Wfl.** | A |
| Heizung Bestand | Gas-Zentralheizung Bj. 2002 (24 J.), Vorlauf 70 °C | A |
| Verbrauch | 109.200 kWh_Hs/a (130 kWh/m²·a) | A |
| CO₂-Intensität Bestand | 19,8 t/a → 23,5 kg/m²·a → Stufe 22–< 27 → Vermieter 30 % | berechnet |
| Heizlast | ≈ 42 kW (50 W/m²) | A |
| Dach | Satteldach Süd, 30 kWp belegbar | A |

**Varianten und Kosten (Kostenstand 2027, brutto)**

| Position | V1 Gas-BW (Ohnehin) | V2 WP + PV |
|---|---|---|
| Wärmeerzeuger | Gas-Brennwert 38.000 € + Abgas 4.000 € | WP-Kaskade 2 × 22 kW inkl. Speicher/Montage 88.000 € |
| Heizkörpertausch | – | 24 Stück × 900 € = 21.600 € (Vorlauf 55 °C) |
| Trinkwarmwasser | – | Frischwasserstation/Legionellenschutz 18.000 € |
| Elektro, Zählerplatz, § 14a-Steuerung | – | 8.000 € |
| Demontage Altanlage | inkl. | 4.000 € |
| Planung/EEE | 8 % → 3.360 € | 10 % → 13.960 € |
| **Summe Heizung** | **45.360 €** | **153.560 €** |
| PV 30 kWp (1.150 €/kWp) + Messkonzept 4.000 € | – | **38.500 €** (USt 0 % nach § 12 Abs. 3 UStG, ≤ 30 kWp) |
| **Gesamt** | **45.360 €** | **192.060 €** |

**Förderung**

| Parameter | Wert | Q/A |
|---|---|---|
| Programm | KfW 459 (Unternehmen – Wohngebäude), Grundförderung 30 %; Antrag bis 31.01.2027 (vor Absenkung der WP-Grundförderung ab Q1/2027 und der 1.-WE-Höchstkosten ab 01.02.2027) | [Q9], [Q8] |
| Förderfähige Höchstkosten | 28.000 + 5 × 15.000 + 6 × 8.000 = **151.000 €** | [Q8] (Staffel für Unternehmen analog angenommen – prüfen) |
| Zuschuss | 30 % × min(153.560; 151.000) = **45.300 €**, Auszahlung 2028 | berechnet |
| PV | keine BEG-Förderung; EEG-Einspeisevergütung (IBN bis 31.01.2027): (10 × 7,70 + 20 × 6,66)/30 = **7,01 ct/kWh**, 20 J. fest | [Q26] |

**Nutzungsentgelt und Umlage**

| Parameter | V1 | V2 |
|---|---|---|
| Nutzungsentgelt 2026 | 6,40 €/m²·Monat (64.512 €/a) | gleich |
| Steigerung | 1,5 % p. a. | gleich |
| Leerstand | 1,0 % | 1,0 % |
| § 559e rechnerisch | – | 10 % × (153.560 − 45.300) × (1 − 0,15) = **9.202,10 €/a** (0,91 €/m²·Monat) |
| Kappung 0,50 €/m² | – | 5.040 €/a |
| JAZ-Prüfung § 559f | – | JAZ 3,1 ≥ 2,5 → volle Bemessungsgrundlage. Testfall JAZ 2,4 → nur 50 % der Kosten ansetzbar; Reihenfolge rechtlich zu klären (Parameter `hp_reduction_order`): Default „erst halbieren, dann Drittmittel abziehen“: 10 % × (76.780 − 45.300) × 0,85 = **2.675,80 €/a**; Alternative „erst Drittmittel, dann halbieren“: 4.601,05 €/a – beide unter der Kappung von 5.040 €/a |
| **Angesetzt (Vorstandsbeschluss)** | – | **0,35 €/m²·Monat = 3.528 €/a ab 2028** |

**Energie, Betrieb und CO₂**

| Parameter | V1 | V2 |
|---|---|---|
| Brennstoff/Strom | Gas 100.000 kWh/a (η 0,95 statt 0,87) | Nutzwärme 95.000 kWh/a, JAZ 3,1 → **30.646 kWh_el/a** |
| PV | – | Ertrag 900 kWh/kWp → 27.000 kWh/a; Eigenverbrauch (WP + Allgemeinstrom) 30 % = 8.100 kWh; Einspeisung 18.900 kWh → **1.324,26 €/a** |
| PV-Strom an Heizkostenabrechnung | – | interner Verrechnungspreis 20 ct/kWh → 1.620 €/a Erlös Genossenschaft (rechtlich prüfen; Alternative 0 ct = voller Mitgliedervorteil) |
| Netzbezug WP | – | 30.646 − 8.100 ≈ 22.546 kWh × 25 ct |
| Wartung (umlagefähig) | Gas 600 €/a + Schornsteinfeger 250 €/a | WP 900 €/a |
| PV-Betrieb (Eigentümer) | – | 1,5 % der PV-Investition = 577,50 €/a |
| CO₂/Netzentgelt Vermieter | 2027: Stufenmodell (21,5 kg/m²·a → 20 %); ab 2028 § 5a: 50 % CO₂ + 50 % Netzentgelt (100.000 × 2,61 ct × 0,5 ≈ 1.305 €/a); ab 2029 50 % Bio-Mehrkosten | 0 € |
| Heizkosten Mitglieder (Preisbasis 2026) | ≈ 12.050 €/a = 1,20 €/m²·Monat | ≈ 22.546 × 0,25 + 8.100 × 0,20 + 900 ≈ 8.157 €/a = 0,81 €/m²·Monat |

**Finanzierung**

| Parameter | V1 | V2 |
|---|---|---|
| EK-Budget | 50.000 € (45.360 € eingesetzt, Rest angelegt zu 2,0 %) | 50.000 € |
| Bankdarlehen | – | 142.060 €, Annuität, 3,90 % fest über 15 J., Volltilgung → **12.687,85 €/a** |
| Zuschuss | – | 45.300 € in 2028 → VoFi-Guthaben (Option: Sondertilgung) |
| Kalkulationszins (Mindestverzinsung) | 2,0 % | 2,0 % |

**Restwert 2046:** linearer Komponentenzeitwert – WP (ND 20 J.) 0 €; Gaskessel (ND 20 J.) 0 €; PV (ND 25 J., 20 J. genutzt) 20 % × 38.500 € = **7.700 €**. Kein Gebäudewerteffekt (A).

**Erwartetes qualitatives Ergebnis (Hypothesen)**

1. V2 > V1 aus Sicht der Genossenschaft: Zuschuss (45,3 T€), Umlage (3,5 T€/a), PV-Erlöse (≈ 2,9 T€/a) und vermiedene Vermieteranteile nach § 5a (≈ 2–3 T€/a, steigend) übersteigen den Kapitaldienst der Mehrinvestition (≈ 12,7 T€/a über 15 J. gegenüber EK-Einsatz in V1); Differenz-Endwert positiv (Größenordnung +20 bis +60 T€).
2. Mitglieder: Warmmiete V2 im ersten vollen Jahr um ≈ 0,04 €/m²·Monat niedriger als in V1 (Umlage +0,35 €, Heizkosten −0,39 €); der Abstand wächst mit CO₂-Preis, Gasnetzentgelten und Bio-Treppe.
3. Kritische Parameter: JAZ (< 2,5 halbiert die Umlagebasis), Strompreisentwicklung, rechtliche Zulässigkeit der PV-Stromverrechnung.

**KPIs:** Differenz-Endwert (Kalkulationszins 2 %); VoFi-Rendite der Mehrinvestition; Nutzungsentgelt- und Warmmietenpfad (€/m²·Monat); Kostendeckungsgrad; Liquidität (min. Kontostand); CO₂-Minderung.

**Stochastische Parameter (MC)**

| Parameter | Verteilung |
|---|---|
| JAZ | Dreieck(2,6; 3,1; 3,4) |
| Eigenverbrauchsquote PV | Dreieck(0,20; 0,30; 0,40) |
| PV-Ertrag | N(900; 60) kWh/kWp |
| Investitionskosten V2 | PERT(0,95; 1,00; 1,20) als Faktor (Komponententausch, enger als Sanierungs-Default) |
| Strom-/Gaspreise, CO₂, Netzentgelt, Bio | Defaults (Abschnitt 4.0) |
| Umlageakzeptanz (Anteil WE mit Härtefall) | Beta(Mittel 5 %) |

**Prüfwerte**

| Nr. | Größe | Erwartung |
|---|---|---|
| S3-T1 | Förderfähige Höchstkosten 12 WE | 151.000 € |
| S3-T2 | Zuschuss | 45.300,00 € |
| S3-T3 | § 559e rechnerisch / gekappt / angesetzt | 9.202,10 € / 5.040,00 € / 3.528,00 € |
| S3-T4 | § 559f bei JAZ 2,4 (rechnerisch, Default-Reihenfolge / Alternative) | 2.675,80 €/a / 4.601,05 €/a |
| S3-T5 | CO₂-Stufe Bestand | 23,5 kg/m²·a → 30 % |
| S3-T6 | Einspeiseerlös PV p. a. | 1.324,26 € |
| S3-T7 | Annuität Bankdarlehen | 12.687,85 €/a |
| S3-T8 | Restwert PV 2046 | 7.700,00 € |

---

### 4.4 S4 – Selbstnutzer EFH Baujahr 1975 (140 m²): stufenweise Sanierung nach iSFP vs. Gaskessel behalten

**Steckbrief**

| Merkmal | Wert |
|---|---|
| Persona | (d) |
| Horizont | 25 Jahre: 2027–2051 |
| Perspektive | Haushalt (Selbstnutzer), Haushaltsmodus-Bericht |
| Referenzvariante | V0 Gaskessel behalten (Ersatz bei Ausfall) |
| Pflichtvarianten | V0, V1 |
| Optional | V2 nur Wärmepumpe; V3 alles sofort (2027) |

**Gebäude und Haushalt**

| Parameter | Wert | Q/A |
|---|---|---|
| Gebäude | freistehendes EFH 1975, 1,5 Geschosse, Satteldach, Keller unbeheizt, 140 m² Wfl. | Vorgabe/A |
| Bauteilflächen | Dach 160 m², Fenster 28 m² (Bj. 1995, 2-fach), Fassade opak 180 m², Kellerdecke 75 m² | A |
| Heizung | Gas-Kessel Bj. 2005 (21 J. → Klimageschwindigkeitsbonus-berechtigt, ≥ 20 J. alt), η_eff 0,88 | A |
| Verbrauch | 24.500 kWh_Hs/a (175 kWh/m²·a, Heizung + TWW), Nutzwärme 21.560 kWh/a; iSFP-Bedarf 230 kWh/m²·a → Prebound ≈ 0,76 | A |
| Haushalt | 2 Erwachsene, 1 Kind (10 J.); zvE Ø (2023/2024) 58.000 € → Familienzuschlag −10.000 € → **48.000 €** → Einkommensbonus **10 %**; Nettoeinkommen 4.800 €/Monat (für Belastungsquote) | A, Regel [Q8] |
| iSFP | liegt vor (Kosten 1.800 €, BAFA-EBW-Zuschuss 50 %, max. 650 € – Wert prüfen), Bonusberechtigung 15 J. | A |
| Erspartes (EK-Budget) | 60.000 €, Habenzins 2,5 % | A |

**Varianten und Maßnahmen (Preisbasis 2026, Baupreisindex 3,0 % p. a. ab 2027 → Ausführungskosten)**

| Variante | Jahr | Maßnahme | Kosten Preisbasis 2026 | Kosten Ausführungsjahr | Ohnehin-Bezug |
|---|---|---|---|---|---|
| **V0** | 2030 | Gaskessel-Ersatz durch Gas-Brennwert (Ausfall; MC-Jahr) | 12.500 € | 14.068,86 € | – |
| V0 | 2032 | Dach-Neueindeckung **mit GModG-Mindestdämmung** (U ≤ 0,24, bedingte Anforderung bei Erneuerung) | 40.000 € | 47.762,09 € | – |
| V0 | 2033 | Fassadenanstrich inkl. Gerüst (keine Putzerneuerung) | 11.600 € | 14.266,54 € | – |
| V0 | 2042 | Fenstertausch 2-fach (U_w 1,3) | 19.600 € | 31.452,25 € | – |
| V0 | 2050 | Heizungsersatz durch WP (ab 2045 nur klimaneutraler Brennstoff → Gas nicht mehr sinnvoll), ohne Förderung (A) | 32.000 € | 65.049,41 € | – |
| **V1** | 2027 | Luft/Wasser-WP 10 kW inkl. 3 Heizkörper, Demontage | 32.000 € | **32.960,00 €** | Ohnehin: Gaskessel 2030 |
| V1 | 2030 | Dach (Aufsparrendämmung, U ≤ 0,14) 160 m² × 320 € + Fenster 3-fach 28 m² × 900 € | 76.400 € | **85.988,87 €** | Ohnehin: Dach 2032 (40.000 €), Fenster 2042 (19.600 €) |
| V1 | 2033 | WDVS 16 cm 180 m² × 210 € + Kellerdecke 75 m² × 50 € + Gerüst 3.500 € | 45.050 € | **55.405,82 €** | Ohnehin: Anstrich 2033 (11.600 €) |
| V1 | 2047 | WP-Ersatz (Erzeuger) | 25.000 € | 46.507,36 € | – |
| V2 | 2027 | wie V1 Stufe 1; Hülle wie V0 (Ohnehin-Termine) | – | – | – |
| V3 | 2027 | alle Maßnahmen V1 in einem Jahr (Förderdeckel 60.000 €/Jahr für Hülle) | 153.450 € | 158.053,50 € | – |

**Energie je Zustand**

| Variante/Zeitraum | Nutzwärme | Erzeuger | Endenergie | Kosten p. a. (Preisbasis 2026) |
|---|---|---|---|---|
| V0 2027–2029 | 21.560 kWh | Gas, η 0,88 | 24.500 kWh Gas | 24.500 × 12,5 ct + 180 € + 300 € Wartung/Schornsteinfeger = **3.542,50 €** (295,21 €/Monat) |
| V0 2030–2031 | 21.560 kWh | Gas-BW, η 0,94 | 22.936 kWh | Bio-Treppe für den 2030 eingebauten Kessel: 15 % ab 2030, 30 % ab 2035, 60 % ab 2040 |
| V0 2032–2041 | 18.973 kWh (−12 % Dach) | Gas-BW | 20.184 kWh | |
| V0 2042–2049 | −5 % Fenster | Gas-BW | 19.175 kWh | ab 2045: 100 % klimaneutraler Brennstoff |
| **V1 2027–2029** | 21.560 kWh | WP, JAZ 2,9 | **7.434,48 kWh_el** | 7.434,48 × 24 ct + 140 € + 250 € Wartung = **2.174,28 €** (181,19 €/Monat) |
| V1 2030–2032 | 16.170 kWh (−25 %) | WP, JAZ 3,2 | **5.053,13 kWh_el** | 1.602,75 € (133,56 €/Monat) |
| V1 ab 2033 | 11.642 kWh (−28 %; 83 kWh/m²·a) | WP, JAZ 3,5 | **3.326,40 kWh_el** | 1.188,34 € (99,03 €/Monat) |
| V2 2027–2031 / 2032–2041 / ab 2042 | 21.560 / 18.973 / 18.024 kWh | WP, JAZ 2,9 / 3,0 / 3,0 | 7.434 / 6.324 / 6.008 kWh_el | |

Energiepreise, CO₂-Pfad und Bio-Treppe gemäß Abschnitt 4.0 (Gas EFH zerlegt in Netzentgelt, CO₂, Rest).

**Förderung**

| Stufe | Programm | Berechnung | Betrag | Auszahlung |
|---|---|---|---|---|
| 2027 WP | KfW 458 (Antrag 12/2026) | (30 % Grund + 16 % Klimageschwindigkeit + 10 % Einkommen) = 56 % ≤ 70 % × min(32.960; 28.000) | **15.680,00 €** | 2028 |
| 2030 Dach + Fenster | BAFA BEG EM Gebäudehülle mit iSFP | förderfähig min(85.988,87; 60.000) = 60.000 €; Default „Bonus nur auf Betrag > 30.000 €“: 15 % × 60.000 + 5 % × 30.000 | **10.500,00 €** (Alternative „Bonus auf Gesamtbetrag“: 12.000,00 €) | 2031 |
| 2033 Fassade + Kellerdecke | BAFA (Fortbestand nach 2030 angenommen; MC Bernoulli) | 15 % × 55.405,82 + 5 % × 25.405,82 | **9.581,16 €** (Alternative 11.081,16 €) | 2034 |
| V3 (alles 2027) | KfW 458 + BAFA | Hülle: förderfähig gedeckelt auf 60.000 € in **einem** Kalenderjahr → Stufung bringt mehr Förderung | Prüfwert: 10.500 € (Hülle) + 15.680 € (WP) | |

**Finanzierung**

| Variante | Finanzierung |
|---|---|
| V0 | aus Erspartem (60.000 €); Fehlbeträge automatisch über Ergänzungskredit 6,0 % (VoFi-Ausgleich) |
| V1 2027 | WP aus Erspartem; Zuschuss 2028 ins Guthaben |
| V1 2030 | EK 15.000 € + **KfW 358** 70.000 € (25/3/10, Sollzins 2,53 % angenommen konstant): Zinsen 2030–2032 **1.771,00 €/a**, danach Annuität 22 J. **4.188,12 €/a**; Rest aus Guthaben |
| V1 2033 | EK 10.000 € + **KfW 358** 45.000 € (25/3/10, 2,53 %): Zinsen 2033–2035 **1.138,50 €/a**, danach **2.692,36 €/a**; Rest aus Guthaben |
| Anschluss | jeweils nach 10 J. zu 4,00 % (Basis) |

**Restwert 2051:** Default `linear_book_value` der Maßnahmen (ND: WP 20 J., Dach 50 J., Fenster 35 J., WDVS 40 J., Gaskessel 20 J.); Option „ohne Restwert“ (Pflichtausweis). Ein Immobilienwertzuschlag für die bessere Effizienzklasse ist optional (v1 aus).

**Erwartetes qualitatives Ergebnis (Hypothesen)**

1. **Wärmepumpe allein (V2) ist klar vorteilhaft** gegenüber V0: Netto-Mehrinvestition 2027 ≈ 17.300 € abzüglich vermiedenem Kesselersatz 2030 (14.069 €), Energie-/Wartungsersparnis ≈ 114 €/Monat ab 2027 und wachsend (CO₂, Netzentgelte, Bio-Treppe) → Vermögensamortisation nach wenigen Jahren (Hypothese ≤ 5 J.).
2. **V1 (Gesamtfahrplan) vs. V0:** In der Liquiditätssicht höhere Monatsbelastung während der Kreditlaufzeit (Hypothese +100 bis +250 €/Monat ab 2036), in der Vermögenssicht über 25 Jahre nahe Null – Vorzeichen hängt am Gas-/CO₂-Pfad, an der Förderung 2033 und am Restwert.
3. **V3 < V1:** Alles sofort bringt weniger Förderung (Jahresdeckel) und höheren Kreditbedarf; Vorteil früherer Energieeinsparung reicht nicht (Hypothese).
4. MC: P(V1 besser als V0) etwa 40–60 %; P(V2 besser als V0) > 90 % (Hypothesen).

**KPIs (Haushaltsmodus):** monatliche Belastung je Jahr (mit und ohne Tilgung), Ersparnis/Mehrkosten pro Monat, Amortisationsjahr (Vermögenssicht), Gesamtkosten 25 J. (nominal und in heutiger Kaufkraft), Endvermögensdifferenz, Förderung gesamt, CO₂ t/a.

**Stochastische Parameter (MC)**

| Parameter | Verteilung |
|---|---|
| Ausfalljahr Altkessel (V0) | diskret gleichverteilt 2028–2033 |
| Einsparwirkung Stufe 2 / Stufe 3 | Dreieck(−18 %; −25 %; −30 %) / Dreieck(−20 %; −28 %; −33 %) |
| JAZ je Zustand | Dreieck(±0,3 um Basis) |
| Förderung 2033 vorhanden | Bernoulli(0,7) |
| KfW-358-Zins 2030 / 2033 | N(2,75 %; 0,75 Pp), trunkiert [1 %; 5 %] |
| Baupreisindex | N(3,0 %; 1,2 Pp) |
| Habenzins | N(2,5 %; 0,75 Pp) |
| Energiepreise, CO₂, Netzentgelt, Bio | Defaults |

**Prüfwerte**

| Nr. | Größe | Erwartung |
|---|---|---|
| S4-T1 | Effektives zvE / Einkommensbonus | 48.000 € / 10 % |
| S4-T2 | KfW-458-Zuschuss | 15.680,00 € |
| S4-T3 | Ausführungskosten 2030 / 2033 | 85.988,87 € / 55.405,82 € |
| S4-T4 | BAFA 2030 / 2033 (Default-Methode) | 10.500,00 € / 9.581,16 € |
| S4-T5 | WP-Strom je Zustand | 7.434,48 / 5.053,13 / 3.326,40 kWh |
| S4-T6 | Energie + Wartung V0 vs. V1 Zustand 1 (Preisbasis 2026) | 3.542,50 € vs. 2.174,28 € → Ersparnis 114,02 €/Monat |
| S4-T7 | KfW 358 (2030) Zinsen / Annuität | 1.771,00 €/a / 4.188,12 €/a |
| S4-T8 | Regel Klimageschwindigkeitsbonus | Kessel Bj. 2008 statt 2005 (18 J.) → Bonus 0 % → Zuschuss 40 % × 28.000 = 11.200 € |
| S4-T9 | Regel Antragsdatum | Antrag 02/2027 → Bonus 12 %, förderfähig 27.250 € → 52 % × 27.250 = 14.170,00 € |

---

### 4.5 S5 – Selbstnutzer Neubau EFH: EH 40 mit KfW 300 vs. GModG-Standard mit KfW 297 (EH-55-Stufe)

**Steckbrief**

| Merkmal | Wert |
|---|---|
| Persona | (e) |
| Horizont | 30 Jahre: 2027–2056; Bauzeit 03–12/2027, Bezug 01.01.2028 |
| Referenzvariante | V1 GModG-Standard (≈ EH 55) |
| Pflichtvarianten | V1, V2 |
| Optional | V1b Standard ohne KfW (EH-55-Stufe ausgelaufen), V3 EH 40 + QNG (KfW 300 Stufe 2: 220.000 €), V2b EH 40 ohne KfW-300-Berechtigung (KfW 297 Standard 100.000 € zu 2,94 %) |

**Haushalt und Grundstück**

| Parameter | Wert | Q/A |
|---|---|---|
| Haushalt | 2 Erwachsene, 2 Kinder (4 und 7 J.); zvE Ø 2023/2024 85.000 € ≤ 100.000 € → **KfW-300-berechtigt** | A, [Q7] |
| Nettoeinkommen inkl. Kindergeld | 6.300 €/Monat | A |
| Miete bis Einzug | 1.250 €/Monat warm (2027, beide Varianten) | A |
| Grundstück | 500 m² × 300 €/m² = 150.000 € + 10 % Erwerbsnebenkosten = 165.000 € | A |
| Haus | 140 m² Wfl., Massivbau ohne Keller, Luft/Wasser-WP, PV 8 kWp (beide Varianten) | A |

**Investitionskosten (Festpreis-Bauvertrag 2027, brutto)**

| Position | V1 Standard (≈ EH 55) | V2 EH 40 + LCA |
|---|---|---|
| Grundstück inkl. NK | 165.000 € | 165.000 € |
| Bauwerk KG 300+400 (3.000 €/m²) | 420.000 € | 420.000 € + 6 % EH-40-Mehrkosten (Dämmung, Fenster, Lüftung mit WRG) = 445.200 € |
| Baunebenkosten KG 700 (12 % von 420.000 €) | 50.400 € | 50.400 € + LCA/EEE 3.000 € |
| Hausanschlüsse KG 200 | 20.000 € | 20.000 € |
| Außenanlagen KG 500 | 25.000 € | 25.000 € |
| Küche KG 600 | 15.000 € | 15.000 € |
| PV 8 kWp | 11.000 € | 11.000 € |
| **Summe** | **706.400 €** | **734.600 €** (Mehrkosten 28.200 €) |

**Finanzierung (monatliche Raten)**

| Parameter | V1 | V2 |
|---|---|---|
| EK | 180.000 € | 180.000 € |
| Förderkredit | **KfW 297 EH-55-Stufe** 100.000 € (35/5/10, Sollzins 2,19 %; Antrag bis 31.12.2026, Baugenehmigung vorhanden) | **KfW 300** 170.000 € (35/5/10, Sollzins 1,00 %) |
| Bankdarlehen | 426.400 € (4,10 % Soll, 10 J. fest, 2 % Anfangstilgung) | 384.600 € (gleiche Konditionen) |
| Rate Bank | 2.167,53 €/Monat | 1.955,05 €/Monat |
| Rate KfW Jahre 1–5 (nur Zins) | 182,50 €/Monat | 141,67 €/Monat |
| Rate KfW Jahre 6–10 (Annuität 30 J.) | 379,19 €/Monat | 546,79 €/Monat |
| **Summe Raten Jahre 1–5 / 6–10** | **2.350,03 € / 2.546,73 €** | **2.096,72 € / 2.501,84 €** |
| Restschuld nach 10 J. (Bank / KfW) | 321.201 € / 87.540 € | 289.714 € / 145.085 € |
| Anschluss 2037 | Bank und KfW zu 4,00 % (Basis), Annuität auf Restlaufzeit (Ziel: Volltilgung bis 2062) | gleich |
| Bereitstellungszinsen Bank | 0,25 %/Monat ab Monat 7 auf nicht abgerufene Beträge (A) | gleich |

**Betrieb**

| Parameter | V1 | V2 |
|---|---|---|
| Nutzwärme (Heizung + TWW) | 50 kWh/m²·a = 7.000 kWh | 35 kWh/m²·a = 4.900 kWh |
| JAZ | 3,5 → 2.000 kWh_el | 3,8 → 1.289 kWh_el + Lüftung 400 kWh |
| Haushaltsstrom | 3.500 kWh | 3.500 kWh |
| PV | 8 kWp × 950 kWh/kWp = 7.600 kWh; Eigenverbrauch 35 %; Einspeisung zu 7,55 ct (IBN 12/2027, −1 % je Halbjahr; MC: EEG-Reform) | gleich (Eigenverbrauch 33 %) |
| Wartung | WP 250 €/a, PV 150 €/a | WP 250 €/a, PV 150 €/a, Lüftungsfilter 120 €/a |
| Grundsteuer + Versicherung | 1.600 €/a | 1.600 €/a |
| Instandhaltungsrücklage | 10 €/m²·a = 1.400 €/a | 1.400 €/a |

**Restwert 2056:** Sachwert vereinfacht = Bodenwert (150.000 € × 1,015²⁹) + Gebäudeherstellungskosten (KG 200–500, 700, PV; ohne Küche) × Baupreisindex × (1 − 28/80); Marktanpassungsfaktor 1,0; V2 zusätzlich +3 % Effizienzzuschlag auf den Gebäudewert (MC Gleich(0 %; 6 %)). Pflichtausweis auch ohne Restwert.

**Erwartetes qualitatives Ergebnis (Hypothesen)**

1. **V2 dominiert V1**, solange KfW 300 erreichbar ist: geringere Monatsrate in den Jahren 1–5 (−253 €/Monat) und 6–10 (−45 €/Monat) und höherer Restwert; die Mehrkosten von 28.200 € werden über den Zinsvorteil (170.000 € zu 1,00 % statt Bank 4,10 %) mehr als ausgeglichen. **Die Betriebskosten sind dagegen nahezu gleich** (überschlägig V1 ≈ 1.080 €/a, V2 ≈ 1.130 €/a inkl. Wartung, PV-Eigenverbrauch und Einspeisung): Lüftungsstrom (400 kWh) und Filterwechsel zehren die WP-Stromeinsparung (≈ 710 kWh) weitgehend auf. Das ist eine typische, für Laien kontraintuitive Aussage, die der Bericht erklären muss („EH 40 lohnt sich hier wegen der Förderung, nicht wegen der Energiekosten“).
2. Ohne KfW-300-Berechtigung (V2b) ist V1 mit EH-55-Stufe günstiger; nach Auslaufen der EH-55-Stufe (V1b) wird V2b wieder konkurrenzfähig → Förderlogik mit Berechtigungsprüfung ist zwingend.
3. **Belastungsquote** (Rate + Nebenkosten ≈ 2.650 €/Monat bzw. 2.400 €/Monat) liegt bei ca. 38–42 % → Warnung im Bericht (Schwelle 40 %).
4. Zinsänderungsrisiko 2037: bei Anschlusszins 6 % steigt die Rate um mehrere hundert €/Monat → Fächerdiagramm.

**KPIs:** Monatsrate je Phase, Belastungsquote, Restschuld bei Zinsbindungsende, monatliche Wohnkosten (Rate + Energie + Nebenkosten), Differenz-Endvermögen, Mehrkosten vs. Fördervorteil (Barwert), P(V2 besser), Anschlussraten-Verteilung 2037.

**Stochastische Parameter (MC)**

| Parameter | Verteilung |
|---|---|
| Anschlusszins 2037 | Vasicek (Default), Quantile 5/50/95 % ausweisen |
| Mehrkosten EH 40 | Dreieck(3 %; 6 %; 10 %) der Bauwerkskosten |
| Nutzwärme V1 / V2 | Dreieck(40; 50; 60) / Dreieck(28; 35; 45) kWh/m²·a |
| Einspeisevergütung | Bernoulli(0,5): 7,55 ct vs. 0 ct (EEG-Reform für < 25 kWp) |
| Effizienzzuschlag Restwert V2 | Gleich(0 %; 6 %) |
| Strompreis | Default |

**Prüfwerte**

| Nr. | Größe | Erwartung |
|---|---|---|
| S5-T1 | Gesamtkosten V1 / V2 | 706.400 € / 734.600 € |
| S5-T2 | KfW-300-Berechtigung | zvE 85.000 € ≤ 100.000 € (2 Kinder) → ja; Höchstbetrag Stufe 1: 170.000 € |
| S5-T3 | Negativtest | zvE 105.000 € → nicht berechtigt → Fehlermeldung bzw. Fallback V2b |
| S5-T4 | Monatsraten Jahre 1–5 V1 / V2 | 2.350,03 € / 2.096,72 € |
| S5-T5 | Monatsraten Jahre 6–10 V1 / V2 | 2.546,73 € / 2.501,84 € |
| S5-T6 | Restschuld Bank nach 120 Monaten V1 | 321.201 € (±1 €) |
| S5-T7 | KfW-Annuität V2 ab Monat 61 | 546,79 €/Monat |

---

### 4.6 Optionales S6 (Skizze) – Privater Kleinvermieter, 6-WE-MFH

Nur als Platzhalter für Persona (c), nicht vollständig spezifiziert, weil das Ergebnis ohne Ertragsteuern (v2) irreführend sein kann.

| Parameter | Skizze |
|---|---|
| Gebäude | MFH 1958, 6 WE, 420 m² Wfl., Gas-Zentralheizung 1999, Einzelmieten 6,10–8,40 €/m² (Mieterliste → Kappung je WE: 2 € bzw. 3 €) |
| Varianten | V1 Gas-BW (Ohnehin, ab 2028 § 5a-Kosten), V2 WP (KfW 458 Grundförderung 30 %, § 559e), V3 WP + Fassade (§ 559 + § 559e kombiniert, Kappungsinteraktion) |
| Horizont | 15 Jahre (2027–2041), Restwert über Vervielfältiger |
| Finanzierung | Hausbank 4,10 %, KfW 359 4,62 % (25/3/10) |
| Kernfrage | „Muss ich monatlich zuschießen?“ → Haushaltsmodus mit Cashflow pro Monat; Steuerhinweis prominent |

---

## 5. Ausgabeanforderungen je Persona und „Verständlichkeit“

### 5.1 Einheitlicher Berichtsaufbau (beide Modi)

| Nr. | Abschnitt | Fachmodus (a, b) | Haushaltsmodus (c, d, e) |
|---|---|---|---|
| 1 | **Ergebnis auf einen Blick** | Ampel, Differenz-Endwert (mit/ohne Restwert), VoFi-EK-Rendite je Variante, P(Variante besser), Warmmietenänderung €/m² | Ampel, „Sie sparen/zahlen mehr … € pro Monat“, Amortisationsjahr, Gesamtersparnis nach N Jahren, Bandbreite in Worten |
| 2 | Variantenvergleich | Tabelle aller Varianten mit KPIs, Rangfolge | Tabelle mit 4–6 Kennzahlen, Klartext je Variante |
| 3 | Zeitverläufe | Vermögens-/Kontostandsverlauf, Cashflow nach Kategorien, DSCR | Monatliche Belastung je Jahr, kumulierte Ersparnis |
| 4 | Finanzierung und Förderung | Darlehensübersicht, Tilgungspläne, Restschulden zum Zinsbindungsende, Förderbarwert | Kreditraten je Phase, Restschuld, Förderbeträge und Auszahlungsjahre |
| 5 | Miete und Umlage (nur Vermietung) | Umlageberechnung (rechnerisch → Kappung → angesetzt), Miet- und Warmmietenpfad, Härtefälle | Zulässige Mieterhöhung je Wohnung (Kleinvermieter) |
| 6 | Energie und CO₂ | Verbrauch je Energieträger, CO₂ t/a, Vermieteranteil CO₂KostAufG/§ 5a, CO₂-Vermeidungskosten | Energiekosten pro Monat, CO₂ t/a |
| 7 | Risiko | MC-Verteilung, Fächerdiagramm, Tornado, Szenariotabelle, Konvergenz | „In X von 10 simulierten Zukünften …“, einfacher Fächer, die 3 wichtigsten Einflussgrößen in Worten |
| 8 | Annahmenprotokoll | alle Parameter mit Quelle, Stand, Override-Kennzeichnung | verkürzt: wichtigste Annahmen + Hinweis auf Vollprotokoll |
| 9 | Anhang | vollständige VoFi-Tabellen je Variante (Grob-Schema), Export Excel/CSV | optional VoFi-Tabelle |
| 10 | Hinweise | Haftungs- und Rechtshinweis, Steuern nicht berücksichtigt | dito, deutlich sichtbar |

### 5.2 Persona-spezifische Pflichtinhalte

| Persona | Pflichttabellen | Pflichtgrafiken | Besondere Berichtsteile |
|---|---|---|---|
| (a) WU | VoFi je Variante; KPI-Vergleich; Umlage/Kappung; DSCR/LTV je Jahr; Förderübersicht | Differenzvermögen mit Amortisationsmarker; Warmmietenpfad; MC-Dichte mit P(> 0); Tornado | Entscheidungsvorlage für Aufsichtsrat (2–4 Seiten), Break-even-Miete, CO₂-Vermeidungskosten, Sensitivität Restwert |
| (b) Genossenschaft | Nutzungsentgelt- und Warmmietentabelle (Mitglieder); Kostendeckung; Liquidität | Warmmietenpfad beider Varianten; Liquiditätsverlauf | Zwei-Perspektiven-Seite „Genossenschaft / Mitglieder“ |
| (c) Kleinvermieter | Monatlicher Cashflow je Jahr; zulässige Mieterhöhung je WE | Kontostand über Zeit; monatlicher Zuschuss/Überschuss | Steuerwarnhinweis, einfache Risikoaussage |
| (d) Selbstnutzer Bestand | Monatliche Belastung je Variante (Energie, Kredit, Wartung); Förderung je Stufe | Balken „Monatliche Belastung“ je Jahr; kumulierte Ersparnis; Zeitstrahl der Stufen | Klartext-Fazit, „Was passiert, wenn …“ (Gaspreis, Förderstopp, Kesselausfall) |
| (e) Selbstnutzer Neubau | Raten je Phase; Belastungsquote; Restschuld; Mehrkosten vs. Fördervorteil | Fächerdiagramm Rate nach 2037; Restschuldverlauf | Förderberechtigungs-Check (Einkommen, Kinder, Standard, Fristen) |

### 5.3 Grafikkatalog

| Grafik | Zweck | Personas |
|---|---|---|
| Vermögens-/Kontostandsverlauf je Variante (Linie) | VoFi-Endwert-Entstehung sichtbar machen | alle |
| Differenzvermögen Variante − Referenz mit Markierung des Amortisationsjahres | „Ab wann lohnt es sich?“ | alle |
| Gestapelte Balken Ein-/Auszahlungen nach Kategorien je Jahr | Treiber erkennen | a, b, c |
| Monatliche Belastung je Jahr (gestapelt: Zinsen, Tilgung, Energie, Wartung) | Haushaltsbudget | c, d, e |
| Miet-/Warmmietenpfad in €/m²·Monat | Sozialverträglichkeit | a, b |
| Restschuld und Tilgungsplan (Fläche) | Finanzierungsrisiko | a, e |
| MC-Dichte/Histogramm der Endwertdifferenz mit Anteil > 0 | Robustheit | a, b, d, e |
| Fächerdiagramm (Quantile 5/25/50/75/95 %) über die Zeit | Unsicherheit im Zeitverlauf | alle |
| Tornado (P10/P90 je Parameter) | wichtigste Einflussgrößen | a, b, (d) |
| Zeitstrahl der Maßnahmen | gestufte Sanierung | d, a |
| CO₂-Emissionen je Variante (t/a) | Klimapfad | a, b, d |

### 5.4 Was heißt „verständlich“ für Nicht-Finanzleute?

**Grundregeln**

1. **Monatswerte statt Jahreswerte, Euro statt Prozent.** Haushalte denken in „€ pro Monat“; Wohnungswirtschaft in „€ pro m² Wohnfläche und Monat“.
2. **Liquidität und Vermögen getrennt zeigen.** Tilgung ist keine Ausgabe im Sinne von „Kosten“, sondern Vermögensaufbau. Darum zwei Sichten: „Was geht monatlich vom Konto ab?“ (Liquidität) und „Wie viel besitze ich am Ende mehr?“ (Vermögen).
3. **Bandbreiten in Worten.** Statt „Median 112 €, P10 60 €, P90 170 €“: „Voraussichtlich rund 110 € pro Monat; in 8 von 10 simulierten Zukünften zwischen 60 € und 170 €.“
4. **Keine Scheingenauigkeit.** Monatswerte auf 5 bzw. 10 € runden, Summen auf 100 €; Prozentangaben auf ganze Prozent (Haushaltsmodus).
5. **Wörter statt Vorzeichen.** „Sie sparen 45 € pro Monat“ bzw. „Sie zahlen 30 € pro Monat mehr“ – nie „−45 €“.
6. **Nominal und „in heutiger Kaufkraft“.** Default im Haushaltsmodus: nominal mit umschaltbarer Kaufkraftsicht (Division durch VPI-Index); im Bericht stets kennzeichnen.
7. **Annahmen sichtbar, aber nachrangig.** Die drei einflussreichsten Annahmen (aus Tornado) im Fazit nennen: „Das Ergebnis hängt vor allem vom Gaspreis, vom CO₂-Preis ab 2028 und vom Zins nach 2037 ab.“

**Definitionen (für Bericht und Glossar)**

| Begriff (Label) | Definition | Hinweis zur Darstellung |
|---|---|---|
| **Monatliche Belastung** (`monthly_burden`) | (Zinsen + Tilgung + Energiekosten + Wartung/Schornsteinfeger + sonstige variantenabhängige laufende Kosten − Einspeiseerlöse) / 12, je Kalenderjahr; Investitionen aus Eigenmitteln und Zuschüsse werden **nicht** in die Monatsbelastung eingerechnet, sondern als Einmalbeträge ausgewiesen | zusätzlich Variante „ohne Tilgung“ (Kostensicht) |
| **Mehrkosten / Ersparnis pro Monat** (`monthly_difference`) | Monatliche Belastung (Variante) − Monatliche Belastung (Referenz) im selben Jahr | Zeitreihe; im Fazit Durchschnitt der ersten 10 Jahre und Wert im Jahr 1 |
| **Amortisationsjahr** (`payback_year_wealth`) | Erstes Jahr t*, ab dem die Vermögensdifferenz ΔV(t) = [Guthaben − Restschulden](Variante) − [Guthaben − Restschulden](Referenz) dauerhaft ≥ 0 ist; optional inkl. Zeitwert der Maßnahmen | Berücksichtigt Zinsen, Förderung und Preissteigerungen – nicht vergleichbar mit der „statischen Amortisation“ aus Handwerkerangeboten; „keine Amortisation im Betrachtungszeitraum“ explizit ausweisen |
| Liquiditäts-Amortisation (`payback_year_cash`) | Erstes Jahr, ab dem die kumulierte Differenz der Zahlungen dauerhaft ≥ 0 ist | nur Fachmodus |
| Gesamtkosten über N Jahre | Summe aller variantenabhängigen Auszahlungen abzüglich Zuschüsse und Erlöse, nominal und als Barwert | Haushaltsmodus |
| Endvermögen / Vermögensdifferenz | VoFi-Endwert (Guthaben − Schulden + optional Restwert) bzw. Differenz zur Referenz | Ausweis mit und ohne Restwert |
| VoFi-EK-Rendite | Zinssatz, zu dem das eingesetzte Eigenkapital auf den VoFi-Endwert anwächst | Fachmodus |
| Warmmiete | Nettokaltmiete + Modernisierungsumlage + Heiz-/Warmwasserkosten + sonstige Betriebskosten (€/m²·Monat) | WU/Genossenschaft |
| Belastungsquote | (Kreditrate + Wohnnebenkosten) / Haushaltsnettoeinkommen | Warnung > 40 % |

**Ampelregel (Vorschlag, konfigurierbar):** Grün: Median der Vermögensdifferenz > 0 und P(besser als Referenz) ≥ 70 %; Gelb: P zwischen 40 % und 70 %; Rot: P < 40 %. Ohne MC: Grün bei Differenz > 0 in Basis- und pessimistischem Szenario.

**Beispiel-Fazit (S4, Formulierungsmuster):**
> „Wenn Sie 2027 eine Wärmepumpe einbauen, zahlen Sie für Heizung und Wartung im ersten Jahr voraussichtlich rund 115 € pro Monat weniger als mit Ihrer Gasheizung. Nach Abzug von 15.680 € Zuschuss haben sich die Mehrkosten gegenüber einem neuen Gaskessel voraussichtlich nach etwa vier bis fünf Jahren bezahlt gemacht. Die zusätzlichen Dämmmaßnahmen 2030 und 2033 erhöhen Ihre monatliche Belastung während der Kreditlaufzeit; über 25 Jahre stehen Sie mit dem Gesamtpaket voraussichtlich etwas schlechter da als mit der Wärmepumpe allein, aber etwa gleich gut wie mit der Gasheizung – und Ihr Haus ist deutlich unabhängiger von Gas- und CO₂-Preisen. Am stärksten hängt das Ergebnis vom CO₂-Preis ab 2028 ab.“ *(Muster; die Zahlen sind Hypothesen und werden vom Tool erzeugt.)*

### 5.5 Label-Mapping (Auszug: Schlüssel → deutsches Label)

| Schlüssel | Label |
|---|---|
| `terminal_value` | VoFi-Endwert |
| `terminal_value_diff` | Vermögensdifferenz zur Referenz |
| `equity_return_vofi` | VoFi-Eigenkapitalrendite |
| `monthly_burden` | Monatliche Belastung |
| `monthly_difference` | Mehrkosten/Ersparnis pro Monat |
| `payback_year_wealth` | Amortisationsjahr |
| `dscr` | Kapitaldienstdeckungsgrad |
| `warm_rent_per_m2` | Warmmiete je m² und Monat |
| `modernisation_levy` | Modernisierungsumlage |
| `co2_landlord_share` | CO₂-Kostenanteil Vermieter |
| `residual_value` | Restwert |
| `prob_better_than_ref` | Wahrscheinlichkeit „besser als Referenz“ |

---

## 6. Ableitungen für Eingabeschema und Tests

### 6.1 Beispiel-YAML (Skizze) für S4

Die Skizze verwendet die Grammatik aus Memo 05 (Abschnitte 4.2–4.4: `project`, `building`, `measures`, `funding`, `financing`, `accounts`, `market`, `stochastic`-Overlay, `variants` mit `extends`/`remove`/`overrides`). Felder, die dort noch nicht definiert sind und von den Referenzszenarien benötigt werden, sind mit `# neu` markiert. Die Basisdatei beschreibt die energetische Variante V1; die Referenz V0 entsteht als Variante durch Entfernen und Ergänzen.

```yaml
schema_version: 1
meta:
  scenario_id: s4_efh_1975_isfp
  title: "S4 – Selbstnutzer EFH Baujahr 1975: stufenweise Sanierung nach iSFP"
  created_date: 2026-10-25
project:
  perspective: selbstnutzer                # Codes nach Memo 02
  project_type: sanierung_stufenweise
  comparison_mode: absolute                # Total-VoFi je Alternative
  valuation_date: 2027-01-01
  horizon_years: 25
  legal_state: 2026-10-25
  price_base_year: 2026
  reference_variant: v0_gas_behalten       # neu
  report_mode: household                   # neu: Haushaltsmodus
building:
  building_type: EFH
  construction_year: 1975
  n_units: 1
  living_area_m2: 140
  component_areas_m2: {roof: 160, windows: 28, facade: 180, basement_ceiling: 75}   # neu
  heating_existing: {carrier: erdgas_efh, installation_year: 2005, efficiency: 0.88} # neu
  consumption_kwh: {erdgas_efh: 24500}     # neu: gemessener Verbrauch (H_s), Ø 3 Jahre
household:                                 # neu: Förderberechtigung
  taxable_income_avg_eur: 58000            # Ø 2. und 3. Vorjahr
  n_children_u18: 1
  net_income_month_eur: 4800

measures:
  wp_2027:
    label: "Luft/Wasser-Wärmepumpe 10 kW"
    year: 2027                              # neu: Ausführungsjahr
    cost_eur: 32000
    price_base_year: 2026
    useful_life_years: 20
    effects: {heating: {carrier: wp_strom_efh, jaz: 2.9}}                      # neu
    replaces_ohnehin: [gaskessel_2030]     # neu: Verknüpfung zur Ohnehin-Maßnahme
  dach_fenster_2030:
    label: "Dach (Aufsparrendämmung) und Fenster 3-fach"
    year: 2030
    cost_eur: {expr: "building.component_areas_m2.roof * 320 + building.component_areas_m2.windows * 900"}
    price_base_year: 2026
    useful_life_years: 45
    effects: {heat_demand_factor: 0.75, jaz: 3.2}
    replaces_ohnehin: [dach_ohnehin_2032, fenster_ohnehin_2042]
  fassade_2033:
    label: "WDVS 16 cm, Kellerdecke, Gerüst"
    year: 2033
    cost_eur: {expr: "building.component_areas_m2.facade * 210 + building.component_areas_m2.basement_ceiling * 50 + 3500"}
    price_base_year: 2026
    useful_life_years: 40
    effects: {heat_demand_factor: 0.72, jaz: 3.5}
    replaces_ohnehin: [anstrich_2033]
  wp_ersatz_2047:
    label: "WP-Ersatz"
    year: 2047
    cost_eur: 25000
    price_base_year: 2026
    useful_life_years: 20

funding:
  kfw458_wp:
    from: funding/kfw_458_2026-07-21       # Regelobjekt mit Stichtag
    measure: wp_2027
    application_date: 2026-12-15           # entscheidet über Bonus 16 % und 28.000 €
    payout_delay_years: 1
  bafa_huelle_2030:
    from: funding/bafa_beg_em_huelle_2026-07-21
    measure: dach_fenster_2030
    isfp: true
    isfp_bonus_mode: excess_over_threshold # Alternative: whole_amount
    payout_delay_years: 1
  bafa_huelle_2033:
    from: funding/bafa_beg_em_huelle_2026-07-21
    measure: fassade_2033
    isfp: true
    isfp_bonus_mode: excess_over_threshold
    payout_delay_years: 1

financing:
  ek:
    type: equity
    amount_eur: 60000
  kfw358_2030:
    type: annuity_loan
    program: kfw_358
    start_year: 2030                        # neu: Darlehen in späterer Periode
    amount_eur: 70000
    term_years: 25
    grace_years: 3
    fixed_years: 10
    rate_pa: 0.0253
    followup_rate_pa: {ref: market.mortgage_rate}
  kfw358_2033:
    type: annuity_loan
    program: kfw_358
    start_year: 2033
    amount_eur: 45000
    term_years: 25
    grace_years: 3
    fixed_years: 10
    rate_pa: 0.0253
    followup_rate_pa: {ref: market.mortgage_rate}

running_costs:                              # neu: benutzerdefinierte Zahlungsreihen
  wartung_wp: {label: "Wartung Wärmepumpe", amount_eur: 250, growth: {ref: market.inflation}}

accounts:
  deposit_rate_pa: 0.025
  overdraft_rate_pa: 0.060
market:
  inflation: {series: {2027: 0.028, 2028: 0.022}, fill: locf}
  construction_price_index: 0.030
  mortgage_rate: 0.040
  co2_price: {from: prices/co2_price_paths_2026, use: mittel}
  energy_prices: {from: prices/energy_2026-10}           # Gas zerlegt: Netz, CO2, Rest
  bio_step: {from: legal/building_energy_law_2026-07}    # Bio-Treppe § 43 GModG
residual_value: {method: linear_book_value, report_without: true}   # neu

stochastic:
  settings: {n_sim: 10000, seed: 20261025, sampling: lhs, copula: iman_conover}
  parameters:
    jaz_stufe1:     {target: measures.wp_2027.effects.heating.jaz, dist: pert, min: 2.6, mode: 2.9, max: 3.3}
    foerderung_2033: {target: funding.bafa_huelle_2033.available, dist: bernoulli, p: 0.7}   # neu
    zins_358_2030:  {target: financing.kfw358_2030.rate_pa, dist: truncnorm, mean: 0.0275, sd: 0.0075, min: 0.01, max: 0.05}
  processes:
    mortgage_rate:  {target: market.mortgage_rate, from: processes/mortgage_rate_vasicek_2026}
    co2_price:      {target: market.co2_price, from: prices/co2_price_paths_2026}

variants:
  v1_isfp_stufen:
    label: "iSFP stufenweise: WP 2027, Dach + Fenster 2030, Fassade 2033"
    extends: base
  v0_gas_behalten:
    label: "Referenz: Gaskessel behalten, Ersatz bei Ausfall"
    extends: base
    remove: [measures.wp_2027, measures.dach_fenster_2030, measures.fassade_2033, measures.wp_ersatz_2047,
             funding.kfw458_wp, funding.bafa_huelle_2030, funding.bafa_huelle_2033,
             financing.kfw358_2030, financing.kfw358_2033, running_costs.wartung_wp]
    overrides:
      measures:
        gaskessel_2030:
          label: "Gas-Brennwertkessel nach Ausfall"
          year: {dist: discrete, values: [2028, 2029, 2030, 2031, 2032, 2033]}   # Basis 2030
          cost_eur: 12500
          price_base_year: 2026
          useful_life_years: 20
          effects: {heating: {carrier: erdgas_efh, efficiency: 0.94, section43_new_fossil: true}}
        dach_ohnehin_2032:
          label: "Dach-Neueindeckung mit GModG-Mindestdämmung"
          year: 2032
          cost_eur: 40000
          price_base_year: 2026
          useful_life_years: 50
          effects: {heat_demand_factor: 0.88}
        anstrich_2033: {label: "Fassadenanstrich inkl. Gerüst", year: 2033, cost_eur: 11600, price_base_year: 2026, useful_life_years: 15}
        fenster_ohnehin_2042:
          label: "Fenstertausch 2-fach"
          year: 2042
          cost_eur: {expr: "building.component_areas_m2.windows * 700"}
          price_base_year: 2026
          useful_life_years: 35
          effects: {heat_demand_factor: 0.95}
        wp_referenz_2050:
          label: "Umstieg Wärmepumpe (Gas nach 2045 nicht mehr sinnvoll)"
          year: 2050
          cost_eur: 32000
          price_base_year: 2026
          useful_life_years: 20
          effects: {heating: {carrier: wp_strom_efh, jaz: 3.0}}
      running_costs:
        wartung_gas: {label: "Wartung und Schornsteinfeger", amount_eur: 300, growth: {ref: market.inflation}, until_year: 2049}
```

**Schemaanforderungen, die sich aus allen Szenarien ergeben (Checkliste):** `payment_schedule` (S2), `rent_roll` je WE (S1, S6), `modernisation_levy`-Block mit `legal_basis` (§ 559/559e), `voluntary_cap_per_m2`, `hardship_share` (S1, S3), `co2_cost_split` mit Heizungs-Einbaudatum (S1, S3), `tenant_perspective: true` (S1, S3), `pv`-Block mit `commissioning_date`, `self_consumption_share`, `internal_transfer_price` (S3, S5), `eligibility`-Prüfung (S5), `loan.subsidy` mit `share_of_amount`, `credit_year`, `effect: term_reduction|payment_reduction` (S1), `residual_value.method: income_value` mit `capitalisation_rate`, `remaining_life_years`, `land_value` (S1, S2), `scenario_overlays` (S2: „EH-55-Stufe nicht verfügbar“).

### 6.2 Testkatalog

| Testart | Inhalt | Szenarien |
|---|---|---|
| Deterministische Prüfwerte | alle S*-T*-Werte aus Abschnitt 4 (Förderbeträge, Kappungen, Annuitäten, Restschulden, Energiemengen) | S1–S5 |
| Regeltests Förderung | Stichtagslogik (Antrag 12/2026 vs. 02/2027), Bonusberechtigung (Kesselalter, Einkommen, Kinder), Deckel (70/80 %, Höchstkosten je WE, je Kalenderjahr), WPB-Bonus, Baubegleitungs-TZ | S1, S3, S4, S5 |
| Regeltests Mietrecht | § 559-Kappung 2 €/3 € je WE, § 559e-Kappung 0,50 €, § 559f-Halbierung, Drittmittelabzug, freiwillige Kappung, Härtefälle | S1, S3, S6 |
| Regeltests CO₂ | Stufenzuordnung, Wechsel auf § 5a ab 2028 nur bei neu eingebauter fossiler Heizung, 30-%-Mengendeckel Bio | S1, S3 |
| VoFi-Invarianten | Kontenidentität je Periode (Anfangsbestand + Einzahlungen − Auszahlungen = Endbestand), Mittelherkunft = Mittelverwendung in t = 0, Restschulden ≥ 0, Darlehen bei Laufzeitende getilgt, gleiches EK-Budget je Variante | alle |
| Metamorphe Tests | Gaspreis ↑ ⇒ Vorteil WP-Variante ↑; TZ ↑ ⇒ Differenz-Endwert ↑; Umlage = 0 ⇒ V2 (S1) schlechter; Restwert ausgeschaltet ⇒ Endwerte sinken; Horizont +1 Jahr ⇒ Zahl der Perioden +1 | S1–S5 |
| Reproduzierbarkeit | gleicher Seed ⇒ identische MC-Ergebnisse; MC mit σ = 0 und θ = r₀ = 4,00 % sowie allen Verteilungen im Modus ⇒ deterministisches Ergebnis | alle |
| Statistische Stabilität | N = 10.000: Median und 5-%-Quantil der Endwertdifferenz zwischen zwei Seeds innerhalb ±1 % bzw. ±2 % | S1, S4 |
| Snapshot-Regression | Kern-KPIs je Szenario als Referenzdatei mit Toleranz; Änderungen nur bewusst (Bibliotheksversion) | alle |

---

## 7. Offene Fragen an den Auftraggeber

1. **Priorität der Zielgruppen für v1:** Zuerst Fachmodus (WU/Genossenschaft) oder Haushaltsmodus (Selbstnutzer)? Das bestimmt Berichtsvorlagen, Default-Parameter und ggf. eine spätere Oberfläche (Shiny).
2. **Steuern:** Bleibt es bei Vor-Steuer-VoFi in v1? Für Kleinvermieter (c) ist das Ergebnis ohne Steuern oft verzerrt – reicht ein deutlicher Warnhinweis, oder soll ein einfaches Steuermodul (Grenzsteuersatz, AfA, Erhaltungsaufwand) in v1.5 kommen?
3. **Eingabeformat:** Nur YAML, oder zusätzlich eine Excel-Eingabevorlage für Controller (Import nach YAML)?
4. **Regionale Defaults:** Sollen Referenzszenarien eine konkrete Region abbilden (z. B. Mittelstadt West, Mietspiegel/Bodenrichtwert/Liegenschaftszins), oder bewusst generisch bleiben?
5. **Genossenschaft:** Soll die Umlage bei Genossenschaften standardmäßig nach §§ 559e/559 laufen oder als frei definierte Nutzungsentgelterhöhung? Default für PV-Stromverrechnung an die Heizkostenabrechnung: 0 ct oder Verrechnungspreis?
6. **Rechtliche Auslegungsfragen (Fachmemo Mietrecht):** Zurechnung der Zinsermäßigung nach § 559a (anteilig/voll); Reihenfolge Halbierung (§ 559f) und Drittmittelabzug; Bedeutung von § 559e Abs. 2 S. 2 für fossile Heizungen; Zurechnung von Zuschüssen auf Modernisierungs- vs. Erhaltungsanteil.
7. **Förderauslegung (Fachmemo Förderung):** iSFP-Bonus nur auf den 30.000 € übersteigenden Betrag oder auf den Gesamtbetrag? Staffel der förderfähigen Kosten bei KfW 459 identisch mit 458? TZ-Verrechnung bei KfW 261 (Laufzeitverkürzung als Default korrekt?).
8. **Default-Restwertmethode je Persona:** Ertragswert (WU), Komponentenzeitwert (Heizungstausch), Sachwert (EFH) – einverstanden?
9. **„Nichtstun“-Logik:** Sollen gesetzlich erzwungene Ereignisse (Bio-Treppe, 2045 klimaneutrale Brennstoffe, bedingte Bauteilanforderungen) automatisch aus der Bibliothek in Referenzvarianten eingesteuert werden, oder bleibt das Nutzereingabe mit Warnung?
10. **Periodik:** Reicht jährliche VoFi auch für Bauphasen und Haushalte (Monatswerte nur abgeleitet)?
11. **MC-Defaults:** Wer verantwortet die Default-Verteilungen? Sollen zusätzlich Presets („vorsichtig/Basis/optimistisch“) angeboten werden?
12. **Bibliothekspflege:** Wer aktualisiert Förder- und Preisbibliotheken zu den absehbaren Stichtagen (01.02. und 01.08. jedes Jahres bei KfW 458/459, Q1/2027 WP-Förderung, EEG-Reform 2027, BEHG 2027, ETS 2 ab 2028)?
13. **Portfolio in v2** – bestätigt? Reicht in v1 der Batch-Lauf mit Summenzeile?
14. **Ersatzneubau (S1-V4) und Landesförderung (S2-V3):** in v1-Integrationstests aufnehmen oder nur als Beispiel?
15. **Mieterperspektive:** Genügt die abgeleitete Warmmietentabelle, oder wird eine vollständige Mieter-VoFi gewünscht?

---

## 8. Risiken

| Risiko | Wirkung | Gegenmaßnahme |
|---|---|---|
| **Hohe Volatilität von Förderung und Recht** (Reform 21.07.2026, Degression ab 01.02.2027, WP-Förderung Q1/2027, EEG-Reform, BEHG 2027 noch nicht verabschiedet, ETS 2 ab 2028, GModG-Folgeverordnungen) | Veraltete Parameter führen zu falschen Empfehlungen | Regelobjekte mit Gültigkeitszeitraum und Stichtag; Warnung bei abgelaufener Bibliothek; Szenario „Förderstopp“ |
| **Sekundärquellen** für Teile der Rahmendaten (Ratgeberportale) | Fehlerhafte Prüfwerte | Primärtext-Verifikation vor Freigabe der Bibliothek; Prüfwerte an Bibliotheksversion koppeln |
| **Restwertdominanz** bei 30–40 Jahren | Vorzeichen des Ergebnisses hängt an RND/LZ | Pflichtausweis ohne Restwert; Tornado; MC auf RND/LZ |
| **Doppelzählungen** (Instandhaltungspauschale vs. Ersatzinvestition; Leerstand vs. Mietausfallwagnis; Ohnehin in Variante und als Anteil) | Verzerrte Vorteilhaftigkeit | Validierungsregeln (A-25), klare Kategorien, Konsistenzchecks |
| **Prebound-/Rebound-Effekt** | Überschätzte Einsparungen bei Rechnung aus Bedarfsausweis | Verbrauchsbasierte Defaults, Prebound-Faktor, Warnung |
| **Fehlinterpretation durch Laien** (Tilgung als Kosten, statische Amortisation, Scheingenauigkeit) | Falsche Entscheidungen | Haushaltsmodus mit Liquiditäts- und Vermögenssicht, Bandbreiten, Klartext, Glossar |
| **Ausklammerung der Ertragsteuern** | Verzerrung v. a. für Kleinvermieter | Warnhinweis; Steuer-Hook im Datenmodell; v2 |
| **Subjektive MC-Verteilungen und Korrelationen** | Scheinbare Objektivität der Wahrscheinlichkeiten | Dokumentierte Defaults, Presets, Sensitivität der Ergebnisse auf Verteilungswahl, Common Random Numbers |
| **Komplexität von Förder- und Mietrechtslogik** | Hoher Implementierungs- und Testaufwand, Scope Creep | Modulare Regel-Engine, v1 auf die Regeln der Referenzszenarien beschränken |
| **Datenschutz** (Einkommen, Kinderzahl) | Personenbezogene Daten | lokale Verarbeitung, keine Übermittlung, Hinweis im Bericht |
| **Haftung** | Nutzer verstehen Ergebnis als Rechts-/Steuer-/Förderberatung | Haftungsausschluss, Verweis auf Energieberatung/EEE und Förderbank |

---

## 9. Quellen (abgerufen am 25.10.2026)

- [Q1] KfW Konditionen-Anzeiger, Stand 22.10.2026: https://www.kfw-formularsammlung.de/KonditionenanzeigerINet/KonditionenAnzeiger
- [Q2] KfW Partnerportal, Wohngebäude-Kredit (261): https://www.kfw.de/partner/KfW-Partnerportal/Multiplikatoren/F%C3%B6rderprodukte/Wohngeb%C3%A4ude-Kredit-%28261%29/index.jsp
- [Q3] 42watt, KfW 261 und 262 (Stand 01.09.2026, Sekundärquelle): https://42watt.de/magazin/kfw-261-und-262
- [Q4] KfW, Klimafreundlicher Neubau Wohngebäude (297/298): https://www.kfw.de/inlandsfoerderung/Privatpersonen/Neubau/F%C3%B6rderprodukte/Klimafreundlicher-Neubau-Wohngeb%C3%A4ude-(297-298)/
- [Q5] KfW, Pressemitteilung vom 27.02.2026 (Zinssenkung Neubau, EH 55 Signalzins): https://www.kfw.de/%C3%9Cber-die-KfW/Newsroom/Aktuelles/Pressemitteilungen-Details_883456.html
- [Q6] KfW, Pressemitteilung vom 19.06.2026 (Verlängerung EH 55 bis 31.12.2026): https://www.kfw.de/About-KfW/Newsroom/Latest-News/Pressemitteilungen-Details_898560.html; Haustechnikdialog: https://www.haustechnikdialog.de/News/31604/Bund-und-KfW-verlaengern-Foerderung-fuer-Effizienzhaus-55-Neubauten
- [Q7] KfW, Wohneigentum für Familien (300): https://www.kfw.de/inlandsfoerderung/Privatpersonen/Neubau/F%C3%B6rderprodukte/Wohneigentum-f%C3%BCr-Familien-(300)/
- [Q8] KfW 458 ab 21.07.2026 (Sekundärquellen): https://reduco.ai/blog/kfw-458-heizungstausch; https://www.cleanthinking.de/heizungsfoerderung/; https://www.steuertipps.de/wohnen-haus-vermietung/kfw-heizungsfoerderung-uebergangsfrist-bis-20-juli-2026-nutzen
- [Q9] KfW, Heizungsförderung für Unternehmen – Wohngebäude (459): https://www.kfw.de/inlandsfoerderung/Unternehmen/Wohnwirtschaft/F%C3%B6rderprodukte/Heizungsf%C3%B6rderung-f%C3%BCr-Unternehmen-Wohngeb%C3%A4ude-%28459%29/
- [Q10] BAFA BEG EM Gebäudehülle nach 21.07.2026 (Sekundärquellen): https://reduco.ai/blog/foerderung/sanierung-einzelmassnahmen-21-juli-2026-aenderungen; https://www.schwaebisch-hall.de/renovieren/energetische-sanierung/bafa-foerderung.html; https://www.cleanthinking.de/?p=1073862; https://www.foerder-welt.de/content/foerderwelt/de/wohnen/alle-foerdermittel/bafa-zuschuss-einzelmassnahmen.html
- [Q11] Energie-Fachberater, Stichtage der BEG-Reform 2026: https://www.energie-fachberater.de/news/kuerzungen-heizungsfoerderung.php
- [Q12] GModG und Folgeänderungen: dejure § 559e BGB https://dejure.org/gesetze/BGB/559e.html; dejure § 559f BGB https://dejure.org/gesetze/BGB/559f.html; IWW (Beschluss) https://www.iww.de/pbp/architektenrecht/gesetzgebung-das-gebaeudemodernisierungsgesetz-ist-beschlossen-und-kann-in-kraft-treten-n173832; Nexvyra (Sekundärquelle) https://nexvyra.de/news/2026-07-16-gebaeudemodernisierungsgesetz-gmodg-verabschiedet.html und https://nexvyra.de/fakten/mieterschutz-gas-oelheizung-co2kostaufg-5a.md; LTO (Koalitionseinigung) https://www.lto.de/recht/nachrichten/n/heizungsgesetz-koalition-mieterschutz-kosten-aufteilung-gas-oel; EMA https://ema-energiewelt.de/wissen/co2-kosten-vermieter-mieter-fossile-heizung-2028; Deutscher Mieterbund https://mieterbund.de/aktuelles/meldungen/mieterbund-begruesst-geplante-regelungen-im-gebaeudemodernisierungsgesetz/; test.de https://www.test.de/Gebaeudeenergiegesetz-Was-Hausbesitzer-wissen-muessen-5655820-0/
- [Q13] GModG Neubauanforderungen: BayIka-Bau Stellungnahme 11.05.2026 https://bayika.de/bayika-wAssets/docs/aktuelles/2026/2026-05-11_BF_Stellungnahme-BayIka-Bau_Verbaendeanhoerung-zum-Entwurf-des-Gebaeudemodernisierungsgesetzes.pdf; BDB Kurzbriefing https://www.baumeister-online.de/app/uploads/2026/07/BDB_Kurzbriefing_GModG_Website_final.pdf
- [Q14] § 559 BGB https://dejure.org/gesetze/BGB/559.html; § 559c BGB https://lxgesetze.de/bgb/559c; Lobbyregister (Verdopplung auf 20.000 €) https://www.lobbyregister.bundestag.de/inhalte-der-interessenvertretung/regelungsvorhabensuche/RV0025430
- [Q15] Mietpreisbremse bis 2029: https://www.lto.de/recht/nachrichten/n/bundestag-verlaengert-mietpreisbremse-bis-2029
- [Q16] BEHG/ETS 2: https://www.advant-beiten.com/aktuelles/behg-novelle-co2-preis-bleibt-2027-im-korridor-von-55-bis-65-euro; BT-Drs. 21/7869 https://dserver.bundestag.de/btd/21/078/2107869.pdf; EY https://www.ey.com/de_de/technical/steuernachrichten/referentenentwurf-zum-dritten-behg-aenderungsgesetz-stabilisierung-des-co2-preises-fuer-2027
- [Q17] BDEW: Quick Check 07.10.2026 https://www.bdew.de/media/documents/BDEW_Quick_Check_Gas_und_Strompreise261007.pdf; Strompreisanalyse 08/2026 https://www.bdew.de/media/documents/BDEW_Strompreisanalyse_082026.pdf; Gaspreisanalyse 08/2026 https://www.bdew.de/media/documents/BDEW_Gaspreisanalyse_082026.pdf; Gaspreisanalyse 01/2026 https://www.bdew.de/media/documents/BDEW_Gaspreisanalyse_012026_1.pdf
- [Q18] Verbraucherzentrale NRW, Marktcheck Wärmepumpenstromtarife 02/2026: https://www.verbraucherzentrale.nrw/sites/default/files/2026-03/2026_02_marktcheck_warmepumpenstromtarife_vz-nrw.pdf
- [Q19] Bauzinsen: https://www.drklein.de/finanzlexikon/darlehenszinsen.html; https://www.schwaebisch-hall.de/baufinanzierung/bauzinsen-aktuell.html
- [Q20] EZB-Einlagensatz (Sekundärquelle): https://www.biallo.de/geldanlage/news/naechste-zinserhoehung-der-ezb
- [Q21] Spareinlagen: https://www.inside-digital.de/vergleich/festgeld; https://www.tagesgeldvergleich.net/veroeffentlichungen/marktanalyse.html
- [Q22] Destatis, Inflationsrate September 2026: https://www.destatis.de/DE/Presse/Pressemitteilungen/2026/10/PD26_364_611.html
- [Q23] Baupreise Wohngebäude: https://ms-aktuell.de/welt/baupreise-dacharbeiten-teurer-12-10-2026/ (August 2026, Destatis-Zahlen); Destatis Mai 2026 https://www.destatis.de/DE/Presse/Pressemitteilungen/2026/07/PD26_241_61261.html
- [Q24] ARGE eV / RegioKontext, „Wohnungsbau in Deutschland 2026“ (Bauforschungsbericht Nr. 93, März 2026): https://mieterbund.de/app/uploads/2026/03/studie_zum_wohnungsbau_2026.pdf
- [Q25] Oberer Gutachterausschuss Brandenburg, Bewirtschaftungskosten nach Anlage 3 ImmoWertV 2022–2026: https://gutachterausschuss.brandenburg.de/sixcms/media.php/9/BewKo_2026.pdf
- [Q26] EEG-Einspeisevergütung ab 01.08.2026: https://www.adac.de/rund-ums-haus/energie/spartipps/einspeiseverguetung-pv-anlagen; EEG-Reform 2027: https://reduco.ai/blog/einspeiseverguetung-aenderungen-2026-2027
- [Q27] PV-Kosten: https://42watt.de/magazin/photovoltaik-kosten
- [Q28] Wärmepumpenkosten: https://reduco.ai/blog/heizung/waermepumpe-kaskade-mehrfamilienhaus; https://www.aroundhome.de/heizung/waermepumpe/preise-kosten
- [Q29] Mieten: https://vdiv.de/news-details/neubaumieten-von-20-euro-qm-etablieren-sich-als-neue-benchmark-in-deutschen-grossstaedten; https://www.immobilienscout24.de/unternehmen/fileadmin/user_upload/WohnBarometer_Q2_2026_Miete.pdf
- [Q30] Bestandsmieten: https://www.sachsen-fernsehen.de/amp/bezahlbares-wohnen-in-sachsen-unter-druck-2236254/; Gewobag Geschäftsbericht 2025 https://berichte.gewobag.de/fileadmin/assets_2025/PDFs/Gewobag-Geschaefts-und-Nachhaltigkeitsbericht-2025-HGB.pdf
- [Q31] Finanztip, KfW 261 (Zinsniveau Juni 2026): https://www.finanztip.de/kfw-foerderung/kfw-energieeffizient-sanieren/
- [Q32] SIKB Hausbankenmitteilung 55/2024 (TZ-Verrechnung): https://www.sikb.de/sites/default/files/SIKB/Hausbankenmitteilungen%202024/HB_55_2024.pdf
- [Q33] Interhyp, EH-55-Antragsfrist: https://www.interhyp.de/ratgeber/news/kfw-effizienzhaus-55-antragsfrist-juni-2026/
