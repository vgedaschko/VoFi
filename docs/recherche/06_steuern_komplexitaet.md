# 06 – Ertragsteuerliche Würdigung im VoFi-Tool: Komplexitätsbewertung und Empfehlung

| | |
|---|---|
| **Stand** | 25.10.2026 (Rechtsstand 2026, Entwürfe gesondert gekennzeichnet) |
| **Status** | Recherche-Memo / Entscheidungsvorlage |
| **Bezug** | Nutzeraussage: „Die ertragssteuerliche Würdigung würde ich je nach deiner Einschätzung des Komplexitätsgrads erstmal ausklammern.“ |
| **Geltungsbereich** | Neubau und energetische Sanierung von Wohngebäuden in Deutschland; Perspektiven: private Vermieter (§ 21 EStG), Selbstnutzer, Wohnungsunternehmen (kommunal, Genossenschaft, privatwirtschaftlich) |
| **Hinweis** | Keine Steuerberatung. Das Memo bewertet, was ein Tool abbilden müsste und wie aufwendig das ist. Angaben aus Sekundärquellen sind gekennzeichnet; vor der Implementierung von Parametern ist der amtliche Gesetzestext zu prüfen. |

---

## 0. Kurzfassung (Entscheidungsvorschlag)

1. **Gesamturteil Komplexität:** Eine *vollständige* ertragsteuerliche Würdigung ist **hoch komplex**. Das liegt kaum an den Formeln (Tarif, AfA), sondern an vier Dingen: (a) der **Einordnung der Maßnahmen** (Erhaltungsaufwand oder Herstellungskosten, neu geregelt im BMF-Schreiben vom 26.01.2026), (b) **Größen außerhalb des Projekts** (übriges Einkommen, Verlustvorträge, Organkreis, Status der erweiterten Kürzung, Genossenschaftsprivileg), (c) **befristeten Normen** (degressive AfA und § 7b bis 30.09.2029, § 35c bis 31.12.2029, KSt-Senkungspfad 2028–2032, Mindestbesteuerung 70 % nur 2024–2027) und (d) **mindestens fünf getrennten Steuerregimen** für die Perspektiven.
2. **Entscheidungsrelevanz je Perspektive:**
   - **Private Vermieter: hoch.** AfA (§ 7 Abs. 4/5a, § 7b), der sofortige Abzug von Erhaltungsaufwand und die steuerfreie Veräußerung nach 10 Jahren können das Ergebnis und die Rangfolge der Varianten umkehren (Neubau gegen Sanierung, Sanierung ja/nein). Ein VoFi vor Steuern ist hier nur bedingt entscheidungstauglich.
   - **Wohnungsunternehmen: mittel bis niedrig auf Projektebene.** Genossenschaften mit Vermietungsprivileg und gemeinnützige Unternehmen sind steuerbefreit. Steuerpflichtige Unternehmen zahlen mit erweiterter Kürzung rund 15,8 % (ab 2032 rund 10,6 %), oft mit Verlustvorträgen. Das ist meist ein Niveau-Effekt und ändert die Rangfolge selten.
   - **Selbstnutzer: niedrig.** Der Nutzungswert wird nicht besteuert, und es gibt keinen Werbungskostenabzug. Entscheidungsrelevant sind nur **§ 35c EStG gegen BEG-Förderung** (schließen sich gegenseitig aus) und die **Abgeltungsteuer auf die Alternativanlage**.
3. **Empfehlung v1:**
   - Das **Ergebnis vor Ertragsteuern** ist das Primärergebnis. Dazu kommt eine **verbindlich umgesetzte Steuer-Schnittstelle** (Steuer-Tags, AfA-/Anlagenregister, Steuerzustand in der Periodenschleife) mit einem **Null-Modul** als Standard.
   - Zusätzlich gibt es ein **optionales Pauschalsteuer-Modul („Steuer-Light“)** als Referenzimplementierung. Es ist standardmäßig aus und nur für private Vermieter und steuerpflichtige Wohnungsunternehmen freigeschaltet. **Für Selbstnutzer und steuerbefreite Rechtsträger ist es gesperrt**, weil es dort irreführen würde (siehe 6.2).
   - Für Selbstnutzer gibt es stattdessen zwei gezielte Bausteine: einen **§ 35c-Generator mit BEG-Ausschlusslogik** und eine **Option „Habenzins nach Abgeltungsteuer“**.
4. **Nicht-Ertragsteuern sind in v1 Pflicht und vollständig:**
   - **Umsatzsteuer** als Kostenbestandteil (Bruttokosten, weil kein Vorsteuerabzug bei steuerfreier Wohnraumvermietung), wobei netto und USt getrennt gespeichert werden;
   - **Grunderwerbsteuer** als Transaktionskosten (Ländersätze 3,5–6,5 %);
   - **Grundsteuer** als Betriebskosten (umlagefähig, aber bei Leerstand, in der Bauphase und für Selbstnutzer kostenwirksam);
   - Nullsteuersatz für PV-Anlagen bis 30 kWp.
5. **Architektur:** Der Steuerbetrag einer Periode hängt von den Zinsen ab, und die Zinsen hängen von den Beständen ab. Daher wird **sequenziell Periode für Periode** gerechnet, mit nachschüssiger Zinskonvention (Zinsen in t auf Bestände t−1). So gibt es keine Zirkularität. Über die Monte-Carlo-Pfade wird vektorisiert, über die Perioden geschleift. Der Steuerzustand (Verlustvortrag, Restbuchwerte, offene Steuerschuld) wird in der Schleife mitgeführt.

---

## 1. Fragestellung

Zu klären ist, ob die Ertragsteuern (ESt/KSt/GewSt inklusive Solidaritätszuschlag und Kirchensteuer) in Version 1 des VoFi-Tools ausgeklammert werden können, ohne dass

- die Ergebnisse für eine Zielgruppe systematisch zu falschen Entscheidungen führen und
- ein späteres Steuermodul ein Refactoring der VoFi-Engine erzwingt.

Dazu wird je Perspektive der relevante Rechtsstand 2026 erhoben (Abschnitt 3), jedes Element nach Implementierungskomplexität und Entscheidungsrelevanz eingestuft (Abschnitt 4), daraus ein v1/v2-Schnitt abgeleitet (Abschnitt 6) und die Schnittstelle spezifiziert (Abschnitt 7).

---

## 2. Methodischer Rahmen: Steuern im VoFi

- Im VoFi nach Grob sind Ertragsteuern **eine Zahlungszeile im Finanzplan**: Zahlung negativ, Erstattung positiv. Berechnet werden sie in einer **steuerlichen Nebenrechnung**:
  steuerliches Ergebnis = steuerpflichtige Einzahlungen − abzugsfähige Auszahlungen − AfA − Sollzinsen + Habenzinsen, jeweils je Periode.
  Der Steuerbetrag ergibt sich durch Anwendung des Tarifs oder Satzes, unter Berücksichtigung von Verlusten. (Literatur: Grob, *Investitionsrechnung mit vollständigen Finanzplänen*, 1989; Grob, *Einführung in die Investitionsrechnung*, 5. Aufl. 2006.)
- **Interdependenz:**
  - Die Sollzinsen und Habenzinsen der **endogenen** Konten (Kontokorrent, Ergänzungsinvestition) hängen von den Beständen ab.
  - Die Bestände hängen von den Steuerzahlungen ab.
  - Die Steuern hängen von den Zinsen ab.

  Mit der Standardkonvention „Zinsen der Periode t auf den Bestand am Ende von t−1“ ist das System **periodenweise rekursiv lösbar**. Siehe 7.8.
- **Vor und nach Steuern können unterschiedliche Rangfolgen ergeben.** Ursachen sind:
  - der zeitliche Versatz der Steuerwirkung (Steuerstundung durch AfA und Sofortabzug),
  - Steuersatzunterschiede zwischen den Perioden (Progression, KSt-Senkung ab 2028),
  - die Besteuerung der Alternativanlage (Habenzins nach Steuern),
  - steuerfreie Endwerte (§ 23 EStG nach 10 Jahren).

  Im Extremfall steigt der Kapitalwert durch die Steuer („Steuerparadoxon“, vgl. Kruschwitz/Lorenz, *Investitionsrechnung*). Ein VoFi vor Steuern ist daher **keine neutrale Näherung**, sondern eine bewusste Vereinfachung mit perspektivenabhängigem Fehler.

---

## 3. Rechtsstand 2026 je Perspektive

### 3.1 Private Vermieter (Einkünfte aus Vermietung und Verpachtung, § 21 EStG)

#### 3.1.1 Tarif, Solidaritätszuschlag, Kirchensteuer

- **§ 32a Abs. 1 EStG ab VZ 2026** (amtlicher Text, x = abgerundetes zvE):

  | Zone | zvE (Grundtabelle) | Formel |
  |---|---|---|
  | 1 | bis 12.348 € | 0 |
  | 2 | 12.349 – 17.799 € | (914,51·y + 1.400)·y, y = (x − 12.348)/10.000 |
  | 3 | 17.800 – 69.878 € | (173,10·z + 2.397)·z + 1.034,87, z = (x − 17.799)/10.000 |
  | 4 | 69.879 – 277.825 € | 0,42·x − 11.135,63 |
  | 5 | ab 277.826 € | 0,45·x − 19.470,38 |

  Beim Splitting wird die Steuer auf das halbe gemeinsame zvE berechnet und dann verdoppelt.
- **Ausblick (Entwurf, noch nicht Gesetz):** Regierungsentwurf des Einkommensteuerreformgesetzes 2027, Kabinettsbeschluss vom 02.09.2026:
  - Grundfreibetrag 12.564 € (2027) und 12.900 € (2028);
  - 45 % bereits ab 250.000 €;
  - neue Stufe 47 % ab 280.000 €;
  - § 35a Handwerkerleistungen sinkt ab 2027 von 20 % auf 15 % (Höchstbetrag 900 € statt 1.200 €).

  **Konsequenz:** Tarifparameter müssen **je VZ versioniert** werden.
- **Solidaritätszuschlag 2026:** Freigrenze 20.350 € bei Einzelveranlagung und 40.700 € bei Zusammenveranlagung, jeweils bezogen auf die festgesetzte ESt. In der Milderungszone beträgt der Zuschlag höchstens 11,9 % des Betrags über der Freigrenze, darüber 5,5 % (Sekundärquelle TK). Der **Grenz**-Zuschlag in der Milderungszone ist mit 11,9 % höher als 5,5 %. Bei 42 % Grenzsteuersatz ergibt das kurzzeitig rund 47 % Grenzbelastung. Das zeigt, dass ein „einfacher Satz“ die Realität nur näherungsweise trifft.
- **Kirchensteuer:** 8 % (BY, BW) bzw. 9 % der ESt. Sie ist als Sonderausgabe abziehbar, die effektive Mehrbelastung ist daher etwas geringer. (Gesetzeskenntnis, nicht gesondert online verifiziert.)
- **Typische Grenzbelastung** eines Vermieters mit gutem Einkommen: 42 % ESt × 1,055 Soli = **44,31 %**, mit KiSt bis knapp 48 %.
- **Kernproblem für ein Tool:** Die Steuer auf das Projektergebnis ist eine **Differenzgröße**:
  ESt(übriges zvE + Projektergebnis) − ESt(übriges zvE).
  Das übrige zvE des Investors über 30 bis 50 Jahre (Ruhestand, Splitting) ist eine Annahme außerhalb des Projekts. Die Tarifformel ist trivial, ihre korrekte Parametrisierung nicht.

#### 3.1.2 Absetzung für Abnutzung (AfA)

- **Lineare Gebäude-AfA § 7 Abs. 4 S. 1 Nr. 2 EStG:**
  - 3 % bei Fertigstellung nach dem 31.12.2022,
  - 2 % bei Fertigstellung 1925 bis 2022,
  - 2,5 % bei Fertigstellung vor 1925.

  Nachträgliche Herstellungskosten erhöhen die Bemessungsgrundlage des Gebäudes. Im Erstjahr wird pro rata temporis abgeschrieben (Monatsgenauigkeit).
- **Degressive AfA für Wohngebäude § 7 Abs. 5a EStG:**
  - 5 % vom jeweiligen Restwert;
  - Herstellungsbeginn nach dem 30.09.2023 und vor dem 01.10.2029. Bei Anschaffung muss der obligatorische Vertrag in diesem Zeitraum geschlossen sein und die Anschaffung bis Ende des Fertigstellungsjahres erfolgen;
  - Nachweis über die Baubeginnsanzeige;
  - Wechsel zur linearen AfA zulässig;
  - keine AfaA.
- **Sonderabschreibung § 7b EStG:**
  - 5 % p. a. im Jahr der Fertigstellung bzw. Anschaffung und in den drei Folgejahren, zusätzlich zur AfA nach § 7 Abs. 4 **oder** Abs. 5a;
  - Bauantrag bzw. Bauanzeige nach dem 31.12.2022 und vor dem 01.10.2029;
  - neue Wohnung, **Effizienzhaus 40 mit QNG-Siegel**;
  - **Baukostenobergrenze 5.200 €/m²** Wohnfläche;
  - **Bemessungsgrundlage höchstens 4.000 €/m²**;
  - entgeltliche Vermietung zu Wohnzwecken im Herstellungsjahr und in den folgenden **neun** Jahren;
  - **Rückgängigmachung** bei Verstoß, bei Veräußerung innerhalb der Frist mit steuerfreiem Gewinn oder bei Überschreiten der Baukostenobergrenze durch nachträgliche Kosten innerhalb von drei Jahren;
  - Beihilferecht (VO (EU) 2023/2831) gilt bei Bauantrag nach 2022 nur für Anspruchsberechtigte mit Einkünften nach §§ 13, 15, 18 EStG, **nicht** für private Vermieter (§ 21).
- **Degressive AfA für bewegliche Wirtschaftsgüter § 7 Abs. 2 EStG** (Investitionssofortprogramm): bis zum Dreifachen des linearen Satzes, höchstens 30 %, für Anschaffung oder Herstellung nach dem 30.06.2025 und vor dem 01.01.2028. Im Wohngebäude betrifft das kaum etwas: Heizung und Fenster sind unselbstständige Gebäudeteile. Relevant sind allenfalls PV-Anlagen oder Ladeinfrastruktur, soweit diese nicht ohnehin nach § 3 Nr. 72 EStG steuerfrei sind.

**Illustration der Größenordnung (vereinfachend):**

- Annahmen: Gebäude-HK = AfA- und § 7b-Bemessungsgrundlage 400.000 €, 100 m², EH40-QNG, volle Jahre, Sonder-AfA mindert den Restwert.

| | Jahr 1 | Jahr 2 | Jahr 3 | Jahr 4 | Summe 4 J. |
|---|---|---|---|---|---|
| linear 3 % | 12.000 | 12.000 | 12.000 | 12.000 | 48.000 (12 %) |
| degressiv 5 % | 20.000 | 18.000 | 16.100 | 14.295 | 68.395 |
| + § 7b 5 % | 20.000 | 20.000 | 20.000 | 20.000 | 80.000 |
| **degressiv + § 7b** | 40.000 | 38.000 | 36.100 | 34.295 | **148.395 (≈ 37 %)** |

Bei 44,31 % Grenzbelastung beträgt die Steuerstundung in den ersten vier Jahren rund **44.500 €** gegenüber linearer AfA. Bei Veräußerung nach Ablauf der 10-Jahresfrist (§ 23, siehe 3.1.6) wird ein Teil dieser Stundung zur **endgültigen** Ersparnis, weil die AfA den steuerfreien Veräußerungsgewinn erhöht.

#### 3.1.3 Erhaltungsaufwand oder Herstellungskosten, anschaffungsnahe HK, § 82b EStDV

- **BMF-Schreiben vom 26.01.2026** (IV C 1 - S 2253/00082/001/064). Es ersetzt die Schreiben vom 18.07.2003 und 20.10.2017 und gilt in allen offenen Fällen.
  - **Standardhebung** liegt nur vor, wenn Maßnahmen in **mindestens drei der vier** zentralen Ausstattungsbereiche den Gebrauchswert deutlich erhöhen (Rn. 13, 19). Die Bereiche sind Heizung, Sanitär, Elektro und Fenster.
  - Eine zusätzliche **Fassadendämmung** zählt dabei nicht mit (Rn. 14) und ist auch keine Substanzmehrung (Rn. 38).
  - Der **Tausch einer Öl- oder Gasheizung gegen eine Wärmepumpe**, Fernwärme oder Solarthermie hebt den Heizungsstandard allein nicht auf „sehr anspruchsvoll“ (Rn. 22).
  - Der **Austausch von 2-fach- gegen 3-fach-Verglasung** ist keine Standardhebung (Rn. 23).
  - Eine Senkung des Endenergiebedarfs allein ist keine deutliche Gebrauchswerterhöhung (Rn. 46).
  - **Sanierung in Raten**: Die Vermutungsregel gilt jetzt für **drei** Jahre statt bisher fünf (Rn. 52).
  - **Erweiterungen** (zusätzliche Wohnfläche, Aufstockung, Gauben) führen immer zu Herstellungskosten, eine Wesentlichkeitsgrenze gibt es nicht (Rn. 31–36).
  - **Folge für das Tool:** Typische energetische Sanierungen an **lange gehaltenen** Mietgebäuden sind in der Regel **Erhaltungsaufwand und sofort abziehbar**. Neubau, Aufstockung und Anbau sind Herstellungskosten.
- **Anschaffungsnahe HK, § 6 Abs. 1 Nr. 1a EStG:** Instandsetzungs- und Modernisierungsaufwand **innerhalb von drei Jahren nach Anschaffung** wird zu Herstellungskosten, wenn er **netto (ohne USt) 15 % der Gebäude-Anschaffungskosten** übersteigt (BMF Rn. 54 ff.). Ausgenommen sind Erweiterungen und jährlich übliche Erhaltungsarbeiten. Schönheitsreparaturen zählen mit. Für „Kauf + energetische Sanierung“ ist die Regel **entscheidend**.
- **§ 82b EStDV:** Größerer Erhaltungsaufwand an Gebäuden im Privatvermögen, die überwiegend Wohnzwecken dienen, kann auf **2 bis 5 Jahre** gleichmäßig verteilt werden (Wahlrecht). Bei Veräußerung wird der Rest im Veräußerungsjahr abgezogen. Das ist relevant zur Glättung der Progression.

**Illustration:** Energetische Sanierung für 150.000 € brutto an einem seit Jahren vermieteten Gebäude.

- **Erhaltungsaufwand:** bis zu rund 66.000 € Steuerentlastung im Abzugsjahr bzw. verteilt nach § 82b (bei 44,31 %; durch die Progression ggf. weniger, daher die Verteilung).
- **Herstellungskosten** (z. B. anschaffungsnah): 2 % AfA, also rund 1.330 € pro Jahr über 50 Jahre.
- Die Einordnung entscheidet damit über einen Barwertunterschied von rund **20–30 % der Investitionssumme** (je nach Diskontierungszins, z. B. Barwert der AfA-Reihe bei 3–5 % rund 24.000–34.000 € gegenüber rund 66.000 € Sofortentlastung).

#### 3.1.4 Schuldzinsen und Finanzierungskosten

- Schuldzinsen und Finanzierungskosten (Bereitstellungszinsen, Gebühren) für vermietete Objekte sind Werbungskosten, in der Bauphase als **vorweggenommene Werbungskosten**. Ein **Disagio** ist nach § 11 Abs. 2 S. 4 EStG bei Marktüblichkeit im Zahlungsjahr abziehbar, sonst wird es verteilt. Tilgung ist nicht abziehbar. (Gesetzeskenntnis.)
- **Kontokorrentzinsen im VoFi** sind abziehbar, soweit sie objektbezogene Auszahlungen finanzieren. Zinsen auf ein Defizit, das durch **private Steuerzahlungen** entsteht, wären streng genommen nicht abziehbar. Das ist eine bekannte Vereinfachung, sie wird dokumentiert.
- **Habenzinsen** der Ergänzungsinvestition sind beim Privatinvestor **Einkünfte aus Kapitalvermögen** (§ 20 EStG): Abgeltungsteuer 25 % + Soli = 26,375 %, Sparer-Pauschbetrag 1.000/2.000 €. Sie werden **nicht** mit Vermietungsverlusten verrechnet (Gesetzeskenntnis). Die Schnittstelle muss Habenzinsen daher getrennt taggen.

#### 3.1.5 Verlustverrechnung

- **Horizontaler und vertikaler Verlustausgleich:** Verluste aus V+V werden im selben VZ mit anderen Einkünften verrechnet, etwa mit dem Gehalt. Für Arbeitnehmer ist „sofortiger Verlustausgleich zum Grenzsteuersatz“ daher meist die realistische Annahme. Über einen Lohnsteuer-Freibetrag nach § 39a EStG wirkt er sogar unterjährig.
- **§ 10d EStG:**
  - Rücktrag bis 1 Mio. € bzw. 2 Mio. € bei Zusammenveranlagung, in die zwei vorangegangenen VZ.
  - Vortrag: Sockel 1 Mio. € bzw. 2 Mio. €, darüber nur **70 %** (VZ 2024–2027), ab VZ 2028 wieder **60 %** (Wachstumschancengesetz).
  - Für private Einzelprojekte ist die Mindestbesteuerung praktisch irrelevant.
- **Hinweise:** § 15b EStG (Steuerstundungsmodelle) betrifft konzeptionierte Anlagemodelle. § 21 Abs. 2 EStG: Bei verbilligter Vermietung unter 50 % der ortsüblichen Miete werden die Werbungskosten aufgeteilt, ab 66 % gilt die Vermietung als voll entgeltlich.

#### 3.1.6 Private Veräußerungsgeschäfte, § 23 EStG

- Gewinne aus der Veräußerung binnen **10 Jahren** nach Anschaffung sind steuerpflichtig. Steuerfrei ist die Veräußerung bei Eigennutzung im Veräußerungsjahr und den beiden Vorjahren. Die in Anspruch genommene AfA mindert die Anschaffungskosten, sodass der Gewinn steigt. (Gesetzeskenntnis.)
- **VoFi-Relevanz:** Am Planungshorizont T hängt es von T − Anschaffungszeitpunkt ab, ob ein Liquidationserlös oder Restwert steuerfrei ist. Das hat erheblichen Einfluss auf den Endwert.

#### 3.1.7 Zuschüsse und Tilgungszuschuss

- **R 21.5 EStR:** Investitionszuschüsse aus öffentlichen Mitteln, die keine Mieterzuschüsse sind, gehören **nicht** zu den Einnahmen.
  - **Bei Herstellungskosten:** Ab dem **Bewilligungsjahr** wird die AfA (auch Sonder-AfA) von den **um den Zuschuss geminderten** HK berechnet. Das gilt auch bei Zufluss in mehreren Jahren.
  - **Bei Erhaltungsaufwand und Schuldzinsen:** Nur der um den Zuschuss geminderte Betrag ist abziehbar. Fallen Zahlung und Abzug in verschiedene VZ, ist der Zuschuss im Zuflussjahr eine Einnahme.
  - **Laufende Zuschüsse**, die Gegenleistung für Miet- oder Belegungsbindungen sind (soziale Wohnraumförderung), sind Einnahmen.
- **KfW-Tilgungszuschuss:** Nach herrschender Praxis wird er wie ein Investitionszuschuss behandelt (Minderung der HK bzw. des Erhaltungsaufwands). Eine KfW-spezifische Verwaltungsanweisung wurde nicht gefunden. Im Einzelfall sollte das mit einem Steuerberater geklärt werden. Der Tilgungszuschuss ist **nicht zahlungswirksam**, er mindert die Darlehensvaluta. Die Schnittstelle muss das abbilden können.
- **Bei Unternehmen** gilt R 6.5 EStR: Wahlrecht zwischen erfolgsneutraler Minderung der AHK und erfolgswirksamer Vereinnahmung.

#### 3.1.8 Weitere Punkte

- **§ 3 Nr. 72 EStG:** PV-Einnahmen sind steuerfrei bis 30 kWp je Wohn- oder Gewerbeeinheit, insgesamt höchstens 100 kWp je Steuerpflichtigem oder Mitunternehmerschaft. Es entsteht keine Abfärbung auf die Vermietung. Für die meisten Projekte ist PV ertragsteuerlich damit neutral.
- **Kaufpreisaufteilung Boden/Gebäude:** Sie bestimmt die AfA-Bemessungsgrundlage beim Bestandserwerb. Das BMF stellt eine Arbeitshilfe bereit. Der **Regierungsentwurf des JStG 2026** (Kabinett 12.08.2026) sieht einen neuen **§ 6f EStG** vor: Aufteilung nach Verkehrswerten, vertragliche Aufteilung grundsätzlich vorrangig, Abweichung per Gutachten, gilt für Verträge nach Verkündung. **Status: Entwurf, parlamentarisches Verfahren läuft.**
- **§§ 7h, 7i EStG** (Sanierungsgebiet, Baudenkmal) sind erhöhte Absetzungen für Spezialfälle. Sie sind nur für energetische Sanierung denkmalgeschützter Bestände relevant, also v2 oder optional.
- **Standortfördergesetz** (BGBl. 2026 I Nr. 33): keine direkten Änderungen bei Vermietungseinkünften oder Gebäude-AfA.

### 3.2 Selbstnutzer

- **Keine Besteuerung des Nutzungswerts** (Konsumgutlösung). Daher gibt es **keinen** Abzug von Schuldzinsen, AfA oder Erhaltungsaufwand. Die Veräußerung ist bei Eigennutzung steuerfrei (§ 23 Abs. 1 Nr. 1 S. 3). Ertragsteuerlich ist das Objekt also **neutral**: Die Steuer auf das Objekt ist null, und genau das muss das Tool korrekt abbilden.
- **§ 35c EStG** (energetische Maßnahmen am selbstgenutzten Gebäude):
  - 20 % der Aufwendungen, verteilt auf **7 % / 7 % / 6 %** (Jahr des Abschlusses und zwei Folgejahre, maximal 14.000 / 14.000 / 12.000 €);
  - **höchstens 40.000 € je Objekt**, also ausgeschöpft bei 200.000 € Kosten;
  - Energieberaterkosten zu 50 %;
  - Gebäude bei Durchführung älter als 10 Jahre;
  - Fachunternehmen und amtliche Bescheinigung erforderlich;
  - Maßnahmen **begonnen nach dem 31.12.2019 und abgeschlossen vor dem 01.01.2030** (§ 52 Abs. 35a EStG). „Abgeschlossen“ heißt erst mit **vollständiger Bezahlung** (BFH 13.08.2024, IX R 31/23).
  - **Ausschluss**, soweit für dieselbe Maßnahme **zinsverbilligte Darlehen oder steuerfreie Zuschüsse** (BEG/KfW) in Anspruch genommen werden oder § 35a bzw. § 10f genutzt wird.
  - Die Ermäßigung mindert nur die **tarifliche ESt**. Ein Überhang wird nicht erstattet.
  - Für 2026 wurde keine Änderung gefunden. Der Regierungsentwurf der ESt-Reform 2027 enthält nach den gesichteten Quellen keine Änderung an § 35c.
- **Entscheidungsrelevanz:** Die Wahl **BEG-Zuschuss/Kredit oder § 35c** ist für Selbstnutzer ein echter, häufig unterschätzter Entscheidungspunkt, besonders bei großen Maßnahmen jenseits der BEG-Höchstgrenzen der förderfähigen Kosten. Sie ist mit geringem Aufwand als Zahlungsstrom abbildbar.
- **§ 35a EStG** (Handwerkerleistungen): 20 % der Lohnkosten, höchstens 1.200 € p. a. (2026). Nach dem Regierungsentwurf sinkt das ab 2027 auf 15 % bzw. 900 €. Kein Kumulieren mit § 35c für dieselbe Maßnahme. Geringe Relevanz.
- **Alternativanlage:** Die Opportunität des Selbstnutzers (Eigenkapital anlegen, Miete zahlen bzw. nicht sanieren) wird mit **Abgeltungsteuer** belastet, die Eigennutzung nicht. Ein VoFi vor Steuern mit Habenzins brutto **unterschätzt** daher systematisch die Vorteilhaftigkeit von Eigentum und Sanierung. Eine einfache Korrektur ist der Habenzins nach Abgeltungsteuer: Habenzins × (1 − 0,26375), mit KiSt rund × (1 − 0,28).

### 3.3 Wohnungsunternehmen

#### 3.3.1 Kapitalgesellschaften (privatwirtschaftlich, kommunale GmbH/AG)

- **KSt 15 % + Soli 5,5 % = 15,825 %.** Nach dem **Investitionssofortprogramm** (StInvSofortPG, BGBl. 2025 I Nr. 161) sinkt die KSt ab VZ 2028 jährlich um einen Prozentpunkt. Mit Soli ergibt sich:

  | VZ | ≤ 2027 | 2028 | 2029 | 2030 | 2031 | ab 2032 |
  |---|---|---|---|---|---|---|
  | KSt | 15 % | 14 % | 13 % | 12 % | 11 % | 10 % |
  | KSt + Soli | 15,825 % | 14,77 % | 13,715 % | 12,66 % | 11,605 % | 10,55 % |

  **Konsequenz:** Der Steuersatz muss als **Zeitreihe** parametrisiert werden.
- **Gewerbesteuer:**
  - Messzahl 3,5 % × Hebesatz. Der **Mindesthebesatz steigt ab EZ 2027 von 200 % auf 280 %** (9. StBerRÄndG, BGBl. 2026 I Nr. 197).
  - **Erweiterte Kürzung § 9 Nr. 1 S. 2 GewStG**: Bei ausschließlicher Verwaltung und Nutzung eigenen Grundbesitzes wird der darauf entfallende Gewerbeertrag gekürzt. Die GewSt auf Mieterträge ist dann praktisch null.
  - Unschädlich sind (S. 3) Stromlieferungen aus EE-Anlagen und Ladestationen bis **20 %** der Einnahmen aus der Gebrauchsüberlassung (EE-Strom grundsätzlich nur an Mieter) und sonstige Leistungen an Mieter bis **5 %**.
  - Ohne erweiterte Kürzung gilt die einfache Kürzung, ab EZ 2025 in Höhe der als Betriebsausgabe erfassten **Grundsteuer**. Hinzu kommt die Hinzurechnung von 25 % der Finanzierungsentgelte über 200.000 € (§ 8 Nr. 1 GewStG, Gesetzeskenntnis). Die Gesamtbelastung liegt dann bei rund 30 % (z. B. bei Hebesatz 450 %: 15,825 % + 15,75 %).
  - **Der Verlust der erweiterten Kürzung**, etwa durch Mieterstrom, Wärmeliefer-Contracting, Betriebsvorrichtungen oder Dienstleistungen, **ist das größte Steuerrisiko** dieser Perspektive. Es ist aber eine **Unternehmens-** und keine Projektgröße.
  - GewSt-Verlustvortrag § 10a GewStG: Sockel 1 Mio. €, darüber 60 %. Die Anhebung auf 70 % gilt hier nicht.
- **Zinsschranke § 4h EStG / § 8a KStG:** Zinsaufwand ist über den Zinsertrag hinaus nur bis 30 % des verrechenbaren EBITDA abziehbar. **Freigrenze 3 Mio. €** Nettozinsaufwand, dazu Konzern-/Escape-Klausel sowie Zins- und EBITDA-Vortrag. Für große Wohnungsunternehmen ist das real, aber nur auf **Unternehmensebene** bestimmbar. Auf Projektebene nicht sinnvoll abbildbar.
- **Mindestbesteuerung § 10d** (KSt 70 % 2024–2027, ab 2028 60 %; Sockel 1 Mio. €) und **Organschaft** wirken auf Unternehmensebene. Auf Projektebene lassen sie sich ausreichend über den Schalter **„Verlust sofort verrechenbar“ (Unternehmen mit Gewinnen, Organkreis) oder „Vortrag“ (Projektgesellschaft)** abbilden.
- **Veräußerungsgewinne** sind stets steuerpflichtig, es gibt keine 10-Jahresfrist. § 6b EStG (Reinvestitionsrücklage) ist v2.
- **HGB und Steuerbilanz:**
  - Zahlungsrelevant ist nur die **Steuerbilanz** (Steuerzahlungen).
  - HGB-Ergebnisse (Gebäude-AfA meist über 50–80 Jahre, Behandlung von Zuschüssen, latente Steuern) beeinflussen Ausschüttungsfähigkeit, Covenants und kommunale Haushaltsbelange, **nicht** die VoFi-Zahlungsreihe.
  - Laut BMF Rn. 19 ist eine abweichende HGB-Beurteilung, etwa bei energetischer Sanierung, für die Steuer unerheblich.
  - Eine HGB-Erfolgsvorschau gehört daher in eine spätere Version, falls überhaupt.

#### 3.3.2 Genossenschaften

- **Vermietungsgenossenschaft § 5 Abs. 1 Nr. 10 KStG:**
  - KSt-frei, soweit Wohnungen an Mitglieder überlassen werden; GewSt-frei nach § 3 Nr. 15 GewStG (Gesetzeskenntnis).
  - Die Befreiung entfällt **insgesamt**, wenn Einnahmen aus nicht begünstigten Tätigkeiten **10 %** übersteigen. Die Grenze steigt auf **30 %**, wenn allein Einnahmen aus **Mieterstrom** (§ 21 Abs. 3 EEG) bzw. **Gebäudestrom** (§ 3 Nr. 53 EnWG) zur Überschreitung führen.
  - Für das Tool heißt das: Steuersatz 0, dazu ein **Warnhinweis**, wenn Projekt-Nebenerlöse (Strom, Gewerbe) die Quote erkennbar belasten.
- **Nicht befreite Genossenschaften** werden wie Kapitalgesellschaften behandelt, oft mit erweiterter Kürzung.

#### 3.3.3 Kommunale Unternehmen und neue Wohngemeinnützigkeit

- Kommunale Wohnungsunternehmen sind meist steuerpflichtige Kapitalgesellschaften. Spezifische Themen auf Unternehmensebene sind Querverbund, BgA, dauerdefizitäre Tätigkeiten und große Verlustvorträge. Viele zahlen faktisch über längere Zeit kaum Ertragsteuern.
- **Neue Wohngemeinnützigkeit seit 01.01.2025** (§ 52 Abs. 2 S. 1 Nr. 27 AO, JStG 2024):
  - Förderzweck ist die vergünstigte Wohnraumüberlassung an Personen nach § 53 AO. Die Einkommensgrenze liegt beim 5-fachen, für Alleinstehende und Alleinerziehende beim 6-fachen Regelsatz der Sozialhilfe, geprüft zu Beginn des Mietverhältnisses.
  - Die Miete muss dauerhaft unter der Marktmiete liegen. Eine Kostenmiete ohne Gewinnaufschlag reicht.
  - Folge sind Steuerbefreiungen (KSt/GewSt) gegen Vermögensbindung.
  - Für das Tool ist das ein **Regime-Schalter** (Satz 0), verbunden mit einer **Mietobergrenze** als Restriktion im Ertragsteil.

### 3.4 Nicht-Ertragsteuern

- **Grunderwerbsteuer** (Stand Mai 2026, Sekundärquelle Wikipedia):

  | Satz | Länder |
  |---|---|
  | 3,5 % | BY |
  | 5,0 % | BW, NI, RP, ST, TH (seit 01.01.2024) |
  | 5,5 % | HB (seit 01.07.2025), HH, SN |
  | 6,0 % | BE, HE, MV |
  | 6,5 % | BB, NW, SL, SH |

  - Bemessungsgrundlage ist die Gegenleistung. Beim **einheitlichen Vertragsgegenstand** (Grundstück und Bauleistung aus einer Hand, z. B. Bauträger) zählt auch die Bauleistung dazu.
  - Freigrenze 2.500 €.
  - Ertragsteuerlich ist die GrESt **Anschaffungsnebenkosten** und wird auf Boden und Gebäude aufgeteilt.
  - Ein Ersterwerber-Freibetrag ist bislang in keinem Land eingeführt (Sekundärquelle, Stand 04/2026).
- **Grundsteuer** (neues Recht seit 01.01.2025, Ländermodelle):
  - Sie ist als öffentliche Last **umlagefähig** (§ 2 Nr. 1 BetrKV).
  - Beim Vermieter ist sie wirtschaftlich ein Durchlaufposten, **außer** bei Leerstand, in der Bauphase (unbebautes Grundstück, ggf. Grundsteuer C nach § 25 Abs. 5 GrStG) und bei der Neubewertung nach Fertigstellung.
  - Beim Selbstnutzer ist sie voll kostenwirksam.
  - Ertragsteuerlich ist sie abziehbar.
- **Umsatzsteuer:**
  - Wohnraumvermietung ist steuerfrei (§ 4 Nr. 12 UStG). Die Option nach § 9 UStG ist für Wohnzwecke ausgeschlossen, damit gibt es **keinen Vorsteuerabzug** (§ 15 Abs. 2 UStG). **Alle Bau- und Sanierungskosten sind brutto (19 %) anzusetzen**, ebenso beim Selbstnutzer. (Gesetzeskenntnis.)
  - **Nullsteuersatz § 12 Abs. 3 UStG** für Lieferung und Installation von PV-Anlagen und Speichern bis 30 kWp (laut MaStR) auf oder bei Wohnungen.
  - Mischnutzung (Gewerbeeinheiten mit Option), Vorsteueraufteilung (§ 15 Abs. 4) und Berichtigung über 10 Jahre (§ 15a) sind komplex und gehören in v2.
  - Kleinunternehmergrenzen § 19 UStG (seit 2025): 25.000 € Vorjahr, 100.000 € laufendes Jahr. Relevant für PV oder Mieterstrom.

---

## 4. Bewertungsmatrix

**Definitionen**

- **Komplexität:**
  - *niedrig*: Formel oder Parameter, keine Sachverhaltswertung, unter 1 PT;
  - *mittel*: bedingte Regeln, Fristen, Zustände oder Zusatzdaten nötig, 1–5 PT;
  - *hoch*: Sachverhaltswürdigung oder unternehmensweite Größen, ohne Fachwissen fehleranfällig, über 5 PT oder auf Projektebene nicht sinnvoll automatisierbar.
- **Entscheidungsrelevanz:**
  - *hoch*: kann Vorzeichen oder Rangfolge ändern, Effekt typisch über 5 % der Investitionssumme (Barwert);
  - *mittel*: spürbarer Niveaueffekt, Rangfolge selten betroffen;
  - *niedrig*: Rand- oder Nischeneffekt.
- **Empfehlung:**
  - **v1** = Pflicht in v1;
  - **v1-L** = im optionalen „Steuer-Light“-Modul;
  - **v1-S** = Selbstnutzer-Baustein;
  - **v2** = spätere Version;
  - **IF** = nur Schnittstelle vorsehen;
  - **aus** = außerhalb des Scopes, Hinweistext.

| Nr | Element | Persp. | Kernregel 2026 (Kurz) | Komplexität | Relevanz | Empf. |
|---|---|---|---|---|---|---|
| 1 | Konstanter Grenzsteuersatz inkl. Soli/KiSt | PV | Nutzereingabe, z. B. 44,31 % | niedrig | hoch | v1-L |
| 2 | Tarif § 32a als Differenzverfahren mit Einkommenspfad | PV | Zonen 2026, ab 2027 Entwurf | niedrig (Formel) / mittel (Pfad) | mittel | v2 |
| 3 | Soli mit Freigrenze und Milderungszone | PV | 20.350/40.700 €; 11,9 % | niedrig | niedrig–mittel | v2 |
| 4 | Kirchensteuer inkl. SA-Abzug | PV | 8/9 % | niedrig | niedrig | v2 (im Satz pauschal) |
| 5 | Lineare AfA § 7 Abs. 4 | PV, WU | 3 % / 2 % / 2,5 %, pro rata | niedrig | hoch | v1-L |
| 6 | Degressive AfA § 7 Abs. 5a + Wechsel | PV, WU | 5 % Restwert, Baubeginn 10/2023–09/2029 | niedrig–mittel | hoch (Neubau) | v1-L |
| 7 | Sonder-AfA § 7b inkl. Prüfungen | PV (WU) | 5 % × 4; EH40-QNG; 5.200/4.000 €/m²; 10 J. | mittel | hoch (Neubau) | v1-L (Rechnung), v2 (Rückgängigmachung) |
| 8 | Einordnung Erhaltung oder HK | PV, WU | BMF 26.01.2026 (3-von-4, Erweiterung) | **hoch** (Sachverhalt) | **hoch** (Sanierung) | v1-L als Nutzer-Tag mit Default je Maßnahmentyp; Regelprüfung v2 |
| 9 | Anschaffungsnahe HK § 6 Abs. 1 Nr. 1a | PV, WU | > 15 % netto in 3 J. | niedrig–mittel | hoch (Kauf + Sanierung) | v1-L (Prüfregel) |
| 10 | Verteilung § 82b EStDV | PV | 2–5 Jahre | niedrig | mittel | v1-L |
| 11 | Schuldzinsen, vorweggenommene WK | PV, WU | voll abziehbar | niedrig | hoch | v1-L |
| 12 | Disagio, Bereitstellungszinsen | PV, WU | § 11 Abs. 2 S. 4 | niedrig–mittel | niedrig | IF, v2 |
| 13 | Habenzinsen separat (Abgeltungsteuer) | PV, SN | 26,375 %; SPB 1.000/2.000 € | niedrig | mittel | v1-L / v1-S |
| 14 | Verlust sofort oder Vortrag | alle stpfl. | vertikaler Ausgleich; § 10d | niedrig (Schalter) | mittel–hoch | v1-L |
| 15 | Mindestbesteuerung, Rücktrag § 10d | PV, WU | Sockel 1 Mio.; 70 % bis 2027, dann 60 % | mittel | niedrig (Projekt) | v2 |
| 16 | § 23 EStG am Horizont | PV | 10 J.; AfA erhöht Gewinn | niedrig–mittel | mittel–hoch | v1-L (einfach) |
| 17 | Investitionszuschüsse (R 21.5) | PV, WU | Minderung HK ab Bewilligung / WK-Minderung | mittel | mittel | v1-L |
| 18 | Tilgungszuschuss (unbar) | PV, WU | wie Zuschuss; mindert Valuta | mittel | mittel | IF v1, Behandlung v1-L |
| 19 | Laufende Förderzuschüsse | PV, WU | Einnahmen | niedrig | mittel (Sozialwohnungen) | v1-L |
| 20 | § 7b-Rückgängigmachung, § 7b/§ 7 Abs. 5a-Fristprüfung | PV | Frist- und Statusprüfung | mittel | mittel | v2 (v1-L: Warnung) |
| 21 | Kaufpreisaufteilung Boden/Gebäude | PV, WU | BMF-Arbeitshilfe; § 6f-E (Entwurf) | mittel | mittel (Bestandskauf) | IF (Nutzereingabe Anteil) |
| 22 | Restnutzungsdauer-Gutachten § 7 Abs. 4 S. 2 | PV, WU | kürzere ND nachweisbar | niedrig (Override) | mittel (Bestand) | IF |
| 23 | §§ 7h/7i Denkmal, Sanierungsgebiet | PV | erhöhte Absetzungen | mittel | hoch (Nische) | v2 |
| 24 | § 21 Abs. 2 verbilligte Vermietung | PV | < 50 % / ≥ 66 % | niedrig | niedrig | aus (Hinweis) |
| 25 | PV § 3 Nr. 72 EStG | PV, SN | steuerfrei ≤ 30 kWp/Einheit | niedrig | niedrig | v1 (Tag „steuerfrei“) |
| 26 | Objekt steuerneutral (keine WK, kein Nutzungswert) | SN | Konsumgutlösung | trivial | hoch (muss korrekt sein) | v1 (Sperre Pauschalmodul) |
| 27 | § 35c EStG gegen BEG | SN | 7/7/6 %, max. 40.000 €, Abschluss < 2030 | niedrig–mittel | **hoch** | v1-S |
| 28 | § 35a Handwerkerleistungen | SN | 20 %/1.200 € (2026); ab 2027 Entwurf 15 %/900 € | niedrig | niedrig | v2 |
| 29 | KSt + Soli mit Senkungspfad | WU | 15 % → 10 % (2028–2032) | niedrig | mittel | v1-L (Zeitreihe) |
| 30 | GewSt mit/ohne erweiterte Kürzung | WU | 20 %/5 %-Grenzen; Mindesthebesatz 280 % ab 2027 | mittel (Satz) / hoch (Statusprüfung) | hoch (bei Verlust der Kürzung) | v1-L als Satz-Schalter; Prüfung v2 |
| 31 | GewSt-Hinzurechnung § 8 Nr. 1 | WU | 25 % über 200 T€ | mittel | mittel (ohne Kürzung) | v2 |
| 32 | Vermietungsgenossenschaft § 5 Abs. 1 Nr. 10 | WU | befreit; 10 %/30 %-Grenze | niedrig (Flag) | hoch | v1 (Satz 0 + Warnung) |
| 33 | Wohngemeinnützigkeit § 52 Abs. 2 Nr. 27 AO | WU | befreit; Mietobergrenze | niedrig (Flag) / mittel (Mietrestriktion) | hoch (kommunal, eG) | v1 (Flag), v2 (Restriktion) |
| 34 | Kommunal: Querverbund, BgA, Verlustvorträge | WU | unternehmensindividuell | hoch | mittel | aus (Verlustmodus-Schalter) |
| 35 | Zinsschranke § 4h | WU | 30 % EBITDA; 3 Mio. Freigrenze | hoch (Unternehmensebene) | niedrig (Projekt) | aus |
| 36 | Organschaft | WU | Ergebniszurechnung | hoch | niedrig (Projekt) | aus (Verlustmodus „sofort“) |
| 37 | HGB- gegen Steuerbilanz-Vorschau | WU | AfA-ND, latente Steuern | hoch | niedrig (Zahlung) / mittel (Ausschüttung) | v2+ |
| 38 | Degressive AfA bewegliche WG 30 % | PV, WU | 07/2025–12/2027 | niedrig | niedrig | v2 |
| 39 | Veräußerungsgewinn KapGes, § 6b | WU | stets steuerpflichtig | mittel | mittel | v1-L (einfach), § 6b aus |
| 40 | Gesellschafterebene (Ausschüttung) | WU | TEV/Abgeltung | hoch | niedrig für Projektentscheidung | aus |
| 41 | **USt: Bruttokosten, kein Vorsteuerabzug** | alle | § 4 Nr. 12, § 15 UStG | niedrig | **hoch** | **v1** |
| 42 | USt-Nullsatz PV | alle | § 12 Abs. 3 UStG | niedrig | niedrig | **v1** |
| 43 | USt-Mischnutzung, § 15a | WU, PV | Vorsteueraufteilung | hoch | mittel (nur gemischt) | v2 |
| 44 | **Grunderwerbsteuer** | alle (Erwerb) | 3,5–6,5 %; einheitlicher Vertrag | niedrig | **hoch** (Erwerbsfälle) | **v1** |
| 45 | **Grundsteuer** | alle | umlagefähig; Leerstand/Bauphase/SN | niedrig | mittel | **v1** |

**Verdichtung:**

- Die **hohen Komplexitäten** liegen nicht im Rechenkern. Sie liegen in der **Einordnung** (Nr. 8), in **Statusprüfungen auf Unternehmensebene** (Nr. 30, 34–37) und in **investorenspezifischen Einkommensdaten** (Nr. 2).
- Die **hohen Relevanzen bei geringer Komplexität** (Nr. 1, 5, 6, 9, 11, 14, 16, 27, 41, 44) sprechen für ein schlankes, klar begrenztes Modul in v1.

---

## 5. Gesamtbewertung je Perspektive

| Perspektive | Steuerregime | Fehler eines VoFi vor Steuern | Vollständige Abbildung | Fazit |
|---|---|---|---|---|
| Privater Vermieter | ESt progressiv, § 20 getrennt, § 23 | **groß, auch für die Rangfolge**: AfA/Sonder-AfA, Sofortabzug Erhaltung, steuerfreier Endwert | hoch (Tarifpfad, Einordnung, Fristen) | vereinfachtes Modul in v1 sinnvoll |
| Selbstnutzer | Objekt neutral; § 35c; Abgeltungsteuer der Alternative | klein, **außer** BEG gegen § 35c und Habenzins brutto | niedrig | gezielte Bausteine statt Steuermodul |
| WU KapGes mit erweiterter Kürzung | 15,825 % → 10,55 % | mittel (Niveau), Rangfolge selten | mittel; Kürzungsstatus hoch | Pauschalsatz genügt für das Projekt-Screening |
| WU KapGes ohne Kürzung | ca. 30 % → ca. 26 % (mit Hinzurechnung) | mittel–groß | mittel–hoch | Pauschalsatz, Hinzurechnung v2 |
| Vermietungsgenossenschaft (befreit) | 0 % | keiner (solange befreit) | niedrig | Satz 0 + Warnung |
| Gemeinnützig (Wohngemeinnützigkeit) | 0 %, Mietrestriktion | keiner bei Steuern; **Ertragsseite** betroffen | mittel | Flag + Mietobergrenze |
| Kommunal mit Verlustvorträgen | effektiv ca. 0 % für Jahre | gering | hoch (Unternehmensebene) | Verlustmodus-Schalter |

**Antwort auf die Nutzerfrage:** Das „Ausklammern“ ist **für Selbstnutzer, Genossenschaften und kommunale Unternehmen in v1 vertretbar**. Für **private Vermieter** ist es **nicht unproblematisch**, weil ein VoFi vor Steuern hier systematisch zu konservativ sein kann (Sanierung und Neubau mit Sonder-AfA wirken unattraktiver) und die Varianten anders reiht. Eine vollständige Modellierung ist für v1 dennoch unverhältnismäßig. Daher der Mittelweg aus Abschnitt 6.

---

## 6. Empfehlung v1 und v2

### 6.1 Umfang v1 (Pflicht)

1. **VoFi vor Ertragsteuern** als Primärergebnis für alle Perspektiven (Endwert, VoFi-Rendite, Kennzahlen).
   - Die Zeile „Ertragsteuern“ ist im VoFi **sichtbar** und mit 0 gefüllt. Sie trägt die Kennzeichnung „nicht berücksichtigt“, damit Nutzer die Annahme wahrnehmen.
2. **Steuerfähige Architektur nach Abschnitt 7:**
   - granulares Zahlungsbuch mit Steuer-Tags, Anlagenregister, Maßnahmenregister und versionierten Steuerparametern;
   - Steuer-Hook in der Periodenschleife, aufgerufen mit dem **Null-Modul** (`tax_none`).
   - Das Null-Modul läuft in jedem Rechenlauf. Damit ist der Codepfad getestet.
3. **Nicht-Ertragsteuern vollständig** (Abschnitt 8).
4. **Selbstnutzer-Bausteine (v1-S):**
   - **§ 35c-Generator**: erzeugt Zahlungsströme 7/7/6 % in den VZ nach Abschluss, gedeckelt auf 40.000 €. Ist für eine Maßnahme BEG/KfW gewählt, wird er **automatisch gesperrt**. Der Nutzer muss bestätigen, dass eine ausreichende tarifliche ESt vorhanden ist. Das ermöglicht den Variantenvergleich „BEG gegen § 35c“.
   - **Option „Habenzins nach Abgeltungsteuer“** für private Investoren (Selbstnutzer und Vermieter), Default an für Selbstnutzer, mit einer Erläuterung.
5. **Regime-Flags für Wohnungsunternehmen:** steuerbefreite Vermietungsgenossenschaft, gemeinnützig. Mit diesen Flags ist der Satz fest 0 und das Pauschalmodul ausgeschaltet. Es erscheint ein Warnhinweis bei relevanten Nebenerlösen (Strom, Gewerbe).

### 6.2 Optionales Pauschalsteuer-Modul („Steuer-Light“) in v1: lohnt es sich?

**Empfehlung: Ja, in v1 aufnehmen, als *Referenzimplementierung der Schnittstelle*, standardmäßig AUS, mit harten Sperren.**

Begründung:

- **Geringer Grenzaufwand:** Die Schnittstelle ist ohnehin nötig. Das Modul selbst umfasst wenige hundert Zeilen R und Tests. Grobe Schätzung: 5–8 PT zusätzlich zu 3–5 PT für die Schnittstelle.
- **Validierung der Schnittstelle:** Ein Hook ohne echte Implementierung „verrottet“, weil fehlende Felder erst beim späteren Modul auffallen und dann doch ein Refactoring nötig wird.
- **Größenordnung sichtbar:** Für private Vermieter zeigt das Modul die Größenordnung von AfA- und Sofortabzugseffekten, also genau dort, wo das Ergebnis vor Steuern am stärksten irreführt.

**Spezifikation des Moduls (v1-L):**

- **Steuerliches Ergebnis der Periode** (je Steuersubjekt):
  E_t = steuerpflichtige Einnahmen (Miete, laufende Zuschüsse, sonstige steuerpflichtige Erlöse)
  − abzugsfähige Aufwendungen (inkl. nicht umgelegter Grundsteuer)
  − Erhaltungsaufwand (sofort oder nach § 82b verteilt, gemindert um Zuschüsse)
  − AfA (§ 7 Abs. 4 linear oder § 7 Abs. 5a degressiv, + § 7b, je Anlage; Bemessungsgrundlage gemindert um Investitionszuschüsse ab Bewilligung)
  − Sollzinsen (exogene Darlehen + Kontokorrent)
  [+ Habenzinsen nur bei Unternehmen]
- **Satz s_t** als Zeitreihe:
  - privat: konstanter Grenzsteuersatz inklusive Soli und KiSt als Nutzereingabe, Default 44,31 %, mit Hinweis auf das Einkommensprofil;
  - Unternehmen: KSt+Soli-Pfad 15,825 % → 10,55 % plus wahlweise GewSt-Satz (0 % bei erweiterter Kürzung, sonst 3,5 % × Hebesatz ≥ 280 % ab 2027).
- **Habenzinsen privat:** separat mit 26,375 % (mit KiSt-Option), optional Sparer-Pauschbetrag. Verluste werden nicht mit V+V verrechnet.
- **Verlustmodus:**
  - `sofort`: negative Steuer = Erstattung; Default für Arbeitnehmer-Vermieter und Unternehmen mit Gewinnen oder Organkreis;
  - `vortrag`: projektinterner Vortrag ohne Mindestbesteuerung; Default für Projektgesellschaften.
- **Zahlungszeitpunkt:** `lag = 0` (Vorauszahlung oder Lohnsteuer-Freibetrag) oder `lag = 1` (Veranlagung), Default 1. Die am Horizont offene Steuer wird im Endwert berücksichtigt (7.11).
- **Prüfregeln mit Warnung:**
  - anschaffungsnahe HK: Summe netto in 3 Jahren > 15 % → Umgliederung zu HK, auf Wunsch automatisch;
  - § 7 Abs. 5a/§ 7b-Zeitfenster (Daten im Anlagenregister) und § 7b-Grenzen 5.200/4.000 €/m²;
  - Horizont < 10 Jahre bei privat mit Restwert → § 23-Steuer (Gewinn = Erlös − (AK/HK − kumulierte AfA)) × s;
  - Unternehmen: Restwert gegen Restbuchwert wird stets versteuert.
- **Ausgabe:** Nach-Steuer-VoFi **immer parallel** zum Vor-Steuer-VoFi; dazu die steuerliche Nebenrechnung als eigene Tabelle (Ergebnis, AfA je Anlage, Verlustvortrag, Steuer).

**Irreführungsrisiken und Schutzmechanismen:**

| Risiko | Wirkung | Schutz |
|---|---|---|
| **Anwendung auf Selbstnutzer** | Abzug von Zinsen und AfA erzeugt fiktive Erstattungen. Werden Energieersparnis oder Mietersparnis als „Einnahme“ getaggt, entsteht eine fiktive Steuer. Beides ist grob falsch. | **Hart gesperrt** für Perspektive Selbstnutzer. Stattdessen nur v1-S (§ 35c, Abgeltungsteuer). |
| Anwendung auf befreite Rechtsträger | Fiktive Steuerlast | Gesperrt bei den Flags eG-befreit und gemeinnützig |
| Falsche Einordnung Erhaltung/HK | Barwertfehler von rund 20–30 % der Investition (3.1.3) | Pflichtfeld je Maßnahme mit Default je Maßnahmentyp nach BMF 26.01.2026; Quelle der Einordnung wird angezeigt; Sensitivität „als HK“ und „als Erhaltung“ als Schnellvergleich |
| Konstanter Grenzsteuersatz trotz Progression oder Ruhestand | Überschätzung der Steuerwirkung, besonders bei hohem Sofortabzug | Hinweis; § 82b-Verteilung anbieten; Grenzsteuersatz als Zeitreihe bzw. MC-Verteilung zulassen |
| „Sofortiger Verlustausgleich“ ohne ausreichende andere Einkünfte | Erstattungen, die real nicht fließen | Nutzer gibt das übrige zvE grob an; Warnung, wenn ein Projektverlust dieses übersteigt; sonst Modus Vortrag |
| Steuerfreier Endwert wird übersehen oder unterstellt | Fehler am Horizont | automatische § 23-Prüfung; Kennzeichnung „Restwert realisiert/hypothetisch“ |
| Scheingenauigkeit | Vertrauen in Nach-Steuer-Zahlen ohne Beratung | Label „vereinfachte Näherung – keine Steuerberatung“; Ergebnis vor Steuern bleibt Primärergebnis |

### 6.3 Umfang v2 (Roadmap)

1. **Vollmodul privat:**
   - § 32a-Differenzverfahren mit Einkommenspfad (Einzel- oder Zusammenveranlagung), Soli mit Milderungszone, KiSt mit SA-Abzug;
   - § 10d vollständig;
   - § 7b-Rückgängigmachung, § 35a, §§ 7h/7i;
   - Disagio-Verteilung;
   - Regelprüfung Standardhebung (3-von-4) anhand des Maßnahmenregisters.
2. **Unternehmen:**
   - GewSt-Hinzurechnung, einfache und erweiterte Kürzung mit Nebenerlös-Quoten (20 %/5 %);
   - Genossenschafts-Quote (10 %/30 %);
   - Mindestbesteuerung (KSt/GewSt getrennt);
   - Vorauszahlungssystematik;
   - optional HGB-Vorschau.
3. **USt:** Mischnutzung, Vorsteueraufteilung, § 15a.
4. **Wohngemeinnützigkeit** als Mietobergrenze in der Ertragslogik.
5. **Rechtsstand-Updates:** Tarif 2027/2028 nach Verabschiedung, § 6f EStG nach Verkündung, Auslaufen der Fristen 2027/2029.

---

## 7. Schnittstellenspezifikation VoFi-Engine ↔ Steuermodul

### 7.1 Designprinzipien

1. **Granularität statt Saldo:** Die Engine hält ein **Zahlungsbuch** (ein Datensatz je Zahlungsstrom-Definition) und nicht nur periodische Nettosalden. Ein VoFi vor Steuern bräuchte nur Salden. Ohne das Buch wäre ein Steuermodul später aber nur mit Refactoring möglich.
2. **Zahlung und steuerliche Erfassung trennen:**
   - Herstellungskosten fließen in der Bauphase ab, die AfA beginnt aber erst ab Fertigstellung.
   - Zuschüsse wirken ab Bewilligung.
   - Erhaltungsaufwand folgt dem Abflussprinzip bzw. der Verteilung nach § 82b.
   - Der Tilgungszuschuss ist unbar.
3. **Steuer ist eine Funktion des Zustands bis einschließlich t**, nie von Größen aus t+1. Mit nachschüssiger Zinskonvention entsteht keine Zirkularität.
4. **Perspektive als Regime:** Das Modul bestimmt aus der Perspektive (`privat_vermieter`, `selbstnutzer`, `wu_kapges`, `wu_eg_befreit`, `wu_eg_stpfl`, `wu_kommunal`, `wu_gemeinnuetzig`), welche Tags wie wirken. Die Engine bleibt perspektivenagnostisch.
5. **Vektorisierung über Monte-Carlo-Pfade:** Alle Mengen sind Vektoren der Länge `n_sim` je Periode. Die Schleife läuft nur über die Perioden.
6. **Parameter versioniert** nach VZ, mit Gültigkeitszeitraum und Quelle. Es gibt keine fest verdrahteten Sätze.

### 7.2 Steuer-Tags (`tax_category`)

| Code | Bedeutung / Beispiele | Privat-Vermieter | Selbstnutzer | WU (stpfl.) |
|---|---|---|---|---|
| `income_rental` | Kaltmiete, Stellplatz, Zuschläge | steuerpflichtig (V+V) | – | steuerpflichtig |
| `income_other_taxable` | Stromverkauf außerhalb § 3 Nr. 72, Gewerbe-Nebenerlöse (Attribut `activity_type` für Kürzungs- und eG-Quoten) | steuerpflichtig | – | steuerpflichtig (Statusrisiko) |
| `income_tax_exempt` | PV nach § 3 Nr. 72 EStG | 0 | 0 | 0 (nach h. M. über § 8 Abs. 1 KStG auch für Körperschaften; vor Implementierung prüfen) |
| `imputed_benefit` | ersparte Miete, Energieeinsparung (nicht steuerbar) | – | **nicht steuerbar** | – |
| `passthrough` | Betriebskosten-Umlagen und umlagefähige BK (Saldo 0) | neutral | – | neutral |
| `expense_deductible` | Verwaltung, laufende Instandhaltung, nicht umgelegte BK, Grundsteuer bei Leerstand, Versicherung | abziehbar | **nicht** abziehbar | abziehbar |
| `expense_nondeductible` | private bzw. nicht abziehbare Kosten | 0 | 0 | 0 |
| `capex_depreciable` | HK/AK Gebäude, Außenanlagen, bewegliche WG (mit `asset_id`) | AfA | – | AfA |
| `capex_land` | Grund und Boden (nicht abschreibbar) | 0 (Basis für § 23) | – | 0 (Basis Veräußerung) |
| `capex_expensable` | Erhaltungsaufwand (mit `measure_id`, Option `spread_years` 1–5) | sofort oder § 82b | – (§ 35c/§ 35a über Maßnahme) | sofort |
| `acquisition_ancillary` | GrESt, Notar, Grundbuch, Makler (mit `allocation_key` Boden/Gebäude) | AK-Zuschlag | – | AK-Zuschlag |
| `subsidy_investment` | BEG-/Landeszuschuss zu Maßnahme oder Anlage (`approval_period`) | mindert HK bzw. Erhaltung | sperrt § 35c | Wahlrecht R 6.5 |
| `subsidy_repayment_grant` | **Tilgungszuschuss** (unbar, `cash = FALSE`, mindert Valuta) | wie `subsidy_investment` | sperrt § 35c | wie oben |
| `subsidy_operating` | laufende Aufwendungs- oder Belegungszuschüsse | Einnahme | – | Ertrag |
| `interest_expense` | Sollzinsen exogener Darlehen und Kontokorrent; Gebühren; Disagio (`spread_periods`) | WK | **nicht** abziehbar | BA (GewSt-Hinzurechnung v2) |
| `interest_income` | Habenzinsen der Ergänzungsinvestition | **§ 20 separat** | § 20 separat | im Gewinn (GewSt nicht gekürzt) |
| `principal` | Darlehensauszahlung, Tilgung | neutral | neutral | neutral |
| `equity` | EK-Einlage, Entnahme | neutral | neutral | neutral |
| `disposal_proceeds` | Veräußerungserlös / Restwert (`realization = actual/hypothetical`) | § 23-Prüfung | steuerfrei | steuerpflichtig vs. Buchwert |
| `tax_credit` | **Output** des Moduls: § 35c, § 35a | – | Gutschrift | – |
| `tax_payment` | **Output** (reserviert): ESt/KSt/GewSt/Soli/KiSt/Abgeltung | – | – | – |

Die Nicht-Ertragsteuern sind normale Kostenpositionen mit Attribut `is_tax ∈ {grundsteuer, grunderwerbsteuer, umsatzsteuer}`:

- GrESt → `acquisition_ancillary`;
- Grundsteuer → `passthrough` bzw. `expense_deductible`;
- USt → Bestandteil von `amount_gross`.

### 7.3 Attribute je Zahlungsstrom (Zahlungsbuch)

| Feld | Typ | v1 Pflicht | Zweck |
|---|---|---|---|
| `flow_id` | chr | ja | Schlüssel |
| `period` | int | ja | VoFi-Periode der **Zahlung** (0…T) |
| `date` | Date | empfohlen | pro rata temporis, VZ-Zuordnung, Fristen (§ 7 Abs. 5a, § 7b, § 35c, § 23) |
| `vofi_row` | factor | ja | Zeile im VoFi (Investition, Betrieb, Finanzierung, Förderung, Transaktionskosten, Restwert …) |
| `amount_gross` | num je Pfad | ja | Vorzeichen: + Einzahlung / − Auszahlung |
| `amount_net`, `vat_amount`, `vat_rate` | num | **ja** | USt-Trennung (15 %-Test netto; Vorsteuer v2; USt-Szenarien) |
| `vat_recoverable` | lgl | ja (Default FALSE) | Vorsteuerabzug (v2: Mischnutzung, PV-Verkauf) |
| `cash` | lgl | ja | FALSE für unbare Vorgänge (Tilgungszuschuss) |
| `tax_category` | factor | **ja** | Haupt-Tag (7.2) |
| `asset_id` | chr | bei capex/subsidy | Zuordnung zum Anlagenregister |
| `measure_id` | chr | bei Bau- und Sanierungsmaßnahmen | Einordnung, Förderung, § 35c |
| `tax_period` | int | optional | steuerliche Erfassung, falls ≠ `period` (z. B. Bewilligungsjahr) |
| `spread_years` | int | optional | § 82b (2–5), Disagio |
| `use_share_rented` | num 0–1 | optional (Default 1/0 je Perspektive) | Mischnutzung (teils selbstgenutzt) |
| `program` | chr | bei Förderung | BEG/KfW/Land → Kumulierung, § 35c-Sperre |
| `activity_type` | chr | bei Nebenerlösen | Quoten erweiterte Kürzung (20 %/5 %), eG (10 %/30 %) |
| `driver` | chr | optional | MC-Treiber (Miete, Baukosten, Zins …) für Auswertung |

**Monte-Carlo-Speicherung:** Die Metadaten liegen als `data.frame`, eine Zeile je Strom. Die Beträge werden je **Steuerschlüssel** (`tax_category × asset_id × measure_id`) zu Matrizen `[n_sim × T]` aggregiert. Bei großen `n_sim` wird in Blöcken gerechnet (z. B. 1.000 Pfade je Chunk). Die volle Strom × Pfad × Periode-Matrix ist zu groß und unnötig.

### 7.4 Anlagenregister (Abschreibungsobjekte)

| Feld | Zweck |
|---|---|
| `asset_id`, `asset_type` | `gebaeude_wohnen`, `gebaeude_nichtwohnen`, `grund_boden`, `aussenanlage`, `bewegliches_wg`, `pv_anlage`, `ladeinfrastruktur` |
| `in_service_date` | Fertigstellung bzw. Anschaffung → AfA-Beginn, pro rata (Monat) |
| `construction_start_date` | Baubeginnsanzeige → § 7 Abs. 5a-Fenster |
| `building_application_date` | Bauantrag/Bauanzeige → § 7b-Fenster |
| `original_completion_year` | bei Bestand: Satz 2 % / 2,5 % / 3 % |
| `acquisition_date`, `acquisition_cost_building` | anschaffungsnahe HK (3 J., 15 %), § 23-Frist |
| `living_area_m2`, `efficiency_standard`, `qng` | § 7b-Prüfung (5.200/4.000 €/m², EH40-QNG) |
| `afa_method` | `linear`, `degressiv_5a`, `+sonder_7b`, `override` (Gutachten-ND) |
| `useful_life_override` | Restnutzungsdauer-Nachweis |
| `land_share` | Kaufpreisaufteilung (Nutzereingabe; später § 6f-Logik) |

Die Bemessungsgrundlage ist **keine Eingabe**. Das Modul bildet sie aus den `capex_depreciable`- und `acquisition_ancillary`-Strömen mit `asset_id` abzüglich `subsidy_*`. Das macht MC-Kostenschwankungen automatisch AfA-wirksam.

### 7.5 Maßnahmenregister

`measure_id`, `measure_type` (`neubau`, `erweiterung`, `aufstockung`, `daemmung_fassade`, `daemmung_dach`, `fenster`, `heizung_tausch`, `pv`, `sanitaer`, `elektro`, `lueftung` …), dazu:

- `central_feature_area` und `standard_before`/`standard_after` (für die 3-von-4-Prüfung, v2);
- `classification` ∈ {`erhaltung`, `herstellung`, `auto`} mit `classification_source` (Nutzer, Regel, Default);
- `completion_date` und `paid_in_full_date` (§ 35c);
- `contractor_certified` (§ 35c);
- `funding_choice` ∈ {`beg_zuschuss`, `beg_kredit`, `35c`, `keine`}.

Defaults je Maßnahmentyp nach BMF 26.01.2026:

- Dämmung, Fenstertausch und Heizungstausch im Bestand → `erhaltung`;
- Neubau, Erweiterung und Aufstockung → `herstellung`;
- Kauf + Sanierung → `auto` (15 %-Test).

### 7.6 Steuerparameter (versioniert)

Die Parameter liegen als Datei je Rechtsstand, z. B. `inst/params/steuern_DE.yaml`, mit `valid_from`, `valid_to` und `quelle`:

- Tarif-ID je VZ (`32a_2026`, später `32a_2027`…);
- Soli (Freigrenzen, Milderungssatz);
- KiSt-Sätze;
- Abgeltungsteuersatz, Sparer-Pauschbetrag;
- KSt-Pfad (2026–2032 ff.);
- GewSt (Messzahl, Mindesthebesatz 200 %/280 %);
- § 10d-Parameter (Sockel, 70 %/60 %);
- AfA-Fenster (§ 7 Abs. 5a, § 7b, § 7 Abs. 2);
- § 35c-Fenster und -Sätze;
- § 35a;
- anschaffungsnahe HK (15 %, 3 J.);
- § 23-Frist;
- Grunderwerbsteuer je Land mit Gültigkeit.

Szenarien (z. B. „Recht 2026 fortgeschrieben“ gegen „Entwurf ESt-Reform 2027“) werden als Parametersätze ausgewählt.

### 7.7 Steuerzustand (je MC-Pfad, in der Periodenschleife fortgeschrieben)

| Zustand | Inhalt |
|---|---|
| `loss_cf` | Verlustvortrag je Steuerart (V+V-intern bei Modus Vortrag; KSt; GewSt) |
| `book_value[asset]` | Restbuchwert je Anlage (für degressive AfA, Wechsel, § 23-Gewinn, Restwertbesteuerung) |
| `afa_cum[asset]`, `sonder_used[asset]` | kumulierte AfA bzw. § 7b-Jahre (Rückgängigmachung v2) |
| `spread_queue` | noch nicht abgezogene § 82b- bzw. Disagio-Raten |
| `tax_due` | festgesetzte, noch nicht gezahlte Steuer (bei `lag = 1`) |
| `credit_queue` | § 35c-Tranchen (Selbstnutzer) |
| `acq_window` | Kostensumme netto seit Anschaffung (15 %-Test) |
| `spb_left` | Sparer-Pauschbetrag (optional) |

### 7.8 Periodenschleife und Zinskonvention

**Konvention (Pflicht v1):**

- Zinsen der Periode t werden auf die **Bestände am Ende von t−1** berechnet (nachschüssig).
- Exogene Darlehen (Annuitäten-, Förderdarlehen) haben vorab berechnete Zins- und Tilgungspläne. Sie sind **unabhängig** von der Steuer.
- Nur die endogenen Ausgleichskonten (Kontokorrent, Ergänzungsinvestition) reagieren auf die Steuer.

**Schleife (R-Skizze, vektorisiert über Pfade):**

```r
# K: Kontokorrent-Bestand, G: Guthaben (Ergänzungsinvestition); Vektoren der Länge n_sim
state <- tax_init(module, params, assets, measures, n_sim)
for (t in seq_len(T)) {
  # 1) Zinsen der endogenen Konten aus Beständen t-1
  z_soll  <- r_soll[, t]  * K_prev
  z_haben <- r_haben[, t] * G_prev

  # 2) Steuer der Periode: hängt nur von Informationen bis t ab -> keine Zirkularität
  res   <- tax_step(module, t,
                    inputs   = tax_inputs[[t]],          # aggregierte Steuerschlüssel [n_sim]
                    interest = list(exo_soll = zins_exo[, t], endo_soll = z_soll,
                                    endo_haben = z_haben),
                    state    = state, params = params)
  state <- res$state                                      # Verlustvortrag, Buchwerte, tax_due ...

  # 3) Finanzierungssaldo vor Ausgleich (Steuerzahlung: res$payment; Erstattung negativ)
  saldo <- cf_exo_cash[, t] - z_soll + z_haben - res$payment

  # 4) Ausgleich: Überschuss tilgt erst Kontokorrent, dann Anlage; Defizit löst erst Guthaben auf, dann Kontokorrent
  bal    <- balance_accounts(saldo, K_prev, G_prev)
  K_prev <- bal$K; G_prev <- bal$G
  report[[t]] <- res$report                               # steuerliche Nebenrechnung (Audit)
}
terminal <- tax_finalize(module, T, state, terminal_inputs, params)  # offene Steuer, § 23, Restwertsteuer
```

- **Zirkularität** entstünde nur bei Zinsen auf Durchschnitts- oder Endbestände derselben Periode oder bei unterjährigen Perioden mit Jahressteuer. Diese Varianten werden in v1 **nicht** angeboten. Falls später nötig, wird eine Fixpunkt-Iteration (2–3 Schritte) innerhalb von t verwendet.
- **Unterjährige Perioden** (falls gewünscht): Das Modul akkumuliert bis zum VZ-Ende und setzt die Steuer im Periodenmonat des Zahlungstermins an. Für v1 werden **Jahresperioden = VZ** empfohlen.

### 7.9 Haben- und Sollzinsen der VoFi-Finanzierungszeilen in der Bemessungsgrundlage

| Perspektive | Sollzinsen (exogen + Kontokorrent) | Habenzinsen (Ergänzungsinvestition) |
|---|---|---|
| Privat-Vermieter | Werbungskosten V+V (Vereinfachung: auch Kontokorrent für Steuerzahlungen) | **§ 20, Abgeltungsteuer separat**, keine Verrechnung mit V+V-Verlusten |
| Selbstnutzer | nicht abziehbar | § 20, Abgeltungsteuer (Option v1-S) |
| KapGes / eG steuerpflichtig | Betriebsausgabe (v2: GewSt-Hinzurechnung ohne Kürzung) | Ertrag im Gewinn; bei erweiterter Kürzung **nicht** gekürzt (GewSt-pflichtig) |
| eG befreit / gemeinnützig | – | – (KapESt-Erstattung bzw. Abstandnahme außerhalb des Scopes) |

### 7.10 Zahlungszeitpunkt

- Parameter `lag ∈ {0, 1}` je Steuerart. v2: Vorauszahlungen auf Basis des Vorjahres plus Abschlusszahlung.
- **§ 35c-Tranchen** werden in den Veranlagungsjahren nach Abschluss ausgezahlt (Default t+1, t+2, t+3).
- **Erstattungen bei `lag = 1`** werden in t über das Kontokorrent vorfinanziert. Das ist realistisch und wird von der Schleife automatisch abgebildet.

### 7.11 Horizont, Endwert, Restwert

- `tax_finalize()` liefert die **am Horizont offene Steuer**: die Steuer für T bei `lag = 1` und noch offene § 35c-Tranchen. Diese wird im Endwert als Verbindlichkeit bzw. Forderung erfasst. Ohne diese Korrektur verbessert `lag = 1` das Ergebnis künstlich.
- **Restwert bzw. Liquidationserlös:**
  - privat: § 23-Prüfung (Frist ab `acquisition_date` bzw. Fertigstellung, Gewinn gegen AK/HK abzüglich kumulierter AfA);
  - Unternehmen: Steuer auf (Erlös − Restbuchwert);
  - Ist der Restwert nur **hypothetisch** (Ertragswert, kein Verkauf), bestimmt der Parameter, ob eine latente Steuer abgezogen wird (Default: ja bei Unternehmen, nach § 23-Status bei privat).
- **Verbleibender Verlustvortrag** wird mit 0 (Default, konservativ) oder mit s × Vortrag (bei Verwertbarkeit im Konzern) bewertet.

### 7.12 Modul-API (R, S3-Generics)

```r
tax_init(module, params, assets, measures, n_sim)                 # -> state
tax_step(module, t, inputs, interest, state, params)              # -> list(payment, state, report)
tax_finalize(module, T, state, terminal_inputs, params)           # -> list(payment_T, report)
# Klassen: "tax_none" (v1 Default), "tax_flat" (v1-L), "tax_selfuse" (v1-S: § 35c, Abgeltung),
#          später "tax_full_private", "tax_corporate"
```

- `report` enthält je Periode: steuerliches Ergebnis je Einkunftsquelle (V+V, KapV, Gewerbe), AfA je Anlage, Verlustvortrag Anfang/Ende, festgesetzte und gezahlte Steuer je Steuerart, Warnungen. Das ist die Grundlage der VoFi-Tabelle „steuerliche Nebenrechnung“.
- **Pflicht-Tests (v1):**
  1. `tax_none` ⇒ Nach-Steuer-VoFi ist identisch mit dem Vor-Steuer-VoFi.
  2. `tax_flat` mit s = 0 ⇒ identisch.
  3. **Standardmodell-Test:** s konstant, sofortiger Verlustausgleich, `lag = 0`, Soll = Haben = i, Zinsen voll steuerwirksam ⇒ der Endwert nach Steuern entspricht dem analytischen Wert mit Kalkulationszins i(1−s) und der Nach-Steuer-Zahlungsreihe.
  4. Die AfA-Summe über die Nutzungsdauer ist gleich der Bemessungsgrundlage.
  5. Selbstnutzer: `tax_flat` lässt sich nicht aktivieren.
  6. Das Ergebnis ist invariant gegen die Pfad-Chunk-Größe.

### 7.13 Monte-Carlo-Aspekte

- Steuerparameter können **stochastisch** sein: Grenzsteuersatzpfad, Hebesatz. **Regimewechsel** (Verlust der erweiterten Kürzung, Gesetzesänderung) werden besser als **Szenario** gerechnet als als Zufallsvariable.
- Kosten-, Zuschuss- und Mietpfade wirken automatisch auf die Bemessungsgrundlagen, weil diese im Modul aus dem Zahlungsbuch gebildet werden.
- Rechenaufwand: T ≈ 30–50 Perioden × n_sim ≈ 10⁴ mit vektorisierten Schritten. Das ist in R unkritisch, solange pro Periode nur Vektoroperationen laufen.

---

## 8. Nicht-Ertragsteuern: Pflichtumfang v1 (unabhängig vom Steuermodul)

1. **Umsatzsteuer als Kostenbestandteil:**
   - Alle Kosten werden für Wohnraumvermietung und Selbstnutzer **brutto** angesetzt (19 %; 7 % nur, wo einschlägig).
   - Netto und USt werden getrennt gespeichert. `vat_recoverable = FALSE` ist der Default.
   - PV-Lieferung und -Installation bis 30 kWp mit **0 %**.
   - Warnhinweis bei Gewerbeeinheiten oder Mischnutzung („Vorsteuerthematik nicht abgebildet“).
2. **Grunderwerbsteuer:**
   - Satz je Bundesland aus versionierter Tabelle.
   - Bemessungsgrundlage ist der Kaufpreis bzw. die Gegenleistung. Per Schalter **einheitlicher Vertragsgegenstand** wird die Bauleistung einbezogen.
   - Freigrenze 2.500 €.
   - Zeitpunkt ist der Erwerb.
   - Weitere Erwerbsnebenkosten (Notar, Grundbuch, ggf. Makler) als eigene Positionen.
   - Tag `acquisition_ancillary` mit Aufteilungsschlüssel Boden/Gebäude, damit das spätere Steuermodul die AfA-Basis korrekt bildet.
3. **Grundsteuer:**
   - Jahresbetrag (Messbetrag × Hebesatz bzw. direkte Eingabe) mit Steigerungsrate und Neubewertung ab Fertigstellung.
   - **Umlagefähig** beim Vermieter: getaggt als `passthrough`, aber **kostenwirksam** in Leerstand bzw. Mietausfall und in der Bauphase (unbebautes Grundstück, ggf. Grundsteuer C).
   - Beim Selbstnutzer voll kostenwirksam.

Nicht in v1: Erbschaft- und Schenkungsteuer, Zweitwohnungsteuer, Share-Deal-Themen der GrESt, Gesellschafterebene.

---

## 9. Offene Fragen an den Nutzer

1. **Zielgruppen-Priorität:** Sind private Vermieter in v1 eine Hauptzielgruppe? Wenn ja, wird das Pauschalmodul (6.2) dringend empfohlen. Wenn nein, kann es auf v1.1 verschoben werden, wobei die Schnittstelle in v1 bleibt.
2. **Periodenraster:** Jahresperioden = VZ (empfohlen) oder Monate bzw. Quartale (Bauphase)?
3. **Fallarten in v1:** Neubau auf eigenem Grundstück, Grundstückskauf + Neubau, **Bestandskauf + Sanierung** (dann sind die anschaffungsnahen HK zwingend), Sanierung im lange gehaltenen Bestand?
4. **Mischnutzung und Nebenerlöse:** Gewerbeeinheiten, Mieterstrom, Wärmelieferung in v1? Diese sind relevant für USt-Vorsteuer, erweiterte Kürzung und die eG-Befreiung.
5. **Endwertdefinition:** Verkauf am Horizont oder hypothetischer Restwert? Typische Horizontlänge (unter oder über 10 Jahre, wegen § 23)?
6. **Steuersatz privat:** Reicht ein vom Nutzer eingegebener Grenzsteuersatz, oder wird in v2 ein Einkommensprofil mit § 32a-Differenzverfahren gewünscht?
7. **Rechtsstand-Politik:** Nur geltendes Recht (inklusive beschlossener KSt-Pfad und Mindesthebesatz 280 %) oder zusätzlich Entwurfsszenarien (ESt-Reform 2027, JStG 2026/§ 6f)?
8. **Wohnungsunternehmen:** Sollen Wohngemeinnützigkeit (Mietobergrenze) und der Status der erweiterten Kürzung als Szenario-Schalter angeboten werden?
9. **Gesellschafterebene** (Ausschüttungen an Kommune oder Gesellschafter): Empfehlung „außerhalb des Scopes“. Ist das so bestätigt?

---

## 10. Risiken

| Risiko | Beschreibung | Gegenmaßnahme |
|---|---|---|
| Fehlentscheidung durch Rechnung vor Steuern | Für private Vermieter systematisch zu konservativ (Sanierung als Erhaltung, Neubau mit Sonder-AfA, steuerfreier Endwert), mögliche Umkehr der Rangfolge | Kennzeichnung im VoFi; Pauschalmodul optional; Hinweis in den Ergebnissen |
| Scheingenauigkeit der Nach-Steuer-Zahlen | Nutzer halten Näherungen für Steuerberatung | Ergebnis vor Steuern bleibt Primärergebnis; Label; Sensitivitäten |
| Einordnung Erhaltung/HK | größte Einzelfehlerquelle | Pflichtfeld mit Default nach BMF 26.01.2026, Anzeige der Quelle, Schnellvergleich |
| Rechtsänderungen | befristete Normen (2027/2029), Entwürfe (ESt-Reform 2027, JStG 2026), KSt-Pfad | versionierte Parameter mit Gültigkeit und Quelle; Szenarien |
| Unvollständige Schnittstelle | späteres Refactoring | Referenzmodul `tax_flat` in v1, Pflicht-Tests (7.12) |
| Unternehmensebene nicht abbildbar | Zinsschranke, Organschaft, Kürzungsstatus, Verlustvorträge | Schalter (Verlustmodus, Satz), Warnhinweise, Scope-Abgrenzung |
| Rechtliche Einordnung des Tools | Abgrenzung zur geschäftsmäßigen Hilfeleistung in Steuersachen bei externer Nutzung | Disclaimer; keine individuellen Steuerberechnungen ohne Nutzerangaben; ggf. juristische Prüfung bei Weitergabe |
| Performance Monte Carlo | Pro-Periode-Schleife in R | Vektorisierung über Pfade, Aggregation auf Steuerschlüssel, Chunking |

---

## 11. Quellen

**Gesetzestexte (konsolidiert):**

- § 32a EStG (Tarif ab VZ 2026): https://www.gesetze-im-internet.de/estg/__32a.html
- § 7 EStG (Abs. 2, 4, 5a): https://www.gesetze-im-internet.de/estg/__7.html
- § 7b EStG: https://lxgesetze.de/estg/7b
- § 35c EStG: https://www.gesetze-im-internet.de/estg/__35c.html; § 52 Abs. 35a (Anwendung) u. a. über https://www.buzer.de/35c_EStG.htm
- § 10d EStG: https://lxgesetze.de/estg/10d
- § 21 EStG: https://lxgesetze.de/estg/21
- § 3 Nr. 72 EStG: https://lxgesetze.de/estg/3
- § 4h EStG: https://lxgesetze.de/estg/4h
- § 82b EStDV: https://lxgesetze.de/estdv/82b
- § 5 KStG: https://lxgesetze.de/kstg/5
- § 9 GewStG: https://lxgesetze.de/gewstg/9
- § 16 GewStG (Mindesthebesatz 280 %): https://www.gesetze-im-internet.de/gewstg/__16.html
- § 12 UStG: https://lxgesetze.de/ustg/12

**Verwaltungsanweisungen / Richtlinien:**

- BMF-Schreiben vom 26.01.2026, Abgrenzung Erhaltungsaufwand/AK/HK/anschaffungsnahe HK (Volltext): https://ivd.net/wp-content/uploads/2026/02/2026-01-26-instandsetzung-modernisierung-gebaeude-1.pdf
- Zusammenfassungen: Forvis Mazars https://www.forvismazars.com/de/en/who-we-are/news/press-media/newsletters/newsletter-steuern/newsletter-steuern-2-2026/wann-sofort-abziehbar-wann-nur-ueber-afa; KPMG https://kpmg.com/de/de/themen/corporate-governance-und-compliance/mehr-klarheit-bei-gebauedesanierung.html
- R 21.5 EStR (Zuschüsse): https://www.steuerschroeder.de/steuer/r-21-5-behandlung-von-zuschussen/

**Gesetzgebung 2025/2026:**

- StInvSofortPG (BGBl. 2025 I Nr. 161): KPMG https://kpmg.com/de/de/home/themen/2025/07/stinvsofortpg-bgbl.html; EY https://www.ey.com/content/dam/ey-unified-site/ey-com/de-de/technical/steuernachrichten/steuerl_invprogramm_22072025_final.pdf
- Wachstumschancengesetz, Verlustverrechnung: FGS https://www.fgs.de/news-and-insights/blog/detail/wachstumschancengesetz-verbesserung-der-ertragsteuerlichen-verlustverrechnungsmoeglichkeiten-teil; Grant Thornton https://www.grantthornton.de/themen/2024/wachstumschancengesetz-in-kraft-getreten
- 9. StBerRÄndG (BGBl. 2026 I Nr. 197; Mindesthebesatz): https://dejure.org/Drucksachen/Bundestag/BT-Drs._21/6002; KPMG https://kpmg.com/de/de/themen/2026/01/reg-e-gewst-hebesatz.html; https://www.steuerschroeder.de/blog/?p=79664
- Einfache Kürzung ab EZ 2025: IWW https://www.iww.de/asr/steuern-und-abgaben/gewerbesteuer--9-nr-1-s-1-gewstg-so-ist-die-einfache-grundstueckskuerzung-ab-2025-neu-gestaltet-f164537
- JStG 2026 (Regierungsentwurf, § 6f EStG-E): Haufe https://www.haufe.de/immobilien/verwaltung/jahressteuergesetz_258_582300.html; Deloitte https://www.deloitte-tax-news.de/steuern/unternehmensteuer/jahressteuergesetz-2026-bundesfinanzministerium-legt-referentenentwurf-vor.html; VDIV https://vdiv.de/news-details/jahressteuergesetz-2026-neue-regeln-fuer-kaufpreisaufteilung-bei-immobilien
- Einkommensteuerreformgesetz 2027 (Regierungsentwurf 02.09.2026): Haufe https://www.haufe.de/steuern/gesetzgebung-politik/referentenentwurf-fuer-ein-einkommensteuerreformgesetz-2027_168_696022.html; https://www.news-research.net/2026/09/einkommensteuertarif-2027-regierungsentwurf-hebt-den-grundfreibetrag-auf-12-564-euro-an-und-fhrt-eine-zweite-reichensteuerstufe-ein/
- Standortfördergesetz: https://www.deubner-steuern.de/themen/aktuelle-steueraenderungen/standortfoerdergesetz/
- Neue Wohngemeinnützigkeit: Forvis Mazars https://www.forvismazars.com/de/de/ueber-uns/aktuelles/presse-medien/newsletter/newsletter-public-sector/newsletter-public-sector-1-2025/die-neue-wohngemeinnuetzigkeit; FGS https://www.fgs.de/news-and-insights/blog/detail/gesetzesaenderungen-zum-jahreswechsel-aenderungen-insbesondere-im-gemeinnuetzigkeits-und-umsatzsteuerrecht

**Sekundärquellen (Werte gegenprüfen):**

- Solidaritätszuschlag 2026 (Freigrenze): https://www.tk.de/firmenkunden/service/fachthemen/fachthema-beitraege/solidaritaetszuschlag-2075802
- § 35c (Ratgeber, BFH IX R 31/23): https://ecovis-kso.com/blog/energetische-sanierung-35c-estg/; https://rechner-hub.de/energetische-sanierung/35c-estg-2026/
- § 35a 2026/2027: https://ecovis-kso.com/?p=25432
- Grunderwerbsteuersätze: https://de.wikipedia.org/wiki/Grunderwerbsteuer_(Deutschland) (Stand 23.05.2026); https://rechner-hub.de/grunderwerbsteuer/bundeslaender-vergleich/

**Gesetzeskenntnis ohne gesonderte Online-Verifikation in dieser Recherche** (vor Implementierung prüfen):

- § 23 EStG (Details), § 11 Abs. 2 S. 4 EStG, § 20/§ 32d EStG (Abgeltungsteuer, Sparer-Pauschbetrag);
- § 8 Nr. 1 GewStG, § 3 Nr. 15 GewStG;
- § 4 Nr. 12, § 9, § 15, § 15a UStG;
- § 2 Nr. 1 BetrKV, § 25 Abs. 5 GrStG;
- Kirchensteuersätze.

**Literatur:**

- Grob, H. L.: *Investitionsrechnung mit vollständigen Finanzplänen*, München 1989;
- Grob, H. L.: *Einführung in die Investitionsrechnung*, 5. Aufl., München 2006;
- Kruschwitz, L./Lorenz, D.: *Investitionsrechnung* (Steuern im Standardmodell, Steuerparadoxon).
